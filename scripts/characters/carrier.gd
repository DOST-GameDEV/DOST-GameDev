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

## ---------------------------------------------------------------------------
## R-06 · THE LOB (`bagsak`) — seconds of hold PAST full power at which the throw
## stops being a flat rifle shot and becomes a dropping lob.
##
## ⚠️ NOT A NEW INPUT ACTION, AND THAT IS THE DESIGN, NOT A SHORTCUT. The charge
## is already an analogue hold; the lob is a REGION of it. A fourth verb on a
## four-player party game is a fifth thing to explain in the tutorial (R-06's own
## note), and the existing hold already carries a number nobody was reading:
## `_charge_time` used to be clamped flat at CHARGE_FULL_TIME, so every millisecond
## of hold past 0.9 s produced the identical throw. That surplus is the input.
##
## ⚠️ PUBLIC, AND `AIController.attacker_lob_overhold` MUST READ IT RATHER THAN
## RESTATE IT. That file shipped its half of R-06 ahead of this one and had to
## guess the threshold (`ATTACKER_LOB_OVERHOLD = 0.20`, with a note saying "the
## PHYS lane owns the real threshold ... the two have to agree or the AI will hold
## for a lob and throw a flat"). 0.20 is deliberately kept, so the two agree TODAY
## by coincidence of value; they should agree BY CONSTRUCTION, exactly as
## `_charge_fraction()` already reads CHARGE_MIN_POWER and CHARGE_FULL_TIME out of
## this file. Flagged for the balance lane — `ai_controller.gd` is not this lane's
## to write.
##
## Sized as a COMMITMENT WINDOW, not a ramp: the whole 0.20 s is the price of the
## lob, and releasing anywhere inside it still throws the ordinary full-power flat
## shot. So a player who simply holds too long is not punished with a mystery
## trajectory — they get the shot they were charging — and a player who wants the
## lob has to hold visibly, deliberately longer, which is the readability R-10
## asks of every committed throw.
const LOB_OVERHOLD_TIME: float = 0.20
## Where the hold stops accumulating at all. Past this the lob is armed and more
## hold changes nothing, so there is no hidden third region.
const CHARGE_MAX_TIME: float = CHARGE_FULL_TIME + LOB_OVERHOLD_TIME
## What `charge_changed` reports at the instant the lob arms. See charge_meter().
const LOB_METER_ARMED: float = 2.0
## T-3: seconds of uninterrupted hold to stand a knocked-down lata back up. Long
## enough that the attacking side gets a real window to punish a taya who commits
## to it, short enough that defending is not hopeless once the can goes over.
##
## ⚠️ 1.5 -> 2.2, third of the four "too easy for the lata to get back up" levers
## — the full set is documented on `CharacterBase.DOWNED_SELF_RIGHT_WINDOW`. The
## channel is the taya's ONLY commitment in the whole round: it is the one moment
## they stand still and can be tagged for it. At 1.5 s that window was shorter
## than the attacker's own charge-and-throw cycle, so there was nothing to punish
## and the reset was effectively free. 2.2 s makes going for it a decision.
##
## Still a guess until someone plays it — this is the tuning knob for the whole
## defensive half of the round.
const RESET_CHANNEL_TIME: float = 2.2

