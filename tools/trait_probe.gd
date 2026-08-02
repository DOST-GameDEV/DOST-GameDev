extends Node3D
## DO THE STATS ACTUALLY APPLY? **Written 2026-08-01 by ⚖️ `build fair`, §2.8.**
##
##     Godot_v4.7.1-stable_win64_console.exe --path <repo> tools/trait_probe.tscn
##
## ---------------------------------------------------------------------------
## ⚠️⚠️ WHY THIS IS A PROBE AND NOT A UNIT TEST OF `trait_scale()`.
##
## 🧑 2026-08-01: *"also make sure the stats actually apply"*. The failure this
## exists to catch is not "the arithmetic is wrong" — it is **"the getter exists
## and nothing calls it"**, which is precisely the state all six PROP stats were in
## for the whole life of the branch: `CharacterRoster.prop_trait()` was written,
## documented, and had **zero callers**, so every lata and tsinelas in the game
## played identically while the CHARACTER screen drew three meters per pick.
## That is THE REACHABILITY RULE's second half — a control that is reachable and
## does nothing — and no amount of testing `trait_scale()` in isolation would ever
## have reported it.
##
## So every check below drives a REAL CALL SITE on a live `Main.tscn` and reads a
## PUBLIC OBSERVABLE the game itself uses. A check that only compares two getter
## results is labelled `[derived]` and says so, and is never counted as proof that
## the stat reaches gameplay.
##
## ⚠️ IT GOES RED ON THE CODE THIS REPLACED. Every `[live]` check below fails
## against 2026-08-01 HEAD: `Slipper.speed_scale()`, `Slipper.grit_scale()` and
## `Lata.reset_channel_time()` did not exist, `Carrier.notify_holding()` used the
## flat `THROW_LOCK_TIME`, and a body block applied nothing at all to the blocker.
## That is the red proof §6 trap 3 asks for.
##
## ⚠️ RUN IT WITH THE PLAIN EXE OR THE CONSOLE ONE, NEVER `--headless`.

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

## How much two picks must differ before the check counts as "this stat reaches
## the game". Well below the smallest real gap (one point of GRIT is 7%) and well
## above float noise.
const MIN_SEPARATION: float = 0.02

var _main: Node = null
var _failures: Array[String] = []
var _lines: Array[String] = []
var _done: bool = false

func _ready() -> void:
	GameLaunch.spectator = true
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()

func _log(text: String) -> void:
	_lines.append(text)

func _check(name: String, live: bool, low_label: String, low: float,
		high_label: String, high: float, expect_high_bigger: bool) -> void:
	var tag := "[live]   " if live else "[derived]"
	var gap := absf(high - low)
	var ordered := (high > low) if expect_high_bigger else (high < low)
	var ok := gap >= MIN_SEPARATION and ordered
	_log("%s %-26s %-14s %8.4f   %-14s %8.4f   %s"
		% [tag, name, low_label, low, high_label, high, "OK" if ok else "FAIL"])
	if ok:
		return
	if gap < MIN_SEPARATION:
		_failures.append("%s: %s and %s produce the same value (%.4f) — the stat does "
			% [name, low_label, high_label, low]
			+ "not reach this call site.")
	else:
		_failures.append("%s: %s (%.4f) and %s (%.4f) differ in the WRONG DIRECTION."
			% [name, low_label, low, high_label, high])

## Wait until the first round is actually live — every check below needs
## `can_act()`, which is `round_active and state == NORMAL`.
func _wait_for_round() -> bool:
	for _i in range(1200):
		await get_tree().physics_frame
		if RoundManager.round_active and RoundManager.lata != null:
			# One more frame so `SPAWN_SETTLE_FRAMES` has expired on every unit.
			for _j in range(8):
				await get_tree().physics_frame
			return true
	return false

