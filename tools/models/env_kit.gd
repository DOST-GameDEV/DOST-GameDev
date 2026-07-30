extends RefCounted

## The environment kit — checklist 2.1b, built to docs/Art_Direction.md.
##
## Called from generate_all.gd. Lives in its own file rather than as twenty-odd
## more functions in that one, because generate_all.gd is where a reader goes to
## understand the five PROP meshes and burying them under the scenery would be a
## net loss. The rules are unchanged and this file is bound by all of them:
##
##   * DETERMINISM IS THE ACCEPTANCE TEST. No randf(), no time, no iteration over
##     an unordered collection. Every "random" variation here is indexed out of a
##     `const` array — see JITTER_YAW and the crate stack.
##   * COLOURS COME FROM UiTheme CONSTANTS, never a retyped hex.
##   * NO OFFENSE (#f87020) AND NO DEFENSE (#0080e8), ever, on any of it. Orange
##     is offence and blue is defence project-wide, and the world is the largest
##     surface in the frame. See Art_Direction.md §2 rule 1.
##   * NO OUTLINES. The M-4 inverted-hull pass is for characters and hero props.
##     Nothing here goes through _apply_toon_pass and nothing here should.
##
## GEOMETRY CONVENTIONS, so a piece drops into a GridMap with no fixup:
##
##   * Grid cell is 2.0 x 2.0 in XZ. Origin at the CENTRE of the footprint.
##   * BASE AT y = 0. Every piece stands on its own zero, so a map root can be
##     moved vertically in one edit. (Note Main.tscn's floor top is currently
##     y = +0.5, not y = 0 — that is B-82, and Eskinita.tscn puts its own floor
##     top at exactly 0 so the documented convention becomes true.)
##   * ⚠️ A PIECE'S FRONT FACES -Z. THIS LINE USED TO CLAIM +Z AND IT WAS WRONG,
##     which cost Bayan Plaza three backwards landmarks (its open item 1).
##     MEASURED, 2026-07-29, from the geometry in this file rather than from the
##     convention: `_church_facade` puts its doorway and rose window at z = -0.76,
##     `_sari_sari_store` puts its counter and awning at z = -0.62..-1.16, and
##     `_basketball_ring` puts the rim on the origin with the backboard and post
##     BEHIND it at z = +0.52/+0.62 — so a player shoots at it from -Z. Every
##     plaza piece here agrees; only this comment disagreed.
##     The consequence: a piece placed at NEGATIVE z on a map, facing the middle,
##     needs yaw = PI, and a piece at POSITIVE z needs yaw = 0. Bayan Plaza had
##     both backwards, so its church rendered as a blank grey slab and both
##     basketball rings faced the tree line. `build_bayan_plaza.py` now derives
##     the yaw from this rule instead of placing by eye — see its Landmarks block.
##
## `wall_corrugated_leaning` and `tricycle` were held back until the Build lane
## landed checklist 2.1b-0 — an optional `transform: Transform3D` on add_revolve
## and add_extrude. Without it a leaning sheet and an upright wheel are simply
## not expressible: revolve is locked to the Y axis at the origin, and extrude
## only ever extrudes vertically. Both are built now, and they are the only two
## pieces in this file that pass a transform.
##
## ⚠️ A transformed primitive's analytic normals are WRONG — they still describe
## the untransformed surface. `_finish()` calls recalculate_normals(), which
## rebuilds them from the transformed geometry, so this is handled as long as
## every piece goes through _finish(). Do not add one that does not.

const ObjWriter = preload("res://tools/models/obj_writer.gd")

## Seeded, not random. Indexed by piece index so two runs are byte-identical.
const JITTER_YAW: Array[float] = [0.14, -0.21, 0.05, -0.09, 0.18, -0.03]
## Typed, not an inline `[-1.0, 1.0]`: this project runs warnings-as-errors, and
## iterating an untyped array literal infers the loop variable as Variant.
const SIDES: Array[float] = [-1.0, 1.0]

var _dir: String = ""

func build_all(output_dir: String) -> void:
	_dir = output_dir

	# --- ground -------------------------------------------------------------
	_road_tile()
	_road_tile_line()
	_kerb_tile()
	_gutter_tile()
	_plaza_tile()

	# --- boundary -----------------------------------------------------------
	_wall_plain()
	_wall_corrugated()
	_wall_corrugated_leaning()
	_post_electric()
	_laundry_line()
	_sari_sari_store()
	# Four masses, not two, and painted rather than concrete-grey. Heights are
	# whole storeys at 1 unit = 1 m: 9.0 is three storeys plus parapet, 12.0 is
	# four. The old 6.0/8.0 read as two-storey sheds and let far too much sky in
	# at the top of the alley, which is what stopped Eskinita feeling enclosed.
	_building_block("env_building_block_a", 9.0, UiTheme.ENV_PAINT_CREAM)
	_building_block("env_building_block_b", 12.0, UiTheme.ENV_PAINT_TERRA)
	_building_block("env_building_block_c", 9.0, UiTheme.ENV_PAINT_MINT)
	_building_block("env_building_block_d", 12.0, UiTheme.ENV_PAINT_OCHRE)

	# --- interior clutter (all <= 1.0 tall, so an FPP Person aims over it) ---
	_bollard()
	_crate_stack()
	_tire()
	_monobloc_chair()
	_oil_drum()
	_tricycle()

	# --- plaza --------------------------------------------------------------
	_bench()
	_planter()
	_flagpole()
	_tree("env_tree", 4.2, UiTheme.ENV_FOLIAGE)
	_tree("env_tree_far", 4.8, UiTheme.ENV_FOLIAGE_DARK)

	# --- PUNO. The trees that decide what country this is. -------------------
	#
	# ⚠️ THE KIT'S ONLY TREES WERE CONIFERS, AND THAT IS THE SINGLE LOUDEST
	# WRONG THING IN EITHER MAP. build_bayan_plaza.py's open item 7 states it
	# plainly — "every tree in both rings is a Kenney pine, so the plaza reads as
	# a Nordic park with a Philippine church in it" — and Eskinita has the same
	# pines lining the alley. There is no pine on a Philippine residential
	# street. A player sees a hundred conifers before they see the sari-sari
	# store, so the store never gets a chance to say where this is.
	#
	# That item was closed as "cannot be fixed by re-picking a piece — it needs
	# either a new CC0 tree at this poly budget or a generated one". This is the
	# generated one, three times, because one tree repeated is its own problem:
	#
	#   SAGING  — a banana clump. Nothing else in the world looks like it, it is
	#             the cheapest of the three, and it is what actually grows in the
	#             gap between two houses.
	#   NIYOG   — a coconut palm. The tall silhouette, for reading against sky.
	#   MANGGA  — a broadleaf mango. The WIDE, lumpy, low canopy that a conifer
	#             is the exact opposite of, and the one that shades a street.
	#
	# All three are the same four primitives as everything else here, at a
	# comparable triangle count to the cone they replace, so this is a swap and
	# not an addition — see the instance counts in the map builders.
	# ⚠️ NOT CALLED — REJECTED ON THE HUMAN'S CALL, KEPT FOR THE REASONING.
	# _puno_saging(), _puno_niyog() and _puno_mangga() are complete and correct
	# below, and both maps used them for one pass. The human rejected them twice on
	# sight ("they dont look like trees, js use different assets"), so both maps now
	# use the Fantasy Town kit's rounded broadleaf trees instead — which still keeps
	# the conifers out, and that was the actual cultural defect (open item 7).
	#
	# The FUNCTIONS stay because what they encode is expensive to re-derive and is
	# not about these three meshes: `_blade` (a leaf that attaches to its stem —
	# see its own note on the detached-corner bug), the stacked-segment lean that
	# `add_revolve` cannot do on its own, and the overlapping-blob canopy that
	# stops a revolve reading as a lollipop. Anyone revisiting palm-and-banana
	# specificity starts from working geometry rather than from scratch.
	# The .obj files are NOT emitted, so nothing unused ships.
	# Plants in cut-open paint tins, which is what a Philippine doorstep has
	# instead of a garden. Interior tier at 0.62, so it can never block an aim.
	_halaman_lata()
	# The GI lean-to every house extends itself with. Roofs the alley edge.
	_atip_yero()
	_church_facade()
	_basketball_ring()
	# The plaza CENTREPIECE set — checklist 2.4, the reference-photo redress.
	# A real Philippine town plaza is a tiered monument on a plinth inside an
	# iron railing ring, with clipped hedges in planters, a church with a BELL
	# TOWER, and a municipal hall with a red roof behind. Every one of those is
	# built here out of the same four primitives the rest of the kit uses, so
	# nothing new is imported and the poly budget and palette are unchanged —
	# see the asset note in build_bayan_plaza.py's header.
	_monument()
	_railing()
	_planter_hedge()
	_bell_tower()
	_municipal_hall()

	# --- field markings (serve BOTH round-win modes) ------------------------
	_chalk_piko()
	_chalk_tao()
	_chalk_bulaklak()
	_chalk_gulo()
	_base_circle_decal()
	_throwing_line_decal()
	_team_side_decal()


# =============================================================================
# Helpers
# =============================================================================

## A rectangle in the XZ plane, wound to match the convention add_extrude wants —
## the same handedness as the tsinelas sole outline: the +X side runs toward +Z.
func _rect(cx: float, cz: float, w: float, d: float) -> PackedVector2Array:
	var hw := w * 0.5
	var hd := d * 0.5
	return PackedVector2Array([
		Vector2(cx + hw, cz - hd),
		Vector2(cx + hw, cz + hd),
		Vector2(cx - hw, cz + hd),
		Vector2(cx - hw, cz - hd),
	])

