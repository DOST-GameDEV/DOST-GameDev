extends Node3D
class_name SpectatorCamera

## SPECTATOR MODE — a free-flying camera with no body. `Design.md` §9.
##
## Human instruction, 2026-07-30: *"implement a Spectator option available in both
## Multiplayer and Singleplayer. The spectator acts as a free-flying camera with no
## physical model, capable of clipping through all geometry to fly anywhere."*
##
## ⚠️⚠️ THE CLIPPING IS BY CONSTRUCTION, NOT BY A COLLISION MASK, AND THAT IS THE WHOLE
## DESIGN OF THIS FILE. This is a plain `Node3D` with a `Camera3D` on it. It is not a
## `CharacterBody3D`, it has no `CollisionShape3D`, it is on no physics layer, and it
## never calls `move_and_slide` or `move_and_collide` — so there is nothing for the
## physics server to resolve and no mask anyone can get wrong later. Moving it is one
## `global_position +=`.
##
## The alternative — a body with `collision_layer = 0` and `collision_mask = 0` — looks
## equivalent and is not: it still enters the broadphase, it still generates
## depenetration against anything that masks IT, and it is one accidental inspector edit
## away from a spectator who can be bumped by a slipper.
##
## ⚠️ AND IT SPAWNS NO CHARACTER AT ALL. A spectator claims no seat (`GameLaunch.
## spectator`, seat -1), is skipped by `main.gd::_spawn_player`, and is excluded from the
## ready gate — see `_expected_ready_count()`. Its slot is filled by the same
## placeholder-AI path that already fills an empty one, so a 2v2 stays a 2v2.
##
## ⚠️ IT IS NOT A PLAYER AND MUST NEVER BECOME ONE. Nothing here writes gameplay state,
## sends an RPC, or resolves a hit. If a future pass wants a spectator to be able to
## nudge anything, that is a different node.
##
## ⚠️⚠️ AND IT IS DRIVEN BY A HUMAN, ONLY, BY CONSTRUCTION. 🧑 human instruction,
## 2026-07-31: *"dont give spectator AI... spectator should only be controllable by a
## person."* Three things hold that, and none of them is a flag anyone has to remember:
##
##   * `AIController` steers a `CharacterBase`, through `character.ai_set_intent()`. This
##     is a `Node3D`. There is nothing here for a controller to attach to and no
##     `_attach_ai` call site that can reach it — `main.gd` only ever attaches one while
##     iterating characters.
##   * it reads the `Input` singleton DIRECTLY, and the AI deliberately does not. That
##     used to be the other way round and it was the bug `character_base.gd`'s
##     PER-CHARACTER INPUT block was written about: bots calling `Input.action_press()`
##     put process-global state where anything reading `Input` would pick it up. Since
##     that fix the bots write per-character intent and touch the global singleton not at
##     all, so a bot walking left cannot fly this camera left.
##   * the vacated SEAT is bot-filled and that is a different unit entirely
##     (`main.gd::_fill_empty_slots_with_placeholders`). A spectator's slot having a bot
##     in it is §2.3 working; the camera itself has no body for one to hold.
##
## If a "cinematic auto-cam" is ever wanted it is a new node with a new name, not an
## `AIController` bolted onto this one.

