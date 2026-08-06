extends Node3D

const SAMPLES := 180
const WARMUP := 90
var _env: Environment
var _light: DirectionalLight3D
var _case := 0
var _n := 0
var _times: Array[float] = []
var _results: Array = []
const CASES := ["everything on", "no SDFGI", "no SDFGI+SSIL", "no GI/SSAO/glow"]

var _map_id := &"eskinita"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var token := String(arg)
		if token.begins_with("map="):
			_map_id = StringName(token.substr(4))
	GameLaunch.selected_map = _map_id
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.0).timeout
	var we := main.find_child("WorldEnvironment", true, false) as WorldEnvironment
	_env = we.environment
	_light = main.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	_apply()

func _apply() -> void:
	var c: String = CASES[_case]
	_env.sdfgi_enabled = (c == "everything on")
	_env.ssil_enabled = c in ["everything on", "no SDFGI"]
	_env.ssao_enabled = c != "no GI/SSAO/glow"
	_env.glow_enabled = c != "no GI/SSAO/glow"
	_times.clear()
	_n = 0

func _process(_d: float) -> void:
	_n += 1
	if _n <= WARMUP:
		return
	_times.append(Performance.get_monitor(Performance.TIME_PROCESS)
		+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	if _times.size() < SAMPLES:
		return
	var fps := Engine.get_frames_per_second()
	var sorted := _times.duplicate(); sorted.sort()
	var med: float = sorted[sorted.size() / 2] * 1000.0
	var p95: float = sorted[int(sorted.size() * 0.95)] * 1000.0
	_results.append("  %-18s  cpu median %6.2f ms   p95 %6.2f ms   fps %d"
		% [CASES[_case], med, p95, fps])
	_case += 1
	if _case >= CASES.size():
		set_process(false)
		print("\n=== 8.3f FRAME TIME — %s, real match scene ===" % _map_id)
		print("  viewport: ", get_viewport().size)
		print("  mesh instances in scene: %d" % _count_instances())
		for r in _results:
			print(r)
		print("  NOTE: CPU process time only. GPU cost of SDFGI/SSIL is NOT in")
		print("  these numbers — compare the fps column for that.")
		get_tree().quit(0)
		return
	_apply()

func _count_instances() -> int:
	var n := 0
	for node in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		n += 1
	return n

