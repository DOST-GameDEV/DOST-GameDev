extends Control
class_name Hud

## HUD per GDD Section 6: current round, Bo5 tracker, timer, who's Attack vs Defense.
## Reads the RoundManager/MatchManager autoloads directly — no per-scene wiring needed,
## drop this scene into Main.tscn (or a match scene) and it just works.

@onready var timer_label: Label = %TimerLabel
@onready var timer_card: PanelContainer = %TimerCard
@onready var round_label: Label = %RoundLabel
@onready var top_left_panel: PanelContainer = %TopLeft
@onready var top_right_panel: PanelContainer = %TopRight
@onready var team_a_label: Label = %TeamALabel
@onready var team_b_label: Label = %TeamBLabel
## The A/B glyphs. Team identity is the LETTER and never the hue, so these are the only
## thing on a team card that does not move when the roles swap — see `_apply_wood_skin`.
@onready var team_a_letter: Label = %TeamALetter
@onready var team_b_letter: Label = %TeamBLetter
@onready var team_a_pips_box: HBoxContainer = %TeamAPipsBox
@onready var team_b_pips_box: HBoxContainer = %TeamBPipsBox
@onready var lata_card: PanelContainer = %LataCard
@onready var lata_label: Label = %LataLabel
@onready var dent_pips_box: HBoxContainer = %DentPipsBox
@onready var dent_text_label: Label = %DentTextLabel
@onready var downed_flash: ColorRect = %DownedFlash
@onready var toast_label: Label = %ToastLabel
@onready var ready_prompt: Label = %ReadyPrompt
@onready var ready_objective: Label = %ReadyObjective
## The centring row the objective sits in. Visibility is toggled here rather than on the
## Label so the row keeps one job — position — and the Label keeps one job: the words.
@onready var ready_objective_row: CenterContainer = %ReadyObjectiveRow
@onready var countdown_label: Label = %CountdownLabel
@onready var you_card: YouCard = %YouCard
@onready var crosshair: Control = %Crosshair
@onready var crosshair_label: Label = %CrosshairLabel
@onready var offscreen_indicators: OffscreenIndicators = %OffscreenIndicators

var _toast_time_left: float = 0.0
var _pulse_tween: Tween = null
var _countdown_tween: Tween = null

func _ready() -> void:
	MatchManager.round_started.connect(_on_round_started)
	MatchManager.match_won.connect(_on_match_won)
	# 4.1 — round result. See _on_round_intermission_audio for why this signal
	# rather than RoundManager.round_won.
	MatchManager.round_intermission_started.connect(_on_round_intermission_audio)
	downed_flash.visible = false
	toast_label.visible = false
	lata_card.visible = false
	# Keep pivot at the TimerCard's centre so the pulse tween scales from the middle.
	# Connect to resized so this stays correct if the card ever changes size.
	timer_card.resized.connect(func(): timer_card.pivot_offset = timer_card.size / 2)
	# BEFORE set_round_display, which paints the role colours on top of this skin.
	_apply_wood_skin()
	# Initialise panels from current MatchManager state so pips and colours are
	# correct on load (e.g. a late-joining peer, or a match already in progress).
	set_round_display(MatchManager.round_number, MatchManager.team_a_is_can)
	# Build stamp in-match too — outlined HudCaption reads over the 3D scene.
	GameVersion.attach_to(self, true)

# --- The wood skin ------------------------------------------------------------
#
# Reported from play, 2026-07-30: the mid-game HUD "kinda doesnt look like our theme
# (menu and lobby), it looks ugly and plain and confusing".
#
# All three complaints were fair and they are three different problems:
#
#  OFF-THEME. The front end is wood and amber — `WOOD_DEEP` panels, `WOOD_EDGE` borders,
#    a 12px radius and a hard drop shadow, cream lettering, amber values. The HUD was
#    near-white `card_style` cards with a navy translucent timer: a different design
#    language on the same screen, and the one the player spends the match looking at.
#  PLAIN. Flat fills, no shadow, one text weight, no hierarchy.
#  CONFUSING. Two specific things, both fixed here. An unwon round pip was drawn
#    fully TRANSPARENT, so the scoreboard's own empty state was invisible and the card
#    read as having no score display at all — the same class of bug as B-?? "the boxes
#    remain empty", which fixed the FILL and left the empty state unreadable. And team
#    identity was a single character buried mid-string in "A · OFFENSE" at body size,
#    which left hue doing the work the letter is supposed to do.
#
# ⚠️ BUILT FROM `UiTheme.wood_style()`, the same static call the menu's own `WoodSlot`
# variation uses. Nothing here invents a colour or a radius, so the HUD cannot drift
# away from the front end again.
#
# ⚠️ AND IT IS CODE RATHER THAN A THEME VARIATION ONLY BECAUSE IT HAS TO BE. The Hud*
# variations live in `ui_theme.gd`, which is ART's file and not writable by this lane.
# Filed for ART to promote these into variations; until then the overrides are here so
# the tokens stay in one place even if the application does not.

## INK outline on the free-floating lines — the objective, the ready prompt and the toast.
## Heavy, because it has to carry role-orange text over a role-orange viewmodel arm.
const TEXT_OUTLINE: int = 8
## The crosshair sits at dead centre of the busiest part of an FPP frame, so its outline
## is heavier still relative to its size.
const CROSSHAIR_OUTLINE: int = 5

## Trimmed from the menu's own wood face. `wood_style()`'s margins are sized for a menu
## button (24px sides) and a HUD card that hugs a glyph and a word cannot afford them.
func _hud_wood_style(fill: Color, border: Color, sink: bool = false) -> StyleBoxFlat:
	var sb := UiTheme.wood_style(fill, border, sink)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb

