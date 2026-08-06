extends Node


const SCREENS := [
	["hud", "res://scenes/ui/HUD.tscn", -1, "local"],
	["match_setup", "res://scenes/ui/MatchSetup.tscn", -1, "local"],
	["match_setup_host", "res://scenes/ui/MatchSetup.tscn", -1, "host"],
	["character_select", "res://scenes/ui/CharacterSelect.tscn", 0, "local"],
	["character_select_lata", "res://scenes/ui/CharacterSelect.tscn", 1, "local"],
	["character_select_tsinelas", "res://scenes/ui/CharacterSelect.tscn", 2, "local"],
]


const DISJOINT: Dictionary = {
	"MatchSetup.tscn": ["ConfigPanel", "SeatPanel", "Banner"],
	"HUD.tscn": ["TopLeft", "TopCentre", "TopRight", "ToastLabel"],
}

const PRESETS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1080)]

var _out := ""
var _i := 0
var _settle := 0
var _screen: Node = null
var _fails := 0
var _checks := 0
var _sizes: Array[Vector2i] = []
var _size_i := 0
var _content_sizes: Array[Vector2] = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_out = String(args[0]) if args.size() > 0 else ""
	var specs := PackedStringArray()
	if args.size() > 1:
		specs = String(args[1]).split(",", false)
	for spec in specs:
		var parts := String(spec).strip_edges().split("x")
		if parts.size() == 2:
			_sizes.append(Vector2i(int(parts[0]), int(parts[1])))
	if _sizes.is_empty():
		_sizes.assign(PRESETS)
	GameLaunch.pending_action = "local"
	_report_window_fit()
	_apply_size()
	_load()

func _report_window_fit() -> void:
	if DisplayServer.get_name() == "headless":
		print("  window fit: headless, no window manager — skipped")
		return
	var win := get_window()
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	var boot := Rect2i(win.get_position_with_decorations(), win.get_size_with_decorations())
	var explicit_size := "--resolution" in OS.get_cmdline_args()
	if not explicit_size:
		_checks += 1
		if not usable.encloses(boot):
			_fails += 1
	print("\n########## WINDOW FIT ##########")
	print("  at boot                   %s  %s" % [str(boot),
		"(--resolution given, GameLaunch stood aside as designed)" if explicit_size
		else ("ok — GameLaunch fitted it at startup" if usable.encloses(boot)
			else "** THE GAME BOOTS WITH ITS WINDOW OFF THE SCREEN **")])
	win.size = Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width", 1920),
		ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	var before := Rect2i(win.get_position_with_decorations(), win.get_size_with_decorations())
	GameLaunch.fit_window_to_usable_screen()
	var after := Rect2i(win.get_position_with_decorations(), win.get_size_with_decorations())
	_checks += 1
	var fits := usable.encloses(after)
	if not fits:
		_fails += 1
	print("  usable screen rect        %s" % str(usable))
	print("  requested (project.godot) %s  %s" % [str(before),
		"fits" if usable.encloses(before) else "DOES NOT FIT — %d px past the bottom"
			% (before.end.y - usable.end.y)])
	print("  after fit_window_...      %s  %s" % [str(after),
		"ok" if fits else "** WINDOW STILL HANGS OFF THE SCREEN **"])
	print("  content rect             %s (the aspect is what the layout follows)"
		% str(get_viewport().get_visible_rect().size))

func _apply_size() -> void:
	var size: Vector2i = _sizes[_size_i]
	DisplayServer.window_set_size(size)
	get_window().size = size
	print("\n########## %d x %d ##########" % [size.x, size.y])

func _load() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
	var action := String(SCREENS[_i][3]) if SCREENS[_i].size() > 3 else ""
	if action != "":
		GameLaunch.pending_action = action
	_screen = (load(String(SCREENS[_i][1])) as PackedScene).instantiate()
	add_child(_screen)
	var tab: int = int(SCREENS[_i][2])
	if tab >= 0 and _screen is CharacterSelect:
		(_screen as CharacterSelect)._on_tab_pressed(tab)
	_settle = 20

