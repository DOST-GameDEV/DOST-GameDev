extends Area3D
class_name Hitbox

## Attach as a child Area3D on a character (or spawn transiently for a Special).
## B-26: this used to say "both Hitbox and Hurtbox default to layer 1" — they
## don't. CharacterBase.tscn sets Hurtbox to layer 2 / mask 0 and Hitbox to
## layer 0 / mask 2 (Hitbox only ever emits into Hurtbox's layer, Hurtbox never
## emits into anything), which is already correct; the old comment was just
## wrong in a load-bearing place.

## Who owns this hitbox — used so a character can't hit itself and so the
## receiving side knows who staggered it.
@export var owner_character: CharacterBase
@export var stagger_duration: float = CharacterBase.BUMP_STAGGER_TIME
## If true, a hit also forces the target into the Downed state (e.g. a heavy special
## like Bakya Bash's "instant-down on direct hit") instead of just staggering it.
@export var forces_downed: bool = false
## True for the character's own always-present melee Hitbox (only registers hits
## during owner_character.is_hitbox_active(), i.e. the brief window after pressing
## bump). Set false for a hitbox spawned/enabled by a Special, which is active for
## whatever duration that ability defines instead.
@export var requires_bump_window: bool = true

## Melee shove, in metres/second, for a hitbox with no ThrowProfile behind it —
## a body-check or an ability pulse. A thrown slipper never uses these; it
## answers with its own profile instead (see _impulse_for).
const MELEE_KNOCKBACK: float = 3.4
const MELEE_KNOCKBACK_LIFT: float = 1.6
const MELEE_FACESLOP_MULTIPLIER: float = 1.8

signal landed_on(target: CharacterBase)

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	monitoring = true

## B-08: called by CharacterBase right when its bump window opens. area_entered
## only fires on a NEW overlap, so someone already standing inside this Hitbox
## at press time (the normal case — you walk into someone, then press bump)
## never generated one, and the bump silently missed. Re-run the same
## resolution against everyone already overlapping.
func sweep_overlaps() -> void:
	for area in get_overlapping_areas():
		_on_area_entered(area)

