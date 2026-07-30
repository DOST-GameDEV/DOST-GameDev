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
## `-- map=eskinita|bayan_plaza`. Ids come from GameLaunch.MAPS, not from a path.
##
## Added 2026-07-29 because this probe had no map argument at all, which meant
## every networked spawn, facing and carry number this project had ever recorded
## described Eskinita — the same gap Checklist.md records for perf_probe and
## ai_probe, in the one harness whose whole job is the networked flow.
var _map_id := &"eskinita"
## `-- can=<id> slipper=<id>`, the two PROP picks this peer takes into the match.
##
## NET-1. Added 2026-07-30 because this probe stood the networked spawn up and
## never once looked at what the Prop was PICKED as — every run so far used the
## default `sarsi`/`goma`, which are roster entry 0 on both lists and carry the
## neutral 3/3/3, so a run in which the picks never crossed the wire at all and
## a run in which they crossed perfectly produce byte-identical trait numbers.
## The ids are the roster's stable ids, same as GameLaunch stores.
var _can_id := &""
var _slipper_id := &""
var _fails: int = 0
var _samples: int = 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var token := String(arg)
		if token == "--host":
			_is_host = true
		elif token.begins_with("map="):
			_map_id = StringName(token.substr(4))
		elif token.begins_with("can="):
			_can_id = StringName(token.substr(4))
		elif token.begins_with("slipper="):
			_slipper_id = StringName(token.substr(8))
		elif token == "graceful":
			_host_quit_graceful = true
		elif token.begins_with("hostquit="):
			# R-25. Passed to BOTH peers: the host to know when to die, the
			# client to know it is running the host-quit beats rather than the
			# round loop.
			_host_quit_at = float(token.substr(9))
	_tag = "HOST" if _is_host else "CLIENT"
	# ⚠️ BEFORE Main.tscn is instantiated — main.gd reads selected_map_scene() as
	# it builds the world, so setting it afterwards silently measures Eskinita
	# while claiming to measure the plaza. That is B-104's failure mode exactly.
	GameLaunch.selected_map = _map_id
	# ⚠️ ALSO BEFORE Main.tscn, and for a second reason on top of the map's.
	# `network_manager.gd::_local_picks()` SNAPSHOTS GameLaunch at connect time
	# (its own doc says so), and the connect happens inside Main's _ready — so a
	# pick written after instantiation is a pick the host is never told about,
	# and the probe would be measuring the default while claiming to measure a
	# pick. Same class of error as B-104.
	if _can_id != &"":
		GameLaunch.selected_can = _can_id
	if _slipper_id != &"":
		GameLaunch.selected_slipper = _slipper_id
	print("[%s] map=%s can=%s(%d) slipper=%s(%d)" % [
		_tag, _map_id,
		GameLaunch.selected_can, GameLaunch.can_index(),
		GameLaunch.selected_slipper, GameLaunch.slipper_index()])

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

	# R-25 · THE HOST QUITS MID-ROUND. Branches before the round loop so the
	# quit lands with a round genuinely live, which is the case that matters —
	# a host leaving between rounds tears down far less.
	if _host_quit_at > 0.0:
		await _run_host_quit()
		return

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

	# ⚠️ A CARRIED OR AIRBORNE PROP CANNOT MOVE ITSELF, BY DESIGN, AND THAT IS NOT
	# AN INPUT FAILURE. `Carriable.drives_movement()` is true for CARRIED and
	# FLYING, and `character_base.gd::_physics_process` hands the whole frame to
	# `Carriable.physics_step()` in that case — a carried slipper is snapped to its
	# carrier's hand and reads no input at all.
	#
	# This matters because `_reset_world()` AUTO-GRABS the tsinelas for the
	# attacking Person at the start of every round, so a peer that owns the
	# tsinelas is holding an unmovable object for much of the match. Measured: the
	# check reported "bound, but the character did not move" (0.010 m) for a
	# perfectly healthy build, on a slipper the log's own CARRY line showed was in
	# somebody's hand two lines earlier. Two outputs of the same probe disagreeing
	# is what caught it.
	var mine_carriable := mine.get_node_or_null("Carriable") as Carriable
	if mine_carriable != null and mine_carriable.drives_movement():
		print("[%s]    SKIPPED — this peer's unit is a %s prop and cannot self-move." % [
			_tag, "carried" if mine_carriable.state == Carriable.CarryState.CARRIED else "flying"])
		print("[%s]    (binding was verified above; the movement half needs a free unit.)" % _tag)
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
	# ⚠️ STATE IS A GATE TOO, and leaving it out of this line cost a session.
	# STAGGERED / DOWNED / SEALED all refuse input by design, so a Can that is
	# being knocked over reports "bound, but the character did not move" — which
	# reads as an input regression and is the game working. That became a live
	# false alarm the moment B-134 made throws actually knock the can down.
	print("[%s]    state        : %d (0 normal, 1 stagger, 2 DOWNED, 3 SEALED)" % [
		_tag, mine.state])
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
	_report_prop_picks(characters)
	# NET-1(c) — LAST in the sample, deliberately. It shoves and walks the units
	# it measures, so anything above it would be reading a world this had already
	# perturbed. It restores what it touched; the next round's _reset_world()
	# re-places everyone regardless.
	await _measure_prop_observable(characters)

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

