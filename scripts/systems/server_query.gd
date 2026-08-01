extends Node
class_name ServerQueryScript

## ONLINE LOBBY LIST AND JOIN CODES — the status protocol every dedicated server answers
## for itself. Players need two things the LAN browser cannot give them: a list of what is
## running on the online pool, and a short code they can read down a phone to a friend.
##
## Online play is a FIXED POOL of dedicated processes on one VM — several copies of the
## game, each bound to its own port, each refereeing exactly one match (see
## `NetworkManager.host_game`'s ⚠️ ONE PROCESS IS STILL ONE MATCH: `RoundManager` and
## `MatchManager` are autoloads and hold one score and one timer between them). This file
## is how a client finds out what those processes are doing. Plain UDP unicast, beside
## ENet and never on top of it — a build that cannot reach the status ports still plays
## exactly as before by typing an address, which is how this game worked first.
##
## ---------------------------------------------------------------------------
## ⚠️⚠️ THERE IS NO REGISTRY. EVERY SERVER ANSWERS FOR ITSELF, AND CODES ARE RESOLVED BY
## ASKING ALL OF THEM.
##
## The obvious design is a master list: one process the servers report into and the
## clients read out of. That is another thing to deploy, another thing to keep alive, and
## the single point whose death takes online mode down while eight perfectly healthy match
## servers sit there answering nobody. The pool here is EIGHT PORTS ON ONE KNOWN ADDRESS —
## small enough and static enough that a client can simply ask every one of them, in eight
## datagrams, and assemble the list itself. A join code is resolved the same way: nothing
## anywhere maps codes to servers, the client asks each server what ITS code is and keeps
## the one that matches.
##
## The price is that the pool is a CONSTANT in this file rather than a lookup, so growing
## it ships a build. That is the trade, and at eight servers it is the right one.
##
## ⚠️⚠️ THE ADDRESS COMES FROM THE PACKET, NOT FROM THE PAYLOAD. Same rule as
## `lan_beacon.gd`, and for the reason its header spells out at length: a host cannot
## reliably know its own address. `IP.get_local_addresses()` on a machine here returns the
## LAN card, a Hamachi 25.x, a Radmin 26.x and a couple of link-local 169.254s in an order
## nothing promises — and a VM is WORSE, because the address it knows is the private one
## inside the provider's network while clients arrive on a public one it was never told
## about. The RECEIVER has no such problem: `PacketPeerUDP.get_packet_ip()` is the source
## of the datagram that actually arrived, which is by construction an address that carries
## traffic between these two machines. So the reply carries the PORT — which a server does
## know, it bound it — and the client supplies the host half from the envelope. Anything
## that later "helpfully" puts an address in the payload has put the bug back.
## ---------------------------------------------------------------------------

## Marks a packet as ours before anything else is parsed. A stray datagram on a UDP port
## is not an error worth logging, it is simply not for us.
const MAGIC: String = "tumbang-preso-query"
## Protocol version, bumped when the SHAPE of these packets changes. Both ends check it:
## a client that cannot read a reply must ignore it rather than draw half a row, and a
## server must not answer a query it does not understand.
##
## ⚠️ NOT THE GAME VERSION, and deliberately not carrying one either. `lan_beacon.gd` gates
## on `GameVersion.string()` because a LAN can hold two people on two different builds; the
## pool is eight processes deployed together from one build, so the game version is a
## constant across every server a client can reach here and a field for it would only be a
## field to get wrong.
const PROTOCOL_VERSION: int = 1

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE STATUS PORT IS THE GAME PORT + 10, AND THAT SPACING IS WHAT BOUNDS THE POOL AT
## TEN PROCESSES. ENet owns the game port and a second socket on it would fight the server
## for its own datagrams. +1 is already spoken for — `LanBeaconScript.DISCOVERY_PORT` is
## 8911, which inside this pool is a GAME port — so the status range has to clear the whole
## pool rather than sit next to it: games 8910-8917 answer on 8920-8927.
##
## ⚠️ A POOL GROWN PAST TEN PORTS COLLIDES WITH ITSELF. Game port 8920 would want the
## status port that 8910 already holds, and the eleventh server would silently answer for
## the first. Widen this offset BEFORE widening the pool.
## ---------------------------------------------------------------------------
const STATUS_PORT_OFFSET: int = 10

