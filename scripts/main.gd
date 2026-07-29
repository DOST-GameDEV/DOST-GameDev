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
## The "this did not actually freeze anything" caveat, on its own line under the
## title. It used to be appended to `paused_label` itself — fine against a 28px
## Heading, but the card's title is display-sized now and a 40-character string
## at that size either overflows the card or drags it half again as wide for a
## state most sessions never see.
@onready var paused_note_label: Label = %PausedNoteLabel
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
## ---------------------------------------------------------------------------
## THE MULTIPLAYER READY PHASE. Human ask: *"implement a pre-match waiting and
## ready-up system in multiplayer mode, similar to the Press R to Ready feature
## in single player."*
##
## Single Player has had this since 2026-07-28 (`_awaiting_local_ready` above);
## multiplayer went straight from `_start_hosting()` to `begin_next_round()` in
## the same frame, so the first thing every LAN player ever saw was a live round
## they had not agreed to start, spawned wherever the map put them and already
## confined.
##
## ⚠️ IT IS ALSO THE FIX FOR THE PRE-ROUND SLIPPER, AND THAT IS NOT A COINCIDENCE.
## Reported as *"slippers cannot move or be controlled by human players during the
## pre-round phase, they are just spinning around uncontrollably."* Chain:
## `begin_next_round()` -> `_reset_world()` -> `host_grab(attacker)` gives the
## tsinelas to the attacking Person before anyone has touched a key. A CARRIED
## slipper returns true from `Carriable.drives_movement()`, so
## `character_base.gd::_physics_process` hands its whole frame to
## `_step_carried()` and RETURNS before any input is read — the slipper's player
## genuinely cannot move it, by design, and `_step_carried()` was snapping it to
## the animated hand bone's full basis every physics frame, which is the spin.
## With a ready phase the round has not started, `_reset_world()` has not run,
## nothing has been grabbed, and the slipper is LOOSE and drivable exactly like
## every other unit. (The spin itself is fixed independently in `carriable.gd`, so
## a slipper genuinely in hand mid-round does not whirl either.)
##
## HOST-AUTHORITATIVE, like everything else that decides when a round happens.
## Peers declare; the host counts and calls it.
var _awaiting_net_ready: bool = false
## peer_id -> true, host-side only. Cleared when the countdown starts.
var _net_ready_peers: Dictionary = {}
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

## The full spawn transform. POSITION comes from the marker; its yaw is used only
## as a fallback — see _spawn_yaw() for why facing is computed instead.
func _spawn_transform(index: int) -> Transform3D:
	if not _map_spawns.is_empty():
		return _map_spawns[index % _map_spawns.size()]
	return Transform3D(Basis.IDENTITY, SPAWN_POINTS[index % SPAWN_POINTS.size()])

## Which slot each slot must be LOOKING AT. The attacker and its tsinelas face
## the can they are throwing at; the taya faces the attacker it is guarding
## against. The can itself is absent on purpose — it is an object, its facing is
## cosmetic, and it keeps whatever yaw its marker was authored with.
const SLOT_FACES: Dictionary = {
	SLOT_TAYA: SLOT_ATTACKER,
	SLOT_ATTACKER: SLOT_CAN,
	SLOT_TSINELAS: SLOT_CAN,
}

## The yaw a unit in `slot` spawns with — DERIVED from where the thing it cares
## about actually is, not read off the marker.
##
## ⚠️⚠️ THE MARKER'S OWN YAW IS NO LONGER TRUSTED FOR FACING. DO NOT GO BACK. ⚠️⚠️
##
## "the attacker spawns facing away from the can" has been reported across more
## than ten sessions. Every fix so far has re-authored marker rotations, and the
## reason that keeps failing is structural: a hand-authored yaw is a THIRD copy
## of a fact already stated twice (this slot's position, and the can's), it is
## invisible in the editor viewport unless you look down the gizmo, and nothing
## validates it. Measured on Eskinita with tools/net_spawn_probe.gd: Spawn1's
## authored 180 degrees puts the taya **55.7 degrees off** the can it is standing
## next to, and Spawn2's attacker was correct only by the coincidence that the
## marker sits on the +Z axis with an identity basis, so the default -Z facing
## happened to point at the origin. Move that marker sideways on any new map —
## Bayan Plaza is a plaza, not a corridor — and it silently breaks again.
##
## Computing it removes the failure mode instead of fixing this instance of it:
## there is no authored value left to get wrong, on this map or any future one.
##
## ⚠️ YAW ONLY, via atan2 — NOT `look_at()`. `look_at` writes a full basis, so a
## target at a different height tilts the body, and camera_rig.gd's whole
## _apply_upright_pose()/_body_yaw() machinery exists because a body with pitch
## or roll in it puts that tilt straight into the player's eye (its own doc calls
## that "THE INVARIANT", after three separate reports). A Y-rotation can never
## do that. The sign convention matches camera_rig.gd::_body_yaw()'s inverse:
## a body's forward is -basis.z, which for yaw t is (-sin t, 0, -cos t).
func _spawn_yaw(slot: int) -> float:
	var here := _spawn_transform(slot)
	if not SLOT_FACES.has(slot):
		return here.basis.get_euler().y
	var delta := _spawn_transform(int(SLOT_FACES[slot])).origin - here.origin
	delta.y = 0.0
	if delta.length() < 0.01:
		# Degenerate (two slots stacked): keep whatever the marker said rather
		# than snapping to an arbitrary axis.
		return here.basis.get_euler().y
	return atan2(-delta.x, -delta.z)

