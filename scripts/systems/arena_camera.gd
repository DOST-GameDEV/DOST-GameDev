extends Camera3D
class_name ArenaCamera

## Generic follow-cam for the prototype arena. Keeps the fixed downward pitch
## the scene was hand-placed with, but slides the camera to track the
## midpoint of whatever's in `follow_paths` and pulls back/in depending on
## how far apart they are — so a 1v1 test or a full 2v2 both stay framed
## without needing per-map camera tuning yet.
##
## Not a "real" competitive camera (no collision avoidance, no per-map
## bounds) — just enough so testing isn't stuck on a locked static shot.
## Swap or extend this once real maps (Eskinita / Bayan Plaza) exist and
## we know what needs to stay on-screen (bases, hazards, etc).

@export var follow_paths: Array[NodePath] = []
@export var min_distance: float = 8.0
@export var max_distance: float = 20.0
@export var distance_padding: float = 4.0 ## extra room added on top of target spread
@export var position_smoothing: float = 5.0 ## higher = snappier follow
@export var zoom_smoothing: float = 3.0 ## higher = snappier zoom response

var _targets: Array[Node3D] = []
var _offset_dir: Vector3
var _current_distance: float
var _fixed_basis: Basis

func _ready() -> void:
	_fixed_basis = global_transform.basis
	_current_distance = global_position.length()
	_offset_dir = global_position.normalized() if global_position.length() > 0.001 else Vector3(0, 0.6, 0.8).normalized()

	for path in follow_paths:
		var n := get_node_or_null(path)
		if n is Node3D:
			_targets.append(n)
		else:
			push_warning("ArenaCamera: follow path '%s' did not resolve to a Node3D" % path)

func _process(delta: float) -> void:
	if _targets.is_empty():
		return

	var midpoint := Vector3.ZERO
	for t in _targets:
		midpoint += t.global_position
	midpoint /= _targets.size()

	var spread := 0.0
	for i in range(_targets.size()):
		for j in range(i + 1, _targets.size()):
			spread = max(spread, _targets[i].global_position.distance_to(_targets[j].global_position))

	var target_distance: float = clamp(spread + distance_padding, min_distance, max_distance)
	_current_distance = lerp(_current_distance, target_distance, zoom_smoothing * delta)

	var target_position := midpoint + _offset_dir * _current_distance
	global_position = global_position.lerp(target_position, position_smoothing * delta)
	global_transform.basis = _fixed_basis
