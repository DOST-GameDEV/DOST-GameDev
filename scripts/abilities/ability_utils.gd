extends RefCounted
class_name AbilityUtils

## Shared helper for AoE / spawned-hitbox specials (Spin Guard, Person Tag) and
## for the tsinelas' in-flight hitbox (Task 0 — see carriable.gd). Builds a
## temporary Hitbox entirely from code — no separate scene needed. First-pass /
## untested in-editor: double check the collision layers match CharacterBase.tscn's
## Hurtbox (layer 2, see scenes/characters/CharacterBase.tscn) once someone has
## this open in Godot.
##
## Returns the spawned Area3D so a caller that needs to end the hitbox EARLY can
## free it — `carriable.gd` does, because a thrown slipper's hitbox has to die the
## moment it lands, and a landing time is not knowable at spawn time. Callers that
## just want a fixed-duration pulse can keep ignoring the return value; the timer
## below still frees it either way.

static func spawn_pulse_hitbox(
	character: CharacterBase,
	radius: float,
	duration: float,
	forces_downed: bool = false,
	local_offset: Vector3 = Vector3.ZERO,
	follow_character: bool = false
) -> Area3D:
	if character == null or not is_instance_valid(character):
		return null

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

	# ⚠️⚠️ CAPTURE THE INSTANCE ID, NOT THE NODE. THE GUARD BELOW IS NOT ENOUGH
	# ON ITS OWN — it never gets to run.
	#
	# This used to be `func(): if is_instance_valid(area): area.queue_free()`,
	# capturing `area` by reference. Every one of these areas joins the
	# `transient_hitbox` group (see above), and `main.gd::_reset_world` frees that
	# whole group on every round reset — so an ability cast shortly before a round
	# ends routinely has its area freed while this timer is still pending.
	#
	# Godot resolves a lambda's captures when the lambda is CALLED, before any of
	# its body executes, and errors on a freed capture right there:
	#   "Lambda capture at index 0 was freed. Passed null instead."
	# The `is_instance_valid()` check inside was therefore dead code for exactly
	# the case it was written for. Confirmed in a real two-instance --host/--join
	# session: the host logged this on round transitions, the client never did
	# (only the host runs ability resolution).
	#
	# An int cannot dangle, so capturing the id and resolving it at call time is
	# both correct and keeps the whole thing local to this function.
	var area_id := area.get_instance_id()
	var timer := character.get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		var live := instance_from_id(area_id)
		if live != null and is_instance_valid(live):
			(live as Node).queue_free()
	)
	return area
