extends Node3D
## The AI harness. Two modes, one tool — per Checklist §9's own instruction that
## balance runs "should extend it rather than adding a second tool".
##
##   godot --path . tools/ai_probe.tscn
##       INDEPENDENCE (default, unchanged). Proves the bots are independent and
##       never freeze. This is the mode every existing Checklist/Handoff number
##       came from; its output format is deliberately untouched.
##
##   godot --path . tools/ai_probe.tscn -- fairness rounds=20 scale=4
##       FAIRNESS. Plays whole AI-vs-AI matches back to back and reports the
##       four numbers Checklist §9's table asks for, plus the still-run number
##       from the independence mode (a frozen bot invalidates a win rate, so
##       they are worth reading together).
##
## ⚠️ NEVER RUN EITHER MODE WITH `--headless`. Same rule as the smoke gate's
## commands 3 and 4 (Concurrency_Protocol.md §8): a headless run never renders a
## pixel and misses the entire class of bug B-77..B-80 belonged to. This is
## "headless-DRIVEN" — nobody touches a key — but it renders.
##
## ⚠️ THE FAIRNESS MODE TAKES OVER THE HUMAN'S UNIT. In Single Player,
## main.gd::_start_local_test() attaches AI to three of the four units and
## leaves TeamAPerson for the human. Measuring fairness with that slot empty
## would be measuring nothing: whenever Team A is the offence, its Attacker is a
## unit that never moves, so the defence "wins" every one of those rounds for
## free. _take_over_human_slot() attaches a fourth AIController and — this part
## is not optional — flips that unit's CameraRig off MOUSE aim, because
## character_base.gd reads WASD in the BODY's frame for a mouse-aimed unit
## (B-60) and the AI's _move_toward() emits WORLD-space directions.
##
## ⚠️⚠️ THE HUMAN-SLOT TAKEOVER IS TEST-ONLY AND IS FLAGGED FOR REMOVAL.
## 🧑 Human ask, 2026-07-30, verbatim: *"one is controlled by me so it isn't AI
## fairness... maybe allow option to switch the user with ai as well js for
## testing ai fairness? flag this."*
##
## It exists for exactly one reason: a fairness table that leaves the human's own
## Single Player seat unpiloted is measuring three bots and one statue, and the
## numbers it prints are not about AI at all. Nothing in the shipping game may
## ever depend on it.
##
## REMOVAL IS ONE FUNCTION AND ONE CALL SITE. It lives entirely in this file, is
## reached only from the `fairness` command-line mode, and `tools/` does not
## ship — so it is already inside the one-way-dependency rule Dev_Plan.md §0.3
## sets for debug code (debug may call gameplay; gameplay never names debug).
## Deleting `_take_over_human_slot()` and its call in _ready() leaves nothing
## behind. Recorded here and in Checklist.md's RUN 8 so it does not have to be
## re-derived later.

## Independence mode: how long to sample.
const SECONDS := 14.0
## Fairness mode: default number of ROUNDS to play. §9 asks for >= 20.
const DEFAULT_ROUNDS := 20
## Fairness mode: default Engine.time_scale. A round is capped at
## RoundManager.ROUND_TIME (90s), so 20 rounds is up to 30 minutes of game time;
## this is what makes that a tolerable wall-clock run. ⚠️ EVERY NUMBER BELOW IS
## MEASURED IN GAME TIME (accumulated physics delta), never wall clock, so the
## scale does not distort the reported values — but it does change how many
## physics steps land per rendered frame, so a result at scale 4 is not
## automatically identical to one at scale 1. Re-run a headline number at
## scale=1 before writing it into the fairness log as final.
const DEFAULT_SCALE := 4.0
## Below this planar speed a bot counts as standing still (independence mode's
## own threshold, reused so the two modes' still-run numbers are comparable).
const STILL_SPEED := 0.35
## Frames of continuous stillness after which a `trace` run names the branch
## responsible. 2 s is the fairness table's own "a frozen bot is not a difficulty
## setting" threshold, so this fires exactly when the metric starts failing.
const STILL_REPORT_FRAMES := 120
## How far a unit must get from its last recorded spot to count as having gone
## anywhere. ⚠️ IT HAS TO BE SMALLER THAN THE AI'S IDLE SHUFFLE RADIUS (0.22) OR THE
## METRIC MEASURES ITS OWN THRESHOLD: at 0.25 every unit idling on its mark scored as
## having gone nowhere for seconds at a time, which is true and useless — an idling
## unit is not a frozen one, and the point of this number is to catch the frozen kind.
## 0.12 is half a shuffle, so a settling unit registers and a stuck one does not.
const STILL_DISPLACEMENT := 0.12

var _mode := "independence"
var _target_rounds := DEFAULT_ROUNDS
## The scale this run asked for, re-asserted every frame — see _reassert_scale().
var _scale := 1.0

var _main: Node
var _bots: Array = []
var _moving: Dictionary = {}
var _still_run: Dictionary = {}
var _still_max: Dictionary = {}
var _transitions: Dictionary = {}
## Displacement-based stillness — see the note in _physics_process.
var _last_pos: Dictionary = {}
var _frozen_run: Dictionary = {}
var _frozen_max: Dictionary = {}
var _same_frame := 0
var _frames := 0
var _t := 0.0

## --- Fairness bookkeeping ---------------------------------------------------
## One dictionary per completed round; see _open_round() for the fields.
var _rounds: Array[Dictionary] = []
var _round: Dictionary = {}
var _round_open := false
var _round_time := 0.0
## Per-Carriable flight record while a throw is in the air: {carriable: {...}}.
var _flights: Dictionary = {}
## Last seen dent count per Can, so a round reset (dents back to 0) is not
## counted as a negative dent and a re-dent after a reset is counted once.
var _dents_seen: Dictionary = {}
var _finishing := false

## --- R-08: which round-win rule this run is measuring ------------------------
## "control" | "slipper" | "inside". See _suppress_tag_win() for how a variant is
## imposed WITHOUT editing hitbox.gd — that file belongs to another lane, and the
## point of R-08 is to produce a table a human picks from, not to ship a rule.
var _tag_variant := "control"
## R-08's new column: how long a round lasted, aggregated. A variant that fixes
## the win rate by making rounds twice as long has failed the no-dead-time pillar.
var _respawns := 0

## --- R-21: position heatmap --------------------------------------------------
var _heatmap := false
var _heat_accum := 0.0
## {unit_name: [Vector2, ...]} in world XZ, sampled once a second of GAME time.
var _heat_samples: Dictionary = {}

## --- R-07: did the attacker's slide actually beat the taya's post? -----------
## `trace` turns on AIController.trace_enabled and prints the branch path of both
## Persons at the moment of every throw, capped so a 20-round run does not become
## unreadable.
var _trace := false
var _traces_printed := 0
const MAX_TRACES := 24
## Throws released while the defending Taya's committed post was wrong by more than
## `taya_repost_angle` — i.e. throws the attacker's bearing-slide EARNED, as opposed
## to throws that walked into a defender already standing in the right place.
## ⚠️ Asked of AIController.taya_post_error(), which is the controller's own live
## number. The probe deliberately does not re-derive the geometry: a second copy of
## the angle maths here could agree with itself while disagreeing with the bot, and
## then the column would be measuring the probe.
var _post_error_at_throw: Dictionary = {}
## Closest approach of every completed flight to the can, in units — the independent
## check on the hitbox metric. See _track_flight_geometry().
var _closest_approaches: Array[float] = []
var _closest_unblocked: Array[float] = []
var _aim_errors: Array[float] = []
var _throw_ranges: Array[float] = []

## --- R-02: the probe-honesty contract ---------------------------------------
## Deliberate-failure injection, so the three assertions can be SHOWN to refuse
## rather than asserted to work. `break=park|map|swap`. ⚠️ TEST-ONLY, and in the
## same one-way-dependency bracket as _take_over_human_slot(): it lives entirely
## in this file, is reached only from the fairness mode, and `tools/` does not ship.
var _break := ""
## Every `team_a_is_can` value the run actually observed on round_started. A
## fairness run in which one team was always the attacker is not a fairness
## measurement, and nothing before R-02 checked.
var _can_sides_seen: Dictionary = {}
## True once every honesty assertion has been evaluated, so the header cannot be
## printed before the contract has been.
var _honesty_ok := true

