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

		var origin := _slipper.global_position
		carriable.host_throw(aim_point, 1.0)
		var closest := 9999.0
		for _i in 400:
			await get_tree().physics_frame
			closest = minf(closest, _slipper.global_position.distance_to(aim_point))
			if carriable.state != Carriable.CarryState.FLYING:
				break
		_results.append({
			"pitch": pitch,
			"range": Vector2(aim_point.x - origin.x, aim_point.z - origin.z).length(),
			"closest": closest,
		})
	_report()
	get_tree().quit(0)

func _report() -> void:
	print("\n=== AIM AUDIT (does the throw go where the crosshair points?) ===")
	print("  pitch    aim point range    closest approach   verdict")
	var worst := 0.0
	for r in _results:
		worst = maxf(worst, r["closest"])
		print("  %+6.1f   %8.2f m        %8.2f m         %s"
			% [r["pitch"], r["range"], r["closest"],
				"ok" if r["closest"] <= PASS_WITHIN else "MISSES"])
	print("  VERDICT: %s  (worst %.2f m, pass mark %.2f)"
		% ["PASS — every throw passed through the point the crosshair was on"
			if worst <= PASS_WITHIN
			else "*** FAIL — throws do not go where the crosshair points ***", worst, PASS_WITHIN])
