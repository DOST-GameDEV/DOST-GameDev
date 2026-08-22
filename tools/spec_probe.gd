extends Node
## SPECTATOR — the toggle, the seat, the ready gate and the camera. `Agent_Prompts.md`
## § CHECKLIST §2.
##
## ⚠️ A NEW FILE, AND THAT IS DELIBERATE. § PATHS gives 👁️ `build spec` no `tools/` row,
## and writing into `net_spawn_probe.gd` (`build fair`'s neighbourhood) or `ui_layout_
## probe.gd` (`build ux`'s) would have broken one-writer-per-file for a probe neither lane
## asked for. Same call `build mech` made for `mech_probe` on 2026-07-31.
##
## ⚠️⚠️ AND IT RUNS THE SEAT CHECK ON TWO REAL PEERS, WHICH IS THE WHOLE POINT.
## §2.3's exclusion — *claims no seat, excluded from the ready gate, its slot bot-filled*
## — had never once run beside a second peer, and every part of it that was broken was
## broken only there:
##
##   * `NetworkManager._local_picks()` snapshots the spectate flag at CONNECT time and the
##     toggle lives in the lobby, one screen later. A client that pressed SPECTATE told
##     nobody; the host spawned it a character and counted it in the gate.
##   * the host's own flag was snapshotted even earlier, in `host_game()`.
##
## Solo passes both of those by accident, because solo reads `GameLaunch.spectator`
## directly and there is no host to disagree with.
##
## USAGE — three modes.
##
##   Two peers, host first, in two terminals:
##     godot --path . --headless tools/spec_probe.tscn -- --lobby-host
##     godot --path . --headless tools/spec_probe.tscn -- --lobby-join=127.0.0.1
##
##   Single Player, in-match camera and HUD (needs a real rendering device — plain exe,
##   NOT --headless; see docs/README.md):
##     godot --path . tools/spec_probe.tscn -- --solo --shots=<dir>
##
## ⚠️ THE LOBBY IS PARENTED AT `/root/MatchSetup`, NOT UNDER THIS PROBE, for the reason
## `net_spawn_probe.gd` documents at length: every RPC in `match_setup.gd` is declared on
## the scene root and Godot resolves them BY NODE PATH. A lobby sitting at
## `SpecProbe/MatchSetup` on one peer and `MatchSetup` on the other silently fails to
## deliver a single seat sync, which reads as "the feature does not work" rather than as
## "the harness is wrong".
##
## Exit code 0 when every check passed, 1 when any did not.
##
## ⚠️ THE **HOST** IS THE GATE, not the client. The client is deliberately still alive when
## the host quits (see the clock table below), so its scene is torn down by
## `_on_server_disconnected` before `_finish()` can print a summary or set an exit code.
## Its four PASS lines do print, and they are worth reading; the number to gate on is the
## host's. Measured 2026-07-31: HOST 22/22, JOIN 8/8, --solo 33/33.

const MATCH_SETUP_PATH: String = "res://scenes/ui/MatchSetup.tscn"
const MAIN_SCENE_PATH: String = "res://scenes/main/Main.tscn"

## Seconds to let ENet complete its handshake and the host's welcome packet land before
## anybody touches a button. Generous: an assertion that fires early measures the
## handshake, not the feature.
const CONNECT_WAIT: float = 4.0

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE TWO CLOCKS ARE NOT THE SAME CLOCK, AND THE FIRST VERSION OF THIS PROBE
## REPORTED A PRODUCT BUG THAT WAS ENTIRELY ITS OWN.
##
## The host is launched FIRST — it has to be, there is nothing to join otherwise — so by
## the time the client's `_ready()` runs the host is already several seconds into its own
## script. Both sides then counted from their own zero, and the host's second sample
## landed 2 s BEFORE the client had pressed the button that sample was about. It read as
## "§2.4 the client is a player again — FAIL", which is exactly what a real regression
## would look like.
##
## Fixed by giving the host a deliberately wide margin around each of the client's
## actions rather than by trying to synchronise the two. The numbers below are laid out
## on the HOST's clock, with the client's own offset written beside them, so the ordering
## can be read rather than reconstructed:
##
##   host t=0    host lobby up
##   host t≈4    client lobby up          (client t=0)
##   host t≈8    client presses SPECTATE  (client t≈4)
##   host t=11   HOST SAMPLE A            — 3 s of margin
##   host t≈18   client presses SPECTATE off (client t≈14)
##   host t=21   HOST SAMPLE B            — 3 s of margin
##   host t=22   HOST SAMPLE C  (host itself spectates), then quits
##   host t≈38   client quits             (client t≈34)
##
## ⚠️ AND THE CLIENT MUST OUTLIVE THE HOST, not merely finish after its own last check.
## When the host drops, `match_setup.gd::_on_server_disconnected` calls
## `change_scene_to_file(MultiplayerSetup)` — which frees `current_scene`, and this probe
## IS the current scene. The client then stops printing mid-run with no error at all,
## which is the same silent-empty-log trap `net_spawn_probe.gd` documents.
const SAMPLE_A_WAIT: float = 5.0   ## after the peer check, on the host
const SAMPLE_B_WAIT: float = 10.0  ## after sample A, on the host
const CLIENT_WATCH_HOLD: float = 9.0   ## client stays spectating across sample A
const CLIENT_LINGER: float = 10.0
## ⚠️ AND ONCE THE RUN FOLLOWS THE PLAYERS INTO THE MATCH, THE DIRECTION REVERSES: the
## HOST must outlive the CLIENT, because the client now has checks of its own on the far
## side of the scene change. The host quitting first tears the client's match down through
## `main.gd::_on_server_disconnected`, which bounces it to MultiplayerSetup and frees
## `/root/Main` — measured exactly once as "§2.2 the spectating CLIENT reached the match —
## FAIL" while the host had just reported 22/22 on the same match. The client was 5 s late,
## not wrong.
const HOST_LINGER: float = 14.0