func _ready() -> void:
	_parse_args()
	# ⚠️ MEASURED, NOT GUESSED — the first 20-round attempt hung silently after
	# the first match. `match_result.gd` sets `get_tree().paused = true` when a
	# match is won (Q-4, deliberately, so the result screen holds), and a probe
	# at the default PROCESS_MODE_INHERIT stops getting _physics_process at that
	# moment — including the very code that would dismiss the screen. ALWAYS is
	# the same answer Main.tscn already gives the MatchResult node itself.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout

	if _mode == "fairness":
		_take_over_human_slot()

	# ⚠️ START THE ROUND. Bots are measured under real match conditions, not in
	# the pre-round free-roam window — several role behaviours key off
	# RoundManager's tracked cans, which do not exist until a round begins.
	# This deliberately bypasses main.gd's ready-up gate (_awaiting_local_ready)
	# rather than faking a keypress; nothing else reads that flag.
	if _mode == "fairness":
		_wire_fairness_signals()
	MatchManager.begin_next_round()
	await get_tree().create_timer(1.0).timeout
	print("round_active=", RoundManager.round_active, " round=", MatchManager.round_number)
	# ⚠️⚠️ R-02(a). "HAS A CONTROLLER" IS NOT "IS BEING DRIVEN", AND THIS LOOP IS
	# WHERE THE DISTINCTION WAS LOST. It used to accept any unit with
	# `ai_controller != null`, which is exactly how the probe printed "AI units
	# found: 4" through a whole run in which one of the four was a statue with a
	# DISABLED controller attached (RUN 8). Every per-bot metric below — the
	# transitions, the co-transition rate, the longest still run — was computed
	# over that statue too, and 58.48 s of "longest still run" turned out to be it.
	#
	# The test is now `is_enabled()`, the same question CharacterBase.is_ai_driven()
	# asks, and both counts are printed so a future divergence is visible rather
	# than inferred.
	var with_controller := 0
	for c in _main.find_children("*", "CharacterBase", true, false):
		if c.ai_controller == null:
			continue
		with_controller += 1
		if not c.ai_controller.is_enabled():
			continue
		_bots.append(c)
		_moving[c] = false
		_still_run[c] = 0
		_still_max[c] = 0
		_transitions[c] = 0
	print("AI units found: %d driven  (%d have a controller attached)"
		% [_bots.size(), with_controller])
	if _mode == "fairness":
		_assert_probe_honesty()
		# The map is named because it is now selectable and every number below
		# depends on it — an unlabelled fairness table is what let Eskinita's
		# results stand in for the project's.
		print("FAIRNESS RUN — target rounds: %d, %s, time_scale: %.1f, map: %s"
			% [_target_rounds, _mode_name(), _scale, GameLaunch.selected_map])
		# ⚠️ R-01. THE LEVER IS IN THE HEADER NOW. Both Taya knobs are printed
		# together because they are the two halves of the same behaviour — where the
		# post is, and when it is abandoned — and a table row whose standoff is not
		# written down beside its pursuit is a row nobody can reproduce.
		print("           taya_pursue_radius %.2f, taya_block_standoff %.2f, tier %s"
			% [AIController.taya_pursue_radius, AIController.taya_block_standoff,
				_tier_name()])
		print("           round-win rule: %s" % _tag_variant_name())
		print("           taya post: hold %.2fs, re-post past %.2f rad | lob: %s"
			% [AIController.taya_post_hold, AIController.taya_repost_angle,
				"ALLOWED (physics half may not exist yet)" if AIController.lob_enabled else "off"])
		print("           attacker band [%.2f, %.2f] | fetch-danger %.2f | thread %.2f"
			% [AIController.attacker_min_throw_range, AIController.ATTACKER_THROW_RANGE,
				AIController.attacker_fetch_danger, AIController.attacker_thread_max])
		print("           motion: gait %.2f, turn %.1f rad/s | flavour(R-10): %s "
			% [AIController.tier_gait, AIController.ai_turn_rate,
				"on" if AIController.flavour_enabled else "OFF"]
			+ "(jitter %.2f, windup %.2f, mistake %.2f)"
			% [AIController.attacker_charge_jitter, AIController.attacker_min_windup,
				AIController.tier_mistake])
	set_physics_process(true)

## R-02 · THE PROBE-HONESTY CONTRACT.
##
## Three things every fairness run before this one ASSUMED, printed and asserted.
## RUN 8's 3-v-4 was caught because a human happened to look; each of these is a
## `push_error` so the next one breaks the run instead of the log.
##
## (c) cannot be answered here — it needs the whole run — so it is asserted in
## _report_fairness() and stated here so a reader of one function sees all three.
func _assert_probe_honesty() -> void:
	print("\n  --- probe honesty contract (R-02) ---")

	# (a) FOUR GENUINELY AI-DRIVEN UNITS. Asked with is_enabled(), never `!= null`.
	if _break == "park" and not _bots.is_empty():
		# Deliberate failure for the acceptance test: park one unit exactly the way
		# RUN 8's harness accidentally did — controller attached, nothing driving it.
		var victim: CharacterBase = _bots[0]
		victim.ai_controller.set_enabled(false)
		_bots.erase(victim)
		print("  break=park: disabled %s's controller on purpose" % victim.name)
	var driven := _driven_count()
	print("  (a) units genuinely AI-driven (is_enabled): %d  (must be 4)" % driven)
	if driven != 4:
		_honesty_ok = false
		push_error("ai_probe: %d of 4 units are AI-driven — this run does not " % driven
			+ "measure AI fairness and its numbers are VOID.")

	# (b) THE MODE AND THE MAP ACTUALLY IN THE TREE, not the ones that were asked
	# for. `selected_map` is a preference; what decides every number below is the
	# scene that is really loaded, so the scene is what gets compared.
	var want_scene := GameLaunch.selected_map_scene()
	if _break == "map":
		GameLaunch.selected_map = &"bayan_plaza"
		want_scene = GameLaunch.selected_map_scene()
		print("  break=map: switched the REQUEST to bayan_plaza after the load, on purpose")
	var loaded := "<none>"
	for node in _main.find_children("*", "Node3D", true, false):
		if node.scene_file_path.begins_with("res://scenes/maps/"):
			loaded = node.scene_file_path
			break
	print("  (b) game mode in effect: %s" % _mode_name())
	print("      map requested: %s   map actually in the tree: %s" % [want_scene, loaded])
	if loaded != want_scene:
		_honesty_ok = false
		push_error("ai_probe: the map in the tree (%s) is not the map this run " % loaded
			+ "claims to measure (%s) — the numbers are labelled wrong." % want_scene)
	if GameLaunch.game_mode != GameLaunch.GameMode.OPTION_A \
			and not "mode=b" in OS.get_cmdline_user_args():
		_honesty_ok = false
		push_error("ai_probe: a fairness run must force OPTION_A unless mode=b was "
			+ "asked for — under OPTION_B the dents column measures literally nothing.")

	# (c) is asserted at report time; announced here so the contract reads as three.
	print("  (c) attacking side changes hands: checked at report time over all rounds")
	if _break == "swap":
		print("  break=swap: pinning team_a_is_can for the whole run, on purpose")

## R-02's (c) breaker, and it pins the GAME STATE rather than the recorded metric —
## faking the number the assertion reads would test nothing.
##
## `MatchManager.begin_next_round()` flips `team_a_is_can` on entry for every round
## after the first, so holding the field at `false` between rounds means every round
## STARTS at `true`: Team A is the Can side and Team B is the attacker, all run long.
## Called from _physics_process while no round is active — i.e. before the flip and
## before the `round_started` emit that main.gd assigns roles from.
func _pin_the_role_swap() -> void:
	if not RoundManager.round_active:
		MatchManager.team_a_is_can = false

## ⚠️ SPLIT THE MISS IN TWO: WAS THE AIM WRONG, OR DID THE FLIGHT NOT GO WHERE IT WAS
## AIMED? A closest-approach of 2.45 units says a throw missed; it does not say which
## half of the throw is at fault, and those are different bugs in different files. So
## the point the AI actually asked for (`CharacterBase.ai_aim_point`, which is what
## `carrier.gd::_aim_point()` returns for a bot) is compared against where the can was
## at that instant. Aim error ~0 with a large closest approach means the ballistics
## are not delivering; aim error ~2.5 means the AI is aiming at the wrong place.
func _aim_error(carriable: Carriable) -> float:
	var thrower := _thrower_of(carriable)
	if thrower == null or thrower.ai_aim_point == Vector3.INF:
		return -1.0
	var can: CharacterBase = null
	for c in RoundManager.get_tracked_cans():
		if is_instance_valid(c):
			can = c
			break
	if can == null:
		return -1.0
	var a := thrower.ai_aim_point
	var b := can.global_position
	return Vector2(a.x - b.x, a.z - b.z).length()

## Planar distance from the thrower to the can at the moment of release — so a throw
## that fell short can be told from one that was aimed badly.
func _throw_range(carriable: Carriable) -> float:
	var thrower := _thrower_of(carriable)
	if thrower == null:
		return -1.0
	for c in RoundManager.get_tracked_cans():
		if is_instance_valid(c):
			var a := thrower.global_position
			var b := c.global_position
			return Vector2(a.x - b.x, a.z - b.z).length()
	return -1.0

## Whoever just threw this: the attacking Person on the same team as the slipper.
func _thrower_of(carriable: Carriable) -> CharacterBase:
	var prop := carriable.get_parent() as CharacterBase
	if prop == null:
		return null
	for c in _main.find_children("*", "CharacterBase", true, false):
		if c.is_person and c.team == prop.team:
			return c
	return null

## ⚠️⚠️ AN INDEPENDENT GEOMETRIC MEASUREMENT OF EVERY THROW, SHARING NO CODE WITH THE
## HITBOX METRIC. `hit_probe.gd` has done this since the multi-hit work and it is the
## only reason the flight-hitbox blindness was ever caught: a resolution count and a
## closest-approach distance cannot both be wrong in the same direction, so when they
## disagree you know which one to doubt.
##
## It exists here because a run reported **27 throws that the taya did not block and 0
## that reached the can**, against `phys_probe`'s measured 3-in-9 for a clean throw.
## One of those is wrong and no amount of re-tuning the AI would say which: a throw
## missing by 0.2 units is bad luck, a throw missing by 3 is a broken aim, and a throw
## that never gets within 5 is falling short. The number distinguishes them; reasoning
## about the code does not.
##
## Closest approach is tracked per in-flight slipper, per physics frame, in 3D — the
## flight hitbox is a sphere about the slipper's own origin, so a planar distance would
## call a slipper sailing overhead a near miss.
func _track_flight_geometry() -> void:
	if _flights.is_empty():
		return
	var can: CharacterBase = null
	for c in RoundManager.get_tracked_cans():
		if is_instance_valid(c):
			can = c
			break
	if can == null:
		return
	for carriable in _flights:
		if not is_instance_valid(carriable):
			continue
		var prop := carriable.get_parent() as CharacterBase
		if prop == null or not is_instance_valid(prop):
			continue
		var flight: Dictionary = _flights[carriable]
		var d: float = prop.global_position.distance_to(can.global_position)
		if d < float(flight.get("closest", 1e9)):
			flight["closest"] = d

