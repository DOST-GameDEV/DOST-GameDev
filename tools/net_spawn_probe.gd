extends Node
## Spawn ORIENTATION and CARRIED-SLIPPER STATE, measured on a real two-peer session.
##
## WHY THIS EXISTS AND WHY `spawn_probe.gd` WAS NOT ENOUGH.
##
## "the attacker sometimes spawns facing away from the can" and "the slipper is
## invisible to everyone except the attacker holding it" have both been reported
## across more than ten sessions and re-fixed several times. `spawn_probe.gd`
## has passed every one of those sessions — because it drives the LOCAL flow
## (`main.gd::_start_local_test`), which is a different code path from the one
## the reports come from. A green probe and a broken game were both true at the
## same time, which is exactly how a bug survives ten sessions.
##
## So this one runs two real peers over ENet on 127.0.0.1 and samples BOTH.
##
## It measures three things per round:
##
##   1. The attacker's facing, from the BODY basis.
##   2. The attacker's facing, from the FPP CAMERA. Those are not the same
##      number: `camera_rig.gd::_apply_upright_pose()` rebuilds the eye
##      transform every frame from `_body_yaw()`, which recovers yaw from the
##      forward VECTOR precisely because euler decomposition of a basis with
##      roll in it does not give back the yaw you want. `rotation.y` is what the
##      code intended; the camera forward is what the player actually looks at,
##      and only the second one is evidence.
##   3. The CARRY INVARIANT: a Person's `Carrier._held` must be non-null if and
##      only if some `Carriable.carrier` points back at that Person. A stale
##      `_held` is what hides the slipper — `camera_rig.gd::_apply_carried_self_
##      hide()` keeps that unit's `Visual.visible = false` for as long as its
##      carrier believes it is holding something.
##
## USAGE — two terminals, host first:
##
##   godot --path . --headless tools/net_spawn_probe.tscn -- --host
##   godot --path . --headless tools/net_spawn_probe.tscn -- --join=127.0.0.1
##
## `--host` / `--join=` are read by `main.gd` itself out of
## `OS.get_cmdline_user_args()`; this probe only stands Main.tscn up and reads
## the result, so the code path under test is the real one.
##
## ⚠️ THE PROBE IS NOT THE CURRENT SCENE, AND THAT IS LOAD-BEARING.
##
## Main.tscn is added to `/root` and made `current_scene`; this node stays a
## plain sibling under `/root`. Two independent reasons, both found the hard way
## when the first version of this probe produced a completely empty client log:
##
##   * `network_manager.gd::_rpc_route_to_running_match()` calls
##     `change_scene_to_file(Main.tscn)` on any peer whose `current_scene` is not
##     already Main.tscn. With the probe as the current scene, that guard misses,
##     the root scene is REPLACED, and the probe is freed before it prints a line.
##   * MultiplayerSpawner/Synchronizer address nodes by PATH. With the probe as
##     the scene root, the host's characters live at `NetSpawnProbe/Main/...`
##     and the client's at `Main/...`, so every replication packet fails to
##     resolve — the client log filled with "Node not found" and nothing synced.
##
## Parenting Main at `/root/Main` on both peers fixes both at once.
##
## Exit code is 0 when every sample passed and 1 when any did not, so this is
## usable as a gate and not only as something to read.

## How far off-axis the attacker's facing may be before it counts as wrong.
## Generous on purpose: this tests "is it pointed at the can at all", not aim
## precision. A genuine instance of this bug is 90-180 degrees off.
const FACING_TOLERANCE_DEG: float = 30.0
## Rounds to drive. Roles swap every round, so this exercises both teams in
## both roles rather than whichever pairing round 1 happened to deal.
const ROUNDS: int = 4
## Seconds to let ENet connect and the spawner replicate before sampling.
const CONNECT_WAIT: float = 4.0
## Seconds between rounds. Must clear MatchManager.INTERMISSION_DURATION (3.0)
## plus enough slack for the reset to land on both peers.
const ROUND_WAIT: float = 4.5
## Seconds the HOST lingers after its last round before quitting.
##
## ⚠️ NOT PADDING. When the host drops, the client tears its own match down;
## a client still mid-run goes with it and prints nothing. The host must
## OUTLIVE the client, not merely finish before it.
const HOST_LINGER: float = 10.0