func _on_area_entered(area: Area3D) -> void:
	if not (area is Hurtbox):
		return
	var target := (area as Hurtbox).owner_character
	if target == null or target == owner_character:
		return
	# B-09: no friendly fire — previously there was no team identity on
	# CharacterBase at all, so a defending Person could dent/seal its own
	# team's Can, and three of those under Option A lose your own round.
	if owner_character and target.team == owner_character.team:
		return
	if requires_bump_window and owner_character and not owner_character.is_hitbox_active():
		return

	# Session 6, host-authoritative combat: every peer's Area3D still detects
	# this overlap locally (positions are replicated to everyone), but only
	# the host is allowed to act on it. Otherwise two peers hitting each other
	# would each decide the outcome independently and disagree. Clients just
	# wait for the state change to arrive via MultiplayerSynchronizer once the
	# host tells the target's owning peer what happened (see
	# CharacterBase._apply_hit_result).
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return

	# ⚠️ ONE HIT PER OFFENSIVE EVENT, PER TARGET. Deliberately AFTER the host
	# gate above — the memory is only ever consulted where hits are actually
	# resolved, so a client never populates one and the two can never disagree.
	#
	# Deliberately asked of the OWNER CHARACTER, not kept in this Area3D: a
	# thrown slipper carries two live hitboxes at once (this scene's melee one
	# plus Carriable's per-throw pulse one) and they must share one memory, or
	# a single clean frame of contact still resolves twice. See
	# CharacterBase._hit_memory for the measured numbers this fixes.
	if owner_character != null and not owner_character.register_hit_once(target):
		return

	# Session 7: this is generic to ANY hitbox/hurtbox pair — Person-vs-Person,
	# Person-vs-Prop, or Prop-vs-Prop all resolve through the same stagger/
	# downed/seal machinery below. Only round_manager.gd's tracked-Cans list
	# (which only ever contains Props, never Persons — see is_can doc on
	# CharacterBase) decides whether a MOST hits actually matter for round
	# win; hitting a Person is ordinarily stun-only flavor (tagging), with one
	# deliberate exception below (2026-07-28).
	#
	# An offense-side hitbox touching an already-Downed (past self-right
	# window) Can seals it, regardless of forces_downed — GDD's "reach it and
	# seal it".
	var kind: String
	if GameLaunch.game_mode == GameLaunch.GameMode.OPTION_A and target.is_can:
		# Option A: a hit landing on a Can is a dent, full stop — no Downed/Seal
		# state machine involved at all (see CharacterBase.apply_dent). Hits on
		# a Person or Slipper still just fall through to stagger below, same
		# stun-only rule as Option B.
		kind = "dent"
	# ⚠️⚠️ THE SEAL-ON-HIT USED TO BE HERE AND §1.9 IS WHY IT IS DELETED. It read:
	#
	#     elif target.is_can and target.state == DOWNED and not target.is_self_rightable():
	#         kind = "seal"
	#
	# i.e. touch a lata that is past its 1.25 s appeal window and it is SEALED, and one
	# sealed lata is every tracked can sealed, which ends the round outright
	# (`round_manager.gd::_on_tracked_can_state_changed`).
	#
	# That was survivable while `DOWNED_MAX_TIME` stood the lata up at 2.0 s no matter
	# where it lay: the seal window was 0.75 s wide and you had to be standing there for
	# it. §1.9 makes a displaced lata stay down until its taya comes for it — so the same
	# branch becomes **an unbounded instant win available to anyone who walks over and
	# presses bump.** One button, next to an object, ends the round with no counterplay
	# worth the name. That is the tap-out, rebuilt by accident and pointing the other way,
	# eight commits after this file deleted it.
	#
	# ⚠️ NOTHING REPLACES IT, AND THAT IS THE DESIGN. `Design.md` §7 lists the attacking
	# side's three wins and a seal is not among them: the countdown reaching zero, a direct
	# Ground Smash, and FALL_LIMIT. What a follow-up hit on a downed lata does now is what
	# every other hit does — it SHOVES it, further from the circle, so the taya's channel
	# is a longer run and the save is a worse trade. Continuous, legible, and it stacks
	# with the clock instead of skipping it.
	#
	# `seal()` and the SEALED state survive untouched; Option A and the state machine both
	# still name them, and nothing about a Person changed.
	elif forces_downed:
		kind = "downed"
		# THE LUCKY FALL — human request, 2026-07-29: *"sometimes make it so that
		# it can land on its head/back and this isnt a point for the enemy."*
		#
		# ⚠️ ROLLED HERE AND NOWHERE ELSE. This line is already past the host gate
		# above, so exactly one machine rolls it; the result then travels as its
		# own `kind` through the SAME broadcast every other outcome uses, and each
		# peer just applies what it was told. Rolling inside
		# CharacterBase._apply_hit_result instead would put a randf() on a function
		# that runs per-peer, and the peers would disagree about whether the round
		# had just been decided.
		#
		# Cans only. A Person knocked over has no "landed on its head" reading and
		# no fall count to be spared from.
		if target.is_can and randf() < CharacterBase.lucky_fall_chance:
			kind = "downed_lucky"
	else:
		kind = "stagger"

	# ⚠️ THE BUMP METER DECIDES WHAT A BODY-CHECK IS NOW. `Design.md` §4.
	#
	# `requires_bump_window` is true only on CharacterBase.tscn's always-present melee
	# box, so this selects the charged bump and nothing else — an ability pulse, a
	# thrown slipper and a shockwave all skip it. A TAP (power 0) is a NUDGE: it moves
	# you and does not stun you, which is the whole distinction the human asked for and
	# is why it cannot simply be a short stagger. A stagger of any length drops the
	# target's carried tsinelas (`carriable.gd::_on_carrier_state_changed` fires on any
	# non-NORMAL state), and a tap that stripped the attacker's slipper would make the
	# 1.35 s charge pointless.
	var bump_duration := stagger_duration
	if requires_bump_window and owner_character != null and owner_character.is_person:
		bump_duration = owner_character.bump_stagger_duration()
		if kind == "stagger" and bump_duration <= 0.0:
			kind = "nudge"

	# ⚠️ THE LONG-THROW PUNISH. `Design.md` §3.1, human instruction: a max-power throw
	# from behind the throwing line that hits the DEFENDER applies a 5-second hit stun.
	#
	# Asked of the slipper rather than recomputed here, for the same reason `sfx` is
	# asked of the hurtbox and the impulse is asked of the carriable: the thrower's
	# distance from the circle and the charge it released at are facts about the THROW,
	# and they were decided on the host in `carriable.gd::host_throw` where both were
	# already in hand. Re-deriving them at resolution time would mean reading a position
	# the thrower has since walked away from.
	if kind == "stagger" or kind == "nudge":
		var punish := _long_throw_punish(target)
		if punish > 0.0:
			kind = "stagger"
			bump_duration = punish

	# ⚠️ TELL THE HOST'S OWN ROUND MANAGER, HERE, WHERE THE ROLL WAS JUST MADE.
	#
	# This line is already past the host gate above, so exactly one machine reaches it,
	# and `kind` is the decision that machine just took. RoundManager used to infer the
	# same fact by reading `target.last_fall_scored` from its own `state_changed`
	# handler — but that flag is written by `_apply_hit_result` on the TARGET'S OWN PEER
	# and is not replicated, so for a client-owned lata the host was reading a stale
	# `true` and charging the defence for every lucky fall. Measured on two real peers:
	# 0 lucky falls counted correctly out of 26 knockdowns of a client-owned can. See
	# `round_manager.gd::host_note_fall` for the full account.
	if target.is_can and kind.begins_with("downed"):
		RoundManager.host_note_fall(target, kind == "downed")

	# 4.1: which impact sound this hit makes. Asked of the HURTBOX, not decided
	# here — see hurtbox.gd::impact_sfx for why the struck object owns that
	# answer. Resolved on the host, where `kind` was just decided, and carried
	# through the same broadcast the visual feedback already uses so the sound
	# and the hitstop land on the same frame on every peer (see
	# CharacterBase._flash_hit).
	var sfx: String = (area as Hurtbox).impact_sfx(kind, requires_bump_window)

	# THE FACESLOP. Same contract as `sfx` directly above, and deliberately
	# right next to it: this file computes the impulse from the STRIKER's own
	# motion, then asks the HURTBOX how much of it this particular body takes
	# (hurtbox.gd::absorb_knockback). Neither side knows the other's rule.
	#
	# `kind` is already resolved above, so a hit that actually knocks the target
	# down gets the profile's faceslop multiplier and a hit that merely staggers
	# does not — the difference between a comedy launch and a nudge.
	# `begins_with("downed")` so the lucky fall takes the same faceslop as a
	# scoring one — it is the same physical knockdown and has to look like it.
	var knockback: Vector3 = (area as Hurtbox).absorb_knockback(
		_impulse_for(kind.begins_with("downed") or kind == "seal"))

	if NetworkManager.is_networked():
		target._apply_hit_result.rpc_id(
			target.get_multiplayer_authority(), kind, bump_duration, knockback)
		# B-66/Q-8: unlike _apply_hit_result above (targeted at the struck
		# character's own owning peer only), this broadcasts to every peer —
		# otherwise nobody except the struck player ever sees the flash/shake/
		# particles land.
		target._rpc_play_hit_vfx.rpc(sfx)
	else:
		target._apply_hit_result(kind, bump_duration, knockback)
		target._rpc_play_hit_vfx(sfx)
	landed_on.emit(target)

	# THE HIT PENALTY — the slow a full-charge bump leaves behind, on top of the stun.
	# Deliberately NOT part of `_apply_hit_result`'s `kind`: it is a property of the
	# STRIKE (only a charged bump produces one), not of the outcome, and widening that
	# RPC's signature to carry it would break every older peer's four-argument call.
	# Routed as its own broadcast for the same reason the VFX is.
	if requires_bump_window and owner_character != null and owner_character.is_person \
			and owner_character.bump_power() >= 0.99:
		if NetworkManager.is_networked():
			target._rpc_apply_hit_penalty.rpc_id(target.get_multiplayer_authority())
		else:
			target._rpc_apply_hit_penalty()

	# ⚠️⚠️ §1.4 — "DROPS THE ATTACKER'S TSINELAS **FAR AWAY**", AND THE "FAR AWAY" HALF
	# WAS NOT BUILT. A charged bump already drops the slipper, for free and with no code
	# of its own: any non-NORMAL state fires `carriable.gd::_on_carrier_state_changed`,
	# which calls `host_drop()`, which broadcasts the slipper LOOSE **at the carrier's own
	# feet**. So the whole cost of eating a 1.35 s power bump was to bend down and pick it
	# up again — and the retrieval scramble, which is the thing the drop is supposed to
	# buy the defence, never happened.
	#
	# Told to the slipper HERE, where the strike is, rather than derived over there where
	# the drop is, for one reason: the drop's own trigger is a state change, and networked
	# that state is applied on the CARRIER'S peer and comes back to the host as
	# replication, whole frames later. By then this hit — its direction, its charge — is
	# gone. So the host notes the punt at the instant it resolves the bump and
	# `host_drop()` spends it whenever the drop actually lands. See `host_note_punt`.
	#
	# Direction is the shove the target just took, which is already the striker's own
	# travel falling back to their facing (`_impulse_for`) — so the slipper leaves along
	# the line the bump sent its carrier, and a taya who body-checks an attacker away from
	# the circle sends their tsinelas the same way.
	if requires_bump_window and owner_character != null and owner_character.is_person \
			and owner_character.bump_power() > 0.0 and kind == "stagger":
		var carrier := target.get_node_or_null("Carrier") as Carrier
		var slipper: Carriable = carrier.held() if carrier != null else null
		if slipper != null:
			var away := Vector3(knockback.x, 0.0, knockback.z)
			if away.length() < 0.01:
				away = target.global_position - owner_character.global_position
				away.y = 0.0
			if away.length() >= 0.01:
				slipper.host_note_punt(away.normalized(), owner_character.bump_power())

	# ⚠️⚠️ THE ROUND-WINNING TAG USED TO BE HERE AND IT IS DELETED. 2026-07-30.
	#
	# Human report: *"the defender role currently feels far too overpowered."* This
	# branch is most of why. A defending Person who touched the attacking Person ended
	# the round outright — 18 of 20 rounds ended that way in the last fairness run — and
	# the attacker's only counter was never to be within reach, which is avoidance
	# rather than counterplay. Narrowing it to the Tag pulse (`not requires_bump_window`)
	# in an earlier pass made it slower to produce and did not change what it WAS: a
	# proximity coin flip that skipped the entire game.
	#
	# **The defence has no instant win any more.** It wins by surviving the 90 s round,
	# and the tools it survives with are the charged bump (`Design.md` §4), the lata's
	# own dash and smash, and the circle countdown it must keep resetting. Every one of
	# those is a spend the attacker can see and play around.
	#
	# `person_action.gd` — the Tag ability itself — went with it. `Design.md` §1.