func _process(_delta: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	set_process(false)
	await _report(String(SCREENS[_i][0]))
	await RenderingServer.frame_post_draw
	if _out != "":
		get_viewport().get_texture().get_image().save_png(
			_out + "ui_" + String(SCREENS[_i][0]) + ".png")
	_i += 1
	if _i >= SCREENS.size():
		_size_i += 1
		if _size_i < _sizes.size():
			_i = 0
			_apply_size()
			_load()
			set_process(true)
			return
		print("\nRESULT: ", "FAIL — %d of %d layout assertions failed" % [_fails, _checks]
			if _fails > 0 else "PASS — %d layout assertions, every checked control on "
			% _checks + "screen and no panel pair overlapping")
		get_tree().quit(1 if _fails > 0 else 0)
		return
	_load()
	set_process(true)

const WATCHED := ["BackButton", "PrimaryButton", "StartButton", "ConfirmButton",
	"DetailLabel", "TraitRows", "StatusLabel", "Banner", "ConfigPanel", "DetailBox",
	"TopLeft", "TopCentre", "TopRight", "YouCard", "Card", "LataCard",
	"ReadyPrompt", "ReadyObjectiveRow", "ToastLabel", "RoleSwapCard"]

func _report(tag: String) -> void:
	var screen_size := Vector2(get_viewport().get_visible_rect().size)
	print("[%s] viewport %.0fx%.0f" % [tag, screen_size.x, screen_size.y])
	if _i == 0:
		_checks += 1
		if _content_sizes.has(screen_size):
			_fails += 1
			print("  ** SAME CONTENT RECT ** requested %s but laid out %.0fx%.0f again — "
				% [str(_sizes[_size_i]), screen_size.x, screen_size.y]
				+ "this pass re-measures the previous one. Pick a different ASPECT.")
		else:
			print("  content rect %.0fx%.0f is new — this pass measures something"
				% [screen_size.x, screen_size.y])
		_content_sizes.append(screen_size)
	var preview := _screen.find_child("CharacterPreview", true, false) as CharacterPreview
	if preview != null:
		var sub := preview.get_node_or_null("SubViewport") as SubViewport
		var cam := preview.get_node_or_null("SubViewport/Camera3D") as Camera3D
		if sub != null and cam != null:
			print("  preview  container=%s subviewport=%s cam_pos=%s fov=%.1f h_offset=%.3f" % [
				str(preview.size), str(sub.size), str(cam.position), cam.fov, cam.h_offset])
	for name in WATCHED:
		var node := _screen.find_child(name, true, false) as Control
		if node == null:
			continue
		var rect := node.get_global_rect()
		var inside := rect.position.y >= -1.0 and rect.end.y <= screen_size.y + 1.0 \
			and rect.position.x >= -1.0 and rect.end.x <= screen_size.x + 1.0
		var hud_only := String(SCREENS[_i][1]).get_file() == "HUD.tscn"
		var full_bleed := rect.size.y >= screen_size.y - 1.0 \
			or rect.size.x >= screen_size.x - 1.0
		var clears := not hud_only or full_bleed or _clears_bands(rect, screen_size)
		_checks += 1
		if not inside or not clears:
			_fails += 1
		print("  %-14s x %6.0f..%-6.0f  y %6.0f..%-6.0f  %s" % [
			name, rect.position.x, rect.end.x, rect.position.y, rect.end.y,
			"ok" if inside and clears else ("** OFF SCREEN **" if not inside
				else "** INSIDE AN EDGE BAND (top %.0f bottom %.0f sides %.0f) **"
					% [TOP_SAFE_BAND, BOTTOM_SAFE_BAND, SIDE_SAFE_BAND])])
	_report_overlaps(String(SCREENS[_i][1]).get_file())
	_report_detail_fit()
	_report_detail_topics()
	_report_containment()
	await _report_you_card(screen_size)

func _report_overlaps(file_name: String) -> void:
	if not DISJOINT.has(file_name):
		return
	var rects: Dictionary = {}
	for name in DISJOINT[file_name]:
		var node := _screen.find_child(String(name), true, false) as Control
		if node == null:
			print("  overlap check: %-14s MISSING — cannot assert" % name)
			_fails += 1
			continue
		rects[name] = node.get_global_rect()
	var names: Array = rects.keys()
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			var a: Rect2 = rects[names[i]]
			var b: Rect2 = rects[names[j]]
			_checks += 1
			if a.intersects(b):
				_fails += 1
				print("  ** OVERLAP ** %s %s  ∩  %s %s"
					% [names[i], _fmt(a), names[j], _fmt(b)])
			else:
				print("  disjoint: %s and %s" % [names[i], names[j]])

func _fmt(r: Rect2) -> String:
	return "(%.0f,%.0f %.0fx%.0f)" % [r.position.x, r.position.y, r.size.x, r.size.y]


func _report_detail_fit() -> void:
	var box := _screen.find_child("DetailBox", true, false) as Control
	var label := _screen.find_child("DetailLabel", true, false) as Label
	if box == null or label == null or not _screen.has_method("detail_text_for"):
		return
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	if font == null:
		return

	var keep_map: int = _screen.get("_map_index")
	var keep_mode: int = _screen.get("_mode_index")
	var keep_tier: int = _screen.get("_difficulty_index")
	var keep_seat: int = GameLaunch.solo_seat

	var worst := 0.0
	var worst_label := ""
	var cases: Array = []
	for i in range(GameLaunch.MAPS.size()):
		cases.append(["_map_index", i, 0, "MAP %d" % i])
	for i in range(MatchSetupScreen.DIFFICULTIES.size()):
		cases.append(["_difficulty_index", i, 2,
			"TIER %s" % MatchSetupScreen.DIFFICULTIES[i]["label"]])
	for seat in range(4):
		cases.append(["", seat, 3, "SEAT %d" % seat])

	for case in cases:
		var field := String(case[0])
		if field == "":
			GameLaunch.solo_seat = int(case[1])
		else:
			_screen.set(field, int(case[1]))
		var text: String = _screen.call("detail_text_for", int(case[2]))
		var height := font.get_multiline_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, box.size.x, font_size).y
		if height > worst:
			worst = height
			worst_label = String(case[3])
		if field != "":
			_screen.set(field, keep_map if field == "_map_index" else (
				keep_mode if field == "_mode_index" else keep_tier))
	GameLaunch.solo_seat = keep_seat

	_checks += 1
	var fits := worst <= box.size.y + 1.0
	if not fits:
		_fails += 1
	print("  %-14s worst of %d selections is %s: %.0f px in a %.0f px box  %s" % [
		"DetailFit", cases.size(), worst_label, worst, box.size.y,
		"ok" if fits else "** DETAIL TEXT IS BEING CLIPPED **"])

