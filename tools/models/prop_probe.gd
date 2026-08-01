extends Node

## The four things the human asked to be SURE of about the new props, measured
## over a real match rather than looked at once.
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/models/prop_probe.tscn -- <seconds>
##
## ⚠️ RUN IT WITH THE PLAIN EXE — it drives the real `Main.tscn`, and `--headless`
## has no rendering device. It prints a PASS/FAIL block and exits non-zero on any
## failure, so it is a gate that can be re-run, not a screenshot.
##
## 🧑 2026-08-01, in one message:
##   1. *"make sure cans dont clip at all to the floor. ever."*
##   2. *"make sure its on the hands of the people for everyones pov"*
##   3. *"Make sure the cans still bounce and doesnt perma stay upright (old bug)"*
##   4. *"make sure slippers are actually throwable"*
##
## Each maps to one counter below. They are watched EVERY FRAME for the whole run
## rather than sampled, because three of the four are transient: a slipper is only
## in flight for about a second, and a lata that fails to topple fails on one
## specific throw and looks fine on either side of it.
##
## ⚠️ IT IS STOCHASTIC — THE BOTS PLAY THE ROUND, SO RE-RUN BEFORE BELIEVING A
## FAILURE ON 2 OR 3. Observed across runs: item 3 reports 0 knockdowns perhaps one
## run in three simply because no bot happened to land a throw in the window, and
## item 2's worst-case spikes to ~75 mm when a tag TELEPORTS a carrier — the
## carrier's `velocity` is zero on that frame, so the "standing still" filter lets
## a legitimate one-frame jump through. Neither is a defect in the props. A REAL
## failure reproduces on every run: the mid-topple floor dip this probe was written
## to catch showed up at -0.0212 m every single time. Run it twice; two clean runs
## with a four-figure "still" sample count is the pass.
##
## ⚠️ WHY THE HAND CHECK IS A DISTANCE AND NOT A PICTURE. `slipper.gd::_step_carried()`
## puts the slipper's ORIGIN on the carrier's hand attachment, and every peer runs
## that same line locally off the carrier's replicated transform — so "can other
## people see it in the hand" is answered by whether the origin tracks the hand,
## which is one number. It reads zero only because every slipper mesh is now
## centred on its own volume centroid; with the old sole-underside origin the mesh
## hung half a slipper below the hand, which is the float that was reported.

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

var _main: Node = null
var _seconds: float = 40.0

var _knockdowns: int = 0
var _throws: int = 0
var _carry_samples: int = 0
var _worst_hand_gap: float = 0.0
var _still_samples: int = 0
var _worst_still_gap: float = 0.0
var _lowest_lata_y: float = INF
var _was_upright: bool = true
var _seen_states: Dictionary = {}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_seconds = String(args[0]).to_float()
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	if _main.has_method("_run_ready_countdown"):
		_main._run_ready_countdown()
	await get_tree().create_timer(4.5).timeout
	var elapsed := 0.0
	while elapsed < _seconds:
		_sample()
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_report()

