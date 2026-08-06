extends Node3D

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

const MIN_SEPARATION: float = 0.02

var _main: Node = null
var _failures: Array[String] = []
var _lines: Array[String] = []
var _done: bool = false

const PERSON_TEST_IMPULSE: float = 8.0

func _ready() -> void:
	GameLaunch.spectator = true
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()

func _log(text: String) -> void:
	_lines.append(text)

func _check(name: String, live: bool, low_label: String, low: float,
		high_label: String, high: float, expect_high_bigger: bool) -> void:
	var tag := "[live]   " if live else "[derived]"
	var gap := absf(high - low)
	var ordered := (high > low) if expect_high_bigger else (high < low)
	var ok := gap >= MIN_SEPARATION and ordered
	_log("%s %-26s %-14s %8.4f   %-14s %8.4f   %s"
		% [tag, name, low_label, low, high_label, high, "OK" if ok else "FAIL"])
	if ok:
		return
	if gap < MIN_SEPARATION:
		_failures.append("%s: %s and %s produce the same value (%.4f) — the stat does "
			% [name, low_label, high_label, low]
			+ "not reach this call site.")
	else:
		_failures.append("%s: %s (%.4f) and %s (%.4f) differ in the WRONG DIRECTION."
			% [name, low_label, low, high_label, high])

func _wait_for_round() -> bool:
	for _i in range(1200):
		await get_tree().physics_frame
		if RoundManager.round_active and RoundManager.lata != null:
			for _j in range(8):
				await get_tree().physics_frame
			return true
	return false

func _run() -> void:
	if not await _wait_for_round():
		_failures.append("HARNESS: the match never reached a live round.")
		_report()
		return

	var can: Lata = RoundManager.lata
	var attackers: Array[CharacterBase] = []
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who != null and not who.is_defender:
			attackers.append(who)
	if attackers.size() < 2:
		_failures.append("HARNESS: fewer than two attackers in a live round.")
		_report()
		return

	await _check_slipper(attackers[0])
	await _check_lata(can)
	await _check_person()
	_report()

func _check_slipper(who: CharacterBase) -> void:
	var slipper := _slipper_owned_by(who)
	if slipper == null:
		_failures.append("HARNESS: P%d owns no slipper to test with." % (who.player_slot + 1))
		return
	var fast := CharacterRoster.index_in(CharacterRoster.SLIPPERS, &"sike")
	var slow := CharacterRoster.index_in(CharacterRoster.SLIPPERS, &"crocs")
	var heavy := CharacterRoster.index_in(CharacterRoster.SLIPPERS, &"crocs")
	var light := CharacterRoster.index_in(CharacterRoster.SLIPPERS, &"pantulog")
	var quick := CharacterRoster.index_in(CharacterRoster.SLIPPERS, &"pantulog")
	var slug := CharacterRoster.index_in(CharacterRoster.SLIPPERS, &"crocs")

	var slow_speed := await _launch_speed_of(slipper, who, slow)
	var fast_speed := await _launch_speed_of(slipper, who, fast)
	_check("tsinelas FLIGHT", true, "CROCS(2)", slow_speed, "IKE(4)", fast_speed, true)

	var slug_lock := await _throw_lock_of(slipper, who, slug)
	var quick_lock := await _throw_lock_of(slipper, who, quick)
	_check("tsinelas RECOVERY (throw lock)", true, "CROCS(2)", slug_lock,
		"PANTULOG(5)", quick_lock, false)

	var blocker := _other_attacker(who)
	if blocker == null:
		_log("[skip]    tsinelas IMPACT           no second attacker available")
		return
	var soft_push := await _block_push(slipper, who, blocker, light)
	var hard_push := await _block_push(slipper, who, blocker, heavy)
	_check("tsinelas IMPACT (block push)", true, "PANTULOG(1)", soft_push,
		"CROCS(5)", hard_push, true)

