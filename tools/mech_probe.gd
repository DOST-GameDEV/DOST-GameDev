extends Node3D

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

const ACTIONS: Array[String] = ["move_left", "move_right", "move_up", "move_down",
	"sprint", "grab", "lunge", "special_ability"]

const AIM_TOLERANCE: float = 0.25

var _main: Node = null
var _lines: Array[String] = []
var _failures: Array[String] = []
var _puppets: Dictionary = {}
var _done: bool = false

class Puppet extends AIController:
	var press: Dictionary = {}

	func decide(_delta: float) -> void:
		if character == null or not is_instance_valid(character):
			return
		for action in ACTIONS:
			_press(action, bool(press.get(action, false)))

func _ready() -> void:
	GameLaunch.spectator = true
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_hold_puppets()
	if RoundManager.round_active and RoundManager.time_left < 30.0:
		RoundManager.time_left = RoundManagerScript.ROUND_TIME

func _log(text: String) -> void:
	_lines.append(text)


func _puppet(who: CharacterBase) -> Puppet:
	if _puppets.has(who.player_slot) and is_instance_valid(_puppets[who.player_slot]):
		var existing: Puppet = _puppets[who.player_slot]
		who.ai_controller = existing
		return existing
	var original := who.ai_controller
	if original != null:
		original.set_enabled(false)
	var brain := Puppet.new()
	brain.name = "MechProbePuppet"
	who.add_child(brain)
	who.ai_controller = brain
	who.ai_clear_intent()
	_puppets[who.player_slot] = brain
	return brain

func _hold_puppets() -> void:
	for slot in _puppets.keys():
		var brain = _puppets[slot]
		if not is_instance_valid(brain):
			continue
		var who := RoundManager.player_at(int(slot))
		if who != null and who.ai_controller != brain:
			who.ai_controller = brain

func _neutralise(who: CharacterBase) -> void:
	who.character_index = CharacterRoster.index_of(&"ate_girlie")

func _place(who: CharacterBase, where: Vector3) -> void:
	who.global_position = where
	who.velocity = Vector3.ZERO

func _clear_bench(keep: CharacterBase) -> void:
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null:
			continue
		slipper.host_reset_for_new_round()
		slipper.global_position = Vector3(-20.0, 0.2, -20.0)
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		who.notify_holding(null)
		if who == keep:
			continue
		_place(who, Vector3(-14.0, who.global_position.y, -14.0 + 2.0 * float(who.player_slot)))
		var brain = _puppets.get(who.player_slot, null)
		if brain != null and is_instance_valid(brain):
			_release(brain)

func _release(brain: Puppet) -> void:
	brain.press.clear()

func _face_by_walking(who: CharacterBase, brain: Puppet, toward: Vector3,
		frames: int) -> void:
	for _i in range(frames):
		_hold_puppets()
		var delta := toward - who.global_position
		delta.y = 0.0
		if delta.length() > 0.001:
			var flat := delta.normalized()
			brain.press["move_right"] = flat.x > 0.3827
			brain.press["move_left"] = flat.x < -0.3827
			brain.press["move_down"] = flat.z > 0.3827
			brain.press["move_up"] = flat.z < -0.3827
		await get_tree().physics_frame

func _tap(brain: Puppet, action: String) -> void:
	brain.press[action] = false
	await get_tree().physics_frame
	brain.press[action] = true
	await get_tree().physics_frame
	brain.press[action] = false
	await get_tree().physics_frame

func _wait_for_round() -> bool:
	for _i in range(3000):
		await get_tree().physics_frame
		if RoundManager.round_active and RoundManager.lata != null:
			for _j in range(10):
				await get_tree().physics_frame
			return true
	return false

func _step() -> float:
	return 1.0 / float(maxi(1, Engine.physics_ticks_per_second))

func _run() -> void:
	if not await _wait_for_round():
		_failures.append("HARNESS: the match never reached a live round.")
		_report()
		return
	var taya := RoundManager.defender()
	var attackers: Array[CharacterBase] = []
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who != null and not who.is_defender:
			attackers.append(who)
	if taya == null or attackers.size() < 2:
		_failures.append("HARNESS: need a taya and two attackers.")
		_report()
		return
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who != null:
			_puppet(who)
			_neutralise(who)
	await get_tree().physics_frame

	await _measure_shove(attackers[0], attackers[1])
	await _measure_stamina(attackers[0])
	await _measure_tag(taya, attackers[0])
	await _measure_aim(attackers[0])
	_report()