var _tag: String = "?"
var _failures: int = 0
var _checks: int = 0
var _shots_dir: String = ""

func _ready() -> void:
	# ⚠️ ONE FRAME FIRST. `_ready()` runs while `/root` is still setting its own children
	# up, and `add_child()` on a busy parent fails outright — measured: "Parent node is
	# busy setting up children", and the probe then reported the spectator missing when
	# what was missing was the scene it lives in.
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

## ⚠️ RENDERS THE SETUP SCREEN IN BOTH TOGGLE STATES. `tools/ui_shot.tscn` already shoots
## this screen, but only ever in its default state — and the SPECTATE toggle's whole job is
## to look different when it is on. The OFF shot is the one that gets taken by habit and
## the ON shot is the one that was wrong: 🧑 rejected two versions of this control on the
## ON state alone, both of which looked fine off. A control with two faces needs two shots
## or half of it is unverified.
func _run_ui_shots() -> void:
	for spectating in [false, true]:
		GameLaunch.spectator = spectating
		var lobby := _stand_up_lobby("local", "")
		GameLaunch.spectator = spectating # _stand_up_lobby clears it
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

## `PackedStringArray` has no `any()` — this is the one place the probe needs it.
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

# =============================================================================
# Two-peer lobby — §2.1 (the toggle carries), §2.3 (seat, ready gate), §2.4 (return)
# =============================================================================

## Stands the REAL `MatchSetup.tscn` up at the root, exactly where the menu flow puts it.
func _stand_up_lobby(action: String, address: String) -> MatchSetupScreen:
	GameLaunch.pending_action = action
	GameLaunch.pending_join_address = address
	GameLaunch.spectator = false
	GameLaunch.clear_seating()
	var lobby := (load(MATCH_SETUP_PATH) as PackedScene).instantiate() as MatchSetupScreen
	lobby.name = "MatchSetup" # see the header: the RPCs resolve by path
	get_tree().root.add_child(lobby)
	# ⚠️⚠️ THE LOBBY BECOMES `current_scene` AND THIS PROBE STOPS BEING IT. Without this the
	# run cannot follow the players out of the lobby at all: `_rpc_begin_match` ends in
	# `change_scene_to_file(Main.tscn)`, which FREES the current scene — and that was this
	# probe, mid-`await`, on both peers at once. Handing the title to the lobby means the
	# engine frees the lobby instead and loads `Main` at `/root/Main` (the same path on
	# every peer, which the spawner and every RPC need), while the probe carries on as a
	# plain sibling under `/root`. Same reasoning `net_spawn_probe.gd` gives for parenting
	# Main by hand; this is the version that works when the GAME does the scene change.
	get_tree().current_scene = lobby
	return lobby

