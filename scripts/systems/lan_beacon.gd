extends Node
class_name LanBeaconScript

## LAN GAME DISCOVERY. 🧑 2026-08-02: *"can u try to list joinable games in lan
## somehwere? like in minecraft hehe"*.
##
## A host shouts a small UDP packet onto the broadcast address once a second; anybody
## sitting on the multiplayer screen listens for those packets and draws what it hears.
## Nothing here touches ENet — this runs entirely beside `NetworkManager`, and a build
## with the discovery port blocked plays exactly as it did before, by typing an address.
##
## ---------------------------------------------------------------------------
## ⚠️⚠️ THE ADDRESS COMES FROM THE PACKET, NOT FROM THE PAYLOAD. This is the whole
## reason the protocol is shaped the way it is.
##
## The obvious design puts the host's own IP in the JSON. That IP is the thing a host
## cannot reliably know: `IP.get_local_addresses()` on a machine here returns the LAN
## address, the Hamachi adapter's 25.x, a WSL bridge and a couple of link-local 169.254s,
## in an order nothing promises. The lobby already has to filter that list to print an
## address for people to type, and it has to guess. A LISTENER has no such problem —
## `PacketPeerUDP.get_packet_ip()` is the source address of the datagram that actually
## reached it, which is by construction an address that carries traffic between these two
## machines. So the payload carries the PORT (which a host does know) and nothing else
## about how to reach it, and the joiner supplies the host half from the envelope.
##
## ⚠️ THE HOST DOES NOT DISCOVER ITSELF, AND THAT IS NOT SPECIAL-CASED. `stop_listening`
## is called by the multiplayer screen's `_exit_tree`, and a host has left that screen
## before `host_game()` runs — so on the hosting machine no socket is bound to hear its
## own broadcast. Two instances on ONE machine are a different story: only the first to
## bind gets the port (Godot's `PacketPeerUDP` exposes no `SO_REUSEADDR`), so a
## same-machine two-client test sees the list on one window only. That is a testing
## artefact, not a play one, and it is cheaper than reimplementing the socket.
##
## ⚠️ WHETHER HAMACHI PEERS APPEAR HERE IS UNMEASURED, AND THE UI DOES NOT PROMISE IT.
## A broadcast is ordinarily a link-local thing and a routed virtual network is not
## obliged to carry 255.255.255.255. But `tools/lan_probe.tscn role=both` on this machine
## came back with source IP **26.190.106.234** — the Hamachi adapter, not the LAN card —
## so the OS did pick that interface to broadcast out of, and the flat claim "Hamachi
## will never work" is not one this measurement supports. What that run proves is only
## that the packet left and came back on ONE machine; it says nothing about whether the
## virtual switch relays it to a second one. Until somebody runs `role=host` and
## `role=listen` on two real Hamachi peers, this is a LAN browser that MIGHT reach
## further, the button says LAN, and the empty-box text points at the typed address
## field rather than claiming the absence is expected.
## ---------------------------------------------------------------------------

## ⚠️ NOT `NetworkManager.DEFAULT_PORT`. Discovery is UDP and the game is ENet-over-UDP
## on 8910; binding a listener to 8910 on a machine that is also hosting would fight the
## server for its own port. One above, and deliberately never defaulted to from the join
## field, so a player who types "…:8911" gets a failed connection rather than a listener.
const DISCOVERY_PORT: int = 8911
## Marks a packet as ours before anything else is parsed. A stray datagram on a shared
## port is not an error worth logging, it is simply not for us.
const MAGIC: String = "tumbang-preso-lan"
## How often a host shouts. Fast enough that a lobby appears in the list about as quickly
## as a player can read the screen, slow enough to be invisible next to ENet's own chatter.
const BEACON_INTERVAL: float = 1.0
## ⚠️ FOUR BEACONS, NOT ONE. A host that has quit stops broadcasting and its row has to
## go, but a single dropped datagram is ordinary on UDP and must not blink the row out
## from under a cursor that is about to click it.
const ENTRY_TIMEOUT: float = 4.0

## Emitted when the visible list actually CHANGES — not once per received packet. The
## screen redraws on this, and a beacon arriving every second from an unchanged lobby is
## not a change; repainting on it would fight the mouse for the row under the cursor.
signal servers_changed

