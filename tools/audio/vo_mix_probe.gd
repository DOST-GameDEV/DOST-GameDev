extends Node3D

const SETTLE_S := 1.0
const PHASE_S := 14.0

enum { SETTLE, VO_ONLY, MATCH_NO_VO, MATCH_WITH_VO, DONE }

const PHASE_NAMES := {
	VO_ONLY: "VO ONLY        (the announcer alone)",
	MATCH_NO_VO: "MATCH, no voice (SFX + music bed)",
	MATCH_WITH_VO: "MATCH + voice   (what a player hears)",
}

var _cap: Dictionary = {}
var _sum_sq: Dictionary = {}
var _count: Dictionary = {}
var _peak: Dictionary = {}
var _phase: int = SETTLE
var _phase_t: float = 0.0
var _vo_i: int = 0
var _results: Dictionary = {}
var _log: PackedStringArray = []
var _main: Node = null

const VO_CYCLE := ["count_3", "count_2", "count_1", "count_go",
	"clock_30", "clock_10", "match_win", "match_draw"]


func _emit(s: String) -> void:
	print(s)
	_log.append(s)


func _ready() -> void:
	for bus_name in ["SFX", "Music", "Master"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			continue
		var cap := AudioEffectCapture.new()
		cap.buffer_length = 2.0
		AudioServer.add_bus_effect(idx, cap)
		_cap[bus_name] = cap
	_reset_meters()
	_main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(_main)
	await get_tree().process_frame
	_emit("=== VO MIX PROBE — checklist 4.7 ===")
	_emit("VO_TRIM_DB   = %+.1f dB" % AudioManager.VO_TRIM_DB)
	_emit("HEADROOM_DB  = %+.1f dB   (every SFX)" % AudioManager.HEADROOM_DB)
	_emit("MUSIC_BASE_DB= %+.1f dB" % AudioManager.MUSIC_BASE_DB)
	_emit("")


func _reset_meters() -> void:
	for b in _cap:
		_sum_sq[b] = 0.0
		_count[b] = 0
		_peak[b] = 0.0
		(_cap[b] as AudioEffectCapture).clear_buffer()


func _process(delta: float) -> void:
	for bus_name in _cap:
		var cap: AudioEffectCapture = _cap[bus_name]
		var avail := cap.get_frames_available()
		if avail > 0:
			for f in cap.get_buffer(avail):
				var mono: float = (f.x + f.y) * 0.5
				_sum_sq[bus_name] = float(_sum_sq[bus_name]) + mono * mono
				_count[bus_name] = int(_count[bus_name]) + 1
				_peak[bus_name] = maxf(float(_peak[bus_name]), absf(mono))

	_phase_t += delta
	if _phase == VO_ONLY or _phase == MATCH_WITH_VO:
		if int(_phase_t / 0.7) > _vo_i:
			_vo_i += 1
			var id: String = VO_CYCLE[_vo_i % VO_CYCLE.size()]
			AudioManager._vo_cooldown_until_ms[id] = 0
			AudioManager.play_vo(id)

	var limit := SETTLE_S if _phase == SETTLE else PHASE_S
	if _phase_t < limit:
		return
	_advance()


func _advance() -> void:
	if _phase != SETTLE:
		_record(_phase)
	_phase += 1
	_phase_t = 0.0
	_vo_i = 0
	_reset_meters()
	match _phase:
		VO_ONLY:
			AudioManager.stop_music_now()
		MATCH_NO_VO:
			MatchManager.begin_next_round()
		MATCH_WITH_VO:
			pass
		DONE:
			_finish()


func _record(phase: int) -> void:
	var row := {}
	for b in ["SFX", "Music", "Master"]:
		if not _cap.has(b) or int(_count[b]) == 0:
			row[b] = null
			continue
		var rms: float = sqrt(float(_sum_sq[b]) / int(_count[b]))
		row[b] = {"rms": linear_to_db(maxf(rms, 0.000001)),
			"peak": linear_to_db(maxf(float(_peak[b]), 0.000001))}
	_results[phase] = row


func _finish() -> void:
	set_process(false)
	for phase in [VO_ONLY, MATCH_NO_VO, MATCH_WITH_VO]:
		_emit(String(PHASE_NAMES[phase]))
		var row: Dictionary = _results.get(phase, {})
		for b in ["SFX", "Music", "Master"]:
			var v = row.get(b)
			if v == null:
				_emit("    %-7s silent" % b)
			else:
				_emit("    %-7s RMS %7.1f dBFS   peak %7.1f dBFS%s" % [
					b, v["rms"], v["peak"],
					"   <-- CLIPPING" if v["peak"] >= -0.1 else ""])
		_emit("")

	var vo = _results.get(VO_ONLY, {}).get("SFX")
	var sfx = _results.get(MATCH_NO_VO, {}).get("SFX")
	var mus = _results.get(MATCH_NO_VO, {}).get("Music")
	var mixed = _results.get(MATCH_WITH_VO, {}).get("Master")
	if vo != null and sfx != null:
		_emit("VOICE vs EFFECTS : %+.1f dB peak, %+.1f dB RMS" % [
			vo["peak"] - sfx["peak"], vo["rms"] - sfx["rms"]])
	if vo != null and mus != null:
		_emit("VOICE vs MUSIC   : %+.1f dB peak" % (vo["peak"] - mus["peak"]))
	if mixed != null:
		_emit("FULL MIX MASTER  : peak %+.1f dBFS%s" % [
			mixed["peak"],
			"   <-- OVER, the limiter is working and something is too hot"
				if mixed["peak"] >= -0.5 else "   (headroom ok)"])
	var file := FileAccess.open("user://vo_mix_probe.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
		print("wrote ", ProjectSettings.globalize_path("user://vo_mix_probe.txt"))
	get_tree().quit(0)

