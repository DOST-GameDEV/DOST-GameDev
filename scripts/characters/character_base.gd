extends CharacterBody3D
class_name CharacterBase

## Shared controller for every unit — both the human Person and the Can/Slipper
## Prop (see `is_person`/`is_can` below). A team is 2 players: 1 Person + 1 Prop,
## not two Props. Each of the 6 roster Props = this scene + a different
## AbilityBase resource plugged into `ability`; every Person shares one
## Tag/Throw ability (see person_action.gd).
## Stock/Downed round-win logic is NOT here on purpose (see Section 3 of the GDD) —
## it lives in its own decoupled system so Option A vs Option B can be swapped freely.

const SPEED: float = 6.0
## B-12: deceleration when there's no movement input, in units/sec² — separate
## from SPEED because the old code reused SPEED itself as a per-tick
## move_toward() step with no `delta`, which was an effectively-instant stop
## every physics tick regardless of framerate (no momentum), and made a
## velocity boost like Flick Dash's decay away in about 3 frames instead of
## actually covering distance.
const FRICTION: float = 30.0
const GRAVITY: float = 20.0
## Fastest a unit may ever fall. See the block in _physics_process that applies
## it — this is a collision-correctness bound derived from the map floor's own
## 1-unit thickness, not a feel number, and lowering it further would start to be
## visible on a genuine fall off the arena.
const MAX_FALL_SPEED: float = 26.0
## Playtest 0.4 — jump. Apex = JUMP_VELOCITY^2 / (2 * GRAVITY) = 0.841 units.
## See the block in _physics_process for why that ceiling is a MAP constraint
## rather than a feel one: the interior clutter height law caps what a jump may
## clear at 1.0, or every crate in the alley becomes a platform.
const JUMP_VELOCITY: float = 5.8
## 4.1. Minimum downward speed, in units/sec, for a floor contact to be worth a
## landing sound — see the block in _physics_process for why a bare floor-edge
## test is not enough on a map paved with abutting collision shapes.
const LAND_SFX_MIN_SPEED: float = 2.0
const BUMP_STAGGER_TIME: float = 0.25
## GDD Section 3, Option B: the window to self-right before a Downed Can
## auto-seals (see the DOWNED case in _physics_process). Kept here (not in
## RoundManager) because it's shared by both Option A and Option B, and by
## abilities like Quick Stand / Shatter Trap that reference "Downed" directly —
## see docs/Dev_Plan.md Section 4.
##
## ⚠️ CUT 2.0 -> 1.25 ON THE HUMAN'S CALL: *"adjust the difficulty to make it
## fairer; currently it is too easy for the can (lata) to get back up."* This is
## the FIRST of the four levers that decide that, and they are worth reading
## together because no one of them is the answer on its own:
##
##   1. THIS — how long a knocked-over lata may take to right ITSELF. Two seconds
##      is longer than the whole retrieval scramble the attacker has to survive to
##      throw again, so under Option B a fall was very nearly free.
##   2. `LUCKY_FALL_CHANCE` — how often a knockdown costs the attacker its whole
##      throw for nothing. 0.25 -> 0.12.
##   3. `Carrier.RESET_CHANNEL_TIME` — how long the taya must stand still to pick
##      the lata up. 1.5 -> 2.2, so committing to a reset is a real window the
##      attacker can punish rather than a formality.
##   4. `RoundManager.FALL_LIMIT` — the backstop. 5 -> 4.
##
## Together these move "the can gets back up" from the default outcome to a play
## the defence has to earn. ⚠️ NONE OF IT IS MEASURED AGAINST A HUMAN. The Phase 9
## fairness log measures AI-vs-AI only, and these are the numbers it should be
## re-run against first.
const DOWNED_SELF_RIGHT_WINDOW: float = 1.25
## THE LUCKY FALL. Human request, 2026-07-29: *"make it easier to fall, but
## sometimes make it so that it can land on its head/back and this isnt a point
## for the enemy."*
##
## How often a knockdown on a Can lands it on its head or its back instead of
## properly over — it visibly falls, and it costs the attacking side nothing.
##
## ⚠️ ROLLED ON THE HOST ONLY, in `hitbox.gd`, where `kind` is already decided and
## where the code is already past the host gate. The result rides the existing
## `_apply_hit_result` RPC as its own kind. It must NEVER be rolled inside
## `_apply_hit_result` itself — that function runs per-peer, so a `randf()` there
## would have different peers disagree about whether the round just changed hands.
##
## ⚠️ 0.25 -> 0.12, second of the four "too easy for the lata to get back up"
## levers — see DOWNED_SELF_RIGHT_WINDOW for the full set. A lucky fall costs the
## attacking side an entire throw AND the retrieval scramble that follows it, so
## at one in four it was the single most common way a clean hit produced nothing.
## One in eight keeps the joke (the can wobbling up off its own lid is the point)
## without it being a routine outcome.
##
## ⚠️ STILL NOT A MEASUREMENT. "Sometimes" is not a number and nobody has played
## it. It is the difficulty knob for the whole defensive half of Option B and
## belongs in the fairness tiers (Checklist Phase 9, item 6).
const LUCKY_FALL_CHANCE: float = 0.12
## User feedback, 2026-07-28: "team can shouldnt be allowed to go outside of a
## box/line when game starts." Confines the Can and its Taya (defending
## Person) to this radius around the map's base circle (world origin — every
## map's base_circle_decal sits at its own local (0,0,0), and $Map carries no
## transform, so world origin IS the base circle centre) for the whole round.
## Sized to give the Taya room to body-block an incoming throw without being
## able to chase the attacker back to the throwing line — see Art_Direction.md
## §9 for why the line sits 6 units out.
## ⚠️ RAISED 3.0 -> 5.0, same day, after the first playtest: "the box that
## defend can move in is so small. he can barely move, theres no room for
## outplays." Still a full unit short of the 6.0 throwing line, so the Taya
## still cannot reach the attacker's line — same design constraint as before,
## just more room inside it.
##
## ⚠️ THIS IS THE SINGLE SOURCE OF TRUTH, AND THE MAP BUILDERS NOW READ IT.
## `tools/maps/build_eskinita.py` and `build_bayan_plaza.py` used to each declare
## their own `CONFINEMENT_BOX_RADIUS = 5.0` with a "keep the two in sync" comment
## — one number written out in three files, kept aligned by hand. Both now parse
## this line out of this file (see `read_confinement_radius()` in either builder)
## and abort the build if they cannot find it, so a retune here cannot silently
## leave the chalk on the floor describing a boundary that no longer exists.
##
## The boundary is a chalk-style SQUARE at |x| = |z| = this value; a ring was
## tried first and replaced the same day ("the circle you made was ugly ... can
## we just use a square"). `_move_and_confine()` clamps X and Z independently to
## match it — see its own note for the 2.07-unit corner lie that came of those
## two disagreeing about their shape.
##
## Still a first guess, not a measurement; needs a human to actually play it.
const CONFINEMENT_RADIUS: float = 5.0
## ⚠️ R-21. The live value every gameplay read goes through, promoted so
## `tools/ai_probe.gd` can sweep the box size (`confine=`) without editing this file —
## the same shape R-01 used for `TAYA_BLOCK_STANDOFF`, and for the same reason: a
## constant with no probe argument is a constant nobody measures.
##
## ⚠️⚠️ THE `const` ABOVE MUST STAY, AND MUST STAY IN THAT EXACT SYNTAX.
## `tools/maps/floorcheck.py` reads the box size by regexing
## `^const CONFINEMENT_RADIUS: float = ...` out of this file, and BOTH map builders draw
## the chalk from it. Delete or reshape the const and every map build aborts.
##
## ⚠️ CHANGING THIS AT RUNTIME MOVES THE PHYSICS BOX AND NOT THE PAINTED ONE. A shipped
## value must be set on the `const` and the maps rebuilt; `confine=` is for measuring
## sensitivity only, and `ai_probe` refuses to call such a run a fairness measurement.
static var confinement_radius: float = CONFINEMENT_RADIUS
## Bump is "no cooldown" per the GDD but still needs an active window so standing
## next to an opponent doesn't stagger them every physics tick — press-to-bump,
## briefly live, matches "light melee" better than always-on contact damage.
const BUMP_ACTIVE_TIME: float = 0.15
## Option A (GDD Section 3, "Stock/Life"): a Can's health bar. Slippers win the
## round once a tracked Can reaches this many dents — see RoundManager
## _on_tracked_can_dents_changed. Only ever meaningful for a Can (is_can true);
## Persons and Slippers never accumulate dents. 3 per user decision (Session 7).
const MAX_DENTS: int = 3

## B-16: GDD Section 4 shared basic — "Guard/Dash (Cans block, Tsinelas
## dash-evade)" — for Props only; Persons don't get this (their assist/support
## slot is Tag/Throw, see person_action.gd). Which half a Prop gets depends on
## `is_can` this round, same as every other Can/Tsinelas-side split.
## Guard: hold to block. A stamina meter (not an unlimited hold) so it can't be
## held forever — drains while held, regenerates while released.
## ⚠️ TRIMMED 3.0/0.6 -> 2.0/0.45 alongside the four levers on
## DOWNED_SELF_RIGHT_WINDOW, and for the same reason: Guard blocks a dent and a
## stagger OUTRIGHT (see apply_dent/apply_stagger), so three seconds of hold with
## a fast refill let a lata simply hold the button through the only window an
## attacker gets per throw. Two seconds is still more than one throw's flight time
## — a read, not a reflex — and the slower regen means holding it early costs you
## the next one.
const GUARD_MAX_STAMINA: float = 2.0
const GUARD_DRAIN_RATE: float = 1.0
const GUARD_REGEN_RATE: float = 0.45
## Dash: a quick evasive burst in the current facing direction, on a short
## cooldown rather than a stamina meter — it's one instant action, not a hold.
const DASH_SPEED: float = 14.0
## Ceilings on knockback (see apply_knockback for why these exist at all and why
## they are anchored to DASH_SPEED and JUMP_VELOCITY rather than picked).
const MAX_KNOCKBACK_SPEED: float = 16.0
const MAX_KNOCKBACK_LIFT: float = 7.0
const DASH_DURATION: float = 0.15
const DASH_COOLDOWN: float = 2.5

## 4.5: hitstop — the one piece of the Q-8 hit-feedback set (flash, particles,
## camera shake) that never landed. A brief, near-total slowdown is what turns
## a landed hit into something that reads as CONTACT rather than a colour
## change. Global `Engine.time_scale`, not a per-node effect, and broadcast the
## same way _rpc_play_hit_vfx already is — every peer sees the same beat at
## the same trigger, consistent with flash/particles already being shared
## rather than per-viewer. Deliberately small and short: this is a LAN
## prototype with no reconciliation already (Handoff.md §1), and a ~60ms
## global dip is well inside the slack a real-hardware LAN test tolerates —
## nothing here is authoritative for anything RoundManager decides.
const HITSTOP_DURATION: float = 0.06
const HITSTOP_TIME_SCALE: float = 0.05
## Static: the guard is about "is a dip already in flight", which is true or
## false for the WHOLE game, not per character — two hits landing the same
## frame must not fight over restoring time_scale out from under each other.
static var _hitstop_active: bool = false

## 4.1 landing detection — see the block in _physics_process. Per-character, and
## deliberately NOT reset by reset_for_new_round(): a stale "was airborne" at a
## round boundary costs at most one extra thud, while forgetting to reset it
## would be a silent landing, and the round reset already zeroes `velocity`
## which makes _fall_speed harmless on its own.
var _was_airborne: bool = false
## B-122. The state this character was in before the current one, maintained
## purely for _on_state_changed_audio. Deliberately separate from `state`
## itself: nothing about gameplay needs a previous-state field, and adding one
## to the real state machine would be a second source of truth for anyone to
## get out of step with.
var _audio_prev_state: State = State.NORMAL
var _fall_speed: float = 0.0

## NORMAL — moving/acting freely.
## STAGGERED — brief no-control flinch from a bump (BUMP_STAGGER_TIME), auto-recovers.
## DOWNED — knocked down; can self-right (bump input) within DOWNED_SELF_RIGHT_WINDOW;
##          after the window expires it becomes sealable by an opponent Hitbox.
## SEALED — round-relevant "out" state for this character. What SEALED actually does to
##          round outcome is intentionally NOT decided here — RoundManager/MatchManager
##          own that, this just reports the state change via `state_changed`.
enum State { NORMAL, STAGGERED, DOWNED, SEALED }

