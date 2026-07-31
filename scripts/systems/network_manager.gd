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
## HOST-ONLY, and it fires for a peer's FIRST declaration as well as for every later
## change — see `publish_spectator`. `match_setup.gd` listens: a peer that starts
## watching has to give its seat back to the bot pool and leave the ready count, and
## the lobby board is the only thing that can show that happening.
##
## Emitted from `_rpc_identify` too (not only from a mid-lobby toggle), because a peer
## that walked into the lobby ALREADY spectating declares it in its identify packet and
## the board would otherwise seat it like anybody else.
signal peer_spectator_changed(peer_id: int, spectating: bool)

const DEFAULT_PORT: int = 8910
const MAX_PLAYERS: int = 4
const MAIN_SCENE_PATH: String = "res://scenes/main/Main.tscn"
## Hamachi (or any VPN-tunnelled LAN) carries more jitter than a same-router
## LAN, and ENet's built-in defaults (timeout_limit 32 / timeout_min 5000ms /
## timeout_max 30000ms) can flag a live connection as dead during an ordinary
## latency spike over the tunnel, not just an actual drop — the exact
## "someone's wifi blips" failure mode B-65 already designed the rejoin
## identity token around. Widened here so a spike has room to recover before
## ENet gives up; kept finite (not "increase forever") so a real drop still
## resolves in a reasonable window rather than stalling a round indefinitely.
const ENET_TIMEOUT_LIMIT: int = 32
const ENET_TIMEOUT_MIN: int = 10000
const ENET_TIMEOUT_MAX: int = 45000
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
## Host-only: peer_id -> the CharacterRoster index that peer picked on the
## CHARACTER screen. Populated by `_rpc_identify` alongside the token, from the
## same packet, because the two are answers to the same question ("who is this
## peer") and splitting them across two RPCs would create a window where the host
## knows a peer's identity but not its face — precisely when it is about to spawn
## it.
##
## Cleared on the same schedule as `peer_tokens`, and for the same reason: a
## reconnecting peer re-identifies, so this is rebuilt rather than stale.
##
## Read by `main.gd::_build_networked_character` via `picks_for()`. Absent (an
## AI-filled slot, or a peer from a build with no roster) means -1 on every slot,
## which `character_visual.gd` reads as "no pick" and answers with the
## signed-off default look.
##
## ⚠️ ALL THREE PICKS ARE SENT BY EVERY PEER EVEN THOUGH EACH PEER USES ONLY ONE.
## A peer controls a Person OR a Prop, never both (`_build_spawn_data` derives
## that from its join index), so a Prop peer's character pick and a Person peer's
## lata pick are both dead weight — three ints. The alternative is deciding what
## to send based on a slot assignment the peer does not know yet at connect time,
## which is a race for no saving worth having.
var peer_characters: Dictionary = {} # peer_id -> {character, can, slipper}
## What THIS process picked, published to the host on connect. Snapshotted at
## connect time rather than read live, so a menu the player wanders back into
## mid-connection cannot change what the host was already told.
var local_picks: Dictionary = {"character": -1, "can": -1, "slipper": -1}

## What `peer_id` picked, or all -1 if it never said. Host-side lookup so main.gd
## does not have to know this dictionary exists, mirroring how it reaches tokens
## through `peer_tokens` rather than through the wire format.
func picks_for(peer_id: int) -> Dictionary:
	return peer_characters.get(peer_id,
		{"character": -1, "can": -1, "slipper": -1, "spectator": 0})

