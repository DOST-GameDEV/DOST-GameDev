extends Control
class_name RoleSwapCard


@onready var title_label: Label = %TitleLabel
@onready var headline_label: Label = %HeadlineLabel
@onready var swap_panel: PanelContainer = %SwapPanel
@onready var taya_caption: Label = %TayaCaption
@onready var taya_name: Label = %TayaName
@onready var attack_caption: Label = %AttackCaption
@onready var attacker_names: Label = %AttackerNames
@onready var standings_panel: PanelContainer = %StandingsPanel
@onready var standings: VBoxContainer = %Standings
@onready var fight_label: Label = %FightLabel

var _rows: Array[HBoxContainer] = []

func _ready() -> void:
	MatchManager.round_intermission_started.connect(_on_intermission_started)
	MatchManager.round_started.connect(_on_round_started)
	_build_standings_rows()
	_apply_wood_skin()

func _apply_wood_skin() -> void:
	for label in [title_label, headline_label, fight_label]:
		label.add_theme_constant_override("outline_size", 10)
		label.add_theme_color_override("font_outline_color", UiTheme.INK)
	title_label.add_theme_color_override("font_color", UiTheme.CREAM_MUTED)
	headline_label.add_theme_color_override("font_color", UiTheme.DEFENSE)
	fight_label.add_theme_color_override("font_color", UiTheme.AMBER)

	for caption in [taya_caption, attack_caption]:
		caption.add_theme_color_override("font_color", UiTheme.CREAM_MUTED)
	taya_name.add_theme_color_override("font_color", UiTheme.DEFENSE)
	attacker_names.add_theme_color_override("font_color", UiTheme.OFFENSE)

	for panel in [swap_panel, standings_panel]:
		var sb := UiTheme.wood_style(UiTheme.WOOD_DEEP)
		sb.content_margin_left = 22.0
		sb.content_margin_right = 22.0
		sb.content_margin_top = 14.0
		sb.content_margin_bottom = 14.0
		panel.add_theme_stylebox_override("panel", sb)

func _build_standings_rows() -> void:
	for i in range(MatchManagerScript.PLAYER_COUNT):
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 18)

		var rank := Label.new()
		rank.name = "Rank"
		rank.custom_minimum_size = Vector2(44, 0)
		rank.add_theme_font_size_override("font_size", 26)
		row.add_child(rank)

		var who := Label.new()
		who.name = "Name"
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.add_theme_font_size_override("font_size", 26)
		who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(who)

		var score := Label.new()
		score.name = "Score"
		score.custom_minimum_size = Vector2(120, 0)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score.add_theme_font_size_override("font_size", 26)
		row.add_child(score)

		standings.add_child(row)
		_rows.append(row)

func _name_of(slot: int) -> String:
	var who := RoundManager.player_at(slot)
	return who.display_name() if who != null else "P%d" % [slot + 1]

func _show_headline() -> void:
	var taya := MatchManager.defender_slot
	headline_label.text = "%s HELD THE LATA FOR %d PTS" % [
		_name_of(taya), MatchManager.score_for(taya)]

func _on_intermission_started(next_round: int, next_defender_slot: int) -> void:
	title_label.text = "END OF ROUND %d" % [maxi(1, next_round - 1)]
	_show_headline()

	taya_name.text = _name_of(next_defender_slot)
	var others := PackedStringArray()
	for slot in range(MatchManagerScript.PLAYER_COUNT):
		if slot != next_defender_slot:
			others.append(_name_of(slot))
	attacker_names.text = " · ".join(others)

	_fill_standings(next_defender_slot)

	fight_label.visible = false
	visible = true
	modulate.a = 1.0
	swap_panel.modulate.a = 0.0
	standings_panel.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(_reveal_panels)
	tween.tween_interval(2.3)
	tween.tween_callback(_show_fight.bind("ROUND %d — FIGHT!" % next_round))

func _fill_standings(next_defender_slot: int) -> void:
	var order := MatchManager.ranking()
	for i in _rows.size():
		var row := _rows[i]
		if i >= order.size():
			row.visible = false
			continue
		row.visible = true
		var slot: int = order[i]
		var colour := UiTheme.DEFENSE if slot == next_defender_slot else UiTheme.CREAM
		var rank := row.get_node("Rank") as Label
		var who := row.get_node("Name") as Label
		var score := row.get_node("Score") as Label
		rank.text = "%d" % [i + 1]
		who.text = _name_of(slot)
		score.text = str(MatchManager.score_for(slot))
		for label in [rank, who, score]:
			(label as Label).add_theme_color_override("font_color", colour)

func _reveal_panels() -> void:
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for panel in [swap_panel, standings_panel]:
		panel.pivot_offset = panel.size / 2.0
		panel.scale = Vector2(0.94, 0.94)
		t.tween_property(panel, "modulate:a", 1.0, 0.35)
		t.tween_property(panel, "scale", Vector2.ONE, 0.45)

func _show_fight(text: String) -> void:
	fight_label.text = text
	fight_label.visible = true
	fight_label.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(fight_label, "modulate:a", 0.0, 0.1)

func _on_round_started(_round_number: int, _defender_slot: int) -> void:
	visible = false
	for panel in [swap_panel, standings_panel]:
		panel.modulate.a = 0.0
		panel.scale = Vector2.ONE