func _report_detail_topics() -> void:
	var label := _screen.find_child("DetailLabel", true, false) as Label
	if label == null or not _screen.has_method("detail_text_for"):
		return
	var rows := {"MapRow": 0, "ModeRow": 1, "DifficultyRow": 2, "FighterRow": 3}
	var seen := {}
	for row_name in rows:
		var row := _screen.find_child(String(row_name), true, false) as Control
		_checks += 1
		if row == null:
			_fails += 1
			print("  %-14s %s MISSING — cannot assert" % ["DetailTopic", row_name])
			continue
		row.mouse_entered.emit()
		var shown := label.text
		var want: String = _screen.call("detail_text_for", rows[row_name])
		var ok := shown == want and shown != ""
		if seen.has(shown):
			ok = false
		seen[shown] = true
		if not ok:
			_fails += 1
		print("  %-14s hover %-14s -> %-30s %s" % [
			"DetailTopic", row_name, shown.substr(0, 28),
			"ok" if ok else "** BOX DID NOT FOLLOW THE HIGHLIGHT **"])

const CONTAINED: Dictionary = {
	"MatchSetup.tscn": [
		["MapRow", "ConfigPanel"], ["ModeRow", "ConfigPanel"],
		["DifficultyRow", "ConfigPanel"], ["FighterRow", "ConfigPanel"],
		["SeatButton0", "SeatPanel"], ["SeatButton3", "SeatPanel"],
		["DetailLabel", "DetailBox"],
	],
	"CharacterSelect.tscn": [
		["TabBar", "ConfigPanel"], ["NameRow", "ConfigPanel"],
		["TaglineLabel", "ConfigPanel"], ["TraitRows", "ConfigPanel"],
	],
}

const YOU_CARD_CASES := [
	["person_attacker_holding", ["HoldLabel"]],
	["person_attacker_charging", ["ChargeRow"]],
	["person_defender_channel", ["ResetChannelRow"]],
	["prop_guard_dash", ["GuardDashRow"]],
	["_control_all_rows_off", []],
]

const YOU_CARD_ROWS := ["GuardDashRow", "HoldLabel", "ChargeRow", "ResetChannelRow"]

const BOTTOM_SAFE_BAND: float = 64.0
const TOP_SAFE_BAND: float = 24.0
const SIDE_SAFE_BAND: float = 16.0

