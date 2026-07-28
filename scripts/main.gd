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
## 2026-07-28 — Single Player only (see _on_local_pressed's doc in
## main_menu.gd). True from the moment _start_local_test() spawns everyone
## until the player presses "ready_up": during that window
## MatchManager.begin_next_round() has deliberately NOT been called yet, so
## RoundManager.round_active is false and CharacterBase._is_confined_to_base()
## lets the Can/Taya walk anywhere — free roam while waiting to start.
var _awaiting_local_ready: bool = false
## 2026-07-28 — true for the ~3.5s between pressing ready_up and
## begin_next_round() actually firing, while the 3-2-1-GO countdown runs.
## Guards _unhandled_input against a second ready_up press restarting the
## countdown mid-count.
var _counting_down: bool = false
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
	# ⚠️⚠️ LOOKED UP BY EXACT NAME. DO NOT GO BACK TO SORTING. ⚠️⚠️
	#
	# This is THE recurring spawn bug, found 2026-07-29 after surviving several
	# sessions of "spawns are still wrong". The previous version was:
	#
	#     markers.sort_custom(func(a, b): return a.name < b.name)
	#
	# which reads as "sort Spawn0..Spawn3 alphabetically" and is not what it
	# does. `Node.name` is a **StringName**, and `<` on StringName compares the
	# interned POINTER, not the text. Measured on this exact engine build, four
	# nodes authored in order Spawn0..Spawn3 came back as:
	#
	#     [Spawn3, Spawn2, Spawn0, Spawn1]
	#
	# so slot -> marker was scrambled: the Can spawned on the Tsinelas's mark,
	# the Taya on the Attacker's, and the ATTACKER ON THE TAYA'S — i.e. offense
	# standing next to the base circle it is supposed to be throwing at from
	# outside the line. Reported as exactly that, repeatedly.
	#
	# Everything about the old line invited trusting it: `_role_slot()` was
	# correct, the markers were authored in the right order, the comment said
	# "sorted by node name", and the resulting order was STABLE within a run so
	# it looked deterministic. It is not even guaranteed stable BETWEEN runs —
	# StringName intern order depends on what got interned first — which is why
	# this appeared to move around from session to session.
	#
	# Named lookup removes the failure mode rather than fixing this instance of
	# it: there is no ordering to get wrong, and a renamed or missing marker is
	# now a loud warning instead of a silently shuffled roster.
	for slot in range(4):
		var marker := points.get_node_or_null("Spawn%d" % slot) as Marker3D
		if marker == null:
			push_warning("main.gd: map '%s' has no SpawnPoints/Spawn%d; using the fallback ring." % [path, slot])
			_map_spawns.clear()
			return
		# The whole TRANSFORM, not just the origin. A spawn point has to say
		# which way you are FACING as well as where you stand — the first render
		# of this had all four units spawn at the ends of the alley looking at
		# the wall behind them, because a Marker3D with no rotation means the
		# default -Z facing and half the spawns are at the far end.
		_map_spawns.append(marker.transform)

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
	# 4.2: this is a TELEPORT, not a walk — every round reset routes through
	# here, and without this a remote peer's interpolated visual would glide
	# across the map from its previous position to the new spawn point
	# instead of snapping there with everyone else.
	character.snap_visual_interpolation()

