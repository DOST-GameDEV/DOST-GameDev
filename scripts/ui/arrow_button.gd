@tool
extends Button
class_name ArrowButton

## The pennant buttons on the menu screens.
##
## The artwork is cut flat on its left edge because it runs off the side of the
## screen — the shape continues past the viewport to an implied flagpole. The
## entrance unfurls from that pole; hover and press pivot on the button's own
## left edge instead, so a button sitting flush against the screen border never
## opens a gap there.
##
## Two children (see ArrowButton.tscn): `Artwork`, a TextureRect with
## `show_behind_parent` so it sits under everything, and `Caption`, a Label on
## top. Button's own `text` stays empty — the caption is a real Label so it can
## be scaled non-uniformly and tracked out, which the artboard does to SETTINGS
## and which no font size reproduces on Button's built-in text. Because `scale`
## applies to children, the caption still stretches with the pennant.

const HOVER_SCALE: float = 1.04
const HOVER_BRIGHTNESS: float = 1.12
const PRESS_SCALE: float = 0.96

@export var texture: Texture2D: set = _set_texture
@export var caption: String = "": set = _set_caption
## Per-button: the moodboard gives each pennant its own ink colour rather than
## one shared value.
@export var text_color: Color = Color("221a10"): set = _set_text_color
@export var label_size: int = 72: set = _set_label_size
## Non-uniform scale on the caption. The artboard sets SETTINGS at a small size
## stretched tall rather than condensed narrow: its mid-height strokes measure
## 16px against QUIT's 22px, while its top bar measures 29px — a 1.8x ratio that
## only a vertical stretch produces. Cap height and stroke weight are otherwise
## impossible to satisfy at once.
@export var label_stretch_x: float = 1.0: set = _set_label_stretch_x
@export var label_stretch_y: float = 1.0: set = _set_label_stretch_y
## Extra tracking, in pixels per gap. The same stretched caption is spaced out to
## span its pennant; without it the letters crowd together.
@export var label_spacing: int = 0: set = _set_label_spacing
## Distance from this button's left edge out to the off-screen flagpole the
## entrance animation pivots around.
@export var pole_distance: float = 420.0
## Insets the caption so it clears the flat left cut and the arrow tip.
@export var text_indent: float = 70.0: set = _set_text_indent
@export var tip_padding: float = 96.0: set = _set_tip_padding
## Nudges the caption off the rect's vertical centre. The pennants are drawn on
## a slant with uneven bleed above and below, so the artwork's optical centre is
## not the texture's centre — positive moves the caption down.
@export var text_offset_y: float = 0.0: set = _set_text_offset_y

var _artwork: TextureRect
var _caption: Label
var _material: ShaderMaterial
var _tween: Tween

func _ready() -> void:
	_build()
	_apply_texture()
	_apply_caption()
	_apply_text_color()
	_apply_label_size()
	_apply_label_stretch()
	_apply_label_spacing()
	_apply_layout()
	_update_pivot()
	resized.connect(_on_resized)
	if Engine.is_editor_hint():
		return
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	focus_entered.connect(_on_hover_start)
	focus_exited.connect(_on_hover_end)
	button_down.connect(_on_press_start)
	button_up.connect(_on_press_end)

func _build() -> void:
	if _artwork != null:
		return
	_artwork = $Artwork
	_caption = $Caption
	_material = _artwork.material as ShaderMaterial
	# Button would draw its own label underneath the Caption otherwise.
	text = ""

func _on_resized() -> void:
	_update_pivot()
	_apply_layout()

## Resting pivot: wherever the button crosses the left screen edge — its own
## left edge for a button fully on screen, or the x=0 line for a pennant that
## bleeds past it. Scaling about any other point walks that crossing sideways
## and opens a sliver of background at the border on hover.
func _update_pivot() -> void:
	pivot_offset = Vector2(maxf(0.0, -position.x), size.y * 0.5)

# --- Property plumbing --------------------------------------------------------
# Exported setters fire while the scene loads, before _ready has resolved the
# children, so each one guards and _ready re-applies the lot.

func _set_texture(value: Texture2D) -> void:
	texture = value
	_apply_texture()

