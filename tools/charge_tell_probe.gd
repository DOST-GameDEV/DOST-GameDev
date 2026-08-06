extends Node


const HOLD_TIME: float = 1.4

const SAMPLES: int = 24

const VISIBLE_TRAVEL: float = 0.02

const VISIBLE_SWING_DEG: float = 10.0

const BASELINE_CLIP: String = "sprint"

const NET_CONNECT_WAIT: float = 25.0
const NET_LINGER: float = 6.0

var _main: Node
var _fails := 0
var _checks := 0

func _ready() -> void:
	_park_window()
	var mode := ""
	var address := ""
	for arg in OS.get_cmdline_user_args():
		var a := String(arg)
		if a == "--host":
			mode = "host"
		elif a.begins_with("--join="):
			mode = "join"
			address = a.substr("--join=".length())
	if mode == "":
		await _run_local()
	else:
		await _run_net(mode, address)
	print("\nRESULT: %s" % ("FAIL — %d of %d assertions failed" % [_fails, _checks]
		if _fails > 0 else "PASS — %d assertions" % _checks))
	get_tree().quit(1 if _fails > 0 else 0)

func _park_window() -> void:
	if DisplayServer.get_name() == "headless" or "--resolution" in OS.get_cmdline_args():
		return
	var win := get_window()
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	win.size = Vector2i(usable.size.x / 2, usable.size.y / 2)
	var second := "--join" in " ".join(OS.get_cmdline_user_args())
	win.position = usable.position + Vector2i(0, win.size.y if second else 0)

func _run_local() -> void:
	_main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.ai_controller != null:
			ch.ai_controller.set_enabled(false)
	MatchManager.begin_next_round()
	await get_tree().create_timer(0.5).timeout

	var attacker: CharacterBase = null
	var slipper: Slipper = null
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.is_person and not ch.team_is_can_side:
			attacker = ch
	if attacker != null:
		slipper = _slipper_owned_by(attacker)
	if attacker == null or slipper == null:
		print("CHARGE: could not find an attacking Person and a tsinelas")
		_fails += 1
		_checks += 1
		return

	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.ai_controller != null:
			ch.ai_controller.set_enabled(false)
		ch.input_parked = ch != attacker
	var rig := attacker.get_node("CameraRig") as CameraRig
	rig.set_active(true)
	print("\n=== LOCAL · one machine, the charging peer's own view ===")
	var already := (attacker.get_node("Carrier") as Carrier).held()
	if already != null:
		already.host_drop()
		await get_tree().physics_frame
	await _baseline(attacker)
	await _measure_axis(attacker)

	if "--scan" in OS.get_cmdline_user_args():
		await _scan_pose_clip(attacker)

	slipper.host_drop()
	await get_tree().physics_frame
	slipper.global_position = attacker.global_position + Vector3(0.4, 0.3, 0.0)
	await get_tree().physics_frame
	slipper.host_grab(attacker)
	await get_tree().physics_frame
	await get_tree().physics_frame

	await _hold_and_sample(attacker, rig, "local")

func _scan_pose_clip(subject: CharacterBase) -> void:
	var visual := subject.get_node_or_null("Visual") as CharacterVisual
	if visual == null:
		return
	var animator := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var hand: Node3D = visual.get_hand_attachment()
	if animator == null or hand == null:
		return
	print("\n  pose scan · every clip on this rig, hand in CHARACTER space")
	print("    %-26s %6s %8s %8s %8s" % ["clip", "len", "travel", "peak dY", "peak dZ"])
	animator.play("idle")
	await get_tree().process_frame
	var rest := subject.to_local(hand.global_position)
	var best := ""
	var best_score := -INF
	var names := animator.get_animation_list()
	names.sort()
	for clip in names:
		var length := animator.get_animation(clip).length
		var travel := 0.0
		var peak_y := 0.0
		var peak_z := 0.0
		var prev := rest
		animator.play(clip)
		animator.pause()
		for i in 21:
			animator.seek(float(i) / 20.0 * length, true)
			await get_tree().process_frame
			var p := subject.to_local(hand.global_position)
			travel += p.distance_to(prev)
			prev = p
			if absf(p.y - rest.y) > absf(peak_y):
				peak_y = p.y - rest.y
			if absf(p.z - rest.z) > absf(peak_z):
				peak_z = p.z - rest.z
		var score := peak_y - peak_z
		if score > best_score:
			best_score = score
			best = clip
		print("    %-26s %6.2f %8.4f %+8.3f %+8.3f" % [clip, length, travel, peak_y, peak_z])
	print("    furthest UP and BACK: %s (score %+.3f)" % [best, best_score])
	print("    for reference, the pose this build actually uses is a BONE rotation: %s by %.2f rad about %s"
		% [str(CharacterVisual.CHARGE_POSE_BONES), CharacterVisual.CHARGE_POSE_RAD,
			str(CharacterVisual.CHARGE_POSE_AXIS)])
	animator.play("idle")
	await get_tree().process_frame

