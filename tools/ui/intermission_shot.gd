extends Node3D

const CASES := [
	["tagged", true, 60.0, false],
	["time", true, 0.0, false],
	["lata_down", false, 45.0, false],
	["dented", false, 45.0, true],
]

var _main: Node
var _card: RoleSwapCard
var _out := ""

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	_card = _main.find_child("RoleSwapCard", true, false) as RoleSwapCard
	if _card == null:
		print("FAIL: no RoleSwapCard in Main.tscn")
		get_tree().quit(1)
		return

	for next_round in [2, 3, 4]:
		await _shoot(next_round)
	await _shoot_match_result()
	get_tree().quit(0)

func _shoot(next_round: int) -> void:
	RoundManager.time_left = 0.0
	var next_defender: int = MatchManager.defender_slot_for(next_round)
	MatchManager.round_number = next_round - 1
	MatchManager.defender_slot = MatchManager.defender_slot_for(next_round - 1)
	MatchManager.round_intermission_started.emit(next_round, next_defender)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("[round %d] reason=%s | result=%s" % [next_round,
		_card.reason_label.text, _card.result_label.text])
	get_viewport().get_texture().get_image().save_png(
		"%sintermission_r%d.png" % [_out, next_round])

func _shoot_match_result() -> void:
	_card.visible = false
	var result := _main.find_child("MatchResult", true, false) as MatchResult
	if result == null:
		print("FAIL: no MatchResult in Main.tscn")
		return
	for shot in [{"name": "win", "scores": [820, 610, 450, 300], "winner": 0},
			{"name": "draw", "scores": [700, 700, 450, 300], "winner": -1}]:
		for slot in range(MatchManagerScript.PLAYER_COUNT):
			MatchManager.scores[slot] = int(shot["scores"][slot])
		MatchManager.match_won.emit(int(shot["winner"]))
		get_tree().paused = false
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		print("[match_result %s] headline=%s  focus=%s" % [shot["name"],
			result.message_label.text,
			str(result.get_viewport().gui_get_focus_owner())])
		get_viewport().get_texture().get_image().save_png(
			"%smatch_result_%s.png" % [_out, shot["name"]])
		get_tree().paused = false
	get_tree().paused = false

