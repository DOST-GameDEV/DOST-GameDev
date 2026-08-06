extends Node3D
class_name Lata


signal upright_changed(now_upright: bool)

const INTERACTION_RADIUS: float = 1.6
const RESET_CHANNEL_TIME: float = 1.5
const DOWNED_TILT_DEG: float = 88.0
const TOPPLE_TIME: float = 0.22

const HIT_MARGIN: float = 0.30

@onready var _visual: Node3D = $Visual
@onready var _hurtbox: Area3D = $Hurtbox

var is_upright: bool = true
var home_position: Vector3 = Vector3.ZERO

var _topple_tween: Tween = null

func _ready() -> void:
	home_position = global_position
	set_multiplayer_authority(1)
	_snap_home_to_ground.call_deferred()
	_fit_collision_to_mesh()
	_apply_upright_visual(true, false)

func _snap_home_to_ground() -> void:
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		home_position + Vector3.UP * 2.0, home_position + Vector3.DOWN * 6.0)
	query.collide_with_areas = false
	var body := get_node_or_null("Body") as CollisionObject3D
	if body != null:
		query.exclude = [body.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	home_position.y = (hit["position"] as Vector3).y
	global_position = home_position


func reset_channel_time() -> float:
	return RESET_CHANNEL_TIME / _scale(&"bilis", CharacterBase.TRAIT_SPEED_PER_POINT)

func power_scale() -> float:
	return _scale(&"lakas", CharacterBase.TRAIT_POWER_PER_POINT)

func hit_margin() -> float:
	return HIT_MARGIN / _scale(&"tatag", CharacterBase.TRAIT_GRIT_PER_POINT)

func _scale(key: StringName, per_point: float) -> float:
	return maxf(0.1, CharacterRoster.trait_scale(
		CharacterRoster.can_trait(skin_index, key), per_point))

func is_in_ring(world_position: Vector3) -> bool:
	var flat := Vector3(world_position.x - global_position.x, 0.0,
		world_position.z - global_position.z)
	return flat.length() <= INTERACTION_RADIUS

func can_be_reset_by(who: CharacterBase) -> bool:
	if who == null or is_upright:
		return false
	if not who.is_defender:
		return false
	if not who.can_act():
		return false
	return is_in_ring(who.global_position)


func host_knock_down(by_slot: int) -> bool:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return false
	if not is_upright:
		return false
	_broadcast_upright(false)
	RoundManager.host_note_lata_knocked(by_slot)
	return true

func host_restore() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if is_upright:
		return
	_broadcast_home()
	_broadcast_upright(true)
	RoundManager.host_note_lata_restored()

func host_reset_for_new_round() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	_broadcast_home()
	_broadcast_upright(true)

func _broadcast_upright(now_upright: bool) -> void:
	if NetworkManager.is_networked():
		_rpc_set_upright.rpc(now_upright)
	else:
		_apply_upright(now_upright)

func _broadcast_home() -> void:
	if NetworkManager.is_networked():
		_rpc_place.rpc(home_position)
	else:
		_apply_place(home_position)

@rpc("authority", "call_local", "reliable")
func _rpc_set_upright(now_upright: bool) -> void:
	_apply_upright(now_upright)

@rpc("authority", "call_local", "reliable")
func _rpc_place(where: Vector3) -> void:
	_apply_place(where)

func _apply_upright(now_upright: bool) -> void:
	if is_upright == now_upright:
		return
	is_upright = now_upright
	_apply_upright_visual(now_upright, true)
	AudioManager.play_at("can_knockdown" if not now_upright else "reset_complete",
		global_position)
	upright_changed.emit(now_upright)

func _apply_place(where: Vector3) -> void:
	global_position = where

var _downed_lift: float = 0.0

func _measure_downed_lift() -> void:
	_downed_lift = 0.0
	if _visual == null:
		return
	var bounds := _mesh_bounds()
	_downed_lift = maxf(bounds.size.x, bounds.size.z) * 0.5

func _mesh_bounds() -> AABB:
	var bounds := AABB()
	var first := true
	if _visual == null:
		return bounds
	for node in _visual.find_children("*", "VisualInstance3D", true, false):
		var box: AABB = (node as VisualInstance3D).get_aabb()
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
	return bounds

func _fit_collision_to_mesh() -> void:
	var bounds := _mesh_bounds()
	if bounds.size.y <= 0.001:
		return
	var shape_node := get_node_or_null("Body/CollisionShape3D") as CollisionShape3D
	if shape_node == null or not (shape_node.shape is CylinderShape3D):
		return
	var cylinder := shape_node.shape as CylinderShape3D
	cylinder.radius = maxf(bounds.size.x, bounds.size.z) * 0.5
	cylinder.height = bounds.size.y
	shape_node.position = Vector3(0.0, bounds.position.y + bounds.size.y * 0.5, 0.0)

func _apply_upright_visual(now_upright: bool, animate: bool) -> void:
	if _visual == null:
		return
	if _downed_lift <= 0.0:
		_measure_downed_lift()
	var target_angle := 0.0 if now_upright else deg_to_rad(DOWNED_TILT_DEG)
	if _topple_tween != null and _topple_tween.is_valid():
		_topple_tween.kill()
	if not animate:
		_set_tilt(target_angle)
		return
	_topple_tween = create_tween()
	_topple_tween.set_trans(Tween.TRANS_BACK if now_upright else Tween.TRANS_BOUNCE)
	_topple_tween.set_ease(Tween.EASE_OUT)
	_topple_tween.tween_method(_set_tilt, _visual.rotation.x, target_angle, TOPPLE_TIME)

func _set_tilt(angle: float) -> void:
	if _visual == null:
		return
	_visual.rotation = Vector3(angle, 0.0, 0.0)
	_visual.position = Vector3(0.0, _downed_lift * absf(sin(angle)), 0.0)

func adopt_state(now_upright: bool, where: Vector3) -> void:
	global_position = where
	if is_upright != now_upright:
		is_upright = now_upright
		_apply_upright_visual(now_upright, false)
		upright_changed.emit(now_upright)


var skin_index: int = -1

func apply_skin(index: int) -> void:
	if index < 0 or index == skin_index:
		return
	var entry: Dictionary = CharacterRoster.can_at(index)
	if not _apply_model(entry):
		return
	skin_index = index
	if not entry.has("tint"):
		return
	var tint: Color = entry["tint"]
	if tint == Color.WHITE:
		return
	_tint_meshes(tint)

func _apply_model(entry: Dictionary) -> bool:
	if not entry.has("model"):
		return false
	var visual := get_node_or_null("Visual")
	if visual == null:
		return false
	var target := visual.find_children("*", "MeshInstance3D", true, false)
	if target.is_empty():
		return false
	var mesh := load(String(entry["model"])) as Mesh
	if mesh == null:
		push_warning("Lata.apply_skin: cannot load %s" % entry["model"])
		return false
	var instance := target[0] as MeshInstance3D
	for surface in range(instance.get_surface_override_material_count()):
		instance.set_surface_override_material(surface, null)
	instance.mesh = mesh
	_measure_downed_lift()
	_fit_collision_to_mesh()
	_apply_upright_visual(is_upright, false)
	return true

func _tint_meshes(tint: Color) -> void:
	var visual := get_node_or_null("Visual")
	if visual == null:
		return
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in range(mesh.get_surface_override_material_count()):
			var material := mesh.get_active_material(surface)
			if material == null:
				continue
			var copy := material.duplicate()
			if copy is StandardMaterial3D:
				(copy as StandardMaterial3D).albedo_color = tint
			elif copy is ShaderMaterial:
				(copy as ShaderMaterial).set_shader_parameter("albedo_color", tint)
			mesh.set_surface_override_material(surface, copy)

