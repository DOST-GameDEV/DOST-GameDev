extends Node

## CAN ANYONE ACTUALLY SEE THE WIND-UP? — 🧑, 2026-07-30: **"WINDUP STILL BROKEN"**,
## and before that *"everyone else should see its windup happening"* /
## *"I WANT EVERYONE ELSE IN THE WORLD TO SEE THAT THE WIND UP IS HAPPENING"*.
##
## ⚠️ THE INPUT HALF IS ALREADY FIXED AND IS NOT WHAT THIS MEASURES. `settings.cfg`
## was stripping left click off `special_ability` at startup (see
## `settings_manager.gd::_replace_key_binding`), so no charge started at all;
## `input_probe` now measures peak charge 0.807 on a held left click. The button
## works. This probe asks the next question, which nothing has ever measured: with a
## charge genuinely running, **does anything visibly move** —
##
##   LEG A · the CHARGING PLAYER'S OWN first-person arm (`camera_rig.gd::
##           set_viewmodel_charge`, B-131's direction fix). Observable: the
##           `RightPivot/Arm/HeldSlipper` node — the fist — in CAMERA space.
##   LEG B · the THIRD-PERSON body, which is what every other player looks at.
##           Observable: the right-hand bone's `HandPoint`
##           (`character_visual.gd::get_hand_attachment()`) in CHARACTER-LOCAL
##           space, so walking, turning and the round-swap rebuild cannot show up
##           as a wind-up.
##
## ⚠️ AND THE POINT OF LEG B IS THAT IT IS DRIVEN BY THE OBSERVED CLOCK, NOT THE
## LOCAL ONE. `carrier.gd::charge_power()` is written in `input_step()`, which runs
## only on the peer that controls the unit, so a pose driven from it is invisible to
## everyone else BY CONSTRUCTION — which is precisely the bug. `observed_charge_power()`
## ticks on every peer off one "begin" broadcast. This probe prints BOTH numbers side
## by side on every sample; if the pose moves with one and not the other, that is
## visible here rather than in a playtest.
##
## USAGE
##     godot --path <ABS> tools/charge_tell_probe.tscn                  # local legs
##     godot --path <ABS> tools/charge_tell_probe.tscn -- --host        # two peers
##     godot --path <ABS> tools/charge_tell_probe.tscn -- --join=127.0.0.1
##
## ⚠️ A LOCAL PASS IS NOT EVIDENCE FOR THE NETWORKED CLAIM. Leg B's whole subject is
## a peer that does not own the charging unit, and only `--join` measures one. The
## local run is what proves the mechanism moves the bone at all.

## How long to hold the button. Past `CHARGE_MAX_TIME` so the sample window covers
## the flat top of the curve as well as the ramp — a pose that keeps climbing after
## the charge is clamped would be a bug too.
const HOLD_TIME: float = 1.4

## Samples per hold. 24 over 1.4s is ~17 Hz, well above the rate anything here
## changes at, and few enough to print in full.
const SAMPLES: int = 24

## Metres the FIRST-PERSON fist must travel across the hold to count as visible. 0.62
## rad about the elbow over a ~0.86-unit arm moves it ~0.2, so this is far below the
## real figure and far above float noise: it answers "did ANYTHING move", not "is it
## enough". The second question is a FEEL call and belongs to the human, with the
## numbers in front of them.
const VISIBLE_TRAVEL: float = 0.02

## Degrees of ARM SWING the third-person wind-up must produce across the hold.
##
## ⚠️ AN ANGLE, NOT A DISTANCE, AND THE CORRECTION CAME OUT OF THE BONE DUMP. Leg B
## first asserted on how far `HandPoint` moved and measured 0.041 m at a full 0.62 rad,
## which reads like a wind-up nobody could possibly see. The skeleton says otherwise:
## this rig has SEVEN bones, `arm-right` is the whole arm, its origin is the SHOULDER at
## (+0.215,+0.292,-0.113) — and `HandPoint` sits only 0.076 from that origin, because it
## is `HAND_CARRY_OFFSET` off the joint rather than out at the fist. So the attachment is
## a good DIRECTION indicator and a useless magnitude one: the arm MESH swings the full
## 36° about the shoulder regardless, and 36° of arm is unmistakable at any range.
##
## The hand's travel is still printed. The pass rides on the angle.
const VISIBLE_SWING_DEG: float = 10.0

## The clip the control leg plays. `sprint` swings the arm hardest of the 32 on this
## rig (0.2847 m of hand travel — see `_scan_pose_clip`'s table), so a dead observable
## has nowhere to hide behind it.
const BASELINE_CLIP: String = "sprint"

## Seconds to WAIT for the other peer (polled, not slept — see `_run_net`). Generous,
## because the host must still be alive when the client's handshake completes and the
## two processes are started by hand seconds apart.
const NET_CONNECT_WAIT: float = 25.0
const NET_LINGER: float = 6.0

var _main: Node
var _fails := 0
var _checks := 0

func _ready() -> void:
	_park_window()
	var mode := ""
	var address := ""
	for arg in OS.get_cmdline_user_args():
		var a := String(arg)
		if a == "--host":
			mode = "host"
		elif a.begins_with("--join="):
			mode = "join"
			address = a.substr("--join=".length())
	if mode == "":
		await _run_local()
	else:
		await _run_net(mode, address)
	print("\nRESULT: %s" % ("FAIL — %d of %d assertions failed" % [_fails, _checks]
		if _fails > 0 else "PASS — %d assertions" % _checks))
	get_tree().quit(1 if _fails > 0 else 0)

