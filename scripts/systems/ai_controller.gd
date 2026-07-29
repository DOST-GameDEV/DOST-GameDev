extends Node
class_name AIController

## Checklist 5.5 — Single Player. Drives one CharacterBase's INPUT exactly the
## way a human at a keyboard would: Input.action_press()/action_release() on
## this character's own _pN action suffixes (CharacterBase.action_name()).
## character_base.gd, carrier.gd and carriable.gd are completely unmodified
## and unaware this exists — they read Input.is_action_*(_action(...)) exactly
## as before, oblivious to whether the press came from hardware or from here.
## This is deliberate: the confinement clamp, the Staggered/Downed/Sealed
## state machine and the round-active freeze all already apply correctly to
## ANY input source, so duplicating any of that here (a second physics path)
## would only create a second copy to keep in sync with the first — exactly
## the trap the brief for this item warned against.
##
## The one real consequence of that choice, worth stating rather than
## discovering by surprise later: character_base.gd calls decide() as the
## FIRST line of its own _physics_process (see the hook there) specifically
## so this node's presses land BEFORE the same frame's Input reads, not a
## frame late. Godot does not guarantee _physics_process order between a
## parent and its children, so this could not be left to rely on tree order —
## the explicit call is the only thing making "same frame" true.
##
## Attached as a plain child node of the CharacterBase it drives, added in
## code (`add_child`, never baked into CharacterBase.tscn) by main.gd's
## _attach_ai() — called from _start_local_test() for Single Player's three
## unpiloted units, and, since networked AI takeover, from
## _build_networked_character()/_rpc_convert_to_ai() for a networked slot with
## no live human behind it (an unfilled team/role slot, or a real peer's
## character after they disconnect). The networked call sites only ever
## attach on the HOST's own process — see _build_networked_character's doc
## for why only the host's presses do anything.
##
## ROLE IS RE-DERIVED EVERY CALL, never cached, same rule as everything else
## in this project that reads is_can/is_person/team_is_can_side
## (main.gd::_role_slot, B-76's per-round ability re-pick) — those flip every
## round and a controller that decided its job once at spawn would be playing
## the wrong one by round 2.
##
## DIFFICULTY IS OUT OF SCOPE (checklist's own words). Nothing here is tuned
## against a human, has any notion of a mistake, or reacts to a threat sooner
## than its own detection radius allows. The acceptance bar is "moves with
## intent toward its role's job and does not stand still" — not "plays well."
## If a future pass wants better play, it is a new item, not a silent
## extension of this one.

## How often each role re-picks its current goal (a wander point, a target to
## chase). Every physics frame would be both wasteful and read as twitchy
## rather than purposeful; this is a first-pass number, not tuned.
const DECISION_INTERVAL: float = 0.35
## Stop pressing a movement direction once this close to the current target —
## without a deadzone the AI oscillates across it every frame instead of
## settling, since a single frame's movement usually overshoots a zero-radius
## target entirely.
const ARRIVE_DISTANCE: float = 0.6
const TAYA_DETECT_RANGE: float = 8.0
const TAYA_MELEE_RANGE: float = 1.4
const TAYA_TAP_INTERVAL: float = 0.5
## How far out from the can the Taya plants itself when body-blocking. Far enough
## to actually intercept a throw rather than hugging the can, comfortably inside
## CONFINEMENT_RADIUS so it never presses on its own boundary.
const TAYA_BLOCK_STANDOFF: float = 2.6
## Distance from the can an Attacker tries to hold before charging — mirrors
## the map's own throwing line (Art_Direction.md §9's 6-unit derivation).
## This file does not import that constant; it just aims for the same number
## so the AI throws from roughly where a human would.
const ATTACKER_THROW_RANGE: float = 6.0
const ATTACKER_GRAB_RANGE: float = 1.5
const ATTACKER_CHARGE_TIME: float = 0.65
const ATTACKER_RETREAT_DISTANCE: float = 3.0
## How close a defender has to be to the attacker->can line to count as blocking
## it. Roughly a Person's own width plus the slipper's, so a defender genuinely
## in the way registers and one merely nearby does not.
const ATTACKER_LANE_CLEARANCE: float = 1.3
const TSINELAS_ARRIVE_DISTANCE: float = 1.0
## Physics frames to wait after releasing the charge-throw button before
## considering pressing ANY held/edge-triggered action again. Measured live,
## not a guess: `Input.is_action_just_released()` does not become visible
## until the physics frame AFTER the `Input.action_release()` call that
## caused it — `is_action_pressed()` (the level, not the edge) updates the
## same frame, but the edge itself is one frame behind it. Re-pressing on
## that very next frame (which an unthrottled "not holding -> start charging
## again" check does by default, since `carrier.held()` has not gone null
## yet) overwrites the pending release before `carrier.gd::_step_throw()`
## ever witnesses it, and the throw silently never fires — confirmed by
## adding a direct print inside carrier.gd during this item's own testing,
## not inferred from behaviour alone. `_tap()`'s own hold window exists for
## the same reason, on the press side instead of the release side.
const RELEASE_SETTLE_FRAMES: int = 6

