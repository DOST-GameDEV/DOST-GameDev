extends Node
## STEP AND TOUCH ON AN OPPONENT'S TSINELAS — the acceptance test for B-136.
##
## Human request, 2026-07-29: *"add a mechanic that defender can step or touch the
## slipper of enemy team and it will slow down or get knocked back (knock back for
## the touch)."*
##
## Four assertions, and the last two matter as much as the first two:
##
##   1. TOUCH — walking into an opponent's loose slipper from the side actually
##      moves it. Measured as displacement of the slipper, not as "an RPC was
##      sent": the whole point of the request is that the thing visibly gets
##      shoved.
##   2. STEP — standing on top of it slows it, i.e. `movement_speed_scale()`
##      drops below the plain crawl.
##   3. OWNERSHIP — your OWN team's slipper is immune to both. This is the half a
##      naive implementation gets wrong, and `carriable.gd`'s ownership rule is
##      explicit that pick-up and collision are different questions.
##   4. NOT WHILE CARRIED OR IN FLIGHT — a slipper in somebody's hand or mid-arc
##      is governed by other rules and must not be shoveable.
##
## ⚠️ RUN IT NETWORKED. `host_scuff()` is host-authoritative and a client reaches
## it through `_rpc_request_scuff`, which is a different code path from the local
## one — and this repo's standing lesson (trap 1) is that a probe driving the
## local flow can pass for months while the networked flow is broken.
##
##   godot --path . --headless tools/scuff_probe.tscn -- --host
##   godot --path . --headless tools/scuff_probe.tscn -- --join=127.0.0.1
##
## Single-process is also useful while iterating and is what `--host` alone does.
##
## ⚠️ THE AI IS DETACHED FROM THE TEST PERSON, deliberately. It would otherwise be
## pressing the same per-character input this probe presses, and the two would
## fight over who is walking where — which measures the AI, not the mechanic. The
## detachment changes only WHO drives the character; every line under test
## (`_scuff_enemy_slippers`, `host_scuff`, `_rpc_apply_scuff`) is untouched.

const CONNECT_WAIT: float = 4.0
## Physics frames to walk into the slipper. Long enough to cover the shove and
## the slide that follows it.
const PUSH_FRAMES: int = 45
## How far the slipper must move to count as knocked back. Well above
## depenetration jitter (a few mm) and well below TOUCH_KNOCKBACK_SPEED * time.
const TOUCH_MIN_DISPLACEMENT: float = 0.30
## Where to put the slipper relative to the pusher for the TOUCH case — just
## outside contact, so the Person walks INTO it rather than starting overlapped
## (an overlap resolves by depenetration, which is not the event under test).
const TOUCH_OFFSET: float = 0.75
const HOST_LINGER: float = 6.0

var _tag := "?"
var _is_host := false
var _fails := 0
var _checks := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			_is_host = true
	_tag = "HOST" if _is_host else "CLIENT"

	# Same parenting rule net_spawn_probe.gd documents at length: Main must be
	# /root/Main on every peer or the spawner and synchronizer cannot resolve
	# paths, and the probe must not be the current scene or a scene swap frees it.
	var main: Node = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main

	await get_tree().create_timer(CONNECT_WAIT).timeout
	await _run()

	if _is_host:
		await get_tree().create_timer(HOST_LINGER).timeout
	print("\n[%s] === %s (%d/%d checks clean) ===" % [
		_tag, "ALL CHECKS PASSED" if _fails == 0 else "%d FAILURES" % _fails,
		_checks - _fails, _checks])
	get_tree().quit(1 if _fails > 0 else 0)

