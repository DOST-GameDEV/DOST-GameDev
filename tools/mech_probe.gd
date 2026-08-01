extends Node3D
## THE MECHANICS BENCH. **Rewritten 2026-08-01 by ⚖️ `build fair`.**
##
##     Godot_v4.7.1-stable_win64_console.exe --path <repo> tools/mech_probe.tscn
##
## ---------------------------------------------------------------------------
## ⚠️⚠️ WHAT THIS REPLACES. 355 lines written on 2026-07-31 for `build mech`,
## measuring `can_out_left()`, the punt's `_rpc_set_loose`, the bump meter and a
## 2v2 round — every one of which the HARRYDAKS pivot deleted the next day. §2.10
## files every probe in `tools/` root as stale; this is the second one to earn a
## rewrite rather than a deletion, because four open items on the board are all
## "this number has never been measured" and they are all measurable on one bench.
##
## §2.4 the shove · §2.5 stamina · §2.6 the tag against a MOVING target ·
## §2.7 what a tag actually costs · §2.16 the preview lands where the slipper lands.
##
## ⚠️ IT MEASURES, IT DOES NOT JUDGE. Only §2.16 has a pass/fail gate, because only
## §2.16 is a claim about two things AGREEING. The rest print numbers a human reads
## against `Design.md`; a probe that failed a run for "2.5 m of knockback feels
## wrong" would be encoding this session's taste as a gate.
##
## ⚠️ EVERY UNIT IS PUPPETED, and that is the only way these numbers mean anything.
## A live bot walking through a measurement is indistinguishable from the mechanic
## under test (§6 trap 14 — `move_and_slide()` writes the RESOLVED velocity back, so
## "pushed 2.5 m" and "walked 2.5 m" read identically; `trait_probe` reported a bot's
## walk speed as a body block to four decimal places before it was parked). The
## `Puppet` brain below extends `AIController` and presses exactly what this file
## tells it to, through the same `ai_set_intent()` harness a human's keyboard feeds.
## `ai_controller.gd` is 🤖 `build ai`'s file and is not edited.
##
## ⚠️ TRAITS ARE PINNED TO NEUTRAL FOR EVERY MEASUREMENT. `character_index` is set
## to a POWER-3 / GRIT-3 entry on both sides of every impulse, so what comes back is
## the CONSTANT rather than the constant times somebody's roster pick. §2.8 made all
## nine stats live, which means an unpinned bench would silently report a different
## number depending on which Person a bot happened to be dealt.
##
## ⚠️ RUN IT WITH THE PLAIN EXE OR THE CONSOLE ONE, NEVER `--headless`.

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

## Every action the bench ever presses.
const ACTIONS: Array[String] = ["move_left", "move_right", "move_up", "move_down",
	"sprint", "grab", "lunge", "special_ability"]

## How close two landing points have to be for §2.16 to call the preview honest.
## The slipper's own contact radius is 0.23 and the lata's window is 0.53, so a
## preview inside this cannot mislead an aim into missing.
const AIM_TOLERANCE: float = 0.25

var _main: Node = null
var _lines: Array[String] = []
var _failures: Array[String] = []
var _puppets: Dictionary = {}
var _done: bool = false

## A unit that presses exactly what it is told and decides nothing.
##
## ⚠️ THE PRESSES ARE APPLIED FROM `decide()`, NOT WRITTEN DIRECTLY BY THE BENCH.
## `CharacterBase._physics_process()` calls `decide()` and then reads the intent
## dictionary in the same frame, so a bench writing intents from its own
## `_physics_process` would be racing node order. Going through `decide()` makes the
## press land on the frame it was asked for, every time.
class Puppet extends AIController:
	var press: Dictionary = {}

	func decide(_delta: float) -> void:
		if character == null or not is_instance_valid(character):
			return
		for action in ACTIONS:
			_press(action, bool(press.get(action, false)))

func _ready() -> void:
	GameLaunch.spectator = true
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()

