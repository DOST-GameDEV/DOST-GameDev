extends Node3D
class_name CharacterVisual


const PERSON_MODELS: Array[String] = [
	"res://assets/characters/persons/character-male-f.glb",
	"res://assets/characters/persons/character-female-f.glb",
	"res://assets/characters/persons/character-male-a.glb",
	"res://assets/characters/persons/character-female-a.glb",
	"res://assets/characters/persons/character-male-b.glb",
	"res://assets/characters/persons/character-female-b.glb",
	"res://assets/characters/persons/character-male-c.glb",
	"res://assets/characters/persons/character-female-c.glb",
	"res://assets/characters/persons/character-male-d.glb",
	"res://assets/characters/persons/character-female-d.glb",
	"res://assets/characters/persons/character-male-e.glb",
	"res://assets/characters/persons/character-female-e.glb",
]
const CAN_VISUAL: String = "res://scenes/characters/visuals/CanVisual.tscn"
const TSINELAS_VISUAL: String = "res://scenes/characters/visuals/TsinelasVisual.tscn"

const CAN_MESHES: Array[String] = [
	"res://assets/models/kits/food/soda-can.glb",
	"res://assets/models/kits/food/soda-can.glb",
	"res://assets/models/kits/food/soda-can.glb",
	"res://assets/models/kits/food/soda-can-crushed.glb",
]
const CAN_DENT_SQUASH: Array[float] = [1.0, 0.93, 0.85, 1.0]

const OUTLINE_WORLD_WIDTH: float = 0.012

const DOWNED_TILT_DEGREES: float = 78.0
const DOWNED_TILT_TIME: float = 0.28

const WALK_SPEED_THRESHOLD: float = 0.4
const RUN_SPEED_THRESHOLD: float = 7.5

const OBSERVED_SMOOTHING: float = 0.12
const OBSERVED_AIRBORNE_SPEED: float = 1.8
const OBSERVED_AIRBORNE_HOLD: float = 0.18
const OBSERVED_TELEPORT_SPEED: float = 30.0

const ACTION_CLIPS: Dictionary = {
	"throw": ["holding-right-shoot", "pick-up", "interact-right"] as Array[String],
	"shove": ["attack-melee-right", "attack-kick-right", "interact-right"] as Array[String],
	"ready": ["emote-yes", "interact-right"] as Array[String],
	"grab": ["pick-up", "interact-right", "interact-left"] as Array[String],
	"lunge": ["attack-kick-right", "attack-melee-right", "interact-right"] as Array[String],
	"punch": ["attack-melee-right", "attack-kick-right", "interact-right"] as Array[String],
}

const PERSON_SCALE: float = 2.38

const PERSON_MODEL_YAW_DEG: float = 180.0

const CAPSULE_HALF_HEIGHT_DOWN: float = -0.8

const HAND_BONE_CANDIDATES: Array[String] = ["arm-right", "arm-left"]
const HAND_CARRY_OFFSET: Vector3 = Vector3(-0.2666, 0.0555, 0.0613)

const CARRY_IDLE_CLIP: String = "holding-right"

var _visual_centre_offset: Vector3 = Vector3.ZERO

func visual_centre_offset() -> Vector3:
	return _visual_centre_offset

const FLASH_DURATION: float = 0.15

const REMOTE_SMOOTH_RATE: float = 18.0

const TOON_SHADER: Shader = preload("res://assets/models/materials/toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://assets/models/materials/outline.gdshader")

const IMPACT_PARTICLE_COUNT: int = 16
const IMPACT_PARTICLE_LIFETIME: float = 0.4
const IMPACT_PARTICLE_HEIGHT: float = 1.0

signal model_changed

var _current_key: String = ""
var _current_material_key: String = ""
var _current_skin_key: int = -1
var _materials: Array[BaseMaterial3D] = []
var _base_albedos: Array[Color] = []
var _shader_materials: Array[ShaderMaterial] = []
var _flash_tween: Tween = null
var _character: CharacterBase = null
var _tilt_tween: Tween = null
var _animator: AnimationPlayer = null
var _action_clip: String = ""

var _observed_velocity: Vector3 = Vector3.ZERO
var _observed_prev_position: Vector3 = Vector3.ZERO
var _observed_has_prev: bool = false
var _observed_airborne_left: float = 0.0
var _hand_attachment: Node3D = null

var _smoothed_world_pos: Vector3 = Vector3.ZERO
var _smoothed_yaw: float = 0.0
var _smoothing_initialized: bool = false

func _ready() -> void:
	_character = get_parent() as CharacterBase
	if _character == null:
		return
	_character.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: CharacterBase.State) -> void:
	_refresh_downed_tilt(new_state == CharacterBase.State.DOWNED)

func _mesh_from(path: String) -> Mesh:
	var resource := load(path)
	if resource is Mesh:
		return resource as Mesh
	var packed := resource as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return null
	var found: Mesh = null
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		found = (node as MeshInstance3D).mesh
		if found != null:
			break
	instance.free()
	return found