## Metres per second at the base speed. Faster than a Person's 4.6 walk — a spectator
## is covering a whole map, not a lane, and the point of the mode is to get to the
## interesting corner before the interesting thing stops happening.
##
## ⚠️⚠️ 12.0 -> 6.0 ON 2026-08-01, ON DIRECT HUMAN INSTRUCTION. 🧑: *"can u allow
## spectator to slow down huhu why is it so fast, barely controllable"*. 12.0 is
## **2.6x a Person's walk** and it crosses the whole 15 m court in 1.25 s, so every
## framing input was an overshoot-and-correct: the camera was tuned for TRAVELLING
## and the thing it is actually used for is WATCHING. 6.0 is still 30% faster than
## the players it follows, which keeps the "get there before it stops happening"
## property the note above is about, and Shift still triples it to 18.0 for the
## crossing case — so the fast camera is now a held key instead of the default.
##
## ⚠️ AND THE FLOOR CAME DOWN WITH IT. The wheel's range mattered less than it
## looks: at `SPEED_MIN` 3.0 the slowest the camera could go was still two thirds
## of a walk, which is not slow enough to hold a shot on the can. 1.2 is.
## ⚠️⚠️ 6.0 -> 3.6 ON 2026-08-02, ALSO ON DIRECT HUMAN INSTRUCTION, AND FOR A USE THIS
## CONSTANT HAD NOT BEEN TUNED FOR YET. 🧑: *"slow down spectator bcz it so fast, cant
## record anything with it ... spectator will be used as camera for cinematics but dont
## make it too slow"*.
##
## The note above tuned 12.0 down to 6.0 for WATCHING. Recording is a third thing again
## and it is stricter than either: a camera that is merely controllable still ruins a
## take, because every correction is in the footage. 6.0 is 30% faster than the players
## being filmed, so holding a player in frame meant riding the stick against them.
##
## 3.6 is deliberately BELOW a Person's 4.6 walk. That is the property that matters for a
## tracking shot — the camera drifts back through a moving subject rather than pulling
## ahead of them, which is the shot people actually want. It still crosses the 15 m court
## in about four seconds under its own power, so it is not a tripod.
const BASE_SPEED: float = 3.6
## Hold `sprint` (Shift) to boost. No stamina: the whole meter exists to make a chase a
## decision, and a spectator has nothing to decide.
##
## ⚠️ 3.0 -> 2.5, BECAUSE THE BOOST IS THE REPOSITIONING GEAR AND NOT A SECOND CAMERA.
## Against the old 6.0 base it was 18 m/s — four times a walk, and far too fast to stop
## anywhere on purpose, so the only usable thing to do with it was let go and re-aim.
## 2.5 against 3.6 is 9.0 m/s: the court in under two seconds when a shot is being SET
## UP, and still slow enough that the camera can be brought to rest on a mark.
const BOOST_SCALE: float = 2.5
## Mouse wheel adjusts the base speed between these, so a player framing a close shot of
## the can and a player crossing Bayan Plaza are not fighting the same number.
const SPEED_MIN: float = 1.2
const SPEED_MAX: float = 40.0
const SPEED_STEP: float = 1.35
## Matches `CameraRig.PITCH_MIN_DEG` / `PITCH_MAX_DEG` in spirit but is wider, because
## a free camera genuinely wants to look straight down at the circle. Stops just short of
## the poles, where yaw and pitch become the same axis and the view rolls.
const PITCH_LIMIT_DEG: float = 88.0
## Exponential smoothing rate on the position, so a hard stop reads as a camera being
## flown rather than as a teleport. Rotation is deliberately NOT smoothed — mouse-look
## with any smoothing on it feels like input lag.
const MOVE_SMOOTH_RATE: float = 14.0

## ⚠️ §2.6 — FOLLOW DISTANCE IS THE OTHER HALF OF "WIDE SHOTS AND CLOSE SHOTS BOTH".
## The wheel already retuned the FLY speed, which does nothing at all while following a
## unit, so the follow shot was a single fixed 6.5 m over-the-shoulder framing and the
## only way to get a close-up of the lata being knocked over was to leave follow mode and
## hand-fly. Same wheel, same gesture, and which number it moves depends on which mode
## you are in — because in each mode that is the only one of the two that does anything.
const FOLLOW_DISTANCE: float = 6.5
const FOLLOW_DISTANCE_MIN: float = 1.2
const FOLLOW_DISTANCE_MAX: float = 30.0
## Metres above the followed unit's origin. Scaled with the distance rather than held
## flat: a 1.2 m close-up wants to be near eye level and a 30 m wide wants to be looking
## down, and one constant cannot be both.
const FOLLOW_LIFT_RATIO: float = 0.34

