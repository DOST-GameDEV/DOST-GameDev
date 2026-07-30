extends Control
class_name MatchResult

## B-14/B-37 (queue item 11): the functional match-end flow — MatchManager
## already correctly decides a Bo5 win (WINS_NEEDED = 3), but nothing used to
## exist after match_won fired. Self-sufficient like Hud: reads MatchManager
## directly and needs no wiring from main.gd beyond being present in the
## scene tree.
##
## Q-4: restyled to the moodboard's Bo5 pip grid (Dev_Plan.md §4.4). Colour
## tracks ROLE, never team identity — §4.2's hard rule ("Team A is not the
## orange team"). Team identity is carried only by the A/B letter marks.

@onready var card: PanelContainer = %Card
@onready var message_label: Label = %MessageLabel
@onready var team_a_pips: HBoxContainer = %TeamAPips
@onready var team_b_pips: HBoxContainer = %TeamBPips
@onready var rematch_button: Button = %RematchButton
@onready var menu_button: Button = %MenuButton

func _ready() -> void:
	visible = false
	MatchManager.match_won.connect(_on_match_won)
	rematch_button.pressed.connect(_on_rematch_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	_style_buttons()

## B-143 — the WOOD BUTTON face, the menu's own. Caught by looking at the first restyled
## render: the card behind these went wood, and the two buttons stayed on the theme's
## default `card_style(CARD)` — a near-white slab and, under focus, a navy one — which read
## as two dialog buttons pasted onto a wooden sign.
##
## `UiTheme.wood_style()`'s `sink` argument is what a press looks like here: the drop shadow
## goes and the content margins re-weight so the label rides down into the well, with the
## footprint unchanged so nothing reflows. Focus is AMBER-edged rather than the theme's
## IMPACT pink, because REMATCH now takes focus by default (R-29) and a permanent pink ring
## on the primary button reads as an error state.
func _style_buttons() -> void:
	for button in [rematch_button, menu_button]:
		button.add_theme_stylebox_override("normal", UiTheme.wood_style(UiTheme.WOOD_DEEP))
		button.add_theme_stylebox_override("hover", UiTheme.wood_style(UiTheme.WOOD_MID))
		button.add_theme_stylebox_override("pressed",
			UiTheme.wood_style(UiTheme.WOOD_DARK, UiTheme.WOOD_EDGE, true))
		button.add_theme_stylebox_override("focus",
			UiTheme.wood_style(UiTheme.WOOD_MID, UiTheme.AMBER))
		button.add_theme_color_override("font_color", UiTheme.CREAM)
		button.add_theme_color_override("font_hover_color", UiTheme.AMBER)
		button.add_theme_color_override("font_focus_color", UiTheme.AMBER)
		button.add_theme_color_override("font_pressed_color", UiTheme.AMBER)

## U-7: Esc exits to the main menu from the match-result screen — same path as
## the Menu button, so the same teardown applies.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_menu_pressed()

func _on_match_won(winning_team: int) -> void:
	message_label.text = "%s WINS THE MATCH!" % ("TEAM A" if winning_team == 0 else "TEAM B")
	# Q-4/§4.2 hard rule: the accent bar tracks ROLE, not team — colour the
	# winning team's card by which side it held in the FINAL round
	# (MatchManager.team_a_is_can), not by team identity. Nothing has reset
	# this yet — match_won fires before Rematch/Menu ever touch MatchManager.
	var team_a_is_can := MatchManager.team_a_is_can
	var winner_is_can_side := team_a_is_can if winning_team == 0 else not team_a_is_can
	var accent := UiTheme.DEFENSE if winner_is_can_side else UiTheme.OFFENSE
	# B-143 — the wood face, matching the HUD, the intermission card and the menu. This was
	# `card_style(PANEL, …)`, a near-white panel, and it was the last screen in the whole
	# mid-game flow still on the old language.
	var sb := UiTheme.wood_style(UiTheme.WOOD_DEEP, accent)
	card.add_theme_stylebox_override("panel", sb)
	message_label.add_theme_color_override("font_color", UiTheme.CREAM)
	# Same rule applied to both team blocks' pip fill colour, not just the
	# winner's accent bar — each team's pips read as whichever role it held
	# this same final round.
	_fill_pips(team_a_pips, MatchManager.team_a_wins, UiTheme.DEFENSE if team_a_is_can else UiTheme.OFFENSE)
	_fill_pips(team_b_pips, MatchManager.team_b_wins, UiTheme.OFFENSE if team_a_is_can else UiTheme.DEFENSE)
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
	# R-29 — REMATCH TAKES THE FOCUS, so the fastest path off this screen is back into the
	# game rather than out of it. Enter/Space now does the thing almost everybody wants;
	# Esc still exits (see `_unhandled_input`), so the way out is unchanged.
	#
	# ⚠️ FALLS BACK TO MENU WHEN REMATCH IS HIDDEN. On a client the line above hides it —
	# `begin_next_round()` is host-gated — and `grab_focus()` on a hidden Control does
	# nothing, which would leave the screen with NO focus and keyboard navigation dead.
	if rematch_button.visible:
		rematch_button.grab_focus()
	else:
		menu_button.grab_focus()
	# Q-4: RoundManager.round_active is false so input is already frozen
	# (character_base.gd), but gravity, hazards, and the camera keep running
	# underneath this screen. Same split as Q-3/B-64 (Handoff.md §0.3): a
	# networked match can't be paused by one player deciding to look at the
	# result screen — the host's authoritative state has to keep running for
	# whichever peer hasn't seen match_won yet, and there is no client-only
	# freeze that wouldn't just desync harmlessly-idle characters. Single Player
	# only. Relies on Q-3's PROCESS_MODE_ALWAYS on this node (set in
	# Main.tscn) to stay clickable while the tree is paused.
	if not NetworkManager.is_networked():
		get_tree().paused = true

## Bo5 pip grid, three squares per team, filled for rounds won. fill_color is
## that team's role colour THIS final round (see _on_match_won) — a plain
## INK/CARD square would lose the role-colour read the moodboard specifies,
## and reusing UiTheme.card_style keeps the border/radius identical to every
## other box in the theme instead of a one-off number.
func _fill_pips(container: HBoxContainer, wins: int, fill_color: Color) -> void:
	for i in range(container.get_child_count()):
		var pip: Panel = container.get_child(i)
		var filled := i < wins
		# B-143: the unfilled state was `UiTheme.CARD`, a near-white square — invisible on
		# the wood card this now sits on, and the same invisible-empty-state problem the
		# HUD's own pips had. A dark well reads as "a round you did not win".
		pip.add_theme_stylebox_override("panel",
			UiTheme.card_style(fill_color if filled else UiTheme.WOOD_DARK, UiTheme.WOOD_EDGE))

## Resets in place — no scene reload — so a networked rematch doesn't tear
## down the connection or any spawned character. main.gd::_on_match_round_started
## (fired by the begin_next_round() below) repositions everyone via
## _reset_world(), same as any other round start.
func _on_rematch_pressed() -> void:
	AudioManager.play("ui_click") # 4.1
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
	AudioManager.play("ui_back") # 4.1
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