func _measure_shove(shover: CharacterBase, victim: CharacterBase) -> void:
	_log("")
	_log("--- §2.4  the shove  (Design.md §5.3: 2.50 m, 1.25 s stun, 25 of 50 stamina) ---")
	var shover_brain: Puppet = _puppets[shover.player_slot]
	var victim_brain: Puppet = _puppets[victim.player_slot]
	_release(shover_brain)
	_release(victim_brain)

	_clear_bench(shover)
	var base := Vector3(0.0, victim.global_position.y, 10.0)
	_place(shover, base)
	_place(victim, base + Vector3(0.0, 0.0, -1.0))
	await get_tree().physics_frame
	await _face_by_walking(shover, shover_brain, victim.global_position, 16)
	_release(shover_brain)
	await get_tree().physics_frame

	var stamina_before := shover.get_stamina_ratio() * CharacterBase.STAMINA_MAX
	var from := victim.global_position
	var to_them := victim.global_position - shover.global_position
	to_them.y = 0.0
	var facing := -shover.global_transform.basis.z
	facing.y = 0.0
	var arc := rad_to_deg(facing.normalized().angle_to(to_them.normalized())) \
		if to_them.length() > 0.01 and facing.length() > 0.01 else 999.0
	_log("setup: gap %.2f m (range %.2f)  arc %.1f deg (limit %.1f)  stamina %.1f  cd %.2f  victim %s"
		% [to_them.length(), CharacterBase.SHOVE_RANGE, arc, CharacterBase.SHOVE_ARC_DEG,
			stamina_before, shover.shove_cooldown_left(),
			("NORMAL" if victim.state == CharacterBase.State.NORMAL else "STUNNED")])
	await _tap(shover_brain, "grab")

	var stunned_for := 0.0
	var settled := 0
	for _i in range(900):
		_hold_puppets()
		await get_tree().physics_frame
		if victim.state != CharacterBase.State.NORMAL:
			stunned_for += _step()
		var speed := Vector2(victim.velocity.x, victim.velocity.z).length()
		if speed < 0.05:
			settled += 1
			if settled > 6:
				break
		else:
			settled = 0
	var travelled := Vector2(victim.global_position.x - from.x,
		victim.global_position.z - from.z).length()
	var spent := stamina_before - shover.get_stamina_ratio() * CharacterBase.STAMINA_MAX

	_log("knockback      %.2f m        (predicted %.2f, from v %.3f by v²/FRICTION_2)"
		% [travelled, CharacterBase.SHOVE_SPEED * CharacterBase.SHOVE_SPEED / 60.0,
			CharacterBase.SHOVE_SPEED])
	_log("stun           %.2f s        (const %.2f)" % [stunned_for, CharacterBase.SHOVE_STUN])
	_log("stamina spent  %.1f of %.1f   (const %.1f) -> %d shoves per full bar"
		% [spent, CharacterBase.STAMINA_MAX, CharacterBase.SHOVE_STAMINA_COST,
			int(CharacterBase.STAMINA_MAX / maxf(CharacterBase.SHOVE_STAMINA_COST, 0.01))])
	_log("cooldown       %.2f s        -> at most %.1f shoves in a 90 s round"
		% [CharacterBase.SHOVE_COOLDOWN, 90.0 / CharacterBase.SHOVE_COOLDOWN])
	_log("⚠️ the real price is the SPRINT: %.1f of the bar is %.2f s of sprint (%.2f m)"
		% [CharacterBase.SHOVE_STAMINA_COST,
			CharacterBase.SHOVE_STAMINA_COST / CharacterBase.STAMINA_DRAIN_RATE,
			CharacterBase.SHOVE_STAMINA_COST / CharacterBase.STAMINA_DRAIN_RATE
				* CharacterBase.SPEED * CharacterBase.ATTACKER_SPEED_SCALE
				* CharacterBase.SPRINT_SCALE])