## Whether `peer_id` joined to WATCH rather than to play. Host-side, read by
## `main.gd::_spawn_player` (which skips them entirely) and by
## `_expected_ready_count()` (which must not wait for a READY press from somebody with
## no character to ready). See `GameLaunch.spectator`.
func is_spectator(peer_id: int) -> bool:
	return int(picks_for(peer_id).get("spectator", 0)) != 0

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE SPECTATE CHOICE IS MADE **AFTER** THE IDENTIFY PACKET HAS ALREADY GONE, AND
## WITHOUT THIS NOTHING EVER TOLD THE HOST.
##
## `_local_picks()` is snapshotted once — at `host_game()` for the host, at
## `_on_connected_to_server()` for a client — and the SPECTATE toggle lives one screen
## LATER, in the lobby the peer is sitting in while connected. So every consumer of
## `is_spectator()` (the ready gate, `_spawn_player`, `playing_peer_count`) was reading a
## value frozen before the player had been given any way to set it:
##
##   * a CLIENT that pressed SPECTATE in the lobby was spawned a character anyway and
##     counted in the ready gate — the toggle did nothing at all off the local machine;
##   * a HOST that pressed it got a body too, because `host_game()` had already written
##     `peer_characters[1]` with `spectator = 0` before the lobby existed.
##
## Solo is unaffected and deliberately does not come through here: `main.gd::
## _start_local_test` reads `GameLaunch.spectator` directly and there is no host to tell.
##
## Host-authoritative like every other pick: the sender proposes, the host records. A
## client never writes another peer's flag, and its own copy of `peer_characters` stays
## empty exactly as it is for the three character indices.
func publish_spectator(spectating: bool) -> void:
	local_picks["spectator"] = 1 if spectating else 0
	if not is_networked():
		return
	if is_host():
		_apply_spectator(multiplayer.get_unique_id(), spectating)
		return
	# Same window `match_setup.gd::_can_rpc` documents: `join_game()` returns when the
	# socket opens, not when the handshake completes, and the SPECTATE button is
	# clickable throughout. A press inside that window is not lost — `local_picks` above
	# already carries it, and `_on_connected_to_server` sends the packet.
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_rpc_set_spectator.rpc_id(1, spectating)

## Any peer -> host: "I am watching / I am playing after all."
@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_spectator(spectating: bool) -> void:
	if not is_host():
		return
	_apply_spectator(multiplayer.get_remote_sender_id(), spectating)

## HOST ONLY. Writes the flag into the same `peer_characters` entry `_rpc_identify`
## builds, rather than into a parallel dictionary, so `is_spectator()` has exactly one
## source and cannot answer two different things depending on which one was written last.
func _apply_spectator(peer_id: int, spectating: bool) -> void:
	var picks: Dictionary = peer_characters.get(peer_id,
		{"character": -1, "can": -1, "slipper": -1, "spectator": 0})
	picks["spectator"] = 1 if spectating else 0
	peer_characters[peer_id] = picks
	peer_spectator_changed.emit(peer_id, spectating)

## How many connected peers are actually PLAYING. The ready gate counts these, not
## `connected_peer_ids.size()` — a lobby of two players and two spectators must start on
## two presses, and counting all four would hang it forever on people who cannot press.
##
## Floored at 1 for the same reason `_expected_ready_count` already floors: a host whose
## own peer list has not populated yet still owes its own press. Note that a host who is
## ITSELF spectating still counts here — somebody has to be able to start the match, and
## the host is the only peer that can.
func playing_peer_count() -> int:
	var count := 0
	for peer_id in connected_peer_ids:
		if peer_id == multiplayer.get_unique_id() or not is_spectator(peer_id):
			count += 1
	return maxi(1, count)

## This process's own three picks, read off GameLaunch. Kept here rather than
## inlined at both call sites so the host's self-seed and the client's RPC cannot
## drift on which preferences count as "my picks".
func _local_picks() -> Dictionary:
	return {
		"character": GameLaunch.character_index(),
		"can": GameLaunch.can_index(),
		"slipper": GameLaunch.slipper_index(),
		# ⚠️ SPECTATING RIDES THE PICKS PACKET RATHER THAN GETTING AN RPC OF ITS OWN.
		# It is answered by the same question the three picks answer — "who is this peer,
		# and what should the host build for them" — and it has to be known BEFORE the
		# host spawns anybody. A second RPC would create exactly the window
		# `peer_characters`' own doc describes for the character index: the host knows a
		# peer exists but not yet what it is, precisely when it is about to seat it.
		#
		# An int, not a bool: this dictionary crosses the wire and every other value in
		# it is an int, so a mixed-type payload buys nothing and costs a type surprise.
		"spectator": 1 if GameLaunch.spectator else 0,
	}
