extends Node3D


const MAP := "res://scenes/maps/Eskinita.tscn"

const SHOTS: Array = [
	["void_overhead", Vector3(0, 25, 26), Vector3(0, 0, -6)],
	["void_corner_ne", Vector3(8.2, 1.6, -17.6), Vector3(60, 6, -60)],
	["void_corner_nw", Vector3(-8.2, 1.6, -17.6), Vector3(-60, 6, -60)],
	["void_corner_se", Vector3(8.2, 1.6, 17.6), Vector3(60, 6, 60)],
	["void_corner_sw", Vector3(-8.2, 1.6, 17.6), Vector3(-60, 6, 60)],
	["street_eye", Vector3(0, 1.6, 12.0), Vector3(0, 1.2, -14.0)],
	["street_lane", Vector3(0, 1.25, 6.0), Vector3(0, 0.4, 0.0)],
]

var _out: String = ""
var _camera: Camera3D
var _index: int = 0
var _settle: int = 0

func _ready() -> void:
	var argv := OS.get_cmdline_user_args()
	_out = argv[0] if argv.size() > 0 else ""
	add_child(load(MAP).instantiate())
	_camera = Camera3D.new()
	_camera.fov = 75.0
	_camera.far = 400.0
	add_child(_camera)
	_camera.current = true
	_place()

func _place() -> void:
	var shot: Array = SHOTS[_index]
	_camera.global_position = shot[1]
	_camera.look_at(shot[2], Vector3.UP)
	_settle = 45

func _process(_delta: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var shot: Array = SHOTS[_index]
	var path: String = _out + String(shot[0]) + ".png"
	if image.save_png(path) != OK:
		push_error("void_probe: could not write " + path)
	else:
		print("wrote ", path)
	_index += 1
	if _index >= SHOTS.size():
		set_process(false)
		get_tree().quit(0)
		return
	_place()