## R-07. The defending Person's own view of how wrong its post is, in radians, or
## -1.0 when there is no taya or it has no post. Asked of the controller, never
## re-derived here — see _post_error_at_throw's note.
func _taya_post_error() -> float:
	for c in _main.find_children("*", "CharacterBase", true, false):
		if not c.is_person or not c.team_is_can_side:
			continue
		if c.ai_controller == null or not c.ai_controller.has_method("taya_post_error"):
			continue
		return float(c.ai_controller.taya_post_error())
	return -1.0

## Planar distance between the two Persons. The number that says whether a 1.6-second
## tag is a spawn-layout fact or an impossible one.
func _person_gap() -> float:
	var persons: Array = []
	for c in _main.find_children("*", "CharacterBase", true, false):
		if c.is_person:
			persons.append(c)
	if persons.size() < 2:
		return -1.0
	var a: Vector3 = persons[0].global_position
	var b: Vector3 = persons[1].global_position
	return Vector2(a.x - b.x, a.z - b.z).length()

func _driven_count() -> int:
	var driven := 0
	for c in _main.find_children("*", "CharacterBase", true, false):
		if c.ai_controller != null and c.ai_controller.is_enabled():
			driven += 1
	return driven

## `-- fairness rounds=20 scale=4`. Everything is optional and order does not
## matter; an unrecognised token is reported rather than silently ignored,
## because a typo'd `round=20` that quietly runs the default would be a
## measurement reported under the wrong label.
func _parse_args() -> void:
	var scale := -1.0
	var tier := -1
	for arg in OS.get_cmdline_user_args():
		var token := String(arg)
		if token == "fairness" or token == "independence":
			_mode = token
		elif token.begins_with("rounds="):
			_target_rounds = maxi(1, int(token.substr(7)))
		# ⚠️ CEILING RAISED 8 -> 24, 2026-07-30, on a human ask for faster tests. The
		# ceiling was never a correctness bound — every number this probe reports is
		# accumulated physics delta (game time), so the scale does not distort a
		# value; it changes how many physics steps have to fit in one rendered frame.
		# `Engine.max_physics_steps_per_frame` is what actually limits that, and it
		# defaults to 8 — so a `scale=16` run WITHOUT raising it silently ran at 8 and
		# reported 16 in its own header. Raised alongside, below.
		# ⚠️ AND THEN PUT BACK TO 8, MEASURED. With the tick rate raised in proportion
		# (below), scale 1 and scale 4 agree — aim error 0.28 vs 0.34 units, block rate
		# 82.6% vs 78.6%. Scale 8 does NOT: aim error goes back up to 1.31, because
		# 480 physics ticks a second for four units is more than this machine delivers
		# in real time and the steps get long again. **Use scale 4. Anything above it
		# has to prove itself against a scale=1 run before its numbers are used.**
		# ⚠️ A HIGH SCALE IS FOR EXPLORING, NOT FOR THE LOG. Re-run a headline number
		# at scale=1 before writing it down as final; that rule predates this and is
		# not softened by it.
		elif token.begins_with("scale="):
			scale = clampf(float(token.substr(6)), 0.25, 8.0)
		elif token == "mode=b":
			GameLaunch.game_mode = GameLaunch.GameMode.OPTION_B
		elif token == "mode=a":
			GameLaunch.game_mode = GameLaunch.GameMode.OPTION_A
		# ⚠️ `map=` DID NOT EXIST, so every fairness number this harness has ever
		# produced describes Eskinita — and Bayan Plaza has never had its AI
		# tested at all. That map is the one with the project's ONLY piece of
		# dressing collision (Obstacles/MonumentBody), which is precisely the kind
		# of geometry a navless "walk toward the target" AI gets stuck on.
		elif token.begins_with("map="):
			GameLaunch.selected_map = StringName(token.substr(4))
		elif token.begins_with("pursue="):
			# Sweeps AIController.taya_pursue_radius without editing the
			# controller — see that field's own doc for why it is the lever.
			AIController.taya_pursue_radius = maxf(0.0, float(token.substr(7)))
		# ⚠️ R-01. THE ONE LEVER RUN 3, RUN 7 AND RUN 8 ALL POINTED AT AND NONE OF
		# THEM COULD MEASURE, because AIController.TAYA_BLOCK_STANDOFF was a `const`
		# and this parser had no argument for it. It is now a `static var` there for
		# the same reason `pursue=` exists: a sweep that needs a source edit per row
		# is a sweep nobody runs.
		elif token.begins_with("standoff="):
			AIController.taya_block_standoff = maxf(0.0, float(token.substr(9)))
		# R-07's two knobs, sweepable from the day they were written rather than
		# three runs later — R-01 is the whole argument for that.
		elif token.begins_with("posthold="):
			AIController.taya_post_hold = maxf(0.0, float(token.substr(9)))
		elif token.begins_with("repost="):
			AIController.taya_repost_angle = maxf(0.0, float(token.substr(7)))
		# The rest of the levers this pass added, all sweepable for the same reason
		# R-01 exists: a knob without a probe argument is a knob nobody measures.
		elif token.begins_with("minrange="):
			AIController.attacker_min_throw_range = maxf(0.0, float(token.substr(9)))
		elif token.begins_with("fetchdanger="):
			AIController.attacker_fetch_danger = maxf(0.0, float(token.substr(12)))
		elif token.begins_with("thread="):
			AIController.attacker_thread_max = maxf(0.0, float(token.substr(7)))
		elif token.begins_with("turn="):
			AIController.ai_turn_rate = maxf(0.5, float(token.substr(5)))
		elif token.begins_with("gait="):
			AIController.tier_gait = clampf(float(token.substr(5)), 0.2, 1.0)
		elif token.begins_with("mistake="):
			AIController.tier_mistake = clampf(float(token.substr(8)), 0.0, 1.0)
		elif token.begins_with("jitter="):
			AIController.attacker_charge_jitter = clampf(float(token.substr(7)), 0.0, 1.0)
		elif token.begins_with("windup="):
			AIController.attacker_min_windup = maxf(0.0, float(token.substr(7)))
		# R-10's master switch, so the flavour changes can be measured against their
		# own absence rather than asserted to be harmless.
		elif token.begins_with("fun="):
			AIController.flavour_enabled = token.substr(4).to_lower() in ["on", "true", "1"]
		# R-06's AI half. `lob=on` lets the attacker choose to go OVER a block
		# instead of feeding it. ⚠️ Until the PHYSICS half lands this only makes the
		# throw later, not higher — see AIController.lob_enabled.
		elif token.begins_with("lob="):
			AIController.lob_enabled = token.substr(4).to_lower() in ["on", "true", "1"]
		elif token.begins_with("lobhold="):
			AIController.attacker_lob_overhold = maxf(0.0, float(token.substr(8)))
		elif token == "trace":
			# R-07's acceptance asks for bt_trace() output. Off by default because it
			# allocates a String per composite per tick on every bot.
			_trace = true
			AIController.trace_enabled = true
		elif token.begins_with("tier="):
			# R-09. apply_difficulty() is complete, correct and — measured, not
			# assumed — called from nowhere outside its own class, so no tier but
			# NORMAL has ever been measured. This is the only caller in the repo.
			# ⚠️ ORDER MATTERS AGAINST `pursue=`/`standoff=`: apply_difficulty()
			# WRITES taya_pursue_radius, so a `tier=` after a `pursue=` silently
			# overwrites it. Deferred to the end of this function rather than
			# applied here, so the two can be combined in either order and the
			# explicit knob always wins — a run whose header disagrees with its own
			# arguments is the exact class of bug RUN 8 was.
			var name := token.substr(5).to_upper()
			if AIController.Difficulty.has(name):
				tier = int(AIController.Difficulty[name])
			else:
				push_error("ai_probe: unknown tier '%s' — expected BATA, NORMAL or ASTIG" % name)
		elif token.begins_with("tag="):
			# R-08. Which round-win rule to MEASURE — see _tag_variant's own doc.
			var variant := token.substr(4).to_lower()
			if variant in ["control", "slipper", "inside"]:
				_tag_variant = variant
			else:
				push_error("ai_probe: unknown tag variant '%s' — expected control, slipper or inside" % variant)
		elif token == "heatmap":
			# R-21. Position density over a whole run, emitted as a PNG.
			_heatmap = true
		elif token.begins_with("break="):
			# R-02's acceptance test. Breaks one honesty assertion on purpose so the
			# refusal can be SEEN. See _break's own doc.
			_break = token.substr(6).to_lower()
		else:
			push_warning("ai_probe: ignoring unrecognised argument '%s'" % token)
	# ⚠️ TIER FIRST, THEN THE EXPLICIT KNOBS — see the `tier=` branch above. The
	# tier is applied before the two overrides are re-asserted so that
	# `tier=ASTIG standoff=1.4` measures ASTIG's think/lead/charge at a standoff of
	# 1.4, rather than ASTIG silently discarding the standoff or the standoff
	# silently discarding ASTIG's pursuit.
	if tier >= 0:
		var keep_pursue := AIController.taya_pursue_radius
		var keep_standoff := AIController.taya_block_standoff
		AIController.apply_difficulty(tier)
		for arg in OS.get_cmdline_user_args():
			if String(arg).begins_with("pursue="):
				AIController.taya_pursue_radius = keep_pursue
			elif String(arg).begins_with("standoff="):
				AIController.taya_block_standoff = keep_standoff
	if scale > 0.0:
		_scale = scale
	elif _mode == "fairness":
		_scale = DEFAULT_SCALE
	Engine.time_scale = _scale
	# ⚠️⚠️ THE PHYSICS TICK RATE HAS TO RISE WITH THE TIME SCALE, AND NOT DOING SO
	# CORRUPTED AN ENTIRE AFTERNOON OF MEASUREMENTS. READ THIS BEFORE RAISING `scale=`.
	#
	# `Engine.time_scale` does not make the simulation run faster — it makes each
	# physics step cover more GAME TIME. At the default 60 ticks/second and scale 16,
	# one step is 16/60 = 0.267 s of game time, so a unit at SPEED 6.0 teleports
	# **1.6 units per step**. Every distance-based decision in the game is then being
	# made on a world that jumps a body-width at a time.
	#
	# How it was caught, because it looked exactly like an AI bug: throws were missing
	# the can by a median of 3.3 units, and the aim-error breakdown said the AI had
	# ASKED for a point up to 3.1 units from the can — a value larger than the sum of
	# every offset the aiming code can possibly apply (lead capped at 1.2, threading at
	# 0.45). An impossible number is not a bad AI, it is a broken measurement: the can
	# had simply moved a step and a half between the aim being written and the throw
	# leaving the hand.
	#
	# Raising the tick rate in proportion keeps the step at 1/60 s of GAME time, so a
	# high scale becomes what it claims to be — the same simulation, wall-clock faster,
	# paid for in CPU. `max_physics_steps_per_frame` has to come up with it or the
	# extra ticks are dropped instead of run.
	Engine.physics_ticks_per_second = maxi(60, int(round(60.0 * _scale)))
	Engine.max_physics_steps_per_frame = maxi(8, int(ceil(_scale)) * 8)
	# ⚠️⚠️ OPTION A BY DEFAULT FOR A FAIRNESS RUN, AND THIS IS NOT A PREFERENCE.
	#
	# `GameLaunch.game_mode` defaults to OPTION_B, where `dents` is never written
	# at all (hitbox.gd only takes the dent branch under OPTION_A) — so a
	# fairness run left on the default reports "0.00 dents per round" no matter
	# how well the attacker plays, and the Checklist §9 table's "can dents per
	# round" row measures literally nothing. This exact trap already cost this
	# project a debugging round once; see Handoff.md's own warning under B-118.
	# Pass `mode=b` to measure Option B deliberately.
	if _mode == "fairness" and not "mode=b" in OS.get_cmdline_user_args():
		GameLaunch.game_mode = GameLaunch.GameMode.OPTION_A

