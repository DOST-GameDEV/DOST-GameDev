extends Node

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


func _loaded_model(who: CharacterBase) -> String:
	var visual := who.get_node_or_null("Visual") as Node3D
	if visual == null:
		return ""
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh != null and instance.mesh.resource_path != "":
			return instance.mesh.resource_path
		var owner_scene := instance.owner
		if owner_scene != null and owner_scene.scene_file_path != "":
			return owner_scene.scene_file_path
	return ""

