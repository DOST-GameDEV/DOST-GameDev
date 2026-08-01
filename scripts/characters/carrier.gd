extends Node
class_name Carrier
## The hands. Everything a player does with a slipper or to the lata.
## Slimmed from 901 lines to this on 2026-07-31, branch `HARRYDAKS`.

## ---------------------------------------------------------------------------
## ⚠️⚠️ WHAT WENT, AND WHAT SURVIVED.
##
## GONE: the `bagsak` lob and its overhold window, the long-throw speed and
## knockback bonuses, the 5 s long-throw punish, the per-class `ThrowProfile`
## lookup, and the `Carriable` component this used to talk to. The slipper is a
## prop now (`scripts/objects/slipper.gd`).
##
## SURVIVED, and each of these is a measured fix that would cost a session to
## rediscover:
##   · `_aim_point()` casts from the CAMERA, not the body. The crosshair is a
##     screen-space thing and the camera is the only node that knows where it
##     points from.
##   · `_throw_origin()` launches from the SIGHT LINE, not the hand. Measured: a
##     throw leaving the hand sags 0.38–0.43 m below the line the player is
##     aiming along, peaking within 0.2 m of the player — i.e. the slipper drops
##     out of the bottom of the screen the instant it is released. From the sight
##     line the same throws sag 0.001–0.043 m. The path was right; the starting
##     height was not.
##   · `input_pressed`, NOT `input_just_pressed`, to START a charge. Measured by
##     `input_probe`: a synthetic press that lasts one frame charged to 0.000 with
##     the just-pressed form.
##   · `observed_charge_power()` ticks on EVERY peer. `charge_power()` only ticks
##     on the peer that controls the unit, so a wind-up drawn from it is invisible
##     to the person being aimed at — which is the whole counterplay.
##
## ⚠️ THE THROW GATE IS NOT HERE. It is `RoundManager.can_throw()`, one function,
## because the HUD's crosshair tell reads it too — so the crosshair greys out for
## exactly the reasons the throw refuses, rather than for a second opinion about
## them.
## ---------------------------------------------------------------------------

## Seconds of hold for a full-power throw.
##
## ⚠️⚠️ 2.5 s SINCE 2026-08-01, UP FROM 0.9. 🧑: *"Charge Time: Takes 2.5 seconds to
## reach 100% power. Strategic Role: Requires Attackers to commit to standing still
## or moving slowly while aiming, giving the Defender time to react."*
##
## This is a pacing change, not a nerf. At 0.9 s the throw was effectively
## instantaneous from the taya's point of view — there was nothing to react TO, so
## the taya's only counterplay was to already be standing in the right place. At 2.5
## it is a visible commitment, and it is what makes the new lunge worth charging: the
## taya now has a window in which they can see an attacker winding up and act on it.
const CHARGE_FULL_TIME: float = 2.5
## A tap still throws. `slipper.gd::MIN_POWER_SCALE` is the other half of this.
const CHARGE_MIN_POWER: float = 0.35
## After a pickup, before it may be thrown. Anti-cheese: grab-and-fling at the
## Defender's feet was free.
const THROW_LOCK_TIME: float = 1.25
## How close you have to be to a loose slipper to pick it up.
const PICKUP_RADIUS: float = 1.4
## How far along the crosshair to look for something to aim AT, before giving up
## and treating the aim as a bearing rather than a target.
const AIM_RAY_LENGTH: float = 40.0
## How far ahead of the eye the slipper actually leaves from. ⚠️ 0.15, NOT 0.5,
## and the difference is measurable in hit rate — moving the launch forward
## shortens the horizontal distance a dodging target's ETA is computed over.
const MUZZLE_FORWARD: float = 0.15

signal charge_changed(power: float)
signal held_changed(held: Slipper)
signal reset_channel_changed(progress: float)

var _character: CharacterBase = null
var _held: Slipper = null
var _charge_time: float = 0.0
var _is_charging: bool = false
var _throw_lock_left: float = 0.0
var _channel_time: float = 0.0
var _channelling: bool = false
var _trajectory: TrajectoryPreview = null

## Ticks on every peer off the charge broadcast — see the header.
var _observed_charge_time: float = -1.0

func _ready() -> void:
	_character = get_parent() as CharacterBase

func _physics_process(delta: float) -> void:
	if _throw_lock_left > 0.0:
		_throw_lock_left = maxf(0.0, _throw_lock_left - delta)
	if _observed_charge_time >= 0.0:
		_observed_charge_time = minf(_observed_charge_time + delta, CHARGE_FULL_TIME)

## ---------------------------------------------------------------------------
## QUERIES.
## ---------------------------------------------------------------------------