## ---------------------------------------------------------------------------
## ⚠️⚠️ POV MODE — `V` — AND IT IS **THIS** CAMERA AT THEIR EYES, NOT THEIR RIG.
##
## 🧑 human instruction, 2026-07-31: *"spectator should be allowed to go to anywhere in the
## map and watch the povs of people/ai, thats why its called camera."* The first half was
## already true; this is the second.
##
## ⚠️ IT DOES NOT ACTIVATE THE TARGET'S `CameraRig`, AND THAT IS NOT A SHORTCUT — IT IS THE
## RULE. `Agent_Prompts.md` § PATHS: *"The spectator is not an exception to it either — it
## is a separate camera for a unit that has no body, not a third mode on the rig, which is
## why the two files can sit in different lanes at all."* `camera_rig.gd` is 🖥️ `build ux`'s
## file and the camera directive on it is marked non-negotiable.
##
## And going through the rig would not have been free even if it were allowed:
## `CameraRig.set_active(true)` also calls `set_process(true)` and
## `set_process_unhandled_input()` on that rig, so a spectator pressing `V` would start
## running a live AI unit's aim pipeline and feeding it this machine's mouse — from a node
## whose entire contract is that it writes no gameplay state. Watching somebody must not
## change what they do.
##
## So POV is a placement, not a takeover: this camera is parked at the unit's eye height
## and its YAW is locked to the unit's facing. Nothing is written to the unit at all — it
## does not know it is being watched, which is the only correct relationship here.
##
## ⚠️ PITCH STAYS WITH THE OPERATOR. A unit's pitch lives on its rig, not on its body
## (`camera_rig.gd`'s own class doc), and that rig is inactive for a bot — so there is no
## honest pitch to copy, and inventing one would be a made-up number presented as somebody
## else's view. Leaving pitch on the mouse is also the better camera: it is what lets a
## POV shot tilt down to the lata without leaving the shot.
const POV_EYE_HEIGHT_PERSON: float = 1.45
## A lata or a tsinelas is ankle-height and its "eyes" are a fiction anyway — low enough to
## read as the object's own view of the street, high enough not to sit inside the mesh.
const POV_EYE_HEIGHT_PROP: float = 0.42
## ⚠️ AND IT SITS SLIGHTLY IN FRONT OF THE EYES, NOT INSIDE THE HEAD. Rendered a POV shot
## and looked at it: the watched Person's own hat and shoulder hung in the bottom-left of
## the frame, because a real FPP rig HIDES the head mesh (`CameraRig.FPP_HIDDEN_MESH_HINT`)
## and this camera is a bystander that has not been given the right to hide anything.
## Stepping forward off the unit's own facing clears the model without writing a single
## property to it, which is the whole reason POV is a placement rather than a takeover.
const POV_FORWARD_OFFSET: float = 0.34

var _yaw: float = 0.0
var _pitch_deg: float = -18.0
var _speed: float = BASE_SPEED
var _target_position: Vector3 = Vector3.ZERO
var _camera: Camera3D = null
## Which unit the camera is following, or null for free flight. `Tab` cycles, `F` frees.
var _follow: Node3D = null
var _follow_index: int = -1
var _follow_distance: float = FOLLOW_DISTANCE
## POV rather than over-the-shoulder, for whatever `_follow` currently is. `V` toggles.
## Sticky across a `Tab` cycle on purpose: somebody filming POV shots wants to step
## through all four units in POV, not re-press `V` at every one.
var _pov: bool = false