var character: CharacterBase = null
## ⚠️ PER-INSTANCE RNG, deliberately not the global `randf()`. Every bot drawing
## from one shared global stream is a subtler version of the same "they behave
## as one" bug: the sequence is shared, so which bot gets which value depends on
## call order, and identical roles called in the same order get correlated
## picks. Seeded from the instance id in _ready().
var _rng := RandomNumberGenerator.new()
var _enabled: bool = true
var _decision_timer: float = 0.0
## World-space point the character is currently walking toward. Meaning
## differs per role (a wander point for Can/Taya, the loose slipper or the
## throwing/retreat spot for Attacker, the retrieving Person for a loose
## Tsinelas) — always re-picked from that role's own logic in _update_*(),
## never carried over from a different role's use of the same field.
var _move_target: Vector3 = Vector3.ZERO
var _has_move_target: bool = false
## Held-action state THIS controller currently believes it is pressing, so a
## repeated "still want this pressed" call never re-fires a just_pressed edge
## — see _set_held()'s own doc for why that matters for bump/bump-like taps.
var _held_actions: Dictionary = {}
## One-frame taps (bump, Tag, grab) queued for release on the NEXT decide()
## call — see _tap()'s own doc.
var _pending_release: Dictionary = {}
var _attacker_charging: bool = false
var _attacker_charge_time: float = 0.0
var _release_settle_frames: int = 0
var _taya_tap_cooldown: float = 0.0

func _ready() -> void:
	character = get_parent() as CharacterBase
	# Stagger the very first decision so four bots spawned on the same frame do
	# not all think on the same frame for the rest of the match. Seeded from the
	# instance id rather than left to a shared global RNG stream, so two
	# controllers created in the same frame cannot draw the same phase.
	_rng.seed = hash(get_instance_id())
	_decision_timer = _rng.randf_range(0.0, DECISION_INTERVAL)

## Called from character_base.gd's own _physics_process, as its first line —
## see this file's class doc for why the order matters. A no-op once
## disabled (see set_enabled) or before this node has a parent character.
func decide(delta: float) -> void:
	_flush_pending_releases()
	if not _enabled or character == null:
		return

	# Downed reacts immediately regardless of the timed decision cadence
	# below — waiting up to DECISION_INTERVAL to start self-righting would
	# read as the AI "not noticing" it fell, which is exactly the kind of
	# standing-still this item's acceptance bar rules out.
	if character.state == CharacterBase.State.DOWNED:
		_release_move()
		_set_held("bump", character.is_self_rightable())
		return
	if character.state != CharacterBase.State.NORMAL:
		# Staggered/Sealed: nothing to decide, and pressing movement here
		# would just be silently eaten by character_base.gd's own state
		# handling anyway — release so nothing is left "held" for whenever
		# NORMAL resumes.
		_release_move()
		return

	_decision_timer -= delta
	var repick := _decision_timer <= 0.0
	if repick:
		# ⚠️ JITTERED, NOT A FLAT INTERVAL — this is the other half of "they all
		# move together at the exact same time". Every controller started its
		# timer at 0.0 and decremented by the same delta, so all of them
		# re-picked on the SAME physics frame forever, in perfect lockstep. Even
		# with the shared-Input bug fixed that still reads as one hive mind
		# rather than four players. The initial phase is staggered in _ready()
		# and each interval is jittered here, so they drift apart and stay apart.
		_decision_timer = DECISION_INTERVAL * _rng.randf_range(0.75, 1.3)

	if character.is_can:
		_update_can(repick)
	elif character.is_person and character.team_is_can_side:
		_update_taya(repick, delta)
	elif character.is_person and not character.team_is_can_side:
		_update_attacker(repick, delta)
	else:
		_update_tsinelas(repick)

