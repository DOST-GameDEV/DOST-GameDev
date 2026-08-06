extends Control
class_name SettingsPanel


signal back_pressed

const ACTION_LABEL_WIDTH: float = 260.0
const BINDING_CONTROL_SIZE: Vector2 = Vector2(170, 46)

@onready var bindings_list: VBoxContainer = %BindingsList
@onready var status_label: Label = %SettingsStatusLabel
@onready var reset_all_button: Button = %ResetAllButton
@onready var back_button: Button = %BackButton
@onready var apply_button: Button = %ApplyButton
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_value_label: Label = %SensitivityValueLabel
@onready var invert_y_check: CheckBox = %InvertYCheck
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var slipper_highlight_picker: OptionButton = %SlipperHighlightPicker
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var master_volume_value_label: Label = %MasterVolumeValueLabel
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var sfx_volume_value_label: Label = %SfxVolumeValueLabel
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var music_volume_value_label: Label = %MusicVolumeValueLabel

var _action_buttons: Dictionary = {}
var _listening_action: String = ""

func _ready() -> void:
	_build_rows()
	reset_all_button.pressed.connect(_on_reset_all_pressed)
	back_button.pressed.connect(_on_back_pressed)
	apply_button.pressed.connect(_on_apply_pressed)
	SettingsManager.begin_edit()
	SettingsManager.binding_changed.connect(_on_binding_changed)
	sensitivity_slider.value = SettingsManager.mouse_sensitivity
	sensitivity_value_label.text = "%.1fx" % SettingsManager.mouse_sensitivity
	invert_y_check.button_pressed = SettingsManager.invert_y
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	invert_y_check.toggled.connect(_on_invert_y_toggled)
	fullscreen_check.button_pressed = SettingsManager.fullscreen
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	SettingsManager.fullscreen_changed.connect(_on_settings_fullscreen_changed)
	_init_slipper_highlight_row()
	_init_volume_rows()
	_build_name_row()

func _init_slipper_highlight_row() -> void:
	slipper_highlight_picker.clear()
	for index in SettingsManagerScript.SLIPPER_HIGHLIGHTS.size():
		var choice: Dictionary = SettingsManagerScript.SLIPPER_HIGHLIGHTS[index]
		slipper_highlight_picker.add_item(String(choice["label"]), index)
		if index != SettingsManagerScript.HIGHLIGHT_OFF:
			slipper_highlight_picker.set_item_icon(index, _colour_swatch(choice["color"]))
	slipper_highlight_picker.select(clampi(SettingsManager.slipper_highlight, 0,
		SettingsManagerScript.SLIPPER_HIGHLIGHTS.size() - 1))
	slipper_highlight_picker.item_selected.connect(_on_slipper_highlight_selected)
	SettingsManager.slipper_highlight_changed.connect(_on_settings_slipper_highlight_changed)

func _on_settings_slipper_highlight_changed() -> void:
	slipper_highlight_picker.select(clampi(SettingsManager.slipper_highlight, 0,
		SettingsManagerScript.SLIPPER_HIGHLIGHTS.size() - 1))

const SWATCH_SIZE: int = 24

func _colour_swatch(colour: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, colour)
	gradient.set_color(1, colour)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = SWATCH_SIZE
	texture.height = SWATCH_SIZE
	return texture

func _on_slipper_highlight_selected(index: int) -> void:
	SettingsManager.set_slipper_highlight(index)
	AudioManager.play("ui_click")
	_refresh_apply_state()

func _build_name_row() -> void:
	var field := get_node_or_null("%PlayerNameField") as LineEdit
	if field == null:
		push_error("SettingsPanel: PlayerNameField missing from SettingsPanel.tscn")
		return
	field.text = SettingsManager.player_name
	field.max_length = SettingsManagerScript.PLAYER_NAME_MAX
	field.custom_minimum_size = BINDING_CONTROL_SIZE
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := get_node_or_null("%PlayerNameRow") as HBoxContainer
	var name_label := name_row.get_node_or_null("PlayerNameLabel") as Label if name_row != null else null
	if name_label != null:
		name_label.custom_minimum_size = Vector2(ACTION_LABEL_WIDTH, 0)
	if name_row != null:
		name_row.remove_theme_constant_override("separation")
	if not field.text_submitted.is_connected(_on_player_name_submitted):
		field.text_submitted.connect(_on_player_name_submitted)
		field.focus_exited.connect(func() -> void: _on_player_name_submitted(field.text))
		field.text_changed.connect(_on_player_name_typed)

