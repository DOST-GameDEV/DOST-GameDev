extends Node
## Does anything leave the screen? Asked at several resolutions, of every screen.
## Written 2026-08-01, branch `HARRYDAKS`.
##
## ⚠️ WHY THIS EXISTS. 🧑 2026-08-01: *"make sure nothing goes beyond screen too when we
## change resolution or smth"*, after *"in fullscreen back button is cut off in lobby
## and other places"*. The BACK button case was found by a human looking at a monitor,
## which is the expensive way to find it — and it was found once, on one screen, at one
## size. Every other screen and every other size was still unchecked.
##
## ⚠️ IT WALKS THE LIVE TREE AND COMPARES RECTS. A `Control`'s `get_global_rect()` after
## layout is the truth about where it actually ended up — not its anchors, not its
## offsets, and not what it looked like in the editor at 1920×1080. Anything whose rect
## crosses the viewport edge is reported with the axis and the overhang in pixels.
##
## ⚠️ RUN IT WITH THE PLAIN EXE. `--headless` has no rendering device, and while the
## layout still resolves, the resize path this is testing does not behave the same.
##
##     Godot_v4.7.1-stable_win64_console.exe --path <repo> tools/ui/bounds_sweep.tscn
##
## Exits non-zero if anything is out of bounds, so it can gate a build.

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

## ⚠️ THE LIST IS ASPECT RATIOS, NOT "BIG AND SMALL". The project stretches
## `canvas_items` with `aspect = expand` (`project.godot`), so the canvas is never
## SHORTER than 1080 — scaling alone cannot clip anything. What changes is the SHAPE:
## 16:10 and 4:3 hand the canvas extra HEIGHT and 21:9 extra WIDTH, and an element
## positioned by absolute offset from the top-left stays put while the edge it was
## measured against moves. That is the failure this sweeps for.
const SIZES: Array = [
	[1920, 1080, "16:9"],
	[1280, 720, "16:9 small"],
	[1920, 1200, "16:10"],
	[2560, 1080, "21:9"],
	[1440, 1080, "4:3"],
]

## A control may sit this far outside before it counts. One pixel of overhang is
## rounding on a scaled canvas; ten is a design error.
const SLACK: float = 2.0

## ⚠️ THE PENNANT BUTTONS BLEED OFF THE LEFT EDGE ON PURPOSE, and this is the list that
## says so. `ArrowButton` draws a banner hanging from a pole, and the pole end runs off
## the left of the frame — the same way the MULTIPLAYER / SETUP banners at the top of
## every screen do. Measured: the overhang is IDENTICAL at 16:9, 16:10, 21:9 and 4:3
## (-123, -143, -158, -173 px), which is the proof it is authored layout rather than a
## clipping bug — a resolution problem would move with the resolution.
##
## ⚠️ IT IS A LEFT-EDGE EXEMPTION ONLY, NOT A BLANKET ONE. These controls are still
## checked against the top, right and bottom edges, so a pennant that fell off the
## BOTTOM — which is the failure the human actually reported — would still be caught.
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
	# ⚠️ A FULL SECOND, NOT TWO FRAMES. Containers resolve minimum sizes on frame one
	# and lay out on frame two — but `MainMenu` and `MultiplayerSetup` TWEEN their
	# pennant buttons in from off the left edge, and sampled at frame two every one of
	# them is still at its off-screen rest position. The first run of this sweep
	# reported eight such "failures" on MainMenu alone, all of which were the intro
	# animation not having played yet. Waiting for it is the difference between a probe
	# that measures the screen and one that measures its own impatience.
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


## ⚠️ HIDDEN NODES ARE SKIPPED, AND SO ARE ZERO-SIZED ONES. A hidden control is not on
## screen to leave it, and half of every screen here ships hidden (spectator rows, the
## charge meters, the result card). A zero-sized one is a spacer.
##
## ⚠️ AND EVERYTHING INSIDE A `ScrollContainer` IS SKIPPED, WHICH IS NOT A LOOPHOLE.
## Content taller than its box is the entire purpose of a scroll view — SettingsPanel's
## volume rows sit 57 px below the fold and are reached by scrolling, exactly as
## designed. Flagging them would train the reader to ignore this probe's output, which
## is worse than not running it. The SCROLL CONTAINER ITSELF is still checked, so a
## scroll view that is itself off-screen is still caught.
func _walk(node: Node, view: Rect2, out: Array[String]) -> void:
	var control := node as Control
	if control != null:
		if not control.is_visible_in_tree():
			return # its children cannot be visible either
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


## True if this control, or an ancestor, is a pennant — the `Artwork` and `Caption`
## children inherit the exemption, because they are parts of the same banner.
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
