extends Control
class_name Hud


@onready var timer_label: Label = %TimerLabel
@onready var timer_card: PanelContainer = %TimerCard
@onready var round_label: Label = %RoundLabel
@onready var scoreboard_panel: PanelContainer = %Scoreboard
@onready var score_title: Label = %ScoreTitle
@onready var lata_card: PanelContainer = %LataCard
@onready var lata_label: Label = %LataLabel
@onready var lata_hint_label: Label = %LataHintLabel
@onready var downed_flash: ColorRect = %DownedFlash
@onready var frost_vignette: ColorRect = %FrostVignette
@onready var toast_label: Label = %ToastLabel
@onready var ready_prompt: Label = %ReadyPrompt
@onready var ready_objective: Label = %ReadyObjective
@onready var ready_objective_row: CenterContainer = %ReadyObjectiveRow
@onready var countdown_label: Label = %CountdownLabel
@onready var you_card: YouCard = %YouCard
@onready var crosshair: Control = %Crosshair
@onready var crosshair_label: Label = %CrosshairLabel
@onready var offscreen_indicators: OffscreenIndicators = %OffscreenIndicators
@onready var emote_wheel: EmoteWheel = %EmoteWheel

var _toast_time_left: float = 0.0
var _pulse_tween: Tween = null
var _countdown_tween: Tween = null

var _timer_seconds_shown: int = -1
var _timer_urgent: int = -1
var _lata_upright_shown: int = -1
var _lata_hint_shown: String = "￿"

func _set_timer_urgent(urgent: bool) -> void:
	var want := 1 if urgent else 0
	if want == _timer_urgent:
		return
	_timer_urgent = want
	timer_label.add_theme_color_override("font_color",
		UiTheme.HIGHLIGHT if urgent else UiTheme.AMBER)

func _ready() -> void:
	emote_wheel.emote_chosen.connect(_on_emote_chosen)
	MatchManager.round_started.connect(_on_round_started)
	MatchManager.match_won.connect(_on_match_won)
	MatchManager.round_intermission_started.connect(_on_round_intermission_audio)
	MatchManager.score_changed.connect(_on_score_changed)
	RoundManager.lata_knocked.connect(_on_lata_knocked)
	RoundManager.lata_restored.connect(_on_lata_restored)
	RoundManager.attacker_tagged.connect(_on_attacker_tagged)
	downed_flash.visible = false
	frost_vignette.visible = false
	_frost_coverage = 0.0
	toast_label.visible = false
	lata_card.visible = false
	timer_card.resized.connect(func(): timer_card.pivot_offset = timer_card.size / 2)
	_apply_wood_skin()
	_build_scoreboard()
	set_round_display(MatchManager.round_number, MatchManager.defender_slot)
	GameVersion.attach_to(self, true)


const TEXT_OUTLINE: int = 8
const CROSSHAIR_OUTLINE: int = 5

func _hud_wood_style(fill: Color, border: Color, sink: bool = false) -> StyleBoxFlat:
	var sb := UiTheme.wood_style(fill, border, sink)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	return sb

func _apply_wood_skin() -> void:
	timer_card.add_theme_stylebox_override("panel",
		_hud_wood_style(UiTheme.WOOD_DARK, UiTheme.WOOD_EDGE, true))
	timer_label.add_theme_color_override("font_color", UiTheme.AMBER)
	round_label.add_theme_color_override("font_color", UiTheme.CREAM)
	round_label.add_theme_font_size_override("font_size", 20)
	round_label.add_theme_color_override("font_outline_color", UiTheme.INK)
	round_label.add_theme_constant_override("outline_size", TEXT_OUTLINE)


	lata_card.add_theme_stylebox_override("panel",
		_hud_wood_style(UiTheme.WOOD_DEEP, UiTheme.WOOD_EDGE))
	lata_label.add_theme_color_override("font_color", UiTheme.AMBER)
	lata_hint_label.add_theme_color_override("font_color", UiTheme.CREAM)

	for label in [ready_prompt, toast_label, ready_objective]:
		label.add_theme_constant_override("outline_size", TEXT_OUTLINE)
		label.add_theme_color_override("font_outline_color", UiTheme.INK)
	ready_prompt.add_theme_color_override("font_color", UiTheme.CREAM)
	toast_label.add_theme_color_override("font_color", UiTheme.AMBER)

