extends Node3D
## Measures the two recurring bugs instead of reasoning about them:
##   1. where a CARRIED tsinelas's visible mesh actually is vs. the hand bone
##   2. where each unit actually spawns vs. the role slot it should occupy
## Prints only; changes nothing. Run WITHOUT --headless (needs a skeleton pose).

func _ready() -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.5).timeout
	_report_spawns(main)
	await _report_carry(main)
	get_tree().quit(0)

func _report_spawns(main: Node) -> void:
	print("\n=== SPAWN AUDIT ===")
	print("team_a_is_can = ", MatchManager.team_a_is_can, "   round = ", MatchManager.round_number)
	var map := main.get_node_or_null("MapRoot")
	var names := ["Spawn0 CAN", "Spawn1 TAYA", "Spawn2 ATTACKER", "Spawn3 TSINELAS"]
	for m in main.find_children("Spawn*", "Marker3D", true, false):
		print("  marker %-9s %s" % [m.name, str((m as Marker3D).global_position)])
	print("  --- units ---")
	for c in main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		var slot := -1
		if ch.is_can: slot = 0
		elif ch.is_person: slot = (1 if ch.team_is_can_side else 2)
		else: slot = 3
		print("  %-16s team=%d person=%s can=%s canside=%s  -> slot %d (%s)" % [
			ch.name, ch.team, str(ch.is_person), str(ch.is_can),
			str(ch.team_is_can_side), slot, names[slot]])
		print("      actual pos %s   yaw %.1f deg" % [
			str(ch.global_position), rad_to_deg(ch.rotation.y)])

func _report_carry(main: Node) -> void:
	print("\n=== CARRY AUDIT ===")
	var person: CharacterBase = null
	var slipper: CharacterBase = null
	for c in main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.is_person and person == null:
			person = ch
		elif not ch.is_person and not ch.is_can and slipper == null:
			slipper = ch
	if person == null or slipper == null:
		print("  could not find a Person + Tsinelas pair"); return
	# Force the carry so this measures the state the bug was reported in,
	# instead of whatever the AI happened to be doing.
	var carriable: Carriable = slipper.get_node_or_null("Carriable")
	if carriable != null:
		slipper.global_position = person.global_position + Vector3(0.0, 0.2, -0.5)
		await get_tree().physics_frame
		carriable.host_grab(person)
		await get_tree().physics_frame
		await get_tree().physics_frame
		print("  carry state         ", carriable.state, " (2 = CARRIED)")
	var visual: Node = person.get_node_or_null("CharacterVisual")
	var hand: Node3D = person.get_hand_attachment()
	if hand == null:
		print("  hand attachment not built yet"); return
	var bone: Node3D = hand.get_parent() as Node3D
	print("  person pos          ", person.global_position, "  capsule h=", person.capsule_height())
	print("  hand BONE  world    ", bone.global_position)
	print("  HandPoint  world    ", hand.global_position)
	print("  offset bone->point  %.3f m" % bone.global_position.distance_to(hand.global_position))
	print("  slipper capsule h   ", slipper.capsule_height())
	print("  slipper ORIGIN      ", slipper.global_position)
	print("  slipper children: ", slipper.get_children().map(func(c): return c.name))
	var sv: Node3D = null
	for c in slipper.get_children():
		if c is Node3D and (c as Node3D).get_child_count() > 0 and String(c.name).contains("Visual"):
			sv = c as Node3D
	if sv != null:
		var model := sv.get_child(0) as Node3D
		print("  slipper model local y offset ", model.position.y)
		var bounds := AABB(); var first := true
		for n in slipper.find_children("*", "VisualInstance3D", true, false):
			var vi := n as VisualInstance3D
			var box: AABB = vi.get_aabb()
			var g := (vi as Node3D).global_transform
			var wb := AABB(g * box.position, Vector3.ZERO)
			for i in range(8):
				wb = wb.expand(g * box.get_endpoint(i))
			if first: bounds = wb; first = false
			else: bounds = bounds.merge(wb)
		print("  slipper MESH world  centre ", bounds.get_center(), "  size ", bounds.size)
		print("  >>> MESH is %.3f m from the hand point" % bounds.get_center().distance_to(hand.global_position))
