extends Node
class_name Carrier


const CHARGE_FULL_TIME: float = 2.5
const CHARGE_MIN_POWER: float = 0.35
const THROW_LOCK_TIME: float = 1.25
const PICKUP_RADIUS: float = 1.4
const AIM_RAY_LENGTH: float = 40.0
const MUZZLE_FORWARD: float = 0.15

signal charge_changed(power: float)
signal held_changed(held: Slipper)
signal reset_channel_changed(progress: float)

var _character: CharacterBase = null
var _held: Slipper = null
var _charge_time: float = 0.0
var _is_charging: bool = false
var _throw_lock_left: float = 0.0
var _channel_time: float = 0.0
var _channelling: bool = false
var _grab_consumed_this_frame: bool = false
var _trajectory: TrajectoryPreview = null

var _observed_charge_time: float = -1.0

func _ready() -> void:
	_character = get_parent() as CharacterBase

func _physics_process(delta: float) -> void:
	if _throw_lock_left > 0.0:
		_throw_lock_left = maxf(0.0, _throw_lock_left - delta)
	if _observed_charge_time >= 0.0:
		_observed_charge_time = minf(_observed_charge_time + delta, CHARGE_FULL_TIME)


func held() -> Slipper:
	if _held != null and not is_instance_valid(_held):
		_held = null
	if _held != null and _held.state != Slipper.CarryState.CARRIED:
		_set_held(null)
	return _held

func is_charging() -> bool:
	return _is_charging

func throw_lock_left() -> float:
	return _throw_lock_left

func is_busy() -> bool:
	return _is_charging or _channelling or _grab_consumed_this_frame

func charge_power() -> float:
	if not _is_charging:
		return 0.0
	return clampf(lerpf(CHARGE_MIN_POWER, 1.0, _charge_time / CHARGE_FULL_TIME),
		CHARGE_MIN_POWER, 1.0)

func observed_charge_power() -> float:
	if _observed_charge_time < 0.0:
		return -1.0
	return clampf(_observed_charge_time / CHARGE_FULL_TIME, 0.0, 1.0)

func channel_progress() -> float:
	if not _channelling:
		return -1.0
	return clampf(_channel_time / _reset_channel_time(), 0.0, 1.0)

func _reset_channel_time() -> float:
	var lata := RoundManager.lata
	return lata.reset_channel_time() if lata != null else Lata.RESET_CHANNEL_TIME


func input_step(delta: float) -> void:
	held()
	_grab_consumed_this_frame = false
	_step_grab()
	_step_reset_channel(delta)
	_step_throw(delta)

func _step_grab() -> void:
	if _held != null or not _character.input_just_pressed("grab"):
		return
	if _character.is_defender:
		return
	var target := _find_grabbable()
	if target == null:
		return
	_character.broadcast_visual_action("grab")
	_request_grab(target)
	_grab_consumed_this_frame = true