func _refresh_can_damage(dent_count: int) -> void:
	if _current_key != CAN_VISUAL:
		return
	var model := get_child(0) as Node3D if get_child_count() > 0 else null
	if model == null:
		return
	var meshes: Array[Node] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if not (node as Node).is_in_group(PROP_ATTACHMENT_GROUP):
			meshes.append(node)
	if meshes.is_empty():
		return
	var index := clampi(dent_count, 0, CAN_MESHES.size() - 1)
	var mesh_path: String = CAN_MESHES[index]
	var mesh := _mesh_from(mesh_path)
	if mesh == null:
		push_error("CharacterVisual: could not load a mesh from '%s'" % mesh_path)
		return
	var target := meshes[0] as MeshInstance3D
	target.mesh = mesh
	var squash: float = CAN_DENT_SQUASH[index]
	target.scale = Vector3(1.0, squash, 1.0)
	_materials.clear()
	_base_albedos.clear()
	_shader_materials.clear()
	_frost_materials.clear()
	_frost_level = 0.0
	_collect_meshes(model)
	_align_to_capsule_floor(model)
	model_changed.emit()

const DOWNED_ROLL_SETTLE: float = 0.35
var _roll_angle: float = 0.0
var _roll_axis: Vector3 = Vector3.RIGHT
var _roll_rest: Transform3D = Transform3D.IDENTITY
var _last_roll_position: Vector3 = Vector3.ZERO
var _rolling: bool = false

func _refresh_downed_tilt(is_downed: bool) -> void:
	if _character == null or not _character.is_can:
		rotation.z = 0.0
		_end_roll()
		return
	if _tilt_tween != null and _tilt_tween.is_valid():
		_tilt_tween.kill()
	_tilt_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tilt_tween.tween_property(self, "rotation:z",
		deg_to_rad(DOWNED_TILT_DEGREES) if is_downed else 0.0, DOWNED_TILT_TIME)
	if is_downed:
		_begin_roll()
	else:
		_end_roll()

func _begin_roll() -> void:
	var model := _model_node()
	if model == null:
		return
	_rolling = true
	_roll_angle = 0.0
	_roll_rest = model.transform
	_last_roll_position = _character.global_position
	var travel := _character.velocity
	travel.y = 0.0
	if travel.length() < 0.05:
		travel = -_character.global_transform.basis.z
		travel.y = 0.0
	if travel.length() < 0.05:
		travel = Vector3.FORWARD
	_roll_axis = travel.normalized().cross(Vector3.UP).normalized()

func _end_roll() -> void:
	if not _rolling:
		return
	_rolling = false
	_roll_angle = 0.0
	var model := _model_node()
	if model != null:
		model.transform = _roll_rest

func _model_node() -> Node3D:
	if get_child_count() == 0:
		return null
	return get_child(0) as Node3D

func _process_downed_roll(_delta: float) -> void:
	if not _rolling or _character == null or not is_instance_valid(_character):
		return
	var here := _character.global_position
	var moved := Vector3(here.x - _last_roll_position.x, 0.0, here.z - _last_roll_position.z)
	_last_roll_position = here
	var speed_flat := Vector2(_character.velocity.x, _character.velocity.z).length()
	if speed_flat < DOWNED_ROLL_SETTLE:
		return
	var radius: float = maxf(0.05, _character.capsule_radius())
	var forward := Vector3.UP.cross(_roll_axis).normalized()
	_roll_angle += moved.dot(forward) / radius
	var model := _model_node()
	if model == null:
		return
	var rotation_basis := Basis(_roll_axis, _roll_angle)
	var centre := _visual_centre_offset
	model.transform = Transform3D(rotation_basis * _roll_rest.basis,
		centre + rotation_basis * (_roll_rest.origin - centre))

func apply(is_person: bool, is_can: bool, team: int) -> void:
	var key := _model_path(is_person, is_can, team)
	var material_path := _person_material_path(is_person, team)
	var skin_key := -1
	if not is_person and _character != null:
		skin_key = _character.can_index if is_can else _character.slipper_index
	if key == _current_key and material_path == _current_material_key \
			and skin_key == _current_skin_key:
		return
	_current_key = key
	_current_material_key = material_path
	_current_skin_key = skin_key

	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_materials.clear()
	_base_albedos.clear()
	_shader_materials.clear()
	_frost_materials.clear()
	_frost_level = 0.0
	_animator = null
	_action_clip = ""
	if _emote_clip != "":
		_emote_clip = ""
		_emote_id = ""
		emote_finished.emit()
	_rolling = false
	_hand_attachment = null

	var scene := load(key) as PackedScene
	if scene == null:
		push_error("CharacterVisual: could not load model '%s'" % key)
		return
	var model := scene.instantiate() as Node3D
	if is_person:
		model.scale = Vector3.ONE * PERSON_SCALE
		model.rotation.y = deg_to_rad(PERSON_MODEL_YAW_DEG)
	add_child(model)

	_apply_toon_pass(model, is_person)
	_apply_person_material(model, material_path)
	_collect_meshes(model)
	_apply_prop_tint(is_person, is_can)
	_align_to_capsule_floor(model)
	_build_prop_attachments(is_person, is_can)
	_play_idle(model)
	model_changed.emit()
	if _character != null:
		_refresh_can_damage(0)
		_refresh_downed_tilt(_character.state == CharacterBase.State.DOWNED)

const PROP_ATTACHMENT_UNSHADED_ROUGHNESS: float = 0.85
const PROP_ATTACHMENT_GROUP: StringName = &"prop_attachment"

