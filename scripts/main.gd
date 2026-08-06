extends Node3D


@onready var players: Array[CharacterBase] = [$Player1, $Player2, $Player3, $Player4]
@onready var lata: Lata = $Lata
@onready var slippers: Array[Slipper] = [$Slipper1, $Slipper2, $Slipper3]
@onready var players_root: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var hud: Hud = $HUDLayer/HUD
@onready var match_result: MatchResult = $HUDLayer/MatchResult
@onready var map_root: Node3D = $Map
var kill_plane: KillPlane = null
@onready var pause_root: Control = %PauseRoot
@onready var resume_button: Button = %ResumeButton
@onready var menu_button: Button = %MenuButton
@onready var settings_button: Button = %SettingsButton
@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var paused_label: Label = %PausedLabel
@onready var paused_note_label: Label = %PausedNoteLabel
@onready var pause_layer: PauseLayer = $PauseLayer

const CHARACTER_SCENE: PackedScene = preload("res://scenes/characters/CharacterBase.tscn")
var _local_roster: Array[CharacterBase] = []
var _awaiting_local_ready: bool = false
var _counting_down: bool = false
var _awaiting_net_ready: bool = false
var _net_ready_peers: Dictionary = {}
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(0, 0.17, 0), Vector3(2, 0.8, 1), Vector3(0, 0.8, 6), Vector3(1, 0.16, 6)
]

var _map_spawns: Array[Transform3D] = []

func _load_map() -> void:
	_map_spawns.clear()
	for child in map_root.get_children():
		map_root.remove_child(child)
		child.queue_free()

	var path := GameLaunch.selected_map_scene()
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("main.gd: could not load map '%s'; running with no map." % path)
		return
	var instance := packed.instantiate() as Node3D
	map_root.add_child(instance)

	kill_plane = instance.find_child("KillPlane", true, false) as KillPlane
	_publish_playable_extent(instance)

	var points := instance.get_node_or_null("SpawnPoints")
	if points == null:
		push_warning("main.gd: map '%s' has no SpawnPoints; using the fallback ring." % path)
		return
	for slot in range(4):
		var marker := points.get_node_or_null("Spawn%d" % slot) as Marker3D
		if marker == null:
			push_warning("main.gd: map '%s' has no SpawnPoints/Spawn%d; using the fallback ring." % [path, slot])
			_map_spawns.clear()
			return
		_map_spawns.append(marker.transform)


const SAFE_ZONE_MARGIN: float = 2.0
const DEFENDER_START_OFFSET: float = 2.5
const SPAWN_START_HEIGHT: float = 1.0

const ATTACKER_SPAWN_SPACING: float = 1.8



func _publish_playable_extent(map: Node3D) -> void:
	var bounds := map.get_node_or_null("Bounds")
	if bounds == null:
		return
	var half_x := INF
	var half_z := INF
	for child in bounds.get_children():
		var body := child as Node3D
		if body == null:
			continue
		var here := body.position
		if absf(here.x) > absf(here.z):
			half_x = minf(half_x, absf(here.x))
		elif absf(here.z) > 0.01:
			half_z = minf(half_z, absf(here.z))
	if is_finite(half_x) and half_x > 0.5:
		CharacterBase.playable_half_x = half_x
	if is_finite(half_z) and half_z > 0.5:
		CharacterBase.playable_half_z = half_z
	print("[main] playable extent x=%.2f z=%.2f (walls, measured)"
		% [CharacterBase.playable_half_x, CharacterBase.playable_half_z])

func _role_spawn_point(role_index: int) -> Vector3:
	if role_index <= 0:
		return Vector3(0.0, SPAWN_START_HEIGHT, -DEFENDER_START_OFFSET)
	var ring: float = CharacterBase.confinement_radius + SAFE_ZONE_MARGIN
	var offset := (float(role_index) - 2.0) * ATTACKER_SPAWN_SPACING
	return Vector3(offset, SPAWN_START_HEIGHT, ring)

func _role_spawn_yaw(role_index: int) -> float:
	var here := _role_spawn_point(role_index)
	var delta := -Vector3(here.x, 0.0, here.z)
	if delta.length() < 0.01:
		return 0.0
	return atan2(-delta.x, -delta.z)

func _place_at_spawn(character: CharacterBase, role_index: int) -> void:
	character.position = _role_spawn_point(role_index)
	character.rotation = Vector3(0.0, _role_spawn_yaw(role_index), 0.0)
	_seat_on_floor(character)
	character.begin_spawn_settle()
	character.snap_visual_interpolation()

const SPAWN_FLOOR_PROBE_HEIGHT: float = 2.0
const SPAWN_FLOOR_PROBE_DEPTH: float = 6.0
const SPAWN_FLOOR_CLEARANCE: float = 0.02

