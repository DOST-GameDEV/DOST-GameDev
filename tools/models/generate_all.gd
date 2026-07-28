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
# ⚠️ Art_Direction.md §1 — the proportion audit. This profile used to build a can
# 1.125 units tall against a real 0.12m can (9.3x oversized) — taller than the
# 0.89-unit monobloc chair standing next to it. LATA_SCALE brings it down to the
# audit's target of 0.30x, landing at ~0.34 units tall, WITHOUT touching a single
# profile coordinate below: it is applied as a post-deform `transform` on every
# add_revolve call (the 2.1b-0 parameter), so the dent maths, which is tuned
# against the UNSCALED radius/y values, is completely unaffected. CharacterBase's
# collision no longer assumes a fixed prop footprint at all — see
# character_base.gd::_apply_role_collision() — so this is safe to change alone.
const LATA_RADIUS: float = 0.34
const LATA_SCALE: float = 0.30

## The lid plane, and how far across it the flat part runs.
##
## ⚠️ FLAT, NOT DOMED, and that is a placement constraint rather than a styling
## one. The lid used to rise from 1.100 at the rim to 1.115 at the centre. The
## pull tab is a flat piece lying ON this plane and reaching out to x = 0.223, so
## against a domed lid its far end would have hung ~0.015 clear of the surface —
## Art_Direction.md Part 4's floating-geometry rule, in miniature, on the one
## surface a knocked-down can shows the camera. A flat lid makes contact true at
## every radius the tab reaches instead of only at its centre.
const LATA_LID_Y: float = 1.098
const LATA_LID_RADIUS: float = 0.250

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
	_build_viewmodel_arm()
	# Checklist 2.1b — the environment kit, built to docs/Art_Direction.md.
	# In its own file because it is ~25 pieces and this one is where a reader goes
	# to understand the five PROP meshes; burying those under the scenery would be
	# a net loss. Same rules apply to it — determinism, UiTheme constants, and no
	# OFFENSE or DEFENSE hue anywhere on a map.
	EnvKit.new().build_all(OUTPUT_DIR)
	print("Model generation complete.")
	quit(0)