func _on_player_name_typed(value: String) -> void:
	SettingsManager.set_player_name(value)
	_refresh_apply_state()

func _on_player_name_submitted(value: String) -> void:
	SettingsManager.set_player_name(value)
	AudioManager.play("ui_click")
	_refresh_apply_state()
	_push_name_to_live_character()

func _push_name_to_live_character() -> void:
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who != null and who.is_multiplayer_authority() and not who.is_ai_driven():
			who.player_name = SettingsManager.player_name

func _on_sensitivity_changed(value: float) -> void:
	SettingsManager.set_mouse_sensitivity(value)
	sensitivity_value_label.text = "%.1fx" % value
	_refresh_apply_state()

func _on_invert_y_toggled(value: bool) -> void:
	SettingsManager.set_invert_y(value)
	_refresh_apply_state()

func _on_fullscreen_toggled(value: bool) -> void:
	SettingsManager.set_fullscreen(value)
	_refresh_apply_state()

func _on_settings_fullscreen_changed(value: bool) -> void:
	fullscreen_check.set_pressed_no_signal(value)
	_refresh_apply_state()

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

func _on_volume_changed(value: float, label: Label, setter: Callable) -> void:
	setter.call(value)
	label.text = _volume_text(value)
	if setter != Callable(SettingsManager, "set_music_volume"):
		AudioManager.play("ui_click")
	_refresh_apply_state()

func _volume_text(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)

func _build_rows() -> void:
	for child in bindings_list.get_children():
		if child.name == "PlayerNameRow":
			continue
		child.queue_free()
	_action_buttons.clear()
	for action in SettingsManager.REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = SettingsManager.ACTION_LABELS.get(action, action)
		label.custom_minimum_size = Vector2(ACTION_LABEL_WIDTH, 0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.theme_type_variation = &"MenuBody"
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = BINDING_CONTROL_SIZE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key_event := event as InputEventKey
	if _listening_action == "":
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
		var conflict_with := SettingsManager.rebind_action(_listening_action, key_event.physical_keycode)
		if conflict_with != "":
			_action_buttons[_listening_action].text = SettingsManager.get_binding_display_name(_listening_action)
			status_label.text = "That key is already \"%s\". Choose a different key." % conflict_with
			AudioManager.play("ui_error")
		else:
			status_label.text = "\"%s\" rebound." % SettingsManager.ACTION_LABELS.get(_listening_action, _listening_action)
			_listening_action = ""
			AudioManager.play("ui_click")
	get_viewport().set_input_as_handled()

func _on_binding_changed(action: String) -> void:
	if _action_buttons.has(action):
		_action_buttons[action].text = SettingsManager.get_binding_display_name(action)
	_refresh_apply_state()

func _on_reset_all_pressed() -> void:
	AudioManager.play("ui_click")
	SettingsManager.reset_all_to_default()
	status_label.text = "All controls reset — press APPLY CHANGES to keep it."
	_refresh_apply_state()


var _back_armed: bool = false

func _on_apply_pressed() -> void:
	AudioManager.play("ui_click")
	_push_name_to_live_character()
	SettingsManager.commit_edit()
	SettingsManager.begin_edit()
	_back_armed = false
	status_label.text = "Settings saved."
	_refresh_apply_state()

func _on_back_pressed() -> void:
	if SettingsManager.has_unsaved_changes() and not _back_armed:
		_back_armed = true
		AudioManager.play("ui_error")
		back_button.text = "◀  DISCARD & GO BACK"
		status_label.text = "You have unsaved changes. Press BACK again to discard them."
		_refresh_apply_state()
		return
	AudioManager.play("ui_back")
	SettingsManager.revert_edit()
	_back_armed = false
	back_button.text = "◀  BACK"
	status_label.text = ""
	back_pressed.emit()

func _refresh_apply_state() -> void:
	if apply_button == null or not is_instance_valid(apply_button):
		return
	var dirty := SettingsManager.has_unsaved_changes()
	apply_button.disabled = not dirty
	if not dirty and _back_armed:
		_back_armed = false
		back_button.text = "◀  BACK"

