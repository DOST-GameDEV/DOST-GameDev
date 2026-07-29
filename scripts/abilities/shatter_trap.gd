extends AbilityBase
class_name ShatterTrap

## Palayok — Shatter Trap: downed state leaves a hazard patch that slows nearby
## attackers (see docs/Dev_Plan.md, Roster: 🥫 Can Class).
## Modeled as: activating arms the trap; the *next* time this character goes Downed
## while armed, a slow-zone hazard spawns at that spot (uses HazardZone, shared with
## future map hazards). First-pass / untested in-editor.

@export var trap_hazard_duration: float = 4.0
@export var trap_hazard_radius: float = 2.5
@export var trap_slow_multiplier: float = 0.5

var _armed: bool = false

func _do_activate(character: CharacterBody3D) -> bool:
	_armed = true
	# Checklist 4.1 — arming. Deliberately the QUIET half: `ability_shatter_trap`
	# is played back here at -8 dB, so setting the trap is a private confirmation
	# to its own player rather than an announcement to the attacker. The trap's
	# value is that nobody else knows it is there.
	AudioManager.play_at("ability_shatter_trap", (character as CharacterBase).global_position, -8.0)
	return true

## Optional passive hook — called by CharacterBase.go_downed() (see ability_base.gd).
func _on_owner_downed(character: CharacterBase) -> void:
	if not _armed:
		return
	_armed = false
	# 4.1 — SPRINGING it, at full level. This is the snap/crunch the checklist
	# names, and it is the moment it matters: an attacker who has just knocked
	# the can over needs to know the ground around it has become a hazard, and
	# the hazard patch itself is a subtle enough visual that a sound is most of
	# how they will learn it.
	AudioManager.play_at("ability_shatter_trap", character.global_position)
	HazardZone.spawn(
		character.get_tree().current_scene,
		character.global_position,
		trap_hazard_radius,
		trap_hazard_duration,
		trap_slow_multiplier
	)
