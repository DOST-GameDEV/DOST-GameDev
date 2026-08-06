extends Node

const EMOTE: String = "yes"

var _fails: int = 0

func _ready() -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.0).timeout

	var persons: Array[Node] = []
	for node in main.find_children("*", "CharacterBase", true, false):
		if node.get("is_person"):
			persons.append(node)
	_check(persons.size() >= 2, "found at least two Persons (%d)" % persons.size())
	if persons.size() < 2:
		_finish()
		return
	var me: Node = null
	var other: Node = null
	for p in persons:
		if not p.is_ai_driven() and me == null:
			me = p
		elif other == null:
			other = p
	_check(me != null, "found the keyboard-driven Person")
	if me == null:
		_finish()
		return
	var rig := me.get_node_or_null("CameraRig")
	_check(rig != null, "the emoting body has a CameraRig")

	var visual: Node = me.get_node_or_null("Visual")
	if visual == null:
		for node in me.find_children("*", "CharacterVisual", true, false):
			visual = node
			break
	_check(visual != null, "the emoting body has a CharacterVisual")
	for entry in EmoteWheel.EMOTES:
		var id: String = String(entry["id"])
		_check(visual.EMOTE_CLIPS.has(id),
			"wheel offers '%s' and EMOTE_CLIPS has it" % id)

	_check(visual._animator != null
		and visual._animator.has_animation(visual.DANCE_CLIP),
		"the generated dance clip is on this body's AnimationPlayer")
	var dance: Animation = (visual._animator.get_animation(visual.DANCE_CLIP)
		if visual._animator != null
			and visual._animator.has_animation(visual.DANCE_CLIP) else null)
	_check(dance != null and dance.get_track_count() == 8,
		"it has a track per bone plus the root's position (%d)"
			% (dance.get_track_count() if dance != null else -1))
	var resolved := 0
	if dance != null:
		var animator_root: Node = visual._animator.get_node(visual._animator.root_node)
		for track in range(dance.get_track_count()):
			var path: NodePath = dance.track_get_path(track)
			var target: Node = animator_root.get_node_or_null(NodePath(path.get_concatenated_names()))
			if target is Skeleton3D \
					and (target as Skeleton3D).find_bone(path.get_concatenated_subnames()) >= 0:
				resolved += 1
	_check(dance != null and resolved == dance.get_track_count(),
		"every dance track resolves to a real bone on this model (%d of %d)"
			% [resolved, dance.get_track_count() if dance != null else -1])
	if dance != null:
		var seam_ok := true
		for track in range(dance.get_track_count()):
			var last := dance.track_get_key_count(track) - 1
			if last < 1:
				continue
			var first_value = dance.track_get_key_value(track, 0)
			var last_value = dance.track_get_key_value(track, last)
			if typeof(first_value) == TYPE_QUATERNION:
				if not (first_value as Quaternion).is_equal_approx(last_value):
					seam_ok = false
			elif not (first_value as Vector3).is_equal_approx(last_value):
				seam_ok = false
		_check(seam_ok, "the loop is seamless — last key equals first on every track")

	_check(me.can_emote(), "can_emote() true at rest")
	me.play_emote(EMOTE)
	await get_tree().process_frame
	_check(me.is_emoting(), "is_emoting() true after play_emote")
	_check(rig.is_emote_view(), "the camera went to the emote view")

	await get_tree().create_timer(3.0).timeout
	_check(me.is_emoting(), "still emoting after 3 s — the clip loops")
	_check(rig.is_emote_view(), "and the camera is still in the emote view")
	_check(visual._animator.is_playing(), "a LOOPING emote is still playing at 3 s")
	me.stop_emote()
	await get_tree().process_frame

	me.play_emote("sit")
	await get_tree().create_timer(3.0).timeout
	_check(me.is_emoting(), "SIT DOWN is still held at 3 s")
	_check(not visual._animator.is_playing(),
		"and it is NOT replaying — the pose stays put")
	_check(rig.is_emote_view(), "camera still in the emote view while held")
	me.stop_emote()
	await get_tree().process_frame
	_check(not me.is_emoting() and not rig.is_emote_view(), "and it releases cleanly")
	me.play_emote(EMOTE)
	await get_tree().process_frame

	me.play_emote(EMOTE)
	await get_tree().process_frame
	var visual_root: Node = me.get_node_or_null("Visual")
	var hidden: Array[String] = []
	if visual_root != null:
		for node in visual_root.find_children("*", "GeometryInstance3D", true, false):
			var gi := node as GeometryInstance3D
			if gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				hidden.append(gi.name)
	_check(hidden.is_empty(), "the whole body is drawn in the emote view%s"
		% ("" if hidden.is_empty() else " — still hidden: " + ", ".join(hidden)))
	me.stop_emote()
	await get_tree().process_frame
	me.play_emote(EMOTE)
	await get_tree().process_frame

	var other_rig := other.get_node_or_null("CameraRig")
	if other_rig != null:
		_check(not other_rig.is_emote_view(),
			"another player's camera did NOT follow someone else's emote")

	Input.action_press("move_up")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("move_up")
	await get_tree().process_frame
	_check(not me.is_emoting(), "moving cancelled the emote")
	_check(not rig.is_emote_view(), "the camera came back out of the emote view")

	me.play_emote(EMOTE)
	await get_tree().process_frame
	_check(me.is_emoting(), "emoting again for the state check")
	me.state = me.State.DOWNED
	me.state_changed.emit(me.State.DOWNED)
	await get_tree().process_frame
	_check(not me.is_emoting(), "a knockdown cancelled the emote")
	_check(not rig.is_emote_view(), "the camera came back after the knockdown")

	print("    (state here is %d, NORMAL is %d)" % [me.state, me.State.NORMAL])
	if me.state != me.State.NORMAL:
		_check(not me.can_emote(), "can_emote() false while not NORMAL")
	else:
		_check(me.can_emote(), "recovered to NORMAL, and can_emote() is true again")

	var slippers := get_tree().get_nodes_in_group("slippers")
	if slippers.is_empty():
		_check(false, "found a slipper to carry")
	else:
		var shoe: Node = slippers[0]
		shoe.carrier = me
		me.notify_holding(shoe)
		shoe._set_state(shoe.CarryState.CARRIED)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(me.holding_slipper(), "the test slipper is being carried")
		var worst := 0.0
		var worst_emote := ""
		var parented_always := true
		for entry in EmoteWheel.EMOTES:
			var id: String = String(entry["id"])
			me.play_emote(id)
			var baseline := Vector3.INF
			for _f in 30:
				await get_tree().process_frame
				if not me.holding_slipper():
					break
				var hand: Node3D = me.get_hand_attachment()
				if hand == null:
					continue
				if shoe.get_parent() != hand:
					parented_always = false
				var local: Vector3 = hand.global_transform.affine_inverse() * shoe.global_position
				if baseline == Vector3.INF:
					baseline = local
					continue
				var drift: float = (local - baseline).length()
				if drift > worst:
					worst = drift
					worst_emote = id
			_check(me.holding_slipper(), "still holding the slipper through '%s'" % id)
			me._apply_stop_emote()
			await get_tree().process_frame
		_check(parented_always, "the slipper stayed parented to the hand bone throughout")
		print("    (worst grip drift %.4f m, during '%s')" % [worst, worst_emote])
		_check(worst < 0.01, "the grip never shifted (%.2f mm worst)" % (worst * 1000.0))

	var stuck := ""
	for i in 12:
		me.play_emote(EMOTE)
		for _f in (i % 4):
			await get_tree().process_frame
		me.stop_emote()
		await get_tree().process_frame
		if me.is_emoting():
			stuck = "still emoting after stop (pass %d)" % i
			break
		if rig.is_emote_view():
			stuck = "still in emote view after stop (pass %d)" % i
			break
		if visual._action_clip != "":
			stuck = "locomotion still blocked by '%s' (pass %d)" % [visual._action_clip, i]
			break
	_check(stuck == "", "12 start/interrupt cycles left no stuck state%s"
		% ("" if stuck == "" else " — " + stuck))

	me.stop_emote()
	me.stop_emote()
	await get_tree().process_frame
	_check(not me.is_emoting() and not rig.is_emote_view(),
		"stop_emote() twice with nothing playing is a no-op")
	me.play_emote(EMOTE)
	me.play_emote("sit")
	await get_tree().process_frame
	_check(me.is_emoting(), "starting a second emote over the first still leaves one running")
	me.stop_emote()
	await get_tree().process_frame
	_check(not me.is_emoting() and not rig.is_emote_view() and visual._action_clip == "",
		"and one stop clears it")

	var cam_bad := ""
	var fpp: Camera3D = rig.fpp_camera
	var tpp: Camera3D = rig.tpp_camera
	var pitch_before: float = fpp.get_parent().rotation.x
	for i in 8:
		me.play_emote(EMOTE)
		await get_tree().process_frame
		if not tpp.current or fpp.current:
			cam_bad = "mid-emote the wrong camera was current (pass %d)" % i
			break
		me.stop_emote()
		await get_tree().process_frame
		if not fpp.current or tpp.current:
			cam_bad = "after the emote the wrong camera was current (pass %d)" % i
			break
		if rig._mode != rig.Mode.FPP:
			cam_bad = "mode did not return to FPP (pass %d)" % i
			break
		var arms = rig._arms
		if arms != null and is_instance_valid(arms) and not arms.visible:
			cam_bad = "the viewmodel arms stayed hidden (pass %d)" % i
			break
	_check(cam_bad == "", "8 emote cycles left the camera clean%s"
		% ("" if cam_bad == "" else " — " + cam_bad))
	_check(absf(fpp.get_parent().rotation.x - pitch_before) < 0.001,
		"first-person pitch came back unchanged")

	_finish()

func _finish() -> void:
	print("\n[emote probe] %s" % ("ALL CHECKS PASSED" if _fails == 0
		else "%d CHECK(S) FAILED" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])

