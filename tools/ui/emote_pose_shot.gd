extends Node
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
		await get_tree().create_timer(SETTLE).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%semote_%s.png" % [_out, id])
		print("[pose] wrote emote_%s (%s)" % [id, entry["label"]])
		me.stop_emote()
		await get_tree().create_timer(0.3).timeout
	get_tree().quit()

