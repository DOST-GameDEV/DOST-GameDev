extends Node3D
class_name Slipper


enum CarryState { LOOSE, CARRIED, FLYING }

signal carry_state_changed(new_state: CarryState)

const LAUNCH_SPEED: float = 18.5
const MIN_POWER_SCALE: float = 0.35
const HIT_RADIUS: float = 0.23
const MAX_FLIGHT_TIME: float = 6.0
const THROWER_IGNORE_TIME: float = 0.25
const REST_HEIGHT: float = 0.045
const SPIN_SPEED_DEG: float = 900.0
const TUMBLE_SPEED_DEG: float = 520.0
const VOID_Y: float = -12.0

const CARRY_BASIS: Basis = Basis(
	Vector3(0.0, 0.0, 1.0),
	Vector3(0.0, 1.0, 0.0),
	Vector3(-1.0, 0.0, 0.0))

@onready var _visual: Node3D = $Visual

@export var slipper_index: int = -1

var owner_slot: int = -1
var state: CarryState = CarryState.LOOSE
var carrier: CharacterBase = null

var spawn_position: Vector3 = Vector3.ZERO

var _velocity: Vector3 = Vector3.ZERO
var _flight_time: float = 0.0
var _thrower_ignore_left: float = 0.0
var _thrower: CharacterBase = null

func _ready() -> void:
	spawn_position = global_position
	set_multiplayer_authority(1)
	add_to_group("slippers")
	process_priority = 100
	_sample_floor.call_deferred()
	_set_state(CarryState.LOOSE)
	SettingsManager.slipper_highlight_changed.connect(_refresh_highlight)

func _process(_delta: float) -> void:
	if state == CarryState.CARRIED and carrier != null \
			and get_parent() != carrier.get_hand_attachment():
		_step_carried()


func is_loose() -> bool:
	return state == CarryState.LOOSE

func is_flying() -> bool:
	return state == CarryState.FLYING

func can_be_grabbed_by(who: CharacterBase) -> bool:
	if who == null or state != CarryState.LOOSE:
		return false
	if who.is_defender or not who.can_act():
		return false
	return not who.holding_slipper()

func _main_rpc(method: StringName, args: Array) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var full_args: Array = [method, slipper_index]
	full_args.append_array(args)
	main.callv("rpc", full_args)


func host_assign_owner(slot: int) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_owner", [slot])
	else:
		_apply_owner(slot)

func _apply_owner(slot: int) -> void:
	if owner_slot == slot:
		return
	owner_slot = slot
	_update_owner_glow()

func host_force_equip(who: CharacterBase) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if who == null or who.is_defender:
		return
	if state == CarryState.CARRIED and carrier == who:
		return
	if owner_slot >= 0 and who.player_slot != owner_slot:
		return
	if RoundManager.player_at(who.player_slot) != who:
		return
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_grabbed", [who.player_slot])
	else:
		_apply_grabbed(who.player_slot)

func host_grab(by: CharacterBase) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if not can_be_grabbed_by(by):
		return
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_grabbed", [by.player_slot])
	else:
		_apply_grabbed(by.player_slot)

var _pending_carrier_slot: int = -1

func _apply_grabbed(slot: int) -> void:
	owner_slot = slot
	carrier = RoundManager.player_at(slot)
	_velocity = Vector3.ZERO
	_set_state(CarryState.CARRIED)
	if carrier == null:
		_pending_carrier_slot = slot
		return
	_pending_carrier_slot = -1
	carrier.notify_holding(self)
	AudioManager.play_at("pickup", global_position)

func _resolve_pending_carrier() -> void:
	var who := RoundManager.player_at(_pending_carrier_slot)
	if who == null:
		return
	carrier = who
	_pending_carrier_slot = -1
	who.notify_holding(self)

func host_throw(from: CharacterBase, origin: Vector3, target_point: Vector3,
		power: float) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if state != CarryState.CARRIED or from == null:
		return
	var speed: float = LAUNCH_SPEED * lerpf(MIN_POWER_SCALE, 1.0, clampf(power, 0.0, 1.0)) \
		* speed_scale()
	var direction := _solve_arc(origin, target_point, speed)
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_thrown", [from.player_slot, origin, direction * speed])
	else:
		_apply_thrown(from.player_slot, origin, direction * speed)

func _apply_thrown(slot: int, origin: Vector3, launch_velocity: Vector3) -> void:
	owner_slot = slot
	_thrower = RoundManager.player_at(slot)
	if _thrower != null:
		_thrower.notify_holding(null)
	carrier = null
	global_position = origin
	_velocity = launch_velocity
	_flight_time = 0.0
	_thrower_ignore_left = THROWER_IGNORE_TIME
	_set_state(CarryState.FLYING)
	AudioManager.play_at("throw_release", origin)

