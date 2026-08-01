extends Node
## Two real peers, one match, and a diff of what each end believes.
## Written 2026-08-01, branch `HARRYDAKS`, for § CHECKLIST §1.8.
##
## ⚠️ WHY THIS EXISTS. Nothing on this branch had ever run on two peers, and every
## scoring, contact and rotation path resolves HOST-SIDE — so on one machine they are
## untested by definition and a failure in any of them is invisible in Single Player.
## The demo is recorded in multiplayer with four people in a room.
##
## ⚠️ IT DOES NOT SYNTHESISE INPUT, AND THAT IS THE POINT. The unclaimed seats are
## bot-filled by `main.gd`, and the bots retrieve, throw, tag and score on their own.
## Driving the match by hand would test the harness; letting it play tests the game.
##
## ⚠️ WHY `aim_probe.gd` WAS COPIED RATHER THAN RUN. Its `--host`/`--join` harness is
## the right shape — instantiate `Main.tscn` at `/root/Main`, press READY, linger on
## the host — but its assertions are all about `lucky_fall_chance`, `RoundManager.
## can_fell` and `hitbox.gd`, three things the pivot deleted (§2.10: every probe in
## `tools/` is stale). The scaffolding is salvage; the measurements are new.
##
## HOW IT IS RUN — two processes, plain exe, second one a few seconds later:
##
##     Godot_v4.7.1-stable_win64_console.exe --path <repo> tools/ui/net_twopeer_probe.tscn \
##         -- --host --secs=120 --out=<dir>/host_
##     Godot_v4.7.1-stable_win64_console.exe --path <repo> tools/ui/net_twopeer_probe.tscn \
##         -- --join=127.0.0.1 --secs=120 --out=<dir>/client_
##
## `--host` and `--join=` are ALSO read by `main.gd` itself (`_boot_network()`), which
## is what actually opens the ENet socket — this probe only needs to pass them through
## by not consuming them.
##
## WHAT TO DIFF. Every line the two peers must agree on is prefixed `[EV]` (an ordered
## causal event stream) or `[FIN]` (the end-state snapshot). Everything else is
## `[INFO]` and is peer-local by nature — peer ids, wall-clock timings, frame counts.
##
##     grep -E '^\[(EV|FIN)\]' host.log   > host.diffable
##     grep -E '^\[(EV|FIN)\]' client.log > client.diffable
##     diff host.diffable client.diffable
##
## ⚠️ TIMESTAMPS ARE DELIBERATELY ABSENT FROM `[EV]`. Two peers do not process the same
## frame at the same wall-clock instant and never will; a timestamp in the diffable
## stream would report replication latency as a desync every single run. What must
## match is the ORDER and the CONTENT, which is what a causal stream is.
##
## ⚠️ AND THE STREAM FREEZES ON A CAUSAL MARKER, NOT ON THE CLOCK — `STOP_AT_ROUND`.
## THE FIRST RUN OF THIS PROBE GOT THIS WRONG and reported a desync that was not one:
## the host lingers 8 s past the client, so it recorded 2 further tags and 8 further
## DEFENSE ticks the client had legitimately not seen yet, and the two `[FIN] scores`
## lines differed by exactly 280 = 200 + 80. That is the probe measuring its own
## shutdown skew. Both peers now stop recording — and snapshot — the instant round
## `STOP_AT_ROUND` starts, which is the same causal point on both machines however far
## apart in wall-clock terms it lands, and they may then exit whenever they like.

const MAIN_SCENE_PATH: String = "res://scenes/main/Main.tscn"

## Seconds to wait after `Main` is in the tree before pressing READY. The socket has to
## connect and all four seats have to settle first.
const CONNECT_WAIT: float = 6.0
## How long the host lingers past its own deadline. When the host drops, every client
## tears its match down and prints nothing — so the host must outlive the client.
const HOST_LINGER: float = 8.0

## Recording stops the instant this round starts — the causal freeze. See the header.
const STOP_AT_ROUND: int = 2

