extends Node
class_name RoundManagerScript
## Registered as the "RoundManager" autoload singleton (Project Settings > Autoload).
## Referenced globally as `RoundManager`, e.g. `RoundManager.start_round()`.

## Deliberately decoupled from movement/combat/hit-registration (see GDD Section 3).
## Session 7: a team is 1 Person + 1 Can/Slipper Prop — only the Prop is ever
## tracked here as a "Can". register_can() is only ever called with a
## character whose `is_can` is true, and `is_can` is now false for Persons
## unconditionally (see main.gd) — so Person-vs-Person or Person-vs-Prop hits
## never affect round-win, only Prop-vs-Prop does, matching the GDD.
## Round-win logic is still an open decision between two options:
##   Option A — Stock/Life (dents): Cans have a health bar, Slippers win by fully
##              denting a Can; Cans win on timer or ring-outs.
##   Option B — Capture the Base + Downed/Seal: hit knocks Can out of its base circle
##              into a Downed state, ~2s self-right window before a Tsinelas can "seal" it.
## Build/test both cheaply against the same single-player loop before committing (see
## docs/Dev_Plan.md, Section 3, Phase 1).

signal round_won(winning_team: int)

const ROUND_TIME: float = 90.0
## B-19: _sync_state used to RPC every rendered frame per client just to drive
## a HUD label that changes once a second — harmless on a LAN, but wasteful
## and easy to throttle. ~4Hz is still smooth for a timer display.
const SYNC_INTERVAL: float = 0.25

var time_left: float = ROUND_TIME
var round_active: bool = false
var _sync_accum: float = 0.0

## Session 6: MainMenu lets the player pick GameLaunch.game_mode (OPTION_A /
## OPTION_B) before a match starts — see game_launch.gd.
## Session 7: Option A is now implemented too (dents, see MAX_DENTS on
## CharacterBase and _on_tracked_can_dents_changed below) — hitbox.gd branches
## on GameLaunch.game_mode so a landed hit becomes a dent (Option A) instead of
## stagger/downed/seal (Option B). Both win checks are wired up here
## unconditionally, but only one ever actually fires per match: whichever mode
## isn't selected never has its corresponding signal (`state_changed` to
## SEALED, or `dents_changed` to MAX_DENTS) change in the first place.
## --- Option B testbed (all Cans Sealed = Slippers win) ---------------------------
## Not auto-populated on its own — call register_can() for whichever characters are
## playing Can this round (see scripts/main.gd for a working example). Deliberately
## opt-in rather than scanning the scene tree, since which characters ARE the Cans
## changes with the Attacker/Defender role swap each round (GDD Section 3). B-26:
## this used to say that reassignment "isn't implemented yet" — it has been since
## Session 7 (main.gd's _on_match_round_started re-registers whichever Prop is
## is_can true every round); this re-registration on every round_started is that
## reassignment, not a placeholder for it.
var _tracked_cans: Array[CharacterBase] = []

func register_can(can: CharacterBase) -> void:
	if can in _tracked_cans:
		return
	_tracked_cans.append(can)
	if not can.state_changed.is_connected(_on_tracked_can_state_changed):
		can.state_changed.connect(_on_tracked_can_state_changed)
	if not can.dents_changed.is_connected(_on_tracked_can_dents_changed):
		can.dents_changed.connect(_on_tracked_can_dents_changed)

func clear_tracked_cans() -> void:
	for can in _tracked_cans:
		if is_instance_valid(can):
			if can.state_changed.is_connected(_on_tracked_can_state_changed):
				can.state_changed.disconnect(_on_tracked_can_state_changed)
			if can.dents_changed.is_connected(_on_tracked_can_dents_changed):
				can.dents_changed.disconnect(_on_tracked_can_dents_changed)
	_tracked_cans.clear()

func _on_tracked_can_state_changed(_new_state: int) -> void:
	if not round_active or _tracked_cans.is_empty():
		return
	for can in _tracked_cans:
		if not is_instance_valid(can) or can.state != CharacterBase.State.SEALED:
			return
	report_round_win(false) # every tracked Can Sealed -> Slippers win the round

