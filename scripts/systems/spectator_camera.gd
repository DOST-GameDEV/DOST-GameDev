extends Node3D
class_name SpectatorCamera


const BASE_SPEED: float = 3.6
const BOOST_SCALE: float = 2.5
const SPEED_MIN: float = 1.2
const SPEED_MAX: float = 40.0
const SPEED_STEP: float = 1.35
const PITCH_LIMIT_DEG: float = 88.0
const MOVE_SMOOTH_RATE: float = 14.0

const FOLLOW_DISTANCE: float = 6.5
const FOLLOW_DISTANCE_MIN: float = 1.2
const FOLLOW_DISTANCE_MAX: float = 30.0
const FOLLOW_LIFT_RATIO: float = 0.34

const POV_EYE_HEIGHT_PERSON: float = 1.45
const POV_EYE_HEIGHT_PROP: float = 0.42
const POV_FORWARD_OFFSET: float = 0.34

var _yaw: float = 0.0
var _pitch_deg: float = -18.0
var _speed: float = BASE_SPEED
var _target_position: Vector3 = Vector3.ZERO
var _camera: Camera3D = null
var _follow: Node3D = null
var _follow_index: int = -1
var _follow_distance: float = FOLLOW_DISTANCE
var _pov: bool = false

func _ready() -> void:
	_camera = Camera3D.new()
	_camera.name = "SpectatorCamera3D"
	_camera.fov = 78.0
	_camera.far = 400.0
	add_child(_camera)
	_camera.current = true
	global_position = Vector3(0.0, 9.0, 14.0)
	_target_position = global_position
	_yaw = 0.0
	_pitch_deg = -26.0
	_apply_rotation()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sensitivity := CameraRig.BASE_SENSITIVITY * SettingsManager.mouse_sensitivity
		_yaw -= deg_to_rad(motion.relative.x * sensitivity)
		var pitch_delta := motion.relative.y * sensitivity
		if SettingsManager.invert_y:
			pitch_delta = -pitch_delta
		_pitch_deg = clampf(_pitch_deg - pitch_delta, -PITCH_LIMIT_DEG, PITCH_LIMIT_DEG)
		_apply_rotation()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button := (event as InputEventMouseButton).button_index
		var following := _follow != null and is_instance_valid(_follow)
		if button == MOUSE_BUTTON_WHEEL_UP:
			if following:
				_follow_distance = clampf(_follow_distance / SPEED_STEP,
					FOLLOW_DISTANCE_MIN, FOLLOW_DISTANCE_MAX)
			else:
				_speed = clampf(_speed * SPEED_STEP, SPEED_MIN, SPEED_MAX)
		elif button == MOUSE_BUTTON_WHEEL_DOWN:
			if following:
				_follow_distance = clampf(_follow_distance * SPEED_STEP,
					FOLLOW_DISTANCE_MIN, FOLLOW_DISTANCE_MAX)
			else:
				_speed = clampf(_speed / SPEED_STEP, SPEED_MIN, SPEED_MAX)
		return

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_TAB:
			_cycle_follow()
			get_viewport().set_input_as_handled()
		KEY_F:
			_follow = null
			_follow_index = -1
			_pov = false
			get_viewport().set_input_as_handled()
		KEY_V:
			if _follow != null and is_instance_valid(_follow):
				_pov = not _pov
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _camera != null and not _camera.current:
		_camera.current = true
	if _follow != null and is_instance_valid(_follow):
		if _pov:
			_target_position = (_follow.global_position
				+ Vector3.UP * _pov_eye_height()
				+ (-_follow.global_transform.basis.z) * POV_FORWARD_OFFSET)
			global_position = _target_position
			_yaw = _follow.global_rotation.y
			_apply_rotation()
			return
		var back := -_camera_forward()
		_target_position = (_follow.global_position
			+ Vector3.UP * (_follow_distance * FOLLOW_LIFT_RATIO)
			+ back * _follow_distance)
	else:
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var move := _camera_forward() * -input_dir.y + _camera_right() * input_dir.x
		if Input.is_action_pressed("jump"):
			move += Vector3.UP
		if Input.is_action_pressed("spectator_down"):
			move += Vector3.DOWN
		if move.length() > 0.001:
			var speed := _speed * (BOOST_SCALE if Input.is_action_pressed("sprint") else 1.0)
			_target_position += move.normalized() * speed * delta
	var t: float = 1.0 - exp(-MOVE_SMOOTH_RATE * delta)
	global_position = global_position.lerp(_target_position, t)

func _apply_rotation() -> void:
	rotation = Vector3(deg_to_rad(_pitch_deg), _yaw, 0.0)

func _camera_forward() -> Vector3:
	return -global_transform.basis.z

func _camera_right() -> Vector3:
	return global_transform.basis.x

func _cycle_follow() -> void:
	var units: Array[Node] = []
	for node in get_tree().get_nodes_in_group("spectatable"):
		if node is Node3D and is_instance_valid(node):
			units.append(node)
	if units.is_empty():
		for node in get_tree().current_scene.find_children("*", "CharacterBase", true, false):
			units.append(node)
	if units.is_empty():
		_follow = null
		_follow_index = -1
		return
	_follow_index += 1
	if _follow_index >= units.size():
		_follow = null
		_follow_index = -1
		_target_position = global_position
		return
	_follow = units[_follow_index] as Node3D

static func controls_text() -> String:
	return "SPECTATOR    WASD fly · SPACE up · CTRL down · SHIFT boost · TAB follow · V POV · F free · WHEEL speed, or follow distance while following"

func status_text() -> String:
	if _follow != null and is_instance_valid(_follow):
		if _pov:
			return "POV  %s  ·  through their eyes" % _follow_name()
		return "FOLLOWING  %s  ·  %.1f m" % [_follow_name(), _follow_distance]
	return "FREE FLIGHT  ·  %.1f m/s" % _speed

func _pov_eye_height() -> float:
	var character := _follow as CharacterBase
	if character == null or character.is_person:
		return POV_EYE_HEIGHT_PERSON
	return POV_EYE_HEIGHT_PROP

func _follow_name() -> String:
	var character := _follow as CharacterBase
	if character == null:
		return String(_follow.name)
	return "%s · %s" % [character.display_name(),
		"TAYA" if character.is_defender else "ATTACKER"]

