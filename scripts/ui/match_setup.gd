extends Control
class_name MatchSetupScreen

## THE one setup screen. Single Player and the multiplayer lobby are the same
## scene, the same layout and the same script — what changes between them is
## which controls are live, not where anything sits.
##
## Replaces both `GameSetup.tscn` (map/mode + a row of launch buttons) and
## `Lobby.tscn` (peer list + ready gate). Those were two screens because the
## networked flow needed a waiting room and the offline flow did not; the offline
## flow was then sent through the waiting room anyway, for symmetry, and ended up
## with a READY button that gated nothing and a "SINGLE PLAYER / YOU (LOCAL) …"
## roster of one. That symmetry is now where it belongs — in the layout — instead
## of in a ceremony the solo player has to click through.
##
##   Single Player   ModeSelect → here → Main.tscn        (START MATCH, no gate)
##   Host            ModeSelect → MultiplayerSetup → here → Main.tscn (READY, then host STARTs)
##   Join            ModeSelect → MultiplayerSetup → here → Main.tscn (READY, waits for host)
##
## WHAT IS AUTHORITATIVE, AND WHY IT HAS TO BE. Three things used to be decided
## per-peer, silently, and the first two were live defects before this screen
## existed:
##
##   * THE MAP. `main.gd::_load_map()` reads `GameLaunch.selected_map_scene()`
##     locally on every peer and nothing synced it, so a client who had last
##     picked Bayan Plaza loaded Bayan Plaza while the host loaded Eskinita —
##     different geometry, different spawn points, and (movement being
##     client-authoritative) players walking through walls that only exist on
##     someone else's screen. Recorded in `lobby.gd` and `Checklist.md` 10.4 as
##     known-and-unfixed. **The host now owns it and broadcasts it.**
##   * THE MODE. Exactly the same hole, never written down: `GameLaunch.game_mode`
##     was only ever transmitted to a peer joining MID-MATCH
##     (`main.gd::_sync_state_to_late_joiner`). A peer that joined through the
##     lobby kept its own pick, and `hitbox.gd`/`carriable.gd` branch on it
##     per-peer — so a client on DENTS dented a can the host on CAPTURE did not.
##     **Host-owned and broadcast too.**
##   * THE SEAT. Team and role came from connection order alone
##     (`main.gd::_next_join_index`), which no player could see or influence.
##     **Now claimed by clicking, exclusively, refereed by the host** — see
##     `_rpc_request_seat`. Connection order survives as the fallback for peers
##     that never pass through this screen (`--host`/`--join` from the command
##     line, and mid-match late joiners).
##
## THE LAYOUT IS CONTAINER-DRIVEN, NOT HAND-PLACED. Both panels used to be
## `layout_mode = 0` rectangles at absolute offsets — the config panel at x
## 83..946, the roster at x 1000..1820 — which looked correct in the editor and
## overlapped in the build. A Control's size is clamped up to its combined
## MINIMUM size, so the moment the PLAYERS button's label grew past the width it
## had been drawn at ("BERTO · SARSILYA · TSINELAS NA GOMA ▸" is three roster
## names, and the roster is data), the button widened, the row widened, and the
## panel grew straight through its own offset_right and under the roster panel.
## Nothing in that chain could push back, because absolute offsets are not a
## constraint — they are a starting guess.
##
##   Body (MarginContainer, screen margins)
##   └── Columns (HBoxContainer, separation 54)
##       ├── LeftColumn  (VBox, min 880, EXPAND|FILL) — config, detail, pennants,
##       │                 a Spacer that eats the slack, then BACK pinned bottom
##       └── RightColumn (VBox, min 700, EXPAND|FILL) — the roster panel
##
## Both columns EXPAND with the same stretch ratio, so the free width is split
## evenly and neither can reach into the other: the worst a long string can now
## do is squeeze its own column down to its `custom_minimum_size`. The strings
## that grow unpredictably (the three-name PLAYERS button, the roster rows, the
## map/mode values) carry `clip_text` + an ellipsis overrun so their preferred
## width stops driving the layout at all, and every descriptive Label
## (`DetailLabel`, `SeatHint`, `StatusLabel`) is `autowrap_mode = 2` inside a
## VBox, so it grows DOWNWARD into space the container reserves rather than
## sideways into a button.
##
## The two things still hand-placed are deliberate: `Banner` is a pennant that
## bleeds off the left edge, and `CharacterSelectPanel` is a full-screen overlay.
## Neither participates in the column flow.
##
## THE CHARACTER PICK IS DELIBERATELY NOT REFEREED. Two players choosing the same
## person or the same tsinelas is not a conflict — they are in different seats,
## and `main.gd` `.duplicate()`s the ability Resource per character anyway, so
## they never share cooldown state. It is also not carried by this screen at all:
## `NetworkManager.peer_characters` already publishes each peer's picks to the
## host on connect, and `CharacterBase.character_index`/`can_index`/`slipper_index`
## are replicated with the spawn. This screen only opens the panel.

const MAIN_SCENE_PATH: String = "res://scenes/main/Main.tscn"
const MODE_SELECT_PATH: String = "res://scenes/ui/ModeSelect.tscn"
const MULTIPLAYER_SETUP_PATH: String = "res://scenes/ui/MultiplayerSetup.tscn"

## Stagger between the two pennants unfurling.
const STAGGER: float = 0.09

## Dim applied to the map/mode arrows on a client, which may look at the host's
## choice but not change it. Disabled alone is not enough of a read at a glance
## — a `TextureButton` shows no disabled state of its own.
const LOCKED_MODULATE: Color = Color(1, 1, 1, 0.28)

## Via the class_name rather than the GameLaunch autoload: an autoload lookup is
## not a constant expression, so it cannot initialise a const. Unchanged from the
## screen this replaces.
## ⚠️ `detail` IS NOT DECORATION — it is half of "whenever a player selects or
## moves to a Map, Mode or Character, the explanation text should update to
## explain the selection." A mode picker that shows two words the player has
## never seen ("CAPTURE", "DENTS") and explains neither is a coin toss with extra
## steps, and both of these change how a round is WON.
## ⚠️ `MODES` WAS A TWO-ENTRY PICKER AND THERE IS NOTHING LEFT TO PICK. 2026-07-31,
## 📋 `build rules` §8.2 — Option A ("DENTS") is deleted and the game ships one
## ruleset, so the mode ROW is hidden in `_ready()` and every arrow, index and
## broadcast argument behind it is gone. The row itself and its scene nodes are left
## in `MatchSetup.tscn` for 🖥️ `build ux` to remove properly along with the focus
## order — that is §4.18, already filed, and the scene is its file not this lane's.
##
## The text survives because the detail box still has to explain how a round is won;
## it is now a statement rather than half of a choice.
const RULESET_LABEL: String = "CAPTURE"
const RULESET_DETAIL: String = "Knock the lata off its circle and keep it there. The countdown at the top of the screen is the round: when it hits zero the attackers take it. Four knockdowns ends it outright. The defenders win by surviving the clock."

## ---------------------------------------------------------------------------
## R-09 · THE BOT DIFFICULTY PICKER.
##
## `AIController.DIFFICULTY_TIERS` has been complete and unreachable for two passes.
## This is the screen half. ⚠️ It sits BESIDE map and mode and rides the SAME
## `_rpc_sync_config` broadcast, because it is a match-affecting value and a per-peer
## one is the bug 10.5's U-8 fixed twice. Do not give it its own RPC.
##
## ⚠️ THE TIER NAMES WERE `BATA / NORMAL / ASTIG` AND ARE NOW ENGLISH — 🧑 human
## call, 2026-07-30: *"only tagalog i want are names and possible skill, i dont
## want sino or siya or stuff its so cringe."* The previous note here argued the
## Filipino words carried characterisation worth keeping; that argument lost, and
## it is recorded rather than deleted so nobody re-litigates it from scratch. The
## characterisation now lives entirely in `detail`, which is where the measured
## numbers already were. `lata`, `tsinelas` and the character/ability names stay
## Filipino — those were named as the ones to keep.
##
## ⚠️ `detail` IS MEASURED, NOT ADJECTIVES. Every number below is the BALANCE lane's,
## from `Checklist.md` §Phase 9 RUN 12 and RUN 14 — the first runs in this project's
## history in which any tier but NORMAL was measured at all. A picker that promises
## "harder" without knowing whether the tiers differ is what the roadmap called a
## coin toss with extra steps; these three genuinely differ and the copy says how.
const DIFFICULTIES: Array[Dictionary] = [
	{
		"id": 0, "label": "EASY",
		"detail": "The kid. Holds its post, aims where the lata is rather than where it is going, and overcommits often enough that you can learn to bait it. Measured the most beatable of the three: it blocks 29% of throws.",
	},
	{
		"id": 1, "label": "NORMAL",
		"detail": "The default, and the tier every balance number in this project was measured at. Reads your bearing, leads the lata, and blocks about 38% of what you throw.",
	},
	{
		"id": 2, "label": "HARD",
		"detail": "The one who wins. Chases to the edge of its own box, leads almost perfectly, and barely ever makes a mistake. Measured: it blocks 62% of throws and rounds end fast, so expect to be tagged on the way in.",
	},
]

@onready var map_preview: MapPreview = %MapPreview
@onready var banner_label: Label = %BannerLabel

@onready var map_prev_button: TextureButton = %MapPrevButton
@onready var map_next_button: TextureButton = %MapNextButton
@onready var map_value_label: Label = %MapValueLabel
@onready var mode_prev_button: TextureButton = %ModePrevButton
@onready var mode_next_button: TextureButton = %ModeNextButton
@onready var mode_value_label: Label = %ModeValueLabel
@onready var difficulty_prev_button: TextureButton = %DifficultyPrevButton
@onready var difficulty_next_button: TextureButton = %DifficultyNextButton
@onready var difficulty_value_label: Label = %DifficultyValueLabel
@onready var character_button: Button = %CharacterButton
@onready var character_panel: CharacterSelect = %CharacterSelectPanel

