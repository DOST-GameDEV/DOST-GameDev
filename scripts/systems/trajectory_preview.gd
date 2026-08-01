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
## Dashes, not dots, and not a solid line either. A solid line reads as a laser sight and
## implies a certainty a thrown slipper does not have; a dotted one reads as an estimate,
## which is what it is.
##
## ⚠️ WAS 1-ON / 1-OFF AND THAT WAS HALF OF WHY IT COULD NOT BE SEEN. 🧑 2026-08-01, with
## a first-person screenshot: *"the trajectory of my throw is kinda ugly and can barely be
## seen"*, *"make it more solid or something"*. Three things were subtracting from the
## same signal at once — 1 px lines (see `WIDTH_PER_METRE`), an alpha ramp that ended at
## 0.25 (see `FADE_FLOOR`), and this, which threw away half the segments.
##
## ⚠️ NOW SOLID, ON A SECOND LOOK FROM THE HUMAN: *"the arc looks great but its not
## full"*. The "a dotted line reads as an estimate" argument above is a real one and it
## LOST to legibility — the gaps read as a broken line rather than as uncertainty, and the
## honesty it was buying is already carried by the length fade (`FADE_FLOOR`), which says
## the same thing without punching holes in the shape. Set `DASH_OFF` above 0 to bring the
## dashes back; the loop still supports it.
const DASH_ON: int = 1
const DASH_OFF: int = 0
## Half-width of the arc ribbon, in metres.
##
## ⚠️⚠️ THE ARC IS A RIBBON OF TRIANGLES, NOT `PRIMITIVE_LINES`, AND IT HAS TO BE.
## Godot 4 rasterises every line primitive at **exactly one pixel** — `line_width` was a
## GLES2 feature and is gone; there is no material property that widens it. So the old
## arc was 1 px wide at any distance, on a grey road, at 25% alpha by its far end, in a
## game played at 1080p+. It was not a styling problem and no colour would have fixed it.
##
## Each segment is drawn as a quad turned to face the camera, so the width is real
## geometry rather than a line-rasteriser setting.
##
## ⚠️⚠️ AND IT IS SCALED BY DISTANCE, WHICH A FIXED WORLD WIDTH GOT BADLY WRONG.
## First version used a constant 0.045 m half-width. Side-on it looked right; from the
## THROWER'S OWN EYE — the view the bug was reported from — the arc leaves the hand about
## half a metre from the near plane, and 9 cm at half a metre is a yellow band across a
## third of the screen. Rendered and looked at, which is the only reason it was caught.
##
## So the half-width is `WIDTH_PER_METRE * distance-to-eye`, clamped: that holds a roughly
## constant ~10 px on screen from the hand to the landing point, at any FOV. The clamp
## floor stops the near end vanishing to nothing, the ceiling stops a very long lob
## turning into a wall at its far end.
const WIDTH_PER_METRE: float = 0.0045
const WIDTH_MIN: float = 0.008
const WIDTH_MAX: float = 0.10
## Where the length-fade bottoms out. The far end is a guess and should say so — but it
## still has to be visible, and 0.25 was under the road's own contrast.
const FADE_FLOOR: float = 0.45
## Overall opacity ceiling. 🧑 2026-08-01: *"also make it a bit transparent so that it
## doesnt block the pov"*. A solid ribbon at full alpha is legible and it is also a
## painted stripe across the middle of a first-person view, which is the one view this
## has to be usable in.
const ALPHA_MAX: float = 0.62
## ⚠️ AND A SEPARATE NEAR-CAMERA FADE, WHICH IS THE HALF THAT ACTUALLY UNBLOCKS THE VIEW.
## Lowering `ALPHA_MAX` alone dims the whole arc, including the far end that is hardest to
## see — the wrong trade. The part that blocks a first-person player is the first metre or
## so, where the arc leaves their own hand almost against the near plane. That span ramps
## from invisible to full across NEAR_FADE_START..NEAR_FADE_END, so the arc appears to
## start a stride in front of the player instead of at their face, and nothing is taken
## away from the part they are aiming with.
const NEAR_FADE_START: float = 0.45
const NEAR_FADE_END: float = 2.20
## Side of the landing marker, in metres. The one point on this arc a player actually
## aims with is where it stops, and a line that thins to nothing gives that away last.
## Drawn flat on the ground, so it reads as a place rather than as more line.
const LANDING_MARK: float = 0.30
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
## `rest_height` is the HELD skin's own resting origin height — see §1.19/B1 and
## `Slipper.rest_height()`. Defaults to FLOOR_EPSILON so an caller that does not
## know its skin behaves exactly as before.
func draw_arc(origin: Vector3, velocity: Vector3, gravity: float, tint: Color,
		rest_height: float = FLOOR_EPSILON) -> void:
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
		var grounded := position.y <= maxf(FLOOR_EPSILON, rest_height)
		# Always keep the LAST point even when it is not on the stride, or the arc stops
		# up to `stride` ticks early and the landing spot — the one part of this line the
		# player is actually reading — is the part that goes missing.
		if grounded or i % stride == 0 or i == total_steps - 1:
			points.append(position)
		if grounded:
			break
	# ⚠️ THE CAMERA IS WHAT GIVES THE RIBBON ITS WIDTH. Each quad is turned so its
	# flat face points at the viewer; without a camera there is no "sideways" that is
	# guaranteed not to be edge-on, and a ribbon seen exactly edge-on is a 1 px line
	# again — the bug this replaced. `Vector3.UP` is the fallback, which is correct
	# for every case except looking straight down the arc.
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else global_position + Vector3.UP * 100.0

	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	var drawn := 0
	var cycle := DASH_ON + DASH_OFF
	for i in range(points.size() - 1):
		if i % cycle >= DASH_ON:
			continue
		var fade: float = 1.0 - (float(i) / float(maxi(1, points.size() - 1))) * (1.0 - FADE_FLOOR)
		# Distance ramp, so the span nearest the player's face is not a painted
		# stripe across their view — see NEAR_FADE_START.
		var dist := ((points[i] + points[i + 1]) * 0.5).distance_to(eye)
		var near: float = clampf((dist - NEAR_FADE_START)
			/ maxf(0.001, NEAR_FADE_END - NEAR_FADE_START), 0.0, 1.0)
		var colour := Color(tint.r, tint.g, tint.b, fade * near * ALPHA_MAX)
		if _add_quad(points[i], points[i + 1], eye, colour):
			drawn += 1
	# The landing mark, flat on the ground at the last sampled point, full alpha —
	# it is the one part of this arc the player is aiming WITH rather than reading.
	if points.size() >= 2:
		var land: Vector3 = points[points.size() - 1]
		var half := LANDING_MARK * 0.5
		# Strongest thing on the arc, but still under ALPHA_MAX — it is a marker on
		# the road, not a decal painted over it.
		var mark := Color(tint.r, tint.g, tint.b, ALPHA_MAX)
		var a := land + Vector3(-half, 0.0, -half)
		var b := land + Vector3(half, 0.0, -half)
		var c := land + Vector3(half, 0.0, half)
		var d := land + Vector3(-half, 0.0, half)
		_add_tri(a, b, c, mark)
		_add_tri(a, c, d, mark)
		drawn += 1
	_mesh.surface_end()
	# A surface with no vertices is a valid mesh that renders nothing, but Godot will
	# still submit it; hiding is cheaper and is also the honest state.
	if drawn == 0:
		visible = false