func host_drop() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if state != CarryState.CARRIED:
		return
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_landed", [global_position])
	else:
		_apply_landed(global_position)

const DEFLECT_SPEED_SCALE: float = 0.27
const DEFLECT_LIFT: float = 5.0

const LATA_RECOIL_SCALE: float = 0.25
const LATA_RECOIL_LIFT_SCALE: float = 0.55

func _host_recoil_from(point: Vector3, scale: float) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var away := global_position - point
	away.y = 0.0
	if away.length() < 0.05:
		away = Vector3(-_velocity.x, 0.0, -_velocity.z)
	if away.length() < 0.05:
		away = Vector3.FORWARD
	away = away.normalized()
	var speed := LAUNCH_SPEED * scale
	var recoiled := Vector3(
		away.x * speed, DEFLECT_LIFT * LATA_RECOIL_LIFT_SCALE, away.z * speed)
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_deflected", [global_position, recoiled])
	else:
		_apply_deflected(global_position, recoiled)

func _host_deflect_from(blocker: CharacterBase) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var away := global_position - blocker.global_position
	away.y = 0.0
	if away.length() < 0.05:
		away = Vector3(-_velocity.x, 0.0, -_velocity.z)
	if away.length() < 0.05:
		away = Vector3.FORWARD
	away = away.normalized()
	var speed := LAUNCH_SPEED * DEFLECT_SPEED_SCALE
	var deflected := Vector3(away.x * speed, DEFLECT_LIFT, away.z * speed)
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_deflected", [global_position, deflected])
	else:
		_apply_deflected(global_position, deflected)

func _apply_deflected(from: Vector3, new_velocity: Vector3) -> void:
	global_position = from
	_velocity = new_velocity
	_flight_time = 0.0

func _apply_landed(where: Vector3, from_flight: bool = false) -> void:
	if carrier != null:
		carrier.notify_holding(null)
	carrier = null
	_thrower = null
	_velocity = Vector3.ZERO
	global_position = Vector3(where.x, maxf(where.y, _rest_height), where.z)
	rotation = Vector3.ZERO
	if _visual != null:
		_visual.rotation = Vector3.ZERO
	_set_state(CarryState.LOOSE)
	_set_landed_highlight(from_flight)
	if from_flight:
		AudioManager.play_at("slipper_land", global_position)

func host_reset_for_new_round() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_landed", [spawn_position])
	else:
		_apply_landed(spawn_position)

var _home_parent: Node = null

func _set_state(new_state: CarryState) -> void:
	if state == new_state:
		return
	if new_state == CarryState.CARRIED:
		_attach_to_hand()
	elif state == CarryState.CARRIED:
		_detach_from_hand()
	state = new_state
	_set_sync_enabled(new_state != CarryState.CARRIED)
	if new_state != CarryState.CARRIED:
		_restore_shadow_casting()
		_pending_carrier_slot = -1
	if new_state != CarryState.LOOSE:
		_set_landed_highlight(false)
	carry_state_changed.emit(new_state)


func _restore_shadow_casting() -> void:
	var visual := get_node_or_null("Visual")
	if visual == null:
		return
	for node in visual.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = \
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if visual is GeometryInstance3D:
		(visual as GeometryInstance3D).cast_shadow = \
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(visual as Node3D).visible = true

func _set_sync_enabled(enabled: bool) -> void:
	var sync := get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync != null:
		sync.public_visibility = enabled

func _attach_to_hand() -> void:
	if carrier == null or not is_instance_valid(carrier):
		return
	var hand := carrier.get_hand_attachment()
	if hand == null:
		return
	if _home_parent == null:
		_home_parent = get_parent()
	if get_parent() == hand:
		return
	_set_sync_enabled(false)
	var keep := global_transform
	get_parent().remove_child(self)
	hand.add_child(self)
	global_transform = keep
	transform = Transform3D(CARRY_BASIS, Vector3.ZERO)
	var inherited := hand.global_transform.basis.get_scale()
	scale = Vector3(
		1.0 / maxf(inherited.x, 0.0001),
		1.0 / maxf(inherited.y, 0.0001),
		1.0 / maxf(inherited.z, 0.0001))
	var bounds := _visual_bounds_local()
	if bounds.size.y > 0.0:
		position.y = -bounds.position.y * scale.y


func _visual_centre_local() -> Vector3:
	return _visual_bounds_local().get_center()