var _is_host := false
var _frozen := false
## The snapshot, taken at the freeze rather than at quit so the two peers describe the
## same instant of the match instead of the same instant of the wall clock.
var _snapshot: Array[String] = []
var _run_secs := 120.0
var _out := ""
var _tag := "?"
var _main: Node = null

## The ordered causal stream both peers must reproduce identically.
var _events: Array[String] = []
## DEFENSE ticks every single second of every round (Design.md §8). Logging each one
## individually would bury the stream in 90 identical lines per round AND make it
## timing-sensitive, so it is counted and reported as a total instead.
var _defense_ticks := 0
var _defense_points := 0
var _shots := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var token := String(arg)
		if token == "--host":
			_is_host = true
		elif token.begins_with("--secs="):
			_run_secs = float(token.substr(len("--secs=")))
		elif token.begins_with("--out="):
			_out = token.substr(len("--out="))
	_tag = "HOST" if _is_host else "CLIENT"

	# ⚠️ `Main` MUST LIVE AT `/root/Main` ON EVERY PEER. The spawner and every
	# MultiplayerSynchronizer address nodes by PATH, so a probe that parents the match
	# under itself desyncs on frame one. Same reason `net_spawn_probe` and `hit_probe`
	# both do it this way.
	_main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	_main.name = "Main"
	get_tree().root.add_child.call_deferred(_main)
	await get_tree().process_frame
	get_tree().current_scene = _main

	_subscribe()
	_run.call_deferred()


## Every hook is a signal on an autoload, so both peers subscribe to the same set and
## no file outside this lane is touched to make the probe work.
func _subscribe() -> void:
	MatchManager.round_started.connect(_on_round_started)
	MatchManager.round_intermission_started.connect(_on_intermission)
	MatchManager.match_won.connect(_on_match_won)
	MatchManager.score_changed.connect(_on_score_changed)
	RoundManager.lata_knocked.connect(_on_lata_knocked)
	RoundManager.lata_restored.connect(_on_lata_restored)
	RoundManager.attacker_tagged.connect(_on_tagged)
	RoundManager.round_ended.connect(_on_round_ended)


func _run() -> void:
	_info("peer_id=%d  args=%s" % [multiplayer.get_unique_id(),
		str(OS.get_cmdline_user_args())])
	await get_tree().create_timer(CONNECT_WAIT).timeout
	_info("connected=%s  is_host=%s  peers=%s" % [
		str(NetworkManager.is_networked()), str(NetworkManager.is_host()),
		str(NetworkManager.connected_peer_ids)])

	await _ready_up()
	_info("round_active=%s after ready phase" % [str(RoundManager.round_active)])

	# Sample the clock rather than sleeping blind, so a run that never starts a round
	# reports that fact instead of a silent wall of zeroes.
	var elapsed := 0.0
	var next_shot := 8.0
	while elapsed < _run_secs:
		await get_tree().create_timer(1.0).timeout
		elapsed += 1.0
		_sample_travel()
		if _out != "" and elapsed >= next_shot and _shots < 3:
			next_shot += 45.0
			await _capture("%02d_t%03d" % [_shots + 1, int(elapsed)])
			_dump_anim(int(elapsed))
			_shots += 1

	if _is_host:
		_info("host lingering %.1fs so the client can finish and report" % [HOST_LINGER])
		await get_tree().create_timer(HOST_LINGER).timeout

	_report()
	get_tree().quit(0)


## Sends READY until the host says the phase is over. Polled rather than driven off a
## signal because `_awaiting_net_ready` is only set once the host's own
## `_rpc_ready_phase` has arrived, which may be after this probe's first look — the
## exact race `aim_probe` documents.
func _ready_up() -> void:
	for _attempt in 60:
		if RoundManager.round_active:
			return
		if bool(_main.get("_awaiting_net_ready")):
			_main._rpc_declare_ready.rpc_id(1)
		elif bool(_main.get("_counting_down")):
			pass
		await get_tree().create_timer(0.5).timeout
	_info("⚠️ never reached a live round — the ready phase did not complete")


