extends Node3D
const ROUNDS := 5
var _main: Node
var _round := 0
var _fails := 0
var _label := ""

func _ready() -> void:
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	for i in ROUNDS:
		MatchManager.begin_next_round()
		_label = "IMMEDIATE"
		_sample()
		await get_tree().physics_frame
		await get_tree().physics_frame
		_label = "+2 frames"
		_sample()
	print("\n=== RESULT: ", "ALL SPAWNS CORRECT" if _fails == 0 else "%d FAILURES" % _fails, " ===")
	get_tree().quit(0)

func _sample() -> void:
	_round += 1
	print("\n--- round %d (team_a_is_can=%s) ---" % [_round, str(MatchManager.team_a_is_can)])
	var can: CharacterBase = null
	var attacker: CharacterBase = null
	var taya: CharacterBase = null
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.is_can: can = ch
		elif ch.is_person and ch.team_is_can_side: taya = ch
		elif ch.is_person: attacker = ch
	for pair in [["CAN", can], ["TAYA", taya], ["ATTACKER", attacker]]:
		var label: String = pair[0]
		var ch: CharacterBase = pair[1]
		if ch == null:
			print("   %-9s MISSING" % label); _fails += 1; continue
		print("   %-9s %-13s pos=(%6.2f,%6.2f) yaw=%7.1f" % [
			label, ch.name, ch.global_position.x, ch.global_position.z,
			rad_to_deg(ch.rotation.y)])
	if attacker == null or can == null:
		return
	var forward := Vector3(0, 0, -1).rotated(Vector3.UP, attacker.rotation.y)
	var to_can := can.global_position - attacker.global_position
	to_can.y = 0.0
	var dot := forward.normalized().dot(to_can.normalized())
	var deg := rad_to_deg(acos(clampf(dot, -1.0, 1.0)))
	var ok: bool = deg < 30.0
	print("   attacker->can  off-axis %.1f deg   %s" % [deg, "OK" if ok else "*** FACING WRONG ***"])
	if not ok:
		_fails += 1
	var d := Vector2(attacker.global_position.x - can.global_position.x,
		attacker.global_position.z - can.global_position.z).length()
	var outside: bool = d > CharacterBase.CONFINEMENT_RADIUS
	print("   attacker->can  distance %.2f  (confinement %.1f)  %s" % [
		d, CharacterBase.CONFINEMENT_RADIUS, "OK" if outside else "*** INSIDE THE BOX ***"])
	if not outside:
		_fails += 1

