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

## ---------------------------------------------------------------------------
## B-144 · THE TWO GEOMETRY FAULTS THAT WERE BEING SCORED AS AIM ERROR.
## Measured with `-- range` (below); both fixes are the aim point, never the solve.
##
## ⚠️ 1. THE RAY RAN 40 m AND THE ARENA IS NOT THAT BIG. At +0.0 and +10.0 pitch
## it met a wall ~24 m out, so two of five rows audited a shot nobody in this game
## takes: the throwing line is z = -6.0, about six metres. Worse, those two rows
## were not even stable — the aim point MOVED 23.42 -> 23.89 m when the launch
## origin was raised to the sight line, because a higher eye raycasts further
## before it meets the wall, so the "before" and "after" of that merge were
## measured at different ranges and the 0.34 -> 0.41 regression compared two
## different questions.
##
## ⚠️ 2. A SLIPPER CANNOT OCCUPY A POINT ON A SURFACE, AND EVERY ROW AIMED AT ONE.
## The aim point was the raycast hit, i.e. a point ON the floor or ON the wall.
## The thrown tsinelas is a capsule with a real body, so its ORIGIN — which is
## what `closest approach` measures — stops one body radius short of any surface
## it flies into, forever, on a perfectly aimed throw. That offset is not aim
## error and `PASS_WITHIN` is not scaled for it: the mark is justified by the
## tightest shipped `hit_radius`, which is a question about hitting a CHARACTER
## in open space.
##
## What the solve actually does, aim points pinned in free space (`-- range`,
## 4 pitches x 7 ranges, wall-occluded and underground cells excluded):
##
##   worst at or inside 10 m : 0.205 m      worst out to 21 m : 0.224 m
##
## i.e. accurate to a fifth of a metre everywhere, with no range dependence left.
## The failing 0.41 m was the audit measuring the slipper's own body against the
## arena wall at 24 m. `PASS_WITHIN` is unchanged and stays absolute.
## ---------------------------------------------------------------------------

## How far out the audit is allowed to look for a target, in metres. Twice the
## throwing line's own six, so a genuinely long shot is still covered and a shot
## into the far wall is not.
const AUDIT_MAX_RANGE: float = 12.0
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
	# R-18(b) — a real two-peer ENet session. See _run_net().
	for arg in OS.get_cmdline_user_args():
		if String(arg) == "net":
			await _run_net()
			return
		if String(arg) == "range":
			await _run_range()
			return
	await _run_local()

## The closest a thrown tsinelas's ORIGIN can get to a flat surface, in metres —
## its own body capsule's largest half-extent, read off the live shape rather
## than restated from `character_base.gd::_COLLISION_BY_ROLE`. Measured 0.20 on
## the shipped tsinelas (radius 0.20, height 0.40).
func _slipper_clearance() -> float:
	var shape := (_slipper.get_node_or_null("CollisionShape3D") as CollisionShape3D)
	var capsule := shape.shape as CapsuleShape3D if shape != null else null
	if capsule == null:
		return 0.0
	return maxf(capsule.radius, capsule.height * 0.5)

## Brings up a local match and hands back the attacker's rig with both bots
## silenced. Shared by `_run_local()` and `_run_range()` so the two modes cannot
## drift into measuring different set-ups.
func _local_setup() -> CameraRig:
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
		return null
	# The bot would otherwise fight the probe for the same slipper.
	if _attacker.ai_controller != null:
		_attacker.ai_controller.set_enabled(false)
	if _slipper.ai_controller != null:
		_slipper.ai_controller.set_enabled(false)
	var rig := _attacker.get_node("CameraRig") as CameraRig
	rig.set_active(true)
	return rig

func _run_local() -> void:
	var rig := await _local_setup()
	if rig == null:
		get_tree().quit(1)
		return
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
		var far := camera.global_position + aim * AUDIT_MAX_RANGE
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, far)
		query.exclude = [_attacker.get_rid(), _slipper.get_rid()]
		var hit := space.intersect_ray(query)
		var aim_point: Vector3 = hit.get("position", far)
		# B-144, fault 2 — see the block at the top. Stand the aim point off the
		# surface by the thrown body's own radius so it is a point the slipper's
		# ORIGIN can actually reach. Read off the live shape, never restated.
		if not hit.is_empty():
			var normal: Vector3 = hit.get("normal", Vector3.UP)
			aim_point += normal * _slipper_clearance()

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

