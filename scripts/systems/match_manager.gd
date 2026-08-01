extends Node
class_name MatchManagerScript
## Registered as the "MatchManager" autoload singleton (Project Settings > Autoload).
## Referenced globally as `MatchManager`, e.g. `MatchManager.add_score(...)`.

## ---------------------------------------------------------------------------
## ⚠️⚠️ FOUR PLAYERS, FOUR ROUNDS, ONE DEFENDER. Rewritten 2026-07-31 on branch
## `HARRYDAKS`. This replaces the paired-set 2v2 format wholesale.
##
## WHAT THIS REPLACED, AND WHY IT IS NOT A REGRESSION. The old format was
## `SETS_NEEDED` sets of `ROUNDS_PER_SET` rounds between two TEAMS, scored on a
## per-set attack-time tiebreak. It existed to close a real fairness bug — Team A
## always defended round 1, so the lobby seat decided matches. **That bug cannot
## exist here at all**: there are no teams, there are four players, and every one
## of them defends exactly once. Fairness is now structural rather than argued.
##
## ⚠️ THE ONE THING KEPT FROM THAT DESIGN IS THE THING THAT MATTERED: **role is
## DERIVED, never accumulated.** `defender_slot_for()` below is a pure function of
## the round number. The predecessor's own header records why, and it is worth
## restating because it is the whole reason this is a function and not a `+= 1`:
## a schedule expressed as a mutating counter has no way to state the invariant it
## is supposed to keep, and it desyncs the moment one peer misses one call.
## "Everyone defends exactly once, clockwise" is true here by construction.
##
## SCORING IS CUMULATIVE AND PER PLAYER. There is no per-round winner any more —
## a round ends, the scores persist, the defender rotates. Highest total after
## round `ROUNDS` takes the match. `RoundManager` is the only thing that awards
## points and it does so through `add_score()`, host-side, which is what keeps a
## single authority path for every point in the game.
## ---------------------------------------------------------------------------

## `winning_slot` is 0..3, or -1 for a genuine dead heat.
signal match_won(winning_slot: int)
## ⚠️ SIGNATURE CHANGED — was `(round_number, team_a_is_can: bool)`. A bool cannot
## name one of four players. Every listener in `scripts/` was updated in the same
## commit; `tools/*_probe.gd` were not and are backlog.
signal round_started(round_number: int, defender_slot: int)
## Fires the instant a round ends without finishing the match, so there is a beat
## for the role-swap card and the world reset to live in. Without it
## `report_round_result -> begin_next_round` ran in a single frame and the next
## round's timer started before anyone saw the last one end.
signal round_intermission_started(next_round_number: int, next_defender_slot: int)
## Fires on every award so the HUD can pop a floater and re-sort the scoreboard
## without polling. `slot` is who scored, `delta` is what they just got, `reason`
## is a short uppercase tag ("LATA DOWN", "TAG", "SABOTAGE", "DEFENSE").
signal score_changed(slot: int, total: int, delta: int, reason: String)

## Four rounds, one per player. This is definitional, not a knob: it is tied to
## `PLAYER_COUNT` by the rule "everyone plays Defender exactly once", and
## `defender_slot_for()` assumes the two are equal.
const ROUNDS: int = 4
const PLAYER_COUNT: int = 4

## How long the intermission gap lasts before the next round's timer starts.
const INTERMISSION_DURATION: float = 3.0

## Global 1-based round counter, 1..ROUNDS. `main.gd` still reads
## `round_number > 0` as "a round has begun", which is why this stays 1-based.
var round_number: int = 0
## Which player slot (0..3) is the Defender this round. Written only ever from
## `defender_slot_for()`, never incremented in place.
var defender_slot: int = 0
## Cumulative match score per player slot. Persists across rounds — that is the
## format. Host-authoritative; a client's copy exists purely for the HUD to read.
var scores: Array[int] = [0, 0, 0, 0]

var _intermission_time_left: float = 0.0

## ⚠️ THE FAIRNESS ARGUMENT IS THIS FUNCTION, and it is one line because the
## format made it one line. Clockwise, wrapping, everyone exactly once.
##
##   round 1 -> slot 0 defends    round 3 -> slot 2 defends
##   round 2 -> slot 1 defends    round 4 -> slot 3 defends
func defender_slot_for(which_round: int) -> int:
	return (maxi(1, which_round) - 1) % PLAYER_COUNT

func is_defender_slot(slot: int) -> bool:
	return slot == defender_slot

func score_for(slot: int) -> int:
	if slot < 0 or slot >= scores.size():
		return 0
	return scores[slot]

