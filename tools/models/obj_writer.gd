extends RefCounted

## Emits Wavefront `.obj` + `.mtl` geometry for the low-poly street-game assets
## (Handoff.md §4, M-1). Not a general-purpose modeller — it does exactly the
## four operations the moodboard's shapes need, and nothing else.
##
## WHY .obj RATHER THAN A .glb OR A .tscn OF PRIMITIVES
##
## `.obj` is plain text, so a mesh diffs and merges like code and needs no LFS.
## Because a *script* emits it, geometry is parameterised: a dent depth or a can
## radius is a constant to change and re-run, not a modelling session to redo.
## No Blender is needed on anyone's machine. See Handoff.md §4's M- block header
## for the full comparison and why CSG was rejected for shipping geometry.
##
## DETERMINISM IS A HARD REQUIREMENT, NOT A NICETY
##
## Running the generator twice must leave `git status` clean, or every future
## model commit carries noise and nobody will trust re-running it. Three rules
## make that true and all three are load-bearing:
##
##   1. Every float is printed at a FIXED precision (`FORMAT`), and the vertex
##      weld key is built from THAT SAME printed form. Two vertices that would
##      print identically therefore always weld identically — a weld keyed on
##      raw float bits would fuse or split depending on accumulated rounding.
##   2. Nothing iterates an unordered collection. Dictionaries here are used for
##      lookup ONLY; output order comes from parallel Arrays.
##   3. No randf(), no time, no engine-version-dependent maths beyond sin/cos.
##
## `-0.0` is normalised to `0.0` (see `_fmt`) — the two are `==` in GDScript but
## print differently, which would otherwise produce two weld keys for one point.
##
## COORDINATES
##
## Godot's convention: +Y up, characters face -Z. `add_revolve` spins around Y;
## `add_extrude` takes an outline in the XZ plane and extrudes along +Y. Faces
## are emitted counter-clockwise viewed from outside, with explicit `vn`
## normals, which is what the Wavefront spec and Godot's importer both expect.
##
## ⚠️ DO NOT "FIX" THE WINDING BY EYE. Godot uses CLOCKWISE winding for front
## faces and its .obj importer flips index order on import, so if you load one
## of these meshes and test each triangle with the familiar counter-clockwise
## rule — `(b - a).cross(c - a)` should point away from the centre — every
## single face reads as inverted. That is the expected result, not a bug:
## Godot's own `CylinderMesh` was measured under the identical test and reports
## exactly the same thing (0 outward / 72 inward by the CCW rule, and 72 outward
## by its stored normals). The meaningful check is that the STORED `vn` normals
## point outward, because those are what light the surface. Verify against an
## engine primitive rather than against a remembered convention.

## Printed precision for every coordinate. 5 decimals is ~0.01mm at this scale —
## far below anything visible, and short enough to keep the files readable.
const FORMAT: String = "%.5f"
## Below this, a revolve radius counts as "on the axis" and its quad collapses to
## a triangle rather than emitting a zero-area face.
const EPSILON: float = 0.00001

var _object_name: String

## Output order for `v` / `vn` lines. The Dictionaries beside them map a printed
## key back to a 1-based index — lookup only, never iterated (rule 2 above).
var _verts: PackedVector3Array = PackedVector3Array()
var _vert_index: Dictionary = {}
var _normals: PackedVector3Array = PackedVector3Array()
var _normal_index: Dictionary = {}

## One entry per triangle: {"v": PackedInt32Array, "n": PackedInt32Array,
## "mat": String}. Emitted in insertion order, grouped by material at write time.
var _faces: Array[Dictionary] = []

## Material names in declaration order, plus their colours. Kept as a parallel
## Array so the .mtl is written in a stable order (rule 2).
var _material_names: Array[String] = []
var _material_colors: Dictionary = {}

func _init(object_name: String = "mesh") -> void:
	_object_name = object_name

