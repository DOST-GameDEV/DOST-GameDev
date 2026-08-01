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
##     godot --path . res://tools/models/preview.tscn -- --model=res://assets/models/lata_pasip.obj

const ObjWriter = preload("res://tools/models/obj_writer.gd")
const EnvKit = preload("res://tools/models/env_kit.gd")

const OUTPUT_DIR: String = "res://assets/models/"

## 16 reads as round at the ~4.5-unit TPP camera distance while staying cheap.
## 12 is visibly polygonal on a shape this smooth; 24 is spent for nothing.
const REVOLVE_SEGMENTS: int = 16


# ==============================================================================
# THE TWO HERO PROPS — four lata and four tsinelas, built from the human's own
# drawings. Rewritten 2026-08-01 by 🎨 `build model` (Agent_Prompts.md § 5).
# ==============================================================================
#
# ⚠️ WHAT THIS REPLACED, so nobody restores it. There used to be ONE can (a Sarsi
# livery, painted with a layered-strip wall so the sail could be non-symmetric)
# and ONE slipper, plus `lata_dent1..3.obj` and a `_apply_dents()` deform that
# drove Option A's "the dent count IS the health bar" mechanic. That mechanic was
# deleted in the HARRYDAKS pivot (Design.md § 12 — `FALL_LIMIT`, ring-outs, dents
# and the seal all went together), so the dents described a health bar that no
# longer exists and are swept here (§ 5.9). The layered-strip wall went with them:
# its whole reason for existing was that a `deform` would shear a decal off the
# can, and there is no deform any more.
#
# ⚠️ THESE ARE TEXTURED, WHICH Art_Direction.md PART 5 USED TO FORBID.
# The human drew four cans and four slippers by hand, three of the cans carrying
# readable parody wordmarks, and supplied FLATTENED 360-degree label wraps for
# exactly this purpose — then ruled on it directly (2026-08-01): *"you can use
# the flattened shit for textures bcz its easier that way, you cant redraw this
# too bro"*. Reduced to a flat `Kd`, a Pasip and a Decades are the same grey
# cylinder and every bit of the Filipino specificity is gone. Art_Direction.md
# Part 5 is amended to match rather than silently broken.
#
# ⚠️ AND IT DOES NOT FIGHT THE SKIN TINT, which was the standing objection
# (§ 5.5). `lata.gd::_tint_meshes()` writes the roster `tint` into `albedo_color`;
# on the toon shader that MULTIPLIES the texture rather than replacing it, so a
# textured skin carries `tint` WHITE and the label reads as drawn. Not one line
# outside this lane's paths had to change to make that work — see
# `toon.gdshader`'s header, which added the textured path for the Kenney kits.
#
# ⚠️ ONE MATERIAL PER PROP, AND THAT IS FORCED BY THE TINT WALK.
# `_tint_meshes()` overwrites EVERY surface it finds. A second, untextured
# material for (say) a bare metal lid would therefore be repainted flat white by
# a white tint — so where a part needs a different colour, it gets it by being
# projected onto a different part of the ONE texture, never by a second material.
# That is why the can's caps are UV-pinned to the wrap's rim bands below.

const TEXTURE_DIR: String = "textures/"

# --- The lata (the can) -------------------------------------------------------
#
# ⚠️ FOUR CANS, FOUR DIFFERENT SHAPES, AND THAT IS AN INSTRUCTION NOT A FLOURISH.
# 🧑 2026-08-01: *"Pls don't just blindly copy paste the same can size for them
# all."* The four drawings really are four different objects — a slim soda can, a
# squat paint tin, a tuna can and a ribbed bare tin — and their height:diameter
# ratios were measured off the drawings' own ink bounding boxes rather than
# guessed: Pasip 1.75, Decades 1.56, Metal 1.53, Boyben 1.35.
#
# ⚠️ THE SILHOUETTE HAS TO SURVIVE LYING ON ITS SIDE AT 88 DEGREES (§ 5.3), and
# that is a gameplay requirement: a crowd that cannot tell a fallen lata from a
# standing one cannot follow the round. Two things carry it, neither of them
# colour, because the toon pass flattens colour at distance:
#   · the ASPECT. Every can is meaningfully taller than it is wide, so upright is
#     a tall thin silhouette and fallen is a wide flat one. That is the whole
#     read, and it is why even the squat Boyben stays at 1.35 rather than going
#     to a true 1:1 paint tin.
#   · the END CAPS. A fallen can shows the camera a circle. Every profile below
#     ends in a rolled rim that is PROUD of the wall, so the disc reads as a hard
#     bright ellipse against the body instead of dissolving into it.
#
# ⚠️ THE DIAMETERS ARE DELIBERATELY CLOSER TOGETHER THAN THE DRAWINGS ARE.
# There is only ONE lata in the world and `Lata.tscn` carries ONE collision
# cylinder and ONE hurtbox for whichever skin is worn, so a true-to-drawing spread
# from a slim soda can to a fat paint tin would leave the hitbox wrong for three
# of the four — exactly the mesh-and-hitbox disagreement § 5.4 exists to prevent.
# So HEIGHT is held near-constant (0.377..0.385) and the identity is carried by
# the profile shape, which costs nothing in collision terms. Residual worst case
# is Pasip at r 0.108 against a 0.130 body cylinder — 22 mm, about a fifth of a
# can — and it is filed to ⚖️ `build fair` rather than hidden.

