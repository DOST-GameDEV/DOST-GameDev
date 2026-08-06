extends Node


const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

var _out := "res://"
var _main: Node = null

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	if _main.has_method("_run_ready_countdown"):
		_main._run_ready_countdown()
	await get_tree().create_timer(4.5).timeout

	var holder: CharacterBase = null
	for _i in range(600):
		holder = _find_holder()
		if holder != null:
			break
		await get_tree().process_frame
	if holder == null:
		print("[carry] NOBODY PICKED A SLIPPER UP - nothing to photograph")
		get_tree().quit(1)
		return

	var slipper := _find_held_slipper(holder)
	var hand := holder.get_hand_attachment()
	if slipper != null and hand != null:
		print("[carry] holder=%s  hand=%s  slipper=%s  gap=%.4f m" % [
			holder.display_name(), hand.global_position, slipper.global_position,
			hand.global_position.distance_to(slipper.global_position)])

	for node in get_tree().root.find_children("*", "Camera3D", true, false):
		(node as Camera3D).current = false
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true

	var focus := holder.global_position + Vector3.UP * 1.1
	if hand != null:
		focus = hand.global_position
	var shots := [
		["01_carry_third", focus + Vector3(1.4, 0.7, 1.4), 1.0],
		["02_carry_hand", focus + Vector3(0.55, 0.18, 0.55), 1.0],
		["03_carry_front", focus + Vector3(0.0, 0.35, 1.5), 1.0],
	]
	for shot in shots:
		camera.global_position = shot[1]
		camera.look_at(focus, Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path: String = _out + String(shot[0]) + ".png"
		var err := image.save_png(path)
		print("[carry] %s -> %s" % [shot[0], path if err == OK else "FAILED"])
	get_tree().quit()

func _find_holder() -> CharacterBase:
	for node in get_tree().get_nodes_in_group("players"):
		var who := node as CharacterBase
		if who != null and who.holding_slipper:
			return who
	for node in _main.find_children("*", "CharacterBase", true, false):
		var who := node as CharacterBase
		if who != null and who.holding_slipper:
			return who
	return null

func _find_held_slipper(holder: CharacterBase) -> Node3D:
	for node in _main.find_children("*", "Node3D", true, false):
		if node is Slipper and (node as Slipper).carrier == holder:
			return node
	return null

