extends SceneTree

const MAGIC: String = "tumbang-preso-query"
const PROTOCOL_VERSION: int = 1
const STATUS_PORT_OFFSET: int = 10

const TIMEOUT_SECONDS: float = 5.0

const RESEND_INTERVAL: float = 0.5

var _socket: PacketPeerUDP = null
var _host: String = "127.0.0.1"
var _game_port: int = 0
var _elapsed: float = 0.0
var _since_send: float = 999.0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--host="):
			_host = arg.trim_prefix("--host=")
		elif arg.begins_with("--port="):
			_game_port = int(arg.trim_prefix("--port="))
	if _game_port <= 0 or _game_port > 65535:
		printerr("status_probe: need --port=<game port>, e.g. -- --host=127.0.0.1 --port=8980")
		quit(2)
		return
	_socket = PacketPeerUDP.new()
	if _socket.bind(0, "*") != OK:
		printerr("status_probe: cannot open a UDP socket")
		quit(3)
		return
	print("status_probe: querying %s game=%d status=%d" % [_host, _game_port, _game_port + STATUS_PORT_OFFSET])

func _process(delta: float) -> bool:
	_elapsed += delta
	_since_send += delta
	if _since_send >= RESEND_INTERVAL:
		_since_send = 0.0
		if _socket.set_dest_address(_host, _game_port + STATUS_PORT_OFFSET) == OK:
			_socket.put_packet(JSON.stringify({
				"magic": MAGIC,
				"v": PROTOCOL_VERSION,
			}).to_utf8_buffer())
	while _socket.get_available_packet_count() > 0:
		var raw: PackedByteArray = _socket.get_packet()
		var text: String = raw.get_string_from_utf8()
		var parsed = JSON.parse_string(text)
		if not (parsed is Dictionary) or String((parsed as Dictionary).get("magic", "")) != MAGIC:
			print("status_probe: ignored a non-matching packet: %s" % text)
			continue
		print("status_probe: REPLY %s" % text)
		quit(0)
		return true
	if _elapsed >= TIMEOUT_SECONDS:
		printerr("status_probe: NO REPLY from %s:%d after %.1fs" % [_host, _game_port + STATUS_PORT_OFFSET, TIMEOUT_SECONDS])
		quit(1)
		return true
	return false

