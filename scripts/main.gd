extends Node3D

## Match scene entry point, dual-purpose:
## - No launch args: local single-PC/split-keyboard flow, spawning the real
##   4-unit Person+Prop structure (see below).
## - `--host`: starts a LAN server, removes the local test characters, and
##   spawns a real networked character per connected peer instead.
## - `--join=<address>`: connects to a host at that address, same swap.
##
## This is the fastest way to test real multi-device play right now: run one
## exported/editor instance with `--host`, another with `--join=<host LAN IP>`
## (or `--join=127.0.0.1` for two instances on one PC via
## Debug > Run Multiple Instances). No lobby UI yet — see
## docs/Handoff.md for what's still missing.
##
## A team is 2 players — 1 Person (tags/throws) + 1 Can/Slipper Prop (carries
## the roster's class ability) — NOT two interchangeable Can/Tsinelas units.
## See CharacterBase.is_person / _spawn_player below.
##
## The local single-PC flow mirrors that structure: all 4 nodes come from
## Main.tscn, and the player controls TeamAPerson (P1 keys) and TeamAProp
## (P2 keys) — i.e. one full team, Person + Prop, so both Tag and Quick Stand
## are directly testable locally. TeamBProp/TeamBPerson are
## local-test dummies (p3/p4, deliberately unbound in project.godot — see
## CharacterBase.player_id doc) standing in as a stationary opponent team.
## Round-swap (Can vs Slipper side) is wired for this flow too — see
## _on_match_round_started.

@onready var team_a_prop: CharacterBase = $TeamAProp
@onready var team_a_person: CharacterBase = $TeamAPerson
@onready var team_b_prop: CharacterBase = $TeamBProp
@onready var team_b_person: CharacterBase = $TeamBPerson
@onready var players_root: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var hud: Hud = $HUDLayer/HUD
## B-51 (residual): consulted by the Esc handler so pausing can't cover the
## match-result screen. Read-only from here — MatchResult wires itself to
## MatchManager and needs nothing from main.gd.
@onready var match_result: MatchResult = $HUDLayer/MatchResult
@onready var map_root: Node3D = $Map
## Checklist 2.2a: the KillPlane belongs to the MAP now, not to Main.tscn, so it
## cannot be an @onready NodePath any more — the map is not instanced until
## _load_map() runs. Resolved from the loaded map instead.
var kill_plane: KillPlane = null
## B-20: no way out of a match existed except Alt+F4.
@onready var pause_root: Control = %PauseRoot
@onready var resume_button: Button = %ResumeButton
@onready var menu_button: Button = %MenuButton
@onready var settings_button: Button = %SettingsButton
@onready var settings_panel: SettingsPanel = %SettingsPanel
## Q-3/B-64: text swaps to a non-freezing warning in networked play — see
## _on_pause_toggle_requested.
@onready var paused_label: Label = %PausedLabel
## Q-3/B-64: owns the Esc _unhandled_input listener itself, at
## PROCESS_MODE_ALWAYS — see pause_layer.gd's doc for why that can't live on
## Main (this node's own script) once the tree is actually paused.
@onready var pause_layer: PauseLayer = $PauseLayer

const CHARACTER_SCENE: PackedScene = preload("res://scenes/characters/CharacterBase.tscn")
## Every Person — networked or local — gets its own Tag/Throw ability
## instance, `.duplicate()`d from this one preloaded Resource rather than
## shared directly, since AbilityBase.tick()/is_ready() carry per-instance
## cooldown state (_time_since_use, _used_this_round) on the Resource itself;
## two Persons sharing the same instance would incorrectly share a cooldown.
## Same trap applies to roster Prop abilities (Quick Stand, etc.) once THEIR
## networked-spawn assignment gets built — today only the local flow's
## TeamAProp has one wired directly in Main.tscn, since it's the only
## character using that particular resource instance.
const PERSON_ACTION_ABILITY: AbilityBase = preload("res://scripts/abilities/resources/person_action.tres")
## B-76: every networked and local-test Prop used to get Quick Stand
## regardless of which side of the round it was playing. Quick Stand has no
## get_throw_profile(), so a Prop on the offence side threw with no identity
## at all — carriable.gd's _profile() fell back to throw_default.tres and none
## of the three Tsinelas specials (Bagsak Bomb, Bakya Bash, Flick Dash) were
## ever reachable in a running game. `.tres` for the other two Can specials
## (Spin Guard, Shatter Trap) exist too but aren't wired to any roster slot
## yet — same B-24/Phase 2 gap as the Tsinelas side, character select assigns
## both eventually.
##
## Interim fix, per checklist 0.2: _prop_ability_for() below picks the ability
## from role (is_can) + team, called at spawn AND every round reset
## (_reset_world) — is_can flips every round, so a Prop's ability has to be
## re-picked every round or it goes stale exactly one round after spawn, which
## is the same "resolved once, wrong from round 2" trap as B-42/B-80(c).
## `.duplicate()` at every call site per PERSON_ACTION_ABILITY doc.
const CAN_ABILITY: AbilityBase = preload("res://scripts/abilities/resources/quick_stand.tres")
## Two of the three Tsinelas identities, picked one per team for the biggest
## contrast a 2-Prop match can show: Bakya Bash is the heavy knockdown
## (forces_downed, flattest-but-one arc), Flick Dash is the fast curving poke
## (steers hardest, never forces downed). A 2v2 match only ever has 2 Props,
## so a single sitting cannot reach all three roster identities regardless of
## which two are picked here — that needs 3.3 (character select). Bagsak Bomb
## (the lob) is reachable today only by swapping one of these two constants.
const TSINELAS_ABILITY_TEAM_A: AbilityBase = preload("res://scripts/abilities/resources/bakya_bash.tres")
const TSINELAS_ABILITY_TEAM_B: AbilityBase = preload("res://scripts/abilities/resources/flick_dash.tres")
## Local-test roster, in a flat array so round-swap/registration code (below)
## can treat all 4 the same way it treats _spawned_characters for the
## networked flow, rather than hand-writing 4 near-identical blocks.
## Populated once in _ready(); order is [TeamAProp, TeamAPerson, TeamBProp, TeamBPerson].
var _local_roster: Array[CharacterBase] = []
## FALLBACK ONLY, since checklist 2.2a. The real spawn points are four Marker3Ds
## under the loaded map's `SpawnPoints` node; this array is used only if a map
## has none — or if something loads Main.tscn with no map at all, which is what
## the render harness does. Indexed by ROLE SLOT (see SLOT_* below), matching
## the real maps' layout: the Can near the middle, the Attacker/Tsinelas pair
## a few units off.
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(0, 0.17, 0), Vector3(2, 0.8, 1), Vector3(0, 0.8, 6), Vector3(1, 0.16, 6)
]

