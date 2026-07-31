extends Node
class_name SettingsManagerScript
## Registered as the "SettingsManager" autoload singleton (Project Settings > Autoload).
## Referenced globally as `SettingsManager`, e.g. `SettingsManager.rebind_action(...)`.

## Lets players rebind and persist the local keyboard controls — P1 only,
## since Checklist 5.5: the human plays exactly one unit in Single Player and
## real AI (ai_controller.gd) drives the other three via
## Input.action_press()/action_release(), which needs no key bound at all.
## P2/p3/p4 are intentionally excluded from what a PLAYER can see or rebind —
## P2 still exists in project.godot [input] and still works as a debug-only
## dual-control affordance for `debug_player_switcher.gd` (a developer poking
## at it in the editor), but exposing a rebind UI for a key set no shipped
## player ever touches is dead weight in the Settings panel. p3/p4 were never
## real controls (the unbound local-test dummy slots — see character_base.gd
## `player_id` doc) and were never in this list either.
##
## Settings persist to user://settings.cfg via ConfigFile, one INI-style
## section ("input") with one key per rebindable action holding its physical
## keycode. Defaults are captured from project.godot's own InputMap on first
## _ready() (before anything is ever loaded/overwritten), so "Reset to
## Default" always has something real to fall back to, and doesn't need a
## duplicate hardcoded list of the original keys.

signal binding_changed(action: String)

const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "input"

## Ordered for display purposes — the Settings panel iterates this directly.
##
## Unsuffixed since the 2026-07-29 input overhaul: `*_p1..*_p4` collapsed to one
## action set when split-keyboard play was retired. The panel had already dropped
## its P2 column on 2026-07-28, so this is a rename rather than a scope change.
##
## ⚠️ A `user://settings.cfg` written before that overhaul has its overrides keyed
## by the old `*_p1` names. Nothing here reads them any more, so a player who had
## rebound keys silently gets the defaults back once. Harmless, and cheaper than
## a migration for a pre-release build, but it IS a real (one-time) loss of the
## player's settings rather than a no-op.
## ⚠️ `clean_feed` IS IN HERE BECAUSE A KEY NOBODY CAN SEE OR CHANGE IS NOT A CONTROL.
## It hides the whole HUD while spectating, for the trailer and the demo capture, and it
## shipped 2026-07-31 as a hardcoded `KEY_H` compared straight off `event.keycode` — no
## InputMap action, no settings row, no way to rebind it, and invisible to the conflict
## check that stops two actions sharing a key. Every other control in the game is an
## action; this one is now too. Default H.
## ⚠️⚠️ `grab` AND `ready_up` WERE IN THE INPUTMAP AND NOT IN THIS LIST, WHICH MADE THEM
## UNREBINDABLE GAMEPLAY CONTROLS. Swept 2026-07-31 by comparing `project.godot`'s
## `[input]` block against this array: every action was present except those two.
##
## `grab` is not a convenience key. It is **pick up the tsinelas** and it is **hold for
## `RESET_CHANNEL_TIME` beside your own lata** — the taya's only answer to a stranded lata
## (`Design.md` §5.2), i.e. the defence's entire counterplay to the countdown that decides
## every round. A player who cannot reach `E` could not perform the defence's one verb.
## `ready_up` starts the round and a player who cannot press it cannot start a match.
##
## ⚠️ `grab` ALSO CARRIES A MOUSE BINDING (LMB) and rebinding does not disturb it —
## `_replace_key_binding()` erases only `InputEventKey` events. Note the LMB half is
## double-bound with `special_ability`, which is a separate open question on §4.19.
const REBINDABLE_ACTIONS: Array[String] = [
	"move_left", "move_right", "move_up", "move_down",
	"bump", "guard_dash", "special_ability", "jump", "sprint",
	"grab", "ready_up", "clean_feed",
]

