extends Control
class_name MultiplayerSetupScreen


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
	back_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
	join_address_edit.text_submitted.connect(func(_text: String) -> void: join_button.pressed.emit())
	join_address_edit.text = GameLaunch.pending_join_address

	if GameLaunch.pending_status_message != "":
		status_label.text = GameLaunch.pending_status_message
		GameLaunch.pending_status_message = ""

	join_address_edit.text_changed.connect(_on_join_text_changed)

	_build_lan_browser()
	_build_online_browser()

	var buttons: Array[ArrowButton] = [host_online_button, host_button, join_button]
	for i in buttons.size():
		buttons[i].animate_in(i * STAGGER)


const BROWSE_RECT: Rect2 = Rect2(427.0, 980.0, 700.0, 58.0)
const BOX_RECT: Rect2 = Rect2(510.0, 190.0, 900.0, 700.0)
const ROW_FONT_SIZE: int = 24
const BROWSER_MAX_ROWS: int = 6

var _browse_button: Button = null
var _box: Panel = null
var _box_title: Label = null
var _box_hint: Label = null
var _browser_rows: Array[Button] = []
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
	join_button.focus_neighbor_bottom = _browse_button.get_path()
	_browse_button.focus_neighbor_top = join_button.get_path()
	_browse_button.focus_neighbor_bottom = back_button.get_path()
	back_button.focus_neighbor_top = _browse_button.get_path()
	_browse_button.pressed.connect(_on_browse_pressed)
	_browse_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
	_build_lan_box(parent)
	LanBeacon.servers_changed.connect(_refresh_lan_browser)
	LanBeacon.start_listening()
	_refresh_lan_browser()

func _build_lan_box(parent: Node) -> void:
	_box = Panel.new()
	_box.name = "LanBrowserBox"
	_box.add_theme_stylebox_override("panel", UiTheme.wood_style(UiTheme.WOOD_DEEP))
	_box.visible = false
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
		row.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
		column.add_child(row)
		_browser_rows.append(row)
	var close := Button.new()
	close.text = "CLOSE"
	close.theme_type_variation = back_button.theme_type_variation
	close.focus_mode = Control.FOCUS_ALL
	close.custom_minimum_size = Vector2(0.0, 56.0)
	close.pressed.connect(_close_lan_box)
	close.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
	column.add_child(close)

func _on_browse_pressed() -> void:
	AudioManager.play("ui_click")
	if _box == null or not is_instance_valid(_box):
		return
	if _online_box != null and is_instance_valid(_online_box):
		_online_box.visible = false
	_box.visible = not _box.visible
	if _box.visible:
		_refresh_lan_browser()

func _close_lan_box() -> void:
	AudioManager.play("ui_back")
	if _box != null and is_instance_valid(_box):
		_box.visible = false
	if _browse_button != null and is_instance_valid(_browse_button):
		_browse_button.grab_focus()

func _refresh_lan_browser() -> void:
	if _box == null or not is_instance_valid(_box):
		return
	var found := LanBeacon.servers()
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
		row.text = "%s   ·   %d/%d   ·   %s\n%s" % [
			entry.get("name", "A GAME"), int(entry.get("players", 0)),
			int(entry.get("max", NetworkManagerScript.MAX_PLAYERS)),
			"IN A MATCH" if bool(entry.get("in_match", false)) else "IN THE LOBBY",
			address]
		row.visible = true

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

const ONLINE_BROWSE_RECT: Rect2 = Rect2(1159.0, 980.0, 666.0, 58.0)
const ONLINE_BOX_X: float = 510.0
const ONLINE_BOX_WIDTH: float = 900.0
const ONLINE_BOX_PAD: float = 24.0
const ONLINE_BOX_MIN_HEIGHT: float = 160.0
const ONLINE_BOX_MAX_HEIGHT: float = 820.0
const VIEWPORT_HEIGHT: float = 1080.0
const ONLINE_MAX_ROWS: int = ServerQueryScript.POOL_PORT_LAST - ServerQueryScript.POOL_PORT_FIRST + 1
const ONLINE_ROW_HEIGHT: float = 58.0

const POOL_SETTLE_SECONDS: float = 2.0
const POOL_PATIENCE_SECONDS: float = 6.0