func held() -> Slipper:
	if _held != null and not is_instance_valid(_held):
		_held = null
	if _held != null and _held.state != Slipper.CarryState.CARRIED:
		_set_held(null)
	return _held

func is_charging() -> bool:
	return _is_charging

func throw_lock_left() -> float:
	return _throw_lock_left

## True while this player is mid-commitment, so `character_base.gd::_step_shove`
## knows an E press was already spent on something else.
func is_busy() -> bool:
	return _is_charging or _channelling

func charge_power() -> float:
	if not _is_charging:
		return 0.0
	return clampf(lerpf(CHARGE_MIN_POWER, 1.0, _charge_time / CHARGE_FULL_TIME),
		CHARGE_MIN_POWER, 1.0)

## -1 when nobody is winding up. Read by `character_visual.gd` for the
## third-person arm pose — never `charge_power()`, see the header.
func observed_charge_power() -> float:
	if _observed_charge_time < 0.0:
		return -1.0
	return clampf(_observed_charge_time / CHARGE_FULL_TIME, 0.0, 1.0)

## ⚠️ BOTH THIS AND THE COMPLETION TEST ASK THE LATA, NOT THE CONST (§2.8). The
## channel length is per-can now, and a progress bar filling against 1.5 while the
## test fires at 1.79 is the "the HUD promises what the rule refuses" failure this
## file's own header keeps warning about. `RESET_CHANNEL_TIME` is still the neutral
## value and still the number in `Design.md`; `reset_channel_time()` is what the
## can on the mark actually costs.
func channel_progress() -> float:
	if not _channelling:
		return -1.0
	return clampf(_channel_time / _reset_channel_time(), 0.0, 1.0)

func _reset_channel_time() -> float:
	var lata := RoundManager.lata
	return lata.reset_channel_time() if lata != null else Lata.RESET_CHANNEL_TIME

## ---------------------------------------------------------------------------
## THE FRAME. Order matters: `grab` gets first refusal on an E press, then the
## channel, and only a press neither of them consumed reaches the shove in
## `character_base.gd`.
## ---------------------------------------------------------------------------

func input_step(delta: float) -> void:
	held() # prunes a stale reference before anything reads it
	_step_grab()
	_step_reset_channel(delta)
	_step_throw(delta)

func _step_grab() -> void:
	if _held != null or not _character.input_just_pressed("grab"):
		return
	if _character.is_defender:
		return
	var target := _find_grabbable()
	if target == null:
		return
	# ⚠⚠ BROADCAST, NOT LOCAL. 🧑 2026-08-01: *"make sure theres an animation for
	# all hand movements even shove or tag or anything"*. This was
	# `play_visual_action`, which plays the clip on THIS MACHINE ONLY — so the
	# one moment an attacker is committed and vulnerable, bending down for their
	# slipper inside the box, was invisible to the taya trying to read it. The
	# same reason `broadcast_visual_action` exists for the throw and the shove.
	_character.broadcast_visual_action("grab")
	_request_grab(target)

