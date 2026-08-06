extends Node3D

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

const BASE_TICKS: int = 60
const STEP_TOLERANCE: float = 1.0 / 45.0
const DEFAULT_SCALE: float = 6.0
const DEFAULT_MATCHES: int = 1
const DEFAULT_WALL_CAP: float = 900.0

const GATE_PASSIVE_SHARE: float = 50.0

const GATE_TURTLE_MAY_WIN: bool = false

enum Policy { BOT, IDLE, TURTLE }

var _policy: Policy = Policy.TURTLE
var _matches_target: int = DEFAULT_MATCHES
var _scale: float = DEFAULT_SCALE
var _wall_cap: float = DEFAULT_WALL_CAP
var _tier: int = AIController.Difficulty.NORMAL
var _seat_filter: int = -1

var _main: Node = null
var _match_index: int = 0
var _rounds_seen: int = 0
var _finished: bool = false
var _wall_start: float = 0.0

var _brains: Dictionary = {}
var _origins: Dictionary = {}

var _score_total: Array[int] = [0, 0, 0, 0]
var _score_by_reason: Dictionary = {}
var _defense_by_slot: Array[int] = [0, 0, 0, 0]
var _tags_by_slot: Array[int] = [0, 0, 0, 0]
var _knockdowns_by_slot: Array[int] = [0, 0, 0, 0]
var _wins: Array[int] = [0, 0, 0, 0]
var _draws: int = 0
var _completed_matches: int = 0

var _throws: int = 0
var _knockdowns: int = 0
var _tags: int = 0
var _slipper_was: Dictionary = {}

var _upright_time: float = 0.0
var _round_live_time: float = 0.0

var _step_samples: int = 0
var _step_total: float = 0.0


class IdleBrain extends AIController:
	func decide(_delta: float) -> void:
		if character == null or not is_instance_valid(character):
			return
		_stop()
		_press("grab", false)
		_press("lunge", false)
		_press("special_ability", false)

class TurtleBrain extends AIController:
	const BLOCK_STANDOFF: float = 2.2
	const POST_SLOP: float = 0.55

	func decide(_delta: float) -> void:
		if character == null or not is_instance_valid(character):
			return
		_press("lunge", false)
		_press("special_ability", false)
		if not RoundManager.round_active or not character.can_act():
			_stop()
			_press("grab", false)
			return
		var can := RoundManager.lata
		if can == null:
			_stop()
			_press("grab", false)
			return
		if not can.is_upright:
			var inside := can.is_in_ring(character.global_position)
			if inside:
				_stop()
			else:
				_walk_to(can.global_position, Lata.INTERACTION_RADIUS * 0.55)
			_press("grab", inside)
			return
		_press("grab", false)
		var threat := _worst_threat(can)
		if threat == null:
			_walk_to(can.global_position, POST_SLOP)
			return
		var toward := threat.global_position - can.global_position
		toward.y = 0.0
		if toward.length() < 0.05:
			_walk_to(can.global_position, POST_SLOP)
			return
		_walk_to(can.global_position + toward.normalized() * BLOCK_STANDOFF, POST_SLOP)

	func _walk_to(point: Vector3, stop_at: float) -> void:
		var delta := point - character.global_position
		delta.y = 0.0
		if delta.length() <= stop_at:
			_stop()
			return
		_drive(delta, false)

	func _worst_threat(can: Lata) -> CharacterBase:
		var best: CharacterBase = null
		var best_score := -INF
		for node in RoundManager.players():
			var who := node as CharacterBase
			if who == null or who.is_defender:
				continue
			var score := 0.0
			if who.holding_slipper():
				score += 2.0
			var hands := who.get_node_or_null("Carrier") as Carrier
			if hands != null and hands.observed_charge_power() >= 0.0:
				score += 4.0
			var flat := Vector2(who.global_position.x - can.global_position.x,
				who.global_position.z - can.global_position.z)
			score -= 0.08 * flat.length()
			if score > best_score:
				best_score = score
				best = who
		return best


