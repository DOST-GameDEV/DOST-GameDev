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

@export var ability: AbilityBase
@export var is_can: bool = true  ## true = Can (defense), false = Tsinelas (offense)

var _staggered_time_left: float = 0.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if ability:
		ability.tick(delta)

	if _staggered_time_left > 0.0:
		_staggered_time_left -= delta
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

	if Input.is_action_just_pressed("bump"):
		_bump()

	if Input.is_action_just_pressed("special_ability") and ability:
		ability.activate(self)

## Light melee, small stagger, no cooldown. Shared by every character.
func _bump() -> void:
	# TODO: hitbox/hurtbox detection — placeholder for now.
	pass

## Called on this character when it's hit by an opponent's bump/special.
func apply_stagger(duration: float = BUMP_STAGGER_TIME) -> void:
	_staggered_time_left = max(_staggered_time_left, duration)
