extends Node
class_name AudioManagerScript


const UI_VOICES: int = 8
const WORLD_VOICES: int = 12

const WORLD_UNIT_SIZE: float = 12.0
const WORLD_MAX_DISTANCE: float = 30.0

const RETRIGGER_MS: int = 60

const PITCH_JITTER: float = 0.07

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"

const MUSIC_PATHS: Dictionary = {
	"menu": "ost_menu.mp3",
	"match": "ost_match.mp3",
}
const MUSIC_CROSSFADE_TIME: float = 1.5
const MUSIC_BASE_DB: float = -6.0
const MUSIC_LIFT_DB: float = 4.0
const MUSIC_LIFT_SECONDS_LEFT: float = 15.0
const MUSIC_LIFT_TIME: float = 1.0
const MUSIC_DUCK_DB: float = -10.0
const MUSIC_DUCK_ATTACK: float = 0.12
const MUSIC_DUCK_HOLD: float = 0.5
const MUSIC_DUCK_RELEASE: float = 0.8
const VO_DUCK_DB: float = -14.0
const VO_DUCK_MIN_HOLD: float = 0.5
const MUSIC_DUCK_TRIGGERS: PackedStringArray = [
	"countdown_tick", "countdown_go", "round_end", "match_win", "round_lose",
	"score_award",
]

const VO_DIR: String = "res://assets/audio/vo/"
const VO_TRIM_DB: float = -1.0
const VO_COOLDOWN_MS: Dictionary = {
	"tumbang": 6000, "taya": 5000, "ayos": 4000,
	"clock_30": 0, "clock_10": 0,
	"match_win": 0, "match_draw": 0, "title": 0,
	"count_3": 0, "count_2": 0, "count_1": 0, "count_go": 0,
	"count_5": 0, "count_4": 0,
}
const VO_DEFAULT_COOLDOWN_MS: int = 4000

const SFX_NAMES: PackedStringArray = [
	"lata_impact", "lata_knockdown", "lata_seal",
	"reset_channel_start", "reset_channel_complete",
	"bump", "tag", "downed", "jump", "land", "dash", "guard_block", "respawn",
	"stamina_empty",
	"hit_body", "bump_swing",
	"throw_whoosh", "throw_charge", "slipper_land", "slipper_bounce", "grab",
	"can_knockdown", "reset_complete", "pickup", "throw_release",
	"ability_bagsak_bomb", "ability_bakya_bash", "ability_flick_dash",
	"ability_shatter_trap", "ability_spin_guard",
	"countdown_tick", "countdown_go", "round_win", "round_lose", "match_win",
	"round_end", "score_award",
	"ui_click", "ui_hover", "ui_back", "ui_error",
	"boot_sting",
]

const SFX_ALIASES: Dictionary = {
	"hit_body": "bump",
	"bump_swing": "dash",
	"can_knockdown": "lata_knockdown",
	"reset_complete": "reset_channel_complete",
	"pickup": "grab",
	"throw_release": "throw_whoosh",
}

const _NO_JITTER: PackedStringArray = [
	"ui_click", "ui_hover", "ui_back", "ui_error",
	"countdown_tick", "countdown_go", "round_win", "round_lose", "match_win",
	"boot_sting",
]

const HEADROOM_DB: float = -7.0

const _TRIM_DB: Dictionary = {
	"lata_impact": 0.0,
	"lata_seal": 0.0,
	"match_win": 0.0,
	"ui_hover": -8.0,
	"ui_click": -3.0,
	"slipper_bounce": -4.0,
	"land": -6.0,
	"jump": -4.0,
	"throw_charge": -5.0,
	"grab": -6.0,
	"throw_whoosh": -4.0,
	"slipper_land": -3.0,
	"dash": -3.0,
}

var _streams: Dictionary = {}
var _retrigger_ms: Dictionary = {}
var _ui_voices: Array[AudioStreamPlayer] = []
var _world_voices: Array[AudioStreamPlayer3D] = []
var _ui_next: int = 0
var _world_next: int = 0
var _last_played_ms: Dictionary = {}

var _music_streams: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _music_active_index: int = 0
var _current_music_name: String = ""
var _music_lift_on: bool = false
var _music_fade_tweens: Array[Tween] = [null, null]
var _music_duck_tween: Tween = null

