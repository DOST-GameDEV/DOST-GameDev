extends SceneTree

## Regenerates every generated mesh in assets/models/ (Handoff.md §4, M- block).
##
##     godot --headless -s tools/models/generate_all.gd
##
## THE ACCEPTANCE TEST FOR THIS FILE IS DETERMINISM: run it twice and
## `git status` must be clean after the second run. If it is not, the generator
## is non-deterministic and every future model commit will carry noise that
## nobody can review — see the rules in obj_writer.gd's header before adding a
## `_build_*` function here.
##
## Add one `_build_*()` per asset and call it from `_initialize()`. Colours come
## from `UiTheme` constants, never retyped hex, so the models and the UI palette
## cannot drift apart (Dev_Plan.md §4.2).
##
## Meshes that a Godot primitive genuinely nails stay as primitive composites in
## a `.tscn` — this file is only for the shapes primitives cannot express. See
## the M- block header in Handoff.md for that split.

const ObjWriter = preload("res://tools/models/obj_writer.gd")

const OUTPUT_DIR: String = "res://assets/models/"

## How many segments a revolved shape gets. 12 reads as visibly polygonal at
## the ~4.5-unit TPP camera distance; 24 is wasted on objects this small.
const REVOLVE_SEGMENTS: int = 16

func _initialize() -> void:
	_build_proof_cylinder()
	print("Model generation complete.")
	quit(0)

## M-1 step 5: the smallest shape that exercises every code path — a revolve
## with both caps collapsed to the axis, smooth wall normals, and a material
## read from UiTheme. Proves the toolchain end to end (write → import → render)
## before any real asset depends on it.
##
## DELETE THIS once M-2 lands; it is scaffolding, not an asset.
func _build_proof_cylinder() -> void:
	var writer := ObjWriter.new("ProofCylinder")
	writer.set_material("defense", UiTheme.DEFENSE)
	# (radius, height), bottom to top. The two axis points are what turn the
	# end segments into flat caps rather than open ends.
	var profile := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(0.5, 0.0),
		Vector2(0.5, 1.0),
		Vector2(0.0, 1.0),
	])
	writer.add_revolve(profile, 12, "defense")
	writer.write(OUTPUT_DIR + "proof_cylinder")
	print("  proof_cylinder")
