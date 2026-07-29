extends Control
class_name YouCard

## Q-5: tells the player which of the four units they're actually driving —
## review item 2's "role unclear on rejoin" gap. HUD.RoleLabel only ever shows
## which SIDE each team holds, never which unit is yours.
##
## Resolution differs by mode (see _find_local_character): networked reads
## main.gd's own is_multiplayer_authority() scan; Single Player scans for
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
## Checklist 0.1's remaining half — the moodboard's "charged throw (glow)" on
## THE ATTACKER card. This is the HOOK, not the treatment: if the design lane
## assigns a `ShaderMaterial` to `charge_bar` (its `CanvasItem.material`, set in
## the editor or from code — nothing here creates one), this uniform is kept
## live at 0..1 for as long as charging is active and snapped to 0 the instant
## it stops. No material means no-op; `set_shader_parameter` on a plain
## `StyleBoxFlat` fill is a silent no-op path, this is the actual node-level one.
const CHARGE_SHADER_PARAM: StringName = &"charge_ratio"

@onready var card: PanelContainer = %Card
@onready var class_label: Label = %ClassLabel
@onready var detail_label: Label = %DetailLabel
@onready var guard_dash_row: HBoxContainer = %GuardDashRow
@onready var guard_dash_key_label: Label = %GuardDashKeyLabel
@onready var guard_dash_bar: ProgressBar = %GuardDashBar
## 0.1 — carrier.gd emits charge_changed/held_changed/reset_channel_changed and
## nothing consumed any of them (Checklist 0.1). Charge + held apply only to
## the attacking Person (the only one who ever holds a slipper); the reset
## channel applies only to the defending Person (the taya). Mirrors the split
## the moodboard itself draws: THE ATTACKER card shows the charged-throw glow,
## THE DEFENDER card shows the lata reset channel.
@onready var hold_label: Label = %HoldLabel
@onready var charge_row: HBoxContainer = %ChargeRow
@onready var charge_key_label: Label = %ChargeKeyLabel
@onready var charge_bar: ProgressBar = %ChargeBar
@onready var reset_channel_row: HBoxContainer = %ResetChannelRow
@onready var reset_channel_key_label: Label = %ResetChannelKeyLabel
@onready var reset_channel_bar: ProgressBar = %ResetChannelBar

var _refresh_accum: float = 0.0
var _character: CharacterBase = null
var _was_ready: bool = true ## last-seen guard/dash readiness, for the Q-6 "back to full" flash
var _bar_flash_tween: Tween = null
## The local character's Carrier component, whose three signals feed the rows
## above. Resolved alongside _character in refresh() rather than looked up
## fresh every signal — a Person's own Carrier node never changes mid-match.
var _carrier: Carrier = null
var _is_attacker_person: bool = false
var _is_defender_person: bool = false
var _charging: bool = false
var _channeling: bool = false

func _ready() -> void:
	# is_can / team_is_can_side flip on every role swap — a card populated
	# once here would be wrong from round 2 onward.
	MatchManager.round_started.connect(func(_round_number, _team_a_is_can): refresh())
	guard_dash_bar.add_theme_stylebox_override("fill", _bar_style(UiTheme.HIGHLIGHT))
	guard_dash_bar.add_theme_stylebox_override("background", _bar_style(UiTheme.CARD))
	# Plain, role-consistent colours (§4.2: orange = offense, blue = defence) —
	# not a restyle, just the same two hex constants every other role-coloured
	# element already uses. The Opus design lane picks the actual moodboard
	# treatment (charge glow, progress-bar chrome) on top of this structure.
	charge_bar.add_theme_stylebox_override("fill", _bar_style(UiTheme.OFFENSE))
	charge_bar.add_theme_stylebox_override("background", _bar_style(UiTheme.CARD))
	reset_channel_bar.add_theme_stylebox_override("fill", _bar_style(UiTheme.DEFENSE))
	reset_channel_bar.add_theme_stylebox_override("background", _bar_style(UiTheme.CARD))
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
		_set_carrier(null)
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
	# 0.1: role flips every round (team_is_can_side), so which of the two rows
	# below applies has to be re-derived here too, same trap as guard_dash_row
	# above — B-42/B-80(c) both hit "resolved once in _ready()".
	_is_attacker_person = _character.is_person and not is_defense
	_is_defender_person = _character.is_person and is_defense
	if _is_attacker_person:
		charge_key_label.text = "[%s]" % _action_key_label(_character, "special_ability")
	if _is_defender_person:
		reset_channel_key_label.text = "RIGHTING LATA [%s]" % _action_key_label(_character, "grab")
	_set_carrier(_character.get_node_or_null("Carrier") as Carrier)
	_update_row_visibility()

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
	return _action_key_label(character, "guard_dash")

## General form of the above — same InputMap read, any base action name.
## character.action_name() already applies the per-player _p<N> suffix
## (character_base.gd), so this stays correct after a Settings rebind without
## this card knowing which key is bound.
func _action_key_label(character: CharacterBase, base_action: String) -> String:
	for event in InputMap.action_get_events(character.action_name(base_action)):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode().to_upper()
	return "?"

## ---------------------------------------------------------------------------
## 0.1 — charge / hold / reset-channel meters. See the @onready block above.
## ---------------------------------------------------------------------------

