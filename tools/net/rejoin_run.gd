extends Node

const MULTIPLAYER_SETUP: String = "res://scenes/ui/MultiplayerSetup.tscn"
const MATCH_SETUP: String = "res://scenes/ui/MatchSetup.tscn"

const PORT_FIRST: int = 8940
const PORT_LAST: int = 8949

var _role: String = "dropper"
var _port: int = 8941
var _host: String = "127.0.0.1"
var _fail: int = 0
var _live: float = 130.0
var _wait_for: int = 1


var _join_after: float = 30.0

var _nudge_round: bool = false
const NUDGE_ARM_DELAY_MS: int = 20000
const NUDGE_TARGET_SECONDS: float = 8.0
const NUDGE_LAST_ROUND: int = 1
var _nudge_armed_ms: int = 0

var _character_id: String = ""
var _can_id: String = ""
var _slipper_id: String = ""
var _expect_character: String = ""
var _expect_can: String = ""
var _expect_slipper: String = ""

var _expect_name: String = ""

const ANCHOR_NAME: String = "ANCHOR"

const DROPPER_NAME: String = "DROPPER"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.substr(len("--role="))
		elif a.begins_with("--port="):
			_port = int(a.substr(len("--port=")))
		elif a.begins_with("--host="):
			_host = a.substr(len("--host="))
		elif a.begins_with("--live="):
			_live = float(a.substr(len("--live=")))
		elif a.begins_with("--wait-for="):
			_wait_for = int(a.substr(len("--wait-for=")))
		elif a.begins_with("--character="):
			_character_id = a.substr(len("--character="))
		elif a.begins_with("--can="):
			_can_id = a.substr(len("--can="))
		elif a.begins_with("--slipper="):
			_slipper_id = a.substr(len("--slipper="))
		elif a.begins_with("--expect-character="):
			_expect_character = a.substr(len("--expect-character="))
		elif a.begins_with("--expect-can="):
			_expect_can = a.substr(len("--expect-can="))
		elif a.begins_with("--expect-slipper="):
			_expect_slipper = a.substr(len("--expect-slipper="))
		elif a.begins_with("--expect-name="):
			_expect_name = a.substr(len("--expect-name="))
		elif a.begins_with("--join-after="):
			_join_after = float(a.substr(len("--join-after=")))
		elif a == "--nudge-round":
			_nudge_round = true
	SettingsManager.player_name = _role.to_upper()
	if _character_id != "":
		GameLaunch.selected_character = StringName(_character_id)
	if _can_id != "":
		GameLaunch.selected_can = StringName(_can_id)
	if _slipper_id != "":
		GameLaunch.selected_slipper = StringName(_slipper_id)
	print("[%s] PICKED character=%s(%d) can=%s(%d) slipper=%s(%d)" % [
		_role, GameLaunch.selected_character, GameLaunch.character_index(),
		GameLaunch.selected_can, GameLaunch.can_index(),
		GameLaunch.selected_slipper, GameLaunch.slipper_index()])
	MatchManager.round_started.connect(_trace_round_started)
	match _role:
		"referee": await _referee()
		"anchor": await _anchor()
		"latecomer": await _latecomer()
		"filler": await _filler()
		"refused": await _refused()
		_: await _dropper()


var _carry_watch: Dictionary = {}

func _process(_delta: float) -> void:
	if _scene_name() != "Main":
		return
	_watch_throws()
	if _role == "referee" or _role == "anchor":
		_watch_dropper_seat(_role)
		_watch_joiner_name(_role)

func _watch_throws() -> void:
	var scene: Node = get_tree().current_scene
	var list: Variant = scene.get("slippers") if scene != null else null
	if not (list is Array):
		return
	for i in range((list as Array).size()):
		var slipper: Node = (list as Array)[i]
		if slipper == null or not is_instance_valid(slipper):
			continue
		var carried: bool = int(slipper.get("state")) == Slipper.CarryState.CARRIED
		var holder: Node = slipper.get("carrier")
		if carried and holder != null and not bool(holder.get("is_bot")):
			var who := String(holder.get("player_name"))
			if who == "":
				who = "slot%d" % [int(holder.get("player_slot"))]
			_carry_watch[i] = who
			continue
		if carried:
			_carry_watch[i] = ""
			continue
		var was: String = String(_carry_watch.get(i, ""))
		if was == "":
			continue
		_carry_watch[i] = ""
		var at: Vector3 = slipper.get("global_position")
		var flying: bool = int(slipper.get("state")) == Slipper.CarryState.FLYING
		print("[%s] %s thrower=%s slipper=%d state=%d at=%.2f,%.2f,%.2f" % [
			_role, "THROW-OBSERVED" if flying else "DROP-OBSERVED",
			was, i, int(slipper.get("state")), at.x, at.y, at.z])

func _trace_round_started(round_number: int, defender_slot: int) -> void:
	print("[%s TRACE] MatchManager.round_started(round=%d defender=%d) at %.1fs, bodies=%d" % [
		_role, round_number, defender_slot,
		Time.get_ticks_msec() / 1000.0, _bodies().size()])

func _address() -> String:
	return "%s:%d" % [_host, _port]

func _other_humans() -> int:
	var count := 0
	var me := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	for peer_id in NetworkManager.connected_peer_ids:
		if peer_id != me and peer_id != 1:
			count += 1
	return count

