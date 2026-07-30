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

## ---------------------------------------------------------------------------
## R-26 · FOUR PEERS, A MID-LOBBY DISCONNECT, AND A JOIN DURING THE READY WINDOW
##
## The 21 assertions above ran on TWO instances and every one of them still runs
## here — that is the acceptance, not a separate four-peer probe that re-asserts
## a subset. What two peers cannot cover:
##
##   * SEAT EXCLUSIVITY WITH CONTENTION. With one client there is never a race:
##     it asks for seat 0, is refused, takes 2, done. With three clients asking
##     at once the referee has to hand out four DISTINCT seats, and only the host
##     can see that — a client knows its own seat and nothing else. So the
##     distinctness assertion lives on the host and is new.
##   * A PEER LEAVING THE LOBBY. Nothing anywhere asserts that its seat comes
##     back, and a seat leaked on disconnect means the next joiner is refused a
##     chair that nobody is sitting in.
##   * A JOIN THAT ARRIVES AFTER EVERYONE ELSE IS READY. The ready flags are
##     agreement to play a specific match with a specific set of players; a peer
##     appearing after that agreement either has to clear it or the match starts
##     with somebody who never agreed to it.
##
## USAGE — the host must be started FIRST and must OUTLIVE every client.
##
##   godot --path . -s tools/lobby_probe.gd -- host peers=4
##   godot --path . -s tools/lobby_probe.gd -- join 127.0.0.1 seat=1
##   godot --path . -s tools/lobby_probe.gd -- join 127.0.0.1 seat=2
##   godot --path . -s tools/lobby_probe.gd -- join 127.0.0.1 seat=3
##
##   `leaveat=N`  this client quits the lobby N seconds in, without readying.
##                The host then expects one fewer peer and asserts the seat freed.
##   `holdready`  this client never presses ready — for the late-join case, where
##                the point is that the OTHERS were ready before it arrived.
##
## ⚠️ `join` IS STILL THE ROLE WORD. Three clients differ by `seat=`, not by
## three new role names, so every client runs the SAME beats and a divergence
## between them is a real one rather than three scripts drifting apart.
## ---------------------------------------------------------------------------

## How many peers the host waits for, including itself. 2 keeps every existing
## two-instance invocation working unchanged.
var _want_peers: int = 2
## Which seat this client asks for. The historical single client took 2.
var _want_seat: int = 2
## Seconds after which this client leaves the lobby, or -1 to stay.
var _leave_at: float = -1.0
## True for a client that must not press ready.
var _hold_ready: bool = false
## Set on the host once a peer has actually been seen and then lost.
var _seen_peak_peers: int = 0
## How many clients were launched with `leaveat=`, stated on the HOST's command
## line. Zero keeps every existing invocation unchanged.
var _want_leavers: int = 0
## R-26 · set on the HOST with `latejoin`, when one client is deliberately
## started after everyone else has readied and never readies itself. It INVERTS
## the START expectation: the gate must still be shut.
var _late_join: bool = false

## ⚠️ EVERY HOST BEAT SLIDES WHEN THERE ARE MORE PEERS, AND THE FIRST FOUR-PEER
## RUN PROVED WHY — twice, in two different ways, and neither was a game defect:
##
##   * the host asserted "4 peers connected" at t 2.5 while the third client was
##     still launching (they are started a second apart so four ENet handshakes
##     do not land in one frame), and reported 2;
##   * the host moved the difficulty selector at t 5.5, which on the wall clock
##     is BEFORE the second and third clients take their welcome-packet look at
##     their own t 2.5 — so both of them correctly read the value the host had
##     already changed it to, and the probe called that a failed welcome packet.
##
## The second one is the dangerous kind: it looks exactly like "the welcome
## packet only works for the first joiner", which is a real bug someone would
## then go hunting for. Both are the schedule, and the schedule now scales.
##
## ⚠️ AND THE CLIENT'S **FIRST** LOOK DELIBERATELY DOES NOT SLIDE. It is the
## welcome-packet assertion, and it is only a welcome-packet assertion while it
## happens BEFORE the host touches the selector — sliding it with everything else
## put it after, and all three clients then failed the sync_config check instead.
## Every later client beat slides; that one is pinned. Both orderings have now
## been run and both failure modes observed, which is the only reason this
## comment can state which way round it goes.
##
## ⚠️ CLIENTS NEED `peers=` TOO, for exactly that reason — a client that does not
## know how many peers there are cannot stay in step with a host that does.
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
	# Kept: the historical positional third argument.
	if args.size() > 2 and not String(args[2]).contains("="):
		_shot_dir = args[2]
	if _role != "host":
		_role = "join%d" % _want_seat

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
		# NET-5 / R-09's remaining acceptance. Deliberately opposite tiers, same reason
		# the map and mode are: a pass has to mean the value TRAVELLED, not that both
		# peers happened to agree already. `persist` false — a probe must not write the
		# human's settings.cfg. Labels are EASY / NORMAL / HARD; index order unchanged.
		_settings().call("set_ai_difficulty", TIER_HARD, false)
	else:
		gl.set("pending_action", "join")
		gl.set("pending_join_address", _address)
		# Deliberately the OTHER map and mode, so "the client ends up on the
		# host's" cannot pass by both sides happening to agree already.
		gl.set("selected_map", &"eskinita")
		gl.set("game_mode", MODE_CAPTURE)
		gl.set("selected_slipper", &"goma")
		_settings().call("set_ai_difficulty", TIER_EASY, false)
	change_scene_to_file(SETUP_PATH)

