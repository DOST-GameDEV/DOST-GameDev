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

func _do_activate(character: CharacterBody3D) -> bool:
	var c := character as CharacterBase
	AbilityUtils.spawn_pulse_hitbox(c, tag_radius, tag_duration, false, Vector3(0, 0, -tag_range))
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
	return true