## Presses the SPECTATE plank the way a player does — through the same `pressed` signal
## the mouse and the keyboard both raise, rather than by calling the handler. A probe that
## calls `_on_spectate_pressed()` directly proves the handler works and proves nothing
## about whether anything is wired to it, which is the failure § THE REACHABILITY RULE is
## about.
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

	# --- A · the client has pressed SPECTATE in its own lobby (host t=11) -------------
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
	# The vacated seat must read as a bot seat to everyone else — that is what
	# `main.gd::_fill_empty_slots_with_placeholders` will act on.
	var vacated := int(lobby._vacated_seats.get(client_id, -1))
	_check("§2.3 the vacated seat is offered as a BOT seat", vacated >= 0
		and "BOT" in lobby._seat_row_text(vacated),
		"seat %d reads '%s'" % [vacated, lobby._seat_row_text(vacated) if vacated >= 0 else "-"])
	# The host readies itself; with the only other peer watching, START must go live.
	lobby._peer_ready[multiplayer.get_unique_id()] = true
	lobby._refresh_start_button()
	_check("§2.3 START MATCH goes live without the spectator's press",
		not lobby.start_button.disabled)

	# --- B · the client un-spectates (§2.4, the seat comes back) — host t=21 ----------
	await _wait(SAMPLE_B_WAIT)
	_check("§2.4 the client is a player again", not NetworkManager.is_spectator(client_id))
	_check("§2.4 it got its OWN seat back, not 'first free'",
		int(lobby._peer_seats.get(client_id, -99)) == vacated,
		"vacated %d, returned %s" % [vacated, lobby._peer_seats.get(client_id, "none")])
	_check("§2.4 it is back in the ready count",
		NetworkManager.playing_peer_count() == 2,
		"playing_peer_count=%d" % NetworkManager.playing_peer_count())

	# --- C · the HOST spectates (§2.4, "a spectating host still runs the match") -------
	_press_spectate(lobby, true)
	await _wait(1.0)
	var host_id := multiplayer.get_unique_id()
	_check("§2.4 the host's own flag updated (host_game() had frozen it)",
		NetworkManager.is_spectator(host_id))
	_check("§2.4 the host released its seat", not lobby._peer_seats.has(host_id),
		"seats=%s" % [lobby._peer_seats])
	# A spectating HOST still counts as playing — somebody has to be able to start.
	_check("§2.4 a spectating host is still allowed to start",
		NetworkManager.playing_peer_count() >= 1)
	lobby._peer_ready[client_id] = true
	lobby._refresh_start_button()
	_check("§2.4 START MATCH still live with the host watching",
		not lobby.start_button.disabled)

	# --- D · into the MATCH, with the client spectating and the host playing ----------
	# ⚠️ EVERYTHING ABOVE IS THE LOBBY. §2.3's third clause — "its slot bot-filled" — is a
	# claim about `main.gd::_spawn_player`, which no lobby check reaches: the seat can be
	# released perfectly and the peer still be handed a character on the other side of the
	# scene change. This is the half that was going to be handed to the next lane as
	# unverified, and it is the headline box of the whole section.
	_press_spectate(lobby, false) # the host plays; the client is watching again by now
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

	# Hold the session open until the client has finished its own in-match checks. See
	# HOST_LINGER: this is not padding, it is the ordering the run depends on.
	await _wait(HOST_LINGER)

func _run_lobby_client(address: String) -> void:
	var lobby := _stand_up_lobby("join", address)
	await _wait(CONNECT_WAIT)
	_check("connected to the host", NetworkManager.is_networked()
		and multiplayer.multiplayer_peer.get_connection_status()
			== MultiplayerPeer.CONNECTION_CONNECTED)
	_press_spectate(lobby, true)
	await _wait(1.0)
	# ⚠️ ASSERTS THE WORD, NOT THE OLD SENTENCE. This read `"WATCHING" in ...text` against
	# the first label ("SPECTATING · WATCHING, NO CHARACTER ◀ YOU") and went red the moment
	# the label was shortened to one word — a probe failing because the thing it watches
	# improved. The state is carried by the styling now (a lit amber slab); the text is the
	# part a probe can still read, so it checks the text and the shots check the styling.
	_check("§2.1 the toggle shows its own state",
		(lobby.find_child("SpectateButton", true, false) as Button).text == "SPECTATING")
	_check("§2.3 READY is withdrawn from a spectator", lobby.primary_button.disabled)
	# Hold through the host's sample A, then hand the seat back for its sample B.
	await _wait(CLIENT_WATCH_HOLD)
	_press_spectate(lobby, false)
	_check("§2.4 READY is offered again", not lobby.primary_button.disabled)
	# Back to watching, and stay that way — the host takes us into the match from here.
	await _wait(6.0)
	_press_spectate(lobby, true)
	# The host presses START at host t≈26 (client t≈22). Sampled at client t≈28, which is
	# inside the window the host holds open for it — see HOST_LINGER.
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
	# Outlive the host — see the clock table above. A client that drops first erases the
	# state the host is about to read, and a client that is still here when the host goes
	# gets its scene swapped out from under it, which silently ends this run.
	await _wait(CLIENT_LINGER)

# =============================================================================
# Single Player in-match — §2.2 (free flight, no body), §2.5/§2.7 (HUD), §2.6 (filmable)
# =============================================================================

