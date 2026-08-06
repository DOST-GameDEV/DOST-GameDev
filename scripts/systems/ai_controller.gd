extends Node
class_name AIController



enum Difficulty { BATA, NORMAL, ASTIG }

const DIFFICULTY_TIERS: Dictionary = {
	Difficulty.BATA: {
		"react": 0.55, "think": 0.34, "lead": 0.00,
		"aim_error": 1.75, "aim_settle": 99.0, "power_margin": 1.04,
		"lane_patience": 0.0, "spacing": 0.15, "fetch_caution": 0.0,
		"sabotage": 0.0,
		"intercept": 0.0, "camp": 0.0, "lunge_range": 1.9, "lunge_cone": 55.0,
		"dodge": 0.0, "sprint_reserve": 0.0, "mistake": 0.30,
	},
	Difficulty.NORMAL: {
		"react": 0.30, "think": 0.24, "lead": 0.45,
		"aim_error": 1.45, "aim_settle": 1.40, "power_margin": 1.18,
		"lane_patience": 1.1, "spacing": 0.60, "fetch_caution": 3.2,
		"sabotage": 0.35,
		"intercept": 0.60, "camp": 0.45, "lunge_range": 2.6, "lunge_cone": 34.0,
		"dodge": 0.55, "sprint_reserve": 0.25, "mistake": 0.10,
	},
	Difficulty.ASTIG: {
		"react": 0.14, "think": 0.16, "lead": 0.85,
		"aim_error": 1.10, "aim_settle": 0.80, "power_margin": 1.32,
		"lane_patience": 2.2, "spacing": 1.00, "fetch_caution": 5.0,
		"sabotage": 0.85,
		"intercept": 1.00, "camp": 1.00, "lunge_range": 3.1, "lunge_cone": 28.0,
		"dodge": 1.00, "sprint_reserve": 0.45, "mistake": 0.02,
	},
}

static var difficulty: Difficulty = Difficulty.NORMAL
static var tuning: Dictionary = DIFFICULTY_TIERS[Difficulty.NORMAL]
static var tuning_stamp: int = 0

static var trace_enabled: bool = false

static func apply_difficulty(tier: Difficulty) -> void:
	difficulty = tier
	tuning = DIFFICULTY_TIERS[tier]
	tuning_stamp += 1


const REACH: float = 1.15
const THROW_STANDOFF: float = 1.2
const GUARD_RADIUS: float = 2.2
const ARRIVE_SLOP: float = 0.55
const ARRIVE_HYSTERESIS: float = 1.8
const GOAL_MOVED: float = 0.9

const SEPARATION_RADIUS: float = 1.45
const SEPARATION_WEIGHT: float = 0.65

const EIGHT_WAY_THRESHOLD: float = 0.3827

const SPRINT_DISTANCE: float = 5.0

const AIM_HEIGHT: float = 0.20
const AIM_REFERENCE_RANGE: float = 7.5
const AIM_RANGE_SCALE_MIN: float = 0.65
const AIM_RANGE_SCALE_MAX: float = 1.70
const AIM_SETTLE_FLOOR: float = 0.55

const WINDUP_TIMEOUT: float = 3.6
const WINDUP_MIN_HOLD_SHARE: float = 0.65

const LANE_SAMPLE_ARC: float = 0.45
const LANE_STEP_MIN: float = 0.012
const LANE_STEP_MAX: float = 0.050
const LANE_MAX_STEPS: int = 96

const LUNGE_HOLD_TIME: float = 0.5

const LUNGE_CONE_FLOOR: float = 26.0

const INTERCEPT_HORIZON: float = 1.4
const INTERCEPT_STEP: float = 0.04
const INTERCEPT_BAND: float = 0.45

const STALK_PATIENCE_BASE: float = 3.5

const STUCK_SPEED: float = 0.30
const STUCK_TRIGGER: float = 1.1
const UNSTICK_TIME: float = 0.65

const CLAIM_TTL: float = 1.2

const LOITER_LEASH: float = 0.45
const LOITER_STEP_MIN: float = 0.07
const LOITER_STEP_MAX: float = 0.13
const LOITER_REST_MIN: float = 1.1
const LOITER_REST_MAX: float = 2.8

