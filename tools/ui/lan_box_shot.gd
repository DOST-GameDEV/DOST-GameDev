extends Node

const SCREEN: String = "res://scenes/ui/MultiplayerSetup.tscn"

var _out: String = ""
var _screen: Node = null

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	_screen = load(SCREEN).instantiate()
	add_child(_screen)
	await get_tree().create_timer(0.6).timeout
	await _shot("lan_closed")
	_screen._on_browse_pressed()
	await get_tree().create_timer(0.3).timeout
	await _shot("lan_empty")
	_fill()
	_screen._refresh_lan_browser()
	await get_tree().create_timer(0.3).timeout
	await _shot("lan_full")
	get_tree().quit(0)

func _fill() -> void:
	var names := ["HARRY'S GAME", "MATTHEW'S GAME", "A TUMBANG PRESO GAME",
		"KUYA JOMS' GAME", "P4'S GAME", "SOMEBODY WITH A VERY VERY LONG NAME'S GAME"]
	for i in names.size():
		LanBeacon._seen["192.168.1.%d:8910" % (10 + i)] = {
			"ip": "192.168.1.%d" % (10 + i), "port": 8910, "name": names[i],
			"players": (i % 4) + 1, "max": 4, "in_match": i % 3 == 0, "age": 0.0,
		}

func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s%s.png" % [_out, tag])
	print("wrote ", tag)