const CAN_ATTACHMENTS: Dictionary = {
	&"sarsi": [],
	&"gatas": [
		{"kind": "rod", "r": 0.022, "h": 0.012, "pos": Vector3(0.035, 0.175, 0.02),
			"colour": Color("2b2b30")},
		{"kind": "rod", "r": 0.022, "h": 0.012, "pos": Vector3(-0.035, 0.175, -0.02),
			"colour": Color("2b2b30")},
	],
	&"sardinas": [
		{"kind": "ring", "r": 0.045, "t": 0.008, "pos": Vector3(0.0, 0.19, -0.06),
			"rot": Vector3(90, 0, 0), "colour": Color("cfd4d8")},
		{"kind": "rod", "r": 0.006, "h": 0.07, "pos": Vector3(0.0, 0.19, -0.02),
			"rot": Vector3(90, 0, 0), "colour": Color("cfd4d8")},
	],
	&"kape": [
		{"kind": "slab", "size": Vector3(0.13, 0.006, 0.10), "pos": Vector3(0.03, 0.185, 0.0),
			"rot": Vector3(0, 15, 22), "colour": Color("d8d2c4")},
	],
	&"pintura": [
		{"kind": "ring", "r": 0.115, "t": 0.007, "pos": Vector3(0.0, 0.17, 0.0),
			"rot": Vector3(0, 0, 90), "colour": Color("6b6b70")},
		{"kind": "slab", "size": Vector3(0.03, 0.16, 0.012), "pos": Vector3(0.09, 0.07, 0.04),
			"colour": Color("4f8c6a")},
		{"kind": "rod", "r": 0.013, "h": 0.03, "pos": Vector3(0.09, -0.02, 0.04),
			"colour": Color("4f8c6a")},
	],
	&"biskwit": [
		{"kind": "ring", "r": 0.125, "t": 0.014, "pos": Vector3(0.0, 0.175, 0.0),
			"rot": Vector3(90, 0, 0), "colour": Color("caa06a")},
		{"kind": "slab", "size": Vector3(0.10, 0.045, 0.004), "pos": Vector3(0.0, 0.06, 0.105),
			"colour": Color("efe4cd")},
	],
}

const SLIPPER_ATTACHMENTS: Dictionary = {
	&"goma": [],
	&"bakya": [
		{"kind": "slab", "size": Vector3(0.13, 0.05, 0.14), "pos": Vector3(0.0, -0.05, 0.13),
			"colour": Color("6b4a28")},
		{"kind": "slab", "size": Vector3(0.16, 0.02, 0.05), "pos": Vector3(0.0, 0.055, -0.09),
			"rot": Vector3(12, 0, 0), "colour": Color("3d2a18")},
	],
	&"pula": [
		{"kind": "ring", "r": 0.028, "t": 0.007, "pos": Vector3(0.0, 0.06, -0.05),
			"rot": Vector3(0, 0, 90), "colour": Color("d8c47a")},
	],
	&"asul": [
		{"kind": "slab", "size": Vector3(0.05, 0.004, 0.30), "pos": Vector3(0.0, 0.045, 0.0),
			"colour": Color("cfe0ea")},
	],
	&"dilaw": [
		{"kind": "slab", "size": Vector3(0.09, 0.005, 0.07), "pos": Vector3(0.0, 0.046, -0.14),
			"colour": Color("fff2a8")},
	],
	&"luma": [
		{"kind": "ring", "r": 0.035, "t": 0.006, "pos": Vector3(0.0, 0.042, 0.10),
			"rot": Vector3(90, 0, 0), "colour": Color("3a342e")},
		{"kind": "rod", "r": 0.004, "h": 0.05, "pos": Vector3(0.045, 0.05, -0.06),
			"rot": Vector3(0, 0, 40), "colour": Color("9aa3a2")},
	],
	&"sabit": [
		{"kind": "ring", "r": 0.055, "t": 0.006, "pos": Vector3(0.0, 0.12, -0.02),
			"rot": Vector3(0, 90, 0), "colour": Color("b8bec4")},
		{"kind": "rod", "r": 0.005, "h": 0.09, "pos": Vector3(0.0, 0.185, -0.02),
			"colour": Color("b8bec4")},
		{"kind": "ring", "r": 0.022, "t": 0.005, "pos": Vector3(0.0, 0.235, -0.045),
			"rot": Vector3(0, 90, 0), "colour": Color("b8bec4")},
		{"kind": "slab", "size": Vector3(0.10, 0.008, 0.02), "pos": Vector3(0.0, 0.065, -0.02),
			"colour": Color("8a7f6a")},
	],
}

func _build_prop_attachments(is_person: bool, is_can: bool) -> void:
	if is_person or _character == null:
		return
	var model := _model_node()
	if model == null:
		return
	var index: int = _character.can_index if is_can else _character.slipper_index
	var entries: Array = CharacterRoster.CANS if is_can else CharacterRoster.SLIPPERS
	if index < 0 or index >= entries.size():
		return
	var id: StringName = entries[index].get("id", &"")
	var table: Dictionary = CAN_ATTACHMENTS if is_can else SLIPPER_ATTACHMENTS
	if not table.has(id):
		return
	for part in table[id]:
		var node := _build_attachment_part(part)
		if node != null:
			model.add_child(node)

