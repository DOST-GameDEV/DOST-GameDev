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

	var buttons: Array[ArrowButton] = [host_button, join_button]
	for i in buttons.size():
		buttons[i].animate_in(i * STAGGER)

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
