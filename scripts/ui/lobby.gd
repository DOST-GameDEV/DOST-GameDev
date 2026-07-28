extends Control
class_name LobbyScene

## Pre-match lobby with ready-up gate. Fixes B-13.
##
## Flow:
##   Host:  game_setup.gd → Lobby (starts ENet server here) → Main.tscn
##   Join:  game_setup.gd → Lobby (starts ENet client here) → Main.tscn
##   Local: game_setup.gd → Lobby (no networking at all) → Main.tscn
##
## The lobby gates the scene transition to Main.tscn behind the host's Start
## button, which is only enabled when every connected peer is ready AND at
## least two are connected. This means `_start_hosting()` in main.gd now only
## runs (and calls MatchManager.begin_next_round()) after the lobby is full and
## ready — the fix for B-13.
##
## Join-index / team-role derivation mirrors main.gd::_spawn_player() exactly:
##   team = join_index / 2   → 0,0,1,1 for up to four peers
##   is_person = join_index % 2 == 0   → first peer of each pair is Person
## Read from one place only (here for display, main.gd for gameplay).
##
## LOCAL (2026-07-28, user feedback: "add the same button to local matching").
## Nothing here actually gates anything for Local — a single-PC session has no
## second peer to wait for — but it gets the same READY -> START rhythm
## instead of jumping straight to the match. See `_setup_local()` and the
## `GameLaunch.pending_action == "local"` branches in the button handlers
## below. Real multi-peer ready gating (the reason this scene exists at all)
## is completely unchanged for Host/Join.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
## Back out to the GAME screen rather than the title: that is where this lobby
## was entered from, and it is what displays GameLaunch.pending_status_message.
const MAIN_MENU_PATH  := "res://scenes/ui/GameSetup.tscn"

## Peer rows are built at runtime, so their look is set here rather than in the
## scene — cream on the wooden panel, matching the GAME screen's selector text.
const ROW_COLOR: Color = Color(0.961, 0.902, 0.784)
const ROW_READY_COLOR: Color = Color(1, 0.729, 0)
const ROW_FONT_SIZE: int = 30

@onready var host_address_label:   Label          = %HostAddressLabel
@onready var peer_list_container:  VBoxContainer  = %PeerListContainer
@onready var ready_button:         ArrowButton    = %ReadyButton
@onready var start_button:         ArrowButton    = %StartButton
@onready var status_label:         Label          = %StatusLabel
@onready var back_button:          Button         = %BackButton

## Host-authoritative ordered list of peer_ids. Index position is each peer's
## join index, which determines team (index/2) and role (index%2==0 → Person).
## Broadcast to all clients on every join/leave.
var _peer_join_order: Array[int] = []

## Host tracks ready state per peer_id. Broadcast to all via _rpc_set_ready.
## On clients the dict is built from RPCs, defaulting to false (not ready).
var _peer_ready: Dictionary = {}  # peer_id -> bool

var _is_ready: bool = false

func _ready() -> void:
	ready_button.pressed.connect(_on_ready_pressed)
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)

	NetworkManager.player_connected.connect(_on_peer_joined)
	NetworkManager.player_disconnected.connect(_on_peer_left)

	var action := GameLaunch.pending_action
	if action == "local":
		_setup_local()
		return

	if action == "host":
		if NetworkManager.host_game() != OK:
			status_label.text = "Failed to start server — port may be in use."
			return
		host_address_label.text = "HOST: %s" % _get_lan_address()
		start_button.visible = true
		start_button.disabled = true
		# Host is peer 1; peer_connected never fires for self on the server.
		var host_id := multiplayer.get_unique_id()
		_peer_join_order.append(host_id)
		_peer_ready[host_id] = false

	elif action == "join":
		var address := GameLaunch.pending_join_address
		if NetworkManager.join_game(address) != OK:
			status_label.text = "Could not reach that host."
			return
		NetworkManager.connection_succeeded.connect(_on_connected_to_host)
		NetworkManager.server_disconnected.connect(_on_server_disconnected)
		NetworkManager.connection_failed.connect(_on_connection_failed)
		host_address_label.text = "HOST: %s" % address
		start_button.visible = false
		status_label.text = "Connecting…"

	_refresh_peer_list()

	ready_button.animate_in()
	if start_button.visible:
		start_button.animate_in(0.09)

# ---------------------------------------------------------------------------
# Networking helpers
# ---------------------------------------------------------------------------

static func _get_lan_address() -> String:
	for addr in IP.get_local_addresses():
		if ":" in addr:
			continue  # skip IPv6
		if addr.begins_with("127."):
			continue  # skip loopback
		return addr
	return "127.0.0.1"

func _on_connected_to_host() -> void:
	# The host will immediately send _rpc_sync_state via _on_peer_joined, which
	# populates _peer_join_order and _peer_ready for us.
	status_label.text = "Connected — waiting for host to start…"

func _on_peer_joined(peer_id: int) -> void:
	if multiplayer.is_server():
		_peer_join_order.append(peer_id)
		_peer_ready[peer_id] = false
		# Give the new peer a full snapshot so they know who's already here.
		_rpc_sync_state.rpc_id(peer_id, _peer_join_order, _peer_ready)
		# Tell everyone else about the updated join order.
		_rpc_update_join_order.rpc(_peer_join_order)
		_refresh_peer_list()
		_refresh_start_button()

