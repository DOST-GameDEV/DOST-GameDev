extends CanvasLayer
class_name DebugBar


@onready var _slots_label: Label = $Root/Slots
@onready var _keys_label: Label = $Root/Keys

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS

	for label in [_slots_label, _keys_label]:
		label.add_theme_font_override("font", ThemeDB.fallback_font)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 13)
	_keys_label.text = "F1-F4 drive · Tab cycle · F6 reset"

	DebugPlayerSwitcher.debug_register_bar(self)
	tree_exiting.connect(DebugPlayerSwitcher.debug_unregister_bar)

	MatchManager.round_started.connect(_on_round_started)

func _on_round_started(_round_number: int, _defender_slot: int) -> void:
	DebugPlayerSwitcher.debug_refresh_readout()

func debug_refresh(driven_text: String) -> void:
	_slots_label.text = "DEBUG  ▶ %s" % driven_text