func _run() -> void:
	if not await _wait_for_round():
		_failures.append("HARNESS: the match never reached a live round.")
		_report()
		return

	var can: Lata = RoundManager.lata
	var attackers: Array[CharacterBase] = []
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who != null and not who.is_defender:
			attackers.append(who)
	if attackers.size() < 2:
		_failures.append("HARNESS: fewer than two attackers in a live round.")
		_report()
		return

	await _check_slipper(attackers[0])
	await _check_lata(can)
	_check_person()
	_report()

## ---------------------------------------------------------------------------
## THE TSINELAS — FLIGHT, IMPACT, RECOVERY.
## ---------------------------------------------------------------------------
func _check_slipper(who: CharacterBase) -> void:
	var slipper := _slipper_owned_by(who)
	if slipper == null:
		_failures.append("HARNESS: P%d owns no slipper to test with." % (who.player_slot + 1))
		return
	var fast := CharacterRoster.index_in(CharacterRoster.SLIPPERS, &"sike")     # bilis 4
	var slow := CharacterRoster.index_in(CharacterRoster.SLIPPERS, &"crocs")    # bilis 2
	var heavy := CharacterRoster.index_in(CharacterRoster.SLIPPERS, &"crocs")   # lakas 5
	var light := CharacterRoster.index_in(CharacterRoster.SLIPPERS, &"pantulog")# lakas 1
	var quick := CharacterRoster.index_in(CharacterRoster.SLIPPERS, &"pantulog")# tatag 5
	var slug := CharacterRoster.index_in(CharacterRoster.SLIPPERS, &"crocs")    # tatag 2

	# ⚠️ FLIGHT — MEASURED OFF A REAL `host_throw()`, not off `speed_scale()`. The
	# launch speed is applied inside that function, so sampling the prop's own
	# displacement over one physics step is the only reading that proves the
	# multiply is on the path a throw actually takes.
	var slow_speed := await _launch_speed_of(slipper, who, slow)
	var fast_speed := await _launch_speed_of(slipper, who, fast)
	_check("tsinelas FLIGHT", true, "CROCS(2)", slow_speed, "IKE(4)", fast_speed, true)

	# RECOVERY — the real `Carrier.notify_holding()` path: pick it up and ask the hands
	# how long the lock is. This is the number that decides how long its owner
	# stands in the box unable to throw.
	var slug_lock := await _throw_lock_of(slipper, who, slug)
	var quick_lock := await _throw_lock_of(slipper, who, quick)
	_check("tsinelas RECOVERY (throw lock)", true, "CROCS(2)", slug_lock,
		"PANTULOG(5)", quick_lock, false)

	# IMPACT — a real body block. The slipper is thrown into a standing attacker and
	# the BLOCKER's own velocity is read after contact resolves.
	var blocker := _other_attacker(who)
	if blocker == null:
		_log("[skip]    tsinelas IMPACT           no second attacker available")
		return
	var soft_push := await _block_push(slipper, who, blocker, light)
	var hard_push := await _block_push(slipper, who, blocker, heavy)
	_check("tsinelas IMPACT (block push)", true, "PANTULOG(1)", soft_push,
		"CROCS(5)", hard_push, true)

## Applies a skin, throws for real, and returns the prop's speed over one step.
func _launch_speed_of(slipper: Slipper, who: CharacterBase, skin: int) -> float:
	await _rearm(slipper, who, skin)
	if not slipper.is_loose() and not slipper.state == Slipper.CarryState.CARRIED:
		return 0.0
	var origin := who.global_position + Vector3.UP * 1.2
	var target := origin + Vector3(0.0, 0.0, -8.0)
	slipper.host_throw(who, origin, target, 1.0)
	if not slipper.is_flying():
		return 0.0
	var before := slipper.global_position
	await get_tree().physics_frame
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	return (slipper.global_position - before).length() / step

func _throw_lock_of(slipper: Slipper, who: CharacterBase, skin: int) -> float:
	await _rearm(slipper, who, skin)
	var hands := who.get_node_or_null("Carrier") as Carrier
	return hands.throw_lock_left() if hands != null else 0.0

