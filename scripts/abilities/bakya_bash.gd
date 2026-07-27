extends AbilityBase
class_name BakyaBash

## Bakya — Bakya Bash. The heavy one.
##
## TASK 0 CHANGED WHAT THIS IS — see bagsak_bomb.gd's header for the full
## reasoning; the same applies to all three Tsinelas specials.
##
## A wooden clog is heavy, slow and flat, and when it connects the lata goes
## down. That reads better as a thrown object than it ever did as a lunge: in
## throw_bakya.tres it is the lowest arc (8°), the heaviest gravity (1.6×), the
## least steer (2.0 — you cannot curve a wooden clog), and `forces_downed` kept
## true so a direct hit still knocks the can flat outright. The old
## `forces_downed` hitbox this script used to spawn is the same flag, now carried
## by the slipper in flight instead of by a sphere placed 2 metres ahead.
##
## Its long cooldown (18s in bakya_bash.tres) no longer gates anything, since the
## throw is gated by having to physically retrieve the slipper instead. That is a
## strictly better gate, and it is the mechanic the game is named after.

const PROFILE: ThrowProfile = preload("res://scripts/abilities/resources/throw_bakya.tres")

func get_throw_profile() -> ThrowProfile:
	return PROFILE

## No-op by design — see bagsak_bomb.gd.
func _do_activate(_character: CharacterBody3D) -> bool:
	return false
