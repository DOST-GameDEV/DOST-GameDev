extends Node3D
## AIM AUDIT — "does the slipper go where the crosshair is pointing?"
##
## Reported twice as a feel problem ("barely has power even during full windup",
## then "the height when you throw it is still too low") and fixed twice before
## this probe existed, which is why it exists now.
##
## ⚠️ THE METRIC IS CLOSEST APPROACH TO THE AIM POINT, NOT WHERE IT LANDS.
## `MAX_BOUNCES` lets a slipper skip once after first contact, so the resting
## place can be a metre or two past the target on a perfectly aimed throw. What
## actually answers the question is whether the TRAJECTORY passes through the
## point the crosshair was on — and it has to pass within about the slipper's own
## `hit_radius` (0.30–0.55) for the throw to hit what the player pointed at.
##
##   godot --path . tools/aim_probe.tscn
##
## Never `--headless` — same rule as smoke-gate 3 and 4.

## Camera pitches to test, in degrees. Spans a near ground target, a mid one and
## a distant wall, because the pre-fix error was a FUNCTION OF RANGE: aiming
## merely parallel to the look direction agreed with the crosshair at exactly one
## distance and was wrong either side of it.
const PITCHES: Array[float] = [0.0, -10.0, -20.0, -30.0, 10.0]
## Pass mark, in metres. The tightest shipped `hit_radius` is 0.30 (flick), so a
## trajectory inside this genuinely hits what was pointed at.
const PASS_WITHIN: float = 0.40
## Pass mark for how far the flight may hang below the eye->crosshair line
## WITHIN THE FIRST `SAG_WINDOW` METRES.
##
## ⚠️ MEASURED NEAR THE PLAYER, NOT OVER THE WHOLE FLIGHT, AND THAT IS THE ONLY
## VERSION OF THIS METRIC THAT MEANS ANYTHING. Over a long throw the path MUST
## fall below the straight eye->target chord — that is what a ballistic arc is,
## and the first cut of this check duly failed a perfectly good 23 m lob by 4.4 m
## while the 6 m throws it was written for read 0.000. What the report was about
## ("the height of the trajectory is too low") is the slipper leaving the hand
## BELOW the sight line and dropping out of the bottom of the screen immediately,
## which is a near-field defect: leaving from the hand peaked at 0.38-0.43 m of
## sag within 0.22 m of the player.
const SAG_WITHIN: float = 0.15
## How far out to look for that near-field sag. Comfortably past the throwing
## line's own stand-off, and well short of where honest arc begins to dominate.
const SAG_WINDOW: float = 3.0

var _main: Node
var _attacker: CharacterBase
var _slipper: CharacterBase
var _results: Array[Dictionary] = []