## ⚠️⚠️ THE BENCH OUTLASTS A ROUND, AND THE FIRST TWO RUNS DID NOT KNOW IT.
## The tag scan alone is 38 trials, each costing a 0.5 s charge, a dash, and up to
## `TAG_STUN_TIME` waiting for the victim to recover — well over **200 s of game
## time against a 90 s round**. So the round quietly ended partway through, and
## every rule downstream of `can_act()` (which is `round_active and state ==
## NORMAL`) started refusing: the crossing-target scan reported **0.00 m**, which
## reads exactly like the tunnelling failure §2.6 was written to look for, and
## §2.16's grab was refused so the slipper never left the origin.
##
## **A harness that runs out of clock reports the bug it was hunting.** The clock is
## held open here rather than the bench being shortened, because shortening it would
## trade the measurement's resolution for the harness's convenience.
func _physics_process(_delta: float) -> void:
	if _done:
		return
	_hold_puppets()
	if RoundManager.round_active and RoundManager.time_left < 30.0:
		RoundManager.time_left = RoundManagerScript.ROUND_TIME

func _log(text: String) -> void:
	_lines.append(text)

## ---------------------------------------------------------------------------
## PUPPET PLUMBING.
## ---------------------------------------------------------------------------

## Takes a unit off its own controller and onto the bench's.
func _puppet(who: CharacterBase) -> Puppet:
	if _puppets.has(who.player_slot) and is_instance_valid(_puppets[who.player_slot]):
		var existing: Puppet = _puppets[who.player_slot]
		who.ai_controller = existing
		return existing
	var original := who.ai_controller
	if original != null:
		original.set_enabled(false)
	var brain := Puppet.new()
	brain.name = "MechProbePuppet"
	who.add_child(brain)
	who.ai_controller = brain
	who.ai_clear_intent()
	_puppets[who.player_slot] = brain
	return brain

## ⚠️ RE-ASSERTED EVERY FRAME the bench is running, because
## `main.gd::_reassert_spectated_bots()` re-enables `character.ai_controller` on a
## schedule of its own — the same race `fair_probe.gd::_apply_policy()` documents.
## Here it is harmless (it would re-enable the PUPPET, which is already enabled) but
## only because the puppet IS `ai_controller`; letting the shipping brain back on
## would put a decision inside a measurement.
func _hold_puppets() -> void:
	for slot in _puppets.keys():
		var brain = _puppets[slot]
		if not is_instance_valid(brain):
			continue
		var who := RoundManager.player_at(int(slot))
		if who != null and who.ai_controller != brain:
			who.ai_controller = brain

## Pins a unit to a neutral roster row so no trait scales the measurement.
## ATE GIRLIE is 4/3/3 — POWER and GRIT both neutral, which covers every stat any
## impulse on this bench touches.
func _neutralise(who: CharacterBase) -> void:
	who.character_index = CharacterRoster.index_of(&"ate_girlie")

func _place(who: CharacterBase, where: Vector3) -> void:
	who.global_position = where
	who.velocity = Vector3.ZERO

## ⚠️⚠️ CLEARS THE BENCH, AND THE FIRST RUN NEEDED ALL THREE HALVES OF IT.
## Without this the measurements silently measured furniture:
##   · the sprint test reported **0.99 m of a predicted 6.5** because the sprinter
##     ran straight into the body the shove test had just left in front of it;
##   · the shove reported **0.00 m** because a slipper was inside `PICKUP_RADIUS`
##     and `carrier.gd::_step_grab()` gets FIRST REFUSAL on an E press — the tap was
##     spent picking something up, which is the contextual-E rule working correctly
##     and ruining the measurement;
##   · §2.16 reported the slipper never leaving the origin, because the thrower's
##     hand was still full from the tag test and `can_be_grabbed_by()` refuses a
##     carrier who is already holding one.
## None of the three looked like a harness fault in the output. They looked like
## broken game numbers, which is exactly how a bench lies.
func _clear_bench(keep: CharacterBase) -> void:
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null:
			continue
		slipper.host_reset_for_new_round()
		slipper.global_position = Vector3(-20.0, 0.2, -20.0)
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		who.notify_holding(null)
		if who == keep:
			continue
		# Parked in a far corner of the safe zone, well outside anything measured.
		_place(who, Vector3(-14.0, who.global_position.y, -14.0 + 2.0 * float(who.player_slot)))
		var brain = _puppets.get(who.player_slot, null)
		if brain != null and is_instance_valid(brain):
			_release(brain)

func _release(brain: Puppet) -> void:
	brain.press.clear()