## One can. `dents` is a list of {angle, depth}; empty builds the pristine one.
##
## ⚠️ SARSI LIVERY — 2026-07-28. This used to be a blue body with a yellow label
## band and a near-black rim, which was the abstract "a can" the first moodboard
## record described. The human supplied an asset moodboard of a
## **Sarsi** can — the Philippine sarsaparilla a real tumbang preso is actually
## played with — and asked for it by name: *"u can reproduce sarsi logo, we have
## to showcase PH in this project, js give credits."* Credit is recorded in
## `docs/Art_Direction.md` Part 2 and `docs/README.md`; Sarsi is a trademark of
## its owner and is used here as homage, not endorsement.
##
## Base, shoulder and lid are stacked revolves, as before. The printed wall
## between them is `_lata_wall()` and is NOT a revolve — see that function.
## Adjacent sub-profiles share their boundary ring, and ObjWriter welds on the
## printed coordinate, so every seam closes exactly.
func _build_lata(file_name: String, dents: Array) -> void:
	var writer := ObjWriter.new("Lata")
	# Named for the PART, not for the palette token — the same rule the tsinelas
	# adopted in B-81, and the reason its old `defense`/`highlight` names are gone.
	# A material called "defense" on the can's LABEL is a bug that reads as correct
	# in every diff.
	writer.set_material("aluminium", UiTheme.PANEL)
	writer.set_material("aluminium_shade", UiTheme.PANEL.darkened(0.30))
	writer.set_material("body_deep", UiTheme.DEFENSE.darkened(0.30))
	writer.set_material("body", UiTheme.DEFENSE)
	# The moodboard's can is a vertical cyan-to-blue gradient. Flat-colour .mtl
	# cannot gradient, so it is BANDED instead — bright low, mid, deep at the
	# shoulder. At the 4.5-unit TPP distance three bands read as a gradient and
	# cost nothing, which is the same trade the painted facades already make.
	writer.set_material("body_bright", UiTheme.DEFENSE.lightened(0.24))
	writer.set_material("wave", UiTheme.CARD)
	writer.set_material("sail", UiTheme.PROP_SARSI_RED)

	var deform := Callable()
	if not dents.is_empty():
		deform = func(radius: float, y: float, angle: float) -> float:
			return _apply_dents(radius, y, angle, dents)

	# LATA_SCALE applied as a post-deform transform (2.1b-0), not by touching the
	# profile coordinates: `deform` still runs against the UNSCALED radius/y, so
	# every dent number above stays valid at its originally-tuned depth, and only
	# the final emitted vertex shrinks. See the header comment above this function.
	var scale_xf := Transform3D.IDENTITY.scaled(Vector3.ONE * LATA_SCALE)

	# Base: a concave dome lifted off the floor by a crimp ring, which is what
	# makes a can read as a can rather than as a tube — the contact shadow sits
	# on a ring, not a disc.
	writer.add_revolve(PackedVector2Array([
		Vector2(0.000, 0.055),
		Vector2(0.180, 0.025),
		Vector2(0.265, 0.000),
		Vector2(0.315, 0.035),
	]), REVOLVE_SEGMENTS, "aluminium_shade", true, deform, scale_xf)

	# Lower wall, flaring from the crimp out to full radius. Deep blue, so the
	# bright body above it lifts off a shadow line at the base.
	writer.add_revolve(PackedVector2Array([
		Vector2(0.315, 0.035),
		Vector2(LATA_RADIUS, LATA_WALL_BOTTOM),
	]), REVOLVE_SEGMENTS, "body_deep", true, deform, scale_xf)

	# The printed wall — everything between the base flare and the shoulder.
	_lata_wall(writer, deform, scale_xf)

	# Shoulder, rolled rim, and the flat lid. The rim rolls OVER: y goes up to
	# 1.118 and then back down to the lid plane as the profile turns inward, which
	# is why the profile is not monotonic in height.
	writer.add_revolve(PackedVector2Array([
		Vector2(LATA_RADIUS, LATA_WALL_TOP),
		Vector2(0.315, 1.020),
	]), REVOLVE_SEGMENTS, "body_deep", true, deform, scale_xf)
	writer.add_revolve(PackedVector2Array([
		Vector2(0.315, 1.020),
		Vector2(0.290, 1.070),
		Vector2(0.305, 1.100),
		Vector2(0.272, 1.118),
		Vector2(LATA_LID_RADIUS, LATA_LID_Y),
		Vector2(0.000, LATA_LID_Y),
	]), REVOLVE_SEGMENTS, "aluminium", true, deform, scale_xf)

	_lata_pull_tab(writer, scale_xf)

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

# --- The lata's printed wall --------------------------------------------------
#
# ⚠️ WHY THIS IS NOT A REVOLVE, so nobody "simplifies" it back into one.
#
# `add_revolve` paints ONE material per sub-profile, and a sub-profile is a full
# 360-degree ring — so it can express a horizontal BAND and nothing else. That was
# fine for a yellow label band. It cannot express Sarsi's mark, which is a sail:
# a triangle across about a third of the circumference, a red ball beside it, and
# a wavy white band beneath. None of those are rotationally symmetric.
#
# ⚠️ AND WHY IT IS NOT DECALS ON TOP OF A PLAIN WALL, which is the obvious other
# answer and is the wrong one HERE for a specific reason: this wall gets DENTED.
# `_apply_dents` pushes a wedge of it inward, and a decal shell offset a couple of
# millimetres off the surface does not move with it — the first dent would shear
# the sail off the can and leave it hanging in the air over the crease. That is
# the floating-geometry failure of Art_Direction.md Part 4 arriving through a side
# door, on the one prop in the game whose whole job is to get hit.
#
# So the sail IS the wall, in a different colour. The wall is emitted strip by
# strip as STACKED LAYERS SHARING BOUNDARY FUNCTIONS:
#
#   - Nothing is offset off the surface, so nothing can float, z-fight or shear.
#     Every layer runs through the same `deform` as the geometry around it, so a
#     dent through the sail dents the sail.
#   - Two neighbouring layers read their shared edge from the SAME function at the
#     SAME angle, so they weld on the printed coordinate and no seam can open.
#   - A layer may be degenerate (bottom == top) at a given angle. That is how the
#     sail and the ball stop existing outside their arc without the layers above
#     them needing to know anything about them.