## Profile points are (radius fraction, height fraction) — fractions of the can's
## own max radius and total height, bottom to top, EXCLUDING the two centre
## points. The caps are emitted separately so their UVs can be pinned; see
## `_build_lata`.
func _lata_specs() -> Array:
	return [
		# The slim soda can. Necked in at BOTH ends, which is the one profile
		# feature no other can here has and is what makes it identifiable in
		# silhouette alone at arena distance.
		{
			"name": "lata_pasip",
			"texture": "lata_pasip.png",
			"radius": 0.1075, "height": 0.377,
			"cap_v": Vector2(0.070, 0.930), "front_u": 0.38,
			"profile": [
				Vector2(0.70, 0.000), Vector2(0.88, 0.035), Vector2(1.00, 0.080),
				Vector2(1.00, 0.870), Vector2(0.88, 0.940), Vector2(0.66, 0.980),
				Vector2(0.62, 1.000),
			],
		},
		# The paint tin. Straight-walled with a rolled lid lip standing PROUD of
		# the wall — the one detail that says "paint" rather than "food", and the
		# thing a real bakod-side paint can is opened by.
		{
			"name": "lata_boyben",
			"texture": "lata_boyben.png",
			"radius": 0.1425, "height": 0.385,
			"cap_v": Vector2(0.070, 0.930), "front_u": 0.22,
			"profile": [
				Vector2(0.86, 0.000), Vector2(0.97, 0.025), Vector2(1.00, 0.050),
				Vector2(1.00, 0.905), Vector2(0.97, 0.928), Vector2(1.00, 0.958),
				Vector2(0.95, 0.988), Vector2(0.92, 1.000),
			],
		},
		# The tuna can. Rolled rims proud at BOTH ends with the wall inset
		# between them, which is what a seamed food can actually looks like and
		# reads as two bright rings around a darker body under the toon bands.
		{
			"name": "lata_decades",
			"texture": "lata_decades.png",
			"radius": 0.1225, "height": 0.382,
			"cap_v": Vector2(0.070, 0.930), "front_u": 0.22,
			"profile": [
				Vector2(0.90, 0.000), Vector2(1.00, 0.030), Vector2(0.96, 0.072),
				Vector2(0.96, 0.928), Vector2(1.00, 0.970), Vector2(0.90, 1.000),
			],
		},
		# The bare ribbed tin — profile built in code, see `_metal_can_profile`.
		{
			"name": "lata_metal",
			"texture": "lata_metal.png",
			"radius": 0.1250, "height": 0.383,
			# Rust from the middle of the wrap at BOTH ends — it has no printed
			# rim band to sample, and the human asked for the rusty texture there
			# by name. 0.40 and 0.62 are two different rows so the two ends do not
			# come out identical.
			"cap_v": Vector2(0.400, 0.620), "front_u": 0.50,
			"profile": _metal_can_profile(),
		},
	]

## How many ribs the bare tin carries, and how deep. Straight off the drawing,
## which shows eight of them across the middle two-thirds of the wall.
##
## ⚠️ THESE ARE REAL GEOMETRY, NOT PAINTED ON, and that is the point of this can.
## The other three are identified by their labels, which is a texture read and
## therefore dies at distance under the toon pass. The metal can has no label at
## all — it is a bare tin — so its ONLY identity is its silhouette, and a ribbed
## silhouette is one of the few that survives being 40 units from the camera and
## two shading bands deep. 0.055 of the radius is shallow enough to stay low poly
## (two extra profile points per rib, 32 rings total) and deep enough to catch a
## shadow band on every rib.
const METAL_RIB_COUNT: int = 8
const METAL_RIB_DEPTH: float = 0.055
const METAL_RIB_FROM: float = 0.190
const METAL_RIB_TO: float = 0.865

func _metal_can_profile() -> Array:
	var profile: Array = [
		Vector2(0.90, 0.000), Vector2(1.00, 0.030), Vector2(0.945, 0.070),
	]
	var span := (METAL_RIB_TO - METAL_RIB_FROM) / float(METAL_RIB_COUNT)
	for i in range(METAL_RIB_COUNT):
		var base := METAL_RIB_FROM + span * float(i)
		# Each rib is a shallow valley between two full-radius shoulders, so the
		# wall leaves and returns to 0.945 and no rib can open a seam against the
		# straight sections either side of the run.
		profile.append(Vector2(0.945, base))
		profile.append(Vector2(0.945 - METAL_RIB_DEPTH, base + span * 0.5))
	profile.append(Vector2(0.945, METAL_RIB_TO))
	profile.append(Vector2(1.00, 0.958))
	profile.append(Vector2(0.90, 1.000))
	return profile

