extends Control
class_name GameSetup

## The GAME screen: pick a map and mode, then start offline, host on the LAN, or
## join an address. Its own scene rather than a panel inside MainMenu — the two
## screens share no nodes and only ever hand off to each other.
##
## Host and Join both land in the pre-match Lobby (U-4 / B-13) for the ready-up
## gate; Play Offline goes straight to Main.tscn.

const MAIN_SCENE_PATH:  String = "res://scenes/main/Main.tscn"
const LOBBY_SCENE_PATH: String = "res://scenes/ui/Lobby.tscn"
const MAIN_MENU_PATH:   String = "res://scenes/ui/MainMenu.tscn"

## Stagger between consecutive buttons unfurling.
const STAGGER: float = 0.09

## Via the class_name rather than the GameLaunch autoload: an autoload lookup is
## not a constant expression, so it cannot initialise a const.
const MODES: Array[Dictionary] = [
	{"id": GameLaunchScript.GameMode.OPTION_B, "label": "CAPTURE"},
	{"id": GameLaunchScript.GameMode.OPTION_A, "label": "DENTS"},
]

## TODO(U-8): make this a real selector — see docs/Handoff.md.
## One arena exists and it is not swappable: the floor, bounds, kill plane and
## hazards are authored inline in Main.tscn and spawn positions are a const in
## main.gd. So the MAP row is present to match the artboard but its arrows are
## disabled in the scene, and this is a fixed label rather than a list. Wiring
## them up means extracting the arena into its own scene first; cycling a
## one-item list would only look interactive.
const MAP_NAME: String = "CLASSIC"

@onready var local_button: ArrowButton = %LocalButton
@onready var host_button: ArrowButton = %HostButton
@onready var join_button: ArrowButton = %JoinButton
@onready var join_address_edit: LineEdit = %JoinAddressEdit
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel

@onready var map_value_label: Label = %MapValueLabel
@onready var mode_value_label: Label = %ModeValueLabel
@onready var mode_prev_button: TextureButton = %ModePrevButton
@onready var mode_next_button: TextureButton = %ModeNextButton

var _mode_index: int = 0

func _ready() -> void:
	status_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameVersion.attach_to(self)

	map_value_label.text = MAP_NAME
	_apply_mode()

	local_button.pressed.connect(_on_local_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
	mode_prev_button.pressed.connect(_on_mode_prev_pressed)
	mode_next_button.pressed.connect(_on_mode_next_pressed)

	# Q-1/B-62: main.gd bounces back here after the host quit or a join failed,
	# since that player is most likely about to rejoin or re-host.
	if GameLaunch.pending_status_message != "":
		status_label.text = GameLaunch.pending_status_message
		GameLaunch.pending_status_message = ""

	var buttons: Array[ArrowButton] = [local_button, host_button, join_button]
	for i in buttons.size():
		buttons[i].animate_in(i * STAGGER)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

# --- Mode selector ------------------------------------------------------------

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

# --- Launch -------------------------------------------------------------------

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
## without this, a second match would resume the first one's score.
func _reset_match_state() -> void:
	MatchManager.reset()
	RoundManager.reset()
