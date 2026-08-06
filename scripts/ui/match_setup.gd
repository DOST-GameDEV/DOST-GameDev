extends Control
class_name MatchSetupScreen


const MAIN_SCENE_PATH: String = "res://scenes/main/Main.tscn"
const MODE_SELECT_PATH: String = "res://scenes/ui/ModeSelect.tscn"
const MULTIPLAYER_SETUP_PATH: String = "res://scenes/ui/MultiplayerSetup.tscn"

const STAGGER: float = 0.09

const LOCKED_MODULATE: Color = Color(1, 1, 1, 0.28)

const RULESET_LABEL: String = "CAPTURE"
const RULESET_DETAIL: String = "Knock the lata off its circle and keep it there. The countdown at the top of the screen is the round: when it hits zero the attackers take it. Four knockdowns ends it outright. The defenders win by surviving the clock."

const DIFFICULTIES: Array[Dictionary] = [
	{
		"id": 0, "label": "EASY",
		"detail": "The kid. Holds its post, aims where the lata is rather than where it is going, and overcommits often enough that you can learn to bait it. Measured the most beatable of the three: it blocks 29% of throws.",
	},
	{
		"id": 1, "label": "NORMAL",
		"detail": "The default, and the tier every balance number in this project was measured at. Reads your bearing, leads the lata, and blocks about 38% of what you throw.",
	},
	{
		"id": 2, "label": "HARD",
		"detail": "The one who wins. Chases to the edge of its own box, leads almost perfectly, and barely ever makes a mistake. Measured: it blocks 62% of throws and rounds end fast, so expect to be tagged on the way in.",
	},
]

@onready var map_preview: MapPreview = %MapPreview
@onready var banner_label: Label = %BannerLabel

@onready var map_prev_button: TextureButton = %MapPrevButton
@onready var map_next_button: TextureButton = %MapNextButton
@onready var map_value_label: Label = %MapValueLabel
@onready var mode_prev_button: TextureButton = %ModePrevButton
@onready var mode_next_button: TextureButton = %ModeNextButton
@onready var mode_value_label: Label = %ModeValueLabel
@onready var difficulty_prev_button: TextureButton = %DifficultyPrevButton
@onready var difficulty_next_button: TextureButton = %DifficultyNextButton
@onready var difficulty_value_label: Label = %DifficultyValueLabel
@onready var character_button: Button = %CharacterButton
@onready var character_panel: CharacterSelect = %CharacterSelectPanel

@onready var map_row: Control = %MapRow
@onready var mode_row: Control = %ModeRow
@onready var difficulty_row: Control = %DifficultyRow
@onready var fighter_row: Control = %FighterRow

@onready var detail_label: Label = %DetailLabel
@onready var primary_button: ArrowButton = %PrimaryButton
@onready var start_button: ArrowButton = %StartButton
@onready var status_label: Label = %StatusLabel
@onready var back_button: Button = %BackButton

@onready var seat_heading: Label = %SeatHeading
@onready var seat_hint: Label = %SeatHint
@onready var seat_buttons: Array[Button] = [
	%SeatButton0, %SeatButton1, %SeatButton2, %SeatButton3,
]

var _action: String = "local"

var _map_index: int = 0
var _difficulty_index: int = 1

enum DetailTopic { MAP, MODE, DIFFICULTY, SEAT }
var _detail_topic: DetailTopic = DetailTopic.MAP


var _peer_seats: Dictionary = {}
var _peer_ready: Dictionary = {}
var _peer_spectating: Dictionary = {}
var _vacated_seats: Dictionary = {}

func _ready() -> void:
	_read_dedicated_args()
	_action = GameLaunch.pending_action
	if _action == "":
		_action = "local"
	status_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameVersion.attach_to(self)

	_map_index = GameLaunch.map_index()
	_difficulty_index = clampi(SettingsManager.ai_difficulty, 0, DIFFICULTIES.size() - 1)

	_wire_selector(map_prev_button, map_next_button, _on_map_prev, _on_map_next)
	_wire_selector(difficulty_prev_button, difficulty_next_button,
		_on_difficulty_prev, _on_difficulty_next)
	character_button.pressed.connect(_on_character_pressed)
	character_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
	character_panel.visible = false
	character_panel.closed.connect(_on_character_panel_closed)

	if GameLaunch.MAPS.size() <= 1:
		map_prev_button.disabled = true
		map_next_button.disabled = true

	for i in seat_buttons.size():
		var seat := i
		seat_buttons[i].pressed.connect(func() -> void: _on_seat_pressed(seat))
		seat_buttons[i].mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))

	_wire_detail_focus(DetailTopic.MAP,
		[map_row, map_prev_button, map_next_button])
	_wire_detail_focus(DetailTopic.MODE,
		[mode_row, mode_prev_button, mode_next_button])
	_wire_detail_focus(DetailTopic.DIFFICULTY,
		[difficulty_row, difficulty_prev_button, difficulty_next_button])
	var seat_targets: Array[Control] = [fighter_row, character_button]
	seat_targets.append_array(seat_buttons)
	_build_spectate_button()
	if _spectate_button != null:
		seat_targets.append(_spectate_button)
	_wire_detail_focus(DetailTopic.SEAT, seat_targets)

	primary_button.pressed.connect(_on_primary_pressed)
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	back_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))

	_apply_map()
	mode_row.visible = false
	_apply_difficulty()
	_refresh_character_button()

	match _action:
		"local": _setup_solo()
		"host":  _setup_host()
		"join":  _setup_join()

	primary_button.animate_in()
	if start_button.visible:
		start_button.animate_in(STAGGER)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()

