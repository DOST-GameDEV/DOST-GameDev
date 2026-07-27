extends AbilityBase
class_name BagsakBomb

## Dyaryo — Bagsak Bomb. The lob.
##
## TASK 0 CHANGED WHAT THIS IS. It used to be a leap-slam: the Tsinelas was a
## character that walked around and this made it jump and burst. Since the
## slipper is now a thrown, retrieved object rather than a unit that charges in
## (see docs/Handoff.md §4's T-block), a Tsinelas special is no longer a button
## the slipper presses — it is the identity of the slipper WHEN THROWN.
##
## The move survives intact, just relocated: Bagsak Bomb is still "goes up, comes
## down hard, bursts on impact". It is now expressed as the arc (30°), the extra
## gravity, and the wide impact radius in throw_bagsak.tres, and it is delivered
## by the attacking Person's charge-throw instead of by the slipper's own legs.

const PROFILE: ThrowProfile = preload("res://scripts/abilities/resources/throw_bagsak.tres")

## Read by carriable.gd when this slipper is launched. Duck-typed rather than
## declared on AbilityBase, so the three Can abilities need no empty override.
func get_throw_profile() -> ThrowProfile:
	return PROFILE

## Returns false, which per AbilityBase.activate()'s B-11 contract means "this
## press did nothing, don't burn the cooldown". A thrown slipper has no button of
## its own: its offensive power is the throw, and while LOOSE its escape tool is
## the Prop-side Dash it already shares with every other Tsinelas
## (character_base.gd::_process_dash). Adding a second self-propelled attack here
## would put back exactly the "the slipper charges in by itself" reading Task 0
## removed.
func _do_activate(_character: CharacterBody3D) -> bool:
	return false
