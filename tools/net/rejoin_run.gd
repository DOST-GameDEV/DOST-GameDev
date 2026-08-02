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
var _live: float = 75.0
## How many OTHER humans the anchor waits for before it presses START MATCH. 1 for the
## rejoin scenario (the dropper must be seated and playing before it can drop out of
## anything); 0 for the latecomer scenario, where the whole point is that the match is
## already running when the second client first arrives.
var _wait_for: int = 1

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
	# A distinguishable name per role, so a body in the report can be read back to the
	# process that owns it without counting peer ids.
	SettingsManager.player_name = _role.to_upper()
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
		_: await _dropper()

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
		_host_report(int(elapsed))
	_done("referee")

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
		await get_tree().create_timer(5.0).timeout
		elapsed += 5.0
		_report("anchor t=%ds" % int(elapsed))
		# ⚠️ THE CONTROL, MEASURED AT ROUGHLY THE MOMENT THE DROPPER COMES BACK. The
		# anchor never left, so its body is a normally-spawned one in the SAME match on
		# the SAME build — which is the only honest thing to diff a reclaimed body
		# against. 20 s lines up with the dropper's AFTER (it spends ~14 s reconnecting
		# after a ~7 s pre-round settle), and one shot rather than every tick because the
		# push probe deliberately staggers the body it tests.
		if int(elapsed) == 10:
			await _check_abilities("CONTROL")
	_done("anchor")

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
		if RoundManager.round_active and RoundManager.player_at(1) != null:
			break
	print("[dropper] round=%d active=%s" % [MatchManager.round_number, str(RoundManager.round_active)])

	# ---- BEFORE ----------------------------------------------------------------
	var before := _report("dropper BEFORE")
	_check("BEFORE: the dropper owns a body", before["owned"] != "")
	_check("BEFORE: the dropper is looking through a camera", before["camera"] != "<none>")

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
	await _check_abilities("AFTER")
	_done("dropper")

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
	# playing. Generous: it is the same 9 s scene-load budget plus the lobby dance.
	await get_tree().create_timer(30.0).timeout
	var screen: Node = await _open_setup()
	screen.call("_begin_join", _address())
	await get_tree().create_timer(14.0).timeout
	var after := _report("latecomer")
	_check("a mid-match newcomer lands in the match scene", String(after["scene"]) == "Main")
	_check("with a populated world", int(after["bodies"]) == 4)
	_check("owning a body", String(after["owned"]) != "")
	_check("and a camera to look through", String(after["camera"]) != "<none>")
	# ⚠️ THE SAME THREE VERBS, BECAUSE IT IS THE SAME DEFECT. `RoundManager.register_player`
	# ran only at a round boundary and the slipper carry state was never sent to anybody who
	# missed the pickup — neither of those cares whether the arriving peer has been in this
	# match before. A first-time mid-match joiner was as unable to throw, pick up or be
	# shoved as a returning one, and is proved fixed by the same probe.
	await _check_abilities("LATECOMER")
	_done("latecomer")

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
			slips.append("s%d(owner=%s state=%s carrier=%s)" % [
				i, str(slipper.get("owner_slot")), str(slipper.get("state")),
				String(holder.name) if holder != null else "<null>"])
	var lata: Node = RoundManager.lata
	return ("WORLD round=%d round_active=%s lata=%s lata_up=%s throw_cd=%.2f time_left=%.1f "
		+ "defender_slot=%d rm_seats=[%s] %s") % [
		MatchManager.round_number, str(RoundManager.round_active), str(lata != null),
		str(lata != null and bool(lata.get("is_upright"))),
		RoundManager.throw_cooldown_left(),
		RoundManager.time_left, MatchManager.defender_slot,
		", ".join(seats), " ".join(slips)]

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
	# ⚠️ TELEPORTED, NOT WALKED. This process is the multiplayer authority for this body,
	# so writing `global_position` is a legal move that the synchronizer carries to the
	# host within a frame or two — which is what makes the host agree the player is in
	# range when the grab request arrives. Walking it there would need a pathfinder and
	# would still be a teleport's worth of trust in the same synchronizer.
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
