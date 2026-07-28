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
@onready var team_a_pips_box: HBoxContainer = %TeamAPipsBox
@onready var team_b_pips_box: HBoxContainer = %TeamBPipsBox
@onready var lata_card: PanelContainer = %LataCard
@onready var dent_pips_box: HBoxContainer = %DentPipsBox
@onready var dent_text_label: Label = %DentTextLabel
@onready var downed_flash: ColorRect = %DownedFlash
@onready var toast_label: Label = %ToastLabel
@onready var ready_prompt: Label = %ReadyPrompt
@onready var countdown_label: Label = %CountdownLabel
@onready var you_card: YouCard = %YouCard
@onready var crosshair: Control = %Crosshair
@onready var offscreen_indicators: OffscreenIndicators = %OffscreenIndicators

var _toast_time_left: float = 0.0
var _pulse_tween: Tween = null
var _countdown_tween: Tween = null

func _ready() -> void:
	MatchManager.round_started.connect(_on_round_started)
	MatchManager.match_won.connect(_on_match_won)
	downed_flash.visible = false
	toast_label.visible = false
	lata_card.visible = false
	# Keep pivot at the TimerCard's centre so the pulse tween scales from the middle.
	# Connect to resized so this stays correct if the card ever changes size.
	timer_card.resized.connect(func(): timer_card.pivot_offset = timer_card.size / 2)
	# Initialise panels from current MatchManager state so pips and colours are
	# correct on load (e.g. a late-joining peer, or a match already in progress).
	set_round_display(MatchManager.round_number, MatchManager.team_a_is_can)
	# Build stamp in-match too — outlined HudCaption reads over the 3D scene.
	GameVersion.attach_to(self, true)

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
		timer_label.remove_theme_color_override("font_color")
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
	crosshair.visible = local_char != null and is_instance_valid(local_char) and local_char.is_person
	# 3.4: same cached character, no second scan.
	offscreen_indicators.update(local_char)

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

func _fill_pips(container: HBoxContainer, filled: int, fill_color: Color = UiTheme.DEFENSE) -> void:
	var key := container.get_instance_id()
	var stamp := "%d:%s" % [filled, fill_color.to_html(false)]
	if _pip_cache.get(key, "") == stamp:
		return
	_pip_cache[key] = stamp
	for i in container.get_child_count():
		var pip: Control = container.get_child(i)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(0)
		sb.set_border_width_all(3)
		sb.border_color = UiTheme.INK
		sb.bg_color = fill_color if i < filled else Color(0.0, 0.0, 0.0, 0.0)
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
func show_ready_prompt(active: bool) -> void:
	ready_prompt.visible = active

## 2026-07-28 — "add a 3 2 1 timer before each match starts too, think about
## how to make it look good." One call per tick ("3", "2", "1", "GO!"); the
## caller (main.gd) times the calls a second apart. Each tick pops in oversize
## and settles to normal scale rather than just appearing, which reads far
## more like a countdown than a static label swap would — the punch is the
## whole effect at this size. HIGHLIGHT colour matches the same urgency tint
## the round timer itself uses under 15s, so it reads as "the same game
## system," not a one-off UI element.
func show_countdown_tick(text: String) -> void:
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
	round_label.text = "Round %d / 5" % round_number
	if team_a_is_can:
		# Team A holds the can this round → Team A defends, Team B attacks.
		team_a_label.text = "A · DEFENSE"
		team_b_label.text = "B · OFFENSE"
		top_left_panel.theme_type_variation = &"DefenseCard"
		top_right_panel.theme_type_variation = &"OffenseCard"
	else:
		# Team A throws the slipper this round → Team A attacks, Team B defends.
		team_a_label.text = "A · OFFENSE"
		team_b_label.text = "B · DEFENSE"
		top_left_panel.theme_type_variation = &"OffenseCard"
		top_right_panel.theme_type_variation = &"DefenseCard"
	_fill_pips(team_a_pips_box, MatchManager.team_a_wins, _pip_color(true))
	_fill_pips(team_b_pips_box, MatchManager.team_b_wins, _pip_color(false))

## Q-5: a joining peer never sees round_started for the round already in
## progress (B-29) — main.gd::_sync_state_to_late_joiner calls this next to
## set_round_display() so the YOU card isn't blank until the next round.
func refresh_you_card() -> void:
	you_card.refresh()

func _on_match_won(winning_team: int) -> void:
	round_label.text = "MATCH WON"

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