## ---------------------------------------------------------------------------
## NET-1 · DID THE PROP PICK CROSS THE WIRE, AND IS IT NEUTRAL BY ACCIDENT?
##
## 🧑 Human report: "add stats for cans and slippers bcz i think theyre all the
## same." The roster data is NOT missing — `CANS` and `SLIPPERS` each carry six
## entries with varied traits, and `CharacterBase.trait_points()` does branch to
## `CharacterRoster.prop_trait()`. So the suspect is the INDEX ARRIVING, and
## there are TWO ways to land on a flat 3/3/3 with no error printed anywhere:
##
##   -1  `picks_for()` returns all -1 for a peer that never published, and
##       `traits_in()` returns {} for any index < 0, which `_trait_value()`
##       resolves to TRAIT_NEUTRAL. This is the silent-neutral trip and it is
##       deliberate — an AI slot, a `--host` session that skipped the CHARACTER
##       screen, and an older peer's unknown index must all stay playable.
##    0  `sarsi` and `goma` are roster entry 0 of their lists and their traits
##       ARE 3/3/3, on purpose ("a player who never opens the CHARACTER screen
##       must get the balance everything else was tuned against"). ⚠️ THIS ONE
##       IS NOT A BUG AND PRODUCES THE IDENTICAL SYMPTOM, so a probe that only
##       asserts "index != -1" would call a stock-default match healthy while
##       reporting the human's exact complaint. Both are printed, separately.
##
## ⚠️ THE INDEX IS NOT THE ANSWER, only the cheap half of it. A resolved
## `trait_points()` of 5 proves a dictionary lookup, not that the trait reached
## the object — that is `_measure_prop_observable()` below, and it is the half
## the PERSON path (`phys_probe -- traits`) has and `prop_trait` never has.
##
## ⚠️ RE-READ EVERY SAMPLE, NEVER CACHED. A Prop is a lata one round and a
## tsinelas the next, so `is_can` flips and the same object answers off a
## different list; this runs on all four round samples for exactly that reason.
func _report_prop_picks(characters: Array[CharacterBase]) -> void:
	for ch in characters:
		if ch.is_person:
			continue
		var index: int = ch.can_index if ch.is_can else ch.slipper_index
		var list_name: String = "CANS" if ch.is_can else "SLIPPERS"
		var entries: Array = CharacterRoster.CANS if ch.is_can else CharacterRoster.SLIPPERS
		var id: String = "?"
		if index >= 0 and index < entries.size():
			id = str(entries[index]["id"])
		# ⚠️ THE LINE THE TWO LOGS ARE DIFFED ON. Everything that must match
		# across peers is on it, in a fixed order, so "every peer's copy of every
		# Prop carries the same indices" is a mechanical comparison of the HOST
		# and CLIENT logs and not a judgement call about two prose paragraphs.
		print("[%s]    PICKS    %-11s is_can=%-5s can_index=%2d slipper_index=%2d -> %s[%2d]=%-9s bilis=%d lakas=%d tatag=%d" % [
			_tag, ch.name, str(ch.is_can), ch.can_index, ch.slipper_index,
			list_name, index, id,
			ch.trait_points(&"bilis"), ch.trait_points(&"lakas"), ch.trait_points(&"tatag")])
		# ⚠️ THIS USED TO TEST `ch.ai_controller != null` AND THAT WAS A HARNESS
		# FAULT, caught by the impossible-number rule on the first run: the HOST
		# log called unit `-4` an AI slot and the CLIENT log called the same unit
		# human-owned, in the same second. `ai_controller` is only ever attached
		# on the host (`_attach_ai`), so on a client every character reads null and
		# the exemption silently inverted into "gate everything".
		#
		# The sentinel peer_id is the fact both peers actually share: real ENet ids
		# are positive, and `_fill_empty_slots_with_placeholders` names an unheld
		# seat `-1 - index`. It is in `character.name` on every peer.
		var is_bot_seat := String(ch.name).begins_with("-")
		# ⚠️ AND SINCE NET-1 A BOT SEAT IS NO LONGER EXEMPT. An AI-held Prop now
		# INHERITS its human teammate's picks (`main.gd::_team_prop_picks`), which
		# is the entire fix — so -1 on a bot Prop is only acceptable when that
		# team's Person seat is a bot too and there was nobody to inherit from.
		var team_person_is_bot := true
		for other in characters:
			if other.is_person and other.team == ch.team:
				team_person_is_bot = String(other.name).begins_with("-")
		if is_bot_seat and team_person_is_bot:
			print("[%s]             (bot Prop on an all-bot team — -1 is correct, not gated.)" % _tag)
			continue
		_samples += 1
		if index < 0:
			_fails += 1
			print("[%s]    *** FAIL: a human-owned Prop resolved index -1 on the %s list." % [_tag, list_name])
			print("[%s]        Its traits are TRAIT_NEUTRAL 3/3/3 by fallback, not by pick," % _tag)
			print("[%s]        and nothing anywhere errors. This is the reported symptom. ***" % _tag)
		elif index == 0:
			print("[%s]             ⚠️ entry 0 — the stock 3/3/3. Correct if nobody picked," % _tag)
			print("[%s]                indistinguishable from the fallback if somebody did." % _tag)

