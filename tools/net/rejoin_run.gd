extends Node
## CAN A PLAYER WHO DROPPED OUT OF A RUNNING MATCH GET BACK INTO IT?
##
## 🧑 2026-08-02, from a real player: *"When getting disconnected from a lobby, I want the
## ability to rejoin it. Currently you are able to JOIN it, but you're stuck on a grey
## screen."*
##
## Every other harness in this tree either starts a match and stops, or walks OUT of one
## and never comes back. This one drops a client out of a live match and drives it back in
## through the player's real path — MultiplayerSetup → JOIN → MatchSetup → the host's
## reroute — and then reports what the returning client ACTUALLY HAS: which scene, how many
## bodies exist, which one it is the authority for, and whether any Camera3D is current.
##
## ⚠️ "GREY SCREEN" IS LITERALLY "NO CAMERA". `Main.tscn` carries no camera of its own any
## more (main.gd: *"The scene-level ArenaCamera is removed — B-03 is closed, B-58 is
## closed"*), so the only 3D camera a player ever looks through is the `CameraRig` on the
## body they own, switched on by `main.gd::_refresh_rig_ownership`. A peer with no owned
## body has no current camera at all and the viewport draws nothing but the 2D HUD
## CanvasLayer — which is exactly the "grey screen" in the report. So this harness asserts
## on `get_viewport().get_camera_3d()`, not on a screenshot.
##
## ⚠️ THREE PROCESSES, BECAUSE TWO CANNOT REPRODUCE IT. The room must NOT empty when the
## dropper leaves: `main.gd::_recycle_dedicated_lobby_if_abandoned()` sends a dedicated
## referee whose last human left straight back to `MatchSetup.tscn`, which ends the match
## and turns the bug into "you rejoined a fresh lobby". So there is an ANCHOR client that
## stays put for the whole run.
##
##     --role=referee  becomes the dedicated server on --port= and prints HOST-side state
##                     (peer_tokens, _token_join_index, _spawned_peer_ids, seats) so both
##                     ends of the rejoin can be read against each other.
##     --role=anchor   a real client: joins, readies, presses START MATCH (it connects
##                     first, so it is the lobby leader), readies up in-match, and STAYS.
##     --role=dropper  the player in the report: joins, readies, plays, then drops with
##                     `NetworkManager.disconnect_network()` and rejoins by address.
##     --role=latecomer  the REGRESSION half: somebody who was never in this match at all
##                     and joins while it is already running. Same host reroute, same
##                     `main.gd::_start_joining` dial-out — so it was broken by the same
##                     line and has to be proved fixed by the same run. Pair it with
##                     `--role=anchor --wait-for=0`, which starts the match on its own.
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/net/rejoin_run.tscn -- \
##         --role=dropper --port=8941 --host=127.0.0.1
##
## ⚠️ THE CLIENT IS DROPPED, NOT KILLED. A killed process only surfaces on the far side at
## `ENET_TIMEOUT_MAX` (45 s, deliberately wide — see network_manager.gd) and would test the
## timeout path rather than the rejoin path. `disconnect_network()` closes the peer, which
## ENet announces immediately, so the host sees `peer_disconnected` within a frame or two —
## the same thing a real drop produces, just without the wait.
##
## ⚠️ THE HARNESS STAYS OUT OF THE SCENE IT DRIVES, exactly as `dedicated_match_run.gd`
## documents: `change_scene_to_file` frees `current_scene`, and this run changes scene four
## times on the dropper.

const MULTIPLAYER_SETUP: String = "res://scenes/ui/MultiplayerSetup.tscn"
const MATCH_SETUP: String = "res://scenes/ui/MatchSetup.tscn"

## ⚠️ 8940-8949 IS THE BAND THIS WORK OWNS. Outside `ServerQuery.POOL_PORT_FIRST..LAST`
## (8910-8917) on purpose, so a run here can never claim — or be claimed by — somebody
## else's pool lobby on this machine. Every client here joins by TYPED ADDRESS, which needs
## no pool at all.
const PORT_FIRST: int = 8940
const PORT_LAST: int = 8949

var _role: String = "dropper"
var _port: int = 8941
var _host: String = "127.0.0.1"
var _fail: int = 0
## How long the anchor stays in the match holding the room open. Long enough to cover the
## dropper's whole drop-and-return, with slack.
##
## ⚠️ 75 -> 130 ON 2026-08-04, WHEN THE RUN STARTED DRIVING REAL THROWS. The dropper now
## does a full charge-and-release BEFORE the drop (the control) and again AFTER it, and each
## of those first has to wait for a legal throwing moment — the can standing, off cooldown.
## At 75 the anchor was walking out of the match while the returning player was still
## measuring, which reports as "this process never witnessed the reclaim".
var _live: float = 130.0
## How many OTHER humans the anchor waits for before it presses START MATCH. 1 for the
## rejoin scenario (the dropper must be seated and playing before it can drop out of
## anything); 0 for the latecomer scenario, where the whole point is that the match is
## already running when the second client first arrives.
var _wait_for: int = 1

# =============================================================================
# ⚠️⚠️ § THE WAITING ROOM INSIDE A RUNNING MATCH — WHAT THIS FILE NOW MEASURES.
#
# 🧑 2026-08-04: *"or we could make them spectators until the next role rotation. but only
# until the lobby is full, we can't keep accepting 5 spectators for a lobby that has only 2
# bot slots open."*
#
# ⚠️⚠️ THE `latecomer` SCENARIO NOW ASSERTS THE OPPOSITE OF WHAT IT USED TO, DELIBERATELY.
# It proved a first-time mid-match joiner *lands in the match* and gets a body immediately.
# Under the rule above that is the DEFECT: it is the arrival-time reclaim every mid-match
# joiner bug of 2026-08-04 came out of (blank nameplate, the placeholder's face, silent
# throws, spawning inside the chalk box). What it must prove now is
#
#   ADMITTED    it reaches `Main.tscn` rather than being turned away, and
#   WATCHING    with the spectator camera and NO body of its own while it waits, and
#   SEATED      at the next ROLE ROTATION, wearing its own name and its own fighter.
#
# The `capacity` scenario is the other half: with every free seat already claimed by
# somebody ahead of it in the queue, the next newcomer is REFUSED and bounced with a legible
# message rather than admitted to a queue that can never be drained.
# =============================================================================

## Seconds this process waits before it even opens the browser. The latecomer/filler/refused
## roles all knock on a match that must already be RUNNING, and how long that takes depends
## on the lobby dance the anchor has to complete first.
var _join_after: float = 30.0

## Referee only. Cut the running round's clock short once somebody is actually waiting for a
## seat, so the ROTATION — the thing under test — happens inside a run somebody will sit
## through rather than 90 s later.
##
## ⚠️⚠️ THIS IS A FIXTURE, NOT A SHORTCUT PAST THE RULE. The rotation is still produced by
## the real `RoundManager._on_time_up()` -> `MatchManager.report_round_result()` ->
## `begin_next_round()` chain, on the real host, with the real intermission — nothing here
## calls `begin_next_round()` or `_promote_waiting_spectators()` itself. All that is moved is
## WHEN the clock reaches zero, which is a thing every real match does. Compare the rule this
## file already follows for the taya's restore (§ THE ANCHOR PLAYS TAYA): drive the real
## verb, never manufacture the state it produces.
var _nudge_round: bool = false
## How long after a peer is first seen waiting before the clock is cut. Not zero, and the
## number is the whole reason the "no body while it waits" check can be believed: the
## latecomer needs a window in which it is demonstrably admitted, watching and seatless
## BEFORE the rotation it is waiting for arrives. Measured against the latecomer's own
## timeline — it reports its waiting state ~12 s after `_begin_join`, so 20 s leaves ~8 s of
## margin at the tightest point and ~25 s at the loosest.
const NUDGE_ARM_DELAY_MS: int = 20000
## What the clock is cut TO. Long enough that the cut is not mistaken for a round that never
## ran; short enough that two of them plus two intermissions fit inside `--live`.
const NUDGE_TARGET_SECONDS: float = 8.0
## ⚠️ ONLY ROUND 1 IS CUT. Round 2 is the round the promoted newcomer is measured in — its
## seat table, its fighter, its name, its shove — and cutting that one too would race the
## measurement against `round_active` going false underneath it. One cut is all the rotation
## needs.
const NUDGE_LAST_ROUND: int = 1
## When the referee first saw somebody waiting, in ms, or 0 for "not yet".
var _nudge_armed_ms: int = 0

# =============================================================================
# ⚠️⚠️ § THE ROSTER PICK. 🧑 2026-08-02, after the rejoin itself started working:
# *"The player rejoins on a different player character and not the same character they
# were on."* Right seat, working controls, WRONG FIGHTER.
#
# ⚠️ THE RUN HAS TO MAKE A PICK OR IT CANNOT SEE THIS AT ALL. `GameLaunch.selected_
# character` defaults to `&"berto"`, roster index 0, and a harness that never opens the
# CHARACTER screen leaves it there — so before this block every peer in every run of this
# file was BERTO, and a rejoin that came back as somebody else's Person would have been
# indistinguishable from one that came back correct. The dropper is deliberately given a
# pick that is
#
#   · not the default (0),
#   · not in `main.gd::AI_PERSON_SPREAD` ([0, 3, 6, 9], what a bot is dealt), and
#   · not the anchor's,
#
# so "the returning player is wearing somebody else's face" cannot be true by accident on
# any of the three processes.
#
# ⚠️ ALL THREE TABS ARE PICKED, NOT JUST THE PERSON. `NetworkManager.picks_for()` carries
# `character`, `can` and `slipper` in ONE dictionary and one `_rpc_identify` packet, so a
# defect in how that table is re-read on reclaim can only be scoped by measuring all
# three. See § THE PICKS REPORT.
## Roster ids this process picks on the CHARACTER screen, or "" to leave the preference
## alone. Stable ids rather than indices, exactly as `GameLaunch` stores them.
var _character_id: String = ""
var _can_id: String = ""
var _slipper_id: String = ""
## What the DROPPER picked, so the referee and the anchor — neither of which owns that
## seat — can assert about it. Passed in rather than inferred: a peer that is not the
## host cannot ask `picks_for()` about anybody (see `network_manager.gd`), which is
## precisely the asymmetry this bug lives in.
var _expect_character: String = ""
var _expect_can: String = ""
var _expect_slipper: String = ""

# =============================================================================
# ⚠️⚠️ § THE NAME. 🧑: a player who joins (or rejoins) a match ALREADY IN PROGRESS has a
# blank name on every peer, and their nameplate and scoreboard row fall back to "P2".
#
# ⚠️ THE EXPECTED NAME IS PASSED IN RATHER THAN DERIVED, ON ALL THREE PROCESSES. The client
# sets `SettingsManager.player_name` from its own `--role`, so a check that compared the body
# against `SettingsManager.player_name` on the client's own machine would be comparing one
# derivation of `--role` with another and would pass on a build that never wrote the property
# at all. `--expect-name=` comes off the command line in `run_rejoin.ps1`, which is outside
# every mechanism under test — and it is the SAME string on the referee and the anchor, which
# is what makes "the name is right on the other peers" a statement those peers can make.
var _expect_name: String = ""

## The anchor's own name, which is how the two OBSERVER processes tell the anchor's body apart
## from the joiner's without consulting the property under test on the joiner (see
## `_joiner_body()`). Uppercase because `_ready()` writes `_role.to_upper()`.
const ANCHOR_NAME: String = "ANCHOR"

## The one body the whole run is about, found by the NAME its process plays under rather
## than by seat or peer id.
##
## ⚠️ THE NAME IS THE ONLY HANDLE THAT SURVIVES THE WHOLE RUN. The peer id changes on
## reconnect (ENet mints a fresh one), the authority changes twice (human → host → human),
## `is_bot` flips twice, and `character_index` is the thing under test and so cannot be
## used to find it. `player_name` is written from the spawn packet and is touched by
## nothing on either the convert-to-AI or the reclaim path, so it is stable across both.
const DROPPER_NAME: String = "DROPPER"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.substr(len("--role="))
		elif a.begins_with("--port="):
			_port = int(a.substr(len("--port=")))
		elif a.begins_with("--host="):
			_host = a.substr(len("--host="))
		elif a.begins_with("--live="):
			_live = float(a.substr(len("--live=")))
		elif a.begins_with("--wait-for="):
			_wait_for = int(a.substr(len("--wait-for=")))
		elif a.begins_with("--character="):
			_character_id = a.substr(len("--character="))
		elif a.begins_with("--can="):
			_can_id = a.substr(len("--can="))
		elif a.begins_with("--slipper="):
			_slipper_id = a.substr(len("--slipper="))
		elif a.begins_with("--expect-character="):
			_expect_character = a.substr(len("--expect-character="))
		elif a.begins_with("--expect-can="):
			_expect_can = a.substr(len("--expect-can="))
		elif a.begins_with("--expect-slipper="):
			_expect_slipper = a.substr(len("--expect-slipper="))
		elif a.begins_with("--expect-name="):
			_expect_name = a.substr(len("--expect-name="))
		elif a.begins_with("--join-after="):
			_join_after = float(a.substr(len("--join-after=")))
		elif a == "--nudge-round":
			_nudge_round = true
	# A distinguishable name per role, so a body in the report can be read back to the
	# process that owns it without counting peer ids.
	SettingsManager.player_name = _role.to_upper()
	# ⚠️ WRITTEN STRAIGHT ONTO `GameLaunch`, WHICH IS WHAT THE CHARACTER SCREEN DOES.
	# `character_select.gd` sets these three preferences and nothing else; every consumer
	# downstream (`GameLaunch.character_index()`, the identify packet, the spawn path)
	# reads them from here. So this is the real pick, not a shortcut past one.
	if _character_id != "":
		GameLaunch.selected_character = StringName(_character_id)
	if _can_id != "":
		GameLaunch.selected_can = StringName(_can_id)
	if _slipper_id != "":
		GameLaunch.selected_slipper = StringName(_slipper_id)
	print("[%s] PICKED character=%s(%d) can=%s(%d) slipper=%s(%d)" % [
		_role, GameLaunch.selected_character, GameLaunch.character_index(),
		GameLaunch.selected_can, GameLaunch.can_index(),
		GameLaunch.selected_slipper, GameLaunch.slipper_index()])
	# ⚠️ THE ROUND-START BEAT IS TRACED, BECAUSE IT IS WHAT REBUILDS `RoundManager`'s SEAT
	# TABLE. `main.gd::_on_match_round_started` -> `_reset_world()` is the ONLY place
	# `RoundManager.register_player()` is ever called on a networked peer, so whether a
	# returning player's seat table is correct comes down entirely to whether this signal
	# fired on their process after their bodies arrived. Connected on the autoload, which
	# outlives every scene change this run makes.
	MatchManager.round_started.connect(_trace_round_started)
	match _role:
		"referee": await _referee()
		"anchor": await _anchor()
		"latecomer": await _latecomer()
		"filler": await _filler()
		"refused": await _refused()
		_: await _dropper()

