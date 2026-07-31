extends RefCounted
class_name PropSmash

## CAN-SMASH and GROUND SMASH — the two shockwave verbs the 2026-07-30 overhaul gave the
## objects. `Design.md` §5.3 and §6.
##
## ⚠️ THESE ARE ROLE ABILITIES AND THEY LIVE HERE RATHER THAN IN AN `AbilityBase`.
## Every lata has the smash and every tsinelas has the dive, exactly as every body has a
## jump. The `ability` slot is the SKIN's kit (Quick Stand, Bakya Bash, …) and is picked
## on the CHARACTER screen; hanging a role verb off it would mean a player who picked
## LATA NG KAPE for its speed silently lost the smash, and six skins would each carry
## three near-identical overrides of the same code.
##
## Static functions on a RefCounted, the same shape `AbilityUtils` already uses, because
## there is no per-instance state to hold: the cooldown and the dive flag are
## per-CHARACTER and live on `character_base.gd` where the per-frame tick already is.
##
## ⚠️ EVERY HIT GOES THROUGH `AbilityUtils.spawn_pulse_hitbox`. That is not tidiness —
## it is the only way a shockwave resolves on the HOST, respects the same-team check
## (B-09), obeys the once-per-offensive-event memory, and joins the `transient_hitbox`
## group so a round ending mid-pulse cannot leak it into the next round. A hand-rolled
## Area3D would look perfect in Single Player and do nothing over a network, because
## `hitbox.gd` refuses to resolve anything on a peer that is not the host.

## ---------------------------------------------------------------------------
## CAN-SMASH — the lata slams the ground.
##
## ⚠️ IT HAS A WIND-UP, AND THE WIND-UP IS THE ENTIRE REASON IT IS FAIR. A 3.6 m
## shockwave centred on the object the attacker MUST approach is, without a telegraph,
## a rule that says "do not come near the can" — which is the opposite of the game. 0.35
## s is a quarter longer than `TAG_WINDUP` ever was (0.14) and long enough for a
## `DASH_DURATION` 0.15 dash or a jump to clear it, and `broadcast_visual_action` puts
## the slam pose on every peer so there is something to react TO.
##
## Radius 3.6 is derived, not picked: the taya's standoff post is 2.6 m from the can
## (`AIController.taya_block_standoff`) and the confinement square's edge is 5.0, so 3.6
## covers the whole approach lane a thrower has to walk to get point-blank and stops
## well short of reaching a thrower standing on the 6.0 line. **The can cannot hit
## anybody who kept their distance.**
const CAN_SMASH_WINDUP: float = 0.35
const CAN_SMASH_RADIUS: float = 3.6
const CAN_SMASH_PULSE_TIME: float = 0.18
const CAN_SMASH_STUN: float = 1.6
## ⚠️ RESOLVED 2026-07-31 by `build abil`, § SALVAGE's flagged conflict: the brief said
## 3.0 s, the salvaged code shipped 8.0 s. **3.0 s wins.** Can-Smash does not force a
## knockdown and cannot itself win a round — it is the lata's ONLY upstream answer to an
## approaching attacker (§1.14/§3.10: its kit has to matter before it is displaced, and
## there is nothing after). At 8.0 s a 90 s round sees it roughly ten times and an
## attacker who eats one smash was never threatened by a second inside the same
## approach; at 3.0 s cooldown plus the 0.35 s windup it is live again every 3.35 s, one
## real area-denial cycle per approach rather than a once-per-round panic button. The
## 0.35 s telegraph is unchanged and is still the whole reason this is fair (§3.1's own
## header): a `DASH_DURATION` 0.15 dash or a jump clears it every single time it fires,
## at 3.0 s same as at 8.0. Nothing about the counterplay gets harder — only the number
## of times the lata gets to try. `Design.md` §5.3 and §11 updated in the same commit.
const CAN_SMASH_COOLDOWN: float = 3.0

## ---------------------------------------------------------------------------
## GROUND SMASH — the tsinelas dives.
##
## The payoff at the end of the self-launch (`Carriable.jump_charge_step`): charge the
## jump, clear the taya, dive on the lata. A DIRECT hit wins the round outright, which
## is the single most powerful thing any object can do in this game and is bounded on
## four sides at once —
##
##   1. it needs height, so it needs a charged launch or a jump, both of which are
##      visible commitments on the ground first;
##   2. `DIRECT_HIT_RADIUS` 0.75 is barely wider than the lata's own hurtbox (0.17) plus
##      the slipper's (0.307) — it is a hit, not a proximity check;
##   3. the lata's counterplay is Can-Dash, one use per round, 2.88 m of travel against
##      a diver who committed to a point in the air and cannot steer;
##   4. `GROUND_SMASH_COOLDOWN` 12.0 is the longest in the game, so a missed dive is
##      most of a round's worth of the slipper's best verb.
const GROUND_SMASH_MIN_HEIGHT: float = 0.6
const GROUND_SMASH_DIVE_SPEED: float = 22.0
const GROUND_SMASH_RADIUS: float = 3.2
const GROUND_SMASH_PULSE_TIME: float = 0.16
const GROUND_SMASH_STUN: float = 1.4
const GROUND_SMASH_COOLDOWN: float = 12.0
const DIRECT_HIT_RADIUS: float = 0.75

## ---------------------------------------------------------------------------