func _launch_speed_of(slipper: Slipper, who: CharacterBase, skin: int) -> float:
	await _rearm(slipper, who, skin)
	if not slipper.is_loose() and not slipper.state == Slipper.CarryState.CARRIED:
		return 0.0
	var origin := who.global_position + Vector3.UP * 1.2
	var target := origin + Vector3(0.0, 0.0, -8.0)
	slipper.host_throw(who, origin, target, 1.0)
	if not slipper.is_flying():
		return 0.0
	var before := slipper.global_position
	await get_tree().physics_frame
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	return (slipper.global_position - before).length() / step

func _throw_lock_of(slipper: Slipper, who: CharacterBase, skin: int) -> float:
	await _rearm(slipper, who, skin)
	var hands := who.get_node_or_null("Carrier") as Carrier
	return hands.throw_lock_left() if hands != null else 0.0

func _block_push(slipper: Slipper, who: CharacterBase, blocker: CharacterBase,
		skin: int) -> float:
	await _rearm(slipper, who, skin)
	for _i in range(40):
		_park(blocker)
		await get_tree().physics_frame
		if Vector2(blocker.velocity.x, blocker.velocity.z).length() < 0.02:
			break
	var origin := blocker.global_position + Vector3(0.0, 0.2, 3.0)
	slipper.host_throw(who, origin, blocker.global_position, 1.0)
	for _i in range(90):
		_park(blocker)
		await get_tree().physics_frame
		var moved := Vector2(blocker.velocity.x, blocker.velocity.z).length()
		if moved > 0.05:
			return moved
		if not slipper.is_flying():
			return 0.0
	return 0.0

func _park(who: CharacterBase) -> void:
	if who.ai_controller != null and who.ai_controller.is_enabled():
		who.ai_controller.set_enabled(false)
	who.input_parked = true
	who.ai_clear_intent()

func _rearm(slipper: Slipper, who: CharacterBase, skin: int) -> void:
	slipper.host_reset_for_new_round()
	slipper.apply_skin(skin)
	slipper.host_assign_owner(who.player_slot)
	slipper.global_position = who.global_position
	await get_tree().physics_frame
	slipper.host_grab(who)
	await get_tree().physics_frame

func _slipper_owned_by(who: CharacterBase) -> Slipper:
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper != null and slipper.owner_slot == who.player_slot:
			return slipper
	for node in get_tree().get_nodes_in_group("slippers"):
		return node as Slipper
	return null

func _other_attacker(not_this: CharacterBase) -> CharacterBase:
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who != null and not who.is_defender and who != not_this:
			return who
	return null

func _check_lata(can: Lata) -> void:
	var quick := CharacterRoster.index_in(CharacterRoster.CANS, &"pasip")
	var slow := CharacterRoster.index_in(CharacterRoster.CANS, &"boyben")
	var heavy := CharacterRoster.index_in(CharacterRoster.CANS, &"metal")
	var light := CharacterRoster.index_in(CharacterRoster.CANS, &"pasip")
	var tough := CharacterRoster.index_in(CharacterRoster.CANS, &"boyben")
	var frail := CharacterRoster.index_in(CharacterRoster.CANS, &"pasip")
	var flight_tough := CharacterRoster.index_in(CharacterRoster.CANS, &"decades")

	can.apply_skin(slow)
	var slow_channel := _channel_time_for(can)
	can.apply_skin(quick)
	var quick_channel := _channel_time_for(can)
	_check("lata RESET (reset channel)", true, "BOYBEN(1)", slow_channel,
		"PASIP(5)", quick_channel, false)

	can.apply_skin(tough)
	var tough_window := Slipper.HIT_RADIUS + can.hit_margin()
	can.apply_skin(frail)
	var frail_window := Slipper.HIT_RADIUS + can.hit_margin()
	_check("lata STANCE (hit window)", true, "BOYBEN(5)", tough_window,
		"PASIP(1)", frail_window, true)
	can.apply_skin(flight_tough)
	var flight_tough_window := Slipper.HIT_RADIUS + can.hit_margin()
	await _check_window_is_live(can, flight_tough, frail, flight_tough_window, frail_window)

	var light_recoil := await _recoil_speed_of(can, light)
	var heavy_recoil := await _recoil_speed_of(can, heavy)
	_check("lata REBOUND (recoil)", true, "PASIP(1)", light_recoil,
		"KALAWANG(5)", heavy_recoil, true)

