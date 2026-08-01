extends Node3D
## THE PASSIVE-DEFENCE EXPERIMENT. **Written 2026-08-01 by ⚖️ `build fair`.**
##
##     Godot_v4.7.1-stable_win64_console.exe --path <repo> tools/fair_probe.tscn -- \
##         policy=turtle matches=1 scale=6 tier=NORMAL
##
## | argument | default | what it does |
## |---|---|---|
## | `policy=bot/idle/turtle` | turtle | what the taya does (see § THE THREE TAYAS) |
## | `matches=N` | 1 | whole 4-round matches, played back to back |
## | `scale=X` | 6 | game seconds per real second |
## | `tier=EASY/NORMAL/HARD` | NORMAL | the ATTACKERS' difficulty |
## | `seats=all/N` | all | which seats play the policy when THEY are taya |
## | `secs=N` | 900 | wall-clock safety cap |
##
## ---------------------------------------------------------------------------
## ⚠️⚠️ WHY THIS EXISTS AND WHY `ai_probe` COULD NOT ANSWER IT.
##
## `Agent_Prompts.md` §2.1 has been the board's number-one balance suspect since
## the pivot, on ARITHMETIC alone: passive defence pays the taya +10/s for a 90 s
## round, which is **900 points uncontested**, against **+100** for a knockdown.
## §2.25 measured it for the first time on 2026-08-01 and found DEFENSE is
## **21–32%** of every point against a competent offence and **77%** against a
## broken one — so the term is dominant exactly when the attackers cannot convert,
## and it degrades as they get better.
##
## ⚠️ BUT THAT MEASUREMENT IS ENTIRELY BOT-VS-BOT, AND THE BOT TAYA PLAYS THE GAME.
## It guards, it intercepts, it hunts, and it LUNGES — `ai_probe` at NORMAL reports
## 21 tags a match. The case §2.25's own note says it does not settle is the one the
## arithmetic actually warns about: **a HUMAN taya who simply hides behind the lata**
## and never risks anything. Nothing in this repo could produce that player, so the
## 900 has never been observed — only reasoned about.
##
## This probe produces that player, and it does it through the game's own intent
## harness (`CharacterBase.ai_set_intent`), so the passive taya presses the same
## eight-way keyboard a human presses. A policy that wrote `velocity` directly
## would be measuring a unit the game cannot contain, and the number that came
## back would not be about the rule.
##
## ⚠️ `ai_controller.gd` IS 🤖 `build ai`'s FILE AND IS NOT EDITED. The two brains
## below EXTEND `AIController` from this file and override `decide()`, and the
## real controller is disabled (not destroyed) for exactly the rounds the policy
## is in force, then handed back. Nothing about the shipping AI changes.
## ---------------------------------------------------------------------------
##
## § THE THREE TAYAS. Each one is the same game with one thing removed, so the
## difference between two runs is attributable to that one thing.
##
##   `bot`    — the shipping `AIController`, untouched. The CONTROL. Should
##              reproduce `ai_probe` at the same tier; if it does not, the
##              takeover machinery is lying and every other row is void.
##   `idle`   — the taya presses NOTHING. The floor: what does zero effort
##              collect? ⚠️ Not the 900 — an idle taya never stands the lata back
##              up, so its passive income stops at the first knockdown. That is
##              itself a finding and it is why "uncontested" was always the load
##              -bearing word in §2.1's arithmetic.
##   `turtle` — the exploit. It guards from the SAME post the shipping bot guards
##              from and it resets the lata the moment it goes down, but it
##              **never lunges**. So `turtle` minus `bot` is exactly the value of
##              the tag, and `turtle` is the best passive game the rules allow.
##
## ⚠️ THE STANDOFF IS DELIBERATELY THE BOT'S OWN `GUARD_RADIUS` (2.2 m). Copying
## the shipping positioning is what makes `bot` vs `turtle` a one-variable
## experiment. A hand-tuned "better" post would have measured this probe's
## author's positioning instead of measuring the rule.
##
## ⚠️ RUN IT WITH THE PLAIN EXE OR THE CONSOLE ONE, NEVER `--headless` — it boots
## the real `Main.tscn` with cameras and a HUD on it, and headless has no
## rendering device.

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

