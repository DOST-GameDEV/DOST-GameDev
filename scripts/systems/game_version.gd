extends RefCounted
class_name GameVersion

## Single source of truth for the build version: `application/config/version`
## in `project.godot`. Deliberately NOT a second copy of the string in this
## file — the whole point is that there is one number to bump.
##
## Not an autoload: nothing here needs per-frame work or state, and a
## `class_name` with static members is reachable from anywhere the same way
## an autoload would be (`GameVersion.string()`), without the startup cost or
## an extra line in project.godot's [autoload] block.
##
## Bump the minor number in project.godot with every change that affects
## gameplay, UI, models, or scenes (docs-only commits don't need it). The
## label built by `attach_to()` puts it on screen so a new build can be
## confirmed visually instead of by diffing files.

const SETTING_PATH: String = "application/config/version"

static func string() -> String:
	return str(ProjectSettings.get_setting(SETTING_PATH, "0.0"))

## "v1.2" — what actually goes on screen.
static func display_string() -> String:
	return "v" + string()

## Builds the corner label and parents it to `parent`. Done in code rather than
## as a .tscn instanced into every screen so that adding the version readout to
## a new screen is one line and can never drift out of sync visually between
## screens. Bottom-right, deliberately quiet — it's a build stamp, not UI.
##
## `over_3d` picks the readable treatment for where it's going: a menu sits on
## the light PANEL background and wants muted INK, while the in-match HUD draws
## over a live 3D scene and needs the outlined caption instead. Both come from
## the design system's type variations (see scripts/ui/ui_theme.gd) rather than
## `theme_override_*`.
static func attach_to(parent: Control, over_3d: bool = false) -> Label:
	var label := Label.new()
	label.name = "VersionLabel"
	label.text = display_string()
	label.theme_type_variation = &"HudCaption" if over_3d else &"Caption"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.offset_left = -140.0
	label.offset_top = -30.0
	label.offset_right = -12.0
	label.offset_bottom = -8.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(label)
	return label