class _Personality:
	var tempo: float = 1.0
	var hands: float = 1.0
	var nerves: float = 1.0
	var nerve_for_the_box: float = 1.0
	var home_bearing: float = 0.0
	var hesitation: float = 0.15

	func _init(seed_value: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("tumbang-preso-bot-%d" % seed_value)
		tempo = rng.randf_range(0.85, 1.20)
		hands = rng.randf_range(0.80, 1.25)
		nerves = rng.randf_range(0.85, 1.15)
		nerve_for_the_box = rng.randf_range(0.75, 1.30)
		home_bearing = rng.randf_range(-PI, PI)
		hesitation = rng.randf_range(0.05, 0.28)

static var _claims: Dictionary = {}

static var _flights: Dictionary = {}
static var _flights_frame: int = -1

var character: CharacterBase = null

var _enabled: bool = true
var _booted: bool = false
var _me: _Personality = null

var _stamp: int = -1
var _react: float = 0.30
var _think: float = 0.24
var _lead: float = 0.45
var _aim_error: float = 0.45
var _aim_settle: float = 1.20
var _power_margin: float = 1.18
var _lane_patience: float = 1.1
var _spacing: float = 0.60
var _fetch_caution: float = 3.2
var _sabotage: float = 0.35
var _intercept: float = 0.60
var _camp: float = 0.45
var _lunge_range: float = 2.6
var _lunge_cone: float = 34.0
var _dodge: float = 0.55
var _sprint_reserve: float = 0.25
var _mistake: float = 0.10

var _think_left: float = 0.0
var _commit_left: float = 0.0

var _seen_pos: Dictionary = {}
var _seen_vel: Dictionary = {}
var _gates: Dictionary = {}
var _pressed: Dictionary = {}

enum Plan {
	IDLE,
	FETCH,
	STALK,
	WITHDRAW,
	POSITION,
	WINDUP,
	EVADE,
	SABOTAGE,
	RESET,
	INTERCEPT,
	HUNT,
	COVER,
	GUARD,
}
var _plan: Plan = Plan.IDLE
var _goal: Vector3 = Vector3.ZERO
var _goal_valid: bool = false
var _arrived: bool = false

var _windup: bool = false
var _windup_time: float = 0.0
var _windup_power: float = 1.0
var _windup_scatter: Vector3 = Vector3.ZERO
var _windup_wait: float = 0.0
var _blundering: bool = false

var _lunge_held: float = -1.0
var _last_threat: CharacterBase = null
var _loiter_left: float = 0.0
var _loiter_dir: float = 0.0
var _stalk_time: float = 0.0
var _stuck_time: float = 0.0
var _unstick_left: float = 0.0
var _unstick_sign: float = 1.0
var _driving: bool = false
var _last_trace: String = ""

func _ready() -> void:
	if character == null:
		character = get_parent() as CharacterBase

func set_enabled(enabled: bool) -> void:
	if _enabled == enabled:
		return
	_enabled = enabled
	if not enabled and character != null:
		_release_all()
		character.ai_clear_intent()

func is_enabled() -> bool:
	return _enabled

func decide(delta: float) -> void:
	if not _enabled or character == null or not is_instance_valid(character):
		return
	if not _booted:
		_boot()
	if _stamp != tuning_stamp:
		_read_tuning()
	if not RoundManager.round_active or not character.can_act():
		_release_all()
		_plan = Plan.IDLE
		_windup = false
		return
	_observe(delta)
	_loiter_left = maxf(0.0, _loiter_left - delta)
	_stalk_time = _stalk_time + delta if _plan == Plan.STALK else 0.0
	_step_unstick(delta)
	_think_left -= delta
	_commit_left = maxf(0.0, _commit_left - delta)
	if _think_left <= 0.0 and _commit_left <= 0.0:
		_think_left = _think
		_replan(delta)
	_act(delta)

func _step_unstick(delta: float) -> void:
	if _unstick_left > 0.0:
		_unstick_left = maxf(0.0, _unstick_left - delta)
		return
	var speed := Vector2(character.velocity.x, character.velocity.z).length()
	if _driving and speed < STUCK_SPEED:
		_stuck_time += delta
		if _stuck_time >= STUCK_TRIGGER:
			_stuck_time = 0.0
			_unstick_left = UNSTICK_TIME
			_unstick_sign = -_unstick_sign
			_trace("UNSTICK")
	else:
		_stuck_time = 0.0
	_driving = false

func _boot() -> void:
	_booted = true
	_me = _Personality.new(character.player_slot)
	_read_tuning()
	_think_left = randf() * _think
	_loiter_dir = 0.0
	_loiter_left = randf() * LOITER_REST_MAX

func _read_tuning() -> void:
	_stamp = tuning_stamp
	var t: Dictionary = tuning
	var p := _me if _me != null else _Personality.new(0)
	_react = float(t["react"]) * p.nerves
	_think = float(t["think"]) * p.tempo
	_lead = float(t["lead"])
	_aim_error = float(t["aim_error"]) * p.hands
	_aim_settle = float(t["aim_settle"])
	_power_margin = float(t["power_margin"])
	_lane_patience = float(t["lane_patience"])
	_spacing = float(t["spacing"])
	_fetch_caution = float(t["fetch_caution"]) / p.nerve_for_the_box
	_sabotage = float(t["sabotage"]) * p.nerve_for_the_box
	_intercept = float(t["intercept"])
	_camp = float(t["camp"])
	_lunge_range = float(t["lunge_range"])
	_lunge_cone = maxf(float(t["lunge_cone"]), LUNGE_CONE_FLOOR)
	_dodge = float(t["dodge"])
	_sprint_reserve = float(t["sprint_reserve"])
	_mistake = float(t["mistake"])

func _observe(delta: float) -> void:
	var alpha := 1.0 - exp(-delta / maxf(_react, 0.02))
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		var slot := who.player_slot
		var truth := who.global_position
		var flat_velocity := Vector3(who.velocity.x, 0.0, who.velocity.z)
		if not _seen_pos.has(slot):
			_seen_pos[slot] = truth
			_seen_vel[slot] = flat_velocity
			continue
		if who == character:
			_seen_pos[slot] = truth
			_seen_vel[slot] = flat_velocity
			continue
		_seen_pos[slot] = (_seen_pos[slot] as Vector3).lerp(truth, alpha)
		_seen_vel[slot] = (_seen_vel[slot] as Vector3).lerp(flat_velocity, alpha)
	_track_flights()

func _track_flights() -> void:
	var frame := Engine.get_physics_frames()
	if _flights_frame == frame:
		return
	_flights_frame = frame
	var seen: Dictionary = {}
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null or not slipper.is_flying():
			continue
		var id := slipper.get_instance_id()
		seen[id] = true
		var here := slipper.global_position
		var record: Dictionary = _flights.get(id, {})
		var last_frame := int(record.get("frame", -99))
		var velocity := Vector3.ZERO
		if frame - last_frame == 1:
			var step := 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)
			velocity = (here - (record["pos"] as Vector3)) / step
		_flights[id] = {"pos": here, "vel": velocity, "frame": frame, "node": slipper}
	for id in _flights.keys():
		if not seen.has(id):
			_flights.erase(id)

