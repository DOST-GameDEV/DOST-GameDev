extends Control
class_name EmoteWheel


const EMOTES: Array[Dictionary] = [
	{"id": "yes", "label": "NOD", "name": "NOD"},
	{"id": "no", "label": "NOPE", "name": "NOPE"},
	{"id": "sit", "label": "SIT", "name": "SIT DOWN"},
	{"id": "crouch", "label": "VICTORY", "name": "VICTORY POSE"},
	{"id": "dance", "label": "DANCE", "name": "DANCE"},
	{"id": "tpose", "label": "T-POSE", "name": "T-POSE"},
	{"id": "bow", "label": "BOW", "name": "BOW"},
]

const DEAD_ZONE: float = 40.0
const RADIUS_OUTER: float = 270.0
const RADIUS_INNER: float = 104.0
const SELECT_BULGE: float = 0.0
const LABEL_RADIUS_FRACTION: float = 0.62
const LABEL_FONT_SIZE: int = 20
const LABEL_FONT_MIN: int = 13
const LABEL_LINE_SPACING: float = 0.92
const LABEL_PADDING: float = 6.0
const SLICE_GAP: float = 0.012
const STICK_GAIN: float = 0.55
const STICK_CLAMP: float = 220.0
const CENTRE_FONT_SIZE: int = 26

signal emote_chosen(id: String)

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

func close(play: bool) -> void:
	if not _open:
		return
	_open = false
	visible = false
	if play and _selection >= 0 and _selection < EMOTES.size():
		emote_chosen.emit(String(EMOTES[_selection]["id"]))
	_selection = -1

func _input(event: InputEvent) -> void:
	if not _open or not (event is InputEventMouseMotion):
		return
	_stick += (event as InputEventMouseMotion).relative * STICK_GAIN
	if _stick.length() > STICK_CLAMP:
		_stick = _stick.normalized() * STICK_CLAMP
	var was := _selection
	_update_selection()
	if _selection != was and _selection >= 0:
		AudioManager.play("ui_hover")
	get_viewport().set_input_as_handled()
	queue_redraw()

func _update_selection() -> void:
	if _stick.length() < DEAD_ZONE:
		_selection = -1
		return
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
		var from := -TAU / 4.0 + span * float(i) + SLICE_GAP
		var to := -TAU / 4.0 + span * float(i + 1) - SLICE_GAP
		_draw_slice(centre, from, to, chosen)
		var mid := (from + to) * 0.5
		var outer := RADIUS_OUTER + (SELECT_BULGE if chosen else 0.0)
		var label_radius := RADIUS_INNER + (outer - RADIUS_INNER) * LABEL_RADIUS_FRACTION
		var offset := Vector2(cos(mid), sin(mid)) * label_radius

		var resolved := _resolve_label(font, String(EMOTES[i]["label"]), offset, mid, span, outer)
		var lines: Array[String] = resolved["lines"]
		var font_size: int = resolved["font_size"]

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
	draw_arc(centre, RADIUS_OUTER + 2.0, 0.0, TAU, 72, Color(UiTheme.INK, 0.85), 3.0, true)
	draw_arc(centre, RADIUS_INNER - 2.0, 0.0, TAU, 48, Color(UiTheme.INK, 0.85), 3.0, true)

	if _selection >= 0 and _selection < EMOTES.size():
		var full := String(EMOTES[_selection].get("name", EMOTES[_selection]["label"]))
		var nf := get_theme_default_font()
		var ns := nf.get_string_size(full, HORIZONTAL_ALIGNMENT_CENTER, -1.0, CENTRE_FONT_SIZE)
		var nat := centre - ns / 2.0 + Vector2(0, ns.y * 0.32)
		draw_string_outline(nf, nat, full, HORIZONTAL_ALIGNMENT_CENTER, -1.0,
			CENTRE_FONT_SIZE, 6, UiTheme.INK)
		draw_string(nf, nat, full, HORIZONTAL_ALIGNMENT_CENTER, -1.0,
			CENTRE_FONT_SIZE, UiTheme.AMBER)

	draw_arc(centre, RADIUS_INNER * 0.30, 0.0, TAU, 32,
		Color(UiTheme.CREAM, 0.30 if _selection < 0 else 0.16), 2.0, true)
	if _stick.length() >= 1.0:
		var knob := centre + _stick.normalized() * (RADIUS_INNER - 16.0)
		draw_circle(knob, 10.0, Color(UiTheme.INK, 0.9))
		draw_circle(knob, 7.0, UiTheme.AMBER)

func _resolve_label(font: Font, label: String, offset: Vector2, mid: float,
		span: float, outer: float) -> Dictionary:
	var one: Array[String] = [label]
	if _label_fits(font, one, LABEL_FONT_SIZE, offset, mid, span, outer):
		return {"lines": one, "font_size": LABEL_FONT_SIZE}
	var candidates: Array = [_label_lines(label), _label_lines(label, true)]
	for lines in candidates:
		if lines.size() > 1 and _label_fits(font, lines, LABEL_FONT_SIZE, offset, mid, span, outer):
			return {"lines": lines, "font_size": LABEL_FONT_SIZE}
	for lines in ([one] as Array) + candidates:
		var font_size := LABEL_FONT_SIZE
		while font_size > LABEL_FONT_MIN and not _label_fits(
				font, lines, font_size, offset, mid, span, outer):
			font_size -= 1
		if _label_fits(font, lines, font_size, offset, mid, span, outer):
			return {"lines": lines, "font_size": font_size}
	return {"lines": one, "font_size": LABEL_FONT_MIN}

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
				bad_detail.append("  %-14s font %d, %d line(s)%s"
					% [label, font_size, lines.size(),
						"" if font_size == LABEL_FONT_SIZE and lines.size() == 1
						else "   <- shrunk/wrapped"])
	return bad

var bad_detail: Array[String] = []

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
	var outer := RADIUS_OUTER + (SELECT_BULGE if chosen else 0.0)
	var points := PackedVector2Array()
	for s in steps + 1:
		var a: float = lerpf(from, to, float(s) / float(steps))
		points.append(centre + Vector2(cos(a), sin(a)) * outer)
	for s in range(steps, -1, -1):
		var a: float = lerpf(from, to, float(s) / float(steps))
		points.append(centre + Vector2(cos(a), sin(a)) * RADIUS_INNER)
	var fill: Color = UiTheme.AMBER if chosen else Color(UiTheme.INK, 0.58)
	draw_colored_polygon(points, fill)
	draw_polyline(points, Color(UiTheme.CREAM, 0.85 if chosen else 0.22),
		3.5 if chosen else 2.0, true)