## ---------------------------------------------------------------------------
## NET-1(c) · DOES A PROP'S TRAIT REACH ANYTHING PHYSICAL?
##
## ⚠️ THE HALF NOTHING HAD EVER MEASURED. `_report_prop_picks()` above proves the
## INDEX arrives and that both peers resolve the same one — verified over four
## rounds and both sides of a role swap. It does not prove the trait reaches the
## object: `trait_points()` returning 5 proves a dictionary lookup. The Person
## path has its physical half (`phys_probe -- traits`); `prop_trait` is a
## DIFFERENT function against DIFFERENT lists and has never had one.
##
## Same three observables as that block, so the two are comparable:
##
##   BILIS -> metres actually travelled in a fixed number of frames
##   LAKAS -> m/s of shove this unit's own Hitbox produces
##   TATAG -> m/s KEPT of a fixed shove
##
## ⚠️ RUN ON THE AUTHORITY ONLY. Every one of these is a physics question and a
## peer that does not own the body is reading a replicated transform, so a
## non-authoritative row would measure the synchroniser. Each peer measures the
## Props it owns and the two logs are read side by side.
##
## ⚠️ AND IT RUNS ON EVERY ROUND SAMPLE FOR THE REASON THE PICKS BLOCK DOES:
## `is_can` flips, so the SAME unit answers off the CANS list one round and the
## SLIPPERS list the next. The role swap is the test — a build that cached the
## trait at spawn passes every single-round check and fails here.

