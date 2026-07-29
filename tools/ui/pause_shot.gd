extends Node
## Screenshots the in-game pause card over a live arena, in both of its states.
##
##   godot --path . tools/ui/pause_shot.tscn --resolution 1920x1080 -- /out/
##
## Writes `pause_local.png` (the real freeze) and `pause_networked.png` (the
## overlay-only state, which carries the extra note under the title). The second
## one is worth shooting because it is the state nobody looks at — it needs a
## networked session to reach and it is where the title used to overflow.
##
## Runs Main.tscn rather than the pause layer on its own: the card draws over
## whatever the arena happens to be showing, and a card that reads fine on a flat
## colour is exactly the mistake this pass exists to undo.

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
	# The map streams in and the round intro plays; shooting before that settles
	# gives a card floating over an unlit greybox.
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
	# Third shot is SETTINGS opened from the pause menu — the same swap
	# main.gd's SettingsButton does. Worth its own frame: that panel draws on a
	# live arena rather than on the light theme it was authored against, which is
	# where its labels went unreadable.
	(_main.get_node("%PauseRoot") as Control).visible = not settings
	(_main.get_node("%SettingsPanel") as Control).visible = settings
	# The overlay-only state is reached by a networked non-solo session, which a
	# screenshot harness cannot stand up. Its ONE visible difference is this
	# note, so the second shot sets it directly rather than faking a peer.
	(_main.get_node("%PausedNoteLabel") as Label).visible = _i == 1