func _apply_wood_skin() -> void:
	# The timer is the single most-read element on the screen, so it gets the menu's
	# RECESSED slot — the same face the map/mode readouts use on the setup screen, which
	# is the front end's existing idiom for "a value being displayed to you".
	timer_card.add_theme_stylebox_override("panel",
		_hud_wood_style(UiTheme.WOOD_DARK, UiTheme.WOOD_EDGE, true))
	timer_label.add_theme_color_override("font_color", UiTheme.AMBER)
	round_label.add_theme_color_override("font_color", UiTheme.CREAM_MUTED)

	# The letter marks: amber, and deliberately NOT role-coloured. This is the one thing
	# on the card that identifies the team, and it has to stay put when the roles swap.
	for letter in [team_a_letter, team_b_letter]:
		letter.add_theme_color_override("font_color", UiTheme.AMBER)

	lata_card.add_theme_stylebox_override("panel",
		_hud_wood_style(UiTheme.WOOD_DEEP, UiTheme.WOOD_EDGE))
	lata_label.add_theme_color_override("font_color", UiTheme.AMBER)
	dent_text_label.add_theme_color_override("font_color", UiTheme.CREAM)

	# ⚠️ THE THREE FLOATING LINES ARE STYLIZED TEXT, NOT PANELS, AND THAT IS THE SECOND
	# ANSWER. They started as bare text — the ready prompt in DANGER red, illegible over
	# the orange viewmodel arms. The first fix gave all three a wood plate, and the plates
	# were rejected on sight: *"it kinda looks ugly with that hud/ui, can u js do text
	# there but stylized, right color and font"*. Correct call — two stacked boxes at the
	# bottom of the frame fought the 3D instead of sitting on it, and the HUD already has
	# enough rectangles.
	#
	# So legibility comes from a heavy INK outline instead of a box: the same trick
	# `offscreen_indicators.gd` uses on the screen-edge arrows, for the same reason. An
	# outlined glyph survives sky, asphalt and a lit orange arm without adding a shape.
	# Colours are the theme's own — CREAM for instruction, AMBER for an alert.
	for label in [ready_prompt, toast_label, ready_objective]:
		label.add_theme_constant_override("outline_size", TEXT_OUTLINE)
		label.add_theme_color_override("font_outline_color", UiTheme.INK)
	ready_prompt.add_theme_color_override("font_color", UiTheme.CREAM)
	toast_label.add_theme_color_override("font_color", UiTheme.AMBER)

## One team card. Wood body, ROLE-coloured border — the role has to be readable across a
## room, and a thick coloured edge on a dark panel carries further than tinted text does.
func _style_team_card(panel: PanelContainer, label: Label, role_colour: Color) -> void:
	panel.add_theme_stylebox_override("panel",
		_hud_wood_style(UiTheme.WOOD_DEEP, role_colour))
	label.add_theme_color_override("font_color", role_colour)

## R-28 — the two in-world markers that answer "what am I doing" take the LOCAL player's
## role colour: the crosshair they aim with, and the edge arrow pointing at the lata.
##
## ⚠️ DRIVEN OFF THE LOCAL UNIT, NOT OFF TEAM A. `set_round_display()` knows which TEAM
## defends; only the local character knows which side the person holding this keyboard is
## on. Called from both of the existing "the role may just have changed" hooks —
## `set_round_display` (round swap) and `refresh_you_card` (late joiner, B-29) — rather
## than from `_process`, so it is a handful of calls per match instead of 60 a second.
##
## The crosshair also takes an INK outline. It is a thin `+` at dead centre of an FPP
## camera, which is the busiest part of the frame; role colour alone would lose it against
## a wall in the same hue.
func _refresh_role_accents() -> void:
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		return
	var role_colour: Color = UiTheme.DEFENSE if local_char.team_is_can_side else UiTheme.OFFENSE
	crosshair_label.add_theme_color_override("font_color", role_colour)
	crosshair_label.add_theme_constant_override("outline_size", CROSSHAIR_OUTLINE)
	crosshair_label.add_theme_color_override("font_outline_color", UiTheme.INK)
	offscreen_indicators.set_can_arrow_colour(role_colour)