## ⚠️ MEASURED, NOT GUESSED — the first fairness run reported "time_scale 0.1"
## in its own header despite being launched at scale=6.
## `CharacterBase._end_hitstop()` restores `Engine.time_scale` to a HARDCODED
## 1.0 rather than to whatever it was before the dip, so the very first hit of
## a run silently stomps this probe's scale, and every hit after that leaves the
## run crawling at HITSTOP_TIME_SCALE. Re-asserting here rather than changing
## character_base.gd keeps a measurement tool out of gameplay code: the dip
## itself (0.05) is deliberately left alone and only the 1.0 restore is
## corrected, so hitstop still happens and still looks right.
func _reassert_scale() -> void:
	if is_equal_approx(Engine.time_scale, 1.0) and not is_equal_approx(_scale, 1.0):
		Engine.time_scale = _scale

## Attach a fourth AIController to whichever Person main.gd left for the human.
## See this file's class doc for why a fairness run is meaningless without it.
## ⚠️⚠️ "HAS A CONTROLLER" IS NOT THE SAME QUESTION AS "IS BEING DRIVEN", AND
## CONFUSING THE TWO SILENTLY VOIDED A WHOLE FAIRNESS RUN.
##
## This used to skip any unit with `ai_controller != null`. That was correct
## while `main.gd::_start_local_test()` attached controllers only to the three
## units the human was NOT playing — the human's own seat was the one with a
## null controller, so the null test found exactly it.
##
## Since 2026-07-30 every unit gets a controller and the human's is created
## DISABLED (`CharacterBase.is_ai_driven()` requires both). The null test
## therefore matched nothing, this function printed nothing, and the human's seat
## stood inert for the entire run — while the probe's own "AI units found: 4"
## line, which counts CONTROLLERS, went on reporting four.
##
## The measured result was a fairness table describing a 3v4: every round in
## which that seat drew the ATTACKER reported `0 throws` and the round was
## handed to the defence by timeout, which read as a balance finding rather than
## as a broken harness. Longest still run 58.48 s was the inert unit, not a bot
## that froze.
##
## This is trap 2 from the repo's own method note, exactly: a probe that does not
## LOOK at the thing you changed passes anyway. So the test is now "is anything
## actually DRIVING this unit", and the count is asserted out loud below.
func _take_over_human_slot() -> void:
	var taken := 0
	for c in _main.find_children("*", "CharacterBase", true, false):
		if not c.is_person:
			continue
		if c.ai_controller != null and c.ai_controller.is_enabled():
			continue # genuinely already driven
		# ⚠️ MOVEMENT, NOT MOUSE. character_base.gd::_physics_process reads WASD
		# in the body's own frame when the unit is mouse-aimed (B-60), and the
		# AI writes world-space directions — leave this on MOUSE and the bot
		# walks in a curve that depends on wherever the camera happens to face.
		var rig := c.get_node_or_null("CameraRig") as CameraRig
		if rig != null:
			rig.set_aim_source(CameraRig.AimSource.MOVEMENT)
		# ⚠️ AND THE KEYBOARD GUARD HAS TO GO WITH IT. `input_parked` is what the
		# debug switcher sets on every unit the human is not holding; a parked
		# unit is deaf to hardware, which is right for a human's abandoned seat
		# and irrelevant to a bot — but leaving it set on a unit this function
		# has just handed to the AI is one more way for a "driven" unit to do
		# nothing.
		c.input_parked = false
		if c.ai_controller != null:
			c.ai_controller.set_enabled(true)
		else:
			var controller := AIController.new()
			c.add_child(controller)
			c.ai_controller = controller
		taken += 1
		print("fairness: took over human slot -> ", c.name)
	# ⚠️ SAID OUT LOUD, EVERY RUN. Single Player seats exactly one human, so this
	# is 1 in the normal case and 0 means the takeover found nothing to take —
	# which is the failure above, and it must never again be silent.
	print("fairness: human slots taken over: ", taken)
	var driven := 0
	for c in _main.find_children("*", "CharacterBase", true, false):
		if c.ai_controller != null and c.ai_controller.is_enabled():
			driven += 1
	print("fairness: units actually DRIVEN by AI: ", driven, " (must be 4)")
	if driven < 4:
		push_error("ai_probe: only %d of 4 units are AI-driven — this run does "
			% driven + "not measure AI fairness and its numbers are void.")

func _wire_fairness_signals() -> void:
	MatchManager.round_started.connect(_on_round_started)
	MatchManager.match_won.connect(_on_match_won)
	RoundManager.round_won.connect(_on_round_won)
	for c in _main.find_children("*", "CharacterBase", true, false):
		c.dents_changed.connect(_on_dents_changed.bind(c))
		var carriable := c.get_node_or_null("Carriable") as Carriable
		if carriable != null:
			carriable.carry_state_changed.connect(_on_carry_state_changed.bind(carriable))
		_watch_hitboxes(c)

## ⚠️ RE-ARMED PER THROW, NOT ONCE AT SETUP — trap 2 in this repo's own method
## note: a probe that never LOOKS at the thing you changed passes anyway.
##
## Connecting only at setup catches the slipper's always-on melee Hitbox but MISSES
## the per-profile pulse Hitbox, which `carriable.gd::_spawn_flight_hitbox()`
## creates INSIDE host_throw's broadcast — a different node on every throw, which
## does not exist yet when this runs. That is the hitbox most throws actually
## resolve on, so `throws_on_can` read 0 for every run ever recorded here while
## `dents` climbed in the same table. Two columns of the same event disagreeing is
## what exposed it: 0.60 dents per round alongside "throws that reached the can: 0"
## is impossible, and the metric was wrong rather than the game.
##
## phys_probe.gd has re-armed for this exact reason since the multi-hit work; this
## brings ai_probe in line. Idempotent, so calling it again is free.
func _watch_hitboxes(c: CharacterBase) -> void:
	if c == null or not is_instance_valid(c):
		return
	for hb in c.find_children("*", "Hitbox", true, false):
		var box := hb as Hitbox
		if not box.landed_on.is_connected(_on_hitbox_landed):
			box.landed_on.connect(_on_hitbox_landed.bind(c))

## ---------------------------------------------------------------------------
## Fairness event handlers.
## ---------------------------------------------------------------------------

func _on_round_started(round_number: int, team_a_is_can: bool) -> void:
	# R-02(c)'s raw material. Recorded from the signal main.gd itself assigns roles
	# from, so this is the side that genuinely attacked, not the side that was
	# supposed to.
	_can_sides_seen[team_a_is_can] = int(_can_sides_seen.get(team_a_is_can, 0)) + 1
	_open_round(round_number, team_a_is_can)

