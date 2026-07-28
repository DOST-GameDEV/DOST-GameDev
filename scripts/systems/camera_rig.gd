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
var _tpp_carry_pitch_deg: float = 0.0
## B-91 — this rig's own Carriable, so it can tell "am I currently being
## carried" without character_base.gd having to learn what carrying is (the
## same information-hiding rule carriable.gd's own header states). Null for a
## Can (never carried) and for a Person (never carriable at all).
@onready var _carriable: Carriable = get_node_or_null("../Carriable") as Carriable
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
	var visual := _character.get_node_or_null("Visual") as CharacterVisual
	if visual != null:
		visual.model_changed.connect(_apply_fpp_self_hide)
		# Re-framed on every model change, not just here: `is_can` flips every
		# round, and a Can and a Tsinelas have different capsule heights, so a
		# rig framed once at _ready() would keep the previous role's distance
		# for the whole of the next round.
		visual.model_changed.connect(_apply_tpp_framing)
	_apply_fpp_self_hide()
	_apply_tpp_framing()
	set_active(false)
	set_process_unhandled_input(false)
	# Networked: authority is already decided at spawn, so a rig can safely
	# activate itself here — no main.gd wiring needed, same pattern as Hud
	# reading autoloads directly. Local test has no authority concept; the
	# switcher (or main.gd, until it exists) calls set_active() explicitly.
	if NetworkManager.is_networked():
		var is_mine := _character.is_multiplayer_authority()
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
func _apply_tpp_framing() -> void:
	if _mode != Mode.TPP or _character == null:
		return
	var ratio := clampf(_character.capsule_height() / PERSON_CAPSULE_HEIGHT, 0.0, 1.0)
	tpp_arm.spring_length = lerpf(TPP_MIN_SPRING_LENGTH, _tpp_base_spring_length, ratio)
	# Pitch, for the same reason and with the same safety property: the mount is
	# 1.2 up and a Can's top is at 0.34, so a rig still aimed 15 degrees down
	# looks straight over it and leaves the subject sitting on the bottom edge of
	# frame under a screenful of sky — measured in the first render of this fix.
	# Tilting further down re-centres it, and like the length it only changes
	# where the cast POINTS, never where it starts, so it cannot reintroduce the
	# collapse that killed the mount-scaling attempt.
	tpp_arm.rotation_degrees.x = lerpf(
		TPP_MIN_PITCH_DEG, _tpp_base_pitch_deg, ratio)

func _mount_height_for(capsule_height: float) -> float:
	var clearance := TPP_MOUNT_CLEARANCE_AT_PERSON_SCALE * (capsule_height / PERSON_CAPSULE_HEIGHT)
	return capsule_height / 2.0 + clearance

## Exactly one camera should be `current` at a time (per local peer) — the
## public API queue item 1's unit switcher hands control between units
## with, and what a networked spawn calls on itself above. Disables _process
## on an inactive rig so four idle rigs aren't doing four cameras' worth of
## work for nothing.
func set_active(active: bool) -> void:
	_active = active
	fpp_camera.current = active and _mode == Mode.FPP
	tpp_camera.current = active and _mode == Mode.TPP
	set_process(active)
	set_process_unhandled_input(active and aim_source == AimSource.MOUSE)
	# B-61: the self-hide depends on whether this rig is the one being looked
	# through, so it has to be re-evaluated whenever that changes — not just
	# once at _ready().
	_apply_fpp_self_hide()

