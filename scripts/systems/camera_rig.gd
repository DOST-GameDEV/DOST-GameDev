extends Node3D
class_name CameraRig

## Standing directive (docs/Handoff.md §1, docs/Dev_Plan.md §0.1): Person is
## ALWAYS first-person, Prop (Can/Slipper) is ALWAYS third-person. Mode is
## DERIVED from CharacterBase.is_person at _ready() — no export, no toggle,
## no per-map override, so it cannot drift. Instanced as a child of
## CharacterBase.tscn; see that scene for the sibling `Visual` node this
## hides in FPP.
##
## Yaw lives on the body, pitch lives on the rig: this script writes
## `_character.rotation.y` for mouse-driven yaw, and never touches the body's
## rotation.x. The melee Hitbox and every directional ability use
## `-transform.basis.z`/local offsets, so tilting the body would tilt hitboxes
## into the floor. `character_base.gd` already writes rotation.y itself via
## look_at() on the movement vector when this rig's aim_source is MOVEMENT
## (every unit that isn't locally mouse-controlled) — this script only takes
## over yaw when aim_source is MOUSE, for exactly the one unit a peer
## actually controls with a mouse.

## ⚠️ TPP rig geometry — do not "correct" the baked transforms in CameraRig.tscn
## without re-reading this. `SpringArm3D` pushes its children along its own
## LOCAL **+Z**, not -Z. The character faces -Z (Godot convention, and what
## `character_base.gd`'s `look_at()` writes), so the arm must carry pitch ONLY:
## `rotation_degrees = (-15, 0, 0)` gives a local +Z of (0, +0.259, +0.966) —
## behind and above the character — and its -Z is then already "forward and 15°
## down", which is exactly where the camera should look, so `TppCamera` carries
## no rotation of its own.
##
## ⚠️ FPP eye height — also measured, do not restore the old 1.55. `FppPivot`
## sat at `y = 1.55` from the day the rig was written, which was a guess at
## "eye height on a 1.6-unit capsule" and never checked against a model. The
## Person is a Kenney Mini Character scaled by `CharacterVisual.PERSON_SCALE`
## (2.38) and dropped to the capsule floor, so in CharacterBase-local space the
## body actually occupies:
##
##     feet / body-mesh   -0.800 .. +0.076
##     head-mesh          +0.017 .. +0.798      <- top of the head is +0.798
##
## `y = 1.55` therefore parked the camera **0.75 units above the top of its own
## head**, looking out over it. That is why first person showed no body, no
## arms, and nothing held: the whole character was below the near edge of the
## frame. `0.45` is 55% of the way up the head mesh — the eye line on a model
## whose face is painted on the front of a ball head — and the head is already
## hidden in FPP by `_apply_fpp_self_hide` below, so sitting inside it is
## correct rather than a clipping problem. Re-measure with the harness in
## `docs/Agent_Prompts.md` before changing it again.
##
## The original bake was arm `(-15, 180, 0)` + camera `(0, 180, 0)`. The 180 on
## the arm assumed the spring cast along -Z, so it actually placed the camera
## 4.35 units IN FRONT of the character; the compensating 180 on the camera then
## aimed it further forward and 15° UP. Net result: the camera looked away from
## its own character into empty sky, which is what shipped. Measured as
## `forward · (character - camera) = -0.972` (it should be ≈ +1). Comments can't
## live in a .tscn — the editor strips them on save — so the warning lives here.
enum Mode { FPP, TPP }
enum AimSource { MOUSE, MOVEMENT }

const PITCH_MIN_DEG: float = -80.0
const PITCH_MAX_DEG: float = 70.0
## Degrees of rotation per pixel of mouse motion. item 14 (SettingsManager
## sensitivity slider) multiplies this by a user-configurable scalar; until
## that lands, every mouse-aimed rig uses this flat default.
const BASE_SENSITIVITY: float = 0.15
## B-73: which mesh to drop in first person. Matched as a lowercase substring of
## the node name, so Kenney's `head-mesh` is caught across the whole 12-model
## roster without naming each one.
const FPP_HIDDEN_MESH_HINT: String = "head"

## Playtest 0.4: "don't see arms of ppl". The rig's real arms are NOT hidden —
## B-73 already drops only `head-mesh` — they are simply out of frame. Measured:
## `body-mesh` tops out at CharacterBase-local +0.076 while the FPP eye sits at
## +0.450, so the whole body hangs 0.37 below the camera and the arm bone at
## y=-0.115 falls ~48 degrees below the view axis against a 37.5-degree
## half-FOV. The chibi head is big enough that the eye is above the shoulders.
##
## So first person gets a dedicated viewmodel mounted to the camera pivot rather
## than to the skeleton, which is how first-person games have always solved this.
## Parented under `FppPivot` so it inherits pitch — the arms rise and fall with
## the look, which is most of what sells them as yours.
##
## ⚠️ Only ever shown on a Person, and only in FPP on the LOCAL unit. A Prop has
## no arms, and a remote player's rig is never the one being looked through.
const VIEWMODEL_ARMS_SCENE: String = "res://scenes/characters/visuals/ViewmodelArms.tscn"
## Uniform scale applied to the arms when they are mounted — § CHECKLIST 1.7. See the
## comment at the mount site for why it lives here and not in the scene.
const VIEWMODEL_SCALE: float = 0.72
## Pushed down and away from the eye after scaling, so shrinking them does not just
## leave a smaller pair of arms in the same commanding spot. Down clears the centre of
## frame; back is what actually stops them subtending half the vertical FOV.
const VIEWMODEL_SEAT: Vector3 = Vector3(0.0, -0.10, -0.16)

## B-91 — mirrors the .tscn's own baked `TppArm.position = (0, 1.2, 0)`, used
## by `_update_tpp_carry_follow()` below to mount the carried-slipper's camera
## at the SAME height a normal TPP rig would use. Written as a formula rather
## than the bare 1.2, because a carrier is always a Person (capsule 1.6) and
## this documents WHY 1.2 is correct there, rather than leaving a magic number
## that looks unrelated to the .tscn's own value.
##
## ⚠️ Do not reuse this for a Prop's OWN (never-carried) mount height. That
## was tried and reverted: scaling TppArm's mount down for a Can/Tsinelas's
## own much shorter capsule put the spring arm's cast origin close enough to
## the ground/the prop's own mesh that the shapecast collapsed the camera into
## solid geometry (measured: a full-frame fill of the can's own INK material).
## `TppArm`'s height and 4.5-unit `spring_length` give the CONTROLLING PLAYER
## situational awareness of the arena at a consistent, human-scale vantage
## point — they are not meant to hug a tiny object's own silhouette, and nothing
## about the proportion fix asked for that; only the carried-slipper case was
## reported broken.
const TPP_MOUNT_CLEARANCE_AT_PERSON_SCALE: float = 0.4
## 2026-07-28 — REPLACES `_mount_height_for(carrier.capsule_height())` for the
## carried case (see `_update_tpp_carry_follow()`). That formula gives `1.2`
## either way, but "1.2" meant two different things depending on WHOSE origin
## it was measured from: for a standalone Prop it is 1.2 above that Prop's own
## short capsule's centre, which reads fine; reused against a Person carrier's
## 1.6-tall capsule it put the mount origin 0.4 units ABOVE the carrier's own
## head (head-top sits at local `+0.8` from a Person's origin — see the FPP
## eye-height note above). A spring-arm cast starting already above someone's
## head collapses into the first thing it touches — reported as an extreme
## close-up on an overhead wire, and "it's just inside the head" once the cast
## comes up short. This sits just below head height instead, a believable
## over-the-shoulder spectator position.
const TPP_CARRY_MOUNT_HEIGHT: float = 0.6
const PERSON_CAPSULE_HEIGHT: float = 1.6

