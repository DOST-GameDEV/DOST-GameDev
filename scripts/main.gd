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
## Main.tscn, and the player controls TeamAProp (P1 keys) and TeamAPerson
## (P2 keys) — i.e. one full team, Prop + Person, so both Quick Stand and
## Tag/Throw are directly testable locally. TeamBProp/TeamBPerson are
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
@onready var arena_camera: ArenaCamera = $Camera3D

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
## B-04: networked Props previously spawned with `ability = null` — only
## Persons got one. Only quick_stand.tres exists as a real roster resource so
## far (the other five specials have no .tres yet — see B-24/Phase 2 for
## character select), so every networked Prop gets it for now, same as
## Main.tscn already hardcodes for the local flow's TeamAProp. `.duplicate()`
## per PERSON_ACTION_ABILITY doc — cooldown/charge state lives on the
## Resource instance, don't share it across Props.
const PROP_ABILITY: AbilityBase = preload("res://scripts/abilities/resources/quick_stand.tres")
## Local-test roster, in a flat array so round-swap/registration code (below)
## can treat all 4 the same way it treats _spawned_characters for the
## networked flow, rather than hand-writing 4 near-identical blocks.
## Populated once in _ready(); order is [TeamAProp, TeamAPerson, TeamBProp, TeamBPerson].
var _local_roster: Array[CharacterBase] = []
## Cycled through as players connect; only the first two matter until real
## map spawn points exist (GDD's Eskinita/Bayan Plaza bases).
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(0, 1, -2), Vector3(0, 1, 2), Vector3(-3, 1, 0), Vector3(3, 1, 0)
]

var _spawned_peer_ids: Dictionary = {}
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
	spawner.spawn_function = _build_networked_character
	MatchManager.round_started.connect(_on_match_round_started)

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
	_wire_downed_flash(team_a_prop)
	_wire_downed_flash(team_b_prop)
	_register_local_can()
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
	if NetworkManager.host_game() != OK:
		return
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	_spawn_player(multiplayer.get_unique_id()) # host is player 1
	# Rough pass: the match begins as soon as the host starts hosting, rather
	# than waiting for a full 2v2 lobby to fill — matches the "no lobby UI"
	# state of networking so far. Revisit once MainMenu has a real ready-up.
	MatchManager.begin_next_round()

func _start_joining(address: String) -> void:
	_clear_local_test_characters()
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.join_game(address)

func _clear_local_test_characters() -> void:
	RoundManager.clear_tracked_cans()
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

func _on_player_disconnected(peer_id: int) -> void:
	var node := players_root.get_node_or_null(str(peer_id))
	if node:
		arena_camera.remove_target(node)
		node.queue_free()
	_spawned_peer_ids.erase(peer_id)
	_peer_teams.erase(peer_id)
	_peer_is_person.erase(peer_id)
	_spawned_characters.erase(peer_id)

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
	var index := _spawned_peer_ids.size()
	_spawned_peer_ids[peer_id] = true
	var team := index / 2 # 0, 0, 1, 1 for up to MAX_PLAYERS = 4
	var is_person := index % 2 == 0 # first peer of each team pair is the Person
	var spawn_pos: Vector3 = SPAWN_POINTS[index % SPAWN_POINTS.size()]
	var team_is_can_side := (team == 0) == MatchManager.team_a_is_can
	var is_can := team_is_can_side and not is_person
	spawner.spawn({
		"peer_id": peer_id, "position": spawn_pos, "is_can": is_can,
		"is_person": is_person, "team": team, "team_is_can_side": team_is_can_side,
	})