func _ready() -> void:
	_parse_args()
	_wall_start = Time.get_ticks_msec() / 1000.0
	AIController.apply_difficulty(_tier as AIController.Difficulty)
	Engine.physics_ticks_per_second = int(round(BASE_TICKS * _scale))
	Engine.max_physics_steps_per_frame = maxi(8, int(round(16.0 * _scale)))
	Engine.time_scale = _scale
	print("[fair_probe] policy=%s tier=%s seats=%s matches=%d scale=%.1f ticks=%d"
		% [_policy_name(), _tier_name(), ("all" if _seat_filter < 0 else "P%d" % (_seat_filter + 1)),
			_matches_target, _scale, Engine.physics_ticks_per_second])
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
		elif lower.begins_with("scale="):
			_scale = clampf(float(lower.substr(6)), 1.0, 12.0)
		elif lower.begins_with("secs="):
			_wall_cap = maxf(30.0, float(lower.substr(5)))
		elif lower.begins_with("seats="):
			var want := lower.substr(6)
			_seat_filter = -1 if want == "all" else clampi(int(want), 0, 3)
		elif lower.begins_with("policy="):
			var name := lower.substr(7)
			if name == "bot":
				_policy = Policy.BOT
			elif name == "idle":
				_policy = Policy.IDLE
			else:
				_policy = Policy.TURTLE
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
	_brains.clear()
	_origins.clear()

func _end_match() -> void:
	_brains.clear()
	_origins.clear()
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

func _apply_policy() -> void:
	if _policy == Policy.BOT:
		return
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		var slot := who.player_slot
		if slot < 0 or slot > 3:
			continue
		var wants := who.is_defender and (_seat_filter < 0 or _seat_filter == slot)
		var has: bool = _brains.has(slot)
		if wants and not has:
			_take_over(who, slot)
		elif has and not wants:
			_hand_back(who, slot)

func _take_over(who: CharacterBase, slot: int) -> void:
	var original := who.ai_controller
	if original != null:
		original.set_enabled(false)
	_origins[slot] = original
	var brain: AIController = IdleBrain.new() if _policy == Policy.IDLE else TurtleBrain.new()
	brain.name = "FairProbeBrain"
	who.add_child(brain)
	who.ai_controller = brain
	who.ai_clear_intent()
	_brains[slot] = brain
	print("[fair_probe] P%d taya -> %s" % [slot + 1, _policy_name()])

func _hand_back(who: CharacterBase, slot: int) -> void:
	var brain = _brains.get(slot, null)
	var original = _origins.get(slot, null)
	who.ai_controller = original if is_instance_valid(original) else null
	if who.ai_controller != null:
		who.ai_controller.set_enabled(true)
	who.ai_clear_intent()
	if is_instance_valid(brain):
		(brain as Node).queue_free()
	_brains.erase(slot)
	_origins.erase(slot)

func _physics_process(delta: float) -> void:
	if _finished:
		return
	_step_samples += 1
	_step_total += delta
	if Time.get_ticks_msec() / 1000.0 - _wall_start > _wall_cap:
		print("[fair_probe] WALL-CLOCK CAP HIT during match %d — grading what there is."
			% _match_index)
		_grade()
		return
	if not RoundManager.round_active:
		return
	_apply_policy()
	_round_live_time += delta
	var can := RoundManager.lata
	if can != null and can.is_upright:
		_upright_time += delta
	_sample_slippers()

func _sample_slippers() -> void:
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null:
			continue
		var id := slipper.get_instance_id()
		var flying := slipper.is_flying()
		if flying and not bool(_slipper_was.get(id, false)):
			_throws += 1
		_slipper_was[id] = flying

func _on_score(slot: int, _total: int, delta_points: int, reason: String) -> void:
	if slot >= 0 and slot < 4:
		_score_total[slot] += delta_points
		if reason == "DEFENSE":
			_defense_by_slot[slot] += delta_points
	_score_by_reason[reason] = int(_score_by_reason.get(reason, 0)) + delta_points

func _on_lata_knocked(by_slot: int) -> void:
	_knockdowns += 1
	if by_slot >= 0 and by_slot < 4:
		_knockdowns_by_slot[by_slot] += 1

func _on_tagged(defender_slot: int, _victim_slot: int) -> void:
	_tags += 1
	if defender_slot >= 0 and defender_slot < 4:
		_tags_by_slot[defender_slot] += 1

