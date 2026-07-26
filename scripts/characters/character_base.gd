extends CharacterBody3D
class_name CharacterBase

## Shared controller for every Can and Tsinelas.
## Each of the 6 characters = this scene + a different AbilityBase resource
## plugged into `ability`, plus its own model/animations.
## Stock/Downed round-win logic is NOT here on purpose (see Section 3 of the GDD) —
## it lives in its own decoupled system so Option A vs Option B can be swapped freely.

const SPEED: float = 6.0
const GRAVITY: float = 20.0
const BUMP_STAGGER_TIME: float = 0.25
## GDD Section 3, Option B: ~2s window to self-right before a Tsinelas can seal a
## Downed Can. Kept here (not in RoundManager) because it's shared by both Option A
## and Option B, and by abilities like Quick Stand / Shatter Trap that reference
## "Downed" directly — see docs/Tumbang_Preso_2v2_GDD.md Section 4.
const DOWNED_SELF_RIGHT_WINDOW: float = 2.0
## Bump is "no cooldown" per the GDD but still needs an active window so standing
## next to an opponent doesn't stagger them every physics tick — press-to-bump,
## briefly live, matches "light melee" better than always-on contact damage.
const BUMP_ACTIVE_TIME: float = 0.15

## NORMAL — moving/acting freely.
## STAGGERED — brief no-control flinch from a bump (BUMP_STAGGER_TIME), auto-recovers.
## DOWNED — knocked down; can self-right (bump input) within DOWNED_SELF_RIGHT_WINDOW;
##          after the window expires it becomes sealable by an opponent Hitbox.
## SEALED — round-relevant "out" state for this character. What SEALED actually does to
##          round outcome is intentionally NOT decided here — RoundManager/MatchManager
##          own that, this just reports the state change via `state_changed`.
enum State { NORMAL, STAGGERED, DOWNED, SEALED }

@export var ability: AbilityBase
@export var is_can: bool = true  ## true = Can (defense), false = Tsinelas (offense)

signal state_changed(new_state: State)

var state: State = State.NORMAL
var _staggered_time_left: float = 0.0
var _downed_time_left: float = 0.0
var _downed_self_rightable: bool = false ## true only within the self-right window
var _bump_active_time_left: float = 0.0

func _ready() -> void:
	for child in find_children("*", "Hurtbox", true, false):
		(child as Hurtbox).owner_character = self
	for child in find_children("*", "Hitbox", true, false):
		(child as Hitbox).owner_character = self

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if ability:
		ability.tick(delta)

	if _bump_active_time_left > 0.0:
		_bump_active_time_left -= delta

	if state == State.NORMAL and Input.is_action_just_pressed("bump"):
		_bump_active_time_left = BUMP_ACTIVE_TIME

	match state:
		State.STAGGERED:
			_staggered_time_left -= delta
			if _staggered_time_left <= 0.0:
				_set_state(State.NORMAL)
		State.DOWNED:
			if _downed_self_rightable:
				_downed_time_left -= delta
				if _downed_time_left <= 0.0:
					_downed_self_rightable = false # window expired, now sealable
			if Input.is_action_just_pressed("bump") and _downed_self_rightable:
				self_right()
		State.SEALED:
			pass # awaiting round reset / respawn logic

	if state in [State.STAGGERED, State.DOWNED, State.SEALED]:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	if Input.is_action_just_pressed("special_ability") and ability:
		ability.activate(self)

## Called on this character when it's hit by an opponent's Hitbox (see hitbox.gd).
func apply_stagger(duration: float = BUMP_STAGGER_TIME) -> void:
	if state == State.SEALED:
		return
	_staggered_time_left = max(_staggered_time_left, duration)
	_set_state(State.STAGGERED)

## Knocks this character into the Downed state (out-of-base hit, or a heavy special
## like Bakya Bash's instant-down). Starts the self-right window.
func go_downed() -> void:
	if state == State.SEALED:
		return
	_downed_time_left = DOWNED_SELF_RIGHT_WINDOW
	_downed_self_rightable = true
	_set_state(State.DOWNED)

## Player (or an ability, e.g. Sardinas' Quick Stand) recovers from Downed early.
func self_right() -> void:
	if state != State.DOWNED:
		return
	_downed_self_rightable = false
	_set_state(State.NORMAL)

## Called by an opponent's Hitbox once this character is Downed and past its
## self-right window (see hitbox.gd forces_downed / seal handling).
func seal() -> bool:
	if state != State.DOWNED or _downed_self_rightable:
		return false # still in the self-right window, can't be sealed yet
	_set_state(State.SEALED)
	return true

## Whether this character's press-to-bump window is currently live. The melee
## Hitbox (requires_bump_window = true) checks this before landing a stagger;
## ability-spawned hitboxes (requires_bump_window = false) ignore it.
func is_hitbox_active() -> bool:
	return _bump_active_time_left > 0.0

func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(state)
