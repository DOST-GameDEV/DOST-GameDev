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
## Fired on the HOST the moment it resolves a knockdown on a tracked Can, carrying its
## own decision: `scored` false is the lucky fall (CharacterBase.LUCKY_FALL_CHANCE).
##
## Exists because that decision was, until now, observable nowhere except as a side
## effect on a counter — which made it untestable across peers and invisible to any HUD
## that wanted to show "3 falls, one of them free". Emitted for BOTH outcomes and before
## the counting below, so a listener sees every roll and not just the ones that pay.
signal can_fell(fallen: CharacterBase, scored: bool)

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

## User feedback, 2026-07-28: "if can falls 5 times they lose" — a backup win
## path for team slipper, independent of whether the Taya recovered each
## individual fall. Counts every Downed transition on a tracked Can this
## round, saved or not; reaching the limit ends the round immediately even if
## THIS particular fall would otherwise have been recoverable. Round-scoped,
## reset alongside time_left in both start_round() and reset().
##
## ⚠️ 5 -> 4, last of the four "too easy for the lata to get back up" levers —
## the full set is documented on `CharacterBase.DOWNED_SELF_RIGHT_WINDOW`. This is
## the backstop the other three feed into: it is the only path that pays the
## attacking side for knockdowns the taya keeps saving. Note it interacts with
## lever 2 — a lucky fall does NOT count here (see the handler below), so cutting
## `LUCKY_FALL_CHANCE` from 0.25 to 0.12 already made this counter tick faster;
## 4 is the deliberate step on top of that, not a duplicate of it.
##
## First guess, not a measurement — needs a human to actually play it.
const FALL_LIMIT: int = 4
var _fall_count: int = 0

## 3.4: read-only so the off-screen indicator (or anything else that needs
## "which unit is currently the Can") reads the one place that already tracks
## it correctly across a role swap, rather than re-scanning the scene tree for
## `is_can` and risking a second copy of that logic drifting from this one.
func get_tracked_cans() -> Array[CharacterBase]:
	return _tracked_cans.duplicate()

func register_can(can: CharacterBase) -> void:
	if can in _tracked_cans:
		return
	_tracked_cans.append(can)
	# ⚠️ THE CAN IS BOUND INTO THE CONNECTION. `state_changed` carries only the new
	# state, so the handler had no way to ask WHICH can changed — and therefore no
	# way to tell a scoring fall from a lucky one (CharacterBase.LUCKY_FALL_CHANCE),
	# which is a property of the can that just fell. Binding is the whole fix; the
	# alternative was widening a signal that four other places already listen to.
	#
	# ⚠️ AND THE GUARD BELOW HAS TO USE THE BOUND CALLABLE TOO. `bind()` produces a
	# DIFFERENT Callable, so `is_connected(_on_tracked_can_state_changed)` reports
	# false even when the bound one is connected — and register_can() is called
	# again on every single round (main.gd::_reregister_tracked_cans), so getting
	# this wrong would stack one extra connection per round and count every fall
	# twice by round 2, three times by round 3.
	var bound := _on_tracked_can_state_changed.bind(can)
	if not can.state_changed.is_connected(bound):
		can.state_changed.connect(bound)
	if not can.dents_changed.is_connected(_on_tracked_can_dents_changed):
		can.dents_changed.connect(_on_tracked_can_dents_changed)

func clear_tracked_cans() -> void:
	for can in _tracked_cans:
		if is_instance_valid(can):
			# Bound, to match register_can() — see its note.
			var bound := _on_tracked_can_state_changed.bind(can)
			if can.state_changed.is_connected(bound):
				can.state_changed.disconnect(bound)
			if can.dents_changed.is_connected(_on_tracked_can_dents_changed):
				can.dents_changed.disconnect(_on_tracked_can_dents_changed)
	_tracked_cans.clear()

