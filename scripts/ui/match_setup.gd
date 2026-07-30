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
const MODES: Array[Dictionary] = [
	{
		"id": GameLaunchScript.GameMode.OPTION_B, "label": "CAPTURE",
		"detail": "Knock the lata over and keep it down. A fall nobody rights in time ends the round, and five falls ends it outright. The defender wins by tagging the thrower, or by surviving the clock.",
	},
	{
		"id": GameLaunchScript.GameMode.OPTION_A, "label": "DENTS",
		"detail": "The lata carries a health bar instead. Dent it three times to win. The defender can beat a dent back out by standing it up, wins on the clock, or by knocking the tsinelas out of bounds.",
	},
]

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
var _mode_index: int = 0
## R-09. Index into DIFFICULTIES, mirroring _map_index / _mode_index exactly.
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
	_mode_index = _index_for_mode(GameLaunch.game_mode)
	# R-09: the tier is a PREFERENCE with the same lifetime as the map and the
	# character picks, so it opens on whatever was chosen last rather than resetting.
	_difficulty_index = clampi(SettingsManager.ai_difficulty, 0, DIFFICULTIES.size() - 1)

	_wire_selector(map_prev_button, map_next_button, _on_map_prev, _on_map_next)
	_wire_selector(mode_prev_button, mode_next_button, _on_mode_prev, _on_mode_next)
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
	_wire_detail_focus(DetailTopic.SEAT, seat_targets)

	primary_button.pressed.connect(_on_primary_pressed)
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	back_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))

	_apply_map()
	_apply_mode()
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
	seat_hint.text = "A team is one person and one object. The other three are bots, the kids from the street who fill in."
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
	seat_heading.text = "LOBBY  ·  HOST %s" % _lan_address()
	seat_hint.text = "You pick the map and the mode for everyone. Click a seat to move. Empty seats are played by bots."
	primary_button.caption = "READY"
	start_button.visible = true
	start_button.disabled = true

	NetworkManager.player_connected.connect(_on_peer_joined)
	NetworkManager.player_disconnected.connect(_on_peer_left)

	# The host is peer 1 and `peer_connected` never fires for self on a server,
	# so it seats itself. Seat 0 (Team A's Person) rather than "first free": it
	# is the seat `main.gd` puts the default camera on, and a host who never
	# touches the board should land somewhere deliberate.
	var host_id := multiplayer.get_unique_id()
	_peer_seats[host_id] = 0
	_peer_ready[host_id] = false
	_refresh_seats()

func _setup_join() -> void:
	banner_label.text = "LOBBY"
	seat_hint.text = "The host picks the map and the mode. Click a free seat to move. Empty seats are played by bots."
	primary_button.caption = "READY"
	start_button.visible = false
	# A client may look at the host's map and mode but not change them — this is
	# the whole fix for the conflicting-map defect, so it is enforced on the
	# control itself, not only by the host ignoring a stray RPC.
	_lock_host_only_controls()

	var parts := MultiplayerSetupScreen.split_address(GameLaunch.pending_join_address)
	var host: String = String(parts[0])
	var port: int = int(parts[1])
	seat_heading.text = "CONNECTING TO %s…" % GameLaunch.pending_join_address
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

## Reported the same way the old lobby did — first non-loopback IPv4 address.
## Static and self-contained so it can be read without an instance.
static func _lan_address() -> String:
	for addr in IP.get_local_addresses():
		if ":" in addr:
			continue # IPv6 — see multiplayer_setup.gd::split_address for why
		if addr.begins_with("127."):
			continue
		return addr
	return "127.0.0.1"

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
	seat_heading.text = "LOBBY  ·  HOST %s" % GameLaunch.pending_join_address
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
	# state; the player can move afterwards. Four seats and MAX_PLAYERS = 4, so
	# a connected peer can always be seated — the -1 branch is a guard, not an
	# expected path.
	var seat := _first_free_seat()
	if seat >= 0:
		_peer_seats[peer_id] = seat
	_peer_ready[peer_id] = false
	# Full snapshot to the newcomer, then the deltas to everyone (including the
	# newcomer, harmlessly) so nobody is holding a half-built board.
	_rpc_sync_state.rpc_id(peer_id, _peer_seats, _peer_ready,
		GameLaunch.selected_map, int(GameLaunch.game_mode), SettingsManager.ai_difficulty)
	_rpc_sync_seats.rpc(_peer_seats)
	_refresh_seats()
	_refresh_start_button()

