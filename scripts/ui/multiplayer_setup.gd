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

@onready var host_online_button: ArrowButton = %HostOnlineButton
@onready var host_button: ArrowButton = %HostButton
@onready var join_button: ArrowButton = %JoinButton
@onready var join_address_edit: LineEdit = %JoinAddressEdit
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	status_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameVersion.attach_to(self)

	host_online_button.pressed.connect(_on_host_online_pressed)
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

	# ⚠️ TYPING ANYTHING CANCELS AN ARMED CODE WAIT. See § JOINING BY CODE: a wait that
	# survives the player rewriting the thing it is waiting for would fire on a code that
	# is no longer on screen, and the join it starts would look like it came from nowhere.
	join_address_edit.text_changed.connect(_on_join_text_changed)

	_build_lan_browser()
	_build_online_browser()

	var buttons: Array[ArrowButton] = [host_online_button, host_button, join_button]
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
	# ⚠️ THE TWO BOXES SHARE A RECT AND MUST NOT SHARE A SCREEN. Both are centred on
	# `BOX_RECT`/`ONLINE_BOX_RECT`, which overlap almost exactly; two open at once is one
	# opaque wood panel with another one's rows bleeding out from behind it.
	if _online_box != null and is_instance_valid(_online_box):
		_online_box.visible = false
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

## ---------------------------------------------------------------------------
## § THE ONLINE BROWSER. The same screen, the same shape, a different transport: this one
## lists what `ServerQuery` hears back from the FIXED POOL of dedicated processes on the
## VM. Read `server_query.gd`'s header first — in particular that there is no registry,
## that every server answers for itself, and that a row's address comes from the envelope
## of the packet rather than from anything the server claims about itself.
##
## ⚠️ IT IS A SECOND BROWSER, NOT A MODE SWITCH ON THE FIRST ONE. LAN discovery and pool
## queries are different protocols on different sockets answering different questions
## ("who on this wire is shouting" versus "what are these eight known processes doing"),
## and one list with a toggle over it would have to reconcile two entry shapes — `name`
## versus `code`, `in_match` versus `in_progress` — for the sole benefit of saving a
## button. The two lists are also useful at the same time: a LAN party with one player
## dialling in from home wants both visible.
##
## ⚠️ A CLICK SELECTS, IT DOES NOT JOIN — the same invariant as the LAN browser's § header
## states, for the same reason, and it matters more here because this list has a second
## plausible thing to do on click. The typed field stays the single source of truth and
## the JOIN pennant stays the only control that opens a connection.
##
## ⚠️ A ROW WRITES THE ADDRESS, NOT THE CODE, even though the code is what the row leads
## with. The code is the human-readable handle you read down a phone; it is NOT a more
## reliable way to reach a server you are already looking at. Writing the code would send
## the press back through `resolve_code()` — a second lookup, against a table that could
## have expired the entry in the meantime — to recover an address this row already has in
## its hand. The code is displayed so it can be read out and shared; the address is what
## gets typed, so the click lands in exactly the path a typed address does.
##
## ⚠️ SAME LAYOUT RULES AS THE LAN BROWSER. This screen has no containers; see that § for
## why the button is placed by rect and why the box is a Panel with a VBox inside it. The
## button sits third in the bottom row (BACK, LAN, ONLINE) and ends at 1825 — 95 from the
## right edge, mirroring BACK's own 95 from the left.
## ---------------------------------------------------------------------------
const ONLINE_BROWSE_RECT: Rect2 = Rect2(1159.0, 868.0, 666.0, 58.0)
## ⚠️⚠️ THIS BOX IS SIZED TO ITS CONTENTS, WHERE THE LAN BOX IS A FIXED RECT — and that
## difference is not tidiness, it is the shipped state. `BOX_RECT` can be a constant
## because the LAN box is either empty or full of rows and both look like a list. This one
## has a THIRD state that is neither: the pool address is empty until the VM exists (see
## `ServerQueryScript.POOL_ADDRESS`), so what every player sees TODAY is a title, two
## sentences and a CLOSE button. At a fixed 790 that shot came back as five hundred pixels
## of blank wood under the button — a panel that looks like a list that failed to draw,
## which is the exact impression this state exists to avoid giving.
##
## So the height is `column.get_combined_minimum_size()` plus the padding, recomputed on
## every refresh, and the box is re-centred vertically around it. The width is constant, so
## the wrapped hint's height cannot feed back into it and oscillate.
##
## ⚠️ THE CLAMP IS LOAD-BEARING AT BOTH ENDS. The first refresh runs from `_ready()`,
## before the column has ever been laid out — the hint's width is 0 there, so it "wraps" to
## one word per line and asks for a panel taller than the screen. The box is hidden at that
## moment and the next refresh (which `_on_online_browse_pressed` does before the box is
## ever drawn) measures correctly, but the ceiling is what makes that harmless rather than
## a one-frame flash of a panel running off both edges of the viewport.
const ONLINE_BOX_X: float = 510.0
const ONLINE_BOX_WIDTH: float = 900.0
const ONLINE_BOX_PAD: float = 24.0
## Low enough that the shortest state — a title, one line of hint and CLOSE, which measures
## 205 — is not padded back out into the blank wood this whole mechanism exists to remove.
const ONLINE_BOX_MIN_HEIGHT: float = 160.0
## Eight rows and a three-line hint measure 772; 820 leaves that some room to grow without
## letting a mis-measurement escape the viewport.
const ONLINE_BOX_MAX_HEIGHT: float = 820.0
## 1080 is the viewport height (`project.godot`), the same assumption `BOX_RECT` makes.
const VIEWPORT_HEIGHT: float = 1080.0
## ⚠️ THE WHOLE POOL FITS, AND THE NUMBER IS DERIVED SO IT KEEPS FITTING. Six rows would
## leave two of the eight servers listed nowhere — reachable only by a code you would have
## had to already know, which defeats the point of a browser. Widening the pool widens
## this automatically; if the box then overflows, that is the screenshot's job to catch.
const ONLINE_MAX_ROWS: int = ServerQueryScript.POOL_PORT_LAST - ServerQueryScript.POOL_PORT_FIRST + 1
## ⚠️ ONE LINE PER ROW, UNLIKE THE LAN BROWSER'S TWO. The LAN row spends its second line on
## an address because a LAN game has no other name you could repeat back to anybody. An
## online row leads with a four-character code that identifies it completely, so the
## address is dead weight on screen — and eight two-line rows do not fit any box that also
## clears the bottom of the viewport.
const ONLINE_ROW_HEIGHT: float = 58.0

