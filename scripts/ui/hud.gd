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
## § THE STUN FROST — the screen half. See `_refresh_frost()`.
@onready var frost_vignette: ColorRect = %FrostVignette
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
@onready var emote_wheel: EmoteWheel = %EmoteWheel

var _toast_time_left: float = 0.0
var _pulse_tween: Tween = null
var _countdown_tween: Tween = null

## ⚠️⚠️ THESE THREE EXIST ONLY TO STOP `_process` REWRITING THINGS THAT HAVE NOT
## CHANGED, and they were added off a measurement, not a hunch.
## `tools/perf_attrib.tscn` brackets the frame's whole script `_process` pass
## between two sentinel nodes and reports it per subsystem. On eskinita, in a real
## four-body match, the HUD was 0.20 ms of a 0.47 ms total — more than all four
## `character_visual.gd` `_process` calls put together, for a screen that changes
## a handful of times a second.
##
## The cause was three unconditional writes per frame: the clock string, the clock
## colour, and the whole lata card. `add_theme_color_override()` in particular is
## not a field assignment — it writes into the Control's theme override map and
## notifies the control (and its children) that the theme changed, every single
## call, whether or not the Color differs from the one already there.
##
## ⚠️ NONE OF THIS CHANGES WHAT IS DRAWN. Each guard reproduces the previous
## behaviour exactly on the frame the value actually changes, and skips the
## identical rewrite on the frames in between. -1 and "" are "nothing shown yet",
## so the first frame always writes.
var _timer_seconds_shown: int = -1
var _timer_urgent: int = -1 # -1 unknown, 0 amber, 1 highlight
var _lata_upright_shown: int = -1
var _lata_hint_shown: String = "￿" # never equal to a real hint, so frame 1 writes

## ⚠️ SET BACK TO AMBER, NOT `remove_theme_color_override`. Removing it would fall
## through to the HudTimer variation's near-white, which is the pre-wood colour —
## so the timer would go white the moment it climbed back over 15s.
func _set_timer_urgent(urgent: bool) -> void:
	var want := 1 if urgent else 0
	if want == _timer_urgent:
		return
	_timer_urgent = want
	timer_label.add_theme_color_override("font_color",
		UiTheme.HIGHLIGHT if urgent else UiTheme.AMBER)

func _ready() -> void:
	emote_wheel.emote_chosen.connect(_on_emote_chosen)
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
	# § THE STUN FROST rides along: it is a transient like the flash above, and a
	# spectator has no stun of their own to be told about.
	frost_vignette.visible = false
	_frost_coverage = 0.0
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
	# ⚠️ 22/16 FROM 14/8, TO MATCH THE 2026-08-02 HUD FONT SIZES. 🧑: *"GOOD TEXT NOW
	# ... js make box bigger"*. These margins were chosen against 13/16pt lettering; at
	# 32/34 the same numbers read as text jammed against a border. Padding rather than a
	# taller anchored rect for the reason `you_card.gd` records at its own copy of these
	# four lines: margins scale WITH the content, so no row set ends up rattling around
	# inside a box sized for a different one.
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
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
	# ⚠️ ONLY ON THE SECOND, NOT EVERY FRAME. The clock has one-second resolution, so
	# at 120 fps this formatted and assigned the same two-digit string 119 times out of
	# 120 for nothing. `Label.text` is not a plain setter — an assignment invalidates
	# the text buffer and queues a reshape whether or not the characters changed.
	# See the ⚠️ on `_timer_urgent` for how this pair was found.
	if t != _timer_seconds_shown:
		_timer_seconds_shown = t
		timer_label.text = "%02d:%02d" % [t / 60, t % 60]

	# Timer urgency (§4.4): HIGHLIGHT colour under 15s, scale pulse under 10s.
	# Scale tween instead of colour flash to avoid collision with the downed vignette.
	if RoundManager.time_left < 15.0:
		_set_timer_urgent(true)
		if RoundManager.time_left < 10.0:
			if _pulse_tween == null or not _pulse_tween.is_running():
				timer_card.pivot_offset = timer_card.size / 2
				_pulse_tween = create_tween().set_loops()
				_pulse_tween.tween_property(timer_card, "scale", Vector2(1.05, 1.05), 0.5)
				_pulse_tween.tween_property(timer_card, "scale", Vector2(1.0, 1.0), 0.5)
		else:
			_kill_pulse_tween()
	else:
		_set_timer_urgent(false)
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
		# ⚠️⚠️ THE FROST, NOW THAT A POV IS A REAL FIRST-PERSON FRAME.
		# `Master_Prompt_Spectator_Player_POV.md` § C.4: this early return used to skip
		# `_refresh_frost()` outright — a spectator's own body has no stagger of its
		# own, which was true of the OLD placement-only POV and is no longer the whole
		# story now that a POV borrows a real player's rig. `spectated_pov_character()`
		# is null in free flight and over-the-shoulder follow (both correctly draw no
		# frost) and the watched unit only while an actual borrow is up.
		_refresh_frost(_spectator_camera.spectated_pov_character()
			if _spectator_camera != null and is_instance_valid(_spectator_camera) else null,
			get_process_delta_time())
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
	_refresh_frost(local_char, get_process_delta_time())

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
const STATUS_BAR_SIZE: Vector2 = Vector2(190, 8)
## ⚠️ FONT 20, UP FROM 15. Handoff A: *"Scale up non-scoreboard HUD text."* The new
## YOU ARE VULNERABLE label is 22 and is the reference; the status rows were the
## smallest text in the game and sat over a live 3D scene.
const STATUS_FONT_SIZE: int = 20
## How far in from the screen edge each stack sits, and how far down.
const STATUS_MARGIN: Vector2 = Vector2(38, 150)

