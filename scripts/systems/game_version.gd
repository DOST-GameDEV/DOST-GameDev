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
	# 2026-07-29, user feedback: on a PC build the label sat close enough to
	# the true corner (12px/8px) to get clipped by the window border/taskbar
	# depending on resolution and windowed vs. fullscreen. Pulled further in
	# rather than assuming a specific resolution to fix around.
	label.offset_left = -156.0
	label.offset_top = -42.0
	label.offset_right = -24.0
	label.offset_bottom = -20.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(label)
	# ⚠️ MENUS ONLY — `over_3d` IS TRUE EXACTLY FOR THE IN-MATCH HUD, and an
	# "UPDATE" button appearing over live play would be both a distraction and a
	# trap: pressing it opens a browser over a running match, and in multiplayer
	# that leaves three other people waiting. The version STAMP still shows there,
	# which is what the HUD's copy of it is for.
	if not over_3d:
		_attach_update_prompt(parent, label)
	return label


## ---------------------------------------------------------------------------
## ⚠️ THE UPDATE PROMPT RIDES THE VERSION LABEL, AND THAT IS THE WHOLE REASON IT
## IS HERE RATHER THAN ON MainMenu.
##
## 🧑 2026-08-07: *"add a version checker so it prompts to install updates when
## pushed"*. THE REACHABILITY RULE says a feature the player cannot reach does
## not exist — and the natural place for "you are running an old build" is beside
## the number that says which build you are running. `attach_to()` is already
## called by every screen in the game (main menu, mode select, lobby, character
## select, settings, the HUD), so hanging it here puts the prompt on ALL of them
## for one line, and a screen added later gets it for free instead of being
## forgotten.
##
## ⚠️ A BUTTON, NOT A LABEL, and it sits ABOVE the version text rather than
## replacing it: the player still needs to be able to read which version they
## actually have when reporting a bug, and a prompt that swallowed that would
## trade one readout for another.
##
## ⚠️ IT SUBSCRIBES AS WELL AS CHECKING. The HTTP round trip usually finishes
## after the first screen is already up, so a prompt built only from the current
## value of `UpdateCheck.available` would miss its own answer on the very screen
## the player is looking at. Checking AND subscribing covers both orders, and
## `update_found` fires once.
const UPDATE_BUTTON_HEIGHT: float = 34.0

static func _attach_update_prompt(parent: Control, label: Label) -> void:
	# Guarded so this file still works in a probe or a scene loaded without the
	# autoload present — `GameVersion` is a plain class and callers do not expect
	# it to require a singleton.
	if not Engine.has_singleton("UpdateCheck") and parent.get_node_or_null("/root/UpdateCheck") == null:
		return
	var checker: Node = parent.get_node_or_null("/root/UpdateCheck")
	if checker == null:
		return

	var button := Button.new()
	button.name = "UpdatePrompt"
	button.theme_type_variation = &"WoodButton"
	button.focus_mode = Control.FOCUS_ALL
	button.visible = false
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Directly above the version label, sharing its right margin so the two read
	# as one stacked block rather than as two unrelated corner controls.
	button.offset_left = label.offset_left - 96.0
	button.offset_right = label.offset_right
	button.offset_top = label.offset_top - UPDATE_BUTTON_HEIGHT - 4.0
	button.offset_bottom = label.offset_top - 4.0
	button.add_theme_font_size_override("font_size", 16)
	parent.add_child(button)

	var show := func(version: String, _notes: String) -> void:
		if not is_instance_valid(button):
			return
		button.text = "UPDATE  →  v%s" % version
		button.tooltip_text = ("You are running v%s. v%s has been published.\n"
			% [GameVersion.string(), version]) + "Click to open the download."
		button.visible = true
	if bool(checker.get("available")):
		show.call(String(checker.get("latest_version")), String(checker.get("notes")))
	checker.connect("update_found", show)
	button.pressed.connect(func() -> void:
		AudioManager.play("ui_click")
		checker.call("open_download"))
	button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))