func _check_window_is_live(can: Lata, tough: int, frail: int,
		tough_window: float, frail_window: float) -> void:
	var gap := (tough_window + frail_window) * 0.5
	var tough_hit := await _knocks_down_any(can, tough, gap)
	var frail_hit := await _knocks_down_any(can, frail, gap)
	var ok := frail_hit and not tough_hit
	_log("[live]    lata STANCE is READ         gap %.3f m -> PASIP(1) %s, DECADES(4) %s   %s"
		% [gap, ("HIT" if frail_hit else "miss"), ("HIT" if tough_hit else "miss"),
			"OK" if ok else "FAIL"])
	if not ok:
		_failures.append(("lata STANCE: a slipper passing %.3f m from the can knocked it "
			+ "over on PASIP=%s and DECADES=%s. Both cans answer the same, so "
			+ "`slipper.gd` is not reading `hit_margin()`.")
			% [gap, str(frail_hit), str(tough_hit)])

func _clear_the_court() -> void:
	var corners := [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]
	var i := 0
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		_park(who)
		var corner: Vector3 = corners[i % corners.size()]
		who.global_position = Vector3(
			corner.x * CharacterBase.confinement_radius,
			who.global_position.y,
			corner.z * CharacterBase.confinement_radius)
		who.velocity = Vector3.ZERO
		i += 1

const WINDOW_ATTEMPTS: int = 3

func _knocks_down_any(can: Lata, skin: int, distance: float) -> bool:
	for _i in range(WINDOW_ATTEMPTS):
		if await _knocks_down_at(can, skin, distance):
			return true
	return false

func _knocks_down_at(can: Lata, skin: int, distance: float) -> bool:
	can.apply_skin(skin)
	can.host_reset_for_new_round()
	var slipper := _any_slipper()
	if slipper == null:
		return false
	var attacker := _other_attacker(null)
	if attacker == null:
		return false
	_clear_the_court()
	await get_tree().physics_frame
	slipper.host_reset_for_new_round()
	slipper.host_assign_owner(attacker.player_slot)
	var from := can.global_position + Vector3(distance, 0.0, 4.0)
	var to := can.global_position + Vector3(distance, 0.0, -4.0)
	slipper.global_position = from
	await get_tree().physics_frame
	slipper.host_grab(attacker)
	await get_tree().physics_frame
	slipper.host_throw(attacker, from, to, 1.0)
	for _i in range(90):
		await get_tree().physics_frame
		if not can.is_upright:
			return true
		if not slipper.is_flying():
			return false
	return false

func _any_slipper() -> Slipper:
	for node in get_tree().get_nodes_in_group("slippers"):
		return node as Slipper
	return null

func _channel_time_for(can: Lata) -> float:
	return can.reset_channel_time()

