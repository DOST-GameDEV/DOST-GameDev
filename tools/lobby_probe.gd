extends SceneTree
## Two-instance verification of the multiplayer lobby, end to end.
##
##   godot --path . -s tools/lobby_probe.gd -- host
##   godot --path . -s tools/lobby_probe.gd -- join 127.0.0.1
##
## Run the host first, the client a second later; both print a `RESULT:` line
## and exit non-zero on failure, so a shell can gate on them. What it proves,
## and why each one is here rather than reasoned about:
##
##   1. THE CLIENT RECEIVES THE HOST'S MAP AND MODE. This is the defect the
##      whole overhaul exists to close — `main.gd::_load_map()` reads
##      `GameLaunch.selected_map_scene()` locally on every peer and nothing used
##      to synchronise it, so two peers loaded two different arenas (recorded in
##      the old `lobby.gd` and `Checklist.md` 10.4). The client here starts on a
##      DELIBERATELY WRONG map and mode, so a pass cannot be an accident of both
##      sides defaulting to the same thing.
##   2. THE CLIENT CANNOT CHANGE THEM. Host privilege is enforced on the control
##      itself, not only by the host ignoring a stray RPC.
##   3. SEATS ARE EXCLUSIVE AND REFEREED. The client asks for the seat the host
##      is already sitting in and must be refused, then takes a free one and
##      must get it — on BOTH boards.
##   4. THE READY GATE HOLDS. The host's START stays disabled while any seated
##      peer is un-ready, and only then goes live.
##   5. START ACTUALLY LANDS BOTH PEERS IN THE MATCH, on the same map, with the
##      seating each of them chose — checked after the scene change, which is
##      why this is a SceneTree script: a probe NODE is freed by
##      `change_scene_to_file()`, which is half of what is being tested.

const SETUP_PATH: String = "res://scenes/ui/MatchSetup.tscn"
const MAIN_PATH: String = "res://scenes/main/Main.tscn"
## GameLaunchScript.GameMode's two values, as literals. ⚠️ Deliberately NOT
## `GameLaunch.GameMode.OPTION_A`: a `-s` SceneTree script is compiled to BECOME
## the main loop, which happens before the autoload singletons are registered as
## GDScript globals, so any compile-time reference to one fails the whole script
## with "Identifier not found: GameLaunch" before a line of it runs. Every
## autoload here is therefore resolved by node path at runtime instead — see
## `_gl()` / `_nm()`.
const MODE_CAPTURE: int = 0
const MODE_DENTS: int = 1

var _role: String = "host"
var _address: String = "127.0.0.1"
var _t: float = 0.0
var _stage: int = 0
var _failures: PackedStringArray = []
var _started: bool = false
## ⚠️ THE TWO INSTANCES DO NOT SHARE A CLOCK — the client is launched a couple
## of seconds after the host, so `_t` means different wall-clock moments on each
## side. Beats are spaced wide enough that the client's slower clock still lands
## its ready press before the host looks for it; a tighter schedule reported the
## ready gate as broken when it was only early.
var _transition_t: float = -1.0
## Optional third argument: where to write a screenshot of the fully-seated,
## fully-ready lobby. Empty (the default) writes nothing.
var _shot_dir: String = ""

func _gl() -> Node:
	return root.get_node("/root/GameLaunch")

func _nm() -> Node:
	return root.get_node("/root/NetworkManager")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_role = args[0]
	if args.size() > 1:
		_address = args[1]
	if args.size() > 2:
		_shot_dir = args[2]

## Deferred out of `_initialize()` for the same reason the enum above is a
## literal: the autoloads are not in the tree yet when a `-s` main loop
## initialises, so the very first `_process` tick is the earliest point at which
## GameLaunch can be written to at all.
func _begin() -> void:
	_started = true
	var gl := _gl()
	gl.call("clear_seating")
	if _role == "host":
		gl.set("pending_action", "host")
		gl.set("selected_map", &"bayan_plaza")
		gl.set("game_mode", MODE_DENTS)
		gl.set("selected_slipper", &"bakya")
	else:
		gl.set("pending_action", "join")
		gl.set("pending_join_address", _address)
		# Deliberately the OTHER map and mode, so "the client ends up on the
		# host's" cannot pass by both sides happening to agree already.
		gl.set("selected_map", &"eskinita")
		gl.set("game_mode", MODE_CAPTURE)
		gl.set("selected_slipper", &"goma")
	change_scene_to_file(SETUP_PATH)

func _check(label: String, ok: bool) -> void:
	print("[lobby_probe/%s] %-46s %s" % [_role, label, "ok" if ok else "*** FAIL ***"])
	if not ok:
		_failures.append(label)

func _process(delta: float) -> bool:
	if not _started:
		_begin()
		return false
	_t += delta
	var screen := current_scene
	if screen == null:
		return false
	if screen.scene_file_path != SETUP_PATH:
		if _transition_t < 0.0:
			_transition_t = _t
		return _after_transition(screen)
	return _host_beats(screen) if _role == "host" else _client_beats(screen)

