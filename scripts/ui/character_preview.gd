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
## exactly as the setup screen's do, so a centred subject would stand behind them.
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

## ---------------------------------------------------------------------------
## PLAYER CAMERA CONTROL — "allow us to control the camera in the character
## selection screen to fix the weird viewing angle for the slippers."
##
## The auto-framing below is measurement-driven and gets a Person right every
## time, but a tsinelas is 0.432 long by 0.078 tall and there is no single fixed
## angle that flatters BOTH a standing figure and a flat object lying down.
## `_frame()` already lerps the pitch on how flat the subject is, which was the
## previous attempt at this; it improved the slipper and did not settle it,
## because "the right angle for a slipper" is a taste question and the person
## holding the taste is the one at the keyboard.
##
## So the framing becomes a STARTING POINT rather than the answer, and the player
## can move from there:
##
##   drag with the left mouse button   orbit (yaw freely, pitch clamped)
##   mouse wheel                       dolly in and out
##   right-click                       snap back to the auto-framed shot
##
## ⚠️ THE ORBIT IS AN OFFSET ON TOP OF THE FRAMING, NOT A REPLACEMENT FOR IT.
## `_frame()` still computes distance, aim height and the h_offset that keeps the
## subject clear of the wood panel, and every one of those is derived from the
## measured bounds of whatever was just instanced. The player's input adds a yaw
## and a pitch delta and a distance multiplier to that result. Framing a 0.3-unit
## lata and a 4-unit Person with one hand-typed camera position is exactly the bug
## this file's own header was written about; handing the whole camera to the mouse
## would put it straight back.
##
## ⚠️ AND THE AUTO-TURN STOPS THE MOMENT THE PLAYER TOUCHES IT. A subject that is
## being dragged and also rotating on its own is unusable — you cannot aim at a
## detail that is walking away from you. The idle sweep is a screensaver for a
## screen nobody is interacting with, so it yields to anyone who is.
const ORBIT_SENSITIVITY: float = 0.4
const ORBIT_PITCH_MIN: float = -55.0
const ORBIT_PITCH_MAX: float = 70.0
## Multiplier bounds on the auto-framed distance. Tighter than a free-fly camera
## on purpose: inside 0.55 the near plane starts clipping a slipper, and past 2.2
## the subject is a speck and the player has lost the thing they came to look at.
const ZOOM_MIN: float = 0.55
const ZOOM_MAX: float = 2.2
const ZOOM_STEP: float = 0.12

@onready var viewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/Camera3D
@onready var pivot: Node3D = $SubViewport/Pivot

var _cache: Dictionary = {}      ## StringName -> Node3D, parked out of tree
var _current: Node3D = null
var _current_id: StringName = &""
var _time: float = 0.0

## The auto-framed shot, kept so the player's offsets can be re-applied to it and
## so right-click can restore it exactly.
var _frame_aim: Vector3 = Vector3.ZERO
var _frame_distance: float = 4.0
var _frame_pitch: float = 16.0
var _frame_half_fov: float = 0.4
var _frame_aspect: float = 1.777

## The player's offsets on top of it. All three are deliberately preserved across
## a subject change: somebody who has found the angle they want to judge slippers
## from should keep it while cycling slippers, not have to re-find it six times.
var _user_yaw: float = 0.0
var _user_pitch: float = 0.0
var _user_zoom: float = 1.0
var _dragging: bool = false
## True once the player has touched the camera at all — see the header for why
## the idle turn yields rather than fighting them.
var _user_took_over: bool = false
## True when this rig is a centred TILE rather than a screen backdrop — see
## `set_tile_framing()`. Zeroes the off-centre `h_offset` below.
var _centre_subject: bool = false
## Set with `set_tile_framing()`. See the ⚠️ in `_frame()`.
var _uniform_extent: bool = false

