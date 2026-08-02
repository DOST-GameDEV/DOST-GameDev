extends Node
## DOES A DEDICATED LOBBY COME BACK? — the half `dedicated_match_run.gd` stops just short of.
##
## 🧑 2026-08-02, measured on the live VM: a pool server whose match had been abandoned
## answered `players=0, occupied=0, in_progress=true` with **nobody connected at all**,
## indefinitely. `multiplayer_setup.gd::_free_pool_address()` only claims a row whose
## `in_progress` is false, so that lobby was permanently unhostable and — the deployment
## running a single lobby — HOST ONLINE was dead for everybody until an operator restarted
## the service. A real player hit it.
##
## `dedicated_match_run.gd` proves a match STARTS through a pool server. This proves the
## server is still usable AFTERWARDS, which is the property the pool actually lives or dies
## on. Three roles, one script, driven by `run_dedicated_recycle.ps1`:
##
##   --role=play    claims the lobby, readies, presses START MATCH, checks a match really is
##                  running, prints the mid-match status reply, then QUITS. Process exit is
##                  the player walking out mid-match — the exact abandonment measured live.
##   --role=watch   asks the lobby for its status once a second for a while and prints every
##                  reply. This is the BEFORE measurement: `in_progress` stays true with
##                  `occupied=0` for as long as you care to look.
##   --role=claim   the AFTER measurement, and the one that matters: the status must have
##                  gone back to `in_progress=false, occupied=0`, and a SECOND client must
##                  then be able to press HOST ONLINE, claim this same lobby and lead it.
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/net/dedicated_recycle_run.tscn -- \
##         --pool=127.0.0.1 --role=claim --port=8971
##
## ⚠️ THE POOL PORTS ARE OVERRIDDEN IN CODE, NOT ON THE COMMAND LINE. `--pool=` moves the
## ADDRESS only; the ports are `ServerQuery.POOL_PORT_FIRST..LAST` (8910-8917) and this run
## deliberately works outside that range so it cannot collide with anybody else's lobbies on
## this machine. `pool_ports` is a plain `var` for exactly this — see § WHAT IS ACTUALLY
## QUERIED in `server_query.gd` — and writing it here is what makes HOST ONLINE, which is a
## real player's path and not a typed address, reach a server on 8971 at all.
##
## ⚠️ THE HARNESS STAYS OUT OF THE SCENE IT DRIVES, exactly as `dedicated_match_run.gd`
## documents: `change_scene_to_file` frees `current_scene`, and this run changes scene twice.

const SCREEN: String = "res://scenes/ui/MultiplayerSetup.tscn"

## The band this work owns. Wide enough that the ⚠️ above stays true if the port moves.
const PORT_FIRST: int = 8970
const PORT_LAST: int = 8979

var _role: String = "play"
var _port: int = 8971
var _fail: int = 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.substr(len("--role="))
		elif a.begins_with("--port="):
			_port = int(a.substr(len("--port=")))
	var ports: Array[int] = []
	for p in range(PORT_FIRST, PORT_LAST + 1):
		ports.append(p)
	ServerQuery.pool_ports = ports
	match _role:
		"watch": await _watch()
		"claim": await _claim()
		"endure": await _endure()
		"referee": await _referee()
		"stay": await _stay()
		_: await _play()

# =============================================================================
# ⚠️⚠️ THE NATURAL-END TRIGGER, WATCHED FROM INSIDE THE REFEREE.
#
# `--role=endure` proves it the honest way — a real client sits through a real match — and
# it costs eleven minutes, because `RoundManager.ROUND_TIME` is 90 s and a round only ever
# ends on the clock (`_on_time_up` is the single caller of `report_round_result`). That is
# too long to be run often, and on this machine it is regularly cut short by other work
# killing every Godot process on the box.
#
# So this role BECOMES the dedicated server. It hosts `MatchSetup.tscn` with the real
# `--dedicated --port=` arguments, a real client claims it and starts a real match through
# the real lobby, and then the referee winds its OWN round clock down instead of waiting
# for it. Nothing about the end-of-match path is faked: `RoundManager._on_time_up` still
# runs, `MatchManager.report_round_result` still decides, `_finish_match` still fires
# `match_won`, and `main.gd` arms and expires its grace window exactly as it would after a
# match played at full length.
#
# ⚠️ AND IT ASSERTS ON THE SERVER'S OWN STATE, NOT ON A STATUS PACKET, which is the whole
# reason this role is worth having as well as `endure`. Only from in here can the run check
# that the ENet listener and the `ServerQuery` responder are STILL OPEN afterwards — the
# property that makes this a return to the waiting room rather than a restart, and the one
# thing a client on the far side of the wire cannot see.
# =============================================================================

