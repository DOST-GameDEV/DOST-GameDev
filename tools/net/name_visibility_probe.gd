extends Node
## DO THE NAMES PEOPLE CHOSE ACTUALLY REACH ANOTHER PLAYER'S SCREEN?
##
## 🧑 2026-08-02, from a real player: *"the usernames we choose in the settings don't show
## in the game"* — everybody reads P1/P2/P3/P4, on the 3D nameplates and on the scoreboard.
##
## ⚠️ IT TAKES **TWO** CLIENTS TO SEE THIS AND THAT IS THE WHOLE POINT. With one client
## the only other bodies in the match are bots, which legitimately have no name, so a
## single-client run is green on a broken build. The question is specifically "does
## client A see client B's chosen name", so this harness runs two of itself.
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/net/name_visibility_probe.tscn -- \
##         --name=ALICE --port=8960 --tag=A
##
## against a real dedicated lobby:
##
##     Godot ... --headless --path . res://scenes/ui/MatchSetup.tscn -- --dedicated --port=8960
##
## ⚠️ THE NAME IS ASSIGNED STRAIGHT ONTO `SettingsManager`, NOT THROUGH
## `set_player_name()`. Two probe processes on one machine share one `user://`, so the
## setter's `settings.cfg` write would have the second process overwrite the first's saved
## name — and, worse, leave the human's own real name replaced by "ALICE" afterwards.
## `tools/lan_probe.gd` already does exactly this, for the same reason.
##
## ⚠️ JOINS BY TYPING AN ADDRESS, not through the pool. `_begin_join()` in
## `multiplayer_setup.gd` is the one place a join is recorded, and it is three
## `GameLaunch` writes plus a scene change — reproducing those directly keeps the pool,
## the browser and the code resolver out of a test that is about names.
##
## ⚠️ THE HARNESS STAYS OUT OF THE SCENE IT DRIVES — same trap `dedicated_match_run.gd`
## documents: this run changes scene twice and `change_scene_to_file` frees
## `current_scene`, so a harness parented above the screen deletes itself.

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
	get_tree().root.add_child.call_deferred(screen) # root is still setting THIS node up
	await get_tree().process_frame
	get_tree().current_scene = screen
	await get_tree().create_timer(5.0).timeout

	var nm: Node = get_node("/root/NetworkManager")
	_say("connected=%s leader=%s dedicated=%s peers=%s"
		% [nm.call("is_networked"), nm.call("is_lobby_leader"),
			nm.get("is_dedicated"), str(nm.get("connected_peer_ids"))])

	var lobby: Node = get_tree().current_scene
	lobby.call("_on_primary_pressed") # READY
	# Long enough that the OTHER probe (started a few seconds later) has joined and
	# readied too — the leader's START is gated on everybody being ready.
	#
	# ⚠️ AND LONG ENOUGH THAT THE FOLLOWER IS PAST THIS POINT BEFORE THE LEADER PRESSES
	# START. The two probes are two seconds apart, so a short wait here had the leader
	# change everybody's scene while the follower was still reading lobby rows off a
	# node that had just been freed — `Cannot call method 'call' on a previously freed
	# instance`, measured, and it took the follower's whole run with it.
	await get_tree().create_timer(12.0).timeout

	# The lobby board is the FIRST place a name is meant to appear, one screen before the
	# match — read it here so a failure can be placed on this side or the far side of the
	# scene change.
	for peer_id in (nm.get("connected_peer_ids") as Array):
		if int(peer_id) == 1 and bool(nm.get("is_dedicated")):
			continue # the referee holds no seat and has no name
		_say("lobby: peer %d spectating=%s picks=%s"
			% [int(peer_id), nm.call("is_spectator", int(peer_id)),
				str(nm.call("picks_for", int(peer_id)))])
	# The actual painted row, not a proxy for it — `_seat_row_text` is what the board
	# shows, so a name that resolves in `picks_for` but never reaches the row would be
	# caught here rather than reported as fixed.
	if is_instance_valid(lobby) and get_tree().current_scene == lobby:
		for seat in range(4):
			_say("lobby row %d: %s" % [seat, String(lobby.call("_seat_row_text", seat))])

	if bool(nm.call("is_lobby_leader")):
		_say("I lead this lobby — pressing START MATCH")
		lobby.call("_on_start_pressed")

	# The request goes to the server, the server broadcasts, both ends change scene, and
	# the map plus every character has to load. Same generous wait
	# `dedicated_match_run.gd` uses for the same work, plus the ready-phase countdown
	# that follows it (the R press below, then 3·2·1·GO).
	await get_tree().create_timer(9.0).timeout
	var scene: Node = get_tree().current_scene
	_say("scene now: %s" % (scene.name if scene != null else "<null>"))
	# The match opens on the free-roam ready gate; press R so the countdown runs and the
	# round actually starts — that is when a real player would be looking at nameplates,
	# and `main.gd` sweeps every pick onto every unit as the countdown begins.
	#
	# ⚠️ `InputEventAction`, NOT `Input.action_press()`. `main.gd` reads the press in
	# `_unhandled_input(event)` via `event.is_action_pressed("ready_up")`, and
	# `Input.action_press` only moves the polled action state — it synthesises no event,
	# so the handler never runs. Measured: the first version of this probe pressed R and
	# the match sat at `round=0` forever.
	var press := InputEventAction.new()
	press.action = "ready_up"
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().create_timer(8.0).timeout

	_report(get_tree().current_scene)
	# ⚠️ TWICE, SIX SECONDS APART. A value that is wrong once and right later is a
	# late-arrival ORDERING bug; one that is wrong in both is a value that never crossed
	# at all. Telling those two apart decides where the fix belongs, and a single sample
	# cannot.
	await get_tree().create_timer(6.0).timeout
	_say("-- second look --")
	_report(get_tree().current_scene)
	get_tree().quit()

## THE SECOND HALF OF THE SAME BUG, GIVEN A BODY TO SIT IN. `is_spectator()` reads the
## same `peer_characters` the names do, so before the broadcast a CLIENT answered `false`
## for everybody no matter who was watching — and every count built on it
## (`playing_peer_count`, `seated_peer_ids`, `match_result.gd`'s rematch denominator) was
## wrong on every peer except the host.
##
## Deliberately does NOT go through the lobby screen — same reasoning
## `pool_free_check.gd::_be_a_spectator` states: this is a body in a chair, not a UI test,
## and the fewer moving parts holding the seat open the better. Bounded: it quits itself.
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

## ⚠️ THE REFEREE HAS TO BE INSTRUMENTED TOO, AND IT CANNOT BE A SEPARATE PROCESS SHAPE.
## The whole question is whether the value is right on the host and lost on the way out,
## or never right anywhere — and the deployed server is a `MatchSetup.tscn --dedicated`
## process that prints nothing. This role hands that exact scene the exact same command
## line (`_read_dedicated_args` reads `OS.get_cmdline_user_args()`, which still carries
## `--dedicated --port=`), and then watches it from beside it.
##
## Bounded: it prints on a fixed schedule and quits itself. A referee that outlived the
## run would hold the port, and the next run's client would then be talking to the
## previous build — which Godot reports as `The rpc node checksum failed` and which looks
## exactly like a code bug.
func _be_the_server() -> void:
	var screen: Node = load(SETUP).instantiate()
	get_tree().root.add_child.call_deferred(screen) # root is still setting THIS node up
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

## Every body in the world, with the name this peer would draw over it. `display_name()`
## is the one function the nameplate, the scoreboard, the YOU card and the result screen
## all call, so printing it is printing what a player sees rather than a proxy for it.
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