## ⚠️⚠️ TWO STACKS, NOT ONE. Handoff A: status effects on the LEFT, ability
## cooldowns on the RIGHT. Both used to come out of one `status_effects()` list into
## one centred stack under the timer, which meant "I am STUNNED" and "my shove is
## recharging" competed for the same four rows — and the two are read at different
## moments and mean different things. One is what is being done TO you, the other is
## what you may do next.
##
## ⚠️ IT IS A ROUTING DECISION, NOT A GAMEPLAY ONE. `status_effects()` is untouched
## and is still the honest list of what is live on the body; every row already
## carries its own `label`, so the split is a partition of that list here.
var _status_root_left: VBoxContainer = null
var _status_root_right: VBoxContainer = null
var _status_rows_left: Array[Control] = []
var _status_rows_right: Array[Control] = []

func _ensure_status_root(right_side: bool) -> VBoxContainer:
	var existing := _status_root_right if right_side else _status_root_left
	if existing != null and is_instance_valid(existing):
		return existing
	var root := VBoxContainer.new()
	root.name = "StatusStackRight" if right_side else "StatusStackLeft"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 6)
	# ⚠️ ANCHORED TO ITS OWN CORNER, NOT PARENTED TO A CARD. A growing stack must
	# never push another element around, which is why the single centred stack was
	# anchored rather than parented in the first place. Same rule, two corners.
	root.set_anchors_preset(Control.PRESET_TOP_RIGHT if right_side else Control.PRESET_TOP_LEFT)
	root.custom_minimum_size = Vector2(STATUS_BAR_SIZE.x, 0)
	if right_side:
		root.position = Vector2(-STATUS_BAR_SIZE.x - STATUS_MARGIN.x, STATUS_MARGIN.y)
		root.alignment = BoxContainer.ALIGNMENT_END
	else:
		root.position = Vector2(STATUS_MARGIN.x, STATUS_MARGIN.y)
	add_child(root)
	if not right_side:
		# ⚠️⚠️ THE LEFT STACK SAT ON TOP OF THE SCOREBOARD. Reported 2026-08-02 with a
		# screenshot of `STUNNED 0.2s` and its red bar drawn straight through the P2
		# and P4 score rows: *"put you are stunned somewhere else"*.
		#
		# Both are anchored TOP_LEFT — the board at (16, 28) and this at a hardcoded
		# (38, 150) — and 150 px is simply inside the board, which is four score rows
		# plus a title and grows with the font. The constant was written when the
		# stack was centred under the timer and was never re-checked after Handoff A
		# split it into two corners.
		#
		# ⚠️ DERIVED FROM THE BOARD'S REAL HEIGHT, NOT NUDGED TO A BIGGER NUMBER. A
		# second literal would be wrong again the next time a row is added, the font
		# grows, or a name wraps — so it asks the panel where it actually ends.
		_follow_scoreboard(root)
		if scoreboard_panel != null:
			scoreboard_panel.resized.connect(_follow_scoreboard.bind(root))
	if right_side:
		_status_root_right = root
	else:
		_status_root_left = root
	return root

## Park the left status stack under the scoreboard, whatever height that board is.
## `STATUS_MARGIN.y` stays the floor, so a board that is somehow shorter than the
## old literal cannot pull the stack UP into the top corner.
const STATUS_UNDER_BOARD_GAP: float = 18.0

func _follow_scoreboard(root: VBoxContainer) -> void:
	if root == null or not is_instance_valid(root):
		return
	var top := STATUS_MARGIN.y
	if scoreboard_panel != null and is_instance_valid(scoreboard_panel):
		top = maxf(top, scoreboard_panel.position.y + scoreboard_panel.size.y \
			+ STATUS_UNDER_BOARD_GAP)
	root.position = Vector2(STATUS_MARGIN.x, top)

func _build_status_row() -> Control:
	var row := VBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", STATUS_FONT_SIZE)
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