## ⚠️ NET-5 — THE VALUE RIDES TWO CALL SITES AND BOTH MATTER.
##
## `_rpc_sync_config` is the host CHANGING something; `_rpc_sync_state` is the WELCOME
## packet, and it is the only thing that configures a peer joining a lobby nobody touches
## afterwards. Asserting only the first passes while a client that joined a quiet lobby
## silently keeps its own tier — and per-peer match-affecting values are the U-8 bug class,
## fixed twice. It fails silently: each peer's bots play at that peer's setting and only the
## host's actually decide the match.
##
## So there are two checks below, in this order:
##   * on the client's FIRST look, before anything in the lobby has been touched — that is
##     the welcome packet and nothing else;
##   * again after the host walks the difficulty selector, which is the sync_config path.
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

# --- Host ---------------------------------------------------------------------

func _host_beats(screen: Node) -> bool:
	var seats_now: Dictionary = screen.get("_peer_seats")
	_seen_peak_peers = maxi(_seen_peak_peers, seats_now.size())
	if _stage == 0 and _t > _beat(2.5):
		_stage = 1
		# ⚠️ ONE FEWER IN THE LATE-JOIN CASE, BY DESIGN — the whole point of that
		# run is that the fourth peer is not here yet. Stated rather than
		# tolerated: an early count check that accepted any number would also
		# accept a peer that never arrived at all.
		var want_now: int = _want_peers - (1 if _late_join else 0)
		_check("%d peers connected at the opening look, got %d"
			% [want_now, seats_now.size()], seats_now.size() == want_now)
		_check("host holds seat 0", int(seats_now[1]) == 0)
	elif _stage == 1 and _t > _beat(5.5):
		_stage = 2
		var start_button := screen.get_node("%StartButton") as Button
		_check("START disabled while nobody is ready", start_button.disabled)
		# NET-5, call site 1 of 2: the host CHANGES the tier mid-lobby, which is the
		# `_rpc_sync_config` path.
		#
		# ⚠️ BEFORE ANY READY PRESS, AND THAT ORDERING IS LOAD-BEARING. Doing it after
		# reported "START live once every peer is ready" as a FAILURE — and the game was
		# right: `_rpc_sync_config` CLEARS EVERY READY FLAG on purpose, because readying up
		# is agreement to play a specific match and carrying the ticks through a picker
		# change would start a match nobody agreed to. Attributed by re-running the probe
		# without this press (green), not by reading the code first. The probe had to move,
		# not the game.
		#
		# ⚠️ AND AFTER THE CLIENT'S OWN FIRST LOOK. The client asserts the WELCOME packet
		# at its t>2.5, which is ~4.5s on this clock (the two instances are launched two
		# seconds apart and do not share a clock — see `_transition_t`). Changing the tier
		# any earlier would have the client checking the welcome packet against a value the
		# host had already moved off, and the two call sites would stop being separable.
		#
		# ⚠️ PREV, NOT NEXT, AND THAT IS THE WHOLE DESIGN OF THIS STEP. NEXT from HARD wraps
		# to EASY — which is the CLIENT's own starting tier, so a client that ignored the
		# broadcast entirely would land on the expected value and pass. PREV lands on NORMAL,
		# which is neither peer's starting tier, so only a value that actually travelled can
		# produce it.
		(screen.get_node("%DifficultyPrevButton") as BaseButton).pressed.emit()
		_check("host moved its own tier to NORMAL (%d), got %d" % [TIER_NORMAL, _tier()],
			_tier() == TIER_NORMAL)
	elif _stage == 2 and _t > _beat(6.5):
		_stage = 3
		(screen.get_node("%PrimaryButton") as BaseButton).pressed.emit() # host readies
	elif _stage == 3 and _t > _beat(7.5):
		_stage = 4
		var start_button := screen.get_node("%StartButton") as Button
		_check("START still disabled — client not ready", start_button.disabled)
	elif _stage == 4 and _t > _beat(13.0) + (6.0 if _want_leavers > 0 else 0.0):
		_stage = 5
		# R-26 · THE MID-LOBBY DISCONNECT, asserted on the only side that can see
		# it. `leavers=N` says how many clients were launched with `leaveat=`, so
		# the expectation is stated on the command line rather than inferred from
		# whatever happened — a probe that concludes "however many are left is the
		# right number" cannot fail.
		#
		# ⚠️ THE SEAT IS THE POINT, NOT THE COUNT. A peer count that drops proves
		# ENet noticed; it does not prove the CHAIR came back, and a seat leaked
		# on disconnect refuses the next joiner a chair nobody is sitting in.
		# Both are checked, and they fail differently.
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
			# R-26 · A JOIN THAT ARRIVES AFTER EVERYONE ELSE IS READY.
			#
			# ⚠️ THE EXPECTATION IS INVERTED HERE AND THAT IS THE WHOLE TEST.
			# Readying up is agreement to play a specific match with a specific
			# set of players — `_rpc_sync_config` already clears every tick when
			# the HOST changes a picker, for exactly that reason. A peer walking
			# in afterwards is a bigger change to the match than a difficulty
			# tier is, so the gate must shut again rather than the newcomer being
			# swept into a match nobody re-agreed to.
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
		# Only when run WITH a rendering device (drop --headless); a headless run
		# writes a blank image, so it is skipped rather than producing a
		# screenshot that looks like a failure.
		if _shot_dir != "" and DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png(_shot_dir + "lobby_host.png")
			print("[lobby_probe/host] wrote lobby_host.png")
		var seats: Dictionary = screen.get("_peer_seats")
		_check("client moved to seat 2, host still 0",
			seats.values().has(2) and int(seats[1]) == 0)
		# R-26 · SEAT EXCLUSIVITY UNDER CONTENTION, and only the host can see it.
		# With three clients asking at once the referee has to hand out distinct
		# chairs; a client knows its own seat and nothing about anyone else's.
		var taken: Array = seats.values()
		var distinct := {}
		for s in taken:
			distinct[int(s)] = true
		_check("every seated peer holds a DISTINCT seat (%d peers, %d seats)"
			% [taken.size(), distinct.size()], taken.size() == distinct.size())
		start_button.pressed.emit()
	return false

