extends Control
class_name CharacterSelect


## The CHARACTER panel: pick who you play as, and what your Prop looks like.
##
## Three tabs — TAO (the Person you play), LATA and TSINELAS (the two things your
## Prop will be, one round each). All three are picked because a player controls
## a Person AND a Prop, and the Prop is a lata one round and a tsinelas the next.
##
## ⚠️ A LATA OR TSINELAS PICK IS NOT ONLY A LOOK — since 10.5 each entry also
## carries the ability that skin brings (`character_roster.gd`'s `ability`
## field), which is how checklist 3.3's kit selection is delivered without a
## fourth and fifth picker. `main.gd::_prop_ability_for()` asks the list matching
## the side being played this round. The TAO tab stays appearance-only: whether a
## Person gets its own ability roster is checklist 1.3, still 🧑 HUMAN-owned and
## unanswered, so every Person shares one Tag/Throw.
##
## STYLING IS THE FRONT END'S OWN, NOT THE LIGHT UI THEME. Cream and amber on
## dark stained wood over a live 3D backdrop, matching the setup screen it opens
## over piece for piece — the same SETTINGS CONFIG PANEL, MAP MODE DISPLAY, arrow
## and BUTTON LONG artwork, so this reads as the next page of the same book
## rather than as a screen somebody bolted on. See `ui_theme.gd`'s WOOD_*/Menu* block for why that
## band exists separately from the light `CARD`/`INK` one.

## ⚠️ THIS IS A PANEL SHOWN IN PLACE, NOT A SCENE IN A CHAIN — changed in 10.5.
## It used to be its own step (`GameSetup -> CharacterSelect -> Lobby`) and it
## used `change_scene_to_file` to move on. It is now instanced hidden inside
## `MatchSetup.tscn` and toggled, the same way `MainMenu.tscn` shows Settings and
## Tutorial: a scene change would tear down and rebuild the setup screen — its
## live 3D map backdrop, and on a client its ENet connection and the whole lobby
## board — behind a panel the player is about to close.
##
## Nothing else about this screen changed. Both exits emit `closed` and the
## screen that owns it decides what that means.
signal closed


## Stagger between consecutive buttons unfurling — same value and same feel as
## the setup screen's, so the two animate in identically.
const STAGGER: float = 0.09

@onready var preview: CharacterPreview = %CharacterPreview
@onready var prev_button: TextureButton = %CharPrevButton
@onready var next_button: TextureButton = %CharNextButton
@onready var name_label: Label = %CharValueLabel
@onready var tagline_label: Label = %TaglineLabel
@onready var confirm_button: ArrowButton = %ConfirmButton
@onready var back_button: Button = %BackButton
@onready var tab_bar: HBoxContainer = %TabBar

## Which tab is showing, and the selected index WITHIN each tab. Three separate
## indices rather than one: switching tabs must return you to the lata you had
## picked, not reset it to the first one.
var _tab: int = 0
var _indices: Array[int] = [0, 0, 0]
var _tab_buttons: Array[Button] = []

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameVersion.attach_to(self)

	# Start on whatever is already chosen rather than resetting to the first
	# entry — all three are preferences that survive returning to the menu,
	# exactly like `selected_map`.
	_indices = [GameLaunch.character_index(), GameLaunch.can_index(),
		GameLaunch.slipper_index()]

	_build_tabs()
	_apply()

	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)
	# 4.1: the five handlers below already play their own `ui_click`/`ui_back`,
	# but hover was never wired on this screen — ArrowButton carries hover
	# internally (see arrow_button.gd) and none of these are ArrowButtons. Added
	# in 10.5 so every control in the front end sounds the same; a scripted audit
	# of all 25 controls across the setup screens is what found the gap.
	for button in [prev_button, next_button, confirm_button, back_button]:
		button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))

	confirm_button.animate_in(STAGGER)