## Debug-switcher hand-off (Checklist 5.5 item 4): a human taking manual
## control of an AI-driven unit via F1-F4/Tab must not fight the AI for the
## same buttons. Disabling releases every action this controller might be
## mid-press or mid-charge on, so nothing sticks "held" once a human is
## driving instead — see debug_player_switcher.gd's own call site.
func set_enabled(enabled: bool) -> void:
	if _enabled == enabled:
		return
	_enabled = enabled
	if not enabled:
		_release_all()
		# Wipe the intent too, or CharacterBase keeps answering input_pressed()
		# from a stale dictionary while a human is trying to drive — the unit
		# would walk into a wall on its own. See character_base.gd::_ai_driven.
		if character != null:
			character.ai_clear_intent()

## CharacterBase asks this before deciding whether to read intent or hardware.
## A disabled controller (a human took manual control via the debug switcher)
## must hand the character straight back to the keyboard.
func is_enabled() -> bool:
	return _enabled

func _release_all() -> void:
	_release_move()
	for base in ["bump", "special_ability", "grab"]:
		_set_held(base, false)
	_pending_release.clear()
	_attacker_charging = false
	_attacker_charge_time = 0.0
	_release_settle_frames = 0

## ---------------------------------------------------------------------------
## Role behaviour. Each _update_* is given `repick` (true on this frame's
## decision tick) so target selection runs on the slow cadence while movement
## and range checks — which need to react the frame a threat enters range,
## not up to DECISION_INTERVAL late — run every call.
## ---------------------------------------------------------------------------

## ⚠️ THE CAN HOLDS ITS CIRCLE. IT DOES NOT WANDER THE BOX.
##
## This used to pick `_random_point_in_confinement(0.6)`, which walks the Can up
## to ~3 units off the base circle. Two things were wrong with that, and the
## second is what got reported:
##
##  1. **It is not the sport.** Tumbang preso is played around a can STANDING on
##     its mark. The whole defending job is to keep it there; a can that strolls
##     off on its own has nothing left to defend.
##  2. **It reads as teleporting.** Every round reset snaps the Can back to
##     Spawn0, so a Can that had wandered visibly jumped across the arena the
##     instant the round turned over. Reported repeatedly as "can keeps on
##     teleporting", and measured with `render_probe.gd`'s `canwatch` mode:
##     velocity a constant 6.0 on a diagonal, then a 1.4-1.8 unit jump back to
##     (0, 0.17, 0) on the transition. The teleport was never the bug — it was
##     the reset correcting a drift that should not have happened.
##
## It still shifts, because a completely static Can reads as a prop rather than
## as a unit and the pillar says take funny — but only within the base circle
## itself, so it never leaves the mark and the reset never has to yank it.
## `base_circle_decal` is 1.4 across, so 0.45 keeps it comfortably inside.
const CAN_HOLD_RADIUS: float = 0.45

## --- Evasion. Playtest 2026-07-29: "the Can (lata) AI doesn't work. It just
## --- stands completely still ... it needs a functioning evasion state."
##
## The Can genuinely had no reactive behaviour at all: `_update_can` only ever
## shuffled inside a 0.45 circle, which is below the speed threshold any observer
## would call movement, and nothing in this file ever looked at a slipper.
##
## ⚠️ THESE NUMBERS ARE A BALANCE SURFACE, NOT PHYSICS. A Can that dodges
## perfectly makes the game unwinnable — the whole sport is hitting it. They are
## tuned so a well-aimed throw still lands and a lazy one gets punished, and they
## are the first thing to revisit when the fairness log's win-rate numbers exist.
##
## ⚠️ MEASURED SWEEP, 2026-07-29 (tools/phys_probe.gd, 12 identical dead-centre
## throws — a deliberate worst case, since every throw is perfectly aimed from
## one fixed spot). Contact frames against evasion movement:
##     lookahead 1.10 -> 18 contact frames, 86% moving   (near-unhittable)
##     lookahead 0.70 -> 0                               (UNWINNABLE)
##     lookahead 0.85 -> 57, 72% moving
##     lookahead 0.55 -> 35, 75% moving
## Non-monotonic because the throws are identical and the outcome turns on exact
## sidestep phase — which is itself the reason not to trust a synthetic probe for
## balance. Shipped values sit on the hittable side on purpose; a Can that cannot
## be hit is a broken game, not a hard one.
## How far ahead a throw is tracked, in seconds.
const CAN_EVADE_LOOKAHEAD: float = 0.6
## Only dodge throws that would otherwise come this close, in units.
const CAN_EVADE_MISS_MARGIN: float = 1.0
## How far to the side one sidestep aims.
const CAN_EVADE_STEP: float = 1.2
## Never sidestep further than this from the base circle.
const CAN_EVADE_RADIUS: float = 1.8
## Below this time-to-impact, stop dodging and raise Guard instead.
const CAN_GUARD_ETA: float = 0.22