## Resolved once per match from the loaded map, then reused. Rebuilt on every
## _load_map(), never cached across maps.
var _map_spawns: Array[Transform3D] = []

## Checklist 3.5 — instances the map the player picked, into $Map.
##
## The map owns the floor, the boundary, the kill plane, the field markings, the
## hazard, the WorldEnvironment and its own sky. Main.tscn deliberately carries
## NONE of those any more: a second WorldEnvironment in this scene would fight
## the map's, and a hardcoded floor is what made every map look the same.
##
## ⚠️ NO CAMERA IS ADDED HERE OR IN A MAP. Person -> FPP, Prop -> TPP, derived
## from is_person. That is the standing directive; a scene-level Camera3D is the
## violation A-2 deleted and it caused B-03.
func _load_map() -> void:
	_map_spawns.clear()
	for child in map_root.get_children():
		map_root.remove_child(child)
		child.queue_free()

	var path := GameLaunch.selected_map_scene()
	var packed := load(path) as PackedScene
	if packed == null:
		# Deliberately not fatal. A missing map must not cost the player their
		# match — they get the fallback spawn ring and a warning in the log.
		push_warning("main.gd: could not load map '%s'; running with no map." % path)
		return
	var instance := packed.instantiate() as Node3D
	map_root.add_child(instance)

	kill_plane = instance.find_child("KillPlane", true, false) as KillPlane

	var points := instance.get_node_or_null("SpawnPoints")
	if points == null:
		push_warning("main.gd: map '%s' has no SpawnPoints; using the fallback ring." % path)
		return
	# Sorted by node name, NOT by get_children() order. B-68 is the same class of
	# bug on the round-reset path: an order that depends on how the scene happens
	# to be authored silently reassigns teams. Spawn0..Spawn3 is the contract.
	var markers: Array[Node] = points.find_children("*", "Marker3D", false, false)
	markers.sort_custom(func(a: Node, b: Node) -> bool: return a.name < b.name)
	for marker in markers:
		# The whole TRANSFORM, not just the origin. A spawn point has to say
		# which way you are FACING as well as where you stand — the first render
		# of this had all four units spawn at the ends of the alley looking at
		# the wall behind them, because a Marker3D with no rotation means the
		# default -Z facing and half the spawns are at the far end.
		_map_spawns.append((marker as Marker3D).transform)

## Spawn slots are ROLE-based, not team-based, since the human playtest of the
## proportion fix (2026-07-28): "two teams spawn on completely different ends
## and i dont think thats how it should go." They were right — the old scheme
## put TeamAProp/TeamAPerson at one end of the alley and TeamBProp/TeamBPerson
## at the other, UNCONDITIONALLY, while the map's own base_circle_decal and
## throwing_line_decal (Art_Direction.md §9) sit at the CENTRE regardless of
## who is spawning where. Whichever team happened to be defending that round
## spawned wherever its fixed team slot was — sometimes the north end, sometimes
## the south — never actually AT the base circle the mechanic is built around.
## That is what "two teams spawn on completely different ends" was: not merely
## "far apart", but structurally disconnected from tumbang preso's actual
## shape (one guarded base, one throwing line), because position tracked TEAM
## (fixed all match) instead of ROLE (swaps every round).
##
## The four slots below are ROLES, and the physical Marker3D positions never
## move — only which unit currently occupies which slot does, exactly like
## is_can/team_is_can_side already do for everything else that flips each
## round. Spawn0 sits ON the base circle, Spawn1 is the guarding Taya a few
## units off it, Spawn2 is the Attacker at the 6-unit throwing line
## (Art_Direction.md §9's own "why 6.0" derivation), Spawn3 is that round's
## loose Tsinelas beside the Attacker (see _reset_world's auto-grab, below,
## for why it does not usually stay loose for long).
const SLOT_CAN: int = 0
const SLOT_TAYA: int = 1
const SLOT_ATTACKER: int = 2
const SLOT_TSINELAS: int = 3

