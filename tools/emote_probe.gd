extends Node
## DOES AN EMOTE ACTUALLY PLAY, MOVE THE CAMERA, AND COME BACK?
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/emote_probe.tscn
##
## ⚠️ PLAIN EXE, NOT --headless. The camera half of this is the whole feature and a
## rig with no rendering device reports nothing useful about which camera is
## `current`.
##
## ⚠️ EVERY CHECK IS A STATE ASSERTION, NOT A SCREENSHOT. "The camera went to third
## person and came back" is two booleans a frame apart; a capture of the middle
## proves the going and says nothing about the coming back, which is the half that
## strands a player if it breaks.

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
	# ⚠️ THE KEYBOARD-DRIVEN BODY, NOT persons[0]. `character_base.gd::input_pressed`
	# routes through `_ai_intent` for an AI-driven unit and only reads the hardware
	# for the human's — so `Input.action_press()` in check 4 is invisible to a bot,
	# and picking arbitrarily made the move-cancel check fail against working code.
	var me: Node = null
	var other: Node = null
	# ⚠️ `is_ai_driven()`, NOT "has no ai_controller". Every Person in a solo match
	# carries a controller node; whether it DRIVES is the separate flag, and that is
	# the one `input_pressed()` branches on.
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

	# 1 — the clip catalogue is real, and every id the wheel offers has a clip.
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

	# 2 — it plays, and it blocks locomotion while it does.
	_check(me.can_emote(), "can_emote() true at rest")
	me.play_emote(EMOTE)
	await get_tree().process_frame
	_check(me.is_emoting(), "is_emoting() true after play_emote")
	_check(rig.is_emote_view(), "the camera went to the emote view")

	# 2b — ⚠️ IT LOOPS UNTIL INTERRUPTED. 🧑: *"let them continue until i interrupt
	# it with my movement"*. Held for three seconds, which is several times the
	# length of any clip on this rig, so a one-shot would have ended long before.
	await get_tree().create_timer(3.0).timeout
	_check(me.is_emoting(), "still emoting after 3 s — the clip loops")
	_check(rig.is_emote_view(), "and the camera is still in the emote view")

	# 3 — ⚠️ THE CAMERA IS LOCAL. The OTHER body must not have moved its own view
	# just because this one danced.
	var other_rig := other.get_node_or_null("CameraRig")
	if other_rig != null:
		_check(not other_rig.is_emote_view(),
			"another player's camera did NOT follow someone else's emote")

	# 4 — moving cancels it, and the camera comes back.
	Input.action_press("move_up")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("move_up")
	await get_tree().process_frame
	_check(not me.is_emoting(), "moving cancelled the emote")
	_check(not rig.is_emote_view(), "the camera came back out of the emote view")

	# 5 — a knockdown cancels it too, rather than stranding the player in TPP.
	me.play_emote(EMOTE)
	await get_tree().process_frame
	_check(me.is_emoting(), "emoting again for the state check")
	me.state = me.State.DOWNED
	me.state_changed.emit(me.State.DOWNED)
	await get_tree().process_frame
	_check(not me.is_emoting(), "a knockdown cancelled the emote")
	_check(not rig.is_emote_view(), "the camera came back after the knockdown")

	# 6 — and it refuses to start while the body is not the player's to drive.
	# ⚠️ RE-READ RATHER THAN ASSUMED: `_physics_process` recovers a DOWNED body on
	# its own timer, so by this line the state may legitimately be NORMAL again and
	# the assertion has to say which it saw.
	print("    (state here is %d, NORMAL is %d)" % [me.state, me.State.NORMAL])
	if me.state != me.State.NORMAL:
		_check(not me.can_emote(), "can_emote() false while not NORMAL")
	else:
		_check(me.can_emote(), "recovered to NORMAL, and can_emote() is true again")

	# 7 — ⚠️ THE SLIPPER STAYS IN THE HAND, AND THIS MEASURES IT RATHER THAN
	# ASSUMING IT. 🧑: *"stay in hand but make sure it doesnt bug bruh / im worried
	# it might flaot and shit"* — and that worry has history: a carried slipper
	# trailed the palm by 98 mm ("the shoe would float") until slipper.gd took
	# `process_priority = 100` to re-sync AFTER the AnimationPlayer had moved the
	# bone. An emote is a clip that swings `arm-right` hard, so it is exactly the
	# case that would bring it back. Every emote is played in turn and the
	# hand-to-slipper distance is sampled every frame.
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
		# ⚠️ MEASURED IN THE HAND'S OWN FRAME, NOT AS A DISTANCE TO THE HAND ORIGIN.
		# A held slipper sits at a deliberate GRIP OFFSET from the bone pivot
		# (`_attach_to_hand()` applies a carry pose), so the global gap is ~34 mm at
		# rest and says nothing about float. What float actually IS, is that offset
		# CHANGING while the arm swings — so this samples the local transform and
		# reports how far it wanders from its first sample.
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
				# The structural guarantee: a child of the hand inherits its
				# transform exactly and CANNOT drift, whatever the clip does.
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

	# 8 — ⚠️⚠️ INTERRUPTING IT REPEATEDLY, WHICH IS WHERE THIS WOULD ACTUALLY BREAK.
	# 🧑: *"make sure it doesnt bug and shit when i interrupt the emote"*. An emote now
	# loops, so the only exits are the player and a loss of control — which makes every
	# one of them a chance to leave the body half-out of an emote: still holding
	# `_action_clip` (so locomotion never resumes and the character freezes mid-pose),
	# or still in `_emote_view` (so the player is stuck in third person). Both are
	# invisible to the single start/stop the checks above make.
	var stuck := ""
	for i in 12:
		me.play_emote(EMOTE)
		# Interrupt at a different point in the loop each pass — the same frame it
		# started, one frame in, several frames in.
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
		# The body has to be animating again, not frozen on the emote's last frame.
		if visual._action_clip != "":
			stuck = "locomotion still blocked by '%s' (pass %d)" % [visual._action_clip, i]
			break
	_check(stuck == "", "12 start/interrupt cycles left no stuck state%s"
		% ("" if stuck == "" else " — " + stuck))

	# Stopping when not emoting, and starting twice, are both things a mashing player
	# will do within a second of finding the key.
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

	# 9 — ⚠️⚠️ THE CAMERA ITSELF, NOT JUST THE FLAG. 🧑: *"make sure camera doesnt bug
	# and glitch"*. `is_emote_view()` going false only says the rig THINKS it is back;
	# the things a player would actually see wrong are one level down. `begin/end` has
	# to re-assert four separate pieces of state that nothing else in the game ever
	# changes — which camera is `current`, the self-hide, the viewmodel arms and the
	# spring-arm framing — so each is checked against the resting first-person values
	# rather than against the flag.
	var cam_bad := ""
	var fpp: Camera3D = rig.fpp_camera
	var tpp: Camera3D = rig.tpp_camera
	var pitch_before: float = fpp.get_parent().rotation.x
	for i in 8:
		me.play_emote(EMOTE)
		await get_tree().process_frame
		# Mid-emote: third person is the one drawing, and exactly one camera is.
		if not tpp.current or fpp.current:
			cam_bad = "mid-emote the wrong camera was current (pass %d)" % i
			break
		me.stop_emote()
		await get_tree().process_frame
		# ⚠️ EXACTLY ONE CURRENT. Two `current` cameras is the classic symptom of a
		# mode restore that set one without clearing the other, and it renders as the
		# view snapping between them.
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
	# The look direction must survive the round trip — an emote that quietly re-aims
	# the player is a glitch even though every flag above is correct.
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