## ⚠️ OUT OF THE WAY, AND SMALL — 🧑: *"the charge tell probe sits on top of existing
## hud/ui, reposition"*. This probe stands up a whole match, so its window is a real
## game window with a real HUD in it, and `GameLaunch` now CENTRES windows at boot
## (see `fit_window_to_usable_screen`) — which parks it squarely over whatever is
## already on the screen, including a running instance of the game. A diagnostic
## window should never be the thing you have to move.
##
## Top-left of the usable area, quarter size, unless the run asked for a specific
## `--resolution` (a capture harness's size is its own business). Two peers get an
## offset each so `--host` and `--join` do not land on top of each other either.
func _park_window() -> void:
	if DisplayServer.get_name() == "headless" or "--resolution" in OS.get_cmdline_args():
		return
	var win := get_window()
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	win.size = Vector2i(usable.size.x / 2, usable.size.y / 2)
	var second := "--join" in " ".join(OS.get_cmdline_user_args())
	win.position = usable.position + Vector2i(0, win.size.y if second else 0)

## ---------------------------------------------------------------------------
## LOCAL — one machine, both legs, no peers. Proves the MECHANISM.
## ---------------------------------------------------------------------------
func _run_local() -> void:
	_main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	# ⚠️ BEFORE THE ROUND STARTS, and that ordering is a bug this probe already hit. A
	# bot switched off DURING a charge never reaches its own release, so the charge
	# clock it started is never stopped — the pose stayed held for the rest of the run
	# and the walking control came back at 0.0000 m with no clip playing at all. That
	# is worth knowing about (the shipping guard in `_drive_charge_pose` exists because
	# of it) but it is not what the control is trying to measure.
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.ai_controller != null:
			ch.ai_controller.set_enabled(false)
	MatchManager.begin_next_round()
	await get_tree().create_timer(0.5).timeout

	# ⚠️⚠️ THE SLIPPER COMES OUT OF THE `slippers` GROUP, NOT THE CHARACTER WALK —
	# 2026-08-02. A tsinelas was a `CharacterBase` with a `Carriable` node until
	# 3abc019; it is a `Slipper` prop now, so the `not ch.is_person and not ch.is_can`
	# arm below matched nothing and the type it was cast to no longer exists.
	var attacker: CharacterBase = null
	var slipper: Slipper = null
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.is_person and not ch.team_is_can_side:
			attacker = ch
	if attacker != null:
		slipper = _slipper_owned_by(attacker)
	# ⚠️⚠️ THE SECOND DISCOVERY PASS THAT USED TO SIT HERE IS DELETED — 2026-08-02, and
	# it was a port miss of mine rather than a design change. It re-scanned every
	# `CharacterBase` for "not a Person, not a can, same team" and assigned the result
	# to `slipper`, which is a `Slipper` now — a parse error that took this whole file
	# down, so the probe could not run at all.
	#
	# What it existed for is genuinely gone. Its note said an opponent's slipper is
	# refused outright, so the pass was there to make sure the RIGHT one was grabbed
	# when tree order did not say which team came first. `slipper.gd` dropped that owner
	# gate ("everything above it — loose, an attacker, able to act" is the whole test),
	# and `_slipper_owned_by()` above already resolves by `owner_slot` in one pass.
	if attacker == null or slipper == null:
		print("CHARGE: could not find an attacking Person and a tsinelas")
		_fails += 1
		_checks += 1
		return

	# The probe drives the button; a bot holding the same one would be a second
	# writer on the very field being measured.
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.ai_controller != null:
			ch.ai_controller.set_enabled(false)
		ch.input_parked = ch != attacker
	var rig := attacker.get_node("CameraRig") as CameraRig
	rig.set_active(true)
	# ⚠️ THE CONTROL RUNS EMPTY-HANDED, AND IT TOOK TWO GOES TO GET THERE. A Person
	# carrying a tsinelas plays `holding-right`, which is a STATIC hold pose on this
	# rig, so the hand reads 0.0000 m of travel while walking — a dead-looking control
	# that was really a confounded one. The second confound was a bot handing the
	# attacker a slipper before the round even started, so the hand has to be EMPTIED
	# rather than merely assumed empty. Empty-handed, the same walk plays `walk` and the
	# arm swings 0.27 m.
	print("\n=== LOCAL · one machine, the charging peer's own view ===")
	var already := (attacker.get_node("Carrier") as Carrier).held()
	if already != null:
		# host_drop, not host_land — see the networked leg's note.
		already.host_drop()
		await get_tree().physics_frame
	await _baseline(attacker)
	await _measure_axis(attacker)

	# 672 seeked frames, ~90 s. It is the evidence for the pose being a bone rotation
	# rather than a clip, not a per-run check, so it is behind a flag: `-- --scan`.
	if "--scan" in OS.get_cmdline_user_args():
		await _scan_pose_clip(attacker)

	slipper.host_drop()
	await get_tree().physics_frame
	slipper.global_position = attacker.global_position + Vector3(0.4, 0.3, 0.0)
	await get_tree().physics_frame
	slipper.host_grab(attacker)
	await get_tree().physics_frame
	await get_tree().physics_frame

	await _hold_and_sample(attacker, rig, "local")