## ---------------------------------------------------------------------------
## B-144 · IS THE 0.41 m A SOLVE ERROR OR AN ARTEFACT OF THE AUDIT'S GEOMETRY?
## `godot --path . tools/aim_probe.tscn -- range`
##
## ⚠️ THE DEFAULT AUDIT'S ROWS ARE NOT LIKE-FOR-LIKE AND CANNOT ANSWER THIS.
## It aims at WHATEVER THE RAY HITS, so pitch and range move together and the
## range is not even stable between builds: +0.0 and +10.0 both land on a wall
## ~24 m out, and the aim point itself moved 23.42 -> 23.89 m when the launch
## origin was raised, because a higher eye raycasts further before it meets the
## wall. Two rows that differ in BOTH variables cannot attribute an error to
## either. This mode pins the aim point at a CHOSEN horizontal range along the
## same sight line, so range is the only thing that varies down a column.
##
## The band that matters is gameplay range: the throwing line is z = -6.0, i.e.
## about six metres of stand-off, and `phys_probe -- band` is flat 3/3 on the can
## out to a 0.30 m offset there.
const RANGE_PITCHES: Array[float] = [0.0, -10.0, -20.0, 10.0]
const RANGES: Array[float] = [3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 21.0]
## Aim points below this world height are not thrown at — the sight line is
## already under the floor there, so the row would measure nothing.
const RANGE_MIN_AIM_Y: float = 0.10

func _run_range() -> void:
	var rig := await _local_setup()
	if rig == null:
		get_tree().quit(1)
		return
	var camera := rig.fpp_camera as Camera3D
	var carriable := _slipper.get_node("Carriable") as Carriable
	var grid: Array[Dictionary] = []

	print("attacker %s   eye height %.2f above body origin"
		% [_attacker.global_position, camera.global_position.y - _attacker.global_position.y])

	for pitch in RANGE_PITCHES:
		for want_range in RANGES:
			carriable.host_land()
			_slipper.global_position = _attacker.global_position + Vector3(0.4, 0.3, 0)
			await get_tree().physics_frame
			carriable.host_grab(_attacker)
			await get_tree().physics_frame
			await get_tree().physics_frame
			rig.set("_pitch_deg", pitch)
			await get_tree().physics_frame

			var aim := -rig.get_aim_basis().z
			var eye := camera.global_position
			# HORIZONTAL range, so a row means the same distance at every pitch.
			var flat := Vector2(aim.x, aim.z).length()
			if flat < 0.01:
				continue
			var aim_point := eye + aim * (want_range / flat)
			if aim_point.y < RANGE_MIN_AIM_Y:
				grid.append({"pitch": pitch, "range": want_range, "closest": -1.0, "y": aim_point.y})
				continue
			# ⚠️ AN AIM POINT INSIDE THE WALL SCORES THE WALL, NOT THE SOLVE. The first
			# cut of this grid did not check, put a 24 m target ~0.5 m past the arena
			# wall at pitch 0, and duly reported 0.640 m of "error" for a slipper that
			# had simply stopped where the arena does.
			var space := _attacker.get_world_3d().direct_space_state
			var query := PhysicsRayQueryParameters3D.create(eye, aim_point)
			query.exclude = [_attacker.get_rid(), _slipper.get_rid()]
			var blocked := space.intersect_ray(query)
			if not blocked.is_empty():
				grid.append({"pitch": pitch, "range": want_range, "closest": -2.0, "y": aim_point.y})
				continue
			var origin := eye + aim * Carrier.MUZZLE_FORWARD
			carriable.host_throw(origin, aim_point, 1.0)
			var closest := 9999.0
			for _i in 400:
				await get_tree().physics_frame
				closest = minf(closest, _slipper.global_position.distance_to(aim_point))
				if carriable.state != Carriable.CarryState.FLYING:
					break
			grid.append({"pitch": pitch, "range": want_range, "closest": closest, "y": aim_point.y})
			print("  row pitch %+5.1f range %5.1f m  aim y %5.2f  closest %6.3f m"
				% [pitch, want_range, aim_point.y, closest])

	print("\n=== B-144 · CLOSEST APPROACH vs RANGE, pitch held (pass mark %.2f m) ===" % PASS_WITHIN)
	var header := "  pitch  "
	for want_range in RANGES:
		header += "%8.0f m" % want_range
	print(header)
	for pitch in RANGE_PITCHES:
		var line := "  %+5.1f  " % pitch
		for want_range in RANGES:
			var cell := "       -"
			for r in grid:
				if is_equal_approx(r["pitch"], pitch) and is_equal_approx(r["range"], want_range):
					if r["closest"] < -1.5:
						cell = "   wall "
					elif r["closest"] < 0.0:
						cell = "  under "
					else:
						cell = "  %6.3f" % r["closest"]
			line += cell + " "
		print(line)
	var worst_short := 0.0
	var worst_long := 0.0
	for r in grid:
		if r["closest"] < 0.0:
			continue
		if float(r["range"]) <= 10.0:
			worst_short = maxf(worst_short, r["closest"])
		else:
			worst_long = maxf(worst_long, r["closest"])
	print("  worst at or inside 10 m : %.3f m   (%s)"
		% [worst_short, "inside the mark" if worst_short <= PASS_WITHIN else "MISSES"])
	print("  worst beyond 10 m       : %.3f m   (%s)"
		% [worst_long, "inside the mark" if worst_long <= PASS_WITHIN else "MISSES"])
	get_tree().quit(0)

