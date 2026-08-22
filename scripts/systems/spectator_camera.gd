extends Node3D
class_name SpectatorCamera

## SPECTATOR MODE — a free-flying camera with no body. THIS FILE IS THE DESCRIPTION: there
## is no longer a `Design.md` section for the spectator (§9 there is traits and skins), so
## the behaviour, every tuned constant, and the human instruction behind each one live only
## here. Read the whole file, not a design doc, before changing any of it.
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
## ⚠️⚠️ POV MODE — `V`/`Tab` — WAS A PLACEMENT, IS NOW A READ-ONLY BORROW OF THE
## TARGET'S OWN `CameraRig`. `Master_Prompt_Spectator_Player_POV.md` §A reverses the
## design this block used to argue for; the argument is kept rather than deleted,
## because the next person deserves the reversal and the reason, not a silent gap.
##
## 🧑 human instruction, 2026-07-31: *"spectator should be allowed to go to anywhere in the
## map and watch the povs of people/ai, thats why its called camera."* — and then, with a
## reference frame of a live first-person view, 2026-08-22: *"it's only a camera pov. it
## should have the player's pov instead. like the reference picture. it should also
## reflect when they've been tagged (frost effect). and the arm retracts when they're
## charging their tsinelas."*
##
## THIS BLOCK ORIGINALLY ARGUED: *"POV is a placement, not a takeover: this camera is
## parked at the unit's eye height and its YAW is locked to the unit's facing. Nothing is
## written to the unit at all."* That was correct about the DANGER and wrong about the
## PICTURE. A camera merely parked at eye height sees what the eyes see and shows NONE of
## what the player is doing — no arms, no tsinelas in hand, no wind-up, no ice on the frame
## when they get tagged. Every one of those already exists on `CameraRig`, gated behind
## `_active and _mode == FPP` — the arms (`_viewmodel_arms()`), the self-hide
## (`_apply_fpp_self_hide()`), the carry solve (`_update_viewmodel_carry()`), the eye
## height and pitch limits. Re-deriving a worse copy of all of it here, by hand, was never
## going to catch up to the real thing.
##
## ⚠️ THE DANGER THE OLD ARGUMENT NAMED IS STILL REAL, AND IT IS NARROWER THAN THE OLD
## TEXT MADE IT SOUND. It is not "the rig is active" — a rig renders exactly this picture
## while active and that picture is the whole point. It is these two lines in
## `CameraRig.set_active()`: `set_process(active)` and `set_process_unhandled_input(active
## and aim_source == AimSource.MOUSE)`. An active rig whose `aim_source` is `MOUSE` reads
## THIS MACHINE'S MOUSE and writes yaw onto somebody else's body — that is what "watching
## somebody must not change what they do" is actually about, and it is the one thing that
## has to remain impossible.
##
## So this borrows the rig — `CameraRig.set_spectated(true)` — rather than either
## activating it fully or faking a placement. See that function's own class doc for the
## invariant it keeps (*"renders like an active rig and reads like a dead one"*) and for
## why it is a THIRD state and not `set_active(true)`. This node never calls
## `set_active()` on anybody else's rig, never touches `aim_source`, and writes nothing
## to `_character` — the borrow does that work, and it is `camera_rig.gd`'s file to keep
## that promise, not this one's.
##
## ⚠️ PITCH IS NO LONGER THE OPERATOR'S. It never was, honestly — the old placement's
## "pitch stays with the mouse" was a workaround for having no rig to read a real pitch
## from. A borrowed rig HAS a real pitch (the bot's own aim, or a live human's), and
## showing anything else would be inventing a number and presenting it as somebody else's
## view — the exact failure the old text warned about from the other direction. The
## spectator's own mouse motion still updates `_yaw`/`_pitch_deg` every frame regardless of
## borrow state (see `_process()`), continuously re-synced from the borrowed camera so
## release — by `V`, `F`, `Tab`, or the target dying — always hands back exactly where the
## eyes were with no stale drift to snap out of.

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
## The rig this camera is currently reading a real first-person frame through, or null
## in free flight and over-the-shoulder follow alike. Exactly one is ever borrowed —
## every place that changes it releases whatever this already holds first, so the
## invariant never needs re-proving by inspection.
var _borrowed_rig: CameraRig = null

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
		# ⚠️⚠️ THE WHEEL DOES NOT TOUCH A BORROWED RIG.
		# `Master_Prompt_Spectator_Player_POV.md` § C.3: no FOV, no spring length, no
		# offset — both of the wheel's meanings (fly speed, follow distance) belong to
		# THIS camera, and inside a POV this camera is not the one rendering.
		if _pov:
			pass
		else:
			# Following: the wheel pulls in and pushes out. Free: it retunes the fly
			# speed. See FOLLOW_DISTANCE's own note for why one control does both.
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
		if button == MOUSE_BUTTON_LEFT:
			# ⚠️⚠️ LEAVES POV ONLY — `Master_Prompt_Spectator_Player_POV.md` § C.3: "the
			# spectator ... leaves a POV with left click". Over-the-shoulder follow and
			# free flight both ignore it: `Tab`/`V` already own entering and toggling
			# POV, and `F` already owns dropping a follow entirely, so a click here has
			# exactly one job and does nothing when there is nothing to leave.
			if _pov:
				# `_release_borrow()` hands the borrowed rig back — restoring the
				# watched unit's own body and world slipper through the same door
				# `set_active(false)` uses — and syncs this camera's position/yaw/pitch
				# to exactly where the rig's own camera was, so free flight resumes
				# from there with no jump.
				_release_borrow()
				_follow = null
				_follow_index = -1
				_pov = false
				# Consumed ONLY because something was actually left — a click that did
				# nothing must not eat the event out from under anything else on screen
				# that reads a left click.
				get_viewport().set_input_as_handled()
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
			# `_release_borrow()` is a no-op unless a rig is actually borrowed (over-the-
			# shoulder follow and free flight both leave it null already), so this is safe
			# to call unconditionally rather than branching on `_pov` first.
			_release_borrow()
			# "Hand it back where it currently IS" — matters most leaving over-the-
			# shoulder follow, where `global_position` is mid-lerp toward the chase
			# target; idempotent if a POV release (or free flight already) left it here.
			_target_position = global_position
			_follow = null
			_follow_index = -1
			_pov = false
			get_viewport().set_input_as_handled()
		KEY_V:
			# A no-op in free flight rather than an error: there is no POV of nobody, and
			# a key that silently arms a mode you cannot see is worse than one that waits.
			if _follow != null and is_instance_valid(_follow):
				_pov = not _pov
				if _pov:
					_begin_borrow(_follow)
				else:
					_release_borrow()
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
	#
	# ⚠️⚠️ GUARDED ON `_borrowed_rig == null` NOW — TRAP #1 OF THE PLAYER-POV REWRITE.
	# While a rig is borrowed, ITS `fpp_camera` is the one that should be `current`, and
	# the moment it is, `Camera3D.current` (winner-takes-all, see above) reads false on
	# THIS node's own `_camera` — which this same authoritative reclaim would otherwise
	# read as "something stole the view" and fight, every single frame, forever. The
	# reclaim's job (recover from a DIFFERENT stolen camera) still matters and still
	# runs in every other state; it just has to stand down for the one state where this
	# camera is correctly, deliberately, not the one rendering.
	if _camera != null and _borrowed_rig == null and not _camera.current:
		_camera.current = true
	# ⚠️ A FOLLOW TARGET THAT DIES MID-POV MUST NOT LEAVE THE CAMERA PARKED AT A DEAD
	# NODE, AND MUST NOT LEAVE A RIG BORROWED WITH NOBODY EVER GIVING IT BACK.
	# `_cycle_follow()` rebuilds its list from live nodes on every `Tab`, but nothing was
	# clearing `_follow` on the frames BETWEEN presses — a unit freed or role-swapped
	# mid-round left `is_instance_valid(_follow)` false forever after, which every read
	# below already guards, but the on-screen name (`spectated_label()`), the wrap order
	# and now the borrowed rig itself all needed the field actually cleared.
	# `_release_borrow()` is itself guarded against a freed rig — see its own doc — so
	# this is safe even if the CameraRig child died in the same sweep as its parent.
	if _follow != null and not is_instance_valid(_follow):
		_release_borrow()
		_follow = null
		_follow_index = -1
		_pov = false
	# ⚠️ `_process`, NOT `_physics_process`. There is no physics here — nothing to step,
	# nothing to collide, nothing another body has to agree with — and a camera that
	# moves on the render frame is smoother than one that moves on the physics tick and
	# is interpolated afterwards.
	if _follow != null and is_instance_valid(_follow):
		if _pov:
			# The borrowed rig's OWN `_process` is what actually moves its camera — see
			# `CameraRig.set_spectated()`. All this does is keep this node's own
			# transform in lockstep with it, every frame rather than only at release,
			# because a mid-POV `Tab`, a left click or `F` can each end the borrow on
			# ANY frame and every one of them needs "exactly where the eyes were" to
			# already be true rather than computed retroactively.
			_sync_from_borrowed_rig()
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

