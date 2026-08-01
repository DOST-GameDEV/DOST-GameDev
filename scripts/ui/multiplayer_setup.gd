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

	_build_lan_browser()

	var buttons: Array[ArrowButton] = [host_button, join_button]
	for i in buttons.size():
		buttons[i].animate_in(i * STAGGER)

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE SPECTATE TOGGLE USED TO LIVE HERE AND IT WAS DELETED. 2026-08-02, 🧑:
## *"spectator button is redundant there's 2 for host game"*.
##
## The old header argued the two were not redundant, on the grounds that declaring it
## BEFORE a socket exists means the identify packet already carries it, so the host
## never seats you rather than seating you and being told to undo it one round trip
## later. That reasoning was only ever true for a JOINER, and the screen could not tell
## which of the two buttons you were about to press — so a HOST, who is the referee and
## has no round trip to save, was shown a toggle that duplicated the SPECTATING button
## sitting on their own lobby one screen later. Two controls for one bool, on the path
## where the argument for having two does not apply.
##
## What is left is `match_setup.gd`'s, which is the one that has to work MID-LOBBY
## anyway (`_on_peer_spectator_changed`, `_vacated_seats` — a chair you are giving back)
## and is fully client-capable. The cost is exactly the round trip the old comment named:
## a joiner who wants to film is seated for one message before the host un-seats them.
## That path is already written and already tested; it is what un-spectating mid-lobby
## has always done.
##
## ⚠️ `GameLaunch.spectator` IS UNTOUCHED AND IS STILL READ HERE. It is a session
## preference that survives the menu (`match_setup.gd` line ~385 republishes it on
## arrival), so a player who set it in the lobby last match still arrives spectating.
## Nothing was removed from the model — only the second control onto it.
## ---------------------------------------------------------------------------

## ---------------------------------------------------------------------------
## § THE LAN BROWSER. 🧑 2026-08-02: *"can u try to list joinable games in lan
## somehwere? like in minecraft hehe"*.
##
## `LanBeacon` does the socket work (see that file for the protocol and for why the
## address comes from the packet's own source IP rather than from its payload). This
## screen only draws the list and, on a click, fills the address field.
##
## ⚠️ A CLICK SELECTS, IT DOES NOT JOIN. Minecraft's server list wants a double-click
## and this screen already has a JOIN pennant two inches away, so a single click writing
## the address into the field and leaving the press to JOIN is both the smaller change
## and the harder one to do by accident. The typed field stays the source of truth —
## there is no second, hidden way to start a connection.
##
## ⚠️ IT REUSES THE DELETED SPECTATE TOGGLE'S EXACT SLOT, on 🧑's instruction: *"make it
## so that clicking the old spectate block opens a box with joinable lans"*. That rect is
## already justified against this screen's hand-laid layout (it shares BACK's row and
## height, one gap to its right, and 95..395 is BACK's own span so 427 clears it), and
## the choice it now offers belongs to the whole session in the same way the toggle's
## did. The button carries the live count so the box is worth opening before you open it.
##
## ⚠️ PLACED BY OFFSETS, NOT ADDED TO A CONTAINER — this screen has none. Every control
## here is `layout_mode = 0` on the bare root `Control` (the pennants are hand-positioned
## so their poles line up with the backdrop art), so a container idiom would have found
## no parent to add to and silently built nothing. The box is one Panel placed by rect
## with a VBox inside it, and the rows go inside THAT.
const BROWSE_RECT: Rect2 = Rect2(427.0, 868.0, 700.0, 58.0)
## Centred over the screen rather than anchored to the button: it is a dialog, it covers
## the pennants while it is up, and 1920x1080 is the viewport (`project.godot`).
##
## ⚠️ 700 TALL, AND THE NUMBER CAME OFF A SCREENSHOT RATHER THAN OUT OF ARITHMETIC. At
## 600 the last two rows and CLOSE drew BELOW the panel's own bottom edge — floating
## brown buttons on the road, with the wood frame ending above them. A two-line row does
## not measure `custom_minimum_size`; it measures its text, and at the theme's default
## font size that came out near 90 px, so six of them plus a title, a wrapped hint and
## CLOSE needed a good 200 px more than the panel had. `ROW_FONT_SIZE` is the other half
## of the fix. Change either and re-run `tools/ui/lan_box_shot.tscn` — the overflow is
## invisible in code and obvious in one frame.
const BOX_RECT: Rect2 = Rect2(510.0, 190.0, 900.0, 700.0)
## Set explicitly so the row height is a number this file controls. Inheriting the
## theme's size is what made the panel too small for its own contents.
const ROW_FONT_SIZE: int = 24
## Rows are pooled, not rebuilt, so a refresh cannot steal focus mid-keyboard-nav.
const BROWSER_MAX_ROWS: int = 6