## ⚠️ THE SAME TIME-SCALE CONTRACT `ai_probe` KEEPS, AND FOR THE SAME REASON.
## `Engine.time_scale` alone makes every physics STEP longer, and a slipper at
## 17 m/s against the lata's 0.53 m hit window then advances 1.7 m per step and
## sails through the can — which would report an offence that never scores while
## it was in fact hitting, i.e. a number that agrees with the bug being hunted.
## The tick rate is raised by the same factor so the step stays 1/60 s of game
## time, and `_grade()` refuses to grade if it drifted.
const BASE_TICKS: int = 60
const STEP_TOLERANCE: float = 1.0 / 45.0
const DEFAULT_SCALE: float = 6.0
const DEFAULT_MATCHES: int = 1
const DEFAULT_WALL_CAP: float = 900.0

## ---------------------------------------------------------------------------
## § THE GATE. One claim, falsifiable, and it goes RED on the shipping numbers.
##
## The claim under test is **"passive defence is not the game"**. Under `turtle`
## every one of the four seats plays the best passive taya the rules allow for
## its own round, so the seat asymmetry cancels and what is left is the size of
## the term itself. If more than this share of every point in a whole match comes
## from the one verb that costs nothing and risks nothing, the term IS the game.
##
## ⚠️ 50% IS THE HONEST LINE AND NOT A ROUND NUMBER PICKED TO PASS. Four rounds
## have exactly one taya and three attackers each; a rule that pays one player
## more than the other three combined, for standing still, is not a catch-up term
## any more. ⚠️ IT IS ONLY APPLIED UNDER `turtle` — grading `bot` on it would be
## grading the AI's competence, which is not this lane's row (§2.27).
const GATE_PASSIVE_SHARE: float = 50.0

## Under `turtle` the taya concedes every tag by construction, so a passive seat
## that STILL out-scores the field is a dominant degenerate strategy — the thing
## "Esports Potential" cannot survive. Reported always; gated under `turtle`.
const GATE_TURTLE_MAY_WIN: bool = false

enum Policy { BOT, IDLE, TURTLE }

var _policy: Policy = Policy.TURTLE
var _matches_target: int = DEFAULT_MATCHES
var _scale: float = DEFAULT_SCALE
var _wall_cap: float = DEFAULT_WALL_CAP
var _tier: int = AIController.Difficulty.NORMAL
## -1 is "every seat, on its own round".
var _seat_filter: int = -1

var _main: Node = null
var _match_index: int = 0
var _rounds_seen: int = 0
var _finished: bool = false
var _wall_start: float = 0.0

## Live brains, and the shipping controllers they displaced. Keyed by seat.
var _brains: Dictionary = {}
var _origins: Dictionary = {}

var _score_total: Array[int] = [0, 0, 0, 0]
var _score_by_reason: Dictionary = {}
## Per seat, points earned WHILE THAT SEAT WAS THE TAYA. The passive income.
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

## The driver of the whole defence term: how long the can spent standing.
var _upright_time: float = 0.0
var _round_live_time: float = 0.0

var _step_samples: int = 0
var _step_total: float = 0.0

## ---------------------------------------------------------------------------
## § THE BRAINS. Both extend the shipping controller and override `decide()`,
## so they inherit `_press()`/`_drive()`/`_stop()` — the eight-way keyboard —
## and nothing else about `AIController` runs.
## ---------------------------------------------------------------------------

## A taya that does nothing at all. The floor.
class IdleBrain extends AIController:
	func decide(_delta: float) -> void:
		if character == null or not is_instance_valid(character):
			return
		_stop()
		_press("grab", false)
		_press("lunge", false)
		_press("special_ability", false)

