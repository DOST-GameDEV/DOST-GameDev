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
##
## ⚠️⚠️ THERE IS ONE RULESET. 2026-07-31, 📋 `build rules` §8.2 — Option A (dents,
## `MAX_DENTS`, ring-outs) is DELETED, not disabled, and `Design.md` §7.2 is the record
## of what it was and why it went. The circle countdown (`_step_can_out`) is the game.
## Every `GameLaunch.game_mode` branch that used to live in this file is gone with it,
## including the one that gated the countdown — a gate that existed only because two
## rulesets did.

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

## §8.1: how long the ATTACKING side took to take the lata out on the round just
## finished, or `MatchManager.NEVER` if it never did. Written once per round by
## report_round_win() and read by MatchManager to score the set. Round-scoped like
## every other counter here.
##
## ⚠️ HOST-AUTHORITATIVE AND IT DOES NOT NEED ITS OWN RPC. The host is the only peer
## that ever calls report_round_win(), and it hands this straight to
## MatchManager.report_round_result(), whose result reaches clients through the
## match-level `_sync_round_started` / `_sync_match_won` broadcasts that already
## mirror the score. A client never scores a set itself, so it never reads this.
##
## ⚠️ `MatchManagerScript.NEVER`, NOT `MatchManager.NEVER`. This is a member-variable
## initializer, and `[autoload]` in `project.godot` brings **RoundManager up before
## MatchManager** — so the singleton is still null when this line runs and the
## instance form would crash the whole game on boot. The `class_name` form is a
## constant lookup on the script and needs no instance. Same reason the calls below
## use it too: one idiom, no line that only works because of when it happens to run.
var _last_attack_time: float = MatchManagerScript.NEVER

## Seconds the attackers took on the round just finished, or `MatchManagerScript.NEVER`.
func last_attack_time() -> float:
	return _last_attack_time

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE OUT-OF-CIRCLE COUNTDOWN — the defence's real job, and the attackers' main
## win condition since 2026-07-30. `Design.md` §5.2.
##
## Human instruction: *"during the defender match, if the can is outside the circle for
## 5 seconds, it is Game Over. If the can is knocked over by a slipper but manages to
## recover and return to the circle, the next 5-second countdown is permanently lowered
## by 0.75 seconds. This stacks up to 5 times (max 1.25 seconds)."*
##
## ⚠️ IT REPLACES THE AUTO-SEAL, IT DOES NOT SIT BESIDE IT. `character_base.gd` used to
## SEAL a lata that failed to self-right, and a sealed lata lost the round outright — so
## the whole game turned on a 1.25 s window and a coin flip (`LUCKY_FALL_CHANCE`) that
## existed only to soften it. The win has moved to something a player can SEE, can drive
## against, and can lose slowly: the can is off its mark, and the clock is running.
##
## ⚠️ THE STACK IS WHAT MAKES SAVING THE CAN A LOSING BATTLE RATHER THAN A LOOP. Without
## it a competent defence returns the lata every time and the countdown never matters —
## the round is a timer again, which is what the whole overhaul is trying to stop being
## true. Each save costs 0.75 s off the NEXT one, so the fifth save buys 1.25 seconds:
## barely more than one knockdown's `DOWNED_MAX_TIME`. The defence's own success is the
## thing that eventually kills it.
##
##     saves   0     1     2     3     4     5+
##     limit   5.00  4.25  3.50  2.75  2.00  1.25
##
## 0.9 m: the drawn ring is r 0.70 (`env_kit.gd::_base_circle_decal`) and a lata's own
## capsule is r 0.14, so 0.9 is "the can is touching its circle" rather than "the can's
## origin is inside a ring you can barely see it in". Sized to be forgiving, because the
## failure it produces ends a round.
const CAN_HOME_RADIUS: float = 0.9
const CAN_OUT_LIMIT_BASE: float = 5.0
const CAN_OUT_RECOVERY_STEP: float = 0.75
const CAN_OUT_RECOVERY_MAX: int = 5

