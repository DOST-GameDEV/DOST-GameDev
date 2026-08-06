extends CanvasLayer
class_name PauseLayer


signal toggle_requested

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_requested.emit()
		get_viewport().set_input_as_handled()

