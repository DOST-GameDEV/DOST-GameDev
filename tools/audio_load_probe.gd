extends Node3D

const REPORT_EVERY_FRAMES: int = 600

var _starts: Dictionary = {}
var _last_playing: Dictionary = {}
var _last_pos: Dictionary = {}
var _peak_concurrent: int = 0
var _peak_at_frame: int = 0
var _frames: int = 0
var _concurrency_histogram: Dictionary = {}


func _ready() -> void:
	var main: Node = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	MatchManager.begin_next_round()


func _process(_delta: float) -> void:
	_frames += 1
	var concurrent := 0
	for voice in _voices():
		var id: int = voice.get_instance_id()
		var playing: bool = voice.playing
		var pos: float = voice.get_playback_position() if playing else 0.0
		var was: bool = _last_playing.get(id, false)
		var last_pos: float = _last_pos.get(id, 0.0)
		if playing:
			concurrent += 1
			if not was or pos < last_pos - 0.001:
				var stream_name := "?"
				if voice.stream != null:
					stream_name = str(voice.stream.resource_path).get_file().get_basename()
				_starts[stream_name] = int(_starts.get(stream_name, 0)) + 1
		_last_playing[id] = playing
		_last_pos[id] = pos

	_concurrency_histogram[concurrent] = int(_concurrency_histogram.get(concurrent, 0)) + 1
	if concurrent > _peak_concurrent:
		_peak_concurrent = concurrent
		_peak_at_frame = _frames

	if _frames % REPORT_EVERY_FRAMES == 0:
		_report()


func _voices() -> Array:
	var out: Array = []
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			out.append(child)
	return out


func _report() -> void:
	print("")
	print("=== frame %d (round_active=%s, round=%d) ==="
		% [_frames, RoundManager.round_active, MatchManager.round_number])
	var names := _starts.keys()
	names.sort_custom(func(a, b): return int(_starts[a]) > int(_starts[b]))
	var seconds := float(_frames) / 60.0
	for n in names:
		var count: int = _starts[n]
		print("  %-24s %5d starts   %6.2f /sec" % [n, count, count / seconds])
	print("  ---")
	print("  peak concurrent voices : %d  (frame %d)" % [_peak_concurrent, _peak_at_frame])
	var busy := 0
	for c in _concurrency_histogram:
		if int(c) >= 4:
			busy += int(_concurrency_histogram[c])
	print("  frames with >=4 voices : %d of %d (%.1f%%)"
		% [busy, _frames, 100.0 * busy / _frames])


func _exit_tree() -> void:
	_report()

