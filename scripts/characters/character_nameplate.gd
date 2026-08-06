extends Node3D
class_name CharacterNameplate


const FADE_START: float = 12.0
const FADE_END: float = 18.0

const RING_RADIUS_RATIO: float = 1.375
const RING_FLOOR_MARGIN: float = 0.02
const LABEL_MARGIN_AT_PERSON_SCALE: float = 0.25
const PERSON_CAPSULE_HEIGHT: float = 1.6

@onready var _ring: MeshInstance3D = $NameplateRing
@onready var _ring_mesh: CylinderMesh = _ring.mesh as CylinderMesh
@onready var _label: Label3D = $NameplateLabel

var _character: CharacterBase = null
var _ring_material: StandardMaterial3D = null
var _role_color: Color = UiTheme.DEFENSE

func _ready() -> void:
	_character = get_parent() as CharacterBase
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = _ring_material
	MatchManager.round_started.connect(_on_round_started)
	refresh()

func apply_sizing() -> void:
	if _character == null:
		return
	var height := _character.capsule_height()
	var radius := _character.capsule_radius()
	_ring.position.y = -height / 2.0 + RING_FLOOR_MARGIN
	if _ring_mesh != null:
		var ring_radius := radius * RING_RADIUS_RATIO
		_ring_mesh.top_radius = ring_radius
		_ring_mesh.bottom_radius = ring_radius
	var label_margin := LABEL_MARGIN_AT_PERSON_SCALE * (height / PERSON_CAPSULE_HEIGHT)
	_label.position.y = height / 2.0 + label_margin

func _on_round_started(_round_number: int, _defender_slot: int) -> void:
	apply_sizing()
	refresh()

func refresh() -> void:
	if _character == null or not is_instance_valid(_character):
		return
	var is_defense: bool = _character.is_defender
	_role_color = UiTheme.DEFENSE if is_defense else UiTheme.OFFENSE
	_ring_material.albedo_color = Color(_role_color.r, _role_color.g, _role_color.b, 0.8)

	var role_glyph := "TAYA" if is_defense else "ATK"
	_label.text = "%s · %s" % [_character.display_name(), role_glyph]
	_label.modulate = _role_color

func _process(_delta: float) -> void:
	var carried := false
	_ring.visible = not carried
	_label.visible = not carried
	if carried:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var distance := camera.global_position.distance_to(_label.global_position)
	var alpha := clampf(inverse_lerp(FADE_END, FADE_START, distance), 0.0, 1.0)
	_label.modulate = Color(_role_color.r, _role_color.g, _role_color.b, alpha)

