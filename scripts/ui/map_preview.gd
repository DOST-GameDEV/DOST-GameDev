extends SubViewportContainer
class_name MapPreview


const DEFAULT_YAW: float = 34.0
const DEFAULT_DISTANCE: float = 19.0
const DEFAULT_HEIGHT: float = 8.5

const SWAY_DEGREES: float = 7.0
const SWAY_PERIOD: float = 26.0

const LOOK_HEIGHT: float = 1.6

@onready var viewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/Camera3D

var _cache: Dictionary = {}
var _current: Node3D = null
var _current_id: StringName = &""
var _pivot: Vector3 = Vector3.ZERO
var _yaw: float = DEFAULT_YAW
var _distance: float = DEFAULT_DISTANCE
var _height: float = DEFAULT_HEIGHT
var _time: float = 0.0

func _ready() -> void:
	_apply_camera()

func _process(delta: float) -> void:
	if _current == null:
		return
	_time += delta
	_apply_camera()

func _exit_tree() -> void:
	for map in _cache.values():
		if is_instance_valid(map) and map.get_parent() == null:
			map.free()
	_cache.clear()

func show_map(entry: Dictionary) -> void:
	var id: StringName = entry["id"]
	if id == _current_id:
		return

	if _current != null:
		viewport.remove_child(_current)
	_current_id = id
	_current = _cache.get(id)

	if _current == null:
		var packed := load(String(entry["scene"])) as PackedScene
		if packed == null:
			push_warning("MapPreview: could not load '%s'" % entry["scene"])
			_current_id = &""
			return
		_current = packed.instantiate()
		_current.process_mode = Node.PROCESS_MODE_DISABLED
		_silence(_current)
		_cache[id] = _current

	viewport.add_child(_current)
	_pivot = _play_area_centre(_current)

	var preview: Dictionary = entry.get("preview", {})
	_yaw = float(preview.get("yaw", DEFAULT_YAW))
	_distance = float(preview.get("distance", DEFAULT_DISTANCE))
	_height = float(preview.get("height", DEFAULT_HEIGHT))
	_apply_camera()

func _play_area_centre(map: Node3D) -> Vector3:
	var points := map.get_node_or_null("SpawnPoints")
	if points == null or points.get_child_count() == 0:
		return Vector3.ZERO
	var sum := Vector3.ZERO
	var count := 0
	for child in points.get_children():
		if child is Node3D:
			sum += (child as Node3D).position
			count += 1
	return sum / count if count > 0 else Vector3.ZERO

func _apply_camera() -> void:
	if camera == null:
		return
	var sway := sin(_time * TAU / SWAY_PERIOD) * SWAY_DEGREES
	var offset := Basis(Vector3.UP, deg_to_rad(_yaw + sway)) * Vector3(0.0, 0.0, _distance)
	camera.position = _pivot + offset + Vector3(0.0, _height, 0.0)
	camera.look_at(_pivot + Vector3(0.0, LOOK_HEIGHT, 0.0))

func _silence(node: Node) -> void:
	if node is AudioStreamPlayer:
		var player := node as AudioStreamPlayer
		player.autoplay = false
		player.stream = null
	elif node is AudioStreamPlayer3D:
		var player_3d := node as AudioStreamPlayer3D
		player_3d.autoplay = false
		player_3d.stream = null
	for child in node.get_children():
		_silence(child)