func _ready() -> void:
	_camera = Camera3D.new()
	_camera.name = "SpectatorCamera3D"
	# A wider FOV than the gameplay rigs': a spectator is watching four units at once
	# rather than aiming at one, and the extra field is what makes the whole circle
	# readable from the side of the arena.
	_camera.fov = 78.0
	# `far` well past the map so a shot from outside the arena does not clip the
	# rooflines it is framing.
	_camera.far = 400.0
	add_child(_camera)
	_camera.current = true
	# Start above and behind the base circle, looking at it. The circle is at the world
	# origin on every map (`Art_Direction.md` §3), so this is map-independent by
	# construction rather than by a per-map marker somebody has to remember to add.
	global_position = Vector3(0.0, 9.0, 14.0)
	_target_position = global_position
	_yaw = 0.0
	_pitch_deg = -26.0
	_apply_rotation()
	# Mouse-look needs the cursor captured, exactly as the gameplay rigs do. `main.gd`
	# has already captured it by the time this is added; re-asserting is harmless and
	# covers the case where a spectator is created from a screen that had released it.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		# The same sensitivity model the gameplay rig uses, read through the same
		# settings multiplier — a spectator whose look speed disagrees with the game's
		# reads as a different game.
		var sensitivity := CameraRig.BASE_SENSITIVITY * SettingsManager.mouse_sensitivity
		_yaw -= deg_to_rad(motion.relative.x * sensitivity)
		var pitch_delta := motion.relative.y * sensitivity
		if SettingsManager.invert_y:
			pitch_delta = -pitch_delta
		_pitch_deg = clampf(_pitch_deg - pitch_delta, -PITCH_LIMIT_DEG, PITCH_LIMIT_DEG)
		_apply_rotation()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button := (event as InputEventMouseButton).button_index
		# Following: the wheel pulls in and pushes out. Free: it retunes the fly speed.
		# See FOLLOW_DISTANCE's own note for why one control does both.
		var following := _follow != null and is_instance_valid(_follow)
		if button == MOUSE_BUTTON_WHEEL_UP:
			if following:
				_follow_distance = clampf(_follow_distance / SPEED_STEP,
					FOLLOW_DISTANCE_MIN, FOLLOW_DISTANCE_MAX)
			else:
				_speed = clampf(_speed * SPEED_STEP, SPEED_MIN, SPEED_MAX)
		elif button == MOUSE_BUTTON_WHEEL_DOWN:
			if following:
				_follow_distance = clampf(_follow_distance * SPEED_STEP,
					FOLLOW_DISTANCE_MIN, FOLLOW_DISTANCE_MAX)
			else:
				_speed = clampf(_speed / SPEED_STEP, SPEED_MIN, SPEED_MAX)
		return