func _build_lata(spec: Dictionary) -> void:
	var writer := ObjWriter.new("Lata")
	var radius: float = spec["radius"]
	var height: float = spec["height"]
	# ⚠️ Kd IS WHITE AND MUST STAY WHITE. Godot's .obj importer multiplies
	# `albedo_color` (from Kd) by `albedo_texture` (from map_Kd), so any Kd but
	# white darkens the human's art before the skin tint ever gets to it.
	writer.set_material("label", Color.WHITE, TEXTURE_DIR + String(spec["texture"]))

	# The wrap covers the FULL height of the can including both rim bands, so `v`
	# is simply the height fraction and `u` the angle. `a1` reaches TAU on the last
	# segment rather than wrapping to 0, which is what closes the seam — see
	# add_revolve's uv note.
	# ⚠️ `u` RUNS 1 -> 0, NOT 0 -> 1, AND THAT IS THE MIRRORING FIX.
	# `add_revolve` sweeps counter-clockwise seen from +Y, so a naive
	# `angle / TAU` wraps the label around the can the wrong way and every
	# wordmark reads back to front — the first render had "BOYBEN" as "NEBYOB"
	# and "Decades" reversed, which is invisible in a UV dump and instantly
	# obvious in a screenshot. Reversing `u` mirrors the wrap back.
	var wall_uv := func(y: float, angle: float) -> Vector2:
		return Vector2(1.0 - angle / TAU, y / height)

	# ⚠️ THE CAN IS YAWED SO ITS LABEL'S FRONT FACES THE DEFAULT VIEW, and this is
	# a restatement of the deleted `LATA_LABEL_FACE` rather than a new idea. The
	# lata has no canonical facing in play — it spends the match being knocked
	# over and stood back up — so the angle is free, and it is spent on making the
	# livery REVIEWABLE. Without it the wrap's seam lands wherever it lands, and
	# the first render framed all four cans from behind: three nutrition panels
	# and a barcode, with every wordmark facing away from the camera.
	#
	# `front_u` is where that can's logo sits along its own wrap, measured off the
	# flattened source. The mesh is turned so that texel arrives on the preview
	# camera's bearing (+X +Z, 45 degrees).
	var front_u: float = spec["front_u"]
	var yaw := PI / 4.0 - (1.0 - front_u) * TAU
	var facing := Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)

	var profile: Array = spec["profile"]
	var wall := PackedVector2Array()
	for point in profile:
		wall.append(Vector2(point.x * radius, point.y * height))
	writer.add_revolve(wall, REVOLVE_SEGMENTS, "label", true, Callable(),
		facing, wall_uv)

	# ⚠️ THE CAPS ARE UV-PINNED TO THE WRAP'S RIM BANDS, and that is what lets the
	# whole can be one material (see this section's header). A cap that took the
	# same y-derived `v` as the wall would smear whatever the label happens to
	# show at that height radially across the disc — and the lid disc is exactly
	# what a knocked-down can points at the camera, so it is the most-looked-at
	# surface on the prop for most of a round. Pinned to v = 0 / v = 1 it samples
	# the uniform metal band the human drew along the very top and bottom edge of
	# every one of the four wraps, and reads as a plain stamped can end.
	# ⚠️ THE CAP SAMPLE ROWS ARE PER-CAN, AND 0.02/0.98 WAS NOT FAR ENOUGH IN.
	# The wraps are CROPPED DRAWINGS, so their outermost rows are blank page —
	# measured on the sources, Pasip has 12 empty rows at the top of 512 and the
	# Latang Kalawang has 7. v = 0.98 is row 10, which is still inside Pasip's
	# blank margin, so the lid came out flat white twice. 🧑: *"theres still white
	# on the metal can"*.
	#
	# The Latang Kalawang gets a different answer from the other three, and it is
	# the one the human asked for directly — *"cant u js put rusty texture there"*.
	# It is a BARE tin: it has no printed rim band to sample, so its cap takes a
	# row from the middle of the wrap, where the rust is. The three labelled cans
	# keep sampling their own drawn rim bands, because a lid wearing a slice of
	# the nutrition panel would be worse than a white one.
	var cap_v: Vector2 = spec["cap_v"]
	var base_uv := func(_y: float, angle: float) -> Vector2:
		return Vector2(1.0 - angle / TAU, cap_v.x)
	var lid_uv := func(_y: float, angle: float) -> Vector2:
		return Vector2(1.0 - angle / TAU, cap_v.y)
	# ⚠️ THE CAPS ARE STEPPED, NOT FLAT DISCS — 🧑: *"make sure the can has a top
	# and bottom bcz the metal can has no top haha"*. A single flat disc spanning
	# the rim is geometrically a lid, but it lights as one uniform facet, so at any
	# angle where it catches the same band as the wall it disappears and the can
	# reads as an open tube. Every real can is RECESSED at the top (the lid sits
	# below its own rolled rim) and CONCAVE at the bottom (which is what makes it
	# stand on a ring rather than a disc). Two extra rings each buys a hard shading
	# break right where the eye looks for the end of the can — and it is the same
	# 88-degree readability argument as the profile itself, since a knocked-over
	# can points one of these two faces straight at the camera.
	var first: Vector2 = profile[0]
	var last: Vector2 = profile[profile.size() - 1]
	var base_y := first.y * height
	var lid_y := last.y * height
	writer.add_revolve(PackedVector2Array([
		Vector2(0.0, base_y + height * 0.022),
		Vector2(first.x * radius * 0.86, base_y + height * 0.016),
		Vector2(first.x * radius, base_y),
	]), REVOLVE_SEGMENTS, "label", true, Callable(), facing, base_uv)
	writer.add_revolve(PackedVector2Array([
		Vector2(last.x * radius, lid_y),
		Vector2(last.x * radius * 0.88, lid_y - height * 0.018),
		Vector2(0.0, lid_y - height * 0.018),
	]), REVOLVE_SEGMENTS, "label", true, Callable(), facing, lid_uv)

	# 40 degrees smooths the 22.5-degree step of a 16-segment revolve while
	# leaving every rim, rib shoulder and cap edge hard — see recalculate_normals.
	writer.recalculate_normals(40.0)
	writer.write(OUTPUT_DIR + String(spec["name"]))
	var size := writer.bounds_size()
	print("  %-14s  d %.3f  h %.3f  ratio %.2f" % [
		spec["name"], size.x, size.y, size.y / maxf(size.x, 0.0001)])