var _tag: String = "?"
var _is_host: bool = false
var _fails: int = 0
var _samples: int = 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			_is_host = true
	_tag = "HOST" if _is_host else "CLIENT"

	# See the class doc: Main goes in as `/root/Main` and becomes the current
	# scene; this node stays a sibling so a scene swap cannot free it.
	var main: Node = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main

	# ⚠️ SAMPLED OFF THE SIGNAL, NOT OFF A WALL CLOCK. The two processes start
	# seconds apart and share no clock, so a timer-driven client samples at an
	# arbitrary offset into a round — by which time the AI has walked off its
	# mark and every reading is contaminated. `round_started` fires on both
	# peers from the same host broadcast, so hanging the sample on it measures
	# the spawn state on each peer and nothing else.
	MatchManager.round_started.connect(_on_round_started)

	await get_tree().create_timer(CONNECT_WAIT).timeout
	_sample("initial spawn")
	await _check_local_input()

	if _is_host:
		# Only the host drives rounds; the client observes what it was told.
		# That asymmetry is the point — a bug that only shows on the peer that
		# did not run the reset is invisible to any single-process probe.
		# ⚠️ report_round_result(), NOT begin_next_round(). They are not
		# interchangeable and the difference invalidated this probe's first
		# results outright.
		#
		# `_reset_world()` — the function that actually places characters — hangs
		# off `round_intermission_started`, which only `report_round_result()`
		# fires. Calling `begin_next_round()` directly advances the round counter
		# and skips placement entirely, so rounds 2+ sampled wherever the AI had
		# wandered rather than where anyone spawned. It read as a facing failure:
		# the AI-driven can had walked onto the attacker's own mark, 0.19 units
		# away, which makes the direction-to-can degenerate and the measured
		# off-axis angle meaningless (94 degrees, from an attacker whose yaw was
		# provably correct). `begin_next_round()` then follows on its own after
		# INTERMISSION_DURATION, from MatchManager._process.
		#
		# The winner alternates so neither side reaches WINS_NEEDED (3) and ends
		# the match before the probe is finished.
		for i in ROUNDS:
			MatchManager.report_round_result(i % 2 == 0)
			await get_tree().create_timer(ROUND_WAIT).timeout
		await get_tree().create_timer(HOST_LINGER).timeout
	else:
		await get_tree().create_timer(ROUND_WAIT * ROUNDS + 4.0).timeout

	print("\n[%s] === %s (%d/%d checks clean) ===" % [
		_tag, "ALL CHECKS PASSED" if _fails == 0 else "%d FAILURES" % _fails,
		_samples - _fails, _samples])
	get_tree().quit(1 if _fails > 0 else 0)

## ---------------------------------------------------------------------------
## CAN THIS PEER MOVE ITS OWN CHARACTER? — 2026-07-29 user report, verbatim:
## "In lan multiplayer we cant move any character, weird, pls fix."
##
## ⚠️ THIS IS THE CHECK THAT DID NOT EXIST, AND ITS ABSENCE IS THE WHOLE BUG.
## Every networked probe so far measured spawn POSITION, FACING and CARRY STATE
## — never whether the human at the keyboard can actually drive the thing. B-30
## changed `player_id` on the networked path from "always 1" to slot-based
## (`main.gd::_build_spawn_data`: `(index % 2) + 1`) and nothing anywhere
## noticed, because `player_id` only decides which INPUT SUFFIX is read and no
## test ever pressed a key.
##
## Two assertions, in order of how much they prove:
##
##   1. The action this peer's own character resolves for "move_up" must be
##      BOUND TO A REAL KEY. p3/p4 are registered-but-unbound on purpose (so an
##      AI can never collide with a human), and p2 is bound to arrows — so a
##      human dealt p2 who presses WASD gets silence, with no error anywhere.
##      This assertion catches that directly and cheaply.
##   2. Pressing that action must actually MOVE the character. This is the end-
##      to-end one: it exercises the authority gate, the freeze branch and the
##      confinement clamp as well as the binding.
##
## Sampled at INITIAL SPAWN deliberately: MatchManager.round_number is still 0
## there, which is the pre-round free-roam window, so `character_base.gd`'s
## between-rounds hard freeze (`not round_active and round_number > 0`) is not
## armed and cannot mask a binding failure as a movement failure.
const MOVE_FRAMES: int = 30
## Well under a walk's real distance over 30 physics frames, but far enough above
## depenetration jitter that a frozen character cannot pass by accident.
const MOVE_MIN_DISPLACEMENT: float = 0.25