const LATA_WALL_BOTTOM: float = 0.075
const LATA_WALL_TOP: float = 0.950
## Where the printed face points, in the revolve's own angle space.
##
## The Can has no canonical facing in play — it spends the match being knocked
## over and reset — so this angle is free, and it is spent on making the livery
## REVIEWABLE: `preview.gd`'s camera is fixed on the (1, 0.7, 1) diagonal, so
## pointing the label down that same bearing is what puts the sail and the ball in
## frame together in a preview shot. Any other value renders half the mark facing
## away from every screenshot anyone will ever take of it.
const LATA_LABEL_FACE: float = PI / 4.0

## The bright skirt under the wave.
const SKIRT_TOP_Y: float = 0.150

## The wavy white band low on the can. `sin` of the angle, so it closes seamlessly
## around it — a non-integer lobe count would not.
const WAVE_Y: float = 0.240
const WAVE_AMPLITUDE: float = 0.034
const WAVE_LOBES: float = 4.0

## The sail. Half-arc 1.35 rad is ~43% of the circumference, which is roughly what
## the moodboard's label occupies and, at REVOLVE_SEGMENTS = 16, is a shade under
## seven strips — enough to read the diagonal as a diagonal rather than a stair.
##
## ⚠️ TALL. The first pass ran 0.430 to 0.690 on an 0.875-high wall — 30% of it —
## and rendered as a red smear low on the body rather than as a sail, with a slab
## of navy above it taking the space the mark should have had. Sarsi's sail is the
## dominant feature of that can and has to be sized like it: base just above the
## wave, apex just under the shoulder, ~57% of the wall.
const SAIL_HALF_ARC: float = 1.35
const SAIL_BASE_Y: float = 0.330
const SAIL_APEX_Y: float = 0.830
## Where along the arc the apex sits. Positive puts the tall near-vertical edge on
## the trailing side, which is the way Sarsi's sail leans.
const SAIL_PEAK_T: float = 0.55

## The red ball, up and to the leading side of the sail — where the sail's own
## edge is still low, which is what leaves room for it.
const BALL_FROM_T: float = -0.88
const BALL_TO_T: float = -0.42
const BALL_BOTTOM_Y: float = 0.600
const BALL_TOP_Y: float = 0.760
const BODY_TOP_Y: float = 0.845

## One entry per layer, bottom to top — so exactly one fewer than the number of
## boundaries `_lata_wall_stops` returns. Kept beside that function: the two are a
## matched pair and editing either alone silently repaints the can.
const LATA_WALL_MATERIALS := [
	"body_bright",   # skirt, below the wave
	"wave",          # the wavy white band
	"body_bright",   # the bright lower body the sail sits on
	"sail",          # the sail
	"body",          # body, between sail and ball
	"sail",          # the ball
	"body",          # body, above the ball
	"body_deep",     # the darker band under the shoulder
]

## Below this a layer counts as degenerate at that corner and collapses.
const LAYER_EPSILON: float = 0.0005

func _lata_wall(writer: ObjWriter, deform: Callable, scale_xf: Transform3D) -> void:
	for s in range(REVOLVE_SEGMENTS):
		var a0 := TAU * float(s) / float(REVOLVE_SEGMENTS)
		var a1 := TAU * float(s + 1) / float(REVOLVE_SEGMENTS)
		var stops0 := _lata_wall_stops(a0)
		var stops1 := _lata_wall_stops(a1)
		for layer in range(LATA_WALL_MATERIALS.size()):
			var material: String = LATA_WALL_MATERIALS[layer]
			var flat0: bool = absf(stops0[layer + 1] - stops0[layer]) < LAYER_EPSILON
			var flat1: bool = absf(stops1[layer + 1] - stops1[layer]) < LAYER_EPSILON
			if flat0 and flat1:
				continue
			# ⚠️ Corner order is add_revolve's, exactly: bottom@a0, top@a0, top@a1,
			# bottom@a1. See obj_writer.gd's winding note before touching it — the
			# familiar counter-clockwise test reports every face here as inverted
			# and that is the correct result, not a bug.
			var v00 := scale_xf * _lata_wall_point(stops0[layer], a0, deform)
			var v01 := scale_xf * _lata_wall_point(stops0[layer + 1], a0, deform)
			var v11 := scale_xf * _lata_wall_point(stops1[layer + 1], a1, deform)
			var v10 := scale_xf * _lata_wall_point(stops1[layer], a1, deform)
			# A layer degenerate at ONE end is a triangle and has to be emitted as
			# one. Handing it to add_quad prints a zero-area face, and that face's
			# meaningless normal then pollutes recalculate_normals()' average for
			# every vertex it touches — a shading bug with no visible geometry to
			# trace it back to.
			if flat0:
				writer.add_tri(v00, v11, v10, material)
			elif flat1:
				writer.add_tri(v00, v01, v11, material)
			else:
				writer.add_quad(v00, v01, v11, v10, material)