# --- The tsinelas (the slipper) -----------------------------------------------
#
# Four slippers, named by the human 2026-08-01: **Tsinelas** (the green rubber
# flip-flop), **Crocs**, **Bakya** and **Sike**.
#
# Orientation is unchanged: the character faces -Z, so the toe is at -Z and the
# heel at +Z in the authoring space below, and everything is scaled by
# TSINELAS_SCALE on the way out.
#
# ⚠️ THE ORIGIN SITS ON THE VOLUME CENTROID, AND THAT IS § 5.2's HARD
# REQUIREMENT. `slipper.gd` spins a thrown slipper about its `Visual` node on two
# axes at once — SPIN_SPEED_DEG 900 about the long axis and TUMBLE_SPEED_DEG 520
# end over end — and that node pivots about the MESH ORIGIN. `add_extrude` puts
# y = 0 at the underside, so a sole authored the obvious way orbits its own heel
# and reads as a bent wheel. `ObjWriter.center_on_volume_centroid()` is called on
# every one of the four; see its own header for why it is the volume centroid and
# not the centre of the bounding box (the crocs' toe box and the bakya's heel
# block both move the mass well off the box centre).
#
# ⚠️ THE TEXTURE IS A TOP-DOWN PLANAR PROJECTION, AND THAT IS WHY THE STRAPS LINE
# UP FOR FREE. The human's drawings ARE top-down views, so projecting them
# straight down the Y axis puts every drawn feature exactly above the geometry
# that represents it: the bakya's floral band lands on the bakya's 3D band, the
# Sike swoosh lands on the Sike's band, the crocs' vent holes land on the crocs'
# toe box. Nothing had to be unwrapped and no seam exists to hide.
#
# ⚠️ ONE SQUARE UV BOX PER SLIPPER, MATCHING THE TEXTURE'S OWN SQUARE CANVAS.
# `build_prop_textures.py` centres each cropped drawing on a square canvas with a
# 4% margin; `_tsinelas_uv` maps a square of side (length x 1.08) centred on the
# sole to 0..1. The two have to agree or the art slides off the toe — they are a
# matched pair, so edit `SLIPPER_PAD` there and `TSINELAS_UV_PAD` here together.

const TSINELAS_SCALE: float = 0.32
const TSINELAS_UV_PAD: float = 0.04
## How far inside the silhouette a SIDE WALL looks up its colour. See
## `ObjWriter.add_extrude`'s own note — sampling on the outline itself picked up
## the drawing's black keyline or the white page beyond it, and put a white rim
## around every sole. 🧑 on that first render: *"the fucking slippers arent 3d"* —
## a white edge all the way round is exactly what a paper cutout looks like.
const UV_WALL_INSET: float = 0.72
## What `TsinelasVisual.tscn` scales the mesh by on top of TSINELAS_SCALE
## (Art_Direction.md §2 — "bigger for drama"). Restated here for ONE purpose: so
## the generator can print each slipper's centroid height in WORLD units, which is
## the space `Slipper.REST_HEIGHT` lives in. Nothing is built from it.
const TSINELAS_VISUAL_SCALE: float = 1.60

