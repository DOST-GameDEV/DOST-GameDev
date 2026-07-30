extends Node

## LOOK AT THE FRONT END, at the real 1920x1080 base resolution.
##
## Every UI item in this pass is a LAYOUT claim — the BACK button not running off
## the bottom, three explanation lines fitting in the left column, the trait
## meters fitting inside the wood panel — and a layout claim is the one kind that
## a parse check, a probe and a code review all pass while the screen is still
## wrong. `Dev_Plan.md` §1 is explicit that this project has shipped code that
## was written, reviewed and never run.
##
## Renders both setup screens and reports whether anything landed outside the
## viewport, which is the specific failure being fixed.
##
##     godot --path . tools/ui_layout_probe.tscn --resolution 1920x1080 -- C:\tmp\

## `tab` is which CHARACTER tab to open before rendering, or -1 for "leave it".
## The tsinelas tab is listed separately because it is the one the report was
## about ("the weird viewing angle for the slippers") and it is also the hardest
## subject to frame — 0.432 long by 0.078 tall against a 4-unit standing figure.
## A fourth field, `action`, is the `GameLaunch.pending_action` the screen is stood
## up under — "" leaves whatever the previous entry set.
##
## ⚠️ `match_setup_host` EXISTS BECAUSE SOLO AND MULTIPLAYER ARE NOT THE SAME
## LAYOUT, though they are the same scene. 🧑 asked for the setup-screen fixes to
## "apply ... to multiplayer screen to", and a solo-only pass cannot answer that:
## `_setup_host()` makes `StartButton` VISIBLE, which adds a second 101px pennant
## to a left column that already had `BackButton` closest to the bottom edge. A
## column that fits in solo can therefore still overflow as a host, and every
## number this probe had ever printed described solo.
const SCREENS := [
	["hud", "res://scenes/ui/HUD.tscn", -1, "local"],
	["match_setup", "res://scenes/ui/MatchSetup.tscn", -1, "local"],
	["match_setup_host", "res://scenes/ui/MatchSetup.tscn", -1, "host"],
	["character_select", "res://scenes/ui/CharacterSelect.tscn", 0, "local"],
	["character_select_lata", "res://scenes/ui/CharacterSelect.tscn", 1, "local"],
	["character_select_tsinelas", "res://scenes/ui/CharacterSelect.tscn", 2, "local"],
]

## ⚠️ EXTENDED 2026-07-30 WITH THE TWO THINGS THE VERIFICATION CONTRACT ASKS FOR AND
## THIS FILE DID NOT DO.
##
## 1. **PAIRWISE OVERLAP, on the laid-out rects.** Checking that a control is inside
##    the viewport does not catch the bug that actually shipped: `MatchSetup`'s two
##    panels were both perfectly on screen and on top of each other. A Control's size
##    is clamped UP to its combined minimum size, so an absolute offset is a starting
##    guess the layout may overrule — which is why `Rect2.intersects()` on
##    `get_global_rect()` is the assertion and `offset_right` is not.
## 2. **A SECOND RESOLUTION.** 1920x1080 is the design size and was the only one
##    anything had ever been checked at (`Checklist.md` 10.5.1's own caveat). A
##    container-driven layout is a claim until a different viewport agrees with it.
##    ⚠️ The second preset was 1280x720, which under `stretch/aspect="expand"` lays
##    out in the SAME content rect as the base and so re-measured the first pass —
##    corrected to 21:9, and a `SAME CONTENT RECT` assertion now makes that class of
##    self-deception fail instead of print. See `PRESETS`.
##
## It caught its first regression immediately: adding R-09's difficulty row pushed
## `BackButton` 7px off the bottom of the left column at 1080p.
##
##     godot --path <ABS> tools/ui_layout_probe.tscn                 # 16:9 then 21:9
##     godot --path <ABS> tools/ui_layout_probe.tscn -- <out-dir>/   # ...and write PNGs
##     godot --path <ABS> tools/ui_layout_probe.tscn -- "" 2560x1080 # one explicit size
##     godot --path <ABS> tools/ui_layout_probe.tscn -- "" 1920x1080,1280x720  # a list

