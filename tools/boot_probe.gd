extends SceneTree
var _out := ""
var _t := 0.0
var _stage := 0

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	change_scene_to_file("res://scenes/ui/SplashScreen.tscn")

func _process(delta: float) -> bool:
	_t += delta
	var cur := current_scene
	if cur == null:
		return false
	if _stage == 0 and _t > 1.3:
		_stage = 1
		var v := cur.get_node_or_null("%Video") as VideoStreamPlayer
		print("t=1.3s scene=", cur.name, "  video_playing=", (v.is_playing() if v else "n/a"))
		root.get_texture().get_image().save_png(_out + "boot_splash.png")
	elif _stage == 1 and _t > 5.5:
		_stage = 2
		print("t=5.5s scene=", cur.name)
		root.get_texture().get_image().save_png(_out + "boot_menu.png")
		print("RESULT: ", "BOOT CHAIN OK" if cur.name == "MainMenu" else "*** DID NOT REACH MAIN MENU ***")
		return true
	return false

