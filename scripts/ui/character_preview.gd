extends SubViewportContainer
class_name CharacterPreview

## The CHARACTER screen's backdrop: the roster entry you actually have selected,
## live in 3D, turning on the spot and swapping the instant you cycle the picker.
##
## Deliberately the same shape as `map_preview.gd` — own_world_3d SubViewport,
## our camera not the scene's, instances cached and RE-PARENTED rather than
## hidden. Read that file's header for the reasoning behind each of those; it is
## the same reasoning and there is no point restating it twice. What follows is
## only what differs because the subject is a character rather than a map.
##
## ⚠️ IT LIGHTS ITSELF. A map brings its own WorldEnvironment, sun and fog; a
## bare .glb brings nothing, so a character dropped into an empty own_world_3d
## viewport renders as a black silhouette. The light rig below is part of the
## scene, not decoration — without it there is nothing to look at.
##
## ⚠️ IT TURNS, IT DOES NOT ORBIT. Same call `map_preview.gd` makes and for a
## sharper reason: these rigs have a FRONT. A full camera orbit would spend half
## its time showing the player the back of a head, and the one thing this screen
## exists to communicate — who is this, what do they look like — is on the face.
## So the camera is fixed at a chosen three-quarter angle and the CHARACTER turns
## slowly through a limited arc, which shows the silhouette from both sides while
## never leaving the face for long.
##
## ⚠️ THE PREVIEW IS A PLAIN .glb, NOT A CharacterBase. It has no capsule, no
## camera rig, no Carrier and no nameplate, and it must not: instancing a real
## character here would start an FPP rig, a hurtbox and a state machine running
## inside a menu. The palette is applied here the same way
## `character_visual.gd::_apply_person_material()` applies it in a match — as a
## surface OVERRIDE on the MeshInstance3D, never a write into the shared imported
## material — so what this screen shows and what spawns are the same recolour
## performed by the same mechanism, and cannot drift.

## ⚠️ THE CAMERA IS FRAMED FROM THE MODEL'S MEASURED BOUNDS, NOT FROM A TYPED-IN
## POSITION. The first version of this file hardcoded a position and a look
## target, and the first render came back with the character three times the
## height of the frame and its head cropped off — because a Kenney mini's native
## height was guessed rather than measured, and then multiplied by PERSON_SCALE.
##
## Measuring is also the only version that stays correct: the roster spans twelve
## different rigs and they are not all the same height, so any single hardcoded
## distance is wrong for most of them. `_frame()` below fits whatever it is
## actually given.

## Horizontal angle the subject is viewed from, degrees off front-on. A slight
## three-quarter so the silhouette has some depth rather than reading as a
## cardboard cutout.
const CAMERA_YAW_DEGREES: float = 18.0
## How far the camera is raised above the subject, degrees. Positive looks DOWN.
## See _frame() — this is what stops a flat object being viewed edge-on.
const CAMERA_PITCH_DEGREES: float = 16.0
## The same angle for a subject that is flat on the ground — see _frame(), which
## lerps between the two on the subject's own height:width ratio.
const CAMERA_PITCH_FLAT_DEGREES: float = 52.0
## How much taller than the subject the framed view is — 1.0 would put the head
## and feet exactly on the frame edges.
##
## ⚠️ MEASURED AGAINST THE REST POSE, WHICH IS A T-POSE, AND THAT IS WHY THIS IS
## GENEROUS. `MeshInstance3D.get_aabb()` on a skinned mesh returns the bounds of
## the REST pose, not of the clip actually playing. The idle below folds the arms
## in, so the real silhouette is narrower than what was measured but its head
## sits slightly HIGHER than the T-pose bounds predict — which cropped the top of
## the head on the first pass at a tighter margin.
const FRAME_MARGIN: float = 1.62
## Where the subject's eyeline sits vertically, as a fraction of its own height.
## Just above centre: enough that the camera reads as looking at a standing
## figure rather than up its nose, without pushing the feet out of frame.
const AIM_HEIGHT_RATIO: float = 0.54

## The clip the preview stands in. `idle` is the one every Kenney rig ships and
## the same one `character_visual.gd::_play_locomotion()` falls back to, so the
## character is posed here exactly as it stands still in a match.
##
## ⚠️ WITHOUT THIS THE SCREEN SHOWS A T-POSE. The rig's rest pose is arms
## straight out, which is what the first render came back with — it reads as
## unfinished art more loudly than any modelling flaw would, and it is also
## nearly twice as wide as the real silhouette, so it wrecks the framing above.
const IDLE_CLIP: String = "idle"

## Pushes the subject to the RIGHT of frame, as a FRACTION OF THE VISIBLE WIDTH
## at whatever distance the subject ended up being framed from. Every control on
## this screen sits in the left third (the wood panel, the banner, both buttons),
## exactly as GameSetup's do, so a centred subject would stand behind them.
##
## ⚠️ A RATIO, NOT A CONSTANT OFFSET, AND THAT IS NOT A REFINEMENT. `h_offset` is
## a frustum shift in WORLD UNITS, so its on-screen effect scales with how far
## away the subject is. A fixed value tuned for a ~4-unit Person framed from ~5
## units away pushed the 0.3-unit lata — framed from well under a metre —
## completely off the right edge of the screen. Only the tsinelas and lata tabs
## showed it, because only they are small.
##
## Negative shifts the frustum left, which puts the subject right.
const FRAME_H_OFFSET_RATIO: float = -0.19

