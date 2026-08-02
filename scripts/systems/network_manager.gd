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
## ⚠️ NOT THE SAME NUMBER AS `MAX_PLAYERS`, ON PURPOSE. `create_server()`'s
## client limit used to just BE `MAX_PLAYERS`, which caps the whole SESSION at
## four connections — host plus three — with no room left for anyone who only
## wants to watch. 🧑 2026-08-01: *"spectate feels redundant... there could be
## 4 ppl playing and im a 5th or 6th guy just wathcing thru spectate."`
## `MAX_PLAYERS` stays 4 everywhere else in this file and in `main.gd` /
## `match_setup.gd` — it is a real game-design invariant (four seats, always)
## and none of that seat-indexing code changes. Only the SOCKET's own ceiling
## moves, and only here.
const MAX_CONNECTIONS: int = 12
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
## ---------------------------------------------------------------------------
## ⚠️⚠️ THE JOIN-CODE ALPHABET IS THIS SHORT BECAUSE THE CODE IS READ ALOUD. A player who
## has a lobby open reads four characters down a phone, across a room, or into a group
## chat, and every character that has a look-alike is a character that gets typed wrong by
## somebody who heard it correctly. So: no 0/O, no 1/I/L. Upper case only, because a code
## spoken has no case and printing one that does implies a distinction that is not there
## (`ServerQuery.resolve_code` folds the typed string up to match).
##
## ⚠️ DO NOT ADD CHARACTERS BACK TO "GET MORE CODES". 31^4 is 923 521 and the pool is
## EIGHT servers — the space is already five orders of magnitude larger than it needs to
## be, and the only thing a bigger alphabet buys is somebody's O landing on somebody
## else's 0.
const JOIN_CODE_ALPHABET: String = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
## Exactly four. Short enough to hold in your head between reading it and typing it, and
## `ServerQuery`'s pool of eight makes collisions a rounding error — see `resolve_code`'s
## own ⚠️ for what a collision actually costs.
const JOIN_CODE_LENGTH: int = 4
## ---------------------------------------------------------------------------

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
var local_picks: Dictionary = {"character": -1, "can": -1, "slipper": -1, "name": ""}

## What `peer_id` picked, or all -1 if it never said. Host-side lookup so main.gd
## does not have to know this dictionary exists, mirroring how it reaches tokens
## through `peer_tokens` rather than through the wire format.
func picks_for(peer_id: int) -> Dictionary:
	return peer_characters.get(peer_id,
		{"character": -1, "can": -1, "slipper": -1, "spectator": 0, "name": ""})

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

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE ONE PEER THAT IS REFEREEING RATHER THAN PLAYING. A dedicated server takes no
## seat (see § DEDICATED HOSTING), so it must never land in a number that answers "how
## many people are here" — and every count below, plus `match_result.gd`'s rematch
## denominator, walks `connected_peer_ids` to work that out.
##
## ⚠️⚠️ THIS EXISTS BECAUSE THE SERVER'S OWN LIST AND A CLIENT'S LIST DO NOT AGREE, AND
## ONLY THE CLIENT'S IS WRONG. `host_game(dedicated = true)` leaves `connected_peer_ids`
## empty, so a count taken ON the referee was already correct and always was. A CLIENT
## builds the same list from `_on_connected_to_server` (itself) plus every `peer_connected`
## Godot hands it — and Godot fires that for peer 1 the instant the handshake lands, so
## the referee is in there like anybody else.
##
## MEASURED, two real clients against a real dedicated server on port 8941, before this
## existed: the server reported `peers=94997600,13230293 seated=2`, while BOTH clients
## reported `peers=<self>,1,<other> seated=3`. Two humans in the lobby, three on their
## screens. The same run against a LISTEN host on 8942 had every peer agreeing on 3 with
## three humans present, which is the case that ships today and the case this must not
## touch.
##
## ⚠️ IT IS ONLY EVER TRUE WHEN THE SERVER SAID SO. `is_dedicated` is set locally in
## `host_game()` on the server and delivered to a client by `_rpc_announce_dedicated`;
## a client cannot infer it, and guessing from something like "the lobby leader is not
## peer 1" would quietly delete a listen host — a real player, holding a real seat —
## from everybody's count.
## ---------------------------------------------------------------------------
func is_seatless_referee(peer_id: int) -> bool:
	# 1 is the server from every peer's point of view, its own included — the same
	# literal `_on_connected_to_server` and every `rpc_id(1, ...)` in this file uses.
	return is_dedicated and peer_id == 1

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
		# ⚠️ A DEDICATED REFEREE PRESSES NOTHING, so counting it would raise the quorum
		# by one press that can never arrive. A no-op on the server (its own list never
		# holds itself) and a no-op on a listen host (peer 1 there is a player) — this
		# only ever fires on a CLIENT of a dedicated server. See `is_seatless_referee`.
		if is_seatless_referee(peer_id):
			continue
		if peer_id == multiplayer.get_unique_id() or not is_spectator(peer_id):
			count += 1
	return maxi(1, count)

