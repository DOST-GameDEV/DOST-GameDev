extends Control
class_name OffscreenIndicators


const EDGE_MARGIN: float = 40.0
const TARGET_HEIGHT_OFFSET: Vector3 = Vector3(0, 0.5, 0)
const GLYPH_OUTLINE: int = 6

@onready var teammate_arrow: Control = %TeammateArrow
@onready var teammate_label: Label = %TeammateLabel
@onready var can_arrow: Control = %CanArrow
@onready var can_label: Label = %CanLabel

func _ready() -> void:
	teammate_label.text = "▲"
	can_label.text = "▲"
	teammate_label.modulate = UiTheme.INK
	can_label.modulate = UiTheme.HIGHLIGHT
	for label in [teammate_label, can_label]:
		label.add_theme_constant_override("outline_size", GLYPH_OUTLINE)
		label.add_theme_color_override("font_outline_color", UiTheme.INK)
	teammate_arrow.visible = false
	can_arrow.visible = false

func set_can_arrow_colour(colour: Color) -> void:
	can_label.modulate = colour

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
	_update_one(teammate_arrow, camera, _find_own_slipper(local_character))
	_update_one(can_arrow, camera, RoundManager.lata)

func _update_one(arrow: Control, camera: Camera3D, target: Node3D) -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		arrow.visible = false
		return
	var world_pos := target.global_position + TARGET_HEIGHT_OFFSET
	var to_target := world_pos - camera.global_position
	var forward_component := -camera.global_transform.basis.z.dot(to_target)
	if to_target.length() < 0.1 or absf(forward_component) < 0.05:
		arrow.visible = false
		return
	var is_behind := forward_component < 0.0
	var viewport_size := get_viewport_rect().size
	var screen_pos := camera.unproject_position(world_pos)
	if is_behind:
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
		dir = Vector2.UP
	dir = dir.normalized()
	var half := center - Vector2.ONE * EDGE_MARGIN
	var scale_x: float = (half.x / absf(dir.x)) if absf(dir.x) > 0.0001 else INF
	var scale_y: float = (half.y / absf(dir.y)) if absf(dir.y) > 0.0001 else INF
	var t: float = minf(scale_x, scale_y)
	arrow.position = center + dir * t - arrow.size / 2.0
	arrow.rotation = dir.angle() + PI / 2.0

func _find_own_slipper(local_character: CharacterBase) -> Node3D:
	if local_character == null or local_character.is_defender:
		return null
	if local_character.holding_slipper():
		return null
	var fallback: Slipper = null
	var fallback_d := INF
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null or slipper.state == Slipper.CarryState.CARRIED:
			continue
		if slipper.owner_slot == local_character.player_slot:
			return slipper
		var d := local_character.global_position.distance_to(slipper.global_position)
		if d < fallback_d:
			fallback_d = d
			fallback = slipper
	return fallback

func _find_can(_local_character: CharacterBase) -> CharacterBase:
	return null

func _find_character(node: Node, matches: Callable) -> CharacterBase:
	if node is CharacterBase and matches.call(node):
		return node
	for child in node.get_children():
		var found := _find_character(child, matches)
		if found:
			return found
	return null

