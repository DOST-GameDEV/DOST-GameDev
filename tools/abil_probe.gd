extends Node
## ABILITY ACCEPTANCE — `build abil`, § CHECKLIST §3. Written 2026-07-31.
##
## The five object verbs (`Design.md` §5.3/§6) were written and never run: not one probe
## fires Can-Smash, Can-Dash, Ground Smash, its direct-hit instant win, or the tsinelas'
## charged self-launch. This is that probe.
##
## ⚠️ NEW FILE, AND A DELIBERATE ONE, same reason `mech_probe.gd` gives: § PATHS gives
## `build abil` no `tools/` row, so this adds a file rather than writing into a later
## lane's probe.
##
##     godot --path . --headless tools/abil_probe.tscn
##
## Local flow only — every check below calls the same functions a real press reaches
## (`_try_prop_smash()`, `jump_charge_step()`, `_process_can_dash()`'s own input path),
## and the shockwaves themselves resolve through `hitbox.gd`'s host gate exactly as they
## do on a real host. What is NOT proven here is the network half of that gate (no
## second peer exists in this run) — the same limit `mech_probe.gd` states for itself.
##
## ⚠️ EVERY AI CONTROLLER IS DISABLED. A bot pressing its own bump/dash/jump mid-check
## would be indistinguishable from the mechanic under test.
##
## ⚠️ ONLY ONE CHARACTER READS HARDWARE INPUT AT A TIME. With AI disabled, all four
## characters fall back to `Input`-polling (`is_ai_driven()` false for all of them) — so
## every check that simulates a real keypress parks every character but the one under
## test first (`input_parked = true`), exactly as `debug_player_switcher.gd` does for a
## human taking manual control of a bot.

const BOOT_WAIT: float = 3.0
const COUNTDOWN_WAIT: float = 5.0
## `CAN_SMASH_WINDUP` is 0.35 — this clears it with room for the physics frame the
## timer's own callback needs.
const WINDUP_CLEAR: float = 0.55
## Comfortably short of `CAN_SMASH_WINDUP`, to catch the shockwave NOT having landed yet.
const WINDUP_EARLY: float = 0.12
## Height above the floor to drop a tsinelas from for the Ground Smash checks — well past
## `GROUND_SMASH_MIN_HEIGHT` (0.6) plus half its own capsule, and short enough that the
## 22 m/s dive settles the check quickly.
const DROP_HEIGHT: float = 3.0
const FALL_TIMEOUT_FRAMES: int = 240

var _fails: int = 0
var _checks: int = 0
var _harness: int = 0

func _ready() -> void:
	var main: Node = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main

	await get_tree().create_timer(BOOT_WAIT).timeout
	_press_ready()
	await get_tree().create_timer(COUNTDOWN_WAIT).timeout
	await _run()

	print("\n=== ABIL PROBE: %s (%d/%d checks clean, %d harness) ===" % [
		"ALL CHECKS PASSED" if _fails == 0 else "%d FAILURES" % _fails,
		_checks - _fails, _checks, _harness])
	get_tree().quit(1 if _fails > 0 else 0)

func _press_ready() -> void:
	var event := InputEventAction.new()
	event.action = &"ready_up"
	event.pressed = true
	Input.parse_input_event(event)

