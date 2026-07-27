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

func _on_intermission_started(next_round: int, next_team_a_is_can: bool, can_team_won: bool) -> void:
	# Recover which team won this round (the opposite assignment from next round).
	var this_round_team_a_is_can := not next_team_a_is_can
	var team_a_won := can_team_won == this_round_team_a_is_can
	var winner_name := "TEAM A" if team_a_won else "TEAM B"

	# 0.0s — show result banner immediately.
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
		left_panel.theme_type_variation = &"DefenseCard"
		right_panel.theme_type_variation = &"OffenseCard"
	else:
		# Next round: Team A throws the slipper → OFFENSE. Team B holds the can → DEFENSE.
		team_a_label.text = "A · OFFENSE"
		role_arrow_a.text = "was DEFENSE →"
		team_b_label.text = "B · DEFENSE"
		role_arrow_b.text = "was OFFENSE →"
		left_panel.theme_type_variation = &"OffenseCard"
		right_panel.theme_type_variation = &"DefenseCard"

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
