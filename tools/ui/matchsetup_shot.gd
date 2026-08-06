extends Node

var _out: String = ""
var _i: int = 0
var _settle: int = 0
var _screen: Control = null

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	GameLaunch.pending_action = "local"
	_screen = load("res://scenes/ui/MatchSetup.tscn").instantiate()
	add_child(_screen)
	_settle = 60

func _process(_d: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	await RenderingServer.frame_post_draw
	var id: String = String(GameLaunch.MAPS[_i]["id"])
	get_viewport().get_texture().get_image().save_png("%smatchsetup_%s.png" % [_out, id])
	print("wrote matchsetup_", id)
	_i += 1
	if _i >= GameLaunch.MAPS.size():
		set_process(false)
		get_tree().quit(0)
		return
	(_screen.get_node("%MapNextButton") as BaseButton).pressed.emit()
	_settle = 40

