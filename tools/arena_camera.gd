extends Camera3D
class_name ArenaCamera


@export var follow_paths: Array[NodePath] = []
@export var min_distance: float = 6.0
@export var max_distance: float = 45.0
@export var frame_padding: float = 3.0
@export var position_smoothing: float = 5.0
@export var zoom_smoothing: float = 3.0

var _targets: Array[Node3D] = []
var _offset_dir: Vector3
var _current_distance: float
var _fixed_basis: Basis

func _ready() -> void:
	current = false
	_fixed_basis = global_transform.basis
	_current_distance = global_position.length()
	_offset_dir = global_position.normalized() if global_position.length() > 0.001 else Vector3(0, 0.6, 0.8).normalized()

	for path in follow_paths:
		var n := get_node_or_null(path)
		if n is Node3D:
			add_target(n)
		else:
			push_warning("ArenaCamera: follow path '%s' did not resolve to a Node3D" % path)

func add_target(target: Node3D) -> void:
	if target != null and not _targets.has(target):
		_targets.append(target)

func remove_target(target: Node3D) -> void:
	_targets.erase(target)

func _process(delta: float) -> void:
	var still_valid: Array[Node3D] = []
	for t in _targets:
		if is_instance_valid(t):
			still_valid.append(t)
	_targets = still_valid
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

	var half_fov_rad := deg_to_rad(fov * 0.5)
	var required_distance: float = (spread * 0.5) / max(tan(half_fov_rad), 0.05) + frame_padding
	var target_distance: float = clamp(required_distance, min_distance, max_distance)
	_current_distance = lerp(_current_distance, target_distance, zoom_smoothing * delta)

	var target_position := midpoint + _offset_dir * _current_distance
	global_position = global_position.lerp(target_position, position_smoothing * delta)
	global_transform.basis = _fixed_basis