## ⚠️ THE 5-SECOND PUNISH, AND IT IS ASKED OF THE SLIPPER, NOT MEASURED HERE.
##
## `Design.md` §3.1: a MAX-POWER throw released from behind the 6.0 throwing line that
## lands on the DEFENDING Person stuns them for five seconds. Both conditions are facts
## about the throw at RELEASE — where the thrower stood and what the charge had reached
## — and `carriable.gd::host_throw` is the one place that knew both, on the one machine
## that decides. Recomputing them here would read a thrower's position several frames
## and up to a couple of metres later.
##
## Returns 0.0 for every hit that is not that hit, which is nearly all of them: a bump,
## an ability pulse, a shockwave, a short throw, a partial charge, and any hit landing
## on a lata or on a tsinelas rather than on the taya.
func _long_throw_punish(target: CharacterBase) -> float:
	if owner_character == null or not is_instance_valid(owner_character):
		return 0.0
	# The taya only. Knocking the lata a metre is already what a long throw is FOR; a
	# five-second stun on the object as well would make the bonus a round-ender.
	if not target.is_person or not target.team_is_can_side:
		return 0.0
	var carriable := owner_character.get_node_or_null("Carriable") as Carriable
	if carriable == null:
		return 0.0
	return carriable.long_throw_punish_stun()

