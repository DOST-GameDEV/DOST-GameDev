extends Node
## HIT REGISTRATION ON AN OPPOSING PERSON, MEASURED ON A REAL MULTI-PEER SESSION.
##
## Human report, 2026-07-29: *"there are times you can't hit an opposing player"*.
## Three hypotheses were on the table and this probe exists to tell them apart
## rather than to argue about them:
##
##   A. NETWORK DESYNC — the host resolves every hit (hitbox.gd's host gate), but
##      a remotely-owned character's position on the host is whatever the
##      MultiplayerSynchronizer last delivered. If that lags far enough, the host
##      genuinely sees a miss while the throwing peer saw a hit.
##   B. COLLISION LAYER / MASK — the per-throw pulse hitbox is built in code
##      (ability_utils.gd), not in the scene, and its own header still says
##      "first-pass / untested in-editor: double check the collision layers match
##      CharacterBase.tscn's Hurtbox". Nobody ever did.
##   C. TUNNELLING — a throw covers `launch_speed / physics_fps` metres per frame
##      (0.43 m for throw_flick at full charge) and `area_entered` is an edge
##      event. A fast enough slipper can step clean over the overlap band.
##
## ⚠️ WHY THIS IS NOT phys_probe. phys_probe drives the LOCAL flow, and the
## report is about multiplayer. That is trap 1 in the method note, and
## spawn_probe.gd is the standing example of a probe that passed for ten sessions
## while the game was broken. This one stands up real ENet peers.
##
## ⚠️ WHY IT DOES NOT TRUST `landed_on` ALONE. That is trap 2. `ai_probe`
## connected to hitboxes once at setup and therefore never saw the per-throw
## pulse hitbox `_spawn_flight_hitbox()` creates INSIDE host_throw, so it reported
## "throws that reached the can: 0" for every run ever recorded. Here the watch is
## re-armed AFTER every host_throw, and — more importantly — the resolution count
## is checked against an INDEPENDENT GEOMETRIC MEASUREMENT that shares no code
## with it (see _closest_approach). Two numbers that cannot both be true is what
## catches a lying metric.
##
## THE GEOMETRY IS EXACT, NOT A HEURISTIC. The flight hitbox is a sphere of
## `ThrowProfile.hit_radius` centred on the slipper's own origin
## (`_spawn_flight_hitbox` passes `Vector3.ZERO` with `follow_character = true`),
## and a Hurtbox is a capsule. A sphere overlaps a capsule exactly when the
## sphere's centre is within `capsule_radius + sphere_radius` of the capsule's
## INNER SEGMENT — so that is what is measured, per physics frame, per peer.
## A throw whose closest approach is inside that band MUST resolve a hit. One
## that does so and does not resolve is the reported bug, with no interpretation
## required.
##
## USAGE — one terminal per peer, host first. Four peers is the interesting case:
## with only two, main.gd fills the other two slots with host-owned AI and every
## opposing Person is therefore local to the resolving host, which is exactly the
## condition hypothesis A cannot be observed under.
##
##   godot --path . --headless tools/hit_probe.tscn -- --host
##   godot --path . --headless tools/hit_probe.tscn -- --join=127.0.0.1
##   godot --path . --headless tools/hit_probe.tscn -- --join=127.0.0.1
##   godot --path . --headless tools/hit_probe.tscn -- --join=127.0.0.1
##
## Optional: `-- --host map=bayan_plaza` to measure the second map.
##
## ⚠️ THE PROBE IS NOT THE CURRENT SCENE. Same two reasons net_spawn_probe.gd
## documents at length: network_manager.gd's route-to-match guard would replace
## the root scene and free this node, and the spawner/synchronizer address nodes
## by PATH, so Main must live at `/root/Main` on every peer or nothing replicates.
##
## Exit code 0 when every throw that geometrically overlapped also resolved.

