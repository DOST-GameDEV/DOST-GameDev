extends Node3D
## Proves the scoreboard pips actually change colour as a team wins rounds, and
## screenshots the HUD at 0-1-2 wins so the fix is verified by looking at it.
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
	# ⚠️ FOUND BY THE `%` UNIQUE NAME, NOT BY A PATH — and it was a hardcoded path until
	# 2026-07-30, when it had been red for an unknown number of sessions.
	#
	# The path it used was `TopLeft/VBoxContainer/TeamAPipsBox`. The HUD's restyle
	# (B-143) inserted a `Row` container, so the real path is
	# `TopLeft/Row/VBoxContainer/TeamAPipsBox` — and `get_node()` on a wrong path returns
	# null with an error and no consequence, so this probe threw "Cannot call method
	# 'get_children' on a null value" on every single run and reported nothing at all.
	# A harness that is red for a reason unrelated to the thing it measures is worse than
	# no harness: it trains everyone to ignore its output.
	#
	# `TeamAPipsBox` is a `unique_name_in_owner` node in `HUD.tscn` (that is how `hud.gd`
	# reaches it, as `%TeamAPipsBox`), so `%` finds it wherever the layout moves it next.
	# `hud.gd` itself never broke here because it has always used the unique name.
	var box := _hud.get_node_or_null("%TeamAPipsBox")
	if box == null:
		push_error("hud_probe: %TeamAPipsBox is gone from HUD.tscn — the probe, not the HUD, needs updating.")
		return
	# ⚠️ AND THE CLASSIFIER WAS STALE TOO, IN A WAY THAT COULD NOT BE TRUE. It read
	# `bg_color.a > 0.1`, which dates from when an unwon pip was drawn at alpha 0 — the
	# exact defect B-143 fixed, because an empty slot that is invisible reads as no
	# scoreboard at all. Every pip is opaque now (won ones take the role colour, unwon
	# ones `WOOD_DARK`), so the alpha test answered "filled" for all three at a score of
	# ZERO. Three won rounds and a score of nothing cannot both be true; the metric was
	# the bug, which is the same rule that has caught five harness faults on this project.
	#
	# Compared against `WOOD_DARK` — the empty fill `hud.gd::_fill_pips` actually writes
	# — rather than against the role colour, so this stays correct whichever side's pips
	# are being read and whichever role that side holds this round.
	var cols := []
	for pip in box.get_children():
		var sb := (pip as Control).get_theme_stylebox("panel") as StyleBoxFlat
		var empty: bool = sb == null or sb.bg_color.is_equal_approx(UiTheme.WOOD_DARK)
		cols.append("empty" if empty else "filled")
	print("A wins=%d B wins=%d  -> A pips: %s" % [s[0], s[1], str(cols)])
	get_viewport().get_texture().get_image().save_png(_out + "hud_%d%d.png" % [s[0], s[1]])