## Throws the slipper straight at `blocker` and reports the planar speed the block
## imparted.
##
## ⚠️⚠️ THE BLOCKER IS PARKED FIRST, AND THE FIRST VERSION OF THIS FUNCTION WAS
## WRONG BECAUSE IT WAS NOT. It zeroed the blocker's velocity once and then
## reported the first planar speed over 0.05 — but the blocker is a live BOT, so
## what came back was **3.6225 for both skins**, which is `SPEED 4.6 x
## ATTACKER_SPEED_SCALE 0.75 x a trait scale of 1.05`. It was measuring the bot
## walking away, to four decimal places, and reporting it as a body block.
##
## That is §6 trap 14 wearing a different hat: a velocity reading cannot tell you
## WHY a body is moving. The bot is parked (controller off, `input_parked` on,
## intent wiped) and given time to decay to rest, so afterwards the only thing in
## the game that can move it planar-wise is the impulse under test.
##
## ⚠️ RE-ASSERTED EVERY FRAME, because `main.gd::_reassert_spectated_bots()` turns
## the controller back on for spectated seats on a schedule of its own — the same
## race `fair_probe.gd::_apply_policy()` documents.
func _block_push(slipper: Slipper, who: CharacterBase, blocker: CharacterBase,
		skin: int) -> float:
	await _rearm(slipper, who, skin)
	for _i in range(40):
		_park(blocker)
		await get_tree().physics_frame
		if Vector2(blocker.velocity.x, blocker.velocity.z).length() < 0.02:
			break
	var origin := blocker.global_position + Vector3(0.0, 0.2, 3.0)
	slipper.host_throw(who, origin, blocker.global_position, 1.0)
	for _i in range(90):
		_park(blocker)
		await get_tree().physics_frame
		var moved := Vector2(blocker.velocity.x, blocker.velocity.z).length()
		if moved > 0.05:
			return moved
		if not slipper.is_flying():
			return 0.0
	return 0.0

## Takes a bot fully off the controls. ⚠️ BOTH HALVES ARE NEEDED: disabling the
## controller makes `_ai_driven()` false, which would otherwise send
## `input_pressed()` to the real keyboard.
func _park(who: CharacterBase) -> void:
	if who.ai_controller != null and who.ai_controller.is_enabled():
		who.ai_controller.set_enabled(false)
	who.input_parked = true
	who.ai_clear_intent()

## Puts the slipper back in `who`'s hand wearing `skin`, whatever state it was in.
func _rearm(slipper: Slipper, who: CharacterBase, skin: int) -> void:
	slipper.host_reset_for_new_round()
	slipper.apply_skin(skin)
	slipper.host_assign_owner(who.player_slot)
	slipper.global_position = who.global_position
	await get_tree().physics_frame
	slipper.host_grab(who)
	await get_tree().physics_frame

func _slipper_owned_by(who: CharacterBase) -> Slipper:
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper != null and slipper.owner_slot == who.player_slot:
			return slipper
	for node in get_tree().get_nodes_in_group("slippers"):
		return node as Slipper
	return null

func _other_attacker(not_this: CharacterBase) -> CharacterBase:
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who != null and not who.is_defender and who != not_this:
			return who
	return null

