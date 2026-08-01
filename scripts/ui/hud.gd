extends Control
class_name Hud

## HUD per GDD Section 6: current round, Bo5 tracker, timer, who's Attack vs Defense.
## Reads the RoundManager/MatchManager autoloads directly — no per-scene wiring needed,
## drop this scene into Main.tscn (or a match scene) and it just works.

@onready var timer_label: Label = %TimerLabel
@onready var timer_card: PanelContainer = %TimerCard
@onready var round_label: Label = %RoundLabel
## ⚠️ THE 2v2 TEAM CARDS ARE GONE FROM THE SCENE — § CHECKLIST 1.1. `TopLeft` and its
## `TopRight` mirror carried an A/B letter mark, an OFFENSE/DEFENSE caption and a
## three-pip win row each; `LataCard` carried a dent counter. None of those five things
## exists in a four-player scored match (`Design.md` §1, §8, §12), and this file used to
## hide all of them at `_build_scoreboard()` and draw the real board on top in code.
## The four rows are authored in `HUD.tscn` now and bound here.
@onready var scoreboard_panel: PanelContainer = %Scoreboard
@onready var score_title: Label = %ScoreTitle
@onready var lata_card: PanelContainer = %LataCard
@onready var lata_label: Label = %LataLabel
@onready var lata_hint_label: Label = %LataHintLabel
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
	# ⚠️ THE SCOREBOARD IS EVENT-DRIVEN, NOT POLLED, and that is what makes a score
	# floater possible at all: `_process` can see that a number changed but not by
	# how much or why, and "+50 SABOTAGE" is the half a spectator actually reads.
	MatchManager.score_changed.connect(_on_score_changed)
	RoundManager.lata_knocked.connect(_on_lata_knocked)
	RoundManager.lata_restored.connect(_on_lata_restored)
	RoundManager.attacker_tagged.connect(_on_attacker_tagged)
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
	_build_scoreboard()
	set_round_display(MatchManager.round_number, MatchManager.defender_slot)
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
	# ⚠️ WAS `CREAM_MUTED`. This line carries the round number and who is playing taya
	# — the two facts that change everything about how the next 90 s goes — and it was
	# styled as a caption under the clock.
	round_label.add_theme_color_override("font_color", UiTheme.CREAM)
	round_label.add_theme_font_size_override("font_size", 20)
	round_label.add_theme_color_override("font_outline_color", UiTheme.INK)
	round_label.add_theme_constant_override("outline_size", TEXT_OUTLINE)

	# ⚠️ THE A/B LETTER MARKS ARE GONE WITH THE TEAM CARDS. The comment here read "this
	# is the one thing on the card that identifies the team, and it has to stay put when
	# the roles swap" — true of a 2v2, meaningless with four independent players. The
	# scoreboard's own title takes the amber instead, in `_build_scoreboard()`.

	lata_card.add_theme_stylebox_override("panel",
		_hud_wood_style(UiTheme.WOOD_DEEP, UiTheme.WOOD_EDGE))
	lata_label.add_theme_color_override("font_color", UiTheme.AMBER)
	lata_hint_label.add_theme_color_override("font_color", UiTheme.CREAM)

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
	var role_colour: Color = UiTheme.DEFENSE if local_char.is_defender else UiTheme.OFFENSE
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
	_refresh_scoreboard()
	_refresh_lata_card()

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
	# ⚠️ THE CROSSHAIR IS THE THROW-LEGALITY TELL, and it asks the SAME function the
	# throw itself asks. A second opinion about legality is a crosshair that promises
	# a throw the rules then refuse, which is the most confusing possible failure —
	# the player sees no reason for nothing to have happened.
	var live := local_char != null and is_instance_valid(local_char)
	crosshair.visible = live and RoundManager.can_throw(local_char)
	# 3.4: same cached character, no second scan.
	offscreen_indicators.update(local_char)
	_refresh_status_stack(local_char)
	_refresh_stamina(local_char)
	_refresh_danger(local_char)
	_refresh_vulnerable_text(local_char)

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
		"STUNNED", "DOWNED", "VULNERABLE":
			return UiTheme.DANGER
		"FATIGUED":
			return UiTheme.AMBER
		_:
			return UiTheme.HIGHLIGHT

