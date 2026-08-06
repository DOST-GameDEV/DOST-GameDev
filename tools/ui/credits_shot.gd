extends Node

var _out: String = ""
var _scroll: int = 0
var _menu: Control = null
var _settle: int = 0
var _stage: int = 0

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	_scroll = int(a[1]) if a.size() > 1 else 0
	_menu = load("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child(_menu)
	_settle = 40

func _process(_d: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	if _stage == 0:
		(_menu.get_node("%CreditsButton") as BaseButton).pressed.emit()
		_stage = 1
		_settle = 20
		return
	var name := "credits_from_menu"
	if _scroll > 0 and _stage == 1:
		var panel := _menu.find_child("CreditsPanel", true, false)
		var box := panel.find_child("Scroll", true, false) as ScrollContainer \
			if panel != null else null
		if box != null:
			box.scroll_vertical = _scroll
		_stage = 2
		_settle = 6
		return
	if _scroll > 0:
		name = "credits_from_menu_scrolled"
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + name + ".png")
	print("wrote " + name)
	get_tree().quit(0)