func _update_can(repick: bool) -> void:
	# ⚠️ EVASION FIRST. It overrides the hold-the-circle behaviour below.
	var threat := _incoming_slipper()
	if threat != null:
		_evade(threat)
		return
	_set_held("guard_dash", false)
	if repick or not _has_move_target:
		var angle := _rng.randf() * TAU
		var radius := _rng.randf() * CAN_HOLD_RADIUS
		_move_target = Vector3(cos(angle) * radius, character.global_position.y,
			sin(angle) * radius)
		_has_move_target = true
	_move_toward(_move_target)

## The tsinelas currently in the air and actually coming at us, or null.
##
## ⚠️ "IN THE AIR" IS NOT ENOUGH — it must be CLOSING. A slipper that has already
## flown past, or one arcing away after a miss, is not a threat, and reacting to
## it is what would make the Can look like it is dodging ghosts. Closing speed
## along the line to us has to be positive and the predicted miss distance small.
func _incoming_slipper() -> Carriable:
	var best: Carriable = null
	var best_eta := CAN_EVADE_LOOKAHEAD
	for other in _roster():
		if other == null or not is_instance_valid(other):
			continue
		if other.is_person or other == character:
			continue
		var c := other.get_node_or_null("Carriable") as Carriable
		if c == null or c.state != Carriable.CarryState.FLYING:
			continue
		var to_us := character.global_position - other.global_position
		to_us.y = 0.0
		var vel := other.velocity
		vel.y = 0.0
		var speed := vel.length()
		if speed < 0.5:
			continue
		var closing := vel.normalized().dot(to_us.normalized())
		if closing <= 0.2:
			continue # flying past or away, not at us
		var eta := to_us.length() / speed
		if eta > CAN_EVADE_LOOKAHEAD:
			continue
		# Perpendicular miss distance: how far off centre this throw currently is.
		var along := to_us.dot(vel.normalized())
		var miss := (to_us - vel.normalized() * along).length()
		if miss > CAN_EVADE_MISS_MARGIN:
			continue
		if eta < best_eta:
			best_eta = eta
			best = c
	return best

## Sidestep out of a throw's path, then let the hold-the-circle behaviour pull
## the Can back once the coast is clear.
##
## ⚠️ IT DODGES SIDEWAYS, NOT BACKWARDS. Running directly away from a slipper
## that is faster than the Can never works — it just gets hit later, further from
## its mark. Stepping perpendicular to the throw line is the only motion that
## actually changes the miss distance, and it is what a real lata-guard does.
##
## ⚠️ AND IT STAYS NEAR ITS MARK. Bounded by CAN_EVADE_RADIUS around the base
## circle. A Can free to flee anywhere inside the confinement box would abandon
## the thing it exists to defend, which is the failure the hold-the-circle rule
## was written for in the first place — this is a sidestep, not a retreat.
func _evade(threat: Carriable) -> void:
	_has_move_target = false
	var slipper := threat.get_parent() as CharacterBase
	if slipper == null:
		return
	var vel := slipper.velocity
	vel.y = 0.0
	if vel.length() < 0.1:
		return
	var dir := vel.normalized()
	# Perpendicular in the ground plane; pick the side we are already off toward
	# so the Can commits rather than oscillating across the line each tick.
	var side := Vector3(-dir.z, 0.0, dir.x)
	var to_us := character.global_position - slipper.global_position
	to_us.y = 0.0
	if side.dot(to_us) < 0.0:
		side = -side
	var target := character.global_position + side * CAN_EVADE_STEP
	# Clamp back toward the mark. Base circle is world origin on every map.
	var from_mark := Vector3(target.x, 0.0, target.z)
	if from_mark.length() > CAN_EVADE_RADIUS:
		from_mark = from_mark.normalized() * CAN_EVADE_RADIUS
	_move_toward(Vector3(from_mark.x, character.global_position.y, from_mark.z))
	# Guard as well when it is too late to move — the Can's Guard blocks dents
	# outright (character_base.apply_dent), so a throw that cannot be dodged can
	# still be eaten. This is the Can genuinely trying to survive rather than
	# just jittering.
	var eta := to_us.length() / maxf(vel.length(), 0.01)
	_set_held("guard_dash", eta <= CAN_GUARD_ETA)

