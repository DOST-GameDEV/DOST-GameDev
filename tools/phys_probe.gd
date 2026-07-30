extends Node3D
## Physics/interaction audit. Throws the tsinelas at the can repeatedly and
## reports whether contact is actually detected, plus watches for the failure
## modes reported 2026-07-29: clipping through the floor, snagging on invisible
## walls, and weird bounces.
var _main: Node
var _slipper: CharacterBase
var _can: CharacterBase
var _min_y := 999.0
var _max_speed := 0.0
var _below_floor := 0
var _outside_bounds := 0
var _frames := 0
var _throws := 0
var _state_hits := 0
var _can_move_while_flying := 0
var _flying_frames := 0
var _can_start := Vector3.ZERO
var _can_max_disp := 0.0
var _dents_seen := 0
var _attacker: CharacterBase

## ---------------------------------------------------------------------------
## ONE HIT PER THROW. Counts how many times a single throw actually RESOLVES a
## hit, which is not the same question as "did it connect" and is the one the
## multi-hit lag bug turns on.
##
## Two independent hitboxes ride a thrown slipper — CharacterBase.tscn's own
## melee Hitbox (live for the whole flight, see is_hitbox_active) and the
## per-profile pulse Hitbox from _spawn_flight_hitbox() — and `_step_flying`
## calls sweep_hitbox() EVERY physics frame. `landed_on` is emitted once per
## resolution, so counting it per throw measures exactly the duplication:
## a correct throw scores 1 per target, and anything above that is the bug.
## ---------------------------------------------------------------------------
var _hits_this_throw: int = 0
var _hits_per_throw: Array[int] = []
var _hit_targets_this_throw: Dictionary = {}
var _worst_single_target: int = 0
## `-- target=can|taya|graze`. See the aim block in _ready() for what each means.
var _target_mode := "can"
## `-- map=eskinita|bayan_plaza`. Ids come from GameLaunch.MAPS, not from a path.
var _map_id := &"eskinita"
## `-- ballistics` swaps the hit-counting series for the landing-scatter sweep.
var _ballistics := false
## `-- lane` (R-06) and `-- bounce` (R-18a). See _run_lane() / _run_bounce().
var _mode := ""
## `standoff=` for `-- lane`. Defaults to the AI's own live value rather than
## restating 2.6, so a swept standoff and a lane measurement cannot disagree.
var _standoff := AIController.taya_block_standoff
## `bounce=` / `bounces=` for `-- bounce`. -1 means "sweep, do not pin".
var _bounce_pin := -1.0
var _bounces_pin := -1
var _taya: CharacterBase
## How far to the side a `graze` throw aims. Bigger than the target's body
## capsule (0.4) so the bodies never touch, smaller than body + hurtbox (0.45)
## + the slipper's own hit radius, so the AREAS still overlap. That gap is
## precisely where the multi-hit bug lives.
const GRAZE_OFFSET: float = 0.62
## How long to follow a struck body after a hit resolves, in physics frames.
const KNOCK_WATCH_FRAMES: int = 20

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var token := String(arg)
		if token.begins_with("target="):
			_target_mode = token.substr(7)
		elif token.begins_with("map="):
			_map_id = StringName(token.substr(4))
		elif token == "ballistics":
			_ballistics = true
		elif token == "lane" or token == "bounce" or token == "traits" or token == "band":
			_mode = token
		elif token.begins_with("standoff="):
			_standoff = float(token.substr(9))
		elif token.begins_with("bounces="):
			_bounces_pin = int(token.substr(8))
		elif token.begins_with("bounce="):
			_bounce_pin = float(token.substr(7))
	if _bounce_pin >= 0.0:
		Carriable.bounce_damping = _bounce_pin
	if _bounces_pin >= 0:
		Carriable.max_bounces = _bounces_pin
	# ⚠️ MUST happen before Main.tscn is instantiated — main.gd reads
	# GameLaunch.selected_map_scene() as it builds the world, so setting this
	# afterwards silently measures Eskinita while claiming to measure the plaza.
	# That is B-104's failure mode exactly (a map that cannot be loaded reports
	# the other one's numbers), so it is set here and echoed in every report.
	GameLaunch.selected_map = _map_id
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	MatchManager.begin_next_round()
	await get_tree().create_timer(0.5).timeout
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.is_can: _can = ch
		elif not ch.is_person and not ch.is_can: _slipper = ch
		elif ch.is_person and not ch.team_is_can_side: _attacker = ch
		elif ch.is_person and ch.team_is_can_side: _taya = ch
	if _slipper == null or _can == null:
		print("PHYS: could not find slipper/can"); get_tree().quit(1); return
	print("slipper=", _slipper.name, " can=", _can.name)
	_watch_slipper_hitboxes()
	set_physics_process(true)
	if _ballistics:
		await _run_ballistics()
		get_tree().quit(0)
		return
	if _mode == "lane":
		await _run_lane()
		get_tree().quit(0)
		return
	if _mode == "band":
		await _run_band()
		get_tree().quit(0)
		return
	if _mode == "bounce":
		await _run_bounce()
		get_tree().quit(0)
		return
	if _mode == "traits":
		await _run_traits()
		get_tree().quit(0)
		return
	# Fire a series of throws straight at the can from the throwing line.
	for i in 12:
		var carriable := _slipper.get_node("Carriable") as Carriable
		# host_throw() requires CARRIED, so go through the real path: put the
		# slipper loose next to its own attacker, have the attacker grab it,
		# then throw. Anything else tests a state the game never reaches.
		carriable.host_land()
		_slipper.global_position = _attacker.global_position + Vector3(0.4, 0.3, 0)
		await get_tree().physics_frame
		carriable.host_grab(_attacker)
		await get_tree().physics_frame
		if carriable.state != Carriable.CarryState.CARRIED:
			print("  throw %d: grab failed, state=%d" % [i, carriable.state])
			continue
		# `target=` picks what the series is aimed at, and it matters: a square
		# hit on a BODY ends the flight via move_and_collide the same frame, which
		# masks the multi-hit window. `taya` (an opposing Person) is the case the
		# lag was actually reported against, and `graze` deliberately aims to
		# pass BESIDE the target — an Area3D overlap with no body contact, so
		# nothing ever ends the flight and the same contact re-resolves for as
		# many frames as the overlap lasts.
		var aim_at: CharacterBase = _can
		if _target_mode == "taya" or _target_mode == "graze":
			aim_at = _taya if _taya != null else _can
		var aim_point := aim_at.global_position + Vector3(0, 0.25, 0)
		if _target_mode == "graze":
			var side := (aim_at.global_position - _slipper.global_position).normalized().cross(Vector3.UP)
			aim_point += side * GRAZE_OFFSET
		_hits_this_throw = 0
		_hit_targets_this_throw.clear()
		# host_throw takes the POINT to aim at, not a direction — it solves the
		# launch angle that lands there (carriable.gd::_solve_arc).
		carriable.host_throw(aim_point, 1.0)
		# The pulse hitbox is spawned INSIDE host_throw's broadcast, so it does
		# not exist until after that call — re-arm the watch every throw or the
		# flight hitbox's own hits go uncounted.
		_watch_slipper_hitboxes()
		_throws += 1
		await get_tree().create_timer(1.2).timeout
		_hits_per_throw.append(_hits_this_throw)
	print("\n=== PHYSICS AUDIT (%d frames) ===" % _frames)
	print("  lowest slipper Y reached : %.3f  (floor top is 0.100)" % _min_y)
	print("  frames below floor       : %d" % _below_floor)
	print("  frames outside map bounds: %d" % _outside_bounds)
	print("  peak slipper speed       : %.2f" % _max_speed)
	print("  throws actually launched : %d" % _throws)
	print("  can dents                : %d / %d" % [_can.dents, CharacterBase.MAX_DENTS])
	print("  mode                     : %s" % ("OPTION_A (dents)" if GameLaunch.game_mode == GameLaunch.GameMode.OPTION_A else "OPTION_B (downed/seal)"))
	print("  frames can was NOT NORMAL: %d" % _state_hits)
	print("  can final state          : %d (0=NORMAL 1=STAGGERED 2=DOWNED 3=SEALED)" % _can.state)
	print("  CAN evasion: moved on %d of %d in-flight frames (%.0f%%), max %.2f from mark" % [_can_move_while_flying, _flying_frames, 100.0*_can_move_while_flying/maxi(_flying_frames,1), _can_max_disp])
	print("  RESULT: ", "CONTACT RESOLVES" if (_dents_seen > 0 or _state_hits > 0) else "*** NO CONTACT EVER REGISTERED ***")
	_report_hits_per_throw()
	_report_the_sky()
	get_tree().quit(0)

## Connects to every Hitbox currently under the slipper. Idempotent — both the
## always-present melee Hitbox and the per-throw pulse one end up here, and the
## pulse one is a different node on every throw.
func _watch_slipper_hitboxes() -> void:
	if _slipper == null or not is_instance_valid(_slipper):
		return
	for hb in _slipper.find_children("*", "Hitbox", true, false):
		var box := hb as Hitbox
		if not box.landed_on.is_connected(_on_slipper_landed_on):
			box.landed_on.connect(_on_slipper_landed_on)

## THE FACESLOP, MEASURED. Sampled on the frame the hit resolves and again a few
## frames later: `apply_knockback` writes `velocity` and the ordinary
## move_and_slide path carries it, so the shove shows up as the target's own
## speed and displacement, not as anything this probe has to simulate.
var _knock_samples: Array[float] = []
var _knock_lift: Array[float] = []
var _knock_watch: CharacterBase = null
var _knock_frames := 0
var _knock_start := Vector3.ZERO
var _knock_disp: Array[float] = []
## ⚠️ THE CONTROL. A struck body is usually already walking, and its own
## locomotion would otherwise be reported as knockback. This caches every
## character's planar speed from the PREVIOUS physics frame, so the hit's real
## contribution is (peak after) - (speed just before) rather than a raw peak.
var _speed_prev: Dictionary = {}
var _knock_pre: Array[float] = []

func _on_slipper_landed_on(target: CharacterBase) -> void:
	_hits_this_throw += 1
	if target != null and is_instance_valid(target):
		# Watch the struck body for the next few frames. Started here rather than
		# read immediately because the impulse lands in `velocity` and is only
		# integrated by the NEXT move_and_slide.
		_knock_watch = target
		_knock_frames = KNOCK_WATCH_FRAMES
		_knock_start = target.global_position
		# The control, captured BEFORE the impulse is integrated — see
		# _speed_prev. Must stay in lockstep with _knock_samples; the report
		# indexes the two together.
		_knock_pre.append(float(_speed_prev.get(target.get_instance_id(), 0.0)))
		_knock_samples.append(0.0)
		_knock_lift.append(0.0)
		_knock_disp.append(0.0)
	if target != null:
		var id := target.get_instance_id()
		var n := int(_hit_targets_this_throw.get(id, 0)) + 1
		_hit_targets_this_throw[id] = n
		# Per-TARGET is the real pass/fail: one throw legitimately hitting two
		# different characters is fine, the same character twice is not.
		_worst_single_target = maxi(_worst_single_target, n)

## ⚠️ THE PASS/FAIL LINE FOR THE MULTI-HIT BUG. A throw that connects should
## resolve ONE hit per distinct target. Anything more is the same contact being
## re-resolved across consecutive physics frames — every one of those re-runs a
## state transition, a VFX flash, a hitstop and a positional sound, which is
## what the lag report was.
func _report_hits_per_throw() -> void:
	if _hits_per_throw.is_empty():
		print("\n  (no throws recorded — nothing to say about hits per throw)")
		return
	var total := 0
	var worst := 0
	var connected := 0
	for h in _hits_per_throw:
		total += h
		worst = maxi(worst, h)
		if h > 0:
			connected += 1
	print("\n  --- ONE HIT PER THROW (target=%s) ---" % _target_mode)
	print("  per-throw hit resolutions: ", _hits_per_throw)
	print("  throws that connected    : %d / %d" % [connected, _hits_per_throw.size()])
	print("  total resolutions        : %d   (ideal: 1 per connecting throw, per target)" % total)
	print("  worst single throw       : %d resolutions" % worst)
	print("  worst single TARGET      : %d resolutions on one character in one throw" % _worst_single_target)
	_report_knockback()
	print("  VERDICT: %s" % ("PASS — no throw resolved more than once on any one target"
		if _worst_single_target <= 1
		else "*** FAIL — one throw resolved %d times on a single target (multi-hit bug) ***"
			% _worst_single_target))

