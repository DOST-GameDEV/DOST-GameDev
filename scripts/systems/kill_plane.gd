extends Area3D
class_name KillPlane


signal character_respawned(character: CharacterBase)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	var character := body as CharacterBase
	if character == null:
		return
	character.respawn()
	character_respawned.emit(character)

