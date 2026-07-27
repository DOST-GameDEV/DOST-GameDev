extends Node
class_name Carrier

## What a Person's hands are doing — the other half of the Task 0 / Option B
## mechanic. `carriable.gd` is the slipper's side; this is the side that picks it
## up, aims it and throws it.
##
## Lives as a child of every CharacterBase and self-disables on anything that is
## not a Person (`is_person`), because a Prop has no hands. That check is made
## per call rather than cached: `is_can` flips every round, and while `is_person`
## does not, keeping both derivations consistent is cheaper than remembering
## which one is safe to cache.
##
## THE THROW IS THE PERSON'S, NOT THE SLIPPER'S. This is the single biggest
## behavioural change from the pre-Task-0 build, where the "Throw" was
## `person_action.gd` blinking an invisible sphere on 4 metres ahead of the
## thrower for 0.2s — nothing left anyone's hands. Now:
##
##   hold `special_ability`  → charge (the moodboard's "charged throw (glow)")
##   release                 → the slipper actually leaves the hand on an arc
##   it lands, goes LOOSE    → somebody has to go and get it
##
## `person_action.gd` keeps only its DEFENCE half (Tag). The offence half is
## this file. See that script's header.
##
## HOST-AUTHORITATIVE. Every grab and every throw is a REQUEST sent to the host,
## which validates it against the ownership rule and the current carry state
## before broadcasting the result. Nothing here mutates carry state directly,
## even on the host — it always goes through `carriable.gd`'s host_* functions so
## there is exactly one place that decides.

## Seconds of hold to reach full power. Short enough that a panicked quick throw
## is viable, long enough that a committed throw is a real decision the taya can
## read and punish.
const CHARGE_FULL_TIME: float = 0.9
## Power floor, so a tap still throws rather than dropping the slipper at your
## feet. Fraction of ThrowProfile.launch_speed.
const CHARGE_MIN_POWER: float = 0.35
## T-3: seconds of uninterrupted hold to stand a knocked-down lata back up. Long
## enough that the attacking side gets a real window to punish a taya who commits
## to it, short enough that defending is not hopeless once the can goes over.
## Pure guess until someone plays it — this is the tuning knob for the whole
## defensive half of the round.
const RESET_CHANNEL_TIME: float = 1.5

## Emitted on the local peer while charging, 0..1, for the HUD's charge meter.
## -1 means "not charging", which is a distinct state from "charging at zero".
signal charge_changed(power: float)
## Emitted when this Person picks something up or loses it, so the HUD can show
## SLIPPER READY vs GO GET IT without polling every frame.
signal held_changed(held: Carriable)
## T-3, 0..1 while the reset channel is running, -1 when it is not — same
## "-1 means not active" convention as charge_changed. Nothing consumes this yet;
## the progress bar it exists for is U-1's job, exactly as charge_changed is.
signal reset_channel_changed(progress: float)

var _character: CharacterBase = null
## What this Person is holding, or null. Mirrors `Carriable.carrier` and is set
## from the same host broadcast, so the two can never disagree.
var _held: Carriable = null
var _charge_time: float = 0.0
var _is_charging: bool = false
## T-3. The lata currently being channelled, and how far in we are.
var _channel_target: Carriable = null
var _channel_time: float = 0.0

@onready var _grab_area: Area3D = get_parent().get_node_or_null("GrabArea")

func _ready() -> void:
	_character = get_parent() as CharacterBase
	# T-3: getting tagged mid-channel has to cancel it — that is the entire
	# counterplay to a taya standing their can back up. input_step() stops being
	# called the moment this Person leaves NORMAL (see character_base.gd's
	# _physics_process gate), so without this the timer would simply freeze and
	# resume where it left off rather than resetting.
	if _character != null:
		_character.state_changed.connect(_on_own_state_changed)

func _on_own_state_changed(new_state: CharacterBase.State) -> void:
	if new_state != CharacterBase.State.NORMAL:
		_cancel_channel()

## True when this unit has hands at all. A Can or a tsinelas never grabs.
func has_hands() -> bool:
	return _character != null and _character.is_person

func held() -> Carriable:
	return _held

func is_charging() -> bool:
	return _is_charging

## 0..1 while charging, -1 otherwise.
func charge_power() -> float:
	if not _is_charging:
		return -1.0
	return clampf(CHARGE_MIN_POWER + (_charge_time / CHARGE_FULL_TIME) * (1.0 - CHARGE_MIN_POWER),
		CHARGE_MIN_POWER, 1.0)

