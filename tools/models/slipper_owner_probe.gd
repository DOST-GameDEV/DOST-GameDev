extends Node
## DOES EVERY SLIPPER KNOW WHOSE IT IS — IN ROUND 1, AND AFTER THE TAYA ROTATES?
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/models/slipper_owner_probe.tscn
##
## `Slipper.owner_slot` decides three shipped things, and every one of them fails
## SILENT or fails OPEN when it is -1:
##
##   · the foot arrow      `offscreen_indicators.gd` compares it to your own slot,
##                          so -1 never matches and the arrow never appears;
##   · the owner glow      `_update_owner_glow()` gates on `owner_slot >= 0`;
##   · **the rule itself**  `can_be_grabbed_by()` opens with `owner_slot >= 0`, so
##                          an unowned slipper is grabbable by ANY attacker —
##                          which is the exact rule `Design.md` §5.2 imposes.
##
## Nothing assigned the field until 2026-08-01: the only writers were the grab and
## the throw, so ownership rode entirely on `main.gd::_reset_slippers()`'s courtesy
## pickup landing — and that pickup can silently refuse, because
## `can_be_grabbed_by()` needs `can_act()`, which is `round_active and state ==
## NORMAL`, and a character mid-reset is neither.
##
## ⚠️ IT CHECKS THE ROTATION, NOT JUST ROUND 1, AND THAT IS THE HALF A ONE-ROUND
## TEST WOULD MISS. The taya rotates every round, so which three seats own
## slippers changes every round — and the OLD code could not re-assign at all: on
## round 2 the gate `owner_slot >= 0 and who.player_slot != owner_slot` refuses
## the new owner's pickup, because the slipper still holds round 1's slot. A test
## that stopped after round 1 would have passed that.

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

var _main: Node = null
var _log: PackedStringArray = []
var _failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()


func _emit(text: String) -> void:
	print(text)
	_log.append(text)


func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	if _main.has_method("_run_ready_countdown"):
		_main._run_ready_countdown()
	await get_tree().create_timer(5.0).timeout

	_check_round(MatchManager.defender_slot_for(1), "round 1")

	# ⚠️ DRIVEN THROUGH `_reset_world()`, WHICH IS THE FUNCTION UNDER TEST. Waiting
	# out a real 90 s round would measure the same code an hour later; this is the
	# exact call `_on_round_intermission_started` makes at every rotation.
	var next_defender := MatchManager.defender_slot_for(2)
	_emit("--- rotating the taya to slot %d ---" % next_defender)
	_main.call("_reset_world", next_defender)
	await get_tree().create_timer(1.5).timeout
	_check_round(next_defender, "round 2")

	_emit("")
	if _failures == 0:
		_emit("SLIPPER OWNER PROBE: PASS — every slipper is owned, and ownership rotates")
	else:
		_emit("SLIPPER OWNER PROBE: %d FAILURE(S)" % _failures)
	var file := FileAccess.open("user://slipper_owner_probe.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	get_tree().quit(0 if _failures == 0 else 1)


func _check_round(defender_slot: int, label: String) -> void:
	_emit("=== %s · taya is slot %d ===" % [label, defender_slot])
	var slippers: Array = _main.get("slippers")
	if slippers == null or slippers.is_empty():
		_fail("Main.tscn exposes no slippers")
		return

	var expected: Array[int] = []
	for slot in range(NetworkManagerScript.MAX_PLAYERS):
		if slot != defender_slot:
			expected.append(slot)

	var seen: Array[int] = []
	for slipper in slippers:
		if slipper == null or not is_instance_valid(slipper):
			continue
		var owner: int = slipper.owner_slot
		_emit("  %-10s owner_slot=%-3d state=%d" % [slipper.name, owner, slipper.state])
		if owner < 0:
			_fail("%s is unowned — the arrow, the glow and the ownership rule all "
				% slipper.name + "fail on -1")
			continue
		if owner == defender_slot:
			_fail("%s belongs to the TAYA, who cannot hold a slipper" % slipper.name)
		if owner in seen:
			_fail("%s shares its owner with another slipper" % slipper.name)
		seen.append(owner)

	seen.sort()
	if seen != expected:
		_fail("owners %s do not match the three attacker seats %s" % [seen, expected])
	else:
		_emit("  OK  the three attacker seats %s each own exactly one" % [expected])

	# The rule the field exists to enforce: nobody may take somebody else's.
	_check_rule_enforced(slippers, defender_slot)


## ⚠️ THE FIELD BEING SET IS NOT THE SAME CLAIM AS THE RULE HOLDING. Ask the
## game's own predicate, with a character who is not the owner.
func _check_rule_enforced(slippers: Array, defender_slot: int) -> void:
	var by_slot := {}
	for node in _main.find_children("*", "CharacterBase", true, false):
		var who := node as CharacterBase
		if who != null:
			by_slot[who.player_slot] = who
	for slipper in slippers:
		if slipper == null or not is_instance_valid(slipper) or slipper.owner_slot < 0:
			continue
		for slot in by_slot:
			if slot == slipper.owner_slot or slot == defender_slot:
				continue
			var other: CharacterBase = by_slot[slot]
			if slipper.can_be_grabbed_by(other):
				_fail("P%d can grab %s, which belongs to P%d"
					% [int(slot) + 1, slipper.name, int(slipper.owner_slot) + 1])
				return


func _fail(why: String) -> void:
	_emit("  FAIL  " + why)
	_failures += 1