var _online_button: Button = null
var _online_box: Panel = null
var _online_column: VBoxContainer = null
var _online_title: Label = null
var _online_hint: Label = null
var _online_rows: Array[Button] = []
var _online_addresses: Array[String] = []
var _online_codes: Array[String] = []

var _browsed_for: float = 0.0
var _first_reply_at: float = -1.0
var _pending_code: String = ""
var _pending_code_since: float = 0.0
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
	_browse_button.focus_neighbor_right = _online_button.get_path()
	_online_button.focus_neighbor_left = _browse_button.get_path()
	_online_button.focus_neighbor_top = join_button.get_path()
	_online_button.focus_neighbor_bottom = back_button.get_path()
	_online_button.pressed.connect(_on_online_browse_pressed)
	_online_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
	parent.move_child(_box, parent.get_child_count() - 1)
	_build_online_box(parent)
	ServerQuery.servers_changed.connect(_refresh_online_browser)
	ServerQuery.start_browsing()
	_refresh_online_browser()

func _build_online_box(parent: Node) -> void:
	_online_box = Panel.new()
	_online_box.name = "OnlineBrowserBox"
	_online_box.add_theme_stylebox_override("panel", UiTheme.wood_style(UiTheme.WOOD_DEEP))
	_online_box.visible = false
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

func _fit_online_box() -> void:
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
		_box.visible = false
	_online_box.visible = not _online_box.visible
	if _online_box.visible:
		_refresh_online_browser()

func _close_online_box() -> void:
	AudioManager.play("ui_back")
	if _online_box != null and is_instance_valid(_online_box):
		_online_box.visible = false
	if _online_button != null and is_instance_valid(_online_button):
		_online_button.grab_focus()

func _pool_configured() -> bool:
	return not ServerQuery.pool_address.strip_edges().is_empty()

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
	if not configured:
		_online_button.text = "ONLINE SERVERS  ·  UNAVAILABLE"
		_online_title.text = "ONLINE PLAY IS NOT SWITCHED ON"
		_online_hint.text = ("This build has no online server address in it yet, so there is "
			+ "nothing to list and join codes cannot be looked up. HOST GAME (LAN) and "
			+ "typing a host's address into the field both still work exactly as before.")
	elif not found.is_empty():
		_online_button.text = "ONLINE SERVERS  ·  %d found" % found.size()
		_online_title.text = "ONLINE SERVERS"
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
			code = "????"
		_online_addresses.append("%s:%d" % [String(entry.get("ip", "")), int(entry.get("port", 0))])
		_online_codes.append(code)
		row.text = "SERVER %d   ·   %d/%d   ·   %s   ·   %s" % [
			_pool_slot_of(int(entry.get("port", 0))), int(entry.get("players", 0)),
			int(entry.get("max", NetworkManagerScript.MAX_PLAYERS)),
			map_label(String(entry.get("map", ""))),
			"IN A MATCH" if bool(entry.get("in_progress", false)) else "IN THE LOBBY"]
		row.visible = true
	_fit_online_box()

static func _pool_slot_of(game_port: int) -> int:
	var slot := game_port - ServerQueryScript.POOL_PORT_FIRST + 1
	return slot if slot >= 1 else game_port

static func _pool_slot_of_address(address: String) -> int:
	var parts := split_address(address)
	return _pool_slot_of(int(parts[1]))

static func map_label(map_id: String) -> String:
	var wanted := map_id.strip_edges()
	if wanted.is_empty():
		return "?"
	for entry in GameLaunchScript.MAPS:
		if String(entry["id"]) == wanted:
			return String(entry["name"])
	return wanted.to_upper()

func _on_online_row_pressed(index: int) -> void:
	AudioManager.play("ui_click")
	if index < 0 or index >= _online_addresses.size():
		return
	_cancel_pending_code()
	_cancel_hosting_online()
	join_address_edit.text = _online_addresses[index]
	GameLaunch.pending_join_address = join_address_edit.text
	status_label.text = "Picked server %d — press JOIN." % _pool_slot_of_address(_online_addresses[index])
	if _online_box != null and is_instance_valid(_online_box):
		_online_box.visible = false
	join_button.grab_focus()