func _style_team_card(panel: PanelContainer, label: Label, role_colour: Color) -> void:
	panel.add_theme_stylebox_override("panel",
		_hud_wood_style(UiTheme.WOOD_DEEP, role_colour))
	label.add_theme_color_override("font_color", role_colour)

func _refresh_role_accents() -> void:
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		return
	var role_colour: Color = UiTheme.DEFENSE if local_char.is_defender else UiTheme.OFFENSE
	crosshair_label.add_theme_color_override("font_color", role_colour)
	crosshair_label.add_theme_constant_override("outline_size", CROSSHAIR_OUTLINE)
	crosshair_label.add_theme_color_override("font_outline_color", UiTheme.INK)
	offscreen_indicators.set_can_arrow_colour(role_colour)

func _process(delta: float) -> void:
	var t := int(ceil(RoundManager.time_left))
	if t != _timer_seconds_shown:
		_timer_seconds_shown = t
		timer_label.text = "%02d:%02d" % [t / 60, t % 60]

	if RoundManager.time_left < 15.0:
		_set_timer_urgent(true)
		if RoundManager.time_left < 10.0:
			if _pulse_tween == null or not _pulse_tween.is_running():
				timer_card.pivot_offset = timer_card.size / 2
				_pulse_tween = create_tween().set_loops()
				_pulse_tween.tween_property(timer_card, "scale", Vector2(1.05, 1.05), 0.5)
				_pulse_tween.tween_property(timer_card, "scale", Vector2(1.0, 1.0), 0.5)
		else:
			_kill_pulse_tween()
	else:
		_set_timer_urgent(false)
		_kill_pulse_tween()

	_refresh_scoreboard()
	_refresh_lata_card()

	if _toast_time_left > 0.0:
		_toast_time_left -= delta
		if _toast_time_left <= 0.0:
			toast_label.visible = false
	var local_char := you_card.get_local_character()
	if _spectating:
		_refresh_spectator_panel()
		return
	var live := local_char != null and is_instance_valid(local_char)
	crosshair.visible = live and RoundManager.can_throw(local_char)
	offscreen_indicators.update(local_char)
	_refresh_status_stack(local_char)
	_refresh_stamina(local_char)
	_refresh_danger(local_char)
	_refresh_vulnerable_text(local_char)
	_refresh_frost(local_char, get_process_delta_time())

const STATUS_ROW_LIMIT: int = 4
const STATUS_BAR_SIZE: Vector2 = Vector2(190, 8)
const STATUS_FONT_SIZE: int = 20
const STATUS_MARGIN: Vector2 = Vector2(38, 150)

var _status_root_left: VBoxContainer = null
var _status_root_right: VBoxContainer = null
var _status_rows_left: Array[Control] = []
var _status_rows_right: Array[Control] = []

func _ensure_status_root(right_side: bool) -> VBoxContainer:
	var existing := _status_root_right if right_side else _status_root_left
	if existing != null and is_instance_valid(existing):
		return existing
	var root := VBoxContainer.new()
	root.name = "StatusStackRight" if right_side else "StatusStackLeft"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 6)
	root.set_anchors_preset(Control.PRESET_TOP_RIGHT if right_side else Control.PRESET_TOP_LEFT)
	root.custom_minimum_size = Vector2(STATUS_BAR_SIZE.x, 0)
	if right_side:
		root.position = Vector2(-STATUS_BAR_SIZE.x - STATUS_MARGIN.x, STATUS_MARGIN.y)
		root.alignment = BoxContainer.ALIGNMENT_END
	else:
		root.position = Vector2(STATUS_MARGIN.x, STATUS_MARGIN.y)
	add_child(root)
	if not right_side:
		_follow_scoreboard(root)
		if scoreboard_panel != null:
			scoreboard_panel.resized.connect(_follow_scoreboard.bind(root))
	if right_side:
		_status_root_right = root
	else:
		_status_root_left = root
	return root

const STATUS_UNDER_BOARD_GAP: float = 18.0