## ---------------------------------------------------------------------------
## ⚠⚠ THE DANGER VIGNETTE — A HELD STATE, AND IT IS THE SECOND TIME THIS NODE HAS
## CHANGED KIND. New 2026-08-01, on human instruction:
##   * *"The full-screen red vignette should only appear on the Defender's screen
##     when the Lata is knocked over. The effect should remain active until the can
##     is stood back up."*
##   * *"Trigger the red vignette on an attacker's screen immediately when they
##     become vulnerable ... until the attacker either safely crosses the boundary
##     line back into the Safe Zone or gets tagged."*
##
## ⚠️ BOTH OF THOSE ARE STATES THAT LAST TENS OF SECONDS, AND THE FILE ALREADY
## RECORDS WHY THAT WENT WRONG BEFORE. `set_downed_flash()`'s own note: a
## full-screen red `ColorRect` held on *"does not read as feedback. It reads as the
## renderer being broken: measured on the first captured frame of a live match, the
## entire arena was washed red."* So the previous lane replaced the state with a
## 0.45 s pulse.
##
## The instruction and that finding are both right, and the thing that reconciles
## them is ALPHA, not duration. `DOWNED_FLASH_PEAK` is 0.45 — fine for a flash, a
## wash if held. `DANGER_HOLD_ALPHA` is 0.16: enough to tint the frame red and be
## noticed in peripheral vision, low enough to read the arena through for a whole
## round. The knockdown PULSE is kept on top of it, so the moment still punches.
##
## ⚠️ AND IT IS PER-SCREEN, WHICH IS THE HALF THAT MAKES IT INFORMATION. The two
## conditions are asked of the LOCAL character only — a defender sees their can is
## down, an attacker sees they are catchable, and neither sees the other's warning.
## A vignette everybody gets at the same time tells nobody anything.
const DANGER_HOLD_ALPHA: float = 0.16
var _danger_held: bool = false

func _refresh_danger(local_char: CharacterBase) -> void:
	var want := false
	if local_char != null and is_instance_valid(local_char):
		if local_char.is_defender:
			# The can is down and it is your job to fix it.
			var can := RoundManager.lata
			want = can != null and not can.is_upright and RoundManager.round_active
		else:
			# ⚠️ `is_taggable()` IS THE WHOLE CONDITION AND IT IS DELIBERATELY THE SAME
			# FUNCTION THE TAG ASKS (`Design.md` §5.2). "Until they cross back out or get
			# tagged" is not two extra checks — it is exactly what that function stops
			# returning true for, so the warning cannot disagree with the rule.
			want = local_char.is_taggable()
	if want == _danger_held:
		return
	_danger_held = want
	_apply_danger_hold()

## Applied separately from the pulse so the two can coexist: the pulse tweens
## `modulate:a` down to zero and then hands back to whatever the held state wants.
func _apply_danger_hold() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		return # a pulse owns the alpha right now; it restores the hold when it ends
	downed_flash.visible = _danger_held
	downed_flash.modulate.a = DANGER_HOLD_ALPHA if _danger_held else 0.0

## ⚠️ THE CROSSHAIR SAYS IT IN WORDS NOW. 🧑: *"Remove the vulnerable timer bar and
## replace it with static text directly below the crosshair reading: YOU ARE
## VULNERABLE."* The bar was the one row in the status stack with no countdown — it
## lasts exactly as long as you choose to stand in the box holding a slipper — so it
## was already a bar pretending to be a timer. Text at the crosshair is where the
## player is looking, and it needs no legend.
var _vulnerable_label: Label = null