func _measure_stamina(who: CharacterBase) -> void:
	_log("")
	_log("--- §2.5  stamina  (Design.md §3: 50 pts, 40/s drain, 1.25 s sprint, 2.0 s fatigue) ---")
	var brain: Puppet = _puppets[who.player_slot]
	_release(brain)
	_clear_bench(who)
	_place(who, Vector3(0.0, who.global_position.y, 12.0))
	who.reset_for_new_round()
	await get_tree().physics_frame

	brain.press["move_right"] = true
	brain.press["sprint"] = true
	var sprint_time := 0.0
	var from := who.global_position
	for _i in range(1800):
		_hold_puppets()
		await get_tree().physics_frame
		if who.is_fatigued():
			break
		sprint_time += _step()
	var sprint_distance := Vector2(who.global_position.x - from.x,
		who.global_position.z - from.z).length()
	_release(brain)

	var fatigue_time := 0.0
	for _i in range(1800):
		_hold_puppets()
		await get_tree().physics_frame
		if not who.is_fatigued():
			break
		fatigue_time += _step()

	var refill := 0.0
	for _i in range(3600):
		_hold_puppets()
		await get_tree().physics_frame
		if who.get_stamina_ratio() >= 0.995:
			break
		refill += _step()

	_log("sprint to empty     %.2f s   (%.2f m covered)" % [sprint_time, sprint_distance])
	_log("fatigue lockout     %.2f s   (const %.2f, regen locked throughout)"
		% [fatigue_time, CharacterBase.FATIGUE_TIME])
	_log("empty -> full again %.2f s   (%.1f s delay + %.1f s refill)"
		% [refill, CharacterBase.STAMINA_REGEN_DELAY,
			CharacterBase.STAMINA_MAX / CharacterBase.STAMINA_REGEN_RATE])
	_log("⚠️ one full sprint covers %.2f m against a box half-width of %.2f m (%.0f%%)"
		% [sprint_distance, CharacterBase.confinement_radius,
			100.0 * sprint_distance / maxf(CharacterBase.confinement_radius, 0.01)])

func _measure_tag(taya: CharacterBase, victim: CharacterBase) -> void:
	_log("")
	_log("--- §2.6  the tag  (LUNGE_TAG_RADIUS %.2f m, swept every frame the dash is live) ---"
		% CharacterBase.LUNGE_TAG_RADIUS)
	_clear_bench(taya)
	await get_tree().physics_frame
	var still_reach := await _tag_reach(taya, victim, false)
	var moving_reach := await _tag_reach(taya, victim, true)
	_log("furthest start that still tags, target STILL     %.2f m" % still_reach)
	_log("furthest start that still tags, target CROSSING  %.2f m   (at %.2f m/s)"
		% [moving_reach, CharacterBase.SPEED * CharacterBase.ATTACKER_SPEED_SCALE])
	if still_reach > 0.0 and moving_reach > 0.0:
		_log("⚠️ the sweep loses %.2f m (%.0f%%) against a crossing body — a lead problem, not a tunnel."
			% [still_reach - moving_reach,
				100.0 * (still_reach - moving_reach) / maxf(still_reach, 0.01)])
	elif moving_reach <= 0.0:
		_log("⚠️⚠️ NO RANGE TAGS A CROSSING TARGET — that is the tunnelling failure §2.6 feared.")

	_log("")
	_log("--- §2.7  what a tag costs  (TAG_STUN_TIME %.1f s of a %.0f s round) ---"
		% [RoundManagerScript.TAG_STUN_TIME, RoundManagerScript.ROUND_TIME])
	_log("stun alone            %.1f s = %.1f%% of a round"
		% [RoundManagerScript.TAG_STUN_TIME,
			100.0 * RoundManagerScript.TAG_STUN_TIME / RoundManagerScript.ROUND_TIME])
	var to_throw := RoundManagerScript.TAG_STUN_TIME + Carrier.CHARGE_FULL_TIME
	_log("stun + a full charge  %.1f s = %.1f%%   (the slipper returns with them, §6)"
		% [to_throw, 100.0 * to_throw / RoundManagerScript.ROUND_TIME])
	_log("⚠️ the taya gets +100; the attacker loses ~%.0f%% of one round's throwing."
		% [100.0 * to_throw / RoundManagerScript.ROUND_TIME])

func _tag_reach(taya: CharacterBase, victim: CharacterBase, crossing: bool) -> float:
	var best := 0.0
	for step_index in range(19):
		var distance := 0.6 + 0.2 * float(step_index)
		if await _tag_lands(taya, victim, distance, crossing):
			best = distance
	return best

