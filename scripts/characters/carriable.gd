extends Node
class_name Carriable

## The tsinelas as a THROWN, RETRIEVED object — the Task 0 / Option B mechanic.
##
## Why this exists. Before Task 0 the Slipper was a character that walked around
## on its own legs. Nothing was ever thrown, nothing landed, nothing was picked
## up, and there was no scramble — which is exactly why the build did not read as
## tumbang preso. The street game is: throw your slipper at the guarded can, then
## scramble to get your slipper back without the taya tagging you. That retrieval
## scramble is the whole tension of the game, and this node is where it lives.
##
## Three states, which are also the three states the moodboard's THE SLIPPER card
## illustrates (docs/Dev_Plan.md §4.1 — "in-hand ready · thrown trajectory ·
## retrieval highlight"). That card is also the one card of the four with NO
## input badge, i.e. the art direction has described the slipper as an object,
## not a player, the entire time. The GDD is the doc that was out of step.
##
##   LOOSE   — lying on the ground. Its own player can still crawl it slowly and
##             exposed toward safety (CRAWL_SPEED_SCALE), or its team's Person
##             can run out and grab it. Both routes are taggable. This is the
##             scramble.
##   CARRIED — attached to a Person's hand. No self-movement; the Person aims it.
##   FLYING  — a real ballistic arc with a hitbox riding along, per ThrowProfile.
##
## WHO IT APPLIES TO. Lives on every CharacterBase, but is only ever meaningful
## on a team's Prop while that Prop is playing the Tsinelas side — see
## `is_throwable()`. A Can has one of these too; it simply reports false and
## never leaves LOOSE. `is_can` FLIPS EVERY ROUND (main.gd::_reset_world), so
## that is re-derived on demand and never cached in _ready().
##
## HOST-AUTHORITATIVE, deliberately and without exception. Holding a slipper
## decides whether a round can be won, so it follows the rule hit resolution
## already follows (hitbox.gd): clients ASK, the host DECIDES, the host
## broadcasts. Nothing here is client-asserted. Note the state is NOT put through
## CharacterBase.tscn's MultiplayerSynchronizer even though that would be less
## code — that synchronizer replicates outward from each character's OWN peer,
## not from the host, so routing held state through it would be precisely the
## client-asserted model this must not be.
##
## Carrying itself costs zero bandwidth: once every peer knows WHO is carrying,
## each recomputes the slipper's transform from that Person's hand locally.

enum CarryState { LOOSE, CARRIED, FLYING }

## How much of normal SPEED the slipper keeps while crawling itself back. Slow
## enough that crawling home across open ground is a real risk and calling your
## Person over is often better, fast enough that the Prop player is never simply
## parked. Tuning knob for the whole retrieval beat — start here.
const CRAWL_SPEED_SCALE: float = 0.45
## Flight is abandoned after this long even if nothing was hit, so a slipper
## launched into a gap in the geometry can never strand its team for the round.
const MAX_FLIGHT_TIME: float = 6.0
## The thrower is ignored for collisions for this long after release, so the
## slipper cannot immediately "land" on the hand that just threw it.
const THROWER_IGNORE_TIME: float = 0.25
## User feedback, 2026-07-28: a thrown slipper should bounce a bit instead of
## stopping dead on first contact — a rubber bakya/tsinelas skidding to a halt
## in one frame reads as a physics bug, not a landing. Reflects _flight_velocity
## off the collision normal (Vector3.bounce()) and keeps this fraction of its
## speed each time. Purely a physical/cosmetic change: hit resolution against a
## lata goes through _spawn_flight_hitbox()'s own Area3D overlap, entirely
## independent of move_and_collide's collision result below, so a slipper that
## bounces off a Can still scores the hit on first contact same as before.
## ⚠️ LOWERED same session: 0.45/2 bounces read as "ragdolls while flying" and
## fed the separate "barely has power even during full windup" report — an
## early clip on nearby clutter (crates, tires — up to 1.0 tall, and a throw
## launches around hand height) now only cost a MAX_BOUNCES=2 sequence, each
## keeping a still-substantial 45% of speed, which looks chaotic and reads as
## the whole throw losing its power rather than one clean skip. A single,
## weaker bounce is closer to "bounces a bit" than "physically simulates a
## rubber object," which was never the ask.
const BOUNCE_DAMPING: float = 0.3
## ⚠️ R-18(a) — SWEEPABLE, AND THE `const` ABOVE STAYS AS THE DOCUMENTED BASELINE.
## Identical shape to `AIController.taya_block_standoff`, which turned a
## three-runs-old question into one measurement for the cost of one line. Both of
## these numbers were tuned DOWN in one pass off a single feedback sentence and have
## never been judged since; sweeping them needs them writable from
## `tools/phys_probe.gd` (`bounce=` / `bounces=`) and nothing else.
## ⚠️ `static`, so it is process-wide and every slipper in the match answers to one
## value — which is correct (this is a property of the physics, not of a slipper) and
## is also why a probe must not leave it changed.
static var bounce_damping: float = BOUNCE_DAMPING
## After this many bounces, the next collision lands it (goes LOOSE) regardless
## of remaining speed, so a shallow-angle skip along the floor can't bounce
## forever. MAX_FLIGHT_TIME (6s) is the backstop under that. Lowered from 2 to
## 1 alongside BOUNCE_DAMPING above — one clean skip, not a multi-bounce
## ragdoll sequence.
const MAX_BOUNCES: int = 1
## R-18(a). See `bounce_damping` directly above for why both of these are sweepable
## and why the `const` is kept.
static var max_bounces: int = MAX_BOUNCES

## ---------------------------------------------------------------------------
## ⚠️⚠️ R-06 FALLOUT · A CEILING ON THE MID-FLIGHT STEER, AND IT IS NOT COSMETIC.
##
## `ThrowProfile.steer_strength` is an ACCELERATION (m/s² sideways), so the total
## lateral authority a throw has is `steer_strength * flight_time` — and the lob
## multiplies flight time by roughly six. Worked from the measured numbers rather
## than guessed:
##
##     throw_default flat  6.0 m/s^2 x 0.29 s  =  1.7 m/s of lateral authority
##     throw_flick   flat 10.0 m/s^2 x 0.23 s  =  2.3 m/s
##     throw_default LOB   6.0 m/s^2 x 1.67 s  = 10.0 m/s   <-- six times the flat
##
## That would have quietly broken the exact triangle R-06 is built on. The lob's
## counterplay is the can's dodge (`CAN_EVADE_LOOKAHEAD` sees it because it arrives
## slowly), and 10 m/s of lateral authority lets the slipper's own pilot simply steer
## back onto a dodging can — the longer flight would hand the attacking team MORE
## correction, not less, and the dodge would stop beating the lob. A lob that is
## also a guided missile is the "strictly better shot" the item forbids.
##
## So the cap bounds the PRODUCT, which is the class of bug, rather than special-
## casing the lob. Sized at the largest authority the game already grants a flat
## throw (2.3 m/s for flick), rounded up: every existing profile's flat throw is
## unchanged to the millimetre — none of them can currently reach 3.0 — and a lob
## gets the same correction budget a line drive does, spent over a longer flight.
## Committing to the lob therefore costs steering, which is the right trade to have
## to make and reads as weight rather than as a rule.
##
## ⚠️ Reset in `_rpc_set_flying`, i.e. per THROW, on every peer — same lifetime and
## same reasoning as `clear_hit_memory()` on the line beside it.
const MAX_STEER_DELTA_V: float = 3.0
## Fallback used when a slipper's ability carries no ThrowProfile of its own
## (e.g. the networked Prop default, which is currently quick_stand.tres for
## every Prop — see main.gd PROP_ABILITY).
const DEFAULT_PROFILE: ThrowProfile = preload("res://scripts/abilities/resources/throw_default.tres")

## ---------------------------------------------------------------------------
## SCUFFING AN OPPONENT'S TSINELAS — human request, 2026-07-29: *"add a mechanic
## that defender can step or touch the slipper of enemy team and it will slow
## down or get knocked back (knock back for the touch)."*
##
## Two different interactions on the SAME object, told apart by the contact
## normal rather than by a button:
##
##   STEP  — you came down on top of it. The normal points up. It gets slowed.
##   TOUCH — you walked into its side. The normal is horizontal. It gets shoved.
##
## This is the missing half of the ownership rule this file already states in
## `can_be_grabbed_by()`: an opponent's slipper "is still a solid, kickable
## obstacle — you can body-check it, your bump still staggers it," but until now
## nothing actually happened when you did anything short of pressing bump. The
## rule said kickable and the code only meant collidable.
##
## ⚠️ HOST-AUTHORITATIVE, like every other transition in this file. The stepping
## character's own peer is the only one that runs its `move_and_slide()` (see
## `character_base.gd::_physics_process`'s authority gate), so detection has to
## happen there — but it only ASKS. `host_scuff()` re-validates from scratch and
## broadcasts, so two peers shoving the same slipper cannot each decide where it
## goes.
## ---------------------------------------------------------------------------

