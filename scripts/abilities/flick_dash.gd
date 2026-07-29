extends AbilityBase
class_name FlickDash

## Havaianas — Flick Dash. The line drive.
##
## TASK 0 CHANGED WHAT THIS IS — see bagsak_bomb.gd's header.
##
## This script's own comment already asked for this, before Task 0 existed:
## "Whether this should actually be a thrown projectile instead of a melee dash
## is a design detail worth revisiting once the team feels this in-editor —
## flagged, not decided." It has now been decided, and the answer was thrown.
##
## A beach flip-flop is light and fast and goes a long way flat. throw_flick.tres
## is the fastest launch (23) on the flattest arc (5°) with reduced gravity, the
## most mid-flight steer (10.0 — it is the one slipper that genuinely curves),
## and the only profile with `forces_downed` FALSE: it is a poke, not a
## knockdown. Under Option A it still dents; under Option B it staggers and sets
## up rather than finishing.

const PROFILE: ThrowProfile = preload("res://scripts/abilities/resources/throw_flick.tres")

func get_throw_profile() -> ThrowProfile:
	return PROFILE

## Checklist 4.1 — the quick cartoon wind-whoosh. See bagsak_bomb.gd's own
## play_launch_sfx for the contract.
##
## The lightest and shortest of the three launch sounds, because this is the
## lightest and fastest of the three slippers: a band of noise sweeping hard
## upward with a whistle riding on top. The whistle is the cartoon — a filtered
## hiss alone would just be air, and this is the one profile with steer_strength
## 10.0, so a player is meant to hear the thing curving.
func play_launch_sfx(character: CharacterBase) -> void:
	AudioManager.play_at("ability_flick_dash", character.global_position)

## No-op by design — see bagsak_bomb.gd.
func _do_activate(_character: CharacterBody3D) -> bool:
	return false
