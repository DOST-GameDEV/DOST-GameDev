extends Node3D
## AIM AUDIT — "does the slipper go where the crosshair is pointing?"
##
## Reported twice as a feel problem ("barely has power even during full windup",
## then "the height when you throw it is still too low") and fixed twice before
## this probe existed, which is why it exists now.
##
## ⚠️ THE METRIC IS CLOSEST APPROACH TO THE AIM POINT, NOT WHERE IT LANDS.
## `MAX_BOUNCES` lets a slipper skip once after first contact, so the resting
## place can be a metre or two past the target on a perfectly aimed throw. What
## actually answers the question is whether the TRAJECTORY passes through the
## point the crosshair was on — and it has to pass within about the slipper's own
## `hit_radius` (0.30–0.55) for the throw to hit what the player pointed at.
##
##   godot --path . tools/aim_probe.tscn
##
## Never `--headless` — same rule as smoke-gate 3 and 4.

## Camera pitches to test, in degrees. Spans a near ground target, a mid one and
## a distant wall, because the pre-fix error was a FUNCTION OF RANGE: aiming
## merely parallel to the look direction agreed with the crosshair at exactly one
## distance and was wrong either side of it.
const PITCHES: Array[float] = [0.0, -10.0, -20.0, -30.0, 10.0]
## Pass mark, in metres. The tightest shipped `hit_radius` is 0.30 (flick), so a
## trajectory inside this genuinely hits what was pointed at.
const PASS_WITHIN: float = 0.40

var _main: Node
var _attacker: CharacterBase
var _slipper: CharacterBase
var _results: Array[Dictionary] = []

func _ready() -> void:
	# R-18(b) — a real two-peer ENet session. See _run_net().
	for arg in OS.get_cmdline_user_args():
		if String(arg) == "net":
			await _run_net()
			return
	await _run_local()

func _run_local() -> void:
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	MatchManager.begin_next_round()
	await get_tree().create_timer(0.5).timeout
	for c in _main.find_children("*", "CharacterBase", true, false):
		var ch := c as CharacterBase
		if ch.is_person and not ch.team_is_can_side:
			_attacker = ch
		elif not ch.is_person and not ch.is_can:
			_slipper = ch
	if _attacker == null or _slipper == null:
		print("AIM: could not find attacker/slipper")
		get_tree().quit(1)
		return
	# The bot would otherwise fight the probe for the same slipper.
	if _attacker.ai_controller != null:
		_attacker.ai_controller.set_enabled(false)
	if _slipper.ai_controller != null:
		_slipper.ai_controller.set_enabled(false)
	var rig := _attacker.get_node("CameraRig") as CameraRig
	rig.set_active(true)
	var camera := rig.fpp_camera as Camera3D
	var carriable := _slipper.get_node("Carriable") as Carriable

	print("attacker %s   eye height %.2f above body origin"
		% [_attacker.global_position, camera.global_position.y - _attacker.global_position.y])

	for pitch in PITCHES:
		carriable.host_land()
		_slipper.global_position = _attacker.global_position + Vector3(0.4, 0.3, 0)
		await get_tree().physics_frame
		carriable.host_grab(_attacker)
		await get_tree().physics_frame
		await get_tree().physics_frame
		rig.set("_pitch_deg", pitch)
		await get_tree().physics_frame

		var aim := -rig.get_aim_basis().z
		var space := _attacker.get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			camera.global_position, camera.global_position + aim * 40.0)
		query.exclude = [_attacker.get_rid(), _slipper.get_rid()]
		var hit := space.intersect_ray(query)
		var aim_point: Vector3 = hit.get("position", camera.global_position + aim * 40.0)

		var origin := _slipper.global_position
		carriable.host_throw(aim_point, 1.0)
		var closest := 9999.0
		for _i in 400:
			await get_tree().physics_frame
			closest = minf(closest, _slipper.global_position.distance_to(aim_point))
			if carriable.state != Carriable.CarryState.FLYING:
				break
		_results.append({
			"pitch": pitch,
			"range": Vector2(aim_point.x - origin.x, aim_point.z - origin.z).length(),
			"closest": closest,
		})
	_report()
	get_tree().quit(0)