## Matches CharacterVisual.PERSON_SCALE. The rigs are authored small and every
## Person in a match is scaled up by it; previewing at native scale would frame a
## doll and make the tuned camera above meaningless.
const PREVIEW_SCALE: float = 2.38

## The turn. A slow sweep through a limited arc rather than a full spin — see the
## header. Degrees either side of front-on, and seconds for a full there-and-back.
const TURN_DEGREES: float = 38.0
const TURN_PERIOD: float = 9.0

@onready var viewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/Camera3D
@onready var pivot: Node3D = $SubViewport/Pivot

var _cache: Dictionary = {}      ## StringName -> Node3D, parked out of tree
var _current: Node3D = null
var _current_id: StringName = &""
var _time: float = 0.0

func _ready() -> void:
	pass

## Fits the camera to `model`'s real bounds. Called once per character, after it
## is in the tree so the transforms are live.
##
## The AABB is merged from every MeshInstance3D rather than read off one of them:
## a Kenney mini is two meshes (`body-mesh` and `head-mesh`) and framing on
## either alone crops the other. Each is transformed into the pivot's space
## first, because they sit under a Skeleton3D with its own transform and their
## local AABBs are not comparable.
func _frame(model: Node3D) -> void:
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var world := mesh_instance.global_transform * mesh_instance.get_aabb()
		if first:
			bounds = world
			first = false
		else:
			bounds = bounds.merge(world)
	if first:
		return # nothing to look at; leave the camera where it was

	var height: float = maxf(bounds.size.y, 0.001)
	# The widest the subject can present as it turns — it rotates about Y, so at
	# some point in the sweep its longest horizontal axis faces the camera.
	var width: float = maxf(maxf(bounds.size.x, bounds.size.z), 0.001)
	var aim := Vector3(bounds.get_center().x,
		bounds.position.y + height * AIM_HEIGHT_RATIO, bounds.get_center().z)

	# ⚠️ FIT BOTH AXES, NOT JUST HEIGHT. Fitting on height alone is right for a
	# standing Person and catastrophic for a tsinelas, which is 0.432 long and
	# 0.078 tall: framing it to be 0.078 units tall on screen put the camera
	# inside it, and the tab rendered as an abstract brown landscape. The lata is
	# the other way round again. Take whichever axis needs the camera further
	# back.
	var half_fov: float = tan(deg_to_rad(camera.fov) * 0.5)
	var size := viewport.size
	var aspect: float = (float(size.x) / float(size.y)) if size.y > 0 else 1.777
	var distance: float = maxf(
		(height * FRAME_MARGIN * 0.5) / half_fov,
		(width * FRAME_MARGIN * 0.5) / (half_fov * aspect))

	# Elevated rather than level with the subject, for the same reason: a flat
	# object seen edge-on from its own height is a sliver. Looking down at it
	# shows the face that reads as "a slipper", and on a standing Person the same
	# angle is just a natural slight downward gaze.
	# ⚠️ THE PITCH SCALES WITH HOW FLAT THE SUBJECT IS. A single angle cannot serve
	# both tabs: 16 degrees is a natural gaze on a standing Person and still
	# nearly edge-on to a tsinelas, which is five times wider than it is tall and
	# read as an anonymous brown lump at that angle. Flatness is height/width —
	# ~1.0 for a Person, ~0.18 for a slipper — so lerping the pitch on it looks
	# each subject in its own most legible face without a per-entry tuning value.
	var flatness: float = clampf(height / width, 0.0, 1.0)
	var pitch: float = lerpf(CAMERA_PITCH_FLAT_DEGREES, CAMERA_PITCH_DEGREES, flatness)
	var offset := Basis(Vector3.UP, deg_to_rad(CAMERA_YAW_DEGREES)) \
		* Basis(Vector3.RIGHT, deg_to_rad(pitch)) * Vector3(0.0, 0.0, distance)
	camera.position = aim + offset
	camera.look_at(aim)

	# The off-centre framing, re-derived for THIS subject's distance — see
	# FRAME_H_OFFSET_RATIO for why it cannot be a constant.
	camera.h_offset = FRAME_H_OFFSET_RATIO * (2.0 * distance * half_fov) * aspect

func _process(delta: float) -> void:
	if _current == null:
		return
	_time += delta
	pivot.rotation.y = deg_to_rad(sin(_time * TAU / TURN_PERIOD) * TURN_DEGREES)

## Same leak this exists to stop in map_preview.gd: Godot only frees nodes that
## are IN the tree when their owner goes, and the parked ones deliberately are
## not. Without this, cycling the roster leaks every character looked at.
func _exit_tree() -> void:
	for model in _cache.values():
		if is_instance_valid(model) and model.get_parent() == null:
			model.free()
	_cache.clear()

