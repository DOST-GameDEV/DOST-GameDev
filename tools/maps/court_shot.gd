extends Node


const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

const CAMERA_HEIGHT: float = 34.0
const ORTHO_SIZE: float = 30.0
const TILT_DEG: float = 68.0

var _out := "res://"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		GameLaunch.selected_map = StringName(String(args[1]).to_lower())
	print("[court] map=%s" % GameLaunch.selected_map)
	add_child(MAIN_SCENE.instantiate())
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ORTHO_SIZE
	camera.far = 200.0
	add_child(camera)
	var tilt := deg_to_rad(TILT_DEG)
	camera.global_position = Vector3(0.0, CAMERA_HEIGHT, CAMERA_HEIGHT / tan(tilt))
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true
	print("[court] CONFINEMENT_RADIUS=%.2f  spawn_ring=%.2f  throwing_line=%.2f"
		% [CharacterBase.CONFINEMENT_RADIUS,
			CharacterBase.CONFINEMENT_RADIUS + 2.0,
			CharacterBase.CONFINEMENT_RADIUS + 1.0])
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(_out + "court.png")
	print("[court] wrote %s (%dx%d)" % [
		_out + "court.png" if err == OK else "FAILED",
		image.get_width(), image.get_height()])
	get_tree().quit()

