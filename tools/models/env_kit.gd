extends RefCounted


const ObjWriter = preload("res://tools/models/obj_writer.gd")

const JITTER_YAW: Array[float] = [0.14, -0.21, 0.05, -0.09, 0.18, -0.03]
const SIDES: Array[float] = [-1.0, 1.0]

var _dir: String = ""

func build_all(output_dir: String) -> void:
	_dir = output_dir

	_road_tile()
	_road_tile_line()
	_kerb_tile()
	_gutter_tile()
	_plaza_tile()

	_wall_plain()
	_wall_corrugated()
	_wall_corrugated_leaning()
	_post_electric()
	_laundry_line()
	_sari_sari_store()
	_building_block("env_building_block_a", 9.0, UiTheme.ENV_PAINT_CREAM)
	_building_block("env_building_block_b", 12.0, UiTheme.ENV_PAINT_TERRA)
	_building_block("env_building_block_c", 9.0, UiTheme.ENV_PAINT_MINT)
	_building_block("env_building_block_d", 12.0, UiTheme.ENV_PAINT_OCHRE)

	_bollard()
	_crate_stack()
	_tire()
	_monobloc_chair()
	_oil_drum()
	_tricycle()

	_bench()
	_planter()
	_flagpole()
	_tree("env_tree", 4.2, UiTheme.ENV_FOLIAGE)
	_tree("env_tree_far", 4.8, UiTheme.ENV_FOLIAGE_DARK)

	_halaman_lata()
	_atip_yero()
	_church_facade()
	_basketball_ring()
	_monument()
	_railing()
	_planter_hedge()
	_bell_tower()
	_municipal_hall()

	_chalk_piko()
	_chalk_tao()
	_chalk_bulaklak()
	_chalk_gulo()
	_base_circle_decal()
	_throwing_line_decal()
	_team_side_decal()



func _rect(cx: float, cz: float, w: float, d: float) -> PackedVector2Array:
	var hw := w * 0.5
	var hd := d * 0.5
	return PackedVector2Array([
		Vector2(cx + hw, cz - hd),
		Vector2(cx + hw, cz + hd),
		Vector2(cx - hw, cz + hd),
		Vector2(cx - hw, cz - hd),
	])