func _seat_on_floor(character: CharacterBase) -> void:
	var space := character.get_world_3d().direct_space_state
	var from := character.global_position + Vector3.UP * SPAWN_FLOOR_PROBE_HEIGHT
	var to := from + Vector3.DOWN * SPAWN_FLOOR_PROBE_DEPTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [character.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	character.global_position.y = (hit["position"] as Vector3).y 		+ character.capsule_height() * 0.5 + SPAWN_FLOOR_CLEARANCE

var _dedicated: bool = false
var _host_port: int = NetworkManagerScript.DEFAULT_PORT

var _spawned_peer_ids: Dictionary = {}
var _token_join_index: Dictionary = {}
var _peer_slots: Dictionary = {}
var _seat_prop_picks: Dictionary = {}
var _spawned_characters: Dictionary = {}
var _index_to_character: Dictionary = {}

var _pending_reclaims: Dictionary = {}

func _ready() -> void:
	MatchManager.reset()
	RoundManager.reset()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_load_map()
	spawner.spawn_function = _build_networked_character
	MatchManager.round_started.connect(_on_match_round_started)
	MatchManager.round_intermission_started.connect(_on_round_intermission_started)
	MatchManager.match_won.connect(_on_match_won_freeze_physics)
	if kill_plane != null:
		kill_plane.character_respawned.connect(_on_character_respawned)
	pause_root.visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_return_to_menu_pressed)
	settings_button.pressed.connect(func() -> void:
		AudioManager.play("ui_click")
		pause_root.hide()
		settings_panel.show())
	settings_panel.back_pressed.connect(func() -> void: settings_panel.hide(); pause_root.show())
	pause_layer.toggle_requested.connect(_on_pause_toggle_requested)

	var join_target := ""
	var should_host := false
	if GameLaunch.pending_action != "":
		should_host = GameLaunch.pending_action == "host"
		if GameLaunch.pending_action == "join":
			join_target = GameLaunch.pending_join_address
		GameLaunch.reset()
	else:
		for arg in OS.get_cmdline_user_args():
			if arg == "--host":
				should_host = true
			elif arg == "--dedicated":
				should_host = true
				_dedicated = true
			elif arg.begins_with("--port="):
				var port_text := arg.substr(len("--port="))
				if port_text.is_valid_int():
					_host_port = int(port_text)
				else:
					push_error("main: --port= needs a number, got '%s'" % port_text)
			elif arg.begins_with("--join="):
				join_target = arg.substr(len("--join="))
			elif arg == "--spectate":
				GameLaunch.spectator = true

	if should_host:
		_start_hosting()
	elif join_target != "":
		_start_joining(join_target)
	else:
		_start_local_test()

func _start_local_test() -> void:
	_local_roster = players.duplicate()
	for i in range(_local_roster.size()):
		_local_roster[i].player_slot = i
		_local_roster[i].player_id = i + 1
	var picked_unit := _local_unit_for_seat(GameLaunch.solo_seat)
	picked_unit.character_index = GameLaunch.character_index()
	picked_unit.player_name = SettingsManager.player_name
	_refresh_ai_prop_picks()
	_refresh_seat_prop_picks()
	var opening_defender := MatchManager.defender_slot_for(1)
	var attacker_index := 0
	for character in _local_roster:
		character.is_defender = character.player_slot == opening_defender
		var role_index := 0
		if not character.is_defender:
			attacker_index += 1
			role_index = attacker_index
		var unit_visual: Node = character.get_node_or_null("Visual")
		if unit_visual != null and unit_visual.has_method("apply"):
			unit_visual.apply(character.is_person, character.is_can, character.player_slot)
		_place_at_spawn(character, role_index)
		character.spawn_position = character.position
		RoundManager.register_player(character)
	RoundManager.lata = lata
	_wire_downed_flash(lata)
	var human := _local_unit_for_seat(GameLaunch.solo_seat)
	_give_human_player_one(human)
	for character in _local_roster:
		character.is_bot = character != human
		_attach_ai(character, character != human)
		character.add_to_group("spectatable")
	if GameLaunch.spectator:
		if human.ai_controller != null:
			human.ai_controller.set_enabled(true)
		human.input_parked = true
		_enter_spectator_mode()
		_reassert_spectated_bots.call_deferred()
	else:
		var default_rig := human.get_node("CameraRig") as CameraRig
		default_rig.set_active(true)
		default_rig.set_aim_source(CameraRig.AimSource.MOUSE)
	_push_pre_round_prop_skins()
	_awaiting_local_ready = true
	hud.show_ready_prompt(true)
	if GameLaunch.spectator:
		_run_ready_countdown.call_deferred()

func _local_unit_for_seat(seat: int) -> CharacterBase:
	if seat < 0 or seat >= _local_roster.size():
		return _local_roster[0]
	return _local_roster[seat]

func _give_human_player_one(human: CharacterBase) -> void:
	if human.player_id == 1:
		return
	for character in _local_roster:
		if character.player_id == 1:
			character.player_id = human.player_id
			break
	human.player_id = 1

var _spectator: SpectatorCamera = null

func _reassert_spectated_bots() -> void:
	for character in _local_roster:
		if not is_instance_valid(character):
			continue
		if character.ai_controller != null:
			character.ai_controller.set_enabled(true)
		character.input_parked = true
		var rig := character.get_node_or_null("CameraRig") as CameraRig
		if rig != null:
			rig.set_active(false)
	_dress_spectated_units()

func _dress_spectated_units() -> void:
	_refresh_ai_prop_picks()
	_refresh_seat_prop_picks()


func _on_provisional_spectator_changed(spectating: bool) -> void:
	if spectating:
		_enter_spectator_mode()
	else:
		_exit_spectator_mode()

func _exit_spectator_mode() -> void:
	if _spectator == null or not is_instance_valid(_spectator):
		return
	_spectator.queue_free()
	_spectator = null
	hud.exit_spectator_mode()

func free_seat_count() -> int:
	var free := 0
	for index in range(NetworkManager.MAX_PLAYERS):
		if _seat_is_taken(index):
			continue
		var seat_body: CharacterBase = _index_to_character.get(index)
		if seat_body == null or not is_instance_valid(seat_body):
			continue
		if seat_body.is_bot:
			free += 1
	return free

func _promote_waiting_spectators() -> void:
	if not NetworkManager.is_host():
		return
	if NetworkManager.waiting_seat_tokens.is_empty():
		return
	var seats := free_seat_count()
	for token in NetworkManager.take_promotable_tokens(seats):
		var peer_id := NetworkManager.peer_id_for_token(String(token))
		if peer_id == 0:
			continue
		NetworkManager.seat_provisional_spectator(peer_id)
		_spawned_peer_ids.erase(peer_id)
		_spawn_player(peer_id)
		print("[main] promoted waiting spectator peer %d into a seat" % [peer_id])

