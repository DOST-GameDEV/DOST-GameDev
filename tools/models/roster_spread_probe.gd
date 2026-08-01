extends Node
## DO THE FOUR SEATS WEAR FOUR DIFFERENT PEOPLE — AND DOES EVERY VIEWER AGREE?
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/models/roster_spread_probe.tscn -- out=C:/tmp/
##     ... -- spectate                (the filmed case: no human seat at all)
##
## ⚠️ PLAIN EXE — it renders a group shot at the end.
##
## 🧑 2026-08-01: *"RANDOMISE THE BOTS' CHARACTER SKINS"*, and separately *"make
## sure as well that it works in multiplayer, that other people and the spectator
## all see the same skins"*.
##
## Those are two different questions and this answers both:
##
##   DISTINCT  every seat resolves a real roster entry, and no two seats resolve
##             the same one. That is the reported bug — `character_index` stays
##             -1 on an AI seat and `character_visual.gd::_model_path()` then
##             falls back to `PERSON_MODELS[team]`, so a four-player match
##             rendered two models.
##   AGREED    the seat -> Person mapping is a property of the MATCH, not of the
##             machine looking at it. This prints the mapping as a signature so a
##             second peer's run can be diffed against the first — the same
##             byte-identical-stream trick `net_twopeer_probe` uses, which is the
##             only honest way to check "everyone sees the same skins" without
##             four people in a room.
##
## ⚠️ IT READS THE MODEL THAT IS ACTUALLY LOADED, NOT `character_index`. An index
## agreeing on two peers while the mesh under it does not is exactly the class of
## bug this is looking for, so the check walks each unit's `Visual` for the real
## `.glb` path — the thing a viewer can actually see.

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

var _out: String = ""
var _main: Node = null
var _log: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("out="):
			_out = text.substr(4)
		elif text == "spectate":
			# The filmed case. A spectator holds no seat, so ALL FOUR units are
			# unpicked — which is the harshest version of the test and the one
			# `_dress_spectated_units()` exists for.
			GameLaunch.spectator = true
	if _out == "":
		_out = ProjectSettings.globalize_path("user://")
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()


func _emit(text: String) -> void:
	print(text)
	_log.append(text)


func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	if _main.has_method("_run_ready_countdown"):
		_main._run_ready_countdown()
	await get_tree().create_timer(5.0).timeout

	var rows: Array[Dictionary] = []
	for node in _main.find_children("*", "CharacterBase", true, false):
		var who := node as CharacterBase
		if who == null or not who.is_person:
			continue
		rows.append({
			"slot": who.player_slot,
			"index": who.character_index,
			"name": _roster_name(who.character_index),
			"model": _loaded_model(who),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["slot"]) < int(b["slot"]))

	_emit("=== ROSTER SPREAD %s ===" % ("(spectator)" if GameLaunch.spectator else "(playing)"))
	for row in rows:
		_emit("  P%d  index=%-3d %-14s %s"
			% [int(row["slot"]) + 1, int(row["index"]), String(row["name"]),
				String(row["model"]).get_file()])

	var failures := 0
	if rows.size() != 4:
		_emit("  FAIL  expected 4 Persons, found %d" % rows.size())
		failures += 1

	var seen_models: Array[String] = []
	for row in rows:
		if int(row["index"]) < 0:
			_emit("  FAIL  P%d has no roster pick — it will draw the fallback model"
				% [int(row["slot"]) + 1])
			failures += 1
		var model := String(row["model"])
		if model == "":
			_emit("  FAIL  P%d has no model loaded at all" % [int(row["slot"]) + 1])
			failures += 1
		elif model in seen_models:
			_emit("  FAIL  P%d wears %s, which another seat is already wearing"
				% [int(row["slot"]) + 1, model.get_file()])
			failures += 1
		else:
			seen_models.append(model)

	# ⚠️ THE SIGNATURE IS THE MULTIPLAYER HALF. Run this on two peers and diff the
	# one line; identical means every viewer resolves the same person for the same
	# seat, which is what was actually asked.
	var signature := PackedStringArray()
	for row in rows:
		signature.append("%d:%s" % [int(row["slot"]), String(row["model"]).get_file()])
	_emit("  SIGNATURE  %s" % " ".join(signature))

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%sroster_spread%s.png" % [_out, "_spectator" if GameLaunch.spectator else ""]
	_emit("  frame -> %s" % (path if image.save_png(path) == OK else "FAILED"))

	_emit("ROSTER SPREAD: %s" % ("PASS — four distinct people" if failures == 0
		else "%d FAILURE(S)" % failures))
	var file := FileAccess.open("user://roster_spread_probe.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	get_tree().quit(0 if failures == 0 else 1)


func _roster_name(index: int) -> String:
	if index < 0 or index >= CharacterRoster.ROSTER.size():
		return "<none>"
	return String(CharacterRoster.ROSTER[index].get("name", "?"))


## The .glb actually instanced under this unit's Visual — not the index that was
## supposed to produce it.
func _loaded_model(who: CharacterBase) -> String:
	var visual := who.get_node_or_null("Visual") as Node3D
	if visual == null:
		return ""
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh != null and instance.mesh.resource_path != "":
			return instance.mesh.resource_path
		# A rig arrives as a PackedScene, so the mesh has no path of its own —
		# fall back to the scene file the instance came out of.
		var owner_scene := instance.owner
		if owner_scene != null and owner_scene.scene_file_path != "":
			return owner_scene.scene_file_path
	return ""