func _follow_scoreboard(root: VBoxContainer) -> void:
	if root == null or not is_instance_valid(root):
		return
	var top := STATUS_MARGIN.y
	if scoreboard_panel != null and is_instance_valid(scoreboard_panel):
		top = maxf(top, scoreboard_panel.position.y + scoreboard_panel.size.y \
			+ STATUS_UNDER_BOARD_GAP)
	root.position = Vector2(STATUS_MARGIN.x, top)

func _build_status_row() -> Control:
	var row := VBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", STATUS_FONT_SIZE)
	label.add_theme_color_override("font_outline_color", UiTheme.INK)
	label.add_theme_constant_override("outline_size", TEXT_OUTLINE)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.show_percentage = false
	bar.custom_minimum_size = STATUS_BAR_SIZE
	bar.max_value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	return row

func _status_colour(label: String) -> Color:
	match label:
		"STUNNED", "DOWNED", "VULNERABLE":
			return UiTheme.DANGER
		"FATIGUED":
			return UiTheme.AMBER
		_:
			return UiTheme.HIGHLIGHT

const DANGER_HOLD_ALPHA: float = 0.16
var _danger_held: bool = false

func _refresh_danger(local_char: CharacterBase) -> void:
	var want := false
	if local_char != null and is_instance_valid(local_char):
		if local_char.is_defender:
			var can := RoundManager.lata
			want = can != null and not can.is_upright and RoundManager.round_active
		else:
			want = local_char.is_taggable()
	if want == _danger_held:
		return
	_danger_held = want
	_apply_danger_hold()

const FROST_RAMP_IN: float = 0.14
const FROST_RAMP_OUT: float = 0.5
const FROST_THAW_TIME: float = 1.6

var _frost_coverage: float = 0.0

func _refresh_frost(local_char: CharacterBase, delta: float) -> void:
	var target := 0.0
	if local_char != null and is_instance_valid(local_char) \
			and local_char.state == CharacterBase.State.STAGGERED:
		var left := local_char.stagger_time_left()
		target = clampf(left / FROST_THAW_TIME, 0.0, 1.0) if left < FROST_THAW_TIME else 1.0
	var rate := FROST_RAMP_IN if target > _frost_coverage else FROST_RAMP_OUT
	_frost_coverage = move_toward(_frost_coverage, target, delta / maxf(rate, 0.001))
	frost_vignette.visible = _frost_coverage > 0.001
	if frost_vignette.visible:
		var material := frost_vignette.material as ShaderMaterial
		material.set_shader_parameter("coverage", _frost_coverage)
		var size := frost_vignette.size
		if size.y > 0.0:
			material.set_shader_parameter("aspect", size.x / size.y)

func _apply_danger_hold() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		return
	downed_flash.visible = _danger_held
	downed_flash.modulate.a = DANGER_HOLD_ALPHA if _danger_held else 0.0

var _vulnerable_label: Label = null

func _ensure_vulnerable_label() -> Label:
	if _vulnerable_label != null and is_instance_valid(_vulnerable_label):
		return _vulnerable_label
	var label := Label.new()
	label.name = "VulnerableWarning"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "YOU ARE VULNERABLE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", UiTheme.OFFENSE)
	label.add_theme_color_override("font_outline_color", UiTheme.INK)
	label.add_theme_constant_override("outline_size", TEXT_OUTLINE)
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.position = Vector2(-200.0, -104.0)
	label.custom_minimum_size = Vector2(400.0, 0.0)
	label.visible = false
	add_child(label)
	_vulnerable_label = label
	return label

func _refresh_vulnerable_text(local_char: CharacterBase) -> void:
	var vulnerable_label := _ensure_vulnerable_label()
	if vulnerable_label == null:
		return
	var live := local_char != null and is_instance_valid(local_char) 			and local_char.is_taggable()
	vulnerable_label.visible = live

func _refresh_status_stack(local_char: CharacterBase) -> void:
	var states: Array[Dictionary] = []
	var cooldowns: Array[Dictionary] = []
	if local_char != null and is_instance_valid(local_char):
		for effect in local_char.status_effects():
			var label := String(effect.get("label", ""))
			if label == "VULNERABLE":
				continue
			if label.ends_with(" CD"):
				cooldowns.append(effect)
			else:
				states.append(effect)
	_fill_status_side(_ensure_status_root(false), _status_rows_left, states, false)
	_fill_status_side(_ensure_status_root(true), _status_rows_right, cooldowns, true)


