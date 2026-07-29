extends Control
class_name SettingsPanel

## Rebindable-controls UI, backed by the SettingsManager autoload (see
## scripts/systems/settings_manager.gd for persistence/apply logic — this
## script is purely the view). Kept as its own scene (instanced into
## MainMenu.tscn, see main_menu.gd) rather than nodes inlined directly into
## MainMenu.tscn: unique names (%NodeName) must be unique scene-wide, and
## MainMenu's PlayMenu already owns a "StatusLabel" — inlining a second one
## here would collide. As a separate instanced scene, this panel's unique
## names resolve within its own instance instead, so there's no collision no
## matter what MainMenu already contains.

signal back_pressed

## Rows are built at runtime, so their colour is set here rather than in the
## scene. See _build_rows for why it cannot be the theme's INK.
const ACTION_LABEL_COLOR: Color = Color(1, 1, 1)

@onready var bindings_list: VBoxContainer = %BindingsList
@onready var status_label: Label = %SettingsStatusLabel
@onready var reset_all_button: Button = %ResetAllButton
@onready var back_button: Button = %BackButton
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_value_label: Label = %SensitivityValueLabel
@onready var invert_y_check: CheckBox = %InvertYCheck
## 4.1 — one row per audio bus (see default_bus_layout.tres).
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var master_volume_value_label: Label = %MasterVolumeValueLabel
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var sfx_volume_value_label: Label = %SfxVolumeValueLabel
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var music_volume_value_label: Label = %MusicVolumeValueLabel

## action name -> the Button showing/capturing its key, so a rebind can
## refresh just that one row's label without rebuilding the whole list.
var _action_buttons: Dictionary = {}
## Action currently waiting for a keypress to rebind to, or "" if none.
var _listening_action: String = ""

func _ready() -> void:
	_build_rows()
	reset_all_button.pressed.connect(_on_reset_all_pressed)
	back_button.pressed.connect(_on_back_pressed)
	SettingsManager.binding_changed.connect(_on_binding_changed)
	# Item 14.
	sensitivity_slider.value = SettingsManager.mouse_sensitivity
	sensitivity_value_label.text = "%.1fx" % SettingsManager.mouse_sensitivity
	invert_y_check.button_pressed = SettingsManager.invert_y
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	invert_y_check.toggled.connect(SettingsManager.set_invert_y)
	_init_volume_rows()

func _on_sensitivity_changed(value: float) -> void:
	SettingsManager.set_mouse_sensitivity(value)
	sensitivity_value_label.text = "%.1fx" % value

## 4.1 — Master / SFX / Ambience.
##
## ⚠️ SET `value` BEFORE CONNECTING `value_changed`, NOT AFTER.
##
## Assigning to an HSlider's `value` emits value_changed synchronously. With the
## connection made first, seeding the three sliders from SettingsManager would
## immediately call straight back into SettingsManager.set_*_volume() and
## _save() — three ConfigFile writes on every single open of this panel, before
## the player has touched anything. The rebind rows above have never had this
## problem because they are Buttons; the sensitivity slider (item 14) already
## established this ordering and it is repeated here for the same reason.
func _init_volume_rows() -> void:
	var rows := [
		[master_volume_slider, master_volume_value_label, SettingsManager.master_volume,
			SettingsManager.set_master_volume],
		[sfx_volume_slider, sfx_volume_value_label, SettingsManager.sfx_volume,
			SettingsManager.set_sfx_volume],
		[music_volume_slider, music_volume_value_label, SettingsManager.music_volume,
			SettingsManager.set_music_volume],
	]
	for row in rows:
		var slider: HSlider = row[0]
		var label: Label = row[1]
		var setter: Callable = row[3]
		slider.value = row[2]
		label.text = _volume_text(row[2])
		slider.value_changed.connect(_on_volume_changed.bind(label, setter))

## Applies the new level to the bus (via SettingsManager -> AudioManager) and
## previews it, so dragging a slider is audible rather than a silent guess. The
## preview is the ordinary UI click, which is on the SFX bus — so it demonstrates
## Master and SFX honestly and is deliberately absent for Ambience, whose own bus
## it would not be routed through. AudioManager's retrigger guard is what keeps
## a fast drag from firing one click per pixel.
func _on_volume_changed(value: float, label: Label, setter: Callable) -> void:
	setter.call(value)
	label.text = _volume_text(value)
	if setter != Callable(SettingsManager, "set_music_volume"):
		AudioManager.play("ui_click")

