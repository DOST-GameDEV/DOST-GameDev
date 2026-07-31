extends Control
class_name RoleSwapCard

## U-3: The moodboard role-swap intermission card (Dev_Plan.md §4.6).
## Connects directly to MatchManager signals — drop the scene into HUD.tscn
## and it drives itself.
##
## Timeline (per §4.6):
##   0.0s  round_intermission_started fires → show result banner
##   1.2s  panels slide in from off-screen and recolour to incoming roles
##   3.5s  "ROUND N — FIGHT!" wipe label briefly shown
##   ~4.0s round_started fires → card hides, panels reset for next time
##
## The world reset at 3.0s already happens in main.gd::_on_round_intermission_started
## (which fires on the same signal) — this card does not touch it.

@onready var reason_label: Label = %ReasonLabel
@onready var result_label: Label = %ResultLabel
@onready var left_panel: PanelContainer = %LeftPanel
@onready var right_panel: PanelContainer = %RightPanel
@onready var team_a_label: Label = %TeamALabel
@onready var role_arrow_a: Label = %RoleArrowA
@onready var team_b_label: Label = %TeamBLabel
@onready var role_arrow_b: Label = %RoleArrowB
@onready var fight_label: Label = %FightLabel

func _ready() -> void:
	MatchManager.round_intermission_started.connect(_on_intermission_started)
	MatchManager.round_started.connect(_on_round_started)
	_apply_wood_skin()

## The card's own share of the 2026-07-30 restyle (B-143). Same face and the same
## `UiTheme.wood_style()` source as `hud.gd::_apply_wood_skin()` — this is the screen the
## HUD hands over to between rounds, so it was the most visible remaining place where the
## old near-white `card_style` cards contradicted the menu.
func _apply_wood_skin() -> void:
	# Display type over a dimmed 3D scene, so both banner lines get the same INK outline
	# the HUD's floating text uses rather than a plate. See HUD.tscn's ReadyObjectiveRow.
	for label in [reason_label, result_label, fight_label]:
		label.add_theme_constant_override("outline_size", 10)
		label.add_theme_color_override("font_outline_color", UiTheme.INK)
	result_label.add_theme_color_override("font_color", UiTheme.CREAM)
	fight_label.add_theme_color_override("font_color", UiTheme.AMBER)

## One swap panel, on the same wood-with-a-role-border face as the HUD's team cards, so
## the intermission looks like the screen it interrupts. Margins trimmed off
## `wood_style()`'s menu-button defaults for the same reason `hud.gd` trims them.
func _style_panel(panel: PanelContainer, team: Label, arrow: Label, role_colour: Color) -> void:
	var sb := UiTheme.wood_style(UiTheme.WOOD_DEEP, role_colour)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", sb)
	team.add_theme_color_override("font_color", role_colour)
	arrow.add_theme_color_override("font_color", UiTheme.CREAM_MUTED)

## R-29 — WHAT JUST HAPPENED. One word, in the colour of the side it favoured.
##
## ⚠️ NOTHING SENDS THE REASON, SO IT IS CLASSIFIED HERE. `MatchManager
## .round_intermission_started` carries `(next_round, next_team_a_is_can, can_team_won)`
## and `RoundManager.round_won` carries `(winning_team)`. That is all there is.
##
## ⚠️ CLASSIFIED AT INTERMISSION, NOT AT `round_won`, AND THAT IS THE DIFFERENCE BETWEEN
## WORKING AND WORKING ON THE HOST ONLY. `RoundManager.report_round_win()` early-returns on
## a client, so `round_won` NEVER FIRES on a client — a reason derived there would be blank
## for every peer that is not hosting. `round_intermission_started` is the replicated
## broadcast every peer does get (the same reasoning `hud.gd::_on_round_intermission_audio`
## documents for hanging its fanfare there).
##
## And the state this needs is valid on a client at that moment: `report_round_win()` does
## `_sync_state.rpc(time_left, round_active)` on the line BEFORE it emits, so every peer has
## the ended round's final `time_left` before the intermission broadcast reaches it — same
## host frame, same ordered reliable channel, that RPC first.
##
## ⚠️ WHAT THIS CANNOT DISTINGUISH, stated rather than hidden:
##  · **RING-OUT ×3 READS AS `TAGGED`.** `register_ring_out()` calls `report_round_win(true)`
##    exactly like a tag does, and nothing downstream records which clause fired. The can
##    side did win by punishing the attacker either way, so the word is not *wrong*, but it
##    is not specific. A real fix needs a reason on the signal, which is the physics/net
##    lane's call, not this file's.
##  · **`TIME` is decided on `time_left`, not on a flag.** `_on_time_up()` fires at exactly
##    0.0 so the margin is generous; but any future win path that also happens to land on a
##    near-zero clock would be labelled TIME.
func _show_reason(can_team_won: bool) -> void:
	reason_label.text = _classify_reason(can_team_won)
	# The reason takes the colour of the side it FAVOURED — can side is defence.
	reason_label.add_theme_color_override("font_color",
		UiTheme.DEFENSE if can_team_won else UiTheme.OFFENSE)
	reason_label.visible = true