## Patrols within the confinement box until an opposing Person (the Attacker)
## comes within detection range, then closes in and taps bump/Tag once in
## melee range. No pathfinding around obstacles — a straight-line approach is
## "moves with intent," not "plays well," per this item's own acceptance bar.
func _update_taya(repick: bool, delta: float) -> void:
	_taya_tap_cooldown -= delta
	var threat := _find_enemy_attacker()
	if threat == null or not is_instance_valid(threat):
		_set_held("bump", false)
		if repick or not _has_move_target:
			_move_target = _random_point_in_confinement(0.7)
			_has_move_target = true
		_move_toward(_move_target)
		return

	var distance := character.global_position.distance_to(threat.global_position)
	if distance > TAYA_DETECT_RANGE:
		_set_held("bump", false)
		if repick or not _has_move_target:
			_move_target = _random_point_in_confinement(0.7)
			_has_move_target = true
		_move_toward(_move_target)
		return

	_has_move_target = false # threat found; abandon the wander point
	if distance <= TAYA_MELEE_RANGE:
		_release_move()
		if _taya_tap_cooldown <= 0.0:
			_taya_tap_cooldown = TAYA_TAP_INTERVAL
			_tap("bump")
		return

	# ⚠️ BODY-BLOCK, DO NOT CHASE. This is the Taya's actual job and chasing was
	# the wrong shape for it.
	#
	# The Taya is confined to CONFINEMENT_RADIUS (5.0) and the attacker throws
	# from the 6.0 line, so a Taya that walks straight at the attacker ALWAYS
	# ends up pressed against the inside of its own box, out at the edge, having
	# achieved nothing — and with the can left completely unguarded behind it.
	# It could never reach the thing it was chasing; the geometry forbids it.
	#
	# What a real taya does, and what actually wins the round, is stand ON the
	# line between the slipper and the can. So: interpose. Take the point
	# `TAYA_BLOCK_STANDOFF` out from the can along the bearing to the attacker,
	# which puts the Taya's body in the throw's path, keeps it near enough to
	# tag anyone who closes, and keeps the can covered.
	#
	# Falls back to chasing only when the threat is already INSIDE the box, where
	# closing to melee is both possible and correct.
	var can := _find_tracked_can()
	if can == null or not is_instance_valid(can):
		_move_toward(threat.global_position)
		return
	var bearing := threat.global_position - can.global_position
	bearing.y = 0.0
	if bearing.length() < 0.1:
		bearing = Vector3.FORWARD
	var standoff: float = minf(TAYA_BLOCK_STANDOFF, CharacterBase.CONFINEMENT_RADIUS - 0.4)
	_move_toward(can.global_position + bearing.normalized() * standoff)