## ⚠️ `spectating` IS A PARAMETER SO THE SAME SCENE CAN BE RUN BOTH WAYS. A defect seen
## while spectating is not a spectator defect until the non-spectating run has been asked
## the same question — otherwise this lane fixes somebody else's bug in its own file, or
## files a bug that is really its own. `--no-spectate` runs the identical solo match with
## the camera off and checks only the things that are true either way.
func _run_solo(spectating: bool = true) -> void:
	_tag = "SOLO" if spectating else "SOLO-PLAY"
	GameLaunch.pending_action = "local"
	GameLaunch.spectator = spectating
	GameLaunch.solo_seat = 0
	var main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	main.name = "Main"
	get_tree().root.add_child(main)
	await _wait(4.0)

	# ⚠️ THE UNIT-OVERLAP CHECK RUNS IN BOTH MODES, and it is the whole point of having a
	# non-spectating mode at all. 🧑 report, 2026-07-31, with a screenshot: *"i dont see one
	# of the characters bruh in spectator"* — two Person nameplates ("A1 · DEF" and
	# "B1 · OFF") stacked over a single visible model. Either two units are occupying one
	# spot, or one has no model. Both are unwatchable on film and neither is obviously
	# this lane's.
	var units0 := main.find_children("*", "CharacterBase", true, false)
	var closest := 999.0
	var closest_pair := ""
	for i in units0.size():
		for j in range(i + 1, units0.size()):
			var a := units0[i] as CharacterBase
			var b := units0[j] as CharacterBase
			# ⚠️ A CARRIED TSINELAS IS *SUPPOSED* TO BE INSIDE ITS CARRIER. The first
			# version of this check read "TeamBProp / TeamBPerson at 0.45 m" as an overlap
			# and reported FAIL on a slipper sitting correctly in a Person's hand — a
			# probe inventing a defect, which is worse than not having the check.
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
	# ⚠️⚠️ 🧑 report, 2026-07-31: *"i dont see one of the characters bruh in spectator"*, with
	# a screenshot showing two Person nameplates over one visible model. The units are NOT
	# overlapping (measured above), so the question is whether one of them is being HIDDEN.
	#
	# `camera_rig.gd::_apply_fpp_self_hide()` drops the head mesh and the carried slipper
	# whenever `_active and _mode == FPP` — correct for the peer looking through that rig,
	# and catastrophic for a spectator, because a rig left active by
	# `debug_player_switcher.gd` keeps hiding its own body on a screen that is now looking
	# at it from the outside. This lane already had to take `Camera3D.current` back off
	# that same mechanism; the self-hide is the half that does not show up in a camera
	# check, because the picture is right and a body is simply missing from it.
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

	# --- no body, no collision, no physics layer — BY CONSTRUCTION ---------------------
	# `is PhysicsBody3D` is a compile error against a statically-known SpectatorCamera —
	# the type system already proves it, which is the strongest form this check can take.
	# Asserted at runtime through the class name so the probe still says so out loud.
	_check("§2.2 it is not a physics body",
		not ClassDB.is_parent_class(spectator.get_class(), "PhysicsBody3D"),
		"class=%s" % spectator.get_class())
	var shapes := spectator.find_children("*", "CollisionShape3D", true, false)
	_check("§2.2 it carries no collision shape at all", shapes.is_empty(),
		"found %d" % shapes.size())
	# ⚠️ 🧑 2026-07-31: *"dont give spectator AI... spectator should only be controllable
	# by a person."* Asserted rather than asserted-in-a-comment.
	var brains := spectator.find_children("*", "AIController", true, false)
	_check("no AI is attached to the spectator", brains.is_empty(),
		"found %d" % brains.size())

	# ⚠️⚠️ ARE WE ACTUALLY LOOKING THROUGH IT. Every other check in this file passed while
	# the rendered frame was a Person's first-person view with its viewmodel arms across
	# the bottom — `debug_player_switcher.gd` had claimed TeamAPerson and its `CameraRig`
	# took `current`. The camera flew, the HUD stripped, the speed changed, and the picture
	# was somebody else's. Asserted against the VIEWPORT, which is the only thing that
	# knows who actually won.
	var live := get_viewport().get_camera_3d()
	_check("§2.2 the spectator's camera is the one being rendered",
		live != null and live.get_parent() == spectator,
		"viewport camera is %s" % ["none" if live == null else String(live.get_path())])

	# --- §2.3's solo half: the vacated seat is bot-filled, the match is still a 2v2 ----
	var units := main.find_children("*", "CharacterBase", true, false)
	var ai_driven := 0
	for unit in units:
		if (unit as CharacterBase).is_ai_driven():
			ai_driven += 1
	_check("§2.3 the match is still four units", units.size() == 4,
		"found %d" % units.size())
	# ⚠️ NOT A SPECTATOR CHECK ON ITS FACE, AND IT EARNS ITS PLACE ANYWAY. Footage of four
	# Props that cannot use a kit is not footage of this game, and `main.gd::
	# _prop_ability_for()` is the fallback that gives an AI-held Prop one. It is also the
	# one function this lane changed for a reason unrelated to spectating (§3.11 — the
	# three ability constants are typed `Resource` now and cast here), so this is the
	# guard on that change: a bad cast would return null silently and cost the props their
	# abilities with nothing anywhere reporting it.
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

	# --- §2.2 it flies, and it flies THROUGH things -----------------------------------
	var start: Vector3 = spectator.global_position
	# Straight down, from 9 m up, far past the road surface. Nothing here asks physics
	# for permission, so "did it stop at the ground" is a real question with a real
	# answer.
	# ⚠️ `spectator_down`, NOT `guard_dash` — see `spectator_camera.gd::_process`'s own
	# note: `guard_dash` was deleted along with Can-Dash and Flick Dash, and this probe
	# was still asking for it, which threw every single frame of this section without
	# ever failing a `_check` for it — the same "GDScript error fills the log and
	# nothing stops the frame" trap `_follow_name()`'s doc warns about.
	# ⚠️ WAIT TIMES ARE SIZED TO `BASE_SPEED`/`BOOST_SCALE` AS THEY STAND TODAY (3.6 and
	# 2.5×), NOT TO THE 12.0 THIS SECTION WAS ORIGINALLY WRITTEN AGAINST. `BASE_SPEED` was
	# tuned down twice on direct human instruction (see its own doc) and this section's
	# durations were never re-derived — at the old 2.0 s / 3.0 s / 4.0 s they measured
	# nothing but noise once `spectator_down` actually started arriving.
	Input.action_press("spectator_down")
	await _wait(3.0) # 3.6 m/s * 3.0 s = 10.8 m, past the 9 m start height
	Input.action_release("spectator_down")
	await _wait(0.5)
	var descended: float = start.y - spectator.global_position.y
	_check("§2.2 it flies", descended > 4.0, "descended %.2f m" % descended)
	_check("§2.2 it clipped through the ground plane", spectator.global_position.y < 0.0,
		"y = %.2f m" % spectator.global_position.y)

	# --- §2.2 "flies ANYWHERE" · 🧑 2026-07-31: "make sure the spectator can fly to
	# anywhere". Down through the road is one direction. These are the other two, and
	# they are the ones a clamp, a bound or a kill plane would show up in: straight up
	# past the rooflines, and far out past the edge of the built map. Nothing in this
	# node clamps `global_position`, and the kill plane is an Area3D that detects BODIES —
	# a spectator has none — so the claim is that there is no ceiling and no fence. That
	# is a claim, and it is cheap to actually measure.
	Input.action_press("sprint") # boost, so the sample is unambiguous
	Input.action_press("jump")
	await _wait(7.0) # BOOST_SCALE(2.5) * BASE_SPEED(3.6) = 9.0 m/s; 7.0 s clears 60 m
	Input.action_release("jump")
	await _wait(0.5)
	var ceiling: float = spectator.global_position.y
	_check("§2.2 no ceiling — it climbs past the rooflines", ceiling > 60.0,
		"y = %.1f m" % ceiling)
	# ⚠️ AIM LEVEL AND DUE NORTH FIRST. "Forward" is the CAMERA's forward, and by this point
	# the camera has been flown up and down, so its pitch decides how much of the burst
	# goes sideways versus straight up. The first version of this check just held
	# `move_up` and measured horizontal distance, and it read 115.4 m on one run and 18.0 m
	# on the next off the same code — the camera was simply pointing somewhere else. That
	# is a probe measuring its own starting conditions, which is exactly the class of
	# metric `docs/README.md`'s impossible-number rule is about. Pinned, so the number
	# means "how far can it get", not "where was it looking".
	spectator._pitch_deg = 0.0
	spectator._yaw = 0.0
	spectator._apply_rotation()
	await _wait(0.2)
	var out_start := Vector2(spectator.global_position.x, spectator.global_position.z)
	Input.action_press("move_up") # forward, away from the arena
	await _wait(12.0) # 9.0 m/s * 12.0 s = 108 m, past the 100 m gate
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

	# --- §2.6 filmable: a speed control that spans wide and close ----------------------
	var speed_before: float = spectator._speed
	_send_wheel(MOUSE_BUTTON_WHEEL_UP)
	_send_wheel(MOUSE_BUTTON_WHEEL_UP)
	await _wait(0.2)
	_check("§2.6 the wheel changes fly speed", spectator._speed > speed_before,
		"%.1f -> %.1f m/s" % [speed_before, spectator._speed])

	var hud := main.get_node_or_null("HUDLayer/HUD")
	if hud == null:
		hud = main.find_children("*", "HUD", true, false).front() if not main.find_children(
			"*", "HUD", true, false).is_empty() else null

	# --- Master_Prompt_Updated_Spectator.md § B.1 · TAB is the camera switcher, and it
	# switches straight INTO POV — not over-the-shoulder first. -------------------------
	_send_key(KEY_TAB)
	await _wait(0.5)
	_check("TAB from free flight lands on a real unit", spectator._follow != null,
		"following %s" % [spectator._follow.name if spectator._follow != null else "nothing"])
	_check("TAB's first press is POV IMMEDIATELY, not follow-then-V", spectator._pov)
	var target: Node3D = spectator._follow
	var eye: float = spectator.global_position.y - target.global_position.y
	_check("POV: the camera sits at the unit's eye height, not behind it",
		spectator.global_position.distance_to(target.global_position) < 1.8 and eye > 0.1,
		"%.2f m away, %.2f m above" % [
			spectator.global_position.distance_to(target.global_position), eye])
	_check("POV: the yaw is TAKEN from the unit",
		absf(angle_difference(spectator._yaw, target.global_rotation.y)) < 0.05,
		"camera %.3f rad vs unit %.3f rad" % [spectator._yaw, target.global_rotation.y])
	# --- Master_Prompt_Spectator_Player_POV.md §A/§C.1 · THE BORROW, READ-ONLY ---------
	# The old contract here asserted the rig was NEVER activated — that placement design
	# is reversed. The new contract: the rig DOES render (arms, self-hide, its own
	# camera), and DOES NOT read this machine's input under any circumstance.
	var rig := target.get_node_or_null("CameraRig") as CameraRig
	_check("POV: exactly one rig is borrowed, and it is this unit's",
		rig != null and spectator._borrowed_rig == rig and rig.is_spectated())
	_check("POV: the borrowed rig renders like an active rig",
		rig != null and rig._active and rig.fpp_camera.current)
	_check("POV: the borrowed rig's OWN camera is the one being rendered, not the spectator's",
		get_viewport().get_camera_3d() != null
			and get_viewport().get_camera_3d() == rig.fpp_camera,
		"viewport camera is %s" % ["none" if get_viewport().get_camera_3d() == null
			else String(get_viewport().get_camera_3d().get_path())])
	_check("POV: the spectator's OWN camera stood down while borrowing",
		not spectator._camera.current)
	# ⚠️⚠️ THE ONE THING THAT MUST STAY IMPOSSIBLE — watching must not change what they
	# do. Asserted directly against the Node-level processing flag, not inferred from
	# `aim_source`, because `aim_source` alone would pass even if `set_active()`'s old
	# `set_process_unhandled_input(active and aim_source == MOUSE)` line had leaked back
	# in — this is the actual gate that decides whether this machine's mouse can reach
	# the body.
	_check("POV: the borrowed rig NEVER processes unhandled input",
		rig != null and not rig.is_processing_unhandled_input())
	# `aim_source` is whatever this MACHINE already computed for this unit at spawn
	# (MOVEMENT for the bot this test happens to land on) — not asserted against that
	# specific value, since the point is that the borrow never WRITES it, not what it
	# happened to already be. Snapshotted here and compared again after release below.
	var aim_source_before_borrow := rig.aim_source
	# The arms are the visible half of the borrow actually working — the reference frame
	# 🧑 gave this brief for is an FPP shot WITH arms, not an eye placement without them.
	var arms := rig.get_node_or_null("FppPivot/ViewmodelArms") as Node3D
	if arms == null:
		# Built lazily by `_viewmodel_arms()` — find it by scanning FppPivot's children
		# instead of assuming the scene-authored node name.
		for child in rig.fpp_pivot.get_children():
			if child.name != "FppCamera":
				arms = child as Node3D
				break
	_check("POV: the viewmodel arms are visible", arms != null and arms.visible)
	if hud != null:
		_check("HUD: the spectated name matches display_name(), plus role",
			hud._spectator_target_name != null
				and hud._spectator_target_name.text == "%s · %s" % [target.display_name(),
					"TAYA" if target.is_defender else "ATTACKER"],
			"'%s'" % [hud._spectator_target_name.text if hud._spectator_target_name != null
				else "<none>"])

		# --- Master_Prompt_Spectator_Player_POV.md § C.4 · the frost runs off THEM ------
		# ⚠️ SOLO ONLY PROVES THE WIRING, NOT THE UNREPLICATED-COUNTDOWN FALLBACK. This
		# peer simulates the bot directly, so `stagger_time_left()` returns a real
		# number here the same way it would for this peer's OWN body — the networked
		# case, where a spectated unit's countdown is genuinely unreplicated and
		# `_refresh_frost()` must hold at full coverage instead of reading a bare 0,
		# is not exercised by this run. Left as a known gap rather than claimed.
		var target_char := target as CharacterBase
		target_char.apply_stagger(3.0)
		await _wait(0.5)
		_check("FROST: staggering the spectated player raises screen frost",
			hud._frost_coverage > 0.5,
			"coverage=%.2f" % hud._frost_coverage)
		await _wait(3.5)
		_check("FROST: it clears once the spectated player's stun ends",
			hud._frost_coverage < 0.05,
			"coverage=%.2f" % hud._frost_coverage)

	# --- Master_Prompt_Spectator_Player_POV.md § C.5 · the arm retracts for a
	# spectator too, off `observed_charge_power()` rather than the silent-here
	# `charge_power()`/`is_charging()`. Driven directly through the observed clock's
	# own RPC handler rather than a real held-slipper charge, so this measures the
	# mechanism (borrowed rig + every-peer clock reaches the visible arm) without
	# needing an attacker mid-round to already be holding something.
	var vm_arm: Node3D = null
	if arms != null:
		vm_arm = arms.get_node_or_null("RightPivot/Arm") as Node3D
	if vm_arm != null:
		var target_carrier := (target as CharacterBase).get_node_or_null("Carrier") as Carrier
		var rot_before: float = vm_arm.rotation.x
		target_carrier._rpc_charge_visual(true)
		await _wait(1.4)
		var rot_mid: float = vm_arm.rotation.x
		_check("WIND-UP: the spectated arm retracts from an observed charge",
			absf(rot_mid - rot_before) > 0.05,
			"rotation.x %.3f -> %.3f rad" % [rot_before, rot_mid])
		target_carrier._rpc_charge_visual(false)
		await _wait(0.3)

	# --- V still toggles POV <-> over-the-shoulder on the SAME target -------------------
	_send_key(KEY_V)
	await _wait(0.4)
	_check("V drops out of POV into over-the-shoulder, same target",
		not spectator._pov and spectator._follow == target)
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
	_check("V re-enters POV on the same target", spectator._pov and spectator._follow == target)

	# --- Master_Prompt_Updated_Spectator.md § B.2 · left click leaves POV ---------------
	var pos_before_click: Vector3 = spectator.global_position
	var yaw_before_click: float = spectator._yaw
	var pitch_before_click: float = spectator._pitch_deg
	_send_left_click()
	await _wait(0.05)
	_check("LEFT CLICK drops the follow target", spectator._follow == null)
	_check("LEFT CLICK clears POV", not spectator._pov)
	# --- Master_Prompt_Spectator_Player_POV.md §C.3 · the release restores the unit ----
	_check("LEFT CLICK releases the borrowed rig", spectator._borrowed_rig == null)
	_check("LEFT CLICK: the released rig is no longer spectated, current, or processing",
		not rig.is_spectated() and not rig.fpp_camera.current
			and not rig.is_processing_unhandled_input())
	_check("LEFT CLICK: the spectator's OWN camera reclaimed the view",
		spectator._camera.current and get_viewport().get_camera_3d() == spectator._camera)
	_check("LEFT CLICK: the arms are hidden again", arms == null or not arms.visible)
	_check("aim_source was never written across the whole POV cycle (borrow + release)",
		rig.aim_source == aim_source_before_borrow,
		"before=%s after=%s" % [aim_source_before_borrow, rig.aim_source])
	var visual_root := target.get_node_or_null("Visual")
	var meshes: Array[Node] = visual_root.find_children("*", "GeometryInstance3D", true, false) \
		if visual_root != null else []
	var still_shadows_only := 0
	for mesh in meshes:
		if (mesh as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			still_shadows_only += 1
	_check("LEFT CLICK: the unit's own body casts real shadows again, not SHADOWS_ONLY",
		not meshes.is_empty() and still_shadows_only == 0,
		"%d of %d meshes still SHADOWS_ONLY" % [still_shadows_only, meshes.size()])
	_check("LEFT CLICK moves the camera only a few centimetres that frame",
		spectator.global_position.distance_to(pos_before_click) < 0.05,
		"%.4f m" % spectator.global_position.distance_to(pos_before_click))
	_check("LEFT CLICK keeps the operator's yaw/pitch",
		absf(angle_difference(spectator._yaw, yaw_before_click)) < 0.01
			and absf(spectator._pitch_deg - pitch_before_click) < 0.01)
	await _wait(0.3)
	_check("LEFT CLICK's exit still holds a moment later — no lerp back across the map",
		spectator.global_position.distance_to(pos_before_click) < 0.5,
		"%.3f m" % spectator.global_position.distance_to(pos_before_click))
	if hud != null:
		_check("HUD: the spectated name is gone in free flight",
			hud._spectator_target_name != null and hud._spectator_target_name.text == ""
				and not hud._spectator_target_name.visible)
	var pos_before_noop_click: Vector3 = spectator.global_position
	_send_left_click()
	await _wait(0.1)
	_check("LEFT CLICK in free flight is a no-op",
		spectator._follow == null and not spectator._pov
			and spectator.global_position.distance_to(pos_before_noop_click) < 0.05)

	# --- Master_Prompt_Updated_Spectator.md § B.1 · TAB wraps, it never falls out -------
	var total_units: int = units0.size()
	var first_wrapped: Node3D = null
	var never_dropped_free := true
	for i in range(total_units + 1):
		_send_key(KEY_TAB)
		await _wait(0.15)
		if spectator._follow == null:
			never_dropped_free = false
		if i == 0:
			first_wrapped = spectator._follow
	_check("N+1 TABs never fall back out to free flight", never_dropped_free)
	_check("TAB wraps back to the first unit after a full cycle",
		spectator._follow == first_wrapped,
		"first=%s now=%s" % [
			first_wrapped.name if first_wrapped != null else "?",
			spectator._follow.name if spectator._follow != null else "?"])

	_send_key(KEY_F)
	await _wait(0.3)
	_check("§2.6 F returns to free flight", spectator._follow == null)
	_check("F drops POV with it", not spectator._pov)

	# --- §2.5 / §2.7 the HUD ----------------------------------------------------------
	_check("the HUD is reachable", hud != null)
	if hud != null:
		_check("§2.5 the YOU card is gone (it describes a character)", not hud.you_card.visible)
		_check("§2.5 the crosshair is gone", not hud.crosshair.visible)
		_check("§2.5 the lata card is gone", not hud.lata_card.visible)
		# ⚠️ `_status_rows_left` / `_status_rows_right`, NOT `_status_rows` — the single
		# array was split into two sides after this check was written; the old name no
		# longer exists on `hud.gd` at all.
		_check("§2.5 no orphaned status rows were built",
			hud._status_rows_left.is_empty() and hud._status_rows_right.is_empty(),
			"%d left, %d right" % [hud._status_rows_left.size(), hud._status_rows_right.size()])
		_check("§2.7 the round readout exists and says something",
			hud._spectator_round != null and hud._spectator_round.text != "",
			"'%s'" % (hud._spectator_round.text if hud._spectator_round != null else ""))
		_check("§2.6 the live camera readout exists and says something",
			hud._spectator_status != null and hud._spectator_status.text != "",
			"'%s'" % (hud._spectator_status.text if hud._spectator_status != null else ""))

	if _shots_dir != "":
		# ⚠️ TWO SHOTS, BECAUSE THEY ARE TWO DIFFERENT CLAIMS. "The free camera renders"
		# and "POV renders somebody else's view" are not evidence for each other, and this
		# lane has already had one mode pass every assertion while drawing the wrong
		# picture entirely.
		spectator._target_position = Vector3(0.0, 7.0, 13.0)
		spectator.global_position = spectator._target_position
		await _wait(1.5)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			_shots_dir.path_join("spectator_ingame.png"))
		print("[%s]  wrote spectator_ingame.png" % _tag)
		# POV of a PERSON specifically — every `spectatable` unit already is one (Lata
		# and Slipper are plain Node3D, not CharacterBase), but this is the shot the
		# reference frame is judged against, so pick one explicitly rather than
		# trusting list order.
		for unit in units:
			if (unit as CharacterBase).is_person:
				spectator._follow = unit as Node3D
				break
		spectator._pov = true
		# ⚠️ `_begin_borrow()`, NOT A BARE FLAG FLIP. Since POV became a real rig
		# borrow, setting `_follow`/`_pov` alone leaves `_borrowed_rig` null — the
		# camera's own `_process` would then sync from nothing and sit frozen wherever
		# the free-flight shot above left it, rendering THAT camera's stale frame
		# under a filename that claims to be somebody's first-person view. Measured
		# once already: exactly the "picture is wrong, every check is green" failure
		# this probe's own header warns about.
		spectator._begin_borrow(spectator._follow)
		await _wait(1.5)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			_shots_dir.path_join("spectator_pov.png"))
		print("[%s]  wrote spectator_pov.png" % _tag)

	# --- Master_Prompt_Updated_Spectator.md § B.3 · exit_spectator_mode() frees the label.
	# Last, because it strips the whole spectator HUD (restores you_card etc.) and every
	# earlier check above depends on that HUD still being in spectator mode.
	if hud != null:
		spectator._release_borrow() # clean handoff from the POV shot above, if any
		spectator._follow = units.front() if not units.is_empty() else null
		spectator._pov = spectator._follow != null
		if spectator._pov:
			spectator._begin_borrow(spectator._follow)
		await get_tree().process_frame
		_check("the spectated-name label exists before exit", hud._spectator_target_name != null
			and is_instance_valid(hud._spectator_target_name))
		hud.exit_spectator_mode()
		await get_tree().process_frame
		await get_tree().process_frame
		_check("exit_spectator_mode() frees the spectated-name label",
			hud._spectator_target_name == null)

## Raw events through `Input.parse_input_event`, so they arrive at
## `SpectatorCamera._unhandled_input` down the real chain rather than by calling it.
## True while this unit is riding in somebody's hand rather than standing on the street.
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

## Same real chain as `_send_wheel` — `MOUSE_BUTTON_LEFT`, proving the POV-exit click
## actually arrives at `SpectatorCamera._unhandled_input` rather than being eaten by the
## HUD's own `_input()` (the emote wheel reads mouse buttons there, and it runs first).
func _send_left_click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
