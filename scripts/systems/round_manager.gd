extends Node
class_name RoundManagerScript
## Registered as the "RoundManager" autoload singleton (Project Settings > Autoload).
## Referenced globally as `RoundManager`, e.g. `RoundManager.start_round()`.

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

## --- Option B testbed (all Cans Sealed = Slippers win) ---------------------------
## Not auto-populated on its own — call register_can() for whichever characters are
## playing Can this round (see scripts/main.gd for a working example). Deliberately
## opt-in rather than scanning the scene tree, since which characters ARE the Cans
## changes with the Attacker/Defender role swap each round (GDD Section 3) — that
## reassignment isn't implemented yet, this just gives Option B something real to
## playtest against with a fixed pair of Cans in the meantime.
var _tracked_cans: Array[CharacterBase] = []

func register_can(can: CharacterBase) -> void:
	if can in _tracked_cans:
		return
	_tracked_cans.append(can)
	if not can.state_changed.is_connected(_on_tracked_can_state_changed):
		can.state_changed.connect(_on_tracked_can_state_changed)

func clear_tracked_cans() -> void:
	for can in _tracked_cans:
		if is_instance_valid(can) and can.state_changed.is_connected(_on_tracked_can_state_changed):
			can.state_changed.disconnect(_on_tracked_can_state_changed)
	_tracked_cans.clear()

func _on_tracked_can_state_changed(_new_state: int) -> void:
	if not round_active or _tracked_cans.is_empty():
		return
	for can in _tracked_cans:
		if not is_instance_valid(can) or can.state != CharacterBase.State.SEALED:
			return
	report_round_win(false) # every tracked Can Sealed -> Slippers win the round
## ----------------------------------------------------------------------------------

func start_round() -> void:
	time_left = ROUND_TIME
	round_active = true
	for can in _tracked_cans:
		if is_instance_valid(can):
			can.reset_for_new_round()

func _process(delta: float) -> void:
	if not round_active:
		return
	time_left = max(0.0, time_left - delta)
	if time_left <= 0.0:
		_on_time_up()

func _on_time_up() -> void:
	if not round_active:
		return
	round_active = false
	# Cans win on timer expiry — true under both Option A and Option B (GDD Section 3).
	round_won.emit(0) # 0 = Can team
	MatchManager.report_round_result(true)

## Call this from whichever round-win option gets implemented first (Slippers denting
## a Can under Option A, or sealing it under Option B — see character_base.gd `seal()`).
func report_round_win(can_team_won: bool) -> void:
	if not round_active:
		return
	round_active = false
	round_won.emit(0 if can_team_won else 1)
	MatchManager.report_round_result(can_team_won)