# =============================================================================
# ⚠️⚠️ § THE THIRD-PARTY THROW WATCH, AND WHY IT IS PER-FRAME.
#
# The client under test can only report what its OWN copy of the prop did. The task this
# file answers — *"it doesnt actually throw"* — needs the REFEREE to agree, because the
# throw is host-authoritative: the client asks, the host validates, and the host broadcasts.
# A host that never accepted the request is the whole hypothesis, so the host's own view has
# to be recorded rather than inferred.
#
# ⚠️ POLLED EVERY FRAME, NOT ON THE REPORT CLOCK. `Slipper.CarryState.FLYING` lasts about a
# second and the referee reports every two, so a sampled watch would miss most throws and
# report "the host never saw it" about a build where the host saw it fine. This is three
# dictionary reads a frame.
#
# ⚠️ ONLY NON-BOT HANDS ARE LATCHED. The AI attackers throw constantly and their throws say
# nothing about this run; a seat is only interesting once a HUMAN is driving it, which is
# exactly `is_bot == false`. That also makes the latch a fair discriminator on the dropper's
# seat, which is bot-held for the ~17 s the human is away.
# =============================================================================

## slipper array index -> the `player_name` of the last HUMAN seen holding it, or "" for
## "nothing worth reporting". Cleared on the transition so one throw prints one line.
var _carry_watch: Dictionary = {}

func _process(_delta: float) -> void:
	if _scene_name() != "Main":
		return
	_watch_throws()
	# ⚠️ MOVED HERE FROM THE ANCHOR'S REPORT LOOP, 2026-08-04. That loop now `await`s a
	# throw drive that can legitimately block for tens of seconds waiting for the can to be
	# stood back up, and a seat watch that stops sampling for that long can miss the whole
	# bot-holds window — which would turn a green run into "this process never witnessed the
	# reclaim". This is idempotent and one-shot guarded, so running it per frame is strictly
	# safer than running it on a clock.
	if _role == "referee" or _role == "anchor":
		_watch_dropper_seat(_role)
		_watch_joiner_name(_role)

func _watch_throws() -> void:
	var scene: Node = get_tree().current_scene
	var list: Variant = scene.get("slippers") if scene != null else null
	if not (list is Array):
		return
	for i in range((list as Array).size()):
		var slipper: Node = (list as Array)[i]
		if slipper == null or not is_instance_valid(slipper):
			continue
		var carried: bool = int(slipper.get("state")) == Slipper.CarryState.CARRIED
		var holder: Node = slipper.get("carrier")
		if carried and holder != null and not bool(holder.get("is_bot")):
			# ⚠️ THE SEAT IS THE FALLBACK, AND WITHOUT IT THIS WATCH IS BLIND TO THE ONE
			# SCENARIO IT MATTERS MOST IN. `player_name` is written from the SPAWN packet,
			# and a mid-match joiner does not get a spawn — it takes over a placeholder's
			# existing body through `_rpc_reclaim_character`, which never touches the name.
			# Measured 2026-08-04 on the referee: `PICK 863342991 slot=1 player_name=''` for
			# a live human. Latching on that empty string made every throw the latecomer made
			# invisible to this function on all three processes, which read as "the host never
			# saw it" on a run where the host saw it fine. (The empty name itself is a real,
			# separate defect and is NOT this run's business.)
			var who := String(holder.get("player_name"))
			if who == "":
				who = "slot%d" % [int(holder.get("player_slot"))]
			_carry_watch[i] = who
			continue
		if carried:
			# A bot's hand, or a hand this peer has not resolved yet. Neither is a throw
			# this run has anything to say about.
			_carry_watch[i] = ""
			continue
		var was: String = String(_carry_watch.get(i, ""))
		if was == "":
			continue
		_carry_watch[i] = ""
		var at: Vector3 = slipper.get("global_position")
		# ⚠️ A THROW AND A DROP ARE NOT THE SAME EVENT AND ARE NOT REPORTED AS ONE. A carrier
		# who is stunned, tagged, or caught by a round reset leaves CARRIED straight for
		# LOOSE (`_apply_landed`); only `_apply_thrown` goes to FLYING. Folding the two
		# together would let a shove that knocked the tsinelas out of somebody's hand pass
		# for the throw this run exists to witness.
		var flying: bool = int(slipper.get("state")) == Slipper.CarryState.FLYING
		print("[%s] %s thrower=%s slipper=%d state=%d at=%.2f,%.2f,%.2f" % [
			_role, "THROW-OBSERVED" if flying else "DROP-OBSERVED",
			was, i, int(slipper.get("state")), at.x, at.y, at.z])

func _trace_round_started(round_number: int, defender_slot: int) -> void:
	print("[%s TRACE] MatchManager.round_started(round=%d defender=%d) at %.1fs, bodies=%d" % [
		_role, round_number, defender_slot,
		Time.get_ticks_msec() / 1000.0, _bodies().size()])

func _address() -> String:
	return "%s:%d" % [_host, _port]

## Connected peers that are neither this process nor the referee. ⚠️ Peer 1 is subtracted
## by LITERAL rather than through `NetworkManager.is_seatless_referee()`, because that
## function needs `is_dedicated`, which only becomes true on this client once
## `_rpc_announce_dedicated` lands — and this is polled from the moment the lobby opens.
func _other_humans() -> int:
	var count := 0
	var me := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	for peer_id in NetworkManager.connected_peer_ids:
		if peer_id != me and peer_id != 1:
			count += 1
	return count

## Every seat on the lobby board has pressed READY, and there are at least two of them.
## Read off `match_setup.gd`'s own broadcast dictionaries rather than off the START button,
## because that button is this client's local guess and the host re-decides for itself.
func _lobby_all_ready(lobby: Node) -> bool:
	if not is_instance_valid(lobby):
		return false
	var seats: Variant = lobby.get("_peer_seats")
	var ready: Variant = lobby.get("_peer_ready")
	if not (seats is Dictionary) or not (ready is Dictionary):
		return false
	# This peer plus whoever it was told to wait for. `--wait-for=0` is a lone anchor
	# starting the match by itself, which is the setup the latecomer scenario needs.
	if (seats as Dictionary).size() < 1 + _wait_for:
		return false
	for peer_id in (seats as Dictionary):
		if not bool((ready as Dictionary).get(peer_id, false)):
			return false
	return true

# =============================================================================
# THE SERVER. Same shape as `dedicated_recycle_run.gd::_referee` — the process BECOMES the
# dedicated lobby by hosting the real `MatchSetup.tscn` with the real `--dedicated --port=`
# arguments, which is the only vantage point from which the host's own seat bookkeeping can
# be read at all. A `--headless` server started from PowerShell can only be asked questions
# a client can already ask.
# =============================================================================

func _referee() -> void:
	var screen: Node = load(MATCH_SETUP).instantiate()
	get_tree().root.add_child.call_deferred(screen)
	await get_tree().process_frame
	get_tree().current_scene = screen
	await get_tree().create_timer(1.0).timeout
	_check("the referee is hosting", NetworkManager.is_host())
	_check("and knows it is one", NetworkManager.is_dedicated)
	print("[referee] port=%d code=%s" % [_port, NetworkManager.join_code])
	var elapsed := 0.0
	while elapsed < _live + 30.0:
		await get_tree().create_timer(2.0).timeout
		elapsed += 2.0
		_nudge_round_clock()
		_host_report(int(elapsed))
	_done("referee")

## HOST ONLY, and only under `--nudge-round`. See `_nudge_round`'s own doc for why cutting
## the clock is a fixture rather than a shortcut past the rule under test.
##
## ⚠️ IT ARMS ON THE QUEUE, NOT ON A STOPWATCH. The first cut waits until
## `waiting_seat_tokens` is actually non-empty — i.e. until the host has genuinely admitted
## somebody as a provisional spectator — so a build that refuses or seats the newcomer
## instead never gets its round shortened, and the run fails on the check rather than on a
## timing coincidence.
func _nudge_round_clock() -> void:
	if not _nudge_round or not NetworkManager.is_host():
		return
	if not RoundManager.round_active or MatchManager.round_number < 1:
		return
	if MatchManager.round_number > NUDGE_LAST_ROUND:
		return
	if _nudge_armed_ms == 0:
		if NetworkManager.waiting_seat_tokens.is_empty():
			return
		_nudge_armed_ms = Time.get_ticks_msec()
		print("[referee] NUDGE armed — %d peer(s) waiting for a seat" % [
			NetworkManager.waiting_seat_tokens.size()])
		return
	if Time.get_ticks_msec() - _nudge_armed_ms < NUDGE_ARM_DELAY_MS:
		return
	if RoundManager.time_left <= NUDGE_TARGET_SECONDS:
		return
	RoundManager.time_left = NUDGE_TARGET_SECONDS
	print("[referee] NUDGE round=%d clock cut to %.0fs (the rotation is the thing under test)" % [
		MatchManager.round_number, NUDGE_TARGET_SECONDS])

## Everything the host knows about who is who. Printed on a clock rather than on an event
## because the interesting window (identify → reroute → disconnect → identify again) is
## three seconds wide and spans two connections.
func _host_report(t: int) -> void:
	var scene: Node = get_tree().current_scene
	var where: String = String(scene.name) if scene != null else "<null>"
	var line := "[referee t=%ds] scene=%s in_progress=%s peers=%s" % [
		t, where, str(NetworkManager.match_in_progress),
		str(NetworkManager.connected_peer_ids)]
	if scene != null and String(scene.name) == "Main":
		# § THE WAITING ROOM INSIDE A RUNNING MATCH. The queue and the seat supply are the
		# two numbers every ruling in `NetworkManager._rule_on_mid_match_arrival` is made
		# from, so they are printed side by side: a refusal is only correct if `free` was
		# genuinely exhausted, and a promotion is only correct if `free` said there was room.
		line += " waiting=%d free_seats=%d" % [
			NetworkManager.waiting_seat_tokens.size(), NetworkManager.free_seat_count()]
		line += " tokens=%s seats=%s spawned=%s" % [
			str(_short_tokens(NetworkManager.peer_tokens)),
			str(_short_seats(scene.get("_token_join_index"))),
			str((scene.get("_spawned_peer_ids") as Dictionary).keys())]
		line += " bodies=%s" % [_bodies_line(scene)]
		# ⚠️ THE HOST'S OWN COPY OF THE WORLD LINE, so "the returning peer thinks its hand
		# is empty" can be read against "the host thinks that hand is full". Without this
		# side the client's report is a claim with nothing to check it.
		line += " | %s" % [_world_line()]
	print(line)
	if scene != null and String(scene.name) == "Main":
		# ⚠️ THE HOST'S OWN PICK TABLE, PRINTED EVERY TICK. `main.gd::_apply_reclaimed_picks`
		# runs here first and reads `picks_for()`, which is host-side state — so if the
		# fighter is wrong ON THE REFEREE the fault is upstream of every client and no
		# amount of client-side catch-up can repair it. This is the control line for the
		# whole run.
		for body in _bodies():
			print("[referee t=%ds] %s" % [t, _pick_line(body)])
		_watch_dropper_seat("referee")

