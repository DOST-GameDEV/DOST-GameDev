extends SceneTree


const TILT_DEG: float = 88.0
const SKINS: Array = [
	"res://assets/models/lata_pasip.obj",
	"res://assets/models/lata_boyben.obj",
	"res://assets/models/lata_decades.obj",
	"res://assets/models/lata_metal.obj",
]

func _initialize() -> void:
	var failures := 0
	print("lata floor probe — lowest point in lata-local space, floor is 0.000")
	for path in SKINS:
		var mesh := load(path) as Mesh
		if mesh == null:
			print("  MISSING %s" % path)
			failures += 1
			continue
		var box := mesh.get_aabb()
		var lift: float = maxf(box.size.x, box.size.z) * 0.5

		var upright := _lowest(box, Transform3D.IDENTITY)
		var down_xf := Transform3D(
			Basis(Vector3.RIGHT, deg_to_rad(TILT_DEG)), Vector3(0.0, lift, 0.0))
		var downed := _lowest(box, down_xf)

		var ok := upright >= -0.001 and downed >= -0.001
		if not ok:
			failures += 1
		print("  %-22s upright %+.4f   downed %+.4f   lift %.4f   %s" % [
			path.get_file(), upright, downed, lift, "OK" if ok else "*** SINKS ***"])

	if failures > 0:
		print("FAIL: %d skin(s) clip the floor" % failures)
		quit(1)
		return
	print("PASS: no skin clips the floor in either state")
	quit(0)

func _lowest(box: AABB, xf: Transform3D) -> float:
	var lowest := INF
	for i in range(8):
		lowest = minf(lowest, (xf * box.get_endpoint(i)).y)
	return lowest