func _ready() -> void:
	# A SubViewportContainer defaults to ignoring the mouse. It has to receive
	# clicks for any of the above to happen, and it is behind every control on
	# this screen, so the panel and the buttons still get first refusal.
	mouse_filter = Control.MOUSE_FILTER_PASS
	# ⚠️⚠️ RE-FRAME ON RESIZE, AND THIS IS A REAL BUG NOT A REFINEMENT.
	#
	# `_frame()` divides by the viewport's ASPECT to decide how far back the
	# camera has to sit, and it is called from `show_character()`/`show_prop()` —
	# which run during `_ready()`, BEFORE the container has been laid out. At that
	# point `viewport.size.y` is 0, the aspect falls through to the 1.777 default,
	# and the distance is computed for a frame that does not exist yet. Whatever
	# the real window then turns out to be, the subject is framed for something
	# else: rendered at 1920x1080 it filled the screen with its feet cropped off.
	#
	# That is also the honest explanation for the reported "weird viewing angle
	# for the slippers" — the pitch lerp was doing its job and the DISTANCE was
	# wrong, which reads as a bad angle because the subject is too close to judge.
	# The manual camera above is the feature that was asked for; this is the
	# framing being correct in the first place.
	resized.connect(_on_resized)

func _on_resized() -> void:
	if _current != null and is_instance_valid(_current):
		_frame(_current)

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
	# ⚠️ THREE TERMS, AND THE THIRD IS THE ONE THE SLIPPER NEEDED.
	#
	# The first two fit the subject's HEIGHT against the frame's height and its
	# WIDTH against the frame's width, which silently assumes the subject's widest
	# horizontal axis lands on screen X. For a standing Person that holds. For a
	# tsinelas it does not, and that is the whole of "the weird viewing angle for
	# the slippers": the camera looks DOWN at a flat object by ~46 degrees (see the
	# pitch lerp below), so the slipper's own long axis projects onto screen Y —
	# where it is being measured against a frame that is 1.78x SHORTER than the one
	# it was fitted to. Measured at 1920x1080: fitted distance 0.641 for a 0.54-long
	# slipper, visible frame height 0.492, so 10% of the subject was outside the
	# frame before it had even started turning.
	#
	# The third term fits the widest horizontal extent against the SHORT axis of
	# the frame, which is true whichever way that axis ends up pointing. It is the
	# conservative one by construction, so it only ever binds for subjects that are
	# wider than they are tall — a Person's width and height are within a few
	# percent of each other, so this changes its framing by nothing.
	var distance: float = maxf(maxf(
		(height * FRAME_MARGIN * 0.5) / half_fov,
		(width * FRAME_MARGIN * 0.5) / (half_fov * aspect)),
		(width * FRAME_MARGIN * 0.5) / half_fov)

	# ⚠️ UNIFORM MODE: EVERY SUBJECT'S LONGEST AXIS GETS THE SAME SCREEN LENGTH.
	#
	# 🧑, looking at the tutorial's premise strip: *"why not make everything size
	# of lata"*. The four tiles are the same box and every subject was "fitted" to
	# it, yet the can dwarfed the person and the slipper. Fitting is not sizing:
	# the rule above takes whichever axis needs the camera furthest back, so a TALL
	# narrow subject (the lata) binds on HEIGHT and fills the tile top to bottom,
	# while a subject that is as wide as it is tall (a person, arms out) binds on
	# WIDTH and is then only as tall as its own aspect allows. Both "fill the
	# frame"; only one looks big. A flat slipper is the extreme case.
	#
	# So this mode measures one number per subject — its longest extent, whichever
	# axis that is — and fits THAT to the frame's short side. The lata's height,
	# the person's height and the slipper's length all land on the same on-screen
	# length, which is what "the same size" means to someone looking at the strip.
	#
	# ⚠️ OPT-IN, AND THE CHARACTER SCREEN MUST NOT GET IT. There a subject is alone
	# at full size and should use the whole frame; equalising against a slipper's
	# length would push a person away for no reason. Only the tutorial's tiles ask
	# for this, via `set_tile_framing(zoom, true)`.
	if _uniform_extent:
		var extent: float = maxf(height, width)
		distance = (extent * FRAME_MARGIN * 0.5) / (half_fov * minf(aspect, 1.0))

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

	# Everything above is the MEASURED shot. Stored rather than applied directly,
	# so the player's own orbit can be layered on it — see the header.
	_frame_aim = aim
	_frame_distance = distance
	_frame_pitch = pitch
	_frame_half_fov = half_fov
	_frame_aspect = aspect
	_apply_camera()

