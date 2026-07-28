extends Node

## Queue item 1 / Dev_Plan.md §3.5 — drive any of the four local-test units by
## hand, for TESTING. Originally this was how a solo tester played a whole Bo5
## on one keyboard at all; since Checklist 5.5, Single Player does that on its
## own (the human plays one unit, AI drives the other three — see
## ai_controller.gd), so this is now specifically a debug OVERRIDE: temporary
## manual control of a unit AI would otherwise be driving, for inspecting or
## exercising it directly. `_apply_slots()` disables that unit's
## `ai_controller` for as long as a slot holds it and hands it straight back
## the instant the slot is cleared (F5, F6, or reassigning the slot to
## something else) — see that function's own doc.
##
## Fixes B-42: from round 2 on, `_on_match_round_started` flips `team_a_is_can`,
## so the tracked Can becomes `TeamBProp` — `player_id = 3`. Before AI existed
## that meant the Can could not be moved or self-righted past round 1; today
## it means nobody has manually overridden it, so its own AI keeps driving it
## exactly as it should.
##
## ⚠️ DEBUG-ONLY. Written to the removal contract in Dev_Plan.md §0.3 and torn
## out by the checklist in §3.5.5. Three rules that make the removal a delete
## rather than an archaeology dig, and that this file must keep honouring:
##
##   1. Every file, class and node in the feature is `debug_`/`Debug` prefixed.
##   2. Debug may call gameplay; gameplay may NEVER name debug — not even behind
##      an `if OS.is_debug_build()`. Nothing here is called from a gameplay
##      script: the units are discovered by walking the scene tree, and the
##      DebugBar registers itself with this autoload rather than the reverse.
##   3. No `[input]` map entries — raw keycodes only, read below.
##
## It also self-disables: `queue_free()` in a release build, and every handler
## no-ops in a networked match (where each peer owns exactly one character and
## reassigning `player_id` would be meaningless).

## Main.tscn order, which is also the Tab cycle order (§3.5.1).
const UNIT_NAMES: Array[String] = ["TeamAProp", "TeamAPerson", "TeamBProp", "TeamBPerson"]
## Registered in project.godot but deliberately never bound, so a unit parked
## here receives no REAL keyboard input at all (§3.5.2). Checklist 5.5: no
## longer the same as "stands inert" — a parked unit with an `ai_controller`
## (every local-test unit except `TeamAPerson`) drives itself via
## `Input.action_press()`/`action_release()` on this same unbound action set,
## which needs no key bound to it at all. Only `TeamAPerson`, which never gets
## an `ai_controller`, is actually inert while parked here.
const PARKED_PLAYER_ID: int = 4
const SLOT_P1: int = 0
const SLOT_P2: int = 1
## Defaults for F6, and for the slot state established when the DebugBar
## registers. P1 holds the Person so a fresh Single Player starts you in the human
## character rather than third-person on a tin can; P2 gets the Prop. Must stay
## in step with Main.tscn's baked player_id values (TeamAPerson=1, TeamAProp=2)
## AND with `main.gd::_start_local_test()`, which picks the same unit for the
## camera — in a release build the switcher self-frees and the baked values are
## the only source of truth (B-67), so all three must agree in both directions.
const DEFAULT_P1_UNIT: String = "TeamAPerson"
const DEFAULT_P2_UNIT: String = "TeamAProp"

## Unit name currently held by each slot, or "" for empty (F5 solo drive).
var _slot_units: Array[String] = [DEFAULT_P1_UNIT, DEFAULT_P2_UNIT]
var _bar: DebugBar = null

func _ready() -> void:
	# §0.3: the whole feature evaporates in a release build regardless of
	# whether anyone remembered to run the removal checklist.
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS # usable while the pause overlay is up

## Called by DebugBar when a match scene comes up (debug → debug, so rule 2
## holds). Establishes a known slot state instead of inheriting whatever
## `player_id` values Main.tscn happens to ship with.
func debug_register_bar(bar: DebugBar) -> void:
	_bar = bar
	_slot_units = [DEFAULT_P1_UNIT, DEFAULT_P2_UNIT]
	_apply_slots()

func debug_unregister_bar() -> void:
	_bar = null