## Throws to attempt. Each cycle is ~0.9 s, so this is well inside one round's
## 90 s when rounds run long, and the loop simply waits out an intermission when
## they do not.
const THROWS: int = 40
## Seconds to let ENet connect and the spawner replicate before the first throw.
const CONNECT_WAIT: float = 5.0
## Seconds to follow each throw before scoring it. A 6 m throw at full charge has
## a flight time near 0.3 s (Art_Direction.md §9); this is generous so a lobbed or
## deflected one is still followed to rest.
const FLIGHT_WATCH: float = 1.1
## Charge to throw at. 1.0 — full power is both the fastest slipper (the worst
## case for hypothesis C) and the one that certainly reaches the target.
const POWER: float = 1.0
## Throws to take before forcing a round transition.
##
## ⚠️ WITHOUT THIS THE PROBE MEASURES THE WRONG HALF OF THE PROBLEM, and the
## first four-peer run did exactly that: all 40 throws landed inside round 1, so
## the taya was the HOST'S OWN Person every single time and the column that
## matters — a remotely-owned target, the only condition under which the host can
## be looking at a stale position — read "0 of 0". A green run that never
## exercised the case under test is trap 1 wearing a different hat.
const THROWS_PER_ROUND: int = 5
## Seconds the HOST lingers after its last throw. ⚠️ NOT PADDING — when the host
## drops, every client tears its own match down and prints nothing.
const HOST_LINGER: float = 8.0

var _tag: String = "?"
var _is_host: bool = false
var _map_id := &"eskinita"
## `-- target=taya|can`. The can is the one the human's "can the can even fall?"
## question is about; the taya is the one "you can't hit an opposing player" is
## about. Same machinery, and they answer different questions.
var _target_mode := "taya"

## Per-throw records, appended in flight order so the host's and a client's logs
## line up index for index.
var _records: Array[Dictionary] = []

## Live sampling state, written by _physics_process while a throw is in the air.
var _watching: bool = false
var _slipper: CharacterBase = null
var _target: CharacterBase = null
var _min_gap: float = INF          # distance from slipper origin to target capsule SEGMENT
var _overlap_band: float = 0.0     # target capsule radius + flight hitbox radius
var _max_step: float = 0.0         # largest single-frame displacement of the slipper
var _last_pos: Vector3 = Vector3.INF
var _resolved_by: String = ""      # which hitbox resolved, "" if none
var _target_left_normal: bool = false
## The FURTHEST the target's state got during the flight. "Left NORMAL" is not
## the question the human asked — STAGGERED and DOWNED both leave it, and only
## DOWNED is the can actually falling over.
var _target_peak_state: int = CharacterBase.State.NORMAL
## THE LUCKY FALL, observed rather than assumed (CharacterBase.LUCKY_FALL_CHANCE).
## Recorded on the frame the target ENTERS Downed, because a lucky fall
## self-rights and would otherwise be indistinguishable afterwards from one that
## never happened.
var _fall_lucky: bool = false
var _was_downed: bool = false
## RoundManager's fall counter across the knockdown, sampled either side of the
## frame it happens on. The DELTA is the acceptance test for the lucky fall:
## exactly 0 for a lucky one and exactly 1 for a scoring one. Reading the counter
## once at the end proves nothing — start_round() zeroes it every round.
var _fall_count_before: int = -1
var _fall_count_after: int = -1
var _frames: int = 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var token := String(arg)
		if token == "--host":
			_is_host = true
		elif token.begins_with("map="):
			_map_id = StringName(token.substr(4))
		elif token.begins_with("target="):
			_target_mode = token.substr(7)
	_tag = "HOST" if _is_host else "CLIENT"
	# ⚠️ BEFORE Main.tscn is instantiated — main.gd reads selected_map_scene() as
	# it builds the world, so setting it afterwards silently measures Eskinita
	# while claiming to measure the plaza (B-104's failure mode).
	GameLaunch.selected_map = _map_id

	var main: Node = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main

	await get_tree().create_timer(CONNECT_WAIT).timeout
	_report_layers()

	if _is_host:
		await _drive_throws()
		await get_tree().create_timer(HOST_LINGER).timeout
	else:
		# A client cannot drive a throw — host_throw() is host-only by design and
		# routing through carrier.gd's request RPC would still be resolved by the
		# host. It observes instead, and its observations are the evidence for
		# hypothesis A: the same throw, measured against this peer's own copy of
		# the world.
		await _observe_throws()

	_report()
	get_tree().quit(1 if _failures() > 0 else 0)