## Seconds left before the attackers win, or -1.0 when every tracked can is home.
## Host-authoritative and mirrored to clients by `_sync_state` at SYNC_INTERVAL, the same
## 4 Hz the round timer already uses — this is a HUD number, not a physics one, and a
## quarter-second of staleness on a five-second clock is invisible.
var _can_out_left: float = -1.0
## How many times the defence has saved it this round. Round-scoped: reset alongside
## `time_left` in start_round() and reset(), same lifetime as `_fall_count`.
var _can_out_stacks: int = 0
## Whether a countdown was actually running last frame — the edge this reads to decide a
## RECOVERY happened. Without it, a can that never left the circle would bank a stack on
## the first frame of the round.
var _can_was_out: bool = false

## The limit the NEXT countdown starts from, after `_can_out_stacks` savings.
func can_out_limit() -> float:
	return maxf(CAN_OUT_LIMIT_BASE
		- CAN_OUT_RECOVERY_STEP * float(mini(_can_out_stacks, CAN_OUT_RECOVERY_MAX)),
		CAN_OUT_LIMIT_BASE - CAN_OUT_RECOVERY_STEP * float(CAN_OUT_RECOVERY_MAX))

## Seconds left on the live countdown, or -1.0 when the lata is home. Read by the HUD on
## every peer.
func can_out_left() -> float:
	return _can_out_left

func can_out_stacks() -> int:
	return _can_out_stacks

## ⚠️ HOST ONLY, AND IT WALKS THE TRACKED CANS RATHER THAN ASKING ONE. `_tracked_cans`
## is a list because Option A's dent rule needs it to be; in practice a round has one.
## The countdown runs while ANY tracked can is out, which is the reading that generalises
## correctly if a second one is ever added — a defence with two cans has to keep both
## home, not whichever one it prefers.
func _step_can_out(delta: float) -> void:
	# ⚠️ THE MODE GATE THAT USED TO OPEN THIS FUNCTION IS GONE (§8.2). It read
	# `if GameLaunch.game_mode != OPTION_B: return`, and it existed only to keep the
	# countdown out of a ruleset that no longer exists. With one ruleset the countdown
	# is unconditional — which also means `character_base.gd::can_self_right()`, which
	# reads this through `can_out_left()`, no longer has a mode in which it silently
	# behaves differently.
	if _tracked_cans.is_empty():
		_can_out_left = -1.0
		_can_was_out = false
		return
	var any_out := false
	for can in _tracked_cans:
		if can == null or not is_instance_valid(can):
			continue
		# Flat distance. A lata popped into the air by a faceslop is still over its own
		# circle and must not start the clock for being briefly off the floor.
		var flat := Vector2(can.global_position.x, can.global_position.z)
		if flat.length() > CAN_HOME_RADIUS:
			any_out = true
			break
	if not any_out:
		# HOME. Bank a recovery only if a countdown was genuinely running — see
		# `_can_was_out`. The stack is capped on read (`can_out_limit`) rather than on
		# write so the raw count stays honest for anything that wants to report it.
		if _can_was_out:
			_can_out_stacks += 1
			AudioManager.play_at("reset_channel_complete", Vector3.ZERO)
		_can_was_out = false
		_can_out_left = -1.0
		return
	if not _can_was_out:
		_can_was_out = true
		_can_out_left = can_out_limit()
		AudioManager.play_at("reset_channel_start", Vector3.ZERO)
	_can_out_left = maxf(0.0, _can_out_left - delta)
	if _can_out_left <= 0.0:
		report_round_win(false) # the Tsinelas side wins the round

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

func clear_tracked_cans() -> void:
	for can in _tracked_cans:
		if is_instance_valid(can):
			# Bound, to match register_can() — see its note.
			var bound := _on_tracked_can_state_changed.bind(can)
			if can.state_changed.is_connected(bound):
				can.state_changed.disconnect(bound)
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