## Sibling groups that must never overlap each other, per screen file name. Empty or
## missing means "no pair to check on this screen" — the viewport test still runs.
const DISJOINT: Dictionary = {
	# The two that actually collided in a shipped build.
	# ⚠️ `Banner` JOINED THIS LIST 2026-07-30. The pennant is hand-placed
	# (`layout_mode = 0`) while everything under it is container-driven, so it is
	# exactly the pair no container can keep apart — and it had been sitting ON
	# TOP of `ConfigPanel`, clipping "SINGLE PLAYER" in half, in a build this
	# assertion passed because the pennant was never one of the names.
	"MatchSetup.tscn": ["ConfigPanel", "SeatPanel", "Banner"],
	# The HUD's own version of the same risk: two team panels and the centre timer
	# share one line across the top, and the team labels carry a role word that a
	# longer one would widen.
	"HUD.tscn": ["TopLeft", "TopCentre", "TopRight"],
}

## The design size first, then the one that catches a layout which only works at it.
##
## ⚠️ CORRECTED 2026-07-30. The second preset was `1280x720` and it tested NOTHING:
## every rect it printed was identical to the 1080p pass, digit for digit, and the
## header said `viewport 1920x1080` under a `########## 1280 x 720 ##########` banner.
##
## The cause is NOT that `_apply_size()` fails — it demonstrably works, `2560x1080`
## reports `viewport 2560x1080`. It is `project.godot`'s
## `stretch/mode="canvas_items"` + `stretch/aspect="expand"`. Under `expand` the
## content rect is derived from the window's ASPECT, not its pixel count, and 1280x720
## is exactly 16:9 — the same aspect as the 1920x1080 base — so the content rect stays
## 1920x1080 and every laid-out rect is obliged to be identical. 720p was a second
## WINDOW SIZE dressed up as a second layout case.
##
## Worth knowing before picking a replacement: `expand` only ever GROWS the content
## rect. 1440x1080 (4:3) reports `1920x1440` — taller, never narrower. So no window
## can squeeze a control off the RIGHT edge, and 16:9 is permanently the tightest
## case vertically, which is why R-09's 7px overflow only ever showed at 1080p.
##
## `2560x1080` (21:9) is therefore the preset that earns its runtime: the content rect
## widens to 2560, so anything anchored right or centred MOVES relative to the
## left-anchored panels, which is exactly the drift the overlap assertion exists for.
const PRESETS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1080)]

var _out := ""
var _i := 0
var _settle := 0
var _screen: Node = null
var _fails := 0
var _checks := 0
var _sizes: Array[Vector2i] = []
var _size_i := 0
## The CONTENT rect each pass actually laid out in, one entry per size, so the run can
## assert the passes differed instead of trusting the banner. See `PRESETS`.
var _content_sizes: Array[Vector2] = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_out = String(args[0]) if args.size() > 0 else ""
	# Comma-separated, so an explicit run can pass more than one size — which is what
	# proves the `SAME CONTENT RECT` assertion actually fires:
	#   -- "" 1920x1080,1280x720   ->  FAIL, the two lay out identically
	var specs := PackedStringArray()
	if args.size() > 1:
		specs = String(args[1]).split(",", false)
	for spec in specs:
		var parts := String(spec).strip_edges().split("x")
		if parts.size() == 2:
			_sizes.append(Vector2i(int(parts[0]), int(parts[1])))
	if _sizes.is_empty():
		_sizes.assign(PRESETS)
	# Solo, so MatchSetup takes the branch that needs no ENet session at all.
	GameLaunch.pending_action = "local"
	_apply_size()
	_load()

## The WINDOW drives the viewport and the viewport drives every laid-out rect, so
## resizing the viewport alone would leave the window's stretch transform stale and
## report rects nobody will ever see.
func _apply_size() -> void:
	var size: Vector2i = _sizes[_size_i]
	DisplayServer.window_set_size(size)
	get_window().size = size
	print("\n########## %d x %d ##########" % [size.x, size.y])

