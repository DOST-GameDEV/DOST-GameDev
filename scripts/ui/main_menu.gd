extends Control
class_name MainMenu

## The game's entry point (see project.godot run/main_scene). Two screens in one
## Control, swapped via visibility:
## - TitleScreen: the TUMP logo and the three pennant buttons.
## - PlayMenu: the GAME screen — map/mode selectors, Local / Host / Join.
##
## Picking Host or Join lands in the pre-match Lobby (U-4 / B-13); Local goes
## straight to Main.tscn.
##
## Both screens replay their pennant entrance every time they are shown, so
## bouncing between them never leaves a button stuck mid-unfurl.

const MAIN_SCENE_PATH:  String = "res://scenes/main/Main.tscn"
const LOBBY_SCENE_PATH: String = "res://scenes/ui/Lobby.tscn"

## Stagger between consecutive pennants unfurling.
const STAGGER: float = 0.09

## Order matches the old OptionButton: Option B is the default selection.
## Via the class_name rather than the GameLaunch autoload: an autoload lookup is
## not a constant expression, so it cannot initialise a const.
const MODES: Array[Dictionary] = [
	{"id": GameLaunchScript.GameMode.OPTION_B, "label": "OPTION B — CAPTURE & SEAL"},
	{"id": GameLaunchScript.GameMode.OPTION_A, "label": "OPTION A — HEALTH / DENTS"},
]

## There is exactly one arena, and which maps ship is still an open design
## decision (docs/Handoff.md). The row is present so the screen matches the
## layout, with its arrows disabled in the scene until there is something to
## cycle through.
const MAP_NAME: String = "DEFAULT ARENA"

@onready var title_screen: Control = %TitleScreen
@onready var play_menu: Control = %PlayMenu
@onready var settings_panel: SettingsPanel = %SettingsPanel

@onready var start_button: ArrowButton = %StartButton
@onready var settings_button: ArrowButton = %SettingsButton
@onready var quit_button: ArrowButton = %QuitButton

@onready var local_button: ArrowButton = %LocalButton
@onready var host_button: ArrowButton = %HostButton
@onready var join_button: ArrowButton = %JoinButton
@onready var join_address_edit: LineEdit = %JoinAddressEdit
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel

@onready var map_value_label: Label = %MapValueLabel
@onready var mode_value_label: Label = %ModeValueLabel
@onready var mode_prev_button: Button = %ModePrevButton
@onready var mode_next_button: Button = %ModeNextButton

var _mode_index: int = 0

func _ready() -> void:
	settings_panel.visible = false
	status_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Main.tscn captures it for a match
	GameVersion.attach_to(self)

	_style_address_field()
	map_value_label.text = MAP_NAME
	_apply_mode()

	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_panel.back_pressed.connect(_on_settings_back_pressed)
	back_button.pressed.connect(_on_back_pressed)
	local_button.pressed.connect(_on_local_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	mode_prev_button.pressed.connect(_on_mode_prev_pressed)
	mode_next_button.pressed.connect(_on_mode_next_pressed)

	# Q-1/B-62: a bounce back here from main.gd after the host quit or a join
	# failed — land on the GAME screen (not the title) since the player was
	# mid-match and most likely wants to rejoin or re-host immediately.
	if GameLaunch.pending_status_message != "":
		_show_play_menu()
		status_label.text = GameLaunch.pending_status_message
		GameLaunch.pending_status_message = ""
	else:
		_show_title_screen()

## The LineEdit sits on top of the wooden TEXT FIELD artwork, so it has to drop
## the theme's own card chrome and switch to the light-on-dark ink the rest of
## the panel uses.
func _style_address_field() -> void:
	for state in ["normal", "focus", "read_only"]:
		join_address_edit.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	join_address_edit.add_theme_color_override("font_color", Color("f5e6c8"))
	join_address_edit.add_theme_color_override("font_placeholder_color", Color(0.961, 0.902, 0.784, 0.45))
	join_address_edit.add_theme_color_override("caret_color", Color("f5e6c8"))
	join_address_edit.add_theme_font_size_override("font_size", 38)

# --- Screen switching ---------------------------------------------------------

func _show_title_screen() -> void:
	title_screen.visible = true
	play_menu.visible = false
	settings_panel.visible = false
	_unfurl([start_button, settings_button, quit_button])

func _show_play_menu() -> void:
	title_screen.visible = false
	play_menu.visible = true
	settings_panel.visible = false
	_unfurl([local_button, host_button, join_button])

func _unfurl(buttons: Array) -> void:
	for i in buttons.size():
		var button: ArrowButton = buttons[i]
		button.animate_in(i * STAGGER)

# --- Input --------------------------------------------------------------------

## B-34: the GAME screen needs a way back to the title without restarting.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and play_menu.visible:
		_on_back_pressed()
		get_viewport().set_input_as_handled()

# --- Title screen -------------------------------------------------------------

func _on_start_pressed() -> void:
	_show_play_menu()

## Title-screen-only, deliberately. A mid-match quit that skips
## NetworkManager.disconnect_network() would strand the other peers — the same
## soft-lock Q-1 fixed, just from the other end. Return to Menu → Quit is two
## clear steps instead.
func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_settings_pressed() -> void:
	title_screen.visible = false
	play_menu.visible = false
	settings_panel.visible = true

func _on_settings_back_pressed() -> void:
	_show_title_screen()

# --- GAME screen --------------------------------------------------------------

func _on_back_pressed() -> void:
	status_label.text = ""
	_show_title_screen()

func _on_mode_prev_pressed() -> void:
	_mode_index = (_mode_index - 1 + MODES.size()) % MODES.size()
	_apply_mode()

func _on_mode_next_pressed() -> void:
	_mode_index = (_mode_index + 1) % MODES.size()
	_apply_mode()

func _apply_mode() -> void:
	var mode: Dictionary = MODES[_mode_index]
	mode_value_label.text = str(mode["label"])
	GameLaunch.game_mode = int(mode["id"]) as GameLaunchScript.GameMode

func _on_local_pressed() -> void:
	GameLaunch.pending_action = "local"
	_reset_match_state()
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

## U-4: Host goes to the lobby so peers can ready-up before the match starts.
func _on_host_pressed() -> void:
	GameLaunch.pending_action = "host"
	_reset_match_state()
	get_tree().change_scene_to_file(LOBBY_SCENE_PATH)

## U-4: Join also goes through the lobby for the same ready-up gate.
func _on_join_pressed() -> void:
	var address := join_address_edit.text.strip_edges()
	if address.is_empty():
		status_label.text = "Enter a host address first (e.g. 127.0.0.1)."
		return
	GameLaunch.pending_action = "join"
	GameLaunch.pending_join_address = address
	_reset_match_state()
	get_tree().change_scene_to_file(LOBBY_SCENE_PATH)

## B-14: MatchManager/RoundManager are autoloads and survive scene changes —
## without this, a second match (Rematch, or Menu then Play again) would resume
## the first one's score/round number instead of starting at 0-0.
func _reset_match_state() -> void:
	MatchManager.reset()
	RoundManager.reset()