## The four config rows, as hover targets for the detail box — see
## `_wire_detail_focus`. Referenced as whole rows rather than as their arrows so
## that hovering the caption ("MAP:") counts too.
@onready var map_row: Control = %MapRow
@onready var mode_row: Control = %ModeRow
@onready var difficulty_row: Control = %DifficultyRow
@onready var fighter_row: Control = %FighterRow

@onready var detail_label: Label = %DetailLabel
@onready var primary_button: ArrowButton = %PrimaryButton
@onready var start_button: ArrowButton = %StartButton
@onready var status_label: Label = %StatusLabel
@onready var back_button: Button = %BackButton

@onready var seat_heading: Label = %SeatHeading
@onready var seat_hint: Label = %SeatHint
@onready var seat_buttons: Array[Button] = [
	%SeatButton0, %SeatButton1, %SeatButton2, %SeatButton3,
]

## "local", "host" or "join" — read once in `_ready()` so a later
## `GameLaunch.reset()` cannot change this screen's behaviour underneath it.
var _action: String = "local"

var _map_index: int = 0
## R-09. Index into DIFFICULTIES, mirroring _map_index exactly.
var _difficulty_index: int = 1

## Which row the detail box is currently explaining. See `_refresh_detail`.
## SEAT covers both the CHARACTER button and the four seat rows on the right —
## they are one subject ("what am I playing, and what do my picks buy it").
enum DetailTopic { MAP, MODE, DIFFICULTY, SEAT }
## Opens on MAP: it is the top row, and the map is the only one of the four whose
## explanation the player cannot infer from the value shown beside it.
var _detail_topic: DetailTopic = DetailTopic.MAP

# --- Networked lobby state ---------------------------------------------------
# All three are host-authoritative and broadcast. On a client they are populated
# purely by RPC and never written locally — a client that decided its own seat
# would be showing itself a lobby nobody else can see, which is the exact class
# of bug this screen exists to close.

var _peer_seats: Dictionary = {}    ## peer_id -> seat 0..3
var _peer_ready: Dictionary = {}    ## peer_id -> bool
## peer_id -> true, for every peer that is here to WATCH. Disjoint from `_peer_seats` by
## construction — a peer is in exactly one of the two — which is what makes "claims no
## seat" and "excluded from the ready count" the SAME fact rather than two flags that can
## disagree. Broadcast beside the seats for that reason.
var _peer_spectating: Dictionary = {}
## HOST ONLY: peer_id -> the seat it gave up when it started watching, so un-spectating
## returns it rather than dropping the player into "first free" beside three people who
## have not moved. Not broadcast: nobody else needs to know about a chair nobody is in.
var _vacated_seats: Dictionary = {}

func _ready() -> void:
	_action = GameLaunch.pending_action
	if _action == "":
		# Reached directly (a tools harness, or a scene run from the editor).
		# Solo is the only branch that needs nothing set up beforehand.
		_action = "local"
	status_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameVersion.attach_to(self)

	# Start on whatever is already chosen rather than resetting to the first
	# entry: `selected_map` and the character picks are preferences that survive
	# returning to the menu (see their own docs in game_launch.gd), so a player
	# who picked Bayan Plaza and Havaianas should not re-pick both every match.
	_map_index = GameLaunch.map_index()
	# R-09: the tier is a PREFERENCE with the same lifetime as the map and the
	# character picks, so it opens on whatever was chosen last rather than resetting.
	_difficulty_index = clampi(SettingsManager.ai_difficulty, 0, DIFFICULTIES.size() - 1)

	_wire_selector(map_prev_button, map_next_button, _on_map_prev, _on_map_next)
	_wire_selector(difficulty_prev_button, difficulty_next_button,
		_on_difficulty_prev, _on_difficulty_next)
	character_button.pressed.connect(_on_character_pressed)
	character_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover")) # 4.1
	character_panel.visible = false
	character_panel.closed.connect(_on_character_panel_closed)

	# A one-map build would leave these cycling a list of one, so they follow the
	# registry rather than a hand-set flag in the scene.
	if GameLaunch.MAPS.size() <= 1:
		map_prev_button.disabled = true
		map_next_button.disabled = true

	for i in seat_buttons.size():
		var seat := i
		seat_buttons[i].pressed.connect(func() -> void: _on_seat_pressed(seat))
		# 4.1: a plain Button carries no audio of its own — ArrowButton does (see
		# arrow_button.gd), these do not, so both halves are wired here.
		seat_buttons[i].mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))

	# One topic in the detail box, chosen by what is highlighted — see
	# `_refresh_detail`. Wired AFTER the seat buttons above so their own
	# `mouse_entered` audio is already connected and this only adds to it.
	_wire_detail_focus(DetailTopic.MAP,
		[map_row, map_prev_button, map_next_button])
	_wire_detail_focus(DetailTopic.MODE,
		[mode_row, mode_prev_button, mode_next_button])
	_wire_detail_focus(DetailTopic.DIFFICULTY,
		[difficulty_row, difficulty_prev_button, difficulty_next_button])
	var seat_targets: Array[Control] = [fighter_row, character_button]
	seat_targets.append_array(seat_buttons)
	_build_spectate_button()
	if _spectate_button != null:
		seat_targets.append(_spectate_button)
	_wire_detail_focus(DetailTopic.SEAT, seat_targets)

	primary_button.pressed.connect(_on_primary_pressed)
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	back_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))

	_apply_map()
	# §8.2: one ruleset, so the picker is not reachable. The row and its nodes stay
	# in the scene for `build ux` §4.18 to remove with the focus order.
	mode_row.visible = false
	_apply_difficulty()
	_refresh_character_button()

	match _action:
		"local": _setup_solo()
		"host":  _setup_host()
		"join":  _setup_join()

	primary_button.animate_in()
	if start_button.visible:
		start_button.animate_in(STAGGER)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()

## 4.1: the arrows are `TextureButton`s, not ArrowButtons, so their click and
## hover are connected here. One helper rather than six pairs of lines, so a new
## selector row cannot be added with half its audio missing.
func _wire_selector(prev: TextureButton, next: TextureButton,
		on_prev: Callable, on_next: Callable) -> void:
	prev.pressed.connect(on_prev)
	next.pressed.connect(on_next)
	prev.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
	next.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))

# =============================================================================
# Per-session setup
# =============================================================================

## No networking at all, and — the point of the overhaul — no ready gate. The
## player confirms map, mode, character and seat, and the match begins.
##
## The in-MATCH ready prompt is untouched and deliberately so: `main.gd`'s
## `_awaiting_local_ready` / "3 · 2 · 1 · GO" beat still runs once Main.tscn
## loads. What was removed is the SECOND, redundant ready — the one in a waiting
## room with nobody to wait for.
func _setup_solo() -> void:
	banner_label.text = "SINGLE PLAYER"
	seat_heading.text = "YOUR CHARACTER"
	# ⚠️ THIS SAID "KALARO" AND NOW SAYS "BOT" AGAIN — 🧑 human call, 2026-07-30:
	# *"can u change the tagalog kalaro to characters."* An earlier ask had gone
	# the other way (rename BOT to something more immersive) and the reasoning is
	# kept because it is still true — these are the other three kids in a 2v2, one
	# of them on YOUR team, not filler opponents — but the newer instruction wins.
	# The "kids from the street who fill in" clause carries that meaning now.
	# ⚠️ THIS DESCRIBED A 2v2 UNTIL 2026-08-01 — *"A team is one person and one
	# object"* — under a seat board that now lists four equal players. See
	# `_seat_name()` for the rest of that correction.
	seat_hint.text = "Four players, one taya. The taya rotates every round, so everyone defends exactly once. Empty seats are bots — the kids from the street who fill in."
	_seat_hint_base = seat_hint.text
	primary_button.caption = "START MATCH"
	start_button.visible = false
	_refresh_seats()

func _setup_host() -> void:
	banner_label.text = "LOBBY"
	if NetworkManager.host_game() != OK:
		# Not fatal to the screen: the player can still back out, and the message
		# says which of the two things went wrong rather than "failed".
		AudioManager.play("ui_error")
		status_label.text = "Could not open the server. Port %d may already be in use." % NetworkManagerScript.DEFAULT_PORT
		primary_button.visible = false
		start_button.visible = false
		seat_heading.text = "NOT HOSTING"
		return
	# ⚠️ THE ADDRESS IS NO LONGER IN THE HEADING — see `_build_address_row()`. The
	# heading shares an HBox with the SPECTATE toggle and trims to an ellipsis, so
	# a Hamachi address rendered as `HOST 25.…` and could not be selected anyway.
	seat_heading.text = "LOBBY  ·  YOU ARE HOSTING"
	_show_addresses(_host_addresses_with_port())
	# Host-only: the firewall block this warns about is about INBOUND traffic
	# to this machine, which is not this joiner's problem on the other two
	# `_show_addresses()` call sites.
	if _firewall_hint != null:
		_firewall_hint.visible = true
	seat_hint.text = "You pick the map and the mode for everyone. Click a seat to move. Empty seats are played by bots. Give the address below to the others."
	_seat_hint_base = seat_hint.text
	primary_button.caption = "READY"
	start_button.visible = true
	start_button.disabled = true

	NetworkManager.player_connected.connect(_on_peer_joined)
	NetworkManager.player_disconnected.connect(_on_peer_left)
	NetworkManager.peer_spectator_changed.connect(_on_peer_spectator_changed)

	# The host is peer 1 and `peer_connected` never fires for self on a server,
	# so it seats itself. Seat 0 (Team A's Person) rather than "first free": it
	# is the seat `main.gd` puts the default camera on, and a host who never
	# touches the board should land somewhere deliberate.
	var host_id := multiplayer.get_unique_id()
	_peer_seats[host_id] = 0
	_peer_ready[host_id] = false
	# ⚠️ SPECTATING IS A PREFERENCE THAT SURVIVES THE MENU (see `GameLaunch.spectator`),
	# so a host who watched the last match walks in here already watching — seated one
	# line above by the default path, and holding a chair. Republished rather than
	# assumed: `host_game()` snapshotted the picks before this screen ran, and this is the
	# first frame in which the preference and the session both exist.
	if GameLaunch.spectator:
		NetworkManager.publish_spectator(true)
	_refresh_seats()
	_refresh_primary_button()