func _rect_yaw(cx: float, cz: float, w: float, d: float, yaw: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := cos(yaw)
	var s := sin(yaw)
	for p in _rect(0.0, 0.0, w, d):
		out.append(Vector2(cx + p.x * c - p.y * s, cz + p.x * s + p.y * c))
	return out

func _ngon(cx: float, cz: float, r: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		out.append(Vector2(cx + r * cos(a), cz + r * sin(a)))
	return out

func _box(w: ObjWriter, cx: float, cz: float, width: float, depth: float,
		y0: float, y1: float, material: String) -> void:
	w.add_extrude(_rect(cx, cz, width, depth), y0, y1, material)

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
		w.add_quad(b0, b1, a1, a0, material)

func _finish(w: ObjWriter, file_name: String, smooth_deg: float = 40.0) -> void:
	w.recalculate_normals(smooth_deg)
	w.write(_dir + file_name)
	print("  ", file_name)


func _road_tile() -> void:
	var w := ObjWriter.new("RoadTile")
	w.set_material("asphalt", UiTheme.ENV_ASPHALT)
	_box(w, 0, 0, 2.0, 2.0, 0.0, 0.06, "asphalt")
	_finish(w, "env_road_tile")

func _road_tile_line() -> void:
	var w := ObjWriter.new("RoadTileLine")
	w.set_material("asphalt", UiTheme.ENV_ASPHALT)
	w.set_material("paint", UiTheme.PANEL)
	_box(w, 0, 0, 2.0, 2.0, 0.0, 0.06, "asphalt")
	_flat_rect(w, 0, 0, 0.10, 1.20, 0.062, "paint")
	_finish(w, "env_road_tile_line")

func _kerb_tile() -> void:
	var w := ObjWriter.new("KerbTile")
	w.set_material("concrete", UiTheme.ENV_CONCRETE)
	_box(w, 0, 0, 2.0, 0.35, 0.0, 0.15, "concrete")
	_finish(w, "env_kerb_tile")

func _gutter_tile() -> void:
	var w := ObjWriter.new("GutterTile")
	w.set_material("asphalt", UiTheme.ENV_ASPHALT)
	w.set_material("channel", UiTheme.ENV_CONCRETE_DARK)
	_box(w, 0.0, -0.325, 2.0, 1.35, 0.0, 0.06, "asphalt")
	_box(w, 0.0, 0.525, 2.0, 0.35, 0.0, 0.02, "channel")
	_box(w, 0.0, 0.850, 2.0, 0.30, 0.0, 0.15, "channel")
	_finish(w, "env_gutter_tile")

func _plaza_tile() -> void:
	var w := ObjWriter.new("PlazaTile")
	w.set_material("concrete", UiTheme.ENV_CONCRETE)
	w.set_material("score", UiTheme.PANEL)
	_box(w, 0, 0, 2.0, 2.0, 0.0, 0.06, "concrete")
	_flat_rect(w, 0.0, -0.985, 2.0, 0.03, 0.062, "score")
	_flat_rect(w, -0.985, 0.0, 0.03, 2.0, 0.062, "score")
	_finish(w, "env_plaza_tile")


func _wall_plain() -> void:
	var w := ObjWriter.new("WallPlain")
	w.set_material("concrete", UiTheme.ENV_CONCRETE)
	w.set_material("skirt", UiTheme.ENV_CONCRETE_DARK)
	_box(w, 0, 0, 2.0, 0.25, 0.40, 3.00, "concrete")
	_box(w, 0, 0, 2.0, 0.25, 0.00, 0.40, "skirt")
	_finish(w, "env_wall_plain")

func _corrugated_outline() -> PackedVector2Array:
	const RIDGES := 17
	const AMPLITUDE := 0.11
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
	w.add_extrude(outline, 0.00, 0.30, "rust")
	_finish(w, "env_wall_corrugated", 22.0)

func _post_electric() -> void:
	var w := ObjWriter.new("PostElectric")
	w.set_material("timber", UiTheme.ENV_WOOD_DARK)
	w.set_material("wire", UiTheme.INK)

	w.set_material("drum", UiTheme.ENV_CONCRETE_DARK)
	w.set_material("rust", UiTheme.ENV_RUST)

	_box(w, 0, 0, 0.24, 0.24, 0.0, 7.20, "timber")
	_box(w, 0, 0, 1.60, 0.14, 6.10, 6.24, "timber")
	for i in range(3):
		var x := -0.6 + 0.6 * float(i)
		_box(w, x, 0, 0.09, 0.09, 6.24, 6.38, "wire")
		_wire(w, Vector3(x, 6.35, 0.0), Vector3(x + 6.0, 6.35, 0.0), 0.55, 0.025, 8, "wire")


	w.add_extrude(_ngon(0.30, 0.0, 0.26, 8), 4.85, 5.62, "drum")
	_box(w, 0.30, 0, 0.14, 0.14, 5.62, 5.78, "rust")
	_box(w, 0.08, 0, 0.44, 0.10, 5.10, 5.22, "timber")

	_box(w, -0.10, 0, 1.10, 0.12, 5.52, 5.64, "timber")
	for i in range(2):
		var x2 := -0.48 + 0.72 * float(i)
		_box(w, x2, 0, 0.08, 0.08, 5.64, 5.74, "wire")
		_wire(w, Vector3(x2, 5.70, 0.0), Vector3(x2 + 6.0, 5.70, 0.0),
			0.92, 0.022, 8, "wire")

	var drops := [[5.05, 1.25], [4.78, 0.78], [5.30, 1.55]]
	for i in range(drops.size()):
		var y: float = drops[i][0]
		var sag: float = drops[i][1]
		var off := -0.22 + 0.20 * float(i)
		_wire(w, Vector3(off, y, 0.0), Vector3(off + 6.0, y, 0.0),
			sag, 0.018, 8, "wire")

	for i in range(4):
		var ry := 4.05 + 0.11 * float(i)
		var rr := 0.30 - 0.03 * float(i)
		w.add_revolve(PackedVector2Array([
			Vector2(rr, ry), Vector2(rr + 0.022, ry + 0.02),
			Vector2(rr, ry + 0.05),
		]), 9, "wire", true, Callable(),
			Transform3D(Basis.IDENTITY, Vector3(-0.16, 0.0, 0.0)))
	_finish(w, "env_post_electric")

func _laundry_line() -> void:
	var w := ObjWriter.new("LaundryLine")
	w.set_material("timber", UiTheme.ENV_WOOD_DARK)
	w.set_material("cloth", UiTheme.ENV_TARP)
	w.set_material("cloth_pale", UiTheme.ENV_PAINT_CREAM)
	w.set_material("cloth_mint", UiTheme.ENV_PAINT_MINT)
	w.set_material("cloth_grey", UiTheme.ENV_CONCRETE)

	_wire(w, Vector3(-7.95, 2.62, 0.0), Vector3(7.95, 2.62, 0.0), 0.42, 0.025, 12, "cloth")
	for _sx in SIDES:
		_box(w, _sx * 7.75, 0.0, 0.42, 0.42, 2.44, 2.80, "timber")

	const CLOTHS: Array[String] = ["cloth", "cloth_pale", "cloth_mint", "cloth",
		"cloth_grey", "cloth_pale", "cloth_mint"]
	const CLOTH_SEGMENTS := 5
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
		var along := Vector3(cos(yaw), 0.0, sin(yaw)) * half_w
		var bow := Vector3(-sin(yaw), 0.0, cos(yaw)) * (half_w * 0.22)
		for s in range(CLOTH_SEGMENTS):
			var f0 := float(s) / float(CLOTH_SEGMENTS)
			var f1 := float(s + 1) / float(CLOTH_SEGMENTS)
			var y0 := y_top - drop * f0
			var y1 := y_top - drop * f1
			var w0 := lerpf(0.82, 1.0, f0)
			var w1 := lerpf(0.82, 1.0, f1)
			var b0 := sin(PI * f0)
			var b1 := sin(PI * f1)
			var p0a := Vector3(x, y0, 0.0) - along * w0 + bow * b0
			var p0b := Vector3(x, y0, 0.0) + along * w0 + bow * b0
			var p1a := Vector3(x, y1, 0.0) - along * w1 + bow * b1
			var p1b := Vector3(x, y1, 0.0) + along * w1 + bow * b1
			w.add_quad(p0a, p0b, p1b, p1a, material)
			w.add_quad(p1a, p1b, p0b, p0a, material)
	_finish(w, "env_laundry_line", 0.0)

func _sari_sari_store() -> void:
	var w := ObjWriter.new("SariSariStore")
	w.set_material("concrete", UiTheme.ENV_CONCRETE)
	w.set_material("timber", UiTheme.ENV_WOOD)
	w.set_material("dark", UiTheme.INK)
	w.set_material("tarp", UiTheme.ENV_TARP)
	w.set_material("stripe", UiTheme.HIGHLIGHT)

	_box(w, 0, 0, 2.0, 1.0, 0.0, 2.60, "concrete")
	_box(w, 0, -0.62, 2.0, 0.40, 0.82, 0.98, "timber")
	_box(w, 0, -0.50, 1.20, 0.06, 1.10, 1.90, "dark")
	for i in range(5):
		_box(w, -0.48 + 0.24 * float(i), -0.54, 0.04, 0.04, 1.10, 1.90, "timber")
	_box(w, 0, -0.85, 2.40, 0.70, 2.02, 2.10, "tarp")
	for i in range(3):
		_box(w, -0.70 + 0.70 * float(i), -0.85, 0.22, 0.70, 2.10, 2.12, "stripe")
	for i in range(6):
		_box(w, -0.55 + 0.22 * float(i), -1.16, 0.10, 0.02, 1.55, 1.95, "stripe")
	_finish(w, "env_sari_sari_store")

func _building_block(file_name: String, height: float, body: Color) -> void:
	var w := ObjWriter.new("BuildingBlock")
	w.set_material("body", body)
	w.set_material("band", UiTheme.ENV_CONCRETE_DARK)
	w.set_material("plinth", UiTheme.ENV_PAINT_PLINTH)
	w.set_material("window", UiTheme.INK)

	_box(w, 0, 0, 4.0, 3.0, 0.0, height, "body")
	_box(w, 0, 0, 4.08, 3.08, 0.0, 2.4, "plinth")
	_box(w, 0, 0, 4.06, 3.06, height - 0.45, height - 0.25, "band")

	var rows := int((height - 3.2) / 2.6)
	var hw := 0.31
	var hh := 0.45
	for row in range(rows):
		var y := 3.55 + 2.6 * float(row)
		for col in range(3):
			var cx := -1.2 + 1.2 * float(col)
			_window(w, Vector3(cx, y, -1.51), Vector3(hw, 0, 0), Vector3(0, hh, 0))
			_window(w, Vector3(cx, y, 1.51), Vector3(hw, 0, 0), Vector3(0, hh, 0))
		for col in range(2):
			var cz := -0.7 + 1.4 * float(col)
			_window(w, Vector3(-2.01, y, cz), Vector3(0, 0, hw), Vector3(0, hh, 0))
			_window(w, Vector3(2.01, y, cz), Vector3(0, 0, hw), Vector3(0, hh, 0))
	_finish(w, file_name)

func _window(w: ObjWriter, centre: Vector3, right: Vector3, up: Vector3) -> void:
	var a := centre - right - up
	var b := centre - right + up
	var c := centre + right + up
	var d := centre + right - up
	w.add_quad(a, b, c, d, "window")
	w.add_quad(d, c, b, a, "window")

func _flat_rect_vertical(w: ObjWriter, cx: float, z: float, width: float,
		height: float, y_bottom: float, material: String) -> void:
	var hw := width * 0.5
	w.add_quad(
		Vector3(cx - hw, y_bottom, z),
		Vector3(cx - hw, y_bottom + height, z),
		Vector3(cx + hw, y_bottom + height, z),
		Vector3(cx + hw, y_bottom, z),
		material)


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

func _crate_stack() -> void:
	var w := ObjWriter.new("CrateStack")
	w.set_material("timber", UiTheme.ENV_WOOD)
	w.add_extrude(_rect_yaw(0.00, 0.00, 0.60, 0.60, JITTER_YAW[0]), 0.00, 0.32, "timber")
	w.add_extrude(_rect_yaw(0.04, -0.03, 0.55, 0.55, JITTER_YAW[1]), 0.32, 0.62, "timber")
	w.add_extrude(_rect_yaw(-0.03, 0.05, 0.50, 0.50, JITTER_YAW[2]), 0.62, 0.90, "timber")
	_finish(w, "env_crate_stack")

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

func _wall_corrugated_leaning() -> void:
	var w := ObjWriter.new("WallCorrugatedLeaning")
	w.set_material("sheet", UiTheme.ENV_GI_SHEET)
	w.set_material("rust", UiTheme.ENV_RUST)
	var outline := _corrugated_outline()
	var lean := Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(6.0)), Vector3.ZERO)
	w.add_extrude(outline, 0.30, 2.40, "sheet", lean)
	w.add_extrude(outline, 0.00, 0.30, "rust", lean)
	_finish(w, "env_wall_corrugated_leaning", 22.0)

