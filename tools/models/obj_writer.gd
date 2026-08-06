extends RefCounted


const FORMAT: String = "%.5f"
const EPSILON: float = 0.00001

var _object_name: String

var _verts: PackedVector3Array = PackedVector3Array()
var _vert_index: Dictionary = {}
var _normals: PackedVector3Array = PackedVector3Array()
var _normal_index: Dictionary = {}
var _uvs: PackedVector2Array = PackedVector2Array()
var _uv_index: Dictionary = {}

var _faces: Array[Dictionary] = []

var _material_names: Array[String] = []
var _material_colors: Dictionary = {}
var _material_textures: Dictionary = {}

func _init(object_name: String = "mesh") -> void:
	_object_name = object_name

func set_material(name: String, color: Color, texture: String = "") -> void:
	if not _material_colors.has(name):
		_material_names.append(name)
	_material_colors[name] = color
	if texture != "":
		_material_textures[name] = texture


func add_tri(a: Vector3, b: Vector3, c: Vector3, material: String, normals: Array = [], uvs: Array = []) -> void:
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
	var ti := PackedInt32Array()
	if uvs.size() == 3:
		ti = PackedInt32Array([_add_uv(uvs[0]), _add_uv(uvs[1]), _add_uv(uvs[2])])
	_faces.append({"v": vi, "n": ni, "t": ti, "mat": material})

func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, material: String, normals: Array = [], uvs: Array = []) -> void:
	var n_abc: Array = []
	var n_acd: Array = []
	if normals.size() == 4:
		n_abc = [normals[0], normals[1], normals[2]]
		n_acd = [normals[0], normals[2], normals[3]]
	var t_abc: Array = []
	var t_acd: Array = []
	if uvs.size() == 4:
		t_abc = [uvs[0], uvs[1], uvs[2]]
		t_acd = [uvs[0], uvs[2], uvs[3]]
	add_tri(a, b, c, material, n_abc, t_abc)
	add_tri(a, c, d, material, n_acd, t_acd)

func add_revolve(profile: PackedVector2Array, segments: int, material: String, smooth: bool = true, deform: Callable = Callable(), transform: Transform3D = Transform3D.IDENTITY, uv_map: Callable = Callable()) -> void:
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
				continue
			var r00 := r0
			var r01 := r1
			var r11 := r1
			var r10 := r0
			if deform.is_valid():
				r00 = deform.call(r0, y0, a0)
				r01 = deform.call(r1, y1, a0)
				r11 = deform.call(r1, y1, a1)
				r10 = deform.call(r0, y0, a1)
			var v00 := transform * _ring_point(r00, y0, a0)
			var v01 := transform * _ring_point(r01, y1, a0)
			var v11 := transform * _ring_point(r11, y1, a1)
			var v10 := transform * _ring_point(r10, y0, a1)
			var normals: Array = []
			if smooth:
				var edge := Vector2(r1 - r0, y1 - y0)
				var flat := Vector2(edge.y, -edge.x).normalized()
				normals = [
					_ring_normal(flat, a0), _ring_normal(flat, a0),
					_ring_normal(flat, a1), _ring_normal(flat, a1),
				]
			var uvs: Array = []
			if uv_map.is_valid():
				uvs = [
					uv_map.call(y0, a0), uv_map.call(y1, a0),
					uv_map.call(y1, a1), uv_map.call(y0, a1),
				]
			if r0 < EPSILON:
				var tri_normals: Array = []
				if smooth:
					tri_normals = [normals[0], normals[1], normals[2]]
				var tri_uvs: Array = []
				if uv_map.is_valid():
					tri_uvs = [uvs[0], uvs[1], uvs[2]]
				add_tri(v00, v01, v11, material, tri_normals, tri_uvs)
			elif r1 < EPSILON:
				var tri_normals2: Array = []
				if smooth:
					tri_normals2 = [normals[0], normals[2], normals[3]]
				var tri_uvs2: Array = []
				if uv_map.is_valid():
					tri_uvs2 = [uvs[0], uvs[2], uvs[3]]
				add_tri(v00, v11, v10, material, tri_normals2, tri_uvs2)
			else:
				add_quad(v00, v01, v11, v10, material, normals, uvs)

