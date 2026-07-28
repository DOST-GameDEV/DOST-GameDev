extends AbilityBase
class_name SpinGuard

## Bilao — Spin Guard: knockback pulse pushes attackers away (see
## docs/Dev_Plan.md, Roster: 🥫 Can Class). An AoE stagger pulse centered
## on the character, using AbilityUtils' spawned-hitbox helper. First-pass / untested.

@export var pulse_radius: float = 2.5
@export var pulse_duration: float = 0.2

func _do_activate(character: CharacterBody3D) -> bool:
	AbilityUtils.spawn_pulse_hitbox(character as CharacterBase, pulse_radius, pulse_duration)
	return true
