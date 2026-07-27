extends Node3D

## Temporary M-1 preview harness. Deleted before commit.
##
## Frames a generated mesh at roughly the TPP camera distance the Props are
## actually seen from (Dev_Plan.md §3.1: SpringArm3D spring_length 4.5), so a
## model is judged at the size it will really be read at rather than filling
## the screen.

## Which mesh to frame, and where to drop a PNG. Both overridable from the
## command line so a model can be eyeballed without editing this file:
##
##     godot --path . res://tools/models/preview.tscn -- \
##         --model=res://assets/models/lata.obj --shot=user://lata.png
##
## With --shot the window renders a few frames, writes the PNG and exits, which
## is what makes "show me the mesh" a single command instead of a manual pose-
## and-crop. Without it the window stays open so you can look around.
const DEFAULT_MODEL: String = "res://assets/models/proof_cylinder.obj"
## Matches CameraRig's SpringArm3D spring_length (Dev_Plan.md §3.1), so a Prop
## is judged at the size it is actually read at in play.
const CAMERA_DISTANCE: float = 4.5
## Two frames, not one: the first frame of a fresh viewport can still be clearing
## when the capture runs, which yields a blank or half-drawn PNG.
const CAPTURE_FRAME_DELAY: int = 3

var _screenshot_path: String = ""

func _ready() -> void:
	var model_path := DEFAULT_MODEL
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			model_path = arg.substr(len("--model="))
		elif arg.begins_with("--shot="):
			_screenshot_path = arg.substr(len("--shot="))

	var mesh := load(model_path) as Mesh
	if mesh == null:
		push_error("preview: could not load " + model_path)
		get_tree().quit(1)
		return

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)

	var bounds := mesh.get_aabb()
	var focus := bounds.get_center()

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.53, 0.73, 0.9) # same sky as Main.tscn
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.6
	env.environment = environment
	add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.shadow_enabled = true
	add_child(light)

	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = focus + Vector3(1.0, 0.7, 1.0).normalized() * CAMERA_DISTANCE
	camera.look_at(focus, Vector3.UP)
	camera.current = true

	print("preview: %s  aabb=%s" % [model_path, bounds])
	if _screenshot_path != "":
		_capture_and_quit()

func _capture_and_quit() -> void:
	for _i in range(CAPTURE_FRAME_DELAY):
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(_screenshot_path)
	if err != OK:
		push_error("preview: could not write %s (error %d)" % [_screenshot_path, err])
		get_tree().quit(1)
		return
	print("preview: wrote ", ProjectSettings.globalize_path(_screenshot_path))
	get_tree().quit(0)
