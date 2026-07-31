extends Node
class_name MatchManagerScript
## Registered as the "MatchManager" autoload singleton (Project Settings > Autoload).
## Referenced globally as `MatchManager`, e.g. `MatchManager.report_round_result(...)`.

## ---------------------------------------------------------------------------
## ⚠️⚠️ PAIRED SETS, NOT SINGLE ROUNDS. `Design.md` §7. Rewritten 2026-07-31 by
## 📋 `build rules` (§8.1) and this is a FAIRNESS fix, not a formatting one.
##
## WHAT WAS WRONG. This file shipped `var team_a_is_can: bool = true` with no coin
## flip, flipped it once per round, and ran first-to-3 over single rounds. So Team A
## defended rounds 1, 3 and 5 and attacked 2 and 4 — every match, forever. A 3-0 meant
## one team defended twice and attacked once. Whichever role turns out stronger (and
## `build fair` §7.2 exists precisely because nobody knows yet), **the lobby seat decided
## the match**, and "balanced mechanics to avoid unfair advantage to one or more
## player/s or team/s" is a named line on the competition rubric.
##
## THE FIX, AND WHY THIS SHAPE. A **set** is two rounds in which **both teams attack
## exactly once**. Sets are the scoring unit; first to `SETS_NEEDED` sets takes the match.
## Because a set is only ever scored once both teams have done both jobs, the format
## cannot pay anybody for the side they were handed.
##
## ⚠️ THE ROLE IS NOW DERIVED, NOT ACCUMULATED, and that is the actual repair. The old
## code carried role in a bool it flipped; a schedule expressed as a flip has no way to
## state the invariant it is supposed to keep. `_team_a_is_can_for()` below is a pure
## function of (set number, round within set), so "both teams attack once per set" is
## true by construction rather than by every caller flipping in the right order.
##
## ⚠️ AND THE FIRST-ATTACK SEAT ALTERNATES BY SET. Within a set the two attacks are not
## quite symmetric — whoever attacks SECOND knows the time it has to beat. That is a real
## edge, so it alternates: Team B attacks first in odd sets, Team A in even ones. Without
## it the original bug simply moves up one level, from "A always defends round 1" to
## "A always attacks second".
##
## THE TIEBREAK IS A CLOCK, AND IT IS ONE RULE RATHER THAN TWO. Each team's **attack
## time** is how long it took to take the lata out on its own attacking round, or
## `NEVER` if it did not. The set goes to the LOWER number. That single comparison
## already expresses both halves of what the board asked for — "won your attack" beats
## "did not" because any finite time beats `NEVER`, and two successful attacks are split
## by which was faster. It also hands the HUD and a caster a number that means something:
## *"B took it out in 41.2 s, A has to beat that."*
## ---------------------------------------------------------------------------

signal match_won(winning_team: int)
signal round_started(round_number: int, team_a_is_can: bool)
## Item 10 / B-37: fires the instant a round ends without finishing the match
## — previously there was no gap at all between one round's win and the
## next one's timer starting (report_round_win -> report_round_result ->
## begin_next_round ran in a single frame), so there was nowhere for a
## round-result/role-swap beat to live. `next_team_a_is_can` is what the
## upcoming round's team_a_is_can WILL be — under paired sets that comes from
## `_team_a_is_can_for()` rather than from negating the current value, so
## main.gd can reset the world early instead of waiting for begin_next_round()
## to actually flip it. `can_team_won` is which SIDE (not team) held the round,
## same meaning as report_round_result's parameter.
signal round_intermission_started(next_round_number: int, next_team_a_is_can: bool, can_team_won: bool)
## §8.1: fires when a set is decided, i.e. once both teams have had their attack.
## `winning_team` is 0/1, or -1 for a drawn set (neither side took the lata out).
## `by_tiebreak` is true when both teams took it out and the clock split them —
## which is the moment worth showing, so the HUD and a caster can say why.
## ⚠️ ADDITIVE. Nothing is required to listen; the existing round signals are
## unchanged in name and signature so every current listener keeps working.
signal set_completed(winning_team: int, team_a_sets: int, team_b_sets: int, by_tiebreak: bool)

