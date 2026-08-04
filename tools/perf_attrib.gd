extends Node3D
## WHERE THE CPU FRAME ACTUALLY GOES, PER SUBSYSTEM — the measurement
## `tools/perf_probe.gd` cannot make.
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/perf_attrib.tscn \
##         --resolution 1920x1080 -- map=eskinita
##
## ⚠️ PLAIN EXE, NOT --headless — the match has to actually render for these
## numbers to mean anything, and there is no rendering device under headless on
## this machine.
##
## ⚠️⚠️ WHY THIS EXISTS RATHER THAN A SECOND CASE IN perf_probe.gd.
## `perf_probe.gd` reports `Performance.TIME_PROCESS + TIME_PHYSICS_PROCESS` and
## calls it "cpu median". TIME_PROCESS is the time to complete a WHOLE FRAME,
## present-wait included — not time spent in script. That is why its own output
## reads "cpu median 16.83 ms ... fps 90": 16.83 ms per frame is 59 fps, and both
## cannot be true at once. Every "cpu" number that probe has printed is a vsync
## reading, and it attributes nothing.
##
## ⚠️⚠️ AND WHY IT DOES NOT MEASURE WALL-CLOCK EITHER. The first version of this
## file sampled `delta` with vsync disabled and `Engine.max_fps = 0`. It reported
## median 8.33 ms AND p95 8.33 ms — identical to the hundredth, across both maps,
## windowed and fullscreen, with `window_get_vsync_mode()` confirming DISABLED.
## A distribution with no spread is not a measurement; that is the 120 Hz panel,
## which this machine's compositor keeps flipping on regardless of what the
## engine asks for. Wall-clock frame time cannot see headroom on this box at all.
##
## So this brackets the frame's ENTIRE script `_process` pass between two sentinel
## nodes — one at the lowest `process_priority`, one at the highest — and reports
## the microseconds between them. That number is real work, and it is independent
## of whatever the display is doing. Each case then switches one subsystem off and
## re-measures, so the cost is attributed by difference rather than guessed.
##
## The subsystems are the three whose per-frame work scales with the match:
## the HUD (one `_process`, but it rewrites theme overrides), the character
## visuals (one `_process` per body), and the AI (three bots in solo, none in a
## full lobby — which is why solo is the heavier case and the one to measure).

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

	# ⚠️ THE SENTINELS GO UNDER `root`, NOT UNDER THIS NODE. `process_priority`
	# orders siblings within the same parent's pass; to bracket EVERY node in the
	# tree the two have to sit at the top level, side by side with the match.
	_open = _sentinel("PerfOpen", -1000)
	_close = _sentinel("PerfClose", 1000)
	# ⚠️⚠️ THIS NODE MUST READ AFTER `_close`, AND AT PRIORITY 0 IT DID NOT.
	# The default put this `_process` BETWEEN the two sentinels, so every sample
	# was `_close`'s stamp from the PREVIOUS frame minus `_open`'s from the current
	# one — a negative span, discarded by the `span > 0.0` guard, forever. The probe
	# looked like it had dead sentinels when in fact both were stamping correctly
	# and the reader was standing in the wrong place.
	process_priority = 2000
	_apply()
	_ready_to_sample = true

func _sentinel(node_name: String, priority: int) -> Node:
	var n := Node.new()
	n.name = node_name
	n.process_priority = priority
	# ⚠️ preload, NOT load. A runtime `load()` of this path returned something whose
	# `_process` never ran — no error, no stamp, so `span` stayed 0.0 forever and the
	# probe hung waiting for samples it could never take. preload resolves at parse
	# time and fails loudly instead.
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

## Runs after both sentinels every frame — this node's own priority is 0, but the
## read happens on the NEXT frame's open, so `_close`'s stamp is always the one
## from the frame that just finished.
func _process(_delta: float) -> void:
	if not _ready_to_sample:
		return
	_n += 1
	if _n <= WARMUP:
		return
	var span: float = float(_close.stamp - _open.stamp) / 1000.0 # usec -> msec
	if span > 0.0:
		_samples.append(span)
	# ⚠️ HANG GUARD. A silently dead sentinel leaves `span` at 0.0 every frame, so
	# the sample array never fills and nothing below ever runs — which is exactly
	# how this probe hung twice for 300 s with no output at all. Fail out loud.
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
