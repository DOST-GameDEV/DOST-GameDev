extends Node
## MECHANICS ACCEPTANCE — `build mech`, § CHECKLIST §1. Written 2026-07-31.
##
## The board's standing rule is that `[x]` needs a named probe, a screenshot or a log,
## and §1 had none: every mechanic on it was written and predicted and not one was
## observed. This is the named probe for the two items this lane actually changed
## behaviour on, plus the three invariants those changes could plausibly have broken.
##
## ⚠️ NEW FILE, AND A DELIBERATE ONE. § PATHS gives `build mech` no `tools/` row, so this
## adds a file rather than writing to `phys_probe.gd` / `hit_probe.gd` / `round_probe.gd`,
## every one of which belongs to a later lane. Nothing else reads it and nothing else
## writes it; one-writer-per-file is intact.
##
##     godot --path . --headless tools/mech_probe.tscn
##
## Local flow only, and honestly so: every rule under test resolves through
## `RoundManager` and `CharacterBase`'s own state machine on the body's own peer, and
## none of the six checks below crosses the host gate. **The two that DO have a
## networked half — the punt's `_rpc_set_loose` argument and §1.9's read of the 4 Hz
## `_sync_state` mirror of `can_out_left()` — are NOT proven here**, and the log says so.
##
## ⚠️ EVERY AI CONTROLLER IS DISABLED, same reason `round_probe.gd` disables them: a bot
## walking a lata home or throwing a slipper into the middle of a measurement is
## indistinguishable from the mechanic under test. With them off, any state change is the
## rules.

## The pre-round free-roam window (`main.gd::_awaiting_local_ready`) holds `round_active`
## false until someone presses ready, and every rule here is gated on a live round — so
## the probe presses it, then waits out main.gd's own 3 · 2 · 1 · GO.
const BOOT_WAIT: float = 3.0
const COUNTDOWN_WAIT: float = 5.0
## Comfortably past `CharacterBase.DOWNED_MAX_TIME` (2.0) and comfortably short of the
## countdown that would end the round out from under the measurement
## (`CAN_OUT_LIMIT_BASE`, 5.0). 3.0 s is 1.5x the ceiling it is proving does not fire.
const STRAND_HOLD: float = 3.0
## Just past the same ceiling, for the cases that are proving it DOES fire.
const CEILING_HOLD: float = 2.4
## Where a stranded lata is put: outside `CAN_HOME_RADIUS` (0.9) and well inside the
## confinement square (`CONFINEMENT_RADIUS`, 5.0), so nothing clamps it mid-test.
const OUT_X: float = 2.6
## Frames to let a punted slipper fly and skid before its displacement is read.
const PUNT_SETTLE_FRAMES: int = 90

var _fails: int = 0
var _checks: int = 0
var _harness: int = 0

func _ready() -> void:
	# Same parenting rule `scuff_probe.gd` and `net_spawn_probe.gd` both document: Main
	# must be /root/Main, and the probe must not be the current scene or a scene swap
	# frees it mid-run.
	var main: Node = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main

	await get_tree().create_timer(BOOT_WAIT).timeout
	_press_ready()
	await get_tree().create_timer(COUNTDOWN_WAIT).timeout
	await _run()

	print("\n=== MECH PROBE: %s (%d/%d checks clean, %d harness) ===" % [
		"ALL CHECKS PASSED" if _fails == 0 else "%d FAILURES" % _fails,
		_checks - _fails, _checks, _harness])
	get_tree().quit(1 if _fails > 0 else 0)

## `main.gd` reads the ready press in `_unhandled_input`, so it has to arrive as a real
## input event rather than as an `Input.action_press()` — that sets the action's state
## without ever producing an event for the tree to route.
func _press_ready() -> void:
	var event := InputEventAction.new()
	event.action = &"ready_up"
	event.pressed = true
	Input.parse_input_event(event)