func _ready() -> void:
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	MatchManager.begin_next_round()
	await get_tree().create_timer(0.5).timeout
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.is_person and not ch.team_is_can_side:
			_attacker = ch
		elif not ch.is_person and not ch.is_can:
			_slipper = ch
	if _attacker == null or _slipper == null:
		print("AIM: could not find attacker/slipper")
		get_tree().quit(1)
		return
	# The bot would otherwise fight the probe for the same slipper.
	if _attacker.ai_controller != null:
		_attacker.ai_controller.set_enabled(false)
	if _slipper.ai_controller != null:
		_slipper.ai_controller.set_enabled(false)
	var rig := _attacker.get_node("CameraRig") as CameraRig
	rig.set_active(true)
	var camera := rig.fpp_camera as Camera3D
	var carriable := _slipper.get_node("Carriable") as Carriable

	print("attacker %s   eye height %.2f above body origin"
		% [_attacker.global_position, camera.global_position.y - _attacker.global_position.y])

	for pitch in PITCHES:
		carriable.host_land()
		_slipper.global_position = _attacker.global_position + Vector3(0.4, 0.3, 0)
		await get_tree().physics_frame
		carriable.host_grab(_attacker)
		await get_tree().physics_frame
		await get_tree().physics_frame
		rig.set("_pitch_deg", pitch)
		await get_tree().physics_frame

		var aim := -rig.get_aim_basis().z
		var space := _attacker.get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			camera.global_position, camera.global_position + aim * 40.0)
		query.exclude = [_attacker.get_rid(), _slipper.get_rid()]
		var hit := space.intersect_ray(query)
		var aim_point: Vector3 = hit.get("position", camera.global_position + aim * 40.0)

		# The production launch origin: the sight line, not the slipper's own
		# position — see carrier.gd::_throw_origin(). This probe exists to measure
		# aim accuracy, so it has to throw from where a real throw leaves from.
		var origin := camera.global_position + aim * Carrier.MUZZLE_FORWARD
		carriable.host_throw(origin, aim_point, 1.0)
		var eye := camera.global_position
		var sight_len := Vector2(aim_point.x - eye.x, aim_point.z - eye.z).length()
		var closest := 9999.0
		var max_sag := 0.0
		for _i in 400:
			await get_tree().physics_frame
			closest = minf(closest, _slipper.global_position.distance_to(aim_point))
			max_sag = maxf(max_sag, _sag_below_sight(_slipper.global_position, eye, aim_point, sight_len))
			if carriable.state != Carriable.CarryState.FLYING:
				break
		_results.append({
			"pitch": pitch,
			"range": Vector2(aim_point.x - origin.x, aim_point.z - origin.z).length(),
			"closest": closest,
			"sag": max_sag,
		})
	_report()
	get_tree().quit(0)

## How far below the eye->crosshair line the slipper is RIGHT NOW, in metres.
## Zero once it is past the aim point — the sight line is a segment, not a ray,
## and a slipper that has flown beyond the target is no longer "sagging".
##
## ⚠️ THIS, NOT THE LANDING POINT, IS WHAT "THE HEIGHT OF THE TRAJECTORY IS TOO
## LOW" WAS ABOUT. The landing was already accurate to a few centimetres when
## that was reported the third time; what the player actually sees is the flight
## in between, and it used to hang up to 0.43 m under the line they were sighting
## along — worst within a fifth of a metre of their own face, i.e. the slipper
## dropping out of the bottom of the screen the instant it left the hand.
static func _sag_below_sight(p: Vector3, eye: Vector3, aim_point: Vector3, sight_len: float) -> float:
	if sight_len < 0.01:
		return 0.0
	var travelled := Vector2(p.x - eye.x, p.z - eye.z).length()
	if travelled <= 0.0 or travelled > sight_len or travelled > SAG_WINDOW:
		return 0.0
	var sight_y: float = lerpf(eye.y, aim_point.y, travelled / sight_len)
	return maxf(0.0, sight_y - p.y)

func _report() -> void:
	print("\n=== AIM AUDIT (does the throw go where the crosshair points?) ===")
	print("  pitch    aim point range    closest approach   near-field sag   verdict")
	var worst := 0.0
	var worst_sag := 0.0
	for r in _results:
		worst = maxf(worst, r["closest"])
		worst_sag = maxf(worst_sag, r["sag"])
		print("  %+6.1f   %8.2f m        %8.2f m           %6.3f m       %s"
			% [r["pitch"], r["range"], r["closest"], r["sag"],
				"ok" if r["closest"] <= PASS_WITHIN else "MISSES"])
	print("  VERDICT: %s  (worst %.2f m, pass mark %.2f)"
		% ["PASS — every throw passed through the point the crosshair was on"
			if worst <= PASS_WITHIN
			else "*** FAIL — throws do not go where the crosshair points ***", worst, PASS_WITHIN])
	print("  SAG:     %s  (worst %.3f m in the first %.0f m, pass mark %.2f)"
		% ["PASS — the flight leaves along the sight line"
			if worst_sag <= SAG_WITHIN
			else "*** FAIL — the flight hangs below where the player is aiming ***",
			worst_sag, SAG_WINDOW, SAG_WITHIN])
	if worst > PASS_WITHIN or worst_sag > SAG_WITHIN:
		get_tree().quit(1)