func _measure_axis(subject: CharacterBase) -> void:
	var visual := subject.get_node_or_null("Visual") as CharacterVisual
	if visual == null or visual.get_child_count() == 0:
		return
	var model := visual.get_child(0) as Node3D
	var skeletons := model.find_children("*", "Skeleton3D", true, false) if model != null else []
	var hand: Node3D = visual.get_hand_attachment()
	if skeletons.is_empty() or hand == null:
		return
	var skeleton := skeletons[0] as Skeleton3D
	var bone := -1
	var bone_name := ""
	for candidate in CharacterVisual.CHARGE_POSE_BONES:
		bone = skeleton.find_bone(candidate)
		if bone != -1:
			bone_name = candidate
			break
	if bone == -1:
		print("  axis: this rig has none of %s" % str(CharacterVisual.CHARGE_POSE_BONES))
		return
	var animator := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator != null:
		animator.pause()
	visual.set_process(false)
	var rest_rot := skeleton.get_bone_pose_rotation(bone)
	await get_tree().process_frame
	await get_tree().process_frame
	var rest := subject.to_local(hand.global_position)
	print("\n  axis · %s, %.2f rad, hand in CHARACTER space (+Y up, BACK is -Z)"
		% [bone_name, CharacterVisual.CHARGE_POSE_RAD])
	print("    rest hand %s" % _v(rest))
	print("    bones (origin in CHARACTER space, * = the one being driven)")
	for b in skeleton.get_bone_count():
		var origin := subject.to_local(skeleton.global_transform
			* skeleton.get_bone_global_pose(b).origin)
		print("      %s%-18s parent %-3d origin %s" % ["* " if b == bone else "  ",
			skeleton.get_bone_name(b), skeleton.get_bone_parent(b), _v(origin)])
	print("    %-6s %-26s %8s %8s %8s" % ["axis", "hand", "dY", "dZ", "travel"])
	var winner := ""
	var winner_travel := 0.0
	for spec in [["+X", Vector3(1, 0, 0)], ["-X", Vector3(-1, 0, 0)],
			["+Y", Vector3(0, 1, 0)], ["-Y", Vector3(0, -1, 0)],
			["+Z", Vector3(0, 0, 1)], ["-Z", Vector3(0, 0, -1)]]:
		var p := Vector3.ZERO
		for _f in 5:
			skeleton.set_bone_pose_rotation(bone, rest_rot
				* Quaternion((spec[1] as Vector3).normalized(), CharacterVisual.CHARGE_POSE_RAD))
			await get_tree().process_frame
			p = subject.to_local(hand.global_position)
		var up_and_back := p.y > rest.y and p.z < rest.z
		var travel := p.distance_to(rest)
		if up_and_back and travel > winner_travel:
			winner_travel = travel
			winner = String(spec[0])
		print("    %-6s %-26s %+8.3f %+8.3f %8.3f  %s" % [spec[0], _v(p),
			p.y - rest.y, p.z - rest.z, travel,
			"up and back" if up_and_back else ""])
	print("    furthest UP-AND-BACK axis: %s (%.3f m of hand travel at full charge)"
		% [winner, winner_travel])
	for sign_ in []:
		var p := Vector3.ZERO
		for _f in 5:
			skeleton.set_bone_pose_rotation(bone, rest_rot
				* Quaternion(Vector3.RIGHT, sign_ * CharacterVisual.CHARGE_POSE_RAD))
			await get_tree().process_frame
			p = subject.to_local(hand.global_position)
		print("    %+.0fX  hand %s  dY %+.3f  dZ %+.3f   %s" % [sign_, _v(p),
			p.y - rest.y, p.z - rest.z,
			"up and back" if p.y > rest.y and p.z < rest.z else "not up-and-back"])
	skeleton.set_bone_pose_rotation(bone, rest_rot)
	visual.set_process(true)
	if animator != null:
		animator.play(animator.current_animation)
	await get_tree().process_frame
	print("    shipping constant: CHARGE_POSE_AXIS %s" % str(CharacterVisual.CHARGE_POSE_AXIS))