## ---------------------------------------------------------------------------
## § JOINING BY CODE, AND THE TRAP UNDERNEATH IT.
##
## ⚠️⚠️ A CODE CANNOT BE RESOLVED UNTIL THE POOL HAS ANSWERED, AND THE SCREEN MUST NEVER
## CALL THAT "WRONG CODE". `ServerQuery.resolve_code()` reads a table filled by UDP replies
## (see its own ⚠️); a player who alt-tabs in with a code from a friend, pastes it and hits
## JOIN within a second of the screen appearing is asking a table that is legitimately
## still empty. Reporting a typo there is the single most convincing way to make a working
## feature look broken, because the player's next move is to retype a code that was right
## the first time.
##
## So a code that does not resolve is ARMED, not rejected: `_pending_code` holds it,
## `_process` retries every frame, and the join fires the moment the answer lands. The
## press the player already made is what completes — this is not a second, hidden way to
## start a connection, it is the same one finishing late.
##
## ⚠️ "THE POOL HAS ANSWERED" IS A TIME, NOT A BOOLEAN, and `POOL_SETTLE_SECONDS` is why.
## The obvious latch — "some server replied, therefore the list is complete" — is wrong for
## the couple of hundred milliseconds in which the eight replies are still arriving: the
## server holding the code may simply not have answered yet while its neighbour already
## has. Verdicts of "no server is using that code" therefore wait `POOL_SETTLE_SECONDS`
## after the FIRST reply, which is two full `ServerQuery.QUERY_INTERVAL` rounds — every
## server has had two chances by then, and a code that is still unmatched is a typo.
##
## ⚠️ AND IF NOTHING EVER ANSWERS, the wait cannot run forever either: a spinner with no
## end is the other way this reads as broken. `POOL_PATIENCE_SECONDS` bounds it, and the
## same number is what flips the browse button from "searching…" to "no answer" — one
## constant for the one question "how long before we are allowed to say something
## negative about the pool".
## ---------------------------------------------------------------------------
const POOL_SETTLE_SECONDS: float = 2.0
const POOL_PATIENCE_SECONDS: float = 6.0

var _online_button: Button = null
var _online_box: Panel = null
## Held because `_fit_online_box()` measures it every refresh — see `ONLINE_BOX_X`'s ⚠️⚠️.
var _online_column: VBoxContainer = null
var _online_title: Label = null
var _online_hint: Label = null
var _online_rows: Array[Button] = []
## Parallel to `_online_rows`, exactly as `_browser_addresses` is to `_browser_rows`.
var _online_addresses: Array[String] = []
var _online_codes: Array[String] = []