## Host-authoritative and the ONLY way a point is ever awarded. RoundManager owns
## every rule that calls this; nothing else should.
func add_score(slot: int, points: int, reason: String = "") -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if slot < 0 or slot >= scores.size() or points == 0:
		return
	var total := scores[slot] + points
	if NetworkManager.is_networked():
		_sync_score.rpc(slot, total, points, reason)
	else:
		_apply_score(slot, total, points, reason)

func _apply_score(slot: int, total: int, delta: int, reason: String) -> void:
	if slot < 0 or slot >= scores.size():
		return
	scores[slot] = total
	score_changed.emit(slot, total, delta, reason)

@rpc("authority", "call_local", "reliable")
func _sync_score(slot: int, total: int, delta: int, reason: String) -> void:
	_apply_score(slot, total, delta, reason)

func begin_next_round() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	round_number += 1
	defender_slot = defender_slot_for(round_number)
	if NetworkManager.is_networked():
		_sync_round_started.rpc(round_number, defender_slot, scores)
	else:
		round_started.emit(round_number, defender_slot)

## Called by RoundManager when the 90 s clock expires. There is no per-round
## winner to report any more — scores already persist — so this only decides
## whether the match is over and otherwise opens the intermission.
func report_round_result() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if round_number >= ROUNDS:
		_finish_match(_leading_slot())
		return
	var next_round := round_number + 1
	var next_defender := defender_slot_for(next_round)
	if NetworkManager.is_networked():
		_sync_intermission_started.rpc(next_round, next_defender, scores)
	else:
		round_intermission_started.emit(next_round, next_defender)
	_intermission_time_left = INTERMISSION_DURATION

## Highest cumulative score takes the match. A tie at the top is reported as -1
## rather than broken arbitrarily — an honest draw is a real result and the HUD
## has a path for it.
func _leading_slot() -> int:
	var best := -1
	var best_score := -1
	var tied := false
	for slot in range(scores.size()):
		if scores[slot] > best_score:
			best_score = scores[slot]
			best = slot
			tied = false
		elif scores[slot] == best_score:
			tied = true
	return -1 if tied else best

## Read by the HUD and by anything casting the match: the slots in scoring order,
## highest first. Ties keep slot order, which is stable frame to frame — a
## scoreboard that reshuffles two equal rows every frame is unreadable.
func ranking() -> Array[int]:
	var order: Array[int] = []
	for slot in range(scores.size()):
		order.append(slot)
	order.sort_custom(func(a: int, b: int) -> bool:
		if scores[a] == scores[b]:
			return a < b
		return scores[a] > scores[b])
	return order

func _process(delta: float) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return # clients: intermission is host-timed, they wait for _sync_round_started
	if _intermission_time_left > 0.0:
		_intermission_time_left -= delta
		if _intermission_time_left <= 0.0:
			begin_next_round()

func _finish_match(winning_slot: int) -> void:
	if NetworkManager.is_networked():
		_sync_match_won.rpc(winning_slot, scores)
	else:
		match_won.emit(winning_slot)

## Broadcast to every peer INCLUDING the host itself (`call_local` — B-01: this
## was `call_remote`, which meant the host, as sender, never ran its own handler,
## so `round_started` never fired locally and nothing ever started a networked
## round). Scores ride along so a peer that missed an award RPC is corrected at
## every round boundary rather than drifting for the whole match.
@rpc("authority", "call_local", "reliable")
func _sync_round_started(new_round_number: int, new_defender_slot: int,
		new_scores: Array) -> void:
	round_number = new_round_number
	defender_slot = new_defender_slot
	_adopt_scores(new_scores)
	round_started.emit(round_number, defender_slot)

@rpc("authority", "call_local", "reliable")
func _sync_match_won(winning_slot: int, new_scores: Array) -> void:
	_adopt_scores(new_scores)
	match_won.emit(winning_slot)

@rpc("authority", "call_local", "reliable")
func _sync_intermission_started(next_round_number: int, next_defender_slot: int,
		new_scores: Array) -> void:
	_adopt_scores(new_scores)
	round_intermission_started.emit(next_round_number, next_defender_slot)

## ⚠️ Copies element by element rather than assigning the array. An RPC delivers a
## plain `Array`, not the `Array[int]` this field is typed as, and assigning one
## to the other is a runtime error in Godot 4.
func _adopt_scores(new_scores: Array) -> void:
	for slot in range(mini(scores.size(), new_scores.size())):
		scores[slot] = int(new_scores[slot])

## B-14: nothing reset this autoload between matches, so a second match resumed
## the first one's score and round number. Called both when returning to the main
## menu (`scripts/ui/match_result.gd`) and defensively at the top of
## `main.gd::_ready()` every time Main.tscn loads fresh.
func reset() -> void:
	round_number = 0
	defender_slot = defender_slot_for(1)
	scores = [0, 0, 0, 0]
	_intermission_time_left = 0.0
