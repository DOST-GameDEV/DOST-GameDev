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

## ⚠️ FOUR PERSONS, INDEXED BY SEAT. Was `TeamAProp / TeamAPerson / TeamBProp /
## TeamBPerson` — two teams of one Person and one playable Prop. The props are
## props now (`scripts/objects/`), so all four seats are people and the only thing
## that distinguishes them in a round is which one `MatchManager.defender_slot`
## points at.
@onready var players: Array[CharacterBase] = [$Player1, $Player2, $Player3, $Player4]
## The lata and the three slippers are WORLD objects, not seats. They take no
## place in the lobby, claim no peer and are never AI-driven — which is the whole
## practical difference between this build and the one it replaced.
@onready var lata: Lata = $Lata
@onready var slippers: Array[Slipper] = [$Slipper1, $Slipper2, $Slipper3]
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
## ⚠️⚠️ A PERSON CARRIES NO `ability` AT ALL SINCE 2026-07-30, AND THAT IS THE TAG BEING
## GONE RATHER THAN AN OVERSIGHT.
##
## `PERSON_ACTION_ABILITY` used to be preloaded here and duplicated onto every Person on
## both spawn paths. The ability it pointed at was the Tag — the defender's round-winning
## tap-out — and the whole of it was deleted with `person_action.gd` and its `.tres`
## (`Design.md` §1, `hitbox.gd`'s round-win branch).
##
## What a Person presses `special_ability` for now is decided entirely by what is in
## their hands, and neither half is an `AbilityBase`:
##   * holding a tsinelas -> the charged throw, `carrier.gd`
##   * empty-handed       -> the charged bump meter, `character_base.gd`
##
## `character_base.gd` guards every ability call with `if ability:`, so a null slot is
## already a supported state — it was the Person's own state before Session 8 built the
## Tag. The duplication rule below still governs every PROP ability and is unchanged.
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
## `.duplicate()` at every call site — an AbilityBase carries per-instance cooldown
## state on the Resource itself, so two Props sharing one instance share a cooldown.
## ---------------------------------------------------------------------------
## ⚠️⚠️ THESE THREE ARE TYPED `Resource`, NOT `AbilityBase`, AND THAT IS NOT SLOPPINESS —
## IT IS WHAT MAKES THIS FILE PASS THE PROJECT'S ONE CHEAP GATE.
##
## `docs/README.md` calls grepping `--check-only` output for `Parse Error` *"the one cheap
## real gate"*. Annotated as `AbilityBase`, this file did not pass it:
##
##   Parse Error: Cannot assign a value of type Resource to constant
##   "TSINELAS_ABILITY_TEAM_A" with specified type AbilityBase.   (main.gd:107, :108)
##
## A `.tres` records `type="Resource" script_class="BakyaBash"`, so the static analyser
## has to go through the global class cache to learn that a `BakyaBash` IS an
## `AbilityBase`. When it cannot, `preload()` comes back as a bare `Resource` and a
## const's declared type is checked at parse time, with no runtime cast available to
## rescue it.
##
## ⚠️ AND IT WAS INCONSISTENT, WHICH IS WHY IT SURVIVED. `CAN_ABILITY` on this same
## pattern resolved fine while the two below did not, on the same run — so the file looked
## like it had two broken lines rather than one unreliable idiom, and the gate was
## quietly useless for the largest file in the project instead of obviously so.
##
## Measured 2026-07-31: warm class cache → exactly these 2 Parse Errors; emptied cache →
## 345. So the cache state changes HOW MUCH resolves, and no cache state makes the const
## annotation dependable. The type is asserted at the one place it is actually consumed
## (`_prop_ability_for`) instead, where a cast is available and a mismatch would be a
## null rather than a file that will not parse.
## ⚠️ `CAN_ABILITY`, `TSINELAS_ABILITY_TEAM_A` AND `TSINELAS_ABILITY_TEAM_B` WERE
## DELETED HERE, along with the `.tres` files they preloaded. They named the
## fallback kit a Prop carried when its roster skin did not specify one. There are
## no abilities and no Props (`Design.md` §Removed).
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
	_publish_playable_extent(instance)

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
## ---------------------------------------------------------------------------
## ⚠️⚠️ SPAWNS ARE COMPUTED FROM THE BOX, NOT READ FROM MAP MARKERS. That is a
## correctness change, not a convenience one.
##
## The GDD states the rule as a GEOMETRIC relationship — *"positions reset to the
## Safe Zone"*, and the Safe Zone is defined as "outside the Defender's box". The
## map's `SpawnPoints/Spawn0..3` markers were authored for the 2v2 layout (can on
## the base circle, taya beside it, attacker on the 6.0 throwing line, tsinelas
## next to the attacker) and nothing validates them against the box. A marker that
## drifts half a metre inside `CONFINEMENT_RADIUS` would spawn an Attacker
## VULNERABLE on frame one, and it would read as a rules bug rather than a map one.
##
## Deriving them from `CharacterBase.confinement_radius` means the two cannot
## disagree, and retuning the box moves the spawns with it. The markers are still
## loaded into `_map_spawns` because the map tooling reads them.
##
## ⚠️ THE MARKER'S OWN YAW WAS ALREADY NOT TRUSTED FOR FACING AND STILL IS NOT.
## "the attacker spawns facing away from the can" was reported across more than ten
## sessions, and every fix that re-authored marker rotations failed for the same
## structural reason: an authored yaw is a THIRD copy of a fact already stated
## twice, it is invisible in the editor viewport unless you look down the gizmo,
## and nothing validates it. Measured with `tools/net_spawn_probe.gd`, Spawn1's
## authored 180° put the taya **55.7° off** the can it was standing next to.
##
## ⚠️ YAW ONLY, via `atan2` — NOT `look_at()`. `look_at` writes a full basis, so a
## target at a different height tilts the body, and `camera_rig.gd` puts that tilt
## straight into the player's eye (its own doc calls that "THE INVARIANT", after
## three separate reports). A Y-rotation cannot. The sign convention matches
## `camera_rig.gd::_body_yaw()`'s inverse: forward is `-basis.z`, which for yaw t
## is `(-sin t, 0, -cos t)`.
## ---------------------------------------------------------------------------

## How far outside the box edge the Attackers start. Far enough to be
## unambiguously in the Safe Zone, close enough to be in throwing range.
const SAFE_ZONE_MARGIN: float = 2.0
## Where the Defender starts inside their own box — not on top of the lata, but
## already between it and somebody.
const DEFENDER_START_OFFSET: float = 2.5
## Height a spawn starts from before `_seat_on_floor()` does the real work.
const SPAWN_START_HEIGHT: float = 1.0

## How far apart the three Attackers stand on their shared line. Two body widths:
## close enough to read as one group, far enough that nobody spawns inside anybody
## and `SPAWN_SETTLE_FRAMES` has nothing to untangle.
const ATTACKER_SPAWN_SPACING: float = 1.8

## `role_index` 0 is the Defender; 1..3 are the three Attackers.
##
## ⚠️⚠️ THE THREE ATTACKERS SHARE ONE SIDE NOW, AND THE TAYA STANDS BEHIND THE CAN
## FACING THEM. Changed 2026-08-01 on human instruction: *"Attackers should spawn in
## one safe zone next to each others"* and *"The Defender should spawn behind the
## can in the danger zone, where in front they see the attackers"*.
##
## They used to be spread on a ring at 120° — deliberately, so *"no mark is handed a
## better angle on the lata than another"*. That is a fair layout and a bad opening:
## the taya was surrounded on frame one, the three attackers could not see each
## other, and the round began with the defence already beaten on bearing rather than
## on play. Symmetry between the three attackers is preserved by putting them on ONE
## line at equal spacing — they still get identical angles as a group.
##
## ⚠️ THE SIDE IS +Z AND THE TAYA IS AT -Z, so the taya's `_role_spawn_yaw()` — which
## already points everyone at the lata — now also points them at the attackers,
## because the attackers are directly beyond it. One rule, two jobs, nothing extra
## to keep in step.


## ⚠️⚠️ TELLS THE REST OF THE GAME WHERE THIS MAP'S WALLS ARE. Read off the map's
## own `Bounds` colliders at load, so a map that moves its walls moves this with
## them and nothing has to be kept in step by hand.
##
## WHY IT EXISTS: `ai_controller` sends attackers to a square ring at
## `confinement_radius + THROW_STANDOFF` and had no way to know a map has edges. On
## 2026-08-01 the box grew until that ring landed past Eskinita's house facades, and
## every bot on an east or west bearing walked into a wall and pressed into it for
## the rest of its plan — 🧑: *"they just walk up the houses"*. Pulling the radius
## back fixed that map at that size; publishing the extent makes the whole class of
## bug impossible to generate.
##
## ⚠️ IT TAKES THE NEAREST WALL ON EACH AXIS, not the bounding box. A map whose east
## wall is closer than its west one is a map whose narrow side is the real limit,
## and a symmetric answer would let a bot walk into the near one.
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
		# A wall is named for the axis it blocks; its offset on that axis is how far
		# out it sits. The other axis is the run of the wall and says nothing.
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
		# BEHIND the can from the attackers' point of view: they are at +Z, the can
		# is at the origin, so the taya's mark is at -Z and the can is between them.
		return Vector3(0.0, SPAWN_START_HEIGHT, -DEFENDER_START_OFFSET)
	var ring: float = CharacterBase.confinement_radius + SAFE_ZONE_MARGIN
	# -1, 0, +1 across the line, so the middle attacker is on the centre line and
	# the layout is symmetric about it.
	var offset := (float(role_index) - 2.0) * ATTACKER_SPAWN_SPACING
	return Vector3(offset, SPAWN_START_HEIGHT, ring)

## Everyone faces the lata at the start of a round — the Defender because it is
## what they are guarding, the Attackers because it is what they are aiming at.
func _role_spawn_yaw(role_index: int) -> float:
	var here := _role_spawn_point(role_index)
	var delta := -Vector3(here.x, 0.0, here.z)
	if delta.length() < 0.01:
		return 0.0
	return atan2(-delta.x, -delta.z)

## Places a player at the mark for the role it is about to play. `role_index` 0 is
## the Defender, 1..3 the Attackers — NOT the player's seat, which is a different
## number and rotates independently of the mark.
func _place_at_spawn(character: CharacterBase, role_index: int) -> void:
	character.position = _role_spawn_point(role_index)
	# ⚠️ THE WHOLE `rotation`, NOT JUST `.y`. Writing only the yaw component leaves
	# whatever pitch and roll the body already carried, and per `camera_rig.gd`'s
	# `_apply_upright_pose()` note that is exactly the class of leftover basis that
	# ends up in a player's eye.
	character.rotation = Vector3(0.0, _role_spawn_yaw(role_index), 0.0)
	_seat_on_floor(character)
	# ⚠️⚠️ NOBODY MOVES UNTIL THE BROADPHASE HAS SEEN THE WRITE. DO NOT REMOVE.
	#
	# Writing `position` on a PhysicsBody3D updates the SCENE TREE immediately and
	# the physics broadphase only at the next flush, so within one frame every other
	# body's `move_and_slide()` still collides with this character's PREVIOUS
	# collider. Roles rotate every round, so seats trade marks — measured with
	# `tools/jump_probe.gd`, the incoming unit was placed correctly, then on the very
	# next physics step `move_and_slide()` reported three contacts with the outgoing
	# one (normal 0,1,0 — stacked on its head), shoved it 1.60 up, and the frame
	# after that slid it 9.84 units into a wall. Reported as characters "flung many
	# units off their real spawn markers, sometimes airborne" (B-100).
	character.begin_spawn_settle()
	# This is a TELEPORT, not a walk. Every round reset routes through here, and
	# without this a remote peer's interpolated visual would glide across the map
	# from its previous position instead of snapping there with everyone else.
	character.snap_visual_interpolation()

const SPAWN_FLOOR_PROBE_HEIGHT: float = 2.0
const SPAWN_FLOOR_PROBE_DEPTH: float = 6.0
## A hair of clearance so the capsule rests ON the floor rather than exactly touching it,
## which `move_and_slide` resolves as a contact on the very first frame.
const SPAWN_FLOOR_CLEARANCE: float = 0.02