## Two jobs depending on whether this Person currently holds the slipper:
## retrieve it if not, or approach the throwing range and charge-release it
## if so. Retreats a short distance after releasing, mirroring the brief's
## "retreat/dodge the Taya" — a fixed step back from the can, not real
## evasion (no threat-awareness here; that is difficulty, out of scope).
func _update_attacker(repick: bool, delta: float) -> void:
	var carrier := character.get_node_or_null("Carrier") as Carrier
	if carrier == null:
		return
	if carrier.held() == null:
		_attacker_charging = false
		_attacker_charge_time = 0.0
		_set_held("special_ability", false)
		# See _release_settle_frames' own doc: for a couple of frames right
		# after releasing a charge, hold off on grabbing anything new (even a
		# DIFFERENT slipper) rather than only guarding the re-press this
		# release was actually about — simpler to reason about than tracking
		# which action the cooldown applies to, and the window is short
		# enough that a still-loose Tsinelas is not going anywhere in it.
		if _release_settle_frames > 0:
			_release_settle_frames -= 1
			_release_move()
			return
		var loose := _find_own_loose_tsinelas()
		if loose != null and is_instance_valid(loose):
			_has_move_target = false
			var target_char := loose.get_parent() as CharacterBase
			var distance := character.global_position.distance_to(target_char.global_position)
			if distance > ATTACKER_GRAB_RANGE:
				_move_toward(target_char.global_position)
			else:
				_release_move()
				_tap("grab")
			return
		# Nothing to retrieve (mid-flight, or already thrown and not yet
		# landed) — hold a spot back from the can rather than drifting toward
		# it with empty hands. Falls back to standing still (no can currently
		# tracked at all) rather than moving toward Vector3.ZERO, which reads
		# as "walking to the world origin" the moment a map is not centred
		# on it.
		if repick or not _has_move_target:
			var can := _find_tracked_can()
			if can != null and is_instance_valid(can):
				var away := character.global_position - can.global_position
				away.y = 0.0
				if away.length() < 0.1:
					away = Vector3.FORWARD
				_move_target = can.global_position + away.normalized() * (ATTACKER_THROW_RANGE + ATTACKER_RETREAT_DISTANCE)
				_has_move_target = true
		if _has_move_target:
			_move_toward(_move_target)
		else:
			_release_move()
		return

	# Holding the slipper.
	var can := _find_tracked_can()
	if can == null or not is_instance_valid(can):
		_release_move()
		return
	var to_can := can.global_position - character.global_position
	to_can.y = 0.0
	var range_now := to_can.length()

	if range_now > ATTACKER_THROW_RANGE:
		_move_toward(_open_throwing_spot(can))
		return

	# ⚠️ IN RANGE, BUT IS THE LANE OPEN? Human call, 2026-07-29: the AI should
	# "fulfil their roles and try to win (attacker avoid defender...)". Standing
	# still and charging into the Taya's chest is not trying to win — it feeds
	# the block. If the defender is sitting on this bearing, slide around to a
	# clear one before committing to the charge.
	var blocker := _blocking_defender(can)
	if blocker != null:
		_attacker_charging = false
		_attacker_charge_time = 0.0
		_set_held("special_ability", false)
		_move_toward(_open_throwing_spot(can))
		return

	# In range. Stand still to charge and release — moving mid-charge is not
	# modelled (carrier.gd allows it; a human sometimes does too), keeping
	# this pass simple.
	_release_move()
	if not _attacker_charging:
		_attacker_charging = true
		_attacker_charge_time = 0.0
		_set_held("special_ability", true)
	_attacker_charge_time += delta
	if _attacker_charge_time >= ATTACKER_CHARGE_TIME:
		_set_held("special_ability", false)
		_attacker_charging = false
		_attacker_charge_time = 0.0
		_release_settle_frames = RELEASE_SETTLE_FRAMES

## The defender standing between this attacker and the can, if any. "Between"
## is measured as perpendicular distance from the defender to the throw line,
## so a Taya beside the lane does not count and a Taya in it does.
func _blocking_defender(can: CharacterBase) -> CharacterBase:
	for other in _roster():
		if other == null or not is_instance_valid(other):
			continue
		if not other.is_person or other.team == character.team:
			continue
		var lane := can.global_position - character.global_position
		lane.y = 0.0
		var to_other := other.global_position - character.global_position
		to_other.y = 0.0
		if lane.length() < 0.1:
			continue
		var along := to_other.dot(lane.normalized())
		if along <= 0.0 or along >= lane.length():
			continue # behind us, or past the can
		var perpendicular := (to_other - lane.normalized() * along).length()
		if perpendicular < ATTACKER_LANE_CLEARANCE:
			return other
	return null