## ---------------------------------------------------------------------------
## HYPOTHESIS B, settled in one pass and then never thought about again.
##
## Printed rather than asserted: the numbers that matter are which layer each
## area emits into and which it listens on, and a mismatch is obvious on sight.
## ability_utils.gd hardcodes `collision_mask = 2` against CharacterBase.tscn's
## Hurtbox `collision_layer = 2`, and its own comment admits nobody had checked
## that against a running game.
## ---------------------------------------------------------------------------
func _report_layers() -> void:
	print("\n[%s] --- COLLISION LAYERS (hypothesis B) ---" % _tag)
	print("[%s]    map=%s  physics_fps=%d  my_peer_id=%d" % [
		_tag, _map_id, Engine.physics_ticks_per_second, multiplayer.get_unique_id()])
	for ch in _characters():
		var hurt := ch.get_node_or_null("Hurtbox") as Area3D
		var melee := ch.get_node_or_null("Hitbox") as Area3D
		if hurt == null or melee == null:
			continue
		# Authority is printed beside the layers because the two questions look
		# nothing alike and turned out to be the same investigation: a hurtbox on
		# the right layer belonging to a character whose authority never got
		# applied is just as unhittable as one on the wrong layer, and only this
		# line tells them apart. `sync_auth` is the MultiplayerSynchronizer's own,
		# which is what actually decides whose packets are accepted.
		var sync := ch.get_node_or_null("MultiplayerSynchronizer") as Node
		print("[%s]    %-12s person=%-5s can=%-5s auth=%-11d sync_auth=%-11d | hurtbox L=%d M=%d monitorable=%-5s | melee L=%d M=%d monitoring=%s" % [
			_tag, ch.name, str(ch.is_person), str(ch.is_can),
			ch.get_multiplayer_authority(),
			sync.get_multiplayer_authority() if sync != null else -1,
			hurt.collision_layer, hurt.collision_mask, str(hurt.monitorable),
			melee.collision_layer, melee.collision_mask, str(melee.monitoring)])

## ---------------------------------------------------------------------------
## The series. Everything below the aim point is the real code path: host_land,
## host_grab and host_throw are the same three functions carrier.gd calls, and
## the broadcast, the pulse hitbox, hitbox.gd's resolution and _apply_hit_result
## are untouched.
##
## The AIM POINT is supplied by the probe rather than read from a camera, and
## that is deliberate — aim is client-authoritative in the real game
## (carrier.gd::_aim_point) and is not what is under test. Aiming dead at the
## target's own hurtbox centre is the most favourable shot the game can produce,
## which is the point: if THAT misses, nothing about the report is subtle.
## ---------------------------------------------------------------------------
func _drive_throws() -> void:
	var attempts := 0
	while _records.size() < THROWS and attempts < THROWS * 6:
		attempts += 1
		# ⚠️ HARNESS AFFORDANCE, STATED OUT LOUD. Rounds end constantly here —
		# 90% of them end in a tag (Checklist Phase 9, RUN 3) — and a Bo5 would
		# finish long before 40 throws. Holding the win counts at zero keeps
		# rounds cycling; it touches no code path this probe measures (spawn,
		# reset, grab, throw and hit resolution all run exactly as they do in a
		# real match).
		MatchManager.team_a_wins = 0
		MatchManager.team_b_wins = 0
		if not RoundManager.round_active:
			await get_tree().create_timer(0.3).timeout
			continue
		var roles := _roles()
		var attacker: CharacterBase = roles.get("attacker")
		var slipper: CharacterBase = roles.get("slipper")
		var taya: CharacterBase = roles.get(_target_mode)
		if attacker == null or slipper == null or taya == null:
			await get_tree().create_timer(0.3).timeout
			continue
		var carriable := slipper.get_node_or_null("Carriable") as Carriable
		if carriable == null:
			await get_tree().create_timer(0.3).timeout
			continue

		# Put the slipper back in the attacker's hand through the real host-side
		# transitions. host_grab() has no proximity rule of its own (that lives in
		# carrier.gd::_find_grabbable, which is the client's half), so this works
		# whoever owns the attacker.
		carriable.host_land()
		await get_tree().physics_frame
		carriable.host_grab(attacker)
		await get_tree().physics_frame
		await get_tree().physics_frame
		if carriable.state != Carriable.CarryState.CARRIED:
			continue

		_begin_watch(slipper, taya)
		carriable.host_throw(taya.global_position, POWER)
		# ⚠️ RE-ARM AFTER THE THROW, NOT BEFORE. The pulse hitbox does not exist
		# until _rpc_set_flying runs inside host_throw. Arming before this line is
		# precisely the bug that made ai_probe report zero hits for every run it
		# ever recorded.
		_arm_hitboxes(slipper)
		if carriable.state != Carriable.CarryState.FLYING:
			_watching = false
			continue
		await get_tree().create_timer(FLIGHT_WATCH).timeout
		_end_watch()

		# Swap roles so the series covers a host-owned taya AND a remotely-owned
		# one. report_round_result(), NOT begin_next_round() — net_spawn_probe.gd
		# records at length why they are not interchangeable: `_reset_world()`
		# hangs off `round_intermission_started`, which only the former fires, so
		# calling the latter advances the counter and skips placement entirely.
		if _records.size() % THROWS_PER_ROUND == 0:
			MatchManager.report_round_result(_records.size() % (THROWS_PER_ROUND * 2) == 0)
			await get_tree().create_timer(MatchManager.INTERMISSION_DURATION + 1.0).timeout

