extends Resource
class_name AbilityBase

## Base resource for every character's Special Ability.
## Each character (Sardinas, Palayok, Bilao, Dyaryo, Bakya, Havaianas) gets its
## own script that extends this and overrides activate().
## Plug an instance of that script into CharacterBase's `ability` export slot.

@export var ability_name: String = "Unnamed Special"
@export var cooldown: float = 5.0
## Session 6: real once-per-round charge, replacing the "set cooldown to ~90s
## to approximate once/round" workaround (see quick_stand.gd). When true,
## `cooldown` is ignored entirely — the ability is usable exactly once until
## RoundManager.start_round() resets it via reset_round_charge().
@export var once_per_round: bool = false

var _time_since_use: float = 999.0
var _used_this_round: bool = false

func is_ready() -> bool:
	if once_per_round:
		return not _used_this_round
	return _time_since_use >= cooldown

func tick(delta: float) -> void:
	_time_since_use += delta

## Override this in each specific ability script (quick_stand.gd, shatter_trap.gd, etc.)
func activate(character: CharacterBody3D) -> void:
	if not is_ready():
		return
	# B-11: cooldown/charge used to be consumed BEFORE calling _do_activate(),
	# so a no-op activation (e.g. Quick Stand pressed while not Downed) still
	# burned the once-per-round charge for nothing. Consume only on success now.
	if not _do_activate(character):
		return
	_time_since_use = 0.0
	if once_per_round:
		_used_this_round = true

## Called by CharacterBase.reset_for_new_round() at the start of every round.
func reset_round_charge() -> void:
	_used_this_round = false

## Actual per-ability behavior — override this, not activate(). Return true if
## the ability actually did something; return false for a no-op activation
## (e.g. Quick Stand pressed while not Downed) so activate() doesn't consume
## the cooldown/charge for nothing (B-11). Default true — most abilities
## always do something once called.
func _do_activate(_character: CharacterBody3D) -> bool:
	return true

## Optional passive hook: implement this in an ability script (don't need to declare
## it here since GDScript duck-types has_method checks) if the ability should react
## to its owner going Downed rather than / in addition to an activate() button press
## — e.g. Palayok's Shatter Trap. CharacterBase.go_downed() calls
## `ability._on_owner_downed(self)` if the ability defines it.
# func _on_owner_downed(character: CharacterBase) -> void: pass
