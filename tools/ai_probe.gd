extends Node3D
## The AI harness. **Rewritten 2026-08-01 by 🤖 `build ai`.**
##
##     Godot_v4.7.1-stable_win64_console.exe --path <repo> tools/ai_probe.tscn -- \
##         matches=3 scale=6 tier=NORMAL
##
## | argument | default | what it does |
## |---|---|---|
## | `matches=N` | 3 | whole 4-round matches, played back to back |
## | `rounds=N` | — | stop after N rounds total, whatever match they fall in |
## | `scale=X` | 6 | game seconds per real second (see § TIME SCALE) |
## | `tier=EASY/NORMAL/HARD` | NORMAL | which difficulty to measure |
## | `trace` | off | `AIController.trace_enabled` — one line per plan change |
## | `secs=N` | 900 | wall-clock safety cap |
##
## ⚠️ WHY THE PREDECESSOR WAS DELETED RATHER THAN EXTENDED. It was 1 579 lines
## measuring a game that no longer exists: `taya_pursue_radius`,
## `attacker_lob_overhold`, `CAN_EVADE_LOOKAHEAD` and `_take_over_human_slot()`
## are all names of things the HARRYDAKS pivot removed, and it asserted against a
## 2v2 with playable props. §2.10 files every probe in `tools/` root as stale;
## this is the one that earned a rewrite, because §6 needs a number.
##
## ⚠️ AND ITS FLAGGED-FOR-REMOVAL HACK IS GONE FOR REAL. The old file carried
## `_take_over_human_slot()` — a fourth `AIController` bolted onto the human's
## seat plus a camera-rig fiddle — under a human instruction to flag it
## (*"maybe allow option to switch the user with ai as well js for testing ai
## fairness? flag this"*). The shipping game grew the correct version of that in
## the meantime: `GameLaunch.spectator` makes `main.gd::_start_local_test()`
## enable the human seat's own (normally disabled) controller, park its input and
## run the ready countdown itself. **This probe measures four bots through the
## game's own spectator path, so there is no test-only code inside the
## measurement at all.**
##
## ⚠️ RUN IT WITH THE PLAIN EXE OR THE CONSOLE ONE, NEVER `--headless`. Same rule
## as everything else here: headless has no rendering device, and this boots the
## real `Main.tscn` with cameras, viewmodels and a HUD on it.
##
## ⚠️ IT EXITS NON-ZERO WHEN A GATE FAILS, and the gates are chosen so the code
## this replaced goes RED on them — see § GATES. A probe that cannot fail is
## worse than no probe (§6 trap 3), and the two headline numbers on the board
## (51 flights / 0 knockdowns, and 14.2 m of travel) are exactly the shape of
## failure it has to be able to report.

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

## ---------------------------------------------------------------------------
## § TIME SCALE — and why this probe does not just set `time_scale` and hope.
##
## ⚠️⚠️ `Engine.time_scale` ALONE MAKES EVERY PHYSICS STEP LONGER, WHICH BREAKS
## THE EXACT THING BEING MEASURED. A slipper flies at up to 17 m/s and the lata's
## hit window is `HIT_RADIUS + 0.30` = **0.53 m** wide, tested once per physics
## frame. At 60 Hz a slipper advances 0.28 m per step and cannot miss the window;
## at `time_scale = 6` with the tick rate left alone it advances **1.7 m** and
## sails straight through the can. The run would then report an AI that never
## scores while the AI was in fact hitting it — the worst kind of wrong number,
## because it agrees with the bug you are looking for.
##
## So the tick rate is raised by the same factor, which keeps the STEP SIZE at
## 1/60 s of game time and buys the speed-up out of more steps per rendered frame
## instead. `_grade()` then re-checks the mean observed step and REFUSES TO GRADE
## if it drifted: an impossible number is a broken harness, not a result.
const DEFAULT_SCALE: float = 6.0
const BASE_TICKS: int = 60
## The step size this probe promises. Beyond this the run is void.
const STEP_TOLERANCE: float = 1.0 / 45.0

const DEFAULT_MATCHES: int = 3
const DEFAULT_WALL_CAP: float = 900.0

## Below this planar speed a unit counts as standing still.
const STILL_SPEED: float = 0.35

## ---------------------------------------------------------------------------
## § GATES. Each one names the measured failure it exists to catch.
## ---------------------------------------------------------------------------
## §6.6 — "51 flights, 0 knockdowns". A match in which nobody knocks the lata
## over is not a game, and it is the specific thing that was wrong.
const GATE_KNOCKDOWNS_PER_MATCH: float = 1.0
## §6.7 — "P3 = 14.2 m, P4 = 26.0 m over a 90 s round". Ninety seconds of
## attacker walk is 310 m of ground available, so 60 is a floor no playing bot
## can be under and no frozen bot can reach.
const GATE_METRES_PER_ROUND: float = 60.0
## A bot that stands still for eight live seconds is not making a decision.
const GATE_MAX_STILL: float = 8.0
## Fairness. Every seat defends exactly once and attacks three times, so four
## bots of one tier should land within a band of each other. Wide on purpose: it
## is a check that the roles are playable from BOTH sides, not a claim that four
## bots should tie.
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

