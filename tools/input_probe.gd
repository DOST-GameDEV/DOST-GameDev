extends Node3D

## ONE KEYBOARD, ONE CHARACTER — the invariant the input overhaul created.
##
## WHY THIS EXISTS. Until 2026-07-29 every character resolved input through
## `_action(name) -> "%s_p%d" % player_id`, and the four suffixes were what kept
## local units off each other's keys: p1/p2 for two humans sharing a keyboard,
## p3/p4 registered in project.godot but deliberately bound to NO key, so an AI
## or a parked unit could never answer a real keystroke.
##
## The user retired split-keyboard play ("u can only play as one guy on one pc
## now"), so all four collapsed into ONE unsuffixed action set. That removes the
## guard along with the suffixes, and leaves exactly one thing standing between
## the game and "every character walks together on one keypress":
##
##   ⚠️ AT MOST ONE LOCAL CHARACTER MAY BE AI-FREE AT A TIME.
##
## `character_base.gd::input_pressed()` routes an AI-driven unit to `_ai_intent`
## and never touches the `Input` singleton, so an enabled AIController IS the
## isolation now. `debug_player_switcher.gd::_apply_slots()` is what upholds it —
## it grants control by moving AI control rather than by reassigning `player_id`,
## which is why its second slot and F5 had to go.
##
## This probe asserts that invariant two ways, because the structural check and
## the behavioural one fail differently:
##
##   1. STRUCTURAL — count the units that would answer the keyboard.
##   2. BEHAVIOURAL — actually press a key and count how many bodies move. This
##      is the one that would have caught the bug the old p3/p4 suffix existed to
##      prevent, and a structural check alone can miss it (an AIController that
##      is attached but disabled reads hardware too).
##
## ⚠️ Trap 1 from the repo's own method note: this drives the LOCAL flow
## (`main.gd::_start_local_test`) ON PURPOSE. Single Player is where multiple
## characters coexist in one process and therefore the only place this collision
## can happen at all — a networked peer owns exactly one character and
## `_physics_process` returns early for every other. The networked half of the
## same question is `net_spawn_probe.gd::_check_local_input()`.
##
## USAGE:  godot --path . tools/input_probe.tscn

## Frames to hold the key. Long enough for a walk to clear the noise floor,
## short enough that nobody reaches the confinement clamp and stops on their own.
const MOVE_FRAMES: int = 30
## Above depenetration jitter and settling, well under a real walk (~2.9 m over
## 30 frames, measured on both peers in net_spawn_probe).
const MOVED_THRESHOLD: float = 0.25

var _main: Node = null
var _fails: int = 0
var _checks: int = 0

func _ready() -> void:
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	MatchManager.begin_next_round()
	await get_tree().create_timer(0.5).timeout

	print("\n=== INPUT ISOLATION PROBE ===")
	print("  action set: unsuffixed since 2026-07-29 (was *_p1..*_p4)")
	_report_bindings()
	_report_binding_conflicts()
	await _check_isolation("default Single Player")
	await _check_charge_on_shared_button()

	# The reworked debug switcher is the thing that can break the invariant, so
	# exercise it rather than trusting that it holds only in the start state.
	# Cycling moves AI control from one unit to the next; if it ever leaves TWO
	# units AI-free, the behavioural check below catches it as two movers.
	# ⚠️ NET-2 — LOOKED UP, NOT NAMED. This used to be a bare
	# `DebugPlayerSwitcher._cycle()`, which is a COMPILE-TIME reference to an
	# autoload: R-30 deletes that autoload, and a deleted autoload makes this
	# whole file fail to PARSE — while "input_probe green" is part of R-30's own
	# acceptance. The probe would have had to be fixed in the same commit that
	# broke it, by whoever was doing an unrelated cleanup.
	#
	# Through `get_node_or_null` the reference is resolved at RUNTIME, so this
	# file parses and runs either way, and the switcher half simply reports itself
	# skipped once the autoload is gone. The isolation invariant it exercises is
	# still asserted above from the default state.
	var switcher := get_node_or_null("/root/DebugPlayerSwitcher")
	if switcher == null or not switcher.has_method("_cycle"):
		print("\n  --- DebugPlayerSwitcher absent — switcher cycles skipped ---")
		print("      (expected after R-30 removes it; the default-state checks above still ran.)")
	else:
		for i in 3:
			switcher.call("_cycle")
			await get_tree().physics_frame
			await _check_isolation("after Tab #%d" % (i + 1))

	print("\n=== %s (%d/%d checks clean) ===" % [
		"ALL CHECKS PASSED" if _fails == 0 else "%d FAILURES" % _fails,
		_checks - _fails, _checks])
	get_tree().quit(1 if _fails > 0 else 0)

