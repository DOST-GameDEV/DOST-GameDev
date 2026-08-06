extends Node3D
class_name CameraRig


enum Mode { FPP, TPP }
enum AimSource { MOUSE, MOVEMENT }

const PITCH_MIN_DEG: float = -80.0
const PITCH_MAX_DEG: float = 70.0
const BASE_SENSITIVITY: float = 0.15
const FPP_HIDDEN_MESH_HINT: String = "head"

const VIEWMODEL_ARMS_SCENE: String = "res://scenes/characters/visuals/ViewmodelArms.tscn"
const VIEWMODEL_SCALE: float = 0.72
const VIEWMODEL_SEAT: Vector3 = Vector3(0.0, -0.10, -0.16)

const TPP_MOUNT_CLEARANCE_AT_PERSON_SCALE: float = 0.4
const TPP_CARRY_MOUNT_HEIGHT: float = 0.6
const PERSON_CAPSULE_HEIGHT: float = 1.6

const TPP_MIN_SPRING_LENGTH: float = 1.8
const TPP_MIN_PITCH_DEG: float = -34.0

@export var aim_source: AimSource = AimSource.MOVEMENT

@onready var fpp_pivot: Node3D = $FppPivot
@onready var fpp_camera: Camera3D = $FppPivot/FppCamera
@onready var tpp_arm: SpringArm3D = $TppArm
@onready var tpp_camera: Camera3D = $TppArm/TppCamera

var _character: CharacterBase
var _mode: Mode
var _pitch_deg: float = 0.0
var _active: bool = false
var _tpp_carry_yaw_deg: float = 0.0
var _tpp_base_spring_length: float = 4.5
var _tpp_base_pitch_deg: float = -15.0
var _tpp_pitch_deg: float = -15.0
var _tpp_mount_height: float = 1.2
var _fpp_eye_height: float = 0.45
var _hidden_carried_visual: Node3D = null
var _tpp_carry_pitch_deg: float = 0.0
var _tpp_excluded_carrier: CharacterBase = null
var _arms: Node3D = null
var _viewmodel_rest: Transform3D = Transform3D.IDENTITY

const VM_KICK_TIME: float = 0.22
const VM_KICKS: Dictionary = {
	"punch": {"push": 0.30, "lift": -0.04, "roll": 0.10},
	"shove": {"push": 0.24, "lift": 0.05, "roll": -0.14},
	"lunge": {"push": 0.34, "lift": 0.07, "roll": 0.05},
	"throw": {"push": 0.26, "lift": 0.10, "roll": -0.08},
	"grab": {"push": 0.06, "lift": -0.22, "roll": 0.0},
}
var _vm_kick_left: float = 0.0
var _vm_kick: Dictionary = {}

var _shake_strength: float = 0.0
var _shake_duration: float = 0.18
var _shake_time_left: float = 0.0
var _fpp_camera_base_position: Vector3 = Vector3.ZERO
var _tpp_camera_base_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	_character = get_parent() as CharacterBase
	_mode = Mode.FPP if _character.is_person else Mode.TPP
	assert((_mode == Mode.FPP) == _character.is_person,
		"Camera directive: Person is always FPP, Prop is always TPP (Dev_Plan §0.1)")
	_fpp_camera_base_position = fpp_camera.position
	_tpp_camera_base_position = tpp_camera.position
	tpp_arm.add_excluded_object(_character.get_rid())
	_tpp_base_spring_length = tpp_arm.spring_length
	_tpp_base_pitch_deg = tpp_arm.rotation_degrees.x
	_tpp_pitch_deg = _tpp_base_pitch_deg
	_tpp_mount_height = tpp_arm.position.y
	_fpp_eye_height = fpp_pivot.position.y
	var visual := _character.get_node_or_null("Visual") as CharacterVisual
	if visual != null:
		visual.model_changed.connect(_apply_fpp_self_hide)
		visual.model_changed.connect(_apply_tpp_framing)
	var carrier := _character.get_node_or_null("Carrier") as Carrier
	if carrier != null:
		carrier.held_changed.connect(_on_held_changed)
	_apply_fpp_self_hide()
	_apply_tpp_framing()
	set_active(false)
	set_process_unhandled_input(false)
	if NetworkManager.is_networked():
		var is_mine := _character.is_multiplayer_authority() and _character.ai_controller == null
		set_active(is_mine)
		set_aim_source(AimSource.MOUSE if is_mine else AimSource.MOVEMENT)

func _body_yaw() -> float:
	var forward := -_character.global_transform.basis.z
	if absf(forward.x) < 0.00001 and absf(forward.z) < 0.00001:
		return _character.global_rotation.y
	return atan2(-forward.x, -forward.z)

