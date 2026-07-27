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
const EnvKit = preload("res://tools/models/env_kit.gd")

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
	_build_tsinelas()
	# Checklist 2.1b — the environment kit, built to docs/Environment_Kit_Spec.md.
	# In its own file because it is ~25 pieces and this one is where a reader goes
	# to understand the five PROP meshes; burying those under the scenery would be
	# a net loss. Same rules apply to it — determinism, UiTheme constants, and no
	# OFFENSE or DEFENSE hue anywhere on a map.
	EnvKit.new().build_all(OUTPUT_DIR)
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

# --- Tsinelas (the slipper) ---------------------------------------------------
#
# Orientation: character faces -Z; toe is at Z = -0.675, heel at Z = +0.675.
# Length: 1.35 units (centered, Z in [-0.675, +0.675]). X is width.
#
# ⚠️ B-81 — WHY THE SOLE IS NOT BLUE, so nobody "restores" it.
#
# The sole used to be UiTheme.DEFENSE, and Design_Agent_Brief.md §2's palette
# table told it to be. Both were wrong. A Prop is a Tsinelas exactly when its
# team is on OFFENCE (carriable.gd::is_throwable — not a Person, not a Can), so
# a blue sole painted the ATTACKING team's prop in the DEFENDING colour. That
# breaks Dev_Plan.md §4.2's hard rule directly: a player has to be able to learn
# one colour pair and read every screen, and the slipper is the most-looked-at
# object in the game. The moodboard agrees independently — THE SLIPPER's card
# accent is magenta, and §4.2's own token table lists IMPACT as the
# "Slipper/Can accent".
#
# So: IMPACT sole, HIGHLIGHT straps, INK toe post. Neither role hue appears.
#
# ⚠️ The materials are named for the PART, not for the palette token. That is
# deliberate and it is the second half of the fix: a material literally called
# "defense" is a bug that reads as correct in every diff. The lata still names
# its materials after tokens; it is not renamed here only because its colours
# are unchanged and renaming would churn four .obj files for nothing.
#
# ⚠️ Renaming the materials also changes the .obj, which is what forces Godot to
# reimport. obj_writer.gd's header warns that the .mtl is NOT in the .obj's
# [deps], so a colour-only change rewrites the .mtl and the engine keeps serving
# the OLD colours from its cache — you would measure the previous values and
# conclude the fix did nothing.

## Sole outline is 12 points, CCW in the XZ plane viewed from above (+Y).
## CCW from above means the right side runs toe->heel (+Z), and the left
## side runs heel->toe (-Z), completing the loop at the toe tip.
## Width profile: ±0.26 at ball, ±0.18 waisted at arch, ±0.22 at heel.
func _build_tsinelas() -> void:
	var writer := ObjWriter.new("Tsinelas")
	writer.set_material("sole", UiTheme.IMPACT)
	writer.set_material("strap", UiTheme.HIGHLIGHT)
	writer.set_material("post", UiTheme.INK)

	# --- Sole ---
	# 12-point CCW outline in (x, z) — side walls face outward, caps correct.
	var sole_outline := PackedVector2Array([
		Vector2( 0.10, -0.620),  #  1  toe-right
		Vector2( 0.26, -0.300),  #  2  ball-right (widest, ±0.26)
		Vector2( 0.18,  0.050),  #  3  arch-right (waisted, ±0.18)
		Vector2( 0.22,  0.500),  #  4  heel-right (±0.22)
		Vector2( 0.10,  0.650),  #  5  heel-tip-right (rounds the heel)
		Vector2( 0.00,  0.675),  #  6  heel-tip center
		Vector2(-0.10,  0.650),  #  7  heel-tip-left (rounds the heel)
		Vector2(-0.22,  0.500),  #  8  heel-left
		Vector2(-0.18,  0.050),  #  9  arch-left
		Vector2(-0.26, -0.300),  # 10  ball-left
		Vector2(-0.10, -0.620),  # 11  toe-left
		Vector2( 0.00, -0.675),  # 12  toe-tip center
	])
	writer.add_extrude(sole_outline, 0.0, 0.10, "sole")

	# --- Toe post ---
	# Small cylindrical knob between the toes, sitting on top of the sole.
	# 8-point circle at (x=0, z=-0.55), extruded y=0.10 to y=0.165.
	# CCW from above (angle increases CCW in XZ) keeps side walls facing out.
	var post_cx: float = 0.0
	var post_cz: float = -0.55
	var post_r: float = 0.045
	var post_segs: int = 8
	var post_outline := PackedVector2Array()
	for i in range(post_segs):
		var angle: float = TAU * float(i) / float(post_segs)
		post_outline.append(Vector2(post_cx + post_r * cos(angle),
		                            post_cz + post_r * sin(angle)))
	writer.add_extrude(post_outline, 0.10, 0.165, "post")

	# --- Y-straps ---
	# Two diagonal ribbon quads from the toe post to the arch sides.
	# Top face only — thin enough to read at TPP distance without side faces.
	# Perpendicular vector = 90-deg CCW rotation of the strap direction in XZ,
	# which makes add_quad(a, b, c, d) emit a face whose normal is +Y.
	var strap_y: float = 0.10
	var W: float = 0.03  # strap half-width

	# Right strap: post (0, -0.55) -> arch-right (0.22, -0.05) in XZ.
	var rpost := Vector2(0.0, -0.55)
	var rside := Vector2(0.22, -0.05)
	var rdir := (rside - rpost).normalized()
	var rperp := Vector2(-rdir.y, rdir.x)  # 90 deg CCW keeps normal pointing +Y
	var ra0 := Vector3(rpost.x + rperp.x * W, strap_y, rpost.y + rperp.y * W)
	var rb0 := Vector3(rpost.x - rperp.x * W, strap_y, rpost.y - rperp.y * W)
	var ra1 := Vector3(rside.x + rperp.x * W, strap_y, rside.y + rperp.y * W)
	var rb1 := Vector3(rside.x - rperp.x * W, strap_y, rside.y - rperp.y * W)
	writer.add_quad(ra0, ra1, rb1, rb0, "strap")

	# Left strap: mirror of right.
	var lpost := Vector2(0.0, -0.55)
	var lside := Vector2(-0.22, -0.05)
	var ldir := (lside - lpost).normalized()
	var lperp := Vector2(-ldir.y, ldir.x)
	var la0 := Vector3(lpost.x + lperp.x * W, strap_y, lpost.y + lperp.y * W)
	var lb0 := Vector3(lpost.x - lperp.x * W, strap_y, lpost.y - lperp.y * W)
	var la1 := Vector3(lside.x + lperp.x * W, strap_y, lside.y + lperp.y * W)
	var lb1 := Vector3(lside.x - lperp.x * W, strap_y, lside.y - lperp.y * W)
	writer.add_quad(la0, la1, lb1, lb0, "strap")

	writer.recalculate_normals(40.0)
	writer.write(OUTPUT_DIR + "tsinelas")
	print("  tsinelas")
