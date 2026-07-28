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

	if NetworkManager.is_networked():
		target._apply_hit_result.rpc_id(target.get_multiplayer_authority(), kind, stagger_duration)
		# B-66/Q-8: unlike _apply_hit_result above (targeted at the struck
		# character's own owning peer only), this broadcasts to every peer —
		# otherwise nobody except the struck player ever sees the flash/shake/
		# particles land.
		target._rpc_play_hit_vfx.rpc()
	else:
		target._apply_hit_result(kind, stagger_duration)
		target._rpc_play_hit_vfx()
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
