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
## User feedback, 2026-07-28: a thrown slipper should bounce a bit instead of
## stopping dead on first contact — a rubber bakya/tsinelas skidding to a halt
## in one frame reads as a physics bug, not a landing. Reflects _flight_velocity
## off the collision normal (Vector3.bounce()) and keeps this fraction of its
## speed each time. Purely a physical/cosmetic change: hit resolution against a
## lata goes through _spawn_flight_hitbox()'s own Area3D overlap, entirely
## independent of move_and_collide's collision result below, so a slipper that
## bounces off a Can still scores the hit on first contact same as before.
## ⚠️ LOWERED same session: 0.45/2 bounces read as "ragdolls while flying" and
## fed the separate "barely has power even during full windup" report — an
## early clip on nearby clutter (crates, tires — up to 1.0 tall, and a throw
## launches around hand height) now only cost a MAX_BOUNCES=2 sequence, each
## keeping a still-substantial 45% of speed, which looks chaotic and reads as
## the whole throw losing its power rather than one clean skip. A single,
## weaker bounce is closer to "bounces a bit" than "physically simulates a
## rubber object," which was never the ask.
const BOUNCE_DAMPING: float = 0.3
## After this many bounces, the next collision lands it (goes LOOSE) regardless
## of remaining speed, so a shallow-angle skip along the floor can't bounce
## forever. MAX_FLIGHT_TIME (6s) is the backstop under that. Lowered from 2 to
## 1 alongside BOUNCE_DAMPING above — one clean skip, not a multi-bounce
## ragdoll sequence.
const MAX_BOUNCES: int = 1
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
var _bounces_left: int = 0

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
		return false # a Can is not a pick-up — it is a RESET, see can_be_reset_by()
	if state != CarryState.LOOSE:
		return false # already in a hand, or still in the air
	if who.team != _character.team:
		return false # an opponent's tsinelas: shove it, kick it, never pocket it
	if not who.is_person:
		return false # a Prop has no hands — only the team's Person retrieves
	return true

## T-3 / B-46 — THE LATA RESET CHANNEL, target side. The taya (the defending
## Person) holds `grab` next to their own knocked-down lata to stand it back up.
## This is the half that says whether that is allowed; carrier.gd runs the
## channel itself and calls host_reset_upright() when it completes.
##
## On the moodboard the whole time, in neither the code nor the GDD until now —
## it is the beat that makes defending an active job rather than standing around
## waiting to be hit.
##
## Mirrors can_be_grabbed_by() deliberately, including the same team rule: you
## right YOUR OWN team's lata, never the opponents'. Note what is NOT checked
## here — whether the round is still live. RoundManager owns that, and by the
## time a Can is SEALED the round is already over (one tracked Can per round, and
## sealing it ends it), which is exactly why SEALED is not resettable below.
func can_be_reset_by(who: CharacterBase) -> bool:
	if who == null or _character == null:
		return false
	if not _character.is_can:
		return false # only a lata is ever stood back up
	if not who.is_person or who.team != _character.team:
		return false # the taya rights their own can; nobody else touches it
	if GameLaunch.game_mode == GameLaunch.GameMode.OPTION_A:
		# Option A: no Downed/Seal machinery at all, the can just carries dents.
		# Beat one back out. At MAX_DENTS the round has already been reported, so
		# only a partially dented can is worth channelling.
		return _character.dents > 0 and _character.dents < CharacterBase.MAX_DENTS
	# Option B: DOWNED only. Not SEALED — a sealed can means the round is already
	# lost, and un-sealing it here would be round-win logic living in the wrong
	# file. Not NORMAL either; there is nothing to stand up.
	return _character.state == CharacterBase.State.DOWNED

## Host-side completion of the channel. Same shape as host_grab/host_throw: the
## client asked, the host re-validates from scratch, and only then does it apply.
##
## The apply is routed to the CAN'S OWN AUTHORITY, not broadcast — this is the
## idiom hitbox.gd/_apply_hit_result already established for state changes: the
## owning peer mutates its own state and CharacterBase.tscn's
## MultiplayerSynchronizer distributes it outward from there. Broadcasting to
## every peer instead would have each one write state it does not own, and the
## synchronizer would immediately overwrite it.
func host_reset_upright(by: CharacterBase) -> void:
	if not _is_host() or not can_be_reset_by(by):
		return
	if NetworkManager.is_networked():
		_rpc_apply_reset.rpc_id(_character.get_multiplayer_authority())
	else:
		_rpc_apply_reset()

## "any_peer" for the reason documented on the broadcasts below: this is sent BY
## the host to a peer that is not this node's authority in the usual case, and an
## "authority" RPC would be silently dropped.
@rpc("any_peer", "call_local", "reliable")
func _rpc_apply_reset() -> void:
	if GameLaunch.game_mode == GameLaunch.GameMode.OPTION_A:
		_character.clear_dent()
	else:
		_character.self_right()

