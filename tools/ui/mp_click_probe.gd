extends Node
const SCREEN: String = "res://scenes/ui/MultiplayerSetup.tscn"

var _hits: Dictionary = {}

func _ready() -> void:
	var screen: Control = load(SCREEN).instantiate()
	get_tree().root.add_child.call_deferred(screen)
	await get_tree().process_frame
	get_tree().current_scene = screen
	await get_tree().create_timer(1.5).timeout

	var targets: Dictionary = {
		"HostOnlineButton": screen.get_node("%HostOnlineButton"),
		"HostButton": screen.get_node("%HostButton"),
		"JoinButton": screen.get_node("%JoinButton"),
		"BackButton": screen.get_node("%BackButton"),
	}
	for label in targets:
		var b: Button = targets[label]
		_hits[label] = 0
		b.pressed.connect(func() -> void: _hits[label] = int(_hits[label]) + 1)

	for label in targets:
		var b: Button = targets[label]
		var centre: Vector2 = b.get_global_rect().get_center()
		Input.warp_mouse(centre)
		await get_tree().process_frame
		await get_tree().process_frame
		var hovered: Control = screen.get_viewport().gui_get_hovered_control()
		var who: String = "<nothing>" if hovered == null else str(hovered.get_path())
		print("[probe] %-18s rect=%s centre=%s visible=%s hovered_by=%s" % [
			label, str(b.get_global_rect()), str(centre), str(b.is_visible_in_tree()), who])
		_click(centre)
		await get_tree().create_timer(0.15).timeout

	print("[probe] --- presses received ---")
	for label in targets:
		print("[probe]   %-18s %d" % [label, int(_hits[label])])
	get_tree().quit(0)

func _click(at: Vector2) -> void:
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)