func _visual_bounds_local() -> AABB:
	var visual := get_node_or_null("Visual") as Node3D
	if visual == null:
		return AABB()
	var bounds := AABB()
	var first := true
	var to_self := global_transform.affine_inverse()
	for node in visual.find_children("*", "VisualInstance3D", true, false):
		var instance := node as VisualInstance3D
		var box: AABB = (to_self * instance.global_transform) * instance.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if visual is VisualInstance3D:
		var own_box: AABB = (to_self * visual.global_transform) \
			* (visual as VisualInstance3D).get_aabb()
		bounds = own_box if first else bounds.merge(own_box)
		first = false
	return AABB() if first else bounds

func _detach_from_hand() -> void:
	if _home_parent == null or not is_instance_valid(_home_parent):
		return
	if get_parent() == _home_parent:
		return
	var keep := global_transform
	get_parent().remove_child(self)
	_home_parent.add_child(self)
	global_transform = keep
	_set_sync_enabled(true)
	scale = Vector3.ONE
	rotation = Vector3.ZERO


const BLOCK_KNOCKBACK_SPEED: float = 4.583

func speed_scale() -> float:
	return CharacterRoster.trait_scale(
		CharacterRoster.slipper_trait(skin_index, &"bilis"),
		CharacterBase.TRAIT_SPEED_PER_POINT)

func power_scale() -> float:
	return CharacterRoster.trait_scale(
		CharacterRoster.slipper_trait(skin_index, &"lakas"),
		CharacterBase.TRAIT_POWER_PER_POINT)

func grit_scale() -> float:
	return maxf(0.1, CharacterRoster.trait_scale(
		CharacterRoster.slipper_trait(skin_index, &"tatag"),
		CharacterBase.TRAIT_GRIT_PER_POINT))


func _physics_process(delta: float) -> void:
	_update_owner_glow()
	match state:
		CarryState.CARRIED:
			if _pending_carrier_slot >= 0:
				_resolve_pending_carrier()
			if carrier != null and is_instance_valid(carrier) 					and get_parent() != carrier.get_hand_attachment():
				_attach_to_hand()
			if carrier == null or get_parent() != carrier.get_hand_attachment():
				_step_carried()
		CarryState.FLYING:
			_step_flying(delta)
		CarryState.LOOSE:
			pass

func _step_carried() -> void:
	if carrier == null or not is_instance_valid(carrier):
		return
	var hand := carrier.get_hand_attachment()
	if hand != null:
		global_position = hand.global_position
		global_rotation = hand.global_rotation
		return
	global_position = carrier.global_position \
		+ Vector3.UP * 0.15 \
		+ carrier.global_transform.basis.x * 0.28 \
		- carrier.global_transform.basis.z * 0.20

const BOUNCE_RESTITUTION: float = 0.45

const BOUNCE_INSET: float = HIT_RADIUS

func _bounce_off_bounds() -> void:
	var limit_x: float = CharacterBase.playable_half_x - BOUNCE_INSET
	var limit_z: float = CharacterBase.playable_half_z - BOUNCE_INSET
	if limit_x > 0.0 and absf(global_position.x) > limit_x:
		global_position.x = signf(global_position.x) * limit_x
		_velocity.x = -signf(global_position.x) * absf(_velocity.x) * BOUNCE_RESTITUTION
	if limit_z > 0.0 and absf(global_position.z) > limit_z:
		global_position.z = signf(global_position.z) * limit_z
		_velocity.z = -signf(global_position.z) * absf(_velocity.z) * BOUNCE_RESTITUTION

func _step_flying(delta: float) -> void:
	_flight_time += delta
	if _thrower_ignore_left > 0.0:
		_thrower_ignore_left = maxf(0.0, _thrower_ignore_left - delta)
	_velocity.y -= CharacterBase.GRAVITY * delta
	global_position += _velocity * delta
	_bounce_off_bounds()
	_spin(delta)

	var host_side := not NetworkManager.is_networked() or NetworkManager.is_host()
	if not host_side:
		return

	if global_position.y < VOID_Y or _flight_time >= MAX_FLIGHT_TIME:
		host_reset_for_new_round()
		return

	var blocker := _first_body_hit()
	if blocker != null:
		AudioManager.play_at("hit_body", global_position)
		var push := Vector3(_velocity.x, 0.0, _velocity.z)
		if push.length() > 0.01:
			blocker.host_apply_block(
				push.normalized() * BLOCK_KNOCKBACK_SPEED * power_scale())
		_host_deflect_from(blocker)
		return

	var target: Lata = RoundManager.lata
	if target != null and target.is_upright \
			and _flat_distance(global_position, target.global_position) \
				<= HIT_RADIUS + target.hit_margin() \
			and absf(global_position.y - target.global_position.y) < 1.0:
		target.host_knock_down(owner_slot)
		_host_recoil_from(target.global_position,
			LATA_RECOIL_SCALE * target.power_scale())
		return

	if global_position.y <= _floor_y + _rest_height:
		var rest := _ground_under(global_position)
		if NetworkManager.is_networked():
			_main_rpc("_rpc_slipper_landed", [rest, true])
		else:
			_apply_landed(rest, true)

