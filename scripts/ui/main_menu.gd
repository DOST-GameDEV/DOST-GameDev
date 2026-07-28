extends Control
class_name MainMenu

## Session 6: the game's actual entry point now (see project.godot
## run/main_scene). Two panels in one Control, swapped via visibility:
## - TitleScreen: name of the game + a single "Start" button.
## - PlayMenu: Local / Host / Join (with an address field) + a game-mode
##   picker (see game_launch.gd). Host, Join AND (2026-07-28) Local all land in
##   the pre-match Lobby (U-4 / B-13) — user feedback: "add the same [ready]
##   button to local matching." Local's ready gate is cosmetic (nothing to
##   actually wait for on a single PC) but keeps the same READY -> START
##   rhythm the networked path already has; see lobby.gd's own local branch.

const LOBBY_SCENE_PATH: String = "res://scenes/ui/Lobby.tscn"

@onready var title_screen: Control = %TitleScreen
@onready var play_menu: Control = %PlayMenu
@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var local_button: Button = %LocalButton
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var join_address_edit: LineEdit = %JoinAddressEdit
@onready var game_mode_option: OptionButton = %GameModeOption
@onready var map_option: OptionButton = %MapOption
@onready var map_tagline: Label = %MapTagline
@onready var status_label: Label = %StatusLabel
@onready var back_button: Button = %BackButton
## Q-9: moodboard card chrome (Dev_Plan.md §4.2/§4.3) — PANEL fill, INK
## border, an IMPACT accent bar. Applied in code, same pattern as the Q-4/Q-5
## cards, rather than a one-off StyleBoxFlat baked into the .tscn.
@onready var title_card: PanelContainer = %TitleCard
@onready var play_card: PanelContainer = %PlayCard

func _ready() -> void:
	title_screen.visible = true
	play_menu.visible = false
	settings_panel.visible = false
	status_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # item 14: defensive — Main.tscn captures it for a match
	GameVersion.attach_to(self) # build stamp, bottom-right — see game_version.gd

	var card_style := UiTheme.card_style(UiTheme.PANEL, UiTheme.INK, UiTheme.IMPACT)
	title_card.add_theme_stylebox_override("panel", card_style)
	play_card.add_theme_stylebox_override("panel", card_style)

	# Q-1/B-62: a bounce back here from main.gd after the host quit or a join
	# failed — land on the Play menu (not the title screen) since the player
	# was mid-match and most likely wants to rejoin or re-host immediately.
	if GameLaunch.pending_status_message != "":
		title_screen.visible = false
		play_menu.visible = true
		status_label.text = GameLaunch.pending_status_message
		GameLaunch.pending_status_message = ""

	# Checklist 3.5 — the map picker. Built from GameLaunch.MAPS rather than
	# hardcoded here, so adding a map is one entry in the autoload plus a scene:
	# the picker, the launch path and the fallback all read the same list and
	# cannot disagree about what exists.
	#
	# The ITEM ID IS THE INDEX INTO MAPS, not an arbitrary enum, which is what
	# lets _on_map_selected go straight back to the entry for the id.
	map_option.clear()
	for i in range(GameLaunch.MAPS.size()):
		map_option.add_item(String(GameLaunch.MAPS[i]["name"]), i)
	# Reflect what is ALREADY chosen rather than resetting to the first map.
	# GameLaunch.selected_map deliberately survives returning to the menu (it is
	# a preference, not a one-shot handoff like pending_action), so a player who
	# picks Bayan Plaza and plays three matches should not have to re-pick it
	# every time they come back here.
	map_option.select(GameLaunch.map_index())
	_refresh_map_tagline()
	map_option.item_selected.connect(_on_map_selected)

	game_mode_option.clear()
	# B-33: Option A has been fully implemented since Session 7 (hitbox.gd's
	# dent branch, round_manager.gd's dent-based win check) — the "(coming
	# soon)" label was stale and both items were always selectable/playable
	# either way, so there was no actual gate to fix, just a wrong label.
	game_mode_option.add_item("Option B — Capture & Seal", GameLaunch.GameMode.OPTION_B)
	game_mode_option.add_item("Option A — Health / Dents", GameLaunch.GameMode.OPTION_A)
	game_mode_option.select(0)
	game_mode_option.item_selected.connect(_on_game_mode_selected)

	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_panel.back_pressed.connect(_on_settings_back_pressed)
	back_button.pressed.connect(_on_back_pressed)
	local_button.pressed.connect(_on_local_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

## B-34: Settings was reachable from TitleScreen but PlayMenu had no way back
## to it (or to TitleScreen at all) without restarting the game.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and play_menu.visible:
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _on_back_pressed() -> void:
	play_menu.visible = false
	title_screen.visible = true
	status_label.text = ""

func _on_start_pressed() -> void:
	title_screen.visible = false
	play_menu.visible = true

## Q-9: title-screen-only, deliberately. A mid-match quit that skips
## NetworkManager.disconnect_network() would strand the other peers — the
## same soft-lock Q-1 fixed, just from the other end. Return to Menu → Quit
## is two clear steps instead.
func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_settings_pressed() -> void:
	title_screen.visible = false
	play_menu.visible = false
	settings_panel.visible = true

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	title_screen.visible = true

## The tagline is the whole reason this is an OptionButton plus a Label rather
## than a bare dropdown: "ESKINITA" means nothing to a judge who has never played
## it, and one line of what the map actually is costs nothing.
func _refresh_map_tagline() -> void:
	var i := map_option.get_selected_id()
	if i < 0 or i >= GameLaunch.MAPS.size():
		map_tagline.text = ""
		return
	map_tagline.text = String(GameLaunch.MAPS[i]["tagline"])

func _on_map_selected(_index: int) -> void:
	var i := map_option.get_selected_id()
	if i < 0 or i >= GameLaunch.MAPS.size():
		return
	GameLaunch.selected_map = GameLaunch.MAPS[i]["id"]
	_refresh_map_tagline()

func _on_game_mode_selected(_index: int) -> void:
	GameLaunch.game_mode = game_mode_option.get_selected_id() as GameLaunch.GameMode

## 2026-07-28: Local now goes through the lobby too, same as Host/Join — see
## the class doc above. B-14's reset-before-transition still applies here,
## same as it always did; lobby.gd's local branch resets AGAIN immediately
## before the actual scene change to Main.tscn, mirroring exactly how the
## networked _rpc_begin_match handler already double-resets for Host/Join.
func _on_local_pressed() -> void:
	GameLaunch.pending_action = "local"
	MatchManager.reset()
	RoundManager.reset()
	get_tree().change_scene_to_file(LOBBY_SCENE_PATH)

## U-4: Host goes to the lobby so peers can ready-up before the match starts.
func _on_host_pressed() -> void:
	GameLaunch.pending_action = "host"
	MatchManager.reset()
	RoundManager.reset()
	get_tree().change_scene_to_file(LOBBY_SCENE_PATH)

## U-4: Join also goes through the lobby for the same ready-up gate.
func _on_join_pressed() -> void:
	var address := join_address_edit.text.strip_edges()
	if address.is_empty():
		status_label.text = "Enter a host address first (e.g. 127.0.0.1)."
		return
	GameLaunch.pending_action = "join"
	GameLaunch.pending_join_address = address
	MatchManager.reset()
	RoundManager.reset()
	get_tree().change_scene_to_file(LOBBY_SCENE_PATH)