func _run() -> void:
	if not RoundManager.round_active:
		_harness_note("the round never started — nothing below is testable")
		return

	var lata: CharacterBase = null
	var tsinelas: CharacterBase = null
	for node in get_tree().root.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch == null or ch.is_person:
			continue
		if ch.is_can and lata == null:
			lata = ch
		elif not ch.is_can and tsinelas == null:
			tsinelas = ch
	if lata == null:
		_harness_note("no lata in the match")
		return
	var taya: CharacterBase = null
	var attacker: CharacterBase = null
	for node in get_tree().root.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch == null or not ch.is_person:
			continue
		if ch.team == lata.team:
			taya = ch
		else:
			attacker = ch
	for node in get_tree().root.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch != null and ch.ai_controller != null:
			ch.ai_controller.set_enabled(false)

	print("\n=== MECHANICS ACCEPTANCE (§1.9 · §1.11 · §1.14 · §1.4) ===")
	print("lata=%s  taya=%s  attacker=%s  tsinelas=%s" % [
		lata.name, _name_of(taya), _name_of(attacker), _name_of(tsinelas)])

	await _check_strand(lata)
	await _check_stands_the_moment_it_is_home(lata)
	await _check_ceiling_at_home(lata)
	await _check_person_is_exempt(taya)
	await _check_reset_channel_cures_a_strand(lata, taya)
	await _check_no_seal_on_hit(lata, attacker)
	await _check_punt(tsinelas, attacker)
	# ⚠️ LAST, AND IT HAS TO BE: it ends the round on purpose, and everything above
	# is gated on `round_active`.
	await _check_countdown_wins_the_round(lata)

## §1.9 — the headline. A lata knocked out of its circle must NOT get up on its own,
## and the ceiling that would otherwise stand it at 2.0 s must not fire.
func _check_strand(lata: CharacterBase) -> void:
	if not await _put_down_at(lata, OUT_X):
		return
	var stacks_before := RoundManager.can_out_stacks()
	var clock_running := RoundManager.can_out_left() >= 0.0
	await get_tree().create_timer(STRAND_HOLD).timeout
	_assert(lata.state == CharacterBase.State.DOWNED,
		"§1.9 STRAND: lata held down %.1fs off its circle (ceiling is %.1fs) — state=%s" % [
			STRAND_HOLD, CharacterBase.DOWNED_MAX_TIME, _state_name(lata.state)])
	_assert(not lata.can_self_right(),
		"§1.9 STRAND: can_self_right() refuses off the circle")
	_assert(clock_running,
		"§1.12 CLOCK: the out-of-circle countdown was running (%.2fs left of %.2f)" % [
			RoundManager.can_out_left(), RoundManager.can_out_limit()])
	_assert(RoundManager.can_out_stacks() == stacks_before,
		"§1.13 no recovery was banked while the lata stayed out")

## The refusal is retried every frame rather than latched — put the same still-DOWNED
## lata back on its mark and it stands up on its own within a frame or two, with no
## fresh input and no channel.
func _check_stands_the_moment_it_is_home(lata: CharacterBase) -> void:
	if lata.state != CharacterBase.State.DOWNED:
		_harness_note("lata was not still down entering the home-again check")
		return
	lata.global_position = Vector3(0.0, lata.global_position.y, 0.0)
	lata.velocity = Vector3.ZERO
	for _i in 6:
		await get_tree().physics_frame
	_assert(lata.state == CharacterBase.State.NORMAL,
		"§1.9 RETRY: a still-DOWNED lata stands up within 6 frames of arriving home")

## §1.11 — the ceiling itself, unchanged, for a lata standing where it belongs.
func _check_ceiling_at_home(lata: CharacterBase) -> void:
	if not await _put_down_at(lata, 0.0):
		return
	await get_tree().create_timer(CEILING_HOLD).timeout
	_assert(lata.state == CharacterBase.State.NORMAL,
		"§1.11 CEILING: a lata ON its circle still gets up by %.1fs" % CharacterBase.DOWNED_MAX_TIME)

