extends Control
class_name OffscreenIndicators

## Checklist 3.4 (U-6b) — screen-edge arrows for your teammate and the
## currently tracked Can. `Dev_Plan.md` §3.3 calls these **mandatory** for
## FPP: a Person's camera has a much narrower awareness cone than a Prop's
## TPP, and U-6 deferred exactly this mitigation.
##
## Driven from hud.gd, which already resolves the local character once a
## frame for the crosshair (`you_card.get_local_character()`) — `update()`
## takes that as a parameter instead of this file scanning for it a second
## time, same rule `you_card.gd`'s own doc already states for the local-
## character scan itself.
##
## Structure only, plain styling — the design lane restyles the arrow glyphs
## once this is merged, same sequencing as 0.1's meters.

## Keeps the arrow's own size inside the true screen edge rather than
## clipping half of it off-frame.
const EDGE_MARGIN: float = 40.0
## Roughly chest height, so the arrow points at "the unit" rather than at
## whatever happens to be at its feet — same reasoning IMPACT_PARTICLE_HEIGHT
## already uses in character_visual.gd.
const TARGET_HEIGHT_OFFSET: Vector3 = Vector3(0, 0.5, 0)

@onready var teammate_arrow: Control = %TeammateArrow
@onready var teammate_label: Label = %TeammateLabel
@onready var can_arrow: Control = %CanArrow
@onready var can_label: Label = %CanLabel

func _ready() -> void:
	teammate_label.text = "▲"
	can_label.text = "▲"
	teammate_label.modulate = UiTheme.INK
	can_label.modulate = UiTheme.HIGHLIGHT
	teammate_arrow.visible = false
	can_arrow.visible = false

## Called once a frame by hud.gd. `local_character` may be null before it
## resolves, or on a peer with no match loaded — both just hide everything.
func update(local_character: CharacterBase) -> void:
	if local_character == null or not is_instance_valid(local_character):
		teammate_arrow.visible = false
		can_arrow.visible = false
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		teammate_arrow.visible = false
		can_arrow.visible = false
		return
	_update_one(teammate_arrow, camera, _find_teammate(local_character))
	_update_one(can_arrow, camera, _find_can(local_character))

## The standard "radar arrow" recipe: project the target, detect off-screen
## (including behind-camera, which `unproject_position` does not itself
## flag), then clamp the centre-to-target ray to the inset screen rect and
## point the arrow along it.
func _update_one(arrow: Control, camera: Camera3D, target: CharacterBase) -> void:
	# `is_inside_tree()`, not just `is_instance_valid()` — measured live during
	# 4.3's peer-drop testing: a character mid-`queue_free()` (main.gd's
	# `_on_player_disconnected`, fired on every peer, not just the host —
	# every surviving peer frees its own copy of a departed one) is a real,
	# non-freed Object for one or more frames after leaving the tree, so
	# `is_instance_valid()` alone still passes it through. `global_position`
	# below needs a live parent chain to resolve and throws
	# `Condition "!is_inside_tree()" is true` otherwise — this was reachable
	# on any frame a tracked teammate or Can disconnects, not a hypothetical.
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		arrow.visible = false
		return
	var world_pos := target.global_position + TARGET_HEIGHT_OFFSET
	var to_target := world_pos - camera.global_position
	# Godot's unproject_position() divides by a plane distance that hits
	# exactly zero the instant a target sits exactly perpendicular to the
	# camera's forward axis (dead level with the lens, neither ahead nor
	# behind) — logging an engine error, not throwing, but still noise on
	# every frame a teammate happens to cross that exact line. A target this
	# close to the camera itself hits the same "p.d == 0" case regardless of
	# angle. Both are edge cases with nothing meaningful to point at anyway.
	var forward_component := -camera.global_transform.basis.z.dot(to_target)
	if to_target.length() < 0.1 or absf(forward_component) < 0.05:
		arrow.visible = false
		return
	var is_behind := forward_component < 0.0
	var viewport_size := get_viewport_rect().size
	var screen_pos := camera.unproject_position(world_pos)
	if is_behind:
		# unproject_position() mirrors a behind-camera point through the
		# centre of the frame instead of flagging it — undo that so the
		# arrow points the short way around to the target, not the long way.
		screen_pos = viewport_size - screen_pos
	var center := viewport_size / 2.0
	var on_screen := not is_behind \
		and screen_pos.x >= 0.0 and screen_pos.x <= viewport_size.x \
		and screen_pos.y >= 0.0 and screen_pos.y <= viewport_size.y
	if on_screen:
		arrow.visible = false
		return
	arrow.visible = true
	var dir := screen_pos - center
	if dir.length() < 0.01:
		dir = Vector2.UP # degenerate — dead centre behind; pick an arbitrary edge
	dir = dir.normalized()
	var half := center - Vector2.ONE * EDGE_MARGIN
	var scale_x: float = (half.x / absf(dir.x)) if absf(dir.x) > 0.0001 else INF
	var scale_y: float = (half.y / absf(dir.y)) if absf(dir.y) > 0.0001 else INF
	var t: float = minf(scale_x, scale_y)
	arrow.position = center + dir * t - arrow.size / 2.0
	# The glyph points up (-Y) at rotation 0; `Vector2.angle()` is measured
	# from +X, so it needs the quarter turn to line up with `dir`.
	arrow.rotation = dir.angle() + PI / 2.0

## Same team, not yourself — a team is 1 Person + 1 Prop (never two of the
## same kind), so this is unambiguous without checking is_person at all.
func _find_teammate(local_character: CharacterBase) -> CharacterBase:
	return _find_character(get_tree().current_scene, func(c: CharacterBase) -> bool:
		return c != local_character and c.team == local_character.team)

## Reads RoundManager's own tracked-Can list rather than re-scanning for
## `is_can` — that is the one place this is already kept correct across a
## role swap (see round_manager.gd::get_tracked_cans doc). Skips yourself:
## if you ARE the tracked Can, you don't need an arrow pointing at your own
## body.
func _find_can(local_character: CharacterBase) -> CharacterBase:
	for can in RoundManager.get_tracked_cans():
		if is_instance_valid(can) and can != local_character:
			return can
	return null

func _find_character(node: Node, matches: Callable) -> CharacterBase:
	if node is CharacterBase and matches.call(node):
		return node
	for child in node.get_children():
		var found := _find_character(child, matches)
		if found:
			return found
	return null
