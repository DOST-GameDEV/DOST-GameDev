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
## `docs/Interaction_Tuning_Agent_Brief.md` before changing it again.
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
## Playtest 0.4 first-person viewmodel arms, created on demand by
## _viewmodel_arms(). Null on every Prop and on any Person that has never
## been looked through.
var _arms: Node3D = null

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
	var visual := _character.get_node_or_null("Visual") as CharacterVisual
	if visual != null:
		visual.model_changed.connect(_apply_fpp_self_hide)
	_apply_fpp_self_hide()
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

func _process(delta: float) -> void:
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
	_character.rotation.y -= deg_to_rad(relative.x * sensitivity)
	if _mode == Mode.FPP:
		var pitch_delta := relative.y * (-1.0 if SettingsManager.invert_y else 1.0)
		_pitch_deg = clamp(_pitch_deg - pitch_delta * sensitivity, PITCH_MIN_DEG, PITCH_MAX_DEG)
		fpp_pivot.rotation.x = deg_to_rad(_pitch_deg)