## A client has no series of its own; it mirrors the host's by watching the
## slipper's carry state. Every peer runs _rpc_set_flying, so FLYING is observable
## here without a single extra message.
func _observe_throws() -> void:
	var deadline := Time.get_ticks_msec() + int((THROWS * 6 * 0.3 + THROWS * (FLIGHT_WATCH + 0.2)) * 1000.0)
	while _records.size() < THROWS and Time.get_ticks_msec() < deadline:
		var roles := _roles()
		var slipper: CharacterBase = roles.get("slipper")
		var taya: CharacterBase = roles.get(_target_mode)
		if slipper == null or taya == null:
			await get_tree().create_timer(0.1).timeout
			continue
		var carriable := slipper.get_node_or_null("Carriable") as Carriable
		if carriable == null or carriable.state != Carriable.CarryState.FLYING:
			await get_tree().physics_frame
			continue
		_begin_watch(slipper, taya)
		_arm_hitboxes(slipper)
		await get_tree().create_timer(FLIGHT_WATCH).timeout
		_end_watch()

## ---------------------------------------------------------------------------

func _begin_watch(slipper: CharacterBase, target: CharacterBase) -> void:
	_slipper = slipper
	_target = target
	_min_gap = INF
	_max_step = 0.0
	_last_pos = Vector3.INF
	_resolved_by = ""
	_target_left_normal = false
	_target_peak_state = CharacterBase.State.NORMAL
	_fall_lucky = false
	_was_downed = false
	_fall_count_before = -1
	_fall_count_after = -1
	_frames = 0
	_overlap_band = _capsule_radius(target) + _flight_hit_radius(slipper)
	_watching = true

func _end_watch() -> void:
	_watching = false
	if _target == null or _slipper == null:
		return
	var overlapped := _min_gap <= _overlap_band
	_records.append({
		"target": String(_target.name),
		"target_authority": _target.get_multiplayer_authority(),
		"target_is_remote": _target.get_multiplayer_authority() != multiplayer.get_unique_id(),
		"min_gap": _min_gap,
		"band": _overlap_band,
		"overlapped": overlapped,
		"resolved_by": _resolved_by,
		"resolved": _resolved_by != "",
		"downed": _target_left_normal,
		"peak_state": _target_peak_state,
		"downed_now": _was_downed,
		"lucky": _fall_lucky,
		"fall_delta": (_fall_count_after - _fall_count_before) if (_was_downed and _fall_count_before >= 0) else -99,
		"max_step": _max_step,
		"frames": _frames,
	})