func _check_local_input() -> void:
	# The character this machine actually drives: authoritative AND not a bot.
	# Exactly the pair character_base.gd::_action() keys the p1 substitution on,
	# so the probe and the fix agree on what "mine" means.
	var mine: CharacterBase = null
	for node in get_tree().root.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch != null and ch.is_multiplayer_authority() and ch.ai_controller == null:
			mine = ch
			break

	print("\n[%s] --- LOCAL INPUT ---" % _tag)
	_samples += 1
	if mine == null:
		print("[%s]    *** FAIL: this peer owns no human character at all ***" % _tag)
		_fails += 1
		return

	var action := mine.action_name("move_up")
	var events: Array = InputMap.action_get_events(action) if InputMap.has_action(action) else []
	print("[%s]    my character : %s  player_id=%d  is_person=%s  is_can=%s" % [
		_tag, mine.name, mine.player_id, str(mine.is_person), str(mine.is_can)])
	print("[%s]    resolves     : \"move_up\" -> %s  (%d bound event(s))" % [
		_tag, action, events.size()])
	if events.is_empty():
		print("[%s]    *** FAIL: %s IS BOUND TO NO KEY — this peer cannot move, and" % [_tag, action])
		print("[%s]        nothing errors because Input.is_action_pressed() on an" % _tag)
		print("[%s]        unbound action just returns false forever. ***" % _tag)
		_fails += 1
		return

	# End-to-end: press it and see if the body actually goes anywhere.
	var before := mine.global_position
	Input.action_press(action)
	for _i in MOVE_FRAMES:
		await get_tree().physics_frame
	Input.action_release(action)
	var moved := Vector2(mine.global_position.x - before.x, mine.global_position.z - before.z).length()
	print("[%s]    pressed %-14s for %d frames -> moved %.3f m (need >= %.2f)" % [
		_tag, action, MOVE_FRAMES, moved, MOVE_MIN_DISPLACEMENT])
	print("[%s]    gates        : round_active=%s round_number=%d (freeze armed=%s)" % [
		_tag, str(RoundManager.round_active), MatchManager.round_number,
		str(not RoundManager.round_active and MatchManager.round_number > 0)])
	if moved < MOVE_MIN_DISPLACEMENT:
		print("[%s]    *** FAIL: bound, but the character did not move ***" % _tag)
		_fails += 1
	else:
		print("[%s]    OK — this peer can drive its own character." % _tag)

## One physics frame of slack so the sample reads the state AFTER main.gd's own
## round handler has run its placement, not the frame it was announced on.
func _on_round_started(round_number: int, _team_a_is_can: bool) -> void:
	await get_tree().physics_frame
	_sample("round %d" % round_number)