## ⚠️ THE CONTROL FOR LEG B, AND IT IS NOT OPTIONAL. The third-person hand read
## 0.0000 m on the first run of this probe — a number that is either the bug or a
## dead metric, and those two look identical. So: measure the same observable while
## the character WALKS, with no charge at all. A walking rig whose hand also reads
## 0.0000 means the observable cannot move and Leg B proves nothing; a walking rig
## whose hand moves means the flat charge sample is real.
##
## Drives the movement action rather than writing `velocity`, so the locomotion clip
## is selected by the same code path a player's WASD goes through.
## ⚠️ WHERE THE WIND-UP LIVES INSIDE `holding-right-shoot`, MEASURED RATHER THAN
## EYEBALLED — this is the evidence for `CharacterVisual.CHARGE_POSE_SPAN`.
##
## The third-person charge pose is a HELD, SCRUBBED frame of the throw clip
## (Art_Direction §234's own recommendation: *"hold a pose from this clip scaled by
## charge instead of inventing new geometry"*), so the constant that matters is how
## far INTO the clip the wind-up peaks. Past that frame the same clip is a release
## and a recoil, and holding a frame from there would show a Person who has already
## thrown a slipper they are still carrying.
##
## Prints the hand's character-local position across the whole clip and names the
## frame where it is furthest BACK and UP — the apex of the cock-back. Rerun this
## after any re-authoring of the rig; the constant is only as good as this table.
func _scan_pose_clip(subject: CharacterBase) -> void:
	var visual := subject.get_node_or_null("Visual") as CharacterVisual
	if visual == null:
		return
	var animator := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var hand: Node3D = visual.get_hand_attachment()
	if animator == null or hand == null:
		return
	# ⚠️ EVERY CLIP ON THE RIG, NOT JUST THE ONE THE CODE PICKS. The first version of
	# this scan looked only at `holding-right-shoot` and found the hand PERFECTLY
	# STATIC across all twenty frames of it — 0.20 s, dY 0.000 at every fraction. A
	# clip that does not move the arm bone cannot carry a wind-up no matter how it is
	# scrubbed, and that fact is invisible unless something measures the alternatives
	# too. So this prints, for every animation the rig has, how far the hand travels
	# through it and how far up and back it gets — which is the shortlist any
	# third-person charge pose has to be chosen from.
	print("\n  pose scan · every clip on this rig, hand in CHARACTER space")
	print("    %-26s %6s %8s %8s %8s" % ["clip", "len", "travel", "peak dY", "peak dZ"])
	animator.play("idle")
	await get_tree().process_frame
	var rest := subject.to_local(hand.global_position)
	var best := ""
	var best_score := -INF
	var names := animator.get_animation_list()
	names.sort()
	for clip in names:
		var length := animator.get_animation(clip).length
		var travel := 0.0
		var peak_y := 0.0
		var peak_z := 0.0
		var prev := rest
		animator.play(clip)
		animator.pause()
		for i in 21:
			animator.seek(float(i) / 20.0 * length, true)
			await get_tree().process_frame
			var p := subject.to_local(hand.global_position)
			travel += p.distance_to(prev)
			prev = p
			if absf(p.y - rest.y) > absf(peak_y):
				peak_y = p.y - rest.y
			if absf(p.z - rest.z) > absf(peak_z):
				peak_z = p.z - rest.z
		# Up and BACK, in the rig's own terms: +Y is up, and the Person model faces
		# +Z (see this file's MODEL_YAW_OFFSET note), so back is -Z.
		var score := peak_y - peak_z
		if score > best_score:
			best_score = score
			best = clip
		print("    %-26s %6.2f %8.4f %+8.3f %+8.3f" % [clip, length, travel, peak_y, peak_z])
	print("    furthest UP and BACK: %s (score %+.3f)" % [best, best_score])
	print("    for reference, the pose this build actually uses is a BONE rotation: %s by %.2f rad about %s"
		% [str(CharacterVisual.CHARGE_POSE_BONES), CharacterVisual.CHARGE_POSE_RAD,
			str(CharacterVisual.CHARGE_POSE_AXIS)])
	animator.play("idle")
	await get_tree().process_frame

