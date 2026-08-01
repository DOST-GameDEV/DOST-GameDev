extends Node
class_name RoundManagerScript
## Registered as the "RoundManager" autoload singleton (Project Settings > Autoload).
## Referenced globally as `RoundManager`.

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE SCORING BUS. Rewritten 2026-07-31 on branch `HARRYDAKS`.
##
## WHAT THIS FILE IS NOW. The 90 s clock, and **the only place in the game a point
## is awarded**. Every rule in `Design.md` §Scoring resolves here, host-side, and
## reaches `MatchManager.add_score()` — which is itself the only writer of the
## score array. Two functions, one authority path, for all four scoring events.
##
## That is a deliberate shape and not just tidiness. The predecessor spread its
## win conditions across four files (`_step_can_out` here, `host_note_fall` here,
## `carriable.gd`'s direct-smash branch, and `hitbox.gd`'s seal) and the recurring
## bug class was a rule that fired on the wrong peer — a scored event that the
## host never saw, or saw twice. A point that can only be created in one function
## cannot be created on a client at all.
##
## WHAT WAS DELETED. `CAN_OUT_*` (the out-of-circle countdown), `FALL_LIMIT`,
## `_tracked_cans`, `register_ring_out`, `report_round_win`, `last_attack_time`.
## Those were the 2v2 ruleset's win conditions. **There is no per-round winner any
## more**: a round is 90 s of scoring, the totals persist, the Defender rotates.
## `Design.md` §7 is the record.
## ---------------------------------------------------------------------------

## Emitted when the 90 s clock expires. Nothing "wins" a round — this is a beat
## for audio and the HUD, not a result.
signal round_ended(round_number: int)
## The Lata went over. `by_slot` is the thrower who scored it, or -1 if nobody did
## (a Defender who knocks their own Lata down scores nothing and is not a thrower).
signal lata_knocked(by_slot: int)
## The Lata was stood back up by the Defender's channel.
signal lata_restored()
## A vulnerable Attacker was tagged. Drives the HUD toast and the VO callout.
signal attacker_tagged(defender_slot: int, victim_slot: int)

const ROUND_TIME: float = 90.0

## How often the host pushes the clock to clients. 0.25 s is four corrections a
## second against a HUD that only ever shows whole seconds, so a dropped packet is
## invisible.
const SYNC_INTERVAL: float = 0.25

## ---------------------------------------------------------------------------
## SCORING TABLE — `Design.md` §Scoring is the source of truth for these four.
## ---------------------------------------------------------------------------
const SCORE_LATA_KNOCKED: int = 100
const SCORE_SABOTAGE: int = 50
const SCORE_TAG: int = 100
const SCORE_DEFENSE_PER_TICK: int = 10
## The passive-defence tick. One second exactly, so "+10 PTS/sec" is literally
## what the number does rather than approximately what it does.
const DEFENSE_TICK_INTERVAL: float = 1.0

## ⚠️ `TAG_RADIUS` 1.1 WAS DELETED HERE ON 2026-08-01 BY ⚖️ `build fair`, AND IT
## HAD DECIDED NOTHING SINCE THE LUNGE LANDED. It was the passive proximity tag's
## reach; that tag was replaced on 2026-08-01 by `CharacterBase.LUNGE_TAG_RADIUS`
## (1.3), `_step_tag()` below became an empty hook, and grep showed the const had
## no reader left in the project — only its own doc comment and the history note
## further down. It was never in `Design.md`, which is the tell: a shipped number
## the balance source of truth does not list is a number nobody can reconcile.
## Left in place it is a trap, because "the tag radius" would resolve to 1.1 here
## and 1.3 in `character_base.gd` for the next person who greps for it. §2.6 is
## the live one and it is measured there.
## `Design.md` §6: a tagged Attacker is teleported to the Safe Zone and stunned.
const TAG_STUN_TIME: float = 5.0
## A shove that leads to a tag within this window pays the shover for the setup.
## `Design.md` §8. ⚠️ MEASURED 2026-08-01 — see the note on `note_shove()`.
const SABOTAGE_WINDOW: float = 2.5
## After the Lata is stood back up, nobody may throw for this long. Stops the
## Defender being re-knocked by a slipper that was already charged and waiting on
## the last frame of their `Lata.RESET_CHANNEL_TIME` channel.
const THROW_RESTORE_COOLDOWN: float = 1.25

