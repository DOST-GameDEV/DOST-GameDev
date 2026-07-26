extends AbilityBase
class_name PersonAction

## Person — Tag / Throw: the mechanic GDD Section 3 describes but Session 7 flagged
## as not real yet ("mechanically both are just the existing Bump/hit interaction
## today — that's a real gap"). Session 8: gives every Person this ability on the
## existing `special_ability` input, which was previously unused for Person since
## `ability` was always null there (see character_base.gd _physics_process — the
## input action already existed and just had nothing plugged into it).
##
## One button, two behaviors, chosen automatically from `team_is_can_side`
## (character_base.gd) rather than a separate input — per the GDD, a Person
## doesn't choose Tag vs Throw, its team's current side decides which half of
## "tag on defense / throw on offense" applies this round:
## - team_is_can_side true  (defense) → Tag: short range, guard-range flavor.
## - team_is_can_side false (offense) → Throw: longer range, closing distance on
##   a fleeing Slipper/Can per the GDD's "throws the Slipper at the Can".
##
## Both are modeled as a spawned pulse hitbox (AbilityUtils, same helper every
## other special uses) placed ahead of the Person, with requires_bump_window
## left at its default false via spawn_pulse_hitbox — unlike the shared melee
## Hitbox, this doesn't need the press-to-bump active window, so it reads as a
## distinct ranged action rather than a reskinned Bump. Hit resolution itself
## (stagger/downed/seal/dent) is untouched — this is generic to any hitbox per
## hitbox.gd, same as Bump or any roster special.
##
## Exact range/radius numbers are a Session 8 judgment call, not confirmed by the
## team — GDD doesn't specify. Throw reaching further than Tag is the only part
## that's load-bearing; revisit both once someone has this in-editor.

@export var tag_range: float = 1.5
@export var tag_radius: float = 1.0
@export var tag_duration: float = 0.2
@export var throw_range: float = 4.0
@export var throw_radius: float = 0.75
@export var throw_duration: float = 0.2

func _do_activate(character: CharacterBody3D) -> void:
	var c := character as CharacterBase
	if c.team_is_can_side:
		# Defense: tagging an attacker — short range, guard-range flavor.
		AbilityUtils.spawn_pulse_hitbox(c, tag_radius, tag_duration, false, Vector3(0, 0, -tag_range))
	else:
		# Offense: throwing the Slipper at the Can — reaches further.
		AbilityUtils.spawn_pulse_hitbox(c, throw_radius, throw_duration, false, Vector3(0, 0, -throw_range))