func _physics_process(_delta: float) -> void:
	if not _watching or _slipper == null or _target == null:
		return
	if not is_instance_valid(_slipper) or not is_instance_valid(_target):
		return
	# THE TARGET'S STATE IS SAMPLED FOR THE WHOLE WATCH WINDOW, NOT ONLY THE
	# FLIGHT — and that distinction is not pedantry, it hid the answer once
	# already. A square hit ENDS the flight on the same frame it resolves
	# (move_and_collide contacts the body, host_land() runs), so a sampler that
	# stops when FLYING stops never observes the state the hit produced. The
	# first version of this probe reported "peak state: normal" for 40 out of 40
	# throws at the can, including ones that had demonstrably resolved a hit —
	# two numbers that could not both be true.
	if _target.state != CharacterBase.State.NORMAL:
		_target_left_normal = true
	_target_peak_state = maxi(_target_peak_state, int(_target.state))
	if _target.state == CharacterBase.State.DOWNED and not _was_downed:
		_was_downed = true
		_fall_lucky = not _target.last_fall_scored
		_fall_count_after = int(RoundManager.get("_fall_count"))
	elif not _was_downed:
		# Kept fresh every frame the target is still up, so it is the value from
		# the frame BEFORE the knockdown no matter which frame that turns out to be.
		_fall_count_before = int(RoundManager.get("_fall_count"))

	# ⚠️ THE SLIPPER'S GEOMETRY, by contrast, IS FLIGHT-ONLY. The first version of this function sampled the
	# whole FLIGHT_WATCH window and produced a largest-single-frame step of
	# 1.62 m — at 60 Hz that is 97 m/s, from a slipper whose fastest profile
	# launches at 26. Two numbers that cannot both be true, so the metric was the
	# bug: after a throw lands the slipper goes LOOSE, and the AI attacker runs
	# over and grabs it, at which point _step_carried() SNAPS it to the hand bone
	# in one frame. That snap is not flight and neither is the closest approach it
	# produces — a slipper lying next to the taya reads as a permanent near-miss.
	var carriable := _slipper.get_node_or_null("Carriable") as Carriable
	if carriable == null or carriable.state != Carriable.CarryState.FLYING:
		return
	_frames += 1
	var pos := _slipper.global_position
	if _last_pos != Vector3.INF:
		_max_step = maxf(_max_step, pos.distance_to(_last_pos))
	_last_pos = pos
	_min_gap = minf(_min_gap, _closest_approach(pos, _target))

## Exact distance from a point to a Hurtbox capsule's INNER SEGMENT. A sphere of
## radius r centred at `point` overlaps that capsule exactly when this is
## <= capsule_radius + r — no tolerance, no fudge, and it shares no code with the
## Area3D path it is used to check.
func _closest_approach(point: Vector3, target: CharacterBase) -> float:
	var hurt := target.get_node_or_null("Hurtbox/CollisionShape3D") as CollisionShape3D
	if hurt == null:
		return INF
	var capsule := hurt.shape as CapsuleShape3D
	if capsule == null:
		return INF
	var centre := hurt.global_position
	var up := hurt.global_transform.basis.y.normalized()
	# A CapsuleShape3D's `height` is the TOTAL height including both caps, so the
	# inner segment is (height - 2 * radius) long, centred on the shape's origin.
	var half_segment := maxf(0.0, capsule.height * 0.5 - capsule.radius)
	var a := centre - up * half_segment
	var b := centre + up * half_segment
	var ab := b - a
	var t := 0.0
	if ab.length_squared() > 0.0:
		t = clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return point.distance_to(a + ab * t)

func _capsule_radius(target: CharacterBase) -> float:
	var hurt := target.get_node_or_null("Hurtbox/CollisionShape3D") as CollisionShape3D
	var capsule := hurt.shape as CapsuleShape3D if hurt != null else null
	return capsule.radius if capsule != null else 0.0

## The radius of the pulse hitbox actually riding this throw, read off the live
## node rather than recomputed from the profile — so a mismatch between what the
## profile says and what was spawned shows up as a contradiction instead of being
## quietly assumed away.
func _flight_hit_radius(slipper: CharacterBase) -> float:
	for child in slipper.get_children():
		if not (child is Area3D) or not (child as Node).is_in_group("transient_hitbox"):
			continue
		var shape := (child as Area3D).get_node_or_null("CollisionShape3D") as CollisionShape3D
		var sphere := shape.shape as SphereShape3D if shape != null else null
		if sphere != null:
			return sphere.radius
	# Not spawned yet (armed before the throw broadcast) — fall back to the
	# profile so the band is never silently zero.
	var carriable := slipper.get_node_or_null("Carriable") as Carriable
	if carriable != null:
		return carriable._profile().hit_radius
	return 0.0