func _on_peer_left(peer_id: int) -> void:
	_peer_join_order.erase(peer_id)
	_peer_ready.erase(peer_id)
	if multiplayer.is_server():
		_rpc_update_join_order.rpc(_peer_join_order)
	_refresh_peer_list()
	if multiplayer.is_server():
		_refresh_start_button()

func _on_server_disconnected() -> void:
	GameLaunch.pending_status_message = "Host ended the session."
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

func _on_connection_failed() -> void:
	GameLaunch.pending_status_message = "Could not reach that host."
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

# ---------------------------------------------------------------------------
# RPCs
# ---------------------------------------------------------------------------

## Host → new joiner only: full snapshot of current lobby state.
@rpc("authority", "call_remote", "reliable")
func _rpc_sync_state(join_order: Array, ready_states: Dictionary) -> void:
	_peer_join_order.assign(join_order)
	_peer_ready = ready_states
	_refresh_peer_list()

## Host → all peers: updated join order after a peer joins or leaves.
@rpc("authority", "call_local", "reliable")
func _rpc_update_join_order(join_order: Array) -> void:
	_peer_join_order.assign(join_order)
	_refresh_peer_list()

## Any peer → all peers: a peer changed their ready state.
## call_local so the sender's own UI updates immediately too.
@rpc("any_peer", "call_local", "reliable")
func _rpc_set_ready(peer_id: int, is_ready: bool) -> void:
	_peer_ready[peer_id] = is_ready
	_refresh_peer_list()
	if multiplayer.is_server():
		_refresh_start_button()

## Host → all peers: begin the match. Each peer transitions to Main.tscn,
## where main.gd's _ready() / GameLaunch flow takes over from here.
@rpc("authority", "call_local", "reliable")
func _rpc_begin_match() -> void:
	MatchManager.reset()
	RoundManager.reset()
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

# ---------------------------------------------------------------------------
# UI refresh
# ---------------------------------------------------------------------------

func _refresh_peer_list() -> void:
	for child in peer_list_container.get_children():
		child.queue_free()

	for i in range(_peer_join_order.size()):
		var peer_id: int = _peer_join_order[i]
		var team      := i / 2
		var is_person := i % 2 == 0
		var team_letter := "A" if team == 0 else "B"
		var role_str    := "PERSON" if is_person else "PROP"
		var is_ready_val: bool = _peer_ready.get(peer_id, false)
		var ready_str := " ✓" if is_ready_val else " …"
		var you_tag   := " (YOU)" if peer_id == multiplayer.get_unique_id() else ""

		var row := Label.new()
		row.text = "TEAM %s · %s%s%s" % [team_letter, role_str, you_tag, ready_str]
		row.add_theme_color_override("font_color", ROW_READY_COLOR if is_ready_val else ROW_COLOR)
		row.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		peer_list_container.add_child(row)

func _refresh_start_button() -> void:
	if not multiplayer.is_server():
		return
	if _peer_join_order.size() < 2:
		start_button.disabled = true
		return
	for pid in _peer_join_order:
		if not _peer_ready.get(pid, false):
			start_button.disabled = true
			return
	start_button.disabled = false

# ---------------------------------------------------------------------------
# Local (no networking) — see the class doc's LOCAL section
# ---------------------------------------------------------------------------

func _setup_local() -> void:
	host_address_label.text = "LOCAL MATCH"
	start_button.visible = true
	start_button.disabled = true
	var row := Label.new()
	row.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	peer_list_container.add_child(row)
	_refresh_local_row()
	status_label.text = "Press READY to start."
	# This branch returns before _ready's own unfurl, so it plays its own.
	ready_button.animate_in()
	start_button.animate_in(0.09)

func _refresh_local_row() -> void:
	if peer_list_container.get_child_count() == 0:
		return
	var row := peer_list_container.get_child(0) as Label
	row.text = "YOU (LOCAL) ✓" if _is_ready else "YOU (LOCAL) …"
	row.add_theme_color_override("font_color", ROW_READY_COLOR if _is_ready else ROW_COLOR)

# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_ready_pressed() -> void:
	_is_ready = not _is_ready
	ready_button.caption = "UNREADY" if _is_ready else "READY"
	if GameLaunch.pending_action == "local":
		start_button.disabled = not _is_ready
		_refresh_local_row()
		status_label.text = "Ready! Press START MATCH." if _is_ready else "Press READY to start."
		return
	_rpc_set_ready.rpc(multiplayer.get_unique_id(), _is_ready)

func _on_start_pressed() -> void:
	if GameLaunch.pending_action == "local":
		# No RPC, no networking — B-14's reset already ran once in
		# game_setup.gd's _on_local_pressed(); this mirrors _rpc_begin_match's
		# own double-reset for Host/Join rather than skipping it here.
		MatchManager.reset()
		RoundManager.reset()
		get_tree().change_scene_to_file(MAIN_SCENE_PATH)
		return
	_rpc_begin_match.rpc()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()

func _on_back_pressed() -> void:
	NetworkManager.disconnect_network()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
