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
@onready var downed_flash: ColorRect = %DownedFlash
@onready var toast_label: Label = %ToastLabel
@onready var round_banner_label: Label = %RoundBannerLabel
@onready var you_card: YouCard = %YouCard
@onready var crosshair: Control = %Crosshair

var _toast_time_left: float = 0.0

func _ready() -> void:
	MatchManager.round_started.connect(_on_round_started)
	MatchManager.match_won.connect(_on_match_won)
	downed_flash.visible = false
	toast_label.visible = false
	round_banner_label.visible = false
	# Initialise panels from current MatchManager state so pips and colours are
	# correct on load (e.g. a late-joining peer, or a match already in progress).
	set_round_display(MatchManager.round_number, MatchManager.team_a_is_can)
	# Build stamp in-match too — outlined HudCaption reads over the 3D scene.
	GameVersion.attach_to(self, true)

func _process(delta: float) -> void:
	var t := int(ceil(RoundManager.time_left))
	timer_label.text = "%02d:%02d" % [t / 60, t % 60]
	# Poll pip fill each frame — lightweight (just stylebox swaps on 6 Panel nodes).
	_fill_pips(team_a_pips_box, MatchManager.team_a_wins)
	_fill_pips(team_b_pips_box, MatchManager.team_b_wins)
	if _toast_time_left > 0.0:
		_toast_time_left -= delta
		if _toast_time_left <= 0.0:
			toast_label.visible = false
	# §4.4 crosshair: visible in FPP (Person) only. Reads the you_card's cached
	# character so the scan logic stays in one place (you_card.gd::_find_local_character).
	var local_char := you_card.get_local_character()
	crosshair.visible = local_char != null and is_instance_valid(local_char) and local_char.is_person

## Paints the first `filled` pips in a HBoxContainer of Panel nodes as filled
## (CARD fill, INK border) and the rest as empty (transparent fill, INK border).
## 12×12 square StyleBoxFlat, 3 px INK border, 2 px separation (set on the HBox).
func _fill_pips(container: HBoxContainer, filled: int) -> void:
	for i in container.get_child_count():
		var pip: Control = container.get_child(i)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(0)
		sb.set_border_width_all(3)
		sb.border_color = UiTheme.INK
		sb.bg_color = UiTheme.CARD if i < filled else Color(0.0, 0.0, 0.0, 0.0)
		pip.add_theme_stylebox_override("panel", sb)

## B-15/B-35: brief on-screen call-out for a locally-relevant event that
## isn't otherwise visible on the HUD, e.g. "OUT OF BOUNDS" from the
## KillPlane respawn (see main.gd::_on_character_respawned).
func show_toast(text: String, duration: float = 1.5) -> void:
	toast_label.text = text
	toast_label.visible = true
	_toast_time_left = duration

## Item 10: shown for the whole round-intermission gap (main.gd::
## _on_round_intermission_started), cleared by _on_round_started once the
## next round actually begins. Placeholder styling — U-3 replaces this with
## the moodboard's animated role-swap card.
func show_round_banner(text: String) -> void:
	round_banner_label.text = text
	round_banner_label.visible = true

func _on_round_started(round_number: int, team_a_is_can: bool) -> void:
	set_round_display(round_number, team_a_is_can)
	round_banner_label.visible = false # item 10: clear the intermission banner once the fight is on

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
	_fill_pips(team_a_pips_box, MatchManager.team_a_wins)
	_fill_pips(team_b_pips_box, MatchManager.team_b_wins)

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
## LATA card display implemented in U-1 step 2.
func set_dents(current: int, max_dents: int) -> void:
	pass
