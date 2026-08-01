extends Node3D
## Poster shots of a map — 🧑 asked for pictures of the maps for a poster.
##
## Loads ONE map scene on its own (no match, no HUD, no characters) and takes a
## few wide frames of it from a camera this script owns, so the result is the
## place rather than a gameplay screenshot with a crosshair over it.
##
## USAGE — the PLAIN exe, never `--headless` and never the console one for this:
## headless has no rendering device and every capture comes back blank.
##
##   godot --path . tools/map_shot.tscn --quit-after 260 \
##       --resolution 2560x1440 -- eskinita <out-dir>
##
## `<out-dir>` must already exist and end in a slash. Map ids come from
## `GameLaunch.MAPS` — `eskinita`, `bayan_plaza`.
##
## ⚠️ AN EXPLICIT `--resolution` IS THE POINT HERE and it is also why
## `GameLaunch.fit_window_to_usable_screen()` stands aside when one is passed:
## a poster wants more pixels than the desktop has, and the shot is the
## VIEWPORT, so the window size IS the image size.

const DEFAULT_OUT := "res://"
## Camera set-ups, in order. Distance and height are metres from the base
## circle, which is the world origin on every map (`_act_evade`'s own note).
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
	# Through GameLaunch rather than by path, so a poster shot cannot quietly
	# render a different map than the picker would load — that is B-104, which
	# resolved BOTH map entries to Eskinita and made Bayan Plaza unrenderable.
	GameLaunch.selected_map = _map_id
	var path := GameLaunch.selected_map_scene()
	print("[map_shot] %s -> %s" % [_map_id, path])
	var map := (load(path) as PackedScene).instantiate()
	add_child(map)
	_camera = Camera3D.new()
	_camera.fov = 55.0
	add_child(_camera)
	_camera.current = true
	# ⚠️ A MAP LOADED ON ITS OWN HAS NO SKY. The WorldEnvironment lives in
	# Main.tscn, not in the map scenes, so the first run of this came back with
	# a flat grey void behind the rooftops — correct for a geometry check and
	# useless for a poster. Added only when the map does not bring its own.
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
		# And a key light, for the same reason — the maps are lit by Main's sun.
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
	# Two settle frames per shot before the capture: the maps are built at
	# runtime by tools/maps/*.py output, and a frame taken on arrival catches
	# meshes still being parented.
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
	# ⚠️ PULL IN UNTIL THE BASE CIRCLE IS ACTUALLY VISIBLE, AND THE FIRST CUT DID
	# NOT. The low angle on `bayan_plaza` put the camera inside a building and
	# the capture came back a flat brown rectangle — a picture of a wall, saved
	# with no error, which is exactly the "it ran, so it worked" failure this
	# whole tools/ directory exists to stop.
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