## Host-only: true once the host has left the pre-match lobby and is
## actually running Main.tscn — set by `main.gd::_start_hosting()`, cleared
## on `disconnect_network()`. A peer that connects (or reconnects) while this
## is true has missed the Lobby's ready-up gate entirely: the host has no
## MatchSetup.tscn left to answer a Start press on, so `_rpc_identify` routes that
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
	# The host never sends itself `_rpc_identify` either, so its own pick has to
	# be seeded here too — otherwise the hosting player is the one person in the
	# match wearing the fallback Person instead of who they actually chose.
	local_picks = _local_picks()
	peer_characters.clear()
	peer_characters[multiplayer.get_unique_id()] = local_picks
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

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE HOST SAYS GOODBYE BEFORE IT CLOSES THE SOCKET. Human report, 2026-07-30:
## *"the host must notify clients it is leaving before it closes the server. Currently,
## quitting politely strands everyone for ~5 seconds."*
##
## MEASURED before this existed, on real peers: an ABRUPT quit (alt-F4) and a GRACEFUL
## one (the pause menu's QUIT TO MENU) produced the SAME teardown time — 5.20 s and
## 5.40 s. That is not a coincidence, it is `ENET_TIMEOUT_MIN` (10 000 ms, halved by
## ENet's own adaptive window): a closed socket is indistinguishable from a silent one,
## so a client learns about a polite exit exactly as slowly as about a yanked cable, by
## waiting for the timeout to expire. `_on_server_disconnected` was already wired and
## already correct; nothing was ever telling it.
##
## ⚠️ DO NOT "FIX" THIS BY SHORTENING `ENET_TIMEOUT_MIN`. That window is deliberately
## wide because this game is played over Hamachi, where an ordinary latency spike would
## otherwise be flagged as a drop and cost somebody their round. The fix is an
## announcement, not a shorter fuse — the timeout stays exactly where it is and remains
## the backstop for the abrupt case, which by definition cannot be announced.
##
## ⚠️ IT YIELDS TWO FRAMES BEFORE CLOSING. `rpc()` hands the packet to ENet, which
## flushes on its own poll — calling `close()` on the same frame discards the queued
## packet and the announcement never leaves the building, which is exactly the bug this
## is fixing wearing a different hat. Two `process_frame` awaits is a handful of
## milliseconds and is invisible next to the 5 s it removes.
##
## `await`, so callers must `await` it too if they intend to change scene afterwards —
## `main.gd::_on_return_to_menu_pressed` does.
func announce_host_leaving() -> void:
	if not is_host():
		return
	_rpc_host_closing.rpc()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame
		await tree.process_frame

## Host -> every client. Deliberately does the SAME teardown a real timeout would, by
## going through the same signal: `server_disconnected` is what `main.gd` already
## listens to, and it already bounces to MultiplayerSetup with a status message. A
## second, parallel "the host left politely" path would be a second thing to keep
## correct, and the two would drift the first time either was touched.
@rpc("authority", "call_remote", "reliable")
func _rpc_host_closing() -> void:
	if is_host():
		return
	_on_server_disconnected()

func disconnect_network() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	connected_peer_ids.clear()
	_is_networked = false
	peer_tokens.clear()
	# Same lifetime as peer_tokens — a hosting SESSION ending abandons both.
	peer_characters.clear()
	match_in_progress = false

## True once host_game()/join_game() actually ran — false for the plain
## single-PC/split-keyboard prototype flow. See _is_networked doc (B-49) for
## why this can't just be multiplayer.has_multiplayer_peer().
func is_networked() -> bool:
	return _is_networked

func is_host() -> bool:
	return is_networked() and multiplayer.is_server()

## Solo-host QoL (2026-07-28+): true once actually networked AND at most one
## peer is connected — i.e., the human at this machine is alone in the
## session, almost always because they hosted and nobody has joined yet.
## Distinct from is_networked() alone: a real 2v2 needs pause to stay
## non-freezing (Q-3/B-64 — a client pausing its own tree stops sending its
## own movement while the host keeps simulating it regardless) and the debug
## switcher to stay inert (each peer owns exactly one character, so there is
## nothing to hand player_id to). Neither restriction protects anyone when
## there is nobody else in the session for it to protect.
func is_solo_session() -> bool:
	return is_networked() and connected_peer_ids.size() <= 1

