extends Node3D

var _main: Node
var _pass: int = 0
var _fail: int = 0

func _pending() -> Dictionary:
	var value: Variant = _main.get("_pending_reclaims")
	return value if value is Dictionary else {}

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  %s  %s%s" % ["PASS" if ok else "FAIL", label, ("   " + detail) if detail != "" else ""])

func _ready() -> void:
	print("=== REJOIN ACCEPTANCE (the reclaim/spawn race) ===")
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout

	var peer_id := multiplayer.get_unique_id()
	var index_to_character: Dictionary = _main.get("_index_to_character")
	var index := 3
	while index_to_character.has(index) and index < 4:
		index += 1
	if index >= 4:
		print("  HARNESS: every seat already built; cannot stage the race.")
		get_tree().quit(1)
		return

	_main.call("_rpc_reclaim_character", index, peer_id)
	var pending := _pending()
	_check("a reclaim for an unknown seat is REMEMBERED, not dropped",
		pending.has(index) and int(pending[index]) == peer_id,
		"_pending_reclaims=%s" % str(pending))

	var data: Dictionary = _main.call("_build_spawn_data", peer_id, index)
	var character: CharacterBase = _main.call("_build_networked_character", data)
	if character == null:
		print("  HARNESS: spawn function returned null.")
		get_tree().quit(1)
		return
	var players := _main.get_node_or_null("Players")
	(players if players != null else _main).add_child(character)
	pending = _pending()
	_check("the remembered reclaim is CONSUMED when that seat turns up",
		not pending.has(index), "_pending_reclaims=%s" % str(pending))

	await get_tree().process_frame
	await get_tree().process_frame

	_check("the rejoining peer OWNS the character",
		character.get_multiplayer_authority() == peer_id,
		"authority=%d want=%d" % [character.get_multiplayer_authority(), peer_id])

	var rig := character.get_node_or_null("CameraRig")
	var rig_active: bool = rig != null and bool(rig.get("_active"))
	var looking_through := false
	if rig != null:
		var fpp := rig.get("fpp_camera") as Camera3D
		var tpp := rig.get("tpp_camera") as Camera3D
		looking_through = (fpp != null and fpp.current) or (tpp != null and tpp.current)
	_check("and is LOOKING THROUGH it — this is the blank screen",
		rig_active and looking_through,
		"rig_active=%s camera_current=%s" % [str(rig_active), str(looking_through)])

	print("=== REJOIN PROBE: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

