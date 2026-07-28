extends Node3D
## Proves the bots are INDEPENDENT and never freeze.
##
## Two reported symptoms, two measurements:
##   a) "they all move together at the exact same time in sync" -> sample every
##      AI unit's velocity each frame and report how often two of them start or
##      stop on the SAME frame. Lockstep bots score near 1.0.
##   b) "they randomly stop and freeze completely" -> report the longest
##      consecutive run of near-zero velocity per bot over the whole sample.
const SECONDS := 14.0
var _main: Node
var _bots: Array = []
var _moving: Dictionary = {}
var _still_run: Dictionary = {}
var _still_max: Dictionary = {}
var _transitions: Dictionary = {}
var _same_frame := 0
var _frames := 0
var _t := 0.0

func _ready() -> void:
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	# ⚠️ START THE ROUND. Bots are measured under real match conditions, not in
	# the pre-round free-roam window — several role behaviours key off
	# RoundManager's tracked cans, which do not exist until a round begins.
	MatchManager.begin_next_round()
	await get_tree().create_timer(1.0).timeout
	print("round_active=", RoundManager.round_active, " round=", MatchManager.round_number)
	for c in _main.find_children("*", "CharacterBase", true, false):
		if c.ai_controller != null:
			_bots.append(c)
			_moving[c] = false
			_still_run[c] = 0
			_still_max[c] = 0
			_transitions[c] = 0
	print("AI units found: ", _bots.size())
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if _bots.is_empty():
		return
	_t += delta
	_frames += 1
	var changed := 0
	for c in _bots:
		var v: float = Vector2(c.velocity.x, c.velocity.z).length()
		var now_moving: bool = v > 0.35
		if now_moving != _moving[c]:
			changed += 1
			_transitions[c] += 1
			_moving[c] = now_moving
		if now_moving:
			_still_run[c] = 0
		else:
			_still_run[c] += 1
			_still_max[c] = maxi(_still_max[c], _still_run[c])
	if changed >= 2:
		_same_frame += 1
	if _t < SECONDS:
		return
	set_physics_process(false)
	print("\n=== AI INDEPENDENCE / FREEZE AUDIT (", _frames, " physics frames) ===")
	var total_tr := 0
	for c in _bots:
		total_tr += _transitions[c]
		print("  %-14s start/stop transitions %3d   longest still run %4d frames (%.2fs)"
			% [c.name, _transitions[c], _still_max[c], _still_max[c] / 60.0])
	print("  frames where 2+ bots changed state together: %d / %d  (%.1f%%)"
		% [_same_frame, _frames, 100.0 * _same_frame / maxi(_frames, 1)])
	print("  total transitions across all bots: ", total_tr,
		"  -> ", "FROZEN" if total_tr < 4 else "active")
	get_tree().quit(0)