func _setup_join() -> void:
	banner_label.text = "LOBBY"
	seat_hint.text = "The host picks the map and the mode. Click a free seat to move. Empty seats are played by bots."
	_seat_hint_base = seat_hint.text
	primary_button.caption = "READY"
	start_button.visible = false
	# A client may look at the host's map and mode but not change them — this is
	# the whole fix for the conflicting-map defect, so it is enforced on the
	# control itself, not only by the host ignoring a stray RPC.
	_lock_host_only_controls()

	var parts := MultiplayerSetupScreen.split_address(GameLaunch.pending_join_address)
	var host: String = String(parts[0])
	var port: int = int(parts[1])
	seat_heading.text = "CONNECTING…"
	_show_addresses(PackedStringArray([GameLaunch.pending_join_address]))
	if host.is_empty() or NetworkManager.join_game(host, port) != OK:
		AudioManager.play("ui_error")
		status_label.text = "Could not reach %s." % GameLaunch.pending_join_address
		seat_heading.text = "NOT CONNECTED"
		primary_button.visible = false
		return

	NetworkManager.connection_succeeded.connect(_on_connected_to_host)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.player_disconnected.connect(_on_peer_left)
	status_label.text = "Connecting…"
	_refresh_seats()
	_refresh_primary_button()

## ⚠️⚠️ "ONLY THE PC THAT SET UP HAMACHI CAN HOST" WAS THIS FUNCTION, AND HOSTING
## WAS NEVER BROKEN.
##
## 🧑 2026-08-01: *"we are using hamachi to run lan and for some reason it only
## works on the pc that configured the hamachi but it shouldnt be like that,
## anyone in hamachi should be able to host"*.
##
## `NetworkManager.host_game()` calls `ENetMultiplayerPeer.create_server()`, which
## binds **every** interface — so every machine in the Hamachi network really can
## host, and always could. What differed per machine is the address the lobby
## PRINTS for other people to type in. This used to return the FIRST non-loopback
## IPv4 `IP.get_local_addresses()` happened to list, and on a laptop that is
## normally the real adapter (`192.168.x.x`), which nobody on the far side of the
## VPN can reach. The one PC where Hamachi's adapter happened to sort first
## advertised a reachable address; everyone else advertised an unreachable one and
## it looked like they could not host.
##
## ⚠️ SO THE ADDRESSES ARE RANKED, NOT PICKED. Hamachi's `25.x.x.x` block first
## because a tunnelled address is reachable by definition from inside the tunnel,
## then ordinary private LAN ranges, then anything else. All of them are offered
## (see `_build_address_row`) rather than only the winner, because this cannot be
## decided correctly from inside the process: a player on the same physical router
## wants the 192.168 one, and only the human knows which network the other four
## people are on.
const HAMACHI_PREFIX: String = "25."

static func host_addresses() -> PackedStringArray:
	var hamachi := PackedStringArray()
	var private := PackedStringArray()
	var other := PackedStringArray()
	for addr in IP.get_local_addresses():
		if ":" in addr:
			continue # IPv6 — see multiplayer_setup.gd::split_address for why
		if addr.begins_with("127."):
			continue
		# ⚠️ 169.254.x.x IS APIPA AND IS NEVER HOSTABLE. Windows assigns one to
		# every adapter that failed to get a DHCP lease — this machine reports
		# THREE of them — so without this the cycle button offered "1/4" where
		# three of the four could not be reached by anybody, which is worse than
		# offering one: it makes the working address look like a guess.
		if addr.begins_with("169.254."):
			continue
		if addr.begins_with(HAMACHI_PREFIX):
			hamachi.append(addr)
		elif addr.begins_with("192.168.") or addr.begins_with("10.") \
				or _is_172_private(addr):
			private.append(addr)
		else:
			other.append(addr)
	var ranked := PackedStringArray()
	ranked.append_array(hamachi)
	ranked.append_array(private)
	ranked.append_array(other)
	if ranked.is_empty():
		ranked.append("127.0.0.1")
	return ranked

## 172.16.0.0 – 172.31.255.255. Spelled out because `begins_with("172.")` would
## also claim public 172.x space, which is a real routable range.
static func _is_172_private(addr: String) -> bool:
	if not addr.begins_with("172."):
		return false
	var second := addr.split(".")[1] if addr.split(".").size() > 1 else ""
	if not second.is_valid_int():
		return false
	var octet := int(second)
	return octet >= 16 and octet <= 31

static func _lan_address() -> String:
	return host_addresses()[0]

## The same list with the listening port appended, which is what somebody actually
## has to type. `multiplayer_setup.gd::split_address()` parses `host:port`, so a
## copied string works verbatim with no explaining — and including the port means
## a future non-default port is not a silent trap.
static func _host_addresses_with_port() -> PackedStringArray:
	var out := PackedStringArray()
	for addr in host_addresses():
		out.append("%s:%d" % [addr, NetworkManagerScript.DEFAULT_PORT])
	return out

func _lock_host_only_controls() -> void:
	for button in [map_prev_button, map_next_button, mode_prev_button, mode_next_button,
			difficulty_prev_button, difficulty_next_button]:
		button.disabled = true
		button.modulate = LOCKED_MODULATE

func _is_networked_lobby() -> bool:
	return _action != "local"

func _is_lobby_host() -> bool:
	return _action == "host" and multiplayer.multiplayer_peer != null and multiplayer.is_server()

## ⚠️ EVERY OUTGOING RPC FROM A BUTTON PRESS HAS TO GO THROUGH THIS FIRST.
## A client sits in this screen for the whole handshake — `join_game()` returns
## the instant the socket is opened, not when the connection is up — so there is
## a real, clickable window in which the peer exists but is not connected yet.
## Calling `.rpc()` in that window throws "trying to call an RPC via a
## multiplayer peer which is not connected", which is the same trap `main.gd`
## documents at `_start_joining` and hit for real in a two-instance test.
func _can_rpc() -> bool:
	if not _is_networked_lobby() or not multiplayer.has_multiplayer_peer():
		return false
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

# =============================================================================
# Connection events
# =============================================================================

func _on_connected_to_host() -> void:
	# The host answers with `_rpc_sync_state` from its own `_on_peer_joined`,
	# which is what fills in the seats, the ready flags, the map and the mode.
	seat_heading.text = "LOBBY  ·  CONNECTED"
	_show_addresses(PackedStringArray([GameLaunch.pending_join_address]))
	status_label.text = "Connected. Pick your character, then press READY."

func _on_connection_failed() -> void:
	GameLaunch.pending_status_message = "Could not reach that host."
	get_tree().change_scene_to_file(MULTIPLAYER_SETUP_PATH)

func _on_server_disconnected() -> void:
	GameLaunch.pending_status_message = "Host ended the session."
	get_tree().change_scene_to_file(MULTIPLAYER_SETUP_PATH)

func _on_peer_joined(peer_id: int) -> void:
	if not _is_lobby_host():
		return
	# Auto-seat into the first free seat so a lobby is always in a startable
	# state; the player can move afterwards.
	var seat := _first_free_seat()
	if seat >= 0:
		_peer_seats[peer_id] = seat
		_peer_ready[peer_id] = false
	else:
		# ⚠️ NO LONGER A GUARD-ONLY BRANCH. `NetworkManager.MAX_CONNECTIONS` is now
		# wider than the four seats, on purpose — 🧑: *"there could be 4 ppl
		# playing and im a 5th or 6th guy just wathcing."* A peer that connects
		# with every seat already taken is a real, expected spectator, not an
		# impossible state: seat it nowhere and mark it watching directly, rather
		# than leaving it seatless AND not-spectating, which `_refresh_seats()`
		# has no row for. No `_peer_ready` entry either — `_refresh_start_button()`
		# only ever asks about peers IN `_peer_seats`, so a peer absent from both
		# dictionaries is already correctly invisible to the ready gate.
		_peer_spectating[peer_id] = true
	# Full snapshot to the newcomer, then the deltas to everyone (including the
	# newcomer, harmlessly) so nobody is holding a half-built board.
	_rpc_sync_state.rpc_id(peer_id, _peer_seats, _peer_ready,
		GameLaunch.selected_map, SettingsManager.ai_difficulty,
		_peer_spectating)
	_rpc_sync_seats.rpc(_peer_seats, _peer_spectating)
	_refresh_seats()
	_refresh_start_button()

func _on_peer_left(peer_id: int) -> void:
	_peer_seats.erase(peer_id)
	_peer_ready.erase(peer_id)
	_peer_spectating.erase(peer_id)
	_vacated_seats.erase(peer_id)
	if _is_lobby_host():
		_rpc_sync_seats.rpc(_peer_seats, _peer_spectating)
		_refresh_start_button()
	_refresh_seats()

