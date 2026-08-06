extends SubViewportContainer
class_name CharacterPreview



const CAMERA_YAW_DEGREES: float = 18.0
const CAMERA_PITCH_DEGREES: float = 16.0
const CAMERA_PITCH_FLAT_DEGREES: float = 52.0
const FRAME_MARGIN: float = 1.62
const AIM_HEIGHT_RATIO: float = 0.54

const IDLE_CLIP: String = "idle"

const FRAME_H_OFFSET_RATIO: float = -0.19

const PREVIEW_SCALE: float = 2.38

const TURN_DEGREES: float = 38.0
const TURN_PERIOD: float = 9.0

const ORBIT_SENSITIVITY: float = 0.4
const ORBIT_PITCH_MIN: float = -55.0
const ORBIT_PITCH_MAX: float = 70.0
const ZOOM_MIN: float = 0.55
const ZOOM_MAX: float = 2.2
const ZOOM_STEP: float = 0.12

@onready var viewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/Camera3D
@onready var pivot: Node3D = $SubViewport/Pivot

var _cache: Dictionary = {}
var _current: Node3D = null
var _current_id: StringName = &""
var _time: float = 0.0

var _frame_aim: Vector3 = Vector3.ZERO
var _frame_distance: float = 4.0
var _frame_pitch: float = 16.0
var _frame_half_fov: float = 0.4
var _frame_aspect: float = 1.777

var _user_yaw: float = 0.0
var _user_pitch: float = 0.0
var _user_zoom: float = 1.0
var _dragging: bool = false
var _user_took_over: bool = false
var _centre_subject: bool = false
var _uniform_extent: bool = false
var _wheel_zooms: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_on_resized)

func _on_resized() -> void:
	if _current != null and is_instance_valid(_current):
		_frame(_current)

func _frame(model: Node3D) -> void:
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var world := mesh_instance.global_transform * mesh_instance.get_aabb()
		if first:
			bounds = world
			first = false
		else:
			bounds = bounds.merge(world)
	if first:
		return

	var height: float = maxf(bounds.size.y, 0.001)
	var width: float = maxf(maxf(bounds.size.x, bounds.size.z), 0.001)
	var aim := Vector3(bounds.get_center().x,
		bounds.position.y + height * AIM_HEIGHT_RATIO, bounds.get_center().z)

	var half_fov: float = tan(deg_to_rad(camera.fov) * 0.5)
	var size := viewport.size
	var aspect: float = (float(size.x) / float(size.y)) if size.y > 0 else 1.777
	var distance: float = maxf(maxf(
		(height * FRAME_MARGIN * 0.5) / half_fov,
		(width * FRAME_MARGIN * 0.5) / (half_fov * aspect)),
		(width * FRAME_MARGIN * 0.5) / half_fov)

	if _uniform_extent:
		var extent: float = maxf(height, width)
		distance = (extent * FRAME_MARGIN * 0.5) / (half_fov * minf(aspect, 1.0))

	var flatness: float = clampf(height / width, 0.0, 1.0)
	var pitch: float = lerpf(CAMERA_PITCH_FLAT_DEGREES, CAMERA_PITCH_DEGREES, flatness)

	_frame_aim = aim
	_frame_distance = distance
	_frame_pitch = pitch
	_frame_half_fov = half_fov
	_frame_aspect = aspect
	_apply_camera()

func _apply_camera() -> void:
	var distance: float = _frame_distance * _user_zoom
	var yaw: float = CAMERA_YAW_DEGREES + _user_yaw
	var pitch: float = clampf(_frame_pitch + _user_pitch, ORBIT_PITCH_MIN, ORBIT_PITCH_MAX)
	var offset := Basis(Vector3.UP, deg_to_rad(yaw)) \
		* Basis(Vector3.RIGHT, deg_to_rad(pitch)) * Vector3(0.0, 0.0, distance)
	camera.position = _frame_aim + offset
	camera.look_at(_frame_aim)

	camera.h_offset = 0.0 if _centre_subject \
		else FRAME_H_OFFSET_RATIO * (2.0 * distance * _frame_half_fov) * _frame_aspect

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = button.pressed
				if button.pressed:
					_user_took_over = true
					accept_event()
			MOUSE_BUTTON_RIGHT:
				if button.pressed:
					reset_view()
					accept_event()
			MOUSE_BUTTON_WHEEL_UP:
				if _wheel_zooms:
					_zoom_by(-ZOOM_STEP)
					accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				if _wheel_zooms:
					_zoom_by(ZOOM_STEP)
					accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := (event as InputEventMouseMotion).relative
		_user_yaw -= motion.x * ORBIT_SENSITIVITY
		_user_pitch -= motion.y * ORBIT_SENSITIVITY
		_user_pitch = clampf(_user_pitch, ORBIT_PITCH_MIN - _frame_pitch,
			ORBIT_PITCH_MAX - _frame_pitch)
		_apply_camera()
		accept_event()

