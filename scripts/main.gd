extends Node3D

## Single-player prototype entry point (build order step 1-2). Starts the match/round
## clocks so RoundManager + MatchManager + HUD have something to show immediately.

func _ready() -> void:
	MatchManager.begin_next_round()
