extends Node
## CAN YOU ACTUALLY PLAY THROUGH A DEDICATED SERVER? — the whole path, driven for real.
##
## 🧑 2026-08-02: *"i want to test if i can join and play just fine through this online
## path"*. Every other harness in this tree stops at the lobby. This one presses HOST
## ONLINE, claims a pool server, readies up, starts the match, and then checks that a
## match is genuinely RUNNING on the far side — characters in the world, a can to knock
## over, a round in progress — rather than that a scene merely loaded.
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/net/dedicated_match_run.tscn -- \
##         --pool=127.0.0.1 --port=<game-port> <out-dir-with-trailing-slash>
##
## A real dedicated lobby must already be listening on that port:
##     Godot ... --headless --path . res://scenes/ui/MatchSetup.tscn -- --dedicated --port=<p>
##
## ⚠️ PLAIN EXE, NOT --headless. No rendering device under --headless on this machine —
## captures come back blank and the 3D scene never draws.
##
## ⚠️⚠️ THE HARNESS STAYS OUT OF THE SCENE IT DRIVES, by handing `current_scene` to the
## screen and living beside it under `root`. This run changes scene TWICE (lobby, then
## Main.tscn) and `change_scene_to_file` frees `current_scene` — a harness parented above
## the screen deletes itself the moment the first press works.
##
## ⚠️ COUNT NODES, DO NOT ASK `RoundManager.players()`. That list is only ever filled on
## the host/solo paths (`register_player` is not called on a client), so on the peer that
## matters it reads 0 whether the match is perfect or broken — measured. The characters in
## the tree are the thing a player would actually see.

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
	get_tree().root.add_child.call_deferred(screen) # root is still setting THIS node up
	await get_tree().process_frame
	get_tree().current_scene = screen
	await get_tree().create_timer(4.0).timeout # several query rounds plus the settle window

	var sq: Node = get_node("/root/ServerQuery")
	var nm: Node = get_node("/root/NetworkManager")
	print("[run] pool rows: %d" % (sq.call("servers") as Array).size())
	screen.call("_on_host_online_pressed")
	await get_tree().create_timer(4.0).timeout

	_check("claimed a server and connected", bool(nm.call("is_networked")))
	_check("this peer leads the lobby", bool(nm.call("is_lobby_leader")))
	# ⚠️ THIS CHECK ONLY BECAME HONEST WHEN THE SERVER STARTED SENDING THE FLAG. It used to
	# be a flag the server set on itself and never told anybody, so on this side it read
	# false whether the far end was a referee or a listen host and asserting on it proved
	# nothing. `NetworkManager._rpc_announce_dedicated` now delivers it on identify — see
	# `is_seatless_referee` for why a client needs it — so a client can finally state what
	# kind of lobby it is in, and this run's whole premise is that it is a dedicated one.
	_check("the far end is a referee, and said so", bool(nm.get("is_dedicated")))
	var code: String = String(nm.get("join_code"))
	_check("a join code arrived to read out", not code.is_empty())
	print("[run] code=%s" % code)

	var lobby: Node = get_tree().current_scene
	_check("landed in the lobby, not still on the fork", lobby.name != "MultiplayerSetup")
	lobby.call("_on_primary_pressed") # READY
	await get_tree().create_timer(1.0).timeout
	_check("START MATCH is offered to the leader", bool(lobby.get("start_button").visible))
	_check("START MATCH is enabled once everyone is ready",
		not bool(lobby.get("start_button").disabled))

	lobby.call("_on_start_pressed")
	# The request goes to the server, the server broadcasts, both ends change scene, and
	# the map plus every character has to load. Generous on purpose: this is the one wait
	# in the run that is doing real work rather than watching a socket.
	await get_tree().create_timer(9.0).timeout

	var scene: Node = get_tree().current_scene
	print("[run] current scene: %s" % (scene.name if scene != null else "<null>"))
	_check("the match scene actually loaded", scene != null and scene.name != "MatchSetup")
	var bodies := _find_all(scene, "CharacterBody3D")
	print("[run] characters in the world: %d" % bodies.size())
	_check("all four fighters spawned", bodies.size() == 4)
	_check("the can is in the world", _find_one(scene, "RigidBody3D") or _named(scene, "can"))

	# ⚠️ DO NOT ASSERT `NetworkManager.match_in_progress` HERE. It is written in one place
	# only — `main.gd::_start_hosting`, on the HOST — because it answers a host-side
	# question ("should a peer arriving now be routed straight into the running match"),
	# and no RPC carries it. On a client it is false during a perfectly healthy match, so
	# a check on it fails on a working game. Measured: this run reported every other check
	# passing, four fighters in the world, and this one false.
	#
	# What matters to the POOL is observable from here, and is the stronger claim anyway:
	# a server in a match must stop looking free, or HOST ONLINE would hand a running game
	# to the next person who pressed it. Ask the pool again and read it back.
	sq.call("start_browsing") # the lobby screen stopped browsing on its way out
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
