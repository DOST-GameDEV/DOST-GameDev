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
## ⚠️ RENAMED WITH THE SEATS. These are `Main.tscn` node names and they were
## `TeamAProp / TeamAPerson / TeamBProp / TeamBPerson`, which no longer exist — the
## debug bar rendered "TeamAPerson (missing)" over a live match because of it.
const UNIT_NAMES: Array[String] = ["Player1", "Player2", "Player3", "Player4"]
## ⚠️ ONE SLOT, NOT TWO — rewritten 2026-07-29 with the input overhaul.
##
## This used to hold two slots (P1/P2, Shift+F1-F4 driving the second) and park
## the other two units on `PARKED_PLAYER_ID = 4`, an action suffix registered in
## project.godot but deliberately bound to no key. That whole mechanism is gone:
## the user retired split-keyboard play ("u can only play as one guy on one pc
## now"), so `*_p1..*_p4` collapsed to ONE unsuffixed action set and there is no
## longer an unbound suffix to park anything on.
##
## The consequence is the invariant this file now exists to uphold. With one
## action set, ANY local character whose AIController is absent-or-disabled reads
## the same keys — so two of them would walk together on one keypress, which is
## exactly the bug `PARKED_PLAYER_ID` used to prevent. Control is therefore
## granted by MOVING AI CONTROL (see _apply_slots): the claimed unit's AI steps
## back, every other unit's AI is switched back on, and at most one unit is ever
## AI-free. `character_base.gd::_action()` documents the same invariant from the
## other side.
##
## F5 (solo drive) is gone with the second slot — solo IS the only mode now.
##
## Default for F6 and for the state established when the DebugBar registers. The
## Person, so a fresh Single Player starts you in the human character rather than
## third-person on a tin can. Must stay in step with `main.gd::_start_local_test()`,
## which picks the same unit for the camera — in a release build the switcher
## self-frees and that is the only source of truth left (B-67).
## ⚠️ A FALLBACK NOW, NOT THE ANSWER — see `_default_unit()` directly below.
## Hardcoding this name meant the bar stole the player's own seat the moment it
## registered.
const DEFAULT_UNIT: String = "Player1"

## Unit name currently driven by the human, or "" for none (every unit under AI).
var _slot_unit: String = DEFAULT_UNIT
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
## ⚠️ THE DEFAULT IS DISCOVERED, NOT DECLARED, AND THAT IS A REAL BUG FIX.
##
## `DEFAULT_UNIT` was the literal "TeamAPerson". Since the setup screen let the
## player pick a SEAT (10.5), the human's unit is whichever one
## `main.gd::_start_local_test()` chose — and registering the bar re-applied the
## hardcoded default over the top of it. A player who picked TEAM B · PERSON
## got, one frame into the match: their own character parked
## (`input_parked = true`), the camera snapped to Team A's Person, and the unit
## they actually chose handed to a bot. `main.gd` documents this as "left alone
## deliberately", which was the wrong call — every editor run is a debug build,
## so this is not an edge case, it is what every session does.
##
## Discovering it needs no gameplay cooperation and so does not break the §0.3
## one-way dependency rule: the human's unit is exactly the one whose AIController
## is not driving it, which this file can read off `CharacterBase` directly.
## `main.gd` now attaches a DISABLED controller to the human's own seat, so both
## the "no controller" and "controller present but off" cases mean the same thing
## here and both are accepted.
func _default_unit() -> String:
	for unit_name in UNIT_NAMES:
		var unit := _find_unit(unit_name)
		if unit == null:
			continue
		if unit.ai_controller == null or not unit.ai_controller.is_enabled():
			return unit_name
	return DEFAULT_UNIT

func debug_register_bar(bar: DebugBar) -> void:
	_bar = bar
	# ⚠️⚠️ DEFERRED, AND WITHOUT THAT THE PLAYER CANNOT MOVE AT ALL.
	#
	# Godot readies CHILDREN before PARENTS, and the DebugBar is a child of
	# Main.tscn — so this function runs during the bar's own `_ready()`, which is
	# BEFORE `main.gd::_ready()` has run `_start_local_test()` and attached a
	# single AIController. `_default_unit()` asks "which unit has no AI driving
	# it", and at that moment the honest answer is "all of them", so it returned
	# the first name in the list and `_apply_slots()` then parked the seat the
	# player had actually chosen.
	#
	# Measured with tools/input_probe.tscn: "units answering the keyboard: 0" on
	# a fresh Single Player, i.e. nobody could move until they pressed Tab. The
	# hardcoded DEFAULT_UNIT this replaced happened to be immune, because a
	# constant needs nothing to exist yet — which is exactly why the discovery
	# version has to wait for the thing it discovers.
	#
	# `call_deferred` lands at idle, after every `_ready()` in the frame.
	_resolve_default.call_deferred()