## Every action the game reads must exist and carry at least one event. A missing
## binding is silent — Input.is_action_pressed() on an unbound action just
## returns false forever, which is exactly how the LAN movement bug hid.
func _report_bindings() -> void:
	var bases: Array[String] = [
		"move_left", "move_right", "move_up", "move_down",
		"jump", "bump", "guard_dash", "special_ability", "grab",
	]
	var missing: Array[String] = []
	for base in bases:
		if not InputMap.has_action(base) or InputMap.action_get_events(base).is_empty():
			missing.append(base)
	_checks += 1
	if missing.is_empty():
		print("  bindings  : all %d actions present and bound" % bases.size())
	else:
		print("  *** FAIL: unbound or missing actions: %s ***" % ", ".join(missing))
		_fails += 1

## A unit answers the keyboard when it is neither AI-driven nor parked —
## mirroring `character_base.gd::_reads_hardware()`. Both halves matter: a
## disabled-but-attached controller hands the unit back to hardware (that is the
## switcher taking manual control), and `input_parked` is what silences every
## unit the human is not currently holding.
func _keyboard_units() -> Array[CharacterBase]:
	var out: Array[CharacterBase] = []
	for node in _main.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch == null:
			continue
		var ai_driven: bool = ch.ai_controller != null and ch.ai_controller.is_enabled()
		if not ai_driven and not ch.input_parked:
			out.append(ch)
	return out

func _check_isolation(label: String) -> void:
	var listeners := _keyboard_units()
	var names: Array[String] = []
	for ch in listeners:
		names.append(ch.name)

	print("\n  --- %s ---" % label)
	print("  units answering the keyboard: %d  %s" % [listeners.size(), str(names)])
	_checks += 1
	if listeners.size() > 1:
		print("  *** FAIL: %d units are AI-free at once. With one action set they" % listeners.size())
		print("      all read the same keys and walk together on one keypress. ***")
		_fails += 1

	# ⚠️ BEHAVIOURAL HALF, AND IT NEEDS A CONTROL. An AI-driven unit walks under
	# its own behaviour tree, so raw "did it move" cannot tell a unit responding
	# to the keyboard from a bot going about its business — every unit would read
	# as a mover and the check would pass no matter how broken the isolation was.
	# So displacement is measured TWICE over the same window length: once with no
	# key held, once with `move_up` held. Only the DIFFERENCE is attributable to
	# the keystroke. Same reasoning as phys_probe's `_speed_prev` control.
	var control := await _displacements(false)
	var pressed := await _displacements(true)

	# ⚠️ ONLY NON-AI-DRIVEN UNITS COUNT, AND THAT IS NOT A WEAKENING.
	# `input_pressed()` routes an AI-driven character to `_ai_intent` and never
	# calls `Input` at all, so a bot CANNOT respond to a keystroke by
	# construction — its displacement is its own behaviour tree and it varies run
	# to run regardless of what the control window saw. Counting bots as
	# "responders" measured AI variance, not input isolation: the first run of
	# this probe reported TeamBProp at +2.17 m on a keypress it is structurally
	# incapable of reading. The collision this probe exists to catch can only
	# occur between units that actually reach `Input`, which is exactly this set.
	var candidates := _keyboard_units()
	var responders: Array[String] = []
	var ai_noise: Array[String] = []
	for id in pressed:
		var gain: float = pressed[id] - control[id]
		if gain < MOVED_THRESHOLD:
			continue
		var is_candidate := false
		for ch in candidates:
			if ch.get_instance_id() == id:
				is_candidate = true
				break
		if is_candidate:
			responders.append("%s(+%.2fm)" % [_name_of(id), gain])
		else:
			ai_noise.append("%s(+%.2fm)" % [_name_of(id), gain])
	print("  responded to the keypress  : %d  %s" % [responders.size(), str(responders)])
	if not ai_noise.is_empty():
		print("  (AI units that moved anyway : %s — cannot read Input, informational)" % str(ai_noise))
	_checks += 1
	if responders.size() > 1:
		print("  *** FAIL: %d units answered one keypress. This is the collision the" % responders.size())
		print("      p3/p4 unbound suffix used to prevent. ***")
		_fails += 1

