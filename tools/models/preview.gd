extends Node3D

## Temporary M-1 preview harness. Deleted before commit.
##
## Frames a generated mesh at roughly the TPP camera distance the Props are
## actually seen from (Dev_Plan.md §3.1: SpringArm3D spring_length 4.5), so a
## model is judged at the size it will really be read at rather than filling
## the screen.

const MODEL_PATH: String = "res://assets/models/proof_cylinder.obj"
const CAMERA_DISTANCE: float = 4.5

func _ready() -> void:
	var mesh := load(MODEL_PATH) as Mesh
	if mesh == null:
		push_error("preview: could not load " + MODEL_PATH)
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