## Seconds this screen has been asking the pool. Every "have we waited long enough" test
## below is measured against this one accumulator rather than against wall-clock time, so
## a paused or slow frame cannot make the screen impatient on the player's behalf.
var _browsed_for: float = 0.0
## `_browsed_for` when the FIRST reply landed; negative while none has. See ⚠️ above.
var _first_reply_at: float = -1.0
## The code a JOIN press is still waiting on, upper-cased. Empty when nothing is armed.
var _pending_code: String = ""
var _pending_code_since: float = 0.0
## One-shot, so the "no answer" repaint happens once rather than once per frame forever.
var _silence_reported: bool = false

func _build_online_browser() -> void:
	var parent := back_button.get_parent()
	if parent == null:
		return
	_online_button = Button.new()
	_online_button.name = "BrowseOnlineButton"
	_online_button.focus_mode = Control.FOCUS_ALL
	_online_button.theme_type_variation = back_button.theme_type_variation
	_online_button.clip_text = true
	parent.add_child(_online_button)
	_online_button.position = ONLINE_BROWSE_RECT.position
	_online_button.size = ONLINE_BROWSE_RECT.size
	# The bottom row reads left to right, so the focus does too: LAN ↔ ONLINE side by side,
	# both hanging off JOIN above and both falling to BACK below.
	_browse_button.focus_neighbor_right = _online_button.get_path()
	_online_button.focus_neighbor_left = _browse_button.get_path()
	_online_button.focus_neighbor_top = join_button.get_path()
	_online_button.focus_neighbor_bottom = back_button.get_path()
	_online_button.pressed.connect(_on_online_browse_pressed)
	_online_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
	# ⚠️⚠️ THE LAN BOX IS RE-RAISED ABOVE THE BUTTON THAT WAS JUST ADDED. `_build_lan_box`'s
	# own ⚠️ says sibling order is this screen's entire stacking rule and that a dialog the
	# pennants punch through is not a dialog — and adding a THIRD bottom-row button after
	# that box did exactly that. The two rects overlap (the box spans 510..1410, this button
	# starts at 1159), and the screenshot showed the wood button drawn on top of the open LAN
	# list. Both buttons first, then both boxes; do not reorder these two calls.
	parent.move_child(_box, parent.get_child_count() - 1)
	_build_online_box(parent)
	ServerQuery.servers_changed.connect(_refresh_online_browser)
	# ⚠️ STARTED EVEN WHEN THE POOL ADDRESS IS EMPTY, and deliberately not branched on.
	# `query_pool()` returns immediately without opening a socket in that case, so the cost
	# of starting anyway is one early return per second — and the alternative is a gate
	# that makes the shipped configuration the only one this call is ever exercised under.
	ServerQuery.start_browsing()
	_refresh_online_browser()

func _build_online_box(parent: Node) -> void:
	_online_box = Panel.new()
	_online_box.name = "OnlineBrowserBox"
	_online_box.add_theme_stylebox_override("panel", UiTheme.wood_style(UiTheme.WOOD_DEEP))
	_online_box.visible = false
	# Added after the LAN box for the same stacking reason its own ⚠️ gives: sibling order
	# is this screen's entire z rule.
	parent.add_child(_online_box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_online_column = column
	_online_box.add_child(column)
	_online_title = Label.new()
	_online_title.add_theme_font_size_override("font_size", 32)
	_online_title.add_theme_color_override("font_color", UiTheme.AMBER)
	column.add_child(_online_title)
	_online_hint = Label.new()
	_online_hint.add_theme_font_size_override("font_size", 19)
	_online_hint.add_theme_color_override("font_color", UiTheme.CREAM_MUTED)
	_online_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_online_hint)
	# Pooled and hidden, never freed per refresh — see `_build_lan_box`'s ⚠️.
	for i in ONLINE_MAX_ROWS:
		var row := Button.new()
		row.theme_type_variation = back_button.theme_type_variation
		row.focus_mode = Control.FOCUS_ALL
		row.clip_text = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		row.custom_minimum_size = Vector2(0.0, ONLINE_ROW_HEIGHT)
		row.visible = false
		row.pressed.connect(_on_online_row_pressed.bind(i))
		row.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
		column.add_child(row)
		_online_rows.append(row)
	var close := Button.new()
	close.text = "CLOSE"
	close.theme_type_variation = back_button.theme_type_variation
	close.focus_mode = Control.FOCUS_ALL
	close.custom_minimum_size = Vector2(0.0, 56.0)
	close.pressed.connect(_close_online_box)
	close.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
	column.add_child(close)
	_fit_online_box()