## ---------------------------------------------------------------------------
## R-18(b) · THE LUCKY FALL, ON TWO REAL PEERS. `-- net --host` / `-- net --join=IP`
##
## ⚠️ WHY THIS IS HERE AND NOT IN `hit_probe`, WHICH ALREADY HAS THE COLUMNS.
## `hit_probe.tscn` records `lucky` and `fall_delta` per throw and was written for
## exactly this. Run today on four real peers it reports **0 throws** and
## *"the harness never got a slipper into the air"*: a networked match no longer starts
## on its own. The multiplayer READY phase landed 2026-07-30 (`main.gd::
## _awaiting_net_ready` — the host counts PEERS, not characters) and nothing begins a
## round until every peer has sent `_rpc_declare_ready`. `hit_probe` waits on
## `RoundManager.round_active`, presses nothing, and spins out its attempt budget. That
## is a one-line fix in a file this lane does not own, so the measurement is taken here
## instead and the staleness is reported rather than worked around silently.
##
## ⚠️ WHAT "TWO PEERS AGREEING" CAN ACTUALLY MEAN, WHICH IS NOT WHAT IT LOOKS LIKE.
## `last_fall_scored` is written inside `_apply_hit_result`, and that is an `rpc_id` to
## the STRUCK character's own authority — so no other peer is ever told the flag at all.
## Comparing the flag across peers is therefore impossible by construction, and a probe
## that tried would be measuring nothing on one side.
##
## What every peer CAN see is the CONSEQUENCE, because `state` replicates from the
## authority outward through CharacterBase.tscn's synchronizer:
##
##     a SCORING fall  ->  DOWNED, then SEALED  (the window lapses and it auto-seals)
##     a LUCKY fall    ->  DOWNED, then NORMAL  (character_base.gd self-rights it)
##
## That is the stronger test anyway: it proves the OUTCOME of the host's roll crossed
## the wire and was applied identically, rather than proving a bool was copied. If the
## roll were ever made per-peer (the failure mode every note in this codebase warns
## about), the two sequences would diverge here and nowhere else.
##
## The host additionally checks its own two internal facts — `last_fall_scored` and the
## delta in `RoundManager._fall_count` — so a lucky fall that somehow still scored would
## be caught on the machine that decided it.
## ---------------------------------------------------------------------------

## Throws to drive. The can dodges, so only some connect; this is sized so ~15-20
## knockdowns happen inside one run.
const NET_THROWS: int = 60
const NET_CONNECT_WAIT: float = 5.0
## Seconds the host lingers after its last throw — when the host drops, every client
## tears its own match down and prints nothing.
const NET_LINGER: float = 6.0
## ⚠️ THE ROLL IS PINNED FOR THE RUN, AND THE SHIPPED 0.12 IS WHY. At one in eight, a
## run like this produces one or two lucky falls if it is fortunate, so "the peers
## agreed" would rest on a single sample and "no lucky fall was observed" would be
## indistinguishable from the feature being dead. At even odds both outcomes appear
## many times in one session and the comparison means something. Restored at the end.
const NET_LUCKY_CHANCE: float = 0.5

var _net_host := false
var _net_records: Array[Dictionary] = []
var _net_watch_can: CharacterBase = null
var _net_was_downed := false
var _net_fall_before := -1
var _net_tag := "?"

func _run_net() -> void:
	for arg in OS.get_cmdline_user_args():
		var token := String(arg)
		if token == "--host":
			_net_host = true
	_net_tag = "HOST" if _net_host else "CLIENT"

	# ⚠️ THE PROBE IS NOT THE CURRENT SCENE, and Main must live at /root/Main on every
	# peer — the spawner and the synchronizers address nodes by PATH. Same two reasons
	# net_spawn_probe.gd and hit_probe.gd both document at length.
	_main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	_main.name = "Main"
	get_tree().root.add_child.call_deferred(_main)
	await get_tree().process_frame
	get_tree().current_scene = _main
	await get_tree().create_timer(NET_CONNECT_WAIT).timeout

	# ⚠️ PRESS READY. This is the line hit_probe is missing.
	await _net_ready_up()

	if _net_host:
		# Pinned on the HOST ONLY, deliberately — the roll is host-side (hitbox.gd, past
		# the NetworkManager gate), so if a client's value mattered at all that would
		# itself be the bug. Leaving the clients at 0.12 is a free check on that.
		CharacterBase.lucky_fall_chance = NET_LUCKY_CHANCE
		# ⚠️ THE HOST'S DECISION, TAKEN FROM THE HOST'S OWN SIGNAL RATHER THAN INFERRED
		# FROM A COUNTER DELTA. The first version diffed `RoundManager._fall_count` either
		# side of the knockdown and read 0 for every scoring fall on a client-owned can —
		# because `hitbox.gd` counts the fall BEFORE it sends `_apply_hit_result`, so for a
		# remote can the counter has already moved by the time the replicated DOWNED
		# arrives. The delta was measuring replication lag, not the roll. A probe that
		# infers a decision from a side effect is measuring the side effect.
		RoundManager.can_fell.connect(_on_can_fell)
		print("[%s] lucky_fall_chance pinned to %.2f for this run (shipped is %.2f)"
			% [_net_tag, CharacterBase.lucky_fall_chance, CharacterBase.LUCKY_FALL_CHANCE])
		await _net_drive()
		CharacterBase.lucky_fall_chance = CharacterBase.LUCKY_FALL_CHANCE
		await get_tree().create_timer(NET_LINGER).timeout
	else:
		await _net_observe()
	_net_report()
	get_tree().quit(0)

