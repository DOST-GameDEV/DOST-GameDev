extends Node

const SCREEN := "res://scenes/ui/CharacterSelect.tscn"

var _out := ""
var _screen: Control = null
var _index := 0
var _settle := 0
var _fails := 0
var _shots: Array = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else ""

	for tab in range(CharacterRoster.CATEGORIES.size()):
		var category := CharacterRoster.category(tab)
		var entries: Array = category["entries"]
		print("tab '%s' (%s): %d entries" % [
			String(category["label"]), String(category["id"]), entries.size()])
		for i in range(entries.size()):
			var entry: Dictionary = entries[i]
			_shots.append([tab, i])
			if not entry.has("model"):
				continue
			var model := load(String(entry["model"]))
			var palette := load(String(entry["material"]))
			if model == null or palette == null:
				_fails += 1
			print("  [%2d] %-12s %-14s model=%-7s palette=%s" % [
				i, String(entry["name"]), String(entry["id"]),
				"OK" if model != null else "MISSING",
				"OK" if palette != null else "MISSING"])

	var packed := load(SCREEN) as PackedScene
	if packed == null:
		print("FAILED to load ", SCREEN)
		get_tree().quit(1)
		return
	_screen = packed.instantiate() as Control
	add_child(_screen)
	_settle = 30

func _process(_delta: float) -> void:
	if _screen == null:
		return
	if _settle > 0:
		_settle -= 1
		return
	if _index >= _shots.size():
		print("\n=== %s (%d entries across %d tabs, %d asset failures) ===" % [
			"ALL ENTRIES RENDERED" if _fails == 0 else "ASSET FAILURES",
			_shots.size(), CharacterRoster.CATEGORIES.size(), _fails])
		set_process(false)
		get_tree().quit(1 if _fails > 0 else 0)
		return

	var tab: int = _shots[_index][0]
	var slot: int = _shots[_index][1]
	_screen.set("_tab", tab)
	var indices: Array = _screen.get("_indices")
	indices[tab] = slot
	_screen.set("_indices", indices)
	_screen.call("_refresh_tab_buttons")
	_screen.call("_apply")
	await RenderingServer.frame_post_draw
	var entry: Dictionary = CharacterRoster.entries_for(tab)[slot]
	var label := "%s_%s" % [String(CharacterRoster.category(tab)["id"]), String(entry["id"])]
	get_viewport().get_texture().get_image().save_png(
		"%schar_%02d_%s.png" % [_out, _index, label])
	print("wrote char_%02d_%s.png" % [_index, label])
	_index += 1
	_settle = 8

