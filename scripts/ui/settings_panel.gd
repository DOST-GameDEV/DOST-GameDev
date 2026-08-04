extends Control
class_name SettingsPanel

## Rebindable-controls UI, backed by the SettingsManager autoload (see
## scripts/systems/settings_manager.gd for persistence/apply logic — this
## script is purely the view). Kept as its own scene (instanced into
## MainMenu.tscn, see main_menu.gd) rather than nodes inlined directly into
## MainMenu.tscn: unique names (%NodeName) must be unique scene-wide, and
## MainMenu's PlayMenu already owns a "StatusLabel" — inlining a second one
## here would collide. As a separate instanced scene, this panel's unique
## names resolve within its own instance instead, so there's no collision no
## matter what MainMenu already contains.

signal back_pressed

## Width of a rebind row's action name, so every key button lines up in one
## column regardless of how long "Special Ability" is.
const ACTION_LABEL_WIDTH: float = 260.0
## ⚠️ THE SIZE OF EVERY CONTROL IN `BindingsList`, SHARED BY THE KEYCAPS AND THE NAME
## FIELD. 🧑 2026-08-02: *"make the box for name in settings same size as others"*.
##
## The name row is authored in the scene and the keybind rows are built here, so the two
## had drifted: a 220-wide label against 260, and a 220x0 LineEdit against a 170x46
## Button. Same list, two different grids, and the field sat visibly out of line with
## everything under it.
##
## Read from here in BOTH places rather than typed into the .tscn a second time — a
## number that appears twice is a number that will disagree with itself the next time
## one of them is tuned.
const BINDING_CONTROL_SIZE: Vector2 = Vector2(170, 46)

@onready var bindings_list: VBoxContainer = %BindingsList
@onready var status_label: Label = %SettingsStatusLabel
@onready var reset_all_button: Button = %ResetAllButton
@onready var back_button: Button = %BackButton
@onready var apply_button: Button = %ApplyButton
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_value_label: Label = %SensitivityValueLabel
@onready var invert_y_check: CheckBox = %InvertYCheck
## The other half of the `toggle_fullscreen` key — same setting, two routes in.
@onready var fullscreen_check: CheckBox = %FullscreenCheck
## 4.1 — one row per audio bus (see default_bus_layout.tres).
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var master_volume_value_label: Label = %MasterVolumeValueLabel
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var sfx_volume_value_label: Label = %SfxVolumeValueLabel
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var music_volume_value_label: Label = %MusicVolumeValueLabel

## action name -> the Button showing/capturing its key, so a rebind can
## refresh just that one row's label without rebuilding the whole list.
var _action_buttons: Dictionary = {}
## Action currently waiting for a keypress to rebind to, or "" if none.
var _listening_action: String = ""

func _ready() -> void:
	_build_rows()
	reset_all_button.pressed.connect(_on_reset_all_pressed)
	back_button.pressed.connect(_on_back_pressed)
	apply_button.pressed.connect(_on_apply_pressed)
	# ⚠️ THE TRANSACTION OPENS WITH THE PANEL AND IT MUST. Every `SettingsManager` setter
	# writes `settings.cfg` on its own; `begin_edit()` is the only thing that stops that,
	# so opening it late by even one signal means whatever the player touched first was
	# already on disk and is no longer revertible. See § STAGED EDITS in that file.
	SettingsManager.begin_edit()
	SettingsManager.binding_changed.connect(_on_binding_changed)
	# Item 14.
	sensitivity_slider.value = SettingsManager.mouse_sensitivity
	sensitivity_value_label.text = "%.1fx" % SettingsManager.mouse_sensitivity
	invert_y_check.button_pressed = SettingsManager.invert_y
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	# ⚠️ NO LONGER CONNECTED STRAIGHT TO THE SETTER. It has to go through a handler now
	# so APPLY can be re-evaluated after it; a direct connection is the one change point
	# on this screen that would silently leave the button disabled with a real edit
	# pending, because nothing else would notice the toggle happened.
	invert_y_check.toggled.connect(_on_invert_y_toggled)
	# ⚠️ SEEDED BEFORE CONNECTING, like the sliders: assigning `button_pressed` emits
	# `toggled`, and connecting first would flip the window mode on every open of this
	# panel. Harmless-looking, and a mode change is the most visible no-op in the game.
	fullscreen_check.button_pressed = SettingsManager.fullscreen
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	SettingsManager.fullscreen_changed.connect(_on_settings_fullscreen_changed)
	_init_volume_rows()
	_build_name_row()
	_bind_graphics_rows()

