extends Node3D
var _main: Node
var _hud: Node
var _out := ""
var _step := 0
const STEPS := [[0,0],[1,0],[2,1],[3,2]]

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	_hud = _main.find_child("HUD", true, false)
	for s in STEPS:
		MatchManager.team_a_wins = s[0]
		MatchManager.team_b_wins = s[1]
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_report(s)
	get_tree().quit(0)

func _report(s: Array) -> void:
	var box := _hud.get_node_or_null("%TeamAPipsBox")
	if box == null:
		push_error("hud_probe: %TeamAPipsBox is gone from HUD.tscn — the probe, not the HUD, needs updating.")
		return
	var cols := []
	for pip in box.get_children():
		var sb := (pip as Control).get_theme_stylebox("panel") as StyleBoxFlat
		var empty: bool = sb == null or sb.bg_color.is_equal_approx(UiTheme.WOOD_DARK)
		cols.append("empty" if empty else "filled")
	print("A wins=%d B wins=%d  -> A pips: %s" % [s[0], s[1], str(cols)])
	get_viewport().get_texture().get_image().save_png(_out + "hud_%d%d.png" % [s[0], s[1]])