func _tag_lands(taya: CharacterBase, victim: CharacterBase, distance: float,
		crossing: bool) -> bool:
	var taya_brain: Puppet = _puppets[taya.player_slot]
	var victim_brain: Puppet = _puppets[victim.player_slot]
	_release(taya_brain)
	_release(victim_brain)
	var lata := RoundManager.lata
	if lata == null:
		return false
	lata.host_reset_for_new_round()

	var origin := Vector3(0.0, taya.global_position.y, 0.0)
	_place(taya, origin + Vector3(0.0, 0.0, 2.5))
	_place(victim, origin + Vector3(0.0, 0.0, 2.5 - distance))
	var slipper := _slipper_for(victim)
	if slipper != null:
		slipper.host_reset_for_new_round()
		slipper.host_assign_owner(victim.player_slot)
		slipper.global_position = victim.global_position
		await get_tree().physics_frame
		slipper.host_grab(victim)
	await get_tree().physics_frame
	if not victim.is_taggable():
		return false

	var hits := [false]
	var seen := func(_defender_slot: int, victim_slot: int) -> void:
		if victim_slot == victim.player_slot:
			hits[0] = true
	RoundManager.attacker_tagged.connect(seen)

	taya_brain.press["lunge"] = true
	await _face_by_walking(taya, taya_brain, victim.global_position,
		int(ceil(CharacterBase.LUNGE_CHARGE_TIME / _step())) + 6)
	if crossing:
		victim_brain.press["move_right"] = true
	taya_brain.press["lunge"] = false
	for _i in range(int(ceil(CharacterBase.LUNGE_ACTIVE_TIME / _step())) + 30):
		_hold_puppets()
		await get_tree().physics_frame
		if bool(hits[0]):
			break
	RoundManager.attacker_tagged.disconnect(seen)
	_release(taya_brain)
	_release(victim_brain)
	victim.global_position = victim.spawn_position
	victim.velocity = Vector3.ZERO
	for _i in range(int(ceil(RoundManagerScript.TAG_STUN_TIME / _step())) + 10):
		await get_tree().physics_frame
		if victim.state == CharacterBase.State.NORMAL:
			break
	return bool(hits[0])

func _slipper_for(who: CharacterBase) -> Slipper:
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper != null and slipper.owner_slot == who.player_slot:
			return slipper
	for node in get_tree().get_nodes_in_group("slippers"):
		return node as Slipper
	return null

func _measure_aim(who: CharacterBase) -> void:
	_log("")
	_log("--- §2.16  the dotted arc vs the flight  (tolerance %.2f m) ---" % AIM_TOLERANCE)
	var slipper := _slipper_for(who)
	if slipper == null:
		_failures.append("HARNESS: no slipper to aim with.")
		return
	var brain: Puppet = _puppets[who.player_slot]
	_release(brain)
	_clear_bench(who)
	await get_tree().physics_frame

	for index in range(CharacterRoster.SLIPPERS.size()):
		var entry: Dictionary = CharacterRoster.SLIPPERS[index]
		var lane_x := 4.0
		var origin := Vector3(lane_x, 1.4, 9.0)
		var target := Vector3(lane_x, 0.15, 0.0)
		_place(who, Vector3(lane_x, who.global_position.y, 9.6))
		slipper.host_reset_for_new_round()
		slipper.apply_skin(index)
		slipper.host_assign_owner(who.player_slot)
		slipper.global_position = origin
		await get_tree().physics_frame
		slipper.host_grab(who)
		await get_tree().physics_frame
		var velocity := Slipper.launch_velocity_for(origin, target, 1.0, slipper.speed_scale())
		var predicted := _integrate_like_preview(origin, velocity)
		slipper.host_throw(who, origin, target, 1.0)
		for _i in range(1200):
			await get_tree().physics_frame
			if not slipper.is_flying():
				break
		var observed := slipper.global_position
		var miss := Vector2(observed.x - predicted.x, observed.z - predicted.z).length()
		var ok := miss <= AIM_TOLERANCE
		_log("%-9s speed x%.2f  predicted z %6.2f  observed z %6.2f  miss %.3f m  %s"
			% [String(entry.get("name", "?")), slipper.speed_scale(),
				predicted.z, observed.z, miss, "OK" if ok else "FAIL"])
		if not ok:
			_failures.append(("§2.16 %s: the preview predicts z %.2f and the slipper lands "
				+ "z %.2f — %.3f m apart, over the %.2f m tolerance.")
				% [String(entry.get("name", "?")), predicted.z, observed.z, miss,
					AIM_TOLERANCE])

func _integrate_like_preview(origin: Vector3, velocity: Vector3) -> Vector3:
	var step := _step()
	var position := origin
	var motion := velocity
	var floor_y: float = 0.1
	if RoundManager.lata != null:
		floor_y = RoundManager.lata.global_position.y
	for _i in range(int(ceil(TrajectoryPreview.HORIZON / step))):
		motion.y -= CharacterBase.GRAVITY * step
		position += motion * step
		if position.y <= floor_y + Slipper.REST_HEIGHT:
			break
	return position

func _report() -> void:
	if _done:
		return
	_done = true
	print("")
	print("================ MECH PROBE — the numbers nobody had measured ================")
	for line in _lines:
		print(line)
	print("")
	if _failures.is_empty():
		print("RESULT: PASS")
		get_tree().quit(0)
		return
	print("RESULT: FAIL — %d check(s)" % _failures.size())
	for line in _failures:
		print("  * " + line)
	get_tree().quit(1)