## The same rectangle, yawed about its own centre. A rotation preserves winding,
## so this stays legal for add_extrude. This is how the crate stack looks tumbled
## without a single random number.
func _rect_yaw(cx: float, cz: float, w: float, d: float, yaw: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := cos(yaw)
	var s := sin(yaw)
	for p in _rect(0.0, 0.0, w, d):
		out.append(Vector2(cx + p.x * c - p.y * s, cz + p.x * s + p.y * c))
	return out

## An N-gon in the XZ plane, for round things that are EXTRUDED rather than
## revolved — a revolve is locked to the origin, an extruded n-gon is not, so
## this is how a post sits off-centre inside its own piece.
func _ngon(cx: float, cz: float, r: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		out.append(Vector2(cx + r * cos(a), cz + r * sin(a)))
	return out

## One axis-aligned box. Most of a street is boxes.
func _box(w: ObjWriter, cx: float, cz: float, width: float, depth: float,
		y0: float, y1: float, material: String) -> void:
	w.add_extrude(_rect(cx, cz, width, depth), y0, y1, material)

## A flat, upward-facing panel — road markings, decals, hung cloth.
##
## ⚠️ WINDING. For a face whose normal is +Y the four corners go CLOCKWISE in the
## (x, z) plane read as a normal 2D plane. Measured, not assumed: (0,0) ->
## (0,1) -> (1,1) -> (1,0) gives (b-a).cross(c-a) = +Y, and the tsinelas strap
## quads already in generate_all.gd compute out to the same handedness. Reverse
## it and the decal is invisible from above — it does not error, it just is not
## there.
func _flat_rect(w: ObjWriter, cx: float, cz: float, width: float, depth: float,
		y: float, material: String) -> void:
	var hw := width * 0.5
	var hd := depth * 0.5
	w.add_quad(
		Vector3(cx - hw, y, cz - hd),
		Vector3(cx - hw, y, cz + hd),
		Vector3(cx + hw, y, cz + hd),
		Vector3(cx + hw, y, cz - hd),
		material)

## A sagging cable, as a ribbon of quads rather than a swept tube.
##
## Deliberate: a tube needs a generator primitive that does not exist, while a
## ribbon needs only add_quad, and at the distance any wire in this game is ever
## seen the two are the same image for a fifth of the triangles. The sag is a
## half-sine, which is not a real catenary and is indistinguishable from one at
## this scale.
func _wire(w: ObjWriter, from: Vector3, to: Vector3, sag: float,
		half_width: float, segments: int, material: String) -> void:
	var flat := Vector2(to.x - from.x, to.z - from.z)
	if flat.length() < 0.0001:
		return
	var perp := Vector2(-flat.normalized().y, flat.normalized().x) * half_width
	for i in range(segments):
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var p0 := from.lerp(to, t0)
		var p1 := from.lerp(to, t1)
		p0.y -= sag * sin(PI * t0)
		p1.y -= sag * sin(PI * t1)
		var a0 := Vector3(p0.x + perp.x, p0.y, p0.z + perp.y)
		var a1 := Vector3(p1.x + perp.x, p1.y, p1.z + perp.y)
		var b1 := Vector3(p1.x - perp.x, p1.y, p1.z - perp.y)
		var b0 := Vector3(p0.x - perp.x, p0.y, p0.z - perp.y)
		w.add_quad(a0, a1, b1, b0, material)
		# ⚠️ AND AGAIN, REVERSED. Found by rendering: a single ribbon faces +Y and
		# is backface-culled from underneath — and an overhead wire is ALWAYS seen
		# from underneath, so every wire in the map was invisible while the .obj
		# looked perfectly correct. Sixteen triangles to fix; nothing else in the
		# kit is single-sided.
		w.add_quad(b0, b1, a1, a0, material)

func _finish(w: ObjWriter, file_name: String, smooth_deg: float = 40.0) -> void:
	w.recalculate_normals(smooth_deg)
	w.write(_dir + file_name)
	print("  ", file_name)

# =============================================================================
# Ground
# =============================================================================

func _road_tile() -> void:
	var w := ObjWriter.new("RoadTile")
	w.set_material("asphalt", UiTheme.ENV_ASPHALT)
	_box(w, 0, 0, 2.0, 2.0, 0.0, 0.06, "asphalt")
	_finish(w, "env_road_tile")

## The same tile with a lane dash. Lane markings are on the board's Metro
## reference, and they are the only thing that gives the eye a sense of scale on
## an otherwise featureless plane.
func _road_tile_line() -> void:
	var w := ObjWriter.new("RoadTileLine")
	w.set_material("asphalt", UiTheme.ENV_ASPHALT)
	w.set_material("paint", UiTheme.PANEL)
	_box(w, 0, 0, 2.0, 2.0, 0.0, 0.06, "asphalt")
	_flat_rect(w, 0, 0, 0.10, 1.20, 0.062, "paint")
	_finish(w, "env_road_tile_line")

## Build this before anything decorative. A 15cm step between road and walkway is
## the cheapest depth cue in the whole kit — it is what stops a flat plane
## reading as a flat plane.
func _kerb_tile() -> void:
	var w := ObjWriter.new("KerbTile")
	w.set_material("concrete", UiTheme.ENV_CONCRETE)
	_box(w, 0, 0, 2.0, 0.35, 0.0, 0.15, "concrete")
	_finish(w, "env_kerb_tile")

func _gutter_tile() -> void:
	var w := ObjWriter.new("GutterTile")
	w.set_material("asphalt", UiTheme.ENV_ASPHALT)
	w.set_material("channel", UiTheme.ENV_CONCRETE_DARK)
	# Road surface, then the channel dropped below it, then the far lip. The dark
	# line along a kerb is what makes a street look drained and lived in.
	_box(w, 0.0, -0.325, 2.0, 1.35, 0.0, 0.06, "asphalt")
	_box(w, 0.0, 0.525, 2.0, 0.35, 0.0, 0.02, "channel")
	_box(w, 0.0, 0.850, 2.0, 0.30, 0.0, 0.15, "channel")
	_finish(w, "env_gutter_tile")

func _plaza_tile() -> void:
	var w := ObjWriter.new("PlazaTile")
	w.set_material("concrete", UiTheme.ENV_CONCRETE)
	w.set_material("score", UiTheme.PANEL)
	_box(w, 0, 0, 2.0, 2.0, 0.0, 0.06, "concrete")
	# Slab joints. They do for a plaza what lane markings do for a road.
	_flat_rect(w, 0.0, -0.985, 2.0, 0.03, 0.062, "score")
	_flat_rect(w, -0.985, 0.0, 0.03, 2.0, 0.062, "score")
	_finish(w, "env_plaza_tile")

# =============================================================================
# Boundary
# =============================================================================

## 3.0 tall, which is decisively above the measured 1.25-unit FPP eye height —
## see Art_Direction.md §2. The bottom 0.4 is a darker damp course, and
## that one extra extrude is the whole difference between a grey rectangle and a
## Manila wall.
func _wall_plain() -> void:
	var w := ObjWriter.new("WallPlain")
	w.set_material("concrete", UiTheme.ENV_CONCRETE)
	w.set_material("skirt", UiTheme.ENV_CONCRETE_DARK)
	_box(w, 0, 0, 2.0, 0.25, 0.40, 3.00, "concrete")
	_box(w, 0, 0, 2.0, 0.25, 0.00, 0.40, "skirt")
	_finish(w, "env_wall_plain")

## THE piece. Corrugated galvanised iron reads as the Philippines louder than
## anything else in the set, and it costs almost nothing: the corrugation is just
## a zigzag in the extrusion outline.
##
## The outline runs the zigzag along the front (low Z) from -X to +X, then
## returns flat along the back. That ordering is what keeps it wound the way
## add_extrude needs — at +X it steps from front to back, i.e. toward +Z, which
## is the same handedness as every other outline here.
## Shared by the plumb sheet and the leaning one, so the two can never drift
## into different corrugation pitches — which would be visible the moment they
## sit next to each other in a wall line.
func _corrugated_outline() -> PackedVector2Array:
	const RIDGES := 17 ## 8 full corrugations across 2 units.
	const AMPLITUDE := 0.11 ## Was 0.05 and rendered as a blank panel.
	var outline := PackedVector2Array()
	for i in range(RIDGES):
		var x := -1.0 + 2.0 * float(i) / float(RIDGES - 1)
		outline.append(Vector2(x, -AMPLITUDE if i % 2 == 0 else 0.0))
	outline.append(Vector2(1.0, 0.10))
	outline.append(Vector2(-1.0, 0.10))
	return outline

func _wall_corrugated() -> void:
	var w := ObjWriter.new("WallCorrugated")
	w.set_material("sheet", UiTheme.ENV_GI_SHEET)
	w.set_material("rust", UiTheme.ENV_RUST)

	var outline := _corrugated_outline()
	w.add_extrude(outline, 0.30, 2.40, "sheet")
	# Rust at the base, where a real sheet rots first because it stands in water.
	w.add_extrude(outline, 0.00, 0.30, "rust")
	# ⚠️ 22 degrees, not the usual 40. The whole read of this piece is that
	# adjacent corrugation facets catch the light DIFFERENTLY. At 40 the
	# smoothing pass averaged them into one flat surface and the sheet rendered
	# as a blank panel — verified by render, twice, before and after.
	_finish(w, "env_wall_corrugated", 22.0)

## Post, cross-arm, insulators and a drooping service wire. The wire is the point:
## the overhead layer converts an open box into a roofed street for about sixty
## triangles, and it is the highest read-per-triangle piece in the kit.
##
## The wire runs to where the NEXT post would be, 6 units along +X, so a row of
## these strings itself together without any per-instance work in the map.
func _post_electric() -> void:
	var w := ObjWriter.new("PostElectric")
	w.set_material("timber", UiTheme.ENV_WOOD_DARK)
	w.set_material("wire", UiTheme.INK)

	# Plan item E, scale fix. Was 4.50 tall against a 1.6 Person - barely three
	# times head height, where a real Philippine post is 8-9 m. The whole kit is
	# authored at 1 unit = 1 m and the posts were the loudest survivor: they set
	# the vertical rhythm of the alley, and short ones made the street read as a
	# model village. 7.2 keeps the wires readable overhead without pushing them
	# out of frame for an FPP eye at 1.25. Every internal height below moved with
	# it rather than being re-guessed.
	w.set_material("drum", UiTheme.ENV_CONCRETE_DARK)
	w.set_material("rust", UiTheme.ENV_RUST)

	_box(w, 0, 0, 0.24, 0.24, 0.0, 7.20, "timber")
	_box(w, 0, 0, 1.60, 0.14, 6.10, 6.24, "timber")
	for i in range(3):
		var x := -0.6 + 0.6 * float(i)
		_box(w, x, 0, 0.09, 0.09, 6.24, 6.38, "wire")
		_wire(w, Vector3(x, 6.35, 0.0), Vector3(x + 6.0, 6.35, 0.0), 0.55, 0.025, 8, "wire")

	# =====================================================================
	# ⚠️ THE TANGLE. THIS IS THE MOST RECOGNISABLE SILHOUETTE A PHILIPPINE
	# STREET HAS, and three tidy parallel lines is not it.
	# =====================================================================
	#
	# The three wires above are a correctly-built utility line for anywhere in
	# the world. What makes the overhead read as Manila rather than as a suburb
	# is that it is obviously ACCRETED: a second and third cross-arm added below
	# the first as more services were hung, a transformer drum bolted to the
	# post, communications cable at a different sag from the power above it, and
	# a coil of slack left hanging where somebody will come back for it.
	#
	# ⚠️ ALL OF IT IS INSIDE THE EXISTING PIECE — no new instance, no new mesh,
	# no new draw call anywhere on either map. The map places exactly the same
	# twelve posts it placed before; each one just carries more silhouette. That
	# is the whole reason this went here rather than into a new `Kable` prop:
	# R-33's budget line is "ADD SPECIFICITY, NOT DENSITY", and geometry inside a
	# piece that is already drawn is free of density by definition.
	#
	# The span stays 6.0 for every added line, because `build_eskinita.py` spaces
	# the posts at exactly POST_SPAN = 6.0 so a row strings itself together. A
	# wire here that ran any other distance would end in mid-air, which is the
	# 2026-07-29 playtest bug ("the electric pole wires are just floating").

	# The transformer. One drum, off to one side, at the height they actually
	# hang. Nothing else in the kit reads as "utility" this fast.
	w.add_extrude(_ngon(0.30, 0.0, 0.26, 8), 4.85, 5.62, "drum")
	_box(w, 0.30, 0, 0.14, 0.14, 5.62, 5.78, "rust")
	_box(w, 0.08, 0, 0.44, 0.10, 5.10, 5.22, "timber")

	# A second cross-arm, shorter and lower — the one added years later.
	_box(w, -0.10, 0, 1.10, 0.12, 5.52, 5.64, "timber")
	for i in range(2):
		var x2 := -0.48 + 0.72 * float(i)
		_box(w, x2, 0, 0.08, 0.08, 5.64, 5.74, "wire")
		# ⚠️ A DIFFERENT SAG FROM THE POWER LINES ABOVE, and that is the detail
		# that sells it. Parallel wires at one sag read as a drawn grid; real
		# comms cable is hung slacker than power and crosses it visually
		# somewhere in the middle of every span.
		_wire(w, Vector3(x2, 5.70, 0.0), Vector3(x2 + 6.0, 5.70, 0.0),
			0.92, 0.022, 8, "wire")

	# The messy tier: three low service drops, each at its own height and sag, so
	# no two spans in the frame are the same curve.
	var drops := [[5.05, 1.25], [4.78, 0.78], [5.30, 1.55]]
	for i in range(drops.size()):
		var y: float = drops[i][0]
		var sag: float = drops[i][1]
		var off := -0.22 + 0.20 * float(i)
		_wire(w, Vector3(off, y, 0.0), Vector3(off + 6.0, y, 0.0),
			sag, 0.018, 8, "wire")

	# The coil of slack. Four loops of leftover cable lashed to the post — the
	# single most "somebody will come back for this" object on a Philippine
	# street, and it is four flat rings.
	for i in range(4):
		var ry := 4.05 + 0.11 * float(i)
		var rr := 0.30 - 0.03 * float(i)
		w.add_revolve(PackedVector2Array([
			Vector2(rr, ry), Vector2(rr + 0.022, ry + 0.02),
			Vector2(rr, ry + 0.05),
		]), 9, "wire", true, Callable(),
			Transform3D(Basis.IDENTITY, Vector3(-0.16, 0.0, 0.0)))
	_finish(w, "env_post_electric")

## Sampay. This is the Barong Barong reference folded into Eskinita rather than
## spent on a third map that would never be built — see Art_Direction.md
## §1. Strung ACROSS the alley overhead, never along it.
func _laundry_line() -> void:
	var w := ObjWriter.new("LaundryLine")
	w.set_material("timber", UiTheme.ENV_WOOD_DARK)
	w.set_material("cloth", UiTheme.ENV_TARP)
	w.set_material("cloth_pale", UiTheme.ENV_PAINT_CREAM)
	w.set_material("cloth_mint", UiTheme.ENV_PAINT_MINT)
	w.set_material("cloth_grey", UiTheme.ENV_CONCRETE)

	# ⚠️ NO POSTS OF ITS OWN, and it spans 16 units rather than sitting on the
	# 2-unit grid. Both deliberate, both found by rendering: this piece is strung
	# BETWEEN the two wall lines, so posts of its own stood in the middle of the
	# road holding up a line nobody could see. A sampay hangs off the buildings.
	# ⚠️ SPANS THE FULL ALLEY, WALL FACE TO WALL FACE (+/-8.6), NOT +/-8.0.
	# Playtest 2026-07-29: "sampayan is just floating in the air ... anchor
	# clothes line to something". It ended 600mm short of the house fronts on
	# both sides, so the line visibly began and ended in mid-air. The facades
	# now sit on the collision plane at x = +/-8.6 (build_eskinita.WALL_FACE_X),
	# so reaching exactly that far is what anchors it into the walls.
	_wire(w, Vector3(-7.95, 2.62, 0.0), Vector3(7.95, 2.62, 0.0), 0.42, 0.025, 12, "cloth")
	# A visible tie-off block at each end, so the line reads as FASTENED to the
	# house rather than passing through it.
	# ⚠️ THE ENDS ARE BURIED IN THE WALL, NOT BUTTED AGAINST IT. Playtest
	# 2026-07-29: "u made an anchor yes but those anchors float". Ending exactly
	# on the facade plane (x = +/-8.6) leaves nothing holding the line the moment
	# the wall is even slightly set back — and in a DRIVEWAY bay there is no wall
	# at that z at all, so the anchor hung in open air. The wire now runs to
	# +/-9.3, well past the facade and into the house, and the tie-off block
	# straddles the plane rather than stopping on it. Geometry inside a wall is
	# invisible; a 700mm gap is not.
	# The lashing where the line meets the post. Straddles the post centre
	# (build_eskinita places the posts at x = +/-7.75) so it reads as tied ON
	# rather than butted against, and there is no z at which it can miss — the
	# posts are always there, which walls are not.
	for _sx in SIDES:
		_box(w, _sx * 7.75, 0.0, 0.42, 0.42, 2.44, 2.80, "timber")

	# ⚠️ THE GARMENTS ARE SEGMENTED DOUBLE-SIDED SHEETS NOW, NOT EXTRUDED BOXES,
	# AND THAT IS THE ACTUAL FIX FOR "STIFF, LIFELESS CARDBOARD BOXES".
	#
	# They used to be `add_extrude(_rect_yaw(...), y - 0.62, y)` — a solid
	# rectangular prism 30 mm thick with exactly two rings of vertices, top and
	# bottom. It read as cardboard because it WAS cardboard: a closed box with
	# hard lit edges and no interior geometry at all.
	#
	# Two things follow from that, and only doing one of them fixes nothing:
	#   1. A box has no vertices between its hem and its pin, so the wind shader
	#      in `assets/models/materials/wind_cloth.gdshader` has nothing to bend.
	#      It could only translate the whole prism sideways, which looks worse
	#      than not moving. CLOTH_SEGMENTS gives it something to bend.
	#   2. Real hung laundry is a SHEET. Cloth is emitted as two-sided quads
	#      (see `_wire`'s own note about single-sided ribbons rendering invisible
	#      from below) with a slight bow across the width, so the light breaks
	#      across it instead of landing flat.
	#
	# The hem is deliberately not level: `_hem_drop` is a fixed table, so a row
	# of garments has different lengths without any randomness — the generator's
	# determinism rule (obj_writer.gd's header) forbids randf() outright.
	# ⚠️ THE SATURATED CLOTHS ARE GONE, AND THE FIRST PHASE 8 RENDER IS WHY.
	# `cloth_warm` was UiTheme.HIGHLIGHT (#f8d028) and `cloth_rust` was ENV_RUST
	# (#a65a3a). Hung overhead at eye level, seventy of them across the alley,
	# they came out as rows of vivid yellow and orange flags — the loudest thing
	# in the frame, and the orange sits at hue ~17 deg against OFFENSE #f87020's
	# ~20 deg, which is exactly the collision Art_Direction.md Part 2 rule 1
	# forbids on environment art. Real sampay is faded anyway: bleached whites,
	# pale mint, washed grey. All four below are already-approved ENV_* facade
	# constants, so this stays inside the palette rather than inventing one.
	const CLOTHS: Array[String] = ["cloth", "cloth_pale", "cloth_mint", "cloth",
		"cloth_grey", "cloth_pale", "cloth_mint"]
	const CLOTH_SEGMENTS := 5
	# Smaller than the first pass. At 0.24 half-width and 0.70 drop these read as
	# banners rather than as laundry — they dominated the street from every angle.
	const HEM_DROP: Array[float] = [0.46, 0.38, 0.52, 0.42, 0.49, 0.36, 0.44]
	const CLOTH_HALF_W: Array[float] = [0.16, 0.13, 0.17, 0.14, 0.16, 0.12, 0.15]
	for i in range(7):
		var t := (float(i) + 0.5) / 7.0
		var x := lerpf(-8.2, 8.2, t)
		var y_top := 2.62 - 0.42 * sin(PI * t)
		var yaw: float = JITTER_YAW[i % JITTER_YAW.size()]
		var half_w: float = CLOTH_HALF_W[i]
		var drop: float = HEM_DROP[i]
		var material: String = CLOTHS[i]
		# The garment hangs across the line, so its width runs along the line's
		# own axis (+X) rotated by `yaw`, and it drops in -Y.
		var along := Vector3(cos(yaw), 0.0, sin(yaw)) * half_w
		var bow := Vector3(-sin(yaw), 0.0, cos(yaw)) * (half_w * 0.22)
		for s in range(CLOTH_SEGMENTS):
			var f0 := float(s) / float(CLOTH_SEGMENTS)
			var f1 := float(s + 1) / float(CLOTH_SEGMENTS)
			var y0 := y_top - drop * f0
			var y1 := y_top - drop * f1
			# A hanging sheet is widest at the hem and gathered at the pin.
			var w0 := lerpf(0.82, 1.0, f0)
			var w1 := lerpf(0.82, 1.0, f1)
			# Bow OUT toward the middle of the drop, so the sheet is not a plane.
			var b0 := sin(PI * f0)
			var b1 := sin(PI * f1)
			var p0a := Vector3(x, y0, 0.0) - along * w0 + bow * b0
			var p0b := Vector3(x, y0, 0.0) + along * w0 + bow * b0
			var p1a := Vector3(x, y1, 0.0) - along * w1 + bow * b1
			var p1b := Vector3(x, y1, 0.0) + along * w1 + bow * b1
			w.add_quad(p0a, p0b, p1b, p1a, material)
			# ⚠️ AND AGAIN, REVERSED — same reason as `_wire`. A single-sided
			# sheet is backface-culled from one side, and a sampay strung across
			# an alley is walked under and looked at from BOTH sides every round.
			w.add_quad(p1a, p1b, p0b, p0a, material)
	# 0.0 smoothing: a garment's fold lines are the read. Averaging normals
	# across them turns the sheet back into a soft blob, which is most of what
	# made the old version look like a lump rather than cloth.
	_finish(w, "env_laundry_line", 0.0)

## The narrative centre of Eskinita. A wall with a counter in it is a street; a
## wall without one is a corridor. Barred window, tarp awning, hanging sachets.
func _sari_sari_store() -> void:
	var w := ObjWriter.new("SariSariStore")
	w.set_material("concrete", UiTheme.ENV_CONCRETE)
	w.set_material("timber", UiTheme.ENV_WOOD)
	w.set_material("dark", UiTheme.INK)
	w.set_material("tarp", UiTheme.ENV_TARP)
	w.set_material("stripe", UiTheme.HIGHLIGHT)

	_box(w, 0, 0, 2.0, 1.0, 0.0, 2.60, "concrete")
	# Counter shelf, at the height a sari-sari counter actually is.
	_box(w, 0, -0.62, 2.0, 0.40, 0.82, 0.98, "timber")
	# Window recess, then the bars. The bars are the read — an unbarred opening
	# reads as a garage.
	_box(w, 0, -0.50, 1.20, 0.06, 1.10, 1.90, "dark")
	for i in range(5):
		_box(w, -0.48 + 0.24 * float(i), -0.54, 0.04, 0.04, 1.10, 1.90, "timber")
	# Awning: flat, not sloping. A slope needs a transform ObjWriter does not have
	# yet (2.1b-0), and flat is honest rather than approximated badly.
	_box(w, 0, -0.85, 2.40, 0.70, 2.02, 2.10, "tarp")
	for i in range(3):
		_box(w, -0.70 + 0.70 * float(i), -0.85, 0.22, 0.70, 2.10, 2.12, "stripe")
	# The strip of hanging sachets every one of these has.
	for i in range(6):
		_box(w, -0.55 + 0.22 * float(i), -1.16, 0.10, 0.02, 1.55, 1.95, "stripe")
	_finish(w, "env_sari_sari_store")

## Layer 2 of the boundary — plain masses standing behind the wall line so the
## edge has depth rather than a single row. Windows are PAINTED, not modelled: at
## this distance a hole and a dark rectangle are the same image for a tenth of
## the cost.
## A background mass standing behind the wall line. Never entered, never
## collided with at close range — its entire job is to close the sky off the
## top of the alley and give the eye something with STOREYS in it, so the street
## reads as a street rather than as a floor with props on it.
##
## ⚠️ WINDOWS GO ON ALL FOUR FACES. They used to be emitted only on the -Z face,
## so three sides of every building in the map were blank slabs — and because
## `build_eskinita.py` yaws every Layer-2 mass by ±0.22-0.35 rad and stands them
## on BOTH sides of the road, the blank sides were what the player actually saw
## most of the time. That single omission is most of why the set read as
## untextured greybox.
##
## ⚠️ HEIGHTS ARE IN METRES AND MUST STAY THAT WAY. The whole environment kit is
## authored at 1 unit = 1 m — the monobloc chair is 0.89, the oil drum 0.90, the
## basketball ring 3.85, all within centimetres of the real objects. A storey is
## ~3 m, so `height` should always be a whole number of storeys plus a parapet.
## Do not tune these by eye against the props: the props are the things that are
## wrong (see the proportion audit), not the set.
func _building_block(file_name: String, height: float, body: Color) -> void:
	var w := ObjWriter.new("BuildingBlock")
	w.set_material("body", body)
	w.set_material("band", UiTheme.ENV_CONCRETE_DARK)
	w.set_material("plinth", UiTheme.ENV_PAINT_PLINTH)
	w.set_material("window", UiTheme.INK)

	_box(w, 0, 0, 4.0, 3.0, 0.0, height, "body")
	# Ground-floor shopfront: darker, and proud of the body so it casts its own
	# shadow line. Real streets always have this break; without it a building is
	# one flat colour from pavement to roof.
	_box(w, 0, 0, 4.08, 3.08, 0.0, 2.4, "plinth")
	# Roof parapet, same trick at the top so the silhouette is not a bare cut.
	_box(w, 0, 0, 4.06, 3.06, height - 0.45, height - 0.25, "band")

	var rows := int((height - 3.2) / 2.6)
	var hw := 0.31
	var hh := 0.45
	for row in range(rows):
		var y := 3.55 + 2.6 * float(row)
		# Long faces (+/-Z): three windows each.
		for col in range(3):
			var cx := -1.2 + 1.2 * float(col)
			_window(w, Vector3(cx, y, -1.51), Vector3(hw, 0, 0), Vector3(0, hh, 0))
			_window(w, Vector3(cx, y, 1.51), Vector3(hw, 0, 0), Vector3(0, hh, 0))
		# Short faces (+/-X): two windows each.
		for col in range(2):
			var cz := -0.7 + 1.4 * float(col)
			_window(w, Vector3(-2.01, y, cz), Vector3(0, 0, hw), Vector3(0, hh, 0))
			_window(w, Vector3(2.01, y, cz), Vector3(0, 0, hw), Vector3(0, hh, 0))
	_finish(w, file_name)

## A window pane, emitted with BOTH windings.
##
## ⚠️ Deliberately double-wound rather than carefully single-wound. A window has
## to appear on four differently-facing walls, and `add_revolve`/`add_quad`
## normal direction follows vertex order — the same rule that made every
## overhead wire invisible once already, because a single-sided quad is culled
## from the side you happen to be looking from. Four faces means four chances to
## get it backwards and no error when you do.
##
## The cost of being sure is two extra triangles per pane. A building carries at
## most 40 panes, so ~80 triangles on a piece that is never closer than the far
## side of a wall. The back-facing copy is culled whenever the front one is
## visible, so nothing ever z-fights.
func _window(w: ObjWriter, centre: Vector3, right: Vector3, up: Vector3) -> void:
	var a := centre - right - up
	var b := centre - right + up
	var c := centre + right + up
	var d := centre + right - up
	w.add_quad(a, b, c, d, "window")
	w.add_quad(d, c, b, a, "window")

## A painted rectangle on a wall facing -Z. Same winding care as _flat_rect, one
## axis over.
func _flat_rect_vertical(w: ObjWriter, cx: float, z: float, width: float,
		height: float, y_bottom: float, material: String) -> void:
	var hw := width * 0.5
	w.add_quad(
		Vector3(cx - hw, y_bottom, z),
		Vector3(cx - hw, y_bottom + height, z),
		Vector3(cx + hw, y_bottom + height, z),
		Vector3(cx + hw, y_bottom, z),
		material)

# =============================================================================
# Interior clutter — everything here is <= 1.0 tall on purpose
# =============================================================================

## 0.85 — the tallest thing allowed loose in the play area, because the FPP eye
## is at 1.25 and a Person has to be able to aim over it.
func _bollard() -> void:
	var w := ObjWriter.new("Bollard")
	w.set_material("concrete", UiTheme.ENV_CONCRETE)
	w.set_material("band", UiTheme.HIGHLIGHT)
	w.add_revolve(PackedVector2Array([
		Vector2(0.00, 0.00), Vector2(0.10, 0.00),
		Vector2(0.10, 0.58),
	]), 12, "concrete")
	w.add_revolve(PackedVector2Array([
		Vector2(0.10, 0.58), Vector2(0.10, 0.70),
	]), 12, "band")
	w.add_revolve(PackedVector2Array([
		Vector2(0.10, 0.70), Vector2(0.10, 0.80),
		Vector2(0.07, 0.85), Vector2(0.00, 0.86),
	]), 12, "concrete")
	_finish(w, "env_bollard")

## Askew is the entire point. Three axis-aligned boxes read as programmer art;
## the same three yawed out of the seeded table read as a street.
func _crate_stack() -> void:
	var w := ObjWriter.new("CrateStack")
	w.set_material("timber", UiTheme.ENV_WOOD)
	w.add_extrude(_rect_yaw(0.00, 0.00, 0.60, 0.60, JITTER_YAW[0]), 0.00, 0.32, "timber")
	w.add_extrude(_rect_yaw(0.04, -0.03, 0.55, 0.55, JITTER_YAW[1]), 0.32, 0.62, "timber")
	w.add_extrude(_rect_yaw(-0.03, 0.05, 0.50, 0.50, JITTER_YAW[2]), 0.62, 0.90, "timber")
	_finish(w, "env_crate_stack")

## Lying flat, which is what makes it expressible at all — a flat tire IS a
## Y-axis revolve. An upright one is not, and waits on 2.1b-0.
func _tire() -> void:
	var w := ObjWriter.new("Tire")
	w.set_material("rubber", UiTheme.ENV_RUBBER)
	w.add_revolve(PackedVector2Array([
		Vector2(0.18, 0.00), Vector2(0.38, 0.00),
		Vector2(0.42, 0.11), Vector2(0.38, 0.22),
		Vector2(0.18, 0.22), Vector2(0.16, 0.11),
		Vector2(0.18, 0.00),
	]), 14, "rubber")
	_finish(w, "env_tire")

## The white plastic monobloc. It is on the board's Metro reference explicitly,
## and it is instantly recognisable to anyone who has ever been to a Philippine
## street corner.
func _monobloc_chair() -> void:
	var w := ObjWriter.new("MonoblocChair")
	w.set_material("plastic", UiTheme.CARD)
	for sx in SIDES:
		for sz in SIDES:
			_box(w, 0.17 * sx, 0.17 * sz, 0.05, 0.05, 0.0, 0.44, "plastic")
	_box(w, 0, 0, 0.42, 0.42, 0.44, 0.50, "plastic")
	_box(w, 0, 0.20, 0.42, 0.06, 0.50, 0.89, "plastic")
	_finish(w, "env_monobloc_chair")

func _oil_drum() -> void:
	var w := ObjWriter.new("OilDrum")
	w.set_material("rust", UiTheme.ENV_RUST)
	w.set_material("rim", UiTheme.INK)
	w.add_revolve(PackedVector2Array([
		Vector2(0.00, 0.00), Vector2(0.30, 0.00),
		Vector2(0.30, 0.26),
	]), 14, "rust")
	w.add_revolve(PackedVector2Array([
		Vector2(0.30, 0.26), Vector2(0.32, 0.30), Vector2(0.30, 0.34),
	]), 14, "rim")
	w.add_revolve(PackedVector2Array([
		Vector2(0.30, 0.34), Vector2(0.30, 0.86),
		Vector2(0.28, 0.90), Vector2(0.00, 0.90),
	]), 14, "rust")
	_finish(w, "env_oil_drum")

## The same sheet, off plumb. Every fourth bay of the wall line uses this one,
## and it is the cheapest thing in the kit that stops a boundary reading as a
## level editor — nothing in an eskinita is straight, and a wall of identical
## plumb panels announces that a machine placed them.
##
## The lean is about X (the sheet is wide along X, thin along Z), so the top
## edge tips ~0.25 units in Z while the base stays put.
func _wall_corrugated_leaning() -> void:
	var w := ObjWriter.new("WallCorrugatedLeaning")
	w.set_material("sheet", UiTheme.ENV_GI_SHEET)
	w.set_material("rust", UiTheme.ENV_RUST)
	var outline := _corrugated_outline()
	var lean := Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(6.0)), Vector3.ZERO)
	w.add_extrude(outline, 0.30, 2.40, "sheet", lean)
	w.add_extrude(outline, 0.00, 0.30, "rust", lean)
	_finish(w, "env_wall_corrugated_leaning", 22.0)

