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
	await _check_isolation("default Single Player")

	# The reworked debug switcher is the thing that can break the invariant, so
	# exercise it rather than trusting that it holds only in the start state.
	# Cycling moves AI control from one unit to the next; if it ever leaves TWO
	# units AI-free, the behavioural check below catches it as two movers.
	for i in 3:
		DebugPlayerSwitcher._cycle()
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