func _ensure_vulnerable_label() -> Label:
	if _vulnerable_label != null and is_instance_valid(_vulnerable_label):
		return _vulnerable_label
	var label := Label.new()
	label.name = "VulnerableWarning"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "YOU ARE VULNERABLE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# ⚠️ BIGGER THAN THE STATUS ROWS ON PURPOSE. 🧑 asked for HUD text to grow
	# *"to improve readability during fast-paced movement"*, and this is the one line
	# that means "you are about to lose 5 seconds". Same INK outline everything over
	# the 3D scene uses.
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", UiTheme.OFFENSE)
	label.add_theme_color_override("font_outline_color", UiTheme.INK)
	label.add_theme_constant_override("outline_size", TEXT_OUTLINE)
	# Dead centre, just under the crosshair — where the eye already is.
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.position = Vector2(-160.0, 34.0)
	label.custom_minimum_size = Vector2(320.0, 0.0)
	label.visible = false
	add_child(label)
	_vulnerable_label = label
	return label

func _refresh_vulnerable_text(local_char: CharacterBase) -> void:
	var vulnerable_label := _ensure_vulnerable_label()
	if vulnerable_label == null:
		return
	var live := local_char != null and is_instance_valid(local_char) 			and local_char.is_taggable()
	vulnerable_label.visible = live

func _refresh_status_stack(local_char: CharacterBase) -> void:
	var root := _ensure_status_root()
	var effects: Array[Dictionary] = []
	if local_char != null and is_instance_valid(local_char):
		# ⚠️ VULNERABLE IS FILTERED OUT HERE, NOT REMOVED FROM `status_effects()`.
		# 🧑 2026-08-01: *"Remove the vulnerable timer bar and replace it with static
		# text directly below the crosshair"* — `_refresh_vulnerable_text()` draws it
		# now. The RULE stays where it was: `is_taggable()` is read by the tag, by the
		# vignette and by that label, and `status_effects()` is still the honest list
		# of what is live on this body. This is a presentation choice about one row,
		# so it is made in the thing doing the presenting.
		for effect in local_char.status_effects():
			if String(effect.get("label", "")) != "VULNERABLE":
				effects.append(effect)
	# ⚠️ THE LATA COUNTDOWN IS APPENDED HERE, NOT IN `status_effects()`, AND THAT IS A
	# REAL DISTINCTION. Everything the character returns is a fact about YOUR OWN BODY;
	# this is a fact about the ROUND, it is the same number for all four players, and it
	# lives on `RoundManager`. Asking a character about it would have four units each
	# reporting the state of an object none of them is.
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
		# ⚠️ A ROW WITH NO COUNTDOWN IS A REAL CASE, NOT A BUG. `VULNERABLE` lasts
		# exactly as long as the player chooses to stand in the box holding a slipper,
		# so it reports `seconds` 0 and draws as a solid bar with no timer. Printing
		# "VULNERABLE  0.0s" would read as an effect that had already expired.
		var timed := seconds > 0.0
		label.text = ("%s  %.1fs" % [text, seconds]) if timed else text
		label.add_theme_color_override("font_color", colour)
		var bar := row.get_node("Bar") as ProgressBar
		bar.value = clampf(seconds / total, 0.0, 1.0) if timed else 1.0
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
	if not RoundManager.round_active:
		_spectator_round.add_theme_color_override("font_color", UiTheme.AMBER)
		_spectator_round.text = "WAITING FOR THE ROUND TO START"
		return
	# ⚠️ WAS THE OUT-OF-CIRCLE COUNTDOWN. That clock decided every round in the old
	# ruleset, so it was the one thing a caster had to see. There is no such clock —
	# the round is 90 s of scoring — so the broadcast line is the thing that now
	# decides it: who is defending, and whether the lata is up.
	var order := MatchManager.ranking()
	var leader := order[0] if not order.is_empty() else 0
	var up: bool = RoundManager.lata != null and RoundManager.lata.is_upright
	_spectator_round.add_theme_color_override("font_color",
		UiTheme.DEFENSE if up else UiTheme.OFFENSE)
	_spectator_round.text = "ROUND %d/%d   ·   TAYA  P%d   ·   LATA %s   ·   LEADER  P%d  %d" % [
		maxi(1, MatchManager.round_number), MatchManagerScript.ROUNDS,
		MatchManager.defender_slot + 1, "UP" if up else "DOWN",
		leader + 1, MatchManager.score_for(leader)]

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
## ⚠️ `_set_state_suffix()` AND `_trim_pips()` WERE DELETED HERE. They rendered the
## paired-set format's attack-time benchmark ("BEAT 41.2s") and clipped the win-pip
## row to `SETS_NEEDED`. There are no sets and no per-round winner.