## Silhouette grade, and it is meant to be. This is read from four units away and
## never inspected — a tricycle is the single piece that makes an alley a
## PHILIPPINE alley rather than any alley, and that is carried entirely by the
## outline: a motorcycle with a roofed sidecar bolted to its side.
##
## WAIST-COVER TIER at 1.25 tall, so per Art_Direction.md §2 it goes at
## the boundary or as deliberate cover — never scattered in the play area, where
## it would block an FPP Person whose eye is at 1.25.
##
## The three wheels are the reason this piece needed 2.1b-0: a wheel stands
## upright, so it is a revolve about a HORIZONTAL axis, and add_revolve only
## spins around Y at the origin.
func _tricycle() -> void:
	var w := ObjWriter.new("Tricycle")
	w.set_material("frame", UiTheme.ENV_RUST)
	w.set_material("roof", UiTheme.ENV_GI_SHEET)
	w.set_material("rubber", UiTheme.ENV_RUBBER)
	w.set_material("trim", UiTheme.HIGHLIGHT)

	# Motorcycle half, on -X. Sidecar half, on +X.
	_box(w, -0.34, -0.05, 0.30, 1.30, 0.34, 0.72, "frame")
	_box(w, -0.34, 0.18, 0.34, 0.46, 0.72, 0.82, "rubber")   # saddle
	_box(w, -0.34, -0.62, 0.52, 0.08, 0.86, 0.94, "frame")   # handlebar
	_box(w, 0.32, 0.10, 0.78, 0.92, 0.20, 0.86, "frame")     # sidecar body
	_box(w, 0.32, 0.10, 0.84, 0.98, 0.86, 0.92, "trim")      # sidecar lip
	for sz in SIDES:
		_box(w, 0.32, 0.10 + sz * 0.40, 0.07, 0.07, 0.92, 1.20, "frame")
	_box(w, 0.32, 0.10, 0.90, 1.04, 1.20, 1.26, "roof")      # GI roof

	# Wheels. Rotating -90 degrees about Z maps the revolve's own +Y (its
	# thickness axis) onto +X, which is the axle direction here. The extra
	# -0.06 in X centres the 0.12-thick wheel on its axle.
	for spec in [Vector3(-0.34, 0.26, -0.62), Vector3(-0.34, 0.26, 0.52),
			Vector3(0.62, 0.24, 0.30)]:
		var axle := Transform3D(
			Basis(Vector3(0, 0, 1), -PI * 0.5),
			Vector3(spec.x - 0.06, spec.y, spec.z))
		w.add_revolve(PackedVector2Array([
			Vector2(0.00, 0.00), Vector2(0.25, 0.00),
			Vector2(0.25, 0.12), Vector2(0.00, 0.12),
		]), 8, "rubber", true, Callable(), axle)
	_finish(w, "env_tricycle")