## Places a character at its slot, facing the way the map says. Kept separate
## from _spawn_point() so the two call sites cannot drift apart on the rotation.
func _place_at_spawn(character: CharacterBase, slot: int) -> void:
	var t := _spawn_transform(slot)
	character.position = t.origin
	# ⚠️ THE WHOLE `rotation`, NOT JUST `.y`. Writing only the yaw component left
	# whatever pitch and roll the body already carried, and a Prop routinely
	# carries plenty: carriable.gd::_step_carried() snaps a CARRIED unit to the
	# hand's full basis every physics frame, CARRY_TILT_DEG (55 degrees) included,
	# and Carriable.reset_for_new_round() — unlike _rpc_set_loose(), which does
	# zero it — never cleared that. So the tsinelas the attacker was holding when
	# the round ended started the next round tilted 55 degrees, which is both
	# visible and, per camera_rig.gd's _apply_upright_pose() note, the class of
	# leftover basis that ends up in a player's eye.
	character.rotation = Vector3(0.0, _spawn_yaw(slot), 0.0)
	# ⚠️⚠️ PUSH THE NEW TRANSFORM TO THE PHYSICS SERVER *NOW*. DO NOT REMOVE.
	#
	# Writing `position` on a PhysicsBody3D updates the SCENE TREE immediately and
	# the physics broadphase only at the next flush. Within one frame, every
	# other body's `move_and_slide()` therefore still collides with this
	# character's PREVIOUS collider position.
	#
	# That is what B-100's "park everyone at y=500 first" was really fighting,
	# and why it could not work: the parking write is invisible to the server for
	# the same reason the placement write is. Roles swap every round, so the two
	# Persons trade marks — measured with tools/jump_probe.gd, the incoming Taya
	# was placed correctly at (2.2, 0.9, -1.5), then on the very next physics step
	# `move_and_slide()` reported three contacts with the OUTGOING Person (normal
	# 0,1,0 — stacked on its head), shoved it 1.60 up to y=2.50, and the frame
	# after that slid it 9.84 units into WallWest. Reported as characters "flung
	# many units off their real spawn markers, sometimes airborne" (B-100) and as
	# weird physics bounces.
	#
	# force_update_transform() flushes this body's transform to the server
	# synchronously, so by the time the next character is placed — and by the time
	# anyone's move_and_slide() runs — the space is genuinely vacated.
	character.begin_spawn_settle()
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
## Single Player does (see ai_controller.gd's own class doc).
## Handing a slot BACK to a reconnecting/new human (_rpc_reclaim_character)
## detaches the AIController and restores the human 1/2 player_id range.
##
## ⚠️ The player_id 3/4 range is now BOOKKEEPING, not a guard. It used to be the
## isolation mechanism — p3/p4 were unbound, so an AI's Input.action_press()
## could not collide with a human's keystrokes on the host machine. Two changes
## retired that: AIController stopped driving `Input` at all (it writes
## `_ai_intent`, see ai_controller.gd), and the 2026-07-29 overhaul collapsed the
## four suffixed action sets into one. Isolation is now `_ai_driven()` plus
## `CharacterBase.input_parked`.
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
	# 4.1: the pause overlay's three buttons are plain Buttons, not ArrowButtons
	# (which carry their own click — see arrow_button.gd), so they are wired
	# individually here. settings_panel.gd plays its own `ui_back` on the way
	# out, which is why the second lambda below is silent.
	settings_button.pressed.connect(func() -> void:
		AudioManager.play("ui_click")
		pause_root.hide()
		settings_panel.show())
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
	# The CHARACTER panel's picks go to the unit the human is actually going to
	# play — the seat they chose (10.5), not always Team A's Person. The other
	# three are deliberately left at -1 and keep the signed-off defaults: the
	# pair at PERSON_MODELS[0]/[1] was chosen specifically to read apart at arena
	# distance (Art_Direction.md), and handing the player's own pick to an
	# opponent too would let someone play a match against a character wearing
	# their exact silhouette.
	#
	# ⚠️ THE PROP PICKS GO ON A PROP AND THE PERSON PICK ON A PERSON. A Prop seat
	# takes BOTH skins for the same reason its networked counterpart does —
	# `is_can` flips every round and it will be each in turn — and since 10.5 a
	# skin also carries that round's ability (`character_roster.gd`), so putting
	# them on the wrong unit would silently cost the player their kit, not just
	# their colour.
	var picked_unit := _local_unit_for_seat(GameLaunch.solo_seat)
	if picked_unit.is_person:
		picked_unit.character_index = GameLaunch.character_index()
	else:
		picked_unit.can_index = GameLaunch.can_index()
		picked_unit.slipper_index = GameLaunch.slipper_index()
	# B-76: Main.tscn no longer hardcodes a Prop ability (see its own node
	# comment) — assign the role-correct one here, same as the networked spawn
	# path. _reset_world() re-picks this every round; this is just the round-1
	# value so there's no null/wrong-ability window before the first
	# begin_next_round() below runs it.
	team_a_prop.ability = _prop_ability_for(team_a_prop).duplicate()
	team_b_prop.ability = _prop_ability_for(team_b_prop).duplicate()
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
	# Checklist 5.5 — Single Player. The human plays the seat they picked in the
	# setup screen (10.5); the other three units on the roster get real AI
	# instead of sitting on unbound input. Attached once, here, not re-attached
	# every round: AIController re-derives its role from
	# is_can/is_person/team_is_can_side on every decide() call, so it stays
	# correct across every role swap without needing to know one happened.
	var human := _local_unit_for_seat(GameLaunch.solo_seat)
	_give_human_player_one(human)
	# ⚠️ EVERY UNIT GETS A CONTROLLER, INCLUDING THE HUMAN'S — the human's is
	# created DISABLED, which is a no-op for control and closes the one asymmetry
	# this file used to carry.
	#
	# Reported as *"only one AI person works at a time."* Both AI Persons do in
	# fact run (measured with tools/settle_probe.tscn: 35.8 m and 21.8 m of ground
	# covered over a 30 s run), so the report is not about the bots that exist. It
	# is about the unit that has NO bot: the seat the human took. The moment the
	# player looks away from it, or hands the camera to another unit with the debug
	# switcher, that Person simply stands still for the rest of the round while the
	# other one plays on. From the outside that is exactly "only one of them works",
	# and it was true.
	#
	# A disabled AIController changes nothing while the human is driving —
	# `is_ai_driven()` is `ai_controller != null AND is_enabled()`, so input still
	# comes from the keyboard — and it means control handoff is now symmetric in
	# both directions. `debug_player_switcher.gd::_apply_slots()` already re-enables
	# every unclaimed unit's controller; its own doc calls this out as "the one
	# asymmetry left and it is pre-existing", and tools/input_probe.gd measured the
	# consequence (2 units answering one keypress, 3 after two Tabs).
	for character in _local_roster:
		_attach_ai(character, character != human)
	# Item 13: no authority concept in local test, unlike networked play,
	# where each rig can activate itself from is_multiplayer_authority(). One
	# rig has to be picked explicitly.
	#
	# Seat 0 (Team A's Person) is the default, so a fresh Single Player still
	# drops you into a Person. This used to be TeamAProp, which meant the first
	# thing anyone saw on launch was a third-person shot of a tin can — correct
	# per the GDD (a team is 1 Person + 1 Prop, and the Prop really is the Can)
	# but a poor read as the default. Per the standing directive (§0.1) a Person
	# is ALWAYS first-person, so a Person seat gives an FPP view: you see the
	# arena and your own shadow, not your body. A Prop seat gives TPP; the rig
	# decides that from is_person itself, so nothing here has to.
	# ⚠️ The debug switcher's DEFAULT_P1_UNIT is still "TeamAPerson" and re-applies
	# slot defaults when the DebugBar registers, so opening the debug bar in a
	# session where the player chose another seat snaps p1 back to Team A's
	# Person. Debug-only path, left alone deliberately: that file is the harness,
	# not the game, and 5.5 removes the overlay from the shipping build anyway.
	var default_rig := human.get_node("CameraRig") as CameraRig
	default_rig.set_active(true)
	default_rig.set_aim_source(CameraRig.AimSource.MOUSE)
	# 2026-07-28: begin_next_round() is deliberately NOT called here any more —
	# see _awaiting_local_ready's own doc. Everyone is already spawned at their
	# role position, but the round (and confinement, which is gated on
	# RoundManager.round_active) doesn't start until the player readies up.
	_awaiting_local_ready = true
	hud.show_ready_prompt(true)