func _seat_on_floor(character: CharacterBase) -> void:
	var space := character.get_world_3d().direct_space_state
	var from := character.global_position + Vector3.UP * SPAWN_FLOOR_PROBE_HEIGHT
	var to := from + Vector3.DOWN * SPAWN_FLOOR_PROBE_DEPTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	# Exclude ourselves, or the ray hits the capsule we are about to move.
	query.exclude = [character.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	character.global_position.y = (hit["position"] as Vector3).y 		+ character.capsule_height() * 0.5 + SPAWN_FLOOR_CLEARANCE

## Set by `--dedicated`, read once by `_start_hosting`. Command-line only: there is no
## button for it, because a player clicking HOST is by definition sitting at the machine
## and wants a seat.
var _dedicated: bool = false
## Set by `--port=`, so a pool of lobby processes on one machine can each take a port.
## Defaults to the same port hosting has always used.
var _host_port: int = NetworkManagerScript.DEFAULT_PORT

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
var _peer_slots: Dictionary = {}
## 🧑 2026-08-01: *"allow bots in single player to have random cans and random
## slippers, their respective cans show when theyre defender, let my
## respective can show when im defender as well."* slot (0..3) -> {"can": int,
## "slipper": int}, host-decided and replicated the same way `character_index`
## already is (§ `_refresh_ai_prop_picks`'s own doc — a peer computing its own
## random pick gives two peers two different answers for the same bot).
## Populated by `_refresh_seat_prop_picks()`, read by `_push_prop_skins()`.
var _seat_prop_picks: Dictionary = {}
## Session 7: a team is 1 Person + 1 Can/Slipper Prop, NOT two identical Props
## (corrects the Session 5/6 placeholder, which spawned two interchangeable
## Can/Tsinelas units per team). peer_id -> bool, true if that peer is the
## team's Person. Fixed for the whole match, same lifetime as _peer_slots —
## see _spawn_player for how it's assigned.
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

## join index -> the peer_id that reclaimed it, for a reclaim whose RPC beat the
## character's own spawn to this peer. Consumed once, from `_build_networked_character`.
## Same shape and same reason as `_known_picks` — see `_rpc_reclaim_character`.
var _pending_reclaims: Dictionary = {}

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
			# ⚠️ HOSTS WITHOUT PLAYING — see NetworkManager.host_game's dedicated
			# header. This is how one of a fixed pool of lobby processes on a server
			# is started: `--headless -- --dedicated --port=8912`. It implies
			# `--host`, because a dedicated server that does not host is nothing.
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
				# ⚠️ THE ONLY WAY TO REACH SPECTATOR MODE WITHOUT CLICKING THROUGH THE
				# SETUP SCREEN, and it exists for the same reason `--host`/`--join=` do:
				# this project is developed by launching Main.tscn directly, and a mode
				# that can only be entered through three screens is a mode nobody
				# verifies. Deliberately inside the command-line branch, so it can never
				# override a real `GameLaunch.spectator` set by the lobby.
				GameLaunch.spectator = true

	if should_host:
		_start_hosting()
	elif join_target != "":
		_start_joining(join_target)
	else:
		_start_local_test()

## Session 9: local single-PC/split-keyboard flow, now spawning the real
## 4-unit Person+Prop structure instead of the old 1v1 Can/Tsinelas smoke
## test. TeamA's Person (P2) needs its own Tag/Throw instance same as any
## networked Person — see the note where PERSON_ACTION_ABILITY was. TeamB's Person is a
## local-test dummy (unbound input, see Main.tscn/project.godot) but still
## gets its own duplicated instance too, rather than sharing TeamA Person's:
## AbilityBase.tick() runs every physics frame regardless of whether the
## character ever receives input, so two Persons sharing one Resource would
## still incorrectly share cooldown state even though the dummy can never
## press the button itself.
func _start_local_test() -> void:
	_local_roster = players.duplicate()
	# Seats are 0..3 and fixed for the match; the ROLE rotates over them. Set here
	# rather than trusted from the scene's exports, because `_reset_world()` keys
	# every role decision off `player_slot` — a duplicated seat would silently give
	# one player two turns as Defender and another none.
	for i in range(_local_roster.size()):
		_local_roster[i].player_slot = i
		_local_roster[i].player_id = i + 1
	# The CHARACTER panel's pick goes to the seat the human is actually going to
	# play. The other three keep the signed-off defaults: the roster's models were
	# chosen to read apart at arena distance, and handing the player's own pick to
	# an opponent too would let someone play a match against a character wearing
	# their exact silhouette.
	var picked_unit := _local_unit_for_seat(GameLaunch.solo_seat)
	picked_unit.character_index = GameLaunch.character_index()
	# ⚠️ ONLY THE HUMAN'S SEAT TAKES THE SAVED NAME. Handing it to all four would put
	# the player's own name on the three bots they are playing against, which is worse
	# than no names at all.
	picked_unit.player_name = SettingsManager.player_name
	# ⚠️ AND THE OTHER THREE GET A REAL PERSON EACH, rather than the -1 sentinel
	# that made every bot wear the same model. Called BEFORE the visual loop
	# below so `apply()` draws the pick first time instead of drawing the stock
	# rig and being corrected. Single Player never reaches the networked call
	# site (`_rpc_begin_ready_countdown` gates it on `NetworkManager.is_host()`,
	# which is false with no session), so it has to be invoked here as well.
	_refresh_ai_prop_picks()
	_refresh_seat_prop_picks()
	# ⚠️ ROUND 1'S ROLES COME FROM THE SCHEDULE UP FRONT, NOT FROM THE SCENE'S
	# EXPORT DEFAULTS. `is_defender` is an `@export` on `CharacterBase.tscn`, so
	# without this every unit loads with whatever the scene file happened to say and
	# the free-roam window before READY shows the wrong player confined to the box.
	# One writer for the role — `MatchManager.defender_slot_for()` — from frame one.
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
		character.is_bot = character != human
		_attach_ai(character, character != human)
		# Follow targets for the spectator's `Tab`. Single Player builds its four units
		# from the scene rather than through `_build_networked_character`, so the group
		# has to be joined here as well — one line, in both places, beats a scan that has
		# to know which units are real.
		character.add_to_group("spectatable")
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
	# ⚠️ A SPECTATOR ACTIVATES NO RIG AT ALL. `_attach_ai` above already gave every unit
	# a controller (the human's is created DISABLED); re-enabling the human's is what
	# turns a four-unit Single Player match into something worth watching, and skipping
	# the rig is what stops the camera being welded inside a Person's head. See
	# `_enter_spectator_mode`.
	if GameLaunch.spectator:
		if human.ai_controller != null:
			human.ai_controller.set_enabled(true)
		human.input_parked = true
		_enter_spectator_mode()
		# ⚠️ RE-ASSERTED A FRAME LATER, BECAUSE SOMETHING TURNS IT BACK OFF.
		# Measured by `spec_probe --solo`: "every seat including the vacated one is
		# bot-held — FAIL, 3 of 4 ai-driven". `debug_player_switcher.gd::_apply_slots()`
		# runs when the DebugBar registers, claims `DEFAULT_P1_UNIT` ("TeamAPerson") for
		# player 1 and DISABLES that unit's controller — which in a spectated solo match
		# is precisely the seat the spectator just vacated. The result is a 2v2 with one
		# unit standing still for the whole round, filmed.
		# Deferred rather than ordered: the switcher registers on its own schedule and
		# this is the cheap half of the fix. The switcher itself is `scripts/ui/**` and
		# therefore `build ux`'s — filed as §4.11.
		_reassert_spectated_bots.call_deferred()
	else:
		var default_rig := human.get_node("CameraRig") as CameraRig
		default_rig.set_active(true)
		default_rig.set_aim_source(CameraRig.AimSource.MOUSE)
	# 2026-07-28: begin_next_round() is deliberately NOT called here any more —
	# see _awaiting_local_ready's own doc. Everyone is already spawned at their
	# role position, but the round (and confinement, which is gated on
	# RoundManager.round_active) doesn't start until the player readies up.
	_awaiting_local_ready = true
	hud.show_ready_prompt(true)
	# ⚠️ A SOLO SPECTATOR HAS NOBODY TO READY UP, AND THE PROMPT ASKING THEM TO IS HIDDEN.
	# `hud.enter_spectator_mode()` strips `ready_prompt` along with every other element
	# that describes a character — correctly, it says "press [R] to start" to somebody who
	# is not in the match — so a spectated Single Player sat in the pre-round window with
	# no instruction on screen and no round ever starting. Measured: `spec_probe --solo`
	# read the §2.7 round strip as '' because `RoundManager.round_active` was still false
	# forty seconds in. There is no second player to wait for here, so waiting is the bug.
	if GameLaunch.spectator:
		_run_ready_countdown.call_deferred()

## Single Player's seat choice, resolved to one of Main.tscn's four hand-placed
## units. The seat numbering is the networked one, unchanged — `team = seat / 2`,
## and the even seat of each pair is the Person — so the two flows cannot mean
## different things by "Team B's Prop". Falls back to Team A's Person, the
## historical default, rather than erroring on a seat that cannot exist.
func _local_unit_for_seat(seat: int) -> CharacterBase:
	if seat < 0 or seat >= _local_roster.size():
		return _local_roster[0]
	return _local_roster[seat]

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

## ---------------------------------------------------------------------------
## ⚠️ SPECTATOR MODE, ENTRY POINT. `Design.md` §9. Called from exactly two places — the
## Single Player branch above, and `_spawn_player` when the LOCAL peer identified itself
## as a spectator — and it is deliberately the only thing either of them does
## differently. There is no spectator flow: there is the ordinary flow with a spawn
## skipped and a camera added.
##
## ⚠️ ADDED TO THIS SCENE, NOT TO `Main.tscn`. The node has no authored content — it is a
## `Node3D` that builds its own `Camera3D` in `_ready()` — so putting it in the scene
## file would mean a camera that exists, and is `current`, for every player who is NOT
## spectating. `Main.tscn` is also a shared-lock file and this needs no lock.
##
## Idempotent: a second call while a spectator already exists is a no-op rather than a
## second camera fighting the first for `current`.
var _spectator: SpectatorCamera = null

## Single Player only. Every one of the four units is a bot while this peer is watching —
## there is no human in the match at all — so nothing local should ever be reading the
## keyboard. Idempotent and cheap; see the call site for the measurement that made it
## necessary and for who owns the real fix.
##
## ⚠️ THE SPECTATOR ITSELF IS NOT IN `_local_roster` AND GETS NO CONTROLLER. 🧑 2026-07-31:
## *"dont give spectator AI... spectator should only be controllable by a person."* This
## loop walks characters; the camera is a `Node3D` with no `CharacterBase` on it and
## cannot be reached from here. `spec_probe --solo` asserts that directly.
func _reassert_spectated_bots() -> void:
	for character in _local_roster:
		if not is_instance_valid(character):
			continue
		if character.ai_controller != null:
			character.ai_controller.set_enabled(true)
		character.input_parked = true
		# ⚠️⚠️ AND EVERY RIG GOES OFF, WHICH IS THE HALF I MISSED THE FIRST TIME.
		#
		# 🧑 report, 2026-07-31: *"i dont see one of the characters bruh in spectator"*,
		# with a screenshot showing two Person nameplates over one visible model. Measured
		# by `spec_probe --solo`: `TeamAPerson rig_active=true` while spectating, with the
		# other three false — `debug_player_switcher.gd::_apply_slots()` had claimed that
		# unit and called `set_active(true)` on its rig.
		#
		# An active rig is not just a camera. `camera_rig.gd::_apply_fpp_self_hide()` drops
		# that character's HEAD MESH and its CARRIED SLIPPER for as long as the rig is
		# active, because the peer looking through it is supposed to be looking PAST its
		# own body — and it shows the viewmodel arms in their place. On a spectator's
		# screen that is a unit missing pieces of itself, seen from the outside.
		#
		# I took `Camera3D.current` back off this same mechanism earlier and stopped there,
		# which fixed the picture and left a body broken inside it. That is why this
		# deactivates the rig outright rather than fighting it property by property: a
		# spectated match has NO local peer holding any character, so there is no rig here
		# that should be active, and every symptom is downstream of that one fact.
		#
		# `set_active()` is CameraRig's own public API — called, not edited. `camera_rig.gd`
		# is `build ux`'s file and stays untouched.
		var rig := character.get_node_or_null("CameraRig") as CameraRig
		if rig != null:
			rig.set_active(false)
	_dress_spectated_units()

## ⚠️⚠️ A SPECTATED MATCH WAS BEING FILMED IN THE STOCK SKIN. 🧑 2026-07-31:
## *"the skins/chara models that are chosen by everyone in char select dont change in
## spectator mode"*, clarified as *"it sees the models BUT it doesnt have custom skin."*
##
## The solo path deliberately writes picks onto ONLY the human's own seat and that
## team's Prop, and leaves every other unit at `character_index`/`can_index` = -1. That
## rule is CORRECT for a playing human and its reason is recorded where it is written:
## handing the player's own pick to an opponent would let somebody play a match against
## a character wearing their exact silhouette. **But a spectator holds no seat**, so in
## a spectated match the rule has nothing to protect and leaves three of four units on
## the neutral 3/3/3 default — which is precisely the match that gets recorded.
##
## ⚠️ SPECTATOR ONLY. This is reached from `_reassert_spectated_bots()`, which runs
## only under `GameLaunch.spectator`, so ordinary play keeps the anti-mirror rule intact.
##
## ⚠️ PERSONS TAKE ROSTER 0 AND 1 ON PURPOSE, not an arbitrary spread.
## `character_roster.gd` pins its first two entries as the signed-off pair chosen to
## read apart at arena distance (`Art_Direction.md`), so this dresses them in real
## roster entries without spending the readability that pinning exists to protect.
##
## ⚠️ It only ever fills a MISSING pick (`< 0`), so the one unit the spectator chose
## before vacating its seat keeps what it chose.
## ⚠️ NOW ONE LINE, AND THE DUPLICATE RULE IT USED TO HOLD IS GONE. This dealt
## `i % ROSTER.size()` — 0/1/2/3, four ADJACENT roster entries — while
## `_refresh_ai_prop_picks()` deals the same kind of pick for ordinary play. Two
## functions answering "which Person does an unpicked seat wear" is two answers
## that drift, and this was already the worse of the two: adjacent entries are the
## least likely to read apart at arena distance, which is the one thing a filmed
## match needs. Both callers now get the spread version, and the anti-mirror rule
## still holds because that function only ever fills a MISSING pick.
func _dress_spectated_units() -> void:
	_refresh_ai_prop_picks()
	_refresh_seat_prop_picks()

func _enter_spectator_mode() -> void:
	if _spectator != null and is_instance_valid(_spectator):
		return
	_spectator = SpectatorCamera.new()
	_spectator.name = "Spectator"
	add_child(_spectator)
	# The YOU card, the crosshair and the charge meters all describe a character this
	# player does not have. `you_card.get_local_character()` would return null and most
	# of the HUD would simply draw nothing, but "mostly blank UI" reads as broken rather
	# than as deliberate — so the whole gameplay layer goes, and the legend replaces it.
	# ⚠️ THE CAMERA GOES WITH IT NOW, not just its static legend: §2.7 needs a live
	# readout (speed, follow target) that only the node itself can answer, and §2.6's
	# whole point is that those two are being changed while a shot is being framed.
	hud.enter_spectator_mode(_spectator)

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
## ⚠️ SPECTATORS ARE NOT COUNTED. They hold no seat and own no character, so they have
## nothing to ready — counting them would hang the gate forever on a press nobody can
## make, which is the same deadlock `_on_player_disconnected` already has to unwind for
## a peer that leaves mid-vote. See `NetworkManager.playing_peer_count()`.
func _expected_ready_count() -> int:
	return NetworkManager.playing_peer_count()

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
	# ⚠️ A SPECTATOR'S PRESS DOES NOT COUNT, and it has to be dropped HERE rather than
	# simply excluded from `_expected_ready_count()`. With one player and one spectator,
	# expected is 1 — so a spectator who presses R first would satisfy the gate on their
	# own and start the match without the person actually playing it. The count and the
	# quorum have to agree about who is in the electorate.
	#
	# The HOST is exempt even when spectating: somebody has to be able to start a match,
	# and it is the only peer that can. Same carve-out `playing_peer_count()` documents.
	if NetworkManager.is_spectator(sender) and sender != multiplayer.get_unique_id():
		return
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
	# ⚠️⚠️ THE LAST CHANCE TO GET EVERY PICK ONTO EVERY UNIT, AND IT IS THE ONE MOMENT
	# THAT IS GUARANTEED TO BE AFTER ALL OF THEM HAVE ARRIVED.
	#
	# Human report, 2026-07-30: *"the character settings (Lata and Slippers) do not
	# update in actual play — no matter what is picked, the default loads."*
	#
	# Every individual link in the chain is correct and has been fixed once already:
	# `_rpc_identify` carries the picks, `_build_networked_character` reads them,
	# `_apply_known_picks` re-applies a pick that lands late, `_refresh_ai_prop_picks`
	# lends a human's picks to their AI teammate's Prop, and `character_visual.gd`'s
	# cache key includes the skin index so a redraw is not skipped. What none of them
	# guarantees is ORDER: a character is built when its peer connects, and a pick is
	# known when that peer's identify packet lands, and those two events race for every
	# peer except the host — so on any given run some units are drawn from a pick and
	# some from the -1 sentinel, which is exactly "sometimes it works" reported as
	# "it never works".
	#
	# The ready gate is the fix because it is the only point in the flow where every peer
	# has connected, every peer has identified, and no round has started. One sweep here
	# is worth another five conditional re-applications scattered along the join path.
	if NetworkManager.is_host():
		_refresh_ai_prop_picks()
		_refresh_seat_prop_picks()
		_rpc_sync_picks.rpc(_picks_table())
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
## ⚠️ `_register_local_can()` WAS DELETED HERE. It registered whichever authored
## Prop was playing the lata this round so `RoundManager` could watch its state.
## The lata is a single world object now and `_reset_world()` hands it over
## directly, so there is nothing per-round to re-register.

func _start_hosting() -> void:
	_clear_local_test_characters()
	# U-4: when arriving from the lobby, ENet is already started — skip the
	# second host_game() call (it would fail with "port in use"). Fall through
	# to signal wiring and spawning, which still need to happen here.
	if not NetworkManager.is_networked():
		if NetworkManager.host_game(_host_port, _dedicated) != OK:
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
	# ⚠️⚠️ A SPECTATING **CLIENT** GOT NO CAMERA AT ALL, AND NOTHING ANYWHERE CALLED FOR ONE.
	#
	# Measured by `spec_probe --lobby-join`: "IN THE MATCH: the client got a free camera —
	# FAIL", with `/root/Main/Spectator` absent while every seat and ready-gate check on
	# the same match passed. `_enter_spectator_mode()` had exactly two call sites — the
	# Single Player branch, and `_spawn_player()` — and **`_spawn_player` is host-only**
	# (it is driven by the host's own connect loop and by `_try_late_join`). So the entire
	# spectator path existed for a solo player and for a host, and a joining client fell
	# through it silently: no camera added, no HUD strip, and the view left on whatever
	# `Camera3D` happened to be current in `Main.tscn`.
	#
	# That is the "boots, single-peer only" line in § SALVAGE, and it is the actual reason
	# spectating could never have been used to film a LAN match.
	#
	# Here rather than in `_spawn_player` because a client is never spawned BY anything
	# local — the host decides who gets a body and the client only ever receives the
	# result. `GameLaunch.spectator` is this peer's own choice, known locally, and this is
	# the first moment on the client where the HUD exists to be stripped.
	if GameLaunch.spectator:
		_enter_spectator_mode()
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
		return
	# ---------------------------------------------------------------------------
	# ⚠️⚠️ B-153 — THE PORT WAS THROWN AWAY HERE, AND THAT IS "you can JOIN it, but
	# you're stuck on a grey screen."
	#
	# 🧑 2026-08-02, from a real player: *"When getting disconnected from a lobby, I want
	# the ability to rejoin it. Currently you are able to JOIN it, but you're stuck on a
	# grey screen."*
	#
	# `address` arrives as `GameLaunch.pending_join_address`, which is a HOST:PORT string —
	# `multiplayer_setup.gd::_begin_join()` is the one place a join is recorded and it
	# stores exactly what the player typed, clicked or resolved from a code, port included
	# (`_free_pool_address()` and every browsed row produce `"ip:port"`). This line used to
	# hand that whole string to `NetworkManager.join_game(address)`, whose second argument
	# is a SEPARATE port defaulting to 8910. `ENetMultiplayerPeer.create_client()` does not
	# parse a colon, so it tried to resolve the literal host name `127.0.0.1:8941`.
	#
	# MEASURED on the returning client (`tools/net/rejoin_run.gd --role=dropper`), verbatim:
	#
	#     ERROR: Couldn't resolve the server IP address or domain name.
	#     ERROR: NetworkManager: failed to connect to 127.0.0.1:8941:8910 (error 20)
	#         [0] join_game  [1] _start_joining  [2] _ready
	#
	# — the port printed twice, which is the bug in one line.
	#
	# ⚠️ THIS IS THE SAME MISTAKE `multiplayer_setup.gd::split_address()` WAS WRITTEN TO
	# FIX, IN THE ONE PATH THAT DID NOT GET IT. That function's own ⚠️ says the address
	# *"went straight to `NetworkManager.join_game(address)`… which takes host and port as
	# SEPARATE arguments and does not parse a colon"* — and both UI join sites were
	# converted. Nothing converted this one, because on the ORDINARY join `MatchSetup` has
	# already connected and the branch above returns before ever reaching it.
	#
	# ⚠️ SO IT ONLY EVER FIRES ON A REJOIN, WHICH IS WHY IT SURVIVED. The only way this
	# scene dials for itself is `NetworkManager._rpc_route_to_running_match`, which
	# deliberately drops the connection and re-opens it from here (see that function's own
	# doc for the spawner race that forces it). The player's JOIN genuinely worked — they
	# reached the lobby, the host recognised them and rerouted them — and then the *second*
	# connection, the one nobody watches, died on a malformed address. Hence "you are able
	# to JOIN it" and a world with nothing in it: `_clear_local_test_characters()` above has
	# already removed the four scene-authored bodies, and `Main.tscn` carries no camera of
	# its own (B-03/B-58), so the viewport draws the 2D HUD over nothing. That is the grey.
	#
	# ⚠️ AND `create_client()` FAILING IS SILENT. It returns an error rather than emitting
	# `connection_failed`, so `_on_connection_failed` never ran and the player was left on a
	# dead scene with no message and no way out but Alt+F4 — the exact soft-lock Q-1/B-62
	# closed for an unreachable host, reopened by a different route. `_bail_to_browser`
	# below is that same exit.
	#
	# ⚠️ `split_address` IS REUSED, NOT REIMPLEMENTED. A second parser is the U-8 bug class
	# this project has already paid for twice, and this one would have to agree about the
	# default port and about rejecting IPv6. `match_setup.gd`'s join branch reaches for the
	# same static function from the same place.
	#
	# Fixes the command-line path too, as a side effect worth stating: `--join=127.0.0.1:8941`
	# silently ignored its port for exactly as long as this line existed.
	# ---------------------------------------------------------------------------
	var parts := MultiplayerSetupScreen.split_address(address)
	var host: String = String(parts[0])
	var port: int = int(parts[1])
	if host.is_empty() or port <= 0 or port > 65535:
		_bail_to_browser("Could not read the address '%s'." % address)
		return
	NetworkManager.connection_succeeded.connect(_on_joined_ready_for_spawn, CONNECT_ONE_SHOT)
	if NetworkManager.join_game(host, port) != OK:
		# ⚠️ THE ONE-SHOT IS TAKEN BACK BY HAND. `CONNECT_ONE_SHOT` disconnects itself when
		# the signal FIRES, and a connection that never opened never fires it — leaving a
		# live subscription on an autoload that outlives this scene, ready to answer the
		# NEXT session's success on a freed node.
		NetworkManager.connection_succeeded.disconnect(_on_joined_ready_for_spawn)
		_bail_to_browser("Could not reach %s." % address)

func _on_joined_ready_for_spawn() -> void:
	_rpc_client_ready_for_spawn.rpc_id(1)

func _clear_local_test_characters() -> void:
	RoundManager.clear_players()
	# The scene-level ArenaCamera is removed — B-03 is closed, B-58 is closed.
	for character in players:
		if is_instance_valid(character):
			character.queue_free()
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
## ---------------------------------------------------------------------------
## B-145 · THE PICKS DO REACH THE UNIT — AND THEN NOT EVERY PEER SEES IT.
##
## 🧑 Reported from play: *"the models we pick don't show up"*, *"i pick coffee,
## if i switch to can, old model stays"*, *"character settings dont update in
## actual play"*. All three are one thing seen from three angles.
##
## ⚠️ MEASURED ON FOUR REAL PEERS FROM A VERIFIED-CLEAN START, and the split is
## exact. For any one Prop there are three kinds of peer:
##
##   the HOST      — `picks_for()` is host-side, so it is right.
##   the OWNER     — writes its own `GameLaunch` (`_apply_reclaimed_picks`), right.
##   EVERYBODY ELSE — reads `can_index = -1` and draws the stock skin at 3/3/3.
##
## **With two peers there is no everybody-else**, which is why every two-instance
## run this project has ever done was green and the game was broken in a real
## four-player match. Host and owner read `can_index=3`; the two third-party
## clients read `-1` for the same unit in the same round.
##
## ⚠️ TWO PLAUSIBLE FIXES WERE TRIED FIRST AND BOTH MEASURED NO CHANGE — recorded
## so nobody spends the afternoon re-trying them:
##
##   1. `_build_networked_character` stamping -1 over a replicated value. Real,
##      and guarded now (a peer with no answer must leave the value alone — the
##      rule `_apply_reclaimed_picks` already states), but NOT the cause: the
##      third-party clients still read -1 afterwards.
##   2. Flipping the three properties from `replication_mode` ON_CHANGE to ALWAYS
##      in `CharacterBase.tscn`. Also no change. The state is not arriving at
##      all, so how often it would be re-sent is beside the point.
##
## So the value never crosses to a peer that owns neither the node nor the
## session, and it is sent HERE instead — on the same trigger, to the same one
## peer, as the round-state catch-up directly above, which exists because a
## joiner misses things that happened before it existed. **This is not U-8.**
## U-8 is a second path for something the host already delivers; nothing
## delivered this.
## ---------------------------------------------------------------------------

## HOST-ONLY. Re-asks `_team_prop_picks` for every AI-held Prop that still has no
## picks, then tells everybody. Idempotent and cheap: a Prop that already has an
## answer is skipped, and a team whose Person is still a bot legitimately stays
## at -1 (the neutral 3/3/3 is correct when there is nobody to inherit from).
## ⚠️ `_refresh_ai_prop_picks()`'s ORIGINAL BODY WAS DELETED IN THE PIVOT. It
## inherited a human's lata and tsinelas skin picks onto their bot teammate's
## Prop. There are no Prop seats and no prop picks — a player picks a Person and
## nothing else. It was left as a no-op; it now deals the BOTS their Persons.
##
## ⚠️⚠️ EVERY BOT WORE THE SAME FACE UNTIL 2026-08-01. 🧑: *"RANDOMISE THE BOTS'
## CHARACTER SKINS."* An AI seat is never given a `character_index`, so it keeps
## the -1 sentinel, and `character_visual.gd::_model_path()` then falls back to
## `PERSON_MODELS[team]` — one model for every bot in the match. Twelve roster
## entries exist and a four-player match was showing two.
##
## ⚠️ HOST-DECIDED AND REPLICATED, NOT COMPUTED PER PEER, AND `randi()` WOULD BE
## WRONG TWICE OVER. The obvious fix is a random pick at spawn, which gives two
## peers two different faces for the same bot; the next-most-obvious is a pure
## function of the slot computed everywhere, which is deterministic but cannot see
## which Persons the HUMANS took and so happily dresses a bot as the player. This
## runs on the host, where both facts are known, and every caller already follows
## it with `_rpc_sync_picks(_picks_table())` — a table that has carried
## `character_index` since the pivot. So the wire format, the late-join catch-up
## and the client-side apply all already exist and none of them changes.
##
## ⚠️ SEATS ARE WALKED IN NUMERIC ORDER, NOT IN DICTIONARY ORDER. `taken`
## accumulates as it goes, so the order decides the answer — and `_index_to_
## character`'s insertion order is connection order, which differs per session and
## per peer. `range()` is what makes the same match deal the same four Persons
## every time.
##
## Idempotent: a seat that already has a pick is skipped, so re-running this at
## every ready gate and every late join cannot reshuffle a match in progress.
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
		# ⚠️ "< 0" IS THE WHOLE TEST FOR "THIS IS A BOT", and it is better than
		# asking about the AIController. It is exactly the condition
		# `_model_path()` falls back on, so this fills precisely the gap that
		# produces the duplicate model — and a human seat is never negative
		# (`GameLaunch.character_index()` floors at 0), so this cannot overwrite
		# a player's own pick even if it ran on the wrong seat.
		if who == null or who.character_index >= 0:
			continue
		var pick := _ai_character_index(slot, taken)
		taken.append(pick)
		who.character_index = pick
		# The model has to be told: `_visual.apply()` runs at `_ready()` and on a
		# role rotation, and this is neither.
		var visual: Node = who.get_node_or_null("Visual")
		if visual != null and visual.has_method("apply"):
			visual.apply(who.is_person, who.is_can, who.player_slot)


## ⚠️⚠️ SENDS A BOT BACK TO -1 IF IT IS WEARING A HUMAN'S PERSON, so the dealer below
## re-fills it. New 2026-08-02, and it is what makes dealing bots at spawn safe.
##
## `_fill_empty_slots_with_placeholders()` now deals AI seats the moment they spawn, so
## their names exist from the first frame instead of appearing at the ready gate (see that
## function's note — it is the multiplayer names fix). But it runs inside `_start_hosting()`,
## before a single client has connected, so the dealer cannot yet see which Persons the
## humans took: a bot can quite legitimately be given the face somebody picks later.
##
## The old dealer could not fix that. It is idempotent by design — `character_index >= 0`
## is skipped — which is what stops a re-run reshuffling a match in progress, and it also
## means a wrong early guess would stick for the whole match. Releasing the collision
## first keeps both properties: a bot that is NOT clashing is still never touched again, and
## a bot that IS gets re-dealt from the same deterministic spread, this time with the human
## picks in `taken`.
##
## ⚠️ THE HUMAN IS NEVER THE ONE MOVED, even though the collision is symmetric. Their pick
## came from the CHARACTER screen and is the one choice in this function anybody made on
## purpose.
func _release_bot_picks_colliding_with_humans(seats: Dictionary) -> void:
	var human_picks: Array[int] = []
	for slot in seats:
		var who: CharacterBase = seats[slot]
		if who == null or not is_instance_valid(who):
			continue
		# ⚠️ `is_bot or is_ai_driven()` — the same pair `display_name()` asks, and for the
		# same reason: `is_bot` is intent set by `call_local` RPCs on every peer, and
		# `is_ai_driven()` catches Single Player and the Tab switcher, which never go
		# through those RPCs. Asking only one of them misclassifies a seat in one mode.
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

## Roster indices the four seats reach for first, spread across the twelve rather
## than taken in order. 0/1/2/3 would deal the four Persons the roster happens to
## list first, which are also the four most likely to be adjacent in palette;
## quartering the list makes four bots read apart at arena distance, which is the
## entire point of dealing them at all.
const AI_PERSON_SPREAD: Array[int] = [0, 3, 6, 9]

## The first roster entry at or after this seat's preferred index that nobody has
## taken. Walking forward on collision (rather than, say, adding a random offset)
## keeps the whole thing a pure function of the seat and the set already taken.
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


## slot -> CharacterBase, for whichever spawn path this session used.
##
## ⚠️ TWO PATHS BUILD THE FOUR UNITS AND THEY STORE THEM IN DIFFERENT PLACES:
## Single Player fills `_local_roster` from the authored scene, and a networked
## match fills `_index_to_character` from the spawner. Anything that wants to
## reason about "the four seats" has to ask both or it silently works in one mode
## only — which is how a bug gets described as "it only happens in multiplayer".
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

## [index, character_index, player_name, can_index, slipper_index] for every
## spawned seat. Built on the host, where the answer is known. The last two
## columns are `_seat_prop_picks`', not a `CharacterBase` property — see that
## var's own doc for why this feature does not touch `character_base.gd`.
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

## Host → ONE peer. Applies to the units that already exist here, and is kept so
## a unit that has not arrived yet can be answered when it does — the spawn order
## and this message have no guaranteed relationship, and assuming one is how the
## first version of this dropped the seat that arrived a frame late.
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

## ⚠️ NEVER WRITES A -1. Same rule as everywhere else in this file: a peer with
## no answer leaves the value it was given alone.
func _apply_known_picks(character: CharacterBase, index: int) -> void:
	var row: Array = _known_picks.get(index, [])
	if row.size() < 2:
		return
	if int(row[1]) >= 0:
		character.character_index = int(row[1])
	# ⚠️ SANITISED ON ARRIVAL. This string came off the wire from another peer and is
	# about to be drawn on a scoreboard and a 3D label; `SettingsManager` owns the one
	# trim-and-cap so a hostile or merely careless client cannot post a novel.
	if row.size() >= 3:
		character.player_name = SettingsManagerScript.sanitise_name(String(row[2]))
	# ⚠️ THE MODEL HAS TO BE TOLD. `_visual.apply()` runs at `_ready()` and on every
	# role rotation — neither of which happens when a pick lands mid-round, so
	# without this the unit keeps wearing whatever it was drawn with.
	var visual: Node = character.get_node_or_null("Visual")
	if visual != null and visual.has_method("apply"):
		visual.apply(character.is_person, character.is_can, character.player_slot)
	# Cached client-side, not written onto `character` — see `_seat_prop_picks`'
	# own doc. `_rpc_sync_picks` is `call_remote`, so the host never runs this
	# branch on itself; it already populated `_seat_prop_picks` directly in
	# `_refresh_seat_prop_picks()`.
	if row.size() >= 5:
		var can := int(row[3])
		var slipper := int(row[4])
		if can >= 0 or slipper >= 0:
			_seat_prop_picks[index] = {"can": can, "slipper": slipper}

func _try_late_join(peer_id: int) -> void:
	if _spawned_peer_ids.has(peer_id):
		return
	if not NetworkManager.peer_tokens.has(peer_id):
		return
	_spawn_player(peer_id)
	# B-29/B-48: _start_hosting() already called MatchManager.begin_next_round()
	# before anyone could possibly be connected (see B-13), so every joining
	# peer — not just a "late" one — missed the one-shot _sync_round_started
	# broadcast and is stuck at round_number 0. Catch this one peer up in a single
	# reliable RPC.
	#
	# ⚠️⚠️ THIS CALL USED TO PASS THE 2v2 ARGUMENT LIST AND THREW ON EVERY SINGLE JOIN.
	# Measured on two real peers 2026-08-01 (`tools/ui/net_twopeer_probe.tscn`): the
	# host printed `Invalid access to property or key 'team_a_wins' on a base object of
	# type 'Node (MatchManagerScript)'` the instant the client identified.
	#
	# The HARRYDAKS pivot rewrote the RECEIVER below to the four-player shape —
	# `(round_number, defender_slot, scores, time_left, round_active, lata_upright)` —
	# and did not update this one call site, which still sent `team_a_wins`,
	# `team_b_wins`, `set_number` and `round_in_set`. None of those four exist on
	# `MatchManager` any more (paired sets and Option A went with the 2v2 format,
	# `Design.md` §12), so the property access threw before the RPC was ever sent.
	#
	# ⚠️ AND THE THROW ABORTED THE REST OF `_try_late_join()`, which is why this was
	# worth finding rather than merely untidy: every line below — the picks catch-up
	# that carries the PROP SKINS, `_refresh_ai_prop_picks()`, and the ready-phase
	# hand-off — never ran for any joining peer. A single-machine session never calls
	# this function at all, so nothing about it is visible in Single Player.
	_sync_state_to_late_joiner.rpc_id(
		peer_id, MatchManager.round_number, MatchManager.defender_slot,
		MatchManager.scores, RoundManager.time_left, RoundManager.round_active,
		lata != null and lata.is_upright
	)
	# B-145 — see `_rpc_sync_picks`. The same catch-up, for the three indices the
	# synchronizer does not deliver to a peer that owns neither the node nor the
	# session. Sent on the SAME trigger as the round state above, to the same one
	# peer, for the same reason: it missed a thing that happened before it existed.
	_rpc_sync_picks.rpc_id(peer_id, _picks_table())
	_sync_slipper_carry_to_late_joiner(peer_id)
	# B-145, second half. NET-1 gave an AI-held Prop its human teammate's picks —
	# but `_fill_empty_slots_with_placeholders()` runs in `_start_hosting()`,
	# BEFORE a single client has connected, so `_team_prop_picks` had nobody to
	# inherit from and wrote -1. Nothing ever asked again, so a bot Prop sitting
	# beside a human who joined thirty seconds later wore the stock 3/3/3 for the
	# whole match. Measured: the last remaining red row on the four-peer run.
	_refresh_ai_prop_picks()
	_refresh_seat_prop_picks()
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
	# ⚠️ `RoundManager.register_ring_out(character)` WAS CALLED HERE and is deleted
	# with Option A (§8.2) — ring-outs were that mode's second win path for the can
	# side. The respawn itself is unchanged: a unit that falls off the arena still
	# comes back, it just no longer scores anything for anybody.

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
## _spawned_characters/_peer_slots/_peer_is_person directly here — that
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
		_rpc_show_toast.rpc("A player left — a bot has taken over their character")
	else:
		# Should not normally happen (every spawned character has an index —
		# see _build_networked_character) — kept as a fallback so a disconnect
		# never silently does nothing if that assumption is ever wrong.
		_rpc_show_toast.rpc("A player left the match — their character will hold position until they reconnect")
	# ⚠️ LAST, AND IT MAY CHANGE SCENE OUT FROM UNDER EVERYTHING ABOVE. On a dedicated
	# referee an empty room means the match is over whatever the scoreboard says — see
	# § BACK TO THE WAITING ROOM. `change_scene_to_file` is deferred to the end of the
	# frame, so the bookkeeping above still completes; nothing after this line may not.
	_recycle_dedicated_lobby_if_abandoned()

## ---------------------------------------------------------------------------
## ⚠️⚠️ § BACK TO THE WAITING ROOM — WHY A POOL LOBBY IS NOT A ONE-SHOT.
##
## MEASURED ON THE LIVE VM, 2026-08-02: a dedicated server whose match had been
## abandoned answered the pool query `players=0, occupied=0, in_progress=true`
## **with nobody connected at all**, indefinitely. Reproduced here on 8971 before
## this existed — twelve consecutive status replies, one a second, all identical.
##
## That is not cosmetic. `multiplayer_setup.gd::_free_pool_address()` skips every row
## whose `in_progress` is true, so a lobby stuck this way is PERMANENTLY UNHOSTABLE:
## HOST ONLINE can never hand it to anybody again. The deployment runs a single lobby,
## so ONE abandoned match killed HOST ONLINE for everyone until an operator restarted
## the service. A real player hit it.
##
## THE CAUSE IS THAT NOTHING EVER TURNED THE FLAG OFF. `match_in_progress` is written
## `true` in exactly one place (`_start_hosting`, below) and back to `false` in exactly
## one place — `NetworkManager.disconnect_network()`, which also closes the ENet server
## and the status socket. A dedicated referee has no human to press QUIT TO MENU, gets no
## `server_disconnected` (it *is* the server), and `_on_player_disconnected` above only
## ever handed the leaver's body to a bot. There was no third way out, and the comment in
## `match_setup.gd`'s § A LOBBY WITH NOBODY SITTING AT IT said so out loud: *"the match
## ends and the process exits… `Restart=always` brings it back"*. It does not exit. It
## sits in `Main.tscn` refereeing nothing.
##
## ⚠️⚠️ SO THE FIX IS A RETURN, NOT A RESTART, AND IT MUST NOT TOUCH THE SOCKETS.
## The process goes back to `MatchSetup.tscn` — the waiting room a pool lobby already
## boots into — while ENet, `ServerQuery`'s status responder and the LAN beacon all stay
## exactly as they are. Tearing those down is what `disconnect_network()` does, and doing
## it here would drop the lobby out of the pool for as long as it took to rebind, which is
## the same outage in a smaller window. `match_setup.gd::_setup_host()` grew the matching
## half: it does not re-`host_game()` when the socket is already open.
##
## ⚠️ GATED ON `NetworkManager.is_dedicated`, NEVER ON "the room is empty".
## A LISTEN HOST has a human at the keyboard who owns this decision — they may be sitting
## on the result screen deciding, or alone in a lobby waiting for friends — and yanking
## their match back to a setup screen because ENet reported nobody else present would be a
## far worse bug than the one this fixes. `is_dedicated` is only ever true where
## `host_game(port, dedicated = true)` was called, i.e. on a pool process.
##
## ⚠️⚠️ TWO DIFFERENT EVENTS LEAD HERE AND THEY ARE NOT THE SAME EVENT.
##
##   THE ROOM EMPTIED (`_on_player_disconnected` above). Immediate, unconditional, and
##   the one the live incident actually was. A referee with nobody connected is
##   refereeing nothing, whether the score was 0-0 or the last round was half over.
##
##   THE MATCH WAS WON (`_on_match_won_freeze_physics` below). Deliberately NOT immediate.
##   The result screen carries a REMATCH VOTE (`match_result.gd`) and the players are
##   still connected and still deciding — recycling on the whistle would tear the world
##   out from under a rematch that was one click away. So the whistle ARMS a grace window;
##   a rematch (`MatchManager.round_started`) disarms it, and only if it actually expires
##   does the referee close the room. That last step is not optional either: without it,
##   four players who finish a match and then wander off leave the lobby held at
##   `in_progress = true` behind a result screen nobody is looking at, which is the same
##   outage arriving the polite way.
## ---------------------------------------------------------------------------

## Where a recycled lobby goes. The same scene a pool process boots into — see
## `match_setup.gd`'s § A LOBBY WITH NOBODY SITTING AT IT — so there is one waiting room,
## not a second one written for coming back to.
const MATCH_SETUP_SCENE_PATH: String = "res://scenes/ui/MatchSetup.tscn"

## How long a finished match's result screen is left up on a DEDICATED server before the
## referee closes the room and takes the lobby back. Long enough that a rematch vote is
## never the thing that times out — the ballot is decided within seconds of the screen
## appearing — and short enough that a lobby is not held hostage by one person who walked
## away from their keyboard without quitting.
##
## ⚠️ IT IS NOT A LISTEN HOST'S BUSINESS. Nothing below this line runs on one.
const DEDICATED_POST_MATCH_SECONDS: float = 120.0

## After the referee evicts the room, how long to give ENet to report the disconnections
## before trying the recycle from this side instead. The clients normally drop themselves
## on the announcement and `_on_player_disconnected` does the work within a frame or two;
## this covers the ordering case where they have all gone but the last signal has not been
## polled yet. It is NOT a way past a peer that is still connected — see `_evict_and_recycle`.
const DEDICATED_EVICT_BACKSTOP: float = 3.0

## The armed post-match window, or null. Held so a rematch can cancel it — a `SceneTreeTimer`
## cannot be stopped, so cancelling means dropping the reference and having the callback
## check whether it is still the armed one.
var _post_match_timer: SceneTreeTimer = null
## One-way latch. `change_scene_to_file` only takes effect at the end of the frame, so
## without this a disconnect burst (four peers dropping together) would queue four scene
## changes and re-run the whole reset on a lobby that had already been rebuilt.
var _recycling: bool = false

## The one predicate everything in this section is gated on. Both halves matter: a CLIENT
## of a dedicated server also has `is_dedicated == true` (the server tells it so — see
## `NetworkManager._rpc_announce_dedicated`), and a client must obviously not recycle
## anybody's lobby.
func _is_dedicated_referee() -> bool:
	return NetworkManager.is_dedicated and NetworkManager.is_host()

## THE ROOM EMPTIED. Called from `_on_player_disconnected`, which only ever runs on the
## host, so this is asking "was that the last one out".
func _recycle_dedicated_lobby_if_abandoned() -> void:
	if not _is_dedicated_referee():
		return
	# ⚠️ `connected_peer_ids` NEVER HOLDS THE SERVER ITSELF on a dedicated process — see
	# `NetworkManager.host_game`'s ⚠️ THE ONLY DIFFERENCE IS THE SELF-SEEDING. So empty
	# here means "no humans", not "no peers at all", and no carve-out is needed.
	if not NetworkManager.connected_peer_ids.is_empty():
		return
	_recycle_dedicated_lobby()

## THE MATCH WAS WON. Arms the grace window described in the header. Re-armable: a rematch
## that is itself won comes back through here.
##
## ⚠️ A NAMED METHOD PLUS `.bind()`, NOT A LAMBDA. A `SceneTreeTimer` outlives this scene —
## the abandonment path can recycle the lobby and free `Main.tscn` while a window is still
## armed — and Godot cleans a connection up when the RECEIVER object is freed, which it can
## only do for a callable whose receiver it can see. A lambda's captured `self` is not that.
func _arm_post_match_reset() -> void:
	if not _is_dedicated_referee():
		return
	var timer := get_tree().create_timer(DEDICATED_POST_MATCH_SECONDS)
	_post_match_timer = timer
	timer.timeout.connect(_on_post_match_window_elapsed.bind(timer))

## ⚠️ IT CHECKS WHICH WINDOW FIRED. A `SceneTreeTimer` cannot be stopped, so disarming means
## dropping the reference — and the timer still fires afterwards. Without this identity test
## a rematch would be interrupted by the window armed before it started, which is precisely
## the thing the grace period exists to avoid.
func _on_post_match_window_elapsed(timer: SceneTreeTimer) -> void:
	if _post_match_timer != timer:
		return
	_post_match_timer = null
	_close_finished_dedicated_match()

## A rematch carried, or an ordinary round began. Either way the referee is refereeing
## again and the window it armed at the last whistle is no longer about anything.
func _disarm_post_match_reset() -> void:
	_post_match_timer = null

## The grace window expired with the match still over. Clear the room, then take the lobby
## back.
##
## ⚠️ IT ANNOUNCES BEFORE IT EVICTS. `NetworkManager.announce_host_leaving()` is the
## existing, measured path for "the host is going" — without it a client learns about a
## closed socket exactly as slowly as about a yanked cable (5.2 s of `ENET_TIMEOUT_MIN`),
## and lands on MultiplayerSetup with "Host ended the session." either way. The point of
## the announcement is that it lands NOW rather than in five seconds.
##
## ⚠️ AND IT EVICTS EXPLICITLY AFTERWARDS, which is not belt-and-braces. A client that has
## already stopped answering never acts on the announcement, and a peer left in
## `connected_peer_ids` keeps `occupied` above zero — which is the OTHER thing
## `_free_pool_address()` refuses to claim. A lobby that recycled its flag and kept a ghost
## would be exactly as unhostable as one that did neither.
func _close_finished_dedicated_match() -> void:
	if not _is_dedicated_referee():
		return
	if NetworkManager.connected_peer_ids.is_empty():
		_recycle_dedicated_lobby()
		return
	_rpc_show_toast.rpc("The match is over — this lobby is going back to its waiting room.")
	await NetworkManager.announce_host_leaving()
	# ⚠️ THE ONE `await` HERE NEEDS THIS, and everything after it is a plain call for the
	# same reason. A peer's disconnect can complete inside that await and recycle the lobby
	# through `_on_player_disconnected`, which frees this scene — and a coroutine resuming
	# on a freed node is a hard error, not a silent no-op.
	if not is_inside_tree():
		return
	_evict_and_recycle()

## ---------------------------------------------------------------------------
## ⚠️⚠️ `disconnect_peer()` IS CALLED WITHOUT `force`, AND THAT IS NOT A DEFAULT LEFT
## UNCONSIDERED. Godot's `ENetMultiplayerPeer::disconnect_peer(peer, true)` erases the peer
## from its own table and then, **if that was the last one, closes the whole host**. On a
## dedicated server that is the entire ENet listener — the socket this fix exists to keep
## open — so forcing the eviction would trade a lobby stuck at `in_progress = true` for one
## that has stopped listening altogether. Strictly worse.
##
## ⚠️ SO A PEER THAT HAS ALREADY GONE SILENT IS NOT EVICTED PROMPTLY, and the backstop below
## will correctly decline to recycle while it is still in `connected_peer_ids`. That case
## self-heals: ENet reaps it on `ENET_TIMEOUT_MAX` (deliberately wide — 45 s — because this
## game is played over Hamachi), `_on_player_disconnected` fires, and the abandonment path
## recycles the lobby then. Late is a real cost; a dead listener is not a cost this may pay.
## ---------------------------------------------------------------------------
func _evict_and_recycle() -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet != null:
		# `.duplicate()`: a disconnect can land inside this loop and erase from the very
		# array it is walking.
		for peer_id in NetworkManager.connected_peer_ids.duplicate():
			enet.disconnect_peer(int(peer_id))
	# Normally nothing below does the work: the announcement above already made every
	# client drop its own peer, `peer_disconnected` arrives within a frame or two, and
	# `_on_player_disconnected` recycles as the last one goes. This is the case where it
	# did not — and `_recycle_dedicated_lobby` declines by itself if the room is not
	# actually empty yet, so an early fire is harmless.
	get_tree().create_timer(DEDICATED_EVICT_BACKSTOP).timeout.connect(_recycle_dedicated_lobby)

## ---------------------------------------------------------------------------
## The reset itself. Everything `host_game()` would have established for a fresh session,
## MINUS the two sockets — because those are already open and must stay that way.
##
## ⚠️ IT RUNS ONLY WITH THE ROOM ALREADY EMPTY, and both callers guarantee that. It clears
## the identity maps a still-connected peer would depend on (`peer_tokens` decides that
## peer's seat, `peer_characters` its name and face), so scrubbing them under somebody who
## is still in the lobby would leave a ghost the board cannot draw and the ready gate
## cannot count.
## ---------------------------------------------------------------------------
func _recycle_dedicated_lobby() -> void:
	if _recycling or not _is_dedicated_referee():
		return
	if not NetworkManager.connected_peer_ids.is_empty():
		return
	_recycling = true
	_disarm_post_match_reset()
	# A dedicated process never pauses itself today, but a scene change with the tree still
	# paused loads the next scene paused and every button on it dies — Q-3/B-64, and the
	# same line `_on_return_to_menu_pressed` opens with.
	get_tree().paused = false
	# ⚠️⚠️ THE ONE LINE THE WHOLE INCIDENT WAS ABOUT. `server_query.gd::_status_payload()`
	# reports this flag verbatim as `in_progress`, and `_free_pool_address()` will not
	# claim a row that has it set.
	NetworkManager.match_in_progress = false
	# ⚠️ A FRESH CODE, BECAUSE THIS IS A DIFFERENT LOBBY. `join_code`'s own doc: a code is
	# per-SESSION *"because a server that has restarted is a different lobby with a
	# different set of people in it — a code that survived would send a player to the room
	# its old occupants have left"*. Coming back from a finished match is that same
	# sentence without the restart, so it gets the same treatment `host_game()` gives.
	NetworkManager.join_code = NetworkManager._mint_join_code()
	NetworkManager.join_code_changed.emit(NetworkManager.join_code)
	# The three things `host_game()` clears for a new session. Same reason: they described
	# the match that just ended, and the next lobby's occupants have not identified yet.
	NetworkManager.peer_tokens.clear()
	NetworkManager.peer_characters.clear()
	# ⚠️ AND THE LEADER, WHICH IS THE ONE THAT WOULD BREAK SILENTLY. A dedicated lobby with
	# a stale non-zero `lobby_leader_id` never runs `_claim_lobby_leader_if_vacant` for the
	# next person through the door, so nobody can pick the map and nobody can press START —
	# a lobby that answers every query, accepts every join and cannot begin a match.
	# `_reassign_leader` normally lands this on 0 as the last peer leaves; setting it here
	# means the invariant does not depend on that having happened.
	NetworkManager.lobby_leader_id = 0
	# Host-authoritative seating from the finished match. `_rpc_begin_match` rewrites it at
	# the next kickoff, but a stale map keyed by tokens nobody holds any more has no
	# business surviving into a lobby those players are not in.
	GameLaunch.clear_seating()
	# B-14, for the same reason `_ready()` and `_rpc_begin_match` both already do it: these
	# are autoloads and would otherwise carry this match's score and round into the next.
	MatchManager.reset()
	RoundManager.reset()
	# The pool is operated by reading journalctl, so the recycle says so on stdout. One
	# line, and it names the new code — which is the only thing about the lobby that
	# changed and the only thing an operator cannot see any other way.
	print("main: dedicated lobby recycled — back to the waiting room, code %s." % [
		NetworkManager.join_code])
	get_tree().change_scene_to_file(MATCH_SETUP_SCENE_PATH)

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
	# ⚠️ A SPECTATOR IS NOT SEATED AT ALL. Marked as spawned first, deliberately, so a
	# later `_try_late_join` cannot come back for the same peer and seat it anyway — the
	# dictionary means "this peer has been dealt with", not "this peer has a body".
	#
	# The seat it would have taken is left empty and is filled by
	# `_fill_empty_slots_with_placeholders`, the path that has always filled an unfilled
	# slot. That is the whole implementation: a spectator is the ABSENCE of a spawn, not
	# a second kind of one. See `GameLaunch.spectator`.
	if NetworkManager.is_spectator(peer_id):
		_spawned_peer_ids[peer_id] = true
		if peer_id == multiplayer.get_unique_id():
			_enter_spectator_mode()
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

## ---------------------------------------------------------------------------
## NET-1 · THE LATA AND TSINELAS PICKS AN AI-HELD PROP SEAT WEARS.
##
## 🧑 Human report: *"add stats for cans and slippers bcz i think theyre all the
## same"* — and MEASURED, on two real peers each picking a different lata and a
## different tsinelas, every Prop in the match read `can_index = -1` and so
## resolved to `TRAIT_NEUTRAL` 3/3/3 on both machines.
##
## ⚠️ THE PICKS WERE CROSSING THE WIRE PERFECTLY. That was the first hypothesis
## and it was wrong; instrumenting the spawn path showed the host holding
## `{"character": 0, "can": 4, "slipper": 1}` for the peer that sent it. The
## actual cause is SEATING: a 2v2 has four seats and each human occupies exactly
## one, so with fewer than four humans the leftover seats are filled with
## negative-sentinel AI (`_fill_empty_slots_with_placeholders`) — and an AI slot
## has no picks by design. In a two-player match BOTH humans can be sitting in
## Person seats, which means every lata and every tsinelas actually in play
## belongs to a bot, and every one of them is neutral. The picker was working;
## it was decorating a chair nobody sat in.
##
## So: an unoccupied Prop seat wears the picks of the human PERSON on its own
## team. 🧑 approved, 2026-07-30: *"yes let it inherit so that ppl cna choose
## what ai uses"* — which is the stronger reading of the feature, since the Prop
## on your team is the thing you are defending and throwing.
##
## ⚠️ NOT A SECOND BROADCAST PATH, and deliberately so — that is the U-8 bug
## class this project has already fixed twice. Nothing new goes on the wire: this
## resolves HOST-SIDE inside `_build_networked_character`, writing the same
## `can_index`/`slipper_index` that were already replicated properties with
## `spawn = true`. A client calling this gets -1 out of `picks_for` and is
## overwritten by the host's value on arrival, exactly as before.
##
## Returns all -1 when the team's Person seat is ALSO an AI (a fully-bot team has
## no human to inherit from) — the neutral fallback is still correct there, and
## that is the case its own doc in `character_roster.gd` was written for.
## ⚠️ A RECLAIMED BODY KEEPS THE PICKS IT WAS SPAWNED WITH UNLESS SOMEBODY SAYS
## OTHERWISE, AND THAT IS A SECOND NET-1 BUG — an older one, uncovered by fixing
## the first.
##
## `_rpc_reclaim_character` exists so that a peer arriving after
## `_fill_empty_slots_with_placeholders` steps into the AI's body rather than
## getting a fifth character. It rewires authority, name, player_id, camera and
## all the bookkeeping — but it never touched `character_index`/`can_index`/
## `slipper_index`, because `_build_networked_character` (the only place those
## were ever written) does not run for a body that already exists.
##
## Before NET-1 that was invisible: the placeholder held -1, the arriving human's
## pick was dropped, and the result was the neutral 3/3/3 — indistinguishable
## from the fallback working as intended, which is exactly how this survived.
## After NET-1 the placeholder holds the TEAMMATE's inherited picks, so the
## symptom became a real human visibly wearing somebody else's lata. Caught by
## the impossible-number rule on the first run of the fix: the client's own log
## printed `can=kape(3)` at startup and its unit reported `can_index=4`.
##
## ⚠️ HOST-ONLY, AND NO NEW MESSAGE. `peer_characters` is host-side (a client
## asking about anyone gets -1, and writing that would erase the right answer),
## and all three fields are replicated properties with `spawn = true` on
## `CharacterBase.tscn`, so the host writing them here is carried by the
## synchronizer that already exists. Inventing an RPC to push picks is the U-8
## bug class and is not needed.
##
## A peer with no pick of its own (a `--host`/`--join=` command-line session that
## never saw the CHARACTER screen) leaves the inherited value alone rather than
## stamping -1 over it — losing the teammate's pick to a peer that expressed no
## preference would be a downgrade, not a correction.
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

## ⚠️ `_team_prop_picks()` WAS DELETED HERE along with the prop seats it read.

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
## A seat IS a player slot now — there is no team/role packing left to undo.
static func _seat_of(slot: int) -> int:
	return slot

## Shared by _spawn_player (a real peer) and _fill_empty_slots_with_placeholders
## (an unfilled team/role slot, given a synthetic negative peer_id nothing
## real can ever match) — the two differ only in WHOSE peer_id ends up
## controlling the resulting character, not in how team/role/position are
## derived from `index`.
func _build_spawn_data(peer_id: int, index: int) -> Dictionary:
	# ⚠️ ONE SEAT PER PLAYER, NOT TWO PER TEAM. `index` used to be packed —
	# `index / 2` was the team and `index % 2` chose Person or Prop. Every seat is
	# a Person now, so the index IS the player slot and no unpacking survives.
	var slot := index
	var opening_defender := MatchManager.defender_slot_for(maxi(1, MatchManager.round_number))
	var is_defender := slot == opening_defender
	# Role index, not seat: the Defender takes mark 0 and the three Attackers take
	# 1..3, so a rotation moves people between marks rather than renumbering them.
	var role_index := 0
	if not is_defender:
		role_index = 1 + (slot if slot < opening_defender else slot - 1)
	# ⚠️ `player_id` IS THE INPUT-BINDING SEAT AND IT IS FIXED FOR THE MATCH — a
	# different question from where this round's fight starts (B-130). It used to
	# be `index % 2` plus an offset, which packed two players per team; it is the
	# slot now, for the same reason everything else here is.
	return {
		"peer_id": peer_id,
		"position": _role_spawn_point(role_index),
		"yaw": _role_spawn_yaw(role_index),
		"is_defender": is_defender,
		"player_slot": slot,
		"player_id": slot + 1,
		# ⚠️⚠️ THE NAME RIDES THE SPAWN PACKET, AND WITHOUT IT EVERY CLIENT WAS "P2".
		# 🧑 2026-08-02: *"only host has name, everyone else that joins is p1 p2 p3 etc"*.
		#
		# `_build_networked_character` used to read the name from
		# `NetworkManager.picks_for()`, and that runs ON EVERY PEER — but `peer_characters`
		# is HOST-ONLY state. A client's copy is empty by design (the same reason its copy
		# of the three character indices is empty), so on every client the lookup missed
		# for everybody and stamped `player_name = ""` on all four bodies. The host's own
		# screen was the only place the dictionary had anything in it, which is exactly the
		# shape of the report: one machine with names, every other machine with seat labels.
		#
		# It was healed afterwards by `_rpc_sync_picks`, which is why this was intermittent
		# rather than total — a broadcast racing a spawn, with the empty string winning
		# whenever the body arrived last.
		#
		# ⚠️ AND THIS IS THE FIX THIS FILE ALREADY WORKED OUT ONCE, for `character_index`:
		# see `_fill_empty_slots_with_placeholders()`. Put the value in the spawn packet and a peer
		# that joins, re-joins or arrives late gets it WITH the body, by the same mechanism
		# that gives it the body. Resolved here because this function only ever runs on the
		# host, which is the one place the answer is known.
		"name": SettingsManagerScript.sanitise_name(
			String(NetworkManager.picks_for(peer_id).get("name", ""))),
		# ⚠️⚠️ AND THE PERSON RIDES IT TOO, FOR EXACTLY THE REASON THE NAME DOES.
		# 🧑 2026-08-02: *"The player rejoins on a different player character and not the
		# same character they were on."*
		#
		# ⚠️ THE REJOIN WAS NEVER THE BROKEN HALF — THE FIRST SPAWN WAS. Measured on
		# `tools/net/run_rejoin.ps1`, three processes, twice, with the dropper picking
		# ALING NENA (11) and the anchor BEBANG (7):
		#
		#   the CLIENT, its own body, t=1..8s in Main:
		#       char=-1  model=character-female-f.glb  mat=person_b.tres
		#   the HOST, the SAME body, the SAME window:
		#       char=-1  model=character-female-e.glb  mat=person_aling-nena.tres
		#
		# Two facts in those four numbers. The host DID resolve the pick — its Visual
		# instanced ALING NENA at `_ready()` — and then lost it; the client NEVER had it
		# and was drawing `PERSON_MODELS`' fallback. `_build_networked_character` read the
		# Person out of `NetworkManager.picks_for()`, which is HOST-ONLY state (see its own
		# doc), so on the client it answered -1 and the body kept the scene default. The
		# client is then made the multiplayer authority for that body in the same function
		# — so its -1 replicated straight back over the host's 11 through the
		# `character_index` entry in `CharacterBase.tscn`'s SceneReplicationConfig.
		#
		# What that -1 cost is the whole bug: at the ready gate `_refresh_ai_prop_picks()`
		# reads it, and that function's `< 0` test is documented as *"THE WHOLE TEST FOR
		# THIS IS A BOT"* — so it dealt the two HUMAN seats faces out of `AI_PERSON_SPREAD`
		# and told their Visuals about it. Measured at the next tick: slot 0 became
		# 0/BERTO and slot 1 became 3/INDAY, which are precisely `AI_PERSON_SPREAD[0]` and
		# `[1]`. The players then played the entire match as somebody else, and
		# `_apply_reclaimed_picks` — which reads the host-side table and is correct —
		# handed the returning player their REAL pick back on the rejoin. Hence the
		# report: the fighter changes when you come back, because coming back is the only
		# path that ever applied your choice.
		#
		# So it is resolved here, host-side, where the answer is known, and carried by the
		# same packet that already carries the body. ⚠️ NO NEW MESSAGE AND NO `@rpc`
		# TOUCHED — this dictionary is the `MultiplayerSpawner`'s custom spawn payload,
		# not an RPC signature, so nothing about the deployed server's rpc checksum
		# changes. A peer reading an older build simply falls back to `picks` below and
		# behaves exactly as it does today.
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
	# ⚠️⚠️ THE BOTS ARE NAMED HERE, AT SPAWN, AND NOT ONLY AT THE READY GATE — 🧑
	# 2026-08-02: *"fix multiplayer names showing up pls"*, with a scoreboard reading
	# P1/P2/P3/P4 in a networked match while the same build named everyone correctly in
	# Single Player.
	#
	# A bot's name IS its `character_index` (`CharacterBase._character_name()`), and until
	# today the only place an AI seat was dealt one was `_rpc_begin_ready_countdown`. That
	# is late: it is after the lobby, after the scene change, after every peer has pressed
	# R — so for the whole of that window every bot on every screen answers the bare seat
	# label, and the scoreboard behind the ready prompt says P2 and P4 because that is
	# genuinely all it has been told.
	#
	# ⚠️ AND IT IS ALSO FRAGILE, WHICH IS THE HALF THAT PRODUCES "SOMETIMES". Dealing at
	# the ready gate means every client learns the names from ONE `_rpc_sync_picks`
	# broadcast plus an ON_CHANGE synchroniser update. Dealing them BEFORE the spawn puts
	# `character_index` in the spawn packet itself (`CharacterBase.tscn` marks it
	# `spawn = true`), so a client that joins, re-joins or arrives late gets the name with
	# the body, by the same mechanism that gives it the body. Single Player never had the
	# bug because `_build_local_roster` deals its bots inline — this makes the networked
	# path do what the working path already did.
	#
	# ⚠️ THE COLLISION IT RISKS IS HANDLED IN `_refresh_ai_prop_picks` ITSELF. No client has
	# identified yet at `_start_hosting()` time, so a bot dealt now can take the Person a
	# human picks thirty seconds later. That is exactly why the deal used to wait. The
	# dealer re-runs at the ready gate and now RELEASES any bot wearing a human's pick
	# before it fills the gaps — so the early deal is a good guess that gets corrected,
	# rather than a claim that sticks.
	if NetworkManager.is_host():
		_refresh_ai_prop_picks()

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
## ⚠️ `_prop_ability_for()` WAS DELETED HERE, along with `scripts/abilities/**`. It
## picked which `AbilityBase` a Prop carried this round from its skin and which
## side it was playing. There are no abilities and no Props.

## Runs on every peer (host and clients) when the spawner replicates a spawn.
func _build_networked_character(data: Dictionary) -> Node:
	var character: CharacterBase = CHARACTER_SCENE.instantiate()
	character.name = str(data["peer_id"])
	character.position = data["position"]
	# B-15/B-35: also where the KillPlane and a TAG send this player back to.
	character.spawn_position = data["position"]
	character.rotation = Vector3(0.0, float(data["yaw"]), 0.0)
	character.is_defender = data["is_defender"]
	character.player_slot = data["player_slot"]
	# B-30: was never assigned and stuck at the scene default of 1, so every
	# networked character read player one's bindings.
	character.player_id = data["player_id"]
	var picks := NetworkManager.picks_for(int(data["peer_id"]))
	# ⚠️⚠️ FROM THE SPAWN PACKET FIRST, `picks` ONLY AS THE FALLBACK — see
	# `_build_spawn_data`'s note for the measurement. This function runs on EVERY peer and
	# `picks_for()` is host-only, so reading the Person out of `picks` here answered -1 on
	# every client; the client is made the authority for its own body four lines below, and
	# `character_index` is a replicated property, so that -1 went back out over the host's
	# correct value and the ready gate's bot dealer then dressed the human as a bot.
	#
	# ⚠️ THE FALLBACK IS `picks`, NOT -1, for the same reason the name's is: a host running
	# an older build of this file sends no `character` key, and falling through to -1 would
	# throw away an answer the host DOES have on its own screen rather than degrade to the
	# previous behaviour.
	var person := int(data.get("character", picks.get("character", -1)))
	if person >= 0:
		character.character_index = person
	# ⚠️⚠️ FROM THE SPAWN PACKET, NOT FROM `picks` — see `_build_spawn_data`'s note. This
	# function runs on EVERY peer and `peer_characters` is host-only state, so the old
	# `picks.get("name")` read an empty dictionary on every machine except the host's and
	# every joiner came out as their bare seat label. `picks` is still right for
	# `character_index` above, because that one is ALSO carried in the replicated spawn
	# state (`CharacterBase.tscn` marks it `spawn = true`) and heals itself; the name is
	# not, so it has to be handed over explicitly.
	#
	# ⚠️ THE FALLBACK IS `picks`, NOT "". A host running a build of this file older than
	# the packet change would send no `name` key at all, and falling back to the empty
	# string would silently reintroduce the bug rather than degrade to the old behaviour.
	character.player_name = SettingsManagerScript.sanitise_name(
		String(data.get("name", picks.get("name", ""))))
	var peer_id: int = data["peer_id"]
	var is_ai := peer_id < 0
	character.set_multiplayer_authority(1 if is_ai else peer_id)
	_peer_slots[peer_id] = data["player_slot"]
	_spawned_characters[peer_id] = character
	var index: int = _seat_of(int(data["player_slot"]))
	_index_to_character[index] = character
	# ⚠️⚠️ THE SEAT TABLE IS FILLED HERE, AND UNTIL 2026-08-02 IT WAS ONLY EVER FILLED AT A
	# ROUND BOUNDARY. 🧑, minutes after the rejoin itself started working: *"no throw, no
	# getting pushed, no pickup"* — a returning player who could WALK and do nothing else.
	#
	# `RoundManager.register_player()` had exactly two call sites: `_build_local_roster()`
	# (Single Player) and `_reset_world()`, which runs off `MatchManager.round_started`. A
	# peer that arrives DURING a round — a rejoiner, or any mid-match joiner — misses that
	# signal by definition, so its `RoundManager._players` stayed `[null, null, null, null]`
	# until the next round boundary healed it. Measured on `tools/net/run_rejoin.ps1`:
	# `rm_seats=[0=<null>, 1=<null>, 2=<null>, 3=<null>]` on the returning peer against
	# `rm_seats=[0=350085074, 1=-2, 2=-3, 3=-4]` on the anchor in the same match, on the
	# same frame. That one dictionary is every symptom in the report:
	#
	#   · NOT BEING PUSHED. A shove, a body block and a tag penalty are all decided on the
	#     host and arrive as `RoundManager._sync_shove/_sync_block/_sync_tag_penalty`, which
	#     resolve the victim with `player_at(slot)` — see that file's § THE MULTIPLAYER
	#     SOFTLOCK for why they are addressed by SLOT and not by node path. `player_at`
	#     returning null makes every one of them a silent no-op, and because the returning
	#     player is the AUTHORITY for their own body, the synchroniser then replicates the
	#     un-shoved position back out. Nobody, anywhere, sees them get pushed.
	#   · NO PICKUP. `Slipper._apply_grabbed()` runs on every peer and resolves the hand
	#     the same way. Null carrier means `notify_holding()` never fires, so the returning
	#     player's own `Carrier` still believes their hands are empty.
	#   · NO THROW. `Carrier._step_throw()` returns immediately while `_held` is null, so a
	#     hand that never heard about the pickup can never charge a throw either.
	#
	# WALKING KEPT WORKING because it is the one verb that asks nothing of this table:
	# `_physics_process` reads the keyboard and calls `move_and_slide()`. That is the whole
	# reason the report reads as "everything except movement".
	#
	# ⚠️ DONE AT SPAWN, WHICH IS THE RULE THIS FILE ALREADY STATES ELSEWHERE. The name in
	# the spawn packet is justified as *"a peer that joins, re-joins or arrives late gets it
	# WITH the body, by the same mechanism that gives it the body"* — the seat table is the
	# same kind of fact and now arrives the same way. `_reset_world()` still clears and
	# rebuilds the whole table every round, so this cannot drift from it; it only closes the
	# window before the first round boundary the joiner ever sees.
	RoundManager.register_player(character)
	_apply_known_picks(character, index)
	if _pending_reclaims.has(index):
		var reclaim_peer: int = _pending_reclaims[index]
		_pending_reclaims.erase(index)
		_apply_reclaim.call_deferred(character, index, reclaim_peer)
	character.is_bot = is_ai
	if is_ai and NetworkManager.is_host():
		_attach_ai(character)
	# Follow targets for the spectator's `Tab`.
	character.add_to_group("spectatable")
	return character

## ⚠️ SIGNATURE FOLLOWS `MatchManager.round_started`, WHICH NOW NAMES A SLOT
## RATHER THAN A SIDE. A bool could describe a 2v2; it cannot name one of four.
func _on_match_round_started(_round_number: int, defender_slot: int) -> void:
	# ⚠️ FIRST, AND IT IS THE REMATCH CASE. `MatchManager.round_started` is what a carried
	# rematch vote ends up firing (`match_result.gd::_begin_rematch_now` → `begin_next_round`),
	# and it is the ONLY signal both a rematch and an ordinary round transition go through —
	# which is exactly why `match_result.gd` hangs its own "hide the scoreboard" off it. A
	# dedicated referee that is refereeing again must drop the window it armed at the last
	# whistle, or it would close a room in the middle of the match that vote just started.
	_disarm_post_match_reset()
	_reset_world(defender_slot)
	RoundManager.start_round()
	# ⚠⚠ THE SLIPPER GOES INTO THE HAND HERE, NOT IN `_reset_slippers()`.
	# 2026-08-01, on human instruction: *"At the beginning of each round,
	# automatically equip each player's personal slipper in their hand. This should
	# eliminate the need for players to manually pick it up at the start of the
	# round."*
	#
	# ⚠️ DEFERRED BY A FRAME, DELIBERATELY. `RoundManager.start_round()` above has
	# just called `reset_for_new_round()` on every character, which re-runs
	# `character_visual.gd::apply()` — and that REBUILDS the `HandAttachment` a
	# carried slipper reparents onto. Handing a slipper over on the same frame is
	# §2.24's reparent-vs-reset race, and forcing it there produced a whole match
	# with 0 throws and every attacker frozen in FETCH.
	_equip_owned_slippers.call_deferred()


## Puts each attacker's own slipper in their hand, host-side. Idempotent: a
## slipper already carried by its owner is left alone.
##
## ⚠️ IT ASKS THE SAME OWNERSHIP RULE EVERYTHING ELSE DOES (`Design.md` §5.2) via
## `Slipper.host_force_equip()`, which keeps the two gates that are about the RULES
## — a defender never holds one, nobody holds somebody else's — and drops only the
## `can_act()` timing gate, which is what made the old courtesy pickup a coin flip.
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

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE ROLE ROTATION HAPPENS HERE AND NOWHERE ELSE. Everything downstream —
## the confinement clamp, the throw gate, the tag, the passive score, the HUD's
## defender marker — reads `is_defender`, and this is the only function that
## writes it. One writer, so four machines cannot end a round disagreeing about
## who was defending it.
## ---------------------------------------------------------------------------
func _reset_world(defender_slot: int) -> void:
	for node in get_tree().get_nodes_in_group("hazard_zone"):
		if is_instance_valid(node):
			node.queue_free()

	var roster := _all_characters()
	RoundManager.clear_players()

	# ⚠️ PARK EVERYONE OFF THE MAP FIRST, THEN PLACE THEM. Roles rotate, so seats
	# trade marks — and placing player B on a mark player A has not left yet is
	# exactly the stacked-collider case `SPAWN_SETTLE_FRAMES` exists for. Lifting
	# them out of each other's way first means the settle only has to absorb the
	# world geometry, not each other.
	for i in range(roster.size()):
		roster[i].position = Vector3(0.0, 500.0 + i * 20.0, 0.0)

	# Attackers take marks 1..3 in seat order, which is stable across a match, so
	# the same seat does not draw the same corner every round it attacks.
	var attacker_index := 0
	for character in roster:
		character.is_defender = character.player_slot == defender_slot
		var role_index := 0
		if not character.is_defender:
			attacker_index += 1
			role_index = attacker_index
		character.reset_for_new_round()
		_place_at_spawn(character, role_index)
		# B-15/B-35: the Safe Zone mark is also where a TAG sends this player back
		# to, so it has to be re-captured every round rather than being whatever the
		# scene file said at load.
		character.spawn_position = character.position
		RoundManager.register_player(character)

	RoundManager.lata = lata
	if lata != null:
		lata.host_reset_for_new_round()

	_reset_slippers(roster, defender_slot)
	_push_prop_skins(defender_slot)

## ---------------------------------------------------------------------------
## ⚠️⚠️ REWRITTEN 2026-08-01, ON DIRECT HUMAN INSTRUCTION — EVERY SEAT NOW OWNS
## ITS OWN LATA AND TSINELAS, NOT ONE SHARED PAIR.
##
## This used to broadcast ONE can pick and ONE slipper pick for the whole
## match, read once from `GameLaunch` — the local peer's own preference,
## applied to everybody. That was the documented design (`Design.md` §9: "the
## host's pick is the one that wins") and it is now wrong on purpose: 🧑,
## *"allow bots in single player to have random cans and random slippers,
## their respective cans show when theyre defender, let my respective can
## show when im defender as well."*
##
## THE LATA NOW SHOWS THE CURRENT DEFENDER'S OWN CAN, RE-APPLIED EVERY ROUND.
## Every seat has its own can + slipper pick — a real player's own CHARACTER-
## screen choice (already crossing the wire in `NetworkManager.peer_characters`
## as `"can"`/`"slipper"`, unused by anything until now) or, for a bot, a
## host-rolled random pick from `_refresh_seat_prop_picks()`. Since only ONE
## lata exists in the arena, it wears whichever seat currently defends —
## looked up here rather than stored on `CharacterBase`, which this lane does
## not own and does not need to touch for this.
## ---------------------------------------------------------------------------
func _push_prop_skins(defender_slot: int) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var can_pick := int(_seat_prop_picks.get(defender_slot, {}).get("can", -1))
	# Each slipper already knows its own owner by the time this runs —
	# `_reset_slippers()` (called immediately above, same host-only branch)
	# assigns `owner_slot` synchronously on the host's own instances, so
	# reading it back here needs no extra bookkeeping. Keyed by NAME rather
	# than by owner slot on the wire, so a client applies the right skin to
	# the right node without having to already agree on ownership timing.
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

## ---------------------------------------------------------------------------
## Host-only. Deals a can + slipper pick to every seat that does not have one
## yet — a real player's own CHARACTER-screen pick if one is reachable, a
## random one otherwise. Same idempotency and same call sites as
## `_refresh_ai_prop_picks()`, and deliberately a separate pass rather than
## folded into it: that function's whole test for "is this a bot" is
## `character_index < 0`, which says nothing about whether a can/slipper pick
## is reachable for a human seat that HASN'T been resolved yet (mid-connect).
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
		if _seat_prop_picks.has(slot) or seats.get(slot) == null:
			continue
		var human_picks: Variant = _human_prop_picks_for_slot(slot)
		if human_picks != null:
			_seat_prop_picks[slot] = human_picks
			continue
		var can := _ai_prop_index(CharacterRoster.CANS.size(), taken_cans)
		var slipper := _ai_prop_index(CharacterRoster.SLIPPERS.size(), taken_slippers)
		taken_cans.append(can)
		taken_slippers.append(slipper)
		_seat_prop_picks[slot] = {"can": can, "slipper": slipper}

## A human's own pick for `slot`, or null if `slot` is not a human seat (an
## unfilled AI slot, in either mode). Solo test has no peer_id to look up —
## the human IS `GameLaunch.solo_seat`, read straight from the same place the
## CHARACTER screen wrote it.
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

## Random, favouring a roster entry no other bot this match already wears —
## §5.16's `AI_PERSON_SPREAD` is a fixed quartering because faces have to stay
## apart from HUMAN picks too; a can or a slipper has no such collision to
## avoid, so true randomness is what was actually asked for.
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

## Every Attacker starts a round holding a slipper, so the first throw does not
## need a retrieval run in front of it. The Defender holds nothing — they have
## never been able to throw and now the rules say so.
##
## ⚠️ THE HAND-OVER IS HOST-ONLY AND IT HAS TO BE. `host_grab()` refuses on a
## client, so calling this everywhere is harmless — but the RPC it fans out is what
## actually puts the slipper in the right hand on the other three machines.
func _reset_slippers(roster: Array[CharacterBase], defender_slot: int) -> void:
	for slipper in slippers:
		if is_instance_valid(slipper):
			slipper.host_reset_for_new_round()
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	# ⚠️⚠️ OWNERSHIP IS ASSIGNED HERE, EXPLICITLY, AND NO LONGER RIDES ON THE GRAB
	# BELOW SUCCEEDING. `Slipper.owner_slot` was only ever written by
	# `_apply_grabbed()`/`_apply_thrown()`, so it depended entirely on this
	# courtesy pickup landing — and `host_grab()` can silently refuse, because
	# `can_be_grabbed_by()` requires `can_act()`, which is
	# `round_active and state == NORMAL`, and a character mid-reset is neither.
	# Measured: one of three slippers left LOOSE at its own player's feet with
	# `owner_slot = -1`. See `slipper.gd::can_be_grabbed_by()` for what reads the
	# field and how each of them fails on -1.
	#
	# ⚠️ SEATS IN NUMERIC ORDER, NOT `roster` ORDER. `roster` is built per session
	# and its order is not a promise; the slipper-to-seat mapping has to be the
	# same on every peer and the same every round, or the foot arrow points at
	# somebody else's slipper on one machine.
	var attackers: Array[int] = []
	for slot in range(NetworkManagerScript.MAX_PLAYERS):
		if slot != defender_slot:
			attackers.append(slot)
	for index in range(slippers.size()):
		var slipper := slippers[index]
		if not is_instance_valid(slipper):
			continue
		# A slipper with no attacker to own it (a short-handed match) is explicitly
		# disowned rather than left holding last round's slot — a stale owner is
		# worse than none, because the gate would refuse everybody.
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
		# Park it on the attacker before handing it over, so the pickup radius test
		# inside `host_grab()` cannot miss by one frame of interpolation.
		#
		# ⚠⚠ THIS STAYS A COURTESY GRAB, AND FORCING IT HERE BROKE THE GAME OUTRIGHT.
		# The obvious way to deliver *"automatically equip each player's personal
		# slipper"* was to bypass `can_be_grabbed_by()`'s `can_act()` gate right here.
		# Measured result: **0 throws, 0 knockdowns, three bots stuck in FETCH for a
		# whole match, DEFENSE 100% of every point.** Forcing the equip mid-reset
		# reparents the slipper onto a `HandAttachment` that
		# `character_visual.gd::apply()` is REBUILDING on the same frame — which is
		# §2.24, already filed, already measured on two peers.
		#
		# The refusal was accidentally protecting against that race. The equip now
		# happens at ROUND START instead (`_equip_owned_slippers()`), where the
		# visuals are built, the players are registered and `can_act()` is true — so
		# the preconditions this call could never satisfy are simply all met.
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
	# THE MATCH WAS WON — the second of the two ways a dedicated lobby comes back. Armed
	# rather than done, because the result screen still owns a live rematch vote; see
	# § BACK TO THE WAITING ROOM for why this one has a grace window and the other does not.
	_arm_post_match_reset()

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

## ---------------------------------------------------------------------------
## ⚠️⚠️ WHO IS HOLDING WHAT, FOR ONE JOINING PEER. THE OTHER HALF OF "no throw, no
## pickup" (2026-08-02).
##
## `Slipper.tscn`'s `SceneReplicationConfig` replicates `position` and `owner_slot` and
## NOTHING ELSE — `state` and `carrier` are driven purely by the `_rpc_slipper_*`
## broadcasts below, which is correct while everyone is present and silent about
## everyone who was not. So a peer arriving mid-round starts with every slipper LOOSE at
## its default, including one that has been in its own seat's hand since the round-start
## auto-equip. `Slipper.can_be_grabbed_by()` requires `state == LOOSE` HOST-side, so that
## player cannot pick their slipper up (the host says it is already held) and cannot
## throw it either (`Carrier._held` is null on their machine). That is a seat with no
## offence at all until the next round boundary rebuilds the world.
##
## ⚠️ IT REPLAYS EXISTING RPCs RATHER THAN DEFINING A NEW ONE, AND THAT IS DELIBERATE
## RATHER THAN THRIFTY. Godot checksums a node's RPC method list; adding a method to this
## script makes every already-deployed dedicated server disagree with every new client and
## fail the handshake with "the rpc node checksum failed". `_rpc_slipper_grabbed` already
## says exactly what needs saying, and `rpc_id` aims it at the one peer that missed it.
##
## ⚠️ ONLY THE CARRIED ONES. A LOOSE slipper already arrives correct (the synchroniser
## carries its position, and LOOSE is the local default), and a slipper in FLIGHT
## corrects itself the moment it lands, because `_rpc_slipper_landed` is a broadcast the
## new peer is now part of. Sending those two would be two more chances to be wrong.
##
## ⚠️⚠️ THAT PARAGRAPH IS NOW MEASURED RATHER THAN ARGUED, 2026-08-04, AND A LOOSE
## CATCH-UP BROADCAST WAS INVESTIGATED AND IS NOT NEEDED. 🧑: *"upon rejoining i dont have
## a slipper, only until the next round/roles rotation."* The obvious reading is that this
## function replays only CARRIED slippers, so a slipper the stand-in bot had THROWN would
## reach the returning peer as nothing at all. It does not: `tools/net/run_rejoin.ps1` now
## prints each slipper's `global_position` beside its owner/state/carrier on all three
## processes, and the three logs are identical at the instant of return. Three runs, three
## different game states, referee · anchor · dropper:
##
##     thrown, lying loose   s0(owner=1 state=0 carrier=<null> at=-1.34,0.14,1.52)  ×3 peers
##     taken by a rival bot  s0(owner=2 state=1 carrier=-3)   s2(owner=3 state=0
##                           carrier=<null> at=-0.82,0.13,-0.31)                    ×3 peers
##
## The LOOSE positions agree to 2 dp on every peer — the synchroniser's `position` really
## does heal a joiner, exactly as claimed — and the second run also proves the CARRIED half
## of this function on the REJOIN path specifically (two slippers in bot hands, both
## arriving with the right `state` and the right `carrier`). In every run the returning peer
## then picked its slipper up on one `E` press and the host agreed.
##
## SO "I COME BACK EMPTY-HANDED" IS GAME STATE, NOT A REPLICATION HOLE. The seat was
## bot-driven for ~17 s and a bot with a tsinelas throws it within seconds; the slipper is
## on the floor, or in a rival's hand under the open-pickup rule, and either way the player
## has to go and fetch it. Adding a LOOSE catch-up here would replay a state the joiner
## already has. If this is to be softened it is a DESIGN change (re-equip on reclaim), and
## note that it hands anyone who alt-F4s a free teleport of their slipper into their hand.
##
## ⚠️ THE RECEIVER MAY NOT HAVE THE BODY YET. The bodies come from `MultiplayerSpawner`
## and this comes from the reliable RPC channel, with no ordering between them — see
## `Slipper._pending_carrier_slot`, which is what makes the losing order resolve instead
## of stranding the slipper.
## ---------------------------------------------------------------------------
func _sync_slipper_carry_to_late_joiner(peer_id: int) -> void:
	for index in range(slippers.size()):
		var slipper := slippers[index]
		if not is_instance_valid(slipper) or slipper.state != Slipper.CarryState.CARRIED:
			continue
		# The hand, not `owner_slot`: `_apply_grabbed()` writes ownership FROM the grab,
		# so the two agree today — but reading the fact this message is actually about
		# means they cannot silently stop agreeing.
		var holder := slipper.carrier
		if holder == null or not is_instance_valid(holder):
			continue
		_rpc_slipper_grabbed.rpc_id(peer_id, index, holder.player_slot)

## Q-2/B-63: shared by _sync_state_to_late_joiner (a joining peer needs to know
## about every already-spawned Can) and _on_player_disconnected (a leaving Can
## must stop being tracked, not leave RoundManager holding a freed reference —
## its own is_instance_valid() guard would otherwise just silently no-op
## forever and the round could then only ever end on the timer).
## ⚠️ `_reregister_tracked_cans()` WAS DELETED HERE. It re-registered whichever
## Prop was playing the lata after a late join. There is one lata, it is a world
## object, and `_sync_state_to_late_joiner` hands it over directly.

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
## ⚠️ NOW WIRED TO THE LATA, NOT TO A PLAYER. This used to hook whichever Prop was
## playing the can this round, and its own note recorded the trouble that caused:
## the `is_can` test had to live INSIDE the callback because the flag flipped every
## round. There is one lata, it never changes identity, and it is not a player — so
## the hook is a single connection made once.
##
## ⚠️ A `dents_changed` HOOK DRIVING `hud.set_dents()` WAS ALSO HERE. The signal,
## the field and the mode are all gone (`Design.md` §Removed).
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
		# ⚠️ ANNOUNCE BEFORE CLOSING, AND `await` IT. Human report: quitting politely
		# stranded every client for ~5 s, because a closed socket and a silent one are
		# the same thing to ENet and both cost `ENET_TIMEOUT_MIN`. The announcement is
		# what tells them; the await is what lets the packet actually leave before the
		# socket goes. See `NetworkManager.announce_host_leaving()`.
		#
		# A CLIENT quitting needs none of this — the host learns about it from
		# `peer_disconnected`, which fires on a clean close immediately.
		if NetworkManager.is_host():
			await NetworkManager.announce_host_leaving()
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
	_bail_to_browser("Host ended the match.")

## Q-1/B-62: a Join to a dead/unreachable address previously left the player on
## a black Main.tscn forever — the same soft-lock as a mid-match host quit,
## just triggered before anyone ever connected. Same teardown, different message.
func _on_connection_failed() -> void:
	_bail_to_browser("Could not reach that host.")

## ---------------------------------------------------------------------------
## The one way out of a match that has stopped being a match. Three callers, one
## teardown: the host went away, the connection failed, or (B-153) the address this
## scene was handed could not be dialled at all.
##
## ⚠️ THE THIRD CALLER IS THE REASON THIS IS A FUNCTION. The two handlers above had
## identical bodies differing only in the message, and `_start_joining` needed the same
## teardown for a THIRD reason — so the choice was a third copy or one function. A copy
## that fell behind would strand a player exactly as thoroughly as having no teardown at
## all, which is precisely the failure B-153 turned out to be.
##
## MultiplayerSetup, not the title screen: it owns the status message and it is where
## somebody in this position would rejoin or re-host from.
## ---------------------------------------------------------------------------
func _bail_to_browser(message: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MatchManager.reset()
	RoundManager.reset()
	GameLaunch.reset()
	GameLaunch.pending_status_message = message
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
			_peer_slots.erase(old_peer_id)
			_spawned_peer_ids.erase(old_peer_id)
			break
	var sentinel_peer_id := -1 - index
	character.name = str(sentinel_peer_id)
	character.set_multiplayer_authority(1) # host runs AI-driven physics — see _build_networked_character
	character.player_id = index + 1
	_spawned_characters[sentinel_peer_id] = character
	_peer_slots[sentinel_peer_id] = character.player_slot
	_spawned_peer_ids[sentinel_peer_id] = true
	# ⚠️ SET ON EVERY PEER, UNLIKE THE CONTROLLER BELOW. `_attach_ai` is host-only
	# because the host runs AI physics; the NAME this seat draws is not a host concern
	# and must be identical on every screen, a spectator's included. See
	# `CharacterBase.is_bot`.
	character.is_bot = true
	if NetworkManager.is_host() and character.ai_controller == null:
		_attach_ai(character)
	# The departing peer's own machine is gone, so this is really about the OTHER
	# peers: a character that just became AI must stop being anybody's camera.
	# See _refresh_rig_ownership.
	_refresh_rig_ownership(character)

## Host → all peers (2026-07-28): hands `index`'s existing, still-standing
## character over to `new_peer_id` instead of spawning a second body for the
## same slot. Runs identically on every peer (call_local, like every other
## bookkeeping RPC here) since _spawned_characters/_peer_slots/_peer_is_person
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
		# ⚠️⚠️ THIS EARLY RETURN WAS THE BLANK SCREEN ON REJOIN. 🧑 2026-07-31:
		# *"blank screen when rejoining sa ongoing na match."*
		#
		# A REJOINING PEER HAS A FRESHLY LOADED `Main.tscn`, so its own
		# `_index_to_character` is EMPTY — the four characters reach it as
		# `MultiplayerSpawner` deliveries, and this reliable RPC races them. When it
		# lost that race the function returned silently and NOTHING else ever retried:
		# no authority migration, no `_refresh_rig_ownership()`, so no rig ever became
		# current and the rejoiner sat looking at whatever the engine fell back to.
		# The bookkeeping that makes rejoin work at all (B-65's token-keyed seat) had
		# already succeeded, which is exactly why this looked like "the match is gone"
		# rather than like a seating bug.
		#
		# ⚠️ THE FIX IS THE ONE THIS FILE ALREADY LEARNED ONCE. `_rpc_sync_picks` hit
		# the identical race and its note states the rule: *"a unit that has not
		# arrived yet can be answered when it does — the spawn order and this message
		# have no guaranteed relationship, and assuming one is how the first version
		# of this dropped the seat that arrived a frame late."* It remembers in
		# `_known_picks` and re-applies from the spawn path. This now does the same
		# through `_pending_reclaims`, so both orderings resolve.
		_pending_reclaims[index] = new_peer_id
		return
	_apply_reclaim(character, index, new_peer_id)

## ---------------------------------------------------------------------------
## ⚠️⚠️ SLIPPER RPCs ARE ROUTED THROUGH MAIN, NOT CALLED ON THE SLIPPER ITSELF.
## THIS IS THE FIX FOR "non-host players and spectators cannot see thrown
## slippers — only the host renders them."
##
## `slipper.gd`'s `_attach_to_hand()`/`_detach_from_hand()` reparent a slipper
## onto a per-peer, runtime-built path under its carrier's hand
## (`Skeleton3D/HandAttachment/HandPoint`) and back again on every pickup and
## throw — see `_attach_to_hand()`'s own §2.24 doc. That doc already diagnosed
## and fixed this exact "packets naming a node the receiver may not have
## finished constructing" problem for the automatic `MultiplayerSynchronizer`
## (silenced via `_set_sync_enabled` while carried), but `slipper.gd`'s five
## explicit `@rpc` methods (`_rpc_owner`, `_rpc_grabbed`, `_rpc_thrown`,
## `_rpc_landed`, `_rpc_deflected`) used the exact same node-path-based RPC
## targeting under the hood and were never covered by that fix.
##
## Measured live, not assumed: a real host + join test, 46 seconds, the host
## AI cycling through 20+ throw/catch loops — the join client received the
## very first round-start equip (sent while every slipper was still at its
## original, since-scene-load path) and NOTHING else for the rest of the
## match. Every slipper stayed frozen mid-air in its carrier's hand on the
## client's screen, exactly matching the bug report.
##
## Main.tscn's own root never reparents, so routing every slipper mutation
## through it and re-dispatching by `slipper_index` (a plain int, immune to
## path instability — see that var's own doc on `Slipper`) sidesteps the
## problem instead of patching around it path-by-path.
## ---------------------------------------------------------------------------

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

## `audible` defaults so a caller that never needs the sound (a round reset
## teleporting three slippers home on one frame — see `_apply_landed`'s own
## doc) can omit it, same contract the old per-node RPC kept.
@rpc("authority", "call_local", "reliable")
func _rpc_slipper_landed(slipper_index: int, where: Vector3, audible: bool = false) -> void:
	if slipper_index < 0 or slipper_index >= slippers.size():
		return
	slippers[slipper_index]._apply_landed(where, audible)

@rpc("authority", "call_local", "reliable")
func _rpc_slipper_deflected(slipper_index: int, from: Vector3, new_velocity: Vector3) -> void:
	if slipper_index < 0 or slipper_index >= slippers.size():
		return
	slippers[slipper_index]._apply_deflected(from, new_velocity)

## The reclaim itself, split out so the spawn path can run it for a character that
## arrived AFTER the RPC did. See `_rpc_reclaim_character`'s note.
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
	# ⚠️ BEFORE set_multiplayer_authority — see _apply_reclaimed_picks. Writing a
	# replicated property on a node this peer has just STOPPED owning is a write
	# the new authority immediately overwrites with its own stale copy.
	_apply_reclaimed_picks(character, new_peer_id)
	character.set_multiplayer_authority(new_peer_id)
	character.player_id = index + 1
	_spawned_characters[new_peer_id] = character
	_peer_slots[new_peer_id] = character.player_slot
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
