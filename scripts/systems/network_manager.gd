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
## 4.3/B-65: host-only, fired once a peer's `_rpc_identify` lands with a
## token main.gd can look up in `peer_tokens`. Separate from `player_connected`
## because that fires the instant ENet completes its handshake, before the
## token has necessarily arrived over the wire — see `_rpc_identify`'s own
## doc for the race this exists to close.
signal player_identified(peer_id: int, token: String)

const DEFAULT_PORT: int = 8910
const MAX_PLAYERS: int = 4
const MAIN_SCENE_PATH: String = "res://scenes/main/Main.tscn"
## 4.3/B-65: where this install's stable player token is persisted. `user://`
## rather than an in-memory value only, so identity survives a full game
## relaunch — the failure mode this exists for is "someone's wifi drops",
## which does not guarantee the game process itself kept running.
const TOKEN_SAVE_PATH: String = "user://player_identity.cfg"

var connected_peer_ids: Array[int] = []
## 4.3/B-65 — a stable identity for THIS RUNNING INSTANCE, independent of the
## ENet peer id ENet hands out fresh on every connection (a reconnect gets a
## new peer id; this does not). Minted once by `_load_or_create_token()` when
## this autoload's `_ready()` runs and held for the process's whole lifetime
## — exactly long enough to cover the actual demo-day failure mode this
## exists for (B-65: "someone's wifi blips", not "someone's game crashed"),
## and presented to the host on every connect via `_rpc_identify`.
##
## ⚠️ Deliberately NOT re-loaded from a previous run's saved value, even
## though one is written to disk (see `_load_or_create_token`) — two
## instances on the SAME machine sharing one `user://` (exactly how this
## project's own two-instance test works: `Debug > Run Multiple Instances`,
## or two `godot --path .` processes) would otherwise read back the identical
## token and collide on the same join index, one silently overwriting the
## other's team/role. Confirmed by running that exact setup while building
## this. A token that does not survive a full relaunch is a real, smaller
## scope than "persisted client-side" first suggests — recorded here rather
## than silently narrowed.
var local_player_token: String = ""
## Host-only: peer_id -> the token that peer identified itself with.
## Deliberately NOT cleared on a single peer's disconnect (`_on_peer_disconnected`
## below) — the entire point is remembering which token `peer_id` USED to
## belong to, so main.gd's `_token_join_index` can hand a reconnecting peer
## (new peer_id, same token) back its own original team/role instead of the
## next free slot. Cleared only when a hosting SESSION ends (`host_game()`,
## `disconnect_network()`), which is also when `main.gd`'s own token map is
## abandoned along with the rest of the match.
var peer_tokens: Dictionary = {}
## Host-only: true once the host has left the pre-match lobby and is
## actually running Main.tscn — set by `main.gd::_start_hosting()`, cleared
## on `disconnect_network()`. A peer that connects (or reconnects) while this
## is true has missed the Lobby's ready-up gate entirely: the host has no
## Lobby.tscn left to answer a Start press on, so `_rpc_identify` routes that
## peer straight into the running match instead of leaving it stuck showing
## "waiting for host to start…" forever. See `_rpc_route_to_running_match`.
var match_in_progress: bool = false
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
	local_player_token = _load_or_create_token()

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
	# 4.3/B-65: the host never sends itself `_rpc_identify` (there is no
	# connection to send it over), so its own token is seeded directly —
	# main.gd's `_spawn_player` looks every peer's token up here, host
	# included, and must not special-case peer_id == 1.
	peer_tokens.clear()
	peer_tokens[multiplayer.get_unique_id()] = local_player_token
	match_in_progress = false
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
	peer_tokens.clear()
	match_in_progress = false

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

## Deliberately does NOT touch `peer_tokens` — see that var's own doc. Losing
## the peer_id -> token record the instant a peer disconnects would defeat
## the entire point of it existing (B-65): the next peer to present that same
## token, under a brand-new peer_id, needs to be recognisable as the SAME
## player, not a stranger.
func _on_peer_disconnected(id: int) -> void:
	connected_peer_ids.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	connected_peer_ids = [multiplayer.get_unique_id()]
	# 4.3/B-65: present our stable token to the host immediately — before
	# main.gd exists to ask for it, and regardless of whether we are about to
	# sit in Lobby.tscn or (a rejoin) get redirected straight back into a
	# running match. See _rpc_identify for what the host does with it.
	_rpc_identify.rpc_id(1, local_player_token)
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	_is_networked = false
	connection_failed.emit()

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	connected_peer_ids.clear()
	_is_networked = false
	peer_tokens.clear()
	match_in_progress = false
	server_disconnected.emit()

## 4.3/B-65 — host-only. Records which token this connecting peer presented,
## then either lets main.gd's own listeners handle spawning it (still in
## Lobby.tscn, or a normal --host/--join test with Main.tscn already loaded
## on both ends) or, if the match is already running and this peer has no
## Lobby left to wait in, tells it to load Main.tscn directly.
##
## "any_peer" because this is sent BY the connecting peer TO the host — the
## host is not this token's authority, the sender is (same reasoning every
## other any_peer RPC in this codebase documents at its own call site).
@rpc("any_peer", "call_remote", "reliable")
func _rpc_identify(token: String) -> void:
	if not is_host():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	peer_tokens[peer_id] = token
	if match_in_progress:
		_rpc_route_to_running_match.rpc_id(peer_id)
	player_identified.emit(peer_id, token)

## Host -> one peer, sent only when that peer connected (or reconnected)
## after the match already started. Idempotent: a peer that connected
## directly via --join= (Main.tscn already loaded, no Lobby involved at all)
## just gets told to "change" to the scene it is already showing, which is a
## deliberate no-op guarded below, not a special case to detect and skip.
@rpc("authority", "call_remote", "reliable")
func _rpc_route_to_running_match() -> void:
	var current := get_tree().current_scene
	if current != null and current.scene_file_path == MAIN_SCENE_PATH:
		return
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

## Mints a fresh token for THIS process and writes it to disk — see
## `local_player_token`'s own doc for why the disk copy is write-only (never
## read back to decide identity): two local test instances would otherwise
## share it via one `user://` and collide on the same join index.
## `RandomNumberGenerator`, not `UUID` — Godot has no built-in UUID type, and
## 128 bits from four `randi()` calls is more than enough entropy that two
## real installs colliding is not a risk for a LAN prototype's player count.
func _load_or_create_token() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var token := "%08x%08x%08x%08x" % [rng.randi(), rng.randi(), rng.randi(), rng.randi()]
	var cfg := ConfigFile.new()
	cfg.set_value("identity", "token", token)
	var err := cfg.save(TOKEN_SAVE_PATH)
	if err != OK:
		push_warning("NetworkManager: could not write player token to disk (error %d) — harmless, it is never read back; see local_player_token's own doc." % err)
	return token
