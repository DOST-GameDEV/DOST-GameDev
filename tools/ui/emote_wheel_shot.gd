extends Node
## THE EMOTE WHEEL, OPEN, OVER A REAL MATCH FRAME.
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/ui/emote_wheel_shot.tscn -- \
##         <out-dir-with-trailing-slash>
##
## ⚠️ PLAIN EXE, NOT --headless — the wheel is drawn, and there is no rendering
## device under headless on this machine.
##
## ⚠️ SHOT OVER THE MATCH, NOT OVER A FLAT COLOUR. The whole question 🧑 asked is
## whether it reads as transparent and on-theme, and a wheel that looks fine on grey
## can be unreadable over a sunlit street. Two captures: one with nothing selected,
## one with the stick pushed into a slice, because the highlight is the part that
## has to survive the background.

const NUDGE: Vector2 = Vector2(0, -150)

var _out: String = ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			_out = a
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.0).timeout

	var wheel: EmoteWheel = main.find_child("EmoteWheel", true, false) as EmoteWheel
	if wheel == null:
		push_error("emote_wheel_shot: no EmoteWheel under Main — is it in HUD.tscn?")
		get_tree().quit(1)
		return
	wheel.open()
	await _shot("wheel_neutral")

	# Drive it the way a player would: relative motion, not a cursor position.
	var motion := InputEventMouseMotion.new()
	motion.relative = NUDGE
	wheel._input(motion)
	await _shot("wheel_selected")
	print("[wheel] selection after nudge: %d" % wheel._selection)
	get_tree().quit()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out + name + ".png")
	print("[wheel] wrote %s" % name)
