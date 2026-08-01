extends Node

## Photographs a CARRIED slipper, in the hand, from outside and from the owner's
## own eyes.
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/models/carry_shot.tscn -- <out_dir>
##
## ⚠️ RUN IT WITH THE PLAIN EXE. `--headless` has no rendering device.
##
## WHY THIS EXISTS. 🧑, twice: *"make sure that when we put these in the game they
## arent buggy and dont float, in earlier iterations the shoe would float for
## either the enemy or the person"* and *"make sure it actually looks like the
## slippers are on the hand of ppl for itself and for others"*.
##
## That bug is real and documented — `character_visual.gd`'s `HAND_CARRY_OFFSET`
## block records a 0.441 m offset that hung the tsinelas half an arm's length
## from the hand, and says the mesh drop was compensated inside
## `carriable.gd::_step_carried()`. **`carriable.gd` was deleted in the HARRYDAKS
## pivot**, so that compensation no longer exists: `slipper.gd::_step_carried()`
## now simply puts the slipper's ORIGIN on the hand attachment point. Which means
## the carried slipper is correct exactly when the mesh origin sits at the middle
## of the slipper — which is what this lane changed every mesh to do (§ 5.2, the
## volume centroid), and therefore exactly the thing that has to be photographed
## rather than assumed.
##
## `harrydaks_shot.tscn` cannot answer it: it films from the player's own FPP
## camera, where the viewmodel arms fill the lower third of the frame (a known
## `build ui` § 1.7 defect) and the real hand is out of shot entirely.

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

	# Wait for somebody to actually pick a slipper up. Polled rather than hooked
	# because the AI decides when, and a fixed delay photographs an empty hand
	# about half the time.
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
		# The number behind the picture: how far the slipper's origin sits from
		# the hand point it is supposed to be riding. Anything but ~0 is the float.
		print("[carry] holder=%s  hand=%s  slipper=%s  gap=%.4f m" % [
			holder.display_name(), hand.global_position, slipper.global_position,
			hand.global_position.distance_to(slipper.global_position)])

	# ⚠️ EVERY OTHER CAMERA HAS TO BE SWITCHED OFF FIRST, not just outranked.
	# `camera_rig.gd` re-asserts the local player's camera, so a probe camera that
	# merely sets `current = true` is silently overridden on the next frame and
	# the capture comes back as the ordinary FPP view — viewmodel arms, HUD and
	# all, which is exactly the shot this probe exists to avoid.
	for node in get_tree().root.find_children("*", "Camera3D", true, false):
		(node as Camera3D).current = false
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true

	# Three views: an over-the-shoulder third-person, a close side-on of the hand
	# itself, and a front view — "for itself and for others", both asked for.
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
	# The group name is not guaranteed; fall back to a type sweep of the world.
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
