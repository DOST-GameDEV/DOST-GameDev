@tool
extends Button
class_name ArrowButton

## The pennant buttons on the main menu and the GAME screen.
##
## The artwork is cut flat on its left edge because it runs off the side of the
## screen — the shape continues past the viewport to an implied flagpole. Every
## animation pivots around that off-screen pole (`pole_distance` to the left of
## this button's own left edge) so the button unfurls and settles like cloth on
## a mast rather than growing from its own centre.
##
## The artwork is the `Artwork` TextureRect child (see ArrowButton.tscn), set to
## `show_behind_parent` so Button still draws its own label on top of it. That
## keeps the text live rather than baked into the export — and because `scale`
## applies to everything this node draws, the text stretches with the pennant
## for free. Its ShaderMaterial is `resource_local_to_scene`, so each instance
## animates its own rim.

const MENU_FONT: Font = preload("res://assets/ui/fonts/DarumadropOne-Regular.ttf")

const HOVER_SCALE: float = 1.04
const HOVER_BRIGHTNESS: float = 1.12
const PRESS_SCALE: float = 0.96

@export var texture: Texture2D: set = _set_texture
## Per-button: the moodboard gives each pennant its own ink colour rather than
## one shared value.
@export var text_color: Color = Color("221a10"): set = _set_text_color
@export var label_size: int = 72: set = _set_label_size
## Distance from this button's left edge out to the off-screen flagpole every
## animation pivots around.
@export var pole_distance: float = 420.0
## Insets the label so it clears the flat left cut and the arrow tip.
@export var text_indent: float = 70.0: set = _set_text_indent
@export var tip_padding: float = 96.0: set = _set_tip_padding

var _artwork: TextureRect
var _material: ShaderMaterial
var _tween: Tween

func _ready() -> void:
	_build()
	_apply_texture()
	_apply_text_color()
	_apply_label_size()
	_apply_padding()
	_update_pivot()
	resized.connect(_update_pivot)
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
	_material = _artwork.material as ShaderMaterial
	add_theme_font_override("font", MENU_FONT)

## The pivot sits out to the left of the button, off the edge of the screen, so
## scaling reads as cloth unfurling from a mast instead of a box zooming in.
func _update_pivot() -> void:
	pivot_offset = Vector2(-pole_distance, size.y * 0.5)

# --- Property plumbing --------------------------------------------------------
# Exported setters fire while the scene loads, before _ready has built the
# internals, so each one guards and _ready re-applies the lot.

func _set_texture(value: Texture2D) -> void:
	texture = value
	_apply_texture()

func _apply_texture() -> void:
	if _artwork != null:
		_artwork.texture = texture

func _set_text_color(value: Color) -> void:
	text_color = value
	_apply_text_color()

func _apply_text_color() -> void:
	if _artwork == null:
		return
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_disabled_color"]:
		add_theme_color_override(state, text_color)

func _set_label_size(value: int) -> void:
	label_size = value
	_apply_label_size()

func _apply_label_size() -> void:
	if _artwork != null:
		add_theme_font_size_override("font_size", label_size)

func _set_text_indent(value: float) -> void:
	text_indent = value
	_apply_padding()

func _set_tip_padding(value: float) -> void:
	tip_padding = value
	_apply_padding()

func _apply_padding() -> void:
	if _artwork == null:
		return
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxEmpty.new()
		box.content_margin_left = text_indent
		box.content_margin_right = tip_padding
		add_theme_stylebox_override(state, box)

# --- Entrance -----------------------------------------------------------------

## Unfurls the pennant from the off-screen pole. `delay` staggers a column of
## buttons so they snap out one after another.
func animate_in(delay: float = 0.0) -> void:
	_update_pivot()
	scale = Vector2(0.0, 0.7)
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.22)

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