func _process(delta: float) -> void:
	var t := int(ceil(RoundManager.time_left))
	timer_label.text = "%02d:%02d" % [t / 60, t % 60]

	# Timer urgency (§4.4): HIGHLIGHT colour under 15s, scale pulse under 10s.
	# Scale tween instead of colour flash to avoid collision with the downed vignette.
	if RoundManager.time_left < 15.0:
		timer_label.add_theme_color_override("font_color", UiTheme.HIGHLIGHT)
		if RoundManager.time_left < 10.0:
			if _pulse_tween == null or not _pulse_tween.is_running():
				timer_card.pivot_offset = timer_card.size / 2
				_pulse_tween = create_tween().set_loops()
				_pulse_tween.tween_property(timer_card, "scale", Vector2(1.05, 1.05), 0.5)
				_pulse_tween.tween_property(timer_card, "scale", Vector2(1.0, 1.0), 0.5)
		else:
			_kill_pulse_tween()
	else:
		# ⚠️ SET BACK TO AMBER, NOT `remove_theme_color_override`. Removing it would fall
		# through to the HudTimer variation's near-white, which is the pre-wood colour —
		# so the timer would go white the moment it climbed back over 15s.
		timer_label.add_theme_color_override("font_color", UiTheme.AMBER)
		_kill_pulse_tween()

	# Polled each frame, but `_fill_pips` early-outs unless the value actually
	# changed — see its own doc. Polling is kept rather than signal-driven
	# because MatchManager mutates wins from several paths and a missed signal
	# is a silently stale scoreboard.
	_fill_pips(team_a_pips_box, MatchManager.team_a_wins, _pip_color(true))
	_fill_pips(team_b_pips_box, MatchManager.team_b_wins, _pip_color(false))

	if _toast_time_left > 0.0:
		_toast_time_left -= delta
		if _toast_time_left <= 0.0:
			toast_label.visible = false
	# §4.4 crosshair: visible in FPP (Person) only. Reads the you_card's cached
	# character so the scan logic stays in one place (you_card.gd::_find_local_character).
	var local_char := you_card.get_local_character()
	# A spectator has no character, and the three lines below all describe one. Guarded
	# here rather than by hiding the nodes once, because `_process` re-asserts
	# `crosshair.visible` every frame and would put it straight back.
	if _spectating:
		# ⚠️ NOT `_refresh_status_stack(null)` ANY MORE, and the difference is ownership.
		# That function is the PLAYER's stack — `build ux` §4.1/§4.9 own it — and with a
		# null character all it could contribute was the one LATA OUT row it appends from
		# RoundManager. `_refresh_spectator_panel` below draws that same clock plus the
		# stack count a spectator needs and a player does not, so calling both would print
		# the countdown twice with two different amounts of context. See §2.7.
		_refresh_spectator_panel()
		return
	crosshair.visible = local_char != null and is_instance_valid(local_char) and local_char.is_person
	# 3.4: same cached character, no second scan.
	offscreen_indicators.update(local_char)
	_refresh_status_stack(local_char)

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE STATUS STACK — every stun and every status effect, with a number on it.
##
## Human instruction, 2026-07-30: *"add visible UI timers for all stun durations and
## status effects so players clearly know when they can move or act again."*
##
## This is most of what "the defender feels overpowered" actually was. A stun you cannot
## time is a stun you cannot play around: a player who has just been knocked over has no
## way to know whether to hold movement, whether their dash is back, or whether the
## slipper in their hands can be thrown yet — so every one of those reads as the game
## taking control away rather than as a cost with a known price.
##
## ⚠️ IT ASKS THE CHARACTER FOR A LIST, IT DOES NOT KNOW WHAT A STUN IS.
## `CharacterBase.status_effects()` returns whatever is currently live, most urgent
## first, and this draws it. That indirection is the point: a status the gameplay code
## gains later appears on screen with no edit here, and the "all" in the instruction
## stays true without anybody having to remember. See that function's own note.
##
## ⚠️ BUILT IN CODE, NOT IN `HUD.tscn`. The scene is a shared-lock file and the rows are
## a variable-length list — a fixed set of nodes in the scene would have to be hidden and
## re-labelled, which is more state than building three labels on demand.
const STATUS_ROW_LIMIT: int = 4
const STATUS_BAR_SIZE: Vector2 = Vector2(148, 6)

var _status_root: VBoxContainer = null
var _status_rows: Array[Control] = []

func _ensure_status_root() -> VBoxContainer:
	if _status_root != null and is_instance_valid(_status_root):
		return _status_root
	_status_root = VBoxContainer.new()
	_status_root.name = "StatusStack"
	_status_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_root.add_theme_constant_override("separation", 4)
	# Directly under the timer card, top-centre: the one place on the screen a player
	# already looks at under pressure. Anchored rather than parented to the timer so a
	# growing stack cannot push the timer around.
	_status_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status_root.position = Vector2(-STATUS_BAR_SIZE.x * 0.5, 96)
	_status_root.custom_minimum_size = Vector2(STATUS_BAR_SIZE.x, 0)
	add_child(_status_root)
	return _status_root

func _build_status_row() -> Control:
	var row := VBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	# The same heavy INK outline the objective and the ready prompt use — this text sits
	# over a live 3D scene and has to survive being drawn over a road, a wall or a
	# role-orange viewmodel arm.
	label.add_theme_color_override("font_outline_color", UiTheme.INK)
	label.add_theme_constant_override("outline_size", TEXT_OUTLINE)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.show_percentage = false
	bar.custom_minimum_size = STATUS_BAR_SIZE
	bar.max_value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	return row

## ⚠️ THE COLOUR IS THE MESSAGE. Three bands, and they mean three different things to
## somebody glancing at them mid-fight:
##   DANGER    you cannot act at all — STUNNED, DOWNED
##   HIGHLIGHT you can act but something is spent or restricted
##   OFFENSE   a countdown that is costing YOUR SIDE the round (the lata off its circle)
func _status_colour(label: String) -> Color:
	match label:
		"STUNNED", "DOWNED", "OUT":
			return UiTheme.DANGER
		"LATA OUT":
			return UiTheme.OFFENSE
		_:
			return UiTheme.HIGHLIGHT

func _refresh_status_stack(local_char: CharacterBase) -> void:
	var root := _ensure_status_root()
	var effects: Array[Dictionary] = []
	if local_char != null and is_instance_valid(local_char):
		effects = local_char.status_effects()
	# ⚠️ THE LATA COUNTDOWN IS APPENDED HERE, NOT IN `status_effects()`, AND THAT IS A
	# REAL DISTINCTION. Everything the character returns is a fact about YOUR OWN BODY;
	# this is a fact about the ROUND, it is the same number for all four players, and it
	# lives on `RoundManager`. Asking a character about it would have four units each
	# reporting the state of an object none of them is.
	var out_left := RoundManager.can_out_left()
	if out_left >= 0.0 and RoundManager.round_active:
		effects.append({"label": "LATA OUT", "seconds": out_left,
			"total": RoundManager.can_out_limit()})
	var wanted: int = mini(effects.size(), STATUS_ROW_LIMIT)
	while _status_rows.size() < wanted:
		var row := _build_status_row()
		root.add_child(row)
		_status_rows.append(row)
	for i in _status_rows.size():
		var row: Control = _status_rows[i]
		if i >= wanted:
			row.visible = false
			continue
		var effect: Dictionary = effects[i]
		var seconds: float = float(effect.get("seconds", 0.0))
		var total: float = maxf(0.01, float(effect.get("total", 1.0)))
		var text: String = String(effect.get("label", ""))
		var colour := _status_colour(text)
		row.visible = true
		var label := row.get_node("Label") as Label
		label.text = "%s  %.1fs" % [text, maxf(0.0, seconds)]
		label.add_theme_color_override("font_color", colour)
		var bar := row.get_node("Bar") as ProgressBar
		bar.value = clampf(seconds / total, 0.0, 1.0)
		bar.add_theme_stylebox_override("fill", _status_fill(colour))
		bar.add_theme_stylebox_override("background", _status_fill(UiTheme.INK, 0.55))