var _vo_takes: Dictionary = {}
var _vo_last_take: Dictionary = {}
var _vo_cooldown_until_ms: Dictionary = {}
var _vo_voices: Array[AudioStreamPlayer] = []
var _vo_next: int = 0
var _clock_30_said: bool = false
var _clock_10_said: bool = false
var _count_said: int = 0
var _music_scene_state: String = ""

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_streams()
	_build_voices()
	_install_master_limiter()
	_load_music()
	_build_music_players()
	_load_vo()
	_build_vo_voices()
	MatchManager.round_started.connect(_on_round_started_music)
	MatchManager.match_won.connect(_on_match_won_music)
	MatchManager.score_changed.connect(_on_score_changed_audio)
	MatchManager.round_started.connect(_on_round_started_vo)
	MatchManager.match_won.connect(_on_match_won_vo)
	RoundManager.lata_knocked.connect(_on_lata_knocked_vo)
	RoundManager.attacker_tagged.connect(_on_attacker_tagged_vo)
	RoundManager.lata_restored.connect(_on_lata_restored_vo)



func _load_music() -> void:
	for track_name in MUSIC_PATHS:
		var path := MUSIC_DIR + String(MUSIC_PATHS[track_name])
		if not ResourceLoader.exists(path):
			push_warning("AudioManager: missing music '%s' — see docs/HUMAN.md § TABLE D" % path)
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			push_warning("AudioManager: '%s' did not load as an AudioStream" % path)
			continue
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_music_streams[track_name] = stream


func _build_music_players() -> void:
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.volume_db = -80.0
		add_child(player)
		_music_players.append(player)


func play_music(track_name: String, fade_time: float = MUSIC_CROSSFADE_TIME) -> void:
	if track_name == _current_music_name:
		return
	var stream: AudioStream = _music_streams.get(track_name)
	if stream == null:
		return
	_current_music_name = track_name
	var old_index := _music_active_index
	var new_index := 1 - old_index
	var old_player := _music_players[old_index]
	var new_player := _music_players[new_index]
	new_player.stream = stream
	new_player.volume_db = -80.0
	new_player.play()
	_music_active_index = new_index
	var target_db := _music_target_db()
	_fade_music_player(new_index, target_db, fade_time)
	if old_player.playing:
		_fade_music_player(old_index, -80.0, fade_time, true)


func _fade_music_player(index: int, target_db: float, fade_time: float,
		stop_after: bool = false) -> void:
	if _music_fade_tweens[index] != null and _music_fade_tweens[index].is_valid():
		_music_fade_tweens[index].kill()
	var player := _music_players[index]
	if fade_time <= 0.0:
		player.volume_db = target_db
		if stop_after:
			player.stop()
		return
	var tween := create_tween()
	_music_fade_tweens[index] = tween
	tween.tween_property(player, "volume_db", target_db, fade_time)
	if stop_after:
		tween.tween_callback(player.stop)


func _music_target_db() -> float:
	return MUSIC_BASE_DB + (MUSIC_LIFT_DB if _music_lift_on else 0.0)


const MATCH_SCENE_PATH: String = "res://scenes/main/Main.tscn"

func _scene_state() -> String:
	var scene := get_tree().current_scene
	if scene == null or not is_instance_valid(scene):
		return ""
	if scene is SplashScreen:
		return "splash"
	if scene.scene_file_path == MATCH_SCENE_PATH:
		return "match"
	return "menu"


func _poll_scene_state() -> void:
	var state := _scene_state()
	if state == "" or state == _music_scene_state:
		return
	_music_scene_state = state
	match state:
		"menu":
			play_music("menu", 0.0)
			play_vo("title")
		"match":
			stop_music_now()
		"splash":
			stop_music_now()


func stop_music_now() -> void:
	for i in _music_players.size():
		if _music_fade_tweens[i] != null and _music_fade_tweens[i].is_valid():
			_music_fade_tweens[i].kill()
		_music_players[i].stop()
		_music_players[i].volume_db = -80.0
	if _music_duck_tween != null and _music_duck_tween.is_valid():
		_music_duck_tween.kill()
	_music_duck_tween = null
	_music_lift_on = false
	_current_music_name = ""