## Human-readable labels for the panel — action string -> display text.
##
## ⚠️ THE LABELS CHANGED WITH THE 2026-07-30 OVERHAUL AND THE ACTION NAMES DID NOT.
## `guard_dash` no longer guards — a lata's Guard was removed outright and the slot
## is Can-Dash / Flick Dash now (`Design.md` §5.3, §6). `bump` is Can-Smash on a lata
## and Ground Smash on an airborne tsinelas. Renaming the ACTIONS would invalidate
## every saved `settings.cfg` key and every `input_probe` assertion for a cosmetic
## gain; the display string is the part a player reads.
const ACTION_LABELS: Dictionary = {
	"move_left": "Move Left", "move_right": "Move Right",
	"move_up": "Move Up", "move_down": "Move Down",
	"bump": "Bump / Smash", "guard_dash": "Dash",
	"special_ability": "Throw / Bump Meter", "jump": "Jump", "sprint": "Sprint",
	# Named for both jobs, because the second one is the one a defender needs and the
	# one nobody guesses from the word "grab": it is also the hold that carries a
	# displaced lata home (`Design.md` §5.2).
	"grab": "Grab / Carry Lata Home",
	"ready_up": "Ready Up",
	# Named for what it DOES to the recording, not for what it hides — the operator
	# reading this row is looking for the setting that gives them a clean plate.
	"clean_feed": "Hide HUD (Spectator)",
}

## action -> physical_keycode captured from the project's InputMap defaults,
## before any user override is ever applied. See _capture_defaults().
var _default_keycodes: Dictionary = {}

const SETTINGS_SECTION_CAMERA: String = "camera"
## Item 14: multiplier on CameraRig.BASE_SENSITIVITY — kept as a plain
## multiplier rather than an absolute degrees-per-pixel value here so the
## slider range (0.2x - 3.0x) reads the same regardless of whatever the rig's
## own base feels right at.
var mouse_sensitivity: float = 1.0
var invert_y: bool = false

## Checklist 4.1 — the three audio buses (Master / SFX / Music, see
## default_bus_layout.tres), 0..1 linear, persisted alongside everything else in
## the same user://settings.cfg.
##
## THE VALUES LIVE HERE; WHAT THEY MEAN TO THE MIXER LIVES IN AudioManager.
## This file knows how to store and reload a number; it deliberately never
## touches AudioServer itself. That split is why the volume model (a fourth bus,
## a limiter on Master) can change without a settings-file migration.
##
## Defaults are 0.8 rather than 1.0. A party game is played on laptop speakers
## with three other people shouting, and shipping at unity leaves a player who
## finds it too loud with only one direction to go — quieter is recoverable,
## clipping is not.
const SETTINGS_SECTION_AUDIO: String = "audio"
const DEFAULT_VOLUME: float = 0.8

var master_volume: float = DEFAULT_VOLUME
var sfx_volume: float = DEFAULT_VOLUME
var music_volume: float = DEFAULT_VOLUME

## ---------------------------------------------------------------------------
## R-09 · BOT DIFFICULTY — the tier the AI plays at.
##
## `AIController.DIFFICULTY_TIERS` (BATA / NORMAL / ASTIG) and `apply_difficulty()`
## have been complete and correct for two passes and reachable from nowhere: until
## `tools/ai_probe.gd` gained a `tier=` argument on 2026-07-30, **nothing outside
## that class had ever called `apply_difficulty()`**, and no tier but NORMAL had
## ever been measured. The BALANCE lane's RUN 12 and RUN 14 measured all three;
## this is the half that lets a player choose one.
##
## ⚠️⚠️ IT IS A MATCH-AFFECTING VALUE, SO IT IS HOST-OWNED IN MULTIPLAYER AND THIS
## FILE IS NOT WHERE THAT IS ENFORCED. The picker on `MatchSetup.tscn` broadcasts
## it down the SAME `_rpc_sync_config` path map and mode already take (10.5, U-8),
## and clients receive it and call in here. **A per-peer difficulty is the exact bug
## U-8 fixed twice** — a client on DENTS denting a can the host on CAPTURE did not,
## and a client on another map walking through walls only it had. Do not add a
## second sync path, and do not "helpfully" apply the local preference on a client.
##
## ⚠️ WHY THE VALUE IS STORED AS AN INT AND NOT AS `AIController.Difficulty`.
## `settings.cfg` is written by `ConfigFile` and read back by a build that may have
## a different enum; an int with a clamp survives that, an enum cast does not. It is
## clamped on load rather than trusted.
##
## The knobs `apply_difficulty()` writes are `static var`s on AIController, so one
## call covers every controller in the process — including ones spawned later, which
## is why this needs no per-match hook beyond being applied when it changes and once
## on load (for a process that never passes through the setup screen at all: a probe,
## or `--host` from the command line).
const SETTINGS_SECTION_MATCH: String = "match"
## Index into AIController.Difficulty. 1 == NORMAL, which is what every measurement
## before RUN 12 was taken at, so it stays the default.
const DEFAULT_DIFFICULTY: int = 1