func _fill_status_side(root: VBoxContainer, rows: Array[Control],
		effects: Array[Dictionary], right_side: bool) -> void:
	var wanted: int = mini(effects.size(), STATUS_ROW_LIMIT)
	while rows.size() < wanted:
		var built := _build_status_row()
		root.add_child(built)
		rows.append(built)
	for i in rows.size():
		var row: Control = rows[i]
		if i >= wanted:
			row.visible = false
			continue
		var effect: Dictionary = effects[i]
		var seconds: float = float(effect.get("seconds", 0.0))
		var total: float = maxf(0.01, float(effect.get("total", 1.0)))
		var text: String = String(effect.get("label", ""))
		var colour := _status_colour(text)
		row.visible = true
		var label := row.get_node("Label") as Label
		var timed := seconds > 0.0
		label.text = ("%s  %.1fs" % [text, seconds]) if timed else text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right_side 			else HORIZONTAL_ALIGNMENT_LEFT
		label.add_theme_color_override("font_color", colour)
		var bar := row.get_node("Bar") as ProgressBar
		bar.value = clampf(seconds / total, 0.0, 1.0) if timed else 1.0
		bar.add_theme_stylebox_override("fill", _status_fill(colour))
		bar.add_theme_stylebox_override("background", _status_fill(UiTheme.INK, 0.55))