# --- Client -------------------------------------------------------------------

func _client_beats(screen: Node) -> bool:
	# R-26 · THE MID-LOBBY DISCONNECT. Quitting the process IS the disconnect —
	# ENet notices a peer that stops answering, which is what a player closing
	# the game does, and it exercises the same path a Wi-Fi drop would. Checked
	# on the HOST, which is the only side that can see a seat come back.
	if _leave_at > 0.0 and _t > _leave_at:
		print("[lobby_probe/%s] leaving the lobby at %.1fs (seat %d)" % [_role, _t, _want_seat])
		quit(0)
		return true
	if _stage == 0 and _t > 2.5:
		_stage = 1
		_check("connected and seated", int(screen.call("_local_seat")) >= 0)
		# 1 — the whole point.
		_check("took the HOST's map, not its own",
			_gl().get("selected_map") == &"bayan_plaza")
		_check("took the HOST's mode, not its own",
			int(_gl().get("game_mode")) == MODE_DENTS)
		# NET-5, call site 2 of 2: nothing in this lobby has been touched yet, so the only
		# thing that can have set this is `_rpc_sync_state`'s welcome packet.
		_check("took the HOST's difficulty from the WELCOME packet (want %d, own start %d, got %d)"
			% [TIER_HARD, TIER_EASY, _tier()], _tier() == TIER_HARD)
		# 2
		_check("map arrows locked on a client",
			(screen.get_node("%MapNextButton") as BaseButton).disabled)
		_check("mode arrows locked on a client",
			(screen.get_node("%ModeNextButton") as BaseButton).disabled)
	elif _stage == 1 and _t > _beat(3.5):
		_stage = 2
		# 3a — ask for the seat the host is already in.
		(screen.get_node("%SeatButton0") as BaseButton).pressed.emit()
	elif _stage == 2 and _t > _beat(5.0):
		_stage = 3
		_check("refused the host's occupied seat", int(screen.call("_local_seat")) != 0)
		# 3b — take a free one. Which one is `seat=`, so three clients run these
		# same beats against three different chairs and any divergence between
		# them is a real one rather than three scripts having drifted apart.
		(screen.get_node("%%SeatButton%d" % _want_seat) as BaseButton).pressed.emit()
	elif _stage == 3 and _t > _beat(6.0):
		_stage = 4
		_check("granted the free seat it asked for (%d, got %d)"
			% [_want_seat, int(screen.call("_local_seat"))],
			int(screen.call("_local_seat")) == _want_seat)
		# NET-5, the sync_config half seen from the client. NORMAL is neither this peer's
		# starting tier (EASY) nor the one the welcome packet delivered (HARD), so it can
		# only be here because the host's change arrived.
		_check("followed the host's mid-lobby change to NORMAL (%d), got %d"
			% [TIER_NORMAL, _tier()], _tier() == TIER_NORMAL)
		if not _hold_ready:
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
	# NET-5 · the tier has to survive the transition into the match as well: this is the
	# value the bots actually play at, and it is read per peer.
	_check("difficulty survived into the match — NORMAL (%d), got %d, own start was %d"
		% [TIER_NORMAL, _tier(), TIER_HARD if _role == "host" else TIER_EASY],
		_tier() == TIER_NORMAL)
	var expected_seat := 0 if _role == "host" else _want_seat
	var seats: Dictionary = _gl().get("seat_tokens")
	var seat: int = int(seats.get(String(_nm().get("local_player_token")), -1))
	_check("seat survived into the match (expected %d, got %d)" % [expected_seat, seat],
		seat == expected_seat)