## Maps a unit's CURRENT role to its spawn slot. `is_can` already implies
## `is_person == false` (CharacterBase's own contract), so checking it first is
## exhaustive: Can, then Taya-or-Attacker by is_person, then whatever Prop is
## left over must be this round's Tsinelas.
func _role_slot(is_can: bool, is_person: bool, team_is_can_side: bool) -> int:
	if is_can:
		return SLOT_CAN
	if is_person:
		return SLOT_TAYA if team_is_can_side else SLOT_ATTACKER
	return SLOT_TSINELAS

## Where slot `index` spawns. Prefers the map's markers and falls back to
## SPAWN_POINTS, so a map with no SpawnPoints still plays.
func _spawn_point(index: int) -> Vector3:
	return _spawn_transform(index).origin

## The full spawn transform. Yaw is taken from the marker so a map can face
## players into the arena; the fallback ring has no opinion and returns none.
func _spawn_transform(index: int) -> Transform3D:
	if not _map_spawns.is_empty():
		return _map_spawns[index % _map_spawns.size()]
	return Transform3D(Basis.IDENTITY, SPAWN_POINTS[index % SPAWN_POINTS.size()])

## Places a character at its slot, facing the way the map says. Kept separate
## from _spawn_point() so the two call sites cannot drift apart on the rotation.
func _place_at_spawn(character: CharacterBase, slot: int) -> void:
	var t := _spawn_transform(slot)
	character.position = t.origin
	character.rotation.y = t.basis.get_euler().y

var _spawned_peer_ids: Dictionary = {}
## B-21: peer_id -> permanently-assigned join index (0..3), separate from
## _spawned_peer_ids.size(). A disconnect/rejoin used to shift every
## subsequent peer's index (and therefore team/role) since the index was
## derived from how many peers happen to be connected right now. Assigned
## once per peer_id and never reused/reassigned, even after that peer leaves.
var _peer_join_index: Dictionary = {}
var _next_join_index: int = 0
## Session 6: real 2v2 team assignment. peer_id -> 0 (Team A) or 1 (Team B),
## fixed for the whole match — replaces the old "alternate Can/Tsinelas by
## join order" 1v1 smoke-test placeholder. First two peers to connect are
## Team A, next two are Team B (GDD: 2v2, teams swap Attacker/Defender role
## each round, per-team not per-player).
var _peer_teams: Dictionary = {}
## Session 7: a team is 1 Person + 1 Can/Slipper Prop, NOT two identical Props
## (corrects the Session 5/6 placeholder, which spawned two interchangeable
## Can/Tsinelas units per team). peer_id -> bool, true if that peer is the
## team's Person. Fixed for the whole match, same lifetime as _peer_teams —
## see _spawn_player for how it's assigned.
var _peer_is_person: Dictionary = {}
var _spawned_characters: Dictionary = {} # peer_id -> CharacterBase

func _ready() -> void:
	# B-14: MatchManager/RoundManager are autoloads and previously carried a
	# finished match's score/round_number into the next one. Main.tscn is the
	# one scene every match path (Local/Host/Join from the menu, or a
	# same-session Rematch that doesn't reload this scene — see
	# match_result.gd) loads through, so reset here is the single point that
	# guarantees a fresh 0-0 round 1 regardless of how we got here.
	MatchManager.reset()
	RoundManager.reset()
	# Item 14: captured for the whole match — FPP without a captured cursor
	# reads as broken, and TPP mouse-look needs it too. Esc toggles it back
	# to visible; there's no pause menu yet (B-20, still open) to hang a real
	# resume flow off of, so pressing Esc again re-captures for now.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# BEFORE anything that touches the world. Spawn points, the kill plane and
	# the WorldEnvironment all live in the map now, not in this scene.
	_load_map()
	spawner.spawn_function = _build_networked_character
	MatchManager.round_started.connect(_on_match_round_started)
	MatchManager.round_intermission_started.connect(_on_round_intermission_started)
	if kill_plane != null:
		kill_plane.character_respawned.connect(_on_character_respawned)
	pause_root.visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_return_to_menu_pressed)
	settings_button.pressed.connect(func() -> void: pause_root.hide(); settings_panel.show())
	settings_panel.back_pressed.connect(func() -> void: settings_panel.hide(); pause_root.show())
	pause_layer.toggle_requested.connect(_on_pause_toggle_requested)

	var join_target := ""
	var should_host := false
	if GameLaunch.pending_action != "":
		# Came from MainMenu.tscn (see main_menu.gd) — this takes priority.
		should_host = GameLaunch.pending_action == "host"
		if GameLaunch.pending_action == "join":
			join_target = GameLaunch.pending_join_address
		GameLaunch.reset() # one-shot; a later replay from the menu sets it fresh
	else:
		# Debug > Run Multiple Instances workflow (see docs/Handoff.md)
		# still works standalone, without going through the menu at all.
		for arg in OS.get_cmdline_user_args():
			if arg == "--host":
				should_host = true
			elif arg.begins_with("--join="):
				join_target = arg.substr(len("--join="))

	if should_host:
		_start_hosting()
	elif join_target != "":
		_start_joining(join_target)
	else:
		_start_local_test()

