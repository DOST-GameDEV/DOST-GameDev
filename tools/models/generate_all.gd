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
## Look at what you made:
##     godot --path . res://tools/models/preview.tscn -- --model=res://assets/models/lata.obj

const ObjWriter = preload("res://tools/models/obj_writer.gd")

const OUTPUT_DIR: String = "res://assets/models/"

## 16 reads as round at the ~4.5-unit TPP camera distance while staying cheap.
## 12 is visibly polygonal on a shape this smooth; 24 is spent for nothing.
const REVOLVE_SEGMENTS: int = 16

# --- Lata (the can) -----------------------------------------------------------
#
# Dimensions match the CanVisual.tscn primitive stack this replaces (~1.13 tall,
# 0.34 radius) so CharacterBase's capsule, its CollisionShape3D and
# CharacterVisual._align_to_capsule_floor() all keep working untouched. Changing
# the silhouette is this task's job; changing the footprint is not.

const LATA_RADIUS: float = 0.34
func _initialize() -> void:
	_build_lata("lata", [])
	# Option A's three dent stages. Fixed angles and depths, never random — a
	# generator that rolled dice would fail the determinism test on run two.
	#
	# These are tuned to be legible AT THE 4.5-UNIT TPP CAMERA DISTANCE, which is
	# the only distance that matters: the dent count IS the health bar under
	# Option A, so a player who cannot count them at a glance has no health bar.
	# The first attempt used a 1.1-radian half-arc spread over most of the wall
	# height and rendered as an almost invisible taper — deep enough in the
	# numbers, far too diffuse to read as damage. Localised and deepened here.
	_build_lata("lata_dent1", [
		{"angle": 0.0, "y": 0.52, "depth": 0.105},
	])
	_build_lata("lata_dent2", [
		{"angle": 0.0, "y": 0.52, "depth": 0.115},
		{"angle": 2.4, "y": 0.38, "depth": 0.100},
	])
	_build_lata("lata_dent3", [
		{"angle": 0.0, "y": 0.52, "depth": 0.125},
		{"angle": 2.4, "y": 0.38, "depth": 0.115},
		{"angle": 4.4, "y": 0.68, "depth": 0.105},
	])
	print("Model generation complete.")
	quit(0)

## One can. `dents` is a list of {angle, depth}; empty builds the pristine one.
##
## Built as five stacked revolves rather than one, purely so the wall can carry
## three different materials — the moodboard's lata is a blue body with a yellow
## label band and a dark rim. Adjacent sub-profiles share their boundary ring, and
## ObjWriter welds on the printed coordinate, so the seams close exactly.
func _build_lata(file_name: String, dents: Array) -> void:
	var writer := ObjWriter.new("Lata")
	writer.set_material("ink", UiTheme.INK)
	writer.set_material("defense", UiTheme.DEFENSE)
	writer.set_material("highlight", UiTheme.HIGHLIGHT)

	var deform := Callable()
	if not dents.is_empty():
		deform = func(radius: float, y: float, angle: float) -> float:
			return _apply_dents(radius, y, angle, dents)

	# Base: a concave dome lifted off the floor by a crimp ring, which is what
	# makes a can read as a can rather than as a tube — the contact shadow sits
	# on a ring, not a disc.
	writer.add_revolve(PackedVector2Array([
		Vector2(0.000, 0.055),
		Vector2(0.180, 0.025),
		Vector2(0.265, 0.000),
		Vector2(0.315, 0.035),
	]), REVOLVE_SEGMENTS, "ink", true, deform)

	# Lower wall, flaring from the crimp out to full radius.
	writer.add_revolve(PackedVector2Array([
		Vector2(0.315, 0.035),
		Vector2(LATA_RADIUS, 0.075),
		Vector2(LATA_RADIUS, 0.330),
	]), REVOLVE_SEGMENTS, "defense", true, deform)

	# Label band.
	writer.add_revolve(PackedVector2Array([
		Vector2(LATA_RADIUS, 0.330),
		Vector2(LATA_RADIUS, 0.680),
	]), REVOLVE_SEGMENTS, "highlight", true, deform)

	# Upper wall.
	writer.add_revolve(PackedVector2Array([
		Vector2(LATA_RADIUS, 0.680),
		Vector2(LATA_RADIUS, 0.950),
	]), REVOLVE_SEGMENTS, "defense", true, deform)

	# Shoulder, rolled rim, and the recessed lid. The rim rolls OVER: y goes up
	# to 1.125 and then back down to 1.100 as the profile turns inward, which is
	# why the profile is not monotonic in height.
	writer.add_revolve(PackedVector2Array([
		Vector2(LATA_RADIUS, 0.950),
		Vector2(0.315, 1.020),
		Vector2(0.285, 1.075),
		Vector2(0.300, 1.105),
		Vector2(0.272, 1.125),
		Vector2(0.255, 1.100),
		Vector2(0.000, 1.115),
	]), REVOLVE_SEGMENTS, "ink", true, deform)

	# Smooth by angle, always — not only for the dented variants. The analytic
	# normals are per-sub-profile, so without this the boundary rings between the
	# five revolves above shade as visible bands around the can.
	writer.recalculate_normals(40.0)
	writer.write(OUTPUT_DIR + file_name)
	print("  ", file_name)

## Half-width of a dent in radians (~34 degrees each side) and half its height.
## Both deliberately small: a crumple is local damage, and a wide shallow dimple
## reads as a manufacturing taper rather than as a hit that landed.
const DENT_ARC: float = 0.60
const DENT_REACH: float = 0.22
## Sharpens the cosine falloff. 1.0 is a plain raised cosine — smooth, but so
## gradual that the deepest point is the only part that visibly moves. Squaring
## it keeps the rim of the dent shallow and drops the middle out fast, which is
## what gives a readable crease at gameplay distance.
const DENT_SHARPNESS: float = 2.0

## Pushes a localised wedge of wall inward. Returns `radius` untouched outside
## the dent's band, which is what keeps the base crimp and the rolled rim welded
## to the wall — the deform is applied to every segment of the can, so a falloff
## that reached the rigid geometry would tear the mesh open at the seam.
func _apply_dents(radius: float, y: float, angle: float, dents: Array) -> float:
	var result := radius
	for dent in dents:
		# Wrap into [-PI, PI] so a dent centred near 0 still bites at TAU - 0.1.
		var delta: float = fposmod(angle - float(dent["angle"]) + PI, TAU) - PI
		if absf(delta) > DENT_ARC:
			continue
		var y_delta: float = (y - float(dent["y"])) / DENT_REACH
		if absf(y_delta) > 1.0:
			continue
		var falloff_angle := pow(0.5 * (1.0 + cos(PI * delta / DENT_ARC)), DENT_SHARPNESS)
		var falloff_height := pow(0.5 * (1.0 + cos(PI * y_delta)), DENT_SHARPNESS)
		result -= float(dent["depth"]) * falloff_angle * falloff_height
	return result