## A taya that plays the best passive game the rules allow, and never lunges.
class TurtleBrain extends AIController:
	## The shipping bot's own `GUARD_RADIUS`. See the header on why it is copied.
	const BLOCK_STANDOFF: float = 2.2
	## ⚠️ NOT `ARRIVE_SLOP` — that name already exists on `AIController` and a
	## subclass redeclaring a parent's const is a PARSE ERROR, not a shadow.
	## ⚠️ AND `--headless --import` DID NOT REPORT IT. The documented "one cheap
	## real gate" (docs/README.md) came back clean while this file could not load
	## at all; the parse error only appeared when the scene was actually run. A
	## tool script is not proven by an import.
	const POST_SLOP: float = 0.55

	func decide(_delta: float) -> void:
		if character == null or not is_instance_valid(character):
			return
		# ⚠️ THE ENTIRE EXPERIMENT IS THIS LINE. Everything else here is ordinary
		# defensive play; refusing to lunge is what makes it PASSIVE, and the
		# difference between this run and `policy=bot` is the value of the tag.
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
			# Uptime IS the score, so the channel is the highest-value thing a
			# passive taya can be doing. ⚠️ HELD, NOT TAPPED: `carrier.gd`'s
			# channel reads `input_pressed` and zeroes on any false frame.
			var inside := can.is_in_ring(character.global_position)
			if inside:
				_stop()
			else:
				_walk_to(can.global_position, Lata.INTERACTION_RADIUS * 0.55)
			_press("grab", inside)
			return
		_press("grab", false)
		# Hide behind the can: stand on the line between it and whoever is most
		# likely to throw next, which is what makes the body a block.
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

	## ⚠️ NEVER SPRINTS. A passive taya has no reason to spend a 1.25 s bar it
	## cannot convert into a tag, and spending it would import the fatigue rule
	## into a measurement that is not about fatigue.
	func _walk_to(point: Vector3, stop_at: float) -> void:
		var delta := point - character.global_position
		delta.y = 0.0
		if delta.length() <= stop_at:
			_stop()
			return
		_drive(delta, false)

	## The armed attacker nearest the can, preferring one already winding up.
	## Deliberately simpler than the shipping `_live_threat()` — a human hiding
	## behind a can is not running a sixteen-bearing solver.
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

## ---------------------------------------------------------------------------
## THE RUN.
## ---------------------------------------------------------------------------

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
	# `spectator` makes all four seats bots through the SHIPPING code path — the
	# same one `ai_probe` uses, so the two harnesses cannot diverge on setup.
	GameLaunch.spectator = true
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_slipper_was.clear()
	_brains.clear()
	_origins.clear()

func _end_match() -> void:
	# The brains are children of characters under `_main`, so they die with it.
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

## ---------------------------------------------------------------------------
## THE TAKEOVER. Re-asserted every physics frame rather than driven off
## `round_started`, and that is not laziness.
##
## ⚠️ `main.gd::_reassert_spectated_bots()` RE-ENABLES `character.ai_controller`
## on a schedule of its own, and the role rotates at a round boundary this node
## does not own the ordering of. An idempotent check every frame cannot be raced
## by either; a one-shot on a signal can be, and a taya that quietly reverted to
## the shipping brain for part of a round would report a `turtle` number that had
## the lunge back in it.
## ---------------------------------------------------------------------------
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
		# Releases everything it is mid-press on and wipes the intent dictionary,
		# so nothing stays "held" across the swap.
		original.set_enabled(false)
	_origins[slot] = original
	var brain: AIController = IdleBrain.new() if _policy == Policy.IDLE else TurtleBrain.new()
	brain.name = "FairProbeBrain"
	# `AIController._ready()` reads `character` off its parent, so parenting to
	# the unit is what wires it up.
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

## ---------------------------------------------------------------------------
## SAMPLING.
## ---------------------------------------------------------------------------
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

## ---------------------------------------------------------------------------
## § THE REPORT.
## ---------------------------------------------------------------------------
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

	# ⚠️ THE HARNESS IS GRADED BEFORE THE RULE IS. A drifted step makes every
	# contact number below a measurement of the time scale.
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

	# ⚠️ GATED ONLY UNDER `turtle`. Grading `bot` here would be grading how good
	# `build ai`'s controller is, which is explicitly not this lane's number
	# (§2.27, and the lane prompt's own warning about tuning against the AI).
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