## The nine layer boundaries of the printed wall at one angle, bottom to top.
##
## ⚠️ MUST BE NON-DECREASING at every angle, or a layer inverts and renders
## inside-out. The constants above are chosen so it is: the wave tops out at 0.356
## below the sail's 0.430 base, and the sail's arc and the ball's do not overlap,
## so the sail is never higher than 0.527 where the ball starts at 0.560.
func _lata_wall_stops(angle: float) -> PackedFloat64Array:
	var t := _lata_label_t(angle)
	var sail_top := SAIL_BASE_Y
	if absf(t) <= 1.0:
		if t <= SAIL_PEAK_T:
			sail_top = lerpf(SAIL_BASE_Y, SAIL_APEX_Y, (t + 1.0) / (SAIL_PEAK_T + 1.0))
		else:
			sail_top = lerpf(SAIL_APEX_Y, SAIL_BASE_Y, (t - SAIL_PEAK_T) / (1.0 - SAIL_PEAK_T))
	# Collapsed against the body's top boundary where the ball is absent, so the
	# two body layers either side of it simply meet.
	var ball_bottom := BODY_TOP_Y
	var ball_top := BODY_TOP_Y
	if t >= BALL_FROM_T and t <= BALL_TO_T:
		ball_bottom = BALL_BOTTOM_Y
		ball_top = BALL_TOP_Y
	return PackedFloat64Array([
		LATA_WALL_BOTTOM,
		SKIRT_TOP_Y,
		WAVE_Y + WAVE_AMPLITUDE * sin(WAVE_LOBES * angle),
		SAIL_BASE_Y,
		sail_top,
		ball_bottom,
		ball_top,
		BODY_TOP_Y,
		LATA_WALL_TOP,
	])

## Signed position across the label's arc: 0 at the centre of the printed face,
## +/-1 at its edges, beyond +/-1 off the label entirely. Wrapped the same way
## `_apply_dents` wraps, so a label centred near 0 still resolves at TAU - 0.1.
func _lata_label_t(angle: float) -> float:
	var delta := fposmod(angle - LATA_LABEL_FACE + PI, TAU) - PI
	return delta / SAIL_HALF_ARC

func _lata_wall_point(y: float, angle: float, deform: Callable) -> Vector3:
	var radius := LATA_RADIUS
	if deform.is_valid():
		radius = deform.call(LATA_RADIUS, y, angle)
	return Vector3(radius * cos(angle), y, radius * sin(angle))

## The lid's pull tab, worth its ~40 triangles: the game's own logo replaces the
## O of PRESO with a top-down can lid AND ITS TAB (Art_Direction.md Part 2, M-8),
## so this is a brand shape rather than a detail — and the knocked-down Can shows
## the camera its lid, which is exactly when it is most visible.
##
## Sits flat ON the lid plane; see LATA_LID_Y for why that plane is flat.
func _lata_pull_tab(writer: ObjWriter, scale_xf: Transform3D) -> void:
	const CAP_SEGMENTS: int = 5
	const TAB_RADIUS: float = 0.048
	const TAB_NEAR_X: float = 0.055
	const TAB_FAR_X: float = 0.175
	const TAB_THICKNESS: float = 0.014
	# A stadium: two half-circle caps, both swept with the angle INCREASING, which
	# is the same sense the tsinelas' toe post uses and is what add_extrude's
	# "counter-clockwise in (x, z)" means here.
	var outline := PackedVector2Array()
	for i in range(CAP_SEGMENTS + 1):
		var far_angle := -PI / 2.0 + PI * float(i) / float(CAP_SEGMENTS)
		outline.append(Vector2(TAB_FAR_X + TAB_RADIUS * cos(far_angle),
		                       TAB_RADIUS * sin(far_angle)))
	for i in range(CAP_SEGMENTS + 1):
		var near_angle := PI / 2.0 + PI * float(i) / float(CAP_SEGMENTS)
		outline.append(Vector2(TAB_NEAR_X + TAB_RADIUS * cos(near_angle),
		                       TAB_RADIUS * sin(near_angle)))
	writer.add_extrude(outline, LATA_LID_Y, LATA_LID_Y + TAB_THICKNESS,
		"aluminium_shade", scale_xf)

