extends Node

var _out: String = ""
var _i: int = 0
var _settle: int = 0
var _main: Node = null

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	GameLaunch.pending_action = "local"
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	_settle = 150

func _process(_d: float) -> void:
	if _settle > 0:
		_settle -= 1
		if _settle == 0:
			_show()
		return
	await RenderingServer.frame_post_draw
	var names := ["pause_local", "pause_networked", "pause_settings"]
	get_viewport().get_texture().get_image().save_png("%s%s.png" % [_out, names[_i]])
	print("wrote ", names[_i])
	_i += 1
	if _i >= names.size():
		set_process(false)
		get_tree().quit(0)
		return
	_settle = 20

func _show() -> void:
	var settings := _i == 2
	(_main.get_node("%PauseRoot") as Control).visible = not settings
	(_main.get_node("%SettingsPanel") as Control).visible = settings
	(_main.get_node("%PausedNoteLabel") as Label).visible = _i == 1