## ---------------------------------------------------------------------------
## ⚠️⚠️ § THE STUN FROST — THE SCREEN HALF. 🧑 2026-08-06: *"can we have like a frost
## effect to indicate that an attacker is stunned after getting tagged?"*, with a
## reference image of an icy frame around a clear centre.
##
## ⚠️ IT IS THE VICTIM'S SCREEN ONLY, and the body half in `character_visual.gd` is what
## everybody else sees. That split is `_refresh_danger()`'s own rule applied again: *"A
## vignette everybody gets at the same time tells nobody anything."* The taya spent their
## one scoring verb on that tag and needs to watch the attacker freeze; the attacker
## needs to know why their controls stopped answering. Those are two different messages
## and they go to two different places.
##
## ⚠️⚠️ AND IT IS WHY THE SHAPE MATTERS RATHER THAN THE ALPHA. `set_downed_flash()`
## records the measurement that governs this whole file: a held full-screen tint *"reads
## as the renderer being broken ... the entire arena was washed red"*, which is why held
## states sit at `DANGER_HOLD_ALPHA` 0.16 while only a 0.45 s pulse goes to 0.45. A tag
## stun is FIVE SECONDS — too long for a flash, far too punchy to hold at flash strength,
## and too important to drop to 0.16, because it is the single biggest moment in the
## defender's game.
##
## The reference image resolves it, and that is the reason it was worth following: put
## the opacity where the player is NOT looking. The frost is heavy at the frame and clear
## through the middle, so it can be genuinely strong without hiding the round the stunned
## player is stuck watching. There is no `modulate` alpha ceiling here at all — the
## shader's own `coverage` is the dial, and the centre stays readable at coverage 1.0.
##
## ⚠️ IT RECEDES. `coverage` tracks the stun down, so the ice visibly retreats toward the
## frame as the five seconds run out. That is the accessible-status requirement to signal
## when an effect is ending, and it is a channel the player already has their eyes on —
## unlike the countdown bar in the status stack, which is correct and easy to miss.
const FROST_RAMP_IN: float = 0.14
const FROST_RAMP_OUT: float = 0.5
## Coverage is held at full until the stun has this long left, then thaws to zero.
const FROST_THAW_TIME: float = 1.6

var _frost_coverage: float = 0.0

func _refresh_frost(local_char: CharacterBase, delta: float) -> void:
	var target := 0.0
	if local_char != null and is_instance_valid(local_char) \
			and local_char.state == CharacterBase.State.STAGGERED:
		# ⚠️⚠️ NOT ALWAYS THIS PEER'S OWN BODY ANY MORE. `local_char` used to be, always
		# — this function's only caller was the player's own crosshair block, so
		# `stagger_time_left()` could be trusted unconditionally. `Master_Prompt_
		# Spectator_Player_POV.md` § C.4 added a second caller: a spectator's borrowed
		# POV, which is a body THIS peer very much does not simulate over the network.
		# `_staggered_time_left` is deliberately not replicated (see `character_visual.
		# gd::_process_frost()`'s own header — the same fix, mirrored here) so
		# `stagger_time_left()` returns a bare 0 there, and reading that as "0 seconds
		# left" would thaw the frost on the very frame it should be at its heaviest.
		# Hold at full until a REAL countdown says otherwise, same rule that function
		# already uses.
		target = 1.0
		var left := local_char.stagger_time_left()
		if left > 0.0 and left < FROST_THAW_TIME:
			target = left / FROST_THAW_TIME
	var rate := FROST_RAMP_IN if target > _frost_coverage else FROST_RAMP_OUT
	_frost_coverage = move_toward(_frost_coverage, target, delta / maxf(rate, 0.001))
	# Hidden outright at zero rather than left drawing a fully transparent full-screen
	# quad every frame for the whole match.
	frost_vignette.visible = _frost_coverage > 0.001
	if frost_vignette.visible:
		var material := frost_vignette.material as ShaderMaterial
		material.set_shader_parameter("coverage", _frost_coverage)
		# ⚠️ THE SHADER CANNOT WORK THIS OUT FOR ITSELF. `UV` is 0..1 on both axes
		# whatever the window's shape, so without the real ratio the frost band is ~1.8x
		# thicker in pixels down the sides than across the top on 16:9 — rendered and
		# confirmed. Pushed every frame rather than on `resized` because the window can
		# also change shape via the fullscreen toggle, which fires no resize on this node.
		var size := frost_vignette.size
		if size.y > 0.0:
			material.set_shader_parameter("aspect", size.x / size.y)

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
	# ⚠️⚠️ MOVED OFF DEAD CENTRE 2026-08-02, ON A PLAYTEST REPORT. 🧑, with a
	# first-person screenshot of the line sitting across the middle of the frame:
	# *"You are vulnerable not in middle"*.
	#
	# The original instruction was *"directly below the crosshair"* and that is where
	# it went, 34 px under centre. In first person the thing you are looking at while
	# this warning is live is the slipper you are bending down to pick up, which is
	# the bottom-middle of the screen — so the one line that means "you are about to
	# lose 5 seconds" was drawn over the exact object it is about. It is bottom-centre
	# now: still on the centre line the eye tracks, out of the sightline entirely.
	#
	# ⚠️ ABOVE `ReadyPrompt`'S BAND AND INSIDE THE 64 px BOTTOM SAFE BAND. The prompt
	# occupies -158..-118 and is hidden during a live round (`show_ready_prompt`), and
	# `YouCard.tscn`'s header records why nothing bottom-anchored may sit closer than
	# 64 px to the frame edge. -104..-64 clears both.
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.position = Vector2(-200.0, -104.0)
	label.custom_minimum_size = Vector2(400.0, 0.0)
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
	var states: Array[Dictionary] = []
	var cooldowns: Array[Dictionary] = []
	if local_char != null and is_instance_valid(local_char):
		# ⚠️ VULNERABLE IS FILTERED OUT HERE, NOT REMOVED FROM `status_effects()`.
		# 🧑 2026-08-01: *"Remove the vulnerable timer bar and replace it with static
		# text directly below the crosshair"* — `_refresh_vulnerable_text()` draws it
		# now. The RULE stays where it was: `is_taggable()` is read by the tag, by the
		# vignette and by that label, and `status_effects()` is still the honest list
		# of what is live on this body.
		for effect in local_char.status_effects():
			var label := String(effect.get("label", ""))
			if label == "VULNERABLE":
				continue
			# ⚠️ THE SUFFIX IS THE ROUTING KEY, and it is deliberately the LABEL rather
			# than a new field on the dictionary. `status_effects()` belongs to
			# `character_base.gd`, which this lane does not own; a presentation split
			# should not need a schema change in somebody else's file. "SHOVE CD",
			# "LUNGE CD" and "THROW CD" are the three cooldowns and they all end the
			# same way, so a new cooldown routes correctly the day it is added.
			if label.ends_with(" CD"):
				cooldowns.append(effect)
			else:
				states.append(effect)
	_fill_status_side(_ensure_status_root(false), _status_rows_left, states, false)
	_fill_status_side(_ensure_status_root(true), _status_rows_right, cooldowns, true)