## ⚠️⚠️ THE FALL COUNT IS TOLD TO THE HOST BY THE HOST, AND IT USED TO BE READ OFF A
## FLAG THE HOST DOES NOT OWN. MEASURED ON TWO REAL PEERS, 2026-07-30.
##
## `hitbox.gd` rolls the lucky fall host-side and ships the answer as its `kind`
## through `target._apply_hit_result.rpc_id(target.get_multiplayer_authority(), ...)`.
## That RPC lands on the CAN'S OWN PEER, which is where `go_downed(false)` runs and
## therefore where `last_fall_scored` is written. **`last_fall_scored` is not in
## CharacterBase.tscn's replication config**, so the host's own copy of it never changes
## from its `true` default for a can owned by a client.
##
## This handler used to read exactly that flag. So for a client-owned lata:
##   * the CAN self-righted correctly (the exception in `_physics_process`'s DOWNED
##     branch runs on the owning peer, which does have the right flag), so it LOOKED
##     right on every screen, and
##   * the host counted the fall toward FALL_LIMIT anyway.
## i.e. the lucky fall's entire purpose — *"this isn't a point for the enemy"* — was
## silently false for half the cans in any networked match, while visibly working.
##
## MEASURED with `tools/aim_probe.tscn -- net` (host + one real client, chance pinned to
## 0.5 so both outcomes appear): 33 knockdowns, and **every lucky fall observed was on a
## host-owned can — 0 of 26 on the client-owned one**, which at even odds is not chance.
## The host's rows read `flag_scored=true, fall_delta=1` on knockdowns the owning peer
## had been told were lucky.
##
## The fix is to stop asking a character we do not own about a decision we made
## ourselves. `hitbox.gd` calls this from the one place that is already host-only and
## already holds the answer, so the count now comes from the same machine and the same
## line as the roll.
##
## ⚠️ A LOCAL-PATH TEST CANNOT SEE ANY OF THIS. Non-networked, the host owns every
## character, so the flag is always correct and the old code passed. That is trap 1 in
## `Handoff_Physics_AI_LAN.md`, and it is why R-18's acceptance demands two real peers.
func host_note_fall(fallen: CharacterBase, scored: bool) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if not round_active or _tracked_cans.is_empty():
		return
	# ⚠️ PARENTHESISED. `not fallen in _tracked_cans` parses as `(not fallen) in
	# _tracked_cans` in GDScript — a bool tested for membership in an array of
	# CharacterBase, which is always false, so the guard would never fire.
	if fallen == null or not is_instance_valid(fallen) or not (fallen in _tracked_cans):
		return
	can_fell.emit(fallen, scored)
	# User feedback: "if can falls 5 times they lose" — counts the transition INTO
	# Downed, not Sealed, so a Taya who saves every single fall still loses the round on
	# the last one. A lucky fall is the exception and does not count: the can still
	# visibly went over and CharacterBase's DOWNED branch self-rights it, so it costs
	# the defence nothing and pays the offence nothing.
	if not scored:
		return
	_fall_count += 1
	if _fall_count >= FALL_LIMIT:
		report_round_win(false) # Slippers win regardless of this fall's own outcome

func _on_tracked_can_state_changed(new_state: int, fallen: CharacterBase) -> void:
	if not round_active or _tracked_cans.is_empty():
		return
	# ⚠️ THE FALL COUNT IS NO LONGER DONE HERE — see host_note_fall() above for the
	# measured reason. This handler is now only the all-Sealed win check.
	#
	# It reaches the host at all only because `CharacterBase.state` has a setter as of
	# 2026-07-30; before that, a synchronizer's write to a replicated property emitted
	# nothing and this function never ran on the host for a client-owned can, so BOTH
	# win paths were unreachable for half the cans in any match.
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

## Dev_Plan.md §3: "Cans win by the timer running out, OR by knocking Slippers
## out of bounds a set number of times" — Option A only; Option B's Can-win
## condition is survival to the timer, no ring-out clause. This second win path
## was never wired up: KillPlane.character_respawned fired a HUD toast
## ("OUT OF BOUNDS") and nothing else, so the round could only ever end by
## denting or by the timer. Found auditing the code against the GDD.
##
## Round-scoped, not match-scoped — reset alongside `time_left` in
## start_round()/reset() below, same lifetime as the timer it's an alternate
## win path for.
const RING_OUT_LIMIT: int = 3
var _ring_out_count: int = 0

## Called from main.gd's KillPlane.character_respawned handler, for the
## character that just respawned. Filters down to "was this THIS round's
## Tsinelas" itself (not the Can, not a Person) rather than trusting the
## caller, for the same reason register_can() re-derives is_can rather than
## trusting a bare bool: this file owns the round-win rule, nothing calling in
## should have to know its exact shape.
##
## Host-only when networked, matching report_round_win()'s own gate — KillPlane
## fires `body_entered` on every peer's local physics world (a replicated
## body's position is present there even when that peer doesn't own it), so
## every peer's own RoundManager would otherwise count the same fall once per
## peer. Only the host's count is ever acted on; a client's local increment is
## harmless (never read) but skipped anyway for clarity.
func register_ring_out(character: CharacterBase) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if not round_active or character == null or not is_instance_valid(character):
		return
	if GameLaunch.game_mode != GameLaunch.GameMode.OPTION_A:
		return # Option B has no ring-out clause
	if character.is_person or character.is_can:
		return # only the attacking Prop (this round's Tsinelas) counts
	_ring_out_count += 1
	if _ring_out_count >= RING_OUT_LIMIT:
		report_round_win(true) # Cans win the round

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
	_ring_out_count = 0
	_fall_count = 0
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
## starts (see main_menu.gd's _on_local_pressed()/_on_host_pressed()/
## _on_join_pressed()). Counterpart to
## MatchManager.reset() — see its doc for when this is called. round_active
## stays false until the next begin_next_round() actually starts a round,
## which also freezes input (character_base.gd) in the meantime —
## appropriate between a match ending and a rematch/new match.
func reset() -> void:
	clear_tracked_cans()
	time_left = ROUND_TIME
	round_active = false
	_sync_accum = 0.0
	_ring_out_count = 0
	_fall_count = 0

## Client-side mirror of the host's timer/round-active state. Unreliable is
## fine here — it's called every physics frame while a round is live and one
## dropped packet just means the HUD is stale for a frame, never wrong for long.
@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_state(new_time_left: float, new_round_active: bool) -> void:
	time_left = new_time_left
	round_active = new_round_active
