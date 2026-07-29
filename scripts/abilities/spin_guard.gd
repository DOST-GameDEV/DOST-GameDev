extends AbilityBase
class_name SpinGuard

## Bilao — Spin Guard: knockback pulse pushes attackers away (see
## docs/Dev_Plan.md, Roster: 🥫 Can Class). An AoE stagger pulse centered
## on the character, using AbilityUtils' spawned-hitbox helper. First-pass / untested.

@export var pulse_radius: float = 2.5
@export var pulse_duration: float = 0.2

func _do_activate(character: CharacterBody3D) -> bool:
	AbilityUtils.spawn_pulse_hitbox(character as CharacterBase, pulse_radius, pulse_duration)
	# Checklist 4.1 — the whirring deflection. Unlike the three Tsinelas
	# abilities (whose sound rides the throw, see bagsak_bomb.gd), this one has a
	# real _do_activate() and so plays straight from it, on the press.
	#
	# ⚠️ THE SOUND IS 500 ms AND THE HITBOX IS 200 ms, ON PURPOSE. The pulse is
	# an instant that has to LAND instantly; the whir is the read that tells
	# everyone nearby it happened, and cutting it to the hitbox's length would
	# leave a knockback nobody could account for. What the ability does and what
	# it announces are two different durations.
	#
	# Fires on whichever peer ran activate() — the presser locally, and the host
	# via _rpc_notify_ability_activate (see character_base.gd). On a client that
	# is both, which the retrigger guard in AudioManager collapses.
	AudioManager.play_at("ability_spin_guard", (character as CharacterBase).global_position)
	return true
