extends Node3D
## PERCH ACCEPTANCE — "stuck in the air, can still move".
##
## 🧑 2026-07-31: *"jumping position bug, pic attached, can still move js stuck there"*,
## and then *"u didnt fix stuck in jump for multiplayer"*.
##
## ⚠️⚠️ WHY A SINGLE-PROCESS PROBE IS THE RIGHT TEST FOR A MULTIPLAYER BUG.
##
## The perch is resolved by the peer that OWNS the body. `_physics_process` returns early
## for a character this peer does not own (`if is_networked() and not
## is_multiplayer_authority(): return`), so gravity, `_move_and_confine()` and
## `_shed_character_perch()` all run on exactly one machine — the same one, running the
## same lines, whether the match is networked or not. What differs across the wire is
## only where the OTHER capsule's transform came from, and a replicated `CharacterBody3D`
## still carries a real collider in the local physics world. So standing one unit on
## another here exercises the identical path a rejoined LAN player walks.
##
## ⚠️ WHAT THIS DOES NOT COVER: ENet ordering, interpolation, or a body whose transform is
## being written by a `MultiplayerSynchronizer` mid-step. If the symptom survives on two
## real machines after this passes, the cause is one of those and NOT the floor test.
##
## THE CHECK. Park one unit, drop a second one onto its head, let physics run, and ask
## whether the top one came down. Pre-fix it rests there forever, because
## `is_on_floor()` is true for a capsule standing on a capsule and the gravity branch is
## skipped entirely.

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
		# Nothing must walk out from under the test.
		if character.ai_controller != null:
			character.ai_controller.set_enabled(false)
		character.input_parked = true
	if people.size() < 2:
		print("  HARNESS: needed two Persons, found %d." % people.size())
		get_tree().quit(1)
		return

	var support := people[0]
	var rider := people[1]
	# Stand the rider squarely on the support's head. `capsule_height()` is the unit's
	# own currently-applied shape, not a restated constant — see its note.
	# ⚠️ DROPPED FROM A GAP, NOT TELEPORTED ONTO IT — and the first version of this probe
	# got that wrong and reported a false PASS on BOTH builds. Placing the rider exactly
	# on the head starts the two capsules OVERLAPPING, so Godot's depenetration shoves
	# them apart on the next step and the rider comes down whatever the gravity branch
	# does. The test passed before the fix and after it, which means it was measuring
	# depenetration and not the bug. Landing on the head from above is the case a player
	# actually reaches by jumping, and it is the one that rests.
	var head := support.global_position
	head.y += support.capsule_height() + 0.5
	rider.velocity = Vector3.ZERO
	rider.global_position = head
	var support_y := support.global_position.y
	# Let it fall and settle first; `start_y` is where it comes to REST on the head, which
	# is the state being tested, not where it was released from.
	await get_tree().create_timer(1.0).timeout
	var start_y := rider.global_position.y

	await get_tree().create_timer(SETTLE_SECONDS).timeout

	var end_y := rider.global_position.y
	# ⚠️⚠️ THE MEASUREMENT IS AT ONE SECOND, NOT AT THE END, AND THAT CORRECTION IS THE
	# WHOLE VALUE OF THIS PROBE. Asserting on the FINAL position passed on both builds and
	# was therefore worthless: given long enough the two capsules drift apart and
	# depenetration brings the rider down even with the bug present. The defect is that it
	# RESTS there — measured pre-fix at y 1.90, exactly a support height above the support
	# at 0.90 — so the question is where it is one second after landing, not where it
	# eventually ends up. Post-fix it is at 1.05 and already on its way down.
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