func _on_peer_connected(id: int) -> void:
	if not connected_peer_ids.has(id):
		connected_peer_ids.append(id)
	# call_deferred: ENet's own internal peer registry isn't always populated
	# by the instant this signal fires — get_peer(id) inside
	# _apply_peer_timeout can race it and hit ENetMultiplayerPeer's own
	# "!peers.has(p_id)" guard (measured live: reproduced on a client the
	# moment it connects, calling this for peer_id 1 before ENet had
	# registered it internally). Deferring to end-of-frame gives ENet's own
	# bookkeeping time to catch up first.
	_apply_peer_timeout.call_deferred(id)
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
	# The host is always peer id 1 from a client's own point of view.
	# call_deferred — see _on_peer_connected's own doc for why.
	_apply_peer_timeout.call_deferred(1)
	# 4.3/B-65: present our stable token to the host immediately — before
	# main.gd exists to ask for it, and regardless of whether we are about to
	# sit in MatchSetup.tscn or (a rejoin) get redirected straight back into a
	# running match. See _rpc_identify for what the host does with it.
	# Snapshotted here rather than read live inside the RPC — see
	# `local_character_index`, so a menu the player wanders back into
	# mid-connection cannot change what the host was already told.
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
	peer_tokens.clear()
	# Same lifetime as peer_tokens — a hosting SESSION ending abandons both.
	peer_characters.clear()
	match_in_progress = false
	server_disconnected.emit()

## 4.3/B-65 — host-only. Records which token this connecting peer presented,
## then either lets main.gd's own listeners handle spawning it (still in
## MatchSetup.tscn, or a normal --host/--join test with Main.tscn already loaded
## on both ends) or, if the match is already running and this peer has no
## Lobby left to wait in, tells it to load Main.tscn directly.
##
## "any_peer" because this is sent BY the connecting peer TO the host — the
## host is not this token's authority, the sender is (same reasoning every
## other any_peer RPC in this codebase documents at its own call site).
@rpc("any_peer", "call_remote", "reliable")
func _rpc_identify(token: String, picks: Dictionary = {}) -> void:
	if not is_host():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	peer_tokens[peer_id] = token
	# Range-checked host-side rather than trusted. This value arrives from a
	# client and is used to index an array on the spawn path, and -1 is itself
	# meaningful ("no pick") so it has to survive the check rather than be
	# clamped into 0. Same rule every other client-sent value here follows: the
	# sender proposes, the host decides.
	peer_characters[peer_id] = {
		"character": _validated(picks, "character", CharacterRoster.ROSTER.size()),
		"can": _validated(picks, "can", CharacterRoster.CANS.size()),
		"slipper": _validated(picks, "slipper", CharacterRoster.SLIPPERS.size()),
		# Absent (a peer on an older build) reads as 0, i.e. a player. That is the right
		# default: an unknown peer that is silently never spawned would be a black screen
		# with no error, which is the worst failure this could have.
		"spectator": 1 if int(picks.get("spectator", 0)) != 0 else 0,
	}
	if match_in_progress:
		_rpc_route_to_running_match.rpc_id(peer_id)
	# ⚠️ FIRED FOR A PLAYER TOO, NOT ONLY FOR A SPECTATOR, AND THE LOBBY RELIES ON THAT.
	# `player_connected` fires the instant ENet completes its handshake — BEFORE this
	# packet arrives — so the lobby has already auto-seated this peer by now and cannot
	# know yet whether it wanted a seat. This is the first moment anybody does.
	peer_spectator_changed.emit(peer_id, is_spectator(peer_id))
	player_identified.emit(peer_id, token)

## One client-sent pick, range-checked against the roster it indexes. -1 is
## itself meaningful ("no pick") so it survives rather than being clamped to 0.
func _validated(picks: Dictionary, key: String, count: int) -> int:
	var value := int(picks.get(key, -1))
	return value if value >= 0 and value < count else -1

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

## Widens ENet's per-peer disconnect-timeout window for `peer_id` — see the
## ENET_TIMEOUT_* constants' own doc for why. Called from both ends of a
## connection (host, once a remote peer's handshake completes; client, once
## connected to the host) since ENet tracks timeout state per direction.
func _apply_peer_timeout(peer_id: int) -> void:
	var enet_peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet_peer == null:
		return
	var packet_peer := enet_peer.get_peer(peer_id)
	if packet_peer != null:
		packet_peer.set_timeout(ENET_TIMEOUT_LIMIT, ENET_TIMEOUT_MIN, ENET_TIMEOUT_MAX)
