extends Node

var _fails: int = 0

func _ready() -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	if not await _wait_for_round():
		_check("HARNESS: the match reached a live round", false)
		_finish()
		return

	var taya: CharacterBase = null
	var victim: CharacterBase = null
	var shover: CharacterBase = null
	for node in main.find_children("*", "CharacterBase", true, false):
		var c := node as CharacterBase
		if c == null or not c.is_person:
			continue
		if c.is_defender:
			taya = c
		elif victim == null:
			victim = c
		elif shover == null:
			shover = c
	_check("found a taya", taya != null)
	_check("found two attackers", victim != null and shover != null)
	if taya == null or victim == null or shover == null:
		_finish()
		return

	var lata := RoundManager.lata
	if lata != null:
		lata.host_reset_for_new_round()

	var origin := Vector3(0.0, victim.global_position.y, 0.0)
	victim.global_position = origin + Vector3(0.0, 0.0, 1.0)
	taya.global_position = origin + Vector3(0.0, 0.0, 1.6)
	var slipper := _slipper_for(victim)
	if slipper != null:
		slipper.host_reset_for_new_round()
		slipper.host_assign_owner(victim.player_slot)
		slipper.global_position = victim.global_position
		await get_tree().physics_frame
		slipper.host_grab(victim)
	await get_tree().physics_frame

	print("§1 the baseline the rule was always right about")
	_check("an unstunned attacker in the box with a slipper IS taggable",
		victim.is_taggable())
	_check("...and is holding one", victim.holding_slipper())
	_check("...and is inside the box", victim.is_inside_box())

	print("§2 THE BUG — shoved, and still taggable")
	RoundManager.note_shove(victim.player_slot, shover.player_slot)
	victim.apply_stagger(CharacterBase.BASE_STAGGER_TIME * 8.0)
	await get_tree().physics_frame
	_check("the shove actually stunned them",
		victim.state == CharacterBase.State.STAGGERED)
	_check("they still hold the slipper (a stun does not drop it)",
		victim.holding_slipper())
	_check("they are still in the box", victim.is_inside_box())
	_check("A SABOTAGED (STAGGERED) ATTACKER IS TAGGABLE", victim.is_taggable())
	_check("can_act() is still false — the fix did not just widen can_act()",
		not victim.can_act())

	print("§3 the tag lands, and pays the saboteur")
	var taya_before := MatchManager.score_for(taya.player_slot)
	var shover_before := MatchManager.score_for(shover.player_slot)
	taya._sweep_lunge_tag()
	await get_tree().physics_frame
	var taya_gain := MatchManager.score_for(taya.player_slot) - taya_before
	var shover_gain := MatchManager.score_for(shover.player_slot) - shover_before
	_check("the taya scored the tag (%d)" % taya_gain,
		taya_gain == RoundManagerScript.SCORE_TAG)
	_check("the SHOVER scored the sabotage (%d)" % shover_gain,
		shover_gain == RoundManagerScript.SCORE_SABOTAGE)

	print("§4 and it cannot be cashed twice")
	await get_tree().physics_frame
	_check("the victim is still stunned after the tag",
		victim.state == CharacterBase.State.STAGGERED)
	_check("...but has been teleported out of the box", not victim.is_inside_box())
	_check("so a stunned, just-tagged victim is NOT taggable again",
		not victim.is_taggable())

	print("§5 every rule that was already correct still refuses")
	_check("the taya is never taggable", not taya.is_taggable())
	var far := _slipper_for(victim)
	if far != null:
		far.host_drop()
	await get_tree().physics_frame
	_check("an attacker with no slipper is not taggable",
		not victim.holding_slipper() and not victim.is_taggable())
	_finish()

func _slipper_for(who: CharacterBase) -> Slipper:
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper != null and slipper.owner_slot == who.player_slot:
			return slipper
	for node in get_tree().get_nodes_in_group("slippers"):
		return node as Slipper
	return null

func _wait_for_round() -> bool:
	for _warmup in range(30):
		await get_tree().physics_frame
	var press := InputEventAction.new()
	press.action = "ready_up"
	press.pressed = true
	Input.parse_input_event(press)
	for _i in range(3000):
		await get_tree().physics_frame
		if RoundManager.round_active and RoundManager.lata != null:
			for _j in range(10):
				await get_tree().physics_frame
			return true
	return false

func _check(what: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])

func _finish() -> void:
	print("[tag probe] %s" % ("ALL CHECKS PASSED" if _fails == 0
		else "*** %d FAILED ***" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)