func _run() -> void:
	if not RoundManager.round_active:
		_harness_note("the round never started — nothing below is testable")
		return

	var all: Array[CharacterBase] = []
	for node in get_tree().root.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch != null:
			all.append(ch)

	var lata: CharacterBase = null
	var tsinelas: CharacterBase = null
	for ch in all:
		if ch.is_person:
			continue
		if ch.is_can and lata == null:
			lata = ch
		elif not ch.is_can and tsinelas == null:
			tsinelas = ch
	if lata == null or tsinelas == null:
		_harness_note("could not find both a lata and a tsinelas in the match")
		return

	var taya: CharacterBase = null
	var attacker: CharacterBase = null
	for ch in all:
		if not ch.is_person:
			continue
		if ch.team == lata.team:
			taya = ch
		else:
			attacker = ch
	if taya == null or attacker == null:
		_harness_note("could not find both Persons in the match")
		return

	for ch in all:
		if ch.ai_controller != null:
			ch.ai_controller.set_enabled(false)

	print("\n=== ABILITY ACCEPTANCE (§3.1 - §3.5, §3.9) ===")
	print("lata=%s  taya=%s  attacker=%s  tsinelas=%s" % [
		lata.name, taya.name, attacker.name, tsinelas.name])

	var lata_home := lata.global_position

	await _check_can_smash(lata, attacker)
	await _check_can_smash_out_of_range(lata, attacker)
	await _check_can_smash_interrupt(lata, attacker)
	_restore_home(lata, lata_home)

	await _check_can_dash(lata, all)
	_restore_home(lata, lata_home)

	await _check_self_launch(tsinelas, all)

	await _check_ground_smash_and_stun(tsinelas, lata, taya, all)
	await _check_ground_smash_bounded_on_downed(tsinelas, lata, all)
	# ⚠️ LAST. It ends the round on purpose, same discipline `mech_probe.gd`'s own
	# countdown-win check follows, and everything above is gated on `round_active`.
	await _check_ground_smash_instant_win(tsinelas, lata, all)

## ---------------------------------------------------------------------------
## §3.1 CAN-SMASH
## ---------------------------------------------------------------------------

func _check_can_smash(lata: CharacterBase, attacker: CharacterBase) -> void:
	lata.state = CharacterBase.State.NORMAL
	lata._smash_cooldown_left = 0.0
	attacker.state = CharacterBase.State.NORMAL
	attacker.global_position = lata.global_position + Vector3(2.0, 0.0, 0.0)
	attacker.velocity = Vector3.ZERO
	await get_tree().physics_frame

	var consumed: bool = lata._try_prop_smash()
	_assert(consumed, "§3.1 PRESS: bump on a lata is consumed by the smash attempt")
	_assert(lata._smash_cooldown_left > 0.0,
		"§3.1 COOLDOWN: starts counting from the press (%.2fs), not the landing" % [
			lata._smash_cooldown_left])

	await get_tree().create_timer(WINDUP_EARLY).timeout
	_assert(attacker.state == CharacterBase.State.NORMAL,
		"§3.1 TELEGRAPH: nothing has landed yet at %.2fs into the %.2fs wind-up" % [
			WINDUP_EARLY, PropSmash.CAN_SMASH_WINDUP])

	await get_tree().create_timer(WINDUP_CLEAR - WINDUP_EARLY).timeout
	_assert(attacker.state != CharacterBase.State.NORMAL,
		"§3.1 HIT: an opponent %.1fm inside the %.1fm radius is staggered once the wind-up clears" % [
			2.0, PropSmash.CAN_SMASH_RADIUS])

	var cooldown_mid := lata._smash_cooldown_left
	var consumed_again: bool = lata._try_prop_smash()
	_assert(consumed_again and is_equal_approx(lata._smash_cooldown_left, cooldown_mid),
		"§3.1 REFUSE: a second press during cooldown is swallowed, not re-armed (%.2fs unchanged)" % [
			cooldown_mid])

	attacker.state = CharacterBase.State.NORMAL