## ---------------------------------------------------------------------------
## THE GRAPHICS TICKS. 🧑 2026-08-04: *"add motion blur tick in settings as well as
## other probably good graphics settings that ppl can turn on in settings"*.
##
## ⚠️ ONE LOOP OVER `SettingsManager.GRAPHICS_KEYS`, NOT SEVEN HANDLERS. The keys,
## the labels, the defaults, the save, the load, the snapshot and the revert are all
## driven off that one list — a checkbox wired by hand here is the eighth place an
## option can be forgotten, and the first seven are already written not to allow it.
##
## ⚠️ SEEDED BEFORE CONNECTING, exactly like `fullscreen_check` above: assigning
## `button_pressed` emits `toggled`, so connecting first would re-apply every effect
## (and dirty the APPLY button) on every open of this panel.
var _graphics_checks: Dictionary = {}

const GRAPHICS_CHECK_NODES: Dictionary = {
	"motion_blur": "%MotionBlurCheck",
	"ssr": "%SsrCheck",
	"taa": "%TaaCheck",
	"sdfgi": "%SdfgiCheck",
	"ssil": "%SsilCheck",
	"ssao": "%SsaoCheck",
	"glow": "%GlowCheck",
}

func _bind_graphics_rows() -> void:
	for key in SettingsManagerScript.GRAPHICS_KEYS:
		var path: String = GRAPHICS_CHECK_NODES.get(key, "")
		var box := get_node_or_null(path) as CheckBox
		if box == null:
			push_error("SettingsPanel: %s missing from SettingsPanel.tscn" % path)
			continue
		box.button_pressed = SettingsManager.graphics_option(key)
		box.toggled.connect(_on_graphics_toggled.bind(key))
		_graphics_checks[key] = box

func _on_graphics_toggled(pressed: bool, key: String) -> void:
	SettingsManager.set_graphics_option(key, pressed)
	_refresh_apply_state()