## ⚠️ WHICH WAY DOES `arm-right` COCK BACK? MEASURED, NEVER READ OFF THE BASIS.
##
## `camera_rig.gd::set_viewmodel_charge()` carries the cautionary case in its own
## comment: the first-person wind-up was sign-inverted for a month behind a comment
## that said "upward", because a bone's — or a pivot's — local basis is not readable by
## eye. So this drives BOTH signs on the real skeleton, from the probe rather than
## through the shipping code, and prints where the hand ends up. The number this prints
## is the justification for `CharacterVisual.CHARGE_POSE_AXIS`; if they ever disagree,
## this table is right and the constant is wrong.
##
## Character space, so: +Y is up, and the Person rig faces +Z (see CharacterVisual's
## MODEL_YAW_OFFSET note), which makes BACK negative Z.
func _measure_axis(subject: CharacterBase) -> void:
	var visual := subject.get_node_or_null("Visual") as CharacterVisual
	if visual == null or visual.get_child_count() == 0:
		return
	var model := visual.get_child(0) as Node3D
	var skeletons := model.find_children("*", "Skeleton3D", true, false) if model != null else []
	var hand: Node3D = visual.get_hand_attachment()
	if skeletons.is_empty() or hand == null:
		return
	var skeleton := skeletons[0] as Skeleton3D
	var bone := -1
	var bone_name := ""
	for candidate in CharacterVisual.CHARGE_POSE_BONES:
		bone = skeleton.find_bone(candidate)
		if bone != -1:
			bone_name = candidate
			break
	if bone == -1:
		print("  axis: this rig has none of %s" % str(CharacterVisual.CHARGE_POSE_BONES))
		return
	# ⚠️ PAUSE THE ANIMATOR FIRST. Both signs printed dY +0.000 until this line existed:
	# the AnimationPlayer re-applies its current frame AFTER a coroutine's bone write, so
	# an unpaused measurement measures the clip and calls it the pose. The shipping code
	# pauses for the same reason — see `CharacterVisual._drive_charge_pose()`.
	var animator := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator != null:
		animator.pause()
	# ⚠️ AND `_play_locomotion()` HAS TO BE HELD OFF TOO — pausing alone is not enough,
	# because that function runs every frame and `play()` RESUMES a paused player. With
	# only the pause, this block printed the SAME hand position for +X and -X: two
	# opposite rotations reading identically, which cannot both be true and was the clip
	# being re-applied over both of them.
	visual.set_process(false)
	var rest_rot := skeleton.get_bone_pose_rotation(bone)
	await get_tree().process_frame
	await get_tree().process_frame
	var rest := subject.to_local(hand.global_position)
	print("\n  axis · %s, %.2f rad, hand in CHARACTER space (+Y up, BACK is -Z)"
		% [bone_name, CharacterVisual.CHARGE_POSE_RAD])
	print("    rest hand %s" % _v(rest))
	# ⚠️ ALL THREE AXES, BOTH SIGNS — SIX ROWS, BECAUSE ONE PAIR IS NOT AN ANSWER. The
	# first version of this measured ±X only and found the hand moving 0.039 m at a full
	# 0.62 rad: correct in direction and far too small to see on a figure 1.6 units tall.
	# A rotation whose axis runs ALONG the arm is a wrist twist, and it looks exactly
	# like a wind-up that is "working" in every number except the one that matters. The
	# axis that swings the hand furthest is a fact about this bone's basis and nothing
	# else, so it is measured rather than assumed — the same reason `windup_probe.gd`
	# exists for the first-person pivot.
	# ⚠️ THE SKELETON ITSELF, because every number below depends on where this bone's
	# ORIGIN is and nothing had ever printed it. A full 0.62 rad about `arm-right` moved
	# the hand attachment only ~0.04 units on the first sweep, which says the attachment
	# sits ~0.07 units from the bone origin — a wrist offset, not an arm's length. That
	# changes what "the arm swung" even means, so the joint positions get printed once.
	print("    bones (origin in CHARACTER space, * = the one being driven)")
	for b in skeleton.get_bone_count():
		var origin := subject.to_local(skeleton.global_transform
			* skeleton.get_bone_global_pose(b).origin)
		print("      %s%-18s parent %-3d origin %s" % ["* " if b == bone else "  ",
			skeleton.get_bone_name(b), skeleton.get_bone_parent(b), _v(origin)])
	print("    %-6s %-26s %8s %8s %8s" % ["axis", "hand", "dY", "dZ", "travel"])
	var winner := ""
	var winner_travel := 0.0
	for spec in [["+X", Vector3(1, 0, 0)], ["-X", Vector3(-1, 0, 0)],
			["+Y", Vector3(0, 1, 0)], ["-Y", Vector3(0, -1, 0)],
			["+Z", Vector3(0, 0, 1)], ["-Z", Vector3(0, 0, -1)]]:
		var p := Vector3.ZERO
		for _f in 5:
			skeleton.set_bone_pose_rotation(bone, rest_rot
				* Quaternion((spec[1] as Vector3).normalized(), CharacterVisual.CHARGE_POSE_RAD))
			await get_tree().process_frame
			p = subject.to_local(hand.global_position)
		var up_and_back := p.y > rest.y and p.z < rest.z
		var travel := p.distance_to(rest)
		if up_and_back and travel > winner_travel:
			winner_travel = travel
			winner = String(spec[0])
		print("    %-6s %-26s %+8.3f %+8.3f %8.3f  %s" % [spec[0], _v(p),
			p.y - rest.y, p.z - rest.z, travel,
			"up and back" if up_and_back else ""])
	print("    furthest UP-AND-BACK axis: %s (%.3f m of hand travel at full charge)"
		% [winner, winner_travel])
	for sign_ in []:
		# ⚠️ EVERY FRAME, FOR SEVERAL FRAMES. A single write before a single frame
		# reported dY +0.000 for BOTH signs — the AnimationPlayer keys this same bone
		# and puts it straight back, so one write measures the animation, not the pose.
		# The shipping code writes it every frame for exactly this reason; a probe that
		# does not is a dead metric that looks like a symmetrical result.
		var p := Vector3.ZERO
		for _f in 5:
			skeleton.set_bone_pose_rotation(bone, rest_rot
				* Quaternion(Vector3.RIGHT, sign_ * CharacterVisual.CHARGE_POSE_RAD))
			await get_tree().process_frame
			p = subject.to_local(hand.global_position)
		print("    %+.0fX  hand %s  dY %+.3f  dZ %+.3f   %s" % [sign_, _v(p),
			p.y - rest.y, p.z - rest.z,
			"up and back" if p.y > rest.y and p.z < rest.z else "not up-and-back"])
	skeleton.set_bone_pose_rotation(bone, rest_rot)
	visual.set_process(true)
	if animator != null:
		animator.play(animator.current_animation)
	await get_tree().process_frame
	print("    shipping constant: CHARGE_POSE_AXIS %s" % str(CharacterVisual.CHARGE_POSE_AXIS))

func _baseline(subject: CharacterBase) -> void:
	var visual := subject.get_node_or_null("Visual") as CharacterVisual
	var hand: Node3D = visual.get_hand_attachment() if visual != null else null
	if hand == null:
		print("  baseline: no hand attachment — Leg B cannot be measured at all")
		_fails += 1
		_checks += 1
		return
	var animator := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator == null or not animator.has_animation(BASELINE_CLIP):
		print("  baseline: no %s clip to control against" % BASELINE_CLIP)
		_fails += 1
		_checks += 1
		return
	# ⚠️ PLAYS THE CLIP DIRECTLY, AND THE COMMENT HAS TO SAY WHY. Two earlier versions
	# drove WASD instead — the honest path — and both came back 0.0000 m for reasons
	# that had nothing to do with the observable: a slipper in the hand pins the rig to
	# the static `holding-right` pose, and which unit the keyboard drives depends on
	# input parking. This control has exactly one job — prove the HandPoint moves when
	# the SKELETON moves, so that a flat charge sample is a real result — and playing a
	# known-animated clip is the shortest path to that with no confounds.
	# ⚠️ It does NOT assert that locomotion SELECTS this clip. That is a different claim
	# and this is not evidence for it.
	# ⚠️ AND LOCOMOTION HAS TO BE HELD OFF WHILE IT PLAYS. `_play_locomotion()` runs every
	# single frame, and a Person with a slipper in hand gets `holding-right` — a STATIC
	# pose — re-played over this clip before it can advance a frame. That is why the
	# third version of this control ALSO came back 0.0000 m: not a dead observable, a
	# clip being overwritten 60 times a second by the thing under test.
	visual.set_process(false)
	animator.play(BASELINE_CLIP)
	var rows: Array = []
	for _i in SAMPLES:
		await get_tree().process_frame
		rows.append({"hand": subject.to_local(hand.global_position)})
	visual.set_process(true)
	var travel := _travel(rows, "hand")
	_assert("baseline · the hand moves when the SKELETON does (control, no charge)",
		travel >= VISIBLE_TRAVEL,
		"travelled %.4f m in character space over %d frames of `%s` — if this is 0 the metric is dead, not the game"
			% [travel, SAMPLES, BASELINE_CLIP])

