extends Control
class_name EmoteWheel

## THE EMOTE WHEEL. 🧑 2026-08-04: *"Like fortnite ig, we click a button and we
## could choose from a set"*, and *"dont let us change emotes anymore, dunno where
## to put it anwyays"* — so the set is fixed in code and there is no locker screen,
## no loadout, and nothing to configure.
##
## Hold the `emote_wheel` key to open, steer with the mouse, release to play the
## highlighted slice. Releasing near the centre plays nothing, which is the escape
## hatch for a player who opened it by accident.
##
## ⚠️ DRAWN, NOT BUILT FROM NODES. Eight slices, a highlight that follows the
## mouse and a label per slice is one `_draw()` and no scene — a Control per slice
## would be twenty-odd nodes rebuilt every time the set changed, all of them
## needing their own rotation and pivot. This also keeps the whole feature to one
## file plus one line in HUD.tscn.
##
## ⚠️ IT READS RELATIVE MOUSE MOTION, NOT THE CURSOR POSITION. The mouse is
## CAPTURED during a match — `Input.mouse_mode == MOUSE_MODE_CAPTURED` — so there is
## no pointer on screen to hit-test against, and `get_global_mouse_position()`
## returns a stale point that never moves. The wheel accumulates `relative` into a
## stick-like vector instead, exactly as a controller would drive it, and releasing
## the mouse capture to show a cursor would drop the player's aim on close.

## ⚠️ IDS MUST MATCH `character_visual.gd::EMOTE_CLIPS`. That dictionary owns which
## clip plays; this owns what the player is offered and what it is called. Kept as
## an ordered array rather than reading the dictionary's keys because a wheel has a
## clockwise order and a Dictionary does not promise one.
## ⚠️⚠️ TWO NAMES PER EMOTE, AND THAT IS THE FIX FOR A BUG I CHASED FOUR TIMES.
##
## `label` is the SHORT word drawn inside the slice. `name` is the full one, drawn
## in the hole in the middle when that slice is highlighted.
##
## 🧑 reported a label hanging out of its wedge four separate times — "it goes out
## the circle u made", "still overflows", "yea lmao still overflows lel", "IT DIDNT
## FIT ALLL I SAW" — and each of my fixes made the MEASUREMENT better while leaving
## the real problem alone: a two-word label in a 51-degree wedge is a bad fit even
## when the arithmetic says it clears the edges by four pixels. Bigger radii, corner
## tests and auto-shrinking all made it *technically* fit and still look wrong.
##
## So no long string is ever drawn in a wedge again. The slice gets a word that
## cannot overflow, and the full name goes in the middle — 208 px of empty hole that
## was doing nothing, which is also where Fortnite puts it and where the eye already
## is while steering.
const EMOTES: Array[Dictionary] = [
	{"id": "yes", "label": "NOD", "name": "NOD"},
	{"id": "no", "label": "NOPE", "name": "NOPE"},
	{"id": "sit", "label": "SIT", "name": "SIT DOWN"},
	{"id": "crouch", "label": "VICTORY", "name": "VICTORY POSE"},
	{"id": "dead", "label": "DEAD", "name": "PLAY DEAD"},
	{"id": "tpose", "label": "T-POSE", "name": "T-POSE"},
	{"id": "bow", "label": "BOW", "name": "BOW"},
]