## How much of its already-slow crawl a stepped-on slipper keeps. Multiplies
## CRAWL_SPEED_SCALE rather than replacing it, so being stood on is strictly
## worse than crawling freely no matter how CRAWL_SPEED_SCALE is retuned.
const STEP_SLOW_SCALE: float = 0.35
## How long the slow lasts after the foot comes off. Non-zero on purpose: with a
## pure while-touching test the effect flickers off every frame the capsules
## separate by a millimetre, which reads as nothing happening at all.
const STEP_SLOW_TIME: float = 0.6
## The shove a body-check gives a loose slipper, in metres/second, and the lift
## that goes with it.
##
## ⚠️ SIZED FROM THE STOPPING DISTANCE, NOT PICKED BY EAR — and the first guess
## was wrong by an order of magnitude for exactly that reason. `FRICTION` is 30.0
## and a loose slipper with no input on it decays at that rate, so a shove of `v`
## travels `v^2 / (2 * 30)` metres and then stops:
##
##     v = 2.6  ->  0.11 m predicted   (the first guess)
##     v = 3.4  ->  0.19 m predicted   (hitbox.gd's MELEE_KNOCKBACK, for scale)
##     v = 8.5  ->  1.20 m predicted   (shipped)
##
## 2.6 was chosen to sit "below MELEE_KNOCKBACK so a deliberate bump always beats
## walking into it", which was reasoning about the wrong quantity: at these speeds
## the whole scale is under a fifth of a metre and nothing in it is visible.
##
## Still under `apply_knockback()`'s horizontal clamp (just above DASH_SPEED, 14),
## so it cannot launch anything out of the arena.
##
## ✅ AND THE PREDICTION HOLDS, once the harness stopped lying. `scuff_probe`
## measured a shove of **1.272 m** against the 1.20 m predicted here.
##
## ⚠️ An earlier note in this spot claimed the opposite — 0.417 m, "and identical
## at v = 2.6, 8.5 and 14.0, so the distance does not respond to this constant at
## all." That was true of what was being measured and false about the game: at the
## time, the touch branch was not firing at all (the STEP/TOUCH discriminator was
## classifying every ground-level contact as a step) and the 0.417 m was the
## Person shoving the slipper by ordinary depenetration, which of course does not
## depend on this constant. Kept as a warning rather than deleted: "the number
## does not respond to the constant" correctly said *something* was wrong, and
## pointed at the wrong thing.
##
## 🧑 THE TARGET DISTANCE IS ALSO A FEEL CALL AND HAS NOT BEEN PLAYED. 1.2 m was
## chosen as "clearly shoved, still retrievable". Checklist Phase 9 owns it.
const TOUCH_KNOCKBACK_SPEED: float = 8.5
const TOUCH_KNOCKBACK_LIFT: float = 1.1
## Minimum gap between two shoves of the same slipper. Without it, a defender
## standing against it re-shoves every physics frame and it rockets away — 60
## impulses a second is not a body-check, it is a jet engine.
const SCUFF_COOLDOWN: float = 0.35
## How vertical a contact normal has to be to count as standing ON the slipper
## rather than walking INTO it.
const STEP_NORMAL_Y: float = 0.6
## How far above the stepper's own feet a contact may still count as standing ON
## the slipper.
##
## ⚠️ THE NORMAL ALONE IS NOT ENOUGH, and the first version of this that shipped
## used only the normal and never once registered a step. A tsinelas is a capsule
## of radius 0.16 — a Person coming down on it is landing on a rounded cap barely
## wider than a fist, so unless the contact is almost exactly dead centre the
## normal comes back angled and the test falls through to TOUCH. Measured: the
## step branch fired 0 times in 40 physics frames of a Person dropped straight
## onto one.
##
## Height is the honest question anyway. "Did I stand on it" is really "was it
## under my feet", and that is what this measures — the normal test is kept as
## the cheap early answer for the clean case.
const STEP_CONTACT_MARGIN: float = 0.12

## Fired on every peer whenever the state changes, so UI and visuals can react
## without polling. CharacterVisual listens for the spin/landing read; hud.gd
## listens so the attacker can be told SLIPPER READY vs GO GET IT.
signal carry_state_changed(new_state: CarryState)

var state: CarryState = CarryState.LOOSE
## The Person currently holding this, or null. Set only by a host broadcast.
var carrier: CharacterBase = null

## R-06. Whether the throw currently in the air is a `bagsak` lob. Set on every peer
## from the launch broadcast (`_rpc_set_flying`), so a visual or audio lane can react
## to a lob without asking who threw it or re-deriving it from the arc. Meaningless
## unless FLYING.
var flight_is_lob: bool = false

var _character: CharacterBase = null
var _flight_velocity: Vector3 = Vector3.ZERO
var _flight_time: float = 0.0
## How much lateral velocity the mid-flight steer has already spent on THIS throw.
## See MAX_STEER_DELTA_V.
var _steer_spent: float = 0.0
var _flight_hitbox: Area3D = null
var _thrower_ignore_left: float = 0.0
var _bounces_left: int = 0
## Scuffing (see the STEP/TOUCH block above). Both are plain local timers driven
## from the broadcast, not replicated state — every peer starts them from the
## same `_rpc_apply_scuff` and counts down at the same rate, which is the same
## reason a carried slipper's transform is recomputed rather than streamed.
var _step_slow_left: float = 0.0
var _scuff_cooldown_left: float = 0.0
## How many times each branch has actually applied, ever, on this peer.
##
## ⚠️ INSTRUMENTATION, AND IT IS LOAD-BEARING — do not delete it as debug cruft.
## The acceptance test for this mechanic originally inferred "the shove happened"
## from how far the slipper ended up moving, which is not the same fact: a Person
## walking through a loose slipper displaces it by ordinary depenetration whether
## or not any of this code runs. Measured, with the probe reporting 0.417 m at
## TOUCH_KNOCKBACK_SPEED 2.6, 8.5 AND 14.0 — a number that does not respond to the
## constant it is supposed to depend on is not measuring that constant.
## These counters observe the branch itself, so the test cannot pass for the wrong
## reason again.
var scuffs_stepped: int = 0
var scuffs_touched: int = 0

func _ready() -> void:
	_character = get_parent() as CharacterBase

## True when this unit is currently a tsinelas, i.e. a Prop on the offence side.
## Re-derived every call rather than cached because `is_can` flips every round.
## A Person is never throwable; neither is a Can.
func is_throwable() -> bool:
	return _character != null and not _character.is_person and not _character.is_can

## THE OWNERSHIP RULE (Task 1). An opponent's slipper is still a solid, kickable
## obstacle — you can body-check it, your bump still staggers it, it still blocks
## a doorway — it simply cannot be PICKED UP by the wrong team. Those are two
## different questions and the distinction is deliberate:
##
##   * collision / hitboxes  — handled elsewhere and NOT touched by ownership.
##     hitbox.gd's own same-team check (B-09) already governs who can hit whom,
##     and the physics body is never disabled on account of who owns it.
##   * pick-up               — this function, and only this function.
##
## Built on CharacterBase.team, the team identity that already exists (B-09).
## There is deliberately no second team system: if this ever disagrees with
## hitbox.gd, that is a bug in one of the two, not a design.
func can_be_grabbed_by(who: CharacterBase) -> bool:
	if who == null or _character == null:
		return false
	if not is_throwable():
		return false # a Can is not a pick-up — it is a RESET, see can_be_reset_by()
	if state != CarryState.LOOSE:
		return false # already in a hand, or still in the air
	if who.team != _character.team:
		return false # an opponent's tsinelas: shove it, kick it, never pocket it
	if not who.is_person:
		return false # a Prop has no hands — only the team's Person retrieves
	return true

