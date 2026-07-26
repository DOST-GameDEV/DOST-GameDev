extends Resource
class_name AbilityBase

## Base resource for every character's Special Ability.
## Each character (Sardinas, Palayok, Bilao, Dyaryo, Bakya, Havaianas) gets its
## own script that extends this and overrides activate().
## Plug an instance of that script into CharacterBase's `ability` export slot.

@export var ability_name: String = "Unnamed Special"
@export var cooldown: float = 5.0

var _time_since_use: float = 999.0

func is_ready() -> bool:
	return _time_since_use >= cooldown

func tick(delta: float) -> void:
	_time_since_use += delta

## Override this in each specific ability script (quick_stand.gd, shatter_trap.gd, etc.)
func activate(character: CharacterBody3D) -> void:
	if not is_ready():
		return
	_time_since_use = 0.0
	_do_activate(character)

## Actual per-ability behavior — override this, not activate().
func _do_activate(character: CharacterBody3D) -> void:
	pass

## Optional passive hook: implement this in an ability script (don't need to declare
## it here since GDScript duck-types has_method checks) if the ability should react
## to its owner going Downed rather than / in addition to an activate() button press
## — e.g. Palayok's Shatter Trap. CharacterBase.go_downed() calls
## `ability._on_owner_downed(self)` if the ability defines it.
# func _on_owner_downed(character: CharacterBase) -> void: pass
