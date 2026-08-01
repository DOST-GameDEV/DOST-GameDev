extends Node
## THE ONLINE BROWSER, AGAINST REAL LOBBIES — not injected rows.
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/ui/online_box_shot.tscn -- \
##         --pool=127.0.0.1 <out-dir-with-trailing-slash>
##
## ⚠️ PLAIN EXE, NOT --headless. There is no rendering device under --headless here and
## every capture comes back blank — the same trap lan_box_shot.gd documents.
##
## Unlike lan_box_shot.gd, this one does NOT write into ServerQuery._seen. Real dedicated
## lobby processes must already be running on the pool ports; what is on screen arrived
## over a real UDP round trip. That is the half no screenshot has covered yet.

const SCREEN: String = "res://scenes/ui/MultiplayerSetup.tscn"

var _out: String = ""
var _screen: Node = null

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			_out = a
	_screen = load(SCREEN).instantiate()
	add_child(_screen)
	# Long enough for several query rounds plus the settle window.
	await get_tree().create_timer(4.0).timeout
	var sq: Node = get_node("/root/ServerQuery")
	var rows: Array = sq.call("servers")
	print("[shot] pool_address=%s rows=%d" % [sq.get("pool_address"), rows.size()])
	for r in rows:
		var d: Dictionary = r
		print("[shot]   %s:%d code=%s players=%d/%d in_progress=%s"
			% [d.get("ip",""), int(d.get("port",0)), d.get("code",""),
			   int(d.get("players",0)), int(d.get("max",0)), d.get("in_progress")])
	await _shot("online_closed")
	_screen.call("_on_online_browse_pressed")
	await get_tree().create_timer(0.4).timeout
	await _shot("online_open")
	get_tree().quit()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s%s.png" % [_out, name])
	print("[shot] wrote %s%s.png" % [_out, name])