## T-3 / B-46 — THE LATA RESET CHANNEL, target side. The taya (the defending
## Person) holds `grab` next to their own knocked-down lata to stand it back up.
## This is the half that says whether that is allowed; carrier.gd runs the
## channel itself and calls host_reset_upright() when it completes.
##
## On the moodboard the whole time, in neither the code nor the GDD until now —
## it is the beat that makes defending an active job rather than standing around
## waiting to be hit.
##
## Mirrors can_be_grabbed_by() deliberately, including the same team rule: you
## right YOUR OWN team's lata, never the opponents'. Note what is NOT checked
## here — whether the round is still live. RoundManager owns that, and by the
## time a Can is SEALED the round is already over (one tracked Can per round, and
## sealing it ends it), which is exactly why SEALED is not resettable below.
func can_be_reset_by(who: CharacterBase) -> bool:
	if who == null or _character == null:
		return false
	if not _character.is_can:
		return false # only a lata is ever stood back up
	if not who.is_person or who.team != _character.team:
		return false # the taya rights their own can; nobody else touches it
	if GameLaunch.game_mode == GameLaunch.GameMode.OPTION_A:
		# Option A: no Downed/Seal machinery at all, the can just carries dents.
		# Beat one back out. At MAX_DENTS the round has already been reported, so
		# only a partially dented can is worth channelling.
		return _character.dents > 0 and _character.dents < CharacterBase.MAX_DENTS
	# Option B: DOWNED only. Not SEALED — a sealed can means the round is already
	# lost, and un-sealing it here would be round-win logic living in the wrong
	# file. Not NORMAL either; there is nothing to stand up.
	return _character.state == CharacterBase.State.DOWNED

## Host-side completion of the channel. Same shape as host_grab/host_throw: the
## client asked, the host re-validates from scratch, and only then does it apply.
##
## The apply is routed to the CAN'S OWN AUTHORITY, not broadcast — this is the
## idiom hitbox.gd/_apply_hit_result already established for state changes: the
## owning peer mutates its own state and CharacterBase.tscn's
## MultiplayerSynchronizer distributes it outward from there. Broadcasting to
## every peer instead would have each one write state it does not own, and the
## synchronizer would immediately overwrite it.
func host_reset_upright(by: CharacterBase) -> void:
	if not _is_host() or not can_be_reset_by(by):
		return
	if NetworkManager.is_networked():
		_rpc_apply_reset.rpc_id(_character.get_multiplayer_authority())
	else:
		_rpc_apply_reset()

## "any_peer" for the reason documented on the broadcasts below: this is sent BY
## the host to a peer that is not this node's authority in the usual case, and an
## "authority" RPC would be silently dropped.
@rpc("any_peer", "call_local", "reliable")
func _rpc_apply_reset() -> void:
	# 4.1 — "reset-channel complete", one of the checklist's named minimum set.
	# Played here rather than only from CharacterBase's state hook because the
	# OPTION_A branch below does not change `state` at all (it beats a dent back
	# out), so under Option A there is no state transition to hang it on and the
	# channel would finish silently. Under Option B both fire and AudioManager's
	# retrigger guard collapses them.
	AudioManager.play_at("reset_channel_complete", _character.global_position)
	if GameLaunch.game_mode == GameLaunch.GameMode.OPTION_A:
		_character.clear_dent()
	else:
		_character.self_right()

## Whether this node is currently driving the character's movement itself, in
## which case character_base.gd hands the physics frame over (see its
## _physics_process). LOOSE deliberately returns false: a loose slipper still
## walks itself with normal player input, just slowed.
func drives_movement() -> bool:
	return state == CarryState.CARRIED or state == CarryState.FLYING

## Multiplier applied to normal movement speed. Only ever != 1.0 while LOOSE and
## throwable — the crawl home.
## ⚠️ Gated on RoundManager.round_active, 2026-07-28, same reason and same
## day as CharacterBase._is_confined_to_base()'s gate: before the round
## actually starts (the new pre-round free-roam window) a Tsinelas Prop is
## always LOOSE and throwable by definition, and without this gate its
## player would be stuck crawling at CRAWL_SPEED_SCALE the whole time they're
## supposed to be moving "with no restrictions."
func movement_speed_scale() -> float:
	if RoundManager.round_active and state == CarryState.LOOSE and is_throwable():
		# Being stood on MULTIPLIES the crawl rather than replacing it — see
		# STEP_SLOW_SCALE. A defender with a foot on your tsinelas should make an
		# already-bad situation worse, not define a new speed out of nowhere.
		if _step_slow_left > 0.0:
			return CRAWL_SPEED_SCALE * STEP_SLOW_SCALE
		return CRAWL_SPEED_SCALE
	return 1.0

## Runs on every peer. The two scuff timers are the only things this node needs
## ticked while the slipper is LOOSE — `physics_step()` above is called by
## character_base only while `drives_movement()` is true (CARRIED or FLYING), and
## a loose slipper is neither.
func _physics_process(delta: float) -> void:
	if _step_slow_left > 0.0:
		_step_slow_left = maxf(0.0, _step_slow_left - delta)
	if _scuff_cooldown_left > 0.0:
		_scuff_cooldown_left = maxf(0.0, _scuff_cooldown_left - delta)

## Whether `who` is allowed to scuff this slipper at all. Mirrors
## can_be_grabbed_by() and inverts its team test on purpose: you may PICK UP only
## your own team's tsinelas, and you may STEP ON or SHOVE only the opponents'.
## The two are the same ownership rule read from its two ends.
func can_be_scuffed_by(who: CharacterBase) -> bool:
	if who == null or _character == null or who == _character:
		return false
	if not is_throwable():
		return false # a lata is not kicked around; it is hit, or it is reset
	if state != CarryState.LOOSE:
		return false # in a hand or in the air is somebody else's rule
	if who.team == _character.team:
		return false # your own team's slipper — go and pick it up instead
	if not RoundManager.round_active:
		return false
	return true

## Host side of a scuff. `kind` is "step" or "touch"; `direction` is the shove
## bearing for a touch, already flat and normalised, and ignored for a step.
##
## Same shape as host_grab/host_throw: the client asked, the host re-validates
## from scratch, and only then does it broadcast. The cooldown is checked HERE,
## on the one machine, so two defenders arriving on the same frame cannot each
## spend it.
func host_scuff(by: CharacterBase, kind: String, direction: Vector3) -> void:
	if not _is_host() or not can_be_scuffed_by(by):
		return
	if kind == "touch" and _scuff_cooldown_left > 0.0:
		return
	if NetworkManager.is_networked():
		_rpc_apply_scuff.rpc(kind, direction)
	else:
		_rpc_apply_scuff(kind, direction)

## "any_peer" for the same reason every other broadcast in this file is — the
## host sends it, and the host is not this node's multiplayer authority in the
## usual case, so an "authority" RPC would be silently dropped.
@rpc("any_peer", "call_local", "reliable")
func _rpc_apply_scuff(kind: String, direction: Vector3) -> void:
	if kind == "step":
		scuffs_stepped += 1
		# Refreshed, not accumulated — standing on it longer keeps it slow, it
		# does not make it slower and slower.
		_step_slow_left = STEP_SLOW_TIME
		return
	scuffs_touched += 1
	_scuff_cooldown_left = SCUFF_COOLDOWN
	# apply_knockback() already refuses between rounds, clamps the result, and
	# respects Guard — reusing it means a body-check on a slipper obeys exactly
	# the same ceilings a thrown Bagsak Bomb does. See its own doc.
	_character.apply_knockback(
		direction * TOUCH_KNOCKBACK_SPEED + Vector3.UP * TOUCH_KNOCKBACK_LIFT)
	AudioManager.play_at("slipper_land", _character.global_position)

## Read by character_visual.gd for the in-flight tumble. Exposed rather than
## making callers reach through to `ability` themselves — how a slipper flies is
## this node's business, what that looks like is theirs.
func spin_speed_deg() -> float:
	return _profile().spin_speed_deg

## Read by character_visual.gd alongside spin_speed_deg() — the end-over-end
## flip, as opposed to the spin about the slipper's own long axis. See
## ThrowProfile.tumble_speed_deg for why doing only the latter read as flat.
func tumble_speed_deg() -> float:
	return _profile().tumble_speed_deg

