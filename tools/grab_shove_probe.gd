extends Node
## DOES PICKING UP A SLIPPER ALSO FIRE A SHOVE?
##
##     godot --headless --path <repo> tools/grab_shove_probe.tscn
##
## 🧑 2026-08-07: *"when trying to pick up a slipper, it accidentally triggers shove
## since both keybind is left click."*
##
## ⚠️ NOT A KEYBIND COLLISION. `grab` (E/LMB) and `special_ability` (Q/LMB) sharing
## LMB is a different, already-documented trade-off — `settings_manager.gd` calls it
## out as "a separate open question on §4.19", and that is the throw, not the shove.
## This bug is `carrier.gd::is_busy()` never being told a grab had just fired: a throw
## charge sets `_is_charging`, the lata channel sets `_channelling`, and a grab set
## NEITHER — so on the exact physics frame a grab connected, `_step_shove()`'s
## `is_busy()` guard read false and the very same `input_just_pressed("grab")` it
## re-reads fired a shove too. See `carrier.gd`'s `_grab_consumed_this_frame` for the
## fix.
##
## ⚠️⚠️ EVERY UNIT IS PUPPETED, the same shape `mech_probe` uses and for the identical
## reason: the shipping `AIController` re-asserts itself on a schedule
## (`main.gd::_reassert_spectated_bots()`), and a live bot deciding to move at the
## same moment as the measured press would make "was pushed" and "walked" read
## identically. The `Puppet` here presses exactly what this probe tells it to,
## through the same `ai_set_intent()` a human's keyboard feeds.

class Puppet extends AIController:
	var press: Dictionary = {}
	func decide(_delta: float) -> void:
		if character == null or not is_instance_valid(character):
			return
		for action in ["grab"]:
			character.ai_set_intent(action, bool(press.get(action, false)))

var _fails: int = 0
var _puppets: Dictionary = {}
var _main: Node = null

func _ready() -> void:
	GameLaunch.spectator = true
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(2.5).timeout
	if not await _wait_for_round():
		_check("HARNESS: the match reached a live round", false)
		_finish()
		return

	var grabber: CharacterBase = null
	var bystander: CharacterBase = null
	for node in _main.find_children("*", "CharacterBase", true, false):
		var c := node as CharacterBase
		if c == null or not c.is_person or c.is_defender:
			continue
		if grabber == null:
			grabber = c
		elif bystander == null:
			bystander = c
	_check("found two attackers", grabber != null and bystander != null)
	if grabber == null or bystander == null:
		_finish()
		return

	var brain := _puppet(grabber)
	# ⚠️ THE BYSTANDER IS PUPPETED TOO, HELD IDLE. Only the grabber was pinned in the
	# first draft of this probe, and it failed on a false positive: the bystander's
	# own shipping AI walked off toward its own objective in the frames this awaited,
	# drift that had nothing to do with a shove. A displacement check is only a
	# measurement of THE SHOVE if nothing else in the scene is free to move.
	_puppet(bystander)
	# ⚠️ SETTLED BEFORE ANYTHING IS STAGED, NOT AFTER. `main.gd::_reassert_spectated_bots()`
	# runs on its own schedule (partly `call_deferred`) around round start, and a position
	# assigned before it has finished running was seen to get overwritten once, one probe
	# run in five — a harness race, not the bug under test. Positions are captured only
	# after this window, so nothing deferred is still in flight when the measurement starts.
	for _i in range(40):
		await get_tree().physics_frame

	# The bystander stands where a shove would reach — directly in front of the
	# grabber, inside SHOVE_RANGE. If the bug is alive, picking up the slipper at the
	# grabber's own feet also shoves this bystander backward.
	var origin := Vector3(0.0, grabber.global_position.y, 0.0)
	grabber.global_position = origin
	grabber.velocity = Vector3.ZERO
	grabber.rotation.y = 0.0 # facing -Z, same convention `mech_probe` uses
	bystander.global_position = origin + Vector3(0.0, 0.0, -1.0)
	bystander.velocity = Vector3.ZERO
	for _i in range(10):
		await get_tree().physics_frame
	var bystander_start := bystander.global_position

	var slipper := _loose_slipper_near(grabber)
	_check("a loose slipper exists to pick up", slipper != null)
	if slipper == null:
		_finish()
		return
	slipper.host_reset_for_new_round()
	slipper.host_assign_owner(grabber.player_slot)
	slipper.global_position = grabber.global_position
	for _i in range(5):
		await get_tree().physics_frame

	_check("grabber starts empty-handed", not grabber.holding_slipper())
	_check("grabber's shove is off cooldown",
		not (float(grabber.get("_shove_cooldown_left")) > 0.0))
	var stamina_before := float(grabber.get("_stamina"))

	# The one press, as an edge: false then true is what makes it register JUST
	# pressed, exactly like a real key going down.
	brain.press["grab"] = false
	await get_tree().physics_frame
	brain.press["grab"] = true
	await get_tree().physics_frame
	brain.press["grab"] = false
	for _i in range(5):
		await get_tree().physics_frame

	print("§ one grab press")
	_check("the grab connected", grabber.holding_slipper())
	# ⚠️ THE WHOLE BUG. On the broken build the shove ALSO fires this frame: the
	# bystander gets knocked back and the grabber's shove goes on cooldown, for a
	# press that only asked to pick something up.
	_check("the shove did NOT also fire (cooldown still clear)",
		not (float(grabber.get("_shove_cooldown_left")) > 0.0))
	_check("the bystander was not pushed (%.3f m)" % bystander.global_position.distance_to(
		bystander_start), bystander.global_position.distance_to(bystander_start) < 0.05)
	# ⚠️ EXACT, NOT A THRESHOLD. `STAMINA_MAX` (60) comfortably clears
	# `SHOVE_STAMINA_COST` (25) even after one shove spends it, so "still >= the cost"
	# never actually caught a spend — measured: it read PASS on the reverted, buggy
	# build right alongside the cooldown and push checks correctly failing. Equality
	# against the pre-press value is what a NO-OP shove actually looks like.
	_check("the grabber's stamina is untouched (%.1f -> %.1f)"
		% [stamina_before, float(grabber.get("_stamina"))],
		is_equal_approx(float(grabber.get("_stamina")), stamina_before))

	_finish()

func _physics_process(_delta: float) -> void:
	for slot in _puppets.keys():
		var brain = _puppets[slot]
		if not is_instance_valid(brain):
			continue
		var who := RoundManager.player_at(int(slot))
		if who != null and who.ai_controller != brain:
			who.ai_controller = brain

func _puppet(who: CharacterBase) -> Puppet:
	var original := who.ai_controller
	if original != null:
		original.set_enabled(false)
	var brain := Puppet.new()
	brain.name = "GrabShoveProbePuppet"
	who.add_child(brain)
	who.ai_controller = brain
	who.ai_clear_intent()
	_puppets[who.player_slot] = brain
	return brain

func _loose_slipper_near(who: CharacterBase) -> Slipper:
	var best: Slipper = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null:
			continue
		var dist := slipper.global_position.distance_to(who.global_position)
		if dist < best_dist:
			best_dist = dist
			best = slipper
	return best

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
	print("[grab/shove probe] %s" % ("ALL CHECKS PASSED" if _fails == 0
		else "*** %d FAILED ***" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)
