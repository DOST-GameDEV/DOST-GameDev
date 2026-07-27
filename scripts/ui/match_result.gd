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
	message_label.text = "%s WINS THE MATCH!" % ("TEAM A" if winning_team == 0 else "TEAM B")
	visible = true
	# B-51: main.gd captures the cursor for the whole match and nothing released
	# it when the match ended, so this screen appeared with an invisible, captured
	# mouse and neither button below could be clicked — you needed the mouse to
	# reach the button that frees the mouse. Released here, re-captured on Rematch.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Only the host (or non-networked local play) can actually start a
	# rematch — MatchManager.begin_next_round() is host-gated, so a client
	# pressing this would be a silent no-op. Hide it there instead.
	rematch_button.visible = not NetworkManager.is_networked() or NetworkManager.is_host()
	# Q-4: RoundManager.round_active is false so input is already frozen
	# (character_base.gd), but gravity, hazards, and the camera keep running
	# underneath this screen. Same split as Q-3/B-64 (Handoff.md §0.3): a
	# networked match can't be paused by one player deciding to look at the
	# result screen — the host's authoritative state has to keep running for
	# whichever peer hasn't seen match_won yet, and there is no client-only
	# freeze that wouldn't just desync harmlessly-idle characters. Local Match
	# only. Relies on Q-3's PROCESS_MODE_ALWAYS on this node (set in
	# Main.tscn) to stay clickable while the tree is paused.
	if not NetworkManager.is_networked():
		get_tree().paused = true

## Resets in place — no scene reload — so a networked rematch doesn't tear
## down the connection or any spawned character. main.gd::_on_match_round_started
## (fired by the begin_next_round() below) repositions everyone via
## _reset_world(), same as any other round start.
func _on_rematch_pressed() -> void:
	visible = false
	# Q-4: must clear before begin_next_round() — a paused tree would freeze
	# the very round it's about to start.
	get_tree().paused = false
	# B-51: back into gameplay, so the cursor goes back to where main.gd's
	# _ready() put it. Without this a rematch runs with a visible OS cursor and
	# no mouse-look, since camera_rig.gd only aims while the mouse is captured.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	MatchManager.reset()
	RoundManager.reset()
	MatchManager.begin_next_round()

func _on_menu_pressed() -> void:
	# Q-4: must clear before change_scene_to_file — same reasoning as Q-3/B-64's
	# _on_return_to_menu_pressed: a scene change with the tree still paused
	# loads MainMenu.tscn paused and every button on it dies.
	get_tree().paused = false
	NetworkManager.disconnect_network()
	MatchManager.reset()
	RoundManager.reset()
	GameLaunch.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # item 14: Main.tscn captures it for the match
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