@export var ability: AbilityBase
## true = this is the team's Can/Slipper Prop this round (defense = Can, offense =
## Slipper); false = this is the team's Person. See `is_person` below — a team is
## 1 Person + 1 Prop, NOT two Props. `is_can` only ever describes the Prop; a
## Person's `is_can` is always false regardless of which side its team is on this
## round (see main.gd `_spawn_player` / `_on_match_round_started`).
@export var is_can: bool = true
## true = this unit is the team's human Person (tags opponents on defense, throws
## the Slipper at the Can on offense — GDD Section 3/4). false = this unit is the
## team's Can/Slipper Prop, which carries the roster's class abilities (Quick
## Stand, Bakya Bash, etc.) via `ability`. Fixed for the whole match — unlike
## Can/Slipper (which flips with the team's Attacker/Defender role each round),
## a player stays Person or stays Prop all match. See main.gd for assignment.
@export var is_person: bool = false
## Session 8 (throw/tag mechanic): mirrors the Prop's `is_can` for a Person, who
## doesn't have an `is_can` of its own (a Person's `is_can` is always false — see
## above) but still needs to know which side its team is on this round to pick
## Tag (defense) vs Throw (offense) — see person_action.gd. true = team is on the
## Can/defense side, false = team is on the Slipper/offense side. Meaningless for
## a Prop (which already has `is_can` for this). Kept in sync by main.gd, same
## lifetime/pattern as `is_can` — see _spawn_player / _on_match_round_started.
@export var team_is_can_side: bool = true
## B-09: which team (0 = Team A, 1 = Team B) this character belongs to.
## Previously there was no team identity on CharacterBase at all — only
## main.gd's own `_peer_teams` dict knew it — so Hitbox had no way to skip a
## same-team hit, letting a defending Person dent/seal its own team's Can.
## Fixed for the whole match, same lifetime as `is_person`. Set by main.gd at
## spawn (both the networked flow and the local-test flow).
@export var team: int = 0
## Which match slot this character holds (1-4).
##
## ⚠️ NO LONGER SELECTS AN INPUT SET. Until 2026-07-29 this picked between four
## suffixed action sets ("_p1".."_p4") so two humans could share one keyboard,
## and p3/p4 were registered-but-unbound so an AI or a parked unit could never
## answer a real keystroke. The user retired split-keyboard play ("u can only
## play as one guy on one pc now") and all four collapsed into ONE unsuffixed
## set, so none of that is true any more:
##
##   * `_action()` is the identity — every character reads the same actions;
##   * an AI-driven character reads `_ai_intent` and never touches `Input`;
##   * `input_parked` is the explicit replacement for the unbound-suffix trick.
##
## What survives is the slot identity itself: `main.gd::_build_spawn_data` ships
## it in the networked spawn payload, and `you_card.gd` uses it to find the local
## character. Assigning it grants no control and silences nothing.
@export_range(1, 4, 1) var player_id: int = 1

## Which `CharacterRoster` entry this Person wears. -1 means "no pick" and is the
## honest default: an AI-driven slot and a local-test dummy never went through
## the CHARACTER screen, and character_visual.gd falls back to the signed-off
## per-team Person for those rather than putting everyone in the same shirt.
##
## ⚠️ REPLICATED, AND IT HAS TO BE. It is in CharacterBase.tscn's
## SceneReplicationConfig with `spawn = true` so it arrives with the character
## itself rather than a frame or two later — a Person that pops from one face to
## another after spawning is exactly the class of glitch the slipper bug was.
##
## ⚠️ NOT carried in MultiplayerSpawner's custom spawn `data`, even though that
## looks like the natural place. That dictionary silently truncates past 7
## entries once it crosses the network (measured — see main.gd::_spawn_player)
## and is already at exactly 7, so an 8th key would vanish on the receiving peer
## with no error whatsoever. The synchronizer has no such limit.
##
## Meaningless on a Prop, which is a lata or a tsinelas and wears neither.
var character_index: int = -1

## The Prop's two skins, same contract as `character_index` above: -1 is "no
## pick", both are replicated with `spawn = true`, both are meaningless on a
## Person.
##
## ⚠️ TWO, NOT ONE, BECAUSE A PROP IS BOTH THINGS OVER A MATCH. `is_can` flips
## every round (main.gd::_reset_world), so the same CharacterBase is a lata one
## round and a tsinelas the next. Storing a single "prop skin" would mean the
## player's lata choice and their tsinelas choice overwriting each other every
## time the role swapped.
var can_index: int = -1
var slipper_index: int = -1

signal state_changed(new_state: State)
## Option A only (see MAX_DENTS above). Fires whenever `dents` changes so
## RoundManager can watch for a tracked Can reaching MAX_DENTS without polling.
signal dents_changed(new_dents: int)
## Q-6: fires whenever a Guard blocks an incoming stagger/dent — the mechanic
## had no feedback of any kind, on the player being hit OR the one landing a
## now-nullified hit. CharacterVisual answers with a distinct (DEFENSE-tinted,
## never IMPACT-tinted) flash — see _flash_blocked below.
signal hit_blocked

## B-15/B-35: where this character respawns after falling into the KillPlane
## (scripts/systems/kill_plane.gd). Captured from wherever this character
## actually was when it first entered the tree (correct as-is for the local
## test flow's hand-placed transforms); main.gd updates it explicitly whenever
## it assigns a fresh position afterward (networked spawn, round reset), so a
## fall during round 2 respawns to round 2's spawn point, not round 1's stale
## one — see _build_networked_character / _on_match_round_started.
## (Two independent PRs added this same field for the same bug; merging them
## left it declared twice, which is a GDScript parse error — this is the
## surviving single declaration.)
var spawn_position: Vector3 = Vector3.ZERO
var state: State = State.NORMAL
## Option A only. Always 0 for Persons and Slippers — only a Can (is_can true)
## ever takes dents. Synced like `state` (see CharacterBase.tscn) so RoundManager
## can watch it identically on every peer; only the host's report actually counts
## (same pattern as _on_tracked_can_state_changed).
var dents: int = 0
## Whether the knockdown this Can is currently in counts for the attacking side.
## False for a lucky fall — see LUCKY_FALL_CHANCE. Written from the KIND the host
## sent, in `_apply_hit_result`, so every peer derives it from the same broadcast
## rather than rolling anything of its own.
##
## Read in two places, and both are the point of the feature:
##   * the DOWNED branch of _physics_process, which self-rights a lucky fall
##     instead of auto-sealing it — otherwise "no point for the enemy" would be
##     false, because an unrecovered fall loses the round outright under Option B;
##   * RoundManager._on_tracked_can_state_changed, which does not count it toward
##     FALL_LIMIT.
var last_fall_scored: bool = true
var _staggered_time_left: float = 0.0
var _downed_time_left: float = 0.0
var _downed_self_rightable: bool = false ## true only within the self-right window
var _bump_active_time_left: float = 0.0
var _speed_multiplier: float = 1.0 ## set by hazard zones (mud, Shatter Trap patch, etc.)
## B-16: Guard/Dash state — see the constants above for the doc on each.
var _guard_stamina: float = GUARD_MAX_STAMINA
var _is_guarding: bool = false
var _dash_cooldown_left: float = 0.0
var _dash_active_time_left: float = 0.0
## The character's own always-present melee Hitbox (requires_bump_window = true)
## — cached so opening the bump window can sweep already-overlapping targets
## (see _open_bump_window, B-08) without a scene-tree lookup every press.
var _melee_hitbox: Hitbox = null
## Everything about how this unit LOOKS lives on the `Visual` node's own script
## (see character_visual.gd) — including the B-44 hit flash, which used to be a
## hardcoded `get_node_or_null("Visual/MeshInstance3D")` here. That path broke
## silently once already (commit 6f97e76) when the mesh moved under the `Visual`
## wrapper: a wrong node path returns null with no error, so the flash simply
## stopped firing and nothing said so. This script no longer knows or cares what
## the mesh tree looks like.
@onready var _visual: CharacterVisual = $Visual
## B-60: this unit's own rig, consulted for who owns yaw this frame. Queried
## live rather than cached as a bool because `aim_source` changes at runtime —
## the debug switcher hands the mouse between units mid-match.
@onready var _camera_rig: CameraRig = get_node_or_null("CameraRig")
## Task 0 — this unit's own carry state, when it is a throwable tsinelas. Present
## on every character; reports is_throwable() false and stays LOOSE on a Person
## or a Can. See carriable.gd.
@onready var _carriable: Carriable = get_node_or_null("Carriable")
## Task 0/1 — this unit's hands, when it is a Person. See carrier.gd.
@onready var _carrier: Carrier = get_node_or_null("Carrier")

## Checklist 5.5, later reused for networked AI takeover. Null for every unit
## with a live human behind it; non-null for Single Player's unpiloted units
## and for a networked character with no real peer (an unfilled slot, or a
## real peer's character after they disconnect — see main.gd's
## _build_networked_character / _rpc_convert_to_ai). main.gd attaches this at
## runtime in every case (never baked into CharacterBase.tscn — see
## ai_controller.gd's own class doc for why). A plain public var rather than
## an @onready get_node_or_null(), because the node this would resolve does
## not exist yet when THIS character's own _ready() runs — main.gd adds it
## afterward.
var ai_controller: AIController = null

## Art_Direction.md §1 proportion audit: CharacterBase.tscn's CollisionShape3D,
## Hurtbox, Hitbox and GrabArea used to be baked once at Person scale (radius
## 0.4, height 1.6) for every unit — Person, Can and Tsinelas alike. Against a
## correctly-scaled 0.34-tall can that is a person-sized invisible capsule
## around a knee-high object: it blocks doorways the can visibly fits through
## and gets hit by throws that visibly miss. Each shape in CharacterBase.tscn
## is `resource_local_to_scene = true`, so mutating one here only ever touches
## THIS character's own copy, never another instance's.
##
## Hurtbox carries the same ~12% margin over its body shape that the Person
## row always has (0.45/1.7 vs 0.4/1.6) — a hair more forgiving than the
## visible silhouette, same idea `flick`/`bagsak`/etc. hitboxes already use.
## Hitbox (the always-on melee/bump reach) and GrabArea are scaled down for
## Props too, proportional to their own body size, so a can's bump doesn't
## reach out nearly a full unit from a 0.17-unit-tall body. GrabArea is inert
## on a Prop (`Carrier.has_hands()` only ever queries a Person's own), so its
## exact number there doesn't affect gameplay; sized anyway for consistency.
## Fine combat-feel tuning (does a can's bump reach far ENOUGH) is checklist
## 4.4's job once a human has played it, not this one's.
## ⚠️⚠️ THE PERSON'S MELEE BOX USED TO SIT AT HEAD HEIGHT AND COULD NOT REACH A
## PROP AT ALL. Worked through with the numbers, because the numbers are the bug:
##
##   Person origin (capsule centre) stands at world y 0.90. The old melee sphere
##   was `hit_off.y = +0.80`, r 0.50 -> it occupied world y 1.20 .. 2.20.
##   A lata's origin stands at world y 0.27 with a 0.40-tall hurtbox capsule
##   (r 0.17) -> world y 0.07 .. 0.47.
##
##   The gap between the two is 0.73 units. They could never touch, at any
##   distance, in any frame. A Person's bump could therefore hit ANOTHER PERSON
##   and nothing else — not the lata it is standing over, not a loose tsinelas.
##
## That silently voided three separate things that are all written as if they
## work: `carriable.gd`'s ownership rule ("an opponent's slipper is still a solid,
## KICKABLE obstacle - your bump still staggers it"), the Option A dent path for a
## Person hitting a can, and the whole `_scuff_enemy_slippers` TOUCH branch's
## sibling behaviour. It also explains why every tuning pass on bump feel found
## nothing: the box was not weak, it was somewhere else.
##
## The melee sphere now hangs at roughly WAIST height and is wider, so a single
## box covers a 1.6-unit Person and a 0.34-unit lata without a second shape:
## local y -0.77 .. +0.67 -> world 0.13 .. 1.57 for a Person, which overlaps both.
## Forward reach is 0.55 + 0.72 = 1.27 from the body centre, i.e. ~0.87 clear of
## the Person's own 0.40 capsule — an arm's length, not a lunge.
##
## The Prop rows keep the same shape-per-role idea (a can's bump must not reach
## a full unit out of a knee-high body) and are re-derived from the new tsinelas
## scale below rather than left at the old ones.
##
## ⚠️ THE TSINELAS ROW IS SCALED BY `TSINELAS_VISUAL_SCALE` AND THAT IS NOT
## COSMETIC BOOKKEEPING. `TsinelasVisual.tscn` is 1.25x bigger now ("slightly
## increase the size of the slipper for dramatic effect"), and a visual that
## outgrows its capsule is a slipper you can see but cannot step on, kick or land
## on the ground correctly. Both numbers move together or neither does.
const TSINELAS_VISUAL_SCALE: float = 1.25