## Checklist 7.2 / playtest 2026-07-28 — "BROKEN LATA CAMERA", with a screenshot
## of an empty road.
##
## `TppArm`'s baked 4.5-unit `spring_length` was tuned for a 1.6-unit Person. The
## Can is **0.34 units tall**, so playing as the Can framed it as a speck in the
## middle of an empty street — a third-person camera whose subject is roughly
## three pixels. Verified by render before and after.
##
## ⚠️ ONLY THE ARM LENGTH SCALES. THE MOUNT HEIGHT DELIBERATELY DOES NOT — see
## the `TPP_MOUNT_CLEARANCE_AT_PERSON_SCALE` note above: scaling the mount down
## for a short capsule was tried and REVERTED, because it dropped the shapecast's
## origin close enough to the ground that the camera collapsed into solid
## geometry. That failure is avoided here by construction: the cast still starts
## at the same safe height a Person's does, and only the distance it travels
## shrinks. Shortening the arm cannot put the origin anywhere new.
##
## The floor keeps the arena readable. A Can player is the one being thrown at
## and still needs to see the attacker, so this frames the prop without hugging
## it — the point is that the subject is visible, not that it fills the screen.
const TPP_MIN_SPRING_LENGTH: float = 1.8
## How far down the arm aims for the shortest subjects. The scene bakes -15,
## which points straight over a 0.34-unit Can from a 1.2 mount.
const TPP_MIN_PITCH_DEG: float = -34.0

@export var aim_source: AimSource = AimSource.MOVEMENT

@onready var fpp_pivot: Node3D = $FppPivot
@onready var fpp_camera: Camera3D = $FppPivot/FppCamera
@onready var tpp_arm: SpringArm3D = $TppArm
@onready var tpp_camera: Camera3D = $TppArm/TppCamera

var _character: CharacterBase
# Written only in _ready(); never exposed publicly — Mode is derived, not settable.
var _mode: Mode
var _pitch_deg: float = 0.0
var _active: bool = false
## 2026-07-28 — user feedback: "tsinelas cam should be movable but anchored to
## person... so awkward for them to be watching gameplay happen like this."
## While CARRIED, `_character.rotation` is slaved to the carrier's hand every
## physics frame (`carriable.gd::_step_carried()`), so the normal TPP
## yaw-steers-the-body mechanism below has no visible effect — the write is
## overwritten before the next frame renders, and the carried player has
## never actually had camera control, B-91 or not. These track a LOOK OFFSET
## instead, applied on top of the carrier's own facing in
## `_update_tpp_carry_follow()`, so the view starts anchored behind the
## carrier and the carried player can still swivel it from there.
var _tpp_carry_yaw_deg: float = 0.0
## The scene's own baked `TppArm.spring_length`, captured before
## `_apply_tpp_framing()` ever shortens it — so re-framing on a round swap
## always scales from the authored value rather than from last round's result,
## which would ratchet the camera closer every round.
var _tpp_base_spring_length: float = 4.5
## The scene's own baked `TppArm` pitch, captured for the same reason as the
## length above — so re-framing scales from the authored value every round.
var _tpp_base_pitch_deg: float = -15.0
## The framing pitch _apply_upright_pose() rebuilds the arm from each frame.
var _tpp_pitch_deg: float = -15.0
## The scene's own baked mount heights, captured before anything overrides them.
var _tpp_mount_height: float = 1.2
var _fpp_eye_height: float = 0.45
## The carried unit's Visual this rig currently has hidden from its own player,
## so it can be un-hidden even after the unit stops being held. See
## _apply_carried_self_hide.
var _hidden_carried_visual: Node3D = null
var _tpp_carry_pitch_deg: float = 0.0
## B-91 — this rig's own Carriable, so it can tell "am I currently being
## carried" without character_base.gd having to learn what carrying is (the
## same information-hiding rule carriable.gd's own header states). Null for a
## Can (never carried) and for a Person (never carriable at all).
## ⚠️ WAS `@onready var _carriable: Carriable`. This rig belonged to a unit that
## could ITSELF be picked up and carried — a lata or a tsinelas with a camera in
## it — so the framing had to stand aside while it rode in somebody's hand. Every
## unit is a Person now and no camera is ever carried, so the three branches that
## read this are gone with it.
## Which carrier's body the spring arm currently excludes from its own
## shapecast, so add/remove_excluded_object is only called on an actual
## CHANGE of carrier (pick up, drop, round reset) rather than every frame.
var _tpp_excluded_carrier: CharacterBase = null
## Playtest 0.4 first-person viewmodel arms, created on demand by
## _viewmodel_arms(). Null on every Prop and on any Person that has never
## been looked through.
var _arms: Node3D = null
## The throwing arm's empty-handed pose, captured from ViewmodelArms.tscn the
## first time it is needed. The carry pose is computed from the slipper, so
## this is what the hand returns to when nothing is held.
var _viewmodel_rest: Transform3D = Transform3D.IDENTITY

## ⚠️⚠️ THE FIRST-PERSON HALF OF EVERY VERB, WHICH DID NOT EXIST.
## 🧑 2026-08-01: *"add visual cue for first person and for everyone else that shove
## and sunok and other skills and abilities shit is happening, maybe an animation"*.
##
## The THIRD-person half was already right — `broadcast_visual_action()` plays a clip
## on every machine for grab, throw, punch, lunge and shove, and its own header
## records why (an action nobody else can see is an action nobody else can answer).
## But in first person the body is `SHADOWS_ONLY` and the player sees only the
## viewmodel arms, which never reacted to anything. So the one person who most needs
## to know the punch came out — the person who pressed it — got no feedback at all.
##
## ⚠️ A KICK ON THE EXISTING POSE, NOT A NEW ANIMATION TRACK. `_update_viewmodel_carry`
## already lerps `RightPivot` to a computed pose every frame, so a transient offset
## layered on top costs one Vector3 and cannot fight the carry pose the way a second
## AnimationPlayer would. It decays on a real timer and is purely cosmetic: nothing
## reads it, and it never touches the body, the hitbox or the facing.
const VM_KICK_TIME: float = 0.22
## Per verb: how far the hand is thrown, along the view's own -Z, and how much it
## rolls. Tuned to read at 60 fps without covering the crosshair.
const VM_KICKS: Dictionary = {
	"punch": {"push": 0.30, "lift": -0.04, "roll": 0.10},
	"shove": {"push": 0.24, "lift": 0.05, "roll": -0.14},
	"lunge": {"push": 0.34, "lift": 0.07, "roll": 0.05},
	"throw": {"push": 0.26, "lift": 0.10, "roll": -0.08},
	"grab": {"push": 0.06, "lift": -0.22, "roll": 0.0},
}
var _vm_kick_left: float = 0.0
var _vm_kick: Dictionary = {}