## Same radius, same setup, an opponent placed OUTSIDE it. §5.3's own claim: "the can
## cannot hit anybody who kept their distance."
func _check_can_smash_out_of_range(lata: CharacterBase, attacker: CharacterBase) -> void:
	lata._smash_cooldown_left = 0.0
	attacker.state = CharacterBase.State.NORMAL
	attacker.global_position = lata.global_position + Vector3(PropSmash.CAN_SMASH_RADIUS + 0.6, 0.0, 0.0)
	attacker.velocity = Vector3.ZERO
	await get_tree().physics_frame

	var consumed: bool = lata._try_prop_smash()
	if not consumed:
		_harness_note("smash press was not consumed for the out-of-range check")
		return
	await get_tree().create_timer(WINDUP_CLEAR).timeout
	_assert(attacker.state == CharacterBase.State.NORMAL,
		"§5.3 RANGE: an opponent %.1fm out, past the %.1fm radius, is untouched" % [
			PropSmash.CAN_SMASH_RADIUS + 0.6, PropSmash.CAN_SMASH_RADIUS])

## "A SMASH INTERRUPTED IS A SMASH THAT MISSED" — prop_smash.gd's own rule. Staggering
## the lata mid-wind-up must cancel the shockwave outright.
func _check_can_smash_interrupt(lata: CharacterBase, attacker: CharacterBase) -> void:
	lata.state = CharacterBase.State.NORMAL
	lata._smash_cooldown_left = 0.0
	attacker.state = CharacterBase.State.NORMAL
	attacker.global_position = lata.global_position + Vector3(2.0, 0.0, 0.0)
	attacker.velocity = Vector3.ZERO
	await get_tree().physics_frame

	var consumed: bool = lata._try_prop_smash()
	if not consumed:
		_harness_note("smash press was not consumed for the interrupt check")
		return
	await get_tree().create_timer(WINDUP_EARLY).timeout
	lata.state = CharacterBase.State.STAGGERED # simulated interrupt, mid wind-up
	await get_tree().create_timer(WINDUP_CLEAR - WINDUP_EARLY).timeout
	_assert(attacker.state == CharacterBase.State.NORMAL,
		"§3.1 INTERRUPT: staggering the lata mid wind-up cancels the shockwave (attacker untouched)")
	lata.state = CharacterBase.State.NORMAL
	attacker.state = CharacterBase.State.NORMAL

## ---------------------------------------------------------------------------
## §3.2 CAN-DASH
## ---------------------------------------------------------------------------

func _check_can_dash(lata: CharacterBase, all: Array[CharacterBase]) -> void:
	lata._can_dash_spent = false
	lata._dash_active_time_left = 0.0
	lata.state = CharacterBase.State.NORMAL
	lata.velocity = Vector3.ZERO
	lata.look_at(lata.global_position + Vector3.FORWARD, Vector3.UP)
	_park_all_except(all, lata)
	await get_tree().physics_frame

	# ⚠️ POLLED, NOT A FIXED FRAME OFFSET. `Input.action_press()` under this harness does
	# not always land on the very next physics tick the way a real device's edge does —
	# same class of harness timing gap `hit_probe.gd`/`net_spawn_probe.gd` document at
	# length for their own polling loops. `_can_dash_spent` and the velocity it sets flip
	# in the same function call, so catching the flag the instant it turns true also
	# catches the un-decayed burst speed.
	Input.action_press(&"guard_dash")
	var fired := await _wait_until(func() -> bool: return lata._can_dash_spent, 30)
	var speed := Vector2(lata.velocity.x, lata.velocity.z).length()
	Input.action_release(&"guard_dash")
	_assert(fired, "§3.2 ONCE: the charge is spent by the first press")
	_assert(is_equal_approx_loose(speed, CharacterBase.CAN_DASH_SPEED, 1.0),
		"§3.2 SPEED: Can-Dash launches at %.2f m/s (spec %.1f)" % [speed, CharacterBase.CAN_DASH_SPEED])

	# Ride out the burst, then confirm a second press this round does nothing.
	for _i in 20:
		await get_tree().physics_frame
	var settled := lata.velocity.length()
	Input.action_press(&"guard_dash")
	for _i in 5:
		await get_tree().physics_frame
	var speed_again := Vector2(lata.velocity.x, lata.velocity.z).length()
	Input.action_release(&"guard_dash")
	_assert(speed_again <= settled + 0.5,
		"§3.2 ONCE PER ROUND: a second press this round does not add another burst (%.2f -> %.2f)" % [
			settled, speed_again])

	_unpark_all(all)

