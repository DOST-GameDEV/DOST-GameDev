extends Node
## Screenshots CHARACTER SELECT AS THE PLAYER ACTUALLY REACHES IT — as the
## full-screen overlay panel on top of MatchSetup's live-3D map backdrop, one shot
## per character tab.
##
##   godot --path . tools/ui/charselect_overlay_shot.tscn -- /out/
##
## Writes `charselect_overlay_<tab>.png`.
##
## ⚠️ WHY THIS EXISTS. `ui_layout_probe.gd` loads `CharacterSelect.tscn` standalone,
## where there is nothing behind it to leak through. But `MatchSetup.tscn` instances
## the same scene as `%CharacterSelectPanel`, and behind that panel a whole map is
## rendering. The panel's opacity used to come from the preview Environment's flat
## `BG_COLOR` fill; now the SubViewport is transparent and a `Backdrop` TextureRect
## carries it instead. That swap is invisible to every existing probe and to a parse
## check — the only way to know the map does not show through is to render the
## overlay over it and LOOK.
##
## Solo branch (`pending_action = "local"`), the one that needs no ENet session.

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
	# Through the screen's own button, so the panel is opened by the path a player
	# uses rather than by setting `visible` behind the screen's back.
	(_screen.get_node("%CharacterButton") as BaseButton).pressed.emit()
	_panel = _screen.get_node("%CharacterSelectPanel") as CharacterSelect
	# Long enough for the map behind to resolve its shadow atlas — a map that has not
	# settled is a weaker test of whether it shows through.
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