## Whether this node is currently driving the character's movement itself, in
## which case character_base.gd hands the physics frame over (see its
## _physics_process). LOOSE deliberately returns false: a loose slipper still
## walks itself with normal player input, just slowed.
func drives_movement() -> bool:
	return state == CarryState.CARRIED or state == CarryState.FLYING

## Multiplier applied to normal movement speed. Only ever != 1.0 while LOOSE and
## throwable — the crawl home.
## ⚠️ Gated on RoundManager.round_active, 2026-07-28, same reason and same
## day as CharacterBase._is_confined_to_base()'s gate: before the round
## actually starts (the new pre-round free-roam window) a Tsinelas Prop is
## always LOOSE and throwable by definition, and without this gate its
## player would be stuck crawling at CRAWL_SPEED_SCALE the whole time they're
## supposed to be moving "with no restrictions."
func movement_speed_scale() -> float:
	if RoundManager.round_active and state == CarryState.LOOSE and is_throwable():
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
			# B-74: this whole function runs ABOVE character_base.gd's
			# `round_active` gate, deliberately — every peer has to run the carry
			# maths and the authority gate sits below it. The side effect nobody
			# thought through is that the round-end freeze, which stops all four
			# players dead, did not stop a slipper already in the air: it sailed
			# on through the entire intermission until reset_for_new_round() put
			# it back on the floor. Hold it where it is instead. The round is
			# already decided by this point (report_round_win has fired), so
			# freezing the arc can never change an outcome.
			if not RoundManager.round_active:
				_character.velocity = Vector3.ZERO
				return
			_step_flying(delta)

## B-90 — the tsinelas is a flat, thin object (0.432 long x 0.166 wide x 0.078
## tall): its own sole is the ONLY side that reads as "a slipper" at a glance,
## and the arm bone's fixed rotation (see character_visual.gd's
## HAND_CARRY_OFFSET comment, "a +60 degree rotation about Y") leaves the
## object's local up axis close to world-up — i.e. presented flat, roughly
## LEVEL with the eye, which from a camera at the same height is close to
## edge-on. Edge-on, a 0.078-tall object is a sliver, not a slipper. This
## tilts the carried object about its OWN local X axis (applied before the
## hand's rotation, so it tilts in the object's own frame first) to angle the
## sole up toward the camera, the way a real held object naturally reads.
## Cosmetic only, on top of the position work HAND_CARRY_OFFSET already does —
## does not touch LOOSE or FLYING, which already read fine (a slipper crawling
## on the ground or spinning in flight is not being viewed edge-on the same
## way). Tuning window roughly 45-70 degrees; re-render if you change it.
const CARRY_TILT_DEG: float = 55.0

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
	#
	# B-90: `* tilt`, not `tilt *` — tilt has to apply in the OBJECT'S OWN
	# local frame (pre-multiplied) so it rotates the sole toward the camera
	# regardless of which way the hand itself is currently oriented, rather
	# than tilting relative to the world after the hand's rotation is already
	# applied.
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(CARRY_TILT_DEG))
	var hand_transform := hand.global_transform
	var basis := hand_transform.basis.orthonormalized() * tilt
	# ⚠️ PUT THE MESH IN THE HAND, NOT THE ORIGIN.
	#
	# 2026-07-29, reported as "floating slipper when held, make it acc be on the
	# hand". A carried unit's visible model is NOT centred on its CharacterBase
	# origin: `character_visual.gd::_align_to_capsule_floor` drops it so its
	# bottom rests on the capsule floor, which for the tsinelas is a measured
	# **0.160 below the origin**. Snapping the origin to the hand therefore hangs
	# the visible slipper under the hand, every frame, by construction.
	#
	# This used to be compensated by baking a fudge into
	# CharacterVisual.HAND_CARRY_OFFSET, which was wrong twice over: the value
	# was 0.441 rather than 0.160, and it lived in the HAND BONE's rotating local
	# frame, so whatever it meant in one animation clip it meant something else
	# in the next. Corrected here instead, in world space, from the carried
	# unit's own measured offset — so it is right for the Can too, and it cannot
	# drift from the drop it exists to cancel.
	var centre := Vector3.ZERO
	var visual := _character.get_node_or_null("Visual") as CharacterVisual
	if visual != null:
		centre = visual.visual_centre_offset()
	_character.global_transform = Transform3D(
		basis, hand_transform.origin - basis * centre)
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
	if collision != null and _thrower_ignore_left <= 0.0 and _bounces_left > 0:
		_flight_velocity = _flight_velocity.bounce(collision.get_normal()) * BOUNCE_DAMPING
		_bounces_left -= 1
		collision = null # consumed by the bounce, not a landing this frame
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
		_watch_carrier_state(carrier, false)
	carrier = null
	# 2026-07-28 — B-101. This was missing entirely. _rpc_set_carried() disables this
	# unit's own collision the instant it's grabbed (_set_physics_enabled(false)
	# — CARRIED must not shove a teammate or be independently hittable); nothing
	# here ever turned it back on. A Prop that was CARRIED when the round ended
	# (the common case — the attacker is usually still holding it) came out of
	# reset_for_new_round() as LOOSE but with its body collision STILL disabled,
	# free to fall straight through the floor with nothing to stop it — this unit
	# might become the Can next round, which is exactly "the can fell off the
	# map." _set_physics_enabled(true) is idempotent (harmless if collision was
	# already on), so this is safe to call unconditionally every round.
	_set_physics_enabled(true)
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
	_watch_carrier_state(who, true)
	_clear_flight_hitbox()
	# While in a hand the slipper is part of the carrier: it must not shove its
	# own teammate around, and it must not be independently hittable.
	_set_physics_enabled(false)
	_notify_carrier(who, self)
	_set_state(CarryState.CARRIED)