## ⚠️⚠️ `Tab` IS THE CAMERA SWITCHER NOW, AND A CAMERA MEANS A UNIT'S REAL POV.
## `Master_Prompt_Spectator_Player_POV.md` § C.2: from free flight the first `Tab`
## borrows the first spectatable unit's own rig IN POV, immediately — not over-the-
## shoulder first — and each further `Tab` advances and WRAPS rather than falling out
## to free flight, because left click is now the dedicated way out (see
## `_unhandled_input`). Every unit in `spectatable` is a Person — `Lata` and `Slipper`
## are plain `Node3D`s, not `CharacterBase` — so this is a description of the group,
## not a filter this function has to enforce.
##
## Rebuilt on every press rather than cached: a unit can be spawned, freed or handed to an
## AI mid-match, and a stale list would follow a dangling node.
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
	# ⚠️⚠️ ALWAYS RELEASED FIRST, EVEN WHEN THE NEXT TARGET IS ABOUT TO BORROW ANOTHER.
	# `Master_Prompt_Spectator_Player_POV.md` § C.2: "release the previous one before
	# you take the next, in that order, every time." A no-op when nothing is borrowed
	# (over-the-shoulder follow, free flight), so this is safe unconditionally rather
	# than branching on `_pov` first.
	_release_borrow()
	if units.is_empty():
		_follow = null
		_follow_index = -1
		return
	# Whether this press is the one that LEAVES free flight — the only moment POV is
	# forced on. Once already following, `_pov` stays whatever `V` last set it to
	# (sticky across the cycle — see `_pov`'s own doc), so stepping through all four
	# units in POV needs one press of `V`, not four.
	var was_free := _follow == null
	_follow_index = (_follow_index + 1) % units.size()
	_follow = units[_follow_index] as Node3D
	if was_free:
		_pov = true
	if _pov:
		_begin_borrow(_follow)