func _open_round(round_number: int, team_a_is_can: bool) -> void:
	_round = {
		"number": round_number,
		"team_a_is_can": team_a_is_can,
		"duration": 0.0,
		"first_throw_at": -1.0,
		"throws_taken": 0,
		"throws_blocked": 0,
		"throws_on_can": 0,
		"dents": 0,
		"defender_won": false,
		"timed_out": false,
		"tagged": false,
		# R-07: throws taken while the taya's committed post was already wrong, and
		# of those, the ones that were NOT blocked — the slide beating the post.
		"throws_off_post": 0,
		"beat_the_post": 0,
		# R-08 / the 1.6-second round. RUN 9's per-round table is sharply bimodal:
		# rounds either run 20-90 s with 10-30 blocked throws, or end in ~1.6 s. A
		# duration column cannot tell those apart from a slow tag, so the tag's own
		# time and the gap between the two Persons at the opening whistle are
		# recorded — a tag at 1.6 s from a 3-unit spawn gap is a spawn-layout
		# finding, and a tag at 1.6 s from a 12-unit gap is impossible and would mean
		# the metric is the bug.
		"tag_at": -1.0,
		"person_gap": -1.0,
	}
	_round_time = 0.0
	_round_open = true
	_flights.clear()

## `winning_team` is RoundManager's own encoding: 0 = the Can side (the
## DEFENCE) won this round, 1 = the Slipper side (the OFFENCE) won.
func _on_round_won(winning_team: int) -> void:
	if not _round_open:
		return
	_round["duration"] = _round_time
	_round["defender_won"] = winning_team == 0
	# The defence also wins on timer expiry (round_manager.gd::_on_time_up), and
	# a round nobody ever resolved is a different failure from a round the
	# defence actually held — §9's own warning that a 50% split where every
	# round times out "is not balanced, it is broken twice".
	_round["timed_out"] = winning_team == 0 and RoundManager.time_left <= 0.05
	_rounds.append(_round.duplicate())
	_round_open = false
	# Progress, not decoration: the full report only prints at the end, and a
	# 20-round run is minutes long — without this a working run and a hung one
	# look identical from outside.
	print("  [%d/%d] round %d -> %s by %s in %.1fs (%d throws, %d dents)" % [
		_rounds.size(), _target_rounds, _round["number"],
		"DEFENCE" if _round["defender_won"] else "OFFENCE", _ended_by(_round),
		_round["duration"], _round["throws_taken"], _round["dents"]])

func _on_match_won(_winning_team: int) -> void:
	# A match is first to 3 (MatchManager.WINS_NEEDED), so 20 rounds means
	# several matches. Reset and keep going rather than stopping at the first
	# one — the sample we want is rounds, not matches.
	if _finishing or _rounds.size() >= _target_rounds:
		# Still un-pause, or the final report never prints: the tree is paused
		# and _physics_process (which does the reporting) never runs again.
		_dismiss_result_screen()
		return
	await get_tree().create_timer(1.0).timeout
	if _finishing:
		return
	_dismiss_result_screen()
	MatchManager.reset()
	RoundManager.reset()
	MatchManager.begin_next_round()

## The headless-driven equivalent of clicking Rematch. Deliberately does the
## three steps itself rather than calling match_result.gd's own button handler:
## that one also plays a UI click and re-captures the mouse, neither of which
## belongs in a measurement run.
func _dismiss_result_screen() -> void:
	var result := _main.get_node_or_null("HUDLayer/MatchResult") as Control
	if result != null:
		result.visible = false
	get_tree().paused = false

func _on_dents_changed(new_dents: int, who: CharacterBase) -> void:
	var previous: int = _dents_seen.get(who, 0)
	_dents_seen[who] = new_dents
	if not _round_open or new_dents <= previous:
		return # a reset back to 0, or a repair — neither is a new dent
	_round["dents"] += new_dents - previous

## A throw begins on CARRIED -> FLYING and ends on FLYING -> anything else.
## Resolving on the END is what makes "blocked" honest: a slipper that clips the
## Taya on the way past and still dents the can was NOT blocked, and only the
## completed flight knows that.
func _on_carry_state_changed(new_state: int, carriable: Carriable) -> void:
	if not _round_open:
		return
	if new_state == Carriable.CarryState.FLYING:
		_round["throws_taken"] += 1
		if _round["first_throw_at"] < 0.0:
			_round["first_throw_at"] = _round_time
		# R-07. Ask the DEFENDING taya's own controller how wrong its post is right
		# now, and carry that with the flight so the answer can be paired with
		# whether the throw was blocked.
		var post_error := _taya_post_error()
		_flights[carriable] = {"hit_taya": false, "hit_can": false, "post_error": post_error,
			"closest": 1e9, "aim_error": _aim_error(carriable), "range": _throw_range(carriable)}
		if post_error > AIController.taya_repost_angle:
			_round["throws_off_post"] += 1
		if _trace and _traces_printed < MAX_TRACES:
			# Raw geometry of the throw, because two aggregate columns disagreeing is
			# where this pass keeps ending up and an aggregate cannot be inspected.
			var thrower := _thrower_of(carriable)
			var cans := RoundManager.get_tracked_cans()
			print("      geom: cans tracked %d | thrower %s at %.2f,%.2f | aim %s | can %s"
				% [cans.size(),
					thrower.name if thrower != null else "?",
					thrower.global_position.x if thrower != null else 0.0,
					thrower.global_position.z if thrower != null else 0.0,
					str(thrower.ai_aim_point) if thrower != null else "?",
					str(cans[0].global_position) if not cans.is_empty() else "none"])
		if _trace and _traces_printed < MAX_TRACES:
			_traces_printed += 1
			print("    trace @ throw %d of round %d (taya post error %.2f rad):"
				% [_round["throws_taken"], _round["number"], post_error])
			for c in _main.find_children("*", "CharacterBase", true, false):
				if not c.is_person or c.ai_controller == null:
					continue
				print("      %-12s %s %s" % [c.name,
					"TAYA    " if c.team_is_can_side else "ATTACKER",
					c.ai_controller.bt_trace()])
		# The pulse hitbox for THIS throw was spawned during the broadcast that
		# got us here, so it is only connectable now. See _watch_hitboxes.
		_watch_hitboxes(carriable.get_parent() as CharacterBase)
		return
	if not _flights.has(carriable):
		return
	var flight: Dictionary = _flights[carriable]
	if flight["hit_can"]:
		_round["throws_on_can"] += 1
	elif flight["hit_taya"]:
		_round["throws_blocked"] += 1
	# R-07's acceptance number: released while the post was already wrong AND not
	# blocked. That is the slide beating the post, resolved on the COMPLETED flight
	# for the same reason `blocked` is — only the finished flight knows.
	if not flight["hit_taya"] and float(flight.get("post_error", -1.0)) > AIController.taya_repost_angle:
		_round["beat_the_post"] += 1
	var closest: float = float(flight.get("closest", 1e9))
	if closest < 1e8:
		_closest_approaches.append(closest)
		if not flight["hit_taya"]:
			_closest_unblocked.append(closest)
			_aim_errors.append(float(flight.get("aim_error", -1.0)))
			_throw_ranges.append(float(flight.get("range", -1.0)))
	_flights.erase(carriable)

## `who` is the character owning the hitbox that landed — for a throw in flight
## that is the slipper itself.
func _on_hitbox_landed(target: CharacterBase, who: CharacterBase) -> void:
	if not _round_open or target == null:
		return
	# ⚠️ THE TAG IS A ROUND-WIN CONDITION, not flavour — hitbox.gd ends the
	# round outright when a defending Person's hitbox lands on the attacking
	# Person. It turned out to be the dominant way rounds end in an all-AI
	# match, which a bare win-rate number would have hidden completely.
	if who.is_person and who.team_is_can_side and target.is_person and not target.team_is_can_side:
		_round["tagged"] = true
		if _round["tag_at"] < 0.0:
			_round["tag_at"] = _round_time
			# ⚠️ MEASURE THE TAG, DO NOT REASON ABOUT IT. 100% of rounds end this way,
			# so which branch each Person was in at the moment of contact is the single
			# most informative line this probe can print — and it is the question that
			# was being answered by inspection of the geometry instead.
			if _trace:
				print("    TAG at %.1fs, %.2f units apart: " % [_round_time,
					who.global_position.distance_to(target.global_position)])
				for c in [who, target]:
					if c.ai_controller != null:
						print("      %-12s %s %s" % [c.name,
							"TAYA    " if c.team_is_can_side else "ATTACKER",
							c.ai_controller.bt_trace()])
		_apply_tag_variant(target)
	var carriable := who.get_node_or_null("Carriable") as Carriable
	if carriable == null or not _flights.has(carriable):
		return # a melee bump, not a throw — not this measurement's business
	var flight: Dictionary = _flights[carriable]
	if target.is_can:
		flight["hit_can"] = true
	elif target.is_person and target.team_is_can_side:
		flight["hit_taya"] = true # body-blocked by the defending Person