## Single Player's seat choice, resolved to one of Main.tscn's four hand-placed
## units. The seat numbering is the networked one, unchanged — `team = seat / 2`,
## and the even seat of each pair is the Person — so the two flows cannot mean
## different things by "Team B's Prop". Falls back to Team A's Person, the
## historical default, rather than erroring on a seat that cannot exist.
func _local_unit_for_seat(seat: int) -> CharacterBase:
	match seat:
		1: return team_a_prop
		2: return team_b_person
		3: return team_b_prop
		_: return team_a_person

## ⚠️ WITHOUT THIS, CHOOSING ANY SEAT BUT TEAM A'S PERSON GIVES YOU A CHARACTER
## YOU CANNOT MOVE. Main.tscn assigns player_id 1/2/3/4 to its four units, and
## only 1 (WASD) and 2 (arrows) are bound to real keys — 3 and 4 are registered
## in project.godot and deliberately left unbound so an AIController's
## Input.action_press() can never collide with a human's own keystrokes (see
## CharacterBase.player_id, and _build_spawn_data's own doc). A human dropped
## into TeamBPerson would therefore be reading action suffixes nothing presses.
##
## Swapped rather than reassigned: whichever unit was holding player_id 1 takes
## the human's old id, so all four ids stay unique and the two unbound ones stay
## in AI hands.
##
## ⚠️ SINGLE PLAYER ONLY, AND THAT IS WHY B-130 DOES NOT COVER IT. B-130 fixed
## the same class of bug on the networked path by making `_action()` ignore
## `player_id` entirely and read p1 — but its guard opens with
## `NetworkManager.is_networked()`, which is false here. Single Player is the one
## flow where `player_id` still genuinely selects an input column (it is a
## split-keyboard concept and this is the split-keyboard harness), so the swap is
## still required. Do not "simplify" this away by pointing at B-130.
func _give_human_player_one(human: CharacterBase) -> void:
	if human.player_id == 1:
		return
	for character in _local_roster:
		if character.player_id == 1:
			character.player_id = human.player_id
			break
	human.player_id = 1

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
	if _counting_down or not event.is_action_pressed("ready_up"):
		return
	if _awaiting_local_ready:
		get_viewport().set_input_as_handled()
		# 7.7 — a body-language read on the ready press. Purely visual: the
		# countdown and the round start are unchanged below, this just means the
		# OTHER players can see it happen in the world instead of only on a HUD.
		# Guarded because the local roster is empty on any non-local path.
		for character in _local_roster:
			if is_instance_valid(character) and character.is_person:
				character.play_visual_action("ready")
		_run_ready_countdown()
	elif _awaiting_net_ready:
		get_viewport().set_input_as_handled()
		# Idempotent on the host's side (a Dictionary key written twice is one
		# key), so mashing R cannot ready you twice or start the countdown early.
		_rpc_declare_ready.rpc_id(1)