## ⚠️⚠️ HOW MANY PEOPLE ACTUALLY HOLD A SEAT. NOT `playing_peer_count()`, AND THE
## DIFFERENCE IS THE POINT. 🧑 2026-08-02: *"spectator shouldnt be counted towards
## players"* — correct, and `playing_peer_count()` does count one, deliberately.
##
## That function answers "who is the rematch vote waiting on", and it carves itself out
## (`peer_id == get_unique_id()`) plus floors at 1 because SOMEBODY has to be able to
## end the vote and a spectating host is the only peer that can. `main.gd`'s vote
## denominator depends on that, `match_setup.gd`'s `_refresh_primary_button` documents
## it, and `spec_probe` asserts `playing_peer_count() == 1` for exactly the host-
## spectating case. It is right for its own question and it must not be "fixed".
##
## It is the wrong number to SHOW someone. A lobby of one spectating host is 0 players,
## not 1, and advertising "1/4" to a LAN browser would put a row in somebody's list
## promising a game that nobody is in. So: no self carve-out, no floor. The two counts
## are allowed to disagree, and this comment is why.
func seated_peer_count() -> int:
	return seated_peer_ids().size()

## ⚠️ THE LIST BEHIND `seated_peer_count()`, AND THE ONLY DEFINITION OF "HOLDS A SEAT".
## Split out rather than duplicated because `match_result.gd::_voting_peer_ids` needs the
## IDS, not the size, and used to walk `connected_peer_ids` with its own copy of this
## filter — which is exactly how the rematch denominator ended up counting a dedicated
## referee as a player while the server it was talking to did not. One predicate, two
## callers, no way for them to drift again.
##
## `Array[int]`, not `Array`, so a caller cannot quietly put a peer id of another type in
## it — every id in this file is an int and the seat maps that consume these are keyed on
## ints.
func seated_peer_ids() -> Array[int]:
	var ids: Array[int] = []
	for peer_id in connected_peer_ids:
		# The referee holds no seat by construction — see `is_seatless_referee` for the
		# measured numbers this line exists for.
		if is_seatless_referee(peer_id):
			continue
		if not is_spectator(peer_id):
			ids.append(peer_id)
	return ids