## Walks a unit toward a point for `frames`, which is also how it is AIMED.
## ⚠️ §6 trap 13: `look_at()` only runs on a frame the body actually moves, and both
## the shove and the lunge fire along `-basis.z`. A unit that is placed and then told
## to act fires at whatever heading it last walked in.
func _face_by_walking(who: CharacterBase, brain: Puppet, toward: Vector3,
		frames: int) -> void:
	for _i in range(frames):
		_hold_puppets()
		var delta := toward - who.global_position
		delta.y = 0.0
		if delta.length() > 0.001:
			var flat := delta.normalized()
			brain.press["move_right"] = flat.x > 0.3827
			brain.press["move_left"] = flat.x < -0.3827
			brain.press["move_down"] = flat.z > 0.3827
			brain.press["move_up"] = flat.z < -0.3827
		await get_tree().physics_frame

func _tap(brain: Puppet, action: String) -> void:
	# A real press EDGE: `input_just_pressed` needs a false frame before the true one.
	brain.press[action] = false
	await get_tree().physics_frame
	brain.press[action] = true
	await get_tree().physics_frame
	brain.press[action] = false
	await get_tree().physics_frame

func _wait_for_round() -> bool:
	for _i in range(3000):
		await get_tree().physics_frame
		if RoundManager.round_active and RoundManager.lata != null:
			for _j in range(10):
				await get_tree().physics_frame
			return true
	return false

func _step() -> float:
	return 1.0 / float(maxi(1, Engine.physics_ticks_per_second))

## ---------------------------------------------------------------------------
func _run() -> void:
	if not await _wait_for_round():
		_failures.append("HARNESS: the match never reached a live round.")
		_report()
		return
	var taya := RoundManager.defender()
	var attackers: Array[CharacterBase] = []
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who != null and not who.is_defender:
			attackers.append(who)
	if taya == null or attackers.size() < 2:
		_failures.append("HARNESS: need a taya and two attackers.")
		_report()
		return
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who != null:
			_puppet(who)
			_neutralise(who)
	await get_tree().physics_frame

	await _measure_shove(attackers[0], attackers[1])
	await _measure_stamina(attackers[0])
	await _measure_tag(taya, attackers[0])
	await _measure_aim(attackers[0])
	_report()

