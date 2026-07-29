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
	print("wrote tutorial_", _page + 1)
	_page += 1
	if _page >= TutorialPanel.PAGES.size():
		set_process(false)
		get_tree().quit(0)
		return
	# Driven through the button rather than by poking _page, so this exercises
	# the same path a player does.
	_panel.get_node("%NextButton").pressed.emit()
	_settle = 6