var _browse_button: Button = null
var _box: Panel = null
var _box_title: Label = null
var _box_hint: Label = null
var _browser_rows: Array[Button] = []
## Parallel to `_browser_rows`: the "ip:port" each visible row would fill in.
var _browser_addresses: Array[String] = []

func _build_lan_browser() -> void:
	var parent := back_button.get_parent()
	if parent == null:
		return
	_browse_button = Button.new()
	_browse_button.name = "BrowseLanButton"
	_browse_button.focus_mode = Control.FOCUS_ALL
	_browse_button.theme_type_variation = back_button.theme_type_variation
	_browse_button.clip_text = true
	parent.add_child(_browse_button)
	_browse_button.position = BROWSE_RECT.position
	_browse_button.size = BROWSE_RECT.size
	# The focus order, explicitly — the slot's previous occupant set the same one.
	# JOIN → BROWSE → BACK.
	join_button.focus_neighbor_bottom = _browse_button.get_path()
	_browse_button.focus_neighbor_top = join_button.get_path()
	_browse_button.focus_neighbor_bottom = back_button.get_path()
	back_button.focus_neighbor_top = _browse_button.get_path()
	_browse_button.pressed.connect(_on_browse_pressed)
	_browse_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover")) # 4.1
	_build_lan_box(parent)
	LanBeacon.servers_changed.connect(_refresh_lan_browser)
	LanBeacon.start_listening()
	_refresh_lan_browser()

func _build_lan_box(parent: Node) -> void:
	_box = Panel.new()
	_box.name = "LanBrowserBox"
	_box.add_theme_stylebox_override("panel", UiTheme.wood_style(UiTheme.WOOD_DEEP))
	_box.visible = false
	# ⚠️ ADDED LAST SO IT DRAWS OVER THE PENNANTS. This screen has no CanvasLayer and
	# no z_index anywhere in it; sibling order is the entire stacking rule here, and a
	# dialog that the JOIN pennant punches through is not a dialog.
	parent.add_child(_box)
	_box.position = BOX_RECT.position
	_box.size = BOX_RECT.size
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_box.add_child(column)
	column.position = Vector2(28.0, 24.0)
	column.size = BOX_RECT.size - Vector2(56.0, 48.0)
	_box_title = Label.new()
	_box_title.add_theme_font_size_override("font_size", 32)
	_box_title.add_theme_color_override("font_color", UiTheme.AMBER)
	column.add_child(_box_title)
	_box_hint = Label.new()
	_box_hint.add_theme_font_size_override("font_size", 19)
	_box_hint.add_theme_color_override("font_color", UiTheme.CREAM_MUTED)
	_box_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_box_hint)
	# ⚠️ EVERY ROW IS BUILT NOW AND HIDDEN, rather than added and freed per refresh.
	# The refresh runs once a second forever; `queue_free()`-ing the focused row out
	# from under a keyboard user is how a menu loses focus to nothing mid-press.
	for i in BROWSER_MAX_ROWS:
		var row := Button.new()
		row.theme_type_variation = back_button.theme_type_variation
		row.focus_mode = Control.FOCUS_ALL
		row.clip_text = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		row.custom_minimum_size = Vector2(0.0, 62.0)
		row.visible = false
		row.pressed.connect(_on_lan_row_pressed.bind(i))
		row.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover")) # 4.1
		column.add_child(row)
		_browser_rows.append(row)
	var close := Button.new()
	close.text = "CLOSE"
	close.theme_type_variation = back_button.theme_type_variation
	close.focus_mode = Control.FOCUS_ALL
	close.custom_minimum_size = Vector2(0.0, 56.0)
	close.pressed.connect(_close_lan_box)
	close.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover")) # 4.1
	column.add_child(close)