func _tricycle() -> void:
	var w := ObjWriter.new("Tricycle")
	w.set_material("frame", UiTheme.ENV_RUST)
	w.set_material("roof", UiTheme.ENV_GI_SHEET)
	w.set_material("rubber", UiTheme.ENV_RUBBER)
	w.set_material("trim", UiTheme.HIGHLIGHT)

	_box(w, -0.34, -0.05, 0.30, 1.30, 0.34, 0.72, "frame")
	_box(w, -0.34, 0.18, 0.34, 0.46, 0.72, 0.82, "rubber")
	_box(w, -0.34, -0.62, 0.52, 0.08, 0.86, 0.94, "frame")
	_box(w, 0.32, 0.10, 0.78, 0.92, 0.20, 0.86, "frame")
	_box(w, 0.32, 0.10, 0.84, 0.98, 0.86, 0.92, "trim")
	for sz in SIDES:
		_box(w, 0.32, 0.10 + sz * 0.40, 0.07, 0.07, 0.92, 1.20, "frame")
	_box(w, 0.32, 0.10, 0.90, 1.04, 1.20, 1.26, "roof")

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

func _blade(w: ObjWriter, root: Vector3, dir: Vector2, length: float,
		half_width: float, rise: float, droop: float, material: String) -> void:
	var d := dir.normalized()
	var perp := Vector2(-d.y, d.x) * half_width
	var mid := root + Vector3(d.x * length * 0.5, rise * 0.5 - droop,
		d.y * length * 0.5)
	var tip := root + Vector3(d.x * length, rise, d.y * length)
	var root_perp := perp * 0.22
	var r0 := Vector3(root.x + root_perp.x, root.y, root.z + root_perp.y)
	var r1 := Vector3(root.x - root_perp.x, root.y, root.z - root_perp.y)
	var m0 := Vector3(mid.x + perp.x * 1.15, mid.y, mid.z + perp.y * 1.15)
	var m1 := Vector3(mid.x - perp.x * 1.15, mid.y, mid.z - perp.y * 1.15)
	var t0 := Vector3(tip.x + perp.x * 0.06, tip.y, tip.z + perp.y * 0.06)
	var t1 := Vector3(tip.x - perp.x * 0.06, tip.y, tip.z - perp.y * 0.06)
	w.add_quad(r0, m0, m1, r1, material)
	w.add_quad(r1, m1, m0, r0, material)
	w.add_quad(m0, t0, t1, m1, material)
	w.add_quad(m1, t1, t0, m0, material)


