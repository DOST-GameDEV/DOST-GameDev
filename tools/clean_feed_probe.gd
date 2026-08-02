extends Node3D
## DOES `H` ACTUALLY GIVE THE OPERATOR A CLEAN PLATE? **Written 2026-08-02.**
##
##     Godot_v4.7.1-stable_win64_console.exe --path <repo> tools/clean_feed_probe.tscn
##
## ---------------------------------------------------------------------------
## ⚠️⚠️ WHY THIS EXISTS AT ALL, AND WHY IT IS NOT PART OF `spec_probe`.
##
## 🧑 2026-08-02: *"clicking H doesnt hide all huds for spectator ... theres popup huds
## midgame and shi"*. The bug was real and nothing was watching for it: `hud.gd` says
## `set_clean_feed()` is "public so `spec_probe` can drive it", and `spec_probe` has
## never called it. A public seam written FOR a test that the test never uses is the
## REACHABILITY RULE's second half wearing a different hat.
##
## ⚠️ IT GOES RED ON THE CODE THIS REPLACED. The old `set_clean_feed()` walked
## `get_children()` once and snapshotted `visible`, so a popup fired AFTER H drew
## straight over the clean plate. Every `after H` case below fails against that
## version and passes against the hidden-root one — which is the point: the checks
## are ordered to fire the popups at the moment the old code could not survive.
##
## ⚠️ RUN IT WITH THE PLAIN EXE OR THE CONSOLE ONE, NEVER `--headless` — the HUD is a
## real Control tree and `is_visible_in_tree()` is what is being asserted.

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

var _main: Node = null
var _failures: Array[String] = []
var _lines: Array[String] = []

func _ready() -> void:
	GameLaunch.spectator = true
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()

func _log(text: String) -> void:
	_lines.append(text)

func _check(name: String, expected_visible: bool, actual_visible: bool) -> void:
	var ok := expected_visible == actual_visible
	_log("%-46s want %-7s got %-7s  %s" % [name,
		("shown" if expected_visible else "hidden"),
		("shown" if actual_visible else "hidden"), "OK" if ok else "FAIL"])
	if not ok:
		_failures.append("%s: expected %s, got %s." % [name,
			("visible" if expected_visible else "hidden"),
			("visible" if actual_visible else "hidden")])

func _wait_for_round() -> bool:
	for _i in range(1200):
		await get_tree().physics_frame
		if RoundManager.round_active and RoundManager.lata != null:
			for _j in range(8):
				await get_tree().physics_frame
			return true
	return false

func _run() -> void:
	if not await _wait_for_round():
		_failures.append("HARNESS: the match never reached a live round.")
		_report()
		return
	var hud: Hud = _main.get_node_or_null("HUDLayer/HUD")
	if hud == null:
		_failures.append("HARNESS: no HUD under Main/HUDLayer/HUD.")
		_report()
		return

	# The HUD is up before anything is toggled — otherwise every check below passes
	# for the wrong reason.
	hud.set_clean_feed(false)
	await get_tree().process_frame
	_check("baseline: HUD before H", true, hud.is_visible_in_tree())

	hud.set_clean_feed(true)
	await get_tree().process_frame
	_check("HUD root after H", false, hud.is_visible_in_tree())

	# ⚠️⚠️ THE CHECKS THAT ACTUALLY CAUGHT THE BUG. Each of these is a transient that
	# shows ITSELF with an unconditional `visible = true` somewhere in `hud.gd`, fired
	# here AFTER the clean feed is already on. The snapshot implementation had no way
	# to know they had happened.
	hud.show_toast("PROBE", 5.0)
	await get_tree().process_frame
	_check("toast fired after H", false, _seen(hud, "toast_label"))

	hud.show_countdown_tick("3")
	await get_tree().process_frame
	_check("countdown fired after H", false, _seen(hud, "countdown_label"))

	hud.show_ready_prompt(true, "READY?")
	await get_tree().process_frame
	_check("ready prompt fired after H", false, _seen(hud, "ready_objective_row"))

	# And the operator can get it all back — the half the old restore bookkeeping
	# existed to protect.
	hud.set_clean_feed(false)
	await get_tree().process_frame
	_check("HUD root after H again", true, hud.is_visible_in_tree())
	_report()

## `is_visible_in_tree()` on the named child, which is the only reading that answers
## "did the operator see it" — a child may hold `visible = true` under a hidden root
## and that is exactly the state the fix relies on.
func _seen(hud: Hud, child_name: String) -> bool:
	var node := hud.get(child_name) as CanvasItem
	if node == null:
		_failures.append("HARNESS: `%s` is not a property on Hud." % child_name)
		return false
	return node.is_visible_in_tree()

func _report() -> void:
	print("\n========== CLEAN FEED PROBE — does H give a clean plate? ==========")
	for line in _lines:
		print(line)
	if _failures.is_empty():
		print("\nRESULT: PASS — nothing draws over a clean feed.")
	else:
		print("\nRESULT: FAIL — %d check(s)" % _failures.size())
		for f in _failures:
			print("  * %s" % f)
	get_tree().quit(0 if _failures.is_empty() else 1)