func _apply_upright_pose() -> void:
	if _character == null:
		return
	if _emote_view:
		tpp_arm.global_transform = Transform3D(
			Basis(Vector3.UP, deg_to_rad(_emote_yaw_deg))
				* Basis(Vector3.RIGHT, deg_to_rad(_emote_pitch_deg)),
			_character.global_position + Vector3.UP * _tpp_mount_height)
		return
	var yaw := Basis(Vector3.UP, _body_yaw())
	if _mode == Mode.FPP:
		fpp_pivot.global_transform = Transform3D(
			yaw * Basis(Vector3.RIGHT, deg_to_rad(_pitch_deg)),
			_character.global_position + Vector3.UP * _fpp_eye_height)
		return
	tpp_arm.global_transform = Transform3D(
		yaw * Basis(Vector3.RIGHT, deg_to_rad(_tpp_pitch_deg)),
		_character.global_position + Vector3.UP * _tpp_mount_height)

func _apply_tpp_framing() -> void:
	if _mode != Mode.TPP or _character == null:
		return
	var ratio := clampf(_character.capsule_height() / PERSON_CAPSULE_HEIGHT, 0.0, 1.0)
	tpp_arm.spring_length = lerpf(TPP_MIN_SPRING_LENGTH, _tpp_base_spring_length, ratio)
	_tpp_pitch_deg = lerpf(TPP_MIN_PITCH_DEG, _tpp_base_pitch_deg, ratio)
	tpp_arm.rotation_degrees.x = _tpp_pitch_deg

func _mount_height_for(capsule_height: float) -> float:
	var clearance := TPP_MOUNT_CLEARANCE_AT_PERSON_SCALE * (capsule_height / PERSON_CAPSULE_HEIGHT)
	return capsule_height / 2.0 + clearance

const EMOTE_PITCH_MIN_DEG: float = -35.0
const EMOTE_PITCH_MAX_DEG: float = 20.0

var _emote_view: bool = false
var _emote_yaw_deg: float = 0.0
var _emote_pitch_deg: float = 0.0
var _mode_before_emote: Mode = Mode.FPP

func is_emote_view() -> bool:
	return _emote_view

func begin_emote_view() -> void:
	if _emote_view:
		return
	_mode_before_emote = _mode
	_emote_view = true
	_emote_yaw_deg = rad_to_deg(_body_yaw())
	_emote_pitch_deg = _tpp_pitch_deg
	_mode = Mode.TPP
	_apply_emote_view()

func end_emote_view() -> void:
	if not _emote_view:
		return
	_emote_view = false
	_mode = _mode_before_emote
	_apply_emote_view()

func _apply_emote_view() -> void:
	fpp_camera.current = _active and _mode == Mode.FPP
	tpp_camera.current = _active and _mode == Mode.TPP
	_apply_fpp_self_hide()
	var arms := _arms
	if arms != null and is_instance_valid(arms):
		arms.visible = _active and _mode == Mode.FPP
	_apply_tpp_framing()

func set_active(active: bool) -> void:
	_active = active
	fpp_camera.current = active and _mode == Mode.FPP
	tpp_camera.current = active and _mode == Mode.TPP
	set_process(active)
	set_process_unhandled_input(active and aim_source == AimSource.MOUSE)
	_apply_fpp_self_hide()

func is_local_fpp() -> bool:
	return _active and _mode == Mode.FPP

func set_aim_source(source: AimSource) -> void:
	aim_source = source
	set_process_unhandled_input(_active and aim_source == AimSource.MOUSE)

func get_aim_basis() -> Basis:
	if _mode == Mode.FPP:
		return fpp_camera.global_transform.basis
	return tpp_camera.global_transform.basis

func shake(strength: float = 0.35, duration: float = 0.18) -> void:
	var remaining_ratio := _shake_time_left / _shake_duration if _shake_duration > 0.0 else 0.0
	var current_effective_strength := _shake_strength * remaining_ratio
	if strength > current_effective_strength:
		_shake_strength = strength
		_shake_duration = duration
		_shake_time_left = duration

const VIEWMODEL_ARM_LENGTH: float = 0.84
const VIEWMODEL_CARRY_DIR: Vector3 = Vector3(-0.447, 0.745, -0.477)
const VIEWMODEL_CARRY_SCALE: float = 0.55
const VIEWMODEL_REACH_SPEED: float = 14.0
const VIEWMODEL_CARRY_ANCHOR: Vector3 = Vector3(0.26, -0.16, -0.48)