func _puno_saging() -> void:
	var w := ObjWriter.new("PunoSaging")
	w.set_material("stem", UiTheme.ENV_FOLIAGE_DARK)
	w.set_material("leaf", UiTheme.ENV_FOLIAGE)
	w.set_material("leaf_old", UiTheme.ENV_FOLIAGE_DARK)

	for k in range(2):
		var ox := 0.0 if k == 0 else 0.46
		var oz := 0.0 if k == 0 else 0.30
		var top := 2.40 if k == 0 else 1.55
		w.add_revolve(PackedVector2Array([
			Vector2(0.00, 0.00), Vector2(0.22, 0.00),
			Vector2(0.19, top * 0.55), Vector2(0.13, top),
			Vector2(0.00, top),
		]), 7, "stem")
		var blades := 6 if k == 0 else 5
		for i in range(blades):
			var a := TAU * float(i) / float(blades) + (0.5 if k else 0.0)
			var dir := Vector2(cos(a), sin(a))
			var long := (k == 0)
			_blade(w, Vector3(ox + dir.x * 0.11, top - 0.14, oz + dir.y * 0.11),
				dir,
				2.35 if long else 1.70,
				0.36 if long else 0.28,
				-1.05 if long else -0.75,
				0.30 if i % 2 else 0.16,
				"leaf" if i % 2 else "leaf_old")
	_finish(w, "env_puno_saging", 0.0)


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
		w.add_extrude(_ngon(lean, 0.0, r0, 7), y0, y1 + 0.02, "trunk")
		lean += lean_step * (1.0 + float(i) * 0.18)
	for i in range(9):
		var a := TAU * float(i) / 9.0
		var dir := Vector2(cos(a), sin(a))
		_blade(w, Vector3(lean + dir.x * 0.13, TRUNK_TOP - 0.12, dir.y * 0.13),
			dir, 2.05, 0.22, 0.45 if i % 2 else 0.15, 1.15,
			"frond" if i % 2 else "frond_dark")
	for i in range(3):
		var a := TAU * float(i) / 3.0 + 0.6
		w.add_revolve(PackedVector2Array([
			Vector2(0.00, TRUNK_TOP - 0.42), Vector2(0.15, TRUNK_TOP - 0.30),
			Vector2(0.00, TRUNK_TOP - 0.14),
		]), 6, "nut", true, Callable(), Transform3D(Basis.IDENTITY,
			Vector3(lean + cos(a) * 0.26, 0.0, sin(a) * 0.26)))
	_finish(w, "env_puno_niyog")


