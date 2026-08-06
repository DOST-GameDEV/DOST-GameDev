extends Node
class_name ServerQueryScript


const MAGIC: String = "tumbang-preso-query"
const PROTOCOL_VERSION: int = 1

const STATUS_PORT_OFFSET: int = 10

const POOL_ADDRESS: String = "139.180.212.110"
const POOL_PORT_FIRST: int = 8910
const POOL_PORT_LAST: int = 8917

const QUERY_INTERVAL: float = 1.0
const ENTRY_TIMEOUT: float = 4.0

signal servers_changed

var pool_address: String = POOL_ADDRESS
var pool_ports: Array[int] = []

var _responder: PacketPeerUDP = null
var _game_port: int = 0

var _client: PacketPeerUDP = null
var _browsing: bool = false
var _since_query: float = 0.0
var _seen: Dictionary = {}
var _last_signature: String = ""

func _ready() -> void:
	if pool_ports.is_empty():
		for port in range(POOL_PORT_FIRST, POOL_PORT_LAST + 1):
			pool_ports.append(port)
	_read_pool_override()
	set_process(true)

func _read_pool_override() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pool="):
			pool_address = arg.substr(len("--pool=")).strip_edges()
			print("ServerQuery: pool address overridden to '%s' for this run." % pool_address)

static func status_port_for(game_port: int) -> int:
	return game_port + STATUS_PORT_OFFSET


func start_responding(game_port: int) -> void:
	stop_responding()
	_game_port = game_port
	var status_port := status_port_for(game_port)
	var socket := PacketPeerUDP.new()
	var err := socket.bind(status_port, "*")
	if err != OK:
		push_warning("ServerQuery: cannot bind status port %d (error %d); this server will not be listed."
			% [status_port, err])
		return
	_responder = socket

func stop_responding() -> void:
	if _responder != null:
		_responder.close()
		_responder = null
	_game_port = 0

func is_responding() -> bool:
	return _responder != null


func start_browsing() -> void:
	_browsing = true
	query_pool()

func stop_browsing() -> void:
	_browsing = false
	if _client != null:
		_client.close()
		_client = null
	if not _seen.is_empty():
		_seen.clear()
		_last_signature = ""
		servers_changed.emit()

func is_browsing() -> bool:
	return _browsing

func query_pool() -> void:
	if pool_address.strip_edges().is_empty():
		return
	if _client == null:
		var socket := PacketPeerUDP.new()
		var err := socket.bind(0, "*")
		if err != OK:
			push_warning("ServerQuery: cannot open a query socket (error %d); the online list will stay empty." % err)
			return
		_client = socket
	var payload := JSON.stringify({
		"magic": MAGIC,
		"v": PROTOCOL_VERSION,
	}).to_utf8_buffer()
	for game_port in pool_ports:
		if _client.set_dest_address(pool_address, status_port_for(game_port)) != OK:
			continue
		_client.put_packet(payload)


const SPAWN_PORT: int = POOL_PORT_FIRST - 1

func request_lobby() -> void:
	if pool_address.strip_edges().is_empty():
		return
	if _client == null:
		var socket := PacketPeerUDP.new()
		if socket.bind(0, "*") != OK:
			return
		_client = socket
	if _client.set_dest_address(pool_address, SPAWN_PORT) != OK:
		return
	_client.put_packet(JSON.stringify({
		"magic": MAGIC,
		"v": PROTOCOL_VERSION,
		"op": "spawn",
	}).to_utf8_buffer())

func servers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in _seen:
		out.append(_seen[key])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("in_progress", false)) != bool(b.get("in_progress", false)):
			return not bool(a.get("in_progress", false))
		if int(a.get("players", 0)) != int(b.get("players", 0)):
			return int(a.get("players", 0)) < int(b.get("players", 0))
		return String(a.get("code", "")) < String(b.get("code", "")))
	return out

