extends AbilityBase
class_name PersonAction

## Person — Tag. The defensive half of the old "Tag / Throw" pair; the offensive
## half is gone as of T-4 (v4.4).
##
## WHAT CHANGED AND WHY. Until Task 0 this script was both halves, switched on
## `team_is_can_side`: Tag on defence, and on offence a "Throw" that was a 0.75m
## pulse hitbox blinking on 4 metres ahead for 0.2s. That was the fake throw —
## nothing ever left anyone's hands, which is the single reason the build did not
## read as tumbang preso (§0.7). The real throw now lives in `carrier.gd`: hold
## `special_ability` to charge, release and the slipper physically leaves the
## hand on an arc.
##
## T-4 asked whether the orphaned offence branch was a feature or dead code, and
## the answer is BOTH, split apart:
##
##   * As a THROW it is dead code, and worse than dead — an invisible sphere
##     appearing 4m in front of an attacker is exactly the thing Task 0 removed.
##     Deleted.
##   * As a Person's empty-handed action it is a real need. An attacker whose
##     slipper is on the ground is mid-retrieval-scramble, which is the tensest
##     moment in the game, and leaving them with literally no action while the
##     taya chases them down is worse than the fake throw was.
##
## So there is now ONE behaviour for every Person regardless of side: a short
## Tag. `character_base.gd` gates this button behind `not _carrier_is_holding()`,
## so a Person with a slipper in hand gets the charge-throw and never reaches
## here; a Person with empty hands tags, whichever side they are on.
##
## BALANCE NOTE, flagged deliberately: an attacking Person's reach drops from
## `throw_range` 4.0 to `tag_range` 1.5. That is a real change and it is the
## intended one — 4m was the reach of a ranged attack that no longer exists.
## Reverse it by giving the offence side its own range export again if play
## disagrees; nothing else depends on the distinction.
##
## Tagging is stun-only either way. A hit on a Person never has a round-win
## effect (see hitbox.gd) — only the tracked Cans decide rounds.
##
## Range/radius remain a judgment call the team has never confirmed; the GDD does
## not specify. Revisit once someone has played it.

@export var tag_range: float = 1.5
@export var tag_radius: float = 1.0
@export var tag_duration: float = 0.2

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE TAG IS A COMMITTED ACTION NOW. Human report, 2026-07-30: *"make tag
## mechanics better, they feel so buns."*
##
## Three things were wrong with it and none of them were the numbers:
##
##  1. IT HAD NO IDENTITY. `hitbox.gd`'s round-win branch accepted any hitbox from the
##     defending Person, so walking into the attacker and pressing bump ended the round
##     exactly as a tag did. Fixed there, not here — see that condition's own note.
##  2. IT HAD NO WIND-UP. The pulse appeared on the same frame as the press. A tag ends
##     the round outright and 18 of 20 rounds end that way (Checklist Phase 9, RUN 3),
##     so the single most decisive event in the game had a zero-frame telegraph. There
##     was nothing to react to and therefore nothing to play against: the attacker's
##     only counter was never to be within 2.5 m, which is not counterplay, it is
##     avoidance. `TAG_WINDUP` is the reaction window it never had.
##  3. IT HAD NO WHIFF PUNISH. Press, miss, nothing happens, press again in 1.5 s. A
##     defender's best play was to stand next to the attacker and mash, and no read the
##     attacker made could be rewarded. `TAG_RECOVERY` makes a miss cost something.
##
## Together those turn "the taya presses a button near you and the round is over" into a
## lunge you can bait, which is what the GDD's own "light melee" reach was always for.
##
## ⚠️ WHAT WAS DELIBERATELY *NOT* TOUCHED: `cooldown` (1.5 s in person_action.tres),
## `tag_range` and `tag_radius`. Those are balance dials and there are no human play
## notes for them yet (`Handoff.md` §5 is empty on this), so retuning them would be
## tuning by taste. The structure is what was broken. The two constants below are new
## behaviour rather than retunes, and both are sized off numbers that already exist.
## ---------------------------------------------------------------------------