var ai_difficulty: int = DEFAULT_DIFFICULTY

func _ready() -> void:
	_capture_defaults()
	_load_and_apply()

## R-09. Sets the tier AND pushes it into the live AI knobs. One function, because a
## stored value that is not applied is the shape of the bug this item exists to fix —
## the tiers were already stored, in code, and reachable from nowhere.
##
## `persist` false is for the receiving end of the host's broadcast: a client should
## play the host's tier for this match without that overwriting its own saved
## preference for the next one it hosts.
func set_ai_difficulty(value: int, persist: bool = true) -> void:
	ai_difficulty = clampi(value, 0, AIController.DIFFICULTY_TIERS.size() - 1)
	_apply_ai_difficulty()
	if persist:
		_save()

func _apply_ai_difficulty() -> void:
	AIController.apply_difficulty(ai_difficulty as AIController.Difficulty)

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = value
	_save()

func set_invert_y(value: bool) -> void:
	invert_y = value
	_save()

## 4.1. One setter per bus rather than one three-argument call, because the
## Settings panel's sliders move one at a time and each has to persist on its
## own. All three funnel into the same _apply_volumes(), so a bus can never be
## saved at a level it is not actually playing at.
func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save()

## ⚠️ AudioManager IS LISTED BEFORE SettingsManager IN project.godot's [autoload]
## BLOCK, AND THAT ORDER IS LOAD-BEARING. Autoloads enter the tree in the order
## they are declared, so AudioManager's own _ready() — which is what creates the
## voice pool and resolves the bus indices — has already run by the time this
## file's _ready() reaches _load_and_apply() below. Move SettingsManager above it
## and the saved volumes are applied to a manager that has not built itself yet.
func _apply_volumes() -> void:
	AudioManager.apply_volumes(master_volume, sfx_volume, music_volume)

## Snapshots each rebindable action's current (project-default) key so
## reset_action_to_default() has something to restore without hardcoding a
## second copy of project.godot's key list here.
func _capture_defaults() -> void:
	for action in REBINDABLE_ACTIONS:
		_default_keycodes[action] = _first_physical_keycode(action)

## Returns the physical keycode currently bound to `action`, or -1 if it has
## no key event bound (shouldn't normally happen for p1/p2 actions, but keeps
## this safe to call before defaults are captured too).
func _first_physical_keycode(action: String) -> int:
	if not InputMap.has_action(action):
		return -1
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).physical_keycode
	return -1

## Human-readable name of whatever key is currently bound to `action`
## (e.g. "W", "Space", "Enter") — for display in the Settings panel.
func get_binding_display_name(action: String) -> String:
	var keycode := _first_physical_keycode(action)
	if keycode <= 0:
		return "—"
	return OS.get_keycode_string(keycode)

## B-22: rebinding used to silently allow two actions to share a physical key
## (e.g. P2 Up rebound onto P1's own W), with no warning — both would fire
## together from then on. Returns "" on success, or the display label of
## whichever OTHER action already owns that key, so the caller (Settings
## panel) can show a clear conflict message instead of silently double-binding it.
func rebind_action(action: String, physical_keycode: int) -> String:
	if not InputMap.has_action(action):
		return ""
	var conflict := _find_conflicting_action(action, physical_keycode)
	if conflict != "":
		return ACTION_LABELS.get(conflict, conflict)
	_set_binding(action, physical_keycode)
	return ""

## Whichever OTHER rebindable action already holds `physical_keycode`, or ""
## if none do. Excludes `action` itself — rebinding a key to what it already is
## isn't a conflict.
func _find_conflicting_action(action: String, physical_keycode: int) -> String:
	for other_action in REBINDABLE_ACTIONS:
		if other_action != action and _first_physical_keycode(other_action) == physical_keycode:
			return other_action
	return ""