var _spawned_peer_ids: Dictionary = {}
## B-21, superseded by 4.3/B-65: token -> permanently-assigned join index
## (0..3), separate from _spawned_peer_ids.size(). B-21 keyed this by peer_id
## so a disconnect/rejoin couldn't shift every OTHER peer's index — but the
## rejoining peer itself still came back as a brand-new peer_id with no entry
## of its own, landing in the next free slot instead of its original team/role
## (B-65). Keyed by NetworkManager's stable per-install token instead: a
## reconnect presents the SAME token under a new peer_id, so it maps straight
## back to the index it already had. See _spawn_player.
var _token_join_index: Dictionary = {}
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
## Abandoned-body placeholder (2026-07-28, user feedback: "instead of
## disappearing it should transition to an AI... just make it stationary and
## make a player be able to join back to their character"). join index (see
## _token_join_index) -> CharacterBase, populated in _build_networked_character
## and, deliberately like NetworkManager.peer_tokens, NEVER erased on
## disconnect — the whole point is finding the SAME character again once its
## owner reconnects under a brand-new peer_id. Keyed by index rather than
## token directly: MultiplayerSpawner's custom spawn data silently truncates
## past 7 entries once it crosses the network (measured — see _spawn_player),
## and index needs no extra entry since every peer already derives it
## identically from data["team"]/data["is_person"].
##
## Real AI now drives every character with no live human behind it — an
## unfilled team/role slot (_fill_empty_slots_with_placeholders) or a real
## peer's slot after they disconnect (_rpc_convert_to_ai) — instead of just
## freezing. Both give the character multiplayer authority 1 (the host, who
## already runs round logic) and add_child() an AIController the same way
## Single Player does (see ai_controller.gd's own class doc), with player_id
## bumped to the unbound 3/4 range so its Input.action_press() calls can never
## collide with a real human's own p1/p2 keystrokes on the same (host)
## machine — see _build_spawn_data's own doc for that trap and its fix.
## Handing a slot BACK to a reconnecting/new human (_rpc_reclaim_character)
## detaches the AIController and restores the human 1/2 player_id range.
var _index_to_character: Dictionary = {}

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
	MatchManager.match_won.connect(_on_match_won_freeze_physics)
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
	# 2026-07-28: user report — "u didnt fix spawn in logic". Local test units
	# used to just sit at Main.tscn's own hand-authored default transforms,
	# which predate the role-based SpawnPoints redesign (2.6) entirely and
	# were never actually seen before this session — _start_local_test() used
	# to call begin_next_round() immediately, and _reset_world() (which DOES
	# use role-based spawns) ran before the first frame was ever shown. Now
	# that there's a pre-round free-roam window, those stale positions are
	# visible and wrong: the Can not on the base circle, the Attacker not
	# facing the Can/Taya, etc. Placing everyone at their real role spawn
	# up front, the same way _reset_world() does every round, fixes it.
	for character in _local_roster:
		_place_at_spawn(character, _role_slot(character.is_can, character.is_person, character.team_is_can_side))
	_wire_downed_flash(team_a_prop)
	_wire_downed_flash(team_b_prop)
	_register_local_can()
	# Checklist 5.5 — Single Player. The human plays team_a_person (see the
	# camera-default doc just below); the other three units on the roster get
	# real AI instead of sitting on unbound input. Attached once, here, not
	# re-attached every round: AIController re-derives its role from
	# is_can/is_person/team_is_can_side on every decide() call, so it stays
	# correct across every role swap without needing to know one happened.
	for character in [team_a_prop, team_b_prop, team_b_person]:
		_attach_ai(character)
	# Item 13: no authority concept in local test, unlike networked play,
	# where each rig can activate itself from is_multiplayer_authority(). One
	# rig has to be picked explicitly.
	#
	# Defaults to TeamAPerson, so a fresh Single Player drops you into the human
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
	# 2026-07-28: begin_next_round() is deliberately NOT called here any more —
	# see _awaiting_local_ready's own doc. Everyone is already spawned at their
	# role position, but the round (and confinement, which is gated on
	# RoundManager.round_active) doesn't start until the player readies up.
	_awaiting_local_ready = true
	hud.show_ready_prompt(true)

## 2026-07-28 — the other half of the pre-round free-roam window. Pressing
## ready_up while waiting simply calls begin_next_round(); MatchManager's own
## round_started signal (already connected in _ready()) fires
## _on_match_round_started(), which both repositions everyone to their role
## spawn via _reset_world() AND calls RoundManager.start_round() — that is
## what re-engages confinement (see _is_confined_to_base()'s round_active
## gate). Nothing else needed here: whoever wandered off gets teleported back
## the instant the round actually begins, same as an ordinary intermission
## already does between rounds.
func _unhandled_input(event: InputEvent) -> void:
	if _awaiting_local_ready and not _counting_down and event.is_action_pressed("ready_up"):
		get_viewport().set_input_as_handled()
		# 7.7 — a body-language read on the ready press. Purely visual: the
		# countdown and the round start are unchanged below, this just means the
		# OTHER players can see it happen in the world instead of only on a HUD.
		# Guarded because the local roster is empty on any non-local path.
		for character in _local_roster:
			if is_instance_valid(character) and character.is_person:
				character.play_visual_action("ready")
		_run_ready_countdown()