func _wire_selector(prev: TextureButton, next: TextureButton,
		on_prev: Callable, on_next: Callable) -> void:
	prev.pressed.connect(on_prev)
	next.pressed.connect(on_next)
	prev.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
	next.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))


func _setup_solo() -> void:
	banner_label.text = "SINGLE PLAYER"
	seat_heading.text = "YOUR CHARACTER"
	seat_hint.text = "Four players, one taya. The taya rotates every round, so everyone defends exactly once. Empty seats are bots — the kids from the street who fill in."
	_seat_hint_base = seat_hint.text
	primary_button.caption = "START MATCH"
	start_button.visible = false
	_refresh_seats()


var _dedicated: bool = false
var _dedicated_port: int = NetworkManagerScript.DEFAULT_PORT

func _read_dedicated_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--dedicated":
			_dedicated = true
			GameLaunch.pending_action = "host"
		elif arg.begins_with("--port="):
			var port_text := arg.substr(len("--port="))
			if port_text.is_valid_int():
				_dedicated_port = int(port_text)
			else:
				push_error("MatchSetup: --port= needs a number, got '%s'" % port_text)

func _setup_host() -> void:
	banner_label.text = "LOBBY"
	var already_hosting := NetworkManager.is_networked() and NetworkManager.is_host()
	if not already_hosting and NetworkManager.host_game(_dedicated_port, _dedicated) != OK:
		AudioManager.play("ui_error")
		status_label.text = "Could not open the server. Port %d may already be in use." % NetworkManagerScript.DEFAULT_PORT
		primary_button.visible = false
		start_button.visible = false
		seat_heading.text = "NOT HOSTING"
		return
	seat_heading.text = "LOBBY  ·  YOU ARE HOSTING"
	_show_addresses(_host_addresses_with_port())
	_show_join_code()
	if _firewall_hint != null:
		_firewall_hint.visible = true
	seat_hint.text = "You pick the map and the mode for everyone. Click a seat to move. Empty seats are played by bots. Give the address below to the others."
	_seat_hint_base = seat_hint.text
	primary_button.caption = "READY"
	start_button.visible = true
	start_button.disabled = true

	NetworkManager.player_connected.connect(_on_peer_joined)
	NetworkManager.player_disconnected.connect(_on_peer_left)
	NetworkManager.peer_spectator_changed.connect(_on_peer_spectator_changed)
	NetworkManager.lobby_leader_changed.connect(_on_lobby_leader_changed)
	NetworkManager.join_code_changed.connect(func(_c: String) -> void: _show_join_code())

	var host_id := multiplayer.get_unique_id()
	if not _dedicated:
		_peer_seats[host_id] = 0
		_peer_ready[host_id] = false
	if GameLaunch.spectator:
		NetworkManager.publish_spectator(true)
	_refresh_leader_controls()
	_refresh_seats()
	_refresh_primary_button()

func _setup_join() -> void:
	banner_label.text = "LOBBY"
	seat_hint.text = JOINER_SEAT_HINT
	_seat_hint_base = seat_hint.text
	primary_button.caption = "READY"
	start_button.visible = false
	_refresh_leader_controls()

	var parts := MultiplayerSetupScreen.split_address(GameLaunch.pending_join_address)
	var host: String = String(parts[0])
	var port: int = int(parts[1])
	seat_heading.text = "CONNECTING…"
	_show_addresses(PackedStringArray([GameLaunch.pending_join_address]))
	_show_join_code()
	if host.is_empty() or NetworkManager.join_game(host, port) != OK:
		AudioManager.play("ui_error")
		status_label.text = "Could not reach %s." % GameLaunch.pending_join_address
		seat_heading.text = "NOT CONNECTED"
		primary_button.visible = false
		return

	NetworkManager.connection_succeeded.connect(_on_connected_to_host)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.player_disconnected.connect(_on_peer_left)
	NetworkManager.lobby_leader_changed.connect(_on_lobby_leader_changed)
	NetworkManager.join_code_changed.connect(func(_c: String) -> void: _show_join_code())
	status_label.text = "Connecting…"
	_refresh_seats()
	_refresh_primary_button()

const HAMACHI_PREFIX: String = "25."

static func host_addresses() -> PackedStringArray:
	var hamachi := PackedStringArray()
	var private := PackedStringArray()
	var other := PackedStringArray()
	for addr in IP.get_local_addresses():
		if ":" in addr:
			continue
		if addr.begins_with("127."):
			continue
		if addr.begins_with("169.254."):
			continue
		if addr.begins_with(HAMACHI_PREFIX):
			hamachi.append(addr)
		elif addr.begins_with("192.168.") or addr.begins_with("10.") \
				or _is_172_private(addr):
			private.append(addr)
		else:
			other.append(addr)
	var ranked := PackedStringArray()
	ranked.append_array(hamachi)
	ranked.append_array(private)
	ranked.append_array(other)
	if ranked.is_empty():
		ranked.append("127.0.0.1")
	return ranked