## ⚠️⚠️ REPLACES THE KEY EVENT ONLY, AND THAT ONE WORD IS A SHIPPED BUG FIX.
##
## 🧑 report, 2026-07-30: *"i cant wind up as attacker?? i cant even throw no
## more"*, with the correct guess that *"this broke bcz i overhauled controls
## earlier"*.
##
## This used to call `InputMap.action_erase_events(action)` — which erases EVERY
## event on the action, not just the keyboard one — and then add back a single
## `InputEventKey`. For the four movement actions that is harmless, because they
## only ever had a key. `special_ability` is different: `project.godot` binds it
## to **Q, LEFT CLICK and RIGHT CLICK**, and the game's own tutorial page
## advertises "Q / LEFT CLICK · Special". The wipe destroyed both mouse bindings
## and re-added Q alone.
##
## ⚠️ AND IT DID NOT NEED A REBIND TO TRIGGER — `_load()` ran the identical
## erase-and-re-add for every action present in `user://settings.cfg`, so ANY
## player with a saved settings file lost left-click on every launch, silently,
## with the correct bindings still sitting in `project.godot`. That is why
## reading `project.godot` says the mouse is bound and the running game says it
## is not; the file is right and the runtime was overwriting it. Measured on this
## machine: `settings.cfg` held `special_ability=81`, and a runtime dump of the
## InputMap showed `special_ability -> key:Q` with no mouse event at all, while
## `grab` — which is NOT in REBINDABLE_ACTIONS and so was never touched — still
## had its `E, MOUSE:1`. Left click therefore grabbed and could never wind up.
##
## Erasing only the `InputEventKey`s leaves mouse and pad bindings from
## `project.godot` intact, which is what a KEY rebind was always supposed to mean.
func _replace_key_binding(action: String, physical_keycode: int) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var replacement := InputEventKey.new()
	replacement.physical_keycode = physical_keycode
	InputMap.action_add_event(action, replacement)

func _set_binding(action: String, physical_keycode: int) -> void:
	_replace_key_binding(action, physical_keycode)
	binding_changed.emit(action)
	_save()

## Bypasses the conflict check above — resetting to a known-good default has
## to always succeed, even mid-way through reset_all_to_default() where an
## action not yet reset might still be sitting on a key that collides with
## another action's default (that's the exact conflict being cleaned up).
func reset_action_to_default(action: String) -> void:
	if not _default_keycodes.has(action):
		return
	_set_binding(action, _default_keycodes[action])

func reset_all_to_default() -> void:
	for action in REBINDABLE_ACTIONS:
		reset_action_to_default(action)

func _save() -> void:
	var config := ConfigFile.new()
	# Load first so we don't clobber other sections/keys some later feature
	# might add to the same file.
	config.load(SETTINGS_PATH)
	for action in REBINDABLE_ACTIONS:
		config.set_value(SETTINGS_SECTION, action, _first_physical_keycode(action))
	config.set_value(SETTINGS_SECTION_CAMERA, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SETTINGS_SECTION_CAMERA, "invert_y", invert_y)
	config.set_value(SETTINGS_SECTION_AUDIO, "master_volume", master_volume)
	config.set_value(SETTINGS_SECTION_AUDIO, "sfx_volume", sfx_volume)
	config.set_value(SETTINGS_SECTION_AUDIO, "music_volume", music_volume)
	config.set_value(SETTINGS_SECTION_MATCH, "ai_difficulty", ai_difficulty)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsManager: failed to save %s (error %d)" % [SETTINGS_PATH, err])

## Bump this when a DEFAULT binding moves, and add the migration below. Written into
## `settings.cfg` so an existing file can be told apart from a fresh one.
const BINDINGS_VERSION: int = 3
const SETTINGS_SECTION_META: String = "meta"

## ⚠️⚠️ A SAVED BINDING OUTLIVES A DEFAULT, AND THAT IS HOW THE LAST TWO CONTROL BUGS
## SHIPPED. Changing `project.godot` fixes the game for a player who has never opened the
## settings panel and for nobody else: `_load_and_apply()` re-applies every saved keycode at
## startup, so the old default comes straight back, and reading the project file then tells
## you one thing while the running game does another. That exact split is what hid the
## left-click wind-up bug for a month (`_replace_key_binding`'s note).
##
## 🧑 decided 2026-07-30 that **Space is jump only** — `input_probe`'s new conflict check
## found Space driving BOTH `jump` and `bump`, so one press jumped and melee'd at once, and
## both keycodes were saved as 32. `bump` moves to F. Every settings.cfg on disk still holds
## `bump=32`, so without this migration the conflict returns on the next launch for everyone
## who has ever run the game, and `input_probe` would go red again with the project file
## looking correct.
##
## Deliberately drops ONLY the stale rows and only once. A migration that reset every
## binding would throw away rebinds the player made on purpose.
## ⚠️ v3, 2026-07-30 — SPRINT TOOK SHIFT AND `guard_dash` MOVED TO CTRL. Stamina
## (`Design.md` §2) needs a sprint key and Shift is the only one a player will reach for.
## `guard_dash` held Left Shift (physical 4194325) since it shipped, so every
## `settings.cfg` on disk carries that value — without this row the two actions would
## BOTH answer Shift on the next launch for everyone who has ever run the game, which is
## exactly the Space/jump/bump conflict from v2 in a new place. The project file would
## look correct the whole time.
const MOVED_BINDINGS: Dictionary = {
	# action -> the default keycode it used to have. A saved value equal to the old default
	# is a stale copy of that default, not a choice; anything else is a real rebind and is
	# left alone.
	"bump": 32, # Space, now jump's alone
	"guard_dash": 4194325, # Left Shift, now sprint's
}

