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
## Adding a map is one entry here plus the scene — the picker, the launch path,
## the GAME screen's live 3D backdrop and the fallback all read this. Nothing
## else needs editing, which is the whole point of it living in the autoload
## rather than in main_menu.gd.
##
## `preview` is the beauty shot `scripts/ui/map_preview.gd` frames the map with
## on the GAME screen. It lives here rather than as a Marker3D in the map scene
## because `tools/maps/build_*.py` emit those scenes WHOLESALE — a camera added
## to Eskinita.tscn by hand survives exactly until the next layout run. Omit it
## and the preview falls back to MapPreview's defaults, so a new map still shows
## something sensible before anyone tunes its angle.
##
##   yaw       degrees around the play area, measured off +Z
##   distance  metres back from the pivot
##   height    metres above it
const MAPS: Array[Dictionary] = [
	{
		"id": &"eskinita",
		"name": "ESKINITA",
		"tagline": "Urban side street. Sari-sari, sampay, kanal.",
		"scene": "res://scenes/maps/Eskinita.tscn",
		"preview": {"yaw": 0.0, "distance": 22.0, "height": 16.0},
	},
	{
		# ⚠️ B-104 — this said `&"eskinita"` too, so `selected_map_scene()`'s
		# first-match lookup resolved BOTH entries to Eskinita and **Bayan Plaza
		# could never be loaded by anything**: not the picker, not the launch
		# path, not the render harness. It fails completely silently — you pick
		# the second map and the first one loads, which reads as "the picker is
		# ignoring me" rather than as a duplicate key.
		# Found 2026-07-28 while trying to render the re-dressed plaza (7.5) and
		# getting Eskinita back three times.
		"id": &"bayan_plaza",
		"name": "BAYAN PLAZA",
		"tagline": "Barangay plaza. Church, basketball ring, acacia.",
		"scene": "res://scenes/maps/BayanPlaza.tscn",
		"preview": {"yaw": 0.0, "distance": 22.0, "height": 16.0},
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

## Which character this player picked on the CHARACTER screen. A PREFERENCE, not
## a one-shot handoff — same lifetime and same reasoning as `selected_map` above,
## so a player who picked Aling Nena does not have to re-pick her every match.
## Deliberately NOT cleared by reset().
##
## Stored as the roster's stable `id` rather than its index: an index is a wire
## format (see character_roster.gd's note on append-only ordering) and would
## silently point at a different person if the roster were ever reordered.
var selected_character: StringName = &"berto"

## Roster index for `selected_character`, or 0 if the id is unknown — which is
## what a preference saved by a newer build looks like to an older one. Falls
## back to the signed-off Person rather than to nothing.
func character_index() -> int:
	var index := CharacterRoster.index_of(selected_character)
	return index if index >= 0 else 0

## The other two tabs of the CHARACTER screen. A player controls a Person AND a
## Prop, and the Prop is a lata one round and a tsinelas the next, so all three
## are picked and all three are preferences with the same lifetime as the map.
var selected_can: StringName = &"sarsi"
var selected_slipper: StringName = &"goma"

func can_index() -> int:
	var index := CharacterRoster.index_in(CharacterRoster.CANS, selected_can)
	return index if index >= 0 else 0

func slipper_index() -> int:
	var index := CharacterRoster.index_in(CharacterRoster.SLIPPERS, selected_slipper)
	return index if index >= 0 else 0

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

# --- SEATING (10.5) -----------------------------------------------------------
#
# A SEAT is an index 0..3 with exactly the meaning `main.gd` already gives its
# join index, unchanged and deliberately so:
#
#     team      = seat / 2         → 0, 0, 1, 1
#     is_person = seat % 2 == 0    → the even seat of each pair is the Person
#
# Nothing new is invented here; what changed is only WHO decides the number. It
# used to be connection order alone (`_next_join_index`), which no player could
# see, influence or predict. It is now whatever seat that player actually clicked
# in the setup screen, with connection order kept as the fallback for peers that
# never went through one (`--host`/`--join` from the command line, and mid-match
# late joiners).

## Host-authoritative: NetworkManager token -> seat. Populated by the setup
## screen and broadcast to every peer before the match scene loads, so all four
## peers agree on who sits where BEFORE `main.gd` spawns anybody. Read by
## `main.gd::_claim_join_index()`.
##
## Keyed by the stable per-install token rather than by peer id, because peer ids
## do not survive a reconnect and seats must (4.3/B-65).
var seat_tokens: Dictionary = {}

## Single Player only: which seat the human takes. Networked seating goes through
## `seat_tokens` above, which has no meaning without a NetworkManager session.
var solo_seat: int = 0

## Cleared when a NEW session is being set up, not by `reset()` — `main.gd` calls
## `reset()` inside its own `_ready()`, after reading `pending_action` but BEFORE
## spawning anyone, so clearing seating there would wipe the assignment the setup
## screen just made, one frame before it is used.
func clear_seating() -> void:
	seat_tokens.clear()
