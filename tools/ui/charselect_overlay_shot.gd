extends Node

const TABS := ["tao", "lata", "tsinelas"]

var _out: String = ""
var _i: int = 0
var _settle: int = 0
var _screen: Control = null
var _panel: CharacterSelect = null

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	GameLaunch.pending_action = "local"
	_screen = load("res://scenes/ui/MatchSetup.tscn").instantiate()
	add_child(_screen)
	(_screen.get_node("%CharacterButton") as BaseButton).pressed.emit()
	_panel = _screen.get_node("%CharacterSelectPanel") as CharacterSelect
	_settle = 60

func _process(_d: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	await RenderingServer.frame_post_draw
	print("[%s] panel visible=%s  map behind=%s" % [TABS[_i], _panel.visible,
		(_screen.get_node("MapPreview") as Control).visible])
	get_viewport().get_texture().get_image().save_png(
		"%scharselect_overlay_%s.png" % [_out, TABS[_i]])
	_i += 1
	if _i >= TABS.size():
		set_process(false)
		get_tree().quit(0)
		return
	_panel._on_tab_pressed(_i)
	_settle = 20