func add_extrude(outline: PackedVector2Array, y_bottom: float, y_top: float, material: String, transform: Transform3D = Transform3D.IDENTITY, uv_map: Callable = Callable(), uv_wall_inset: float = 1.0) -> void:
	if outline.size() < 3:
		push_error("ObjWriter.add_extrude: outline needs >= 3 points")
		return
	for i in range(outline.size()):
		var p0 := outline[i]
		var p1 := outline[(i + 1) % outline.size()]
		var wall_uvs: Array = []
		if uv_map.is_valid():
			var u0: Vector2 = uv_map.call(p0.x * uv_wall_inset, p0.y * uv_wall_inset)
			var u1: Vector2 = uv_map.call(p1.x * uv_wall_inset, p1.y * uv_wall_inset)
			wall_uvs = [u0, u0, u1, u1]
		add_quad(
			transform * Vector3(p0.x, y_bottom, p0.y),
			transform * Vector3(p0.x, y_top, p0.y),
			transform * Vector3(p1.x, y_top, p1.y),
			transform * Vector3(p1.x, y_bottom, p1.y),
			material, [], wall_uvs
		)
	var indices := Geometry2D.triangulate_polygon(outline)
	if indices.is_empty():
		push_error("ObjWriter.add_extrude: could not triangulate outline (self-intersecting?)")
		return
	for i in range(0, indices.size(), 3):
		var a := outline[indices[i]]
		var b := outline[indices[i + 1]]
		var c := outline[indices[i + 2]]
		var cap_uvs: Array = []
		if uv_map.is_valid():
			cap_uvs = [uv_map.call(a.x, a.y), uv_map.call(b.x, b.y), uv_map.call(c.x, c.y)]
		_add_cap_tri(transform * Vector3(a.x, y_top, a.y), transform * Vector3(b.x, y_top, b.y), transform * Vector3(c.x, y_top, c.y), Vector3.UP, material, cap_uvs)
		_add_cap_tri(transform * Vector3(a.x, y_bottom, a.y), transform * Vector3(b.x, y_bottom, b.y), transform * Vector3(c.x, y_bottom, c.y), Vector3.DOWN, material, cap_uvs)


func recalculate_normals(angle_threshold_deg: float = 40.0) -> void:
	var threshold := cos(deg_to_rad(angle_threshold_deg))

	var face_normals: Array[Vector3] = []
	var vertex_faces: Dictionary = {}
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

	_normals = PackedVector3Array()
	_normal_index = {}
	for f in range(_faces.size()):
		var vi: PackedInt32Array = _faces[f]["v"]
		var ni := PackedInt32Array()
		for corner in range(3):
			var v := vi[corner]
			var own := face_normals[f]
			var sum := Vector3.ZERO
			for other in vertex_faces[v]:
				if own.dot(face_normals[other]) >= threshold:
					sum += face_normals[other]
			if sum.length() < EPSILON:
				sum = own
			ni.append(_add_normal(sum.normalized()))
		_faces[f]["n"] = ni


func center_on_volume_centroid() -> Vector3:
	var total_volume := 0.0
	var accumulated := Vector3.ZERO
	for face in _faces:
		var vi: PackedInt32Array = face["v"]
		var a := _verts[vi[0] - 1]
		var b := _verts[vi[1] - 1]
		var c := _verts[vi[2] - 1]
		var signed_volume := a.dot(b.cross(c)) / 6.0
		total_volume += signed_volume
		accumulated += signed_volume * (a + b + c) / 4.0
	var centre: Vector3
	if absf(total_volume) < EPSILON:
		push_warning("ObjWriter.center_on_volume_centroid: degenerate volume, "
			+ "falling back to the bounding-box centre")
		centre = _bounds_centre()
	else:
		centre = accumulated / total_volume
	translate_all(-centre)
	return centre

func _bounds_centre() -> Vector3:
	if _verts.is_empty():
		return Vector3.ZERO
	var lo := _verts[0]
	var hi := _verts[0]
	for v in _verts:
		lo = Vector3(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z))
		hi = Vector3(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z))
	return (lo + hi) * 0.5

func bounds_centre() -> Vector3:
	return _bounds_centre()

