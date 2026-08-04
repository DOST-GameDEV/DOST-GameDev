extends Node
## THE SHIFTED MULTIPLAYER LAYOUT, PLAIN AND AT ITS WORST CASE. **Written 2026-08-02.**
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/ui/mp_shift_shot.tscn -- \
##         <out-dir-with-trailing-slash>
##
## 🧑 asked for everything except the bottom BACK row to move down. The block moved by 40,
## which leaves the status line a 48 px slot between JoinCaption's new bottom (816) and the
## bottom row (868) — so the question this answers is not "did it move" but "does the
## LONGEST message this screen can print still fit the slot it was squeezed into".
##
## ⚠️ PLAIN EXE, NOT --headless — no rendering device under headless on this machine, every
## capture comes back blank. Same trap lan_box_shot.gd and online_box_shot.gd document.
const SCREEN: String = "res://scenes/ui/MultiplayerSetup.tscn"

## The longest string in the file, from host_online_shot.gd — the one that already exists
## to prove the status line clears BACK.
const WORST: String = ("Every online server is in use right now. Open ONLINE SERVERS to "
	+ "join one of them, or try again in a minute.")

var _out: String = ""
var _screen: Node = null

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	_screen = load(SCREEN).instantiate()
	add_child(_screen)
	await get_tree().create_timer(1.2).timeout
	await _shot("shift_plain")

	var status: Label = _screen.get_node("%StatusLabel")
	status.text = WORST
	await get_tree().process_frame
	# The number that decides it: text height against the slot, and the slot against the
	# bottom row. Printed as well as photographed so a regression is greppable.
	var back: Control = _screen.get_node("%BackButton")
	print("[shift] status rect=%s text_height=%.1f" % [str(status.get_global_rect()),
		status.get_theme_font("font").get_multiline_string_size(status.text,
			HORIZONTAL_ALIGNMENT_LEFT, status.size.x, status.get_theme_font_size("font_size")).y])
	print("[shift] status bottom=%.1f  bottom row top=%.1f  clearance=%.1f" % [
		status.get_global_rect().end.y, back.get_global_rect().position.y,
		back.get_global_rect().position.y - status.get_global_rect().end.y])
	await _shot("shift_worst")
	get_tree().quit(0)

func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s%s.png" % [_out, tag])
	print("[shift] wrote ", tag)
