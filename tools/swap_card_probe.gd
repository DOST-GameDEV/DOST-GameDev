extends Node3D

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

var _out := "res://"
var _main: Node = null
var _failures: Array[String] = []

func _ready() -> void:
	GameLaunch.spectator = true
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	if _main.has_method("_run_ready_countdown"):
		_main._run_ready_countdown()
	await get_tree().create_timer(5.0).timeout

	Engine.time_scale = 8.0
	await get_tree().create_timer(6.0).timeout
	Engine.time_scale = 1.0

	RoundManager.time_left = 0.0
	await get_tree().create_timer(2.2).timeout

	var card := _find_card()
	if card == null:
		_failures.append("HARNESS: no RoleSwapCard in the tree.")
		_report()
		get_tree().quit()
		return
	if not card.visible:
		_failures.append("the card is not visible during the intermission.")
	_capture("swap_card")
	await get_tree().create_timer(0.1).timeout

	var hud := _find_hud()
	if hud == null:
		_failures.append("HARNESS: no HUD to toggle.")
	else:
		hud.set_clean_feed(true)
		await get_tree().process_frame
		await get_tree().process_frame
		if card.is_visible_in_tree():
			_failures.append("CLEAN FEED: the intermission card still draws with the HUD off.")
		_capture("swap_card_clean")
	_report()
	get_tree().quit()

func _find_card() -> Control:
	var found := get_tree().root.find_children("*", "RoleSwapCard", true, false)
	return found[0] as Control if not found.is_empty() else null

func _find_hud() -> Node:
	var found := get_tree().root.find_children("HUD", "", true, false)
	for node in found:
		if node.has_method("set_clean_feed"):
			return node
	return null

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("saved %s/%s.png" % [_out, name])

func _report() -> void:
	print("\n========== SWAP CARD PROBE ==========")
	if _failures.is_empty():
		print("RESULT: PASS — the card showed, and the clean feed covered it.")
	else:
		print("RESULT: FAIL")
		for line in _failures:
			print("  · %s" % line)
	print("=====================================\n")

