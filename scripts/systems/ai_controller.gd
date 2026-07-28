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
## code by main.gd::_start_local_test() (`add_child`, not baked into
## CharacterBase.tscn) — Single Player is the only mode with unpiloted units
## to drive, and CharacterBase.tscn is shared with the networked spawn path,
## which has no use for this at all.
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
## Distance from the can an Attacker tries to hold before charging — mirrors
## the map's own throwing line (Art_Direction.md §9's 6-unit derivation).
## This file does not import that constant; it just aims for the same number
## so the AI throws from roughly where a human would.
const ATTACKER_THROW_RANGE: float = 6.0
const ATTACKER_GRAB_RANGE: float = 1.5
const ATTACKER_CHARGE_TIME: float = 0.65
const ATTACKER_RETREAT_DISTANCE: float = 3.0
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
		_decision_timer = DECISION_INTERVAL

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

func _update_can(repick: bool) -> void:
	if repick or not _has_move_target:
		var angle := randf() * TAU
		var radius := randf() * CAN_HOLD_RADIUS
		_move_target = Vector3(cos(angle) * radius, character.global_position.y,
			sin(angle) * radius)
		_has_move_target = true
	_move_toward(_move_target)

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
	if distance > TAYA_MELEE_RANGE:
		_move_toward(threat.global_position)
	else:
		_release_move()
		if _taya_tap_cooldown <= 0.0:
			_taya_tap_cooldown = TAYA_TAP_INTERVAL
			_tap("bump")

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
		_move_toward(can.global_position - to_can.normalized() * ATTACKER_THROW_RANGE * 0.9)
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
## Roster lookups. Single Player's four units are direct siblings under
## Main.tscn's root (see Main.tscn / main.gd::_local_roster) — there is no
## MultiplayerSpawner-owned Players node to worry about, since AI only ever
## attaches in the non-networked local flow.
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
	var angle := randf() * TAU
	var min_r := CharacterBase.CONFINEMENT_RADIUS * inner_fraction * 0.3
	var max_r := CharacterBase.CONFINEMENT_RADIUS * maxf(inner_fraction, 0.35)
	var radius := randf_range(min_r, max_r)
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
	var was_pressed: bool = _held_actions.get(base, false)
	if want_pressed == was_pressed:
		return
	_held_actions[base] = want_pressed
	var action := character.action_name(base)
	if want_pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)

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
