extends Node

const MAIN_SCENE_PATH: String = "res://scenes/main/Main.tscn"

const CONNECT_WAIT: float = 6.0
const HOST_LINGER: float = 8.0

const STOP_AT_ROUND: int = 2

var _is_host := false
var _frozen := false
var _snapshot: Array[String] = []
var _run_secs := 120.0
var _out := ""
var _tag := "?"
var _main: Node = null

var _events: Array[String] = []
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

	_main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	_main.name = "Main"
	get_tree().root.add_child.call_deferred(_main)
	await get_tree().process_frame
	get_tree().current_scene = _main

	_subscribe()
	_run.call_deferred()


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



func _ev(line: String) -> void:
	if _frozen:
		return
	_events.append(line)


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



func _info(line: String) -> void:
	print("[INFO][%s] %s" % [_tag, line])


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s%s.png" % [_out, name]
	var err := image.save_png(path)
	print("[INFO][%s] shot %s -> %s (%dx%d)" % [_tag, name,
		path if err == OK else "FAILED", image.get_width(), image.get_height()])


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
			if step < 5.0:
				_travel[slot] = float(_travel.get(slot, 0.0)) + step
		_travel_prev[slot] = here


func _report() -> void:
	for line in _events:
		print("[EV] %s" % [line])
	if not _frozen:
		_snapshot = _build_snapshot()
	print("[FIN] frozen=%s" % [str(_frozen)])
	for line in _snapshot:
		print(line)
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

	var slipper_lines: Array[String] = []
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null:
			continue
		slipper_lines.append("[FIN] slipper %s state=%d skin=%d"
			% [slipper.name, int(slipper.state), slipper.skin_index])
	slipper_lines.sort()
	out.append_array(slipper_lines)

	var player_lines: Array[String] = []
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		player_lines.append("[FIN] player slot=%d name=%s defender=%s score=%d character_index=%d"
			% [who.player_slot, who.display_name(), str(who.is_defender),
				MatchManager.score_for(who.player_slot), who.character_index])
	player_lines.sort()
	out.append_array(player_lines)
	return out

