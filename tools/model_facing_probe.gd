extends Node3D

## WHICH WAY DOES A PERSON RIG ACTUALLY FACE IN ITS OWN LOCAL SPACE?
##
## Reported across sessions as "the attacker spawns facing backward and the AI
## moves/attacks in reverse. Check if the model's face is incorrectly configured
## to its back." `main.gd::_spawn_yaw()` and every directional ability agree on
## Godot's convention — a body's forward is `-basis.z` — so if the imported .glb
## has its face on +Z, every one of them is correct and the CHARACTER still looks
## backwards, which is exactly the shape of a bug that survives being "fixed"
## repeatedly in the yaw maths.
##
## Renders the rig at yaw 0 from the -Z side (where Godot says its face is) and
## from the +Z side. Whichever shot shows a FACE is the model's real front.
##
##     godot --path . tools/model_facing_probe.tscn --resolution 640x640 -- C:\tmp\

const MODEL := "res://assets/characters/persons/character-male-f.glb"
const VIEWS := [
	["front_if_negZ", Vector3(0, 1.9, -4.2)],  # Godot's "front" for a -Z facer
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
