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
## ⚠️⚠️ § THE GRAB-SHOVE DOUBLE-FIRE. 🧑 2026-08-06: *"when trying to pick up a slipper,
## it accidentally triggers shove since both keybind is left click."*
##
## Not a keybind collision — `grab` and `special_ability` sharing LMB is a DIFFERENT,
## already-documented trade-off (§4.19). This is `is_busy()`'s own contract going
## unmet: its doc already says it exists *"so `character_base.gd::_step_shove` knows an
## E press was already spent on something else"*, and `_step_grab()` never told it.
## A throw charge sets `_is_charging`; the reset channel sets `_channelling`; a grab
## fires `_request_grab()` and sets NEITHER, because picking something up has no
## multi-frame state to hold — it is one RPC and done. So on the exact frame a grab
## connects, `is_busy()` still read false, `_step_shove()`'s guard let the frame
## through, and `input_just_pressed("grab")` was — correctly — still true for anyone
## ELSE reading it that frame, because Godot's polled input has no notion of a value
## being "consumed" by the first reader. Bending to pick up a slipper also threw a
## shove: burning cooldown and stamina, and shoving anyone standing in front.
##
## One-frame flag, not a third addition to `is_busy()`'s two persistent ones — a grab
## has nothing to stay busy WITH once the request is sent, so it only needs to say
## "already spent" for the remainder of the frame it fired on. Reset at the top of
## every `input_step()`, so a later frame's `grab` press (rebind, re-press, whatever)
## is never shadowed by an old one.
var _grab_consumed_this_frame: bool = false
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
##
## ⚠️ `_grab_consumed_this_frame` IS THE THIRD CASE, ADDED FOR § THE GRAB-SHOVE
## DOUBLE-FIRE — see that var's own note. The other two are held across several
## frames; this one is true for exactly the frame a grab connected on.
func is_busy() -> bool:
	return _is_charging or _channelling or _grab_consumed_this_frame

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
	# ⚠️ CLEARED HERE, ONCE, BEFORE `_step_grab()` CAN SET IT — see § THE GRAB-SHOVE
	# DOUBLE-FIRE at the var's declaration. A flag that lived past this frame would
	# shadow a later, unrelated `grab` press instead of only the one that set it.
	_grab_consumed_this_frame = false
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
	# ⚠️ SET AFTER THE PICKUP IS ALREADY COMMITTED, NOT AS A GATE ABOVE. § THE
	# GRAB-SHOVE DOUBLE-FIRE. This is the whole fix: `_step_shove()` runs immediately
	# after this function returns and reads `is_busy()` before re-reading the same
	# `input_just_pressed("grab")` this frame — so a connecting grab now shows up as
	# "already spent" and the shove refuses to fire on top of it.
	_grab_consumed_this_frame = true

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
	# ⚠️ `is_multiplayer_authority()` ALONE LIES IN ONE SEQUENCE: SINGLE PLAYER,
	# AFTER A LAN/ONLINE MATCH IN THE SAME PROCESS. `NetworkManager.disconnect_network()`
	# (and its failure/disconnect siblings) tear a session down with
	# `multiplayer.multiplayer_peer = null` rather than restoring the engine's own
	# offline default, so `multiplayer.get_unique_id()` stops returning 1 for the
	# rest of the process's life even though this character's own
	# `multiplayer_authority` is still 1 and `NetworkManager.is_networked()`
	# correctly reports false. Same fix, same shape, as
	# `character_base.gd::try_emote()`'s own note.
	var is_mine := _character.is_multiplayer_authority() if NetworkManager.is_networked() \
		else _character.player_id == 1
	if not is_mine or _character.is_ai_driven():
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
	var target := _resolve_slipper(target_path)
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
	var target := _resolve_slipper(target_path)
	if target != null:
		target.host_throw(_character, origin, point, clampf(power, 0.0, 1.0))