func _build_attachment_part(part: Dictionary) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	match String(part.get("kind", "slab")):
		"ring":
			var torus := TorusMesh.new()
			var outer: float = float(part.get("r", 0.05))
			var tube: float = float(part.get("t", 0.008))
			torus.outer_radius = outer
			torus.inner_radius = maxf(0.001, outer - tube)
			torus.rings = 12
			torus.ring_segments = 8
			mesh_instance.mesh = torus
		"rod":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = float(part.get("r", 0.01))
			cylinder.bottom_radius = cylinder.top_radius
			cylinder.height = float(part.get("h", 0.05))
			cylinder.radial_segments = 8
			cylinder.rings = 1
			mesh_instance.mesh = cylinder
		_:
			var box := BoxMesh.new()
			box.size = part.get("size", Vector3(0.05, 0.01, 0.05))
			mesh_instance.mesh = box
	mesh_instance.position = part.get("pos", Vector3.ZERO)
	var euler: Vector3 = part.get("rot", Vector3.ZERO)
	mesh_instance.rotation = Vector3(
		deg_to_rad(euler.x), deg_to_rad(euler.y), deg_to_rad(euler.z))
	var material := StandardMaterial3D.new()
	material.albedo_color = part.get("colour", Color.WHITE)
	material.roughness = PROP_ATTACHMENT_UNSHADED_ROUGHNESS
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.add_to_group(PROP_ATTACHMENT_GROUP)
	return mesh_instance

func get_hand_attachment() -> Node3D:
	if _hand_attachment != null and is_instance_valid(_hand_attachment):
		return _hand_attachment
	_hand_attachment = _build_hand_attachment()
	return _hand_attachment

func _build_hand_attachment() -> Node3D:
	if get_child_count() == 0:
		return null
	var model := get_child(0) as Node3D
	if model == null:
		return null
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return null
	var skeleton := skeletons[0] as Skeleton3D
	for bone_name in HAND_BONE_CANDIDATES:
		if skeleton.find_bone(bone_name) == -1:
			continue
		var attachment := BoneAttachment3D.new()
		attachment.name = "HandAttachment"
		skeleton.add_child(attachment)
		attachment.bone_name = bone_name
		attachment.bone_idx = skeleton.find_bone(bone_name)
		var point := Node3D.new()
		point.name = "HandPoint"
		attachment.add_child(point)
		_aim_carry_point(point, bone_name)
		return point

	for index in range(skeleton.get_bone_count()):
		var found := skeleton.get_bone_name(index).to_lower()
		if not (found.contains("hand") or found.contains("arm")
				or found.contains("wrist")):
			continue
		var fallback := BoneAttachment3D.new()
		fallback.name = "HandAttachment"
		skeleton.add_child(fallback)
		fallback.bone_name = skeleton.get_bone_name(index)
		fallback.bone_idx = index
		var fallback_point := Node3D.new()
		fallback_point.name = "HandPoint"
		fallback.add_child(fallback_point)
		_aim_carry_point(fallback_point, fallback.bone_name)
		push_warning("CharacterVisual: no %s bone; carrying from '%s' instead"
			% [str(HAND_BONE_CANDIDATES), fallback.bone_name])
		return fallback_point
	push_warning("CharacterVisual: this rig has no arm or hand bone at all; "
		+ "a carried slipper will ride the body instead of a hand")
	return null

const HAND_CARRY_TARGET: Vector3 = Vector3(0.30, -0.30, 0.12)

func _aim_carry_point(point: Node3D, bone_name: String) -> void:
	var target := HAND_CARRY_TARGET
	if bone_name.to_lower().contains("left"):
		target.x = -target.x
	point.position = _carry_offset_for(bone_name)

func _carry_offset_for(bone_name: String) -> Vector3:
	if bone_name.to_lower().contains("left"):
		return Vector3(-HAND_CARRY_OFFSET.x, HAND_CARRY_OFFSET.y, HAND_CARRY_OFFSET.z)
	return HAND_CARRY_OFFSET

func _align_to_capsule_floor(model: Node3D) -> void:
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "VisualInstance3D", true, false):
		if (node as Node).is_in_group(PROP_ATTACHMENT_GROUP):
			continue
		var box: AABB = (node as VisualInstance3D).get_aabb()
		box = (node as Node3D).transform * box
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
	if first:
		return
	model.position.y = _capsule_half_height_down() - bounds.position.y * model.scale.y
	_visual_centre_offset = model.transform * bounds.get_center()

func _capsule_half_height_down() -> float:
	if _character != null:
		return -_character.capsule_height() / 2.0
	return CAPSULE_HALF_HEIGHT_DOWN

func _roster_entry(is_person: bool) -> Dictionary:
	if not is_person or _character == null or _character.character_index < 0:
		return {}
	return CharacterRoster.at(_character.character_index)

func _model_path(is_person: bool, is_can: bool, team: int) -> String:
	if is_person:
		var entry := _roster_entry(true)
		if entry.has("model"):
			return String(entry["model"])
		return PERSON_MODELS[team % PERSON_MODELS.size()]
	return CAN_VISUAL if is_can else TSINELAS_VISUAL

const PERSON_FALLBACK_MATERIALS: Array[String] = [
	"res://assets/characters/persons/materials/person_a.tres",
	"res://assets/characters/persons/materials/person_b.tres",
]

func _person_material_path(is_person: bool, team: int = 0) -> String:
	if not is_person:
		return ""
	var entry := _roster_entry(is_person)
	if entry.has("material"):
		return String(entry["material"])
	return PERSON_FALLBACK_MATERIALS[team % PERSON_FALLBACK_MATERIALS.size()]

