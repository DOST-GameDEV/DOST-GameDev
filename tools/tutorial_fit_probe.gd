extends Node

const TUTORIAL: String = "res://scenes/ui/Tutorial.tscn"
const REFERENCE: Vector2i = Vector2i(1920, 1080)

func _ready() -> void:
	get_window().size = REFERENCE
	var packed := load(TUTORIAL) as PackedScene
	if packed == null:
		print("cannot load %s" % TUTORIAL)
		get_tree().quit(1)
		return
	var screen := packed.instantiate() as Control
	add_child(screen)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in range(10):
		await get_tree().process_frame
	var pages: Array = screen.get("PAGES")
	print("
===== TUTORIAL FIT PROBE — %d x %d =====" % [REFERENCE.x, REFERENCE.y])
	var scroll := screen.get_node_or_null("%Scroll") as ScrollContainer
	var rows := screen.get_node_or_null("%Rows") as VBoxContainer
	if scroll == null or rows == null or pages == null:
		print("  Scroll/Rows/PAGES not reachable on the tutorial")
		get_tree().quit(1)
		return
	var failed := 0
	var tightest := INF
	for page_index in range(pages.size()):
		screen.set("_page", page_index)
		screen.call("_apply_page")
		for i in range(4):
			await get_tree().process_frame
		var page: Dictionary = pages[page_index]
		var have := scroll.size.y
		var need := rows.get_combined_minimum_size().y
		var spare := have - need
		var count: int = (page.get("rows", []) as Array).size()
		tightest = minf(tightest, spare)
		if spare < 0.0:
			failed += 1
		print("  %-24s %d rows   need %6.1f  have %6.1f  spare %+7.1f  %s"
			% [String(page.get("title", "?")), count, need, have, spare,
				"ok" if spare >= 0.0 else "OVERFLOWS"])
	print("-----------------------------------------")
	if failed == 0:
		print("RESULT: PASS — every page fits; tightest has %.1f px spare" % tightest)
	else:
		print("RESULT: FAIL — %d page(s) overflow" % failed)
	print("=========================================
")
	get_tree().quit(1 if failed > 0 else 0)