var time_left: float = ROUND_TIME
var round_active: bool = false
var _sync_accum: float = 0.0
var _defense_accum: float = 0.0
var _throw_cooldown_left: float = 0.0

## Set by `main.gd` once the world is built. The Lata is a plain prop now
## (`scripts/objects/lata.gd`), not a player unit, so this is a reference and not
## a roster.
var lata: Lata = null
## Every Person in the match, indexed by player slot. `main.gd` registers them.
var _players: Array = [null, null, null, null]
## slot -> {"by": shover_slot, "at": _clock} written by `character_base.gd` when a
## shove lands, read by `_resolve_tag()`. Round-scoped.
var _shove_credit: Dictionary = {}
## Monotonic seconds since the round started. Used only for the sabotage window;
## deliberately not wall-clock so a paused game cannot expire it.
var _clock: float = 0.0

func register_player(who: CharacterBase) -> void:
	if who == null:
		return
	var slot := who.player_slot
	if slot < 0 or slot >= _players.size():
		return
	_players[slot] = who

func clear_players() -> void:
	_players = [null, null, null, null]
	_shove_credit.clear()

func player_at(slot: int) -> CharacterBase:
	if slot < 0 or slot >= _players.size():
		return null
	var who = _players[slot]
	return who if is_instance_valid(who) else null

func players() -> Array:
	var live: Array = []
	for who in _players:
		if is_instance_valid(who):
			live.append(who)
	return live

func defender() -> CharacterBase:
	return player_at(MatchManager.defender_slot)

## Read by `carrier.gd`'s throw gate and shown on the HUD as `THROW CD`.
func throw_cooldown_left() -> float:
	return _throw_cooldown_left

## The single legality test for a throw, so the HUD tell and the rule cannot
## disagree — the crosshair greys out for exactly the reasons the throw refuses.
## `Design.md`: holding a slipper, Lata upright, outside the box, off cooldown.
func can_throw(who: CharacterBase) -> bool:
	if who == null or not round_active:
		return false
	if who.is_defender:
		return false
	if not who.holding_slipper():
		return false
	if lata == null or not lata.is_upright:
		return false
	if _throw_cooldown_left > 0.0:
		return false
	return not who.is_inside_box()

## ---------------------------------------------------------------------------
## SHOVE CREDIT — the Sabotage score's memory.
## ---------------------------------------------------------------------------

## Called host-side by `character_base.gd` when a shove connects.
func note_shove(victim_slot: int, shover_slot: int) -> void:
	if victim_slot < 0 or shover_slot < 0 or victim_slot == shover_slot:
		return
	_shove_credit[victim_slot] = {"by": shover_slot, "at": _clock}

func _consume_shove_credit(victim_slot: int) -> int:
	if not _shove_credit.has(victim_slot):
		return -1
	var record: Dictionary = _shove_credit[victim_slot]
	_shove_credit.erase(victim_slot)
	if _clock - float(record.get("at", -999.0)) > SABOTAGE_WINDOW:
		return -1
	return int(record.get("by", -1))

## ---------------------------------------------------------------------------
## THE FOUR SCORING EVENTS.
## ---------------------------------------------------------------------------

## Called host-side by `lata.gd` when a thrown slipper puts it over. `by_slot` is
## the slipper's owner; -1 when nothing scoreable caused it.
func host_note_lata_knocked(by_slot: int) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if not round_active:
		return
	if by_slot >= 0 and by_slot != MatchManager.defender_slot:
		MatchManager.add_score(by_slot, SCORE_LATA_KNOCKED, "LATA DOWN")
	if NetworkManager.is_networked():
		_sync_lata_event.rpc(true, by_slot)
	else:
		lata_knocked.emit(by_slot)

## Called host-side by `lata.gd` when the Defender's channel completes.
func host_note_lata_restored() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	_throw_cooldown_left = THROW_RESTORE_COOLDOWN
	if NetworkManager.is_networked():
		_sync_lata_event.rpc(false, -1)
	else:
		lata_restored.emit()

## Broadcast so a client's HUD can pop the toast and start the throw-cooldown row
## on the same frame the host does, rather than inferring it from the next
## `_sync_state`.
@rpc("authority", "call_local", "reliable")
func _sync_lata_event(knocked: bool, by_slot: int) -> void:
	if knocked:
		lata_knocked.emit(by_slot)
	else:
		_throw_cooldown_left = THROW_RESTORE_COOLDOWN
		lata_restored.emit()

