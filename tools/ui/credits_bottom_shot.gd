extends Node
const SCREEN: String = "res://scenes/ui/CreditsPanel.tscn"

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else ""
	var screen: Control = load(SCREEN).instantiate()
	add_child(screen)
	await get_tree().create_timer(0.8).timeout

	var scroll: ScrollContainer = _find_scroll(screen)
	if scroll == null:
		push_error("no ScrollContainer under CreditsPanel")
		get_tree().quit(1)
		return
	scroll.scroll_vertical = 1_000_000
	await get_tree().process_frame
	await get_tree().process_frame
	print("[credits] scrolled to %d" % scroll.scroll_vertical)

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%scredits_bottom.png" % out)
	print("[credits] wrote %scredits_bottom.png" % out)
	get_tree().quit(0)

func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for child in node.get_children():
		var found := _find_scroll(child)
		if found != null:
			return found
	return null