## Q-8: decaying camera-shake offset, applied to whichever camera this rig's
## _mode actually uses — never by writing the character body's rotation
## (which would fight _is_mouse_aimed() and reproduce B-60).
var _shake_strength: float = 0.0
var _shake_duration: float = 0.18
var _shake_time_left: float = 0.0
var _fpp_camera_base_position: Vector3 = Vector3.ZERO
var _tpp_camera_base_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	_character = get_parent() as CharacterBase
	_mode = Mode.FPP if _character.is_person else Mode.TPP
	assert((_mode == Mode.FPP) == _character.is_person,
		"Camera directive: Person is always FPP, Prop is always TPP (Dev_Plan §0.1)")
	_fpp_camera_base_position = fpp_camera.position
	_tpp_camera_base_position = tpp_camera.position
	# SpringArm3D's shapecast would otherwise hit the character's own capsule
	# every frame and drag the camera in against its own body.
	tpp_arm.add_excluded_object(_character.get_rid())
	# The meshes do not exist yet: this rig's _ready() runs before
	# character_base.gd's (children are ready before parents), and the model is
	# instanced there. Re-apply on every model change instead of only now —
	# which also covers the round-swap, where a Prop's Can/Tsinelas model is
	# rebuilt from scratch. Calling it once here too is harmless and keeps the
	# behaviour correct if a Visual ever ships with meshes baked in.
	_tpp_base_spring_length = tpp_arm.spring_length
	_tpp_base_pitch_deg = tpp_arm.rotation_degrees.x
	_tpp_pitch_deg = _tpp_base_pitch_deg
	_tpp_mount_height = tpp_arm.position.y
	_fpp_eye_height = fpp_pivot.position.y
	var visual := _character.get_node_or_null("Visual") as CharacterVisual
	if visual != null:
		visual.model_changed.connect(_apply_fpp_self_hide)
		# Re-framed on every model change, not just here: `is_can` flips every
		# round, and a Can and a Tsinelas have different capsule heights, so a
		# rig framed once at _ready() would keep the previous role's distance
		# for the whole of the next round.
		visual.model_changed.connect(_apply_tpp_framing)
	# 2026-07-29 — THE SELF-HIDE IS EVENT-DRIVEN NOW, not only polled.
	#
	# _apply_carried_self_hide() restores whatever it hid, but until this it was
	# re-evaluated in only two places: `model_changed`/`set_active` (via
	# _apply_fpp_self_hide) and _update_viewmodel_carry() in _process. That left a
	# window with teeth. On a round reset the roster is walked one character at a
	# time, so this Person's `model_changed` can fire while the slipper it was
	# holding has not been reset yet — the rig correctly hides it, the slipper
	# then goes LOOSE, and NOTHING re-evaluates until the next _process tick.
	# Measured with tools/net_spawn_probe.gd: sampled one physics frame after
	# round_started, the host's own former slipper — by then re-rolled as the CAN
	# — was still `visible = false`.
	#
	# _process did clear it a frame later, so this was a narrow flicker rather
	# than the ten-session bug (that one is Carriable.reset_for_new_round()'s
	# stale `_held`, fixed at source). But it is the same failure shape, it is
	# invisible to every check that is not frame-exact, and _process is not
	# guaranteed to run at all — `set_process(active)` gates it, and a paused tree
	# stops it outright. `held_changed` fires on every peer from the same host
	# broadcast that changes the fact, so hanging the update on it makes hide and
	# restore deterministic instead of "correct by the next rendered frame".
	var carrier := _character.get_node_or_null("Carrier") as Carrier
	if carrier != null:
		carrier.held_changed.connect(_on_held_changed)
	_apply_fpp_self_hide()
	_apply_tpp_framing()
	set_active(false)
	set_process_unhandled_input(false)
	# Networked: authority is already decided at spawn, so a rig can safely
	# activate itself here — no main.gd wiring needed, same pattern as Hud
	# reading autoloads directly. Local test has no authority concept; the
	# switcher (or main.gd, until it exists) calls set_active() explicitly.
	#
	# AI takeover: is_multiplayer_authority() alone is no longer sufficient on
	# the HOST machine specifically — an AI-driven character's authority is
	# also the host's own peer_id (see main.gd::_build_networked_character),
	# so on a host that is itself a real player, every AI-driven character's
	# rig would ALSO see is_mine = true and activate here, stealing the
	# camera (and, via _apply_fpp_self_hide below, hiding that AI character's
	# own body/head as if it were being viewed through its own eyes) —
	# reported as "my POV is another AI-controlled character" and "other
	# characters have an FPP model with a TPP view." `ai_controller` is only
	# ever non-null on the one process that attached it (the host, and only
	# for the character it's actually driving — see main.gd's _attach_ai
	# call sites), so excluding it is enough to tell "mine" from "the host's
	# machine happens to also simulate this one." Same fix as
	# main.gd::get_local_character().
	if NetworkManager.is_networked():
		var is_mine := _character.is_multiplayer_authority() and _character.ai_controller == null
		set_active(is_mine)
		set_aim_source(AimSource.MOUSE if is_mine else AimSource.MOVEMENT)

## B-91 — TPP mount height for a given capsule height, used ONLY by
## _update_tpp_carry_follow() below, evaluated against the CARRIER's capsule
## (always a Person's 1.6 — see the const doc above for why this is a formula
## and not the bare 1.2). Deliberately not used for a Prop's own standalone
## mount height — see the same const doc for why that was tried and reverted.
## Scales the TPP arm to the unit it is actually watching. See
## TPP_MIN_SPRING_LENGTH for why only the length moves and never the mount.
##
## No-ops on a Person in every respect: a 1.6 capsule gives a ratio of 1.0 and
## the arm keeps the scene's own baked 4.5, so nothing about the FPP/TPP
## directive or a Person's framing changes.
## ⚠️ THE CAMERA NEVER INHERITS THE BODY'S ROLL OR PITCH. THIS IS THE INVARIANT.
##
## Playtest 2026-07-28, with screenshots: "camera for both can and slippers
## randomly break" — the whole 3D view rolled 40 degrees while the HUD stayed
## level, which is a camera roll and nothing else.
##
## Both pivots are CHILDREN of the CharacterBase, so they inherit its full basis.
## Almost everything writes only `rotation.y` and is harmless, but a Prop's body
## does get a full basis written to it: `carriable.gd::_step_carried()` snaps a
## carried unit to the carrier's HAND every physics frame, tilt included, and
## anything that leaves a non-yaw component behind — a mid-transition frame, a
## release path that has not zeroed it yet, a future ability that tilts a
## body — lands directly in the player's eye.
##
## Patching each writer has been tried in pieces and this is the third report.
## So the rig stops trusting its parent instead: every frame, both pivots are
## given an ABSOLUTE transform built from the body's YAW ONLY plus their own
## pitch. Whatever the body is doing on the other two axes cannot reach the
## camera, from any code path, including ones nobody has written yet.
##
## ⚠️ Yaw is recovered from the body's FORWARD VECTOR, not from
## `global_rotation.y`. Euler decomposition of a basis that has roll in it does
## not give back the yaw you want — which is exactly the situation this function
## exists to survive.
func _body_yaw() -> float:
	var forward := -_character.global_transform.basis.z
	if absf(forward.x) < 0.00001 and absf(forward.z) < 0.00001:
		return _character.global_rotation.y # looking straight up/down; degenerate
	return atan2(-forward.x, -forward.z)

func _apply_upright_pose() -> void:
	if _character == null:
		return
	# ⚠️ THE ORBIT IS ANCHORED TO THE BODY, NOT DRIVEN BY IT. Same position the
	# ordinary TPP case uses — `_character.global_position` — so the camera stays on
	# the emoting player; only the direction it looks from is this rig's own, which
	# is what lets the player circle their own character while it animates.
	if _emote_view:
		tpp_arm.global_transform = Transform3D(
			Basis(Vector3.UP, deg_to_rad(_emote_yaw_deg))
				* Basis(Vector3.RIGHT, deg_to_rad(_emote_pitch_deg)),
			_character.global_position + Vector3.UP * _tpp_mount_height)
		return
	var yaw := Basis(Vector3.UP, _body_yaw())
	if _mode == Mode.FPP:
		fpp_pivot.global_transform = Transform3D(
			yaw * Basis(Vector3.RIGHT, deg_to_rad(_pitch_deg)),
			_character.global_position + Vector3.UP * _fpp_eye_height)
		return
	# The carried case already writes an absolute transform of its own, anchored
	# to the CARRIER rather than to this body — see _update_tpp_carry_follow().
	# Overwriting it here would undo the anchoring and snap the view back onto a
	# slipper that is being swung around by someone else's arm.
	tpp_arm.global_transform = Transform3D(
		yaw * Basis(Vector3.RIGHT, deg_to_rad(_tpp_pitch_deg)),
		_character.global_position + Vector3.UP * _tpp_mount_height)

func _apply_tpp_framing() -> void:
	if _mode != Mode.TPP or _character == null:
		return
	var ratio := clampf(_character.capsule_height() / PERSON_CAPSULE_HEIGHT, 0.0, 1.0)
	tpp_arm.spring_length = lerpf(TPP_MIN_SPRING_LENGTH, _tpp_base_spring_length, ratio)
	_tpp_pitch_deg = lerpf(TPP_MIN_PITCH_DEG, _tpp_base_pitch_deg, ratio)
	# Pitch, for the same reason and with the same safety property: the mount is
	# 1.2 up and a Can's top is at 0.34, so a rig still aimed 15 degrees down
	# looks straight over it and leaves the subject sitting on the bottom edge of
	# frame under a screenful of sky — measured in the first render of this fix.
	# Tilting further down re-centres it, and like the length it only changes
	# where the cast POINTS, never where it starts, so it cannot reintroduce the
	# collapse that killed the mount-scaling attempt.
	tpp_arm.rotation_degrees.x = _tpp_pitch_deg

func _mount_height_for(capsule_height: float) -> float:
	var clearance := TPP_MOUNT_CLEARANCE_AT_PERSON_SCALE * (capsule_height / PERSON_CAPSULE_HEIGHT)
	return capsule_height / 2.0 + clearance

