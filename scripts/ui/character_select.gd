extends Control
class_name CharacterSelect



signal closed


const STAGGER: float = 0.09

@onready var preview: CharacterPreview = %CharacterPreview
@onready var prev_button: TextureButton = %CharPrevButton
@onready var next_button: TextureButton = %CharNextButton
@onready var name_label: Label = %CharValueLabel
@onready var tagline_label: Label = %TaglineLabel
@onready var confirm_button: ArrowButton = %ConfirmButton
@onready var back_button: Button = %BackButton
@onready var tab_bar: HBoxContainer = %TabBar
@onready var trait_rows: VBoxContainer = %TraitRows

const TRAIT_SLOTS: int = 5
const TRAIT_PIP_SIZE: Vector2 = Vector2(42, 12)
const TRAIT_PIP_GAP: int = 6
const TRAIT_PIP_FILLED: Color = Color(0.973, 0.816, 0.157)
const TRAIT_PIP_EMPTY: Color = Color(0.961, 0.902, 0.784, 0.20)

func _refresh_traits(entry: Dictionary, category_index: int) -> void:
	for child in trait_rows.get_children():
		child.queue_free()
	var traits: Dictionary = entry.get("traits", {})
	for label in CharacterRoster.trait_labels(category_index):
		trait_rows.add_child(_build_trait_row(label, traits))
	var hint := Label.new()
	hint.text = "Drag to turn the view  ·  scroll to zoom  ·  right-click to reset"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.961, 0.902, 0.784, 0.5))
	trait_rows.add_child(hint)

func _build_trait_row(label: Dictionary, traits: Dictionary) -> HBoxContainer:
	var key: StringName = label["key"]
	var points: int = CharacterRoster._trait_value(traits, key)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var name_label := Label.new()
	name_label.text = String(label["name"])
	name_label.custom_minimum_size = Vector2(126, 0)
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_color_override("font_color", TRAIT_PIP_FILLED)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", TRAIT_PIP_GAP)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in range(TRAIT_SLOTS):
		var pip := ColorRect.new()
		pip.custom_minimum_size = TRAIT_PIP_SIZE
		pip.color = TRAIT_PIP_FILLED if i < points else TRAIT_PIP_EMPTY
		pips.add_child(pip)
	row.add_child(pips)

	var gloss_text := String(label.get("gloss", ""))
	if gloss_text == "":
		return row
	var gloss := Label.new()
	gloss.text = gloss_text
	gloss.add_theme_font_size_override("font_size", 18)
	gloss.add_theme_color_override("font_color", Color(0.961, 0.902, 0.784, 0.55))
	gloss.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gloss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gloss)
	return row

var _tab: int = 0
var _indices: Array[int] = [0, 0, 0]
var _tab_buttons: Array[Button] = []

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameVersion.attach_to(self)

	_indices = [GameLaunch.character_index(), GameLaunch.can_index(),
		GameLaunch.slipper_index()]

	_build_tabs()
	_apply()

	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)
	for button in [prev_button, next_button, confirm_button, back_button]:
		button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))

	confirm_button.animate_in(STAGGER)

func _build_tabs() -> void:
	for i in range(CharacterRoster.CATEGORIES.size()):
		var button := Button.new()
		button.text = String(CharacterRoster.category(i)["label"])
		button.theme_type_variation = &"WoodButton"
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_tab_pressed.bind(i))
		button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
		tab_bar.add_child(button)
		_tab_buttons.append(button)
	_refresh_tab_buttons()

func _refresh_tab_buttons() -> void:
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].disabled = (i == _tab)

func _on_tab_pressed(index: int) -> void:
	if index == _tab:
		return
	AudioManager.play("ui_click")
	_tab = index
	_refresh_tab_buttons()
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
		return
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_on_prev_pressed()
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_on_next_pressed()
	elif event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_on_tab_pressed(posmod(_tab - 1, CharacterRoster.CATEGORIES.size()))
	elif event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_on_tab_pressed(posmod(_tab + 1, CharacterRoster.CATEGORIES.size()))

func _entries() -> Array:
	return CharacterRoster.entries_for(_tab)

func _on_prev_pressed() -> void:
	var count := _entries().size()
	if count <= 1:
		return
	AudioManager.play("ui_click")
	_indices[_tab] = posmod(_indices[_tab] - 1, count)
	_apply()

func _on_next_pressed() -> void:
	var count := _entries().size()
	if count <= 1:
		return
	AudioManager.play("ui_click")
	_indices[_tab] = posmod(_indices[_tab] + 1, count)
	_apply()

func _apply() -> void:
	var entries := _entries()
	if entries.is_empty():
		return
	var index: int = posmod(_indices[_tab], entries.size())
	_indices[_tab] = index
	var entry: Dictionary = entries[index]

	name_label.text = String(entry["name"])
	var detail := String(entry["tagline"])
	if String(CharacterRoster.category(_tab)["slot"]) == "slipper":
		var launch := CharacterRoster.slipper_launch_speed(index)
		if launch > 0.0:
			detail += "\nLAUNCH  %.1f m/s" % launch
	tagline_label.text = detail
	_refresh_traits(entry, _tab)

	var many := entries.size() > 1
	prev_button.disabled = not many
	next_button.disabled = not many

	match String(CharacterRoster.category(_tab)["slot"]):
		"character":
			GameLaunch.selected_character = entry["id"]
			preview.show_character(entry)
		"can":
			GameLaunch.selected_can = entry["id"]
			preview.show_prop(entry, true)
		"slipper":
			GameLaunch.selected_slipper = entry["id"]
			preview.show_prop(entry, false)

func _on_back_pressed() -> void:
	AudioManager.play("ui_back")
	closed.emit()

func _on_confirm_pressed() -> void:
	AudioManager.play("ui_click")
	closed.emit()

