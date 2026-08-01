extends Node
## MUSIC LIFECYCLE PROBE — does the right bed play in the right state?
##
##     godot --path . tools/audio/music_probe.tscn
##
## ⚠️ NOT `--headless`. It drives the REAL boot flow, and the first thing that
## flow does is decode `opening_animation.ogv` — a headless run has no rendering
## device, the video never reports finishing, and the whole measurement then
## describes the watchdog path rather than the one a player takes.
##
## Three faults were reported from play, 2026-08-01, and each has a phase here:
##
##   1. the menu bed is audible UNDER the intro video, ahead of the boot sting;
##   2. the menu bed keeps playing after the match starts ("the music doesnt
##      change");
##   3. the round bed does not stop when the match ends or the player leaves.
##
## ⚠️ IT MEASURES THE MIXER, NOT THE INTENT. Every check reads the two real
## `AudioStreamPlayer`s `AudioManager` owns — which stream each holds, whether it
## is `playing`, and its actual `volume_db` — rather than `_current_music_name`.
## That distinction is the whole point: `play_music()` sets the name FIRST and
## crossfades afterwards, so a run that asserted on the name would have passed
## while both beds were audible together, which is exactly one of the bugs.
##
## ⚠️ IT WALKS THE WHOLE SCREEN CHAIN, NOT MainMenu -> Main. The first version
## jumped straight from the title screen into the match and passed every check,
## which proves nothing about a player who goes through MODE SELECT and the
## CHARACTER/lobby screen on the way — and "Main Menu and Character Select
## music" is half of what was reported. Each screen is entered by the same
## `change_scene_to_file` its own button calls, so the chain under test is the
## one that ships.
##
## The watcher is parented to `AudioManager` (an autoload) rather than kept on
## this scene root, because every phase below is a `change_scene_to_file()` and a
## probe that lives on the current scene is freed by the first one.

func _ready() -> void:
	var watcher := Watcher.new()
	watcher.name = "MusicWatcher"
	watcher.process_mode = Node.PROCESS_MODE_ALWAYS
	AudioManager.add_child(watcher)
	# The real boot scene, not MainMenu directly: fault 1 is about the splash, and
	# a run that skips it cannot see the bug it is looking for.
	get_tree().change_scene_to_file("res://scenes/ui/SplashScreen.tscn")


class Watcher extends Node:
	## Anything quieter than this is inaudible against the SFX bus and counts as
	## silence. -80 is what `_build_music_players()` parks an idle player at, and
	## a crossfade passes through the range between, so the threshold has to be a
	## real gap rather than "not exactly -80".
	const AUDIBLE_DB: float = -40.0

	## Seconds to hold in each state before moving on. Generous against
	## `MUSIC_CROSSFADE_TIME` (1.5 s) so a fade that is merely slow is never
	## reported as a fade that never happened.
	const SCREEN_DWELL: float = 2.5
	const PRE_READY_DWELL: float = 2.5
	const ROUND_DWELL: float = 7.0
	const AFTER_LEAVE_DWELL: float = 4.0
	const SPLASH_TIMEOUT: float = 14.0

	## The menu screens, in the order a player meets them, and the scene each
	## one's own button loads. MODE SELECT and the CHARACTER/lobby screen are
	## both "menu states" for music purposes — the bed must be up and unchanged
	## across all three.
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
	## Set the first frame the menu bed is audible while SplashScreen is still the
	## current scene — fault 1, and it can only be caught in the moment.
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

	# -- measurement ---------------------------------------------------------

	func _scene_name() -> String:
		var scene := get_tree().current_scene
		if scene == null or not is_instance_valid(scene):
			return "<none>"
		var script_res: Script = scene.get_script() as Script
		if script_res != null and script_res.get_global_name() != &"":
			return String(script_res.get_global_name())
		return scene.name

	## (name, playing, volume_db) for each of AudioManager's two music players.
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

	## Which named bed is actually audible right now, or "" for silence. Reads the
	## players, never `_current_music_name` — see the class doc.
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

	## ⚠️ QUANTISED, AND WITHOUT THAT THE LOG IS UNREADABLE. A 1.5 s crossfade at
	## 165 fps writes ~250 lines that differ by 0.3 dB each; the first run buried
	## every verdict under two thousand of them. Bucketing to 6 dB keeps the shape
	## of a fade (a dozen lines) and still shows a bed that never moves.
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

	# -- phases --------------------------------------------------------------

	## 1 · THE INTRO VIDEO. The menu bed must not be audible while the splash is
	## up. Measured continuously in `_sample()` rather than sampled once, because
	## the window is only as long as the clip.
	func _phase_splash() -> void:
		if _scene_name() == "MainMenu":
			_emit("--- reached MainMenu at %.2fs ---" % _t)
			_check("1 menu bed silent under the intro video", not _bed_under_splash,
				"splash seen: %s, bed audible during it: %s"
					% [_splash_seen, _bed_under_splash])
			_advance(1)
			return
		if _phase_t > SPLASH_TIMEOUT:
			# ⚠️ A FAILURE, NOT AN EARLY EXIT. The first version of this file just
			# called `_finish()` here and printed "all checks PASS" for a run that
			# had measured nothing at all — the exact green-and-wrong probe § LOG
			# already records three of on this branch.
			_check("0 the boot flow reaches MainMenu", false,
				"still on '%s' after %.0fs" % [_scene_name(), SPLASH_TIMEOUT])
			_finish()

	## 2 · THE MENU STATES. Title -> mode select -> the CHARACTER/lobby screen.
	## The menu bed must be audible on every one of them, and it must be the SAME
	## bed rather than being restarted per screen.
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
			# The last hop is into the match, and it needs the handoff the lobby's
			# START button makes — see match_setup.gd's own launch path.
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

	## ⚠️ THE FREE-ROAM WINDOW, AND IT IS THE ONE THIS FILE ORIGINALLY MISSED.
	##
	## The first version called this "still a menu-ish state" and asserted
	## nothing here, so it passed every check while the actual reported bug sat
	## in this exact window: `Main.tscn` is loaded, the player is walking around
	## the arena, and the match bed has not started yet because it waits for the
	## first `countdown_tick`. The menu bed was audible for all of it — 🧑: *"main
	## menu ost audio still leaks into game"*. A probe that skips a state cannot
	## fail in it, which is a more expensive kind of green than a wrong assertion.
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

	## 3 · THE MATCH. By the time the round is running the round bed must be the
	## audible one AND the menu bed must be gone — two separate assertions,
	## because "both playing" is a distinct failure from "wrong one playing" and
	## it is the one the human actually reported.
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

	## 4 · LEAVING. The round bed must stop and the menu bed must come back.
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
		# Written as well as printed: the plain Windows exe does not reliably
		# deliver stdout to a redirected pipe, and the whole run is worthless if
		# the report cannot be read back.
		var file := FileAccess.open("user://music_probe.txt", FileAccess.WRITE)
		if file != null:
			file.store_string("\n".join(_log) + "\n")
			file.close()
			print("wrote ", ProjectSettings.globalize_path("user://music_probe.txt"))
		get_tree().quit(0 if _fails.is_empty() else 1)
