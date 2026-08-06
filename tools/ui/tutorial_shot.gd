extends Node

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
	_panel.get_node("%NextButton").pressed.emit()
	_settle = 6

func _report_overflow() -> void:
	var scroll := _panel.get_node_or_null("%Scroll") as ScrollContainer
	var page_name: String = String(TutorialPanel.PAGES[_page]["title"])
	if scroll == null:
		print("[page %d] %s  scroll=MISSING" % [_page + 1, page_name])
		return
	var bar := scroll.get_v_scroll_bar()
	var content := bar.max_value
	var box := bar.page
	var overflows := content > box + 1.0
	print("[page %d] %-22s content=%.0f box=%.0f %s"
		% [_page + 1, page_name, content, box,
			"⚠️ OVERFLOWS BY %.0f px" % [content - box] if overflows else "fits"])