func _volume_text(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)

func _build_rows() -> void:
	for child in bindings_list.get_children():
		child.queue_free()
	_action_buttons.clear()
	for action in SettingsManager.REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = SettingsManager.ACTION_LABELS.get(action, action)
		label.custom_minimum_size = Vector2(160, 0)
		# This panel has no card behind it — the rows sit straight on the menu's
		# dark navy, where the theme's INK body colour is unreadable. The rebind
		# buttons keep their own light stylebox and INK text.
		label.add_theme_color_override("font_color", ACTION_LABEL_COLOR)
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(140, 0)
		button.text = SettingsManager.get_binding_display_name(action)
		button.pressed.connect(_on_rebind_button_pressed.bind(action))
		row.add_child(button)
		_action_buttons[action] = button
		bindings_list.add_child(row)

func _on_rebind_button_pressed(action: String) -> void:
	AudioManager.play("ui_click")
	_listening_action = action
	status_label.text = "Press any key for \"%s\"… (Esc to cancel)" % SettingsManager.ACTION_LABELS.get(action, action)
	_action_buttons[action].text = "…"

func _unhandled_input(event: InputEvent) -> void:
	# ⚠️ VISIBILITY GUARD — DO NOT REMOVE. A hidden Control still receives
	# _unhandled_input in Godot; only _gui_input is gated by visibility.
	#
	# Without this line the HIDDEN settings panel swallowed every Esc press in
	# the match, called set_input_as_handled(), and emitted back_pressed —
	# which main.gd:231 has wired to `settings_panel.hide(); pause_root.show()`.
	# That shows the pause overlay but never sets Input.mouse_mode and never
	# sets get_tree().paused, because _on_pause_toggle_requested() was never
	# reached at all.
	#
	# Found by the first real playtest (0.4), reported as three separate bugs
	# that were all this one: "mouse disappears when I pause", "it doesn't
	# really pause, the game keeps playing", and "I can't return to menu because
	# no mouse — I have to alt-tab to get it back". match_result.gd:29 already
	# had this guard, which is what made the omission obvious once both were
	# read side by side.
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key_event := event as InputEventKey
	if _listening_action == "":
		# U-7: Esc exits the panel (back to pause menu or main menu, whoever
		# wired back_pressed). Handled even when not rebinding so every panel
		# in the game has a working Esc path (Dev_Plan.md §4.7 / Handoff.md U-7).
		if key_event.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_back_pressed()
		return
	if key_event.physical_keycode == KEY_ESCAPE:
		_action_buttons[_listening_action].text = SettingsManager.get_binding_display_name(_listening_action)
		status_label.text = "Rebind cancelled."
		_listening_action = ""
		AudioManager.play("ui_back")
	else:
		# B-22: rebind_action() now refuses (and reports) a key already used
		# by another action instead of silently double-binding it.
		var conflict_with := SettingsManager.rebind_action(_listening_action, key_event.physical_keycode)
		if conflict_with != "":
			_action_buttons[_listening_action].text = SettingsManager.get_binding_display_name(_listening_action)
			status_label.text = "That key is already \"%s\". Choose a different key." % conflict_with
			# 4.1: the conflict buzz. B-22 gave this case a clear message and
			# nothing else — a player looking at the keyboard rather than at the
			# status label got no signal at all that the press was refused.
			AudioManager.play("ui_error")
		else:
			status_label.text = "\"%s\" rebound." % SettingsManager.ACTION_LABELS.get(_listening_action, _listening_action)
			_listening_action = ""
			AudioManager.play("ui_click")
	get_viewport().set_input_as_handled()

## Refreshes whichever row's button just changed — covers both rebinds made
## through this panel and ones applied elsewhere (e.g. reset_all_to_default()).
func _on_binding_changed(action: String) -> void:
	if _action_buttons.has(action):
		_action_buttons[action].text = SettingsManager.get_binding_display_name(action)

func _on_reset_all_pressed() -> void:
	AudioManager.play("ui_click")
	SettingsManager.reset_all_to_default()
	status_label.text = "All controls reset to default."

func _on_back_pressed() -> void:
	AudioManager.play("ui_back")
	status_label.text = ""
	back_pressed.emit()