## ---------------------------------------------------------------------------
## R-08 · THE ROUND-WIN CONDITION AS A MEASURABLE VARIANT.
##
## A tag by the defending Person ends the round OUTRIGHT (hitbox.gd's own rule at
## the bottom of _on_area_entered) and RUN 8 measured 10/10 rounds ending that way.
## So the defence has a ONE-SHOT instant win and the offence has a REPEATED-SUCCESS
## win, and those are not symmetric objectives. R-08 asks whether that asymmetry —
## not any knob — is the imbalance.
##
## ⚠️ IMPOSED FROM THE PROBE, NOT FROM hitbox.gd, AND THAT IS DELIBERATE.
## `scripts/characters/hitbox.gd` belongs to another lane, R-08's deliverable is a
## table a human picks a rule FROM, and shipping a rule change to measure it would
## be deciding the thing this item explicitly does not decide. The interception is
## honest because of the ORDER inside hitbox.gd::_on_area_entered: `landed_on.emit()`
## (which lands us here) runs BEFORE the `RoundManager.report_round_win(true)` at the
## end of that function, and report_round_win() no-ops on `not round_active`. So
## clearing round_active for the remainder of this frame is exactly "this tag does
## not end the round", with no gameplay file touched.
##
## ⚠️ THE COST OF THAT MECHANISM, STATED RATHER THAN DISCOVERED LATER: the round
## clock does not advance for the fraction of a frame between the suppression and
## the deferred restore, and any OTHER round-win check that fires in that same
## window is also suppressed. Over 20 rounds that is far below the noise on every
## column in the table; if a variant is ever picked, it belongs in hitbox.gd as a
## real rule and not as this.
##
##   control  the shipping rule, unchanged.
##   slipper  a tag costs the attacker its slipper and a respawn, not the round.
##   inside   a tag ends the round ONLY while the attacker is inside the
##            confinement box — i.e. only during retrieval, which RUN 6 already
##            established is where the real exposure is.
## ---------------------------------------------------------------------------

func _apply_tag_variant(attacker: CharacterBase) -> void:
	if _tag_variant == "control":
		return
	if _tag_variant == "inside" and _inside_confinement(attacker):
		return # this tag is one the variant KEEPS — let hitbox.gd have it
	# Suppress the win this tag is about to report.
	if RoundManager.round_active:
		RoundManager.round_active = false
		call_deferred("_restore_round_active")
	if _tag_variant != "slipper":
		return
	# ⚠️ AND IT HAS TO COST SOMETHING, or "a tag no longer ends the round" is just
	# "the taya cannot win", which is not one of the three variants. The tsinelas
	# becomes the currency: the attacker drops what it is holding and goes back to
	# its spawn, so the retrieval scramble is the price of being caught.
	var carrier := attacker.get_node_or_null("Carrier") as Carrier
	if carrier != null and carrier.held() != null:
		carrier.held().host_drop()
	attacker.respawn()
	_respawns += 1

## ⚠️ SQUARE, NOT A CIRCLE. `character_base.gd::_move_and_confine()` clamps X and Z
## INDEPENDENTLY to +/-CONFINEMENT_RADIUS and both map builders draw the chalk as a
## square to match. A `.length()` test here would call the corners "outside" a box
## the physics lets a unit stand in, and the shape was a deliberate correctness fix
## (RUN 3) — do not answer this question with a radius.
func _inside_confinement(who: CharacterBase) -> bool:
	if who == null or not is_instance_valid(who):
		return false
	var p := who.global_position
	return maxf(absf(p.x), absf(p.z)) <= CharacterBase.CONFINEMENT_RADIUS

func _restore_round_active() -> void:
	if not _finishing and _round_open:
		RoundManager.round_active = true

## ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _bots.is_empty():
		return
	_t += delta
	_frames += 1
	_reassert_scale()
	if _break == "swap":
		_pin_the_role_swap()
	if _round_open and RoundManager.round_active:
		_round_time += delta
		# Measured on the first frame AFTER round_started rather than inside the
		# handler: main.gd listens to the same signal to teleport everybody to their
		# role spawns, and listener order is connection order, so reading positions
		# inside the handler could read the PREVIOUS round's geometry.
		if _round["person_gap"] < 0.0:
			_round["person_gap"] = _person_gap()
	if _heatmap:
		_sample_heatmap(delta)
	_track_flight_geometry()
	var changed := 0
	for c in _bots:
		# ⚠️ TWO STILLNESS METRICS, AND THE DISPLACEMENT ONE IS THE HONEST ONE.
		# `STILL_SPEED` (0.35 m/s) was written against Persons walking at SPEED 6.0,
		# and every OTHER unit in this game moves through a speed scale: a crawling
		# tsinelas is at CRAWL_SPEED_SCALE 0.45, a stood-on one at another 0.35 of
		# that, a settling unit at IDLE_GAIT. A slipper crawling home at 0.33 m/s is
		# doing exactly its job and scores as "frozen" on a velocity test — which is
		# how "the longest still run has moved independently of everything else for
		# three runs" happened. What nobody wants is a unit that does not GO anywhere,
		# so that is what is measured: displacement over a real window.
		var here := Vector2(c.global_position.x, c.global_position.z)
		if not _last_pos.has(c):
			_last_pos[c] = here
			_frozen_run[c] = 0
			_frozen_max[c] = 0
		if here.distance_to(_last_pos[c]) >= STILL_DISPLACEMENT:
			_last_pos[c] = here
			_frozen_run[c] = 0
		else:
			_frozen_run[c] += 1
			_frozen_max[c] = maxi(_frozen_max[c], _frozen_run[c])
		var v: float = Vector2(c.velocity.x, c.velocity.z).length()
		var now_moving: bool = v > STILL_SPEED
		if now_moving != _moving[c]:
			changed += 1
			_transitions[c] += 1
			_moving[c] = now_moving
		if now_moving:
			_still_run[c] = 0
		else:
			_still_run[c] += 1
			_still_max[c] = maxi(_still_max[c], _still_run[c])
			# ⚠️ WHICH BRANCH IS IT STANDING IN? The still-run figure "has moved
			# independently of everything else for three consecutive runs" and every
			# previous attempt to explain it reasoned about the code. A unit that has
			# been motionless for STILL_REPORT_FRAMES says what it is doing, once per
			# episode, and the answer is either "a leaf that deliberately stands still"
			# (fine, and now nameable) or a freeze (a bug, and now locatable).
			if _trace and _still_run[c] == STILL_REPORT_FRAMES and c.ai_controller != null:
				print("    STILL %.1fs: %-12s %s" % [STILL_REPORT_FRAMES / 60.0, c.name,
					c.ai_controller.bt_trace()])
	if changed >= 2:
		_same_frame += 1

	if _mode == "fairness":
		if _rounds.size() >= _target_rounds and not _finishing:
			_finishing = true
			set_physics_process(false)
			_report_fairness()
			get_tree().quit(0)
		return

	if _t < SECONDS:
		return
	set_physics_process(false)
	_report_independence()
	get_tree().quit(0)

## Unchanged from the original probe — this is the output every existing
## Checklist/Handoff AI number was read off, so its shape stays put.
func _report_independence() -> void:
	print("\n=== AI INDEPENDENCE / FREEZE AUDIT (", _frames, " physics frames) ===")
	var total_tr := 0
	for c in _bots:
		total_tr += _transitions[c]
		print("  %-14s start/stop transitions %3d   longest still run %4d frames (%.2fs)"
			% [c.name, _transitions[c], _still_max[c], _still_max[c] / 60.0])
	print("  frames where 2+ bots changed state together: %d / %d  (%.1f%%)"
		% [_same_frame, _frames, 100.0 * _same_frame / maxi(_frames, 1)])
	print("  total transitions across all bots: ", total_tr,
		"  -> ", "FROZEN" if total_tr < 4 else "active")
	if _heatmap:
		_report_heatmap()

