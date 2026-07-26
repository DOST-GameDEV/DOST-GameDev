extends Area3D
class_name KillPlane

## B-15/B-35: the arena is a single 40x40 floor with no walls and no edge
## stop — walk past it and gravity pulls you down forever, with no respawn.
## This sits well below the floor; anyone who reaches it gets sent back to
## their own last-known spawn point (CharacterBase.spawn_position) instead
## of falling indefinitely.

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBase:
		var character := body as CharacterBase
		character.velocity = Vector3.ZERO
		character.global_position = character.spawn_position
