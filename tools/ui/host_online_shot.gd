extends Node
## HOST ONLINE, END TO END, AGAINST REAL POOL LOBBIES — no injected rows and no
## hardcoded address. Presses the pennant, lets it claim whatever the pool said was
## free, follows the scene change, and photographs the code the player is meant to
## read out.
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/ui/host_online_shot.tscn -- \
##         --pool=127.0.0.1 <out-dir-with-trailing-slash>
##
## Real dedicated lobbies must already be listening on the pool ports:
##     Godot ... --headless --path . res://scenes/ui/MatchSetup.tscn -- --dedicated --port=8910
##
## ⚠️ PLAIN EXE, NOT --headless. There is no rendering device under --headless on this
## machine and every capture comes back blank — the same trap online_box_shot.gd documents.
##
## ⚠️⚠️ THIS NODE MAKES THE SCREEN THE CURRENT SCENE AND STAYS OUT OF IT, which is the
## only reason the second half of the shot exists. `_begin_join` calls
## `change_scene_to_file`, and that FREES `get_tree().current_scene` — so a harness that
## parents the screen under itself (as online_box_shot.gd does, which is fine there
## because nothing it presses changes scene) is itself the thing that gets freed the
## instant the pennant works. Handing `current_scene` to the screen puts the harness
## beside it under `root` instead, so the change_scene destroys the screen and leaves the
## camera running.

const SCREEN: String = "res://scenes/ui/MultiplayerSetup.tscn"

var _out: String = ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			_out = a
	var screen: Node = load(SCREEN).instantiate()
	# ⚠️ DEFERRED. `root` is still setting THIS node up during `_ready`, and a direct
	# `add_child` there fails outright ("Parent node is busy setting up children") — which
	# left the screen unparented, so its `_build_online_browser` never ran, so nothing ever
	# asked the pool and the first run of this harness reported zero servers that were in
	# fact answering. Await the tree afterwards so `current_scene` is set on a live node.
	get_tree().root.add_child.call_deferred(screen)
	await get_tree().process_frame
	get_tree().current_scene = screen # see this file's ⚠️⚠️
	# Long enough for several query rounds plus POOL_SETTLE_SECONDS.
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

	# The longest sentence this screen can print, drawn where it actually lands. The status
	# label sits directly above the bottom button row, so "does the worst case still clear
	# BACK" is a layout question no amount of reading the .tscn answers.
	screen.get_node("%StatusLabel").text = ("Every online server is in use right now. Open "
		+ "ONLINE SERVERS to join one of them, or try again in a minute.")
	await _shot("host_online_busy")
	screen.get_node("%StatusLabel").text = ""

	screen.call("_on_host_online_pressed")
	# The claim changes scene; MatchSetup then has to connect and be told the code.
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