## Every sole is a 12-point outline, CCW in (x, z) seen from above, centred on the
## origin in both axes so the planar UV box below is symmetric. CCW from above
## means the right side runs toe->heel (+Z) and the left side heel->toe (-Z).
func _tsinelas_specs() -> Array:
	return [
		# THE TSINELAS — the plain green rubber flip-flop, and the one the game is
		# named after. Thin, waisted at the arch, Y-strap over an open foot. It is
		# the silhouette everything else here is read against.
		{
			"name": "tsinelas_tsinelas", "texture": "tsinelas_tsinelas.png",
			"kind": "thong", "length": 1.35,
			"outline": [
				Vector2( 0.10, -0.620), Vector2( 0.26, -0.300), Vector2( 0.18,  0.050),
				Vector2( 0.22,  0.500), Vector2( 0.10,  0.650), Vector2( 0.00,  0.675),
				Vector2(-0.10,  0.650), Vector2(-0.22,  0.500), Vector2(-0.18,  0.050),
				Vector2(-0.26, -0.300), Vector2(-0.10, -0.620), Vector2( 0.00, -0.675),
			],
			# ⚠️ THICKER THAN THE FIRST PASS (0.120 -> 0.165). A flip-flop is thin,
			# but "thin" at 0.32 scale came out 19 mm tall in world units against a
			# 690 mm length — a 1:36 slab, which is a sheet of paper, not an object.
			# The steps between the three layers are what catch the shading bands.
			"layers": [
				{"to": 0.035, "inset": 0.88}, {"to": 0.120, "inset": 1.00},
				{"to": 0.165, "inset": 0.94},
			],
		},
		# THE CROCS — a clog, so the front half is a CLOSED domed toe box and the
		# heel carries a strap. That dome is the whole point: it is the only
		# slipper here with a tall closed silhouette, so it is the only one you can
		# identify mid-flight from the shape alone.
		{
			"name": "tsinelas_crocs", "texture": "tsinelas_crocs.png",
			"kind": "clog", "length": 1.32,
			"outline": [
				Vector2( 0.14, -0.610), Vector2( 0.30, -0.280), Vector2( 0.25,  0.060),
				Vector2( 0.27,  0.480), Vector2( 0.14,  0.635), Vector2( 0.00,  0.660),
				Vector2(-0.14,  0.635), Vector2(-0.27,  0.480), Vector2(-0.25,  0.060),
				Vector2(-0.30, -0.280), Vector2(-0.14, -0.610), Vector2( 0.00, -0.660),
			],
			# A thinner sole than the flip-flop on purpose: the toe box adds a lot
			# of mass high up, and a thick sole under it would push the volume
			# centroid so far from the underside that one shared REST_HEIGHT could
			# not serve all four (see the REST_HEIGHT note in slipper.gd).
			# A crocs is a CHUNKY foam clog — the sole alone is as thick as a whole
			# flip-flop, and the upper sits on top of that again.
			"layers": [
				{"to": 0.045, "inset": 0.90}, {"to": 0.140, "inset": 1.00},
			],
		},
		# THE BAKYA — carved wood, so one rigid slab with no midsole layering at
		# all, and a heel block underneath. Thickest and heaviest-reading of the
		# four, which is exactly what a bakya is.
		{
			"name": "tsinelas_bakya", "texture": "tsinelas_bakya.png",
			"kind": "bakya", "length": 1.34,
			"outline": [
				Vector2( 0.13, -0.615), Vector2( 0.25, -0.310), Vector2( 0.22,  0.040),
				Vector2( 0.24,  0.490), Vector2( 0.13,  0.640), Vector2( 0.00,  0.670),
				Vector2(-0.13,  0.640), Vector2(-0.24,  0.490), Vector2(-0.22,  0.040),
				Vector2(-0.25, -0.310), Vector2(-0.13, -0.615), Vector2( 0.00, -0.670),
			],
			# One rigid carved slab — no midsole layering, because a bakya has none.
			"layers": [
				{"to": 0.150, "inset": 1.00},
			],
		},
		# THE SIKE — a slide. One broad band across the middle of the foot and no
		# toe post, on a chunky two-layer sole. Reads as the "sports" one.
		{
			"name": "tsinelas_sike", "texture": "tsinelas_sike.png",
			"kind": "slide", "length": 1.33,
			"outline": [
				Vector2( 0.12, -0.600), Vector2( 0.28, -0.290), Vector2( 0.23,  0.050),
				Vector2( 0.26,  0.485), Vector2( 0.13,  0.638), Vector2( 0.00,  0.665),
				Vector2(-0.13,  0.638), Vector2(-0.26,  0.485), Vector2(-0.23,  0.050),
				Vector2(-0.28, -0.290), Vector2(-0.12, -0.600), Vector2( 0.00, -0.665),
			],
			# A moulded sports slide: deep outsole, deeper midsole, thin footbed.
			"layers": [
				{"to": 0.060, "inset": 0.88}, {"to": 0.150, "inset": 1.00},
				{"to": 0.185, "inset": 0.95},
			],
		},
	]