## §1.11's other half, and the one §1.9 could most easily have broken: the 2.0 s wall is
## what stops a Person being left on the floor, and a Person has no circle to be off.
func _check_person_is_exempt(taya: CharacterBase) -> void:
	if taya == null:
		_harness_note("no taya to test the Person exemption on")
		return
	taya.global_position = Vector3(OUT_X, taya.global_position.y, OUT_X)
	taya.velocity = Vector3.ZERO
	await get_tree().physics_frame
	taya.go_downed()
	await get_tree().create_timer(CEILING_HOLD).timeout
	_assert(taya.state == CharacterBase.State.NORMAL,
		"§1.11 PERSON: a Person downed far off the circle still gets up by %.1fs" % [
			CharacterBase.DOWNED_MAX_TIME])

## §1.14 — the defence's answer. This is also the regression test for the ORDER inside
## `carriable.gd::_rpc_apply_reset`: with the stand-up called before the carry-home, §1.9
## refuses it and the channel silently does nothing at all.
func _check_reset_channel_cures_a_strand(lata: CharacterBase, taya: CharacterBase) -> void:
	if taya == null:
		_harness_note("no taya to run the reset channel")
		return
	if not await _put_down_at(lata, OUT_X):
		return
	await get_tree().create_timer(STRAND_HOLD).timeout
	if lata.state != CharacterBase.State.DOWNED:
		_harness_note("lata recovered before the channel could be tested")
		return
	var limit_before := RoundManager.can_out_limit()
	var carriable := lata.get_node_or_null("Carriable") as Carriable
	if carriable == null:
		_harness_note("lata has no Carriable")
		return
	carriable.host_reset_upright(taya)
	for _i in 8:
		await get_tree().physics_frame
	_assert(lata.state == CharacterBase.State.NORMAL,
		"§1.14 CHANNEL: a completed channel stands a STRANDED lata up")
	_assert(lata.is_home(),
		"§1.14 CHANNEL: and puts it back on the mark (%.2fm from centre)" % [
			Vector2(lata.global_position.x, lata.global_position.z).length()])
	# The stack is banked by RoundManager's own edge, one _process tick later.
	await get_tree().create_timer(0.2).timeout
	_assert(is_equal_approx(limit_before - RoundManager.can_out_limit(),
			RoundManagerScript.CAN_OUT_RECOVERY_STEP),
		"§1.13 STACK: the save shortened the next countdown by %.2fs (%.2f -> %.2f)" % [
			RoundManagerScript.CAN_OUT_RECOVERY_STEP, limit_before, RoundManager.can_out_limit()])

## THE REGRESSION §1.9 NEARLY INTRODUCED. `hitbox.gd` used to seal any lata that was
## DOWNED past its self-right window, and a sealed lata ends the round. While the lata
## always stood up at 2.0 s that window was 0.75 s wide; stranded, it never closes — so
## an attacker could walk over, press bump and win. The branch is deleted; this proves a
## landed hit on a stranded lata SHOVES it and does not end anything.
func _check_no_seal_on_hit(lata: CharacterBase, attacker: CharacterBase) -> void:
	if attacker == null:
		_harness_note("no attacking Person to test the deleted seal with")
		return
	if not await _put_down_at(lata, OUT_X):
		return
	# Past the self-right window, which is the state the old branch keyed on.
	await get_tree().create_timer(CharacterBase.DOWNED_SELF_RIGHT_WINDOW + 0.3).timeout
	if lata.is_self_rightable():
		_harness_note("lata was still inside its self-right window; the old branch needs it past")
		return
	# ⚠️ THE ATTACKER KEEPS ITS OWN Y AND IS TURNED TO FACE THE CAN. The melee sphere
	# hangs at `hit_off` (0, -0.05, -0.55) with r 0.72 — i.e. FORWARD of the body, in the
	# body's own frame — so an offset along world X with the attacker still facing
	# wherever it spawned puts the box nowhere near the lata, and lifting the attacker to
	# the lata's own y raises the box clear over it. Both were true on the first run and
	# the check passed on a hit that never landed.
	attacker.global_position = Vector3(lata.global_position.x,
		attacker.global_position.y, lata.global_position.z + 0.7)
	attacker.velocity = Vector3.ZERO
	attacker.look_at(Vector3(lata.global_position.x, attacker.global_position.y,
		lata.global_position.z), Vector3.UP)
	for _i in 4:
		await get_tree().physics_frame
	var where_before := lata.global_position
	attacker._open_bump_window()
	for _i in 20:
		await get_tree().physics_frame
	var moved := where_before.distance_to(lata.global_position)
	_assert(lata.state != CharacterBase.State.SEALED,
		"§7 NO SEAL: a bump on a stranded lata does not seal it (state=%s)" % _state_name(lata.state))
	_assert(RoundManager.round_active,
		"§7 NO SEAL: and the round is still live afterwards")
	if moved < 0.02:
		_harness_note("the bump did not connect (%.3fm of shove) — the no-seal result is weak" % moved)
	else:
		print("      (the hit landed: %.3fm of extra displacement, which is the reward now)" % moved)