## ---------------------------------------------------------------------------
## THE PLAYER NAME ROW. 🧑 2026-07-31: *"add the option to change name in settings
## so that P1 is an actual username"*.
##
## ⚠️ BUILT IN CODE, AT THE TOP OF THE BINDINGS LIST. `SettingsPanel.tscn` is the UI
## lane's file and this is a mechanics-and-UX commit; adding the row here keeps the
## scene theirs to restructure while the control still exists and still works. It is
## first in the list on purpose — it is the only row that is about WHO you are rather
## than about how the game reads your hardware.
##
## ⚠️ COMMITTED ON `text_submitted` AND ON FOCUS LOSS, NOT ON EVERY KEYSTROKE.
## `SettingsManager.set_player_name()` writes `settings.cfg`, and saving a config
## file once per typed character is a real cost for a control the player is holding
## down backspace in.
## ---------------------------------------------------------------------------
## ⚠️ IT BINDS NOW, IT NO LONGER BUILDS — § CHECKLIST 1.9. The row is authored in
## `SettingsPanel.tscn`; this wires it. A control created at runtime sits outside the
## focus order the scene defines, which is the half of the REACHABILITY RULE that is
## easy to miss: it was operable with a mouse and unreachable by keyboard.
##
## ⚠️ THE FIELD IS STILL POPULATED FROM `SettingsManager` HERE rather than in the
## scene, because the saved name is not known until run time — the scene can only
## state the placeholder.
func _build_name_row() -> void:
	var field := get_node_or_null("%PlayerNameField") as LineEdit
	if field == null:
		push_error("SettingsPanel: PlayerNameField missing from SettingsPanel.tscn")
		return
	field.text = SettingsManager.player_name
	field.max_length = SettingsManagerScript.PLAYER_NAME_MAX
	# ⚠️ SIZED FROM THE SAME CONSTANTS THE KEYCAP ROWS USE, so this row lines up with the
	# ones built under it instead of describing its own grid. See BINDING_CONTROL_SIZE.
	field.custom_minimum_size = BINDING_CONTROL_SIZE
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := get_node_or_null("%PlayerNameRow") as HBoxContainer
	var name_label := name_row.get_node_or_null("PlayerNameLabel") as Label if name_row != null else null
	if name_label != null:
		name_label.custom_minimum_size = Vector2(ACTION_LABEL_WIDTH, 0)
	if name_row != null:
		# The built rows carry no separation override, so the authored 12 here put this
		# row's control a few pixels off every other one's left edge.
		name_row.remove_theme_constant_override("separation")
	if not field.text_submitted.is_connected(_on_player_name_submitted):
		field.text_submitted.connect(_on_player_name_submitted)
		field.focus_exited.connect(func() -> void: _on_player_name_submitted(field.text))
		# ⚠️⚠️ `text_changed` TOO, AND WITHOUT IT APPLY COULD NOT BE REACHED AT ALL.
		# 🧑 2026-08-02: *"changing name doesnt trigger APPLY CHANGES in settings"*.
		#
		# The other two signals both need the player to LEAVE the field — Enter, or
		# focus moving elsewhere — and the obvious way to leave it is to click APPLY.
		# But APPLY is `disabled` until `has_unsaved_changes()` is true, a disabled
		# Button takes no focus and emits nothing, so the click did nothing, the focus
		# never left, the name was never staged, and the button stayed grey. A dead
		# control whose only route to being live was through itself.
		#
		# Typing is the change, so typing is what reports it. Safe per keystroke:
		# `SettingsManager._save()` returns early inside an edit transaction, so this
		# stages in memory and touches no disk until APPLY commits.
		field.text_changed.connect(_on_player_name_typed)

## Keystroke-by-keystroke staging, so APPLY lights up while the caret is still in the
## field. Deliberately NOT `_on_player_name_submitted`: that one plays a click and
## pushes the name onto the live character, and doing either per letter would be a
## click track and a replicated write per keypress.
func _on_player_name_typed(value: String) -> void:
	SettingsManager.set_player_name(value)
	_refresh_apply_state()

func _on_player_name_submitted(value: String) -> void:
	SettingsManager.set_player_name(value)
	AudioManager.play("ui_click")
	_refresh_apply_state()
	# ⚠️ APPLIED TO THE LIVE CHARACTER TOO, NOT JUST SAVED. This panel is reachable
	# from the in-match pause menu, and a rename that only took effect on the next
	# launch would read as the control not working. `player_name` is a replicated
	# property, so writing it on the seat this peer has authority over is what carries
	# it to the other three scoreboards.
	_push_name_to_live_character()

## Writes the saved name onto the seat this peer drives. `player_name` is replicated, so
## this is what carries a rename to the other three scoreboards mid-match.
func _push_name_to_live_character() -> void:
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who != null and who.is_multiplayer_authority() and not who.is_ai_driven():
			who.player_name = SettingsManager.player_name

func _on_sensitivity_changed(value: float) -> void:
	SettingsManager.set_mouse_sensitivity(value)
	sensitivity_value_label.text = "%.1fx" % value
	_refresh_apply_state()

func _on_invert_y_toggled(value: bool) -> void:
	SettingsManager.set_invert_y(value)
	_refresh_apply_state()

func _on_fullscreen_toggled(value: bool) -> void:
	SettingsManager.set_fullscreen(value)
	_refresh_apply_state()