func _first_free_seat() -> int:
	for seat in range(NetworkManagerScript.MAX_PLAYERS):
		if not _peer_seats.values().has(seat):
			return seat
	return -1

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE SEAT AND THE READY GATE, WHICH IS §2.3 AND THE HALF THAT HAD NEVER RUN BESIDE
## A SECOND PEER.
##
## HOST ONLY — `_peer_seats` has exactly one writer and this does not change that.
## Reached from two places, and it matters that both go through here rather than one of
## them doing it inline: a peer that toggles SPECTATE mid-lobby
## (`NetworkManager._rpc_set_spectator`) and a peer that walked in already spectating
## (`NetworkManager._rpc_identify`) are the same state change arriving at two different
## moments, and the second one arrives AFTER `_on_peer_joined` has already given that
## peer a chair.
##
## Three things happen together, and leaving any one of them out is a lobby that hangs:
##   * the seat goes back to the pool, where `main.gd::_fill_empty_slots_with_
##     placeholders` picks it up as an ordinary unclaimed slot — the path that has always
##     filled one. A spectator's slot is not a special kind of empty;
##   * the ready TICK is dropped, because `_refresh_start_button` gates on a tick per
##     SEATED peer and a watcher has nothing to be ready about;
##   * `_peer_spectating` is broadcast, because the other three players are looking at a
##     roster that has to explain where that person went. A seat that silently turns into
##     "· BOT" reads as a disconnect.
func _on_peer_spectator_changed(peer_id: int, spectating: bool) -> void:
	if not _is_lobby_host():
		return
	if spectating == bool(_peer_spectating.get(peer_id, false)):
		# `_rpc_identify` fires this for players too — see its own note. A peer that is
		# already correctly seated must not be re-seated, or the identify packet would
		# move somebody who had just clicked a chair into a different one.
		return
	if spectating:
		if _peer_seats.has(peer_id):
			_vacated_seats[peer_id] = int(_peer_seats[peer_id])
			_peer_seats.erase(peer_id)
		_peer_spectating[peer_id] = true
		_peer_ready.erase(peer_id)
	else:
		_peer_spectating.erase(peer_id)
		var wanted := int(_vacated_seats.get(peer_id, -1))
		_vacated_seats.erase(peer_id)
		if wanted < 0 or _peer_seats.values().has(wanted):
			wanted = _first_free_seat()
		if wanted >= 0:
			_peer_seats[peer_id] = wanted
		_peer_ready[peer_id] = false
	_rpc_sync_seats.rpc(_peer_seats, _peer_spectating)
	_refresh_seats()
	_refresh_start_button()

# =============================================================================
# RPCs
# =============================================================================
# Every one of these lives on the scene root, whose node path is identical on
# every peer (`/root/MatchSetup`) because every peer loads this same scene —
# the same arrangement the lobby it replaces used.

## Host -> one new joiner: the whole board at once, map, mode and bot tier
## included.
## ⚠️ R-09: THE TIER HAD TO BE ADDED HERE AS WELL AS TO `_rpc_sync_config`, AND
## MISSING THIS ONE WOULD HAVE BEEN INVISIBLE. `_rpc_sync_config` only fires when the
## host CHANGES something; a peer that joins a lobby nobody touches afterwards is
## configured entirely by this welcome packet. Leave the tier out and that peer plays
## the host's map and mode against its own difficulty — the exact per-peer split U-8
## fixed, reintroduced through the one path that only runs once.
@rpc("authority", "call_remote", "reliable")
func _rpc_sync_state(seats: Dictionary, ready_states: Dictionary,
		map_id: StringName, difficulty: int,
		spectating: Dictionary = {}) -> void:
	_peer_seats = seats
	_peer_ready = ready_states
	_peer_spectating = spectating
	_apply_host_config(map_id, difficulty)
	_refresh_seats()
	_refresh_primary_button()

## Host -> everyone: the seating changed. ⚠️ `spectating` rides the SAME message as the
## seats and is not given one of its own, for the reason `_on_peer_spectator_changed`
## states: they are one fact. Two messages could land in either order and produce a frame
## in which a peer is drawn both seated and watching.
@rpc("authority", "call_local", "reliable")
func _rpc_sync_seats(seats: Dictionary, spectating: Dictionary = {}) -> void:
	_peer_seats = seats
	_peer_spectating = spectating
	_refresh_seats()

## Host -> everyone: the map or the mode changed.
##
## ⚠️ THIS CLEARS EVERY READY FLAG, deliberately. Readying up is agreement to
## play a specific match; if the host cycles from Eskinita/CAPTURE to Bayan
## Plaza/DENTS afterwards, carrying those ticks forward would start a match
## nobody actually agreed to — silently, since the ticks would still look right.
## The cost is that a host who fiddles with the picker makes everyone press
## READY again, which is the correct trade and is said out loud in the status
## line rather than left to be discovered.
@rpc("authority", "call_local", "reliable")
func _rpc_sync_config(map_id: StringName, difficulty: int) -> void:
	_apply_host_config(map_id, difficulty)
	for peer_id in _peer_ready:
		_peer_ready[peer_id] = false
	primary_button.caption = "READY"
	status_label.text = "The host changed the match. Press READY again."
	_refresh_seats()
	_refresh_start_button()

func _apply_host_config(map_id: StringName, difficulty: int) -> void:
	GameLaunch.selected_map = map_id
	_map_index = GameLaunch.map_index()
	# R-09. ⚠️ `persist` FALSE: this is the HOST's choice for THIS match, and writing
	# it into the client's own settings.cfg would silently change what that player
	# gets the next time they host. The bug U-8 fixed was a per-peer value deciding
	# the match; the mirror-image mistake is a per-match value editing a preference.
	_difficulty_index = clampi(difficulty, 0, DIFFICULTIES.size() - 1)
	SettingsManager.set_ai_difficulty(_difficulty_index, false)
	map_value_label.text = String(GameLaunch.MAPS[_map_index]["name"])
	difficulty_value_label.text = String(DIFFICULTIES[_difficulty_index]["label"])
	map_preview.show_map(GameLaunch.MAPS[_map_index])
	# A client cannot change either of these, but the HOST can change them under
	# it - so the explanation has to follow the broadcast as well as the click.
	_refresh_detail()

## Any peer -> host: "I would like seat N." Refereed rather than applied: the
## host is the only writer of `_peer_seats`, so two peers clicking the same seat
## in the same frame cannot both get it. The loser is told, and hears it.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_seat(seat: int) -> void:
	if not _is_lobby_host():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _claim_seat(peer_id, seat):
		_rpc_seat_denied.rpc_id(peer_id)

## Host -> one peer: that seat was taken between your click and my receiving it.
@rpc("authority", "call_remote", "reliable")
func _rpc_seat_denied() -> void:
	AudioManager.play("ui_error") # 4.1
	status_label.text = "Somebody took that character first."

## Any peer -> everyone: I readied, or un-readied. `call_local` so the sender's
## own board updates on the same frame rather than after a round trip.
@rpc("any_peer", "call_local", "reliable")
func _rpc_set_ready(peer_id: int, is_ready: bool) -> void:
	_peer_ready[peer_id] = is_ready
	_refresh_seats()
	if _is_lobby_host():
		_refresh_start_button()

## Host -> everyone: go. Carries the finished seating with it rather than
## letting each peer assemble its own from the board it happens to be holding —
## this is the single message that makes all four peers agree on who is who,
## which map loads and which ruleset runs, and it is the last thing that
## happens before anyone leaves this scene.
##
## `seat_tokens` is keyed by NetworkManager's stable per-install token, not by
## peer id, because peer ids do not survive a reconnect and seats must (B-65).
@rpc("authority", "call_local", "reliable")
func _rpc_begin_match(seat_tokens: Dictionary, map_id: StringName) -> void:
	GameLaunch.seat_tokens = seat_tokens
	GameLaunch.selected_map = map_id
	# B-14: the autoloads survive scene changes, so a second match would resume
	# the first one's score. Reset here as well as on the way in — main.gd resets
	# defensively too, and three cheap resets beat one missed one.
	MatchManager.reset()
	RoundManager.reset()
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

# =============================================================================
# Selectors
# =============================================================================

func _on_map_prev() -> void:
	_cycle_map(-1)

func _on_map_next() -> void:
	_cycle_map(1)

func _cycle_map(step: int) -> void:
	AudioManager.play("ui_click") # 4.1
	_map_index = posmod(_map_index + step, GameLaunch.MAPS.size())
	_apply_map()
	_broadcast_config()

## The one place the map selection is applied, so the name in the slot, the map
## the match will load and the map behind the UI cannot disagree — the backdrop
## IS the selection, not a picture of it.
func _apply_map() -> void:
	var entry: Dictionary = GameLaunch.MAPS[_map_index]
	map_value_label.text = String(entry["name"])
	GameLaunch.selected_map = entry["id"]
	map_preview.show_map(entry)
	_refresh_detail() # the explanation follows the selection - see _refresh_detail


func _on_difficulty_prev() -> void:
	_cycle_difficulty(-1)

func _on_difficulty_next() -> void:
	_cycle_difficulty(1)

func _cycle_difficulty(step: int) -> void:
	AudioManager.play("ui_click") # 4.1
	_difficulty_index = posmod(_difficulty_index + step, DIFFICULTIES.size())
	_apply_difficulty()
	_broadcast_config()

## R-09. Writes the tier through SettingsManager rather than at AIController
## directly, so the one function that stores it is also the one that applies it —
## see `set_ai_difficulty`'s own note on why those cannot be separate steps here.
func _apply_difficulty() -> void:
	var tier: Dictionary = DIFFICULTIES[_difficulty_index]
	difficulty_value_label.text = String(tier["label"])
	SettingsManager.set_ai_difficulty(int(tier["id"]))
	_refresh_detail()

## Solo changes nothing but its own copy; a host pushes map, mode and the bot
## tier to every client. A client never reaches here at all — its arrows are
## disabled.
func _broadcast_config() -> void:
	if _is_lobby_host():
		_rpc_sync_config.rpc(GameLaunch.selected_map, SettingsManager.ai_difficulty)

## Opens the CHARACTER panel in place rather than changing scene — see
## `character_select.gd`'s own note for why a scene change would be wrong here
## (it would tear down the live 3D backdrop, and on a client the ENet connection
## and the whole lobby board, behind a panel about to be closed).
func _on_character_pressed() -> void:
	AudioManager.play("ui_click") # 4.1
	character_panel.visible = true

