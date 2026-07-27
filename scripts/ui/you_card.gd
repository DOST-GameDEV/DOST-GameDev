extends Control
class_name YouCard

## Q-5: tells the player which of the four units they're actually driving —
## review item 2's "role unclear on rejoin" gap. HUD.RoleLabel only ever shows
## which SIDE each team holds, never which unit is yours.
##
## Resolution differs by mode (see _find_local_character): networked reads
## main.gd's own is_multiplayer_authority() scan; Local Match scans for
## whichever unit currently holds player_id == 1. The debug switcher
## (scripts/systems/debug_player_switcher.gd) reassigns player_id at runtime
## when driving Tab/F1-F4 — this card polls on a plain timer rather than
## listening for a switch event, since the debug-code contract (Dev_Plan.md
## §0.3, protocol rule 11) forbids gameplay code from referencing anything
## debug-only, even a signal. Polling a public var stays correct with zero
## coupling in either direction.

const REFRESH_INTERVAL: float = 0.15

@onready var card: PanelContainer = %Card
@onready var class_label: Label = %ClassLabel
@onready var detail_label: Label = %DetailLabel

var _refresh_accum: float = 0.0

func _ready() -> void:
	# is_can / team_is_can_side flip on every role swap — a card populated
	# once here would be wrong from round 2 onward.
	MatchManager.round_started.connect(func(_round_number, _team_a_is_can): refresh())
	refresh()

func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= REFRESH_INTERVAL:
		_refresh_accum = 0.0
		refresh()

## Public so a late-joining client can force an immediate refresh (see
## main.gd::_sync_state_to_late_joiner, B-29) instead of waiting up to
## REFRESH_INTERVAL for the poll to catch it.
func refresh() -> void:
	var character := _find_local_character()
	if character == null or not is_instance_valid(character):
		visible = false
		return
	visible = true
	class_label.text = "PERSON" if character.is_person else ("CAN (LATA)" if character.is_can else "TSINELAS")
	var is_defense := character.team_is_can_side
	var team_letter := "A" if character.team == 0 else "B"
	# §4.2 hard rule: team identity is the letter mark, never hue — only the
	# accent bar and the OFFENSE/DEFENSE word track role colour.
	detail_label.text = "TEAM %s · %s" % [team_letter, "DEFENSE" if is_defense else "OFFENSE"]
	var accent := UiTheme.DEFENSE if is_defense else UiTheme.OFFENSE
	card.add_theme_stylebox_override("panel",
		UiTheme.card_style(Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.55), Color(0, 0, 0, 0), accent))

func _find_local_character() -> CharacterBase:
	if NetworkManager.is_networked():
		var main := get_tree().current_scene
		if main and main.has_method("get_local_character"):
			return main.get_local_character()
		return null
	return _find_by_player_id(get_tree().current_scene, 1)

func _find_by_player_id(node: Node, id: int) -> CharacterBase:
	if node is CharacterBase and node.player_id == id:
		return node
	for child in node.get_children():
		var found := _find_by_player_id(child, id)
		if found:
			return found
	return null