## ----------------------------------------------------------------------------------
## ⚠️ `_on_tracked_can_dents_changed()` AND `register_ring_out()` WERE DELETED HERE
## (§8.2, 2026-07-31). They were Option A's two win checks — "every tracked can has
## taken `MAX_DENTS` hits" and "the attacking tsinelas has been knocked out of bounds
## `RING_OUT_LIMIT` times". Both are recorded in `Design.md` §7.2 rather than kept as
## dead branches. The kill-plane path that fed the ring-out counter still exists and
## still respawns a fallen unit; it simply no longer scores anything, which is what it
## did under the shipped ruleset anyway.
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
	_fall_count = 0
	_last_attack_time = MatchManagerScript.NEVER
	# ROUND-SCOPED, like every other counter here. The recovery stack must NOT survive a
	# round: it is the price of this round's saves, and carrying it forward would have a
	# team that defended well in round 1 start round 3 with a 1.25 s clock it never
	# earned there.
	_can_out_left = -1.0
	_can_out_stacks = 0
	_can_was_out = false
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
	# BEFORE the sync below, so the value that goes over the wire is this frame's, and
	# before the time-up check, so a countdown expiring on the same frame the round timer
	# does resolves as an attacker win rather than a defender one. That ordering is a
	# real decision: the lata was off its mark when the whistle went.
	_step_can_out(delta)
	if NetworkManager.is_networked():
		_sync_accum += delta
		if _sync_accum >= SYNC_INTERVAL:
			_sync_accum = 0.0
			_sync_state.rpc(time_left, round_active, _can_out_left, _can_out_stacks)
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

## Every win path in the game ends here: the circle countdown reaching zero
## (`_step_can_out`), `FALL_LIMIT` knockdowns (`host_note_fall`), a direct Ground
## Smash (`carriable.gd`), or the round timer expiring (`_on_time_up`, the only
## defender win). Host-only when networked — see class doc above.
##
## ⚠️ IT ALSO STOPS THE ATTACK CLOCK, which is what §8.1's set tiebreak is scored on.
## `last_attack_time()` is "how long the attacking side took to take the lata out this
## round", and `MatchManager.NEVER` when they did not — a defender win is by definition
## an attack that never landed. MatchManager compares the two teams' numbers at the end
## of a set; see its header for why one comparison covers both the win and the tiebreak.
func report_round_win(can_team_won: bool) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if not round_active:
		return
	round_active = false
	# Elapsed, not remaining. Measured off the same `time_left` the HUD shows, so a
	# caster's number and the scoring number are the same number.
	_last_attack_time = MatchManagerScript.NEVER if can_team_won else (ROUND_TIME - time_left)
	if NetworkManager.is_networked():
		_sync_state.rpc(time_left, round_active)
	round_won.emit(0 if can_team_won else 1)
	MatchManager.report_round_result(can_team_won, _last_attack_time)

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
	_fall_count = 0
	_last_attack_time = MatchManagerScript.NEVER
	_can_out_left = -1.0
	_can_out_stacks = 0
	_can_was_out = false

## Client-side mirror of the host's timer/round-active state. Unreliable is
## fine here — it's called every physics frame while a round is live and one
## dropped packet just means the HUD is stale for a frame, never wrong for long.
## ⚠️ THE TWO NEW ARGUMENTS DEFAULT, so a peer on an older build calling the
## two-argument form still resolves rather than failing the RPC outright — the same
## contract `carriable.gd::_rpc_set_flying` keeps for `lob`. -1.0 is the honest "no
## countdown is running" value, which is also what a peer that was never told should
## believe.
@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_state(new_time_left: float, new_round_active: bool,
		new_can_out_left: float = -1.0, new_can_out_stacks: int = 0) -> void:
	time_left = new_time_left
	round_active = new_round_active
	_can_out_left = new_can_out_left
	_can_out_stacks = new_can_out_stacks