func _grade() -> void:
	if _finished:
		return
	_finished = true
	Engine.time_scale = 1.0
	var mean_step := _step_total / maxf(float(_step_samples), 1.0)
	var matches := maxi(_match_index, 1)
	var failures: Array[String] = []

	print("")
	print("========== FAIR PROBE — policy %s, attackers %s =========="
		% [_policy_name(), _tier_name()])
	print("matches %d   rounds %d   live game time %.1f s   mean physics step %.4f s"
		% [matches, _rounds_seen, _round_live_time, mean_step])

	if mean_step > STEP_TOLERANCE:
		failures.append(("HARNESS: mean physics step %.4f s exceeds %.4f — contact "
			+ "sampling too coarse to trust. Re-run at scale=1.")
			% [mean_step, STEP_TOLERANCE])

	var upright_share := 100.0 * _upright_time / maxf(_round_live_time, 0.001)
	print("")
	print("--- the can ---")
	print("upright %.1f s of %.1f s live  (%.1f%%)   knockdowns %d   throws %d"
		% [_upright_time, _round_live_time, upright_share, _knockdowns, _throws])
	print("  ^ passive defence is paid per second of THIS, so it is the term's driver.")

	print("")
	print("--- where the points came from ---")
	var reasons := _score_by_reason.keys()
	reasons.sort()
	var grand := 0
	for reason in reasons:
		grand += int(_score_by_reason[reason])
	var defense_share := 0.0
	for reason in reasons:
		var points := int(_score_by_reason[reason])
		var share := 100.0 * float(points) / maxf(float(grand), 1.0)
		if reason == "DEFENSE":
			defense_share = share
		print("%-10s %6d   %5.1f%% of every point scored" % [reason, points, share])

	print("")
	print("--- per seat (each defends exactly once) ---")
	var high := 0
	var best_slot := -1
	for slot in range(4):
		print("P%d  total %6d   of which DEFENSE %5d (%4.1f%%)   tags %2d   knockdowns %2d"
			% [slot + 1, _score_total[slot], _defense_by_slot[slot],
				100.0 * float(_defense_by_slot[slot]) / maxf(float(_score_total[slot]), 1.0),
				_tags_by_slot[slot], _knockdowns_by_slot[slot]])
		if _score_total[slot] > high:
			high = _score_total[slot]
			best_slot = slot
	print("wins by seat %s   draws %d" % [str(_wins), _draws])

	print("")
	print("--- the §2.1 arithmetic, against the measurement ---")
	print("the alarm: +10/s x 90 s = 900 uncontested, against +100 a knockdown.")
	print("measured : DEFENSE is %.1f%% of every point with the taya playing %s."
		% [defense_share, _policy_name()])
	var per_round_defense := float(int(_score_by_reason.get("DEFENSE", 0))) / maxf(float(_rounds_seen), 1.0)
	print("           a taya collects %.0f of the theoretical 900 per round (%.0f%% of it)."
		% [per_round_defense, 100.0 * per_round_defense / 900.0])

	if _policy == Policy.TURTLE and _completed_matches >= 1:
		print("")
		print("passive share %.1f%%   (gate: <= %.1f%% under `turtle`)"
			% [defense_share, GATE_PASSIVE_SHARE])
		if defense_share > GATE_PASSIVE_SHARE:
			failures.append(("PASSIVE DOMINANCE: %.1f%% of every point in a whole match "
				+ "came from standing still while the can stayed up. The catch-up term "
				+ "is the game.") % defense_share)
		if not GATE_TURTLE_MAY_WIN and best_slot >= 0 \
				and float(_defense_by_slot[best_slot]) / maxf(float(_score_total[best_slot]), 1.0) > 0.5:
			failures.append(("DEGENERATE STRATEGY: the leading seat P%d earned %.0f%% of "
				+ "its points passively — hiding out-scores playing.")
				% [best_slot + 1, 100.0 * float(_defense_by_slot[best_slot])
					/ maxf(float(_score_total[best_slot]), 1.0)])
	elif _policy == Policy.TURTLE:
		print("")
		print("       ^ NOT GATED: %d complete match(es). The share is only meaningful"
			% _completed_matches)
		print("         over a whole four-round rotation.")

	print("")
	if failures.is_empty():
		print("RESULT: PASS")
		get_tree().quit(0)
		return
	print("RESULT: FAIL — %d gate(s)" % failures.size())
	for line in failures:
		print("  * " + line)
	get_tree().quit(1)

func _policy_name() -> String:
	match _policy:
		Policy.BOT:
			return "bot"
		Policy.IDLE:
			return "idle"
		_:
			return "turtle"

func _tier_name() -> String:
	if _tier == AIController.Difficulty.BATA:
		return "EASY"
	if _tier == AIController.Difficulty.ASTIG:
		return "HARD"
	return "NORMAL"