## One side of the split. `right_side` only decides text alignment — everything
## else about a row is identical, which is the point of routing rather than
## building two different widgets.
func _fill_status_side(root: VBoxContainer, rows: Array[Control],
		effects: Array[Dictionary], right_side: bool) -> void:
	var wanted: int = mini(effects.size(), STATUS_ROW_LIMIT)
	while rows.size() < wanted:
		var built := _build_status_row()
		root.add_child(built)
		rows.append(built)
	for i in rows.size():
		var row: Control = rows[i]
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
		# ⚠️ A ROW WITH NO COUNTDOWN IS A REAL CASE, NOT A BUG. An effect that lasts
		# as long as the player chooses reports `seconds` 0 and draws as a solid bar
		# with no timer; printing "0.0s" would read as already expired.
		var timed := seconds > 0.0
		label.text = ("%s  %.1fs" % [text, seconds]) if timed else text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right_side 			else HORIZONTAL_ALIGNMENT_LEFT
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
	# § THE STUN FROST rides along: it is a transient like the flash above, and a
	# spectator has no stun of their own to be told about.
	frost_vignette.visible = false
	_frost_coverage = 0.0
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
	# ⚠️⚠️ WHO YOU ARE WATCHING, ON SCREEN, WHENEVER A UNIT IS BEING SPECTATED.
	# `Master_Prompt_Updated_Spectator.md` § B.3. Top of the screen rather than the bottom
	# strip the other two labels share, so it reads at a glance while flying and does not
	# crowd the wheel/legend/round line already anchored to the bottom. Text and visibility
	# are set every frame in `_refresh_spectator_panel()`, off `SpectatorCamera.
	# spectated_label()` — never cached here, so a role rotation or a mid-match joiner
	# taking a bot's name is reflected the same frame the camera notices it.
	_spectator_target_name = _build_spectator_label(16, 54, 26, UiTheme.CREAM,
		Control.PRESET_TOP_WIDE)
	# The clean feed is only discoverable if it is written down where the operator is
	# already reading. Appended here rather than inside `SpectatorCamera.controls_text()`
	# because that static describes the CAMERA's keys and this one is the HUD's.
	# ⚠️ ASKED, NOT HARDCODED. `clean_feed` is rebindable in Settings, so a literal "H"
	# here would start lying the moment anybody changed it — and this legend is the only
	# place the control is advertised on screen.
	legend.text += "   ·   %s clean feed" % SettingsManager.get_binding_display_name("clean_feed")
	set_process_input(true)

## ---------------------------------------------------------------------------
## ⚠️⚠️ THERE IS A WAY OUT NOW, AND `enter_spectator_mode()`'s *"there is no leaving it"*
## ABOVE IS WHY IT NEEDED WRITING RATHER THAN JUST CALLING SOMETHING.
##
## `NetworkManager`'s § MID-MATCH ARRIVALS parks a newcomer as a spectator and PROMOTES it
## into a seat at the next role rotation, so this HUD now has to be able to become a
## player's again. Called from `main.gd::_exit_spectator_mode`, and from nowhere else.
##
## ⚠️ IT RESTORES ONLY THE ALWAYS-ON GAMEPLAY ELEMENTS. `downed_flash`, `ready_prompt` and
## `ready_objective_row` are TRANSIENTS — each is shown by its own driver on its own event
## (`show_ready_prompt`, the downed signal, `_rpc_ready_phase`) — and blanket-showing them
## here would put a stale ready prompt over a live round. Their drivers were free to fire
## while this peer was watching and will fire again; the four below have no driver because
## they are simply meant to be on.
##
## ⚠️ AND IT LIFTS THE CLEAN FEED. `set_clean_feed(true)` hides `self`, and a promoted player
## who had pressed H would otherwise walk into a live round with no HUD at all and no way
## back — `_input()` returns immediately once `_spectating` is false, so the key that turned
## it off has just stopped working.
## ---------------------------------------------------------------------------
func exit_spectator_mode() -> void:
	if not _spectating:
		return
	set_clean_feed(false)
	_spectating = false
	_spectator_camera = null
	for label in [get_node_or_null("SpectatorLegend"), _spectator_status, _spectator_round,
			_spectator_target_name]:
		if label != null and is_instance_valid(label):
			label.queue_free()
	_spectator_status = null
	_spectator_round = null
	_spectator_target_name = null
	you_card.visible = true
	crosshair.visible = true
	lata_card.visible = true
	offscreen_indicators.visible = true
	set_process_input(false)