func _baseline(subject: CharacterBase) -> void:
	var visual := subject.get_node_or_null("Visual") as CharacterVisual
	var hand: Node3D = visual.get_hand_attachment() if visual != null else null
	if hand == null:
		print("  baseline: no hand attachment — Leg B cannot be measured at all")
		_fails += 1
		_checks += 1
		return
	var animator := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator == null or not animator.has_animation(BASELINE_CLIP):
		print("  baseline: no %s clip to control against" % BASELINE_CLIP)
		_fails += 1
		_checks += 1
		return
	visual.set_process(false)
	animator.play(BASELINE_CLIP)
	var rows: Array = []
	for _i in SAMPLES:
		await get_tree().process_frame
		rows.append({"hand": subject.to_local(hand.global_position)})
	visual.set_process(true)
	var travel := _travel(rows, "hand")
	_assert("baseline · the hand moves when the SKELETON does (control, no charge)",
		travel >= VISIBLE_TRAVEL,
		"travelled %.4f m in character space over %d frames of `%s` — if this is 0 the metric is dead, not the game"
			% [travel, SAMPLES, BASELINE_CLIP])

func _run_net(mode: String, address: String) -> void:
	GameLaunch.pending_action = mode
	GameLaunch.pending_join_address = address
	_main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	_main.name = "Main"
	get_tree().root.add_child.call_deferred(_main)
	await get_tree().process_frame
	get_tree().current_scene = _main
	for _i in int(NET_CONNECT_WAIT * 10.0):
		if not multiplayer.get_peers().is_empty():
			break
		await get_tree().create_timer(0.1).timeout
	_assert("%s · the session is up" % mode, multiplayer.get_peers().size() >= 1,
		"peers %s, unique id %d" % [str(multiplayer.get_peers()), multiplayer.get_unique_id()])
	if multiplayer.get_peers().is_empty():
		print("CHARGE: no peer connected — refusing to report a networked claim")
		return
	await _net_ready_up()
	await get_tree().create_timer(1.0).timeout

	var subject: CharacterBase = null
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.is_person and not ch.team_is_can_side and subject == null:
			subject = ch
	if subject == null:
		print("CHARGE: no attacking Person in the networked match")
		_fails += 1
		_checks += 1
		return
	var mine := subject.get_multiplayer_authority() == multiplayer.get_unique_id()
	print("
=== NET · %s · subject %s (authority %d, local peer %d) — this peer %s ===" % [
		mode, subject.name, subject.get_multiplayer_authority(), multiplayer.get_unique_id(),
		"DRIVES" if mine else "OBSERVES"])

	if mode == "host":
		var slipper := _slipper_owned_by(subject)
		if slipper != null:
			slipper.host_drop()
			await get_tree().physics_frame
			slipper.global_position = subject.global_position + Vector3(0.4, 0.3, 0.0)
			await get_tree().physics_frame
			slipper.host_grab(subject)
			print("  slipper  %s owner_slot=%d (subject slot=%d) grabbable=%s" % [
				slipper.name, slipper.owner_slot, subject.player_slot,
				str(slipper.can_be_grabbed_by(subject))])
		else:
			print("  slipper  NONE owned by this seat — that should be impossible")

	var carrier := subject.get_node("Carrier") as Carrier
	for _f in 120:
		if carrier.held() != null:
			break
		await get_tree().physics_frame
	_assert("%s · the slipper is in hand" % mode, carrier.held() != null,
		"held=%s (replicated from the host either way)" % str(carrier.held()))

	if mine:
		for c in _main.find_children("*", "CharacterBase", true, false):
			var ch := c as CharacterBase
			if ch.ai_controller != null:
				ch.ai_controller.set_enabled(false)
			ch.input_parked = ch != subject
		var rig := subject.get_node("CameraRig") as CameraRig
		rig.set_active(true)
		print("  preconditions  round_active=%s state=%d held=%s parked=%s ai=%s" % [
			str(RoundManager.round_active), subject.state, str(carrier.held() != null),
			str(subject.input_parked),
			str(subject.ai_controller != null and subject.ai_controller.is_enabled())])
		await _hold_and_sample(subject, rig, mode)
	else:
		await _observe_only(subject)
	if mode == "host":
		await get_tree().create_timer(NET_LINGER).timeout