## Shrinks the panel onto whatever the column currently holds and re-centres it. See
## `ONLINE_BOX_X`'s ⚠️⚠️ for why this box measures and the LAN one does not.
func _fit_online_box() -> void:
	# ⚠️⚠️ THE HINT IS HANDED ITS WIDTH BEFORE ANYTHING IS MEASURED, and this line is the
	# whole reason the fit works. A HIDDEN container does not lay its children out, so for
	# as long as this box is closed the hint Label is still zero pixels wide — and an
	# autowrapping Label that is 0 wide reports the height of one word per line, which is
	# taller than the viewport. The first screenshot of this box showed exactly that: a
	# panel stuck at `ONLINE_BOX_MAX_HEIGHT` with five hundred pixels of blank wood in it,
	# because every measurement had been taken while the thing was invisible. The VBox
	# writes the same number back on its next sort, so this costs nothing when the box IS
	# open — it only stops the closed case from lying.
	_online_hint.size.x = ONLINE_BOX_WIDTH - ONLINE_BOX_PAD * 2.0
	var height := clampf(_online_column.get_combined_minimum_size().y + ONLINE_BOX_PAD * 2.0,
		ONLINE_BOX_MIN_HEIGHT, ONLINE_BOX_MAX_HEIGHT)
	_online_box.size = Vector2(ONLINE_BOX_WIDTH, height)
	_online_box.position = Vector2(ONLINE_BOX_X, floorf((VIEWPORT_HEIGHT - height) * 0.5))
	_online_column.position = Vector2(ONLINE_BOX_PAD, ONLINE_BOX_PAD)
	_online_column.size = _online_box.size - Vector2(ONLINE_BOX_PAD * 2.0, ONLINE_BOX_PAD * 2.0)

func _on_online_browse_pressed() -> void:
	AudioManager.play("ui_click")
	if _online_box == null or not is_instance_valid(_online_box):
		return
	if _box != null and is_instance_valid(_box):
		_box.visible = false # see `_on_browse_pressed`'s ⚠️
	_online_box.visible = not _online_box.visible
	if _online_box.visible:
		_refresh_online_browser()

func _close_online_box() -> void:
	AudioManager.play("ui_back")
	if _online_box != null and is_instance_valid(_online_box):
		_online_box.visible = false
	if _online_button != null and is_instance_valid(_online_button):
		_online_button.grab_focus()

## True only when this build actually points somewhere. `POOL_ADDRESS` ships empty until
## the VM exists (see its ⚠️ in `server_query.gd`), and every negative message on this
## screen has to distinguish "nothing answered" from "nothing was asked".
func _pool_configured() -> bool:
	return not ServerQuery.pool_address.strip_edges().is_empty()

## Whether the pool has been quiet long enough that a negative verdict is honest. See the
## § JOINING BY CODE ⚠️ — this is the whole reason a code is armed rather than rejected.
func _pool_answered_enough() -> bool:
	return _first_reply_at >= 0.0 and _browsed_for - _first_reply_at >= POOL_SETTLE_SECONDS