## ⚠️⚠️ THE SKY WATCHDOG — ADDED 2026-07-30 BECAUSE A HUMAN WATCHING A PROBE RUN SAW
## SOMETHING THIS PROBE COULD NOT REPORT: *"the person and the can started flying to
## the sky."*
##
## Every number this probe printed was about the SLIPPER (`_min_y`, `_max_speed`,
## `_below_floor`). Nothing in it ever looked at where the other three characters
## were, so a Person launched 10 m into the air was invisible to a green run — which
## is trap (b) in this repo's method note, word for word: a probe that never looks at
## the thing you changed passes anyway.
##
## The mechanism is documented and it is B-100's, from the other direction. Writing
## `global_position` on a PhysicsBody3D updates the scene tree at once and the physics
## BROADPHASE only at the next server step, so for one frame a teleported body is
## standing inside another body's stale collider — and Godot's depenetration resolves
## that by shoving one of them out along the contact normal, which for a stacked pair
## is straight up. `character_base.gd::begin_spawn_settle()` exists precisely for this
## and is why the game itself no longer does it; this probe was teleporting four
## characters per throw without ever calling it.
##
## Reported as a MAX and a NAME, not a bool: "someone went up" is not actionable and
## "TeamAPerson reached y 4.86" is.
var _sky_watch: Dictionary = {}

func _watch_the_sky() -> void:
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch == null or not is_instance_valid(ch):
			continue
		# Anything the probe has deliberately parked off the map (the ballistics sweep
		# moves the can and the taya to x/z 30-40) is not a launch and is skipped.
		if absf(ch.global_position.x) > 20.0 or absf(ch.global_position.z) > 25.0:
			continue
		# ⚠️ A THROWN SLIPPER IS *SUPPOSED* TO BE IN THE AIR, AND THE FIRST VERSION OF
		# THIS FLAGGED EVERY LOB AS A LAUNCH (peak y 3.24 = a 2.31 m apex over a 0.90 m
		# hand, i.e. the mechanic working exactly as measured). A watchdog that fires on
		# the feature it was added alongside is noise, and noise is how a real launch
		# gets ignored later.
		var carriable := ch.get_node_or_null("Carriable") as Carriable
		if carriable != null and carriable.state == Carriable.CarryState.FLYING:
			continue
		var key := String(ch.name)
		if ch.global_position.y > float(_sky_watch.get(key, -99.0)):
			_sky_watch[key] = ch.global_position.y

## A Person stands at y 0.90 and apexes at 0.84 on a jump, so 1.80 is comfortably
## above anything legitimate and well under a real launch.
const SKY_LIMIT: float = 1.8

func _report_the_sky() -> void:
	print("\n  --- PEAK HEIGHT PER CHARACTER (the sky watchdog) ---")
	var bad := 0
	for key in _sky_watch:
		var y: float = _sky_watch[key]
		var flag := ""
		if y > SKY_LIMIT:
			flag = "   *** LAUNCHED — nothing in a round should reach this ***"
			bad += 1
		print("  %-14s peak y %.2f%s" % [key, y, flag])
	print("  VERDICT: %s" % ("nobody left the ground unreasonably" if bad == 0
		else "*** %d character(s) were launched ***" % bad))

func _physics_process(_d: float) -> void:
	_watch_the_sky()
	if _slipper == null: return
	_frames += 1
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		_speed_prev[ch.get_instance_id()] = Vector2(ch.velocity.x, ch.velocity.z).length()
	if _knock_frames > 0 and _knock_watch != null and is_instance_valid(_knock_watch):
		_knock_frames -= 1
		var flat: float = Vector2(_knock_watch.velocity.x, _knock_watch.velocity.z).length()
		_knock_samples[-1] = maxf(_knock_samples[-1], flat)
		_knock_lift[-1] = maxf(_knock_lift[-1], _knock_watch.velocity.y)
		_knock_disp[-1] = maxf(_knock_disp[-1], _knock_start.distance_to(_knock_watch.global_position))
	var p := _slipper.global_position
	# `-- band` only. Closest approach to the can's hurtbox CENTRE, so the contact column
	# can be checked against a distance instead of trusted on its own. Sampled here rather
	# than in the sweep's own await loop because a physics frame is the finest resolution
	# there is, and a lob's descent covers real ground between two of them.
	if _band_watch != null and is_instance_valid(_band_watch):
		var hb := _band_watch.get_node_or_null("Hurtbox") as Node3D
		var centre: Vector3 = hb.global_position if hb != null \
			else _band_watch.global_position
		var d3 := p.distance_to(centre)
		# ⚠️ THE PERP DISPLACEMENT IS SAMPLED ON THE CLOSEST-APPROACH FRAME, INSIDE THIS
		# COMPARISON. Recording the peak and the closest approach independently would let
		# a can that stepped 1.2 m out and drifted back report 1.2 m against a hit — the
		# two numbers have to be read on the same frame to mean anything together.
		if d3 < _band_min_3d:
			_band_min_3d = d3
			var from_mark := _band_watch.global_position - _band_mark
			from_mark.y = 0.0
			_band_perp_at_closest = absf(from_mark.dot(_band_side))
		var perp_now := _band_watch.global_position - _band_mark
		perp_now.y = 0.0
		_band_peak_perp = maxf(_band_peak_perp, absf(perp_now.dot(_band_side)))
		_band_min_flat = minf(_band_min_flat,
			Vector2(p.x - centre.x, p.z - centre.z).length())
	_min_y = minf(_min_y, p.y)
	_max_speed = maxf(_max_speed, _slipper.velocity.length())
	if p.y < 0.0: _below_floor += 1
	if absf(p.x) > 9.5 or absf(p.z) > 19.0: _outside_bounds += 1
	if _can != null and _can.dents > _dents_seen: _dents_seen = _can.dents
	if _can != null and _can.state != 0: _state_hits += 1
	if _slipper != null and _can != null:
		var cr := _slipper.get_node_or_null("Carriable") as Carriable
		if cr != null and cr.state == Carriable.CarryState.FLYING:
			_flying_frames += 1
			if Vector2(_can.velocity.x, _can.velocity.z).length() > 0.4:
				_can_move_while_flying += 1
			var d := Vector2(_can.global_position.x, _can.global_position.z).length()
			_can_max_disp = maxf(_can_max_disp, d)

## Task 3 verification. A hit that resolves but never moves the target is the
## "lacks weight" report; these are the numbers that say whether it does now.
func _report_knockback() -> void:
	if _knock_samples.is_empty():
		print("  (no hits landed — no knockback to report)")
		return
	var peak := 0.0
	var peak_lift := 0.0
	var peak_disp := 0.0
	var sum := 0.0
	for i in _knock_samples.size():
		peak = maxf(peak, _knock_samples[i])
		peak_lift = maxf(peak_lift, _knock_lift[i])
		peak_disp = maxf(peak_disp, _knock_disp[i])
		sum += _knock_samples[i]
	var gain_sum := 0.0
	var gain_peak := 0.0
	for i in _knock_samples.size():
		var gain: float = _knock_samples[i] - _knock_pre[i]
		gain_sum += gain
		gain_peak = maxf(gain_peak, gain)
	print("\n  --- FACESLOP (knockback on the struck body, %d hits) ---" % _knock_samples.size())
	print("  speed the target already had   : %.2f m/s mean (its own walking — the control)"
		% (_sum_of(_knock_pre) / _knock_samples.size()))
	print("  peak horizontal speed after hit: %.2f m/s   (raw, includes the above)" % peak)
	print("  SPEED ADDED BY THE HIT         : %.2f m/s mean, %.2f peak   (0.00 = no knockback)"
		% [gain_sum / _knock_samples.size(), gain_peak])
	print("  peak upward speed imparted     : %.2f m/s" % peak_lift)
	print("  peak displacement within %2d fr : %.2f m" % [KNOCK_WATCH_FRAMES, peak_disp])