## ---------------------------------------------------------------------------
## §2.4 · THE SHOVE. `Design.md` §5.3 predicts 2.50 m by v²/60 and a 1.25 s stun.
## ---------------------------------------------------------------------------
func _measure_shove(shover: CharacterBase, victim: CharacterBase) -> void:
	_log("")
	_log("--- §2.4  the shove  (Design.md §5.3: 2.50 m, 1.25 s stun, 25 of 50 stamina) ---")
	var shover_brain: Puppet = _puppets[shover.player_slot]
	var victim_brain: Puppet = _puppets[victim.player_slot]
	_release(shover_brain)
	_release(victim_brain)

	# Out in the safe zone, well clear of the box, the lata and anybody else.
	_clear_bench(shover)
	var base := Vector3(0.0, victim.global_position.y, 10.0)
	_place(shover, base)
	_place(victim, base + Vector3(0.0, 0.0, -1.0))
	await get_tree().physics_frame
	# Walk INTO the victim so the facing is real (§6 trap 13).
	await _face_by_walking(shover, shover_brain, victim.global_position, 16)
	_release(shover_brain)
	await get_tree().physics_frame

	var stamina_before := shover.get_stamina_ratio() * CharacterBase.STAMINA_MAX
	var from := victim.global_position
	# ⚠️ THE SETUP IS REPORTED, NOT ASSUMED. A shove that does not fire looks
	# identical in the output to a shove that fires and does nothing, and this
	# bench has already been fooled once by that shape (§6 trap 14). Every gate
	# `host_resolve_shove()` applies is printed, so a 0.00 m result says WHY.
	var to_them := victim.global_position - shover.global_position
	to_them.y = 0.0
	var facing := -shover.global_transform.basis.z
	facing.y = 0.0
	var arc := rad_to_deg(facing.normalized().angle_to(to_them.normalized())) \
		if to_them.length() > 0.01 and facing.length() > 0.01 else 999.0
	_log("setup: gap %.2f m (range %.2f)  arc %.1f deg (limit %.1f)  stamina %.1f  cd %.2f  victim %s"
		% [to_them.length(), CharacterBase.SHOVE_RANGE, arc, CharacterBase.SHOVE_ARC_DEG,
			stamina_before, shover.shove_cooldown_left(),
			("NORMAL" if victim.state == CharacterBase.State.NORMAL else "STUNNED")])
	await _tap(shover_brain, "grab")

	var stunned_for := 0.0
	var settled := 0
	for _i in range(900):
		_hold_puppets()
		await get_tree().physics_frame
		if victim.state != CharacterBase.State.NORMAL:
			stunned_for += _step()
		var speed := Vector2(victim.velocity.x, victim.velocity.z).length()
		if speed < 0.05:
			settled += 1
			if settled > 6:
				break
		else:
			settled = 0
	var travelled := Vector2(victim.global_position.x - from.x,
		victim.global_position.z - from.z).length()
	var spent := stamina_before - shover.get_stamina_ratio() * CharacterBase.STAMINA_MAX

	_log("knockback      %.2f m        (predicted %.2f, from v %.3f by v²/FRICTION_2)"
		% [travelled, CharacterBase.SHOVE_SPEED * CharacterBase.SHOVE_SPEED / 60.0,
			CharacterBase.SHOVE_SPEED])
	_log("stun           %.2f s        (const %.2f)" % [stunned_for, CharacterBase.SHOVE_STUN])
	_log("stamina spent  %.1f of %.1f   (const %.1f) -> %d shoves per full bar"
		% [spent, CharacterBase.STAMINA_MAX, CharacterBase.SHOVE_STAMINA_COST,
			int(CharacterBase.STAMINA_MAX / maxf(CharacterBase.SHOVE_STAMINA_COST, 0.01))])
	_log("cooldown       %.2f s        -> at most %.1f shoves in a 90 s round"
		% [CharacterBase.SHOVE_COOLDOWN, 90.0 / CharacterBase.SHOVE_COOLDOWN])
	# ⚠️ THE NUMBER THAT ACTUALLY DECIDES WHETHER THE SHOVE IS WORTH PRESSING. It
	# costs half the stamina bar, and that bar is also the sprint that gets you out
	# of the box — so the real price is not 25 points, it is the escape.
	_log("⚠️ the real price is the SPRINT: %.1f of the bar is %.2f s of sprint (%.2f m)"
		% [CharacterBase.SHOVE_STAMINA_COST,
			CharacterBase.SHOVE_STAMINA_COST / CharacterBase.STAMINA_DRAIN_RATE,
			CharacterBase.SHOVE_STAMINA_COST / CharacterBase.STAMINA_DRAIN_RATE
				* CharacterBase.SPEED * CharacterBase.ATTACKER_SPEED_SCALE
				* CharacterBase.SPRINT_SCALE])

## ---------------------------------------------------------------------------
## §2.5 · STAMINA. `Design.md` §3 predicts 1.25 s of sprint and a 2.0 s fatigue.
## ---------------------------------------------------------------------------
func _measure_stamina(who: CharacterBase) -> void:
	_log("")
	_log("--- §2.5  stamina  (Design.md §3: 50 pts, 40/s drain, 1.25 s sprint, 2.0 s fatigue) ---")
	var brain: Puppet = _puppets[who.player_slot]
	_release(brain)
	# ⚠️ EVERY OTHER BODY OUT OF THE LANE FIRST. `move_and_slide()` writes the
	# resolved velocity back, so a sprint into somebody's chest measures as a slow
	# walk and nothing in the output says why (§6 trap 14).
	_clear_bench(who)
	_place(who, Vector3(0.0, who.global_position.y, 12.0))
	who.reset_for_new_round()
	await get_tree().physics_frame

	# ⚠️ ALONG +X, NOT FURTHER OUT IN Z. `COURT_Z` is 13.0 on both maps and the
	# sprinter starts at z 12, so a 6.5 m run in Z would leave the paving and meet
	# `kill_plane.gd` — measuring the map edge instead of the stamina bar.
	brain.press["move_right"] = true
	brain.press["sprint"] = true
	var sprint_time := 0.0
	var from := who.global_position
	for _i in range(1800):
		_hold_puppets()
		await get_tree().physics_frame
		if who.is_fatigued():
			break
		sprint_time += _step()
	var sprint_distance := Vector2(who.global_position.x - from.x,
		who.global_position.z - from.z).length()
	_release(brain)

	var fatigue_time := 0.0
	for _i in range(1800):
		_hold_puppets()
		await get_tree().physics_frame
		if not who.is_fatigued():
			break
		fatigue_time += _step()

	var refill := 0.0
	for _i in range(3600):
		_hold_puppets()
		await get_tree().physics_frame
		if who.get_stamina_ratio() >= 0.995:
			break
		refill += _step()

	_log("sprint to empty     %.2f s   (%.2f m covered)" % [sprint_time, sprint_distance])
	_log("fatigue lockout     %.2f s   (const %.2f, regen locked throughout)"
		% [fatigue_time, CharacterBase.FATIGUE_TIME])
	_log("empty -> full again %.2f s   (%.1f s delay + %.1f s refill)"
		% [refill, CharacterBase.STAMINA_REGEN_DELAY,
			CharacterBase.STAMINA_MAX / CharacterBase.STAMINA_REGEN_RATE])
	# ⚠️⚠️ THE FINDING. One sprint against the box half-width is the retrieval run
	# the whole game is about (`Design.md` §0).
	_log("⚠️ one full sprint covers %.2f m against a box half-width of %.2f m (%.0f%%)"
		% [sprint_distance, CharacterBase.confinement_radius,
			100.0 * sprint_distance / maxf(CharacterBase.confinement_radius, 0.01)])