# =============================================================================
# Plaza
# =============================================================================

## Slats, not a solid box. The gaps are the whole read.
func _bench() -> void:
	var w := ObjWriter.new("Bench")
	w.set_material("timber", UiTheme.ENV_WOOD)
	w.set_material("leg", UiTheme.ENV_CONCRETE_DARK)
	for sx in SIDES:
		_box(w, 0.75 * sx, 0.0, 0.12, 0.42, 0.0, 0.42, "leg")
	for i in range(3):
		_box(w, 0.0, -0.15 + 0.15 * float(i), 1.80, 0.12, 0.42, 0.48, "timber")
	for i in range(2):
		_box(w, 0.0, 0.20, 1.80, 0.08, 0.60 + 0.16 * float(i), 0.72 + 0.16 * float(i), "timber")
	_finish(w, "env_bench")

func _planter() -> void:
	var w := ObjWriter.new("Planter")
	w.set_material("concrete", UiTheme.ENV_CONCRETE)
	w.set_material("leaf", UiTheme.ENV_FOLIAGE)
	_box(w, 0, 0, 1.20, 1.20, 0.00, 0.50, "concrete")
	w.add_revolve(PackedVector2Array([
		Vector2(0.00, 0.46), Vector2(0.52, 0.52),
		Vector2(0.46, 0.92), Vector2(0.00, 1.10),
	]), 8, "leaf")
	_finish(w, "env_planter")

## Vertical punctuation. A plaza without one reads as a car park.
func _flagpole() -> void:
	var w := ObjWriter.new("Flagpole")
	w.set_material("pole", UiTheme.PANEL)
	w.set_material("base", UiTheme.ENV_CONCRETE_DARK)
	w.set_material("flag", UiTheme.HIGHLIGHT)
	w.add_revolve(PackedVector2Array([
		Vector2(0.00, 0.00), Vector2(0.22, 0.00), Vector2(0.18, 0.24),
	]), 10, "base")
	w.add_revolve(PackedVector2Array([
		Vector2(0.07, 0.24), Vector2(0.07, 4.90), Vector2(0.00, 5.00),
	]), 10, "pole")
	_box(w, 0.42, 0.0, 0.70, 0.02, 4.10, 4.60, "flag")
	_finish(w, "env_flagpole")

## Trunk and a bulged canopy, both centred revolves. `tree_far` is one value
## darker and exists ONLY so the ring has two layers — the board rings Province
## with depth, and depth here is a second colour, not a second row.
func _tree(file_name: String, height: float, canopy: Color) -> void:
	var w := ObjWriter.new("Tree")
	w.set_material("trunk", UiTheme.ENV_WOOD_DARK)
	w.set_material("canopy", canopy)
	var trunk_top := height * 0.42
	w.add_revolve(PackedVector2Array([
		Vector2(0.00, 0.00), Vector2(0.24, 0.00),
		Vector2(0.16, trunk_top),
	]), 8, "trunk")
	w.add_revolve(PackedVector2Array([
		Vector2(0.00, trunk_top - 0.15), Vector2(0.85, trunk_top + 0.10),
		Vector2(1.40, trunk_top + 0.75), Vector2(1.05, height - 0.75),
		Vector2(0.55, height - 0.20), Vector2(0.00, height),
	]), 12, "canopy")
	_finish(w, file_name)

## A leaf blade, as two triangles-worth of quad with a droop in the middle.
##
## ⚠️ DOUBLE-WOUND, for the reason `_wire` records: a single-sided quad is culled
## from whichever side you happen to be looking from, and foliage is looked at
## from underneath as often as from above. Every leaf in this file is seen from
## an FPP eye at 1.25 standing under it.
##
## `dir` is the horizontal direction the blade runs, `rise` its tip height
## relative to its root, and `droop` how far the midpoint sags below the straight
## line between them — which is the whole difference between a banana leaf and a
## plank.
func _blade(w: ObjWriter, root: Vector3, dir: Vector2, length: float,
		half_width: float, rise: float, droop: float, material: String) -> void:
	var d := dir.normalized()
	var perp := Vector2(-d.y, d.x) * half_width
	var mid := root + Vector3(d.x * length * 0.5, rise * 0.5 - droop,
		d.y * length * 0.5)
	var tip := root + Vector3(d.x * length, rise, d.y * length)
	# Root -> mid, at full width; mid -> tip, tapering to a point.
	# ⚠️ THE ROOT END IS NARROW, NOT FULL WIDTH, AND THAT IS WHAT MAKES A LEAF
	# ATTACH. Reported from a render: "some of your trees leaves were floating, not
	# even connected to the trunk." The blade used to start at its FULL half-width,
	# so a 0.36-wide banana leaf began as a 0.72-long straight edge centred on a
	# stem only 0.26 across — the middle of that edge met the stem and both corners
	# hung in clear air to either side of it. Every leaf was genuinely detached at
	# two points; it only read as attached from angles where the stem happened to
	# be behind the gap.
	#
	# A real leaf leaves the stem as a stalk and widens further out, which fixes
	# the geometry and the silhouette in the same move: 22% at the root, full width
	# at the midpoint. Callers also seat their roots ON the stem surface rather
	# than inboard of it — see _puno_saging and _puno_niyog.
	var root_perp := perp * 0.22
	var r0 := Vector3(root.x + root_perp.x, root.y, root.z + root_perp.y)
	var r1 := Vector3(root.x - root_perp.x, root.y, root.z - root_perp.y)
	var m0 := Vector3(mid.x + perp.x * 1.15, mid.y, mid.z + perp.y * 1.15)
	var m1 := Vector3(mid.x - perp.x * 1.15, mid.y, mid.z - perp.y * 1.15)
	# ⚠️ THE TIP IS A NARROW QUAD, NOT A POINT. Collapsing both far corners onto
	# one vertex looks like the obvious way to taper a blade and emits a
	# DEGENERATE triangle — zero area, so its face normal is undefined, and
	# `recalculate_normals()` then averages that undefined normal into the two
	# real vertices next to it. The leaf renders with a black wedge at the end.
	# 6% of the width costs two triangles and is invisible.
	var t0 := Vector3(tip.x + perp.x * 0.06, tip.y, tip.z + perp.y * 0.06)
	var t1 := Vector3(tip.x - perp.x * 0.06, tip.y, tip.z - perp.y * 0.06)
	w.add_quad(r0, m0, m1, r1, material)
	w.add_quad(r1, m1, m0, r0, material)
	w.add_quad(m0, t0, t1, m1, material)
	w.add_quad(m1, t1, t0, m0, material)


