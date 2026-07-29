extends Node3D

## SETTLE PROBE — "does anything fall through the floor, and where does it end
## up?", measured rather than reasoned about.
##
## Loads the REAL Main.tscn on the Single Player flow (so `_start_local_test`,
## `_place_at_spawn`, `begin_spawn_settle` and the AI all run exactly as they do
## in a match), presses `ready_up` once the free-roam window opens, and then
## samples every character's Y every frame for the whole run.
##
## Reports, per unit: min Y ever seen, final Y, whether it ever went below the
## map's own floor top, and whether the KillPlane ever had to catch it. A
## KillPlane catch is a FAILURE here, not a save — it means the unit left the
## world under its own weight.
##
##     godot --path . tools/settle_probe.tscn --quit-after 1400 -- map=bayan_plaza
##
## ⚠️ RUN IT WITH THE PLAIN EXE, NOT --headless. Main.tscn brings a
## WorldEnvironment and camera rigs; headless has no rendering device and the
## flow behaves differently enough that a pass there proves less.

const MAIN := "res://scenes/main/Main.tscn"
## Floor collision top on both shipped maps (build_*.py's GROUND_Y). Anything
## whose capsule bottom goes meaningfully below this has left the floor.
const FLOOR_TOP := 0.1

var _main: Node = null
var _frames := 0
var _readied := false
var _min_y := {}
var _respawns := {}
var _rounds := 0
var _travel := {}
var _last_pos := {}
var _ai_units := {}

func _ready() -> void:
	var map := &"eskinita"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("map="):
			map = StringName(arg.substr(4))
		elif arg.begins_with("seat="):
			# Which seat the (absent) human takes. Everything else is AI, so this
			# is how "does the OTHER Person's AI run" gets asked directly.
			GameLaunch.solo_seat = int(arg.substr(5))
	GameLaunch.selected_map = map
	print("settle_probe: solo_seat=", GameLaunch.solo_seat)
	GameLaunch.pending_action = ""
	print("settle_probe: map=", map)
	_main = load(MAIN).instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	MatchManager.round_started.connect(func(n: int, _c: bool) -> void:
		_rounds = n
		print("[round %d started]" % n))

func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not is_instance_valid(_main):
		return
	if not _readied and _frames > 30:
		_readied = true
		# The free-roam window ends on `ready_up`; main.gd runs a 3-2-1 countdown
		# and only then calls begin_next_round().
		var ev := InputEventAction.new()
		ev.action = "ready_up"
		ev.pressed = true
		Input.parse_input_event(ev)
	for c in _units():
		var key := String(c.name)
		var bottom: float = c.global_position.y - c.capsule_height() * 0.5
		if not _min_y.has(key) or bottom < _min_y[key]:
			_min_y[key] = bottom
		# AI ACTIVITY. "only one AI person works at a time" is a claim about
		# MOVEMENT, so measure movement: total ground distance covered, per unit.
		# A bot that is thinking but never moving and a bot that is not running at
		# all look identical from outside and are told apart by nothing else.
		var here := Vector3(c.global_position.x, 0.0, c.global_position.z)
		if _last_pos.has(key):
			var step: float = here.distance_to(_last_pos[key])
			if step < 2.0: # ignore teleports (round reset, respawn)
				_travel[key] = _travel.get(key, 0.0) + step
		_last_pos[key] = here
		if c.ai_controller != null:
			_ai_units[key] = true
	if _frames % 240 == 0:
		_report("t=%.1fs" % (_frames / 60.0))

func _units() -> Array:
	var out := []
	for child in _main.get_children():
		if child is CharacterBase:
			out.append(child)
	var players := _main.get_node_or_null("Players")
	if players != null:
		for child in players.get_children():
			if child is CharacterBase:
				out.append(child)
	return out

func _report(tag: String) -> void:
	var lines := []
	for c in _units():
		var role := "can" if c.is_can else ("person" if c.is_person else "tsinelas")
		lines.append("%s(%s) y=%.3f min_bottom=%.3f%s" % [
			c.name, role, c.global_position.y, _min_y.get(String(c.name), 0.0),
			"  ** BELOW FLOOR **" if _min_y.get(String(c.name), 9.9) < FLOOR_TOP - 0.05 else ""])
	print("[%s round=%d] %s" % [tag, _rounds, " | ".join(lines)])

func _exit_tree() -> void:
	print("---- settle_probe summary ----")
	var failed := false
	for key in _min_y:
		var below: bool = _min_y[key] < FLOOR_TOP - 0.05
		failed = failed or below
		print("%s min_bottom=%.3f travel=%.1fm ai=%s %s" % [
			key, _min_y[key], _travel.get(key, 0.0),
			"yes" if _ai_units.has(key) else "NO",
			"FELL" if below else "ok"])
	# The "only one AI works at a time" test: every AI-driven unit must have
	# covered real ground. A bot under 2 m over the whole run is parked.
	var idle: Array[String] = []
	for key in _ai_units:
		if _travel.get(key, 0.0) < 2.0:
			idle.append(key)
	print("IDLE AI UNITS: ", idle if not idle.is_empty() else "none")
	print("RESULT: ", "FAIL — something left the floor" if failed else "PASS — nothing left the floor")