## ---------------------------------------------------------------------------
## Networked ready phase. Every function below is a no-op outside it.
## ---------------------------------------------------------------------------

## HOST ONLY. Opens the phase and tells every peer, itself included.
func _enter_net_ready_phase() -> void:
	if not NetworkManager.is_host():
		return
	_net_ready_peers.clear()
	_rpc_ready_phase.rpc(true, 0, _expected_ready_count())

## How many READY presses the host is waiting for: one per connected human peer.
##
## ⚠️ COUNTS PEERS, NOT CHARACTERS, and that is the whole reason a lone host can
## start at all. A 2v2 always has four characters — `_fill_empty_slots_with_
## placeholders()` guarantees it — but the unfilled ones are AI and an AI cannot
## press R. Counting characters would leave a solo host waiting forever for three
## bots to agree.
##
## Floored at 1 so a host whose peer list has not populated yet still needs its
## own press rather than starting instantly on an empty count.
func _expected_ready_count() -> int:
	return maxi(1, NetworkManager.connected_peer_ids.size())

## Any peer -> host: "I am ready." `call_remote`, because the host's own press
## routes here through `rpc_id(1)` on itself... which Godot delivers locally with
## a sender id of 0. Resolved below rather than by adding a second code path.
@rpc("any_peer", "call_local", "reliable")
func _rpc_declare_ready() -> void:
	if not NetworkManager.is_host():
		return
	if not _awaiting_net_ready:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id() # our own press, delivered locally
	_net_ready_peers[sender] = true
	var ready_count: int = _net_ready_peers.size()
	var expected := _expected_ready_count()
	_rpc_ready_phase.rpc(true, ready_count, expected)
	if ready_count >= expected:
		_rpc_begin_ready_countdown.rpc()