func _build_tsinelas(spec: Dictionary) -> void:
	var writer := ObjWriter.new("Tsinelas")
	writer.set_material("skin", Color.WHITE, TEXTURE_DIR + String(spec["texture"]))
	var scale_xf := Transform3D.IDENTITY.scaled(Vector3.ONE * TSINELAS_SCALE)

	# The square the texture's own square canvas maps onto. Authoring space, so it
	# is applied BEFORE scale_xf — the projection has to be in the same coordinates
	# as the outline points that feed it.
	var box: float = float(spec["length"]) * (1.0 + 2.0 * TSINELAS_UV_PAD)
	var uv := func(x: float, z: float) -> Vector2:
		return Vector2(0.5 + x / box, 0.5 + z / box)

	var outline := PackedVector2Array()
	for point in spec["outline"]:
		outline.append(point)

	# --- The sole. Stacked slabs, each inset by its own factor so the steps
	# between them catch a shadow line and the whole thing reads as a moulded
	# object rather than a flat lozenge (the finding that produced the original
	# three-layer sole, kept).
	var y := 0.0
	for layer in spec["layers"]:
		var inset: float = layer["inset"]
		var shaped := PackedVector2Array()
		for point in outline:
			shaped.append(point * inset)
		writer.add_extrude(shaped, y, float(layer["to"]), "skin", scale_xf, uv,
			UV_WALL_INSET)
		y = float(layer["to"])

	# ⚠️ EVERY BAND BELOW GOT TALLER AND FATTER AFTER THE FIRST RENDER, and the
	# reason is worth keeping. The straps were modelled correctly and were still
	# INVISIBLE: a 0.013 half-thickness band arching 0.28 over a sole whose top is
	# already at 0.12 clears it by so little that, painted by the same top-down
	# projection as the footbed underneath it, there was nothing to see — no
	# silhouette gap, no shading break, no colour change. 🧑: *"the fucking
	# slippers arent 3d"*. The fix is the ARCH: the hole between the strap and the
	# sole is the whole visual signature of a slipper, and it has to be big enough
	# to see daylight through at throwing distance.
	match String(spec["kind"]):
		"thong":
			_tsinelas_toe_post(writer, scale_xf, uv, y)
			# ⚠️ THE Y ARCHES TO 0.62, WHICH IS FOUR TIMES THE SOLE'S OWN HEIGHT.
			# A flip-flop's strap really does stand that proud — it has to clear
			# the whole width of a foot — and the HOLE it makes is the single
			# thing that identifies the object in flight. The earlier 0.40 apex
			# was still low enough that the sole filled the gap from any camera
			# above the horizon, which is every camera in this game.
			# ⚠️ THE ANCHORS ARE MEASURED OFF THE DRAWING, NOT PLACED BY EYE.
			# 🧑: *"for the green tsinelas i drew where straps should be (yellow
			# line) pls take that into account bcz u made random ass straps"*.
			# Sampling the yellow in `tsinelas_tsinelas.png` puts the drawn Y
			# between mesh z -0.493 (the toe post) and z +0.245 (where the arms
			# meet the sole). The first pass anchored them at z -0.04 — half a
			# slipper too far forward, which crowded the whole Y into the front
			# third AND made the band sample the footbed instead of the yellow.
			_strap_band(writer, Vector3(0.170, y - 0.020, 0.245),
				Vector3(0.155, 0.640, -0.090), Vector3(0.0, 0.400, -0.493),
				TSINELAS_SCALE, uv, 0.060, 0.024)
			_strap_band(writer, Vector3(-0.170, y - 0.020, 0.245),
				Vector3(-0.155, 0.640, -0.090), Vector3(0.0, 0.400, -0.493),
				TSINELAS_SCALE, uv, 0.060, 0.024)
		"clog":
			_clog_toe_box(writer, scale_xf, uv, y)
			# The heel strap, swung up and BACK past the heel the way a real
			# crocs' does when it is flipped into sport mode — which also puts it
			# outside the sole's own silhouette, so it reads from every angle
			# instead of hiding against the heel.
			# ⚠️ THE HEEL STRAP SITS ON THE INSTEP, NOT SWUNG OUT BEHIND THE SHOE.
			# The first pass arced it to z +0.900 — past the back of the sole
			# entirely — which rendered as a flat blade sticking out of the heel
			# and is the "random ass straps on the back part" the human called
			# out. On the drawing the band crosses the foot just behind the toe
			# box, so that is where it goes.
			_strap_band(writer, Vector3(0.255, y - 0.020, 0.235),
				Vector3(0.0, 0.470, 0.290), Vector3(-0.255, y - 0.020, 0.235),
				TSINELAS_SCALE, uv, 0.105, 0.024, 0.235)
		"bakya":
			# The heel block, underneath the back of the slab. A bakya stands on a
			# heel, and it is what stops the profile reading as a plank.
			var heel := PackedVector2Array()
			for point in outline:
				if point.y > 0.20:
					heel.append(point * 0.80)
			# ⚠️ TWO SEPARATE BLOCKS UNDER THE SLAB, NOT ONE SKIRT — this is the
			# thing that makes a bakya a bakya and not "the flip-flop but thicker".
			# A real bakya is a carved plank standing on a heel at the back and a
			# lower step at the ball of the foot, with the arch CUT AWAY between
			# them. That gap is a hole straight through the side silhouette, which
			# is a far stronger read than any surface detail — and it is the one
			# feature none of the other three has.
			var heel_block := PackedVector2Array()
			var toe_block := PackedVector2Array()
			for point in outline:
				if point.y > 0.26:
					heel_block.append(point * 0.86)
				elif point.y < -0.20:
					toe_block.append(point * 0.86)
			if heel_block.size() >= 3:
				writer.add_extrude(heel_block, -0.105, 0.002, "skin", scale_xf,
					uv, UV_WALL_INSET)
			if toe_block.size() >= 3:
				writer.add_extrude(toe_block, -0.048, 0.002, "skin", scale_xf,
					uv, UV_WALL_INSET)
			# One broad cloth band across the ball of the foot, where the drawing
			# puts the floral strap. `band_uv_z` pins its sample to the middle of
			# that drawn band so it keeps the floral repeat and picks up no
			# keyline — see _strap_band.
			# Measured: the floral band sits at mesh z +0.147..+0.418 in the
			# drawing, centre +0.283 — a mule strap over the mid-foot, NOT over
			# the toes where the first pass put it (-0.140, the wrong half).
			_strap_band(writer, Vector3(0.235, y - 0.015, 0.283),
				Vector3(0.0, 0.520, 0.283), Vector3(-0.235, y - 0.015, 0.283),
				TSINELAS_SCALE, uv, 0.135, 0.026, 0.283)
		"slide":
			# ⚠️ A CONTOURED FOOTBED, WHICH IS WHAT SEPARATES THE SIKE FROM THE
			# BAKYA. Both were "slab plus one band" in the first pass and read as
			# the same object twice. A moulded slide has a dished footbed with a
			# raised HEEL CUP behind it, so its top surface is not flat and its
			# back end stands up in silhouette — the opposite of the bakya's
			# dead-flat plank.
			var cup := PackedVector2Array()
			for point in outline:
				if point.y > 0.16:
					cup.append(point * 0.94)
			if cup.size() >= 3:
				writer.add_extrude(cup, y - 0.012, y + 0.085, "skin", scale_xf,
					uv, UV_WALL_INSET)
			# The Sike band: wider, thicker and higher than the bakya's, because
			# it is moulded rubber rather than cloth.
			# Measured: the white swoosh sits at mesh z +0.272..+0.398, and the
			# SIKE wordmark just ahead of it, so the moulded band spans roughly
			# +0.15..+0.45 with its centre at +0.30. Again the wrong half in the
			# first pass (-0.120).
			_strap_band(writer, Vector3(0.255, y - 0.015, 0.300),
				Vector3(0.0, 0.585, 0.300), Vector3(-0.255, y - 0.015, 0.300),
				TSINELAS_SCALE, uv, 0.155, 0.034, 0.300)

	writer.recalculate_normals(40.0)
	# ⚠️ AFTER recalculate_normals AND BEFORE write. A pure translation does not
	# change a normal, so the order is safe either way for shading — but it must
	# be before `write`, and doing it last keeps that obvious.
	var centroid := writer.center_on_volume_centroid()
	writer.write(OUTPUT_DIR + String(spec["name"]))
	var size := writer.bounds_size()
	# The number REST_HEIGHT has to agree with: how far the volume centroid (now
	# the origin) sits above the lowest point of the mesh. Printed for all four so
	# the constant can be chosen against measurements rather than by eye.
	# Distance from the origin (now the centroid) DOWN to the lowest vertex. The
	# bounding-box centre is relative to that same new origin, so the floor sits at
	# centre.y - size.y/2 and the distance is the negative of it.
	var to_floor := size.y * 0.5 - writer.bounds_centre().y
	print("  %-18s L %.3f  W %.3f  H %.3f  centroid->floor %.4f  (world %.4f)" % [
		spec["name"], size.z, size.x, size.y, to_floor,
		to_floor * TSINELAS_VISUAL_SCALE])