## ---------------------------------------------------------------------------
## THE TAG — host-side, every physics frame, one rule.
## ---------------------------------------------------------------------------
##
## ⚠️ THIS IS A PROXIMITY CHECK AND NOT AN `Area3D`, ON PURPOSE. The predecessor
## resolved contact through `hitbox.gd`'s overlap signals, and the recurring
## defect (recorded in that file and in § LOG) was that an overlap fires on
## whichever peer owns the body — so a tag could resolve on a client, or on
## nobody. Four players and one tag radius is sixteen distance checks a frame on
## the host; that is cheaper than one correct networked overlap and it can only
## happen where the score is written.
## ⚠️⚠️ THE PASSIVE PROXIMITY TAG WAS DELETED 2026-08-01 AND THIS FUNCTION IS NOW A
## RECORD OF WHY. It used to run every physics frame and tag any vulnerable attacker
## within 1.1 m of the taya — no input, no animation, no commitment. 100 points for
## standing close enough. (That 1.1 lived here as `TAG_RADIUS` until 2026-08-01; it
## is quoted inline now because the const had no reader left and was deleted.)
##
## 🧑 replaced it with a charged, aimed lunge on right-click: *"Tag Trigger: Any
## vulnerable Attacker caught in the lunge path is instantly tagged."* The tag is now
## driven from `CharacterBase._sweep_lunge_tag()`, which calls
## `host_resolve_lunge_tag()` below — the same resolution, reached by a press instead
## of by adjacency.
##
## ⚠️ IT IS KEPT AS AN EMPTY FRAME HOOK RATHER THAN REMOVED because `_physics_process`
## calls it and this is the one place contact is allowed to resolve; a future contact
## rule belongs here, on the physics tick, and not on `_process`.
func _step_tag() -> void:
	pass

## Called by the taya's lunge sweep, host-side only. Public because the caller is
## `character_base.gd` — the same shape `host_note_lata_knocked()` already uses, and
## the reason the scoring stays in one file (`Design.md` §8: a point can only be
## created where `MatchManager.add_score()` is reachable).
func host_resolve_lunge_tag(taya: CharacterBase, victim: CharacterBase) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if not round_active or taya == null or victim == null:
		return
	_resolve_tag(taya, victim)

func _resolve_tag(taya: CharacterBase, victim: CharacterBase) -> void:
	MatchManager.add_score(taya.player_slot, SCORE_TAG, "TAG")
	var saboteur := _consume_shove_credit(victim.player_slot)
	if saboteur >= 0 and saboteur != victim.player_slot:
		MatchManager.add_score(saboteur, SCORE_SABOTAGE, "SABOTAGE")
	victim.host_apply_tag_penalty(TAG_STUN_TIME)
	if NetworkManager.is_networked():
		_sync_tag.rpc(taya.player_slot, victim.player_slot)
	else:
		attacker_tagged.emit(taya.player_slot, victim.player_slot)

@rpc("authority", "call_local", "reliable")
func _sync_tag(defender_slot: int, victim_slot: int) -> void:
	attacker_tagged.emit(defender_slot, victim_slot)

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE MULTIPLAYER SOFTLOCK, AND WHY IT LIVES HERE RATHER THAN ON THE PLAYER.
## Fixed 2026-08-01. 🧑: *"non-host players can become softlocked and unable to
## move, throw, or interact after being tagged."*
##
## `main.gd` gives every human's character `set_multiplayer_authority(peer_id)` —
## a player owns their own body, which is what lets them drive it without asking.
## But four state changes on a character are decided by the HOST and have to reach
## everybody: the tag penalty, the shove, the body block, and the shove cooldown.
## Each of those was `@rpc("authority", "call_local", "reliable")` **declared on
## `character_base.gd`** — and in that mode the only peer allowed to call the RPC
## is the node's own authority, which is the VICTIM, not the host.
##
## So the host was calling four RPCs it had no right to call, on somebody else's
## node. `call_local` meant the host still ran the handler on ITS OWN copy of that
## character — teleporting it, stunning it, and starting a `SPAWN_SETTLE_FRAMES`
## freeze — while the victim's own machine, the one actually driving that body,
## either never heard about it or heard about it inconsistently. Two peers then
## disagreed about where a player was and whether they were stunned, and the
## MultiplayerSynchronizer replicates `position`/`state` FROM the authority, so
## the argument never resolved.
##
## ⚠️ THE FIX IS NOT "LOOSEN THE RPC MODE". Switching them to `any_peer` would let
## any client stun any other player, which is worse than the bug. They move to
## THIS node instead: `RoundManager` is an autoload, so its authority is the
## default — peer 1, the host — and `@rpc("authority")` on it means exactly what it
## is supposed to mean. The host is allowed to broadcast; nobody else is; every
## peer applies it to its own copy of the named seat.
##
## ⚠️ AND THE VICTIM IS NAMED BY SLOT, NOT BY NODE PATH. A `NodePath` to a
## character is per-peer (`Main/Players/-4/...` differs by spawn order and by
## whether a seat is a bot), and §2.24 records what happens when an RPC references
## a path a peer has not finished building. A slot is an int that means the same
## thing on all four machines.
## ---------------------------------------------------------------------------