# ── the causal stream ────────────────────────────────────────────────────────────

func _ev(line: String) -> void:
	if _frozen:
		return
	_events.append(line)


## ⚠️ THE FREEZE IS TAKEN *BEFORE* THE MARKER EVENT IS RECORDED, so the stream ends
## with `round_started round=STOP_AT_ROUND` on both peers rather than one of them
## catching an extra event that arrived in the same frame.
func _on_round_started(round_number: int, defender_slot: int) -> void:
	_ev("round_started round=%d defender=%d" % [round_number, defender_slot])
	if round_number >= STOP_AT_ROUND and not _frozen:
		_freeze()


func _freeze() -> void:
	if _frozen:
		return
	_snapshot = _build_snapshot()
	_frozen = true
	_info("stream frozen at round %d — %d events recorded" % [STOP_AT_ROUND, _events.size()])


func _on_round_ended(round_number: int) -> void:
	_ev("round_ended round=%d" % [round_number])


func _on_intermission(next_round: int, next_defender: int) -> void:
	_ev("intermission next_round=%d next_defender=%d" % [next_round, next_defender])


func _on_match_won(winning_slot: int) -> void:
	_ev("match_won winner=%d" % [winning_slot])


## ⚠️ DEFENSE IS AGGREGATED, EVERY OTHER REASON IS LOGGED. See `_defense_ticks`.
func _on_score_changed(slot: int, total: int, delta: int, reason: String) -> void:
	if reason == "DEFENSE":
		if _frozen:
			return
		_defense_ticks += 1
		_defense_points += delta
		return
	_ev("score slot=%d delta=%+d total=%d reason=%s" % [slot, delta, total, reason])


func _on_lata_knocked(by_slot: int) -> void:
	_ev("lata_knocked by=%d" % [by_slot])


func _on_lata_restored() -> void:
	_ev("lata_restored")


func _on_tagged(defender_slot: int, victim_slot: int) -> void:
	_ev("tagged defender=%d victim=%d" % [defender_slot, victim_slot])


# ── output ───────────────────────────────────────────────────────────────────────

func _info(line: String) -> void:
	print("[INFO][%s] %s" % [_tag, line])


func _capture(name: String) -> void:
	# Two waits, not one: `get_texture()` returns the texture the GPU has finished
	# with, so a single wait after a state change captures the frame BEFORE it.
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s%s.png" % [_out, name]
	var err := image.save_png(path)
	print("[INFO][%s] shot %s -> %s (%dx%d)" % [_tag, name,
		path if err == OK else "FAILED", image.get_width(), image.get_height()])


## ⚠️ THE ANIMATION CLAIM IS MEASURED, NOT EYEBALLED. "Some of them were just stuck in
## jump position" is a report about `AnimationPlayer.current_animation`, and a
## screenshot of a low-poly figure is a poor instrument for it — a crouched pose and a
## seated one are four pixels apart at arena distance. This prints, per character and
## per peer: whether THIS peer simulates it, what the physics says, what the observer
## derived, and which clip is actually playing. `[ANIM]` rather than `[EV]`/`[FIN]`
## because it is a live sample, not something the two peers must match exactly.
func _dump_anim(at_secs: int) -> void:
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		var visual: Node = who.get_node_or_null("Visual")
		var clip := "?"
		var observed := "?"
		if visual != null:
			var player: AnimationPlayer = visual.get("_animator")
			if player != null:
				# ⚠️ `is_playing()` AND `_charge_posing` MATTER AS MUCH AS THE CLIP NAME.
				# `_drive_charge_pose()` calls `_animator.pause()` and returns out of
				# `_play_locomotion()` while it holds — a stuck charge pose freezes the
				# rig mid-frame and looks identical to a wrong clip selection.
				clip = "%s%s pose=%s" % [player.current_animation,
					"" if player.is_playing() else " PAUSED",
					str(bool(visual.get("_charge_posing")))]
			observed = "%.2f,%.2f air=%.2f" % [
				Vector2(float(visual.get("_observed_velocity").x),
					float(visual.get("_observed_velocity").z)).length(),
				float(visual.get("_observed_velocity").y),
				float(visual.get("_observed_airborne_left"))]
		print("[ANIM][%s] t=%d P%d mine=%s on_floor=%s vel=%.2f obs=%s clip=%s"
			% [_tag, at_secs, who.player_slot + 1,
				str(who.is_multiplayer_authority()), str(who.is_on_floor()),
				Vector2(who.velocity.x, who.velocity.z).length(), observed, clip])