## Emitted on the local peer while charging, for the HUD's charge meter.
## -1 means "not charging", which is a distinct state from "charging at zero".
##
## ⚠️ THE RANGE IS 0..2 NOW, NOT 0..1, AND THE TOP HALF IS THE LOB (R-06). The
## signal signature is deliberately UNCHANGED — see charge_meter() for the encoding
## and for why the two existing consumers keep working untouched.
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

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE WIND-UP EVERY OTHER PEER CAN SEE. Human report, 2026-07-30: *"everyone
## else should see its windup happening."*
##
## They could not, and not by oversight — there was no path for it to travel. The
## charge lived entirely on the charging peer:
##
##   * `_charge_time` is written in `input_step()`, which `character_base.gd` calls
##     only for the character THAT PEER controls (its authority gate);
##   * `charge_changed` is a local signal consumed by `you_card.gd`, i.e. the charging
##     player's own HUD;
##   * `character_visual.gd` polls `charge_power()` to drive the FIRST-PERSON viewmodel
##     arm — which by construction only the charging player can see.
##
## So a taya had nothing to read. This file's own header calls a committed throw "a
## real decision the taya can read and punish", and R-10's whole premise is that a
## wind-up is readable; both were true only of the thrower's own screen. The rising
## charge tone (`throw_charge`, played positionally on every peer) was the ONLY cue
## anyone else got, which is why the fix was worth having and why the sound alone was
## not enough.
##
## ⚠️ BROADCAST ONCE, THEN RECOMPUTED LOCALLY — NOT STREAMED. An RPC per frame at 60 Hz
## for a cosmetic ramp is exactly what B-19 throttled `_sync_state` for. The charge
## curve is deterministic in elapsed time, so every peer starts its own clock from one
## "begin" message and arrives at the same number, which is the same idiom
## `carriable.gd::_step_carried` uses for a carried slipper ("once every peer knows WHO
## is carrying, each recomputes the transform locally") and the same one
## `_rpc_apply_scuff` uses for its timers.
##
## What is NOT built here, deliberately: the third-person POSE. `play_visual_action`
## is emitted on every peer with the kind `"charge"`, and `character_visual.gd`'s
## `ACTION_CLIPS` has no entry for it yet — that file is the visual lane's and adding
## one line to that dictionary is the whole remaining job. Until it does, this is a
## silent no-op on the body (both `play_action` and `play_viewmodel_action` skip an
## unknown clip) and the observable value below is available for it.
## ---------------------------------------------------------------------------

## Ticks on EVERY peer while this Person is observed to be charging, -1 when not.
var _observed_charge_time: float = -1.0

## The charge fraction as any peer can see it, 0..1, or -1 when this Person is not
## charging. Same curve as `charge_power()`, recomputed rather than replicated.
func observed_charge_power() -> float:
	if _observed_charge_time < 0.0:
		return -1.0
	return clampf(
		CHARGE_MIN_POWER + (_observed_charge_time / CHARGE_FULL_TIME) * (1.0 - CHARGE_MIN_POWER),
		CHARGE_MIN_POWER, 1.0)

## Whether the throw this Person is currently winding up would be a lob — visible to
## every peer, so a defender can read "that one is going over you" and move.
func observed_lob_armed() -> bool:
	return _observed_charge_time >= CHARGE_MAX_TIME

## Runs on every peer, unlike input_step(). Only the observed clock is ticked here;
## the authoritative `_charge_time` stays where the input is read.
func _physics_process(delta: float) -> void:
	if _observed_charge_time >= 0.0:
		_observed_charge_time = minf(_observed_charge_time + delta, CHARGE_MAX_TIME)

## Told to every peer at the START of a charge and again when it ends, by any route —
## released, cancelled, tagged out of our hands, round reset.
func _broadcast_charge(active: bool) -> void:
	if NetworkManager.is_networked():
		_rpc_charge_visual.rpc(active)
	else:
		_rpc_charge_visual(active)

## "any_peer" / "call_local" for the reason every broadcast in carriable.gd documents:
## this is sent by the charging peer, which is not necessarily this node's authority as
## far as any given receiver is concerned, and an "authority" RPC would be dropped.
@rpc("any_peer", "call_local", "reliable")
func _rpc_charge_visual(active: bool) -> void:
	_observed_charge_time = 0.0 if active else -1.0
	if _character == null:
		return
	# Cosmetic only, and the same contract bump/throw/grab already use: this says WHAT
	# happened and CharacterVisual decides what it looks like.
	_character.play_visual_action("charge" if active else "throw")

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

## What this Person is holding, or null.
##
## ⚠️ SELF-HEALING, AND THAT IS THE POINT — do not "simplify" it back to
## `return _held`.
##
## `_held` and `Carriable.carrier` are two halves of one fact, set together from
## one host broadcast. When they drift, the failure is silent, permanent and
## invisible in the place you would look for it: `camera_rig.gd::_apply_carried_
## self_hide()` keeps the held unit's `Visual` hidden for as long as THIS reports
## something, so a stale value makes the slipper disappear on that player's
## machine and nothing in the rendering code is wrong. It also locks this Person
## out of grabbing (`_step_grab`) and out of the lata reset channel
## (`_step_reset_channel`) for the rest of the match.
##
## That exact drift shipped for more than ten sessions via
## `Carriable.reset_for_new_round()`, which cleared its own `carrier` and never
## told this node — see that function's note. It is fixed at the source; this
## check exists so the NEXT path that forgets cannot reintroduce it, because the
## symptom is far too indirect to be found again cheaply.
##
## Cheap enough to sit in a per-frame getter: one validity test and one pointer
## compare, no allocation, no tree walk.
func held() -> Carriable:
	if _held != null and (not is_instance_valid(_held) or _held.carrier != _character):
		notify_holding(null)
	return _held

