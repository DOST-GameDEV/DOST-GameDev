extends Node3D
class_name EnvToonPass


const NO_OUTLINE_GROUPS: Array[String] = [
	"Bahay", "Bakod", "Kanto", "Likod", "Kable", "Malayo", "Kalat", "Kalsada",
	"Puno",
	"Belt", "Road", "Slab", "Apron", "Layer1", "Layer2", "Layer3", "Clutter",
	"BayFill", "TreesNear", "TreesFar", "Ground", "Landmarks", "Furniture",
	"Monument", "Vehicles"]

const FACADE_TINTS: Array[Color] = [
	Color("e2d2ac"),
	Color("b5664c"),
	Color("86b4a6"),
	Color("c9994a"),
	Color("b7b2a6"),
	Color("cbb9b4"),
]

const FOLIAGE_TINTS: Array[Color] = [
	Color(0.86, 0.94, 0.78),
	Color(0.72, 0.82, 0.60),
	Color(0.95, 0.90, 0.66),
	Color(0.62, 0.76, 0.58),
	Color(0.80, 0.86, 0.70),
]

const ROAD_GROUPS: Array[String] = ["Kalsada", "Road", "Slab", "Apron"]
const ROAD_TINT: Color = Color(0.66, 0.62, 0.55)

const SLAB_GROUPS: Array[String] = ["Slab"]
const SLAB_TINT: Color = Color(0.88, 0.85, 0.78)

const BELT_FADE: Color = Color(0.878, 0.812, 0.694)
const BELT_FADE_AMOUNT: float = 0.68

const FACADE_GROUPS: Array[String] = [
	"Bahay", "Likod", "Malayo", "Kanto", "Puno", "TreesNear", "TreesFar",
	"Layer1", "Layer2", "Belt", "CrossRow"]

const ROOF_ATLASES: Array[Texture2D] = [
	preload("res://assets/models/kits/city/Textures/colormap_roof_terra.png"),
	preload("res://assets/models/kits/city/Textures/colormap_roof_rust.png"),
	preload("res://assets/models/kits/city/Textures/colormap_roof_slate.png"),
	preload("res://assets/models/kits/city/Textures/colormap_roof_ochre.png"),
	preload("res://assets/models/kits/city/Textures/colormap_roof_galv.png"),
	preload("res://assets/models/kits/city/Textures/colormap_roof_teal.png"),
]

const WIND_PREFIX: String = "Sampay"
const WIND_STRENGTH: float = 0.075
const WIND_SPEED: float = 1.15
const WIND_ANCHOR_Y: float = 2.62
const WIND_DROP: float = 0.70

func _ready() -> void:
	for child in get_children():
		var layer := child as Node3D
		if layer == null:
			continue
		var outlined := not NO_OUTLINE_GROUPS.has(layer.name)
		var facaded := FACADE_GROUPS.has(layer.name)
		for node in layer.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			var tint := Color.WHITE
			var roof: Texture2D = null
			var owner_name := _instance_name(mesh_instance, layer)
			if SLAB_GROUPS.has(layer.name):
				tint = SLAB_TINT
			elif ROAD_GROUPS.has(layer.name):
				tint = ROAD_TINT
			elif facaded:
				if _is_building(owner_name):
					tint = _facade_tint(owner_name)
					roof = _roof_atlas(owner_name)
				elif owner_name.contains("Tree") or owner_name.contains("Puno"):
					tint = FOLIAGE_TINTS[(_name_hash(owner_name) * 11 + 3)
						% FOLIAGE_TINTS.size()]
				if layer.name == "Belt" or layer.name == "Malayo":
					tint = tint.lerp(BELT_FADE, BELT_FADE_AMOUNT)
			_apply(mesh_instance, outlined, _wants_wind(mesh_instance, layer),
				tint, roof)


func _is_building(instance_name: String) -> bool:
	if instance_name.begins_with("BeltTree") or instance_name.contains("Puno"):
		return false
	return (instance_name.begins_with("Bahay_")
		or instance_name.begins_with("Likod_")
		or instance_name.begins_with("Kanto_")
		or instance_name.begins_with("MalayoX_")
		or instance_name.begins_with("MalayoZ_")
		or instance_name.begins_with("L1_")
		or instance_name.begins_with("L2_")
		or instance_name.begins_with("Cross_")
		or instance_name.begins_with("BeltX_")
		or instance_name.begins_with("BeltZ_"))


func _instance_name(node: Node, stop_at: Node) -> String:
	var walker: Node = node
	var last: String = node.name
	while walker != null and walker != stop_at:
		last = walker.name
		walker = walker.get_parent()
	return last


func _facade_tint(instance_name: String) -> Color:
	return FACADE_TINTS[(_name_hash(instance_name) * 7) % FACADE_TINTS.size()]


func _roof_atlas(instance_name: String) -> Texture2D:
	return ROOF_ATLASES[(_name_hash(instance_name) * 13 + 5) % ROOF_ATLASES.size()]


func _name_hash(text: String) -> int:
	var value := 0
	for i in text.length():
		value = (value * 31 + text.unicode_at(i)) & 0x7fffffff
	return value


func _wants_wind(node: Node, stop_at: Node) -> bool:
	var walker: Node = node
	while walker != null and walker != stop_at:
		if walker.name.begins_with(WIND_PREFIX):
			return true
		walker = walker.get_parent()
	return false


func _apply(mesh_instance: MeshInstance3D, outlined: bool, windy: bool,
		tint: Color, roof: Texture2D) -> void:
	for surface in range(mesh_instance.get_surface_override_material_count()):
		var original: Material = mesh_instance.get_active_material(surface)
		var mat := StandardMaterial3D.new()
		mat.roughness = 1.0
		mat.metallic = 0.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if original is BaseMaterial3D:
			var base_mat := original as BaseMaterial3D
			mat.albedo_color = base_mat.albedo_color * tint
			var tex := base_mat.albedo_texture
			if roof != null and tex != null:
				tex = roof
			if tex != null:
				mat.albedo_texture = tex
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		else:
			mat.albedo_color = tint
		mesh_instance.set_surface_override_material(surface, mat)


func _set_wind(material: ShaderMaterial) -> void:
	material.set_shader_parameter("wind_strength", WIND_STRENGTH)
	material.set_shader_parameter("wind_speed", WIND_SPEED)
	material.set_shader_parameter("wind_anchor_y", WIND_ANCHOR_Y)
	material.set_shader_parameter("wind_drop", WIND_DROP)

