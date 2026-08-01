extends SceneTree

## Proves no lata skin clips through the floor, upright OR knocked down.
##
##     godot --headless -s tools/models/lata_floor_probe.gd
##
## ⚠️ THIS IS A GATE, NOT A LOOK. It exits non-zero if any skin sinks, so it can
## be re-run after any change to a can profile, to `DOWNED_TILT_DEG`, or to
## `lata.gd`'s topple. 🧑 2026-08-01: *"make sure cans dont clip at all to the
## floor. ever."* — "ever" is four skins times two states, which is eight numbers,
## which is a probe rather than eight screenshots.
##
## WHAT IT MEASURES. The mesh's own AABB, pushed through exactly the transform
## `Lata._apply_upright_visual()` builds for that state, and then asked for its
## lowest corner in the lata's local space. The floor is y = 0 there, so any
## result below zero is the can underground by that much.
##
## ⚠️ AN AABB IS A CONSERVATIVE ANSWER AND THAT IS THE RIGHT KIND OF WRONG HERE.
## Rotating a bounding box and re-bounding it over-estimates the extent slightly,
## so a can that PASSES this test cannot clip; one that fails by a hair might not
## actually. Erring toward "lifted a millimetre too far" is invisible; erring the
## other way is the bug being chased.

const TILT_DEG: float = 88.0          # Lata.DOWNED_TILT_DEG
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
		# The same lift lata.gd measures: half the widest horizontal span.
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

## Lowest corner of `box` after `xf`, which is what the floor actually sees.
func _lowest(box: AABB, xf: Transform3D) -> float:
	var lowest := INF
	for i in range(8):
		lowest = minf(lowest, (xf * box.get_endpoint(i)).y)
	return lowest