func is_charging() -> bool:
	return _is_charging

## 0..1 while charging, -1 otherwise.
##
## ⚠️ LAKAS IS DELIBERATELY *NOT* APPLIED HERE. This is what the HUD charge meter
## and the first-person wind-up both read, and a meter that fills past its own
## bar (or never reaches the end of it) reads as broken rather than as a stat.
## The trait is applied once, at the moment of release, in `_request_throw()` —
## so a strong thrower's full bar simply carries further than a weak one's full
## bar, which is the thing being modelled.
## ⚠️ STILL CLAMPED TO 1.0 WITH THE LOB REGION IN PLAY, and that is required, not
## incidental: this is what the throw's SPEED is scaled by (`host_throw` clamps it
## again) and what the viewmodel wind-up reads. A lob is not a harder throw — it is
## the same speed on the other root of the same arc — so letting this exceed 1.0
## would silently make the lob a power buff as well as a trajectory, which is
## exactly the "strictly better shot" R-06 forbids.
func charge_power() -> float:
	if not _is_charging:
		return -1.0
	return clampf(CHARGE_MIN_POWER + (_charge_time / CHARGE_FULL_TIME) * (1.0 - CHARGE_MIN_POWER),
		CHARGE_MIN_POWER, 1.0)

## R-06. How far into the lob commitment window this hold has got, 0..1. 0 for the
## whole of the ordinary charge, 1 when the lob is armed. -1 when not charging, the
## same convention every other read in this file uses.
func lob_progress() -> float:
	if not _is_charging:
		return -1.0
	if LOB_OVERHOLD_TIME <= 0.0:
		return 1.0 if _charge_time >= CHARGE_FULL_TIME else 0.0
	return clampf((_charge_time - CHARGE_FULL_TIME) / LOB_OVERHOLD_TIME, 0.0, 1.0)

## R-06. True when releasing RIGHT NOW throws a `bagsak` lob rather than a flat
## shot. This is the one question the throw itself asks — read it before
## `_cancel_charge()`, which zeroes the timer it depends on.
func is_lob_armed() -> bool:
	return _is_charging and _charge_time >= CHARGE_MAX_TIME

## ⚠️ WHAT `charge_changed` CARRIES, AND WHY IT IS ONE FLOAT AND NOT TWO ARGUMENTS.
##
## R-06 asks for the lob region to be surfaced "in the existing charge signal" so
## the HUD and the viewmodel can show it. Widening the signal to
## `charge_changed(power, lob)` is the obvious way and it is the wrong one: the only
## consumer, `you_card.gd::_on_charge_changed(power: float)`, takes one argument, and
## a Godot signal emitted with more arguments than its callable accepts throws
## *"Method expected 1 arguments, but called with 2"* on every single emit. That file
## belongs to the UX lane, so widening here would break a file this lane may not fix.
##
## So the region rides the value instead, monotonically, in one number:
##
##     -1.0            not charging
##     0.35 .. 1.0     the ordinary charge, exactly as before
##     1.0  .. 2.0     inside the lob commitment window, filling
##     2.0             the lob is ARMED — release now and it lobs
##
## ⚠️ AND IT IS BACKWARD COMPATIBLE ON BOTH CONSUMERS, CHECKED RATHER THAN ASSUMED.
## `you_card.gd` does `charge_bar.value = power * charge_bar.max_value`, and a
## `ProgressBar` clamps its own value — so the meter "fills and stops rather than
## overflowing", which is what R-06's written spec asks for in those words.
## `camera_rig.gd::set_viewmodel_charge` already does `clampf(power, 0.0, 1.0)`, so
## the arm reaches full cock and holds. Neither file needs a line changed, and a HUD
## lane that WANTS to draw the lob segment now has the number to draw it from.
func charge_meter() -> float:
	if not _is_charging:
		return -1.0
	return charge_power() + lob_progress() * (LOB_METER_ARMED - 1.0)

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
	# Through the getter, not the field, so the drift check in held() runs before
	# any of the three steps below reads `_held` directly. Without this the
	# self-heal would only fire for the camera rig, which polls held() — and the
	# half of the bug that locks a Person out of grabbing forever would survive.
	held()
	_step_grab()
	_step_reset_channel(delta)
	_step_throw(delta)