## Shows the character described by a `CharacterRoster.ROSTER` entry. Cheap to
## call with the entry already showing — the picker fires this on every press.
func show_character(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var id: StringName = entry["id"]
	if id == _current_id:
		return

	if _current != null:
		pivot.remove_child(_current)
	_current_id = id
	_current = _cache.get(id)

	if _current == null:
		var packed := load(String(entry["model"])) as PackedScene
		if packed == null:
			push_warning("CharacterPreview: could not load '%s'" % entry["model"])
			_current_id = &""
			return
		_current = packed.instantiate()
		_current.scale = Vector3.ONE * PREVIEW_SCALE
		_apply_material(_current, String(entry["material"]))
		_cache[id] = _current
	# Re-asserted on every show, not only on first instance: a cached model comes
	# back from the parked dictionary with its AnimationPlayer stopped, so a
	# character revisited by cycling the picker would return to a T-pose.
	_play_idle(_current)

	pivot.add_child(_current)
	# Restart the sweep on every swap so each character is first seen from the
	# same angle. Otherwise the arc's phase carries over and one pick greets you
	# front-on while the next shows you its ear.
	_time = 0.0
	pivot.rotation.y = 0.0
	# AFTER add_child and after the rotation reset: _frame() reads
	# `global_transform`, which is only meaningful once the model is in the tree,
	# and it must measure the character square-on rather than mid-turn.
	_frame(_current)

## The two Prop visuals, matching CharacterVisual's own constants. Referenced
## rather than retyped so a re-authored lata or tsinelas cannot leave this screen
## previewing a model the match no longer uses.
const CAN_VISUAL: String = "res://scenes/characters/visuals/CanVisual.tscn"
const TSINELAS_VISUAL: String = "res://scenes/characters/visuals/TsinelasVisual.tscn"

## Props are shown at their own scale, not PERSON_SCALE — they are small objects
## and `_frame()` fits whatever it is given, so the lata fills the frame the same
## way a Person does without either being resized to match the other.
##
## Shows the lata or tsinelas skin described by a `CharacterRoster.CANS` /
## `.SLIPPERS` entry.
##
## ⚠️ THE TINT IS APPLIED THE SAME WAY THE MATCH APPLIES IT — as `albedo_color`
## on a toon ShaderMaterial — but it CANNOT reuse `character_visual.gd`'s path,
## because that builds its toon materials inside `_apply_toon_pass()` on a live
## CharacterBase and this screen has no CharacterBase. So the tint is written
## onto a duplicated copy of whatever material the visual ships with, which gets
## the same colour onto the same surfaces without instancing a character.
func show_prop(entry: Dictionary, is_can: bool) -> void:
	if entry.is_empty():
		return
	var id: StringName = entry["id"]
	if id == _current_id:
		return

	if _current != null:
		pivot.remove_child(_current)
	_current_id = id
	_current = _cache.get(id)

	if _current == null:
		var packed := load(CAN_VISUAL if is_can else TSINELAS_VISUAL) as PackedScene
		if packed == null:
			_current_id = &""
			return
		_current = packed.instantiate()
		_tint(_current, entry.get("tint", Color.WHITE))
		_cache[id] = _current

	pivot.add_child(_current)
	_time = 0.0
	pivot.rotation.y = 0.0
	_frame(_current)

## Recolours a previewed Prop. Duplicates per MeshInstance3D surface first —
## without that, tinting one lata skin would recolour every other cached one,
## since they all came from the same PackedScene and share its materials.
func _tint(model: Node3D, colour: Color) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in range(mesh_instance.get_surface_override_material_count()):
			var source: Material = mesh_instance.get_active_material(surface)
			if source == null:
				continue
			var duped := source.duplicate()
			if duped is BaseMaterial3D:
				(duped as BaseMaterial3D).albedo_color = colour
			elif duped is ShaderMaterial:
				var shader_mat := duped as ShaderMaterial
				if shader_mat.get_shader_parameter("albedo_color") == null:
					continue
				shader_mat.set_shader_parameter("albedo_color", colour)
			mesh_instance.set_surface_override_material(surface, duped)

## Stands the preview in its idle. Looked up by type rather than by path — the
## rigs are CC0 imports and their internal node layout is not ours to depend on,
## which is the same rule `character_visual.gd::_play_idle()` follows.
func _play_idle(model: Node3D) -> void:
	var animator := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator == null or not animator.has_animation(IDLE_CLIP):
		return
	animator.play(IDLE_CLIP)

## The roster palette, as a surface override — see the header for why never a
## write into the loaded material. Identical in mechanism to
## `character_visual.gd::_apply_person_material()`; if you change one, change
## both, because "the preview showed someone else" is precisely the bug this
## symmetry exists to make impossible.
func _apply_material(model: Node3D, material_path: String) -> void:
	if material_path.is_empty():
		return
	var material := load(material_path) as ShaderMaterial
	if material == null:
		push_warning("CharacterPreview: could not load palette '%s'" % material_path)
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in range(mesh_instance.get_surface_override_material_count()):
			mesh_instance.set_surface_override_material(surface, material)