func _referee() -> void:
	var screen: Node = load("res://scenes/ui/MatchSetup.tscn").instantiate()
	get_tree().root.add_child.call_deferred(screen)
	await get_tree().process_frame
	get_tree().current_scene = screen
	await get_tree().create_timer(1.0).timeout
	_check("the referee is hosting", NetworkManager.is_host())
	_check("and knows it is one", NetworkManager.is_dedicated)
	_check("its status socket is open", ServerQuery.is_responding())
	var code_before: String = NetworkManager.join_code
	print("[referee] code_before=%s" % code_before)

	# The `stay` client claims the lobby and presses START. Generous: it has to browse,
	# settle, ready up and load the match scene.
	var waited := 0.0
	while waited < 45.0 and MatchManager.round_number < 1:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	print("[referee] scene=%s round=%d in_progress=%s" % [
		_scene_name(), MatchManager.round_number,
		str(NetworkManager.match_in_progress)])
	_check("a real match started through the real lobby", MatchManager.round_number >= 1)
	_check("and the pool is told so", NetworkManager.match_in_progress)

	# ⚠️ WINDING THE CLOCK, NOT SKIPPING THE END. Every round still ends through
	# `_on_time_up`; this only refuses to spend 90 s of wall clock finding out. Read off
	# `main.gd` BEFORE the wind-down, because the constant is only reachable while
	# `Main.tscn` is still the current scene.
	var grace: float = _post_match_seconds() + 25.0
	var spun := 0.0
	while spun < 90.0:
		if MatchManager.round_number >= MatchManager.ROUNDS and not RoundManager.round_active:
			break
		if RoundManager.round_active:
			RoundManager.time_left = 0.02
		await get_tree().create_timer(0.1).timeout
		spun += 0.1
	print("[referee] after the last whistle: scene=%s round=%d" % [
		_scene_name(), MatchManager.round_number])
	_check("all four rounds were played out", MatchManager.round_number >= MatchManager.ROUNDS)

	print("[referee] waiting up to %.0fs for the post-match window" % grace)
	var slept := 0.0
	while slept < grace and _scene_name() != "MatchSetup":
		await get_tree().create_timer(1.0).timeout
		slept += 1.0
	print("[referee] t+%.0fs scene=%s" % [slept, _scene_name()])

	_check("the referee went back to its waiting room", _scene_name() == "MatchSetup")
	_check("and stopped advertising a match", not NetworkManager.match_in_progress)
	_check("the room is empty", NetworkManager.connected_peer_ids.is_empty())
	_check("nobody is left holding the lobby", NetworkManager.lobby_leader_id == 0)
	print("[referee] code_after=%s" % NetworkManager.join_code)
	_check("it minted a fresh join code", not NetworkManager.join_code.is_empty()
		and NetworkManager.join_code != code_before)
	# ⚠️ THE TWO THAT MAKE THIS A RETURN AND NOT A RESTART.
	_check("the ENet server was NOT torn down", NetworkManager.is_networked() and NetworkManager.is_host())
	_check("the status socket was NOT torn down", ServerQuery.is_responding())
	_done("referee")

## `current_scene` is briefly null across a `change_scene_to_file`, and this run asks for
## its name on every tick of two polling loops.
func _scene_name() -> String:
	var scene: Node = get_tree().current_scene
	return String(scene.name) if scene != null else "<null>"

## `main.gd::DEDICATED_POST_MATCH_SECONDS`, read off the live script rather than copied.
##
## ⚠️ THROUGH `get_script_constant_map()`, NOT `Object.get()`. A GDScript `const` is not a
## property — `get("DEDICATED_POST_MATCH_SECONDS")` returns null and the fallback would
## silently become the whole answer, which is how a wait-for-N-seconds test quietly turns
## into a wait-for-zero-seconds one.
func _post_match_seconds() -> float:
	var scene: Node = get_tree().current_scene
	if scene == null or scene.get_script() == null:
		return 120.0
	var constants: Dictionary = scene.get_script().get_script_constant_map()
	return float(constants.get("DEDICATED_POST_MATCH_SECONDS", 120.0))