func _at(who: CharacterBase) -> Vector3:
	if who == null:
		return Vector3.ZERO
	return _seen_pos.get(who.player_slot, who.global_position)

func _ahead_of(who: CharacterBase, horizon: float) -> Vector3:
	if who == null:
		return Vector3.ZERO
	var base := _at(who)
	var velocity: Vector3 = _seen_vel.get(who.player_slot, Vector3.ZERO)
	return base + velocity * horizon * _lead

func _reacted(key: String, condition: bool, delta: float) -> bool:
	if not condition:
		_gates[key] = 0.0
		return false
	var held := float(_gates.get(key, 0.0)) + delta
	_gates[key] = held
	return held >= _react

func _replan(delta: float) -> void:
	var chosen := _plan_defender(delta) if character.is_defender else _plan_attacker(delta)
	if chosen == _plan:
		return
	_commit_left = _me.hesitation
	_plan = chosen
	_arrived = false
	if chosen != Plan.POSITION:
		_goal_valid = false
	if chosen != Plan.WINDUP:
		_windup = false
	_trace(_plan_name(chosen))

func _plan_attacker(delta: float) -> Plan:
	var lata := RoundManager.lata
	var taya := RoundManager.defender()

	if _should_evade(taya, delta):
		return Plan.EVADE

	if _sabotage_target(taya) != null:
		return Plan.SABOTAGE
	if not character.holding_slipper():
		var mine := _my_slipper()
		if mine == null:
			return Plan.POSITION
		if mine.is_flying():
			return Plan.POSITION
		if _fetch_is_safe(mine, taya):
			return Plan.FETCH
		return Plan.STALK

	if character.is_inside_box():
		return Plan.WITHDRAW
	if lata == null or not lata.is_upright or not RoundManager.can_throw(character):
		if _sabotage_target(taya) != null:
			return Plan.SABOTAGE
		return Plan.POSITION
	if _sabotage_target(taya) != null:
		return Plan.SABOTAGE
	if _throw_locked():
		return Plan.POSITION
	if _arrived and _plan in [Plan.POSITION, Plan.WINDUP]:
		return Plan.WINDUP
	if _plan == Plan.WINDUP:
		return Plan.WINDUP
	return Plan.POSITION

func _throw_locked() -> bool:
	var carrier := character.get_node_or_null("Carrier") as Carrier
	return carrier != null and carrier.throw_lock_left() > 0.0

func _plan_defender(delta: float) -> Plan:
	var lata := RoundManager.lata
	if lata == null:
		return Plan.IDLE
	if not lata.is_upright:
		return Plan.RESET
	if _intercept > 0.0 and _intercept_point(lata) != Vector3.INF:
		if _reacted("incoming", true, delta):
			return Plan.INTERCEPT
	else:
		_gates["incoming"] = 0.0
	if _tag_target() != null:
		return Plan.HUNT
	if _camp > 0.0 and _cover_point(lata) != Vector3.INF:
		return Plan.COVER
	return Plan.GUARD

func _act(delta: float) -> void:
	_touched.clear()
	match _plan:
		Plan.IDLE:
			_do_idle()
		Plan.FETCH:
			_do_fetch()
		Plan.STALK:
			_do_stalk()
		Plan.WITHDRAW:
			_do_withdraw()
		Plan.POSITION:
			_do_position()
		Plan.WINDUP:
			_do_windup(delta)
		Plan.EVADE:
			_do_evade()
		Plan.SABOTAGE:
			_do_sabotage()
		Plan.RESET:
			_do_reset()
		Plan.INTERCEPT:
			_do_intercept()
		Plan.HUNT:
			_do_hunt(delta)
		Plan.COVER:
			_do_cover()
		Plan.GUARD:
			_do_guard()
	if not _touched.has("special_ability"):
		_press("special_ability", false)
	if _plan != Plan.WINDUP:
		_windup = false
	if not _touched.has("lunge"):
		_press("lunge", false)
	if _plan != Plan.HUNT:
		_lunge_held = -1.0
	if not _touched.has("grab"):
		_press("grab", false)


func _do_fetch() -> void:
	var mine := _my_slipper()
	if mine == null:
		_stop()
		return
	var where := mine.global_position
	var distance := _flat(character.global_position, where)
	var hurry := distance > REACH and (_mine_is_exposed(mine) or distance > SPRINT_DISTANCE)
	_goto(where, REACH * 0.75, hurry)
	if distance <= REACH:
		_tap("grab")
	else:
		_press("grab", false)

func _mine_is_exposed(mine: Slipper) -> bool:
	var taya := RoundManager.defender()
	if taya == null:
		return false
	return _flat(_at(taya), mine.global_position) < 4.5

func _do_stalk() -> void:
	var mine := _my_slipper()
	var anchor: Vector3 = mine.global_position if mine != null else Vector3.ZERO
	var bearing := atan2(anchor.x, anchor.z)
	_goto(_ring_point(bearing, CharacterBase.confinement_radius + 0.6), ARRIVE_SLOP, false)
	if _arrived:
		_loiter()