## How far the stick has to travel from centre before a slice counts as chosen.
## Below it, releasing closes the wheel and plays nothing.
const DEAD_ZONE: float = 40.0
## ⚠️ SIZED FOR THE LABELS, NOT PICKED BY EYE — 🧑: *"so that it doesnt overflow js
## make the circle a bit bigger to account for it burh"*. At 190/72 with seven
## slices, "PLAY DEAD" and "VICTORY POSE" only fitted by wrapping onto two lines;
## the wedge is wider the further out you go, so growing the wheel buys single-line
## labels at full size. `overflow_report()` prints the font size and line count each
## label resolves to, which is how these two numbers were chosen rather than guessed.
const RADIUS_OUTER: float = 270.0
const RADIUS_INNER: float = 104.0
## ⚠️⚠️ THE HIGHLIGHT NO LONGER CHANGES THE WHEEL'S SHAPE, AND THIS WAS THE BUG.
##
## 🧑, after four rounds of me measuring the wrong thing: *"overflow is the shape
## man! it overflows when u hover"*, with the highlighted wedge circled poking out
## past the rim. It was never the text. The selected slice grew 14 px past
## RADIUS_OUTER while the rim arc stayed at RADIUS_OUTER + 2, so hovering broke the
## circle's silhouette — and every "fix" I shipped before this made the label
## arithmetic more precise while leaving that alone.
##
## The affordance is now colour and border weight only, plus the emote's full name
## in the middle. The outer edge is a constant, so the wheel is a circle in every
## state and there is nothing left that CAN overflow it.
##
## ⚠️ DO NOT REINTRODUCE AN OUTWARD BULGE. If a size change is ever wanted back, it
## has to grow INWARD (a smaller inner radius) so the silhouette is untouched.
const SELECT_BULGE: float = 0.0
## Where the label sits between the inner and outer radius. Deliberately past the
## midpoint — the wedge widens outward, and the label needs the room. See the
## ⚠️⚠️ at the fit code in `_draw()`.
const LABEL_RADIUS_FRACTION: float = 0.62
const LABEL_FONT_SIZE: int = 20
const LABEL_FONT_MIN: int = 13
## Multiplied by the font height to space stacked lines.
const LABEL_LINE_SPACING: float = 0.92
## Clearance kept between the label block and the wedge's edges, in pixels. Without
## it a label that technically fits sits with its letters touching the border.
const LABEL_PADDING: float = 6.0
## The angular gap drawn between neighbouring slices, in radians. Used by the fit
## test too, so a label can never stray into the seam.
const SLICE_GAP: float = 0.012
## Relative-motion pixels are raw mouse counts; this scales them to something that
## crosses DEAD_ZONE with a normal flick rather than a shove.
const STICK_GAIN: float = 0.55
const STICK_CLAMP: float = 220.0
## The full name in the middle. Bigger than a slice label because it has the room.
const CENTRE_FONT_SIZE: int = 26

signal emote_chosen(id: String)

## ⚠️ DIAGNOSTIC ONLY, OFF IN THE GAME. Draws each label's real bounding box and
## the wedge edges it is tested against, so "does it overflow" stops being a matter
## of squinting at a screenshot. tools/ui/emote_wheel_shot.tscn turns it on.
var debug_bounds: bool = false

var _open: bool = false
var _stick: Vector2 = Vector2.ZERO
var _selection: int = -1

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func is_open() -> bool:
	return _open

func open() -> void:
	if _open:
		return
	_open = true
	_stick = Vector2.ZERO
	_selection = -1
	visible = true
	queue_redraw()

## `play` false is a cancel — the wheel closes and nothing fires.
func close(play: bool) -> void:
	if not _open:
		return
	_open = false
	visible = false
	if play and _selection >= 0 and _selection < EMOTES.size():
		emote_chosen.emit(String(EMOTES[_selection]["id"]))
	_selection = -1

