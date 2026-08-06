extends Control
class_name MatchResult


@onready var card: PanelContainer = %Card
@onready var message_label: Label = %MessageLabel
@onready var standings: VBoxContainer = %Standings
@onready var rematch_button: Button = %RematchButton
@onready var menu_button: Button = %MenuButton

var _rematch_votes: Dictionary = {}

func _ready() -> void:
	visible = false
	MatchManager.match_won.connect(_on_match_won)
	MatchManager.round_started.connect(_on_round_started)
	NetworkManager.player_disconnected.connect(_on_peer_disconnected)
	rematch_button.pressed.connect(_on_rematch_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	_style_buttons()

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

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_menu_pressed()

func _on_match_won(winning_team: int) -> void:
	if winning_team < 0:
		message_label.text = "DRAW  —  %s" % [_tied_names()]
	else:
		var champ := RoundManager.player_at(winning_team)
		var champ_name: String = champ.display_name() if champ != null \
			else "P%d" % [winning_team + 1]
		message_label.text = "%s WINS THE MATCH!  %d PTS" % [
			champ_name, MatchManager.score_for(winning_team)]
	var accent := UiTheme.HIGHLIGHT if winning_team >= 0 else UiTheme.AMBER
	var sb := UiTheme.wood_style(UiTheme.WOOD_DEEP, accent)
	card.add_theme_stylebox_override("panel", sb)
	message_label.add_theme_color_override("font_color", UiTheme.CREAM)
	_render_standings(winning_team)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rematch_votes.clear()
	rematch_button.visible = not GameLaunch.spectator
	_refresh_rematch_button()
	if rematch_button.visible:
		rematch_button.grab_focus()
	else:
		menu_button.grab_focus()
	if not NetworkManager.is_networked():
		get_tree().paused = true

func _tied_names() -> String:
	var order := MatchManager.ranking()
	if order.is_empty():
		return ""
	var top: int = MatchManager.score_for(order[0])
	var names := PackedStringArray()
	for slot in order:
		if MatchManager.score_for(slot) != top:
			break
		var who := RoundManager.player_at(slot)
		names.append(who.display_name() if who != null else "P%d" % [slot + 1])
	return "  ·  ".join(names)

func _render_standings(winning_slot: int) -> void:
	var order := MatchManager.ranking()
	var top_score: int = MatchManager.score_for(order[0]) if not order.is_empty() else 0
	var drawn := winning_slot < 0
	for i in range(4):
		var row := standings.get_node_or_null("Place%d" % [i]) as Control
		if row == null:
			continue
		if i >= order.size():
			row.visible = false
			continue
		row.visible = true
		var slot: int = order[i]
		var points: int = MatchManager.score_for(slot)
		var tied_at_top := points == top_score
		var who := RoundManager.player_at(slot)
		var display: String = who.display_name() if who != null else "P%d" % [slot + 1]
		var place_text := "=" if (drawn and tied_at_top) else "%d" % [i + 1]
		var colour: Color = UiTheme.HIGHLIGHT if tied_at_top else UiTheme.CREAM
		for cell_name in ["Place", "Name", "Points"]:
			var cell := row.get_node_or_null(cell_name) as Label
			if cell == null:
				continue
			cell.add_theme_color_override("font_color", colour)
			cell.add_theme_color_override("font_outline_color", UiTheme.INK)
		(row.get_node("Place") as Label).text = place_text
		(row.get_node("Name") as Label).text = display
		(row.get_node("Points") as Label).text = "%d PTS" % [points]

func _on_rematch_pressed() -> void:
	AudioManager.play("ui_click")
	if not NetworkManager.is_networked():
		_begin_rematch_now()
		return
	var my_id := multiplayer.get_unique_id()
	if bool(_rematch_votes.get(my_id, false)):
		return
	_rpc_vote_rematch.rpc(my_id)

@rpc("any_peer", "call_local", "reliable")
func _rpc_vote_rematch(peer_id: int) -> void:
	_rematch_votes[peer_id] = true
	_refresh_rematch_button()
	if NetworkManager.is_host():
		_check_rematch_ready()

func _on_peer_disconnected(peer_id: int) -> void:
	if not visible or not _rematch_votes.has(peer_id):
		return
	_rematch_votes.erase(peer_id)
	_refresh_rematch_button()
	if NetworkManager.is_host():
		_check_rematch_ready()

func _voting_peer_ids() -> Array:
	return NetworkManager.seated_peer_ids()

func _check_rematch_ready() -> void:
	var required := _voting_peer_ids()
	if required.is_empty():
		return
	for id in required:
		if not bool(_rematch_votes.get(id, false)):
			return
	_begin_rematch_now()

func _refresh_rematch_button() -> void:
	if not rematch_button.visible:
		return
	if not NetworkManager.is_networked():
		rematch_button.text = "REMATCH"
		rematch_button.disabled = false
		return
	var required := _voting_peer_ids()
	var voted := 0
	for id in required:
		if bool(_rematch_votes.get(id, false)):
			voted += 1
	var my_id := multiplayer.get_unique_id()
	if bool(_rematch_votes.get(my_id, false)):
		rematch_button.text = "WAITING…  (%d/%d)" % [voted, required.size()]
		rematch_button.disabled = true
	else:
		rematch_button.text = "REMATCH  (%d/%d)" % [voted, required.size()] if voted > 0 else "REMATCH"
		rematch_button.disabled = false

func _begin_rematch_now() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	MatchManager.reset()
	RoundManager.reset()
	MatchManager.begin_next_round()

func _on_round_started(_round_number: int, _defender_slot: int) -> void:
	if not visible:
		return
	visible = false

func _on_menu_pressed() -> void:
	AudioManager.play("ui_back")
	get_tree().paused = false
	NetworkManager.disconnect_network()
	MatchManager.reset()
	RoundManager.reset()
	GameLaunch.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

