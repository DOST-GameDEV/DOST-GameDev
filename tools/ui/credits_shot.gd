extends Node
## Screenshots the CREDITS panel reached the way a player reaches it — through
## MainMenu.tscn's own CreditsButton, not by loading CreditsPanel.tscn in
## isolation — so this is evidence for § CHECKLIST 1.11 rather than a claim
## that the control is merely in the tree (THE REACHABILITY RULE).
##
##   godot --path . tools/ui/credits_shot.tscn --resolution 1920x1080 -- /out/
##
## Writes `credits_from_menu.png`.

var _out: String = ""
var _menu: Control = null
var _settle: int = 0
var _stage: int = 0

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
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
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + "credits_from_menu.png")
	print("wrote credits_from_menu")
	get_tree().quit(0)
