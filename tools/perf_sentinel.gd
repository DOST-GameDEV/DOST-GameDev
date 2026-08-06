extends Node

var stamp: int = 0

func _process(_delta: float) -> void:
	stamp = Time.get_ticks_usec()