func _migrate_bindings(config: ConfigFile) -> void:
	var version: int = int(config.get_value(SETTINGS_SECTION_META, "bindings_version", 1))
	if version >= BINDINGS_VERSION:
		return
	var dropped: Array[String] = []
	for action in MOVED_BINDINGS:
		var old_default: int = int(MOVED_BINDINGS[action])
		# Both the bare action and the legacy `_p1` copy — `settings.cfg` files written
		# before the 2026-07-29 input overhaul carry both, and the suffixed one is dead
		# weight that would still be re-applied if anything ever read it again.
		for key in [String(action), "%s_p1" % action]:
			if config.has_section_key(SETTINGS_SECTION, key) \
					and int(config.get_value(SETTINGS_SECTION, key)) == old_default:
				config.erase_section_key(SETTINGS_SECTION, key)
				dropped.append(key)
	config.set_value(SETTINGS_SECTION_META, "bindings_version", BINDINGS_VERSION)
	config.save(SETTINGS_PATH)
	if not dropped.is_empty():
		print("[Settings] bindings migrated to v%d — dropped stale %s, project defaults stand"
			% [BINDINGS_VERSION, ", ".join(dropped)])

func _load_and_apply() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		# No saved settings yet — project.godot/coded defaults stand as-is.
		# ⚠️ EXCEPT the volumes, which still have to be PUSHED to the buses.
		# The bus layout ships at 0 dB (unity) and DEFAULT_VOLUME is 0.8, so
		# returning here without applying would leave a first-time player on a
		# mix 2 dB louder than every returning player's — the one case where
		# "no saved file" is not the same as "nothing to do".
		_apply_volumes()
		# R-09: and the difficulty, for the same reason — the AI's live knobs sit at
		# whatever the class initialiser left them, which is NORMAL, and a first-time
		# player must get the same tier a returning one does rather than a coincidence.
		_apply_ai_difficulty()
		return
	_migrate_bindings(config)
	for action in REBINDABLE_ACTIONS:
		if config.has_section_key(SETTINGS_SECTION, action):
			var keycode: int = config.get_value(SETTINGS_SECTION, action)
			if keycode > 0:
				# ⚠️ THE SAME ERASE-EVERYTHING BUG AS `_set_binding`, and THIS is
				# the copy that actually reached players: it runs at startup for
				# every saved action, so a settings.cfg written before the mouse
				# bindings existed silently stripped them on every launch. See
				# `_replace_key_binding`.
				_replace_key_binding(action, keycode)
	if config.has_section_key(SETTINGS_SECTION_CAMERA, "mouse_sensitivity"):
		mouse_sensitivity = config.get_value(SETTINGS_SECTION_CAMERA, "mouse_sensitivity")
	if config.has_section_key(SETTINGS_SECTION_CAMERA, "invert_y"):
		invert_y = config.get_value(SETTINGS_SECTION_CAMERA, "invert_y")
	master_volume = config.get_value(SETTINGS_SECTION_AUDIO, "master_volume", DEFAULT_VOLUME)
	sfx_volume = config.get_value(SETTINGS_SECTION_AUDIO, "sfx_volume", DEFAULT_VOLUME)
	music_volume = config.get_value(SETTINGS_SECTION_AUDIO, "music_volume", DEFAULT_VOLUME)
	_apply_volumes()
	# R-09. Clamped through the setter rather than assigned, so a settings.cfg written
	# by a build with a different tier list cannot push an out-of-range enum into
	# AIController. `persist` false: loading is not a change worth writing back.
	set_ai_difficulty(int(config.get_value(SETTINGS_SECTION_MATCH, "ai_difficulty",
		DEFAULT_DIFFICULTY)), false)
