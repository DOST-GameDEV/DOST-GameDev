extends Area3D
class_name Hurtbox

## The "can be hit here" area for a character. A Hitbox entering this Area3D is what
## registers a bump/special landing (see hitbox.gd). One Hurtbox per character is enough
## for this scope — split into more later only if we need per-limb hit detection.

@export var owner_character: CharacterBase
