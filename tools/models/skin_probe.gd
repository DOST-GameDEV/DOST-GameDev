extends SceneTree

## Every roster skin loads, is the right size, and brings its texture with it.
##
##     godot --headless -s tools/models/skin_probe.gd
##
## ⚠️ THIS IS THE "DOES THE CHARACTER SCREEN LIE" GATE. 🧑 2026-08-01: *"make sure
## other models of slippers actually work if we switch to them in char select"*.
## A skin is a MESH as well as a tint since this session, so there are now four
## ways a pick can be broken that a tint never could be: the path can be wrong,
## the mesh can fail to import, it can come in at the wrong scale, or its texture
## can be missing while the mesh loads fine. Every one of those renders as
## "the game looks broken" and none of them raises an error at startup.
##
## Exits non-zero on any failure, so it can be re-run after touching a roster
## entry, a generator, or the footwear converter.

## Every slipper is normalised to this by the two builders, times
## `TsinelasVisual.tscn`'s 1.6 — the world length `HIT_RADIUS` is quoted against.
const SLIPPER_MESH_LENGTH: float = 0.432
## The cans vary on purpose (Agent_Prompts.md §5.3) but all sit in this band.
const CAN_MIN_HEIGHT: float = 0.34
const CAN_MAX_HEIGHT: float = 0.42
## How far a mesh may miss its nominal size before it counts as wrong.
const TOLERANCE: float = 0.02

func _initialize() -> void:
	var failures := 0
	print("skin probe — every CANS / SLIPPERS entry")

	print("  CANS")
	for entry in CharacterRoster.CANS:
		failures += _check(entry, true)
	print("  SLIPPERS")
	for entry in CharacterRoster.SLIPPERS:
		failures += _check(entry, false)

	if failures > 0:
		print("FAIL: %d skin(s) broken" % failures)
		quit(1)
		return
	print("PASS: every skin loads, sizes and textures correctly")
	quit(0)

func _check(entry: Dictionary, is_can: bool) -> int:
	var name: String = String(entry.get("name", "?"))
	if not entry.has("model"):
		print("    %-18s NO `model` KEY — this skin can only ever show the default"
			% name)
		return 1
	var path: String = String(entry["model"])
	if not ResourceLoader.exists(path):
		print("    %-18s MISSING %s" % [name, path])
		return 1
	var mesh := load(path) as Mesh
	if mesh == null:
		print("    %-18s %s did not load as a Mesh" % [name, path])
		return 1

	var box := mesh.get_aabb()
	var problems: Array[String] = []

	# Size. A skin that loads but comes in at the wrong scale is the failure that
	# looks like an art problem and is really a pipeline one.
	if is_can:
		if box.size.y < CAN_MIN_HEIGHT or box.size.y > CAN_MAX_HEIGHT:
			problems.append("height %.3f outside %.2f..%.2f"
				% [box.size.y, CAN_MIN_HEIGHT, CAN_MAX_HEIGHT])
	else:
		if absf(box.size.z - SLIPPER_MESH_LENGTH) > TOLERANCE:
			problems.append("length %.3f, expected %.3f"
				% [box.size.z, SLIPPER_MESH_LENGTH])
		# A slipper wider than it is long is two slippers — the pair-split failed.
		if box.size.x > box.size.z * 0.75:
			problems.append("width %.3f vs length %.3f — is this still a PAIR?"
				% [box.size.x, box.size.z])

	# ⚠️ THE TEXTURE IS CHECKED SEPARATELY FROM THE MESH, because a `map_Kd`
	# pointing at a file that does not exist imports SILENTLY: the mesh is fine and
	# the prop just renders untextured, which reads as a lighting bug.
	var mtl := path.replace(".obj", ".mtl")
	if FileAccess.file_exists(mtl):
		var text := FileAccess.get_file_as_string(mtl)
		for line in text.split("\n"):
			if not line.begins_with("map_Kd "):
				continue
			var rel := line.substr(7).strip_edges()
			var texture := path.get_base_dir() + "/" + rel
			if not ResourceLoader.exists(texture):
				problems.append("texture missing: %s" % texture)

	# Tint. White is the "this skin brings its own look" contract both props read.
	if not entry.has("tint"):
		problems.append("no `tint` key")

	if problems.is_empty():
		print("    %-18s OK   L %.3f  W %.3f  H %.3f"
			% [name, box.size.z, box.size.x, box.size.y])
		return 0
	print("    %-18s FAIL %s" % [name, ", ".join(problems)])
	return 1