func _lobby_all_ready(lobby: Node) -> bool:
	if not is_instance_valid(lobby):
		return false
	var seats: Variant = lobby.get("_peer_seats")
	var ready: Variant = lobby.get("_peer_ready")
	if not (seats is Dictionary) or not (ready is Dictionary):
		return false
	if (seats as Dictionary).size() < 1 + _wait_for:
		return false
	for peer_id in (seats as Dictionary):
		if not bool((ready as Dictionary).get(peer_id, false)):
			return false
	return true


func _referee() -> void:
	var screen: Node = load(MATCH_SETUP).instantiate()
	get_tree().root.add_child.call_deferred(screen)
	await get_tree().process_frame
	get_tree().current_scene = screen
	await get_tree().create_timer(1.0).timeout
	_check("the referee is hosting", NetworkManager.is_host())
	_check("and knows it is one", NetworkManager.is_dedicated)
	print("[referee] port=%d code=%s" % [_port, NetworkManager.join_code])
	var elapsed := 0.0
	while elapsed < _live + 30.0:
		await get_tree().create_timer(2.0).timeout
		elapsed += 2.0
		_nudge_round_clock()
		_host_report(int(elapsed))
	_done("referee")

func _nudge_round_clock() -> void:
	if not _nudge_round or not NetworkManager.is_host():
		return
	if not RoundManager.round_active or MatchManager.round_number < 1:
		return
	if MatchManager.round_number > NUDGE_LAST_ROUND:
		return
	if _nudge_armed_ms == 0:
		if NetworkManager.waiting_seat_tokens.is_empty():
			return
		_nudge_armed_ms = Time.get_ticks_msec()
		print("[referee] NUDGE armed — %d peer(s) waiting for a seat" % [
			NetworkManager.waiting_seat_tokens.size()])
		return
	if Time.get_ticks_msec() - _nudge_armed_ms < NUDGE_ARM_DELAY_MS:
		return
	if RoundManager.time_left <= NUDGE_TARGET_SECONDS:
		return
	RoundManager.time_left = NUDGE_TARGET_SECONDS
	print("[referee] NUDGE round=%d clock cut to %.0fs (the rotation is the thing under test)" % [
		MatchManager.round_number, NUDGE_TARGET_SECONDS])

func _host_report(t: int) -> void:
	var scene: Node = get_tree().current_scene
	var where: String = String(scene.name) if scene != null else "<null>"
	var line := "[referee t=%ds] scene=%s in_progress=%s peers=%s" % [
		t, where, str(NetworkManager.match_in_progress),
		str(NetworkManager.connected_peer_ids)]
	if scene != null and String(scene.name) == "Main":
		line += " waiting=%d free_seats=%d" % [
			NetworkManager.waiting_seat_tokens.size(), NetworkManager.free_seat_count()]
		line += " tokens=%s seats=%s spawned=%s" % [
			str(_short_tokens(NetworkManager.peer_tokens)),
			str(_short_seats(scene.get("_token_join_index"))),
			str((scene.get("_spawned_peer_ids") as Dictionary).keys())]
		line += " bodies=%s" % [_bodies_line(scene)]
		line += " | %s" % [_world_line()]
	print(line)
	if scene != null and String(scene.name) == "Main":
		for body in _bodies():
			print("[referee t=%ds] %s" % [t, _pick_line(body)])
		_watch_dropper_seat("referee")

