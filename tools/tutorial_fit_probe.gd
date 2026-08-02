extends Node
## DOES EVERY TUTORIAL PAGE FIT WITHOUT SCROLLING? **Written 2026-08-02.**
##
##     Godot_v4.7.1-stable_win64_console.exe --headless --path <repo> tools/tutorial_fit_probe.tscn
##
## ⚠️ THE FAILURE THIS GUARDS IS A REPEAT ONE AND IT IS INVISIBLE TO A PARSE GATE. Two
## separate notes in `tutorial.gd` record a page whose rows overflowed the panel — HANDS
## raised a scrollbar and clipped its own last row at 1920×1080, and SCORING overflowed by
## 37 px on its CHIPS rather than its bodies. Both were found by rendering and looking.
## Reading is what this screen is for, so a page the player has to scroll is a bug, and
## after the 2026-08-02 rewrite that merged two pages away every page's row count moved.
##
## Measured rather than rendered: the `Rows` VBox's laid-out height against the
## `ScrollContainer` that holds it. If the content is taller, the page scrolls. That needs
## a layout pass, not a rendering device, so it runs headless in a couple of seconds.
##
## ⚠️ ONE COROUTINE IN `_ready()`, NOT A STATE MACHINE IN `_process()`. Awaiting inside
## `_process` starts a fresh overlapping coroutine every frame and the first draft of this
## file hung on exactly that.

const TUTORIAL: String = "res://scenes/ui/Tutorial.tscn"
## The panel is authored against 1920×1080 and that is where both historical clips were
## seen, so it is the size the question is asked at.
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
		# ⚠️ THE COMBINED MINIMUM, NOT `rows.size.y`. A `ScrollContainer`'s child is
		# STRETCHED to the viewport it scrolls in, so `size.y` reports the container's
		# height on every page — the first draft of this probe printed an identical
		# "need 513.0, have 513.0, spare 0.0" for all eight, including the page with no
		# rows at all, and called it a pass. The content's own demand is the minimum.
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
