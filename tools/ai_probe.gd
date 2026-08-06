extends Node3D

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

const DEFAULT_SCALE: float = 6.0
const BASE_TICKS: int = 60
const STEP_TOLERANCE: float = 1.0 / 45.0

const DEFAULT_MATCHES: int = 3
const DEFAULT_WALL_CAP: float = 900.0

const STILL_SPEED: float = 0.35

const GATE_KNOCKDOWNS_PER_MATCH: float = 1.0
const GATE_HIT_RATE_NORMAL: float = 30.0
const GATE_METRES_PER_ROUND: float = 60.0
const GATE_MAX_STILL: float = 8.0
const GATE_FAIRNESS_SPREAD: float = 0.62

var _matches_target: int = DEFAULT_MATCHES
var _rounds_target: int = -1
var _scale: float = DEFAULT_SCALE
var _wall_cap: float = DEFAULT_WALL_CAP
var _tier: int = AIController.Difficulty.NORMAL

var _main: Node = null
var _match_index: int = 0
var _rounds_seen: int = 0
var _finished: bool = false

var _score_total: Array[int] = [0, 0, 0, 0]
var _score_by_reason: Dictionary = {}
var _metres: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _still_run: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _still_worst: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _still_plan: Array[String] = ["-", "-", "-", "-"]
var _blocked_run: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _blocked_worst: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _blocked_plan: Array[String] = ["-", "-", "-", "-"]
var _taggable_time: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _wins: Array[int] = [0, 0, 0, 0]
var _draws: int = 0
var _completed_matches: int = 0
var _last_pos: Array = [null, null, null, null]

var _throws: int = 0
var _throws_by_slot: Array[int] = [0, 0, 0, 0]
var _knockdowns: int = 0
var _knockdowns_by_slot: Array[int] = [0, 0, 0, 0]
var _tags: int = 0
var _sabotages: int = 0
var _near_misses: int = 0
var _flight_open: Dictionary = {}
var _flight_scored: Dictionary = {}
var _slipper_was: Dictionary = {}

var _step_samples: int = 0
var _step_total: float = 0.0

var _round_live_time: float = 0.0
var _wall_start: float = 0.0

func _ready() -> void:
	_parse_args()
	_wall_start = Time.get_ticks_msec() / 1000.0
	AIController.apply_difficulty(_tier as AIController.Difficulty)
	Engine.physics_ticks_per_second = int(round(BASE_TICKS * _scale))
	Engine.max_physics_steps_per_frame = maxi(8, int(round(16.0 * _scale)))
	Engine.time_scale = _scale
	print("[ai_probe] tier=%s matches=%d scale=%.1f ticks=%d"
		% [_tier_name(), _matches_target, _scale, Engine.physics_ticks_per_second])
	MatchManager.score_changed.connect(_on_score)
	MatchManager.match_won.connect(_on_match_won)
	RoundManager.lata_knocked.connect(_on_lata_knocked)
	RoundManager.attacker_tagged.connect(_on_tagged)
	RoundManager.round_ended.connect(_on_round_ended)
	_start_match.call_deferred()

func _parse_args() -> void:
	for token in OS.get_cmdline_user_args():
		var lower := String(token).to_lower()
		if lower.begins_with("matches="):
			_matches_target = maxi(1, int(lower.substr(8)))
		elif lower.begins_with("rounds="):
			_rounds_target = maxi(1, int(lower.substr(7)))
		elif lower.begins_with("scale="):
			_scale = clampf(float(lower.substr(6)), 1.0, 12.0)
		elif lower.begins_with("secs="):
			_wall_cap = maxf(30.0, float(lower.substr(5)))
		elif lower == "trace":
			AIController.trace_enabled = true
		elif lower.begins_with("tier="):
			var wanted := lower.substr(5)
			if wanted in ["easy", "bata", "0"]:
				_tier = AIController.Difficulty.BATA
			elif wanted in ["hard", "astig", "2"]:
				_tier = AIController.Difficulty.ASTIG
			else:
				_tier = AIController.Difficulty.NORMAL

func _start_match() -> void:
	_match_index += 1
	GameLaunch.spectator = true
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_slipper_was.clear()
	_flight_open.clear()
	for i in range(4):
		_last_pos[i] = null

func _end_match() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	MatchManager.reset()
	RoundManager.reset()
	await get_tree().process_frame
	await get_tree().process_frame
	if _finished:
		return
	if _match_index >= _matches_target:
		_grade()
		return
	_start_match()

