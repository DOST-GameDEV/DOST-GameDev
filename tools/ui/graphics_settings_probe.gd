extends Node
## DOES THE GRAPHICS SECTION ACTUALLY EXIST, BIND, APPLY AND PERSIST?
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/ui/graphics_settings_probe.tscn
##
## ⚠️ PLAIN EXE, NOT --headless — it loads a real match to get a real
## `WorldEnvironment` and a real `Camera3D`, and the motion-blur node needs the
## latter to exist at all.
##
## ⚠️ A SCREENSHOT CANNOT ANSWER THIS. The seven new ticks sit below the fold of the
## settings panel's scroll container, so `settings_shot_check.tscn` photographs a
## panel that looks completely unchanged whether they are there or not. Every check
## below is a state assertion instead.

const PANEL: String = "res://scenes/ui/SettingsPanel.tscn"

var _fails: int = 0

func _ready() -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.5).timeout

	var env: Environment = null
	for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		env = (node as WorldEnvironment).environment
		break
	_check(env != null, "a WorldEnvironment with an Environment exists")

	# 1 — every key has a box, and every box agrees with the manager.
	var panel: Node = load(PANEL).instantiate()
	add_child(panel)
	await get_tree().process_frame
	for key in SettingsManager.GRAPHICS_KEYS:
		var path: String = panel.GRAPHICS_CHECK_NODES.get(key, "")
		var box := panel.get_node_or_null(path) as CheckBox
		_check(box != null, "%s exists in the scene" % path)
		if box == null:
			continue
		_check(box.button_pressed == SettingsManager.graphics_option(key),
			"%s seeded from SettingsManager (%s)" % [key, box.button_pressed])

	# 2 — the defaults are the ones the human asked for: the three new effects off,
	# the four shipped ones on so nothing about the look changes.
	for key in ["motion_blur", "ssr", "taa"]:
		_check(not SettingsManager.graphics_option(key), "%s defaults OFF" % key)
	for key in ["sdfgi", "ssil", "ssao", "glow"]:
		_check(SettingsManager.graphics_option(key), "%s defaults ON" % key)

	# 3 — a toggle reaches the live Environment, not just the variable.
	SettingsManager.set_graphics_option("sdfgi", false)
	await get_tree().process_frame
	_check(not env.sdfgi_enabled, "unticking SDFGI cleared it on the live Environment")
	SettingsManager.set_graphics_option("sdfgi", true)
	await get_tree().process_frame
	_check(env.sdfgi_enabled, "re-ticking SDFGI set it back")

	# 4 — motion blur is a node that exists only while ticked.
	_check(get_tree().root.find_children("MotionBlur", "", true, false).is_empty(),
		"no MotionBlur node while the tick is off")
	SettingsManager.set_graphics_option("motion_blur", true)
	await get_tree().process_frame
	await get_tree().process_frame
	var blur := get_tree().root.find_children("MotionBlur", "", true, false)
	_check(blur.size() == 1, "exactly one MotionBlur node once ticked (found %d)" % blur.size())
	if blur.size() == 1:
		_check(blur[0].get_parent() is Camera3D, "it parented itself to the current Camera3D")
		var mat := (blur[0] as MeshInstance3D).material_override as ShaderMaterial
		_check(mat != null and mat.shader != null, "its shader loaded")
	SettingsManager.set_graphics_option("motion_blur", false)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(get_tree().root.find_children("MotionBlur", "", true, false).is_empty(),
		"unticking freed the MotionBlur node again")

	print("\n[graphics probe] %s" % ("ALL CHECKS PASSED" if _fails == 0
		else "%d CHECK(S) FAILED" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])