func _puno_mangga() -> void:
	var w := ObjWriter.new("PunoMangga")
	w.set_material("trunk", UiTheme.ENV_WOOD_DARK)
	w.set_material("canopy", UiTheme.ENV_FOLIAGE)
	w.set_material("canopy_dark", UiTheme.ENV_FOLIAGE_DARK)

	w.add_revolve(PackedVector2Array([
		Vector2(0.00, 0.00), Vector2(0.46, 0.00),
		Vector2(0.30, 0.90), Vector2(0.26, 1.55),
	]), 8, "trunk")
	for k in range(2):
		var a := 0.9 + PI * float(k)
		w.add_extrude(_ngon(cos(a) * 0.30, sin(a) * 0.30, 0.15, 5),
			0.90, 2.35, "trunk")
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


func _halaman_lata() -> void:
	var w := ObjWriter.new("HalamanLata")
	w.set_material("tin", UiTheme.ENV_PAINT_TERRA)
	w.set_material("rim", UiTheme.ENV_CONCRETE_DARK)
	w.set_material("soil", UiTheme.ENV_WOOD_DARK)
	w.set_material("leaf", UiTheme.ENV_FOLIAGE)

	w.add_extrude(_ngon(0.0, 0.0, 0.16, 9), 0.00, 0.24, "tin")
	w.add_extrude(_ngon(0.0, 0.0, 0.17, 9), 0.24, 0.27, "rim")
	w.add_extrude(_ngon(0.0, 0.0, 0.145, 9), 0.27, 0.29, "soil")
	for i in range(5):
		var a := TAU * float(i) / 5.0 + 0.3
		var dir := Vector2(cos(a), sin(a))
		_blade(w, Vector3(dir.x * 0.04, 0.29, dir.y * 0.04),
			dir, 0.30, 0.075, 0.30, 0.10, "leaf")
	_finish(w, "env_halaman_lata", 0.0)


