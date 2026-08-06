extends MeshInstance3D
class_name TrajectoryPreview


const HORIZON: float = 2.5
const SAMPLES: int = 48
const DASH_ON: int = 1
const DASH_OFF: int = 0
const WIDTH_PER_METRE: float = 0.0045
const WIDTH_MIN: float = 0.008
const WIDTH_MAX: float = 0.10
const FADE_FLOOR: float = 0.45
const ALPHA_MAX: float = 0.62
const NEAR_FADE_START: float = 0.45
const NEAR_FADE_END: float = 2.20
const LANDING_MARK: float = 0.30
const FLOOR_EPSILON: float = 0.03

var _material: StandardMaterial3D = null
var _mesh: ImmediateMesh = null

func _ready() -> void:
	top_level = true
	_mesh = ImmediateMesh.new()
	mesh = _mesh
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.render_priority = 8
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false

func draw_arc(origin: Vector3, velocity: Vector3, gravity: float, tint: Color,
		rest_height: float = FLOOR_EPSILON) -> void:
	if _mesh == null:
		return
	_mesh.clear_surfaces()
	visible = true
	var step := 1.0 / float(maxi(1, Engine.physics_ticks_per_second))
	var total_steps := maxi(1, int(ceil(HORIZON / step)))
	var stride := maxi(1, int(round(float(total_steps) / float(SAMPLES))))
	var points: Array[Vector3] = []
	var position := origin
	var motion := velocity
	points.append(position)
	for i in range(total_steps):
		motion.y -= gravity * step
		position += motion * step
		var grounded := position.y <= maxf(FLOOR_EPSILON, rest_height)
		if grounded or i % stride == 0 or i == total_steps - 1:
			points.append(position)
		if grounded:
			break
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else global_position + Vector3.UP * 100.0

	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	var drawn := 0
	var cycle := DASH_ON + DASH_OFF
	for i in range(points.size() - 1):
		if i % cycle >= DASH_ON:
			continue
		var fade: float = 1.0 - (float(i) / float(maxi(1, points.size() - 1))) * (1.0 - FADE_FLOOR)
		var dist := ((points[i] + points[i + 1]) * 0.5).distance_to(eye)
		var near: float = clampf((dist - NEAR_FADE_START)
			/ maxf(0.001, NEAR_FADE_END - NEAR_FADE_START), 0.0, 1.0)
		var colour := Color(tint.r, tint.g, tint.b, fade * near * ALPHA_MAX)
		if _add_quad(points[i], points[i + 1], eye, colour):
			drawn += 1
	if points.size() >= 2:
		var land: Vector3 = points[points.size() - 1]
		var half := LANDING_MARK * 0.5
		var mark := Color(tint.r, tint.g, tint.b, ALPHA_MAX)
		var a := land + Vector3(-half, 0.0, -half)
		var b := land + Vector3(half, 0.0, -half)
		var c := land + Vector3(half, 0.0, half)
		var d := land + Vector3(-half, 0.0, half)
		_add_tri(a, b, c, mark)
		_add_tri(a, c, d, mark)
		drawn += 1
	_mesh.surface_end()
	if drawn == 0:
		visible = false


func _add_quad(a: Vector3, b: Vector3, eye: Vector3, colour: Color) -> bool:
	var along := b - a
	if along.length_squared() <= 0.0000001:
		return false
	along = along.normalized()
	var to_eye := (eye - (a + b) * 0.5)
	var half := clampf(to_eye.length() * WIDTH_PER_METRE, WIDTH_MIN, WIDTH_MAX)
	var side := along.cross(to_eye)
	if side.length_squared() <= 0.0000001:
		side = along.cross(Vector3.UP)
		if side.length_squared() <= 0.0000001:
			side = along.cross(Vector3.RIGHT)
	side = side.normalized() * half
	_add_tri(a - side, a + side, b + side, colour)
	_add_tri(a - side, b + side, b - side, colour)
	return true


func _add_tri(a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	_mesh.surface_set_color(colour)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(colour)
	_mesh.surface_add_vertex(b)
	_mesh.surface_set_color(colour)
	_mesh.surface_add_vertex(c)

func clear() -> void:
	if _mesh != null:
		_mesh.clear_surfaces()
	visible = false

