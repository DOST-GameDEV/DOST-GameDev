extends SceneTree
## Real-network verification of § DEDICATED HOSTING and § THE LOBBY LEADER
## (`scripts/systems/network_manager.gd`). ONE script, TWO roles, several
## processes — driven by `tools/net/run_lobby_leader_suite.ps1`.
##
##   godot --headless --path . -s tools/net/net_lobby_probe.gd -- \
##       --probe-role=server --probe-tag=S --probe-port=8990 --dedicated --port=8990
##   godot --headless --path . -s tools/net/net_lobby_probe.gd -- \
##       --probe-role=client --probe-tag=A --probe-port=8990 --join=127.0.0.1
##
## ⚠️ EVERY ASSERTION LIVES IN THE DRIVER, NOT HERE. This process only REPORTS —
## one machine-readable line per observation on stdout — because the facts under
## test are relationships BETWEEN processes ("the second peer did not steal the
## role the first one holds") and no single process can see both sides. A probe
## that judged its own half would only be able to check the half that is already
## the easiest to reason about.
##
## ⚠️ THE SERVER ROLE REACHES `host_game()` THROUGH `main.gd`, NOT BY CALLING IT.
## The hosting args (`--dedicated`, `--host`, `--port=`) are passed straight
## through to `Main.tscn`, whose `_ready()` parses `OS.get_cmdline_user_args()`
## exactly as it does for the documented launch line. Calling `host_game(port,
## true)` from here would test this file's understanding of the flag rather than
## the flag, and the argument parsing is half of what "dedicated hosting works"
## means. The ONLY deviation from the documented command is that the scene is
## reached via `change_scene_to_file` instead of a positional scene argument —
## required, because a `-s` script IS the main loop and is the only thing that
## outlives the scene load to keep reporting.
##
## ⚠️ AND IT IS A `SceneTree` SCRIPT FOR A SECOND REASON. A dedicated server sets
## `match_in_progress` in `_start_hosting()`, so `_rpc_identify` answers every
## client with `_rpc_route_to_running_match` — a `change_scene_to_file()` on the
## CLIENT. A probe Node would be freed by it mid-run and the leader handover,
## which happens later, would go unreported.

## Deliberately a literal, not `NetworkManagerScript.MAIN_SCENE_PATH`: a `-s`
## main loop is compiled before the autoloads are registered as GDScript globals,
## so a compile-time reference to one fails the whole script before a line runs.
## Same reason `_nm()` resolves by node path — see `tools/lobby_probe.gd`, which
## paid for this lesson first.
const MAIN_PATH: String = "res://scenes/main/Main.tscn"
## Fast enough that a handover lands inside one or two samples, slow enough that
## a 60 s run is a few hundred lines rather than a few thousand.
const STATE_INTERVAL: float = 0.25

var _role: String = "client"
var _tag: String = "?"
var _port: int = 8990
## Absolute native path. When it appears, this peer leaves the lobby POLITELY —
## see `_leave` for why the departure is not simply a killed process.
var _leave_file: String = ""
## Backstop only. A driver that dies must not leave a process holding a port.
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

## ⚠️ NOT `_initialize()`. The autoloads are not in the tree yet when a `-s` main
## loop initialises, so the first `_process` tick is the earliest point at which
## `/root/NetworkManager` can be reached at all.
func _begin() -> void:
	_started = true
	var nm := _nm()
	# Connected BEFORE anything hosts or joins, so no transition can happen
	# behind this probe's back and be missed.
	nm.connect("lobby_leader_changed", _on_leader_changed)
	_say("BOOT", "role=%s port=%d" % [_role, _port])
	if _role == "server":
		change_scene_to_file(MAIN_PATH)
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

	# The instant hosting comes up, before any client can have touched it. This
	# is the sample the "a dedicated server seeds none of the three" assertion
	# reads — a periodic STATE line could only ever say "not any more".
	if _role == "server" and not _announced_hosting and bool(nm.call("is_host")):
		_announced_hosting = true
		_snapshot("INIT")
		_say("HOSTING", "port=%d" % _port)

	# `connected_peer_ids` is written in `_on_connected_to_server`, i.e. once the
	# handshake really completed — `get_unique_id()` alone is answered by the
	# offline sentinel peer long before that and would report id 1 for a client.
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

## ⚠️ A POLITE EXIT, NOT A KILLED PROCESS, AND THE DIFFERENCE IS ~5 SECONDS.
## `announce_host_leaving`'s own header measured it: a closed socket and a silent
## one are indistinguishable to ENet, so an abruptly killed peer is only noticed
## when `ENET_TIMEOUT_MIN` expires. `disconnect_network()` closes the peer, which
## flushes a real ENet disconnect, so the server's `_on_peer_disconnected` — and
## therefore `_reassign_leader` — runs immediately. Killing the process would
## still work, but it would test the timeout rather than the handover.
func _leave() -> void:
	_left = true
	_say("LEAVE", "t=%.2f self=%d" % [_t, _uid()])
	_nm().call("disconnect_network")
	# A beat for ENet to actually put the disconnect on the wire before the
	# process dies underneath it.
	_quit_at = minf(_quit_at, _t + 1.0)

func _on_leader_changed(peer_id: int) -> void:
	# The ordered transcript the driver checks handover against. Every change
	# lands here on the host AND on every client, which is itself an assertion.
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
	_say(kind, "t=%.2f self=%d net=%d host=%d dedicated=%d leader=%d isleader=%d peers=%s tokens=%s chars=%s" % [
		_t, _uid(),
		1 if networked else 0,
		1 if host else 0,
		1 if dedicated else 0,
		leader,
		1 if is_leader else 0,
		_ids(peers), _ids(tokens.keys()), _ids(chars.keys()),
	])

func _uid() -> int:
	var nm := _nm()
	if nm.multiplayer == null:
		return 0
	return nm.multiplayer.get_unique_id()

## "-" for empty rather than "", so a field can never vanish from the line and
## silently shift the driver's parse.
func _ids(values: Array) -> String:
	if values.is_empty():
		return "-"
	var out: PackedStringArray = []
	for value in values:
		out.append(str(int(value)))
	return ",".join(out)

func _say(kind: String, body: String) -> void:
	print("NETPROBE %s %s %s" % [_tag, kind, body])