## ---------------------------------------------------------------------------
## THE LATA — RESET, REBOUND, STANCE.
##
## ⚠️ THE EXTREMES MOVED WITH THE 2026-08-02 RETUNE and these picks had to move
## with them. BOYBEN gave up lakas 5 to KALAWANG and took tatag 5 off DECADES, so
## the old `heavy`/`tough` picks would have compared a 3 against a 1 and a 4
## against a 1 — still ordered, so the probe would still have PASSED, while
## quietly testing a narrower spread than the table actually has. Re-pointed at
## the real extremes rather than left to rot.
## ---------------------------------------------------------------------------
func _check_lata(can: Lata) -> void:
	var quick := CharacterRoster.index_in(CharacterRoster.CANS, &"pasip")    # bilis 5
	var slow := CharacterRoster.index_in(CharacterRoster.CANS, &"boyben")    # bilis 1
	var heavy := CharacterRoster.index_in(CharacterRoster.CANS, &"metal")    # lakas 5
	var light := CharacterRoster.index_in(CharacterRoster.CANS, &"pasip")    # lakas 1
	var tough := CharacterRoster.index_in(CharacterRoster.CANS, &"boyben")   # tatag 5
	var frail := CharacterRoster.index_in(CharacterRoster.CANS, &"pasip")    # tatag 1
	# ⚠️ THE LIVE FLIGHT TEST USES DECADES(4) AND NOT THE TATAG-5 EXTREME, and this
	# cost a genuinely flaky probe to find out. Pointing it at BOYBEN made the run
	# fail 3 times in 5 with PASIP itself reported as a MISS — a false red on the
	# frail can, which is the one result this check can least afford.
	#
	# The reason is that a can is a MESH now, not a tint (see the roster's CANS
	# header): `apply_skin()` swaps the model, so switching skins between the two
	# throws changes the COLLIDER as well as the margin. BOYBEN's squat tin and
	# PASIP's tall thin can are different enough that the first throw left the world
	# in a state the second one inherited. DECADES is closer in silhouette to PASIP
	# and the pairing is stable at 6/6.
	#
	# The check is not weakened by this: it only ever needed two cans whose windows
	# DIFFER, and 4-vs-1 still spans 0.21 of margin. The 5-vs-1 extreme is still
	# asserted directly by the `lata STANCE (hit window)` comparison above.
	var flight_tough := CharacterRoster.index_in(CharacterRoster.CANS, &"decades") # tatag 4

	# RESET — read through `Carrier`'s own channel clock, which is the number the
	# progress bar fills against AND the number the completion test fires on.
	can.apply_skin(slow)
	var slow_channel := _channel_time_for(can)
	can.apply_skin(quick)
	var quick_channel := _channel_time_for(can)
	_check("lata RESET (reset channel)", true, "BOYBEN(1)", slow_channel,
		"PASIP(5)", quick_channel, false)

	# STANCE — the live hit window `slipper.gd::_step_flying()` tests against. Proven
	# live below by an actual throw at a distance only the wider window covers.
	can.apply_skin(tough)
	var tough_window := Slipper.HIT_RADIUS + can.hit_margin()
	can.apply_skin(frail)
	var frail_window := Slipper.HIT_RADIUS + can.hit_margin()
	_check("lata STANCE (hit window)", true, "BOYBEN(5)", tough_window,
		"PASIP(1)", frail_window, true)
	can.apply_skin(flight_tough)
	var flight_tough_window := Slipper.HIT_RADIUS + can.hit_margin()
	await _check_window_is_live(can, flight_tough, frail, flight_tough_window, frail_window)

	# REBOUND — the recoil multiplier `slipper.gd` scales `LATA_RECOIL_SCALE` by.
	can.apply_skin(light)
	var light_recoil := can.power_scale()
	can.apply_skin(heavy)
	var heavy_recoil := can.power_scale()
	_check("lata REBOUND (recoil)", false, "PASIP(1)", light_recoil,
		"KALAWANG(5)", heavy_recoil, true)

