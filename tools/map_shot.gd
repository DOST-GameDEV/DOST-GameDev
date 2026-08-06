extends Node3D

const DEFAULT_OUT := "res://"
const SHOTS: Array[Dictionary] = [
	{"name": "wide", "yaw": 35.0, "distance": 26.0, "height": 15.0, "look_y": 1.0},
	{"name": "low", "yaw": 200.0, "distance": 17.0, "height": 4.5, "look_y": 1.6},
	{"name": "top", "yaw": 0.0, "distance": 0.1, "height": 34.0, "look_y": 0.0},
]

var _map_id := &"eskinita"
var _out := DEFAULT_OUT
var _frames := 0
var _camera: Camera3D = null

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_map_id = StringName(args[0])
	if args.size() > 1:
		_out = args[1]
	GameLaunch.selected_map = _map_id
	var path := GameLaunch.selected_map_scene()
	print("[map_shot] %s -> %s" % [_map_id, path])
	var map := (load(path) as PackedScene).instantiate()
	add_child(map)
	_camera = Camera3D.new()
	_camera.fov = 55.0
	add_child(_camera)
	_camera.current = true
	if get_viewport().world_3d.environment == null and _find_environment(self) == null:
		var sky := Sky.new()
		sky.sky_material = ProceduralSkyMaterial.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		var holder := WorldEnvironment.new()
		holder.environment = env
		add_child(holder)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
		sun.light_energy = 1.1
		sun.shadow_enabled = true
		add_child(sun)

func _find_environment(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	for child in node.get_children():
		var found := _find_environment(child)
		if found != null:
			return found
	return null

func _process(_delta: float) -> void:
	_frames += 1
	for i in SHOTS.size():
		var place_at: int = 60 + i * 60
		if _frames == place_at:
			_place(SHOTS[i])
		elif _frames == place_at + 40:
			_shot("%s_%s" % [_map_id, SHOTS[i]["name"]])
	if _frames == 60 + SHOTS.size() * 60:
		get_tree().quit()

func _place(shot: Dictionary) -> void:
	var yaw := deg_to_rad(float(shot["yaw"]))
	var distance := float(shot["distance"])
	var look := Vector3(0.0, float(shot["look_y"]), 0.0)
	var want := Vector3(sin(yaw) * distance, float(shot["height"]), cos(yaw) * distance)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(look, want)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var clear: Vector3 = hit["position"]
		want = look + (clear - look) * 0.9
	_camera.global_position = want
	_camera.look_at(look, Vector3.UP)

func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(_out + name + ".png")
	print("[map_shot] %s%s.png -> %d" % [_out, name, err])