const _COLLISION_BY_ROLE: Dictionary = {
	"person": {
		"body_r": 0.40, "body_h": 1.60, "hurt_r": 0.45, "hurt_h": 1.70,
		"hit_r": 0.72, "hit_off": Vector3(0, -0.05, -0.55), "grab_r": 1.70,
	},
	"can": {
		"body_r": 0.14, "body_h": 0.34, "hurt_r": 0.17, "hurt_h": 0.40,
		"hit_r": 0.20, "hit_off": Vector3(0, 0.02, -0.16), "grab_r": 0.60,
	},
	"tsinelas": {
		"body_r": 0.20, "body_h": 0.40, "hurt_r": 0.24, "hurt_h": 0.48,
		"hit_r": 0.18, "hit_off": Vector3(0, 0.02, -0.18), "grab_r": 0.75,
	},
}

## ---------------------------------------------------------------------------
## CHARACTER TRAITS — the gameplay half of `character_roster.gd`'s three numbers.
##
## Human ask: *"give characters unique gameplay traits and stats (faster,
## stronger) that tie directly into their respective lore descriptions."*
##
## ⚠️ THREE MULTIPLIERS, NOT A NEW SYSTEM, AND THAT IS THE WHOLE DESIGN. Each one
## is applied at exactly ONE site that already existed:
##
##   BILIS -> the `SPEED` term in _physics_process's movement block.
##   LAKAS -> the impulse `hitbox.gd::_impulse_for()` produces, and the charge
##            power `carrier.gd` releases a throw at.
##   TATAG -> divides incoming knockback in apply_knockback(), and shortens the
##            stagger in apply_stagger().
##
## Nothing new is simulated, no second physics path, no per-character branch.
## That is deliberate and it is the same rule `ai_controller.gd`'s own class doc
## states from the other direction: a second copy of a rule is a second copy to
## keep in sync, and this project has paid for that repeatedly.
##
## ⚠️ RE-DERIVED EVERY CALL, NEVER CACHED. `is_can` flips every round, so a Prop
## is answering from the LATA list one round and the TSINELAS list the next; a
## value resolved once at spawn would be describing the wrong object from round 2.
## Same rule as `is_can`/`team_is_can_side`/`_prop_ability_for` already follow.
##
## ⚠️ THE PER-POINT STEPS ARE SMALL ON PURPOSE. Full range on a 1..5 scale is
## +/-10% speed and +/-14% power and grit. A party game about hitting a can with a
## slipper cannot afford a pick that is simply correct, and a difference you feel
## is worth more here than a difference you can count.
const TRAIT_SPEED_PER_POINT: float = 0.05
const TRAIT_POWER_PER_POINT: float = 0.07
const TRAIT_GRIT_PER_POINT: float = 0.07

## This unit's points, 1..5, for one trait — from the roster entry matching what
## it currently IS (a Person reads the Person list; a Prop reads the lata or the
## tsinelas list depending on this round's `is_can`).
func trait_points(key: StringName) -> int:
	if is_person:
		return CharacterRoster.person_trait(character_index, key)
	return CharacterRoster.prop_trait(can_index, slipper_index, is_can, key)

## Movement multiplier from BILIS. 1.0 at the neutral 3.
func trait_speed_scale() -> float:
	return 1.0 + float(trait_points(&"bilis") - CharacterRoster.TRAIT_NEUTRAL) * TRAIT_SPEED_PER_POINT

## Outgoing-force multiplier from LAKAS. Applied to melee impulses and to throw
## charge power. 1.0 at the neutral 3.
func trait_power_scale() -> float:
	return 1.0 + float(trait_points(&"lakas") - CharacterRoster.TRAIT_NEUTRAL) * TRAIT_POWER_PER_POINT

## Incoming-force DIVISOR from TATAG, so a higher number always means "moved and
## stunned less". Returned as a multiplier greater than 1 for a sturdy unit, which
## callers divide by — stated this way round so the direction cannot be misread at
## a call site. 1.0 at the neutral 3, and floored so it can never be zero.
func trait_grit_scale() -> float:
	return maxf(0.1,
		1.0 + float(trait_points(&"tatag") - CharacterRoster.TRAIT_NEUTRAL) * TRAIT_GRIT_PER_POINT)

## True when the local player is aiming this unit with the mouse, i.e. the rig
## is writing `rotation.y` and this script must not fight it.
func _is_mouse_aimed() -> bool:
	return _camera_rig != null and _camera_rig.aim_source == CameraRig.AimSource.MOUSE

## Resizes this character's own collision shapes to match its current role.
## Called from _ready() and again from reset_for_new_round(), because a Prop's
## `is_can` flips every round (Can this round, Tsinelas the next) while
## `is_person` never does — re-running for a Person is a harmless no-op of
## identical numbers.
func _apply_role_collision() -> void:
	var key := "person" if is_person else ("can" if is_can else "tsinelas")
	var cfg: Dictionary = _COLLISION_BY_ROLE[key]
	var body_shape := ($CollisionShape3D as CollisionShape3D).shape as CapsuleShape3D
	if body_shape:
		body_shape.radius = cfg["body_r"]
		body_shape.height = cfg["body_h"]
	var hurt_shape := ($Hurtbox/CollisionShape3D as CollisionShape3D).shape as CapsuleShape3D
	if hurt_shape:
		hurt_shape.radius = cfg["hurt_r"]
		hurt_shape.height = cfg["hurt_h"]
	var hit_area := $Hitbox as Area3D
	var hit_shape := (hit_area.get_node("CollisionShape3D") as CollisionShape3D).shape as SphereShape3D
	if hit_shape:
		hit_shape.radius = cfg["hit_r"]
	hit_area.position = cfg["hit_off"]
	var grab_shape := ($GrabArea/CollisionShape3D as CollisionShape3D).shape as SphereShape3D
	if grab_shape:
		grab_shape.radius = cfg["grab_r"]
	# B-89: the nameplate ring/label read this same capsule, so they resize in
	# the same call, right after the shapes above actually changed — never
	# before. See CharacterNameplate.apply_sizing()'s own warning for why this
	# cannot just run from the nameplate's own _ready().
	var nameplate := get_node_or_null("Nameplate") as CharacterNameplate
	if nameplate != null:
		nameplate.apply_sizing()

## Team can = the Can Prop itself, and its team's defending Person (the Taya).
## Re-derived every call rather than cached, same as is_can/team_is_can_side
## themselves — both flip every round.
##
## ⚠️ Gated on RoundManager.round_active, added 2026-07-28: user feedback
## ("i want ppl to be able to move around with no restrictions whiile waiting
## for ready") wants a free-roam window before the round actually starts.
## round_active is false there, same as it briefly is between rounds during
## an ordinary intermission — that window is harmless because
## reset_for_new_round()/_reset_world() already re-teleports everyone to
## their role spawn the instant the next round's setup runs, before a player
## has time to wander. Do not remove this gate to "simplify" back to the old
## always-on version; that is what made the pre-round waiting area impossible.
func _is_confined_to_base() -> bool:
	return RoundManager.round_active and (is_can or (is_person and team_is_can_side))

## Wraps move_and_slide() with the confinement clamp so every call site in this
## file gets it automatically rather than relying on each one to remember —
## see CONFINEMENT_RADIUS's own doc for what this is and why. A soft radial
## clamp on the flat (X/Z) position, not a wall: crossing the edge just stops
## making further progress outward, rather than colliding with anything, so it
## costs no extra collision shape and cannot itself desync a hit.
## ⚠️ SPAWN SETTLE — DO NOT REMOVE. This is the real fix for B-100.
##
## Writing `position` on a PhysicsBody3D updates the SCENE TREE at once and the
## physics BROADPHASE only at the next server step. Roles swap every round, so
## the two Persons trade marks — and for one physics frame each of them is
## standing on the OTHER one's stale collider. Measured with tools/jump_probe.gd
## and tools/spawn_probe.gd: the incoming Taya is placed correctly at
## (2.2, 0.9, -1.5), then `move_and_slide()` reports three contacts with the
## outgoing Person (normal 0,1,0 — stacked on its head), shoves it 1.60 up to
## y=2.50, and the next frame slides it 9.89 units into WallWest, where the
## confinement clamp parks it on the boundary at exactly radius 5.0.
##
## Neither `force_update_transform()` nor `PhysicsServer3D.body_set_state()`
## fixes it, and B-100's "park everyone at y=500 first" could not either — all
## three are writes that the broadphase does not see until it steps. Toggling
## `CollisionShape3D.disabled` was tried before that and also failed, for the
## same reason.
##
## So instead of trying to make the server see the write sooner, nobody MOVES
## until it has. For SPAWN_SETTLE_FRAMES physics frames after placement this
## character holds its placed transform, keeps zero velocity, and skips
## move_and_slide() entirely. Three frames is 50ms — invisible — and by then the
## broadphase has stepped and every capsule is where the scene tree says it is.
const SPAWN_SETTLE_FRAMES: int = 3
var _spawn_settle: int = 0
var _spawn_settle_at: Transform3D = Transform3D.IDENTITY

## Called by main.gd::_place_at_spawn immediately after it writes the transform.
func begin_spawn_settle() -> void:
	_spawn_settle = SPAWN_SETTLE_FRAMES
	_spawn_settle_at = global_transform
	velocity = Vector3.ZERO

func _move_and_confine() -> void:
	move_and_slide()
	# ⚠️ BEFORE THE CONFINEMENT EARLY-RETURN BELOW. The attacking Person is not
	# confined, and it is just as entitled to boot the defenders' slipper around
	# as they are its own — putting this after the return would have made the
	# mechanic silently one-sided.
	_scuff_enemy_slippers()
	if not _is_confined_to_base():
		return
	# ⚠️ A SQUARE, NOT A CIRCLE — and it was a circle until 2026-07-29 while the
	# floor said otherwise. This used to clamp radially
	# (`if flat.length() > CONFINEMENT_RADIUS`), but BOTH map builders draw the
	# confinement marker as four straight court lines at |x| = |z| = 5.0
	# (`court_line("Confinement*", ...)`), and a square and a circle of the same
	# "radius" only agree at the four edge midpoints.
	#
	# On the diagonals they disagree by a lot: the chalk promises 7.07 units at a
	# corner and the radial clamp stopped the player dead at 5.0 — a 2.07-unit
	# invisible wall, exactly where a Taya moves when it is covering a corner of
	# its own box. Nobody had hit it because nobody had played the box.
	#
	# Human call, 2026-07-29: the SQUARE is the real one. The marker stays square
	# (that decision predates this — a drawn circle was rejected as ugly) and the
	# physics now matches it, so the Taya gets its corners back.
	#
	# ⚠️ THIS IS A BALANCE CHANGE, not just a correctness one: it enlarges the
	# defended area by 4/pi (~27%) and gives the Taya up to 2.07 more units of
	# reach on the diagonals. AI fairness was measured either side of it.
	global_position.x = clampf(global_position.x, -confinement_radius, confinement_radius)
	global_position.z = clampf(global_position.z, -confinement_radius, confinement_radius)

## STEP AND TOUCH ON AN OPPONENT'S TSINELAS. Human request, 2026-07-29: *"add a
## mechanic that defender can step or touch the slipper of enemy team and it will
## slow down or get knocked back (knock back for the touch)."*
##
## Read straight off `move_and_slide()`'s own collision results, which is the only
## place that already knows both WHAT was touched and FROM WHAT ANGLE — and the
## angle is the whole mechanic. Standing on top of a slipper and walking into its
## side are the same overlap to an Area3D and completely different events to a
## player, so a hitbox could not have told them apart; the contact normal can.
##
## Runs on this character's own peer only (`_physics_process` has already gated on
## authority by the time `_move_and_confine` is reached), so it ASKS rather than
## decides — `Carriable.host_scuff()` re-validates and broadcasts. Same
## client-asks/host-decides split as every grab and throw.
##
## The rules themselves are all in carriable.gd deliberately: this file must never
## learn what carrying is, which is the same rule that keeps dents and round-win
## logic out of it.
func _scuff_enemy_slippers() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var other := collision.get_collider() as CharacterBase
		if other == null:
			continue
		var carriable := other.get_node_or_null("Carriable") as Carriable
		if carriable == null or not carriable.can_be_scuffed_by(self):
			continue
		# STEP or TOUCH, decided two ways because one is not reliable enough.
		#
		# `get_normal()` points out of the surface we hit, so coming down squarely
		# on the slipper gives something close to straight up — but a tsinelas is a
		# 0.16-radius capsule, and anything short of a dead-centre landing on a cap
		# that small returns an angled normal. So the contact HEIGHT is the second
		# and more forgiving test: if we touched it at or below our own feet, it was
		# under us, whatever the normal says. See Carriable.STEP_CONTACT_MARGIN.
		var normal := collision.get_normal()
		# ⚠️ COMPARE THE SLIPPER'S TOP TO OUR FEET — NOT THE CONTACT POINT TO OUR
		# FEET. The contact-point version was tried and it made TOUCH unreachable:
		# a tsinelas lies on the ground, so ANY contact with it — including walking
		# squarely into its side — happens down near the walker's feet, and every
		# single collision therefore read as a step. Caught by changing
		# TOUCH_KNOCKBACK_SPEED from 2.6 to 8.5 and watching the measured
		# displacement not move a millimetre (0.196 m both times): a number that
		# ignores the constant it should depend on means the branch never ran.
		#
		# The right question is whether the slipper is UNDER us, and that is its top
		# against our feet. Standing on one puts our feet at its top (~0.32); walking
		# into one leaves our feet on the ground, well below it.
		var feet_y := global_position.y - capsule_height() * 0.5
		var other_top := other.global_position.y + other.capsule_height() * 0.5
		var underfoot := other_top <= feet_y + Carriable.STEP_CONTACT_MARGIN
		if normal.y >= Carriable.STEP_NORMAL_Y or underfoot:
			_request_scuff(carriable, "step", Vector3.ZERO)
			continue
		# The shove goes along the contact, flattened — a body-check should send
		# it skidding across the ground, not punt it into the sky. The lift is
		# added on the receiving side (Carriable.TOUCH_KNOCKBACK_LIFT).
		var push := Vector3(-normal.x, 0.0, -normal.z)
		if push.length() < 0.01:
			continue
		_request_scuff(carriable, "touch", push.normalized())