## THE FACESLOP, STRIKER SIDE. The impulse a hit from this slipper should impart
## right now, in metres/second, before the struck object's own resistance is
## applied (that is hurtbox.gd::absorb_knockback's job).
##
## Taken from `_flight_velocity` rather than from `_character.velocity`: they
## agree during flight, but _flight_velocity is the one this file actually
## integrates, and it is still correct on the exact frame a collision has
## already zeroed the body's velocity — which is precisely the frame a hit
## resolves on. Reading the body instead would give a knockback of zero for
## every square hit, i.e. for every hit that matters most.
##
## Zero unless FLYING: a slipper being carried or lying on the floor has no
## momentum to give, and a hit involving one should fall through to hitbox.gd's
## ordinary melee shove instead.
func knockback_impulse(force_downed: bool) -> Vector3:
	if state != CarryState.FLYING:
		return Vector3.ZERO
	var profile := _profile()
	var flat := Vector3(_flight_velocity.x, 0.0, _flight_velocity.z)
	if flat.length() < 0.01:
		return Vector3.ZERO
	var strength: float = profile.knockback_scale * profile.mass
	if force_downed:
		strength *= profile.faceslop_multiplier
	var lift: float = profile.knockback_lift * (profile.faceslop_multiplier if force_downed else 1.0)
	return flat.normalized() * flat.length() * strength + Vector3.UP * lift

## Called from character_base.gd's _physics_process when drives_movement() is
## true. Runs on EVERY peer, not just the authority: both branches below are
## deterministic given state that is already replicated, so running them locally
## is both cheaper and smoother than streaming a transform.
func physics_step(delta: float) -> void:
	match state:
		CarryState.CARRIED:
			_step_carried()
		CarryState.FLYING:
			# B-74: this whole function runs ABOVE character_base.gd's
			# `round_active` gate, deliberately — every peer has to run the carry
			# maths and the authority gate sits below it. The side effect nobody
			# thought through is that the round-end freeze, which stops all four
			# players dead, did not stop a slipper already in the air: it sailed
			# on through the entire intermission until reset_for_new_round() put
			# it back on the floor. Hold it where it is instead. The round is
			# already decided by this point (report_round_win has fired), so
			# freezing the arc can never change an outcome.
			if not RoundManager.round_active:
				_character.velocity = Vector3.ZERO
				return
			_step_flying(delta)

## B-90 — the tsinelas is a flat, thin object (0.432 long x 0.166 wide x 0.078
## tall): its own sole is the ONLY side that reads as "a slipper" at a glance,
## and the arm bone's fixed rotation (see character_visual.gd's
## HAND_CARRY_OFFSET comment, "a +60 degree rotation about Y") leaves the
## object's local up axis close to world-up — i.e. presented flat, roughly
## LEVEL with the eye, which from a camera at the same height is close to
## edge-on. Edge-on, a 0.078-tall object is a sliver, not a slipper. This
## tilts the carried object about its OWN local X axis (applied before the
## hand's rotation, so it tilts in the object's own frame first) to angle the
## sole up toward the camera, the way a real held object naturally reads.
## Cosmetic only, on top of the position work HAND_CARRY_OFFSET already does —
## does not touch LOOSE or FLYING, which already read fine (a slipper crawling
## on the ground or spinning in flight is not being viewed edge-on the same
## way). Tuning window roughly 45-70 degrees; re-render if you change it.
const CARRY_TILT_DEG: float = 55.0

## Snap to the carrier's hand. Every peer computes this identically from the
## replicated `carrier`, so a carried slipper needs no position replication at
## all. The hand itself comes from CharacterVisual, which is the only thing that
## knows the shape of the model — character_base.gd must never learn where a
## Person's hand is, same rule that keeps dents out of it.
func _step_carried() -> void:
	if carrier == null or not is_instance_valid(carrier):
		# The carrier left the match mid-hold. Drop where we stand rather than
		# following a freed node; the host will confirm with its own broadcast.
		if _is_host():
			host_drop()
		return
	var hand := carrier.get_hand_attachment()
	if hand == null:
		return # the Person's model has not been instanced yet; try again next frame
	# ⚠️⚠️ THE ORIENTATION COMES FROM THE CARRIER'S BODY, NOT FROM THE HAND BONE.
	# THIS IS THE FIX FOR "THE SLIPPER JUST SPINS AROUND UNCONTROLLABLY".
	#
	# The POSITION still comes from the hand — that is what puts the tsinelas in
	# the fist rather than floating beside it, and it is correct. The BASIS used
	# to come from the hand too, and that is where the spin came from: `hand` is a
	# node under a `BoneAttachment3D` on the Person's arm bone, so its basis is
	# re-derived from the currently-playing ANIMATION CLIP every single frame. The
	# arm swings through idle, walk, sprint, the throw one-shot and the grab
	# one-shot, and the slipper was rigidly welded to all of it — a full,
	# fast, uncontrollable tumble in the hand of anyone who so much as walked.
	#
	# It reads worst exactly where it was reported, before the round starts: a
	# CARRIED slipper returns true from `drives_movement()`, so
	# `character_base.gd::_physics_process` gives its whole frame to this function
	# and returns before reading input. The player cannot move it AND it is
	# spinning, which is the complaint word for word.
	#
	# A body's yaw is a single number that changes when the player turns, so
	# building the basis from it gives a slipper that is held steady, points where
	# its carrier points, and still tilts its sole toward the camera. Nothing about
	# the hand's POSITION is given up — the arm still carries it, it just no longer
	# spins it.
	#
	# ⚠️ ORTHONORMALISED YAW, NOT THE CARRIER'S RAW BASIS. A Person's model is
	# scaled by CharacterVisual.PERSON_SCALE (2.38) and a body can carry
	# non-yaw components transiently; both would ride straight into this transform.
	# `camera_rig.gd::_body_yaw()` exists for the same reason and recovers yaw the
	# same way, from the forward vector rather than from Euler decomposition.
	#
	# B-90: `* tilt`, not `tilt *` — tilt has to apply in the OBJECT'S OWN
	# local frame (pre-multiplied) so it rotates the sole toward the camera
	# regardless of which way the carrier is currently facing, rather than
	# tilting relative to the world after the yaw is already applied.
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(CARRY_TILT_DEG))
	var hand_transform := hand.global_transform
	var forward := -carrier.global_transform.basis.z
	var carrier_yaw := atan2(-forward.x, -forward.z)
	var basis := Basis(Vector3.UP, carrier_yaw) * tilt
	# ⚠️ PUT THE MESH IN THE HAND, NOT THE ORIGIN.
	#
	# 2026-07-29, reported as "floating slipper when held, make it acc be on the
	# hand". A carried unit's visible model is NOT centred on its CharacterBase
	# origin: `character_visual.gd::_align_to_capsule_floor` drops it so its
	# bottom rests on the capsule floor, which for the tsinelas is a measured
	# **0.160 below the origin**. Snapping the origin to the hand therefore hangs
	# the visible slipper under the hand, every frame, by construction.
	#
	# This used to be compensated by baking a fudge into
	# CharacterVisual.HAND_CARRY_OFFSET, which was wrong twice over: the value
	# was 0.441 rather than 0.160, and it lived in the HAND BONE's rotating local
	# frame, so whatever it meant in one animation clip it meant something else
	# in the next. Corrected here instead, in world space, from the carried
	# unit's own measured offset — so it is right for the Can too, and it cannot
	# drift from the drop it exists to cancel.
	var centre := Vector3.ZERO
	var visual := _character.get_node_or_null("Visual") as CharacterVisual
	if visual != null:
		centre = visual.visual_centre_offset()
	_character.global_transform = Transform3D(
		basis, hand_transform.origin - basis * centre)
	_character.velocity = Vector3.ZERO