## ⚠️ EMPTY BECAUSE THE VM DOES NOT EXIST YET — FILLED IN AT DEPLOYMENT with the address
## (or DNS name) the pool is actually reachable at from the outside. Empty means
## `query_pool()` sends nothing and the online list stays empty, which is the honest state
## for a build with nowhere to point. It must never be inferred at runtime from this
## machine's own interfaces: that is precisely the mistake the header's ⚠️⚠️ describes.
const POOL_ADDRESS: String = ""
## The pool's game ports, inclusive. One process per port, one match per process. Status
## ports are these + `STATUS_PORT_OFFSET`, so this range must stay within ten of its start.
const POOL_PORT_FIRST: int = 8910
const POOL_PORT_LAST: int = 8917

## How often `start_browsing()` re-asks the pool. Fast enough that a lobby filling up is
## visible about as quickly as a player can read the screen, slow enough that eight tiny
## datagrams a second are invisible next to ENet's own traffic.
const QUERY_INTERVAL: float = 1.0
## ⚠️ FOUR QUERIES, NOT ONE — the same reasoning as `LanBeaconScript.ENTRY_TIMEOUT`. A
## server that has gone down must lose its row, but a single dropped datagram is ordinary
## on UDP and must not blink a row out from under a cursor that is about to click it.
const ENTRY_TIMEOUT: float = 4.0

## Emitted when the visible list actually CHANGES — not once per received reply. A server
## answering every second with identical numbers is not a change, and repainting on it
## would fight the mouse for the row under the cursor.
signal servers_changed

## ---------------------------------------------------------------------------
## § WHAT IS ACTUALLY QUERIED. Seeded from the consts above rather than read from them at
## the send site, so a probe — or a LAN party running the pool off somebody's spare PC —
## can aim at 127.0.0.1 and a spare port range without editing a shipped constant.
## Deployment fills the CONST; nothing in the game itself writes these.
## ---------------------------------------------------------------------------
var pool_address: String = POOL_ADDRESS
var pool_ports: Array[int] = []

## § SERVER SIDE — one socket, bound, started by `NetworkManager.host_game()`.
var _responder: PacketPeerUDP = null
## The GAME port this process hosted on. Reported in every reply, because it is the half of
## the address a server does legitimately know; see the header's ⚠️⚠️.
var _game_port: int = 0

## § CLIENT SIDE.
var _client: PacketPeerUDP = null
var _browsing: bool = false
var _since_query: float = 0.0
## "ip:game_port" -> {ip, port, code, players, max, map, in_progress, age}
var _seen: Dictionary = {}
## The row fingerprint the last `servers_changed` was emitted for — see the signal's doc.
var _last_signature: String = ""

func _ready() -> void:
	if pool_ports.is_empty():
		for port in range(POOL_PORT_FIRST, POOL_PORT_LAST + 1):
			pool_ports.append(port)
	_read_pool_override()
	set_process(true)

## ---------------------------------------------------------------------------
## § TESTING THE POOL WITHOUT A POOL — `--pool=127.0.0.1`
##
## `POOL_ADDRESS` is empty until a VM exists, which means a developer cannot see the
## server browser work at all without editing a const and remembering to put it back.
## That is precisely the kind of edit that gets committed by accident, so the override
## is a command-line argument instead:
##
##     godot --path . -- --pool=127.0.0.1
##
## Then start some lobbies locally (`tools/server/lobby-pool.ps1 start 2`) and the
## browser lists them, join codes and all — the whole online path, on one machine, with
## nobody else online.
##
## ⚠️ DELIBERATELY NOT A SETTING. It is not a preference a player should ever have, and
## a saved value would outlive the test session it was meant for and quietly point a
## shipped build at somebody's old localhost.
## ---------------------------------------------------------------------------
func _read_pool_override() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pool="):
			pool_address = arg.substr(len("--pool=")).strip_edges()
			print("ServerQuery: pool address overridden to '%s' for this run." % pool_address)