func _request_scuff(target: Carriable, kind: String, direction: Vector3) -> void:
	if not NetworkManager.is_networked() or NetworkManager.is_host():
		target.host_scuff(self, kind, direction)
	else:
		# Routed to the host by PATH and re-resolved there, exactly as
		# carrier.gd::_rpc_request_grab does — a client asserting that it scuffed
		# something proves nothing about whether it was allowed to.
		_rpc_request_scuff.rpc_id(1, target.get_parent().get_path(), kind, direction)

## Client -> host. The host re-resolves the target from its path and re-checks
## `can_be_scuffed_by()` inside `host_scuff()`.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_scuff(target_path: NodePath, kind: String, direction: Vector3) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var target := get_node_or_null(target_path) as CharacterBase
	if target == null:
		return
	var carriable := target.get_node_or_null("Carriable") as Carriable
	if carriable == null:
		return
	carriable.host_scuff(self, kind, direction)

func _ready() -> void:
	spawn_position = global_position
	for child in find_children("*", "Hurtbox", true, false):
		(child as Hurtbox).owner_character = self
	for child in find_children("*", "Hitbox", true, false):
		var hitbox := child as Hitbox
		hitbox.owner_character = self
		if hitbox.requires_bump_window:
			_melee_hitbox = hitbox
	_apply_role_collision()
	# Person / Can / Tsinelas each get their own model. Reapplied every round in
	# reset_for_new_round(), because `is_can` flips with the role swap.
	_visual.apply(is_person, is_can, team)
	# 4.1 — see _on_state_changed_audio for why the state SIGNAL is the hook
	# rather than the transition functions themselves.
	state_changed.connect(_on_state_changed_audio)

func _physics_process(delta: float) -> void:
	# ⚠️ BEFORE EVERYTHING, INCLUDING THE AI. See begin_spawn_settle().
	# Holding the placed transform for a few frames is what stops two characters
	# that just traded spawn marks from depenetrating off each other's stale
	# collider. Skipping the whole function is deliberate: gravity, the AI and
	# move_and_slide() must all stay out of it until the broadphase has stepped.
	if _spawn_settle > 0:
		_spawn_settle -= 1
		global_transform = _spawn_settle_at
		velocity = Vector3.ZERO
		return

	# Checklist 5.5 — Single Player AI. Deliberately the FIRST line of this
	# function, before anything below reads Input: ai_controller writes into
	# this character's own action_name()-suffixed Input state exactly the way
	# a human would, and Godot does not guarantee _physics_process order
	# between a parent and its children — leaving this implicit (e.g. relying
	# on AIController being a child that "happens" to run first) would make
	# the AI's presses land a frame late roughly as often as not. This is the
	# ONLY hook: everything after this line — movement, abilities, carrier,
	# confinement, the state machine, round-active gating — is completely
	# unmodified and unaware whether the Input it reads came from hardware or
	# from here. See ai_controller.gd's own class doc for the full reasoning.
	if ai_controller != null:
		ai_controller.decide(delta)

	# Session 6: the bump-active window has to decay on every peer, not just
	# the owning one — the host needs its own copy of this timer to resolve
	# hits authoritatively (see hitbox.gd), and it never runs the input half
	# of this function for a character it doesn't own. Cheap and harmless for
	# the non-networked local flow too.
	if _bump_active_time_left > 0.0:
		_bump_active_time_left -= delta
	if _dash_active_time_left > 0.0:
		_dash_active_time_left -= delta

	# Task 0: a tsinelas that is in someone's hand or in the air is not walking
	# anywhere under its own power — the carry component owns its transform for
	# the duration. Deliberately placed BEFORE the authority gate below so every
	# peer runs it: both branches are deterministic from state the host has
	# already broadcast (who is carrying / the launch origin and velocity), so
	# computing them locally is cheaper and smoother than streaming a transform,
	# and a carried slipper costs literally no bandwidth.
	if _carriable != null and _carriable.drives_movement():
		_carriable.physics_step(delta)
		return

	# Rough networking pass (Session 5): once a network peer exists, only the
	# owning peer simulates movement/input for its own character — everyone
	## else's copy is driven purely by MultiplayerSynchronizer (see
	## CharacterBase.tscn). Local single-PC/split-keyboard testing is
	# unaffected since NetworkManager.is_networked() is false there.
	if NetworkManager.is_networked() and not is_multiplayer_authority():
		return

	# 4.1 — the landing thud, and the only piece of audio in this file that has
	# to be sampled BEFORE gravity and movement run for the frame.
	#
	# ⚠️ GATED ON IMPACT SPEED, NOT JUST ON THE FLOOR EDGE. `is_on_floor()`
	# flickers false for a single frame whenever a character walks over the seam
	# between two collision shapes — and this arena is paved with them (the road
	# slabs, the kerbs, the apron). An ungated edge test therefore fires a thud
	# every few steps on flat ground, which reads as a stutter rather than as
	# footsteps. JUMP_VELOCITY is 5.8, so anything past ~2 is a real fall and a
	# seam blip (which carries essentially no downward speed, because the
	# character never left the ground) is not.
	var grounded := is_on_floor()
	if grounded and _was_airborne and _fall_speed > LAND_SFX_MIN_SPEED:
		AudioManager.play_at("land", global_position)
	_was_airborne = not grounded
	if not grounded:
		velocity.y -= GRAVITY * delta
		# ⚠️ TERMINAL VELOCITY, AND IT IS AN ANTI-TUNNELLING GUARD, NOT FEEL.
		#
		# `CharacterBody3D` does no continuous collision detection: `move_and_slide()`
		# steps `velocity * delta` and tests the END position. A map floor is a
		# 1-unit-thick box, so the instant a unit's per-frame displacement exceeds
		# that thickness it can pass straight through with no contact generated at
		# all — and once it is under the floor nothing pushes it back, only the
		# KillPlane at y = -10 catches it.
		#
		# Unbounded gravity reaches 60 units/s in three seconds, which is 1.0 units
		# per frame at 60 Hz and exactly the floor's thickness. It gets there sooner
		# on a frame spike, which is why this reads as MAP-SPECIFIC: Bayan Plaza
		# carries ~640 instances against Eskinita's ~500, so its frames right after
		# a round reset are its longest, and "the can falls through the world" was
		# reported on that map.
		#
		# MAX_FALL_SPEED caps a fall at 0.43 units per frame at 60 Hz and stays
		# under the floor thickness even at 30 Hz, so tunnelling is impossible by
		# arithmetic rather than by hoping the frame budget holds. It is far above
		# anything reachable in play — JUMP_VELOCITY is 5.8, MAX_KNOCKBACK_LIFT is
		# 7.0 — so nothing in a round can feel it, and a real fall off the map still
		# looks like a fall.
		velocity.y = maxf(velocity.y, -MAX_FALL_SPEED)
	# Sampled AFTER gravity so it is the speed this character will actually
	# arrive at the floor with, not the speed it had a frame earlier.
	_fall_speed = -velocity.y

	# Item 10 / B-37: freeze input during the round intermission (the gap
	# between a round ending and the next one's timer starting — see
	# MatchManager.round_intermission_started / main.gd::_reset_world) and
	# while waiting for a rematch after a match ends. round_active is false
	# in both cases; still apply gravity/friction above/below so nobody
	# floats or skids, just can't act.
	# ⚠️ EXCLUDES the pre-match free-roam window added 2026-07-28
	# (main.gd::_start_local_test/_awaiting_local_ready) — round_active is
	# ALSO false there, but MatchManager.round_number is still 0 (no round
	# has ever begun yet), which is what distinguishes "waiting to ready up,
	# should be able to walk around" from "between rounds/matches, should
	# not." Do not simplify this back to a bare `not round_active` check;
	# that is exactly what froze movement during the free-roam window the
	# first time this shipped.
	if not RoundManager.round_active and MatchManager.round_number > 0:
		# ⚠️ A HARD FREEZE, NOT A FRICTION SLIDE. 2026-07-29, user report:
		# "whenever a round ends, players get launched to multiple directions."
		#
		# This used to decay velocity by FRICTION and still call
		# _move_and_confine() — i.e. it stopped INPUT but kept integrating
		# whatever velocity was already there, and kept integrating anything
		# written DURING the gap. Measured with tools/round_probe.gd: a single
		# impulse delivered two frames into the intermission slid every
		# character at 10.63 m/s and up to 5.20 m off the spawn marker it had
		# just been teleported to.
		#
		# Such an impulse is not hypothetical, and there are two routine sources:
		#   * the round-winning TAG applies knockback in the very frame it ends
		#     the round (hitbox.gd resolves the hit before it calls
		#     report_round_win), and
		#   * networked, `_apply_hit_result` is an rpc_id to the STRUCK peer, so
		#     it can arrive whole frames after _reset_world() has already put
		#     everyone home.
		# apply_knockback() now refuses to write velocity while the round is
		# inactive, which closes the source; this closes the integration path
		# regardless of what else ever writes velocity between rounds.
		velocity.x = 0.0
		velocity.z = 0.0
		# Still fall if somehow airborne — the original's "nobody floats"
		# concern is real, and a match ending mid-jump must not leave a body
		# hanging in the air. Once grounded, stop moving entirely: no
		# move_and_slide at all, so no depenetration impulse, no drift, and
		# nothing for a stray velocity write to act on.
		if is_on_floor():
			velocity.y = 0.0
			return
		_move_and_confine()
		return

	if ability:
		ability.tick(delta)

	# Playtest 0.4: jump. EVERY unit jumps, Person and Prop alike — a hopping
	# lata and a hopping tsinelas are funnier than a realistic one, and this
	# project is a party game for friends first.
	#
	# Deliberately placed here, after the round-active gate above, so nobody can
	# hop around during the intermission, and before the ability block so a jump
	# and a throw on the same frame both resolve.
	#
	# ⚠️ JUMP_VELOCITY IS CONSTRAINED BY THE MAP, NOT BY FEEL. Every loose piece
	# of interior clutter is <= 1.0 tall on purpose, because an FPP Person's eye
	# is at 1.25 and has to see over all of it (Art_Direction.md's height
	# law). 5.8 against GRAVITY 20.0 apexes at 5.8^2 / (2*20) = 0.841, which
	# clears a kerb (0.15) and a tyre (0.22) but NOT a crate stack or an oil drum
	# (0.90). Raise this above ~1.0 and every crate in the alley silently becomes
	# a platform, which breaks the height law and puts players on top of the
	# dressing where there is no boundary to stop them.
	if state == State.NORMAL and is_on_floor() 			and input_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		AudioManager.play_at("jump", global_position)

	# Task 0/1: grab and charge-throw. Runs before the rest of the input block so
	# a throw released this frame is not also read as an ability press below.
	if _carrier != null and state == State.NORMAL:
		_carrier.input_step(delta)

	if state == State.NORMAL and input_just_pressed("bump"):
		_open_bump_window()
		# Cosmetic only. CharacterVisual decides what a bump LOOKS like and picks
		# a clip the model actually has; this file just says what happened.
		_visual.play_action("bump")
		# Tell the host our bump window just opened, since the host is the one
		# resolving Hitbox/Hurtbox overlaps now (see hitbox.gd) and it can't
		# see this peer's local-only timer any other way. No-op if we ARE the
		# host, or if we're not networked at all.
		if NetworkManager.is_networked() and not NetworkManager.is_host():
			_rpc_notify_bump.rpc_id(1)

	if state == State.NORMAL:
		_process_guard_dash(delta)

	match state:
		State.STAGGERED:
			_staggered_time_left -= delta
			if _staggered_time_left <= 0.0:
				_set_state(State.NORMAL)
		State.DOWNED:
			if _downed_self_rightable:
				_downed_time_left -= delta
				if _downed_time_left <= 0.0:
					_downed_self_rightable = false
					# User feedback, 2026-07-28: "if team slipper make the can
					# fall... they win" — no mention of an attacker having to
					# walk up and physically seal it afterward. Auto-seal the
					# instant the self-right window lapses unrecovered, rather
					# than waiting for a follow-up hit (the old Option B
					# behaviour, now retired). state is still DOWNED and
					# _downed_self_rightable was just cleared above, so
					# seal()'s own guard passes. RoundManager's existing
					# "every tracked Can Sealed" win check (unchanged) fires
					# from this exactly as it used to fire from a manual seal.
					#
					# THE LUCKY FALL EXCEPTION. A fall that landed the can on its
					# head or its back must cost the attacking side nothing, and
					# not counting it toward FALL_LIMIT is not enough on its own:
					# under Option B an unrecovered fall auto-seals, and a seal
					# loses the round outright. So a lucky fall rights itself here
					# instead — the can went over, wobbled on its lid, and came
					# back up. See LUCKY_FALL_CHANCE.
					#
					# ⚠️⚠️ CANS ONLY. A PERSON MUST NEVER BE SEALED BY THE CLOCK.
					#
					# SEALED has no recovery — `_physics_process`'s SEALED branch
					# is `pass # awaiting round reset`. For a lata that is the
					# entire win condition. For a PERSON it means one hit removes
					# a player from the round permanently, and it went unnoticed
					# only because a thrown slipper used to resolve on the melee
					# hitbox and merely stagger (B-134). The moment throws started
					# actually knocking things down, every Person hit by one was
					# DOWNED for 2 s and then SEALED for the rest of the round.
					#
					# Caught by tools/scuff_probe.tscn, which could not drive its
					# test Person and printed `state=2` then `state=3` four times
					# running. A knocked-down Person gets back up.
					if last_fall_scored and is_can:
						seal()
					else:
						self_right()
			if input_just_pressed("bump") and _downed_self_rightable:
				self_right()
			# B-06: special_ability is normally only read further down, past the
			# STAGGERED/DOWNED/SEALED early return below — unreachable for an
			# "escape" ability like Quick Stand, whose only effect is self-
			# righting from exactly this state. is_ready()/once_per_round on the
			# ability itself already gates whether it actually does anything.
			if input_just_pressed("special_ability") and ability:
				ability.activate(self)
				if NetworkManager.is_networked() and not NetworkManager.is_host():
					_rpc_notify_ability_activate.rpc_id(1)
		State.SEALED:
			pass # awaiting round reset / respawn logic

	if state in [State.STAGGERED, State.DOWNED, State.SEALED]:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
		_move_and_confine()
		return

	if _dash_active_time_left > 0.0:
		# B-16: a Tsinelas-side Dash burst (see _process_dash) is a brief
		# committed action, not just a velocity nudge — without this guard,
		# holding a movement key during the dash would overwrite the burst
		# with normal walk speed on the very same physics frame it fired.
		_move_and_confine()
		return

	var input_dir := input_vector("move_left", "move_right", "move_up", "move_down")
	# B-60: which frame WASD is read in depends on who owns this unit's yaw.
	#
	# Mouse-aimed (the unit you are personally driving): the CameraRig owns yaw
	# and writes `rotation.y` from mouse motion, so input is read in the BODY's
	# frame — W is "where I am looking". Reading it in world space instead, and
	# then calling look_at() below to face the movement vector, snapped the body
	# to the WASD direction on every keypress; since the rig is a CHILD of the
	# body, that dragged the camera round with it. Measured: aim 90 deg left,
	# then hold D, and the camera flipped a full 180.
	#
	# Everything else (remote peers, local-test dummies — aim_source MOVEMENT)
	# keeps the original world-space scheme with look_at(), which is right for a
	# unit nobody is aiming with a mouse.
	#
	# B-05's original note said world-space was deliberate, "NOT
	# `transform.basis * input_dir`". That was correct when the only camera was
	# the fixed-angle ArenaCamera (removed A-2, v4.8); it stopped being correct the moment the
	# per-character FPP/TPP rigs (item 13) made the camera turn with the player.
	var mouse_aimed := _is_mouse_aimed()
	var direction: Vector3
	if mouse_aimed:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
		direction.y = 0.0
		direction = direction.normalized()
	else:
		direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	# Task 0: a LOOSE tsinelas crawls rather than walks (CRAWL_SPEED_SCALE) — the
	# retrieval scramble is only tense if getting home under your own power is
	# genuinely slow. 1.0 for every other unit and every other carry state.
	var carry_scale: float = _carriable.movement_speed_scale() if _carriable != null else 1.0
	# BILIS. The one place movement speed is decided, so the one place the trait
	# applies — see the trait block above. Multiplied in alongside the hazard-zone
	# and crawl scales rather than replacing either: a fast character crawling a
	# loose tsinelas through mud is still slow, just less slow than Lola Pacing.
	var trait_scale := trait_speed_scale()
	if direction:
		velocity.x = direction.x * SPEED * _speed_multiplier * carry_scale * trait_scale
		velocity.z = direction.z * SPEED * _speed_multiplier * carry_scale * trait_scale
		# Face the direction we're moving — nothing wrote `rotation` before this,
		# so every directional attack (melee Hitbox offset, PersonAction,
		# BakyaBash, FlickDash, all built on `-transform.basis.z`/local offsets)
		# fired toward world -Z regardless of which way the player was moving.
		# Skipped when mouse-aimed: the rig already wrote yaw this frame, and
		# overwriting it here is exactly the bug above. Attacks still fire where
		# you are looking, which is what B-05 actually wanted.
		if not mouse_aimed:
			look_at(global_position + direction, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)

	# Task 0: `and not _carrier_is_holding()` — with a slipper in hand this button
	# is the charge-throw (carrier.gd owns it, above) and must not ALSO fire the
	# ordinary ability. person_action.gd is now Tag-only for exactly this reason.
	if input_just_pressed("special_ability") and ability and not _carrier_is_holding():
		# B-12: this used to run AFTER move_and_slide(), so an ability that sets
		# velocity directly (Flick Dash's dash burst) applied a full physics
		# frame late. Moved above move_and_slide() so a velocity change this
		# tick actually takes effect this tick.
		#
		# Same pattern as the bump RPC above: activate locally (so a client sees
		# its own cosmetic hitbox/movement effect immediately, e.g. Flick Dash's
		# velocity kick), and — since hitbox resolution only ever runs on the
		# host (see hitbox.gd) — also tell the host to activate ITS OWN copy of
		# this character so the actual resolving hitbox exists where it can be
		# resolved (B-02: previously the activating peer's hitbox never reached
		# the host at all, so every special/Tag/Throw was a no-op for clients).
		ability.activate(self)
		# The grab/throw arm swing. Cosmetic, same contract as the bump above.
		_visual.play_action("throw")
		if NetworkManager.is_networked() and not NetworkManager.is_host():
			_rpc_notify_ability_activate.rpc_id(1)

	_move_and_confine()

	# ⚠️ LAST LINE, AFTER EVERY CONSUMER HAS READ THIS FRAME.
	# Rolls AI intent into "previous" so input_just_pressed()/just_released()
	# have an edge to detect. Doing it any earlier would consume the edge before
	# carrier.gd/ability code further down the same frame ever saw it, and a
	# charged throw would never fire for a bot.
	if ai_controller != null:
		ai_commit_intent_frame()

