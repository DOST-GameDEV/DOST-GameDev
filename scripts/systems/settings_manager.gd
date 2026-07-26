extends Node
class_name SettingsManagerScript
## Registered as the "SettingsManager" autoload singleton (Project Settings > Autoload).
## Referenced globally as `SettingsManager`, e.g. `SettingsManager.rebind_action(...)`.

## Lets players rebind and persist the local keyboard controls (P1/P2 — see
## project.godot [input]). p3/p4 are intentionally excluded: those are the
## unbound local-test dummy slots (see character_base.gd `player_id` doc),
## not real player controls, so there's nothing sensible to rebind there.
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
const REBINDABLE_ACTIONS: Array[String] = [
	"move_left_p1", "move_right_p1", "move_up_p1", "move_down_p1",
	"bump_p1", "guard_dash_p1", "special_ability_p1",
	"move_left_p2", "move_right_p2", "move_up_p2", "move_down_p2",
	"bump_p2", "guard_dash_p2", "special_ability_p2",
]

## Human-readable labels for the panel — action string -> display text.
const ACTION_LABELS: Dictionary = {
	"move_left_p1": "P1 Move Left", "move_right_p1": "P1 Move Right",
	"move_up_p1": "P1 Move Up", "move_down_p1": "P1 Move Down",
	"bump_p1": "P1 Bump", "guard_dash_p1": "P1 Guard/Dash",
	"special_ability_p1": "P1 Special Ability",
	"move_left_p2": "P2 Move Left", "move_right_p2": "P2 Move Right",
	"move_up_p2": "P2 Move Up", "move_down_p2": "P2 Move Down",
	"bump_p2": "P2 Bump", "guard_dash_p2": "P2 Guard/Dash",
	"special_ability_p2": "P2 Special Ability",
}

## action -> physical_keycode captured from the project's InputMap defaults,
## before any user override is ever applied. See _capture_defaults().
var _default_keycodes: Dictionary = {}

func _ready() -> void:
	_capture_defaults()
	_load_and_apply()

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

## Rebinds `action` to a single physical key, replacing whatever was there
## before (each rebindable action only ever has one key at a time — simpler
## for a keyboard-split local prototype than stacking multiple bindings).
## Saves immediately so a rebind survives even if the game crashes right after.
func rebind_action(action: String, physical_keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, event)
	binding_changed.emit(action)
	_save()

func reset_action_to_default(action: String) -> void:
	if not _default_keycodes.has(action):
		return
	rebind_action(action, _default_keycodes[action])

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
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsManager: failed to save %s (error %d)" % [SETTINGS_PATH, err])

func _load_and_apply() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return # no saved settings yet — project.godot defaults stand as-is
	for action in REBINDABLE_ACTIONS:
		if config.has_section_key(SETTINGS_SECTION, action):
			var keycode: int = config.get_value(SETTINGS_SECTION, action)
			if keycode > 0:
				InputMap.action_erase_events(action)
				var event := InputEventKey.new()
				event.physical_keycode = keycode
				InputMap.action_add_event(action, event)
