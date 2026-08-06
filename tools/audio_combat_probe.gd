extends Node3D

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

	await _phase("three staggers, no knockdown", func() -> void:
		for i in 3:
			unit.apply_stagger(0.25)
			await get_tree().create_timer(0.45).timeout)

	await _phase("knockdown + early self-right", func() -> void:
		unit.go_downed()
		await get_tree().create_timer(0.4).timeout
		unit.self_right()
		await get_tree().create_timer(0.4).timeout)

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

