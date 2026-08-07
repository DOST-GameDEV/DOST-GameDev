extends Node
## DOES THE UPDATE PROMPT APPEAR, AND DOES IT APPEAR ONLY WHEN IT SHOULD?
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> --resolution 1280x720 \
##         tools/ui/update_probe.tscn -- out=C:/tmp/
##
## ⚠️ PLAIN EXE — the last phase renders the menu with the prompt on it.
##
## Two halves, because they fail differently:
##
##   COMPARISON  `UpdateCheck.is_newer()` against the cases that break the two
##               shortcuts somebody will eventually "simplify" this into. Pure
##               function, no network, so it is the part that can be asserted
##               exactly.
##   PROMPT      the button really is built, really is visible, and really is
##               hidden when there is nothing to install. Driven through
##               `apply_manifest()` with fixture JSON, so the probe depends on
##               neither the network nor on whatever is published today.
##
## ⚠️ THE FIRST VERSION OF THIS TRIED TO EXERCISE THE REAL TRANSPORT by writing a
## manifest to `user://` and pointing `check_now()` at a `file://` URL. Godot's
## `HTTPRequest` will not fetch that scheme, so the test failed for a reason that
## had nothing to do with the code under test — which is exactly the signal that
## the seam was in the wrong place. `apply_manifest()` was split out of the
## response handler in response, and everything that can genuinely be wrong (JSON
## shape, missing keys, the comparison, the quiet-on-junk contract) is now
## reachable without a socket.

var _out: String = ""
var _log: PackedStringArray = []
var _failures: int = 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("out="):
			_out = text.substr(4)
	if _out == "":
		_out = ProjectSettings.globalize_path("user://")
	_run.call_deferred()


func _emit(text: String) -> void:
	print(text)
	_log.append(text)


func _check(label: String, got: Variant, want: Variant) -> void:
	var ok: bool = got == want
	if not ok:
		_failures += 1
	_emit("  %s  %-46s got %s, want %s"
		% ["PASS" if ok else "FAIL", label, str(got), str(want)])


func _run() -> void:
	_emit("=== version comparison ===")
	# ⚠️ 4.9 vs 4.10 IS THE WHOLE REASON THIS IS NOT A STRING OR FLOAT COMPARE.
	# As strings "4.10" < "4.9"; as floats 4.10 == 4.1 < 4.9. Both say "no update"
	# for a release that IS newer, and this project crosses 4.9 within a few
	# releases of where it stands.
	_check("4.10 is newer than 4.9", UpdateCheck.is_newer("4.10", "4.9"), true)
	_check("4.9 is NOT newer than 4.10", UpdateCheck.is_newer("4.9", "4.10"), false)
	_check("4.69 is newer than 4.68", UpdateCheck.is_newer("4.69", "4.68"), true)
	_check("4.68 is NOT newer than itself", UpdateCheck.is_newer("4.68", "4.68"), false)
	_check("4.68 is NOT newer than 4.69", UpdateCheck.is_newer("4.68", "4.69"), false)
	_check("5.0 is newer than 4.99", UpdateCheck.is_newer("5.0", "4.99"), true)
	_check("4.100 is newer than 4.99", UpdateCheck.is_newer("4.100", "4.99"), true)
	# Junk must go QUIET, never loud — a false "update available" sends people to
	# a download that does not exist.
	_check("garbage version is refused", UpdateCheck.is_newer("banana", "4.68"), false)
	_check("empty version is refused", UpdateCheck.is_newer("", "4.68"), false)

	_emit("=== the prompt, driven off a local manifest ===")
	var local := GameVersion.string()
	var newer := UpdateCheck.is_newer("99.0", local)
	_check("the fixture really is newer than this build", newer, true)
	# The quiet-on-junk contract, before the happy path — a checker that shouts on
	# a 404 page or a truncated response is the one that sends people to a
	# download that does not exist.
	_check("html instead of json is refused",
		UpdateCheck.apply_manifest("<!doctype html><h1>404</h1>"), false)
	_check("json without a version is refused",
		UpdateCheck.apply_manifest('{"url":"https://example.invalid/x.zip"}'), false)
	_check("an OLDER published version is refused",
		UpdateCheck.apply_manifest('{"version":"0.1"}'), false)
	_check("still nothing available after three bad manifests",
		UpdateCheck.available, false)

	_check("a newer manifest is accepted", UpdateCheck.apply_manifest(JSON.stringify(
		{"version": "99.0", "url": "https://example.invalid/x.zip",
		"notes": "probe fixture"})), true)
	_check("update reported available", UpdateCheck.available, true)
	_check("version captured", UpdateCheck.latest_version, "99.0")

	var menu := await _render_menu("update_prompt_shown")
	var button := menu.find_child("UpdatePrompt", true, false) as Button
	_check("prompt button exists", button != null, true)
	if button != null:
		_check("prompt is visible", button.visible, true)
		_emit("  text: '%s'" % button.text)
	menu.queue_free()
	await get_tree().process_frame

	# ...and the negative case, which is the one a happy-path probe forgets.
	UpdateCheck.available = false
	UpdateCheck.latest_version = ""
	var menu2 := await _render_menu("update_prompt_hidden")
	var button2 := menu2.find_child("UpdatePrompt", true, false) as Button
	_check("prompt hidden when up to date", button2 == null or not button2.visible, true)
	menu2.queue_free()

	_emit("")
	_emit("UPDATE PROBE: %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	var file := FileAccess.open("user://update_probe.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	get_tree().quit(0 if _failures == 0 else 1)


func _render_menu(stem: String) -> Control:
	var menu := load("res://scenes/ui/MainMenu.tscn").instantiate() as Control
	add_child(menu)
	for _i in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s%s.png" % [_out, stem]
	_emit("  frame -> %s" % (path if image.save_png(path) == OK else "FAILED"))
	return menu