## SAGING. A banana clump — the cheapest unmistakable tropical silhouette there
## is, and the one that actually grows in the gap between two houses.
##
## Not a trunk with a canopy on top: a banana has no branches, so it is a fat
## pseudostem with every leaf springing from one point at the top. Getting that
## wrong (leaves scattered up the stem) is what makes a generated banana read as
## a palm, so the roots are all within 0.2 of each other.
func _puno_saging() -> void:
	var w := ObjWriter.new("PunoSaging")
	w.set_material("stem", UiTheme.ENV_FOLIAGE_DARK)
	w.set_material("leaf", UiTheme.ENV_FOLIAGE)
	w.set_material("leaf_old", UiTheme.ENV_FOLIAGE_DARK)

	# Two stems, because a banana is never alone — it suckers into a clump. The
	# second is shorter and offset, which is also what stops one instance from
	# reading as a repeated stamp when four of them stand in a row.
	# ⚠️ THE TIPS HANG BELOW THEIR OWN ROOTS. `rise` IS NEGATIVE AND THAT IS THE
	# WHOLE PIECE. The first version gave every blade a POSITIVE rise (+0.30) with
	# a mid-sag, so each leaf went up, dipped, and came out above where it
	# started — rendered, and it read as an agave or a spiky green star, not a
	# banana. A banana leaf is heavy: it leaves the crown roughly level and the
	# outer half FALLS, so the plant's silhouette is a fountain, not a starburst.
	# Long, wide and downward is the entire recognition cue and all three were
	# wrong.
	for k in range(2):
		var ox := 0.0 if k == 0 else 0.46
		var oz := 0.0 if k == 0 else 0.30
		var top := 2.40 if k == 0 else 1.55
		w.add_revolve(PackedVector2Array([
			Vector2(0.00, 0.00), Vector2(0.22, 0.00),
			Vector2(0.19, top * 0.55), Vector2(0.13, top),
			Vector2(0.00, top),
		]), 7, "stem")
		# Six broad blades on the main stem, five on the sucker. FEWER and BIGGER
		# than the first attempt's eight — a banana has half a dozen leaves that
		# each read individually, and eight narrow ones average into a blob.
		var blades := 6 if k == 0 else 5
		for i in range(blades):
			var a := TAU * float(i) / float(blades) + (0.5 if k else 0.0)
			var dir := Vector2(cos(a), sin(a))
			var long := (k == 0)
			# Root ON the stem surface: the top radius is 0.13, and starting at
			# 0.10 left a hairline gap that the narrow root now cannot hide.
			_blade(w, Vector3(ox + dir.x * 0.11, top - 0.14, oz + dir.y * 0.11),
				dir,
				2.35 if long else 1.70,          # long
				0.36 if long else 0.28,          # and wide
				-1.05 if long else -0.75,        # tip well below the crown
				0.30 if i % 2 else 0.16,         # a little sag on the way down
				"leaf" if i % 2 else "leaf_old")
	_finish(w, "env_puno_saging", 0.0)


## NIYOG. The coconut palm — the tall silhouette, for reading against sky at the
## end of the alley and over the plaza's tree line.
##
## The trunk LEANS, and that is the piece's whole character: a coconut grown in a
## yard is never plumb. It is built as a stack of short revolved segments each
## nudged along +X, because `add_revolve` spins about Y at the origin and cannot
## produce a curve on its own — the same limitation `_tricycle` needed a
## transform for, solved here without one.
func _puno_niyog() -> void:
	var w := ObjWriter.new("PunoNiyog")
	w.set_material("trunk", UiTheme.ENV_WOOD_DARK)
	w.set_material("frond", UiTheme.ENV_FOLIAGE)
	w.set_material("frond_dark", UiTheme.ENV_FOLIAGE_DARK)
	w.set_material("nut", UiTheme.ENV_WOOD)

	const SEGMENTS := 7
	const TRUNK_TOP := 6.10
	var lean := 0.0
	var lean_step := 0.085
	for i in range(SEGMENTS):
		var y0 := TRUNK_TOP * float(i) / float(SEGMENTS)
		var y1 := TRUNK_TOP * float(i + 1) / float(SEGMENTS)
		var r0 := lerpf(0.27, 0.15, float(i) / float(SEGMENTS))
		var r1 := lerpf(0.27, 0.15, float(i + 1) / float(SEGMENTS))
		# Each segment is its own little ngon column, offset in X. The overlap at
		# the joins is deliberate — it hides the step between two radii.
		w.add_extrude(_ngon(lean, 0.0, r0, 7), y0, y1 + 0.02, "trunk")
		lean += lean_step * (1.0 + float(i) * 0.18)
	# The crown. Nine fronds, drooping hard — a frond that does not droop reads
	# as a starfish on a stick.
	for i in range(9):
		var a := TAU * float(i) / 9.0
		var dir := Vector2(cos(a), sin(a))
		# Trunk top radius is 0.15, so seat the frond just inside it.
		_blade(w, Vector3(lean + dir.x * 0.13, TRUNK_TOP - 0.12, dir.y * 0.13),
			dir, 2.05, 0.22, 0.45 if i % 2 else 0.15, 1.15,
			"frond" if i % 2 else "frond_dark")
	# Three coconuts under the crown. Small, but they are the read that says
	# palm rather than fern.
	for i in range(3):
		var a := TAU * float(i) / 3.0 + 0.6
		w.add_revolve(PackedVector2Array([
			Vector2(0.00, TRUNK_TOP - 0.42), Vector2(0.15, TRUNK_TOP - 0.30),
			Vector2(0.00, TRUNK_TOP - 0.14),
		# ⚠️ `transform` IS add_revolve's SIXTH ARGUMENT, not its fourth — the
		# fourth is `smooth` and the fifth a deform Callable. Passing a
		# Transform3D in slot four is a PARSE error, not a silent misplacement,
		# so this is cheap to get wrong and impossible to ship wrong.
		]), 6, "nut", true, Callable(), Transform3D(Basis.IDENTITY,
			Vector3(lean + cos(a) * 0.26, 0.0, sin(a) * 0.26)))
	_finish(w, "env_puno_niyog")


## MANGGA. The broadleaf — WIDE, lumpy and low, which is the exact opposite of
## the cone it replaces and the reason all three of these exist rather than one.
##
## A mango over a wall is the shade a street is actually played in. The canopy is
## three overlapping revolved blobs at different heights and radii rather than
## one dome: a single revolve is a perfect solid of rotation and reads as a
## lollipop from every angle, which is the thing that made the old cone look
## generated.
func _puno_mangga() -> void:
	var w := ObjWriter.new("PunoMangga")
	w.set_material("trunk", UiTheme.ENV_WOOD_DARK)
	w.set_material("canopy", UiTheme.ENV_FOLIAGE)
	w.set_material("canopy_dark", UiTheme.ENV_FOLIAGE_DARK)

	w.add_revolve(PackedVector2Array([
		Vector2(0.00, 0.00), Vector2(0.46, 0.00),
		Vector2(0.30, 0.90), Vector2(0.26, 1.55),
	]), 8, "trunk")
	# Two low limbs, so the trunk forks the way a mango does instead of running
	# straight into the canopy like a lamp post.
	# ⚠️ THE LIMBS START INSIDE THE TRUNK. These were columns offset 0.55 from the
	# axis running 1.20..2.35 — the trunk is 0.26 wide up there, so neither limb
	# touched it and both read as free-standing posts under the canopy, the same
	# floating-part complaint as the leaves. Starting them at 0.9 (inside the
	# trunk, which runs to 1.55) means each one is rooted in solid geometry.
	for k in range(2):
		var a := 0.9 + PI * float(k)
		w.add_extrude(_ngon(cos(a) * 0.30, sin(a) * 0.30, 0.15, 5),
			0.90, 2.35, "trunk")
	# (offset x, offset z, base y, radius, top y, material)
	var blobs := [
		[0.00, 0.00, 1.95, 1.95, 4.30, "canopy"],
		[-0.95, 0.55, 1.70, 1.35, 3.55, "canopy_dark"],
		[0.85, -0.60, 1.80, 1.45, 3.80, "canopy"],
	]
	for b in blobs:
		var ox: float = b[0]
		var oz: float = b[1]
		var y0: float = b[2]
		var r: float = b[3]
		var y1: float = b[4]
		var mid := (y0 + y1) * 0.5
		w.add_revolve(PackedVector2Array([
			Vector2(0.00, y0 + 0.10), Vector2(r * 0.62, y0),
			Vector2(r, mid), Vector2(r * 0.72, y1 - 0.35),
			Vector2(0.00, y1),
		]), 10, String(b[5]), true, Callable(),
			Transform3D(Basis.IDENTITY, Vector3(ox, 0.0, oz)))
	_finish(w, "env_puno_mangga")


## HALAMAN SA LATA. A plant in a cut-open paint tin.
##
## This is the smallest piece in the kit and one of the most specific. A
## Philippine doorstep does not have a garden or a planter; it has whatever tin
## the paint came in, cut down, with something growing out of it — and there are
## five of them on every step. It costs a revolve and five blades.
##
## INTERIOR TIER at 0.62 — well under the 1.10 the map builders hold interior
## clutter to, so it can stand anywhere legal without ever blocking an aim.
func _halaman_lata() -> void:
	var w := ObjWriter.new("HalamanLata")
	w.set_material("tin", UiTheme.ENV_PAINT_TERRA)
	w.set_material("rim", UiTheme.ENV_CONCRETE_DARK)
	w.set_material("soil", UiTheme.ENV_WOOD_DARK)
	w.set_material("leaf", UiTheme.ENV_FOLIAGE)

	w.add_extrude(_ngon(0.0, 0.0, 0.16, 9), 0.00, 0.24, "tin")
	# The cut rim, a shade darker. A tin without one reads as a solid cylinder.
	w.add_extrude(_ngon(0.0, 0.0, 0.17, 9), 0.24, 0.27, "rim")
	w.add_extrude(_ngon(0.0, 0.0, 0.145, 9), 0.27, 0.29, "soil")
	for i in range(5):
		var a := TAU * float(i) / 5.0 + 0.3
		var dir := Vector2(cos(a), sin(a))
		_blade(w, Vector3(dir.x * 0.04, 0.29, dir.y * 0.04),
			dir, 0.30, 0.075, 0.30, 0.10, "leaf")
	_finish(w, "env_halaman_lata", 0.0)