## Session 9: local single-PC/split-keyboard flow, now spawning the real
## 4-unit Person+Prop structure instead of the old 1v1 Can/Tsinelas smoke
## test. TeamA's Person (P2) needs its own Tag/Throw instance same as any
## networked Person — see PERSON_ACTION_ABILITY doc. TeamB's Person is a
## local-test dummy (unbound input, see Main.tscn/project.godot) but still
## gets its own duplicated instance too, rather than sharing TeamA Person's:
## AbilityBase.tick() runs every physics frame regardless of whether the
## character ever receives input, so two Persons sharing one Resource would
## still incorrectly share cooldown state even though the dummy can never
## press the button itself.
func _start_local_test() -> void:
	_local_roster = [team_a_prop, team_a_person, team_b_prop, team_b_person]
	# B-09: give every local-test unit a team id — without this they all sat at
	# the CharacterBase default (team = 0), which would have made Hitbox's new
	# same-team check treat all four as one team and block every bump.
	team_a_prop.team = 0
	team_a_person.team = 0
	team_b_prop.team = 1
	team_b_person.team = 1
	team_a_person.ability = PERSON_ACTION_ABILITY.duplicate()
	team_b_person.ability = PERSON_ACTION_ABILITY.duplicate()
	# B-76: Main.tscn no longer hardcodes a Prop ability (see its own node
	# comment) — assign the role-correct one here, same as the networked spawn
	# path. _reset_world() re-picks this every round; this is just the round-1
	# value so there's no null/wrong-ability window before the first
	# begin_next_round() below runs it.
	team_a_prop.ability = _prop_ability_for(team_a_prop.is_can, team_a_prop.team).duplicate()
	team_b_prop.ability = _prop_ability_for(team_b_prop.is_can, team_b_prop.team).duplicate()
	_wire_downed_flash(team_a_prop)
	_wire_downed_flash(team_b_prop)
	_register_local_can()
	# Item 13: no authority concept in local test, unlike networked play,
	# where each rig can activate itself from is_multiplayer_authority(). One
	# rig has to be picked explicitly.
	#
	# Defaults to TeamAPerson, so a fresh Local Match drops you into the human
	# character. This used to be TeamAProp, which meant the first thing anyone
	# saw on launch was a third-person shot of a tin can — correct per the GDD
	# (a team is 1 Person + 1 Prop, and the Prop really is the Can) but a poor
	# read as the default. Per the standing directive (§0.1) a Person is ALWAYS
	# first-person, so this default is an FPP view: you see the arena and your
	# own shadow, not your body. Press Tab, or F1-F4, to take the Prop instead.
	# The switcher's own DEFAULT_P1_UNIT is kept in step — it re-applies slot
	# defaults when the DebugBar registers, and would otherwise immediately
	# override whatever is chosen here.
	var default_rig := team_a_person.get_node("CameraRig") as CameraRig
	default_rig.set_active(true)
	default_rig.set_aim_source(CameraRig.AimSource.MOUSE)
	MatchManager.begin_next_round()

## (Re)tells RoundManager which local Prop is currently the Can — whichever
## of TeamAProp/TeamBProp has is_can true this round. Called once up front in
## _start_local_test() and again every round from _on_match_round_started
## once the swap below has updated is_can, so Option A/B win-checks always
## watch the right one instead of staying locked to whoever was Can in round 1.
func _register_local_can() -> void:
	RoundManager.clear_tracked_cans()
	for character in [team_a_prop, team_b_prop]:
		if character.is_can:
			RoundManager.register_can(character)

func _start_hosting() -> void:
	_clear_local_test_characters()
	# U-4: when arriving from the lobby, ENet is already started — skip the
	# second host_game() call (it would fail with "port in use"). Fall through
	# to signal wiring and spawning, which still need to happen here.
	if not NetworkManager.is_networked():
		if NetworkManager.host_game() != OK:
			return
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	# U-4: after the lobby all connected peers are already known; iterate over
	# connected_peer_ids so everyone gets a spawner entry. In a fresh (non-
	# lobby) host flow, connected_peer_ids = [host_id] so behaviour is the same
	# as the old single _spawn_player(multiplayer.get_unique_id()) call.
	for id in NetworkManager.connected_peer_ids:
		_spawn_player(id)
	MatchManager.begin_next_round()

func _start_joining(address: String) -> void:
	_clear_local_test_characters()
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	# Q-1/B-62: only a client can lose its server or fail to reach one — a host
	# has no server to lose, and Local Match has no NetworkManager session at
	# all, so these are wired here rather than _ready().
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	# U-4: when arriving from the lobby, join_game() already ran — skip it.
	if not NetworkManager.is_networked():
		NetworkManager.join_game(address)

func _clear_local_test_characters() -> void:
	RoundManager.clear_tracked_cans()
	# The scene-level ArenaCamera is removed — B-03 is closed, B-58 is closed.
	team_a_prop.queue_free()
	team_a_person.queue_free()
	team_b_prop.queue_free()
	team_b_person.queue_free()
	_local_roster.clear()

func _on_player_connected(peer_id: int) -> void:
	if NetworkManager.is_host():
		_spawn_player(peer_id)
		# B-29/B-48: _start_hosting() already called MatchManager.begin_next_round()
		# before anyone could possibly be connected (see B-13), so every joining
		# peer — not just a "late" one — missed the one-shot _sync_round_started
		# broadcast and is stuck at round_number 0. GameLaunch.game_mode is also
		# never networked at all; each peer reads its own menu selection, so a
		# client's copy can silently disagree with the host's. Catch this one
		# peer up on both in a single reliable RPC.
		_sync_state_to_late_joiner.rpc_id(
			peer_id, MatchManager.round_number, MatchManager.team_a_is_can,
			MatchManager.team_a_wins, MatchManager.team_b_wins,
			RoundManager.time_left, RoundManager.round_active, GameLaunch.game_mode
		)

