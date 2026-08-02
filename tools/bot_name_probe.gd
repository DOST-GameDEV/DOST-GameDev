extends Node3D
## ARE THE BOTS CALLED BY THEIR CHARACTERS, AND DOES THE NAME SURVIVE A HANDOVER?
## **Written 2026-08-02.**
##
##     Godot_v4.7.1-stable_win64_console.exe --path <repo> tools/bot_name_probe.tscn
##
## ---------------------------------------------------------------------------
## 🧑 2026-08-02: *"give the bots names, not just p1 p2, give them the names of their
## characters ... make sure that when human switches to bot or smth the name doesnt
## bug as there are many ways for human and bot to switch (tab, singleplayer and when
## someone disconnects reconnects in multiplayer)"*.
##
## ⚠️⚠️ WHAT THIS ACTUALLY GUARDS IS THE DERIVATION, NOT THE STRING. `display_name()`
## reads `is_ai_driven()` live instead of being written at each handover, which is why
## there is no per-path fix for Tab, `_rpc_convert_to_ai` and `_rpc_reclaim_character`.
## The check below therefore drives the HANDOVER ITSELF — disable the controller, read
## the name, re-enable it, read it again — because a cached implementation passes the
## static reading and fails exactly here.
##
## ⚠️ IT GOES RED ON THE CODE THIS REPLACED: every AI seat answered "P1".."P4".
##
## ⚠️ RUN WITHOUT `--headless` (a live match, same as `trait_probe`).

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

var _main: Node = null
var _failures: Array[String] = []
var _lines: Array[String] = []

func _ready() -> void:
	GameLaunch.spectator = true
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()

func _log(t: String) -> void:
	_lines.append(t)

func _check(name: String, got: String, want: String) -> void:
	var ok := got == want
	_log("%-44s got %-14s want %-14s %s" % [name, got, want, "OK" if ok else "FAIL"])
	if not ok:
		_failures.append("%s: got %s, wanted %s." % [name, got, want])

func _run() -> void:
	for _i in range(1200):
		await get_tree().physics_frame
		if RoundManager.round_active and RoundManager.lata != null:
			break
	for _j in range(8):
		await get_tree().physics_frame

	_check_name_lengths()

	var seats := RoundManager.players()
	if seats.is_empty():
		_failures.append("HARNESS: no seats in the live round.")
		_report()
		return

	for node in seats:
		var who := node as CharacterBase
		if who == null:
			continue
		var roster_name := CharacterRoster.name_at(who.character_index)
		var seat_label := "P%d" % [who.player_slot + 1]

		# 1. A bot wears its character.
		if not who.is_ai_driven():
			_log("[skip]  seat %d is not AI-driven" % who.player_slot)
			continue
		_check("seat %d bot name" % who.player_slot, who.display_name(), roster_name)
		if who.display_name() == seat_label:
			_failures.append("seat %d still answers the bare seat label %s."
				% [who.player_slot, seat_label])

		# ⚠️⚠️ THERE ARE TWO DIFFERENT "TAKEOVERS" AND THEY MEAN DIFFERENT THINGS.
		# Conflating them is what this block got wrong first time round.
		#
		#   SOLO / Tab — `debug_player_switcher.gd` flips `set_enabled()` on a seat so
		#   the keyboard drives it. `is_bot` is untouched, and the name STAYS the
		#   character's: you have taken over LOLA PACING, you have not become her.
		#   That is the L4D2 reading the human asked for.
		#
		#   MULTIPLAYER reclaim — `_rpc_reclaim_character` hands the seat back to a
		#   returning human and clears `is_bot` on every peer, so their own name comes
		#   back on every screen.
		#
		# 2. SOLO / Tab: control moves, the name does not.
		# ⚠️ `is_bot` IS SET EXPLICITLY RATHER THAN ASSUMED. The harness seeds one seat
		# as the local human (`is_bot = character != human` in `main.gd`), so reading
		# whatever the seat happened to start as made this check pass on three seats
		# and fail on the fourth for a reason that had nothing to do with the code
		# under test. A probe states the state it is testing.
		who.is_bot = true
		who.player_name = "HUMAN%d" % who.player_slot
		who.ai_controller.set_enabled(false)
		await get_tree().physics_frame
		_check("seat %d solo Tab takeover keeps character" % who.player_slot,
			who.display_name(), roster_name)

		# 3. MULTIPLAYER reclaim: the human's own name returns.
		who.is_bot = false
		await get_tree().physics_frame
		_check("seat %d mp reclaim shows human" % who.player_slot,
			who.display_name(), "HUMAN%d" % who.player_slot)

		# 4. AND BACK TO A BOT on a disconnect. `player_name` is deliberately left
		# set - a rejoining human owns it - so this is the check that catches a bot
		# wearing the name of whoever just quit.
		who.is_bot = true
		await get_tree().physics_frame
		_check("seat %d disconnect back to bot" % who.player_slot,
			who.display_name(), roster_name)

		# 5. An unnamed human keeps the SEAT LABEL, never the character. 🧑 *"make
		# sure human's name doesnt change too"*.
		who.is_bot = false
		who.player_name = ""
		await get_tree().physics_frame
		_check("seat %d unnamed human keeps seat label" % who.player_slot,
			who.display_name(), seat_label)

		# 6. A named human survives a character re-pick - `character_index` is
		# reassigned in five places, so a character-derived label for a human would
		# not be stable across a reclaim. `player_slot` is.
		who.player_name = "HUMAN%d" % who.player_slot
		var was := who.character_index
		who.character_index = (was + 1) % CharacterRoster.size()
		await get_tree().physics_frame
		_check("seat %d named human after re-pick" % who.player_slot,
			who.display_name(), "HUMAN%d" % who.player_slot)
		who.character_index = was
		who.player_name = ""
		who.is_bot = true
		who.ai_controller.set_enabled(true)

	_report()

