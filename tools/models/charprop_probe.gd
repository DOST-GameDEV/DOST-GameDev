extends Node

const CHARACTER_SELECT := "res://scenes/ui/CharacterSelect.tscn"

var _out: String = ""
var _screen: Control = null
var _preview: CharacterPreview = null
var _jobs: Array[Dictionary] = []
var _job: int = 0
var _settle: int = 0
var _fails: PackedStringArray = []
var _log: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("out="):
			_out = text.substr(4)
	if _out == "":
		_out = ProjectSettings.globalize_path("user://")

	_screen = load(CHARACTER_SELECT).instantiate() as Control
	add_child(_screen)
	await get_tree().process_frame
	_preview = _screen.get_node_or_null("%CharacterPreview") as CharacterPreview
	if _preview == null:
		_emit("FAIL: CharacterSelect.tscn has no %CharacterPreview node")
		_finish()
		return

	for entry in CharacterRoster.CANS:
		_jobs.append({"entry": entry, "kind": "can"})
	for entry in CharacterRoster.SLIPPERS:
		_jobs.append({"entry": entry, "kind": "slipper"})
	_emit("=== CHARACTER SCREEN — %d prop skins ===" % _jobs.size())
	_begin_job()


func _begin_job() -> void:
	if _job >= _jobs.size():
		_finish()
		return
	var job := _jobs[_job]
	var entry: Dictionary = job["entry"]
	_preview.show_prop(entry, String(job["kind"]) == "can")
	_settle = 3


func _process(_delta: float) -> void:
	if _job >= _jobs.size() or _preview == null:
		return
	if _settle > 0:
		_settle -= 1
		return
	await RenderingServer.frame_post_draw
	_check_job()
	_job += 1
	_begin_job()


func _check_job() -> void:
	var job := _jobs[_job]
	var entry: Dictionary = job["entry"]
	var label := "%-8s %-18s" % [String(job["kind"]).to_upper(), String(entry["name"])]
	var want := String(entry.get("model", ""))

	var shown := PackedStringArray()
	var current: Node3D = _preview._current
	if current != null and is_instance_valid(current):
		for node in current.find_children("*", "MeshInstance3D", true, false):
			var instance := node as MeshInstance3D
			if instance.mesh != null:
				shown.append(instance.mesh.resource_path)

	if want == "":
		_fail(label, "roster entry has no `model` key")
	elif shown.is_empty():
		_fail(label, "the preview is showing no mesh at all")
	elif not (want in shown):
		_fail(label, "showing %s, roster says %s" % [", ".join(shown), want])
	else:
		_emit("  PASS  %s  %s" % [label, want.get_file()])

	var image := get_viewport().get_texture().get_image()
	var path := "%scharprop_%s_%s.png" % [_out, String(job["kind"]), String(entry["id"])]
	if image.save_png(path) != OK:
		push_error("charprop_probe: could not write " + path)


func _fail(label: String, why: String) -> void:
	_emit("  FAIL  %s  %s" % [label, why])
	_fails.append(label.strip_edges())


func _emit(text: String) -> void:
	print(text)
	_log.append(text)


func _finish() -> void:
	set_process(false)
	_emit("")
	if _fails.is_empty():
		_emit("CHARPROP PROBE: every skin previews its own mesh")
	else:
		_emit("CHARPROP PROBE: %d FAIL — %s" % [_fails.size(), ", ".join(_fails)])
	_emit("frames written to " + _out)
	var file := FileAccess.open("user://charprop_probe.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	get_tree().quit(0 if _fails.is_empty() else 1)

