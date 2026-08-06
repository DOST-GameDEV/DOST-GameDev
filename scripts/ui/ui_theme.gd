extends RefCounted
class_name UiTheme


const DISPLAY_FONT_PATH: String = "res://assets/ui/fonts/DarumadropOne-Regular.ttf"

const BASELINE_OFFSET: float = -0.088

const INK: Color = Color("040838")
const PANEL: Color = Color("e1e5e8")
const CARD: Color = Color("f5f7fa")
const OFFENSE: Color = Color("f87020")
const DEFENSE: Color = Color("0080e8")
const IMPACT: Color = Color("f468a8")
const HIGHLIGHT: Color = Color("f8d028")
const DANGER: Color = Color("f80000")

const INK_MUTED: Color = Color(INK.r, INK.g, INK.b, 0.62)

const ENV_ASPHALT: Color = Color("4a4e57")
const ENV_CONCRETE: Color = Color("b7b2a6")
const ENV_CONCRETE_DARK: Color = Color("8c877c")
const ENV_GI_SHEET: Color = Color("9aa3a2")
const ENV_RUST: Color = Color("a65a3a")
const ENV_WOOD: Color = Color("a8763f")
const ENV_WOOD_DARK: Color = Color("6b4a28")
const ENV_FOLIAGE: Color = Color("4f8c3b")
const ENV_FOLIAGE_DARK: Color = Color("35652a")
const ENV_DIRT: Color = Color("c2a878")
const ENV_TARP: Color = Color("dcd5c4")
const ENV_RUBBER: Color = Color("2b2b30")

const ENV_PAINT_CREAM: Color = Color("e2d2ac")
const ENV_PAINT_TERRA: Color = Color("b5664c")
const ENV_PAINT_MINT: Color = Color("86b4a6")
const ENV_PAINT_OCHRE: Color = Color("c9994a")
const ENV_PAINT_PLINTH: Color = Color("6d5f52")

const PROP_FOAM: Color = Color("7a5741")
const PROP_FOAM_DARK: Color = Color("54382a")
const PROP_WEBBING: Color = Color("c69a6b")
const PROP_SARSI_RED: Color = Color("d8221c")

const WOOD_DEEP: Color = Color("31190b")
const WOOD_MID: Color = Color("5a2f14")
const WOOD_DARK: Color = Color("1d0e06")
const WOOD_EDGE: Color = Color("8b5227")
const CREAM: Color = Color("f5e6c8")
const AMBER: Color = Color("ffba00")

const CREAM_MUTED: Color = Color(CREAM.r, CREAM.g, CREAM.b, 0.68)

const MENU_GREEN: Color = Color("21a131")
const MENU_GREEN_LIT: Color = Color("69e548")
const MENU_RED: Color = Color("ed2136")
const MENU_RED_LIT: Color = Color("fa7653")

const WOOD_BORDER_WIDTH: int = 5
const WOOD_CORNER_RADIUS: int = 12
const WOOD_SHADOW_SIZE: int = 6
const WOOD_SHADOW_OFFSET: Vector2 = Vector2(0, 5)

const BORDER_WIDTH: int = 3
const CORNER_RADIUS: int = 6
const ACCENT_BAR_WIDTH: int = 6
const MARGIN: int = 16

const FONT_SIZE_BODY: int = 16
const FONT_SIZE_CAPTION: int = 13
const FONT_SIZE_BUTTON: int = 18
const FONT_SIZE_HEADING: int = 28
const FONT_SIZE_DISPLAY: int = 56
const FONT_SIZE_TIMER: int = 44

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE_BODY
	theme.default_font = display_font()

	_style_button(theme)
	_style_inputs(theme)
	_style_containers(theme)
	_style_labels(theme)
	_register_variations(theme)
	return theme

static func display_font() -> FontVariation:
	var face := FontVariation.new()
	face.base_font = load(DISPLAY_FONT_PATH)
	face.baseline_offset = BASELINE_OFFSET
	return face

