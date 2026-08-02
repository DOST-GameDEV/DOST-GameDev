extends Node3D
## Measures the two recurring bugs instead of reasoning about them:
##   1. where a CARRIED tsinelas's visible mesh actually is vs. the hand bone
##   2. where each unit actually spawns vs. the role slot it should occupy
## Prints only; changes nothing. Run WITHOUT --headless (needs a skeleton pose).

func _ready() -> void:
	# ⚠️ SPECTATOR, LIKE `trait_probe` — it is what gets the match to actually RUN.
	# Without it the round never leaves its opening freeze: `round_active` goes true
	# but every Person stays outside NORMAL, so `can_act()` was false for the whole
	# 10 s the carry audit waited and the grab could never be accepted.
	GameLaunch.spectator = true
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	# ⚠️ WAIT FOR A LIVE ROUND, NOT FOR A CLOCK. The 1.5 s timer this replaced was
	# enough for the spawn audit and not for the carry audit: `owner_slot` is assigned
	# by the round reset, so polling `RoundManager` is the only thing that guarantees
	# the seats exist before they are read.
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
	# ⚠️⚠️ FOUR SEATS AND ONE TAYA, NOT TWO TEAMS AND FOUR ROLE SLOTS — 2026-08-02.
	# This audit used to read `MatchManager.team_a_is_can` and map every unit onto
	# Spawn0 CAN / Spawn1 TAYA / Spawn2 ATTACKER / Spawn3 TSINELAS. None of that
	# survives 3abc019: `team_a_is_can` is not a property on MatchManager any more
	# (it threw at runtime, which is why the audit printed a header and no units),
	# the can is a `Lata` prop rather than a seat, and the match is four Persons of
	# whom exactly one is the taya. Seats come off `RoundManager` now.
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
	# ⚠️⚠️ THE SLIPPER IS FOUND IN A GROUP, NOT IN THE CHARACTER LIST — 2026-08-02.
	# This used to walk `CharacterBase` children looking for one that was neither a
	# Person nor a can, because a tsinelas WAS a character then and carried a
	# `Carriable` node. Since 3abc019 it is a `Slipper` (a plain Node3D prop) in the
	# `slippers` group, so the old search matched nothing and the old type no longer
	# exists to compile against.
	# ⚠️ AN ATTACKER, NOT MERELY "THE FIRST PERSON". `Slipper.can_be_grabbed_by()`
	# refuses the taya outright and refuses anyone already holding one, so grabbing
	# with the first `is_person` hit reported `carry state 0` (LOOSE) — a carry audit
	# measuring an empty hand. The pairing is by `owner_slot`, which is the seat the
	# round reset assigns.
	# ⚠️ ANY ATTACKER AND ANY SLIPPER — NOT A MATCHED `owner_slot` PAIR. Pairing them
	# by ownership found nothing, and the reason is in `slipper.gd`'s own note: the
	# owner gate on grabbing is GONE ("everything above it — loose, an attacker, able
	# to act" is the whole test). `owner_slot` is still assigned, but it is not what
	# decides who may pick a slipper up, so requiring it here invented a constraint
	# the game does not have.
	var person: CharacterBase = null
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who != null and not who.is_defender:
			person = who
			break
	# ⚠️ THE ONE ALREADY IN THAT ATTACKER'S HAND, IF THERE IS ONE. The round opens with
	# every attacker holding their tsinelas, and `can_be_grabbed_by()` refuses anyone
	# who `holding_slipper()` — so dropping SOME OTHER slipper and asking this person
	# to grab it left them with full hands and the audit reading LOOSE.
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
	# Force the carry so this measures the state the bug was reported in,
	# instead of whatever the AI happened to be doing. `host_drop()` first because the
	# round opens with the slipper already in hand, and a CARRIED slipper is not
	# grabbable — the re-grab is what puts it in a known pose to measure.
	# ⚠️ WAIT FOR `can_act()`, WHICH IS THE GATE THAT ACTUALLY REFUSED. Measured, not
	# guessed: the audit read `can_act=false` for several seconds after `round_active`
	# went true, so "the round is live" and "this Person may pick something up" are
	# not the same instant and the probe was grabbing in the gap between them.
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
	# ⚠️ CARRIED IS 1, AND THE OLD LINE SAID 2. `Slipper.CarryState` is
	# { LOOSE, CARRIED, FLYING }; the deleted `Carriable.CarryState` ordered them
	# differently, so the annotation was quietly wrong the moment the class changed.
	# ⚠️ THE GATES ARE PRINTED, NOT ASSUMED. `host_grab()` is silent when it refuses,
	# so a bare "carry state 0" says the audit failed without saying why — and this
	# probe exists to measure instead of reasoning about it. Every term of
	# `Slipper.can_be_grabbed_by()` is listed beside the result.
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
	# ⚠️ NO `capsule_height()` ON A PROP — that was a `CharacterBase` accessor and a
	# Slipper is not one. The mesh bounds printed below are the honest measurement of
	# how big the thing in the hand is, which is what this probe was ever about.
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