## Called on this character when it's hit by an opponent's Hitbox (see hitbox.gd).
func apply_stagger(duration: float = BUMP_STAGGER_TIME) -> void:
	# B-07: also skip DOWNED, not just SEALED — a hit landing on a Can that's
	# still inside its self-right window used to overwrite DOWNED with
	# STAGGERED, which auto-recovers to NORMAL, letting ANY bump (including a
	# teammate's) rescue a Downed Can for free. A hit during that window
	# should do nothing; hitbox.gd already routes a hit AFTER the window
	# expires to "seal" instead of "stagger", so this only ever blocks the
	# free-rescue case.
	if state == State.SEALED or state == State.DOWNED:
		return
	# B-16: a Can actively Guarding blocks the incoming hit outright — no
	# stagger, same as apply_dent() below no-ops the dent for the same reason.
	if _is_guarding:
		hit_blocked.emit()
		_flash_blocked()
		return
	# TATAG shortens the flinch. Applied here rather than at the striking end
	# because it is a property of the body being hit, exactly like
	# `hurtbox.gd::absorb_knockback` — the striker decides how hard, the target
	# decides how much of that it wears.
	_staggered_time_left = max(_staggered_time_left, duration / trait_grit_scale())
	_set_state(State.STAGGERED)

## B-17: HazardZone used to call a single set_speed_multiplier(1.0) on exit,
## which reset speed to normal even while still standing in a second overlapping
## zone. Track every zone this character is currently inside instead, and apply
## whichever is most restrictive — normal speed only once none are left.
var _active_speed_multipliers: Array[float] = []

func enter_speed_zone(multiplier: float) -> void:
	_active_speed_multipliers.append(multiplier)
	_recompute_speed_multiplier()

## `multiplier` identifies which zone is leaving (a zone could in principle change
## multiplier mid-life, but none do today) — removes one matching entry, not all.
func exit_speed_zone(multiplier: float) -> void:
	var idx := _active_speed_multipliers.find(multiplier)
	if idx != -1:
		_active_speed_multipliers.remove_at(idx)
	_recompute_speed_multiplier()

func _recompute_speed_multiplier() -> void:
	var lowest := 1.0
	for m in _active_speed_multipliers:
		lowest = min(lowest, m)
	_speed_multiplier = lowest

## Knocks this character into the Downed state (out-of-base hit, or a heavy special
## like Bakya Bash's instant-down). Starts the self-right window.
## `scoring` false is the lucky fall — see LUCKY_FALL_CHANCE. Set BEFORE
## `_set_state`, because that is what emits `state_changed`, and RoundManager's
## handler reads this flag the moment it fires.
func go_downed(scoring: bool = true) -> void:
	if state == State.SEALED:
		return
	last_fall_scored = scoring
	_downed_time_left = DOWNED_SELF_RIGHT_WINDOW
	_downed_self_rightable = true
	_set_state(State.DOWNED)
	if ability and ability.has_method("_on_owner_downed"):
		ability._on_owner_downed(self)

## Player (or an ability, e.g. Sardinas' Quick Stand) recovers from Downed early.
func self_right() -> void:
	if state != State.DOWNED:
		return
	_downed_self_rightable = false
	_set_state(State.NORMAL)

## Option A only: a landed hit on this Can adds one dent (capped at MAX_DENTS)
## and applies a brief stagger for hit feedback — deliberately does NOT use the
## Downed/Seal state machine at all, since Option A's win condition is purely
## the dent count, tracked independently by RoundManager (see
## _on_tracked_can_dents_changed). No-op for a Person or Slipper.
func apply_dent(stagger_duration: float = BUMP_STAGGER_TIME) -> void:
	if not is_can:
		return
	# B-16: Guard blocks dents too — the whole point of a Can blocking is to
	# protect its own health bar, not just avoid the cosmetic stagger.
	if _is_guarding:
		hit_blocked.emit()
		_flash_blocked()
		return
	dents = min(dents + 1, MAX_DENTS)
	dents_changed.emit(dents)
	apply_stagger(stagger_duration)

## T-3 / B-46, Option A half: the taya's reset channel beats one dent back out of
## this Can. The exact mirror of apply_dent() above and it lives here for the same
## reason — `dents` is this file's business, and nothing outside it writes the
## field directly. No stagger, because being repaired is not being hit.
##
## Deliberately NOT a round-win concern: RoundManager watches dents_changed and
## re-evaluates on its own (_on_tracked_can_dents_changed), so dropping back below
## MAX_DENTS needs no cooperation from here. Same contract apply_dent() relies on.
func clear_dent() -> void:
	if not is_can or dents <= 0:
		return
	dents -= 1
	dents_changed.emit(dents)

