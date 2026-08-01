extends Node
## DOES PICKING A PLAYER NUMBER IN SINGLE PLAYER ACTUALLY DO ANYTHING?
##
##     godot --path . tools/ui/solo_seat_probe.tscn
##
## 🧑 2026-08-01: *"SINGLE PLAYER ALWAYS STARTS YOU AS TAYA no matter which
## player number is chosen."*
##
## There are three links in that chain and only the middle one had ever been
## checked, so this walks all three rather than assuming which is broken:
##
##   1. the lobby row -> `GameLaunch.solo_seat`   (this file, by pressing it)
##   2. `solo_seat` -> which unit the human drives (measured separately by
##      `tools/models/fpp_carry_probe.tscn --seat=N`; it is CORRECT — 0..3 map
##      to P1..P4 and only P1 comes out defending)
##   3. round 1's taya -> always slot 0, by `MatchManager.defender_slot_for(1)`,
##      which is a pure function and is working as designed.
##
## ⚠️ SO THE INTERESTING ANSWER IS ABOUT THE DEFAULT, NOT ABOUT A BREAKAGE.
## `GameLaunch.solo_seat` starts at 0, and slot 0 is exactly the seat that
## defends first — so a player who never touches the seat board is the taya every
## single time, which is precisely the report. This probe exists to keep that
## honest: it presses each row through the real `pressed` signal and reads back
## what the game stored, so "the button works" is a measurement and not a claim.

const MATCH_SETUP := "res://scenes/ui/MatchSetup.tscn"

func _ready() -> void:
	GameLaunch.pending_action = "local"
	var before := GameLaunch.solo_seat
	var screen := load(MATCH_SETUP).instantiate() as Control
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var buttons: Array = screen.get("seat_buttons")
	if buttons == null or buttons.is_empty():
		print("[seat] FAIL — MatchSetup exposes no seat buttons at all")
		get_tree().quit(1)
		return
	print("[seat] default solo_seat = %d  (round-1 taya is slot %d)"
		% [before, MatchManager.defender_slot_for(1)])
	print("[seat] %d seat rows, disabled: %s" % [buttons.size(),
		str((buttons as Array).map(func(b: Button) -> bool: return b.disabled))])

	var failures := 0
	for seat in range(buttons.size()):
		(buttons[seat] as BaseButton).pressed.emit()
		await get_tree().process_frame
		var got := GameLaunch.solo_seat
		var ok := got == seat
		if not ok:
			failures += 1
		print("[seat] pressed row %d -> solo_seat=%d  %s"
			% [seat, got, "OK" if ok else "WRONG"])

	# The default is the finding, so it is reported as its own line rather than
	# folded into a pass/fail — the buttons can be perfect and the experience
	# still be "I am always the taya".
	print("[seat] DEFAULT SEAT DEFENDS FIRST: %s"
		% (before == MatchManager.defender_slot_for(1)))
	print("[seat] %s" % ("all rows store their seat" if failures == 0
		else "%d row(s) did not store their seat" % failures))
	get_tree().quit(1 if failures > 0 else 0)
