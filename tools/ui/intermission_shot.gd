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

	# ⚠️ THE FOUR "REASON" CASES ARE GONE. `CASES` drove the card through TAGGED /
	# DENTED / LATA_DOWN / TIME — four win conditions, none of which exists: a round is
	# 90 s of scoring and ends on the clock, every time (`Design.md` §12). The card
	# itself already says so (`_show_reason()` prints the round's headline stat now), so
	# the only thing left worth capturing is the ROTATION, once per boundary.
	for next_round in [2, 3, 4]:
		await _shoot(next_round)
	await _shoot_match_result()
	get_tree().quit(0)

## ⚠️ THE SIGNAL TAKES TWO ARGUMENTS NOW, NOT THREE. This emitted
## `(2, true, can_team_won)` — the 2v2 shape — and every listener rejected it at run
## time with "Method expected 2 argument(s), but called with 3", so nothing this tool
## captured of the card was real. It is `(next_round, next_defender_slot)`.
func _shoot(next_round: int) -> void:
	RoundManager.time_left = 0.0
	var next_defender: int = MatchManager.defender_slot_for(next_round)
	MatchManager.round_number = next_round - 1
	MatchManager.defender_slot = MatchManager.defender_slot_for(next_round - 1)
	# Through the signal the card is connected to, not by calling its handler — same rule
	# every other shot tool in this directory follows.
	MatchManager.round_intermission_started.emit(next_round, next_defender)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("[round %d] reason=%s | result=%s" % [next_round,
		_card.reason_label.text, _card.result_label.text])
	get_viewport().get_texture().get_image().save_png(
		"%sintermission_r%d.png" % [_out, next_round])

## The match-end screen, which R-29 also touches (REMATCH takes focus) and B-143 restyled.
func _shoot_match_result() -> void:
	_card.visible = false
	var result := _main.find_child("MatchResult", true, false) as MatchResult
	if result == null:
		print("FAIL: no MatchResult in Main.tscn")
		return
	# ⚠️ THIS SET `team_a_wins` / `team_b_wins` AND THREW ON EVERY RUN. Neither exists
	# since the pivot (`Design.md` §12) — the same stale-2v2-property defect that was
	# crashing `main.gd::_try_late_join` on every join. §2.10 warned that every probe in
	# `tools/` asserts deleted mechanics; this is one of them, and it is in this lane's
	# own row so it is fixed rather than filed.
	#
	# ⚠️ BOTH OUTCOMES ARE RENDERED, and the draw is the reason this function was worth
	# repairing rather than deleting. § CHECKLIST 1.3 asks for `winning_slot == -1` to be
	# a first-class result; a screenshot of a clear win says nothing about whether the
	# draw path draws anything sensible.
	for shot in [{"name": "win", "scores": [820, 610, 450, 300], "winner": 0},
			{"name": "draw", "scores": [700, 700, 450, 300], "winner": -1}]:
		for slot in range(MatchManagerScript.PLAYER_COUNT):
			MatchManager.scores[slot] = int(shot["scores"][slot])
		MatchManager.match_won.emit(int(shot["winner"]))
		# ⚠️ UNPAUSE BEFORE THE AWAITS, NOT AFTER. `MatchResult._on_match_won()` pauses
		# the tree on its single-player branch, and this probe is not
		# `PROCESS_MODE_ALWAYS` — so an `await process_frame` placed after the emit and
		# before this line never resumes. That is exactly how the first version of this
		# loop hung the whole capture run past its timeout.
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
	# The probe pauses the tree via MatchResult's own single-player branch; clear it so the
	# quit below is not waiting on a frozen tree.
	get_tree().paused = false