## Connects `landed_on` on BOTH hitboxes a thrown slipper carries — the scene's
## own melee Hitbox (live for the whole flight, see is_hitbox_active) and the
## per-throw pulse one. Attributing which resolved matters: the melee box on a
## tsinelas is radius 0.14 at a 0.16 offset and is not what a throw is meant to
## hit with.
func _arm_hitboxes(slipper: CharacterBase) -> void:
	var melee := slipper.get_node_or_null("Hitbox")
	if melee != null and not melee.landed_on.is_connected(_on_landed_melee):
		melee.landed_on.connect(_on_landed_melee)
	for child in slipper.get_children():
		if not (child is Area3D) or not (child as Node).is_in_group("transient_hitbox"):
			continue
		if not child.landed_on.is_connected(_on_landed_pulse):
			child.landed_on.connect(_on_landed_pulse)

func _on_landed_melee(target: CharacterBase) -> void:
	if _watching and target == _target:
		_resolved_by = "melee" if _resolved_by == "" else _resolved_by + "+melee"

func _on_landed_pulse(target: CharacterBase) -> void:
	if _watching and target == _target:
		_resolved_by = "pulse" if _resolved_by == "" else _resolved_by + "+pulse"

## ---------------------------------------------------------------------------

## STAGGERED and DOWNED are both "not NORMAL" and they are not the same event.
## Only DOWNED is the can actually going over, which is the whole of the human's
## "can the can even fall?" question, so the report names the state rather than
## printing a bool that cannot tell them apart.
func _state_name(s: int) -> String:
	match s:
		CharacterBase.State.NORMAL: return "normal"
		CharacterBase.State.STAGGERED: return "stagger"
		CharacterBase.State.DOWNED: return "DOWNED"
		CharacterBase.State.SEALED: return "SEALED"
	return "?"

func _characters() -> Array[CharacterBase]:
	var out: Array[CharacterBase] = []
	for node in get_tree().root.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch != null:
			out.append(ch)
	return out

## Whoever is playing each role RIGHT NOW. Re-derived every cycle rather than
## cached, for the same reason everything else in this codebase re-derives it:
## `is_can` and `team_is_can_side` both flip every round.
func _roles() -> Dictionary:
	var out: Dictionary = {}
	for ch in _characters():
		if ch.is_can:
			out["can"] = ch
		elif not ch.is_person:
			out["slipper"] = ch
		elif ch.team_is_can_side:
			out["taya"] = ch
		else:
			out["attacker"] = ch
	return out

## A throw that geometrically overlapped the target's hurtbox and produced no
## hit. That is the reported bug, stated as a predicate.
##
## ⚠️ THE HOST AND A CLIENT NEED DIFFERENT EVIDENCE, and conflating them is a
## harness fault that reads exactly like a game fault. `landed_on` fires where
## resolution happens, and resolution is host-only by design (hitbox.gd's
## NetworkManager gate) — so a client counting `resolved` scores 0 on a perfectly
## healthy build. The first four-peer run reported "37 THROWS PASSED THROUGH THE
## TARGET" on all three clients for precisely that reason, with `downed` true on
## every one of those same rows.
##
## What a client CAN see is the outcome: `_apply_hit_result` runs on the struck
## peer and `state` replicates from there, so the target leaving NORMAL is the
## client-side proof that the hit landed.
func _failures() -> int:
	var n := 0
	for r in _records:
		if not r["overlapped"]:
			continue
		if _is_host and not r["resolved"]:
			n += 1
		elif not _is_host and not r["downed"]:
			n += 1
	return n