## ⚠️⚠️ `_input`, NOT `_unhandled_input`, AND THE DIFFERENCE IS THE WHOLE FEATURE.
## `camera_rig.gd` steers the player from ITS `_unhandled_input`, and every node's
## `_input` runs before any node's `_unhandled_input` — so this is the only
## placement that can reliably claim the motion first. As `_unhandled_input` the
## two would race on scene-tree order, and the losing half of that race is a player
## whose character spins on the spot while they pick a slice.
##
## ⚠️ AND IT MUST CONSUME. `set_input_as_handled()` is what stops the rig seeing the
## same motion afterwards; without it, being first would not matter.
func _input(event: InputEvent) -> void:
	if not _open or not (event is InputEventMouseMotion):
		return
	_stick += (event as InputEventMouseMotion).relative * STICK_GAIN
	if _stick.length() > STICK_CLAMP:
		_stick = _stick.normalized() * STICK_CLAMP
	var was := _selection
	_update_selection()
	# ⚠️ ON THE CHANGE, NOT ON THE MOTION. 🧑: *"add sound effect for mhovering thru
	# it, not too loud"*. This runs on every mouse-move event while the wheel is
	# open — firing per event would be dozens of overlapping voices a second. Only a
	# slice actually changing under the stick makes a sound, which is also the only
	# moment worth a sound. `ui_hover` already carries a -8 dB trim in
	# audio_manager.gd, whose own note says it "fires on every mouse move across a
	# menu", so the quiet level is the catalogue's decision rather than a number
	# invented here.
	if _selection != was and _selection >= 0:
		AudioManager.play("ui_hover")
	get_viewport().set_input_as_handled()
	queue_redraw()

func _update_selection() -> void:
	if _stick.length() < DEAD_ZONE:
		_selection = -1
		return
	# ⚠️ -90° SO SLICE 0 IS STRAIGHT UP. atan2 measures from +X (east) and the
	# wheel is read from the top, which is where the eye starts.
	var angle := fposmod(rad_to_deg(_stick.angle()) + 90.0, 360.0)
	var span := 360.0 / float(EMOTES.size())
	_selection = int(floor(angle / span)) % EMOTES.size()

