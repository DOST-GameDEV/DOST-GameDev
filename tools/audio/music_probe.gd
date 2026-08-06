extends Node

func _ready() -> void:
	var watcher := Watcher.new()
	watcher.name = "MusicWatcher"
	watcher.process_mode = Node.PROCESS_MODE_ALWAYS
	AudioManager.add_child(watcher)
	get_tree().change_scene_to_file("res://scenes/ui/SplashScreen.tscn")


class Watcher extends Node:
	const AUDIBLE_DB: float = -40.0

	const SCREEN_DWELL: float = 2.5
	const PRE_READY_DWELL: float = 2.5
	const ROUND_DWELL: float = 7.0
	const AFTER_LEAVE_DWELL: float = 4.0
	const SPLASH_TIMEOUT: float = 14.0

	const MENU_CHAIN: Array[Array] = [
		["MainMenu", "res://scenes/ui/ModeSelect.tscn"],
		["ModeSelectScreen", "res://scenes/ui/MatchSetup.tscn"],
		["MatchSetupScreen", "res://scenes/main/Main.tscn"],
	]

	var _t: float = 0.0
	var _phase: int = 0
	var _phase_t: float = 0.0
	var _chain_step: int = 0
	var _last_line: String = ""
	var _log: PackedStringArray = []
	var _fails: PackedStringArray = []
	var _main: Node = null
	var _bed_under_splash: bool = false
	var _splash_seen: bool = false

	func _process(delta: float) -> void:
		_t += delta
		_phase_t += delta
		_sample()
		match _phase:
			0: _phase_splash()
			1: _phase_menu_chain()
			2: _phase_pre_ready()
			3: _phase_round()
			4: _phase_left()


	func _scene_name() -> String:
		var scene := get_tree().current_scene
		if scene == null or not is_instance_valid(scene):
			return "<none>"
		var script_res: Script = scene.get_script() as Script
		if script_res != null and script_res.get_global_name() != &"":
			return String(script_res.get_global_name())
		return scene.name

	func _bed(index: int) -> Dictionary:
		var player: AudioStreamPlayer = AudioManager._music_players[index]
		var track := ""
		for key in AudioManager._music_streams:
			if AudioManager._music_streams[key] == player.stream:
				track = String(key)
				break
		return {
			"track": track,
			"playing": player.playing,
			"db": player.volume_db,
			"audible": player.playing and player.volume_db > AUDIBLE_DB,
		}

	func _audible_track() -> String:
		for i in 2:
			var bed := _bed(i)
			if bool(bed["audible"]):
				return String(bed["track"])
		return ""

	func _track_audible(track: String) -> bool:
		for i in 2:
			var bed := _bed(i)
			if String(bed["track"]) == track and bool(bed["audible"]):
				return true
		return false

	func _sample() -> void:
		var a := _bed(0)
		var b := _bed(1)
		var line := "%-16s | want=%-6s | A %-6s %s %4d | B %-6s %s %4d" % [
			_scene_name(), AudioManager._current_music_name,
			a["track"], "on " if a["playing"] else "off",
			int(float(a["db"]) / 6.0) * 6,
			b["track"], "on " if b["playing"] else "off",
			int(float(b["db"]) / 6.0) * 6]
		if line != _last_line:
			_last_line = line
			_emit("%6.2f  %s" % [_t, line])
		if _scene_name() == "SplashScreen":
			_splash_seen = true
			if _audible_track() == "menu":
				_bed_under_splash = true

	func _emit(text: String) -> void:
		print(text)
		_log.append(text)

	func _check(label: String, ok: bool, detail: String) -> void:
		_emit("  %s  %s — %s" % ["PASS" if ok else "FAIL", label, detail])
		if not ok:
			_fails.append(label)

	func _advance(next_phase: int) -> void:
		_phase = next_phase
		_phase_t = 0.0


	func _phase_splash() -> void:
		if _scene_name() == "MainMenu":
			_emit("--- reached MainMenu at %.2fs ---" % _t)
			_check("1 menu bed silent under the intro video", not _bed_under_splash,
				"splash seen: %s, bed audible during it: %s"
					% [_splash_seen, _bed_under_splash])
			_advance(1)
			return
		if _phase_t > SPLASH_TIMEOUT:
			_check("0 the boot flow reaches MainMenu", false,
				"still on '%s' after %.0fs" % [_scene_name(), SPLASH_TIMEOUT])
			_finish()

	func _phase_menu_chain() -> void:
		if _phase_t < SCREEN_DWELL:
			return
		var step := MENU_CHAIN[_chain_step]
		var expected := String(step[0])
		_check("2%s menu bed plays on %s" % ["abc"[_chain_step], expected],
			_scene_name() == expected and _audible_track() == "menu",
			"scene: '%s', audible: '%s'" % [_scene_name(), _audible_track()])
		var next_scene := String(step[1])
		if _chain_step == MENU_CHAIN.size() - 1:
			GameLaunch.pending_action = "local"
			GameLaunch.clear_seating()
			MatchManager.reset()
			RoundManager.reset()
			_emit("--- entering a Single Player match at %.2fs ---" % _t)
			get_tree().change_scene_to_file(next_scene)
			_advance(2)
			return
		_chain_step += 1
		get_tree().change_scene_to_file(next_scene)
		_phase_t = 0.0

	func _phase_pre_ready() -> void:
		if _main == null or not is_instance_valid(_main):
			var scene := get_tree().current_scene
			if scene != null and scene.has_method("_rpc_begin_ready_countdown"):
				_main = scene
			return
		if _phase_t < PRE_READY_DWELL:
			return
		_check("2d menu bed is cut on entering the match", not _track_audible("menu"),
			"free-roam window, menu player audible: %s" % _track_audible("menu"))
		_emit("--- ready-up (starts the 3-2-1) at %.2fs ---" % _t)
		_main.call("_rpc_begin_ready_countdown")
		_advance(3)

	func _phase_round() -> void:
		if _phase_t < ROUND_DWELL:
			return
		_check("3a round bed plays in the match", _audible_track() == "match",
			"audible: '%s', round_active: %s"
				% [_audible_track(), RoundManager.round_active])
		_check("3b menu bed is silent in the match", not _track_audible("menu"),
			"menu player audible: %s" % _track_audible("menu"))
		_emit("--- leaving the match for the menu at %.2fs ---" % _t)
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		_advance(4)

	func _phase_left() -> void:
		if _phase_t < AFTER_LEAVE_DWELL:
			return
		_check("4a round bed stops on leaving the match", not _track_audible("match"),
			"match player audible: %s" % _track_audible("match"))
		_check("4b menu bed returns", _audible_track() == "menu",
			"audible: '%s'" % _audible_track())
		_finish()

	func _finish() -> void:
		set_process(false)
		_emit("")
		if _fails.is_empty():
			_emit("MUSIC PROBE: all checks PASS")
		else:
			_emit("MUSIC PROBE: %d FAIL — %s" % [_fails.size(), ", ".join(_fails)])
		var file := FileAccess.open("user://music_probe.txt", FileAccess.WRITE)
		if file != null:
			file.store_string("\n".join(_log) + "\n")
			file.close()
			print("wrote ", ProjectSettings.globalize_path("user://music_probe.txt"))
		get_tree().quit(0 if _fails.is_empty() else 1)