## ⚠️ A CHARACTER CHANGE UN-READIES YOU, for the same reason a seat change does:
## READY means "I am happy to play THIS", and the Prop skins now carry the kit
## that Prop fights with (`character_roster.gd`'s `ability` field), so a pick
## made after readying would change what you brought without changing the tick.
func _on_character_panel_closed() -> void:
	character_panel.visible = false
	_refresh_character_button()
	if not _can_rpc():
		return
	var peer_id := multiplayer.get_unique_id()
	# NetworkManager republishes this peer's picks to the host on its own; all
	# this has to do is retract a ready that is no longer about the same match.
	if bool(_peer_ready.get(peer_id, false)):
		primary_button.caption = "READY"
		status_label.text = "Character changed. Press READY again."
		_rpc_set_ready.rpc(peer_id, false)

## The button doubles as the readout, so the three picks are visible without
## opening the panel — which matters most for the two Prop skins, since those
## decide the kit and not only the colour.
func _refresh_character_button() -> void:
	character_button.text = "%s · %s · %s  ▸" % [
		_entry_name(CharacterRoster.ROSTER, GameLaunch.character_index()),
		_entry_name(CharacterRoster.CANS, GameLaunch.can_index()),
		_entry_name(CharacterRoster.SLIPPERS, GameLaunch.slipper_index())]
	_refresh_detail()

static func _entry_name(list: Array[Dictionary], index: int) -> String:
	if index < 0 or index >= list.size():
		return "?"
	return String(list[index]["name"])

## Says what the Prop picks actually buy, and — when the player is sitting in a
## Person seat — says plainly that they buy nothing for THAT unit yet, rather
## than letting them believe a kit choice applies to a character it does not.
## Checklist 1.3 (does a Person get its own roster?) is 🧑 HUMAN-owned and still
## open; until it is answered every Person shares one Tag/Throw.
## ⚠️ ONE FUNCTION, THREE LINES, CALLED FROM EVERY SELECTOR. Human ask: *"whenever
## a player selects or moves to a Map, Mode or Character, the explanation text
## should dynamically update to explain the selection."*
##
## Before this, the detail line described the CHARACTER pick and nothing else, so
## cycling the map or the mode changed a single word in a slot and explained
## nothing — which for the mode is a real problem, because CAPTURE and DENTS are
## two different games and the picker gave the player no way to find that out
## short of playing both.
##
## Every caller that can change any of the three routes through here
## (`_apply_map`, `_apply_mode`, `_on_seat_pressed`, `_refresh_seats`,
## `_refresh_character_button`, and the host-config RPC), so there is no path that
## changes a selection and leaves the explanation describing the previous one.
## ⚠️ ONE TOPIC AT A TIME — 🧑 human call, 2026-07-30: *"i want the description
## for eskinita/capture/character to only show up when i highlight it, example i
## highlight map, it will show map desc but if i highlight mode or other stuff,
## that text box will change."*
##
## This used to concatenate ALL FOUR explanations into one Label every refresh,
## and that was not only noisy — it was the LAYOUT BUG in the same report. The
## left column is a VBox whose height is the sum of its children, and an
## `autowrap_mode = 2` Label's minimum height is however tall the wrapped text
## turns out to be. Four paragraphs measured 277 px at 1080p and left `BackButton`
## ending at y=1063 of 1080: seventeen pixels of margin, held up by nothing but
## the particular strings that happened to be selected. Picking DENTS + HARD +
## an OBJECT seat — all three longer than the defaults — is enough to push BACK
## off the bottom, which is exactly what the human photographed.
##
## So the fix is BOTH halves and neither alone is sufficient: show one topic, and
## give the box a FIXED height (`DetailBox` in the scene, `clip_contents`) so the
## column's geometry no longer depends on the copy at all. `_detail_height_probe`
## in `ui_layout_probe.gd` asserts the longest topic still fits inside it.
func _refresh_detail() -> void:
	detail_label.text = detail_text_for(_detail_topic)

## Split out from `_refresh_detail` so `ui_layout_probe.gd` can ask for every
## topic's text without driving the screen through four hover events.
func detail_text_for(topic: DetailTopic) -> String:
	match topic:
		DetailTopic.MAP:
			var map_entry: Dictionary = GameLaunch.MAPS[_map_index]
			return "%s   %s" % [String(map_entry["name"]), String(map_entry["tagline"])]
		DetailTopic.MODE:
			# Kept as a topic rather than removed from the enum: `ui_layout_probe.gd`
			# indexes DetailTopic by int, so deleting a member would silently shift
			# DIFFICULTY and SEAT underneath it.
			return "%s   %s" % [RULESET_LABEL, RULESET_DETAIL]
		DetailTopic.DIFFICULTY:
			return "%s   %s" % [
				String(DIFFICULTIES[_difficulty_index]["label"]),
				String(DIFFICULTIES[_difficulty_index]["detail"])]
		_:
			return _seat_detail()

## Called from every row's hover AND focus. Both, not either: hover is what the
## human described, and focus is the same gesture on a keyboard or a pad, which
## is the only way this screen is navigable without a mouse.
##
## Guarded on a real change so that sweeping the pointer across a row does not
## rebuild the Label once per mouse-enter of every child control.
func _focus_detail(topic: DetailTopic) -> void:
	if _detail_topic == topic:
		return
	_detail_topic = topic
	_refresh_detail()

## Every control that, when highlighted, should make the box explain `topic`.
## Containers are included so hovering the caption or the empty space in a row
## counts as highlighting that row — the human's example is "i highlight map",
## not "i highlight the map arrow".
func _wire_detail_focus(topic: DetailTopic, controls: Array[Control]) -> void:
	for control in controls:
		if control == null:
			continue
		control.mouse_entered.connect(func() -> void: _focus_detail(topic))
		control.focus_entered.connect(func() -> void: _focus_detail(topic))

## What the seat the player is sitting in actually does, and what their picks buy
## it. Split out so `_refresh_detail` above reads as the three things it is
## explaining rather than as a branch.
func _seat_detail() -> String:
	# The four seat rows go dead while spectating (`_refresh_seats`), so the detail box is
	# the only thing left that can explain WHY they are dead. Says what the mode actually
	# does rather than just naming it — the same standard the map and mode copy is held to.
	if GameLaunch.spectator:
		return "SPECTATOR   You take no seat and control no character: a free camera with no body, flying anywhere and through anything. Your slot is played by a bot, so the match is still four players. WASD to fly, mouse to look, TAB to follow a unit, wheel for speed."
	# ⚠️⚠️ ONE SEAT DESCRIPTION, NOT TWO. This used to branch on PERSON vs OBJECT and
	# describe the seat as either "the person" or "the object you field" — a 2v2 in
	# which the lata and the tsinelas were playable units. They are props now
	# (`Design.md` §12) and all four seats are the same kind of thing, so the copy
	# says what the ROUND does to you instead of what kind of unit you are.
	var seat := _local_seat()
	var opens_as_taya := seat == MatchManager.defender_slot_for(1)
	var role_line := "You defend FIRST — round 1 is yours in the box." if opens_as_taya \
		else "You attack first; your turn as taya comes in round %d." % [seat + 1]
	return "P%d   %s Every player is taya exactly once across the four rounds, and scores carry the whole way. Your lata and tsinelas picks are %s and %s — they tint the props everyone sees." % [
		seat + 1, role_line,
		_entry_name(CharacterRoster.CANS, GameLaunch.can_index()),
		_entry_name(CharacterRoster.SLIPPERS, GameLaunch.slipper_index())]

## The ability a skin brings, named rather than pathed. Falls back to the skin's
## own name when an entry has no `ability` — a roster entry added without one is
## a real possibility and is not worth erroring over.
static func _kit_name(list: Array[Dictionary], index: int) -> String:
	if index < 0 or index >= list.size():
		return "the default kit"
	var path := String(list[index].get("ability", ""))
	if path == "":
		return "the default kit"
	# ⚠️ WAS `load(path) as AbilityBase`. Abilities are deleted; a roster entry's
	# `ability` field is now an inert leftover, so the skin's own name is the honest
	# answer rather than a kit that does not exist.
	return path.get_file().get_basename().capitalize()

# =============================================================================
# Seats
# =============================================================================

## Seat 0..3 with exactly the meaning `main.gd` gives its join index — team is
## `seat / 2`, and the even seat of each pair is the Person. Named here so the
## board and the spawner cannot drift apart.
static func _seat_is_person(seat: int) -> bool:
	return seat % 2 == 0

## ⚠️ THESE WERE `TAO` / `GAMIT` AND ARE NOW ENGLISH — 🧑 human call, 2026-07-30:
## *"only tagalog i want are names and possible skill... use person, lata,
## tsinelas i guess thats fine."* An earlier ask had gone the other way ("update
## the UI to use Filipino terms for gameplay roles") and that is why the words
## were there; the newer instruction supersedes it, and both are recorded so the
## next pass does not flip them back a third time.
##
## ⚠️⚠️ THIS PRINTED "TEAM A · PERSON" / "TEAM B · OBJECT" UNTIL 2026-08-01 AND EVERY
## WORD OF IT DESCRIBED A DELETED GAME. There are no teams, no A/B sides, and no
## OBJECT seats — the lata and the tsinelas are props, not units, and there are four
## equal players (`Design.md` §0, §12). The rendered lobby was showing a four-row
## board labelled with a 2v2 format, above a hint that read *"A team is one person
## and one object"*, on the screen a judge meets before anything else.
##
## A seat is now just a seat: **P1..P4**. The round-1 taya is marked, because that is
## the one thing about a seat that is decided before the match starts and it is the
## only asymmetry left in the lobby — `MatchManager.defender_slot_for(1)` is a pure
## function of the round number, so the board can state it honestly up front.
## ⚠️ NO LONGER `static`. It asks `MatchManager.defender_slot_for()`, which is an
## instance method on the autoload — calling it through the CLASS is a parse error that
## takes this whole script down with it, and the seat labels then silently fall back to
## whatever `MatchSetup.tscn` authored. Its one caller is an instance method anyway.
func _seat_name(seat: int) -> String:
	var label := "P%d" % [seat + 1]
	if seat == MatchManager.defender_slot_for(1):
		label += "  ·  TAYA FIRST"
	return label