const CAN_RIM_COLOR: Color = Color(0.93, 0.96, 1.0)
const CAN_RIM_STRENGTH: float = 0.42
const CAN_RIM_POWER: float = 4.5
const TSINELAS_RIM_COLOR: Color = Color(1.0, 0.90, 0.76)
const TSINELAS_RIM_STRENGTH: float = 0.26
const TSINELAS_RIM_POWER: float = 1.9

func _apply_prop_tint(is_person: bool, is_can: bool) -> void:
	if is_person or _character == null:
		return
	_apply_prop_surface(is_can)
	var index: int = _character.can_index if is_can else _character.slipper_index
	if index < 0:
		return
	var entry := CharacterRoster.can_at(index) if is_can else CharacterRoster.slipper_at(index)
	if not entry.has("tint"):
		return
	var tint: Color = entry["tint"]
	for material in _shader_materials:
		if material.get_shader_parameter("albedo_color") == null:
			continue
		material.set_shader_parameter("albedo_color", tint)

func _apply_prop_surface(is_can: bool) -> void:
	for material in _shader_materials:
		if material.get_shader_parameter("flash_amount") == null:
			continue
		material.set_shader_parameter("rim_color",
			CAN_RIM_COLOR if is_can else TSINELAS_RIM_COLOR)
		material.set_shader_parameter("rim_strength",
			CAN_RIM_STRENGTH if is_can else TSINELAS_RIM_STRENGTH)
		material.set_shader_parameter("rim_power",
			CAN_RIM_POWER if is_can else TSINELAS_RIM_POWER)

func _apply_person_material(model: Node3D, material_path: String) -> void:
	if material_path.is_empty():
		return
	var material := load(material_path) as ShaderMaterial
	if material == null:
		push_error("CharacterVisual: could not load palette '%s'" % material_path)
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in range(mesh_instance.get_surface_override_material_count()):
			mesh_instance.set_surface_override_material(surface, material)

func _collect_meshes(model: Node3D) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if (node as Node).is_in_group(PROP_ATTACHMENT_GROUP):
			continue
		var mesh_instance := node as MeshInstance3D
		for surface in range(mesh_instance.get_surface_override_material_count()):
			var source: Material = mesh_instance.get_active_material(surface)
			if source is ShaderMaterial:
				var shader_mat := source as ShaderMaterial
				if shader_mat.get_shader_parameter("flash_amount") == null:
					_collect_frost_material(mesh_instance, surface, shader_mat)
					continue
				var duped := shader_mat.duplicate() as ShaderMaterial
				mesh_instance.set_surface_override_material(surface, duped)
				_shader_materials.append(duped)
			elif source is BaseMaterial3D:
				var mat := (source as BaseMaterial3D).duplicate() as BaseMaterial3D
				mesh_instance.set_surface_override_material(surface, mat)
				_materials.append(mat)
				_base_albedos.append(mat.albedo_color)

var _frost_materials: Array[ShaderMaterial] = []

func _collect_frost_material(mesh_instance: MeshInstance3D, surface: int,
		source: ShaderMaterial) -> void:
	if not _shader_declares(source.shader, "frost_amount"):
		return
	var duped := source.duplicate() as ShaderMaterial
	mesh_instance.set_surface_override_material(surface, duped)
	_frost_materials.append(duped)

func _shader_declares(shader: Shader, uniform_name: String) -> bool:
	if shader == null:
		return false
	for uniform in shader.get_shader_uniform_list():
		if String(uniform["name"]) == uniform_name:
			return true
	return false

func set_frost(amount: float) -> void:
	var clamped := clampf(amount, 0.0, 1.0)
	if is_equal_approx(clamped, _frost_level):
		return
	_frost_level = clamped
	for material in _frost_materials:
		material.set_shader_parameter("frost_amount", clamped)

var _frost_level: float = 0.0

func _apply_toon_pass(model: Node3D, is_person: bool) -> void:
	if is_person:
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var outline_mat := ShaderMaterial.new()
		outline_mat.shader = OUTLINE_SHADER
		var scale_vector := mesh_instance.global_transform.basis.get_scale()
		var scale := maxf(maxf(absf(scale_vector.x), absf(scale_vector.y)),
			absf(scale_vector.z))
		if scale < 0.0001:
			scale = 1.0
		outline_mat.set_shader_parameter("outline_width", OUTLINE_WORLD_WIDTH / scale)
		for surface in range(mesh_instance.get_surface_override_material_count()):
			var toon_mat := ShaderMaterial.new()
			toon_mat.shader = TOON_SHADER
			var original: Material = mesh_instance.get_active_material(surface)
			if original is BaseMaterial3D:
				var base_mat := original as BaseMaterial3D
				toon_mat.set_shader_parameter("albedo_color", base_mat.albedo_color)
				var albedo_tex := base_mat.albedo_texture
				if albedo_tex != null:
					toon_mat.set_shader_parameter("albedo_texture", albedo_tex)
					toon_mat.set_shader_parameter("use_texture", true)
			elif original is ShaderMaterial:
				var orig_albedo = (original as ShaderMaterial).get_shader_parameter("albedo_color")
				if orig_albedo != null:
					toon_mat.set_shader_parameter("albedo_color", orig_albedo as Color)
			toon_mat.next_pass = outline_mat
			mesh_instance.set_surface_override_material(surface, toon_mat)