static func _is_172_private(addr: String) -> bool:
	if not addr.begins_with("172."):
		return false
	var second := addr.split(".")[1] if addr.split(".").size() > 1 else ""
	if not second.is_valid_int():
		return false
	var octet := int(second)
	return octet >= 16 and octet <= 31

static func _lan_address() -> String:
	return host_addresses()[0]

static func _host_addresses_with_port() -> PackedStringArray:
	var out := PackedStringArray()
	for addr in host_addresses():
		out.append("%s:%d" % [addr, NetworkManagerScript.DEFAULT_PORT])
	return out

func _lock_host_only_controls() -> void:
	for button in [map_prev_button, map_next_button, mode_prev_button, mode_next_button,
			difficulty_prev_button, difficulty_next_button]:
		button.disabled = true
		button.modulate = LOCKED_MODULATE

func _is_networked_lobby() -> bool:
	return _action != "local"

func _is_lobby_host() -> bool:
	return _action == "host" and multiplayer.multiplayer_peer != null and multiplayer.is_server()

func _is_lobby_leader() -> bool:
	if not _is_networked_lobby():
		return true
	return NetworkManager.is_lobby_leader()

const JOINER_SEAT_HINT: String = "The host picks the map and the mode. Click a free seat to move. Empty seats are played by bots."
const LEADER_SEAT_HINT: String = "You pick the map and the mode for everyone. Click a free seat to move. Empty seats are played by bots. Read the code above out to the others."

func _refresh_leader_controls() -> void:
	if _is_lobby_leader():
		_unlock_leader_controls()
	else:
		_lock_host_only_controls()
	if _is_networked_lobby() and not _is_lobby_host():
		_seat_hint_base = LEADER_SEAT_HINT if _is_lobby_leader() else JOINER_SEAT_HINT
		_refresh_seat_hint()

func _unlock_leader_controls() -> void:
	for button in [map_prev_button, map_next_button, mode_prev_button, mode_next_button,
			difficulty_prev_button, difficulty_next_button]:
		button.disabled = false
		button.modulate = Color.WHITE

func _on_lobby_leader_changed(peer_id: int) -> void:
	_refresh_leader_controls()
	start_button.visible = _can_start_match()
	_refresh_start_button()
	if peer_id == multiplayer.get_unique_id() and not _is_lobby_host():
		status_label.text = "You are now the lobby leader — you pick the map, the mode, and when to start."

func _can_rpc() -> bool:
	if not _is_networked_lobby() or not multiplayer.has_multiplayer_peer():
		return false
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _on_connected_to_host() -> void:
	seat_heading.text = "LOBBY  ·  CONNECTED"
	_show_addresses(PackedStringArray([GameLaunch.pending_join_address]))
	_show_join_code()
	status_label.text = "Connected. Pick your character, then press READY."

func _on_connection_failed() -> void:
	GameLaunch.pending_status_message = "Could not reach that host."
	get_tree().change_scene_to_file(MULTIPLAYER_SETUP_PATH)

func _on_server_disconnected() -> void:
	if NetworkManager.rerouting_to_running_match:
		return
	GameLaunch.pending_status_message = "Host ended the session."
	get_tree().change_scene_to_file(MULTIPLAYER_SETUP_PATH)

func _on_peer_joined(peer_id: int) -> void:
	if not _is_lobby_host():
		return
	var seat := _first_free_seat()
	if seat >= 0:
		_peer_seats[peer_id] = seat
		_peer_ready[peer_id] = false
	else:
		_peer_spectating[peer_id] = true
	_rpc_sync_state.rpc_id(peer_id, _peer_seats, _peer_ready,
		GameLaunch.selected_map, SettingsManager.ai_difficulty,
		_peer_spectating)
	_rpc_sync_seats.rpc(_peer_seats, _peer_spectating)
	_refresh_seats()
	_refresh_start_button()

func _on_peer_left(peer_id: int) -> void:
	_peer_seats.erase(peer_id)
	_peer_ready.erase(peer_id)
	_peer_spectating.erase(peer_id)
	_vacated_seats.erase(peer_id)
	if _is_lobby_host():
		_rpc_sync_seats.rpc(_peer_seats, _peer_spectating)
		_refresh_start_button()
	_refresh_seats()

func _first_free_seat() -> int:
	for seat in range(NetworkManagerScript.MAX_PLAYERS):
		if not _peer_seats.values().has(seat):
			return seat
	return -1

