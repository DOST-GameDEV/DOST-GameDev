extends Node

const SCREEN: String = "res://scenes/ui/MultiplayerSetup.tscn"

var _out: String = ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			_out = a
	var screen: Node = load(SCREEN).instantiate()
	get_tree().root.add_child.call_deferred(screen)
	await get_tree().process_frame
	get_tree().current_scene = screen
	await get_tree().create_timer(4.0).timeout

	var sq: Node = get_node("/root/ServerQuery")
	var rows: Array = sq.call("servers")
	print("[shot] pool=%s rows=%d" % [sq.get("pool_address"), rows.size()])
	for r in rows:
		var d: Dictionary = r
		print("[shot]   %s:%d code=%s players=%d/%d in_progress=%s" % [d.get("ip", ""),
			int(d.get("port", 0)), d.get("code", ""), int(d.get("players", 0)),
			int(d.get("max", 0)), d.get("in_progress")])
	print("[shot] free slot the pennant would take: '%s'" % screen.call("_free_pool_address"))
	await _shot("host_online_screen")

	screen.get_node("%StatusLabel").text = ("Every online server is in use right now. Open "
		+ "ONLINE SERVERS to join one of them, or try again in a minute.")
	await _shot("host_online_busy")
	screen.get_node("%StatusLabel").text = ""

	screen.call("_on_host_online_pressed")
	await get_tree().create_timer(4.0).timeout
	var nm: Node = get_node("/root/NetworkManager")
	print("[shot] after claim: join_code='%s' leader=%d peers=%s" % [nm.get("join_code"),
		int(nm.get("lobby_leader_id")), str(nm.get("connected_peer_ids"))])
	print("[shot] am I the leader? %s" % str(nm.call("is_lobby_leader")))
	await _shot("host_online_lobby")
	get_tree().quit()

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s%s.png" % [_out, shot_name])
	print("[shot] wrote %s%s.png" % [_out, shot_name])