static func card_style(fill: Color, border: Color = INK, accent: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_border_width_all(BORDER_WIDTH)
	sb.border_color = border
	sb.set_corner_radius_all(CORNER_RADIUS)
	sb.content_margin_left = MARGIN
	sb.content_margin_right = MARGIN
	sb.content_margin_top = MARGIN / 2
	sb.content_margin_bottom = MARGIN / 2
	if accent.a > 0.0:
		sb.border_width_left = ACCENT_BAR_WIDTH + BORDER_WIDTH
		sb.border_color = accent
	return sb

static func wood_style(fill: Color, border: Color = WOOD_EDGE, sink: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_border_width_all(WOOD_BORDER_WIDTH)
	sb.border_color = border
	sb.set_corner_radius_all(WOOD_CORNER_RADIUS)
	sb.content_margin_left = MARGIN + 8
	sb.content_margin_right = MARGIN + 8
	sb.content_margin_top = MARGIN - 4
	sb.content_margin_bottom = MARGIN - 4
	if sink:
		sb.content_margin_top += WOOD_SHADOW_OFFSET.y
		sb.content_margin_bottom -= WOOD_SHADOW_OFFSET.y
		return sb
	sb.shadow_color = Color(INK.r, INK.g, INK.b, 0.55)
	sb.shadow_size = WOOD_SHADOW_SIZE
	sb.shadow_offset = WOOD_SHADOW_OFFSET
	return sb

static func _style_button(theme: Theme) -> void:
	theme.set_font_size("font_size", "Button", FONT_SIZE_BUTTON)
	theme.set_stylebox("normal", "Button", card_style(CARD))
	theme.set_stylebox("hover", "Button", card_style(HIGHLIGHT))
	theme.set_stylebox("pressed", "Button", card_style(INK))
	theme.set_stylebox("disabled", "Button", card_style(PANEL, INK_MUTED))

	var focus := card_style(CARD, IMPACT)
	focus.set_border_width_all(BORDER_WIDTH + 1)
	theme.set_stylebox("focus", "Button", focus)

	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", PANEL)
	theme.set_color("font_focus_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", INK_MUTED)

static func _style_inputs(theme: Theme) -> void:
	theme.set_stylebox("normal", "LineEdit", card_style(CARD))
	var le_focus := card_style(CARD, IMPACT)
	le_focus.set_border_width_all(BORDER_WIDTH + 1)
	theme.set_stylebox("focus", "LineEdit", le_focus)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", INK_MUTED)
	theme.set_color("caret_color", "LineEdit", INK)

	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "OptionButton", card_style(CARD))
	theme.set_color("font_color", "OptionButton", INK)
	theme.set_color("font_hover_color", "OptionButton", INK)
	theme.set_color("font_pressed_color", "OptionButton", INK)
	theme.set_color("font_focus_color", "OptionButton", INK)

	theme.set_stylebox("panel", "PopupMenu", card_style(CARD))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_stylebox("hover", "PopupMenu", card_style(HIGHLIGHT))

	theme.set_stylebox("slider", "HSlider", card_style(PANEL))
	theme.set_stylebox("grabber_area", "HSlider", card_style(DEFENSE))
	theme.set_stylebox("grabber_area_highlight", "HSlider", card_style(IMPACT))

	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "CheckBox", card_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	theme.set_color("font_color", "CheckBox", INK)
	theme.set_color("font_hover_color", "CheckBox", INK)
	theme.set_color("font_pressed_color", "CheckBox", INK)

static func _style_containers(theme: Theme) -> void:
	theme.set_stylebox("panel", "Panel", card_style(CARD))
	theme.set_stylebox("panel", "PanelContainer", card_style(CARD))
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 10)

	var clear := StyleBoxEmpty.new()
	theme.set_stylebox("panel", "ScrollContainer", clear)
	theme.set_stylebox("scroll", "VScrollBar", card_style(PANEL, INK_MUTED))
	theme.set_stylebox("grabber", "VScrollBar", card_style(INK, INK))
	theme.set_stylebox("grabber_highlight", "VScrollBar", card_style(IMPACT, INK))
	theme.set_stylebox("grabber_pressed", "VScrollBar", card_style(IMPACT, INK))

static func _style_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", INK)
	theme.set_font_size("font_size", "Label", FONT_SIZE_BODY)

