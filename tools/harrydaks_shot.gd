extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

const SHOTS: Array = [
	[1.5, "01_round_open"],
	[6.0, "02_midround"],
	[14.0, "03_later"],
]

var _out := "res://"
var _main: Node = null

func _ready() -> void:
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
	await get_tree().create_timer(4.5).timeout
	var last := 0.0
	for shot in SHOTS:
		await get_tree().create_timer(float(shot[0]) - last).timeout
		last = float(shot[0])
		_capture(String(shot[1]))
	_report()
	get_tree().quit()

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _out + name + ".png"
	var err := image.save_png(path)
	print("[shot] %s -> %s (%dx%d)" % [name, path if err == OK else "FAILED",
		image.get_width(), image.get_height()])

func _report() -> void:
	print("[state] round=%d/%d  defender_slot=%d  round_active=%s  time_left=%.1f"
		% [MatchManager.round_number, MatchManagerScript.ROUNDS,
			MatchManager.defender_slot, RoundManager.round_active, RoundManager.time_left])
	print("[state] scores=%s" % [str(MatchManager.scores)])
	var lata := RoundManager.lata
	print("[state] lata=%s upright=%s" % [
		"present" if lata != null else "MISSING",
		str(lata.is_upright) if lata != null else "n/a"])
	var loose := 0
	var carried := 0
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null:
			continue
		if slipper.state == Slipper.CarryState.LOOSE:
			loose += 1
		elif slipper.state == Slipper.CarryState.CARRIED:
			carried += 1
	print("[state] slippers loose=%d carried=%d" % [loose, carried])
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		print("[player] P%d  defender=%s  holding=%s  in_box=%s  taggable=%s  stamina=%.2f  score=%d"
			% [who.player_slot + 1, who.is_defender, who.holding_slipper(),
				who.is_inside_box(), who.is_taggable(), who.get_stamina_ratio(),
				MatchManager.score_for(who.player_slot)])