func _net_ready_up() -> void:
	for _i in 60:
		if not bool(_main.get("_awaiting_net_ready")):
			if RoundManager.round_active or bool(_main.get("_counting_down")):
				return
		else:
			_main._rpc_declare_ready.rpc_id(1)
		await get_tree().create_timer(0.5).timeout
		if RoundManager.round_active:
			return
	print("CHARGE: never reached a live round — the ready phase did not complete")

func _hold_and_sample(subject: CharacterBase, rig: CameraRig, tag: String) -> void:
	var by_action := "--action" in OS.get_cmdline_user_args()
	var action := subject.action_name("special_ability")
	_dump_bindings(action, subject.action_name("grab"))
	if by_action:
		Input.action_press(action)
	else:
		_click(true)
	await get_tree().physics_frame
	_assert("%s · a held LEFT CLICK reads as %s" % [tag, action],
		Input.is_action_pressed(action) or by_action,
		"pressed=%s (this is the link settings.cfg used to sever)"
			% str(Input.is_action_pressed(action)))
	var rows := await _sample(subject, rig, tag, action if tag != "local" else "")
	if by_action:
		Input.action_release(action)
	else:
		_click(false)
	await get_tree().physics_frame
	_report(rows, tag, true)

func _click(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(event)

func _dump_bindings(special: String, grab: String) -> void:
	for action in [special, grab, "jump", "bump"]:
		if not InputMap.has_action(action):
			print("  bindings  %-16s ** NO SUCH ACTION **" % action)
			continue
		var names: Array[String] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				names.append("key:%s" % (event as InputEventKey).as_text_physical_keycode())
			elif event is InputEventMouseButton:
				names.append("MOUSE:%d" % (event as InputEventMouseButton).button_index)
			else:
				names.append(event.as_text())
		print("  bindings  %-16s %s" % [action, ", ".join(names)])

func _observe_only(subject: CharacterBase) -> void:
	var rows := await _sample(subject, null, "observer", "", 3)
	_report(rows, "observer", false)

func _sample(subject: CharacterBase, rig: CameraRig, tag: String, hold_action: String,
		spans: int = 1) -> Array:
	var carrier := subject.get_node_or_null("Carrier") as Carrier
	var visual := subject.get_node_or_null("Visual") as CharacterVisual
	var hand: Node3D = visual.get_hand_attachment() if visual != null else null
	var skeleton: Skeleton3D = null
	var bone := -1
	if visual != null and visual.get_child_count() > 0:
		var model := visual.get_child(0) as Node3D
		var skeletons := model.find_children("*", "Skeleton3D", true, false) if model != null else []
		if not skeletons.is_empty():
			skeleton = skeletons[0] as Skeleton3D
			for candidate in CharacterVisual.CHARGE_POSE_BONES:
				bone = skeleton.find_bone(candidate)
				if bone != -1:
					break
	var rows: Array = []
	for i in SAMPLES * spans:
		if hold_action != "":
			Input.action_press(hold_action)
		await get_tree().create_timer(HOLD_TIME / float(SAMPLES)).timeout
		var row := {
			"t": float(i + 1) * HOLD_TIME / float(SAMPLES),
			"local_power": carrier.charge_power() if carrier != null else -1.0,
			"observed_power": carrier.observed_charge_power() if carrier != null else -1.0,
			"fist": Vector3.ZERO,
			"hand": Vector3.ZERO,
			"arm_rot": 0.0,
			"anim": "",
			"playing": false,
			"arm_q": Quaternion.IDENTITY,
		}
		if skeleton != null and bone != -1:
			row["arm_q"] = skeleton.get_bone_pose_rotation(bone)
		if visual != null:
			var animator := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if animator != null:
				row["anim"] = animator.current_animation
				row["playing"] = animator.is_playing()
		if rig != null:
			var arms := rig.find_child("ViewmodelArms", true, false) as Node3D
			if arms == null:
				for child in rig.find_children("*", "Node3D", true, false):
					if child.get_node_or_null("RightPivot/Arm") != null:
						arms = child as Node3D
						break
			var arm := arms.get_node_or_null("RightPivot/Arm") as Node3D if arms != null else null
			var fist := arms.get_node_or_null("RightPivot/Arm/HeldSlipper") as Node3D \
				if arms != null else null
			if arm != null:
				row["arm_rot"] = arm.rotation.x
			if fist != null and rig.fpp_camera != null:
				row["fist"] = (rig.fpp_camera as Camera3D).global_transform.affine_inverse() \
					* fist.global_position
		if hand != null and is_instance_valid(hand):
			row["hand"] = subject.to_local(hand.global_position)
		rows.append(row)
	return rows

func _report(rows: Array, tag: String, expect_fpp: bool) -> void:
	var best_from := 0
	var best_len := 0
	var from := -1
	for i in range(rows.size()):
		var charging: bool = float(rows[i]["observed_power"]) >= 0.0
		if charging and from < 0:
			from = i
		if (not charging or i == rows.size() - 1) and from >= 0:
			var to: int = i if not charging else i + 1
			if to - from > best_len:
				best_len = to - from
				best_from = from
			from = -1
	if best_len >= 4 and best_len < rows.size():
		print("  (trimmed to the charging segment: samples %d..%d of %d)"
			% [best_from, best_from + best_len - 1, rows.size()])
		rows = rows.slice(best_from, best_from + best_len)
	print("  %4s %8s %8s   %-24s %-24s %8s  %s"
		% ["t", "local", "observed", "fist (camera space)", "hand (character space)",
			"arm.x", "animator"])
	for row in rows:
		print("  %4.2f %8.3f %8.3f   %-24s %-24s %8.3f  %s%s" % [
			row["t"], row["local_power"], row["observed_power"],
			_v(row["fist"]), _v(row["hand"]), row["arm_rot"],
			row["anim"], " PLAYING" if row["playing"] else " paused"])

	var observed_rise: float = float(rows[-1]["observed_power"]) - float(rows[0]["observed_power"])
	_assert("%s · observed_charge_power rises" % tag,
		float(rows[-1]["observed_power"]) > 0.0,
		"first %.3f last %.3f (delta %+.3f)"
			% [rows[0]["observed_power"], rows[-1]["observed_power"], observed_rise])

	var hand_travel := _travel(rows, "hand")
	var swing := 0.0
	var monotonic := true
	var prev := 0.0
	for row in rows:
		var d := rad_to_deg((rows[0]["arm_q"] as Quaternion).angle_to(row["arm_q"] as Quaternion))
		if d < prev - 1.0:
			monotonic = false
		prev = d
		swing = maxf(swing, d)
	_assert("%s · THIRD-PERSON arm swings with the charge" % tag,
		swing >= VISIBLE_SWING_DEG and monotonic,
		"arm-right swept %.1f° (threshold %.0f°), %s with the hold, hand attachment %.4f m — this is the pose every OTHER player looks at"
			% [swing, VISIBLE_SWING_DEG, "rising" if monotonic else "NOT MONOTONIC (a clip, not a wind-up)",
				hand_travel])
	var hand_dy: float = float(rows[-1]["hand"].y) - float(rows[0]["hand"].y)
	var hand_dz: float = float(rows[-1]["hand"].z) - float(rows[0]["hand"].z)
	_assert("%s · that hand goes UP and BACK" % tag, hand_dy > 0.0 and hand_dz < 0.0,
		"dY %+.4f dZ %+.4f in character space (+Y up, BACK is -Z)" % [hand_dy, hand_dz])

	if expect_fpp:
		var fist_travel := _travel(rows, "fist")
		_assert("%s · FIRST-PERSON fist moves with the charge" % tag,
			fist_travel >= VISIBLE_TRAVEL,
			"travelled %.4f m in camera space (threshold %.2f)"
				% [fist_travel, VISIBLE_TRAVEL])
		var dy: float = float(rows[-1]["fist"].y) - float(rows[0]["fist"].y)
		_assert("%s · the fist goes UP, not down" % tag, dy > 0.0,
			"dY %+.4f in camera space (+Y is up)" % dy)

func _travel(rows: Array, key: String) -> float:
	var total := 0.0
	for i in range(1, rows.size()):
		total += (rows[i][key] as Vector3).distance_to(rows[i - 1][key] as Vector3)
	return total

func _assert(what: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("  %s %-52s %s" % ["ok  " if ok else "**  ", what, detail])

func _v(v: Vector3) -> String:
	return "(%+.3f,%+.3f,%+.3f)" % [v.x, v.y, v.z]

func _slipper_owned_by(who: CharacterBase) -> Slipper:
	for node in get_tree().get_nodes_in_group("slippers"):
		var s := node as Slipper
		if s != null and s.owner_slot == who.player_slot:
			return s
	return null