## Sends READY until the host acknowledges the phase is over. Polled rather than
## signal-driven because `_awaiting_net_ready` is only set once the host's own
## `_rpc_ready_phase` arrives, which may be after this probe's first look.
func _net_ready_up() -> void:
	for attempt in 60:
		if not bool(_main.get("_awaiting_net_ready")):
			if RoundManager.round_active or bool(_main.get("_counting_down")):
				return
		else:
			_main._rpc_declare_ready.rpc_id(1)
		await get_tree().create_timer(0.5).timeout
		if RoundManager.round_active:
			return
	print("[%s] ⚠️ never reached a live round — the ready phase did not complete" % _net_tag)

## Host only. Buffered per can as a FIFO rather than applied to "the current record",
## because the roll and the replicated DOWNED it produces do not land on the same frame
## for a remotely-owned can — see the connect site.
var _rolls: Dictionary = {}

func _on_can_fell(fallen: CharacterBase, scored: bool) -> void:
	var key := String(fallen.name)
	if not _rolls.has(key):
		_rolls[key] = [] as Array[bool]
	(_rolls[key] as Array[bool]).append(scored)

func _take_roll(can_name: String) -> int:
	var queue: Array = _rolls.get(can_name, [])
	if queue.is_empty():
		return -1 # no roll seen for this knockdown — reported, never guessed
	return 1 if bool(queue.pop_front()) else 0

func _net_roles() -> Dictionary:
	var out: Dictionary = {}
	for node in get_tree().root.find_children("*", "CharacterBase", true, false):
		var ch := node as CharacterBase
		if ch == null:
			continue
		if ch.is_can:
			out["can"] = ch
		elif not ch.is_person:
			out["slipper"] = ch
		elif ch.team_is_can_side:
			out["taya"] = ch
		else:
			out["attacker"] = ch
	return out

func _net_drive() -> void:
	var thrown := 0
	var attempts := 0
	while thrown < NET_THROWS and attempts < NET_THROWS * 6:
		attempts += 1
		# Rounds end constantly (a seal ends one outright), and a Bo5 would finish long
		# before 60 throws. Holding the win counts at zero keeps rounds cycling and
		# touches no path this probe measures — the same affordance hit_probe states out
		# loud for the same reason.
		MatchManager.team_a_wins = 0
		MatchManager.team_b_wins = 0
		if not RoundManager.round_active:
			await get_tree().create_timer(0.3).timeout
			continue
		var roles := _net_roles()
		var attacker: CharacterBase = roles.get("attacker")
		var slipper: CharacterBase = roles.get("slipper")
		var can: CharacterBase = roles.get("can")
		if attacker == null or slipper == null or can == null:
			await get_tree().create_timer(0.3).timeout
			continue
		var carriable := slipper.get_node_or_null("Carriable") as Carriable
		if carriable == null:
			await get_tree().create_timer(0.3).timeout
			continue
		carriable.host_land()
		await get_tree().physics_frame
		carriable.host_grab(attacker)
		await get_tree().physics_frame
		if carriable.state != Carriable.CarryState.CARRIED:
			continue
		_net_watch_can = can
		carriable.host_throw(can.global_position + Vector3(0.0, 0.25, 0.0), 1.0)
		thrown += 1
		# Long enough to cover the flight AND the whole self-right window, because the
		# outcome under test happens 1.25 s AFTER the knockdown, not at it.
		await get_tree().create_timer(CharacterBase.DOWNED_SELF_RIGHT_WINDOW + 0.9).timeout
	print("[%s] drove %d throws in %d attempts" % [_net_tag, thrown, attempts])