## This process's own three picks, read off GameLaunch. Kept here rather than
## inlined at both call sites so the host's self-seed and the client's RPC cannot
## drift on which preferences count as "my picks".
func _local_picks() -> Dictionary:
	return {
		"character": GameLaunch.character_index(),
		"can": GameLaunch.can_index(),
		"slipper": GameLaunch.slipper_index(),
		# ⚠️ THE NAME RIDES THE SAME PACKET, for the same reason spectating does: it
		# answers "who is this peer" and the host needs it BEFORE it spawns anybody. A
		# separate RPC would open the window where the host has seated a player it
		# cannot yet label.
		"name": GameLaunch.player_name(),
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
## ---------------------------------------------------------------------------
## § DEDICATED HOSTING — a referee with nobody sitting at it.
##
## `host_game(port, dedicated = true)` starts a server that arbitrates the match but
## takes no seat. It exists so a machine with no player at it — one of a fixed pool of
## lobby processes on a VM — can run a match for four humans, instead of the four
## seats being three humans and whoever's PC is hosting.
##
## ⚠️ THE ONLY DIFFERENCE IS THE SELF-SEEDING BELOW, AND THAT IS DELIBERATE.
## Everything else about hosting is unchanged, because everything else is already
## right: the server is still `is_host()`, still the authority at all 66 call sites
## that ask, still the one running RoundManager. What a listen-host additionally does
## is enter ITSELF into `connected_peer_ids`, `peer_tokens` and `peer_characters` —
## which is what `main.gd::_start_hosting` iterates to decide who gets a character.
## Skip those three and the server spawns nobody for itself; `_fill_empty_slots_with_placeholders`
## then covers all four seats with bots until humans take them. No seat logic changes.
##
## ⚠️ ONE PROCESS IS STILL ONE MATCH. `RoundManager`/`MatchManager` are autoloads —
## one instance each per running process, holding one score and one timer. Several
## concurrent lobbies means several processes on different ports, NOT several matches
## inside one. Nothing here makes this process re-entrant and nothing should try.
##
## ⚠️ NOBODY HERE PICKS THE MAP. A listen-host is also the player who chose the map
## and mode on the setup screen; a dedicated server has no such player, so whatever it
## booted with stands unless a client is given those controls. See the lobby-leader
## work that goes with this — without it, an online lobby is stuck on the default map.
## ---------------------------------------------------------------------------

## True when this process is refereeing without playing. Read by anything that would
## otherwise assume the server owns a character.
var is_dedicated: bool = false

## ---------------------------------------------------------------------------
## THIS SERVER'S 4-CHARACTER JOIN CODE. Minted in `host_game()`, cleared in
## `disconnect_network()` — the same lifetime as the session it names — and read off this
## var by `server_query.gd`, which is the only thing that ever tells anybody what it is.
##
## ⚠️ IT IS A LABEL, NOT A SECRET AND NOT AN AUTHORITY. Nothing is checked against it: a
## code resolves to an address and the join proceeds exactly as a typed address would. It
## is short because it is spoken, and it is per-SESSION because a server that has restarted
## is a different lobby with a different set of people in it — a code that survived a
## restart would send a player to the room its old occupants have left.
##
## ⚠️ NOT COORDINATED WITH THE REST OF THE POOL, deliberately: `server_query.gd`'s header
## explains why there is no registry to coordinate through. Two servers CAN roll the same
## four characters; see `ServerQuery.resolve_code` for what that costs.
##
## Empty while this process is not hosting, which is what a client reports too.
## ---------------------------------------------------------------------------
var join_code: String = ""

## Four characters from `JOIN_CODE_ALPHABET`. `RandomNumberGenerator` seeded per call for
## the same reason `_load_or_create_token` does it: two pool processes started by the same
## script in the same second must not both fall out of an unseeded global generator with
## the same value.
func _mint_join_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var code := ""
	for i in range(JOIN_CODE_LENGTH):
		code += JOIN_CODE_ALPHABET[rng.randi_range(0, JOIN_CODE_ALPHABET.length() - 1)]
	return code

## ---------------------------------------------------------------------------
## § THE LOBBY LEADER — who is allowed to pick the map, when the referee is a robot.
##
## On a listen host these are the same person, and this changes nothing: the leader is
## peer 1, which is the host, which is who could already pick. On a DEDICATED server
## there is no such person, so the first human through the door gets those controls.
##
## ⚠️ THE LEADER IS NOT AN AUTHORITY. It is permission to ASK. The server still owns
## the settings and still broadcasts them — a leader's map change is a request the
## server validates against this id and then applies, exactly like a seat request. Any
## other shape would let a client mutate lobby state directly, which is the one thing
## the whole host-authoritative model exists to prevent.
##
## ⚠️ IT MUST SURVIVE THE LEADER LEAVING. A lobby whose leader quit and which nobody
## can change the map on is stuck, and on a persistent server it stays stuck for
## everyone who arrives later. Handover is not polish here — see `_reassign_leader`.
## ---------------------------------------------------------------------------

## Fired when this peer learns or mints the lobby's join code — the host on host_game,
## a client when the server tells it on identify. The lobby screen listens so the code
## appears the moment it is known rather than only if something else redraws.
signal join_code_changed(code: String)
signal lobby_leader_changed(peer_id: int)

## 0 means nobody holds it — a dedicated server before its first human arrives.
var lobby_leader_id: int = 0

func is_lobby_leader() -> bool:
	return _is_networked and lobby_leader_id == multiplayer.get_unique_id()

## Host-only. Gives the role to `peer_id` and tells everyone, including itself, so a
## listen host's own UI and a client's take the same path.
##
## ⚠️ UNCONDITIONAL — it will take the role off whoever holds it. Only `_reassign_leader`
## may do that, and only because the holder has left. A peer ARRIVING must go through
## `_claim_lobby_leader_if_vacant`, which is where the "first one in, and only the first"
## rule lives so it cannot be forgotten at a call site.
func _set_lobby_leader(peer_id: int) -> void:
	if not is_host() or lobby_leader_id == peer_id:
		return
	_rpc_announce_leader.rpc(peer_id)

## Host-only. The arrival path: takes the role only if nobody holds it, and otherwise
## just tells this peer who does — an announcement it was not connected in time to hear.
func _claim_lobby_leader_if_vacant(peer_id: int) -> void:
	if not is_host():
		return
	if lobby_leader_id == 0:
		_set_lobby_leader(peer_id)
	else:
		_rpc_announce_leader.rpc_id(peer_id, lobby_leader_id)

## Host-only, on a peer leaving. Hands the role to whoever is still connected, oldest
## first, so it lands on the person who has been waiting longest rather than at random.
## Falls back to 0 — an empty dedicated lobby has no leader until someone arrives, and
## that is a real state, not an error.
func _reassign_leader(departed_id: int) -> void:
	if not is_host() or lobby_leader_id != departed_id:
		return
	for candidate in connected_peer_ids:
		if candidate != departed_id:
			_rpc_announce_leader.rpc(candidate)
			return
	_rpc_announce_leader.rpc(0)

## `call_local` so the host applies it through the same line the clients do — one code
## path, so a listen host cannot drift from what it told everyone else.
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
	peer_tokens.clear()
	peer_characters.clear()
	# A dedicated server seeds none of the three — see this function's header. It is
	# the referee, not a player, so it must not appear in the list `_start_hosting`
	# spawns characters from.
	if dedicated:
		connected_peer_ids = []
		# Nobody to lead yet. The first peer to identify takes it.
		lobby_leader_id = 0
	else:
		connected_peer_ids = [multiplayer.get_unique_id()]
		# A listen host leads its own lobby, which is what it has always done —
		# this just names the existing behaviour so one gate covers both cases.
		lobby_leader_id = multiplayer.get_unique_id()
		# 4.3/B-65: the host never sends itself `_rpc_identify` (there is no
		# connection to send it over), so its own token is seeded directly —
		# main.gd's `_spawn_player` looks every peer's token up here, host
		# included, and must not special-case peer_id == 1.
		peer_tokens[multiplayer.get_unique_id()] = local_player_token
		# The host never sends itself `_rpc_identify` either, so its own pick has to
		# be seeded here too — otherwise the hosting player is the one person in the
		# match wearing the fallback Person instead of who they actually chose.
		local_picks = _local_picks()
		peer_characters[multiplayer.get_unique_id()] = local_picks
	match_in_progress = false
	# Minted before anything can be asked for it — `ServerQuery.start_responding()` below
	# opens the socket that reports it, and a query arriving in the gap would answer with
	# an empty code that a player could not then type back in.
	join_code = _mint_join_code()
	join_code_changed.emit(join_code)
	# ⚠️ SAME FIRE-AND-FORGET CONTRACT AS THE BEACON BELOW. `start_responding` swallows its
	# own failure (see `server_query.gd`), so a server that cannot bind its status port
	# still referees its match and is still reachable by a typed address. Nothing here may
	# branch on it.
	ServerQuery.start_responding(port)
	# ⚠️ THE LAN BEACON IS STARTED HERE AND NOWHERE ELSE, because this is the one line
	# that knows a server now exists. It is fire-and-forget by design: `start_advertising`
	# swallows its own failure (see `lan_beacon.gd`), so a machine that cannot broadcast
	# still hosts and is still reachable by a typed address. Nothing below may branch on it.
	LanBeacon.start_advertising()
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
	# ⚠️ FIRST, AND BEFORE `_is_networked` GOES FALSE. `_step_advertise` stops itself
	# when `is_host()` stops being true, but that check runs on the next frame — and a
	# beacon sent in that gap advertises a lobby whose socket is already closed, which
	# puts a row in somebody's list that cannot be joined. Closing it here makes the
	# frame-later check a backstop rather than the mechanism.
	LanBeacon.stop_advertising()
	# Closed here for the same reason and at the same moment as the beacon: a status reply
	# sent after the socket is gone advertises a lobby that cannot be joined. The code goes
	# with it — an empty code is what a non-hosting process truthfully has.
	ServerQuery.stop_responding()
	join_code = ""
	join_code_changed.emit("")
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	connected_peer_ids.clear()
	_is_networked = false
	# Same lifetime as `_is_networked`: this described the session that just ended,
	# and a process that hosts again must be told again what it is.
	is_dedicated = false
	# Same lifetime as the session it described.
	lobby_leader_id = 0
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
##
## ⚠️⚠️ DELIBERATELY DOES **NOT** SUBTRACT A DEDICATED REFEREE, unlike `seated_peer_ids()`
## and `playing_peer_count()` above. The lone client of a dedicated server has
## `connected_peer_ids == [self, 1]` and therefore answers `false` here, even though it is
## the only human in the session — and that is what this question wants. It is not asking
## "am I alone", it is asking "is it safe to freeze this machine's tree". It is not: the
## referee is a SEPARATE PROCESS still running `RoundManager`/`MatchManager`, so a client
## that hard-paused would come back to a round that had carried on without it. A listen
## host solo may freeze everything precisely because the timer is in the same process it
## is freezing. Reading one high here is the conservative answer, not the bug the counts
## above had — do not "fix" it to match them.
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
	# After the erase, so the departed peer cannot be handed the role it just gave up.
	_reassign_leader(id)
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
	# Same lifetime as `_is_networked`, and the same line `disconnect_network()` already
	# carries — this is the OTHER way a client's session ends (the server went away rather
	# than we left), and it was the one path that let a value describing a finished session
	# outlive it. A client that walked out of a dedicated lobby and into a listen host's
	# would otherwise spend the gap before `_rpc_announce_dedicated` lands subtracting a
	# referee from a lobby that has a real player sitting at peer 1.
	is_dedicated = false
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
		# ⚠️ SANITISED HERE, ON THE HOST, ON ARRIVAL. Same rule as the three indices
		# above — the sender proposes, the host decides. This string is drawn on every
		# peer's scoreboard and on a 3D label in the world, so an untrimmed one from a
		# careless (or hostile) client would be everybody's problem, not just its own.
		"name": SettingsManagerScript.sanitise_name(String(picks.get("name", ""))),
	}
	if match_in_progress:
		_rpc_route_to_running_match.rpc_id(peer_id)
	# ⚠️ FIRED FOR A PLAYER TOO, NOT ONLY FOR A SPECTATOR, AND THE LOBBY RELIES ON THAT.
	# `player_connected` fires the instant ENet completes its handshake — BEFORE this
	# packet arrives — so the lobby has already auto-seated this peer by now and cannot
	# know yet whether it wanted a seat. This is the first moment anybody does.
	peer_spectator_changed.emit(peer_id, is_spectator(peer_id))
	# A dedicated server starts with nobody leading; the first peer to get this far
	# takes it. Deliberately here rather than in `_on_peer_connected`: a peer that has
	# not identified has no token and no picks, and handing the lobby to it would put
	# the settings in the hands of something we cannot yet name.
	_claim_lobby_leader_if_vacant(peer_id)
	# ⚠️ THE SERVER TELLS THE CLIENT THE CODE; the client does not look it up.
	# The alternative is reading it out of whatever the server browser last heard, which
	# is stale by construction and simply absent for anyone who arrived by typing an
	# address. The code is the thing a player reads out to invite a friend, so the peer
	# that owns it authoritatively is the one that should say what it is.
	_rpc_announce_join_code.rpc_id(peer_id, join_code)
	# ⚠️ THE SERVER TELLS THE CLIENT WHAT KIND OF HOST IT IS, for the same reason it tells
	# it the code one line up: it is a fact about the SESSION that only the server knows,
	# and nothing on the client can derive it. Without it a client counts the referee as a
	# player in every number it computes — see `is_seatless_referee` for the measurement.
	#
	# Sent to a listen host's clients too, carrying `false`. Announcing "not dedicated"
	# costs one reliable bool and means the client's `is_dedicated` is always something the
	# SERVER said, never a default that happens to be right — the shape every other fact
	# in this handshake already has.
	_rpc_announce_dedicated.rpc_id(peer_id, is_dedicated)
	player_identified.emit(peer_id, token)

## Host -> one peer. Mirrors `_rpc_announce_leader`: sent on identify so a peer knows it
## the moment it is in the lobby, rather than when something happens to refresh a cache.
@rpc("authority", "call_remote", "reliable")
func _rpc_announce_join_code(code: String) -> void:
	join_code = code
	join_code_changed.emit(code)

## Host -> one peer, on identify. `call_remote`: the server already wrote its own copy in
## `host_game()` and re-running this on itself would only be a chance to disagree with it.
##
## ⚠️ NO SIGNAL. Unlike the join code and the lobby leader, nothing redraws when this
## lands — it is read on demand by `is_seatless_referee`, and it arrives in the same
## reliable identify burst, long before a lobby board or a rematch button has a count to
## show. A signal here would be a subscriber list with nobody on it.
@rpc("authority", "call_remote", "reliable")
func _rpc_announce_dedicated(dedicated: bool) -> void:
	is_dedicated = dedicated

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