## Exactly one camera should be `current` at a time (per local peer) — the
## public API queue item 1's unit switcher hands control between units
## with, and what a networked spawn calls on itself above. Disables _process
## on an inactive rig so four idle rigs aren't doing four cameras' worth of
## work for nothing.
## ---------------------------------------------------------------------------
## ⚠️⚠️ THE EMOTE CAMERA. 🧑 2026-08-04: *"i want the emotes to switch camera to
## TPP js for the emote and go back to FPP after the emote ends"*, and *"make srue
## i can move camera around while im emoting but its anchored to my body"*.
##
## ⚠️ THIS IS THE ONLY THING IN THE GAME THAT MOVES A PERSON OFF FPP, and `_ready()`
## asserts the opposite ("Person is always FPP, Prop is always TPP"). That assert is
## about the RESTING mode and still holds: this restores whatever it found on the
## way out, so a Person is FPP before the emote and FPP after it. Nothing else may
## write `_mode` while `_emote_view` is up.
##
## ⚠️ LOCAL ONLY, ALWAYS. Only the peer that owns this body ever calls these — the
## emote itself is replicated (character_base.gd::broadcast_emote), the camera is
## not. A remote peer swinging to third person because somebody else danced would
## take the game away from them mid-round.
const EMOTE_PITCH_MIN_DEG: float = -35.0
const EMOTE_PITCH_MAX_DEG: float = 20.0

var _emote_view: bool = false
var _emote_yaw_deg: float = 0.0
var _emote_pitch_deg: float = 0.0
var _mode_before_emote: Mode = Mode.FPP

func is_emote_view() -> bool:
	return _emote_view

func begin_emote_view() -> void:
	if _emote_view:
		return
	_mode_before_emote = _mode
	_emote_view = true
	# ⚠️ SEEDED FROM THE BODY'S CURRENT FACING so the camera opens behind the
	# character it is about to orbit, rather than snapping to world north.
	_emote_yaw_deg = rad_to_deg(_body_yaw())
	_emote_pitch_deg = _tpp_pitch_deg
	_mode = Mode.TPP
	_apply_emote_view()

func end_emote_view() -> void:
	if not _emote_view:
		return
	_emote_view = false
	_mode = _mode_before_emote
	_apply_emote_view()

## Re-asserts everything that reads `_mode`. Each of these is set once elsewhere on
## a mode that never changed before this feature existed, so all four have to be
## re-run by hand here.
func _apply_emote_view() -> void:
	fpp_camera.current = _active and _mode == Mode.FPP
	tpp_camera.current = _active and _mode == Mode.TPP
	# ⚠️ THE POINT OF THE WHOLE SWITCH: in FPP your own body is SHADOWS_ONLY, so
	# without this the third-person camera would swing around to look at an emote
	# performed by an invisible man.
	_apply_fpp_self_hide()
	# The arms are a first-person prop and read as two slabs floating beside the
	# character from outside.
	var arms := _arms
	if arms != null and is_instance_valid(arms):
		arms.visible = _active and _mode == Mode.FPP
	# The spring arm has not been framing anything while the rig was in FPP.
	_apply_tpp_framing()

## ⚠️⚠️ IGNORED WHILE SPECTATED — SEE `set_spectated()`. `main.gd::
## _reassert_spectated_bots()` calls `set_active(false)` on every rig in the match,
## unconditionally, and it has to keep doing that (it is what stops a DIFFERENT
## unit's rig stealing the viewport — see that function's own header). Without
## this guard the very next reassert would silently strip the one rig the
## spectator is standing inside of. This is the "teach it about the borrow"
## the master prompt asks for: not by making main.gd special-case a node it does
## not otherwise know about, but by making the call it already makes harmless.
func set_active(active: bool) -> void:
	if _spectated:
		return
	_active = active
	fpp_camera.current = active and _mode == Mode.FPP
	tpp_camera.current = active and _mode == Mode.TPP
	set_process(active)
	set_process_unhandled_input(active and aim_source == AimSource.MOUSE)
	# B-61: the self-hide depends on whether this rig is the one being looked
	# through, so it has to be re-evaluated whenever that changes — not just
	# once at _ready().
	_apply_fpp_self_hide()

## True only when this rig is the one the local screen is looking THROUGH, in
## first person. Both halves matter and `_active` alone is not enough: a rig can
## be active while rendering TPP (spectator, prop cameras), and every character in
## a single-process debug session reports `is_multiplayer_authority()`.
##
## Added 2026-08-01 for the aiming arc. 🧑: *"make sure that only first person sees
## that, dont show it for others"*. Networked play was already correct by accident
## — `carrier.gd` gated on multiplayer authority, which is per-peer — but "the
## local player is the authority" and "the local player is LOOKING THROUGH THIS
## CHARACTER'S EYES" are different claims, and only the second one is what the arc
## should be drawn for.
##
## ⚠️⚠️ A SPECTATED RIG COUNTS, DELIBERATELY, AND THIS IS THE DECISION IN WRITING.
## `Master_Prompt_Spectator_Player_POV.md` §1 asks for exactly that: a spectator
## borrowing this rig sees a real first-person frame, and `is_local_fpp()`'s own
## consumer (`carrier.gd::_update_trajectory()`) gates on it plus a SEPARATE
## authority check the borrow can never satisfy (a spectator holds no authority
## over anybody), so the trajectory preview cannot leak into a spectated frame
## through this door regardless. Nothing else reads this. `_active` already
## reads true while spectated (see `set_spectated()`), so this needed no code
## change — only the sentence saying it was not an accident.
func is_local_fpp() -> bool:
	return _active and _mode == Mode.FPP

## The rig mode (FPP/TPP) is derived and untouchable (§0.1) — this only
## chooses how the ACTIVE rig reads aim input, never what mode it renders in.
##
## ⚠️⚠️ NEVER RE-ENABLES UNHANDLED INPUT WHILE SPECTATED, UNDER ANY `source`. This is
## the second of the two doors `set_spectated()`'s class doc names — the first is
## `set_active()` above, gated the same way. Something re-applying an aim source
## (the debug switcher's `_apply_slots()`, a role rotation) must not be able to
## reopen the one path that would let this machine's mouse steer a body it does
## not own.
func set_aim_source(source: AimSource) -> void:
	aim_source = source
	if _spectated:
		set_process_unhandled_input(false)
		return
	set_process_unhandled_input(_active and aim_source == AimSource.MOUSE)

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE SPECTATOR BORROW — READ-ONLY, NEVER A TAKEOVER.
## `Master_Prompt_Spectator_Player_POV.md` §A reverses the old spectator design
## (a camera placed at the unit's eye height, seeing none of what they are
## doing) in favour of this: the spectator borrows the rig itself, because
## every piece of a real first-person frame — the arms, the tsinelas in hand,
## the self-hide, the carry solve, the eye height and pitch limits — already
## lives here, tuned, and re-deriving a worse copy of it on the spectator's own
## camera was always going to lose detail the real rig does not.
##
## The one thing a placement was actually protecting — `set_active(true)` also
## flips `set_process_unhandled_input(active and aim_source == MOUSE)`, and an
## active rig whose `aim_source` is MOUSE reads THIS MACHINE'S MOUSE and writes
## yaw onto somebody else's body — is still exactly as dangerous. So this is a
## THIRD state, not `set_active(true)` and not a placement:
##
## ⚠️⚠️ THE INVARIANT, IN ONE LINE: A SPECTATED RIG RENDERS LIKE AN ACTIVE RIG
## AND READS LIKE A DEAD ONE.
##
## RENDERS like active: `fpp_camera.current`, `set_process(true)` so the carry
## solve/kicks/shake keep running, and `_apply_fpp_self_hide()` so the body goes
## SHADOWS_ONLY, the arms appear, and the world slipper is swapped for the
## viewmodel's — the exact rows `Master_Prompt_Spectator_Player_POV.md` §B's
## "free" table lists.
##
## READS like dead: `set_process_unhandled_input(false)` is written EXPLICITLY,
## never left to fall out of `aim_source != MOUSE` happening to be true for a
## bot — that coincidence is not a guarantee, and `set_active()`/
## `set_aim_source()` above are both gated so nothing else can flip it back
## while this is up. Nothing here writes `_character` at all: no rotation, no
## state, no RPC. `aim_source` itself is never touched, so whatever it already
## was (MOVEMENT for a bot, whatever this machine's own copy of a remote human's
## rig already computed) is exactly what it still is on release.
var _spectated: bool = false
## `_active`'s value from immediately before the borrow began, so releasing
## restores it rather than assuming "false" — a spectator can only ever borrow a
## rig that was not already the one being looked through on THIS machine (this
## machine holds no seat), so in every real case that is false, but the field is
## kept rather than the assumption so a future caller cannot silently disagree.
var _pre_borrow_active: bool = false