func _sample(label: String) -> void:
	var characters: Array[CharacterBase] = []
	for node in get_tree().root.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch != null:
			characters.append(ch)

	var can: CharacterBase = null
	var attacker: CharacterBase = null
	var taya: CharacterBase = null
	for ch in characters:
		if ch.is_can:
			can = ch
		elif ch.is_person and ch.team_is_can_side:
			taya = ch
		elif ch.is_person:
			attacker = ch

	print("\n[%s] --- %s (team_a_is_can=%s, %d characters) ---" % [
		_tag, label, str(MatchManager.team_a_is_can), characters.size()])
	# The can's own position, printed because every facing number below is
	# measured RELATIVE to it. A can that has been shoved off its base circle
	# makes a correctly-facing attacker read as wrong, and without this line
	# that is indistinguishable from the bug.
	if can != null:
		print("[%s]    CAN      %-11s pos=(%6.2f,%6.2f)" % [
			_tag, can.name, can.global_position.x, can.global_position.z])
	if can == null or attacker == null:
		print("[%s]    MISSING can=%s attacker=%s" % [_tag, str(can), str(attacker)])
		_samples += 1
		_fails += 1
		return

	# ⚠️ FACING IS ONLY GATED ON A ROUND SAMPLE, NEVER ON THE INITIAL ONE.
	#
	# The initial sample fires off a wall-clock timer that has to be long enough
	# for ENet to connect and the spawner to replicate (CONNECT_WAIT), by which
	# point round 1 has been LIVE for several seconds and the AI has been playing
	# it. Measured: the attacker had already run from (0, 6.00) to (-0.28, 2.63)
	# and turned to go back for its slipper — 179 degrees off the can, and
	# completely correct behaviour. Gating that is not a spawn test, it is a test
	# of whether an AI ever turns around, and it fails on a working build.
	#
	# The round samples ARE evidence: they run one physics frame after
	# `round_started`, i.e. immediately after `_reset_world()` placed everyone and
	# before anything has had a frame to move.
	#
	# The carry and visibility invariants below are NOT time-sensitive — they must
	# hold at every instant, mid-round included — so they stay gated throughout.
	_report_facing("ATTACKER", attacker, can, label != "initial spawn")
	if taya != null:
		_report_facing("TAYA", taya, can, false)
	_report_carry(characters)

## One unit's facing, measured two independent ways. Both must agree with the
## direction to the can, and the disagreement between them is itself diagnostic:
## if `rotation.y` is right and the camera is not, the body carries roll or pitch
## that the euler write never cleared.
func _report_facing(label: String, who: CharacterBase, can: CharacterBase, gated: bool) -> void:
	var to_can := can.global_position - who.global_position
	to_can.y = 0.0
	if to_can.length() < 0.01:
		return
	to_can = to_can.normalized()

	var body_forward := -who.global_transform.basis.z
	body_forward.y = 0.0
	var body_deg := _off_axis(body_forward, to_can)

	var cam_deg := -1.0
	var eye := who.get_node_or_null("CameraRig/FppPivot") as Node3D
	if eye != null:
		var eye_forward := -eye.global_transform.basis.z
		eye_forward.y = 0.0
		cam_deg = _off_axis(eye_forward, to_can)

	# Only the attacker's facing, and only on a round sample, is a pass/fail gate
	# (see the call site). The taya is printed for context — "guarding the can"
	# does not imply "nose pointed at it", so holding it to the same bar would
	# fail on correct behaviour.
	var ok := body_deg < FACING_TOLERANCE_DEG and (cam_deg < 0.0 or cam_deg < FACING_TOLERANCE_DEG)
	if gated:
		_samples += 1
		if not ok:
			_fails += 1
	print("[%s]    %-8s %-11s pos=(%6.2f,%6.2f) yaw=%7.1f  body_off=%5.1f  cam_off=%5.1f  %s" % [
		_tag, label, who.name, who.global_position.x, who.global_position.z,
		rad_to_deg(who.rotation.y), body_deg, cam_deg,
		("" if not gated else ("OK" if ok else "*** FACING WRONG ***"))])