func _do_withdraw() -> void:
	_goto(_safe_spot(), ARRIVE_SLOP, true)

func _do_position() -> void:
	if not character.holding_slipper():
		var mine := _my_slipper()
		if mine == null:
			mine = _nearest_flying_slipper()
		if mine != null and mine.is_flying():
			var landing := _predicted_landing(mine)
			if landing != Vector3.INF:
				_goto(_pull_outside(landing, 0.4), ARRIVE_SLOP, false)
				return
		if not _goal_valid:
			_goal = _throw_spot()
			_goal_valid = true
		_goto(_goal, ARRIVE_SLOP, false)
		if _arrived:
			_loiter()
		return
	if not _goal_valid:
		_goal = _throw_spot()
		_goal_valid = true
	_goto(_goal, ARRIVE_SLOP, _flat(character.global_position, _goal) > SPRINT_DISTANCE)
	_claim(atan2(_goal.x, _goal.z))
	if _arrived:
		_loiter()

func _do_windup(delta: float) -> void:
	var lata := RoundManager.lata
	if lata == null or not character.holding_slipper() \
			or not RoundManager.can_throw(character):
		_windup = false
		_press("special_ability", false)
		_plan = Plan.POSITION
		_goal_valid = false
		return
	if not _windup:
		_windup = true
		_windup_time = 0.0
		_windup_wait = 0.0
		_blundering = _blunder()
		_windup_scatter = _roll_scatter()
		_windup_power = _plan_power(lata)
	_windup_time += delta
	_stop()

	var aim := lata.global_position + Vector3.UP * AIM_HEIGHT
	var settle := 1.0
	if _aim_settle < 90.0:
		settle = lerpf(1.0, AIM_SETTLE_FLOOR, clampf(_windup_time / maxf(_aim_settle, 0.05), 0.0, 1.0))
	character.ai_aim_point = aim + _windup_scatter * settle

	var carrier := character.get_node_or_null("Carrier") as Carrier
	var power: float = carrier.charge_power() if carrier != null else 0.0
	_press("special_ability", true)

	if _windup_time >= WINDUP_TIMEOUT:
		_release_throw()
		return
	if power < _windup_power:
		return
	var min_hold := 0.0
	if _aim_settle < 90.0:
		min_hold = minf(_aim_settle, Carrier.CHARGE_FULL_TIME) * WINDUP_MIN_HOLD_SHARE
	if _windup_time < min_hold:
		return
	var origin := Carrier.throw_origin_for(character, character.ai_aim_point)
	if not _blundering and _lane_blocked(origin, character.ai_aim_point, power):
		_windup_wait += delta
		if _windup_wait < _lane_patience:
			return
		_windup = false
		_goal_valid = false
		_plan = Plan.POSITION
		_press("special_ability", false)
		_trace("POSITION (lane shut)")
		return
	_release_throw()

func _release_throw() -> void:
	_press("special_ability", false)
	_windup = false
	_goal_valid = false
	_commit_left = 0.0
	_plan = Plan.IDLE

func _do_evade() -> void:
	var taya := RoundManager.defender()
	if taya == null:
		_do_withdraw()
		return
	var toward := character.global_position - _at(taya)
	toward.y = 0.0
	if toward.length() < 0.05:
		toward = Vector3.FORWARD
	var across := Vector3(-toward.z, 0.0, toward.x).normalized()
	if across.dot(_out_of_box_dir()) < 0.0:
		across = -across
	var escape := (across * 0.75 + _out_of_box_dir() * 0.75).normalized()
	_drive(escape, true)
	_press("grab", false)

func _do_sabotage() -> void:
	var victim := _sabotage_target(RoundManager.defender())
	if victim == null:
		_stop()
		return
	var distance := _flat(character.global_position, victim.global_position)
	var toward := victim.global_position - character.global_position
	toward.y = 0.0
	_drive(toward, distance > 3.0)
	if distance <= CharacterBase.SHOVE_RANGE * 0.9 			and _facing(victim, CharacterBase.SHOVE_ARC_DEG * 0.6):
		_tap("grab")
	else:
		_press("grab", false)

func _do_idle() -> void:
	_loiter()


func _do_reset() -> void:
	var lata := RoundManager.lata
	if lata == null:
		_stop()
		return
	var inside := lata.is_in_ring(character.global_position)
	if inside:
		_stop()
	else:
		_goto(lata.global_position, Lata.INTERACTION_RADIUS * 0.55, true)
	_press("grab", inside)

func _do_intercept() -> void:
	var lata := RoundManager.lata
	var point := _intercept_point(lata)
	if point == Vector3.INF:
		_do_guard()
		return
	_goto(point, 0.3, true)

func _do_hunt(delta: float) -> void:
	var victim := _tag_target()
	if victim == null:
		_do_guard()
		return
	var aim_at := _ahead_of(victim, 0.35)
	var toward := aim_at - character.global_position
	toward.y = 0.0
	_drive(toward, _may_sprint() and toward.length() > 1.5)
	_step_lunge_intent(victim, delta)

func _do_cover() -> void:
	var point := _cover_point(RoundManager.lata)
	if point == Vector3.INF:
		_do_guard()
		return
	_goto(point, ARRIVE_SLOP, false)
	if _arrived:
		_loiter()