## Host-side entry points. Each broadcasts, then every peer applies it locally.
func host_broadcast_tag_penalty(victim_slot: int, stun: float, safe_spot: Vector3) -> void:
	if NetworkManager.is_networked():
		_sync_tag_penalty.rpc(victim_slot, stun, safe_spot)
	else:
		_apply_tag_penalty_to(victim_slot, stun, safe_spot)

@rpc("authority", "call_local", "reliable")
func _sync_tag_penalty(victim_slot: int, stun: float, safe_spot: Vector3) -> void:
	_apply_tag_penalty_to(victim_slot, stun, safe_spot)

func _apply_tag_penalty_to(victim_slot: int, stun: float, safe_spot: Vector3) -> void:
	var who := player_at(victim_slot)
	if who != null:
		who.apply_tag_penalty_local(stun, safe_spot)

func host_broadcast_shove(victim_slot: int, impulse: Vector3, stun: float) -> void:
	if NetworkManager.is_networked():
		_sync_shove.rpc(victim_slot, impulse, stun)
	else:
		_apply_shove_to(victim_slot, impulse, stun)

@rpc("authority", "call_local", "reliable")
func _sync_shove(victim_slot: int, impulse: Vector3, stun: float) -> void:
	_apply_shove_to(victim_slot, impulse, stun)

func _apply_shove_to(victim_slot: int, impulse: Vector3, stun: float) -> void:
	var who := player_at(victim_slot)
	if who != null:
		who.apply_shove_local(impulse, stun)

func host_broadcast_block(blocker_slot: int, impulse: Vector3) -> void:
	if NetworkManager.is_networked():
		_sync_block.rpc(blocker_slot, impulse)
	else:
		_apply_block_to(blocker_slot, impulse)

@rpc("authority", "call_local", "reliable")
func _sync_block(blocker_slot: int, impulse: Vector3) -> void:
	_apply_block_to(blocker_slot, impulse)

func _apply_block_to(blocker_slot: int, impulse: Vector3) -> void:
	var who := player_at(blocker_slot)
	if who != null:
		who.apply_block_local(impulse)

func host_broadcast_shove_cooldown(shover_slot: int) -> void:
	if NetworkManager.is_networked():
		_sync_shove_cooldown.rpc(shover_slot)
	else:
		_apply_shove_cooldown_to(shover_slot)

@rpc("authority", "call_local", "reliable")
func _sync_shove_cooldown(shover_slot: int) -> void:
	_apply_shove_cooldown_to(shover_slot)

func _apply_shove_cooldown_to(shover_slot: int) -> void:
	var who := player_at(shover_slot)
	if who != null:
		who.apply_shove_cooldown_local()

## ---------------------------------------------------------------------------
## THE ROUND.
## ---------------------------------------------------------------------------

func start_round() -> void:
	# Every peer resets its own local clock display; only the host drives it.
	time_left = ROUND_TIME
	_clock = 0.0
	_defense_accum = 0.0
	_throw_cooldown_left = 0.0
	_shove_credit.clear()
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return # clients wait for the host's _sync_state RPC for `round_active`
	round_active = true
	_sync_accum = 0.0
	for who in players():
		who.reset_for_new_round()
	if lata != null:
		lata.host_reset_for_new_round()
	if NetworkManager.is_networked():
		_sync_state.rpc(time_left, round_active)