## First to this many SETS takes the match. Two sets = each team has attacked at
## least twice, which is the smallest sample that can separate two teams on
## something other than the draw.
const SETS_NEEDED: int = 2
## A set is both teams attacking exactly once. This is definitional — it is not a
## knob, and `_team_a_is_can_for()` assumes it.
const ROUNDS_PER_SET: int = 2
## ⚠️ TERMINATION GUARD, not a format choice. A set in which NEITHER team takes the
## lata out is genuinely drawn and awards nothing (see `_score_set`), so without a cap
## "first to 2 sets" is not guaranteed to halt. At the cap the match resolves on the
## aggregate clock — see `_finish_on_aggregate()`. Reaching it requires four straight
## rounds of nobody scoring; it is insurance, not an expected path.
const MAX_SETS: int = 5
## The attack-time sentinel for "this team never took the lata out". Any finite
## time beats it, which is what collapses the win check and the tiebreak into one
## comparison. Deliberately a real large float rather than INF so it survives an
## RPC round trip and prints legibly in a log.
const NEVER: float = 999999.0

## How long the intermission gap lasts before the next round's timer starts.
## `Design.md` §4.6's full moodboard sequence (banner -> role-swap card ->
## world reset -> "ROUND n - FIGHT" wipe) is ~4s; this is the plain
## placeholder-banner version (item 19 owns the animated card), kept a touch
## shorter since there's nothing to animate through yet.
const INTERMISSION_DURATION: float = 3.0

## ⚠️ THESE TWO NOW COUNT SETS, NOT ROUNDS, and the names are kept deliberately.
## `hud.gd`, `match_result.gd` and main.gd's late-joiner sync all read them, and all
## three are other lanes' files — changing the meaning without changing the name keeps
## every existing read valid (it is still "how much of the match this team has won").
## The HUD's pip count is the one thing that genuinely has to move, 3 -> `SETS_NEEDED`,
## and that is filed on 🖥️ `build ux` §4.20 rather than reached into from here.
var team_a_wins: int = 0
var team_b_wins: int = 0
## Global 1-based round counter across the whole match, 1..(MAX_SETS * ROUNDS_PER_SET).
## Unchanged in meaning: main.gd still reads `round_number > 0` as "a round has begun".
var round_number: int = 0
## 1-based set counter. `round_in_set` is 1 or 2 — which of this set's two attacks
## is being played.
var set_number: int = 0
var round_in_set: int = 0
## Which side Team A is playing THIS round. Still a plain bool that main.gd,
## character_nameplate.gd and the HUD read exactly as before — but it is now written
## only ever from `_team_a_is_can_for()`, never flipped in place.
var team_a_is_can: bool = true
## Per-team attack time for the set in progress, indexed by team (0 = A, 1 = B).
## `NEVER` until that team has had its attacking round.
var _set_attack_time: Array[float] = [NEVER, NEVER]
## Aggregate of every attack time this match, used only by the MAX_SETS fallback.
var _total_attack_time: Array[float] = [0.0, 0.0]
var _intermission_time_left: float = 0.0

## Session 6: host-authoritative, same pattern as RoundManager. Only the host
## (or a non-networked single-PC game) ever calls begin_next_round() /
## report_round_result() for real; those RPC the resulting fields out to
## clients, whose local copies exist purely for the HUD to read.

## ⚠️ THE WHOLE FAIRNESS ARGUMENT IS THIS FUNCTION. Role is a pure function of the
## schedule, so it cannot drift and cannot be biased by where anyone sat.
##
##   set 1 (odd):  round 1 -> A defends, B attacks    round 2 -> A attacks, B defends
##   set 2 (even): round 1 -> A attacks, B defends    round 2 -> A defends, B attacks
##
## Both teams attack exactly once per set, and which team attacks FIRST alternates
## with the set number so the "knows the time to beat" edge alternates too.
func _team_a_is_can_for(which_set: int, which_round_in_set: int) -> bool:
	var a_attacks_first := which_set % 2 == 0
	# Team A is the can (defends) in exactly the round it is not attacking.
	if which_round_in_set == 1:
		return not a_attacks_first
	return a_attacks_first

