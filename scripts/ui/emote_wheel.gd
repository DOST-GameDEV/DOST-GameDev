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
const EMOTES: Array[Dictionary] = [
	{"id": "yes", "label": "NICE"},
	{"id": "no", "label": "NOPE"},
	{"id": "sit", "label": "SIT"},
	{"id": "crouch", "label": "DUCK"},
	{"id": "dead", "label": "PLAY DEAD"},
]

## How far the stick has to travel from centre before a slice counts as chosen.
## Below it, releasing closes the wheel and plays nothing.
const DEAD_ZONE: float = 40.0
const RADIUS_OUTER: float = 190.0
const RADIUS_INNER: float = 72.0
## How far the highlighted slice pushes out past the others.
const SELECT_BULGE: float = 12.0
## Where the label sits between the inner and outer radius. Deliberately past the
## midpoint — the wedge widens outward, and the label needs the room. See the
## ⚠️⚠️ at the fit code in `_draw()`.
const LABEL_RADIUS_FRACTION: float = 0.62
## Fraction of the chord a label may occupy. The gap is what stops a horizontal
## text box clipping the wedge's diagonal edges at its corners.
const LABEL_FIT_MARGIN: float = 0.80
const LABEL_FONT_SIZE: int = 20
const LABEL_FONT_MIN: int = 13
## Relative-motion pixels are raw mouse counts; this scales them to something that
## crosses DEAD_ZONE with a normal flick rather than a shove.
const STICK_GAIN: float = 0.55
const STICK_CLAMP: float = 220.0

signal emote_chosen(id: String)

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
	_update_selection()
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
	for i in EMOTES.size():
		var chosen := i == _selection
		# Godot's arc angles run from +X too, so the same -90° rotation applies,
		# and the slice is drawn a hair short of `span` to leave a visible gap.
		var from := -TAU / 4.0 + span * float(i) + 0.012
		var to := -TAU / 4.0 + span * float(i + 1) - 0.012
		_draw_slice(centre, from, to, chosen)
		var mid := (from + to) * 0.5
		# ⚠️⚠️ SEATED OUTWARD AND SHRUNK TO FIT, BECAUSE "PLAY DEAD" RAN OUT OF ITS
		# OWN SLICE. 🧑: *"it goes out the circle u made"*, with the top-left wedge
		# circled. A label is a HORIZONTAL box and a wedge is bounded by two RADIAL
		# edges, so on the diagonal slices the corners of the box cross the boundary
		# long before the word is as wide as the arc — which is why the top and bottom
		# slices looked fine and the corners did not.
		#
		# Two fixes, together: sit the text further out, where the wedge is widest
		# (LABEL_RADIUS_FRACTION), and measure it against the chord actually available
		# there, shrinking the font until it fits. The measure is what stops this
		# coming back — a longer emote name added later shrinks instead of spilling.
		var span_radius := RADIUS_OUTER - RADIUS_INNER + (SELECT_BULGE if chosen else 0.0)
		var label_radius := RADIUS_INNER + span_radius * LABEL_RADIUS_FRACTION
		var label_at := centre + Vector2(cos(mid), sin(mid)) * label_radius
		var text := String(EMOTES[i]["label"])
		var font := get_theme_default_font()
		# The chord across the wedge at this radius, with a margin for the box corners.
		var available := 2.0 * label_radius * sin(span * 0.5) * LABEL_FIT_MARGIN
		var font_size := LABEL_FONT_SIZE
		while font_size > LABEL_FONT_MIN and font.get_string_size(
				text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size).x > available:
			font_size -= 1
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
		var text_at := label_at - text_size / 2.0 + Vector2(0, text_size.y * 0.35)
		# ⚠️⚠️ THE OUTLINE FLIPS WITH THE FILL, AND NOT DOING THAT MADE THE SELECTED
		# LABEL UNREADABLE. 🧑: *"it look a bit ugly when i select / i cant see text"*.
		# Both the text AND its 6 px outline were INK, so on the amber slice the
		# letterforms were ink drawn on top of an ink blob the same shape — the outline
		# filled the counters in and swallowed the word. Ink on cream is the same
		# emboss the wood buttons use, and it only reads if the two are opposites.
		var ink_on_amber := chosen
		draw_string_outline(font, text_at, text, HORIZONTAL_ALIGNMENT_CENTER, -1.0,
			font_size, 5, UiTheme.CREAM if ink_on_amber else UiTheme.INK)
		draw_string(font, text_at, text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size,
			UiTheme.INK if ink_on_amber else UiTheme.CREAM)
	# ⚠️ A RIM AROUND THE WHOLE THING. Without it the wheel dissolves into the
	# street at the outer edge — the slices are translucent by design, so the only
	# thing giving it an outline is this.
	draw_arc(centre, RADIUS_OUTER + 2.0, 0.0, TAU, 72, Color(UiTheme.INK, 0.85), 3.0, true)
	draw_arc(centre, RADIUS_INNER - 2.0, 0.0, TAU, 48, Color(UiTheme.INK, 0.85), 3.0, true)

	# The stick, so the player can see what the wheel thinks they are pointing at.
	# A ring rather than a disc: the hole in the middle is the clearest place to
	# keep an eye on the match, and filling it in is the one thing this overlay
	# should not do.
	draw_arc(centre, RADIUS_INNER * 0.30, 0.0, TAU, 32,
		Color(UiTheme.CREAM, 0.30 if _selection < 0 else 0.16), 2.0, true)
	if _stick.length() >= 1.0:
		var knob := centre + _stick.limit_length(RADIUS_OUTER - 14.0)
		draw_circle(knob, 10.0, Color(UiTheme.INK, 0.9))
		draw_circle(knob, 7.0, UiTheme.AMBER)

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
	draw_polyline(points, Color(UiTheme.CREAM, 0.7 if chosen else 0.22), 2.0, true)