## 2026-07-28 — "add a 3 2 1 timer before each match starts too." Runs once,
## between the ready press and the round actually starting; begin_next_round()
## (and the reposition-to-role-spawn + confinement it triggers) only fires
## once the countdown finishes, not on the ready press itself. _counting_down
## guards against a second ready_up press restarting it mid-count.
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
	_counting_down = false
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
	# 4.3/B-65: a peer that connects (or reconnects) from here on has missed
	# the lobby entirely — see NetworkManager.match_in_progress's own doc.
	NetworkManager.player_identified.connect(_on_player_identified)
	NetworkManager.match_in_progress = true
	# U-4: after the lobby all connected peers are already known; iterate over
	# connected_peer_ids so everyone gets a spawner entry. In a fresh (non-
	# lobby) host flow, connected_peer_ids = [host_id] so behaviour is the same
	# as the old single _spawn_player(multiplayer.get_unique_id()) call.
	for id in NetworkManager.connected_peer_ids:
		_spawn_player(id)
	# 2026-07-28, user feedback: "when playing multiplayer, for example only
	# 2 people is playing, there's only 2 characters. it should have 4."
	_fill_empty_slots_with_placeholders()
	MatchManager.begin_next_round()

func _start_joining(address: String) -> void:
	_clear_local_test_characters()
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	# Q-1/B-62: only a client can lose its server or fail to reach one — a host
	# has no server to lose, and Single Player has no NetworkManager session at
	# all, so these are wired here rather than _ready().
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	# U-4: when arriving from the lobby, join_game() already ran — skip it.
	#
	# 4.3/B-65: also decides how to send _rpc_client_ready_for_spawn (tells
	# the host our OWN Main.tscn/MultiplayerSpawner actually exists, so it is
	# safe to replicate a spawn to us — see that RPC's own doc). Already
	# networked (arrived via Lobby, or NetworkManager just redirected us here
	# mid-match) means the connection is live RIGHT NOW, so send it
	# immediately. A fresh join_game() call here is still mid-handshake the
	# instant it returns — an RPC sent this same frame throws "trying to call
	# an RPC via a multiplayer peer which is not connected" (measured, not
	# guessed: the two-instance test threw exactly that before this was
	# split) — so that case waits for the real connection_succeeded signal.
	if NetworkManager.is_networked():
		_rpc_client_ready_for_spawn.rpc_id(1)
	else:
		NetworkManager.connection_succeeded.connect(_on_joined_ready_for_spawn, CONNECT_ONE_SHOT)
		NetworkManager.join_game(address)

func _on_joined_ready_for_spawn() -> void:
	_rpc_client_ready_for_spawn.rpc_id(1)

func _clear_local_test_characters() -> void:
	RoundManager.clear_tracked_cans()
	# The scene-level ArenaCamera is removed — B-03 is closed, B-58 is closed.
	team_a_prop.queue_free()
	team_a_person.queue_free()
	team_b_prop.queue_free()
	team_b_person.queue_free()
	_local_roster.clear()

## 4.3/B-65: this used to be the ONE trigger for spawning + catching up a
## post-lobby joiner, firing the instant ENet's handshake completed. It is
## now one of THREE (see _on_player_identified, _rpc_client_ready_for_spawn
## below) because that instant is no longer late enough to safely act on:
## the peer's token may not have arrived yet (raced against _rpc_identify,
## a separate message with no ordering guarantee relative to this signal),
## and — for a peer redirected here mid-match out of Lobby.tscn — their own
## Main.tscn may not even be loaded yet. All three call the same idempotent
## _try_late_join, so whichever condition is satisfied LAST is the one that
## actually spawns them.
func _on_player_connected(peer_id: int) -> void:
	if NetworkManager.is_host():
		_try_late_join(peer_id)