func _status_fill(colour: Color, alpha: float = 1.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(colour.r, colour.g, colour.b, alpha)
	sb.set_corner_radius_all(3)
	return sb

## ---------------------------------------------------------------------------
## SPECTATOR HUD. `Design.md` §9.
##
## ⚠️ IT STRIPS RATHER THAN REPLACES. Every gameplay element on this HUD describes a
## character — the YOU card, the crosshair, the lata card, the off-screen indicators —
## and a spectator has none. `you_card.get_local_character()` would return null and most
## of them would simply draw nothing, which reads as a broken HUD rather than as a
## deliberate one. The timer and the scoreboard stay, because those are facts about the
## MATCH and are exactly what somebody watching wants.
##
## Called once, from `main.gd::_enter_spectator_mode`. There is no leaving it: a
## spectator spectates for the session.
##
## ⚠️ TAKES THE CAMERA, so `_refresh_spectator_panel` can ask it what it is doing. The
## dependency is one-way and stays that way: the HUD reads `status_text()` off the
## camera, the camera has never heard of the HUD, which is the same rule that keeps
## `controls_text()` a static on the camera and the Label a node over here.
func enter_spectator_mode(camera: SpectatorCamera) -> void:
	you_card.visible = false
	crosshair.visible = false
	lata_card.visible = false
	downed_flash.visible = false
	ready_prompt.visible = false
	ready_objective_row.visible = false
	offscreen_indicators.visible = false
	_spectating = true
	_spectator_camera = camera
	var legend := Label.new()
	legend.name = "SpectatorLegend"
	legend.text = SpectatorCamera.controls_text()
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_font_size_override("font_size", 15)
	legend.add_theme_color_override("font_color", UiTheme.CREAM_MUTED)
	legend.add_theme_color_override("font_outline_color", UiTheme.INK)
	legend.add_theme_constant_override("outline_size", TEXT_OUTLINE)
	legend.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	legend.offset_top = -46
	legend.offset_bottom = -18
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(legend)
	_spectator_status = _build_spectator_label(-70, -46, 15, UiTheme.CREAM_MUTED)
	_spectator_round = _build_spectator_label(-104, -70, 21, UiTheme.AMBER)
	# The clean feed is only discoverable if it is written down where the operator is
	# already reading. Appended here rather than inside `SpectatorCamera.controls_text()`
	# because that static describes the CAMERA's keys and this one is the HUD's.
	# ⚠️ ASKED, NOT HARDCODED. `clean_feed` is rebindable in Settings, so a literal "H"
	# here would start lying the moment anybody changed it — and this legend is the only
	# place the control is advertised on screen.
	legend.text += "   ·   %s clean feed" % SettingsManager.get_binding_display_name("clean_feed")
	set_process_input(true)

var _spectating: bool = false
var _spectator_camera: SpectatorCamera = null
var _spectator_status: Label = null
var _spectator_round: Label = null

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE CLEAN FEED — `H`. 🧑 2026-07-31: *"allow option to remove everything in
## screen to js do record the game bcz we only added spectator for the video record"*,
## and then, explicitly: *"the remove hud is only for spectator okay, no one else."*
##
## SPECTATOR ONLY, AND THAT IS ENFORCED RATHER THAN DOCUMENTED. `_unhandled_input`
## returns immediately unless `_spectating`, so a player in a live match cannot hide
## their own timer, status stack or charge meters by leaning on a key — which would be
## a competitive advantage handed out by a typo.
##
## ⚠️ IT HIDES THE CHILDREN, NOT `self`, AND THAT IS DELIBERATE. Hiding the HUD root
## would be the obvious one line, and it risks a one-way trip: input delivery to a
## hidden Control is not something to bet an operator's recording session on. The root
## stays visible and empty, so the key that turned the overlay off is guaranteed to
## still be listening when they press it again.
##
## ⚠️ AND IT RESTORES WHAT WAS THERE, NOT EVERYTHING. `enter_spectator_mode()` has
## already hidden the YOU card, the crosshair, the lata card and the ready prompt —
## blanket-showing every child on the way back would resurrect exactly the gameplay
## chrome a spectator must not have. Prior visibility is recorded on the way out.
## ⚠️ AN ACTION, NOT A KEYCODE — and the first version of this was the keycode.
## It shipped comparing `event.keycode` against a hardcoded `KEY_H`, which meant the one
## control the camera operator needs was not in the InputMap, not in the settings panel,
## not rebindable, and invisible to `SettingsManager`'s conflict check — the same class
## of thing the REACHABILITY RULE calls "not an entry point". It is `clean_feed` now,
## default H, and it sits in `REBINDABLE_ACTIONS` beside every other control.
##
## ⚠️ `keycode` -> `physical_keycode` came free with that. The raw check used `keycode`,
## which is the LAYOUT symbol: on AZERTY or QWERTZ the key that produces "H" is not in
## the same place, and `SettingsManager` stores `physical_keycode` everywhere else.
## `is_action_pressed()` goes through the InputMap and inherits that.
var _clean_feed: bool = false
var _clean_feed_restore: Dictionary = {}

## ⚠️⚠️ `_input`, NOT `_unhandled_input`, AND THE REASON IS MEASURED — BY ANOTHER LANE.
## `spectator_camera.gd` moved `Tab`/`F`/`V` to `_input` after `spec_probe --solo` caught
## Tab never arriving at all: the Viewport consumes input during the GUI phase, which runs
## BEFORE `_unhandled_input`, and **this HUD is exactly the "live CanvasLayer of Controls"
## that note blames**. `H` is not a focus-navigation key so it would *probably* have
## survived `_unhandled_input` — but "probably" is not what you want under the one control
## a camera operator reaches for mid-take, and the failure mode is silent.
##
## ⚠️ NARROW ON PURPOSE, same discipline as that file: the `_spectating` gate is tested
## first and the event is consumed ONLY when the action actually matches, so nothing else
## on screen — the pause toggle above all — ever loses an event to this.
func _input(event: InputEvent) -> void:
	if not _spectating:
		return
	# `allow_echo` defaults false, which is the guard the first version spelled out by
	# hand. Modifiers are deliberately not matched exactly — an operator with a finger
	# already on Shift should still get their clean plate.
	if not event.is_action_pressed("clean_feed"):
		return
	get_viewport().set_input_as_handled()
	set_clean_feed(not _clean_feed)

## Public so `spec_probe` can drive it without synthesising a key event.
func set_clean_feed(on: bool) -> void:
	if on == _clean_feed:
		return
	_clean_feed = on
	_apply_clean_feed_to_world(on)
	if on:
		_clean_feed_restore.clear()
		for child in get_children():
			var item := child as CanvasItem
			if item == null:
				continue
			_clean_feed_restore[item] = item.visible
			item.visible = false
		return
	for child in get_children():
		var item := child as CanvasItem
		if item == null:
			continue
		# A node added while the feed was clean was never recorded, so it takes the
		# honest default rather than staying invisible forever.
		item.visible = bool(_clean_feed_restore.get(item, true))
	_clean_feed_restore.clear()

## ⚠️⚠️ THE NAMEPLATES AND THE GROUND RINGS ARE NOT PART OF THIS HUD, AND A CLEAN FEED
## THAT LEAVES THEM ON IS NOT CLEAN. 🧑 2026-07-31, with a screenshot: *"turn off
## character labels as well as circles around player when click H, we want H turn off hud
## to make it cinematic so turn off that stuff."*
##
## They are `Node3D`s parented to each unit (`CharacterBase.tscn` → `Nameplate`, holding
## `NameplateRing` + `NameplateLabel`), so they live in the WORLD, not in this
## `CanvasLayer` — which is exactly why the first version of the toggle missed them: it
## walked this node's own children and they were never among them.
##
## ⚠️ ONE NODE HIDES BOTH, deliberately. The ring and the tag are siblings under
## `Nameplate`, so hiding the parent takes the label AND the coloured circle in one move
## and cannot leave the two disagreeing. `character_nameplate.gd` is not touched — this
## is a `visible` sweep from the outside, the same contract the rest of the clean feed
## keeps.
##
## ⚠️ RE-SWEPT ON EVERY TOGGLE rather than remembered, because the roster changes: a unit
## that respawns, or a Prop rebuilt by a role swap, gets a fresh `Nameplate` this has
## never seen. Asking the tree each time is cheap (four units) and cannot go stale.
func _apply_clean_feed_to_world(hidden: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for node in scene.find_children("*", "CharacterBase", true, false):
		var nameplate := (node as Node).get_node_or_null("Nameplate") as Node3D
		if nameplate != null:
			nameplate.visible = not hidden

func is_clean_feed() -> bool:
	return _clean_feed

## ---------------------------------------------------------------------------
## ⚠️⚠️ §2.7 — THE ROUND'S DRAMA IS A CLOCK AND A SPECTATOR HAS NO CHARACTER TO READ IT
## OFF. Filed by `build mech` 2026-07-31, and it is the reason this lane was pulled
## forward: since §1.9 and §5.2 a round is won by the lata being off its circle when the
## countdown expires, so the two numbers that explain everything happening on screen are
## `RoundManager.can_out_left()` and `can_out_stacks()`. Both are public, both are
## mirrored to every peer at 4 Hz, and neither needs a local character — which is exactly
## why a spectator can show them and why "the HUD is sane with no character" (§2.5) is
## the floor rather than the ask. Footage of a lata lying in the street with no clock on
## screen does not read as a round being lost; it reads as nothing happening.
##
## ⚠️ THE STACK COUNT IS HERE FOR THE SAME REASON THE CLOCK IS. "3.2 s left" is a number;
## "3.2 s left, and this is the fourth save, so the next one only buys 1.25" is the
## escalation the whole round is designed around. A viewer who cannot see the stack
## cannot tell a routine knockdown from the one that ends the match.
##
## ⚠️ WHAT THIS DELIBERATELY DOES NOT DO: draw a countdown for the PLAYERS. `build ux`
## §4.9 owns that and must not be pre-empted — this Label is created only inside
## `enter_spectator_mode` and only a peer with no character ever sees it.
func _build_spectator_label(top: float, bottom: float, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", UiTheme.INK)
	label.add_theme_constant_override("outline_size", TEXT_OUTLINE)
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = top
	label.offset_bottom = bottom
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _refresh_spectator_panel() -> void:
	if _spectator_status != null and is_instance_valid(_spectator_status):
		_spectator_status.text = ("" if _spectator_camera == null
			or not is_instance_valid(_spectator_camera) else _spectator_camera.status_text())
	if _spectator_round == null or not is_instance_valid(_spectator_round):
		return
	var out_left := RoundManager.can_out_left()
	var stacks: int = RoundManager.can_out_stacks()
	# ⚠️ THE STACK LINE SURVIVES THE CLOCK ENDING, deliberately. It is a fact about the
	# ROUND SO FAR, not about the current knockdown, and blanking it the moment the lata
	# gets home would hide the escalation precisely between the saves — which is the only
	# time anyone has a second to read it.
	var saves := "SAVES  %d / %d" % [stacks, RoundManager.CAN_OUT_RECOVERY_MAX]
	if out_left >= 0.0 and RoundManager.round_active:
		_spectator_round.add_theme_color_override("font_color", UiTheme.OFFENSE)
		_spectator_round.text = "LATA OUT  %.1f / %.2f s      %s" % [
			maxf(0.0, out_left), RoundManager.can_out_limit(), saves]
		return
	_spectator_round.add_theme_color_override("font_color", UiTheme.AMBER)
	# ⚠️ NEVER BLANK. `spec_probe --solo` caught this reading '' for the whole pre-round
	# window — and that window is exactly when a spectator is deciding where to fly to.
	# An empty strip reads as a HUD that has not loaded.
	_spectator_round.text = ("%s      NEXT LIMIT  %.2f s" % [saves, RoundManager.can_out_limit()]
		if RoundManager.round_active else "WAITING FOR THE ROUND TO START")

## Kills the pulse tween and resets the timer card to its natural scale.
func _kill_pulse_tween() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
		timer_card.scale = Vector2.ONE

## Paints the first `filled` pips in a HBoxContainer of Panel nodes with the
## team's ROLE colour, and the rest transparent. 14x14 square StyleBoxFlat with
## a 3px INK border.
##
## ⚠️⚠️ THE FILL IS THE ROLE COLOUR, NOT `UiTheme.CARD`. THIS WAS THE BUG.
##
## Reported 2026-07-29: "the UI for A-DEFENSE and B-DEFENSE has small indicator
## boxes that are currently broken. They remain empty and do not update with a
## colour/fill to show how many points a team has won."
##
## They were never empty — they were filling with `UiTheme.CARD` (#f5f7fa), a
## near-white, ON TOP OF a near-white team card. A won round painted a white
## square onto a white panel behind a 3px navy border, which is visually
## indistinguishable from the empty state. The logic was right and the contrast
## was zero.
##
## `match_result.gd::_fill_pips` already had this right — it passes DEFENSE or
## OFFENSE per team — so this is now consistent with the end-of-match screen as
## well as with the card's own accent bar and label.
##
## ⚠️ AND IT NO LONGER REBUILDS EVERY FRAME. `_process` called this on both
## boxes unconditionally, allocating six StyleBoxFlat objects per frame (~360
## per second) to redraw a value that changes a handful of times per MATCH. The
## cache below makes it a no-op unless the count or the colour actually moved,
## which is the "HUD updates cleanly without lag" half of the same report.
var _pip_cache: Dictionary = {}

## ⚠️⚠️ WITHOUT THIS THE SCOREBOARD SITS AT 0–0 FOR TWO WHOLE ROUNDS. 🧑 reported it
## straight after §8.1 landed: *"hindi uli nag didisplay yung score."*
##
## The pips are honest — a **set** is only awarded once BOTH teams have attacked, so
## nothing can legitimately fill after round 1. But "honest" and "readable" are not the
## same thing: under the old best-of-5 a round win lit a pip immediately, and now a team
## can win a round and see the board not move at all, which reads as broken rather than
## as pending.
##
## So the round line carries the in-set state, and it is the tiebreak that supplies it —
## the number this format already computes and nothing was showing. In round 2 the
## attacking side has a clock to beat, which is the whole drama of the set:
##
##   round 1        SET 1 · ROUND 1/2
##   round 2, scored    SET 1 · ROUND 2/2 · BEAT 41.2s
##   round 2, held      SET 1 · ROUND 2/2 · SCORE TO WIN
##
## `NEVER` means that team's attack never took the lata out, so the side attacking now
## wins the set by scoring at all — which is a genuinely different instruction to give a
## player than a time, and worth saying in words rather than as a sentinel number.
func _set_state_suffix() -> String:
	if MatchManager.round_in_set < MatchManagerScript.ROUNDS_PER_SET:
		return ""
	# Round 2: whoever is defending now is the team that already had its attack.
	var first_attacker := 0 if MatchManager.team_a_is_can else 1
	var benchmark := MatchManager.attack_time_for(first_attacker)
	if benchmark >= MatchManagerScript.NEVER:
		return "  ·  SCORE TO WIN"
	return "  ·  BEAT %.1fs" % benchmark

## `Hud.tscn` authors THREE pip nodes per team, for the old first-to-3 over single
## rounds. The match is first to `SETS_NEEDED` sets now (§8.1), so the third pip is a
## score nobody can reach and it reads as "0 of 3" to anyone watching. Hidden rather
## than freed — the scene is 🖥️ `build ux`'s file and removing the node belongs with
## its layout pass, filed as §4.20.
func _trim_pips(container: HBoxContainer) -> void:
	for i in container.get_child_count():
		var pip := container.get_child(i) as CanvasItem
		if pip != null:
			pip.visible = i < MatchManagerScript.SETS_NEEDED

func _fill_pips(container: HBoxContainer, filled: int, fill_color: Color = UiTheme.DEFENSE) -> void:
	var key := container.get_instance_id()
	var stamp := "%d:%s" % [filled, fill_color.to_html(false)]
	if _pip_cache.get(key, "") == stamp:
		return
	_pip_cache[key] = stamp
	for i in container.get_child_count():
		var pip: Control = container.get_child(i)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(2)
		sb.set_border_width_all(3)
		# ⚠️ WOOD_EDGE, NOT INK, AND THE EMPTY STATE IS NOW A DARK WELL RATHER THAN
		# NOTHING. A navy border was invisible on the new wood card, and an unwon pip was
		# drawn at alpha 0 — so on a dark panel it vanished completely and the scoreboard
		# read as three won rounds or as no scoreboard at all, depending on the score.
		# "Best of 5, you have won none" has to LOOK like an empty slot, and an empty slot
		# has to be drawn to be seen. This is the readable half of the same complaint the
		# fill colour fixed earlier.
		sb.border_color = UiTheme.WOOD_EDGE
		sb.bg_color = fill_color if i < filled else UiTheme.WOOD_DARK
		pip.add_theme_stylebox_override("panel", sb)

## The colour a team's pips take THIS round — the same role colour its card and
## label already use, so a filled pip reads as "that side won a round" at a
## glance rather than needing the label to disambiguate it.
func _pip_color(is_team_a: bool) -> Color:
	var a_is_can := MatchManager.team_a_is_can
	if is_team_a:
		return UiTheme.DEFENSE if a_is_can else UiTheme.OFFENSE
	return UiTheme.OFFENSE if a_is_can else UiTheme.DEFENSE

## B-15/B-35: brief on-screen call-out for a locally-relevant event that
## isn't otherwise visible on the HUD, e.g. "OUT OF BOUNDS" from the
## KillPlane respawn (see main.gd::_on_character_respawned).
func show_toast(text: String, duration: float = 1.5) -> void:
	toast_label.text = text
	toast_label.visible = true
	_toast_time_left = duration

## 2026-07-28 — the pre-round free-roam window (main.gd::_start_local_test,
## _is_confined_to_base()'s round_active gate). Shown the instant Main.tscn
## spawns everyone but before the round has actually started; hidden the
## moment the player readies up and the round begins.
## 2026-07-30: `text` added for the networked ready phase, which has something
## the solo one does not — other people to wait for. Defaults to "" so every
## existing solo call site keeps the scene's own authored line.
## 2026-07-30, R-27(b): ALSO RAISES THE ROLE OBJECTIVE. The ready phase is the last
## screen before the round and it said only how to start one, never what the player was
## about to be doing in it — dead air at exactly the moment somebody who has just read
## the tutorial needs it confirmed.
##
## ⚠️ THE OBJECTIVE IS DERIVED HERE, NOT PASSED IN. `main.gd` owns all four call sites
## and is not this lane's file, so nothing new is threaded through them: the role is
## already reachable from inside the HUD — the local character via `you_card`, and which
## side holds the can via `MatchManager` — and that is the same pair
## `set_round_display()` and `_local_team_won()` already read. Derived rather than
## remembered also means it cannot drift out of step with the team cards above it.
func show_ready_prompt(active: bool, text: String = "") -> void:
	if text != "":
		ready_prompt.text = text
	ready_prompt.visible = active
	_refresh_ready_objective(active)

## Blank when the role cannot be established — a late-joining peer can reach the ready
## phase before its own character has spawned, and NO objective is a better failure than
## confidently telling somebody to guard the lata they are about to throw a slipper at.
## (`_local_team_won()` guesses in the same situation on purpose; it is choosing between
## two fanfares and has to pick one. This is text, so it can simply say nothing.)
func _refresh_ready_objective(active: bool) -> void:
	if not active:
		ready_objective_row.visible = false
		return
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		ready_objective_row.visible = false
		return
	var defending: bool = (local_char.team == 0) == MatchManager.team_a_is_can
	# Two sentences for defence because it IS two jobs, and players who only hear
	# "guard the lata" stand on the base and never tag the thrower.
	var role_colour := UiTheme.DEFENSE if defending else UiTheme.OFFENSE
	ready_objective.text = "GUARD THE LATA.  TAG THE THROWER." if defending \
		else "KNOCK THE LATA DOWN"
	ready_objective.add_theme_color_override("font_color", role_colour)
	ready_objective_row.visible = true

## 2026-07-28 — "add a 3 2 1 timer before each match starts too, think about
## how to make it look good." One call per tick ("3", "2", "1", "GO!"); the
## caller (main.gd) times the calls a second apart. Each tick pops in oversize
## and settles to normal scale rather than just appearing, which reads far
## more like a countdown than a static label swap would — the punch is the
## whole effect at this size. HIGHLIGHT colour matches the same urgency tint
## the round timer itself uses under 15s, so it reads as "the same game
## system," not a one-off UI element.
func show_countdown_tick(text: String) -> void:
	# 4.1. Played from here rather than from main.gd's countdown loop so that
	# every caller of this function gets it for free and the pop animation and
	# its sound can never drift apart by a frame.
	AudioManager.play("countdown_go" if text == "GO!" else "countdown_tick")
	countdown_label.text = text
	countdown_label.visible = true
	countdown_label.modulate = UiTheme.HIGHLIGHT
	if _countdown_tween != null and _countdown_tween.is_valid():
		_countdown_tween.kill()
	countdown_label.pivot_offset = countdown_label.size / 2.0
	countdown_label.scale = Vector2(1.8, 1.8)
	_countdown_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_countdown_tween.tween_property(countdown_label, "scale", Vector2.ONE, 0.35)

func hide_countdown() -> void:
	if _countdown_tween != null and _countdown_tween.is_valid():
		_countdown_tween.kill()
	countdown_label.visible = false

func _on_round_started(round_number: int, team_a_is_can: bool) -> void:
	set_round_display(round_number, team_a_is_can)

## Public so a late-joining client can refresh the round/role display directly
## (see main.gd::_sync_state_to_late_joiner, B-29) without going through
## MatchManager.round_started, which main.gd also listens on to reset and
## reposition every character — correct for a real round transition, wrong for
## a peer whose characters already have correct state via
## MultiplayerSynchronizer's spawn=true replication.
##
## Colour rule (§4.2): orange = OFFENSE, blue = DEFENSE — role-coloured,
## never team-coloured. The panel accent bar and label text both move with
## the role; the panel's physical position (left vs right) stays with the team.
func set_round_display(round_number: int, team_a_is_can: bool) -> void:
	# ⚠️ "Round n / 5" WAS A BEST-OF-5 STRING AND THE MATCH IS NOT ONE ANY MORE.
	# 📋 `build rules` §8.1 scores paired sets: a set is two rounds, both teams attack
	# once, first to `SETS_NEEDED`. A bare round number no longer tells anybody where
	# the match is, and "/ 5" was simply false — this is the one HUD row a judge or a
	# viewer reads to follow the format, and it is on camera for the whole video.
	# Falls back to the round number alone before the first set opens (`set_number` is
	# 0 during the pre-round free-roam window).
	if MatchManager.set_number > 0:
		round_label.text = "SET %d  ·  ROUND %d/%d%s" % [MatchManager.set_number,
			MatchManager.round_in_set, MatchManagerScript.ROUNDS_PER_SET, _set_state_suffix()]
	else:
		round_label.text = "ROUND %d" % maxi(round_number, 1)
	_trim_pips(team_a_pips_box)
	_trim_pips(team_b_pips_box)
	# ⚠️ THE LETTER IS NO LONGER IN THIS STRING. It is its own amber glyph on each card
	# (see `_apply_wood_skin`), so the label carries the ROLE alone and the two channels —
	# letter for team, colour for role — are finally separate rather than sharing one line
	# of body text. The panel skin comes from `_style_team_card` instead of a theme
	# variation for the reason given in that section's header.
	if team_a_is_can:
		# Team A holds the can this round → Team A defends, Team B attacks.
		team_a_label.text = "DEFENSE"
		team_b_label.text = "OFFENSE"
		_style_team_card(top_left_panel, team_a_label, UiTheme.DEFENSE)
		_style_team_card(top_right_panel, team_b_label, UiTheme.OFFENSE)
	else:
		# Team A throws the slipper this round → Team A attacks, Team B defends.
		team_a_label.text = "OFFENSE"
		team_b_label.text = "DEFENSE"
		_style_team_card(top_left_panel, team_a_label, UiTheme.OFFENSE)
		_style_team_card(top_right_panel, team_b_label, UiTheme.DEFENSE)
	_fill_pips(team_a_pips_box, MatchManager.team_a_wins, _pip_color(true))
	_fill_pips(team_b_pips_box, MatchManager.team_b_wins, _pip_color(false))
	_refresh_role_accents()

## Q-5: a joining peer never sees round_started for the round already in
## progress (B-29) — main.gd::_sync_state_to_late_joiner calls this next to
## set_round_display() so the YOU card isn't blank until the next round.
func refresh_you_card() -> void:
	you_card.refresh()
	# The local character may only NOW exist (B-29), which is the first moment the
	# crosshair and the lata arrow can know which role they belong to.
	_refresh_role_accents()

## 4.1 — ROUND WIN / ROUND LOSS.
##
## ⚠️ HUNG ON MatchManager.round_intermission_started, NOT ON
## RoundManager.round_won. Two reasons, both load-bearing:
##
##  1. `round_won` is emitted by RoundManager on the HOST ONLY — it is the
##     host's decision, and what actually reaches every peer is MatchManager's
##     replicated intermission broadcast (see _sync_intermission_started). A
##     client hung on round_won would never hear a round end.
##  2. The match-DECIDING round deliberately does not emit this at all —
##     report_round_result() branches to _finish_match() instead. That is what
##     stops the last round of a match playing a round fanfare and a match
##     fanfare on top of each other.
##
## `can_team_won` is which SIDE won, and MatchManager.team_a_is_can still holds
## the JUST-ENDED round's value at this point (it is only flipped later, by
## _sync_round_started), so the two compose into which TEAM won without needing
## anything extra sent over the wire.
func _on_round_intermission_audio(_next_round: int, _next_team_a_is_can: bool, can_team_won: bool) -> void:
	var team_a_won := can_team_won == MatchManager.team_a_is_can
	AudioManager.play(_result_sfx(team_a_won))

func _on_match_won(winning_team: int) -> void:
	round_label.text = "MATCH WON"
	# 4.1. Non-positional (AudioManager.play, not play_at): a result is a fact
	# about the match, not an event at a place in the arena.
	AudioManager.play("match_win" if _local_team_won(winning_team == 0) else "round_lose")

## "did the local player's team win", given whether TEAM A did. Falls back to
## treating team A as ours when there is no local character to ask — the HUD is
## only ever instanced inside a match, but a late-joining peer can reach here
## before its own character has spawned, and a wrong-but-present fanfare is a
## better failure than a silent round end.
func _local_team_won(team_a_won: bool) -> bool:
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		return team_a_won
	return (local_char.team == 0) == team_a_won

func _result_sfx(team_a_won: bool) -> String:
	return "round_win" if _local_team_won(team_a_won) else "round_lose"

## Call when the locally-viewed Can enters/exits Downed — clear visual read for
## stream/demo per GDD Section 6.
func set_downed_flash(active: bool) -> void:
	downed_flash.visible = active

## Option A only. Call with the locally-viewed Can's current dent count once
## GameLaunch.game_mode == OPTION_A; leave uncalled (default hidden) under
## Option B, which has no dent concept.
## Filled pip = structural integrity remaining (max_dents − current).
func set_dents(current: int, max_dents: int) -> void:
	lata_card.visible = true
	_fill_pips(dent_pips_box, max_dents - current, UiTheme.DEFENSE)
	if current > 0:
		dent_text_label.text = "Dents: %d / %d" % [current, max_dents]
		dent_text_label.visible = true
	else:
		dent_text_label.visible = false