## Option A — parallel to the Option B check above, just watching `dents`
## instead of `state`. Never fires under Option B since dents never changes
## there (apply_dent() is Option-A-only, see hitbox.gd). Session 7 default:
## requires BOTH tracked Cans to hit MAX_DENTS (mirrors Option B's "every Can
## Sealed" rule) rather than either one alone — change the `for` loop below to
## `break` on the first fully-dented Can instead if you'd rather have EITHER
## Can alone end the round.
func _on_tracked_can_dents_changed(_new_dents: int) -> void:
	if not round_active or _tracked_cans.is_empty():
		return
	for can in _tracked_cans:
		if not is_instance_valid(can) or can.dents < CharacterBase.MAX_DENTS:
			return
	report_round_win(false) # every tracked Can fully dented -> Slippers win the round
## ----------------------------------------------------------------------------------

## Session 6: networked, this whole autoload becomes host-authoritative — same
## pattern as combat (see hitbox.gd/character_base.gd). The host runs the real
## timer and makes the real win call; clients just receive `_sync_state` RPCs
## and mirror `time_left`/`round_active` for HUD display, they never decide
## anything themselves. Non-networked local play is unaffected: every peer
## check below is a no-op when NetworkManager.is_networked() is false.

func start_round() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return # clients wait for the host's _sync_state RPC instead
	time_left = ROUND_TIME
	round_active = true
	_sync_accum = 0.0
	for can in _tracked_cans:
		if is_instance_valid(can):
			can.reset_for_new_round()
	if NetworkManager.is_networked():
		_sync_state.rpc(time_left, round_active)

func _process(delta: float) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return # clients: time_left/round_active only ever change via _sync_state
	if not round_active:
		return
	time_left = max(0.0, time_left - delta)
	if NetworkManager.is_networked():
		_sync_accum += delta
		if _sync_accum >= SYNC_INTERVAL:
			_sync_accum = 0.0
			_sync_state.rpc(time_left, round_active)
	if time_left <= 0.0:
		_on_time_up()

## B-18: this used to set round_active = false and report the win locally
## without ever RPCing the change, so clients kept believing the round was
## still live until the next round's _sync_round_started happened to arrive.
## report_round_win() already does exactly this (set round_active false, sync,
## emit, report) for the "Slippers sealed/dented every Can" win path — reuse
## it instead of duplicating the same steps minus the sync.
func _on_time_up() -> void:
	# Cans win on timer expiry — true under both Option A and Option B (GDD Section 3).
	report_round_win(true)

## Call this from whichever round-win option gets implemented first (Slippers denting
## a Can under Option A, or sealing it under Option B — see character_base.gd `seal()`).
## Host-only when networked — see class doc above.
func report_round_win(can_team_won: bool) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if not round_active:
		return
	round_active = false
	if NetworkManager.is_networked():
		_sync_state.rpc(time_left, round_active)
	round_won.emit(0 if can_team_won else 1)
	MatchManager.report_round_result(can_team_won)

## B-14: nothing reset this autoload between matches, so a second match
## resumed the first one's timer/tracked-Can state. Call before a fresh match
## starts (see main_menu.gd _go_to_match()). Counterpart to
## MatchManager.reset() — see its doc for when this is called. round_active
## stays false until the next begin_next_round() actually starts a round,
## which also freezes input (character_base.gd) in the meantime —
## appropriate between a match ending and a rematch/new match.
func reset() -> void:
	clear_tracked_cans()
	time_left = ROUND_TIME
	round_active = false
	_sync_accum = 0.0

## Client-side mirror of the host's timer/round-active state. Unreliable is
## fine here — it's called every physics frame while a round is live and one
## dropped packet just means the HUD is stale for a frame, never wrong for long.
@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_state(new_time_left: float, new_round_active: bool) -> void:
	time_left = new_time_left
	round_active = new_round_active