## ---------------------------------------------------------------------------
## TWO PEERS — the only configuration Leg B's claim is actually about.
##
## The HOST charges. The CLIENT owns nothing about that charge: it never runs
## `input_step()` for that unit, so every number it prints comes off the observed
## clock and the replicated state. Copied from `aim_probe.gd::_run_net()`, including
## the polled ready-up, for the reason recorded there — `_awaiting_net_ready` is only
## set once the host's own phase RPC lands, which can be after the probe's first look.
## ---------------------------------------------------------------------------
func _run_net(mode: String, address: String) -> void:
	# ⚠️ LET `main.gd` OPEN THE SESSION, AND PUT `Main` AT `/root/Main`. Both halves were
	# wrong in the first version of this leg and it cost a run: it called
	# `NetworkManager.host_game()` itself AND set `pending_action`, so `main.gd::_ready()`
	# tried to host a second time on a port already in use; and it parented Main under the
	# probe, so every RPC addressed `ChargeTellProbe/Main` on one peer and `Main` on the
	# other — the spawner and the synchronizers address nodes by PATH. Both peers reported
	# `peers []` and the host's own charge broadcast then failed silently. Same setup
	# `aim_probe.gd::_run_net()` documents; do not "simplify" it back.
	GameLaunch.pending_action = mode
	GameLaunch.pending_join_address = address
	_main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	_main.name = "Main"
	get_tree().root.add_child.call_deferred(_main)
	await get_tree().process_frame
	get_tree().current_scene = _main
	# ⚠️ WAIT FOR THE PEER, DO NOT SLEEP AND HOPE. A fixed `NET_CONNECT_WAIT` looked at
	# the session once and both peers failed it: the host reached its check 4 s in, at
	# which point the client process had barely booted, so it reported `peers []` and
	# QUIT — taking the session down before the client could finish its handshake. The
	# host has to outlive the client, so the host is the one that must be patient.
	for _i in int(NET_CONNECT_WAIT * 10.0):
		if not multiplayer.get_peers().is_empty():
			break
		await get_tree().create_timer(0.1).timeout
	# ⚠️ ASSERT THE SESSION BEFORE MEASURING ANYTHING IN IT. A run where the peers never
	# connected does not merely lose the client's numbers — the HOST's go wrong too, and
	# silently: `_broadcast_charge` calls `_rpc_charge_visual.rpc()`, and an `rpc()` on a
	# disconnected peer errors out WITHOUT running its own `call_local` half, so the
	# host's observed clock stays at -1 and its third-person pose never fires. Measured
	# exactly that way once, on a run with a stale instance holding the port: the host
	# printed `observed -1.000` beside an arm that swung 77.9° — the swing was a
	# locomotion clip, not a wind-up. Two numbers that cannot both be true.
	_assert("%s · the session is up" % mode, multiplayer.get_peers().size() >= 1,
		"peers %s, unique id %d" % [str(multiplayer.get_peers()), multiplayer.get_unique_id()])
	if multiplayer.get_peers().is_empty():
		print("CHARGE: no peer connected — refusing to report a networked claim")
		return
	await _net_ready_up()
	await get_tree().create_timer(1.0).timeout

	# ⚠️ THE SUBJECT IS THE ATTACKING PERSON, AND WHICH PEER DRIVES IT FOLLOWS FROM THAT
	# RATHER THAN THE OTHER WAY ROUND.
	#
	# The first version picked "a Person the host owns" and the leg could not run at all:
	# `slipper NONE on the subject's team`. Only the ATTACKING team has a tsinelas — the
	# defending team's Prop is the lata — and `can_be_grabbed_by()` refuses an opponent's
	# slipper outright, so a Person on the can side has nothing to wind up with. Which team
	# is attacking in round 1 is a coin flip, and with two humans both seats are on team A,
	# so half of all runs had no valid subject and said so only as `held=<null>`.
	#
	# So: the subject is the attacking Person, whoever owns it. The peer that OWNS it drives
	# the button (`input_step()` runs nowhere else) and the other peer OBSERVES. The claim is
	# symmetric — "a peer that does not own the charging Person can see the wind-up" — so it
	# does not matter which of the two ends up watching, only that one of them does.
	var subject: CharacterBase = null
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.is_person and not ch.team_is_can_side and subject == null:
			subject = ch
	if subject == null:
		print("CHARGE: no attacking Person in the networked match")
		_fails += 1
		_checks += 1
		return
	var mine := subject.get_multiplayer_authority() == multiplayer.get_unique_id()
	print("
=== NET · %s · subject %s (authority %d, local peer %d) — this peer %s ===" % [
		mode, subject.name, subject.get_multiplayer_authority(), multiplayer.get_unique_id(),
		"DRIVES" if mine else "OBSERVES"])

	# ⚠️ THE HOST PUTS THE SLIPPER IN THE HAND EVEN WHEN THE CLIENT IS THE ONE THROWING.
	# `carriable.gd::host_grab()` no-ops off the host by design, and carry state is a host
	# broadcast, so this is the only peer that can set it up — for either Person.
	if mode == "host":
		# ⚠️ MATCHED ON `owner_slot`, NOT ON `team` — 2026-08-02. Teams were how a prop
		# was paired to its side when a tsinelas was a character; a `Slipper` carries
		# `owner_slot` instead, which is the seat it belongs to and the thing
		# `_reset_world()` assigns every round.
		var slipper := _slipper_owned_by(subject)
		if slipper != null:
			# ⚠️ `host_drop()`, NOT `host_land()`. `host_land` only fires from FLYING, so on a
			# slipper a bot had already picked up it is a no-op — measured as
			# `grabbable=false` with the slipper CARRIED, after which the re-grab was skipped
			# and the OBSERVING peer never received a carry broadcast at all (`held=<null>`
			# on the client beside `held=Carriable:<...>` on the host, for the same unit —
			# two numbers that cannot both be true). Dropping and re-grabbing forces the
			# broadcast both peers need.
			slipper.host_drop()
			await get_tree().physics_frame
			slipper.global_position = subject.global_position + Vector3(0.4, 0.3, 0.0)
			await get_tree().physics_frame
			slipper.host_grab(subject)
			print("  slipper  %s owner_slot=%d (subject slot=%d) grabbable=%s" % [
				slipper.name, slipper.owner_slot, subject.player_slot,
				str(slipper.can_be_grabbed_by(subject))])
		else:
			print("  slipper  NONE owned by this seat — that should be impossible")

	# Both peers wait for the carry to land: the driver needs it because
	# `carrier.gd::_step_throw` returns immediately with nothing in hand, and the observer
	# needs it because it is the replicated fact everything downstream hangs off.
	var carrier := subject.get_node("Carrier") as Carrier
	for _f in 120:
		if carrier.held() != null:
			break
		await get_tree().physics_frame
	_assert("%s · the slipper is in hand" % mode, carrier.held() != null,
		"held=%s (replicated from the host either way)" % str(carrier.held()))

	if mine:
		for c in _main.find_children("*", "CharacterBase", true, false):
			var ch := c as CharacterBase
			if ch.ai_controller != null:
				ch.ai_controller.set_enabled(false)
			ch.input_parked = ch != subject
		var rig := subject.get_node("CameraRig") as CameraRig
		rig.set_active(true)
		print("  preconditions  round_active=%s state=%d held=%s parked=%s ai=%s" % [
			str(RoundManager.round_active), subject.state, str(carrier.held() != null),
			str(subject.input_parked),
			str(subject.ai_controller != null and subject.ai_controller.is_enabled())])
		await _hold_and_sample(subject, rig, mode)
	else:
		# ⚠️ PRESSES NOTHING. A peer that drives its own button would measure its own local
		# charge and call it an observation.
		await _observe_only(subject)
	if mode == "host":
		# The host must outlive the client — the session dies with it.
		await get_tree().create_timer(NET_LINGER).timeout

