extends Node


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
		if _was_upright and not lata.is_upright:
			_knockdowns += 1
		_was_upright = lata.is_upright
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
		if slipper.state == Slipper.CarryState.FLYING:
			if not slipper.has_meta("counted_flight"):
				slipper.set_meta("counted_flight", true)
				_throws += 1
		else:
			if slipper.has_meta("counted_flight"):
				slipper.remove_meta("counted_flight")
		if slipper.state == Slipper.CarryState.CARRIED and slipper.carrier != null:
			var hand := slipper.carrier.get_hand_attachment()
			if hand != null:
				var gap := hand.global_position.distance_to(slipper.global_position)
				_carry_samples += 1
				_worst_hand_gap = maxf(_worst_hand_gap, gap)
				var speed: float = slipper.carrier.velocity.length()
				if speed < 0.05:
					_still_samples += 1
					_worst_still_gap = maxf(_worst_still_gap, gap)

func _report() -> void:
	print("")
	print("=== PROP PROBE — %.0f s of live match ===" % _seconds)
	var fails := 0

	var floor_ok := _lowest_lata_y >= -0.001
	print("1 lata vs floor    : lowest point %+.4f m   %s"
		% [_lowest_lata_y, "PASS" if floor_ok else "FAIL - clipping"])
	if not floor_ok:
		fails += 1

	var hand_ok := _still_samples > 0 and _worst_still_gap <= 0.02
	print("2 slipper in hand  : %d samples (%d still)  worst %.4f m  worst-while-still %.4f m   %s"
		% [_carry_samples, _still_samples, _worst_hand_gap, _worst_still_gap,
			"PASS" if hand_ok else ("FAIL - floating" if _still_samples > 0
				else "INCONCLUSIVE - nobody stood still holding one")])
	if not hand_ok:
		fails += 1

	var topple_ok := _knockdowns > 0
	print("3 lata topples     : %d knockdown(s)   %s"
		% [_knockdowns, "PASS" if topple_ok else "FAIL - never went over"])
	if not topple_ok:
		fails += 1

	var throw_ok := _throws > 0
	print("4 slippers thrown  : %d flight(s), states seen %s   %s"
		% [_throws, str(_seen_states.keys()),
			"PASS" if throw_ok else "FAIL - nothing ever flew"])
	if not throw_ok:
		fails += 1

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