func _process(_delta: float) -> void:
	_poll_scene_state()
	var should_lift := RoundManager.round_active \
		and RoundManager.time_left <= MUSIC_LIFT_SECONDS_LEFT \
		and RoundManager.time_left > 0.0
	_set_music_lift(should_lift)
	if RoundManager.round_active and not _clock_30_said and RoundManager.time_left <= 30.0:
		_clock_30_said = true
		play_vo("clock_30")
		play_vo("bilis")
	if RoundManager.round_active and not _clock_10_said and RoundManager.time_left <= 10.0:
		_clock_10_said = true
		play_vo("clock_10")
	if RoundManager.round_active and RoundManager.time_left > 0.0:
		var whole := ceili(RoundManager.time_left)
		if whole <= 3 and whole != _count_said:
			_count_said = whole
			play_vo("count_%d" % whole)
	if not RoundManager.round_active:
		_clock_30_said = false
		_clock_10_said = false
		_count_said = 0


func _set_music_lift(on: bool) -> void:
	if on == _music_lift_on:
		return
	_music_lift_on = on
	_fade_music_player(_music_active_index, _music_target_db(), MUSIC_LIFT_TIME)


func _duck_music(hold: float = MUSIC_DUCK_HOLD, depth: float = MUSIC_DUCK_DB) -> void:
	if _music_duck_tween != null and _music_duck_tween.is_valid():
		_music_duck_tween.kill()
	var player := _music_players[_music_active_index]
	var floor_db := _music_target_db() + depth
	_music_duck_tween = create_tween()
	_music_duck_tween.tween_property(player, "volume_db", floor_db, MUSIC_DUCK_ATTACK)
	_music_duck_tween.tween_interval(hold)
	_music_duck_tween.tween_callback(func() -> void:
		if _music_duck_tween == null:
			return
		var release := create_tween()
		release.tween_property(player, "volume_db", _music_target_db(), MUSIC_DUCK_RELEASE))


func _on_round_started_music(_round_number: int, _defender_slot: int) -> void:
	play_music("match")


func _on_match_won_music(_winning_slot: int) -> void:
	play_music("menu")