## ---------------------------------------------------------------------------
## ⚠️⚠️ WHICH SLIPPER THE ASKER MEANT — RESOLVED BY **NODE NAME**, NOT BY THE PATH ON THE
## WIRE. THIS IS THE FIX FOR 🧑 2026-08-04: *"still cant throw on rejoin.. i have the throw
## animation and chargup now but it doesnt actually throw."*
##
## THE TWO REQUESTS ABOVE NAME THEIR TARGET WITH `slipper.get_path()`, AND FOR A **CARRIED**
## SLIPPER THAT PATH IS PER-PEER. `slipper.gd::_attach_to_hand()` re-parents a held tsinelas
## onto `<body>/Visual/<model root>/Skeleton3D/HandAttachment/HandPoint`, and `<model root>`
## is whichever rig THAT peer's `CharacterVisual` happened to instance. Two peers that
## disagree about the model disagree about the path, `get_node_or_null()` answers null on the
## host, and `_rpc_request_throw` returns without a word: the client charges, plays its throw
## clip, and the prop never moves. Silent on both machines, which is why it reads to a player
## as *"it just doesn't throw"*.
##
## ⚠️ THAT DISAGREEMENT IS A REAL, STILL-OPEN, DOCUMENTED STATE — see `character_base.gd`'s
## `character_index` note (the withdrawn repaint setter). A peer that took over a bot's seat
## mid-match keeps the BOT's face on every process that did not reload `Main.tscn`, the host
## included, while the peer that DID reload instances its own pick. Measured 2026-08-04,
## `run_rejoin.ps1 -Scenario latecomer`, the same Slipper3 in the same hand on the same
## frame:
##
##     host   .../Players/863342991/Visual/character-female-a2/character-female-a/...
##     client .../Players/863342991/Visual/character-female-e2/character-female-e/...
##
## with `THROW GATE ... can_throw=true`, `charged=true`, and the slipper still reading
## `state=1 carrier=863342991 travelled=0.72` a second after the release — on the host, on
## the anchor and on the thrower alike.
##
## ⚠️ THE PICKUP KEPT WORKING THROUGHOUT, AND THAT IS THE TELL RATHER THAN A COINCIDENCE. A
## grab always targets a LOOSE slipper, which is sitting at the home path every peer has had
## since the scene loaded; only the throw names a node that has been re-parented. Both are
## routed through here anyway, because the grab's immunity is a property of the game's
## current rules and not of this message.
##
## ⚠️ THE `@rpc` NAMES AND SIGNATURES ARE UNCHANGED, SO NO LOCKSTEP REDEPLOY IS NEEDED.
## Godot checksums a node's RPC method list; adding or re-typing a parameter here would make
## every deployed dedicated server fail the handshake with *"the rpc node checksum failed"*.
## The wire format still carries the full `NodePath` — an older client's packet resolves
## through the same fallback, and a newer client's through an older host exactly as well (or
## as badly) as it does today.
##
## ⚠️ THE NAME IS THE STABLE IDENTITY AND THE PATH IS NOT. `Slipper1/2/3` are authored
## directly in `Main.tscn`, so every peer has the same three names for the whole match, and a
## node keeps its name through any number of re-parents. It is the same reasoning `main.gd`'s
## § SLIPPER RPCs block already applied to the BROADCAST half with `slipper_index` — that fix
## routed the host's outbound messages through `Main` and re-dispatched them by a plain int,
## and simply never covered the two inbound REQUESTS, because their target is an ARGUMENT
## rather than the RPC's own delivery address.
##
## ⚠️ THE DIRECT LOOKUP IS TRIED FIRST, so a peer whose paths do agree costs one
## `get_node_or_null` and nothing else. The group scan is three comparisons and only runs on
## the path that used to fail outright.
## ---------------------------------------------------------------------------
func _resolve_slipper(target_path: NodePath) -> Slipper:
	var direct := get_node_or_null(target_path) as Slipper
	if direct != null:
		return direct
	var parts := target_path.get_name_count()
	if parts == 0:
		return null
	# `add_to_group("slippers")` happens in `Slipper._ready()` and survives re-parenting,
	# so this reaches a held slipper as readily as a loose one — unlike the path above.
	var wanted := target_path.get_name(parts - 1)
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper != null and slipper.name == wanted:
			return slipper
	return null

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
## exposure back rather than buying damage. PANTULOG (tatag 5) is armed in 1.10 s
## against CROCS (tatag 2) at 1.34 s, either side of the neutral 1.25.
##
## ⚠️ THOSE TWO NUMBERS READ 1.03 AND 1.42 UNTIL 2026-08-02 AND WERE NEVER RIGHT.
## `THROW_LOCK_TIME / trait_scale(points, 0.07)` is 1.25/1.14 and 1.25/0.93; the
## old pair would need about 0.107 per point. Nothing was wrong with the CODE —
## the comment was quoting a per-point constant the game does not use, which is
## the failure mode a hand-copied number always has. `tools/trait_probe.gd`
## measures the real locks off `Carrier` itself if they ever need checking again.
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
