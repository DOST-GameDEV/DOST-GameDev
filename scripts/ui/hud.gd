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

func _on_match_won(winning_team: int) -> void:
	round_label.text = "Team %s wins the match!" % ("A" if winning_team == 0 else "B")

## Call when the locally-viewed Can enters/exits Downed — clear visual read for
## stream/demo per GDD Section 6.
func set_downed_flash(active: bool) -> void:
	downed_flash.visible = active