## Planar displacement per character over MOVE_FRAMES, optionally holding move_up.
func _displacements(hold_key: bool) -> Dictionary:
	var start: Dictionary = {}
	var units: Array[CharacterBase] = []
	for node in _main.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch != null:
			units.append(ch)
			start[ch.get_instance_id()] = ch.global_position
	if hold_key:
		Input.action_press("move_up")
	for _i in MOVE_FRAMES:
		await get_tree().physics_frame
	if hold_key:
		Input.action_release("move_up")
	var out: Dictionary = {}
	for ch in units:
		var from: Vector3 = start[ch.get_instance_id()]
		out[ch.get_instance_id()] = Vector2(
			ch.global_position.x - from.x, ch.global_position.z - from.z).length()
	return out

func _name_of(instance_id: int) -> String:
	var obj := instance_from_id(instance_id)
	return (obj as Node).name if obj is Node else str(instance_id)


## ---------------------------------------------------------------------------
## ⚠️ TWO ACTIONS ON ONE PHYSICAL INPUT — 🧑 report, 2026-07-30: *"i cant wind up
## as attacker?? i cant even throw no more"*, with the user's own guess that
## *"this broke bcz i overhauled controls earlier"*. It did.
##
## `_report_bindings()` above asks only "is every action bound to SOMETHING",
## which is the check that would have caught an action bound to nothing. It
## cannot see the opposite mistake: ONE button bound to TWO actions that then
## fight each other. The overhaul left `grab` on E **and LEFT CLICK** while
## `special_ability` is on Q, LEFT CLICK **and RIGHT CLICK**, so a left click
## fires both in the same frame.
##
## The game's own tutorial states the intended split — "E · Grab the tsinelas"
## and "Q / LEFT CLICK · Special" — so the extra `grab` binding contradicts
## documented, shipped copy. That disagreement is itself the evidence.
const GAMEPLAY_ACTIONS: Array[String] = [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "bump", "guard_dash", "special_ability", "grab", "ready_up",
]

## ⚠️ THE ONE PAIR THAT IS ALLOWED TO SHARE A BUTTON, AND IT IS ONLY ALLOWED BECAUSE THE
## SECTION BELOW MEASURES IT.
##
## 🧑 answered the other one on 2026-07-30: **Space is jump only**, so `bump` moved to F
## (`project.godot`, plus a `settings_manager.gd` migration, because every settings.cfg on
## disk still held `bump=32` and would have put it straight back). That leaves LEFT CLICK on
## both `grab` and `special_ability` — which is DESIGNED: one button picks the tsinelas up
## and then winds it up, the tutorial advertises "Q / LEFT CLICK · Special", and
## `_check_charge_on_shared_button()` drives exactly that sequence and measures the charge
## that comes out of it (0.807 peak, and 0 means the wind-up never started).
##
## Keyed on the sorted action list, not just the input, so this exempts THAT pair on THAT
## button and nothing else — a third action landing on left click still fails, and so does
## the same pair appearing on some other key.
const EXPECTED_SHARED: Array[String] = ["mouse:1:grab,special_ability"]

func _report_binding_conflicts() -> void:
	# Keyed by a stable description of the physical input, so a keyboard key and
	# a mouse button with the same numeric code cannot collide in this dictionary.
	var owners: Dictionary = {}
	for base in GAMEPLAY_ACTIONS:
		if not InputMap.has_action(base):
			continue
		for event in InputMap.action_get_events(base):
			var key := ""
			if event is InputEventKey:
				var ev := event as InputEventKey
				var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
				if code == 0:
					continue
				key = "key:%s" % OS.get_keycode_string(code)
			elif event is InputEventMouseButton:
				key = "mouse:%d" % (event as InputEventMouseButton).button_index
			elif event is InputEventJoypadButton:
				key = "pad:%d" % (event as InputEventJoypadButton).button_index
			else:
				continue
			if not owners.has(key):
				owners[key] = []
			(owners[key] as Array).append(base)
	var clashes: Array[String] = []
	for key in owners:
		var actions: Array = owners[key]
		if actions.size() > 1:
			var sorted := (actions as Array).duplicate()
			sorted.sort()
			if EXPECTED_SHARED.has("%s:%s" % [key, ",".join(sorted)]):
				print("  shared    : %s -> %s (intended — see EXPECTED_SHARED)"
					% [key, ", ".join(actions)])
				continue
			clashes.append("%s -> %s" % [key, ", ".join(actions)])
	_checks += 1
	if clashes.is_empty():
		print("  conflicts : none — every physical input drives exactly one action")
		return
	_fails += 1
	print("  *** FAIL: one physical input drives more than one action ***")
	for clash in clashes:
		print("      %s" % clash)