func set_spectated(on: bool) -> void:
	if _spectated == on:
		return
	_spectated = on
	if on:
		_pre_borrow_active = _active
		_active = true
	else:
		_active = _pre_borrow_active
	fpp_camera.current = _active and _mode == Mode.FPP
	tpp_camera.current = _active and _mode == Mode.TPP
	set_process(_active)
	set_process_unhandled_input(false)
	_apply_fpp_self_hide()

func is_spectated() -> bool:
	return _spectated

## Where this rig is looking, in world space, for anything that needs to fire
## along the player's aim rather than along the body's facing (Task 0's
## charge-throw — see carrier.gd::_aim_direction).
##
## This has to come from the CAMERA, not the character. Yaw lives on the body but
## PITCH lives on this rig (see the class doc above), so a throw aimed off
## `-character.transform.basis.z` would travel dead flat regardless of whether
## the player was looking up at a lob or down at their feet. That is the same
## class of bug B-05 fixed for melee, and it would be invisible in a flat test
## arena and obvious the moment a map has height.
##
## Returns the active camera's basis for this rig's mode, so it is correct for a
## TPP Prop too even though only Persons throw today.
func get_aim_basis() -> Basis:
	if _mode == Mode.FPP:
		return fpp_camera.global_transform.basis
	return tpp_camera.global_transform.basis

## Q-8: brief decaying camera kick on a landed hit. Lives here (never on
## arena_camera.gd, which is retired — B-58) so it rides whichever mode this
## rig is already in and can never violate the FPP/TPP directive.
##
## strength/duration match whatever _process() is already mid-shake with by
## taking the max of the two, never summing — a rapid multi-hit stacking
## additively would produce an unrecoverable offset instead of just staying
## at "one hit's worth" of kick.
func shake(strength: float = 0.35, duration: float = 0.18) -> void:
	var remaining_ratio := _shake_time_left / _shake_duration if _shake_duration > 0.0 else 0.0
	var current_effective_strength := _shake_strength * remaining_ratio
	if strength > current_effective_strength:
		_shake_strength = strength
		_shake_duration = duration
		_shake_time_left = duration

## Length of `viewmodel_arm.obj` from elbow to fingertip, in metres. The mesh is
## authored along +Y from the elbow at the origin, so the fist sits exactly this
## far along the pivot's y-axis. Re-measure if `_build_viewmodel_arm()` changes
## its extents.
const VIEWMODEL_ARM_LENGTH: float = 0.84
## The direction the throwing forearm points while carrying, in FppPivot space:
## up, forward and slightly inward toward the crosshair. The elbow is then placed
## backwards along this from the slipper, which is what puts it below frame.
const VIEWMODEL_CARRY_DIR: Vector3 = Vector3(-0.447, 0.745, -0.477)
## Size of the throwing arm while it is holding something. See the block in
## _update_viewmodel_carry() for why the carrying arm shrinks and the empty one
## does not.
const VIEWMODEL_CARRY_SCALE: float = 0.55
## How fast the hand converges on the slipper. Instant snapping on pick-up reads
## as a teleport; this is quick enough to feel attached, slow enough to see.
const VIEWMODEL_REACH_SPEED: float = 14.0
## Where the held slipper sits in the LOCAL player's frame, in FppPivot space.
## Forward, right and below the crosshair — the composition the old chase-the-
## world-slipper code was reverse-engineering, now stated directly and applied
## to the viewmodel where it belongs.
const VIEWMODEL_CARRY_ANCHOR: Vector3 = Vector3(0.26, -0.16, -0.48)


## Playtest: "the slippers just float when you hold it, its completely
## unattached to person".
##
## Correct, and the cause is a seam this rig created. A carried unit is parented
## to a BoneAttachment3D on the SKELETON's arm bone — but in first person the
## skeleton is hidden (`_apply_fpp_self_hide`) and sits below the frustum
## entirely, while the arms the player can actually see are the VIEWMODEL,
## mounted to the camera. Two different spaces. The slipper was never detached
## from the character; it was attached to the arm nobody can see.
##
## So the visible hand is moved to the slipper, rather than the slipper to the
## hand. The fist is placed exactly on the carried unit and the elbow projected
## backwards from it along `VIEWMODEL_CARRY_DIR`, which drops the elbow below
## frame and keeps the forearm running off-screen the way it should.
##
## ⚠️ DELIBERATELY READS THE SLIPPER'S LIVE POSITION rather than baking a pose
## from `HAND_CARRY_OFFSET`. Art_Direction.md §1's proportions work re-measured
## that constant and deleted `TSINELAS_CARRY_SCALE` outright — a baked pose here
## would have silently drifted the moment either landed. Tracking the actual
## unit is correct for whatever those settle at.
func _update_viewmodel_carry(delta: float) -> void:
	var arms := _viewmodel_arms()
	if arms == null or not arms.visible:
		return
	var pivot := arms.get_node_or_null("RightPivot") as Node3D
	if pivot == null:
		return
	if _viewmodel_rest == Transform3D.IDENTITY:
		_viewmodel_rest = pivot.transform

	var carrier := _character.get_node_or_null("Carrier") as Carrier
	var held: Slipper = carrier.held() if carrier != null else null
	var holding := held != null and is_instance_valid(held)
	# ⚠️ 7.3 — THE VIEWMODEL CARRIES ITS OWN SLIPPER NOW, and no longer chases
	# the world one. That inversion is the whole fix for "slipper floating".
	#
	# The old code moved the visible FPP hand ONTO the world slipper, which meant
	# the world slipper's position had to be chosen to compose the FIRST-PERSON
	# frame — `HAND_CARRY_OFFSET`'s own note says so outright: a little above the
	# eye, forward and to the right so it never covers the crosshair. That is a
	# fine place for a viewmodel and a terrible place for a real object, because
	# it is nowhere near the character's actual hand. Everyone ELSE therefore saw
	# a slipper hovering beside its carrier's head. Reported repeatedly as the
	# slipper floating; re-measuring the offset could never have fixed it,
	# because the offset was doing exactly what it was written to do.
	#
	# So the two views get two objects, which is how first-person games have
	# always solved this and is the same reasoning that gave the arms a dedicated
	# viewmodel in the first place. The world slipper sits in the real hand and
	# is correct in third person; `HeldSlipper` under the fist is what the local
	# player sees, posed for their frame and nobody else's.
	var slipper := pivot.get_node_or_null("Arm/HeldSlipper") as MeshInstance3D
	if slipper != null:
		slipper.visible = holding
		if holding:
			_sync_viewmodel_slipper(slipper, held)
	# Per-frame, because what this character is holding changes DURING a round —
	# _apply_fpp_self_hide only re-runs on activation and model changes, so a
	# pick-up mid-round would otherwise show both slippers until the next swap.
	_apply_carried_self_hide(true)
	if _vm_kick_left > 0.0:
		_vm_kick_left = maxf(0.0, _vm_kick_left - delta)
	var wanted := _viewmodel_rest
	if holding:
		# A FIXED carry pose, not a chase. Nothing here reads the world slipper's
		# position any more, so the two can never drag each other around — which
		# is what produced "my arms float during windup" (B-90) as well.
		var dir := VIEWMODEL_CARRY_DIR.normalized()
		var reach := VIEWMODEL_ARM_LENGTH * VIEWMODEL_CARRY_SCALE
		var target := VIEWMODEL_CARRY_ANCHOR
		var elbow := target - dir * reach
		var right_axis := dir.cross(Vector3.FORWARD).normalized()
		wanted = Transform3D(Basis(right_axis * VIEWMODEL_CARRY_SCALE,
			dir * VIEWMODEL_CARRY_SCALE,
			right_axis.cross(dir) * VIEWMODEL_CARRY_SCALE), elbow)

	pivot.transform = pivot.transform.interpolate_with(
		wanted, clampf(VIEWMODEL_REACH_SPEED * delta, 0.0, 1.0))
	# ⚠️ APPLIED AFTER THE LERP, NOT BLENDED INTO `wanted`. The lerp is a slow chase
	# (`VIEWMODEL_REACH_SPEED`) and a kick folded into its target would be smoothed
	# into nothing — the whole point is that it snaps out and eases back. Written
	# straight onto the transform, so it decays as `_vm_kick_left` runs down and
	# leaves the carry pose exactly where it was.
	if _vm_kick_left > 0.0 and not _vm_kick.is_empty():
		var t: float = _vm_kick_left / VM_KICK_TIME
		# Fast out, slow back: t^2 spends most of the window near the extreme.
		var amount: float = t * t
		pivot.transform.origin += Vector3(
			0.0,
			float(_vm_kick["lift"]) * amount,
			-float(_vm_kick["push"]) * amount)
		pivot.transform.basis = pivot.transform.basis.rotated(
			Vector3.FORWARD, float(_vm_kick["roll"]) * amount)