func _first_body_hit() -> CharacterBase:
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		if who == _thrower and _thrower_ignore_left > 0.0:
			continue
		if not who.can_be_hit_by_slipper():
			continue
		if _flat_distance(global_position, who.global_position) > HIT_RADIUS + who.capsule_radius():
			continue
		var dy := global_position.y - who.global_position.y
		if dy < -who.capsule_height() * 0.5 or dy > who.capsule_height() * 0.5:
			continue
		return who
	return null

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _ground_under(where: Vector3) -> Vector3:
	return Vector3(where.x, _floor_y + _rest_height, where.z)

var _floor_y: float = 0.0

func _sample_floor() -> void:
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(spawn_position.x, spawn_position.y + 3.0, spawn_position.z),
		Vector3(spawn_position.x, spawn_position.y - 6.0, spawn_position.z))
	query.collide_with_areas = false
	var blocked: Array[RID] = []
	for node in RoundManager.players():
		var who := node as CollisionObject3D
		if who != null:
			blocked.append(who.get_rid())
	query.exclude = blocked
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		_floor_y = (hit["position"] as Vector3).y

func _spin(delta: float) -> void:
	if _visual == null:
		return
	_visual.rotate_z(deg_to_rad(SPIN_SPEED_DEG) * delta)
	_visual.rotate_x(deg_to_rad(TUMBLE_SPEED_DEG) * delta)

static func _solve_arc(origin: Vector3, target: Vector3, speed: float) -> Vector3:
	var to_target := target - origin
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var distance := flat.length()
	if distance < 0.05 or speed < 0.01:
		return to_target.normalized() if to_target.length() > 0.01 else Vector3.FORWARD
	var gravity: float = CharacterBase.GRAVITY
	var v2 := speed * speed
	var discriminant := v2 * v2 - gravity * (gravity * distance * distance + 2.0 * to_target.y * v2)
	if discriminant < 0.0:
		return to_target.normalized()
	var root := sqrt(discriminant)
	var tangent := (v2 - root) / (gravity * distance)
	return (flat.normalized() + Vector3.UP * tangent).normalized()

static func launch_velocity_for(origin: Vector3, target: Vector3, power: float,
		skin_speed_scale: float = 1.0) -> Vector3:
	var speed: float = LAUNCH_SPEED * lerpf(MIN_POWER_SCALE, 1.0, clampf(power, 0.0, 1.0)) \
		* skin_speed_scale
	return _solve_arc(origin, target, speed) * speed


var skin_index: int = -1

func apply_skin(index: int) -> void:
	if index < 0 or index == skin_index:
		return
	var entry: Dictionary = CharacterRoster.slipper_at(index)
	if not _apply_model(entry):
		return
	skin_index = index
	var tint: Color = entry.get("tint", Color.WHITE)
	if tint != Color.WHITE:
		_tint_meshes(tint)
	_refresh_highlight()

const MODEL_LENGTH: float = 0.691

var _rest_height: float = REST_HEIGHT

func rest_height() -> float:
	return _rest_height

func _measure_rest_height(visual: Node3D) -> void:
	var lowest := INF
	for node in visual.find_children("*", "VisualInstance3D", true, false):
		var mesh_node := node as VisualInstance3D
		var box: AABB = mesh_node.get_aabb()
		var chain := Transform3D.IDENTITY
		var walk: Node = mesh_node
		while walk != null and walk != self:
			if walk is Node3D:
				chain = (walk as Node3D).transform * chain
			walk = walk.get_parent()
		for i in range(8):
			lowest = minf(lowest, (chain * box.get_endpoint(i)).y)
	if lowest < INF and lowest > -0.25:
		_rest_height = -lowest
	else:
		_rest_height = REST_HEIGHT