func _report() -> void:
	print("\n========== BOT NAME PROBE — are bots called by their characters? ==========")
	for l in _lines:
		print(l)
	if _failures.is_empty():
		print("\nRESULT: PASS — every seat is named by its character and survives a handover.")
	else:
		print("\nRESULT: FAIL — %d check(s)" % _failures.size())
		for f in _failures:
			print("  * %s" % f)
	get_tree().quit(0 if _failures.is_empty() else 1)

## ⚠️⚠️ THE LENGTH LIMIT IS ENFORCED HERE RATHER THAN CLIPPED AT DRAW TIME. 🧑
## 2026-08-02: *"lets not truncate the names / lets js put a limit to how long names
## can be"*. So nothing in the game shortens a name; instead a name that would break a
## layout fails this probe, which is the difference between the bug being found by the
## build and being found by a player mid-match.
##
## All three tables, not just the Persons: a can and a slipper name share the CHARACTER
## screen's one `NAME` row, and the role-swap cards that were reported overlapping put
## two Person names side by side inside a fixed 220 px panel.
func _check_name_lengths() -> void:
	var tables := {
		"person": CharacterRoster.ROSTER,
		"lata": CharacterRoster.CANS,
		"tsinelas": CharacterRoster.SLIPPERS,
	}
	var worst := 0
	var worst_name := ""
	for kind in tables:
		for entry in tables[kind]:
			var name_text := String(entry.get("name", ""))
			if name_text.length() > worst:
				worst = name_text.length()
				worst_name = name_text
			if name_text.length() > CharacterRoster.NAME_MAX:
				_failures.append("%s name %s is %d chars, over NAME_MAX %d."
					% [kind, name_text, name_text.length(), CharacterRoster.NAME_MAX])
	_log("%-44s worst %-14s %d/%d chars    %s" % ["every roster name within NAME_MAX",
		worst_name, worst, CharacterRoster.NAME_MAX,
		"OK" if worst <= CharacterRoster.NAME_MAX else "FAIL"])
