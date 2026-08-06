extends Node
class_name SettingsManagerScript


signal binding_changed(action: String)
signal player_name_changed(new_name: String)
signal fullscreen_changed(is_fullscreen: bool)

const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "input"

const REBINDABLE_ACTIONS: Array[String] = [
	"move_left", "move_right", "move_up", "move_down",
	"special_ability", "grab", "lunge", "jump", "sprint",
	"ready_up", "clean_feed",
	"emote_wheel",
	"toggle_fullscreen",
]

const ACTION_LABELS: Dictionary = {
	"move_left": "Move Left", "move_right": "Move Right",
	"move_up": "Move Up", "move_down": "Move Down",
	"special_ability": "Throw", "jump": "Jump", "sprint": "Sprint",
	"grab": "Grab",
	"lunge": "Lunge",
	"ready_up": "Ready Up",
	"emote_wheel": "Emote Wheel",
	"clean_feed": "Hide HUD (Spectator)",
	"toggle_fullscreen": "Toggle Fullscreen",
}

var _default_keycodes: Dictionary = {}

const SETTINGS_SECTION_CAMERA: String = "camera"
var mouse_sensitivity: float = 1.0
var invert_y: bool = false

const SETTINGS_SECTION_AUDIO: String = "audio"
const DEFAULT_VOLUME: float = 0.8

var master_volume: float = DEFAULT_VOLUME
var sfx_volume: float = DEFAULT_VOLUME
var music_volume: float = DEFAULT_VOLUME

const SETTINGS_SECTION_MATCH: String = "match"
const DEFAULT_DIFFICULTY: int = 1

var ai_difficulty: int = DEFAULT_DIFFICULTY

const SETTINGS_SECTION_DISPLAY: String = "display"
const DEFAULT_FULLSCREEN: bool = true

var fullscreen: bool = DEFAULT_FULLSCREEN

const HIGHLIGHT_OFF: int = 0

const SLIPPER_HIGHLIGHTS: Array[Dictionary] = [
	{"label": "Off", "color": Color(0.0, 0.0, 0.0)},
	{"label": "Blue", "color": Color(0.18, 0.55, 1.0)},
	{"label": "Purple", "color": Color(0.79, 0.13, 1.0)},
	{"label": "Red", "color": Color(1.0, 0.16, 0.16)},
	{"label": "Yellow", "color": Color(1.0, 0.95, 0.05)},
]

const DEFAULT_SLIPPER_HIGHLIGHT: int = 1

signal slipper_highlight_changed

var slipper_highlight: int = DEFAULT_SLIPPER_HIGHLIGHT

func set_slipper_highlight(value: int, persist: bool = true) -> void:
	slipper_highlight = clampi(value, 0, SLIPPER_HIGHLIGHTS.size() - 1)
	if persist:
		_save()
	slipper_highlight_changed.emit()

func slipper_highlight_enabled() -> bool:
	return slipper_highlight != HIGHLIGHT_OFF

func slipper_highlight_color() -> Color:
	var index := clampi(slipper_highlight, 0, SLIPPER_HIGHLIGHTS.size() - 1)
	return SLIPPER_HIGHLIGHTS[index]["color"]

func _ready() -> void:
	_capture_defaults()
	_load_and_apply()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen", false, true):
		set_fullscreen(not fullscreen)
		get_viewport().set_input_as_handled()

func set_fullscreen(value: bool, persist: bool = true) -> void:
	var changed := value != fullscreen
	fullscreen = value
	_apply_fullscreen()
	if changed:
		fullscreen_changed.emit(fullscreen)
	if persist:
		_save()

func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)

func set_ai_difficulty(value: int, persist: bool = true) -> void:
	ai_difficulty = clampi(value, 0, AIController.DIFFICULTY_TIERS.size() - 1)
	_apply_ai_difficulty()
	if persist:
		_save()

func _apply_ai_difficulty() -> void:
	AIController.apply_difficulty(ai_difficulty as AIController.Difficulty)

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = value
	_save()

func set_invert_y(value: bool) -> void:
	invert_y = value
	_save()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save()

func _apply_volumes() -> void:
	AudioManager.apply_volumes(master_volume, sfx_volume, music_volume)

func _capture_defaults() -> void:
	for action in REBINDABLE_ACTIONS:
		_default_keycodes[action] = _first_physical_keycode(action)

func _first_physical_keycode(action: String) -> int:
	if not InputMap.has_action(action):
		return -1
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).physical_keycode
	return -1

func get_binding_display_name(action: String) -> String:
	var keycode := _first_physical_keycode(action)
	if keycode <= 0:
		return "—"
	return OS.get_keycode_string(keycode)

