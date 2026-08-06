extends Control
class_name YouCard


const REFRESH_INTERVAL: float = 0.15
const READY_FLASH_DURATION: float = 0.2
const CHARGE_SHADER_PARAM: StringName = &"charge_ratio"

@onready var card: PanelContainer = %Card
@onready var class_label: Label = %ClassLabel
@onready var detail_label: Label = %DetailLabel
@onready var guard_dash_row: HBoxContainer = %GuardDashRow
@onready var guard_dash_key_label: Label = %GuardDashKeyLabel
@onready var guard_dash_bar: ProgressBar = %GuardDashBar
@onready var charge_row: HBoxContainer = %ChargeRow
@onready var charge_key_label: Label = %ChargeKeyLabel
@onready var charge_bar: ProgressBar = %ChargeBar
@onready var reset_channel_row: HBoxContainer = %ResetChannelRow
@onready var reset_channel_key_label: Label = %ResetChannelKeyLabel
@onready var reset_channel_bar: ProgressBar = %ResetChannelBar

var _refresh_accum: float = 0.0
var _character: CharacterBase = null
var _was_ready: bool = true
var _bar_flash_tween: Tween = null
var _carrier: Carrier = null
var _is_attacker_person: bool = false
var _is_defender_person: bool = false
var _charging: bool = false
var _channeling: bool = false

func _ready() -> void:
	MatchManager.round_started.connect(func(_round_number, _defender_slot): refresh())
	guard_dash_bar.add_theme_stylebox_override("fill", _bar_style(UiTheme.HIGHLIGHT))
	guard_dash_bar.add_theme_stylebox_override("background", _bar_style(UiTheme.CARD))
	charge_bar.add_theme_stylebox_override("fill", _bar_style(UiTheme.OFFENSE))
	charge_bar.add_theme_stylebox_override("background", _bar_style(UiTheme.CARD))
	reset_channel_bar.add_theme_stylebox_override("fill", _bar_style(UiTheme.DEFENSE))
	reset_channel_bar.add_theme_stylebox_override("background", _bar_style(UiTheme.CARD))
	refresh()

func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= REFRESH_INTERVAL:
		_refresh_accum = 0.0
		refresh()
	_update_guard_dash_meter()
	_update_bump_meter()

func refresh() -> void:
	_character = _find_local_character()
	if _character == null or not is_instance_valid(_character):
		visible = false
		_set_carrier(null)
		return
	visible = true
	var is_defense := _character.is_defender
	class_label.text = "TAYA (DEFENDER)" if is_defense else "ATTACKER"
	detail_label.text = _character.display_name()
	var accent := UiTheme.DEFENSE if is_defense else UiTheme.OFFENSE
	var sb := UiTheme.wood_style(UiTheme.WOOD_DEEP, accent)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	card.add_theme_stylebox_override("panel", sb)
	class_label.add_theme_color_override("font_color", UiTheme.CREAM)
	detail_label.add_theme_color_override("font_color", accent)
	guard_dash_row.visible = true
	guard_dash_key_label.text = _guard_dash_key_label(_character)
	guard_dash_key_label.visible = guard_dash_key_label.text != ""
	_is_attacker_person = _character.is_person and not is_defense
	_is_defender_person = _character.is_person and is_defense
	if _is_attacker_person:
		charge_key_label.text = "[%s]" % _action_key_label(_character, "special_ability")
	if _is_defender_person:
		reset_channel_key_label.text = "RIGHTING LATA [%s]" % _action_key_label(_character, "grab")
	_set_carrier(_character.get_node_or_null("Carrier") as Carrier)
	_update_row_visibility()

func _update_guard_dash_meter() -> void:
	if _character == null or not is_instance_valid(_character):
		return
	var ratio: float = _character.get_stamina_ratio()
	guard_dash_bar.value = ratio * guard_dash_bar.max_value
	var fatigued: bool = _character.is_fatigued()
	if fatigued != _was_fatigued:
		_was_fatigued = fatigued
		guard_dash_bar.add_theme_stylebox_override("fill",
			_bar_style(UiTheme.DANGER if fatigued else UiTheme.HIGHLIGHT))
		guard_dash_key_label.text = "FATIGUED" if fatigued else _sprint_key_text()
		guard_dash_key_label.add_theme_color_override("font_color",
			UiTheme.DANGER if fatigued else UiTheme.CREAM_MUTED)
		guard_dash_key_label.visible = guard_dash_key_label.text != ""
	var is_ready := ratio >= 1.0
	if is_ready and not _was_ready and not fatigued:
		_flash_bar_ready()
	_was_ready = is_ready

