extends Control
class_name MultiplayerSetupScreen

## The Host-or-Join fork, reached from ModeSelect's MULTIPLAYER pennant.
##
## Nothing here touches ENet. It only records WHICH kind of session the player
## asked for, and where to reach the host if they asked to join; the actual
## `NetworkManager.host_game()` / `join_game()` call happens one screen later,
## in `match_setup.gd`, because that is the screen that has to be alive and
## listening when the connection succeeds or fails. Making the connection here
## and then changing scene would open a window where a `connection_failed`
## signal has nobody left to hear it.
##
## This is also where a bounced client lands: `main.gd::_on_server_disconnected`
## and `_on_connection_failed` both send the player back here with a
## `pending_status_message`, since re-hosting or re-joining is what somebody in
## that position almost always wants next.

const MATCH_SETUP_PATH: String = "res://scenes/ui/MatchSetup.tscn"
const MODE_SELECT_PATH: String = "res://scenes/ui/ModeSelect.tscn"

const STAGGER: float = 0.09

@onready var host_button: ArrowButton = %HostButton
@onready var join_button: ArrowButton = %JoinButton
@onready var join_address_edit: LineEdit = %JoinAddressEdit
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	status_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameVersion.attach_to(self)

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
	back_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover")) # 4.1
	# Enter in the address field is the same press as the JOIN pennant, so it
	# routes through the pennant's own `pressed` rather than calling the handler
	# directly — that way the click SFX and the press squash still happen.
	join_address_edit.text_submitted.connect(func(_text: String) -> void: join_button.pressed.emit())
	# Typing an address you already used last time is the most common thing to
	# do here, so it is filled back in rather than cleared.
	join_address_edit.text = GameLaunch.pending_join_address

	# Q-1/B-62: "Host ended the match." / "Could not reach that host." — this is
	# the screen main.gd bounces a dropped client to, and the one that explains
	# why they are looking at it.
	if GameLaunch.pending_status_message != "":
		status_label.text = GameLaunch.pending_status_message
		GameLaunch.pending_status_message = ""

	_build_spectate_button()

	var buttons: Array[ArrowButton] = [host_button, join_button]
	for i in buttons.size():
		buttons[i].animate_in(i * STAGGER)

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE SECOND SPECTATE TOGGLE, ON THE HOST-OR-JOIN FORK. `Design.md` §9, §2.1.
##
## § THE REACHABILITY RULE asks for the toggle on the multiplayer lobby *and* the
## pre-match setup screen, and the two are not redundant:
##
##   * `match_setup.gd`'s lives beside the four seat rows because there it is the fifth
##     answer to "which of these am I", and it is the one that has to work MID-LOBBY,
##     with the host refereeing a chair you are giving back.
##   * this one is answered BEFORE a socket exists. It is the difference between joining
##     a friend's game to play and joining it to film, and declaring it here means the
##     identify packet `NetworkManager._on_connected_to_server` sends on connect already
##     carries it — so the host never seats you in the first place, rather than seating
##     you and then being told to undo it one round trip later.
##
## Built in code for the same reason the other one is: the entire state is one bool on an
## autoload, and `MultiplayerSetup.tscn` is a hand-laid screen whose two pennants animate
## in. Styled off `BackButton`, the only plain Button already on this screen.
##
## ⚠️ PLACED BY OFFSETS, NOT ADDED TO A CONTAINER — this screen has none. Every control
## here is `layout_mode = 0` on the bare root `Control` (the pennants are hand-positioned
## so their poles line up with the backdrop art), so the container idiom `match_setup.gd`
## uses would have found no parent to add to and silently built nothing. It shares
## BACK's row and its height, one gap to the right of it: the bottom bar is where this
## screen already puts choices that belong to the whole session rather than to one
## pennant, and 95..395 is BACK's own span, so 427 clears it without crowding.
const SPECTATE_RECT: Rect2 = Rect2(427.0, 868.0, 700.0, 58.0)

var _spectate_button: Button = null