## ATIP NA YERO. The corrugated lean-to a house extends itself with.
##
## ⚠️ THIS IS THE PIECE THAT ROOFS THE ALLEY, and roofing the alley is the whole
## contrast between this map and the plaza — Eskinita is fought ALONG a corridor
## with something overhead, Bayan Plaza is fought ACROSS an open room. Wires do
## part of that job; a GI awning over the doorway does the rest, at eye level
## where the wires are not.
##
## ⚠️ THE CORRUGATION IS AUTHORED AS RIDGES, NOT AS A ROTATED WALL SHEET, AND THE
## FIRST VERSION IS WHY. It reused `_corrugated_outline()` — a vertical wall's
## CROSS-SECTION — extruded it along the slope and tipped it 68 degrees about X.
## Rendered, that came out as a thin sliver floating clear of two disconnected
## posts, with the rust band across the top face and the corrugation reading as a
## sawtooth SILHOUETTE seen edge-on. The outline's own 0.21 of amplitude had
## become the panel's visible depth and the 1.55 of extrusion had gone into the
## screen. A rotation that has to be right in two axes at once is not worth it for
## a piece this small.
##
## So the ridges are boxes: nine of them side by side, alternating height by 5 cm.
## That IS what corrugation is, it needs no transform, it cannot be oriented
## wrong, and every ridge runs down the slope (+Z) the way a roof sheet is
## actually laid. `_sari_sari_store`'s awning and `_church_facade`'s pediment both
## take the same route for the same reason and say so — when a slope is awkward,
## step it, because "flat is honest rather than approximated badly".
func _atip_yero() -> void:
	var w := ObjWriter.new("AtipYero")
	w.set_material("sheet", UiTheme.ENV_GI_SHEET)
	w.set_material("rust", UiTheme.ENV_RUST)
	w.set_material("timber", UiTheme.ENV_WOOD_DARK)

	const RIDGES := 9
	const SPAN := 2.00          # the awning's width, along X
	const DEPTH := 1.45         # how far it reaches out from the wall, along Z
	const FRONT_Y := 2.02       # the low, outer edge — over the posts
	const BACK_Y := 2.34        # the high edge, against the wall

	# Two posts carrying the outer edge, and a wall plate at the back. The posts
	# stop AT the front edge rather than short of it — the first version left a
	# 7 cm gap and the roof hovered.
	for sx in SIDES:
		_box(w, sx * (SPAN * 0.5 - 0.14), DEPTH * 0.5 - 0.10,
			0.10, 0.10, 0.0, FRONT_Y, "timber")
	_box(w, 0.0, -DEPTH * 0.5 + 0.06, SPAN + 0.10, 0.12,
		BACK_Y - 0.12, BACK_Y, "timber")

	# The ridges. Each is one box running the full DEPTH, so the corrugation
	# lines point down the slope and the sheet drains the way a real one does.
	var ridge_w := SPAN / float(RIDGES)
	for i in range(RIDGES):
		var cx := -SPAN * 0.5 + ridge_w * (float(i) + 0.5)
		var high := (i % 2 == 0)
		var y0 := FRONT_Y + (0.00 if high else 0.05)
		var y1 := y0 + (0.09 if high else 0.05)
		# Two segments per ridge — front half and back half — which is what gives
		# the awning its pitch without a rotation: the back half simply sits
		# higher than the front half.
		# ⚠️ THE TWO HALVES OVERLAP IN Z BY 0.22, AND THE FIRST VERSION DID NOT.
		# Abutting them exactly left the step between the low front half and the
		# raised back half standing open — rendered, and you could see daylight
		# through the middle of the awning. Overlapping the back half forward over
		# the front one closes it, which is the same trick `_puno_niyog`'s trunk
		# segments use on their radius steps and for the same reason.
		var step := (BACK_Y - FRONT_Y) * 0.55
		_box(w, cx, DEPTH * 0.25, ridge_w * 0.92, DEPTH * 0.5, y0, y1, "sheet")
		_box(w, cx, -DEPTH * 0.25 + 0.11, ridge_w * 0.92, DEPTH * 0.5 + 0.22,
			y0 + step, y1 + step, "sheet")
		# And a riser closing the step's own face, so the joint reads as a lap
		# rather than as two separate sheets at two heights.
		_box(w, cx, 0.0, ridge_w * 0.92, 0.12, y0, y1 + step, "sheet")
	# The rust run along the low outer lip, where a real sheet rots first because
	# that is where the water leaves it.
	_box(w, 0.0, DEPTH * 0.5 - 0.05, SPAN, 0.10, FRONT_Y - 0.04, FRONT_Y + 0.06,
		"rust")
	_finish(w, "env_atip_yero", 22.0)


## One instance, on the long axis of the boundary. It is the landmark that tells
## a player which way they are facing, and that is worth more than any three
## clutter pieces.
func _church_facade() -> void:
	var w := ObjWriter.new("ChurchFacade")
	w.set_material("stone", UiTheme.ENV_CONCRETE)
	w.set_material("timber", UiTheme.ENV_WOOD_DARK)
	w.set_material("dark", UiTheme.INK)

	_box(w, 0, 0, 6.0, 1.5, 0.0, 6.40, "stone")
	# Pediment, stepped rather than sloped — 2.1b-0 again.
	_box(w, 0, 0, 4.4, 1.5, 6.40, 7.10, "stone")
	_box(w, 0, 0, 2.6, 1.5, 7.10, 7.70, "stone")
	_box(w, 0, 0, 0.22, 0.22, 7.70, 8.40, "timber")
	_box(w, 0, 0, 0.90, 0.20, 7.95, 8.15, "timber")

	# Arched doorway, approximated with six stacked lintels. At this scale the
	# stepping reads as an arch and costs 72 triangles instead of a new primitive.
	const ARCH := 6
	for i in range(ARCH):
		var t := float(i) / float(ARCH)
		var half := 0.95 * sqrt(maxf(1.0 - t * t, 0.0))
		_box(w, 0, -0.76, half * 2.0, 0.06, 2.60 + 0.16 * float(i), 2.76 + 0.16 * float(i), "dark")
	_box(w, 0, -0.76, 1.90, 0.06, 0.00, 2.60, "timber")
	# Rose window.
	w.add_revolve(PackedVector2Array([
		Vector2(0.00, 4.80), Vector2(0.62, 4.80),
	]), 12, "dark")
	_finish(w, "env_church_facade")

## MANDATORY. It IS the Philippine plaza — if exactly one piece of the plaza set
## ships, it is this one.
##
## The HOOP sits at the origin and the post is offset behind it, not the other
## way round: a hoop is horizontal so it is a legal Y-axis revolve, and putting
## the gameplay-relevant part on the axis is what lets the whole piece exist
## before 2.1b-0 lands.
func _basketball_ring() -> void:
	var w := ObjWriter.new("BasketballRing")
	w.set_material("board", UiTheme.ENV_WOOD)
	w.set_material("edge", UiTheme.PANEL)
	w.set_material("post", UiTheme.ENV_CONCRETE)
	w.set_material("ring", UiTheme.PANEL)

	w.add_extrude(_ngon(0.0, 0.62, 0.12, 8), 0.00, 3.05, "post")
	_box(w, 0.0, 0.52, 1.20, 0.06, 2.95, 3.85, "board")
	_box(w, 0.0, 0.49, 0.62, 0.02, 3.02, 3.48, "edge")
	# The rim: a horizontal torus, i.e. an ordinary revolve.
	w.add_revolve(PackedVector2Array([
		Vector2(0.21, 3.05), Vector2(0.25, 3.07),
		Vector2(0.21, 3.09), Vector2(0.17, 3.07),
		Vector2(0.21, 3.05),
	]), 12, "ring")
	_finish(w, "env_basketball_ring")

# =============================================================================
# The plaza centrepiece set (checklist 2.4 — the reference-photo redress)
#
# ⚠️ THE ONE CONSTRAINT THAT SHAPES ALL OF THESE: the plaza's centre is where
# the can stands, and `build_bayan_plaza.py` protects a LANE_RADIUS = 3.2 disc
# around it that aborts the build on violation. So the monument does NOT go in
# the middle the way the reference photo has it — human call, 2026-07-29: "dont
# center monument, js make it seen and we're playing near it". It goes off-axis,
# large enough and tall enough to be the thing you orient by, close enough to
# the court that you fight beside it. That is a placement decision and it lives
# in the map builder; what lives HERE is only the geometry.
#
# ⚠️ HEIGHTS ARE IN METRES, same law as `_building_block`. The monument is 4.90,
# which is three times a Person's 1.6 — a real plaza monument is 4-7 m. The
# railing is 0.98 and the hedge planter 0.96, both under the 1.1 interior tier
# so an FPP eye at 1.25 clears them; that is checked by the map builder too, but
# it is authored true here rather than relied on downstream.
# =============================================================================

## The tiered monument. Steps, plinth die, cornice, spire — the silhouette in
## the reference photo, in about 400 triangles.
##
## Built entirely from `_box` and `add_revolve`: the stepped tiers are boxes
## because a real plinth IS stepped (no sloping primitive needed, which is the
## same reason `_church_facade`'s pediment is stepped), and the spire is one
## revolve because it is a solid of revolution and nothing else in the kit
## expresses a taper as cheaply.
##
## ⚠️ 2.60 FOOTPRINT, NOT WIDER. It has to fit inside a 4.0 railed enclosure with
## a walkway left round it, and the enclosure has to fit between the confinement
## box (|x| <= 5) and the slab edge (|x| <= 10). Widening this means moving the
## enclosure, and the enclosure has nowhere to go.
func _monument() -> void:
	var w := ObjWriter.new("Monument")
	w.set_material("stone", UiTheme.ENV_CONCRETE)
	w.set_material("step", UiTheme.ENV_CONCRETE_DARK)
	w.set_material("plaque", UiTheme.ENV_PAINT_PLINTH)

	# Three steps. Alternating stone/step is what makes them read as separate
	# courses at 8 m rather than as one tapered lump.
	_box(w, 0, 0, 2.60, 2.60, 0.00, 0.22, "step")
	_box(w, 0, 0, 2.16, 2.16, 0.22, 0.44, "stone")
	_box(w, 0, 0, 1.76, 1.76, 0.44, 0.64, "step")

	# The die — the big block that carries the dedication.
	_box(w, 0, 0, 1.36, 1.36, 0.64, 2.00, "stone")
	# A plaque on all FOUR faces, for the same reason `_building_block` puts
	# windows on all four: this piece is walked around, and three blank sides is
	# how the belt buildings came to read as greybox.
	for sx in SIDES:
		_box(w, sx * 0.69, 0.00, 0.02, 0.86, 0.96, 1.68, "plaque")
		_box(w, 0.00, sx * 0.69, 0.86, 0.02, 0.96, 1.68, "plaque")

	# Cornice and cap.
	_box(w, 0, 0, 1.66, 1.66, 2.00, 2.20, "step")
	_box(w, 0, 0, 1.30, 1.30, 2.20, 2.38, "stone")
	# Corner urns. Four tiny revolves, and they are most of why the silhouette
	# reads as ORNATE rather than as a stack of boxes.
	for sx in SIDES:
		for sz in SIDES:
			var urn := Transform3D(Basis(), Vector3(sx * 0.52, 2.38, sz * 0.52))
			w.add_revolve(PackedVector2Array([
				Vector2(0.00, 0.00), Vector2(0.13, 0.00),
				Vector2(0.16, 0.14), Vector2(0.10, 0.30),
				Vector2(0.14, 0.38), Vector2(0.00, 0.42),
			]), 8, "step", true, Callable(), urn)

	# The spire: drum, taper, collar, taper, finial. Faceted at 8 segments to
	# match the kit's flat-shaded look rather than reading as a smooth cone.
	w.add_revolve(PackedVector2Array([
		Vector2(0.00, 2.38), Vector2(0.44, 2.38),
		Vector2(0.44, 2.66), Vector2(0.36, 2.78),
		Vector2(0.32, 3.52), Vector2(0.42, 3.60),
		Vector2(0.42, 3.80), Vector2(0.30, 3.92),
		Vector2(0.17, 4.54),
	]), 8, "stone")
	w.add_revolve(PackedVector2Array([
		Vector2(0.17, 4.54), Vector2(0.21, 4.62),
		Vector2(0.17, 4.72), Vector2(0.07, 4.84),
		Vector2(0.00, 4.90),
	]), 8, "step")
	_finish(w, "env_monument")

## One 2.0-unit bay of iron railing, so bays tile on the kit's own grid with no
## per-instance work in the map — the same trick `_post_electric` uses to string
## its wire to where the next post will be.
##
## ⚠️ THE END POSTS ARE AT x = +/-1.0, i.e. ON the bay boundary, so two adjacent
## bays share a post position and the doubled geometry is exactly coincident and
## invisible. That is deliberate: the alternative is a corner piece and an
## end piece and a rule about which to use where, for a saving of twelve
## triangles on a piece there are eight of.
##
## 0.98 tall — under the 1.1 interior tier, so it never blocks an FPP aim. It is
## a waist-high garden railing, which is what the reference has; a chest-high one
## would be both wrong and illegal here.
func _railing() -> void:
	var w := ObjWriter.new("Railing")
	w.set_material("rail", UiTheme.PANEL)
	w.set_material("foot", UiTheme.ENV_CONCRETE_DARK)

	for sx in SIDES:
		_box(w, sx * 1.0, 0.0, 0.16, 0.16, 0.00, 0.14, "foot")
		_box(w, sx * 1.0, 0.0, 0.13, 0.13, 0.14, 0.90, "rail")
		_box(w, sx * 1.0, 0.0, 0.19, 0.19, 0.90, 0.98, "rail")
	# Bottom, middle and top rails.
	_box(w, 0, 0, 2.00, 0.06, 0.16, 0.22, "rail")
	_box(w, 0, 0, 2.00, 0.05, 0.46, 0.51, "rail")
	_box(w, 0, 0, 2.00, 0.09, 0.78, 0.86, "rail")
	# Balusters. Nine, which at this span is the density that still reads as
	# a railing rather than as a fence when it foreshortens across the plaza.
	for i in range(9):
		_box(w, -0.80 + 0.20 * float(i), 0.0, 0.045, 0.045, 0.22, 0.78, "rail")
	_finish(w, "env_railing")