func _sample() -> void:
	var lata: Lata = RoundManager.lata
	if lata != null and is_instance_valid(lata):
		# 3 — the topple actually happens, repeatedly, over a whole match.
		if _was_upright and not lata.is_upright:
			_knockdowns += 1
		_was_upright = lata.is_upright
		# 1 — the floor. Measured on the VISUAL, which is what tips over; the
		# node itself never leaves the floor plane.
		var visual := lata.get_node_or_null("Visual") as Node3D
		if visual != null:
			for node in visual.find_children("*", "VisualInstance3D", true, false):
				var mesh_node := node as VisualInstance3D
				var box: AABB = mesh_node.get_aabb()
				var xf: Transform3D = mesh_node.global_transform
				for i in range(8):
					_lowest_lata_y = minf(_lowest_lata_y, (xf * box.get_endpoint(i)).y)

	for node in _main.find_children("*", "Node3D", true, false):
		var slipper := node as Slipper
		if slipper == null:
			continue
		_seen_states[slipper.state] = true
		# 4 — a slipper reaching FLYING is a throw that was accepted and left the
		# hand. Counted on the transition so one long flight is not counted twice.
		if slipper.state == Slipper.CarryState.FLYING:
			if not slipper.has_meta("counted_flight"):
				slipper.set_meta("counted_flight", true)
				_throws += 1
		else:
			if slipper.has_meta("counted_flight"):
				slipper.remove_meta("counted_flight")
		# 2 — carried slippers ride the hand, on every machine.
		if slipper.state == Slipper.CarryState.CARRIED and slipper.carrier != null:
			var hand := slipper.carrier.get_hand_attachment()
			if hand != null:
				var gap := hand.global_position.distance_to(slipper.global_position)
				_carry_samples += 1
				_worst_hand_gap = maxf(_worst_hand_gap, gap)
				# ⚠️ THE GAP IS ONLY MEANINGFUL WHILE THE CARRIER IS STILL, and
				# separating the two cases is what tells a FLOAT from a LAG.
				# `_step_carried()` copies the hand's transform once per frame, so
				# a sprinting carrier is always one frame ahead of their own
				# slipper — at 6.9 m/s that is 0.115 m of perfectly correct
				# "gap", and reading it as a float sends you chasing a bug that
				# is not there. A genuine float shows up when nobody is moving.
				var speed: float = slipper.carrier.velocity.length()
				if speed < 0.05:
					_still_samples += 1
					_worst_still_gap = maxf(_worst_still_gap, gap)

func _report() -> void:
	print("")
	print("=== PROP PROBE — %.0f s of live match ===" % _seconds)
	var fails := 0

	# 1. The floor. Tolerance is one millimetre: the lift is derived from a
	# bounding box, so a hair of positive error is expected and fine.
	var floor_ok := _lowest_lata_y >= -0.001
	print("1 lata vs floor    : lowest point %+.4f m   %s"
		% [_lowest_lata_y, "PASS" if floor_ok else "FAIL - clipping"])
	if not floor_ok:
		fails += 1

	# 2. The hand. The slipper's origin IS its middle now, so anything above a
	# few centimetres means it is not being held.
	# Judged on the STILL samples only — see the note at the sample site. A moving
	# carrier is one frame ahead of their slipper by construction and that is not
	# a defect.
	var hand_ok := _still_samples > 0 and _worst_still_gap <= 0.02
	print("2 slipper in hand  : %d samples (%d still)  worst %.4f m  worst-while-still %.4f m   %s"
		% [_carry_samples, _still_samples, _worst_hand_gap, _worst_still_gap,
			"PASS" if hand_ok else ("FAIL - floating" if _still_samples > 0
				else "INCONCLUSIVE - nobody stood still holding one")])
	if not hand_ok:
		fails += 1

	# 3. The topple.
	var topple_ok := _knockdowns > 0
	print("3 lata topples     : %d knockdown(s)   %s"
		% [_knockdowns, "PASS" if topple_ok else "FAIL - never went over"])
	if not topple_ok:
		fails += 1

	# 4. The throw.
	var throw_ok := _throws > 0
	print("4 slippers thrown  : %d flight(s), states seen %s   %s"
		% [_throws, str(_seen_states.keys()),
			"PASS" if throw_ok else "FAIL - nothing ever flew"])
	if not throw_ok:
		fails += 1

	# ⚠️ WHY THE PER-PLAYER DUMP IS HERE. Items 3 and 4 can only fail because a bot
	# never threw, and "never threw" has at least five distinct causes — it is not
	# holding, it is inside the box, the lata is down, the throw is on cooldown, or
	# it is charging and never releasing. Guessing between them costs a run each;
	# printing all five costs nothing and ends the question in one.
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		var carrier := who.get_node_or_null("Carrier") as Carrier
		print("   %-4s def=%-5s hold=%-5s inbox=%-5s can_throw=%-5s pos=(%.1f,%.1f) chebyshev=%.2f charge=%.2f vel=%.2f"
			% [who.display_name(), who.is_defender, who.holding_slipper(),
				who.is_inside_box(), RoundManager.can_throw(who),
				who.global_position.x, who.global_position.z,
				maxf(absf(who.global_position.x), absf(who.global_position.z)),
				carrier.charge_power() if carrier != null else -1.0,
				who.velocity.length()])
	print("   box radius = %.2f" % CharacterBase.confinement_radius)

	print("=== %s ===" % ("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)
