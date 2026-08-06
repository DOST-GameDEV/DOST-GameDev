extends Node

const MATCH_SETUP_PATH: String = "res://scenes/ui/MatchSetup.tscn"
const MAIN_SCENE_PATH: String = "res://scenes/main/Main.tscn"

const CONNECT_WAIT: float = 4.0

const SAMPLE_A_WAIT: float = 5.0
const SAMPLE_B_WAIT: float = 10.0
const CLIENT_WATCH_HOLD: float = 9.0
const CLIENT_LINGER: float = 10.0
const HOST_LINGER: float = 14.0

var _tag: String = "?"
var _failures: int = 0
var _checks: int = 0
var _shots_dir: String = ""

func _ready() -> void:
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--shots="):
			_shots_dir = arg.substr(len("--shots="))
	if "--lobby-host" in args:
		_tag = "HOST"
		await _run_lobby_host()
	elif _joined_address(args) != "":
		_tag = "JOIN"
		await _run_lobby_client(_joined_address(args))
	elif "--shots-ui" in args:
		_tag = "SHOTS"
		await _run_ui_shots()
	elif "--solo" in args:
		_tag = "SOLO"
		await _run_solo("--no-spectate" not in args)
	else:
		print("spec_probe: pass --lobby-host, --lobby-join=<ip> or --solo")
		get_tree().quit(1)
		return
	_finish()

func _run_ui_shots() -> void:
	for spectating in [false, true]:
		GameLaunch.spectator = spectating
		var lobby := _stand_up_lobby("local", "")
		GameLaunch.spectator = spectating
		var button := lobby.find_child("SpectateButton", true, false) as Button
		if button != null:
			button.button_pressed = spectating
			button.pressed.emit()
		await _wait(1.2)
		await RenderingServer.frame_post_draw
		var name := "spectate_on" if spectating else "spectate_off"
		get_viewport().get_texture().get_image().save_png(
			_shots_dir.path_join("matchsetup_%s.png" % name))
		print("[%s]  wrote matchsetup_%s.png" % [_tag, name])
		lobby.queue_free()
		await _wait(0.4)

static func _joined_address(args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with("--lobby-join="):
			return arg.substr(len("--lobby-join="))
	return ""

func _check(name: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s]  %s  %s%s" % [_tag, "PASS" if ok else "*** FAIL", name,
		("   " + detail) if detail != "" else ""])

