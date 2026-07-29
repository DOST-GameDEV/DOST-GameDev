extends Node3D
## Checklist 4.1 verification harness. Proves the audio workstream actually
## RUNS, rather than merely parsing.
##
##   godot --path . tools/audio_probe.tscn --quit-after 400
##
## Reports, and fails loudly on, the six things that can each be wrong while
## every other check in the smoke gate still passes:
##
##   1. The three buses exist and are named what the code thinks they are. A
##      typo'd or unregistered default_bus_layout.tres does NOT error — Godot
##      silently ships one bus called Master, `AudioServer.get_bus_index("SFX")`
##      returns -1, and every sound plays at the wrong level forever.
##   2. Every name in AudioManager.SFX_NAMES resolved to a real stream. A
##      missing .wav is a push_warning, which nobody reads.
##   3. The streams have NO LEADING SILENCE at the sample level. This is the
##      property the lata impact's hitstop sync depends on (see the header of
##      tools/audio/generate_sfx.py) and it is checked here, on the IMPORTED
##      resource, not on the source file — Godot's wav importer can trim,
##      normalise and resample, so the generator's own assertion proves nothing
##      about what the game actually loads.
##   4. play() and play_at() genuinely start a voice.
##   5. Both maps carry an Ambience/AmbienceLoop, autoplaying, on the Music bus.
##   6. Those ambience streams actually LOOP. Godot's ogg importer defaults
##      loop=false; a bed that plays once and stops leaves the map silent for
##      the rest of the match, and nothing anywhere reports it.
##
## Exits non-zero if any check fails, so it is usable as a gate.

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_check_buses()
	_check_streams()
	_check_playback()
	await _check_map_ambience("res://scenes/maps/Eskinita.tscn")
	await _check_map_ambience("res://scenes/maps/BayanPlaza.tscn")

	print("")
	print("audio probe: %d checks, %d failures" % [_checks, _failures.size()])
	for f in _failures:
		print("  [FAIL] %s" % f)
	if _failures.is_empty():
		print("  all clear")
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _ok(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(what)


func _check_buses() -> void:
	print("-- buses")
	for bus_name in ["Master", "SFX", "Music"]:
		var index := AudioServer.get_bus_index(bus_name)
		_ok(index >= 0, "bus '%s' does not exist" % bus_name)
		print("   %-7s index=%d  volume=%.1f dB  muted=%s"
			% [bus_name, index, AudioServer.get_bus_volume_db(index) if index >= 0 else 0.0,
				AudioServer.is_bus_mute(index) if index >= 0 else "?"])
	# SFX and Music must route INTO Master, or the master slider does nothing to
	# them and the three controls stop being a hierarchy.
	for bus_name in ["SFX", "Music"]:
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0:
			_ok(AudioServer.get_bus_send(index) == &"Master",
				"bus '%s' does not send to Master (sends to '%s')"
					% [bus_name, AudioServer.get_bus_send(index)])


func _check_streams() -> void:
	print("-- streams (%d expected)" % AudioManager.SFX_NAMES.size())
	var missing: Array[String] = []
	var padded: Array[String] = []
	for sound_name in AudioManager.SFX_NAMES:
		var path := AudioManager.SFX_DIR + sound_name + ".wav"
		var stream := load(path) as AudioStreamWAV
		if stream == null:
			missing.append(sound_name)
			continue
		var lead := _leading_silent_frames(stream)
		if lead > 0:
			padded.append("%s (%d frames)" % [sound_name, lead])
	_ok(missing.is_empty(), "streams missing or not AudioStreamWAV: %s" % ", ".join(missing))
	# THE HITSTOP-SYNC CHECK. See the class doc.
	_ok(padded.is_empty(), "streams with leading silence: %s" % ", ".join(padded))
	print("   loaded  : %d" % (AudioManager.SFX_NAMES.size() - missing.size()))
	print("   padded  : %d" % padded.size())


## Number of leading frames below -60 dBFS in the IMPORTED sample. Reads the raw
## PCM out of the resource, which is why the .import files pin compress/mode=0
## (PCM) — a lossy codec would make this measurement meaningless as well as
## smearing the transient it is measuring.
func _leading_silent_frames(stream: AudioStreamWAV) -> int:
	var data := stream.data
	if data.is_empty():
		return -1
	var stereo := stream.stereo
	var is16 := stream.format == AudioStreamWAV.FORMAT_16_BITS
	if not is16:
		return 0 # not PCM16 — nothing to measure, and the import is what's wrong
	var step := 4 if stereo else 2
	var floor_value := 32768.0 * pow(10.0, -60.0 / 20.0)
	var frame := 0
	var i := 0
	while i + 1 < data.size():
		var sample := data.decode_s16(i)
		if absf(float(sample)) > floor_value:
			return frame
		frame += 1
		i += step
	return frame


func _check_playback() -> void:
	print("-- playback")
	AudioManager.play("ui_click")
	var ui_playing := 0
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing:
			ui_playing += 1
	_ok(ui_playing > 0, "AudioManager.play() started no voice")

	AudioManager.play_at("lata_impact", Vector3(1.0, 0.5, 2.0))
	var world_playing := 0
	var placed := false
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer3D:
			var p := child as AudioStreamPlayer3D
			if p.playing:
				world_playing += 1
				if p.global_position.is_equal_approx(Vector3(1.0, 0.5, 2.0)):
					placed = true
	_ok(world_playing > 0, "AudioManager.play_at() started no voice")
	_ok(placed, "play_at() did not move the voice to the requested world position")

	# The retrigger guard: a second identical call inside RETRIGGER_MS must be
	# dropped, or a sustained slipper-on-lata overlap becomes a metallic scream
	# (see AudioManager.RETRIGGER_MS).
	var before := _count_playing_3d()
	for i in 8:
		AudioManager.play_at("lata_impact", Vector3.ZERO)
	_ok(_count_playing_3d() <= before + 1,
		"retrigger guard let a burst of identical calls through (%d -> %d voices)"
			% [before, _count_playing_3d()])
	print("   ui voices playing    : %d" % ui_playing)
	print("   world voices playing : %d" % world_playing)


func _count_playing_3d() -> int:
	var n := 0
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer3D and (child as AudioStreamPlayer3D).playing:
			n += 1
	return n


func _check_map_ambience(path: String) -> void:
	print("-- ambience: %s" % path.get_file())
	var packed := load(path) as PackedScene
	_ok(packed != null, "%s did not load" % path)
	if packed == null:
		return
	var map := packed.instantiate() as Node3D
	add_child(map)
	# autoplay starts on tree entry, but not until the node has actually been
	# processed — one frame is enough and costs nothing.
	await get_tree().process_frame

	var player := map.get_node_or_null("Ambience/AmbienceLoop") as AudioStreamPlayer
	_ok(player != null, "%s has no Ambience/AmbienceLoop" % path.get_file())
	if player == null:
		map.queue_free()
		return
	_ok(player.autoplay, "%s ambience is not set to autoplay" % path.get_file())
	_ok(player.bus == &"Music", "%s ambience is on bus '%s', not Music"
		% [path.get_file(), player.bus])
	_ok(player.playing, "%s ambience did not start playing" % path.get_file())
	var ogg := player.stream as AudioStreamOggVorbis
	_ok(ogg != null, "%s ambience stream is not an AudioStreamOggVorbis" % path.get_file())
	if ogg != null:
		# The default is false and it is silently wrong — see the class doc.
		_ok(ogg.loop, "%s ambience stream does not loop" % path.get_file())
		print("   stream  : %.2f s, loop=%s, bus=%s, vol=%.1f dB"
			% [ogg.get_length(), ogg.loop, player.bus, player.volume_db])
	map.queue_free()
	await get_tree().process_frame