func _refresh_online_browser() -> void:
	if _online_box == null or not is_instance_valid(_online_box):
		return
	var configured := _pool_configured()
	var found: Array[Dictionary] = []
	if configured:
		found = ServerQuery.servers()
	if not found.is_empty() and _first_reply_at < 0.0:
		_first_reply_at = _browsed_for
	# ⚠️ THE UNCONFIGURED CASE IS NAMED ON THE CLOSED BUTTON, not hidden inside the box.
	# A build with no pool address will otherwise sit on "searching…" forever and invite
	# the player to blame their own network for a list that was never going to fill.
	if not configured:
		_online_button.text = "ONLINE SERVERS  ·  UNAVAILABLE"
		_online_title.text = "ONLINE PLAY IS NOT SWITCHED ON"
		_online_hint.text = ("This build has no online server address in it yet, so there is "
			+ "nothing to list and join codes cannot be looked up. HOST GAME (LAN) and "
			+ "typing a host's address into the field both still work exactly as before.")
	elif not found.is_empty():
		_online_button.text = "ONLINE SERVERS  ·  %d found" % found.size()
		_online_title.text = "ONLINE SERVERS"
		# ⚠️ THIS USED TO POINT AT A CODE IN THE ROW. The rows stopped printing codes
		# deliberately (see `_refresh_online_browser`), and copy describing a column that
		# is no longer there is worse than no copy — it sends the player hunting for it.
		_online_hint.text = ("Click one to fill in its address, then press JOIN. Once you "
			+ "are in a lobby it shows a four-character code: read that out and a friend "
			+ "can type it here instead of an address to land in the same game.")
	elif _silence_reported:
		_online_button.text = "ONLINE SERVERS  ·  no answer"
		_online_title.text = "NO ONLINE SERVERS ANSWERED"
		_online_hint.text = ("Nothing in the online pool replied. It may be down, or your "
			+ "network may be blocking it. HOST GAME (LAN) and typing a host's address both "
			+ "still work — this screen keeps asking in the background.")
	else:
		_online_button.text = "ONLINE SERVERS  ·  searching…"
		_online_title.text = "ASKING THE ONLINE SERVERS…"
		_online_hint.text = "Every server in the pool is being asked what it is doing. Give it a second."
	_online_addresses.clear()
	_online_codes.clear()
	for i in _online_rows.size():
		var row := _online_rows[i]
		if i >= found.size():
			row.visible = false
			continue
		var entry: Dictionary = found[i]
		var code: String = String(entry.get("code", ""))
		if code.is_empty():
			code = "????" # a reply with no code is still a server you can reach by address
		_online_addresses.append("%s:%d" % [String(entry.get("ip", "")), int(entry.get("port", 0))])
		_online_codes.append(code)
		# ⚠️⚠️ THE CODE IS DELIBERATELY NOT PRINTED HERE. A code is what you hand to the
		# people you want in your game; a public list that prints every code is a list of
		# everyone's private invites, and reading one off the board is indistinguishable
		# from being given it. The row still CARRIES the code — `_online_codes` keeps it,
		# because that is how a click resolves to an address — it just does not show it.
		#
		# ⚠️ THIS IS NOT ACCESS CONTROL AND MUST NOT BE SOLD AS ANY. Every listed lobby is
		# still one click away in this same box; hiding the code stops it being COPIED, not
		# the lobby being ENTERED. A lobby that genuinely must be private needs the server
		# to refuse peers that did not present its code, which is a change on the host
		# side, not in this browser.
		#
		# Servers are named by their slot in the pool instead, which is stable across the
		# whole session and is the same number the operator sees in `lobby-pool status`.
		row.text = "SERVER %d   ·   %d/%d   ·   %s   ·   %s" % [
			_pool_slot_of(int(entry.get("port", 0))), int(entry.get("players", 0)),
			int(entry.get("max", NetworkManagerScript.MAX_PLAYERS)),
			map_label(String(entry.get("map", ""))),
			"IN A MATCH" if bool(entry.get("in_progress", false)) else "IN THE LOBBY"]
		row.visible = true
	# ⚠️ LAST, AND IT HAS TO BE. It measures the column, and the column has just changed
	# by however many rows this refresh turned on or off.
	_fit_online_box()

## Which slot in the pool a game port is, counting from 1 — the same number the operator
## sees in `lobby-pool status`, so a player saying "server 3 is broken" and the person
## reading the logs mean the same box. Falls back to the raw port for anything outside the
## configured range rather than inventing a slot that does not exist.
static func _pool_slot_of(game_port: int) -> int:
	var slot := game_port - ServerQueryScript.POOL_PORT_FIRST + 1
	return slot if slot >= 1 else game_port

static func _pool_slot_of_address(address: String) -> int:
	var parts := split_address(address)
	return _pool_slot_of(int(parts[1]))

## The map's display name for an id off the wire. Falls back to the raw id rather than to
## a map that happens to be first: a pool server running something this build has never
## heard of should say so, not quietly claim to be Eskinita.
static func map_label(map_id: String) -> String:
	var wanted := map_id.strip_edges()
	if wanted.is_empty():
		return "?"
	for entry in GameLaunchScript.MAPS:
		if String(entry["id"]) == wanted:
			return String(entry["name"])
	return wanted.to_upper()

## ⚠️ IT WRITES THE FIELD AND STOPS, exactly as `_on_lan_row_pressed` does. See the §
## header for why it writes the ADDRESS while the row displays the CODE.
func _on_online_row_pressed(index: int) -> void:
	AudioManager.play("ui_click")
	if index < 0 or index >= _online_addresses.size():
		return
	# Picking a server supersedes both waits — you have just named the one you want.
	_cancel_pending_code()
	_cancel_hosting_online()
	join_address_edit.text = _online_addresses[index]
	GameLaunch.pending_join_address = join_address_edit.text
	# Names the slot, not the code — same reason the row does. See `_refresh_online_browser`.
	status_label.text = "Picked server %d — press JOIN." % _pool_slot_of_address(_online_addresses[index])
	if _online_box != null and is_instance_valid(_online_box):
		_online_box.visible = false
	join_button.grab_focus()