func _on_match_won(winning_slot: int) -> void:
	_completed_matches += 1
	if winning_slot < 0:
		_draws += 1
	elif winning_slot < _wins.size():
		_wins[winning_slot] += 1
	print("[match %d] winner=%s scores=%s"
		% [_match_index, ("DRAW" if winning_slot < 0 else "P%d" % (winning_slot + 1)),
			str(MatchManager.scores)])
	_end_match.call_deferred()

func _on_round_ended(_round_number: int) -> void:
	_rounds_seen += 1
	if _rounds_target > 0 and _rounds_seen >= _rounds_target and not _finished:
		_grade()

func _physics_process(delta: float) -> void:
	if _finished:
		return
	_step_samples += 1
	_step_total += delta
	if Time.get_ticks_msec() / 1000.0 - _wall_start > _wall_cap:
		print("[ai_probe] WALL-CLOCK CAP HIT during match %d — grading what there is."
			% _match_index)
		_grade()
		return
	if not RoundManager.round_active:
		return
	_round_live_time += delta
	_sample_players(delta)
	_sample_slippers()

func _sample_players(delta: float) -> void:
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		var slot := who.player_slot
		if slot < 0 or slot >= 4:
			continue
		var here := who.global_position
		var was = _last_pos[slot]
		if was != null:
			var previous: Vector3 = was
			_metres[slot] += Vector2(here.x - previous.x, here.z - previous.z).length()
		_last_pos[slot] = here
		var speed := Vector2(who.velocity.x, who.velocity.z).length()
		var trying := who.input_pressed("move_left") or who.input_pressed("move_right") 			or who.input_pressed("move_up") or who.input_pressed("move_down")
		if speed < STILL_SPEED and not trying:
			_still_run[slot] += delta
			if _still_run[slot] > _still_worst[slot]:
				_still_worst[slot] = _still_run[slot]
				_still_plan[slot] = _plan_of(who)
		else:
			_still_run[slot] = 0.0
		if speed < STILL_SPEED and trying:
			_blocked_run[slot] += delta
			if _blocked_run[slot] > _blocked_worst[slot]:
				_blocked_worst[slot] = _blocked_run[slot]
				_blocked_plan[slot] = _plan_of(who)
		else:
			_blocked_run[slot] = 0.0
		if who.is_taggable():
			_taggable_time[slot] += delta

func _sample_slippers() -> void:
	var lata := RoundManager.lata
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null:
			continue
		var id := slipper.get_instance_id()
		var flying := slipper.is_flying()
		var was := bool(_slipper_was.get(id, false))
		_slipper_was[id] = flying
		if flying and not was:
			_throws += 1
			var slot := slipper.owner_slot
			if slot >= 0 and slot < 4:
				_throws_by_slot[slot] += 1
			_flight_open[id] = INF
		if flying and lata != null:
			var distance := Vector2(slipper.global_position.x - lata.global_position.x,
				slipper.global_position.z - lata.global_position.z).length()
			_flight_open[id] = minf(float(_flight_open.get(id, INF)), distance)
		elif not flying and was:
			if not _flight_scored.has(id) and float(_flight_open.get(id, INF)) <= 1.0:
				_near_misses += 1
			_flight_open.erase(id)
			_flight_scored.erase(id)

func _plan_of(who: CharacterBase) -> String:
	if who.ai_controller == null or not who.ai_controller.has_method("current_plan"):
		return "-"
	return String(who.ai_controller.current_plan())

func _on_score(slot: int, _total: int, delta_points: int, reason: String) -> void:
	if slot >= 0 and slot < 4:
		_score_total[slot] += delta_points
	_score_by_reason[reason] = int(_score_by_reason.get(reason, 0)) + delta_points
	if reason == "SABOTAGE":
		_sabotages += 1

func _on_lata_knocked(by_slot: int) -> void:
	_knockdowns += 1
	if by_slot >= 0 and by_slot < 4:
		_knockdowns_by_slot[by_slot] += 1
	for id in _flight_open.keys():
		_flight_scored[id] = true

func _on_tagged(_defender_slot: int, _victim_slot: int) -> void:
	_tags += 1