## ---------------------------------------------------------------------------
## §2.6 / §2.7 · THE TAG, INCLUDING AGAINST A MOVING TARGET.
##
## ⚠️ THE MOVING CASE IS THE WHOLE POINT AND IT HAD NEVER BEEN RUN. §2.6:
## *"`LUNGE_TAG_RADIUS` was never measured against a moving target."* The worry is
## specific — the dash covers 2.5 m and the sweep is tested once per physics frame,
## so a body crossing the path can in principle be stepped over between two frames.
## ---------------------------------------------------------------------------
func _measure_tag(taya: CharacterBase, victim: CharacterBase) -> void:
	_log("")
	_log("--- §2.6  the tag  (LUNGE_TAG_RADIUS %.2f m, swept every frame the dash is live) ---"
		% CharacterBase.LUNGE_TAG_RADIUS)
	# Everybody else off the court; `_tag_lands()` re-places the victim itself.
	_clear_bench(taya)
	await get_tree().physics_frame
	var still_reach := await _tag_reach(taya, victim, false)
	var moving_reach := await _tag_reach(taya, victim, true)
	_log("furthest start that still tags, target STILL     %.2f m" % still_reach)
	_log("furthest start that still tags, target CROSSING  %.2f m   (at %.2f m/s)"
		% [moving_reach, CharacterBase.SPEED * CharacterBase.ATTACKER_SPEED_SCALE])
	if still_reach > 0.0 and moving_reach > 0.0:
		_log("⚠️ the sweep loses %.2f m (%.0f%%) against a crossing body — a lead problem, not a tunnel."
			% [still_reach - moving_reach,
				100.0 * (still_reach - moving_reach) / maxf(still_reach, 0.01)])
	elif moving_reach <= 0.0:
		_log("⚠️⚠️ NO RANGE TAGS A CROSSING TARGET — that is the tunnelling failure §2.6 feared.")

	_log("")
	_log("--- §2.7  what a tag costs  (TAG_STUN_TIME %.1f s of a %.0f s round) ---"
		% [RoundManagerScript.TAG_STUN_TIME, RoundManagerScript.ROUND_TIME])
	_log("stun alone            %.1f s = %.1f%% of a round"
		% [RoundManagerScript.TAG_STUN_TIME,
			100.0 * RoundManagerScript.TAG_STUN_TIME / RoundManagerScript.ROUND_TIME])
	# The slipper comes home with them (`Design.md` §6), so the recovery is the stun
	# plus one charge — not the whole retrieval trip the old rule cost.
	var to_throw := RoundManagerScript.TAG_STUN_TIME + Carrier.CHARGE_FULL_TIME
	_log("stun + a full charge  %.1f s = %.1f%%   (the slipper returns with them, §6)"
		% [to_throw, 100.0 * to_throw / RoundManagerScript.ROUND_TIME])
	_log("⚠️ the taya gets +100; the attacker loses ~%.0f%% of one round's throwing."
		% [100.0 * to_throw / RoundManagerScript.ROUND_TIME])

