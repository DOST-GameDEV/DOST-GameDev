extends Node
class_name NetworkManagerScript


signal server_created
signal connection_succeeded
signal connection_failed
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_disconnected
signal player_identified(peer_id: int, token: String)
signal peer_spectator_changed(peer_id: int, spectating: bool)
signal provisional_spectator_changed(spectating: bool)

const DEFAULT_PORT: int = 8910
const MAX_PLAYERS: int = 4
const MAX_CONNECTIONS: int = 12
const MAIN_SCENE_PATH: String = "res://scenes/main/Main.tscn"
const MULTIPLAYER_SETUP_PATH: String = "res://scenes/ui/MultiplayerSetup.tscn"
const ENET_TIMEOUT_LIMIT: int = 32
const ENET_TIMEOUT_MIN: int = 10000
const ENET_TIMEOUT_MAX: int = 45000
const TOKEN_SAVE_PATH: String = "user://player_identity.cfg"
const JOIN_CODE_ALPHABET: String = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
const JOIN_CODE_LENGTH: int = 4

var connected_peer_ids: Array[int] = []
var local_player_token: String = ""
var peer_tokens: Dictionary = {}
var peer_characters: Dictionary = {}
var local_picks: Dictionary = {"character": -1, "can": -1, "slipper": -1, "name": ""}

func picks_for(peer_id: int) -> Dictionary:
	return peer_characters.get(peer_id,
		{"character": -1, "can": -1, "slipper": -1, "spectator": 0, "name": ""})

func is_spectator(peer_id: int) -> bool:
	return int(picks_for(peer_id).get("spectator", 0)) != 0

func publish_spectator(spectating: bool) -> void:
	local_picks["spectator"] = 1 if spectating else 0
	if not is_networked():
		return
	if is_host():
		_apply_spectator(multiplayer.get_unique_id(), spectating)
		return
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_rpc_set_spectator.rpc_id(1, spectating)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_spectator(spectating: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if is_host():
		_apply_spectator(sender, spectating)
		return
	if sender != 1:
		return
	provisional_spectator = spectating
	provisional_spectator_changed.emit(spectating)

func _apply_spectator(peer_id: int, spectating: bool) -> void:
	var picks: Dictionary = peer_characters.get(peer_id,
		{"character": -1, "can": -1, "slipper": -1, "spectator": 0})
	picks["spectator"] = 1 if spectating else 0
	peer_characters[peer_id] = picks
	peer_spectator_changed.emit(peer_id, spectating)

func publish_picks() -> void:
	local_picks["character"] = GameLaunch.character_index()
	local_picks["can"] = GameLaunch.can_index()
	local_picks["slipper"] = GameLaunch.slipper_index()
	if not is_networked():
		return
	if is_host():
		_apply_picks(multiplayer.get_unique_id(),
			local_picks["character"], local_picks["can"], local_picks["slipper"])
		return
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_rpc_set_picks.rpc_id(1, local_picks["character"], local_picks["can"], local_picks["slipper"])

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_picks(character: int, can: int, slipper: int) -> void:
	if not is_host():
		return
	_apply_picks(multiplayer.get_remote_sender_id(), character, can, slipper)

func _apply_picks(peer_id: int, character: int, can: int, slipper: int) -> void:
	var picks: Dictionary = peer_characters.get(peer_id,
		{"character": -1, "can": -1, "slipper": -1, "spectator": 0, "name": ""})
	picks["character"] = character
	picks["can"] = can
	picks["slipper"] = slipper
	peer_characters[peer_id] = picks

func is_seatless_referee(peer_id: int) -> bool:
	return is_dedicated and peer_id == 1

func playing_peer_count() -> int:
	var count := 0
	for peer_id in connected_peer_ids:
		if is_seatless_referee(peer_id):
			continue
		if peer_id == multiplayer.get_unique_id() or not is_spectator(peer_id):
			count += 1
	return maxi(1, count)

func seated_peer_count() -> int:
	return seated_peer_ids().size()

func seated_peer_ids() -> Array[int]:
	var ids: Array[int] = []
	for peer_id in connected_peer_ids:
		if is_seatless_referee(peer_id):
			continue
		if not is_spectator(peer_id):
			ids.append(peer_id)
	return ids

func _local_picks() -> Dictionary:
	return {
		"character": GameLaunch.character_index(),
		"can": GameLaunch.can_index(),
		"slipper": GameLaunch.slipper_index(),
		"name": GameLaunch.player_name(),
		"spectator": 1 if GameLaunch.spectator else 0,
	}
var match_in_progress: bool = false
var rerouting_to_running_match: bool = false


enum MidMatchRuling { RETURNING, SPECTATING, WAITING, REFUSED }

const MATCH_FULL_MESSAGE: String = "Match already started — every open seat is taken. Try again when it ends."

var waiting_seat_tokens: Array[String] = []

var provisional_spectator: bool = false
var _is_networked: bool = false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	local_player_token = _load_or_create_token()


var is_dedicated: bool = false

const DEDICATED_MAX_FPS: int = 60

var join_code: String = ""

func _mint_join_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var code := ""
	for i in range(JOIN_CODE_LENGTH):
		code += JOIN_CODE_ALPHABET[rng.randi_range(0, JOIN_CODE_ALPHABET.length() - 1)]
	return code


signal join_code_changed(code: String)
signal lobby_leader_changed(peer_id: int)

var lobby_leader_id: int = 0

func is_lobby_leader() -> bool:
	return _is_networked and lobby_leader_id == multiplayer.get_unique_id()

func _set_lobby_leader(peer_id: int) -> void:
	if not is_host() or lobby_leader_id == peer_id:
		return
	_rpc_announce_leader.rpc(peer_id)

func _claim_lobby_leader_if_vacant(peer_id: int) -> void:
	if not is_host():
		return
	if lobby_leader_id == 0:
		_set_lobby_leader(peer_id)
	else:
		_rpc_announce_leader.rpc_id(peer_id, lobby_leader_id)

func _reassign_leader(departed_id: int) -> void:
	if not is_host() or lobby_leader_id != departed_id:
		return
	for candidate in connected_peer_ids:
		if candidate != departed_id:
			_rpc_announce_leader.rpc(candidate)
			return
	_rpc_announce_leader.rpc(0)

@rpc("authority", "call_local", "reliable")
func _rpc_announce_leader(peer_id: int) -> void:
	lobby_leader_id = peer_id
	lobby_leader_changed.emit(peer_id)

func host_game(port: int = DEFAULT_PORT, dedicated: bool = false) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CONNECTIONS)
	if err != OK:
		push_error("NetworkManager: failed to host on port %d (error %d)" % [port, err])
		return err
	multiplayer.multiplayer_peer = peer
	_is_networked = true
	is_dedicated = dedicated
	if dedicated:
		Engine.max_fps = DEDICATED_MAX_FPS
	peer_tokens.clear()
	peer_characters.clear()
	if dedicated:
		connected_peer_ids = []
		lobby_leader_id = 0
	else:
		connected_peer_ids = [multiplayer.get_unique_id()]
		lobby_leader_id = multiplayer.get_unique_id()
		peer_tokens[multiplayer.get_unique_id()] = local_player_token
		local_picks = _local_picks()
		peer_characters[multiplayer.get_unique_id()] = local_picks
	match_in_progress = false
	waiting_seat_tokens.clear()
	provisional_spectator = false
	rerouting_to_running_match = false
	join_code = _mint_join_code()
	join_code_changed.emit(join_code)
	ServerQuery.start_responding(port)
	LanBeacon.start_advertising()
	server_created.emit()
	return OK

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	rerouting_to_running_match = false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("NetworkManager: failed to connect to %s:%d (error %d)" % [address, port, err])
		return err
	multiplayer.multiplayer_peer = peer
	_is_networked = true
	return OK