## A spot at throwing range from the can whose lane the defender is NOT sitting
## in. Samples bearings around the can starting from the one we already hold, so
## the attacker slides to the nearest open angle rather than teleporting its
## intent to the far side every decision tick.
func _open_throwing_spot(can: CharacterBase) -> Vector3:
	var current := character.global_position - can.global_position
	current.y = 0.0
	if current.length() < 0.1:
		current = Vector3.FORWARD
	var base_angle := atan2(current.z, current.x)
	var reach: float = ATTACKER_THROW_RANGE * 0.92
	# 0 first (hold this bearing if it is already open), then alternate outward.
	var steps: Array[float] = [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6, 2.2, -2.2]
	for step in steps:
		var a: float = base_angle + step
		var spot := can.global_position + Vector3(cos(a), 0.0, sin(a)) * reach
		var clear := true
		for other in _roster():
			if other == null or not is_instance_valid(other):
				continue
			if not other.is_person or other.team == character.team:
				continue
			var lane := can.global_position - spot
			lane.y = 0.0
			var to_other := other.global_position - spot
			to_other.y = 0.0
			if lane.length() < 0.1:
				continue
			var along := to_other.dot(lane.normalized())
			if along <= 0.0 or along >= lane.length():
				continue
			if (to_other - lane.normalized() * along).length() < ATTACKER_LANE_CLEARANCE:
				clear = false
				break
		if clear:
			return spot
	# Every bearing covered — take the one furthest from the defender anyway
	# rather than freezing, which is what "the bots suck" looked like.
	return can.global_position + Vector3(cos(base_angle + PI), 0.0, sin(base_angle + PI)) * reach

## Only ever meaningful while LOOSE (Carriable.drives_movement() already
## bypasses this entirely for CARRIED/FLYING — see character_base.gd — so
## this function is never even reached in either of those states in
## practice, but the check stays explicit rather than assumed). Crawls
## toward its own team's Attacker so the two meet in the middle, rather than
## the Attacker having to cross the whole confinement gap alone.
## movement_speed_scale() already applies CRAWL_SPEED_SCALE to whatever
## direction is pressed here — this file does not need to know that.
func _update_tsinelas(repick: bool) -> void:
	var carriable := character.get_node_or_null("Carriable") as Carriable
	if carriable == null or carriable.state != Carriable.CarryState.LOOSE:
		_release_move()
		return
	var attacker := _find_own_attacker()
	if attacker == null or not is_instance_valid(attacker):
		_release_move()
		return
	if repick:
		_has_move_target = false # always chase the attacker's CURRENT position
	var distance := character.global_position.distance_to(attacker.global_position)
	if distance <= TSINELAS_ARRIVE_DISTANCE:
		_release_move()
		return
	_move_toward(attacker.global_position)

## ---------------------------------------------------------------------------
## Roster lookups. get_parent() resolves to whatever this AI's own character's
## parent actually is, which differs by mode rather than needing a mode check
## here: Single Player's four units are direct siblings under Main.tscn's root
## (see Main.tscn / main.gd::_local_roster), while a networked AI-driven
## character's parent is $Players, the same MultiplayerSpawner.spawn_path
## every real networked character (and every other AI-driven one) is spawned
## under — see main.gd's own MultiplayerSpawner setup. Either way every
## sibling CharacterBase under that same parent is a legitimate roster entry.
## ---------------------------------------------------------------------------

func _roster() -> Array[CharacterBase]:
	var result: Array[CharacterBase] = []
	var parent := character.get_parent()
	if parent == null:
		return result
	for child in parent.get_children():
		if child is CharacterBase:
			result.append(child as CharacterBase)
	return result

## The opposing team's Person while that team is on offence — i.e. the unit
## this Taya's whole job is to stop.
func _find_enemy_attacker() -> CharacterBase:
	for other in _roster():
		if other == character or other.team == character.team:
			continue
		if other.is_person and not other.team_is_can_side:
			return other
	return null

## This Taya's own team's Attacker — same lookup as above, mirrored to the
## other side, for a loose Tsinelas deciding who to crawl toward.
func _find_own_attacker() -> CharacterBase:
	for other in _roster():
		if other == character or other.team != character.team:
			continue
		if other.is_person and not other.team_is_can_side:
			return other
	return null

## This Attacker's own team's Tsinelas Prop, only while it is actually LOOSE
## (can_be_grabbed_by() already encodes the team-ownership rule — reused here
## rather than re-deriving it, same as carrier.gd's own _find_grabbable()).
func _find_own_loose_tsinelas() -> Carriable:
	for other in _roster():
		if other == character or other.is_person:
			continue
		var carriable := other.get_node_or_null("Carriable") as Carriable
		if carriable == null:
			continue
		if carriable.can_be_grabbed_by(character):
			return carriable
	return null

## RoundManager's own tracked-Can list, same accessor offscreen_indicators.gd
## already uses for this exact lookup — reused rather than re-deriving is_can
## a third time across the codebase.
func _find_tracked_can() -> CharacterBase:
	for can in RoundManager.get_tracked_cans():
		if is_instance_valid(can) and can != character:
			return can
	return null