## Host -> everyone. `active` false closes the phase without starting anything,
## which is what a late joiner arriving mid-MATCH is told.
@rpc("authority", "call_local", "reliable")
func _rpc_ready_phase(active: bool, ready_count: int, expected: int) -> void:
	_awaiting_net_ready = active
	if not active:
		hud.show_ready_prompt(false)
		return
	# 7.7's body-language read, mirrored to the networked path: everyone can see
	# who has readied in the world, not only on their own HUD.
	if ready_count > 0:
		for character in _all_characters():
			if character.is_person:
				character.play_visual_action("ready")
	hud.show_ready_prompt(true,
		"Walk around freely.  %d / %d ready  ·  press [R]" % [ready_count, expected])

## Host -> everyone: everybody is in, run the 3 · 2 · 1 · GO. Shared with Single
## Player deliberately — one countdown, one place it can be restyled or retimed.
@rpc("authority", "call_local", "reliable")
func _rpc_begin_ready_countdown() -> void:
	if _counting_down:
		return
	_awaiting_net_ready = false
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
	_awaiting_net_ready = false
	_counting_down = false
	# `begin_next_round()` is host-gated inside MatchManager, so every peer runs
	# this same countdown for the visuals and only the host's call actually starts
	# the round — which then reaches everyone through `_sync_round_started`. That
	# is why the countdown is broadcast rather than run on the host and synced at
	# the end: a client that only learns about the round when it begins gets no
	# 3 · 2 · 1 at all.
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
	# ⚠️ NOT begin_next_round() ANY MORE — see _awaiting_net_ready's own doc.
	# The round starts when the players say so, not when the scene finishes
	# loading. Until then RoundManager.round_active is false and
	# MatchManager.round_number is still 0, which is precisely the pair
	# `character_base.gd`'s freeze gate reads as "waiting to ready up, should be
	# able to walk around" rather than "between rounds, should not."
	_enter_net_ready_phase()

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
## and — for a peer redirected here mid-match out of MatchSetup.tscn — their own
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
## out of MatchSetup.tscn mid-match (where it is NOT already true, and skipping
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
	# A peer arriving DURING the ready phase joins the vote rather than watching
	# it: broadcast rather than rpc_id, because `_expected_ready_count()` just went
	# up and everybody's "2 / 3 ready" line is now wrong. A peer arriving after the
	# match is under way is told the phase is closed, so its R press does nothing
	# instead of silently asking the host to start a round already in progress.
	if _awaiting_net_ready:
		_rpc_ready_phase.rpc(true, _net_ready_peers.size(), _expected_ready_count())
	else:
		_rpc_ready_phase.rpc_id(peer_id, false, 0, 0)

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
	# ⚠️ A PEER THAT LEAVES MID-VOTE MUST NOT DEADLOCK THE READY PHASE. Without
	# this, `_expected_ready_count()` drops by one while `_net_ready_peers` keeps
	# the departed peer's tick, so the counter reads "3 / 2 ready" and the equality
	# check that starts the countdown has already been passed and will not be
	# re-evaluated. Everyone waits forever for somebody who has gone home.
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
		_rpc_show_toast.rpc("A player left — a kalaro has taken over their character")
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
	var index := _claim_join_index(token)
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