## The `toggle_fullscreen` key works while this panel is open — SettingsManager handles
## it in `_input`, above every Control — so the box has to follow the window rather than
## claim the opposite of what the player is looking at. `set_pressed_no_signal` because
## the change has already been applied; re-entering the handler would only re-save it.
func _on_settings_fullscreen_changed(value: bool) -> void:
	fullscreen_check.set_pressed_no_signal(value)
	_refresh_apply_state()

## 4.1 — Master / SFX / Ambience.
##
## ⚠️ SET `value` BEFORE CONNECTING `value_changed`, NOT AFTER.
##
## Assigning to an HSlider's `value` emits value_changed synchronously. With the
## connection made first, seeding the three sliders from SettingsManager would
## immediately call straight back into SettingsManager.set_*_volume() and
## _save() — three ConfigFile writes on every single open of this panel, before
## the player has touched anything. The rebind rows above have never had this
## problem because they are Buttons; the sensitivity slider (item 14) already
## established this ordering and it is repeated here for the same reason.
func _init_volume_rows() -> void:
	var rows := [
		[master_volume_slider, master_volume_value_label, SettingsManager.master_volume,
			SettingsManager.set_master_volume],
		[sfx_volume_slider, sfx_volume_value_label, SettingsManager.sfx_volume,
			SettingsManager.set_sfx_volume],
		[music_volume_slider, music_volume_value_label, SettingsManager.music_volume,
			SettingsManager.set_music_volume],
	]
	for row in rows:
		var slider: HSlider = row[0]
		var label: Label = row[1]
		var setter: Callable = row[3]
		slider.value = row[2]
		label.text = _volume_text(row[2])
		slider.value_changed.connect(_on_volume_changed.bind(label, setter))

## Applies the new level to the bus (via SettingsManager -> AudioManager) and
## previews it, so dragging a slider is audible rather than a silent guess. The
## preview is the ordinary UI click, which is on the SFX bus — so it demonstrates
## Master and SFX honestly and is deliberately absent for Ambience, whose own bus
## it would not be routed through. AudioManager's retrigger guard is what keeps
## a fast drag from firing one click per pixel.
func _on_volume_changed(value: float, label: Label, setter: Callable) -> void:
	setter.call(value)
	label.text = _volume_text(value)
	if setter != Callable(SettingsManager, "set_music_volume"):
		AudioManager.play("ui_click")
	_refresh_apply_state()

func _volume_text(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)