## 4.3/B-65: fires once NetworkManager has recorded this peer's token
## (NetworkManager.player_identified) — see _on_player_connected's doc for
## why this is needed as a second trigger rather than trusting player_connected
## alone.
func _on_player_identified(peer_id: int, _token: String) -> void:
	if NetworkManager.is_host():
		_try_late_join(peer_id)

## 4.3/B-65 — client -> host: "my own Main.tscn is loaded and ready to
## receive a spawn." Sent unconditionally from the end of _start_joining(),
## for both a normal --join= (Main.tscn already loaded, so this just
## confirms what was already true) and a peer NetworkManager just redirected
## out of Lobby.tscn mid-match (where it is NOT already true, and skipping
## this ping would race the spawn against a scene still loading). No-op via
## _try_late_join's own guards if the match hasn't started yet — the ordinary
## Lobby-gated flow spawns everyone from _start_hosting()'s own loop and
## never needed a ping at all.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_ready_for_spawn() -> void:
	if NetworkManager.is_host():
		_try_late_join(multiplayer.get_remote_sender_id())

## Shared by all three triggers above. Idempotent both ways: _spawned_peer_ids
## guards against spawning twice, and the missing-token return means a trigger
## that fires before NetworkManager.peer_tokens has this peer's entry simply
## does nothing rather than spawning them into the wrong slot — whichever
## trigger fires once BOTH conditions are true is the one that actually acts.
func _try_late_join(peer_id: int) -> void:
	if _spawned_peer_ids.has(peer_id):
		return
	if not NetworkManager.peer_tokens.has(peer_id):
		return
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

## 2026-07-28, user feedback: "instead of disappearing it should transition to
## an AI... just make it stationary and make a player be able to join back to
## their character." First half landed as a stationary placeholder (frozen —
## nobody's peer_id ever satisfies is_multiplayer_authority() for it, see
## character_base.gd:347's gate). This function now finishes the ask: the
## character is handed to AIController instead of staying frozen, via
## _rpc_convert_to_ai below. Deliberately does NOT free the node or erase
## _spawned_characters/_peer_teams/_peer_is_person directly here — that
## bookkeeping migration is _rpc_convert_to_ai's job (same shape as
## _rpc_reclaim_character's own migration), so every peer updates its local
## dictionaries identically instead of only the host's.
## See _spawn_player for the other half: reclaiming this same character when
## its owner's token reconnects, instead of spawning a fresh one — that path
## now also has to hand control back FROM the AI, see _rpc_reclaim_character.
func _on_player_disconnected(peer_id: int) -> void:
	# Q-2/B-63 (still applies, just from a different cause now): RoundManager's
	# _tracked_cans is a snapshot taken at the last _reregister_tracked_cans()
	# call, not a live view — rebuild it so a Can whose team assignment this
	# disconnect might otherwise leave stale is correctly (re)tracked. Only the
	# host drives round-win logic (same gate RoundManager itself uses
	# throughout).
	if not NetworkManager.is_host():
		return
	_reregister_tracked_cans()
	var character: CharacterBase = _spawned_characters.get(peer_id)
	var index := _index_for_character(character) if character != null else -1
	if index != -1:
		_rpc_convert_to_ai.rpc(index)
		_rpc_show_toast.rpc("A player left the match — an AI has taken over their character")
	else:
		# Should not normally happen (every spawned character has an index —
		# see _build_networked_character) — kept as a fallback so a disconnect
		# never silently does nothing if that assumption is ever wrong.
		_rpc_show_toast.rpc("A player left the match — their character will hold position until they reconnect")

