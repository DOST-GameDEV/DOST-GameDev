extends MeshInstance3D
class_name TrajectoryPreview

## THE AIMING ARC — the dotted line a charging thrower sees.
##
## Human instruction, 2026-07-30: *"add a visual trajectory path for all throws and
## charge-ups."* The moodboard asked for this before anything existed (it was filed as
## B-45 and closed as "an illustrated idea, never a build order"); this is it built.
##
## ⚠️ IT DOES NOT KNOW ANY BALLISTICS. `carrier.gd::_update_trajectory` hands it a launch
## velocity that came out of `Carriable.launch_velocity()` — the same function
## `host_throw` releases through — and this file only integrates it forward. That split
## is deliberate and it is the whole reason the preview can be trusted: there is no
## second copy of the solve to drift from the first.
##
## ⚠️ AN `ImmediateMesh`, NOT A POOL OF `MeshInstance3D` DOTS. Fifty small nodes rebuilt
## every physics frame is fifty transform updates and fifty culling tests per frame per
## thrower; one immediate mesh is one draw call and one buffer upload. It also means the
## arc costs literally nothing when nobody is charging, because `clear()` empties the
## surface rather than hiding fifty nodes.
##
## ⚠️ `top_level`, so the arc is drawn in world space. It is parented to the scene root
## rather than to the thrower, but a future caller that parents it under a character
## would otherwise inherit that character's yaw, its `PERSON_SCALE` of 2.38, and — if it
## ever hung under the carried slipper — `CARRY_TILT_DEG`. Immunity by construction is
## cheaper than remembering.

## Seconds of flight to draw. 2.5 covers every flat throw (~0.3 s) and every lob
## (0.86-1.10 s at the throwing line, `carriable.gd::_solve_lob`) with room for a lob
## aimed at something far away, and stops short of drawing a line into the next map.
const HORIZON: float = 2.5
## How many segments the horizon is cut into. 48 over 2.5 s is a sample every 52 ms,
## which at a flat throw's ~20 m/s is a dot roughly every metre — dense enough to read
## as a curve, sparse enough to read as dots rather than a solid tube.
const SAMPLES: int = 48
## Dots, not a line: every other segment is drawn. A solid line reads as a laser sight
## and implies a certainty a thrown slipper does not have; a dotted one reads as an
## estimate, which is what it is.
const DASH_ON: int = 1
const DASH_OFF: int = 1
## How far above the floor the arc stops. Sampling past the ground draws the parabola
## continuing underneath the map, which looks like the throw going through the floor —
## the exact bug B-132 actually was, and it must not be simulated by the preview.
const FLOOR_EPSILON: float = 0.03

var _material: StandardMaterial3D = null
var _mesh: ImmediateMesh = null

func _ready() -> void:
	top_level = true
	_mesh = ImmediateMesh.new()
	mesh = _mesh
	# ⚠️ UNSHADED, NO DEPTH TEST, AND THAT IS NOT LAZINESS. The arc has to be visible
	# where it matters most — passing behind the taya's body and over the lata — and a
	# depth-tested line disappears exactly there. `render_priority` puts it over the
	# toon pass, which draws its outlines as an inverted hull and would otherwise win.
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.render_priority = 8
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _material
	# `cast_shadow` off — a dotted line casting fifty little shadows across the road is
	# both wrong and, on the 640-instance map, not free.
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false