## A real client for the run above: claims the lobby, starts the match, and then STAYS —
## which is the case `play` deliberately does not cover. It exits when the referee closes
## the room, which is itself the check that the eviction reached a live client.
func _stay() -> void:
	var screen: Node = await _open_screen()
	screen.call("_on_host_online_pressed")
	await get_tree().create_timer(4.0).timeout
	_check("claimed the lobby", NetworkManager.is_networked())
	var lobby: Node = get_tree().current_scene
	if lobby == null or lobby.name == "MultiplayerSetup":
		_check("landed in the lobby", false)
		_done("stay")
		return
	lobby.call("_on_primary_pressed") # READY
	await get_tree().create_timer(1.0).timeout
	lobby.call("_on_start_pressed")
	await get_tree().create_timer(9.0).timeout
	_check("the match scene loaded", get_tree().current_scene.name == "Main")
	# The in-match ready gate — a second, separate press. See `_endure`.
	var press := InputEventAction.new()
	press.action = "ready_up"
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().create_timer(5.0).timeout
	_check("the round started", MatchManager.round_number >= 1)
	var slept := 0.0
	while slept < 220.0 and get_tree().current_scene.name != "MultiplayerSetup":
		await get_tree().create_timer(1.0).timeout
		slept += 1.0
	print("[stay] t+%.0fs scene=%s" % [slept, get_tree().current_scene.name])
	_check("the referee sent this client home when the match was over",
		get_tree().current_scene.name == "MultiplayerSetup")
	_done("stay")

# =============================================================================
# The screen, hosted beside us rather than above us.
# =============================================================================

func _open_screen() -> Node:
	var screen: Node = load(SCREEN).instantiate()
	get_tree().root.add_child.call_deferred(screen) # root is still setting THIS node up
	await get_tree().process_frame
	get_tree().current_scene = screen
	# Several query rounds plus `_pool_answered_enough`'s settle window, which HOST ONLINE
	# waits on before it will call a silent pool "busy".
	await get_tree().create_timer(4.0).timeout
	return screen

## The row this lobby is putting on the wire right now, or {} if it did not answer.
func _status() -> Dictionary:
	for row in (ServerQuery.servers() as Array):
		if int((row as Dictionary).get("port", 0)) == _port:
			return row
	return {}

func _print_status(tag: String) -> void:
	var row := _status()
	if row.is_empty():
		print("[%s] status: <no reply from %d>" % [tag, _port])
		return
	print("[%s] status: code=%s players=%d occupied=%d in_progress=%s" % [
		tag, String(row.get("code", "")), int(row.get("players", 0)),
		int(row.get("occupied", 0)), str(bool(row.get("in_progress", false)))])

# =============================================================================
# Roles
# =============================================================================