## ---------------------------------------------------------------------------
## R-18(b) · THE LUCKY FALL, ON TWO REAL PEERS. `-- net --host` / `-- net --join=IP`
##
## ⚠️ WHY THIS IS HERE AND NOT IN `hit_probe`, WHICH ALREADY HAS THE COLUMNS.
## `hit_probe.tscn` records `lucky` and `fall_delta` per throw and was written for
## exactly this. Run today on four real peers it reports **0 throws** and
## *"the harness never got a slipper into the air"*: a networked match no longer starts
## on its own. The multiplayer READY phase landed 2026-07-30 (`main.gd::
## _awaiting_net_ready` — the host counts PEERS, not characters) and nothing begins a
## round until every peer has sent `_rpc_declare_ready`. `hit_probe` waits on
## `RoundManager.round_active`, presses nothing, and spins out its attempt budget. That
## is a one-line fix in a file this lane does not own, so the measurement is taken here
## instead and the staleness is reported rather than worked around silently.
##
## ⚠️ WHAT "TWO PEERS AGREEING" CAN ACTUALLY MEAN, WHICH IS NOT WHAT IT LOOKS LIKE.
## `last_fall_scored` is written inside `_apply_hit_result`, and that is an `rpc_id` to
## the STRUCK character's own authority — so no peer OTHER THAN THE OWNER is ever told the
## flag. Comparing the flag on a can you do not own is therefore measuring nothing.
##
## ⚠️ AND THIS PARAGRAPH USED TO SAY "no OTHER peer is ever told the flag at all", WHICH
## READ ONE STEP TOO FAR AND COST A WHOLE FALSE FINDING. The owner is a peer too. For a
## client-owned lata the client IS the authority the `rpc_id` targets, so it is the one
## machine holding the applied result first-hand — and on the strength of that sentence
## `_physics_process` substituted a literal `true` for it and the run reported 0 lucky
## falls out of 28 at a pinned chance of 0.5. See the note at the substitution site.
##
## What every peer CAN see is the CONSEQUENCE, because `state` replicates from the
## authority outward through CharacterBase.tscn's synchronizer:
##
##     a SCORING fall  ->  DOWNED, then SEALED  (the window lapses and it auto-seals)
##     a LUCKY fall    ->  DOWNED, then NORMAL  (character_base.gd self-rights it)
##
## That is the stronger test anyway: it proves the OUTCOME of the host's roll crossed
## the wire and was applied identically, rather than proving a bool was copied. If the
## roll were ever made per-peer (the failure mode every note in this codebase warns
## about), the two sequences would diverge here and nowhere else.
##
## The host additionally checks its own two internal facts — `last_fall_scored` and the
## delta in `RoundManager._fall_count` — so a lucky fall that somehow still scored would
## be caught on the machine that decided it.
## ---------------------------------------------------------------------------

