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
@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var local_button: Button = %LocalButton
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var join_address_edit: LineEdit = %JoinAddressEdit
@onready var game_mode_option: OptionButton = %GameModeOption
@onready var status_label: Label = %StatusLabel
@onready var back_button: Button = %BackButton

func _ready() -> void:
	title_screen.visible = true
	play_menu.visible = false
	settings_panel.visible = false
	status_label.text = ""

	game_mode_option.clear()
	# B-33: Option A has been fully implemented since Session 7 (hitbox.gd's
	# dent branch, round_manager.gd's dent-based win check) — the "(coming
	# soon)" label was stale and both items were always selectable/playable
	# either way, so there was no actual gate to fix, just a wrong label.
	game_mode_option.add_item("Option B — Capture & Seal", GameLaunch.GameMode.OPTION_B)
	game_mode_option.add_item("Option A — Health / Dents", GameLaunch.GameMode.OPTION_A)
	game_mode_option.select(0)
	game_mode_option.item_selected.connect(_on_game_mode_selected)

	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_panel.back_pressed.connect(_on_settings_back_pressed)
	back_button.pressed.connect(_on_back_pressed)
	local_button.pressed.connect(_on_local_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

## B-34: Settings was reachable from TitleScreen but PlayMenu had no way back
## to it (or to TitleScreen at all) without restarting the game.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and play_menu.visible:
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _on_back_pressed() -> void:
	play_menu.visible = false
	title_screen.visible = true
	status_label.text = ""

func _on_start_pressed() -> void:
	title_screen.visible = false
	play_menu.visible = true

func _on_settings_pressed() -> void:
	title_screen.visible = false
	play_menu.visible = false
	settings_panel.visible = true

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	title_screen.visible = true

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
	# B-14: MatchManager/RoundManager are autoloads and survive scene changes —
	# without this, a second match (Rematch, or Menu then Play again) would
	# resume the first one's score/round number instead of starting at 0-0.
	MatchManager.reset()
	RoundManager.reset()
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
