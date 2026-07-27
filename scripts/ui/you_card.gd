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
## Q-6: how long the "just became ready again" flash lasts. Deliberately not
## reusing character_visual.gd's FLASH_DURATION — that one is about a hit
## landing on a 3D mesh, this one is a 2D meter filling back up; no reason
## the two have to move in lockstep just because they're both "a flash".
const READY_FLASH_DURATION: float = 0.2

@onready var card: PanelContainer = %Card
@onready var class_label: Label = %ClassLabel
@onready var detail_label: Label = %DetailLabel
@onready var guard_dash_row: HBoxContainer = %GuardDashRow
@onready var guard_dash_key_label: Label = %GuardDashKeyLabel
@onready var guard_dash_bar: ProgressBar = %GuardDashBar

var _refresh_accum: float = 0.0
var _character: CharacterBase = null
var _was_ready: bool = true ## last-seen guard/dash readiness, for the Q-6 "back to full" flash
var _bar_flash_tween: Tween = null

func _ready() -> void:
	# is_can / team_is_can_side flip on every role swap — a card populated
	# once here would be wrong from round 2 onward.
	MatchManager.round_started.connect(func(_round_number, _team_a_is_can): refresh())
	guard_dash_bar.add_theme_stylebox_override("fill", _bar_style(UiTheme.HIGHLIGHT))
	guard_dash_bar.add_theme_stylebox_override("background", _bar_style(UiTheme.CARD))
	refresh()

func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= REFRESH_INTERVAL:
		_refresh_accum = 0.0
		refresh()
	_update_guard_dash_meter()

## Public so a late-joining client can force an immediate refresh (see
## main.gd::_sync_state_to_late_joiner, B-29) instead of waiting up to
## REFRESH_INTERVAL for the poll to catch it.
func refresh() -> void:
	_character = _find_local_character()
	if _character == null or not is_instance_valid(_character):
		visible = false
		return
	visible = true
	class_label.text = "PERSON" if _character.is_person else ("CAN (LATA)" if _character.is_can else "TSINELAS")
	var is_defense := _character.team_is_can_side
	var team_letter := "A" if _character.team == 0 else "B"
	# §4.2 hard rule: team identity is the letter mark, never hue — only the
	# accent bar and the OFFENSE/DEFENSE word track role colour.
	detail_label.text = "TEAM %s · %s" % [team_letter, "DEFENSE" if is_defense else "OFFENSE"]
	var accent := UiTheme.DEFENSE if is_defense else UiTheme.OFFENSE
	card.add_theme_stylebox_override("panel",
		UiTheme.card_style(Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.55), Color(0, 0, 0, 0), accent))
	# Q-6: Persons have no Guard/Dash (their assist slot is Tag/Throw) — an
	# always-empty bar would read as a bug, not as "not applicable to you".
	guard_dash_row.visible = not _character.is_person
	if guard_dash_row.visible:
		guard_dash_key_label.text = _guard_dash_key_label(_character)

## One bar with two meanings, picked by is_can: GUARD (stamina, drains as
## held) or DASH (cooldown, refills to ready). Updated every frame — unlike
## refresh() above, a meter that only moves every REFRESH_INTERVAL would
## visibly stutter.
func _update_guard_dash_meter() -> void:
	if _character == null or not is_instance_valid(_character) or _character.is_person:
		return
	var ratio: float = _character.get_guard_stamina_ratio() if _character.is_can else _character.get_dash_cooldown_ratio()
	guard_dash_bar.value = ratio * guard_dash_bar.max_value
	var is_ready := ratio >= 1.0
	if is_ready and not _was_ready:
		_flash_bar_ready()
	_was_ready = is_ready

## Q-6: flash to CARD (~off-white) for ~0.2s when the bar returns to full so
## 'ready again' is readable without watching the bar.
func _flash_bar_ready() -> void:
	if _bar_flash_tween != null and _bar_flash_tween.is_valid():
		_bar_flash_tween.kill()
	var style := _bar_style(UiTheme.CARD)
	guard_dash_bar.add_theme_stylebox_override("fill", style)
	_bar_flash_tween = create_tween()
	_bar_flash_tween.tween_property(style, "bg_color", UiTheme.HIGHLIGHT, READY_FLASH_DURATION)

func _bar_style(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(UiTheme.CORNER_RADIUS)
	return sb

## Reads the InputMap directly so a Settings rebind of guard_dash_p<N> keeps
## this label truthful without the card needing to know about Settings at all.
func _guard_dash_key_label(character: CharacterBase) -> String:
	var action := "guard_dash_p%d" % character.player_id
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode().to_upper()
	return "?"

## Returns the locally-controlled character resolved by the last refresh cycle.
## Use this from sibling HUD nodes rather than duplicating the scan logic —
## the you_card already polls every REFRESH_INTERVAL and caches the result.
func get_local_character() -> CharacterBase:
	return _character

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