func _grade() -> void:
	if _finished:
		return
	_finished = true
	Engine.time_scale = 1.0
	var mean_step := _step_total / maxf(float(_step_samples), 1.0)
	var rounds := maxi(_rounds_seen, 1)
	var matches := maxi(_match_index, 1)
	var failures: Array[String] = []

	print("")
	print("================ AI PROBE — tier %s ================" % _tier_name())
	print("matches %d   rounds %d   live game time %.1f s   mean physics step %.4f s"
		% [matches, _rounds_seen, _round_live_time, mean_step])

	if mean_step > STEP_TOLERANCE:
		failures.append(("HARNESS: mean physics step %.4f s exceeds %.4f — flight "
			+ "sampling too coarse to trust. Re-run at scale=1.")
			% [mean_step, STEP_TOLERANCE])

	print("")
	print("--- offence ---")
	var hit_rate := 100.0 * float(_knockdowns) / maxf(float(_throws), 1.0)
	print("throws %d   knockdowns %d   hit rate %.1f%%   near misses (<1 m, no knock) %d"
		% [_throws, _knockdowns, hit_rate, _near_misses])
	print("tags %d   sabotages %d" % [_tags, _sabotages])
	var per_match := float(_knockdowns) / float(matches)
	print("knockdowns per match %.2f   (gate: >= %.2f)"
		% [per_match, GATE_KNOCKDOWNS_PER_MATCH])
	if per_match < GATE_KNOCKDOWNS_PER_MATCH:
		failures.append(("OFFENCE: %.2f knockdowns per match against %d throws — "
			+ "the §6.6 failure, the bots throw and miss.") % [per_match, _throws])
	if _tier_name() != "EASY" and _throws > 0 and hit_rate < GATE_HIT_RATE_NORMAL:
		failures.append(("OFFENCE: %.1f%% hit rate at tier %s against a floor of "
			+ "%.0f%% — the bots are throwing and not converting. A healthy NORMAL "
			+ "build measures 44-50%%; 7%% and 29%% were both real, both broken, and "
			+ "both PASSED the knockdowns-per-match gate alone.")
			% [hit_rate, _tier_name(), GATE_HIT_RATE_NORMAL])

	print("")
	print("--- movement ---")
	for slot in range(4):
		var per_round := _metres[slot] / float(rounds)
		print("P%d  %7.1f m total  %6.1f m/round  idle %4.1f s (%s)  blocked %4.1f s (%s)  taggable %5.1f s"
			% [slot + 1, _metres[slot], per_round, _still_worst[slot], _still_plan[slot],
				_blocked_worst[slot], _blocked_plan[slot], _taggable_time[slot]])
		if per_round < GATE_METRES_PER_ROUND:
			failures.append(("MOVEMENT: P%d covered %.1f m per round against a gate of "
				+ "%.1f — the §6.7 failure.") % [slot + 1, per_round, GATE_METRES_PER_ROUND])
		if _still_worst[slot] > GATE_MAX_STILL:
			failures.append("MOVEMENT: P%d idled %.1f s inside a live round, pressing "
				% [slot + 1, _still_worst[slot]]
				+ "nothing, in plan %s." % _still_plan[slot])

	print("")
	print("--- where the points came from ---")
	var reasons := _score_by_reason.keys()
	reasons.sort()
	var grand := 0
	for reason in reasons:
		grand += int(_score_by_reason[reason])
	for reason in reasons:
		var points := int(_score_by_reason[reason])
		print("%-10s %6d   %5.1f%% of every point scored"
			% [reason, points, 100.0 * float(points) / maxf(float(grand), 1.0)])

	print("")
	print("--- fairness over %d match(es) ---" % matches)
	print("wins by seat %s   draws %d" % [str(_wins), _draws])
	var high := 0
	var low := 1 << 30
	for slot in range(4):
		print("P%d  total %6d   throws %3d   knockdowns %2d"
			% [slot + 1, _score_total[slot], _throws_by_slot[slot],
				_knockdowns_by_slot[slot]])
		high = maxi(high, _score_total[slot])
		low = mini(low, _score_total[slot])
	var spread := 1.0 - (float(low) / maxf(float(high), 1.0))
	print("seat score spread %.2f   (gate: <= %.2f — every seat defends exactly once)"
		% [spread, GATE_FAIRNESS_SPREAD])
	if _completed_matches < 1:
		print("       ^ NOT GATED: %d complete match(es). Fairness needs a whole"
			% _completed_matches)
		print("         four-round rotation, or it is measuring the rotation itself.")
	elif spread > GATE_FAIRNESS_SPREAD:
		failures.append(("FAIRNESS: seat totals span %d..%d (spread %.2f) — four bots "
			+ "of one tier, each defending once, should not be this far apart.")
			% [low, high, spread])

	print("")
	if failures.is_empty():
		print("RESULT: PASS")
		get_tree().quit(0)
		return
	print("RESULT: FAIL — %d gate(s)" % failures.size())
	for line in failures:
		print("  * " + line)
	get_tree().quit(1)

func _tier_name() -> String:
	if _tier == AIController.Difficulty.BATA:
		return "EASY"
	if _tier == AIController.Difficulty.ASTIG:
		return "HARD"
	return "NORMAL"