## Tokens are 32 hex characters and there are four of them; the last six are plenty to tell
## two peers apart and keep a report line readable.
func _short_tokens(map: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in map:
		out[key] = String(map[key]).right(6)
	return out

func _short_seats(map: Variant) -> Dictionary:
	var out: Dictionary = {}
	if map is Dictionary:
		for key in (map as Dictionary):
			out[String(key).right(6)] = (map as Dictionary)[key]
	return out

# =============================================================================
# THE ANCHOR. Connects first, so `_claim_lobby_leader_if_vacant` hands it the lobby and it
# is the peer that can press START MATCH on a dedicated server. Then it sits there, which
# is its whole job: see this file's header for why an empty room ends the match.
# =============================================================================

func _anchor() -> void:
	var screen: Node = await _open_setup()
	screen.call("_begin_join", _address())
	await get_tree().create_timer(3.0).timeout
	var lobby: Node = get_tree().current_scene
	var in_lobby := lobby != null and String(lobby.name) == "MatchSetup"
	_check("the anchor reached the lobby", in_lobby)
	_check("the anchor connected", NetworkManager.is_networked())
	_check("the anchor leads the lobby, so it can press START",
		NetworkManager.is_lobby_leader())
	# See the same guard in `_dropper` for why a missing method is fatal, not a no-op.
	if not in_lobby:
		_done("anchor")
		return
	lobby.call("_on_primary_pressed") # READY

	# ⚠️⚠️ IT WAITS FOR A SECOND HUMAN BEFORE IT LOOKS AT THE BUTTON, AND WITHOUT THIS THE
	# RUN SILENTLY TESTS SOMETHING ELSE. START MATCH is gated on everyone SEATED being
	# ready — with only the anchor in the lobby that is satisfied the instant it presses
	# READY, so the first version of this started the match three seconds in, before the
	# dropper had connected at all. Measured: the dropper then landed on `Main.tscn`
	# straight out of `_rpc_route_to_running_match` and the run exercised the FIRST-TIME
	# late joiner instead of a rejoin.
	var waited := 0.0
	while waited < 45.0 and _other_humans() < _wait_for:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	_check("the other client is in the lobby too", _other_humans() >= _wait_for)
	# ⚠️⚠️ AND THEN IT WAITS FOR THE OTHER SEAT TO ACTUALLY BE READY, WHICH IS A SECOND,
	# LATER FACT. `_rpc_request_begin_match` re-checks `_everyone_ready_to_start()`
	# HOST-side and silently returns if it fails — deliberately, so a peer un-readying in
	# the same frame as the press cannot start a match it just left. Measured: pressing on
	# "the dropper has CONNECTED" put the request on the wire two seconds before the
	# dropper pressed READY, the server dropped it on the floor exactly as designed, and
	# both clients sat in the lobby for the rest of the run with nothing on screen to say
	# why.
	while waited < 70.0 and not _lobby_all_ready(lobby):
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	_check("both seats are ready", _lobby_all_ready(lobby))
	# Re-pressed while the lobby is still up rather than pressed once and hoped: the button
	# is a request, not a command, and one refused request is indistinguishable from a lost
	# one from this side.
	var pressed := 0.0
	while pressed < 15.0 and _scene_name() == "MatchSetup":
		if is_instance_valid(lobby):
			lobby.call("_on_start_pressed")
		await get_tree().create_timer(1.0).timeout
		pressed += 1.0
	await get_tree().create_timer(8.0).timeout
	_check("the anchor is in the match scene", _scene_name() == "Main")
	_press_ready_up()
	await get_tree().create_timer(6.0).timeout
	print("[anchor] round=%d active=%s" % [MatchManager.round_number, str(RoundManager.round_active)])
	_check("a round is genuinely running", RoundManager.round_active)

	var elapsed := 0.0
	while elapsed < _live:
		await get_tree().create_timer(1.0).timeout
		elapsed += 1.0
		# ⚠️ POLLED AT 1 Hz WHILE REPORTING AT 0.2 Hz, AND THE TWO RATES ARE DELIBERATE.
		# `_watch_dropper_seat` is looking for an EDGE (`is_bot` going false again) that
		# lands wherever the day's scene-load time puts it, so it has to be sampled far
		# more often than a report anybody reads. The report itself stays at five seconds
		# because it prints a line per body and this loop runs for over a minute.
		_watch_dropper_seat("anchor")
		_keep_lata_up()
		if int(elapsed) % 5 != 0:
			continue
		_report("anchor t=%ds" % int(elapsed))
		# ⚠️ THE CONTROL, MEASURED AT ROUGHLY THE MOMENT THE DROPPER COMES BACK. The
		# anchor never left, so its body is a normally-spawned one in the SAME match on
		# the SAME build — which is the only honest thing to diff a reclaimed body
		# against. 20 s lines up with the dropper's AFTER (it spends ~14 s reconnecting
		# after a ~7 s pre-round settle), and one shot rather than every tick because the
		# push probe deliberately staggers the body it tests.
		if int(elapsed) == 10:
			await _check_abilities("CONTROL")
	# ⚠️ A CHECK THAT NEVER RAN MUST NOT READ AS A PASS. The anchor's whole contribution to
	# this run is the third-party view of the reclaim; if the dropper never came back
	# inside `--live` the run has measured nothing about it, and reporting green would be
	# worse than reporting red. Only in the rejoin scenario — the latecomer one has no
	# dropper and no reclaim to watch.
	if _wait_for > 0 and _expect_character != "":
		_check("the anchor actually witnessed the reclaim it is here to judge",
			_reclaim_checked)
	_done("anchor")

# =============================================================================
# ⚠️⚠️ § THE ANCHOR PLAYS TAYA, AND WITHOUT THIS NO THROW IN THIS HARNESS IS EVER LEGAL.
#
# `RoundManager.can_throw()` refuses everybody while the lata is DOWN, and in this run
# nothing ever stood it back up: the anchor connects first, so it takes seat 0, which is
# round 1's defender — and a defender that just stands there is the one player who CAN
# restore the can and never does. Measured on the run that added the throw drive: the AI
# attackers put the can over within seconds of the whistle and `lata_up=false` on all three
# processes for the remaining 80 s, so the throw check timed out with
# `reason=gate-never-opened` on a build where nothing about throwing had been tested at all.
#
# ⚠️ IT IS THE REAL BUTTON, NOT `lata.host_restore()`. Holding `grab` inside the ring is the
# taya's only verb (`carrier.gd::_step_reset_channel` -> `_request_reset` -> the host's
# `host_restore`), and reaching past it would have this harness manufacture a game state no
# player can produce — the exact failure this file's own § THE THREE VERBS header refuses.
#
# ⚠️ THE KEY IS SIMPLY LEFT DOWN. `grab` does nothing else for a defender (`_step_grab`
# returns immediately for one), the channel zeroes itself on release, and re-pressing it on
# a 1 Hz poll would restart a 1.5 s channel forever without ever completing one.
func _keep_lata_up() -> void:
	var body: CharacterBase = _my_body()
	var lata: Node = RoundManager.lata
	if body == null or lata == null or not body.is_defender:
		return
	if bool(lata.get("is_upright")):
		return
	# Stand on the mark. The taya spawns there anyway; this only recovers from a shove.
	var mark: Vector3 = lata.get("global_position")
	body.global_position = Vector3(mark.x, body.global_position.y, mark.z)
	_press("grab", true)

# =============================================================================
# THE DROPPER. The player in the report.
# =============================================================================

func _dropper() -> void:
	# ⚠️ LETS THE ANCHOR IDENTIFY FIRST, and that is not cosmetic. The lobby leader is
	# whoever identifies first (`_claim_lobby_leader_if_vacant`), and on a dedicated server
	# only the leader can press START MATCH. A dropper that won that race would leave
	# nobody able to start the match this run exists to interrupt.
	await get_tree().create_timer(6.0).timeout
	var screen: Node = await _open_setup()
	screen.call("_begin_join", _address())
	await get_tree().create_timer(3.0).timeout
	var lobby: Node = get_tree().current_scene
	var in_lobby := lobby != null and String(lobby.name) == "MatchSetup"
	_check("the dropper reached the lobby", in_lobby)
	_check("the dropper connected", NetworkManager.is_networked())
	# ⚠️ GUARDED ON HAVING ACTUALLY LANDED THERE, the same trap `dedicated_recycle_run.gd`
	# documents: `Object.call()` for a method the node does not have is a HARD ERROR that
	# kills the process before `_done()` ever runs, so a run that went somewhere unexpected
	# reports two failures and then nothing at all — which reads as a harness crash rather
	# than as the finding. Measured here on the run where the anchor started the match early
	# and this landed on `Main` instead of `MatchSetup`.
	if not in_lobby:
		_done("dropper")
		return
	lobby.call("_on_primary_pressed") # READY

	# The anchor presses START; both ends change scene on `_rpc_begin_match`.
	var waited := 0.0
	while waited < 45.0 and _scene_name() != "Main":
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	_check("the dropper is in the match scene", _scene_name() == "Main")
	_press_ready_up()
	# ⚠️ POLLED RATHER THAN SLEPT THROUGH. The first version waited a flat 7 s and printed
	# once, and that single sample said `round=0 active=false` while the anchor's sample
	# from the same match said `round=1 active=true` — which reads as the two peers
	# permanently disagreeing when it may only be that the countdown had not finished. A
	# state this run's whole conclusion rests on cannot be read once.
	var settle := 0.0
	while settle < 14.0:
		await get_tree().create_timer(1.0).timeout
		settle += 1.0
		print("[dropper t=%ds] %s" % [int(settle), _world_line()])
		# ⚠️ THE CLIENT'S OWN COPY OF ITS OWN `character_index`, SAMPLED FROM THE FIRST
		# SECOND IN `Main`. Measured 2026-08-03: the REFEREE printed `char=-1` for both
		# human bodies for the first eight seconds of the match while its Visual showed
		# the right face — i.e. the host set the pick at spawn and something wiped it
		# afterwards. The only other writer is the synchronizer, whose authority for a
		# human body IS that human's own client, so this line is what separates "the
		# client never had the value" from "the host lost it on its own".
		print("[dropper t=%ds] %s" % [int(settle), _pick_line(_body_named(DROPPER_NAME))])
		if RoundManager.round_active and RoundManager.player_at(1) != null:
			break
	print("[dropper] round=%d active=%s" % [MatchManager.round_number, str(RoundManager.round_active)])

	# ---- BEFORE ----------------------------------------------------------------
	var before := _report("dropper BEFORE")
	_check("BEFORE: the dropper owns a body", before["owned"] != "")
	_check("BEFORE: the dropper is looking through a camera", before["camera"] != "<none>")
	# ⚠️ THE PICK IS RECORDED BEFORE THE DROP AND COMPARED AFTERWARDS, rather than only
	# compared against the command line. "They came back on the same fighter they left on"
	# is the player's actual claim, and it is a strictly stronger statement than "they came
	# back on the fighter the harness asked for" — it also catches a match in which the
	# pick never arrived in the first place, which would otherwise make both halves of the
	# run agree on the same wrong number.
	var before_body := _body_named(DROPPER_NAME)
	_check("BEFORE: the dropper's own body carries their pick",
		before_body != null and before_body.character_index
			== CharacterRoster.index_of(StringName(_expect_character)))
	var before_index: int = before_body.character_index if before_body != null else -1
	var before_props := _seat_props(before_body.player_slot) if before_body != null else {}
	print("[dropper BEFORE] %s" % [_pick_line(before_body)])
	# ⚠️⚠️ THE CONTROL, AND IT IS THIS PROCESS RATHER THAN THE ANCHOR'S. 🧑 2026-08-04:
	# *"still cant throw on rejoin"* — a claim about a DIFFERENCE, so the run is worthless
	# without a same-build, same-match measurement of a player who has NOT rejoined.
	#
	# The anchor cannot be that control: it connects first, so it takes seat 0, which is
	# round 1's DEFENDER — and a defender may not throw at all (`can_throw` refuses one
	# outright), so `_check_abilities` skips the whole pickup-and-throw branch for it. That
	# is not a fixable ordering detail; it is what the anchor is FOR.
	#
	# So the control is the dropper itself, five seconds before it drops: same process, same
	# match, same seat, same build, one rejoin apart. If this FAILS and AFTER fails too,
	# throwing is broken for everybody and the rejoin is a red herring; if this passes and
	# AFTER fails, the defect is rejoin-specific. One run answers it either way.
	await _check_abilities("BEFORE")

	# ---- THE DROP --------------------------------------------------------------
	# ⚠️ THE SCENE TEARDOWN IS COPIED FROM `main.gd::_on_server_disconnected`, ON PURPOSE.
	# That is what a real disconnected player's process does — reset the two autoloads,
	# clear the launch handoff, and land back on the server browser — and a harness that
	# skipped it would be rejoining from a state no player is ever in.
	print("[dropper] --- dropping ---")
	NetworkManager.disconnect_network()
	MatchManager.reset()
	RoundManager.reset()
	GameLaunch.reset()
	var match_scene: Node = get_tree().current_scene
	if match_scene != null:
		match_scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(3.0).timeout
	print("[dropper] dropped: networked=%s bodies=%d" % [
		str(NetworkManager.is_networked()), _bodies().size()])

	# ---- THE RETURN ------------------------------------------------------------
	var screen2: Node = await _open_setup()
	screen2.call("_begin_join", _address())
	# The reroute costs a scene change, a deliberate disconnect and a whole fresh
	# connection (`_rpc_route_to_running_match`), then `Main.tscn` plus the map plus four
	# characters have to load. Same budget `dedicated_match_run.gd` measured for a first
	# load, doubled because this path does it after a round trip.
	await get_tree().create_timer(14.0).timeout

	var after := _report("dropper AFTER")
	_check("AFTER: the returning player is in the match scene",
		String(after["scene"]) == "Main")
	_check("AFTER: the world is populated (four bodies)", int(after["bodies"]) == 4)
	_check("AFTER: the returning player owns a body", String(after["owned"]) != "")
	_check("AFTER: the returning player has a camera to look through",
		String(after["camera"]) != "<none>")
	_check("AFTER: it is THEIR OWN seat, the one they had before",
		String(after["owned_slot"]) == String(before["owned_slot"])
			and String(before["owned_slot"]) != "")
	_check("AFTER: no bot is still driving that body", not bool(after["owned_is_bot"]))
	# ---- THE FIGHTER ------------------------------------------------------------
	# ⚠️ ASSERTED ON THIS PROCESS TOO, NOT ONLY ON THE TWO THAT STAYED. This is the screen
	# in the report. `_watch_dropper_seat` cannot fire here — this process was not running
	# while a bot held the seat, so it never sees the edge — so the same assertion is
	# invoked directly.
	var after_body := _body_named(DROPPER_NAME)
	_assert_dropper_picks("dropper AFTER")
	# ⚠️ THE NAME IS ASSERTED SEPARATELY FROM THE FIGHTER, on the same body and at the same
	# moment. A rejoiner's body kept its name across the AI window on purpose, so this half is
	# expected to have been green before the fix as well as after it — and that is the point:
	# the fix must not be a trade that repairs the latecomer by breaking the rejoiner. This is
	# the line that would catch that.
	_assert_own_name("dropper AFTER")
	_check("AFTER: it is the SAME fighter they dropped out on",
		after_body != null and before_index >= 0
			and after_body.character_index == before_index)
	if not before_props.is_empty():
		var after_props := _seat_props(after_body.player_slot) if after_body != null else {}
		print("[dropper AFTER] props before=%s after=%s" % [str(before_props), str(after_props)])
		_check("AFTER: the same lata and tsinelas they dropped out with",
			after_props == before_props)
	await _check_abilities("AFTER")
	_done("dropper")

# =============================================================================
# ⚠️⚠️ § SHARED BY THE THREE MID-MATCH ARRIVAL ROLES (latecomer, filler, refused).
# =============================================================================

## Knock on a match that is already running, by the route a real player takes: the server
## browser, a typed address, `_begin_join`. Returns once the join has had `settle` seconds to
## resolve into whatever the host ruled.
func _knock_mid_match(settle: float) -> void:
	await get_tree().create_timer(_join_after).timeout
	var screen: Node = await _open_setup()
	screen.call("_begin_join", _address())
	await get_tree().create_timer(settle).timeout

## Whatever the browser is telling this player, or "" off any other screen. Read off the
## LABEL rather than off `GameLaunch.pending_status_message` — `multiplayer_setup.gd::_ready`
## consumes that var into the label and clears it, so by the time anything can look the var
## is empty on a healthy build and on a broken one alike.
func _status_text() -> String:
	var scene: Node = get_tree().current_scene
	if scene == null or String(scene.name) != "MultiplayerSetup":
		return ""
	var label := scene.get_node_or_null("%StatusLabel") as Label
	if label == null:
		label = _first_named(scene, "StatusLabel") as Label
	return label.text if label != null else ""

## Is this peer being shown the spectator's view — the camera `main.gd::_enter_spectator_mode`
## adds to `Main` under that exact name? Asked of the TREE rather than of a flag, because a
## flag set without a camera is precisely the "grey screen" this harness exists for.
func _has_spectator_camera() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null or String(scene.name) != "Main":
		return false
	return scene.get_node_or_null("Spectator") != null

# =============================================================================
# ⚠️ THE REGRESSION HALF. A FIRST-TIME JOINER MID-MATCH TAKES THE SAME BROKEN LINE.
#
# `main.gd::_start_joining()` is reached with a live `join_game()` to make in exactly one
# situation — `NetworkManager._rpc_route_to_running_match` dropped the connection and told
# this process to open a new one — and that reroute does NOT care whether the arriving peer
# has ever been in this match before. So B-153 broke the brand-new mid-match joiner exactly
# as thoroughly as the rejoiner, and both are proved by the same fix.
#
# What differs is only what the host does with them: a rejoiner's token is already in
# `_token_join_index` and takes its old seat back off a bot (`_rpc_reclaim_character`); a
# newcomer's is not and gets `_first_free_seat()`. Both end in a body and a camera, which is
# all this asserts — the seat rules are `dedicated_match_run.gd`'s business.
# =============================================================================

func _latecomer() -> void:
	# The anchor needs to have claimed the lobby, readied, started the match and loaded it
	# before this client knocks — the whole premise is arriving at a room that is already
	# playing. `--join-after=` is generous: the same 9 s scene-load budget plus the lobby dance.
	await _knock_mid_match(12.0)

	# ---- ADMITTED, AND WATCHING ---------------------------------------------
	# ⚠️⚠️ THIS BLOCK IS THE ONE THAT INVERTED. It used to demand a body here; a body here
	# is now the defect. See § THE WAITING ROOM INSIDE A RUNNING MATCH at the top of this file.
	var waiting := _report("latecomer waiting")
	print("[latecomer] WAIT-CHECK scene=%s provisional=%s spectator_cam=%s body=%s" % [
		_scene_name(), str(NetworkManager.provisional_spectator),
		str(_has_spectator_camera()), str(_my_body() != null)])
	_check("a mid-match newcomer is admitted rather than turned away",
		String(waiting["scene"]) == "Main")
	_check("...as a SPECTATOR, because the host said so", NetworkManager.provisional_spectator)
	_check("...with a camera to watch through", _has_spectator_camera())
	# ⚠️ THE NEGATIVE IS THE POINT OF THE WHOLE CHANGE. Every mid-match-joiner defect found on
	# 2026-08-04 came out of the arrival-time reclaim this asserts did NOT happen.
	_check("...and NO body of its own while it waits", _my_body() == null)
	_check("...while the match it is watching is still fully populated",
		int(waiting["bodies"]) == 4)

	# ---- SEATED AT THE NEXT ROLE ROTATION ------------------------------------
	# Polled rather than slept on: the rotation lands wherever the day's round clock and the
	# referee's cut put it, and a fixed sleep would report whichever side of it we woke on.
	var start_round := MatchManager.round_number
	var waited := 0.0
	while waited < 100.0 and _my_body() == null:
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
	var after := _report("latecomer seated")
	print("[latecomer] PROMOTE-CHECK round %d -> %d after %.0fs body=%s spectator_cam=%s" % [
		start_round, MatchManager.round_number, waited,
		str(_my_body() != null), str(_has_spectator_camera())])
	_check("a waiting newcomer is given a real seat", _my_body() != null)
	# ⚠️ "IT HAPPENED **AT** A ROTATION" IS A SEPARATE FACT FROM "IT HAPPENED". A build that
	# seated the newcomer on arrival would satisfy the line above and fail this one, which is
	# exactly the regression this scenario is here to catch from now on.
	_check("...at a ROLE ROTATION, not on arrival", MatchManager.round_number > start_round)
	_check("...and the spectator camera is gone with it", not _has_spectator_camera())
	_check("owning a body", String(after["owned"]) != "")
	_check("and a camera to look through", String(after["camera"]) != "<none>")
	# ⚠️ THE SAME THREE VERBS, BECAUSE IT IS THE SAME DEFECT. `RoundManager.register_player`
	# ran only at a round boundary and the slipper carry state was never sent to anybody who
	# missed the pickup — neither of those cares whether the arriving peer has been in this
	# match before. A first-time mid-match joiner was as unable to throw, pick up or be
	# shoved as a returning one, and is proved fixed by the same probe.
	# ⚠️ THE SAME PICK QUESTION, ASKED OF A PEER WITH NOTHING TO RESTORE. A first-time
	# mid-match joiner steps into a seat a bot has been holding since `_start_hosting`, by
	# the SAME `_rpc_reclaim_character` path a returning player takes — the host does not
	# branch on whether it has seen this token before, only on whether the seat has a body.
	# So if the reclaim path drops the arriving human's roster pick, it drops it here too,
	# and this is the cheaper of the two reproductions.
	if _expect_character != "":
		var body := _my_body()
		var want := CharacterRoster.index_of(StringName(_expect_character))
		print("[latecomer] %s" % [_pick_line(body)])
		_check("a promoted newcomer wears the fighter they picked (%s)"
			% _roster_name(want), body != null and body.character_index == want)
	# ⚠️ AND THE NAME, WHICH IS THE OTHER THING THAT ONLY EVER ARRIVED IN THE SPAWN PACKET.
	# A first-time mid-match joiner takes over a placeholder built from `picks_for(-1 - index)`
	# — a sentinel peer with no name — so before the fix this read `player_name=''` here and on
	# both other processes, and `display_name()` fell through to the seat label "P2".
	_assert_own_name("latecomer")
	# ⚠️ THE THROW HALF OF THIS IS SKIPPED BY `_check_abilities` ITSELF WHEN THE PROMOTED SEAT
	# IS THIS ROUND'S TAYA, AND THAT IS THE RULES, NOT A GAP. The anchor identifies first and
	# takes seat 0; the promotion takes `_first_free_seat()` = seat 1; `defender_slot_for(2)`
	# is `(2 - 1) % 4` = 1. So in round 2 the newcomer IS the defender, and a defender may not
	# throw. `run_rejoin.ps1` therefore demands THROW-CHECK/THROW-OBSERVED only in the
	# `rejoin` scenario — see the ⚠️ on that block. Everything else here (the seat table, the
	# lata, the live round, the shove) is asserted for both.
	await _check_abilities("LATECOMER")
	# ⚠️⚠️ IT STAYS IN THE MATCH FOR A FEW SECONDS AFTER ITS OWN CHECKS, AND WITHOUT THIS THE
	# OTHER TWO PROCESSES CANNOT REPORT AT ALL. `run_rejoin.ps1` kills the anchor and the
	# referee the instant THIS process exits, and their NAME-CHECK is deliberately not
	# instantaneous — `_watch_joiner_name` gives the replicated `player_name` `NAME_SETTLE_MS`
	# (2 s) to arrive before it judges. Measured 2026-08-04: without this wait the promotion
	# landed at t≈70 s, this process was done at t≈75 s, and both observers were killed
	# mid-settle with zero NAME-CHECK lines — reported as two failures against a build where
	# the name was provably correct on the peer that owns it.
	await get_tree().create_timer(10.0).timeout
	_done("latecomer")

# =============================================================================
# ⚠️⚠️ § THE CAPACITY CASE. 🧑: *"we can't keep accepting 5 spectators for a lobby that has
# only 2 bot slots open."*
#
# Two roles, and neither of them is interesting alone:
#
#   filler   a newcomer that IS admitted to the queue and then simply stays in it. Its whole
#            job is to occupy one of the free seats' worth of queue so the next arrival has
#            nowhere to go. Headless: it asks nothing about a camera.
#   refused  the arrival after the queue is full. The one under test.
#
# ⚠️ THE FILLERS ASSERT THEIR OWN ADMISSION, which is what stops this scenario passing for
# the wrong reason. If a filler were refused (or seated) the queue would not actually be full
# when `refused` knocks, and its bounce would be measuring something else entirely.
# =============================================================================

func _filler() -> void:
	await _knock_mid_match(14.0)
	print("[filler] FILL-CHECK scene=%s provisional=%s body=%s" % [
		_scene_name(), str(NetworkManager.provisional_spectator), str(_my_body() != null)])
	_check("a filler is admitted to the waiting queue", NetworkManager.provisional_spectator)
	_check("...and holds no seat while it waits there", _my_body() == null)
	# Then it just sits, holding its place in the queue for the rest of the run. Without this
	# the process would exit, the host would drop its token at the next rotation, and the seat
	# it was occupying would be free again by the time `refused` arrives.
	await get_tree().create_timer(_live).timeout
	_done("filler")

func _refused() -> void:
	await _knock_mid_match(16.0)
	var status := _status_text()
	print("[refused] REFUSE-CHECK scene=%s networked=%s body=%s status='%s'" % [
		_scene_name(), str(NetworkManager.is_networked()), str(_my_body() != null), status])
	_check("a newcomer arriving at a full waiting queue is bounced back to the browser",
		_scene_name() == "MultiplayerSetup")
	# ⚠️ THE WORDS ARE ASSERTED, NOT JUST THE BOUNCE. A silent return to the browser is the
	# soft-lock Q-1/B-62 closed once already: the player is looking at the screen they started
	# from with no idea why, which reads as the JOIN button being broken.
	_check("...and told why, in words that name the cause",
		status.to_lower().contains("already started"))
	_check("...and is not left holding a connection to a match it is not in",
		not NetworkManager.is_networked())
	_check("...and never gets a body", _my_body() == null)
	_done("refused")

# =============================================================================
# Reporting
# =============================================================================

## Everything a player would be able to see, as numbers. Returns the same facts it prints so
## a check can be written against them rather than against a re-read of the tree.
func _report(tag: String) -> Dictionary:
	var scene: Node = get_tree().current_scene
	var bodies := _bodies()
	var owned := ""
	var owned_slot := ""
	var owned_is_bot := false
	var me := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	var lines: Array[String] = []
	for body in bodies:
		var mine: bool = body.is_multiplayer_authority()
		var ai: bool = body.get("ai_controller") != null
		var rig: Node = body.get_node_or_null("CameraRig")
		var rig_on := false
		if rig != null:
			for cam in [rig.get_node_or_null("FppPivot/FppCamera"), rig.get_node_or_null("TppArm/TppCamera")]:
				if cam != null and bool(cam.get("current")):
					rig_on = true
		lines.append("%s(slot=%s auth=%d mine=%s bot=%s ai=%s cam=%s)" % [
			body.name, str(body.get("player_slot")), body.get_multiplayer_authority(),
			str(mine), str(body.get("is_bot")), str(ai), str(rig_on)])
		if mine and not ai:
			owned = String(body.name)
			owned_slot = str(body.get("player_slot"))
			owned_is_bot = bool(body.get("is_bot"))
	var cam3d: Camera3D = get_viewport().get_camera_3d()
	var camera: String = String(cam3d.get_path()) if cam3d != null else "<none>"
	var local_body := "<none>"
	if scene != null and scene.has_method("get_local_character"):
		var lc: Node = scene.call("get_local_character")
		if lc != null:
			local_body = String(lc.name)
	print("[%s] scene=%s peer=%d networked=%s peers=%s" % [
		tag, _scene_name(), me, str(NetworkManager.is_networked()),
		str(NetworkManager.connected_peer_ids)])
	print("[%s] bodies=%d %s" % [tag, bodies.size(), " ".join(lines)])
	print("[%s] camera=%s get_local_character=%s round=%d hud='%s'" % [
		tag, camera, local_body, MatchManager.round_number, _hud_text(scene)])
	# The §THE PROPERTY DIFF block — printed for every body on every report, so a
	# reclaimed body and an ordinary one can be read against each other line for line.
	print("[%s] %s" % [tag, _world_line()])
	for body in bodies:
		print("[%s] %s" % [tag, _probe_line(body as CharacterBody3D)])
		# § THE PICKS REPORT — printed beside the property diff rather than instead of it,
		# because "the returning player has the wrong face" and "the returning player
		# cannot be shoved" were reported by the same human about the same rejoin and both
		# have to be readable off one run.
		print("[%s] %s" % [tag, _pick_line(body)])
	return {
		"scene": _scene_name(),
		"bodies": bodies.size(),
		"owned": owned,
		"owned_slot": owned_slot,
		"owned_is_bot": owned_is_bot,
		"camera": camera,
	}

# =============================================================================
# ⚠️⚠️ § THE PROPERTY DIFF. 🧑 2026-08-02, minutes after the rejoin itself started
# working: *"no throw, no getting pushed, no pickup"* — a returning player who can WALK
# and can do nothing else.
#
# "No getting pushed" is the one that says where to look. Being pushed is not an input
# path at all: a shove is decided on the host and arrives as
# `RoundManager._sync_shove(victim_slot, ...)`, which every peer applies to ITS OWN copy
# of that seat. So a body that walks but cannot be shoved is not deaf to the keyboard —
# something on this peer cannot find that seat.
#
# Hence this: everything that could plausibly differ between a reclaimed body and a
# normally-spawned one, dumped as numbers on BOTH processes (the anchor never dropped, so
# its own body is the control), rather than reasoned about. The autoload half is printed
# separately because it is PER PROCESS, not per body — and that turned out to be where
# the whole difference lived.
# =============================================================================

## The per-process state four separate rules read before a body may do anything: the
## `RoundManager` seat table (`player_at`, which every host broadcast is addressed
## through), the lata (half of `can_throw`), and the round clock.
func _world_line() -> String:
	var seats: Array[String] = []
	for slot in range(4):
		var who: Node = RoundManager.player_at(slot)
		seats.append("%d=%s" % [slot, String(who.name) if who != null else "<null>"])
	var slips: Array[String] = []
	var scene: Node = get_tree().current_scene
	var list: Variant = scene.get("slippers") if scene != null else null
	if list is Array:
		for i in range((list as Array).size()):
			var slipper: Node = (list as Array)[i]
			if slipper == null or not is_instance_valid(slipper):
				continue
			var holder: Node = slipper.get("carrier")
			# ⚠️⚠️ THE WORLD POSITION IS PART OF THE STATE AND WAS MISSING UNTIL 2026-08-04.
			# 🧑: *"upon rejoining i dont have a slipper, only until the next round"*. Answering
			# that needs the distinction between "the bot legitimately threw it, so it is lying
			# on the floor where anyone can see it" and "this peer has a slipper object in the
			# wrong place" — and owner/state/carrier alone cannot tell those apart. `Slipper.tscn`
			# replicates ONLY `position` and `owner_slot`; `state` and `carrier` come from the
			# `_rpc_slipper_*` broadcasts a joiner missed by definition, so the position is
			# precisely the field whose replication has to be READ rather than assumed.
			#
			# ⚠️ PRINTED ON ALL THREE PROCESSES SO IT CAN BE DIFFED ACROSS THEM. A LOOSE slipper
			# is static, so the same line logged on the referee, the anchor and the dropper
			# within a second of each other is a fair comparison; a FLYING one is not, and
			# `state` on the same line is what says which you are looking at.
			#
			# ⚠️ `global_position`, NOT `position`. A CARRIED slipper is reparented onto its
			# carrier's `HandAttachment` (`slipper.gd::_attach_to_hand()`), so its LOCAL position
			# is bone-space and near zero — which would read as "at the origin" and invent a bug
			# that is not there.
			var at: Vector3 = slipper.get("global_position")
			slips.append("s%d(owner=%s state=%s carrier=%s at=%.2f,%.2f,%.2f)%s" % [
				i, str(slipper.get("owner_slot")), str(slipper.get("state")),
				String(holder.name) if holder != null else "<null>",
				at.x, at.y, at.z, _carry_path(slipper)])
	var lata: Node = RoundManager.lata
	return ("WORLD round=%d round_active=%s lata=%s lata_up=%s throw_cd=%.2f time_left=%.1f "
		+ "defender_slot=%d rm_seats=[%s] %s") % [
		MatchManager.round_number, str(RoundManager.round_active), str(lata != null),
		str(lata != null and bool(lata.get("is_upright"))),
		RoundManager.throw_cooldown_left(),
		RoundManager.time_left, MatchManager.defender_slot,
		", ".join(seats), " ".join(slips)]

## ⚠️⚠️ THE SCENE-TREE PATH OF A **CARRIED** SLIPPER, PRINTED ON ALL THREE PROCESSES SO THE
## THREE CAN BE DIFFED. This is not decoration and it is not a debug leftover: it is the
## measurement the throw investigation turns on.
##
## `slipper.gd::_attach_to_hand()` re-parents a carried tsinelas onto
## `<body>/Visual/<model root>/Skeleton3D/HandAttachment/HandPoint`, and **every component
## of that path after `Visual` is built at runtime, per peer, from that peer's own idea of
## which MODEL this character is wearing**. `carrier.gd::_request_throw()` puts
## `slipper.get_path()` on the wire and the host resolves it with `get_node_or_null()` — so
## two peers that disagree about the model disagree about the path, and the host answers
## `null` and drops the throw on the floor with no error anywhere.
##
## Empty for a LOOSE or FLYING slipper: those sit at the home path every peer has had since
## the scene loaded, which is exactly why the PICKUP half of the same mechanism works.
func _carry_path(slipper: Node) -> String:
	if int(slipper.get("state")) != Slipper.CarryState.CARRIED:
		return ""
	return " path=%s" % [String(slipper.get_path())]

## Everything about ONE body that could differ. Read through `get()`/`call()` rather than
## through typed members so the harness keeps compiling if a field is renamed — a probe
## that fails to load reports nothing at all, which is worse than reporting a blank.
func _probe_line(body: CharacterBody3D) -> String:
	var slot: int = int(body.get("player_slot"))
	var seated: Node = RoundManager.player_at(slot)
	var can_throw: bool = RoundManager.can_throw(body as CharacterBase)
	return ("BODY %s slot=%d player_id=%s auth=%d mine=%s is_bot=%s ai_ctrl=%s "
		+ "ai_driven=%s input_parked=%s layer=%d mask=%d phys_proc=%s proc=%s "
		+ "can_process=%s state=%s settle=%s defender=%s holding=%s carrier_held=%s "
		+ "rm_seat=%s can_act=%s can_throw=%s inside_box=%s shove_cd=%.2f lunge_cd=%.2f "
		+ "punch_cd=%.2f throw_lock=%.2f") % [
		body.name, slot, str(body.get("player_id")),
		body.get_multiplayer_authority(), str(body.is_multiplayer_authority()),
		str(body.get("is_bot")), str(body.get("ai_controller") != null),
		str(body.call("is_ai_driven")), str(body.get("input_parked")),
		body.collision_layer, body.collision_mask,
		str(body.is_physics_processing()), str(body.is_processing()),
		str(body.can_process()), str(body.get("state")), str(body.get("_spawn_settle")),
		str(body.get("is_defender")), str(body.call("holding_slipper")),
		_carrier_held(body),
		"self" if seated == body else ("<null>" if seated == null else String(seated.name)),
		str(body.call("can_act")), str(can_throw), str(body.call("is_inside_box")),
		float(body.call("shove_cooldown_left")), _f(body, "_lunge_cooldown_left"),
		_f(body, "_punch_cooldown_left"), _carrier_lock(body)]

## The `Carrier` component's own idea of what is in the hand, which is a SEPARATE fact
## from `CharacterBase.holding_slipper()` — `notify_holding` writes both, and the whole
## point of printing them side by side is to catch a hand that only half-heard.
func _carrier_held(body: Node) -> String:
	var carrier: Node = body.get_node_or_null("Carrier")
	if carrier == null:
		return "<no carrier node>"
	var held: Node = carrier.call("held")
	return String(held.name) if held != null else "<null>"

func _carrier_lock(body: Node) -> float:
	var carrier: Node = body.get_node_or_null("Carrier")
	return float(carrier.call("throw_lock_left")) if carrier != null else -1.0

func _f(body: Node, field: String) -> float:
	var value: Variant = body.get(field)
	return float(value) if value != null else -1.0

# =============================================================================
# ⚠️⚠️ § THE PICKS REPORT. 🧑 2026-08-02: *"The player rejoins on a different player
# character and not the same character they were on."*
#
# Three separate facts are printed per body and they are deliberately NOT collapsed,
# because the whole bug class this file keeps finding is one of them being right while
# another is stale:
#
#   character_index  the replicated int — what this peer has been TOLD to wear.
#   model / material what `CharacterVisual` last actually INSTANCED. `apply()` is keyed
#                    on the model path AND the palette path (two roster entries can share
#                    a rig), and it is only ever called from `_ready()`, a role rotation
#                    and `main.gd::_apply_known_picks` — so an index that changes with
#                    nobody to tell the Visual leaves the player looking at the old face
#                    while every number in the log says the pick arrived.
#   can / slipper    `main.gd::_seat_prop_picks[slot]`, which is a SEPARATE table from the
#                    character index and is not a `CharacterBase` property at all. Same
#                    `picks_for()` dictionary feeds both, so a defect in re-reading it on
#                    reclaim cannot be scoped without measuring all three.
# =============================================================================

func _roster_name(index: int) -> String:
	return "<none>" if index < 0 else CharacterRoster.name_at(index)

## The lata/tsinelas picks `main.gd` holds for `slot` on THIS peer, or an empty dictionary
## when this peer has not been told. ⚠️ "not been told" is a real, expected state and not
## a failure by itself: `_rpc_sync_picks` reaches a client at the ready gate and again as
## an `rpc_id` to a late joiner, so a third-party peer's copy can legitimately predate the
## reclaim. It is reported as `<none>` rather than asserted against.
func _seat_props(slot: int) -> Dictionary:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return {}
	var table: Variant = scene.get("_seat_prop_picks")
	if not (table is Dictionary):
		return {}
	var row: Variant = (table as Dictionary).get(slot)
	return row if row is Dictionary else {}

## Everything about what one body is WEARING, on one line.
##
## ⚠️ `_current_key`/`_current_material_key` ARE READ OFF `CharacterVisual` ON PURPOSE.
## They are the paths it last actually instanced, which is the only honest answer to "what
## is on screen" on a process with no rendering device (`--headless`, and the referee is
## one). Deriving the model from `character_index` here would re-implement `_model_path()`
## and would agree with itself no matter what the player could see.
func _pick_line(body: Node) -> String:
	if body == null:
		return "<no body>"
	var index: int = int(body.get("character_index"))
	var visual: Node = body.get_node_or_null("Visual")
	var model := "<no visual>"
	var material := ""
	if visual != null:
		model = String(visual.get("_current_key")).get_file()
		material = String(visual.get("_current_material_key")).get_file()
	var slot: int = int(body.get("player_slot"))
	var props := _seat_props(slot)
	var props_text := "<none>"
	if not props.is_empty():
		var can := int(props.get("can", -1))
		var slipper := int(props.get("slipper", -1))
		props_text = "can=%d/%s slipper=%d/%s" % [
			can, String(CharacterRoster.can_at(can).get("name", "<none>")) if can >= 0 else "<none>",
			slipper,
			String(CharacterRoster.slipper_at(slipper).get("name", "<none>")) if slipper >= 0 else "<none>"]
	return "PICK %s slot=%d player_name='%s' is_bot=%s auth=%d char=%d/%s model=%s mat=%s %s" % [
		body.name, slot, String(body.get("player_name")), str(body.get("is_bot")),
		body.get_multiplayer_authority(), index, _roster_name(index), model, material,
		props_text]

## The body the run is about, wherever it currently lives. See DROPPER_NAME.
func _body_named(who: String) -> CharacterBase:
	for node in _bodies():
		var body := node as CharacterBase
		if body != null and body.player_name == who:
			return body
	return null

# =============================================================================
# ⚠️⚠️ § THE NAME WATCH, AND WHY IT MAY NOT USE `_body_named()`.
#
# Every other check in this file finds the joiner's body by `player_name == "DROPPER"` — see
# DROPPER_NAME, which says so and says why. That handle is USELESS HERE and worse than
# useless: the name is the thing under test, so a check that located the body by its name and
# then asserted its name would be a tautology that passes on any build, and in the LATECOMER
# scenario it cannot even find a body (the measurement is `player_name=''`).
#
# So the joiner is identified by two facts that have nothing to do with the property being
# measured:
#
#   · a human is driving it — `is_bot == false`, which `_rpc_reclaim_character` writes on
#     EVERY peer (`call_local`), so all three processes agree without asking the synchroniser;
#   · and it is not THIS process's own body, nor the anchor's.
#
# On the anchor its own body is excluded by ownership (`_my_body()`), which is a fact about
# this machine and cannot be wrong. On the referee — a dedicated server that owns no seat, and
# whose four AI bodies all fail the `is_bot` test — the only other human is the anchor, whose
# name IS reliable: the anchor was seated in the LOBBY, so its body came through the ordinary
# `MultiplayerSpawner` path that carries the name in the spawn packet. Confirmed on the
# baseline run of this fix, in the same log line that recorded the defect:
#
#     [referee t=44s] PICK 438837950 slot=0 player_name='ANCHOR' ...
#     [referee t=44s] PICK 1927296562 slot=1 player_name=''      ...   <- the latecomer
#
# ⚠️ NOT IDENTIFIED BY SEAT, although slot 1 would have worked on every run so far. Which seat
# a joiner lands in is `main.gd::_first_free_seat()`'s business and is exactly the kind of rule
# this harness must not quietly assume — see the file's own rule about asserting a game rule
# against a state the test created.
# =============================================================================

## The mid-match joiner's body as seen from a process that is NOT the joiner: the one
## human-driven body that is neither this machine's own nor the anchor's. Null while the seat
## is bot-held (the window between the drop and the reclaim) and null before the joiner
## arrives at all — both are real, expected states and neither is a failure by itself.
func _joiner_body() -> CharacterBase:
	var mine: CharacterBase = _my_body()
	for node in _bodies():
		var body := node as CharacterBase
		if body == null or body == mine or body.is_bot:
			continue
		if body.player_name == ANCHOR_NAME:
			continue
		return body
	return null

## True while a foreign human body is present, so the check below can fire on the RISING EDGE
## of one appearing rather than on a clock.
var _joiner_present: bool = false
## When that presence began, in ms. `_NAME_SETTLE_MS` after it the name is asserted — once per
## presence, by pushing this far into the future.
var _joiner_seen_ms: int = 0
## How many NAME-CHECK lines this process has printed. Capped so the rejoin scenario's two
## presences (before the drop, and again after the reclaim) each produce exactly one.
var _name_checks: int = 0

## ⚠️ THE VALUE IS GIVEN TIME TO ARRIVE BEFORE IT IS JUDGED, AND THAT IS NOT SLACK FOR A
## BROKEN BUILD. `player_name` is `replication_mode = 2` (ON_CHANGE) on `CharacterBase.tscn`:
## the joiner writes it on ITS machine at the reclaim and the synchroniser carries it outward
## on a later frame, so an observer that measured on the same frame `is_bot` went false would
## be measuring the network's latency rather than the fix. Two seconds is ~120 frames — orders
## of magnitude more than one ON_CHANGE update needs on loopback, and far short of anything
## that could hide a value that is never coming.
const NAME_SETTLE_MS: int = 2000
const NAME_CHECKS_MAX: int = 2

func _watch_joiner_name(tag: String) -> void:
	if _expect_name == "":
		return
	var body := _joiner_body()
	if body == null:
		# The seat went back to a bot (the drop) or the joiner has not arrived yet. Re-arm:
		# the rejoin scenario legitimately produces a SECOND presence, and it is the
		# interesting one.
		_joiner_present = false
		return
	if not _joiner_present:
		_joiner_present = true
		_joiner_seen_ms = Time.get_ticks_msec()
		return
	if _name_checks >= NAME_CHECKS_MAX:
		return
	if Time.get_ticks_msec() - _joiner_seen_ms < NAME_SETTLE_MS:
		return
	# One shot per presence. Pushed an hour out rather than latched with a bool, so the
	# re-arm above is the only thing that can make this fire again.
	_joiner_seen_ms = Time.get_ticks_msec() + 3_600_000
	_name_checks += 1
	_assert_joiner_name("%s #%d" % [tag, _name_checks], body)

## The verdict, as one machine-readable line so `run_rejoin.ps1` can require it to be PRESENT
## rather than merely require the absence of a FAIL — the rule § THE RECLAIM WATCH states.
func _assert_joiner_name(tag: String, body: CharacterBase) -> void:
	if body == null:
		print("[%s] NAME-CHECK ok=false reason=no-joiner-body expect='%s'" % [tag, _expect_name])
		_check("%s: there is a joiner body to read a name off" % tag, false)
		return
	var got := body.player_name
	var shown := body.display_name()
	var ok := got == _expect_name
	# ⚠️ `display_name()` IS PRINTED BESIDE THE RAW PROPERTY, because that is what a player
	# actually reads on the 3D nameplate and the scoreboard row, and the two can disagree: a
	# seat whose `is_bot` is still true would show a roster name over a correct `player_name`.
	# Asserted as well as printed — an empty name shows as the bare seat label "P2", which is
	# the exact symptom in the report.
	print("[%s] NAME-CHECK body=%s slot=%d got='%s' expect='%s' display='%s' is_bot=%s ok=%s" % [
		tag, body.name, body.player_slot, got, _expect_name, shown, str(body.is_bot), str(ok)])
	# ⚠️ THE MEASURED VALUE COMES FIRST IN THE MESSAGE, so the line reads correctly whether it
	# is prefixed with PASS or with FAIL. The first version said "is 'X', not 'Y'" and printed
	# "PASS  the joiner's name is 'DROPPER', not 'DROPPER'" on a healthy run.
	_check("%s: the joiner's name reads '%s' on this peer (want '%s')" % [
		tag, got, _expect_name], ok)
	_check("%s: ...so the label drawn over them is not the bare seat number" % tag,
		shown != "P%d" % [body.player_slot + 1])

## The same verdict from the JOINER'S OWN machine, where the body is found by ownership
## instead. ⚠️ NOT SUFFICIENT ON ITS OWN, WHICH IS WHY IT IS ONLY ONE OF THREE. The fix writes
## this property on the peer that owns the body, so this process is the one place it is
## guaranteed to look right whether or not it ever reached the wire — "a name that is only
## right locally is the bug half-fixed". The referee's and the anchor's NAME-CHECK lines are
## what make this one mean anything.
func _assert_own_name(tag: String) -> void:
	if _expect_name == "":
		return
	_assert_joiner_name(tag, _my_body())

# =============================================================================
# ⚠️⚠️ § THE RECLAIM WATCH, AND WHY IT IS EVENT-DRIVEN ON THREE PROCESSES.
#
# The returning player's fighter has to be right on EVERY screen, and the three screens
# learn about it by three different mechanisms, so one process asserting is not evidence
# about the other two:
#
#   the referee  wrote the value itself (`main.gd::_apply_reclaimed_picks` reads
#                `picks_for()`, which is host-side state and correct there by
#                construction). It is the control: if the HOST is wrong, nothing
#                downstream can be right.
#   the dropper  rebuilt `Main.tscn` from nothing, so every body it has arrived through
#                the spawner plus the late-joiner catch-up. This is the player's own
#                screen and the one in the report.
#   the anchor   never left. It owns neither the node nor the session for that seat, which
#                is exactly the peer class `main.gd`'s B-145 note measured reading -1 while
#                the host and the owner both read the right value.
#
# ⚠️ WATCHED RATHER THAN SAMPLED ON A CLOCK. The interesting transition is `is_bot` going
# true and then false again on one body, and it lands somewhere inside a ~20 s window
# whose position depends on how long a scene load takes on the day. A fixed sample would
# report whichever side of it the machine happened to be on.
# =============================================================================

## True once this process has seen the dropper's seat handed to a bot, which is what makes
## a later `is_bot == false` a RECLAIM rather than the original human still sitting there.
var _saw_bot_hold: bool = false
## Guards the assertion to one shot: it is a statement about an event, not about a state
## that can be re-read, and re-running it every tick would multiply one finding into twenty.
var _reclaim_checked: bool = false

func _watch_dropper_seat(tag: String) -> void:
	if _reclaim_checked or _expect_character == "":
		return
	var body := _body_named(DROPPER_NAME)
	if body == null:
		return
	if body.is_bot:
		if not _saw_bot_hold:
			_saw_bot_hold = true
			# ⚠️ THE MIDDLE MEASUREMENT THE TASK ASKS FOR — what the seat wears while the
			# bot has it. The prime hypothesis was that a bot stamps its OWN roster index
			# onto the body it takes over; this line is what settles that, on the two
			# processes still running while the human is away.
			print("[%s] BOT-HOLDS %s" % [tag, _pick_line(body)])
		return
	if not _saw_bot_hold:
		return # still the original human: the drop has not happened yet
	_reclaim_checked = true
	_assert_dropper_picks(tag)

## The verdict, printed as one machine-readable line so `run_rejoin.ps1` can require it to
## be PRESENT in each process's log rather than merely require no failures — a check that
## never ran and a check that passed look identical to a grep for "FAIL".
func _assert_dropper_picks(tag: String) -> void:
	var body := _body_named(DROPPER_NAME)
	if body == null:
		print("[%s] RECLAIM-CHECK ok=false reason=no-body-named-%s" % [tag, DROPPER_NAME])
		_check("%s: the returning player's body exists at all" % tag, false)
		return
	var want_person := CharacterRoster.index_of(StringName(_expect_character))
	var got_person := body.character_index
	var person_ok := got_person == want_person
	print("[%s] RECLAIM-CHECK char=%d/%s expect=%d/%s ok=%s" % [
		tag, got_person, _roster_name(got_person),
		want_person, _roster_name(want_person), str(person_ok)])
	print("[%s] %s" % [tag, _pick_line(body)])
	_check("%s: the returning player is on their OWN fighter (%s), not %s" % [
		tag, _roster_name(want_person), _roster_name(got_person)], person_ok)

	# ⚠️ THE MODEL IS ASSERTED SEPARATELY FROM THE INDEX, AND THAT IS THE POINT. They are
	# written by different code on different triggers, so a run in which the index is right
	# and the mesh is the bot's would otherwise report a clean PASS while the player is
	# still looking at the wrong person.
	var visual: Node = body.get_node_or_null("Visual")
	var want_entry := CharacterRoster.at(want_person)
	if visual != null and want_entry.has("model"):
		var model := String(visual.get("_current_key"))
		var material := String(visual.get("_current_material_key"))
		_check("%s: ...and the MODEL on screen is that fighter's" % tag,
			model == String(want_entry["model"]))
		_check("%s: ...and so is the palette" % tag,
			material == String(want_entry["material"]))

	# ⚠️ THE PROP PICKS RIDE THE SAME `picks_for()` DICTIONARY as the character, one packet
	# and one host-side table, so they are checked here rather than in a run of their own.
	# Skipped — reported, not failed — on a peer that has not been sent the table; see
	# `_seat_props()`.
	var props := _seat_props(body.player_slot)
	if props.is_empty():
		print("[%s] RECLAIM-PROPS <none on this peer>" % tag)
		return
	var want_can := CharacterRoster.index_in(CharacterRoster.CANS, StringName(_expect_can))
	var want_slipper := CharacterRoster.index_in(
		CharacterRoster.SLIPPERS, StringName(_expect_slipper))
	var got_can := int(props.get("can", -1))
	var got_slipper := int(props.get("slipper", -1))
	print("[%s] RECLAIM-PROPS can=%d expect=%d slipper=%d expect=%d ok=%s" % [
		tag, got_can, want_can, got_slipper, want_slipper,
		str(got_can == want_can and got_slipper == want_slipper)])
	if want_can >= 0:
		_check("%s: the returning player's own LATA came back" % tag, got_can == want_can)
	if want_slipper >= 0:
		_check("%s: the returning player's own TSINELAS came back" % tag,
			got_slipper == want_slipper)

# =============================================================================
# ⚠️⚠️ § THE THREE VERBS, ASSERTED AS STATE. 🧑 2026-08-02: *"no throw, no getting
# pushed, no pickup"*.
#
# Every check below drives the REAL path rather than a convenient shortcut past it:
# the pickup is an `E` press on a body standing on its own slipper (so it goes out as
# `_rpc_request_grab` and comes back as `main.gd::_rpc_slipper_grabbed`), and the push
# is `RoundManager._apply_shove_to`, which is literally the body of the `_sync_shove`
# handler the host's broadcast lands in. A check that asserted "the harness could call
# `notify_holding`" would have passed on the broken build.
# =============================================================================

## The one body this process drives — authority here, and no AI attached. Same test
## `main.gd::_refresh_rig_ownership` uses to decide whose camera to switch on.
func _my_body() -> CharacterBase:
	for node in _bodies():
		var body := node as CharacterBase
		if body != null and body.is_multiplayer_authority() and body.ai_controller == null:
			return body
	return null

func _check_abilities(tag: String) -> void:
	var body: CharacterBase = _my_body()
	if body == null:
		_check("%s: there is a body to test at all" % tag, false)
		return
	var slot: int = body.player_slot

	# ⚠️ THE THREE FACTS EVERY HOST BROADCAST IS ADDRESSED THROUGH. `_sync_shove`,
	# `_sync_block` and `_sync_tag_penalty` all resolve their victim with
	# `RoundManager.player_at(slot)`, and `can_throw` needs the lata — so a peer missing
	# any of them silently drops the message on the floor with no error anywhere.
	_check("%s: RoundManager on this peer knows the body by its seat" % tag,
		RoundManager.player_at(slot) == body)
	_check("%s: this peer has the lata" % tag, RoundManager.lata != null)
	_check("%s: the round is live on this peer" % tag, RoundManager.round_active)

	if not body.is_defender:
		await _check_pickup_and_throw(tag, body)

	# ---- BEING PUSHED -------------------------------------------------------
	# ⚠️ LAST, because it stuns the body it tests and `can_act()` is false for the next
	# 0.6 s — running it before the pickup would have failed the pickup for the wrong
	# reason.
	# ⚠️ READ ON THE SAME LINE, WITH NO `await` AND NO POSITION FALLBACK, AND THE FIRST
	# VERSION OF THIS CHECK HAD BOTH. `_apply_shove()` writes `velocity` and `state`
	# synchronously, so anything measured after a physics frame is measuring gravity and
	# `move_and_slide()` as well — and "the body moved at all" is true of any body standing
	# on a slope or still settling. Measured: it reported PASS on the broken build, on a
	# peer whose seat table was empty and where the shove provably went nowhere.
	body.velocity = Vector3.ZERO
	body.state = CharacterBase.State.NORMAL
	RoundManager._apply_shove_to(slot, Vector3(7.0, 0.0, 0.0), 0.6)
	var pushed := body.velocity.length() > 0.5
	var stunned := body.state != CharacterBase.State.NORMAL
	print("[%s] PUSH velocity=%.2f state=%s" % [tag, body.velocity.length(), str(body.state)])
	_check("%s: a host shove reaches the body (it can be PUSHED)" % tag, pushed and stunned)

## ⚠️ ONE CHECK COVERS BOTH STARTING STATES, ON PURPOSE. The seat was bot-driven for the
## ~17 s the human was away, so their slipper is either still auto-equipped in the hand
## (`main.gd::_equip_owned_slippers` at round start) or lying wherever the bot threw it —
## and which one it is on any given run is the bot's business, not this run's. The end
## state is the same either way: *an attacker standing on their own slipper with `E` held
## is holding it*. Both branches were broken before the fix and both are proved by this.
func _check_pickup_and_throw(tag: String, body: CharacterBase) -> void:
	var mine: Slipper = _reachable_slipper(body)
	if mine == null:
		_check("%s: this peer can see a slipper to pick up at all" % tag, false)
		return
	# ⚠️ WHICH slipper this landed on is PRINTED, NOT ASSERTED, and the distinction matters.
	# `_reachable_slipper()` falls back to ANY loose slipper on purpose (see its own doc:
	# ownership is not what a pickup is gated on), so a PASS below is a PASS for the game's
	# real rule — but it does not by itself say the returning player got THEIR seat's
	# slipper back. Printing the choice keeps a run that passed via the fallback readable
	# against one that did not, without asserting a rule the game does not have.
	# ⚠️ THE BUTTON STATES ARE PRINTED WITH THE TARGET, because `special_ability` and `grab`
	# SHARE MOUSE BUTTON 1 in `project.godot` (`grab` is E or MB1; `special_ability` is Q or
	# MB1). Two actions on one physical button is a real binding a player uses, and a harness
	# that pressed one and assumed nothing about the other would misread a charge it started
	# itself as a defect in the build.
	print(("[%s] TARGET slipper=%s owner=%d mine=%s state=%d in_hand=%s dist=%.2f "
		+ "held_ability=%s held_grab=%s charging=%s") % [
		tag, mine.name, mine.owner_slot, str(mine.owner_slot == body.player_slot),
		int(mine.state), str(mine.carrier == body),
		body.global_position.distance_to(mine.global_position),
		str(Input.is_action_pressed("special_ability")),
		str(Input.is_action_pressed("grab")),
		str(body.get_node("Carrier").call("is_charging"))])
	# ⚠️ TELEPORTED, NOT WALKED. This process is the multiplayer authority for this body,
	# so writing `global_position` is a legal move that the synchronizer carries to the
	# host within a frame or two — which is what makes the host agree the player is in
	# range when the grab request arrives. Walking it there would need a pathfinder and
	# would still be a teleport's worth of trust in the same synchronizer.
	# ⚠️⚠️ THE `E` PRESS IS SKIPPED WHEN THE HAND IS ALREADY FULL, AND THAT IS NOT A
	# SHORTCUT — IT IS REMOVING ONE. `Carrier._step_grab()` returns on its FIRST line while
	# `_held != null`, so an E press with a slipper already in hand cannot possibly prove
	# anything about pickup. What it does instead is fall through to `character_base.gd`'s
	# `_step_shove` — E is the shove button too, and this check holds it for 1.5 s, which is
	# a full shove charge and release. Measured 2026-08-04, a latecomer that arrived already
	# holding its slipper: `shove_cd=0.23` before the check had pressed anything, and the
	# tsinelas left the hand mid-check, so the pickup, the gate and the throw all reported
	# FAIL on a build where all three were fine. A harness must not fight the body it is
	# about to measure.
	#
	# The assertion below is unchanged and still covers both starting states, exactly as this
	# function's header says: what is being claimed is the END state — an attacker standing
	# on a slipper ends up holding it — not that a particular button was pushed.
	if mine.carrier != body:
		body.global_position = mine.global_position
		await get_tree().create_timer(1.0).timeout
		# `Carrier._step_grab` reads `input_just_pressed`, so the press must be genuinely
		# NEW — released first, then held across several physics frames while the request
		# makes its round trip to the host and back.
		_press("grab", false)
		await get_tree().physics_frame
		_press("grab", true)
		await get_tree().create_timer(1.5).timeout
		_press("grab", false)
		await get_tree().create_timer(1.0).timeout
	_check("%s: a slipper is in this peer's hand after pressing E on one (PICKUP)" % tag,
		body.holding_slipper())
	var carrier: Node = body.get_node_or_null("Carrier")
	_check("%s: and the Carrier component agrees it is holding one" % tag,
		carrier != null and carrier.call("held") != null)

	# ---- THROW --------------------------------------------------------------
	# ⚠️ STOOD OUTSIDE THE CHALK FIRST, AND DERIVED FROM `confinement_radius` RATHER THAN
	# FROM `spawn_position`. `RoundManager.can_throw()` refuses a thrower inside the box
	# (`Design.md`: the throwing line) and the pickup above walks the body to wherever the
	# slipper happens to be lying, so the position has to be re-established either way.
	#
	# The first version used `spawn_position`, which is right for a REJOINER — its seat was
	# placed on an attacker mark by `_reset_world` at the whistle — and wrong for a
	# first-time mid-match joiner, whose `spawn_position` is whatever the spawn packet said
	# and has never been through `_place_at_spawn`. Measured on the latecomer scenario:
	# `inside_box=true` at the throw check, i.e. the run failed on where the HOST had put
	# them rather than on anything about the gate. `confinement_radius` is the same number
	# `is_inside_box()` tests against, so stepping past it cannot disagree with the rule.
	# ⚠️ READ OFF THE CLASS, NOT OFF THE INSTANCE. Both are `static var` on `CharacterBase`
	# (the box and the arena bounds are properties of the MAP, one copy for everybody), and
	# GDScript will not serve a static through an instance.
	var clear_of_box: float = CharacterBase.confinement_radius + 1.5
	if CharacterBase.playable_half_x > 0.0:
		clear_of_box = minf(clear_of_box, CharacterBase.playable_half_x - 0.5)
	body.global_position = Vector3(clear_of_box, body.global_position.y, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# ⚠️⚠️ THE GATE IS ASSERTED WITH `lata.is_upright` FACTORED OUT, AND THE FIRST VERSION
	# OF THIS CHECK WAS VACUOUS WITHOUT THAT. `RoundManager.can_throw()` is six clauses, and
	# ONE of them — the can standing — is a live game condition the AI taya's own attackers
	# knock over within seconds of the whistle. Measured across three runs: `lata_up` was
	# false at this point in all three, so `can_throw == (lata_up and off_cooldown)` reduced
	# to `false == false` and would have gone green on any build at all.
	#
	# The five remaining clauses are precisely the ones a rejoin can break, and each of them
	# was broken on the build this run was written against: `round_active` and the lata come
	# from `_sync_state_to_late_joiner`, `holding` from the slipper catch-up, and the seat
	# table under both. So they are asserted directly, and the can's posture is printed
	# rather than demanded.
	# ⚠️⚠️ WAIT OUT THE THROW COOLDOWN, WHICH THIS CHECK STARTS ITSELF. The pickup asserted a
	# few lines above is a real `E` press, and equipping a slipper arms the throw cooldown —
	# so asserting `throw_cooldown_left() <= 0.0` immediately afterwards is asserting a normal
	# game rule against a state this function created. Measured on a HEALTHY build:
	#
	#     THROW GATE lata_up=true inside_box=false holding=true defender=false
	#                round_active=true  throw_cd=0.62  can_throw=false
	#
	# Every clause a rejoin can break was already satisfied; only the cooldown was open, and
	# the run reported FAIL on a correct fix. Poll rather than sleep a fixed time — the
	# cooldown length is a balance number and this must not re-break when it changes.
	var cooldown_deadline := Time.get_ticks_msec() + 4000
	while RoundManager.throw_cooldown_left() > 0.0 and Time.get_ticks_msec() < cooldown_deadline:
		await get_tree().physics_frame
	var lata: Node = RoundManager.lata
	var lata_up: bool = lata != null and bool(lata.get("is_upright"))
	# ⚠️ THE WHOLE FORMAT STRING IS PARENTHESISED. `%` binds tighter than `+` in GDScript,
	# so `"a" + "b" % args` formats only the second half and throws on the argument count.
	print(("[%s] THROW GATE lata_up=%s throw_cd=%.2f inside_box=%s holding=%s defender=%s "
		+ "round_active=%s can_throw=%s") % [
		tag, str(lata_up), RoundManager.throw_cooldown_left(),
		str(body.is_inside_box()), str(body.holding_slipper()), str(body.is_defender),
		str(RoundManager.round_active), str(RoundManager.can_throw(body))])
	_check("%s: every clause of the throw gate a rejoin can break is satisfied (THROW)" % tag,
		RoundManager.round_active
			and not body.is_defender
			and body.holding_slipper()
			and lata != null
			and RoundManager.throw_cooldown_left() <= 0.0
			and not body.is_inside_box())
	# And the whole gate, which is the five above plus the can. Stated separately so a run
	# that fails only because somebody knocked the lata over says so in one line.
	_check("%s: ...so the gate is open iff the can is standing" % tag,
		RoundManager.can_throw(body) == lata_up)
	# ⚠️ AND THEN THE THROW ITSELF, WHICH IS A COMPLETELY DIFFERENT QUESTION — see
	# `_drive_throw`'s own header for why everything above this line is only PERMISSION.
	await _drive_throw(tag, body)

# =============================================================================
# ⚠️⚠️ § THE RELEASE. 🧑 2026-08-04, after the permission gate was fixed: *"still cant
# throw on rejoin.. i have the throw animation and chargup now but it doesnt actually
# throw."*
#
# EVERYTHING ABOVE THIS BLOCK ASSERTS `RoundManager.can_throw()`, WHICH IS PERMISSION AND
# NOTHING ELSE. That is precisely how this defect reached a player: the gate is the LAST
# thing `Carrier._step_throw()` checks before it calls `_request_throw()`, so a build in
# which the request goes out and the host silently refuses it satisfies every assertion in
# § THE THREE VERBS while the tsinelas never leaves the hand. The old check passed on a
# build where throwing was completely broken.
#
# So a throw is asserted here as a STATE TRANSITION on the PROP, not as a permission on the
# player:
#
#   · the slipper leaves the hand — `state` CARRIED -> anything else, `carrier` -> null,
#     and the thrower's own `holding_slipper()` goes false;
#   · it TRAVELS — `global_position` ends up metres from the thrower a second later, which
#     is what separates a throw from a drop;
#   · and the HOST agrees, which is `_watch_throws()` on the referee process. That is not
#     a courtesy third opinion: `_apply_thrown` only ever runs off `_rpc_slipper_thrown`,
#     an `@rpc("authority")` the host alone may send, so a client that sees its own slipper
#     go FLYING has already been told so by the host — but a run that measured only the
#     client could not tell that apart from a client-side simulation, and the referee's
#     line is what closes it.
#
# ⚠️ DRIVEN THROUGH THE REAL INPUT PATH, NOT BY CALLING `host_throw()` OR `_request_throw()`.
# The whole fault lives between "the player let go of the button" and "the host moved the
# prop"; a harness that called either end directly would step over the part that is broken
# and report green.
#
# ⚠️ THE GATE IS WAITED FOR RATHER THAN DEMANDED, AND THAT IS THE `lata_up` LESSON ABOVE
# APPLIED TO A DRIVE INSTEAD OF AN ASSERTION. `can_throw()` needs the can STANDING, and the
# AI taya's own attackers knock it over within seconds of the whistle — measured false at
# this point in all three runs the gate check was written against. So this polls for a legal
# moment instead of assuming one, and reports honestly if the round never offers one.
# =============================================================================

## How long to hold `special_ability` before letting go. Well short of
## `Carrier.CHARGE_FULL_TIME` (2.5 s) on purpose — this is testing the RELEASE, and a
## partial charge still throws (`Carrier.CHARGE_MIN_POWER`), so there is nothing to gain
## from making the run 2.5 s longer per throw.
const CHARGE_HOLD: float = 0.8
## How long to wait for the state transition after the release. A client's request has to
## reach the host, be validated, and come back as `_rpc_slipper_thrown` — one round trip on
## loopback, with a wide margin.
const RELEASE_GRACE_MS: int = 2500
## How far the slipper must end up from the thrower for this to be a THROW rather than a
## drop at the feet. `Slipper.LAUNCH_SPEED` 18.5 at the minimum 0.35 power still clears
## several metres; 1.5 m is far enough that nothing but a real launch reaches it and near
## enough that a throw straight into the ground still counts.
const THROW_TRAVEL_MIN: float = 1.5
## How many times to press before calling the charge broken. Three because the two things
## that eat a press — the taya's can being down, and `input_parked` during the ready
## countdown — both clear on their own within a second or two.
const CHARGE_ATTEMPTS: int = 3

## Everything that has to be true for a press to be able to START a charge, which is strictly
## more than `can_throw()`. `Carrier._step_throw()` reads the button through
## `CharacterBase.input_pressed()`, which returns false outright while `input_parked` is set
## (the ready countdown, the pause menu), and `_step_throw` itself refuses while the throw lock
## is up. Waiting on `can_throw()` alone is what let the run press into a body that could not
## hear it and report `charged=false power=0.00` on a healthy build.
func _throw_moment_is_legal(body: CharacterBase) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	return RoundManager.can_throw(body) and body.can_act() and not body.input_parked

func _drive_throw(tag: String, body: CharacterBase) -> void:
	var carrier: Node = body.get_node_or_null("Carrier")
	if carrier == null:
		_check("%s: the body has a Carrier to throw with" % tag, false)
		return
	var slipper := carrier.call("held") as Slipper
	if slipper == null:
		print("[%s] THROW-CHECK ok=false reason=nothing-in-hand" % tag)
		_check("%s: there is a slipper in the hand to throw (THROW)" % tag, false)
		return
	print("[%s] THROW-BEFORE slipper=%s state=%d carrier=%s path=%s" % [
		tag, slipper.name, int(slipper.state),
		String(slipper.carrier.name) if slipper.carrier != null else "<null>",
		String(slipper.get_path())])

	# ---- WAIT FOR A LEGAL MOMENT --------------------------------------------
	# Re-placed outside the chalk on every pass: the wait can be long, and a shove or a
	# tag can put the body back inside the box while it runs.
	var clear_of_box: float = CharacterBase.confinement_radius + 1.5
	if CharacterBase.playable_half_x > 0.0:
		clear_of_box = minf(clear_of_box, CharacterBase.playable_half_x - 0.5)
	var gate_deadline := Time.get_ticks_msec() + 30000
	while not _throw_moment_is_legal(body) and Time.get_ticks_msec() < gate_deadline:
		if body.state == CharacterBase.State.NORMAL:
			body.global_position = Vector3(clear_of_box, body.global_position.y, 0.0)
		await get_tree().physics_frame
	if not RoundManager.can_throw(body):
		# ⚠️ REPORTED AS ITS OWN FAILURE RATHER THAN FOLDED INTO THE THROW. "the round never
		# offered a legal moment" and "the release does not work" are different findings and
		# a run that cannot tell them apart is not worth having.
		print(("[%s] THROW-CHECK ok=false reason=gate-never-opened lata_up=%s throw_cd=%.2f "
			+ "holding=%s inside_box=%s") % [
			tag, str(RoundManager.lata != null and bool(RoundManager.lata.get("is_upright"))),
			RoundManager.throw_cooldown_left(), str(body.holding_slipper()),
			str(body.is_inside_box())])
		_check("%s: the round offered a legal throwing moment within 30 s" % tag, false)
		return

	# ---- THE PRESS AND THE RELEASE -------------------------------------------
	var from := body.global_position
	var charged := false
	var charge_power := 0.0
	# ⚠️⚠️ THE PRESS IS RETRIED, AND THAT IS THE KNOWN FLAKE IN THIS HARNESS RATHER THAN A
	# DEFECT IN THE GAME. The pre-drop control intermittently reported
	# `charged=false power=0.00` — the run pressing at a moment the body could not accept.
	# `Carrier._step_throw()` refuses to START a charge unless `can_throw()` holds AND
	# `_throw_lock_left` is clear, and it CANCELS one mid-hold the instant `can_throw()` stops
	# holding — and the can is knocked over by the AI attackers several times a round, so a
	# 0.8 s hold that begins one frame before that is lost through no fault of the build.
	# `CharacterBase.input_pressed()` is deaf while `input_parked` is set as well, which is
	# true through the ready countdown the run presses into.
	#
	# This is the treatment § THE RELEASE already gives the GATE — *"polls for a legal moment
	# instead of assuming one, and reports honestly if the round never offers one"* — applied
	# to the press itself: re-wait the gate, press again, and only report failure once the
	# round has genuinely refused three separate attempts. The assertion below is unchanged, so
	# a build where the charge really is broken still fails; it just no longer fails on a build
	# where the taya's can happened to be lying down for a second.
	for attempt in range(CHARGE_ATTEMPTS):
		# Re-wait rather than assume: an earlier attempt may have spent seconds discovering
		# the can was down, and the position has to be re-established each pass for the same
		# reason the gate wait re-establishes it.
		var retry_deadline := Time.get_ticks_msec() + 10000
		while not _throw_moment_is_legal(body) and Time.get_ticks_msec() < retry_deadline:
			if body.state == CharacterBase.State.NORMAL:
				body.global_position = Vector3(clear_of_box, body.global_position.y, 0.0)
			await get_tree().physics_frame
		from = body.global_position
		# Released first so the press is genuinely NEW — `_step_throw` starts a charge off
		# `input_pressed`, but a button this process left down from an earlier check would make
		# the charge start at an unknown time.
		_press("special_ability", false)
		await get_tree().physics_frame
		_press("special_ability", true)
		await get_tree().create_timer(CHARGE_HOLD).timeout
		charged = bool(carrier.call("is_charging"))
		charge_power = float(carrier.call("charge_power"))
		if charged:
			break
		# ⚠️ RELEASED BEFORE LOOPING. A button left down is exactly the "charge started at an
		# unknown time" trap the line above guards against, and `special_ability` shares MOUSE
		# BUTTON 1 with `grab` — leaving it held would also be pressing somebody else's verb.
		_press("special_ability", false)
		print("[%s] THROW-RETRY attempt=%d charged=false can_throw=%s parked=%s state=%s cd=%.2f" % [
			tag, attempt + 1, str(RoundManager.can_throw(body)), str(body.input_parked),
			str(body.state), RoundManager.throw_cooldown_left()])
		await get_tree().create_timer(0.5).timeout
		# The hand can be emptied by a shove or a tag while this waits, and charging with
		# nothing in it is not the thing under test.
		if carrier.call("held") == null:
			break
	_press("special_ability", false)
	# ⚠️ THE CHARGE IS ASSERTED SEPARATELY FROM THE RELEASE, because the player's report
	# distinguishes them: *"i have the throw animation and chargup now but it doesnt
	# actually throw"*. A run in which the charge never started is a DIFFERENT bug from
	# the one under test and must not be reported as this one.
	_check("%s: the charge-up ran on a real button hold" % tag, charged)

	# ---- THE TRANSITION ------------------------------------------------------
	var left_hand := false
	var deadline := Time.get_ticks_msec() + RELEASE_GRACE_MS
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if slipper.state != Slipper.CarryState.CARRIED and slipper.carrier == null:
			left_hand = true
			break
	# A second of flight, so "it moved" is travel and not the launch frame's own step.
	await get_tree().create_timer(1.0).timeout
	var travelled := slipper.global_position.distance_to(from)
	var still_held: bool = body.holding_slipper()
	var carrier_held: bool = carrier.call("held") != null
	# ⚠️ ONE MACHINE-READABLE LINE, so `run_rejoin.ps1` can require it to be PRESENT rather
	# than merely require the absence of a FAIL — the same rule § THE RECLAIM WATCH states.
	print(("[%s] THROW-CHECK ok=%s charged=%s power=%.2f state=%d carrier=%s "
		+ "travelled=%.2f holding=%s carrier_held=%s") % [
		tag, str(left_hand and travelled >= THROW_TRAVEL_MIN and not still_held),
		str(charged), charge_power, int(slipper.state),
		String(slipper.carrier.name) if slipper.carrier != null else "<null>",
		travelled, str(still_held), str(carrier_held)])
	_check("%s: the tsinelas actually LEFT THE HAND on release (THROW)" % tag, left_hand)
	_check("%s: ...and the thrower's hand is empty afterwards" % tag,
		not still_held and not carrier_held)
	_check("%s: ...and it TRAVELLED away from the thrower (%.2f m >= %.2f)" % [
		tag, travelled, THROW_TRAVEL_MIN], travelled >= THROW_TRAVEL_MIN)

## The slipper this body should be able to end up holding: the one already in its hand,
## else its own if that is lying loose, else ANY loose one.
##
## ⚠️⚠️ THE LAST FALLBACK IS NOT LAZINESS, IT IS THE GAME'S ACTUAL RULE. This function
## used to demand `owner_slot == player_slot` and went red on a healthy build. Ownership
## is not fixed for the round: `Slipper._apply_grabbed()` writes `owner_slot = slot` on
## every pickup, so whoever picks a slipper up OWNS it from then on. Measured on the run
## that caught this — after ~17 s of bots fetching and throwing, the host itself held
## `s0(owner=2) s1(owner=3) s2(owner=3)` and NO slipper belonged to the returning seat at
## all, on the host and on both clients alike. `Slipper.can_be_grabbed_by()` has never
## consulted ownership, so "your own slipper" was never what a pickup was gated on.
func _reachable_slipper(body: CharacterBase) -> Slipper:
	var scene: Node = get_tree().current_scene
	var list: Variant = scene.get("slippers") if scene != null else null
	if not (list is Array):
		return null
	var own_loose: Slipper = null
	var any_loose: Slipper = null
	for entry in (list as Array):
		var slipper := entry as Slipper
		if slipper == null or not is_instance_valid(slipper):
			continue
		if slipper.carrier == body:
			return slipper
		if not slipper.is_loose():
			continue
		if any_loose == null:
			any_loose = slipper
		if slipper.owner_slot == body.player_slot:
			own_loose = slipper
	return own_loose if own_loose != null else any_loose

## ⚠️ `InputEventAction`, THE SAME WAY `_press_ready_up` DOES IT. `Input.action_press()`
## would also work for the pressed half but leaves the action stuck down for the rest of
## the process; parsing a real event keeps press and release symmetric.
func _press(action: String, down: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = down
	Input.parse_input_event(event)

## What the 2D layer is saying — the one thing that stays visible on a grey screen, so it
## is the one thing a player could still read while reporting the bug.
func _hud_text(scene: Node) -> String:
	if scene == null:
		return ""
	var hud: Node = scene.get_node_or_null("HUDLayer/HUD")
	if hud == null:
		hud = _first_named(scene, "HUD")
	if hud == null:
		return "<no hud>"
	var label: Node = hud.get_node_or_null("%RoundLabel")
	if label == null:
		return "<no round label>"
	return String(label.get("text"))

func _first_named(from: Node, needle: String) -> Node:
	if String(from.name) == needle:
		return from
	for child in from.get_children():
		var hit := _first_named(child, needle)
		if hit != null:
			return hit
	return null

## ⚠️ WALKED FROM `/root`, NOT FROM `current_scene`. During a scene change the match scene
## is briefly still parented while `current_scene` already points elsewhere, and counting
## from the wrong root is how a run reports zero bodies in a perfectly healthy match.
func _bodies() -> Array[Node]:
	var out: Array[Node] = []
	_collect(get_tree().root, "CharacterBody3D", out)
	return out

func _bodies_line(from: Node) -> String:
	var out: Array[Node] = []
	_collect(from, "CharacterBody3D", out)
	var parts: Array[String] = []
	for body in out:
		parts.append("%s(slot=%s auth=%d bot=%s)" % [
			body.name, str(body.get("player_slot")), body.get_multiplayer_authority(),
			str(body.get("is_bot"))])
	return " ".join(parts)

func _collect(from: Node, type_name: String, out: Array[Node]) -> void:
	if from == null:
		return
	if from.is_class(type_name):
		out.append(from)
	for child in from.get_children():
		_collect(child, type_name, out)

# =============================================================================
# Plumbing
# =============================================================================

## The server browser, hosted BESIDE this node rather than above it. `_begin_join` calls
## `change_scene_to_file`, which frees `current_scene` — a harness parented above the screen
## deletes itself the moment the first press works.
func _open_setup() -> Node:
	var screen: Node = load(MULTIPLAYER_SETUP).instantiate()
	get_tree().root.add_child.call_deferred(screen) # root is still setting THIS node up
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = screen
	await get_tree().create_timer(1.0).timeout
	return screen

## ⚠️ THE IN-MATCH READY GATE IS A SECOND, SEPARATE PRESS from the lobby's READY, and the
## round does not start without it — `main.gd::_enter_net_ready_phase` waits for one
## `ready_up` per playing peer. Sent as a real input event rather than by reaching for the
## RPC, because the client's half of that gate IS the keypress.
func _press_ready_up() -> void:
	var press := InputEventAction.new()
	press.action = "ready_up"
	press.pressed = true
	Input.parse_input_event(press)

func _scene_name() -> String:
	var scene: Node = get_tree().current_scene
	return String(scene.name) if scene != null else "<null>"

func _done(tag: String) -> void:
	print("[%s] RESULT %s" % [tag, "PASS" if _fail == 0 else "FAIL (%d)" % _fail])
	get_tree().quit(_fail)

func _check(what: String, ok: bool) -> void:
	if not ok:
		_fail += 1
	print("[%s] %s  %s" % [_role, "PASS" if ok else "FAIL", what])