## B-15/B-35: only show the "OUT OF BOUNDS" toast for a character that's
## actually ours — a client's screen shouldn't flash every time some OTHER
## peer's unit falls off. In local test (not networked at all) every unit is
## on this one screen, so any of them falling is worth a toast.
func _on_character_respawned(character: CharacterBase) -> void:
	if not NetworkManager.is_networked() or character.is_multiplayer_authority():
		hud.show_toast("OUT OF BOUNDS")
	# Dev_Plan.md §3's second Option A win path for the Can side — see
	# RoundManager.register_ring_out()'s own doc for why this was missing and
	# what it filters down to. Called unconditionally (not gated on this being
	# "our" character, unlike the toast above): it's a round-win decision, not
	# a per-viewer cosmetic, and register_ring_out() already gates itself to
	# the host.
	RoundManager.register_ring_out(character)

## Focus loss always releases the mouse outright: alt-tabbing away with the
## cursor still captured is a bad experience regardless of what's on screen.
## The Esc-driven capture/release toggle itself now lives in the pause menu's
## _unhandled_input below (B-20), which owns that transition together with
## showing/hiding the pause overlay.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# B-72: alt-tabbing away released the cursor (above) and NOTHING ever
		# recaptured it. camera_rig.gd::_unhandled_input only reads mouse motion
		# while Input.mouse_mode == MOUSE_MODE_CAPTURED, so coming back left the
		# player able to walk but unable to look — reported as "if you alt tab
		# you can't move camera". Recapture on the way back in.
		#
		# Except when something on screen is meant to be clicked: the pause
		# overlay and the match-result screen both deliberately release the
		# cursor, and stealing it back on focus would undo B-51 and hand back a
		# result screen with no usable pointer.
		#
		# B-77: Godot delivers this notification once at WINDOW CREATION, which
		# is BEFORE _ready() has run — so every @onready below is still null and
		# the three-way `.visible` check threw "Invalid access to property
		# 'visible' on a base object of type 'Nil'" on every single launch of
		# Main.tscn. Found by actually running the scene for 300 frames rather
		# than a --quit smoke test. _ready() sets MOUSE_MODE_CAPTURED itself
		# (main.gd:120), so declining to recapture here is the correct
		# behaviour, not a workaround for the crash.
		if not is_node_ready():
			return
		if pause_root.visible or match_result.visible or settings_panel.visible:
			return
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_player_disconnected(peer_id: int) -> void:
	var node := players_root.get_node_or_null(str(peer_id))
	if node:
		node.queue_free()
	_spawned_peer_ids.erase(peer_id)
	_peer_teams.erase(peer_id)
	_peer_is_person.erase(peer_id)
	_spawned_characters.erase(peer_id)
	# Q-2/B-63: the leaver's node is freed above, but RoundManager's
	# _tracked_cans still held a reference if it was the Can — its guard
	# (`is_instance_valid()`) then silently no-ops forever, so the round could
	# only ever end on the timer. Only the host drives round-win logic (same
	# gate RoundManager itself uses throughout).
	if NetworkManager.is_host():
		_reregister_tracked_cans()
		_rpc_show_toast.rpc("A player left the match")

## Host-only: tells every peer (via MultiplayerSpawner) to construct a
## character for `peer_id`, assigned to a fixed team (2 peers per team, first
## in gets Team A) AND a fixed role within that team — first peer to join a
## team is its Person, second is its Can/Slipper Prop (Session 7: a team is 1
## Person + 1 Prop, not two identical Props — see is_person doc on
## CharacterBase). Which side the team's Prop plays (Can vs Slipper) THIS
## round comes from MatchManager.team_a_is_can, kept in sync by
## _on_match_round_started below; the Person doesn't have a Can/Slipper side,
## it stays a Person all match regardless of role swaps.
func _spawn_player(peer_id: int) -> void:
	if _spawned_peer_ids.has(peer_id):
		return
	_spawned_peer_ids[peer_id] = true
	# B-21: was `_spawned_peer_ids.size()` — a live count that shifts for every
	# peer still connected after someone disconnects, scrambling team/role
	# assignment for everyone whose index moved. Assign once, permanently, per
	# peer_id instead.
	if not _peer_join_index.has(peer_id):
		_peer_join_index[peer_id] = _next_join_index
		_next_join_index += 1
	var index: int = _peer_join_index[peer_id]
	var team := index / 2 # 0, 0, 1, 1 for up to MAX_PLAYERS = 4
	var is_person := index % 2 == 0 # first peer of each team pair is the Person
	var team_is_can_side := (team == 0) == MatchManager.team_a_is_can
	var is_can := team_is_can_side and not is_person
	# Spawn POSITION is role-based (_role_slot), not the team-fixed `index` —
	# see the doc above _role_slot for why. `player_id` below stays index-based
	# on purpose: it is a fixed-for-the-match input-binding assignment, a
	# different question from where this round's fight actually starts.
	var spawn_pos: Vector3 = _spawn_point(_role_slot(is_can, is_person, team_is_can_side))
	# B-30: CharacterBase.player_id was never set on a networked spawn, so every
	# networked character kept the scene default of 1 and read *_p1 actions —
	# harmless by accident (one human per LAN machine binds p1 and controls
	# whichever single character is theirs) except the Settings panel's entire
	# P2 rebind column was dead in networked play. Mirror the is_person split
	# (index % 2) so the Person of each team gets slot 1 (WASD default) and the
	# Prop gets slot 2 (arrows default) — a fixed-for-the-match assignment,
	# same lifetime as is_person. Note this does NOT give the moodboard's
	# WASD-tracks-Attacker/arrows-tracks-Defender scheme, since Attacker/
	# Defender swaps every round while a peer's is_person/player_id don't;
	# that would need input rebinding on every role swap, not just this fix.
	var player_id := (index % 2) + 1
	spawner.spawn({
		"peer_id": peer_id, "position": spawn_pos, "is_can": is_can,
		"is_person": is_person, "team": team, "team_is_can_side": team_is_can_side,
		"player_id": player_id,
	})