## Frames to walk. At SPEED 6.0 a full BILIS spread is +/-10%, so 40 frames
## (0.67 s) separates a 1 from a 5 by ~0.8 m — far above depenetration jitter.
const PROP_WALK_FRAMES: int = 40
## The fixed shove TATAG is asked to absorb, m/s. Same value the Person block
## used, so the two tables can be read against each other. Well under
## MAX_KNOCKBACK_SPEED (14.0), or the clamp would flatten the trait.
const PROP_SHOVE: float = 10.0
## Metres of clear floor a walk direction needs before it is used.
const PROP_WALK_CLEARANCE: float = 3.0

func _measure_prop_observable(characters: Array[CharacterBase]) -> void:
	for ch in characters:
		if ch.is_person or not ch.is_multiplayer_authority():
			continue
		var list_name: String = "CANS" if ch.is_can else "SLIPPERS"
		var bilis := ch.trait_points(&"bilis")
		var lakas := ch.trait_points(&"lakas")
		var tatag := ch.trait_points(&"tatag")

		# ---- LAKAS: what this unit's own Hitbox delivers ---------------------
		# ⚠️ TWO BRANCHES, AND ONLY ONE OF THEM CARRIES THE TRAIT — see the
		# finding printed below. hitbox.gd::_impulse_for asks the Carriable
		# FIRST, and Carriable.knockback_impulse() is the ThrowProfile path.
		var hitbox := ch.get_node_or_null("Hitbox") as Hitbox
		var carriable := ch.get_node_or_null("Carriable") as Carriable
		var flying: bool = carriable != null and carriable.state == Carriable.CarryState.FLYING
		var shove := -1.0
		if hitbox != null and not flying:
			var keep_velocity := ch.velocity
			ch.velocity = Vector3.ZERO
			var impulse: Vector3 = hitbox._impulse_for(false)
			shove = Vector2(impulse.x, impulse.z).length()
			ch.velocity = keep_velocity

		# ---- TATAG: what it accepts of a fixed shove -------------------------
		# ⚠️ apply_knockback REFUSES between rounds, when SEALED and while
		# guarding, all three by design. A refused row reads as a dead trait, so
		# the gates are printed rather than silently producing a 0.
		var kept := -1.0
		var gated: bool = not RoundManager.round_active \
			or ch.state == CharacterBase.State.SEALED
		if not gated:
			var keep_velocity := ch.velocity
			ch.velocity = Vector3.ZERO
			ch.apply_knockback(Vector3(PROP_SHOVE, 0.0, 0.0))
			kept = absf(ch.velocity.x)
			ch.velocity = keep_velocity

		# ---- BILIS: how fast the body actually travels -----------------------
		var walk: Dictionary = await _measure_prop_walk(ch)
		var walked: float = walk.get("speed", -1.0)

		# ⚠️ ONE LINE, FIXED ORDER, SO THE ROLE SWAP IS A MECHANICAL DIFF. Grep
		# both logs for PROPOBS and one unit name: the row must CHANGE between a
		# round where is_can=true and one where it is false, because the unit is
		# answering off a different list. Two identical rows across a swap is the
		# cached-at-spawn bug and is the whole reason this runs every round.
		print("[%s]    PROPOBS  %-11s is_can=%-5s %-8s[%2d]  bilis=%d lakas=%d tatag=%d  ->  walked=%s  shove=%s  kept=%s" % [
			_tag, ch.name, str(ch.is_can), list_name,
			(ch.can_index if ch.is_can else ch.slipper_index), bilis, lakas, tatag,
			"%.3f m/s over %.2f m" % [walked, float(walk.get("metres", 0.0))] if walked >= 0.0
				else ("obstructed" if walked < -1.5 else "carried/flying"),
			"%.3f m/s" % shove if shove >= 0.0 else ("flying — ThrowProfile" if flying else "n/a"),
			"%.3f m/s" % kept if kept >= 0.0 else "gated"])