## Runs on every peer (host and clients) when the spawner replicates a spawn.
func _build_networked_character(data: Dictionary) -> Node:
	var character: CharacterBase = CHARACTER_SCENE.instantiate()
	character.name = str(data["peer_id"])
	character.position = data["position"]
	character.is_can = data["is_can"]
	character.is_person = data["is_person"]
	character.team_is_can_side = data["team_is_can_side"]
	character.team = data["team"] # B-09: no team identity on CharacterBase before this
	if data["is_person"]:
		# Session 8: Person's Tag/Throw, replacing the previously-null `ability`
		# for Person (see PersonAction doc). .duplicate() per PERSON_ACTION_ABILITY
		# doc above — don't share cooldown state across the two Persons in a match.
		character.ability = PERSON_ACTION_ABILITY.duplicate()
	else:
		# B-04: Props carry the roster's class ability — see PROP_ABILITY doc.
		character.ability = PROP_ABILITY.duplicate()
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
	# B-03: register every spawned networked character as a camera target at
	# runtime — Main.tscn's `follow_paths` only ever pointed at the local-test
	# nodes, so without this the camera never picked up real network peers.
	arena_camera.add_target(character)
	return character

## Fires on every peer identically (host emits locally, clients receive it via
## MatchManager._sync_round_started — see match_manager.gd) since it's driven
## by fields (team_a_is_can) that are already synced. No RPC needed here: each
## peer just recomputes is_can for every spawned character from that
## character's fixed team, which every peer already knows from spawn data.
func _on_match_round_started(_round_number: int, team_a_is_can: bool) -> void:
	if NetworkManager.is_networked():
		RoundManager.clear_tracked_cans()
		var index := 0
		for peer_id in _spawned_characters.keys():
			var character: CharacterBase = _spawned_characters[peer_id]
			if not is_instance_valid(character):
				continue
			var team: int = _peer_teams.get(peer_id, 0)
			var is_person: bool = _peer_is_person.get(peer_id, false)
			var team_is_can_side := (team == 0) == MatchManager.team_a_is_can
			# Session 8: every character on the team tracks team_is_can_side now,
			# not just the Prop — Person needs it too, to pick Tag vs Throw (see
			# person_action.gd). Only the team's Prop can ever be a Can, though —
			# the Person's own is_can stays false regardless of which side its
			# team is on this round (Session 7: 1 Person + 1 Prop per team, not
			# two Props).
			character.team_is_can_side = team_is_can_side
			character.is_can = team_is_can_side and not is_person
			# B-10: previously only RoundManager's own tracked-Can loop reset
			# anything, so the two Persons and the Slipper-side Prop carried
			# their Downed/Sealed state, dents, speed multiplier, and spent
			# once-per-round charges into the next round, and nobody's position
			# reset at all. Reset + reposition every unit here instead.
			character.reset_for_new_round()
			character.position = SPAWN_POINTS[index % SPAWN_POINTS.size()]
			index += 1
			if character.is_can:
				RoundManager.register_can(character)
	elif not _local_roster.is_empty():
		# Session 9: role-swap for the local flow too — was previously a "known
		# gap" (docs/Handoff.md). Same rule as networked: Team A's
		# Prop/Person side comes straight from team_a_is_can, Team B is the
		# mirror image. Persons never become Cans (team_is_can_side only, same
		# as networked above).
		team_a_prop.team_is_can_side = team_a_is_can
		team_a_prop.is_can = team_a_is_can
		team_a_person.team_is_can_side = team_a_is_can
		team_b_prop.team_is_can_side = not team_a_is_can
		team_b_prop.is_can = not team_a_is_can
		team_b_person.team_is_can_side = not team_a_is_can
		# B-10: same reset+reposition as the networked branch above, for all
		# four local units — see _local_roster doc (order: TeamAProp,
		# TeamAPerson, TeamBProp, TeamBPerson, matching SPAWN_POINTS 1:1).
		for i in range(_local_roster.size()):
			var character := _local_roster[i]
			character.reset_for_new_round()
			character.position = SPAWN_POINTS[i % SPAWN_POINTS.size()]
		_register_local_can()
	RoundManager.start_round()

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
	RoundManager.clear_tracked_cans()
	for peer_id in _spawned_characters:
		var character: CharacterBase = _spawned_characters[peer_id]
		if is_instance_valid(character) and character.is_can:
			RoundManager.register_can(character)

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