## Finds `character`'s join index by reverse lookup through _index_to_character
## — the only direction that dictionary is normally read (index -> character);
## this is the one caller that needs the other direction, to know which index
## a peer_id about to go stale (disconnect) actually belongs to.
func _index_for_character(character: CharacterBase) -> int:
	for index in _index_to_character:
		if _index_to_character[index] == character:
			return index
	return -1

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
	# 4.3/B-65: a peer_id is only good for one connection's lifetime — a
	# rejoin gets a fresh one from ENet. NetworkManager.peer_tokens is where
	# _rpc_identify recorded the STABLE token this peer_id currently belongs
	# to; every caller of _spawn_player (_start_hosting's loop,
	# _try_late_join) already checked this is populated before getting here.
	var token: String = NetworkManager.peer_tokens.get(peer_id, "")
	if token == "":
		push_warning("main.gd: _spawn_player(%d) called with no registered token; skipping." % peer_id)
		return
	_spawned_peer_ids[peer_id] = true
	# B-21, superseded by 4.3/B-65: was keyed by peer_id, which meant a
	# rejoin (new peer_id, same human) landed in the next free slot instead
	# of the one it already had — see _token_join_index's own doc. Assign
	# once, permanently, per TOKEN instead.
	if not _token_join_index.has(token):
		_token_join_index[token] = _next_join_index
		_next_join_index += 1
	var index: int = _token_join_index[token]
	# 2026-07-28: this index's character may still be standing right where its
	# previous owner left it — _on_player_disconnected no longer frees it (see
	# that function's own doc) specifically so a reconnect can pick the same
	# body back up instead of getting a fresh one at a spawn point.
	# _index_to_character is never erased on disconnect, for this lookup.
	#
	# Keyed by INDEX, not token: MultiplayerSpawner's custom spawn `data`
	# silently truncates to 7 entries once it crosses the network (measured,
	# not assumed — a "token": String key added as an 8th entry vanished on
	# the receiving peer even at 1 character long, ruling out a size limit).
	# index needs no extra key at all — every peer already derives the exact
	# same index from data["team"]/data["is_person"], both already sent (see
	# _build_networked_character).
	var existing_character: CharacterBase = _index_to_character.get(index)
	if existing_character != null and is_instance_valid(existing_character):
		_rpc_reclaim_character.rpc(index, peer_id)
		return
	spawner.spawn(_build_spawn_data(peer_id, index))

## Shared by _spawn_player (a real peer) and _fill_empty_slots_with_placeholders
## (an unfilled team/role slot, given a synthetic negative peer_id nothing
## real can ever match) — the two differ only in WHOSE peer_id ends up
## controlling the resulting character, not in how team/role/position are
## derived from `index`.
func _build_spawn_data(peer_id: int, index: int) -> Dictionary:
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
	#
	# AI takeover: `peer_id < 0` is the existing negative-sentinel convention
	# (see _fill_empty_slots_with_placeholders / _rpc_convert_to_ai) for a slot
	# with no real human behind it. Those get player_id 3/4 instead of 1/2 —
	# p3/p4 are registered in project.godot but deliberately left unbound to
	# any real key (see CharacterBase.player_id's own doc), so an AIController's
	# Input.action_press() on that suffix can never collide with a real human's
	# own p1/p2 keystrokes, even when both are simulated on the same machine
	# (the host, which is who actually runs an AI-driven character's physics —
	# see _build_networked_character). Flagged as a real trap by the
	# networking-lane handoff before any AI was wired into networked play at
	# all; this is that fix.
	var player_id := (index % 2) + (3 if peer_id < 0 else 1)
	return {
		"peer_id": peer_id, "position": spawn_pos, "is_can": is_can,
		"is_person": is_person, "team": team, "team_is_can_side": team_is_can_side,
		"player_id": player_id,
	}