## Starts the borrow onto `character`'s own `CameraRig` — see `CameraRig.
## set_spectated()` for what "borrow" means and what it can never do. Always
## releases whatever this camera already holds first (§ THE INVARIANT: exactly one
## rig, ever). No-ops into free-flight-shaped POV (harmless: `status_text()` and
## `spectated_label()` still show the target's name, there is simply no first-person
## frame to show) if the target has no rig — every real `spectatable` unit is a
## Person and every Person has one, but a hand-built probe scene might not.
func _begin_borrow(character: Node3D) -> void:
	_release_borrow()
	var rig := character.get_node_or_null("CameraRig") as CameraRig
	if rig == null:
		return
	rig.set_spectated(true)
	_borrowed_rig = rig
	_sync_from_borrowed_rig()

## Hands the rig back — restoring the watched unit's body, arms and world slipper
## through the exact door `CameraRig.set_active(false)` uses, since `set_spectated()`
## routes release through it — and syncs this camera to exactly where the rig's own
## camera was rendering, so whatever comes next (free flight, over-the-shoulder
## follow) resumes with no jump. Safe to call when nothing is borrowed (a no-op) and
## safe to call after the borrowed rig's own CharacterBase died (guarded below).
func _release_borrow() -> void:
	if _borrowed_rig == null:
		return
	if is_instance_valid(_borrowed_rig):
		_sync_from_borrowed_rig()
		_borrowed_rig.set_spectated(false)
	_borrowed_rig = null
	# The rig's `fpp_camera` just stopped being `current` (or never was, if it was
	# already dead) — reclaim on the spot rather than waiting for `_process()`'s own
	# reclaim next frame, so there is never a frame with no camera `current` at all.
	if _camera != null:
		_camera.current = true

