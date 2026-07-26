extends Node
class_name RoundManager

## Deliberately decoupled from movement/combat/hit-registration (see GDD Section 3).
## Round-win logic is still an open decision between two options:
##   Option A — Stock/Life (dents): Cans have a health bar, Slippers win by fully
##              denting a Can; Cans win on timer or ring-outs.
##   Option B — Capture the Base + Downed/Seal: hit knocks Can out of its base circle
##              into a Downed state, ~2s self-right window before a Tsinelas can "seal" it.
## Build/test both cheaply against the same single-player loop before committing (see
## Dev_Plan_and_Godot_Setup.md, Part 1, Build order step 2).

signal round_won(winning_team: int)

const ROUND_TIME: float = 90.0

var time_left: float = ROUND_TIME
var round_active: bool = false

func start_round() -> void:
	time_left = ROUND_TIME
	round_active = true

func _process(delta: float) -> void:
	if not round_active:
		return
	time_left = max(0.0, time_left - delta)
	if time_left <= 0.0:
		_on_time_up()

func _on_time_up() -> void:
	round_active = false
	# TODO: Cans win on timer expiry per both Option A and Option B — confirm once
	# stock/downed system is chosen and wire in the actual win check here.
	round_won.emit(0) # 0 = Can team, placeholder

## Call this from whichever round-win option gets implemented first.
func report_round_win(winning_team: int) -> void:
	if not round_active:
		return
	round_active = false
	round_won.emit(winning_team)