## 2026-07-28, user feedback: "when playing multiplayer, for example only 2
## people is playing, there's only 2 characters. it should have 4... make the
## other 2 stationary for the meantime as it's only a placeholder." A 2v2
## match with fewer than 4 real peers connected used to leave the unfilled
## team's slots with no character at all — _start_hosting only ever spawned
## _spawn_player for peers that actually connected.
##
## Fills every remaining slot (0..MAX_PLAYERS-1) with a negative sentinel
## peer_id (real ENet peer ids are always positive, so it can never collide
## with, or ever be reconnected to by, an actual connection) — the bookkeeping
## key _build_networked_character reads to know "no real human owns this
## one," which it answers by giving the character to the host's own
## AIController instead of a real player's Input (see that function's own
## doc, and _index_to_character's).
##
## Deliberately does NOT touch _token_join_index/_next_join_index: a REAL
## peer connecting later still gets the next free index normally, finds this
## placeholder already sitting in _index_to_character for that index, and
## reclaims it via the exact same _rpc_reclaim_character a reconnecting real
## peer uses (see _spawn_player) — a new player taking an empty slot and a
## dropped player's own slot coming back are the same event to this code.
func _fill_empty_slots_with_placeholders() -> void:
	for index in range(NetworkManager.MAX_PLAYERS):
		var existing_character: CharacterBase = _index_to_character.get(index)
		if existing_character != null and is_instance_valid(existing_character):
			continue
		var sentinel_peer_id := -1 - index
		_spawned_peer_ids[sentinel_peer_id] = true
		spawner.spawn(_build_spawn_data(sentinel_peer_id, index))

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
	var peer_id: int = data["peer_id"]
	# AI takeover: a negative peer_id is the sentinel for "no real human owns
	# this slot" (see _fill_empty_slots_with_placeholders / _rpc_convert_to_ai)
	# — no real ENet connection can ever present one, so it used to mean
	# "frozen forever" (nobody's is_multiplayer_authority() ever true for it).
	# It now means "the HOST's machine runs this one," same authority the host
	# already has for round logic — real authority is the host's own peer_id
	# (always 1), while `peer_id` itself stays the negative sentinel for
	# bookkeeping (the _spawned_characters/_index_to_character keys below,
	# and character.name) so multiple AI slots don't collide on the same
	# dictionary key the way they would if they all shared authority id 1 there
	# too.
	var is_ai := peer_id < 0
	character.set_multiplayer_authority(1 if is_ai else peer_id)
	_peer_teams[peer_id] = data["team"]
	_peer_is_person[peer_id] = data["is_person"]
	_spawned_characters[peer_id] = character
	# 2026-07-28: keyed by INDEX (derived here identically to _spawn_player's
	# own derivation, from data this spawn already carries), not peer_id, and
	# never erased on disconnect (unlike _spawned_characters above) — see
	# _spawn_player's reclaim check and _on_player_disconnected's own doc for
	# why a stale peer_id's body needs to stay findable by something that
	# survives a reconnect.
	var index: int = data["team"] * 2 + (0 if data["is_person"] else 1)
	_index_to_character[index] = character
	if is_ai:
		# Only the host's own local instance of this spawn_function call
		# attaches a driving AIController (add_child, never baked into
		# CharacterBase.tscn — see ai_controller.gd's own class doc): the
		# spawn function runs identically on every peer (that's how
		# MultiplayerSpawner replicates a spawn at all), but only the host is
		# ever this character's multiplayer authority, so only the host's
		# presses through Input.action_press() do anything once
		# _physics_process's own authority gate is reached. Attaching it
		# anywhere else would just press dead, unread Input state on that
		# other peer's machine — harmless, but pointless.
		if NetworkManager.is_host():
			_attach_ai(character)
	elif peer_id == multiplayer.get_unique_id() and character.is_can:
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
	# B-100 — park every character somewhere nobody could possibly overlap
	# BEFORE any of them move to a real spot. Roles swap every round, so two
	# characters routinely trade positions with each other; repositioning
	# them one at a time straight to their new spots otherwise leaves a real
	# window where the second character hasn't vacated a spot the first one
	# just arrived at, and the physics engine depenetrates that overlap with
	# a genuine impulse — confirmed via tools/render_probe.gd's round2 mode,
	# characters ended up flung many units off their real spawn markers,
	# sometimes airborne, sometimes far enough to clear the confinement box
	# or the floor collision entirely. Reported as "cann fell off map again"
	# and the spawn layout looking "completely different" from what the code
	# says it should be.
	# ⚠️ Toggling CollisionShape3D.disabled around the reposition was tried
	# first and did NOT reliably fix it — disable, reposition and re-enable
	# all happen within the same script frame, before any physics step, and
	# Godot's physics server appears to sync only the FINAL state (enabled,
	# new position) rather than replaying the toggle, so the depenetration
	# still fired. This works instead because it is purely geometric: widely
	# separated, per-character-index parking spots can never overlap ANY
	# other character's parking spot or real spawn point, so there is
	# nothing for the physics engine to resolve regardless of when it syncs.
	for i in range(roster.size()):
		(roster[i]["character"] as CharacterBase).position = Vector3(0.0, 500.0 + i * 20.0, 0.0)
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

