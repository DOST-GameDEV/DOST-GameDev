extends Node
class_name GameLaunchScript

## Autoload singleton "GameLaunch". Session 6.
##
## Small handoff point between MainMenu.tscn and Main.tscn: the menu can't
## pass arguments through change_scene_to_file(), so it stashes the player's
## choice here first. main.gd reads it on _ready() and falls back to the old
## `--host` / `--join=<ip>` command-line-args flow (still handy for
## Debug > Run Multiple Instances) if nothing was set here.

enum GameMode {
	OPTION_B, ## Capture-the-base + Downed/Seal.
	OPTION_A, ## Stock/Health (dents) — 3 dents on a Can ends the round for the
	          ## Slippers (both Cans must be fully dented). Session 7: both modes
	          ## are now real, see round_manager.gd / hitbox.gd.
}

## Checklist 3.5 — THE MAP REGISTRY, and the single place a map is named.
##
## Order is the order the picker shows them in. `id` is what travels between the
## menu and main.gd and what a saved preference would store, so it must stay
## stable even if the display name changes.
##
## Adding a map is one entry here plus the scene — the picker, the launch path
## and the fallback all read this. Nothing else needs editing, which is the whole
## point of it living in the autoload rather than in main_menu.gd.
const MAPS: Array[Dictionary] = [
	{
		"id": &"eskinita",
		"name": "ESKINITA",
		"tagline": "Urban side street. Sari-sari, sampay, jeepney lane.",
		"scene": "res://scenes/maps/Eskinita.tscn",
	},
	{
		"id": &"bayan_plaza",
		"name": "BAYAN PLAZA",
		"tagline": "Barangay plaza. Church, basketball ring, acacia.",
		"scene": "res://scenes/maps/BayanPlaza.tscn",
	},
]

## Which map the next match loads. NOT reset() — unlike pending_action this is a
## preference, not a one-shot handoff, so it survives returning to the menu and
## the player does not have to re-pick after every match.
var selected_map: StringName = &"eskinita"

## Scene path for `selected_map`, or the first map's if the id is somehow
## unknown. main.gd calls this; it never indexes MAPS itself.
func selected_map_scene() -> String:
	for entry in MAPS:
		if entry["id"] == selected_map:
			return String(entry["scene"])
	push_warning("GameLaunch: unknown map '%s', falling back to '%s'" % [
		selected_map, MAPS[0]["id"]])
	return String(MAPS[0]["scene"])

func map_index() -> int:
	for i in range(MAPS.size()):
		if MAPS[i]["id"] == selected_map:
			return i
	return 0

var pending_action: String = "" ## "", "host", "join", or "local"
var pending_join_address: String = ""
var game_mode: GameMode = GameMode.OPTION_B
## Q-1/B-62: set by main.gd right before bouncing back to MainMenu.tscn after
## a network teardown the player didn't initiate (host quit, connection
## failed), so main_menu.gd can explain why they're back here instead of a
## silent, crash-looking bounce. Consumed once, same one-shot pattern as
## pending_action.
var pending_status_message: String = ""

func reset() -> void:
	pending_action = ""
	pending_join_address = ""
	pending_status_message = ""
