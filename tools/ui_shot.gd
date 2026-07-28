extends Node
## Screenshots each menu screen after the UI-redesign merge, so the merge is
## verified by looking at it rather than by "all scenes load".
const SCREENS := ["res://scenes/ui/MainMenu.tscn", "res://scenes/ui/GameSetup.tscn",
	"res://scenes/ui/Lobby.tscn"]
var _out := ""
var _i := 0
var _settle := 0
var _current: Node = null

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	_load()

func _load() -> void:
	if _current != null:
		_current.queue_free()
	_current = load(SCREENS[_i]).instantiate()
	add_child(_current)
	_settle = 30

func _process(_d: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	await RenderingServer.frame_post_draw
	var name := String(SCREENS[_i].get_file().get_basename())
	get_viewport().get_texture().get_image().save_png(_out + "ui_" + name + ".png")
	print("wrote ui_", name)
	_i += 1
	if _i >= SCREENS.size():
		set_process(false)
		get_tree().quit(0)
		return
	_load()