func _build_spectate_button() -> void:
	var parent := back_button.get_parent()
	if parent == null:
		return
	_spectate_button = Button.new()
	_spectate_button.name = "SpectateButton"
	_spectate_button.toggle_mode = true
	_spectate_button.button_pressed = GameLaunch.spectator
	_spectate_button.focus_mode = Control.FOCUS_ALL
	_spectate_button.theme_type_variation = back_button.theme_type_variation
	_spectate_button.clip_text = true
	parent.add_child(_spectate_button)
	_spectate_button.position = SPECTATE_RECT.position
	_spectate_button.size = SPECTATE_RECT.size
	# The focus order, explicitly — see match_setup.gd's own note. JOIN → SPECTATE → BACK.
	join_button.focus_neighbor_bottom = _spectate_button.get_path()
	_spectate_button.focus_neighbor_top = join_button.get_path()
	_spectate_button.focus_neighbor_bottom = back_button.get_path()
	back_button.focus_neighbor_top = _spectate_button.get_path()
	_spectate_button.pressed.connect(_on_spectate_pressed)
	_spectate_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover")) # 4.1
	_refresh_spectate_button()

func _on_spectate_pressed() -> void:
	AudioManager.play("ui_click")
	GameLaunch.spectator = _spectate_button.button_pressed
	# No `NetworkManager.publish_spectator()` here, deliberately: nothing on this screen
	# touches ENet (see the file header), so there is no host to tell yet. The value is
	# read straight off `GameLaunch` by `_local_picks()` when the connection is made one
	# screen later, which is the earliest moment it can be sent.
	_refresh_spectate_button()

func _refresh_spectate_button() -> void:
	if _spectate_button == null or not is_instance_valid(_spectate_button):
		return
	_spectate_button.text = ("SPECTATE: ON  ·  watch, no character"
		if GameLaunch.spectator else "SPECTATE: OFF  ·  play normally")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()

func _on_host_pressed() -> void:
	GameLaunch.pending_action = "host"
	GameLaunch.clear_seating()
	_reset_match_state()
	get_tree().change_scene_to_file(MATCH_SETUP_PATH)

func _on_join_pressed() -> void:
	var address := join_address_edit.text.strip_edges()
	if address.is_empty():
		AudioManager.play("ui_error") # 4.1
		status_label.text = "Enter the host's address first (e.g. 192.168.1.12)."
		return
	if not is_address_parseable(address):
		AudioManager.play("ui_error")
		status_label.text = "That is not an address. Use 192.168.1.12, or 192.168.1.12:8910."
		return
	GameLaunch.pending_action = "join"
	GameLaunch.pending_join_address = address
	GameLaunch.clear_seating()
	_reset_match_state()
	get_tree().change_scene_to_file(MATCH_SETUP_PATH)

## ⚠️ THE PORT USED TO BE SILENTLY DISCARDED. The old GAME screen's placeholder
## text read `192.168.1.12:7777`, but the address string went straight to
## `NetworkManager.join_game(address)` → `ENetMultiplayerPeer.create_client()`,
## which takes host and port as SEPARATE arguments and does not parse a colon.
## Anyone who typed the format the placeholder itself demonstrated got a failed
## connection with no explanation. Split here, once, and hand the two halves
## over separately — see `split_address()` and `match_setup.gd`'s join branch.
static func is_address_parseable(address: String) -> bool:
	var parts := split_address(address)
	return not String(parts[0]).is_empty() and int(parts[1]) > 0 and int(parts[1]) <= 65535

## "1.2.3.4" -> ["1.2.3.4", DEFAULT_PORT]; "1.2.3.4:9000" -> ["1.2.3.4", 9000].
## Rejects IPv6 by returning an empty host: this is a same-LAN prototype and
## ENet is configured for IPv4 throughout (`lobby`/`match_setup` skip IPv6 when
## reporting the host's own address too), so accepting a bracketed IPv6 literal
## here would only produce a failure further down with a worse message.
static func split_address(address: String) -> Array:
	var host := address.strip_edges()
	var port := NetworkManagerScript.DEFAULT_PORT
	var colon := host.rfind(":")
	if colon != -1:
		var port_text := host.substr(colon + 1)
		host = host.substr(0, colon)
		port = int(port_text) if port_text.is_valid_int() else 0
	if ":" in host: # a second colon means IPv6 — see the doc above
		return ["", 0]
	return [host.strip_edges(), port]

func _on_back_pressed() -> void:
	AudioManager.play("ui_back") # 4.1
	get_tree().change_scene_to_file(MODE_SELECT_PATH)

## B-14: MatchManager/RoundManager are autoloads and survive scene changes.
func _reset_match_state() -> void:
	MatchManager.reset()
	RoundManager.reset()