var _spectating: bool = false
var _spectator_camera: SpectatorCamera = null
var _spectator_status: Label = null
var _spectator_round: Label = null
var _spectator_target_name: Label = null

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE CLEAN FEED — `H`. 🧑 2026-07-31: *"allow option to remove everything in
## screen to js do record the game bcz we only added spectator for the video record"*,
## and then, explicitly: *"the remove hud is only for spectator okay, no one else."*
##
## SPECTATOR ONLY, AND THAT IS ENFORCED RATHER THAN DOCUMENTED. `_input()` below
## returns immediately unless `_spectating`, so a player in a live match cannot hide
## their own timer, status stack or charge meters by leaning on a key — which would be
## a competitive advantage handed out by a typo.
##
## ⚠️⚠️ IT HIDES `self`, AND IT USED TO HIDE THE CHILDREN — THE CHANGE IS THE FIX.
## This block used to say hiding the root "risks a one-way trip: input delivery to a
## hidden Control is not something to bet an operator's recording session on", and
## walked `get_children()` instead. That caution was wrong on the fact and it cost the
## feature: `_input()` is a Node callback and fires regardless of `visible` — only
## mouse picking and focus are given up by a hidden Control, and `clean_feed` is a key.
## Measured on this engine build, hidden root, event delivered.
##
## What the per-child walk actually bought was a SNAPSHOT taken the instant H was
## pressed, so every transient that shows itself later — toast, countdown, downed
## flash, lata card, ready row, score rows — came back over a clean plate. 🧑 reported
## it: *"theres popup huds midgame and shi"*. A hidden parent is a state and cannot
## be out-voted by a child setting its own `visible`.
##
## ⚠️ AND NOTHING NEEDS RESTORING NOW. The old code recorded prior visibility because
## it OVERWROTE it, and had to avoid blanket-showing on the way back —
## `enter_spectator_mode()` has already hidden the YOU card, the crosshair, the lata
## card and the ready prompt, and a spectator must not get those back. Hiding the root
## overwrites nothing, so that whole class of bug is gone rather than handled.
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
	# ⚠️ BEFORE THE `_spectating` GATE. Everything below this line is the spectator's
	# clean-feed key and returns early for an ordinary player — which is exactly who
	# the emote wheel is for.
	if _handle_emote_input(event):
		return
	if not _spectating:
		return
	# `allow_echo` defaults false, which is the guard the first version spelled out by
	# hand. Modifiers are deliberately not matched exactly — an operator with a finger
	# already on Shift should still get their clean plate.
	if not event.is_action_pressed("clean_feed"):
		return
	get_viewport().set_input_as_handled()
	set_clean_feed(not _clean_feed)

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE EMOTE WHEEL'S KEY. Hold to open, release to play the highlighted slice.
##
## ⚠️ IT LIVES ON THE HUD RATHER THAN ON `character_base.gd`, deliberately. The
## wheel is a screen, and this file already owns every screen the player sees mid
## match AND already resolves "which body is mine" through `you_card`. Putting the
## open/close on the character would make a second answer to that question and give
## the four bodies in a local match four wheels between them.
##
## Returns true when it consumed the event, so `_input` above can stop.
func _handle_emote_input(event: InputEvent) -> bool:
	if emote_wheel == null:
		return false
	# ⚠️ SPECTATORS CANNOT EMOTE, BUT THEY SEE EVERY EMOTE. 🧑 2026-08-04: *"make
	# sure spectators dont emote HAHA but they can see emotes"*. Both fall out of
	# where the two halves live: opening the wheel is gated HERE, on the local
	# screen, while the clip itself is replicated by `character_base.gd::_rpc_emote`
	# onto every peer's copy of that body — so a spectator watching someone else
	# dance is just watching a body animate, exactly like a walk cycle. A spectator
	# also has no `get_local_character()` to emote WITH, so this gate is the second
	# lock rather than the only one.
	#
	# ⚠️ AND THE CLEAN FEED STILL HIDES EVERYTHING. *"make sure huds still dont show
	# up for spectator if they choose to turn it off"*. The wheel is a CHILD of this
	# HUD, and `set_clean_feed()` hides this whole Control rather than each child —
	# so a hidden parent means the wheel cannot draw, by construction, and it needs
	# no entry in any restore list. That is the same property the comment on
	# `set_clean_feed` explains for the toast and the countdown.
	#
	# The wheel closes without playing if it is somehow up when it should not be —
	# a pause, a round end, spectating, or the local body going away mid-hold.
	var allowed := not _spectating and not get_tree().paused
	if not allowed:
		if emote_wheel.is_open():
			emote_wheel.close(false)
		return false
	if event.is_action_pressed("emote_wheel", false, true):
		var local_char := you_card.get_local_character()
		# ⚠️ ASKED BEFORE OPENING, NOT BEFORE PLAYING. A wheel that opens and then
		# refuses on release reads as a broken button; one that never opens reads as
		# "not now", which is the truth.
		if local_char == null or not is_instance_valid(local_char) or not local_char.can_emote():
			return false
		emote_wheel.open()
		get_viewport().set_input_as_handled()
		return true
	if event.is_action_released("emote_wheel"):
		if not emote_wheel.is_open():
			return false
		emote_wheel.close(true)
		get_viewport().set_input_as_handled()
		return true
	return false

