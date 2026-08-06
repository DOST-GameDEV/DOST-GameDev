extends Node3D

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

		if not who.is_ai_driven():
			_log("[skip]  seat %d is not AI-driven" % who.player_slot)
			continue
		_check("seat %d bot name" % who.player_slot, who.display_name(), roster_name)
		if who.display_name() == seat_label:
			_failures.append("seat %d still answers the bare seat label %s."
				% [who.player_slot, seat_label])

		who.is_bot = false
		who.player_name = "HUMAN%d" % who.player_slot
		who.ai_controller.set_enabled(false)
		await get_tree().physics_frame
		_check("seat %d Tab in shows the driver" % who.player_slot,
			who.display_name(), "HUMAN%d" % who.player_slot)

		who.is_bot = true
		who.ai_controller.set_enabled(true)
		await get_tree().physics_frame
		_check("seat %d Tab out restores character" % who.player_slot,
			who.display_name(), roster_name)
		who.is_bot = false
		who.ai_controller.set_enabled(false)

		who.is_bot = false
		await get_tree().physics_frame
		_check("seat %d mp reclaim shows human" % who.player_slot,
			who.display_name(), "HUMAN%d" % who.player_slot)

		who.is_bot = true
		await get_tree().physics_frame
		_check("seat %d disconnect back to bot" % who.player_slot,
			who.display_name(), roster_name)

		who.is_bot = false
		who.player_name = ""
		await get_tree().physics_frame
		_check("seat %d unnamed human keeps seat label" % who.player_slot,
			who.display_name(), seat_label)

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

