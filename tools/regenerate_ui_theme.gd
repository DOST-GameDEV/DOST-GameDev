extends SceneTree

## Regenerates assets/ui/tumbang_preso.tres from scripts/ui/ui_theme.gd.
##
##     godot --headless -s tools/regenerate_ui_theme.gd
##
## The .tres is committed so the Godot editor previews the real styling at
## design time, but `ui_theme.gd` is the source of truth — run this and commit
## both whenever a constant changes. Never hand-edit the .tres.

const OUTPUT_PATH: String = "res://assets/ui/tumbang_preso.tres"

func _initialize() -> void:
	var theme := UiTheme.build()
	var err := ResourceSaver.save(theme, OUTPUT_PATH)
	if err != OK:
		push_error("Failed to write %s (error %d)" % [OUTPUT_PATH, err])
		quit(1)
		return
	print("Wrote ", OUTPUT_PATH)
	quit(0)