func _physics_process(_delta: float) -> void:
	# Contact is resolved on the physics tick, not the render tick — a tag decided
	# against last frame's transforms is a tag the victim already dodged.
	_step_tag()

func _process(delta: float) -> void:
	if not round_active:
		return
	_clock += delta
	if _throw_cooldown_left > 0.0:
		_throw_cooldown_left = maxf(0.0, _throw_cooldown_left - delta)
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return # clients: time_left/round_active only ever change via _sync_state
	time_left = maxf(0.0, time_left - delta)
	_step_passive_defense(delta)
	if NetworkManager.is_networked():
		_sync_accum += delta
		if _sync_accum >= SYNC_INTERVAL:
			_sync_accum = 0.0
			_sync_state.rpc(time_left, round_active, _throw_cooldown_left)
	if time_left <= 0.0:
		_on_time_up()

## +10 per whole second the Lata is upright. The accumulator is drained by a
## subtraction rather than reset to zero, so a frame that overshoots the tick
## carries its remainder forward — at 60 fps that is the difference between 90
## ticks a round and 89.
func _step_passive_defense(delta: float) -> void:
	if lata == null or not lata.is_upright:
		_defense_accum = 0.0
		return
	_defense_accum += delta
	while _defense_accum >= DEFENSE_TICK_INTERVAL:
		_defense_accum -= DEFENSE_TICK_INTERVAL
		MatchManager.add_score(MatchManager.defender_slot, SCORE_DEFENSE_PER_TICK, "DEFENSE")

## B-18: this used to set `round_active = false` locally without ever RPCing the
## change, so clients kept believing the round was live until the next round's
## sync happened to arrive.
##
## ⚠️⚠️ §2.18 — `round_ended` IS BROADCAST NOW, AND IT WAS HOST-ONLY UNTIL
## 2026-08-01. `tools/ui/net_twopeer_probe.tscn` measured it directly: over a full
## round on two real peers it was **the single line differing between two otherwise
## byte-identical 33-event streams**. The signal fired on the host and reached
## nobody else, because the only thing a client ever learned about the round ending
## was `_sync_state`'s `round_active = false` — an UNRELIABLE packet that carries a
## bool, not an event.
##
## It had zero subscribers in `scripts/` on the day it was found, which is exactly
## why it needed fixing rather than noting: this is the beat the round-end sting,
## the VO callout and the HUD's own end-of-round state are all supposed to hang
## off, and every one of them would have been silently host-only the moment
## somebody connected one. A signal that is wrong only in multiplayer, and only
## once somebody uses it, is a bug that gets found during a recording.
##
## Reliable and `call_local`, the same shape `_sync_lata_event()` and `_sync_tag()`
## already use — the host runs its own handler through the RPC rather than emitting
## separately, so there is one code path and it cannot fire twice.
func _on_time_up() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if not round_active:
		return
	round_active = false
	if NetworkManager.is_networked():
		_sync_state.rpc(time_left, round_active)
		_sync_round_ended.rpc(MatchManager.round_number)
	else:
		round_ended.emit(MatchManager.round_number)
	MatchManager.report_round_result()

## ⚠️ IT WRITES `round_active` TOO. A client that receives this before the
## unreliable `_sync_state` that carries the same bool would otherwise emit
## "the round ended" while still believing it was live.
@rpc("authority", "call_local", "reliable")
func _sync_round_ended(which_round: int) -> void:
	round_active = false
	round_ended.emit(which_round)

## B-14: nothing reset this autoload between matches, so a second match resumed
## the first one's timer. Counterpart to `MatchManager.reset()`.
func reset() -> void:
	clear_players()
	lata = null
	time_left = ROUND_TIME
	round_active = false
	_sync_accum = 0.0
	_defense_accum = 0.0
	_throw_cooldown_left = 0.0
	_clock = 0.0

## Client-side mirror of the host's clock. Unreliable is fine: it is sent four
## times a second against a HUD that shows whole seconds, so a dropped packet is
## never visible. ⚠️ The third argument DEFAULTS, so a peer calling the
## two-argument form still resolves rather than failing the RPC outright.
@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_state(new_time_left: float, new_round_active: bool,
		new_throw_cooldown: float = 0.0) -> void:
	time_left = new_time_left
	round_active = new_round_active
	_throw_cooldown_left = new_throw_cooldown