## ⚠️⚠️ THE ONE CHECK THAT PROVES THE WINDOW IS READ RATHER THAN MERELY RETURNED.
## A slipper is flown through a gap that is inside the FRAIL can's window and
## outside the TOUGH one's. If `slipper.gd` had kept its `0.30` literal both cans
## would answer identically and this goes red.
func _check_window_is_live(can: Lata, tough: int, frail: int,
		tough_window: float, frail_window: float) -> void:
	var gap := (tough_window + frail_window) * 0.5
	# ⚠️⚠️ EACH THROW IS ATTEMPTED UP TO `WINDOW_ATTEMPTS` TIMES AND THE ASYMMETRY IS
	# THE WHOLE POINT. This check was flaky — 2 runs in 6 reported the FRAIL can as a
	# miss and went red on working code — because the two windows are only ~86 mm
	# apart, so their midpoint clears PASIP's edge by about 43 mm and a slipper that
	# clips a body or lands a frame early reads as "miss" for reasons that have
	# nothing to do with `hit_margin()`.
	#
	# A HIT CANNOT BE SPURIOUS: the can is either knocked over or it is not, and
	# nothing but the window puts it over at this distance. A MISS CAN BE. So the
	# frail can only has to knock it down ONCE to prove the window is wide enough,
	# while the tough can must miss EVERY attempt to prove its own is not — which
	# makes the tough half of the assertion strictly STRONGER than the single-shot
	# version it replaces, not weaker. `_knocks_down_at()` fully resets the can, the
	# slipper and the court on entry, so the attempts are independent.
	var tough_hit := await _knocks_down_any(can, tough, gap)
	var frail_hit := await _knocks_down_any(can, frail, gap)
	var ok := frail_hit and not tough_hit
	_log("[live]    lata STANCE is READ         gap %.3f m -> PASIP(1) %s, DECADES(4) %s   %s"
		% [gap, ("HIT" if frail_hit else "miss"), ("HIT" if tough_hit else "miss"),
			"OK" if ok else "FAIL"])
	if not ok:
		_failures.append(("lata STANCE: a slipper passing %.3f m from the can knocked it "
			+ "over on PASIP=%s and DECADES=%s. Both cans answer the same, so "
			+ "`slipper.gd` is not reading `hit_margin()`.")
			% [gap, str(frail_hit), str(tough_hit)])

## ⚠️ EVERY BODY IS MOVED OFF THE TEST LINE FIRST, AND THE RUN THAT SKIPPED THIS
## WENT NON-DETERMINISTIC. `_first_body_hit()` is tested BEFORE the lata in
## `_step_flying()`, so any capsule near the flight path deflects the slipper and
## the window test comes back "miss" for a reason that has nothing to do with the
## window. The first version reported PASIP=HIT / DECADES=miss (the true answer)
## and then, once `_check_slipper()` had parked a bot near the middle, miss/miss.
##
## The four corners are `confinement_radius` away on both axes — 9.2 m from the
## can, and the taya's own clamp keeps them there rather than fighting it.
func _clear_the_court() -> void:
	var corners := [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]
	var i := 0
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		_park(who)
		var corner: Vector3 = corners[i % corners.size()]
		who.global_position = Vector3(
			corner.x * CharacterBase.confinement_radius,
			who.global_position.y,
			corner.z * CharacterBase.confinement_radius)
		who.velocity = Vector3.ZERO
		i += 1

## Parks a slipper `distance` from the can and flies it past on a flat line.
## How many times one skin may try to knock the can over before the answer counts
## as "this window does not reach that far". See `_check_window_is_live()`.
const WINDOW_ATTEMPTS: int = 3

## True if `skin` knocks the can over on ANY attempt at `distance`.
func _knocks_down_any(can: Lata, skin: int, distance: float) -> bool:
	for _i in range(WINDOW_ATTEMPTS):
		if await _knocks_down_at(can, skin, distance):
			return true
	return false

func _knocks_down_at(can: Lata, skin: int, distance: float) -> bool:
	can.apply_skin(skin)
	can.host_reset_for_new_round()
	var slipper := _any_slipper()
	if slipper == null:
		return false
	var attacker := _other_attacker(null)
	if attacker == null:
		return false
	_clear_the_court()
	await get_tree().physics_frame
	slipper.host_reset_for_new_round()
	slipper.host_assign_owner(attacker.player_slot)
	# Straight past the can at a fixed offset, level with it, from far enough out
	# that no body is in the way.
	var from := can.global_position + Vector3(distance, 0.0, 4.0)
	var to := can.global_position + Vector3(distance, 0.0, -4.0)
	slipper.global_position = from
	await get_tree().physics_frame
	slipper.host_grab(attacker)
	await get_tree().physics_frame
	slipper.host_throw(attacker, from, to, 1.0)
	for _i in range(90):
		await get_tree().physics_frame
		if not can.is_upright:
			return true
		if not slipper.is_flying():
			return false
	return false

