extends Node
class_name MatchManagerScript
## Registered as the "MatchManager" autoload singleton (Project Settings > Autoload).
## Referenced globally as `MatchManager`, e.g. `MatchManager.report_round_result(...)`.

## Best of 5 tracker. Teams swap Attacker/Defender role each round (GDD Section 3).

signal match_won(winning_team: int)
signal round_started(round_number: int, team_a_is_can: bool)

const WINS_NEEDED: int = 3

var team_a_wins: int = 0
var team_b_wins: int = 0
var round_number: int = 0
var team_a_is_can: bool = true # roles swap each round

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
		begin_next_round()

func _finish_match(winning_team: int) -> void:
	if NetworkManager.is_networked():
		_sync_match_won.rpc(winning_team, team_a_wins, team_b_wins)
	else:
		match_won.emit(winning_team)

## Broadcast to every client (call_remote — host already applied this
## directly above); mirrors the fields and re-fires the same signals so HUD
## code doesn't need to know or care whether it's networked.
@rpc("authority", "call_remote", "reliable")
func _sync_round_started(new_round_number: int, new_team_a_is_can: bool, new_team_a_wins: int, new_team_b_wins: int) -> void:
	round_number = new_round_number
	team_a_is_can = new_team_a_is_can
	team_a_wins = new_team_a_wins
	team_b_wins = new_team_b_wins
	round_started.emit(round_number, team_a_is_can)

@rpc("authority", "call_remote", "reliable")
func _sync_match_won(winning_team: int, new_team_a_wins: int, new_team_b_wins: int) -> void:
	team_a_wins = new_team_a_wins
	team_b_wins = new_team_b_wins
	match_won.emit(winning_team)