## ⚠️ MUST SKIP `PlayerNameRow`. It is authored as `BindingsList`'s first child
## (§ CHECKLIST 1.9's own note in `SettingsPanel.tscn`), and this used to
## `queue_free()` every child indiscriminately before rebuilding the rebind
## rows — which frees it in the same frame `_build_name_row()` (called later in
## `_ready()`) still finds it under its unique name and wires it up. The field
## worked for exactly one frame and then vanished with everything else this
## loop cleared, which is why it read as "disappeared" rather than as "never
## built" — 🧑: *"the username change option disappeared from settings"*.
## `add_child()` below still appends the rebind rows AFTER it, so skipping it
## here is enough; nothing about the ordering needs restating.
func _build_rows() -> void:
	for child in bindings_list.get_children():
		if child.name == "PlayerNameRow":
			continue
		child.queue_free()
	_action_buttons.clear()
	for action in SettingsManager.REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = SettingsManager.ACTION_LABELS.get(action, action)
		label.custom_minimum_size = Vector2(ACTION_LABEL_WIDTH, 0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# `MenuBody`, not a colour override: this panel draws on dark wood, where
		# the theme's INK body colour is invisible, and the variation is how the
		# rest of the front end says that. The override this replaces predates
		# the Menu* set and was the only thing keeping these rows legible — every
		# label the SCENE owned was still INK on navy, which is what made the
		# in-game panel unreadable.
		label.theme_type_variation = &"MenuBody"
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = BINDING_CONTROL_SIZE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Deliberately the theme's DEFAULT Button — light fill, INK lettering.
		# It is the one control on this screen that should read as a physical
		# keycap, and inverting it to wood would lose that.
		button.text = SettingsManager.get_binding_display_name(action)
		button.pressed.connect(_on_rebind_button_pressed.bind(action))
		row.add_child(button)
		_action_buttons[action] = button
		bindings_list.add_child(row)

func _on_rebind_button_pressed(action: String) -> void:
	AudioManager.play("ui_click")
	_listening_action = action
	status_label.text = "Press any key for \"%s\"… (Esc to cancel)" % SettingsManager.ACTION_LABELS.get(action, action)
	_action_buttons[action].text = "…"

func _unhandled_input(event: InputEvent) -> void:
	# ⚠️ VISIBILITY GUARD — DO NOT REMOVE. A hidden Control still receives
	# _unhandled_input in Godot; only _gui_input is gated by visibility.
	#
	# Without this line the HIDDEN settings panel swallowed every Esc press in
	# the match, called set_input_as_handled(), and emitted back_pressed —
	# which main.gd:231 has wired to `settings_panel.hide(); pause_root.show()`.
	# That shows the pause overlay but never sets Input.mouse_mode and never
	# sets get_tree().paused, because _on_pause_toggle_requested() was never
	# reached at all.
	#
	# Found by the first real playtest (0.4), reported as three separate bugs
	# that were all this one: "mouse disappears when I pause", "it doesn't
	# really pause, the game keeps playing", and "I can't return to menu because
	# no mouse — I have to alt-tab to get it back". match_result.gd:29 already
	# had this guard, which is what made the omission obvious once both were
	# read side by side.
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key_event := event as InputEventKey
	if _listening_action == "":
		# U-7: Esc exits the panel (back to pause menu or main menu, whoever
		# wired back_pressed). Handled even when not rebinding so every panel
		# in the game has a working Esc path (Dev_Plan.md §4.7 / Handoff.md U-7).
		if key_event.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_back_pressed()
		return
	if key_event.physical_keycode == KEY_ESCAPE:
		_action_buttons[_listening_action].text = SettingsManager.get_binding_display_name(_listening_action)
		status_label.text = "Rebind cancelled."
		_listening_action = ""
		AudioManager.play("ui_back")
	else:
		# B-22: rebind_action() now refuses (and reports) a key already used
		# by another action instead of silently double-binding it.
		var conflict_with := SettingsManager.rebind_action(_listening_action, key_event.physical_keycode)
		if conflict_with != "":
			_action_buttons[_listening_action].text = SettingsManager.get_binding_display_name(_listening_action)
			status_label.text = "That key is already \"%s\". Choose a different key." % conflict_with
			# 4.1: the conflict buzz. B-22 gave this case a clear message and
			# nothing else — a player looking at the keyboard rather than at the
			# status label got no signal at all that the press was refused.
			AudioManager.play("ui_error")
		else:
			status_label.text = "\"%s\" rebound." % SettingsManager.ACTION_LABELS.get(_listening_action, _listening_action)
			_listening_action = ""
			AudioManager.play("ui_click")
	get_viewport().set_input_as_handled()

## Refreshes whichever row's button just changed — covers both rebinds made
## through this panel and ones applied elsewhere (e.g. reset_all_to_default()).
func _on_binding_changed(action: String) -> void:
	if _action_buttons.has(action):
		_action_buttons[action].text = SettingsManager.get_binding_display_name(action)
	_refresh_apply_state()

func _on_reset_all_pressed() -> void:
	AudioManager.play("ui_click")
	SettingsManager.reset_all_to_default()
	# ⚠️ RESET IS NOW A STAGED EDIT LIKE ANY OTHER, and the wording has to say so or the
	# button lies. It used to write to disk immediately; inside the transaction it does
	# not, so "All controls reset to default." would promise something that has not
	# happened until APPLY is pressed.
	status_label.text = "All controls reset — press APPLY CHANGES to keep it."
	_refresh_apply_state()

## ---------------------------------------------------------------------------
## § THE APPLY / DISCARD PAIR. 🧑 2026-08-02: *"add apply box in settings ... reset all
## back apply changes"*.
##
## ⚠️ BACK DISCARDS, AND IT ASKS FIRST ONLY WHEN THERE IS SOMETHING TO LOSE. An APPLY
## button that does not have a matching discard is a save button wearing the wrong word:
## the reason to want one is to be able to change your mind, and the only control that
## can mean "no" here is BACK. `has_unsaved_changes()` gates the prompt so that leaving a
## panel you only looked at costs nothing.
##
## ⚠️ THE CONFIRM IS A SECOND PRESS OF BACK, NOT A DIALOG. This panel is instanced into
## MainMenu and has no popup layer of its own; a ConfirmationDialog here would be the
## only modal in the menu and would need its own focus handling on a screen whose
## REACHABILITY RULE is already fiddly. Arming the button instead — the label changes to
## say what the next press does — costs one bool and no new nodes.
##
## ⚠️ THE GREEN MOVED FROM BACK TO APPLY, AND THAT IS THE THEME'S OWN RULE RATHER THAN
## A PREFERENCE. 🧑 asked for colour on the apply box; `ui_theme.gd` reserves
## `WoodPrimaryButton` for *"the one action a screen wants you to take"*, and once this
## screen has an APPLY that is no longer BACK — leaving is the neutral option and
## committing is the one the screen is for. So APPLY takes PLAY's green and BACK drops to
## plain `WoodButton`. RESET ALL keeps QUIT's red. Painting APPLY green while BACK stayed
## green would have put two primaries in one row, which is the same as having none.
## ---------------------------------------------------------------------------

## True once BACK has been pressed with unsaved changes pending. Cleared by anything
## that resolves the question, so an armed BACK cannot survive an APPLY.
var _back_armed: bool = false

func _on_apply_pressed() -> void:
	AudioManager.play("ui_click")
	# ⚠️ THE LIVE CHARACTER IS UPDATED HERE TOO, not only on Enter/blur. Now that typing
	# alone can arm APPLY, a player can rename and commit without the field ever losing
	# focus — so without this the scoreboard in a running match would keep the old name
	# until the next launch, which is the same "the control does not work" the submit
	# handler already documents.
	_push_name_to_live_character()
	SettingsManager.commit_edit()
	# Straight back into a new transaction: the panel is still open, so the next change
	# the player makes has to be revertible too.
	SettingsManager.begin_edit()
	_back_armed = false
	status_label.text = "Settings saved."
	_refresh_apply_state()

func _on_back_pressed() -> void:
	if SettingsManager.has_unsaved_changes() and not _back_armed:
		_back_armed = true
		AudioManager.play("ui_error")
		back_button.text = "◀  DISCARD & GO BACK"
		status_label.text = "You have unsaved changes. Press BACK again to discard them."
		_refresh_apply_state()
		return
	AudioManager.play("ui_back")
	# ⚠️ REVERT, NOT JUST CLOSE. Nothing has been written since `begin_edit()`, so the
	# FILE is already right — but the running process is not: a rebind is live in the
	# InputMap and a volume is live on the bus. Leaving without this would give a player
	# who pressed BACK the settings they rejected, until the next restart put the saved
	# ones back and made it look like the panel had forgotten them.
	SettingsManager.revert_edit()
	_back_armed = false
	back_button.text = "◀  BACK"
	status_label.text = ""
	back_pressed.emit()

## APPLY is live only when there is something to apply, and BACK goes back to saying
## BACK the moment the player un-does whatever armed it.
func _refresh_apply_state() -> void:
	if apply_button == null or not is_instance_valid(apply_button):
		return
	var dirty := SettingsManager.has_unsaved_changes()
	apply_button.disabled = not dirty
	if not dirty and _back_armed:
		_back_armed = false
		back_button.text = "◀  BACK"