## Accumulated over the whole run, indexed by seat.
var _score_total: Array[int] = [0, 0, 0, 0]
var _score_by_reason: Dictionary = {}
var _metres: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _still_run: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _still_worst: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _still_plan: Array[String] = ["-", "-", "-", "-"]
## Pressing a direction and going nowhere: blocked by a body or by geometry.
var _blocked_run: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _blocked_worst: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _blocked_plan: Array[String] = ["-", "-", "-", "-"]
var _taggable_time: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _wins: Array[int] = [0, 0, 0, 0]
var _draws: int = 0
## Matches that ran all four rounds. The fairness gate needs these; a run that
## stops mid-rotation has not measured fairness at all.
var _completed_matches: int = 0
var _last_pos: Array = [null, null, null, null]

## Slipper flights. One record per launch, closed when the slipper stops flying.
var _throws: int = 0
var _throws_by_slot: Array[int] = [0, 0, 0, 0]
var _knockdowns: int = 0
var _knockdowns_by_slot: Array[int] = [0, 0, 0, 0]
var _tags: int = 0
var _sabotages: int = 0
## Flights that got inside a metre of the can without putting it over — the body
## block and the near miss, which are a different failure from a throw that never
## arrived at all, and telling them apart is the whole point (§6.6 was the
## second kind being read as the first).
var _near_misses: int = 0
var _flight_open: Dictionary = {}
## ⚠️ A SEPARATE SET, BECAUSE THE FIRST VERSION DOUBLE-COUNTED AND THE TOTAL SAID
## SO. It marked a flight resolved by writing `INF` back into its closest
## approach — but a slipper that knocks the lata over **keeps flying**: it recoils
## (`slipper.gd::LATA_RECOIL_SCALE`) and then bounces around within a metre of the
## can, so the minimum immediately fell back under the near-miss threshold and the
## same flight was counted twice. The tell was an impossible number: 33
## knockdowns + 44 near misses out of **51** throws. Two outcomes of one flight
## cannot exceed the flights.
var _flight_scored: Dictionary = {}
var _slipper_was: Dictionary = {}

## Physics-step honesty (§ TIME SCALE).
var _step_samples: int = 0
var _step_total: float = 0.0

var _round_live_time: float = 0.0
var _wall_start: float = 0.0

func _ready() -> void:
	_parse_args()
	_wall_start = Time.get_ticks_msec() / 1000.0
	AIController.apply_difficulty(_tier as AIController.Difficulty)
	# ⚠️ RAISED TOGETHER, NEVER SEPARATELY — see § TIME SCALE.
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

## ---------------------------------------------------------------------------
## THE RUN. One whole match at a time, through the game's own spectator path.
## ---------------------------------------------------------------------------
func _start_match() -> void:
	_match_index += 1
	# ⚠️ `spectator` IS WHAT MAKES ALL FOUR SEATS BOTS, and it is a SHIPPING code
	# path rather than a probe hack — see the header.
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

## ---------------------------------------------------------------------------
## SAMPLING. Everything is measured off the game's own signals and transforms —
## nothing here asks `AIController` what it MEANT to do.
## ---------------------------------------------------------------------------
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
		# ⚠️⚠️ NOT MOVING AND NOT TRYING TO ARE DIFFERENT FAILURES, AND THE FIRST
		# VERSION OF THIS CONFLATED THEM. It gated on speed alone and then failed a
		# HARD run for "P1 stood still 20.3 s" — while P1 was in fact walking into a
		# body every one of those frames. `move_and_slide()` writes the RESOLVED
		# velocity back, so a unit pressing into another capsule reads exactly like a
		# unit pressing nothing at all.
		#
		# The gated number is now "still AND pressing nothing", which is the frozen
		# bot this probe exists to catch. Blocked-but-pushing is reported beside it,
		# because a bot that leans on a wall for a whole round is also wrong — just
		# wrong in a way that needs a different fix.
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

## Flights, opened on the transition into `FLYING` and closed on the way out.
## The closest approach is recorded WHILE it flies rather than inferred after.
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

## The bot's own word for what it is doing, when it has one.
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
	# A knockdown resolves whichever flights are open as HITS, not near misses.
	for id in _flight_open.keys():
		_flight_scored[id] = true

func _on_tagged(_defender_slot: int, _victim_slot: int) -> void:
	_tags += 1

## ---------------------------------------------------------------------------
## § THE REPORT AND THE GATES.
## ---------------------------------------------------------------------------
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

	# ⚠️ THE HARNESS IS GRADED BEFORE THE AI IS. If the step drifted, every contact
	# number below is measuring the time scale rather than the bots.
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
	# ⚠️ THIS BLOCK IS ⚖️ `build fair`'s §2.1 EVIDENCE AND NOT THIS LANE'S TO ACT
	# ON. Passive defence pays +10/s for 90 s uncontested against +100 for a
	# knockdown; the DEFENSE percentage above is the first measurement of that
	# ratio ever taken over whole matches. Printed, never gated — moving the
	# number is another lane's row.

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
	# ⚠️⚠️ THE GATE ONLY APPLIES TO WHOLE MATCHES, AND ITS FIRST RUN PROVED WHY.
	# A `rounds=2` run stopped after P1 and P2 had defended and P3 and P4 never
	# had, then failed the fairness gate on a 500..2160 spread — which is not
	# unfairness, it is **half a rotation**. The whole reason the schedule is a
	# pure function of the round number (`Design.md` §1) is that fairness here is
	# a property of the completed cycle; measuring it mid-cycle measures the
	# rotation, and a gate that fires on a correct game is worse than no gate.
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