func rebind_action(action: String, physical_keycode: int) -> String:
	if not InputMap.has_action(action):
		return ""
	var conflict := _find_conflicting_action(action, physical_keycode)
	if conflict != "":
		return ACTION_LABELS.get(conflict, conflict)
	_set_binding(action, physical_keycode)
	return ""

func _find_conflicting_action(action: String, physical_keycode: int) -> String:
	for other_action in REBINDABLE_ACTIONS:
		if other_action != action and _first_physical_keycode(other_action) == physical_keycode:
			return other_action
	return ""

func _replace_key_binding(action: String, physical_keycode: int) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var replacement := InputEventKey.new()
	replacement.physical_keycode = physical_keycode
	InputMap.action_add_event(action, replacement)

func _set_binding(action: String, physical_keycode: int) -> void:
	_replace_key_binding(action, physical_keycode)
	binding_changed.emit(action)
	_save()

func reset_action_to_default(action: String) -> void:
	if not _default_keycodes.has(action):
		return
	_set_binding(action, _default_keycodes[action])

func reset_all_to_default() -> void:
	for action in REBINDABLE_ACTIONS:
		reset_action_to_default(action)

const PLAYER_NAME_MAX: int = 14
const DEFAULT_PLAYER_NAME: String = ""

var player_name: String = DEFAULT_PLAYER_NAME

static func sanitise_name(raw: String) -> String:
	var clean := raw.strip_edges()
	clean = clean.replace("\n", " ").replace("\t", " ").replace("\r", " ")
	if clean.length() > PLAYER_NAME_MAX:
		clean = clean.substr(0, PLAYER_NAME_MAX)
	return clean

func set_player_name(value: String, persist: bool = true) -> void:
	var clean := sanitise_name(value)
	if clean == player_name:
		return
	player_name = clean
	if persist:
		_save()
	player_name_changed.emit(player_name)

var _editing: bool = false
var _snapshot: Dictionary = {}

func begin_edit() -> void:
	if _editing:
		return
	_editing = true
	_snapshot = {
		"bindings": _current_binding_map(),
		"mouse_sensitivity": mouse_sensitivity,
		"invert_y": invert_y,
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
		"ai_difficulty": ai_difficulty,
		"player_name": player_name,
		"fullscreen": fullscreen,
		"slipper_highlight": slipper_highlight,
	}

func is_editing() -> bool:
	return _editing

func has_unsaved_changes() -> bool:
	if not _editing:
		return false
	return (_snapshot.get("bindings", {}) != _current_binding_map()
		or not is_equal_approx(float(_snapshot.get("mouse_sensitivity", 0.0)), mouse_sensitivity)
		or bool(_snapshot.get("invert_y", false)) != invert_y
		or not is_equal_approx(float(_snapshot.get("master_volume", 0.0)), master_volume)
		or not is_equal_approx(float(_snapshot.get("sfx_volume", 0.0)), sfx_volume)
		or not is_equal_approx(float(_snapshot.get("music_volume", 0.0)), music_volume)
		or int(_snapshot.get("ai_difficulty", 0)) != ai_difficulty
		or String(_snapshot.get("player_name", "")) != player_name
		or bool(_snapshot.get("fullscreen", DEFAULT_FULLSCREEN)) != fullscreen
		or int(_snapshot.get("slipper_highlight", DEFAULT_SLIPPER_HIGHLIGHT))
			!= slipper_highlight)

func commit_edit() -> void:
	_editing = false
	_snapshot.clear()
	_save()

func revert_edit() -> void:
	if not _editing:
		return
	var snapshot := _snapshot.duplicate(true)
	_editing = false
	_snapshot.clear()
	var bindings: Dictionary = snapshot.get("bindings", {})
	for action in bindings:
		_replace_key_binding(String(action), int(bindings[action]))
		binding_changed.emit(String(action))
	mouse_sensitivity = float(snapshot.get("mouse_sensitivity", mouse_sensitivity))
	invert_y = bool(snapshot.get("invert_y", invert_y))
	master_volume = float(snapshot.get("master_volume", master_volume))
	sfx_volume = float(snapshot.get("sfx_volume", sfx_volume))
	music_volume = float(snapshot.get("music_volume", music_volume))
	_apply_volumes()
	ai_difficulty = int(snapshot.get("ai_difficulty", ai_difficulty))
	_apply_ai_difficulty()
	fullscreen = bool(snapshot.get("fullscreen", fullscreen))
	_apply_fullscreen()
	set_slipper_highlight(int(snapshot.get("slipper_highlight", slipper_highlight)), false)
	var restored_name := String(snapshot.get("player_name", player_name))
	if restored_name != player_name:
		player_name = restored_name
		player_name_changed.emit(player_name)
	_save()