func _play_idle(model: Node3D) -> void:
	_animator = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animator == null:
		return
	if not _animator.animation_finished.is_connected(_on_animation_finished):
		_animator.animation_finished.connect(_on_animation_finished)
	_ensure_dance_clip(model)
	_play_locomotion()

const DANCE_LIBRARY: StringName = &"generated"
const DANCE_CLIP: String = "generated/dance"
const DANCE_LENGTH: float = 2.0
const DANCE_KEYS: int = 24
const DANCE_BONES: Array[String] = [
	"root", "torso", "head", "arm-left", "arm-right", "leg-left", "leg-right",
]

func _ensure_dance_clip(model: Node3D) -> void:
	if _animator == null or _animator.has_animation(DANCE_CLIP):
		return
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var animator_root := _animator.get_node_or_null(_animator.root_node)
	if animator_root == null:
		return
	var library := AnimationLibrary.new()
	library.add_animation(&"dance", _build_dance_animation(
		String(animator_root.get_path_to(skeleton))))
	_animator.add_animation_library(DANCE_LIBRARY, library)

func _build_dance_animation(prefix: String) -> Animation:
	var anim := Animation.new()
	anim.length = DANCE_LENGTH
	anim.loop_mode = Animation.LOOP_NONE
	var rotation_tracks: Dictionary = {}
	for bone in DANCE_BONES:
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath("%s:%s" % [prefix, bone]))
		rotation_tracks[bone] = track
	var root_position := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(root_position, NodePath("%s:root" % prefix))

	for i in range(DANCE_KEYS + 1):
		var time: float = DANCE_LENGTH * float(i) / float(DANCE_KEYS)
		var phase: float = TAU * float(i) / float(DANCE_KEYS)
		var sway: float = sin(phase)
		var beat: float = sin(phase * 2.0)
		var hop: float = (1.0 - cos(phase * 2.0)) * 0.5
		var raise_left: float = 0.5 + 0.5 * sway
		var raise_right: float = 0.5 - 0.5 * sway

		anim.position_track_insert_key(root_position, time,
			Vector3(0.042 * sway, 0.050 * hop, 0.0))
		anim.rotation_track_insert_key(rotation_tracks["root"], time,
			Quaternion.from_euler(Vector3(0.0, deg_to_rad(14.0 * sway),
				deg_to_rad(-9.0 * sway))))
		anim.rotation_track_insert_key(rotation_tracks["torso"], time,
			Quaternion.from_euler(Vector3(deg_to_rad(7.0 * beat),
				deg_to_rad(-20.0 * sway), deg_to_rad(14.0 * sway))))
		anim.rotation_track_insert_key(rotation_tracks["head"], time,
			Quaternion.from_euler(Vector3(deg_to_rad(9.0 * beat),
				deg_to_rad(10.0 * sway), deg_to_rad(13.0 * sway))))
		anim.rotation_track_insert_key(rotation_tracks["arm-left"], time,
			Quaternion.from_euler(Vector3(deg_to_rad(8.0 * beat), 0.0,
				deg_to_rad(lerpf(25.0, 160.0, raise_left)))))
		anim.rotation_track_insert_key(rotation_tracks["arm-right"], time,
			Quaternion.from_euler(Vector3(deg_to_rad(-8.0 * beat), 0.0,
				deg_to_rad(-lerpf(25.0, 160.0, raise_right)))))
		anim.rotation_track_insert_key(rotation_tracks["leg-left"], time,
			Quaternion.from_euler(Vector3(deg_to_rad(16.0 * sway), 0.0,
				deg_to_rad(11.0 * sway))))
		anim.rotation_track_insert_key(rotation_tracks["leg-right"], time,
			Quaternion.from_euler(Vector3(deg_to_rad(-16.0 * sway), 0.0,
				deg_to_rad(11.0 * sway))))
	return anim

func _simulated_here() -> bool:
	if _character == null:
		return false
	if not NetworkManager.is_networked():
		return true
	return _character.is_multiplayer_authority()

func _observe_motion(delta: float) -> void:
	if _character == null or delta <= 0.0:
		return
	var here := _character.global_position
	if not _observed_has_prev:
		_observed_prev_position = here
		_observed_has_prev = true
		return
	var raw := (here - _observed_prev_position) / delta
	_observed_prev_position = here
	if raw.length() > OBSERVED_TELEPORT_SPEED:
		_observed_velocity = Vector3.ZERO
		_observed_airborne_left = 0.0
		return
	_observed_velocity = _observed_velocity.lerp(raw,
		clampf(delta / OBSERVED_SMOOTHING, 0.0, 1.0))
	if absf(_observed_velocity.y) >= OBSERVED_AIRBORNE_SPEED:
		_observed_airborne_left = OBSERVED_AIRBORNE_HOLD
	elif _observed_airborne_left > 0.0:
		_observed_airborne_left = maxf(0.0, _observed_airborne_left - delta)