## ---------------------------------------------------------------------------
## § THE FIELD TAKES EITHER. An address and a join code are both valid input, told apart
## by shape rather than by a mode the player has to set.
## ---------------------------------------------------------------------------

## ⚠️ THE CODE TEST HAS TO RUN BEFORE `is_address_parseable()`, NOT AFTER. `split_address`
## takes anything without a colon as a bare host, so "A7SF" parses perfectly happily as
## host "A7SF" on the default port and would be handed to ENet as a name to look up — a
## DNS failure several seconds later, on a screen that has already changed. The two tests
## cannot both be permissive, and this one is the narrow one: exactly four characters, all
## of them from an alphabet that deliberately contains no 0, O, 1, I or L, which is also
## why "8910" is not mistaken for a code.
static func looks_like_join_code(text: String) -> bool:
	var candidate := text.strip_edges().to_upper()
	if candidate.length() != NetworkManagerScript.JOIN_CODE_LENGTH:
		return false
	for i in candidate.length():
		if not (candidate[i] in NetworkManagerScript.JOIN_CODE_ALPHABET):
			return false
	return true

## Resolves now if it can, arms `_pending_code` if it cannot yet, and only calls a code
## wrong once the pool has had its say. See § JOINING BY CODE for all three branches.
func _join_by_code(code: String) -> void:
	if not _pool_configured():
		AudioManager.play("ui_error")
		status_label.text = ("Join codes need the online servers, and this build has none "
			+ "configured yet. Type the host's address instead, or host on your LAN.")
		return
	var address := ServerQuery.resolve_code(code)
	if not address.is_empty():
		_begin_join(address)
		return
	if _pool_answered_enough():
		AudioManager.play("ui_error")
		status_label.text = "No online server is using the code %s. Check it and try again." % code
		return
	# ⚠️ NOT AN ERROR, AND IT MUST NOT SOUND LIKE ONE — `ui_click`, not `ui_error`. The
	# table is empty because the replies are still in the air, which is the state every
	# player who pastes a code the instant the screen opens will be in.
	AudioManager.play("ui_click")
	_pending_code = code
	_pending_code_since = _browsed_for
	status_label.text = "Looking for %s — waiting on the online servers…" % code
	ServerQuery.query_pool() # do not sit out the rest of this second's interval

## Returns whether a wait was actually cancelled, so Escape can tell "I stopped something"
## from "there was nothing to stop and you meant to leave the screen".
func _cancel_pending_code() -> bool:
	if _pending_code.is_empty():
		return false
	_pending_code = ""
	return true

func _on_join_text_changed(_text: String) -> void:
	if _cancel_pending_code():
		status_label.text = ""

## ⚠️ THE ONE PLACE A JOIN IS RECORDED. A typed address, a browsed row and a resolved code
## all funnel through here, so there is exactly one set of `GameLaunch` writes to keep
## correct — and `match_setup.gd` cannot tell, or need to tell, which of the three it was.
func _begin_join(address: String) -> void:
	GameLaunch.pending_action = "join"
	GameLaunch.pending_join_address = address
	GameLaunch.clear_seating()
	_reset_match_state()
	get_tree().change_scene_to_file(MATCH_SETUP_PATH)

func _process(delta: float) -> void:
	_browsed_for += delta
	# The one-shot flip from "searching…" to "no answer". Repainting the button is cheap
	# but not free, and this screen's refresh is otherwise driven entirely by the signal.
	if not _silence_reported and _pool_configured() and _first_reply_at < 0.0 \
			and _browsed_for >= POOL_PATIENCE_SECONDS:
		_silence_reported = true
		_refresh_online_browser()
	# ⚠️ BEFORE THE CODE WAIT, AND THE TWO CANNOT BOTH BE ARMED — every entry point into
	# either cancels the other, so this order is about reading clearly rather than about
	# precedence between two live waits.
	if _hosting_online:
		_tick_hosting_online()
		return
	if _pending_code.is_empty():
		return
	var address := ServerQuery.resolve_code(_pending_code)
	if not address.is_empty():
		var found_code := _pending_code
		_pending_code = ""
		status_label.text = "Found %s." % found_code
		_begin_join(address)
		return
	# Two ways to give up, and they answer different questions: the pool replied and none
	# of them claim this code (a typo), or the pool never replied at all (it is down).
	if _pool_answered_enough():
		var missing := _pending_code
		_cancel_pending_code()
		AudioManager.play("ui_error")
		status_label.text = "No online server is using the code %s. Check it and try again." % missing
		return
	if _browsed_for - _pending_code_since >= POOL_PATIENCE_SECONDS:
		var unanswered := _pending_code
		_cancel_pending_code()
		AudioManager.play("ui_error")
		status_label.text = ("Could not reach the online servers to look up %s. Try again, or "
			+ "type the host's address instead.") % unanswered

