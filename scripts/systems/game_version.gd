extends RefCounted
class_name GameVersion


const SETTING_PATH: String = "application/config/version"

static func string() -> String:
	return str(ProjectSettings.get_setting(SETTING_PATH, "0.0"))

static func display_string() -> String:
	return "v" + string()

static func attach_to(parent: Control, over_3d: bool = false) -> Label:
	var label := Label.new()
	label.name = "VersionLabel"
	label.text = display_string()
	label.theme_type_variation = &"HudCaption" if over_3d else &"Caption"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.offset_left = -156.0
	label.offset_top = -42.0
	label.offset_right = -24.0
	label.offset_bottom = -20.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(label)
	return label

