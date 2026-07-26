extends Control
class_name MatchResult

## B-14/B-37 (queue item 11): the functional match-end flow — MatchManager
## already correctly decides a Bo5 win (WINS_NEEDED = 3), but nothing used to
## exist after match_won fired. Self-sufficient like Hud: reads MatchManager
## directly and needs no wiring from main.gd beyond being present in the
## scene tree. Plain placeholder styling — item 20 replaces this with the
## moodboard's Bo5 grid.

@onready var message_label: Label = %MessageLabel
@onready var rematch_button: Button = %RematchButton
@onready var menu_button: Button = %MenuButton

func _ready() -> void:
	visible = false
	MatchManager.match_won.connect(_on_match_won)
	rematch_button.pressed.connect(_on_rematch_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

func _on_match_won(winning_team: int) -> void:
	message_label.text = "%s wins the match!" % ("Team A" if winning_team == 0 else "Team B")
	visible = true
	# Only the host (or non-networked local play) can actually start a
	# rematch — MatchManager.begin_next_round() is host-gated, so a client
	# pressing this would be a silent no-op. Hide it there instead.
	rematch_button.visible = not NetworkManager.is_networked() or NetworkManager.is_host()

## Resets in place — no scene reload — so a networked rematch doesn't tear
## down the connection or any spawned character. main.gd::_on_match_round_started
## (fired by the begin_next_round() below) repositions everyone via
## _reset_world(), same as any other round start.
func _on_rematch_pressed() -> void:
	visible = false
	MatchManager.reset()
	RoundManager.reset()
	MatchManager.begin_next_round()

func _on_menu_pressed() -> void:
	NetworkManager.disconnect_network()
	MatchManager.reset()
	RoundManager.reset()
	GameLaunch.reset()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