## Draws one arc. `gravity` is the profile's own effective gravity, not
## `CharacterBase.GRAVITY` — see `Carriable.flight_gravity()`.
##
## Fades along its length: the near end is the part the player can act on, the far end
## is a guess, and the alpha ramp says so without a legend.
func draw_arc(origin: Vector3, velocity: Vector3, gravity: float, tint: Color) -> void:
	if _mesh == null:
		return
	_mesh.clear_surfaces()
	visible = true
	# ⚠️⚠️ INTEGRATE AT THE PHYSICS TIMESTEP, THEN SUB-SAMPLE FOR DRAWING. This used to
	# step `HORIZON / SAMPLES` — 2.5 / 48 = 52 ms — while `carriable.gd::_step_flying`
	# steps the real slipper at the physics tick, 16.7 ms. Both use semi-implicit Euler
	# (`v -= g*h` then `x += v*h`), whose error against the true parabola is O(h): after
	# time t it over-drops by exactly `g*t*h/2`.
	#
	# So the two arcs were never the same curve. Two different numbers fall out of that
	# and it is worth keeping them apart, because the big one is not the one a player
	# sees. At the default profile's effective gravity (20.0 x 1.25 = 25) the preview
	# over-drops by `g*t*(0.0521 - 0.0167)/2` ≈ 0.44 m at t = 1.0 s — but the arc is
	# steep by the time it lands, so the error in the LANDING POINT, which is the part
	# the player is actually aiming with, is smaller.
	#
	# *Measured* by integrating both schemes against the real one at `throw_default`
	# (speed 21.0, origin y 1.45): the old preview missed the true landing spot by
	# **+0.086 m at 10°, -0.082 m at 20° and -0.227 m at 30°**, and the error grows with
	# arc height — so a lob was the worst case and a flat poke the best. Stepping at the
	# physics tick makes it **0.000 m at all three**. That is 🧑's *"slippers trajectory
	# broken"* and `build phys` §6.6's acceptance ("the preview arc and the thrown arc
	# land in the same place") closed by matching one number.
	#
	# Matching the STEP is the fix, not matching the sample count: the drawn polyline
	# still gets ~SAMPLES segments via `stride`, so the dash pattern and the vertex
	# budget are unchanged. It costs ~150 float steps per frame while one player aims.
	var step := 1.0 / float(maxi(1, Engine.physics_ticks_per_second))
	var total_steps := maxi(1, int(ceil(HORIZON / step)))
	var stride := maxi(1, int(round(float(total_steps) / float(SAMPLES))))
	var points: Array[Vector3] = []
	var position := origin
	var motion := velocity
	points.append(position)
	for i in range(total_steps):
		motion.y -= gravity * step
		position += motion * step
		# Stop at the floor. `origin.y` is the sight line the throw leaves from, so this
		# is "roughly ground level relative to the thrower" rather than an absolute — a
		# map with a raised lane strip would otherwise clip the arc early.
		var grounded := position.y <= FLOOR_EPSILON
		# Always keep the LAST point even when it is not on the stride, or the arc stops
		# up to `stride` ticks early and the landing spot — the one part of this line the
		# player is actually reading — is the part that goes missing.
		if grounded or i % stride == 0 or i == total_steps - 1:
			points.append(position)
		if grounded:
			break
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _material)
	var drawn := 0
	var cycle := DASH_ON + DASH_OFF
	for i in range(points.size() - 1):
		if i % cycle >= DASH_ON:
			continue
		var fade: float = 1.0 - (float(i) / float(maxi(1, points.size() - 1))) * 0.75
		var colour := Color(tint.r, tint.g, tint.b, fade)
		_mesh.surface_set_color(colour)
		_mesh.surface_add_vertex(points[i])
		_mesh.surface_set_color(colour)
		_mesh.surface_add_vertex(points[i + 1])
		drawn += 1
	_mesh.surface_end()
	# A surface with no vertices is a valid mesh that renders nothing, but Godot will
	# still submit it; hiding is cheaper and is also the honest state.
	if drawn == 0:
		visible = false

## Empties the arc. Called on every exit from a charge — released, cancelled, the
## slipper knocked out of the thrower's hands, a round reset — for the same reason
## `carrier.gd::_cancel_charge` broadcasts the end of the wind-up from one place: an arc
## left on screen after the throw has gone is worse than one that never appeared.
func clear() -> void:
	if _mesh != null:
		_mesh.clear_surfaces()
	visible = false
