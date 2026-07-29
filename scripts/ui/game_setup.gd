extends Control
class_name GameSetup

## The GAME screen: pick a map and mode, then start offline, host on the LAN, or
## join an address. Its own scene rather than a panel inside MainMenu — the two
## screens share no nodes and only ever hand off to each other.
##
## All three launches land in the pre-match Lobby (U-4 / B-13). Host and Join
## need it for the ready-up gate; Play Offline has nothing to wait for but keeps
## the same READY → START rhythm rather than jumping straight into the match.

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

@onready var map_prev_button: TextureButton = %MapPrevButton
@onready var map_next_button: TextureButton = %MapNextButton

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
var _map_index: int = 0

func _ready() -> void:
	status_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameVersion.attach_to(self)

	# Start on whatever is already chosen rather than resetting to the first map.
	# GameLaunch.selected_map is a preference that survives returning to the menu,
	# so a player who picked Bayan Plaza should not have to re-pick it every time.
	_map_index = GameLaunch.map_index()
	_apply_map()
	_apply_mode()

	# A one-map build would leave these cycling a list of one, so they follow the
	# registry rather than a hand-set flag in the scene.
	var many_maps := GameLaunch.MAPS.size() > 1
	map_prev_button.disabled = not many_maps
	map_next_button.disabled = not many_maps

	local_button.pressed.connect(_on_local_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
	map_prev_button.pressed.connect(_on_map_prev_pressed)
	map_next_button.pressed.connect(_on_map_next_pressed)
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
	AudioManager.play("ui_back") # 4.1
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

# --- Map selector -------------------------------------------------------------
# Reads GameLaunch.MAPS, the registry that also drives the launch path and the
# fallback, so the picker cannot disagree with what actually exists. Adding a map
# is one entry there plus its scene — nothing here changes.

func _on_map_prev_pressed() -> void:
	AudioManager.play("ui_click") # 4.1
	_map_index = (_map_index - 1 + GameLaunch.MAPS.size()) % GameLaunch.MAPS.size()
	_apply_map()

func _on_map_next_pressed() -> void:
	AudioManager.play("ui_click") # 4.1
	_map_index = (_map_index + 1) % GameLaunch.MAPS.size()
	_apply_map()

func _apply_map() -> void:
	var entry: Dictionary = GameLaunch.MAPS[_map_index]
	map_value_label.text = String(entry["name"])
	GameLaunch.selected_map = entry["id"]

# --- Mode selector ------------------------------------------------------------

func _on_mode_prev_pressed() -> void:
	AudioManager.play("ui_click") # 4.1
	_mode_index = (_mode_index - 1 + MODES.size()) % MODES.size()
	_apply_mode()

func _on_mode_next_pressed() -> void:
	AudioManager.play("ui_click") # 4.1
	_mode_index = (_mode_index + 1) % MODES.size()
	_apply_mode()

func _apply_mode() -> void:
	var mode: Dictionary = MODES[_mode_index]
	mode_value_label.text = str(mode["label"])
	GameLaunch.game_mode = int(mode["id"]) as GameLaunchScript.GameMode

# --- Launch -------------------------------------------------------------------

## Local goes through the lobby too, so single-PC play gets the same READY →
## START rhythm as the networked paths. lobby.gd resets again immediately before
## the scene change, mirroring _rpc_begin_match's own double-reset.
func _on_local_pressed() -> void:
	GameLaunch.pending_action = "local"
	_reset_match_state()
	get_tree().change_scene_to_file(LOBBY_SCENE_PATH)

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
