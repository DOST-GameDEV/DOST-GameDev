extends Node3D

## Single-player prototype entry point, now dual-purpose (Session 5):
## - No launch args: unchanged local single-PC/split-keyboard prototype
##   (CanTestCharacter / TsinelasTestCharacter, as before).
## - `--host`: starts a LAN server, removes the local test characters, and
##   spawns a real networked character per connected peer instead.
## - `--join=<address>`: connects to a host at that address, same swap.
##
## This is the fastest way to test real multi-device play right now: run one
## exported/editor instance with `--host`, another with `--join=<host LAN IP>`
## (or `--join=127.0.0.1` for two instances on one PC via
## Debug > Run Multiple Instances). No lobby UI yet — see
## docs/Handoff_Session5.md for what's still missing.
##
## Session 7 correction: a team is 2 players — 1 Person (tags/throws) + 1
## Can/Slipper Prop (carries the roster's class ability) — NOT two
## interchangeable Can/Tsinelas units. See CharacterBase.is_person /
## _spawn_player below. The local single-PC fallback above (no launch args)
## still models the OLD 1v1 direct Can-vs-Tsinelas smoke test and has NOT been
## updated for this — see docs/Handoff_Session7.md known gaps.

@onready var can_test_character: CharacterBase = $CanTestCharacter
@onready var tsinelas_test_character: CharacterBase = $TsinelasTestCharacter
@onready var players_root: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var hud: Hud = $HUDLayer/HUD

const CHARACTER_SCENE: PackedScene = preload("res://scenes/characters/CharacterBase.tscn")
## Session 8 (throw/tag mechanic): every networked Person gets its own Tag/Throw
## ability instance — see _build_networked_character. Loaded once here and
## `.duplicate()`d per character rather than sharing this one Resource, since
## AbilityBase.tick()/is_ready() carry per-instance cooldown state
## (_time_since_use, _used_this_round) on the Resource itself; two Persons (one
## per team) sharing the same instance would incorrectly share a cooldown. Note
## this same trap applies to roster Prop abilities (Quick Stand, etc.) once
## THEIR networked-spawn assignment gets built — today only the local test
## flow's CanTestCharacter has one wired (see Main.tscn), so it hasn't bitten
## anyone yet, but the fix should carry over then too.
const PERSON_ACTION_ABILITY: AbilityBase = preload("res://scripts/abilities/resources/person_action.tres")
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
		# Debug > Run Multiple Instances workflow (see docs/Handoff_Session5.md)
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
		# Local single-PC/split-keyboard prototype flow, unchanged.
		# Testbed for Option B (GDD Section 3) — see round_manager.gd's
		# "Option B testbed" comment for why this is opt-in rather than
		# auto-detected.
		RoundManager.register_can(can_test_character)
		MatchManager.begin_next_round()
		_wire_downed_flash(can_test_character)

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
	can_test_character.queue_free()
	tsinelas_test_character.queue_free()

func _on_player_connected(peer_id: int) -> void:
	if NetworkManager.is_host():
		_spawn_player(peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	var node := players_root.get_node_or_null(str(peer_id))
	if node:
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
	if data["is_person"]:
		# Session 8: Person's Tag/Throw, replacing the previously-null `ability`
		# for Person (see PersonAction doc). .duplicate() per PERSON_ACTION_ABILITY
		# doc above — don't share cooldown state across the two Persons in a match.
		character.ability = PERSON_ACTION_ABILITY.duplicate()
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
## by fields (team_a_is_can) that are already synced. No RPC needed here: each
## peer just recomputes is_can for every spawned character from that
## character's fixed team, which every peer already knows from spawn data.
func _on_match_round_started(_round_number: int, _team_a_is_can: bool) -> void:
	if NetworkManager.is_networked():
		RoundManager.clear_tracked_cans()
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
			if character.is_can:
				RoundManager.register_can(character)
	# Local single-PC flow: register_can(can_test_character) already happened
	# once in _ready() and role-swap isn't wired for that flow (see GDD's
	# single-PC fallback note) — this just (re)starts the round timer.
	RoundManager.start_round()

## Shows/hides the HUD's DownedFlash whenever the given (locally-controlled)
## character enters/exits Downed — but only if it's a Can; Tsinelas/Person
## never flash since the GDD ties this to "your Can got knocked down". Under
## Option A this doubles as the entry point for the dent counter too, since
## both only ever apply to the locally-controlled Can.
func _wire_downed_flash(character: CharacterBase) -> void:
	if not character.is_can:
		return
	character.state_changed.connect(func(new_state: CharacterBase.State) -> void:
		hud.set_downed_flash(new_state == CharacterBase.State.DOWNED)
	)
	if GameLaunch.game_mode == GameLaunch.GameMode.OPTION_A:
		hud.set_dents(character.dents, CharacterBase.MAX_DENTS)
		character.dents_changed.connect(func(new_dents: int) -> void:
			hud.set_dents(new_dents, CharacterBase.MAX_DENTS)
		)
