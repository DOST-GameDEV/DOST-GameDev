extends Node
class_name SettingsManagerScript
## Registered as the "SettingsManager" autoload singleton (Project Settings > Autoload).
## Referenced globally as `SettingsManager`, e.g. `SettingsManager.rebind_action(...)`.

## Lets players rebind and persist the local keyboard controls — P1 only,
## since Checklist 5.5: the human plays exactly one unit in Single Player and
## real AI (ai_controller.gd) drives the other three via
## Input.action_press()/action_release(), which needs no key bound at all.
## P2/p3/p4 are intentionally excluded from what a PLAYER can see or rebind —
## P2 still exists in project.godot [input] and still works as a debug-only
## dual-control affordance for `debug_player_switcher.gd` (a developer poking
## at it in the editor), but exposing a rebind UI for a key set no shipped
## player ever touches is dead weight in the Settings panel. p3/p4 were never
## real controls (the unbound local-test dummy slots — see character_base.gd
## `player_id` doc) and were never in this list either.
##
## Settings persist to user://settings.cfg via ConfigFile, one INI-style
## section ("input") with one key per rebindable action holding its physical
## keycode. Defaults are captured from project.godot's own InputMap on first
## _ready() (before anything is ever loaded/overwritten), so "Reset to
## Default" always has something real to fall back to, and doesn't need a
## duplicate hardcoded list of the original keys.

signal binding_changed(action: String)

const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "input"

## Ordered for display purposes — the Settings panel iterates this directly.
## P1 only — see this file's class doc for why P2 was removed 2026-07-28.
const REBINDABLE_ACTIONS: Array[String] = [
	"move_left_p1", "move_right_p1", "move_up_p1", "move_down_p1",
	"bump_p1", "guard_dash_p1", "special_ability_p1", "jump_p1",
]

## Human-readable labels for the panel — action string -> display text.
const ACTION_LABELS: Dictionary = {
	"move_left_p1": "Move Left", "move_right_p1": "Move Right",
	"move_up_p1": "Move Up", "move_down_p1": "Move Down",
	"bump_p1": "Bump", "guard_dash_p1": "Guard/Dash",
	"special_ability_p1": "Special Ability", "jump_p1": "Jump",
}

## action -> physical_keycode captured from the project's InputMap defaults,
## before any user override is ever applied. See _capture_defaults().
var _default_keycodes: Dictionary = {}

const SETTINGS_SECTION_CAMERA: String = "camera"
## Item 14: multiplier on CameraRig.BASE_SENSITIVITY — kept as a plain
## multiplier rather than an absolute degrees-per-pixel value here so the
## slider range (0.2x - 3.0x) reads the same regardless of whatever the rig's
## own base feels right at.
var mouse_sensitivity: float = 1.0
var invert_y: bool = false

## Checklist 4.1 — the three audio buses (Master / SFX / Music, see
## default_bus_layout.tres), 0..1 linear, persisted alongside everything else in
## the same user://settings.cfg.
##
## THE VALUES LIVE HERE; WHAT THEY MEAN TO THE MIXER LIVES IN AudioManager.
## This file knows how to store and reload a number; it deliberately never
## touches AudioServer itself. That split is why the volume model (a fourth bus,
## a limiter on Master) can change without a settings-file migration.
##
## Defaults are 0.8 rather than 1.0. A party game is played on laptop speakers
## with three other people shouting, and shipping at unity leaves a player who
## finds it too loud with only one direction to go — quieter is recoverable,
## clipping is not.
const SETTINGS_SECTION_AUDIO: String = "audio"
const DEFAULT_VOLUME: float = 0.8

var master_volume: float = DEFAULT_VOLUME
var sfx_volume: float = DEFAULT_VOLUME
var music_volume: float = DEFAULT_VOLUME

func _ready() -> void:
	_capture_defaults()
	_load_and_apply()

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = value
	_save()

func set_invert_y(value: bool) -> void:
	invert_y = value
	_save()

## 4.1. One setter per bus rather than one three-argument call, because the
## Settings panel's sliders move one at a time and each has to persist on its
## own. All three funnel into the same _apply_volumes(), so a bus can never be
## saved at a level it is not actually playing at.
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

## ⚠️ AudioManager IS LISTED BEFORE SettingsManager IN project.godot's [autoload]
## BLOCK, AND THAT ORDER IS LOAD-BEARING. Autoloads enter the tree in the order
## they are declared, so AudioManager's own _ready() — which is what creates the
## voice pool and resolves the bus indices — has already run by the time this
## file's _ready() reaches _load_and_apply() below. Move SettingsManager above it
## and the saved volumes are applied to a manager that has not built itself yet.
func _apply_volumes() -> void:
	AudioManager.apply_volumes(master_volume, sfx_volume, music_volume)

