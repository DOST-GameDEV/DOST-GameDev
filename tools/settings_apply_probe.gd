extends Node
## DOES APPLY / DISCARD ACTUALLY STAGE ANYTHING? **Written 2026-08-02.**
##
##     Godot_v4.7.1-stable_win64_console.exe --headless --path <repo> \
##         tools/settings_apply_probe.tscn
##
## ⚠️⚠️ IT READS `settings.cfg` OFF DISK BETWEEN EVERY STEP, which is the whole point.
## 🧑 asked for an APPLY button; the risk of that request is shipping one that looks
## staged and is not, because every setter in `SettingsManager` wrote to disk on its own
## before today and a gate that fails open would leave that behaviour exactly as it was
## while the button implied otherwise. Asserting on the in-memory value would pass in
## that case. Only the FILE can tell you whether the write was really deferred.
##
## Four things are checked, in the order a player does them:
##   1. an edit inside begin_edit() does NOT reach the file
##   2. commit_edit() writes it
##   3. an edit then discarded by revert_edit() leaves neither file nor memory changed
##   4. has_unsaved_changes() tracks all of the above

const SETTINGS_PATH: String = "user://settings.cfg"

var _fails: int = 0

func _ready() -> void:
	await get_tree().process_frame
	# A value nothing else in the process is touching, and one whose "changed" is
	# unambiguous: a float compared against itself.
	var original := SettingsManager.mouse_sensitivity
	var staged := 3.7 if not is_equal_approx(original, 3.7) else 1.4
	print("[apply] original sensitivity  %.2f" % original)

	# --- 1. staged edits must not reach the file -----------------------------
	SettingsManager.begin_edit()
	SettingsManager.set_mouse_sensitivity(staged)
	_check("in-memory value took effect immediately (live, not previewed away)",
		is_equal_approx(SettingsManager.mouse_sensitivity, staged))
	_check("has_unsaved_changes() is true after a staged edit",
		SettingsManager.has_unsaved_changes())
	_check("the FILE still holds the old value while staged",
		is_equal_approx(_on_disk(), original),
		"disk=%.2f expected=%.2f" % [_on_disk(), original])

	# --- 2. commit writes it -------------------------------------------------
	SettingsManager.commit_edit()
	_check("commit_edit() wrote the staged value to the file",
		is_equal_approx(_on_disk(), staged),
		"disk=%.2f expected=%.2f" % [_on_disk(), staged])
	_check("has_unsaved_changes() is false once committed",
		not SettingsManager.has_unsaved_changes())

	# --- 3. discard puts memory AND file back --------------------------------
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

	# --- 4. a rebind stages too, not just a slider ---------------------------
	# ⚠️ CHECKED SEPARATELY BECAUSE IT TAKES A DIFFERENT ROUTE TO `_save()`. The sliders
	# go through their own setters; a rebind goes through `_set_binding()`, and the
	# snapshot has to carry the InputMap as well as the plain fields or BACK would
	# silently keep a rebind it claimed to discard.
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

	# Leave the machine as we found it.
	SettingsManager.set_mouse_sensitivity(original)
	print("=== settings_apply_probe: %s ===" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)

## Re-reads the config from disk every time — never cached, or step 1 would pass by
## reading a value that was written after the assertion it is meant to guard.
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
