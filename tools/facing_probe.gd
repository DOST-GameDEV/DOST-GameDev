extends Node3D
var _out := ""
var _i := 0
var _settle := 0
const VIEWS := [["front_negZ", Vector3(0, 3, 14)], ["back_posZ", Vector3(0, 3, -14)],
	["right_posX", Vector3(14, 3, 0)], ["left_negX", Vector3(-14, 3, 0)]]
var _cam: Camera3D

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.35, 0.5, 0.7)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	add_child(sun)
	var b: Node3D = load("res://assets/models/kits/city/building-type-a.glb").instantiate()
	b.scale = Vector3(5, 5, 5)
	add_child(b)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_place()

func _place() -> void:
	_cam.global_position = VIEWS[_i][1]
	_cam.look_at(Vector3(0, 2, 0), Vector3.UP)
	_settle = 12

func _process(_d: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + "face_" + String(VIEWS[_i][0]) + ".png")
	print("wrote ", VIEWS[_i][0])
	_i += 1
	if _i >= VIEWS.size():
		set_process(false)
		get_tree().quit(0)
		return
	_place()

