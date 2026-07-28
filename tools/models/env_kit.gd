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
##   * Characters face -Z, so a wall panel's "front" faces +Z by default.
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
	_church_facade()
	_basketball_ring()

	# --- field markings (serve BOTH round-win modes) ------------------------
	_base_circle_decal()
	_throwing_line_decal()
	_team_side_decal()
	_jeepney_lane_decal()

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
	_box(w, 0, 0, 0.24, 0.24, 0.0, 7.20, "timber")
	_box(w, 0, 0, 1.60, 0.14, 6.10, 6.24, "timber")
	for i in range(3):
		var x := -0.6 + 0.6 * float(i)
		_box(w, x, 0, 0.09, 0.09, 6.24, 6.38, "wire")
		_wire(w, Vector3(x, 6.35, 0.0), Vector3(x + 6.0, 6.35, 0.0), 0.55, 0.025, 8, "wire")
	_finish(w, "env_post_electric")

## Sampay. This is the Barong Barong reference folded into Eskinita rather than
## spent on a third map that would never be built — see Art_Direction.md
## §1. Strung ACROSS the alley overhead, never along it.
func _laundry_line() -> void:
	var w := ObjWriter.new("LaundryLine")
	w.set_material("timber", UiTheme.ENV_WOOD_DARK)
	w.set_material("cloth", UiTheme.ENV_TARP)
	w.set_material("cloth_warm", UiTheme.HIGHLIGHT)
	w.set_material("cloth_rust", UiTheme.ENV_RUST)

	# ⚠️ NO POSTS OF ITS OWN, and it spans 16 units rather than sitting on the
	# 2-unit grid. Both deliberate, both found by rendering: this piece is strung
	# BETWEEN the two wall lines, so posts of its own stood in the middle of the
	# road holding up a line nobody could see. A sampay hangs off the buildings.
	_wire(w, Vector3(-8.0, 2.62, 0.0), Vector3(8.0, 2.62, 0.0), 0.42, 0.025, 12, "cloth")

	# Five garments, alternating material and yaw out of the seeded table. Flat
	# quads, hung from the sag — a shirt at this distance is a rectangle.
	const CLOTHS: Array[String] = ["cloth", "cloth_warm", "cloth_rust", "cloth",
		"cloth_warm", "cloth_rust", "cloth"]
	for i in range(7):
		var t := (float(i) + 0.5) / 7.0
		var x := lerpf(-8.0, 8.0, t)
		var y := 2.62 - 0.42 * sin(PI * t)
		var yaw: float = JITTER_YAW[i % JITTER_YAW.size()]
		w.add_extrude(_rect_yaw(x, 0.0, 0.44, 0.03, yaw), y - 0.62, y, CLOTHS[i])
	_finish(w, "env_laundry_line")

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
func _throwing_line_decal() -> void:
	var w := ObjWriter.new("ThrowingLineDecal")
	w.set_material("mark", UiTheme.PANEL)
	_box(w, 0, 0, 8.0, 0.12, 0.0, 0.02, "mark")
	_finish(w, "env_throwing_line_decal")

func _team_side_decal() -> void:
	var w := ObjWriter.new("TeamSideDecal")
	w.set_material("mark", UiTheme.PANEL)
	_box(w, 0, 0, 6.0, 0.08, 0.0, 0.02, "mark")
	_finish(w, "env_team_side_decal")

## What motivates the HazardZone. The hazard exists in code and currently sits at
## (5, 0.5, 5) with nothing in the map explaining it; this is the jeepney lane it
## is supposed to be.
##
## ⚠️ The DECAL is all that is built here. Placement, the collider and the
## slow-zone behaviour are not this file's — and HazardZone must NOT join the
## `hazard_zone` group, which main.gd::_reset_world() empties every round.
func _jeepney_lane_decal() -> void:
	var w := ObjWriter.new("JeepneyLaneDecal")
	w.set_material("hazard", UiTheme.IMPACT)
	# ⚠️ EDGE STRIPES, not a filled rectangle. Rendered as a fill it was a solid
	# pink carpet that shouted over the Props — and IMPACT belongs to them and to
	# hit feedback, not to the floor. Two stripes plus rungs read as a marked lane
	# and stay quiet.
	for side in SIDES:
		_box(w, side * 1.8, 0.0, 0.16, 12.0, 0.0, 0.01, "hazard")
	for i in range(7):
		_box(w, 0.0, -5.0 + 1.7 * float(i), 3.6, 0.10, 0.0, 0.01, "hazard")
	_finish(w, "env_jeepney_lane_decal")
