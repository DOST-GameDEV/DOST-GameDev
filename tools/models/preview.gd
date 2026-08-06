extends Node3D


const DEFAULT_MODEL: String = "res://assets/models/proof_cylinder.obj"
const CAMERA_DISTANCE: float = 4.5
const CAPTURE_FRAME_DELAY: int = 3

var _screenshot_path: String = ""

func _ready() -> void:
	var model_path := DEFAULT_MODEL
	var distance := CAMERA_DISTANCE
	var yaw_deg := 45.0
	var elev_deg := 26.3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			model_path = arg.substr(len("--model="))
		elif arg.begins_with("--shot="):
			_screenshot_path = arg.substr(len("--shot="))
		elif arg.begins_with("--yaw="):
			yaw_deg = arg.substr(len("--yaw=")).to_float()
		elif arg.begins_with("--elev="):
			elev_deg = arg.substr(len("--elev=")).to_float()
		elif arg.begins_with("--dist="):
			distance = arg.substr(len("--dist=")).to_float()

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
	environment.background_color = Color(0.53, 0.73, 0.9)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.6
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

