extends Node3D
## B-122 diagnostic. Drives the COMBAT state machine directly and counts what
## it makes noise about.
##
##   godot --path . tools/audio_combat_probe.tscn --quit-after 1200
##
## WHY. audio_load_probe.gd measured a real match and reported a clean bill of
## health — but in that run nothing was ever knocked down (lata_impact fired
## once in 1800 frames, and no unit entered DOWNED or SEALED at all). So it
## measured the throw loop and never touched the stagger/downed/self-right path,
## which is most of what a human actually generates in a fight.
##
## This drives those transitions on purpose: repeated staggers, a knockdown, an
## early self-right, then more staggers. If a sound fires on a transition it has
## no business firing on, it shows up here as a count that should be zero.

var _starts: Dictionary = {}
var _last_playing: Dictionary = {}
var _last_pos: Dictionary = {}
var _units: Array[CharacterBase] = []
var _log: Array[String] = []


func _ready() -> void:
	var main: Node = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	MatchManager.begin_next_round()
	await get_tree().create_timer(0.5).timeout

	for node in get_tree().get_nodes_in_group("_none_"):
		pass
	_units.assign(_find_units(main))
	print("units found: %d" % _units.size())
	if _units.is_empty():
		get_tree().quit(1); return

	var unit := _units[0]
	print("driving: %s (is_can=%s is_person=%s)" % [unit.name, unit.is_can, unit.is_person])

	# 1. Three plain staggers on a NORMAL unit. Nothing about a stagger should
	#    make a recovery noise — the impact that caused it already sounded.
	await _phase("three staggers, no knockdown", func() -> void:
		for i in 3:
			unit.apply_stagger(0.25)
			await get_tree().create_timer(0.45).timeout)

	# 2. A knockdown, then an EARLY self-right (Quick Stand / the taya's reset
	#    channel). This is the one transition that legitimately makes a recovery
	#    sound.
	await _phase("knockdown + early self-right", func() -> void:
		unit.go_downed()
		await get_tree().create_timer(0.4).timeout
		unit.self_right()
		await get_tree().create_timer(0.4).timeout)

	# 3. THE ACTUAL TEST. More plain staggers, AFTER that knockdown. Identical
	#    to phase 1, so the counts must be identical too. If recovery sounds
	#    appear here and not in phase 1, state from the knockdown is leaking
	#    into every subsequent stagger.
	await _phase("three MORE staggers (same as phase 1)", func() -> void:
		for i in 3:
			unit.apply_stagger(0.25)
			await get_tree().create_timer(0.45).timeout)

	print("")
	for line in _log:
		print(line)
	get_tree().quit(0)


func _phase(label: String, body: Callable) -> void:
	_starts.clear()
	await body.call()
	await get_tree().create_timer(0.3).timeout
	var parts: Array[String] = []
	var names := _starts.keys()
	names.sort()
	for n in names:
		parts.append("%s x%d" % [n, _starts[n]])
	_log.append("  %-38s -> %s" % [label, ", ".join(parts) if parts.size() > 0 else "(silence)"])


func _find_units(root: Node) -> Array:
	var out: Array = []
	for child in root.find_children("*", "CharacterBase", true, false):
		var c := child as CharacterBase
		if c != null and is_instance_valid(c):
			out.append(c)
	return out


func _process(_delta: float) -> void:
	for child in AudioManager.get_children():
		if not (child is AudioStreamPlayer or child is AudioStreamPlayer3D):
			continue
		var id: int = child.get_instance_id()
		var playing: bool = child.playing
		var pos: float = child.get_playback_position() if playing else 0.0
		if playing and (not bool(_last_playing.get(id, false)) or pos < float(_last_pos.get(id, 0.0)) - 0.001):
			var n := "?"
			if child.stream != null:
				n = str(child.stream.resource_path).get_file().get_basename()
			_starts[n] = int(_starts.get(n, 0)) + 1
		_last_playing[id] = playing
		_last_pos[id] = pos
