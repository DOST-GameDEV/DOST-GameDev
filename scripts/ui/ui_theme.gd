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

# --- Environment palette (docs/Art_Direction.md, checklist 2.1a) --------
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

# --- Prop palette (docs/Art_Direction.md Part 2) -------------------------------
#
# WHY THESE EXIST. The two hero props wore UI tokens — an `IMPACT` magenta sole,
# a `HIGHLIGHT` yellow strap — because in 2026-07-28's B-81 pass those were the
# only non-role colours to hand. **The human confirmed that magenta was
# placeholder** and supplied asset moodboards for both props, so
# they now get their own band instead of borrowing the UI's.
#
# They are NOT in the `ENV_*` band either, and that distinction is load-bearing:
# `ENV_*` is held under ~70% saturation on purpose so a wall never competes with
# a character. A hero prop is the opposite problem — the tsinelas is the
# most-looked-at object in the game and has to read against asphalt at throwing
# distance. So these are allowed to be more saturated than any `ENV_*` token,
# and forbidden from going anywhere near `OFFENSE` or `DEFENSE` in hue.
#
# ⚠️ `PROP_SARSI_RED` is a brand red, not `DANGER`. `DANGER` (#F80000) means
# downed / out-of-bounds and is a STATE signal; the sail is permanent livery, and
# painting livery in the alarm colour would make a healthy can look hurt. Two
# steps down in value and slightly warm keeps them apart at arena distance.
const PROP_FOAM: Color = Color("7a5741")          ## tsinelas footbed — worn brown foam
const PROP_FOAM_DARK: Color = Color("54382a")     ## tsinelas outsole, the dirty underside
const PROP_WEBBING: Color = Color("c69a6b")       ## tsinelas Y-strap — tan fabric webbing
const PROP_SARSI_RED: Color = Color("d8221c")     ## the lata's sail and ball

# --- Menu chrome palette (the front end's wood-and-pennant look) --------------
#
# WHY THIS BAND EXISTS. The eight UI tokens above describe a LIGHT interface —
# `CARD` fill, `INK` text, `PANEL` background. Every front-end screen in the game
# is the opposite: cream and amber lettering on dark stained wood, with the
# pennant buttons over a photographic backdrop. Those colours were real and
# consistent long before this block; they were just retyped as raw literals into
# the old GAME and LOBBY screens' BackButtons, MAP:/MODE: captions and ready
# rows, plus `MainMenu.tscn`'s tagline — a dozen `theme_override_*` entries that
# the header of this file explicitly exists to abolish. Those two screens were
# replaced by `MatchSetup.tscn` in the 10.5 front-end pass, which opts into the
# variations below instead, so most of that band is gone from the scenes now.
#
# So they are named here and registered as type variations below. Nothing about
# the look changed when they moved; the hexes are the ones already on screen.
# `HIGHLIGHT` (#f8d028) is deliberately reused rather than duplicated — the wood
# buttons' hover border was already exactly that value.
#
# ⚠️ NOT an environment band. These are Control colours only. `ENV_WOOD` /
# `ENV_WOOD_DARK` above are the 3D world's timber and are a different, duller
# pair on purpose — a crate seen at arena distance and a button under the mouse
# have opposite jobs.
const WOOD_DEEP: Color = Color("31190b")    ## panel and button fill
const WOOD_MID: Color = Color("5a2f14")     ## the lit face, on hover
const WOOD_DARK: Color = Color("1d0e06")    ## pressed, and inset display slots
const WOOD_EDGE: Color = Color("8b5227")    ## tan border around every wood face
const CREAM: Color = Color("f5e6c8")        ## body lettering on wood
const AMBER: Color = Color("ffba00")        ## headings, values, hover lettering

## Cream at reduced alpha, for secondary text on wood — same reasoning as
## INK_MUTED, from the other end of the value range.
const CREAM_MUTED: Color = Color(CREAM.r, CREAM.g, CREAM.b, 0.68)

## Sampled from the pennant artwork so a StyleBox-drawn button and a
## texture-drawn one can sit in the same column without disagreeing about what
## "the green one" is. `MENU_GREEN` is PLAY's body, `MENU_RED` is QUIT's.
const MENU_GREEN: Color = Color("21a131")
const MENU_GREEN_LIT: Color = Color("69e548")
const MENU_RED: Color = Color("ed2136")
const MENU_RED_LIT: Color = Color("fa7653")

## Chunkier than `BORDER_WIDTH`: these are cartoon buttons meant to read across a
## room, and a 3px edge disappears at that distance.
const WOOD_BORDER_WIDTH: int = 5
const WOOD_CORNER_RADIUS: int = 12
## The cartoon drop shadow that makes a flat fill read as a physical thing
## sitting above the panel rather than painted onto it.
##
## ⚠️ `shadow_size` MUST STAY > 0. StyleBoxFlat gates the whole shadow pass on
## `shadow_size > 0` and ignores `shadow_offset` entirely when it is zero, so the
## intuitive "size 0, offset 5" spelling of a hard-edged offset slab silently
## draws nothing at all. Keep the size and let the offset do the displacing.
const WOOD_SHADOW_SIZE: int = 6
const WOOD_SHADOW_OFFSET: Vector2 = Vector2(0, 5)

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

