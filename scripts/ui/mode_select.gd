extends Control
class_name ModeSelectScreen

## The PLAY fork: Single Player or Multiplayer, and nothing else.
##
## WHY THIS SCREEN EXISTS. PLAY used to hand straight to one combined GAME
## screen that asked for a map, a mode and — in the same breath, as three
## sibling buttons — whether you wanted to play offline, host, or join. Three
## different questions were being answered by one row of buttons, and the one
## that decides everything downstream (are other humans involved?) was asked
## last and looked identical to the other two. Asking it first, on its own,
## costs one click and removes the whole class of "I pressed Host and now there
## is a lobby I did not want" confusion.
##
## Flow from here:
##
##   SINGLE PLAYER → MatchSetup.tscn  (pending_action = "local")
##   MULTIPLAYER   → MultiplayerSetup.tscn → MatchSetup.tscn ("host" / "join")
##
## Both branches land in the SAME screen (`match_setup.gd`) — that is the point
## of the overhaul, and the reason this one only sets `GameLaunch.pending_action`
## rather than knowing anything about maps, fighters or ENet.

const MATCH_SETUP_PATH: String = "res://scenes/ui/MatchSetup.tscn"
const MULTIPLAYER_SETUP_PATH: String = "res://scenes/ui/MultiplayerSetup.tscn"
const MAIN_MENU_PATH: String = "res://scenes/ui/MainMenu.tscn"

## Stagger between consecutive pennants unfurling, matching MainMenu.
const STAGGER: float = 0.09

@onready var solo_button: ArrowButton = %SoloButton
@onready var multi_button: ArrowButton = %MultiButton
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	status_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameVersion.attach_to(self)

	solo_button.pressed.connect(_on_solo_pressed)
	multi_button.pressed.connect(_on_multi_pressed)
	back_button.pressed.connect(_on_back_pressed)
	# 4.1: ArrowButton carries its own hover/click SFX (see arrow_button.gd's own
	# doc for why they live there and not here). A plain Button does not, so the
	# BACK button gets its `ui_back` in the handler below, the same way every
	# other plain Button in the front end does.
	back_button.mouse_entered.connect(func() -> void: AudioManager.play("ui_hover"))

	# Q-1/B-62: main.gd bounces a dropped client back to MultiplayerSetup, which
	# owns that message. This screen only ever shows one if something bounced the
	# player all the way out to the fork — kept because consuming it in exactly
	# one place is what stops it surviving into a later, unrelated screen.
	if GameLaunch.pending_status_message != "":
		status_label.text = GameLaunch.pending_status_message
		GameLaunch.pending_status_message = ""

	var buttons: Array[ArrowButton] = [solo_button, multi_button]
	for i in buttons.size():
		buttons[i].animate_in(i * STAGGER)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()

## B-14: MatchManager/RoundManager are autoloads and survive scene changes, so a
## second match would otherwise resume the first one's score. Cleared at the
## point the player commits to a session rather than deeper in, so every entry
## into MatchSetup — solo, host and join alike — starts from the same state.
## `clear_seating()` is separate from `GameLaunch.reset()` on purpose; see its
## own doc for the one-frame window that makes reset() the wrong place.
func _begin_session(action: String) -> void:
	GameLaunch.pending_action = action
	GameLaunch.clear_seating()
	MatchManager.reset()
	RoundManager.reset()

func _on_solo_pressed() -> void:
	_begin_session("local")
	get_tree().change_scene_to_file(MATCH_SETUP_PATH)

## Deliberately does NOT set pending_action — Host and Join are still two
## different sessions and MultiplayerSetup.tscn is where that is chosen. It only
## clears, so backing out of the host/join fork cannot leave a stale action
## behind for the next screen to act on.
func _on_multi_pressed() -> void:
	GameLaunch.pending_action = ""
	GameLaunch.clear_seating()
	MatchManager.reset()
	RoundManager.reset()
	get_tree().change_scene_to_file(MULTIPLAYER_SETUP_PATH)

func _on_back_pressed() -> void:
	AudioManager.play("ui_back") # 4.1
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