func _resolve_default() -> void:
	if _bar == null:
		return
	_slot_unit = _default_unit()
	if NetworkManager.is_networked():
		# Solo-host QoL: the local-test node names below don't exist in a
		# networked match at all (main.gd's _clear_local_test_characters()
		# freed them) — _apply_slots() would just describe both slots as
		# "(missing)". See _refresh_bar()'s own doc.
		_refresh_bar()
	else:
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
	# Solo-host QoL: _is_active() can now be true in a networked match (see
	# its own doc) but there is still nothing to switch TO — a networked
	# spawn is exactly one CharacterBase per connected peer, and this only
	# ever activates when there is exactly one. Fall through unhandled
	# rather than swallowing the key: none of F1-F6/Tab are bound to a real
	# game action (§0.3 rule 3), so letting them pass is a no-op, same as an
	# unrecognised key already falls through below.
	if NetworkManager.is_networked():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	# Raw keycodes, never InputMap actions (rule 3). physical_keycode is the
	# layout-independent one; keycode is the fallback for platforms that only
	# populate that.
	var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode

	# Shift is no longer read at all: there is one slot, so Shift+F1-F4 has
	# nothing to address. F5 (solo drive) is gone for the same reason — parking
	# the second slot was the whole of what it did, and solo is now the only mode.
	match code:
		KEY_F1, KEY_F2, KEY_F3, KEY_F4:
			_assign(UNIT_NAMES[code - KEY_F1])
		KEY_TAB:
			_cycle()
		KEY_F6:
			# Back to the seat the PLAYER picked, not to a hardcoded name — see
			# _default_unit(). Resolved at press time rather than cached at
			# registration, so F6 still means "give me my own character back"
			# however far the slot has wandered.
			_assign(_default_unit())
		_:
			return
	get_viewport().set_input_as_handled()

## Both guards from §0.3: no-op outside a local match, and no-op if the scene
## doesn't actually hold the four local-test units (menu, or a networked match
## where `_clear_local_test_characters()` freed them).
##
## ⚠️ A REAL (2+ peer) networked match returns false here on purpose, and this
## is not a bug. Every peer owns exactly one character,
## `character_base.gd::_physics_process` gates movement behind
## `is_multiplayer_authority()`, and `main.gd::_clear_local_test_characters()`
## has already freed the four local units this switcher addresses by name.
## There is nothing to switch to and reassigning `player_id` would grant no
## control. **Solo-test a real 2v2 through Single Player**, which is the mode
## this switcher exists for.
##
## So if Tab does nothing and the pause card shows its "The match is still
## running." note under the title, the session is HOSTED, not Single Player.
## That combination is the tell, and it is exactly what the 0.4 playtest
## reported. (The note used to be appended to the title itself; it moved to its
## own line when the card was restyled.)
##
## Solo-host QoL (2026-07-28+): a SOLO networked session (NetworkManager.
## is_solo_session() — hosting, nobody else has joined) is different from the
## above, not the same case: nothing above stops applying (there is still
## only ever one spawned character, still nothing to cycle TO), but before
## this the bar showed "(missing)" for both slots because it was still
## looking for the four local-test names. See _refresh_bar().
func _is_active() -> bool:
	if _bar == null:
		return false
	if NetworkManager.is_networked():
		return NetworkManager.is_solo_session() and _solo_networked_unit() != null
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

## Solo-host QoL — the networked equivalent of _find_unit(UNIT_NAMES[0]).
## `main.gd`'s networked spawns live under a `Players` node (see
## `MultiplayerSpawner.spawn_path` in Main.tscn), keyed by peer_id rather than
## by the fixed local-test names, so this walks up to that ancestor instead
## of `_match_root()`. Returns the ONE character whose authority is this
## machine's own peer and who isn't AI-driven — solo no longer means there is
## only one spawned character at all (a solo host's unfilled slots are now
## AI-driven, see main.gd's own AI-takeover doc), so the `ai_controller` check
## is what actually narrows this down to "the one I own," same fix as
## main.gd::get_local_character() / camera_rig.gd's own is_mine check.
func _solo_networked_unit() -> CharacterBase:
	var node: Node = _bar
	var players: Node = null
	while node != null:
		if node.has_node("Players"):
			players = node.get_node("Players")
			break
		node = node.get_parent()
	if players == null:
		return null
	for child in players.get_children():
		var character := child as CharacterBase
		if character != null and character.is_multiplayer_authority() and character.ai_controller == null:
			return character
	return null

func _assign(unit_name: String) -> void:
	_slot_unit = unit_name
	_apply_slots()

## Every unit is reachable in one lap, which is what the 0.4 playtest's "I can't
## Tab to the can" was actually about.
##
## ⚠️ That bug is now structurally impossible rather than merely fixed, and the
## reason is worth keeping. The old two-slot cycle skipped any candidate the OTHER
## slot held; P2 defaulted to "TeamAProp" and never moved, so TeamAProp was
## permanently excluded — and in round 1 Team A defends, which means TeamAProp IS
## the Can. Measured at the time: Tab twice from a fresh Single Player walked
## TeamAPerson -> TeamBProp -> TeamBPerson, never touching the one unit the player
## was trying to look at. With one slot there is no other slot to skip against, so
## the cycle is a plain walk over UNIT_NAMES.
func _cycle() -> void:
	var start := UNIT_NAMES.find(_slot_unit)
	_slot_unit = UNIT_NAMES[(start + 1) % UNIT_NAMES.size()]
	_apply_slots()