# --- Tsinelas (the slipper) ---------------------------------------------------
#
# Orientation: character faces -Z; toe is at Z = -0.675, heel at Z = +0.675 in
# the UNSCALED profile below (X is width). Every add_extrude/_strap_band call
# applies TSINELAS_SCALE, so the emitted mesh is 0.32x that: length 1.35 -> 0.432.
#
# ⚠️ Art_Direction.md §1 — the proportion audit. TSINELAS_SCALE is not a fresh
# number: `character_visual.gd::TSINELAS_CARRY_SCALE` was already 0.32, applied
# only while the slipper was CARRIED, and arrived at independently by rendering
# — 0.32 x 1.35 = 0.432 is exactly the audit's target. The carried slipper was
# ALREADY the right size; only the loose and flying ones (mesh at native scale
# 1.0) were the outliers. Baking 0.32 in here natively and deleting
# TSINELAS_CARRY_SCALE / _scale_while_carried() / CARRY_SCALE_LERP from
# character_visual.gd (done in the same pass) turns a per-frame runtime hack
# into nothing: the mesh just IS the right size in every carry state.
# ⚠️ B-81 — WHY THE SOLE IS NOT BLUE, so nobody "restores" it.
#
# The sole used to be UiTheme.DEFENSE, and Art_Direction.md §2's palette
# table told it to be. Both were wrong. A Prop is a Tsinelas exactly when its
# team is on OFFENCE (carriable.gd::is_throwable — not a Person, not a Can), so
# a blue sole painted the ATTACKING team's prop in the DEFENDING colour. That
# breaks Dev_Plan.md §4.2's hard rule directly: a player has to be able to learn
# one colour pair and read every screen, and the slipper is the most-looked-at
# object in the game. The moodboard agrees independently — THE SLIPPER's card
# accent is magenta, and §4.2's own token table lists IMPACT as the
# "Slipper/Can accent".
#
# ⚠️ AND WHY IT IS NO LONGER MAGENTA EITHER — 2026-07-28, same day, one step on.
#
# B-81's magenta was correct about the RULE and was only ever a placeholder for
# the COLOUR: "the magenta shit is just placeholder, we can update it with the
# new ones" (the human, supplying an asset moodboard for this exact
# prop). The moodboard's tsinelas is a worn brown foam sole with a tan fabric
# Y-strap — which is what a street tsinelas actually is, and which still satisfies
# B-81 completely, because brown and tan are neither role hue. The rule survives;
# only the stand-in colours it was demonstrated with are gone.
#
# So: PROP_FOAM footbed over a PROP_FOAM_DARK outsole, PROP_WEBBING straps and
# toe post. Neither role hue appears. See `UiTheme`'s PROP_* band for why these
# are their own tokens rather than borrowed UI or ENV_* ones.
#
# ⚠️ The materials are named for the PART, not for the palette token. That is
# deliberate and it is the second half of the fix: a material literally called
# "defense" is a bug that reads as correct in every diff. The lata now follows
# the same rule — it was renamed in the moodboard pass, when its colours changed
# anyway and the .obj churn was going to happen regardless.
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
## A first-person viewmodel forearm and fist. Playtest 0.4: "don't see arms of ppl".
##
## ⚠️ THE RIG'S OWN ARMS CANNOT BE USED FOR THIS, and it is worth knowing why
## before anyone tries again. `camera_rig.gd` already hides only `head-mesh`
## (B-73), so the real arms ARE being drawn — they are simply not in frame.
## Measured on the actual model: `body-mesh` spans CharacterBase-local
## -0.800..+0.076 while the FPP eye sits at +0.450, so the entire body is 0.37
## below the camera, and the arm bone at y=-0.115 sits ~48 degrees below the
## view axis against a 37.5-degree half-FOV. The chibi head is so large that the
## eye is above the shoulders. No amount of self-hide logic fixes that; the arms
## are out of the frustum, not hidden.
##
## So this is a dedicated viewmodel, mounted to the camera rather than the
## skeleton, which is how first-person games have always done it.
##
## Authored pointing +Y with the elbow at the origin, so it can be built from
## `add_extrude` (which only extrudes along Y) and then rotated into place in
## ViewmodelArms.tscn. Keeping the mesh axis-aligned means the numbers here stay
## readable; the aiming happens in the scene where it can be seen.
func _build_viewmodel_arm() -> void:
	var writer := ObjWriter.new("ViewmodelArm")
	# The two Persons deliberately share one skin, so a single baked colour is
	# correct here and this mesh never needs a per-Person variant. If that ever
	# stops being true, this becomes a palette-shader surface like the Persons.
	writer.set_material("skin", Color("c8875a"))
	writer.set_material("skin_shade", Color("a66b45"))

	# Forearm, elbow at y=0 running to the wrist. Chunky and near-square in
	# section, matching Kenney's blocky limbs rather than tapering realistically.
	# ⚠️ CHUNKY ON PURPOSE, and the first version was not chunky enough. The
	# Kenney rig is chibi: its real forearm is roughly as wide as it is long, and
	# a viewmodel authored at human proportions read as two thin sticks against
	# it. Width is now ~0.21 against a 0.42 total length - about 1:2 - which is
	# what matches the body the player sees in third person.
	# ⚠️ LONG ON PURPOSE. The elbow has to sit BELOW the frame so the arm reads as
	# running off-screen into the player's own body. Two earlier versions were
	# short enough that both ends were visible, and a limb with two visible ends
	# floating in the lower frame reads as a box, not an arm - which is exactly
	# what the playtest reported ("MY ARMS ARE FLOATING").
	writer.add_extrude(PackedVector2Array([
		Vector2( 0.130, -0.122),
		Vector2( 0.130,  0.122),
		Vector2(-0.130,  0.122),
		Vector2(-0.130, -0.122),
	]), 0.0, 0.62, "skin_shade")

	# Fist: wider than the forearm so the silhouette has a knuckle break in it.
	# Without the step the arm reads as a plank.
	writer.add_extrude(PackedVector2Array([
		Vector2( 0.158, -0.150),
		Vector2( 0.158,  0.150),
		Vector2(-0.158,  0.150),
		Vector2(-0.158, -0.150),
	]), 0.62, 0.84, "skin")

	writer.recalculate_normals(40.0)
	writer.write(OUTPUT_DIR + "viewmodel_arm")
	print("  viewmodel_arm")


