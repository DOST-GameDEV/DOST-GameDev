extends Node3D

## Single-player prototype entry point (build order step 1-2). Starts the match/round
## clocks so RoundManager + MatchManager + HUD have something to show immediately.

@onready var can_test_character: CharacterBase = $CanTestCharacter

func _ready() -> void:
	# Testbed for Option B (GDD Section 3) — see round_manager.gd's "Option B testbed"
	# comment for why this is opt-in rather than auto-detected.
	RoundManager.register_can(can_test_character)
	MatchManager.begin_next_round()
