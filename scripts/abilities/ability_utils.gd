extends RefCounted
class_name AbilityUtils

## Shared helper for AoE / spawned-hitbox specials (Spin Guard, Bagsak Bomb, Bakya
## Bash, Flick Dash). Builds a temporary Hitbox entirely from code — no separate
## scene needed. First-pass / untested in-editor: double check the collision layers
## match CharacterBase.tscn's Hurtbox (layer 2, see scenes/characters/CharacterBase.tscn)
## once someone has this open in Godot.

static func spawn_pulse_hitbox(
	character: CharacterBase,
	radius: float,
	duration: float,
	forces_downed: bool = false,
	local_offset: Vector3 = Vector3.ZERO
) -> void:
	if character == null or not is_instance_valid(character):
		return

	var area := Area3D.new()
	area.set_script(load("res://scripts/characters/hitbox.gd"))
	area.set("owner_character", character)
	area.set("forces_downed", forces_downed)
	area.set("requires_bump_window", false) # specials bypass the press-to-bump gate
	area.collision_layer = 0
	area.collision_mask = 2 # matches Hurtbox layer

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	area.add_child(shape)

	character.get_tree().current_scene.add_child(area)
	area.global_position = character.global_position + character.transform.basis * local_offset

	var timer := character.get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(area):
			area.queue_free()
	)