func _zoom_by(amount: float) -> void:
	_user_took_over = true
	_user_zoom = clampf(_user_zoom + amount, ZOOM_MIN, ZOOM_MAX)
	_apply_camera()

func set_tile_framing(factor: float, uniform_extent: bool = false) -> void:
	_centre_subject = true
	_uniform_extent = uniform_extent
	_user_zoom = clampf(factor, ZOOM_MIN, ZOOM_MAX)
	if _current != null and is_instance_valid(_current):
		_frame(_current)
	_apply_camera()

func enable_tile_interaction() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_wheel_zooms = false

func reset_view() -> void:
	_user_yaw = 0.0
	_user_pitch = 0.0
	_user_zoom = 1.0
	_user_took_over = false
	_time = 0.0
	pivot.rotation.y = 0.0
	_apply_camera()

func _process(delta: float) -> void:
	if _current == null:
		return
	if _user_took_over:
		return
	_time += delta
	pivot.rotation.y = deg_to_rad(sin(_time * TAU / TURN_PERIOD) * TURN_DEGREES)

func _exit_tree() -> void:
	for model in _cache.values():
		if is_instance_valid(model) and model.get_parent() == null:
			model.free()
	_cache.clear()

func show_character(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var id: StringName = entry["id"]
	if id == _current_id:
		return

	if _current != null:
		pivot.remove_child(_current)
	_current_id = id
	_current = _cache.get(id)

	if _current == null:
		var packed := load(String(entry["model"])) as PackedScene
		if packed == null:
			push_warning("CharacterPreview: could not load '%s'" % entry["model"])
			_current_id = &""
			return
		_current = packed.instantiate()
		_current.scale = Vector3.ONE * PREVIEW_SCALE
		_apply_material(_current, String(entry["material"]))
		_cache[id] = _current
	_play_idle(_current)

	pivot.add_child(_current)
	_time = 0.0
	pivot.rotation.y = 0.0
	_frame(_current)

const CAN_VISUAL: String = "res://scenes/characters/visuals/CanVisual.tscn"
const TSINELAS_VISUAL: String = "res://scenes/characters/visuals/TsinelasVisual.tscn"

func show_prop(entry: Dictionary, is_can: bool) -> void:
	if entry.is_empty():
		return
	var id: StringName = entry["id"]
	if id == _current_id:
		return

	if _current != null:
		pivot.remove_child(_current)
	_current_id = id
	_current = _cache.get(id)

	if _current == null:
		var packed := load(CAN_VISUAL if is_can else TSINELAS_VISUAL) as PackedScene
		if packed == null:
			_current_id = &""
			return
		_current = packed.instantiate()
		_apply_model(_current, entry)
		_tint(_current, entry.get("tint", Color.WHITE))
		_cache[id] = _current

	pivot.add_child(_current)
	_time = 0.0
	pivot.rotation.y = 0.0
	_frame(_current)

func _apply_model(model: Node3D, entry: Dictionary) -> void:
	if not entry.has("model"):
		return
	var target := model.find_children("*", "MeshInstance3D", true, false)
	if target.is_empty():
		return
	var mesh := load(String(entry["model"])) as Mesh
	if mesh == null:
		push_warning("CharacterPreview: cannot load %s" % entry["model"])
		return
	var instance := target[0] as MeshInstance3D
	for surface in range(instance.get_surface_override_material_count()):
		instance.set_surface_override_material(surface, null)
	instance.mesh = mesh

func _tint(model: Node3D, colour: Color) -> void:
	if colour == Color.WHITE:
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in range(mesh_instance.get_surface_override_material_count()):
			var source: Material = mesh_instance.get_active_material(surface)
			if source == null:
				continue
			var duped := source.duplicate()
			if duped is BaseMaterial3D:
				(duped as BaseMaterial3D).albedo_color = colour
			elif duped is ShaderMaterial:
				var shader_mat := duped as ShaderMaterial
				if shader_mat.get_shader_parameter("albedo_color") == null:
					continue
				shader_mat.set_shader_parameter("albedo_color", colour)
			mesh_instance.set_surface_override_material(surface, duped)

func _play_idle(model: Node3D) -> void:
	var animator := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator == null or not animator.has_animation(IDLE_CLIP):
		return
	animator.play(IDLE_CLIP)

func _apply_material(model: Node3D, material_path: String) -> void:
	if material_path.is_empty():
		return
	var material := load(material_path) as ShaderMaterial
	if material == null:
		push_warning("CharacterPreview: could not load palette '%s'" % material_path)
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in range(mesh_instance.get_surface_override_material_count()):
			mesh_instance.set_surface_override_material(surface, material)