## §1.4 — "drops the attacker's tsinelas FAR AWAY". Measured as displacement of the
## slipper from the hand it left, because that is exactly what the item asks for and
## what the old code (drop at the carrier's feet) did not do.
func _check_punt(tsinelas: CharacterBase, attacker: CharacterBase) -> void:
	if tsinelas == null or attacker == null:
		_harness_note("no tsinelas/attacker pair to punt")
		return
	var carriable := tsinelas.get_node_or_null("Carriable") as Carriable
	if carriable == null:
		_harness_note("tsinelas has no Carriable")
		return
	# ⚠️⚠️ THE ORIGIN IS PINNED, AND THE FIRST VERSION OF THIS CHECK WAS NOT — WHICH IS
	# WHY IT PRODUCED AN IMPOSSIBLE NUMBER. It punted from wherever the attacker happened
	# to be standing after `_check_no_seal_on_hit` had already moved it, so the slipper
	# started from a different spot, at a different height, over different geometry on
	# every run. Raising the impulse from 9.0/3.5 to 10.5/3.8 then measured 3.30 m -> 2.69
	# m: a bigger shove travelling less far. Two numbers that cannot both be right, so the
	# metric was the bug, exactly as this project's standing rule says.
	#
	# Pinned to open floor inside the arena, well clear of the lata on its circle and of
	# any wall the flight could end against, and punted along +X from there.
	attacker.global_position = Vector3(-4.0, attacker.global_position.y, 3.5)
	attacker.velocity = Vector3.ZERO
	tsinelas.global_position = attacker.global_position
	await get_tree().physics_frame
	carriable.host_grab(attacker)
	for _i in 4:
		await get_tree().physics_frame
	if carriable.state != Carriable.CarryState.CARRIED:
		_harness_note("could not get the tsinelas into the attacker's hands")
		return
	var from := attacker.global_position
	# Full charge, straight along +X. This is what `hitbox.gd` hands it on a landed
	# power bump; the drop itself is what `_on_carrier_state_changed` would trigger.
	carriable.host_note_punt(Vector3.RIGHT, 1.0)
	carriable.host_drop()
	# ⚠️ WAIT FOR REST, DO NOT COUNT FRAMES. A fixed frame budget measures wherever the
	# slipper happened to be at frame N, which is a different quantity from where it came
	# to a stop and is the other half of what made the first reading unreproducible.
	var frames := 0
	while frames < PUNT_SETTLE_FRAMES:
		await get_tree().physics_frame
		frames += 1
		if Vector2(tsinelas.velocity.x, tsinelas.velocity.z).length() < 0.05 \
				and tsinelas.is_on_floor():
			break
	var flew := Vector3(tsinelas.global_position.x - from.x, 0.0,
		tsinelas.global_position.z - from.z).length()
	_assert(flew >= 2.5,
		"§1.4 PUNT: a full-charge bump throws the tsinelas %.2fm clear of the hand it left" % flew)
	print("      (%.1f flat + %.1f lift; came to rest after %d physics frames)" % [
		Carriable.PUNT_SPEED, Carriable.PUNT_LIFT, frames])