## Puts the camera where the measured framing says, plus whatever the player has
## dragged. The single place `camera.position`, `look_at` and `h_offset` are
## written, so the auto and manual paths cannot disagree about any of the three.
func _apply_camera() -> void:
	var distance: float = _frame_distance * _user_zoom
	var yaw: float = CAMERA_YAW_DEGREES + _user_yaw
	var pitch: float = clampf(_frame_pitch + _user_pitch, ORBIT_PITCH_MIN, ORBIT_PITCH_MAX)
	var offset := Basis(Vector3.UP, deg_to_rad(yaw)) \
		* Basis(Vector3.RIGHT, deg_to_rad(pitch)) * Vector3(0.0, 0.0, distance)
	camera.position = _frame_aim + offset
	camera.look_at(_frame_aim)

	# The off-centre framing, re-derived for THIS subject's CURRENT distance — see
	# FRAME_H_OFFSET_RATIO for why it cannot be a constant. It has to follow the
	# zoom too, or dollying in walks the subject back behind the wood panel.
	# ⚠️ Skipped entirely for a TILE, which has no panel to clear and is cropped by this
	# rather than helped by it — see `set_tile_framing()`.
	camera.h_offset = 0.0 if _centre_subject \
		else FRAME_H_OFFSET_RATIO * (2.0 * distance * _frame_half_fov) * _frame_aspect

## ⚠️ `_gui_input`, NOT `_unhandled_input`. This is a Control sitting behind the
## whole screen, and the panel, the tabs and both buttons are in front of it — a
## drag that starts on a button must belong to the button. `_gui_input` only fires
## for events that actually landed on THIS control, which is that rule for free.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = button.pressed
				if button.pressed:
					_user_took_over = true
					accept_event()
			MOUSE_BUTTON_RIGHT:
				if button.pressed:
					reset_view()
					accept_event()
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_by(-ZOOM_STEP)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by(ZOOM_STEP)
				accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := (event as InputEventMouseMotion).relative
		_user_yaw -= motion.x * ORBIT_SENSITIVITY
		_user_pitch -= motion.y * ORBIT_SENSITIVITY
		_user_pitch = clampf(_user_pitch, ORBIT_PITCH_MIN - _frame_pitch,
			ORBIT_PITCH_MAX - _frame_pitch)
		_apply_camera()
		accept_event()

func _zoom_by(amount: float) -> void:
	_user_took_over = true
	_user_zoom = clampf(_user_zoom + amount, ZOOM_MIN, ZOOM_MAX)
	_apply_camera()