## Toe-to-heel length the held slipper presents IN THE WORLD, in metres, so it
## reads at arm's length in the first-person frame.
##
## ⚠️ MEASURED, NOT TYPED, AND THE OLD VALUE WAS 0.171 m. `ViewmodelArms.tscn`
## authors `HeldSlipper` at mesh scale, and it then inherits TWO nested shrinks —
## the arms' own `VIEWMODEL_SCALE` 0.72 and the carry pose's
## `VIEWMODEL_CARRY_SCALE` 0.55 — so a 0.432 m mesh arrived on screen at 0.396 of
## its size. `tools/models/fpp_carry_probe.tscn` reported it visible, meshed and
## inside the frustum the whole time, which is exactly why this was reported as
## "it doesnt get seen in first person" rather than as a size bug: nothing was
## switched off, it was just too small to notice at the fingertip.
##
## Applied as a per-frame local scale computed against the parent's CURRENT world
## scale, so the slipper keeps this size while the carry pose is still
## interpolating in rather than growing as the arm settles.
const VIEWMODEL_SLIPPER_LENGTH: float = 0.34

## ⚠️ THE VIEWMODEL SLIPPER WEARS THE PICKED SKIN NOW, AND IT USED NOT TO.
## `ViewmodelArms.tscn` hardcodes `tsinelas_classic.obj` on this node, so a player
## who chose CROCS, PANTULOG or SIKE on the CHARACTER screen held a brown flip-flop
## in their own hands while every other peer correctly saw what they had picked.
## That is the second half of THE REACHABILITY RULE — a control that does not do
## what it says — seen from inside the player's own view.
##
## ⚠️ COPIED FROM THE WORLD SLIPPER, NOT LOOKED UP IN THE ROSTER. `slipper.gd`
## already resolves `skin_index` -> mesh, normalises downloaded models at runtime
## and clears stale surface overrides; asking the roster again here would be a
## second implementation of that, free to drift from the first. Reading the object
## that is actually in the player's hand cannot disagree with it.
func _sync_viewmodel_slipper(node: MeshInstance3D, held: Slipper) -> void:
	var visual := held.get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	var source: MeshInstance3D = null
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		source = child as MeshInstance3D
		break
	if source == null or source.mesh == null:
		return
	if node.mesh != source.mesh:
		node.mesh = source.mesh
		# Overrides do not clear themselves when the mesh under them changes, and
		# the surface counts need not match — the same rule `slipper.gd` and
		# `lata.gd` both keep at their own mesh swaps.
		for surface in range(node.get_surface_override_material_count()):
			node.set_surface_override_material(surface, null)
	for surface in range(source.get_surface_override_material_count()):
		node.set_surface_override_material(surface,
			source.get_surface_override_material(surface))

	var length: float = maxf(source.mesh.get_aabb().size.z, 0.001)
	var parent := node.get_parent_node_3d()
	var parent_scale: float = 1.0
	if parent != null:
		parent_scale = maxf(parent.global_transform.basis.get_scale().z, 0.0001)
	node.scale = Vector3.ONE * (VIEWMODEL_SLIPPER_LENGTH / (length * parent_scale))


## B-91 — "slippers camera is completely broken right now", and specifically:
## while a Tsinelas is CARRIED, `carriable.gd::_step_carried()` teleports its
## ENTIRE CharacterBase — origin AND basis — into the carrying Person's hand
## every physics frame. This rig is a child of that CharacterBase, so the TPP
## spring arm inherits that same transform: mounted inside (or right against)
## the carrier's own body, with nowhere sensible to cast toward, and the
## carrier's own capsule was never excluded from the shapecast (only this
## unit's OWN body was, in _ready() above) — so the view collapses against it.
## There is also nothing worth framing there: a 0.43-unit object glued to a
## hand has no independent third-person shot of its own.
##
## So while held, this rig's TPP camera is based on the CARRIER instead — same
## mount height/pitch formula a normal TPP rig uses, evaluated against the
## carrier's own capsule (always a Person's 1.6, so this resolves to the
## ordinary 1.2 mount), just following the carrier's transform rather than
## this unit's own currently-nonsensical one. The slipper's own controlling
## player rides along behind their teammate, third-person, until it is thrown
## or dropped and this unit's transform means something again.
func _update_tpp_carry_follow() -> void:
	if _mode != Mode.TPP:
		return
	# Nothing carries a camera any more — see the note where `_carriable` was.
	var carrier: CharacterBase = null
	# Exclusion list only changes on an actual pick-up/drop/carrier swap, not
	# every frame — SpringArm3D's exclusion list has no "is this already in
	# there" query, so add/remove is gated on a real transition.
	if carrier != _tpp_excluded_carrier:
		if _tpp_excluded_carrier != null and is_instance_valid(_tpp_excluded_carrier):
			tpp_arm.remove_excluded_object(_tpp_excluded_carrier.get_rid())
		if carrier != null:
			tpp_arm.add_excluded_object(carrier.get_rid())
		_tpp_excluded_carrier = carrier
	if carrier == null:
		# Not carried any more — reset the look offset so the next pick-up
		# starts anchored behind the new carrier instead of wherever this
		# player last looked.
		_tpp_carry_yaw_deg = 0.0
		_tpp_carry_pitch_deg = 0.0
		return # ordinary parent-driven transform, nothing to override
	# ANCHORED to the carrier's own yaw (rotation.y is the only axis a body
	# ever rotates on) plus TppArm's fixed -15 degree base tilt, same as
	# before — but now with the carried player's own look offset added on top,
	# so the view starts behind the carrier and can still be swivelled from
	# there. See apply_mouse_delta() and TPP_CARRY_MOUNT_HEIGHT's own docs.
	#
	# ⚠️ 8.5a — READ THE CARRIER'S *INTERPOLATED* TRANSFORM, NOT ITS RAW ONE.
	# This function runs in _process (every render frame) and the carrier is a
	# CharacterBody3D whose transform only changes in _physics_process (60 Hz).
	# Reading `carrier.global_position` from here samples a staircase: at any
	# refresh rate that is not an exact multiple of the tick rate the camera
	# holds still for a frame, then jumps two ticks' worth — which is the judder,
	# and it is worst exactly while being carried. `get_global_transform_
	# interpolated()` is the engine's own accessor for "what does this physics
	# body look like right now, between ticks", and it only returns something
	# different from the raw transform because project.godot now enables
	# physics_interpolation (it had no [physics] section at all before Phase 8).
	var carrier_xform := carrier.get_global_transform_interpolated()
	var carrier_yaw := carrier_xform.basis.get_euler().y
	var yaw_basis := Basis(Vector3.UP, carrier_yaw + deg_to_rad(_tpp_carry_yaw_deg))
	var pitch_basis := Basis(Vector3.RIGHT, deg_to_rad(-15.0 + _tpp_carry_pitch_deg))
	tpp_arm.global_transform = Transform3D(
		yaw_basis * pitch_basis, carrier_xform.origin + Vector3.UP * TPP_CARRY_MOUNT_HEIGHT)

