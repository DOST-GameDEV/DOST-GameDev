extends Node3D
## R-29 ACCEPTANCE: every round-end REASON the intermission card can print, plus the
## match-result screen, rendered off the real `Main.tscn`.
##
##   godot --path . tools/ui/intermission_shot.tscn -- /out/
##
## Writes `intermission_<reason>.png` and `match_result.png`, and prints the word the card
## actually resolved so the claim is a measurement and not only a look.
##
## ⚠️ DRIVES THE REAL SIGNAL, AND SETS UP THE REAL STATE IT CLASSIFIES FROM.
## `role_swap_card.gd::_classify_reason()` reads `RoundManager.time_left` and
## `GameLaunch.game_mode` and takes `can_team_won` off the signal — so this probe sets those
## three and emits `MatchManager.round_intermission_started`, which is the replicated
## broadcast the card is actually hung on. A probe that wrote `%ReasonLabel.text` directly
## would prove nothing about the classification, which is the only part that can be wrong.
##
## ⚠️ SHOT AT 0.0s OF THE §4.6 TIMELINE, deliberately. The card's own tween moves panels at
## 1.2s and shows the FIGHT wipe at 3.5s, and the world resets at 3.0s. The reason line is
## raised at 0.0s and must be readable from that instant, so that is when it is captured —
## waiting would also mean racing the reset this lane must not touch.

## reason -> [can_team_won, time_left, option_a]
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

	for case in CASES:
		await _shoot(String(case[0]), bool(case[1]), float(case[2]), bool(case[3]))
	await _shoot_match_result()
	get_tree().quit(0)

func _shoot(tag: String, can_team_won: bool, time_left: float, option_a: bool) -> void:
	RoundManager.time_left = time_left
	GameLaunch.game_mode = GameLaunch.GameMode.OPTION_A if option_a \
		else GameLaunch.GameMode.OPTION_B
	# Through the signal the card is connected to, not by calling its handler — same rule
	# every other shot tool in this directory follows.
	MatchManager.round_intermission_started.emit(2, true, can_team_won)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var label: Label = _card.reason_label
	var ok := label.text.to_lower().replace(" ", "_") == tag
	print("[%s] resolved=%-10s colour=%s  %s" % [tag, label.text,
		label.get_theme_color("font_color").to_html(false), "ok" if ok else "** MISMATCH **"])
	get_viewport().get_texture().get_image().save_png(
		"%sintermission_%s.png" % [_out, tag])

## The match-end screen, which R-29 also touches (REMATCH takes focus) and B-143 restyled.
func _shoot_match_result() -> void:
	_card.visible = false
	var result := _main.find_child("MatchResult", true, false) as MatchResult
	if result == null:
		print("FAIL: no MatchResult in Main.tscn")
		return
	MatchManager.team_a_wins = 3
	MatchManager.team_b_wins = 1
	MatchManager.match_won.emit(0)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("[match_result] focus=%s  rematch_visible=%s" % [
		str(result.get_viewport().gui_get_focus_owner()), result.rematch_button.visible])
	get_viewport().get_texture().get_image().save_png("%smatch_result.png" % _out)
	# The probe pauses the tree via MatchResult's own single-player branch; clear it so the
	# quit below is not waiting on a frozen tree.
	get_tree().paused = false