## ⚠️ THE MECHANISM CHANGED 2026-07-29. It used to reassign the public
## `player_id` export from the outside, because `character_base.gd` resolved
## input through `_action(name) -> "%s_p%d"` and a unit could therefore be parked
## by giving it a suffix bound to no key. The input overhaul collapsed all four
## suffixes into one action set, so `player_id` no longer selects anything and
## parking that way is impossible.
##
## Control is now granted by MOVING AI CONTROL, which was already half the old
## implementation (checklist 5.5 had it disabling the claimed unit's AI so it
## would not fight the human for the same buttons). That is now the WHOLE of it:
##
##   * the claimed unit's AIController is disabled -> `_ai_driven()` false ->
##     it reads the `Input` singleton, i.e. the human's keys;
##   * every other unit's AIController is enabled -> it reads `_ai_intent` and
##     never touches `Input` at all.
##
## ⚠️ THE INVARIANT: at most one local unit may be AI-free at a time. With a
## single action set there is nothing else keeping two units off the same keys —
## two AI-free units would walk together on one keypress, which is precisely what
## `PARKED_PLAYER_ID` used to prevent. One slot is what enforces it, which is why
## the second slot and F5 went away rather than being ported.
##
## `TeamAPerson` never gets an `ai_controller` at all (main.gd::_attach_ai), so
## it is inert rather than AI-driven when something else is claimed. That is the
## one asymmetry left and it is pre-existing.
##
## Only ever called from `_input`, never mid-`_physics_process`, or a unit
## inherits a half-consumed edge-triggered press on the frame it gains control.
func _apply_slots() -> void:
	for unit_name in UNIT_NAMES:
		var unit := _find_unit(unit_name)
		if unit == null:
			continue
		var is_driven := unit_name == _slot_unit
		# `player_id` is deliberately NOT written any more — it is the match-slot
		# identity now, nothing to do with input. Writing it here is what the old
		# mechanism did and it would be a silent no-op today.
		#
		# ⚠️ BOTH LINES ARE LOAD-BEARING AND THEY ARE NOT REDUNDANT.
		# `input_parked` is what actually makes an unclaimed unit deaf to the
		# keyboard; re-enabling its AI is what makes it play on rather than stand
		# inert. Moving AI control ALONE is not enough, and tools/input_probe.gd
		# is what proved it: `main.gd::_attach_ai` never gives `TeamAPerson` an
		# AIController, so with only the line below, Tabbing away from it left it
		# AI-free and still listening — 2 units answering one keypress, and 3
		# after another Tab.
		unit.input_parked = not is_driven
		if unit.ai_controller != null:
			unit.ai_controller.set_enabled(not is_driven)

		# §3.5.3: the switcher picks WHICH rig is active via the rig's ordinary
		# public API; it never touches the FPP/TPP mode, which stays derived
		# from is_person (§0.1). The driven unit is the camera holder, since it
		# is now the only unit a human is driving at all.
		var rig := unit.get_node_or_null("CameraRig") as CameraRig
		if rig != null:
			rig.set_active(is_driven)
			rig.set_aim_source(CameraRig.AimSource.MOUSE if is_driven else CameraRig.AimSource.MOVEMENT)

	_refresh_bar()

## One-line summary of what a slot is holding. Must carry is_person, is_can,
## team and current side (§3.5.4) — that is exactly the state that silently
## changes under you when roles swap between rounds.
func _describe() -> String:
	if _slot_unit == "":
		return "—"
	return _describe_unit(_find_unit(_slot_unit), _slot_unit)

func _describe_unit(unit: CharacterBase, label: String) -> String:
	if unit == null:
		return "%s (missing)" % label
	var side := "TAYA" if unit.is_defender else "ATTACKER"
	return "%s (P%d · %s)" % [label, unit.player_slot + 1, side]

## Re-read and re-describe both slots without changing them. Called by the bar
## on MatchManager.round_started, since is_can/team_is_can_side flip there.
func debug_refresh_readout() -> void:
	_refresh_bar()

## Solo-host QoL — the single point that actually writes to the bar. Split
## out of _apply_slots()/debug_refresh_readout() so both can share the
## networked branch: a real (2+ peer) match never reaches here at all
## (_is_active() is false, nothing above calls this), and a SOLO one shows
## the one unit that actually exists instead of the four local-test names,
## which don't (see _solo_networked_unit()'s own doc for why there is
## nothing to put in a P2 slot here — solo means exactly one spawned
## character, full stop).
func _refresh_bar() -> void:
	if _bar == null:
		return
	if NetworkManager.is_networked():
		_bar.debug_refresh(_describe_unit(_solo_networked_unit(), "you"))
	else:
		_bar.debug_refresh(_describe())