## Declares a material and its diffuse colour. Call with a `UiTheme` constant —
## never a retyped hex — so the models and the UI palette cannot drift apart.
## Re-declaring an existing name updates its colour without reordering it.
func set_material(name: String, color: Color) -> void:
	if not _material_colors.has(name):
		_material_names.append(name)
	_material_colors[name] = color

# --- Primitive operations -----------------------------------------------------

## One triangle. With `normals` empty every vertex takes the flat face normal —
## which is usually what this art style wants. Pass three normals to shade it
## smoothly (`add_revolve` does this for curved walls).
func add_tri(a: Vector3, b: Vector3, c: Vector3, material: String, normals: Array = []) -> void:
	var na: Vector3
	var nb: Vector3
	var nc: Vector3
	if normals.size() == 3:
		na = normals[0]
		nb = normals[1]
		nc = normals[2]
	else:
		var face_normal := _face_normal(a, b, c)
		na = face_normal
		nb = face_normal
		nc = face_normal
	var vi := PackedInt32Array([_add_vert(a), _add_vert(b), _add_vert(c)])
	var ni := PackedInt32Array([_add_normal(na), _add_normal(nb), _add_normal(nc)])
	_faces.append({"v": vi, "n": ni, "mat": material})

## One quad as two triangles, wound a-b-c / a-c-d. Vertices must be given in
## order around the face (not criss-cross) and counter-clockwise seen from
## outside. `normals`, if given, is four normals in the same order.
func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, material: String, normals: Array = []) -> void:
	if normals.size() == 4:
		add_tri(a, b, c, material, [normals[0], normals[1], normals[2]])
		add_tri(a, c, d, material, [normals[0], normals[2], normals[3]])
	else:
		add_tri(a, b, c, material)
		add_tri(a, c, d, material)

## Spins a 2D profile around the Y axis — the workhorse for every rotationally
## symmetric object in this game (the lata, a bollard, a tricycle wheel).
##
## `profile` is a list of (radius, height) pairs, ordered bottom to top. A
## segment whose radius CHANGES while height holds is a flat annulus, so caps,
## rims and recesses are all just profile points: the entire can — base crimp,
## wall, seam, shoulder, rolled rim and recessed lid — is one call.
##
## `smooth` shades the wall with radial normals. Set it false for a hard-edged
## facet look; it does not change the geometry either way.
## `deform`, if given, is called as `deform.call(radius, y, angle) -> float` and
## returns a replacement radius. That is how the lata's dent variants are made:
## same profile, a function that pushes a wedge of the wall inward. A deformed
## revolve's analytic normals are no longer correct, so ALWAYS follow a deformed
## call with `recalculate_normals()` — see that function's note.
func add_revolve(profile: PackedVector2Array, segments: int, material: String, smooth: bool = true, deform: Callable = Callable()) -> void:
	if profile.size() < 2 or segments < 3:
		push_error("ObjWriter.add_revolve: need >= 2 profile points and >= 3 segments")
		return
	for s in range(segments):
		var a0 := TAU * float(s) / float(segments)
		var a1 := TAU * float(s + 1) / float(segments)
		for p in range(profile.size() - 1):
			var lower := profile[p]
			var upper := profile[p + 1]
			var r0 := lower.x
			var y0 := lower.y
			var r1 := upper.x
			var y1 := upper.y
			if r0 < EPSILON and r1 < EPSILON:
				continue # both on the axis — nothing to draw
			# Each corner gets its own deformed radius: a dent has to vary with
			# angle, so the four corners of one quad are not all at the same
			# radius any more.
			var r00 := r0
			var r01 := r1
			var r11 := r1
			var r10 := r0
			if deform.is_valid():
				r00 = deform.call(r0, y0, a0)
				r01 = deform.call(r1, y1, a0)
				r11 = deform.call(r1, y1, a1)
				r10 = deform.call(r0, y0, a1)
			var v00 := _ring_point(r00, y0, a0)
			var v01 := _ring_point(r01, y1, a0)
			var v11 := _ring_point(r11, y1, a1)
			var v10 := _ring_point(r10, y0, a1)
			var normals: Array = []
			if smooth:
				# Perpendicular to the profile edge, swept around Y. For a
				# vertical wall this is the plain radial normal; for a flat
				# annulus it is straight up or down, which is what makes caps
				# expressible as profile points at all.
				var edge := Vector2(r1 - r0, y1 - y0)
				var flat := Vector2(edge.y, -edge.x).normalized()
				normals = [
					_ring_normal(flat, a0), _ring_normal(flat, a0),
					_ring_normal(flat, a1), _ring_normal(flat, a1),
				]
			if r0 < EPSILON:
				# Collapsed at the bottom: the quad degenerates to one triangle.
				var tri_normals: Array = []
				if smooth:
					tri_normals = [normals[0], normals[1], normals[2]]
				add_tri(v00, v01, v11, material, tri_normals)
			elif r1 < EPSILON:
				var tri_normals2: Array = []
				if smooth:
					tri_normals2 = [normals[0], normals[2], normals[3]]
				add_tri(v00, v11, v10, material, tri_normals2)
			else:
				add_quad(v00, v01, v11, v10, material, normals)