func _step_flying(delta: float) -> void:
	_flight_time += delta
	if _thrower_ignore_left > 0.0:
		_thrower_ignore_left -= delta

	var profile := _profile()
	_flight_velocity.y -= CharacterBase.GRAVITY * profile.gravity_scale * delta

	# Mid-flight steer — the Prop player is a pilot, not cargo (Task 0 agreement).
	# Sideways only, relative to the direction of travel: it can curve a throw
	# around a defender, never turn it into a guided missile or add range.
	if profile.steer_strength > 0.0 and _is_locally_driven() \
			and _steer_spent < MAX_STEER_DELTA_V:
		var input_dir := _character.input_vector(
			"move_left", "move_right", "move_up", "move_down")
		if input_dir.length() > 0.0:
			var travel := _flight_velocity
			travel.y = 0.0
			if travel.length() > 0.01:
				var right := travel.normalized().cross(Vector3.UP)
				# ⚠️ THE BUDGET IS SPENT ON MAGNITUDE, NOT ON SIGN. Counting only the
				# net displacement would let a pilot wiggle left-right forever and
				# accumulate unlimited authority a frame at a time, which is the same
				# 60-impulses-a-second failure SCUFF_COOLDOWN exists for. See
				# MAX_STEER_DELTA_V.
				var step: float = minf(
					absf(input_dir.x) * profile.steer_strength * delta,
					MAX_STEER_DELTA_V - _steer_spent)
				_steer_spent += step
				_flight_velocity += right * signf(input_dir.x) * step

	# The hitbox is live for the whole flight (character_base.is_hitbox_active),
	# but area_entered only fires on the ENTER edge — so sweep every frame or a
	# can already inside the slipper's hitbox on the first flight frame is never
	# reported. Cheap: one Area3D overlap query on one node.
	_character.sweep_hitbox()
	var collision := _character.move_and_collide(_flight_velocity * delta)
	# ⚠️ IGNORE THE THROWER, NOT THE ENTIRE WORLD (B-132). This used to read
	# `_thrower_ignore_left <= 0.0`, with no test of WHAT was hit — so for the
	# first THROWER_IGNORE_TIME (0.25 s) of every flight the slipper passed
	# through the floor, the walls and the lata alike.
	#
	# That is most of a real throw. Measured with tools/phys_probe.tscn's
	# ballistics mode: a throw_default shot at the 6.0 line has a total flight
	# time of about 0.29 s, so ~87% of it was intangible. The slipper sank
	# through the ground, kept travelling, and only became solid again well past
	# the target — landing 10.14 m out on a 6.0 m throw, a 69% overshoot on an
	# arc that _solve_arc had solved correctly. Every profile's landing was wrong
	# by a different amount depending on its flight time, which is exactly the
	# "weird bounces" and floor-clipping this file's own header records.
	#
	# The window was never needed for its stated purpose anyway: _rpc_set_flying
	# already calls `add_collision_exception_with(carrier)`, and _rpc_set_loose
	# removes it, so the PHYSICS ENGINE excludes the thrower for the whole flight.
	# The identity test below keeps the belt-and-braces intent while making the
	# comment above THROWER_IGNORE_TIME true.
	var ignoring_thrower := collision != null and _thrower_ignore_left > 0.0 \
		and carrier != null and is_instance_valid(carrier) \
		and collision.get_collider() == carrier
	if collision != null and not ignoring_thrower and _bounces_left > 0:
		_flight_velocity = _flight_velocity.bounce(collision.get_normal()) * bounce_damping
		_bounces_left -= 1
		collision = null # consumed by the bounce, not a landing this frame
		# 4.1. Runs on every peer (this whole function does — see physics_step's
		# own note), so the skip is audible to everyone watching the throw, not
		# just to whoever threw it.
		AudioManager.play_at("slipper_bounce", _character.global_position)
	_character.velocity = _flight_velocity

	if not _is_host():
		return # only the host decides that a flight has ended

	var hit_something := collision != null and not ignoring_thrower
	if hit_something or _flight_time >= MAX_FLIGHT_TIME:
		host_land()

## ---------------------------------------------------------------------------
## Host-side transitions. Everything below decides; the _rpc_* pair broadcasts.
## Call these ONLY on the host — clients route through carrier.gd's request RPCs.
## ---------------------------------------------------------------------------

func host_grab(by: CharacterBase) -> void:
	if not _is_host() or not can_be_grabbed_by(by):
		return
	_broadcast_carried(by.get_path())

## Launch. `direction` is the thrower's aim (already normalised, world space);
## `power` is 0..1 from the charge meter.
## ⚠️ TAKES THE POINT THE CROSSHAIR IS ON, NOT A DIRECTION. See
## carrier.gd::_aim_point() for the measurements behind that, and _solve_arc()
## below for the maths. The parameter used to be a unit direction; anything
## calling this with one will now aim at a point 1 metre from the world origin.
## ⚠️ `lob` IS R-06, AND IT IS THE ONLY NEW PARAMETER *THAT MECHANIC* NEEDED. Default
## false so every existing caller — the probes, and any ability that ever throws —
## keeps the flat throw it already asked for.
##
## ⚠️ `launch_origin` IS 10.6, AND IT HAS NO DEFAULT ON PURPOSE. Merged 2026-07-30 from
## `code/throw-feel`, which was written against a `host_throw` that had neither `lob` nor
## the LAKAS power scale — the two changes are complementary (one is WHERE the throw
## leaves from, the other is WHAT SHAPE it flies) and both are kept in full.
##
## It is the FIRST parameter and it is required, so that every one of the ten call sites
## across four probes had to be visited by hand rather than silently inheriting a default
## that would have quietly restored the sag this fixes. See `carrier.gd::_throw_origin()`.
func host_throw(launch_origin: Vector3, target_point: Vector3, power: float,
		lob: bool = false) -> void:
	if not _is_host() or state != CarryState.CARRIED:
		return
	var profile := _profile()
	var speed_now: float = profile.launch_speed * clampf(power, 0.0, 1.0)
	# ⚠️ SOLVED FROM, AND LAUNCHED FROM, THE SIGHT LINE — not this unit's own
	# position. See carrier.gd::_throw_origin() for the measurements: leaving
	# from the hand hung the whole flight up to 0.43 m under the line the player
	# was aiming along, worst within a fifth of a metre of their face. Both the
	# solve and the broadcast below use the same origin, or the arc would be
	# solved for a flight that never happens.
	#
	# ⚠️ AND THE LOB TAKES IT TOO — that is a merge DECISION, not a mechanical
	# resolution. `code/throw-feel` predates R-06 and so only ever fixed the flat
	# throw. Leaving the lob on `_character.global_position` would have kept the
	# exact sag this fixes for the one throw whose whole identity is its arc, and
	# split the two paths over which origin they launch from for no reason.
	if lob:
		# The lob solves the SPEED for a fixed angle instead of the angle for a fixed
		# speed — the mirror image of the flat throw, and the same arc. See _solve_lob.
		_broadcast_flying(launch_origin,
			_solve_lob(launch_origin, target_point, profile, speed_now), true)
		return
	var aim := _solve_arc(launch_origin, target_point, speed_now, profile, lob)
	# ⚠️ THE SIGN HERE WAS INVERTED, AND IT IS WHY EVERY THROW FLEW LOW.
	# 2026-07-29, user report: "the height when you throw it is still too low."
	#
	# This block has always been documented as "tilt the aim UPWARD by the
	# profile's arc" and it did the exact opposite. `horizontal.cross(UP)` for a
	# forward aim of (0,0,-1) is (+1,0,0), and rotating about +X by a NEGATIVE
	# angle drives y negative. Measured against the expression as it stood:
	#     crosshair level  ->  launch y -0.242   (14 deg BELOW the crosshair)
	#     crosshair +20    ->  launch y +0.105   (still 14 deg below)
	#     crosshair -20    ->  launch y -0.559
	# So every throw left the hand a full `arc_angle_deg` under where the player
	# was pointing — 28 deg low for Bagsak, whose whole identity is the lob.
	# Nothing caught it because the arc and the drop compound in the same
	# direction: it just read as "the throw is weak", which is how it was
	# reported both times.
	#
	# ⚠️ AND THE ARC IS NOW 0.0 ON EVERY SHIPPED PROFILE — see the .tres files.
	# The request was for the launch to be ALIGNED WITH THE CROSSHAIR, and any
	# non-zero arc, in either direction, is by definition a hidden offset from
	# it. The field is kept, and now finally works in the direction it claims,
	# so a profile can dial a lob back in deliberately.
	var horizontal := Vector3(aim.x, 0.0, aim.z)
	if horizontal.length() > 0.01 and not is_zero_approx(profile.arc_angle_deg):
		var axis := horizontal.normalized().cross(Vector3.UP)
		aim = aim.rotated(axis.normalized(), deg_to_rad(profile.arc_angle_deg))
	_broadcast_flying(launch_origin, aim.normalized() * speed_now, lob)