func _find_grabbable() -> Slipper:
	var best: Slipper = null
	var best_distance := PICKUP_RADIUS
	for node in _character.get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null or not slipper.can_be_grabbed_by(_character):
			continue
		var distance := _character.global_position.distance_to(slipper.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = slipper
	return best

func _step_reset_channel(delta: float) -> void:
	if not _character.is_defender or _held != null:
		_cancel_channel()
		return
	if not _character.input_pressed("grab"):
		_cancel_channel()
		return
	var lata := RoundManager.lata
	if lata == null or not lata.can_be_reset_by(_character):
		_cancel_channel()
		return
	if not _channelling:
		_channelling = true
		_channel_time = 0.0
		AudioManager.play_at("reset_channel_start", _character.global_position)
	_channel_time += delta
	reset_channel_changed.emit(channel_progress())
	if _channel_time < _reset_channel_time():
		return
	_cancel_channel()
	_character.broadcast_visual_action("grab")
	_request_reset()

func _cancel_channel() -> void:
	if not _channelling:
		return
	_channelling = false
	_channel_time = 0.0
	reset_channel_changed.emit(-1.0)

func _step_throw(delta: float) -> void:
	if _held == null:
		_cancel_charge()
		return
	if not _is_charging and _character.input_pressed("special_ability"):
		if not RoundManager.can_throw(_character):
			return
		if _throw_lock_left > 0.0:
			return
		_is_charging = true
		_charge_time = 0.0
		_broadcast_charge(true)
		AudioManager.play_at("throw_charge", _character.global_position)
	elif _is_charging and _character.input_pressed("special_ability"):
		_charge_time = minf(_charge_time + delta, CHARGE_FULL_TIME)
		charge_changed.emit(charge_power())
		_update_trajectory()
		if not RoundManager.can_throw(_character):
			_cancel_charge()
	elif _is_charging:
		var power := charge_power()
		_cancel_charge()
		if RoundManager.can_throw(_character):
			_character.broadcast_visual_action("throw")
			_request_throw(power)

func _cancel_charge() -> void:
	if not _is_charging:
		return
	_is_charging = false
	_charge_time = 0.0
	charge_changed.emit(0.0)
	_broadcast_charge(false)
	if _trajectory != null:
		_trajectory.clear()

func _broadcast_charge(active: bool) -> void:
	if NetworkManager.is_networked():
		_rpc_charge_visual.rpc(active)
	else:
		_rpc_charge_visual(active)

@rpc("any_peer", "call_local", "reliable")
func _rpc_charge_visual(active: bool) -> void:
	_observed_charge_time = 0.0 if active else -1.0


func _aim_direction() -> Vector3:
	var rig := _character.get_node_or_null("CameraRig") as CameraRig
	if rig != null:
		return -rig.get_aim_basis().z
	return -_character.global_transform.basis.z

func _aim_point() -> Vector3:
	if _character.is_ai_driven() and _character.ai_aim_point != Vector3.INF:
		return _character.ai_aim_point
	var origin := _character.global_position
	var direction := _aim_direction()
	var rig := _character.get_node_or_null("CameraRig") as CameraRig
	if rig != null and rig.fpp_camera != null:
		origin = rig.fpp_camera.global_position
	var space := _character.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * AIM_RAY_LENGTH)
	query.exclude = [_character.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return origin + direction * AIM_RAY_LENGTH
	return hit["position"]

func _throw_origin() -> Vector3:
	var rig := _character.get_node_or_null("CameraRig") as CameraRig
	if rig == null or rig.fpp_camera == null:
		return _character.global_position + Vector3.UP * 0.9
	return rig.fpp_camera.global_position + _aim_direction() * MUZZLE_FORWARD

static func throw_origin_for(thrower: CharacterBase, aim_point: Vector3) -> Vector3:
	if thrower == null:
		return aim_point
	var rig := thrower.get_node_or_null("CameraRig") as CameraRig
	if rig == null or rig.fpp_camera == null:
		return thrower.global_position + Vector3.UP * 0.9
	var eye := rig.fpp_camera.global_position
	var to_aim := aim_point - eye
	if to_aim.length() < 0.01:
		return eye
	return eye + to_aim.normalized() * MUZZLE_FORWARD

func _ensure_trajectory() -> void:
	if _trajectory != null and is_instance_valid(_trajectory):
		return
	_trajectory = TrajectoryPreview.new()
	_character.get_tree().current_scene.add_child(_trajectory)

func _update_trajectory() -> void:
	var is_mine := _character.is_multiplayer_authority() if NetworkManager.is_networked() \
		else _character.player_id == 1
	if not is_mine or _character.is_ai_driven():
		return
	var rig := _character.get_node_or_null("CameraRig") as CameraRig
	if rig == null or not rig.is_local_fpp():
		if _trajectory != null and is_instance_valid(_trajectory):
			_trajectory.clear()
		return
	_ensure_trajectory()
	var origin := _throw_origin()
	_trajectory.draw_arc(origin,
		Slipper.launch_velocity_for(origin, _aim_point(), charge_power(),
			_held.speed_scale()),
		CharacterBase.GRAVITY, UiTheme.OFFENSE, _held.rest_height())


func _request_grab(target: Slipper) -> void:
	if not NetworkManager.is_networked() or NetworkManager.is_host():
		target.host_grab(_character)
		return
	_rpc_request_grab.rpc_id(1, target.get_path())

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_grab(target_path: NodePath) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var target := _resolve_slipper(target_path)
	if target != null:
		target.host_grab(_character)

func _request_throw(power: float) -> void:
	var slipper := held()
	if slipper == null:
		return
	var origin := _throw_origin()
	var point := _aim_point()
	if not NetworkManager.is_networked() or NetworkManager.is_host():
		slipper.host_throw(_character, origin, point, power)
		return
	_rpc_request_throw.rpc_id(1, slipper.get_path(), origin, point, power)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_throw(target_path: NodePath, origin: Vector3, point: Vector3,
		power: float) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var target := _resolve_slipper(target_path)
	if target != null:
		target.host_throw(_character, origin, point, clampf(power, 0.0, 1.0))

func _resolve_slipper(target_path: NodePath) -> Slipper:
	var direct := get_node_or_null(target_path) as Slipper
	if direct != null:
		return direct
	var parts := target_path.get_name_count()
	if parts == 0:
		return null
	var wanted := target_path.get_name(parts - 1)
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper != null and slipper.name == wanted:
			return slipper
	return null

func _request_reset() -> void:
	if not NetworkManager.is_networked() or NetworkManager.is_host():
		if RoundManager.lata != null:
			RoundManager.lata.host_restore()
		return
	_rpc_request_reset.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_reset() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var lata := RoundManager.lata
	if lata != null and lata.can_be_reset_by(_character):
		lata.host_restore()


func notify_holding(what: Slipper) -> void:
	_set_held(what)
	if what != null:
		_throw_lock_left = THROW_LOCK_TIME / what.grit_scale()

func _set_held(what: Slipper) -> void:
	if _held == what:
		return
	_held = what
	held_changed.emit(what)

func reset_for_new_round() -> void:
	_cancel_charge()
	_cancel_channel()
	_set_held(null)
	_throw_lock_left = 0.0
	_observed_charge_time = -1.0
	if _trajectory != null and is_instance_valid(_trajectory):
		_trajectory.clear()