func _play_locomotion() -> void:
	if _charge_posing:
		return
	if _animator == null or _character == null or _action_clip != "":
		return
	var simulated := _simulated_here()
	var motion := _character.velocity if simulated else _observed_velocity
	var airborne := (not _character.is_on_floor()) if simulated \
		else _observed_airborne_left > 0.0
	var vertical := motion.y
	var speed := Vector2(motion.x, motion.z).length()
	var wanted := "idle"
	if _character.state == CharacterBase.State.DOWNED:
		wanted = "die"
	elif airborne:
		wanted = "jump" if vertical > 0.0 else "fall"
	elif _character.is_fatigued():
		wanted = "crouch"
	elif _is_holding():
		wanted = CARRY_IDLE_CLIP
	elif speed > RUN_SPEED_THRESHOLD:
		wanted = "sprint"
	elif speed > WALK_SPEED_THRESHOLD:
		wanted = "walk"
	if not _animator.has_animation(wanted):
		wanted = "idle"
	if _animator.has_animation(wanted) and _animator.current_animation != wanted:
		_animator.play(wanted)

func _process(delta: float) -> void:
	_observe_motion(delta)
	_drive_charge_pose()
	_play_locomotion()
	_process_downed_roll(delta)
	_spin_while_airborne(delta)
	_drive_viewmodel_charge()
	_process_remote_smoothing(delta)
	_process_frost(delta)

const FROST_RAMP_IN: float = 0.18
const FROST_RAMP_OUT: float = 0.45
const FROST_THAW_TIME: float = 1.2

func _process_frost(delta: float) -> void:
	if _frost_materials.is_empty() or _character == null or not is_instance_valid(_character):
		return
	var target := 0.0
	if _character.state == CharacterBase.State.STAGGERED:
		target = 1.0
		var left: float = _character.stagger_time_left()
		if left > 0.0 and left < FROST_THAW_TIME:
			target = left / FROST_THAW_TIME
	var rate := FROST_RAMP_IN if target > _frost_level else FROST_RAMP_OUT
	set_frost(move_toward(_frost_level, target, delta / maxf(rate, 0.001)))

func _process_remote_smoothing(delta: float) -> void:
	if not _should_smooth_remote():
		if _smoothing_initialized:
			position = Vector3.ZERO
			rotation.y = 0.0
			_smoothing_initialized = false
		return
	if not _smoothing_initialized:
		snap_remote_transform()
		return

	var body_pos := _character.global_position
	var body_yaw := _character.rotation.y
	var t: float = 1.0 - exp(-REMOTE_SMOOTH_RATE * delta)
	_smoothed_world_pos = _smoothed_world_pos.lerp(body_pos, t)
	_smoothed_yaw = lerp_angle(_smoothed_yaw, body_yaw, t)

	var world_gap := _smoothed_world_pos - body_pos
	position = _character.global_transform.basis.inverse() * world_gap
	rotation.y = wrapf(_smoothed_yaw - body_yaw, -PI, PI)

func _should_smooth_remote() -> bool:
	if _character == null or not NetworkManager.is_networked():
		return false
	if _character.is_multiplayer_authority():
		return false
	return true

func snap_remote_transform() -> void:
	if _character == null:
		return
	_smoothed_world_pos = _character.global_position
	_smoothed_yaw = _character.rotation.y
	position = Vector3.ZERO
	rotation.y = 0.0
	_smoothing_initialized = true


const CHARGE_POSE_BONES: Array[String] = ["arm-right", "arm-left"]

const CHARGE_POSE_RAD: float = CameraRig.VIEWMODEL_WINDUP_RAD

const CHARGE_POSE_AXIS: Vector3 = Vector3(1.0, 0.0, 0.0)

var _charge_posing: bool = false
var _charge_bone: int = -1
var _charge_bone_rest: Quaternion = Quaternion.IDENTITY
var _charge_skeleton: Skeleton3D = null

func _drive_charge_pose() -> void:
	if _animator == null or _character == null or not _character.is_person:
		return
	var carrier := _character.get_node_or_null("Carrier") as Carrier
	var power := -1.0
	if carrier != null and carrier.held() != null:
		power = carrier.observed_charge_power()
	if power < 0.0:
		var shove := _character.observed_shove_charge()
		if shove >= 0.0:
			power = clampf(shove, 0.0, 1.0)
	if power < 0.0:
		var lunge := _character.observed_lunge_charge()
		if lunge >= 0.0:
			power = clampf(lunge, 0.0, 1.0)
	var winding := power >= 0.0 and _character.state == CharacterBase.State.NORMAL
	if not winding:
		if _charge_posing:
			_clear_charge_pose()
			if _action_clip == "":
				_play_locomotion()
		return
	if not _charge_posing:
		if not _resolve_charge_bone():
			return
		_charge_posing = true
		_animator.pause()
	_charge_skeleton.set_bone_pose_rotation(_charge_bone, _charge_bone_rest
		* Quaternion(CHARGE_POSE_AXIS.normalized(), CHARGE_POSE_RAD * clampf(power, 0.0, 1.0)))

func _resolve_charge_bone() -> bool:
	if get_child_count() == 0:
		return false
	var model := get_child(0) as Node3D
	if model == null:
		return false
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return false
	_charge_skeleton = skeletons[0] as Skeleton3D
	for bone_name in CHARGE_POSE_BONES:
		var idx := _charge_skeleton.find_bone(bone_name)
		if idx != -1:
			_charge_bone = idx
			_charge_bone_rest = _charge_skeleton.get_bone_pose_rotation(idx)
			return true
	return false

