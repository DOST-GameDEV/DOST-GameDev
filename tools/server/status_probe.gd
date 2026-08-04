extends SceneTree
## DOES ONE LOBBY, ON ONE PORT, ANSWER? — a headless status query against a single
## dedicated server, printing the raw reply and exiting non-zero if nothing came back.
##
##     Godot_v4.7.1-stable_win64.exe --headless --path <repo> \
##         --script tools/server/status_probe.gd -- --host=127.0.0.1 --port=8980
##
## `--port=` is the GAME port, the same number you passed the server. The status
## socket is that plus ten (`ServerQuery.STATUS_PORT_OFFSET`) and this probe does
## the arithmetic for you, so the two numbers you type at a shell always match.
##
## ⚠️ WHY THIS EXISTS WHEN tools/ui/host_online_shot.gd ALREADY QUERIES A POOL.
## That harness drives the real HOST ONLINE screen, and the screen asks
## `ServerQuery` for the pool — whose range is the compile-time constants
## `POOL_PORT_FIRST`/`POOL_PORT_LAST` (8910-8917 at time of writing). A lobby on
## any other port is invisible to it, not broken. Verifying an export, or any
## one-off server, means asking a port outside that range, so this speaks the
## protocol directly instead of going through the screen.
##
## ⚠️ IT DEPENDS ON NOTHING IN scripts/. The magic string and version below are
## duplicated from `scripts/systems/server_query.gd` ON PURPOSE: this probe has to
## be able to interrogate an EXPORTED server, and a probe that imported the
## project's own autoloads would be testing this checkout's idea of the protocol
## against itself. If `MAGIC` or `PROTOCOL_VERSION` ever change, this file has to
## be edited by hand — that is the cost, and a probe that suddenly reports "no
## reply" against a server you know is up is the symptom.
##
## ⚠️ SceneTree SCRIPT, NOT A SCENE. `--script` with a SceneTree subclass gives a
## `_initialize`/`_process` pair with no window, no main scene and no autoloads —
## which is what makes the "depends on nothing" claim above true. A `.tscn`
## harness would boot the project, and booting the project on the same machine as
## the server under test is how you end up measuring the wrong process.

const MAGIC: String = "tumbang-preso-query"
const PROTOCOL_VERSION: int = 1
const STATUS_PORT_OFFSET: int = 10

## Long enough to cover a first-packet round trip on a real VM, short enough that a
## dead server is reported inside a shell prompt's worth of patience. Loopback
## answers in well under a frame; this budget is for the WAN case.
const TIMEOUT_SECONDS: float = 5.0

## ⚠️ RE-ASKED EVERY TICK, NOT SENT ONCE. UDP has no retransmit and the very first
## packet is the one most likely to be dropped — a single send that lands in a
## boot-time gap reports a healthy server as dead, which is the worst possible
## failure for a tool whose whole job is answering "is it up".
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
	# Port 0 is an ephemeral port from the OS. Binding is what makes this socket able
	# to RECEIVE the reply at all; the number is nobody's business, and pinning one
	# would collide with a second copy of this probe on the same machine.
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
			# Not ours. Say so rather than dropping it silently — on a busy box a
			# stray packet on this port is a real finding, not noise.
			print("status_probe: ignored a non-matching packet: %s" % text)
			continue
		print("status_probe: REPLY %s" % text)
		quit(0)
		return true
	if _elapsed >= TIMEOUT_SECONDS:
		printerr("status_probe: NO REPLY from %s:%d after %.1fs" % [_host, _game_port + STATUS_PORT_OFFSET, TIMEOUT_SECONDS])
		# ⚠️ A SILENT STATUS PORT DOES NOT MEAN A DEAD LOBBY. The game port and the
		# status port are two different sockets; check `ss -lun` / `netstat -an -p udp`
		# for BOTH before concluding anything. See §2 of
		# docs/Dedicated_Server_Deployment.md.
		quit(1)
		return true
	return false