func _on_peer_left(peer_id: int) -> void:
	_peer_seats.erase(peer_id)
	_peer_ready.erase(peer_id)
	if _is_lobby_host():
		_rpc_sync_seats.rpc(_peer_seats)
		_refresh_start_button()
	_refresh_seats()

func _first_free_seat() -> int:
	for seat in range(NetworkManagerScript.MAX_PLAYERS):
		if not _peer_seats.values().has(seat):
			return seat
	return -1

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
		map_id: StringName, mode: int, difficulty: int) -> void:
	_peer_seats = seats
	_peer_ready = ready_states
	_apply_host_config(map_id, mode, difficulty)
	_refresh_seats()

## Host -> everyone: the seating changed.
@rpc("authority", "call_local", "reliable")
func _rpc_sync_seats(seats: Dictionary) -> void:
	_peer_seats = seats
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
func _rpc_sync_config(map_id: StringName, mode: int, difficulty: int) -> void:
	_apply_host_config(map_id, mode, difficulty)
	for peer_id in _peer_ready:
		_peer_ready[peer_id] = false
	primary_button.caption = "READY"
	status_label.text = "The host changed the match. Press READY again."
	_refresh_seats()
	_refresh_start_button()

func _apply_host_config(map_id: StringName, mode: int, difficulty: int) -> void:
	GameLaunch.selected_map = map_id
	_map_index = GameLaunch.map_index()
	GameLaunch.game_mode = mode as GameLaunchScript.GameMode
	_mode_index = _index_for_mode(GameLaunch.game_mode)
	# R-09. ⚠️ `persist` FALSE: this is the HOST's choice for THIS match, and writing
	# it into the client's own settings.cfg would silently change what that player
	# gets the next time they host. The bug U-8 fixed was a per-peer value deciding
	# the match; the mirror-image mistake is a per-match value editing a preference.
	_difficulty_index = clampi(difficulty, 0, DIFFICULTIES.size() - 1)
	SettingsManager.set_ai_difficulty(_difficulty_index, false)
	map_value_label.text = String(GameLaunch.MAPS[_map_index]["name"])
	mode_value_label.text = String(MODES[_mode_index]["label"])
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
func _rpc_begin_match(seat_tokens: Dictionary, map_id: StringName, mode: int) -> void:
	GameLaunch.seat_tokens = seat_tokens
	GameLaunch.selected_map = map_id
	GameLaunch.game_mode = mode as GameLaunchScript.GameMode
	# B-14: the autoloads survive scene changes, so a second match would resume
	# the first one's score. Reset here as well as on the way in — main.gd resets
	# defensively too, and three cheap resets beat one missed one.
	MatchManager.reset()
	RoundManager.reset()
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

# =============================================================================
# Selectors
# =============================================================================

func _index_for_mode(mode: GameLaunchScript.GameMode) -> int:
	for i in range(MODES.size()):
		if MODES[i]["id"] == mode:
			return i
	return 0

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

func _on_mode_prev() -> void:
	_cycle_mode(-1)

func _on_mode_next() -> void:
	_cycle_mode(1)

func _cycle_mode(step: int) -> void:
	AudioManager.play("ui_click") # 4.1
	_mode_index = posmod(_mode_index + step, MODES.size())
	_apply_mode()
	_broadcast_config()