## §1.12 — THE PRIMARY WIN CONDITION, ACTUALLY RUN TO ZERO. Every check above proves the
## clock ticks; this is the only one that proves what happens when it stops, which is the
## whole reason the clock exists. Ends the round, so it runs last.
##
## Deliberately driven by STRANDING the lata rather than by holding it out by hand: that
## is the real sequence a round dies of, and it exercises §1.9 and §1.12 as one path.
func _check_countdown_wins_the_round(lata: CharacterBase) -> void:
	# ⚠️ BOTH FACTS ARE SAMPLED INSIDE THE SIGNAL, NOT AFTER THE WAIT, AND THE FIRST
	# VERSION OF THIS CHECK GOT IT WRONG IN A WAY WORTH RECORDING. It asserted
	# `not RoundManager.round_active` once the countdown had elapsed, and read it TRUE
	# while `round_won` had already fired correctly with the right team — two results that
	# cannot both describe the same round. They describe two: `main.gd` runs an
	# intermission and a 3 · 2 · 1 countdown and begins the NEXT round about 3.5 s later,
	# which is inside this function's own wait. The round-active flag is simply not
	# samplable from outside the moment it changes.
	var won_by: Array[int] = []
	var active_at_win: Array[bool] = []
	RoundManager.round_won.connect(func(team: int) -> void:
		won_by.append(team)
		active_at_win.append(RoundManager.round_active))
	if not await _put_down_at(lata, OUT_X):
		return
	var limit := RoundManager.can_out_limit()
	await get_tree().create_timer(limit + 0.75).timeout
	_assert(won_by.size() == 1,
		"§1.12 WIN: the %.2fs countdown reaching zero ended the round (%d win events)" % [
			limit, won_by.size()])
	_assert(won_by.size() == 1 and won_by[0] == 1,
		"§1.12 WIN: and it was awarded to the tsinelas side (round_won=%s)" % str(won_by))
	_assert(active_at_win.size() == 1 and not active_at_win[0],
		"§1.12 WIN: and the round was already closed at the instant it fired")

## Puts the lata at `x` on the X axis and knocks it down there. Returns false and files a
## HARNESS note if the setup did not take, so a failed setup never reads as a failed rule.
func _put_down_at(lata: CharacterBase, x: float) -> bool:
	lata.global_position = Vector3(x, lata.global_position.y, 0.0)
	lata.velocity = Vector3.ZERO
	await get_tree().physics_frame
	lata.go_downed()
	await get_tree().physics_frame
	if lata.state != CharacterBase.State.DOWNED:
		_harness_note("lata refused to go down at x=%.2f" % x)
		return false
	return true

func _assert(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_fails += 1
	print("  %s  %s" % ["PASS" if condition else "FAIL", what])

## Something about the setup, not about the rules. Counted separately and never as a
## failure — the standing lesson from `scuff_probe.gd` is that a probe which cannot
## distinguish "the mechanic is broken" from "the match did not cooperate" is a probe
## whose red results nobody can act on.
func _harness_note(what: String) -> void:
	_harness += 1
	print("  HARNESS: %s" % what)

func _name_of(who: CharacterBase) -> String:
	return str(who.name) if who != null else "none"

func _state_name(s: int) -> String:
	match s:
		CharacterBase.State.NORMAL: return "NORMAL"
		CharacterBase.State.STAGGERED: return "STAGGERED"
		CharacterBase.State.DOWNED: return "DOWNED"
		CharacterBase.State.SEALED: return "SEALED"
	return "?"