func _on_emote_chosen(id: String) -> void:
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		return
	# `try_emote` re-checks `can_emote()` and the authority. Between opening the
	# wheel and releasing it the player can have been tagged, knocked down or had
	# the round end under them.
	local_char.try_emote(id)

## Public so `spec_probe` can drive it without synthesising a key event.
func set_clean_feed(on: bool) -> void:
	if on == _clean_feed:
		return
	_clean_feed = on
	_apply_clean_feed_to_world(on)
	# ⚠️⚠️ THE ROOT IS HIDDEN, NOT EACH CHILD, AND THE PER-CHILD VERSION WAS A BUG.
	# 🧑 2026-08-02: *"clicking H doesnt hide all huds for spectator ... theres popup
	# huds midgame and shi"*. Correct, and the old code could not have done otherwise:
	# it walked `get_children()` ONCE, at the moment H was pressed, recorded each
	# child's `visible` and set it false. That is a snapshot, not a state.
	#
	# Every transient on this HUD shows ITSELF later and unconditionally — the toast,
	# the countdown, the downed flash, the lata card, the ready row, the score rows.
	# Each one is a plain `visible = true` on a timer or a signal, so anything that
	# fired after H went straight back on screen over a "clean" plate, which is the
	# one thing a camera operator must be able to rely on mid-take.
	#
	# Hiding this Control instead makes the clean feed a STATE: a hidden parent means
	# no descendant draws whatever it sets on itself, so a popup that fires during a
	# clean feed stays dark and is simply there again when the operator toggles back.
	# That also deletes the restore bookkeeping outright — nothing is overwritten, so
	# nothing has to be put back, and `enter_spectator_mode()`'s own hiding of the YOU
	# card, crosshair, lata card and ready prompt survives untouched underneath.
	#
	# ⚠️ `_input()` STILL FIRES WHILE HIDDEN, which is what makes the toggle reversible.
	# Input callbacks are Node-level and do not care about `visible`; it is only mouse
	# picking and focus that a hidden Control gives up, and `clean_feed` is a key.
	visible = not on

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
func _build_spectator_label(top: float, bottom: float, size: int, colour: Color,
		preset: Control.LayoutPreset = Control.PRESET_BOTTOM_WIDE) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", UiTheme.INK)
	label.add_theme_constant_override("outline_size", TEXT_OUTLINE)
	label.set_anchors_preset(preset)
	label.offset_top = top
	label.offset_bottom = bottom
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _refresh_spectator_panel() -> void:
	if _spectator_status != null and is_instance_valid(_spectator_status):
		_spectator_status.text = ("" if _spectator_camera == null
			or not is_instance_valid(_spectator_camera) else _spectator_camera.status_text())
	if _spectator_target_name != null and is_instance_valid(_spectator_target_name):
		var label_text := ("" if _spectator_camera == null
			or not is_instance_valid(_spectator_camera)
			else _spectator_camera.spectated_label())
		_spectator_target_name.text = label_text
		_spectator_target_name.visible = label_text != ""
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
	_spectator_round.text = "ROUND %d/%d   ·   TAYA  %s   ·   LATA %s   ·   LEADER  %s  %d" % [
		maxi(1, MatchManager.round_number), MatchManagerScript.ROUNDS,
		seat_name(MatchManager.defender_slot), "UP" if up else "DOWN",
		seat_name(leader), MatchManager.score_for(leader)]

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
	#
	# 4.4, 2026-08-01 — now ALSO the announcer's "Tatlo! Dalawa! Isa! Simula!".
	# ⚠️ Same one call as before, and the SFX behaviour is byte-for-byte
	# unchanged: `play_countdown()` wraps the exact `play("countdown_go" if ...)`
	# line this used to be. It exists because `countdown_tick` is the same string
	# for 3, 2 and 1, so AudioManager cannot tell them apart from the inside, and
	# `text` is the only place the number exists. Adding the mapping THERE rather
	# than a second `AudioManager.play_vo(...)` line here keeps every audio
	# decision in 🔊 `build sound`'s own file and leaves this one at one line.
	AudioManager.play_countdown(text)
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
	var taya_name := seat_name(defender_slot)
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
	# same theme what is that white box"*.
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
		_widen_name_cell(row.get_node_or_null("Name") as Label)
		_build_role_cell(row)
		_score_rows.append(row)

