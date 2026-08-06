extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

var _out: String = ""
var _main: Node = null
var _log: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("out="):
			_out = text.substr(4)
		elif text.begins_with("slipper="):
			GameLaunch.selected_slipper = StringName(text.substr(8))
	if _out == "":
		_out = ProjectSettings.globalize_path("user://")
	GameLaunch.solo_seat = 1
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("seat="):
			GameLaunch.solo_seat = int(text.substr(5))
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()


func _emit(text: String) -> void:
	print(text)
	_log.append(text)


func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	if _main.has_method("_run_ready_countdown"):
		_main._run_ready_countdown()
	await get_tree().create_timer(4.5).timeout

	var local := _local_character()
	if local == null:
		_emit("[fpp] NO LOCAL CHARACTER — cannot test first person")
		_finish(1)
		return
	var rig := local.get_node_or_null("CameraRig") as CameraRig
	if rig == null:
		_emit("[fpp] local character has no CameraRig")
		_finish(1)
		return
	_emit("[fpp] local = %s  (defender: %s)" % [local.display_name(), local.is_defender])

	var slipper := _give_slipper(local)
	if slipper == null:
		_emit("[fpp] could not put a slipper in the local player's hand")
		for node in _main.find_children("*", "Node3D", true, false):
			var each := node as Slipper
			if each == null:
				continue
			_emit("[fpp]   %s owner_slot=%d state=%d carrier=%s grabbable=%s d=%.2f"
				% [each.name, each.owner_slot, each.state,
					each.carrier != null, each.can_be_grabbed_by(local),
					local.global_position.distance_to(each.global_position)])
		_finish(1)
		return
	await get_tree().create_timer(1.5).timeout

	_report(local, rig, slipper)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _out + "fpp_carry.png"
	_emit("[fpp] frame -> %s" % (path if image.save_png(path) == OK else "FAILED"))
	_finish(0)


func _report(local: CharacterBase, rig: CameraRig, slipper: Node3D) -> void:
	var carrier := local.get_node_or_null("Carrier") as Carrier
	_emit("[fpp] carrier.held() = %s" % ("null" if carrier == null or carrier.held() == null
		else String(carrier.held().name)))

	var arms: Node3D = rig.call("_viewmodel_arms") as Node3D
	if arms == null:
		_emit("[fpp] 1 viewmodel arms      : ABSENT — the rig built none")
		return
	_emit("[fpp] 1 viewmodel arms      : visible=%s  scale=%.3f" % [arms.visible, arms.scale.x])

	var held := arms.get_node_or_null("RightPivot/Arm/HeldSlipper") as MeshInstance3D
	if held == null:
		_emit("[fpp] 2 HeldSlipper         : NODE MISSING from ViewmodelArms.tscn")
		return
	_emit("[fpp] 2 HeldSlipper         : visible=%s  visible_in_tree=%s"
		% [held.visible, held.is_visible_in_tree()])

	if held.mesh == null:
		_emit("[fpp] 3 HeldSlipper mesh    : NONE")
		return
	_emit("[fpp] 3 HeldSlipper mesh    : %s" % held.mesh.resource_path.get_file())

	var box := held.mesh.get_aabb()
	var world_scale := held.global_transform.basis.get_scale()
	_emit("[fpp] 4 size                : mesh L %.3f -> world L %.3f  (scale %.3f)"
		% [box.size.z, box.size.z * world_scale.z, world_scale.z])

	var camera: Camera3D = null
	for node in rig.find_children("*", "Camera3D", true, false):
		if (node as Camera3D).current:
			camera = node as Camera3D
			break
	if camera == null:
		_emit("[fpp] 5 frustum             : no current camera on this rig")
		return
	var centre := held.global_transform * box.get_center()
	var local_point := camera.global_transform.affine_inverse() * centre
	var on_screen := camera.is_position_in_frustum(centre)
	var behind := local_point.z > 0.0
	_emit("[fpp] 5 frustum             : in_frustum=%s  behind_camera=%s  depth=%.3f m"
		% [on_screen, behind, -local_point.z])
	_emit("[fpp]   camera %s   slipper %s   world slipper %s"
		% [camera.global_position, centre, slipper.global_position])
	if not on_screen:
		var uv := camera.unproject_position(centre)
		_emit("[fpp]   unprojects to %s in a %s viewport — OFF SCREEN"
			% [uv, get_viewport().get_visible_rect().size])


func _local_character() -> CharacterBase:
	for node in _main.find_children("*", "CharacterBase", true, false):
		var who := node as CharacterBase
		if who == null:
			continue
		var rig := who.get_node_or_null("CameraRig") as CameraRig
		if rig == null:
			continue
		for cam in rig.find_children("*", "Camera3D", true, false):
			if (cam as Camera3D).current:
				return who
	return null


func _give_slipper(who: CharacterBase) -> Node3D:
	var carrier := who.get_node_or_null("Carrier") as Carrier
	if carrier == null:
		return null
	if carrier.held() != null:
		return carrier.held()
	for node in _main.find_children("*", "Node3D", true, false):
		var slipper := node as Slipper
		if slipper == null or slipper.carrier != null:
			continue
		if not slipper.can_be_grabbed_by(who):
			continue
		who.global_position = slipper.global_position + Vector3.UP * 0.2
		carrier.call("_request_grab", slipper)
		break
	return carrier.held()


func _finish(code: int) -> void:
	var file := FileAccess.open("user://fpp_carry_probe.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	get_tree().quit(code)