## B-76. Picks the ability class a Prop should carry THIS round, given its
## role (is_can) and team. Never cached on the caller's side — call this again
## every time is_can might have changed (spawn, and every _reset_world()).
func _prop_ability_for(is_can: bool, team: int) -> AbilityBase:
	if is_can:
		return CAN_ABILITY
	return TSINELAS_ABILITY_TEAM_A if team == 0 else TSINELAS_ABILITY_TEAM_B

## Runs on every peer (host and clients) when the spawner replicates a spawn.
func _build_networked_character(data: Dictionary) -> Node:
	var character: CharacterBase = CHARACTER_SCENE.instantiate()
	character.name = str(data["peer_id"])
	character.position = data["position"]
	character.spawn_position = data["position"] # B-15/B-35: where KillPlane sends it back to
	character.is_can = data["is_can"]
	character.is_person = data["is_person"]
	character.team_is_can_side = data["team_is_can_side"]
	character.team = data["team"] # B-09: no team identity on CharacterBase before this
	character.player_id = data["player_id"] # B-30: was never assigned, stuck at the scene default of 1
	if data["is_person"]:
		# Session 8: Person's Tag/Throw, replacing the previously-null `ability`
		# for Person (see PersonAction doc). .duplicate() per PERSON_ACTION_ABILITY
		# doc above — don't share cooldown state across the two Persons in a match.
		character.ability = PERSON_ACTION_ABILITY.duplicate()
	else:
		# B-76: the class ability depends on which side of the round this Prop
		# is playing — see _prop_ability_for() doc.
		character.ability = _prop_ability_for(character.is_can, character.team).duplicate()
	character.set_multiplayer_authority(data["peer_id"])
	_peer_teams[data["peer_id"]] = data["team"]
	_peer_is_person[data["peer_id"]] = data["is_person"]
	_spawned_characters[data["peer_id"]] = character
	if data["peer_id"] == multiplayer.get_unique_id() and character.is_can:
		# This is the character we personally control — DownedFlash should
		# only ever reflect what's happening to OUR Can, never a teammate's
		# Person or an opponent's (GDD Section 6: "clear visual read",
		# per-player). Guard on is_can here since the local player might be
		# controlling their team's Person this match, not its Prop.
		_wire_downed_flash.call_deferred(character)
	return character

## Fires on every peer identically (host emits locally, clients receive it via
## MatchManager._sync_round_started — see match_manager.gd) since it's driven
## by fields (team_a_is_can) that are already synced.
func _on_match_round_started(_round_number: int, team_a_is_can: bool) -> void:
	_reset_world(team_a_is_can)
	RoundManager.start_round()