## Which seat this peer is in right now. Solo has no peers, so it reads the
## GameLaunch value the seat buttons write directly.
func _local_seat() -> int:
	if not _is_networked_lobby():
		return GameLaunch.solo_seat
	return int(_peer_seats.get(multiplayer.get_unique_id(), -1))

func _on_seat_pressed(seat: int) -> void:
	if not _is_networked_lobby():
		AudioManager.play("ui_click") # 4.1
		GameLaunch.solo_seat = seat
		_refresh_seats()
		_refresh_detail()
		return
	if _local_seat() == seat:
		return # already sitting there; not an error, just nothing to do
	AudioManager.play("ui_click")
	if _is_lobby_host():
		if not _claim_seat(multiplayer.get_unique_id(), seat):
			AudioManager.play("ui_error")
			status_label.text = "That character is taken."
		return
	if not _can_rpc():
		AudioManager.play("ui_error")
		status_label.text = "Not connected to the host yet."
		return
	_rpc_request_seat.rpc_id(1, seat)

## HOST ONLY — the referee. Returns false if the seat is already somebody
## else's, in which case nothing at all changes.
##
## Moving seats clears that player's ready flag on purpose: READY means "I am
## happy to play THIS", and changing which character you are about to play makes
## the previous tick a statement about something else.
func _claim_seat(peer_id: int, seat: int) -> bool:
	if seat < 0 or seat >= NetworkManagerScript.MAX_PLAYERS:
		return false
	for other_id in _peer_seats:
		if other_id != peer_id and int(_peer_seats[other_id]) == seat:
			return false
	_peer_seats[peer_id] = seat
	_peer_ready[peer_id] = false
	_rpc_sync_seats.rpc(_peer_seats, _peer_spectating)
	_rpc_set_ready.rpc(peer_id, false)
	_refresh_seats()
	_refresh_start_button()
	return true

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE FIFTH SEAT, AND IT IS BUILT IN CODE RATHER THAN ADDED TO `MatchSetup.tscn`.
## `Design.md` §9.
##
## Spectating is seat -1: no team, no role, no character. It belongs beside the four
## seat rows because it is the same question those rows ask — *which of these am I* —
## and putting it anywhere else on the screen would make it read as a mode switch that
## discards the map and difficulty the player just chose.
##
## Built here because `MatchSetup.tscn` is a scene file with `%`-unique seat buttons and
## a hand-tuned layout; a fifth authored row means editing a shared scene for a control
## whose entire state is one bool. It is styled off the same `wood_style()` the rest of
## the screen uses, so it cannot drift from the four buttons it sits under.
##
## ⚠️ IT **DOES** CLEAR THE SEAT NOW, and the note that used to sit here said the
## opposite. "Keeps whichever seat they had highlighted" is not compatible with §2.3 —
## *claims no seat, its slot bot-filled* — because a chair still listed under your peer
## id is a chair the other three players cannot sit in, for a match you are not playing.
## The seat is released to the bot pool the moment you press this and REMEMBERED
## host-side (`_vacated_seats`), so un-spectating puts you straight back into it if
## nobody took it meanwhile and into the first free one if they did. That is what the old
## note was actually after, and this is the version of it that survives a second peer.
##
## ⚠️ IT SITS ON THE HEADING ROW, NOT AT THE BOTTOM OF THE SEAT LIST — 🧑 human call,
## 2026-07-31, with a screenshot and an arrow pointing at the top right of the panel.
##
## It was a fifth full-width plank under the four seat rows, styled to match them exactly.
## That was the wrong read and the styling is what made it wrong: spectating is NOT a
## fifth seat, it is the decision to take no seat at all, and a control that looks
## identical to the four things it opts out of says the opposite. Four planks and then a
## fifth plank is a list of five choices.
##
## On the heading row it is a compact toggle beside "YOUR CHARACTER" — visibly a different
## kind of control, in the corner where a mode switch belongs, and it stops competing with
## the roster for the eye. The four seats stay a list of four.
##
## ⚠️ THE HEADING IS REPARENTED INTO AN HBOX AT RUNTIME rather than the row being authored
## in `MatchSetup.tscn`. Same reason the button itself is built in code: the whole state is
## one bool, and `MatchSetup.tscn` is a shared-lock scene with `%`-unique nodes and a
## hand-tuned layout. `%SeatHeading` keeps resolving after the move — unique names are
## owner-scoped, not parent-scoped.
##
## ⚠️ AND THE HEADING LOSES ITS WRAP, DELIBERATELY. It is `autowrap_mode = 2` in the scene,
## which is correct for a full-width Label and wrong inside an HBox: in the lobby it reads
## "LOBBY  ·  HOST 192.168.1.12", and wrapping that would grow the row's height and shove
## the button around as the address changes. Ellipsis instead, with the heading taking the
## expand so the button is pinned right whatever the heading says.
var _spectate_button: Button = null

## Compact — this is a toggle, not a roster row — but sized so the WORD fills it. The
## first pass was 300x56 at font 22 and 🧑 called it *"too small/ugly"*: a short label
## floating in a wide empty plank reads as a control that failed to load, not as a button.
## The text now carries the box instead of rattling around in it.
## ⚠️ SHRUNK FROM 286x62 / 27 ON 2026-08-01, AND THE REASON IS THE HEADING BESIDE
## IT. 🧑, with a screenshot of `CONNECTING TO 25.…`: *"cant see ip also make it
## copy pastable rlly easy, make spectate button smaller so that whole ip can be
## seen, make ip smaller too"*. The heading and this button share one HBox and the
## heading takes the ellipsis, so every pixel this button holds is a pixel of
## address the player cannot read. It is a toggle with one short word in it and it
## does not need a third of the panel.
##
## ⚠️ The address does NOT live in that heading any more either — see
## `_build_address_row()`. Shrinking the button alone would have bought a few more
## characters of a string that still could not be selected or copied.
const SPECTATE_BUTTON_SIZE: Vector2 = Vector2(176, 46)
const SPECTATE_FONT_SIZE: int = 19

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE ON STATE IS A FILLED AMBER PLANK WITH DARK LETTERING, AND IT IS BUILT HERE
## RATHER THAN INHERITED. 🧑, 2026-07-31: *"spectate looks too small/ugly, especially when
## its turned on."*
##
## Inherited, "on" was the `WoodButton` variation's PRESSED face — a dark sunk plank with a
## bright yellow ring around it. That is the right look for *"this button is being held
## down right now"* and the wrong one for *"this mode is active": a hairline ring is the
## weakest signal the theme has, and it was carrying the single most important piece of
## state on the screen — whether you are in the match at all — on a screen where every
## other row had simultaneously gone dim.
##
## Filled AMBER with INK lettering is the inversion, and it is the front end's own
## language rather than a new colour: `AMBER` is already "headings, values, hover
## lettering", i.e. the lit thing. A lit slab beside four dimmed planks says which one is
## live without anybody having to read it.
##
## ⚠️ FOUR STYLEBOXES, NOT TWO, because a toggle has a hover state in BOTH positions and
## Godot draws `hover_pressed` for the on-and-hovered case. Miss it and hovering an active
## toggle flips it back to looking inactive for as long as the pointer is over it — the
## exact moment the player is about to click, which is the worst possible time to lie.
## The font colours are set per state for the same reason: CREAM on wood, INK on amber,
## and no per-frame code deciding which.
const SPECTATE_ON: Color = Color("ffba00")      ## == UiTheme.AMBER, the lit face
const SPECTATE_ON_HOVER: Color = Color("ffd45c") ## the same amber, lifted

func _build_spectate_button() -> void:
	if seat_buttons.is_empty() or seat_heading == null:
		return
	var rows := seat_heading.get_parent() as Container
	if rows == null:
		return
	var header_row := HBoxContainer.new()
	header_row.name = "HeaderRow"
	header_row.add_theme_constant_override("separation", 18)
	rows.add_child(header_row)
	rows.move_child(header_row, seat_heading.get_index())
	rows.remove_child(seat_heading)
	header_row.add_child(seat_heading)
	seat_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seat_heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# See the note above: wrap off, ellipsis on, so a long host address cannot reflow the
	# row or push the button out of the corner.
	seat_heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	seat_heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	_spectate_button = Button.new()
	_spectate_button.name = "SpectateButton"
	_spectate_button.toggle_mode = true
	_spectate_button.button_pressed = GameLaunch.spectator
	_spectate_button.focus_mode = Control.FOCUS_ALL
	# ⚠️ NO `theme_type_variation` — the four states below fully replace it. Leaving
	# `WoodButton` on as well would layer this lane's `pressed` under the variation's and
	# make which one wins depend on theme load order.
	_spectate_button.custom_minimum_size = SPECTATE_BUTTON_SIZE
	_spectate_button.add_theme_font_size_override("font_size", SPECTATE_FONT_SIZE)
	_spectate_button.add_theme_stylebox_override("normal",
		UiTheme.wood_style(UiTheme.WOOD_DEEP, UiTheme.WOOD_EDGE))
	_spectate_button.add_theme_stylebox_override("hover",
		UiTheme.wood_style(UiTheme.WOOD_MID, UiTheme.AMBER))
	_spectate_button.add_theme_stylebox_override("pressed",
		UiTheme.wood_style(SPECTATE_ON, UiTheme.WOOD_EDGE))
	_spectate_button.add_theme_stylebox_override("hover_pressed",
		UiTheme.wood_style(SPECTATE_ON_HOVER, UiTheme.WOOD_EDGE))
	# The focus ring is the theme's own focus colour, so a keyboard player sees the same
	# emphasis here as everywhere else on the screen.
	_spectate_button.add_theme_stylebox_override("focus",
		UiTheme.wood_style(Color(0, 0, 0, 0), UiTheme.IMPACT))
	_spectate_button.add_theme_color_override("font_color", UiTheme.CREAM)
	_spectate_button.add_theme_color_override("font_hover_color", UiTheme.AMBER)
	_spectate_button.add_theme_color_override("font_pressed_color", UiTheme.INK)
	_spectate_button.add_theme_color_override("font_hover_pressed_color", UiTheme.INK)
	_spectate_button.add_theme_color_override("font_focus_color", UiTheme.CREAM)
	_spectate_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_spectate_button.clip_text = true
	_spectate_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_row.add_child(_spectate_button)
	# THE FOCUS ORDER, EXPLICITLY. It now sits ABOVE the roster rather than below it, so
	# the neighbours are the other way round from the first version of this control. Left
	# unset, a keyboard player arrowing up from the first seat would fall off the list and
	# never find it — reachable by keyboard is half of § THE REACHABILITY RULE.
	_spectate_button.focus_neighbor_bottom = seat_buttons[0].get_path()
	seat_buttons[0].focus_neighbor_top = _spectate_button.get_path()
	_spectate_button.pressed.connect(_on_spectate_pressed)
	# 4.1: a plain Button carries no audio of its own — same wiring the four seat rows get.
	_spectate_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
	_refresh_spectate_button()
	_build_address_row(rows, header_row.get_index() + 1)


