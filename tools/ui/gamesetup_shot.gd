extends Node
## Screenshots the GAME screen once per map, by cycling the picker the way a
## player does. `tools/ui_shot.gd` only ever catches the first map, which is
## exactly the half of the live-3D-backdrop feature that cannot go wrong.
##
##   godot --path . tools/ui/gamesetup_shot.tscn --resolution 1920x1080 -- /out/
##
## Writes `gamesetup_<map id>.png`. Use it to tune the `preview` blocks in
## `GameLaunch.MAPS` — every shot is the real screen, scrim and all, so what you
## see here is what the player gets.

var _out: String = ""
var _i: int = 0
var _settle: int = 0
var _screen: Control = null

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	_screen = load("res://scenes/ui/GameSetup.tscn").instantiate()
	add_child(_screen)
	_settle = 60

func _process(_d: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	await RenderingServer.frame_post_draw
	var id: String = String(GameLaunch.MAPS[_i]["id"])
	get_viewport().get_texture().get_image().save_png("%sgamesetup_%s.png" % [_out, id])
	print("wrote gamesetup_", id)
	_i += 1
	if _i >= GameLaunch.MAPS.size():
		set_process(false)
		get_tree().quit(0)
		return
	# Through the button, so this exercises the same signal path the picker uses
	# rather than setting the index behind the screen's back.
	(_screen.get_node("%MapNextButton") as BaseButton).pressed.emit()
	# Long enough for the newly-added map's shadow atlas and SSAO to resolve; a
	# shot taken immediately is visibly flatter than a settled one.
	_settle = 40
