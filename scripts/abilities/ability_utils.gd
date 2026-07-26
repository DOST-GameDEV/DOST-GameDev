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
	local_offset: Vector3 = Vector3.ZERO,
	follow_character: bool = false
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
	# B-43: these already self-free via the timer below, but not if a round
	# ends first — main.gd::_reset_world frees anything still in this group so
	# a pulse hitbox never survives into the next round.
	area.add_to_group("transient_hitbox")

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	area.add_child(shape)

	# B-43: Flick Dash's own comment said the hitbox "rides along with" the
	# dash, but every caller parented it to current_scene at a fixed world
	# position — fine for a stationary pulse (Spin Guard, Bagsak Bomb), but a
	# static sphere at the activation point while the character dashes away
	# from it for a dash-throw. follow_character parents it to the character
	# instead, as a plain local-offset child, so it moves with them for free.
	if follow_character:
		character.add_child(area)
		area.position = local_offset
	else:
		character.get_tree().current_scene.add_child(area)
		area.global_position = character.global_position + character.transform.basis * local_offset

	var timer := character.get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(area):
			area.queue_free()
	)