## Called from carriable.gd's host broadcast on EVERY peer, so `_held` and
## `Carriable.carrier` are always set and cleared together. Never call this to
## "make" someone hold something — go through Carriable.host_grab().
func notify_holding(what: Carriable) -> void:
	if _held == what:
		return
	_held = what
	# A throw in progress is void the moment the thing being thrown leaves the
	# hand by any other route (round reset, a drop, the carrier being tagged).
	if what == null:
		_cancel_charge()
	held_changed.emit(_held)

## Driven from character_base.gd's _physics_process, only for the unit this peer
## actually controls — the same gate every other input read sits behind.
func input_step(delta: float) -> void:
	if not has_hands():
		return
	_step_grab()
	_step_reset_channel(delta)
	_step_throw(delta)

## ---------------------------------------------------------------------------

func _step_grab() -> void:
	if not Input.is_action_just_pressed(_character.action_name("grab")):
		return
	if _held != null:
		return # already holding; the grab button is not a drop button
	var target := _find_grabbable()
	if target == null:
		return
	# The visible half — "I want the hands to move and to actually grab". The
	# clip choice belongs to CharacterVisual, not here; this only says what
	# happened, same contract bump/throw already use.
	_character.play_visual_action("grab")
	_request_grab(target)

func _step_throw(delta: float) -> void:
	var action := _character.action_name("special_ability")
	if _held == null:
		# Nothing in hand: the button falls through to the ordinary ability path
		# in character_base.gd (Tag, on the defence side). Make sure a charge
		# left over from a slipper that was knocked out of our hands mid-hold
		# does not survive.
		_cancel_charge()
		return

	if Input.is_action_just_pressed(action):
		_is_charging = true
		_charge_time = 0.0
		charge_changed.emit(charge_power())
	elif _is_charging and Input.is_action_pressed(action):
		_charge_time = minf(_charge_time + delta, CHARGE_FULL_TIME)
		charge_changed.emit(charge_power())
	elif _is_charging and Input.is_action_just_released(action):
		var power := charge_power()
		_cancel_charge()
		_character.play_visual_action("throw")
		_request_throw(power)

## T-3 / B-46 — the lata reset channel, driver side. Hold `grab` next to your own
## knocked-down lata and it stands back up when the bar fills; anything that
## interrupts you cancels it outright, with no partial credit.
##
## Shares the `grab` button with _step_grab() without conflicting: that reads
## just_pressed and bails on anything a Person cannot pick up, and
## Carriable.can_be_grabbed_by() already refuses a Can. So a tap near a lata does
## nothing and a hold channels it.
##
## The timer runs LOCALLY, then asks the host to apply the result — deliberately
## the same split the charge-throw uses. Aim and hold duration are the player's
## own business; whether the thing may actually happen is the host's.
func _step_reset_channel(delta: float) -> void:
	if _held != null:
		# Hands full. You cannot right the can while carrying a slipper — put it
		# down, or throw it, first.
		_cancel_channel()
		return
	if not Input.is_action_pressed(_character.action_name("grab")):
		_cancel_channel()
		return

	var target := _find_resettable()
	if target == null:
		# Walked out of range, or the can stopped being resettable underneath us
		# (someone sealed it, or a teammate's channel got there first).
		_cancel_channel()
		return
	if target != _channel_target:
		# Switched cans mid-hold: start the new one from zero rather than
		# inheriting progress banked against a different target.
		_channel_target = target
		_channel_time = 0.0

	_channel_time += delta
	reset_channel_changed.emit(clampf(_channel_time / RESET_CHANNEL_TIME, 0.0, 1.0))
	if _channel_time < RESET_CHANNEL_TIME:
		return

	# Filled. Clear local state BEFORE requesting so a slow host reply cannot let
	# the same channel fire twice.
	var completed := _channel_target
	_cancel_channel()
	_character.play_visual_action("grab")
	_request_reset(completed)

func _cancel_channel() -> void:
	if _channel_target == null and _channel_time == 0.0:
		return
	_channel_target = null
	_channel_time = 0.0
	reset_channel_changed.emit(-1.0)