var _advertiser: PacketPeerUDP = null
## Every address a beacon is sent to each tick — see `_broadcast_destinations()` for why
## this is a list and not the single limited-broadcast address it started as.
var _destinations: Array[String] = []
var _listener: PacketPeerUDP = null
var _since_beacon: float = 0.0
## ip:port -> {ip, port, name, players, max, in_match, age}
var _seen: Dictionary = {}
## The payload fingerprint the last `servers_changed` was emitted for, so an unchanged
## lobby re-announcing itself every second stays silent. See the signal's own note.
var _last_signature: String = ""

func _ready() -> void:
	set_process(true)

## ---------------------------------------------------------------------------
## § HOSTING — called by `NetworkManager.host_game()` / `disconnect_network()`.
## ---------------------------------------------------------------------------

## ⚠️ FAILURE IS SILENT AND DELIBERATELY NOT FATAL. Broadcast permission is exactly the
## thing a locked-down Windows profile refuses, and a host whose beacon cannot open must
## still host — everyone reaches it by typing the address, which is how this game worked
## before discovery existed. `push_warning`, never `push_error`, and no return value the
## caller is tempted to branch on.
func start_advertising() -> void:
	stop_advertising()
	_advertiser = PacketPeerUDP.new()
	_advertiser.set_broadcast_enabled(true)
	_destinations = _broadcast_destinations()
	if _destinations.is_empty():
		push_warning("LanBeacon: no broadcast destination; this host is typed-address only.")
		_advertiser = null
		return
	# Shout once immediately. A host that has to wait a full interval before its first
	# packet is a host that is invisible for a second to somebody already watching.
	_since_beacon = BEACON_INTERVAL

## ---------------------------------------------------------------------------
## ⚠️⚠️ ONE BEACON PER INTERFACE, AND 255.255.255.255 ALONE IS NOT ENOUGH. This is the
## bug that made the feature not work at all on the machine it was written on.
##
## 🧑 2026-08-02, testing host-here / join-on-a-spare-laptop: *"cant detect the lan for
## some reason"*. The limited broadcast address goes out exactly ONE interface — whichever
## the routing table picks — and `tools/lan_probe.tscn` had already printed which one
## without anybody reading it properly: source IP **26.190.106.234**. That is the Radmin
## VPN adapter. `IP.get_local_interfaces()` on this PC lists FOUR IPv4 interfaces:
##
##     Ethernet      192.168.1.7        <- the actual LAN, and the only one that matters
##     Hamachi       25.5.84.39
##     Radmin VPN    26.190.106.234     <- where every beacon was going
##     Loopback      127.0.0.1
##
## So the packet was real, well-formed, and delivered to a virtual network with nobody on
## it. The one-machine `role=both` probe passed throughout, because the loopback path does
## not care which adapter the datagram left by — which is exactly the blind spot that
## probe's own header warns about, one paragraph that then went unheeded.
##
## The fix is to stop letting the routing table choose. Every non-loopback IPv4 gets a
## SUBNET-DIRECTED broadcast of its own, so the Ethernet card is addressed by name rather
## than by luck, and the limited address is kept as well for anything the /24 guess misses.
##
## ⚠️ THE /24 IS A GUESS AND IT IS ONLY SAFE BECAUSE A WRONG ONE IS INERT. Godot exposes
## addresses but no NETMASKS (`get_local_interfaces()` returns name/friendly/index/
## addresses and nothing else), so the subnet broadcast is built by replacing the last
## octet. That is right for the 192.168.x.x/24 and 10.x.x.x/24 home LANs this game is
## played on, and WRONG for Hamachi and Radmin, which are /8 — 25.5.84.255 is a perfectly
## ordinary host address on 25.0.0.0/8, not a broadcast. Sending there does nothing and
## harms nothing: it is one 200-byte datagram a second to an address that ignores it.
## Guessing narrow costs a wasted packet; guessing wide would mean not covering the LAN.
func _broadcast_destinations() -> Array[String]:
	var out: Array[String] = ["255.255.255.255"]
	for address in IP.get_local_addresses():
		if ":" in address: # IPv6 has no broadcast at all — it uses multicast
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

