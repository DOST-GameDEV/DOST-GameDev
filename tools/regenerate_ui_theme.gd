extends SceneTree


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