## A concrete planter with a CLIPPED hedge in it — square-cut, not the bulged
## revolve `_planter` uses. The reference's plaza is ringed with these and the
## clipped silhouette is the entire difference between "municipal planting" and
## "a bush".
##
## 1.10 footprint on purpose: four of these stand in the corners of a 4.0 railed
## enclosure around a 2.60 monument, and 1.10 is what fits between the two with
## the walkway kept clear.
func _planter_hedge() -> void:
	var w := ObjWriter.new("PlanterHedge")
	w.set_material("concrete", UiTheme.ENV_CONCRETE)
	w.set_material("coping", UiTheme.ENV_CONCRETE_DARK)
	w.set_material("leaf", UiTheme.ENV_FOLIAGE)
	w.set_material("leaf_dark", UiTheme.ENV_FOLIAGE_DARK)

	_box(w, 0, 0, 1.10, 1.10, 0.00, 0.38, "concrete")
	_box(w, 0, 0, 1.20, 1.20, 0.38, 0.46, "coping")
	# Two stacked boxes rather than one: the inset top course is what gives a
	# clipped hedge its shoulder, and it is four extra quads.
	_box(w, 0, 0, 1.04, 1.04, 0.46, 0.82, "leaf")
	_box(w, 0, 0, 0.88, 0.88, 0.82, 0.96, "leaf_dark")
	_finish(w, "env_planter_hedge")

## The campanile. `_church_facade` has no tower and the reference's church is
## READ from its tower — at 14.3 it is the tallest thing on the map and clears
## the 8.9-unit forest trees in the ring, which is what makes it a landmark from
## inside the plaza instead of another shape in the tree line.
##
## Fronts on -Z with the rest of the plaza set (see the header note), so it takes
## the same yaw as the church it stands beside.
func _bell_tower() -> void:
	var w := ObjWriter.new("BellTower")
	w.set_material("stone", UiTheme.ENV_CONCRETE)
	w.set_material("band", UiTheme.ENV_CONCRETE_DARK)
	w.set_material("roof", UiTheme.ENV_PAINT_TERRA)
	w.set_material("window", UiTheme.INK)

	# Three tapering storeys with a string course between each. The taper is what
	# stops it reading as a chimney.
	_box(w, 0, 0, 2.50, 2.50, 0.00, 3.40, "stone")
	_box(w, 0, 0, 2.62, 2.62, 3.40, 3.62, "band")
	_box(w, 0, 0, 2.30, 2.30, 3.62, 6.60, "stone")
	_box(w, 0, 0, 2.42, 2.42, 6.60, 6.82, "band")
	_box(w, 0, 0, 2.10, 2.10, 6.82, 9.40, "stone")
	_box(w, 0, 0, 2.22, 2.22, 9.40, 9.62, "band")
	# The belfry. Its openings are the read, so they are tall and on all four
	# faces — same rule as every other window in this file.
	_box(w, 0, 0, 1.94, 1.94, 9.62, 11.60, "stone")
	for sx in SIDES:
		_window(w, Vector3(sx * 0.98, 10.60, 0.0),
			Vector3(0, 0, 0.46), Vector3(0, 0.74, 0))
		_window(w, Vector3(0.0, 10.60, sx * 0.98),
			Vector3(0.46, 0, 0), Vector3(0, 0.74, 0))
	# Narrow slit windows down the shaft, so the storeys are not blank.
	for i in range(3):
		var y := 2.10 + 2.90 * float(i)
		for sx in SIDES:
			_window(w, Vector3(sx * 1.27, y, 0.0),
				Vector3(0, 0, 0.16), Vector3(0, 0.52, 0))
			_window(w, Vector3(0.0, y, sx * 1.27),
				Vector3(0.16, 0, 0), Vector3(0, 0.52, 0))
	_box(w, 0, 0, 2.16, 2.16, 11.60, 11.84, "band")
	# Red pyramid roof and a cross. The roof colour is the reference's, and it is
	# ENV_PAINT_TERRA rather than a new red — a fifth environment colour would
	# have to be argued for in UiTheme first (env_toon_pass.gd's own rule).
	w.add_revolve(PackedVector2Array([
		Vector2(1.16, 11.84), Vector2(0.00, 13.60),
	]), 4, "roof", false)
	_box(w, 0, 0, 0.10, 0.10, 13.60, 14.30, "band")
	_box(w, 0, 0, 0.44, 0.09, 13.86, 13.96, "band")
	_finish(w, "env_bell_tower")

## The municipal hall — the long two-storey block with the red roof behind the
## plaza in the reference. It is the second half of "pull the landmarks IN from
## the silhouette belt so they become real landmarks instead of distant fog
## shapes": at 12 wide and 8.5 tall standing at z = -15.8 it fills the whole
## back-right of the frame from the south throwing line.
##
## ⚠️ NOT a `_building_block` with a roof on it. A building block is a
## silhouette mass authored to be seen at 30 m; this is seen at 20 m and is one
## of only three things on the map a player will actually look AT. It gets an
## arcade, a balcony band and a pitched roof, which is about 200 triangles more
## and the entire difference between a landmark and a wall.
func _municipal_hall() -> void:
	var w := ObjWriter.new("MunicipalHall")
	w.set_material("body", UiTheme.ENV_PAINT_CREAM)
	w.set_material("plinth", UiTheme.ENV_CONCRETE)
	w.set_material("band", UiTheme.ENV_CONCRETE_DARK)
	w.set_material("roof", UiTheme.ENV_PAINT_TERRA)
	w.set_material("window", UiTheme.INK)

	const HALL_W := 12.0
	const HALL_D := 5.60

	_box(w, 0, 0, HALL_W, HALL_D, 0.00, 6.60, "body")
	# Ground-floor arcade, proud of the body so it throws its own shadow line.
	_box(w, 0, 0, HALL_W + 0.24, HALL_D + 0.24, 0.00, 3.00, "plinth")
	_box(w, 0, 0, HALL_W + 0.32, HALL_D + 0.32, 3.00, 3.24, "band")
	# Seven arched openings along the FRONT (-Z, per the header rule). Stepped
	# arches, the same six-lintel approximation `_church_facade` uses.
	var front_z := -(HALL_D + 0.24) * 0.5 - 0.02
	for bay in range(7):
		var cx := -4.80 + 1.60 * float(bay)
		_box(w, cx, front_z, 1.06, 0.06, 0.00, 1.90, "window")
		for i in range(5):
			var t := float(i) / 5.0
			var half := 0.53 * sqrt(maxf(1.0 - t * t, 0.0))
			_box(w, cx, front_z, half * 2.0, 0.06,
				1.90 + 0.13 * float(i), 2.03 + 0.13 * float(i), "window")
	# First-floor windows, front and back, plus two on each end.
	for bay in range(7):
		var cx := -4.80 + 1.60 * float(bay)
		for sz in SIDES:
			_window(w, Vector3(cx, 4.70, sz * (HALL_D * 0.5 + 0.01)),
				Vector3(0.34, 0, 0), Vector3(0, 0.62, 0))
	for sz in SIDES:
		for sx in SIDES:
			_window(w, Vector3(sx * (HALL_W * 0.5 + 0.01), 4.70, sz * 1.30),
				Vector3(0, 0, 0.34), Vector3(0, 0.62, 0))
	# Parapet, then the pitched red roof. Two stepped courses rather than a true
	# hip: at this distance the step reads as a pitch and needs no new primitive.
	_box(w, 0, 0, HALL_W + 0.40, HALL_D + 0.40, 6.60, 6.90, "band")
	_box(w, 0, 0, HALL_W + 0.30, HALL_D + 0.30, 6.90, 7.70, "roof")
	_box(w, 0, 0, HALL_W - 1.60, HALL_D - 1.60, 7.70, 8.36, "roof")
	_box(w, 0, 0, HALL_W - 4.20, HALL_D - 3.00, 8.36, 8.60, "roof")
	_finish(w, "env_municipal_hall")


# =============================================================================
# Field markings — these serve BOTH round-win modes, which is why they are not
# optional. Option B is unreadable without the base circle; Option A needs the
# lata lit and unoccluded where it stands so the dent count can be read.
# =============================================================================

## The ring the lata stands in. The game is named after this.
##
## Built as a shallow revolved ring rather than a flat annulus: a revolve's
## profile makes the inner wall, top and outer wall in one call, all wound
## correctly by construction, where a hand-built flat annulus is one winding
## mistake away from being invisible from above.
##
## ⚠️ Art_Direction.md §1 — 1.50 outer radius (3.0 m across) was sized around a
## 1.12 m can (LATA_RADIUS 0.34 pre-rescale, at the OLD 1.0 scale). Against the
## rescaled ~0.10 m-radius can this read as a dinner plate. Outer radius down to
## 0.70 (1.4 m across, inside the audit's 1.2-1.5 m window); ring width kept at
## a legible 0.15 rather than scaling it down 1:1 with the diameter — the whole
## reason it was widened from 0.06 in the first place was that a thin ring
## foreshortens to sub-pixel at the front/back of the ellipse from a throwing
## line 6 units away, and that distance hasn't changed.
## =============================================================================
## CHILDREN CHALK DRAWINGS - the floor of an eskinita is a sketchpad
## =============================================================================
##
## Human ask, with reference photos of kids drawing on pavement: "add random child
## chalk scribbles in eskinita on the floor, make it look like real drawings."
##
## THIS IS A PILLAR-1 PIECE, NOT DECORATION, and it is the cheapest one left. The
## map already says "a street somebody lives on"; this says "and CHILDREN PLAY ON
## IT", which is the entire premise of tumbang preso. The game is about kalaro in an
## alley, and until now the only thing on the ground was the court the engine needs.
##
## PIKO EARNS ITS PLACE TWICE. It is Filipino hopscotch, chalked on streets across
## the country, and it is a DIFFERENT STREET GAME drawn beside the one being played
## - the same kids, another afternoon. A non-Filipino reads "hopscotch, so children
## play here"; a Filipino reads "piko". That is the specific-not-decorative standard:
## the reference is a real named game, not a generic squiggle.
##
## PASTELS, because real pavement chalk comes in a box of pale colours and children
## use all of them, which is what the references show.
## These are LOCAL CONSTANTS and that is a documented exception to this file's
## "colours come from UiTheme" rule. UiTheme is the game's UI and role palette; a
## child's chalk box is neither, and no ENV_* token is a pale pink. Adding four
## UI-band colours for a floor doodle would be the worse trade. NONE of them is near
## OFFENSE orange (#f87020) or DEFENSE blue (#0080e8) - checked, because the world is
## the largest surface in frame and that rule does not bend.
const CHALK_PINK: Color = Color(0.902, 0.678, 0.706)
const CHALK_BLUE: Color = Color(0.678, 0.780, 0.851)
const CHALK_LEMON: Color = Color(0.910, 0.878, 0.671)
const CHALK_MINT: Color = Color(0.714, 0.843, 0.745)


## One chalk stroke along a polyline, as a wobbly ribbon per segment.
##
## Reuses `_chalk_wander`, so a doodle and a court line are drawn by the same
## unsteady hand - which is what stops the drawings reading as a different asset
## dropped on the same floor. `t` advances along the WHOLE path rather than resetting
## per segment, so the wobble carries continuously through corners.
func _chalk_stroke(w: ObjWriter, pts: PackedVector2Array, width: float,
		material: String, seed_t: float = 0.0) -> void:
	if pts.size() < 2:
		return
	var t := seed_t
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var d := b - a
		var seg := d.length()
		if seg < 0.0001:
			continue
		var dir := d / seg
		var perp := Vector2(-dir.y, dir.x)
		var steps := maxi(2, int(seg / 0.09))
		var outline := PackedVector2Array()
		for k in range(steps + 1):
			var f := float(k) / float(steps)
			var tt := t + f * seg
			outline.append(a + d * f + perp * (_chalk_wander(tt)
				+ width * 0.5 * (0.85 + 0.3 * sin(tt * 21.7))))
		for k in range(steps, -1, -1):
			var f := float(k) / float(steps)
			var tt := t + f * seg
			outline.append(a + d * f + perp * (_chalk_wander(tt)
				- width * 0.5 * (0.85 + 0.3 * sin(tt * 19.1 + 1.4))))
		w.add_extrude(outline, 0.0, 0.02, material)
		t += seg


## A closed ring of chalk - a head, a wheel, a flower centre. The radius breathes so
## it is a child's circle rather than a compass one.
func _chalk_ring(w: ObjWriter, cx: float, cz: float, r: float, width: float,
		material: String) -> void:
	var pts := PackedVector2Array()
	for i in range(15):
		var ang := TAU * float(i) / 14.0
		var rr := r * (1.0 + 0.09 * sin(ang * 3.0 + 0.7))
		pts.append(Vector2(cx + rr * cos(ang), cz + rr * sin(ang)))
	_chalk_stroke(w, pts, width, material, cx * 3.1 + cz)