## Walks the taya in from increasing distance and reports the furthest start that
## still lands a tag.
## ⚠️ THE SCAN RUNS TO 4.2 m, WELL PAST `LUNGE_TAG_RADIUS`, AND IT HAS TO. The first
## run capped at 2.2 and reported exactly 2.2 for the stationary case — a scan that
## returns its own upper bound has not found an edge, it has run out of room. The
## reach is the DASH plus the radius, not the radius: 2.5 m of travel against a
## 1.3 m sweep, so anything under ~3.8 m is inside the envelope in principle.
func _tag_reach(taya: CharacterBase, victim: CharacterBase, crossing: bool) -> float:
	var best := 0.0
	for step_index in range(19):
		var distance := 0.6 + 0.2 * float(step_index)
		if await _tag_lands(taya, victim, distance, crossing):
			best = distance
	return best

func _tag_lands(taya: CharacterBase, victim: CharacterBase, distance: float,
		crossing: bool) -> bool:
	var taya_brain: Puppet = _puppets[taya.player_slot]
	var victim_brain: Puppet = _puppets[victim.player_slot]
	_release(taya_brain)
	_release(victim_brain)
	var lata := RoundManager.lata
	if lata == null:
		return false
	lata.host_reset_for_new_round() # a tag requires the can upright

	# Both inside the box, on the +Z line, so the taya's confinement never bites.
	var origin := Vector3(0.0, taya.global_position.y, 0.0)
	_place(taya, origin + Vector3(0.0, 0.0, 2.5))
	_place(victim, origin + Vector3(0.0, 0.0, 2.5 - distance))
	# ⚠️ THE VICTIM HAS TO BE TAGGABLE OR NOTHING CAN LAND: `is_taggable()` needs a
	# slipper in hand and a body inside the box. Handing it one is not a cheat — it
	# is the only state the rule applies to at all.
	var slipper := _slipper_for(victim)
	if slipper != null:
		slipper.host_reset_for_new_round()
		slipper.host_assign_owner(victim.player_slot)
		slipper.global_position = victim.global_position
		await get_tree().physics_frame
		slipper.host_grab(victim)
	await get_tree().physics_frame
	if not victim.is_taggable():
		return false

	var hits := [false]
	var seen := func(_defender_slot: int, victim_slot: int) -> void:
		if victim_slot == victim.player_slot:
			hits[0] = true
	RoundManager.attacker_tagged.connect(seen)

	# Charge while walking in, so the body is aimed (§6 trap 13), then release.
	taya_brain.press["lunge"] = true
	await _face_by_walking(taya, taya_brain, victim.global_position,
		int(ceil(CharacterBase.LUNGE_CHARGE_TIME / _step())) + 6)
	if crossing:
		# Perpendicular to the dash, at the attacker's own walk speed.
		victim_brain.press["move_right"] = true
	taya_brain.press["lunge"] = false
	for _i in range(int(ceil(CharacterBase.LUNGE_ACTIVE_TIME / _step())) + 30):
		_hold_puppets()
		await get_tree().physics_frame
		if bool(hits[0]):
			break
	RoundManager.attacker_tagged.disconnect(seen)
	_release(taya_brain)
	_release(victim_brain)
	# Clean state for the next trial: the tag penalty teleported and stunned them.
	victim.global_position = victim.spawn_position
	victim.velocity = Vector3.ZERO
	for _i in range(int(ceil(RoundManagerScript.TAG_STUN_TIME / _step())) + 10):
		await get_tree().physics_frame
		if victim.state == CharacterBase.State.NORMAL:
			break
	return bool(hits[0])

func _slipper_for(who: CharacterBase) -> Slipper:
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper != null and slipper.owner_slot == who.player_slot:
			return slipper
	for node in get_tree().get_nodes_in_group("slippers"):
		return node as Slipper
	return null

