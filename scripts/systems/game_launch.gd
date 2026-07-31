extends Node
class_name GameLaunchScript

## Autoload singleton "GameLaunch". Session 6.
##
## Small handoff point between MainMenu.tscn and Main.tscn: the menu can't
## pass arguments through change_scene_to_file(), so it stashes the player's
## choice here first. main.gd reads it on _ready() and falls back to the old
## `--host` / `--join=<ip>` command-line-args flow (still handy for
## Debug > Run Multiple Instances) if nothing was set here.

## ⚠️ `enum GameMode` AND `var game_mode` WERE DELETED HERE. 2026-07-31, 📋 `build rules`
## §8.2 — the game shipped two win-condition sets and let the host pick between them.
## There is now one ruleset (the circle countdown) and therefore nothing to select.
## `Design.md` §7.2 records what Option A was and why it went.

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
## The name this peer plays under, straight from Settings. Exposed here rather than
## read from `SettingsManager` at each call site so the lobby, the spawn path and the
## HUD all take it from the same place a roster pick comes from.
func player_name() -> String:
	return SettingsManager.player_name

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

## ⚠️ SEAT -1 IS THE SPECTATOR SEAT, AND IT IS A SEAT RATHER THAN A MODE ON PURPOSE.
## `Design.md` §9.
##
## Everything downstream of seating already handles "this peer holds no seat": an
## unclaimed slot is filled with a negative-sentinel AI by
## `main.gd::_fill_empty_slots_with_placeholders`, which has existed since before
## spectating did. So a spectator is not a new branch through the spawn path — it is the
## ABSENCE of one, plus a camera. That is why this is one bool and four guards rather
## than a mode with its own flow.
##
## A PREFERENCE, not a one-shot handoff, so it is NOT cleared by `reset()` — same
## lifetime and same reasoning as `selected_map` and the three character picks. A player
## who spectated one match and wants to spectate the next should not have to say so
## again; the setup screen is where they change their mind.
var spectator: bool = false

## Cleared when a NEW session is being set up, not by `reset()` — `main.gd` calls
## `reset()` inside its own `_ready()`, after reading `pending_action` but BEFORE
## spawning anyone, so clearing seating there would wipe the assignment the setup
## screen just made, one frame before it is used.
func clear_seating() -> void:
	seat_tokens.clear()


## ---------------------------------------------------------------------------
## ⚠️⚠️ "UI GOES BELOW SCREEN" — AND IT IS THE WINDOW, NOT THE LAYOUT.
##
## 🧑 report, 2026-07-30, with a screenshot: *"ui goes below screen, pls make sure
## no ui goes below screen bruh."* The YOU card's bottom row ("SLIPPER READY") is
## sheared in half by the bottom of the frame mid-match.
##
## ⚠️ THE SCREENSHOT IS THE MEASUREMENT, AND IT IS 1920x1037. Not 1080. The card
## lays out at y 908..1064 (`ui_layout_probe`, every row set, both presets — its
## content minimum FITS its 156px anchor box with room to spare, so no amount of
## re-anchoring that card would have fixed anything). 1064 is inside 1080 and
## outside 1037, which is the whole bug: 43 pixels of the client area were never on
## the screen at all.
##
## `project.godot` asks for a 1920x1080 WINDOWED window and nothing in the project
## touched the window after that. On a 1920x1080 display that cannot fit: add a
## title bar and a border and the bottom of the client area is pushed under the
## taskbar and off the panel. Every bottom-anchored control loses its last rows —
## the YOU card, the lata card, the ready prompt, the round-objective line — and
## `stretch/aspect="expand"` hides it from every layout check ever run, because the
## CONTENT rect is still a perfect 1920x1080 and every rect in it is exactly where
## it was designed to be. There is no overflow to find in the scene tree.
##
## So the fix is to make the window fit the screen it is on, once, at boot:
##
##   * shrink the client area until the DECORATED window fits the usable rect
##     (which already excludes the taskbar), and
##   * re-centre it inside that rect, so it cannot hang off an edge either way.
##
## ⚠️ THE ASPECT IS PRESERVED ON PURPOSE. Under `stretch/aspect="expand"` the
## content rect is derived from the window's ASPECT, not its pixel count, so a
## 16:9 client area of any size lays out in the same 1920x1080 content rect the
## whole UI was designed against — the layout is untouched and every probe number
## still describes what the player sees. Squeezing only the height instead would
## change the aspect, grow the content rect, and move every anchored control.
##
## ⚠️ NOT FULLSCREEN. Forcing `display/window/size/mode` would fix the clipping and
## break two-instance LAN testing, which is how this game is developed and how the
## human tests it. It also cannot be done from here: `project.godot` is
## SHARED-LOCK. A window that fits needs no lock and no mode change.
##
## Asserted by `tools/ui_layout_probe.gd::_report_window_fit()`, which calls this
## function and then checks the decorated window against the usable rect — the one
## check in that file that looks at the WINDOW rather than at the content rect.
## ---------------------------------------------------------------------------

## ⚠️ AN EXPLICIT `--resolution` WINS. Half the render harnesses in `tools/` ask the
## engine for a specific window size and then save a PNG of it — `ui_shot`,
## `charselect_overlay_shot`, `ui_layout_probe`'s own presets. Silently shrinking the
## window under them would return images at a size nobody asked for, and a capture
## harness that quietly changes resolution is the kind of fault that gets read as a
## layout change. A player launching the game normally passes no such flag.
func _ready() -> void:
	if "--resolution" in OS.get_cmdline_args():
		return
	fit_window_to_usable_screen()

## Public so the layout probe can drive the real thing rather than a copy of it.
## Safe to call more than once and a no-op when the window already fits.
func fit_window_to_usable_screen() -> void:
	# No window manager, no decorations, no usable rect worth reading.
	if DisplayServer.get_name() == "headless":
		return
	var win := get_window()
	if win == null:
		return
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return
	# How much bigger the decorated window is than its client area, and where the
	# client area sits inside it. Both come off the window itself rather than from
	# a guessed title-bar height, which differs per platform and per theme.
	var extra: Vector2i = win.get_size_with_decorations() - win.size
	var inset: Vector2i = win.position - win.get_position_with_decorations()
	var room: Vector2i = usable.size - extra
	if room.x <= 0 or room.y <= 0:
		return
	# One scale for both axes: fitting the axes independently would change the
	# aspect, and under `expand` the aspect IS the layout. See the note above.
	var scale := minf(
		minf(float(room.x) / float(win.size.x), float(room.y) / float(win.size.y)), 1.0)
	if scale < 1.0:
		win.size = Vector2i(
			maxi(int(floor(win.size.x * scale)), 1), maxi(int(floor(win.size.y * scale)), 1))
		extra = win.get_size_with_decorations() - win.size
	# Centre what is now known to fit, so the same 43 pixels cannot be lost off the
	# bottom by a window the WM happened to place low.
	var decorated: Vector2i = win.size + extra
	win.position = usable.position + inset + Vector2i(
		maxi((usable.size.x - decorated.x) / 2, 0), maxi((usable.size.y - decorated.y) / 2, 0))
