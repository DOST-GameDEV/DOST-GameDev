extends Node
class_name Carriable

## The tsinelas as a THROWN, RETRIEVED object — the Task 0 / Option B mechanic.
##
## Why this exists. Before Task 0 the Slipper was a character that walked around
## on its own legs. Nothing was ever thrown, nothing landed, nothing was picked
## up, and there was no scramble — which is exactly why the build did not read as
## tumbang preso. The street game is: throw your slipper at the guarded can, then
## scramble to get your slipper back without the taya tagging you. That retrieval
## scramble is the whole tension of the game, and this node is where it lives.
##
## Three states, which are also the three states the moodboard's THE SLIPPER card
## illustrates (docs/Dev_Plan.md §4.1 — "in-hand ready · thrown trajectory ·
## retrieval highlight"). That card is also the one card of the four with NO
## input badge, i.e. the art direction has described the slipper as an object,
## not a player, the entire time. The GDD is the doc that was out of step.
##
##   LOOSE   — lying on the ground. Its own player can still crawl it slowly and
##             exposed toward safety (CRAWL_SPEED_SCALE), or its team's Person
##             can run out and grab it. Both routes are taggable. This is the
##             scramble.
##   CARRIED — attached to a Person's hand. No self-movement; the Person aims it.
##   FLYING  — a real ballistic arc with a hitbox riding along, per ThrowProfile.
##
## WHO IT APPLIES TO. Lives on every CharacterBase, but is only ever meaningful
## on a team's Prop while that Prop is playing the Tsinelas side — see
## `is_throwable()`. A Can has one of these too; it simply reports false and
## never leaves LOOSE. `is_can` FLIPS EVERY ROUND (main.gd::_reset_world), so
## that is re-derived on demand and never cached in _ready().
##
## HOST-AUTHORITATIVE, deliberately and without exception. Holding a slipper
## decides whether a round can be won, so it follows the rule hit resolution
## already follows (hitbox.gd): clients ASK, the host DECIDES, the host
## broadcasts. Nothing here is client-asserted. Note the state is NOT put through
## CharacterBase.tscn's MultiplayerSynchronizer even though that would be less
## code — that synchronizer replicates outward from each character's OWN peer,
## not from the host, so routing held state through it would be precisely the
## client-asserted model this must not be.
##
## Carrying itself costs zero bandwidth: once every peer knows WHO is carrying,
## each recomputes the slipper's transform from that Person's hand locally.

enum CarryState { LOOSE, CARRIED, FLYING }

## How much of normal SPEED the slipper keeps while crawling itself back. Slow
## enough that crawling home across open ground is a real risk and calling your
## Person over is often better, fast enough that the Prop player is never simply
## parked. Tuning knob for the whole retrieval beat — start here.
const CRAWL_SPEED_SCALE: float = 0.45
## Flight is abandoned after this long even if nothing was hit, so a slipper
## launched into a gap in the geometry can never strand its team for the round.
const MAX_FLIGHT_TIME: float = 6.0
## The thrower is ignored for collisions for this long after release, so the
## slipper cannot immediately "land" on the hand that just threw it.
const THROWER_IGNORE_TIME: float = 0.25
## Fallback used when a slipper's ability carries no ThrowProfile of its own
## (e.g. the networked Prop default, which is currently quick_stand.tres for
## every Prop — see main.gd PROP_ABILITY).
const DEFAULT_PROFILE: ThrowProfile = preload("res://scripts/abilities/resources/throw_default.tres")

## Fired on every peer whenever the state changes, so UI and visuals can react
## without polling. CharacterVisual listens for the spin/landing read; hud.gd
## listens so the attacker can be told SLIPPER READY vs GO GET IT.
signal carry_state_changed(new_state: CarryState)

var state: CarryState = CarryState.LOOSE
## The Person currently holding this, or null. Set only by a host broadcast.
var carrier: CharacterBase = null

var _character: CharacterBase = null
var _flight_velocity: Vector3 = Vector3.ZERO
var _flight_time: float = 0.0
var _flight_hitbox: Area3D = null
var _thrower_ignore_left: float = 0.0

func _ready() -> void:
	_character = get_parent() as CharacterBase