func _on_peer_spectator_changed(peer_id: int, spectating: bool) -> void:
	if not _is_lobby_host():
		return
	if spectating == bool(_peer_spectating.get(peer_id, false)):
		return
	if spectating:
		if _peer_seats.has(peer_id):
			_vacated_seats[peer_id] = int(_peer_seats[peer_id])
			_peer_seats.erase(peer_id)
		_peer_spectating[peer_id] = true
		_peer_ready.erase(peer_id)
	else:
		_peer_spectating.erase(peer_id)
		var wanted := int(_vacated_seats.get(peer_id, -1))
		_vacated_seats.erase(peer_id)
		if wanted < 0 or _peer_seats.values().has(wanted):
			wanted = _first_free_seat()
		if wanted >= 0:
			_peer_seats[peer_id] = wanted
		_peer_ready[peer_id] = false
	_rpc_sync_seats.rpc(_peer_seats, _peer_spectating)
	_refresh_seats()
	_refresh_start_button()


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_state(seats: Dictionary, ready_states: Dictionary,
		map_id: StringName, difficulty: int,
		spectating: Dictionary = {}) -> void:
	_peer_seats = seats
	_peer_ready = ready_states
	_peer_spectating = spectating
	_apply_host_config(map_id, difficulty)
	_refresh_seats()
	_refresh_primary_button()

@rpc("authority", "call_local", "reliable")
func _rpc_sync_seats(seats: Dictionary, spectating: Dictionary = {}) -> void:
	_peer_seats = seats
	_peer_spectating = spectating
	_refresh_seats()

@rpc("authority", "call_local", "reliable")
func _rpc_sync_config(map_id: StringName, difficulty: int) -> void:
	_apply_host_config(map_id, difficulty)
	for peer_id in _peer_ready:
		_peer_ready[peer_id] = false
	primary_button.caption = "READY"
	status_label.text = "The host changed the match. Press READY again."
	_refresh_seats()
	_refresh_start_button()

func _apply_host_config(map_id: StringName, difficulty: int) -> void:
	GameLaunch.selected_map = map_id
	_map_index = GameLaunch.map_index()
	_difficulty_index = clampi(difficulty, 0, DIFFICULTIES.size() - 1)
	SettingsManager.set_ai_difficulty(_difficulty_index, false)
	map_value_label.text = String(GameLaunch.MAPS[_map_index]["name"])
	difficulty_value_label.text = String(DIFFICULTIES[_difficulty_index]["label"])
	map_preview.show_map(GameLaunch.MAPS[_map_index])
	_refresh_detail()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_seat(seat: int) -> void:
	if not _is_lobby_host():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _claim_seat(peer_id, seat):
		_rpc_seat_denied.rpc_id(peer_id)

@rpc("authority", "call_remote", "reliable")
func _rpc_seat_denied() -> void:
	AudioManager.play("ui_error")
	status_label.text = "Somebody took that character first."

@rpc("any_peer", "call_local", "reliable")
func _rpc_set_ready(peer_id: int, is_ready: bool) -> void:
	_peer_ready[peer_id] = is_ready
	_refresh_seats()
	_refresh_start_button()

@rpc("authority", "call_local", "reliable")
func _rpc_begin_match(seat_tokens: Dictionary, map_id: StringName) -> void:
	GameLaunch.seat_tokens = seat_tokens
	GameLaunch.selected_map = map_id
	MatchManager.reset()
	RoundManager.reset()
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_map_prev() -> void:
	_cycle_map(-1)

func _on_map_next() -> void:
	_cycle_map(1)

func _cycle_map(step: int) -> void:
	AudioManager.play("ui_click")
	_map_index = posmod(_map_index + step, GameLaunch.MAPS.size())
	_apply_map()
	_broadcast_config()

func _apply_map() -> void:
	var entry: Dictionary = GameLaunch.MAPS[_map_index]
	map_value_label.text = String(entry["name"])
	GameLaunch.selected_map = entry["id"]
	map_preview.show_map(entry)
	_refresh_detail()


func _on_difficulty_prev() -> void:
	_cycle_difficulty(-1)

func _on_difficulty_next() -> void:
	_cycle_difficulty(1)

func _cycle_difficulty(step: int) -> void:
	AudioManager.play("ui_click")
	_difficulty_index = posmod(_difficulty_index + step, DIFFICULTIES.size())
	_apply_difficulty()
	_broadcast_config()

func _apply_difficulty() -> void:
	var tier: Dictionary = DIFFICULTIES[_difficulty_index]
	difficulty_value_label.text = String(tier["label"])
	SettingsManager.set_ai_difficulty(int(tier["id"]))
	_refresh_detail()

func _broadcast_config() -> void:
	if _is_lobby_host():
		_rpc_sync_config.rpc(GameLaunch.selected_map, SettingsManager.ai_difficulty)
	elif _is_lobby_leader() and _can_rpc():
		_rpc_request_config.rpc_id(1, GameLaunch.selected_map, SettingsManager.ai_difficulty)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_config(map_id: StringName, difficulty: int) -> void:
	if not _is_lobby_host():
		return
	if multiplayer.get_remote_sender_id() != NetworkManager.lobby_leader_id:
		return
	if not _is_known_map(map_id):
		return
	GameLaunch.selected_map = map_id
	SettingsManager.set_ai_difficulty(clampi(difficulty, 0, DIFFICULTIES.size() - 1), false)
	_rpc_sync_config.rpc(GameLaunch.selected_map, SettingsManager.ai_difficulty)

static func _is_known_map(map_id: StringName) -> bool:
	for entry in GameLaunch.MAPS:
		if entry["id"] == map_id:
			return true
	return false