func _do_guard() -> void:
	var lata := RoundManager.lata
	if lata == null:
		_stop()
		return
	var threat := _live_threat()
	if threat == null:
		_goto(_clamp_to_box(lata.global_position), ARRIVE_SLOP, false)
		return
	var toward := _at(threat) - lata.global_position
	toward.y = 0.0
	if toward.length() < 0.05:
		_goto(_clamp_to_box(lata.global_position), ARRIVE_SLOP, false)
		return
	var post := lata.global_position + toward.normalized() * GUARD_RADIUS
	_goto(_clamp_to_box(post), ARRIVE_SLOP, _flat(character.global_position, post) > SPRINT_DISTANCE)
	if _arrived:
		_loiter()

func _step_lunge_intent(victim: CharacterBase, delta: float) -> void:
	if character.punch_cooldown_left() <= 0.0 and victim != null 			and _flat(character.global_position, victim.global_position) <= CharacterBase.PUNCH_RANGE 			and _facing(victim, CharacterBase.PUNCH_ARC_DEG):
		_tap("special_ability")
		return
	_press("special_ability", false)
	if character.lunge_cooldown_left() > 0.0:
		_lunge_held = -1.0
		_press("lunge", false)
		return
	var reach := _flat(character.global_position, _ahead_of(victim, LUNGE_HOLD_TIME))
	if _lunge_held < 0.0:
		if reach > _lunge_range:
			_press("lunge", false)
			return
		_lunge_held = 0.0
	_lunge_held += delta
	if _lunge_held >= LUNGE_HOLD_TIME and _facing(victim, _lunge_cone):
		_lunge_held = -1.0
		_press("lunge", false)
		return
	if _lunge_held >= LUNGE_HOLD_TIME + 0.45:
		_lunge_held = -1.0
		_press("lunge", false)
		return
	_press("lunge", true)


func _min_power_for(origin: Vector3, target: Vector3) -> float:
	var flat := Vector2(target.x - origin.x, target.z - origin.z).length()
	var rise := target.y - origin.y
	var speed := sqrt(maxf(CharacterBase.GRAVITY * (rise + sqrt(rise * rise + flat * flat)), 0.0))
	return _power_for_speed(speed)

func _power_for_speed(speed: float) -> float:
	var scale := speed / Slipper.LAUNCH_SPEED
	return clampf((scale - Slipper.MIN_POWER_SCALE) / (1.0 - Slipper.MIN_POWER_SCALE), 0.0, 1.0)

func _plan_power(lata: Lata) -> float:
	var aim := lata.global_position + Vector3.UP * AIM_HEIGHT
	var origin := Carrier.throw_origin_for(character, aim)
	var floor_power := _min_power_for(origin, aim)
	var flat := Vector2(aim.x - origin.x, aim.z - origin.z).length()
	var rise := aim.y - origin.y
	var wanted := sqrt(maxf(CharacterBase.GRAVITY * (rise + sqrt(rise * rise + flat * flat)), 0.0))
	var margin := _power_margin
	if _blundering:
		margin = 1.0
	return clampf(maxf(_power_for_speed(wanted * margin), floor_power + 0.02), 0.0, 1.0)

func _roll_scatter() -> Vector3:
	var lata := RoundManager.lata
	var range_scale := 1.0
	if lata != null:
		var distance := _flat(character.global_position, lata.global_position)
		range_scale = clampf(distance / AIM_REFERENCE_RANGE,
			AIM_RANGE_SCALE_MIN, AIM_RANGE_SCALE_MAX)
	var spread := _aim_error * range_scale * (2.2 if _blundering else 1.0)
	var bearing := randf_range(-PI, PI)
	var reach := sqrt(randf()) * spread
	return Vector3(cos(bearing) * reach, 0.0, sin(bearing) * reach)

func _lane_blocked(origin: Vector3, target: Vector3, power: float) -> bool:
	var launch := Slipper.launch_velocity_for(origin, target, power)
	var speed := maxf(launch.length(), 1.0)
	var step := clampf(LANE_SAMPLE_ARC / speed, LANE_STEP_MIN, LANE_STEP_MAX)
	var others := RoundManager.players()
	var t := 0.0
	for _i in range(LANE_MAX_STEPS):
		t += step
		var point := origin + launch * t \
			+ Vector3.DOWN * (0.5 * CharacterBase.GRAVITY * t * t)
		if Vector2(point.x - target.x, point.z - target.z).length() \
				<= Slipper.HIT_RADIUS + 0.30:
			return false
		if point.y < target.y - 1.0:
			return true
		for node in others:
			var who := node as CharacterBase
			if who == null or who == character:
				continue
			if not who.can_be_hit_by_slipper():
				continue
			if Vector2(point.x - who.global_position.x,
					point.z - who.global_position.z).length() \
					> Slipper.HIT_RADIUS + who.capsule_radius():
				continue
			var rise := point.y - who.global_position.y
			if rise < -who.capsule_height() * 0.5 or rise > who.capsule_height() * 0.5:
				continue
			return true
	return true

const SPOT_SAMPLES: int = 16

func _throw_spot() -> Vector3:
	var lata := RoundManager.lata
	if lata == null:
		return _safe_spot()
	var ring: float = CharacterBase.confinement_radius + THROW_STANDOFF
	var here := character.global_position
	var taya := RoundManager.defender()
	var taya_bearing := 0.0
	var have_taya := taya != null
	if have_taya:
		var offset := _at(taya) - lata.global_position
		taya_bearing = atan2(offset.x, offset.z)
	var rivals := _rival_bearings()
	var best := _safe_spot()
	var best_score := -INF
	for i in range(SPOT_SAMPLES):
		var bearing := -PI + TAU * float(i) / float(SPOT_SAMPLES)
		var point := _ring_point(bearing, ring)
		var score := 0.0
		if have_taya:
			score += 2.4 * (absf(_angle_between(bearing, taya_bearing)) / PI)
		var nearest_rival := PI
		for claimed in rivals:
			nearest_rival = minf(nearest_rival, absf(_angle_between(bearing, claimed)))
		score += 2.0 * _spacing * (nearest_rival / PI)
		score += 0.5 * (1.0 - absf(_angle_between(bearing, _me.home_bearing)) / PI)
		score -= 0.11 * _flat(here, point)
		if score > best_score:
			best_score = score
			best = point
	return best