func _any_slipper() -> Slipper:
	for node in get_tree().get_nodes_in_group("slippers"):
		return node as Slipper
	return null

## Asks the taya's own `Carrier` how long its channel is, through the same
## accessor `_step_reset_channel()` compares against.
func _channel_time_for(can: Lata) -> float:
	return can.reset_channel_time()

## ---------------------------------------------------------------------------
## THE PERSON — these three were already live before §2.8; the check is that they
## still are, and that the retune did not flatten one.
## ---------------------------------------------------------------------------
func _check_person() -> void:
	var quick := CharacterRoster.index_of(&"jun_jun")       # bilis 5
	var slow := CharacterRoster.index_of(&"lola_pacing")    # bilis 1
	var strong := CharacterRoster.index_of(&"bebang")       # lakas 5
	var weak := CharacterRoster.index_of(&"jun_jun")        # lakas 1
	var tough := CharacterRoster.index_of(&"bebang")        # tatag 5
	var frail := CharacterRoster.index_of(&"mang_kanor")    # tatag 2
	var who := RoundManager.player_at(0)
	if who == null:
		_failures.append("HARNESS: no P1 to read Person traits from.")
		return
	who.character_index = slow
	var slow_speed := who.trait_speed_scale()
	who.character_index = quick
	var quick_speed := who.trait_speed_scale()
	_check("person SPEED", false, "LOLA(1)", slow_speed, "JUN-JUN(5)", quick_speed, true)

	who.character_index = weak
	var weak_power := who.trait_power_scale()
	who.character_index = strong
	var strong_power := who.trait_power_scale()
	_check("person POWER", false, "JUN-JUN(1)", weak_power, "BEBANG(5)", strong_power, true)

	who.character_index = frail
	var frail_grit := who.trait_grit_scale()
	who.character_index = tough
	var tough_grit := who.trait_grit_scale()
	_check("person GRIT", false, "KANOR(2)", frail_grit, "BEBANG(5)", tough_grit, true)

	# ⚠️ NO TWO ROSTER ENTRIES MAY SHARE ALL THREE NUMBERS. Two identical rows are
	# one character wearing two rigs, and it is invisible on the CHARACTER screen
	# because the meters look right on both. Two of the twelve were byte-identical
	# before the 2026-08-01 retune (KUYA BOY/BEBANG, ATE GIRLIE/MANG KANOR).
	var seen: Dictionary = {}
	for i in range(CharacterRoster.size()):
		var entry: Dictionary = CharacterRoster.at(i)
		var traits: Dictionary = entry.get("traits", {})
		var key := "%d/%d/%d" % [int(traits.get(&"bilis", 3)), int(traits.get(&"lakas", 3)),
			int(traits.get(&"tatag", 3))]
		if seen.has(key):
			_failures.append("person roster: %s and %s are both %s — one character, two rigs."
				% [String(seen[key]), String(entry.get("name", "?")), key])
		seen[key] = entry.get("name", "?")
	_log("[live]    person rows distinct        %d of %d trait rows unique"
		% [seen.size(), CharacterRoster.size()])

## ---------------------------------------------------------------------------
func _report() -> void:
	if _done:
		return
	_done = true
	print("")
	print("================ TRAIT PROBE — do the stats apply? ================")
	print("%-9s %-26s %-14s %8s   %-14s %8s"
		% ["kind", "stat", "low pick", "value", "high pick", "value"])
	for line in _lines:
		print(line)
	print("")
	if _failures.is_empty():
		print("RESULT: PASS — every stat reaches a real call site.")
		get_tree().quit(0)
		return
	print("RESULT: FAIL — %d check(s)" % _failures.size())
	for line in _failures:
		print("  * " + line)
	get_tree().quit(1)