## `Hud.tscn` authors THREE pip nodes per team, for the old first-to-3 over single
## rounds. The match is first to `SETS_NEEDED` sets now (§8.1), so the third pip is a
## score nobody can reach and it reads as "0 of 3" to anyone watching. Hidden rather
## than freed — the scene is 🖥️ `build ux`'s file and removing the node belongs with
## its layout pass, filed as §4.20.
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
## ⚠️ `_pip_color()` WAS DELETED HERE — it coloured a pip by which side Team A was
## playing, and there are no teams.

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
	var defending: bool = local_char.is_defender
	# Two sentences for defence because it IS two jobs, and players who only hear
	# "guard the lata" stand on the base and never tag the thrower.
	var role_colour := UiTheme.DEFENSE if defending else UiTheme.OFFENSE
	# Two sentences for the taya because it IS two jobs, and a player who only hears
	# "guard the lata" stands on the base and never tags anybody. Two for the attacker
	# for the same reason: the retrieval run is the half people miss.
	ready_objective.text = "GUARD THE LATA.  TAG ANYONE HOLDING A SLIPPER." if defending \
		else "KNOCK THE LATA DOWN.  RETRIEVE FROM THE BOX."
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

func _on_round_started(round_number: int, defender_slot: int) -> void:
	set_round_display(round_number, defender_slot)

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
func set_round_display(round_number: int, defender_slot: int) -> void:
	# ⚠️ NAME, NOT SEAT. This used to hardcode "P%d" off the raw slot, so a taya
	# who set a name in Settings still read as "P3" here — the one thing on
	# screen that most needs to say who is playing. `_refresh_scoreboard()` a
	# few dozen lines down already reads `display_name()` for every row;
	# this is the row that didn't.
	var taya := RoundManager.player_at(defender_slot)
	var taya_name := taya.display_name() if taya != null else "P%d" % [defender_slot + 1]
	round_label.text = "ROUND %d / %d   ·   TAYA: %s" % [
		maxi(round_number, 1), MatchManagerScript.ROUNDS, taya_name]
	# The two top cards are now a scoreboard and a lata readout rather than two team
	# panels. The letters and pip boxes the 2v2 layout used are hidden in
	# `_build_scoreboard()` rather than deleted from `HUD.tscn`, so the scene stays
	# 🖥️ `build ui`'s to reshape.
	_refresh_scoreboard()
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
func _on_round_intermission_audio(_next_round: int, _next_defender_slot: int) -> void:
	# ⚠️ NO PER-ROUND WIN/LOSE STING ANY MORE, because there is no per-round winner —
	# a round ends, the scores persist, the taya rotates. Playing the old
	# `round_win`/`round_lose` pair here would tell every player they had won or lost
	# something that did not happen.
	AudioManager.play("round_end")

func _on_match_won(winning_slot: int) -> void:
	round_label.text = "MATCH OVER"
	var local_char := you_card.get_local_character()
	var mine := local_char != null and is_instance_valid(local_char) 		and local_char.player_slot == winning_slot
	AudioManager.play("match_win" if mine else "round_lose")