## ⚠️⚠️ `_input`, NOT `_unhandled_input`, AND ONLY FOR THESE TWO KEYS — BECAUSE TAB NEVER
## ARRIVED. Measured by `spec_probe --solo`: "TAB picks up a follow target — FAIL,
## following nothing", with the follow list correctly populated the whole time.
##
## `Tab` is bound to `ui_focus_next` in Godot's built-in InputMap, and the Viewport
## consumes focus-navigation keys during the GUI phase, which runs BEFORE
## `_unhandled_input`. The HUD is a live CanvasLayer of Controls, so there is always
## something for focus to move to — the press was being eaten by the UI and the follow
## cycle, the one control that makes this camera usable for anything but a static wide
## shot, could not be reached at all. It read as "Tab does nothing", which is
## indistinguishable from "the follow cycle is not built".
##
## Deliberately narrow: this handles exactly `Tab` and `F` and consumes only those, so
## nothing else on the screen — the pause toggle above all — loses an event to it. Mouse
## look and the wheel stay in `_unhandled_input` below, where they are not competing with
## anything.
##
## Raw keys rather than InputMap actions, still on purpose: adding two actions to
## `project.godot` for a spectator-only convenience would mean two more rows in the
## rebind panel, two more `input_probe` conflict checks, and a `settings.cfg` migration —
## for a mode with no gameplay stake at all. `project.godot` is also a shared-lock file.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_TAB:
			_cycle_follow()
			get_viewport().set_input_as_handled()
		KEY_F:
			_follow = null
			_follow_index = -1
			_pov = false
			get_viewport().set_input_as_handled()
		KEY_V:
			# A no-op in free flight rather than an error: there is no POV of nobody, and
			# a key that silently arms a mode you cannot see is worse than one that waits.
			if _follow != null and is_instance_valid(_follow):
				_pov = not _pov
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# ⚠️⚠️ IT RE-CLAIMS `current` EVERY FRAME, AND WITHOUT THIS THE WHOLE MODE IS A LIE.
	#
	# Found by rendering a spectated match and LOOKING at the frame, which is the half of
	# § THE REACHABILITY RULE that no assertion in `spec_probe` was covering: every control
	# measured correctly — the speed changed, TAB picked up a target, the HUD stripped —
	# and the picture was a Person's first-person view with its orange viewmodel arms
	# across the bottom of the shot. The camera was flying perfectly and nobody was looking
	# through it.
	#
	# `Camera3D.current` is winner-takes-all per viewport and the LAST writer wins.
	# `debug_player_switcher.gd::_apply_slots()` claims `DEFAULT_P1_UNIT` ("TeamAPerson")
	# whenever the DebugBar registers and calls `set_active(true)` on that unit's
	# `CameraRig` — which is exactly the seat a spectator has just vacated. `_ready()`
	# below sets `current` once, at spawn, and loses it silently some frames later.
	#
	# A one-shot re-assert would only move the race. This is authoritative instead, and
	# that is the correct reading rather than a workaround: a spectator has no rig, no
	# body and no seat, so for as long as this node exists there is no other legitimate
	# owner of the view. One bool compare per frame.
	if _camera != null and not _camera.current:
		_camera.current = true
	# ⚠️ `_process`, NOT `_physics_process`. There is no physics here — nothing to step,
	# nothing to collide, nothing another body has to agree with — and a camera that
	# moves on the render frame is smoother than one that moves on the physics tick and
	# is interpolated afterwards.
	if _follow != null and is_instance_valid(_follow):
		if _pov:
			# ⚠️ SNAPPED, NOT SMOOTHED. `MOVE_SMOOTH_RATE` is what makes a flown camera
			# read as flown, and it is exactly wrong here: an eye that lags its own head
			# by a few frames is the one camera artefact everybody reads as nauseating.
			# A POV shot is rigid or it is not a POV shot.
			_target_position = (_follow.global_position
				+ Vector3.UP * _pov_eye_height()
				+ (-_follow.global_transform.basis.z) * POV_FORWARD_OFFSET)
			global_position = _target_position
			# Yaw is TAKEN from the unit; pitch stays on the mouse. See POV_EYE_HEIGHT_*.
			_yaw = _follow.global_rotation.y
			_apply_rotation()
			return
		# Follow mode holds a fixed offset in the camera's own current bearing, so the
		# player still owns the angle and only gives up the position.
		var back := -_camera_forward()
		_target_position = (_follow.global_position
			+ Vector3.UP * (_follow_distance * FOLLOW_LIFT_RATIO)
			+ back * _follow_distance)
	else:
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var move := _camera_forward() * -input_dir.y + _camera_right() * input_dir.x
		if Input.is_action_pressed("jump"):
			move += Vector3.UP
		# ⚠️ WAS `guard_dash`, WHICH NO LONGER EXISTS. That action was Can-Dash and
		# Flick Dash; both are deleted, and so is the action — leaving this reading it
		# threw `The InputMap action "guard_dash" doesn't exist` every single frame a
		# spectator was live. `spectator_down` is its own binding on the same Ctrl key,
		# so the documented controls are unchanged and the camera no longer borrows a
		# gameplay action it has nothing to do with.
		if Input.is_action_pressed("spectator_down"):
			move += Vector3.DOWN
		if move.length() > 0.001:
			var speed := _speed * (BOOST_SCALE if Input.is_action_pressed("sprint") else 1.0)
			_target_position += move.normalized() * speed * delta
	var t: float = 1.0 - exp(-MOVE_SMOOTH_RATE * delta)
	global_position = global_position.lerp(_target_position, t)

func _apply_rotation() -> void:
	rotation = Vector3(deg_to_rad(_pitch_deg), _yaw, 0.0)

func _camera_forward() -> Vector3:
	return -global_transform.basis.z

func _camera_right() -> Vector3:
	return global_transform.basis.x

