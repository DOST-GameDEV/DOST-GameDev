extends Node
## Screenshots every page of Tutorial.tscn, so the screen is verified by looking
## at it rather than by "the scene loads". `tools/ui_shot.gd`'s equivalent for a
## panel that has six states instead of one.
##
##   godot --path . tools/ui/tutorial_shot.tscn --resolution 1920x1080 -- /out/

var _out: String = ""
var _page: int = 0
var _settle: int = 0
var _panel: TutorialPanel = null

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	_panel = load("res://scenes/ui/Tutorial.tscn").instantiate()
	add_child(_panel)
	_settle = 30

func _process(_d: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"%stutorial_%d.png" % [_out, _page + 1])
	_report_overflow()
	_page += 1
	if _page >= TutorialPanel.PAGES.size():
		set_process(false)
		get_tree().quit(0)
		return
	# Driven through the button rather than by poking _page, so this exercises
	# the same path a player does.
	_panel.get_node("%NextButton").pressed.emit()
	_settle = 6

## ⚠️ "NOTHING GETS CUT OFF" IS A MEASUREMENT, NOT A SQUINT. 🧑 2026-08-01: *"make sure
## nothing truncates or gets cut off btw make sure all text looks good"*. Ten pages at
## one screenshot each is ten chances to miss a scrollbar by eye — and the failure is
## quiet, because an overflowing page still renders a perfectly good screenshot of its
## first two-thirds.
##
## The `ScrollContainer` knows. If its content is taller than the box, its vertical
## scrollbar has a usable range; if it fits, `max_value <= page`. That is the same fact
## the scrollbar itself draws, read as a number instead of as pixels.
func _report_overflow() -> void:
	var scroll := _panel.get_node_or_null("%Scroll") as ScrollContainer
	var page_name: String = String(TutorialPanel.PAGES[_page]["title"])
	if scroll == null:
		print("[page %d] %s  scroll=MISSING" % [_page + 1, page_name])
		return
	var bar := scroll.get_v_scroll_bar()
	var content := bar.max_value
	var box := bar.page
	var overflows := content > box + 1.0 # a pixel of slack for rounding
	print("[page %d] %-22s content=%.0f box=%.0f %s"
		% [_page + 1, page_name, content, box,
			"⚠️ OVERFLOWS BY %.0f px" % [content - box] if overflows else "fits"])