func _atip_yero() -> void:
	var w := ObjWriter.new("AtipYero")
	w.set_material("sheet", UiTheme.ENV_GI_SHEET)
	w.set_material("rust", UiTheme.ENV_RUST)
	w.set_material("timber", UiTheme.ENV_WOOD_DARK)

	const RIDGES := 9
	const SPAN := 2.00
	const DEPTH := 1.45
	const FRONT_Y := 2.02
	const BACK_Y := 2.34

	for sx in SIDES:
		_box(w, sx * (SPAN * 0.5 - 0.14), DEPTH * 0.5 - 0.10,
			0.10, 0.10, 0.0, FRONT_Y, "timber")
	_box(w, 0.0, -DEPTH * 0.5 + 0.06, SPAN + 0.10, 0.12,
		BACK_Y - 0.12, BACK_Y, "timber")

	var ridge_w := SPAN / float(RIDGES)
	for i in range(RIDGES):
		var cx := -SPAN * 0.5 + ridge_w * (float(i) + 0.5)
		var high := (i % 2 == 0)
		var y0 := FRONT_Y + (0.00 if high else 0.05)
		var y1 := y0 + (0.09 if high else 0.05)
		var step := (BACK_Y - FRONT_Y) * 0.55
		_box(w, cx, DEPTH * 0.25, ridge_w * 0.92, DEPTH * 0.5, y0, y1, "sheet")
		_box(w, cx, -DEPTH * 0.25 + 0.11, ridge_w * 0.92, DEPTH * 0.5 + 0.22,
			y0 + step, y1 + step, "sheet")
		_box(w, cx, 0.0, ridge_w * 0.92, 0.12, y0, y1 + step, "sheet")
	_box(w, 0.0, DEPTH * 0.5 - 0.05, SPAN, 0.10, FRONT_Y - 0.04, FRONT_Y + 0.06,
		"rust")
	_finish(w, "env_atip_yero", 22.0)


func _church_facade() -> void:
	var w := ObjWriter.new("ChurchFacade")
	w.set_material("stone", UiTheme.ENV_CONCRETE)
	w.set_material("timber", UiTheme.ENV_WOOD_DARK)
	w.set_material("dark", UiTheme.INK)

	_box(w, 0, 0, 6.0, 1.5, 0.0, 6.40, "stone")
	_box(w, 0, 0, 4.4, 1.5, 6.40, 7.10, "stone")
	_box(w, 0, 0, 2.6, 1.5, 7.10, 7.70, "stone")
	_box(w, 0, 0, 0.22, 0.22, 7.70, 8.40, "timber")
	_box(w, 0, 0, 0.90, 0.20, 7.95, 8.15, "timber")

	const ARCH := 6
	for i in range(ARCH):
		var t := float(i) / float(ARCH)
		var half := 0.95 * sqrt(maxf(1.0 - t * t, 0.0))
		_box(w, 0, -0.76, half * 2.0, 0.06, 2.60 + 0.16 * float(i), 2.76 + 0.16 * float(i), "dark")
	_box(w, 0, -0.76, 1.90, 0.06, 0.00, 2.60, "timber")
	w.add_revolve(PackedVector2Array([
		Vector2(0.00, 4.80), Vector2(0.62, 4.80),
	]), 12, "dark")
	_finish(w, "env_church_facade")

func _basketball_ring() -> void:
	var w := ObjWriter.new("BasketballRing")
	w.set_material("board", UiTheme.ENV_WOOD)
	w.set_material("edge", UiTheme.PANEL)
	w.set_material("post", UiTheme.ENV_CONCRETE)
	w.set_material("ring", UiTheme.PANEL)

	w.add_extrude(_ngon(0.0, 0.62, 0.12, 8), 0.00, 3.05, "post")
	_box(w, 0.0, 0.52, 1.20, 0.06, 2.95, 3.85, "board")
	_box(w, 0.0, 0.49, 0.62, 0.02, 3.02, 3.48, "edge")
	w.add_revolve(PackedVector2Array([
		Vector2(0.21, 3.05), Vector2(0.25, 3.07),
		Vector2(0.21, 3.09), Vector2(0.17, 3.07),
		Vector2(0.21, 3.05),
	]), 12, "ring")
	_finish(w, "env_basketball_ring")