## The four numbers Checklist §9's fairness table asks for, each printed next to
## that table's own fair range so a run is self-scoring and nobody has to go
## look up what "good" was. ⚠️ It prints the PER-ROUND table as well as the
## aggregate on purpose: an aggregate hides the bimodal case (half the rounds
## resolved in 10s, half timed out) that §9 explicitly warns about.
func _report_fairness() -> void:
	print("\n=== AI FAIRNESS RUN (%d rounds, %s, time_scale %.1f) ==="
		% [_rounds.size(), _mode_name(), _scale])
	print("    map %s | taya_pursue_radius %.2f | taya_block_standoff %.2f | tier %s"
		% [GameLaunch.selected_map, AIController.taya_pursue_radius,
			AIController.taya_block_standoff, _tier_name()])
	print("    round-win rule: %s" % _tag_variant_name())
	print("  round  winner    dur(s)  1st-throw  throws  blocked  on-can  dents  ended-by  tag@  gap  off-post/beat")
	var defender_wins := 0
	var throws := 0
	var blocked := 0
	var on_can := 0
	var dents := 0
	var timeouts := 0
	var rounds_with_dent := 0
	var first_throw_total := 0.0
	var first_throw_count := 0
	var no_throw_rounds := 0
	var tag_rounds := 0
	for r in _rounds:
		if r["tagged"] and r["defender_won"]:
			tag_rounds += 1
		if r["defender_won"]:
			defender_wins += 1
		throws += r["throws_taken"]
		blocked += r["throws_blocked"]
		on_can += r["throws_on_can"]
		dents += r["dents"]
		if r["dents"] > 0:
			rounds_with_dent += 1
		if r["timed_out"]:
			timeouts += 1
		if r["first_throw_at"] >= 0.0:
			first_throw_total += r["first_throw_at"]
			first_throw_count += 1
		else:
			no_throw_rounds += 1
		print("  %5d  %-8s  %6.1f  %9s  %6d  %7d  %6d  %5d  %-8s  %4s %4s  %d/%d" % [
			r["number"],
			"DEFENCE" if r["defender_won"] else "OFFENCE",
			r["duration"],
			("%.1f" % r["first_throw_at"]) if r["first_throw_at"] >= 0.0 else "none",
			r["throws_taken"], r["throws_blocked"], r["throws_on_can"], r["dents"],
			_ended_by(r),
			("%.1f" % r["tag_at"]) if r["tag_at"] >= 0.0 else "-",
			("%.1f" % r["person_gap"]) if r["person_gap"] >= 0.0 else "-",
			r["throws_off_post"], r["beat_the_post"],
		])

	var n: int = maxi(_rounds.size(), 1)
	var defender_rate := 100.0 * defender_wins / n
	var mean_first_throw := first_throw_total / maxi(first_throw_count, 1)
	var block_rate := 100.0 * blocked / maxi(throws, 1)
	var dents_per_round := float(dents) / n
	# R-08's new column. A variant that fixes the win rate by making every round run
	# to the 90 s clock has not balanced anything — it has removed the game.
	var duration_total := 0.0
	for r in _rounds:
		duration_total += r["duration"]
	var mean_duration := duration_total / n
	var still_max := 0
	for c in _bots:
		still_max = maxi(still_max, _still_max[c])

	print("\n  --- Checklist Phase 9 fairness table ---")
	print("  round win rate       DEFENCE %.1f%% / OFFENCE %.1f%%   (fair: 40-60%%)  %s"
		% [defender_rate, 100.0 - defender_rate, _verdict(defender_rate >= 40.0 and defender_rate <= 60.0)])
	print("  time-to-first-throw  %.1fs mean over %d rounds       (fair: < 8s)     %s"
		% [mean_first_throw, first_throw_count, _verdict(first_throw_count > 0 and mean_first_throw < 8.0)])
	print("  throws blocked       %d / %d taken = %.1f%%             (fair: 25-50%%)  %s"
		% [blocked, throws, block_rate, _verdict(throws > 0 and block_rate >= 25.0 and block_rate <= 50.0)])
	print("  can dents per round  %.2f  (%d/%d rounds dented)      (fair: >= 1)     %s   [%s]"
		% [dents_per_round, rounds_with_dent, _rounds.size(),
			_verdict(rounds_with_dent * 2 >= _rounds.size()), _mode_name()])
	print("  longest still run    %.2fs                             (fair: < 2s)     %s"
		% [still_max / 60.0, _verdict(still_max < 120)])
	# ⚠️ NO FAIR RANGE ON THIS ONE ON PURPOSE — R-08 introduces it and nobody has
	# played a round, so "the right length" is not a number this project owns yet.
	# What it is for is catching a variant that buys its win rate with dead time.
	print("  avg round duration   %.1fs over %d rounds              (no range yet — R-08)"
		% [mean_duration, _rounds.size()])
	print("\n  throws that reached the can: %d   rounds with no throw at all: %d   rounds timed out: %d"
		% [on_can, no_throw_rounds, timeouts])
	print("  rounds the DEFENCE won by TAGGING the attacker: %d / %d  (%.0f%% of all rounds)"
		% [tag_rounds, _rounds.size(), 100.0 * tag_rounds / n])
	if _tag_variant != "control":
		print("  tags SUPPRESSED by the round-win variant (attacker respawns): %d" % _respawns)

	# R-07's own two numbers, and the reason the still-run column gets a per-unit
	# breakdown: that figure "has moved independently of everything else for three
	# consecutive runs" (Roadmap R-07), and an aggregate max cannot say which unit
	# it belongs to. A Can standing on its mark is intended behaviour
	# (CAN_HOLD_RADIUS 0.45 is inside ARRIVE_DISTANCE 0.6, so it genuinely never
	# moves unless it is evading) and a frozen Person is a bug; one number for both
	# is a number nobody can act on.
	var off_post := 0
	var beat := 0
	var tag_times := 0.0
	var tag_count := 0
	var gap_total := 0.0
	var gap_count := 0
	var quick_tags := 0
	for r in _rounds:
		off_post += r["throws_off_post"]
		beat += r["beat_the_post"]
		if r["tag_at"] >= 0.0:
			tag_times += r["tag_at"]
			tag_count += 1
			if r["tag_at"] <= 3.0:
				quick_tags += 1
		if r["person_gap"] >= 0.0:
			gap_total += r["person_gap"]
			gap_count += 1
	# ⚠️ THE INDEPENDENT CHECK ON THE TWO COLUMNS ABOVE. If `throws that reached the
	# can` is 0 while these distances cluster under half a unit, the HITBOX metric is
	# lying; if they cluster at 2+ units the AIM is wrong; if they cluster above the
	# throwing distance the throws are falling short. Three different bugs that the
	# hitbox column alone reports identically.
	if not _closest_approaches.is_empty():
		var sorted := _closest_approaches.duplicate()
		sorted.sort()
		var sum := 0.0
		for d in sorted:
			sum += d
		var within := 0
		for d in _closest_unblocked:
			if d <= 0.5:
				within += 1
		print("\n  --- every throw's CLOSEST APPROACH to the can (geometry, not the hitbox) ---")
		print("  %d flights: min %.2f, median %.2f, mean %.2f, max %.2f units"
			% [sorted.size(), sorted[0], sorted[sorted.size() / 2], sum / sorted.size(),
				sorted[sorted.size() - 1]])
		print("  unblocked flights that came within 0.50 (the overlap band): %d / %d"
			% [within, _closest_unblocked.size()])
		# Which half of the throw is at fault — see _aim_error().
		var aim_sum := 0.0
		var aim_n := 0
		var aim_worst := 0.0
		for e in _aim_errors:
			if e >= 0.0:
				aim_sum += e
				aim_n += 1
				aim_worst = maxf(aim_worst, e)
		var range_sum := 0.0
		var range_n := 0
		for r in _throw_ranges:
			if r >= 0.0:
				range_sum += r
				range_n += 1
		if aim_n > 0:
			print("  where the AI ASKED for the slipper to go, vs where the can was: "
				+ "%.2f mean, %.2f worst (over %d unblocked throws)"
				% [aim_sum / aim_n, aim_worst, aim_n])
			print("  release range: %.2f mean" % (range_sum / maxi(range_n, 1)))
			print("  -> aim error small + closest approach large = the BALLISTICS are not "
				+ "delivering; both large = the AI is aiming at the wrong place.")

	print("\n  --- R-07: the taya's post ---")
	print("  throws released while the post was already wrong (> %.2f rad): %d / %d"
		% [AIController.taya_repost_angle, off_post, throws])
	print("  of those, throws the slide actually BEAT (not blocked): %d" % beat)
	print("  --- the tag ---")
	print("  mean time of the round-ending tag: %.1fs over %d tagged rounds; "
		% [tag_times / maxi(tag_count, 1), tag_count]
		+ "%d of them landed within 3s of the whistle" % quick_tags)
	print("  mean distance between the two Persons at the opening whistle: %.2f units"
		% [gap_total / maxf(float(gap_count), 1.0)])
	print("  per-unit longest still run (a Prop holding its mark is INTENDED — see")
	print("  CAN_HOLD_RADIUS; a Person standing still is not):")
	for c in _bots:
		print("    %-16s velocity-still %5.2fs | WENT NOWHERE %5.2fs   (%d transitions)"
			% [c.name, _still_max[c] / 60.0, float(_frozen_max.get(c, 0)) / 60.0,
				_transitions[c]])
	var frozen_worst := 0
	for c in _bots:
		frozen_worst = maxi(frozen_worst, int(_frozen_max.get(c, 0)))
	print("  worst WENT-NOWHERE run across all units: %.2fs   (fair: < 2s)   %s"
		% [frozen_worst / 60.0, _verdict(frozen_worst < 120)])
	# ⚠️ §9's own warning, printed rather than left to be remembered: a win rate
	# on its own is not a fairness result.
	if timeouts * 2 >= _rounds.size():
		print("  ⚠️ HALF OR MORE OF THESE ROUNDS TIMED OUT — the win rate above is NOT a")
		print("     balance result. Rounds that never resolve are the failure to fix first.")

	# R-02(c) · DID THE ATTACKING SIDE CHANGE HANDS? A run in which one team was
	# always the attacker is not a fairness measurement — it is one team's numbers
	# reported as both teams'. Asserted here because it is the one part of the
	# contract that cannot be known until the run is over.
	print("\n  --- probe honesty contract, part (c) ---")
	var a_can: int = int(_can_sides_seen.get(true, 0))
	var b_can: int = int(_can_sides_seen.get(false, 0))
	print("  rounds with Team A on the CAN side: %d   Team B on the CAN side: %d" % [a_can, b_can])
	if a_can == 0 or b_can == 0:
		_honesty_ok = false
		push_error("ai_probe: the attacking side NEVER changed hands (%d/%d) — this " % [a_can, b_can]
			+ "run measures one team, not fairness, and its numbers are VOID.")
	else:
		print("  the attacking side changed hands — this run is a fairness measurement.")
	print("  honesty contract: %s" % ("PASSED — every number above is admissible"
		if _honesty_ok else "⚠️⚠️ FAILED — DO NOT LOG THESE NUMBERS"))
	if _heatmap:
		_report_heatmap()

## ---------------------------------------------------------------------------
## R-21 · THE HEATMAP. Where the units actually are, as a picture.
##
## The half of R-21 that does not need `CharacterBase.CONFINEMENT_RADIUS` promoted
## to a `static var` — see the fairness log's R-21 note for why the size sweep is
## filed rather than run. Dead space and the retrieval route are questions about a
## DISTRIBUTION, and every previous answer to them in this repo has been somebody
## reasoning about the geometry.
##
## ⚠️ IT PRINTS AN ASCII GRID AS WELL AS WRITING A PNG, and the ASCII one is the
## deliverable. `docs/` is another lane's directory and a binary asset there is a
## merge conflict waiting to happen, so the artefact that goes INTO the fairness log
## is text that survives a diff. The PNG is for looking at.
## ---------------------------------------------------------------------------

## Half-width of the sampled square, in world units. Fixed rather than derived from
## the data so two maps' heatmaps are directly comparable — a grid that rescales to
## its own extent makes a tight map and a loose one look identical.
const HEATMAP_EXTENT: float = 14.0
const HEATMAP_CELLS: int = 29
const HEATMAP_PNG_PIXELS: int = 464