## Walks a Prop under its own body and returns
## `{"speed": median m/s per frame, "metres": total flat distance}`, restoring
## where it stood. `speed` is -1.0 when the unit cannot be measured.
##
## ⚠️ A CARRIED OR FLYING PROP CANNOT MOVE ITSELF AND THAT IS NOT A DEAD TRAIT.
## `Carriable.drives_movement()` hands the whole frame to the carry code, so a
## tsinelas in somebody's hand reads 0.000 m on a perfectly healthy build — the
## same trap `_check_local_input()` above fell into and documents. `_reset_world()`
## auto-grabs the tsinelas for the attacking Person every round, so the SLIPPER
## side of the swap is unmeasurable for BILIS by design, and says so rather than
## reporting a zero.
##
## ⚠️⚠️ THE HEADLINE IS THE MEDIAN PER-FRAME STEP, NOT THE TOTAL DISTANCE, AND
## THE FIRST CUT OF THIS WAS TOTAL DISTANCE AND WAS WRONG. It ran on two real
## peers and reported a NEUTRAL bilis=3 can travelling 1.034 m while a bilis=1
## can travelled 3.022 m — a slower pick out-walking a faster one, which cannot
## be true, so the metric was the bug (this repo's method note, again). Total
## distance over 40 frames is contaminated two ways at once and both are the
## GAME WORKING: `CONFINEMENT_RADIUS` (5.0) clamps a Can that walks off its base
## circle, and `eskinita` is a narrow alley where 4 m of walk meets the dressing.
## A median step is immune to both — a wall or a clamp shortens the tail, not the
## middle — as long as the unit is free for most of the window.
func _measure_prop_walk(who: CharacterBase) -> Dictionary:
	var blocked := {"speed": -1.0, "metres": 0.0}
	var carriable := who.get_node_or_null("Carriable") as Carriable
	if carriable != null and carriable.drives_movement():
		return blocked
	# Walk toward the most open direction rather than the first passable one:
	# on a map this tight, "not blocked within 3 m" is satisfied by directions
	# with a wall at 3.1 m.
	var space := who.get_world_3d().direct_space_state
	var heading := Vector3.ZERO
	var best := 0.0
	for candidate in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK,
			Vector3(1, 0, 1).normalized(), Vector3(1, 0, -1).normalized(),
			Vector3(-1, 0, 1).normalized(), Vector3(-1, 0, -1).normalized()]:
		var from := who.global_position + Vector3.UP * 0.3
		var query := PhysicsRayQueryParameters3D.create(
			from, from + candidate * PROP_WALK_CLEARANCE)
		query.exclude = [who.get_rid()]
		var hit := space.intersect_ray(query)
		var free: float = PROP_WALK_CLEARANCE
		if not hit.is_empty():
			free = from.distance_to(hit["position"])
		if free > best:
			best = free
			heading = candidate
	if best < 1.5:
		return blocked
	var start := who.global_position
	var keep_transform := who.global_transform
	var keep_velocity := who.velocity
	var speed: float = CharacterBase.SPEED * who.trait_speed_scale()
	var steps: Array[float] = []
	for _frame in PROP_WALK_FRAMES:
		var was := who.global_position
		who.velocity.x = heading.x * speed
		who.velocity.z = heading.z * speed
		await get_tree().physics_frame
		steps.append(Vector2(who.global_position.x - was.x,
			who.global_position.z - was.z).length())
	var travelled := Vector2(who.global_position.x - start.x,
		who.global_position.z - start.z).length()
	who.global_transform = keep_transform
	who.velocity = keep_velocity
	steps.sort()
	var median: float = steps[steps.size() / 2] / _physics_delta()
	# ⚠️ A MEDIAN IS ONLY IMMUNE TO A WALL WHILE THE UNIT IS FREE FOR MOST OF THE
	# WINDOW, AND ON THIS MAP IT SOMETIMES IS NOT. Measured on two real peers: a
	# free tsinelas printed 0.006 m/s beside a total of 1.14 m — pinned for most
	# of the 40 frames and shoved along in a few. Half a metre per second cannot
	# also be 1.14 m of travel, so the row is refused rather than reported.
	if median < speed * 0.5:
		return {"speed": -2.0, "metres": travelled}
	return {"speed": median, "metres": travelled}