func _on_character_pressed() -> void:
	AudioManager.play("ui_click")
	character_panel.visible = true

func _on_character_panel_closed() -> void:
	character_panel.visible = false
	_refresh_character_button()
	if not _can_rpc():
		return
	NetworkManager.publish_picks()
	var peer_id := multiplayer.get_unique_id()
	if bool(_peer_ready.get(peer_id, false)):
		primary_button.caption = "READY"
		status_label.text = "Character changed. Press READY again."
		_rpc_set_ready.rpc(peer_id, false)

func _refresh_character_button() -> void:
	character_button.text = "%s · %s · %s  ▸" % [
		_entry_name(CharacterRoster.ROSTER, GameLaunch.character_index()),
		_entry_name(CharacterRoster.CANS, GameLaunch.can_index()),
		_entry_name(CharacterRoster.SLIPPERS, GameLaunch.slipper_index())]
	_refresh_detail()

static func _entry_name(list: Array[Dictionary], index: int) -> String:
	if index < 0 or index >= list.size():
		return "?"
	return String(list[index]["name"])

func _refresh_detail() -> void:
	detail_label.text = detail_text_for(_detail_topic)

func detail_text_for(topic: DetailTopic) -> String:
	match topic:
		DetailTopic.MAP:
			var map_entry: Dictionary = GameLaunch.MAPS[_map_index]
			return "%s   %s" % [String(map_entry["name"]), String(map_entry["tagline"])]
		DetailTopic.MODE:
			return "%s   %s" % [RULESET_LABEL, RULESET_DETAIL]
		DetailTopic.DIFFICULTY:
			return "%s   %s" % [
				String(DIFFICULTIES[_difficulty_index]["label"]),
				String(DIFFICULTIES[_difficulty_index]["detail"])]
		_:
			return _seat_detail()

func _focus_detail(topic: DetailTopic) -> void:
	if _detail_topic == topic:
		return
	_detail_topic = topic
	_refresh_detail()

func _wire_detail_focus(topic: DetailTopic, controls: Array[Control]) -> void:
	for control in controls:
		if control == null:
			continue
		control.mouse_entered.connect(func() -> void: _focus_detail(topic))
		control.focus_entered.connect(func() -> void: _focus_detail(topic))

func _seat_detail() -> String:
	if GameLaunch.spectator:
		return "SPECTATOR   You take no seat and control no character: a free camera with no body, flying anywhere and through anything. Your slot is played by a bot, so the match is still four players. WASD to fly, mouse to look, TAB to follow a unit, wheel for speed."
	var seat := _local_seat()
	var opens_as_taya := seat == MatchManager.defender_slot_for(1)
	var role_line := "You defend FIRST — round 1 is yours in the box." if opens_as_taya \
		else "You attack first; your turn as taya comes in round %d." % [seat + 1]
	return "P%d   %s Every player is taya exactly once across the four rounds, and scores carry the whole way. Your lata and tsinelas picks are %s and %s — they tint the props everyone sees." % [
		seat + 1, role_line,
		_entry_name(CharacterRoster.CANS, GameLaunch.can_index()),
		_entry_name(CharacterRoster.SLIPPERS, GameLaunch.slipper_index())]

static func _kit_name(list: Array[Dictionary], index: int) -> String:
	if index < 0 or index >= list.size():
		return "the default kit"
	var path := String(list[index].get("ability", ""))
	if path == "":
		return "the default kit"
	return path.get_file().get_basename().capitalize()


static func _seat_is_person(seat: int) -> bool:
	return seat % 2 == 0

func _seat_name(seat: int) -> String:
	var label := "P%d" % [seat + 1]
	if seat == MatchManager.defender_slot_for(1):
		label += "  ·  TAYA FIRST"
	return label

func _local_seat() -> int:
	if not _is_networked_lobby():
		return GameLaunch.solo_seat
	return int(_peer_seats.get(multiplayer.get_unique_id(), -1))

func _on_seat_pressed(seat: int) -> void:
	if not _is_networked_lobby():
		AudioManager.play("ui_click")
		GameLaunch.solo_seat = seat
		_refresh_seats()
		_refresh_detail()
		return
	if _local_seat() == seat:
		return
	AudioManager.play("ui_click")
	if _is_lobby_host():
		if not _claim_seat(multiplayer.get_unique_id(), seat):
			AudioManager.play("ui_error")
			status_label.text = "That character is taken."
		return
	if not _can_rpc():
		AudioManager.play("ui_error")
		status_label.text = "Not connected to the host yet."
		return
	_rpc_request_seat.rpc_id(1, seat)

func _claim_seat(peer_id: int, seat: int) -> bool:
	if seat < 0 or seat >= NetworkManagerScript.MAX_PLAYERS:
		return false
	for other_id in _peer_seats:
		if other_id != peer_id and int(_peer_seats[other_id]) == seat:
			return false
	_peer_seats[peer_id] = seat
	_peer_ready[peer_id] = false
	_rpc_sync_seats.rpc(_peer_seats, _peer_spectating)
	_rpc_set_ready.rpc(peer_id, false)
	_refresh_seats()
	_refresh_start_button()
	return true

