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
##
## B-03 fix: targets are no longer just a one-shot cache resolved from
## `follow_paths` in _ready(). `follow_paths` still works for local-test
## scenes wired directly in the editor (see Main.tscn), but callers should
## use add_target()/remove_target() at runtime instead — main.gd calls these
## as networked characters spawn/despawn, and _process() also tolerates a
## target being freed out from under it (e.g. _clear_local_test_characters()
## queue_free()-ing the local-test nodes when a networked match starts),
## instead of dereferencing a freed Node3D every frame.

@export var follow_paths: Array[NodePath] = []
@export var min_distance: float = 6.0
@export var max_distance: float = 45.0 ## must cover the ~57-unit floor diagonal
@export var frame_padding: float = 3.0 ## extra room added around the target spread
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
			add_target(n)
		else:
			push_warning("ArenaCamera: follow path '%s' did not resolve to a Node3D" % path)

## Start following `target` (e.g. a newly spawned networked character). Safe
## to call more than once for the same target.
func add_target(target: Node3D) -> void:
	if target != null and not _targets.has(target):
		_targets.append(target)

## Stop following `target` (e.g. a disconnecting peer's character, or the
## local-test dummies being cleared when a networked match starts).
func remove_target(target: Node3D) -> void:
	_targets.erase(target)

func _process(delta: float) -> void:
	# Drop anything freed since last frame (e.g. local-test characters torn
	# down by _clear_local_test_characters(), which never calls
	# remove_target()) instead of dereferencing it. NOT Array.filter() with a
	# Node3D-typed lambda parameter: passing an already-freed reference as an
	# argument to a typed parameter throws "Cannot convert argument 1 from
	# Object to Object" from inside filter() itself, every single frame — this
	# was the actual remaining cause of B-03's per-frame error flood even
	# after add_target()/remove_target() landed. A plain loop with an untyped
	# local doesn't trigger that argument-type conversion.
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

	# Distance needed so `spread` fits inside the camera's field of view, not a
	# guessed linear clamp — otherwise targets silently fall outside the frame
	# once they're farther apart than whatever number we picked by eye.
	var half_fov_rad := deg_to_rad(fov * 0.5)
	var required_distance: float = (spread * 0.5) / max(tan(half_fov_rad), 0.05) + frame_padding
	var target_distance: float = clamp(required_distance, min_distance, max_distance)
	_current_distance = lerp(_current_distance, target_distance, zoom_smoothing * delta)

	var target_position := midpoint + _offset_dir * _current_distance
	global_position = global_position.lerp(target_position, position_smoothing * delta)
	global_transform.basis = _fixed_basis
