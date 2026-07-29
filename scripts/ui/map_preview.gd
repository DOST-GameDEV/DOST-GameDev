extends SubViewportContainer
class_name MapPreview

## The GAME screen's background: the map you actually have selected, live in 3D,
## swapping the instant you cycle the picker.
##
## Replaces a `blueprint_grid.gdshader` ColorRect. That grid was a placeholder
## standing in for art nobody had yet, and it had outlived its job — by the time
## two dressed maps existed, the screen was asking the player to choose between
## two names on a backdrop that showed neither.
##
## HOW IT RENDERS. A SubViewport with `own_world_3d`, so the map brings its own
## WorldEnvironment, its own sun and its own fog and none of it leaks into — or
## is contaminated by — whatever else the menu is doing. The camera is ours, not
## the map's; maps ship no camera because in a match every character carries its
## own rig (`Dev_Plan.md` §3.1).
##
## ⚠️ MAPS ARE CACHED AND RE-PARENTED, NEVER HIDDEN. `visible = false` on a map
## root looks like it should work and does not: `visible` propagates to
## VisualInstance3D children, and a map's two most important nodes —
## WorldEnvironment and DirectionalLight3D — are neither. A hidden map therefore
## keeps lighting the world and keeps fighting the other map's environment for
## it, which reads as the sky and fog changing while the geometry does not. So
## the inactive map is REMOVED from the tree and parked, alive, in `_cache`.
## Re-adding it is instant, which is what makes cycling the picker feel free
## after the first visit to each map.
##
## THE SCRIM IS A GRADIENT, NOT A FLAT WASH, and that is deliberate: every
## control on this screen sits in the left half of the frame, so the scrim in
## GameSetup.tscn runs dark on the left and nearly clear on the right. A flat
## scrim would have to be dark enough for cream-on-wood lettering to survive
## across the whole viewport, and at that strength there is no point rendering
## the map at all.
##
## ⚠️ AND THEY ARE SILENCED ON THE WAY IN. Every map carries an `Ambience` node
## whose AudioStreamPlayer is `autoplay = true` — instancing one here would start
## the street bed playing over the menu, and cycling the picker would restart it
## on every press. `_silence()` strips the streams before the instance is ever
## added to the tree, so the sound never gets a frame to start in.

## Where the camera sits when a map's registry entry says nothing. Deliberately
## a legible three-quarter view rather than anything clever — a new map should
## look acceptable before anyone has tuned it, and obviously untuned rather than
## subtly wrong.
const DEFAULT_YAW: float = 34.0
const DEFAULT_DISTANCE: float = 19.0
const DEFAULT_HEIGHT: float = 8.5

## The camera sways instead of orbiting. A full orbit would eventually swing
## behind the facades and show the player the back of a set; a slow sway keeps
## the tuned angle and only ever leaves it by a few degrees, so every frame is
## one somebody chose.
const SWAY_DEGREES: float = 7.0
const SWAY_PERIOD: float = 26.0

## What the camera aims at, above the play area's floor — roughly head height on
## a standing Person, so the shot is framed on the fight rather than on the road.
const LOOK_HEIGHT: float = 1.6

@onready var viewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/Camera3D

var _cache: Dictionary = {}          ## StringName -> Node3D, parked out of tree
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

## Frees the parked maps. Godot only frees nodes that are IN the tree when their
## owner goes, and these deliberately are not — without this, leaving the GAME
## screen would leak every map the player looked at.
func _exit_tree() -> void:
	for map in _cache.values():
		if is_instance_valid(map) and map.get_parent() == null:
			map.free()
	_cache.clear()

## Shows the map described by a `GameLaunch.MAPS` entry. Cheap to call with the
## entry that is already showing — the picker fires this on every arrow press.
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
		# Both set BEFORE the node ever enters the tree: PROCESS_MODE_DISABLED so
		# the map's hazard and kill-plane areas never tick in a menu, and the
		# silencing so autoplay has no stream left to start.
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

## Where the round happens, which is what the shot should be about. Every map
## carries a `SpawnPoints` node — it is how `main.gd` places characters — so
## averaging its markers finds the play area without this needing to know
## anything map-specific. Falls back to the origin, which is where both current
## maps put their base circle anyway.
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

## Strips every stream out of a detached map instance. Walks the whole subtree
## rather than looking for the `Ambience` node by name: the name is a convention
## both maps happen to share, and a map that grew a second player somewhere else
## would silently start making noise on the menu.
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