## ---------------------------------------------------------------------------
## § LISTENING — called by `multiplayer_setup.gd`, which also closes it in `_exit_tree`.
## ---------------------------------------------------------------------------

func start_listening() -> void:
	if _listener != null:
		return
	_listener = PacketPeerUDP.new()
	# "*" binds every interface: on a machine with a LAN card and a Hamachi adapter,
	# binding one of them is a coin flip over which network the player is actually on.
	var err := _listener.bind(DISCOVERY_PORT, "*")
	if err != OK:
		# Same rule as the advertiser: not fatal, and the box explains the fallback.
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

## Newest-first is wrong and alphabetical is arbitrary, so: lobbies you can still get a
## seat in, then fuller ones, then by name. The list is at most a handful of rows.
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
	# ⚠️ IT ADVERTISES FOR AS LONG AS THE SERVER IS UP, INCLUDING MID-MATCH, and the
	# payload says which. `NetworkManager._rpc_route_to_running_match` exists precisely
	# because a peer may arrive after the start whistle, so hiding in-progress games
	# would hide games that are genuinely joinable — Minecraft's list does not hide a
	# world because somebody is already in it. The row is labelled instead.
	if not NetworkManager.is_host():
		stop_advertising()
		return
	_since_beacon += delta
	if _since_beacon < BEACON_INTERVAL:
		return
	_since_beacon = 0.0
	var payload := JSON.stringify({
		"magic": MAGIC,
		# ⚠️ THE BUILD VERSION RIDES ALONG AND IS CHECKED ON RECEIPT. Two different
		# builds on one LAN can see each other's beacons and cannot play together; a
		# row that always fails to connect is worse than no row.
		"version": GameVersion.string(),
		# ⚠️ THE JOIN CODE RIDES THE BEACON TOO, so a LAN lobby has a working code and
		# not just an online one. Codes are resolved by matching what a server SAYS it
		# is called against what was typed, and until this was here the only servers
		# that ever said were pool servers — a LAN host could be shown a code that
		# nothing on earth could look up.
		"code": NetworkManager.join_code,
		"port": NetworkManagerScript.DEFAULT_PORT,
		"name": _host_label(),
		# ⚠️ `seated_peer_count()`, NOT `playing_peer_count()` — see that function's own
		# ⚠️⚠️ for why the two exist and must disagree. 🧑: *"spectator shouldnt be
		# counted towards players"*. A lobby whose only occupant is a spectating host
		# advertises 0/4 here, which is the truth and is what makes the row worth
		# clicking; the other count would say 1/4 and promise a game nobody is in.
		"players": NetworkManager.seated_peer_count(),
		"max": NetworkManagerScript.MAX_PLAYERS,
		"in_match": NetworkManager.match_in_progress,
	}).to_utf8_buffer()
	# ⚠️ `set_dest_address` PER DESTINATION, PER TICK. It is a property of the socket, not
	# an argument to the send, so the address in force is whatever was set last — a loop
	# that set it once outside would post every packet to the final entry.
	for destination in _destinations:
		if _advertiser.set_dest_address(destination, DISCOVERY_PORT) != OK:
			continue
		_advertiser.put_packet(payload)

## The hosting player's own name, which is what somebody scanning a list recognises.
## Falls back rather than showing an empty row: `player_name()` is free text and a
## player who never typed one still has to be listed as something.
func _host_label() -> String:
	var who := GameLaunch.player_name().strip_edges()
	return "%s'S GAME" % who.to_upper() if not who.is_empty() else "A TUMBANG PRESO GAME"

func _step_listen(delta: float) -> void:
	if _listener == null:
		return
	while _listener.get_available_packet_count() > 0:
		var raw := _listener.get_packet()
		# ⚠️ READ THE ENVELOPE BEFORE THE BODY. `get_packet_ip()` describes the packet
		# just taken and is overwritten by the next `get_packet()`, so reading it after
		# parsing would attribute one host's address to another's payload.
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

## The signature deliberately excludes `age`, which changes every frame, and includes
## everything the row actually draws — so a lobby that fills up repaints and a lobby that
## merely said hello again does not.
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