## This camera's own position/yaw/pitch, read live off the borrowed rig's actual
## camera rather than off the character body — the rig already solves the forward
## clearance the old placement's deleted `POV_FORWARD_OFFSET` was faking (it hides
## the head instead of stepping past it) and knows the exact pitch (the target's
## own aim, not a fiction).
func _sync_from_borrowed_rig() -> void:
	if _borrowed_rig == null or not is_instance_valid(_borrowed_rig):
		return
	var cam := _borrowed_rig.fpp_camera
	global_position = cam.global_position
	_target_position = global_position
	var cam_rotation := cam.global_rotation
	_yaw = cam_rotation.y
	_pitch_deg = clampf(rad_to_deg(cam_rotation.x), -PITCH_LIMIT_DEG, PITCH_LIMIT_DEG)
	_apply_rotation()

## The on-screen legend. Built by `main.gd` rather than here so the spectator node stays
## a camera and nothing else — same rule that keeps gameplay state out of it.
static func controls_text() -> String:
	return ("SPECTATOR    WASD fly · SPACE up · CTRL down · SHIFT boost · TAB pov (cycles, " +
		"wraps) · CLICK leave pov · V pov/follow · F free · WHEEL speed, or follow distance " +
		"while following")

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

## ⚠️⚠️ WHO IS BEING WATCHED, FOR THE HUD'S ON-SCREEN NAME — POV OR OVER-THE-SHOULDER,
## "" IN FREE FLIGHT. `Master_Prompt_Spectator_Player_POV.md` § C.6: the name is
## `CharacterBase.display_name()` and nothing else, so this is a thin wrapper over
## `_follow_name()` rather than a second answer to "who is this" — same one string the
## scoreboard, the 3D nameplate and the result screen already agree on.
##
## Same one-way dependency `status_text()` keeps: `hud.gd` polls this every frame
## (`_refresh_spectator_panel`) and owns the Label; this node has never heard of the HUD
## and returns a plain String. Polled rather than cached at `Tab` time on purpose — the
## taya rotates every round and a mid-match joiner can take a bot's seat and its name
## with it, and a cached string would go stale under both.
func spectated_label() -> String:
	if _follow != null and is_instance_valid(_follow):
		return _follow_name()
	return ""

## The unit whose rig is actually borrowed right now, or null — over-the-shoulder
## follow and free flight both return null, since neither one is looking through
## anybody's own eyes. `hud.gd` polls this to run the screen frost off the SPECTATED
## player's own stagger, per `Master_Prompt_Spectator_Player_POV.md` § C.4, rather
## than off `you_card`'s local character (a spectator has none).
func spectated_pov_character() -> CharacterBase:
	if _pov and _follow != null and is_instance_valid(_follow):
		return _follow as CharacterBase
	return null

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
