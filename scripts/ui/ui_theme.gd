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
## ⚠️ Display font: the moodboard's heavy hand-drawn unicase marker face is
## Harry's and was not supplied with the brief, so this ships on Godot's default
## font. The palette, chrome and layout logic are all moodboard-accurate; only
## the typeface is standing in. Dropping the real face in is a one-line change
## (`theme.default_font`) plus the licence record for submission Form 03 — see
## the blocker note in docs/Handoff.md item 15.

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

# --- Environment palette (docs/Environment_Kit_Spec.md, checklist 2.1a) --------
#
# WHY THESE EXIST AT ALL. The eight tokens above are a UI palette. Six of them
# are unusable on a street (INK, PANEL and CARD are near-black and near-white;
# DANGER is reserved for downed/out-of-bounds) and two of them are FORBIDDEN on
# environment geometry outright:
#
#   ⛔ OFFENSE (#f87020) and DEFENSE (#0080e8) may NEVER appear on a map.
#
# That is `Dev_Plan.md` §4.2's hard rule read to its conclusion: if a wall can be
# orange, then orange no longer means "this team is attacking". A player has to
# be able to learn one colour pair and read every screen, and the world is the
# largest surface in the frame. So the environment gets its own band of the
# palette and never borrows from the role band.
#
# THE DISCIPLINE THAT KEEPS THEM APART. Every colour below is held under ~70%
# saturation and, where its hue approaches a role hue, under ~75% value. That is
# what stops ENV_RUST reading as OFFENSE at arena distance — it is the same
# family of hue and deliberately two steps down in both saturation and
# brightness. Add nothing here that does not clear that bar, and add nothing in
# the cyan-blue band at all.
#
# These are consumed by `tools/models/generate_all.gd`'s `_build_*` functions as
# `.mtl` diffuse values, exactly as the prop colours already are — never a
# retyped hex, so the world and the UI cannot drift apart.
#
# NOT part of the generated `Theme`. `build()` does not read them and must not:
# `assets/ui/tumbang_preso.tres` is a Control theme, and adding 3D surface
# colours to it would put map paint into every button's inheritance chain.
const ENV_ASPHALT: Color = Color("4a4e57")        ## road surface, gutter channel
const ENV_CONCRETE: Color = Color("b7b2a6")       ## walls, kerbs, plaza slab, bollards
const ENV_CONCRETE_DARK: Color = Color("8c877c")  ## damp-course skirts, shadow bands, wall bases
const ENV_GI_SHEET: Color = Color("9aa3a2")       ## galvanised-iron corrugated sheet
const ENV_RUST: Color = Color("a65a3a")           ## rust streaks, drums, tricycle frame
const ENV_WOOD: Color = Color("a8763f")           ## crates, counters, bench slats, backboards
const ENV_WOOD_DARK: Color = Color("6b4a28")      ## posts, framing, tree trunks
const ENV_FOLIAGE: Color = Color("4f8c3b")        ## canopies, planters — front layer
const ENV_FOLIAGE_DARK: Color = Color("35652a")   ## canopies — the layer behind, for depth
const ENV_DIRT: Color = Color("c2a878")           ## dirt apron, mud, unpaved shoulder
const ENV_TARP: Color = Color("dcd5c4")           ## awning canvas, sacks, hung laundry
const ENV_RUBBER: Color = Color("2b2b30")         ## tires, wheels

## Painted facades. A Philippine street is NOT grey — it is painted concrete in
## whatever the hardware store had, weathered unevenly. `ENV_CONCRETE` alone made
## every building read as an untextured box, which is the single loudest
## "unfinished greybox" signal the set had.
##
## ⚠️ All four are deliberately WARM or DESATURATED-COOL, never a clean mid green
## or blue. Person A wears `#1E9E5A` and Person B `#5C1F2A`, and a facade in the
## same hue family would eat the character silhouette at arena distance. Warm
## walls also push the green Person forward, which is the whole point of putting
## a character in front of a wall. Neither hue goes anywhere near `OFFENSE`
## `#F87020` or `DEFENSE` `#0080E8` — `Dev_Plan.md` §4.2 rule 1.
const ENV_PAINT_CREAM: Color = Color("e2d2ac")    ## the default Manila facade
const ENV_PAINT_TERRA: Color = Color("b5664c")    ## oxide-red / terracotta
const ENV_PAINT_MINT: Color = Color("86b4a6")     ## the pale mint that is everywhere
const ENV_PAINT_OCHRE: Color = Color("c9994a")    ## mustard / ochre
## Ground-floor shopfronts are always darker than the storeys above them —
## roll-up shutters, tiled skirting, or just forty years of splashback.
const ENV_PAINT_PLINTH: Color = Color("6d5f52")

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

	_style_button(theme)
	_style_inputs(theme)
	_style_containers(theme)
	_style_labels(theme)
	_register_variations(theme)
	return theme

## A card/button face: flat fill, rounded, INK border — OR, when `accent` is
## given, a full-height role-colour bar down the left edge.
##
## ⚠️ IT IS ONE OR THE OTHER, NOT BOTH, AND THAT IS A DELIBERATE DEVIATION FROM
## THE MOODBOARD. `Dev_Plan.md` §4.1 specifies "deep-navy 3px border" AND "a 6px
## full-height colour bar at the left of each heading". `StyleBoxFlat` carries a
## single `border_color` for all four sides — Godot has no per-side border
## colour — so the accent branch below necessarily repaints the whole border,
## and an accented card ends up outlined edge-to-edge in its role colour rather
## than in navy.
##
## This comment used to claim the card kept its INK border when accented. It
## never has. Confirmed by rendering the role-swap card: both panels are outlined
## completely in orange and blue, with no navy anywhere.
##
## Left as-is on purpose rather than "fixed". Getting both would mean a child
## ColorRect on every accented Control — exactly what the note below deliberately
## avoided — and the full outline reads *better* at HUD scale than a 6px bar
## would: the top-corner team panels are legible across a room because of it.
## Revisit only if 0.4 reports the role colour being missed.
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