## 2026-07-28 — user report: "when round ends the can falls thru the world."
## Root cause: unlike every OTHER round transition, the match's FINAL round
## never gets a _reset_world() call afterward (match_won fires instead of
## round_intermission_started, see match_manager.gd::report_round_result),
## so nothing ever clears velocity again. RoundManager.round_active is false
## from here on and character_base.gd's own freeze gate stops it from
## MOVING, but gravity is still applied every physics frame regardless
## (deliberately, so a unit mid-jump still settles) — with no reset ever
## coming, a unit that was airborne right as the match ended just keeps
## falling under gravity for as long as the result screen is up, long
## enough to tunnel through the floor's thin collision shape. This is the
## same root cause as B-93, just on a code path B-93 didn't cover because it
## isn't a round reset at all. Zeroing velocity once, here, is enough —
## nothing moves it again once round_active is permanently false.
func _on_match_won_freeze_physics(_winning_team: int) -> void:
	for character in _all_characters():
		character.velocity = Vector3.ZERO

## Every character currently in play, local-test or networked — the same
## roster _reset_world() already builds, minus the team/role bookkeeping
## nothing here needs.
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
## Single Player never calls this; it resolves by scanning for player_id == 1
## instead, since there is no is_multiplayer_authority() concept there.
##
## AI takeover: is_multiplayer_authority() alone is no longer sufficient on
## the HOST machine specifically — an AI-driven character's authority is also
## the host's own peer_id (see _build_networked_character), so on a host that
## is itself a real player, both the host's own character AND every AI-driven
## one would match. `ai_controller` is only ever non-null on the one process
## that attached it (the host, and only for the character it's actually
## driving — see _attach_ai's call sites), so excluding it is enough to tell
## "mine" from "the host's machine happens to also simulate this one."
func get_local_character() -> CharacterBase:
	for peer_id in _spawned_characters:
		var character: CharacterBase = _spawned_characters[peer_id]
		if is_instance_valid(character) and character.is_multiplayer_authority() and character.ai_controller == null:
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

## Checklist 5.5, later reused for networked AI takeover (see
## _build_networked_character / _rpc_convert_to_ai) — instances an
## AIController and hands it to `character` (CharacterBase.ai_controller —
## see that var's own doc for why this can't just be an @onready node
## reference on the character itself). A plain `Node`, `add_child()`'d rather
## than baked into CharacterBase.tscn, since that scene is shared by every
## spawn path and most characters (every human-controlled one) never have an
## unpiloted unit to drive.
func _attach_ai(character: CharacterBase) -> void:
	var controller := AIController.new()
	character.add_child(controller)
	character.ai_controller = controller

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
	#
	# Solo-host QoL (2026-07-28+): except neither risk exists when there is
	# nobody else in the session — a lone host pausing cannot desync a round
	# nobody else is watching, and cannot stop movement anyone else is
	# depending on. The playtest that surfaced this was run by HOSTING, not
	# Local Match, specifically to exercise the networked code path alone;
	# refusing to actually pause for that is a real cost with no one to
	# protect. See NetworkManager.is_solo_session().
	if NetworkManager.is_networked() and not NetworkManager.is_solo_session():
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
	# (see main_menu.gd's _on_local_pressed()/_on_host_pressed()/_on_join_pressed(),
	# all of which reset before handing off to the lobby) — otherwise a
	# Rematch/new match after using this button would resume this match's score.
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