func _status_fill(colour: Color, alpha: float = 1.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(colour.r, colour.g, colour.b, alpha)
	sb.set_corner_radius_all(3)
	return sb

func enter_spectator_mode(camera: SpectatorCamera) -> void:
	you_card.visible = false
	crosshair.visible = false
	lata_card.visible = false
	downed_flash.visible = false
	frost_vignette.visible = false
	_frost_coverage = 0.0
	ready_prompt.visible = false
	ready_objective_row.visible = false
	offscreen_indicators.visible = false
	_spectating = true
	_spectator_camera = camera
	var legend := Label.new()
	legend.name = "SpectatorLegend"
	legend.text = SpectatorCamera.controls_text()
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_font_size_override("font_size", 15)
	legend.add_theme_color_override("font_color", UiTheme.CREAM_MUTED)
	legend.add_theme_color_override("font_outline_color", UiTheme.INK)
	legend.add_theme_constant_override("outline_size", TEXT_OUTLINE)
	legend.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	legend.offset_top = -46
	legend.offset_bottom = -18
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(legend)
	_spectator_status = _build_spectator_label(-70, -46, 15, UiTheme.CREAM_MUTED)
	_spectator_round = _build_spectator_label(-104, -70, 21, UiTheme.AMBER)
	legend.text += "   ·   %s clean feed" % SettingsManager.get_binding_display_name("clean_feed")
	set_process_input(true)

func exit_spectator_mode() -> void:
	if not _spectating:
		return
	set_clean_feed(false)
	_spectating = false
	_spectator_camera = null
	for label in [get_node_or_null("SpectatorLegend"), _spectator_status, _spectator_round]:
		if label != null and is_instance_valid(label):
			label.queue_free()
	_spectator_status = null
	_spectator_round = null
	you_card.visible = true
	crosshair.visible = true
	lata_card.visible = true
	offscreen_indicators.visible = true
	set_process_input(false)

var _spectating: bool = false
var _spectator_camera: SpectatorCamera = null
var _spectator_status: Label = null
var _spectator_round: Label = null

var _clean_feed: bool = false

func _input(event: InputEvent) -> void:
	if _handle_emote_input(event):
		return
	if not _spectating:
		return
	if not event.is_action_pressed("clean_feed"):
		return
	get_viewport().set_input_as_handled()
	set_clean_feed(not _clean_feed)

func _handle_emote_input(event: InputEvent) -> bool:
	if emote_wheel == null:
		return false
	var allowed := not _spectating and not get_tree().paused
	if not allowed:
		if emote_wheel.is_open():
			emote_wheel.close(false)
		return false
	if event.is_action_pressed("emote_wheel", false, true):
		var local_char := you_card.get_local_character()
		if local_char == null or not is_instance_valid(local_char) or not local_char.can_emote():
			return false
		emote_wheel.open()
		get_viewport().set_input_as_handled()
		return true
	if event.is_action_released("emote_wheel"):
		if not emote_wheel.is_open():
			return false
		emote_wheel.close(true)
		get_viewport().set_input_as_handled()
		return true
	return false

func _on_emote_chosen(id: String) -> void:
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		return
	local_char.try_emote(id)

func set_clean_feed(on: bool) -> void:
	if on == _clean_feed:
		return
	_clean_feed = on
	_apply_clean_feed_to_world(on)
	visible = not on

func _apply_clean_feed_to_world(hidden: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for node in scene.find_children("*", "CharacterBase", true, false):
		var nameplate := (node as Node).get_node_or_null("Nameplate") as Node3D
		if nameplate != null:
			nameplate.visible = not hidden

func is_clean_feed() -> bool:
	return _clean_feed

func _build_spectator_label(top: float, bottom: float, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", UiTheme.INK)
	label.add_theme_constant_override("outline_size", TEXT_OUTLINE)
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = top
	label.offset_bottom = bottom
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _refresh_spectator_panel() -> void:
	if _spectator_status != null and is_instance_valid(_spectator_status):
		_spectator_status.text = ("" if _spectator_camera == null
			or not is_instance_valid(_spectator_camera) else _spectator_camera.status_text())
	if _spectator_round == null or not is_instance_valid(_spectator_round):
		return
	if not RoundManager.round_active:
		_spectator_round.add_theme_color_override("font_color", UiTheme.AMBER)
		_spectator_round.text = "WAITING FOR THE ROUND TO START"
		return
	var order := MatchManager.ranking()
	var leader := order[0] if not order.is_empty() else 0
	var up: bool = RoundManager.lata != null and RoundManager.lata.is_upright
	_spectator_round.add_theme_color_override("font_color",
		UiTheme.DEFENSE if up else UiTheme.OFFENSE)
	_spectator_round.text = "ROUND %d/%d   ·   TAYA  %s   ·   LATA %s   ·   LEADER  %s  %d" % [
		maxi(1, MatchManager.round_number), MatchManagerScript.ROUNDS,
		seat_name(MatchManager.defender_slot), "UP" if up else "DOWN",
		seat_name(leader), MatchManager.score_for(leader)]

func _kill_pulse_tween() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
		timer_card.scale = Vector2.ONE

var _pip_cache: Dictionary = {}


func _fill_pips(container: HBoxContainer, filled: int, fill_color: Color = UiTheme.DEFENSE) -> void:
	var key := container.get_instance_id()
	var stamp := "%d:%s" % [filled, fill_color.to_html(false)]
	if _pip_cache.get(key, "") == stamp:
		return
	_pip_cache[key] = stamp
	for i in container.get_child_count():
		var pip: Control = container.get_child(i)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(2)
		sb.set_border_width_all(3)
		sb.border_color = UiTheme.WOOD_EDGE
		sb.bg_color = fill_color if i < filled else UiTheme.WOOD_DARK
		pip.add_theme_stylebox_override("panel", sb)


func show_toast(text: String, duration: float = 1.5) -> void:
	toast_label.text = text
	toast_label.visible = true
	_toast_time_left = duration

func show_ready_prompt(active: bool, text: String = "") -> void:
	if text != "":
		ready_prompt.text = text
	ready_prompt.visible = active
	_refresh_ready_objective(active)

func _refresh_ready_objective(active: bool) -> void:
	if not active:
		ready_objective_row.visible = false
		return
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		ready_objective_row.visible = false
		return
	var defending: bool = local_char.is_defender
	var role_colour := UiTheme.DEFENSE if defending else UiTheme.OFFENSE
	ready_objective.text = "GUARD THE LATA.  TAG ANYONE HOLDING A SLIPPER." if defending \
		else "KNOCK THE LATA DOWN.  RETRIEVE FROM THE BOX."
	ready_objective.add_theme_color_override("font_color", role_colour)
	ready_objective_row.visible = true

func show_countdown_tick(text: String) -> void:
	AudioManager.play_countdown(text)
	countdown_label.text = text
	countdown_label.visible = true
	countdown_label.modulate = UiTheme.HIGHLIGHT
	if _countdown_tween != null and _countdown_tween.is_valid():
		_countdown_tween.kill()
	countdown_label.pivot_offset = countdown_label.size / 2.0
	countdown_label.scale = Vector2(1.8, 1.8)
	_countdown_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_countdown_tween.tween_property(countdown_label, "scale", Vector2.ONE, 0.35)

func hide_countdown() -> void:
	if _countdown_tween != null and _countdown_tween.is_valid():
		_countdown_tween.kill()
	countdown_label.visible = false

func _on_round_started(round_number: int, defender_slot: int) -> void:
	set_round_display(round_number, defender_slot)

func set_round_display(round_number: int, defender_slot: int) -> void:
	var taya_name := seat_name(defender_slot)
	round_label.text = "ROUND %d / %d   ·   TAYA: %s" % [
		maxi(round_number, 1), MatchManagerScript.ROUNDS, taya_name]
	_refresh_scoreboard()
	_refresh_role_accents()

func refresh_you_card() -> void:
	you_card.refresh()
	_refresh_role_accents()

func _on_round_intermission_audio(_next_round: int, _next_defender_slot: int) -> void:
	AudioManager.play("round_end")

func _on_match_won(winning_slot: int) -> void:
	round_label.text = "MATCH OVER"
	var local_char := you_card.get_local_character()
	var mine := local_char != null and is_instance_valid(local_char) 		and local_char.player_slot == winning_slot
	AudioManager.play("match_win" if mine else "round_lose")

func set_downed_flash(active: bool) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if not active:
		downed_flash.visible = false
		return
	downed_flash.visible = true
	downed_flash.modulate.a = DOWNED_FLASH_PEAK
	_flash_tween = create_tween()
	_flash_tween.tween_property(downed_flash, "modulate:a", 0.0, DOWNED_FLASH_TIME)
	_flash_tween.tween_callback(func() -> void:
		_flash_tween = null
		_apply_danger_hold())

const DOWNED_FLASH_TIME: float = 0.45
const DOWNED_FLASH_PEAK: float = 0.45
var _flash_tween: Tween = null



var _score_rows: Array[Control] = []
var _score_stamp: String = ""

func _build_scoreboard() -> void:
	if not _score_rows.is_empty():
		return
	_style_team_card(scoreboard_panel, score_title, UiTheme.AMBER)
	score_title.add_theme_color_override("font_color", UiTheme.AMBER)
	for slot in range(MatchManagerScript.PLAYER_COUNT):
		var row := get_node_or_null("%%ScoreRow%d" % [slot]) as Control
		if row == null:
			push_error("HUD: ScoreRow%d missing from HUD.tscn" % [slot])
			return
		for cell_name in ["Name", "Score"]:
			var cell := row.get_node_or_null(cell_name) as Label
			if cell != null:
				cell.add_theme_color_override("font_outline_color", UiTheme.INK)
		_widen_name_cell(row.get_node_or_null("Name") as Label)
		_build_role_cell(row)
		_score_rows.append(row)

func _build_role_cell(row: Control) -> void:
	if row.get_node_or_null("Role") != null:
		return
	var badge := Label.new()
	badge.name = "Role"
	badge.add_theme_font_size_override("font_size", TAYA_BADGE_FONT_SIZE)
	badge.add_theme_color_override("font_color", UiTheme.CREAM_MUTED)
	badge.add_theme_color_override("font_outline_color", UiTheme.INK)
	badge.add_theme_constant_override("outline_size", 5)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := badge.get_theme_font("font")
	var needed := 54.0
	if font != null:
		needed = ceilf(font.get_string_size(
			TAYA_BADGE, HORIZONTAL_ALIGNMENT_LEFT, -1, TAYA_BADGE_FONT_SIZE).x)
	badge.custom_minimum_size.x = needed
	row.add_child(badge)
	row.move_child(badge, 1)

const TAYA_BADGE_FONT_SIZE: int = 15
const TAYA_BADGE: String = "TAYA"

func _widen_name_cell(cell: Label) -> void:
	if cell == null:
		return
	var font := cell.get_theme_font("font")
	var font_size := cell.get_theme_font_size("font_size")
	if font == null:
		return
	var worst := "W".repeat(CharacterRoster.NAME_MAX)
	var needed := font.get_string_size(worst, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	cell.custom_minimum_size.x = maxf(cell.custom_minimum_size.x, ceilf(needed))


func _refresh_scoreboard() -> void:
	if _score_rows.is_empty():
		return
	var names := PackedStringArray()
	for slot in range(MatchManagerScript.PLAYER_COUNT):
		names.append(seat_name(slot))
	var stamp := "%s|%d|%s" % [str(MatchManager.scores), MatchManager.defender_slot,
		"|".join(names)]
	if stamp == _score_stamp:
		return
	_score_stamp = stamp
	var order := MatchManager.ranking()
	var local_char := you_card.get_local_character()
	var mine := local_char.player_slot if local_char != null and is_instance_valid(local_char) else -1
	for i in _score_rows.size():
		var row: Control = _score_rows[i]
		if i >= order.size():
			row.visible = false
			continue
		var slot: int = order[i]
		row.visible = true
		var is_taya := slot == MatchManager.defender_slot
		var name_label := row.get_node("Name") as Label
		var score_label := row.get_node("Score") as Label
		name_label.text = seat_name(slot)
		var badge := row.get_node_or_null("Role") as Label
		if badge != null:
			badge.text = TAYA_BADGE if is_taya else ""
		score_label.text = str(MatchManager.score_for(slot))
		var colour: Color = UiTheme.DEFENSE if is_taya else UiTheme.OFFENSE
		if slot == mine:
			colour = UiTheme.HIGHLIGHT
		name_label.add_theme_color_override("font_color", colour)
		score_label.add_theme_color_override("font_color", colour)

func _refresh_lata_card() -> void:
	var lata := RoundManager.lata
	if lata == null or not RoundManager.round_active:
		lata_card.visible = false
		return
	lata_card.visible = true
	if _lata_upright_shown != int(lata.is_upright):
		_lata_upright_shown = int(lata.is_upright)
		lata_label.text = "LATA  ·  UPRIGHT" if lata.is_upright else "LATA  ·  DOWN"
		lata_label.add_theme_color_override("font_color",
			UiTheme.DEFENSE if lata.is_upright else UiTheme.OFFENSE)
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		lata_hint_label.visible = false
		return
	var line := ""
	if local_char.is_defender:
		if not lata.is_upright:
			var carrier := local_char.get_node_or_null("Carrier") as Carrier
			var progress: float = carrier.channel_progress() if carrier != null else -1.0
			line = ("RESETTING  %d%%" % int(progress * 100.0)) if progress >= 0.0 \
				else "HOLD E IN THE RING"
	elif RoundManager.throw_cooldown_left() > 0.0:
		line = "THROW LOCKED  %.1fs" % RoundManager.throw_cooldown_left()
	elif not local_char.holding_slipper():
		line = "RETRIEVE A SLIPPER"
	elif local_char.is_inside_box():
		line = "GET OUT OF THE BOX TO THROW"
	if line != _lata_hint_shown:
		_lata_hint_shown = line
		lata_hint_label.text = line
		lata_hint_label.visible = line != ""

func _refresh_stamina(_local_char: CharacterBase) -> void:
	pass


func _on_score_changed(slot: int, _total: int, delta: int, reason: String) -> void:
	if reason == "DEFENSE":
		return
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		return
	if local_char.player_slot != slot:
		return
	show_toast("+%d  %s" % [delta, reason], 1.2)

func _on_lata_knocked(by_slot: int) -> void:
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		return
	if local_char.is_defender:
		show_toast("LATA DOWN  ·  RESET IT", 1.6)
	elif by_slot >= 0 and by_slot != local_char.player_slot:
		show_toast("%s KNOCKED THE LATA DOWN" % [seat_name(by_slot)], 1.2)

func _on_lata_restored() -> void:
	show_toast("LATA IS BACK UP", 1.2)

func _on_attacker_tagged(defender_slot: int, victim_slot: int) -> void:
	var local_char := you_card.get_local_character()
	if local_char == null or not is_instance_valid(local_char):
		return
	if local_char.player_slot == victim_slot:
		show_toast("TAGGED  ·  BACK TO THE SAFE ZONE", 2.0)
	elif local_char.player_slot == defender_slot:
		show_toast("TAG  ·  %s" % [seat_name(victim_slot)], 1.4)

static func seat_name(slot: int) -> String:
	var who := RoundManager.player_at(slot)
	return who.display_name() if who != null else "P%d" % [slot + 1]

