extends RefCounted
class_name UiTheme

## Queue item 15 — the moodboard design system, as the single source of truth
## for every colour, radius and border width in the game's UI.
##
## `assets/ui/tumbang_preso.tres` is GENERATED from this file by
## `tools/regenerate_ui_theme.gd` and committed so the Godot editor previews the
## real styling at design time. It is set as the project-wide default via
## `gui/theme/custom` in project.godot, so every Control in the game inherits it
## without per-scene assignment — including screens nobody has written yet.
##
##     After editing anything here, regenerate and commit both files:
##       godot --headless -s tools/regenerate_ui_theme.gd
##
## Do NOT hand-edit the generated .tres, and do NOT reintroduce `theme_override_*` on
## individual nodes — that is what this replaces. Reach for a type variation
## (see `_register_variations`) when a node needs to look different.
##
## Display font: Darumadrop One (SIL Open Font License 1.1, licence text kept
## beside the face at assets/ui/fonts/OFL.txt for submission Form 03). This
## resolves the F-2 placeholder-typeface blocker.

const DISPLAY_FONT_PATH: String = "res://assets/ui/fonts/DarumadropOne-Regular.ttf"

## Darumadrop One is a Japanese face: it reserves a deep descent for kana, so its
## ascent:descent split is roughly 4:1. Godot centres the *line box*, not the
## ink, which leaves an all-caps Latin string sitting about 13% of the font size
## below the optical centre of whatever it is centred in — measured at 40/54/88px
## as -0.125/-0.130/-0.131. Expressed here as a fraction of line height
## (0.130 / 1.475) and applied once via FontVariation, so every Label, Button and
## LineEdit in the project is optically centred instead of each one carrying its
## own nudge. Negative lifts the ink: a positive offset pushes the baseline down,
## which measured as exactly double the original error.
const BASELINE_OFFSET: float = -0.088

# --- Palette (docs/Handoff.md item 15) ----------------------------------------
const INK: Color = Color("040838")        ## near-black navy: text, borders, pressed fills
const PANEL: Color = Color("e1e5e8")      ## light neutral: screen background
const CARD: Color = Color("f5f7fa")       ## slightly lighter: raised card / control fill
const OFFENSE: Color = Color("f87020")    ## orange: attacking side (Slipper/Person on offense)
const DEFENSE: Color = Color("0080e8")    ## blue: defending side (Can side)
const IMPACT: Color = Color("f468a8")     ## pink: hits, focus, emphasis
const HIGHLIGHT: Color = Color("f8d028")  ## yellow: timers under pressure, hover
const DANGER: Color = Color("f80000")     ## red: destructive / out-of-bounds

## Ink at reduced alpha, for secondary text. A flat lighter grey would drift
## off-palette the moment the background colour changes.
const INK_MUTED: Color = Color(INK.r, INK.g, INK.b, 0.62)

# --- Chrome -------------------------------------------------------------------
const BORDER_WIDTH: int = 3
const CORNER_RADIUS: int = 6
const ACCENT_BAR_WIDTH: int = 6 ## full-height role-colour bar down a card's left edge
const MARGIN: int = 16

const FONT_SIZE_BODY: int = 16
const FONT_SIZE_CAPTION: int = 13
const FONT_SIZE_BUTTON: int = 18
const FONT_SIZE_HEADING: int = 28
const FONT_SIZE_DISPLAY: int = 56
const FONT_SIZE_TIMER: int = 44

## Builds the whole theme from the constants above. Pure — no side effects, no
## disk access — so it is equally usable at runtime if a screen ever needs a
## one-off variant.
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

## The display face, baseline-corrected. See BASELINE_OFFSET — without this the
## whole UI's text reads as sitting low in its box.
static func display_font() -> FontVariation:
	var face := FontVariation.new()
	face.base_font = load(DISPLAY_FONT_PATH)
	face.baseline_offset = BASELINE_OFFSET
	return face