## The raw impulse this hitbox should impart, before the struck object's own
## resistance. Two sources, in priority order:
##
##   1. A slipper in flight answers for itself (carriable.gd::knockback_impulse)
##      — its ThrowProfile owns how heavy that particular slipper hits.
##   2. Anything else is a melee contact: a body-check or an ability pulse. The
##      shove comes from the striker's own travel, so walking into someone barely
##      moves them and charging into them does not. Falls back to the striker's
##      facing when they are standing still, since a stationary bump still has to
##      push somewhere and pushing nowhere reads as the hit not landing.
func _impulse_for(force_downed: bool) -> Vector3:
	if owner_character == null or not is_instance_valid(owner_character):
		return Vector3.ZERO
	var carriable := owner_character.get_node_or_null("Carriable") as Carriable
	if carriable != null:
		var thrown := carriable.knockback_impulse(force_downed)
		if not thrown.is_zero_approx():
			return thrown
	var travel := owner_character.velocity
	travel.y = 0.0
	var direction := travel.normalized() if travel.length() > 0.5 \
		else -owner_character.global_transform.basis.z
	direction.y = 0.0
	if direction.length() < 0.01:
		return Vector3.ZERO
	# ⚠️ A PERSON'S BODY-CHECK IS THE BUMP METER NOW, AND ITS NUMBERS COME FROM THE
	# CHARGE. `MELEE_KNOCKBACK` below survives for everything else that reaches this
	# line — an ability pulse, a shockwave, a Prop shoulder-charging something — because
	# those have no meter behind them and still have to shove somewhere.
	#
	# The direction is unchanged and is still the striker's own travel, falling back to
	# their facing: a charged bump delivered while running should send the target the
	# way the runner was going, which is what makes a committed charge read as weight.
	if requires_bump_window and owner_character.is_person:
		return owner_character.bump_impulse(direction)
	# LAKAS. The striker's own trait scales what it delivers; the target's TATAG
	# then scales what it accepts (character_base.gd::apply_knockback). Two
	# separate questions, answered at the two ends, exactly as `sfx` and
	# `absorb_knockback` already are.
	var power := owner_character.trait_power_scale()
	var strength := MELEE_KNOCKBACK * power * (MELEE_FACESLOP_MULTIPLIER if force_downed else 1.0)
	return direction.normalized() * strength + Vector3.UP * (MELEE_KNOCKBACK_LIFT * power
		* (MELEE_FACESLOP_MULTIPLIER if force_downed else 1.0))