## Item 10 / B-37: called twice per round transition now instead of once —
## immediately when MatchManager.round_intermission_started fires (so the
## world is already reset while the intermission banner shows, per
## Dev_Plan.md §4.6's "WORLD RESET" beat) and again, idempotently, from
## _on_match_round_started when the round actually begins. Recomputes is_can
## for every spawned character from that character's fixed team, which every
## peer already knows from spawn data — no RPC needed, this runs identically
## on every peer. Also frees any live HazardZone / transient ability hitbox
## (B-43) so nothing from the previous round survives into the next.
func _reset_world(team_a_is_can: bool) -> void:
	for node in get_tree().get_nodes_in_group("hazard_zone"):
		if is_instance_valid(node):
			node.queue_free()
	for node in get_tree().get_nodes_in_group("transient_hitbox"):
		if is_instance_valid(node):
			node.queue_free()
	# Build a unified roster — {character, team, is_person} — per mode. Networked:
	# _spawned_characters keyed by peer_id. Local: _local_roster, order
	# [TeamAProp, TeamAPerson, TeamBProp, TeamBPerson] (only used to derive team/
	# is_person below, not for spawn position any more — see _role_slot).
	var roster: Array = []
	if NetworkManager.is_networked():
		for peer_id in _spawned_characters.keys():
			var character: CharacterBase = _spawned_characters[peer_id]
			if not is_instance_valid(character):
				continue
			roster.append({
				"character": character,
				"team": _peer_teams.get(peer_id, 0),
				"is_person": _peer_is_person.get(peer_id, false),
			})
	elif not _local_roster.is_empty():
		for i in range(_local_roster.size()):
			roster.append({
				"character": _local_roster[i],
				"team": _local_roster[i].team,
				"is_person": _local_roster[i].is_person,
			})

	RoundManager.clear_tracked_cans()
	var attacker: CharacterBase = null
	var tsinelas: CharacterBase = null
	for entry in roster:
		var character: CharacterBase = entry["character"]
		var team_is_can_side: bool = (entry["team"] == 0) == team_a_is_can
		# Session 8: every character on the team tracks team_is_can_side now,
		# not just the Prop — Person needs it too. Only the team's Prop can be
		# a Can (Session 7: 1 Person + 1 Prop per team, not two Props).
		character.team_is_can_side = team_is_can_side
		character.is_can = team_is_can_side and not entry["is_person"]
		# B-76: is_can just flipped (or held) above — a Prop's ability has to be
		# re-picked every round or a Tsinelas keeps last round's Can ability
		# (Quick Stand, no throw profile) one round after it stops being one.
		# Persons never change class ability by role, only Props do.
		if not entry["is_person"]:
			character.ability = _prop_ability_for(character.is_can, entry["team"]).duplicate()
		# B-10: reset + reposition every unit — Persons and the off-side Prop
		# were carrying downed/sealed state, dents, and speed multipliers into
		# the next round before this. Position is now ROLE-based, not the old
		# team-fixed slot — see _role_slot's doc above _spawn_point.
		character.reset_for_new_round()
		_place_at_spawn(character, _role_slot(character.is_can, entry["is_person"], team_is_can_side))
		character.spawn_position = character.position # B-15/B-35
		if character.is_can:
			RoundManager.register_can(character)
		elif entry["is_person"] and not team_is_can_side:
			attacker = character
		elif not entry["is_person"] and not team_is_can_side:
			tsinelas = character
	# User feedback, 2026-07-28: "the attacking Person carries the tsinelas"
	# (Dev_Plan.md §3's beat-by-beat loop, step 1) reads as the opening state of
	# a round, not a first chore before it — a real taya at a real tumbang
	# preso match is not waiting for the attacker to walk over and pick up
	# their own teammate. host_grab() is already host-gated internally (see its
	# own doc in carriable.gd), so calling it unconditionally here — this
	# function runs on every peer identically — is safe: only the host's call
	# actually does anything.
	if attacker != null and tsinelas != null:
		var carriable := tsinelas.get_node_or_null("Carriable") as Carriable
		if carriable != null:
			carriable.host_grab(attacker)

## Item 10 / B-37: fires on every peer (see MatchManager._sync_intermission_started)
## the moment a round ends without finishing the match — the gap that never
## used to exist between report_round_win and the next round's timer
## starting. Resets the world early (so players see themselves back at spawn
## during the card animation, not just when the fight starts).
## U-3: RoleSwapCard connects to round_intermission_started directly and
## handles all display — this function retains only the world reset.
func _on_round_intermission_started(_next_round_number: int, next_team_a_is_can: bool, _can_team_won: bool) -> void:
	_reset_world(next_team_a_is_can)

## Host → one late-joining peer (B-29, B-48). Sets every field directly rather
## than replaying _on_match_round_started's reset cascade: that function calls
## reset_for_new_round() and rewrites `position` on every character it knows
## about, which is correct for an actual round transition but would wrongly
## re-zero the position/state/dents of characters that already arrived on this
## peer with correct current values, via MultiplayerSynchronizer's spawn=true
## replication (CharacterBase.tscn's SceneReplicationConfig). Only refreshes
## the HUD's round/role labels directly (Hud.set_round_display) and registers
## already-known Cans with RoundManager for completeness — both side-effect
## free, unlike a full reset.
@rpc("authority", "call_remote", "reliable")
func _sync_state_to_late_joiner(new_round_number: int, new_team_a_is_can: bool, new_team_a_wins: int, new_team_b_wins: int, new_time_left: float, new_round_active: bool, new_game_mode: GameLaunch.GameMode) -> void:
	MatchManager.round_number = new_round_number
	MatchManager.team_a_is_can = new_team_a_is_can
	MatchManager.team_a_wins = new_team_a_wins
	MatchManager.team_b_wins = new_team_b_wins
	RoundManager.time_left = new_time_left
	RoundManager.round_active = new_round_active
	GameLaunch.game_mode = new_game_mode
	hud.set_round_display(new_round_number, new_team_a_is_can)
	hud.refresh_you_card()
	_reregister_tracked_cans()

## Q-2/B-63: shared by _sync_state_to_late_joiner (a joining peer needs to know
## about every already-spawned Can) and _on_player_disconnected (a leaving Can
## must stop being tracked, not leave RoundManager holding a freed reference —
## its own is_instance_valid() guard would otherwise just silently no-op
## forever and the round could then only ever end on the timer).
func _reregister_tracked_cans() -> void:
	RoundManager.clear_tracked_cans()
	for peer_id in _spawned_characters:
		var character: CharacterBase = _spawned_characters[peer_id]
		if is_instance_valid(character) and character.is_can:
			RoundManager.register_can(character)

## Q-5: the "YOU" card's networked path (scripts/ui/you_card.gd) — the one
## character out of _spawned_characters that this peer actually controls.
## Local Match never calls this; it resolves by scanning for player_id == 1
## instead, since there is no is_multiplayer_authority() concept there.
func get_local_character() -> CharacterBase:
	for peer_id in _spawned_characters:
		var character: CharacterBase = _spawned_characters[peer_id]
		if is_instance_valid(character) and character.is_multiplayer_authority():
			return character
	return null