## THE LAUNCH ANGLE THAT ACTUALLY PASSES THROUGH `target`.
##
## ⚠️ THIS, NOT THE LAUNCH DIRECTION, IS WHAT "ALIGNED WITH THE CROSSHAIR"
## MEANS. Pointing the initial velocity at the crosshair is not the same thing
## and does not look like it: gravity bends the flight away from the sight line by an
## amount that grows with range.
## ⚠️ THIS PARAGRAPH USED TO SAY "the slipper leaves the HAND (y 0.89) rather than the
## eye (y 1.35)". It no longer does — 10.6 moved the launch onto the sight line, and
## `host_throw` now takes that origin. The solve below is still what makes the flight pass
## THROUGH the point; the origin is what stops it sagging under the line on the way. Measured with the launch merely parallel to the
## aim, from the 6.0 throwing line: a target 7.04 m out landed 1.70 m SHORT and
## one 3.38 m out landed 1.47 m LONG — the two only ever agreed at a single
## distance, which is exactly what "the height is too low" describes.
##
## Standard ballistic solution for a fixed speed. With horizontal range d,
## height difference h and gravity g:
##     tan(theta) = (v^2 +/- sqrt(v^4 - g*(g*d^2 + 2*h*v^2))) / (g*d)
## The MINUS root is the flat, direct throw and the plus root is the lob over
## the top; a slipper wants the flat one, and taking it also means the solved
## angle stays close to where the player is already pointing.
##
## `g` is the profile's own effective gravity, so a heavy Bakya solves a steeper
## angle than a floaty Havaianas for the same target — which is the profiles
## doing their job rather than fighting the aim.
##
## ---------------------------------------------------------------------------
## ⚠️⚠️ R-06 · `lob` PICKS THE OTHER ROOT, AND THAT IS THE WHOLE MECHANIC.
##
## This function has computed both solutions of the ballistic quadratic since B-129
## and thrown one of them away on the line below. `(v2 - root)` is the flat shot;
## `(v2 + root)` is the same slipper, at the same speed, to the same target point,
## over the top of whatever is in between. No new ballistics, no new ThrowProfile
## field, no second physics path — the lob was already solved and simply had no way
## to be chosen.
##
## Both roots pass through `target` exactly. So the lob does NOT trade accuracy for
## height: it lands where the crosshair is, which is what makes it an answer to a
## body-block rather than a hail mary. What it trades is TIME — the high root's
## flight is several times longer, which is the balance clause R-06 is built on
## ("arrives slowly enough that the can's evasion can actually see it"). The
## measured numbers are in Art_Direction.md §9.
##
## Out of range is unchanged and shared: when the discriminant goes negative there
## is no arc of either kind, so a lob falls back to the same honest short throw a
## flat one does rather than firing straight up.
## ---------------------------------------------------------------------------
func _solve_arc(origin: Vector3, target: Vector3, speed: float, profile: ThrowProfile,
		lob: bool = false) -> Vector3:
	var to_target := target - origin
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var distance := flat.length()
	# Straight up, straight down, or on top of us: no arc to solve, just throw
	# along the line. Also guards the division below.
	if distance < 0.05 or speed < 0.01:
		return to_target.normalized() if to_target.length() > 0.01 else Vector3.FORWARD
	var gravity: float = CharacterBase.GRAVITY * profile.gravity_scale
	var v2 := speed * speed
	var discriminant := v2 * v2 - gravity * (gravity * distance * distance + 2.0 * to_target.y * v2)
	if discriminant < 0.0:
		# ⚠️ OUT OF RANGE — no launch angle at this speed reaches that point, so
		# there is nothing to solve and the honest thing is to throw along the
		# player's own line and let it fall short. Deliberately NOT the
		# maximum-range 45 degrees: aiming at a distant wall would then fire a
		# lob straight up, which is a far stranger thing to have happen than a
		# throw that visibly does not get there.
		return to_target.normalized()
	var root := sqrt(discriminant)
	var tangent := ((v2 + root) if lob else (v2 - root)) / (gravity * distance)
	return (flat.normalized() + Vector3.UP * tangent).normalized()

## ---------------------------------------------------------------------------
## ⚠️⚠️ R-06 · THE LOB SOLVES THE SPEED FOR A FIXED ANGLE, NOT THE ANGLE FOR A FIXED
## SPEED. THE WRITTEN SPEC ASKED FOR THE RAW HIGH ROOT AND THE MEASUREMENT SAID NO.
##
## R-06's handoff (Checklist.md §Phase 9) specifies "root selection": take
## `(v2 + sqrt(disc))` in `_solve_arc` instead of `(v2 - sqrt(disc))`. That was built
## first, exactly as written, and then measured with `phys_probe -- ballistics`. The
## flat rows reproduced the 2026-07-29 baseline to the charge step, so the selection
## itself was correct — and the lob rows were unusable:
##
##     profile         launch angle   flight time   apex above the hand
##     throw_bagsak      74.8 deg        1.22 s          5.06 m
##     throw_bakya       77.4 deg        1.40 s          6.22 m
##     throw_default     80.5 deg        1.68 s          8.41 m
##     throw_flick       85.6 deg        2.90 s        18.45 m      <-- 18 metres
##
## The high root at FULL LAUNCH SPEED is a mortar, not a lob. `throw_flick` throws the
## tsinelas 18 m straight up for nearly three seconds: above Eskinita's 10–14 m
## rooflines, out of an FPP player's field of view entirely (they would have to look
## at the sky to watch their own throw), and a three-second dead beat in a party game
## whose whole round is 90 s. It also scales the WRONG WAY — the fastest, lightest
## slipper produces the highest, slowest lob, so the profile identities invert.
##
## The cause is structural, not a tuning miss: the high root's angle is a function of
## how much surplus speed there is over the minimum needed to reach the target, and a
## full-charge throw at the 6.0 line has a great deal of surplus. Any fix that keeps
## full speed is picking between "too steep" and "misses the target".
##
## So the lob fixes the ANGLE and solves the SPEED, which is the same quadratic read
## from its other end:
##
##     v^2 = g * d^2 / (2 * cos^2(theta) * (d * tan(theta) - h))
##
## This is not a different arc from the high root — it IS the high root, at the speed
## that makes the high root equal LOB_LAUNCH_ANGLE_DEG. Everything the spec required
## survives: it passes exactly through the crosshair point (so the lob is an ANSWER to
## a block, not a hail mary), it needs no new ThrowProfile field, it adds no input
## action, and it is not a power buff — it uses LESS speed than the charge earned,
## which is also why its knockback lands as a drop rather than a blast.
##
## ⚠️ AND IT MAKES THE LOB'S SHAPE PROFILE-INDEPENDENT, WHICH IS A PROPERTY, NOT A
## COINCIDENCE. Apex depends only on the angle and the target geometry; `g` cancels
## out of it entirely. So every slipper lobs to the same readable height and the
## profile identity survives as TIMING instead — measured at the 6.0 line: flick
## 1.10 s, default 0.93 s, bakya 0.89 s, bagsak 0.86 s. The floaty one hangs longest,
## the heavy one arrives soonest, and all four clear CAN_EVADE_LOOKAHEAD's 0.6 s.
##
## ⚠️ 60 DEGREES IS DERIVED FROM THE BLOCK IT HAS TO CLEAR, NOT PICKED BY EYE. A taya
## posted at `AIController.taya_block_standoff` (2.6) from the can stands 3.4 m along
## a 6.0 m lane, and its Hurtbox tops out at world y 1.75 against a hand that releases
## at 0.9. At 60 deg the arc is 2.42 m above the hand at that point — it clears the
## defender's head by 1.57 m, which is a lob a player can SEE going over rather than
## one that grazes and gets stopped. 45 deg is the flattest arc that reaches at all
## (the minimum-speed solution) and clears by only 0.09 m, i.e. inside one frame of
## travel; the margin is the whole reason this is not 45.
## ---------------------------------------------------------------------------

## The angle a `bagsak` lob leaves the hand at, above horizontal.
const LOB_LAUNCH_ANGLE_DEG: float = 60.0

## The launch VELOCITY for a lob — direction and speed together, unlike _solve_arc,
## which answers only the direction because the flat throw's speed is the charge's.
##
## `max_speed` is what the charge actually earned. A lob never exceeds it: past about
## 16 m the 60-degree solution needs more speed than the profile has, and rather than
## quietly becoming a stronger throw it keeps the angle, takes what it has and falls
## short — the same honest behaviour `_solve_arc` documents for its own out-of-range
## case, and visible to the player as a throw that plainly did not get there.
func _solve_lob(origin: Vector3, target: Vector3, profile: ThrowProfile,
		max_speed: float) -> Vector3:
	var to_target := target - origin
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var distance := flat.length()
	var theta := deg_to_rad(LOB_LAUNCH_ANGLE_DEG)
	# How far the 60-degree sight line rises above the target over this range. Zero or
	# negative means the target is at or above that line — you cannot lob onto
	# something already steeper than the lob, so there is nothing to solve.
	var rise := distance * tan(theta) - to_target.y
	if distance < 0.05 or rise <= 0.01 or max_speed < 0.01:
		return _solve_arc(origin, target, max_speed, profile) * max_speed
	var gravity: float = CharacterBase.GRAVITY * profile.gravity_scale
	var cos_theta := cos(theta)
	var needed: float = sqrt(gravity * distance * distance / (2.0 * cos_theta * cos_theta * rise))
	var direction := (flat.normalized() + Vector3.UP * tan(theta)).normalized()
	return direction * minf(needed, max_speed)