## Snapshots each rebindable action's current (project-default) key so
## reset_action_to_default() has something to restore without hardcoding a
## second copy of project.godot's key list here.
func _capture_defaults() -> void:
	for action in REBINDABLE_ACTIONS:
		_default_keycodes[action] = _first_physical_keycode(action)

## Returns the physical keycode currently bound to `action`, or -1 if it has
## no key event bound (shouldn't normally happen for p1/p2 actions, but keeps
## this safe to call before defaults are captured too).
func _first_physical_keycode(action: String) -> int:
	if not InputMap.has_action(action):
		return -1
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).physical_keycode
	return -1

## Human-readable name of whatever key is currently bound to `action`
## (e.g. "W", "Space", "Enter") — for display in the Settings panel.
func get_binding_display_name(action: String) -> String:
	var keycode := _first_physical_keycode(action)
	if keycode <= 0:
		return "—"
	return OS.get_keycode_string(keycode)

## B-22: rebinding used to silently allow two actions to share a physical key
## (e.g. P2 Up rebound onto P1's own W), with no warning — both would fire
## together from then on. Returns "" on success, or the display label of
## whichever OTHER action already owns that key, so the caller (Settings
## panel) can show a clear conflict message instead of silently double-binding it.
func rebind_action(action: String, physical_keycode: int) -> String:
	if not InputMap.has_action(action):
		return ""
	var conflict := _find_conflicting_action(action, physical_keycode)
	if conflict != "":
		return ACTION_LABELS.get(conflict, conflict)
	_set_binding(action, physical_keycode)
	return ""

## Whichever OTHER rebindable action already holds `physical_keycode`, or ""
## if none do. Excludes `action` itself — rebinding a key to what it already is
## isn't a conflict.
func _find_conflicting_action(action: String, physical_keycode: int) -> String:
	for other_action in REBINDABLE_ACTIONS:
		if other_action != action and _first_physical_keycode(other_action) == physical_keycode:
			return other_action
	return ""

func _set_binding(action: String, physical_keycode: int) -> void:
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, event)
	binding_changed.emit(action)
	_save()

## Bypasses the conflict check above — resetting to a known-good default has
## to always succeed, even mid-way through reset_all_to_default() where an
## action not yet reset might still be sitting on a key that collides with
## another action's default (that's the exact conflict being cleaned up).
func reset_action_to_default(action: String) -> void:
	if not _default_keycodes.has(action):
		return
	_set_binding(action, _default_keycodes[action])

func reset_all_to_default() -> void:
	for action in REBINDABLE_ACTIONS:
		reset_action_to_default(action)

func _save() -> void:
	var config := ConfigFile.new()
	# Load first so we don't clobber other sections/keys some later feature
	# might add to the same file.
	config.load(SETTINGS_PATH)
	for action in REBINDABLE_ACTIONS:
		config.set_value(SETTINGS_SECTION, action, _first_physical_keycode(action))
	config.set_value(SETTINGS_SECTION_CAMERA, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SETTINGS_SECTION_CAMERA, "invert_y", invert_y)
	config.set_value(SETTINGS_SECTION_AUDIO, "master_volume", master_volume)
	config.set_value(SETTINGS_SECTION_AUDIO, "sfx_volume", sfx_volume)
	config.set_value(SETTINGS_SECTION_AUDIO, "music_volume", music_volume)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsManager: failed to save %s (error %d)" % [SETTINGS_PATH, err])

func _load_and_apply() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		# No saved settings yet — project.godot/coded defaults stand as-is.
		# ⚠️ EXCEPT the volumes, which still have to be PUSHED to the buses.
		# The bus layout ships at 0 dB (unity) and DEFAULT_VOLUME is 0.8, so
		# returning here without applying would leave a first-time player on a
		# mix 2 dB louder than every returning player's — the one case where
		# "no saved file" is not the same as "nothing to do".
		_apply_volumes()
		return
	for action in REBINDABLE_ACTIONS:
		if config.has_section_key(SETTINGS_SECTION, action):
			var keycode: int = config.get_value(SETTINGS_SECTION, action)
			if keycode > 0:
				InputMap.action_erase_events(action)
				var event := InputEventKey.new()
				event.physical_keycode = keycode
				InputMap.action_add_event(action, event)
	if config.has_section_key(SETTINGS_SECTION_CAMERA, "mouse_sensitivity"):
		mouse_sensitivity = config.get_value(SETTINGS_SECTION_CAMERA, "mouse_sensitivity")
	if config.has_section_key(SETTINGS_SECTION_CAMERA, "invert_y"):
		invert_y = config.get_value(SETTINGS_SECTION_CAMERA, "invert_y")
	master_volume = config.get_value(SETTINGS_SECTION_AUDIO, "master_volume", DEFAULT_VOLUME)
	sfx_volume = config.get_value(SETTINGS_SECTION_AUDIO, "sfx_volume", DEFAULT_VOLUME)
	music_volume = config.get_value(SETTINGS_SECTION_AUDIO, "music_volume", DEFAULT_VOLUME)
	_apply_volumes()