## Claims the lobby, plays into the match, then walks out mid-match.
func _play() -> void:
	var screen: Node = await _open_screen()
	print("[play] pool rows: %d" % (ServerQuery.servers() as Array).size())
	_print_status("play")
	screen.call("_on_host_online_pressed")
	await get_tree().create_timer(4.0).timeout

	_check("claimed the lobby and connected", NetworkManager.is_networked())
	_check("this peer leads it", NetworkManager.is_lobby_leader())
	_check("the far end is a referee, and said so", NetworkManager.is_dedicated)
	print("[play] code_before=%s" % NetworkManager.join_code)

	var lobby: Node = get_tree().current_scene
	_check("landed in the lobby", lobby != null and lobby.name != "MultiplayerSetup")
	lobby.call("_on_primary_pressed") # READY
	await get_tree().create_timer(1.0).timeout
	_check("START MATCH is live", not bool(lobby.get("start_button").disabled))
	lobby.call("_on_start_pressed")
	# The request goes over, the server broadcasts, both ends change scene and the map plus
	# four characters have to load. Same budget `dedicated_match_run.gd` measured.
	await get_tree().create_timer(9.0).timeout

	var scene: Node = get_tree().current_scene
	print("[play] current scene: %s" % (scene.name if scene != null else "<null>"))
	_check("the match scene loaded", scene != null and scene.name != "MatchSetup")
	var bodies := _find_all(scene, "CharacterBody3D")
	print("[play] characters in the world: %d" % bodies.size())
	_check("all four fighters spawned", bodies.size() == 4)

	# ⚠️ THE ROUND IS STARTED BEFORE WALKING OUT, ON PURPOSE. The reported incident is a
	# match *"abandoned mid-"*, and a client that quits during the in-match ready gate
	# leaves the referee in a subtly easier state — `RoundManager.round_active` false,
	# `_awaiting_net_ready` true, no round clock running. Pressing `ready_up` puts the
	# referee in the state it is actually stuck in on the VM: a live round, a running
	# timer, and then nobody there. See `main.gd::_enter_net_ready_phase` for why this is
	# a second, separate press from the lobby's READY.
	var press := InputEventAction.new()
	press.action = "ready_up"
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().create_timer(6.0).timeout
	print("[play] round=%d active=%s" % [MatchManager.round_number, str(RoundManager.round_active)])
	_check("a round is genuinely running before we walk out", RoundManager.round_active)

	# The lobby screen stopped browsing on its way out — ask again from here.
	ServerQuery.start_browsing()
	await get_tree().create_timer(3.0).timeout
	_print_status("play")
	var row := _status()
	_check("mid-match it reports IN A MATCH", bool(row.get("in_progress", false)))
	_check("mid-match it counts the one human playing", int(row.get("occupied", 0)) == 1)
	_done("play")

## ---------------------------------------------------------------------------
## THE OTHER TRIGGER: the match reaches its NATURAL END with the player still sitting there.
##
## Everything `play` does, and then it stays. `RoundManager.ROUND_TIME` is 90 s and a round
## only ever ends on the clock (`_on_time_up` is its single caller of
## `report_round_result`), so four rounds plus three 3 s intermissions is 6 min 9 s of
## real time before `match_won` can possibly fire — then `main.gd`'s
## `DEDICATED_POST_MATCH_SECONDS` grace on top. There is no shortcut: the whole point of
## this role is that nothing is faked, so it costs what a match costs.
##
## What it is watching for is that the referee eventually CLOSES THE ROOM: this client
## lands back on `MultiplayerSetup` ("Host ended the session."), and the lobby it was in
## goes back to `in_progress=false, occupied=0` rather than sitting behind a result screen
## nobody is looking at.
## ---------------------------------------------------------------------------
func _endure() -> void:
	var screen: Node = await _open_screen()
	screen.call("_on_host_online_pressed")
	await get_tree().create_timer(4.0).timeout
	_check("claimed the lobby and connected", NetworkManager.is_networked())
	print("[endure] code_before=%s" % NetworkManager.join_code)
	var lobby: Node = get_tree().current_scene
	_check("landed in the lobby", lobby != null and lobby.name != "MultiplayerSetup")
	lobby.call("_on_primary_pressed") # READY
	await get_tree().create_timer(1.0).timeout
	lobby.call("_on_start_pressed")
	await get_tree().create_timer(9.0).timeout
	_check("the match scene loaded", get_tree().current_scene.name == "Main")

	# ⚠️ THE IN-MATCH READY GATE IS A SECOND, SEPARATE PRESS, and the round does not start
	# without it — `main.gd::_enter_net_ready_phase` waits for one `ready_up` per playing
	# peer before `_run_ready_countdown` ever runs. Sent as a real input event rather than
	# by reaching for the RPC, because the RPC is host-side (`_rpc_declare_ready` returns
	# immediately unless `is_host()`) and the client's half of that gate IS the keypress.
	var press := InputEventAction.new()
	press.action = "ready_up"
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().create_timer(6.0).timeout
	print("[endure] round=%d active=%s" % [MatchManager.round_number, str(RoundManager.round_active)])
	_check("the round actually started", MatchManager.round_number >= 1)

	ServerQuery.start_browsing()
	var bounced := false
	# 4 x 90 s of rounds, 3 x 3 s of intermission, then the referee's post-match grace.
	# Generous on top of that, because this is the one run that is genuinely waiting for
	# wall-clock game time rather than for a socket.
	for i in range(60):
		await get_tree().create_timer(10.0).timeout
		var here: String = get_tree().current_scene.name if get_tree().current_scene != null else "<null>"
		if i % 3 == 0 or here != "Main":
			print("[endure] t=%ds scene=%s round=%d %s" % [
				(i + 1) * 10, here, MatchManager.round_number, _status_line()])
		if here != "Main":
			bounced = true
			break
	_check("the referee closed the room once the match was over", bounced)
	_check("and this client landed back on the server browser",
		get_tree().current_scene != null and get_tree().current_scene.name == "MultiplayerSetup")
	# The client's own peer is gone by now, so ask the pool rather than NetworkManager.
	ServerQuery.start_browsing()
	await get_tree().create_timer(3.0).timeout
	var row := _status()
	print("[endure] %s" % _status_line())
	_check("the lobby is free again", not bool(row.get("in_progress", true)))
	_check("and holds nobody", int(row.get("occupied", 1)) == 0)
	_done("endure")

