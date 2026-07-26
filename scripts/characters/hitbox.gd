extends Area3D
class_name Hitbox

## Attach as a child Area3D on a character (or spawn transiently for a Special).
## Put it on physics layer "hitbox" / mask "hurtbox" (set in the editor — see
## docs/Dev_Plan_and_Godot_Setup.md for the layer-naming convention once we add one;
## for now both Hitbox and Hurtbox default to layer 1 so bump works out of the box,
## tighten this once we have more than one interaction type).

## Who owns this hitbox — used so a character can't hit itself and so the
## receiving side knows who staggered it.
@export var owner_character: CharacterBase
@export var stagger_duration: float = CharacterBase.BUMP_STAGGER_TIME
## If true, a hit also forces the target into the Downed state (e.g. a heavy special
## like Bakya Bash's "instant-down on direct hit") instead of just staggering it.
@export var forces_downed: bool = false
## True for the character's own always-present melee Hitbox (only registers hits
## during owner_character.is_hitbox_active(), i.e. the brief window after pressing
## bump). Set false for a hitbox spawned/enabled by a Special, which is active for
## whatever duration that ability defines instead.
@export var requires_bump_window: bool = true

signal landed_on(target: CharacterBase)

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	monitoring = true

func _on_area_entered(area: Area3D) -> void:
	if not (area is Hurtbox):
		return
	var target := (area as Hurtbox).owner_character
	if target == null or target == owner_character:
		return
	if requires_bump_window and owner_character and not owner_character.is_hitbox_active():
		return

	# Session 6, host-authoritative combat: every peer's Area3D still detects
	# this overlap locally (positions are replicated to everyone), but only
	# the host is allowed to act on it. Otherwise two peers hitting each other
	# would each decide the outcome independently and disagree. Clients just
	# wait for the state change to arrive via MultiplayerSynchronizer once the
	# host tells the target's owning peer what happened (see
	# CharacterBase._apply_hit_result).
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return

	# A Tsinelas hitbox touching an already-Downed (past self-right window) Can
	# seals it, regardless of forces_downed — that's the GDD's "reach it and seal it".
	var kind: String
	if target.state == CharacterBase.State.DOWNED and not target.is_self_rightable():
		kind = "seal"
	elif forces_downed:
		kind = "downed"
	else:
		kind = "stagger"

	if NetworkManager.is_networked():
		target._apply_hit_result.rpc_id(target.get_multiplayer_authority(), kind, stagger_duration)
	else:
		target._apply_hit_result(kind, stagger_duration)
	landed_on.emit(target)