func _process(delta: float) -> void:
	_update_viewmodel_carry(delta)
	_update_tpp_carry_follow()
	_apply_upright_pose()
	if _shake_time_left > 0.0:
		_shake_time_left = max(0.0, _shake_time_left - delta)
		var ratio := _shake_time_left / _shake_duration
		var magnitude := _shake_strength * ratio
		# FPP strength is roughly half of TPP's — the same offset is far more
		# violent from a first-person eye position and reads as nausea rather
		# than impact.
		var effective := magnitude * (0.5 if _mode == Mode.FPP else 1.0)
		_apply_shake_offset(Vector3(
			randf_range(-1.0, 1.0) * effective,
			randf_range(-1.0, 1.0) * effective,
			0.0,
		))
	elif _shake_strength > 0.0:
		_shake_strength = 0.0
		_apply_shake_offset(Vector3.ZERO)

func _apply_shake_offset(offset: Vector3) -> void:
	if _mode == Mode.FPP:
		fpp_camera.position = _fpp_camera_base_position + offset
	else:
		tpp_camera.position = _tpp_camera_base_position + offset

## B-61: hides this character's own body ONLY while you are looking through its
## eyes — i.e. an FPP rig that is currently the active camera. The original
## version applied shadows-only to every Person unconditionally, ignoring
## `_active` entirely, which meant *nobody* could see *any* Person: they were
## walking shadows with no body, teammates and opponents alike. The doc comment
## below already stated the correct rule ("other peers still need to see the
## mesh"); the code just never implemented it.
##
## The bug was invisible until now because the self-hide had silently been a
## no-op — it ran in `_ready()`, before `character_visual.gd` had instanced any
## meshes to find. Fixing that (v1.5) is what exposed this.
## Creates the viewmodel arms on first use and returns them, or null for any
## unit that must never have them. Built lazily rather than in _ready() because
## most rigs in a match are Props or remote Persons and would only pay for a
## node tree nothing ever draws.
func _viewmodel_arms() -> Node3D:
	if _arms != null and is_instance_valid(_arms):
		return _arms
	if _character == null or not _character.is_person:
		return null
	var scene := load(VIEWMODEL_ARMS_SCENE) as PackedScene
	if scene == null:
		push_error("CameraRig: could not load '%s'" % VIEWMODEL_ARMS_SCENE)
		return null
	_arms = scene.instantiate() as Node3D
	fpp_pivot.add_child(_arms)
	# ⚠️⚠️ THE ARMS ARE SEATED HERE, NOT IN THEIR OWN SCENE — § CHECKLIST 1.7.
	# 🧑: *"The FPP viewmodel arms are enormous and dominate the lower third of every
	# frame"*, and every capture in § LOG shows it: two orange slabs across the bottom
	# of the shot the trailer is filmed in.
	#
	# `ViewmodelArms.tscn` puts a 0.84 m mesh 0.34 m in front of the camera, which is
	# why it fills the frame — at that distance the arm subtends most of the vertical
	# FOV. Scaled down and pushed further out and down, it reads as a pair of hands at
	# the bottom of the view instead of as a wall.
	#
	# ⚠️ APPLIED FROM THIS FILE RATHER THAN BY EDITING THE SCENE, deliberately.
	# `scenes/characters/visuals/**` is not this lane's row in § PATHS; `camera_rig.gd`
	# is, and it is the only thing that mounts these arms. A uniform scale on the root
	# also keeps `VIEWMODEL_ARM_LENGTH`, `VIEWMODEL_CARRY_ANCHOR` and the carry solve
	# consistent with each other, because every one of them works in the arms' own
	# local space and scales with it — which editing individual offsets in the scene
	# would not have.
	_arms.scale = Vector3.ONE * VIEWMODEL_SCALE
	_arms.position += VIEWMODEL_SEAT
	return _arms


## How far the throwing arm cocks back at FULL charge, in radians about the
## elbow. The wind-up is the ONLY in-world readout of throw strength a Person
## has in first person — the HUD charge meter is on the YOU card at the bottom
## corner, which nobody looks at while aiming. 0.62 rad (~36°) is enough to be
## unmistakable in peripheral vision without the fist leaving the frame.
const VIEWMODEL_WINDUP_RAD: float = 0.62

## Drives the throwing arm's wind-up from live charge power, 0..1, or -1 for
## "not charging". Polled by character_visual.gd rather than driven by a signal,
## for the same reason that file already polls carry scale and spin: charge is a
## continuously-varying value, not an event, and a poll self-heals across a model
## rebuild on the round swap.
##
## ⚠️ The idle clip animates the SAME rotation this writes, so it has to be
## stopped while charging or it overwrites the pose every frame and the arm just
## sways instead of cocking. It restarts on its own once charge ends and nothing
## else is playing.
func set_viewmodel_charge(power: float) -> void:
	var arms := _viewmodel_arms()
	if arms == null or not arms.visible:
		return
	var player := arms.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var arm := arms.get_node_or_null("RightPivot/Arm") as Node3D
	if player == null or arm == null:
		return
	if power < 0.0:
		# Not charging. Let a throw/grab one-shot finish before idle resumes.
		if not player.is_playing():
			player.play("idle")
		return
	if player.current_animation == "idle":
		player.stop()
	# ⚠️ THE SIGN IS NEGATIVE, AND IT WAS WRONG UNTIL 2026-07-29. User report:
	# "i think the wind up is opposite direction? the arm goes down, not up."
	#
	# Correct. Which way a positive rotation about the arm's local X takes the
	# fist is NOT readable from this line — it depends entirely on RightPivot's
	# basis in ViewmodelArms.tscn, which is a fully general rotation. Measured
	# with tools/windup_probe.tscn, tracking RightPivot/Arm/HeldSlipper (the node
	# the thrown tsinelas rides on, i.e. the fist) in camera space:
	#
	#   rest        rotation.x +0.000 -> fist (+0.205, -0.485, -0.899)
	#   old sign    rotation.x +0.620 -> fist (+0.275, -0.946, -1.141)   dY -0.461
	#   this sign   rotation.x -0.620 -> fist (+0.275, -0.223, -0.450)   dY +0.261
	#
	# +Y is up and -Z is forward, so the old sign drove the fist DOWN and FORWARD
	# — the arm falling away from the player rather than cocking back. The whole
	# point of the wind-up is that it is the only readout of throw strength in the
	# player's eyeline (Art_Direction §1.9), and it was reading backwards.
	#
	# The `throw` one-shot in ViewmodelArms.tscn is NOT affected and was checked:
	# it keys +0.52 first, which under this same measurement is the forward snap,
	# then recoils. That one was always right, which is part of why this hid.
	arm.rotation.x = -VIEWMODEL_WINDUP_RAD * clampf(power, 0.0, 1.0)


## Plays a one-shot on the first-person viewmodel — the visible half of "your
## hand moves when you throw". Called by `character_visual.gd::play_action()`,
## which already resolves what kind of action happened for the third-person
## model, so the two can never disagree about whether a throw occurred.
##
## No-ops on anything without a viewmodel (every Prop, every remote Person) and
## on any clip this rig's arms do not carry, so a new action kind added to
## ACTION_CLIPS never has to be mirrored here to avoid an error.
func play_viewmodel_action(kind: String) -> void:
	var arms := _viewmodel_arms()
	if arms == null or not arms.visible:
		return
	var player := arms.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player != null and player.has_animation(kind):
		player.play(kind)
		return
	# ⚠️⚠️ AND A PROCEDURAL KICK WHEN THERE IS NO CLIP, WHICH IS EVERY VERB BUT THE
	# THROW. 🧑 2026-08-01: *"add visual cue for first person and for everyone else
	# that shove and sunok and other skills and abilities shit is happening"*.
	#
	# This function already existed and was already called for every action, and it
	# RETURNED SILENTLY on any kind the arms had no animation for — which is the
	# punch, the shove, the lunge and the grab. Its own doc called that a feature
	# ("a new action kind never has to be mirrored here to avoid an error"), and it
	# is, right up until the actions that matter are the ones with no clip. In first
	# person the body is SHADOWS_ONLY, so those four verbs had NO first-person
	# feedback whatsoever: you pressed shove and the screen did not move.
	#
	# The kick is not a substitute for an authored clip — it is what makes the verb
	# legible until somebody animates it, and it disappears on its own the day a
	# clip with that name is added, because the branch above wins.
	if VM_KICKS.has(kind):
		_vm_kick = VM_KICKS[kind]
		_vm_kick_left = VM_KICK_TIME