func _load_vo() -> void:
	var dir := DirAccess.open(VO_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("vo_") \
				and file_name.ends_with(".wav"):
			var line_id := _vo_id_from_filename(file_name)
			if line_id != "":
				var stream := load(VO_DIR + file_name) as AudioStream
				if stream != null:
					if not _vo_takes.has(line_id):
						_vo_takes[line_id] = []
					(_vo_takes[line_id] as Array).append(stream)
		file_name = dir.get_next()
	dir.list_dir_end()


func _vo_id_from_filename(file_name: String) -> String:
	var stem := file_name.get_basename()
	if not stem.begins_with("vo_"):
		return ""
	stem = stem.substr(3)
	var last_us := stem.rfind("_")
	if last_us <= 0:
		return stem
	return stem.substr(0, last_us)


func _build_vo_voices() -> void:
	for i in 3:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_vo_voices.append(player)


func play_vo(line_id: String) -> void:
	var takes: Array = _vo_takes.get(line_id, [])
	if takes.is_empty():
		return
	var now := Time.get_ticks_msec()
	var cooldown: int = int(VO_COOLDOWN_MS.get(line_id, VO_DEFAULT_COOLDOWN_MS))
	if now < int(_vo_cooldown_until_ms.get(line_id, 0)):
		return
	_vo_cooldown_until_ms[line_id] = now + cooldown
	var index := randi() % takes.size()
	if takes.size() > 1 and index == int(_vo_last_take.get(line_id, -1)):
		index = (index + 1) % takes.size()
	_vo_last_take[line_id] = index
	var player := _vo_voices[_vo_next]
	_vo_next = (_vo_next + 1) % _vo_voices.size()
	player.stream = takes[index]
	player.volume_db = VO_TRIM_DB
	player.play()
	var take_length: float = VO_DUCK_MIN_HOLD
	var stream_length := player.stream.get_length() if player.stream != null else 0.0
	if stream_length > 0.0:
		take_length = maxf(take_length, stream_length)
	_duck_music(take_length, VO_DUCK_DB)


func play_countdown(tick_text: String) -> void:
	var is_go := tick_text == "GO!"
	play("countdown_go" if is_go else "countdown_tick")
	if is_go:
		play_vo("count_go")
	elif tick_text.is_valid_int():
		play_vo("count_%d" % tick_text.to_int())


func _on_round_started_vo(round_number: int, _defender_slot: int) -> void:
	if round_number == 1:
		play_vo("taya")


func _on_match_won_vo(winning_slot: int) -> void:
	play_vo("match_draw" if winning_slot < 0 else "match_win")


func _on_lata_knocked_vo(_by_slot: int) -> void:
	play_vo("tumbang")


func _on_lata_restored_vo() -> void:
	play_vo("lata_restored")


func _on_attacker_tagged_vo(_defender_slot: int, _victim_slot: int) -> void:
	play_vo("taya")
	play_vo("ayos")


func _on_score_changed_audio(_slot: int, _total: int, _delta: int, reason: String) -> void:
	if reason == "DEFENSE":
		return
	play("score_award")


func _install_master_limiter() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx < 0:
		push_warning("AudioManager: no 'Master' bus — cannot install the clipping limiter.")
		return
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -0.3
	limiter.threshold_db = 0.0
	AudioServer.add_bus_effect(master_idx, limiter)

	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx < 0:
		push_warning("AudioManager: no 'SFX' bus — cannot install its clipping limiter.")
		return
	var sfx_limiter := AudioEffectLimiter.new()
	sfx_limiter.ceiling_db = -1.0
	sfx_limiter.threshold_db = 0.0
	AudioServer.add_bus_effect(sfx_idx, sfx_limiter)


func _load_streams() -> void:
	for sound_name in SFX_NAMES:
		var file_stem: String = SFX_ALIASES.get(sound_name, sound_name)
		var path := SFX_DIR + file_stem + ".wav"
		if not ResourceLoader.exists(path):
			push_warning("AudioManager: missing '%s' — run tools/audio/generate_sfx.py" % path)
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			push_warning("AudioManager: '%s' did not load as an AudioStream" % path)
			continue
		_streams[sound_name] = stream
		_retrigger_ms[sound_name] = _retrigger_window(stream)


func _build_voices() -> void:
	for i in UI_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_ui_voices.append(player)
	for i in WORLD_VOICES:
		var player := AudioStreamPlayer3D.new()
		player.bus = &"SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.unit_size = WORLD_UNIT_SIZE
		player.max_distance = WORLD_MAX_DISTANCE
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		_world_voices.append(player)



func play(sound_name: String, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _take(sound_name)
	if stream == null:
		return
	var player := _ui_voices[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_voices.size()
	player.stream = stream
	player.volume_db = volume_db + _trim(sound_name)
	player.pitch_scale = _pitch(sound_name)
	player.play()
	if sound_name in MUSIC_DUCK_TRIGGERS:
		_duck_music()
	if sound_name == "countdown_tick":
		play_music("match", 0.0)


func play_at(sound_name: String, where: Vector3, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _take(sound_name)
	if stream == null:
		return
	var player := _world_voices[_world_next]
	_world_next = (_world_next + 1) % _world_voices.size()
	player.stream = stream
	player.global_position = where
	player.volume_db = volume_db + _trim(sound_name)
	player.pitch_scale = _pitch(sound_name)
	player.play()


func stop_all() -> void:
	for player in _ui_voices:
		player.stop()
	for player in _world_voices:
		player.stop()
	_last_played_ms.clear()

func _take(sound_name: String) -> AudioStream:
	var stream: AudioStream = _streams.get(sound_name)
	if stream == null:
		return null
	var window: int = int(_retrigger_ms.get(sound_name, RETRIGGER_MS))
	var now := Time.get_ticks_msec()
	if now - int(_last_played_ms.get(sound_name, -window)) < window:
		return null
	_last_played_ms[sound_name] = now
	return stream


func _retrigger_window(stream: AudioStream) -> int:
	var length_ms := int(roundf(stream.get_length() * 1000.0))
	return maxi(RETRIGGER_MS, length_ms)


func _trim(sound_name: String) -> float:
	return HEADROOM_DB + minf(float(_TRIM_DB.get(sound_name, 0.0)), 0.0)


func _pitch(sound_name: String) -> float:
	if sound_name in _NO_JITTER:
		return 1.0
	return randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)



func apply_volumes(master: float, sfx: float, music: float) -> void:
	master_volume = clampf(master, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	music_volume = clampf(music, 0.0, 1.0)
	_apply_bus("Master", master_volume)
	_apply_bus("SFX", sfx_volume)
	_apply_bus("Music", music_volume)


func _apply_bus(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_warning("AudioManager: no '%s' bus — is default_bus_layout.tres registered "
			% bus_name + "in project.godot under audio/buses/default_bus_layout?")
		return
	if linear <= 0.001:
		AudioServer.set_bus_mute(index, true)
		return
	AudioServer.set_bus_mute(index, false)
	AudioServer.set_bus_volume_db(index, linear_to_db(linear))