func _rival_bearings() -> Array:
	var out: Array = []
	var now := Time.get_ticks_msec() / 1000.0
	for slot in _claims.keys():
		if slot == character.player_slot:
			continue
		var record: Dictionary = _claims[slot]
		if now - float(record.get("at", -99.0)) > CLAIM_TTL:
			continue
		out.append(float(record.get("bearing", 0.0)))
	return out

func _claim(bearing: float) -> void:
	_claims[character.player_slot] = {
		"bearing": bearing, "at": Time.get_ticks_msec() / 1000.0,
	}


func _nearest_flying_slipper() -> Slipper:
	var best: Slipper = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null or not slipper.is_flying():
			continue
		var d := character.global_position.distance_to(slipper.global_position)
		if d < best_d:
			best_d = d
			best = slipper
	return best

func _my_slipper() -> Slipper:
	for node in get_tree().get_nodes_in_group("slippers"):
		var flying := node as Slipper
		if flying != null and flying.is_flying() \
				and flying.owner_slot == character.player_slot:
			return flying
	var best: Slipper = null
	var best_score := INF
	var fallback: Slipper = null
	var fallback_d := INF
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null or slipper.state != Slipper.CarryState.LOOSE:
			continue
		var d := character.global_position.distance_to(slipper.global_position)
		if d < fallback_d:
			fallback_d = d
			fallback = slipper
		var score := d + _claim_penalty(slipper)
		if _is_nearest_claimant(slipper, d) and score < best_score:
			best_score = score
			best = slipper
	return best if best != null else fallback


const HUMAN_SLIPPER_BIAS: float = 3.5


func _claim_penalty(slipper: Slipper) -> float:
	if slipper.owner_slot < 0 or slipper.owner_slot == character.player_slot:
		return 0.0
	var owner := RoundManager.player_at(slipper.owner_slot)
	if owner == null or owner.is_ai_driven():
		return 0.0
	return HUMAN_SLIPPER_BIAS


func _is_nearest_claimant(slipper: Slipper, my_distance: float) -> bool:
	for slot in range(4):
		var rival := RoundManager.player_at(slot)
		if rival == null or rival == character:
			continue
		if rival.is_defender or not rival.can_act() or rival.holding_slipper():
			continue
		var d := rival.global_position.distance_to(slipper.global_position)
		if slipper.owner_slot >= 0 and slipper.owner_slot != rival.player_slot \
				and rival.is_ai_driven():
			var owner := RoundManager.player_at(slipper.owner_slot)
			if owner != null and not owner.is_ai_driven():
				d += HUMAN_SLIPPER_BIAS
		if d < my_distance:
			return false
		if is_equal_approx(d, my_distance) and rival.player_slot < character.player_slot:
			return false
	return true

func _fetch_is_safe(mine: Slipper, taya: CharacterBase) -> bool:
	if _fetch_caution <= 0.0 or taya == null:
		return true
	if _stalk_time >= STALK_PATIENCE_BASE + _fetch_caution:
		return true
	var lata := RoundManager.lata
	if lata != null and not lata.is_upright:
		return true
	if taya.lunge_cooldown_left() > 0.35:
		return true
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who != null and who != character and who.is_taggable():
			return true
	return _flat(_at(taya), mine.global_position) > _fetch_caution

func _sabotage_target(taya: CharacterBase) -> CharacterBase:
	if _sabotage <= 0.0 or taya == null:
		return null
	if character.shove_cooldown_left() > 0.0:
		return null
	if character.get_stamina_ratio() * CharacterBase.STAMINA_MAX \
			< CharacterBase.SHOVE_STAMINA_COST + 2.0:
		return null
	var best: CharacterBase = null
	var best_distance: float = CharacterBase.SHOVE_RANGE * (1.0 + 3.0 * _sabotage)
	var taya_window: float = 2.5 + 4.0 * _sabotage
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who == character or who.is_defender:
			continue
		if not who.is_taggable():
			continue
		if _flat(_at(taya), who.global_position) > taya_window:
			continue
		var distance := _flat(character.global_position, who.global_position)
		if distance >= best_distance:
			continue
		var push := who.global_position - character.global_position
		push.y = 0.0
		var to_taya := _at(taya) - who.global_position
		to_taya.y = 0.0
		if push.length() < 0.05 or to_taya.length() < 0.05:
			continue
		if push.normalized().dot(to_taya.normalized()) < 0.15:
			continue
		best_distance = distance
		best = who
	return best

func _should_evade(taya: CharacterBase, delta: float) -> bool:
	if _dodge <= 0.0 or taya == null or not character.is_taggable():
		_gates["lunge"] = 0.0
		return false
	var winding := taya.observed_lunge_charge() >= 0.0 \
		and _flat(character.global_position, _at(taya)) < 4.5
	return _reacted("lunge", winding, delta)

