extends Node3D
const MAP := "res://scenes/maps/BayanPlaza.tscn"
const SHOTS := [
	["bp_overhead", Vector3(0, 30, 30), Vector3(0, 0, 0)],
	["bp_corner_ne", Vector3(12.0, 1.6, -12.0), Vector3(60, 6, -60)],
	["bp_corner_nw", Vector3(-12.0, 1.6, -12.0), Vector3(-60, 6, -60)],
	["bp_corner_se", Vector3(12.0, 1.6, 12.0), Vector3(60, 6, 60)],
	["bp_corner_sw", Vector3(-12.0, 1.6, 12.0), Vector3(-60, 6, 60)],
	["bp_eye", Vector3(0, 1.6, 11.0), Vector3(0, 1.4, -14.0)],
	["bp_monument", Vector3(0, 1.25, 6.0), Vector3(-7.6, 2.2, 6.4)],
	["bp_hazard", Vector3(-1.5, 1.25, -1.0), Vector3(-6.5, 0.2, -4.0)],
	["bp_civic", Vector3(2.0, 1.6, 7.5), Vector3(-2.0, 3.0, -14.0)],
]
var _out := ""
var _cam: Camera3D
var _i := 0
var _settle := 0

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	var m: Node3D = load(MAP).instantiate()
	add_child(m)
	await get_tree().process_frame
	var meshes := m.find_children("*", "MeshInstance3D", true, false)
	var missing := 0
	for n in meshes:
		if (n as MeshInstance3D).mesh == null:
			missing += 1
	print("MeshInstance3D: ", meshes.size(), "   null mesh: ", missing)
	print("wall east x = ", (m.get_node("Bounds/WallEast") as Node3D).global_position.x)
	print("markings    = ", m.get_node("Markings").get_child_count())
	_cam = Camera3D.new(); _cam.fov = 75.0; _cam.far = 400.0
	add_child(_cam); _cam.current = true
	_place()

func _place() -> void:
	_cam.global_position = SHOTS[_i][1]
	_cam.look_at(SHOTS[_i][2], Vector3.UP)
	_settle = 30

func _process(_d: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + String(SHOTS[_i][0]) + ".png")
	print("wrote ", SHOTS[_i][0])
	_i += 1
	if _i >= SHOTS.size():
		set_process(false)
		get_tree().quit(0)
		return
	_place()