func bounds_size() -> Vector3:
	if _verts.is_empty():
		return Vector3.ZERO
	var lo := _verts[0]
	var hi := _verts[0]
	for v in _verts:
		lo = Vector3(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z))
		hi = Vector3(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z))
	return hi - lo

func translate_all(offset: Vector3) -> void:
	var moved := PackedVector3Array()
	for v in _verts:
		moved.append(v + offset)
	_verts = PackedVector3Array()
	_vert_index = {}
	var remap := PackedInt32Array()
	for v in moved:
		remap.append(_add_vert(v))
	for face in _faces:
		var vi: PackedInt32Array = face["v"]
		face["v"] = PackedInt32Array([
			remap[vi[0] - 1], remap[vi[1] - 1], remap[vi[2] - 1],
		])


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
	file.store_line("# Generated by tools/models/generate_all.gd - DO NOT EDIT BY HAND.")
	file.store_line("# Change the generator and re-run:")
	file.store_line("#   godot --headless -s tools/models/generate_all.gd")
	file.store_line("mtllib " + mtl_filename)
	file.store_line("o " + _object_name)
	for v in _verts:
		file.store_line("v %s %s %s" % [_fmt(v.x), _fmt(v.y), _fmt(v.z)])
	var textured := not _uvs.is_empty()
	var fallback_uv := 0
	if textured:
		fallback_uv = _add_uv(Vector2.ZERO)
		for t in _uvs:
			file.store_line("vt %s %s" % [_fmt(t.x), _fmt(t.y)])
	for n in _normals:
		file.store_line("vn %s %s %s" % [_fmt(n.x), _fmt(n.y), _fmt(n.z)])
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
			if not textured:
				file.store_line("f %d//%d %d//%d %d//%d"
					% [vi[0], ni[0], vi[1], ni[1], vi[2], ni[2]])
				continue
			var ti: PackedInt32Array = face.get("t", PackedInt32Array())
			if ti.size() != 3:
				ti = PackedInt32Array([fallback_uv, fallback_uv, fallback_uv])
			file.store_line("f %d/%d/%d %d/%d/%d %d/%d/%d"
				% [vi[0], ti[0], ni[0], vi[1], ti[1], ni[1], vi[2], ti[2], ni[2]])
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
		file.store_line("Ks 0.00000 0.00000 0.00000")
		file.store_line("Ns 1000.00000")
		file.store_line("d %s" % _fmt(color.a))
		file.store_line("illum 1")
		if _material_textures.has(material_name):
			file.store_line("map_Kd %s" % String(_material_textures[material_name]))
	file.close()


func _ring_point(radius: float, y: float, angle: float) -> Vector3:
	return Vector3(radius * cos(angle), y, radius * sin(angle))

func _ring_normal(flat: Vector2, angle: float) -> Vector3:
	return Vector3(flat.x * cos(angle), flat.y, flat.x * sin(angle)).normalized()

func _face_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var n := (b - a).cross(c - a)
	if n.length() < EPSILON:
		return Vector3.UP
	return n.normalized()

func _add_cap_tri(a: Vector3, b: Vector3, c: Vector3, want: Vector3, material: String, uvs: Array = []) -> void:
	if _face_normal(a, b, c).dot(want) < 0.0:
		var flipped: Array = []
		if uvs.size() == 3:
			flipped = [uvs[0], uvs[2], uvs[1]]
		add_tri(a, c, b, material, [want, want, want], flipped)
	else:
		add_tri(a, b, c, material, [want, want, want], uvs)

func _add_vert(v: Vector3) -> int:
	var key := "%s/%s/%s" % [_fmt(v.x), _fmt(v.y), _fmt(v.z)]
	if _vert_index.has(key):
		return _vert_index[key]
	_verts.append(v)
	var index := _verts.size()
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

func _add_uv(uv: Vector2) -> int:
	var key := "%s/%s" % [_fmt(uv.x), _fmt(uv.y)]
	if _uv_index.has(key):
		return _uv_index[key]
	_uvs.append(uv)
	var index := _uvs.size()
	_uv_index[key] = index
	return index

func _fmt(value: float) -> String:
	var snapped_value := snappedf(value, 0.00001)
	if snapped_value == 0.0:
		return FORMAT % 0.0
	return FORMAT % snapped_value

