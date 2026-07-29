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
## Seconds between rounds, long enough for the reset to land on both peers.
const ROUND_WAIT: float = 2.0
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

	if _is_host:
		# Only the host drives rounds; the client observes what it was told.
		# That asymmetry is the point — a bug that only shows on the peer that
		# did not run the reset is invisible to any single-process probe.
		for i in ROUNDS:
			MatchManager.begin_next_round()
			await get_tree().create_timer(ROUND_WAIT).timeout
		await get_tree().create_timer(HOST_LINGER).timeout
	else:
		await get_tree().create_timer(ROUND_WAIT * ROUNDS + 2.0).timeout

	print("\n[%s] === %s (%d/%d checks clean) ===" % [
		_tag, "ALL CHECKS PASSED" if _fails == 0 else "%d FAILURES" % _fails,
		_samples - _fails, _samples])
	get_tree().quit(1 if _fails > 0 else 0)

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
	if can == null or attacker == null:
		print("[%s]    MISSING can=%s attacker=%s" % [_tag, str(can), str(attacker)])
		_samples += 1
		_fails += 1
		return

	_report_facing("ATTACKER", attacker, can)
	if taya != null:
		_report_facing("TAYA", taya, can)
	_report_carry(characters)

## One unit's facing, measured two independent ways. Both must agree with the
## direction to the can, and the disagreement between them is itself diagnostic:
## if `rotation.y` is right and the camera is not, the body carries roll or pitch
## that the euler write never cleared.
func _report_facing(label: String, who: CharacterBase, can: CharacterBase) -> void:
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

	# Only the attacker's facing is a pass/fail gate. The taya is printed for
	# context — "guarding the can" does not imply "nose pointed at it", so
	# holding it to the same bar would fail on correct behaviour.
	var gated := label == "ATTACKER"
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
	var claimed: Dictionary = {} # CharacterBase (person) -> CharacterBase (slipper)
	for ch in characters:
		var carriable := ch.get_node_or_null("Carriable") as Carriable
		if carriable != null and carriable.carrier != null and is_instance_valid(carriable.carrier):
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