static func _register_variations(theme: Theme) -> void:
	for variation in ["Display", "Heading", "Caption", "TimerDisplay",
			"HudTimer", "HudScore", "HudBody", "HudCaption", "HudBanner", "HudToast"]:
		theme.set_type_variation(variation, "Label")

	theme.set_font_size("font_size", "Display", FONT_SIZE_DISPLAY)
	theme.set_color("font_color", "Display", INK)

	theme.set_font_size("font_size", "Heading", FONT_SIZE_HEADING)
	theme.set_color("font_color", "Heading", INK)

	theme.set_font_size("font_size", "Caption", FONT_SIZE_CAPTION)
	theme.set_color("font_color", "Caption", INK_MUTED)

	theme.set_font_size("font_size", "TimerDisplay", FONT_SIZE_TIMER)
	theme.set_color("font_color", "TimerDisplay", INK)

	const HUD_SIZES := {
		"HudTimer": FONT_SIZE_TIMER,
		"HudScore": 32,
		"HudBody": 34,
		"HudCaption": 32,
		"HudBanner": 40,
		"HudToast": 28,
	}
	for variation in HUD_SIZES:
		theme.set_color("font_color", variation, CARD)
		theme.set_color("font_outline_color", variation, INK)
		theme.set_constant("outline_size", variation, 6)
		theme.set_font_size("font_size", variation, HUD_SIZES[variation])
	theme.set_color("font_color", "HudToast", DANGER)

	for variation in ["PrimaryButton", "DangerButton"]:
		theme.set_type_variation(variation, "Button")

	theme.set_font_size("font_size", "PrimaryButton", FONT_SIZE_BUTTON + 4)
	theme.set_stylebox("normal", "PrimaryButton", card_style(INK))
	theme.set_stylebox("hover", "PrimaryButton", card_style(OFFENSE))
	theme.set_stylebox("pressed", "PrimaryButton", card_style(OFFENSE, INK))
	theme.set_stylebox("focus", "PrimaryButton", card_style(INK, IMPACT))
	theme.set_color("font_color", "PrimaryButton", CARD)
	theme.set_color("font_hover_color", "PrimaryButton", INK)
	theme.set_color("font_pressed_color", "PrimaryButton", INK)
	theme.set_color("font_focus_color", "PrimaryButton", CARD)

	theme.set_stylebox("normal", "DangerButton", card_style(CARD, DANGER))
	theme.set_stylebox("hover", "DangerButton", card_style(DANGER))
	theme.set_color("font_color", "DangerButton", DANGER)
	theme.set_color("font_hover_color", "DangerButton", CARD)

	theme.set_type_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", card_style(CARD))

	theme.set_type_variation("OffenseCard", "PanelContainer")
	theme.set_stylebox("panel", "OffenseCard", card_style(CARD, INK, OFFENSE))

	theme.set_type_variation("DefenseCard", "PanelContainer")
	theme.set_stylebox("panel", "DefenseCard", card_style(CARD, INK, DEFENSE))

	theme.set_type_variation("HudCard", "PanelContainer")
	theme.set_stylebox("panel", "HudCard", card_style(Color(INK.r, INK.g, INK.b, 0.55), Color(0, 0, 0, 0)))

	_register_menu_variations(theme)

static func _register_menu_variations(theme: Theme) -> void:
	for variation in ["MenuDisplay", "MenuHeading", "MenuBody", "MenuCaption", "MenuValue"]:
		theme.set_type_variation(variation, "Label")

	const MENU_SIZES := {
		"MenuDisplay": [52, 6],
		"MenuHeading": [34, 5],
		"MenuBody": [21, 4],
		"MenuCaption": [16, 3],
		"MenuValue": [26, 4],
	}
	for variation in MENU_SIZES:
		theme.set_color("font_color", variation, CREAM)
		theme.set_color("font_outline_color", variation, INK)
		theme.set_font_size("font_size", variation, MENU_SIZES[variation][0])
		theme.set_constant("outline_size", variation, MENU_SIZES[variation][1])
	theme.set_color("font_color", "MenuDisplay", AMBER)
	theme.set_color("font_color", "MenuHeading", AMBER)
	theme.set_color("font_color", "MenuCaption", CREAM_MUTED)

	theme.set_type_variation("WoodPanel", "PanelContainer")
	theme.set_stylebox("panel", "WoodPanel", wood_style(WOOD_DEEP))

	theme.set_type_variation("WoodSlot", "PanelContainer")
	theme.set_stylebox("panel", "WoodSlot", wood_style(WOOD_DARK, WOOD_EDGE, true))

	for variation in ["WoodButton", "WoodPrimaryButton", "WoodDangerButton"]:
		theme.set_type_variation(variation, "Button")

	theme.set_type_variation("MenuCheckBox", "CheckBox")
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "MenuCheckBox", CREAM)
	theme.set_font_size("font_size", "MenuCheckBox", 21)

	_style_wood_button(theme, "WoodButton", WOOD_DEEP, WOOD_MID, WOOD_DARK, CREAM, AMBER)
	_style_wood_button(theme, "WoodPrimaryButton", MENU_GREEN, MENU_GREEN_LIT, WOOD_DARK, INK, INK)
	_style_wood_button(theme, "WoodDangerButton", MENU_RED, MENU_RED_LIT, WOOD_DARK, CREAM, INK)

static func _style_wood_button(theme: Theme, variation: String, fill: Color,
		lit: Color, sunk: Color, ink: Color, lit_ink: Color) -> void:
	theme.set_font_size("font_size", variation, FONT_SIZE_BUTTON + 6)
	theme.set_stylebox("normal", variation, wood_style(fill))
	theme.set_stylebox("hover", variation, wood_style(lit, HIGHLIGHT))
	theme.set_stylebox("pressed", variation, wood_style(sunk, HIGHLIGHT, true))
	theme.set_stylebox("focus", variation, wood_style(lit, IMPACT))
	theme.set_stylebox("disabled", variation, wood_style(WOOD_DARK, WOOD_EDGE))

	theme.set_color("font_color", variation, ink)
	theme.set_color("font_hover_color", variation, lit_ink)
	theme.set_color("font_pressed_color", variation, AMBER)
	theme.set_color("font_focus_color", variation, lit_ink)
	theme.set_color("font_disabled_color", variation, CREAM_MUTED)