## The armed half of HOST ONLINE. Mirrors the `_pending_code` block above line for line,
## including both ways of giving up — "they answered and all eight are busy" and "nothing
## answered at all" are different problems and get different sentences.
func _tick_hosting_online() -> void:
	var address := _free_pool_address()
	if not address.is_empty():
		_cancel_hosting_online()
		_claim_online_server(address)
		return
	if _pool_answered_enough():
		_cancel_hosting_online()
		AudioManager.play("ui_error")
		status_label.text = ("Every online server is in use right now. Open ONLINE SERVERS to "
			+ "join one of them, or try again in a minute.")
		return
	if _browsed_for - _hosting_online_since >= POOL_PATIENCE_SECONDS:
		_cancel_hosting_online()
		AudioManager.play("ui_error")
		status_label.text = ("Could not reach the online servers. They may be down, or your "
			+ "network may be blocking them — HOST GAME (LAN) still works.")

## ⚠️ THE LISTENER IS CLOSED ON THE WAY OUT, not left to the autoload's lifetime.
## `LanBeacon` is an autoload and survives every scene change, so a socket opened here
## and never closed would still be bound while the player is in a match — and on the
## HOST's machine that is the same process that is advertising.
##
## ⚠️ `ServerQuery` GETS THE SAME TREATMENT AND NEEDS IT MORE. It is an autoload too, and
## a browse left running would keep firing eight datagrams a second for the whole match —
## on a DEDICATED server that is the same process that is answering them.
func _exit_tree() -> void:
	LanBeacon.stop_listening()
	ServerQuery.stop_browsing()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		# ⚠️ ESCAPE CLOSES THE BOX FIRST AND LEAVES THE SCREEN SECOND. A dialog that
		# is up and an Escape that walks out of the whole screen anyway is the same
		# bug as a modal that ignores its own close button.
		if _box != null and is_instance_valid(_box) and _box.visible:
			_close_lan_box()
			return
		if _online_box != null and is_instance_valid(_online_box) and _online_box.visible:
			_close_online_box()
			return
		# ⚠️ AND AN ARMED CODE IS THE SAME ARGUMENT ONE LAYER DOWN. A player who mistyped
		# and sees "Looking for A7SF…" presses Escape to take it back, not to leave; an
		# Escape that walked out would change scene the instant the code then resolved.
		if _cancel_pending_code() or _cancel_hosting_online():
			AudioManager.play("ui_back")
			status_label.text = "Stopped looking."
			return
		_on_back_pressed()

## ---------------------------------------------------------------------------
## § HOST ONLINE — 🧑 2026-08-02: *"i told you to add a HOST ONLINE button. when you host
## an online game the code shows and you share it to your friends to give"*, and *"we're
## trying to move away from LAN"*.
##
## ⚠️⚠️ IT DOES NOT HOST. It CLAIMS. There is no process to start on the player's machine
## and no port to open on their router — the pool is eight dedicated processes that are
## already running on the VM (see `docs/Dedicated_Server_Deployment.md`), and "hosting
## online" means taking an idle one. So this press is a JOIN, aimed at an EMPTY server,
## and it funnels through `_begin_join` like every other join on this screen.
##
## ⚠️ WHAT MAKES IT FEEL LIKE HOSTING IS THE LOBBY LEADER RULE, not anything here. A
## dedicated server hands the role to the first peer that identifies (see
## `NetworkManager._claim_lobby_leader_if_vacant`), so the player who claims an empty
## server picks the map, the mode and when to start — and `match_setup.gd` shows them the
## four-character code to read out. Land on an EMPTY one and you are the leader; land on
## an occupied one and you are a guest, which is why "empty" here means BOTH `players == 0`
## AND `in_progress == false` rather than merely "has a free seat".
##
## ⚠️ TWO PLAYERS CAN CLAIM THE SAME SERVER, and nothing in this design prevents it.
## `server_query.gd`'s header says there is no registry; a slot is only known to be free
## because it said so up to a second ago, and two people pressing this at once both believe
## it. The loser is not broken — they are a guest in a lobby with a stranger leading — but
## it is not what they asked for. Picking at RANDOM among the free servers rather than
## always the lowest-numbered one is the cheap half of the fix: it turns a guaranteed
## collision between two simultaneous presses into a 1-in-N one. The expensive half is a
## claim the server itself arbitrates, which is a change on the host side, not here.
## ---------------------------------------------------------------------------

