extends Node
## One-off: is the player-name row actually visible on SETTINGS, reached the
## way a player reaches it? 🧑 reported it "disappeared" — checked whether that
## is a real regression before touching anything.
##
##   godot --path <repo> tools/ui/settings_shot_check.tscn -- out=C:/tmp/

var _out: String = ""
var _menu: Control = null

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("out="):
			_out = text.substr(4)
	_menu = load("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child(_menu)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	(_menu.get_node("%SettingsButton") as BaseButton).pressed.emit()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + "settings_check.png")
	print("wrote settings_check")
	get_tree().quit(0)