## ⚠️ `_input`, NOT `_unhandled_key_input`. Playtest 0.4 reported "I can't Tab to
## the can", and there are TWO independent reasons for it — this fixes the one
## that bites even in Single Player.
##
## Godot binds Tab to the built-in `ui_focus_next` action, and the viewport's GUI
## layer consumes focus-navigation keys BEFORE unhandled input runs. The HUD and
## the DebugBar are Controls, so as soon as anything on screen is focusable, Tab
## moves focus instead of reaching here and `_unhandled_key_input` never fires
## at all. F1-F6 were unaffected, which is why this looked like "Tab
## specifically is broken" rather than "the handler is not being called".
##
## Handling it in `_input` puts this ahead of the GUI layer. Safe because every
## branch below is gated on `_is_active()` (debug build, match scene, local
## match) and every recognised key calls `set_input_as_handled()`, so nothing
## else in the game ever sees these presses, and unrecognised keys fall straight
## through untouched.
func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	# Raw keycodes, never InputMap actions (rule 3). physical_keycode is the
	# layout-independent one; keycode is the fallback for platforms that only
	# populate that.
	var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
	var slot: int = SLOT_P2 if key.shift_pressed else SLOT_P1

	match code:
		KEY_F1, KEY_F2, KEY_F3, KEY_F4:
			_assign(slot, UNIT_NAMES[code - KEY_F1])
		KEY_TAB:
			_cycle(slot)
		KEY_F5:
			# Solo drive: one unit live, three inert. Shift is irrelevant here,
			# so this is checked as its own case rather than through `slot`.
			_assign(SLOT_P2, "")
		KEY_F6:
			_slot_units = [DEFAULT_P1_UNIT, DEFAULT_P2_UNIT]
			_apply_slots()
		_:
			return
	get_viewport().set_input_as_handled()

## Both guards from §0.3: no-op outside a local match, and no-op if the scene
## doesn't actually hold the four local-test units (menu, or a networked match
## where `_clear_local_test_characters()` freed them).
##
## ⚠️ THE SECOND REASON "I can't Tab to the can" HAPPENS, and it is not a bug.
## A networked match returns false here on purpose: every peer owns exactly one
## character, `character_base.gd::_physics_process` gates movement behind
## `is_multiplayer_authority()`, and `main.gd::_clear_local_test_characters()`
## has already freed the four local units this switcher addresses by name. There
## is nothing to switch to and reassigning `player_id` would grant no control.
##
## So if Tab does nothing and Esc shows "PAUSED — the match is still running",
## the session is HOSTED, not Single Player. That combination is the tell, and it
## is exactly what the 0.4 playtest reported. **Solo-test through Single Player**,
## which is the mode this switcher exists for.
func _is_active() -> bool:
	if _bar == null or NetworkManager.is_networked():
		return false
	return _find_unit(UNIT_NAMES[0]) != null

## Units are located by walking up from the DebugBar (which Main.tscn instances
## under HUDLayer) to whichever ancestor actually holds them, NOT via
## `get_tree().current_scene`. current_scene is only correct when the match was
## reached through `change_scene_to_file`; anything that instances Main.tscn as
## a sub-scene — a test harness, a future lobby that previews the arena — leaves
## it pointing elsewhere and every lookup silently returns null, which surfaces
## as a bar reading "(missing)" rather than as an error.
func _match_root() -> Node:
	var node: Node = _bar
	while node != null:
		if node.has_node(UNIT_NAMES[0]):
			return node
		node = node.get_parent()
	return null

func _find_unit(unit_name: String) -> CharacterBase:
	var scene := _match_root()
	if scene == null:
		return null
	return scene.get_node_or_null(unit_name) as CharacterBase

func _assign(slot: int, unit_name: String) -> void:
	# A slot never takes a unit the other slot already holds, so the two can
	# never both sit on the same `player_id` and move together on one keypress.
	var other := SLOT_P1 if slot == SLOT_P2 else SLOT_P2
	if unit_name != "" and _slot_units[other] == unit_name:
		_slot_units[other] = ""
	_slot_units[slot] = unit_name
	_apply_slots()