## Extrudes a closed outline in the XZ plane along +Y, with both caps.
##
## `outline` must be counter-clockwise in (x, z) and must not self-intersect —
## that is what makes the side walls face outward. Used for the tsinelas sole,
## signage, and corrugated sheet.
func add_extrude(outline: PackedVector2Array, y_bottom: float, y_top: float, material: String) -> void:
	if outline.size() < 3:
		push_error("ObjWriter.add_extrude: outline needs >= 3 points")
		return
	for i in range(outline.size()):
		var p0 := outline[i]
		var p1 := outline[(i + 1) % outline.size()]
		add_quad(
			Vector3(p0.x, y_bottom, p0.y),
			Vector3(p0.x, y_top, p0.y),
			Vector3(p1.x, y_top, p1.y),
			Vector3(p1.x, y_bottom, p1.y),
			material
		)
	# Geometry2D's ear clipping is deterministic for a given input, so the caps
	# do not break the determinism contract.
	var indices := Geometry2D.triangulate_polygon(outline)
	if indices.is_empty():
		push_error("ObjWriter.add_extrude: could not triangulate outline (self-intersecting?)")
		return
	for i in range(0, indices.size(), 3):
		var a := outline[indices[i]]
		var b := outline[indices[i + 1]]
		var c := outline[indices[i + 2]]
		_add_cap_tri(Vector3(a.x, y_top, a.y), Vector3(b.x, y_top, b.y), Vector3(c.x, y_top, c.y), Vector3.UP, material)
		_add_cap_tri(Vector3(a.x, y_bottom, a.y), Vector3(b.x, y_bottom, b.y), Vector3(c.x, y_bottom, c.y), Vector3.DOWN, material)

# --- Shading ------------------------------------------------------------------