## A client cannot drive a throw (host_throw is host-only by design). It watches the
## same can and records the same outcomes off replicated state.
func _net_observe() -> void:
	var deadline := Time.get_ticks_msec() + int((NET_THROWS * 2.6 + 30.0) * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var roles := _net_roles()
		_net_watch_can = roles.get("can")
		await get_tree().physics_frame

## Runs on every peer. Records one entry per transition INTO Downed, then the state that
## knockdown RESOLVED to — which is the whole measurement.
func _physics_process(_delta: float) -> void:
	if _net_tag == "?" or _net_watch_can == null or not is_instance_valid(_net_watch_can):
		return
	var can := _net_watch_can
	if can.state == CharacterBase.State.DOWNED and not _net_was_downed:
		_net_was_downed = true
		_net_records.append({
			"round": MatchManager.round_number,
			"can": String(can.name),
			# Host-only facts. A client is never told either — see this section's header.
			"flag_scored": can.last_fall_scored if _net_host else true,
			"fall_delta": -99,
			"mine": can.get_multiplayer_authority() == multiplayer.get_unique_id(),
			"resolved": "?",
		})
		if _net_host:
			_net_records[-1]["fall_delta"] = _take_roll(String(can.name))
	elif can.state != CharacterBase.State.DOWNED and _net_was_downed:
		_net_was_downed = false
		if not _net_records.is_empty() and _net_records[-1]["resolved"] == "?":
			match can.state:
				CharacterBase.State.NORMAL: _net_records[-1]["resolved"] = "up"
				CharacterBase.State.SEALED: _net_records[-1]["resolved"] = "sealed"
				_: _net_records[-1]["resolved"] = "reset"
	elif not _net_was_downed and _net_host:
		# Kept fresh every frame the can is up, so it is the value from the frame BEFORE
		# the knockdown whichever frame that turns out to be.
		_net_fall_before = int(RoundManager.get("_fall_count"))

## ⚠️⚠️ THE CLASSIFIER IS THE FLAG, NOT THE STATE THE CAN ENDED IN. THE FIRST VERSION
## USED THE STATE AND WAS WRONG ABOUT 26 ROWS OUT OF 33.
##
## "DOWNED then NORMAL" is not "a lucky fall". A can gets back up by FOUR different
## routes and only one of them is the feature under test: the lucky-fall self-right, its
## OWN bump self-right inside DOWNED_SELF_RIGHT_WINDOW (which is what the whole "too
## easy for the lata to get back up" pass was about), Quick Stand, and the taya's reset
## channel. Reading the outcome state therefore counted every recovery as lucky, and the
## run reported 33 lucky falls out of 33 knockdowns at a pinned chance of 0.5 — a number
## that cannot be true, which is what exposed it.
##
## What actually identifies the roll:
##   * on the peer that OWNS the can, `last_fall_scored`, written by `_apply_hit_result`
##     from the kind the host sent. This is the applied result.
##   * on the HOST, the delta in `RoundManager._fall_count` across the knockdown: 0 for a
##     lucky fall, 1 for a scoring one. This is the consequence the host acted on.
## Those two are on different machines and must agree. That IS the cross-peer test.
func _net_report() -> void:
	print("\n[%s] === THE LUCKY FALL ON A REAL PEER, %d knockdowns ==="
		% [_net_tag, _net_records.size()])
	var lucky := 0
	var scored := 0
	var seq := ""
	for i in _net_records.size():
		var r: Dictionary = _net_records[i]
		# One character per knockdown, in flight order, so the two logs line up index for
		# index: L / S from whichever evidence THIS peer legitimately has, '.' where this
		# peer has none (it does not own the can and is not the host).
		var mark := "."
		if _net_host:
			# `fall_delta` now carries the host's ROLL: 0 lucky, 1 scoring, -1 none seen.
			var d: int = int(r["fall_delta"])
			if d == 0:
				mark = "L"
			elif d == 1:
				mark = "S"
		elif bool(r["mine"]):
			mark = "L" if not bool(r["flag_scored"]) else "S"
		if mark == "L":
			lucky += 1
		elif mark == "S":
			scored += 1
		seq += mark
		print("[%s]   %-3d round %-2d %-12s mine=%-5s flag_scored=%-5s fall_delta=%-4d ended=%-6s -> %s"
			% [_net_tag, i, r["round"], r["can"], str(r["mine"]), str(r["flag_scored"]),
				int(r["fall_delta"]), r["resolved"], mark])
	print("[%s]   lucky (no point) : %d" % [_net_tag, lucky])
	print("[%s]   scoring          : %d" % [_net_tag, scored])
	# ⚠️ THE CROSS-PEER COMPARISON IS THIS ONE LINE. Diff it between the two logs. Every
	# position where BOTH peers printed a letter must carry the SAME letter: that is the
	# host's roll and the owning peer's applied result agreeing on the same hit. A '.' is
	# "this peer has no evidence about that one", not a disagreement.
	print("[%s]   OUTCOME-SEQ: %s" % [_net_tag, seq])

func _report() -> void:
	print("\n=== AIM AUDIT (does the throw go where the crosshair points?) ===")
	print("  pitch    aim point range    closest approach   verdict")
	var worst := 0.0
	for r in _results:
		worst = maxf(worst, r["closest"])
		print("  %+6.1f   %8.2f m        %8.2f m         %s"
			% [r["pitch"], r["range"], r["closest"],
				"ok" if r["closest"] <= PASS_WITHIN else "MISSES"])
	print("  VERDICT: %s  (worst %.2f m, pass mark %.2f)"
		% ["PASS — every throw passed through the point the crosshair was on"
			if worst <= PASS_WITHIN
			else "*** FAIL — throws do not go where the crosshair points ***", worst, PASS_WITHIN])