## ---------------------------------------------------------------------------
## §2.16 · THE PREVIEW LANDS WHERE THE SLIPPER LANDS.
##
## ⚠️⚠️ THIS IS THE ONE GATED CHECK, AND IT IS GATED BECAUSE THIS LANE PUT IT AT
## RISK. §2.8 made `LAUNCH_SPEED` per-skin, and the aim arc and the flight only ever
## agreed because BOTH come out of `Slipper.launch_velocity_for()` (`Design.md` §12).
## Scaling one and not the other would have re-opened §2.16 silently — the dotted
## line would land where a NEUTRAL slipper lands and the real one 5% away, which is
## precisely the class of bug that shared function exists to make impossible.
##
## Every slipper skin is tested, because the per-skin scale is exactly what could
## break it.
## ---------------------------------------------------------------------------
func _measure_aim(who: CharacterBase) -> void:
	_log("")
	_log("--- §2.16  the dotted arc vs the flight  (tolerance %.2f m) ---" % AIM_TOLERANCE)
	var slipper := _slipper_for(who)
	if slipper == null:
		_failures.append("HARNESS: no slipper to aim with.")
		return
	var brain: Puppet = _puppets[who.player_slot]
	_release(brain)
	# Clear the court so no capsule intercepts a test throw, and empty the thrower's
	# hand so the grab below can actually take — the same two lessons `trait_probe`
	# learned the hard way.
	_clear_bench(who)
	await get_tree().physics_frame

	for index in range(CharacterRoster.SLIPPERS.size()):
		var entry: Dictionary = CharacterRoster.SLIPPERS[index]
		# ⚠️⚠️ AIMED 4 m TO THE SIDE OF THE LATA, AND THE RUN THAT AIMED AT IT WAS
		# MEASURING THE RECOIL. Throwing at the can means the first shot KNOCKS IT
		# DOWN and bounces off it (`LATA_RECOIL_SCALE`), so the slipper lands
		# somewhere the preview never claimed — TSINELAS came back 1.43 m out. The
		# next two shots then flew clean, because a downed can is not tested at all,
		# and read as OK. **A test whose result depends on the order it ran in.**
		# §2.16 is about the ARC, so the arc gets an empty patch of road.
		var lane_x := 4.0
		var origin := Vector3(lane_x, 1.4, 9.0)
		var target := Vector3(lane_x, 0.15, 0.0)
		_place(who, Vector3(lane_x, who.global_position.y, 9.6))
		slipper.host_reset_for_new_round()
		slipper.apply_skin(index)
		slipper.host_assign_owner(who.player_slot)
		slipper.global_position = origin
		await get_tree().physics_frame
		slipper.host_grab(who)
		await get_tree().physics_frame
		var velocity := Slipper.launch_velocity_for(origin, target, 1.0, slipper.speed_scale())
		var predicted := _integrate_like_preview(origin, velocity)
		slipper.host_throw(who, origin, target, 1.0)
		for _i in range(1200):
			await get_tree().physics_frame
			if not slipper.is_flying():
				break
		var observed := slipper.global_position
		var miss := Vector2(observed.x - predicted.x, observed.z - predicted.z).length()
		var ok := miss <= AIM_TOLERANCE
		_log("%-9s speed x%.2f  predicted z %6.2f  observed z %6.2f  miss %.3f m  %s"
			% [String(entry.get("name", "?")), slipper.speed_scale(),
				predicted.z, observed.z, miss, "OK" if ok else "FAIL"])
		if not ok:
			_failures.append(("§2.16 %s: the preview predicts z %.2f and the slipper lands "
				+ "z %.2f — %.3f m apart, over the %.2f m tolerance.")
				% [String(entry.get("name", "?")), predicted.z, observed.z, miss,
					AIM_TOLERANCE])

## Mirrors `TrajectoryPreview.draw_arc()`'s integration: semi-implicit Euler at the
## physics step, stopped at the floor.
##
## ⚠️ IT IS A MIRROR AND THIS COMMENT SAYS SO. What actually guarantees the two agree
## is the SHARED INPUT — the arc and the throw both come from
## `Slipper.launch_velocity_for()`. Walking the same scheme forward here lets a
## failure be reported as a distance in metres rather than as two unequal vectors,
## which is the difference between a readable result and a red light.
func _integrate_like_preview(origin: Vector3, velocity: Vector3) -> Vector3:
	var step := _step()
	var position := origin
	var motion := velocity
	var floor_y: float = 0.1
	if RoundManager.lata != null:
		floor_y = RoundManager.lata.global_position.y
	for _i in range(int(ceil(TrajectoryPreview.HORIZON / step))):
		motion.y -= CharacterBase.GRAVITY * step
		position += motion * step
		if position.y <= floor_y + Slipper.REST_HEIGHT:
			break
	return position

## ---------------------------------------------------------------------------
func _report() -> void:
	if _done:
		return
	_done = true
	print("")
	print("================ MECH PROBE — the numbers nobody had measured ================")
	for line in _lines:
		print(line)
	print("")
	if _failures.is_empty():
		print("RESULT: PASS")
		get_tree().quit(0)
		return
	print("RESULT: FAIL — %d check(s)" % _failures.size())
	for line in _failures:
		print("  * " + line)
	get_tree().quit(1)