var _spectate_button: Button = null

const SPECTATE_BUTTON_SIZE: Vector2 = Vector2(176, 46)
const SPECTATE_FONT_SIZE: int = 19

const SPECTATE_ON: Color = Color("ffba00")
const SPECTATE_ON_HOVER: Color = Color("ffd45c")

func _build_spectate_button() -> void:
	if seat_buttons.is_empty() or seat_heading == null:
		return
	var rows := seat_heading.get_parent() as Container
	if rows == null:
		return
	var header_row := HBoxContainer.new()
	header_row.name = "HeaderRow"
	header_row.add_theme_constant_override("separation", 18)
	rows.add_child(header_row)
	rows.move_child(header_row, seat_heading.get_index())
	rows.remove_child(seat_heading)
	header_row.add_child(seat_heading)
	seat_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seat_heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seat_heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	seat_heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	_spectate_button = Button.new()
	_spectate_button.name = "SpectateButton"
	_spectate_button.toggle_mode = true
	_spectate_button.button_pressed = GameLaunch.spectator
	_spectate_button.focus_mode = Control.FOCUS_ALL
	_spectate_button.custom_minimum_size = SPECTATE_BUTTON_SIZE
	_spectate_button.add_theme_font_size_override("font_size", SPECTATE_FONT_SIZE)
	_spectate_button.add_theme_stylebox_override("normal",
		UiTheme.wood_style(UiTheme.WOOD_DEEP, UiTheme.WOOD_EDGE))
	_spectate_button.add_theme_stylebox_override("hover",
		UiTheme.wood_style(UiTheme.WOOD_MID, UiTheme.AMBER))
	_spectate_button.add_theme_stylebox_override("pressed",
		UiTheme.wood_style(SPECTATE_ON, UiTheme.WOOD_EDGE))
	_spectate_button.add_theme_stylebox_override("hover_pressed",
		UiTheme.wood_style(SPECTATE_ON_HOVER, UiTheme.WOOD_EDGE))
	_spectate_button.add_theme_stylebox_override("focus",
		UiTheme.wood_style(Color(0, 0, 0, 0), UiTheme.IMPACT))
	_spectate_button.add_theme_color_override("font_color", UiTheme.CREAM)
	_spectate_button.add_theme_color_override("font_hover_color", UiTheme.AMBER)
	_spectate_button.add_theme_color_override("font_pressed_color", UiTheme.INK)
	_spectate_button.add_theme_color_override("font_hover_pressed_color", UiTheme.INK)
	_spectate_button.add_theme_color_override("font_focus_color", UiTheme.CREAM)
	_spectate_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_spectate_button.clip_text = true
	_spectate_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_row.add_child(_spectate_button)
	_spectate_button.focus_neighbor_bottom = seat_buttons[0].get_path()
	seat_buttons[0].focus_neighbor_top = _spectate_button.get_path()
	_spectate_button.pressed.connect(_on_spectate_pressed)
	_spectate_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
	_refresh_spectate_button()
	_build_address_row(rows, header_row.get_index() + 1)
	_build_code_row(rows, header_row.get_index() + 2)


var _code_row: HBoxContainer = null
var _code_edit: LineEdit = null
var _address_row: HBoxContainer = null
var _address_edit: LineEdit = null
var _address_copy: Button = null
var _address_cycle: Button = null
var _address_options: PackedStringArray = PackedStringArray()
var _address_index: int = 0

const ADDRESS_FONT_SIZE: int = 20
const ADDRESS_BUTTON_FONT_SIZE: int = 16

func _build_code_row(rows: Container, at_index: int) -> void:
	_code_row = HBoxContainer.new()
	_code_row.name = "CodeRow"
	_code_row.add_theme_constant_override("separation", 10)
	_code_row.visible = false
	rows.add_child(_code_row)
	rows.move_child(_code_row, at_index)

	var caption := Label.new()
	caption.text = "CODE"
	caption.add_theme_color_override("font_color", UiTheme.HIGHLIGHT)
	caption.add_theme_font_size_override("font_size", ADDRESS_FONT_SIZE)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_code_row.add_child(caption)

	_code_edit = LineEdit.new()
	_code_edit.name = "CodeEdit"
	_code_edit.editable = false
	_code_edit.selecting_enabled = true
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.add_theme_font_size_override("font_size", ADDRESS_FONT_SIZE)
	_code_edit.add_theme_color_override("font_color", UiTheme.CREAM)
	_code_edit.add_theme_color_override("font_uneditable_color", UiTheme.CREAM)
	_code_edit.add_theme_stylebox_override("normal",
		UiTheme.wood_style(UiTheme.WOOD_DARK, UiTheme.WOOD_EDGE))
	_code_edit.add_theme_stylebox_override("read_only",
		UiTheme.wood_style(UiTheme.WOOD_DARK, UiTheme.WOOD_EDGE))
	_code_row.add_child(_code_edit)

	var copy := _small_button("COPY")
	copy.pressed.connect(_on_code_copy_pressed)
	_code_row.add_child(copy)

