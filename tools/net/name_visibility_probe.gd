extends Node

const SETUP: String = "res://scenes/ui/MatchSetup.tscn"

var _name: String = "PROBE"
var _tag: String = "?"
var _port: int = 8960
var _role: String = "client"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--name="):
			_name = a.substr(len("--name="))
		elif a.begins_with("--tag="):
			_tag = a.substr(len("--tag="))
		elif a.begins_with("--port="):
			_port = int(a.substr(len("--port=")))
		elif a.begins_with("--role="):
			_role = a.substr(len("--role="))
	if _role == "server":
		await _be_the_server()
		return
	if _role == "spectate":
		await _be_a_spectator()
		return

	SettingsManager.player_name = _name
	_say("my chosen name is '%s' (GameLaunch says '%s')"
		% [_name, GameLaunch.player_name()])

	GameLaunch.pending_action = "join"
	GameLaunch.pending_join_address = "127.0.0.1:%d" % _port
	GameLaunch.clear_seating()
	MatchManager.reset()
	RoundManager.reset()

	var screen: Node = load(SETUP).instantiate()
	get_tree().root.add_child.call_deferred(screen)
	await get_tree().process_frame
	get_tree().current_scene = screen
	await get_tree().create_timer(5.0).timeout

	var nm: Node = get_node("/root/NetworkManager")
	_say("connected=%s leader=%s dedicated=%s peers=%s"
		% [nm.call("is_networked"), nm.call("is_lobby_leader"),
			nm.get("is_dedicated"), str(nm.get("connected_peer_ids"))])

	var lobby: Node = get_tree().current_scene
	lobby.call("_on_primary_pressed")
	await get_tree().create_timer(12.0).timeout

	for peer_id in (nm.get("connected_peer_ids") as Array):
		if int(peer_id) == 1 and bool(nm.get("is_dedicated")):
			continue
		_say("lobby: peer %d spectating=%s picks=%s"
			% [int(peer_id), nm.call("is_spectator", int(peer_id)),
				str(nm.call("picks_for", int(peer_id)))])
	if is_instance_valid(lobby) and get_tree().current_scene == lobby:
		for seat in range(4):
			_say("lobby row %d: %s" % [seat, String(lobby.call("_seat_row_text", seat))])

	if bool(nm.call("is_lobby_leader")):
		_say("I lead this lobby — pressing START MATCH")
		lobby.call("_on_start_pressed")

	await get_tree().create_timer(9.0).timeout
	var scene: Node = get_tree().current_scene
	_say("scene now: %s" % (scene.name if scene != null else "<null>"))
	var press := InputEventAction.new()
	press.action = "ready_up"
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().create_timer(8.0).timeout

	_report(get_tree().current_scene)
	await get_tree().create_timer(6.0).timeout
	_say("-- second look --")
	_report(get_tree().current_scene)
	get_tree().quit()

func _be_a_spectator() -> void:
	SettingsManager.player_name = _name
	GameLaunch.spectator = true
	if NetworkManager.join_game("127.0.0.1", _port) != OK:
		_say("could not reach the lobby")
		get_tree().quit(1)
		return
	await get_tree().create_timer(3.0).timeout
	NetworkManager.publish_spectator(true)
	_say("watching lobby on %d as '%s'" % [_port, _name])
	await get_tree().create_timer(30.0).timeout
	get_tree().quit()

func _be_the_server() -> void:
	var screen: Node = load(SETUP).instantiate()
	get_tree().root.add_child.call_deferred(screen)
	await get_tree().process_frame
	get_tree().current_scene = screen
	var nm: Node = get_node("/root/NetworkManager")
	for sample in range(16):
		await get_tree().create_timer(5.0).timeout
		var scene: Node = get_tree().current_scene
		_say("t+%ds scene=%s picks=%s"
			% [(sample + 1) * 5, (scene.name if scene != null else "<null>"),
				str(nm.get("peer_characters"))])
		if scene != null and scene.name == "Main":
			_report(scene)
	get_tree().quit()

func _report(scene: Node) -> void:
	var nm: Node = get_node("/root/NetworkManager")
	_say("round=%d peers=%s" % [MatchManager.round_number, str(nm.get("connected_peer_ids"))])
	if scene != null:
		_say("seats: %s" % str((scene.get("_index_to_character") as Dictionary).keys()))
	var bodies := _find_all(scene, "CharacterBody3D")
	_say("bodies in the world: %d" % bodies.size())
	for body in bodies:
		_say("  node=%s slot=%s player_name='%s' display='%s' authority=%d picks=%s"
			% [body.name, str(body.get("player_slot")), String(body.get("player_name")),
				String(body.call("display_name")), body.get_multiplayer_authority(),
				str(nm.call("picks_for", int(String(body.name))))])

func _say(what: String) -> void:
	print("[%s] %s" % [_tag, what])

func _find_all(from: Node, type_name: String) -> Array[Node]:
	var out: Array[Node] = []
	if from == null:
		return out
	if from.is_class(type_name):
		out.append(from)
	for child in from.get_children():
		out.append_array(_find_all(child, type_name))
	return out