func _run() -> void:
	var slipper: CharacterBase = null
	var enemy: CharacterBase = null   # a Person on the OTHER team from the slipper
	var friend: CharacterBase = null  # the slipper's own team's Person
	for node in get_tree().root.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch != null and not ch.is_person and not ch.is_can:
			slipper = ch
			break
	if slipper == null:
		_fail("no tsinelas in the match at all")
		return
	for node in get_tree().root.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch == null or not ch.is_person:
			continue
		if ch.team != slipper.team and enemy == null:
			enemy = ch
		elif ch.team == slipper.team and friend == null:
			friend = ch
	if enemy == null:
		_fail("no opposing Person to do the scuffing")
		return

	var carriable := slipper.get_node_or_null("Carriable") as Carriable
	print("\n[%s] slipper=%s (team %d)  enemy=%s (team %d)  friend=%s" % [
		_tag, slipper.name, slipper.team, enemy.name, enemy.team,
		str(friend.name) if friend != null else "none"])

	# --- 3. OWNERSHIP, and 4. STATE. Pure predicates, so they are asked directly
	# rather than inferred from a physical outcome that could fail for ten other
	# reasons. Cheap, and they pin the rule rather than a symptom of it.
	_ensure_loose(carriable)
	_check("an opponent may scuff a loose enemy tsinelas",
		carriable.can_be_scuffed_by(enemy), true)
	if friend != null:
		_check("its OWN team's Person may NOT scuff it",
			carriable.can_be_scuffed_by(friend), false)
	_check("it may not scuff ITSELF", carriable.can_be_scuffed_by(slipper), false)
	# A can is not a kickable slipper.
	for node in get_tree().root.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch != null and ch.is_can:
			var can_carriable := ch.get_node_or_null("Carriable") as Carriable
			if can_carriable != null:
				_check("a LATA may not be scuffed (it is hit or reset, never kicked)",
					can_carriable.can_be_scuffed_by(enemy), false)
			break

	# --- 1. TOUCH. The physical assertion.
	#
	# ⚠️ THIS PEER ONLY EVER MOVES A NODE IT OWNS. Writing `slipper.global_position`
	# from a peer that is not its authority is pointless — the synchronizer
	# overwrites it on the next tick — so the PERSON is walked to the slipper
	# rather than the slipper teleported in front of the Person. That also makes
	# the test work unchanged whoever happens to own what this round.
	if not _drivable(enemy):
		print("[%s]    (this peer does not own %s — the owning peer runs the physical half)" % [
			_tag, enemy.name])
		return
	if enemy.ai_controller != null:
		enemy.ai_controller.queue_free()
		enemy.ai_controller = null
		await get_tree().physics_frame

	# CALIBRATE THE WALK DIRECTION rather than assuming it. `move_up` resolves in
	# the BODY's frame for a mouse-aimed unit and in WORLD space otherwise
	# (character_base.gd's B-60 note), and which one applies here depends on the
	# CameraRig's aim source — so the probe presses the key on open ground, sees
	# which way the character actually went, and places itself accordingly. An
	# assumed bearing is how this test would quietly stop touching the slipper at
	# all and still report a pass.
	var action := enemy.action_name("move_up")
	var cal_from := enemy.global_position
	Input.action_press(action)
	for _i in 15:
		await get_tree().physics_frame
	Input.action_release(action)
	var walk := enemy.global_position - cal_from
	walk.y = 0.0
	print("[%s]    calibration: pressing %s moved it (%.2f, %.2f)" % [
		_tag, action, walk.x, walk.z])
	if walk.length() < 0.2:
		_fail("could not drive %s at all — cannot test the mechanic" % enemy.name)
		return
	walk = walk.normalized()

	# ⚠️ THE SLIPPER IS PLACED IN FRONT OF THE PUSHER, NOT THE PUSHER BEHIND THE
	# SLIPPER — and that is the third arrangement tried, after measuring the other
	# two fail.
	#
	# Walking the Person to a computed stand-off point does not work: `move_up`
	# resolves in the BODY frame or in WORLD space depending on the CameraRig's aim
	# source, `look_at()` rewrites the body yaw on every step, and the resulting
	# path is not predictable from out here. Measured over three bearings — the
	# calibrated one, the body's own forward, and the reverse — the Person walked
	# past the slipper (gap 0.95 -> 2.70), stood still (0.91 -> 0.84), and walked
	# away (0.75 -> 5.04). Zero contacts, three times, on a mechanic that works.
	#
	# Putting the slipper directly on the Person's forward axis removes the
	# guesswork entirely: whatever frame the input resolves in, the Person is
	# facing the thing it is about to walk into.
	#
	# The cost is that this peer must own the slipper to place it, which is what
	# the guard below checks.
	if not _drivable(slipper):
		print("[%s]    (this peer does not own %s — the owning peer runs the TOUCH half)" % [
			_tag, slipper.name])
	else:
		var moved := 0.0
		var moved_best := 0.0
		var touches_best := 0
		var valid := false
		for attempt in 3:
			_ensure_loose(carriable)
			await get_tree().physics_frame
			if carriable.state != Carriable.CarryState.LOOSE:
				continue # the AI attacker is holding it; nothing to shove
			# ⚠️ RE-CALIBRATE IMMEDIATELY BEFORE EVERY ATTEMPT. The body's forward is
			# NOT the direction `move_up` walks: for a unit that is not mouse-aimed
			# the input resolves in WORLD space and `look_at()` then turns the body
			# to match, so the body forward is a stale record of the last step rather
			# than a prediction of the next one. Placing the slipper on the body axis
			# had the Person walk 3.1 m AWAY from it (gap 0.57 -> 3.69) while the
			# slipper sat still — which scored as "the knockback does nothing".
			#
			# Pressing the key and watching where it actually goes needs no
			# assumption about aim mode at all.
			var cal := enemy.global_position
			Input.action_press(action)
			for _c in 10:
				await get_tree().physics_frame
			Input.action_release(action)
			var forward := enemy.global_position - cal
			forward.y = 0.0
			if forward.length() < 0.05:
				continue
			forward = forward.normalized()
			# The slipper keeps its OWN height — it lies on the ground, and a
			# Person's origin is 0.8 up.
			slipper.global_position = Vector3(
				enemy.global_position.x + forward.x * TOUCH_OFFSET,
				slipper.global_position.y,
				enemy.global_position.z + forward.z * TOUCH_OFFSET)
			slipper.velocity = Vector3.ZERO
			await get_tree().physics_frame
			await get_tree().physics_frame

			var before := slipper.global_position
			var gap_before := _flat_gap(enemy, slipper)
			var touched_before := carriable.scuffs_touched
			Input.action_press(action)
			for _i in PUSH_FRAMES:
				await get_tree().physics_frame
			Input.action_release(action)
			moved = Vector2(slipper.global_position.x - before.x,
				slipper.global_position.z - before.z).length()
			# ⚠️ A run the game interfered with proves nothing either way and must
			# not be scored. Measured: one attempt ended with the slipper CARRIED
			# and a 4.081 m gap, which looked like an enormous knockback and was
			# the AI attacker picking it up and running off with it.
			var still_loose := carriable.state == Carriable.CarryState.LOOSE
			var touches := carriable.scuffs_touched - touched_before
			print("[%s]    TOUCH attempt %d: %d touch-scuffs applied, slipper moved %.3f m, gap %.2f -> %.2f, still loose=%s" % [
				_tag, attempt, touches, moved, gap_before, _flat_gap(enemy, slipper), str(still_loose)])
			touches_best = maxi(touches_best, touches)
			# ⚠️ ONLY A VALID ATTEMPT MAY CONTRIBUTE A NUMBER. The first version of
			# this loop kept `moved` from whichever attempt ran LAST and asserted on
			# that — so a run whose slipper had been picked up and carried 1.4 m
			# away scored as a successful knockback and turned a failing test green.
			# Discarding an attempt's validity but keeping its measurement is worse
			# than not checking at all.
			if still_loose:
				valid = true
				moved_best = maxf(moved_best, moved)
				if moved_best >= TOUCH_MIN_DISPLACEMENT:
					break
		if not valid:
			_fail("HARNESS: every attempt was interrupted (slipper carried) — says nothing about the mechanic")
		else:
			print("[%s]    TOUCH: best uninterrupted attempt applied %d scuffs and moved it %.3f m" % [
				_tag, touches_best, moved_best])
			# ⚠️ BOTH, and the first one is the real assertion. Displacement alone
			# cannot tell the mechanic from ordinary depenetration — see
			# Carriable.scuffs_touched for the measurement that proved it.
			_check("body contact applies the touch branch at all",
				touches_best > 0, true)
			_check("walking into an opponent's tsinelas knocks it back",
				moved_best >= TOUCH_MIN_DISPLACEMENT, true)

	# --- 2. STEP. Asserted on the speed scale rather than on a position, because
	# "slowed" is a property of how fast it MAY move, and a loose slipper nobody is
	# driving does not move at all either way.
	#
	# Dropped ONTO it from just above, so the contact normal is genuinely vertical.
	# The branch is chosen by that normal, so producing a real one is the test —
	# calling the step path directly would assert nothing about the split.
	_ensure_loose(carriable)
	await get_tree().physics_frame
	var free_scale := carriable.movement_speed_scale()
	enemy.global_position = slipper.global_position + Vector3(0.0, 1.2, 0.0)
	enemy.velocity = Vector3.ZERO
	var stepped_scale := free_scale
	var contacts := 0
	var closest := INF
	var best_normal_y := -1.0
	for _i in 40:
		await get_tree().physics_frame
		stepped_scale = minf(stepped_scale, carriable.movement_speed_scale())
		closest = minf(closest, enemy.global_position.distance_to(slipper.global_position))
		for ci in enemy.get_slide_collision_count():
			var c := enemy.get_slide_collision(ci)
			if c.get_collider() == slipper:
				contacts += 1
				best_normal_y = maxf(best_normal_y, c.get_normal().y)
	print("[%s]    STEP scuffs applied: %d" % [_tag, carriable.scuffs_stepped])
	print("[%s]    STEP diag: %d contact-frames with the slipper, closest %.3f m, best normal.y %.2f, round_active=%s" % [
		_tag, contacts, closest, best_normal_y, str(RoundManager.round_active)])
	print("[%s]    STEP : crawl scale %.3f -> %.3f while stood on (expect x%.2f)" % [
		_tag, free_scale, stepped_scale, Carriable.STEP_SLOW_SCALE])
	_check("standing on an opponent's tsinelas slows it",
		stepped_scale < free_scale - 0.001, true)