## ---------------------------------------------------------------------------
## Movement and input primitives.
## ---------------------------------------------------------------------------

func _random_point_in_confinement(inner_fraction: float) -> Vector3:
	var angle := _rng.randf() * TAU
	var min_r := CharacterBase.CONFINEMENT_RADIUS * inner_fraction * 0.3
	var max_r := CharacterBase.CONFINEMENT_RADIUS * maxf(inner_fraction, 0.35)
	var radius := _rng.randf_range(min_r, max_r)
	return Vector3(cos(angle) * radius, character.global_position.y, sin(angle) * radius)

## World-space direction, matching character_base.gd's own non-mouse-aimed
## movement scheme (`Vector3(input_dir.x, 0, input_dir.y)` — see its
## _physics_process comment on B-60): +X presses move_right, +Z presses
## move_down. AI units never carry CameraRig.AimSource.MOUSE (only the
## human's own rig is ever set to it — see main.gd::_start_local_test), so
## this world-space scheme is always the correct one for anything this file
## drives.
func _move_toward(target: Vector3) -> void:
	var offset := target - character.global_position
	offset.y = 0.0
	if offset.length() <= ARRIVE_DISTANCE:
		_release_move()
		return
	var dir := offset.normalized()
	const DEAD := 0.15
	_set_held("move_right", dir.x > DEAD)
	_set_held("move_left", dir.x < -DEAD)
	_set_held("move_down", dir.z > DEAD)
	_set_held("move_up", dir.z < -DEAD)

func _release_move() -> void:
	_set_held("move_left", false)
	_set_held("move_right", false)
	_set_held("move_up", false)
	_set_held("move_down", false)

## Presses or releases a HELD action only on an actual state transition.
## Deliberately not "call action_press() every frame we still want it held":
## measured against carrier.gd/character_base.gd's own edge-triggered reads
## (Input.is_action_just_pressed for bump/grab/special_ability-release),
## re-issuing action_press() on an already-pressed action risks re-arming
## that edge every frame instead of once — tracking our own believed state
## here and only calling into Input on a real transition sidesteps needing to
## know or rely on Godot's own internal idempotency for that call.
func _set_held(base: String, want_pressed: bool) -> void:
	# ⚠️ PER-CHARACTER INTENT, NOT THE GLOBAL `Input` SINGLETON.
	#
	# This used to call `Input.action_press(character.action_name(base))`, which
	# is process-global state keyed only by player_id — and main.gd hands AI
	# slots player_id (index % 2) + 3, so index 0 and index 2 both got p3. Two
	# bots then shared one action set, which is BOTH reported symptoms at once:
	# they moved in lockstep because they were reading each other, and they
	# froze because this function is edge-triggered against its own belief, so
	# one bot's release cancelled the other's press and neither re-pressed.
	# character_base.gd::input_pressed carries the full write-up.
	#
	# No transition guard any more, and none is needed: writing an unchanged
	# value into a dictionary is idempotent, and the edge helpers on
	# CharacterBase derive just_pressed/just_released from frame-to-frame
	# difference rather than from anything this function remembers.
	_held_actions[base] = want_pressed
	if character != null:
		character.ai_set_intent(base, want_pressed)

## A short press for an edge-triggered action (bump, Tag/special_ability on
## the defence side, grab) — pressed now, queued to release a few frames into
## the future (see RELEASE_SETTLE_FRAMES' own doc for why a SINGLE frame is
## not enough: is_action_just_pressed()/is_action_just_released() lag one
## physics frame behind the action_press()/action_release() call that causes
## them, so a bare one-frame tap can end up released again before the game
## code watching for it ever reads the edge). Matches a human's tap: one
## just_pressed edge, not a hold, and safe to call again next time this role
## wants another one since _set_held's own transition-tracking clears it as
## released in between.
func _tap(base: String) -> void:
	_set_held(base, true)
	_pending_release[base] = RELEASE_SETTLE_FRAMES

func _flush_pending_releases() -> void:
	if _pending_release.is_empty():
		return
	var done := []
	for base in _pending_release.keys():
		_pending_release[base] -= 1
		if _pending_release[base] <= 0:
			_set_held(base, false)
			done.append(base)
	for base in done:
		_pending_release.erase(base)