## Polls `predicate` once per physics frame, up to `max_frames`, returning true as soon
## as it does. Exists because this harness's `Input.action_press()` does not reliably land
## its "just pressed" edge on the very next tick — see the Can-Dash check's own note.
func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _i in max_frames:
		if predicate.call():
			return true
		await get_tree().physics_frame
	return bool(predicate.call())

## ---------------------------------------------------------------------------
## §3.5 CHARGED SELF-LAUNCH
## ---------------------------------------------------------------------------

func _check_self_launch(tsinelas: CharacterBase, all: Array[CharacterBase]) -> void:
	var carriable := tsinelas.get_node_or_null("Carriable") as Carriable
	if carriable == null:
		_harness_note("tsinelas has no Carriable — self-launch not testable")
		return
	if carriable.state != Carriable.CarryState.LOOSE:
		carriable.host_land()
		for _i in 4:
			await get_tree().physics_frame
	if carriable.state != Carriable.CarryState.LOOSE:
		_harness_note("could not get the tsinelas LOOSE for the self-launch check")
		return

	tsinelas.global_position = Vector3(-3.0, tsinelas.global_position.y, -3.0)
	tsinelas.velocity = Vector3.ZERO
	tsinelas.state = CharacterBase.State.NORMAL
	_park_all_except(all, tsinelas)
	for _i in 6:
		await get_tree().physics_frame
	if not tsinelas.is_on_floor():
		_harness_note("tsinelas was not grounded ahead of the self-launch check")
		_unpark_all(all)
		return

	# A tap: hold only until the charge is confirmed to have STARTED (`_launch_charge`
	# flips from -1 to 0 the instant `jump_charge_step` sees the press — see the Can-Dash
	# check for why this is polled rather than timed to a fixed frame), then release
	# immediately — the minimum charge a real tap can bank.
	#
	# ⚠️ THE LAUNCH NEVER LEAVES LOOSE — its own doc is explicit that a self-launch is
	# "ordinary CharacterBody motion, not a flight controller", so there is no CARRIED /
	# FLYING transition to poll for, and a LOOSE tsinelas with no movement input runs the
	# SAME per-frame `move_toward(velocity, 0, FRICTION * delta)` decay every character
	# does at rest — friction eats the flat component fast (30 units/s^2) while gravity
	# eats the vertical one far slower, so "wait a few frames, then read" measures an
	# already-skewed vector, vertical-heavy, exactly the failure the first version of
	# this check hit. `_launch_charge` going back to -1.0 is set in the very same
	# statement that computes the launch velocity (`jump_charge_step`'s own "Released."
	# branch) — polling for THAT edge, the same idiom the Can-Dash check uses for
	# `_can_dash_spent`, catches the tick it fires on before either decay has a chance to
	# run even once.
	Input.action_press(&"jump")
	await _wait_until(func() -> bool: return carriable._launch_charge >= 0.0, 15)
	Input.action_release(&"jump")
	await _wait_until(func() -> bool: return carriable._launch_charge < 0.0, 15)
	var tap_speed := tsinelas.velocity.length()
	_assert(tap_speed >= Carriable.SELF_LAUNCH_MIN_SPEED - 0.5
			and tap_speed <= Carriable.SELF_LAUNCH_MIN_SPEED + 1.5,
		"§3.5 TAP: a bare press+release launches at ~%.1f m/s (min spec %.1f)" % [
			tap_speed, Carriable.SELF_LAUNCH_MIN_SPEED])
	var vfrac_tap := (tsinelas.velocity.y / tap_speed) if tap_speed > 0.01 else 0.0
	_assert(is_equal_approx_loose(vfrac_tap, Carriable.SELF_LAUNCH_VERTICAL_FRACTION, 0.05),
		"§3.5 ARC: vertical fraction %.3f matches the spec %.3f" % [
			vfrac_tap, Carriable.SELF_LAUNCH_VERTICAL_FRACTION])

	# Let it come back to rest, LOOSE, then charge a FULL launch.
	for _i in 180:
		await get_tree().physics_frame
		if carriable.state == Carriable.CarryState.LOOSE and tsinelas.is_on_floor() \
				and tsinelas.velocity.length() < 0.1:
			break
	if carriable.state != Carriable.CarryState.LOOSE:
		_harness_note("tsinelas did not settle LOOSE in time for the full-charge check")
		_unpark_all(all)
		return

	Input.action_press(&"jump")
	await _wait_until(func() -> bool: return carriable._launch_charge >= 0.0, 15)
	await get_tree().create_timer(Carriable.SELF_LAUNCH_CHARGE_TIME + 0.15).timeout
	Input.action_release(&"jump")
	await _wait_until(func() -> bool: return carriable._launch_charge < 0.0, 15)
	var full_speed := tsinelas.velocity.length()
	_assert(full_speed >= Carriable.SELF_LAUNCH_MAX_SPEED - 1.0,
		"§3.5 FULL CHARGE: holding the full %.2fs launches at ~%.1f m/s (max spec %.1f)" % [
			Carriable.SELF_LAUNCH_CHARGE_TIME, full_speed, Carriable.SELF_LAUNCH_MAX_SPEED])
	_assert(full_speed > tap_speed + 1.0,
		"§3.5 CHARGE SCALES: a full hold launches harder than a tap (%.1f > %.1f)" % [
			full_speed, tap_speed])

	_unpark_all(all)

