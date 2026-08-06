extends Node
class_name LanBeaconScript


const DISCOVERY_PORT: int = 8911
const MAGIC: String = "tumbang-preso-lan"
const BEACON_INTERVAL: float = 1.0
const ENTRY_TIMEOUT: float = 4.0

signal servers_changed

var _advertiser: PacketPeerUDP = null
var _destinations: Array[String] = []
var _listener: PacketPeerUDP = null
var _since_beacon: float = 0.0
var _seen: Dictionary = {}
var _last_signature: String = ""

func _ready() -> void:
	set_process(true)


func start_advertising() -> void:
	stop_advertising()
	_advertiser = PacketPeerUDP.new()
	_advertiser.set_broadcast_enabled(true)
	_destinations = _broadcast_destinations()
	if _destinations.is_empty():
		push_warning("LanBeacon: no broadcast destination; this host is typed-address only.")
		_advertiser = null
		return
	_since_beacon = BEACON_INTERVAL

func _broadcast_destinations() -> Array[String]:
	var out: Array[String] = ["255.255.255.255"]
	for address in IP.get_local_addresses():
		if ":" in address:
			continue
		if address.begins_with("127."):
			continue
		var octets := address.split(".")
		if octets.size() != 4:
			continue
		var subnet := "%s.%s.%s.255" % [octets[0], octets[1], octets[2]]
		if not out.has(subnet):
			out.append(subnet)
	return out

func stop_advertising() -> void:
	if _advertiser != null:
		_advertiser.close()
		_advertiser = null


func start_listening() -> void:
	if _listener != null:
		return
	_listener = PacketPeerUDP.new()
	var err := _listener.bind(DISCOVERY_PORT, "*")
	if err != OK:
		push_warning("LanBeacon: cannot listen on %d (error %d); the LAN list will stay empty."
			% [DISCOVERY_PORT, err])
		_listener = null
		return
	_seen.clear()
	_last_signature = ""

func stop_listening() -> void:
	if _listener != null:
		_listener.close()
		_listener = null
	if not _seen.is_empty():
		_seen.clear()
		_last_signature = ""
		servers_changed.emit()

func is_listening() -> bool:
	return _listener != null

func servers() -> Array:
	var out: Array = []
	for key in _seen:
		out.append(_seen[key])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("in_match", false)) != bool(b.get("in_match", false)):
			return not bool(a.get("in_match", false))
		if int(a.get("players", 0)) != int(b.get("players", 0)):
			return int(a.get("players", 0)) < int(b.get("players", 0))
		return String(a.get("name", "")) < String(b.get("name", "")))
	return out

func _process(delta: float) -> void:
	_step_advertise(delta)
	_step_listen(delta)

func _step_advertise(delta: float) -> void:
	if _advertiser == null:
		return
	if not NetworkManager.is_host():
		stop_advertising()
		return
	_since_beacon += delta
	if _since_beacon < BEACON_INTERVAL:
		return
	_since_beacon = 0.0
	var payload := JSON.stringify({
		"magic": MAGIC,
		"version": GameVersion.string(),
		"code": NetworkManager.join_code,
		"port": NetworkManagerScript.DEFAULT_PORT,
		"name": _host_label(),
		"players": NetworkManager.seated_peer_count(),
		"max": NetworkManagerScript.MAX_PLAYERS,
		"in_match": NetworkManager.match_in_progress,
	}).to_utf8_buffer()
	for destination in _destinations:
		if _advertiser.set_dest_address(destination, DISCOVERY_PORT) != OK:
			continue
		_advertiser.put_packet(payload)

func _host_label() -> String:
	var who := GameLaunch.player_name().strip_edges()
	return "%s'S GAME" % who.to_upper() if not who.is_empty() else "A TUMBANG PRESO GAME"

func _step_listen(delta: float) -> void:
	if _listener == null:
		return
	while _listener.get_available_packet_count() > 0:
		var raw := _listener.get_packet()
		var from_ip := _listener.get_packet_ip()
		_ingest(raw, from_ip)
	_expire(delta)

func _ingest(raw: PackedByteArray, from_ip: String) -> void:
	if from_ip.is_empty():
		return
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var packet: Dictionary = parsed
	if String(packet.get("magic", "")) != MAGIC:
		return
	if String(packet.get("version", "")) != GameVersion.string():
		return
	var port := int(packet.get("port", NetworkManagerScript.DEFAULT_PORT))
	if port <= 0 or port > 65535:
		return
	var key := "%s:%d" % [from_ip, port]
	_seen[key] = {
		"ip": from_ip,
		"port": port,
		"name": String(packet.get("name", "A TUMBANG PRESO GAME")),
		"code": String(packet.get("code", "")),
		"players": int(packet.get("players", 0)),
		"max": int(packet.get("max", NetworkManagerScript.MAX_PLAYERS)),
		"in_match": bool(packet.get("in_match", false)),
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
		signature += "%s:%d|%s|%d/%d|%s\n" % [
			entry.get("ip", ""), int(entry.get("port", 0)), entry.get("name", ""),
			int(entry.get("players", 0)), int(entry.get("max", 0)),
			"m" if bool(entry.get("in_match", false)) else "l"]
	if signature == _last_signature:
		return
	_last_signature = signature
	servers_changed.emit()