func _load() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
	# ⚠️ BEFORE instantiate(). `match_setup.gd` reads `pending_action` in its own
	# `_ready()` and never looks again, so setting it afterwards measures a solo
	# screen while the log calls it a host one.
	var action := String(SCREENS[_i][3]) if SCREENS[_i].size() > 3 else ""
	if action != "":
		GameLaunch.pending_action = action
	_screen = (load(String(SCREENS[_i][1])) as PackedScene).instantiate()
	add_child(_screen)
	var tab: int = int(SCREENS[_i][2])
	if tab >= 0 and _screen is CharacterSelect:
		# Through the screen's own handler rather than by poking its state, so
		# what is rendered is what a player clicking that tab would actually get.
		(_screen as CharacterSelect)._on_tab_pressed(tab)
	_settle = 20

func _process(_delta: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	set_process(false)
	_report(String(SCREENS[_i][0]))
	await RenderingServer.frame_post_draw
	if _out != "":
		get_viewport().get_texture().get_image().save_png(
			_out + "ui_" + String(SCREENS[_i][0]) + ".png")
	_i += 1
	if _i >= SCREENS.size():
		# Every screen done at this size; go round again at the next one before
		# reporting, so one invocation covers the whole contract.
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

## Every named control that has ever been reported as off-screen, plus the ones
## this pass moved. Checked against the VIEWPORT rect rather than against a
## parent, because "off the bottom of the screen" is what was reported and a
## control can be perfectly placed inside a container that is itself too tall.
const WATCHED := ["BackButton", "PrimaryButton", "StartButton", "ConfirmButton",
	"DetailLabel", "TraitRows", "StatusLabel", "Banner", "ConfigPanel", "DetailBox"]

func _report(tag: String) -> void:
	var screen_size := Vector2(get_viewport().get_visible_rect().size)
	print("[%s] viewport %.0fx%.0f" % [tag, screen_size.x, screen_size.y])
	# ⚠️ THE ASSERTION THAT WOULD HAVE CAUGHT THE FAKE 720p PASS. A second preset only
	# counts as a second layout case if the CONTENT rect changed; under
	# `stretch/aspect="expand"` a same-aspect window leaves it untouched and every rect
	# below is a copy of the previous pass. Checked once per size, on the first screen.
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
	# The 3D framing, not just the 2D rects — "the subject is cropped" is a camera
	# fact and none of the Control rects below can see it.
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
		_checks += 1
		if not inside:
			_fails += 1
		print("  %-14s x %6.0f..%-6.0f  y %6.0f..%-6.0f  %s" % [
			name, rect.position.x, rect.end.x, rect.position.y, rect.end.y,
			"ok" if inside else "** OFF SCREEN **"])
	_report_overlaps(String(SCREENS[_i][1]).get_file())
	_report_detail_fit()
	_report_detail_topics()
	_report_containment()

## ⚠️ THE ASSERTION THAT CATCHES THE CLASS OF BUG THAT ALREADY SHIPPED ONCE.
## Every PAIR in the group, not just adjacent ones — a three-panel row can have the
## outer two meet in the middle when the centre one is narrow — and on
## `get_global_rect()`, never on an offset.
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


## ⚠️ THE ASSERTION THE FIXED-HEIGHT DETAIL BOX NEEDS, AND THE ONE A SCREENSHOT
## CANNOT MAKE. `DetailBox` is `clip_contents`, so copy that overflows it no longer
## pushes `BackButton` off the bottom — it silently disappears instead, which
## trades a visible bug for an invisible one. 🧑 asked for exactly this guarantee:
## *"make sure that truncating it doesnt cause it to overflow or look bad."*
##
## ⚠️ SWEEPS EVERY SELECTION, NOT THE ONE THE SCREEN OPENED ON. This is the whole
## point and the first version got it wrong: it measured the four topics at the
## DEFAULT map/mode/tier/seat and reported a comfortable 96px in a 150px box. But
## every one of those strings is selection-dependent — DENTS is longer than
## CAPTURE, HARD is longer than NORMAL, the PERSON seat blurb is longer than the
## OBJECT one and it interpolates two roster names whose lengths vary too. The
## default is nowhere near the worst case, so a probe that only measures it is
## certifying a box against copy nobody will read.
##
## So: drive the screen's own indices across their full range, ask it for the
## string each time, and hold the TALLEST of all of them to the box.
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
	for i in range(MatchSetupScreen.MODES.size()):
		cases.append(["_mode_index", i, 1, "MODE %s" % MatchSetupScreen.MODES[i]["label"]])
	for i in range(MatchSetupScreen.DIFFICULTIES.size()):
		cases.append(["_difficulty_index", i, 2,
			"TIER %s" % MatchSetupScreen.DIFFICULTIES[i]["label"]])
	# The seat blurb is the one that reads off GameLaunch rather than off an index
	# on the screen, and it is also the longest of the four — both halves of the
	# PERSON / OBJECT split have to be measured, not just whichever seat is current.
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
	# ⚠️ THE HEADROOM IS THE POINT, not just the pass. Measured 2026-07-30 at
	# 1080p: one line is 32px, and the eleven selections come out 32 / 64 / 96 —
	# so the box holds the worst real string with a full line and a half to spare.
	# If a future copy edit takes this past ~128 the right move is to raise the box
	# (BackButton has ~72px of slack under it), NOT to let clip_contents eat a line.
	print("  %-14s worst of %d selections is %s: %.0f px in a %.0f px box  %s" % [
		"DetailFit", cases.size(), worst_label, worst, box.size.y,
		"ok" if fits else "** DETAIL TEXT IS BEING CLIPPED **"])

## ⚠️ THE BEHAVIOURAL HALF, AND IT IS NOT A LAYOUT CLAIM — kept here anyway because
## this is the only harness that already stands `MatchSetup` up with its autoloads.
## 🧑 asked for "the description ... to only show up when i highlight it, example i
## highlight map, it will show map desc but if i highlight mode ... that text box
## will change". Every part of that is invisible to a screenshot and to the rect
## checks above: the box is the right size and in the right place whichever topic
## it is showing.
##
## Drives the REAL signal (`mouse_entered` on the row) rather than calling the
## handler directly, so a row that was never wired fails here — which is the actual
## regression risk, four rows wired by hand in `_ready`.
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
		# ⚠️ DISTINCTNESS IS PART OF IT. Four rows that all "match" because every
		# topic returns the same string would pass the equality check above and be
		# exactly the reported bug — one box that never changes.
		if seen.has(shown):
			ok = false
		seen[shown] = true
		if not ok:
			_fails += 1
		print("  %-14s hover %-14s -> %-30s %s" % [
			"DetailTopic", row_name, shown.substr(0, 28),
			"ok" if ok else "** BOX DID NOT FOLLOW THE HIGHLIGHT **"])

## ⚠️ A CONTROL PUSHED OUT OF THE PANEL DRAWN BEHIND IT — 🧑 report, 2026-07-30:
## *"wtf the text goes out of the boxes now."*
##
## ⚠️ THE OBVIOUS VERSION OF THIS CHECK IS VACUOUS, and it was written and run
## before this one replaced it. Measuring a Label's string against the Label's OWN
## rect always passes: a non-clipping Label's minimum size IS its text width, so the
## rect grows to fit and the comparison can never fail. It printed "every
## fixed-width label fits its control" against the exact build whose screenshot
## shows the selector hanging off the panel — a green check beside a visible bug,
## which is the failure mode this whole probe exists to prevent.
##
## What actually happens is a ROW-MATE problem. Renaming `SINO:` to `CHARACTER:`
## more than doubled that caption's minimum width; the HBox honoured it, handed the
## remainder to `CharSelector`, and the selector — which has a 380px minimum of its
## own — was pushed straight through `ConfigPanel`'s right edge. Every rect involved
## is on screen and no two PANELS overlap, so the viewport check and the disjoint
## check pass as well.
##
## So the assertion is CONTAINMENT: this control must sit inside that ancestor's
## rect. It is the only one of the four that can see a copy change break a box.
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
		# One pixel of slack each way: a child laid out flush against its parent's
		# edge is correct, and the two rects are computed by different paths.
		var fits := a.position.x >= b.position.x - 1.0 and a.end.x <= b.end.x + 1.0 \
			and a.position.y >= b.position.y - 1.0 and a.end.y <= b.end.y + 1.0
		if not fits:
			_fails += 1
		print("  %-14s %-14s in %-12s  x %6.0f..%-6.0f vs %6.0f..%-6.0f  %s" % [
			"Contained", pair[0], pair[1], a.position.x, a.end.x, b.position.x, b.end.x,
			"ok" if fits else "** PUSHED OUT OF ITS BOX **"])