## One arm of the Y-strap: a rectangular cross-section swept along a quadratic
## Bezier from `start` (anchored on the footbed edge) through `control` (the
## apex, above where the top of a foot would be) to `finish` (the top of the toe
## post). Both arms meet at `finish`, which is what makes the Y.
##
## Swept rather than extruded because the arch is the point. `add_extrude` only
## walks a 2D outline up the Y axis, so it cannot produce a band that leaves the
## sole, rises, and comes back down to a single shared point.
##
## Winding: each ring's four corners are emitted in a fixed order around the
## tangent, and consecutive rings are stitched with that same order, so every
## side face inherits the outward direction from the first ring. Getting this
## backwards makes the whole strap render inside-out, which is loud and obvious
## in any render rather than silent — deliberately preferred over the
## double-winding trick used for the building windows, because this band is
## chunky enough that a hidden inverted face would also break the M-4 outline
## pass (an inverted hull on inverted geometry produces no outline at all).
## `scale`, Art_Direction.md §1: `add_extrude` gets a `transform` param for this
## (2.1b-0), but this function builds its band from raw `add_quad` calls, which
## has none — so the control points AND the cross-section (HALF_WIDTH/HALF_THICK)
## are scaled directly here instead. Without scaling the cross-section too, a
## shrunk strap arc with an unscaled ~0.03 band width would come out relatively
## fatter than before, not merely smaller.
func _strap_band(writer: ObjWriter, start: Vector3, control: Vector3,
		finish: Vector3, scale: float = 1.0) -> void:
	const SEGMENTS: int = 7
	# ⚠️ WIDE AND FLAT, from the 2026-07-28 moodboard. The strap on a real
	# tsinelas is a broad flat webbing band, roughly a fifth of the sole's width;
	# the previous 0.032/0.017 section was near-square and read as a piece of
	# cord, which is the one thing a flip-flop strap never looks like.
	const HALF_WIDTH: float = 0.046
	const HALF_THICK: float = 0.013
	var half_width := HALF_WIDTH * scale
	var half_thick := HALF_THICK * scale
	start *= scale
	control *= scale
	finish *= scale

	var rings: Array[Array] = []
	for i in range(SEGMENTS + 1):
		var t := float(i) / float(SEGMENTS)
		var inv := 1.0 - t
		# Quadratic Bezier and its analytic derivative — the derivative gives the
		# tangent directly, which is cheaper and steadier than differencing
		# neighbouring samples (that degenerates at the endpoints).
		var point: Vector3 = inv * inv * start + 2.0 * inv * t * control + t * t * finish
		var tangent: Vector3 = (2.0 * inv * (control - start) + 2.0 * t * (finish - control)).normalized()
		# The band should stay flat-side-up along its whole run, so the frame is
		# built from world up rather than from a rotation-minimising frame. The
		# arc never approaches vertical, so `up` and `tangent` never align and
		# the cross product is always well conditioned.
		var right := tangent.cross(Vector3.UP).normalized()
		var up := right.cross(tangent).normalized()
		rings.append([
			point + right * half_width + up * half_thick,
			point - right * half_width + up * half_thick,
			point - right * half_width - up * half_thick,
			point + right * half_width - up * half_thick,
		])

	for i in range(SEGMENTS):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for corner in range(4):
			var nxt := (corner + 1) % 4
			writer.add_quad(a[corner], b[corner], b[nxt], a[nxt], "strap")

	# Cap only the footbed end. The toe-post end is buried inside the post knob,
	# so a cap there would z-fight with it for no visible gain.
	var first: Array = rings[0]
	writer.add_quad(first[3], first[2], first[1], first[0], "strap")