func _check_person() -> void:
	var quick := CharacterRoster.index_of(&"jun_jun")
	var slow := CharacterRoster.index_of(&"lola_pacing")
	var strong := CharacterRoster.index_of(&"bebang")
	var weak := CharacterRoster.index_of(&"jun_jun")
	var tough := CharacterRoster.index_of(&"bebang")
	var frail := CharacterRoster.index_of(&"mang_kanor")
	var who := RoundManager.player_at(0)
	if who == null:
		_failures.append("HARNESS: no P1 to read Person traits from.")
		return
	who.character_index = slow
	var slow_speed := who.trait_speed_scale()
	who.character_index = quick
	var quick_speed := who.trait_speed_scale()
	_check("person SPEED", false, "LOLA(1)", slow_speed, "JUN-JUN(5)", quick_speed, true)

	var victim := _other_attacker(who)
	if victim == null:
		_log("[skip]    person POWER              no second attacker to shove")
	else:
		var weak_push := await _shove_push(who, victim, weak)
		var strong_push := await _shove_push(who, victim, strong)
		_check("person POWER (shove)", true, "JUN-JUN(1)", weak_push,
			"BEBANG(5)", strong_push, true)

	who.character_index = frail
	var frail_push := _knockback_speed(who)
	who.character_index = tough
	var tough_push := _knockback_speed(who)
	_check("person GRIT (knockback)", true, "KANOR(2)", frail_push,
		"BEBANG(5)", tough_push, false)

	var seen: Dictionary = {}
	for i in range(CharacterRoster.size()):
		var entry: Dictionary = CharacterRoster.at(i)
		var traits: Dictionary = entry.get("traits", {})
		var key := "%d/%d/%d" % [int(traits.get(&"bilis", 3)), int(traits.get(&"lakas", 3)),
			int(traits.get(&"tatag", 3))]
		if seen.has(key):
			_failures.append("person roster: %s and %s are both %s — one character, two rigs."
				% [String(seen[key]), String(entry.get("name", "?")), key])
		seen[key] = entry.get("name", "?")
	_log("[live]    person rows distinct        %d of %d trait rows unique"
		% [seen.size(), CharacterRoster.size()])

func _report() -> void:
	if _done:
		return
	_done = true
	print("")
	print("================ TRAIT PROBE — do the stats apply? ================")
	print("%-9s %-26s %-14s %8s   %-14s %8s"
		% ["kind", "stat", "low pick", "value", "high pick", "value"])
	for line in _lines:
		print(line)
	print("")
	if _failures.is_empty():
		print("RESULT: PASS — every stat reaches a real call site.")
		get_tree().quit(0)
		return
	print("RESULT: FAIL — %d check(s)" % _failures.size())
	for line in _failures:
		print("  * " + line)
	get_tree().quit(1)

func _recoil_speed_of(can: Lata, skin: int) -> float:
	for _attempt in range(WINDOW_ATTEMPTS):
		var speed := await _recoil_once(can, skin)
		if speed > 0.0:
			return speed
	return 0.0

func _recoil_once(can: Lata, skin: int) -> float:
	can.apply_skin(skin)
	can.host_reset_for_new_round()
	var slipper := _any_slipper()
	var attacker := _other_attacker(null)
	if slipper == null or attacker == null:
		return 0.0
	_clear_the_court()
	await get_tree().physics_frame
	slipper.host_reset_for_new_round()
	slipper.host_assign_owner(attacker.player_slot)
	var from := can.global_position + Vector3(0.0, 0.0, 4.0)
	var to := can.global_position + Vector3(0.0, 0.0, -4.0)
	slipper.global_position = from
	await get_tree().physics_frame
	slipper.host_grab(attacker)
	await get_tree().physics_frame
	slipper.host_throw(attacker, from, to, 1.0)
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	for _i in range(90):
		await get_tree().physics_frame
		if not can.is_upright:
			var before := slipper.global_position
			await get_tree().physics_frame
			return (slipper.global_position - before).length() / step
		if not slipper.is_flying():
			return 0.0
	return 0.0

func _knockback_speed(who: CharacterBase) -> float:
	who.velocity = Vector3.ZERO
	who.apply_knockback(Vector3(PERSON_TEST_IMPULSE, 0.0, 0.0))
	return Vector2(who.velocity.x, who.velocity.z).length()

func _shove_push(shover: CharacterBase, victim: CharacterBase, skin: int) -> float:
	shover.character_index = skin
	for _i in range(240):
		if victim.can_act():
			break
		await get_tree().physics_frame
	_park(shover)
	_park(victim)
	victim.global_position = shover.global_position + Vector3(1.0, 0.0, 0.0)
	victim.velocity = Vector3.ZERO
	await get_tree().physics_frame
	victim.velocity = Vector3.ZERO
	shover.host_resolve_shove(shover.player_slot, shover.global_position, Vector3.RIGHT)
	return Vector2(victim.velocity.x, victim.velocity.z).length()

