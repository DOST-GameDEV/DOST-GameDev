extends CanvasLayer
class_name PauseLayer

## Q-3/B-64: Main.tscn's own root node (running main.gd) sits at the default
## PROCESS_MODE_INHERIT, so once Local Match actually pauses the tree
## (get_tree().paused = true), Main stops receiving _unhandled_input
## entirely — including the very Esc press meant to resume it. Confirmed live
## with a standalone headless test: an INHERIT-mode node's _unhandled_input
## never fires while SceneTree.paused is true, only an ALWAYS-mode node's
## does. This node is PROCESS_MODE_ALWAYS (set in Main.tscn) specifically so
## the pause TOGGLE survives the pause it causes; main.gd still owns
## everything else about pausing (the freeze itself, the overlay contents,
## the Resume/Menu buttons — those already work while paused because they're
## children of this same ALWAYS-mode layer).

signal toggle_requested

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_requested.emit()
		get_viewport().set_input_as_handled()