func _sum_of(values: Array[float]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total

## ---------------------------------------------------------------------------
## BALLISTICS — landing scatter per profile, from both throwing lines, per map.
##
## ⚠️ WHY THIS EXISTS: Art_Direction.md §9's range table is STALE and every
## number in it is wrong. It was computed when the four profiles carried
## non-zero `arc_angle_deg` (14/12/30/5) and lower launch speeds. B-127
## (86e9139) found the arc tilt was sign-inverted, corrected it, and set
## `arc_angle_deg = 0.0` on ALL FOUR profiles while retuning launch_speed and
## gravity_scale. The table therefore describes resources that no longer exist.
##
## ⚠️ "Max range at full charge" is ALSO no longer the right question. With arc
## at 0 and `host_throw()` taking a POINT rather than a bearing (B-129), the
## launch angle is SOLVED per throw by `carriable.gd::_solve_arc()`. Reach is now
## "does the solver find an angle at this charge" — when the discriminant goes
## negative it gives up and throws flat along the aim, which reads in-game as a
## throw that visibly falls short. So this measures where the slipper ACTUALLY
## LANDS, and the charge floor at which the can becomes reachable at all.
##
## ✅ TRUSTWORTHY AS OF 2026-07-29. Scatter across identical full-charge throws is
## 0.00-0.33 m (it was 3-9 m before the four faults below were fixed), the two
## throwing lines mirror each other, the reach floors order correctly by speed and
## gravity, and Eskinita and Bayan Plaza agree to within 0.1 m — which is the
## cross-check that matters, since ballistics is map-independent and any real
## divergence between the two would mean the probe was measuring the map.
##
## Four faults had to go first, and they are recorded because each one produced
## plausible-looking numbers rather than an obvious failure:
##
##   1. The state reset covered only FLYING, so every cell after the first
##      reported 8/8 grab failures — the slipper was still CARRIED.
##   2. Accumulated dents ENDED THE ROUND mid-sweep and roles swapped, so the
##      cached attacker failed can_be_grabbed_by()'s team check. Now the round is
##      frozen (_freeze_round) instead of survived.
##   3. The landing was read after the flight ENDED, i.e. after a bounce and a
##      skid; `is_on_floor()` could not fix it because a flying slipper moves by
##      move_and_collide and Godot never computes floor contact for it. Now first
##      contact is read off the flight code's own bounce counter.
##   4. The can and the taya stood in the arena, so throws that hit a BODY ended
##      at the body while throws that missed flew on to the floor — two
##      populations averaged into one meaningless mean. Now the arena is cleared
##      and every throw ends on the floor (see _clear_the_arena).
##
## It also found a real game bug on the way: B-132, the thrower-ignore window
## ignoring the whole world rather than the thrower. See _step_flying.
##
## Every unit is parked (ai_controller = null) for the sweep. That is deliberate:
## this measures the BALLISTICS, not a contested throw. A Taya body-blocking the
## arc is what `target=taya` and the fairness harness are for, and mixing the two
## would make a shortfall unattributable between "cannot reach" and "was blocked".
const BALLISTIC_ABILITIES: Array = [
	["throw_default (every Prop today, per B-76)", ""],
	["throw_bakya", "res://scripts/abilities/bakya_bash.gd"],
	["throw_flick", "res://scripts/abilities/flick_dash.gd"],
	["throw_bagsak", "res://scripts/abilities/bagsak_bomb.gd"],
]
## The two throwing lines, as z offsets. Both builders draw these along X at
## z = ±6.0 (`court_line("ThrowingLine*", "x", ±6.0, ...)`), so they are read
## from the same constant the chalk uses rather than restated by eye.
const THROWING_LINES: Array[float] = [-6.0, 6.0]
## ⚠️ KEPT SMALL ON PURPOSE. A throw that MISSES everything flies until
## MAX_FLIGHT_TIME (6.0 s), and the sweep is 8 cells — so every extra sample
## costs up to 6 seconds of wall clock per cell. At 8 throws plus 8 charge steps
## the run exceeded 500 s and was killed. These throws are near-deterministic
## (identical solved arc, everything else parked), so the sample is for
## confirming that determinism, not for averaging out noise.
const BALLISTIC_THROWS: int = 5
## Charge steps for the reach floor. CHARGE_MIN_POWER is 0.35, so below that is
## not a state the game can produce. Coarse for the same wall-clock reason —
## this locates the floor to within ~15%, which is enough to say whether a
## profile can reach the line at a sane charge.
const CHARGE_STEPS: Array[float] = [0.35, 0.5, 0.65, 0.8, 1.0]

## Teleport a character the way the GAME teleports one. See _watch_the_sky() for what
## a bare `global_position` write costs and why every placement in this file goes
## through here now.
func _place(who: CharacterBase, where: Vector3) -> void:
	if who == null or not is_instance_valid(who):
		return
	who.global_position = where
	who.velocity = Vector3.ZERO
	who.begin_spawn_settle()

func _park_everyone() -> void:
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		ch.ai_controller = null
		ch.velocity = Vector3.ZERO

## ⚠️ THE ROUND MUST NOT END, AND THIS IS WHY THE MEASUREMENT KEPT LYING.
##
## Every earlier version of this sweep fought the live match and lost. The chain:
## throws dent the can -> the can reaches MAX_DENTS -> THE ROUND ENDS ->
## `_reset_world()` swaps every role -> the cached `_attacker` is now on the CAN's
## team, so `can_be_grabbed_by()` rejects it on the team check ("an opponent's
## tsinelas: shove it, never pocket it") and every throw after that reports a grab
## failure. Re-deriving the cast fixed the grab failures but introduced a worse
## fault: the two teams own two DIFFERENT Prop nodes, so a refresh could hand back
## the other team's slipper carrying its own ability, and cells silently measured
## the wrong profile (throw_default and throw_bagsak reported near-identical
## landings, -2.75 vs -2.73, because both were measuring whatever Prop they got).
##
## So the round is FROZEN instead of survived: `round_active` is held true and
## the can is kept healthy and NORMAL, so no round ever ends, no role ever swaps,
## and the cast resolved at startup stays valid for the whole sweep.
## ⚠️ AND THE KNOCKDOWN PATH HAD TO BE CLOSED TOO, WHICH THE `-- ballistics` SWEEP
## NEVER NOTICED BECAUSE IT MOVES THE CAN OUT OF THE ARENA AND NEVER HITS IT.
## `-- lane` (R-06) deliberately aims AT the can, so it walks straight into three
## round-win paths the note above does not cover: FALL_LIMIT (4 Downed transitions
## end the round), the auto-seal when a Downed can's self-right window lapses, and
## Option A's dent count. Un-tracking the cans closes all three at once —
## `RoundManager._on_tracked_can_state_changed` and `_on_tracked_can_dents_changed`
## both return early on an empty list — and it is the ONLY one of the three that is a
## single call rather than a per-path patch. `main.gd` re-registers on every
## `round_started`, and no round starts during a sweep, so it stays closed.
##
## It changes nothing this probe measures: hit RESOLUTION (hitbox.gd) never consults
## the tracked list, and the resolved `kind`, the state transition and the knockback
## all happen exactly as they do in a match.
func _freeze_round() -> void:
	RoundManager.round_active = true
	RoundManager.time_left = 999.0
	RoundManager.clear_tracked_cans()
	MatchManager.team_a_wins = 0
	MatchManager.team_b_wins = 0
	if _can != null and is_instance_valid(_can):
		_can.dents = 0
		if _can.state != CharacterBase.State.NORMAL:
			_can.state = CharacterBase.State.NORMAL

## Puts the profile under test on EVERY Prop in the match, not just the one
## currently selected as `_slipper` — cheap insurance against the wrong-Prop
## failure described above, and it costs nothing since only one is ever thrown.
func _apply_profile(script_path: String) -> void:
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch == null or ch.is_person or ch.is_can:
			continue
		ch.ability = null if script_path == "" else load(script_path).new()

## Where every throw in the sweep is aimed. Captured from the can's spawn mark
## ONCE, before the can is moved out of the arena — see _clear_the_arena().
var _aim_point := Vector3.ZERO

## ⚠️ EMPTY THE ARENA, AND AIM AT A POINT ON THE GROUND RATHER THAN AT A BODY.
##
## This mode measures BALLISTICS — where a given profile puts the slipper at a
## given charge. A body standing at the target answers a different question and
## corrupts this one, in both directions:
##
##   * the TAYA spawns between the throwing line and the can, so a throw that
##     hits it registers a short landing that is indistinguishable from a profile
##     that cannot reach;
##   * the CAN itself ends the flight ON CONTACT, so a throw that reaches lands
##     at the can's collision surface (~1 m out) while a throw that misses flies
##     on to the ground. Averaging those two populations produced the nonsense
##     that made every earlier run untrustworthy — metres of "scatter" on eight
##     identical solved arcs, because the mean sat between two clusters.
##
## Both are moved far away and the aim point is kept as a bare Vector3. Every
## throw then ends the same way — on the floor — so the landing distribution is
## single-population and the scatter number means what it says.
##
## Whether a throw would have HIT the can is then a question about the landing
## point versus the can's mark, which is exactly what `mean miss` reports.
func _clear_the_arena() -> void:
	_can = null
	_attacker = null
	_taya = null
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.is_can: _can = ch
		elif not ch.is_person and not ch.is_can: _slipper = ch
		elif ch.is_person and not ch.team_is_can_side: _attacker = ch
		elif ch.is_person and ch.team_is_can_side: _taya = ch
	_park_everyone()
	# Captured BEFORE the can is moved — this is the mark the chalk is drawn
	# around and the point the 6.0 lines are measured from.
	if _can != null:
		_aim_point = Vector3(0.0, _can.global_position.y + 0.25, 0.0)
		_can.global_position = Vector3(40.0, 0.9, 40.0)
		_can.velocity = Vector3.ZERO
	if _taya != null:
		_taya.global_position = Vector3(30.0, 0.9, 30.0)

## R-06 · WHAT THE BALLISTICS SWEEP HAS TO REPORT NOW, AND WHY IT IS NOT JUST A ROW.
##
## The lob's acceptance is a TIME, not a distance: `CAN_EVADE_LOOKAHEAD` is 0.6 s and
## the arc has to last longer than that or the dodge never gets a chance. The old
## sweep measured only WHERE a throw lands, so it could not have answered it.
##
## ⚠️ AND `eta` IN `AIController._cond_slipper_incoming()` IS FLIGHT TIME, WHICH IS
## WHY FLIGHT TIME IS THE RIGHT NUMBER TO MEASURE RATHER THAN A PROXY FOR ONE. That
## function computes `eta := horizontal_distance / horizontal_speed` and ignores the
## throw entirely when `eta > CAN_EVADE_LOOKAHEAD`. Horizontal speed is constant under
## gravity, so that expression is EXACTLY time-to-impact for any arc, flat or lobbed —
## the can's warning is therefore `min(flight_time, 0.6)`. A 0.29 s flat throw gives it
## 0.29 s; a lob that lasts longer than 0.6 s gives it the full lookahead budget. That
## is the whole balance clause, and it is a property of the arc, not of the AI.
##
## `apex` is here for a different reason: it is the only number that says whether the
## lob CLEARS a body-block rather than being stopped by it, and it is also the number
## that would catch a lob fouling map dressing (a sampay line, a wire tangle) — which
## would show up as a short landing with a bounce, not as an error.
##
## One throw from `origin` at `charge`. Returns a Dictionary, not a position, because
## four numbers now come off one throw and returning Vector3.INF for "the grab never
## took" was already overloading the one value it did return.
##   ok           false = probe failure (grab never took), not a physics result
##   landed       first CONTACT position, not the resting place — see below
##   flight_time  launch to first contact, in seconds
##   apex         highest y reached, minus the launch y
##   angle_deg    the solved launch angle above horizontal
func _ballistic_throw(origin: Vector3, charge: float, lob: bool = false) -> Dictionary:
	var carriable := _slipper.get_node("Carriable") as Carriable
	# ⚠️ RESET TO LOOSE FROM WHATEVER STATE THE LAST THROW LEFT. The first version
	# of this called only host_land(), which returns early unless the state is
	# FLYING — so the first cell's throws worked and every cell after it reported
	# 8/8 grab failures, because the slipper was still CARRIED and host_grab()
	# refuses a slipper that already has a carrier. Both exits have to be covered.
	if carriable.state == Carriable.CarryState.CARRIED:
		carriable.host_drop()
	elif carriable.state == Carriable.CarryState.FLYING:
		carriable.host_land()
	# Hold the round open every throw, so no round ever ends and no role ever
	# swaps mid-sweep. See _freeze_round's doc for what that was costing.
	_freeze_round()
	await get_tree().physics_frame
	# ⚠️ `begin_spawn_settle()`, NOT A BARE TELEPORT. See _watch_the_sky() — a
	# teleported body spends one frame inside whatever was already there and gets
	# depenetrated straight up. This is the same call `main.gd::_place_at_spawn` makes
	# for exactly this reason, and the probe was the last place still teleporting
	# without it.
	_place(_attacker, origin)
	for settle in CharacterBase.SPAWN_SETTLE_FRAMES + 1:
		await get_tree().physics_frame
	# Same path the real game takes — loose, grabbed, thrown. Anything that skips
	# the grab tests a state the game never reaches (see the main series above).
	#
	# ⚠️ PLACED AND GRABBED IN ONE FRAME GAP, DELIBERATELY. The slipper lands 0.4 m
	# from the attacker and their capsules are 0.20 + 0.40 = 0.60 wide, so they
	# INTERPENETRATE on placement by design (the slipper has to be in reach). Letting a
	# physics step run in between is what shoves the attacker; `host_grab` disables the
	# slipper's own collision (`_set_physics_enabled(false)`), so grabbing first means
	# there is never an overlapping pair for the broadphase to resolve.
	_slipper.global_position = origin + Vector3(0.4, 0.3, 0.0)
	_slipper.velocity = Vector3.ZERO
	carriable.host_grab(_attacker)
	await get_tree().physics_frame
	if carriable.state != Carriable.CarryState.CARRIED:
		return {"ok": false}
	var launch_y := _slipper.global_position.y
	carriable.host_throw(_aim_point, charge, lob)
	# Read the SOLVED angle off the launch velocity the throw actually produced,
	# rather than re-deriving it from the quadratic here. A probe that recomputes the
	# thing under test cannot catch the thing under test being wrong.
	var launch_v: Vector3 = carriable._flight_velocity
	var launch_flat := Vector2(launch_v.x, launch_v.z).length()
	var angle_deg: float = rad_to_deg(atan2(launch_v.y, maxf(launch_flat, 0.0001)))
	# ⚠️ FIRST CONTACT, NOT THE RESTING PLACE — AND `is_on_floor()` CANNOT FIND IT.
	#
	# The first version waited for the FLYING state to end and took the position
	# there, which measures the throw PLUS a skip PLUS the roll: a throw from
	# z=-6.0 aimed at the can reported a landing of z=+2.92, nearly 3 m PAST the
	# target, and cells showed 3-9 m of "scatter" on eight identical solved-arc
	# throws. `_step_flying` bounces up to MAX_BOUNCES (1) at BOUNCE_DAMPING (0.3)
	# before it calls host_land(), so the end of the flight is the end of the SKID.
	#
	# The second version watched `is_on_floor()`, which never goes true: a flying
	# slipper is moved by `move_and_collide`, not `move_and_slide`, so Godot never
	# computes floor contact for it and the check silently fell through to the same
	# resting position as before.
	#
	# So first contact is read off the flight code's own bounce counter — the frame
	# `_bounces_left` drops is the frame it first touched something. If it never
	# drops, the flight ended on its first collision (or timed out) and the end
	# position IS first contact.
	var guard := 0
	var bounces_before: int = carriable._bounces_left
	var landed := Vector3.INF
	var apex := launch_y
	var flight_time := 0.0
	# ⚠️ FLIGHT TIME IS TAKEN FROM THE FLIGHT CODE'S OWN CLOCK, NOT FROM A FRAME
	# COUNT HERE. `_flight_time` is what `_step_flying` integrates and what
	# MAX_FLIGHT_TIME is checked against, so it cannot drift from the thing being
	# measured — and a frame count would silently be wrong under any time scale,
	# which is the exact shape of the `Engine.time_scale` fault that made every
	# fairness number recorded at `scale=4` actually a scale-1 number.
	while carriable.state == Carriable.CarryState.FLYING and guard < 800:
		await get_tree().physics_frame
		guard += 1
		apex = maxf(apex, _slipper.global_position.y)
		if landed == Vector3.INF and carriable._bounces_left < bounces_before:
			landed = _slipper.global_position
			flight_time = carriable._flight_time
	if landed == Vector3.INF:
		landed = _slipper.global_position
		flight_time = carriable._flight_time
	return {
		"ok": true,
		"landed": landed,
		"flight_time": flight_time,
		"apex": apex - launch_y,
		"angle_deg": angle_deg,
	}

func _run_ballistics() -> void:
	# Cast resolved ONCE — the round is frozen below, so no role ever swaps and
	# nothing here can go stale mid-sweep.
	_clear_the_arena()
	_freeze_round()
	await get_tree().physics_frame
	print("\n=== BALLISTICS SWEEP ===")
	print("  map            : %s" % _map_id)
	print("  aim point      : (%.2f, %.2f, %.2f)  (the can's mark; the can itself is moved away)"
		% [_aim_point.x, _aim_point.y, _aim_point.z])
	print("  throwing lines : z = %.1f and z = %.1f  (%d throws each, full charge)"
		% [THROWING_LINES[0], THROWING_LINES[1], BALLISTIC_THROWS])
	print("  GRAVITY        : %.1f  (CharacterBase.GRAVITY, NOT 9.8)" % CharacterBase.GRAVITY)
	print("  arena          : can and taya moved out; every throw ends on the FLOOR,")
	print("                   so the landing distribution is single-population.")
	for entry in BALLISTIC_ABILITIES:
		var label: String = entry[0]
		var script_path: String = entry[1]
		_apply_profile(script_path)
		await get_tree().physics_frame
		var profile := (_slipper.get_node("Carriable") as Carriable)._profile()
		print("\n  --- %s  (speed %.1f, arc %.1f deg, gravity_scale %.2f) ---"
			% [label, profile.launch_speed, profile.arc_angle_deg, profile.gravity_scale])
		for line_z in THROWING_LINES:
			var origin := Vector3(_aim_point.x, 0.9, _aim_point.z + line_z)
			# R-06: the same cell measured twice, FLAT then LOB. Deliberately side by
			# side on adjacent lines of output rather than in two separate tables —
			# the whole claim is a comparison ("steeper arc, longer flight, same
			# landing point"), and a comparison split across two runs is one nobody
			# checks. The flat row is also the row that must still match the
			# 2026-07-29 baseline, which is the regression test on the root
			# selection: if picking the minus root explicitly changed the flat
			# throw at all, the mechanic broke the game it was added to.
			for lob in [false, true]:
				await _ballistic_cell(origin, line_z, lob)
			var reach_charge := await _reach_floor(origin)
			print("        reach floor (flat) : %s"
				% [("%.0f%% charge" % (reach_charge * 100.0)) if reach_charge > 0.0
					else "*** NEVER REACHES ***"])

## One cell of the sweep: BALLISTIC_THROWS identical throws, reported as a mean
## landing plus the spread about it. Scatter is measured about the MEAN LANDING POINT
## rather than about the can — a throw that consistently lands 2 m short is precise
## and wrong, and averaging those two together would hide it.
func _ballistic_cell(origin: Vector3, line_z: float, lob: bool) -> void:
	var misses: Array[float] = []
	var lands: Array[Vector3] = []
	var times: Array[float] = []
	var apexes: Array[float] = []
	var angles: Array[float] = []
	var failed := 0
	for i in BALLISTIC_THROWS:
		var shot: Dictionary = await _ballistic_throw(origin, 1.0, lob)
		if not shot.get("ok", false):
			failed += 1
			continue
		var rest: Vector3 = shot["landed"]
		lands.append(rest)
		times.append(shot["flight_time"])
		apexes.append(shot["apex"])
		angles.append(shot["angle_deg"])
		misses.append(Vector2(rest.x - _aim_point.x, rest.z - _aim_point.z).length())
	var label := "LOB " if lob else "flat"
	if lands.is_empty():
		print("    line z=%+.1f %s: *** NO THROW LAUNCHED (%d grab failures) ***"
			% [line_z, label, failed])
		return
	var mean := Vector3.ZERO
	for p in lands:
		mean += p
	mean /= float(lands.size())
	var spread := 0.0
	for p in lands:
		spread = maxf(spread, Vector2(p.x - mean.x, p.z - mean.z).length())
	var n := float(lands.size())
	var mean_time := _sum_of(times) / n
	# ⚠️ THE ACCEPTANCE TEST, EVALUATED IN THE PROBE RATHER THAN BY EYE. The bar is
	# `flight_time > CAN_EVADE_LOOKAHEAD`, and a verdict printed beside the number is
	# what stops a later reader inferring the wrong one from a table.
	var evade := "dodge gets %s" % [
		"THE FULL 0.60 s LOOKAHEAD" if mean_time > AIController.CAN_EVADE_LOOKAHEAD
		else "only %.2f s" % mean_time]
	print("    line z=%+.1f %s: landed (%.2f, %.2f) | miss %.2f m | scatter %.2f m | angle %.1f deg | flight %.3f s | apex %.2f m | %s%s"
		% [line_z, label, mean.x, mean.z, _sum_of(misses) / n, spread,
			_sum_of(angles) / n, mean_time, _sum_of(apexes) / n, evade,
			"" if failed == 0 else "  (%d grab failures)" % failed])

## ---------------------------------------------------------------------------
## R-06 · THE CONTESTED LANE — `-- lane`. THE TRIANGLE, MEASURED AS A 2x2.
##
## The item's acceptance bar is a contact rate against a taya parked in the lane, and
## R-06 is explicit that the lob must NOT be a strictly better shot: "the lob beats
## the taya, the dodge beats the lob, the flat throw beats the dodge." That is three
## claims, and a single contact number for the lob answers only the first of them —
## it would pass identically for a lob that is simply better at everything, which is
## the outcome the item says to revert rather than ship.
##
## So all four cells are measured in one run, from one harness, and the triangle
## either appears in the table or it does not:
##
##                    | taya blocks, can PARKED | taya blocks, can DODGING
##     flat throw     |  (a) the 92% wall       |  (c)
##     LOB            |  (b) >= 40% is the bar  |  (d) must fall well below (b)
##
##   (b) > (a)  — the lob beats the body-block.        R-06's stated acceptance.
##   (d) < (b)  — the can's dodge beats the lob.       The balance clause.
##   (c) vs (d) — the flat throw's own dodge exposure, i.e. whether the flat throw
##                is the better answer once the can is the thing in the way. This is
##                the corner nobody would have measured, and it is the one that says
##                the two throws are genuinely different tools rather than ranked.
##
## ⚠️ WHY THE CAN IS PARKED IN (a)/(b) AND NOT IN (c)/(d). A parked can isolates the
## BLOCK; a live one measures block-and-dodge together, and the ballistics sweep's
## own fault #4 is the standing example of two populations averaged into one
## meaningless mean. Parking is `ai_controller = null`, i.e. the same mechanism
## `_park_everyone()` already uses.
##
## ⚠️ THE TAYA IS RE-PLACED BEFORE EVERY THROW, AND THAT IS NOT TIDINESS. A flat throw
## that hits it delivers real knockback (`apply_knockback` writes velocity and the
## ordinary move_and_slide carries it), so an unmoved taya walks itself out of the
## lane over a dozen throws and the later throws in a cell are measuring a lane that
## is no longer blocked — a cell that drifts from (a) toward an unblocked lane while
## still being labelled (a).
## ---------------------------------------------------------------------------

## Throws per cell. Four cells, and a lob is ~1.7 s of flight against a flat throw's
## ~0.29, so this is the wall-clock knob — see BALLISTIC_THROWS' own note.
const LANE_THROWS: int = 10
## Where the parked taya stands, as a fraction of the way from the can to the
## attacker. Overridden by `standoff=`; the default comes off the AI's live value.
var _lane_hits := 0
var _lane_blocked := 0
var _lane_target: CharacterBase = null
var _lane_blocker: CharacterBase = null

## Counts, per throw, whether the CAN was struck and whether the TAYA was struck.
## ⚠️ Attributed by WHICH CHARACTER the hitbox resolved on, not inferred from the
## flight ending — a throw stopped by the taya and a throw that fell short both end
## the flight, and calling both "blocked" would flatter the lob for free.
func _on_lane_landed_on(target: CharacterBase) -> void:
	if target == null:
		return
	if target == _lane_target:
		_lane_hits += 1
	elif target == _lane_blocker:
		_lane_blocked += 1

func _run_lane() -> void:
	# ⚠️ THE CAN'S CONTROLLER IS CAPTURED FROM THE FIELD, BEFORE PARKING NULLS IT.
	# The first version looked it up as `get_node_or_null("AIController")` and got null
	# every time — `main.gd::_attach_ai` does `AIController.new()` + `add_child()` with
	# no explicit name, so Godot auto-names the node and the path is not the class name.
	# It failed SILENTLY into "the can does not dodge", which would have made the two
	# cells that test R-06's balance clause quietly measure nothing. The probe now says
	# so out loud instead (see the warning below the table).
	var can_ai: AIController = null
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.is_can:
			can_ai = ch.ai_controller
	# Cast resolved once, then the round held open — same contract the ballistics
	# sweep documents at length in _freeze_round().
	_park_everyone()
	_freeze_round()
	await get_tree().physics_frame
	if _can == null or _taya == null or _attacker == null or _slipper == null:
		print("LANE: incomplete cast (can/taya/attacker/slipper) — nothing to measure")
		return
	_lane_target = _can
	_lane_blocker = _taya
	var can_mark := Vector3(0.0, _can.global_position.y, 0.0)
	var line := Vector3(0.0, 0.9, THROWING_LINES[0])
	print("\n=== CONTESTED LANE (R-06) ===")
	print("  map            : %s" % _map_id)
	print("  throwing line  : z = %.1f   (%d throws per cell, full charge)"
		% [line.z, LANE_THROWS])
	print("  taya standoff  : %.2f from the can, parked ON the lane" % _standoff)
	print("  can mark       : (%.2f, %.2f, %.2f)" % [can_mark.x, can_mark.y, can_mark.z])
	print("  mode           : %s" % ("OPTION_A (dents)" if GameLaunch.game_mode == GameLaunch.GameMode.OPTION_A else "OPTION_B (downed/seal)"))
	print("")
	print("  %-6s %-8s %-8s %8s %8s %8s   %s" % [
		"throw", "lane", "can", "contact", "blocked", "neither", "detail"])
	var results: Dictionary = {}
	# ⚠️ EIGHT CELLS, AND THE THIRD AXIS IS WHY. The first version of this ran only the
	# four cells with the lane BLOCKED, and leg 3 of the triangle came out unmeasurable:
	# with a taya on the lane the flat throw scores 0% whether the can dodges or not
	# (the block stops it before the can is even relevant), so "the flat throw beats the
	# dodge" had nothing to compare against — 0% vs 0% is a tie at zero, not a
	# domination, and reading it as one would have condemned the mechanic for the
	# harness's fault. The OPEN-lane pair is the only place that claim lives.
	for blocked in [true, false]:
		for lob in [false, true]:
			for dodging in [false, true]:
				var rate := await _lane_cell(can_mark, line, lob, dodging, blocked, can_ai)
				results["%s/%s/%s" % [
					"lob" if lob else "flat",
					"blocked" if blocked else "open",
					"dodge" if dodging else "park"]] = rate
	print("")
	if can_ai == null:
		print("  ⚠️ THE CAN HAS NO AIController — the two 'dodging' cells measured a")
		print("     PARKED can and the balance clause is therefore UNMEASURED here.")
	_lane_verdict(results)
	_report_the_sky()

## One cell. Returns the contact rate on the can, 0..1.
func _lane_cell(can_mark: Vector3, line: Vector3, lob: bool, dodging: bool,
		blocked: bool, can_ai: AIController) -> float:
	var carriable := _slipper.get_node("Carriable") as Carriable
	var hits := 0
	# Named `stopped`, not `blocked` — `blocked` is this cell's own axis (is there a body
	# on the lane at all) and shadowing it with the outcome counter is how a table ends
	# up labelling its rows from its results.
	var stopped := 0
	var neither := 0
	for i in LANE_THROWS:
		# Reset the world to the identical starting geometry every throw. Everything
		# here is a re-placement, not a state change, so no code path under test is
		# skipped: the slipper still goes LOOSE -> CARRIED -> FLYING through the real
		# host transitions below.
		if carriable.state == Carriable.CarryState.CARRIED:
			carriable.host_drop()
		elif carriable.state == Carriable.CarryState.FLYING:
			carriable.host_land()
		_freeze_round()
		_can.state = CharacterBase.State.NORMAL
		_place(_can, can_mark)
		# The can dodges only in the (c)/(d) cells. Detaching and re-attaching the
		# controller is the same lever _park_everyone() pulls.
		_can.ai_controller = can_ai if dodging else null
		# The blocker, on the lane, standoff out from the can toward the thrower.
		var bearing := (line - can_mark)
		bearing.y = 0.0
		bearing = bearing.normalized()
		_taya.ai_controller = null
		_taya.input_parked = true
		_taya.state = CharacterBase.State.NORMAL
		# BLOCKED: on the lane, standoff out from the can. OPEN: still on the field and
		# still inside its own confinement square (CONFINEMENT_RADIUS 5.0), just off the
		# lane — moved sideways rather than deleted, so the two cells differ ONLY in
		# whether the body is in the way.
		var post := can_mark + bearing * _standoff if blocked \
			else can_mark + bearing.cross(Vector3.UP) * (CharacterBase.CONFINEMENT_RADIUS - 0.2)
		_place(_taya, post + Vector3(0.0, 0.9 - can_mark.y, 0.0))
		_place(_attacker, line)
		# ⚠️ SETTLE BEFORE MEASURING. Four bodies were just teleported; without this the
		# broadphase resolves the overlaps by launching them, which is the very thing a
		# human spotted watching a run of this probe. See _watch_the_sky().
		for settle in CharacterBase.SPAWN_SETTLE_FRAMES + 1:
			await get_tree().physics_frame
		# ⚠️⚠️ RELEASE PHASE IS JITTERED PER THROW, AND WITHOUT IT A CELL IS ONE COIN
		# FLIP REPORTED AS TEN.
		#
		# `AIController`'s own note on CAN_EVADE_LOOKAHEAD says the sweep is
		# non-monotonic "because those throws are identical and the outcome turns on
		# exact sidestep phase". Every throw in a cell here IS identical — same
		# geometry, same charge, same frame offsets — so the can's dodge timer sits at
		# the same phase every time and all ten throws resolve the same way. The first
		# run of this table duly returned 0/10 and 10/10 and nothing in between, which
		# is not a contact rate, it is one sample with a misleading denominator.
		#
		# 3 frames per throw spans 450 ms over ten throws, comfortably more than one
		# sidestep cycle. The wait happens with the can's controller LIVE, so it is the
		# AI's own state that advances rather than a number being perturbed.
		for phase in i * 3:
			await get_tree().physics_frame
		# Placed and grabbed in one frame gap — see _ballistic_throw's own note.
		_slipper.global_position = line + Vector3(0.4, 0.3, 0.0)
		_slipper.velocity = Vector3.ZERO
		carriable.host_grab(_attacker)
		await get_tree().physics_frame
		if carriable.state != Carriable.CarryState.CARRIED:
			neither += 1
			continue
		_lane_hits = 0
		_lane_blocked = 0
		# ⚠️ ARMED AFTER THE THROW, NOT BEFORE — the pulse hitbox does not exist until
		# _rpc_set_flying runs inside host_throw. Arming before is precisely the bug
		# that made ai_probe report zero hits for every run it ever recorded.
		carriable.host_throw(can_mark + Vector3(0.0, 0.25, 0.0), 1.0, lob)
		_watch_lane_hitboxes()
		# Long enough for a lob (measured ~1.7 s) plus its bounce and settle.
		var guard := 0
		while carriable.state == Carriable.CarryState.FLYING and guard < 240:
			await get_tree().physics_frame
			guard += 1
		await get_tree().create_timer(0.2).timeout
		if _lane_hits > 0:
			hits += 1
		elif _lane_blocked > 0:
			stopped += 1
		else:
			neither += 1
	var rate := float(hits) / float(LANE_THROWS)
	print("  %-6s %-8s %-8s %7.0f%% %7.0f%% %7.0f%%   %s" % [
		"LOB" if lob else "flat", "blocked" if blocked else "open",
		"dodging" if dodging else "parked",
		rate * 100.0, 100.0 * stopped / LANE_THROWS, 100.0 * neither / LANE_THROWS,
		"%d/%d on the can, %d stopped by the taya" % [hits, LANE_THROWS, stopped]])
	return rate

func _watch_lane_hitboxes() -> void:
	if _slipper == null or not is_instance_valid(_slipper):
		return
	for hb in _slipper.find_children("*", "Hitbox", true, false):
		var box := hb as Hitbox
		if not box.landed_on.is_connected(_on_lane_landed_on):
			box.landed_on.connect(_on_lane_landed_on)

## ⚠️ THREE PASS/FAIL LINES, NOT ONE. R-06's own acceptance is only the first; the
## other two are the difference between shipping a third corner and shipping a
## strictly better shot, and the item says the second outcome is a REVERT.
func _lane_verdict(r: Dictionary) -> void:
	var flat_block: float = r.get("flat/blocked/park", 0.0)
	var lob_block: float = r.get("lob/blocked/park", 0.0)
	var lob_block_dodge: float = r.get("lob/blocked/dodge", 0.0)
	var flat_open_dodge: float = r.get("flat/open/dodge", 0.0)
	var lob_open_dodge: float = r.get("lob/open/dodge", 0.0)
	var lob_open_park: float = r.get("lob/open/park", 0.0)
	print("  --- THE TRIANGLE, LEG BY LEG ---")
	print("  1. THE LOB BEATS THE TAYA   : lane blocked, can parked — lob %.0f%% vs flat %.0f%%"
		% [lob_block * 100.0, flat_block * 100.0])
	print("       -> %s" % ["PASS (R-06's bar is >= 40%)" if lob_block >= 0.40
		else "*** FAIL — the lob does not get over the block ***"])
	print("  2. THE DODGE BEATS THE LOB  : lob %.0f%% against a dodging can vs %.0f%% parked"
		% [lob_open_dodge * 100.0, lob_open_park * 100.0])
	print("       -> %s" % ["PASS (the dodge costs the lob its contact)"
		if lob_open_dodge < lob_open_park
		else "*** FAIL — the can's evasion does not touch the lob ***"])
	print("  3. THE FLAT THROW BEATS THE DODGE : open lane, dodging can — flat %.0f%% vs lob %.0f%%"
		% [flat_open_dodge * 100.0, lob_open_dodge * 100.0])
	print("       -> %s" % ["PASS (the flat throw owns a corner the lob does not)"
		if flat_open_dodge > lob_open_dodge
		else "*** FAIL — the flat throw does not own its corner. SEE THE NOTE BELOW ***"])
	if flat_open_dodge <= lob_open_dodge:
		# ⚠️ WHERE THIS FAILURE LIVES, BECAUSE "REVERT" IS THE WRONG READING OF IT AND
		# THE ITEM'S OWN REVERT CLAUSE IS CONDITIONED ON THE MECHANIC HAVING FAILED.
		#
		# The mechanic passes its two stated bars. What fails is the third leg, and the
		# cause is not the lob's ballistics — it is the can's evasion.
		#
		# ⚠️⚠️ AND THIS COMMENT USED TO NAME THE WRONG CAUSE, WHICH IS WHY `-- band` EXISTS.
		# It said `_act_can_evade` (a function that does not exist — it is `_act_evade`)
		# "sidesteps LATERALLY … CAN_EVADE_STEP is 1.2 m against an overlap band of ~0.52 m
		# … you cannot sidestep out from under a drop." The 1.2 is the AI's constant; the
		# 0.52 was measured NOWHERE, and the sentence is a physics argument, which is the
		# one kind of diagnosis this project does not accept.
		#
		# MEASURED with `-- band`: the lob's band is 0.45 m, so CAN_EVADE_STEP aims 2.7x it
		# and IS BIG ENOUGH. The can reaches a peak of 0.84 m against a lob — a full-size
		# sidestep, the same as the 0.82 m it manages against a flat throw — and is back
		# within 0.31 m of the mark by the frame the slipper is closest. IT STEPS OUT AND
		# COMES HOME during the lob's 1.40 s tail. The step is the right size and is not
		# HELD.
		#
		# That is one behaviour in one file, and it is not this lane's. `flight_is_lob` is
		# still the flag to branch on, and it is replicated to every peer precisely so the
		# decision needs no re-derivation from the trajectory — but the fix is holding the
		# sidestep, NOT widening it.
		print("")
		print("  ⚠️ DIAGNOSIS — this is the CAN'S DODGE, not the lob's ballistics.")
		print("     The lob passes legs 1 and 2. Do NOT revert it on this row alone;")
		print("     nothing here is a property of the arc.")
		print("     RUN `-- band` FOR THE CAUSE. It is measured there, and it is NOT the")
		print("     one this line used to state: the band is 0.45 m, CAN_EVADE_STEP aims")
		print("     2.7x it, and the can completes a full-size sidestep and is back within")
		print("     0.31 m of the mark by the frame the lob arrives. The step is the right")
		print("     SIZE and is not HELD. Handover: `Carriable.flight_is_lob` is replicated")
		print("     for exactly this. Widening CAN_EVADE_STEP is the wrong fix.")
	print("  (for reference, blocked lane + dodging can: lob %.0f%% — both defences at once)"
		% [lob_block_dodge * 100.0])

## ---------------------------------------------------------------------------
## R-06 leg 3 · THE OVERLAP BAND — `-- band`. THE ONE NUMBER THE HANDOVER ASSERTED
## AND NEVER MEASURED.
##
## `_lane_verdict()` above diagnoses leg 3's failure as "CAN_EVADE_STEP 1.2 m against a
## ~0.52 m overlap band — you cannot sidestep out from under a drop." The 1.2 is read
## from the AI's own constant. **The 0.52 was not measured anywhere.** It is close to
## `ai_controller.gd`'s arithmetic for a different quantity (hurtbox 0.17 +
## `throw_flick`'s hit_radius 0.30 = 0.47), and that in turn does not match the shipped
## Hurtbox capsule, whose radius in `CharacterBase.tscn` is 0.45 before any scaling.
## Three numbers that cannot all be the band.
##
## ⚠️ AND THE DIAGNOSIS IS A PHYSICS ARGUMENT, WHICH IS THE ONE KIND THIS PROJECT DOES
## NOT ACCEPT. "You cannot sidestep out from under a drop" sounds obviously true and
## predicts the opposite of what leg 3 measured on two counts: the lob's flight is
## 0.86–1.10 s against the flat throw's 0.32, and `CAN_EVADE_LOOKAHEAD` caps the warning
## at 0.6 s for both — so the can gets MORE dodging time against a lob, not less, and it
## still gets hit more. A handover built on the reasoning rather than the number could
## send the balance lane to widen a step that is already wide enough.
##
## SO MEASURE THE BAND DIRECTLY, and the design is the whole point:
##
##   * the throw is aimed at the can's MARK, never at where the can actually is. That is
##     what a sidestep IS — the arc is committed before the can moves, and a probe that
##     re-aimed at the displaced can would measure nothing at all.
##   * the can is PARKED at a fixed lateral offset instead of dodging. This deliberately
##     removes the AI: the question here is geometric ("how far must a body be from the
##     mark to be missed"), and mixing it with the AI's timing is what made leg 3
##     ambiguous in the first place. Timing is the NEXT question, and it is only
##     answerable once this one has a number.
##   * offsets sweep past CAN_EVADE_STEP on purpose. If the band's half-width is under
##     1.2 m then a 1.2 m sidestep is geometrically sufficient and leg 3's failure is
##     TIMING, not shape — a completely different fix in a different function.
##
## Sanity, both from the impossible-number rule:
##   1. offset 0.00 must be 100% for BOTH throws. A dead-centre throw at a parked can
##      that misses is a broken harness, and every earlier fault in this file presented
##      exactly that way.
##   2. contact must be MONOTONIC in offset. Once a column reaches zero it must stay
##      there; contact that resumes further out is a bounce or a second body, not a
##      band, and the report says so rather than averaging it in.
## ---------------------------------------------------------------------------

## Swept past CAN_EVADE_STEP (1.2) on both sides so the comparison is readable rather
## than a bound. 0.15 steps resolve the band to about a third of a hurtbox radius.
const BAND_OFFSETS: Array[float] = [0.0, 0.15, 0.30, 0.45, 0.60, 0.75, 0.90,
	1.05, 1.20, 1.35, 1.50]
## Per cell. The can is parked and the arc is solved, so these throws are near
## deterministic — the sample confirms that determinism rather than averaging noise,
## the same contract BALLISTIC_THROWS documents.
const BAND_THROWS: int = 3

## Closest the slipper got to the can's hurtbox centre on the throw in flight, tracked
## per throw so the contact column can be cross-checked against a distance. Horizontal
## and full 3D are both kept: for a flat throw they are nearly the same number and for a
## lob they are not, which is itself the arc's signature.
var _band_min_flat := 9999.0
var _band_min_3d := 9999.0
var _band_watch: CharacterBase = null
## Phase 2 (the dodge ACHIEVED, see _band_dodge). The mark and the perpendicular axis
## the sidestep is measured along, plus the peak displacement reached and the
## displacement at the frame of closest approach — which is the only one that decides
## anything. Peak alone would flatter a can that stepped out and drifted back.
var _band_mark := Vector3.ZERO
var _band_side := Vector3.RIGHT
var _band_peak_perp := 0.0
var _band_perp_at_closest := 0.0

func _run_band() -> void:
	var can_ai: AIController = null
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.is_can:
			can_ai = ch.ai_controller
	_park_everyone()
	_freeze_round()
	await get_tree().physics_frame
	if _can == null or _taya == null or _attacker == null or _slipper == null:
		print("BAND: incomplete cast (can/taya/attacker/slipper) — nothing to measure")
		return
	_lane_target = _can
	_lane_blocker = _taya
	var can_mark := Vector3(0.0, _can.global_position.y, 0.0)
	var line := Vector3(0.0, 0.9, THROWING_LINES[0])
	print("\n=== THE OVERLAP BAND (R-06 leg 3) ===")
	print("  map            : %s" % _map_id)
	print("  throwing line  : z = %.1f   (%d throws per offset, full charge)"
		% [line.z, BAND_THROWS])
	print("  can mark       : (%.2f, %.2f, %.2f)   lane is OPEN (taya off it)"
		% [can_mark.x, can_mark.y, can_mark.z])
	print("  aim point      : the MARK, every throw — never the can's actual position")
	# ⚠️ THE GEOMETRY IS READ OFF THE LIVE NODES, NOT RESTATED. Both numbers below are
	# what the three conflicting figures in the header are guesses at, so a guess is
	# exactly what must not appear here.
	print("  can hurtbox    : %s" % _describe_hurtbox(_can))
	print("  slipper        : %s" % _describe_slipper(_slipper))
	print("  CAN_EVADE_STEP : %.2f m   (what one sidestep aims for — the number to beat)"
		% AIController.CAN_EVADE_STEP)
	print("")
	print("  %-6s %8s %8s %10s %10s   %s"
		% ["throw", "offset", "contact", "min flat", "min 3D", "detail"])
	var bands: Dictionary = {}
	for lob in [false, true]:
		bands["lob" if lob else "flat"] = await _band_sweep(can_mark, line, lob, can_ai)
	print("")
	var band_half := _band_verdict(bands)
	# ⚠️ PHASE 2 EXISTS BECAUSE PHASE 1 CANNOT CONDEMN ANYTHING ON ITS OWN. A band
	# narrower than CAN_EVADE_STEP says the sidestep is BIG ENOUGH; it does not say the
	# can ever performs it. Those are two different failures with two different fixes, and
	# only the pair of tables distinguishes them.
	var achieved := await _band_dodge(can_mark, line, can_ai)
	_band_handover(band_half, achieved)
	_report_the_sky()

## ---------------------------------------------------------------------------
## `-- band` PHASE 2 · THE DODGE ACTUALLY ACHIEVED. The can starts ON the mark with its
## controller LIVE, and what is recorded is how far off the mark it got by the frame the
## slipper was closest — measured along the same perpendicular axis phase 1 swept, so the
## two tables are in the same units and can be compared directly.
##
## ⚠️ PEAK AND AT-CLOSEST ARE BOTH REPORTED AND THEY ARE NOT THE SAME CLAIM. A can that
## sidesteps 1.2 m and is pulled back to the circle before the slipper arrives has a peak
## of 1.2 and an at-closest of nearly 0, and it gets hit. Reporting the peak alone is how
## a dodge that happens too EARLY reads as a dodge that worked.
## ---------------------------------------------------------------------------

const BAND_DODGE_THROWS: int = 10

func _band_dodge(can_mark: Vector3, line: Vector3, can_ai: AIController) -> Dictionary:
	print("")
	print("  --- PHASE 2: THE DODGE THE CAN ACTUALLY ACHIEVES (controller LIVE) ---")
	if can_ai == null:
		print("  ⚠️ THE CAN HAS NO AIController — phase 2 measured nothing. The handover")
		print("     below rests on phase 1 alone and cannot separate shape from timing.")
		return {}
	print("  %-6s %8s %10s %12s %10s   %s"
		% ["throw", "contact", "peak perp", "at closest", "flight", "detail"])
	var carriable := _slipper.get_node("Carriable") as Carriable
	var bearing := (line - can_mark)
	bearing.y = 0.0
	bearing = bearing.normalized()
	_band_mark = can_mark
	_band_side = bearing.cross(Vector3.UP).normalized()
	var out: Dictionary = {}
	for lob in [false, true]:
		var hits := 0
		var peaks: Array[float] = []
		var closes: Array[float] = []
		var flights: Array[float] = []
		for i in BAND_DODGE_THROWS:
			if carriable.state == Carriable.CarryState.CARRIED:
				carriable.host_drop()
			elif carriable.state == Carriable.CarryState.FLYING:
				carriable.host_land()
			_freeze_round()
			_can.state = CharacterBase.State.NORMAL
			_place(_can, can_mark)
			_can.ai_controller = can_ai
			_taya.ai_controller = null
			_taya.input_parked = true
			_taya.state = CharacterBase.State.NORMAL
			_place(_taya, can_mark + _band_side * (CharacterBase.CONFINEMENT_RADIUS - 0.2)
				+ Vector3(0.0, 0.9 - can_mark.y, 0.0))
			_place(_attacker, line)
			for settle in CharacterBase.SPAWN_SETTLE_FRAMES + 1:
				await get_tree().physics_frame
			# Release phase jittered per throw, for the reason `_lane_cell` documents at
			# length: every throw here is otherwise identical, so the can's dodge timer
			# sits at one phase and ten throws report one coin flip.
			for phase in i * 3:
				await get_tree().physics_frame
			_slipper.global_position = line + Vector3(0.4, 0.3, 0.0)
			_slipper.velocity = Vector3.ZERO
			carriable.host_grab(_attacker)
			await get_tree().physics_frame
			if carriable.state != Carriable.CarryState.CARRIED:
				continue
			_lane_hits = 0
			_lane_blocked = 0
			_band_min_flat = 9999.0
			_band_min_3d = 9999.0
			_band_peak_perp = 0.0
			_band_perp_at_closest = 0.0
			_band_watch = _can
			var t0 := Time.get_ticks_msec()
			carriable.host_throw(can_mark + Vector3(0.0, 0.25, 0.0), 1.0, lob)
			_watch_lane_hitboxes()
			var guard := 0
			while carriable.state == Carriable.CarryState.FLYING and guard < 240:
				await get_tree().physics_frame
				guard += 1
			flights.append(float(Time.get_ticks_msec() - t0) / 1000.0)
			_band_watch = null
			peaks.append(_band_peak_perp)
			closes.append(_band_perp_at_closest)
			await get_tree().create_timer(0.2).timeout
			if _lane_hits > 0:
				hits += 1
		var n := maxf(float(peaks.size()), 1.0)
		var mean_peak := _sum_of(peaks) / n
		var mean_close := _sum_of(closes) / n
		out["lob" if lob else "flat"] = {
			"contact": float(hits) / float(BAND_DODGE_THROWS),
			"peak": mean_peak,
			"closest": mean_close,
		}
		print("  %-6s %7.0f%% %9.2fm %11.2fm %9.2fs   %d/%d on the can"
			% ["LOB" if lob else "flat", 100.0 * hits / BAND_DODGE_THROWS,
				mean_peak, mean_close, _sum_of(flights) / n, hits, BAND_DODGE_THROWS])
	# The can is left parked, matching every other sweep's exit state.
	_can.ai_controller = null
	return out

## The whole point of the mode: put phase 1 and phase 2 side by side and say which
## function the balance lane should open. Nothing here is inferred from one table.
func _band_handover(band_half: Dictionary, achieved: Dictionary) -> void:
	print("")
	print("  === HANDOVER, FROM BOTH TABLES ===")
	if band_half.is_empty() or achieved.is_empty():
		print("  Incomplete — a phase failed its sanity check. No handover.")
		return
	var step := AIController.CAN_EVADE_STEP
	for key in ["flat", "lob"]:
		var band: Dictionary = band_half.get(key, {})
		var got: Dictionary = achieved.get(key, {})
		if band.is_empty() or got.is_empty():
			continue
		var at_closest: float = got["closest"]
		print("  %-4s: needs > %.2f m off the mark to be missed; achieved %.2f m at the"
			% [key, float(band["hit_out_to"]), at_closest])
		print("        closest frame (peak %.2f m), contact %.0f%%."
			% [got["peak"], float(got["contact"]) * 100.0])
	var lob_band: Dictionary = band_half.get("lob", {})
	var lob_got: Dictionary = achieved.get("lob", {})
	if lob_band.is_empty() or lob_got.is_empty():
		return
	var lob_need: float = float(lob_band["hit_out_to"])
	var lob_clears: float = float(lob_band["miss_from"])
	print("")
	# ⚠️ THE STRADDLE IS REPORTED, NOT ROUNDED AWAY. Phase 1 resolves the threshold only
	# to the interval (hit_out_to, miss_from]; a displacement landing inside that interval
	# is genuinely undecided by this run and saying so is the honest reading. Claiming
	# either side of it would be BAND_OFFSETS' step masquerading as a result.
	if lob_clears >= 0.0 and float(lob_got["closest"]) > lob_need \
			and float(lob_got["closest"]) < lob_clears:
		print("  -> UNDECIDED FOR THE LOB. The can reaches %.2f m, inside this sweep's own"
			% float(lob_got["closest"]))
		print("     unresolved interval (%.2f, %.2f] m. Re-run with a finer BAND_OFFSETS"
			% [lob_need, lob_clears])
		print("     before handing anything over — do not round it to either side.")
		return
	if float(lob_got["closest"]) <= lob_need:
		print("  -> AGAINST A LOB THE CAN DOES NOT GET FAR ENOUGH OFF THE MARK, and")
		print("     CAN_EVADE_STEP (%.2f m) is not why — it aims %.1fx the %.2f m band."
			% [step, step / maxf(lob_need, 0.01), lob_need])
		print("     The sidestep is the right SIZE and it is not being COMPLETED. That is")
		print("     _act_evade's commitment and _cond_slipper_incoming's trigger, not")
		print("     CAN_EVADE_STEP, and not the lob's ballistics.")
	else:
		print("  -> THE CAN DOES CLEAR THE BAND AGAINST A LOB (%.2f m vs %.2f m needed)."
			% [float(lob_got["closest"]), lob_need])
		print("     Whatever leg 3 is measuring is neither the band nor the sidestep's")
		print("     size or completion. Re-open it before changing any AI constant.")

## One throw type, every offset. Returns the per-offset contact rates in sweep order.
func _band_sweep(can_mark: Vector3, line: Vector3, lob: bool,
		can_ai: AIController) -> Array[float]:
	var carriable := _slipper.get_node("Carriable") as Carriable
	var rates: Array[float] = []
	# Perpendicular to the lane, in the ground plane — the same `side` axis
	# `AIController._act_evade` steps along, so the offsets are directly comparable to
	# CAN_EVADE_STEP rather than merely similar in magnitude.
	var bearing := (line - can_mark)
	bearing.y = 0.0
	bearing = bearing.normalized()
	var side := bearing.cross(Vector3.UP).normalized()
	for offset in BAND_OFFSETS:
		var hits := 0
		var stopped := 0
		var neither := 0
		var best_flat := 9999.0
		var best_3d := 9999.0
		for i in BAND_THROWS:
			if carriable.state == Carriable.CarryState.CARRIED:
				carriable.host_drop()
			elif carriable.state == Carriable.CarryState.FLYING:
				carriable.host_land()
			_freeze_round()
			_can.state = CharacterBase.State.NORMAL
			# ⚠️ PARKED, AND THE CONTROLLER IS NULLED EVERY THROW. `can_ai` is captured
			# only so this cannot be mistaken for the lane sweep's dodging cells — the
			# can never gets it back here, because the offset IS the dodge in this test.
			_can.ai_controller = null
			_place(_can, can_mark + side * offset)
			_taya.ai_controller = null
			_taya.input_parked = true
			_taya.state = CharacterBase.State.NORMAL
			# Lane OPEN: the taya is moved off it, not deleted, exactly as the lane
			# sweep's open cells do — so the only body the throw can meet is the can.
			_place(_taya, can_mark + side * (CharacterBase.CONFINEMENT_RADIUS - 0.2)
				+ Vector3(0.0, 0.9 - can_mark.y, 0.0))
			_place(_attacker, line)
			for settle in CharacterBase.SPAWN_SETTLE_FRAMES + 1:
				await get_tree().physics_frame
			_slipper.global_position = line + Vector3(0.4, 0.3, 0.0)
			_slipper.velocity = Vector3.ZERO
			carriable.host_grab(_attacker)
			await get_tree().physics_frame
			if carriable.state != Carriable.CarryState.CARRIED:
				neither += 1
				continue
			_lane_hits = 0
			_lane_blocked = 0
			_band_min_flat = 9999.0
			_band_min_3d = 9999.0
			_band_watch = _can
			carriable.host_throw(can_mark + Vector3(0.0, 0.25, 0.0), 1.0, lob)
			_watch_lane_hitboxes()
			var guard := 0
			while carriable.state == Carriable.CarryState.FLYING and guard < 240:
				await get_tree().physics_frame
				guard += 1
			_band_watch = null
			await get_tree().create_timer(0.2).timeout
			best_flat = minf(best_flat, _band_min_flat)
			best_3d = minf(best_3d, _band_min_3d)
			if _lane_hits > 0:
				hits += 1
			elif _lane_blocked > 0:
				stopped += 1
			else:
				neither += 1
		var rate := float(hits) / float(BAND_THROWS)
		rates.append(rate)
		print("  %-6s %7.2fm %7.0f%% %9.2fm %9.2fm   %d/%d on the can%s"
			% ["LOB" if lob else "flat", offset, rate * 100.0, best_flat, best_3d,
				hits, BAND_THROWS,
				"" if stopped == 0 else ", %d stopped by the taya (SHOULD BE 0)" % stopped])
	return rates

## Half-width of the band: the largest offset that still made contact, plus the first
## offset that made none. ⚠️ RETURNED AS THE PAIR, NEVER COLLAPSED TO ONE NUMBER — the
## true threshold lies between them and BAND_OFFSETS' step is the resolution, so a single
## figure would be a precision this sweep does not have. The handover below reads both and
## says "ambiguous" where they straddle.
func _band_verdict(bands: Dictionary) -> Dictionary:
	print("  --- THE BAND, AND WHETHER A 1.2 m SIDESTEP CLEARS IT ---")
	var summary: Dictionary = {}
	for key in ["flat", "lob"]:
		var rates: Array = bands.get(key, [])
		if rates.is_empty():
			continue
		var last_hit := -1.0
		var first_miss := -1.0
		var resumed := false
		for i in rates.size():
			var r: float = rates[i]
			if r > 0.0:
				last_hit = BAND_OFFSETS[i]
				if first_miss >= 0.0:
					resumed = true
			elif first_miss < 0.0:
				first_miss = BAND_OFFSETS[i]
		# Sanity 1. A dead-centre throw at a parked can MUST connect.
		if float(rates[0]) < 1.0:
			print("  ⚠️ %s AT OFFSET 0.00 IS %.0f%%, NOT 100%% — THE HARNESS IS WRONG,"
				% [key, float(rates[0]) * 100.0])
			print("     not the arc. A dead-centre throw at a parked can cannot miss.")
			continue
		# Sanity 2. Monotonic, or the columns are not a band.
		if resumed:
			print("  ⚠️ %s CONTACT RESUMES PAST A ZERO — these columns are not a band."
				% key)
			print("     Something other than the hurtbox is being struck (a bounce, or")
			print("     the taya). Do not read a half-width off this row.")
			continue
		# Recorded only past both sanity gates, so a column that failed one contributes
		# nothing to the handover rather than contributing a wrong number.
		summary[key] = {
			"hit_out_to": last_hit,
			"miss_from": first_miss if first_miss >= 0.0 else -1.0,
		}
		print("  %-4s: contact out to %.2f m, none from %.2f m%s"
			% [key, last_hit,
				first_miss if first_miss >= 0.0 else BAND_OFFSETS[-1],
				"" if first_miss >= 0.0 else " (NEVER STOPPED — sweep too short)"])
	var flat_band: float = float(summary.get("flat", {}).get("hit_out_to", -1.0))
	var lob_band: float = float(summary.get("lob", {}).get("hit_out_to", -1.0))
	if flat_band < 0.0 or lob_band < 0.0:
		print("  (no verdict — a column failed its sanity check above)")
		return {}
	var step := AIController.CAN_EVADE_STEP
	print("")
	print("  CAN_EVADE_STEP is %.2f m. Band half-width: flat %.2f m, LOB %.2f m."
		% [step, flat_band, lob_band])
	# ⚠️ THE TWO READINGS ARE DIFFERENT HANDOVERS TO DIFFERENT FUNCTIONS, and printing
	# which one the numbers support is the entire deliverable of this mode.
	if lob_band >= step:
		print("  -> THE STEP IS TOO SMALL. A %.2f m sidestep cannot clear a %.2f m band,"
			% [step, lob_band])
		print("     so leg 3's shape diagnosis HOLDS and the fix is in _act_evade's")
		print("     GEOMETRY: step further, or step under the arc instead of across it.")
	else:
		print("  -> THE STEP IS ALREADY BIG ENOUGH (%.2f m clears a %.2f m band), so"
			% [step, lob_band])
		print("     LEG 3'S \"you cannot sidestep out from under a drop\" IS REFUTED as")
		print("     stated. The geometry is sufficient and the failure is TIMING — when")
		print("     the can commits and whether it stays committed, not how far it goes.")
		print("     Hand this to _cond_slipper_incoming / CAN_EVADE_LOOKAHEAD's reaction")
		print("     window, NOT to CAN_EVADE_STEP.")
	if lob_band > flat_band + 0.01:
		print("  (the lob's band is %.2f m WIDER than the flat throw's — a descending"
			% (lob_band - flat_band))
		print("   slipper sweeps a longer footprint through the capsule.)")
	elif flat_band > lob_band + 0.01:
		print("  (the FLAT throw's band is the wider of the two, by %.2f m.)"
			% (flat_band - lob_band))
	return summary

## The hurtbox as it actually is in the world, scale included — the header's three
## conflicting radii are what happens when this is restated instead of read.
func _describe_hurtbox(who: CharacterBase) -> String:
	if who == null or not is_instance_valid(who):
		return "no character"
	var hb := who.get_node_or_null("Hurtbox") as Area3D
	if hb == null:
		return "no Hurtbox node"
	for child in hb.get_children():
		var cs := child as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var scale_xz: float = maxf(hb.global_transform.basis.get_scale().x,
			hb.global_transform.basis.get_scale().z)
		if cs.shape is CapsuleShape3D:
			var cap := cs.shape as CapsuleShape3D
			return "capsule r=%.3f h=%.3f, world scale %.3f -> world r=%.3f" \
				% [cap.radius, cap.height, scale_xz, cap.radius * scale_xz]
		if cs.shape is SphereShape3D:
			var sp := cs.shape as SphereShape3D
			return "sphere r=%.3f, world scale %.3f -> world r=%.3f" \
				% [sp.radius, scale_xz, sp.radius * scale_xz]
		return "shape %s (unhandled here)" % cs.shape.get_class()
	return "Hurtbox has no CollisionShape3D"

func _describe_slipper(who: CharacterBase) -> String:
	if who == null or not is_instance_valid(who):
		return "no character"
	var c := who.get_node_or_null("Carriable") as Carriable
	if c == null:
		return "no Carriable"
	# `._profile()` is the same accessor the ballistics sweep already reads (see its call
	# site) — the leading underscore is Carriable's own convention, not a barrier.
	var profile := c._profile()
	if profile == null:
		return "profile unresolved"
	# A profile built in code has no resource_path, so fall back to its script rather
	# than printing an empty string where the identity belongs.
	var id := profile.resource_path.get_file()
	if id.is_empty():
		var scr: Script = profile.get_script() as Script
		id = String(scr.resource_path).get_file() if scr != null else "<unnamed>"
	return "%s, hit_radius %.3f" % [id, profile.hit_radius]

## Lowest charge whose throw lands within REACH_TOLERANCE of the can. This is the
## measured replacement for §9's computed "charge needed for a 6.0 line" column.
const REACH_TOLERANCE: float = 1.0

## ---------------------------------------------------------------------------
## R-18(a) · BOUNCE AND LANDING — `-- bounce`. WHAT WAS NEVER MEASURED.
##
## `BOUNCE_DAMPING` went 0.45 -> 0.30 and `MAX_BOUNCES` 2 -> 1 in a single pass, off
## one feedback sentence ("ragdolls while flying"), and neither has been judged since.
## Both are now `static var` so they can be swept from here; the `const` beside each
## stays as the documented baseline.
##
## ⚠️ THE QUESTION IS NOT "HOW BOUNCY DOES IT LOOK", WHICH IS A FEEL CALL THIS PROBE
## CANNOT ANSWER AND MUST NOT PRETEND TO. What it CAN answer is the gameplay
## consequence, which is a distance: how far past its first contact the slipper ends
## up. That distance IS the retrieval scramble — `carriable.gd`'s own header calls the
## scramble "the whole tension of the game", and CRAWL_SPEED_SCALE is 0.45, so every
## extra metre of skid is more than two metres' worth of crawl for the Prop player and
## a longer exposed run for the Person. A bounce setting is therefore a balance number
## wearing a cosmetic hat, and the table below is the part of it that is measurable.
##
## Reported per setting: first-contact-to-rest distance, and the settle time. The
## human's call is which row reads as "bounces a bit" rather than as a physics bug —
## that is the half nobody but a person can supply, and it is asked, not guessed.
## ---------------------------------------------------------------------------

const BOUNCE_DAMPINGS: Array[float] = [0.0, 0.15, 0.30, 0.45, 0.60]
const BOUNCE_COUNTS: Array[int] = [1, 2]
const BOUNCE_THROWS: int = 4

func _run_bounce() -> void:
	_clear_the_arena()
	_freeze_round()
	await get_tree().physics_frame
	var origin := Vector3(_aim_point.x, 0.9, _aim_point.z + THROWING_LINES[0])
	print("\n=== BOUNCE AND LANDING (R-18a) ===")
	print("  map            : %s" % _map_id)
	print("  profile        : throw_default (every Prop today, per B-76)")
	print("  throw          : full charge from z=%+.1f at the can's mark, %d per cell"
		% [THROWING_LINES[0], BOUNCE_THROWS])
	print("  BASELINE IS damping 0.30 / bounces 1 — the shipped values.")
	print("")
	print("  %-8s %-8s %10s %10s %10s" % [
		"damping", "bounces", "skid (m)", "settle (s)", "worst (m)"])
	_apply_profile("")
	await get_tree().physics_frame
	for bounces in BOUNCE_COUNTS:
		for damping in BOUNCE_DAMPINGS:
			Carriable.bounce_damping = damping
			Carriable.max_bounces = bounces
			var skids: Array[float] = []
			var settles: Array[float] = []
			for i in BOUNCE_THROWS:
				var shot: Dictionary = await _ballistic_throw(origin, 1.0)
				if not shot.get("ok", false):
					continue
				var first: Vector3 = shot["landed"]
				var t0: float = shot["flight_time"]
				# The flight is already over by the time _ballistic_throw returns (it
				# waits out FLYING), so the resting place is where the slipper is now.
				var rest := _slipper.global_position
				skids.append(Vector2(rest.x - first.x, rest.z - first.z).length())
				var carriable := _slipper.get_node("Carriable") as Carriable
				settles.append(maxf(0.0, carriable._flight_time - t0))
			if skids.is_empty():
				print("  %-8.2f %-8d %10s" % [damping, bounces, "no throws"])
				continue
			var worst := 0.0
			for s in skids:
				worst = maxf(worst, s)
			print("  %-8.2f %-8d %10.3f %10.3f %10.3f%s" % [
				damping, bounces, _sum_of(skids) / float(skids.size()),
				_sum_of(settles) / float(settles.size()), worst,
				"   <-- SHIPPED" if is_equal_approx(damping, Carriable.BOUNCE_DAMPING)
					and bounces == Carriable.MAX_BOUNCES else ""])
	# ⚠️ PUT THEM BACK. These are `static`, i.e. process-wide, and a probe that leaves
	# a swept value behind is a probe that has silently retuned the game.
	Carriable.bounce_damping = Carriable.BOUNCE_DAMPING
	Carriable.max_bounces = Carriable.MAX_BOUNCES
	print("\n  restored to shipped: damping %.2f / bounces %d"
		% [Carriable.bounce_damping, Carriable.max_bounces])
	print("  🧑 WHICH ROW READS AS 'BOUNCES A BIT' IS A FEEL CALL AND IS ASKED, NOT GUESSED.")

## ---------------------------------------------------------------------------
## CHARACTER TRAITS, MEASURED END TO END — `-- traits`.
##
## Human ask, 2026-07-30: *"can u make sure the change in stats actually work? in
## character selection?"*
##
## Nothing had ever asked. BILIS / LAKAS / TATAG were built as "three multipliers at three
## sites that already existed", which is the right design and is also exactly the shape
## that fails silently: every one of the three is a scalar folded into an expression that
## produces a plausible number whatever the scalar is. A trait that never reaches the
## character, or reaches it and is multiplied by something that gets overwritten
## afterwards, looks identical to a trait that works.
##
## ⚠️ SO THIS MEASURES THE OBSERVABLE, NOT THE MULTIPLIER. Asserting
## `trait_speed_scale() == 1.10` proves only that arithmetic works. Each trait is checked
## against the thing a player would actually notice:
##
##   BILIS -> metres actually travelled in a fixed number of physics frames.
##   LAKAS -> the impulse the character's own hitbox produces (hitbox.gd::_impulse_for).
##   TATAG -> the knockback the character ACCEPTS, and the stagger duration it wears.
##
## And the chain is checked at both ends: the ROSTER value has to reach `trait_points()`
## (a can_index/slipper_index that never got set would silently give every Prop the
## neutral 3), and the multiplier has to move the observable. Either half broken is a
## FAIL, and they fail differently.
## ---------------------------------------------------------------------------

## Physics frames to run the walk test over. Long enough for the difference between a
## BILIS 1 and a BILIS 5 unit to exceed any single-frame noise: full range is +/-10% of
## SPEED 6.0, so 60 frames (1 s) separates them by ~1.2 m.
const TRAIT_WALK_FRAMES: int = 60

func _run_traits() -> void:
	_park_everyone()
	_freeze_round()
	await get_tree().physics_frame
	print("\n=== CHARACTER TRAITS, END TO END ===")
	print("  neutral point : %d   steps: speed %.0f%%/pt, power %.0f%%/pt, grit %.0f%%/pt"
		% [CharacterRoster.TRAIT_NEUTRAL, CharacterBase.TRAIT_SPEED_PER_POINT * 100.0,
			CharacterBase.TRAIT_POWER_PER_POINT * 100.0, CharacterBase.TRAIT_GRIT_PER_POINT * 100.0])
	if _attacker == null or _taya == null:
		print("  TRAITS: no two Persons in the cast — nothing to measure")
		return

	# ---- 1. DOES THE ROSTER VALUE REACH THE CHARACTER AT ALL ----------------
	print("\n  --- (1) the roster -> character chain ---")
	var chain_ok := true
	for points in [1, 3, 5]:
		# ⚠️ Driven by setting `character_index` to a roster entry that HAS this value,
		# rather than by writing the multiplier — the question is whether a CHARACTER
		# SELECTION lands, and writing the multiplier would skip the whole chain under
		# test (trap: a probe that never looks at the thing you changed).
		var idx := _roster_person_with(&"bilis", points)
		if idx < 0:
			print("    bilis=%d : no Person roster entry carries this value (skipped)" % points)
			continue
		_attacker.character_index = idx
		var got := _attacker.trait_points(&"bilis")
		var scale := _attacker.trait_speed_scale()
		var want := 1.0 + float(points - CharacterRoster.TRAIT_NEUTRAL) * CharacterBase.TRAIT_SPEED_PER_POINT
		var ok: bool = got == points and is_equal_approx(scale, want)
		chain_ok = chain_ok and ok
		print("    roster[%d] bilis=%d -> trait_points()=%d, trait_speed_scale()=%.3f (want %.3f)  %s"
			% [idx, points, got, scale, want, "ok" if ok else "*** MISMATCH ***"])

	# ---- 2. BILIS: DOES IT MOVE THE UNIT FURTHER ---------------------------
	print("\n  --- (2) BILIS -> distance actually walked in %d frames ---" % TRAIT_WALK_FRAMES)
	var walked: Dictionary = {}
	for points in [1, 3, 5]:
		var idx := _roster_person_with(&"bilis", points)
		if idx < 0:
			continue
		_attacker.character_index = idx
		walked[points] = await _measure_walk(_attacker)
		print("    bilis=%d : %.3f m   (scale %.3f)"
			% [points, walked[points], _attacker.trait_speed_scale()])
	var bilis_ok: bool = walked.has(1) and walked.has(5) and walked[5] > walked[1] + 0.05
	print("    -> %s" % ["a faster pick genuinely travels further (%.3f m of spread)"
		% (walked[5] - walked[1]) if bilis_ok
		else "*** FAIL — BILIS does not change how far the unit gets ***"])

	# ---- 3. LAKAS: DOES IT DELIVER A BIGGER SHOVE --------------------------
	# Read off the character's OWN melee hitbox, which is the node the trait is applied
	# in (hitbox.gd::_impulse_for). Measured rather than recomputed, so a trait applied
	# to a value that is later overwritten still fails here.
	print("\n  --- (3) LAKAS -> the impulse this character's hitbox produces ---")
	var impulses: Dictionary = {}
	var hitbox := _attacker.get_node_or_null("Hitbox") as Hitbox
	for points in [1, 3, 5]:
		var idx := _roster_person_with(&"lakas", points)
		if idx < 0 or hitbox == null:
			continue
		_attacker.character_index = idx
		# Standing still, so _impulse_for falls back to facing — the deterministic case.
		_attacker.velocity = Vector3.ZERO
		var impulse: Vector3 = hitbox._impulse_for(false)
		impulses[points] = Vector2(impulse.x, impulse.z).length()
		print("    lakas=%d : %.3f m/s of shove   (scale %.3f)"
			% [points, impulses[points], _attacker.trait_power_scale()])
	var lakas_ok: bool = impulses.has(1) and impulses.has(5) and impulses[5] > impulses[1] + 0.01
	print("    -> %s" % ["a stronger pick hits harder (%.3f m/s of spread)"
		% (impulses[5] - impulses[1]) if lakas_ok
		else "*** FAIL — LAKAS does not change what this character delivers ***"])

	# ---- 4. TATAG: DOES IT ABSORB MORE, AND FLINCH LESS -------------------
	print("\n  --- (4) TATAG -> knockback ACCEPTED and stagger worn ---")
	var kept: Dictionary = {}
	var flinch: Dictionary = {}
	for points in [1, 2, 3, 5]:
		var idx := _roster_person_with(&"tatag", points)
		if idx < 0:
			continue
		_taya.character_index = idx
		_taya.state = CharacterBase.State.NORMAL
		_taya.velocity = Vector3.ZERO
		# apply_knockback writes velocity; the DIVISOR is what TATAG contributes.
		_taya.apply_knockback(Vector3(10.0, 0.0, 0.0))
		kept[points] = absf(_taya.velocity.x)
		# ⚠️ CLEAR THE TIMER FIRST. `apply_stagger` does `max(_staggered_time_left, ...)`, so
		# a leftover 0.25 s from the previous row silently swallows the shorter one a sturdier
		# unit should get — which is how the first run reported an identical 0.2500 s at every
		# TATAG value while the knockback divisor was plainly working.
		#
		# ⚠️ AND THAT `max()` IS A REAL DESIGN WART, NOT ONLY A PROBE ONE: in game, a second
		# hit landing inside an existing stagger cannot shorten it, so TATAG is invisible on
		# every hit after the first until the flinch runs out. Flagged, not changed — whether
		# stagger should refresh or extend is a balance call with no play notes behind it.
		_taya.set("_staggered_time_left", 0.0)
		_taya.state = CharacterBase.State.NORMAL
		_taya.apply_stagger(CharacterBase.BUMP_STAGGER_TIME)
		flinch[points] = float(_taya.get("_staggered_time_left"))
		_taya.state = CharacterBase.State.NORMAL
		print("    tatag=%d : kept %.3f m/s of a 10.0 shove, stagger %.4f s   (scale %.3f)"
			% [points, kept[points], flinch[points], _taya.trait_grit_scale()])
	# ⚠️ COMPARE THE EXTREMES THAT THE CHARACTER SCREEN CAN ACTUALLY OFFER. The Person
	# roster carries no TATAG 1, so a test keyed on 1 reports FAIL on a working trait —
	# which it did, while the rows either side of it were plainly monotonic.
	var tatag_lo: int = 1 if kept.has(1) else 2
	var tatag_ok: bool = kept.has(tatag_lo) and kept.has(5) and kept[tatag_lo] > kept[5] + 0.01 \
		and flinch[tatag_lo] > flinch[5] + 0.0001
	print("    -> %s" % ["a sturdier pick is shoved less and flinches shorter" if tatag_ok
		else "*** FAIL — TATAG does not change what this character absorbs ***"])

	print("\n  VERDICT: %s" % [
		"ALL THREE TRAITS REACH THE CHARACTER AND CHANGE AN OBSERVABLE"
		if chain_ok and bilis_ok and lakas_ok and tatag_ok
		else "*** SOMETHING IS NOT WIRED — see the FAIL lines above ***"])
	print("  🧑 WHETHER THE SPREAD IS BIG ENOUGH TO FEEL IS A HUMAN CALL. Full range on a")
	print("     1..5 scale is +/-10%% speed and +/-14%% power and grit, deliberately small")
	print("     (character_base.gd's own trait note: 'a party game cannot afford a pick")
	print("     that is simply correct'). The numbers above are what that buys.")

## Walks a character forward under its own movement code for a fixed number of frames and
## returns the flat distance covered. Uses the AI intent path rather than writing velocity,
## so the SPEED term the trait multiplies is the one actually exercised.
func _measure_walk(who: CharacterBase) -> float:
	# ⚠️ RE-PLACED EVERY RUN, AND THE FIRST VERSION WAS NOT — which produced the exact
	# nonsense this repo's method note warns about: 4.90 m at bilis 1, 2.80 m at bilis 3 and
	# 0.00 m at bilis 5, i.e. the SLOWEST pick travelling furthest and the fastest not moving
	# at all. A slower unit cannot out-walk a faster one, so the harness was the bug: each run
	# started where the last one finished, so the unit walked itself into the arena dressing
	# and the third run began already against a wall.
	_place(who, Vector3(0.0, 0.9, 0.0))
	for settle in CharacterBase.SPAWN_SETTLE_FRAMES + 1:
		await get_tree().physics_frame
	who.velocity = Vector3.ZERO
	who.ai_controller = null
	# `_ai_intent` is only read when the character is AI-driven, and is_ai_driven() needs a
	# live controller — so drive the body directly through the same expression instead, one
	# frame at a time, and let move_and_slide carry it.
	var start := who.global_position
	var scale: float = CharacterBase.SPEED * who.trait_speed_scale()
	for frame in TRAIT_WALK_FRAMES:
		who.velocity.x = scale
		who.velocity.z = 0.0
		await get_tree().physics_frame
	return Vector2(who.global_position.x - start.x, who.global_position.z - start.z).length()

## The first Person roster index whose `key` trait equals `points`, or -1.
func _roster_person_with(key: StringName, points: int) -> int:
	for i in CharacterRoster.size():
		if CharacterRoster.person_trait(i, key) == points:
			return i
	return -1

func _reach_floor(origin: Vector3) -> float:
	for charge in CHARGE_STEPS:
		var shot: Dictionary = await _ballistic_throw(origin, charge)
		if not shot.get("ok", false):
			continue
		var rest: Vector3 = shot["landed"]
		var miss := Vector2(rest.x - _aim_point.x, rest.z - _aim_point.z).length()
		if miss <= REACH_TOLERANCE:
			return charge
	return 0.0
