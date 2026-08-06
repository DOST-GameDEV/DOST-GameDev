extends SceneTree

const SETUP_PATH: String = "res://scenes/ui/MatchSetup.tscn"
const MAIN_PATH: String = "res://scenes/main/Main.tscn"

var _role: String = "host"
var _address: String = "127.0.0.1"
var _t: float = 0.0
var _stage: int = 0
var _failures: PackedStringArray = []
var _started: bool = false
var _transition_t: float = -1.0
var _shot_dir: String = ""

func _gl() -> Node:
	return root.get_node("/root/GameLaunch")

func _nm() -> Node:
	return root.get_node("/root/NetworkManager")


var _want_peers: int = 2
var _want_seat: int = 2
var _leave_at: float = -1.0
var _hold_ready: bool = false
var _seen_peak_peers: int = 0
var _want_leavers: int = 0
var _late_join: bool = false

func _beat(at: float) -> float:
	return at + float(maxi(_want_peers - 2, 0)) * 2.5

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_role = args[0]
	if args.size() > 1 and not String(args[1]).contains("="):
		_address = args[1]
	for arg in args:
		var token := String(arg)
		if token.begins_with("peers="):
			_want_peers = int(token.substr(6))
		elif token.begins_with("seat="):
			_want_seat = int(token.substr(5))
		elif token.begins_with("leaveat="):
			_leave_at = float(token.substr(8))
		elif token.begins_with("leavers="):
			_want_leavers = int(token.substr(8))
		elif token == "latejoin":
			_late_join = true
		elif token == "holdready":
			_hold_ready = true
		elif token.begins_with("shot="):
			_shot_dir = token.substr(5)
	if args.size() > 2 and not String(args[2]).contains("="):
		_shot_dir = args[2]
	if _role != "host":
		_role = "join%d" % _want_seat

func _begin() -> void:
	_started = true
	var gl := _gl()
	gl.call("clear_seating")
	if _role == "host":
		gl.set("pending_action", "host")
		gl.set("selected_map", &"bayan_plaza")
		gl.set("selected_slipper", &"bakya")
		_settings().call("set_ai_difficulty", TIER_HARD, false)
	else:
		gl.set("pending_action", "join")
		gl.set("pending_join_address", _address)
		gl.set("selected_map", &"eskinita")
		gl.set("selected_slipper", &"goma")
		_settings().call("set_ai_difficulty", TIER_EASY, false)
	change_scene_to_file(SETUP_PATH)

const TIER_EASY: int = 0
const TIER_NORMAL: int = 1
const TIER_HARD: int = 2

func _settings() -> Node:
	return root.get_node("/root/SettingsManager")

func _tier() -> int:
	return int(_settings().get("ai_difficulty"))

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