func announce_host_leaving() -> void:
	if not is_host():
		return
	_rpc_host_closing.rpc()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame
		await tree.process_frame

@rpc("authority", "call_remote", "reliable")
func _rpc_host_closing() -> void:
	if is_host():
		return
	_on_server_disconnected()

func disconnect_network() -> void:
	LanBeacon.stop_advertising()
	ServerQuery.stop_responding()
	join_code = ""
	join_code_changed.emit("")
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	connected_peer_ids.clear()
	_is_networked = false
	is_dedicated = false
	lobby_leader_id = 0
	peer_tokens.clear()
	peer_characters.clear()
	match_in_progress = false
	waiting_seat_tokens.clear()

func is_networked() -> bool:
	return _is_networked

func is_host() -> bool:
	return is_networked() and multiplayer.is_server()

func is_solo_session() -> bool:
	return is_networked() and connected_peer_ids.size() <= 1

func _on_peer_connected(id: int) -> void:
	if not connected_peer_ids.has(id):
		connected_peer_ids.append(id)
	_apply_peer_timeout.call_deferred(id)
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	connected_peer_ids.erase(id)
	_reassign_leader(id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	connected_peer_ids = [multiplayer.get_unique_id()]
	_apply_peer_timeout.call_deferred(1)
	local_picks = _local_picks()
	_rpc_identify.rpc_id(1, local_player_token, local_picks)
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	_is_networked = false
	connection_failed.emit()

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	connected_peer_ids.clear()
	_is_networked = false
	is_dedicated = false
	peer_tokens.clear()
	peer_characters.clear()
	match_in_progress = false
	waiting_seat_tokens.clear()
	if not rerouting_to_running_match:
		provisional_spectator = false
	server_disconnected.emit()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_identify(token: String, picks: Dictionary = {}) -> void:
	if not is_host():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var was_here := _token_was_in_this_match(token)
	peer_tokens[peer_id] = token
	peer_characters[peer_id] = {
		"character": _validated(picks, "character", CharacterRoster.ROSTER.size()),
		"can": _validated(picks, "can", CharacterRoster.CANS.size()),
		"slipper": _validated(picks, "slipper", CharacterRoster.SLIPPERS.size()),
		"spectator": 1 if int(picks.get("spectator", 0)) != 0 else 0,
		"name": SettingsManagerScript.sanitise_name(String(picks.get("name", ""))),
	}
	if match_in_progress:
		var ruling := _rule_on_mid_match_arrival(token, peer_id, was_here)
		if ruling == MidMatchRuling.REFUSED:
			peer_tokens.erase(peer_id)
			peer_characters.erase(peer_id)
			_rpc_route_to_running_match.rpc_id(peer_id, MATCH_FULL_MESSAGE)
			return
		if ruling == MidMatchRuling.WAITING:
			_apply_spectator(peer_id, true)
			_rpc_set_spectator.rpc_id(peer_id, true)
		_rpc_route_to_running_match.rpc_id(peer_id)
	peer_spectator_changed.emit(peer_id, is_spectator(peer_id))
	_claim_lobby_leader_if_vacant(peer_id)
	_rpc_announce_join_code.rpc_id(peer_id, join_code)
	_rpc_announce_dedicated.rpc_id(peer_id, is_dedicated)
	player_identified.emit(peer_id, token)

func _rule_on_mid_match_arrival(token: String, peer_id: int, was_here: bool) -> MidMatchRuling:
	if waiting_seat_tokens.has(token):
		return MidMatchRuling.WAITING
	if int(picks_for(peer_id).get("spectator", 0)) != 0:
		return MidMatchRuling.SPECTATING
	if was_here:
		return MidMatchRuling.RETURNING
	if waiting_seat_tokens.size() < free_seat_count():
		waiting_seat_tokens.append(token)
		return MidMatchRuling.WAITING
	return MidMatchRuling.REFUSED

func _token_was_in_this_match(token: String) -> bool:
	if token == "":
		return false
	if GameLaunch.seat_tokens.has(token):
		return true
	for id in peer_tokens:
		if String(peer_tokens[id]) == token:
			return true
	return false

func free_seat_count() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 0
	var scene: Node = tree.current_scene
	if scene == null or not scene.has_method("free_seat_count"):
		return 0
	return int(scene.call("free_seat_count"))

func peer_id_for_token(token: String) -> int:
	for id in peer_tokens:
		if String(peer_tokens[id]) == token and connected_peer_ids.has(int(id)):
			return int(id)
	return 0

func take_promotable_tokens(limit: int) -> Array[String]:
	var out: Array[String] = []
	var kept: Array[String] = []
	for token in waiting_seat_tokens:
		if out.size() < limit and peer_id_for_token(token) != 0:
			out.append(token)
		elif peer_id_for_token(token) != 0:
			kept.append(token)
	waiting_seat_tokens = kept
	return out

func seat_provisional_spectator(peer_id: int) -> void:
	if not is_host():
		return
	_apply_spectator(peer_id, false)
	_rpc_set_spectator.rpc_id(peer_id, false)

@rpc("authority", "call_remote", "reliable")
func _rpc_announce_join_code(code: String) -> void:
	join_code = code
	join_code_changed.emit(code)

@rpc("authority", "call_remote", "reliable")
func _rpc_announce_dedicated(dedicated: bool) -> void:
	is_dedicated = dedicated

func _validated(picks: Dictionary, key: String, count: int) -> int:
	var value := int(picks.get(key, -1))
	return value if value >= 0 and value < count else -1

@rpc("authority", "call_remote", "reliable")
func _rpc_route_to_running_match(refusal: String = "") -> void:
	if refusal != "":
		rerouting_to_running_match = true
		disconnect_network()
		GameLaunch.reset()
		GameLaunch.pending_status_message = refusal
		get_tree().change_scene_to_file(MULTIPLAYER_SETUP_PATH)
		return
	var current := get_tree().current_scene
	if current != null and current.scene_file_path == MAIN_SCENE_PATH:
		return
	rerouting_to_running_match = true
	disconnect_network()
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

func _load_or_create_token() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var token := "%08x%08x%08x%08x" % [rng.randi(), rng.randi(), rng.randi(), rng.randi()]
	var cfg := ConfigFile.new()
	cfg.set_value("identity", "token", token)
	var err := cfg.save(TOKEN_SAVE_PATH)
	if err != OK:
		push_warning("NetworkManager: could not write player token to disk (error %d) â€” harmless, it is never read back; see local_player_token's own doc." % err)
	return token

func _apply_peer_timeout(peer_id: int) -> void:
	var enet_peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet_peer == null:
		return
	var packet_peer := enet_peer.get_peer(peer_id)
	if packet_peer != null:
		packet_peer.set_timeout(ENET_TIMEOUT_LIMIT, ENET_TIMEOUT_MIN, ENET_TIMEOUT_MAX)

