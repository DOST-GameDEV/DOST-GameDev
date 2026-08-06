extends Node3D

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

const SCALE: float = 3.0
const VICTIM_RADIUS: float = 2.2

var _victim_kind: String = "human"
var _secs: float = 25.0
var _tier: String = "NORMAL"

var _main: Node = null
var _victim: CharacterBase = null
var _taya: CharacterBase = null
var _elapsed: float = 0.0
var _running: bool = false
var _tags: int = 0
var _tag_log: Array[String] = []

var _f_total: int = 0
var _f_taggable: int = 0
var _f_holding: int = 0
var _f_inside: int = 0
var _f_can_act: int = 0
var _f_lata_up: int = 0
var _f_punch_range: int = 0
var _f_punch_facing: int = 0
var _f_punch_ready: int = 0
var _f_taya_hunting: int = 0
var _f_special_held: int = 0
var _f_special_edge: int = 0
var _f_lunge_held: int = 0
var _f_lunge_edge: int = 0
var _plans: Dictionary = {}
var _min_distance: float = INF


func _ready() -> void:
	for raw in OS.get_cmdline_user_args():
		var arg := String(raw)
		if arg.begins_with("victim="):
			_victim_kind = arg.substr(7)
		elif arg.begins_with("secs="):
			_secs = float(arg.substr(5))
		elif arg.begins_with("tier="):
			_tier = arg.substr(5)
	print("[tag_probe] victim=%s secs=%.0f tier=%s" % [_victim_kind, _secs, _tier])
	Engine.time_scale = SCALE
	GameLaunch.spectator = false
	GameLaunch.solo_seat = 1
	AIController.apply_difficulty(_tier_enum())
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_boot.call_deferred()


func _tier_enum() -> AIController.Difficulty:
	match _tier.to_upper():
		"EASY", "BATA":
			return AIController.Difficulty.BATA
		"HARD", "ASTIG":
			return AIController.Difficulty.ASTIG
		_:
			return AIController.Difficulty.NORMAL


func _boot() -> void:
	await get_tree().create_timer(1.5).timeout
	if _main.has_method("_run_ready_countdown"):
		_main._run_ready_countdown()
	await get_tree().create_timer(4.5).timeout
	_victim = RoundManager.player_at(1)
	_taya = RoundManager.defender()
	if _victim == null or _taya == null:
		print("[tag_probe] FAIL: could not resolve seats")
		_finish(2)
		return
	print("[tag_probe] victim seat=%d ai_controller=%s | taya seat=%d ai_controller=%s"
		% [_victim.player_slot, _victim.ai_controller != null,
		   _taya.player_slot, _taya.ai_controller != null])
	if _victim_kind == "bot":
		_victim = RoundManager.player_at(2)
		if _victim == null:
			print("[tag_probe] FAIL: no seat 2")
			_finish(2)
			return
		if _victim.ai_controller != null:
			_victim.ai_controller.set_process(false)
			_victim.ai_controller.set_physics_process(false)
		print("[tag_probe] control run: victim moved to seat %d (ai_controller=%s, silenced)"
			% [_victim.player_slot, _victim.ai_controller != null])
	RoundManager.attacker_tagged.connect(_on_tagged)
	_running = true


func _on_tagged(defender_slot: int, victim_slot: int) -> void:
	if victim_slot != _victim.player_slot:
		return
	_tags += 1
	_tag_log.append("t=%.1fs  taya P%d tagged P%d" % [_elapsed, defender_slot + 1, victim_slot + 1])


func _physics_process(delta: float) -> void:
	if not _running:
		return
	if not is_instance_valid(_victim) or not is_instance_valid(_taya):
		return
	_elapsed += delta
	if _elapsed >= _secs:
		_report()
		return

	var lata := RoundManager.lata
	if lata != null and not lata.is_upright:
		lata.host_restore()

	if lata != null:
		var mark: Vector3 = lata.global_position + Vector3(VICTIM_RADIUS, 0.0, 0.0)
		mark.y = _victim.global_position.y
		_victim.global_position = mark
		_victim.velocity = Vector3.ZERO
	if not _victim.holding_slipper():
		_arm_victim()

	_sample()


func _arm_victim() -> void:
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null or slipper.is_flying():
			continue
		if slipper.carrier_slot() >= 0:
			continue
		slipper.global_position = _victim.global_position
		slipper.host_assign_owner(_victim.player_slot)
		if slipper.can_be_grabbed_by(_victim):
			slipper.host_grab(_victim)
		return


