extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

var _out: String = ""
var _main: Node = null

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("out="):
			_out = text.substr(4)
	GameLaunch.solo_seat = 0
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	if _main.has_method("_run_ready_countdown"):
		_main._run_ready_countdown()
	await get_tree().create_timer(4.5).timeout

	print("[props] seat picks: %s" % [_main.get("_seat_prop_picks")])
	var lata: Node = _main.get("lata")
	print("[props] round 1 defender_slot=%d lata skin_index=%d"
		% [MatchManager.defender_slot, lata.get("skin_index")])
	_print_slippers()
	_frame_lata()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + "props_round1.png")

	RoundManager.time_left = 0.01
	await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(4.0).timeout

	print("[props] round 2 defender_slot=%d lata skin_index=%d"
		% [MatchManager.defender_slot, lata.get("skin_index")])
	_print_slippers()
	_frame_lata()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + "props_round2.png")
	get_tree().quit(0)

func _print_slippers() -> void:
	for node in _main.find_children("*", "Node3D", true, false):
		var slipper := node as Slipper
		if slipper == null:
			continue
		print("[props]   %s owner_slot=%d skin_index=%d" % [slipper.name, slipper.owner_slot, slipper.skin_index])

func _frame_lata() -> void:
	var lata: Node3D = _main.get("lata")
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.global_position = lata.global_position + Vector3(0, 0.8, 1.4)
	cam.look_at(lata.global_position + Vector3(0, 0.3, 0), Vector3.UP)