## "did the local player's team win", given whether TEAM A did. Falls back to
## treating team A as ours when there is no local character to ask — the HUD is
## only ever instanced inside a match, but a late-joining peer can reach here
## before its own character has spawned, and a wrong-but-present fanfare is a
## better failure than a silent round end.
## Call when the locally-viewed Can enters/exits Downed — clear visual read for
## stream/demo per GDD Section 6.
## ⚠️⚠️ A PULSE, NOT A STATE, AND THAT DISTINCTION IS THE WHOLE BUG.
##
## This used to be `downed_flash.visible = active`, driven by whether the unit YOU
## were driving was down — a damage vignette, on for the second or two you spent on
## the floor. It is now driven by whether the LATA is down, which in a real round is
## most of the time, and a full-screen red `ColorRect` left on for forty seconds does
## not read as feedback. It reads as the renderer being broken: measured on the first
## captured frame of a live match, the entire arena was washed red.
##
## So the knockdown gets a flash the length of a flash. `active` false still clears
## it immediately, because the lata coming back up should not wait out a tween.
func set_downed_flash(active: bool) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if not active:
		downed_flash.visible = false
		return
	downed_flash.visible = true
	# ⚠️ PEAKS BELOW FULL. At alpha 1.0 the vignette is opaque enough to hide the arena
	# for its whole duration, and the frame it lands on is exactly the frame the player
	# wants to see — where the lata went and who threw it. It has to register as a hit,
	# not black the shot out.
	downed_flash.modulate.a = DOWNED_FLASH_PEAK
	_flash_tween = create_tween()
	_flash_tween.tween_property(downed_flash, "modulate:a", 0.0, DOWNED_FLASH_TIME)
	# ⚠️ HANDS BACK TO THE HELD STATE rather than hiding outright — the knockdown
	# pulse and the defender's "your can is down" hold fire on the same frame, and
	# a bare `visible = false` here would cancel the hold the pulse announced.
	_flash_tween.tween_callback(func() -> void:
		_flash_tween = null
		_apply_danger_hold())

## How long the knockdown vignette lasts. Long enough to register as a hit landing,
## short enough that it is gone before the player looks for the lata.
const DOWNED_FLASH_TIME: float = 0.45
const DOWNED_FLASH_PEAK: float = 0.45
var _flash_tween: Tween = null

## Option A only. Call with the locally-viewed Can's current dent count once
## GameLaunch.game_mode == OPTION_A; leave uncalled (default hidden) under
## Option B, which has no dent concept.
## Filled pip = structural integrity remaining (max_dents − current).
## ⚠️ `set_dents()` WAS DELETED HERE. It drew Option A's lata health bar, a mode
## that was removed before this rewrite and whose last caller went with the dent
## field. `LataCard` now reports whether the lata is standing — see
## `_refresh_lata_card()`.

# =============================================================================
# THE SCOREBOARD, THE LATA CARD AND THE STAMINA BAR
#
# ⚠️ ALL THREE ARE BUILT IN CODE INTO PANELS `HUD.tscn` ALREADY HAS, and that is a
# deliberate scope decision rather than laziness. The scene was authored for two
# team cards with a three-pip win row each; four players need four rows, and the
# lata needs a state readout rather than a dent counter. Reshaping the scene is the
# UI lane's row on the board. Hiding the 2v2 children and appending real ones keeps
# the anchors, the wood skin and the safe-area work the window-fit pass measured —
# and it leaves the scene file that lane's to restructure.
# =============================================================================

## One row per player. Built once, refreshed when something moves.
var _score_rows: Array[Control] = []
## Only redraw when something actually changed — a scoreboard rebuilt every frame is
## four `StyleBoxFlat` allocations a frame for a thing that moves twice a round.
var _score_stamp: String = ""

