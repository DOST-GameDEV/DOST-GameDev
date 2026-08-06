extends Node3D


const MODEL := "res://assets/characters/persons/character-male-f.glb"
const VIEWS := [
	["front_if_negZ", Vector3(0, 1.9, -4.2)],
	["front_if_posZ", Vector3(0, 1.9, 4.2)],
]

var _out := ""
var _i := 0
var _settle := 0
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
	e.ambient_light_energy = 1.0
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 20, 0)
	add_child(sun)
	var model: Node3D = load(MODEL).instantiate()
	model.scale = Vector3.ONE * 2.38
	add_child(model)
	var animator := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator != null and animator.has_animation("idle"):
		animator.play("idle")
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_place()

func _place() -> void:
	_cam.global_position = VIEWS[_i][1]
	_cam.look_at(Vector3(0, 1.5, 0), Vector3.UP)
	_settle = 20

func _process(_d: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + "model_" + String(VIEWS[_i][0]) + ".png")
	print("wrote ", VIEWS[_i][0])
	_i += 1
	if _i >= VIEWS.size():
		set_process(false)
		get_tree().quit(0)
		return
	_place()