## True when this unit is currently a tsinelas, i.e. a Prop on the offence side.
## Re-derived every call rather than cached because `is_can` flips every round.
## A Person is never throwable; neither is a Can.
func is_throwable() -> bool:
	return _character != null and not _character.is_person and not _character.is_can

## THE OWNERSHIP RULE (Task 1). An opponent's slipper is still a solid, kickable
## obstacle — you can body-check it, your bump still staggers it, it still blocks
## a doorway — it simply cannot be PICKED UP by the wrong team. Those are two
## different questions and the distinction is deliberate:
##
##   * collision / hitboxes  — handled elsewhere and NOT touched by ownership.
##     hitbox.gd's own same-team check (B-09) already governs who can hit whom,
##     and the physics body is never disabled on account of who owns it.
##   * pick-up               — this function, and only this function.
##
## Built on CharacterBase.team, the team identity that already exists (B-09).
## There is deliberately no second team system: if this ever disagrees with
## hitbox.gd, that is a bug in one of the two, not a design.
func can_be_grabbed_by(who: CharacterBase) -> bool:
	if who == null or _character == null:
		return false
	if not is_throwable():
		return false # a Can is not a pick-up; see reset_channel handling in carrier.gd
	if state != CarryState.LOOSE:
		return false # already in a hand, or still in the air
	if who.team != _character.team:
		return false # an opponent's tsinelas: shove it, kick it, never pocket it
	if not who.is_person:
		return false # a Prop has no hands — only the team's Person retrieves
	return true

## Whether this node is currently driving the character's movement itself, in
## which case character_base.gd hands the physics frame over (see its
## _physics_process). LOOSE deliberately returns false: a loose slipper still
## walks itself with normal player input, just slowed.
func drives_movement() -> bool:
	return state == CarryState.CARRIED or state == CarryState.FLYING

## Multiplier applied to normal movement speed. Only ever != 1.0 while LOOSE and
## throwable — the crawl home.
func movement_speed_scale() -> float:
	if state == CarryState.LOOSE and is_throwable():
		return CRAWL_SPEED_SCALE
	return 1.0

## Read by character_visual.gd for the in-flight tumble. Exposed rather than
## making callers reach through to `ability` themselves — how a slipper flies is
## this node's business, what that looks like is theirs.
func spin_speed_deg() -> float:
	return _profile().spin_speed_deg

## Called from character_base.gd's _physics_process when drives_movement() is
## true. Runs on EVERY peer, not just the authority: both branches below are
## deterministic given state that is already replicated, so running them locally
## is both cheaper and smoother than streaming a transform.
func physics_step(delta: float) -> void:
	match state:
		CarryState.CARRIED:
			_step_carried()
		CarryState.FLYING:
			_step_flying(delta)

## Snap to the carrier's hand. Every peer computes this identically from the
## replicated `carrier`, so a carried slipper needs no position replication at
## all. The hand itself comes from CharacterVisual, which is the only thing that
## knows the shape of the model — character_base.gd must never learn where a
## Person's hand is, same rule that keeps dents out of it.
func _step_carried() -> void:
	if carrier == null or not is_instance_valid(carrier):
		# The carrier left the match mid-hold. Drop where we stand rather than
		# following a freed node; the host will confirm with its own broadcast.
		if _is_host():
			host_drop()
		return
	var hand := carrier.get_hand_attachment()
	if hand == null:
		return # the Person's model has not been instanced yet; try again next frame
	# ORTHONORMALISED, not copied wholesale. A Person's model is scaled by
	# CharacterVisual.PERSON_SCALE (2.38) and every bone under its Skeleton3D
	# inherits that, so assigning the hand's transform directly would blow the
	# slipper up to 2.38x — with no error, just a comically large tsinelas.
	var hand_transform := hand.global_transform
	_character.global_transform = Transform3D(hand_transform.basis.orthonormalized(), hand_transform.origin)
	_character.velocity = Vector3.ZERO

