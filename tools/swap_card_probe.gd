extends Node3D
## DOES THE INTERMISSION CARD READ? **Written 2026-08-02, with the card rebuilt.**
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/swap_card_probe.tscn -- <out_dir>
##
## ⚠️ RUN WITHOUT `--headless`. It captures frames.
##
## 🧑 2026-08-02, with a screenshot of the old card: *"i dont get this shit at all, like
## what is it supposed to tell me? pls revamp the boxes here and whats supposed to go to
## them"* / *"shit wrapsaround and not proper"*.
##
## ⚠️⚠️ IT DRIVES A REAL INTERMISSION RATHER THAN SHOWING THE SCENE. `RoleSwapCard.tscn`
## opened on its own draws its authored placeholder text — "LOLA PACING", "END OF ROUND 2"
## — at whatever length the scene happens to carry, which is exactly the reading that
## missed the overlap for weeks. The whole failure was that REAL names are longer than the
## authored ones. So this boots `Main.tscn`, plays a round, ends it on the clock, and
## photographs what four actual roster names do to the layout.
##
## ⚠️ AND IT ALSO CHECKS THE CLEAN FEED, because the same report asked for it: *"again
## make sure spectator wont see this shit if they click h (turn off huds)"*. The card is
## a child of the HUD, so hiding the HUD root must take it — asserted here rather than
## assumed, on the live card while it is actually on screen.

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

	# Let a little of the round actually happen, so the standings are not four zeroes and
	# the headline stat has a number in it.
	Engine.time_scale = 8.0
	await get_tree().create_timer(6.0).timeout
	Engine.time_scale = 1.0

	# End the round the way the clock does.
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

	# ⚠️ THE CLEAN FEED IS TESTED WHILE THE CARD IS UP, which is the only moment the
	# question is interesting. `set_clean_feed()` hides the HUD ROOT; a card that set its
	# own `visible = true` on the way in must still be dark, because a hidden parent
	# cannot be out-voted by a child.
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

## ⚠️ BY NODE NAME, NOT BY CLASS. `hud.gd` has no `class_name`, so the obvious
## `find_children("*", "HUD")` matched nothing and the first run of this probe reported
## "HARNESS: no HUD to toggle" — a harness fault that looks exactly like a clean-feed
## pass if nobody reads the line.
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
