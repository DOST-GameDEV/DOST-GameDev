extends CanvasLayer
class_name DebugBar

## Dev_Plan.md §3.5.4 — the switcher's on-screen readout.
##
## ⚠️ DEBUG-ONLY, removed by the §3.5.5 checklist along with
## `debug_player_switcher.gd` and this scene.
##
## Deliberately ugly: plain white monospace on a black strip, with NO reference
## to `UiTheme` and no theme of its own, so nobody mistakes it for shipping UI
## and so removing it can never leave a hole in the real design system. That
## also means the `theme_override_*` calls below are correct here and only here
## — this bar must not inherit the project theme.

@onready var _slots_label: Label = $Root/Slots
@onready var _keys_label: Label = $Root/Keys

func _ready() -> void:
	# Same self-disable as the switcher: gone in a release build even if the
	# removal checklist was never run.
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS

	for label in [_slots_label, _keys_label]:
		label.add_theme_font_override("font", ThemeDB.fallback_font)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 13)
	# One slot since the 2026-07-29 input overhaul — Shift+F1-F4 and F5 (solo)
	# both addressed the second slot, which no longer exists. See
	# debug_player_switcher.gd::_apply_slots for why there can only be one.
	_keys_label.text = "F1-F4 drive · Tab cycle · F6 reset"

	# Debug registers itself with debug; no gameplay script names either one.
	DebugPlayerSwitcher.debug_register_bar(self)
	tree_exiting.connect(DebugPlayerSwitcher.debug_unregister_bar)

	# §3.5.4: after a role swap you need to see at a glance that the unit you
	# are holding is now the Can — is_can and team_is_can_side both flip here.
	MatchManager.round_started.connect(_on_round_started)

func _on_round_started(_round_number: int, _defender_slot: int) -> void:
	DebugPlayerSwitcher.debug_refresh_readout()

func debug_refresh(driven_text: String) -> void:
	_slots_label.text = "DEBUG  ▶ %s" % driven_text
