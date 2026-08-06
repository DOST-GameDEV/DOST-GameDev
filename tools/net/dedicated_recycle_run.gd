extends Node

const SCREEN: String = "res://scenes/ui/MultiplayerSetup.tscn"

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

	var waited := 0.0
	while waited < 45.0 and MatchManager.round_number < 1:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	print("[referee] scene=%s round=%d in_progress=%s" % [
		_scene_name(), MatchManager.round_number,
		str(NetworkManager.match_in_progress)])
	_check("a real match started through the real lobby", MatchManager.round_number >= 1)
	_check("and the pool is told so", NetworkManager.match_in_progress)

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
	_check("the ENet server was NOT torn down", NetworkManager.is_networked() and NetworkManager.is_host())
	_check("the status socket was NOT torn down", ServerQuery.is_responding())
	_done("referee")

func _scene_name() -> String:
	var scene: Node = get_tree().current_scene
	return String(scene.name) if scene != null else "<null>"

func _post_match_seconds() -> float:
	var scene: Node = get_tree().current_scene
	if scene == null or scene.get_script() == null:
		return 120.0
	var constants: Dictionary = scene.get_script().get_script_constant_map()
	return float(constants.get("DEDICATED_POST_MATCH_SECONDS", 120.0))

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
	lobby.call("_on_primary_pressed")
	await get_tree().create_timer(1.0).timeout
	lobby.call("_on_start_pressed")
	await get_tree().create_timer(9.0).timeout
	_check("the match scene loaded", get_tree().current_scene.name == "Main")
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


func _open_screen() -> Node:
	var screen: Node = load(SCREEN).instantiate()
	get_tree().root.add_child.call_deferred(screen)
	await get_tree().process_frame
	get_tree().current_scene = screen
	await get_tree().create_timer(4.0).timeout
	return screen

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
	lobby.call("_on_primary_pressed")
	await get_tree().create_timer(1.0).timeout
	_check("START MATCH is live", not bool(lobby.get("start_button").disabled))
	lobby.call("_on_start_pressed")
	await get_tree().create_timer(9.0).timeout

	var scene: Node = get_tree().current_scene
	print("[play] current scene: %s" % (scene.name if scene != null else "<null>"))
	_check("the match scene loaded", scene != null and scene.name != "MatchSetup")
	var bodies := _find_all(scene, "CharacterBody3D")
	print("[play] characters in the world: %d" % bodies.size())
	_check("all four fighters spawned", bodies.size() == 4)

	var press := InputEventAction.new()
	press.action = "ready_up"
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().create_timer(6.0).timeout
	print("[play] round=%d active=%s" % [MatchManager.round_number, str(RoundManager.round_active)])
	_check("a round is genuinely running before we walk out", RoundManager.round_active)

	ServerQuery.start_browsing()
	await get_tree().create_timer(3.0).timeout
	_print_status("play")
	var row := _status()
	_check("mid-match it reports IN A MATCH", bool(row.get("in_progress", false)))
	_check("mid-match it counts the one human playing", int(row.get("occupied", 0)) == 1)
	_done("play")

func _endure() -> void:
	var screen: Node = await _open_screen()
	screen.call("_on_host_online_pressed")
	await get_tree().create_timer(4.0).timeout
	_check("claimed the lobby and connected", NetworkManager.is_networked())
	print("[endure] code_before=%s" % NetworkManager.join_code)
	var lobby: Node = get_tree().current_scene
	_check("landed in the lobby", lobby != null and lobby.name != "MultiplayerSetup")
	lobby.call("_on_primary_pressed")
	await get_tree().create_timer(1.0).timeout
	lobby.call("_on_start_pressed")
	await get_tree().create_timer(9.0).timeout
	_check("the match scene loaded", get_tree().current_scene.name == "Main")

	var press := InputEventAction.new()
	press.action = "ready_up"
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().create_timer(6.0).timeout
	print("[endure] round=%d active=%s" % [MatchManager.round_number, str(RoundManager.round_active)])
	_check("the round actually started", MatchManager.round_number >= 1)

	ServerQuery.start_browsing()
	var bounced := false
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

func _watch() -> void:
	ServerQuery.start_browsing()
	for i in range(12):
		await get_tree().create_timer(1.0).timeout
		_print_status("watch t=%ds" % [i + 1])
	_done("watch")

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
	if in_lobby:
		lobby.call("_on_primary_pressed")
		await get_tree().create_timer(1.0).timeout
		_check("START MATCH is offered to the new leader", bool(lobby.get("start_button").visible))
		_check("and it is live, so the lobby is genuinely usable",
			not bool(lobby.get("start_button").disabled))
	_done("claim")


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

