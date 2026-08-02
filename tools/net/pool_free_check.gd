extends Node
## IS A LOBBY HOLDING ONLY A SPECTATOR "FREE"? — the case `players` cannot answer.
##
## Two roles, one script:
##
##   --role=spectator --port=<p>   joins that lobby as a SPECTATOR and sits there
##   --role=probe                  asks the pool what it sees and whether HOST ONLINE
##                                 would claim it
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/net/pool_free_check.tscn -- \
##         --pool=127.0.0.1 --role=probe
##
## ⚠️ THE POINT OF THE SPECTATOR. `seated_peer_count()` counts SEATS, so a lobby whose
## only occupant is watching advertises `players=0` — indistinguishable from empty on the
## wire. That occupant identified first, so it holds the lobby leader role; a HOST ONLINE
## press that claimed this server would hand the player a lobby somebody else runs. The
## probe therefore checks `occupied`, not `players`, and this harness is what proves the
## two genuinely disagree rather than being the same number twice.
##
## ⚠️ --headless IS FINE HERE. Nothing is rendered — this prints numbers.

const SCREEN: String = "res://scenes/ui/MultiplayerSetup.tscn"

var _role: String = "probe"
var _port: int = 8916
var _fail: int = 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.substr(len("--role="))
		elif a.begins_with("--port="):
			_port = int(a.substr(len("--port=")))
	if _role == "spectator":
		await _be_a_spectator()
	else:
		await _probe()

## Joins and declares itself a watcher, then stays up so the probe has something to look
## at. Deliberately does NOT go through the lobby screen: this is a body in a chair, not a
## UI test, and the fewer moving parts holding the seat open the better.
func _be_a_spectator() -> void:
	GameLaunch.spectator = true
	if NetworkManager.join_game("127.0.0.1", _port) != OK:
		print("[spec] could not reach the lobby")
		get_tree().quit(1)
		return
	await get_tree().create_timer(2.0).timeout
	NetworkManager.publish_spectator(true)
	print("[spec] watching lobby on %d" % _port)
	# Long enough for the probe to start, query, settle and report.
	await get_tree().create_timer(25.0).timeout
	get_tree().quit()

func _probe() -> void:
	var screen: Node = load(SCREEN).instantiate()
	get_tree().root.add_child.call_deferred(screen) # root is still setting THIS node up
	await get_tree().process_frame
	get_tree().current_scene = screen
	await get_tree().create_timer(5.0).timeout

	var sq: Node = get_node("/root/ServerQuery")
	var mine: Dictionary = {}
	for row in (sq.call("servers") as Array):
		if int((row as Dictionary).get("port", 0)) == _port:
			mine = row
	print("[probe] the server says: %s" % str(mine))
	_check("the pool heard the server at all", not mine.is_empty())
	_check("it reports NO seats taken -- the spectator holds none",
		int(mine.get("players", -1)) == 0)
	_check("but it reports somebody IS in there", int(mine.get("occupied", -1)) == 1)
	var free: String = String(screen.call("_free_pool_address"))
	print("[probe] HOST ONLINE would claim: '%s'" % free)
	_check("so HOST ONLINE refuses to claim it", free.is_empty())
	print("[probe] RESULT %s" % ("PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(_fail)

func _check(what: String, ok: bool) -> void:
	if not ok:
		_fail += 1
	print("[probe] %s  %s" % ["PASS" if ok else "FAIL", what])