func _apply_texture() -> void:
	if _artwork != null:
		_artwork.texture = texture

func _set_caption(value: String) -> void:
	caption = value
	_apply_caption()

func _apply_caption() -> void:
	if _caption != null:
		_caption.text = caption

func _set_text_color(value: Color) -> void:
	text_color = value
	_apply_text_color()

func _apply_text_color() -> void:
	if _caption != null:
		_caption.add_theme_color_override("font_color", text_color)

func _set_label_size(value: int) -> void:
	label_size = value
	_apply_label_size()

func _apply_label_size() -> void:
	if _caption != null:
		_caption.add_theme_font_size_override("font_size", label_size)

func _set_label_stretch_x(value: float) -> void:
	label_stretch_x = value
	_apply_label_stretch()
	_apply_layout()

func _set_label_stretch_y(value: float) -> void:
	label_stretch_y = value
	_apply_label_stretch()
	_apply_layout()

## Scaling via the Label's own transform rather than a FontVariation transform:
## that transform reshapes glyph outlines but leaves their advances alone, so a
## word keeps almost all its width.
func _apply_label_stretch() -> void:
	if _caption != null:
		_caption.scale = Vector2(label_stretch_x, label_stretch_y)

func _set_label_spacing(value: int) -> void:
	label_spacing = value
	_apply_label_spacing()
	_apply_layout()

## Clears the override before reading the theme font, so repeated calls wrap the
## base face rather than stacking FontVariations on top of each other.
func _apply_label_spacing() -> void:
	if _caption == null:
		return
	_caption.remove_theme_font_override("font")
	if label_spacing == 0:
		return
	var tracked := FontVariation.new()
	tracked.base_font = _caption.get_theme_font("font")
	tracked.spacing_glyph = label_spacing
	_caption.add_theme_font_override("font", tracked)

func _set_text_indent(value: float) -> void:
	text_indent = value
	_apply_layout()

func _set_tip_padding(value: float) -> void:
	tip_padding = value
	_apply_layout()

func _set_text_offset_y(value: float) -> void:
	text_offset_y = value
	_apply_layout()

func _apply_layout() -> void:
	if _caption == null:
		return
	_caption.offset_left = text_indent
	_caption.offset_right = -tip_padding
	_caption.offset_top = maxf(0.0, text_offset_y * 2.0)
	_caption.offset_bottom = minf(0.0, text_offset_y * 2.0)
	# Scale about the caption's own centre so condensing squeezes inward rather
	# than dragging the word toward one edge.
	_caption.pivot_offset = _caption.size * 0.5

# --- Entrance -----------------------------------------------------------------

## Unfurls the pennant from the off-screen pole. `delay` staggers a column of
## buttons so they snap out one after another.
func animate_in(delay: float = 0.0) -> void:
	pivot_offset = Vector2(-pole_distance, size.y * 0.5)
	scale = Vector2(0.0, 0.7)
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.22)
	# Hand back to the resting pivot once the unfurl lands. Safe to swap only
	# because the tween ends at scale 1, where pivot_offset has no effect.
	tween.finished.connect(_update_pivot, CONNECT_ONE_SHOT)

# --- Hover / press ------------------------------------------------------------

func _on_hover_start() -> void:
	_retween()
	_tween.tween_property(self, "scale", Vector2.ONE * HOVER_SCALE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_material, "shader_parameter/rim_alpha", 1.0, 0.14)
	_tween.tween_property(_material, "shader_parameter/brightness", HOVER_BRIGHTNESS, 0.14)

func _on_hover_end() -> void:
	_retween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_material, "shader_parameter/rim_alpha", 0.0, 0.18)
	_tween.tween_property(_material, "shader_parameter/brightness", 1.0, 0.18)

func _on_press_start() -> void:
	_retween()
	_tween.tween_property(self, "scale", Vector2.ONE * PRESS_SCALE, 0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_press_end() -> void:
	var target: Vector2 = Vector2.ONE * HOVER_SCALE if is_hovered() else Vector2.ONE
	_retween()
	_tween.tween_property(self, "scale", target, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _retween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