## Shows/hides the unit THIS character is carrying, for this peer only.
##
## ⚠️ IT REMEMBERS WHAT IT HID, and that is not bookkeeping for its own sake.
## The obvious version just reads `carrier.held()` and hides it — which works
## until the slipper is THROWN, at which point `held()` is null, the function
## returns early having restored nothing, and the slipper stays invisible to the
## player who threw it for the rest of the round. Restoring is keyed on the node
## this actually hid, so releasing it is never conditional on still holding it.
func _apply_carried_self_hide(hide_it: bool) -> void:
	var wanted: Node3D = null
	if hide_it:
		var carrier := _character.get_node_or_null("Carrier") as Carrier
		var held: Slipper = carrier.held() if carrier != null else null
		if held != null and is_instance_valid(held):
			# ⚠️ THE SLIPPER'S OWN VISUAL, NOT ITS HOLDER'S. A carried slipper used to
			# be a whole `CharacterBase` and the thing to hide was that unit's `Visual`
			# child; the prop IS the visual now, so hiding the parent would hide the
			# player holding it.
			wanted = held.get_node_or_null("Visual") as Node3D
	if wanted == _hidden_carried_visual:
		return
	if _hidden_carried_visual != null and is_instance_valid(_hidden_carried_visual):
		_hidden_carried_visual.visible = true
	if wanted != null:
		wanted.visible = false
	_hidden_carried_visual = wanted

## What this Person is holding just changed. Re-evaluate the self-hide on the
## spot rather than waiting for the next _process tick — see the connect site in
## _ready() for why that wait was not safe.
##
## Takes the same `_active and _mode == Mode.FPP` gate _apply_fpp_self_hide()
## uses rather than a bare `true`, so a rig nobody is looking through can never
## hide a slipper on this machine.
func _on_held_changed(_held: Slipper) -> void:
	_apply_carried_self_hide(_active and _mode == Mode.FPP)

func _apply_fpp_self_hide() -> void:
	# The viewmodel is the inverse of the self-hide: it is the one thing that
	# must appear exactly when the rest of the body is being looked past. Driven
	# from here rather than from set_active() so it can never disagree with the
	# body it is standing in for — both states come off the same two flags.
	var arms := _viewmodel_arms()
	if arms != null:
		arms.visible = _active and _mode == Mode.FPP

	# ⚠️ 7.3 — THE CARRIED SLIPPER IS PART OF THE SELF-HIDE NOW.
	#
	# Once the viewmodel got its own `HeldSlipper`, the LOCAL player saw two of
	# them: the viewmodel's, posed for their frame, and the real one sitting in
	# their character's hand. The world slipper is a separate CharacterBase, so
	# it was never covered by the body hide below.
	#
	# Same mechanism and same reasoning as the body: `_active` is only ever true
	# for the rig a peer is actually looking through, so this hides the object on
	# THAT machine only. Every other peer still sees the slipper in their hand,
	# which is the whole point of having moved it there.
	_apply_carried_self_hide(_active and _mode == Mode.FPP)

	var visual_root := _character.get_node_or_null("Visual")
	if visual_root == null:
		return
	# "Visual" is a plain Node3D wrapper (see CharacterBase.tscn) so the whole
	# subtree can be treated as one unit — it is not itself a VisualInstance3D,
	# so cast_shadow has to be set on every mesh underneath it individually.
	# NOT hide(): losing your own shadow in FPP destroys the ground read, so the
	# body still casts, it just isn't drawn.
	var looking_through_this_body := _active and _mode == Mode.FPP
	var meshes := visual_root.find_children("*", "GeometryInstance3D", true, false)
	if not looking_through_this_body:
		for node in meshes:
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		return

	# B-73: hide ONLY the head, not the whole body.
	#
	# The Kenney rig is two meshes — `head-mesh` and `body-mesh` — and the arms
	# are not separate geometry, they are skinned to the arm bones INSIDE
	# `body-mesh`. So blanking every mesh under Visual (what this used to do)
	# took the arms, torso and legs with it and left first person with no body at
	# all, which is what "I can't see the arms in FPP" was. Dropping just the
	# head keeps the body visible from the eye position and stops you looking at
	# the inside of your own face.
	# ⚠️ B-73 ONCE HID ONLY THE HEAD. That is no longer right, and reverting to it
	# brings back a bug the playtest found: "arms clip thru body, it feels
	# disconnected from person".
	#
	# B-73 kept `body-mesh` visible because there was nothing else to look at in
	# first person. There is now — the viewmodel above. Keeping the real body as
	# well means two sets of arms in the same frustum: the viewmodel ones mounted
	# to the camera, and the skinned ones hanging 0.37 below it. They intersect
	# whenever the player looks down or the rig animates, which is exactly what
	# "clipping through the body" is.
	#
	# The real body was never actually visible from the eye anyway — it sits
	# below the frustum (see VIEWMODEL_ARMS_SCENE's note) — so hiding it costs
	# nothing on screen and removes the intersection outright. This is what every
	# first-person game does: the world sees the character, the player sees the
	# viewmodel.
	#
	# SHADOWS_ONLY, never hide(): losing your own shadow in first person destroys
	# the ground read, and it is the only cue a Person has for where they are
	# standing relative to the base circle.
	for node in meshes:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

func _unhandled_input(event: InputEvent) -> void:
	if not _active or aim_source != AimSource.MOUSE:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_mouse_delta((event as InputEventMouseMotion).relative)

## Split out from _unhandled_input so the yaw/pitch math is directly testable
## without depending on the engine's input-event dispatch (which needs a real
## display server to route InputEventMouseMotion to _unhandled_input — not
## available headless).
func apply_mouse_delta(relative: Vector2) -> void:
	# Item 14: SettingsManager.mouse_sensitivity is a plain multiplier on this
	# rig's own flat BASE_SENSITIVITY, so the Settings slider's range means
	# the same thing regardless of whatever base rate feels right here.
	var sensitivity := BASE_SENSITIVITY * SettingsManager.mouse_sensitivity
	# 2026-07-28 — while carried, _character.rotation.y (written below for the
	# ordinary TPP case) is overwritten every physics frame by
	# carriable.gd::_step_carried(), so it has no visible effect here. Track a
	# separate look offset instead — see _tpp_carry_yaw_deg's own doc and
	# _update_tpp_carry_follow(), which is what actually reads it.
	# ⚠️ THIS BRANCH IS UNREACHABLE NOW AND IS KEPT AS A GUARD, NOT AS LOGIC. It
	# steered the look of a unit that was ITSELF being carried; no unit is carried
	# any more, so the condition is false by construction rather than by accident.
	if false:
		_tpp_carry_yaw_deg -= relative.x * sensitivity
		var carry_pitch_delta := relative.y * (-1.0 if SettingsManager.invert_y else 1.0)
		_tpp_carry_pitch_deg = clamp(
			_tpp_carry_pitch_deg - carry_pitch_delta * sensitivity, PITCH_MIN_DEG, PITCH_MAX_DEG)
		return
	# ⚠️⚠️ AN EMOTE ORBITS, IT DOES NOT STEER. 🧑 2026-08-04: *"make srue i can move
	# camera around while im emoting but its anchored to my body"*. Writing
	# `_character.rotation.y` here — what every other frame does — would spin the
	# BODY under the emote clip, so a player looking around would turn their own
	# dancing character on the spot for everyone else watching. The look is held as
	# this rig's own yaw/pitch instead and the body is left alone; see
	# `_apply_upright_pose()`, which reads these two instead of `_body_yaw()` while
	# the orbit is up.
	if _emote_view:
		_emote_yaw_deg -= relative.x * sensitivity
		var emote_pitch_delta := relative.y * (-1.0 if SettingsManager.invert_y else 1.0)
		_emote_pitch_deg = clamp(_emote_pitch_deg - emote_pitch_delta * sensitivity,
			EMOTE_PITCH_MIN_DEG, EMOTE_PITCH_MAX_DEG)
		return
	_character.rotation.y -= deg_to_rad(relative.x * sensitivity)
	if _mode == Mode.FPP:
		var pitch_delta := relative.y * (-1.0 if SettingsManager.invert_y else 1.0)
		_pitch_deg = clamp(_pitch_deg - pitch_delta * sensitivity, PITCH_MIN_DEG, PITCH_MAX_DEG)
		fpp_pivot.rotation.x = deg_to_rad(_pitch_deg)