func _monument() -> void:
	var w := ObjWriter.new("Monument")
	w.set_material("stone", UiTheme.ENV_CONCRETE)
	w.set_material("step", UiTheme.ENV_CONCRETE_DARK)
	w.set_material("plaque", UiTheme.ENV_PAINT_PLINTH)

	_box(w, 0, 0, 2.60, 2.60, 0.00, 0.22, "step")
	_box(w, 0, 0, 2.16, 2.16, 0.22, 0.44, "stone")
	_box(w, 0, 0, 1.76, 1.76, 0.44, 0.64, "step")

	_box(w, 0, 0, 1.36, 1.36, 0.64, 2.00, "stone")
	for sx in SIDES:
		_box(w, sx * 0.69, 0.00, 0.02, 0.86, 0.96, 1.68, "plaque")
		_box(w, 0.00, sx * 0.69, 0.86, 0.02, 0.96, 1.68, "plaque")

	_box(w, 0, 0, 1.66, 1.66, 2.00, 2.20, "step")
	_box(w, 0, 0, 1.30, 1.30, 2.20, 2.38, "stone")
	for sx in SIDES:
		for sz in SIDES:
			var urn := Transform3D(Basis(), Vector3(sx * 0.52, 2.38, sz * 0.52))
			w.add_revolve(PackedVector2Array([
				Vector2(0.00, 0.00), Vector2(0.13, 0.00),
				Vector2(0.16, 0.14), Vector2(0.10, 0.30),
				Vector2(0.14, 0.38), Vector2(0.00, 0.42),
			]), 8, "step", true, Callable(), urn)

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

func _railing() -> void:
	var w := ObjWriter.new("Railing")
	w.set_material("rail", UiTheme.PANEL)
	w.set_material("foot", UiTheme.ENV_CONCRETE_DARK)

	for sx in SIDES:
		_box(w, sx * 1.0, 0.0, 0.16, 0.16, 0.00, 0.14, "foot")
		_box(w, sx * 1.0, 0.0, 0.13, 0.13, 0.14, 0.90, "rail")
		_box(w, sx * 1.0, 0.0, 0.19, 0.19, 0.90, 0.98, "rail")
	_box(w, 0, 0, 2.00, 0.06, 0.16, 0.22, "rail")
	_box(w, 0, 0, 2.00, 0.05, 0.46, 0.51, "rail")
	_box(w, 0, 0, 2.00, 0.09, 0.78, 0.86, "rail")
	for i in range(9):
		_box(w, -0.80 + 0.20 * float(i), 0.0, 0.045, 0.045, 0.22, 0.78, "rail")
	_finish(w, "env_railing")

func _planter_hedge() -> void:
	var w := ObjWriter.new("PlanterHedge")
	w.set_material("concrete", UiTheme.ENV_CONCRETE)
	w.set_material("coping", UiTheme.ENV_CONCRETE_DARK)
	w.set_material("leaf", UiTheme.ENV_FOLIAGE)
	w.set_material("leaf_dark", UiTheme.ENV_FOLIAGE_DARK)

	_box(w, 0, 0, 1.10, 1.10, 0.00, 0.38, "concrete")
	_box(w, 0, 0, 1.20, 1.20, 0.38, 0.46, "coping")
	_box(w, 0, 0, 1.04, 1.04, 0.46, 0.82, "leaf")
	_box(w, 0, 0, 0.88, 0.88, 0.82, 0.96, "leaf_dark")
	_finish(w, "env_planter_hedge")

