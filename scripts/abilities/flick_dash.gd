extends AbilityBase
class_name FlickDash

## Havaianas — Flick Dash: short ranged dash-throw (see
## docs/Tumbang_Preso_2v2_GDD.md, Roster: 🩴 Tsinelas Class). First-pass: a quick
## forward velocity burst plus a small hitbox riding along with it. Whether this
## should actually be a thrown projectile instead of a melee dash is a design detail
## worth revisiting once the team feels this in-editor — flagged, not decided.
## Untested.

@export var dash_speed: float = 16.0
@export var dash_duration: float = 0.2
@export var hit_radius: float = 1.0

func _do_activate(character: CharacterBody3D) -> bool:
	var c := character as CharacterBase
	var forward := -c.transform.basis.z
	c.velocity.x = forward.x * dash_speed
	c.velocity.z = forward.z * dash_speed
	# B-43: follow_character = true — this hitbox needs to ride along with the
	# dash, not sit at a static world point the character immediately dashes
	# away from (see AbilityUtils doc).
	AbilityUtils.spawn_pulse_hitbox(c, hit_radius, dash_duration, false, Vector3(0, 0, -1.5), true)
	return true