## One segment of the ribbon: a quad from `a` to `b`, turned face-on to `eye`.
## Returns false for a degenerate segment rather than emitting NaN vertices — two
## identical points give a zero-length direction, and `normalized()` on that is a
## zero vector, which would put four coincident corners into the buffer.
func _add_quad(a: Vector3, b: Vector3, eye: Vector3, colour: Color) -> bool:
	var along := b - a
	if along.length_squared() <= 0.0000001:
		return false
	along = along.normalized()
	var to_eye := (eye - (a + b) * 0.5)
	# Constant on screen rather than constant in the world — see WIDTH_PER_METRE.
	var half := clampf(to_eye.length() * WIDTH_PER_METRE, WIDTH_MIN, WIDTH_MAX)
	var side := along.cross(to_eye)
	if side.length_squared() <= 0.0000001:
		# Looking straight down the arc. Any perpendicular will do and none is
		# better than another, so take a stable one rather than skipping the
		# segment and leaving a hole.
		side = along.cross(Vector3.UP)
		if side.length_squared() <= 0.0000001:
			side = along.cross(Vector3.RIGHT)
	side = side.normalized() * half
	_add_tri(a - side, a + side, b + side, colour)
	_add_tri(a - side, b + side, b - side, colour)
	return true


func _add_tri(a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	_mesh.surface_set_color(colour)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(colour)
	_mesh.surface_add_vertex(b)
	_mesh.surface_set_color(colour)
	_mesh.surface_add_vertex(c)

## Empties the arc. Called on every exit from a charge — released, cancelled, the
## slipper knocked out of the thrower's hands, a round reset — for the same reason
## `carrier.gd::_cancel_charge` broadcasts the end of the wind-up from one place: an arc
## left on screen after the throw has gone is worse than one that never appeared.
func clear() -> void:
	if _mesh != null:
		_mesh.clear_surfaces()
	visible = false
