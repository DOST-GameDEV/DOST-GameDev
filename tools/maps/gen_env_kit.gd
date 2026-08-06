extends Node

const EnvKit = preload("res://tools/models/env_kit.gd")
const OUTPUT_DIR: String = "res://assets/models/"


func _ready() -> void:
	print("regenerating environment kit -> ", OUTPUT_DIR)
	EnvKit.new().build_all(OUTPUT_DIR)
	print("env kit: done")
	get_tree().quit(0)