func _enter_spectator_mode() -> void:
	if _spectator != null and is_instance_valid(_spectator):
		return
	_spectator = SpectatorCamera.new()
	_spectator.name = "Spectator"
	add_child(_spectator)
	hud.enter_spectator_mode(_spectator)

func _unhandled_input(event: InputEvent) -> void:
	if _counting_down or not event.is_action_pressed("ready_up"):
		return
	if _awaiting_local_ready:
		get_viewport().set_input_as_handled()
		for character in _local_roster:
			if is_instance_valid(character) and character.is_person:
				character.play_visual_action("ready")
		_run_ready_countdown()
	elif _awaiting_net_ready:
		get_viewport().set_input_as_handled()
		_rpc_declare_ready.rpc_id(1)


func _enter_net_ready_phase() -> void:
	if not NetworkManager.is_host():
		return
	_net_ready_peers.clear()
	_rpc_ready_phase.rpc(true, 0, _expected_ready_count())

func _expected_ready_count() -> int:
	return NetworkManager.playing_peer_count()

@rpc("any_peer", "call_local", "reliable")
func _rpc_declare_ready() -> void:
	if not NetworkManager.is_host():
		return
	if not _awaiting_net_ready:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if NetworkManager.is_spectator(sender) and sender != multiplayer.get_unique_id():
		return
	_net_ready_peers[sender] = true
	var ready_count: int = _net_ready_peers.size()
	var expected := _expected_ready_count()
	_rpc_ready_phase.rpc(true, ready_count, expected)
	if ready_count >= expected:
		_rpc_begin_ready_countdown.rpc()

@rpc("authority", "call_local", "reliable")
func _rpc_ready_phase(active: bool, ready_count: int, expected: int) -> void:
	_awaiting_net_ready = active
	if not active:
		hud.show_ready_prompt(false)
		return
	if ready_count > 0:
		for character in _all_characters():
			if character.is_person:
				character.play_visual_action("ready")
	hud.show_ready_prompt(true,
		"Walk around freely.  %d / %d ready  ·  press [R]" % [ready_count, expected])

@rpc("authority", "call_local", "reliable")
func _rpc_begin_ready_countdown() -> void:
	if _counting_down:
		return
	_awaiting_net_ready = false
	if NetworkManager.is_host():
		_refresh_ai_prop_picks()
		_refresh_seat_prop_picks()
		_rpc_sync_picks.rpc(_picks_table())
	_run_ready_countdown()

func _run_ready_countdown() -> void:
	_counting_down = true
	hud.show_ready_prompt(false)
	for tick in ["3", "2", "1"]:
		hud.show_countdown_tick(tick)
		await get_tree().create_timer(1.0).timeout
	hud.show_countdown_tick("GO!")
	await get_tree().create_timer(0.5).timeout
	hud.hide_countdown()
	_awaiting_local_ready = false
	_awaiting_net_ready = false
	_counting_down = false
	MatchManager.begin_next_round()


func _start_hosting() -> void:
	_clear_local_test_characters()
	if not NetworkManager.is_networked():
		if NetworkManager.host_game(_host_port, _dedicated) != OK:
			return
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.player_identified.connect(_on_player_identified)
	NetworkManager.match_in_progress = true
	NetworkManager.publish_picks()
	for id in NetworkManager.connected_peer_ids:
		_spawn_player(id)
	_fill_empty_slots_with_placeholders()
	_push_pre_round_prop_skins()
	_enter_net_ready_phase()

func _start_joining(address: String) -> void:
	_clear_local_test_characters()
	if GameLaunch.spectator or NetworkManager.provisional_spectator:
		_enter_spectator_mode()
	NetworkManager.provisional_spectator_changed.connect(_on_provisional_spectator_changed)
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	if NetworkManager.is_networked():
		NetworkManager.publish_picks()
		_rpc_client_ready_for_spawn.rpc_id(1)
		return
	var parts := MultiplayerSetupScreen.split_address(address)
	var host: String = String(parts[0])
	var port: int = int(parts[1])
	if host.is_empty() or port <= 0 or port > 65535:
		_bail_to_browser("Could not read the address '%s'." % address)
		return
	NetworkManager.connection_succeeded.connect(_on_joined_ready_for_spawn, CONNECT_ONE_SHOT)
	if NetworkManager.join_game(host, port) != OK:
		NetworkManager.connection_succeeded.disconnect(_on_joined_ready_for_spawn)
		_bail_to_browser("Could not reach %s." % address)

func _on_joined_ready_for_spawn() -> void:
	_rpc_client_ready_for_spawn.rpc_id(1)

func _clear_local_test_characters() -> void:
	RoundManager.clear_players()
	for character in players:
		if is_instance_valid(character):
			character.queue_free()
	_local_roster.clear()

func _on_player_connected(peer_id: int) -> void:
	if NetworkManager.is_host():
		_try_late_join(peer_id)