func _update_viewmodel_carry(delta: float) -> void:
	var arms := _viewmodel_arms()
	if arms == null or not arms.visible:
		return
	var pivot := arms.get_node_or_null("RightPivot") as Node3D
	if pivot == null:
		return
	if _viewmodel_rest == Transform3D.IDENTITY:
		_viewmodel_rest = pivot.transform

	var carrier := _character.get_node_or_null("Carrier") as Carrier
	var held: Slipper = carrier.held() if carrier != null else null
	var holding := held != null and is_instance_valid(held)
	var slipper := pivot.get_node_or_null("Arm/HeldSlipper") as MeshInstance3D
	if slipper != null:
		slipper.visible = holding
		if holding:
			_sync_viewmodel_slipper(slipper, held)
	_apply_carried_self_hide(true)
	if _vm_kick_left > 0.0:
		_vm_kick_left = maxf(0.0, _vm_kick_left - delta)
	var wanted := _viewmodel_rest
	if holding:
		var dir := VIEWMODEL_CARRY_DIR.normalized()
		var reach := VIEWMODEL_ARM_LENGTH * VIEWMODEL_CARRY_SCALE
		var target := VIEWMODEL_CARRY_ANCHOR
		var elbow := target - dir * reach
		var right_axis := dir.cross(Vector3.FORWARD).normalized()
		wanted = Transform3D(Basis(right_axis * VIEWMODEL_CARRY_SCALE,
			dir * VIEWMODEL_CARRY_SCALE,
			right_axis.cross(dir) * VIEWMODEL_CARRY_SCALE), elbow)

	pivot.transform = pivot.transform.interpolate_with(
		wanted, clampf(VIEWMODEL_REACH_SPEED * delta, 0.0, 1.0))
	if _vm_kick_left > 0.0 and not _vm_kick.is_empty():
		var t: float = _vm_kick_left / VM_KICK_TIME
		var amount: float = t * t
		pivot.transform.origin += Vector3(
			0.0,
			float(_vm_kick["lift"]) * amount,
			-float(_vm_kick["push"]) * amount)
		pivot.transform.basis = pivot.transform.basis.rotated(
			Vector3.FORWARD, float(_vm_kick["roll"]) * amount)


const VIEWMODEL_SLIPPER_LENGTH: float = 0.34

func _sync_viewmodel_slipper(node: MeshInstance3D, held: Slipper) -> void:
	var visual := held.get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	var source: MeshInstance3D = null
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		source = child as MeshInstance3D
		break
	if source == null or source.mesh == null:
		return
	if node.mesh != source.mesh:
		node.mesh = source.mesh
		for surface in range(node.get_surface_override_material_count()):
			node.set_surface_override_material(surface, null)
	for surface in range(source.get_surface_override_material_count()):
		node.set_surface_override_material(surface,
			source.get_surface_override_material(surface))

	var length: float = maxf(source.mesh.get_aabb().size.z, 0.001)
	var parent := node.get_parent_node_3d()
	var parent_scale: float = 1.0
	if parent != null:
		parent_scale = maxf(parent.global_transform.basis.get_scale().z, 0.0001)
	node.scale = Vector3.ONE * (VIEWMODEL_SLIPPER_LENGTH / (length * parent_scale))


func _update_tpp_carry_follow() -> void:
	if _mode != Mode.TPP:
		return
	var carrier: CharacterBase = null
	if carrier != _tpp_excluded_carrier:
		if _tpp_excluded_carrier != null and is_instance_valid(_tpp_excluded_carrier):
			tpp_arm.remove_excluded_object(_tpp_excluded_carrier.get_rid())
		if carrier != null:
			tpp_arm.add_excluded_object(carrier.get_rid())
		_tpp_excluded_carrier = carrier
	if carrier == null:
		_tpp_carry_yaw_deg = 0.0
		_tpp_carry_pitch_deg = 0.0
		return
	var carrier_xform := carrier.get_global_transform_interpolated()
	var carrier_yaw := carrier_xform.basis.get_euler().y
	var yaw_basis := Basis(Vector3.UP, carrier_yaw + deg_to_rad(_tpp_carry_yaw_deg))
	var pitch_basis := Basis(Vector3.RIGHT, deg_to_rad(-15.0 + _tpp_carry_pitch_deg))
	tpp_arm.global_transform = Transform3D(
		yaw_basis * pitch_basis, carrier_xform.origin + Vector3.UP * TPP_CARRY_MOUNT_HEIGHT)

func _process(delta: float) -> void:
	_update_viewmodel_carry(delta)
	_update_tpp_carry_follow()
	_apply_upright_pose()
	if _shake_time_left > 0.0:
		_shake_time_left = max(0.0, _shake_time_left - delta)
		var ratio := _shake_time_left / _shake_duration
		var magnitude := _shake_strength * ratio
		var effective := magnitude * (0.5 if _mode == Mode.FPP else 1.0)
		_apply_shake_offset(Vector3(
			randf_range(-1.0, 1.0) * effective,
			randf_range(-1.0, 1.0) * effective,
			0.0,
		))
	elif _shake_strength > 0.0:
		_shake_strength = 0.0
		_apply_shake_offset(Vector3.ZERO)