func host_land() -> void:
	if not _is_host() or state != CarryState.FLYING:
		return
	_broadcast_loose(_character.global_position)

## The carrier died, disconnected, or the round ended while holding.
func host_drop() -> void:
	if not _is_host() or state == CarryState.LOOSE:
		return
	_broadcast_loose(_character.global_position)

## Round reset. Called from CharacterBase.reset_for_new_round() on every peer —
## no RPC, because every peer runs the reset itself from already-synced state,
## exactly as _reset_world does for team/role.
func reset_for_new_round() -> void:
	_clear_flight_hitbox()
	_flight_velocity = Vector3.ZERO
	_flight_time = 0.0
	_thrower_ignore_left = 0.0
	flight_is_lob = false
	_steer_spent = 0.0
	_character.clear_hit_memory()
	if carrier != null and is_instance_valid(carrier):
		_character.remove_collision_exception_with(carrier)
		_watch_carrier_state(carrier, false)
		# 2026-07-29 — THE INVISIBLE SLIPPER. Reported across more than ten
		# sessions as "the slipper is invisible to everyone except the attacker
		# holding it", and measured on a real two-peer session with
		# tools/net_spawn_probe.gd before this line was written.
		#
		# This function cleared `carrier` (below) but never told the CARRIER, so
		# the Person's own `Carrier._held` kept pointing at a slipper that no
		# longer considered itself carried. Every other transition out of CARRIED
		# — _rpc_set_flying, _rpc_set_loose — calls _notify_carrier(carrier, null)
		# and is fine; the round reset was the one path that did not, and it is
		# the path taken by the COMMON case, because the attacker is usually still
		# holding the tsinelas when the round ends (see _set_physics_enabled's own
		# B-101 note directly below, which is the same oversight on the other half
		# of this function's state).
		#
		# What a stale `_held` then does, on that player's machine only:
		#
		#   * camera_rig.gd::_apply_carried_self_hide() hides the held unit's
		#     `Visual` for whoever is looking through their own eyes. Keyed on
		#     `Carrier.held()`, so it keeps hiding a slipper the Person no longer
		#     holds — FOREVER, including while somebody else is carrying it.
		#     Roles swap every round, so that player is the DEFENDER next round:
		#     "the defender cannot see it", exactly as reported.
		#   * carrier.gd::_step_grab() bails on `_held != null`, so that Person can
		#     never pick anything up again for the rest of the match.
		#   * carrier.gd::_step_reset_channel() treats them as hands-full, so they
		#     can never stand their own lata back up either.
		#
		# The last two are why this reads as "the slipper is bugged" rather than
		# purely as a rendering fault, and why re-checking the rendering code found
		# nothing for ten sessions.
		#
		# Belt and braces: `Carrier.held()` is ALSO self-healing now (see its own
		# doc), so a future path that forgets this call cannot resurrect the bug.
		_notify_carrier(carrier, null)
	carrier = null
	# 2026-07-28 — B-101. This was missing entirely. _rpc_set_carried() disables this
	# unit's own collision the instant it's grabbed (_set_physics_enabled(false)
	# — CARRIED must not shove a teammate or be independently hittable); nothing
	# here ever turned it back on. A Prop that was CARRIED when the round ended
	# (the common case — the attacker is usually still holding it) came out of
	# reset_for_new_round() as LOOSE but with its body collision STILL disabled,
	# free to fall straight through the floor with nothing to stop it — this unit
	# might become the Can next round, which is exactly "the can fell off the
	# map." _set_physics_enabled(true) is idempotent (harmless if collision was
	# already on), so this is safe to call unconditionally every round.
	_set_physics_enabled(true)
	_set_state(CarryState.LOOSE)

## ---------------------------------------------------------------------------
## Broadcasts. `call_local` so the host runs its own handler too, matching the
## pattern MatchManager._sync_round_started already uses.
## ---------------------------------------------------------------------------

func _broadcast_carried(carrier_path: NodePath) -> void:
	if NetworkManager.is_networked():
		_rpc_set_carried.rpc(carrier_path)
	else:
		_rpc_set_carried(carrier_path)

func _broadcast_flying(origin: Vector3, velocity: Vector3, lob: bool = false) -> void:
	if NetworkManager.is_networked():
		_rpc_set_flying.rpc(origin, velocity, lob)
	else:
		_rpc_set_flying(origin, velocity, lob)

func _broadcast_loose(where: Vector3) -> void:
	if NetworkManager.is_networked():
		_rpc_set_loose.rpc(where)
	else:
		_rpc_set_loose(where)

## "any_peer", not "authority", for the same reason CharacterBase._apply_hit_result
## documents: resolution runs on the HOST, but this node's multiplayer authority
## is the slipper's own owning peer, which for any non-host player is not the
## host. An "authority" RPC from the host would be silently rejected.
@rpc("any_peer", "call_local", "reliable")
func _rpc_set_carried(carrier_path: NodePath) -> void:
	var who := get_node_or_null(carrier_path) as CharacterBase
	if who == null:
		return
	carrier = who
	_watch_carrier_state(who, true)
	_clear_flight_hitbox()
	# While in a hand the slipper is part of the carrier: it must not shove its
	# own teammate around, and it must not be independently hittable.
	_set_physics_enabled(false)
	# Picked up — whatever the last throw hit is no longer relevant.
	_character.clear_hit_memory()
	_notify_carrier(who, self)
	AudioManager.play_at("grab", _character.global_position) # 4.1
	_set_state(CarryState.CARRIED)

## `lob` rides the SAME broadcast the launch already takes rather than being derived
## per-peer from the velocity — the trajectory alone cannot answer it (a steep flat
## throw at short range and a shallow lob at long range look the same), and every
## peer has to agree, because the steer ceiling below is applied locally on the
## slipper's own pilot. Defaulted so nothing that calls the two-argument form breaks.
@rpc("any_peer", "call_local", "reliable")
func _rpc_set_flying(origin: Vector3, velocity: Vector3, lob: bool = false) -> void:
	flight_is_lob = lob
	_steer_spent = 0.0
	_character.global_position = origin
	# 2026-07-28 — user report: a thrown slipper "doesnt land flat, sometimes
	# it points up from ground... it also goes thru the floor when this
	# happens." _step_carried() overwrites _character's entire transform —
	# BASIS included — to the carrier's tilted hand orientation
	# (CARRY_TILT_DEG, 55°) every physics frame while held. Nothing ever reset
	# that basis on release: only `global_position` was written here and in
	# _rpc_set_loose() below, so the 55° tilt (plus whatever yaw the hand had)
	# rode straight through the whole flight and into landing. A capsule
	# resting on the floor at an angle instead of upright is exactly the kind
	# of resolved-collision edge case that can end up clipping through thin
	# geometry, which matches the floor-tunnelling half of the report.
	# _spin_while_airborne()'s own rotation is on the VISUAL node, a CHILD of
	# this transform, and was never the actual cause — resetting it alone
	# (already correct) could not fix a tilt baked into the parent.
	_character.rotation = Vector3.ZERO
	_flight_velocity = velocity
	_flight_time = 0.0
	_thrower_ignore_left = THROWER_IGNORE_TIME
	_bounces_left = max_bounces
	# ⚠️ A NEW THROW IS A NEW OFFENSIVE EVENT. Clearing here is what makes the
	# rule "once per throw" rather than "once, ever" — the same opponent must
	# be hittable again by the next throw. See CharacterBase._hit_memory.
	_character.clear_hit_memory()
	# Solid again the instant it leaves the hand — it has to be able to bounce
	# off walls and, above all, hit the lata.
	_set_physics_enabled(true)
	if carrier != null and is_instance_valid(carrier):
		_character.add_collision_exception_with(carrier)
		_notify_carrier(carrier, null)
		# B-75: stop watching the thrower the instant it leaves the hand. `carrier`
		# is deliberately still set here (the collision exception is cleared
		# against it on landing), but the slipper is no longer theirs to drop —
		# without this, tagging the thrower mid-flight would land the slipper in
		# mid-air.
		_watch_carrier_state(carrier, false)
	_spawn_flight_hitbox()
	# 4.1 — SLIPPER RELEASE. Two layers, and the split is the point:
	#
	#   * `throw_whoosh` is what a THROWN OBJECT sounds like, so every launch
	#     gets it and it never changes.
	#   * the ability's own launch sound is what THIS slipper is — the wooden
	#     crack of a bakya, the light snap of a havaianas. It is asked of the
	#     ability rather than switched on here, because "what does a Bakya Bash
	#     sound like" is bakya_bash.gd's business; see that file.
	#
	# Duck-typed with has_method(), exactly as _profile() below already asks for
	# get_throw_profile(), so the three Can abilities need no empty override.
	#
	# Broadcast, not host-only: this is inside the _rpc_set_flying handler, so it
	# is already running on every peer. That is why the throw is audible to the
	# taya who has to react to it, which is most of the point of it having a
	# sound at all.
	AudioManager.play_at("throw_whoosh", _character.global_position)
	if _character.ability != null and _character.ability.has_method("play_launch_sfx"):
		_character.ability.play_launch_sfx(_character)
	_set_state(CarryState.FLYING)

