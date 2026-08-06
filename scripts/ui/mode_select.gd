extends Control
class_name ModeSelectScreen


const MATCH_SETUP_PATH: String = "res://scenes/ui/MatchSetup.tscn"
const MULTIPLAYER_SETUP_PATH: String = "res://scenes/ui/MultiplayerSetup.tscn"
const MAIN_MENU_PATH: String = "res://scenes/ui/MainMenu.tscn"

const STAGGER: float = 0.09

@onready var solo_button: ArrowButton = %SoloButton
@onready var multi_button: ArrowButton = %MultiButton
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	status_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameVersion.attach_to(self)

	solo_button.pressed.connect(_on_solo_pressed)
	multi_button.pressed.connect(_on_multi_pressed)
	back_button.pressed.connect(_on_back_pressed)
	back_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))

	if GameLaunch.pending_status_message != "":
		status_label.text = GameLaunch.pending_status_message
		GameLaunch.pending_status_message = ""

	var buttons: Array[ArrowButton] = [solo_button, multi_button]
	for i in buttons.size():
		buttons[i].animate_in(i * STAGGER)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()

func _begin_session(action: String) -> void:
	GameLaunch.pending_action = action
	GameLaunch.clear_seating()
	MatchManager.reset()
	RoundManager.reset()

func _on_solo_pressed() -> void:
	_begin_session("local")
	get_tree().change_scene_to_file(MATCH_SETUP_PATH)

func _on_multi_pressed() -> void:
	GameLaunch.pending_action = ""
	GameLaunch.clear_seating()
	MatchManager.reset()
	RoundManager.reset()
	get_tree().change_scene_to_file(MULTIPLAYER_SETUP_PATH)

func _on_back_pressed() -> void:
	AudioManager.play("ui_back")
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