## Throws to drive. The can dodges, so only some connect; this is sized so ~15-20
## knockdowns happen inside one run.
const NET_THROWS: int = 60
const NET_CONNECT_WAIT: float = 5.0
## Seconds the host lingers after its last throw — when the host drops, every client
## tears its own match down and prints nothing.
const NET_LINGER: float = 6.0
## ⚠️ THE ROLL IS PINNED FOR THE RUN, AND THE SHIPPED 0.12 IS WHY. At one in eight, a
## run like this produces one or two lucky falls if it is fortunate, so "the peers
## agreed" would rest on a single sample and "no lucky fall was observed" would be
## indistinguishable from the feature being dead. At even odds both outcomes appear
## many times in one session and the comparison means something. Restored at the end.
const NET_LUCKY_CHANCE: float = 0.5

var _net_host := false
var _net_records: Array[Dictionary] = []
var _net_watch_can: CharacterBase = null
var _net_was_downed := false
var _net_fall_before := -1
var _net_tag := "?"

func _run_net() -> void:
	for arg in OS.get_cmdline_user_args():
		var token := String(arg)
		if token == "--host":
			_net_host = true
	_net_tag = "HOST" if _net_host else "CLIENT"

	# ⚠️ THE PROBE IS NOT THE CURRENT SCENE, and Main must live at /root/Main on every
	# peer — the spawner and the synchronizers address nodes by PATH. Same two reasons
	# net_spawn_probe.gd and hit_probe.gd both document at length.
	_main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	_main.name = "Main"
	get_tree().root.add_child.call_deferred(_main)
	await get_tree().process_frame
	get_tree().current_scene = _main
	await get_tree().create_timer(NET_CONNECT_WAIT).timeout

	# ⚠️ PRESS READY. This is the line hit_probe is missing.
	await _net_ready_up()

	if _net_host:
		# Pinned on the HOST ONLY, deliberately — the roll is host-side (hitbox.gd, past
		# the NetworkManager gate), so if a client's value mattered at all that would
		# itself be the bug. Leaving the clients at 0.12 is a free check on that.
		CharacterBase.lucky_fall_chance = NET_LUCKY_CHANCE
		# ⚠️ THE HOST'S DECISION, TAKEN FROM THE HOST'S OWN SIGNAL RATHER THAN INFERRED
		# FROM A COUNTER DELTA. The first version diffed `RoundManager._fall_count` either
		# side of the knockdown and read 0 for every scoring fall on a client-owned can —
		# because `hitbox.gd` counts the fall BEFORE it sends `_apply_hit_result`, so for a
		# remote can the counter has already moved by the time the replicated DOWNED
		# arrives. The delta was measuring replication lag, not the roll. A probe that
		# infers a decision from a side effect is measuring the side effect.
		RoundManager.can_fell.connect(_on_can_fell)
		print("[%s] lucky_fall_chance pinned to %.2f for this run (shipped is %.2f)"
			% [_net_tag, CharacterBase.lucky_fall_chance, CharacterBase.LUCKY_FALL_CHANCE])
		await _net_drive()
		CharacterBase.lucky_fall_chance = CharacterBase.LUCKY_FALL_CHANCE
		await get_tree().create_timer(NET_LINGER).timeout
	else:
		await _net_observe()
	_net_report()
	get_tree().quit(0)

