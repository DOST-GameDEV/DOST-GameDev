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
	match _role:
		"referee": await _referee()
		"anchor": await _anchor()
		"latecomer": await _latecomer()
		_: await _dropper()

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
	await get_tree().create_timer(7.0).timeout
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
	return {
		"scene": _scene_name(),
		"bodies": bodies.size(),
		"owned": owned,
		"owned_slot": owned_slot,
		"owned_is_bot": owned_is_bot,
		"camera": camera,
	}

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