## Rebuilds every normal from the geometry, averaging across adjacent faces
## whose normals are within `angle_threshold_deg` of each other.
##
## This is the "smooth by angle" / smoothing-group rule, and it is the whole
## difference between a model that reads as a moulded object and one that reads
## as a stack of primitives. A curved wall gets one smoothly-varying normal per
## vertex; a hard edge like the can's rolled rim exceeds the threshold, so the
## faces on either side keep their own normals and the edge stays crisp. Blindly
## averaging everything instead — the obvious implementation — melts every hard
## edge and makes the can look like a wax candle.
##
## Call it AFTER every add_* for a mesh. Two cases need it:
##
##   - Any deformed revolve. `add_revolve`'s analytic normals assume a surface of
##     revolution; the moment a `deform` callable moves vertices off that
##     surface they are wrong, and a dent lit by the pristine can's normals is
##     invisible.
##   - Anything built from `add_quad`/`add_tri` that should look curved, since
##     those default to flat per-face normals.
##
## 40 degrees is the default because it sits comfortably between the 22.5 degree
## step of a 16-segment revolve (which must smooth) and the near-90 degree turn
## at a rim or cap (which must not).
func recalculate_normals(angle_threshold_deg: float = 40.0) -> void:
	var threshold := cos(deg_to_rad(angle_threshold_deg))

	# Per-triangle geometric normals, and which triangles touch each vertex.
	var face_normals: Array[Vector3] = []
	var vertex_faces: Dictionary = {} # vertex index -> PackedInt32Array of face indices
	for f in range(_faces.size()):
		var vi: PackedInt32Array = _faces[f]["v"]
		var normal := _face_normal(_verts[vi[0] - 1], _verts[vi[1] - 1], _verts[vi[2] - 1])
		face_normals.append(normal)
		for corner in range(3):
			var v := vi[corner]
			if not vertex_faces.has(v):
				vertex_faces[v] = PackedInt32Array()
			var list: PackedInt32Array = vertex_faces[v]
			list.append(f)
			vertex_faces[v] = list

	# Rebuild the normal table from scratch; the old analytic entries are dead.
	_normals = PackedVector3Array()
	_normal_index = {}
	for f in range(_faces.size()):
		var vi: PackedInt32Array = _faces[f]["v"]
		var ni := PackedInt32Array()
		for corner in range(3):
			var v := vi[corner]
			var own := face_normals[f]
			var sum := Vector3.ZERO
			# Iterating a PackedInt32Array built in face order keeps this
			# deterministic — the Dictionary is lookup only (see header rule 2).
			for other in vertex_faces[v]:
				if own.dot(face_normals[other]) >= threshold:
					sum += face_normals[other]
			if sum.length() < EPSILON:
				sum = own
			ni.append(_add_normal(sum.normalized()))
		_faces[f]["n"] = ni

# --- Output -------------------------------------------------------------------

## Writes `<path>.obj` and a sibling `<path>.mtl`. `path` is a res:// path
## WITHOUT an extension, e.g. "res://assets/models/lata".
func write(path: String) -> void:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	_write_mtl(path + ".mtl")
	_write_obj(path + ".obj", (path + ".mtl").get_file())

