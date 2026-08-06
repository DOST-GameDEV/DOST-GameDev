extends Node3D

var _main: Node
var _hud: Node
var _out := ""

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	_hud = _main.find_child("HUD", true, false)

	var local_char = _hud.you_card.get_local_character()
	if local_char == null:
		print("FAIL: no local character after 1.0s — nothing to derive a role from")
		get_tree().quit(1)
		return
	print("local unit is on team %d" % local_char.team)

	await _shoot("defense", local_char.team == 0)
	await _shoot("offense", local_char.team != 0)
	get_tree().quit(0)

func _shoot(tag: String, team_a_is_can: bool) -> void:
	MatchManager.team_a_is_can = team_a_is_can
	_hud.set_round_display(MatchManager.round_number, team_a_is_can)
	_hud.show_ready_prompt(true)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var label: Label = _hud.ready_objective
	print("[%s] visible=%s  colour=%s  text=%s" % [tag, label.visible,
		label.get_theme_color("font_color").to_html(false), label.text])
	get_viewport().get_texture().get_image().save_png(
		"%sready_objective_%s.png" % [_out, tag])