## ---------------------------------------------------------------------------
## THE BEHAVIOURAL HALF OF THE SAME REPORT, and the one that says whether the
## conflict above actually costs the player anything.
##
## `carrier.gd::_step_grab()` runs BEFORE `_step_throw()` in the same frame, and
## `_request_grab` is a round trip — so on the frame a left click picks the
## tsinelas up, `_held` is still null when `_step_throw` looks, and it takes the
## "nothing in hand" branch and calls `_cancel_charge()`. By the next frame the
## slipper has arrived but `special_ability` is no longer JUST pressed, only
## held, so the charge never starts. The player holds the button and nothing
## winds up — exactly the report.
##
## Measured by pressing the two actions TOGETHER, which is what one left click
## does, and asking whether the charge meter ever leaves zero.
## The keyboard-driven Person currently on the OFFENCE side, or null.
func _keyboard_attacker() -> CharacterBase:
	for node in _main.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch != null and ch.is_person and not ch.team_is_can_side \
				and not ch.input_parked and not ch.is_ai_driven():
			return ch
	return null

func _check_charge_on_shared_button() -> void:
	# ⚠️ THE HUMAN IS NOT THE ATTACKER IN ROUND 1, and the first version of this
	# check simply reported "no keyboard-driven attacking Person to test" and
	# passed over the whole question. `_start_local_test` gives the keyboard
	# TeamAPerson while `team_a_is_can` starts true, so the human opens on
	# DEFENCE and only the AI has a tsinelas. Swap roles first rather than
	# skipping — a check that quietly does nothing is worse than no check.
	print("\n  --- LEFT CLICK: grab and wind-up on one button ---")
	var attacker := _keyboard_attacker()
	if attacker == null:
		# ⚠️ NO ARGUMENT. `report_round_result()` took a "did the attackers win" bool when
		# a round had two teams and one of them won it; scoring is per-seat and
		# cumulative now, so the function reads the scores itself and there is nothing
		# left to tell it.
		MatchManager.report_round_result()
		await get_tree().create_timer(4.0).timeout
		attacker = _keyboard_attacker()
		print("  (swapped roles once so the keyboard unit is on offence)")
	_checks += 1
	if attacker == null:
		print("  *** FAIL: no keyboard-driven attacking Person to test ***")
		_fails += 1
		return
	var carrier := attacker.get_node_or_null("Carrier") as Carrier
	if carrier == null:
		print("  *** FAIL: the attacker has no Carrier ***")
		_fails += 1
		return

	# One left click = both actions, pressed on the same frame and held.
	Input.action_press("grab")
	Input.action_press("special_ability")
	var peak := 0.0
	var held_at := -1
	for i in 40:
		await get_tree().physics_frame
		peak = maxf(peak, carrier.charge_meter())
		if held_at < 0 and carrier.held() != null:
			held_at = i
	Input.action_release("grab")
	Input.action_release("special_ability")
	await get_tree().physics_frame

	print("  slipper in hand after      : %s" % (
		"%d frames" % held_at if held_at >= 0 else "never"))
	print("  peak charge while holding  : %.3f  (0.0 means the wind-up never started)" % peak)
	if held_at >= 0 and peak <= 0.001:
		_fails += 1
		print("  *** FAIL: the attacker grabbed the tsinelas and then never wound up,")
		print("      on a button that was held down the whole time. `grab` and")
		print("      `special_ability` share LEFT CLICK; the grab consumes the frame")
		print("      and special_ability is never JUST-pressed again. ***")
	elif peak > 0.001:
		print("  OK — the wind-up starts and charges on a held button.")
	else:
		print("  INCONCLUSIVE — nothing was grabbed, so the charge was never reachable.")