func _on_code_copy_pressed() -> void:
	AudioManager.play("ui_click")
	DisplayServer.clipboard_set(_code_edit.text)
	status_label.text = "Join code copied — send it to whoever you want in the game."

func _build_address_row(rows: Container, at_index: int) -> void:
	_address_row = HBoxContainer.new()
	_address_row.name = "AddressRow"
	_address_row.add_theme_constant_override("separation", 10)
	_address_row.visible = false
	rows.add_child(_address_row)
	rows.move_child(_address_row, at_index)

	_address_edit = LineEdit.new()
	_address_edit.name = "AddressEdit"
	_address_edit.editable = false
	_address_edit.selecting_enabled = true
	_address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address_edit.add_theme_font_size_override("font_size", ADDRESS_FONT_SIZE)
	_address_edit.add_theme_color_override("font_color", UiTheme.CREAM)
	_address_edit.add_theme_color_override("font_uneditable_color", UiTheme.CREAM)
	_address_edit.add_theme_stylebox_override("normal",
		UiTheme.wood_style(UiTheme.WOOD_DARK, UiTheme.WOOD_EDGE))
	_address_edit.add_theme_stylebox_override("read_only",
		UiTheme.wood_style(UiTheme.WOOD_DARK, UiTheme.WOOD_EDGE))
	_address_row.add_child(_address_edit)

	_address_copy = _small_button("COPY")
	_address_copy.pressed.connect(_on_address_copy_pressed)
	_address_row.add_child(_address_copy)

	_address_cycle = _small_button("OTHER")
	_address_cycle.visible = false
	_address_cycle.pressed.connect(_on_address_cycle_pressed)
	_address_row.add_child(_address_cycle)

	_build_firewall_hint(rows, at_index + 1)

var _firewall_hint: Label = null

const FIREWALL_DETAIL: String = ("Windows Firewall may be blocking this game silently.\n"
	+ "Check Windows Security ▸ Firewall & network protection ▸\n"
	+ "\"Allow an app through firewall\", and make sure BOTH\n"
	+ "Private and Public are ticked for this game.\n\n"
	+ "The host sees nothing wrong when this happens — the\n"
	+ "socket is open and listening either way.")

func _build_firewall_hint(rows: Container, at_index: int) -> void:
	_firewall_hint = Label.new()
	_firewall_hint.name = "FirewallHint"
	_firewall_hint.theme_type_variation = &"MenuCaption"
	_firewall_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_firewall_hint.visible = false
	_firewall_hint.text = "Nobody connecting?  ▸  hover here"
	_firewall_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	_firewall_hint.tooltip_text = FIREWALL_DETAIL
	rows.add_child(_firewall_hint)
	rows.move_child(_firewall_hint, at_index)


func _small_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	button.theme_type_variation = &"WoodButton"
	button.add_theme_font_size_override("font_size", ADDRESS_BUTTON_FONT_SIZE)
	button.custom_minimum_size = Vector2(96, 40)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
	return button


func _show_join_code() -> void:
	if _code_row == null:
		return
	var code: String = _local_join_code()
	_code_row.visible = not code.is_empty()
	if not code.is_empty():
		_code_edit.text = code

func _local_join_code() -> String:
	return NetworkManager.join_code

func _show_addresses(options: PackedStringArray) -> void:
	if _address_row == null:
		return
	_address_options = options
	_address_index = 0
	_address_row.visible = not options.is_empty()
	if options.is_empty():
		return
	_address_cycle.visible = options.size() > 1
	_refresh_address_text()


func _refresh_address_text() -> void:
	if _address_edit == null or _address_options.is_empty():
		return
	var shown := String(_address_options[_address_index])
	_address_edit.text = shown
	_address_edit.tooltip_text = "\n".join(Array(_address_options))
	if _address_cycle != null and _address_options.size() > 1:
		_address_cycle.text = "IP %d/%d" % [_address_index + 1, _address_options.size()]


func _on_address_copy_pressed() -> void:
	if _address_options.is_empty():
		return
	AudioManager.play("ui_click")
	DisplayServer.clipboard_set(String(_address_options[_address_index]))
	_address_copy.text = "COPIED"
	_address_edit.select_all()
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(_address_copy):
		_address_copy.text = "COPY"


func _on_address_cycle_pressed() -> void:
	if _address_options.size() <= 1:
		return
	AudioManager.play("ui_click")
	_address_index = (_address_index + 1) % _address_options.size()
	_refresh_address_text()

func _on_spectate_pressed() -> void:
	AudioManager.play("ui_click")
	GameLaunch.spectator = _spectate_button.button_pressed
	NetworkManager.publish_spectator(GameLaunch.spectator)
	_refresh_spectate_button()
	_refresh_seats()
	_refresh_detail()
	_refresh_primary_button()

func _refresh_spectate_button() -> void:
	if _spectate_button == null or not is_instance_valid(_spectate_button):
		return
	_spectate_button.text = "SPECTATING" if GameLaunch.spectator else "SPECTATE"
	_refresh_seat_hint()

