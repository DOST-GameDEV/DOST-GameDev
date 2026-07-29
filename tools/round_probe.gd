extends Node3D
## ROUND TRANSITION AUDIT — "whenever a round ends, players get launched to
## multiple directions" (user report, 2026-07-29).
##
## Drives several round transitions back to back and measures, for every
## character, whether it MOVES AT ALL between the round ending and the next one
## starting. Between rounds every unit is teleported to its role spawn marker
## (main.gd::_reset_world) and is supposed to stay there; any motion at all in
## that window is the bug.
##
## ⚠️ EVERY AI CONTROLLER IS DISABLED. This is the difference between a probe
## that measures the engine and one that measures the bots: a bot walking at
## SPEED (6.0) or launching a slipper at 26.0 is indistinguishable from a
## physics launch in a raw velocity sample. With the controllers off, ANY
## nonzero speed around a transition is the engine.
##
## ⚠️ IT DELIBERATELY FIRES AN IMPULSE INTO THE FROZEN GAP. Simply letting the
## rounds tick over reports a clean pass even when the bug is present — the
## reset itself was never the problem. What breaks is an impulse ARRIVING during
## the gap, and there are two routine sources of one: the round-winning tag
## applies knockback in the same frame it ends the round, and networked,
## `_apply_hit_result` is an rpc_id to the struck peer that can land frames
## after the reset has already teleported everyone home. The probe reproduces
## exactly that.
##
##   godot --path . tools/round_probe.tscn
##
## Never `--headless` — same rule as smoke-gate 3 and 4.

## How many round transitions to drive.
const TRANSITIONS: int = 6
## Impulse fired into the frozen gap, in m/s. Deliberately large and diagonal so
## a failure is unmistakable and obviously not gravity.
const PROBE_IMPULSE := Vector3(9.0, 4.0, 4.0)
## Speed below which a character counts as genuinely stationary.
const STILL_EPSILON: float = 0.15
## How far a character may drift from where the reset parked it before it counts
## as having moved. Generous enough to absorb the spawn-settle transform write.
const DRIFT_EPSILON: float = 0.10

var _main: Node
var _roster: Array[CharacterBase] = []
var _max_speed: Dictionary = {}
var _max_drift: Dictionary = {}
## Where each character was on the first frozen frame of the current gap — the
## control for the drift number. ⚠️ NOT `spawn_position`: _reset_world() rewrites
## that field mid-transition, so measuring against it reports the marker moving
## rather than the character moving, which is how the first version of this
## probe produced a meaningless 1.65 m "drift" on a run where nothing moved.
var _anchor: Dictionary = {}
var _was_active: bool = false
var _transitions_done: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	for c in _main.find_children("*", "CharacterBase", true, false):
		var character := c as CharacterBase
		if character.ai_controller != null:
			character.ai_controller.set_enabled(false)
		_roster.append(character)
		_max_speed[character] = 0.0
		_max_drift[character] = 0.0
	MatchManager.begin_next_round()
	await get_tree().create_timer(0.5).timeout
	set_physics_process(true)

	for i in TRANSITIONS:
		await get_tree().create_timer(1.5).timeout
		RoundManager.report_round_win(i % 2 == 0)
		_transitions_done += 1
		# Two frames in: past _reset_world(), squarely inside the frozen gap.
		await get_tree().physics_frame
		await get_tree().physics_frame
		for c in _roster:
			if is_instance_valid(c):
				c.apply_knockback(PROBE_IMPULSE)
		await get_tree().create_timer(4.5).timeout
	_report()
	get_tree().quit(0)

func _physics_process(_delta: float) -> void:
	var active := RoundManager.round_active
	var in_gap := not active and MatchManager.round_number > 0
	if not in_gap:
		_was_active = active
		if active:
			_anchor.clear()
		return
	for c in _roster:
		if not is_instance_valid(c):
			continue
		# ⚠️ SKIP A PROP THAT CARRIABLE IS DRIVING. _reset_world() ends by having
		# the attacker grab its own tsinelas (the round opens with it in hand,
		# per Dev_Plan §3), and _step_carried() then snaps that Prop to the
		# hand every physics frame. That is a legitimate, intended teleport of
		# ~1.65 m with zero velocity — the first version of this probe reported
		# it as drift and failed a run in which nothing was actually wrong.
		var carriable := c.get_node_or_null("Carriable") as Carriable
		if carriable != null and carriable.drives_movement():
			_anchor.erase(c)
			continue
		# First frozen frame of this gap: anchor here, after _reset_world has
		# already teleported everyone.
		if not _anchor.has(c):
			_anchor[c] = c.global_position
		_max_speed[c] = maxf(_max_speed[c], c.velocity.length())
		_max_drift[c] = maxf(_max_drift[c], (c.global_position - _anchor[c] as Vector3).length())
	_was_active = active

func _report() -> void:
	print("\n=== ROUND TRANSITION AUDIT (%d transitions, impulse %s fired into each gap) ==="
		% [_transitions_done, PROBE_IMPULSE])
	var worst_speed := 0.0
	var worst_drift := 0.0
	for c in _roster:
		worst_speed = maxf(worst_speed, _max_speed[c])
		worst_drift = maxf(worst_drift, _max_drift[c])
		print("  %-14s max speed in gap %6.2f m/s   max drift from reset spot %5.2f m"
			% [c.name, _max_speed[c], _max_drift[c]])
	var ok := worst_speed < STILL_EPSILON and worst_drift < DRIFT_EPSILON
	print("  VERDICT: %s" % ("PASS — every character stayed exactly where the reset put it"
		if ok else "*** FAIL — characters move between rounds (worst %.2f m/s, %.2f m) ***"
			% [worst_speed, worst_drift]))