## The rig mode (FPP/TPP) is derived and untouchable (§0.1) — this only
## chooses how the ACTIVE rig reads aim input, never what mode it renders in.
func set_aim_source(source: AimSource) -> void:
	aim_source = source
	set_process_unhandled_input(_active and aim_source == AimSource.MOUSE)

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
	var held: Carriable = carrier.held() if carrier != null else null
	var wanted := _viewmodel_rest
	if held != null and is_instance_valid(held) and held.get_parent() is Node3D:
		# ⚠️ THE CARRYING ARM IS SCALED DOWN, and that is not a cheat.
		#
		# The slipper rides only ~0.48 units in front of the eye
		# (HAND_CARRY_OFFSET, chosen so it never covers the crosshair), while the
		# forearm mesh is 0.84 long. Any full-size arm reaching that point has to
		# pass within centimetres of the lens, and at a 95-degree FOV that fills
		# half the frame — measured twice, once with the elbow projected back from
		# the slipper (elbow ended up BEHIND the camera) and once with the elbow
		# anchored and the forearm stretched (still a wall of skin on the right).
		#
		# So the carrying arm renders at VIEWMODEL_CARRY_SCALE. It reads as a hand
		# at arm's length rather than a forearm across the lens, and because the
		# fist is placed exactly ON the carried unit the slipper is unambiguously
		# held. The empty hand keeps its full size — nothing is close enough to
		# the eye there for it to matter.
		var target := fpp_pivot.to_local((held.get_parent() as Node3D).global_position)
		var dir := VIEWMODEL_CARRY_DIR.normalized()
		var reach := VIEWMODEL_ARM_LENGTH * VIEWMODEL_CARRY_SCALE
		var elbow := target - dir * reach
		# Any stable reference works; the arm never approaches vertical here, so
		# the cross product is always well conditioned.
		var right_axis := dir.cross(Vector3.FORWARD).normalized()
		wanted = Transform3D(Basis(right_axis * VIEWMODEL_CARRY_SCALE,
			dir * VIEWMODEL_CARRY_SCALE,
			right_axis.cross(dir) * VIEWMODEL_CARRY_SCALE), elbow)

	pivot.transform = pivot.transform.interpolate_with(
		wanted, clampf(VIEWMODEL_REACH_SPEED * delta, 0.0, 1.0))


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
	var carrier: CharacterBase = null
	if _carriable != null and _carriable.state == Carriable.CarryState.CARRIED:
		carrier = _carriable.carrier
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
	var yaw_basis := Basis(Vector3.UP, carrier.rotation.y + deg_to_rad(_tpp_carry_yaw_deg))
	var pitch_basis := Basis(Vector3.RIGHT, deg_to_rad(-15.0 + _tpp_carry_pitch_deg))
	tpp_arm.global_transform = Transform3D(
		yaw_basis * pitch_basis, carrier.global_position + Vector3.UP * TPP_CARRY_MOUNT_HEIGHT)

func _process(delta: float) -> void:
	_update_viewmodel_carry(delta)
	_update_tpp_carry_follow()
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
	arm.rotation.x = VIEWMODEL_WINDUP_RAD * clampf(power, 0.0, 1.0)


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
	if player == null or not player.has_animation(kind):
		return
	player.play(kind)


func _apply_fpp_self_hide() -> void:
	# The viewmodel is the inverse of the self-hide: it is the one thing that
	# must appear exactly when the rest of the body is being looked past. Driven
	# from here rather than from set_active() so it can never disagree with the
	# body it is standing in for — both states come off the same two flags.
	var arms := _viewmodel_arms()
	if arms != null:
		arms.visible = _active and _mode == Mode.FPP

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
	if _mode == Mode.TPP and _carriable != null and _carriable.state == Carriable.CarryState.CARRIED:
		_tpp_carry_yaw_deg -= relative.x * sensitivity
		var carry_pitch_delta := relative.y * (-1.0 if SettingsManager.invert_y else 1.0)
		_tpp_carry_pitch_deg = clamp(
			_tpp_carry_pitch_deg - carry_pitch_delta * sensitivity, PITCH_MIN_DEG, PITCH_MAX_DEG)
		return
	_character.rotation.y -= deg_to_rad(relative.x * sensitivity)
	if _mode == Mode.FPP:
		var pitch_delta := relative.y * (-1.0 if SettingsManager.invert_y else 1.0)
		_pitch_deg = clamp(_pitch_deg - pitch_delta * sensitivity, PITCH_MIN_DEG, PITCH_MAX_DEG)
		fpp_pivot.rotation.x = deg_to_rad(_pitch_deg)