## Once a second of GAME time (accumulated scaled delta), matching every other
## number this probe reports — see DEFAULT_SCALE's own note.
func _sample_heatmap(delta: float) -> void:
	_heat_accum += delta
	if _heat_accum < 1.0:
		return
	_heat_accum = 0.0
	for c in _main.find_children("*", "CharacterBase", true, false):
		var key := String(c.name)
		if not _heat_samples.has(key):
			_heat_samples[key] = PackedVector2Array()
		var p: Vector3 = c.global_position
		_heat_samples[key].append(Vector2(p.x, p.z))

## Grid index for a world XZ point, or -1 when it is off the sampled square. +Z is
## DOWN the printed grid, so the picture reads the way the game's own top-down
## +X-right/+Z-toward-camera axes do.
func _heat_cell(p: Vector2) -> Vector2i:
	var u := (p.x + HEATMAP_EXTENT) / (2.0 * HEATMAP_EXTENT)
	var v := (p.y + HEATMAP_EXTENT) / (2.0 * HEATMAP_EXTENT)
	if u < 0.0 or u >= 1.0 or v < 0.0 or v >= 1.0:
		return Vector2i(-1, -1)
	return Vector2i(int(u * HEATMAP_CELLS), int(v * HEATMAP_CELLS))

func _report_heatmap() -> void:
	var total := 0
	var off_grid := 0
	var grid: Array = []
	for _row in range(HEATMAP_CELLS):
		var row: Array[int] = []
		row.resize(HEATMAP_CELLS)
		row.fill(0)
		grid.append(row)
	var peak := 0
	for key in _heat_samples.keys():
		for p in _heat_samples[key]:
			total += 1
			var cell := _heat_cell(p)
			if cell.x < 0:
				off_grid += 1
				continue
			grid[cell.y][cell.x] += 1
			peak = maxi(peak, grid[cell.y][cell.x])
	print("\n=== R-21 POSITION HEATMAP — map: %s, %d samples (1/s of game time), peak cell %d ==="
		% [GameLaunch.selected_map, total, peak])
	if total == 0:
		print("  no samples — nothing to report")
		return
	print("  extent +/-%.0f units, %dx%d cells (%.2f units per cell); %d samples off the grid"
		% [HEATMAP_EXTENT, HEATMAP_CELLS, HEATMAP_CELLS,
			2.0 * HEATMAP_EXTENT / HEATMAP_CELLS, off_grid])
	print("  '#' >= 50%% of peak, '+' >= 20%%, ':' >= 5%%, '.' > 0, ' ' never visited.")
	print("  [] marks the CONFINEMENT SQUARE (+/-%.1f, and it IS a square — see" % CharacterBase.CONFINEMENT_RADIUS)
	print("     character_base.gd::_move_and_confine); 'o' marks the world origin, i.e. the can's mark.")
	# The confinement square in cell coordinates, so the picture carries its own
	# reference frame instead of needing one described in prose.
	var edge_lo := _heat_cell(Vector2(-CharacterBase.CONFINEMENT_RADIUS, -CharacterBase.CONFINEMENT_RADIUS))
	var edge_hi := _heat_cell(Vector2(CharacterBase.CONFINEMENT_RADIUS, CharacterBase.CONFINEMENT_RADIUS))
	var origin := _heat_cell(Vector2.ZERO)
	for y in range(HEATMAP_CELLS):
		var line := ""
		for x in range(HEATMAP_CELLS):
			var n: int = grid[y][x]
			var ch := " "
			if n > 0:
				var frac := float(n) / maxf(float(peak), 1.0)
				if frac >= 0.5:
					ch = "#"
				elif frac >= 0.2:
					ch = "+"
				elif frac >= 0.05:
					ch = ":"
				else:
					ch = "."
			if n == 0 and x == origin.x and y == origin.y:
				ch = "o"
			if n == 0 and (x == edge_lo.x or x == edge_hi.x) \
					and y >= edge_lo.y and y <= edge_hi.y:
				ch = "["
			if n == 0 and (y == edge_lo.y or y == edge_hi.y) \
					and x >= edge_lo.x and x <= edge_hi.x:
				ch = "-"
			line += ch
		print("  |" + line + "|")
	print("  per-unit sample counts (a unit with far fewer samples than the others "
		+ "was not in the tree the whole run):")
	for key in _heat_samples.keys():
		var pts: PackedVector2Array = _heat_samples[key]
		var mean := 0.0
		for p in pts:
			mean += p.length()
		print("    %-16s %4d samples, mean distance from the mark %.2f"
			% [key, pts.size(), mean / maxf(float(pts.size()), 1.0)])
	_write_heatmap_png()

## The looking-at-it version. Written to `user://`, which on this machine resolves
## under the Godot app-data directory — the path is printed rather than assumed.
func _write_heatmap_png() -> void:
	var img := Image.create(HEATMAP_PNG_PIXELS, HEATMAP_PNG_PIXELS, false, Image.FORMAT_RGB8)
	img.fill(Color(0.04, 0.04, 0.06))
	# Splat each sample with a small radius so a 1-pixel dot does not disappear;
	# accumulate into a float buffer first, then colour-map, so the ramp is applied
	# to a density rather than to overdraw order.
	var density := PackedFloat32Array()
	density.resize(HEATMAP_PNG_PIXELS * HEATMAP_PNG_PIXELS)
	var scale := float(HEATMAP_PNG_PIXELS) / (2.0 * HEATMAP_EXTENT)
	const SPLAT := 5
	var peak := 0.0
	for key in _heat_samples.keys():
		for p in _heat_samples[key]:
			var px := int((p.x + HEATMAP_EXTENT) * scale)
			var py := int((p.y + HEATMAP_EXTENT) * scale)
			for dy in range(-SPLAT, SPLAT + 1):
				for dx in range(-SPLAT, SPLAT + 1):
					var x := px + dx
					var y := py + dy
					if x < 0 or y < 0 or x >= HEATMAP_PNG_PIXELS or y >= HEATMAP_PNG_PIXELS:
						continue
					var r := sqrt(float(dx * dx + dy * dy))
					if r > float(SPLAT):
						continue
					var i := y * HEATMAP_PNG_PIXELS + x
					density[i] += 1.0 - r / float(SPLAT)
					peak = maxf(peak, density[i])
	if peak <= 0.0:
		return
	for y in range(HEATMAP_PNG_PIXELS):
		for x in range(HEATMAP_PNG_PIXELS):
			var d: float = density[y * HEATMAP_PNG_PIXELS + x] / peak
			if d <= 0.0:
				continue
			# log-ish ramp: the interesting structure is in the low end, and a linear
			# ramp buries the retrieval route under the two standing posts.
			var t := pow(d, 0.45)
			img.set_pixel(x, y, Color(0.05, 0.05, 0.08).lerp(Color(1.0, 0.95, 0.6), t)
				.lerp(Color(1.0, 0.35, 0.15), clampf(t * t, 0.0, 1.0) * 0.6))
	# The confinement square, drawn on top in a dim line so the picture carries its
	# own scale. Same square metric as _inside_confinement().
	var r_px := int(CharacterBase.CONFINEMENT_RADIUS * scale)
	var mid := HEATMAP_PNG_PIXELS / 2
	for i in range(mid - r_px, mid + r_px + 1):
		if i < 0 or i >= HEATMAP_PNG_PIXELS:
			continue
		for edge in [mid - r_px, mid + r_px]:
			if edge >= 0 and edge < HEATMAP_PNG_PIXELS:
				img.set_pixel(i, edge, Color(0.35, 0.9, 1.0))
				img.set_pixel(edge, i, Color(0.35, 0.9, 1.0))
	var out := "user://heatmap_%s_%s.png" % [GameLaunch.selected_map, _tag_variant]
	var err := img.save_png(out)
	if err != OK:
		push_error("ai_probe: could not write %s (error %d)" % [out, err])
		return
	print("  heatmap PNG: %s   -> %s" % [out, ProjectSettings.globalize_path(out)])

func _verdict(ok: bool) -> String:
	return "OK" if ok else "OUT OF RANGE"

## Which tier this run is measuring. R-09: nothing outside AIController called
## apply_difficulty() before this probe did, so this label is the only place a run
## can say which tier its numbers describe.
func _tier_name() -> String:
	match AIController.difficulty:
		AIController.Difficulty.BATA:
			return "BATA"
		AIController.Difficulty.ASTIG:
			return "ASTIG"
		_:
			return "NORMAL"

func _tag_variant_name() -> String:
	match _tag_variant:
		"slipper":
			return "VARIANT 1 — a tag costs the attacker its slipper and a respawn, NOT the round"
		"inside":
			return "VARIANT 2 — a tag ends the round ONLY inside the confinement square"
		_:
			return "CONTROL — the shipping rule: any tag ends the round outright (hitbox.gd)"

## Printed in the header AND next to the dents row, because "0.00 dents" means
## two completely different things in the two modes and a run whose mode is not
## on the same page as its numbers is a run somebody will misread later.
func _mode_name() -> String:
	return "OPTION_A (dents)" if GameLaunch.game_mode == GameLaunch.GameMode.OPTION_A \
		else "OPTION_B (downed/seal — dents are ALWAYS 0)"

## How a round actually ended, which is the thing a bare win rate cannot tell
## you. "dented" is the offence's only win path under Option A; the defence has
## three, and knowing which one it used is what turns a number into a decision.
func _ended_by(r: Dictionary) -> String:
	if not r["defender_won"]:
		return "dented"
	if r["timed_out"]:
		return "timeout"
	if r["tagged"]:
		return "tag"
	return "ring-out?"