## ⚠️ IT BINDS NOW, IT NO LONGER BUILDS. The rows are authored in `HUD.tscn`, so this
## walks `%ScoreRow0..3` instead of allocating four `HBoxContainer`s and eight `Label`s
## at runtime — and the six-node hide list that used to sit at the top of this function
## is gone with the nodes it was hiding.
func _build_scoreboard() -> void:
	if not _score_rows.is_empty():
		return
	# ⚠️⚠️ THE PANEL HAS TO BE RE-SKINNED HERE. `_apply_wood_skin()` styles the timer
	# and the lata card but NOT the two team panels — those were painted by
	# `set_round_display()` calling `_style_team_card()` with a role colour, and that
	# call went with the two-team layout. Without this the scoreboard renders on the
	# stock theme: a flat white box next to a wood-and-amber timer, which is exactly
	# the "doesn't look like our theme" complaint the wood restyle was done to fix.
	# 🧑 2026-07-31, on the first screenshot of this build: *"ugly ui btw, not even
	# same theme wtf is that white shit"*.
	_style_team_card(scoreboard_panel, score_title, UiTheme.AMBER)
	score_title.add_theme_color_override("font_color", UiTheme.AMBER)
	for slot in range(MatchManagerScript.PLAYER_COUNT):
		var row := get_node_or_null("%%ScoreRow%d" % [slot]) as Control
		if row == null:
			push_error("HUD: ScoreRow%d missing from HUD.tscn" % [slot])
			return
		# The outline colour is the one thing the scene cannot state: it is a theme
		# constant, not a per-node property, and both cells need it against a live 3D
		# background rather than against the panel.
		for cell_name in ["Name", "Score"]:
			var cell := row.get_node_or_null(cell_name) as Label
			if cell != null:
				cell.add_theme_color_override("font_outline_color", UiTheme.INK)
		_score_rows.append(row)

## ⚠️ `_score_cell()` IS DELETED AND ITS ONE LOAD-BEARING FACT MOVED INTO `HUD.tscn`.
## It built the Name/Score labels at runtime; the scene authors them now (§ CHECKLIST
## 1.1). The fact worth keeping is the font size: **20 px, not 15**. The scoreboard sits
## beside a 48 px timer and a 22 px header, and at 15 it read as a debug printout rather
## than as part of the HUD — 🧑 2026-07-31: *"the text look bad too"*. It is the only
## place in the match a player reads four numbers at a glance, so it is set close to the
## header's weight in the scene, on every `ScoreRow`'s two cells.

## ⚠️ SORTED BY SCORE, NOT BY SEAT, AND THE MARKER SAYS WHO IS DEFENDING. Both halves
## matter to a spectator: the ranking is the story of the match, and the defender
## marker is the only thing on screen that explains why one player is behaving
## completely differently from the other three.
func _refresh_scoreboard() -> void:
	if _score_rows.is_empty():
		return
	var stamp := "%s|%d" % [str(MatchManager.scores), MatchManager.defender_slot]
	if stamp == _score_stamp:
		return
	_score_stamp = stamp
	var order := MatchManager.ranking()
	var local_char := you_card.get_local_character()
	var mine := local_char.player_slot if local_char != null and is_instance_valid(local_char) else -1
	for i in _score_rows.size():
		var row: Control = _score_rows[i]
		if i >= order.size():
			row.visible = false
			continue
		var slot: int = order[i]
		row.visible = true
		var is_taya := slot == MatchManager.defender_slot
		var name_label := row.get_node("Name") as Label
		var score_label := row.get_node("Score") as Label
		# The bullet marks YOU; the word marks the taya. Two different questions, so
		# two different marks rather than one overloaded glyph.
		# The bullet marks YOU; the word marks the taya. Two different questions, so
		# two marks rather than one overloaded glyph.
		var who := RoundManager.player_at(slot)
		var who_name: String = who.display_name() if who != null else "P%d" % [slot + 1]
		name_label.text = "%s %s%s" % ["\u25B8" if slot == mine else "  ", who_name,
			"  TAYA" if is_taya else ""]
		score_label.text = str(MatchManager.score_for(slot))
		var colour: Color = UiTheme.DEFENSE if is_taya else UiTheme.OFFENSE
		if slot == mine:
			colour = UiTheme.HIGHLIGHT
		name_label.add_theme_color_override("font_color", colour)
		score_label.add_theme_color_override("font_color", colour)