func _sample() -> void:
	_f_total += 1
	var lata := RoundManager.lata
	var lata_up: bool = lata != null and lata.is_upright
	if lata_up:
		_f_lata_up += 1
	if _victim.holding_slipper():
		_f_holding += 1
	if _victim.is_inside_box():
		_f_inside += 1
	if _victim.can_act():
		_f_can_act += 1
	if _victim.is_taggable():
		_f_taggable += 1

	var to_them: Vector3 = _victim.global_position - _taya.global_position
	to_them.y = 0.0
	var distance := to_them.length()
	_min_distance = minf(_min_distance, distance)
	if distance <= CharacterBase.PUNCH_RANGE:
		_f_punch_range += 1
	if distance > 0.01:
		var facing: Vector3 = -_taya.global_transform.basis.z
		facing.y = 0.0
		if facing.length() > 0.01:
			var angle := rad_to_deg(facing.normalized().angle_to(to_them.normalized()))
			if angle <= CharacterBase.PUNCH_ARC_DEG:
				_f_punch_facing += 1
	if _taya.punch_cooldown_left() <= 0.0:
		_f_punch_ready += 1
	if _taya.ai_controller != null:
		var plan: String = _taya.ai_controller.current_plan()
		_plans[plan] = int(_plans.get(plan, 0)) + 1
		if plan == "HUNT":
			_f_taya_hunting += 1
	if _taya.input_pressed("special_ability"):
		_f_special_held += 1
	if _taya.input_just_pressed("special_ability"):
		_f_special_edge += 1
	if _taya.input_pressed("lunge"):
		_f_lunge_held += 1
	if _taya.input_just_pressed("lunge"):
		_f_lunge_edge += 1


func _pct(n: int) -> float:
	return 0.0 if _f_total == 0 else 100.0 * float(n) / float(_f_total)


func _report() -> void:
	_running = false
	print("")
	print("=== tag_probe: victim=%s, %d frames over %.1f game-seconds ===" % [_victim_kind, _f_total, _elapsed])
	print("  VICTIM SIDE (is_taggable() and its three terms)")
	print("    holding_slipper   %6.1f%%" % _pct(_f_holding))
	print("    is_inside_box     %6.1f%%" % _pct(_f_inside))
	print("    can_act           %6.1f%%" % _pct(_f_can_act))
	print("    is_taggable       %6.1f%%   <- the rule the tag reads" % _pct(_f_taggable))
	print("  RULE SIDE")
	print("    lata upright      %6.1f%%   <- no tag is legal while it is down" % _pct(_f_lata_up))
	print("  TAYA SIDE")
	print("    plan == HUNT      %6.1f%%" % _pct(_f_taya_hunting))
	print("    within PUNCH_RANGE(%.1fm) %6.1f%%" % [CharacterBase.PUNCH_RANGE, _pct(_f_punch_range)])
	print("    facing within arc %6.1f%%" % _pct(_f_punch_facing))
	print("    punch off cooldown%6.1f%%" % _pct(_f_punch_ready))
	print("    closest approach  %6.2f m" % _min_distance)
	print("  TAYA'S ACTUAL BUTTON PRESSES (the intent harness, as the character reads it)")
	print("    special_ability held   %6.1f%%   edges: %d" % [_pct(_f_special_held), _f_special_edge])
	print("    lunge held            %6.1f%%   edges: %d" % [_pct(_f_lunge_held), _f_lunge_edge])
	var plan_line := ""
	for key in _plans.keys():
		plan_line += "%s=%.0f%% " % [key, _pct(int(_plans[key]))]
	print("    plans: %s" % plan_line)
	print("  RESULT")
	print("    TAGS ON THIS VICTIM: %d" % _tags)
	for line in _tag_log:
		print("      " + line)
	var verdict := 0
	if _tags > 0:
		print("    >> tags landed, one roughly every %.1f s (TAG_STUN_TIME is %.1f)."
			% [_elapsed / float(_tags), RoundManager.TAG_STUN_TIME])
		_finish(0)
		return
	if _f_taggable < int(0.5 * float(_f_total)):
		print("    >> the victim was not taggable for most of the run; the pose failed, not the tag.")
		verdict = 3
	elif _tags == 0:
		print("    >> HELD TAGGABLE AND NEVER TAGGED. The taya columns above say which term failed.")
		verdict = 1
	else:
		print("    >> tags landed.")
	_finish(verdict)


func _finish(code: int) -> void:
	Engine.time_scale = 1.0
	await get_tree().process_frame
	get_tree().quit(code)

