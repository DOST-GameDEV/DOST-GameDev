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

@export var aim_source: AimSource = AimSource.MOVEMENT

@onready var fpp_pivot: Node3D = $FppPivot
@onready var fpp_camera: Camera3D = $FppPivot/FppCamera
@onready var tpp_arm: SpringArm3D = $TppArm
@onready var tpp_camera: Camera3D = $TppArm/TppCamera

var _character: CharacterBase
var _mode: Mode
var _pitch_deg: float = 0.0
var _active: bool = false

func _ready() -> void:
	_character = get_parent() as CharacterBase
	_mode = Mode.FPP if _character.is_person else Mode.TPP
	# SpringArm3D's shapecast would otherwise hit the character's own capsule
	# every frame and drag the camera in against its own body.
	tpp_arm.add_excluded_object(_character.get_rid())
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
## public API the debug switcher (queue item 1) hands control between units
## with, and what a networked spawn calls on itself above. Disables _process
## on an inactive rig so four idle rigs aren't doing four cameras' worth of
## work for nothing.
func set_active(active: bool) -> void:
	_active = active
	fpp_camera.current = active and _mode == Mode.FPP
	tpp_camera.current = active and _mode == Mode.TPP
	set_process(active)
	set_process_unhandled_input(active and aim_source == AimSource.MOUSE)

## The rig mode (FPP/TPP) is derived and untouchable (§0.1) — this only
## chooses how the ACTIVE rig reads aim input, never what mode it renders in.
func set_aim_source(source: AimSource) -> void:
	aim_source = source
	set_process_unhandled_input(_active and aim_source == AimSource.MOUSE)

func _apply_fpp_self_hide() -> void:
	if _mode != Mode.FPP:
		return
	var visual_root := _character.get_node_or_null("Visual")
	if visual_root == null:
		return
	# "Visual" is a plain Node3D wrapper (see CharacterBase.tscn) so the whole
	# subtree can be hidden as one unit later once it holds a real multi-mesh
	# model — it is not itself a VisualInstance3D, so cast_shadow has to be
	# set on every mesh underneath it individually. NOT hide() — losing your
	# own shadow in FPP destroys the ground read, and other peers still need
	# to see the mesh.
	for node in visual_root.find_children("*", "GeometryInstance3D", true, false):
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
