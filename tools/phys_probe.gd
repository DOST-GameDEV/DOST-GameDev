extends Node3D
## Physics/interaction audit. Throws the tsinelas at the can repeatedly and
## reports whether contact is actually detected, plus watches for the failure
## modes reported 2026-07-29: clipping through the floor, snagging on invisible
## walls, and weird bounces.
var _main: Node
var _slipper: CharacterBase
var _can: CharacterBase
var _min_y := 999.0
var _max_speed := 0.0
var _below_floor := 0
var _outside_bounds := 0
var _frames := 0
var _throws := 0
var _state_hits := 0
var _dents_seen := 0
var _attacker: CharacterBase

func _ready() -> void:
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	MatchManager.begin_next_round()
	await get_tree().create_timer(0.5).timeout
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.is_can: _can = ch
		elif not ch.is_person and not ch.is_can: _slipper = ch
		elif ch.is_person and not ch.team_is_can_side: _attacker = ch
	if _slipper == null or _can == null:
		print("PHYS: could not find slipper/can"); get_tree().quit(1); return
	print("slipper=", _slipper.name, " can=", _can.name)
	set_physics_process(true)
	# Fire a series of throws straight at the can from the throwing line.
	for i in 12:
		var carriable := _slipper.get_node("Carriable") as Carriable
		# host_throw() requires CARRIED, so go through the real path: put the
		# slipper loose next to its own attacker, have the attacker grab it,
		# then throw. Anything else tests a state the game never reaches.
		carriable.host_land()
		_slipper.global_position = _attacker.global_position + Vector3(0.4, 0.3, 0)
		await get_tree().physics_frame
		carriable.host_grab(_attacker)
		await get_tree().physics_frame
		if carriable.state != Carriable.CarryState.CARRIED:
			print("  throw %d: grab failed, state=%d" % [i, carriable.state])
			continue
		var dir := (_can.global_position + Vector3(0, 0.25, 0)) - _slipper.global_position
		carriable.host_throw(dir.normalized(), 1.0)
		_throws += 1
		await get_tree().create_timer(1.2).timeout
	print("\n=== PHYSICS AUDIT (%d frames) ===" % _frames)
	print("  lowest slipper Y reached : %.3f  (floor top is 0.100)" % _min_y)
	print("  frames below floor       : %d" % _below_floor)
	print("  frames outside map bounds: %d" % _outside_bounds)
	print("  peak slipper speed       : %.2f" % _max_speed)
	print("  throws actually launched : %d" % _throws)
	print("  can dents                : %d / %d" % [_can.dents, CharacterBase.MAX_DENTS])
	print("  mode                     : %s" % ("OPTION_A (dents)" if GameLaunch.game_mode == GameLaunch.GameMode.OPTION_A else "OPTION_B (downed/seal)"))
	print("  frames can was NOT NORMAL: %d" % _state_hits)
	print("  can final state          : %d (0=NORMAL 1=STAGGERED 2=DOWNED 3=SEALED)" % _can.state)
	print("  RESULT: ", "CONTACT RESOLVES" if (_dents_seen > 0 or _state_hits > 0) else "*** NO CONTACT EVER REGISTERED ***")
	get_tree().quit(0)

func _physics_process(_d: float) -> void:
	if _slipper == null: return
	_frames += 1
	var p := _slipper.global_position
	_min_y = minf(_min_y, p.y)
	_max_speed = maxf(_max_speed, _slipper.velocity.length())
	if p.y < 0.0: _below_floor += 1
	if absf(p.x) > 9.5 or absf(p.z) > 19.0: _outside_bounds += 1
	if _can != null and _can.dents > _dents_seen: _dents_seen = _can.dents
	if _can != null and _can.state != 0: _state_hits += 1