func _step_flying(delta: float) -> void:
	_flight_time += delta
	if _thrower_ignore_left > 0.0:
		_thrower_ignore_left -= delta

	var profile := _profile()
	_flight_velocity.y -= CharacterBase.GRAVITY * profile.gravity_scale * delta

	# Mid-flight steer — the Prop player is a pilot, not cargo (Task 0 agreement).
	# Sideways only, relative to the direction of travel: it can curve a throw
	# around a defender, never turn it into a guided missile or add range.
	if profile.steer_strength > 0.0 and _is_locally_driven():
		var input_dir := Input.get_vector(
			_character.action_name("move_left"), _character.action_name("move_right"),
			_character.action_name("move_up"), _character.action_name("move_down"))
		if input_dir.length() > 0.0:
			var travel := _flight_velocity
			travel.y = 0.0
			if travel.length() > 0.01:
				var right := travel.normalized().cross(Vector3.UP)
				_flight_velocity += right * input_dir.x * profile.steer_strength * delta

	var collision := _character.move_and_collide(_flight_velocity * delta)
	_character.velocity = _flight_velocity

	if not _is_host():
		return # only the host decides that a flight has ended

	var hit_something := collision != null and _thrower_ignore_left <= 0.0
	if hit_something or _flight_time >= MAX_FLIGHT_TIME:
		host_land()

## ---------------------------------------------------------------------------
## Host-side transitions. Everything below decides; the _rpc_* pair broadcasts.
## Call these ONLY on the host — clients route through carrier.gd's request RPCs.
## ---------------------------------------------------------------------------

func host_grab(by: CharacterBase) -> void:
	if not _is_host() or not can_be_grabbed_by(by):
		return
	_broadcast_carried(by.get_path())

## Launch. `direction` is the thrower's aim (already normalised, world space);
## `power` is 0..1 from the charge meter.
func host_throw(direction: Vector3, power: float) -> void:
	if not _is_host() or state != CarryState.CARRIED:
		return
	var profile := _profile()
	var aim := direction.normalized()
	# Tilt the aim upward by the profile's arc. Rotating about the horizontal
	# axis perpendicular to the aim keeps this correct regardless of where the
	# thrower is looking, including straight up or down.
	var horizontal := Vector3(aim.x, 0.0, aim.z)
	if horizontal.length() > 0.01:
		var axis := horizontal.normalized().cross(Vector3.UP)
		aim = aim.rotated(axis.normalized(), -deg_to_rad(profile.arc_angle_deg))
	var speed: float = profile.launch_speed * clampf(power, 0.0, 1.0)
	_broadcast_flying(_character.global_position, aim.normalized() * speed)

func host_land() -> void:
	if not _is_host() or state != CarryState.FLYING:
		return
	_broadcast_loose(_character.global_position)

## The carrier died, disconnected, or the round ended while holding.
func host_drop() -> void:
	if not _is_host() or state == CarryState.LOOSE:
		return
	_broadcast_loose(_character.global_position)

## Round reset. Called from CharacterBase.reset_for_new_round() on every peer —
## no RPC, because every peer runs the reset itself from already-synced state,
## exactly as _reset_world does for team/role.
func reset_for_new_round() -> void:
	_clear_flight_hitbox()
	_flight_velocity = Vector3.ZERO
	_flight_time = 0.0
	_thrower_ignore_left = 0.0
	if carrier != null and is_instance_valid(carrier):
		_character.remove_collision_exception_with(carrier)
	carrier = null
	_set_state(CarryState.LOOSE)

## ---------------------------------------------------------------------------
## Broadcasts. `call_local` so the host runs its own handler too, matching the
## pattern MatchManager._sync_round_started already uses.
## ---------------------------------------------------------------------------

func _broadcast_carried(carrier_path: NodePath) -> void:
	if NetworkManager.is_networked():
		_rpc_set_carried.rpc(carrier_path)
	else:
		_rpc_set_carried(carrier_path)

func _broadcast_flying(origin: Vector3, velocity: Vector3) -> void:
	if NetworkManager.is_networked():
		_rpc_set_flying.rpc(origin, velocity)
	else:
		_rpc_set_flying(origin, velocity)

func _broadcast_loose(where: Vector3) -> void:
	if NetworkManager.is_networked():
		_rpc_set_loose.rpc(where)
	else:
		_rpc_set_loose(where)