## One button per category, built from `CharacterRoster.CATEGORIES` rather than
## authored in the scene — adding a fourth tab is then one entry in the roster
## and nothing here or in the .tscn changes, which is the same rule the map
## picker follows against `GameLaunch.MAPS`.
func _build_tabs() -> void:
	for i in range(CharacterRoster.CATEGORIES.size()):
		var button := Button.new()
		button.text = String(CharacterRoster.category(i)["label"])
		button.theme_type_variation = &"WoodButton"
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_tab_pressed.bind(i))
		button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover")) # 4.1
		tab_bar.add_child(button)
		_tab_buttons.append(button)
	_refresh_tab_buttons()

## The showing tab is DISABLED rather than merely restyled. `ui_theme.gd`'s wood
## set already draws disabled as the sunk face with the pressed fill, so this
## gets the "pushed in" read for free and, more usefully, makes the current tab
## unclickable — pressing the tab you are already on should do nothing, and this
## is that rule expressed once instead of guarded at the handler.
func _refresh_tab_buttons() -> void:
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].disabled = (i == _tab)

func _on_tab_pressed(index: int) -> void:
	if index == _tab:
		return
	AudioManager.play("ui_click") # 4.1
	_tab = index
	_refresh_tab_buttons()
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
		return
	# The arrows are a real way to browse this screen, not just a mouse target:
	# it is a picker, and a picker you cannot key through feels broken. Guarded
	# on a roster of more than one for the same reason the buttons are.
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_on_prev_pressed()
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_on_next_pressed()
	# Up/down move between TABS, left/right within one. Keeping the two axes
	# separate means a keyboard player can reach all three lists without ever
	# touching the mouse, which is the whole reason the arrows are wired.
	elif event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_on_tab_pressed(posmod(_tab - 1, CharacterRoster.CATEGORIES.size()))
	elif event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_on_tab_pressed(posmod(_tab + 1, CharacterRoster.CATEGORIES.size()))

func _entries() -> Array:
	return CharacterRoster.entries_for(_tab)

func _on_prev_pressed() -> void:
	var count := _entries().size()
	if count <= 1:
		return
	AudioManager.play("ui_click") # 4.1
	_indices[_tab] = posmod(_indices[_tab] - 1, count)
	_apply()

func _on_next_pressed() -> void:
	var count := _entries().size()
	if count <= 1:
		return
	AudioManager.play("ui_click") # 4.1
	_indices[_tab] = posmod(_indices[_tab] + 1, count)
	_apply()

## The one place a selection is applied, so the name in the slot, the tagline,
## the thing behind the UI and what actually spawns cannot disagree — the
## backdrop IS the selection, not a picture of it. Same contract as
## match_setup.gd::_apply_map().
##
## Writes straight into the matching `GameLaunch` preference on every change
## rather than only on confirm: the three are preferences, and CONFIRM is a
## navigation button, not a commit. Leaving without confirming keeps your picks,
## which is what the map picker already does and what a player expects.
func _apply() -> void:
	var entries := _entries()
	if entries.is_empty():
		return
	var index: int = posmod(_indices[_tab], entries.size())
	_indices[_tab] = index
	var entry: Dictionary = entries[index]

	name_label.text = String(entry["name"])
	tagline_label.text = String(entry["tagline"])

	# A one-entry category would leave these cycling a list of one.
	var many := entries.size() > 1
	prev_button.disabled = not many
	next_button.disabled = not many

	match String(CharacterRoster.category(_tab)["slot"]):
		"character":
			GameLaunch.selected_character = entry["id"]
			preview.show_character(entry)
		"can":
			GameLaunch.selected_can = entry["id"]
			preview.show_prop(entry, true)
		"slipper":
			GameLaunch.selected_slipper = entry["id"]
			preview.show_prop(entry, false)

func _on_back_pressed() -> void:
	AudioManager.play("ui_back") # 4.1
	closed.emit()

## Closes the panel with `pending_action` untouched. Nothing about the choice
## needs saying to anyone yet: it is in `GameLaunch`, which survives the scene
## change, and NetworkManager publishes it to the host on connect.
func _on_confirm_pressed() -> void:
	AudioManager.play("ui_click") # 4.1
	closed.emit()