## Connects/disconnects carrier.gd's three signals as the local character
## changes (in practice: null while it hasn't resolved yet, then fixed for the
## match — is_person never flips, only team_is_can_side does). Guarded both
## ways so a repeated refresh() with the same carrier never double-connects.
func _set_carrier(carrier: Carrier) -> void:
	if carrier == _carrier:
		return
	if _carrier != null and is_instance_valid(_carrier):
		if _carrier.charge_changed.is_connected(_on_charge_changed):
			_carrier.charge_changed.disconnect(_on_charge_changed)
		if _carrier.held_changed.is_connected(_on_held_changed):
			_carrier.held_changed.disconnect(_on_held_changed)
		if _carrier.reset_channel_changed.is_connected(_on_reset_channel_changed):
			_carrier.reset_channel_changed.disconnect(_on_reset_channel_changed)
	_carrier = carrier
	_charging = false
	_channeling = false
	hold_label.text = "GO GET IT"
	if _carrier != null:
		_carrier.charge_changed.connect(_on_charge_changed)
		_carrier.held_changed.connect(_on_held_changed)
		_carrier.reset_channel_changed.connect(_on_reset_channel_changed)

func _on_charge_changed(power: float) -> void:
	_charging = power >= 0.0
	if _charging:
		charge_bar.value = power * charge_bar.max_value
	_set_charge_shader_param(power if _charging else 0.0)
	_update_row_visibility()

## The hook itself — see CHARGE_SHADER_PARAM's doc above.
func _set_charge_shader_param(ratio: float) -> void:
	var mat := charge_bar.material
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter(CHARGE_SHADER_PARAM, ratio)

func _on_held_changed(held: Carriable) -> void:
	hold_label.text = "SLIPPER READY" if held != null else "GO GET IT"

func _on_reset_channel_changed(progress: float) -> void:
	_channeling = progress >= 0.0
	if _channeling:
		reset_channel_bar.value = progress * reset_channel_bar.max_value
	_update_row_visibility()

## Combines the role gate (re-derived every refresh(), since role swaps every
## round) with the activity gate (driven by the signals above) without either
## one clobbering the other. hold_label hides while actively charging — the
## charge bar itself already says "you have it", so showing both at once is
## redundant and is the difference between the card fitting in the space a
## Prop's single Guard/Dash row already uses and needing more of it.
func _update_row_visibility() -> void:
	hold_label.visible = _is_attacker_person and not _charging
	charge_row.visible = _is_attacker_person and _charging
	reset_channel_row.visible = _is_defender_person and _channeling

## Returns the locally-controlled character resolved by the last refresh cycle.
## Use this from sibling HUD nodes rather than duplicating the scan logic —
## the you_card already polls every REFRESH_INTERVAL and caches the result.
##
## Validated here, not just left to the next poll: `_character` can be freed
## in the gap between two refresh cycles (up to REFRESH_INTERVAL, ~9 frames at
## 60fps) — measured live during 4.2/4.3's two-instance testing, where a
## fresh --join= still has the local-test dummy units in the tree for the
## first few frames (main.gd's own _ready() hasn't run _clear_local_test_characters()
## yet — children ready before parents) and this card's very first refresh()
## can cache one of them. A caller with a raw, unchecked freed reference is
## worse than returning null: passing it into a TYPED parameter (e.g.
## offscreen_indicators.update()) fails Godot's own argument type-check
## before that function's body — and its is_instance_valid() guard — ever run.
##
## ⚠️ `is_instance_valid(_character)` alone, NOT `_character != null and
## not is_instance_valid(_character)`. Measured live: for a FREED (not null)
## Object reference, GDScript's own `!=` already treats it as equal to null
## in a plain comparison — so the `_character != null` half of that guard is
## false for exactly the freed case it exists to catch, short-circuits the
## `and`, and falls through to `return _character`, handing the caller the
## same poisoned reference back. It merely COMPARES as null from then on;
## it is not reassigned to an actual null literal, so it still fails the
## same argument type-check downstream. `is_instance_valid()` alone handles
## both a real null and a freed reference correctly, with no error either way.
func get_local_character() -> CharacterBase:
	if not is_instance_valid(_character):
		return null
	return _character

func _find_local_character() -> CharacterBase:
	if NetworkManager.is_networked():
		var main := get_tree().current_scene
		if main and main.has_method("get_local_character"):
			return main.get_local_character()
		return null
	return _find_hardware_character(get_tree().current_scene)

## ⚠️ FINDS THE UNIT THE KEYBOARD ACTUALLY DRIVES, not `player_id == 1`.
##
## This used to scan for player_id 1, which worked only because the debug
## switcher granted control BY REASSIGNING player_id — so "slot 1" and "the unit
## you are driving" were the same thing by construction. The 2026-07-29 input
## overhaul collapsed the four action sets into one and the switcher now moves
## AI control and `input_parked` instead, leaving player_id fixed for the match.
## Scanning for 1 would therefore pin the YOU card to whichever unit was dealt
## slot 1 and leave it there while you Tab through the other three.
##
## Matches `character_base.gd::_reads_hardware()` — not AI-driven, not parked —
## which is the same predicate tools/input_probe.gd asserts is true for at most
## one local unit at a time. That uniqueness is what makes "first match wins"
## correct here rather than arbitrary.
func _find_hardware_character(node: Node) -> CharacterBase:
	var ch := node as CharacterBase
	if ch != null:
		var ai_driven: bool = ch.ai_controller != null and ch.ai_controller.is_enabled()
		if not ai_driven and not ch.input_parked:
			return ch
	for child in node.get_children():
		var found := _find_hardware_character(child)
		if found:
			return found
	return null
