extends Area3D
class_name KillPlane

## B-15/B-35: the 40x40 arena floor had no bounds, no walls, no kill plane —
## walk off the edge and you fall forever with gravity accumulating, and the
## old ArenaCamera (framing the midpoint of every target) would get dragged
## down with whoever fell, pinning everyone else off-screen too.
##
## Sits well below the playable floor. Whichever character enters it gets
## reset to its own spawn_position with zero velocity — not despawned, not
## damaged — matching the GDD's "stun-only, no permanent elimination" rule
## and doubling as the landing spot for Option A's ring-out win condition.
## Position/size is set in Main.tscn: wide enough in X/Z to catch a character
## that fell off the 40x40 floor with some horizontal drift still on it.

signal character_respawned(character: CharacterBase)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	var character := body as CharacterBase
	if character == null:
		return
	character.respawn()
	character_respawned.emit(character)