## The port a server on `game_port` answers status queries on. One function, used by both
## ends, so the two can never disagree about where the conversation happens.
static func status_port_for(game_port: int) -> int:
	return game_port + STATUS_PORT_OFFSET

## ---------------------------------------------------------------------------
## § ANSWERING — the server half. Started by `NetworkManager.host_game()` and stopped by
## `disconnect_network()`, exactly where `LanBeacon` is started and stopped and for the
## same reason: those are the two lines that know whether a server exists.
## ---------------------------------------------------------------------------

## ⚠️ FAILURE IS SILENT AND DELIBERATELY NOT FATAL, same rule as `LanBeacon`. A bound
## status port is a convenience — the lobby is still reachable by a typed address and by
## its LAN beacon — and a server that cannot open it must still referee its match.
## `push_warning`, never `push_error`, and no return value a caller is tempted to branch on.
##
## ⚠️ IT DOES NOT TOUCH ENET. This is a separate UDP socket on a different port; the game
## port is left entirely to `ENetMultiplayerPeer`, which is the one thing that must not be
## disturbed by a feature whose whole job is answering questions about it.
##
## ⚠️ NOT GATED ON `NetworkManager.is_dedicated`. The pool is dedicated, but "what is this
## server doing" is the same question with the same answer on a listen host, and gating it
## would mean the only code path that ever runs it is the one nobody can test without a VM.
func start_responding(game_port: int) -> void:
	stop_responding()
	_game_port = game_port
	var status_port := status_port_for(game_port)
	var socket := PacketPeerUDP.new()
	# "*" binds every interface: a VM with a public NIC and a private one has no way to
	# guess in advance which of them a player's packet will arrive on.
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

## ---------------------------------------------------------------------------
## § ASKING — the client half.
## ---------------------------------------------------------------------------

## Starts re-asking the pool every `QUERY_INTERVAL` until `stop_browsing()`. The repetition
## is what makes `ENTRY_TIMEOUT` meaningful: a row survives four missed answers and no more,
## so a server that dies disappears and a server that drops one datagram does not.
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

## One query to every configured server. Usable on its own — a manual REFRESH press, or a
## probe — which is why it opens the socket itself rather than assuming `start_browsing()`
## ran first.
##
## ⚠️ ONE SOCKET FOR THE WHOLE POOL, AND DELIBERATELY NO `connect_to_host()`. That call
## filters the socket down to a single remote peer, which is exactly wrong here: the entire
## point is eight different servers answering on one socket. `set_dest_address` is a
## property of the socket rather than an argument to the send, so it is set immediately
## before each `put_packet` — setting it once outside the loop would post every query to
## the last address in the list.
func query_pool() -> void:
	if pool_address.strip_edges().is_empty():
		# Not a warning: a build whose pool address has not been filled in yet is the
		# normal state before deployment, and an empty list already says so.
		return
	if _client == null:
		var socket := PacketPeerUDP.new()
		# Port 0 asks the OS for a free ephemeral port. Binding at all is what lets this
		# socket RECEIVE the replies; the number itself is nobody's business but the OS's,
		# and pinning one would collide with a second copy of the game on this machine.
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

## Every server that has answered recently, best row first: lobbies you can still get a seat
## in, then fuller ones, then in code order so the list does not shuffle under the mouse.
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