func _net_ready_up() -> void:
	for _i in 60:
		if not bool(_main.get("_awaiting_net_ready")):
			if RoundManager.round_active or bool(_main.get("_counting_down")):
				return
		else:
			_main._rpc_declare_ready.rpc_id(1)
		await get_tree().create_timer(0.5).timeout
		if RoundManager.round_active:
			return
	print("CHARGE: never reached a live round — the ready phase did not complete")

## ---------------------------------------------------------------------------
## The sampler. Presses the REAL action through the REAL input path, because
## "charge started" is exactly the link that broke last time and a probe that sets
## `_is_charging` by hand would have passed straight through it.
## ---------------------------------------------------------------------------
## ⚠️ IT HOLDS THE LEFT MOUSE BUTTON, NOT THE ACTION — and that difference is the
## whole reason this probe can see what 🧑 is reporting. `Input.action_press()`
## bypasses the InputMap completely: it would report a healthy wind-up on a build
## where left click is bound to nothing at all, which is EXACTLY the state
## `settings.cfg` used to leave the game in (`special_ability=81` applied with a full
## `action_erase_events`, so Q survived and both mouse buttons did not). The human's
## input is a physical click, so the probe sends a physical click through
## `Input.parse_input_event` and lets the InputMap decide what that means.
##
## `-- --action` presses the action directly instead, which isolates "the wind-up
## visuals are broken" from "the click does not reach the wind-up".
func _hold_and_sample(subject: CharacterBase, rig: CameraRig, tag: String) -> void:
	var by_action := "--action" in OS.get_cmdline_user_args()
	var action := subject.action_name("special_ability")
	_dump_bindings(action, subject.action_name("grab"))
	if by_action:
		Input.action_press(action)
	else:
		_click(true)
	# One frame, then ask the InputMap whether the click became the action. This is
	# the link that was broken and it is worth its own assertion rather than being
	# inferred from a flat pose further down.
	await get_tree().physics_frame
	_assert("%s · a held LEFT CLICK reads as %s" % [tag, action],
		Input.is_action_pressed(action) or by_action,
		"pressed=%s (this is the link settings.cfg used to sever)"
			% str(Input.is_action_pressed(action)))
	# ⚠️ THE NET LEG RE-PRESSES EVERY TICK, AND THAT IS NOT BELT-AND-BRACES. Two windows
	# on one machine means the host loses FOCUS the moment the client's window opens, and
	# Godot releases every pressed input on focus-out. Measured on the first two-peer run:
	# `local -1.000` for the whole hold with `holding-right-shoot` already PLAYING in the
	# first sample — the charge had started and released inside two frames and the probe
	# was watching the throw. A held button cannot be simulated across a focus change, so
	# the networked legs hold the ACTION instead and renew it each tick. The local leg
	# keeps the physical click, which is what proves the InputMap link.
	var rows := await _sample(subject, rig, tag, action if tag != "local" else "")
	if by_action:
		Input.action_release(action)
	else:
		_click(false)
	await get_tree().physics_frame
	_report(rows, tag, true)

