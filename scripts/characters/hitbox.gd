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
	# ⚠️ `target.is_can` ADDED — sealing is a LATA rule and always was. SEALED has
	# no recovery path, so sealing a Person takes them out of the round for good.
	# The GDD's "reach it and seal it" is about the can standing in the circle;
	# nothing in the game ever intended a Person to be sealable, and this only
	# became reachable when B-134 made thrown slippers actually knock things down.
	elif target.is_can and target.state == CharacterBase.State.DOWNED \
			and not target.is_self_rightable():
		kind = "seal"
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
			target.get_multiplayer_authority(), kind, stagger_duration, knockback)
		# B-66/Q-8: unlike _apply_hit_result above (targeted at the struck
		# character's own owning peer only), this broadcasts to every peer —
		# otherwise nobody except the struck player ever sees the flash/shake/
		# particles land.
		target._rpc_play_hit_vfx.rpc(sfx)
	else:
		target._apply_hit_result(kind, stagger_duration, knockback)
		target._rpc_play_hit_vfx(sfx)
	landed_on.emit(target)

	# User feedback, 2026-07-28: "the person on team can may tag the human on
	# team slipper and they win that round." Deliberately after the normal
	# stagger/VFX dispatch above, not instead of it: a round-winning tag should
	# still read as contact landing, not as a rules screen appearing out of
	# nowhere. report_round_win() no-ops if the round already ended, so this is
	# safe to call unconditionally; this whole function is already host-only past
	# the NetworkManager guard above, so no further authority check is needed.
	#
	# ⚠️⚠️ `and not requires_bump_window` — A BUMP IS NOT A TAG, AND UNTIL NOW IT WAS.
	# Human report, 2026-07-30: *"make tag mechanics better, they feel so buns."*
	#
	# This condition used to accept ANY hitbox from the defending Person, and its own
	# note said so out loud: "the always-on Bump as much as the Tag ability's own
	# transient hitbox, both resolve through this same function". So the single most
	# decisive event in the game — a tag ends the round outright, and 18 of 20 rounds
	# end that way (Checklist Phase 9, RUN 3) — could be produced by WALKING INTO
	# SOMEONE and pressing the shove button. The Tag ability had no mechanical identity
	# at all: it was a second, slower way to do what body contact already did.
	#
	# That is most of what "feels buns" is. A round-ender with no commitment, no
	# telegraph and no distinct input is a coin flip on proximity, and the defender's
	# best play is to stand next to the attacker and mash.
	#
	# ⚠️ AND THE CODE ALREADY BELIEVED THE DISTINCTION EVERYWHERE ELSE — this line was
	# the outlier. `hurtbox.gd::impact_sfx()` takes `from_melee` (i.e. exactly this
	# flag) and returns "bump" or "tag" precisely because, in its own words,
	# "shoulder-charging the attacker and CATCHING them are different events with
	# different consequences (hitbox.gd's round-win branch fires on one of them)". It
	# fired on both. The audio has been telling the truth about a rule the rules did not
	# enforce.
	#
	# `requires_bump_window` is true only on CharacterBase.tscn's always-present melee
	# box and false on every hitbox an ability spawns (ability_utils.gd sets it), so this
	# selects the Tag pulse and nothing else. A bump still staggers, still knocks the
	# slipper out of a carrier's hands (B-75, "most of the point of tagging"), and still
	# shoves — it simply no longer wins the round by accident.
	if owner_character and owner_character.is_person and owner_character.team_is_can_side \
			and target.is_person and not target.team_is_can_side \
			and not requires_bump_window:
		RoundManager.report_round_win(true) # Cans win the round

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
	# LAKAS. The striker's own trait scales what it delivers; the target's TATAG
	# then scales what it accepts (character_base.gd::apply_knockback). Two
	# separate questions, answered at the two ends, exactly as `sfx` and
	# `absorb_knockback` already are.
	var power := owner_character.trait_power_scale()
	var strength := MELEE_KNOCKBACK * power * (MELEE_FACESLOP_MULTIPLIER if force_downed else 1.0)
	return direction.normalized() * strength + Vector3.UP * (MELEE_KNOCKBACK_LIFT * power
		* (MELEE_FACESLOP_MULTIPLIER if force_downed else 1.0))
