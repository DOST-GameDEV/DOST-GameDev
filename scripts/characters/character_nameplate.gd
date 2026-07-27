extends Node3D
class_name CharacterNameplate

@onready var _ring: MeshInstance3D = $NameplateRing
@onready var _label: Label3D = $NameplateLabel

func _ready() -> void:
	var parent := get_parent()
	var is_person: bool = parent.is_person if "is_person" in parent else false
	var team: int = parent.team if "team" in parent else 0

	var role_color: Color = UiTheme.OFFENSE if is_person else UiTheme.DEFENSE
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(role_color.r, role_color.g, role_color.b, 0.8)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = ring_mat

	var team_letter := "A" if team == 0 else "B"
	var role_str := "PERSON" if is_person else "PROP"
	_label.text = "%s · %s" % [team_letter, role_str]
