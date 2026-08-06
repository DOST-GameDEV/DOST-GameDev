extends Node3D

const REPORT_EVERY: int = 600

var _cap: Dictionary = {}
var _sum_sq: Dictionary = {}
var _count: Dictionary = {}
var _peak: Dictionary = {}
var _frames: int = 0


func _ready() -> void:
	for bus_name in ["SFX", "Music", "Master"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			continue
		var cap := AudioEffectCapture.new()
		cap.buffer_length = 2.0
		AudioServer.add_bus_effect(idx, cap)
		_cap[bus_name] = cap
		_sum_sq[bus_name] = 0.0
		_count[bus_name] = 0
		_peak[bus_name] = 0.0

	var main: Node = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	print("map = %s" % GameLaunch.selected_map_scene())
	MatchManager.begin_next_round()


func _process(_delta: float) -> void:
	_frames += 1
	for bus_name in _cap:
		var cap: AudioEffectCapture = _cap[bus_name]
		var available := cap.get_frames_available()
		if available <= 0:
			continue
		for f in cap.get_buffer(available):
			var mono: float = (f.x + f.y) * 0.5
			_sum_sq[bus_name] = float(_sum_sq[bus_name]) + mono * mono
			_count[bus_name] = int(_count[bus_name]) + 1
			_peak[bus_name] = maxf(float(_peak[bus_name]), absf(mono))
	if _frames % REPORT_EVERY == 0:
		_report()


func _report() -> void:
	print("")
	print("=== frame %d ===" % _frames)
	for bus_name in ["SFX", "Music", "Master"]:
		if not _cap.has(bus_name):
			continue
		var n: int = _count[bus_name]
		if n == 0:
			print("  %-7s silent" % bus_name); continue
		var rms: float = sqrt(float(_sum_sq[bus_name]) / n)
		print("  %-7s RMS %7.1f dBFS   peak %7.1f dBFS%s" % [
			bus_name,
			linear_to_db(maxf(rms, 0.000001)),
			linear_to_db(maxf(float(_peak[bus_name]), 0.000001)),
			"   <-- CLIPPING" if float(_peak[bus_name]) >= 0.999 else ""])
	if _count.get("SFX", 0) > 0 and _count.get("Music", 0) > 0:
		var sfx_rms: float = sqrt(float(_sum_sq["SFX"]) / int(_count["SFX"]))
		var mus_rms: float = sqrt(float(_sum_sq["Music"]) / int(_count["Music"]))
		var delta_db := linear_to_db(maxf(mus_rms, 0.000001)) - linear_to_db(maxf(sfx_rms, 0.000001))
		print("  --> ambience is %+.1f dB relative to SFX %s" % [
			delta_db,
			"(AMBIENCE DOMINATES THE MIX)" if delta_db > -6.0 else "(sits under, ok)"])


func _exit_tree() -> void:
	_report()
	var clipped: Array[String] = []
	for bus_name in _peak:
		if float(_peak[bus_name]) >= 0.999:
			clipped.append("%s (peak %+.1f dBFS)" % [bus_name,
				linear_to_db(float(_peak[bus_name]))])
	if clipped.is_empty():
		print("")
		print("  RESULT: no bus clipped. PASS")
	else:
		print("")
		print("  RESULT: CLIPPING on %s — FAIL" % ", ".join(clipped))

