extends Control
class_name CharacterSelect

## The CHARACTER screen: pick who you play as, then go on to the lobby.
##
## WHERE IT SITS IN THE FLOW, AND WHY THERE.
##
##     MainMenu -> GameSetup -> **CharacterSelect** -> Lobby -> Main
##
## After GameSetup rather than before it, because the two screens ask different
## kinds of question and the order matters: GameSetup decides what the MATCH is
## (map, mode, and whether it is offline/host/join) and CharacterSelect decides
## who YOU are in it. Putting the personal choice last means it is the freshest
## thing in mind when the lobby's READY gate appears.
##
## Before the Lobby rather than inside it, because all three launch paths pass
## through here on the way (GameSetup's Play Offline, Host and Join all set
## `GameLaunch.pending_action` and then come here), so the pick is made ONCE, on
## a screen that owns it, instead of being a widget competing with the ready-up
## gate for attention. It also means the choice is already settled by the time
## the peer connects, which is what lets `main.gd` hand it to the spawn without
## a second round trip — see `NetworkManager.local_character_index`.
##
## ⚠️ IT DOES NOT TOUCH `pending_action`. GameSetup set it and the Lobby consumes
## it; this screen is a pure detour between them. Going BACK from here therefore
## returns to GameSetup, where it can be set again, rather than silently leaving
## a stale host/join intent behind.
##
## STYLING IS THE FRONT END'S OWN, NOT THE LIGHT UI THEME. Cream and amber on
## dark stained wood over a live 3D backdrop, matching GameSetup.tscn piece for
## piece — the same SETTINGS CONFIG PANEL, MAP MODE DISPLAY, arrow and BUTTON
## LONG artwork, so this reads as the next page of the same book rather than as a
## screen somebody bolted on. See `ui_theme.gd`'s WOOD_*/Menu* block for why that
## band exists separately from the light `CARD`/`INK` one.

const LOBBY_SCENE_PATH: String = "res://scenes/ui/Lobby.tscn"
const GAME_SETUP_PATH:  String = "res://scenes/ui/GameSetup.tscn"

## Stagger between consecutive buttons unfurling — same value and same feel as
## GameSetup's, so the two screens animate in identically.
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
## GameSetup::_apply_map().
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
	get_tree().change_scene_to_file(GAME_SETUP_PATH)

## Straight to the Lobby, with `pending_action` untouched — GameSetup already
## decided whether this is a local, host or join launch and lobby.gd reads it
## there. Nothing about the character choice needs saying to anyone yet: it is in
## `GameLaunch`, which survives the scene change, and NetworkManager publishes it
## to the host on connect.
func _on_confirm_pressed() -> void:
	AudioManager.play("ui_click") # 4.1
	get_tree().change_scene_to_file(LOBBY_SCENE_PATH)
