extends Control
class_name MainMenu

## Session 6: the game's actual entry point now (see project.godot
## run/main_scene). Two panels in one Control, swapped via visibility:
## - TitleScreen: name of the game + a single "Start" button.
## - PlayMenu: Local / Host / Join (with an address field) + a game-mode
##   picker (see game_launch.gd). Picking Host or Join hands off to
##   Main.tscn via GameLaunch, exactly like the existing `--host` /
##   `--join=<ip>` command-line flow main.gd already understands.

const MAIN_SCENE_PATH: String = "res://scenes/main/Main.tscn"

@onready var title_screen: Control = %TitleScreen
@onready var play_menu: Control = %PlayMenu
@onready var start_button: Button = %StartButton
@onready var local_button: Button = %LocalButton
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var join_address_edit: LineEdit = %JoinAddressEdit
@onready var game_mode_option: OptionButton = %GameModeOption
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	title_screen.visible = true
	play_menu.visible = false
	status_label.text = ""

	game_mode_option.clear()
	game_mode_option.add_item("Option B — Capture & Seal", GameLaunch.GameMode.OPTION_B)
	game_mode_option.add_item("Option A — Health / Dents (coming soon)", GameLaunch.GameMode.OPTION_A)
	game_mode_option.select(0)
	game_mode_option.item_selected.connect(_on_game_mode_selected)

	start_button.pressed.connect(_on_start_pressed)
	local_button.pressed.connect(_on_local_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

func _on_start_pressed() -> void:
	title_screen.visible = false
	play_menu.visible = true

func _on_game_mode_selected(_index: int) -> void:
	GameLaunch.game_mode = game_mode_option.get_selected_id() as GameLaunch.GameMode

func _on_local_pressed() -> void:
	GameLaunch.pending_action = "local"
	_go_to_match()

func _on_host_pressed() -> void:
	GameLaunch.pending_action = "host"
	_go_to_match()

func _on_join_pressed() -> void:
	var address := join_address_edit.text.strip_edges()
	if address.is_empty():
		status_label.text = "Enter a host address first (e.g. 127.0.0.1)."
		return
	GameLaunch.pending_action = "join"
	GameLaunch.pending_join_address = address
	_go_to_match()

func _go_to_match() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