@rpc("any_peer", "call_local", "reliable")
func _rpc_set_flying(origin: Vector3, velocity: Vector3) -> void:
	_character.global_position = origin
	# 2026-07-28 — user report: a thrown slipper "doesnt land flat, sometimes
	# it points up from ground... it also goes thru the floor when this
	# happens." _step_carried() overwrites _character's entire transform —
	# BASIS included — to the carrier's tilted hand orientation
	# (CARRY_TILT_DEG, 55°) every physics frame while held. Nothing ever reset
	# that basis on release: only `global_position` was written here and in
	# _rpc_set_loose() below, so the 55° tilt (plus whatever yaw the hand had)
	# rode straight through the whole flight and into landing. A capsule
	# resting on the floor at an angle instead of upright is exactly the kind
	# of resolved-collision edge case that can end up clipping through thin
	# geometry, which matches the floor-tunnelling half of the report.
	# _spin_while_airborne()'s own rotation is on the VISUAL node, a CHILD of
	# this transform, and was never the actual cause — resetting it alone
	# (already correct) could not fix a tilt baked into the parent.
	_character.rotation = Vector3.ZERO
	_flight_velocity = velocity
	_flight_time = 0.0
	_thrower_ignore_left = THROWER_IGNORE_TIME
	_bounces_left = MAX_BOUNCES
	# Solid again the instant it leaves the hand — it has to be able to bounce
	# off walls and, above all, hit the lata.
	_set_physics_enabled(true)
	if carrier != null and is_instance_valid(carrier):
		_character.add_collision_exception_with(carrier)
		_notify_carrier(carrier, null)
		# B-75: stop watching the thrower the instant it leaves the hand. `carrier`
		# is deliberately still set here (the collision exception is cleared
		# against it on landing), but the slipper is no longer theirs to drop —
		# without this, tagging the thrower mid-flight would land the slipper in
		# mid-air.
		_watch_carrier_state(carrier, false)
	_spawn_flight_hitbox()
	_set_state(CarryState.FLYING)

@rpc("any_peer", "call_local", "reliable")
func _rpc_set_loose(where: Vector3) -> void:
	_character.global_position = where
	# Defensive, same reasoning as _rpc_set_flying()'s own note — a slipper
	# dropped (not thrown) straight from CARRIED also carries the 55° hand
	# tilt through unless this clears it too.
	_character.rotation = Vector3.ZERO
	_character.velocity = Vector3.ZERO
	_flight_velocity = Vector3.ZERO
	_clear_flight_hitbox()
	if carrier != null and is_instance_valid(carrier):
		_character.remove_collision_exception_with(carrier)
		_notify_carrier(carrier, null)
		_watch_carrier_state(carrier, false)
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

## B-75. A taya tagging the attacker mid-carry has to knock the slipper out of
## their hands — that is most of the point of tagging, and without it the whole
## retrieval scramble can be skipped by simply eating the hit. Any state that is
## not NORMAL drops it: STAGGERED, DOWNED and SEALED are all "this Person is not
## currently holding anything together".
##
## Watched from HERE rather than from character_base.gd, which must never learn
## what carrying is — the same rule that keeps dents and round-win logic out of
## that file. It subscribes to the state_changed signal that already exists, so
## nothing had to be added on the CharacterBase side.
##
## Runs on every peer; only the host acts, because dropping is a transition like
## every other one and host_drop() is where that is decided.
func _on_carrier_state_changed(new_state: CharacterBase.State) -> void:
	if new_state == CharacterBase.State.NORMAL:
		return
	if _is_host():
		host_drop()

## Connected while, and only while, this slipper is actually in someone's hand.
## Guarded both ways because a carrier can be freed mid-hold (see _step_carried)
## and a double-connect would fire host_drop() twice.
func _watch_carrier_state(who: CharacterBase, enable: bool) -> void:
	if who == null or not is_instance_valid(who):
		return
	if enable:
		if not who.state_changed.is_connected(_on_carrier_state_changed):
			who.state_changed.connect(_on_carrier_state_changed)
	elif who.state_changed.is_connected(_on_carrier_state_changed):
		who.state_changed.disconnect(_on_carrier_state_changed)

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