func _status_line() -> String:
	var row := _status()
	if row.is_empty():
		return "status=<no reply>"
	return "status: code=%s players=%d occupied=%d in_progress=%s" % [
		String(row.get("code", "")), int(row.get("players", 0)),
		int(row.get("occupied", 0)), str(bool(row.get("in_progress", false)))]

## The BEFORE measurement. Nobody is connected; watch what the server keeps saying.
func _watch() -> void:
	ServerQuery.start_browsing()
	for i in range(12):
		await get_tree().create_timer(1.0).timeout
		_print_status("watch t=%ds" % [i + 1])
	_done("watch")

## The AFTER measurement: free again, and genuinely claimable by a second player.
func _claim() -> void:
	var screen: Node = await _open_screen()
	_print_status("claim")
	var row := _status()
	_check("the lobby is still answering at all", not row.is_empty())
	_check("it is no longer IN A MATCH", not bool(row.get("in_progress", false)))
	_check("it holds nobody", int(row.get("occupied", 1)) == 0)
	_check("it seats nobody", int(row.get("players", 1)) == 0)
	var free: String = String(screen.call("_free_pool_address"))
	print("[claim] HOST ONLINE would claim: '%s'" % free)
	_check("HOST ONLINE will claim it", free.ends_with(":%d" % _port))

	screen.call("_on_host_online_pressed")
	await get_tree().create_timer(5.0).timeout
	_check("a second client connected to the recycled lobby", NetworkManager.is_networked())
	_check("and it leads it, so it can pick the map and start", NetworkManager.is_lobby_leader())
	_check("the far end is still a referee", NetworkManager.is_dedicated)
	print("[claim] code_after=%s" % NetworkManager.join_code)
	_check("the recycled lobby advertises a join code", not NetworkManager.join_code.is_empty())
	var lobby: Node = get_tree().current_scene
	var in_lobby := lobby != null and lobby.name != "MultiplayerSetup"
	_check("landed in a fresh waiting room", in_lobby)
	# ⚠️ GUARDED ON HAVING ACTUALLY MOVED. `MultiplayerSetup` has no `_on_primary_pressed`,
	# so calling it on a run that never left the fork is a hard error that kills the process
	# before `_done()` — which is how the pre-fix run reported nine failures and then no
	# RESULT line at all, and looked like a harness bug rather than the finding.
	if in_lobby:
		lobby.call("_on_primary_pressed") # READY
		await get_tree().create_timer(1.0).timeout
		_check("START MATCH is offered to the new leader", bool(lobby.get("start_button").visible))
		_check("and it is live, so the lobby is genuinely usable",
			not bool(lobby.get("start_button").disabled))
	_done("claim")

# =============================================================================

func _done(tag: String) -> void:
	print("[%s] RESULT %s" % [tag, "PASS" if _fail == 0 else "FAIL (%d)" % _fail])
	get_tree().quit(_fail)

func _check(what: String, ok: bool) -> void:
	if not ok:
		_fail += 1
	print("[%s] %s  %s" % [_role, "PASS" if ok else "FAIL", what])

func _find_all(from: Node, type_name: String) -> Array[Node]:
	var out: Array[Node] = []
	if from == null:
		return out
	if from.is_class(type_name):
		out.append(from)
	for child in from.get_children():
		out.append_array(_find_all(child, type_name))
	return out