## "host:port" for `code`, or "" if no server currently answering claims it. The string is
## shaped for `main_menu.gd`'s existing typed-address path — the code box resolves to an
## address and then joins exactly like a typed one, so there is no second connect path.
##
## ⚠️ IT READS THE TABLE, IT DOES NOT ASK THE POOL. Resolution is only as fresh as the last
## `query_pool()`, so a caller must have browsed for at least one round-trip before a code
## can possibly match — a code box that resolves on the first keystroke will find nothing
## and must not report that as "wrong code".
##
## ⚠️ CASE-FOLDED, BECAUSE THE CODE IS READ ALOUD. Somebody typing "a7sf" has typed the
## right code; the alphabet is upper-case only (see `NetworkManagerScript.JOIN_CODE_ALPHABET`)
## so folding up is lossless.
##
## ⚠️ FIRST MATCH WINS AND A COLLISION IS POSSIBLE. Nothing coordinates minting — that is
## the point of having no registry — so two of the eight servers CAN roll the same code.
## 31^4 is 923 521 and eight servers make 28 pairs, so it happens about three times in a
## hundred thousand deployments and costs one player a wrong lobby, not a crash. Detecting
## it would need the very central authority this design exists to avoid.
## ⚠️ SEARCHES THE LAN AS WELL AS THE POOL, and the LAN comes FIRST.
##
## A code is one handle for "the game my friend is in", and a player has no idea
## whether that game is a pool server or somebody's PC across the room — so a code that
## only worked for one of the two would be a code that mysteriously works half the time.
## `LanBeacon` carries the same code in its broadcast for exactly this.
##
## LAN first because it is the cheaper and more certain answer: a beacon that has already
## been heard is a machine known to be reachable from here, whereas a pool entry may be
## on the far side of an internet path. On the vanishingly unlikely collision (31^4 across
## one LAN plus eight servers) the near one is also the better guess.
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

## ---------------------------------------------------------------------------
## § THE WIRE.
## ---------------------------------------------------------------------------

func _step_respond() -> void:
	if _responder == null:
		return
	while _responder.get_available_packet_count() > 0:
		var raw := _responder.get_packet()
		# ⚠️ READ THE ENVELOPE BEFORE THE BODY. `get_packet_ip()`/`get_packet_port()`
		# describe the packet just taken and are overwritten by the next `get_packet()`, so
		# reading them after parsing would answer one client at another one's address.
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

## What this server says about itself. Read live, once per query, rather than cached: the
## numbers a player is deciding on are the numbers as of the moment they asked.
func _status_payload() -> PackedByteArray:
	return JSON.stringify({
		"magic": MAGIC,
		"v": PROTOCOL_VERSION,
		"code": NetworkManager.join_code,
		# The port, and nothing else about how to reach this process — see the header.
		"port": _game_port,
		# ⚠️ `seated_peer_count()`, NOT `playing_peer_count()`. See that function's own ⚠️⚠️
		# for why the two exist and must disagree: a lobby whose only occupant is a
		# spectator is 0 players, and the other count would advertise a game nobody is in.
		"players": NetworkManager.seated_peer_count(),
		"max": NetworkManagerScript.MAX_PLAYERS,
		# The map this process booted with, or whatever the lobby leader has since chosen —
		# on a dedicated server nobody at the keyboard picks it. See
		# `NetworkManager`'s § THE LOBBY LEADER.
		"map": String(GameLaunch.selected_map),
		# ⚠️ AN IN-PROGRESS LOBBY IS STILL LISTED, AND THE ROW SAYS SO. `NetworkManager.
		# _rpc_route_to_running_match` exists precisely so a peer can arrive after the start
		# whistle, so hiding these would hide games that are genuinely joinable.
		"in_progress": NetworkManager.match_in_progress,
	}).to_utf8_buffer()

func _step_browse(delta: float) -> void:
	if _client != null:
		while _client.get_available_packet_count() > 0:
			var raw := _client.get_packet()
			# Envelope first, for the same reason as `_step_respond` — and here it is the
			# whole point of the protocol rather than a detail. See the header's ⚠️⚠️.
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
	var port := int(packet.get("port", 0))
	if port <= 0 or port > 65535:
		return
	# ⚠️ KEYED ON THE ENVELOPE'S IP AND THE PAYLOAD'S GAME PORT, NOT ON THE CODE. A server
	# that restarts mints a fresh code (see `NetworkManager.host_game`) and would otherwise
	# leave its old row sitting in the list for the full timeout, next to its new one.
	var key := "%s:%d" % [from_ip, port]
	_seen[key] = {
		"ip": from_ip,
		"port": port,
		# Folded up on arrival so `resolve_code`'s comparison has exactly one form to match
		# against, wherever the string came from.
		"code": String(packet.get("code", "")).to_upper(),
		"players": int(packet.get("players", 0)),
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

## The signature deliberately excludes `age`, which changes every frame, and includes
## everything a row actually draws — so a lobby that fills up repaints and a lobby that
## merely answered again does not.
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
