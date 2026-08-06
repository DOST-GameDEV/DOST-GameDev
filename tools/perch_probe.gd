extends Node3D

const SETTLE_SECONDS: float = 2.5

var _main: Node
var _pass: int = 0
var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  %s  %s%s" % ["PASS" if ok else "FAIL", label, ("   " + detail) if detail != "" else ""])

func _ready() -> void:
	print("=== PERCH ACCEPTANCE (standing on another unit) ===")
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	MatchManager.begin_next_round()
	await get_tree().create_timer(0.6).timeout

	var people: Array[CharacterBase] = []
	for node in _main.find_children("*", "CharacterBase", true, false):
		var character := node as CharacterBase
		if character.is_person:
			people.append(character)
		if character.ai_controller != null:
			character.ai_controller.set_enabled(false)
		character.input_parked = true
	if people.size() < 2:
		print("  HARNESS: needed two Persons, found %d." % people.size())
		get_tree().quit(1)
		return

	var support := people[0]
	var rider := people[1]
	var head := support.global_position
	head.y += support.capsule_height() + 0.5
	rider.velocity = Vector3.ZERO
	rider.global_position = head
	var support_y := support.global_position.y
	await get_tree().create_timer(1.0).timeout
	var start_y := rider.global_position.y

	await get_tree().create_timer(SETTLE_SECONDS).timeout

	var end_y := rider.global_position.y
	var perch_line := support_y + support.capsule_height() * 0.5
	var rested_on_head := start_y > perch_line
	_check("a unit that lands on another unit does NOT rest there",
		not rested_on_head,
		"y@1s=%.2f perch_line=%.2f support_y=%.2f final_y=%.2f" % [start_y, perch_line, support_y, end_y])
	_check("and gravity is still being applied to it while it is up there",
		not rested_on_head or rider.velocity.y < 0.0,
		"velocity.y=%.2f" % rider.velocity.y)

	print("=== PERCH PROBE: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

