extends AbilityBase
class_name ShatterTrap

## Palayok — Shatter Trap: downed state leaves a hazard patch that slows nearby
## attackers (see docs/Tumbang_Preso_2v2_GDD.md, Roster: 🥫 Can Class).
## Modeled as: activating arms the trap; the *next* time this character goes Downed
## while armed, a slow-zone hazard spawns at that spot (uses HazardZone, shared with
## future map hazards). First-pass / untested in-editor.

@export var trap_hazard_duration: float = 4.0
@export var trap_hazard_radius: float = 2.5
@export var trap_slow_multiplier: float = 0.5

var _armed: bool = false

func _do_activate(_character: CharacterBody3D) -> void:
	_armed = true

## Optional passive hook — called by CharacterBase.go_downed() (see ability_base.gd).
func _on_owner_downed(character: CharacterBase) -> void:
	if not _armed:
		return
	_armed = false
	HazardZone.spawn(
		character.get_tree().current_scene,
		character.global_position,
		trap_hazard_radius,
		trap_hazard_duration,
		trap_slow_multiplier
	)