## Sends READY until the host acknowledges the phase is over. Polled rather than
## signal-driven because `_awaiting_net_ready` is only set once the host's own
## `_rpc_ready_phase` arrives, which may be after this probe's first look.
func _net_ready_up() -> void:
	for attempt in 60:
		if not bool(_main.get("_awaiting_net_ready")):
			if RoundManager.round_active or bool(_main.get("_counting_down")):
				return
		else:
			_main._rpc_declare_ready.rpc_id(1)
		await get_tree().create_timer(0.5).timeout
		if RoundManager.round_active:
			return
	print("[%s] ⚠️ never reached a live round — the ready phase did not complete" % _net_tag)

## Host only. Buffered per can as a FIFO rather than applied to "the current record",
## because the roll and the replicated DOWNED it produces do not land on the same frame
## for a remotely-owned can — see the connect site.
var _rolls: Dictionary = {}

func _on_can_fell(fallen: CharacterBase, scored: bool) -> void:
	var key := String(fallen.name)
	if not _rolls.has(key):
		_rolls[key] = [] as Array[bool]
	(_rolls[key] as Array[bool]).append(scored)

func _take_roll(can_name: String) -> int:
	var queue: Array = _rolls.get(can_name, [])
	if queue.is_empty():
		return -1 # no roll seen for this knockdown — reported, never guessed
	return 1 if bool(queue.pop_front()) else 0

func _net_roles() -> Dictionary:
	var out: Dictionary = {}
	for node in get_tree().root.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch == null:
			continue
		if ch.is_can:
			out["can"] = ch
		elif not ch.is_person:
			out["slipper"] = ch
		elif ch.team_is_can_side:
			out["taya"] = ch
		else:
			out["attacker"] = ch
	return out

func _net_drive() -> void:
	var thrown := 0
	var attempts := 0
	while thrown < NET_THROWS and attempts < NET_THROWS * 6:
		attempts += 1
		# Rounds end constantly (a seal ends one outright), and a Bo5 would finish long
		# before 60 throws. Holding the win counts at zero keeps rounds cycling and
		# touches no path this probe measures — the same affordance hit_probe states out
		# loud for the same reason.
		MatchManager.team_a_wins = 0
		MatchManager.team_b_wins = 0
		if not RoundManager.round_active:
			await get_tree().create_timer(0.3).timeout
			continue
		var roles := _net_roles()
		var attacker: CharacterBase = roles.get("attacker")
		var slipper: CharacterBase = roles.get("slipper")
		var can: CharacterBase = roles.get("can")
		if attacker == null or slipper == null or can == null:
			await get_tree().create_timer(0.3).timeout
			continue
		var carriable := slipper.get_node_or_null("Carriable") as Carriable
		if carriable == null:
			await get_tree().create_timer(0.3).timeout
			continue
		carriable.host_land()
		await get_tree().physics_frame
		carriable.host_grab(attacker)
		await get_tree().physics_frame
		if carriable.state != Carriable.CarryState.CARRIED:
			continue
		_net_watch_can = can
		# ⚠️ SIGHT-LINE ORIGIN (10.6), same helper the production throw uses.
		var net_aim := can.global_position + Vector3(0.0, 0.25, 0.0)
		carriable.host_throw(Carrier.throw_origin_for(attacker, net_aim), net_aim, 1.0)
		thrown += 1
		# Long enough to cover the flight AND the whole self-right window, because the
		# outcome under test happens 1.25 s AFTER the knockdown, not at it.
		await get_tree().create_timer(CharacterBase.DOWNED_SELF_RIGHT_WINDOW + 0.9).timeout
	print("[%s] drove %d throws in %d attempts" % [_net_tag, thrown, attempts])

