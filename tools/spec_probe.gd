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
## host's. Measured 2026-07-31: HOST 22/22, JOIN 8/8, --solo 31/31.

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
	elif "--solo" in args:
		_tag = "SOLO"
		await _run_solo()
	else:
		print("spec_probe: pass --lobby-host, --lobby-join=<ip> or --solo")
		get_tree().quit(1)
		return
	_finish()

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
	_check("§2.1 the toggle shows its own state",
		"WATCHING" in (lobby.find_child("SpectateButton", true, false) as Button).text)
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

func _run_solo() -> void:
	GameLaunch.pending_action = "local"
	GameLaunch.spectator = true
	GameLaunch.solo_seat = 0
	var main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	main.name = "Main"
	get_tree().root.add_child(main)
	await _wait(4.0)

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
	# Straight down, from 9 m up, for two seconds at 12 m/s: far past the road surface.
	# Nothing here asks physics for permission, so "did it stop at the ground" is a real
	# question with a real answer.
	Input.action_press("guard_dash")
	await _wait(2.0)
	Input.action_release("guard_dash")
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
	await _wait(3.0)
	Input.action_release("jump")
	await _wait(0.5)
	var ceiling: float = spectator.global_position.y
	_check("§2.2 no ceiling — it climbs past the rooflines", ceiling > 60.0,
		"y = %.1f m" % ceiling)
	Input.action_press("move_up") # forward, away from the arena
	await _wait(4.0)
	Input.action_release("move_up")
	Input.action_release("sprint")
	await _wait(0.5)
	var out: float = Vector2(spectator.global_position.x,
		spectator.global_position.z).length()
	_check("§2.2 no fence — it leaves the built map entirely", out > 100.0,
		"%.1f m from the circle, at y = %.1f m" % [out, spectator.global_position.y])
	_check("§2.2 it is still the rendered camera out there",
		get_viewport().get_camera_3d() != null
			and get_viewport().get_camera_3d().get_parent() == spectator)

	# --- §2.6 filmable: follow cycle, and a speed control that spans wide and close ----
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
	# --- 2.8 · POV, the human's own ask: watch through a unit's eyes -------------------
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
	# ⚠️ THE POINT OF DOING THIS WITHOUT THE RIG: watching must not change what they do.
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

	# --- §2.5 / §2.7 the HUD ----------------------------------------------------------
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
		# POV of a PERSON specifically — the Prop case is a slipper on the road and reads
		# as a bug in a still even when it is correct.
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

## Raw events through `Input.parse_input_event`, so they arrive at
## `SpectatorCamera._unhandled_input` down the real chain rather than by calling it.
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
