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
	for c in _main.find_children("*", "CharacterBase", true, false):
		if c.ai_controller != null:
			_bots.append(c)
			_moving[c] = false
			_still_run[c] = 0
			_still_max[c] = 0
			_transitions[c] = 0
	print("AI units found: ", _bots.size())
	if _mode == "fairness":
		print("FAIRNESS RUN — target rounds: %d, %s, time_scale: %.1f"
			% [_target_rounds, _mode_name(), _scale])
	set_physics_process(true)

## `-- fairness rounds=20 scale=4`. Everything is optional and order does not
## matter; an unrecognised token is reported rather than silently ignored,
## because a typo'd `round=20` that quietly runs the default would be a
## measurement reported under the wrong label.
func _parse_args() -> void:
	var scale := -1.0
	for arg in OS.get_cmdline_user_args():
		var token := String(arg)
		if token == "fairness" or token == "independence":
			_mode = token
		elif token.begins_with("rounds="):
			_target_rounds = maxi(1, int(token.substr(7)))
		elif token.begins_with("scale="):
			scale = clampf(float(token.substr(6)), 0.25, 8.0)
		elif token == "mode=b":
			GameLaunch.game_mode = GameLaunch.GameMode.OPTION_B
		elif token == "mode=a":
			GameLaunch.game_mode = GameLaunch.GameMode.OPTION_A
		elif token.begins_with("pursue="):
			# Sweeps AIController.taya_pursue_radius without editing the
			# controller — see that field's own doc for why it is the lever.
			AIController.taya_pursue_radius = maxf(0.0, float(token.substr(7)))
		else:
			push_warning("ai_probe: ignoring unrecognised argument '%s'" % token)
	if scale > 0.0:
		_scale = scale
	elif _mode == "fairness":
		_scale = DEFAULT_SCALE
	Engine.time_scale = _scale
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
func _take_over_human_slot() -> void:
	for c in _main.find_children("*", "CharacterBase", true, false):
		if c.ai_controller != null or not c.is_person:
			continue
		# ⚠️ MOVEMENT, NOT MOUSE. character_base.gd::_physics_process reads WASD
		# in the body's own frame when the unit is mouse-aimed (B-60), and the
		# AI writes world-space directions — leave this on MOUSE and the bot
		# walks in a curve that depends on wherever the camera happens to face.
		var rig := c.get_node_or_null("CameraRig") as CameraRig
		if rig != null:
			rig.set_aim_source(CameraRig.AimSource.MOVEMENT)
		var controller := AIController.new()
		c.add_child(controller)
		c.ai_controller = controller
		print("fairness: took over human slot -> ", c.name)

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
		_flights[carriable] = {"hit_taya": false, "hit_can": false}
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
	var carriable := who.get_node_or_null("Carriable") as Carriable
	if carriable == null or not _flights.has(carriable):
		return # a melee bump, not a throw — not this measurement's business
	var flight: Dictionary = _flights[carriable]
	if target.is_can:
		flight["hit_can"] = true
	elif target.is_person and target.team_is_can_side:
		flight["hit_taya"] = true # body-blocked by the defending Person

## ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _bots.is_empty():
		return
	_t += delta
	_frames += 1
	_reassert_scale()
	if _round_open and RoundManager.round_active:
		_round_time += delta
	var changed := 0
	for c in _bots:
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

## The four numbers Checklist §9's fairness table asks for, each printed next to
## that table's own fair range so a run is self-scoring and nobody has to go
## look up what "good" was. ⚠️ It prints the PER-ROUND table as well as the
## aggregate on purpose: an aggregate hides the bimodal case (half the rounds
## resolved in 10s, half timed out) that §9 explicitly warns about.
func _report_fairness() -> void:
	print("\n=== AI FAIRNESS RUN (%d rounds, %s, time_scale %.1f, taya_pursue_radius %.1f) ==="
		% [_rounds.size(), _mode_name(), _scale, AIController.taya_pursue_radius])
	print("  round  winner    dur(s)  1st-throw  throws  blocked  on-can  dents  ended-by")
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
		print("  %5d  %-8s  %6.1f  %9s  %6d  %7d  %6d  %5d  %s" % [
			r["number"],
			"DEFENCE" if r["defender_won"] else "OFFENCE",
			r["duration"],
			("%.1f" % r["first_throw_at"]) if r["first_throw_at"] >= 0.0 else "none",
			r["throws_taken"], r["throws_blocked"], r["throws_on_can"], r["dents"],
			_ended_by(r),
		])

	var n: int = maxi(_rounds.size(), 1)
	var defender_rate := 100.0 * defender_wins / n
	var mean_first_throw := first_throw_total / maxi(first_throw_count, 1)
	var block_rate := 100.0 * blocked / maxi(throws, 1)
	var dents_per_round := float(dents) / n
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
	print("\n  throws that reached the can: %d   rounds with no throw at all: %d   rounds timed out: %d"
		% [on_can, no_throw_rounds, timeouts])
	print("  rounds the DEFENCE won by TAGGING the attacker: %d / %d  (%.0f%% of all rounds)"
		% [tag_rounds, _rounds.size(), 100.0 * tag_rounds / n])
	# ⚠️ §9's own warning, printed rather than left to be remembered: a win rate
	# on its own is not a fairness result.
	if timeouts * 2 >= _rounds.size():
		print("  ⚠️ HALF OR MORE OF THESE ROUNDS TIMED OUT — the win rate above is NOT a")
		print("     balance result. Rounds that never resolve are the failure to fix first.")

func _verdict(ok: bool) -> String:
	return "OK" if ok else "OUT OF RANGE"

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