## `LataCard` is the one readout every player needs whatever their role: the throw is
## illegal while the lata is down, and the passive score only ticks while it is up.
func _refresh_lata_card() -> void:
	var lata := RoundManager.lata
	if lata == null or not RoundManager.round_active:
		lata_card.visible = false
		return
	lata_card.visible = true
	lata_label.text = "LATA  ·  UPRIGHT" if lata.is_upright else "LATA  ·  DOWN"
	lata_label.add_theme_color_override("font_color",
		UiTheme.DEFENSE if lata.is_upright else UiTheme.OFFENSE)
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		lata_hint_label.visible = false
		return
	# The second line is what THIS player can do about it, which differs by role and
	# is the whole reason the card is not just a coloured light.
	var line := ""
	if local_char.is_defender:
		if not lata.is_upright:
			var carrier := local_char.get_node_or_null("Carrier") as Carrier
			var progress: float = carrier.channel_progress() if carrier != null else -1.0
			line = ("RESETTING  %d%%" % int(progress * 100.0)) if progress >= 0.0 \
				else "HOLD E IN THE RING"
	elif RoundManager.throw_cooldown_left() > 0.0:
		line = "THROW LOCKED  %.1fs" % RoundManager.throw_cooldown_left()
	elif not local_char.holding_slipper():
		line = "RETRIEVE A SLIPPER"
	elif local_char.is_inside_box():
		line = "GET OUT OF THE BOX TO THROW"
	lata_hint_label.text = line
	lata_hint_label.visible = line != ""

## ⚠️ FATIGUE IS SHOWN ON THE BAR AS WELL AS IN THE STATUS STACK, and that is not a
## duplicate. The stack row says how long it lasts; the bar says why it happened. A
## player who empties the bar and then cannot sprint needs both facts in one glance,
## and the stack is top-centre while the bar is above their own card.
## ⚠️ THE HUD NO LONGER DRAWS ITS OWN STAMINA BAR, AND THIS IS THE SECOND HALF OF
## THAT DECISION. A centre-bottom bar was added here at the same time `you_card.gd`
## was already drawing one from the same `get_stamina_ratio()` — two bars, same
## number, forty pixels apart. `YouCard` keeps it, because that card is where a
## player already looks for their own state, and it now carries the FATIGUED read
## as well (`you_card.gd::_update_guard_dash_meter`).
func _refresh_stamina(_local_char: CharacterBase) -> void:
	pass

# --- Score and event feedback -------------------------------------------------

## ⚠️ ONLY THE LOCAL PLAYER'S OWN AWARDS POP A FLOATER, AND THE PASSIVE TICK NEVER
## DOES. Passive defence fires every single second of every round; toasting it would
## be a message that never leaves the screen and says nothing while it is there. The
## scoreboard already carries that number.
func _on_score_changed(slot: int, _total: int, delta: int, reason: String) -> void:
	if reason == "DEFENSE":
		return
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		return
	if local_char.player_slot != slot:
		return
	show_toast("+%d  %s" % [delta, reason], 1.2)

func _on_lata_knocked(by_slot: int) -> void:
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		return
	if local_char.is_defender:
		show_toast("LATA DOWN  ·  RESET IT", 1.6)
	elif by_slot >= 0 and by_slot != local_char.player_slot:
		show_toast("P%d KNOCKED THE LATA DOWN" % [by_slot + 1], 1.2)

func _on_lata_restored() -> void:
	show_toast("LATA IS BACK UP", 1.2)

func _on_attacker_tagged(defender_slot: int, victim_slot: int) -> void:
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		return
	if local_char.player_slot == victim_slot:
		show_toast("TAGGED  ·  BACK TO THE SAFE ZONE", 2.0)
	elif local_char.player_slot == defender_slot:
		show_toast("TAG  ·  P%d" % [victim_slot + 1], 1.4)