## A client cannot drive a throw (host_throw is host-only by design). It watches the
## same can and records the same outcomes off replicated state.
func _net_observe() -> void:
	var deadline := Time.get_ticks_msec() + int((NET_THROWS * 2.6 + 30.0) * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var roles := _net_roles()
		_net_watch_can = roles.get("can")
		await get_tree().physics_frame

## Runs on every peer. Records one entry per transition INTO Downed, then the state that
## knockdown RESOLVED to — which is the whole measurement.
func _physics_process(_delta: float) -> void:
	if _net_tag == "?" or _net_watch_can == null or not is_instance_valid(_net_watch_can):
		return
	var can := _net_watch_can
	if can.state == CharacterBase.State.DOWNED and not _net_was_downed:
		_net_was_downed = true
		# ⚠️⚠️ THE FLAG IS READ IFF THIS PEER OWNS THE CAN, AND THE OLD CONDITION WAS
		# `if _net_host else true`. THAT `true` IS A CONSTANT, NOT A MEASUREMENT, and it
		# is the entire "downed_lucky does not apply on a remote peer" finding.
		#
		# `_net_host` is the wrong question. `_apply_hit_result` is an `rpc_id` to
		# `target.get_multiplayer_authority()`, so the peer that is told the kind is the
		# peer that OWNS the can — which for a client-owned lata is the CLIENT, not the
		# host. The client was therefore the one peer with first-hand evidence, and the
		# harness threw it away and substituted `true`; the classifier below then read
		# that constant back out through `mark = "L" if not flag_scored else "S"` and
		# could only ever print S. 0 lucky out of 28 at a pinned chance of 0.5 is
		# p ≈ 3.7e-9 — an impossible number, and the metric was the bug.
		#
		# The header's claim that "no other peer is ever told the flag" is true and was
		# read one step too far: not-told applies to peers that do NOT own the can (the
		# host looking at a client's lata, and vice versa). `flag_known` now carries that
		# distinction explicitly instead of leaving a stale default to stand in for it.
		var mine := can.get_multiplayer_authority() == multiplayer.get_unique_id()
		_net_records.append({
			"round": MatchManager.round_number,
			"can": String(can.name),
			"flag_scored": can.last_fall_scored if mine else true,
			"flag_known": mine,
			"fall_delta": -99,
			"mine": mine,
			"resolved": "?",
		})
		if _net_host:
			_net_records[-1]["fall_delta"] = _take_roll(String(can.name))
	elif can.state != CharacterBase.State.DOWNED and _net_was_downed:
		_net_was_downed = false
		if not _net_records.is_empty() and _net_records[-1]["resolved"] == "?":
			match can.state:
				CharacterBase.State.NORMAL: _net_records[-1]["resolved"] = "up"
				CharacterBase.State.SEALED: _net_records[-1]["resolved"] = "sealed"
				_: _net_records[-1]["resolved"] = "reset"
	elif not _net_was_downed and _net_host:
		# Kept fresh every frame the can is up, so it is the value from the frame BEFORE
		# the knockdown whichever frame that turns out to be.
		_net_fall_before = int(RoundManager.get("_fall_count"))

## ⚠️⚠️ THE CLASSIFIER IS THE FLAG, NOT THE STATE THE CAN ENDED IN. THE FIRST VERSION
## USED THE STATE AND WAS WRONG ABOUT 26 ROWS OUT OF 33.
##
## "DOWNED then NORMAL" is not "a lucky fall". A can gets back up by FOUR different
## routes and only one of them is the feature under test: the lucky-fall self-right, its
## OWN bump self-right inside DOWNED_SELF_RIGHT_WINDOW (which is what the whole "too
## easy for the lata to get back up" pass was about), Quick Stand, and the taya's reset
## channel. Reading the outcome state therefore counted every recovery as lucky, and the
## run reported 33 lucky falls out of 33 knockdowns at a pinned chance of 0.5 — a number
## that cannot be true, which is what exposed it.
##
## What actually identifies the roll:
##   * on the peer that OWNS the can, `last_fall_scored`, written by `_apply_hit_result`
##     from the kind the host sent. This is the applied result.
##   * on the HOST, the delta in `RoundManager._fall_count` across the knockdown: 0 for a
##     lucky fall, 1 for a scoring one. This is the consequence the host acted on.
## Those two are on different machines and must agree. That IS the cross-peer test.
func _net_report() -> void:
	print("\n[%s] === THE LUCKY FALL ON A REAL PEER, %d knockdowns ==="
		% [_net_tag, _net_records.size()])
	var lucky := 0
	var scored := 0
	var seq := ""
	# ⚠️ THE HOST'S OWN WITHIN-MACHINE CHECK, on the knockdowns where the host owns the can
	# and therefore holds BOTH facts: the roll it made (`can_fell`) and the flag
	# `_apply_hit_result` wrote locally through `call_local`. Those cannot legitimately
	# disagree on one machine, so a non-zero count here is a bug in the mechanic itself and
	# not in the wire — which is exactly the half of the question a cross-peer diff cannot
	# answer.
	var self_checked := 0
	var self_mismatch := 0
	for i in _net_records.size():
		var r: Dictionary = _net_records[i]
		# One character per knockdown, in flight order, so the two logs line up index for
		# index: L / S from whichever evidence THIS peer legitimately has, '.' where this
		# peer has none (it does not own the can and is not the host).
		var mark := "."
		var flag_known := bool(r.get("flag_known", false))
		var flag_mark := "?"
		if flag_known:
			flag_mark = "S" if bool(r["flag_scored"]) else "L"
		if _net_host:
			# `fall_delta` now carries the host's ROLL: 0 lucky, 1 scoring, -1 none seen.
			var d: int = int(r["fall_delta"])
			if d == 0:
				mark = "L"
			elif d == 1:
				mark = "S"
			if flag_known and mark != ".":
				self_checked += 1
				if flag_mark != mark:
					self_mismatch += 1
		elif flag_known:
			mark = flag_mark
		if mark == "L":
			lucky += 1
		elif mark == "S":
			scored += 1
		seq += mark
		print("[%s]   %-3d round %-2d %-12s mine=%-5s flag=%-4s fall_delta=%-4d ended=%-6s -> %s"
			% [_net_tag, i, r["round"], r["can"], str(r["mine"]),
				flag_mark if flag_known else "n/a",
				int(r["fall_delta"]), r["resolved"], mark])
	print("[%s]   lucky (no point) : %d" % [_net_tag, lucky])
	print("[%s]   scoring          : %d" % [_net_tag, scored])
	if _net_host:
		print("[%s]   host-owned rows where the roll and the applied flag agree: %d/%d%s"
			% [_net_tag, self_checked - self_mismatch, self_checked,
				"" if self_mismatch == 0 else "   *** %d DISAGREE ***" % self_mismatch])
	# ⚠️ THE CROSS-PEER COMPARISON IS THIS ONE LINE. Diff it between the two logs. Every
	# position where BOTH peers printed a letter must carry the SAME letter: that is the
	# host's roll and the owning peer's applied result agreeing on the same hit. A '.' is
	# "this peer has no evidence about that one", not a disagreement.
	#
	# ⚠️⚠️ ALIGN BY SUFFIX, NOT BY INDEX 0, AND FILTER TO ONE CAN FIRST. The two peers do
	# NOT record the same number of knockdowns and that is not a fault: the host begins
	# driving as soon as its own ready-up returns, while a client's `_net_watch_can` is not
	# assigned until `_net_observe()` starts, so the client legitimately misses the first
	# knockdown or two. Measured 2026-07-30: host 42 rows, client 39, and on the
	# client-owned can specifically 21 against 19.
	#
	# So: grep both logs for the SAME can name, take the mark column, and align the
	# shorter sequence to the END of the longer. That alignment is checkable rather than
	# assumed — sliding the 19-long client sequence along the 21-long host one scored
	# 11, 12 and 19 agreements at offsets 0, 1 and 2, so the correct offset is the unique
	# maximum and not a choice. At it, agreement was 19/19.
	print("[%s]   OUTCOME-SEQ: %s   (%d rows; align by SUFFIX per can — see the note)"
		% [_net_tag, seq, _net_records.size()])
## ---------------------------------------------------------------------------
## 10.6 · THE SAG METRIC, merged 2026-07-30 from `code/throw-feel`. Nothing above
## conflicts with it — the R-18(b) net section and this measure different things and
## landed on different branches; both are kept in full.
## ---------------------------------------------------------------------------

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
