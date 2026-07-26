extends AbilityBase
class_name BakyaBash

## Bakya — Bakya Bash: big charge, instant-down on direct hit, long cooldown (see
## docs/Tumbang_Preso_2v2_GDD.md, Roster: 🩴 Tsinelas Class — set `cooldown` high in
## the .tres resource, e.g. 15-20s, to reflect "long cooldown"). Spawns a forward,
## forces_downed hitbox for the charge's brief active window. First-pass / untested —
## the charge itself doesn't move the character yet, only the hitbox is placed ahead;
## revisit once movement/dash feel is being tuned alongside Flick Dash.

@export var charge_range: float = 2.0
@export var active_duration: float = 0.35
@export var hit_radius: float = 1.0

func _do_activate(character: CharacterBody3D) -> void:
	var c := character as CharacterBase
	AbilityUtils.spawn_pulse_hitbox(c, hit_radius, active_duration, true, Vector3(0, 0, -charge_range))