## Host → all peers: hands `index`'s existing, still-standing character over
## to AI control instead of leaving it frozen — see _on_player_disconnected.
## Same shape as _rpc_reclaim_character below (bookkeeping migration to a
## fresh key, run identically on every peer via call_local), mirrored for the
## opposite direction: human -> AI instead of AI/nobody -> human.
##
## Re-derives a fresh negative-sentinel peer_id (-1 - index) rather than
## reusing the dead peer's own old id — the old id belonged to a connection
## that is gone for good (a reconnect always gets a NEW peer_id from ENet, see
## NetworkManager.local_player_token's doc), so keeping it around as a
## dictionary key would just be a stale id no future event can ever match.
## Matches the sentinel _fill_empty_slots_with_placeholders already uses for
## an unfilled slot — a slot that was never filled and a slot whose owner just
## left are the same state as far as this bookkeeping is concerned.
@rpc("authority", "call_local", "reliable")
func _rpc_convert_to_ai(index: int) -> void:
	var character: CharacterBase = _index_to_character.get(index)
	if character == null or not is_instance_valid(character):
		return
	for old_peer_id in _spawned_characters.keys():
		if _spawned_characters[old_peer_id] == character:
			_spawned_characters.erase(old_peer_id)
			_peer_teams.erase(old_peer_id)
			_peer_is_person.erase(old_peer_id)
			_spawned_peer_ids.erase(old_peer_id)
			break
	var sentinel_peer_id := -1 - index
	character.name = str(sentinel_peer_id)
	character.set_multiplayer_authority(1) # host runs AI-driven physics — see _build_networked_character
	character.player_id = (index % 2) + 3 # AI-safe range — see _build_spawn_data's own doc
	_spawned_characters[sentinel_peer_id] = character
	_peer_teams[sentinel_peer_id] = character.team
	_peer_is_person[sentinel_peer_id] = character.is_person
	_spawned_peer_ids[sentinel_peer_id] = true
	if NetworkManager.is_host() and character.ai_controller == null:
		_attach_ai(character)

## Host → all peers (2026-07-28): hands `index`'s existing, still-standing
## character over to `new_peer_id` instead of spawning a second body for the
## same slot. Runs identically on every peer (call_local, like every other
## bookkeeping RPC here) since _spawned_characters/_peer_teams/_peer_is_person
## are all per-peer local state, not replicated automatically.
##
## Migrates bookkeeping from whichever peer_id key currently points at this
## character to new_peer_id — leaving BOTH keys pointing at the same instance
## would double-count it in _reset_world's roster loop (registers it as a
## tracked Can twice, resets it twice) the very next round transition.
##
## "authority" (host-only sender) because only the host's _spawn_player runs
## the reclaim check at all — the RPC's job is purely to fan the host's
## decision out, not to let some other peer make it.
##
## Also the AI-handoff-back path: `index`'s character may currently be
## AI-driven (see _rpc_convert_to_ai / _fill_empty_slots_with_placeholders) —
## a real peer reclaiming it needs its own ai_controller detached (or it
## fights the human for the same character's Input state) and player_id
## restored to the human 1/2 scheme (or the reclaiming human's real p1/p2
## keystrokes would land on the unbound p3/p4 actions instead — see
## _build_spawn_data's own doc on why AI slots use 3/4 to begin with).
@rpc("authority", "call_local", "reliable")
func _rpc_reclaim_character(index: int, new_peer_id: int) -> void:
	var character: CharacterBase = _index_to_character.get(index)
	if character == null or not is_instance_valid(character):
		return
	for old_peer_id in _spawned_characters.keys():
		if _spawned_characters[old_peer_id] == character and old_peer_id != new_peer_id:
			_spawned_characters.erase(old_peer_id)
			_peer_teams.erase(old_peer_id)
			_peer_is_person.erase(old_peer_id)
			_spawned_peer_ids.erase(old_peer_id)
			break
	if character.ai_controller != null:
		character.ai_controller.queue_free()
		character.ai_controller = null
	character.name = str(new_peer_id)
	character.set_multiplayer_authority(new_peer_id)
	character.player_id = (index % 2) + 1
	_spawned_characters[new_peer_id] = character
	_peer_teams[new_peer_id] = character.team
	_peer_is_person[new_peer_id] = character.is_person
	_spawned_peer_ids[new_peer_id] = true
	if new_peer_id == multiplayer.get_unique_id() and character.is_can:
		# Mirrors _build_networked_character's own DownedFlash wiring — this
		# process never ran that function for this character (it already
		# existed before this peer connected), so nothing wired it up yet.
		_wire_downed_flash.call_deferred(character)
	if NetworkManager.is_host():
		_rpc_show_toast.rpc("A player reconnected to their character")