## A chunky wood face: thick tan edge, generous radius, and a hard drop shadow
## offset straight down. The front end's counterpart to `card_style`.
##
## `sink` is what a press feels like. Rather than shrinking the button — which
## reflows every sibling in a container and makes a whole menu twitch — the
## shadow is dropped and the content margins are re-weighted so the label rides
## down into the well. Same footprint, so nothing around it moves.
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
	# ⚠️⚠️ THE HUD'S BODY AND CAPTION SIZES ARE ITS OWN NUMBERS, NOT `FONT_SIZE_BODY` AND
	# `FONT_SIZE_CAPTION`. 🧑 2026-08-02, with a screenshot of the YouCard and the
	# LataCard: *"theyre too hard to read so pls adjust text too to make it a bit bigger"*.
	#
	# They used to inherit the menu's 16 and 13. A menu caption is read on a flat wood
	# panel, at rest, with nothing else moving; a HUD caption is read in a corner of a
	# live 3D scene, mid-sprint, over whatever the arena happens to put behind it. Same
	# number, two very different reading conditions — and the HUD one loses. 22 and 19
	# are those two bumped by roughly a third, which is the point where the LataCard's
	# `LATA · UPRIGHT` survives being glanced at rather than read.
	#
	# ⚠️ DELIBERATELY NOT DONE BY RAISING `FONT_SIZE_BODY`. That constant is the whole
	# menu's body text and the settings rows are already tight; this dict is the seam
	# that lets the HUD grow without dragging every screen with it.
	const HUD_SIZES := {
		"HudTimer": FONT_SIZE_TIMER,
		"HudScore": 26,
		"HudBody": 22,
		"HudCaption": 19,
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

	_register_menu_variations(theme)

## The front end's wood set — the pause overlay and the tutorial screen, and any
## screen that draws over a photo backdrop or a live 3D view rather than over
## PANEL. See the WOOD_* palette block for why these are separate from the
## light-interface variations above.
static func _register_menu_variations(theme: Theme) -> void:
	# Labels ------------------------------------------------------------------
	for variation in ["MenuDisplay", "MenuHeading", "MenuBody", "MenuCaption", "MenuValue"]:
		theme.set_type_variation(variation, "Label")

	# Cream body copy, amber for anything that names or numbers something. Both
	# carry an INK outline: a tutorial page sits over the street backdrop and a
	# pause card over the live arena, and unoutlined cream vanishes against a
	# pale facade exactly the way the Hud* set's would.
	## size, outline. The outline is scaled to the face rather than shared, unlike
	## the Hud* set's flat 6: that set is five sizes of the same shout and can get
	## away with it, but this one spans a 52px title and a 16px caption, and 5px
	## of ink around 16px lettering closes up the counters and reads as a blob
	## rather than as an outline.
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

	# Panels ------------------------------------------------------------------
	theme.set_type_variation("WoodPanel", "PanelContainer")
	theme.set_stylebox("panel", "WoodPanel", wood_style(WOOD_DEEP))

	# The inset display slot — the recessed strip the GAME screen shows a map
	# name in. Reads as carved into the panel rather than sitting on it, so it
	# takes the pressed fill and drops the shadow.
	theme.set_type_variation("WoodSlot", "PanelContainer")
	theme.set_stylebox("panel", "WoodSlot", wood_style(WOOD_DARK, WOOD_EDGE, true))

	# Buttons -----------------------------------------------------------------
	for variation in ["WoodButton", "WoodPrimaryButton", "WoodDangerButton"]:
		theme.set_type_variation(variation, "Button")

	# A CheckBox on wood. Only the lettering needs saying — the tick itself is
	# theme-independent and already reads at any background.
	theme.set_type_variation("MenuCheckBox", "CheckBox")
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "MenuCheckBox", CREAM)
	theme.set_font_size("font_size", "MenuCheckBox", 21)

	_style_wood_button(theme, "WoodButton", WOOD_DEEP, WOOD_MID, WOOD_DARK, CREAM, AMBER)
	# The one action a screen wants you to take, in PLAY's green.
	_style_wood_button(theme, "WoodPrimaryButton", MENU_GREEN, MENU_GREEN_LIT, WOOD_DARK, INK, INK)
	# Leaving, in QUIT's red. Not `DANGER` — that hue is reserved for the downed
	# and out-of-bounds STATE signal, and a button is not a state.
	_style_wood_button(theme, "WoodDangerButton", MENU_RED, MENU_RED_LIT, WOOD_DARK, CREAM, INK)

## One wood button's five states, so the three variations above cannot drift
## apart in which state got which treatment.
static func _style_wood_button(theme: Theme, variation: String, fill: Color,
		lit: Color, sunk: Color, ink: Color, lit_ink: Color) -> void:
	theme.set_font_size("font_size", variation, FONT_SIZE_BUTTON + 6)
	theme.set_stylebox("normal", variation, wood_style(fill))
	theme.set_stylebox("hover", variation, wood_style(lit, HIGHLIGHT))
	theme.set_stylebox("pressed", variation, wood_style(sunk, HIGHLIGHT, true))
	theme.set_stylebox("focus", variation, wood_style(lit, IMPACT))
	theme.set_stylebox("disabled", variation, wood_style(WOOD_DARK, WOOD_EDGE, true))

	theme.set_color("font_color", variation, ink)
	theme.set_color("font_hover_color", variation, lit_ink)
	theme.set_color("font_pressed_color", variation, AMBER)
	theme.set_color("font_focus_color", variation, lit_ink)
	theme.set_color("font_disabled_color", variation, CREAM_MUTED)
