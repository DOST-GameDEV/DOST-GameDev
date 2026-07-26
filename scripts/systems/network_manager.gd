extends Node
class_name NetworkManagerScript

## Autoload singleton "NetworkManager" — rough LAN pass (Session 5).
## ENet over Godot's high-level multiplayer API. Deliberately minimal for now:
## no lobby UI, no reconnect handling, no NAT/relay traversal — same-LAN only,
## which is exactly what the GDD calls for. See docs/Handoff.md.
##
## - Host-authoritative: Downed state, seal/capture checks, timer, score
##   (all already live on the autoloads below RoundManager/MatchManager, which
##   only the host drives — clients just read the results).
## - Client-authoritative movement for this rough pass: each peer owns and
##   simulates its own CharacterBase locally, replicated to everyone else via
##   MultiplayerSynchronizer. No server reconciliation/anti-cheat yet — fine
##   for LAN prototyping, NOT fine to ship as-is.
##
## Test with Debug > Run Multiple Instances in the editor before testing
## across real devices — much faster iteration loop.

signal server_created
signal connection_succeeded
signal connection_failed
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_disconnected

const DEFAULT_PORT: int = 8910
const MAX_PLAYERS: int = 4

var connected_peer_ids: Array[int] = []
## B-49: Godot 4's `multiplayer.multiplayer_peer` defaults to an
## `OfflineMultiplayerPeer` sentinel, NOT null, and `multiplayer.has_multiplayer_peer()`
## reports `true` for it — so `is_networked()` used to read `true` even for
## the plain single-PC/split-keyboard local-test flow, which never calls
## `host_game()`/`join_game()` at all. That silently sent every
## `if NetworkManager.is_networked(): ...` branch throughout the codebase down
## its "networked" path in local play. Most of those happened to be harmless
## (`is_host()` was ALSO accidentally true, since the default peer reports as
## server too, so "networked and not host" gates never actually skipped
## anything) — but main.gd::_on_match_round_started branches on `is_networked()`
## alone with no such accidental save: it took the networked branch and
## iterated `_spawned_characters`, which is always empty in local test, so the
## ENTIRE per-round reset (position, is_can/team_is_can_side recompute,
## RoundManager.register_can()) silently did nothing for any local-test unit
## from round 2 onward. Track "actually networked" explicitly instead of
## trusting the engine's default-peer sentinel.
var _is_networked: bool = false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

## Starts a server on `port` and marks the host itself as the first connected
## player (host's own peer id, `1`, never fires `peer_connected`).
func host_game(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: failed to host on port %d (error %d)" % [port, err])
		return err
	multiplayer.multiplayer_peer = peer
	_is_networked = true
	connected_peer_ids = [multiplayer.get_unique_id()]
	server_created.emit()
	return OK

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("NetworkManager: failed to connect to %s:%d (error %d)" % [address, port, err])
		return err
	multiplayer.multiplayer_peer = peer
	_is_networked = true
	return OK

func disconnect_network() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	connected_peer_ids.clear()
	_is_networked = false

## True once host_game()/join_game() actually ran — false for the plain
## single-PC/split-keyboard prototype flow. See _is_networked doc (B-49) for
## why this can't just be multiplayer.has_multiplayer_peer().
func is_networked() -> bool:
	return _is_networked

func is_host() -> bool:
	return is_networked() and multiplayer.is_server()

func _on_peer_connected(id: int) -> void:
	if not connected_peer_ids.has(id):
		connected_peer_ids.append(id)
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	connected_peer_ids.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	connected_peer_ids = [multiplayer.get_unique_id()]
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	_is_networked = false
	connection_failed.emit()

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	connected_peer_ids.clear()
	_is_networked = false
	server_disconnected.emit()
