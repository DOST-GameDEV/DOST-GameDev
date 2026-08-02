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

		# 2. HANDOVER TO A HUMAN. The controller is disabled rather than freed,
		# which is what `_rpc_reclaim_character` does on a rejoin.
		who.player_name = "HUMAN%d" % who.player_slot
		who.ai_controller.set_enabled(false)
		await get_tree().physics_frame
		_check("seat %d after human takeover" % who.player_slot,
			who.display_name(), "HUMAN%d" % who.player_slot)

		# 3. HANDOVER BACK TO A BOT — the disconnect case. `player_name` is
		# deliberately left set, because a rejoining human owns it; the name must
		# come off the character anyway.
		who.ai_controller.set_enabled(true)
		await get_tree().physics_frame
		_check("seat %d after handover back to bot" % who.player_slot,
			who.display_name(), roster_name)

		# 4. ⚠️ AN UNNAMED HUMAN KEEPS THE SEAT LABEL, IT DOES NOT BORROW THE
		# CHARACTER. 🧑 *"make sure human's name doesnt change too"*. Two reasons and
		# the second is the hard one: a human reading MARING is indistinguishable from
		# a bot, and `character_index` is reassigned in five places, so a
		# character-derived label for a human is not even stable across a reclaim.
		# `player_slot` is.
		who.ai_controller.set_enabled(false)
		who.player_name = ""
		await get_tree().physics_frame
		_check("seat %d unnamed human keeps seat label" % who.player_slot,
			who.display_name(), seat_label)

		# 5. And a named human survives a character re-pick, which is the drift the
		# check above exists to prevent.
		who.player_name = "HUMAN%d" % who.player_slot
		var was := who.character_index
		who.character_index = (was + 1) % CharacterRoster.size()
		await get_tree().physics_frame
		_check("seat %d named human after re-pick" % who.player_slot,
			who.display_name(), "HUMAN%d" % who.player_slot)
		who.character_index = was
		who.player_name = ""
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
