extends Control
class_name MainMenu


const MODE_SELECT_PATH: String = "res://scenes/ui/ModeSelect.tscn"

const STAGGER: float = 0.09

@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var tutorial_panel: TutorialPanel = %TutorialPanel
@onready var credits_panel: CreditsPanel = %CreditsPanel
@onready var start_button: ArrowButton = %StartButton
@onready var settings_button: ArrowButton = %SettingsButton
@onready var tutorial_button: ArrowButton = %TutorialButton
@onready var quit_button: ArrowButton = %QuitButton
@onready var credits_button: Button = %CreditsButton

func _ready() -> void:
	settings_panel.visible = false
	tutorial_panel.visible = false
	credits_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameVersion.attach_to(self)

	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	settings_panel.back_pressed.connect(_on_settings_back_pressed)
	tutorial_panel.back_pressed.connect(_on_tutorial_back_pressed)
	credits_panel.back_pressed.connect(_on_credits_back_pressed)

	_unfurl()

func _unfurl() -> void:
	var buttons: Array[ArrowButton] = [start_button, settings_button, tutorial_button, quit_button]
	for i in buttons.size():
		buttons[i].animate_in(i * STAGGER)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(MODE_SELECT_PATH)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_tutorial_pressed() -> void:
	tutorial_panel.reset_to_first_page()
	tutorial_panel.visible = true

func _on_tutorial_back_pressed() -> void:
	tutorial_panel.visible = false
	_unfurl()

func _on_credits_pressed() -> void:
	credits_panel.visible = true

func _on_credits_back_pressed() -> void:
	credits_panel.visible = false
	_unfurl()

func _on_settings_pressed() -> void:
	settings_panel.visible = true

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	_unfurl()