func _clear_charge_pose() -> void:
	_charge_posing = false
	if _animator != null:
		_animator.play(_animator.current_animation)
	if _charge_skeleton != null and is_instance_valid(_charge_skeleton) and _charge_bone != -1:
		_charge_skeleton.set_bone_pose_rotation(_charge_bone, _charge_bone_rest)
	_charge_bone = -1
	_charge_skeleton = null

func _drive_viewmodel_charge() -> void:
	if _character == null or not _character.is_person:
		return
	var rig := _character.get_node_or_null("CameraRig") as CameraRig
	if rig == null:
		return
	var carrier := _character.get_node_or_null("Carrier") as Carrier
	if carrier == null:
		return
	rig.set_viewmodel_charge(carrier.charge_power() if carrier.is_charging() else -1.0)

func _spin_while_airborne(_delta: float) -> void:
	pass

func _is_holding() -> bool:
	if _character == null or not _character.is_person:
		return false
	var carrier := _character.get_node_or_null("Carrier") as Carrier
	if carrier == null:
		return false
	return carrier.held() != null

func play_action(kind: String) -> void:
	var rig := _character.get_node_or_null("CameraRig") as CameraRig if _character != null else null
	if rig != null:
		rig.play_viewmodel_action(kind)

	if _animator == null:
		return
	var candidates: Array[String] = ACTION_CLIPS.get(kind, [] as Array[String])
	for clip in candidates:
		if _animator.has_animation(clip):
			_action_clip = clip
			_animator.play(clip)
			return

const EMOTE_CLIPS: Dictionary = {
	"yes": ["emote-yes", "interact-right"] as Array[String],
	"no": ["emote-no", "interact-left"] as Array[String],
	"sit": ["sit", "crouch"] as Array[String],
	"crouch": ["crouch", "sit"] as Array[String],
	"dance": [DANCE_CLIP, "emote-yes"] as Array[String],
	"tpose": ["static", "idle"] as Array[String],
	"bow": ["pick-up", "interact-right"] as Array[String],
}

const EMOTE_LOOPS: Dictionary = {
	"yes": true,
	"no": true,
	"sit": false,
	"crouch": false,
	"dance": true,
	"tpose": false,
	"bow": true,
}

signal emote_finished

var _emote_clip: String = ""
var _emote_id: String = ""

func is_emoting() -> bool:
	return _emote_clip != ""

func play_emote(id: String) -> bool:
	if _animator == null:
		return false
	var candidates: Array[String] = EMOTE_CLIPS.get(id, [] as Array[String])
	for clip in candidates:
		if _animator.has_animation(clip):
			_emote_clip = clip
			_emote_id = id
			_action_clip = clip
			_animator.play(clip)
			return true
	return false

func stop_emote() -> void:
	if _emote_clip == "":
		return
	_emote_clip = ""
	_emote_id = ""
	_action_clip = ""
	_play_locomotion()

func _on_animation_finished(anim_name: StringName) -> void:
	if String(anim_name) == _emote_clip:
		if bool(EMOTE_LOOPS.get(_emote_id, true)):
			_animator.play(_emote_clip)
		return
	if String(anim_name) == _action_clip:
		_action_clip = ""
		_play_locomotion()

func flash_hit() -> void:
	_spawn_impact_particles()
	if _materials.is_empty() and _shader_materials.is_empty():
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_parallel(true)
	for i in range(_materials.size()):
		_materials[i].albedo_color = Color.WHITE
		_flash_tween.tween_property(_materials[i], "albedo_color", _base_albedos[i], FLASH_DURATION)
	for mat in _shader_materials:
		mat.set_shader_parameter("flash_color", Color.WHITE)
		mat.set_shader_parameter("flash_amount", 1.0)
		_flash_tween.tween_method(
			func(a: float) -> void: mat.set_shader_parameter("flash_amount", a),
			1.0, 0.0, FLASH_DURATION)

func _spawn_impact_particles() -> void:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 1.5
	material.initial_velocity_max = 3.5
	material.gravity = Vector3(0, -9.8, 0)
	material.color = UiTheme.IMPACT

	var point_mesh := SphereMesh.new()
	point_mesh.radius = 0.04
	point_mesh.height = 0.08
	var point_material := StandardMaterial3D.new()
	point_material.albedo_color = UiTheme.IMPACT
	point_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	point_mesh.material = point_material

	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = IMPACT_PARTICLE_COUNT
	particles.lifetime = IMPACT_PARTICLE_LIFETIME
	particles.process_material = material
	particles.draw_pass_1 = point_mesh
	particles.position.y = IMPACT_PARTICLE_HEIGHT
	particles.finished.connect(particles.queue_free)
	add_child(particles)
	particles.emitting = true

func flash_blocked() -> void:
	if _materials.is_empty() and _shader_materials.is_empty():
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_parallel(true)
	for i in range(_materials.size()):
		_materials[i].albedo_color = UiTheme.DEFENSE
		_flash_tween.tween_property(_materials[i], "albedo_color", _base_albedos[i], FLASH_DURATION)
	for mat in _shader_materials:
		mat.set_shader_parameter("flash_color", UiTheme.DEFENSE)
		mat.set_shader_parameter("flash_amount", 1.0)
		_flash_tween.tween_method(
			func(a: float) -> void: mat.set_shader_parameter("flash_amount", a),
			1.0, 0.0, FLASH_DURATION)

