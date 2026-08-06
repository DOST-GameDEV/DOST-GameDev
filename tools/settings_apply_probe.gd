extends Node

const SETTINGS_PATH: String = "user://settings.cfg"

var _fails: int = 0

func _ready() -> void:
	await get_tree().process_frame
	var original := SettingsManager.mouse_sensitivity
	var staged := 3.7 if not is_equal_approx(original, 3.7) else 1.4
	print("[apply] original sensitivity  %.2f" % original)

	SettingsManager.begin_edit()
	SettingsManager.set_mouse_sensitivity(staged)
	_check("in-memory value took effect immediately (live, not previewed away)",
		is_equal_approx(SettingsManager.mouse_sensitivity, staged))
	_check("has_unsaved_changes() is true after a staged edit",
		SettingsManager.has_unsaved_changes())
	_check("the FILE still holds the old value while staged",
		is_equal_approx(_on_disk(), original),
		"disk=%.2f expected=%.2f" % [_on_disk(), original])

	SettingsManager.commit_edit()
	_check("commit_edit() wrote the staged value to the file",
		is_equal_approx(_on_disk(), staged),
		"disk=%.2f expected=%.2f" % [_on_disk(), staged])
	_check("has_unsaved_changes() is false once committed",
		not SettingsManager.has_unsaved_changes())

	SettingsManager.begin_edit()
	SettingsManager.set_mouse_sensitivity(9.9)
	_check("has_unsaved_changes() is true again mid-edit",
		SettingsManager.has_unsaved_changes())
	SettingsManager.revert_edit()
	_check("revert_edit() restored the in-memory value",
		is_equal_approx(SettingsManager.mouse_sensitivity, staged),
		"memory=%.2f expected=%.2f" % [SettingsManager.mouse_sensitivity, staged])
	_check("revert_edit() left the file at the last committed value",
		is_equal_approx(_on_disk(), staged),
		"disk=%.2f expected=%.2f" % [_on_disk(), staged])
	_check("has_unsaved_changes() is false after a discard",
		not SettingsManager.has_unsaved_changes())

	var action := String(SettingsManagerScript.REBINDABLE_ACTIONS[0])
	var before := SettingsManager.get_binding_display_name(action)
	SettingsManager.begin_edit()
	SettingsManager.rebind_action(action, KEY_F9)
	_check("a rebind registers as an unsaved change",
		SettingsManager.has_unsaved_changes())
	SettingsManager.revert_edit()
	_check("revert_edit() puts the rebound key back",
		SettingsManager.get_binding_display_name(action) == before,
		"now=%s expected=%s" % [SettingsManager.get_binding_display_name(action), before])

	SettingsManager.set_mouse_sensitivity(original)
	print("=== settings_apply_probe: %s ===" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)

func _on_disk() -> float:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return -1.0
	return float(config.get_value("camera", "mouse_sensitivity", -1.0))

func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s%s" % ["PASS" if ok else "FAIL", what,
		"" if detail == "" else "   (%s)" % detail])