static func begin_can_smash(character: CharacterBase) -> void:
	if character == null or not is_instance_valid(character):
		return
	character.broadcast_visual_action("bump")
	AudioManager.play_at("ability_bakya_bash", character.global_position)
	# ⚠️ CAPTURE THE INSTANCE ID, NOT THE NODE, and re-check validity in the callback —
	# the rule `ability_utils.gd` records at length for its own self-free timer and
	# `person_action.gd` followed for the tag wind-up. A lambda holding the node keeps a
	# freed character alive and the `is_instance_valid` guard inside never runs. A round
	# can end, and a character can leave the match, inside 0.35 s.
	var id := character.get_instance_id()
	character.get_tree().create_timer(CAN_SMASH_WINDUP).timeout.connect(func() -> void:
		var who := instance_from_id(id) as CharacterBase
		if who == null or not is_instance_valid(who):
			return
		# ⚠️ A SMASH INTERRUPTED IS A SMASH THAT MISSED. Being bumped or knocked over
		# during your own wind-up must cancel it — that window is exactly what the
		# attacker is meant to be able to punish, and honouring it is the difference
		# between a commitment and a delay. Same rule the deleted tag finally learned.
		if who.state != CharacterBase.State.NORMAL:
			return
		AudioManager.play_at("lata_impact", who.global_position)
		# `forces_downed` false: the smash STUNS, it does not knock down. A lata that
		# could floor the attacker would simply be the tag again with a bigger radius.
		AbilityUtils.spawn_pulse_hitbox(who, CAN_SMASH_RADIUS, CAN_SMASH_PULSE_TIME,
			false, Vector3.ZERO, true, CAN_SMASH_STUN))

## ---------------------------------------------------------------------------

static func begin_ground_smash(character: CharacterBase) -> void:
	if character == null or not is_instance_valid(character):
		return
	character._dive_active = true
	# Straight down, and horizontal motion is killed outright. A dive that kept its
	# forward speed would be a very fast, very flat throw the slipper aimed itself —
	# which is a different (and much stronger) move than the one being built.
	character.velocity = Vector3(0.0, -GROUND_SMASH_DIVE_SPEED, 0.0)
	character.broadcast_visual_action("bump")
	AudioManager.play_at("ability_bagsak_bomb", character.global_position)

## Called every physics frame while a dive is in flight, from `character_base.gd`. Ends
## the moment the body touches anything solid.
static func step_dive(character: CharacterBase, _delta: float) -> void:
	if character == null or not is_instance_valid(character):
		return
	# Held at speed rather than accelerating: a dive whose speed depended on how high it
	# started would land harder from a lucky bounce than from a charged launch, and the
	# whole point of the launch is that the height IS the commitment.
	character.velocity.y = -GROUND_SMASH_DIVE_SPEED
	if not character.is_on_floor():
		return
	character._dive_active = false
	AudioManager.play_at("lata_knockdown", character.global_position)
	AbilityUtils.spawn_pulse_hitbox(character, GROUND_SMASH_RADIUS, GROUND_SMASH_PULSE_TIME,
		false, Vector3.ZERO, true, GROUND_SMASH_STUN)
	_resolve_direct_hit(character)

## ⚠️ THE INSTANT WIN, AND IT IS HOST-ONLY BY THE SAME GATE EVERY ROUND DECISION USES.
##
## `RoundManager.report_round_win` already refuses on a non-host and already no-ops if
## the round has ended, so this is safe to call unconditionally — but the SEARCH is
## gated too, so four peers do not each walk the tracked-can list on the same frame to
## reach the same conclusion three of them may not act on.
##
## Measured against the tracked cans rather than by an Area3D overlap, deliberately: the
## shockwave hitbox above is 3.2 m and this is 0.75 m, and expressing "direct hit" as a
## second, smaller Area3D would make the round-winning condition depend on the order two
## overlaps happened to be delivered in.
##
## ⚠️ RESOLVED 2026-07-31 by `build abil`, filed by `build mech` as §3.9: a stranded or
## downed lata cannot dodge, cannot Can-Dash and cannot Can-Smash (§1.9/§5.1.1 — it has no
## verb at all while down), so treating it as a live instant-win target turned bound #2
## ("a hit, not a proximity check") into no bound at all — walk over a body that is
## already losing and tap it in. `can.state == NORMAL` restores the fourth thing this
## move was supposed to require: the lata has to still be UP, actively holding its
## ground, for a direct hit to be the one that ends the round outright. A lata that is
## already down is already being timed out by §5.2's countdown — that is its own,
## separate loss condition, and it needs no second one stacked on top for free. This
## costs the diver nothing they were relying on: §6's whole loop is charge past the
## taya and land ON a can that is still fighting, not corpse-kick one a teammate's bump
## already finished.
static func _resolve_direct_hit(character: CharacterBase) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if not RoundManager.round_active:
		return
	for can in RoundManager.get_tracked_cans():
		if can == null or not is_instance_valid(can):
			continue
		if can.team == character.team:
			continue # your own team's lata is not a win condition (B-09's rule)
		if can.state != CharacterBase.State.NORMAL:
			continue # §3.9: already down is already losing to §5.2, not to this
		if character.global_position.distance_to(can.global_position) > DIRECT_HIT_RADIUS:
			continue
		AudioManager.play_at("match_win", can.global_position)
		RoundManager.report_round_win(false) # the Tsinelas side wins the round
		return
