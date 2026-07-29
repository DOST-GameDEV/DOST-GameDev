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

func _physics_process(_d: float) -> void:
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
## ⚠️⚠️ THE NUMBERS THIS MODE CURRENTLY PRINTS ARE NOT TRUSTWORTHY. DO NOT QUOTE
## THEM, AND DO NOT TUNE ANYTHING AGAINST THEM. Status 2026-07-29: the harness
## faults below are fixed (state reset between throws, cast re-resolved as roles
## swap, can healed so the round cannot end mid-sweep) and it now produces output
## for all 8 cells — but the output fails its own sanity checks:
##
##   * `throw_default` (launch_speed 21.0) reports NEVER REACHES the 6.0 line
##     while `throw_bakya` (19.0, and HEAVIER at gravity_scale 1.35) reaches it
##     at 50% charge. A slower, heavier profile cannot out-range a faster one;
##     one of the two readings is wrong.
##   * Scatter runs 3-9 m across eight IDENTICAL full-charge throws at a solved
##     arc. These should be near-deterministic; metres of spread means something
##     the probe does not control is varying per throw.
##
## Two suspects, neither confirmed: (a) `_slipper.is_on_floor()` may never go
## true for a slipper flown by move_and_collide, so "first ground contact" is
## silently falling back to wherever the FLYING state happened to end, i.e. after
## bounce and roll; (b) throws that strike the can end their flight ON it while
## throws that miss sail past, so the two populations are being averaged together
## into one meaningless mean.
##
## The fix is to record the landing off the flight code's own landing event
## rather than inferring it, and to separate hits from misses before averaging.
## Until that is done this mode measures the harness, not the ballistics.
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
const BALLISTIC_THROWS: int = 8
## Charge steps for the reach floor. CHARGE_MIN_POWER is 0.35, so below that is
## not a state the game can produce.
const CHARGE_STEPS: Array[float] = [0.35, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

func _park_everyone() -> void:
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		ch.ai_controller = null
		ch.velocity = Vector3.ZERO

## ⚠️ RE-RESOLVE THE CAST, AND KEEP THE ROUND FROM ENDING. Both halves are here
## because of the same failure, and it is a good example of trap 1 in reverse —
## the probe was measuring a state the game had already moved on from.
##
## The sweep fires ~16 throws per cell. Those dent the can, the can reaches
## MAX_DENTS, THE ROUND ENDS, and `_reset_world()` swaps every role. The cached
## `_attacker` is then on the CAN's team, so `carriable.gd::can_be_grabbed_by()`
## rejects it on the team check ("an opponent's tsinelas: shove it, never pocket
## it") and every subsequent throw reports a grab failure. It read as "the probe
## cannot grab", which is why the first cell always passed and every cell after
## it failed 8/8 — the first cell is simply the one that runs before the can dies.
##
## So the can is healed between throws (this is a ballistics measurement, not a
## damage one) and the cast is re-derived from the CURRENT role flags rather than
## trusted from _ready().
func _refresh_cast() -> void:
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
	if _can != null:
		_can.dents = 0
		_can.global_position = Vector3(0.0, _can.global_position.y, 0.0)
		_can.velocity = Vector3.ZERO
	if _taya != null:
		_taya.global_position = Vector3(30.0, 0.9, 30.0)

## One throw from `origin` at `charge`, aimed at the can. Returns the slipper's
## resting position, or Vector3.INF if the grab never took (which is a probe
## failure, not a physics result, and is reported as such rather than averaged in).
func _ballistic_throw(origin: Vector3, charge: float) -> Vector3:
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
	# Heal the can every throw, not just every cell — MAX_DENTS is small enough
	# that one cell's 16 throws can kill it twice over. See _refresh_cast's doc.
	if _can != null:
		_can.dents = 0
	await get_tree().physics_frame
	_attacker.global_position = origin
	_attacker.velocity = Vector3.ZERO
	await get_tree().physics_frame
	# Same path the real game takes — loose, grabbed, thrown. Anything that skips
	# the grab tests a state the game never reaches (see the main series above).
	_slipper.global_position = origin + Vector3(0.4, 0.3, 0.0)
	_slipper.velocity = Vector3.ZERO
	await get_tree().physics_frame
	carriable.host_grab(_attacker)
	await get_tree().physics_frame
	if carriable.state != Carriable.CarryState.CARRIED:
		return Vector3.INF
	carriable.host_throw(_can.global_position + Vector3(0, 0.25, 0), charge)
	# ⚠️ FIRST GROUND CONTACT, NOT THE RESTING PLACE. Returning the position where
	# the slipper finally stops measures the throw PLUS the bounce PLUS the roll,
	# which is why the first run reported a 3.94 m "scatter" on a solved arc: a
	# throw from z=-6.0 aimed at the can showed a landing of z=+2.92, i.e. it had
	# skittered nearly 3 m PAST the target after touching down. Bounce and roll
	# are worth measuring, but they are not where the slipper LANDED.
	var guard := 0
	var landed := Vector3.INF
	while carriable.state == Carriable.CarryState.FLYING and guard < 400:
		await get_tree().physics_frame
		guard += 1
		if landed == Vector3.INF and _slipper.is_on_floor():
			landed = _slipper.global_position
	if landed == Vector3.INF:
		landed = _slipper.global_position
	return landed

func _run_ballistics() -> void:
	_park_everyone()
	# ⚠️ GET THE TAYA OUT OF THE ARC. Parking everyone leaves the defender standing
	# on its spawn mark, which sits between the throwing line and the can — so a
	# throw that hits it reports as a short landing and reads exactly like a reach
	# failure. A contested throw is what `target=taya` and the fairness harness
	# measure; this mode is the ballistics alone, and the two must not be mixed or
	# a shortfall is unattributable.
	if _taya != null:
		_taya.global_position = Vector3(30.0, 0.9, 30.0)
	await get_tree().physics_frame
	var can_pos := _can.global_position
	print("\n=== BALLISTICS SWEEP ===")
	print("  map            : %s" % _map_id)
	print("  can at         : (%.2f, %.2f, %.2f)" % [can_pos.x, can_pos.y, can_pos.z])
	print("  throwing lines : z = %.1f and z = %.1f  (%d throws each, full charge)"
		% [THROWING_LINES[0], THROWING_LINES[1], BALLISTIC_THROWS])
	print("  GRAVITY        : %.1f  (CharacterBase.GRAVITY, NOT 9.8)" % CharacterBase.GRAVITY)
	for entry in BALLISTIC_ABILITIES:
		var label: String = entry[0]
		var script_path: String = entry[1]
		_slipper.ability = null if script_path == "" else load(script_path).new()
		await get_tree().physics_frame
		var profile := (_slipper.get_node("Carriable") as Carriable)._profile()
		print("\n  --- %s  (speed %.1f, arc %.1f deg, gravity_scale %.2f) ---"
			% [label, profile.launch_speed, profile.arc_angle_deg, profile.gravity_scale])
		for line_z in THROWING_LINES:
			_refresh_cast()
			await get_tree().physics_frame
			var origin := Vector3(can_pos.x, can_pos.y, can_pos.z + line_z)
			var misses: Array[float] = []
			var lands: Array[Vector3] = []
			var failed := 0
			for i in BALLISTIC_THROWS:
				var rest: Vector3 = await _ballistic_throw(origin, 1.0)
				if rest == Vector3.INF:
					failed += 1
					continue
				lands.append(rest)
				misses.append(Vector2(rest.x - can_pos.x, rest.z - can_pos.z).length())
			if lands.is_empty():
				print("    line z=%+.1f : *** NO THROW LAUNCHED (%d grab failures) ***"
					% [line_z, failed])
				continue
			# Scatter, reported as spread about the MEAN LANDING POINT rather than
			# about the can — a throw that consistently lands 2 m short is precise
			# and wrong, and averaging those two together would hide it.
			var mean := Vector3.ZERO
			for p in lands:
				mean += p
			mean /= float(lands.size())
			var spread := 0.0
			for p in lands:
				spread = maxf(spread, Vector2(p.x - mean.x, p.z - mean.z).length())
			var mean_miss := _sum_of(misses) / float(misses.size())
			var reach_charge := await _reach_floor(origin)
			print("    line z=%+.1f : landed (%.2f, %.2f) | mean miss from can %.2f m | scatter %.2f m | reach floor %s%s"
				% [line_z, mean.x, mean.z, mean_miss, spread,
					("%.0f%% charge" % (reach_charge * 100.0)) if reach_charge > 0.0 else "*** NEVER REACHES ***",
					"" if failed == 0 else "  (%d grab failures)" % failed])

## Lowest charge whose throw lands within REACH_TOLERANCE of the can. This is the
## measured replacement for §9's computed "charge needed for a 6.0 line" column.
const REACH_TOLERANCE: float = 1.0

func _reach_floor(origin: Vector3) -> float:
	for charge in CHARGE_STEPS:
		var rest: Vector3 = await _ballistic_throw(origin, charge)
		if rest == Vector3.INF:
			continue
		var miss := Vector2(rest.x - _can.global_position.x, rest.z - _can.global_position.z).length()
		if miss <= REACH_TOLERANCE:
			return charge
	return 0.0