func resolve_code(code: String) -> String:
	var wanted := code.strip_edges().to_upper()
	if wanted.is_empty():
		return ""
	for entry in LanBeacon.servers():
		if String(entry.get("code", "")).to_upper() == wanted:
			return "%s:%d" % [String(entry.get("ip", "")), int(entry.get("port", 0))]
	for entry in servers():
		if String(entry.get("code", "")).to_upper() == wanted:
			return "%s:%d" % [String(entry.get("ip", "")), int(entry.get("port", 0))]
	return ""

func _process(delta: float) -> void:
	_step_respond()
	_step_browse(delta)


func _step_respond() -> void:
	if _responder == null:
		return
	while _responder.get_available_packet_count() > 0:
		var raw := _responder.get_packet()
		var from_ip := _responder.get_packet_ip()
		var from_port := _responder.get_packet_port()
		if from_ip.is_empty() or from_port <= 0:
			continue
		if not _is_query(raw):
			continue
		if _responder.set_dest_address(from_ip, from_port) != OK:
			continue
		_responder.put_packet(_status_payload())

func _is_query(raw: PackedByteArray) -> bool:
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary):
		return false
	var packet: Dictionary = parsed
	if String(packet.get("magic", "")) != MAGIC:
		return false
	return int(packet.get("v", 0)) == PROTOCOL_VERSION

func _status_payload() -> PackedByteArray:
	return JSON.stringify({
		"magic": MAGIC,
		"v": PROTOCOL_VERSION,
		"code": NetworkManager.join_code,
		"port": _game_port,
		"players": NetworkManager.seated_peer_count(),
		"occupied": NetworkManager.connected_peer_ids.size(),
		"max": NetworkManagerScript.MAX_PLAYERS,
		"map": String(GameLaunch.selected_map),
		"in_progress": NetworkManager.match_in_progress,
	}).to_utf8_buffer()

func _step_browse(delta: float) -> void:
	if _client != null:
		while _client.get_available_packet_count() > 0:
			var raw := _client.get_packet()
			var from_ip := _client.get_packet_ip()
			_ingest_reply(raw, from_ip)
	if not _browsing:
		return
	_since_query += delta
	if _since_query >= QUERY_INTERVAL:
		_since_query = 0.0
		query_pool()
	_expire(delta)

func _ingest_reply(raw: PackedByteArray, from_ip: String) -> void:
	if from_ip.is_empty():
		return
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var packet: Dictionary = parsed
	if String(packet.get("magic", "")) != MAGIC:
		return
	if int(packet.get("v", 0)) != PROTOCOL_VERSION:
		return
	if packet.has("op"):
		return
	var port := int(packet.get("port", 0))
	if port <= 0 or port > 65535:
		return
	var key := "%s:%d" % [from_ip, port]
	_seen[key] = {
		"ip": from_ip,
		"port": port,
		"code": String(packet.get("code", "")).to_upper(),
		"players": int(packet.get("players", 0)),
		"occupied": int(packet.get("occupied", packet.get("players", 0))),
		"max": int(packet.get("max", NetworkManagerScript.MAX_PLAYERS)),
		"map": String(packet.get("map", "")),
		"in_progress": bool(packet.get("in_progress", false)),
		"age": 0.0,
	}
	_emit_if_changed()

func _expire(delta: float) -> void:
	var dropped := false
	for key in _seen.keys():
		var entry: Dictionary = _seen[key]
		entry["age"] = float(entry.get("age", 0.0)) + delta
		if float(entry["age"]) >= ENTRY_TIMEOUT:
			_seen.erase(key)
			dropped = true
	if dropped:
		_emit_if_changed()

func _emit_if_changed() -> void:
	var signature := ""
	for entry in servers():
		signature += "%s:%d|%s|%d/%d|%s|%s\n" % [
			String(entry.get("ip", "")), int(entry.get("port", 0)), String(entry.get("code", "")),
			int(entry.get("players", 0)), int(entry.get("max", 0)), String(entry.get("map", "")),
			"m" if bool(entry.get("in_progress", false)) else "l"]
	if signature == _last_signature:
		return
	_last_signature = signature
	servers_changed.emit()

