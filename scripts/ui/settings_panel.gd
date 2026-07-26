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

@onready var bindings_list: VBoxContainer = %BindingsList
@onready var status_label: Label = %SettingsStatusLabel
@onready var reset_all_button: Button = %ResetAllButton
@onready var back_button: Button = %BackButton
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_value_label: Label = %SensitivityValueLabel
@onready var invert_y_check: CheckBox = %InvertYCheck

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

func _on_sensitivity_changed(value: float) -> void:
	SettingsManager.set_mouse_sensitivity(value)
	sensitivity_value_label.text = "%.1fx" % value

func _build_rows() -> void:
	for child in bindings_list.get_children():
		child.queue_free()
	_action_buttons.clear()
	for action in SettingsManager.REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = SettingsManager.ACTION_LABELS.get(action, action)
		label.custom_minimum_size = Vector2(160, 0)
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(140, 0)
		button.text = SettingsManager.get_binding_display_name(action)
		button.pressed.connect(_on_rebind_button_pressed.bind(action))
		row.add_child(button)
		_action_buttons[action] = button
		bindings_list.add_child(row)

func _on_rebind_button_pressed(action: String) -> void:
	_listening_action = action
	status_label.text = "Press any key for \"%s\"… (Esc to cancel)" % SettingsManager.ACTION_LABELS.get(action, action)
	_action_buttons[action].text = "…"

func _unhandled_input(event: InputEvent) -> void:
	if _listening_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.physical_keycode == KEY_ESCAPE:
			_action_buttons[_listening_action].text = SettingsManager.get_binding_display_name(_listening_action)
			status_label.text = "Rebind cancelled."
			_listening_action = ""
		else:
			# B-22: rebind_action() now refuses (and reports) a key already used
			# by another action instead of silently double-binding it.
			var conflict_with := SettingsManager.rebind_action(_listening_action, key_event.physical_keycode)
			if conflict_with != "":
				_action_buttons[_listening_action].text = SettingsManager.get_binding_display_name(_listening_action)
				status_label.text = "That key is already \"%s\". Choose a different key." % conflict_with
			else:
				status_label.text = "\"%s\" rebound." % SettingsManager.ACTION_LABELS.get(_listening_action, _listening_action)
				_listening_action = ""
		get_viewport().set_input_as_handled()

## Refreshes whichever row's button just changed — covers both rebinds made
## through this panel and ones applied elsewhere (e.g. reset_all_to_default()).
func _on_binding_changed(action: String) -> void:
	if _action_buttons.has(action):
		_action_buttons[action].text = SettingsManager.get_binding_display_name(action)

func _on_reset_all_pressed() -> void:
	SettingsManager.reset_all_to_default()
	status_label.text = "All controls reset to default."

func _on_back_pressed() -> void:
	status_label.text = ""
	back_pressed.emit()
