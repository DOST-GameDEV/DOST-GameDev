extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const SEAT: int = 1

var _out: String = ""
var _main: Node = null
var _log: PackedStringArray = []
var _cam: Camera3D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("out="):
			_out = text.substr(4)
	if _out == "":
		_out = ProjectSettings.globalize_path("user://")
	GameLaunch.solo_seat = SEAT
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
		_emit("[fatigue] NO LOCAL CHARACTER")
		_finish(1)
		return
	_emit("[fatigue] local = %s  defender=%s" % [local.display_name(), local.is_defender])

	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true

	await _shoot_fatigue(local)
	await _shoot_glow(local)
	_finish(0)

func _shoot_fatigue(local: CharacterBase) -> void:
	Input.action_press("move_up")
	Input.action_press("sprint")
	var frames := 0
	while not local.is_fatigued() and frames < 400:
		await get_tree().process_frame
		frames += 1
	Input.action_release("sprint")
	Input.action_release("move_up")
	_emit("[fatigue] is_fatigued=%s after %d frames" % [local.is_fatigued(), frames])
	_frame_on(local, Vector3(0, 1.6, 3.2))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := _out + "fatigue_pose.png"
	_emit("[fatigue] frame -> %s" % (path if get_viewport().get_texture().get_image().save_png(path) == OK else "FAILED"))
	await get_tree().create_timer(3.0).timeout

func _shoot_glow(local: CharacterBase) -> void:
	var slipper := _owned_slipper(local)
	if slipper == null:
		_emit("[glow] local (slot=%d) owns no slipper at all — cannot test" % local.player_slot)
		for node in _main.find_children("*", "Node3D", true, false):
			var each := node as Slipper
			if each == null:
				continue
			_emit("[glow]   %s owner_slot=%d state=%d carrier=%s"
				% [each.name, each.owner_slot, each.state, each.carrier])
		return
	_emit("[glow] owns %s owner_slot=%d state=%d" % [slipper.name, slipper.owner_slot, int(slipper.state)])
	if int(slipper.state) == 2:
		Input.action_press("special_ability")
		await get_tree().create_timer(0.1).timeout
		Input.action_release("special_ability")
		await get_tree().create_timer(4.0).timeout
	_emit("[glow] state=%d (0=LOOSE) at shot time" % [int(slipper.state)])
	_frame_on(slipper, Vector3(0, 0.6, 1.1))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := _out + "slipper_glow.png"
	_emit("[glow] frame -> %s" % (path if get_viewport().get_texture().get_image().save_png(path) == OK else "FAILED"))

func _owned_slipper(local: CharacterBase) -> Slipper:
	for node in _main.find_children("*", "Node3D", true, false):
		var each := node as Slipper
		if each != null and each.owner_slot == local.player_slot:
			return each
	return null

func _frame_on(subject: Node3D, offset: Vector3) -> void:
	_cam.global_position = subject.global_position + offset
	_cam.look_at(subject.global_position + Vector3(0, 0.9, 0), Vector3.UP)

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

func _finish(code: int) -> void:
	var file := FileAccess.open("user://fatigue_glow_shot.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	get_tree().quit(code)

