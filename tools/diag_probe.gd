extends Node3D

func _ready() -> void:
	GameLaunch.spectator = true
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	for _i in range(1200):
		await get_tree().physics_frame
		if RoundManager.round_active and RoundManager.lata != null:
			break
	for _j in range(8):
		await get_tree().physics_frame
	_report_spawns(main)
	await _report_carry(main)
	get_tree().quit(0)

func _report_spawns(main: Node) -> void:
	print("
=== SPAWN AUDIT ===")
	print("defender_slot = ", MatchManager.defender_slot, "   round = ", MatchManager.round_number)
	for m in main.find_children("Spawn*", "Marker3D", true, false):
		print("  marker %-9s %s" % [m.name, str((m as Marker3D).global_position)])
	print("  --- seats ---")
	for slot in range(4):
		var ch := RoundManager.player_at(slot)
		if ch == null:
			print("  seat %d  <empty>" % slot)
			continue
		print("  seat %d  %-16s %-8s score=%d" % [slot, ch.name,
			"TAYA" if ch.is_defender else "attacker", MatchManager.score_for(slot)])
		print("      actual pos %s   yaw %.1f deg" % [
			str(ch.global_position), rad_to_deg(ch.rotation.y)])
	var can := RoundManager.lata
	if can != null:
		print("  lata     %s  upright=%s" % [str(can.global_position), str(can.is_upright)])


func _report_carry(main: Node) -> void:
	print("\n=== CARRY AUDIT ===")
	var person: CharacterBase = null
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who != null and not who.is_defender:
			person = who
			break
	var carrier := person.get_node_or_null("Carrier") as Carrier
	var slipper: Slipper = carrier.held() if carrier != null else null
	if slipper == null:
		for node in get_tree().get_nodes_in_group("slippers"):
			slipper = node as Slipper
			if slipper != null:
				break
	if person == null or slipper == null:
		print("  no attacker (%s) or no slipper (%s) in the live round" % [
			str(person != null), str(slipper != null)]); return
	for _i in range(600):
		if person.can_act():
			break
		await get_tree().physics_frame
	slipper.host_drop()
	await get_tree().physics_frame
	slipper.global_position = person.global_position + Vector3(0.0, 0.2, -0.5)
	await get_tree().physics_frame
	slipper.host_grab(person)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("  carry state         ", slipper.state, " (1 = CARRIED)")
	print("  grab gates          loose=%s not_taya=%s can_act=%s hands_free=%s -> %s" % [
		str(slipper.state == Slipper.CarryState.LOOSE), str(not person.is_defender),
		str(person.can_act()), str(not person.holding_slipper()),
		str(slipper.can_be_grabbed_by(person))])
	var visual: Node = person.get_node_or_null("CharacterVisual")
	var hand: Node3D = person.get_hand_attachment()
	if hand == null:
		print("  hand attachment not built yet"); return
	var bone: Node3D = hand.get_parent() as Node3D
	print("  person pos          ", person.global_position, "  capsule h=", person.capsule_height())
	print("  hand BONE  world    ", bone.global_position)
	print("  HandPoint  world    ", hand.global_position)
	print("  offset bone->point  %.3f m" % bone.global_position.distance_to(hand.global_position))
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