func _draw() -> void:
	if not _open:
		return
	var centre := size / 2.0
	var span := TAU / float(EMOTES.size())
	var font := get_theme_default_font()
	for i in EMOTES.size():
		var chosen := i == _selection
		# Godot's arc angles run from +X too, so the same -90 degree rotation applies,
		# and the slice is drawn a hair short of `span` to leave a visible gap.
		var from := -TAU / 4.0 + span * float(i) + SLICE_GAP
		var to := -TAU / 4.0 + span * float(i + 1) - SLICE_GAP
		_draw_slice(centre, from, to, chosen)
		var mid := (from + to) * 0.5
		var outer := RADIUS_OUTER + (SELECT_BULGE if chosen else 0.0)
		var label_radius := RADIUS_INNER + (outer - RADIUS_INNER) * LABEL_RADIUS_FRACTION
		var offset := Vector2(cos(mid), sin(mid)) * label_radius

		# ⚠️⚠️ EVERY LABEL GOES THROUGH `_resolve_label`, WHICH IS ALSO WHAT
		# `overflow_report()` CALLS. Two copies of this logic is how a wheel ends up
		# passing its own fit check and still overflowing on screen.
		var resolved := _resolve_label(font, String(EMOTES[i]["label"]), offset, mid, span, outer)
		var lines: Array[String] = resolved["lines"]
		var font_size: int = resolved["font_size"]

		# ⚠️⚠️ THE OUTLINE FLIPS WITH THE FILL, AND NOT DOING THAT MADE THE
		# SELECTED LABEL UNREADABLE. 🧑: *"it look a bit ugly when i select / i cant see
		# text"*. Both the text AND its outline were INK, so on the amber slice the
		# letterforms were ink drawn over an ink blob of the same shape — the outline
		# filled the counters in and swallowed the word. Ink on cream is the emboss the
		# wood buttons use, and it only reads because the two are opposites.
		if debug_bounds:
			_draw_label_bounds(centre, offset, font, lines, font_size, from, to, outer)
		var fill: Color = UiTheme.INK if chosen else UiTheme.CREAM
		var halo: Color = UiTheme.CREAM if chosen else UiTheme.INK
		var line_h := font.get_height(font_size) * LABEL_LINE_SPACING
		var block_h := line_h * float(lines.size())
		for l in lines.size():
			var text: String = lines[l]
			var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
			var at := centre + offset + Vector2(
				-ts.x / 2.0,
				-block_h / 2.0 + line_h * (float(l) + 0.5) + ts.y * 0.32)
			draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, -1.0,
				font_size, 5, halo)
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, fill)
	# ⚠️ A RIM AROUND THE WHOLE THING. Without it the wheel dissolves into the
	# street at the outer edge — the slices are translucent by design, so the only
	# thing giving it an outline is this.
	draw_arc(centre, RADIUS_OUTER + 2.0, 0.0, TAU, 72, Color(UiTheme.INK, 0.85), 3.0, true)
	draw_arc(centre, RADIUS_INNER - 2.0, 0.0, TAU, 48, Color(UiTheme.INK, 0.85), 3.0, true)

	# ⚠️ THE FULL NAME GOES IN THE HOLE. The slice carries a short word that cannot
	# overflow a 51-degree wedge; the middle is 200 px of empty space the eye is
	# already on while steering, so the long form costs nothing and reads better.
	if _selection >= 0 and _selection < EMOTES.size():
		var full := String(EMOTES[_selection].get("name", EMOTES[_selection]["label"]))
		var nf := get_theme_default_font()
		var ns := nf.get_string_size(full, HORIZONTAL_ALIGNMENT_CENTER, -1.0, CENTRE_FONT_SIZE)
		var nat := centre - ns / 2.0 + Vector2(0, ns.y * 0.32)
		draw_string_outline(nf, nat, full, HORIZONTAL_ALIGNMENT_CENTER, -1.0,
			CENTRE_FONT_SIZE, 6, UiTheme.INK)
		draw_string(nf, nat, full, HORIZONTAL_ALIGNMENT_CENTER, -1.0,
			CENTRE_FONT_SIZE, UiTheme.AMBER)

	# The stick, so the player can see what the wheel thinks they are pointing at.
	# A ring rather than a disc: the hole in the middle is the clearest place to
	# keep an eye on the match, and filling it in is the one thing this overlay
	# should not do.
	draw_arc(centre, RADIUS_INNER * 0.30, 0.0, TAU, 32,
		Color(UiTheme.CREAM, 0.30 if _selection < 0 else 0.16), 2.0, true)
	# ⚠️ THE KNOB RIDES THE INNER RING, NOT THE STICK'S RAW LENGTH. Left free it
	# wanders into the label band and sits on top of a word — visible in the first
	# render of this fix, straddling "BOW". Direction is the only part that carries
	# meaning; how far the stick has travelled is already said by the highlight.
	if _stick.length() >= 1.0:
		var knob := centre + _stick.normalized() * (RADIUS_INNER - 16.0)
		draw_circle(knob, 10.0, Color(UiTheme.INK, 0.9))
		draw_circle(knob, 7.0, UiTheme.AMBER)

## ⚠⚠ THE ONE PLACE A LABEL'S LAYOUT IS DECIDED — `_draw()` and
## `overflow_report()` both call this, so the check and the drawing can never
## disagree. They did briefly, and a fit report that describes different geometry
## from the thing on screen is worse than no report.
##
## ⚠️ ORDER MATTERS: FULL SIZE ON ONE LINE FIRST. The first version split on a
## space unconditionally, so "PLAY DEAD" and "VICTORY POSE" wrapped to two lines
## even once the wheel was big enough to hold them whole — the wrap was never a
## last resort, it was the default. Now each option is tried in order of how much
## it costs the reader: one line at full size, then two lines at full size, then
## shrinking, and only then breaking a single long word.
func _resolve_label(font: Font, label: String, offset: Vector2, mid: float,
		span: float, outer: float) -> Dictionary:
	var one: Array[String] = [label]
	if _label_fits(font, one, LABEL_FONT_SIZE, offset, mid, span, outer):
		return {"lines": one, "font_size": LABEL_FONT_SIZE}
	var candidates: Array = [_label_lines(label), _label_lines(label, true)]
	for lines in candidates:
		if lines.size() > 1 and _label_fits(font, lines, LABEL_FONT_SIZE, offset, mid, span, outer):
			return {"lines": lines, "font_size": LABEL_FONT_SIZE}
	# Nothing fits at full size — shrink, preferring the fewest lines that work.
	for lines in ([one] as Array) + candidates:
		var font_size := LABEL_FONT_SIZE
		while font_size > LABEL_FONT_MIN and not _label_fits(
				font, lines, font_size, offset, mid, span, outer):
			font_size -= 1
		if _label_fits(font, lines, font_size, offset, mid, span, outer):
			return {"lines": lines, "font_size": font_size}
	return {"lines": one, "font_size": LABEL_FONT_MIN}

