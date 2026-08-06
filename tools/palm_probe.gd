extends Node

const MODEL: String = "res://assets/characters/persons/character-male-f.glb"
const BONE: String = "arm-right"
const OWN: float = 0.5
const TIP: float = 0.125

func _ready() -> void:
	print("\n========== PALM PROBE — bone-local hand ==========")
	await _report(MODEL)
	print("=================================================\n")
	get_tree().quit()

func _report(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		print("  cannot load %s" % path)
		return
	var model := packed.instantiate() as Node3D
	add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		print("  no skeleton")
		return
	var skeleton := skeletons[0] as Skeleton3D
	var bone := skeleton.find_bone(BONE)
	print("  bone '%s' idx %d of %d" % [BONE, bone, skeleton.get_bone_count()])
	var rest := skeleton.get_bone_global_rest(bone)
	print("  global rest origin (%+.4f, %+.4f, %+.4f)" % [rest.origin.x, rest.origin.y, rest.origin.z])
	print("  global rest basis  x(%+.3f,%+.3f,%+.3f) y(%+.3f,%+.3f,%+.3f) z(%+.3f,%+.3f,%+.3f)"
		% [rest.basis.x.x, rest.basis.x.y, rest.basis.x.z,
			rest.basis.y.x, rest.basis.y.y, rest.basis.y.z,
			rest.basis.z.x, rest.basis.z.y, rest.basis.z.z])

	for node in model.find_children("*", "MeshInstance3D", true, false):
		_measure(node as MeshInstance3D, skeleton, bone)
	await _track(model, skeleton, bone)
	model.queue_free()

func _measure(mi: MeshInstance3D, skeleton: Skeleton3D, bone: int) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	var skin := mi.skin
	if skin == null:
		return
	var bind := -1
	for i in range(skin.get_bind_count()):
		var b := skin.get_bind_bone(i)
		if b == -1:
			b = skeleton.find_bone(skin.get_bind_name(i))
		if b == bone:
			bind = i
			break
	if bind == -1:
		return
	var bind_pose := skin.get_bind_pose(bind)
	print("  mesh '%s' surfaces %d, bind slot %d" % [mi.name, mesh.get_surface_count(), bind])
	print("  mesh xform rel skeleton (%+.3f, %+.3f, %+.3f) scale (%.3f, %.3f, %.3f)"
		% [mi.transform.origin.x, mi.transform.origin.y, mi.transform.origin.z,
			mi.transform.basis.get_scale().x, mi.transform.basis.get_scale().y,
			mi.transform.basis.get_scale().z])

	var pts: Array[Vector3] = []
	for s in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		if verts.is_empty() or bones.is_empty():
			continue
		var per := bones.size() / verts.size()
		for v in range(verts.size()):
			var w := 0.0
			for k in range(per):
				if bones[v * per + k] == bind:
					w += weights[v * per + k]
			if w >= OWN:
				pts.append(bind_pose * verts[v])
	if pts.is_empty():
		print("  no vertices weighted >= %.2f to the arm" % OWN)
		return

	var mean := Vector3.ZERO
	for p in pts:
		mean += p
	mean /= float(pts.size())
	var axis := Vector3.ZERO
	var far := 0.0
	for p in pts:
		var d := p.length()
		if d > far:
			far = d
			axis = p
	axis = axis.normalized()
	var lo := INF
	var hi := -INF
	for p in pts:
		var t := p.dot(axis)
		lo = minf(lo, t)
		hi = maxf(hi, t)
	print("  %d arm vertices; local axis (%+.3f, %+.3f, %+.3f); reach %.4f .. %.4f"
		% [pts.size(), axis.x, axis.y, axis.z, lo, hi])

	var cut := hi - (hi - lo) * TIP
	var hand := Vector3.ZERO
	var n := 0
	for p in pts:
		if p.dot(axis) >= cut:
			hand += p
			n += 1
	hand /= float(n)
	var radius := 0.0
	for p in pts:
		if p.dot(axis) >= cut:
			var off := (p - hand)
			off -= axis * off.dot(axis)
			radius = maxf(radius, off.length())
	print("  >> PALM (bone-local, = HAND_CARRY_OFFSET) (%+.4f, %+.4f, %+.4f)  from %d verts"
		% [hand.x, hand.y, hand.z, n])
	print("  >> hand blob radius %.4f (bone units)" % radius)
	var blo := Vector3(INF, INF, INF)
	var bhi := Vector3(-INF, -INF, -INF)
	for p in pts:
		if p.dot(axis) >= cut:
			blo = Vector3(minf(blo.x, p.x), minf(blo.y, p.y), minf(blo.z, p.z))
			bhi = Vector3(maxf(bhi.x, p.x), maxf(bhi.y, p.y), maxf(bhi.z, p.z))
	print("  >> hand box x %+.4f..%+.4f  y %+.4f..%+.4f  z %+.4f..%+.4f"
		% [blo.x, bhi.x, blo.y, bhi.y, blo.z, bhi.z])
	var up := (Vector3.UP - axis * Vector3.UP.dot(axis)).normalized()
	print("  >> 'away from the limb, upward' unit dir (%+.3f, %+.3f, %+.3f)" % [up.x, up.y, up.z])


func _track(model: Node3D, skeleton: Skeleton3D, bone: int) -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		print("  no AnimationPlayer to test tracking with")
		return
	var player := players[0] as AnimationPlayer
	var clip := ""
	for name in player.get_animation_list():
		if name.contains("holding-right") and not name.contains("shoot"):
			clip = name
			break
	if clip == "":
		print("  no holding-right clip; have %s" % str(player.get_animation_list()))
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "HandAttachment"
	skeleton.add_child(attachment)
	attachment.bone_name = skeleton.get_bone_name(bone)
	attachment.bone_idx = bone
	player.play(clip)
	var worst := 0.0
	var moved := 0.0
	var first := Vector3.ZERO
	for frame in range(60):
		player.advance(1.0 / 60.0)
		await get_tree().process_frame
		var want := skeleton.get_bone_global_pose(bone)
		var got := attachment.transform
		worst = maxf(worst, (want.origin - got.origin).length())
		if frame == 0:
			first = want.origin
		moved = maxf(moved, (want.origin - first).length())
	print("  >> clip '''%s''': attachment vs bone pose, worst gap %.6f over 60 frames" % [clip, worst])
	print("  >> the bone itself moved %.4f over those frames (0 would mean a frozen pose)" % moved)
	var hp := skeleton.get_bone_global_pose(bone) * Vector3(-0.2666, 0.0400, 0.0613)
	print("  >> HandPoint now lands at skeleton-space (%+.4f, %+.4f, %+.4f)" % [hp.x, hp.y, hp.z])

