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

## How far into the label wrap the can wall stops sampling, at each end.
## The wraps are cropped drawings with a few blank rows of page top and bottom
## (measured: Pasip 12 and 10 of 512, Latang Kalawang 7 and 5), and sampling them
## puts a white band around the can right where the rim meets the lid. 0.03 clears
## the worst of the four with margin. See `_build_lata`'s `wall_uv`.
const UV_V_INSET: float = 0.03

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
			# 0.95 rather than 0.93: measured, that row is the dark grey lid band
			# (76/75/74) while 0.93 is still the brown of the label edge.
			"cap_v": Vector2(0.050, 0.950), "front_u": 0.22,
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
			# ⚠️ RUST, AND FROM THE DARK END OF THE WRAP RATHER THAN THE MIDDLE.
			# 🧑: *"u made the can top ugly, it ssupposed to rusty too"*. The
			# mid-wrap rows this used to sample (0.40/0.62) are a pale grey-brown
			# around 115/96/90, and a cap is a flat horizontal face taking the light
			# square on, so it lit up to near-silver — the one thing a bare rusted
			# tin must not look like. The low rows are the deep corroded end of the
			# drawing: 0.04 measures ~75/55/50 and 0.07 ~100/75/68, so both ends read
			# as rust and the two still differ from each other.
			"cap_v": Vector2(0.040, 0.070), "front_u": 0.50,
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
	# ⚠️ `v` IS INSET AT BOTH ENDS, AND THAT IS THE WHITE RING BETWEEN THE WALL AND
	# THE LID. The wraps are CROPPED DRAWINGS, so their outermost rows are blank
	# page — measured, the Pasip has 12 empty rows of 512 at the top and 10 at the
	# bottom, the Latang Kalawang 7 and 5. Mapping the wall's height straight onto
	# v 0..1 therefore samples that blank margin along the can's very top and
	# bottom edge, and it renders as a hard white band right where the rolled rim
	# meets the lid. 🧑, circling it: *"theres a white space in between lid and
	# shit"*.
	#
	# Squeezing the wall into v 0.03..0.97 keeps every ring inside the drawn area
	# on all four wraps, at the cost of losing 3% of the label off each end — which
	# is 3% of a margin nobody drew anything in. Same root cause as the caps below;
	# this is the ring the cap fix did not cover.
	var wall_uv := func(y: float, angle: float) -> Vector2:
		return Vector2(1.0 - angle / TAU,
			lerpf(UV_V_INSET, 1.0 - UV_V_INSET, y / height))

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
	# ⚠️ A CAP SAMPLES ONE POINT, NOT ONE ROW, AND THAT IS WHAT STOPPED THE LIDS
	# READING AS WHITE. Letting `u` follow the angle sweeps an entire horizontal
	# LINE of the label radially across the disc — a pinwheel of whatever the
	# wrap happens to show at that height, which on the pale rows blows out to
	# flat white under a light hitting a horizontal face square on. 🧑, pointing at
	# it: *"fill that shit in with somehting why is it just white"*.
	#
	# Fixing `u` as well as `v` makes the whole cap one texel, so it renders as a
	# solid stamped can end in the metal colour the human actually drew on that
	# can's rim. Measured at these rows: Pasip 114/115/115 grey, Boyben 76/75/74
	# dark grey, Decades 127/125/125 grey, Latang Kalawang 115/96/90 rust.
	#
	# u = 0.5 is the middle of the wrap, deliberately far from the seam at u = 0/1
	# where a texture's edge filtering can pull in the opposite side of the label.
	var cap_v: Vector2 = spec["cap_v"]
	var base_uv := func(_y: float, _angle: float) -> Vector2:
		return Vector2(0.5, cap_v.x)
	var lid_uv := func(_y: float, _angle: float) -> Vector2:
		return Vector2(0.5, cap_v.y)
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
# ⚠️⚠️ THE SLIPPERS ARE NOT BUILT HERE ANY MORE, AND LEAVING THEM HERE WAS A LIVE
# BUG RATHER THAN CLUTTER.
#
# Four slippers were built procedurally from the human's drawings, rejected four
# times on look, and replaced with sourced CC-BY models converted by
# `tools/models/build_footwear.py` (see its header). The procedural builders were
# left in place for one commit "in case the sourced models have a licence
# problem" — but `_initialize()` still CALLED them, and they wrote to the same
# filenames the converter does.
#
# So every run of this generator silently overwrote the sourced CROCS and SIKE
# with the rejected procedural ones. It went unnoticed because the two pipelines
# were usually run together, in the order that happened to leave the right files
# on disk; the moment this file was re-run alone for an unrelated fix to the can
# lids, the slippers reverted. 🧑, looking at the character screen: *"nigag what
# is this these are not the models we used"*.
#
# ⚠️ TWO GENERATORS MUST NEVER SHARE AN OUTPUT PATH. That is the whole finding.
# The dead code is deleted rather than commented out, because a commented-out
# builder cannot overwrite anything and a "temporarily disabled" one eventually
# gets re-enabled by somebody who does not know why it was off. The procedural
# slippers remain recoverable from git history, which is what history is for.
#
# The slippers now come from ONE place:
#     python tools/models/build_footwear.py

func _initialize() -> void:
	print("lata:")
	for spec in _lata_specs():
		_build_lata(spec)
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
