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
##         --model=res://assets/models/lata_pasip.obj --shot=user://lata.png
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
	var distance := CAMERA_DISTANCE
	# Defaults reproduce the old fixed (1, 0.7, 1) bearing exactly, so every
	# existing invocation frames what it always framed.
	var yaw_deg := 45.0
	var elev_deg := 26.3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			model_path = arg.substr(len("--model="))
		elif arg.begins_with("--shot="):
			_screenshot_path = arg.substr(len("--shot="))
		elif arg.begins_with("--yaw="):
			# Degrees around Y. 0 looks along +Z at the model's heel.
			yaw_deg = arg.substr(len("--yaw=")).to_float()
		elif arg.begins_with("--elev="):
			# Degrees above the horizon. Use 6-12 to look THROUGH a strap arch.
			elev_deg = arg.substr(len("--elev=")).to_float()
		elif arg.begins_with("--dist="):
			# Judge silhouette and readability at the default 4.5; drop closer
			# only to inspect a detail. A model that only works up close is not
			# finished — nobody plays with their face against the Prop.
			distance = arg.substr(len("--dist=")).to_float()

	# Takes either a bare mesh (.obj) or a scene (.tscn). The scene path matters:
	# it is what the game actually instances, so previewing CanVisual.tscn proves
	# the whole asset chain the Prop uses, not just that a file parses.
	var resource := load(model_path)
	var bounds := AABB()
	if resource is Mesh:
		var instance := MeshInstance3D.new()
		instance.mesh = resource
		add_child(instance)
		bounds = (resource as Mesh).get_aabb()
	elif resource is PackedScene:
		var model := (resource as PackedScene).instantiate() as Node3D
		if model == null:
			push_error("preview: '%s' is not a 3D scene" % model_path)
			get_tree().quit(1)
			return
		add_child(model)
		bounds = _merged_bounds(model)
	else:
		push_error("preview: could not load " + model_path)
		get_tree().quit(1)
		return

	var focus := bounds.get_center()

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.53, 0.73, 0.9) # same sky as Main.tscn
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.6
	# Load-bearing, and the reason the first previews came out half-black.
	# `ambient_light_sky_contribution` defaults to 1.0, meaning "the sky supplies
	# all ambient light" — and with BG_COLOR there is no sky, so ambient
	# evaluates to black no matter what ambient_light_color says. Setting it to 0
	# is what actually hands control to ambient_light_color. Main.tscn had the
	# same misconfiguration (B-72).
	environment.ambient_light_sky_contribution = 0.0
	env.environment = environment
	add_child(env)
	print("DEBUG ambient: source=", environment.ambient_light_source,
		" sky_contrib=", environment.ambient_light_sky_contribution,
		" energy=", environment.ambient_light_energy)
	print("DEBUG world env: ", get_viewport().world_3d.environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.shadow_enabled = true
	add_child(light)

	# ⚠️ THE CAMERA IS AIMABLE NOW, AND IT HAD TO BECOME SO. The fixed
	# (1, 0.7, 1) bearing looks DOWN on the model at ~35 degrees, which is the
	# worst possible angle for judging a slipper: the whole point of a strap is
	# the daylight gap between it and the sole, and from above the sole sits
	# directly behind that gap and fills it in. 🧑, looking at exactly that shot:
	# *"i dont even see the straps bruh"*. A low `--elev` puts the horizon
	# through the gap and the arch reads instantly.
	var yaw_rad := deg_to_rad(yaw_deg)
	var elev_rad := deg_to_rad(elev_deg)
	var offset := Vector3(
		cos(elev_rad) * sin(yaw_rad), sin(elev_rad), cos(elev_rad) * cos(yaw_rad))
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = focus + offset.normalized() * distance
	camera.look_at(focus, Vector3.UP)
	camera.current = true

	print("preview: %s  aabb=%s" % [model_path, bounds])
	if _screenshot_path != "":
		_capture_and_quit()

## Union of every visual's bounds in the scene, so the camera frames a multi-mesh
## model the same way it frames a single one.
func _merged_bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "VisualInstance3D", true, false):
		var box: AABB = (node as VisualInstance3D).get_aabb()
		box = (node as Node3D).transform * box
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
	return bounds

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