## ⚠️ NEAREST, NOT FIRST. Three attackers converge on one box and slippers land in
## a pile; picking whichever happened to be earlier in the tree makes the pickup
## feel like it has a mind of its own.
func _find_grabbable() -> Slipper:
	var best: Slipper = null
	var best_distance := PICKUP_RADIUS
	for node in _character.get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null or not slipper.can_be_grabbed_by(_character):
			continue
		var distance := _character.global_position.distance_to(slipper.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = slipper
	return best

## ⚠️ THE DEFENDER'S ONLY BUTTON. Hold E in the ring for `Lata.RESET_CHANNEL_TIME`
## and the lata goes back on its mark AND stands up. The price is that long stood
## still inside a box with three attackers in it, which is the one moment the
## offence gets to punish — so it must NOT be cancellable-and-resumable at no cost.
## Letting go zeroes it.
##
## ⚠️ THE DURATION IS QUOTED BY NAME, NOT BY VALUE, AND THAT IS THE FIX FOR §2.26.
## This comment said "2.5 s" twice while calling `Lata.RESET_CHANNEL_TIME`, which
## has been **1.5** since 2026-08-01 — three pieces of prose across three files
## described a slower game than the one that shipped. The code was always
## self-consistent; only the prose disagreed, so the prose stopped naming a number
## it does not own.
func _step_reset_channel(delta: float) -> void:
	if not _character.is_defender or _held != null:
		_cancel_channel()
		return
	if not _character.input_pressed("grab"):
		_cancel_channel()
		return
	var lata := RoundManager.lata
	if lata == null or not lata.can_be_reset_by(_character):
		_cancel_channel()
		return
	if not _channelling:
		_channelling = true
		_channel_time = 0.0
		AudioManager.play_at("reset_channel_start", _character.global_position)
	_channel_time += delta
	reset_channel_changed.emit(channel_progress())
	if _channel_time < _reset_channel_time():
		return
	_cancel_channel()
	# Broadcast for the same reason as the pickup above: standing the lata back up
	# is the taya's longest commitment and every attacker needs to see it happen.
	_character.broadcast_visual_action("grab")
	_request_reset()

func _cancel_channel() -> void:
	if not _channelling:
		return
	_channelling = false
	_channel_time = 0.0
	reset_channel_changed.emit(-1.0)

func _step_throw(delta: float) -> void:
	if _held == null:
		_cancel_charge()
		return
	# ⚠️ `input_pressed`, NOT `input_just_pressed` — see the header.
	if not _is_charging and _character.input_pressed("special_ability"):
		if not RoundManager.can_throw(_character):
			return
		if _throw_lock_left > 0.0:
			return
		_is_charging = true
		_charge_time = 0.0
		_broadcast_charge(true)
		AudioManager.play_at("throw_charge", _character.global_position)
	elif _is_charging and _character.input_pressed("special_ability"):
		_charge_time = minf(_charge_time + delta, CHARGE_FULL_TIME)
		charge_changed.emit(charge_power())
		_update_trajectory()
		# Stepping out of legality mid-charge cancels it rather than banking it.
		if not RoundManager.can_throw(_character):
			_cancel_charge()
	elif _is_charging:
		var power := charge_power()
		_cancel_charge()
		if RoundManager.can_throw(_character):
			_character.broadcast_visual_action("throw")
			_request_throw(power)

func _cancel_charge() -> void:
	if not _is_charging:
		return
	_is_charging = false
	_charge_time = 0.0
	charge_changed.emit(0.0)
	_broadcast_charge(false)
	if _trajectory != null:
		_trajectory.clear()

func _broadcast_charge(active: bool) -> void:
	if NetworkManager.is_networked():
		_rpc_charge_visual.rpc(active)
	else:
		_rpc_charge_visual(active)

@rpc("any_peer", "call_local", "reliable")
func _rpc_charge_visual(active: bool) -> void:
	_observed_charge_time = 0.0 if active else -1.0

## ---------------------------------------------------------------------------
## AIM. Both of these are load-bearing; see the header.
## ---------------------------------------------------------------------------

func _aim_direction() -> Vector3:
	var rig := _character.get_node_or_null("CameraRig") as CameraRig
	if rig != null:
		return -rig.get_aim_basis().z
	return -_character.global_transform.basis.z

func _aim_point() -> Vector3:
	# ⚠️ AN AI AIMS AT A POINT IT WAS TOLD, NOT DOWN A CAMERA (B-125). A
	# non-mouse-aimed unit's camera follows its body, and its body yaw is the
	# direction it last WALKED, so the whole cast resolves to "wherever I was
	# heading". Measured over 20 AI rounds, throws that reached the can: 0.
	if _character.is_ai_driven() and _character.ai_aim_point != Vector3.INF:
		return _character.ai_aim_point
	var origin := _character.global_position
	var direction := _aim_direction()
	var rig := _character.get_node_or_null("CameraRig") as CameraRig
	if rig != null and rig.fpp_camera != null:
		origin = rig.fpp_camera.global_position
	var space := _character.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * AIM_RAY_LENGTH)
	query.exclude = [_character.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return origin + direction * AIM_RAY_LENGTH
	return hit["position"]

func _throw_origin() -> Vector3:
	var rig := _character.get_node_or_null("CameraRig") as CameraRig
	if rig == null or rig.fpp_camera == null:
		return _character.global_position + Vector3.UP * 0.9
	return rig.fpp_camera.global_position + _aim_direction() * MUZZLE_FORWARD

## The same origin, for a caller that has an aim POINT rather than a live aim
## direction. ⚠️ EXISTS SO THE PROBES AND THE GAME CANNOT LAUNCH FROM DIFFERENT
## PLACES — three probes were each about to grow their own copy of this, one with
## the eye height typed in as a literal.
static func throw_origin_for(thrower: CharacterBase, aim_point: Vector3) -> Vector3:
	if thrower == null:
		return aim_point
	var rig := thrower.get_node_or_null("CameraRig") as CameraRig
	if rig == null or rig.fpp_camera == null:
		return thrower.global_position + Vector3.UP * 0.9
	var eye := rig.fpp_camera.global_position
	var to_aim := aim_point - eye
	if to_aim.length() < 0.01:
		return eye
	return eye + to_aim.normalized() * MUZZLE_FORWARD

func _ensure_trajectory() -> void:
	if _trajectory != null and is_instance_valid(_trajectory):
		return
	_trajectory = TrajectoryPreview.new()
	_character.get_tree().current_scene.add_child(_trajectory)

func _update_trajectory() -> void:
	if not _character.is_multiplayer_authority() or _character.is_ai_driven():
		return
	# ⚠️ AND THE LOCAL SCREEN HAS TO BE LOOKING THROUGH THIS CHARACTER. 🧑
	# 2026-08-01: *"make sure that only first person sees that, dont show it for
	# others"*. The authority gate above is per-peer, so networked play was already
	# right — but it is NOT right in a single-process session, where every character
	# reports authority and four aiming arcs can be on screen at once, nor for a
	# spectator, who is active in TPP and should not be shown somebody's aim line.
	var rig := _character.get_node_or_null("CameraRig") as CameraRig
	if rig == null or not rig.is_local_fpp():
		if _trajectory != null and is_instance_valid(_trajectory):
			_trajectory.clear()
		return
	_ensure_trajectory()
	var origin := _throw_origin()
	# ⚠️ `CharacterBase.GRAVITY` PLAIN — the per-profile `gravity_scale` is deleted
	# with the profiles, so the preview and the flight now share one constant
	# rather than two agreeing lookups.
	#
	# ⚠️ AND THE HELD SLIPPER'S OWN SPEED SCALE IS PASSED THROUGH (§2.8). The whole
	# reason `launch_velocity_for()` is shared with `slipper.gd::host_throw()` is
	# that the aim line and the flight line are then one line BY CONSTRUCTION
	# (`Design.md` §12). A per-skin launch speed applied to only one of them would
	# have quietly broken that and re-opened §2.16 — the dotted arc would land
	# where a neutral slipper lands and the real one would land 5% away.
	_trajectory.draw_arc(origin,
		Slipper.launch_velocity_for(origin, _aim_point(), charge_power(),
			_held.speed_scale()),
		CharacterBase.GRAVITY, UiTheme.OFFENSE, _held.rest_height())

## ---------------------------------------------------------------------------
## HOST HANDOFF. Clients ASK, the host DECIDES, the host BROADCASTS — the same
## contract every other action in the game keeps.
## ---------------------------------------------------------------------------

func _request_grab(target: Slipper) -> void:
	if not NetworkManager.is_networked() or NetworkManager.is_host():
		target.host_grab(_character)
		return
	_rpc_request_grab.rpc_id(1, target.get_path())

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_grab(target_path: NodePath) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var target := get_node_or_null(target_path) as Slipper
	if target != null:
		target.host_grab(_character)

func _request_throw(power: float) -> void:
	var slipper := held()
	if slipper == null:
		return
	var origin := _throw_origin()
	var point := _aim_point()
	if not NetworkManager.is_networked() or NetworkManager.is_host():
		slipper.host_throw(_character, origin, point, power)
		return
	_rpc_request_throw.rpc_id(1, slipper.get_path(), origin, point, power)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_throw(target_path: NodePath, origin: Vector3, point: Vector3,
		power: float) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var target := get_node_or_null(target_path) as Slipper
	if target != null:
		target.host_throw(_character, origin, point, clampf(power, 0.0, 1.0))

func _request_reset() -> void:
	if not NetworkManager.is_networked() or NetworkManager.is_host():
		if RoundManager.lata != null:
			RoundManager.lata.host_restore()
		return
	_rpc_request_reset.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_reset() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var lata := RoundManager.lata
	if lata != null and lata.can_be_reset_by(_character):
		lata.host_restore()

## ---------------------------------------------------------------------------
## STATE FROM THE SLIPPER'S SIDE.
## ---------------------------------------------------------------------------

## Called by `slipper.gd` on both halves of the relationship.
## ⚠️ THE LOCK IS DIVIDED BY THE SLIPPER'S OWN GRIT (§2.8), and this is the stat
## that plays the game's actual thesis — `Design.md` §0: *"the tension is the
## retrieval, not the throw"*. A slipper that is ready sooner shortens the one
## window in which its owner is standing inside the box and taggable, so GRIT buys
## exposure back rather than buying damage. PANTULOG (tatag 5) is armed in 1.03 s
## against CROCS (tatag 2) at 1.42 s, either side of the neutral 1.25.
func notify_holding(what: Slipper) -> void:
	_set_held(what)
	if what != null:
		_throw_lock_left = THROW_LOCK_TIME / what.grit_scale()

func _set_held(what: Slipper) -> void:
	if _held == what:
		return
	_held = what
	held_changed.emit(what)

func reset_for_new_round() -> void:
	_cancel_charge()
	_cancel_channel()
	_set_held(null)
	_throw_lock_left = 0.0
	_observed_charge_time = -1.0
	if _trajectory != null and is_instance_valid(_trajectory):
		_trajectory.clear()
