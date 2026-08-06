extends SceneTree


const ObjWriter = preload("res://tools/models/obj_writer.gd")
const EnvKit = preload("res://tools/models/env_kit.gd")

const OUTPUT_DIR: String = "res://assets/models/"

const REVOLVE_SEGMENTS: int = 16



const TEXTURE_DIR: String = "textures/"

const UV_V_INSET: float = 0.03


func _lata_specs() -> Array:
	return [
		{
			"name": "lata_pasip",
			"texture": "lata_pasip.png",
			"radius": 0.1075, "height": 0.377,
			"cap_v": Vector2(0.070, 0.930), "front_u": 0.38,
			"profile": [
				Vector2(0.70, 0.000), Vector2(0.88, 0.035), Vector2(1.00, 0.080),
				Vector2(1.00, 0.870), Vector2(0.88, 0.940), Vector2(0.66, 0.980),
				Vector2(0.62, 1.000),
			],
		},
		{
			"name": "lata_boyben",
			"texture": "lata_boyben.png",
			"radius": 0.1425, "height": 0.385,
			"cap_v": Vector2(0.050, 0.950), "front_u": 0.22,
			"profile": [
				Vector2(0.86, 0.000), Vector2(0.97, 0.025), Vector2(1.00, 0.050),
				Vector2(1.00, 0.905), Vector2(0.97, 0.928), Vector2(1.00, 0.958),
				Vector2(0.95, 0.988), Vector2(0.92, 1.000),
			],
		},
		{
			"name": "lata_decades",
			"texture": "lata_decades.png",
			"radius": 0.1225, "height": 0.382,
			"cap_v": Vector2(0.070, 0.930), "front_u": 0.22,
			"profile": [
				Vector2(0.90, 0.000), Vector2(1.00, 0.030), Vector2(0.96, 0.072),
				Vector2(0.96, 0.928), Vector2(1.00, 0.970), Vector2(0.90, 1.000),
			],
		},
		{
			"name": "lata_metal",
			"texture": "lata_metal.png",
			"radius": 0.1250, "height": 0.383,
			"cap_v": Vector2(0.040, 0.070), "front_u": 0.50,
			"profile": _metal_can_profile(),
		},
	]

const METAL_RIB_COUNT: int = 8
const METAL_RIB_DEPTH: float = 0.055
const METAL_RIB_FROM: float = 0.190
const METAL_RIB_TO: float = 0.865

func _metal_can_profile() -> Array:
	var profile: Array = [
		Vector2(0.90, 0.000), Vector2(1.00, 0.030), Vector2(0.945, 0.070),
	]
	var span := (METAL_RIB_TO - METAL_RIB_FROM) / float(METAL_RIB_COUNT)
	for i in range(METAL_RIB_COUNT):
		var base := METAL_RIB_FROM + span * float(i)
		profile.append(Vector2(0.945, base))
		profile.append(Vector2(0.945 - METAL_RIB_DEPTH, base + span * 0.5))
	profile.append(Vector2(0.945, METAL_RIB_TO))
	profile.append(Vector2(1.00, 0.958))
	profile.append(Vector2(0.90, 1.000))
	return profile

func _build_lata(spec: Dictionary) -> void:
	var writer := ObjWriter.new("Lata")
	var radius: float = spec["radius"]
	var height: float = spec["height"]
	writer.set_material("label", Color.WHITE, TEXTURE_DIR + String(spec["texture"]))

	var wall_uv := func(y: float, angle: float) -> Vector2:
		return Vector2(1.0 - angle / TAU,
			lerpf(UV_V_INSET, 1.0 - UV_V_INSET, y / height))

	var front_u: float = spec["front_u"]
	var yaw := PI / 4.0 - (1.0 - front_u) * TAU
	var facing := Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)

	var profile: Array = spec["profile"]
	var wall := PackedVector2Array()
	for point in profile:
		wall.append(Vector2(point.x * radius, point.y * height))
	writer.add_revolve(wall, REVOLVE_SEGMENTS, "label", true, Callable(),
		facing, wall_uv)

	var cap_v: Vector2 = spec["cap_v"]
	var base_uv := func(_y: float, _angle: float) -> Vector2:
		return Vector2(0.5, cap_v.x)
	var lid_uv := func(_y: float, _angle: float) -> Vector2:
		return Vector2(0.5, cap_v.y)
	var first: Vector2 = profile[0]
	var last: Vector2 = profile[profile.size() - 1]
	var base_y := first.y * height
	var lid_y := last.y * height
	writer.add_revolve(PackedVector2Array([
		Vector2(0.0, base_y + height * 0.022),
		Vector2(first.x * radius * 0.86, base_y + height * 0.016),
		Vector2(first.x * radius, base_y),
	]), REVOLVE_SEGMENTS, "label", true, Callable(), facing, base_uv)
	writer.add_revolve(PackedVector2Array([
		Vector2(last.x * radius, lid_y),
		Vector2(last.x * radius * 0.88, lid_y - height * 0.018),
		Vector2(0.0, lid_y - height * 0.018),
	]), REVOLVE_SEGMENTS, "label", true, Callable(), facing, lid_uv)

	writer.recalculate_normals(40.0)
	writer.write(OUTPUT_DIR + String(spec["name"]))
	var size := writer.bounds_size()
	print("  %-14s  d %.3f  h %.3f  ratio %.2f" % [
		spec["name"], size.x, size.y, size.y / maxf(size.x, 0.0001)])


func _initialize() -> void:
	print("lata:")
	for spec in _lata_specs():
		_build_lata(spec)
	_build_viewmodel_arm()
	EnvKit.new().build_all(OUTPUT_DIR)
	print("Model generation complete.")
	quit(0)


func _build_viewmodel_arm() -> void:
	var writer := ObjWriter.new("ViewmodelArm")
	writer.set_material("skin", Color("c8875a"))
	writer.set_material("skin_shade", Color("a66b45"))

	writer.add_extrude(PackedVector2Array([
		Vector2( 0.130, -0.122),
		Vector2( 0.130,  0.122),
		Vector2(-0.130,  0.122),
		Vector2(-0.130, -0.122),
	]), 0.0, 0.62, "skin_shade")

	writer.add_extrude(PackedVector2Array([
		Vector2( 0.158, -0.150),
		Vector2( 0.158,  0.150),
		Vector2(-0.158,  0.150),
		Vector2(-0.158, -0.150),
	]), 0.62, 0.84, "skin")

	writer.recalculate_normals(40.0)
	writer.write(OUTPUT_DIR + "viewmodel_arm")
	print("  viewmodel_arm")