func _current_binding_map() -> Dictionary:
	var out: Dictionary = {}
	for action in REBINDABLE_ACTIONS:
		out[action] = _first_physical_keycode(action)
	return out

func _save() -> void:
	if _editing:
		return
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	for action in REBINDABLE_ACTIONS:
		config.set_value(SETTINGS_SECTION, action, _first_physical_keycode(action))
	config.set_value(SETTINGS_SECTION_CAMERA, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SETTINGS_SECTION_CAMERA, "invert_y", invert_y)
	config.set_value(SETTINGS_SECTION_AUDIO, "master_volume", master_volume)
	config.set_value(SETTINGS_SECTION_AUDIO, "sfx_volume", sfx_volume)
	config.set_value(SETTINGS_SECTION_AUDIO, "music_volume", music_volume)
	config.set_value(SETTINGS_SECTION_MATCH, "ai_difficulty", ai_difficulty)
	config.set_value(SETTINGS_SECTION_MATCH, "player_name", player_name)
	config.set_value(SETTINGS_SECTION_DISPLAY, "fullscreen", fullscreen)
	config.set_value(SETTINGS_SECTION_DISPLAY, "slipper_highlight", slipper_highlight)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsManager: failed to save %s (error %d)" % [SETTINGS_PATH, err])

const BINDINGS_VERSION: int = 3
const SETTINGS_SECTION_META: String = "meta"

const MOVED_BINDINGS: Dictionary = {
	"bump": 32,
	"guard_dash": 4194325,
}

func _migrate_bindings(config: ConfigFile) -> void:
	var version: int = int(config.get_value(SETTINGS_SECTION_META, "bindings_version", 1))
	if version >= BINDINGS_VERSION:
		return
	var dropped: Array[String] = []
	for action in MOVED_BINDINGS:
		var old_default: int = int(MOVED_BINDINGS[action])
		for key in [String(action), "%s_p1" % action]:
			if config.has_section_key(SETTINGS_SECTION, key) \
					and int(config.get_value(SETTINGS_SECTION, key)) == old_default:
				config.erase_section_key(SETTINGS_SECTION, key)
				dropped.append(key)
	config.set_value(SETTINGS_SECTION_META, "bindings_version", BINDINGS_VERSION)
	config.save(SETTINGS_PATH)
	if not dropped.is_empty():
		print("[Settings] bindings migrated to v%d — dropped stale %s, project defaults stand"
			% [BINDINGS_VERSION, ", ".join(dropped)])

func _load_and_apply() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		_apply_volumes()
		_apply_ai_difficulty()
		_apply_fullscreen()
		return
	_migrate_bindings(config)
	for action in REBINDABLE_ACTIONS:
		if config.has_section_key(SETTINGS_SECTION, action):
			var keycode: int = config.get_value(SETTINGS_SECTION, action)
			if keycode > 0:
				_replace_key_binding(action, keycode)
	if config.has_section_key(SETTINGS_SECTION_CAMERA, "mouse_sensitivity"):
		mouse_sensitivity = config.get_value(SETTINGS_SECTION_CAMERA, "mouse_sensitivity")
	if config.has_section_key(SETTINGS_SECTION_CAMERA, "invert_y"):
		invert_y = config.get_value(SETTINGS_SECTION_CAMERA, "invert_y")
	master_volume = config.get_value(SETTINGS_SECTION_AUDIO, "master_volume", DEFAULT_VOLUME)
	sfx_volume = config.get_value(SETTINGS_SECTION_AUDIO, "sfx_volume", DEFAULT_VOLUME)
	music_volume = config.get_value(SETTINGS_SECTION_AUDIO, "music_volume", DEFAULT_VOLUME)
	_apply_volumes()
	set_ai_difficulty(int(config.get_value(SETTINGS_SECTION_MATCH, "ai_difficulty",
		DEFAULT_DIFFICULTY)), false)
	set_player_name(String(config.get_value(SETTINGS_SECTION_MATCH, "player_name",
		DEFAULT_PLAYER_NAME)), false)
	set_fullscreen(bool(config.get_value(SETTINGS_SECTION_DISPLAY, "fullscreen",
		DEFAULT_FULLSCREEN)), false)
	set_slipper_highlight(int(config.get_value(SETTINGS_SECTION_DISPLAY, "slipper_highlight",
		DEFAULT_SLIPPER_HIGHLIGHT)), false)