func _refresh_seat_hint() -> void:
	if seat_hint == null or _seat_hint_base == "":
		return
	var others := 0
	for peer_id in _peer_spectating:
		if peer_id != multiplayer.get_unique_id():
			others += 1
	if others <= 0:
		seat_hint.text = _seat_hint_base
		return
	seat_hint.text = "%s  ·  %d %s watching." % [_seat_hint_base, others,
		"player is" if others == 1 else "players are"]

var _seat_hint_base: String = ""

func _refresh_primary_button() -> void:
	if not _is_networked_lobby():
		return
	primary_button.disabled = GameLaunch.spectator
	if GameLaunch.spectator:
		primary_button.caption = "SPECTATING"
		status_label.text = ("Watching. Your seat is played by a bot"
			+ ("; press START MATCH when everyone is ready." if _is_lobby_host()
				else " and the others do not wait for you."))
		return
	primary_button.caption = "READY"
	status_label.text = ""

func _refresh_seats() -> void:
	_refresh_spectate_button()
	for seat in range(seat_buttons.size()):
		var button := seat_buttons[seat]
		button.text = _seat_row_text(seat)
		button.disabled = GameLaunch.spectator 			or _occupant_of(seat) not in [-1, multiplayer.get_unique_id()]
	_refresh_detail()

func _player_number(peer_id: int) -> int:
	var ids: Array = _peer_seats.keys()
	for id in _peer_spectating:
		if not ids.has(id):
			ids.append(id)
	ids.sort()
	return ids.find(peer_id) + 1

func _occupant_of(seat: int) -> int:
	if not _is_networked_lobby():
		return -1
	for peer_id in _peer_seats:
		if int(_peer_seats[peer_id]) == seat:
			return peer_id
	return -1

func _peer_display_name(peer_id: int) -> String:
	var picks: Dictionary = NetworkManager.picks_for(peer_id)
	var who := String(picks.get("name", "")).strip_edges()
	return who if who != "" else "PLAYER %d" % [_player_number(peer_id)]

const SOLO_YOU_MARK: String = "◀ YOU"

func _seat_row_text(seat: int) -> String:
	var label := _seat_name(seat)
	if not _is_networked_lobby():
		if seat == GameLaunch.solo_seat:
			return "%s   %s" % [label, SOLO_YOU_MARK]
		return "%s   · BOT" % label

	var occupant := _occupant_of(seat)
	if occupant == -1:
		return "%s   · BOT" % label
	if occupant == multiplayer.get_unique_id():
		var own_tick := "✓" if bool(_peer_ready.get(occupant, false)) else "…"
		return "%s   %s  %s" % [label, SOLO_YOU_MARK, own_tick]
	var who := _peer_display_name(occupant)
	var tick := "✓" if bool(_peer_ready.get(occupant, false)) else "…"
	return "%s   · %s  %s" % [label, who, tick]

func _everyone_ready_to_start() -> bool:
	for peer_id in _peer_seats:
		if not bool(_peer_ready.get(peer_id, false)):
			return false
	return not (_peer_seats.is_empty() and _peer_spectating.is_empty())

func _refresh_start_button() -> void:
	if not _can_start_match():
		return
	start_button.disabled = not _everyone_ready_to_start()

func _can_start_match() -> bool:
	return _is_lobby_host() or (_is_networked_lobby() and _is_lobby_leader())


func _on_primary_pressed() -> void:
	if not _is_networked_lobby():
		_launch_solo()
		return
	if not _can_rpc():
		AudioManager.play("ui_error")
		status_label.text = "Not connected to the host yet."
		return
	var peer_id := multiplayer.get_unique_id()
	var now_ready := not bool(_peer_ready.get(peer_id, false))
	primary_button.caption = "UNREADY" if now_ready else "READY"
	if not now_ready:
		status_label.text = ""
	elif _is_lobby_host():
		status_label.text = "Ready. START MATCH goes live once every seated player is."
	else:
		status_label.text = "Waiting for the host to start…"
	_rpc_set_ready.rpc(peer_id, now_ready)

func _launch_solo() -> void:
	GameLaunch.seat_tokens.clear()
	MatchManager.reset()
	RoundManager.reset()
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

func _on_start_pressed() -> void:
	if not _is_lobby_host():
		if _is_lobby_leader() and _can_rpc():
			_rpc_request_begin_match.rpc_id(1)
		return
	_begin_match_as_host()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_begin_match() -> void:
	if not _is_lobby_host():
		return
	if multiplayer.get_remote_sender_id() != NetworkManager.lobby_leader_id:
		return
	if not _everyone_ready_to_start():
		return
	_begin_match_as_host()

func _begin_match_as_host() -> void:
	var seat_tokens: Dictionary = {}
	for peer_id in _peer_seats:
		var seat: int = int(_peer_seats[peer_id])
		var token: String = NetworkManager.peer_tokens.get(peer_id, "")
		if token != "":
			seat_tokens[token] = seat
	_rpc_begin_match.rpc(seat_tokens, GameLaunch.selected_map)

func _on_back_pressed() -> void:
	AudioManager.play("ui_back")
	if _is_networked_lobby():
		NetworkManager.disconnect_network()
		get_tree().change_scene_to_file(MULTIPLAYER_SETUP_PATH)
		return
	get_tree().change_scene_to_file(MODE_SELECT_PATH)

