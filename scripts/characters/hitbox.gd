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
	elif target.state == CharacterBase.State.DOWNED and not target.is_self_rightable():
		kind = "seal"
	elif forces_downed:
		kind = "downed"
	else:
		kind = "stagger"

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
	var knockback: Vector3 = (area as Hurtbox).absorb_knockback(
		_impulse_for(kind == "downed" or kind == "seal"))

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
	# team slipper and they win that round." ANY hitbox from the defending
	# Person landing on the attacking Person — the always-on Bump as much as
	# the Tag ability's own transient hitbox, both resolve through this same
	# function — ends the round for team can outright. Deliberately after the
	# normal stagger/VFX dispatch above, not instead of it: a round-winning
	# tag should still read as contact landing, not as a rules screen
	# appearing out of nowhere. report_round_win() no-ops if the round already
	# ended, so this is safe to call unconditionally; this whole function is
	# already host-only past the NetworkManager guard above, so no further
	# authority check is needed here.
	if owner_character and owner_character.is_person and owner_character.team_is_can_side \
			and target.is_person and not target.team_is_can_side:
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
	var strength := MELEE_KNOCKBACK * (MELEE_FACESLOP_MULTIPLIER if force_downed else 1.0)
	return direction.normalized() * strength + Vector3.UP * (MELEE_KNOCKBACK_LIFT
		* (MELEE_FACESLOP_MULTIPLIER if force_downed else 1.0))
