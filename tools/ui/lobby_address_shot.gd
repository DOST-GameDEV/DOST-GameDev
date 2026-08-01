extends Node
## Renders the lobby in its HOST and JOIN forms, and prints the address row's
## real contents.
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> --resolution 1600x900 \
##         tools/ui/lobby_address_shot.tscn -- out=C:/tmp/
##
## ⚠️ PLAIN EXE — it renders.
##
## 🧑 2026-08-01, with a screenshot of `CONNECTING TO 25.…`: *"cant see ip also
## make it copy pastable rlly easy"*. `matchsetup_shot.tscn` only ever drives the
## SOLO branch, which has no address at all, so nothing in `tools/` had ever
## photographed the two screens where the bug actually lived.
##
## It also prints what `host_addresses()` ranked and why, because the Hamachi
## complaint ("only the pc that configured hamachi can host") was never about
## hosting — it was about which of several local addresses the lobby advertised.

const MATCH_SETUP := "res://scenes/ui/MatchSetup.tscn"

var _out: String = ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("out="):
			_out = text.substr(4)
	if _out == "":
		_out = ProjectSettings.globalize_path("user://")
	_run.call_deferred()


func _run() -> void:
	print("[lobby] every local IPv4, ranked (Hamachi 25.x first, then private LAN):")
	for addr in MatchSetupScreen.host_addresses():
		var kind := "hamachi" if addr.begins_with("25.") else "lan/other"
		print("  %-18s %s" % [addr, kind])

	await _shoot("host", "host")
	await _shoot("join", "join")
	get_tree().quit(0)


func _shoot(action: String, stem: String) -> void:
	GameLaunch.pending_action = action
	if action == "join":
		# A Hamachi-shaped address, because its length is the whole complaint.
		GameLaunch.pending_join_address = "25.114.207.183:8910"
	var screen := load(MATCH_SETUP).instantiate() as Control
	add_child(screen)
	# The lobby builds its address row during _ready() and lays out a frame later.
	for _i in range(40):
		await get_tree().process_frame

	var row := screen.find_child("AddressRow", true, false) as Control
	var edit := screen.find_child("AddressEdit", true, false) as LineEdit
	# find_child, not "%SeatHeading": the heading is REPARENTED into a runtime
	# HBox by `_build_spectate_button()`, and a probe that asks for it by unique
	# name reports MISSING and looks like a bug in the screen.
	var heading := screen.find_child("SeatHeading", true, false) as Label
	print("[lobby] %s — heading %s" % [action, "'%s'" % heading.text if heading else "MISSING"])
	if row == null or edit == null:
		print("[lobby] %s — NO ADDRESS ROW" % action)
	else:
		print("[lobby] %s — row visible=%s  address '%s'  font %d"
			% [action, row.visible, edit.text,
				edit.get_theme_font_size("font_size")])
		# ⚠️ THE POINT OF THE FIX: it must be SELECTABLE and NOT TRUNCATED.
		print("[lobby] %s — selectable=%s editable=%s  fits=%s"
			% [action, edit.selecting_enabled, edit.editable,
				edit.get_theme_font(&"font").get_string_size(edit.text,
					HORIZONTAL_ALIGNMENT_LEFT, -1,
					edit.get_theme_font_size("font_size")).x <= edit.size.x])

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := "%slobby_%s.png" % [_out, stem]
	print("[lobby] %s -> %s" % [stem,
		path if get_viewport().get_texture().get_image().save_png(path) == OK else "FAILED"])
	screen.queue_free()
	await get_tree().process_frame