func _report() -> void:
	print("\n[%s] === HIT REGISTRATION, %d throws, map=%s ===" % [
		_tag, _records.size(), _map_id])
	if _records.is_empty():
		print("[%s]    NO THROWS RECORDED — the harness never got a slipper into the air." % _tag)
		return
	print("[%s]    %-4s %-12s %-6s %-8s %-8s %-6s %-10s %-6s %s" % [
		_tag, "#", "target", "remote", "min_gap", "band", "ovlap", "resolved", "peak", "max_step"])
	for i in _records.size():
		var r: Dictionary = _records[i]
		print("[%s]    %-4d %-12s %-6s %8.3f %8.3f %-6s %-10s %-6s %.3f" % [
			_tag, i, r["target"], str(r["target_is_remote"]), r["min_gap"], r["band"],
			str(r["overlapped"]), (r["resolved_by"] if r["resolved"] else "-"),
			_state_name(r["peak_state"]), r["max_step"]])

	# "Landed" means resolved on the host and "the target left NORMAL" on a
	# client — see _failures() for why those cannot be the same test.
	var overlapped := 0
	var landed := 0
	var missed := 0            # overlapped and nothing happened — THE BUG
	var phantom := 0           # landed without ever overlapping — a LYING METRIC
	var local_overlapped := 0
	var local_missed := 0
	var remote_overlapped := 0
	var remote_missed := 0
	var worst_step := 0.0
	for r in _records:
		worst_step = maxf(worst_step, r["max_step"])
		var hit: bool = r["resolved"] if _is_host else r["downed"]
		if not r["overlapped"]:
			if hit:
				phantom += 1
			continue
		overlapped += 1
		if r["target_is_remote"]:
			remote_overlapped += 1
		else:
			local_overlapped += 1
		if hit:
			landed += 1
		else:
			missed += 1
			if r["target_is_remote"]:
				remote_missed += 1
			else:
				local_missed += 1

	var band_width: float = (_records[0]["band"] as float) * 2.0
	print("\n[%s]    throws                              : %d" % [_tag, _records.size()])
	print("[%s]    geometrically overlapped the target : %d" % [_tag, overlapped])
	print("[%s]    ... of which landed                 : %d" % [_tag, landed])
	print("[%s]    ... of which did NOT (THE BUG)      : %d" % [_tag, missed])
	# THE SPLIT THAT ANSWERS HYPOTHESIS A. If a locally-owned target is hit every
	# time and a remotely-owned one is not, the difference is replication lag and
	# nothing else — same code, same geometry, same frame budget.
	print("[%s]        target owned by THIS peer       : %d missed of %d overlaps" % [
		_tag, local_missed, local_overlapped])
	print("[%s]        target owned by ANOTHER peer    : %d missed of %d overlaps" % [
		_tag, remote_missed, remote_overlapped])
	print("[%s]    landed WITHOUT overlapping          : %d  (non-zero = the metric is wrong)" % [
		_tag, phantom])
	print("[%s]    largest single-frame slipper step   : %.3f m  (overlap band is %.3f m wide)" % [
		_tag, worst_step, band_width])
	if worst_step > band_width:
		print("[%s]    ⚠️ a single frame can step clean over the band — hypothesis C is live." % _tag)
	# THE LUCKY FALL'S ACCEPTANCE TEST. Two independent counts of the same event:
	# how many knockdowns the probe watched happen, and what RoundManager actually
	# charged the defence for. `falls - lucky` and `_fall_count` must agree, or the
	# flag is not reaching the scoring path.
	var falls := 0
	var lucky := 0
	for r in _records:
		if r.get("downed_now", false):
			falls += 1
			if r.get("lucky", false):
				lucky += 1
	if falls > 0:
		print("\n[%s]    knockdowns watched                  : %d" % [_tag, falls])
		print("[%s]    ... lucky (head/back, no point)     : %d  (LUCKY_FALL_CHANCE %.2f)" % [
			_tag, lucky, CharacterBase.LUCKY_FALL_CHANCE])
		print("[%s]    ... scoring                         : %d" % [_tag, falls - lucky])
		var bad := 0
		for r in _records:
			if not r.get("downed_now", false):
				continue
			var d: int = r.get("fall_delta", -99)
			if d == -99:
				continue # counter reset by a round boundary inside the window
			var want: int = 0 if r.get("lucky", false) else 1
			if d != want:
				bad += 1
				print("[%s]    *** fall_count moved by %d, wanted %d (lucky=%s) ***" % [
					_tag, d, want, str(r.get("lucky", false))])
		print("[%s]    fall_count delta wrong on           : %d of %d knockdowns" % [
			_tag, bad, falls])
	print("\n[%s] === %s ===" % [
		_tag, "EVERY OVERLAPPING THROW LANDED" if missed == 0 else "%d THROWS PASSED THROUGH THE TARGET" % missed])