## ---------------------------------------------------------------------------
## ⚠️⚠️ THE HOST ADDRESS GETS ITS OWN SELECTABLE ROW, BECAUSE A HEADING CANNOT BE
## COPIED AND WAS NOT EVEN LEGIBLE.
##
## 🧑 2026-08-01, with a screenshot reading `CONNECTING TO 25.…`: *"cant see ip
## also make it copy pastable rlly easy, make spectate button smaller so that
## whole ip can be seen, make ip smaller too"*.
##
## The address used to be interpolated into `%SeatHeading`, which shares an HBox
## with the SPECTATE toggle and carries `OVERRUN_TRIM_ELLIPSIS` — so a Hamachi
## address (`25.x.x.x`, the longest kind this game will ever show) was trimmed to
## four characters, and even when it fit, a `Label` cannot be selected. The player
## was expected to read a dotted quad off a screen and retype it into another
## machine.
##
## ⚠️ A READ-ONLY `LineEdit`, NOT A `Label`. Selection, drag-highlight and Ctrl+C
## all come for free and behave the way every other text field on the OS does; the
## COPY button is for people who will not think to try. It is `editable = false`
## so the text cannot be altered into something that no longer matches the socket
## actually listening.
##
## ⚠️ AND IT OFFERS EVERY ADDRESS, NOT THE BEST ONE. See `host_addresses()`: which
## interface the other four players can reach is not knowable from inside this
## process — the Hamachi one is right for a VPN lobby and the `192.168` one is
## right for a room with one router — so the ranking chooses the DEFAULT and the
## cycle button hands the decision to the human, who knows.
var _address_row: HBoxContainer = null
var _address_edit: LineEdit = null
var _address_copy: Button = null
var _address_cycle: Button = null
var _address_options: PackedStringArray = PackedStringArray()
var _address_index: int = 0

const ADDRESS_FONT_SIZE: int = 20
const ADDRESS_BUTTON_FONT_SIZE: int = 16

func _build_address_row(rows: Container, at_index: int) -> void:
	_address_row = HBoxContainer.new()
	_address_row.name = "AddressRow"
	_address_row.add_theme_constant_override("separation", 10)
	_address_row.visible = false
	rows.add_child(_address_row)
	rows.move_child(_address_row, at_index)

	_address_edit = LineEdit.new()
	_address_edit.name = "AddressEdit"
	_address_edit.editable = false
	_address_edit.selecting_enabled = true
	_address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address_edit.add_theme_font_size_override("font_size", ADDRESS_FONT_SIZE)
	_address_edit.add_theme_color_override("font_color", UiTheme.CREAM)
	_address_edit.add_theme_color_override("font_uneditable_color", UiTheme.CREAM)
	_address_edit.add_theme_stylebox_override("normal",
		UiTheme.wood_style(UiTheme.WOOD_DARK, UiTheme.WOOD_EDGE))
	_address_edit.add_theme_stylebox_override("read_only",
		UiTheme.wood_style(UiTheme.WOOD_DARK, UiTheme.WOOD_EDGE))
	_address_row.add_child(_address_edit)

	_address_copy = _small_button("COPY")
	_address_copy.pressed.connect(_on_address_copy_pressed)
	_address_row.add_child(_address_copy)

	# Only shown when there is genuinely a choice to make.
	_address_cycle = _small_button("OTHER")
	_address_cycle.visible = false
	_address_cycle.pressed.connect(_on_address_cycle_pressed)
	_address_row.add_child(_address_cycle)

	_build_firewall_hint(rows, at_index + 1)

## ⚠️ HOSTING WAS NEVER ACTUALLY RESTRICTED TO ONE MACHINE — see
## `host_addresses()`'s own note. 🧑 2026-08-01, after actually finding it:
## *"its bcz of firewall"*. `create_server()` binds every interface and always
## could; what silently blocks other people in is Windows dropping inbound
## traffic to an app that was never explicitly allowed through, with **zero
## error on the host's own screen** — the host sees nothing wrong because
## nothing IS wrong on its end. That failure mode cannot be detected from
## inside this process (a bound, listening socket looks identical whether the
## firewall lets packets reach it or not), so this is the fix that fits: tell
## the one person who can act on it, next to the address they are about to
## hand out.
var _firewall_hint: Label = null

func _build_firewall_hint(rows: Container, at_index: int) -> void:
	_firewall_hint = Label.new()
	_firewall_hint.name = "FirewallHint"
	_firewall_hint.theme_type_variation = &"MenuCaption"
	_firewall_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_firewall_hint.visible = false
	_firewall_hint.text = ("Nobody connecting? Windows Firewall may be blocking this game" +
		" silently — check Windows Security ▸ Firewall & network protection ▸" +
		" \"Allow an app through firewall\", and make sure both Private and Public are checked.")
	rows.add_child(_firewall_hint)
	rows.move_child(_firewall_hint, at_index)


func _small_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	button.theme_type_variation = &"WoodButton"
	button.add_theme_font_size_override("font_size", ADDRESS_BUTTON_FONT_SIZE)
	button.custom_minimum_size = Vector2(96, 40)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
	return button


## Shows `options` in the row, defaulting to the first. Hides the row entirely for
## Single Player, which has no address and no one to give it to.
func _show_addresses(options: PackedStringArray) -> void:
	if _address_row == null:
		return
	_address_options = options
	_address_index = 0
	_address_row.visible = not options.is_empty()
	if options.is_empty():
		return
	_address_cycle.visible = options.size() > 1
	_refresh_address_text()


func _refresh_address_text() -> void:
	if _address_edit == null or _address_options.is_empty():
		return
	var shown := String(_address_options[_address_index])
	_address_edit.text = shown
	# ⚠️ THE TOOLTIP CARRIES THE WHOLE LIST. With more than one adapter the player
	# needs to know what they are cycling between without clicking through it.
	_address_edit.tooltip_text = "\n".join(Array(_address_options))
	# ⚠️ IT SAYS "IP", AND THE BARE FRACTION IT USED TO SHOW WAS READ AS A PLAYER COUNT.
	# 🧑 2026-08-02, looking at a lobby that showed `1/3`: *"why 1/3 if spectating?"* —
	# reasonably, because the button sits in the top row beside COPY on a screen whose
	# whole subject is four seats, and `1/3` in that company reads as one-of-three
	# players. It has never meant that. It is which of this machine's local addresses is
	# in the field: a PC with a LAN card, a Hamachi adapter and a WSL bridge has three,
	# and this cycles them. The count is the number of ADAPTERS, which is why it is 3 and
	# not 4 — nothing here is capped at three of anything.
	if _address_cycle != null and _address_options.size() > 1:
		_address_cycle.text = "IP %d/%d" % [_address_index + 1, _address_options.size()]


func _on_address_copy_pressed() -> void:
	if _address_options.is_empty():
		return
	AudioManager.play("ui_click")
	DisplayServer.clipboard_set(String(_address_options[_address_index]))
	_address_copy.text = "COPIED"
	_address_edit.select_all()
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(_address_copy):
		_address_copy.text = "COPY"


func _on_address_cycle_pressed() -> void:
	if _address_options.size() <= 1:
		return
	AudioManager.play("ui_click")
	_address_index = (_address_index + 1) % _address_options.size()
	_refresh_address_text()

func _on_spectate_pressed() -> void:
	AudioManager.play("ui_click")
	GameLaunch.spectator = _spectate_button.button_pressed
	# ⚠️ THE HOST HAS TO BE TOLD, AND THIS IS THE ONLY THING THAT TELLS IT. Everything
	# downstream — the ready gate, the spawn skip, the bot that fills the vacated slot —
	# reads `NetworkManager.is_spectator()`, which is fed by a packet sent BEFORE this
	# screen existed. See `NetworkManager.publish_spectator`. A no-op in Single Player,
	# which reads `GameLaunch.spectator` directly and has nobody to tell.
	NetworkManager.publish_spectator(GameLaunch.spectator)
	_refresh_spectate_button()
	_refresh_seats()
	_refresh_detail()
	_refresh_primary_button()

func _refresh_spectate_button() -> void:
	if _spectate_button == null or not is_instance_valid(_spectate_button):
		return
	# ⚠️ ONE WORD. The state IS the styling now — a lit amber slab versus a dark one — so
	# the label does not also have to carry a count, a mode name and an explanation. The
	# earlier version appended "· 1 WATCHING" here and that is what forced the font down to
	# a size 🧑 called ugly: the button was sized around its rarest string instead of its
	# normal one. The count moved to the hint line below, which is a sentence and can hold
	# a clause without changing shape.
	_spectate_button.text = "SPECTATING" if GameLaunch.spectator else "SPECTATE"
	_refresh_seat_hint()

