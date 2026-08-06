extends Node

const SCREENS: Array[String] = [
	"res://scenes/ui/MainMenu.tscn",
	"res://scenes/ui/ModeSelect.tscn",
	"res://scenes/ui/MultiplayerSetup.tscn",
	"res://scenes/ui/MatchSetup.tscn",
	"res://scenes/ui/CharacterSelect.tscn",
	"res://scenes/ui/SettingsPanel.tscn",
	"res://scenes/ui/Tutorial.tscn",
	"res://scenes/ui/HUD.tscn",
	"res://scenes/ui/MatchResult.tscn",
]

const SIZES: Array = [
	[1920, 1080, "16:9"],
	[1280, 720, "16:9 small"],
	[1920, 1200, "16:10"],
	[2560, 1080, "21:9"],
	[1440, 1080, "4:3"],
]

const SLACK: float = 2.0

const BLEEDS_LEFT: Array[String] = ["ArrowButton"]

var _failures: int = 0


func _ready() -> void:
	for size in SIZES:
		get_window().size = Vector2i(int(size[0]), int(size[1]))
		await get_tree().process_frame
		await get_tree().process_frame
		for path in SCREENS:
			await _check(path, String(size[2]))
	print("")
	if _failures == 0:
		print("[bounds] PASS — nothing leaves the screen on %d screens x %d sizes"
			% [SCREENS.size(), SIZES.size()])
	else:
		print("[bounds] FAIL — %d out-of-bounds control(s)" % [_failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(path: String, label: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		print("[bounds] %s  %s  COULD NOT LOAD" % [label, path.get_file()])
		_failures += 1
		return
	var screen := packed.instantiate()
	add_child(screen)
	await get_tree().create_timer(1.0).timeout

	var view := Rect2(Vector2.ZERO, Vector2(get_viewport().get_visible_rect().size))
	var bad: Array[String] = []
	_walk(screen, view, bad)
	if bad.is_empty():
		print("[bounds] %-11s %-22s ok" % [label, path.get_file()])
	else:
		_failures += bad.size()
		for line in bad:
			print("[bounds] %-11s %-22s ⚠️ %s" % [label, path.get_file(), line])
	screen.queue_free()
	await get_tree().process_frame


func _walk(node: Node, view: Rect2, out: Array[String]) -> void:
	var control := node as Control
	if control != null:
		if not control.is_visible_in_tree():
			return
		if control is ScrollContainer:
			_check_one(control, view, out)
			return
		_check_one(control, view, out)
	for child in node.get_children():
		_walk(child, view, out)


func _check_one(control: Control, view: Rect2, out: Array[String]) -> void:
	var rect := control.get_global_rect()
	if rect.size.x <= 0.5 or rect.size.y <= 0.5:
		return
	var over := _overhang(rect, view, _bleeds_left(control))
	if over != "":
		out.append("%s  %s  rect=%s" % [control.name, over, str(rect)])


func _bleeds_left(control: Control) -> bool:
	var node: Node = control
	while node != null:
		for cls in BLEEDS_LEFT:
			if node.is_class(cls) or node.get_script() != null 					and String(node.get_script().get_global_name()) == cls:
				return true
		node = node.get_parent()
	return false


func _overhang(rect: Rect2, view: Rect2, allow_left: bool = false) -> String:
	var parts := PackedStringArray()
	if not allow_left and rect.position.x < view.position.x - SLACK:
		parts.append("off LEFT by %.0f" % [view.position.x - rect.position.x])
	if rect.position.y < view.position.y - SLACK:
		parts.append("off TOP by %.0f" % [view.position.y - rect.position.y])
	if rect.end.x > view.end.x + SLACK:
		parts.append("off RIGHT by %.0f" % [rect.end.x - view.end.x])
	if rect.end.y > view.end.y + SLACK:
		parts.append("off BOTTOM by %.0f" % [rect.end.y - view.end.y])
	return " · ".join(parts)