func begin_next_round() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	round_number += 1
	# Advance the set cursor. Round 1 of the match opens set 1.
	if round_in_set >= ROUNDS_PER_SET or set_number == 0:
		set_number += 1
		round_in_set = 1
		# A set's attack clocks are set-scoped, like RoundManager's own counters.
		_set_attack_time = [NEVER, NEVER]
	else:
		round_in_set += 1
	team_a_is_can = _team_a_is_can_for(set_number, round_in_set)
	if NetworkManager.is_networked():
		_sync_round_started.rpc(round_number, team_a_is_can, team_a_wins, team_b_wins,
			set_number, round_in_set)
	else:
		round_started.emit(round_number, team_a_is_can)

## `attack_elapsed` is how long the ATTACKING side took to take the lata out this
## round, or `NEVER` if it never did — RoundManager measures it (it owns the clock)
## and hands it over here. Defaulted so the two-argument form still resolves.
func report_round_result(can_team_won: bool, attack_elapsed: float = NEVER) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	# Which team was ATTACKING this round is the complement of who held the can.
	# team_a_is_can true -> A defended -> B attacked.
	var attacking_team := 1 if team_a_is_can else 0
	var recorded := attack_elapsed if not can_team_won else NEVER
	_set_attack_time[attacking_team] = recorded
	if recorded < NEVER:
		_total_attack_time[attacking_team] += recorded

	# ⚠️ A SET IS SCORED ONLY ON ITS SECOND ROUND, once both teams have attacked.
	# Nothing is awarded mid-set, which is the entire point of the format.
	if round_in_set >= ROUNDS_PER_SET:
		_score_set()
		if team_a_wins >= SETS_NEEDED:
			_finish_match(0)
			return
		if team_b_wins >= SETS_NEEDED:
			_finish_match(1)
			return
		if set_number >= MAX_SETS:
			_finish_on_aggregate()
			return

	# Item 10 / B-37: begin_next_round() no longer fires immediately — it
	# fires after INTERMISSION_DURATION, from _process below. The upcoming
	# round's role comes from the schedule, not from negating this round's.
	var next_set := set_number
	var next_round_in_set := round_in_set + 1
	if next_round_in_set > ROUNDS_PER_SET:
		next_set += 1
		next_round_in_set = 1
	var next_team_a_is_can := _team_a_is_can_for(next_set, next_round_in_set)
	if NetworkManager.is_networked():
		_sync_intermission_started.rpc(round_number + 1, next_team_a_is_can, can_team_won,
			team_a_wins, team_b_wins)
	else:
		round_intermission_started.emit(round_number + 1, next_team_a_is_can, can_team_won)
	_intermission_time_left = INTERMISSION_DURATION

## Both teams have now attacked once. The lower attack time takes the set; equal
## `NEVER`s mean neither side took the lata out and the set is drawn, awarding
## nothing. See the header for why one comparison covers both the win and the
## tiebreak.
func _score_set() -> void:
	var a_time := _set_attack_time[0]
	var b_time := _set_attack_time[1]
	if a_time == b_time:
		# Both NEVER (a genuinely drawn set), or — vanishingly unlikely — two
		# identical clocks. Nobody is awarded the set.
		set_completed.emit(-1, team_a_wins, team_b_wins, false)
		return
	# True only when the clock actually separated two SUCCESSFUL attacks; a finite
	# time beating a NEVER is just "one side scored and the other did not".
	var by_tiebreak := a_time < NEVER and b_time < NEVER
	var winner := 0 if a_time < b_time else 1
	if winner == 0:
		team_a_wins += 1
	else:
		team_b_wins += 1
	set_completed.emit(winner, team_a_wins, team_b_wins, by_tiebreak)