func _on_player_identified(peer_id: int, _token: String) -> void:
	if NetworkManager.is_host():
		_try_late_join(peer_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_ready_for_spawn() -> void:
	if not NetworkManager.is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	_try_late_join(sender)
	_rpc_sync_picks.rpc_id(sender, _picks_table())
	_push_pre_round_prop_skins()


func _refresh_ai_prop_picks() -> void:
	var seats := _seat_characters()
	_release_bot_picks_colliding_with_humans(seats)
	var taken: Array[int] = []
	for slot in range(NetworkManagerScript.MAX_PLAYERS):
		var who: CharacterBase = seats.get(slot)
		if who != null and who.character_index >= 0:
			taken.append(who.character_index)
	for slot in range(NetworkManagerScript.MAX_PLAYERS):
		var who: CharacterBase = seats.get(slot)
		if who == null or who.character_index >= 0:
			continue
		var pick := _ai_character_index(slot, taken)
		taken.append(pick)
		who.character_index = pick
		var visual: Node = who.get_node_or_null("Visual")
		if visual != null and visual.has_method("apply"):
			visual.apply(who.is_person, who.is_can, who.player_slot)


func _release_bot_picks_colliding_with_humans(seats: Dictionary) -> void:
	var human_picks: Array[int] = []
	for slot in seats:
		var who: CharacterBase = seats[slot]
		if who == null or not is_instance_valid(who):
			continue
		if who.is_bot or who.is_ai_driven():
			continue
		if who.character_index >= 0:
			human_picks.append(who.character_index)
	if human_picks.is_empty():
		return
	for slot in seats:
		var who: CharacterBase = seats[slot]
		if who == null or not is_instance_valid(who):
			continue
		if not (who.is_bot or who.is_ai_driven()):
			continue
		if who.character_index in human_picks:
			who.character_index = -1

const AI_PERSON_SPREAD: Array[int] = [0, 3, 6, 9]

func _ai_character_index(slot: int, taken: Array[int]) -> int:
	var size := CharacterRoster.ROSTER.size()
	if size <= 0:
		return 0
	var start: int = AI_PERSON_SPREAD[slot % AI_PERSON_SPREAD.size()] % size
	for step in range(size):
		var candidate := (start + step) % size
		if not (candidate in taken):
			return candidate
	return start


func _seat_characters() -> Dictionary:
	var seats: Dictionary = {}
	for character in _local_roster:
		if character != null and is_instance_valid(character):
			seats[int(character.player_slot)] = character
	for index in _index_to_character:
		var character: CharacterBase = _index_to_character[index]
		if character != null and is_instance_valid(character):
			seats[int(index)] = character
	return seats

func _picks_table() -> Array:
	var table: Array = []
	for index in _index_to_character:
		var character: CharacterBase = _index_to_character[index]
		if character == null or not is_instance_valid(character):
			continue
		var props: Dictionary = _seat_prop_picks.get(index, {})
		table.append([int(index), character.character_index, character.player_name,
			int(props.get("can", -1)), int(props.get("slipper", -1))])
	return table

var _known_picks: Dictionary = {}

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_picks(table: Array) -> void:
	for row in table:
		if typeof(row) != TYPE_ARRAY or (row as Array).size() < 2:
			continue
		var index := int(row[0])
		_known_picks[index] = row
		var character: CharacterBase = _index_to_character.get(index)
		if character != null and is_instance_valid(character):
			_apply_known_picks(character, index)

func _apply_known_picks(character: CharacterBase, index: int) -> void:
	var row: Array = _known_picks.get(index, [])
	if row.size() < 2:
		return
	var owned_by_me := character.is_multiplayer_authority() and not character.is_bot
	if int(row[1]) >= 0 and not owned_by_me:
		character.character_index = int(row[1])
	if row.size() >= 3:
		var told_name := SettingsManagerScript.sanitise_name(String(row[2]))
		if told_name != "":
			character.player_name = told_name
	var visual: Node = character.get_node_or_null("Visual")
	if visual != null and visual.has_method("apply"):
		visual.apply(character.is_person, character.is_can, character.player_slot)
	if row.size() >= 5:
		var can := int(row[3])
		var slipper := int(row[4])
		if can >= 0 or slipper >= 0:
			_seat_prop_picks[index] = {"can": can, "slipper": slipper}

func _apply_own_pick(character: CharacterBase) -> void:
	if character == null or not is_instance_valid(character):
		return
	var mine := GameLaunch.character_index()
	if mine >= 0:
		character.character_index = mine

func _try_late_join(peer_id: int) -> void:
	if _spawned_peer_ids.has(peer_id):
		return
	if not NetworkManager.peer_tokens.has(peer_id):
		return
	_spawn_player(peer_id)
	_sync_state_to_late_joiner.rpc_id(
		peer_id, MatchManager.round_number, MatchManager.defender_slot,
		MatchManager.scores, RoundManager.time_left, RoundManager.round_active,
		lata != null and lata.is_upright
	)
	_rpc_sync_picks.rpc_id(peer_id, _picks_table())
	_sync_slipper_carry_to_late_joiner(peer_id)
	_refresh_ai_prop_picks()
	_refresh_seat_prop_picks()
	if _awaiting_net_ready:
		_rpc_ready_phase.rpc(true, _net_ready_peers.size(), _expected_ready_count())
	else:
		_rpc_ready_phase.rpc_id(peer_id, false, 0, 0)

func _on_character_respawned(character: CharacterBase) -> void:
	if not NetworkManager.is_networked() or character.is_multiplayer_authority():
		hud.show_toast("OUT OF BOUNDS")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if not is_node_ready():
			return
		if pause_root.visible or match_result.visible or settings_panel.visible:
			return
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_player_disconnected(peer_id: int) -> void:
	if not NetworkManager.is_host():
		return
	if _awaiting_net_ready:
		_net_ready_peers.erase(peer_id)
		var expected := _expected_ready_count()
		_rpc_ready_phase.rpc(true, _net_ready_peers.size(), expected)
		if _net_ready_peers.size() >= expected:
			_rpc_begin_ready_countdown.rpc()
	var character: CharacterBase = _spawned_characters.get(peer_id)
	var index := _index_for_character(character) if character != null else -1
	if index != -1:
		_rpc_convert_to_ai.rpc(index)
		_rpc_show_toast.rpc("A player left — a bot has taken over their character")
	else:
		_rpc_show_toast.rpc("A player left the match — their character will hold position until they reconnect")
	_recycle_dedicated_lobby_if_abandoned()


const MATCH_SETUP_SCENE_PATH: String = "res://scenes/ui/MatchSetup.tscn"

const DEDICATED_POST_MATCH_SECONDS: float = 120.0

const DEDICATED_EVICT_BACKSTOP: float = 3.0

var _post_match_timer: SceneTreeTimer = null
var _recycling: bool = false

func _is_dedicated_referee() -> bool:
	return NetworkManager.is_dedicated and NetworkManager.is_host()

func _recycle_dedicated_lobby_if_abandoned() -> void:
	if not _is_dedicated_referee():
		return
	if not NetworkManager.connected_peer_ids.is_empty():
		return
	_recycle_dedicated_lobby()

func _arm_post_match_reset() -> void:
	if not _is_dedicated_referee():
		return
	var timer := get_tree().create_timer(DEDICATED_POST_MATCH_SECONDS)
	_post_match_timer = timer
	timer.timeout.connect(_on_post_match_window_elapsed.bind(timer))

func _on_post_match_window_elapsed(timer: SceneTreeTimer) -> void:
	if _post_match_timer != timer:
		return
	_post_match_timer = null
	_close_finished_dedicated_match()

func _disarm_post_match_reset() -> void:
	_post_match_timer = null

func _close_finished_dedicated_match() -> void:
	if not _is_dedicated_referee():
		return
	if NetworkManager.connected_peer_ids.is_empty():
		_recycle_dedicated_lobby()
		return
	_rpc_show_toast.rpc("The match is over — this lobby is going back to its waiting room.")
	await NetworkManager.announce_host_leaving()
	if not is_inside_tree():
		return
	_evict_and_recycle()

func _evict_and_recycle() -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet != null:
		for peer_id in NetworkManager.connected_peer_ids.duplicate():
			enet.disconnect_peer(int(peer_id))
	get_tree().create_timer(DEDICATED_EVICT_BACKSTOP).timeout.connect(_recycle_dedicated_lobby)

func _recycle_dedicated_lobby() -> void:
	if _recycling or not _is_dedicated_referee():
		return
	if not NetworkManager.connected_peer_ids.is_empty():
		return
	_recycling = true
	_disarm_post_match_reset()
	get_tree().paused = false
	NetworkManager.match_in_progress = false
	NetworkManager.join_code = NetworkManager._mint_join_code()
	NetworkManager.join_code_changed.emit(NetworkManager.join_code)
	NetworkManager.peer_tokens.clear()
	NetworkManager.peer_characters.clear()
	NetworkManager.lobby_leader_id = 0
	GameLaunch.clear_seating()
	MatchManager.reset()
	RoundManager.reset()
	print("main: dedicated lobby recycled — back to the waiting room, code %s." % [
		NetworkManager.join_code])
	get_tree().change_scene_to_file(MATCH_SETUP_SCENE_PATH)

func _index_for_character(character: CharacterBase) -> int:
	for index in _index_to_character:
		if _index_to_character[index] == character:
			return index
	return -1

func _spawn_player(peer_id: int) -> void:
	if _spawned_peer_ids.has(peer_id):
		return
	var token: String = NetworkManager.peer_tokens.get(peer_id, "")
	if token == "":
		push_warning("main.gd: _spawn_player(%d) called with no registered token; skipping." % peer_id)
		return
	if NetworkManager.is_spectator(peer_id):
		_spawned_peer_ids[peer_id] = true
		if peer_id == multiplayer.get_unique_id():
			_enter_spectator_mode()
		return
	_spawned_peer_ids[peer_id] = true
	var index := _claim_join_index(token)
	var existing_character: CharacterBase = _index_to_character.get(index)
	if existing_character != null and is_instance_valid(existing_character):
		_rpc_reclaim_character.rpc(index, peer_id)
		return
	spawner.spawn(_build_spawn_data(peer_id, index))

func _claim_join_index(token: String) -> int:
	if _token_join_index.has(token):
		return _token_join_index[token]
	var seat: int = int(GameLaunch.seat_tokens.get(token, -1))
	if seat < 0 or seat >= NetworkManager.MAX_PLAYERS or _seat_is_taken(seat):
		seat = _first_free_seat()
	_token_join_index[token] = seat
	return seat

func _seat_is_taken(seat: int) -> bool:
	return _token_join_index.values().has(seat)

func _apply_reclaimed_picks(character: CharacterBase, new_peer_id: int) -> void:
	var picks := {}
	if NetworkManager.is_host():
		picks = NetworkManager.picks_for(new_peer_id)
	if new_peer_id == multiplayer.get_unique_id():
		picks = {"character": GameLaunch.character_index()}
	if picks.is_empty():
		return
	var person := int(picks.get("character", -1))
	if person >= 0:
		character.character_index = person


func _first_free_seat() -> int:
	for seat in range(NetworkManager.MAX_PLAYERS):
		if not _seat_is_taken(seat):
			return seat
	return 0

static func _seat_of(slot: int) -> int:
	return slot

func _build_spawn_data(peer_id: int, index: int) -> Dictionary:
	var slot := index
	var opening_defender := MatchManager.defender_slot_for(maxi(1, MatchManager.round_number))
	var is_defender := slot == opening_defender
	var role_index := 0
	if not is_defender:
		role_index = 1 + (slot if slot < opening_defender else slot - 1)
	return {
		"peer_id": peer_id,
		"position": _role_spawn_point(role_index),
		"yaw": _role_spawn_yaw(role_index),
		"is_defender": is_defender,
		"player_slot": slot,
		"player_id": slot + 1,
		"name": SettingsManagerScript.sanitise_name(
			String(NetworkManager.picks_for(peer_id).get("name", ""))),
		"character": int(NetworkManager.picks_for(peer_id).get("character", -1)),
	}

func _fill_empty_slots_with_placeholders() -> void:
	for index in range(NetworkManager.MAX_PLAYERS):
		var existing_character: CharacterBase = _index_to_character.get(index)
		if existing_character != null and is_instance_valid(existing_character):
			continue
		var sentinel_peer_id := -1 - index
		_spawned_peer_ids[sentinel_peer_id] = true
		spawner.spawn(_build_spawn_data(sentinel_peer_id, index))
	if NetworkManager.is_host():
		_refresh_ai_prop_picks()


func _build_networked_character(data: Dictionary) -> Node:
	var character: CharacterBase = CHARACTER_SCENE.instantiate()
	character.name = str(data["peer_id"])
	character.position = data["position"]
	character.spawn_position = data["position"]
	character.rotation = Vector3(0.0, float(data["yaw"]), 0.0)
	character.is_defender = data["is_defender"]
	character.player_slot = data["player_slot"]
	character.player_id = data["player_id"]
	var picks := NetworkManager.picks_for(int(data["peer_id"]))
	var person := int(data.get("character", picks.get("character", -1)))
	if person >= 0:
		character.character_index = person
	if int(data["peer_id"]) == multiplayer.get_unique_id():
		_apply_own_pick.call_deferred(character)
	character.player_name = SettingsManagerScript.sanitise_name(
		String(data.get("name", picks.get("name", ""))))
	var peer_id: int = data["peer_id"]
	var is_ai := peer_id < 0
	character.set_multiplayer_authority(1 if is_ai else peer_id)
	_peer_slots[peer_id] = data["player_slot"]
	_spawned_characters[peer_id] = character
	var index: int = _seat_of(int(data["player_slot"]))
	_index_to_character[index] = character
	RoundManager.register_player(character)
	_apply_known_picks(character, index)
	if _pending_reclaims.has(index):
		var reclaim_peer: int = _pending_reclaims[index]
		_pending_reclaims.erase(index)
		_apply_reclaim.call_deferred(character, index, reclaim_peer)
	character.is_bot = is_ai
	if is_ai and NetworkManager.is_host():
		_attach_ai(character)
	character.add_to_group("spectatable")
	return character

func _on_match_round_started(_round_number: int, defender_slot: int) -> void:
	_disarm_post_match_reset()
	_promote_waiting_spectators()
	_reset_world(defender_slot)
	RoundManager.start_round()
	_equip_owned_slippers.call_deferred()


func _equip_owned_slippers() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if not RoundManager.round_active:
		return
	for slipper in slippers:
		if not is_instance_valid(slipper) or slipper.owner_slot < 0:
			continue
		var owner := RoundManager.player_at(slipper.owner_slot)
		if owner == null or owner.is_defender:
			continue
		slipper.global_position = owner.global_position
		slipper.host_force_equip(owner)

func _reset_world(defender_slot: int) -> void:
	for node in get_tree().get_nodes_in_group("hazard_zone"):
		if is_instance_valid(node):
			node.queue_free()

	var roster := _all_characters()
	RoundManager.clear_players()

	for i in range(roster.size()):
		roster[i].position = Vector3(0.0, 500.0 + i * 20.0, 0.0)

	var attacker_index := 0
	for character in roster:
		character.is_defender = character.player_slot == defender_slot
		var role_index := 0
		if not character.is_defender:
			attacker_index += 1
			role_index = attacker_index
		character.reset_for_new_round()
		_place_at_spawn(character, role_index)
		character.spawn_position = character.position
		RoundManager.register_player(character)

	RoundManager.lata = lata
	if lata != null:
		lata.host_reset_for_new_round()

	_reset_slippers(roster, defender_slot)
	NetworkManager.publish_picks()
	_refresh_seat_prop_picks()
	_push_prop_skins(defender_slot)

func _push_pre_round_prop_skins() -> void:
	NetworkManager.publish_picks()
	_refresh_seat_prop_picks()
	_push_prop_skins(MatchManager.defender_slot_for(maxi(1, MatchManager.round_number)))

func _push_prop_skins(defender_slot: int) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var can_pick := int(_seat_prop_picks.get(defender_slot, {}).get("can", -1))
	var slipper_skins: Dictionary = {}
	for slipper in slippers:
		if not is_instance_valid(slipper):
			continue
		var owner: int = slipper.owner_slot
		slipper_skins[slipper.name] = int(_seat_prop_picks.get(owner, {}).get("slipper", -1))
	if NetworkManager.is_networked():
		_rpc_prop_skins.rpc(can_pick, slipper_skins)
	else:
		_apply_prop_skins(can_pick, slipper_skins)

@rpc("authority", "call_local", "reliable")
func _rpc_prop_skins(can_pick: int, slipper_skins: Dictionary) -> void:
	_apply_prop_skins(can_pick, slipper_skins)

func _apply_prop_skins(can_pick: int, slipper_skins: Dictionary) -> void:
	if lata != null and is_instance_valid(lata):
		lata.apply_skin(can_pick)
	for slipper in slippers:
		if is_instance_valid(slipper) and slipper_skins.has(slipper.name):
			slipper.apply_skin(int(slipper_skins[slipper.name]))

func _refresh_seat_prop_picks() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var seats := _seat_characters()
	var taken_cans: Array[int] = []
	var taken_slippers: Array[int] = []
	for slot in _seat_prop_picks:
		var existing: Dictionary = _seat_prop_picks[slot]
		taken_cans.append(int(existing.get("can", -1)))
		taken_slippers.append(int(existing.get("slipper", -1)))
	for slot in range(NetworkManagerScript.MAX_PLAYERS):
		if seats.get(slot) == null:
			continue
		var human_picks: Variant = _human_prop_picks_for_slot(slot)
		if human_picks != null:
			_seat_prop_picks[slot] = human_picks
			continue
		if _seat_prop_picks.has(slot):
			continue
		var can := _ai_prop_index(CharacterRoster.CANS.size(), taken_cans)
		var slipper := _ai_prop_index(CharacterRoster.SLIPPERS.size(), taken_slippers)
		taken_cans.append(can)
		taken_slippers.append(slipper)
		_seat_prop_picks[slot] = {"can": can, "slipper": slipper}

func _human_prop_picks_for_slot(slot: int) -> Variant:
	if not NetworkManager.is_networked():
		if slot == GameLaunch.solo_seat:
			return {"can": GameLaunch.can_index(), "slipper": GameLaunch.slipper_index()}
		return null
	for peer_id in _peer_slots:
		if int(_peer_slots[peer_id]) != slot:
			continue
		var picks := NetworkManager.picks_for(peer_id)
		var can := int(picks.get("can", -1))
		var slipper := int(picks.get("slipper", -1))
		return {"can": can, "slipper": slipper} if can >= 0 or slipper >= 0 else null
	return null

func _ai_prop_index(size: int, taken: Array[int]) -> int:
	if size <= 0:
		return 0
	var available: Array[int] = []
	for i in range(size):
		if not (i in taken):
			available.append(i)
	if available.is_empty():
		return randi() % size
	return available[randi() % available.size()]

func _reset_slippers(roster: Array[CharacterBase], defender_slot: int) -> void:
	for slipper in slippers:
		if is_instance_valid(slipper):
			slipper.host_reset_for_new_round()
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var attackers: Array[int] = []
	for slot in range(NetworkManagerScript.MAX_PLAYERS):
		if slot != defender_slot:
			attackers.append(slot)
	for index in range(slippers.size()):
		var slipper := slippers[index]
		if not is_instance_valid(slipper):
			continue
		slipper.host_assign_owner(attackers[index] if index < attackers.size() else -1)
	for index in range(slippers.size()):
		if index >= attackers.size():
			break
		var slipper := slippers[index]
		if not is_instance_valid(slipper):
			continue
		var character := _character_in_seat(roster, attackers[index])
		if character == null:
			continue
		slipper.global_position = character.global_position
		slipper.host_grab(character)


func _character_in_seat(roster: Array[CharacterBase], slot: int) -> CharacterBase:
	for character in roster:
		if is_instance_valid(character) and character.player_slot == slot:
			return character
	return null

func _on_round_intermission_started(_next_round_number: int, next_defender_slot: int) -> void:
	_reset_world(next_defender_slot)

func _on_match_won_freeze_physics(_winning_team: int) -> void:
	for character in _all_characters():
		character.velocity = Vector3.ZERO
	_arm_post_match_reset()

func _all_characters() -> Array[CharacterBase]:
	var result: Array[CharacterBase] = []
	if NetworkManager.is_networked():
		for character in _spawned_characters.values():
			if is_instance_valid(character):
				result.append(character)
	else:
		for character in _local_roster:
			if is_instance_valid(character):
				result.append(character)
	return result

@rpc("authority", "call_remote", "reliable")
func _sync_state_to_late_joiner(new_round_number: int, new_defender_slot: int,
		new_scores: Array, new_time_left: float, new_round_active: bool,
		new_lata_upright: bool) -> void:
	MatchManager.round_number = new_round_number
	MatchManager.defender_slot = new_defender_slot
	for slot in range(mini(MatchManager.scores.size(), new_scores.size())):
		MatchManager.scores[slot] = int(new_scores[slot])
	RoundManager.time_left = new_time_left
	RoundManager.round_active = new_round_active
	RoundManager.lata = lata
	if lata != null:
		lata.adopt_state(new_lata_upright, lata.home_position)
	hud.set_round_display(new_round_number, new_defender_slot)

func _sync_slipper_carry_to_late_joiner(peer_id: int) -> void:
	for index in range(slippers.size()):
		var slipper := slippers[index]
		if not is_instance_valid(slipper) or slipper.state != Slipper.CarryState.CARRIED:
			continue
		var holder := slipper.carrier
		if holder == null or not is_instance_valid(holder):
			continue
		_rpc_slipper_grabbed.rpc_id(peer_id, index, holder.player_slot)


func get_local_character() -> CharacterBase:
	for peer_id in _spawned_characters:
		var character = _spawned_characters[peer_id]
		if character is CharacterBase and is_instance_valid(character) \
				and character.is_multiplayer_authority() and character.ai_controller == null:
			return character
	return null

@rpc("authority", "call_local", "reliable")
func _rpc_show_toast(text: String) -> void:
	hud.show_toast(text)

func _wire_downed_flash(target: Lata) -> void:
	if target == null:
		return
	target.upright_changed.connect(func(now_upright: bool) -> void:
		hud.set_downed_flash(not now_upright)
	)

func _attach_ai(character: CharacterBase, enabled: bool = true) -> void:
	var controller := AIController.new()
	character.add_child(controller)
	character.ai_controller = controller
	if not enabled:
		controller.set_enabled(false)

func _on_pause_toggle_requested() -> void:
	if match_result.visible:
		return
	pause_root.visible = not pause_root.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause_root.visible else Input.MOUSE_MODE_CAPTURED
	var overlay_only := NetworkManager.is_networked() and not NetworkManager.is_solo_session()
	paused_note_label.visible = overlay_only
	if not overlay_only:
		get_tree().paused = pause_root.visible

func _on_resume_pressed() -> void:
	AudioManager.play("ui_back")
	pause_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false

func _on_return_to_menu_pressed() -> void:
	AudioManager.play("ui_back")
	get_tree().paused = false
	if NetworkManager.is_networked():
		if NetworkManager.is_host():
			await NetworkManager.announce_host_leaving()
		NetworkManager.disconnect_network()
	MatchManager.reset()
	RoundManager.reset()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_server_disconnected() -> void:
	_bail_to_browser("Host ended the match.")

func _on_connection_failed() -> void:
	_bail_to_browser("Could not reach that host.")

func _bail_to_browser(message: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MatchManager.reset()
	RoundManager.reset()
	GameLaunch.reset()
	GameLaunch.pending_status_message = message
	get_tree().change_scene_to_file("res://scenes/ui/MultiplayerSetup.tscn")

@rpc("authority", "call_local", "reliable")
func _rpc_convert_to_ai(index: int) -> void:
	var character: CharacterBase = _index_to_character.get(index)
	if character == null or not is_instance_valid(character):
		return
	for old_peer_id in _spawned_characters.keys():
		if _spawned_characters[old_peer_id] == character:
			_spawned_characters.erase(old_peer_id)
			_peer_slots.erase(old_peer_id)
			_spawned_peer_ids.erase(old_peer_id)
			break
	var sentinel_peer_id := -1 - index
	character.name = str(sentinel_peer_id)
	character.set_multiplayer_authority(1)
	character.player_id = index + 1
	_spawned_characters[sentinel_peer_id] = character
	_peer_slots[sentinel_peer_id] = character.player_slot
	_spawned_peer_ids[sentinel_peer_id] = true
	character.is_bot = true
	if NetworkManager.is_host() and character.ai_controller == null:
		_attach_ai(character)
	_refresh_rig_ownership(character)

@rpc("authority", "call_local", "reliable")
func _rpc_reclaim_character(index: int, new_peer_id: int) -> void:
	var character: CharacterBase = _index_to_character.get(index)
	if character == null or not is_instance_valid(character):
		_pending_reclaims[index] = new_peer_id
		return
	_apply_reclaim(character, index, new_peer_id)


@rpc("authority", "call_local", "reliable")
func _rpc_slipper_owner(slipper_index: int, slot: int) -> void:
	if slipper_index < 0 or slipper_index >= slippers.size():
		return
	slippers[slipper_index]._apply_owner(slot)

@rpc("authority", "call_local", "reliable")
func _rpc_slipper_grabbed(slipper_index: int, slot: int) -> void:
	if slipper_index < 0 or slipper_index >= slippers.size():
		return
	slippers[slipper_index]._apply_grabbed(slot)

@rpc("authority", "call_local", "reliable")
func _rpc_slipper_thrown(slipper_index: int, slot: int, origin: Vector3, launch_velocity: Vector3) -> void:
	if slipper_index < 0 or slipper_index >= slippers.size():
		return
	slippers[slipper_index]._apply_thrown(slot, origin, launch_velocity)

@rpc("authority", "call_local", "reliable")
func _rpc_slipper_landed(slipper_index: int, where: Vector3, from_flight: bool = false) -> void:
	if slipper_index < 0 or slipper_index >= slippers.size():
		return
	slippers[slipper_index]._apply_landed(where, from_flight)

@rpc("authority", "call_local", "reliable")
func _rpc_slipper_deflected(slipper_index: int, from: Vector3, new_velocity: Vector3) -> void:
	if slipper_index < 0 or slipper_index >= slippers.size():
		return
	slippers[slipper_index]._apply_deflected(from, new_velocity)

func _apply_reclaim(character: CharacterBase, index: int, new_peer_id: int) -> void:
	if character == null or not is_instance_valid(character):
		return
	for old_peer_id in _spawned_characters.keys():
		if _spawned_characters[old_peer_id] == character and old_peer_id != new_peer_id:
			_spawned_characters.erase(old_peer_id)
			_peer_slots.erase(old_peer_id)
			_spawned_peer_ids.erase(old_peer_id)
			break
	character.is_bot = false
	if character.ai_controller != null:
		character.ai_controller.queue_free()
		character.ai_controller = null
	character.name = str(new_peer_id)
	_apply_reclaimed_picks(character, new_peer_id)
	character.set_multiplayer_authority(new_peer_id)
	if new_peer_id == multiplayer.get_unique_id():
		var my_name := SettingsManagerScript.sanitise_name(SettingsManager.player_name)
		if my_name != "":
			character.player_name = my_name
	character.player_id = index + 1
	_spawned_characters[new_peer_id] = character
	_peer_slots[new_peer_id] = character.player_slot
	_spawned_peer_ids[new_peer_id] = true
	_refresh_rig_ownership(character)
	if NetworkManager.is_host():
		_rpc_show_toast.rpc("A player reconnected to their character")

func _refresh_rig_ownership(character: CharacterBase) -> void:
	var rig := character.get_node_or_null("CameraRig") as CameraRig
	if rig == null:
		return
	var is_mine := character.is_multiplayer_authority() and character.ai_controller == null
	rig.set_active(is_mine)
	rig.set_aim_source(CameraRig.AimSource.MOUSE if is_mine else CameraRig.AimSource.MOVEMENT)
	if is_mine:
		if not pause_root.visible and not match_result.visible and not settings_panel.visible:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