func _bell_tower() -> void:
	var w := ObjWriter.new("BellTower")
	w.set_material("stone", UiTheme.ENV_CONCRETE)
	w.set_material("band", UiTheme.ENV_CONCRETE_DARK)
	w.set_material("roof", UiTheme.ENV_PAINT_TERRA)
	w.set_material("window", UiTheme.INK)

	_box(w, 0, 0, 2.50, 2.50, 0.00, 3.40, "stone")
	_box(w, 0, 0, 2.62, 2.62, 3.40, 3.62, "band")
	_box(w, 0, 0, 2.30, 2.30, 3.62, 6.60, "stone")
	_box(w, 0, 0, 2.42, 2.42, 6.60, 6.82, "band")
	_box(w, 0, 0, 2.10, 2.10, 6.82, 9.40, "stone")
	_box(w, 0, 0, 2.22, 2.22, 9.40, 9.62, "band")
	_box(w, 0, 0, 1.94, 1.94, 9.62, 11.60, "stone")
	for sx in SIDES:
		_window(w, Vector3(sx * 0.98, 10.60, 0.0),
			Vector3(0, 0, 0.46), Vector3(0, 0.74, 0))
		_window(w, Vector3(0.0, 10.60, sx * 0.98),
			Vector3(0.46, 0, 0), Vector3(0, 0.74, 0))
	for i in range(3):
		var y := 2.10 + 2.90 * float(i)
		for sx in SIDES:
			_window(w, Vector3(sx * 1.27, y, 0.0),
				Vector3(0, 0, 0.16), Vector3(0, 0.52, 0))
			_window(w, Vector3(0.0, y, sx * 1.27),
				Vector3(0.16, 0, 0), Vector3(0, 0.52, 0))
	_box(w, 0, 0, 2.16, 2.16, 11.60, 11.84, "band")
	w.add_revolve(PackedVector2Array([
		Vector2(1.16, 11.84), Vector2(0.00, 13.60),
	]), 4, "roof", false)
	_box(w, 0, 0, 0.10, 0.10, 13.60, 14.30, "band")
	_box(w, 0, 0, 0.44, 0.09, 13.86, 13.96, "band")
	_finish(w, "env_bell_tower")

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
	_box(w, 0, 0, HALL_W + 0.24, HALL_D + 0.24, 0.00, 3.00, "plinth")
	_box(w, 0, 0, HALL_W + 0.32, HALL_D + 0.32, 3.00, 3.24, "band")
	var front_z := -(HALL_D + 0.24) * 0.5 - 0.02
	for bay in range(7):
		var cx := -4.80 + 1.60 * float(bay)
		_box(w, cx, front_z, 1.06, 0.06, 0.00, 1.90, "window")
		for i in range(5):
			var t := float(i) / 5.0
			var half := 0.53 * sqrt(maxf(1.0 - t * t, 0.0))
			_box(w, cx, front_z, half * 2.0, 0.06,
				1.90 + 0.13 * float(i), 2.03 + 0.13 * float(i), "window")
	for bay in range(7):
		var cx := -4.80 + 1.60 * float(bay)
		for sz in SIDES:
			_window(w, Vector3(cx, 4.70, sz * (HALL_D * 0.5 + 0.01)),
				Vector3(0.34, 0, 0), Vector3(0, 0.62, 0))
	for sz in SIDES:
		for sx in SIDES:
			_window(w, Vector3(sx * (HALL_W * 0.5 + 0.01), 4.70, sz * 1.30),
				Vector3(0, 0, 0.34), Vector3(0, 0.62, 0))
	_box(w, 0, 0, HALL_W + 0.40, HALL_D + 0.40, 6.60, 6.90, "band")
	_box(w, 0, 0, HALL_W + 0.30, HALL_D + 0.30, 6.90, 7.70, "roof")
	_box(w, 0, 0, HALL_W - 1.60, HALL_D - 1.60, 7.70, 8.36, "roof")
	_box(w, 0, 0, HALL_W - 4.20, HALL_D - 3.00, 8.36, 8.60, "roof")
	_finish(w, "env_municipal_hall")



const CHALK_PINK: Color = Color(0.902, 0.678, 0.706)
const CHALK_BLUE: Color = Color(0.678, 0.780, 0.851)
const CHALK_LEMON: Color = Color(0.910, 0.878, 0.671)
const CHALK_MINT: Color = Color(0.714, 0.843, 0.745)


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


func _chalk_ring(w: ObjWriter, cx: float, cz: float, r: float, width: float,
		material: String) -> void:
	var pts := PackedVector2Array()
	for i in range(15):
		var ang := TAU * float(i) / 14.0
		var rr := r * (1.0 + 0.09 * sin(ang * 3.0 + 0.7))
		pts.append(Vector2(cx + rr * cos(ang), cz + rr * sin(ang)))
	_chalk_stroke(w, pts, width, material, cx * 3.1 + cz)


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
	w.add_revolve(PackedVector2Array([
		Vector2(0.55, 0.00), Vector2(0.70, 0.00),
		Vector2(0.70, 0.03), Vector2(0.55, 0.03),
		Vector2(0.55, 0.00),
	]), 28, "mark")
	_finish(w, "env_base_circle_decal")

const CHALK_WIDTH: float = 0.09
const CHALK_TINT: Color = Color(0.902, 0.878, 0.816)

func _chalk_wander(t: float) -> float:
	return 0.011 * sin(t * 13.7) + 0.006 * sin(t * 31.3 + 1.1) 		+ 0.003 * sin(t * 67.1 + 0.5)


func _chalk_halfwidth(t: float, side: float) -> float:
	var press := 0.95 + 0.28 * sin(t * 17.9 + 0.4) + 0.12 * sin(t * 43.3 + side * 2.1)
	return CHALK_WIDTH * 0.5 * clampf(press, 0.55, 1.35)


func _chalk_line(file_name: String, length: float) -> void:
	var w := ObjWriter.new("ChalkLine")
	w.set_material("mark", CHALK_TINT)

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
	w.add_extrude(outline, 0.0, 0.02, "mark")
	_finish(w, file_name, 0.0)


func _throwing_line_decal() -> void:
	_chalk_line("env_throwing_line_decal", 8.0)


func _team_side_decal() -> void:
	_chalk_line("env_team_side_decal", 6.0)