## ---------------------------------------------------------------------------
## §3.3 GROUND SMASH, and §3.9's bound on the direct-hit win (§3.4)
## ---------------------------------------------------------------------------

## Drops the tsinelas from DROP_HEIGHT and drives it through Ground Smash, landing at
## `landing_xz`. Returns true once it has come to rest on the floor (`_dive_active`
## cleared), false on a harness failure.
func _drop_and_smash(tsinelas: CharacterBase, all: Array[CharacterBase], landing_xz: Vector2) -> bool:
	var carriable := tsinelas.get_node_or_null("Carriable") as Carriable
	if carriable == null or carriable.state != Carriable.CarryState.LOOSE:
		_harness_note("tsinelas not LOOSE ahead of a Ground Smash drop")
		return false
	tsinelas._smash_cooldown_left = 0.0
	tsinelas.state = CharacterBase.State.NORMAL
	tsinelas.global_position = Vector3(landing_xz.x, tsinelas.global_position.y + DROP_HEIGHT, landing_xz.y)
	tsinelas.velocity = Vector3.ZERO
	_park_all_except(all, tsinelas)
	for _i in 3:
		await get_tree().physics_frame
	if tsinelas.is_on_floor() or carriable.can_ground_smash() == false:
		_harness_note("tsinelas was not airborne high enough after the drop teleport")
		_unpark_all(all)
		return false

	var consumed: bool = tsinelas._try_prop_smash()
	if not consumed or not tsinelas._dive_active:
		_harness_note("Ground Smash press was not consumed / dive did not start")
		_unpark_all(all)
		return false
	_assert(is_equal_approx(tsinelas.velocity.y, -PropSmash.GROUND_SMASH_DIVE_SPEED),
		"§3.3 DIVE: vertical speed locked to %.1f m/s straight down" % PropSmash.GROUND_SMASH_DIVE_SPEED)

	var frames := 0
	while tsinelas._dive_active and frames < FALL_TIMEOUT_FRAMES:
		await get_tree().physics_frame
		frames += 1
	if tsinelas._dive_active:
		_harness_note("the dive never landed within the frame budget")
		_unpark_all(all)
		return false
	return true

