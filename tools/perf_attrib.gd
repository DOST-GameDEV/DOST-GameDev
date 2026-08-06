extends Node3D

const SENTINEL: GDScript = preload("res://tools/perf_sentinel.gd")
const SAMPLES: int = 180
const WARMUP: int = 60
const CASES: Array[String] = ["everything on", "no AI", "no AI+visuals", "no AI+visuals+HUD"]

var _map_id: StringName = &"eskinita"
var _main: Node = null
var _hud: Node = null
var _visuals: Array[Node] = []
var _ais: Array[Node] = []

var _open: Node = null
var _close: Node = null
var _case: int = 0
var _samples: Array[float] = []
var _n: int = 0
var _results: Array[String] = []
var _ready_to_sample: bool = false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var token := String(arg)
		if token.begins_with("map="):
			_map_id = StringName(token.substr(4))
	GameLaunch.selected_map = _map_id
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(2.0).timeout

	_hud = _main.find_child("HUD", true, false)
	for node in _main.find_children("*", "CharacterVisual", true, false):
		_visuals.append(node)
	for node in _main.find_children("*", "AIController", true, false):
		_ais.append(node)

	_open = _sentinel("PerfOpen", -1000)
	_close = _sentinel("PerfClose", 1000)
	process_priority = 2000
	_apply()
	_ready_to_sample = true

func _sentinel(node_name: String, priority: int) -> Node:
	var n := Node.new()
	n.name = node_name
	n.process_priority = priority
	n.set_script(SENTINEL)
	get_tree().root.add_child(n)
	return n

func _apply() -> void:
	var c: String = CASES[_case]
	for ai in _ais:
		ai.set_process(c == "everything on")
		ai.set_physics_process(c == "everything on")
	for v in _visuals:
		v.set_process(c in ["everything on", "no AI"])
	if _hud != null:
		_hud.set_process(c != "no AI+visuals+HUD")
	_samples.clear()
	_n = 0

func _process(_delta: float) -> void:
	if not _ready_to_sample:
		return
	_n += 1
	if _n <= WARMUP:
		return
	var span: float = float(_close.stamp - _open.stamp) / 1000.0
	if span > 0.0:
		_samples.append(span)
	elif _n > WARMUP + SAMPLES * 4:
		push_error("perf_attrib: sentinels never stamped; span stayed 0. Aborting.")
		get_tree().quit(1)
		return
	if _samples.size() < SAMPLES:
		return
	_record()

func _record() -> void:
	var sorted := _samples.duplicate()
	sorted.sort()
	var med: float = sorted[sorted.size() / 2]
	var p95: float = sorted[int(sorted.size() * 0.95)]
	_results.append("  %-20s  script median %6.3f ms   p95 %6.3f ms"
		% [CASES[_case], med, p95])
	_case += 1
	if _case < CASES.size():
		_apply()
		return
	print("\n=== SCRIPT _process COST — %s, real match scene ===" % _map_id)
	print("  mesh instances: %d   bodies: %d   ai controllers: %d"
		% [_main.find_children("*", "MeshInstance3D", true, false).size(),
			_visuals.size(), _ais.size()])
	for line in _results:
		print(line)
	print("  Each row switches one more subsystem off; the DIFFERENCE between")
	print("  consecutive rows is that subsystem's per-frame script cost.")
	print("  Physics, rendering and audio are not in these numbers.")
	get_tree().quit()