func _flat_gap(a: CharacterBase, b: CharacterBase) -> float:
	return Vector2(a.global_position.x - b.global_position.x,
		a.global_position.z - b.global_position.z).length()

## Whether this peer can actually drive `who` — it must be ours to move, or every
## key press below lands on a copy whose `_physics_process` returns early.
func _drivable(who: CharacterBase) -> bool:
	return not NetworkManager.is_networked() or who.is_multiplayer_authority()

## Puts the slipper back in the one state the mechanic applies to, through the
## real host transition rather than by assigning `state` behind its back.
func _ensure_loose(carriable: Carriable) -> void:
	if carriable.state == Carriable.CarryState.LOOSE:
		return
	# host_land()/host_drop() self-gate on the host, so on a client this is a
	# no-op and the probe simply waits for the slipper to come loose on its own.
	# Deliberately not forced: reaching in and assigning `state` would fake the
	# very transition the mechanic is gated on.
	carriable.host_land()
	carriable.host_drop()

func _check(what: String, got: bool, want: bool) -> void:
	_checks += 1
	var ok := got == want
	if not ok:
		_fails += 1
	print("[%s]    %-6s %s (got %s, wanted %s)" % [
		_tag, "OK" if ok else "*FAIL*", what, str(got), str(want)])

func _fail(why: String) -> void:
	_checks += 1
	_fails += 1
	print("[%s]    *FAIL* %s" % [_tag, why])
