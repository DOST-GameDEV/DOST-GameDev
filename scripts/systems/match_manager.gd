extends Node
class_name MatchManagerScript
## Registered as the "MatchManager" autoload singleton (Project Settings > Autoload).
## Referenced globally as `MatchManager`, e.g. `MatchManager.report_round_result(...)`.

## Best of 5 tracker. Teams swap Attacker/Defender role each round (GDD Section 3).

signal match_won(winning_team: int)
signal round_started(round_number: int, team_a_is_can: bool)
## Item 10 / B-37: fires the instant a round ends without finishing the match
## — previously there was no gap at all between one round's win and the
## next one's timer starting (report_round_win -> report_round_result ->
## begin_next_round ran in a single frame), so there was nowhere for a
## round-result/role-swap beat to live. `next_team_a_is_can` is what the
## upcoming round's team_a_is_can WILL be (roles always swap between
## rounds), so main.gd can reset the world early instead of waiting for
## begin_next_round() to actually flip it. `can_team_won` is which SIDE (not
## team) held the round, same meaning as report_round_result's parameter.
signal round_intermission_started(next_round_number: int, next_team_a_is_can: bool, can_team_won: bool)

const WINS_NEEDED: int = 3
## How long the intermission gap lasts before the next round's timer starts.
## Dev_Plan.md §4.6's full moodboard sequence (banner -> role-swap card ->
## world reset -> "ROUND n - FIGHT" wipe) is ~4s; this is the plain
## placeholder-banner version (item 19 owns the animated card), kept a touch
## shorter since there's nothing to animate through yet.
const INTERMISSION_DURATION: float = 3.0

var team_a_wins: int = 0
var team_b_wins: int = 0
var round_number: int = 0
var team_a_is_can: bool = true # roles swap each round
var _intermission_time_left: float = 0.0

## Session 6: host-authoritative, same pattern as RoundManager. Only the host
## (or a non-networked single-PC game) ever calls begin_next_round() /
## report_round_result() for real; those RPC the resulting fields out to
## clients, whose local copies exist purely for the HUD to read.

func begin_next_round() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	round_number += 1
	if round_number > 1:
		team_a_is_can = not team_a_is_can
	if NetworkManager.is_networked():
		_sync_round_started.rpc(round_number, team_a_is_can, team_a_wins, team_b_wins)
	else:
		round_started.emit(round_number, team_a_is_can)

func report_round_result(can_team_won: bool) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var team_a_won := can_team_won == team_a_is_can
	if team_a_won:
		team_a_wins += 1
	else:
		team_b_wins += 1

	if team_a_wins >= WINS_NEEDED:
		_finish_match(0)
	elif team_b_wins >= WINS_NEEDED:
		_finish_match(1)
	else:
		# Item 10 / B-37: begin_next_round() no longer fires immediately — it
		# fires after INTERMISSION_DURATION, from _process below. Roles always
		# swap between rounds (round_number is already >= 1 here, since a
		# round just ended), so the upcoming round's team_a_is_can is simply
		# the opposite of this round's.
		var next_team_a_is_can := not team_a_is_can
		if NetworkManager.is_networked():
			_sync_intermission_started.rpc(round_number + 1, next_team_a_is_can, can_team_won, team_a_wins, team_b_wins)
		else:
			round_intermission_started.emit(round_number + 1, next_team_a_is_can, can_team_won)
		_intermission_time_left = INTERMISSION_DURATION

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

## Broadcast to every peer including the host itself (call_local — B-01: this
## was call_remote, which meant the host, as sender, never ran its own
## handler, so round_started/match_won never fired locally and nothing ever
## started a networked round); mirrors the fields and re-fires the same
## signals so HUD code doesn't need to know or care whether it's networked.
@rpc("authority", "call_local", "reliable")
func _sync_round_started(new_round_number: int, new_team_a_is_can: bool, new_team_a_wins: int, new_team_b_wins: int) -> void:
	round_number = new_round_number
	team_a_is_can = new_team_a_is_can
	team_a_wins = new_team_a_wins
	team_b_wins = new_team_b_wins
	round_started.emit(round_number, team_a_is_can)

@rpc("authority", "call_local", "reliable")
func _sync_match_won(winning_team: int, new_team_a_wins: int, new_team_b_wins: int) -> void:
	team_a_wins = new_team_a_wins
	team_b_wins = new_team_b_wins
	match_won.emit(winning_team)

## Item 10 / B-37: broadcast counterpart of the local round_intermission_started
## emit above — call_local so the host's own _process (which drives the
## actual timer) doesn't need a separate non-networked code path.
@rpc("authority", "call_local", "reliable")
func _sync_intermission_started(next_round_number: int, next_team_a_is_can: bool, can_team_won: bool, new_team_a_wins: int, new_team_b_wins: int) -> void:
	team_a_wins = new_team_a_wins
	team_b_wins = new_team_b_wins
	round_intermission_started.emit(next_round_number, next_team_a_is_can, can_team_won)