# --- Host ---------------------------------------------------------------------

func _host_beats(screen: Node) -> bool:
	if _stage == 0 and _t > 2.5:
		_stage = 1
		_check("client connected", screen.get("_peer_seats").size() == 2)
		_check("host holds seat 0", int(screen.get("_peer_seats")[1]) == 0)
	elif _stage == 1 and _t > 4.0:
		_stage = 2
		var start_button := screen.get_node("%StartButton") as Button
		_check("START disabled while nobody is ready", start_button.disabled)
		(screen.get_node("%PrimaryButton") as BaseButton).pressed.emit() # host readies
	elif _stage == 2 and _t > 5.0:
		_stage = 3
		var start_button := screen.get_node("%StartButton") as Button
		_check("START still disabled — client not ready", start_button.disabled)
	elif _stage == 3 and _t > 12.0:
		_stage = 4
		var start_button := screen.get_node("%StartButton") as Button
		_check("START live once every peer is ready", not start_button.disabled)
		# Only when run WITH a rendering device (drop --headless); a headless run
		# writes a blank image, so it is skipped rather than producing a
		# screenshot that looks like a failure.
		if _shot_dir != "" and DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png(_shot_dir + "lobby_host.png")
			print("[lobby_probe/host] wrote lobby_host.png")
		var seats: Dictionary = screen.get("_peer_seats")
		_check("client moved to seat 2, host still 0",
			seats.values().has(2) and int(seats[1]) == 0)
		start_button.pressed.emit()
	return false

# --- Client -------------------------------------------------------------------

func _client_beats(screen: Node) -> bool:
	if _stage == 0 and _t > 2.5:
		_stage = 1
		_check("connected and seated", int(screen.call("_local_seat")) >= 0)
		# 1 — the whole point.
		_check("took the HOST's map, not its own",
			_gl().get("selected_map") == &"bayan_plaza")
		_check("took the HOST's mode, not its own",
			int(_gl().get("game_mode")) == MODE_DENTS)
		# 2
		_check("map arrows locked on a client",
			(screen.get_node("%MapNextButton") as BaseButton).disabled)
		_check("mode arrows locked on a client",
			(screen.get_node("%ModeNextButton") as BaseButton).disabled)
	elif _stage == 1 and _t > 3.5:
		_stage = 2
		# 3a — ask for the seat the host is already in.
		(screen.get_node("%SeatButton0") as BaseButton).pressed.emit()
	elif _stage == 2 and _t > 5.0:
		_stage = 3
		_check("refused the host's occupied seat", int(screen.call("_local_seat")) != 0)
		# 3b — take a free one.
		(screen.get_node("%SeatButton2") as BaseButton).pressed.emit()
	elif _stage == 3 and _t > 6.0:
		_stage = 4
		_check("granted the free seat it asked for", int(screen.call("_local_seat")) == 2)
		(screen.get_node("%PrimaryButton") as BaseButton).pressed.emit() # client readies
	return false

# --- Both, after the host presses START ---------------------------------------

## ⚠️ THE HOST MUST OUTLIVE THE CLIENT'S OWN CHECKS. Quitting the instant the
## host is satisfied drops the server; the client's `main.gd` correctly handles
## that by bouncing to MultiplayerSetup, and the client then reports "did not
## reach the match scene" — the probe tearing down the thing it is measuring
## rather than a defect. Reported as exactly that once, hence the linger.
const HOST_LINGER: float = 5.0

var _checked: bool = false
var _checked_t: float = 0.0

func _after_transition(screen: Node) -> bool:
	# Measured from OUR OWN transition, not from launch — see `_transition_t`.
	# One beat so main.gd's own _ready() has run and spawned.
	if _t - _transition_t < 2.5:
		return false
	if not _checked:
		_checked = true
		_checked_t = _t
		_run_final_checks(screen)
		if _failures.is_empty():
			print("RESULT[%s]: LOBBY OK" % _role)
		else:
			print("RESULT[%s]: %d FAILED — %s" % [_role, _failures.size(), ", ".join(_failures)])
	if _role == "host" and _t - _checked_t < HOST_LINGER:
		return false
	quit(1 if _failures.size() > 0 else 0)
	return true

func _run_final_checks(screen: Node) -> void:
	_check("reached the match scene", screen.scene_file_path == MAIN_PATH)
	_check("both peers on the host's map",
		String(_gl().call("selected_map_scene")) == "res://scenes/maps/BayanPlaza.tscn")
	var expected_seat := 0 if _role == "host" else 2
	var seats: Dictionary = _gl().get("seat_tokens")
	var seat: int = int(seats.get(String(_nm().get("local_player_token")), -1))
	_check("seat survived into the match (expected %d, got %d)" % [expected_seat, seat],
		seat == expected_seat)