func _tag_target() -> CharacterBase:
	var lata := RoundManager.lata
	if lata == null or not lata.is_upright:
		return null
	var best: CharacterBase = null
	var best_distance := INF
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who == character or not who.is_taggable():
			continue
		var distance := _flat(character.global_position, _at(who))
		if distance < best_distance:
			best_distance = distance
			best = who
	return best

func _live_threat() -> CharacterBase:
	var best: CharacterBase = null
	var best_score := -INF
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who.is_defender:
			continue
		var score := 0.0
		if who.holding_slipper():
			score += 2.0
		if not who.is_inside_box():
			score += 1.0
		var carrier := who.get_node_or_null("Carrier") as Carrier
		if carrier != null and carrier.observed_charge_power() >= 0.0:
			score += 1.0 + carrier.observed_charge_power() * 1.0
		score -= 0.08 * _flat(character.global_position, _at(who))
		if who == _last_threat:
			score -= 0.6
		if score > best_score:
			best_score = score
			best = who
	_last_threat = best
	return best

func _intercept_point(lata: Lata) -> Vector3:
	if lata == null or not lata.is_upright:
		return Vector3.INF
	var speed := CharacterBase.SPEED * character.trait_speed_scale()
	var here := character.global_position
	for id in _flights.keys():
		var record: Dictionary = _flights[id]
		var slipper := record.get("node") as Slipper
		if slipper == null or not is_instance_valid(slipper) or not slipper.is_flying():
			continue
		var launch: Vector3 = record["vel"]
		if launch.length() < 1.0:
			continue
		var from: Vector3 = record["pos"]
		var t := 0.0
		while t < INTERCEPT_HORIZON:
			t += INTERCEPT_STEP
			var point := from + launch * t \
				+ Vector3.DOWN * (0.5 * CharacterBase.GRAVITY * t * t)
			if _flat(point, lata.global_position) <= Slipper.HIT_RADIUS + 0.30:
				break
			var rise := point.y - here.y
			if rise < -INTERCEPT_BAND or rise > INTERCEPT_BAND:
				continue
			if not _heading_for(point, launch, lata):
				continue
			var travel := _flat(here, point)
			if travel > speed * t * (0.75 + 0.55 * _intercept):
				continue
			return _clamp_to_box(point)
	return Vector3.INF

func _heading_for(point: Vector3, launch: Vector3, lata: Lata) -> bool:
	var to_can := lata.global_position - point
	to_can.y = 0.0
	var flat_launch := Vector3(launch.x, 0.0, launch.z)
	if to_can.length() < 0.05 or flat_launch.length() < 0.05:
		return true
	return to_can.normalized().dot(flat_launch.normalized()) > 0.55

func _nearest_claimant_to(slipper: Slipper) -> CharacterBase:
	var best: CharacterBase = null
	var best_d := INF
	for slot in range(4):
		var who := RoundManager.player_at(slot)
		if who == null or who.is_defender or not who.can_act():
			continue
		if who.holding_slipper():
			continue
		var d := who.global_position.distance_to(slipper.global_position)
		if d < best_d:
			best_d = d
			best = who
	return best


func _cover_point(lata: Lata) -> Vector3:
	if lata == null:
		return Vector3.INF
	var best: Vector3 = Vector3.INF
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null or not slipper.is_loose():
			continue
		if maxf(absf(slipper.global_position.x), absf(slipper.global_position.z)) \
				>= CharacterBase.confinement_radius:
			continue
		var holder := _nearest_claimant_to(slipper)
		if holder == null:
			continue
		var toward := _at(holder) - slipper.global_position
		toward.y = 0.0
		if toward.length() < 0.05:
			continue
		var point := slipper.global_position + toward.normalized() * (0.6 + 0.9 * _camp)
		var distance := _flat(character.global_position, point)
		if distance < best_distance:
			best_distance = distance
			best = point
	if best == Vector3.INF:
		return best
	return _clamp_to_box(best)


func _goto(point: Vector3, stop_at: float, sprint: bool) -> bool:
	if _flat(_goal, point) > GOAL_MOVED:
		_arrived = false
	_goal = point
	var delta := point - character.global_position
	delta.y = 0.0
	var distance := delta.length()
	var threshold := stop_at * ARRIVE_HYSTERESIS if _arrived else stop_at
	if distance <= threshold:
		_arrived = true
		_stop()
		return true
	_arrived = false
	var heading := delta / maxf(distance, 0.001)
	heading += _separation() * SEPARATION_WEIGHT
	_drive(heading, sprint and distance > REACH)
	return false

func _drive(direction: Vector3, sprint: bool) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.001:
		_stop()
		return
	flat = flat.normalized()
	_driving = true
	if _unstick_left > 0.0:
		flat = Vector3(-flat.z * _unstick_sign, 0.0, flat.x * _unstick_sign)
	_press("move_right", flat.x > EIGHT_WAY_THRESHOLD)
	_press("move_left", flat.x < -EIGHT_WAY_THRESHOLD)
	_press("move_down", flat.z > EIGHT_WAY_THRESHOLD)
	_press("move_up", flat.z < -EIGHT_WAY_THRESHOLD)
	_press("sprint", sprint and _may_sprint())

func _may_sprint() -> bool:
	if character.is_fatigued():
		return false
	return character.get_stamina_ratio() > _sprint_reserve

func _separation() -> Vector3:
	var push := Vector3.ZERO
	var here := character.global_position
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who == character:
			continue
		var away := here - who.global_position
		away.y = 0.0
		var distance := away.length()
		if distance > SEPARATION_RADIUS or distance < 0.01:
			continue
		push += (away / distance) * (1.0 - distance / SEPARATION_RADIUS)
	return push