## ---------------------------------------------------------------------------

func _step_grab() -> void:
	if not _character.input_just_pressed("grab"):
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
	# Per-character read, not the global Input singleton — see
	# character_base.gd::input_pressed for why the AI cannot use `Input`.
	if _held == null:
		# Nothing in hand: the button falls through to the ordinary ability path
		# in character_base.gd (Tag, on the defence side). Make sure a charge
		# left over from a slipper that was knocked out of our hands mid-hold
		# does not survive.
		_cancel_charge()
		return

	if _character.input_just_pressed("special_ability"):
		_is_charging = true
		_charge_time = 0.0
		charge_changed.emit(charge_meter())
		# Tell every other peer a wind-up has started — see _broadcast_charge.
		_broadcast_charge(true)
		# 4.1. This file's own header calls a committed throw "a real decision
		# the taya can read and punish" — until now it was readable only if the
		# taya happened to be looking straight at the attacker's arm. The rising
		# charge tone is what makes it readable from behind the can.
		AudioManager.play_at("throw_charge", _character.global_position)
	elif _is_charging and _character.input_pressed("special_ability"):
		# R-06: CHARGE_MAX_TIME, not CHARGE_FULL_TIME. The extra LOB_OVERHOLD_TIME
		# past full power is the lob's entire input surface — this one word is what
		# makes the surplus hold mean something instead of being discarded.
		_charge_time = minf(_charge_time + delta, CHARGE_MAX_TIME)
		charge_changed.emit(charge_meter())
	elif _is_charging and _character.input_just_released("special_ability"):
		var power := charge_power()
		# ⚠️ BEFORE _cancel_charge(), which zeroes `_charge_time` — the whole basis
		# of the answer.
		var lob := is_lob_armed()
		_cancel_charge()
		# `_broadcast_charge(false)` inside _cancel_charge() already plays the throw
		# follow-through on every peer, so this is not repeated here.
		_request_throw(power, lob)

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
	if not _character.input_pressed("grab"):
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
		# 4.1. The wind-up, at the START of the channel. Its completion sound
		# lives in carriable.gd::_rpc_apply_reset, on the host-validated result —
		# this one is local and speculative on purpose, because it is the
		# feedback that says "you are holding the right button in the right
		# place" and it is worth nothing if it is not immediate.
		AudioManager.play_at("reset_channel_start", _character.global_position)

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

## ⚠️ EVERY exit from a charge comes through here — released, cancelled, the slipper
## knocked out of our hands mid-hold, a round reset — which is exactly why the "the
## wind-up is over" broadcast belongs here and not at the release site. A pose left
## running on a Person who was tagged mid-charge is the mirror image of the invisible
## wind-up: wrong on every screen except the one that knows.
func _cancel_charge() -> void:
	if not _is_charging:
		return
	_is_charging = false
	_charge_time = 0.0
	charge_changed.emit(-1.0)
	_broadcast_charge(false)

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

## How far along the crosshair to look for something to aim AT, before giving up
## and treating the aim as a bearing rather than a target.
const AIM_RAY_LENGTH: float = 40.0

