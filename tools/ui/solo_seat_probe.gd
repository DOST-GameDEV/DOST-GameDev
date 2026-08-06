extends Node

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

	print("[seat] DEFAULT SEAT DEFENDS FIRST: %s"
		% (before == MatchManager.defender_slot_for(1)))
	print("[seat] %s" % ("all rows store their seat" if failures == 0
		else "%d row(s) did not store their seat" % failures))
	get_tree().quit(1 if failures > 0 else 0)