func _clears_bands(rect: Rect2, screen_size: Vector2) -> bool:
	return rect.position.y >= TOP_SAFE_BAND - 1.0 \
		and rect.end.y <= screen_size.y - BOTTOM_SAFE_BAND + 1.0 \
		and rect.position.x >= SIDE_SAFE_BAND - 1.0 \
		and rect.end.x <= screen_size.x - SIDE_SAFE_BAND + 1.0

const RUNTIME_MARGIN_H: float = 14.0
const RUNTIME_MARGIN_V: float = 8.0

func _report_you_card(screen_size: Vector2) -> void:
	if String(SCREENS[_i][1]).get_file() != "HUD.tscn":
		return
	var you := _screen.find_child("YouCard", true, false) as Control
	if you == null:
		_checks += 1
		_fails += 1
		print("  %-14s MISSING — cannot assert" % "YouCard")
		return
	you.set_process(false)
	you.visible = true
	var card := you.find_child("Card", true, false) as Control
	if card != null:
		var pad := StyleBoxFlat.new()
		pad.content_margin_left = RUNTIME_MARGIN_H
		pad.content_margin_right = RUNTIME_MARGIN_H
		pad.content_margin_top = RUNTIME_MARGIN_V
		pad.content_margin_bottom = RUNTIME_MARGIN_V
		card.add_theme_stylebox_override("panel", pad)
	for case in YOU_CARD_CASES:
		var wanted: Array = case[1]
		for row_name in YOU_CARD_ROWS:
			var row := you.find_child(String(row_name), true, false) as Control
			if row != null:
				row.visible = wanted.has(row_name)
		await get_tree().process_frame
		await get_tree().process_frame
		var rect := card.get_global_rect() if card != null else you.get_global_rect()
		var anchored := you.get_global_rect()
		_checks += 1
		var inside := rect.end.y <= screen_size.y + 1.0 and rect.position.y >= -1.0 \
			and rect.position.x >= -1.0 and rect.end.x <= screen_size.x + 1.0
		var in_box := rect.end.y <= anchored.end.y + 1.0
		var clears := _clears_bands(rect, screen_size)
		if not inside or not in_box or not clears:
			_fails += 1
		var content := card.get_combined_minimum_size().y if card != null else 0.0
		var verdict := "ok"
		if not inside:
			verdict = "** RUNS OFF THE SCREEN, %.0f px BELOW THE BOTTOM **" \
				% (rect.end.y - screen_size.y)
		elif not in_box:
			verdict = "** %.0f px BELOW ITS OWN ANCHOR BOX — grow_vertical must be BEGIN **" \
				% (rect.end.y - anchored.end.y)
		elif not clears:
			verdict = "** %.0f px INSIDE THE %.0f px BOTTOM BAND **" \
				% [rect.end.y - (screen_size.y - BOTTOM_SAFE_BAND), BOTTOM_SAFE_BAND]
		print("  %-14s %-24s card y %6.1f..%-7.1f (content %.0f px in a %.0f px anchor box)  %s" % [
			"YouCardRows", String(case[0]), rect.position.y, rect.end.y,
			content, anchored.size.y, verdict])

func _report_containment() -> void:
	var file_name := String(SCREENS[_i][1]).get_file()
	if not CONTAINED.has(file_name):
		return
	for pair in CONTAINED[file_name]:
		var inner := _screen.find_child(String(pair[0]), true, false) as Control
		var outer := _screen.find_child(String(pair[1]), true, false) as Control
		_checks += 1
		if inner == null or outer == null:
			_fails += 1
			print("  %-14s %s in %s — MISSING, cannot assert" % ["Contained", pair[0], pair[1]])
			continue
		var a := inner.get_global_rect()
		var b := outer.get_global_rect()
		var fits := a.position.x >= b.position.x - 1.0 and a.end.x <= b.end.x + 1.0 \
			and a.position.y >= b.position.y - 1.0 and a.end.y <= b.end.y + 1.0
		if not fits:
			_fails += 1
		print("  %-14s %-14s in %-12s  x %6.0f..%-6.0f vs %6.0f..%-6.0f  %s" % [
			"Contained", pair[0], pair[1], a.position.x, a.end.x, b.position.x, b.end.x,
			"ok" if fits else "** PUSHED OUT OF ITS BOX **"])

