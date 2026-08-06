extends Node3D


const MOVE_FRAMES: int = 30
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

	var control := await _displacements(false)
	var pressed := await _displacements(true)

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


const GAMEPLAY_ACTIONS: Array[String] = [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "bump", "guard_dash", "special_ability", "grab", "ready_up",
]

const EXPECTED_SHARED: Array[String] = ["mouse:1:grab,special_ability"]

func _report_binding_conflicts() -> void:
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

func _keyboard_attacker() -> CharacterBase:
	for node in _main.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch != null and ch.is_person and not ch.team_is_can_side \
				and not ch.input_parked and not ch.is_ai_driven():
			return ch
	return null

func _check_charge_on_shared_button() -> void:
	print("\n  --- LEFT CLICK: grab and wind-up on one button ---")
	var attacker := _keyboard_attacker()
	if attacker == null:
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