## Splits a label for drawing. Normally at its spaces ("PLAY DEAD" -> two lines);
## with `force` it will also break a single long word in half, which is the last
## resort before the type goes unreadably small.
func _label_lines(label: String, force: bool = false) -> Array[String]:
	var out: Array[String] = []
	if label.contains(" "):
		for part in label.split(" ", false):
			out.append(String(part))
		return out
	if force and label.length() > 5:
		var cut := int(ceil(float(label.length()) / 2.0))
		out.append(label.substr(0, cut))
		out.append(label.substr(cut))
		return out
	out.append(label)
	return out

## Is every corner of this text block inside this wedge?
##
## ⚠️ THE WHOLE POINT IS THE CORNERS. The wedge is bounded by two RADIAL edges and
## two arcs, and the text block is axis-aligned — so the failure mode is always a
## corner crossing a radial edge while the centre still has room. Checking the
## block's width against the arc cannot see that, which is how "PLAY DEAD" and then
## "DUCK" both shipped hanging out of their slices.
##
## `offset` is the block's centre relative to the wheel's centre.
func _label_fits(font: Font, lines: Array[String], font_size: int, offset: Vector2,
		mid: float, span: float, outer: float) -> bool:
	var line_h := font.get_height(font_size) * LABEL_LINE_SPACING
	var block_h := line_h * float(lines.size())
	var widest := 0.0
	for text in lines:
		widest = maxf(widest,
			font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size).x)
	var half := Vector2(widest, block_h) * 0.5 + Vector2(LABEL_PADDING, LABEL_PADDING)
	var half_span := span * 0.5 - SLICE_GAP
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := offset + Vector2(half.x * sx, half.y * sy)
			var radius := corner.length()
			if radius < RADIUS_INNER or radius > outer:
				return false
			if absf(angle_difference(mid, corner.angle())) > half_span:
				return false
	return true

## ⚠️⚠️ THE OVERFLOW CHECK, EXPOSED SO A PROBE CAN ASSERT IT INSTEAD OF A HUMAN
## SQUINTING AT A SCREENSHOT. 🧑 reported a label hanging out of its slice three
## separate times — "it goes out the circle u made", "still overflows", "yea lmao
## still overflows lel" — and each time the check was a render I looked at, for ONE
## slice, in ONE selection state. That is exactly the kind of thing eyes are bad at
## and a loop is good at: five slices times selected/unselected is ten cases, and
## the bulge changes the geometry of the selected one.
##
## Returns a list of human-readable failures, empty when every label fits.
func overflow_report() -> Array[String]:
	var bad: Array[String] = []
	bad_detail.clear()
	var span := TAU / float(EMOTES.size())
	var font := get_theme_default_font()
	if font == null:
		bad.append("no theme font — cannot measure anything")
		return bad
	for i in EMOTES.size():
		for chosen in [false, true]:
			var from := -TAU / 4.0 + span * float(i) + SLICE_GAP
			var to := -TAU / 4.0 + span * float(i + 1) - SLICE_GAP
			var mid := (from + to) * 0.5
			var outer := RADIUS_OUTER + (SELECT_BULGE if chosen else 0.0)
			var label_radius := RADIUS_INNER + (outer - RADIUS_INNER) * LABEL_RADIUS_FRACTION
			var offset := Vector2(cos(mid), sin(mid)) * label_radius
			var label := String(EMOTES[i]["label"])
			var resolved := _resolve_label(font, label, offset, mid, span, outer)
			var lines: Array[String] = resolved["lines"]
			var font_size: int = resolved["font_size"]
			if not _label_fits(font, lines, font_size, offset, mid, span, outer):
				bad.append("'%s' OVERFLOWS its slice (%s, smallest font %d)"
					% [label, "selected" if chosen else "resting", font_size])
			elif not chosen:
				# Not a failure — but a label that only fits by wrapping or shrinking is
				# the wheel telling you it wants to be bigger. Reported so that is a
				# number rather than a judgement call.
				bad_detail.append("  %-14s font %d, %d line(s)%s"
					% [label, font_size, lines.size(),
						"" if font_size == LABEL_FONT_SIZE and lines.size() == 1
						else "   <- shrunk/wrapped"])
	return bad

