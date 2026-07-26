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

func begin_next_round() -> void:
	round_number += 1
	if round_number > 1:
		team_a_is_can = not team_a_is_can
	round_started.emit(round_number, team_a_is_can)

func report_round_result(can_team_won: bool) -> void:
	var team_a_won := can_team_won == team_a_is_can
	if team_a_won:
		team_a_wins += 1
	else:
		team_b_wins += 1

	if team_a_wins >= WINS_NEEDED:
		match_won.emit(0)
	elif team_b_wins >= WINS_NEEDED:
		match_won.emit(1)
	else:
		begin_next_round()