## ⚠️⚠️ "TAYA" IS ITS OWN CELL NOW, BECAUSE GLUED TO THE NAME IT READ AS PART OF THE
## NAME. 🧑 2026-08-02, with a screenshot of the board: *"inday taya makes it look like
## inday taya is her name, not that she is TAYA — make this implementation better"*.
##
## Exactly right, and the old row could not have read any other way: `"%s%s" % [name,
## "  TAYA"]` is ONE string in ONE Label, in ONE colour, at ONE size. Two spaces are not
## a grammar. Every roster name is uppercase (`display_name()` shouts them all — see its
## note), several of them are two words ("LOLA PACING"), and the game has a character
## called INDAY, so "INDAY TAYA" is indistinguishable from a two-word name because at the
## level of pixels it IS one.
##
## A separate Label can differ in the three ways that carry the meaning: it is smaller,
## it is muted where the name is bright, and it sits in its own column so it starts at
## the same x on whichever row holds it. That is a role BADGE — the thing the string was
## always trying to be.
##
## ⚠️ MUTED CREAM, NOT `DEFENSE` BLUE, AND THE OBVIOUS CHOICE WAS THE WRONG ONE. §4.2's
## rule is blue = defence, and the taya's NAME is already painted blue eight lines into
## `_refresh_scoreboard()` — so a blue badge beside it is the same colour, at nearly the
## same size, immediately after the name. That is the reported bug again in a new colour.
## The badge is an annotation ON the row, and it has to look like one.
##
## ⚠️ BUILT IN CODE AND MOVED TO INDEX 1, rather than authored in `HUD.tscn`. The four
## rows are authored there (§ CHECKLIST 1.1) and a new child would land AFTER `Score`,
## which puts the badge on the wrong side of the number. `move_child` is the one line
## that fixes that, and it keeps the scene's four rows identical to each other.
##
## ⚠️ A FIXED WIDTH, ALWAYS PRESENT, NEVER HIDDEN. The badge is empty text on three rows
## out of four; hiding the Label instead would let those three rows' scores slide left
## and the column of numbers — the entire point of the board — would stop being a column.
## Same reasoning as `_widen_name_cell`, one cell over.
func _build_role_cell(row: Control) -> void:
	if row.get_node_or_null("Role") != null:
		return
	var badge := Label.new()
	badge.name = "Role"
	badge.add_theme_font_size_override("font_size", TAYA_BADGE_FONT_SIZE)
	badge.add_theme_color_override("font_color", UiTheme.CREAM_MUTED)
	badge.add_theme_color_override("font_outline_color", UiTheme.INK)
	badge.add_theme_constant_override("outline_size", 5)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := badge.get_theme_font("font")
	var needed := 54.0
	if font != null:
		needed = ceilf(font.get_string_size(
			TAYA_BADGE, HORIZONTAL_ALIGNMENT_LEFT, -1, TAYA_BADGE_FONT_SIZE).x)
	badge.custom_minimum_size.x = needed
	row.add_child(badge)
	row.move_child(badge, 1)

## Smaller than the 20 px name beside it, because a badge that matches the name's weight
## is a second name. Small enough to read as an annotation, large enough to survive being
## drawn over the road.
const TAYA_BADGE_FONT_SIZE: int = 15
const TAYA_BADGE: String = "TAYA"