func _apply_model(entry: Dictionary) -> bool:
	if not entry.has("model"):
		return false
	var visual := get_node_or_null("Visual")
	if visual == null:
		return false
	var resource := load(String(entry["model"]))
	if resource == null:
		push_warning("Slipper.apply_skin: cannot load %s" % entry["model"])
		return false

	if resource is Mesh:
		var target := visual.find_children("*", "MeshInstance3D", true, false)
		if target.is_empty():
			return false
		var instance := target[0] as MeshInstance3D
		for surface in range(instance.get_surface_override_material_count()):
			instance.set_surface_override_material(surface, null)
		instance.mesh = resource
		_measure_rest_height(visual)
		return true

	if resource is PackedScene:
		_swap_scene_model(visual, resource as PackedScene)
		return true
	return false

func _swap_scene_model(visual: Node3D, scene: PackedScene) -> void:
	for child in visual.get_children():
		child.queue_free()
		visual.remove_child(child)
	var holder := Node3D.new()
	visual.add_child(holder)
	var model := scene.instantiate()
	holder.add_child(model)

	var bounds := _merged_bounds(holder)
	if bounds.size.z <= 0.0001:
		return
	var factor: float = (MODEL_LENGTH / 1.6) / bounds.size.z
	holder.scale = Vector3.ONE * factor
	holder.position = -bounds.get_center() * factor

func _merged_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var visual_node := node as VisualInstance3D
		var box: AABB = visual_node.get_aabb()
		var relative: Transform3D = root.global_transform.affine_inverse() \
			* visual_node.global_transform
		box = relative * box
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
	return bounds

const OWNER_RIM_STRENGTH: float = 0.85
const OWNER_RIM_COLOR: Color = Color(1.0, 0.86, 0.35)

var _glow_on: bool = false

const LANDED_RIM_STRENGTH: float = 0.85

var _landed_highlight_on: bool = false

func _set_landed_highlight(on: bool) -> void:
	if on == _landed_highlight_on:
		return
	_landed_highlight_on = on
	_refresh_highlight()

func _update_owner_glow() -> void:
	var mine := state == CarryState.LOOSE and owner_slot >= 0 		and owner_slot == _local_owner_slot()
	if mine == _glow_on:
		return
	_glow_on = mine
	_refresh_highlight()

func _local_owner_slot() -> int:
	var main := get_tree().current_scene
	if main == null or not main.has_method("get_local_character"):
		return -1
	var who := main.get_local_character() as CharacterBase
	return who.player_slot if who != null and is_instance_valid(who) else -1

func _refresh_highlight() -> void:
	if is_queued_for_deletion():
		return
	if _landed_highlight_on and SettingsManager.slipper_highlight_enabled():
		_set_rim(LANDED_RIM_STRENGTH, SettingsManager.slipper_highlight_color())
	elif _glow_on:
		_set_rim(OWNER_RIM_STRENGTH, OWNER_RIM_COLOR)
	else:
		_set_rim(0.0, OWNER_RIM_COLOR)

func _set_rim(strength: float, color: Color) -> void:
	var visual := get_node_or_null("Visual")
	if visual == null:
		return
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in range(mesh.get_surface_override_material_count()):
			var material := mesh.get_surface_override_material(surface)
			if material == null:
				if strength <= 0.0:
					continue
				var base := mesh.get_active_material(surface)
				if base == null:
					continue
				material = base.duplicate()
				mesh.set_surface_override_material(surface, material)
			if material is ShaderMaterial:
				var shader_mat := material as ShaderMaterial
				shader_mat.set_shader_parameter("rim_strength", strength)
				shader_mat.set_shader_parameter("rim_color", color)
			elif material is StandardMaterial3D:
				var std_mat := material as StandardMaterial3D
				std_mat.emission_enabled = strength > 0.0
				std_mat.emission = color
				std_mat.emission_energy_multiplier = strength * EMISSION_SCALE
			_set_outline(mesh, material, strength, color)

const OUTLINE_SHADER: Shader = preload("res://assets/models/materials/outline.gdshader")
const OUTLINE_WORLD_WIDTH: float = 0.011
const EMISSION_SCALE: float = 0.12

func _set_outline(mesh: MeshInstance3D, material: Material, strength: float,
		color: Color) -> void:
	if strength <= 0.0:
		material.next_pass = null
		return
	var outline := material.next_pass as ShaderMaterial
	if outline == null or outline.shader != OUTLINE_SHADER:
		outline = ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		material.next_pass = outline
	outline.set_shader_parameter("outline_color", color)
	var scale := 1.6
	if mesh.is_inside_tree():
		var basis_scale := mesh.global_transform.basis.get_scale()
		scale = maxf(maxf(absf(basis_scale.x), absf(basis_scale.y)), absf(basis_scale.z))
	outline.set_shader_parameter("outline_width",
		OUTLINE_WORLD_WIDTH / maxf(scale, 0.0001))

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