func _physics_delta() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)

## ---------------------------------------------------------------------------
## R-25 · A CLEAN HOST-QUIT STORY. `hostquit=SECONDS` on BOTH peers.
##
##   godot --path . --headless tools/net_spawn_probe.tscn -- --host hostquit=10
##   godot --path . --headless tools/net_spawn_probe.tscn -- --join=127.0.0.1 hostquit=10
##
## There is no host migration and there will not be one, so the honest version
## is: every client gets off the dead match promptly, lands somewhere it can
## rejoin from, and leaves nothing behind.
##
## ⚠️ THE 3 s IS MEASURED FROM `server_disconnected`, NOT FROM THE HOST'S QUIT,
## and that is deliberate rather than generous. The gap between a host process
## dying and ENet noticing is a TIMEOUT, not this game's teardown — it is set by
## the peer's own keep-alive and no amount of work in `main.gd` shortens it.
## Both numbers are printed so the split is visible; only the second is gated.
##
## ⚠️ AND THE ORPHAN CHECK IS THE HALF THAT ACTUALLY BITES. Reaching the menu
## while `/root/Main` is still parented — or with four CharacterBase nodes still
## in the tree under a freed scene — is the soft-leak that shows up two rejoins
## later as a match that starts with eight characters. Gated separately from the
## scene change for that reason: they fail differently and mean different things.
const HOST_QUIT_MENU: String = "res://scenes/ui/MultiplayerSetup.tscn"
## Seconds a client may take to leave the dead match, measured from
## `server_disconnected`.
const HOST_QUIT_GRACE: float = 3.0
## How long a client waits for that signal before giving up on the run.
const HOST_QUIT_WAIT: float = 25.0

var _host_quit_at: float = -1.0
var _host_quit_graceful: bool = false
var _disconnect_seen_at: float = -1.0
## ⚠️ CAPTURED IN THE SIGNAL HANDLER, NOT READ OFF GameLaunch LATER. The first
## version checked it after the scene change and reported "landed on the menu
## with no explanation" on both clients — but the message is CONSUMED by the
## screen that shows it (`mode_select.gd` reads it and blanks it), so the probe
## was measuring its own lateness. `main.gd::_on_server_disconnected` connects
## before this does and therefore runs first, so by the time this handler is
## called the message is set and not yet consumed.
var _status_at_disconnect: String = ""

func _on_server_disconnected_probe() -> void:
	_disconnect_seen_at = Time.get_ticks_msec() / 1000.0
	_status_at_disconnect = String(GameLaunch.pending_status_message)
	print("[%s]    server_disconnected at %.2fs" % [_tag, _disconnect_seen_at])