## THE CARRY INVARIANT. `Carrier._held` and `Carriable.carrier` are two halves of
## one fact and are set from the same host broadcast, so they must agree on every
## peer. When they do not, the loser is always the same: a Person whose `_held`
## still points at a slipper that no longer considers itself carried keeps that
## slipper's `Visual` hidden on that Person's machine forever, and can never grab
## anything again (`carrier.gd::_step_grab` bails on `_held != null`).
##
## Also reports `Visual.visible` per unit, since that is the symptom the human
## actually sees and it is worth having the raw flag next to the invariant that
## explains it.
func _report_carry(characters: Array[CharacterBase]) -> void:
	# Who each slipper thinks is carrying it.
	#
	# ⚠️ `state == CARRIED` IS PART OF THE QUESTION, NOT A TIGHTENING OF IT.
	# `Carriable.carrier` deliberately STAYS SET through the whole flight —
	# _rpc_set_flying() clears the Person's `_held` but keeps `carrier` so landing
	# can drop the collision exception against the thrower (its own B-75 note says
	# so). So a thrown slipper legitimately reads "carrier = X, X.held() = null",
	# and an invariant that ignored the state flagged every throw as a bug. It did
	# exactly that on the first run of this check.
	#
	# Restricting to CARRIED loses nothing: the bug being guarded against is a
	# `_held` that outlives the carry, and the slipper is LOOSE by then.
	var claimed: Dictionary = {} # CharacterBase (person) -> CharacterBase (slipper)
	for ch in characters:
		var carriable := ch.get_node_or_null("Carriable") as Carriable
		if carriable == null or carriable.state != Carriable.CarryState.CARRIED:
			continue
		if carriable.carrier != null and is_instance_valid(carriable.carrier):
			claimed[carriable.carrier] = ch

	for ch in characters:
		var carrier := ch.get_node_or_null("Carrier") as Carrier
		if carrier == null or not ch.is_person:
			continue
		var held: Carriable = carrier.held()
		var held_name: String = "none"
		if held != null and is_instance_valid(held):
			held_name = str(held.get_parent().name)
		var claim: CharacterBase = claimed.get(ch, null) as CharacterBase
		var claim_name: String = str(claim.name) if claim != null else "none"
		var agrees := held_name == claim_name
		_samples += 1
		if not agrees:
			_fails += 1
		print("[%s]    CARRY    %-11s held=%-10s claimed_by_slipper=%-10s %s" % [
			_tag, ch.name, held_name, claim_name,
			"OK" if agrees else "*** STALE _held — SLIPPER WILL BE INVISIBLE HERE ***"])

	# THE SYMPTOM ITSELF, gated rather than merely printed.
	#
	# A Prop's `Visual` may be hidden on this machine for exactly one legitimate
	# reason: the player at THIS keyboard is holding it, and is looking through
	# their own first-person eyes, so they see the viewmodel's `HeldSlipper`
	# instead of the world one (camera_rig.gd::_apply_carried_self_hide). Hidden
	# in any other circumstance is the reported bug — "invisible to everyone
	# except the attacker holding it" — and hidden while nobody local holds it is
	# a self-hide that was never restored.
	var main := get_tree().root.get_node_or_null("Main")
	var local: CharacterBase = null
	if main != null and main.has_method("get_local_character"):
		local = main.get_local_character() as CharacterBase
	var local_carrier: Carrier = null
	if local != null:
		local_carrier = local.get_node_or_null("Carrier") as Carrier
	var local_held: Carriable = local_carrier.held() if local_carrier != null else null

	for ch in characters:
		if ch.is_person:
			continue
		var visual := ch.get_node_or_null("Visual") as Node3D
		if visual == null:
			continue
		var carriable := ch.get_node_or_null("Carriable") as Carriable
		var held_by_local := local_held != null and carriable == local_held
		var ok := visual.visible or held_by_local
		_samples += 1
		if not ok:
			_fails += 1
		print("[%s]    VISUAL   %-11s is_can=%-5s visible=%-5s held_by_local=%-5s %s" % [
			_tag, ch.name, str(ch.is_can), str(visual.visible), str(held_by_local),
			"OK" if ok else "*** HIDDEN WITH NO LOCAL CARRIER — THIS IS THE BUG ***"])

func _off_axis(forward: Vector3, target: Vector3) -> float:
	if forward.length() < 0.001:
		return 180.0
	return rad_to_deg(acos(clampf(forward.normalized().dot(target), -1.0, 1.0)))