## MAX_SETS reached with neither team on `SETS_NEEDED` — only possible via drawn
## sets. Resolve on sets first, then on the aggregate clock (a team that took the
## lata out faster across the whole match has outplayed one that never did).
## `-1` is an honest draw and the HUD's handling of it is filed on `build ux`.
func _finish_on_aggregate() -> void:
	if team_a_wins != team_b_wins:
		_finish_match(0 if team_a_wins > team_b_wins else 1)
		return
	# Never having scored at all is the worst aggregate, not the best.
	var a_total := _total_attack_time[0] if _total_attack_time[0] > 0.0 else NEVER
	var b_total := _total_attack_time[1] if _total_attack_time[1] > 0.0 else NEVER
	if a_total == b_total:
		_finish_match(-1)
		return
	_finish_match(0 if a_total < b_total else 1)

func _process(delta: float) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return # clients: intermission is host-timed, they just wait for _sync_round_started
	if _intermission_time_left > 0.0:
		_intermission_time_left -= delta
		if _intermission_time_left <= 0.0:
			begin_next_round()

func _finish_match(winning_team: int) -> void:
	if NetworkManager.is_networked():
		_sync_match_won.rpc(winning_team, team_a_wins, team_b_wins)
	else:
		match_won.emit(winning_team)

## Read by the HUD and by anything casting the match. Seconds, or `NEVER`.
func attack_time_for(team: int) -> float:
	if team < 0 or team >= _set_attack_time.size():
		return NEVER
	return _set_attack_time[team]

## Broadcast to every peer including the host itself (call_local — B-01: this
## was call_remote, which meant the host, as sender, never ran its own
## handler, so round_started/match_won never fired locally and nothing ever
## started a networked round); mirrors the fields and re-fires the same
## signals so HUD code doesn't need to know or care whether it's networked.
## ⚠️ The two set arguments DEFAULT, the same contract `round_manager.gd::_sync_state`
## keeps, so a peer calling the four-argument form still resolves.
@rpc("authority", "call_local", "reliable")
func _sync_round_started(new_round_number: int, new_team_a_is_can: bool, new_team_a_wins: int,
		new_team_b_wins: int, new_set_number: int = 0, new_round_in_set: int = 0) -> void:
	round_number = new_round_number
	team_a_is_can = new_team_a_is_can
	team_a_wins = new_team_a_wins
	team_b_wins = new_team_b_wins
	set_number = new_set_number
	round_in_set = new_round_in_set
	round_started.emit(round_number, team_a_is_can)

@rpc("authority", "call_local", "reliable")
func _sync_match_won(winning_team: int, new_team_a_wins: int, new_team_b_wins: int) -> void:
	team_a_wins = new_team_a_wins
	team_b_wins = new_team_b_wins
	match_won.emit(winning_team)

## B-14: nothing reset this autoload between matches, so a second match
## resumed the first one's score/round number. Called both when returning to
## the main menu (scripts/ui/match_result.gd) and defensively at the top of
## main.gd::_ready() every time Main.tscn loads fresh, so a Local/Host/Join
## press from the menu always starts a match at 0-0 round 1 even if
## something upstream forgot to call this.
func reset() -> void:
	team_a_wins = 0
	team_b_wins = 0
	round_number = 0
	set_number = 0
	round_in_set = 0
	# The set-1 round-1 value, from the schedule rather than a hardcoded `true`,
	# so there is exactly one place that decides who defends first.
	team_a_is_can = _team_a_is_can_for(1, 1)
	_set_attack_time = [NEVER, NEVER]
	_total_attack_time = [0.0, 0.0]
	_intermission_time_left = 0.0

## Item 10 / B-37: broadcast counterpart of the local round_intermission_started
## emit above — call_local so the host's own _process (which drives the
## actual timer) doesn't need a separate non-networked code path.
@rpc("authority", "call_local", "reliable")
func _sync_intermission_started(next_round_number: int, next_team_a_is_can: bool, can_team_won: bool, new_team_a_wins: int, new_team_b_wins: int) -> void:
	team_a_wins = new_team_a_wins
	team_b_wins = new_team_b_wins
	round_intermission_started.emit(next_round_number, next_team_a_is_can, can_team_won)