## A real left mouse button, through the real input pipeline.
func _click(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(event)

## What the RUNTIME InputMap holds, not what `project.godot` says — the two
## disagreed for weeks and that disagreement was the bug. Both actions on the left
## button are printed, because a physical click drives every one of them.
func _dump_bindings(special: String, grab: String) -> void:
	for action in [special, grab, "jump", "bump"]:
		if not InputMap.has_action(action):
			print("  bindings  %-16s ** NO SUCH ACTION **" % action)
			continue
		var names: Array[String] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				names.append("key:%s" % (event as InputEventKey).as_text_physical_keycode())
			elif event is InputEventMouseButton:
				names.append("MOUSE:%d" % (event as InputEventMouseButton).button_index)
			else:
				names.append(event.as_text())
		print("  bindings  %-16s %s" % [action, ", ".join(names)])

## The watching peer. Named "observer" rather than "client" because which of the two peers
## watches depends on who owns the attacking Person, not on who hosts — see `_run_net`.
func _observe_only(subject: CharacterBase) -> void:
	# ⚠️ WATCHES FOR THREE TIMES AS LONG AS THE DRIVER HOLDS, and then only the charging
	# part of that is judged. The two processes are started by hand seconds apart and each
	# waits on its own clock, so the observer's window cannot be assumed to bracket the
	# hold: measured once as `first 0.663 last -1.000` — the client had genuinely SEEN the
	# wind-up (0.663 is not -1) and the run failed on the fact that its window caught the
	# tail. Widening the window and trimming to the charging segment measures the wind-up
	# instead of the alignment of two stopwatches.
	var rows := await _sample(subject, null, "observer", "", 3)
	_report(rows, "observer", false)

## `hold_action` is renewed on every tick when non-empty — see `_hold_and_sample`'s note
## about focus loss between two windows on one machine.
func _sample(subject: CharacterBase, rig: CameraRig, tag: String, hold_action: String,
		spans: int = 1) -> Array:
	var carrier := subject.get_node_or_null("Carrier") as Carrier
	var visual := subject.get_node_or_null("Visual") as CharacterVisual
	var hand: Node3D = visual.get_hand_attachment() if visual != null else null
	# The arm bone itself — the thing the pose actually writes, and the honest measure of
	# how much of the arm moved. See VISIBLE_SWING_DEG.
	var skeleton: Skeleton3D = null
	var bone := -1
	if visual != null and visual.get_child_count() > 0:
		var model := visual.get_child(0) as Node3D
		var skeletons := model.find_children("*", "Skeleton3D", true, false) if model != null else []
		if not skeletons.is_empty():
			skeleton = skeletons[0] as Skeleton3D
			for candidate in CharacterVisual.CHARGE_POSE_BONES:
				bone = skeleton.find_bone(candidate)
				if bone != -1:
					break
	var rows: Array = []
	for i in SAMPLES * spans:
		if hold_action != "":
			Input.action_press(hold_action)
		await get_tree().create_timer(HOLD_TIME / float(SAMPLES)).timeout
		var row := {
			"t": float(i + 1) * HOLD_TIME / float(SAMPLES),
			# The owner's clock (-1 on any peer that does not drive this unit) and
			# the one every peer ticks. Printed together on purpose.
			"local_power": carrier.charge_power() if carrier != null else -1.0,
			"observed_power": carrier.observed_charge_power() if carrier != null else -1.0,
			"fist": Vector3.ZERO,
			"hand": Vector3.ZERO,
			"arm_rot": 0.0,
			# ⚠️ WHAT THE ANIMATOR IS DOING WHILE THE POSE IS SUPPOSED TO BE HELD. The
			# third-person pose is a bone write, and any clip still running keys the same
			# bone — so "is it playing" is the difference between the full 0.62 rad and a
			# fraction of it. Printed, not assumed.
			"anim": "",
			"playing": false,
			"arm_q": Quaternion.IDENTITY,
		}
		if skeleton != null and bone != -1:
			row["arm_q"] = skeleton.get_bone_pose_rotation(bone)
		if visual != null:
			var animator := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if animator != null:
				row["anim"] = animator.current_animation
				row["playing"] = animator.is_playing()
		if rig != null:
			var arms := rig.find_child("ViewmodelArms", true, false) as Node3D
			if arms == null:
				for child in rig.find_children("*", "Node3D", true, false):
					if child.get_node_or_null("RightPivot/Arm") != null:
						arms = child as Node3D
						break
			var arm := arms.get_node_or_null("RightPivot/Arm") as Node3D if arms != null else null
			var fist := arms.get_node_or_null("RightPivot/Arm/HeldSlipper") as Node3D \
				if arms != null else null
			if arm != null:
				row["arm_rot"] = arm.rotation.x
			if fist != null and rig.fpp_camera != null:
				# Camera space: +Y up, -Z forward. The same convention
				# `windup_probe.gd` reports in, so the two are comparable.
				row["fist"] = (rig.fpp_camera as Camera3D).global_transform.affine_inverse() \
					* fist.global_position
		if hand != null and is_instance_valid(hand):
			# CHARACTER-local, so running and turning cannot masquerade as a pose.
			row["hand"] = subject.to_local(hand.global_position)
		rows.append(row)
	return rows

## ⚠️ TRIMS TO THE CHARGING SEGMENT FIRST. `rows` may be three times longer than the hold
## (see `_observe_only`), and judging a wind-up over a window that also contains the
## idle-before and the throw-after would measure the harness's timing, not the feature. The
## LONGEST contiguous run of `observed_power >= 0` is the wind-up; everything else is noise
## around it. A driver's own window is already tight, so this is usually a no-op there.
func _report(rows: Array, tag: String, expect_fpp: bool) -> void:
	var best_from := 0
	var best_len := 0
	var from := -1
	for i in range(rows.size()):
		var charging: bool = float(rows[i]["observed_power"]) >= 0.0
		if charging and from < 0:
			from = i
		if (not charging or i == rows.size() - 1) and from >= 0:
			var to: int = i if not charging else i + 1
			if to - from > best_len:
				best_len = to - from
				best_from = from
			from = -1
	if best_len >= 4 and best_len < rows.size():
		print("  (trimmed to the charging segment: samples %d..%d of %d)"
			% [best_from, best_from + best_len - 1, rows.size()])
		rows = rows.slice(best_from, best_from + best_len)
	print("  %4s %8s %8s   %-24s %-24s %8s  %s"
		% ["t", "local", "observed", "fist (camera space)", "hand (character space)",
			"arm.x", "animator"])
	for row in rows:
		print("  %4.2f %8.3f %8.3f   %-24s %-24s %8.3f  %s%s" % [
			row["t"], row["local_power"], row["observed_power"],
			_v(row["fist"]), _v(row["hand"]), row["arm_rot"],
			row["anim"], " PLAYING" if row["playing"] else " paused"])

	# ⚠️ THE OBSERVED CLOCK FIRST. Everything else is downstream of it: if this never
	# rises on this machine, no pose on this machine can be driven by a charge, and
	# the answer is in the broadcast rather than in the visuals.
	var observed_rise: float = float(rows[-1]["observed_power"]) - float(rows[0]["observed_power"])
	_assert("%s · observed_charge_power rises" % tag,
		float(rows[-1]["observed_power"]) > 0.0,
		"first %.3f last %.3f (delta %+.3f)"
			% [rows[0]["observed_power"], rows[-1]["observed_power"], observed_rise])

	var hand_travel := _travel(rows, "hand")
	# Degrees the arm bone swept between the first sample and the deepest point of the
	# hold. Measured against the FIRST sample rather than against a rest pose, because a
	# charge is already ~0.4 by the time anything can be read — so this is the visible
	# sweep of the wind-up, not its absolute depth.
	var swing := 0.0
	# ⚠️ AND IT HAS TO RISE WITH THE CHARGE, NOT MERELY MOVE. An arm playing ANY clip
	# sweeps tens of degrees, so "it swept 10°" on its own credits locomotion for the
	# wind-up — measured once at 77.9° of swing beside an observed charge of -1.000. A
	# wind-up is monotonic in the charge by construction, so a sample that swings BACK
	# toward the first pose is a clip, and one clip frame is enough to disqualify it.
	var monotonic := true
	var prev := 0.0
	for row in rows:
		var d := rad_to_deg((rows[0]["arm_q"] as Quaternion).angle_to(row["arm_q"] as Quaternion))
		if d < prev - 1.0:
			monotonic = false
		prev = d
		swing = maxf(swing, d)
	_assert("%s · THIRD-PERSON arm swings with the charge" % tag,
		swing >= VISIBLE_SWING_DEG and monotonic,
		"arm-right swept %.1f° (threshold %.0f°), %s with the hold, hand attachment %.4f m — this is the pose every OTHER player looks at"
			% [swing, VISIBLE_SWING_DEG, "rising" if monotonic else "NOT MONOTONIC (a clip, not a wind-up)",
				hand_travel])
	# ⚠️ DIRECTION, NOT JUST DISTANCE — the same clause the first-person leg has, for
	# the same reason (B-131 moved the right distance the wrong way). At full charge the
	# third-person arm has to be UP and BACK: +Y is up, and the Person rig faces +Z, so
	# back is -Z.
	var hand_dy: float = float(rows[-1]["hand"].y) - float(rows[0]["hand"].y)
	var hand_dz: float = float(rows[-1]["hand"].z) - float(rows[0]["hand"].z)
	_assert("%s · that hand goes UP and BACK" % tag, hand_dy > 0.0 and hand_dz < 0.0,
		"dY %+.4f dZ %+.4f in character space (+Y up, BACK is -Z)" % [hand_dy, hand_dz])

	if expect_fpp:
		var fist_travel := _travel(rows, "fist")
		_assert("%s · FIRST-PERSON fist moves with the charge" % tag,
			fist_travel >= VISIBLE_TRAVEL,
			"travelled %.4f m in camera space (threshold %.2f)"
				% [fist_travel, VISIBLE_TRAVEL])
		# The direction, not just the magnitude — B-131 was a wind-up that moved
		# exactly this far in exactly the wrong direction and read as "broken".
		var dy: float = float(rows[-1]["fist"].y) - float(rows[0]["fist"].y)
		_assert("%s · the fist goes UP, not down" % tag, dy > 0.0,
			"dY %+.4f in camera space (+Y is up)" % dy)

## Total path length of one observable across the hold. A path length rather than an
## endpoint delta: a pose that rises and falls back would score zero on the
## difference and is still perfectly visible.
func _travel(rows: Array, key: String) -> float:
	var total := 0.0
	for i in range(1, rows.size()):
		total += (rows[i][key] as Vector3).distance_to(rows[i - 1][key] as Vector3)
	return total

func _assert(what: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("  %s %-52s %s" % ["ok  " if ok else "**  ", what, detail])

func _v(v: Vector3) -> String:
	return "(%+.3f,%+.3f,%+.3f)" % [v.x, v.y, v.z]

## The `Slipper` belonging to one seat. Replaces the old "walk every CharacterBase
## looking for one that is neither a Person nor a can, on my team" search, which
## described a world where a prop was a character (3abc019 ended it).
func _slipper_owned_by(who: CharacterBase) -> Slipper:
	for node in get_tree().get_nodes_in_group("slippers"):
		var s := node as Slipper
		if s != null and s.owner_slot == who.player_slot:
			return s
	return null
