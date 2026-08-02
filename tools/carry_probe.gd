extends Node3D
## IS THE SLIPPER IN THE HAND — ON EVERY BODY, NOT JUST YOUR OWN? **Written 2026-08-02.**
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/carry_probe.tscn -- <out_dir>
##
## ⚠️ RUN WITHOUT `--headless`. It captures a frame, and headless has no rendering device.
##
## 🧑 2026-08-02, having reported it three times across two months: *"yo make sure that
## the slippers clip to the arm for everyone else okay, its such a reoccuring problem,
## make sure u actually fix it"*.
##
## ⚠️⚠️ "FOR EVERYONE ELSE" IS THE WHOLE POINT AND IT IS WHY THE BUG SURVIVED SO LONG.
## The person holding the slipper does not see this object at all: `camera_rig.gd` gives
## first person its own `HeldSlipper` viewmodel on a separate anchor, so the carrier's
## screen was composed correctly while the REAL prop sat in the carrier's chest on all
## three other screens. Every fix was checked by the one player who could not see the
## fault. So this probe looks at somebody else's body, from outside, in spectator mode.
##
## ⚠️ IT ASSERTS IN CHARACTER-LOCAL SPACE, NOT IN WORLD SPACE, because that is the frame
## the claim is actually about: "in the hand" means a fixed place on the BODY, and a
## world-space number would pass or fail depending on where the carrier happened to be
## standing. A CharacterBase's origin is the centre of its 1.6-unit capsule, so the feet
## are at local y = -0.8 and the crown at +0.8.
##
## ⚠️ AND IT CHECKS BOTH ENDS. Too high is the reported "floating in the chest / inside
## the head"; too low is a slipper dragging at the knee. The band below is the arm's own
## geometry: `hand_bone_probe` measures the shoulder at 0.288 and the fingertip 0.290 out
## along the arm on a 0.672-unit model, which at `PERSON_SCALE` 2.38 puts the palm around
## y = -0.05 .. -0.35 in character-local space and roughly 0.25 m out to the side.

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

## Character-local band the palm must land in. Generous — this is a "not in the chest,
## not at the ankle" assertion, not a calibration.
const PALM_Y_MIN: float = -0.45
const PALM_Y_MAX: float = 0.10
## ⚠️⚠️ THERE IS DELIBERATELY NO "OUT TO THE SIDE" THRESHOLD, AND THE FIRST VERSION OF
## THIS PROBE HAD ONE AND WAS WRONG. It required the slipper to sit ≥ 0.12 out from the
## body's centre line, on the reasoning that a slipper on the centre line is the reported
## bug. Two of three seats passed it and the taya failed at 0.013 — while the RENDER of
## that same seat shows the shoe correctly in her raised hand.
##
## The threshold was measuring the ANIMATION CLIP, not the attachment. The carry point
## hangs off a `BoneAttachment3D`, so it goes wherever the arm bone goes, and an arm
## raised or crossed in front of the chest legitimately puts the hand near the centre
## line for as long as that clip is playing. A probe that fails on that would demand the
## attachment be wrong in order to pass.
##
## What can be asserted without knowing the pose is what is checked below: the slipper is
## PARENTED to a hand attachment (so it is riding the bone rather than the body's
## last-resort fallback), and it is somewhere on the torso's vertical band rather than at
## the ankles or above the head. The side offset is still PRINTED, because it is the
## number a human reading the render wants next to it.
const PALM_SIDE_MIN: float = 0.0

var _out := "res://"
var _main: Node = null
var _failures: Array[String] = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	GameLaunch.spectator = true
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	if _main.has_method("_run_ready_countdown"):
		_main._run_ready_countdown()
	await get_tree().create_timer(5.5).timeout

	print("\n========== CARRY PROBE — is the slipper in the hand? ==========")
	var carriers: Array = []
	for node in get_tree().current_scene.find_children("*", "Slipper", true, false):
		var slipper := node as Slipper
		if slipper.state != Slipper.CarryState.CARRIED:
			continue
		var who := slipper.carrier
		if who == null or not is_instance_valid(who):
			continue
		carriers.append(who)
		_check(slipper, who)
	if carriers.is_empty():
		_failures.append("HARNESS: nobody was carrying a slipper — nothing was measured.")
	else:
		for i in carriers.size():
			_frame(carriers[i])
			await get_tree().process_frame
			await get_tree().process_frame
			await _capture("carry_%d" % [(carriers[i] as CharacterBase).player_slot])
	_report()
	get_tree().quit()