func _on_browse_pressed() -> void:
	AudioManager.play("ui_click")
	if _box == null or not is_instance_valid(_box):
		return
	_box.visible = not _box.visible
	if _box.visible:
		_refresh_lan_browser()

func _close_lan_box() -> void:
	AudioManager.play("ui_back") # 4.1
	if _box != null and is_instance_valid(_box):
		_box.visible = false
	if _browse_button != null and is_instance_valid(_browse_button):
		_browse_button.grab_focus()

func _refresh_lan_browser() -> void:
	if _box == null or not is_instance_valid(_box):
		return
	var found := LanBeacon.servers()
	# ⚠️ THE COUNT IS ON THE CLOSED BUTTON, not only inside the box. The listener runs
	# for as long as this screen does, so "is anybody hosting" is answerable without
	# opening anything — which is the question somebody standing on this screen has.
	_browse_button.text = ("GAMES ON YOUR LAN  ·  searching…" if found.is_empty()
		else "GAMES ON YOUR LAN  ·  %d found" % found.size())
	_box_title.text = ("GAMES ON YOUR NETWORK" if not found.is_empty()
		else "NO GAMES FOUND YET")
	_box_hint.text = ("Click one to fill in its address, then press JOIN."
		if not found.is_empty() else
		"This finds games on your own network. If the host you want is missing — or is "
		+ "on Hamachi — type their address into the field above instead. Windows "
		+ "Firewall blocking the game is the usual reason a LAN game does not show up.")
	_browser_addresses.clear()
	for i in _browser_rows.size():
		var row := _browser_rows[i]
		if i >= found.size():
			row.visible = false
			continue
		var entry: Dictionary = found[i]
		var address := "%s:%d" % [entry.get("ip", ""), int(entry.get("port", 0))]
		_browser_addresses.append(address)
		# "HARRY'S GAME · 2/4 · IN THE LOBBY" over the address it will type for you.
		row.text = "%s   ·   %d/%d   ·   %s\n%s" % [
			entry.get("name", "A GAME"), int(entry.get("players", 0)),
			int(entry.get("max", NetworkManagerScript.MAX_PLAYERS)),
			"IN A MATCH" if bool(entry.get("in_match", false)) else "IN THE LOBBY",
			address]
		row.visible = true

## ⚠️ IT WRITES THE FIELD AND STOPS. See the § header: the JOIN pennant is the only
## thing on this screen that opens a connection, and a list that could also do it would
## be a second entry point into `_on_join_pressed`'s validation.
func _on_lan_row_pressed(index: int) -> void:
	AudioManager.play("ui_click")
	if index < 0 or index >= _browser_addresses.size():
		return
	join_address_edit.text = _browser_addresses[index]
	GameLaunch.pending_join_address = join_address_edit.text
	status_label.text = "Picked %s — press JOIN." % _browser_addresses[index]
	if _box != null and is_instance_valid(_box):
		_box.visible = false
	join_button.grab_focus()

## ⚠️ THE LISTENER IS CLOSED ON THE WAY OUT, not left to the autoload's lifetime.
## `LanBeacon` is an autoload and survives every scene change, so a socket opened here
## and never closed would still be bound while the player is in a match — and on the
## HOST's machine that is the same process that is advertising.
func _exit_tree() -> void:
	LanBeacon.stop_listening()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		# ⚠️ ESCAPE CLOSES THE BOX FIRST AND LEAVES THE SCREEN SECOND. A dialog that
		# is up and an Escape that walks out of the whole screen anyway is the same
		# bug as a modal that ignores its own close button.
		if _box != null and is_instance_valid(_box) and _box.visible:
			_close_lan_box()
			return
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