const TSINELAS_SCALE: float = 0.32

func _build_tsinelas() -> void:
	var writer := ObjWriter.new("Tsinelas")
	writer.set_material("outsole", UiTheme.PROP_FOAM_DARK)
	writer.set_material("foam", UiTheme.PROP_FOAM_DARK.lerp(UiTheme.PROP_FOAM, 0.55))
	writer.set_material("footbed", UiTheme.PROP_FOAM)
	writer.set_material("strap", UiTheme.PROP_WEBBING)
	writer.set_material("post", UiTheme.PROP_WEBBING.darkened(0.24))
	var scale_xf := Transform3D.IDENTITY.scaled(Vector3.ONE * TSINELAS_SCALE)

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
	# THREE layers, not one slab and no longer two. A real tsinelas has a darker
	# rubber outsole under a moulded foam midsole under a lighter footbed, and the
	# steps between them catch shadow lines that make the whole thing read as an
	# object rather than as a flat lozenge. The footbed is inset so that step is
	# visible from directly above, which is the angle a loose Prop is usually seen
	# from, and the outsole is inset MORE so the widest point of the slab sits at
	# mid-height — that is what reads as a moulded bevel rather than as a
	# cake-slice, and it is the silhouette the moodboard's side view shows.
	#
	# ⚠️ Bottom stays at y = 0.0. The sole's Y is its UNDERSIDE, not its centre
	# (Art_Direction.md Part 4, STANDING RULE — FLOATING GEOMETRY): the loose
	# slipper is placed by this face, so lifting it "for clearance" is exactly how
	# a prop ends up hovering.
	var footbed_outline := PackedVector2Array()
	var outsole_outline := PackedVector2Array()
	for p in sole_outline:
		footbed_outline.append(p * 0.94)
		outsole_outline.append(p * 0.88)
	# Total 0.120 against a 1.35 length. The old 0.10 was measured off a thinner
	# reference; the moodboard's foam is visibly chunkier, and chunky is also what
	# Art_Direction.md §0's readability pillar wants at throwing distance.
	writer.add_extrude(outsole_outline, 0.0, 0.022, "outsole", scale_xf)
	writer.add_extrude(sole_outline, 0.022, 0.085, "foam", scale_xf)
	writer.add_extrude(footbed_outline, 0.085, 0.120, "footbed", scale_xf)

	# --- Toe post ---
	# Small cylindrical knob between the toes, sitting on top of the sole.
	# 8-point circle at (x=0, z=-0.55), extruded y=0.10 to y=0.165.
	# CCW from above (angle increases CCW in XZ) keeps side walls facing out.
	var post_cx: float = 0.0
	var post_cz: float = -0.55
	var post_r: float = 0.050
	var post_segs: int = 8
	var post_outline := PackedVector2Array()
	for i in range(post_segs):
		var angle: float = TAU * float(i) / float(post_segs)
		post_outline.append(Vector2(post_cx + post_r * cos(angle),
		                            post_cz + post_r * sin(angle)))
	writer.add_extrude(post_outline, 0.120, 0.195, "post", scale_xf)

	# --- Y-straps ---
	# ⚠️ THESE USED TO BE FLAT QUADS AT strap_y = 0.10 — which is EXACTLY the top
	# face of the sole. A strap lying in the same plane as the footbed is not a
	# strap, it is a decal painted on the footbed, and that is precisely how it
	# rendered: a yellow chevron drawn on a pink lozenge, with no silhouette of
	# its own from any angle. It was the single thing making the hero prop read
	# as unfinished.
	#
	# They are now swept bands that ARCH over where a foot would be, so the
	# slipper has a hole through it — which is the whole visual signature of a
	# tsinelas and the thing that makes it readable in flight.
	# ⚠️ The footbed anchors must sit INSIDE the footbed outline at that z, not on
	# the nominal half-width — and the check is on the OUTER EDGE of the band,
	# `x + HALF_WIDTH`, not on its centreline. The waist of the sole is only
	# +/-0.18 at z=0 and the footbed is inset a further 6%, so the old anchor
	# (centre 0.163 + half-width 0.032 = 0.195 against a 0.176 footbed edge) hung
	# 0.019 of every strap off the side in mid-air. Widening the band to 0.052
	# would have tripled that overhang.
	#
	# Fixed by moving the anchors FORWARD rather than inward, to z = -0.04 where
	# the sole is 0.201 wide (0.189 on the footbed): 0.134 + 0.046 = 0.180, which
	# lands inside with margin. That is also roughly where a real tsinelas anchors
	# its strap — ahead of the waist — so the moodboard and the geometry agree.
	#
	# ⚠️ NOT further forward than that, which the first attempt tried (z = -0.15,
	# where the sole is wider and the margin is easier). It rendered wrong: the
	# whole Y crowded into the front quarter of the slipper and read as one band
	# across the toe rather than as two arms meeting at a post. The span from
	# anchor to post is the shape, so it is the thing to protect — win the width
	# margin back from the band section instead, which is what HALF_WIDTH 0.046 is.
	#
	# ⚠️ Anchor y = 0.105 is BELOW the footbed top (0.120) on purpose: the band is
	# 0.013 half-thick, so its underside sits at 0.092, buried in the foam. An
	# anchor placed ON the surface at 0.120 would leave the band's lower face
	# floating 0.013 clear of it — the same class of bug as the decals, on a
	# surface small enough that nobody would spot it until it was in a screenshot.
	_strap_band(writer, Vector3(0.134, 0.105, -0.04),
		Vector3(0.118, 0.285, -0.30), Vector3(0.0, 0.190, -0.505), TSINELAS_SCALE)
	_strap_band(writer, Vector3(-0.134, 0.105, -0.04),
		Vector3(-0.118, 0.285, -0.30), Vector3(0.0, 0.190, -0.505), TSINELAS_SCALE)

	writer.recalculate_normals(40.0)
	writer.write(OUTPUT_DIR + "tsinelas")
	print("  tsinelas")
