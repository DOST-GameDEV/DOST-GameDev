extends Node

const SCREEN := "res://scenes/ui/CharacterSelect.tscn"

var _log: PackedStringArray = []
var _fails: int = 0


func _emit(s: String) -> void:
	print(s)
	_log.append(s)


func _ready() -> void:
	var screen := (load(SCREEN) as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var panel := screen.get_node("ConfigPanel") as Control
	var rows := screen.get_node("ConfigPanel/Rows") as VBoxContainer
	var budget: float = panel.size.y - rows.offset_top + rows.offset_bottom

	_emit("=== CHARACTER panel fit ===")
	_emit("panel %.0f px tall, Rows budget %.0f px" % [panel.size.y, budget])
	_emit("")

	for tab in range(CharacterRoster.CATEGORIES.size()):
		var category: Dictionary = CharacterRoster.CATEGORIES[tab]
		var entries: Array = CharacterRoster.entries_for(tab)
		_emit("%s — %d entries" % [String(category["label"]), entries.size()])
		for index in range(entries.size()):
			screen.set("_tab", tab)
			var picks: Array = screen.get("_indices")
			picks[tab] = index
			screen.set("_indices", picks)
			screen.call("_apply")
			await get_tree().process_frame
			await get_tree().process_frame
			var need: float = rows.get_combined_minimum_size().y
			var over: float = need - budget
			var name: String = String(entries[index]["name"])
			if over > 0.5:
				_fails += 1
				_emit("  FAIL %-14s needs %.0f px, %.0f OVER" % [name, need, over])
			else:
				_emit("  ok   %-14s needs %.0f px (%.0f spare)" % [name, need, -over])
		_emit("")

	_finish()


func _finish() -> void:
	if _fails == 0:
		_emit("CHARSELECT FIT: all entries fit")
	else:
		_emit("CHARSELECT FIT: %d entry(ies) OVERFLOW the panel" % _fails)
	var file := FileAccess.open("user://charselect_fit.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	get_tree().quit(0 if _fails == 0 else 1)