func _check_ground_smash_and_stun(tsinelas: CharacterBase, lata: CharacterBase,
		taya: CharacterBase, all: Array[CharacterBase]) -> void:
	taya.state = CharacterBase.State.NORMAL
	taya.global_position = Vector3(3.0, taya.global_position.y, 3.0)
	taya.velocity = Vector3.ZERO
	var spot := Vector2(taya.global_position.x + 1.0, taya.global_position.z)
	if not await _drop_and_smash(tsinelas, all, spot):
		return
	_assert(taya.state != CharacterBase.State.NORMAL,
		"§3.3 STUN: a Person %.1fm from the impact (inside the %.1fm radius) is stunned on landing" % [
			1.0, PropSmash.GROUND_SMASH_RADIUS])
	taya.state = CharacterBase.State.NORMAL
	_unpark_all(all)

## §3.9 — a lata already DOWNED must not still hand over the round on a direct hit; that
## is what §5.2's countdown is for. This is the fix `_resolve_direct_hit` got this pass.
func _check_ground_smash_bounded_on_downed(tsinelas: CharacterBase, lata: CharacterBase,
		all: Array[CharacterBase]) -> void:
	var won: Array[int] = []
	var handler := func(team: int) -> void: won.append(team)
	RoundManager.round_won.connect(handler)
	lata.global_position = Vector3(-4.0, lata.global_position.y, -4.0)
	lata.velocity = Vector3.ZERO
	lata.go_downed()
	await get_tree().physics_frame
	if lata.state != CharacterBase.State.DOWNED:
		_harness_note("lata would not go DOWNED for the §3.9 bound check")
		RoundManager.round_won.disconnect(handler)
		return
	var spot := Vector2(lata.global_position.x, lata.global_position.z)
	if not await _drop_and_smash(tsinelas, all, spot):
		RoundManager.round_won.disconnect(handler)
		return
	_assert(won.is_empty(),
		"§3.9 BOUND: a direct hit on an already-DOWNED lata does NOT win the round (%d win events)" % won.size())
	RoundManager.round_won.disconnect(handler)
	lata.state = CharacterBase.State.NORMAL
	_unpark_all(all)

## §3.4 — the instant win itself, on a lata that is still up and fighting. Ends the round
## on purpose; runs last.
func _check_ground_smash_instant_win(tsinelas: CharacterBase, lata: CharacterBase,
		all: Array[CharacterBase]) -> void:
	var won: Array[int] = []
	RoundManager.round_won.connect(func(team: int) -> void: won.append(team))
	lata.state = CharacterBase.State.NORMAL
	lata.global_position = Vector3(4.0, lata.global_position.y, -4.0)
	lata.velocity = Vector3.ZERO
	var spot := Vector2(lata.global_position.x, lata.global_position.z)
	if not await _drop_and_smash(tsinelas, all, spot):
		return
	await get_tree().create_timer(0.3).timeout
	_assert(won.size() == 1 and won[0] == 1,
		"§3.4 INSTANT WIN: a direct hit on a standing lata ends the round for the tsinelas side (events=%s)" % [
			str(won)])
	_unpark_all(all)

## ---------------------------------------------------------------------------

func _park_all_except(all: Array[CharacterBase], keep: CharacterBase) -> void:
	for ch in all:
		ch.input_parked = (ch != keep)

func _unpark_all(all: Array[CharacterBase]) -> void:
	for ch in all:
		ch.input_parked = false

func _restore_home(lata: CharacterBase, home: Vector3) -> void:
	lata.global_position = home
	lata.velocity = Vector3.ZERO

func is_equal_approx_loose(a: float, b: float, tolerance: float) -> bool:
	return absf(a - b) <= tolerance

func _assert(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_fails += 1
	print("  %s  %s" % ["PASS" if condition else "FAIL", what])

func _harness_note(what: String) -> void:
	_harness += 1
	print("  HARNESS: %s" % what)