## The descriptive line under the heading, plus the one thing about the lobby that no seat
## row can show: somebody is here who is not on the board. Kept off the toggle so that
## button can be sized for the word it almost always shows.
func _refresh_seat_hint() -> void:
	if seat_hint == null or _seat_hint_base == "":
		return
	var others := 0
	for peer_id in _peer_spectating:
		if peer_id != multiplayer.get_unique_id():
			others += 1
	if others <= 0:
		seat_hint.text = _seat_hint_base
		return
	seat_hint.text = "%s  ·  %d %s watching." % [_seat_hint_base, others,
		"player is" if others == 1 else "players are"]

## ⚠️ CACHED, because `_refresh_seat_hint` rewrites the label and would otherwise append
## to its own output every time the board syncs. The three `_setup_*` branches each write
## the base copy once; this is the copy they wrote.
var _seat_hint_base: String = ""

## ⚠️ A SPECTATOR IS NOT IN THE READY COUNT, SO IT MUST NOT BE OFFERED THE READY BUTTON.
## Leaving it live let a watching client press READY and sit in `_peer_ready` holding a
## tick for a seat it does not have, while `_refresh_start_button` — which iterates
## `_peer_seats` — never looked at it. Harmless by luck rather than by design, and it
## told the player they were part of a gate they had just left. The HOST keeps its START
## button either way: somebody has to be able to begin the match and it is the only peer
## that can (the same carve-out `NetworkManager.playing_peer_count()` documents).
func _refresh_primary_button() -> void:
	if not _is_networked_lobby():
		return
	primary_button.disabled = GameLaunch.spectator
	if GameLaunch.spectator:
		primary_button.caption = "SPECTATING"
		status_label.text = ("Watching. Your seat is played by a bot"
			+ ("; press START MATCH when everyone is ready." if _is_lobby_host()
				else " and the others do not wait for you."))
		return
	# Back into the gate. The tick was dropped when the seat was released, so this is
	# always the un-readied caption rather than whatever was showing before.
	primary_button.caption = "READY"
	status_label.text = ""

func _refresh_seats() -> void:
	_refresh_spectate_button()
	for seat in range(seat_buttons.size()):
		var button := seat_buttons[seat]
		button.text = _seat_row_text(seat)
		# ⚠️ `disabled` MEANS "SOMEBODY ELSE HAS THIS", NOT "THIS IS YOURS".
		# Your own seat was disabled here first, which was exactly backwards on
		# screen: the wood theme's disabled state is a sunk, dimmed plank, so the
		# one row the player most needs to find — their own — was the only one
		# that read as unavailable. Your seat stays live (pressing it is a no-op,
		# handled in `_on_seat_pressed`) and is marked in the text instead.
		# ⚠️ AND A SPECTATOR'S SEAT ROWS ARE ALL DEAD. Leaving them live would let a
		# player highlight a chair while the button underneath says they are watching —
		# two controls asserting different things about the same choice, which is the
		# class of confusion the seat rows' own `disabled` note is already about.
		button.disabled = GameLaunch.spectator 			or _occupant_of(seat) not in [-1, multiplayer.get_unique_id()]
	_refresh_detail()

## A small, human-sized number for a peer — 1 for the host, then 2, 3, 4 in peer
## order. ⚠️ NOT the peer id: ENet hands out ids like 816586678, and the lobby
## read "PLAYER 816586678" until this existed. Derived by sorting the seat map's
## keys, which every peer holds identically (the host broadcasts it), so the same
## player is the same number on everybody's screen.
## ⚠️ THE UNION OF SEATED AND WATCHING PEERS, not `_peer_seats` alone. Numbering off the
## seat map only meant that the moment somebody pressed SPECTATE, every player numbered
## after them was renumbered on all four screens — PLAYER 3 became PLAYER 2 while they
## were looking at it, for a reason nothing on the board explained.
func _player_number(peer_id: int) -> int:
	var ids: Array = _peer_seats.keys()
	for id in _peer_spectating:
		if not ids.has(id):
			ids.append(id)
	ids.sort()
	return ids.find(peer_id) + 1

## The peer sitting in `seat`, or -1 for a seat no human holds (which `main.gd`
## fills with an AI rather than leaving empty). Always -1 in solo, which has no
## peers at all — the solo board reads `GameLaunch.solo_seat` directly.
func _occupant_of(seat: int) -> int:
	if not _is_networked_lobby():
		return -1
	for peer_id in _peer_seats:
		if int(_peer_seats[peer_id]) == seat:
			return peer_id
	return -1

## The name that peer published on its identify packet, or its seat label if it has
## none. Read through `picks_for()` rather than off `peer_characters`, which is
## host-only by design — a client asking about somebody else's picks gets -1, and a
## row that resolved on the host and blanked everywhere else is worse than no name.
func _peer_display_name(peer_id: int) -> String:
	var picks: Dictionary = NetworkManager.picks_for(peer_id)
	var who := String(picks.get("name", "")).strip_edges()
	return who if who != "" else "PLAYER %d" % [_player_number(peer_id)]

func _seat_row_text(seat: int) -> String:
	var label := _seat_name(seat)
	if not _is_networked_lobby():
		if seat == GameLaunch.solo_seat:
			return "%s   ◀ YOU" % label
		return "%s   · BOT" % label

	var occupant := _occupant_of(seat)
	if occupant == -1:
		# Not "empty": `main.gd::_fill_empty_slots_with_placeholders` gives every
		# unclaimed seat a real AI, so a two-human lobby is a complete 2v2 rather
		# than a match with two missing players. Saying "BOT" is what makes a
		# lone host obviously startable — and it is set in the same caps as the
		# rest of the row so it reads as a roster entry, not as a footnote.
		return "%s   · BOT" % label
	# ⚠️⚠️ THE NAME, NOT "PLAYER 3" — § CHECKLIST 1.5. `NetworkManager.picks_for()`
	# has carried the name on the identify packet since the pivot and neither lobby
	# screen ever read it, so a four-player lobby introduced everyone as a seat
	# number. That is the first screen a judge sees and the first place a player
	# looks for themselves.
	#
	# ⚠️ IT FALLS BACK TO "PLAYER n" RATHER THAN TO EMPTY. An unset name is legal
	# (`Design.md` §10: empty falls back to the seat label), so the row has to stay
	# populated for a peer who never opened Settings — the same contract
	# `CharacterBase.display_name()` keeps in the match itself.
	var who := "YOU" if occupant == multiplayer.get_unique_id() \
		else _peer_display_name(occupant)
	# ⚠️ Deliberately does NOT show the occupant's character picks.
	# `NetworkManager.peer_characters` is HOST-ONLY by design (see its own doc) —
	# a client asking about somebody else gets -1 — so a row that named other
	# players' picks would be right on the host's screen and wrong on everyone
	# else's. The picks arrive replicated with the spawn; the lobby does not need
	# to duplicate that.
	var tick := "✓" if bool(_peer_ready.get(occupant, false)) else "…"
	return "%s   · %s  %s" % [label, who, tick]

func _refresh_start_button() -> void:
	if not _is_lobby_host():
		return
	# No minimum peer COUNT: unclaimed seats are filled with real AI by
	# `main.gd`, so a lone host is a complete, startable 2v2 rather than an
	# incomplete lobby waiting for a second human.
	for peer_id in _peer_seats:
		if not bool(_peer_ready.get(peer_id, false)):
			start_button.disabled = true
			return
	# ⚠️ AN ALL-SPECTATOR LOBBY IS STARTABLE, AND IT IS THE FILMING CASE. `_peer_seats` is
	# empty when the only human present is watching — four bots, nobody seated — and the
	# empty-board guard below would have disabled the one button that can begin the match
	# a spectator is there to film. §2.4: a spectating host still runs the match.
	start_button.disabled = _peer_seats.is_empty() and _peer_spectating.is_empty()

# =============================================================================
# Launch
# =============================================================================

## Solo: this IS the start button. Networked: this is READY.
func _on_primary_pressed() -> void:
	if not _is_networked_lobby():
		_launch_solo()
		return
	if not _can_rpc():
		AudioManager.play("ui_error")
		status_label.text = "Not connected to the host yet."
		return
	var peer_id := multiplayer.get_unique_id()
	var now_ready := not bool(_peer_ready.get(peer_id, false))
	primary_button.caption = "UNREADY" if now_ready else "READY"
	# The host is not waiting for the host. It read "Waiting for the host to
	# start…" on the hosting machine until this branch existed.
	if not now_ready:
		status_label.text = ""
	elif _is_lobby_host():
		status_label.text = "Ready. START MATCH goes live once every seated player is."
	else:
		status_label.text = "Waiting for the host to start…"
	_rpc_set_ready.rpc(peer_id, now_ready)

func _launch_solo() -> void:
	GameLaunch.seat_tokens.clear() # no tokens without a NetworkManager session
	MatchManager.reset()
	RoundManager.reset()
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

## HOST ONLY. Turns the board into the two dictionaries `main.gd` reads, then
## broadcasts them with the go signal.
func _on_start_pressed() -> void:
	if not _is_lobby_host():
		return
	var seat_tokens: Dictionary = {}
	for peer_id in _peer_seats:
		var seat: int = int(_peer_seats[peer_id])
		# 4.3/B-65: the STABLE per-install token, not the peer id — a peer that
		# drops and rejoins comes back under a brand-new peer id and has to land
		# in the seat it actually chose, not the next free one.
		var token: String = NetworkManager.peer_tokens.get(peer_id, "")
		if token != "":
			seat_tokens[token] = seat
	_rpc_begin_match.rpc(seat_tokens, GameLaunch.selected_map)

func _on_back_pressed() -> void:
	AudioManager.play("ui_back") # 4.1
	if _is_networked_lobby():
		# Leaving the lobby has to actually tear the session down — a host that
		# walked away with its server still up would keep accepting joins into a
		# lobby nobody is refereeing.
		NetworkManager.disconnect_network()
		get_tree().change_scene_to_file(MULTIPLAYER_SETUP_PATH)
		return
	get_tree().change_scene_to_file(MODE_SELECT_PATH)