@rpc("any_peer", "call_local", "reliable")
func _rpc_set_loose(where: Vector3) -> void:
	_character.global_position = where
	# Defensive, same reasoning as _rpc_set_flying()'s own note — a slipper
	# dropped (not thrown) straight from CARRIED also carries the 55° hand
	# tilt through unless this clears it too.
	_character.rotation = Vector3.ZERO
	_character.velocity = Vector3.ZERO
	_flight_velocity = Vector3.ZERO
	_clear_flight_hitbox()
	# Came to rest — see _rpc_set_flying's note; this is the other end of it.
	_character.clear_hit_memory()
	if carrier != null and is_instance_valid(carrier):
		_character.remove_collision_exception_with(carrier)
		_notify_carrier(carrier, null)
		_watch_carrier_state(carrier, false)
	carrier = null
	_set_physics_enabled(true)
	# 4.1. Only when it actually ARRIVED from somewhere — this same handler is
	# how a slipper is dropped, and how one that was never picked up is put back
	# at round reset. FLYING is the state that means "it just landed".
	if state == CarryState.FLYING:
		AudioManager.play_at("slipper_land", where)
	_set_state(CarryState.LOOSE)

## ---------------------------------------------------------------------------

## Keeps the Person's own `Carrier._held` in step with this node's `carrier`.
## Both are set from the same host broadcast on the same peer, so they cannot
## drift — which matters because the HUD reads one and the throw reads the other.
func _notify_carrier(who: CharacterBase, what: Carriable) -> void:
	var component := who.get_node_or_null("Carrier") as Carrier
	if component != null:
		component.notify_holding(what)

## B-75. A taya tagging the attacker mid-carry has to knock the slipper out of
## their hands — that is most of the point of tagging, and without it the whole
## retrieval scramble can be skipped by simply eating the hit. Any state that is
## not NORMAL drops it: STAGGERED, DOWNED and SEALED are all "this Person is not
## currently holding anything together".
##
## Watched from HERE rather than from character_base.gd, which must never learn
## what carrying is — the same rule that keeps dents and round-win logic out of
## that file. It subscribes to the state_changed signal that already exists, so
## nothing had to be added on the CharacterBase side.
##
## Runs on every peer; only the host acts, because dropping is a transition like
## every other one and host_drop() is where that is decided.
func _on_carrier_state_changed(new_state: CharacterBase.State) -> void:
	if new_state == CharacterBase.State.NORMAL:
		return
	if _is_host():
		host_drop()

## Connected while, and only while, this slipper is actually in someone's hand.
## Guarded both ways because a carrier can be freed mid-hold (see _step_carried)
## and a double-connect would fire host_drop() twice.
func _watch_carrier_state(who: CharacterBase, enable: bool) -> void:
	if who == null or not is_instance_valid(who):
		return
	if enable:
		if not who.state_changed.is_connected(_on_carrier_state_changed):
			who.state_changed.connect(_on_carrier_state_changed)
	elif who.state_changed.is_connected(_on_carrier_state_changed):
		who.state_changed.disconnect(_on_carrier_state_changed)

func _set_state(new_state: CarryState) -> void:
	if new_state == state:
		return
	state = new_state
	carry_state_changed.emit(state)

## The hitbox that rides along with a thrown slipper. Reuses AbilityUtils rather
## than hand-rolling one, so flight hits go through exactly the same host-only
## resolution, team check and Option A/B branching that every other hit does
## (hitbox.gd) — a thrown slipper denting or knocking down a lata is not a
## special case, it is the ordinary hit path with an unusual delivery.
func _spawn_flight_hitbox() -> void:
	_clear_flight_hitbox()
	var profile := _profile()
	_flight_hitbox = AbilityUtils.spawn_pulse_hitbox(
		_character, profile.hit_radius, MAX_FLIGHT_TIME, profile.forces_downed,
		Vector3.ZERO, true)

func _clear_flight_hitbox() -> void:
	if _flight_hitbox != null and is_instance_valid(_flight_hitbox):
		_flight_hitbox.queue_free()
	_flight_hitbox = null

## Disables/enables the body and the hurtbox together. Deliberately NOT used to
## express ownership — see can_be_grabbed_by(); an opponent's loose slipper is
## fully solid and this is never called on account of whose it is.
##
## ⚠️⚠️ B-137 — BOTH WRITES ARE DEFERRED, AND WITHOUT THAT THEY SILENTLY DO
## NOTHING ON THE PATHS THAT MATTER MOST.
##
## Godot refuses both of these while the physics server is mid-step: a
## `CollisionShape3D.disabled` write raises *"Can't change this state while
## flushing queries"* and a `monitorable` write raises *"Function blocked during
## in/out signal"*. Every important caller of this function reaches it from inside
## an `area_entered` callback, because that is where hits resolve:
##
##   * TAGGED MID-CARRY — `hitbox.gd::_on_area_entered` -> `_apply_hit_result` ->
##     `apply_stagger` -> `_set_state` -> `_on_carrier_state_changed` ->
##     `host_drop` -> `_rpc_set_loose` -> here. The re-enable was DROPPED, so the
##     slipper knocked out of a tagged carrier's hands came back with its
##     collision shape still disabled and nothing to stop it sinking through the
##     floor. B-75 calls knocking the slipper loose "most of the point of
##     tagging"; B-101 is the same failure from the other direction.
##   * A ROUND WON BY A TAG — the same callback -> `report_round_win` ->
##     `report_round_result` -> `_reset_world` -> `reset_for_new_round` -> here.
##     The hurtbox stayed non-monitorable into the NEXT round, and
##     `carrier.gd::_find_grabbable()` finds slippers by scanning its GrabArea for
##     Hurtboxes — so the attacker could not pick their own tsinelas up at all.
##     Under Option B a tag ends 18 of 20 rounds (Checklist Phase 9, RUN 3), so
##     this is the common path, not an edge case.
##
## Found by `tools/ai_probe.tscn -- fairness`, which surfaced 11 blocked
## `monitorable` writes and 3 blocked `disabled` writes in a single 20-round run.
## Nothing in the game reported anything; the writes just did not happen.
##
## Deferring is what both engine messages ask for. The cost is that the change
## lands at idle rather than instantly — one frame in which the slipper is still
## intangible, which is invisible and is strictly better than never.
func _set_physics_enabled(enabled: bool) -> void:
	var shape := _character.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null:
		shape.set_deferred(&"disabled", not enabled)
	var hurtbox := _character.get_node_or_null("Hurtbox") as Area3D
	if hurtbox != null:
		hurtbox.set_deferred(&"monitorable", enabled)

## The slipper's own ability carries its flight identity (see throw_profile.gd).
## Duck-typed rather than declared on AbilityBase so the three Can abilities,
## which have no throw, need no empty override.
func _profile() -> ThrowProfile:
	if _character != null and _character.ability != null \
			and _character.ability.has_method("get_throw_profile"):
		var profile := _character.ability.get_throw_profile() as ThrowProfile
		if profile != null:
			return profile
	return DEFAULT_PROFILE

func _is_host() -> bool:
	return not NetworkManager.is_networked() or NetworkManager.is_host()

## Whether the human at THIS machine is the one flying this slipper — gates the
## mid-flight steer so a remote peer's input never curves someone else's throw.
func _is_locally_driven() -> bool:
	if NetworkManager.is_networked():
		return _character.is_multiplayer_authority()
	return true