func _apply_mode() -> void:
	var mode: Dictionary = MODES[_mode_index]
	mode_value_label.text = String(mode["label"])
	GameLaunch.game_mode = int(mode["id"]) as GameLaunchScript.GameMode
	_refresh_detail()

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
		_rpc_sync_config.rpc(GameLaunch.selected_map, int(GameLaunch.game_mode),
			SettingsManager.ai_difficulty)

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
## highlight map, it will show map desc but if i highlight mode or other shit,
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
			return "%s   %s" % [
				String(MODES[_mode_index]["label"]), String(MODES[_mode_index]["detail"])]
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
	var seat := _local_seat()
	if _seat_is_person(seat):
		# Checklist 1.3 (does a Person get its own ability roster?) is still
		# HUMAN-owned and open, so every person shares one Tag / Throw kit. Say that
		# plainly rather than letting the player believe a kit choice applies to a
		# character it does not.
		return "PERSON   You are the person. On defence you are the defender: body-block, tag, and stand your lata back up. On offence you carry the tsinelas and throw it. Your %s and %s picks belong to your object teammate and only apply if you move to that seat." % [
			_entry_name(CharacterRoster.CANS, GameLaunch.can_index()),
			_entry_name(CharacterRoster.SLIPPERS, GameLaunch.slipper_index())]
	return "OBJECT   You are the object. A lata on defence, holding the mark and guarding, then a tsinelas on offence, thrown and scrambling home. Your kit swaps with the role: %s as the lata, %s as the tsinelas." % [
		_kit_name(CharacterRoster.CANS, GameLaunch.can_index()),
		_kit_name(CharacterRoster.SLIPPERS, GameLaunch.slipper_index())]

## The ability a skin brings, named rather than pathed. Falls back to the skin's
## own name when an entry has no `ability` — a roster entry added without one is
## a real possibility and is not worth erroring over.
static func _kit_name(list: Array[Dictionary], index: int) -> String:
	if index < 0 or index >= list.size():
		return "the default kit"
	var path := String(list[index].get("ability", ""))
	if path == "":
		return "the default kit"
	var ability := load(path) as AbilityBase
	return String(ability.ability_name) if ability != null else "the default kit"

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
## PERSON is the human unit, OBJECT is the thing they field (a lata one round, a
## tsinelas the next) — and `lata`/`tsinelas` themselves stay Filipino, because
## those are two of the three words the human explicitly kept. The team letter
## stays A/B because that is an identity, not a role, and `Dev_Plan.md` §4.2 is
## explicit that team identity is carried by the letter mark rather than by any
## word or hue.
static func _seat_name(seat: int) -> String:
	return "TEAM %s · %s" % ["A" if seat / 2 == 0 else "B",
		"PERSON" if _seat_is_person(seat) else "OBJECT"]

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
	_rpc_sync_seats.rpc(_peer_seats)
	_rpc_set_ready.rpc(peer_id, false)
	_refresh_seats()
	_refresh_start_button()
	return true

func _refresh_seats() -> void:
	for seat in range(seat_buttons.size()):
		var button := seat_buttons[seat]
		button.text = _seat_row_text(seat)
		# ⚠️ `disabled` MEANS "SOMEBODY ELSE HAS THIS", NOT "THIS IS YOURS".
		# Your own seat was disabled here first, which was exactly backwards on
		# screen: the wood theme's disabled state is a sunk, dimmed plank, so the
		# one row the player most needs to find — their own — was the only one
		# that read as unavailable. Your seat stays live (pressing it is a no-op,
		# handled in `_on_seat_pressed`) and is marked in the text instead.
		button.disabled = _occupant_of(seat) not in [-1, multiplayer.get_unique_id()]
	_refresh_detail()

## A small, human-sized number for a peer — 1 for the host, then 2, 3, 4 in peer
## order. ⚠️ NOT the peer id: ENet hands out ids like 816586678, and the lobby
## read "PLAYER 816586678" until this existed. Derived by sorting the seat map's
## keys, which every peer holds identically (the host broadcasts it), so the same
## player is the same number on everybody's screen.
func _player_number(peer_id: int) -> int:
	var ids: Array = _peer_seats.keys()
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
	var who := "YOU" if occupant == multiplayer.get_unique_id() else "PLAYER %d" % _player_number(occupant)
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
	start_button.disabled = _peer_seats.is_empty()

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
	_rpc_begin_match.rpc(seat_tokens, GameLaunch.selected_map, int(GameLaunch.game_mode))

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