## ⚠️ SWAPS with the other slot; it must NOT skip. This is the actual reason the
## 0.4 playtest said "I can't Tab to the can", and it was a real bug rather than
## the mode confusion it first looked like.
##
## The old loop skipped any candidate the other slot already held. P2 holds
## `DEFAULT_P2_UNIT` = "TeamAProp" and never moves on its own, so "TeamAProp" was
## permanently excluded from P1's cycle — and in round 1 Team A defends, which
## means **TeamAProp IS the Can**. P1 could reach TeamBProp and TeamBPerson and
## then wrap straight back past the one unit the player was trying to look at.
## Measured, not guessed: pressing Tab twice from a fresh Single Player walked
## TeamAPerson -> TeamBProp -> TeamBPerson, never touching TeamAProp.
##
## Swapping keeps the invariant that mattered — the two slots can never hold the
## same unit and move together on one keypress — while making every unit
## reachable in one lap. The other slot simply inherits whatever this one was
## driving.
func _cycle(slot: int) -> void:
	var other := SLOT_P1 if slot == SLOT_P2 else SLOT_P2
	var start := UNIT_NAMES.find(_slot_units[slot])
	var candidate := UNIT_NAMES[(start + 1) % UNIT_NAMES.size()]
	if _slot_units[other] == candidate:
		_slot_units[other] = _slot_units[slot]
	_slot_units[slot] = candidate
	_apply_slots()

## The whole mechanism (§3.5.2): reassign the public `player_id` export from the
## outside. `character_base.gd` needs no changes at all — it already resolves
## input through `_action(name) -> "%s_p%d"`. Only ever called from
## `_unhandled_key_input`, never mid-`_physics_process`, or a unit inherits a
## half-consumed edge-triggered press on the frame it gains control.
##
## Checklist 5.5: three of these four units may now have an `ai_controller`
## (main.gd::_attach_ai — never `TeamAPerson`, the human's own default unit).
## A slot claiming a unit is a human taking manual control of it, same as it
## always was — the AI for that specific unit has to step back rather than
## fight the human for the same buttons, so it is disabled exactly when a
## slot holds it and re-enabled the instant it is parked again. This is what
## makes F5 (solo drive, parks P2) put `TeamAProp` back under AI control
## instead of leaving it inert, which is what actually happens in Single
## Player outside the debug switcher entirely.
func _apply_slots() -> void:
	for unit_name in UNIT_NAMES:
		var unit := _find_unit(unit_name)
		if unit == null:
			continue
		var slot := _slot_units.find(unit_name)
		unit.player_id = slot + 1 if slot != -1 else PARKED_PLAYER_ID
		if unit.ai_controller != null:
			unit.ai_controller.set_enabled(slot == -1)

		# §3.5.3: the switcher picks WHICH rig is active via the rig's ordinary
		# public API; it never touches the FPP/TPP mode, which stays derived
		# from is_person (§0.1). Only the P1 slot drives the camera — the P2
		# unit is driven blind off the P1 view, which is what F5 exists for.
		var rig := unit.get_node_or_null("CameraRig") as CameraRig
		if rig != null:
			var is_camera_holder := slot == SLOT_P1
			rig.set_active(is_camera_holder)
			rig.set_aim_source(CameraRig.AimSource.MOUSE if is_camera_holder else CameraRig.AimSource.MOVEMENT)

	if _bar != null:
		_bar.debug_refresh(_describe(SLOT_P1), _describe(SLOT_P2))

## One-line summary of what a slot is holding. Must carry is_person, is_can,
## team and current side (§3.5.4) — that is exactly the state that silently
## changes under you when roles swap between rounds.
func _describe(slot: int) -> String:
	var unit_name := _slot_units[slot]
	if unit_name == "":
		return "—"
	var unit := _find_unit(unit_name)
	if unit == null:
		return "%s (missing)" % unit_name
	var role := "Person" if unit.is_person else ("Can" if unit.is_can else "Tsinelas")
	var side := "DEFENSE" if unit.team_is_can_side else "OFFENSE"
	return "%s (%s · Team %s · %s)" % [unit_name, role, "A" if unit.team == 0 else "B", side]

## Re-read and re-describe both slots without changing them. Called by the bar
## on MatchManager.round_started, since is_can/team_is_can_side flip there.
func debug_refresh_readout() -> void:
	if _bar != null:
		_bar.debug_refresh(_describe(SLOT_P1), _describe(SLOT_P2))