## ⚠️ THE POINT THE CROSSHAIR IS ON, NOT THE DIRECTION IT POINTS. This is the
## whole of "the throw should be aligned with the crosshair", and the two are
## not the same thing — which is why aligning the direction did not fix it.
##
## Measured, 2026-07-29, standing on the 6.0 throwing line:
##   * the slipper leaves the HAND at y 0.89 while the camera eye is at y 1.35,
##     so a throw parallel to the look direction starts 0.46 m below the line
##     the player is sighting along and only ever diverges from there;
##   * with the launch merely parallel to the aim, crosshair and landing point
##     agree at exactly ONE distance — aiming at a point 7.04 m out landed
##     1.70 m SHORT, aiming at one 3.38 m out landed 1.47 m LONG.
## No amount of tilting the launch direction fixes that, because the error is a
## function of range. Solving for the launch angle that actually passes through
## this point does (see carriable.gd::host_throw).
##
## Ray, not a plane intersection, so the aim point is a real surface — the can,
## the floor, a wall — rather than an arbitrary distance along the look vector.
## Falls back to a far point along the aim when the ray hits nothing, which
## host_throw() then treats as out of range and throws as a plain bearing.
func _aim_point() -> Vector3:
	# ⚠️ AN AI AIMS AT A POINT IT WAS TOLD, NOT DOWN A CAMERA (B-125). The ray
	# below is right for a human and wrong for a bot: a non-mouse-aimed unit's
	# camera follows its body, and its body yaw is the direction it last WALKED,
	# so the whole cast resolves to "wherever I was heading". Measured over 20
	# AI-vs-AI rounds, throws that reached the can: 0. See
	# CharacterBase.ai_aim_point for the full note and who writes it.
	if _character.is_ai_driven() and _character.ai_aim_point != Vector3.INF:
		return _character.ai_aim_point
	var origin := _character.global_position
	var direction := _aim_direction()
	var rig := _character.get_node_or_null("CameraRig") as CameraRig
	if rig != null and rig.fpp_camera != null:
		# Cast from the CAMERA: the crosshair is a screen-space thing and the
		# camera is the only node that knows where it is pointing from.
		origin = rig.fpp_camera.global_position
	var space := _character.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * AIM_RAY_LENGTH)
	# Never aim at yourself or at the slipper currently in your own hand.
	query.exclude = [_character.get_rid()]
	if _held != null and _held.get_parent() is CharacterBase:
		query.exclude = [_character.get_rid(), (_held.get_parent() as CharacterBase).get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return origin + direction * AIM_RAY_LENGTH
	return hit["position"]

## ---------------------------------------------------------------------------
## Requests. On the host these call straight through; on a client they RPC to
## peer 1. Either way the decision is made in exactly one place.
## ---------------------------------------------------------------------------

func _request_grab(target: Carriable) -> void:
	if _is_host():
		target.host_grab(_character)
	else:
		_rpc_request_grab.rpc_id(1, target.get_parent().get_path())

## Sends the aim POINT rather than the aim direction — see _aim_point() for why.
## The raycast has to happen on the peer that owns the camera, so the point is
## resolved here and travels; the host still owns whether the throw happens and
## how it flies.
##
## ⚠️ `lob` TRAVELS WITH THE THROW AND IS NEVER RE-DERIVED AT THE FAR END (R-06).
## `power` clamps at 1.0, so a full-power flat throw and a lob are INDISTINGUISHABLE
## by the time the host sees them — inferring "it was a lob" from the power value is
## not merely fragile, it is impossible. The bool is the only carrier of a decision
## that was made on the aiming peer, which is the same split aim itself already
## uses: the client owns what it meant, the host owns whether it may happen.
func _request_throw(power: float, lob: bool) -> void:
	var target_point := _aim_point()
	# LAKAS, applied once, at release — see charge_power()'s own note for why it is
	# not baked into the meter. `host_throw()` clamps to 0..1 on the host, so a
	# strong thrower cannot exceed the profile's own launch speed; what the trait
	# buys is reaching full power from a shorter hold, which is exactly "stronger".
	var thrown_power := clampf(power * _character.trait_power_scale(), 0.0, 1.0)
	if _is_host():
		_held.host_throw(target_point, thrown_power, lob)
	else:
		_rpc_request_throw.rpc_id(1, target_point, thrown_power, lob)

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
## `lob` defaults false so an older peer's two-argument call still resolves to the
## flat throw that peer meant, rather than failing the RPC outright.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_throw(target_point: Vector3, power: float, lob: bool = false) -> void:
	if not _is_host() or _held == null:
		return
	_held.host_throw(target_point, clampf(power, 0.0, 1.0), lob)

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