## PIKO - Filipino hopscotch. Four single boxes then a wide pair, drawn wonky.
func _chalk_piko() -> void:
	var w := ObjWriter.new("ChalkPiko")
	w.set_material("chalk", CHALK_LEMON)
	const CELL := 0.62
	var y := 0.0
	for row in range(4):
		var wob := 0.035 * sin(float(row) * 2.3)
		_chalk_stroke(w, PackedVector2Array([
			Vector2(-CELL * 0.5 + wob, y), Vector2(CELL * 0.5 + wob, y),
			Vector2(CELL * 0.5 - wob, y + CELL), Vector2(-CELL * 0.5 - wob, y + CELL),
			Vector2(-CELL * 0.5 + wob, y),
		]), 0.045, "chalk", float(row) * 1.7)
		y += CELL
	_chalk_stroke(w, PackedVector2Array([
		Vector2(-CELL, y), Vector2(CELL, y), Vector2(CELL, y + CELL),
		Vector2(-CELL, y + CELL), Vector2(-CELL, y),
	]), 0.045, "chalk", 9.3)
	_chalk_stroke(w, PackedVector2Array([Vector2(0.0, y), Vector2(0.0, y + CELL)]),
		0.045, "chalk", 4.1)
	_finish(w, "env_chalk_piko", 0.0)


## A stick figure. Every child draws this one and it reads instantly from above.
func _chalk_tao() -> void:
	var w := ObjWriter.new("ChalkTao")
	w.set_material("chalk", CHALK_PINK)
	_chalk_ring(w, 0.0, 0.62, 0.17, 0.04, "chalk")
	_chalk_stroke(w, PackedVector2Array([Vector2(0.0, 0.45), Vector2(0.02, -0.12)]),
		0.04, "chalk", 1.3)
	_chalk_stroke(w, PackedVector2Array([Vector2(-0.30, 0.14), Vector2(0.01, 0.32),
		Vector2(0.32, 0.10)]), 0.04, "chalk", 2.6)
	_chalk_stroke(w, PackedVector2Array([Vector2(-0.24, -0.52), Vector2(0.02, -0.12),
		Vector2(0.26, -0.50)]), 0.04, "chalk", 5.2)
	_finish(w, "env_chalk_tao", 0.0)


## A flower, straight off the second reference photo.
func _chalk_bulaklak() -> void:
	var w := ObjWriter.new("ChalkBulaklak")
	w.set_material("petal", CHALK_BLUE)
	w.set_material("stem", CHALK_MINT)
	for i in range(6):
		var ang := TAU * float(i) / 6.0
		_chalk_ring(w, cos(ang) * 0.27, sin(ang) * 0.27 + 0.30, 0.15, 0.035, "petal")
	_chalk_ring(w, 0.0, 0.30, 0.11, 0.035, "petal")
	_chalk_stroke(w, PackedVector2Array([Vector2(0.0, 0.16), Vector2(-0.04, -0.42)]),
		0.038, "stem", 3.4)
	_chalk_stroke(w, PackedVector2Array([Vector2(-0.03, -0.12), Vector2(0.22, -0.02)]),
		0.033, "stem", 7.1)
	_finish(w, "env_chalk_bulaklak", 0.0)


## Loops and a sun - the "I was just holding chalk" drawing. There is one in every
## reference photo, and it is what makes a floor look USED rather than decorated with
## three tidy motifs.
func _chalk_gulo() -> void:
	var w := ObjWriter.new("ChalkGulo")
	w.set_material("chalk", CHALK_MINT)
	w.set_material("sun", CHALK_LEMON)
	var loop := PackedVector2Array()
	for i in range(34):
		var f := float(i) / 33.0
		var ang := f * TAU * 2.4
		var r := 0.16 + f * 0.42
		loop.append(Vector2(cos(ang) * r - 0.15, sin(ang) * r * 0.72))
	_chalk_stroke(w, loop, 0.036, "chalk", 0.9)
	_chalk_ring(w, 0.74, 0.52, 0.13, 0.034, "sun")
	for i in range(6):
		var a2 := TAU * float(i) / 6.0 + 0.3
		_chalk_stroke(w, PackedVector2Array([
			Vector2(0.74 + cos(a2) * 0.18, 0.52 + sin(a2) * 0.18),
			Vector2(0.74 + cos(a2) * 0.30, 0.52 + sin(a2) * 0.30)]),
			0.03, "sun", float(i) * 3.3)
	_finish(w, "env_chalk_gulo", 0.0)


func _base_circle_decal() -> void:
	var w := ObjWriter.new("BaseCircleDecal")
	w.set_material("mark", UiTheme.HIGHLIGHT)
	# ⚠️ PROFILE ORDER IS OUTER-FIRST, and reversing it breaks the piece. Found by
	# rendering: add_revolve derives its normal from the profile edge as
	# (edge.y, -edge.x), so a top annulus written inner->outer faces DOWN and the
	# whole ring is backface-culled from above — it rendered as two stray yellow
	# arcs where the far side showed through the near side. Written outer->inner
	# the top faces up, the outer wall faces out, and the inner wall faces in.
	# A CLOSED section — bottom, outer wall, top, inner wall — so no face can be
	# hidden by a winding mistake. The game is named after this circle; it has to
	# be legible from a throwing line 6 units away, not merely present in the .obj.
	w.add_revolve(PackedVector2Array([
		Vector2(0.55, 0.00), Vector2(0.70, 0.00),
		Vector2(0.70, 0.03), Vector2(0.55, 0.03),
		Vector2(0.55, 0.00),
	]), 28, "mark")
	_finish(w, "env_base_circle_decal")

## 6.0 units from the base circle is where this goes — see
## Art_Direction.md §9 for the ballistics, and for the finding that
## throw_bakya cannot reach it.
## ⚠️⚠️ ONE WIDTH FOR EVERY CHALK LINE ON EVERY MAP, AND IT USED TO BE TWO.
## Reported from a playtest: "fix these lines for play area of both maps, they dont
## connect and they dont look uniform, one is fat af one is thin."
## Measured: `throwing_line_decal` was 0.12 wide and `team_side_decal` 0.08 — a 50%
## difference between two lines that meet at a corner, which is why the court read
## as several unrelated markings rather than one chalked court. `court_line()` in
## both builders already extends each edge by the SIDE line's half-width so corners
## overlap, and that arithmetic is only correct when every line shares a width; with
## two widths the throwing line overshot by 20 mm at each end (measured) and the
## corner never closed cleanly.
##
## So there is one constant and both meshes use it. Changing chalk width is now a
## one-line change that cannot desynchronise.
const CHALK_WIDTH: float = 0.09
## Chalk is a DUSTY OFF-WHITE, not paint. `UiTheme.PANEL` is a UI panel colour and
## read as crisp white plastic at ground level — part of why these looked like
## printed lines rather than something a kid drew.
const CHALK_TINT: Color = Color(0.902, 0.878, 0.816)

## ⚠️⚠️ SOLID, NOT DASHED, BECAUSE IT HAS TO CONNECT. An earlier attempt at "make
## it look like chalk" authored each line as six strokes with gaps between them.
## That is what chalk looks like and it is the wrong answer here, because the SAME
## report also says "make sure that it actually CONNECTS" — and a line with gaps in
## it cannot close a corner. Geometry carries the SHAPE; the chalk look comes from
## the TEXTURE instead (see `chalk.png` and the `Mat_chalk` triplanar material both
## builders attach to every Markings node).
##
## ⚠️ TRIPLANAR IS WHY A TEXTURE IS POSSIBLE AT ALL HERE. `obj_writer.gd` emits no
## `vt` lines — the pipeline has no UVs, which is exactly why `Handoff.md` §5 has a
## standing question about printed type on the lata. A triplanar material needs no
## UVs: it projects from world space. So the decals get real chalk grain without a
## UV pipeline, and nothing else in the kit has to change.
## The centreline's WANDER at position `t` along the line, in metres. Two
## incommensurate sines, so it never repeats over a line's length and never needs a
## random number — same determinism rule as everything else in this file.
func _chalk_wander(t: float) -> float:
	return 0.011 * sin(t * 13.7) + 0.006 * sin(t * 31.3 + 1.1) 		+ 0.003 * sin(t * 67.1 + 0.5)


## Half the line's WIDTH at `t`. A stick of chalk held by a kid does not hold a
## width: it presses, skips, and rolls. 0.55x to 1.35x of nominal.
func _chalk_halfwidth(t: float, side: float) -> float:
	var press := 0.95 + 0.28 * sin(t * 17.9 + 0.4) + 0.12 * sin(t * 43.3 + side * 2.1)
	return CHALK_WIDTH * 0.5 * clampf(press, 0.55, 1.35)


func _chalk_line(file_name: String, length: float) -> void:
	var w := ObjWriter.new("ChalkLine")
	w.set_material("mark", CHALK_TINT)

	## ⚠️⚠️ A HAND-DRAWN RIBBON, NOT A BOX. Human, with three reference photos:
	## "make the lines not straight like idk REAL CHALK? IVE NEVER SEEN STRAIGHT UP
	## STRAIGHT CHALK WITH STRAIGHT WHITE LINE NO TEXTURE."
	## Right — and a single `_box()` is exactly a straight white line. In every one
	## of those references the line WANDERS off true by a centimetre or two, CHANGES
	## THICKNESS along its length as the stick presses and skips, and has edges that
	## are ragged rather than parallel. None of that is texture; it is the SHAPE.
	##
	## `add_extrude` takes an arbitrary outline, so the line is built as a closed
	## ribbon: forward along the low-Z edge, back along the high-Z edge, with the
	## centreline wandering and the half-width varying INDEPENDENTLY on each side.
	## Same winding as `_corrugated_outline` — that is the handedness add_extrude
	## wants.
	##
	## ⚠️ THE WANDER IS AUTHORED IN Z, WHICH THE BUILDERS DO NOT STRETCH. Both
	## builders scale these decals on the X basis column only, so a 6 m mesh drawn
	## out to 26 m keeps its wobble AMPLITUDE in real centimetres and simply gets a
	## longer wavelength. A 2 cm wobble stays a 2 cm wobble on every line on both
	## maps, which is what makes one mesh usable at four different lengths.
	const SEGS := 64
	var outline := PackedVector2Array()
	for i in range(SEGS + 1):
		var t := float(i) / float(SEGS)
		var x := -length * 0.5 + length * t
		outline.append(Vector2(x, _chalk_wander(t) - _chalk_halfwidth(t, 0.0)))
	for i in range(SEGS, -1, -1):
		var t := float(i) / float(SEGS)
		var x := -length * 0.5 + length * t
		outline.append(Vector2(x, _chalk_wander(t) + _chalk_halfwidth(t, 1.0)))
	# 0.0 smoothing: chalk grain is a hard, faceted edge. Averaging the normals
	# across the ragged boundary sands it back into the straight line this exists
	# to get rid of — the same lesson `_laundry_line` records about cloth folds.
	w.add_extrude(outline, 0.0, 0.02, "mark")
	_finish(w, file_name, 0.0)


func _throwing_line_decal() -> void:
	_chalk_line("env_throwing_line_decal", 8.0)


func _team_side_decal() -> void:
	_chalk_line("env_team_side_decal", 6.0)


## ⚠️ `_jeepney_lane_decal()` IS DELETED. DO NOT REBUILD IT. (Phase 8, 2026-07-29)
##
## It emitted the map's only piece using the `hazard` material (`UiTheme.IMPACT`,
## #F468A8), as a pink chalk lane 3.76 wide and 12 long. Explicit human
## instruction after seeing it in play: "completely remove and delete all pink
## chalk lines and their generation logic from build_eskinita.py and the scene
## files. Do not render them at all."
##
## It was also genuinely broken, and the measurement is worth keeping because it
## explains BOTH visual complaints at once. Placed at x=5.2 scaled 0.6 it
## occupied x 4.07..6.33 and z -6..+6, while the confinement box's east edge is a
## white line at x=5.0 running z -5..+5. So the pink band lay directly ON TOP of
## the white line for the white line's entire length and then ran a further metre
## past both of its ends — which is exactly the report, "they overshoot and merge
## with white lines", and exactly why the court never read as a closed shape.
##
## ⚠️ THE `HazardZone` AT x=5.4 IS STILL LIVE, AND IT NEEDS A VISUAL.
## Deleting the marking without replacing it would leave an invisible permanent
## slow-field (speed_multiplier 0.5) sitting beside the court — a worse bug than
## the one being fixed. `build_eskinita.py` now dresses that footprint with a
## real `gutter_tile` kanal instead: 3D geometry that physically explains why you
## slow down there, with no chalk and no pink anywhere on the map.