## Seconds between the press and the hitbox going live — the lunge you can see coming.
##
## Sized against the throw it has to be readable next to: `Carrier.CHARGE_FULL_TIME` is
## 0.9 s and `AIController.ATTACKER_MIN_WINDUP` is 0.42 s "because a human needs roughly
## a third of a second to see a wind-up and start moving". A tag is a snap, not a charge,
## so it gets a fraction of that — enough to be a distinct beat and to be beaten by a
## dash (`DASH_DURATION` 0.15), not enough to feel like input lag.
const TAG_WINDUP: float = 0.14
## Seconds the tagger is slowed after committing, and how much of its speed it keeps.
##
## ⚠️ ROUTED THROUGH `enter_speed_zone()`/`exit_speed_zone()`, WHICH ALREADY EXIST AND
## ALREADY STACK CORRECTLY. B-17 made that pair handle overlapping sources and apply the
## most restrictive one, so a tag whiffed in mud is slow for both reasons and neither
## cancels the other. No new state, no second slow system, nothing in
## `character_base.gd` to change — the same rule that kept the lob out of a new
## ThrowProfile field.
##
## 0.45 s is half a full charge, so a baited tag genuinely buys the attacker a wind-up
## rather than a token pause; the flat throw's whole flight is 0.32 s.
const TAG_RECOVERY: float = 0.45
const TAG_RECOVERY_SPEED: float = 0.45

func _do_activate(character: CharacterBody3D) -> bool:
	var c := character as CharacterBase
	# ⚠️ NO VISUAL CALL HERE, DELIBERATELY. `character_base.gd` already broadcasts one on
	# the ability press itself (see `broadcast_visual_action`), on the frame of the press
	# and to every peer — which is what makes the wind-up below a telegraph rather than
	# just a delay. Playing a second clip from here would immediately override it.
	# Checklist 4.1 — the SWING, not the connection. Landing a tag is voiced by
	# the struck Person's own hurtbox (hurtbox.gd::impact_sfx returns "tag"), so
	# this is deliberately the whiff: quiet, and present whether or not anything
	# was in reach.
	#
	# It exists because tag_range is only 1.5 — this script's own balance note
	# flags that as a real reduction from the deleted 4.0 throw — so missing is
	# the common case, and a button that does nothing audible at all when you
	# miss reads as an input that did not register rather than as a miss.
	AudioManager.play_at("throw_whoosh", c.global_position, -10.0)

	# ⚠️ CAPTURE THE INSTANCE ID, NOT THE NODE, and re-check validity in the callback.
	# Same reasoning `ability_utils.gd::spawn_pulse_hitbox` records for its own self-free
	# timer: a lambda holding the node keeps a freed character's reference alive and the
	# `is_instance_valid` guard inside it never gets to run. A round can end, and a
	# character can leave the match, inside 0.14 s.
	var id := c.get_instance_id()
	var radius := tag_radius
	var duration := tag_duration
	var reach := tag_range
	c.get_tree().create_timer(TAG_WINDUP).timeout.connect(func() -> void:
		var who := instance_from_id(id) as CharacterBase
		if who == null or not is_instance_valid(who):
			return
		# ⚠️ A TAG INTERRUPTED IS A TAG THAT MISSED. If the taya was staggered, knocked
		# down or sealed during its own wind-up, the catch must not land anyway — that
		# window is exactly what the attacker is now able to punish, and honouring it is
		# the difference between a commitment and a delay.
		if who.state != CharacterBase.State.NORMAL:
			return
		AbilityUtils.spawn_pulse_hitbox(who, radius, duration, false, Vector3(0, 0, -reach)))

	# The recovery starts at the press, not at the hitbox: the whole action is the
	# commitment, and a defender who presses and then walks away freely has committed to
	# nothing. Released by a second timer rather than tracked as state, for the same
	# reason the wind-up is a timer — this ability owns no per-frame tick.
	c.enter_speed_zone(TAG_RECOVERY_SPEED)
	c.get_tree().create_timer(TAG_RECOVERY).timeout.connect(func() -> void:
		var who := instance_from_id(id) as CharacterBase
		if who != null and is_instance_valid(who):
			who.exit_speed_zone(TAG_RECOVERY_SPEED))
	return true