## Q-2/B-63: _on_player_disconnected only runs on the host, but every
## remaining peer should see the toast — call_local so the host's own HUD
## shows it too, same as _rpc_notify_ability_activate's pattern elsewhere.
@rpc("authority", "call_local", "reliable")
func _rpc_show_toast(text: String) -> void:
	hud.show_toast(text)

## Shows/hides the HUD's DownedFlash whenever the given (locally-controlled)
## character enters/exits Downed — but only if it's a Can; Tsinelas/Person
## never flash since the GDD ties this to "your Can got knocked down". Under
## Option A this doubles as the entry point for the dent counter too, since
## both only ever apply to the locally-controlled Can.
##
## Session 9: the is_can check now happens INSIDE the connected callback
## rather than gating the connection itself, so this keeps working correctly
## for a character whose is_can flips between rounds (the local flow's two
## Props, and — as of Session 7/8's role-swap — networked Props too) instead
## of only ever reflecting whatever is_can happened to be true the one time
## this was called.
func _wire_downed_flash(character: CharacterBase) -> void:
	character.state_changed.connect(func(new_state: CharacterBase.State) -> void:
		if character.is_can:
			hud.set_downed_flash(new_state == CharacterBase.State.DOWNED)
	)
	character.dents_changed.connect(func(new_dents: int) -> void:
		if character.is_can and GameLaunch.game_mode == GameLaunch.GameMode.OPTION_A:
			hud.set_dents(new_dents, CharacterBase.MAX_DENTS)
	)

## B-20: Esc toggles a pause overlay with Resume/Return to Menu — previously
## the only way out of a match at all was Alt+F4. Also owns the Item 14 mouse
## capture toggle (previously a bare Esc-only handler with no pause menu):
## the cursor has to be released for the overlay's buttons to be clickable at
## all, and re-captured on Resume so gameplay input isn't stuck showing the
## OS cursor.
##
## Q-3/B-64: fired from pause_layer.gd's _unhandled_input, NOT one of Main's
## own — Main sits at the default PROCESS_MODE_INHERIT, and once the tree is
## actually paused it stops receiving input entirely, including the Esc press
## meant to resume it. See pause_layer.gd's doc for how that was confirmed.
func _on_pause_toggle_requested() -> void:
	# B-51 (residual): the match is over and the result screen owns the
	# screen — PauseLayer is layer 10 and MatchResult sits in HUDLayer, so
	# pausing here draws the overlay ON TOP of the result, and Resume then
	# re-captures the cursor and hands back a result screen you cannot click,
	# which is exactly the softlock B-51 fixed. There is nothing to pause
	# once the match has been decided, so ignore Esc entirely.
	if match_result.visible:
		return
	pause_root.visible = not pause_root.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause_root.visible else Input.MOUSE_MODE_CAPTURED
	# Q-3/B-64: a naive get_tree().paused = true breaks networked play in
	# both directions (Handoff.md §0.3) — the host can't stop the
	# authoritative round timer for everyone because one player pressed
	# Esc, and a client that pauses its own tree stops sending its own
	# movement while the host keeps simulating it regardless. Only Local
	# Match gets a real freeze; networked stays a non-freezing overlay and
	# says so, so the player isn't misled into thinking they've stopped
	# anything.
	if NetworkManager.is_networked():
		paused_label.text = "PAUSED — the match is still running"
	else:
		get_tree().paused = pause_root.visible
		paused_label.text = "PAUSED"

func _on_resume_pressed() -> void:
	pause_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false

func _on_return_to_menu_pressed() -> void:
	# Q-3/B-64: must run before change_scene_to_file — a scene change with the
	# tree still paused loads MainMenu.tscn paused and every button on it dies
	# (Godot doesn't auto-unpause across change_scene_to_file).
	get_tree().paused = false
	if NetworkManager.is_networked():
		NetworkManager.disconnect_network()
	# B-14: leaving a match should reset the same as starting a fresh one does
	# (see main_menu.gd _go_to_match()) — otherwise a Rematch/new match after
	# using this button would resume this match's score.
	MatchManager.reset()
	RoundManager.reset()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

## Q-1/B-62: NetworkManager.server_disconnected already fires when the host's
## peer goes away and already nulls the peer/clears connected_peer_ids itself —
## nothing in the codebase was listening, so a client just sat in Main.tscn
## with a dead peer, a frozen timer, and no way out but Alt+F4. Same teardown
## _on_return_to_menu_pressed does, minus the redundant disconnect_network()
## call (the peer's already gone), plus a status message so the bounce reads
## as "the host left", not a crash.
func _on_server_disconnected() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MatchManager.reset()
	RoundManager.reset()
	GameLaunch.reset()
	GameLaunch.pending_status_message = "Host ended the match."
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

## Q-1/B-62: a Join to a dead/unreachable address previously left the player on
## a black Main.tscn forever — the same soft-lock as a mid-match host quit,
## just triggered before anyone ever connected. Same teardown, different message.
func _on_connection_failed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MatchManager.reset()
	RoundManager.reset()
	GameLaunch.reset()
	GameLaunch.pending_status_message = "Could not reach that host."
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