## A card/button face: flat fill, INK border, rounded, optionally with a
## full-height accent bar down the left edge (the moodboard's role-colour marker).
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
		# Drawn as an oversized left border rather than a child ColorRect so it
		# survives on any Control that takes a StyleBox, with no extra nodes.
		sb.border_width_left = ACCENT_BAR_WIDTH + BORDER_WIDTH
		sb.border_color = accent
	return sb

static func _style_button(theme: Theme) -> void:
	theme.set_font_size("font_size", "Button", FONT_SIZE_BUTTON)
	theme.set_stylebox("normal", "Button", card_style(CARD))
	theme.set_stylebox("hover", "Button", card_style(HIGHLIGHT))
	theme.set_stylebox("pressed", "Button", card_style(INK))
	theme.set_stylebox("disabled", "Button", card_style(PANEL, INK_MUTED))

	# Focus is its own IMPACT-bordered box rather than an overlay, so keyboard
	# navigation is unmistakable — the default theme's focus ring is invisible
	# against this palette.
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

	# ScrollContainer's own background must not paint a second card face on top
	# of whatever card it already sits inside.
	var clear := StyleBoxEmpty.new()
	theme.set_stylebox("panel", "ScrollContainer", clear)
	theme.set_stylebox("scroll", "VScrollBar", card_style(PANEL, INK_MUTED))
	theme.set_stylebox("grabber", "VScrollBar", card_style(INK, INK))
	theme.set_stylebox("grabber_highlight", "VScrollBar", card_style(IMPACT, INK))
	theme.set_stylebox("grabber_pressed", "VScrollBar", card_style(IMPACT, INK))

static func _style_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", INK)
	theme.set_font_size("font_size", "Label", FONT_SIZE_BODY)

## Named looks a scene can opt into with `theme_type_variation`, instead of the
## per-node `theme_override_*` this design system exists to get rid of.
static func _register_variations(theme: Theme) -> void:
	# Labels ------------------------------------------------------------------
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

	# The HUD draws over a live 3D scene, not over PANEL, so INK text would be
	# unreadable against dark geometry and shadow. The Hud* set inverts to CARD
	# with an INK outline, which survives any background the arena throws at it.
	# One variation per size rather than one variation plus per-node
	# `theme_override_font_sizes` — the override is exactly what this file exists
	# to remove, and it would also drop the outline on whichever nodes used it.
	const HUD_SIZES := {
		"HudTimer": FONT_SIZE_TIMER,
		"HudScore": 24,
		"HudBody": FONT_SIZE_BODY,
		"HudCaption": FONT_SIZE_CAPTION,
		"HudBanner": 40,
		"HudToast": 26,
	}
	for variation in HUD_SIZES:
		theme.set_color("font_color", variation, CARD)
		theme.set_color("font_outline_color", variation, INK)
		theme.set_constant("outline_size", variation, 6)
		theme.set_font_size("font_size", variation, HUD_SIZES[variation])
	# The one exception: an out-of-bounds toast is a warning, so it takes DANGER
	# rather than CARD. The INK outline stays — red on sky is unreadable without it.
	theme.set_color("font_color", "HudToast", DANGER)

	# Buttons -----------------------------------------------------------------
	for variation in ["PrimaryButton", "DangerButton"]:
		theme.set_type_variation(variation, "Button")

	# The one action a screen wants you to take: filled INK, inverted text.
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

	# Cards -------------------------------------------------------------------
	# Role-coloured panels for the HUD's per-team blocks and the role-swap card.
	theme.set_type_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", card_style(CARD))

	theme.set_type_variation("OffenseCard", "PanelContainer")
	theme.set_stylebox("panel", "OffenseCard", card_style(CARD, INK, OFFENSE))

	theme.set_type_variation("DefenseCard", "PanelContainer")
	theme.set_stylebox("panel", "DefenseCard", card_style(CARD, INK, DEFENSE))

	# Translucent INK slab for HUD blocks that sit over the 3D scene.
	theme.set_type_variation("HudCard", "PanelContainer")
	theme.set_stylebox("panel", "HudCard", card_style(Color(INK.r, INK.g, INK.b, 0.55), Color(0, 0, 0, 0)))