## TILE FRAMING: subject CENTRED in its box and pulled in to fill it. For a caller showing
## this rig as a small picture rather than as a screen backdrop.
##
## ⚠️ TWO CHANGES, AND BOTH ARE NEEDED — the first attempt did only the zoom and the render
## came back with the lata cropped top and bottom and the running figure cropped through
## its feet and its right side.
##
## 1. `FRAME_MARGIN` is 1.62 — 62% air around the subject. Right on the CHARACTER screen,
##    where the figure shares the frame with a wood panel and must sit clear of it, and
##    measured against a T-POSE so it has to be generous. In a 250px tile that same margin
##    is the *"big negative space"* that was reported.
## 2. ⚠️ `h_offset` IS WHY IT CROPPED SIDEWAYS. `_apply_camera()` always shoves the subject
##    off-centre by `FRAME_H_OFFSET_RATIO`, so the character screen's figure clears the
##    panel on the left. In a centred tile there is no panel to clear — the offset just
##    walks the subject towards one edge, and any zoom then pushes it out of frame. A tile
##    has to zero it, which is what `_centre_subject` does.
##
## ⚠️ DOES NOT SET `_user_took_over`, unlike `_zoom_by()`. That flag means "a human has
## taken the camera, stop moving it", and this is the SCREEN choosing its own framing — if
## it set the flag it would silently kill the idle turn on all four tiles.
func set_tile_framing(factor: float, uniform_extent: bool = false) -> void:
	_centre_subject = true
	_uniform_extent = uniform_extent
	_user_zoom = clampf(factor, ZOOM_MIN, ZOOM_MAX)
	# ⚠️ RE-FRAME, DO NOT ONLY RE-AIM. `_uniform_extent` changes what `_frame()`
	# COMPUTES, and the subject was already framed by `show_prop`/`show_character`
	# before this call — so applying the camera alone would keep the old distance
	# and the flag would appear to do nothing.
	if _current != null and is_instance_valid(_current):
		_frame(_current)
	_apply_camera()

## Back to the measured shot, and back to turning on its own. Public because the
## screen may want to offer it as a button later; bound to right-click today.
func reset_view() -> void:
	_user_yaw = 0.0
	_user_pitch = 0.0
	_user_zoom = 1.0
	_user_took_over = false
	_time = 0.0
	pivot.rotation.y = 0.0
	_apply_camera()

func _process(delta: float) -> void:
	if _current == null:
		return
	# The idle sweep yields to the player — see the header. Left running, a
	# subject the player is trying to inspect rotates out from under the angle
	# they just chose, which makes the control feel broken rather than free.
	if _user_took_over:
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
		# ⚠️ SWAP THE MESH BEFORE TINTING, exactly as `lata.gd`/`slipper.gd` do.
		# Without this every lata skin previewed as the SAME can and every tsinelas
		# as the same slipper: this screen instantiated the shared
		# CanVisual/TsinelasVisual scene and only recoloured it, which was right
		# while a skin WAS only a colour. Since 2026-08-01 a skin is a MODEL as
		# well (see character_roster.gd's `model` key), so a preview that only
		# tints is a control that lies about what you are picking — the exact
		# failure THE REACHABILITY RULE's second half describes.
		_apply_model(_current, entry)
		_tint(_current, entry.get("tint", Color.WHITE))
		_cache[id] = _current

	pivot.add_child(_current)
	_time = 0.0
	pivot.rotation.y = 0.0
	_frame(_current)

## Recolours a previewed Prop. Duplicates per MeshInstance3D surface first —
## without that, tinting one lata skin would recolour every other cached one,
## since they all came from the same PackedScene and share its materials.
## Points the previewed prop at the mesh its roster entry names, so the screen
## shows the object the match will spawn. Mirrors `Lata::_apply_model()`.
func _apply_model(model: Node3D, entry: Dictionary) -> void:
	if not entry.has("model"):
		return
	var target := model.find_children("*", "MeshInstance3D", true, false)
	if target.is_empty():
		return
	var mesh := load(String(entry["model"])) as Mesh
	if mesh == null:
		push_warning("CharacterPreview: cannot load %s" % entry["model"])
		return
	var instance := target[0] as MeshInstance3D
	# Overrides do not clear themselves when the mesh under them changes, and the
	# surface counts need not match — same rule as the two props.
	for surface in range(instance.get_surface_override_material_count()):
		instance.set_surface_override_material(surface, null)
	instance.mesh = mesh

## Recolours a previewed Prop.
##
## ⚠️ WHITE MEANS "DO NOT TINT", matching `lata.gd`/`slipper.gd`. Writing white
## into `albedo_color` is a no-op on a TEXTURED prop and a repaint on an
## UNTEXTURED one, and every slipper is untextured — so the tsinelas skins all
## previewed as a featureless white blob while the game rendered them correctly.
func _tint(model: Node3D, colour: Color) -> void:
	if colour == Color.WHITE:
		return
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