func _apply_shake_offset(offset: Vector3) -> void:
	if _mode == Mode.FPP:
		fpp_camera.position = _fpp_camera_base_position + offset
	else:
		tpp_camera.position = _tpp_camera_base_position + offset

func _viewmodel_arms() -> Node3D:
	if _arms != null and is_instance_valid(_arms):
		return _arms
	if _character == null or not _character.is_person:
		return null
	var scene := load(VIEWMODEL_ARMS_SCENE) as PackedScene
	if scene == null:
		push_error("CameraRig: could not load '%s'" % VIEWMODEL_ARMS_SCENE)
		return null
	_arms = scene.instantiate() as Node3D
	fpp_pivot.add_child(_arms)
	_arms.scale = Vector3.ONE * VIEWMODEL_SCALE
	_arms.position += VIEWMODEL_SEAT
	return _arms


const VIEWMODEL_WINDUP_RAD: float = 0.62

func set_viewmodel_charge(power: float) -> void:
	var arms := _viewmodel_arms()
	if arms == null or not arms.visible:
		return
	var player := arms.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var arm := arms.get_node_or_null("RightPivot/Arm") as Node3D
	if player == null or arm == null:
		return
	if power < 0.0:
		if not player.is_playing():
			player.play("idle")
		return
	if player.current_animation == "idle":
		player.stop()
	arm.rotation.x = -VIEWMODEL_WINDUP_RAD * clampf(power, 0.0, 1.0)


func play_viewmodel_action(kind: String) -> void:
	var arms := _viewmodel_arms()
	if arms == null or not arms.visible:
		return
	var player := arms.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player != null and player.has_animation(kind):
		player.play(kind)
		return
	if VM_KICKS.has(kind):
		_vm_kick = VM_KICKS[kind]
		_vm_kick_left = VM_KICK_TIME


func _apply_carried_self_hide(hide_it: bool) -> void:
	var wanted: Node3D = null
	if hide_it:
		var carrier := _character.get_node_or_null("Carrier") as Carrier
		var held: Slipper = carrier.held() if carrier != null else null
		if held != null and is_instance_valid(held):
			wanted = held.get_node_or_null("Visual") as Node3D
	if wanted == _hidden_carried_visual:
		return
	if _hidden_carried_visual != null and is_instance_valid(_hidden_carried_visual):
		_hidden_carried_visual.visible = true
	if wanted != null:
		wanted.visible = false
	_hidden_carried_visual = wanted

func _on_held_changed(_held: Slipper) -> void:
	_apply_carried_self_hide(_active and _mode == Mode.FPP)

func _apply_fpp_self_hide() -> void:
	var arms := _viewmodel_arms()
	if arms != null:
		arms.visible = _active and _mode == Mode.FPP

	_apply_carried_self_hide(_active and _mode == Mode.FPP)

	var visual_root := _character.get_node_or_null("Visual")
	if visual_root == null:
		return
	var looking_through_this_body := _active and _mode == Mode.FPP
	var meshes := visual_root.find_children("*", "GeometryInstance3D", true, false)
	if not looking_through_this_body:
		for node in meshes:
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		return

	for node in meshes:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

func _unhandled_input(event: InputEvent) -> void:
	if not _active or aim_source != AimSource.MOUSE:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_mouse_delta((event as InputEventMouseMotion).relative)

func apply_mouse_delta(relative: Vector2) -> void:
	var sensitivity := BASE_SENSITIVITY * SettingsManager.mouse_sensitivity
	if false:
		_tpp_carry_yaw_deg -= relative.x * sensitivity
		var carry_pitch_delta := relative.y * (-1.0 if SettingsManager.invert_y else 1.0)
		_tpp_carry_pitch_deg = clamp(
			_tpp_carry_pitch_deg - carry_pitch_delta * sensitivity, PITCH_MIN_DEG, PITCH_MAX_DEG)
		return
	if _emote_view:
		_emote_yaw_deg -= relative.x * sensitivity
		var emote_pitch_delta := relative.y * (-1.0 if SettingsManager.invert_y else 1.0)
		_emote_pitch_deg = clamp(_emote_pitch_deg - emote_pitch_delta * sensitivity,
			EMOTE_PITCH_MIN_DEG, EMOTE_PITCH_MAX_DEG)
		return
	_character.rotation.y -= deg_to_rad(relative.x * sensitivity)
	if _mode == Mode.FPP:
		var pitch_delta := relative.y * (-1.0 if SettingsManager.invert_y else 1.0)
		_pitch_deg = clamp(_pitch_deg - pitch_delta * sensitivity, PITCH_MIN_DEG, PITCH_MAX_DEG)
		fpp_pivot.rotation.x = deg_to_rad(_pitch_deg)

