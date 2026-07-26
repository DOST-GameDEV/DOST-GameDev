extends Control
class_name Hud

## HUD per GDD Section 6: current round, Bo5 tracker, timer, who's Attack vs Defense.
## Reads the RoundManager/MatchManager autoloads directly — no per-scene wiring needed,
## drop this scene into Main.tscn (or a match scene) and it just works.

@onready var timer_label: Label = %TimerLabel
@onready var score_label: Label = %ScoreLabel
@onready var round_label: Label = %RoundLabel
@onready var role_label: Label = %RoleLabel
@onready var downed_flash: ColorRect = %DownedFlash
@onready var dent_label: Label = %DentLabel

func _ready() -> void:
	MatchManager.round_started.connect(_on_round_started)
	MatchManager.match_won.connect(_on_match_won)
	downed_flash.visible = false

func _process(_delta: float) -> void:
	var t := int(ceil(RoundManager.time_left))
	timer_label.text = "%02d:%02d" % [t / 60, t % 60]
	score_label.text = "%d - %d" % [MatchManager.team_a_wins, MatchManager.team_b_wins]

func _on_round_started(round_number: int, team_a_is_can: bool) -> void:
	round_label.text = "Round %d / 5" % round_number
	role_label.text = "Team A: %s   Team B: %s" % [
		"Defense" if team_a_is_can else "Offense",
		"Offense" if team_a_is_can else "Defense",
	]

## B-29: public entry point for a late-joining client to refresh this display
## once, without going through the round_started signal — that signal also
## drives main.gd's full round reset/reposition logic, which must NOT re-run
## just because a new peer joined mid-round (see main.gd _send_late_join_state).
func refresh_round_display(round_number: int, team_a_is_can: bool) -> void:
	_on_round_started(round_number, team_a_is_can)

func _on_match_won(winning_team: int) -> void:
	round_label.text = "Team %s wins the match!" % ("A" if winning_team == 0 else "B")

## Call when the locally-viewed Can enters/exits Downed — clear visual read for
## stream/demo per GDD Section 6.
func set_downed_flash(active: bool) -> void:
	downed_flash.visible = active

## Option A only. Call with the locally-viewed Can's current dent count once
## GameLaunch.game_mode == OPTION_A; leave uncalled (default hidden) under
## Option B, which has no dent concept.
func set_dents(current: int, max_dents: int) -> void:
	dent_label.visible = true
	dent_label.text = "Dents: %d / %d" % [current, max_dents]