func _write_obj(path: String, mtl_filename: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ObjWriter: cannot write %s" % path)
		return
	# ASCII only in generated files: a stray em dash is fine for Godot but some
	# .obj parsers choke on non-ASCII bytes even inside a comment.
	file.store_line("# Generated by tools/models/generate_all.gd - DO NOT EDIT BY HAND.")
	file.store_line("# Change the generator and re-run:")
	file.store_line("#   godot --headless -s tools/models/generate_all.gd")
	file.store_line("mtllib " + mtl_filename)
	file.store_line("o " + _object_name)
	for v in _verts:
		file.store_line("v %s %s %s" % [_fmt(v.x), _fmt(v.y), _fmt(v.z)])
	for n in _normals:
		file.store_line("vn %s %s %s" % [_fmt(n.x), _fmt(n.y), _fmt(n.z)])
	# Grouped by material in declaration order so the importer produces one
	# surface per material, in a stable order — a mesh whose surface order
	# shuffles between runs would churn every .tscn that overrides a material.
	for material_name in _material_names:
		var wrote_header := false
		for face in _faces:
			if face["mat"] != material_name:
				continue
			if not wrote_header:
				file.store_line("usemtl " + material_name)
				wrote_header = true
			var vi: PackedInt32Array = face["v"]
			var ni: PackedInt32Array = face["n"]
			file.store_line("f %d//%d %d//%d %d//%d" % [vi[0], ni[0], vi[1], ni[1], vi[2], ni[2]])
	file.close()

func _write_mtl(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ObjWriter: cannot write %s" % path)
		return
	file.store_line("# Generated by tools/models/generate_all.gd - DO NOT EDIT BY HAND.")
	for material_name in _material_names:
		var color: Color = _material_colors[material_name]
		file.store_line("newmtl " + material_name)
		file.store_line("Kd %s %s %s" % [_fmt(color.r), _fmt(color.g), _fmt(color.b)])
		# Flat and matte on purpose: the moodboard and PEAK are both flat
		# high-saturation colour with no specular hit. M-4 replaces these with
		# the toon shader; until then this is already much closer than the
		# importer's default grey.
		file.store_line("Ks 0.00000 0.00000 0.00000")
		# ⚠️ Ns MUST STAY 1000. Godot's .obj importer does not use Ns as the
		# Wavefront spec's specular exponent — it maps it INVERSELY onto
		# StandardMaterial3D.metallic. Measured on 4.7.1, three data points:
		#
		#     Ns 0     -> metallic 1.0
		#     Ns 1     -> metallic 0.999
		#     Ns 1000  -> metallic 0.0
		#
		# i.e. metallic = 1 - Ns/1000. So `Ns 1`, the spec-correct way to write
		# "barely shiny", imports as an almost fully METALLIC surface. Metal has
		# no diffuse response, so with no reflection probe or sky in the scene
		# its unlit side renders pure black — measured at RGB(2,1,0) on the first
		# lata render, which reads as a broken light and is nothing of the kind.
		#
		# Also note: the .mtl is NOT listed in the .obj's [deps], so editing it
		# alone will NOT trigger a reimport. Delete assets/models/*.obj.import
		# and re-run --import after changing anything here, or you will measure
		# the previous values and conclude your fix did nothing.
		file.store_line("Ns 1000.00000")
		file.store_line("d %s" % _fmt(color.a))
		file.store_line("illum 1")
	file.close()

# --- Internals ----------------------------------------------------------------

func _ring_point(radius: float, y: float, angle: float) -> Vector3:
	return Vector3(radius * cos(angle), y, radius * sin(angle))

func _ring_normal(flat: Vector2, angle: float) -> Vector3:
	return Vector3(flat.x * cos(angle), flat.y, flat.x * sin(angle)).normalized()

func _face_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var n := (b - a).cross(c - a)
	if n.length() < EPSILON:
		return Vector3.UP # degenerate; the face contributes nothing anyway
	return n.normalized()

## Adds a cap triangle, flipping its winding if it would face the wrong way.
## Cheaper and far more robust than reasoning about what winding
## `Geometry2D.triangulate_polygon` happens to return for a given outline.
func _add_cap_tri(a: Vector3, b: Vector3, c: Vector3, want: Vector3, material: String) -> void:
	if _face_normal(a, b, c).dot(want) < 0.0:
		add_tri(a, c, b, material, [want, want, want])
	else:
		add_tri(a, b, c, material, [want, want, want])

## Welds on the PRINTED form, not the raw float — see the determinism note above.
func _add_vert(v: Vector3) -> int:
	var key := "%s/%s/%s" % [_fmt(v.x), _fmt(v.y), _fmt(v.z)]
	if _vert_index.has(key):
		return _vert_index[key]
	_verts.append(v)
	var index := _verts.size() # .obj indices are 1-based
	_vert_index[key] = index
	return index

func _add_normal(n: Vector3) -> int:
	var key := "%s/%s/%s" % [_fmt(n.x), _fmt(n.y), _fmt(n.z)]
	if _normal_index.has(key):
		return _normal_index[key]
	_normals.append(n)
	var index := _normals.size()
	_normal_index[key] = index
	return index

## Snaps to the output precision FIRST, then formats. Both steps matter:
##
## - Snapping makes the weld key exactly the printed value, so two points that
##   render identically always weld into one vertex.
## - It also collapses the tiny non-zero values trigonometry leaves behind.
##   `cos(3 * PI / 2)` is about -1.8e-16, not 0, so a raw `%.5f` prints it as
##   `-0.00000` — which is a DIFFERENT weld key from `0.00000` and left the
##   proof cylinder with 28 vertices where it should have had 26, plus signed
##   zeros in the file. Snapping turns it into `-0.0`, and `-0.0 == 0.0` is true
##   in GDScript, so the check below normalises the sign away.
func _fmt(value: float) -> String:
	var snapped_value := snappedf(value, 0.00001)
	if snapped_value == 0.0:
		return FORMAT % 0.0
	return FORMAT % snapped_value