static func looks_like_join_code(text: String) -> bool:
	var candidate := text.strip_edges().to_upper()
	if candidate.length() != NetworkManagerScript.JOIN_CODE_LENGTH:
		return false
	for i in candidate.length():
		if not (candidate[i] in NetworkManagerScript.JOIN_CODE_ALPHABET):
			return false
	return true

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
	AudioManager.play("ui_click")
	_pending_code = code
	_pending_code_since = _browsed_for
	status_label.text = "Looking for %s — waiting on the online servers…" % code
	ServerQuery.query_pool()

func _cancel_pending_code() -> bool:
	if _pending_code.is_empty():
		return false
	_pending_code = ""
	return true

func _on_join_text_changed(_text: String) -> void:
	if _cancel_pending_code():
		status_label.text = ""

func _begin_join(address: String) -> void:
	GameLaunch.pending_action = "join"
	GameLaunch.pending_join_address = address
	GameLaunch.clear_seating()
	_reset_match_state()
	get_tree().change_scene_to_file(MATCH_SETUP_PATH)

func _process(delta: float) -> void:
	_browsed_for += delta
	if not _silence_reported and _pool_configured() and _first_reply_at < 0.0 \
			and _browsed_for >= POOL_PATIENCE_SECONDS:
		_silence_reported = true
		_refresh_online_browser()
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

const SPAWN_PATIENCE_SECONDS: float = 20.0

func _tick_hosting_online() -> void:
	var address := _free_pool_address()
	if not address.is_empty():
		_cancel_hosting_online()
		_claim_online_server(address)
		return
	if _browsed_for - _hosting_online_since >= SPAWN_PATIENCE_SECONDS:
		_cancel_hosting_online()
		AudioManager.play("ui_error")
		status_label.text = ("Could not get an online server. They may all be busy, or your "
			+ "network may be blocking them — open ONLINE SERVERS to look, or use "
			+ "HOST GAME (LAN).")

func _exit_tree() -> void:
	LanBeacon.stop_listening()
	ServerQuery.stop_browsing()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _box != null and is_instance_valid(_box) and _box.visible:
			_close_lan_box()
			return
		if _online_box != null and is_instance_valid(_online_box) and _online_box.visible:
			_close_online_box()
			return
		if _cancel_pending_code() or _cancel_hosting_online():
			AudioManager.play("ui_back")
			status_label.text = "Stopped looking."
			return
		_on_back_pressed()


var _hosting_online: bool = false
var _hosting_online_since: float = 0.0

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

func _cancel_hosting_online() -> bool:
	if not _hosting_online:
		return false
	_hosting_online = false
	return true

func _on_host_online_pressed() -> void:
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
	ServerQuery.request_lobby()
	AudioManager.play("ui_click")
	_hosting_online = true
	_hosting_online_since = _browsed_for
	status_label.text = "Starting a server for you…"
	ServerQuery.query_pool()

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
	_cancel_pending_code()
	_cancel_hosting_online()
	var typed := join_address_edit.text.strip_edges()
	if typed.is_empty():
		AudioManager.play("ui_error")
		status_label.text = "Enter an address or a 4-character code first (e.g. 192.168.1.12, or A7SF)."
		return
	if looks_like_join_code(typed):
		_join_by_code(typed.to_upper())
		return
	if not is_address_parseable(typed):
		AudioManager.play("ui_error")
		status_label.text = ("That is neither an address nor a code. Use 192.168.1.12, "
			+ "192.168.1.12:8910, or a 4-character code like A7SF.")
		return
	_begin_join(typed)

static func is_address_parseable(address: String) -> bool:
	var parts := split_address(address)
	return not String(parts[0]).is_empty() and int(parts[1]) > 0 and int(parts[1]) <= 65535

static func split_address(address: String) -> Array:
	var host := address.strip_edges()
	var port := NetworkManagerScript.DEFAULT_PORT
	var colon := host.rfind(":")
	if colon != -1:
		var port_text := host.substr(colon + 1)
		host = host.substr(0, colon)
		port = int(port_text) if port_text.is_valid_int() else 0
	if ":" in host:
		return ["", 0]
	return [host.strip_edges(), port]

func _on_back_pressed() -> void:
	AudioManager.play("ui_back")
	get_tree().change_scene_to_file(MODE_SELECT_PATH)

func _reset_match_state() -> void:
	MatchManager.reset()
	RoundManager.reset()

