extends Node

const SCREEN: String = "res://scenes/ui/MultiplayerSetup.tscn"

var _out: String = ""
var _port: int = 8910
var _fail: int = 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			_port = int(a.substr(len("--port=")))
		elif not a.begins_with("--"):
			_out = a

	var screen: Node = load(SCREEN).instantiate()
	get_tree().root.add_child.call_deferred(screen)
	await get_tree().process_frame
	get_tree().current_scene = screen
	await get_tree().create_timer(4.0).timeout

	var sq: Node = get_node("/root/ServerQuery")
	var nm: Node = get_node("/root/NetworkManager")
	print("[run] pool rows: %d" % (sq.call("servers") as Array).size())
	screen.call("_on_host_online_pressed")
	await get_tree().create_timer(4.0).timeout

	_check("claimed a server and connected", bool(nm.call("is_networked")))
	_check("this peer leads the lobby", bool(nm.call("is_lobby_leader")))
	_check("the far end is a referee, and said so", bool(nm.get("is_dedicated")))
	var code: String = String(nm.get("join_code"))
	_check("a join code arrived to read out", not code.is_empty())
	print("[run] code=%s" % code)

	var lobby: Node = get_tree().current_scene
	_check("landed in the lobby, not still on the fork", lobby.name != "MultiplayerSetup")
	lobby.call("_on_primary_pressed")
	await get_tree().create_timer(1.0).timeout
	_check("START MATCH is offered to the leader", bool(lobby.get("start_button").visible))
	_check("START MATCH is enabled once everyone is ready",
		not bool(lobby.get("start_button").disabled))

	lobby.call("_on_start_pressed")
	await get_tree().create_timer(9.0).timeout

	var scene: Node = get_tree().current_scene
	print("[run] current scene: %s" % (scene.name if scene != null else "<null>"))
	_check("the match scene actually loaded", scene != null and scene.name != "MatchSetup")
	var bodies := _find_all(scene, "CharacterBody3D")
	print("[run] characters in the world: %d" % bodies.size())
	_check("all four fighters spawned", bodies.size() == 4)
	_check("the can is in the world", _find_one(scene, "RigidBody3D") or _named(scene, "can"))

	sq.call("start_browsing")
	await get_tree().create_timer(3.0).timeout
	var mine: Dictionary = {}
	for row in (sq.call("servers") as Array):
		if int((row as Dictionary).get("port", 0)) == _port:
			mine = row
	print("[run] the server now says: %s" % str(mine))
	_check("the pool can still hear the server mid-match", not mine.is_empty())
	_check("it reports IN A MATCH, so HOST ONLINE cannot claim it as free",
		bool(mine.get("in_progress", false)))
	_check("it counts the human who is playing", int(mine.get("players", 0)) == 1)

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + "dedicated_match.png")
	print("[run] wrote %sdedicated_match.png" % _out)
	print("[run] RESULT %s" % ("PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(_fail)

func _check(what: String, ok: bool) -> void:
	if not ok:
		_fail += 1
	print("[run] %s  %s" % ["PASS" if ok else "FAIL", what])

func _find_all(from: Node, type_name: String) -> Array[Node]:
	var out: Array[Node] = []
	if from == null:
		return out
	if from.is_class(type_name):
		out.append(from)
	for child in from.get_children():
		out.append_array(_find_all(child, type_name))
	return out

func _find_one(from: Node, type_name: String) -> bool:
	return not _find_all(from, type_name).is_empty()

func _named(from: Node, needle: String) -> bool:
	if from == null:
		return false
	if String(from.name).to_lower().contains(needle):
		return true
	for child in from.get_children():
		if _named(child, needle):
			return true
	return false

