extends Node3D

const TRANSITIONS: int = 6
const PROBE_IMPULSE := Vector3(9.0, 4.0, 4.0)
const STILL_EPSILON: float = 0.15
const DRIFT_EPSILON: float = 0.10

var _main: Node
var _roster: Array[CharacterBase] = []
var _max_speed: Dictionary = {}
var _max_drift: Dictionary = {}
var _anchor: Dictionary = {}
var _was_active: bool = false
var _transitions_done: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	for c in _main.find_children("*", "CharacterBase", true, false):
		var character := c as CharacterBase
		if character.ai_controller != null:
			character.ai_controller.set_enabled(false)
		_roster.append(character)
		_max_speed[character] = 0.0
		_max_drift[character] = 0.0
	MatchManager.begin_next_round()
	await get_tree().create_timer(0.5).timeout
	set_physics_process(true)

	for i in TRANSITIONS:
		await get_tree().create_timer(1.5).timeout
		RoundManager.report_round_win(i % 2 == 0)
		_transitions_done += 1
		await get_tree().physics_frame
		await get_tree().physics_frame
		for c in _roster:
			if is_instance_valid(c):
				c.apply_knockback(PROBE_IMPULSE)
		await get_tree().create_timer(4.5).timeout
	_report()
	get_tree().quit(0)

func _physics_process(_delta: float) -> void:
	var active := RoundManager.round_active
	var in_gap := not active and MatchManager.round_number > 0
	if not in_gap:
		_was_active = active
		if active:
			_anchor.clear()
		return
	for c in _roster:
		if not is_instance_valid(c):
			continue
		if not _anchor.has(c):
			_anchor[c] = c.global_position
		_max_speed[c] = maxf(_max_speed[c], c.velocity.length())
		_max_drift[c] = maxf(_max_drift[c], (c.global_position - _anchor[c] as Vector3).length())
	_was_active = active

func _report() -> void:
	print("\n=== ROUND TRANSITION AUDIT (%d transitions, impulse %s fired into each gap) ==="
		% [_transitions_done, PROBE_IMPULSE])
	var worst_speed := 0.0
	var worst_drift := 0.0
	for c in _roster:
		worst_speed = maxf(worst_speed, _max_speed[c])
		worst_drift = maxf(worst_drift, _max_drift[c])
		print("  %-14s max speed in gap %6.2f m/s   max drift from reset spot %5.2f m"
			% [c.name, _max_speed[c], _max_drift[c]])
	var ok := worst_speed < STILL_EPSILON and worst_drift < DRIFT_EPSILON
	print("  VERDICT: %s" % ("PASS — every character stayed exactly where the reset put it"
		if ok else "*** FAIL — characters move between rounds (worst %.2f m/s, %.2f m) ***"
			% [worst_speed, worst_drift]))

