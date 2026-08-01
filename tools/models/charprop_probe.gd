extends Node
## DOES THE CHARACTER SCREEN SHOW THE SKIN YOU ACTUALLY PICKED?
##
##     godot --path . tools/models/charprop_probe.tscn -- out=C:/tmp/
##
## ⚠️ NOT `--headless` — it renders, and a headless capture comes back blank.
##
## `skin_probe.gd` already gates the ROSTER side: every `model` path exists,
## loads, and is the right size. This gates the SCREEN side, which is a
## different question and has been wrong before: `character_preview.gd`
## instantiated the SHARED `CanVisual`/`TsinelasVisual` scene and only
## recoloured it, so every lata previewed as the same can and every tsinelas as
## the same slipper (§ LOG, 2026-08-01, bug 1). `_apply_model()` was added to fix
## that and has never been verified by anything but eye.
##
## ⚠️ IT COMPARES MESH PATHS, IT DOES NOT JUST TAKE A PICTURE. A screenshot
## proves something rendered; it does not prove it rendered the RIGHT can, and
## four cans that all look like cans is exactly the failure that survived a look.
## So for every entry this asserts that the `MeshInstance3D` the preview is
## actually showing carries the mesh `CharacterRoster` names for it — the same
## comparison the eye cannot make reliably at 250 px.
##
## The PNGs are still written, because "it is the right mesh" and "it is framed
## and lit so a player can tell" are two different claims and the second one
## needs a human to look.

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

	# Every prop skin, in the order the picker cycles them. The Persons are in the
	# same screen and are checked the same way — `show_character()` has its own
	# path to get wrong and `person_lineup_shot` only ever covered the palette.
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
	# ⚠️ SETTLE BEFORE MEASURING AND BEFORE CAPTURING. `show_prop()` adds the model
	# to the tree and `_frame()` reads `global_transform`, which is only correct
	# once the tree has processed — and the SubViewport needs a frame to draw at
	# all. Two frames rather than one, because the container's own `resized`
	# re-frame lands on the frame after the add.
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


## The assertion. Walks whatever the preview is currently showing and compares
## the mesh it holds against the roster entry's `model` path.
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
		# ⚠️ THE FAILURE THIS FILE EXISTS FOR. A wrong-but-present mesh renders
		# perfectly and looks like art, not like a bug.
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
