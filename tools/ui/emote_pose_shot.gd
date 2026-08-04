extends Node
## EVERY EMOTE, PLAYED ON A REAL BODY, PHOTOGRAPHED FROM THE EMOTE CAMERA.
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/ui/emote_pose_shot.tscn -- <out-dir/>
##
## ⚠️ PLAIN EXE, NOT --headless — no rendering device under headless here.
##
## ⚠️ THIS EXISTS BECAUSE A CLIP NAME IS NOT A POSE. "T-POSE" is a promise about
## what the player will see, and `static` is only the rig's bind pose if you have
## actually looked at it. Naming a slice off a guess is how a wheel ends up offering
## something the animation does not do.
const SETTLE: float = 0.6

var _out: String = ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			_out = a
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.0).timeout

	var me: Node = null
	for node in main.find_children("*", "CharacterBase", true, false):
		if node.get("is_person") and not node.is_ai_driven():
			me = node
			break
	if me == null:
		push_error("emote_pose_shot: no keyboard-driven Person")
		get_tree().quit(1)
		return

	for entry in EmoteWheel.EMOTES:
		var id: String = String(entry["id"])
		me.play_emote(id)
		# Long enough for a one-shot to reach its held final frame.
		await get_tree().create_timer(SETTLE).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%semote_%s.png" % [_out, id])
		print("[pose] wrote emote_%s (%s)" % [id, entry["label"]])
		me.stop_emote()
		await get_tree().create_timer(0.3).timeout
	get_tree().quit()