## Transitions Downed -> Sealed once the self-right window has passed.
## Previously only ever called by an opponent's follow-up Hitbox landing on an
## already-past-the-window Can (see hitbox.gd); now also called by this file's
## own _physics_process the instant the window itself expires (2026-07-28 —
## "if team slipper make the can fall, they win," no manual follow-up hit
## required). Both call sites hit the same guard below, so neither can
## double-seal or race the other.
func seal() -> bool:
	if state != State.DOWNED or _downed_self_rightable:
		return false # still in the self-right window, can't be sealed yet
	_set_state(State.SEALED)
	return true

## Opens the press-to-bump window and immediately sweeps for anyone already
## overlapping the melee Hitbox (B-08) — area_entered alone only catches
## someone who overlaps AFTER the window opens, so walking into someone and
## then pressing bump (the natural order) used to never register a hit.
func _open_bump_window() -> void:
	_bump_active_time_left = BUMP_ACTIVE_TIME
	# A new swing is a new offensive event, so everything this character already
	# struck becomes fair game again. Without this, bumping the same opponent
	# twice in a row would silently land only the first one — see
	# `_hit_memory`'s own doc for the rule this is one half of.
	clear_hit_memory()
	if _melee_hitbox:
		_melee_hitbox.sweep_overlaps()

## ---------------------------------------------------------------------------
## ONE HIT PER OFFENSIVE EVENT, PER TARGET.
##
## ⚠️ MEASURED BEFORE IT WAS FIXED (tools/phys_probe.gd, 12 throws each):
##     target=can   -> worst throw resolved  1 time   (looked fine — this is
##                     why it went unnoticed for so long)
##     target=taya  -> worst throw resolved 35 times, 344 resolutions total
##     target=graze -> worst throw resolved 59 times
## Every one of those re-runs a full state transition, a VFX flash, a hitstop
## (which dips Engine.time_scale globally) and a positional sound. That is the
## "hit animation triggers repeatedly and severely lags the game" report.
##
## Two independent causes, and this is why the memory lives HERE on the
## character rather than inside hitbox.gd:
##
##  1. `_step_flying()` calls `sweep_hitbox()` EVERY physics frame, and
##     `sweep_overlaps()` re-runs `_on_area_entered` for everything already
##     inside. A hurtbox that stays overlapped for 35 frames resolves 35 times.
##  2. A thrown slipper carries TWO live hitboxes at once — this scene's own
##     melee Hitbox (live for the whole flight, see is_hitbox_active) and the
##     per-profile pulse Hitbox from Carriable._spawn_flight_hitbox(). Both
##     overlap the same hurtbox, so even a single clean frame resolved TWICE.
##     Per-Hitbox memory could never have caught that; a shared one does.
##
## The Area3D-versus-body gap is why this cannot be left to physics: the
## hitbox spheres are deliberately larger than the capsules, so overlap starts
## a few frames before `move_and_collide` ends the flight — and on a graze the
## bodies never touch at all, so nothing ends it and the overlap just persists.
##
## Keyed by instance id rather than by holding object references: an id cannot
## dangle, and this dictionary outlives at least one round reset. Same
## reasoning ability_utils.gd already uses after B-118.
var _hit_memory: Dictionary = {}

## Records `target` as struck by this character's current offensive event.
## Returns false if it was already struck — the caller must then skip the hit
## entirely. Call once, at the point of resolution; it mutates.
func register_hit_once(target: CharacterBase) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var id := target.get_instance_id()
	if _hit_memory.has(id):
		return false
	_hit_memory[id] = true
	return true

## Starts a fresh offensive event. Called when a bump window opens, and by
## carriable.gd on every carry-state transition — thrown, caught, come to rest,
## round reset — so "once per throw" resets exactly when a throw does.
func clear_hit_memory() -> void:
	_hit_memory.clear()

## B-16: Guard/Dash. Props only (a Person's assist slot is Tag/Throw instead —
## see person_action.gd) — which half a Prop gets depends on `is_can` this
## round, same split as everything else that differs between Can and Tsinelas.
func _process_guard_dash(delta: float) -> void:
	if is_person:
		return
	if is_can:
		_process_guard(delta)
	else:
		_process_dash(delta)

func _process_guard(delta: float) -> void:
	var held := input_pressed("guard_dash")
	if held and _guard_stamina > 0.0:
		_is_guarding = true
		_guard_stamina = max(0.0, _guard_stamina - GUARD_DRAIN_RATE * delta)
	else:
		_is_guarding = false
		_guard_stamina = min(GUARD_MAX_STAMINA, _guard_stamina + GUARD_REGEN_RATE * delta)

func _process_dash(delta: float) -> void:
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left -= delta
	if _dash_active_time_left <= 0.0 and _dash_cooldown_left <= 0.0 and input_just_pressed("guard_dash"):
		var forward := -transform.basis.z
		velocity.x = forward.x * DASH_SPEED
		velocity.z = forward.z * DASH_SPEED
		_dash_active_time_left = DASH_DURATION
		_dash_cooldown_left = DASH_COOLDOWN
		AudioManager.play_at("dash", global_position)

## Whether this character is currently blocking (B-16 Guard). Gates incoming
## stagger/dents in apply_stagger()/apply_dent() below — hitbox.gd itself stays
## generic to any hit, same as the team check (B-09).
func is_guarding() -> bool:
	return _is_guarding

## Q-6: read-only HUD accessors — the mechanic itself (B-16) was fully
## implemented with no UI at all, which is almost certainly why it was
## reported missing. Exposed rather than making _guard_stamina/_dash_cooldown_left
## public outright, so nothing outside this file can write them.
func get_guard_stamina_ratio() -> float:
	return _guard_stamina / GUARD_MAX_STAMINA

## 1.0 once the cooldown has fully elapsed (ready to dash again), 0.0 the
## instant it was just used.
func get_dash_cooldown_ratio() -> float:
	return 1.0 - clamp(_dash_cooldown_left / DASH_COOLDOWN, 0.0, 1.0)

## Q-6: distinct from _flash_hit() (B-44's white "landed" flash) — DEFENSE-
## tinted, so a blocked hit never reads as a landed one.
func _flash_blocked() -> void:
	_visual.flash_blocked()
	# 4.1: a deflection, not a hit. Q-6's point was that Guard was fully
	# implemented with no feedback at all; a blocked hit that sounds like a
	# landed one would put that back, so this is the only impact in the game
	# with no hitstop behind it and its own metallic tink.
	AudioManager.play_at("guard_block", global_position)

## Whether this character's press-to-bump window is currently live. The melee
## Hitbox (requires_bump_window = true) checks this before landing a stagger;
## ability-spawned hitboxes (requires_bump_window = false) ignore it.
func is_hitbox_active() -> bool:
	# ⚠️⚠️ A THROWN SLIPPER IS LIVE FOR ITS WHOLE FLIGHT. THIS IS THE CORE
	# MECHANIC AND IT DID NOT WORK.
	#
	# `Hitbox.requires_bump_window` is true on CharacterBase.tscn's one Hitbox,
	# so every hit in the game was gated behind `_bump_active_time_left > 0.0` —
	# which is written in exactly one place, the BUMP press. A tsinelas in the
	# air never presses bump, so its hitbox was never active, so it could never
	# dent the lata. Measured with tools/phys_probe.gd: eleven throws launched
	# straight at the can from the throwing line produced **0 dents out of 3**.
	# Tumbang preso is a game about hitting a can with a slipper, and the slipper
	# passed through it.
	#
	# ⚠️⚠️ B-134 — AND THE `or _is_carriable_flying()` THAT USED TO BE HERE IS WHY
	# THE CAN COULD NOT FALL OVER.
	#
	# Human question, 2026-07-29: *"can the can even fall?"* Measured answer, with
	# tools/hit_probe.tscn aiming dead at the can's own hurtbox centre at full
	# charge: **0 knockdowns in 40 throws.** Of the 12 that made contact, SIX
	# resolved through this scene's own melee Hitbox.
	#
	# That box is the character's BODY-CHECK reach. It is 0.14 radius at a 0.16
	# offset, it carries `forces_downed = false`, and it knows nothing about the
	# ThrowProfile. So whenever it won the race, `hitbox.gd` resolved the throw as
	# a plain "stagger" no matter what was thrown — the profile's `forces_downed`,
	# its `hit_radius` and its whole identity were simply bypassed.
	#
	# It won the race constantly because the two boxes are nearly the same size in
	# practice. Against a Person the melee band is 0.14 + 0.45 = 0.59 and the
	# profile band is 0.30 + 0.45 = 0.75 — a 0.16 m difference, less than HALF of
	# one frame's travel at 0.433 m/frame. They therefore begin overlapping on the
	# same physics frame, and `_step_flying()` calls `sweep_hitbox()` at the top of
	# that frame, before the profile box's own `area_entered` is delivered.
	# Measured on a four-peer session: 33 of 40 throws resolved on melee.
	#
	# A thrown slipper is not body-checking anybody. Its profile hitbox
	# (`Carriable._spawn_flight_hitbox`) is live for the whole flight, is strictly
	# larger, and is the one that carries what the throw actually is — so it is now
	# the only thing that resolves a throw. `sweep_hitbox()` below sweeps it, so
	# the first-frame case the flying clause was originally added for is still
	# covered.
	return _bump_active_time_left > 0.0

## True while this unit is a Prop mid-throw. Read from Carriable rather than
## mirrored into a field here, so there is one source of truth for the state.
func _is_carriable_flying() -> bool:
	var c := get_node_or_null("Carriable") as Carriable
	return c != null and c.state == Carriable.CarryState.FLYING

## Re-runs this character's OFFENSIVE hitboxes against everything already inside
## them. `Area3D.area_entered` only fires on the ENTER edge, so a hitbox that
## becomes active while it is already overlapping a hurtbox never reports —
## which is true on the first frame of a throw, and is why `sweep_overlaps()`
## exists for the bump press. carriable.gd::_step_flying calls this every flight
## frame.
##
## B-134: this used to sweep ONLY `_melee_hitbox`, which was the wrong box for
## the one caller that runs it every frame. A thrown slipper resolves on its
## profile's pulse hitbox now (see is_hitbox_active), and that box is a child
## added at runtime by `Carriable._spawn_flight_hitbox()`, so it is not
## `_melee_hitbox` and was never swept. Sweeping both keeps the melee sweep for
## the bump press and gives the throw the first-frame coverage the flying clause
## used to provide.
##
## Double resolution is not a risk: `register_hit_once()` is keyed on the OWNER
## character precisely so two live hitboxes share one memory — see `_hit_memory`.
func sweep_hitbox() -> void:
	if _melee_hitbox:
		_melee_hitbox.sweep_overlaps()
	for child in get_children():
		if child is Hitbox and child != _melee_hitbox:
			(child as Hitbox).sweep_overlaps()

## Whether this character is still inside its Downed self-right window (i.e.
## NOT yet sealable). Hitbox needs this from the outside to decide seal vs.
## downed/stagger without reaching into the private var directly.
func is_self_rightable() -> bool:
	return _downed_self_rightable

## Client → host RPC (see _physics_process): lets the host keep its own copy
## of _bump_active_time_left in sync with a remote peer's bump press, since
## the host never runs this character's input logic itself.
@rpc("any_peer", "call_local", "reliable")
func _rpc_notify_bump() -> void:
	if NetworkManager.is_networked() and NetworkManager.is_host():
		_open_bump_window()

## Client → host RPC (B-02): a non-host activator's own copy of `ability` already
## ran _do_activate() locally (see the special_ability check above) for its
## cosmetic effect, but its spawned hitbox only exists in that peer's own scene
## tree, where hitbox.gd refuses to resolve anything (host-only). This tells
## the host to run activate() on ITS OWN copy of this character/ability
## instead, so the authoritative resolving hitbox actually exists on the host.
@rpc("any_peer", "call_local", "reliable")
func _rpc_notify_ability_activate() -> void:
	if NetworkManager.is_networked() and NetworkManager.is_host() and ability:
		ability.activate(self)

## Host → target-owner RPC: the host is the only peer that decides hit
## outcomes now (see hitbox.gd), but state authority for THIS character still
## lives with its own owning peer (MultiplayerSynchronizer replicates `state`
## from the authority outward). So the host tells the owning peer what
## happened, that peer applies it locally exactly like the old local-only
## flow, and the existing synchronizer replicates the resulting state to
## everyone else — no change needed there.
##
## B-66: this used to also call _flash_hit() here, but rpc_id() only ever
## targets the STRUCK character's own owning peer — every other peer watching
## the hit land saw no feedback at all. State resolution stays exactly here,
## on the authority; the cosmetic half moved to _rpc_play_hit_vfx below,
## broadcast to everyone.
@rpc("any_peer", "call_local", "reliable")
func _apply_hit_result(kind: String, duration: float, knockback: Vector3 = Vector3.ZERO) -> void:
	match kind:
		"stagger":
			apply_stagger(duration)
		"downed":
			go_downed()
		# The lucky fall. ⚠️ The roll is NOT made here — `kind` already carries the
		# host's decision, so every peer running this function reaches the same
		# answer. Rolling here would give each peer its own.
		"downed_lucky":
			go_downed(false)
		"seal":
			seal()
		"dent":
			apply_dent(duration)
	# AFTER the state transition, deliberately. apply_stagger()/apply_dent()
	# no-op a guarded or already-Downed hit, and a shove that landed anyway
	# would be the one visible sign of a hit that the rules just said did not
	# happen. `knockback` is already zero for a guarded hit
	# (hurtbox.gd::absorb_knockback), and apply_knockback() re-checks the states
	# that block it — see there.
	apply_knockback(knockback)