func _check(slipper: Slipper, who: CharacterBase) -> void:
	var hand := who.get_hand_attachment()
	var label := "%s seat %d" % [who.display_name(), who.player_slot]
	if hand == null:
		_failures.append("%s: no hand attachment at all — the slipper is riding the body."
			% label)
		print("%-28s NO HAND ATTACHMENT" % label)
		return
	# ⚠️ THE PARENT CHECK IS NOT OPTIONAL. `_step_carried()`'s last-resort branch parks
	# the slipper at chest height off the BODY, and it looks almost right from some
	# angles — so a probe that only measured position could pass on the fallback path.
	var parented := slipper.get_parent() == hand
	if not parented:
		_failures.append("%s: slipper is not parented to the hand (it is on '%s')."
			% [label, slipper.get_parent().name if slipper.get_parent() != null else "<none>"])

	var local: Vector3 = who.global_transform.affine_inverse() * slipper.global_position
	var side := absf(local.x)
	var ok := local.y >= PALM_Y_MIN and local.y <= PALM_Y_MAX and side >= PALM_SIDE_MIN
	print("%-28s slipper at character-local (%+.3f, %+.3f, %+.3f)  side %.3f  %s"
		% [label, local.x, local.y, local.z, side, "OK" if ok and parented else "FAIL"])
	if not ok:
		_failures.append(("%s: palm at local y %+.3f, side %.3f — outside the band "
			+ "(y %.2f..%.2f, side >= %.2f). y above the band is the chest/head; "
			+ "side below it is the body's centre line.")
			% [label, local.y, side, PALM_Y_MIN, PALM_Y_MAX, PALM_SIDE_MIN])

## Points a camera at the carrier from the side, close, so the capture shows the ARM
## rather than a figure in a street. This is the frame a human should look at before
## believing any of the numbers above — 🧑's standing rule after a "fix" was proved with
## a render that still had the bug in it.
func _frame(who: CharacterBase) -> void:
	# ⚠️⚠️ THE SPECTATOR CAMERA HAS TO BE SWITCHED OFF, NOT OUT-VOTED, AND IT TOOK TWO
	# FAILED CAPTURES TO GET THAT RIGHT. Run 1 added a camera and set `current = true`:
	# the capture came back as the spectator's free flight. Run 2 also cleared `current`
	# on every `Camera3D` under `current_scene` first: same result, because the spectator
	# rig is NOT under `current_scene` and was never in that list. It writes its own
	# transform every frame, so the only thing that cannot race it is stopping it from
	# processing at all. Searched from the ROOT for the same reason.
	for node in get_tree().root.find_children("*", "Camera3D", true, false):
		(node as Camera3D).current = false
	for node in get_tree().root.find_children("*", "SpectatorCamera", true, false):
		(node as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	var basis := who.global_transform.basis
	# ⚠️ FAR ENOUGH BACK TO SEE THE ARM. The first framing was 2.2 m at 40° fov, which put
	# the carrier's shoulders past both edges of the frame — the slipper was visible and
	# the limb it is supposed to be attached to was not, which is the one thing the shot
	# is for.
	camera.global_position = who.global_position + basis.x * 3.4 + Vector3.UP * 0.5 \
		- basis.z * 1.1
	camera.look_at(who.global_position, Vector3.UP)
	camera.fov = 55.0

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	image.save_png(path)
	print("saved %s" % path)

func _report() -> void:
	print("---------------------------------------------------------------")
	if _failures.is_empty():
		print("RESULT: PASS — every carried slipper is parented to a hand and sits in it.")
	else:
		print("RESULT: FAIL")
		for line in _failures:
			print("  · %s" % line)
	print("===============================================================\n")