## Which seat (join index 0..3, and therefore which team and role) this token
## plays. Assigned once and permanently per TOKEN — B-21, superseded by
## 4.3/B-65: keyed by peer_id it used to mean a rejoin (new peer_id, same human)
## landed in the next free slot instead of the one it already had.
##
## THE SEAT NOW COMES FROM THE SETUP SCREEN FIRST (10.5). `GameLaunch.seat_tokens`
## is what `match_setup.gd` broadcast to every peer with the go signal, keyed by
## the same stable token — so a player who clicked "TEAM B · PROP" gets Team B's
## Prop, instead of whatever connection order happened to hand them. It is a
## LOOKUP, not a rule change: the seat still means exactly what the join index
## always meant (`team = seat / 2`, `is_person = seat % 2 == 0`), which is why
## nothing downstream of here needed touching.
##
## Connection order survives as the fallback and is not dead code — it is the
## only thing that seats a peer which never passed through a setup screen at
## all: a `--host`/`--join=` command-line run (still the fastest way to test,
## see docs/Handoff.md), and a late joiner arriving mid-match, who by definition
## was not in the lobby when seats were handed out. A requested seat that is
## somehow already occupied falls back the same way rather than evicting anyone
## — the lobby already refereed exclusivity (`match_setup.gd::_claim_seat`), so
## reaching that branch means the two sources disagree, and the running match
## wins.
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

## Lowest seat nobody holds. Falls back to 0 rather than -1 if all four are
## somehow taken: a fifth peer cannot connect (ENet is created with
## MAX_PLAYERS = 4), so this is a guard against an impossible state, and
## doubling up on seat 0 is a far better failure than indexing out of bounds.
func _first_free_seat() -> int:
	for seat in range(NetworkManager.MAX_PLAYERS):
		if not _seat_is_taken(seat):
			return seat
	return 0

## The seat a character sits in, from the two facts every code path here already
## has. Same derivation `_build_spawn_data` and `match_setup.gd` use, written
## once so the three cannot drift.
static func _seat_of(team: int, is_person: bool) -> int:
	return team * 2 + (0 if is_person else 1)

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
	# ⚠️ B-130, AND THE HISTORY IS THE POINT — DO NOT "RESTORE" INPUT MEANING HERE.
	#
	# B-30 set this because CharacterBase.player_id was never assigned on a
	# networked spawn: every networked character kept the scene default of 1 and
	# read *_p1 actions. B-30's own note called that "harmless by accident (one
	# human per LAN machine binds p1 and controls whichever single character is
	# theirs)" and changed it to the index-based split below so the Settings
	# panel's P2 rebind column would work in networked play.
	#
	# That accident was load-bearing and the trade was a bad one. Each LAN peer is
	# a separate machine with its own keyboard, so the peer dealt an odd index got
	# player_id 2 — arrow keys — and pressing WASD did nothing. `grab_p2` carried
	# no mouse binding at all, so that player could not grab either. Reported
	# 2026-07-29 as "In lan multiplayer we cant move any character". The P2 rebind
	# column it was paying for had itself been removed from the panel on
	# 2026-07-28, so by then it bought nothing.
	#
	# Both ends are settled now: the input overhaul collapsed *_p1..*_p4 into one
	# unsuffixed action set, so this value no longer selects any input at all. It
	# is kept as the match-slot identity — shipped in the spawn payload, read by
	# you_card.gd to find the local character — and the 3/4 range still marks an
	# AI-held slot for bookkeeping (see _attach_ai's doc for why that is no longer
	# an isolation mechanism either).
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
## Deliberately does NOT touch _token_join_index: a REAL
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
## 3.3: the pick decides it now. `character` already carries both skin indices —
## they are replicated onto it at spawn (see `_build_networked_character`) — and
## a skin carries its kit (`character_roster.gd`'s `ability` field), so this
## needs no extra dictionary and nothing extra on the wire.
##
## The constants below stay as the fallback and are still reachable: an AI slot
## has no picks, and neither does a `--host`/`--join=` command-line session that
## never passed through the setup screen.
func _prop_ability_for(character: CharacterBase) -> AbilityBase:
	var path := CharacterRoster.ability_path_at(
		character.can_index, character.slipper_index, character.is_can)
	if path != "":
		var picked := load(path) as AbilityBase
		if picked != null:
			return picked
		push_warning("main.gd: a roster skin names a missing ability '%s'; using the default." % path)
	if character.is_can:
		return CAN_ABILITY
	return TSINELAS_ABILITY_TEAM_A if character.team == 0 else TSINELAS_ABILITY_TEAM_B