## THE FACESLOP, RECEIVING END. `impulse` is metres/second, already scaled by
## this character's own Hurtbox (hurtbox.gd::absorb_knockback) — this function
## only decides whether the body is in a state that can be moved at all, and
## then moves it.
##
## ⚠️ THERE IS NO RAGDOLL IN THIS PROJECT, AND THIS IS NOT ONE. DOWNED is a
## state on the existing machine (go_downed), and character_visual.gd renders it
## as a tilt — nothing simulates limbs. What "physically knocked backward" means
## here is that the CharacterBody3D keeps its own momentum through the knockdown:
## the impulse goes into `velocity` and the ordinary move_and_slide/gravity path
## in _physics_process carries it, so the unit slides and falls exactly the way
## it would from a jump. That is why this is a velocity write and not a new
## physics path — a second one would have to re-implement the confinement clamp,
## the floor check and the round freeze, which is the trap ai_controller.gd's
## class doc already warns about.
func apply_knockback(impulse: Vector3) -> void:
	if impulse.is_zero_approx():
		return
	# ⚠️ NOT BETWEEN ROUNDS. A hit can resolve in the same frame that ends the
	# round (the round-winning tag does exactly that), and networked it can
	# resolve FRAMES LATER still, because _apply_hit_result is an rpc_id to the
	# struck character's own peer. Either way the target may already have been
	# teleported back to its spawn marker by _reset_world(), and shoving it from
	# there is the "players get launched to multiple directions" report. The
	# freeze in _physics_process would swallow the motion anyway; refusing to
	# write the velocity at all means nothing has to.
	if not RoundManager.round_active:
		return
	# SEALED is over — a sealed Can is out of the round and being shoved around
	# afterwards reads as the seal not having stuck.
	if state == State.SEALED:
		return
	if _is_guarding:
		return
	# ⚠️ CLAMPED, AND THE CEILINGS ARE ANCHORED TO NUMBERS THAT ALREADY EXIST.
	# Knockback is the product of four independently-tunable ThrowProfile fields
	# (launch_speed x knockback_scale x mass x faceslop_multiplier), so it is
	# very easy to pick four innocuous-looking values whose product throws a
	# player clean out of the arena. Rather than trusting every future profile to
	# be sane, cap the result:
	#   * horizontal at just above DASH_SPEED (14.0) — the fastest a unit can
	#     legitimately travel under its own power, so a faceslop can out-run a
	#     dash but never by an order of magnitude.
	#   * vertical at just above JUMP_VELOCITY (5.8) — a hit can pop a body
	#     higher than it can jump, but not into orbit. Apex at 7.0 is
	#     v^2/(2*GRAVITY) = 1.2 units.
	# TATAG. Divided BEFORE the clamp, so a sturdy unit is genuinely harder to
	# shift rather than merely arriving at the same ceiling more slowly.
	impulse /= trait_grit_scale()
	var flat := Vector2(impulse.x, impulse.z)
	if flat.length() > MAX_KNOCKBACK_SPEED:
		flat = flat.normalized() * MAX_KNOCKBACK_SPEED
	velocity.x += flat.x
	velocity.z += flat.y
	# ⚠️ MAX, NOT +=, ON THE VERTICAL. Two hitboxes can still legitimately
	# resolve on one target in one frame (a slipper's melee box and a teammate's
	# bump, say), and summing lift launches the target into orbit. Taking the
	# larger keeps the biggest hit's pop without ever compounding — and it also
	# means a knockback can only ever help a falling body, never drive it
	# downward into the floor.
	velocity.y = maxf(velocity.y, minf(impulse.y, MAX_KNOCKBACK_LIFT))

## B-66: the cosmetic half of a landed hit, broadcast to every peer (unlike
## _apply_hit_result above, which only ever reaches the struck character's own
## owning peer) — see hitbox.gd for the call site. Deliberately separate from
## state resolution: gameplay outcome must stay exactly where it already was,
## on the authority.
##
## "any_peer", not "authority" — confirmed live: hit resolution always runs
## on the HOST (hitbox.gd), but a struck character's multiplayer authority is
## its OWNING peer, which for any non-host player's own unit is NOT the host.
## An "authority"-mode RPC is only accepted when sent BY that node's own
## authority, so the host calling it on a client's character was silently
## rejected — logged as "RPC '_rpc_play_hit_vfx' is not allowed ... Mode is
## authority" on the receiving client, meaning the VFX never played for any
## hit landing on a non-host player. Same reasoning _apply_hit_result already
## uses "any_peer" for, just missed here initially.
@rpc("any_peer", "call_local", "reliable")
func _rpc_play_hit_vfx(sfx: String = "") -> void:
	_flash_hit(sfx)

## B-44/Q-8: brief white flash + impact particles on a landed hit, any kind,
## on every peer (see _rpc_play_hit_vfx). Camera shake is additionally gated
## to only the struck player's own screen — a shake when a stranger across
## the map gets bumped is noise, not feedback.
##
## 4.1: and the impact SOUND, which is the other half of the same beat.
func _flash_hit(sfx: String = "") -> void:
	_visual.flash_hit()
	# ⚠️⚠️ THE SOUND GOES ON THE LINE ABOVE _hitstop(), AND THAT IS THE POINT.
	#
	# Checklist 4.1 asks for the lata impact "on the EXACT frame hitstop
	# starts", and this is the only place in the codebase where that is
	# expressible: `_hitstop()` is called from here and nowhere else, and this
	# whole function is the broadcast half of a landed hit, so every peer runs
	# these two statements back to back inside one frame.
	#
	# Doing it in hitbox.gd instead — where the sound NAME is chosen, and where
	# it is tempting to also play it — would have been wrong twice over: that
	# code is host-only past its NetworkManager guard, so no client would ever
	# hear a hit; and it runs during physics resolution, a variable number of
	# frames before the visual feedback it is supposed to be synchronised with.
	# The name is decided there and played here, which is why _rpc_play_hit_vfx
	# carries it as an argument.
	#
	# Ordering within the frame does not matter to the mixer (audio is not
	# time-scaled — see audio_manager.gd's class doc), but it matters to anyone
	# reading this later: sound first, then the freeze it is meant to coincide
	# with. Do not reorder them "for tidiness".
	if sfx != "":
		AudioManager.play_at(sfx, global_position)
	_hitstop()
	# AI takeover: is_multiplayer_authority() alone can also be true for an
	# AI-driven character on the host (see camera_rig.gd's own is_mine doc for
	# why) — exclude ai_controller so a hit on an AI-driven unit never shakes
	# the host's own screen for a character nobody there is looking through.
	var is_mine := (is_multiplayer_authority() and ai_controller == null) if NetworkManager.is_networked() else player_id == 1
	if is_mine:
		var rig := get_node_or_null("CameraRig") as CameraRig
		if rig:
			rig.shake()

## 4.5. Dips Engine.time_scale for HITSTOP_DURATION real seconds, restored by a
## SceneTreeTimer that itself ignores the dip (the 4th `create_timer` arg) —
## without that, the restore would take 20x longer than intended, since its
## own countdown would run at HITSTOP_TIME_SCALE too. Guarded against a second
## hit landing mid-dip stomping the first one's restore.
func _hitstop() -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = HITSTOP_TIME_SCALE
	get_tree().create_timer(HITSTOP_DURATION, true, false, true).timeout.connect(_end_hitstop)

func _end_hitstop() -> void:
	Engine.time_scale = 1.0
	_hitstop_active = false

## ---------------------------------------------------------------------------
## 4.1 — STATE-TRANSITION AUDIO
## ---------------------------------------------------------------------------
##
## ⚠️ HOOKED TO THE `state_changed` SIGNAL, NOT TO go_downed()/seal()/
## self_right(). THAT IS NOT A STYLE CHOICE.
##
## Those three functions only ever run on the character's OWN authority — the
## host tells the owning peer what happened and CharacterBase.tscn's
## MultiplayerSynchronizer replicates the resulting `state` outward (see
## _apply_hit_result's own doc). Playing from inside them means the only person
## who ever hears their can go down is the person who was already looking at it.
## `state_changed` fires on every peer, because every peer's synchronizer
## applies the replicated state locally — so this is the one hook that is
## correct in local play, on the host, and on a client, with no extra RPC.
##
## It also catches the transition NOTHING ELSE CAN: `seal()` is called from this
## file's own _physics_process the instant the self-right window lapses
## unrecovered ("if team slipper make the can fall, they win" — no follow-up hit
## required). There is no hitbox behind that one, so the impact path in
## _flash_hit() never sees it, and a round would end in silence.
##
## The overlap with the impact path is deliberate and harmless: a hit-driven
## seal fires this AND _flash_hit() within the same frame, and AudioManager's
## real-millisecond retrigger guard collapses the pair into one play.
func _on_state_changed_audio(new_state: State) -> void:
	match new_state:
		State.DOWNED:
			AudioManager.play_at("lata_knockdown" if is_can else "downed", global_position)
		State.SEALED:
			AudioManager.play_at("lata_seal", global_position)
		State.NORMAL:
			# Only meaningful coming back UP from Downed — which is Quick Stand,
			# or the taya's reset channel completing. Both are "the can is
			# standing again", so both get the sound named after the channel.
			#
			# ⚠️⚠️ B-122 — THIS TRACKS THE PREVIOUS STATE. IT USED TO INFER IT
			# FROM `_downed_time_left > 0.0`, AND THAT WAS THE SECOND HALF OF THE
			# "UNNECESSARY NOISE IN GAMEPLAY" REPORT.
			#
			# `self_right()` clears `_downed_self_rightable` but deliberately
			# does NOT clear `_downed_time_left` — recovering early leaves the
			# remainder of the window sitting there, permanently nonzero. So
			# after any knockdown that was recovered from, EVERY subsequent
			# STAGGERED -> NORMAL transition passed that guard and fired a
			# 450 ms metallic chime. A stagger is a bump; bumps happen
			# constantly; the chime has no visible cause, which is exactly what
			# "a noise that seems unnecessary" describes.
			#
			# Measured with tools/audio_combat_probe.gd: three staggers on a
			# clean unit produced ZERO recovery sounds; three IDENTICAL staggers
			# after one knockdown+self-right produced TWO.
			#
			# A timer that outlives the state it describes cannot stand in for
			# that state. Track the transition itself.
			if _audio_prev_state == State.DOWNED:
				AudioManager.play_at("reset_channel_complete", global_position)
		State.STAGGERED:
			pass # the impact that caused it already sounded — see _flash_hit
	_audio_prev_state = new_state

## Maps a base action name to its input action. Since 2026-07-29 that mapping is
## the identity — the suffix is gone and this exists only so every call site
## still routes through one place.
##
## ⚠️ THERE IS EXACTLY ONE ACTION SET NOW, AND `player_id` NO LONGER SELECTS IT.
## User decision, 2026-07-29: "remove p1 p2 bindings bcz we overhauled that plan
## — u can only play as one guy on one pc now." Split-keyboard local 2-player is
## retired, so `*_p1..*_p4` collapsed to one unsuffixed set carrying the old p1
## bindings (WASD / E / mouse). This supersedes B-130, which had networked humans
## force-read p1 while local ones still went by slot; with one set there is
## nothing left to disambiguate.
##
## `player_id` survives as the MATCH-SLOT identity — spawn data ships it and
## `main.gd::_build_spawn_data` still assigns it — it simply no longer decides
## which keys anyone reads.
##
## ⚠️ WHAT NOW KEEPS TWO LOCAL CHARACTERS OFF THE SAME KEYS. It used to be the
## suffix: a parked or AI unit was handed an unbound p3/p4 so its Input reads
## could never collide with a human's. That guard is gone, so the ONLY thing
## separating them is `_ai_driven()` — an AI-controlled character reads
## `_ai_intent` and never touches the `Input` singleton at all. The invariant is
## therefore "at most one local character is AIController-free at a time", and
## `debug_player_switcher.gd` is what upholds it: it takes control by MOVING the
## AIController, not by reassigning `player_id`. If a second local character ever
## ends up with `ai_controller == null`, both will walk on one keypress.
func _action(base_name: String) -> String:
	return base_name