## "any_peer", not "authority", for the same reason CharacterBase._apply_hit_result
## documents: resolution runs on the HOST, but this node's multiplayer authority
## is the slipper's own owning peer, which for any non-host player is not the
## host. An "authority" RPC from the host would be silently rejected.
@rpc("any_peer", "call_local", "reliable")
func _rpc_set_carried(carrier_path: NodePath) -> void:
	var who := get_node_or_null(carrier_path) as CharacterBase
	if who == null:
		return
	carrier = who
	_clear_flight_hitbox()
	# While in a hand the slipper is part of the carrier: it must not shove its
	# own teammate around, and it must not be independently hittable.
	_set_physics_enabled(false)
	_notify_carrier(who, self)
	_set_state(CarryState.CARRIED)

@rpc("any_peer", "call_local", "reliable")
func _rpc_set_flying(origin: Vector3, velocity: Vector3) -> void:
	_character.global_position = origin
	_flight_velocity = velocity
	_flight_time = 0.0
	_thrower_ignore_left = THROWER_IGNORE_TIME
	# Solid again the instant it leaves the hand — it has to be able to bounce
	# off walls and, above all, hit the lata.
	_set_physics_enabled(true)
	if carrier != null and is_instance_valid(carrier):
		_character.add_collision_exception_with(carrier)
		_notify_carrier(carrier, null)
	_spawn_flight_hitbox()
	_set_state(CarryState.FLYING)

@rpc("any_peer", "call_local", "reliable")
func _rpc_set_loose(where: Vector3) -> void:
	_character.global_position = where
	_character.velocity = Vector3.ZERO
	_flight_velocity = Vector3.ZERO
	_clear_flight_hitbox()
	if carrier != null and is_instance_valid(carrier):
		_character.remove_collision_exception_with(carrier)
		_notify_carrier(carrier, null)
	carrier = null
	_set_physics_enabled(true)
	_set_state(CarryState.LOOSE)

## ---------------------------------------------------------------------------

## Keeps the Person's own `Carrier._held` in step with this node's `carrier`.
## Both are set from the same host broadcast on the same peer, so they cannot
## drift — which matters because the HUD reads one and the throw reads the other.
func _notify_carrier(who: CharacterBase, what: Carriable) -> void:
	var component := who.get_node_or_null("Carrier") as Carrier
	if component != null:
		component.notify_holding(what)

func _set_state(new_state: CarryState) -> void:
	if new_state == state:
		return
	state = new_state
	carry_state_changed.emit(state)

## The hitbox that rides along with a thrown slipper. Reuses AbilityUtils rather
## than hand-rolling one, so flight hits go through exactly the same host-only
## resolution, team check and Option A/B branching that every other hit does
## (hitbox.gd) — a thrown slipper denting or knocking down a lata is not a
## special case, it is the ordinary hit path with an unusual delivery.
func _spawn_flight_hitbox() -> void:
	_clear_flight_hitbox()
	var profile := _profile()
	_flight_hitbox = AbilityUtils.spawn_pulse_hitbox(
		_character, profile.hit_radius, MAX_FLIGHT_TIME, profile.forces_downed,
		Vector3.ZERO, true)

func _clear_flight_hitbox() -> void:
	if _flight_hitbox != null and is_instance_valid(_flight_hitbox):
		_flight_hitbox.queue_free()
	_flight_hitbox = null

## Disables/enables the body and the hurtbox together. Deliberately NOT used to
## express ownership — see can_be_grabbed_by(); an opponent's loose slipper is
## fully solid and this is never called on account of whose it is.
func _set_physics_enabled(enabled: bool) -> void:
	var shape := _character.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null:
		shape.disabled = not enabled
	var hurtbox := _character.get_node_or_null("Hurtbox") as Area3D
	if hurtbox != null:
		hurtbox.monitorable = enabled

## The slipper's own ability carries its flight identity (see throw_profile.gd).
## Duck-typed rather than declared on AbilityBase so the three Can abilities,
## which have no throw, need no empty override.
func _profile() -> ThrowProfile:
	if _character != null and _character.ability != null \
			and _character.ability.has_method("get_throw_profile"):
		var profile := _character.ability.get_throw_profile() as ThrowProfile
		if profile != null:
			return profile
	return DEFAULT_PROFILE

func _is_host() -> bool:
	return not NetworkManager.is_networked() or NetworkManager.is_host()

## Whether the human at THIS machine is the one flying this slipper — gates the
## mid-flight steer so a remote peer's input never curves someone else's throw.
func _is_locally_driven() -> bool:
	if NetworkManager.is_networked():
		return _character.is_multiplayer_authority()
	return true
