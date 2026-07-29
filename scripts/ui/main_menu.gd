extends Control
class_name MainMenu

## The title screen: the TUMP logo, the backdrop plate and the four pennant
## buttons. No longer the game's literal entry point — `SplashScreen.tscn` is
## `run/main_scene` now and hands off to this once the opening sting has played.
##
## PLAY hands off to GameSetup.tscn, which owns map/mode selection and the
## offline/host/join launch. The two used to share this scene; they share no
## nodes and only ever hand off to each other, so they are separate scenes.

const GAME_SETUP_PATH: String = "res://scenes/ui/GameSetup.tscn"

## Stagger between consecutive pennants unfurling.
const STAGGER: float = 0.09

@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var tutorial_panel: TutorialPanel = %TutorialPanel
@onready var start_button: ArrowButton = %StartButton
@onready var settings_button: ArrowButton = %SettingsButton
@onready var tutorial_button: ArrowButton = %TutorialButton
@onready var quit_button: ArrowButton = %QuitButton

func _ready() -> void:
	settings_panel.visible = false
	tutorial_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Main.tscn captures it for a match
	GameVersion.attach_to(self)

	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_panel.back_pressed.connect(_on_settings_back_pressed)
	tutorial_panel.back_pressed.connect(_on_tutorial_back_pressed)

	_unfurl()

func _unfurl() -> void:
	var buttons: Array[ArrowButton] = [start_button, settings_button, tutorial_button, quit_button]
	for i in buttons.size():
		buttons[i].animate_in(i * STAGGER)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SETUP_PATH)

## Title-screen-only, deliberately. A mid-match quit that skips
## NetworkManager.disconnect_network() would strand the other peers — the same
## soft-lock Q-1 fixed, just from the other end. Return to Menu → Quit is two
## clear steps instead.
func _on_quit_pressed() -> void:
	get_tree().quit()

## Shown in place rather than switched to, same as SETTINGS — a scene change
## would tear down and rebuild the title screen behind a panel the player is
## about to close.
func _on_tutorial_pressed() -> void:
	tutorial_panel.reset_to_first_page()
	tutorial_panel.visible = true

func _on_tutorial_back_pressed() -> void:
	tutorial_panel.visible = false
	_unfurl()

func _on_settings_pressed() -> void:
	settings_panel.visible = true

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	_unfurl()