## Companion to `overflow_report()` — how each label actually resolved. Filled by
## the same pass, so the two can never describe different geometry.
var bad_detail: Array[String] = []

## Red box = what the label actually occupies. Green = the wedge it must stay in.
func _draw_label_bounds(centre: Vector2, offset: Vector2, font: Font,
		lines: Array[String], font_size: int, from: float, to: float, outer: float) -> void:
	var line_h := font.get_height(font_size) * LABEL_LINE_SPACING
	var widest := 0.0
	for text in lines:
		widest = maxf(widest,
			font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size).x)
	var half := Vector2(widest, line_h * float(lines.size())) * 0.5 		+ Vector2(LABEL_PADDING, LABEL_PADDING)
	draw_rect(Rect2(centre + offset - half, half * 2.0), Color(1, 0, 0, 1), false, 2.0)
	for a in [from, to]:
		draw_line(centre + Vector2(cos(a), sin(a)) * RADIUS_INNER,
			centre + Vector2(cos(a), sin(a)) * outer, Color(0, 1, 0, 1), 2.0)
	draw_arc(centre, outer, from, to, 24, Color(0, 1, 0, 1), 2.0, true)
	draw_arc(centre, RADIUS_INNER, from, to, 24, Color(0, 1, 0, 1), 2.0, true)

func _draw_slice(centre: Vector2, from: float, to: float, chosen: bool) -> void:
	var steps := 18
	# ⚠️ THE CHOSEN SLICE GROWS OUTWARD. On a wheel held for a fraction of a second
	# over a moving street, a colour change alone is easy to miss — the silhouette
	# changing is not, and it is the affordance every radial menu uses.
	var outer := RADIUS_OUTER + (SELECT_BULGE if chosen else 0.0)
	var points := PackedVector2Array()
	for s in steps + 1:
		var a: float = lerpf(from, to, float(s) / float(steps))
		points.append(centre + Vector2(cos(a), sin(a)) * outer)
	for s in range(steps, -1, -1):
		var a: float = lerpf(from, to, float(s) / float(steps))
		points.append(centre + Vector2(cos(a), sin(a)) * RADIUS_INNER)
	# ⚠️ THE RESTING FILL IS DELIBERATELY THIN — 🧑 asked for "smth transparent ...
	# and in theme". INK at 0.58 is the same navy the wood panels are outlined in,
	# dark enough to carry cream lettering over a sunlit street and light enough
	# that the player can still see who is running at them while they pick.
	var fill: Color = UiTheme.AMBER if chosen else Color(UiTheme.INK, 0.58)
	draw_colored_polygon(points, fill)
	# ⚠️ WEIGHT, NOT SIZE. The selected slice reads by a brighter, thicker border and
	# the amber fill — never by growing past the rim. See SELECT_BULGE.
	draw_polyline(points, Color(UiTheme.CREAM, 0.85 if chosen else 0.22),
		3.5 if chosen else 2.0, true)