## ⚠️ "NOBODY IS MOVING" IS A DISTANCE QUESTION, NOT AN INSTANT ONE. `_dump_anim()`
## samples `velocity` at three instants and read 0.00 every time, which is consistent
## BOTH with units that never move and with units that were briefly still at each of
## the three moments it happened to look. Cumulative ground covered per unit separates
## them, and it is the same measurement `settle_probe` used for the same question.
var _travel: Dictionary = {}
var _travel_prev: Dictionary = {}

func _sample_travel() -> void:
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		var slot := who.player_slot
		var here := who.global_position
		if _travel_prev.has(slot):
			var step: float = (here - Vector3(_travel_prev[slot])).length()
			# Teleports are not travel — the tag penalty alone moves an attacker the
			# width of the map. Same discontinuity guard `character_visual.gd` uses.
			if step < 5.0:
				_travel[slot] = float(_travel.get(slot, 0.0)) + step
		_travel_prev[slot] = here


func _report() -> void:
	# The ordered stream first, then the snapshot. Both prefixed for `grep | diff`.
	for line in _events:
		print("[EV] %s" % [line])
	# A run that never reached `STOP_AT_ROUND` still reports — against its own end
	# state, and `[FIN] frozen=false` says so rather than the two peers quietly
	# comparing two different instants.
	if not _frozen:
		_snapshot = _build_snapshot()
	print("[FIN] frozen=%s" % [str(_frozen)])
	for line in _snapshot:
		print(line)
	# Peer-local: each end integrates its own view, and a client's view of a remote
	# unit is a replicated position rather than a simulated one, so the two totals are
	# not required to match to the metre. `[INFO]` for exactly that reason.
	for slot in range(MatchManagerScript.PLAYER_COUNT):
		_info("travel P%d = %.1f m" % [slot + 1, float(_travel.get(slot, 0.0))])


func _build_snapshot() -> Array[String]:
	var out: Array[String] = []
	out.append("[FIN] events=%d" % [_events.size()])
	out.append("[FIN] defense_ticks=%d defense_points=%d"
		% [_defense_ticks, _defense_points])
	out.append("[FIN] round=%d defender_slot=%d"
		% [MatchManager.round_number, MatchManager.defender_slot])
	out.append("[FIN] scores=%s" % [str(MatchManager.scores)])

	var lata := RoundManager.lata
	out.append("[FIN] lata=%s upright=%s skin=%d" % [
		"present" if lata != null else "MISSING",
		str(lata.is_upright) if lata != null else "n/a",
		lata.skin_index if lata != null else -99])

	# ⚠️ SLIPPERS ARE SORTED BY NAME. `get_nodes_in_group()` returns tree order, and the
	# two peers build their trees through different code paths (host spawn vs replicated
	# spawn) — an unsorted list would diff as a desync purely from ordering.
	var slipper_lines: Array[String] = []
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null:
			continue
		slipper_lines.append("[FIN] slipper %s state=%d skin=%d"
			% [slipper.name, int(slipper.state), slipper.skin_index])
	slipper_lines.sort()
	out.append_array(slipper_lines)

	# Player rows carry the NAME, which is the identify-packet half of §1.8.
	var player_lines: Array[String] = []
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		player_lines.append("[FIN] player slot=%d name=%s defender=%s score=%d"
			% [who.player_slot, who.display_name(), str(who.is_defender),
				MatchManager.score_for(who.player_slot)])
	player_lines.sort()
	out.append_array(player_lines)
	return out