func _host_beats(screen: Node) -> bool:
	var seats_now: Dictionary = screen.get("_peer_seats")
	_seen_peak_peers = maxi(_seen_peak_peers, seats_now.size())
	if _stage == 0 and _t > _beat(2.5):
		_stage = 1
		var want_now: int = _want_peers - (1 if _late_join else 0)
		_check("%d peers connected at the opening look, got %d"
			% [want_now, seats_now.size()], seats_now.size() == want_now)
		_check("host holds seat 0", int(seats_now[1]) == 0)
	elif _stage == 1 and _t > _beat(5.5):
		_stage = 2
		var start_button := screen.get_node("%StartButton") as Button
		_check("START disabled while nobody is ready", start_button.disabled)
		(screen.get_node("%DifficultyPrevButton") as BaseButton).pressed.emit()
		_check("host moved its own tier to NORMAL (%d), got %d" % [TIER_NORMAL, _tier()],
			_tier() == TIER_NORMAL)
	elif _stage == 2 and _t > _beat(6.5):
		_stage = 3
		(screen.get_node("%PrimaryButton") as BaseButton).pressed.emit()
	elif _stage == 3 and _t > _beat(7.5):
		_stage = 4
		var start_button := screen.get_node("%StartButton") as Button
		_check("START still disabled — client not ready", start_button.disabled)
	elif _stage == 4 and _t > _beat(13.0) + (6.0 if _want_leavers > 0 else 0.0):
		_stage = 5
		if _want_leavers > 0:
			var left: int = _seen_peak_peers - seats_now.size()
			_check("%d peer(s) left the lobby and the host noticed (peak %d, now %d)"
				% [_want_leavers, _seen_peak_peers, seats_now.size()],
				left == _want_leavers)
			var freed: Array = []
			for seat in range(4):
				if not seats_now.values().has(seat):
					freed.append(seat)
			_check("the leaver's seat came back — %d free chair(s), expected %d"
				% [freed.size(), _want_leavers], freed.size() == _want_leavers)
		var start_button := screen.get_node("%StartButton") as Button
		if _late_join:
			_check("a late joiner is seated (%d peers)" % seats_now.size(),
				seats_now.size() == _want_peers)
			_check("START is SHUT again — someone arrived after the others readied",
				start_button.disabled)
			print("RESULT[%s]: %s" % [_role,
				"LOBBY OK" if _failures.is_empty()
				else "%d FAILED — %s" % [_failures.size(), ", ".join(_failures)]])
			quit(1 if _failures.size() > 0 else 0)
			return true
		_check("START live once every REMAINING peer is ready", not start_button.disabled)
		if _shot_dir != "" and DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png(_shot_dir + "lobby_host.png")
			print("[lobby_probe/host] wrote lobby_host.png")
		var seats: Dictionary = screen.get("_peer_seats")
		_check("client moved to seat 2, host still 0",
			seats.values().has(2) and int(seats[1]) == 0)
		var taken: Array = seats.values()
		var distinct := {}
		for s in taken:
			distinct[int(s)] = true
		_check("every seated peer holds a DISTINCT seat (%d peers, %d seats)"
			% [taken.size(), distinct.size()], taken.size() == distinct.size())
		start_button.pressed.emit()
	return false


func _client_beats(screen: Node) -> bool:
	if _leave_at > 0.0 and _t > _leave_at:
		print("[lobby_probe/%s] leaving the lobby at %.1fs (seat %d)" % [_role, _t, _want_seat])
		quit(0)
		return true
	if _stage == 0 and _t > 2.5:
		_stage = 1
		_check("connected and seated", int(screen.call("_local_seat")) >= 0)
		_check("took the HOST's map, not its own",
			_gl().get("selected_map") == &"bayan_plaza")
		_check("took the HOST's difficulty from the WELCOME packet (want %d, own start %d, got %d)"
			% [TIER_HARD, TIER_EASY, _tier()], _tier() == TIER_HARD)
		_check("map arrows locked on a client",
			(screen.get_node("%MapNextButton") as BaseButton).disabled)
	elif _stage == 1 and _t > _beat(3.5):
		_stage = 2
		(screen.get_node("%SeatButton0") as BaseButton).pressed.emit()
	elif _stage == 2 and _t > _beat(5.0):
		_stage = 3
		_check("refused the host's occupied seat", int(screen.call("_local_seat")) != 0)
		(screen.get_node("%%SeatButton%d" % _want_seat) as BaseButton).pressed.emit()
	elif _stage == 3 and _t > _beat(6.0):
		_stage = 4
		_check("granted the free seat it asked for (%d, got %d)"
			% [_want_seat, int(screen.call("_local_seat"))],
			int(screen.call("_local_seat")) == _want_seat)
		_check("followed the host's mid-lobby change to NORMAL (%d), got %d"
			% [TIER_NORMAL, _tier()], _tier() == TIER_NORMAL)
		if not _hold_ready:
			(screen.get_node("%PrimaryButton") as BaseButton).pressed.emit()
	return false


const HOST_LINGER: float = 5.0

var _checked: bool = false
var _checked_t: float = 0.0

func _after_transition(screen: Node) -> bool:
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
	_check("difficulty survived into the match — NORMAL (%d), got %d, own start was %d"
		% [TIER_NORMAL, _tier(), TIER_HARD if _role == "host" else TIER_EASY],
		_tier() == TIER_NORMAL)
	var expected_seat := 0 if _role == "host" else _want_seat
	var seats: Dictionary = _gl().get("seat_tokens")
	var seat: int = int(seats.get(String(_nm().get("local_player_token")), -1))
	_check("seat survived into the match (expected %d, got %d)" % [expected_seat, seat],
		seat == expected_seat)