## The nearest lata in reach that this Person is actually allowed to stand up.
## The rule itself lives in carriable.gd — this only asks, same as
## _find_grabbable() does for pick-ups.
func _find_resettable() -> Carriable:
	if _grab_area == null:
		return null
	var best: Carriable = null
	var best_distance := INF
	for area in _grab_area.get_overlapping_areas():
		if not (area is Hurtbox):
			continue
		var other := (area as Hurtbox).owner_character
		if other == null or other == _character:
			continue
		var carriable := other.get_node_or_null("Carriable") as Carriable
		if carriable == null or not carriable.can_be_reset_by(_character):
			continue
		var distance := _character.global_position.distance_to(other.global_position)
		if distance < best_distance:
			best_distance = distance
			best = carriable
	return best

func _cancel_charge() -> void:
	if not _is_charging:
		return
	_is_charging = false
	_charge_time = 0.0
	charge_changed.emit(-1.0)

## Nearest thing in the grab area this Person is actually allowed to pick up.
## The ownership rule itself lives in carriable.gd — this only asks.
func _find_grabbable() -> Carriable:
	if _grab_area == null:
		return null
	var best: Carriable = null
	var best_distance := INF
	for area in _grab_area.get_overlapping_areas():
		if not (area is Hurtbox):
			continue
		var other := (area as Hurtbox).owner_character
		if other == null or other == _character:
			continue
		var carriable := other.get_node_or_null("Carriable") as Carriable
		if carriable == null or not carriable.can_be_grabbed_by(_character):
			continue
		var distance := _character.global_position.distance_to(other.global_position)
		if distance < best_distance:
			best_distance = distance
			best = carriable
	return best

## Where the throw goes. Taken from the CAMERA, not the body: a Person is always
## first person (the standing camera directive) and the body carries yaw only —
## pitch lives on the rig (see camera_rig.gd). Aiming off the body would throw
## flat along the floor no matter where the player was looking, which is the
## same class of bug B-05 fixed for melee.
func _aim_direction() -> Vector3:
	var rig := _character.get_node_or_null("CameraRig") as CameraRig
	if rig != null:
		return -rig.get_aim_basis().z
	return -_character.global_transform.basis.z

## ---------------------------------------------------------------------------
## Requests. On the host these call straight through; on a client they RPC to
## peer 1. Either way the decision is made in exactly one place.
## ---------------------------------------------------------------------------

func _request_grab(target: Carriable) -> void:
	if _is_host():
		target.host_grab(_character)
	else:
		_rpc_request_grab.rpc_id(1, target.get_parent().get_path())

func _request_throw(power: float) -> void:
	var direction := _aim_direction()
	if _is_host():
		_held.host_throw(direction, power)
	else:
		_rpc_request_throw.rpc_id(1, direction, power)

## T-3. Same shape as _request_grab: on the host, straight through; on a client,
## a request to peer 1. The host re-checks can_be_reset_by() from scratch — a
## client having run a timer locally proves nothing about whether the can was
## still down when the bar filled.
func _request_reset(target: Carriable) -> void:
	if target == null or not is_instance_valid(target):
		return
	if _is_host():
		target.host_reset_upright(_character)
	else:
		_rpc_request_reset.rpc_id(1, target.get_parent().get_path())

## Client → host. The host re-resolves the target from the path and re-checks
## can_be_grabbed_by() inside host_grab(); a client asserting it may grab
## something is not sufficient and is never trusted.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_grab(target_character_path: NodePath) -> void:
	if not _is_host():
		return
	var target := get_node_or_null(target_character_path) as CharacterBase
	if target == null:
		return
	var carriable := target.get_node_or_null("Carriable") as Carriable
	if carriable == null:
		return
	carriable.host_grab(_character)

## Client → host. Direction and power come from the client because they are
## aim, which is client-authoritative by the same rule that makes a peer's own
## movement client-authoritative. WHETHER the throw may happen at all, and what
## it then hits, stay with the host.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_throw(direction: Vector3, power: float) -> void:
	if not _is_host() or _held == null:
		return
	_held.host_throw(direction, clampf(power, 0.0, 1.0))

## Client → host, T-3. Mirrors _rpc_request_grab exactly, including re-resolving
## the target node from its path rather than trusting anything the client sent
## about it beyond which can it meant.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_reset(target_character_path: NodePath) -> void:
	if not _is_host():
		return
	var target := get_node_or_null(target_character_path) as CharacterBase
	if target == null:
		return
	var carriable := target.get_node_or_null("Carriable") as Carriable
	if carriable == null:
		return
	carriable.host_reset_upright(_character)

func _is_host() -> bool:
	return not NetworkManager.is_networked() or NetworkManager.is_host()
