extends Node


const UNIT_NAMES: Array[String] = ["Player1", "Player2", "Player3", "Player4"]
const DEFAULT_UNIT: String = "Player1"

var _slot_unit: String = DEFAULT_UNIT
var _bar: DebugBar = null

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS

func _default_unit() -> String:
	for unit_name in UNIT_NAMES:
		var unit := _find_unit(unit_name)
		if unit == null:
			continue
		if unit.ai_controller == null or not unit.ai_controller.is_enabled():
			return unit_name
	return DEFAULT_UNIT

func debug_register_bar(bar: DebugBar) -> void:
	_bar = bar
	_resolve_default.call_deferred()

func _resolve_default() -> void:
	if _bar == null:
		return
	_slot_unit = _default_unit()
	if NetworkManager.is_networked():
		_refresh_bar()
	else:
		_apply_slots()

func debug_unregister_bar() -> void:
	_bar = null

func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	if NetworkManager.is_networked():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode

	match code:
		KEY_F1, KEY_F2, KEY_F3, KEY_F4:
			_assign(UNIT_NAMES[code - KEY_F1])
		KEY_TAB:
			_cycle()
		KEY_F6:
			_assign(_default_unit())
		_:
			return
	get_viewport().set_input_as_handled()

func _is_active() -> bool:
	if _bar == null:
		return false
	if NetworkManager.is_networked():
		return NetworkManager.is_solo_session() and _solo_networked_unit() != null
	return _find_unit(UNIT_NAMES[0]) != null

func _match_root() -> Node:
	var node: Node = _bar
	while node != null:
		if node.has_node(UNIT_NAMES[0]):
			return node
		node = node.get_parent()
	return null

func _find_unit(unit_name: String) -> CharacterBase:
	var scene := _match_root()
	if scene == null:
		return null
	return scene.get_node_or_null(unit_name) as CharacterBase

func _solo_networked_unit() -> CharacterBase:
	var node: Node = _bar
	var players: Node = null
	while node != null:
		if node.has_node("Players"):
			players = node.get_node("Players")
			break
		node = node.get_parent()
	if players == null:
		return null
	for child in players.get_children():
		var character := child as CharacterBase
		if character != null and character.is_multiplayer_authority() and character.ai_controller == null:
			return character
	return null

func _assign(unit_name: String) -> void:
	_slot_unit = unit_name
	_apply_slots()

func _cycle() -> void:
	var start := UNIT_NAMES.find(_slot_unit)
	_slot_unit = UNIT_NAMES[(start + 1) % UNIT_NAMES.size()]
	_apply_slots()

func _apply_slots() -> void:
	for unit_name in UNIT_NAMES:
		var unit := _find_unit(unit_name)
		if unit == null:
			continue
		var is_driven := unit_name == _slot_unit
		unit.input_parked = not is_driven
		if unit.ai_controller != null:
			unit.ai_controller.set_enabled(not is_driven)

		unit.is_bot = not is_driven
		if is_driven and unit.player_name == "":
			unit.player_name = SettingsManager.player_name

		var rig := unit.get_node_or_null("CameraRig") as CameraRig
		if rig != null:
			rig.set_active(is_driven)
			rig.set_aim_source(CameraRig.AimSource.MOUSE if is_driven else CameraRig.AimSource.MOVEMENT)

	_refresh_bar()

func _describe() -> String:
	if _slot_unit == "":
		return "—"
	return _describe_unit(_find_unit(_slot_unit), _slot_unit)

func _describe_unit(unit: CharacterBase, label: String) -> String:
	if unit == null:
		return "%s (missing)" % label
	var side := "TAYA" if unit.is_defender else "ATTACKER"
	return "%s (%s · %s)" % [label, unit.display_name(), side]

func debug_refresh_readout() -> void:
	_refresh_bar()

func _refresh_bar() -> void:
	if _bar == null:
		return
	if NetworkManager.is_networked():
		_bar.debug_refresh(_describe_unit(_solo_networked_unit(), "you"))
	else:
		_bar.debug_refresh(_describe())

