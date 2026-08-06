extends Node
const SCREEN: String = "res://scenes/ui/MultiplayerSetup.tscn"

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