## ⚠️⚠️ THE NAME COLUMN IS SIZED FROM THE CAP AND THE FONT, NOT TYPED IN. 🧑
## 2026-08-02: *"make sure the 14 character names fit in the hud and if the name is
## too short like CP it doesnt look ugly"*. Both ends, and they pull opposite ways:
##
##   TOO LONG — `HUD.tscn` authors this cell at 132 px, which was chosen when every
##   row read "P1".."P4". A 14-character name (`CharacterRoster.NAME_MAX`) plus the
##   trailing "  TAYA" needs roughly 190 px at font size 20, so the Label would
##   overrun its column, push the right-aligned score out and ruin the one thing a
##   scoreboard is for — four numbers readable at a glance, in a line.
##
##   TOO SHORT — a 2-character name like CP must NOT let the column collapse, or the
##   score slides left on that row alone and the numbers stop forming a column. A
##   FIXED width is what serves both: nothing moves, whatever the name.
##
## So the width is measured off the real theme font at the real size, for the longest
## string this game can now produce. Typing "190" here would be correct until somebody
## changes the font size in the scene, and then silently wrong — this cannot drift,
## because it is derived from the same constant the probe enforces.
##
## "W" is the widest glyph in most faces, so `NAME_MAX` of them is the true worst case
## rather than an average-case guess that a name like MMMMMM would beat.
func _widen_name_cell(cell: Label) -> void:
	if cell == null:
		return
	var font := cell.get_theme_font("font")
	var font_size := cell.get_theme_font_size("font_size")
	if font == null:
		return
	# ⚠️ NO LONGER `+ "  TAYA"`. The badge is its own cell with its own width
	# (`_build_role_cell`), so reserving room for it here would reserve it twice and
	# push the score column off the panel on every row.
	var worst := "W".repeat(CharacterRoster.NAME_MAX)
	var needed := font.get_string_size(worst, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	cell.custom_minimum_size.x = maxf(cell.custom_minimum_size.x, ceilf(needed))

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
	# ⚠️⚠️ THE NAMES ARE PART OF THE STAMP, AND LEAVING THEM OUT WAS A REAL BUG.
	# This gate exists so a scoreboard is not rebuilt every frame, and it keyed on
	# scores and the taya alone — which was complete right up until a row could change
	# for a THIRD reason. Bots took their characters' names on 2026-08-02, so a seat
	# changing hands (a disconnect converting to AI, a rejoin reclaiming it, the Tab
	# switcher) renames a row without touching a score: the board would have gone on
	# showing the name of the human who left until somebody happened to score.
	#
	# `display_name()` is cheap and this is four calls on a change check that already
	# stringifies an array, so the honest fix is to stamp what is actually drawn.
	var names := PackedStringArray()
	for slot in range(MatchManagerScript.PLAYER_COUNT):
		names.append(seat_name(slot))
	var stamp := "%s|%d|%s" % [str(MatchManager.scores), MatchManager.defender_slot,
		"|".join(names)]
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
		# \u26A0\uFE0F\u26A0\uFE0F NO LEADING BULLET \u2014 THE COLOUR IS THE MARK. \uD83E\uDDD1 2026-08-02: *"move the
		# arrow to the right on the p1p2p3p4 top left / make it so that it js
		# highlights / the arrow makes the names of the characters not aligned"*.
		#
		# The report is exactly right and the cause is off-by-one: the prefix was
		# `"\u25B8"` for your own row against `"  "` for every other, which is ONE
		# character versus TWO, so all four names started at a different x and the
		# column read as ragged. It was invisible while every row said "P1".."P4" and
		# obvious the moment the names became MARING and LOLA PACING.
		#
		# Nothing is lost by deleting it: `slot == mine` already recolours this row to
		# `UiTheme.HIGHLIGHT` six lines below, which is the same fact said in the way
		# that costs no width. The taya is marked by its own cell, for the same reason
		# and one column over — see `_build_role_cell()`.
		# ⚠️ THE NAME CELL HOLDS THE NAME AND NOTHING ELSE — see `_build_role_cell()` for
		# why "  TAYA" cannot live in this string.
		name_label.text = seat_name(slot)
		var badge := row.get_node_or_null("Role") as Label
		if badge != null:
			badge.text = TAYA_BADGE if is_taya else ""
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
	# ⚠️ A SPECTATOR HAS NO ROLE FOR THIS CARD TO DESCRIBE, AND `_process` CALLS THIS
	# EVERY FRAME REGARDLESS OF `_spectating`. `enter_spectator_mode()` hides it once at
	# entry; without this gate the very next frame the round is live, this function
	# below re-asserts `visible = true` over it — a spectator only, not a player, since
	# `enter_spectator_mode` is the only thing that ever hides it in the first place.
	# Caught by `spec_probe --solo`: "§2.5 the lata card is gone — FAIL".
	if lata == null or not RoundManager.round_active or _spectating:
		lata_card.visible = false
		return
	lata_card.visible = true
	# ⚠️ THE UPRIGHT LINE CHANGES ONLY WHEN THE LATA TIPS, which is a handful of times
	# a round — but the text and the colour override below it were both rewritten every
	# frame. Gated on the bool itself rather than on a stamp string, because that is the
	# entire input to both writes. See the ⚠️⚠️ block on `_timer_seconds_shown`.
	if _lata_upright_shown != int(lata.is_upright):
		_lata_upright_shown = int(lata.is_upright)
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
	# ⚠️ The two live hints ("RESETTING 42%", "THROW LOCKED 1.2s") DO change most frames,
	# and this guard deliberately does not try to be clever about them — it compares the
	# finished string, so those two still write when they tick and the other four states,
	# which are constant for as long as they hold, write once.
	if line != _lata_hint_shown:
		_lata_hint_shown = line
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
		show_toast("%s KNOCKED THE LATA DOWN" % [seat_name(by_slot)], 1.2)

func _on_lata_restored() -> void:
	show_toast("LATA IS BACK UP", 1.2)

func _on_attacker_tagged(defender_slot: int, victim_slot: int) -> void:
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		return
	if local_char.player_slot == victim_slot:
		show_toast("TAGGED  ·  BACK TO THE SAFE ZONE", 2.0)
	elif local_char.player_slot == defender_slot:
		show_toast("TAG  ·  %s" % [seat_name(victim_slot)], 1.4)

## ⚠️⚠️ THE NAME FOR A SEAT WHEN ONLY A SLOT NUMBER IS IN HAND. 🧑 2026-08-02:
## *"make sure the bot names show up everywhere they have to / Not p1 p2 p3 p4"*.
##
## Three rows on this HUD built their own "P%d" out of a slot and never asked the
## character at all — the spectator round line's TAYA and LEADER, the "knocked the
## lata down" toast and the tag toast — so they kept printing P2 after bots learned
## their names. Two others already resolved the slot by hand, identically, which is
## how the three that did not went unnoticed.
##
## One function now, for the same reason `CharacterBase.display_name()` is one
## function: a seat cannot be called two different things on two rows of one screen.
## The bare seat label survives only as the genuinely nameless case — a slot with no
## character in it, which happens between a disconnect and the AI conversion.
static func seat_name(slot: int) -> String:
	var who := RoundManager.player_at(slot)
	return who.display_name() if who != null else "P%d" % [slot + 1]
