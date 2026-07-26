extends AbilityBase
class_name BagsakBomb

## Dyaryo — Bagsak Bomb: leap-slam, small AoE knockback (see
## docs/Tumbang_Preso_2v2_GDD.md, Roster: 🩴 Tsinelas Class). Same AoE-pulse pattern as
## Spin Guard but themed as an offensive slam; tune radius/duration separately per
## character in the .tres resource. Doesn't force Downed on its own — GDD calls it
## "knockback" not "instant-down", that's Bakya Bash's thing. First-pass / untested.

@export var slam_radius: float = 2.0
@export var slam_duration: float = 0.2

func _do_activate(character: CharacterBody3D) -> void:
	AbilityUtils.spawn_pulse_hitbox(character as CharacterBase, slam_radius, slam_duration)