func _run_host_quit() -> void:
	if _is_host:
		# ⚠️ MID-ROUND, AND THE FIRST RUN OF THIS WAS NOT. It quit at
		# round_active=false round=0 — a host leaving the ready phase, which
		# tears down far less than R-25 is about. The host drives one round
		# first, exactly as the round loop above does, and the state it quit in
		# is PRINTED rather than assumed.
		MatchManager.report_round_result(true)
		await get_tree().create_timer(_host_quit_at).timeout
		print("[%s] round_active=%s round=%d — QUITTING NOW (%s)" % [
			_tag, str(RoundManager.round_active), MatchManager.round_number,
			"graceful: disconnect_network() first" if _host_quit_graceful
			else "abrupt: the process simply dies"])
		# R-25 · THE TWO QUITS ARE NOT THE SAME EVENT AND THE DIFFERENCE IS THE
		# WHOLE FINDING. An abrupt death (alt-F4, power, crash) gives the clients
		# nothing but silence, so they wait out ENET_TIMEOUT_MIN — deliberately
		# 10 s, widened for Hamachi jitter, and not a defect. A graceful quit can
		# CLOSE the peer, which ENet announces immediately. Measured both ways.
		if _host_quit_graceful:
			NetworkManager.disconnect_network()
			await get_tree().create_timer(0.5).timeout
		# ⚠️ THE PROCESS DIES. Calling `disconnect_network()` would test a tidy
		# in-process teardown that a real host-quit does not necessarily take —
		# a player alt-F4ing, losing power or closing the window gives the
		# clients nothing but silence, and silence is the case worth proving.
		get_tree().quit(0)
		return

	NetworkManager.server_disconnected.connect(_on_server_disconnected_probe)
	var waited := 0.0
	while _disconnect_seen_at < 0.0 and waited < HOST_QUIT_WAIT:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	_samples += 1
	if _disconnect_seen_at < 0.0:
		_fails += 1
		print("[%s]    *** FAIL: the host quit and this client was never told ***" % _tag)
		print("[%s] === 1 FAILURES ===" % _tag)
		get_tree().quit(1)
		return
	print("[%s]    OK — told the host was gone (ENet took %.2fs to notice)" % [_tag, waited])

	var left_at := -1.0
	var elapsed := 0.0
	while elapsed < HOST_QUIT_GRACE + 2.0:
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == HOST_QUIT_MENU:
			left_at = elapsed
			break
	_samples += 1
	if left_at < 0.0:
		_fails += 1
		print("[%s]    *** FAIL: still on the dead match %.1fs after being told ***"
			% [_tag, elapsed])
	elif left_at > HOST_QUIT_GRACE:
		_fails += 1
		print("[%s]    *** FAIL: took %.2fs to reach %s (grace %.1fs) ***"
			% [_tag, left_at, HOST_QUIT_MENU, HOST_QUIT_GRACE])
	else:
		print("[%s]    OK — reached MultiplayerSetup in %.2fs (grace %.1fs)"
			% [_tag, left_at, HOST_QUIT_GRACE])

	# One frame for the freed scene to actually leave the tree.
	await get_tree().process_frame
	await get_tree().process_frame
	var orphan_main := get_tree().root.get_node_or_null("Main")
	var orphan_characters := get_tree().root.find_children("*", "CharacterBase", true, false)
	_samples += 1
	if orphan_main != null or not orphan_characters.is_empty():
		_fails += 1
		print("[%s]    *** FAIL: orphans left behind — /root/Main=%s, %d CharacterBase ***"
			% [_tag, str(orphan_main != null), orphan_characters.size()])
	else:
		print("[%s]    OK — nothing orphaned: no /root/Main, 0 CharacterBase" % _tag)
	_samples += 1
	var message := _status_at_disconnect
	if message == "":
		_fails += 1
		print("[%s]    *** FAIL: landed on the menu with no explanation for the player ***" % _tag)
	else:
		print("[%s]    OK — the player is told why: \"%s\"" % [_tag, message])

	print("\n[%s] === %s (%d/%d checks clean) ===" % [
		_tag, "ALL CHECKS PASSED" if _fails == 0 else "%d FAILURES" % _fails,
		_samples - _fails, _samples])
	get_tree().quit(1 if _fails > 0 else 0)

func _off_axis(forward: Vector3, target: Vector3) -> float:
	if forward.length() < 0.001:
		return 180.0
	return rad_to_deg(acos(clampf(forward.normalized().dot(target), -1.0, 1.0)))