func _short_tokens(map: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in map:
		out[key] = String(map[key]).right(6)
	return out

func _short_seats(map: Variant) -> Dictionary:
	var out: Dictionary = {}
	if map is Dictionary:
		for key in (map as Dictionary):
			out[String(key).right(6)] = (map as Dictionary)[key]
	return out


func _anchor() -> void:
	var screen: Node = await _open_setup()
	screen.call("_begin_join", _address())
	await get_tree().create_timer(3.0).timeout
	var lobby: Node = get_tree().current_scene
	var in_lobby := lobby != null and String(lobby.name) == "MatchSetup"
	_check("the anchor reached the lobby", in_lobby)
	_check("the anchor connected", NetworkManager.is_networked())
	_check("the anchor leads the lobby, so it can press START",
		NetworkManager.is_lobby_leader())
	if not in_lobby:
		_done("anchor")
		return
	lobby.call("_on_primary_pressed")

	var waited := 0.0
	while waited < 45.0 and _other_humans() < _wait_for:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	_check("the other client is in the lobby too", _other_humans() >= _wait_for)
	while waited < 70.0 and not _lobby_all_ready(lobby):
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	_check("both seats are ready", _lobby_all_ready(lobby))
	var pressed := 0.0
	while pressed < 15.0 and _scene_name() == "MatchSetup":
		if is_instance_valid(lobby):
			lobby.call("_on_start_pressed")
		await get_tree().create_timer(1.0).timeout
		pressed += 1.0
	await get_tree().create_timer(8.0).timeout
	_check("the anchor is in the match scene", _scene_name() == "Main")
	_press_ready_up()
	await get_tree().create_timer(6.0).timeout
	print("[anchor] round=%d active=%s" % [MatchManager.round_number, str(RoundManager.round_active)])
	_check("a round is genuinely running", RoundManager.round_active)

	var elapsed := 0.0
	while elapsed < _live:
		await get_tree().create_timer(1.0).timeout
		elapsed += 1.0
		_watch_dropper_seat("anchor")
		_keep_lata_up()
		if int(elapsed) % 5 != 0:
			continue
		_report("anchor t=%ds" % int(elapsed))
		if int(elapsed) == 10:
			await _check_abilities("CONTROL")
	if _wait_for > 0 and _expect_character != "":
		_check("the anchor actually witnessed the reclaim it is here to judge",
			_reclaim_checked)
	_done("anchor")

func _keep_lata_up() -> void:
	var body: CharacterBase = _my_body()
	var lata: Node = RoundManager.lata
	if body == null or lata == null or not body.is_defender:
		return
	if bool(lata.get("is_upright")):
		return
	var mark: Vector3 = lata.get("global_position")
	body.global_position = Vector3(mark.x, body.global_position.y, mark.z)
	_press("grab", true)


func _dropper() -> void:
	await get_tree().create_timer(6.0).timeout
	var screen: Node = await _open_setup()
	screen.call("_begin_join", _address())
	await get_tree().create_timer(3.0).timeout
	var lobby: Node = get_tree().current_scene
	var in_lobby := lobby != null and String(lobby.name) == "MatchSetup"
	_check("the dropper reached the lobby", in_lobby)
	_check("the dropper connected", NetworkManager.is_networked())
	if not in_lobby:
		_done("dropper")
		return
	lobby.call("_on_primary_pressed")

	var waited := 0.0
	while waited < 45.0 and _scene_name() != "Main":
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	_check("the dropper is in the match scene", _scene_name() == "Main")
	_press_ready_up()
	var settle := 0.0
	while settle < 14.0:
		await get_tree().create_timer(1.0).timeout
		settle += 1.0
		print("[dropper t=%ds] %s" % [int(settle), _world_line()])
		print("[dropper t=%ds] %s" % [int(settle), _pick_line(_body_named(DROPPER_NAME))])
		if RoundManager.round_active and RoundManager.player_at(1) != null:
			break
	print("[dropper] round=%d active=%s" % [MatchManager.round_number, str(RoundManager.round_active)])

	var before := _report("dropper BEFORE")
	_check("BEFORE: the dropper owns a body", before["owned"] != "")
	_check("BEFORE: the dropper is looking through a camera", before["camera"] != "<none>")
	var before_body := _body_named(DROPPER_NAME)
	_check("BEFORE: the dropper's own body carries their pick",
		before_body != null and before_body.character_index
			== CharacterRoster.index_of(StringName(_expect_character)))
	var before_index: int = before_body.character_index if before_body != null else -1
	var before_props := _seat_props(before_body.player_slot) if before_body != null else {}
	print("[dropper BEFORE] %s" % [_pick_line(before_body)])
	await _check_abilities("BEFORE")

	print("[dropper] --- dropping ---")
	NetworkManager.disconnect_network()
	MatchManager.reset()
	RoundManager.reset()
	GameLaunch.reset()
	var match_scene: Node = get_tree().current_scene
	if match_scene != null:
		match_scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(3.0).timeout
	print("[dropper] dropped: networked=%s bodies=%d" % [
		str(NetworkManager.is_networked()), _bodies().size()])

	var screen2: Node = await _open_setup()
	screen2.call("_begin_join", _address())
	await get_tree().create_timer(14.0).timeout

	var after := _report("dropper AFTER")
	_check("AFTER: the returning player is in the match scene",
		String(after["scene"]) == "Main")
	_check("AFTER: the world is populated (four bodies)", int(after["bodies"]) == 4)
	_check("AFTER: the returning player owns a body", String(after["owned"]) != "")
	_check("AFTER: the returning player has a camera to look through",
		String(after["camera"]) != "<none>")
	_check("AFTER: it is THEIR OWN seat, the one they had before",
		String(after["owned_slot"]) == String(before["owned_slot"])
			and String(before["owned_slot"]) != "")
	_check("AFTER: no bot is still driving that body", not bool(after["owned_is_bot"]))
	var after_body := _body_named(DROPPER_NAME)
	_assert_dropper_picks("dropper AFTER")
	_assert_own_name("dropper AFTER")
	_check("AFTER: it is the SAME fighter they dropped out on",
		after_body != null and before_index >= 0
			and after_body.character_index == before_index)
	if not before_props.is_empty():
		var after_props := _seat_props(after_body.player_slot) if after_body != null else {}
		print("[dropper AFTER] props before=%s after=%s" % [str(before_props), str(after_props)])
		_check("AFTER: the same lata and tsinelas they dropped out with",
			after_props == before_props)
	await _check_abilities("AFTER")
	_done("dropper")


func _knock_mid_match(settle: float) -> void:
	await get_tree().create_timer(_join_after).timeout
	var screen: Node = await _open_setup()
	screen.call("_begin_join", _address())
	await get_tree().create_timer(settle).timeout

func _status_text() -> String:
	var scene: Node = get_tree().current_scene
	if scene == null or String(scene.name) != "MultiplayerSetup":
		return ""
	var label := scene.get_node_or_null("%StatusLabel") as Label
	if label == null:
		label = _first_named(scene, "StatusLabel") as Label
	return label.text if label != null else ""

func _has_spectator_camera() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null or String(scene.name) != "Main":
		return false
	return scene.get_node_or_null("Spectator") != null


func _latecomer() -> void:
	await _knock_mid_match(12.0)

	var waiting := _report("latecomer waiting")
	print("[latecomer] WAIT-CHECK scene=%s provisional=%s spectator_cam=%s body=%s" % [
		_scene_name(), str(NetworkManager.provisional_spectator),
		str(_has_spectator_camera()), str(_my_body() != null)])
	_check("a mid-match newcomer is admitted rather than turned away",
		String(waiting["scene"]) == "Main")
	_check("...as a SPECTATOR, because the host said so", NetworkManager.provisional_spectator)
	_check("...with a camera to watch through", _has_spectator_camera())
	_check("...and NO body of its own while it waits", _my_body() == null)
	_check("...while the match it is watching is still fully populated",
		int(waiting["bodies"]) == 4)

	var start_round := MatchManager.round_number
	var waited := 0.0
	while waited < 100.0 and _my_body() == null:
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
	var after := _report("latecomer seated")
	print("[latecomer] PROMOTE-CHECK round %d -> %d after %.0fs body=%s spectator_cam=%s" % [
		start_round, MatchManager.round_number, waited,
		str(_my_body() != null), str(_has_spectator_camera())])
	_check("a waiting newcomer is given a real seat", _my_body() != null)
	_check("...at a ROLE ROTATION, not on arrival", MatchManager.round_number > start_round)
	_check("...and the spectator camera is gone with it", not _has_spectator_camera())
	_check("owning a body", String(after["owned"]) != "")
	_check("and a camera to look through", String(after["camera"]) != "<none>")
	if _expect_character != "":
		var body := _my_body()
		var want := CharacterRoster.index_of(StringName(_expect_character))
		print("[latecomer] %s" % [_pick_line(body)])
		_check("a promoted newcomer wears the fighter they picked (%s)"
			% _roster_name(want), body != null and body.character_index == want)
	_assert_own_name("latecomer")
	await _check_abilities("LATECOMER")
	await get_tree().create_timer(10.0).timeout
	_done("latecomer")


func _filler() -> void:
	await _knock_mid_match(14.0)
	print("[filler] FILL-CHECK scene=%s provisional=%s body=%s" % [
		_scene_name(), str(NetworkManager.provisional_spectator), str(_my_body() != null)])
	_check("a filler is admitted to the waiting queue", NetworkManager.provisional_spectator)
	_check("...and holds no seat while it waits there", _my_body() == null)
	await get_tree().create_timer(_live).timeout
	_done("filler")

func _refused() -> void:
	await _knock_mid_match(16.0)
	var status := _status_text()
	print("[refused] REFUSE-CHECK scene=%s networked=%s body=%s status='%s'" % [
		_scene_name(), str(NetworkManager.is_networked()), str(_my_body() != null), status])
	_check("a newcomer arriving at a full waiting queue is bounced back to the browser",
		_scene_name() == "MultiplayerSetup")
	_check("...and told why, in words that name the cause",
		status.to_lower().contains("already started"))
	_check("...and is not left holding a connection to a match it is not in",
		not NetworkManager.is_networked())
	_check("...and never gets a body", _my_body() == null)
	_done("refused")


func _report(tag: String) -> Dictionary:
	var scene: Node = get_tree().current_scene
	var bodies := _bodies()
	var owned := ""
	var owned_slot := ""
	var owned_is_bot := false
	var me := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	var lines: Array[String] = []
	for body in bodies:
		var mine: bool = body.is_multiplayer_authority()
		var ai: bool = body.get("ai_controller") != null
		var rig: Node = body.get_node_or_null("CameraRig")
		var rig_on := false
		if rig != null:
			for cam in [rig.get_node_or_null("FppPivot/FppCamera"), rig.get_node_or_null("TppArm/TppCamera")]:
				if cam != null and bool(cam.get("current")):
					rig_on = true
		lines.append("%s(slot=%s auth=%d mine=%s bot=%s ai=%s cam=%s)" % [
			body.name, str(body.get("player_slot")), body.get_multiplayer_authority(),
			str(mine), str(body.get("is_bot")), str(ai), str(rig_on)])
		if mine and not ai:
			owned = String(body.name)
			owned_slot = str(body.get("player_slot"))
			owned_is_bot = bool(body.get("is_bot"))
	var cam3d: Camera3D = get_viewport().get_camera_3d()
	var camera: String = String(cam3d.get_path()) if cam3d != null else "<none>"
	var local_body := "<none>"
	if scene != null and scene.has_method("get_local_character"):
		var lc: Node = scene.call("get_local_character")
		if lc != null:
			local_body = String(lc.name)
	print("[%s] scene=%s peer=%d networked=%s peers=%s" % [
		tag, _scene_name(), me, str(NetworkManager.is_networked()),
		str(NetworkManager.connected_peer_ids)])
	print("[%s] bodies=%d %s" % [tag, bodies.size(), " ".join(lines)])
	print("[%s] camera=%s get_local_character=%s round=%d hud='%s'" % [
		tag, camera, local_body, MatchManager.round_number, _hud_text(scene)])
	print("[%s] %s" % [tag, _world_line()])
	for body in bodies:
		print("[%s] %s" % [tag, _probe_line(body as CharacterBody3D)])
		print("[%s] %s" % [tag, _pick_line(body)])
	return {
		"scene": _scene_name(),
		"bodies": bodies.size(),
		"owned": owned,
		"owned_slot": owned_slot,
		"owned_is_bot": owned_is_bot,
		"camera": camera,
	}


func _world_line() -> String:
	var seats: Array[String] = []
	for slot in range(4):
		var who: Node = RoundManager.player_at(slot)
		seats.append("%d=%s" % [slot, String(who.name) if who != null else "<null>"])
	var slips: Array[String] = []
	var scene: Node = get_tree().current_scene
	var list: Variant = scene.get("slippers") if scene != null else null
	if list is Array:
		for i in range((list as Array).size()):
			var slipper: Node = (list as Array)[i]
			if slipper == null or not is_instance_valid(slipper):
				continue
			var holder: Node = slipper.get("carrier")
			var at: Vector3 = slipper.get("global_position")
			slips.append("s%d(owner=%s state=%s carrier=%s at=%.2f,%.2f,%.2f)%s" % [
				i, str(slipper.get("owner_slot")), str(slipper.get("state")),
				String(holder.name) if holder != null else "<null>",
				at.x, at.y, at.z, _carry_path(slipper)])
	var lata: Node = RoundManager.lata
	return ("WORLD round=%d round_active=%s lata=%s lata_up=%s throw_cd=%.2f time_left=%.1f "
		+ "defender_slot=%d rm_seats=[%s] %s") % [
		MatchManager.round_number, str(RoundManager.round_active), str(lata != null),
		str(lata != null and bool(lata.get("is_upright"))),
		RoundManager.throw_cooldown_left(),
		RoundManager.time_left, MatchManager.defender_slot,
		", ".join(seats), " ".join(slips)]

func _carry_path(slipper: Node) -> String:
	if int(slipper.get("state")) != Slipper.CarryState.CARRIED:
		return ""
	return " path=%s" % [String(slipper.get_path())]

func _probe_line(body: CharacterBody3D) -> String:
	var slot: int = int(body.get("player_slot"))
	var seated: Node = RoundManager.player_at(slot)
	var can_throw: bool = RoundManager.can_throw(body as CharacterBase)
	return ("BODY %s slot=%d player_id=%s auth=%d mine=%s is_bot=%s ai_ctrl=%s "
		+ "ai_driven=%s input_parked=%s layer=%d mask=%d phys_proc=%s proc=%s "
		+ "can_process=%s state=%s settle=%s defender=%s holding=%s carrier_held=%s "
		+ "rm_seat=%s can_act=%s can_throw=%s inside_box=%s shove_cd=%.2f lunge_cd=%.2f "
		+ "punch_cd=%.2f throw_lock=%.2f") % [
		body.name, slot, str(body.get("player_id")),
		body.get_multiplayer_authority(), str(body.is_multiplayer_authority()),
		str(body.get("is_bot")), str(body.get("ai_controller") != null),
		str(body.call("is_ai_driven")), str(body.get("input_parked")),
		body.collision_layer, body.collision_mask,
		str(body.is_physics_processing()), str(body.is_processing()),
		str(body.can_process()), str(body.get("state")), str(body.get("_spawn_settle")),
		str(body.get("is_defender")), str(body.call("holding_slipper")),
		_carrier_held(body),
		"self" if seated == body else ("<null>" if seated == null else String(seated.name)),
		str(body.call("can_act")), str(can_throw), str(body.call("is_inside_box")),
		float(body.call("shove_cooldown_left")), _f(body, "_lunge_cooldown_left"),
		_f(body, "_punch_cooldown_left"), _carrier_lock(body)]

func _carrier_held(body: Node) -> String:
	var carrier: Node = body.get_node_or_null("Carrier")
	if carrier == null:
		return "<no carrier node>"
	var held: Node = carrier.call("held")
	return String(held.name) if held != null else "<null>"

func _carrier_lock(body: Node) -> float:
	var carrier: Node = body.get_node_or_null("Carrier")
	return float(carrier.call("throw_lock_left")) if carrier != null else -1.0

func _f(body: Node, field: String) -> float:
	var value: Variant = body.get(field)
	return float(value) if value != null else -1.0


func _roster_name(index: int) -> String:
	return "<none>" if index < 0 else CharacterRoster.name_at(index)

func _seat_props(slot: int) -> Dictionary:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return {}
	var table: Variant = scene.get("_seat_prop_picks")
	if not (table is Dictionary):
		return {}
	var row: Variant = (table as Dictionary).get(slot)
	return row if row is Dictionary else {}

func _pick_line(body: Node) -> String:
	if body == null:
		return "<no body>"
	var index: int = int(body.get("character_index"))
	var visual: Node = body.get_node_or_null("Visual")
	var model := "<no visual>"
	var material := ""
	if visual != null:
		model = String(visual.get("_current_key")).get_file()
		material = String(visual.get("_current_material_key")).get_file()
	var slot: int = int(body.get("player_slot"))
	var props := _seat_props(slot)
	var props_text := "<none>"
	if not props.is_empty():
		var can := int(props.get("can", -1))
		var slipper := int(props.get("slipper", -1))
		props_text = "can=%d/%s slipper=%d/%s" % [
			can, String(CharacterRoster.can_at(can).get("name", "<none>")) if can >= 0 else "<none>",
			slipper,
			String(CharacterRoster.slipper_at(slipper).get("name", "<none>")) if slipper >= 0 else "<none>"]
	return "PICK %s slot=%d player_name='%s' is_bot=%s auth=%d char=%d/%s model=%s mat=%s %s" % [
		body.name, slot, String(body.get("player_name")), str(body.get("is_bot")),
		body.get_multiplayer_authority(), index, _roster_name(index), model, material,
		props_text]

func _body_named(who: String) -> CharacterBase:
	for node in _bodies():
		var body := node as CharacterBase
		if body != null and body.player_name == who:
			return body
	return null


func _joiner_body() -> CharacterBase:
	var mine: CharacterBase = _my_body()
	for node in _bodies():
		var body := node as CharacterBase
		if body == null or body == mine or body.is_bot:
			continue
		if body.player_name == ANCHOR_NAME:
			continue
		return body
	return null

var _joiner_present: bool = false
var _joiner_seen_ms: int = 0
var _name_checks: int = 0

const NAME_SETTLE_MS: int = 2000
const NAME_CHECKS_MAX: int = 2

func _watch_joiner_name(tag: String) -> void:
	if _expect_name == "":
		return
	var body := _joiner_body()
	if body == null:
		_joiner_present = false
		return
	if not _joiner_present:
		_joiner_present = true
		_joiner_seen_ms = Time.get_ticks_msec()
		return
	if _name_checks >= NAME_CHECKS_MAX:
		return
	if Time.get_ticks_msec() - _joiner_seen_ms < NAME_SETTLE_MS:
		return
	_joiner_seen_ms = Time.get_ticks_msec() + 3_600_000
	_name_checks += 1
	_assert_joiner_name("%s #%d" % [tag, _name_checks], body)

func _assert_joiner_name(tag: String, body: CharacterBase) -> void:
	if body == null:
		print("[%s] NAME-CHECK ok=false reason=no-joiner-body expect='%s'" % [tag, _expect_name])
		_check("%s: there is a joiner body to read a name off" % tag, false)
		return
	var got := body.player_name
	var shown := body.display_name()
	var ok := got == _expect_name
	print("[%s] NAME-CHECK body=%s slot=%d got='%s' expect='%s' display='%s' is_bot=%s ok=%s" % [
		tag, body.name, body.player_slot, got, _expect_name, shown, str(body.is_bot), str(ok)])
	_check("%s: the joiner's name reads '%s' on this peer (want '%s')" % [
		tag, got, _expect_name], ok)
	_check("%s: ...so the label drawn over them is not the bare seat number" % tag,
		shown != "P%d" % [body.player_slot + 1])

func _assert_own_name(tag: String) -> void:
	if _expect_name == "":
		return
	_assert_joiner_name(tag, _my_body())


var _saw_bot_hold: bool = false
var _reclaim_checked: bool = false

func _watch_dropper_seat(tag: String) -> void:
	if _reclaim_checked or _expect_character == "":
		return
	var body := _body_named(DROPPER_NAME)
	if body == null:
		return
	if body.is_bot:
		if not _saw_bot_hold:
			_saw_bot_hold = true
			print("[%s] BOT-HOLDS %s" % [tag, _pick_line(body)])
		return
	if not _saw_bot_hold:
		return
	_reclaim_checked = true
	_assert_dropper_picks(tag)

func _assert_dropper_picks(tag: String) -> void:
	var body := _body_named(DROPPER_NAME)
	if body == null:
		print("[%s] RECLAIM-CHECK ok=false reason=no-body-named-%s" % [tag, DROPPER_NAME])
		_check("%s: the returning player's body exists at all" % tag, false)
		return
	var want_person := CharacterRoster.index_of(StringName(_expect_character))
	var got_person := body.character_index
	var person_ok := got_person == want_person
	print("[%s] RECLAIM-CHECK char=%d/%s expect=%d/%s ok=%s" % [
		tag, got_person, _roster_name(got_person),
		want_person, _roster_name(want_person), str(person_ok)])
	print("[%s] %s" % [tag, _pick_line(body)])
	_check("%s: the returning player is on their OWN fighter (%s), not %s" % [
		tag, _roster_name(want_person), _roster_name(got_person)], person_ok)

	var visual: Node = body.get_node_or_null("Visual")
	var want_entry := CharacterRoster.at(want_person)
	if visual != null and want_entry.has("model"):
		var model := String(visual.get("_current_key"))
		var material := String(visual.get("_current_material_key"))
		_check("%s: ...and the MODEL on screen is that fighter's" % tag,
			model == String(want_entry["model"]))
		_check("%s: ...and so is the palette" % tag,
			material == String(want_entry["material"]))

	var props := _seat_props(body.player_slot)
	if props.is_empty():
		print("[%s] RECLAIM-PROPS <none on this peer>" % tag)
		return
	var want_can := CharacterRoster.index_in(CharacterRoster.CANS, StringName(_expect_can))
	var want_slipper := CharacterRoster.index_in(
		CharacterRoster.SLIPPERS, StringName(_expect_slipper))
	var got_can := int(props.get("can", -1))
	var got_slipper := int(props.get("slipper", -1))
	print("[%s] RECLAIM-PROPS can=%d expect=%d slipper=%d expect=%d ok=%s" % [
		tag, got_can, want_can, got_slipper, want_slipper,
		str(got_can == want_can and got_slipper == want_slipper)])
	if want_can >= 0:
		_check("%s: the returning player's own LATA came back" % tag, got_can == want_can)
	if want_slipper >= 0:
		_check("%s: the returning player's own TSINELAS came back" % tag,
			got_slipper == want_slipper)


func _my_body() -> CharacterBase:
	for node in _bodies():
		var body := node as CharacterBase
		if body != null and body.is_multiplayer_authority() and body.ai_controller == null:
			return body
	return null

func _check_abilities(tag: String) -> void:
	var body: CharacterBase = _my_body()
	if body == null:
		_check("%s: there is a body to test at all" % tag, false)
		return
	var slot: int = body.player_slot

	_check("%s: RoundManager on this peer knows the body by its seat" % tag,
		RoundManager.player_at(slot) == body)
	_check("%s: this peer has the lata" % tag, RoundManager.lata != null)
	_check("%s: the round is live on this peer" % tag, RoundManager.round_active)

	if not body.is_defender:
		await _check_pickup_and_throw(tag, body)

	body.velocity = Vector3.ZERO
	body.state = CharacterBase.State.NORMAL
	RoundManager._apply_shove_to(slot, Vector3(7.0, 0.0, 0.0), 0.6)
	var pushed := body.velocity.length() > 0.5
	var stunned := body.state != CharacterBase.State.NORMAL
	print("[%s] PUSH velocity=%.2f state=%s" % [tag, body.velocity.length(), str(body.state)])
	_check("%s: a host shove reaches the body (it can be PUSHED)" % tag, pushed and stunned)

func _check_pickup_and_throw(tag: String, body: CharacterBase) -> void:
	var mine: Slipper = _reachable_slipper(body)
	if mine == null:
		_check("%s: this peer can see a slipper to pick up at all" % tag, false)
		return
	print(("[%s] TARGET slipper=%s owner=%d mine=%s state=%d in_hand=%s dist=%.2f "
		+ "held_ability=%s held_grab=%s charging=%s") % [
		tag, mine.name, mine.owner_slot, str(mine.owner_slot == body.player_slot),
		int(mine.state), str(mine.carrier == body),
		body.global_position.distance_to(mine.global_position),
		str(Input.is_action_pressed("special_ability")),
		str(Input.is_action_pressed("grab")),
		str(body.get_node("Carrier").call("is_charging"))])
	if mine.carrier != body:
		body.global_position = mine.global_position
		await get_tree().create_timer(1.0).timeout
		_press("grab", false)
		await get_tree().physics_frame
		_press("grab", true)
		await get_tree().create_timer(1.5).timeout
		_press("grab", false)
		await get_tree().create_timer(1.0).timeout
	_check("%s: a slipper is in this peer's hand after pressing E on one (PICKUP)" % tag,
		body.holding_slipper())
	var carrier: Node = body.get_node_or_null("Carrier")
	_check("%s: and the Carrier component agrees it is holding one" % tag,
		carrier != null and carrier.call("held") != null)

	var clear_of_box: float = CharacterBase.confinement_radius + 1.5
	if CharacterBase.playable_half_x > 0.0:
		clear_of_box = minf(clear_of_box, CharacterBase.playable_half_x - 0.5)
	body.global_position = Vector3(clear_of_box, body.global_position.y, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cooldown_deadline := Time.get_ticks_msec() + 4000
	while RoundManager.throw_cooldown_left() > 0.0 and Time.get_ticks_msec() < cooldown_deadline:
		await get_tree().physics_frame
	var lata: Node = RoundManager.lata
	var lata_up: bool = lata != null and bool(lata.get("is_upright"))
	print(("[%s] THROW GATE lata_up=%s throw_cd=%.2f inside_box=%s holding=%s defender=%s "
		+ "round_active=%s can_throw=%s") % [
		tag, str(lata_up), RoundManager.throw_cooldown_left(),
		str(body.is_inside_box()), str(body.holding_slipper()), str(body.is_defender),
		str(RoundManager.round_active), str(RoundManager.can_throw(body))])
	_check("%s: every clause of the throw gate a rejoin can break is satisfied (THROW)" % tag,
		RoundManager.round_active
			and not body.is_defender
			and body.holding_slipper()
			and lata != null
			and RoundManager.throw_cooldown_left() <= 0.0
			and not body.is_inside_box())
	_check("%s: ...so the gate is open iff the can is standing" % tag,
		RoundManager.can_throw(body) == lata_up)
	await _drive_throw(tag, body)


const CHARGE_HOLD: float = 0.8
const RELEASE_GRACE_MS: int = 2500
const THROW_TRAVEL_MIN: float = 1.5
const CHARGE_ATTEMPTS: int = 3

func _throw_moment_is_legal(body: CharacterBase) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	return RoundManager.can_throw(body) and body.can_act() and not body.input_parked

func _drive_throw(tag: String, body: CharacterBase) -> void:
	var carrier: Node = body.get_node_or_null("Carrier")
	if carrier == null:
		_check("%s: the body has a Carrier to throw with" % tag, false)
		return
	var slipper := carrier.call("held") as Slipper
	if slipper == null:
		print("[%s] THROW-CHECK ok=false reason=nothing-in-hand" % tag)
		_check("%s: there is a slipper in the hand to throw (THROW)" % tag, false)
		return
	print("[%s] THROW-BEFORE slipper=%s state=%d carrier=%s path=%s" % [
		tag, slipper.name, int(slipper.state),
		String(slipper.carrier.name) if slipper.carrier != null else "<null>",
		String(slipper.get_path())])

	var clear_of_box: float = CharacterBase.confinement_radius + 1.5
	if CharacterBase.playable_half_x > 0.0:
		clear_of_box = minf(clear_of_box, CharacterBase.playable_half_x - 0.5)
	var gate_deadline := Time.get_ticks_msec() + 30000
	while not _throw_moment_is_legal(body) and Time.get_ticks_msec() < gate_deadline:
		if body.state == CharacterBase.State.NORMAL:
			body.global_position = Vector3(clear_of_box, body.global_position.y, 0.0)
		await get_tree().physics_frame
	if not RoundManager.can_throw(body):
		print(("[%s] THROW-CHECK ok=false reason=gate-never-opened lata_up=%s throw_cd=%.2f "
			+ "holding=%s inside_box=%s") % [
			tag, str(RoundManager.lata != null and bool(RoundManager.lata.get("is_upright"))),
			RoundManager.throw_cooldown_left(), str(body.holding_slipper()),
			str(body.is_inside_box())])
		_check("%s: the round offered a legal throwing moment within 30 s" % tag, false)
		return

	var from := body.global_position
	var charged := false
	var charge_power := 0.0
	for attempt in range(CHARGE_ATTEMPTS):
		var retry_deadline := Time.get_ticks_msec() + 10000
		while not _throw_moment_is_legal(body) and Time.get_ticks_msec() < retry_deadline:
			if body.state == CharacterBase.State.NORMAL:
				body.global_position = Vector3(clear_of_box, body.global_position.y, 0.0)
			await get_tree().physics_frame
		from = body.global_position
		_press("special_ability", false)
		await get_tree().physics_frame
		_press("special_ability", true)
		await get_tree().create_timer(CHARGE_HOLD).timeout
		charged = bool(carrier.call("is_charging"))
		charge_power = float(carrier.call("charge_power"))
		if charged:
			break
		_press("special_ability", false)
		print("[%s] THROW-RETRY attempt=%d charged=false can_throw=%s parked=%s state=%s cd=%.2f" % [
			tag, attempt + 1, str(RoundManager.can_throw(body)), str(body.input_parked),
			str(body.state), RoundManager.throw_cooldown_left()])
		await get_tree().create_timer(0.5).timeout
		if carrier.call("held") == null:
			break
	_press("special_ability", false)
	_check("%s: the charge-up ran on a real button hold" % tag, charged)

	var left_hand := false
	var deadline := Time.get_ticks_msec() + RELEASE_GRACE_MS
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if slipper.state != Slipper.CarryState.CARRIED and slipper.carrier == null:
			left_hand = true
			break
	await get_tree().create_timer(1.0).timeout
	var travelled := slipper.global_position.distance_to(from)
	var still_held: bool = body.holding_slipper()
	var carrier_held: bool = carrier.call("held") != null
	print(("[%s] THROW-CHECK ok=%s charged=%s power=%.2f state=%d carrier=%s "
		+ "travelled=%.2f holding=%s carrier_held=%s") % [
		tag, str(left_hand and travelled >= THROW_TRAVEL_MIN and not still_held),
		str(charged), charge_power, int(slipper.state),
		String(slipper.carrier.name) if slipper.carrier != null else "<null>",
		travelled, str(still_held), str(carrier_held)])
	_check("%s: the tsinelas actually LEFT THE HAND on release (THROW)" % tag, left_hand)
	_check("%s: ...and the thrower's hand is empty afterwards" % tag,
		not still_held and not carrier_held)
	_check("%s: ...and it TRAVELLED away from the thrower (%.2f m >= %.2f)" % [
		tag, travelled, THROW_TRAVEL_MIN], travelled >= THROW_TRAVEL_MIN)

func _reachable_slipper(body: CharacterBase) -> Slipper:
	var scene: Node = get_tree().current_scene
	var list: Variant = scene.get("slippers") if scene != null else null
	if not (list is Array):
		return null
	var own_loose: Slipper = null
	var any_loose: Slipper = null
	for entry in (list as Array):
		var slipper := entry as Slipper
		if slipper == null or not is_instance_valid(slipper):
			continue
		if slipper.carrier == body:
			return slipper
		if not slipper.is_loose():
			continue
		if any_loose == null:
			any_loose = slipper
		if slipper.owner_slot == body.player_slot:
			own_loose = slipper
	return own_loose if own_loose != null else any_loose

func _press(action: String, down: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = down
	Input.parse_input_event(event)

func _hud_text(scene: Node) -> String:
	if scene == null:
		return ""
	var hud: Node = scene.get_node_or_null("HUDLayer/HUD")
	if hud == null:
		hud = _first_named(scene, "HUD")
	if hud == null:
		return "<no hud>"
	var label: Node = hud.get_node_or_null("%RoundLabel")
	if label == null:
		return "<no round label>"
	return String(label.get("text"))

func _first_named(from: Node, needle: String) -> Node:
	if String(from.name) == needle:
		return from
	for child in from.get_children():
		var hit := _first_named(child, needle)
		if hit != null:
			return hit
	return null

func _bodies() -> Array[Node]:
	var out: Array[Node] = []
	_collect(get_tree().root, "CharacterBody3D", out)
	return out

func _bodies_line(from: Node) -> String:
	var out: Array[Node] = []
	_collect(from, "CharacterBody3D", out)
	var parts: Array[String] = []
	for body in out:
		parts.append("%s(slot=%s auth=%d bot=%s)" % [
			body.name, str(body.get("player_slot")), body.get_multiplayer_authority(),
			str(body.get("is_bot"))])
	return " ".join(parts)

func _collect(from: Node, type_name: String, out: Array[Node]) -> void:
	if from == null:
		return
	if from.is_class(type_name):
		out.append(from)
	for child in from.get_children():
		_collect(child, type_name, out)


func _open_setup() -> Node:
	var screen: Node = load(MULTIPLAYER_SETUP).instantiate()
	get_tree().root.add_child.call_deferred(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = screen
	await get_tree().create_timer(1.0).timeout
	return screen

func _press_ready_up() -> void:
	var press := InputEventAction.new()
	press.action = "ready_up"
	press.pressed = true
	Input.parse_input_event(press)

func _scene_name() -> String:
	var scene: Node = get_tree().current_scene
	return String(scene.name) if scene != null else "<null>"

func _done(tag: String) -> void:
	print("[%s] RESULT %s" % [tag, "PASS" if _fail == 0 else "FAIL (%d)" % _fail])
	get_tree().quit(_fail)

func _check(what: String, ok: bool) -> void:
	if not ok:
		_fail += 1
	print("[%s] %s  %s" % [_role, "PASS" if ok else "FAIL", what])

