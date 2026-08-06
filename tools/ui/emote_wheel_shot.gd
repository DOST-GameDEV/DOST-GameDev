extends Node

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
	var bad: Array = wheel.overflow_report()
	if bad.is_empty():
		print("[wheel] LABEL FIT: all %d labels fit, selected and resting"
			% wheel.EMOTES.size())
	else:
		for line in bad:
			print("[wheel] %s" % line)
	for line in wheel.bad_detail:
		print("[wheel]%s" % line)

	wheel.open()
	await _shot("wheel_neutral")

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