## Runs on every peer (host and clients) when the spawner replicates a spawn.
func _build_networked_character(data: Dictionary) -> Node:
	var character: CharacterBase = CHARACTER_SCENE.instantiate()
	character.name = str(data["peer_id"])
	character.position = data["position"]
	character.spawn_position = data["position"] # B-15/B-35: where KillPlane sends it back to
	character.is_can = data["is_can"]
	character.is_person = data["is_person"]
	character.team_is_can_side = data["team_is_can_side"]
	# 2026-07-29 — this function set POSITION and nothing whatsoever about
	# rotation, so every networked character entered its first round on the
	# scene default (identity, i.e. facing -Z) no matter what its spawn marker
	# said. It has looked correct on Eskinita purely because the attacker's
	# marker sits on the +Z axis, where -Z happens to point at the can; the taya
	# has been facing 55 degrees wrong since networked play existed, and any map
	# whose attacker slot is not on that axis would put the attacker's back to
	# the can on round 1. This is the half of the spawn bug that
	# tools/spawn_probe.gd could never see: it drives _start_local_test(), which
	# goes through _place_at_spawn() for all four units and so was always right.
	#
	# Derived here rather than carried in `data`: MultiplayerSpawner's custom
	# spawn data silently truncates past 7 entries once it crosses the network
	# (measured — see _spawn_player), `data` is already at exactly 7, and an 8th
	# "yaw" key would vanish on the receiving peer with no error at all. Every
	# input _spawn_yaw() needs is already present and every peer derives the same
	# value from it, exactly as `index` is derived rather than sent.
	character.rotation = Vector3(0.0, _spawn_yaw(
		_role_slot(data["is_can"], data["is_person"], data["team_is_can_side"])), 0.0)
	character.team = data["team"] # B-09: no team identity on CharacterBase before this
	character.player_id = data["player_id"] # B-30: was never assigned, stuck at the scene default of 1
	# Which roster character this peer picked on the CHARACTER screen.
	#
	# Looked up from NetworkManager rather than carried in `data` for the reason
	# `character.rotation` above is derived rather than sent: this dictionary is
	# already at MultiplayerSpawner's silent 7-entry ceiling and an 8th key would
	# vanish on the receiving peer with no error at all.
	#
	# ⚠️ ONLY THE HOST'S ANSWER IS RIGHT, AND ONLY THE HOST NEEDS IT TO BE. This
	# spawn function runs on every peer, but `peer_characters` is host-only — a
	# client asking it about somebody else gets -1. That is correct and not a bug
	# to route around: `character_index` is a REPLICATED property with
	# `spawn = true` (CharacterBase.tscn), so the host's value arrives with the
	# character itself and overwrites the client's -1 before it is ever drawn.
	# Trying to make every peer compute this independently would need every peer
	# to know every other peer's pick, which is exactly the state the
	# synchronizer already carries.
	# Person picks and Prop picks are set on the unit they belong to. A Prop takes
	# BOTH lata and tsinelas skins because `is_can` flips every round and it will
	# be each of them in turn — see CharacterBase.can_index.
	var picks := NetworkManager.picks_for(int(data["peer_id"]))
	if character.is_person:
		character.character_index = int(picks.get("character", -1))
	else:
		character.can_index = int(picks.get("can", -1))
		character.slipper_index = int(picks.get("slipper", -1))
	if data["is_person"]:
		# Session 8: Person's Tag/Throw, replacing the previously-null `ability`
		# for Person (see PersonAction doc). .duplicate() per PERSON_ACTION_ABILITY
		# doc above — don't share cooldown state across the two Persons in a match.
		character.ability = PERSON_ACTION_ABILITY.duplicate()
	else:
		# B-76: the class ability depends on which side of the round this Prop
		# is playing — see _prop_ability_for() doc.
		character.ability = _prop_ability_for(character).duplicate()
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
	# ⚠️ B-133 — THIS LINE IS IMPLICATED IN A MEASURED LATE-JOIN REPLICATION
	# FAULT. DO NOT "TIDY" IT WITHOUT READING docs/Handoff.md B-133 FIRST.
	#
	# Deferring this assignment past the spawn's replication flush takes a real
	# four-peer session's discarded sync packets from 12,731 / 25,218 (peers 3 and
	# 4) to 0 / 0 — but it also races `_rpc_reclaim_character`, which is what
	# actually hands a slot to a joining human, and cost this peer its own
	# character in tools/net_spawn_probe.tscn. So the fix is NOT applied here yet
	# and this line is deliberately unchanged. Measurements, the three candidate
	# fixes tried, and what each one did are in Handoff.md B-133; the harness is
	# tools/hit_probe.tscn.
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
	var index: int = _seat_of(data["team"], data["is_person"])
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
			character.ability = _prop_ability_for(character).duplicate()
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
## `enabled` false attaches a controller that is present but silent — the unit
## still reads the keyboard (`CharacterBase.is_ai_driven()` requires BOTH a
## controller and an enabled one), and anything that later wants the AI to take
## over just calls `set_enabled(true)` instead of having to construct one. Used
## for the human's own Single Player seat; see _start_local_test's own note.
func _attach_ai(character: CharacterBase, enabled: bool = true) -> void:
	var controller := AIController.new()
	character.add_child(controller)
	character.ai_controller = controller
	if not enabled:
		controller.set_enabled(false)

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
	var overlay_only := NetworkManager.is_networked() and not NetworkManager.is_solo_session()
	paused_note_label.visible = overlay_only
	if not overlay_only:
		get_tree().paused = pause_root.visible