## Set while a HOST ONLINE press is waiting for the pool to answer. Exactly the armed shape
## `_pending_code` has, and for exactly the reason § JOINING BY CODE gives: the table this
## reads is filled by UDP replies, so a press made the instant the screen opens is asking a
## list that is legitimately still empty, and calling that "no servers free" is the fastest
## way to make a working feature look broken.
var _hosting_online: bool = false
var _hosting_online_since: float = 0.0

## An idle pool server, or "" if none is known to be idle right now. Random among the free
## ones rather than the first — see the § ⚠️ on simultaneous presses.
##
## ⚠️⚠️ "FREE" IS `occupied`, NOT `players`. `players` is the count of SEATS taken, so a
## lobby whose only occupant is a spectator advertises `0/4` and reads as empty — and that
## spectator, having identified first, already holds the lobby leader role. Claiming that
## server would drop the player into a lobby they cannot pick the map in, cannot start,
## and were told they were hosting. `occupied` counts every human attached whether seated
## or not; see the field's own ⚠️⚠️ in `server_query.gd::_status_payload`.
func _free_pool_address() -> String:
	var free: Array[String] = []
	for entry in ServerQuery.servers():
		if bool(entry.get("in_progress", false)):
			continue
		if int(entry.get("occupied", entry.get("players", 0))) > 0:
			continue
		free.append("%s:%d" % [String(entry.get("ip", "")), int(entry.get("port", 0))])
	if free.is_empty():
		return ""
	return free[randi() % free.size()]

## Returns whether a wait was actually cancelled, so Escape can tell the two cases apart —
## same contract as `_cancel_pending_code`.
func _cancel_hosting_online() -> bool:
	if not _hosting_online:
		return false
	_hosting_online = false
	return true

func _on_host_online_pressed() -> void:
	# A HOST ONLINE press supersedes a code the player was waiting on, exactly as a second
	# JOIN press does: two armed waits could otherwise both resolve and change scene twice.
	_cancel_pending_code()
	if not _pool_configured():
		AudioManager.play("ui_error")
		status_label.text = ("This build has no online server address in it yet, so there is "
			+ "nothing to host on. Use HOST GAME (LAN) for now.")
		return
	var address := _free_pool_address()
	if not address.is_empty():
		_claim_online_server(address)
		return
	if _pool_answered_enough():
		# The pool spoke and every one of them is occupied. A real answer, not a timeout —
		# and the honest thing to offer is the browser, since a busy lobby is still joinable.
		AudioManager.play("ui_error")
		status_label.text = ("Every online server is in use right now. Open ONLINE SERVERS to "
			+ "join one of them, or try again in a minute.")
		return
	AudioManager.play("ui_click") # not an error — the replies are still in the air
	_hosting_online = true
	_hosting_online_since = _browsed_for
	status_label.text = "Finding you a free online server…"
	ServerQuery.query_pool() # do not sit out the rest of this second's interval

func _claim_online_server(address: String) -> void:
	AudioManager.play("ui_click")
	status_label.text = "Taking server %d — your code is on the next screen." % _pool_slot_of_address(address)
	_begin_join(address)

func _on_host_pressed() -> void:
	_cancel_pending_code()
	_cancel_hosting_online()
	GameLaunch.pending_action = "host"
	GameLaunch.clear_seating()
	_reset_match_state()
	get_tree().change_scene_to_file(MATCH_SETUP_PATH)

func _on_join_pressed() -> void:
	# A second press supersedes a code the first one is still waiting on — otherwise the
	# old wait could resolve and change scene out from under the new one. A HOST ONLINE
	# wait is superseded for the same reason: it would change scene to a different server.
	_cancel_pending_code()
	_cancel_hosting_online()
	var typed := join_address_edit.text.strip_edges()
	if typed.is_empty():
		AudioManager.play("ui_error") # 4.1
		status_label.text = "Enter an address or a 4-character code first (e.g. 192.168.1.12, or A7SF)."
		return
	if looks_like_join_code(typed): # see `looks_like_join_code`'s ⚠️ for why this is first
		_join_by_code(typed.to_upper())
		return
	if not is_address_parseable(typed):
		AudioManager.play("ui_error")
		status_label.text = ("That is neither an address nor a code. Use 192.168.1.12, "
			+ "192.168.1.12:8910, or a 4-character code like A7SF.")
		return
	_begin_join(typed)

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