func _classify_reason(can_team_won: bool) -> String:
	if RoundManager.time_left <= TIME_EPSILON:
		return "TIME"
	if can_team_won:
		return "TAGGED"
	# The tsinelas side took it, and there is one way to do that now: put the lata over
	# and keep it off its circle. ⚠️ This used to branch on `GameLaunch.game_mode` and
	# return "DENTED" under Option A — that mode is deleted (§8.2) and so is the branch.
	return "LATA DOWN"

## `_on_time_up()` reports at exactly `time_left == 0.0`, so this only has to be wider than
## float noise — not a tolerance on a race.
const TIME_EPSILON: float = 0.05

func _on_intermission_started(next_round: int, next_team_a_is_can: bool, can_team_won: bool) -> void:
	# Recover which team won this round (the opposite assignment from next round).
	var this_round_team_a_is_can := not next_team_a_is_can
	var team_a_won := can_team_won == this_round_team_a_is_can
	var winner_name := "TEAM A" if team_a_won else "TEAM B"

	# 0.0s — show result banner immediately, with WHY above it (R-29).
	_show_reason(can_team_won)
	result_label.text = "%s WINS THE ROUND!" % winner_name
	fight_label.visible = false
	visible = true
	modulate.a = 1.0

	# Set panel labels and colours for the INCOMING roles (what each team swaps TO).
	if next_team_a_is_can:
		# Next round: Team A holds the can → DEFENSE. Team B throws → OFFENSE.
		team_a_label.text = "A · DEFENSE"
		role_arrow_a.text = "was OFFENSE →"
		team_b_label.text = "B · OFFENSE"
		role_arrow_b.text = "was DEFENSE →"
		_style_panel(left_panel, team_a_label, role_arrow_a, UiTheme.DEFENSE)
		_style_panel(right_panel, team_b_label, role_arrow_b, UiTheme.OFFENSE)
	else:
		# Next round: Team A throws the slipper → OFFENSE. Team B holds the can → DEFENSE.
		team_a_label.text = "A · OFFENSE"
		role_arrow_a.text = "was DEFENSE →"
		team_b_label.text = "B · DEFENSE"
		role_arrow_b.text = "was OFFENSE →"
		_style_panel(left_panel, team_a_label, role_arrow_a, UiTheme.OFFENSE)
		_style_panel(right_panel, team_b_label, role_arrow_b, UiTheme.DEFENSE)

	# Chained tween drives the two later beats:
	#   1.2s  → slide panels in
	#   3.5s  → show FIGHT wipe (1.2 + 2.3 = 3.5)
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(_slide_panels_in)
	tween.tween_interval(2.3)
	tween.tween_callback(_show_fight.bind("ROUND %d — FIGHT!" % next_round))

## Slides both panels in from off-screen simultaneously using a BACK/EASE_OUT
## tween for a satisfying overshoot-and-settle feel.
func _slide_panels_in() -> void:
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(left_panel, "offset_left", -250.0, 0.5)
	t.tween_property(left_panel, "offset_right", -30.0, 0.5)
	t.tween_property(right_panel, "offset_left", 30.0, 0.5)
	t.tween_property(right_panel, "offset_right", 250.0, 0.5)

## Shows the "ROUND N — FIGHT!" wipe label, then fades it out quickly.
func _show_fight(text: String) -> void:
	fight_label.text = text
	fight_label.visible = true
	fight_label.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(fight_label, "modulate:a", 0.0, 0.1)

func _on_round_started(_round_number: int, _team_a_is_can: bool) -> void:
	visible = false
	# Reset panel offsets to off-screen so the next intermission slide-in starts clean.
	left_panel.offset_left = -700.0
	left_panel.offset_right = -480.0
	right_panel.offset_left = 480.0
	right_panel.offset_right = 700.0
