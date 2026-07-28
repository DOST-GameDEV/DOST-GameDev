extends Node3D
## Checklist 8.3f — the frame-time capture Phase 8 shipped without.
##
## SDFGI, SSIL, glow, 4096 directional shadows, MSAA and ~510 dressing instances
## all landed in one phase on hardware nobody had profiled. This measures the
## real match scene, and then measures it again with the expensive effects off,
## so the cost is attributed rather than guessed.
##
##   godot --path . tools/perf_probe.tscn --quit-after 2000 --resolution 1920x1080
##
## Run WITHOUT --headless. Reports median and 95th-percentile frame time; the
## 95th is what a judge feels as a hitch, the median is what they see as smooth.

const SAMPLES := 180          # ~3 s per case at 60fps
const WARMUP := 90            # SDFGI needs time to converge its cascades
var _env: Environment
var _light: DirectionalLight3D
var _case := 0
var _n := 0
var _times: Array[float] = []
var _results: Array = []
const CASES := ["everything on", "no SDFGI", "no SDFGI+SSIL", "no GI/SSAO/glow"]

func _ready() -> void:
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
		print("\n=== 8.3f FRAME TIME — Eskinita, real match scene ===")
		print("  viewport: ", get_viewport().size)
		for r in _results:
			print(r)
		print("  NOTE: CPU process time only. GPU cost of SDFGI/SSIL is NOT in")
		print("  these numbers — compare the fps column for that.")
		get_tree().quit(0)
		return
	_apply()