## Cycles the follow target through every live CharacterBase in the match, then back to
## free flight. Rebuilt on every press rather than cached: a unit can be spawned, freed
## or handed to an AI mid-match, and a stale list would follow a dangling node.
func _cycle_follow() -> void:
	var units: Array[Node] = []
	for node in get_tree().get_nodes_in_group("spectatable"):
		if node is Node3D and is_instance_valid(node):
			units.append(node)
	if units.is_empty():
		# Fall back to a scan when nothing registered — the group is populated by
		# `main.gd` at spawn, and a probe scene that builds characters by hand does not
		# go through it.
		for node in get_tree().current_scene.find_children("*", "CharacterBase", true, false):
			units.append(node)
	if units.is_empty():
		_follow = null
		_follow_index = -1
		return
	_follow_index += 1
	if _follow_index >= units.size():
		_follow = null
		_follow_index = -1
		# Leaving follow mode hands the camera back where it currently IS rather than
		# where it was when follow started, or the view would jump across the map.
		_target_position = global_position
		return
	_follow = units[_follow_index] as Node3D

## The on-screen legend. Built by `main.gd` rather than here so the spectator node stays
## a camera and nothing else — same rule that keeps gameplay state out of it.
static func controls_text() -> String:
	return "SPECTATOR    WASD fly · SPACE up · CTRL down · SHIFT boost · TAB follow · V POV · F free · WHEEL speed, or follow distance while following"

## ⚠️ §2.6 — WHAT THE CAMERA IS DOING RIGHT NOW, WHICH THE STATIC LEGEND CANNOT SAY.
## Polled once a frame by `hud.gd`'s spectator branch. Both numbers on it are ones a
## person framing a shot is actively changing and cannot otherwise see: turning the wheel
## produced no feedback at all, so "am I at 3 m/s or 40" was answered by flying and
## finding out — twice, because the wheel means two different things in the two modes.
##
## Returns a plain String and reads nothing outside this node, so the HUD does not have
## to know what a follow target is.
func status_text() -> String:
	if _follow != null and is_instance_valid(_follow):
		if _pov:
			return "POV  %s  ·  through their eyes" % _follow_name()
		return "FOLLOWING  %s  ·  %.1f m" % [_follow_name(), _follow_distance]
	return "FREE FLIGHT  ·  %.1f m/s" % _speed

## Where this unit's eyes are. A Person stands; a lata and a tsinelas lie on the street.
## Read off `is_person` — the same property the camera directive itself is derived from —
## rather than off a per-class table, so a new roster entry needs no edit here.
func _pov_eye_height() -> float:
	var character := _follow as CharacterBase
	if character == null or character.is_person:
		return POV_EYE_HEIGHT_PERSON
	return POV_EYE_HEIGHT_PROP

## The followed unit's name, in the words the rest of the game uses for it rather than
## its node name — a legend that says `TeamAProp@3` is a debug print with a nicer font.
##
## ⚠️⚠️ THIS THREW ON EVERY CALL UNTIL 2026-08-01 AND NOTHING CAUGHT IT. It read
## `character.team`, a property the HARRYDAKS pivot renamed to `player_slot` on
## 2026-07-31 — so every frame the spectator legend drew, this raised
## *"Invalid access to property or key 'team'"*. It survived because the spectator's
## own probes never render the legend and because a GDScript property error does not
## stop the frame; it just fills the log. Found while running `mech_probe`, which
## boots through `GameLaunch.spectator` like every other bench here.
##
## ⚠️ AND THE STRING IT WAS BUILDING DESCRIBED A DELETED GAME. There are no teams
## (`Design.md` §1 — four players, one taya, role derived from the round number) and
## no playable props (§12), so "TEAM A · LATA" was three wrong words out of three.
## It reads the player's own name and their role this round now, which is what a
## spectator actually needs to know and what every other screen already says
## (`CharacterBase.display_name()`).
##
## ⚠️ Out of row: `spectator_camera.gd` is in nobody's §3 table — 👁️ `build spec` is
## closed — which is the §2.19 ownerless-file problem for the third file. Recorded
## in §7 rather than quietly done.
func _follow_name() -> String:
	var character := _follow as CharacterBase
	if character == null:
		return String(_follow.name)
	return "%s · %s" % [character.display_name(),
		"TAYA" if character.is_defender else "ATTACKER"]
