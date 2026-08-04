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

	_finish()

func _finish() -> void:
	print("\n[emote probe] %s" % ("ALL CHECKS PASSED" if _fails == 0
		else "%d CHECK(S) FAILED" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])