## ---------------------------------------------------------------------------
## PER-CHARACTER INPUT. Read through these, never through `Input` directly.
## ---------------------------------------------------------------------------
##
## ⚠️⚠️ THIS EXISTS BECAUSE `Input` IS A GLOBAL SINGLETON AND THE AI WAS DRIVING
## IT. Read this before routing anything else through `Input`.
##
## AIController used to steer its character by calling
## `Input.action_press("move_left_p%d" % player_id)`. That is process-global
## state keyed only by `player_id`, and `main.gd::_build_spawn_data` hands AI
## slots `player_id = (index % 2) + 3` — so **index 0 and index 2 both get p3**,
## and 1 and 3 both get p4. Two AI characters therefore pressed and released
## the *same* actions, which produced both halves of the 2026-07-29 report:
##
##   * *"they all move together at the exact same time in sync"* — they were
##     literally reading one another's input.
##   * *"they randomly stop and freeze completely"* — `_set_held()` is edge
##     triggered against the controller's OWN belief about what it is holding.
##     Bot A presses `move_left_p3`; bot B, believing that action is not held,
##     calls `Input.action_release("move_left_p3")` and stops BOTH of them. The
##     two beliefs then disagree with the global forever, so neither re-presses.
##
## The fix is not a bigger `player_id` range — a human and an AI on one machine
## can still collide, and a shared global is the wrong shape for per-unit intent
## regardless. An AI-driven character reads its own intent dictionary instead;
## a human-driven one reads the hardware. Nothing else in this file had to
## change: every gameplay read below now goes through `input_*` and neither
## knows nor cares which source answered.
var _ai_intent: Dictionary = {}      ## base action -> bool, this frame
var _ai_intent_prev: Dictionary = {} ## base action -> bool, previous frame

## Where an AI-driven thrower is actually aiming, in world space, or Vector3.INF
## for "not set — fall back to the camera".
##
## ⚠️ THIS EXISTS BECAUSE AN AI HAS NO CROSSHAIR (B-125). `carrier.gd::_aim_point()`
## derives the throw target by ray-casting from the FPP CAMERA, which is correct
## for a human — the crosshair is a screen-space thing and the camera is the only
## node that knows where it points. But a non-mouse-aimed unit's camera follows
## its BODY, and the body's yaw is written by `look_at(position + direction)`,
## i.e. THE DIRECTION IT LAST PRESSED MOVEMENT IN. The attacker's charge leaf
## deliberately stands still, so it threw along whatever bearing it last walked.
##
## Measured consequence, over 20 AI-vs-AI rounds: throws that reached the can, 0.
## Not "few" — zero, at every pursuit setting ever tested. The AI could not score
## because it was never aiming at the target, and no amount of tuning any other
## lever could have shown up while that was true.
##
## Written by `ai_controller.gd::_act_attacker_charge_release()` while charging
## and cleared when it stops. Deliberately NOT a permanent override: a human who
## takes manual control of a bot through the debug switcher gets the camera path
## back, because `_ai_driven()` goes false the moment the controller is disabled.
var ai_aim_point: Vector3 = Vector3.INF

## True when this character is driven by an AIController rather than hardware.
## Public because carrier.gd has to ask the same question — see `ai_aim_point`.
func is_ai_driven() -> bool:
	# A DISABLED controller hands the character back to hardware input — that is
	# the debug switcher taking manual control of a bot mid-match.
	return ai_controller != null and ai_controller.is_enabled()

func _ai_driven() -> bool:
	return is_ai_driven()

## Written by AIController each physics frame, before anything reads it.
func ai_set_intent(base_name: String, pressed: bool) -> void:
	_ai_intent[base_name] = pressed

## Rolls this frame's intent into "previous" so the edge helpers below have
## something to compare against. Called at the END of _physics_process, after
## every consumer has read the frame — see the call site.
func ai_commit_intent_frame() -> void:
	_ai_intent_prev = _ai_intent.duplicate()

func ai_clear_intent() -> void:
	_ai_intent.clear()
	_ai_intent_prev.clear()

## ⚠️ THE EXPLICIT REPLACEMENT FOR THE UNBOUND p3/p4 SUFFIX. Set true on every
## local character except the one the human is driving.
##
## Parking used to be implicit: `debug_player_switcher.gd` handed an unclaimed
## unit `player_id = 4`, and p4 was registered in project.godot but bound to no
## key, so its `Input` reads could never come back true. The 2026-07-29 input
## overhaul collapsed all four suffixes into one action set and took that guard
## with it.
##
## "Just rely on the AIController" is NOT sufficient, and tools/input_probe.gd
## caught it: `main.gd::_attach_ai` never attaches one to `TeamAPerson` (it is
## the human's own default unit), so the moment the switcher moved control
## elsewhere, TeamAPerson stayed AI-free and BOTH units answered the keyboard —
## measured at 2 responders on one keypress, and 3 after two Tabs.
##
## So the guard is a flag now rather than an emergent property of who happens to
## own an AIController. Read by every `input_*` accessor below, so a parked unit
## is deaf to hardware no matter which accessor asks.
##
## ⚠️ Does NOT touch `_ai_intent`. Parking is about the KEYBOARD; an AI-driven
## character still drives itself normally while parked, which is exactly what
## should happen to the three units the human is not currently holding.
var input_parked: bool = false

## True when hardware input reaches this character at all: not AI-driven, and not
## parked. The single place the two guards combine.
func _reads_hardware() -> bool:
	return not _ai_driven() and not input_parked

func input_pressed(base_name: String) -> bool:
	if _ai_driven():
		return _ai_intent.get(base_name, false)
	return _reads_hardware() and Input.is_action_pressed(_action(base_name))

func input_just_pressed(base_name: String) -> bool:
	if _ai_driven():
		return _ai_intent.get(base_name, false) and not _ai_intent_prev.get(base_name, false)
	return _reads_hardware() and Input.is_action_just_pressed(_action(base_name))

func input_just_released(base_name: String) -> bool:
	if _ai_driven():
		return _ai_intent_prev.get(base_name, false) and not _ai_intent.get(base_name, false)
	return _reads_hardware() and Input.is_action_just_released(_action(base_name))

## Godot's `Input.get_vector` equivalent for this character's own source.
func input_vector(neg_x: String, pos_x: String, neg_y: String, pos_y: String) -> Vector2:
	if _ai_driven():
		var v := Vector2(
			(1.0 if _ai_intent.get(pos_x, false) else 0.0) - (1.0 if _ai_intent.get(neg_x, false) else 0.0),
			(1.0 if _ai_intent.get(pos_y, false) else 0.0) - (1.0 if _ai_intent.get(neg_y, false) else 0.0))
		return v.normalized() if v.length() > 1.0 else v
	if not _reads_hardware():
		return Vector2.ZERO
	return Input.get_vector(_action(neg_x), _action(pos_x), _action(neg_y), _action(pos_y))

## Public form of _action(), for the Task 0 carry components (carriable.gd,
## carrier.gd) which read this character's input set from outside this file.
## Deliberately an alias rather than a rename: `_action` has ten call sites in
## here and the string `_action(` is a substring of `play_action(`, so a blanket
## rename is a silent-corruption risk for no benefit.
func action_name(base_name: String) -> String:
	return _action(base_name)

## Task 1 — where a carried tsinelas rides on this character. Forwarded straight
## to CharacterVisual, which is the only thing that knows this model has a
## skeleton, let alone where its arm bone is. Returns null for a unit with no
## hands or whose model has not been instanced yet; callers treat that as "not
## ready", not as an error.
func get_hand_attachment() -> Node3D:
	return _visual.get_hand_attachment()

## Task 1 — lets the carry components ask for an animation without reaching into
## `_visual` themselves. Same contract the bump/throw calls already use: this
## file says WHAT happened, CharacterVisual decides what it looks like and picks
## a clip the model actually has.
func play_visual_action(kind: String) -> void:
	_visual.play_action(kind)

## 4.2 — tells this unit's Visual its body position/yaw was just TELEPORTED
## (a round reset, a KillPlane respawn) rather than walked, so remote-peer
## interpolation snaps to the new spot instead of gliding across the map from
## wherever it was before. No-op for every unit that isn't currently being
## smoothed (the locally-driven character, Local Match, everyone once the
## match isn't networked) — see character_visual.gd::snap_remote_transform.
func snap_visual_interpolation() -> void:
	_visual.snap_remote_transform()

## Art_Direction.md §1 / B-88 — this unit's OWN, currently-applied collision
## capsule height, read from the shape `_apply_role_collision()` just sized
## rather than assumed. Every child node that positions itself relative to
## "the capsule floor" or "the capsule top" — CharacterVisual's model-drop and
## CharacterNameplate's ring/label — must read this instead of hardcoding the
## old shared 1.6, which is exactly the bug B-88 was for the model and is the
## same bug again for the nameplate ring if left alone.
func capsule_height() -> float:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		return (shape_node.shape as CapsuleShape3D).height
	return 1.6

## Companion to capsule_height() — this unit's own current capsule radius, for
## anything sized off the unit's girth rather than its height (the nameplate
## ring's own radius, so it doesn't read as a dinner plate around a can).
func capsule_radius() -> float:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		return (shape_node.shape as CapsuleShape3D).radius
	return 0.4

## Task 0 — true while this unit is a Person with something in its hands, in
## which case `special_ability` is the charge-throw and must NOT also fire the
## ordinary ability (Tag). One button, and holding a slipper is what decides
## which half of it you get.
func _carrier_is_holding() -> bool:
	return _carrier != null and _carrier.held() != null

func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(state)

## Called by KillPlane (B-15/B-35) when this character falls off the arena.
## Stun-only, no elimination — same "straight back in the fight" rule as a
## bump — so this returns to spawn_position rather than sitting anyone out.
func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	snap_visual_interpolation()
	# 4.1. After the teleport, so it plays at the mark rather than at the void
	# the character just fell into — this is the audible half of the
	# "OUT OF BOUNDS" toast main.gd already shows.
	AudioManager.play_at("respawn", global_position)
	# The teleport itself would otherwise register as a huge fall on the next
	# frame and fire the landing thud on top of this. See the landing block in
	# _physics_process.
	_was_airborne = false
	_fall_speed = 0.0

## Called by RoundManager at the start of a new round to clear Downed/Sealed/Staggered
## carryover from the previous round. Does NOT touch position — whatever resets a
## character to its base spot (map-specific) is a separate concern.
func reset_for_new_round() -> void:
	# A unit airborne (jump, knockback) the instant the round ends carries its
	# velocity straight through _place_at_spawn()'s teleport otherwise — spawn
	# markers sit flush with the floor (zero clearance, same as respawn()'s
	# own spot above), so leftover downward velocity can tunnel a Can through
	# the floor before the next move_and_slide() re-establishes floor contact.
	# respawn() already clears this on a KillPlane catch; this path did not.
	velocity = Vector3.ZERO
	_staggered_time_left = 0.0
	_downed_time_left = 0.0
	_downed_self_rightable = false
	# B-17: clear any hazard zones this character was standing in too — a
	# lingering slow effect (or the reverse: a stale exit dropping speed to 1.0
	# under a still-live zone) shouldn't survive a round reset either way.
	_active_speed_multipliers.clear()
	_speed_multiplier = 1.0
	# B-16: fresh guard stamina and no leftover dash cooldown each round —
	# otherwise a Can that emptied its stamina staying alive to round end
	# would start the next round already unable to block.
	_guard_stamina = GUARD_MAX_STAMINA
	_is_guarding = false
	_dash_cooldown_left = 0.0
	_dash_active_time_left = 0.0
	state = State.NORMAL
	# B-122: before the emit, or a unit that ended the round DOWNED fires a
	# recovery chime at the start of every new round.
	_audio_prev_state = State.NORMAL
	state_changed.emit(state)
	dents = 0
	dents_changed.emit(dents)
	if ability:
		ability.reset_round_charge()
	# Task 0: a slipper still in someone's hand, or still in the air, when the
	# round ends goes back to LOOSE — otherwise round 2 starts with a tsinelas
	# welded to a Person who is no longer even on the attacking side. Runs on
	# every peer without an RPC, same as the team/role recompute in
	# main.gd::_reset_world, because every peer already has the state to do it.
	if _carriable != null:
		_carriable.reset_for_new_round()
	# Roles swap between rounds, so a Prop that was the Can is the Tsinelas now
	# (and vice versa) and needs the other model AND the other collision sizing
	# (Art_Direction.md §1) — a can-sized capsule left over on a tsinelas-shaped
	# Prop is exactly the bug this whole pass exists to remove.
	_apply_role_collision()
	_visual.apply(is_person, is_can, team)