func _finish() -> void:
	print("[%s]  %d/%d checks passed" % [_tag, _checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _stand_up_lobby(action: String, address: String) -> MatchSetupScreen:
	GameLaunch.pending_action = action
	GameLaunch.pending_join_address = address
	GameLaunch.spectator = false
	GameLaunch.clear_seating()
	var lobby := (load(MATCH_SETUP_PATH) as PackedScene).instantiate() as MatchSetupScreen
	lobby.name = "MatchSetup"
	get_tree().root.add_child(lobby)
	get_tree().current_scene = lobby
	return lobby

func _press_spectate(lobby: Node, want: bool) -> void:
	var button := lobby.find_child("SpectateButton", true, false) as Button
	if button == null:
		_check("SPECTATE button exists", false, "find_child found nothing")
		return
	button.button_pressed = want
	button.pressed.emit()

func _run_lobby_host() -> void:
	var lobby := _stand_up_lobby("host", "")
	await _wait(CONNECT_WAIT + 2.0)
	var peers: Array = NetworkManager.connected_peer_ids.duplicate()
	var client_id := 0
	for id in peers:
		if id != multiplayer.get_unique_id():
			client_id = id
	_check("a second real peer connected", client_id != 0, "peers=%s" % [peers])
	if client_id == 0:
		return

	await _wait(SAMPLE_A_WAIT)
	_check("§2.3 the host LEARNED the client is spectating",
		NetworkManager.is_spectator(client_id),
		"is_spectator(%d)=%s" % [client_id, NetworkManager.is_spectator(client_id)])
	_check("§2.3 the client HOLDS NO SEAT on the host's board",
		not lobby._peer_seats.has(client_id), "seats=%s" % [lobby._peer_seats])
	_check("§2.3 the client is out of the ready count",
		NetworkManager.playing_peer_count() == 1,
		"playing_peer_count=%d (host only)" % NetworkManager.playing_peer_count())
	_check("§2.3 the client holds no READY tick",
		not lobby._peer_ready.has(client_id), "ready=%s" % [lobby._peer_ready])
	_check("§2.3 the board shows it as watching",
		bool(lobby._peer_spectating.get(client_id, false)))
	var vacated := int(lobby._vacated_seats.get(client_id, -1))
	_check("§2.3 the vacated seat is offered as a BOT seat", vacated >= 0
		and "BOT" in lobby._seat_row_text(vacated),
		"seat %d reads '%s'" % [vacated, lobby._seat_row_text(vacated) if vacated >= 0 else "-"])
	lobby._peer_ready[multiplayer.get_unique_id()] = true
	lobby._refresh_start_button()
	_check("§2.3 START MATCH goes live without the spectator's press",
		not lobby.start_button.disabled)

	await _wait(SAMPLE_B_WAIT)
	_check("§2.4 the client is a player again", not NetworkManager.is_spectator(client_id))
	_check("§2.4 it got its OWN seat back, not 'first free'",
		int(lobby._peer_seats.get(client_id, -99)) == vacated,
		"vacated %d, returned %s" % [vacated, lobby._peer_seats.get(client_id, "none")])
	_check("§2.4 it is back in the ready count",
		NetworkManager.playing_peer_count() == 2,
		"playing_peer_count=%d" % NetworkManager.playing_peer_count())

	_press_spectate(lobby, true)
	await _wait(1.0)
	var host_id := multiplayer.get_unique_id()
	_check("§2.4 the host's own flag updated (host_game() had frozen it)",
		NetworkManager.is_spectator(host_id))
	_check("§2.4 the host released its seat", not lobby._peer_seats.has(host_id),
		"seats=%s" % [lobby._peer_seats])
	_check("§2.4 a spectating host is still allowed to start",
		NetworkManager.playing_peer_count() >= 1)
	lobby._peer_ready[client_id] = true
	lobby._refresh_start_button()
	_check("§2.4 START MATCH still live with the host watching",
		not lobby.start_button.disabled)

	_press_spectate(lobby, false)
	await _wait(4.0)
	_check("§2.3 the client is watching again before the match starts",
		NetworkManager.is_spectator(client_id))
	lobby._peer_ready[multiplayer.get_unique_id()] = true
	lobby._on_start_pressed()
	await _wait(8.0)

	var main := get_tree().root.get_node_or_null("Main")
	_check("§2.3 the match actually loaded on the host", main != null)
	if main == null:
		return
	var units := main.find_children("*", "CharacterBase", true, false)
	_check("§2.3 IN THE MATCH: still a full 2v2 with one human and one watcher",
		units.size() == 4, "found %d units" % units.size())
	_check("§2.3 IN THE MATCH: the spectating peer was handed NO character",
		main._spawned_characters.get(client_id) == null,
		"spawned_characters=%s" % [main._spawned_characters.keys()])
	_check("§2.3 IN THE MATCH: it was still marked dealt-with, so no late path re-seats it",
		bool(main._spawned_peer_ids.get(client_id, false)))
	var ai_units := 0
	for unit in units:
		if (unit as CharacterBase).is_ai_driven():
			ai_units += 1
	_check("§2.3 IN THE MATCH: the vacated slot is bot-filled (3 bots, 1 human host)",
		ai_units == 3, "%d of %d bot-held" % [ai_units, units.size()])
	_check("§2.3 IN THE MATCH: the host is not waiting on the spectator to ready",
		NetworkManager.playing_peer_count() == 1,
		"playing_peer_count=%d" % NetworkManager.playing_peer_count())

	await _wait(HOST_LINGER)

func _run_lobby_client(address: String) -> void:
	var lobby := _stand_up_lobby("join", address)
	await _wait(CONNECT_WAIT)
	_check("connected to the host", NetworkManager.is_networked()
		and multiplayer.multiplayer_peer.get_connection_status()
			== MultiplayerPeer.CONNECTION_CONNECTED)
	_press_spectate(lobby, true)
	await _wait(1.0)
	_check("§2.1 the toggle shows its own state",
		(lobby.find_child("SpectateButton", true, false) as Button).text == "SPECTATING")
	_check("§2.3 READY is withdrawn from a spectator", lobby.primary_button.disabled)
	await _wait(CLIENT_WATCH_HOLD)
	_press_spectate(lobby, false)
	_check("§2.4 READY is offered again", not lobby.primary_button.disabled)
	await _wait(6.0)
	_press_spectate(lobby, true)
	await _wait(8.0)
	var main := get_tree().root.get_node_or_null("Main")
	_check("§2.2 the spectating CLIENT reached the match", main != null)
	if main != null:
		var spectator := main.get_node_or_null("Spectator")
		_check("§2.2 IN THE MATCH: the client got a free camera",
			spectator is SpectatorCamera)
		var chud = main.find_children("*", "Hud", true, false)
		_check("§2.5 IN THE MATCH: the client's HUD knows it has no character",
			not chud.is_empty() and chud[0]._spectating,
			"hud found=%s" % [not chud.is_empty()])
		var mine: Array = []
		for unit in main.find_children("*", "CharacterBase", true, false):
			if (unit as CharacterBase).is_multiplayer_authority():
				mine.append(unit)
		_check("§2.3 IN THE MATCH: the client owns NO character at all", mine.is_empty(),
			"owns %d" % mine.size())
	await _wait(CLIENT_LINGER)


func _run_solo(spectating: bool = true) -> void:
	_tag = "SOLO" if spectating else "SOLO-PLAY"
	GameLaunch.pending_action = "local"
	GameLaunch.spectator = spectating
	GameLaunch.solo_seat = 0
	var main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	main.name = "Main"
	get_tree().root.add_child(main)
	await _wait(4.0)

	var units0 := main.find_children("*", "CharacterBase", true, false)
	var closest := 999.0
	var closest_pair := ""
	for i in units0.size():
		for j in range(i + 1, units0.size()):
			var a := units0[i] as CharacterBase
			var b := units0[j] as CharacterBase
			if _is_carried(a) or _is_carried(b):
				continue
			var d := a.global_position.distance_to(b.global_position)
			if d < closest:
				closest = d
				closest_pair = "%s / %s" % [a.name, b.name]
	_check("no two units are standing in the same place", closest > 0.6,
		"closest pair %s at %.2f m" % [closest_pair, closest])
	for unit in units0:
		var u := unit as CharacterBase
		print("[%s]    %-14s pos=(%.2f, %.2f, %.2f)  person=%s  can=%s  visible=%s" % [
			_tag, u.name, u.global_position.x, u.global_position.y, u.global_position.z,
			u.is_person, u.is_can, u.visible])
	for unit in units0:
		var rig := (unit as CharacterBase).get_node_or_null("CameraRig") as CameraRig
		var vis := (unit as CharacterBase).get_node_or_null("Visual") as Node3D
		var hidden_meshes := 0
		if vis != null:
			for m in vis.find_children("*", "MeshInstance3D", true, false):
				if not (m as MeshInstance3D).visible:
					hidden_meshes += 1
		print("[%s]    %-14s rig_active=%s  hidden_meshes=%d" % [
			_tag, (unit as CharacterBase).name,
			"none" if rig == null else str(rig._active), hidden_meshes])
	if not spectating:
		return

	var active_rigs := 0
	var self_hidden := 0
	for unit in units0:
		var rig2 := (unit as CharacterBase).get_node_or_null("CameraRig") as CameraRig
		if rig2 != null and rig2._active:
			active_rigs += 1
		var vis2 := (unit as CharacterBase).get_node_or_null("Visual") as Node3D
		if vis2 != null:
			for m2 in vis2.find_children("*", "MeshInstance3D", true, false):
				if not (m2 as MeshInstance3D).visible:
					self_hidden += 1
	_check("no unit is still hiding its own body for a rig nobody looks through",
		active_rigs == 0 and self_hidden == 0,
		"%d active rigs, %d hidden meshes" % [active_rigs, self_hidden])

	var spectator := main.get_node_or_null("Spectator") as SpectatorCamera
	_check("§2.2 the spectator exists in Single Player", spectator != null)
	if spectator == null:
		return

	_check("§2.2 it is not a physics body",
		not ClassDB.is_parent_class(spectator.get_class(), "PhysicsBody3D"),
		"class=%s" % spectator.get_class())
	var shapes := spectator.find_children("*", "CollisionShape3D", true, false)
	_check("§2.2 it carries no collision shape at all", shapes.is_empty(),
		"found %d" % shapes.size())
	var brains := spectator.find_children("*", "AIController", true, false)
	_check("no AI is attached to the spectator", brains.is_empty(),
		"found %d" % brains.size())

	var live := get_viewport().get_camera_3d()
	_check("§2.2 the spectator's camera is the one being rendered",
		live != null and live.get_parent() == spectator,
		"viewport camera is %s" % ["none" if live == null else String(live.get_path())])

	var units := main.find_children("*", "CharacterBase", true, false)
	var ai_driven := 0
	for unit in units:
		if (unit as CharacterBase).is_ai_driven():
			ai_driven += 1
	_check("§2.3 the match is still four units", units.size() == 4,
		"found %d" % units.size())
	var props_with_kit := 0
	var props := 0
	for unit in units:
		if not (unit as CharacterBase).is_person:
			props += 1
			if (unit as CharacterBase).ability != null:
				props_with_kit += 1
	_check("§3.11 guard: every Prop still resolved a real ability kit",
		props > 0 and props_with_kit == props,
		"%d of %d props have a kit" % [props_with_kit, props])
	_check("§2.3 every seat including the vacated one is bot-held", ai_driven == 4,
		"%d of %d ai-driven" % [ai_driven, units.size()])

	var start: Vector3 = spectator.global_position
	Input.action_press("guard_dash")
	await _wait(2.0)
	Input.action_release("guard_dash")
	await _wait(0.5)
	var descended: float = start.y - spectator.global_position.y
	_check("§2.2 it flies", descended > 4.0, "descended %.2f m" % descended)
	_check("§2.2 it clipped through the ground plane", spectator.global_position.y < 0.0,
		"y = %.2f m" % spectator.global_position.y)

	Input.action_press("sprint")
	Input.action_press("jump")
	await _wait(3.0)
	Input.action_release("jump")
	await _wait(0.5)
	var ceiling: float = spectator.global_position.y
	_check("§2.2 no ceiling — it climbs past the rooflines", ceiling > 60.0,
		"y = %.1f m" % ceiling)
	spectator._pitch_deg = 0.0
	spectator._yaw = 0.0
	spectator._apply_rotation()
	await _wait(0.2)
	var out_start := Vector2(spectator.global_position.x, spectator.global_position.z)
	Input.action_press("move_up")
	await _wait(4.0)
	Input.action_release("move_up")
	Input.action_release("sprint")
	await _wait(0.5)
	var out: float = out_start.distance_to(
		Vector2(spectator.global_position.x, spectator.global_position.z))
	_check("§2.2 no fence — it leaves the built map entirely", out > 100.0,
		"travelled %.1f m horizontally, ending %.1f m from the circle" % [out,
			Vector2(spectator.global_position.x, spectator.global_position.z).length()])
	_check("§2.2 it is still the rendered camera out there",
		get_viewport().get_camera_3d() != null
			and get_viewport().get_camera_3d().get_parent() == spectator)

	var speed_before: float = spectator._speed
	_send_wheel(MOUSE_BUTTON_WHEEL_UP)
	_send_wheel(MOUSE_BUTTON_WHEEL_UP)
	await _wait(0.2)
	_check("§2.6 the wheel changes fly speed", spectator._speed > speed_before,
		"%.1f -> %.1f m/s" % [speed_before, spectator._speed])
	_send_key(KEY_TAB)
	await _wait(0.5)
	_check("§2.6 TAB picks up a follow target", spectator._follow != null,
		"following %s" % [spectator._follow.name if spectator._follow != null else "nothing"])
	var dist_before: float = spectator._follow_distance
	_send_wheel(MOUSE_BUTTON_WHEEL_UP)
	_send_wheel(MOUSE_BUTTON_WHEEL_UP)
	_send_wheel(MOUSE_BUTTON_WHEEL_UP)
	await _wait(0.5)
	_check("§2.6 the same wheel pulls the follow shot in for a close-up",
		spectator._follow_distance < dist_before,
		"%.1f -> %.1f m" % [dist_before, spectator._follow_distance])
	_check("§2.6 the follow shot rides the target",
		spectator.global_position.distance_to(spectator._follow.global_position) < 12.0,
		"%.1f m from target" % spectator.global_position.distance_to(
			spectator._follow.global_position))
	_send_key(KEY_V)
	await _wait(0.4)
	_check("2.8 V enters POV on the followed unit", spectator._pov)
	var target: Node3D = spectator._follow
	var eye: float = spectator.global_position.y - target.global_position.y
	_check("2.8 the camera sits at the unit's eye height, not behind it",
		spectator.global_position.distance_to(target.global_position) < 1.8 and eye > 0.1,
		"%.2f m away, %.2f m above" % [
			spectator.global_position.distance_to(target.global_position), eye])
	_check("2.8 the yaw is TAKEN from the unit",
		absf(angle_difference(spectator._yaw, target.global_rotation.y)) < 0.05,
		"camera %.3f rad vs unit %.3f rad" % [spectator._yaw, target.global_rotation.y])
	var rig := target.get_node_or_null("CameraRig") as CameraRig
	_check("2.8 the watched unit's own rig was NOT activated",
		rig == null or not rig._active,
		"rig active=%s" % ["no rig" if rig == null else str(rig._active)])
	_check("2.8 the spectator still owns the rendered view",
		get_viewport().get_camera_3d() != null
			and get_viewport().get_camera_3d().get_parent() == spectator)

	_send_key(KEY_F)
	await _wait(0.3)
	_check("§2.6 F returns to free flight", spectator._follow == null)
	_check("2.8 F drops POV with it", not spectator._pov)

	var hud := main.get_node_or_null("HUDLayer/HUD")
	if hud == null:
		hud = main.find_children("*", "HUD", true, false).front() if not main.find_children(
			"*", "HUD", true, false).is_empty() else null
	_check("the HUD is reachable", hud != null)
	if hud != null:
		_check("§2.5 the YOU card is gone (it describes a character)", not hud.you_card.visible)
		_check("§2.5 the crosshair is gone", not hud.crosshair.visible)
		_check("§2.5 the lata card is gone", not hud.lata_card.visible)
		_check("§2.5 no orphaned status rows were built", hud._status_rows.is_empty(),
			"%d rows" % hud._status_rows.size())
		_check("§2.7 the round readout exists and says something",
			hud._spectator_round != null and hud._spectator_round.text != "",
			"'%s'" % (hud._spectator_round.text if hud._spectator_round != null else ""))
		_check("§2.6 the live camera readout exists and says something",
			hud._spectator_status != null and hud._spectator_status.text != "",
			"'%s'" % (hud._spectator_status.text if hud._spectator_status != null else ""))

	if _shots_dir != "":
		spectator._target_position = Vector3(0.0, 7.0, 13.0)
		spectator.global_position = spectator._target_position
		await _wait(1.5)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			_shots_dir.path_join("spectator_ingame.png"))
		print("[%s]  wrote spectator_ingame.png" % _tag)
		for unit in units:
			if (unit as CharacterBase).is_person:
				spectator._follow = unit as Node3D
				break
		spectator._pov = true
		spectator._pitch_deg = -6.0
		await _wait(1.5)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			_shots_dir.path_join("spectator_pov.png"))
		print("[%s]  wrote spectator_pov.png" % _tag)

static func _is_carried(unit: CharacterBase) -> bool:
	var carriable := unit.get_node_or_null("Carriable")
	return carriable != null and carriable.get("carrier") != null

func _send_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)

func _send_wheel(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)

