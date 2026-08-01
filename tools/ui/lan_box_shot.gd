extends Node
## THE LAN BROWSER BOX, OPENED AND FULL. **Written 2026-08-02.**
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/ui/lan_box_shot.tscn -- \
##         <out-dir-with-trailing-slash>
##
## ⚠️ RUN IT WITH THE PLAIN EXE, NOT `--headless`. There is no rendering device under
## `--headless` on this machine and every capture comes back blank.
##
## ⚠️⚠️ IT FAKES THE SERVERS RATHER THAN HOSTING ANY. `tools/lan_probe.tscn` already
## proves the socket half end to end; what cannot be proved without a picture is whether
## six rows FIT the box, whether a long host name clips instead of overflowing, and
## whether the panel actually draws over the JOIN pennant. Those are layout questions, so
## this reaches past the socket and writes `LanBeacon._seen` directly — one variable, and
## the variable is the layout.
##
## It shoots three states, because the empty one is the one a player sees first and is
## the easiest to leave unstyled: CLOSED (the button's count), EMPTY (the box with its
## fallback text), FULL (six rows, including a deliberately over-long name).

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
	# EMPTY: the box open with nothing found. `start_listening()` cleared `_seen`, so
	# this is the real empty state and not a mocked one.
	_screen._on_browse_pressed()
	await get_tree().create_timer(0.3).timeout
	await _shot("lan_empty")
	_fill()
	_screen._refresh_lan_browser()
	await get_tree().create_timer(0.3).timeout
	await _shot("lan_full")
	get_tree().quit(0)

## Six entries: the count the row pool is sized for, so this is also the overflow test.
## One name is deliberately far too long — `clip_text` is supposed to eat it, and a row
## that grows instead would push CLOSE off the bottom of the panel.
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