## The flip-flop's toe post — a small 8-sided knob between the toes that the two
## strap arms meet on top of.
func _tsinelas_toe_post(writer: ObjWriter, scale_xf: Transform3D, uv: Callable,
		sole_top: float) -> void:
	const POST_SEGMENTS: int = 8
	const POST_RADIUS: float = 0.050
	const POST_Z: float = -0.55
	var post := PackedVector2Array()
	for i in range(POST_SEGMENTS):
		var angle: float = TAU * float(i) / float(POST_SEGMENTS)
		post.append(Vector2(POST_RADIUS * cos(angle), POST_Z + POST_RADIUS * sin(angle)))
	writer.add_extrude(post, sole_top, sole_top + 0.105, "skin", scale_xf, uv, UV_WALL_INSET)

## The crocs' closed toe box: three stacked, shrinking, forward-biased slabs.
##
## ⚠️ STEPPED, NOT A REVOLVE OR A DOME. Three flat-topped layers is what the rest
## of this game's geometry looks like — the toon pass bands hard, so a smoothly
## curved dome would show as three bands anyway, at four times the triangle cost
## and with a soft silhouette that fights every other prop in the frame.
func _clog_toe_box(writer: ObjWriter, scale_xf: Transform3D, uv: Callable,
		sole_top: float) -> void:
	# ⚠️ FIVE LAYERS AND A ROUNDED PLAN, NOT THREE BOXES. The first pass stacked
	# three clipped rectangles and rendered as a grey brick sitting on a sole —
	# 🧑: *"make them look like real crocs"*. A clog's toe box is a DOME that
	# rolls over in both axes: it is widest and lowest at the toe, rises to a
	# rounded crown over the ball of the foot, and stops in a clean vertical wall
	# at the instep where the foot goes in. The `back` column is that instep wall,
	# the `inset` column is the roll inward, and `lift` is how far the FRONT edge
	# of each layer drops relative to the crown — which is what curves the dome
	# down toward the toe instead of leaving a flat table top.
	# ⚠️ THE BACK EDGE IS MEASURED OFF THE DRAWING TOO. The vented toe box in
	# `tsinelas_crocs.png` ends around mesh z -0.07, so the instep wall goes
	# there — the first pass ran it back to +0.095, which swallowed the middle of
	# the shoe and left no room for the strap the drawing shows crossing it.
	# Seven layers rather than five, with the inset falling away faster near the
	# top, so the crown ROLLS OVER instead of ending in a flat plateau — the
	# plateau is most of why it read as a block rather than a clog.
	var layers := [
		{"back":  0.020, "inset": 1.00, "to": sole_top + 0.055},
		{"back":  0.000, "inset": 0.97, "to": sole_top + 0.115},
		{"back": -0.020, "inset": 0.93, "to": sole_top + 0.170},
		{"back": -0.040, "inset": 0.87, "to": sole_top + 0.218},
		{"back": -0.060, "inset": 0.78, "to": sole_top + 0.256},
		{"back": -0.080, "inset": 0.64, "to": sole_top + 0.283},
		{"back": -0.100, "inset": 0.44, "to": sole_top + 0.298},
	]
	# A rounded 10-point plan rather than the sole's own angular outline, so the
	# dome reads as moulded foam. Still low poly: 10 points x 5 layers is 100
	# triangles for the whole upper.
	var base := [
		Vector2( 0.10, -0.625), Vector2( 0.22, -0.470), Vector2( 0.29, -0.270),
		Vector2( 0.29, -0.020), Vector2( 0.26,  0.150),
		Vector2(-0.26,  0.150), Vector2(-0.29, -0.020), Vector2(-0.29, -0.270),
		Vector2(-0.22, -0.470), Vector2(-0.10, -0.625),
		Vector2( 0.00, -0.660),
	]
	var y := sole_top
	for layer in layers:
		var shaped := PackedVector2Array()
		for point in base:
			var z: float = minf(point.y, float(layer["back"]))
			shaped.append(Vector2(point.x, z) * float(layer["inset"]))
		writer.add_extrude(shaped, y, float(layer["to"]), "skin", scale_xf, uv,
			UV_WALL_INSET)
		y = float(layer["to"])