func _on_resume_pressed() -> void:
	AudioManager.play("ui_back") # 4.1
	pause_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false

func _on_return_to_menu_pressed() -> void:
	AudioManager.play("ui_back") # 4.1
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
	# MultiplayerSetup, not the title screen: it owns the status message and it
	# is where this player would rejoin or re-host from.
	get_tree().change_scene_to_file("res://scenes/ui/MultiplayerSetup.tscn")

## Q-1/B-62: a Join to a dead/unreachable address previously left the player on
## a black Main.tscn forever — the same soft-lock as a mid-match host quit,
## just triggered before anyone ever connected. Same teardown, different message.
func _on_connection_failed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MatchManager.reset()
	RoundManager.reset()
	GameLaunch.reset()
	GameLaunch.pending_status_message = "Could not reach that host."
	get_tree().change_scene_to_file("res://scenes/ui/MultiplayerSetup.tscn")

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
	# The departing peer's own machine is gone, so this is really about the OTHER
	# peers: a character that just became AI must stop being anybody's camera.
	# See _refresh_rig_ownership.
	_refresh_rig_ownership(character)

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
	# ⚠️⚠️ WITHOUT THIS A RECONNECTING PLAYER GETS NO CAMERA AT ALL.
	#
	# `camera_rig.gd` decides whether it is the one being looked through in its
	# OWN `_ready()`, from `is_multiplayer_authority()` — which is evaluated once,
	# at spawn, and is the only place that ever calls `set_active()` on the
	# networked path. This function is the one place authority CHANGES after
	# spawn, and it was changing it silently: the rejoining peer took ownership of
	# a character whose rig had been told, minutes earlier, that it belonged to
	# somebody else. No camera became current, no mouse aim was armed, and the
	# player was left looking at whatever the engine fell back to while their
	# character walked around off screen.
	#
	# The half of the human's ask this completes is "ensure players can seamlessly
	# rejoin the match later" — the bookkeeping half has worked since 2026-07-28;
	# it was the view that never came back.
	_refresh_rig_ownership(character)
	if new_peer_id == multiplayer.get_unique_id() and character.is_can:
		# Mirrors _build_networked_character's own DownedFlash wiring — this
		# process never ran that function for this character (it already
		# existed before this peer connected), so nothing wired it up yet.
		_wire_downed_flash.call_deferred(character)
	if NetworkManager.is_host():
		_rpc_show_toast.rpc("A player reconnected to their character")

## Re-asks "is this character mine?" and points its camera rig accordingly.
##
## Runs on EVERY peer, because the answer differs per peer and every one of them
## has to reach its own. The test is character-for-character identical to
## `camera_rig.gd::_ready()`'s — deliberately, since the two must never disagree
## about who is looking through what:
##
##   authority is this machine's peer   AND   no AIController is driving it
##
## The second clause is what keeps a HOST that is also a player from claiming
## every AI-driven character as well: an AI slot's authority is the host's own
## peer id (see _build_networked_character), so the first clause alone is true for
## all of them. `ai_controller` is only ever non-null on the process that attached
## it, which is only ever the host, and only for the ones it actually drives.
func _refresh_rig_ownership(character: CharacterBase) -> void:
	var rig := character.get_node_or_null("CameraRig") as CameraRig
	if rig == null:
		return
	var is_mine := character.is_multiplayer_authority() and character.ai_controller == null
	rig.set_active(is_mine)
	rig.set_aim_source(CameraRig.AimSource.MOUSE if is_mine else CameraRig.AimSource.MOVEMENT)
	if is_mine:
		# The pause overlay and the result screen deliberately release the cursor;
		# arriving back into a live match with a visible cursor and no mouse-look
		# is the same "you can walk but you cannot look" symptom B-72 fixed for
		# alt-tab, just reached by a different route.
		if not pause_root.visible and not match_result.visible and not settings_panel.visible:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
