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

var pending_action: String = "" ## "", "host", "join", or "local"
var pending_join_address: String = ""
var game_mode: GameMode = GameMode.OPTION_B

func reset() -> void:
	pending_action = ""
	pending_join_address = ""