func _loiter() -> void:
	var here := character.global_position
	var anchor := _goal if _flat(here, _goal) <= ARRIVE_SLOP else here
	var out := here - anchor
	out.y = 0.0
	if out.length() > LOITER_LEASH:
		_loiter_dir = 0.0
		_loiter_left = randf_range(LOITER_REST_MIN, LOITER_REST_MAX)
		_drive(-out, false)
		return
	if _loiter_left <= 0.0:
		if _loiter_dir == 0.0:
			_loiter_dir = 1.0 if randf() < 0.5 else -1.0
			_loiter_left = randf_range(LOITER_STEP_MIN, LOITER_STEP_MAX)
		else:
			_loiter_dir = 0.0
			_loiter_left = randf_range(LOITER_REST_MIN, LOITER_REST_MAX)
	if _loiter_dir == 0.0:
		_stop()
		return
	var lata := RoundManager.lata
	var pivot: Vector3 = lata.global_position if lata != null else Vector3.ZERO
	var radial := here - pivot
	radial.y = 0.0
	if radial.length() < 0.05:
		radial = Vector3.FORWARD
	radial = radial.normalized()
	var across := Vector3(-radial.z, 0.0, radial.x)
	_drive(across * _loiter_dir, false)

func _safe_spot() -> Vector3:
	var here := character.global_position
	var flat := Vector2(here.x, here.z)
	var reach := maxf(absf(flat.x), absf(flat.y))
	if reach < 0.01:
		flat = Vector2(0.0, 1.0)
		reach = 1.0
	var ring: float = CharacterBase.confinement_radius + THROW_STANDOFF
	flat *= ring / reach
	return CharacterBase.clamp_to_playable(Vector3(flat.x, 0.0, flat.y))

func _ring_point(bearing: float, ring: float) -> Vector3:
	var direction := Vector2(sin(bearing), cos(bearing))
	var reach := maxf(absf(direction.x), absf(direction.y))
	if reach < 0.001:
		return Vector3(0.0, 0.0, ring)
	direction *= ring / reach
	return CharacterBase.clamp_to_playable(Vector3(direction.x, 0.0, direction.y))

func _out_of_box_dir() -> Vector3:
	var here := character.global_position
	if absf(here.x) >= absf(here.z):
		return Vector3(signf(here.x) if absf(here.x) > 0.01 else 1.0, 0.0, 0.0)
	return Vector3(0.0, 0.0, signf(here.z) if absf(here.z) > 0.01 else 1.0)

func _pull_outside(point: Vector3, margin: float) -> Vector3:
	var reach := maxf(absf(point.x), absf(point.z))
	var ring: float = CharacterBase.confinement_radius + margin
	if reach >= ring or reach < 0.01:
		return point
	var flat := Vector2(point.x, point.z) * (ring / reach)
	return Vector3(flat.x, 0.0, flat.y)

func _clamp_to_box(point: Vector3) -> Vector3:
	var edge: float = CharacterBase.confinement_radius - 0.35
	return Vector3(clampf(point.x, -edge, edge), point.y, clampf(point.z, -edge, edge))

func _predicted_landing(slipper: Slipper) -> Vector3:
	var record: Dictionary = _flights.get(slipper.get_instance_id(), {})
	if record.is_empty():
		return Vector3.INF
	var launch: Vector3 = record["vel"]
	if launch.length() < 0.5:
		return Vector3.INF
	var from: Vector3 = record["pos"]
	var t := 0.0
	while t < Slipper.MAX_FLIGHT_TIME:
		t += 0.05
		var point := from + launch * t \
			+ Vector3.DOWN * (0.5 * CharacterBase.GRAVITY * t * t)
		if point.y <= from.y - 1.2 or point.y <= 0.2:
			return Vector3(point.x, 0.0, point.z)
	return Vector3.INF

func _facing(who: CharacterBase, cone: float) -> bool:
	if who == null:
		return false
	var forward := -character.global_transform.basis.z
	forward.y = 0.0
	var toward := who.global_position - character.global_position
	toward.y = 0.0
	if forward.length() < 0.01 or toward.length() < 0.01:
		return false
	return rad_to_deg(forward.normalized().angle_to(toward.normalized())) <= cone


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _angle_between(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)

func _blunder() -> bool:
	return randf() < _mistake

func _stop() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "sprint"]:
		_press(action, false)

func _release_all() -> void:
	_windup = false
	_lunge_held = -1.0
	_goal_valid = false
	_arrived = false
	_stuck_time = 0.0
	_unstick_left = 0.0
	_driving = false
	for action in ["move_left", "move_right", "move_up", "move_down", "sprint",
			"grab", "special_ability", "jump", "lunge"]:
		_press(action, false)

var _touched: Dictionary = {}

func _press(action: String, pressed: bool) -> void:
	if character == null:
		return
	character.ai_set_intent(action, pressed)
	_pressed[action] = pressed
	_touched[action] = true

func _tap(action: String) -> void:
	_press(action, not bool(_pressed.get(action, false)))

func _plan_name(plan: Plan) -> String:
	return Plan.keys()[plan]

func current_plan() -> String:
	return _plan_name(_plan)

func _trace(what: String) -> void:
	if not trace_enabled or what == _last_trace:
		return
	_last_trace = what
	print("[ai] P%d %s %s" % [character.player_slot + 1,
		"taya" if character.is_defender else "atk", what])

