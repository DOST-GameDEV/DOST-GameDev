extends Area3D
class_name Hurtbox

## The "can be hit here" area for a character. A Hitbox entering this Area3D is what
## registers a bump/special landing (see hitbox.gd). One Hurtbox per character is enough
## for this scope — split into more later only if we need per-limb hit detection.

@export var owner_character: CharacterBase

## Checklist 4.4 — HOW HARD THIS OBJECT IS TO SHOVE.
##
## Lives here for exactly the reason `impact_sfx` below does: it is a property
## of the thing being HIT, not of the thing doing the hitting. A slipper that
## sends a Person sprawling should barely move a tin can that is half-buried on
## its mark, and the striker has no business knowing which is which.
##
## 1.0 passes the incoming impulse straight through; 0.0 makes this object
## immovable. Exported so a scene can override it per unit without a second
## system — nothing sets it today, which is deliberate: one number, one place,
## until a real playtest asks for more.
@export_range(0.0, 2.0, 0.05) var knockback_resistance: float = 1.0

## THE RECEIVING END OF THE FACESLOP. hitbox.gd computes the raw impulse from
## the striker's own motion and hands it here; this decides how much of it this
## particular body actually takes, and returns what CharacterBase should apply.
##
## Kept as a function rather than letting hitbox.gd read `knockback_resistance`
## itself so the striker never has to know the rule — same contract
## `impact_sfx()` already establishes, where the struck object owns the answer.
func absorb_knockback(impulse: Vector3) -> Vector3:
	if owner_character == null or impulse.is_zero_approx():
		return Vector3.ZERO
	# A Guarding Can eats the shove outright, matching
	# CharacterBase.apply_dent()/apply_stagger(), which already no-op a guarded
	# hit. Being knocked flying while successfully blocking would read as the
	# guard having failed.
	if owner_character.is_guarding():
		return Vector3.ZERO
	return impulse * knockback_resistance

## Checklist 4.1 — WHAT THIS OBJECT SOUNDS LIKE WHEN IT IS STRUCK.
##
## Lives here rather than in hitbox.gd because it is a property of the thing
## being hit, not of the thing doing the hitting: a slipper, a bump and a
## Bakya Bash landing on the same lata all have to produce the same lata. That
## is the whole reason the impact set is built from one shared partial series
## (see the CAN_PARTIALS note in tools/audio/generate_sfx.py) — hitting the can
## must always sound like hitting THE can.
##
## `kind` is hitbox.gd's own resolution string ("dent"/"seal"/"downed"/
## "stagger"), so the sound tracks the OUTCOME as well as the material. The
## alternative — one impact sound for everything — makes a round-ending seal
## and a glancing stagger indistinguishable by ear, which in a game this noisy
## is most of what audio is for.
##
## `from_melee` is the one thing the struck object genuinely cannot know and
## the striker can: hitbox.gd's `requires_bump_window`, i.e. "this was the
## always-present body-check Hitbox, not a hitbox an ability spawned". It only
## changes the answer for a Person, and it is the whole bump-versus-tag
## distinction — shoulder-charging the attacker and CATCHING them are different
## events with different consequences (hitbox.gd's round-win branch fires on
## one of them), so they must not share a sound.
func impact_sfx(kind: String, from_melee: bool) -> String:
	if owner_character == null:
		return "bump"
	if kind == "seal":
		return "lata_seal"
	if owner_character.is_can:
		# A dent (Option A) and a knockdown (Option B) are the same event to a
		# player watching — the can just got hit hard — but "downed" is the one
		# with a tumble in it. Note this is deliberately indifferent to
		# `from_melee`: bumping the lata, throwing a slipper at it and landing a
		# Bakya Bash all have to produce the same object. See the CAN_PARTIALS
		# note in tools/audio/generate_sfx.py.
		return "lata_knockdown" if kind == "downed" else "lata_impact"
	if owner_character.is_person:
		return "bump" if from_melee else "tag"
	# A Prop that is not the Can this round — i.e. the tsinelas being kicked
	# around. Rubber, not tin.
	return "slipper_land"
