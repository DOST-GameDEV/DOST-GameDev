extends Node
## WHERE IS THE HAND, ACTUALLY? **Written 2026-08-02.**
##
##     Godot_v4.7.1-stable_win64_console.exe --headless --path <repo> tools/hand_bone_probe.tscn
##
## 🧑 2026-08-02, for the third time on this feature: *"the slipper floating earlier for
## others is a repeating problem, pls make sure u fix it, make it so that everyone on
## multiplayer and singleplayer sees it on the arms of the people"*.
##
## ⚠️⚠️ EVERY PREVIOUS ATTEMPT TUNED `HAND_CARRY_OFFSET` BY EYE AND THAT IS WHY IT KEPT
## COMING BACK. The constant was 0.441 m (measured: half an arm out in mid-air), then
## 0.04/0.03/-0.06 (measured: buried in the chest), each chosen from a screenshot.
## Neither number could be right, because the quantity it is trying to express — "from
## the bone origin to the palm" — is a FACT ABOUT THE SKELETON, and nobody had asked the
## skeleton.
##
## ⚠️⚠️ WHAT IT ANSWERS, AND IT IS NOT WHAT THE CODE ASSUMED. This rig has SEVEN bones.
## `arm-right` is the WHOLE ARM, it has NO CHILD BONE, and its rest origin is the
## SHOULDER — (-0.100, 0.288, -0.017) on a model 0.672 units tall. So `HandPoint`, sitting
## at that origin plus an 0.08 m nudge, has never been in a hand at all; it is at the
## collarbone, which is exactly where every "floating slipper" screenshot shows it. There
## is no wrist bone to attach to and there never was.
##
## ⚠️ SO THE PALM IS MEASURED OFF THE SKIN, NOT OFF THE SKELETON. The arm's geometry is
## the only thing that knows how long the arm is: every vertex the mesh weights primarily
## to `arm-right` belongs to that arm, so the one furthest from the shoulder along the
## bone's own axis IS the fingertip, and a little back from it is the palm. That is a
## measurement, it is the same for every rig in the roster (all twelve ship the same
## skeleton — verified below), and it cannot be argued with by a screenshot.

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

	# The furthest skinned vertex from the shoulder, in the BONE's own frame — which is
	# the frame `HandPoint.position` is written in, so the answer can be used directly.
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
			# 4 or 8 influences per vertex; the array length tells us which.
			var per_vertex := bones.size() / maxi(1, verts.size())
			for v in range(verts.size()):
				var weight := 0.0
				for i in range(per_vertex):
					if bones[v * per_vertex + i] == bone:
						weight = maxf(weight, weights[v * per_vertex + i])
				# ⚠️ 0.5, NOT "> 0". A vertex on the shoulder seam is shared with the
				# torso; taking anything with a trace of arm weight would measure the
				# body. Half the influence means the arm is what moves it.
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
