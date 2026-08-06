extends SceneTree

const MAIN_PATH: String = "res://scenes/main/Main.tscn"
const MATCH_SETUP_PATH: String = "res://scenes/ui/MatchSetup.tscn"

func _is_dedicated() -> bool:
	return OS.get_cmdline_user_args().has("--dedicated")
const STATE_INTERVAL: float = 0.25

var _role: String = "client"
var _tag: String = "?"
var _port: int = 8990
var _leave_file: String = ""
var _quit_at: float = 120.0

var _t: float = 0.0
var _state_at: float = 0.0
var _started: bool = false
var _left: bool = false
var _announced_self: bool = false
var _announced_hosting: bool = false

func _nm() -> Node:
	return root.get_node("/root/NetworkManager")

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var token := String(arg)
		if token.begins_with("--probe-role="):
			_role = token.substr(len("--probe-role="))
		elif token.begins_with("--probe-tag="):
			_tag = token.substr(len("--probe-tag="))
		elif token.begins_with("--probe-port="):
			_port = int(token.substr(len("--probe-port=")))
		elif token.begins_with("--probe-leave-file="):
			_leave_file = token.substr(len("--probe-leave-file="))
		elif token.begins_with("--probe-quit-at="):
			_quit_at = float(token.substr(len("--probe-quit-at=")))

func _begin() -> void:
	_started = true
	var nm := _nm()
	nm.connect("lobby_leader_changed", _on_leader_changed)
	_say("BOOT", "role=%s port=%d" % [_role, _port])
	if _role == "server":
		if not _is_dedicated():
			var gl := root.get_node("GameLaunch")
			gl.set("pending_action", "host")
		change_scene_to_file(MATCH_SETUP_PATH)
		return
	var err: int = nm.call("join_game", "127.0.0.1", _port)
	if err != OK:
		_say("FATAL", "join_game returned %d" % err)
		quit(1)

func _process(delta: float) -> bool:
	if not _started:
		_begin()
		return false
	_t += delta
	var nm := _nm()

	if _role == "server" and not _announced_hosting and bool(nm.call("is_host")):
		_announced_hosting = true
		_snapshot("INIT")
		_say("HOSTING", "port=%d" % _port)

	if _role == "client" and not _announced_self:
		var peers: Array = nm.get("connected_peer_ids")
		if not peers.is_empty():
			_announced_self = true
			_snapshot("JOINED")

	if _t - _state_at >= STATE_INTERVAL:
		_state_at = _t
		_snapshot("STATE")

	if not _left and _leave_file != "" and FileAccess.file_exists(_leave_file):
		_leave()

	if _t >= _quit_at:
		_say("DONE", "t=%.2f" % _t)
		quit(0)
	return false

func _leave() -> void:
	_left = true
	_say("LEAVE", "t=%.2f self=%d" % [_t, _uid()])
	_nm().call("disconnect_network")
	_quit_at = minf(_quit_at, _t + 1.0)

func _on_leader_changed(peer_id: int) -> void:
	_say("EVENT", "t=%.2f self=%d leader=%d" % [_t, _uid(), peer_id])

func _snapshot(kind: String) -> void:
	var nm := _nm()
	var peers: Array = nm.get("connected_peer_ids")
	var tokens: Dictionary = nm.get("peer_tokens")
	var chars: Dictionary = nm.get("peer_characters")
	var leader: int = nm.get("lobby_leader_id")
	var dedicated: bool = nm.get("is_dedicated")
	var networked: bool = nm.call("is_networked")
	var host: bool = nm.call("is_host")
	var is_leader: bool = nm.call("is_lobby_leader")
	var seated: int = nm.call("seated_peer_count")
	var playing: int = nm.call("playing_peer_count")
	_say(kind, "t=%.2f self=%d net=%d host=%d dedicated=%d leader=%d isleader=%d peers=%s tokens=%s chars=%s seated=%d playing=%d voting=%s" % [
		_t, _uid(),
		1 if networked else 0,
		1 if host else 0,
		1 if dedicated else 0,
		leader,
		1 if is_leader else 0,
		_ids(peers), _ids(tokens.keys()), _ids(chars.keys()),
		seated, playing, _voting(),
	])

func _voting() -> String:
	var scene := current_scene
	if scene == null:
		return "-"
	var result := scene.find_child("MatchResult", true, false)
	if result == null or not result.has_method("_voting_peer_ids"):
		return "-"
	return str((result.call("_voting_peer_ids") as Array).size())

func _uid() -> int:
	var nm := _nm()
	if nm.multiplayer == null:
		return 0
	return nm.multiplayer.get_unique_id()

func _ids(values: Array) -> String:
	if values.is_empty():
		return "-"
	var out: PackedStringArray = []
	for value in values:
		out.append(str(int(value)))
	return ",".join(out)

func _say(kind: String, body: String) -> void:
	print("NETPROBE %s %s %s" % [_tag, kind, body])

