extends Node

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

const BONE: String = "arm-right"

func _ready() -> void:
	print("\n========== HAND BONE PROBE — where is the palm? ==========")
	for path in PERSON_MODELS:
		_report(path)
	print("==========================================================\n")
	get_tree().quit()

func _report(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		print("%-28s MISSING" % path.get_file())
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		return
	add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		print("%-28s NO SKELETON" % path.get_file())
		model.queue_free()
		return
	var skeleton := skeletons[0] as Skeleton3D
	var bone := skeleton.find_bone(BONE)
	if bone == -1:
		print("%-28s no '%s' bone" % [path.get_file(), BONE])
		model.queue_free()
		return
	var rest := skeleton.get_bone_global_rest(bone)

	var best := Vector3.ZERO
	var best_len := -1.0
	var counted := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var mesh := mesh_instance.mesh as ArrayMesh
		if mesh == null:
			continue
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if verts.is_empty() or bones.is_empty():
				continue
			var per_vertex := bones.size() / maxi(1, verts.size())
			for v in range(verts.size()):
				var weight := 0.0
				for i in range(per_vertex):
					if bones[v * per_vertex + i] == bone:
						weight = maxf(weight, weights[v * per_vertex + i])
				if weight < 0.5:
					continue
				counted += 1
				var local: Vector3 = rest.affine_inverse() * verts[v]
				if local.length() > best_len:
					best_len = local.length()
					best = local
	print("%-28s bone rest (%.3f, %.3f, %.3f) · %4d arm verts · tip in bone space (%.3f, %.3f, %.3f) = %.3f"
		% [path.get_file(), rest.origin.x, rest.origin.y, rest.origin.z, counted,
			best.x, best.y, best.z, best_len])
	model.queue_free()