## One band of strap: a rectangular cross-section swept along a quadratic Bezier
## from `start`, through `control` (the apex, above where a foot would be), to
## `finish`. A Y-strap uses two of these meeting at the toe post; a bakya's or a
## Sike's single band uses one, running right across from edge to edge.
##
## Swept rather than extruded because the arch is the point: `add_extrude` only
## walks an outline up the Y axis, so it cannot produce a band that leaves the
## sole, rises and comes back down.
##
## ⚠️ `half_width` AND `half_thick` ARE PARAMETERS NOW, not constants. The four
## slippers' bands are genuinely different objects — a flip-flop's thin webbing
## arm, a crocs' pivoting heel strap, a bakya's broad cloth band and a Sike's
## moulded rubber one — and the old fixed 0.046/0.013 made every one of them look
## like the flip-flop's.
##
## Winding: each ring's four corners are emitted in a fixed order around the
## tangent and consecutive rings are stitched in that same order, so every side
## face inherits its outward direction from the first ring. Getting this backwards
## renders the band inside-out, which is loud in any render rather than silent —
## deliberately preferred, because an inverted hull on inverted geometry produces
## no outline at all and the M-4 outline pass would fail quietly.
## ⚠️ `band_uv_z` IS THE FIX FOR THE BARCODE STRAPS, and it is worth the extra
## parameter. A band ARCHES: it leaves the sole, rises over where a foot would be
## and comes down again, so its samples sweep a long way across the drawing in z.
## Sampled at its true (x, z) it therefore crosses the drawn strap's black
## keyline, then the footbed, then the keyline again — and the Sike's band came
## out looking like a barcode while the Bakya's went half black. 🧑: *"theyre
## still really bad"*.
##
## Passing a `band_uv_z` pins every sample to ONE line across the drawing — the
## middle of the drawn strap — so the band takes the colours the human actually
## painted on it, varying across its width (the Bakya keeps its floral repeat,
## the Sike keeps its swoosh) and constant along its arch, with no keyline
## anywhere near the sample line. INF means "sample where you really are", which
## is what the flip-flop's Y-strap wants: the drawn Y genuinely runs under the
## modelled Y, so following it is correct there.
func _strap_band(writer: ObjWriter, start: Vector3, control: Vector3,
		finish: Vector3, scale: float, uv: Callable,
		half_width: float, half_thick: float,
		band_uv_z: float = INF) -> void:
	const SEGMENTS: int = 7
	var hw := half_width * scale
	var ht := half_thick * scale
	start *= scale
	control *= scale
	finish *= scale

	var rings: Array[Array] = []
	var flats: Array[Vector2] = []
	for i in range(SEGMENTS + 1):
		var t := float(i) / float(SEGMENTS)
		var inv := 1.0 - t
		# Quadratic Bezier and its analytic derivative — the derivative gives the
		# tangent directly, which is steadier than differencing neighbouring
		# samples (that degenerates at the endpoints).
		var point: Vector3 = inv * inv * start + 2.0 * inv * t * control + t * t * finish
		var tangent: Vector3 = (2.0 * inv * (control - start) + 2.0 * t * (finish - control)).normalized()
		# Flat-side-up along the whole run, so the frame comes from world up
		# rather than a rotation-minimising one. The arc never approaches
		# vertical, so `up` and `tangent` never align.
		var right := tangent.cross(Vector3.UP).normalized()
		var up := right.cross(tangent).normalized()
		rings.append([
			point + right * hw + up * ht,
			point - right * hw + up * ht,
			point - right * hw - up * ht,
			point + right * hw - up * ht,
		])
		# The band is textured by the same top-down projection as everything else,
		# so its UV comes from where each corner sits in x/z — which is what makes
		# the drawn strap land on the modelled strap. Divided back out of `scale`
		# because `uv` works in authoring coordinates. `band_uv_z` pins the z when
		# the arch would otherwise sweep across the drawing — see the header.
		# ⚠️ A PINNED BAND ALSO PULLS ITS x IN. Pinning z alone kept the sample off
		# the drawn band's TOP and BOTTOM keylines but not off its ENDS, so the
		# outermost slice of every cross band still sampled the black outline
		# where the strap meets the sole — which is the dark cap seen on both ends
		# of the Bakya's and the Sike's band. 0.78 keeps the sample inside the
		# painted area across the full width.
		var sample_x: float = point.x / scale
		var sample_z: float = point.z / scale
		if band_uv_z != INF:
			sample_x *= 0.78
			sample_z = band_uv_z
		flats.append(Vector2(sample_x, sample_z))

	for i in range(SEGMENTS):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for corner in range(4):
			var nxt := (corner + 1) % 4
			var ua: Vector2 = uv.call(flats[i].x, flats[i].y)
			var ub: Vector2 = uv.call(flats[i + 1].x, flats[i + 1].y)
			writer.add_quad(a[corner], b[corner], b[nxt], a[nxt], "skin", [],
				[ua, ub, ub, ua])

	# Cap only the start end. On a Y-strap the far end is buried inside the toe
	# post; on a single cross band both ends are buried in the sole.
	var first: Array = rings[0]
	var u0: Vector2 = uv.call(flats[0].x, flats[0].y)
	writer.add_quad(first[3], first[2], first[1], first[0], "skin", [],
		[u0, u0, u0, u0])

func _initialize() -> void:
	print("lata:")
	for spec in _lata_specs():
		_build_lata(spec)
	print("tsinelas:")
	for spec in _tsinelas_specs():
		_build_tsinelas(spec)
	_build_viewmodel_arm()
	# The environment kit, built to docs/Art_Direction.md. In its own file because
	# it is ~25 pieces and this one is where a reader goes to understand the HERO
	# props; burying those under the scenery would be a net loss. Same rules apply
	# to it — determinism, UiTheme constants, and no OFFENSE or DEFENSE hue on a map.
	EnvKit.new().build_all(OUTPUT_DIR)
	print("Model generation complete.")
	quit(0)


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