var _was_fatigued: bool = false

func _sprint_key_text() -> String:
	return ""

func _flash_bar_ready() -> void:
	if _bar_flash_tween != null and _bar_flash_tween.is_valid():
		_bar_flash_tween.kill()
	var style := _bar_style(UiTheme.CARD)
	guard_dash_bar.add_theme_stylebox_override("fill", style)
	_bar_flash_tween = create_tween()
	_bar_flash_tween.tween_property(style, "bg_color", UiTheme.HIGHLIGHT, READY_FLASH_DURATION)

func _bar_style(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(UiTheme.CORNER_RADIUS)
	return sb

func _guard_dash_key_label(_character_unused: CharacterBase) -> String:
	return _sprint_key_text()

func _action_key_label(character: CharacterBase, base_action: String) -> String:
	for event in InputMap.action_get_events(character.action_name(base_action)):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode().to_upper()
	return "?"


func _set_carrier(carrier: Carrier) -> void:
	if carrier == _carrier:
		return
	if _carrier != null and is_instance_valid(_carrier):
		if _carrier.charge_changed.is_connected(_on_charge_changed):
			_carrier.charge_changed.disconnect(_on_charge_changed)
		if _carrier.held_changed.is_connected(_on_held_changed):
			_carrier.held_changed.disconnect(_on_held_changed)
		if _carrier.reset_channel_changed.is_connected(_on_reset_channel_changed):
			_carrier.reset_channel_changed.disconnect(_on_reset_channel_changed)
	_carrier = carrier
	_charging = false
	_channeling = false
	if _carrier != null:
		_carrier.charge_changed.connect(_on_charge_changed)
		_carrier.held_changed.connect(_on_held_changed)
		_carrier.reset_channel_changed.connect(_on_reset_channel_changed)

func _on_charge_changed(power: float) -> void:
	_charging = power >= 0.0
	if _charging:
		charge_bar.value = power * charge_bar.max_value
	_set_charge_shader_param(power if _charging else 0.0)
	_update_row_visibility()

func _set_charge_shader_param(ratio: float) -> void:
	var mat := charge_bar.material
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter(CHARGE_SHADER_PARAM, ratio)

func _on_held_changed(_held: Slipper) -> void:
	pass

func _on_reset_channel_changed(progress: float) -> void:
	_channeling = progress >= 0.0
	if _channeling:
		reset_channel_bar.value = progress * reset_channel_bar.max_value
	_update_row_visibility()

func _update_row_visibility() -> void:
	charge_row.visible = (_is_attacker_person and _charging) or _bump_charging
	reset_channel_row.visible = _is_defender_person and _channeling

var _bump_charging: bool = false

func _update_bump_meter() -> void:
	if _character == null or not is_instance_valid(_character) or not _character.is_defender:
		_bump_charging = false
		return
	var ratio: float = _character.observed_lunge_charge()
	var was := _bump_charging
	_bump_charging = ratio >= 0.0
	if _bump_charging:
		charge_bar.value = ratio * charge_bar.max_value
		_set_charge_shader_param(ratio)
		charge_key_label.text = "LUNGE [%s]" % _action_key_label(_character, "lunge")
	elif was:
		_set_charge_shader_param(0.0)
	if was != _bump_charging:
		_update_row_visibility()

func get_local_character() -> CharacterBase:
	if not is_instance_valid(_character):
		return null
	return _character

func _find_local_character() -> CharacterBase:
	if NetworkManager.is_networked():
		var main := get_tree().current_scene
		if main and main.has_method("get_local_character"):
			return main.get_local_character()
		return null
	return _find_hardware_character(get_tree().current_scene)

func _find_hardware_character(node: Node) -> CharacterBase:
	var ch := node as CharacterBase
	if ch != null:
		var ai_driven: bool = ch.ai_controller != null and ch.ai_controller.is_enabled()
		if not ai_driven and not ch.input_parked:
			return ch
	for child in node.get_children():
		var found := _find_hardware_character(child)
		if found:
			return found
	return null

