extends Node
class_name AIController

## Checklist 5.5 — Single Player. Drives one CharacterBase's INPUT exactly the
## way a human at a keyboard would: it writes this character's own per-unit
## intent dictionary (CharacterBase.ai_set_intent), which every gameplay read in
## character_base.gd / carrier.gd / carriable.gd already goes through via
## input_pressed() / input_just_pressed() / input_just_released() /
## input_vector(). Those files are completely unmodified and unaware this
## exists. This is deliberate: the confinement clamp, the Staggered/Downed/
## Sealed state machine and the round-active freeze all already apply correctly
## to ANY input source, so duplicating any of that here (a second physics path)
## would only create a second copy to keep in sync with the first — exactly the
## trap the brief for this item warned against.
##
## ⚠️⚠️ NOTHING IN THIS FILE MAY TOUCH THE GLOBAL `Input` SINGLETON. That was
## B-114 and it produced BOTH reported AI symptoms at once — see _set_held()'s
## own write-up and character_base.gd::input_pressed. `_set_held()` and `_tap()`
## are the only two functions in this file allowed to express an input at all,
## and they go through `character.ai_set_intent()`. If you are adding a
## behaviour, express it through those two; do not reach for `Input`.
##
## The one real consequence of the intent-dictionary choice, worth stating
## rather than discovering by surprise later: character_base.gd calls decide()
## as the FIRST line of its own _physics_process (see the hook there)
## specifically so this node's writes land BEFORE the same frame's input reads,
## not a frame late. Godot does not guarantee _physics_process order between a
## parent and its children, so this could not be left to rely on tree order —
## the explicit call is the only thing making "same frame" true.
##
## Attached as a plain child node of the CharacterBase it drives, added in
## code (`add_child`, never baked into CharacterBase.tscn) by main.gd's
## _attach_ai() — called from _start_local_test() for Single Player's three
## unpiloted units, and, since networked AI takeover, from
## _build_networked_character()/_rpc_convert_to_ai() for a networked slot with
## no live human behind it (an unfilled team/role slot, or a real peer's
## character after they disconnect). The networked call sites only ever
## attach on the HOST's own process — see _build_networked_character's doc
## for why only the host's presses do anything.
##
## ROLE IS RE-DERIVED EVERY CALL, never cached, same rule as everything else
## in this project that reads is_can/is_person/team_is_can_side
## (main.gd::_role_slot, B-76's per-round ability re-pick) — those flip every
## round and a controller that decided its job once at spawn would be playing
## the wrong one by round 2. The behaviour tree below enforces this
## structurally: the role check is a CONDITION re-evaluated on every tick, not
## a branch chosen once.
##
## DIFFICULTY IS OUT OF SCOPE (checklist's own words). Nothing here is tuned
## against a human, has any notion of a mistake, or reacts to a threat sooner
## than its own detection radius allows. The acceptance bar is "moves with
## intent toward its role's job and does not stand still" — not "plays well."
## If a future pass wants better play, it is a new item, not a silent
## extension of this one.
##
## ---------------------------------------------------------------------------
## BEHAVIOUR TREE (2026-07-29 refactor)
## ---------------------------------------------------------------------------
## The four `_update_<role>(repick, delta)` procedures this file used to have
## are gone; the same logic is now a reactive behaviour tree built once in
## _ready() and ticked once per decide(). Nothing about WHAT the bots do
## changed except where noted with a ⚠️ BEHAVIOUR CHANGE comment — the point of
## the refactor is that the role logic is now a data structure you can read,
## trace and re-order for the pending fairness/balance work, instead of four
## nested-`if` procedures where a tuning change means re-reading control flow.
##
## The tree is REACTIVE (no node memory): every tick starts at the root, so a
## higher-priority branch — the Can spotting an incoming slipper, the round
## swapping this unit's role out from under it — pre-empts a lower one on the
## very frame it becomes true, with no "currently running node" to unwind
## first. RUNNING exists and propagates (the Attacker's charge uses it), but it
## only means "this leaf is mid-action, stop evaluating my siblings THIS tick";
## it never pins the tree to a subtree across ticks.
##
## Leaves dispatch by method name against the CONTEXT passed down the tree
## (`ctx`), not against a captured `self`, so the tree holds no reference to
## any one controller and every method name is validated once at build time by
## _validate_tree() rather than failing silently at runtime on a typo.

## How often each role re-picks its current goal (a wander point, a target to
## chase). Every physics frame would be both wasteful and read as twitchy
## rather than purposeful; this is a first-pass number, not tuned.
## ⚠️ SUPERSEDED BY `tier_think` AT EVERY CALL SITE — kept as the documented
## NORMAL value and as the thing the tier table is written against, so a reader
## can still see what the baseline was without opening DIFFICULTY_TIERS.
const DECISION_INTERVAL: float = 0.35
## Stop pressing a movement direction once this close to the current target —
## without a deadzone the AI oscillates across it every frame instead of
## settling, since a single frame's movement usually overshoots a zero-radius
## target entirely.
const ARRIVE_DISTANCE: float = 0.6
const TAYA_DETECT_RANGE: float = 8.0
const TAYA_MELEE_RANGE: float = 1.4
const TAYA_TAP_INTERVAL: float = 0.5
## How far out from the can the Taya plants itself when body-blocking. Far enough
## to actually intercept a throw rather than hugging the can, comfortably inside
## CONFINEMENT_RADIUS so it never presses on its own boundary.
## ⚠️ SUPERSEDED BY `taya_block_standoff` AT ITS ONE CALL SITE — kept as the
## documented NORMAL baseline and as the value the fairness log's runs before
## RUN 9 were all measured at, exactly as DECISION_INTERVAL and
## ATTACKER_CHARGE_TIME already are. Read the `static var` below, not this.
const TAYA_BLOCK_STANDOFF: float = 2.6
## ⚠️ R-01. The lever RUN 3, RUN 7 and RUN 8 each pointed at and which none of
## them could measure, because it was a `const` and `tools/ai_probe.gd` had no
## argument for it. It is a `static var` for exactly the reason
## `taya_pursue_radius` is: `ai_probe.gd`'s fairness mode sweeps it from the
## command line (`standoff=`) without editing this file, which is the only way
## "measured, not assumed" is cheap enough to actually happen.
##
## Geometry that bounds the useful range, so a sweep is read against something
## rather than against nothing: the can sits at the world origin, the attacker
## throws from ATTACKER_THROW_RANGE 6.0, and the Taya is clamped to
## CONFINEMENT_RADIUS 5.0 (character_base.gd::_move_and_confine). A standoff at
## or past ~4.6 therefore puts the post on the Taya's own wall, and a standoff
## near 0 makes it hug the can. `_act_taya_body_block` clamps to
## CONFINEMENT_RADIUS - 0.4 regardless, so values above that are the same run.
##
## ⚠️ NOT IN DIFFICULTY_TIERS YET, deliberately: RUN 9 has to say whether it is a
## lever at all before a tier table is written against it.
static var taya_block_standoff: float = TAYA_BLOCK_STANDOFF

## ---------------------------------------------------------------------------
## R-07 · THE TAYA'S POST IS COMMITTED, NOT RE-DERIVED EVERY TICK.
##
## ⚠️ MEASURED FIRST, THEN WRITTEN — RUN 9's mechanism, not a guess.
## `_act_taya_body_block` used to recompute its post from the attacker's CURRENT
## bearing on every single tick, so the lane was re-closed on the frame the
## attacker arrived anywhere. That is not a defender reading a threat; it is a lane
## that cannot be beaten by movement, only by patience — the same shape as B-124's
## livelock, surviving as a balance problem instead of a hang. RUN 9 measured what
## it costs: at the shipped standoff, 94.7% of 188 throws blocked and 0.05 dents a
## round, with the long rounds running 10-30 consecutive blocked throws.
##
## So the post is COMMITTED. Two conditions have to hold together before the Taya
## will re-post, and requiring BOTH is the whole design:
##
##   1. the reaction window has elapsed (TAYA_POST_HOLD, scaled by `tier_think` so
##      a BATA reacts later than an ASTIG — the tier table already means "how fast
##      does this bot think", and this is exactly that), and
##   2. the attacker has actually moved off the posted bearing by more than
##      TAYA_REPOST_ANGLE — a small slide is not new information.
##
## What that buys, in the language of the game rather than of the code: a taya that
## can be WRONG-FOOTED. A feint means nothing against a defender that re-derives
## its answer every frame, and the attacker's bearing-slide behaviour
## (`_act_attacker_slide_open`, which has existed since B-124) has never had
## anything to earn. Now it does.
##
## Both knobs are `static var` for the reason R-01 exists: a lever that needs a
## source edit per row is a lever nobody sweeps. `posthold=` and `repost=` on
## tools/ai_probe.gd.
## ---------------------------------------------------------------------------

## Seconds the post is held before a re-post is even considered, at NORMAL. Scaled
## by tier_think / DECISION_INTERVAL at the call site, so it tracks the tier's own
## reaction speed rather than needing a fourth column in DIFFICULTY_TIERS.
##
## ⚠️ 1.6, NOT THE ~0.25-0.5 R-07 GUESSED, AND THE DIFFERENCE IS THE WHOLE ITEM.
## Measured (fairness log RUN 14): at 0.35 the committed post changed almost nothing —
## 78.1% of throws still blocked and **0 of 73 released while the post was wrong** —
## because the window has to outlast the thing it is supposed to be beaten by. The
## attacker's charge is 0.42-0.98 s (`_flat_hold_time`), so a taya that re-posts after
## 0.35 s simply re-posts DURING the wind-up and the slide can never earn anything.
## Swept {0.35, 0.70, 1.10, 1.60} x {0.35, 0.50, 0.55, 0.70}: the block rate falls
## monotonically as the hold crosses the charge time, exactly as that mechanism
## predicts, and lands at 44.4% here.
##
## Scaled by tier, so BATA holds ~2.3 s (slow, very beatable) and ASTIG ~1.0 s.
const TAYA_POST_HOLD: float = 1.6
static var taya_post_hold: float = TAYA_POST_HOLD
## How far the attacker's bearing (measured AT THE CAN, so it is the angle that
## actually decides whether the post still covers the lane) must swing before the
## Taya believes the threat has moved. 0.35 rad ~ 20 degrees; at the 6.0 throwing
## line that is ~2.1 units of arc, comfortably more than ATTACKER_LANE_CLEARANCE
## (1.3) so a re-post only happens when the old post genuinely no longer blocks.
## ⚠️ 0.50, measured in the same sweep. Below ~0.5 the taya re-posts on slides small
## enough that the old post still covered the lane; above it, it stops reacting to real
## repositioning. Note the counter that judges this item ("throws released while the
## post was already wrong") uses THIS value as its threshold, so a wider angle both
## lowers the block rate and raises the bar it is measured against — read the two
## together, never one alone.
const TAYA_REPOST_ANGLE: float = 0.50
static var taya_repost_angle: float = TAYA_REPOST_ANGLE
## Distance from the can an Attacker tries to hold before charging — mirrors
## the map's own throwing line (Art_Direction.md §9's 6-unit derivation).
## This file does not import that constant; it just aims for the same number
## so the AI throws from roughly where a human would.
const ATTACKER_THROW_RANGE: float = 6.0
## ⚠️ THE INNER EDGE OF THE THROWING BAND, AND IT IS A MEASURED BUG FIX, NOT A
## PREFERENCE. `_cond_attacker_out_of_range` used to ask only "am I further than
## ATTACKER_THROW_RANGE", so an attacker standing THREE units from the can was "in
## range" and charged from there — inside `taya_pursue_radius`, inside the defended
## box, a step away from `TAYA_MELEE_RANGE`.
##
## Measured, RUN 10's per-round table: the two Persons open a round 7.8 units apart,
## and a fifth of all rounds still ended in a TAG AT 1.4-1.7 SECONDS with exactly
## one throw taken — every one of them a round in which the attacker's opening
## position was already inside the box, so the taya's `close-gap` branch simply
## sprinted at it and tagged it before the round had begun. A tag 1.4 s after the
## whistle is not a defender outplaying anyone; it is the offence standing in the
## wrong place.
##
## 4.6 is derived, not picked: `taya_pursue_radius` ships at 1.8 and
## `TAYA_MELEE_RANGE` is 1.4, so the taya can reach 3.2 from the can before it has
## to break off its own post. 4.6 keeps the attacker a clear 1.4 outside that, which
## is one more melee range of margin. The band [4.6, 6.0] is 1.4 wide — wider than
## ARRIVE_DISTANCE (0.6), so an attacker settling inside it does not immediately
## read as out of it and start walking again.
const ATTACKER_MIN_THROW_RANGE: float = 4.6
static var attacker_min_throw_range: float = ATTACKER_MIN_THROW_RANGE
const ATTACKER_GRAB_RANGE: float = 1.5
## Minimum gap between grab presses. Long enough that `_tap()`'s own
## RELEASE_SETTLE_FRAMES window closes and the key genuinely comes back up, so the
## next press is a new `input_just_pressed` edge — see _act_attacker_retrieve.
const ATTACKER_GRAB_INTERVAL: float = 0.22
## ⚠️ SUPERSEDED BY `tier_charge` at both call sites, same as DECISION_INTERVAL.
const ATTACKER_CHARGE_TIME: float = 0.65
const ATTACKER_RETREAT_DISTANCE: float = 3.0
## How close a defender has to be to the attacker->can line to count as blocking
## it. Roughly a Person's own width plus the slipper's, so a defender genuinely
## in the way registers and one merely nearby does not.
const ATTACKER_LANE_CLEARANCE: float = 1.3
const TSINELAS_ARRIVE_DISTANCE: float = 1.0
## ⚠️ THE SINGLE BIGGEST BALANCE LEVER FOUND SO FAR, AND IT IS A `static var`
## RATHER THAN A `const` ON PURPOSE — tools/ai_probe.gd's fairness mode sweeps
## it from the command line (`pursue=`) without editing this file, which is the
## only way "measured, not assumed" is cheap enough to actually happen.
##
## How far from the base circle the Taya will abandon its blocking post and
## charge the attacker to tag it. 0.0 disables pursuit entirely (pure
## body-blocking, which is what this file did before the behaviour-tree pass).
##
## ⚠️ MEASURED, 2026-07-29, 20 rounds per value, Option A — full table in the
## fairness log (docs/Checklist.md §9). AT THE TIME, a tag by the defending Person
## ended the round outright (hitbox.gd's own rule, not this file's) — that branch
## is deleted as of 2026-07-30 (`Design.md` §1), so read "by tag" below as history:
## the table is kept for what it says about pursuit distance, not for what a tag
## was worth, which no longer applies to anything. So pursuit was not a small
## adjustment, historically:
##     0.0 -> defence 100%, 12/20 by tag,  8/20 timeout, longest still-run 23.6s
##     2.0 -> defence 100%, 10/20 by tag, 10/20 timeout, longest still-run 30.9s
##     5.0 -> defence 100%, 20/20 by tag,  0/20 timeout, longest still-run  2.0s
## Every value gives the defence 100%, because the offence currently cannot win
## at all (B-119/B-120 in the same log) — so this knob does not decide fairness
## today, it only decides HOW the defence wins.
##
## ⚠️ NO LONGER 0.0. Human call: *"ensure the defender AI actively tries to tag
## attackers."* At 0.0 the Taya never leaves its blocking post, so the only leaf
## that could ever act on a threat in melee could only ever fire if the attacker
## walked into it. That is body-blocking, not engaging, and the report is correct
## that it does not look like a defender playing.
##
## ⚠️⚠️ THE MEASUREMENTS ABOVE ARE ALL PRE-TAG-DELETION, AND ARE KEPT FOR THE
## GEOMETRY ARGUMENT, NOT THE OUTCOME. "Won by tag" and "20/20 by tag" describe a
## mechanic that ended the round outright on contact (`person_action.gd`,
## `hitbox.gd`'s round-win-by-tag branch — both deleted 2026-07-30, `Design.md` §1:
## "The defence no longer has an instant win at all"). What replaced it is the
## charged bump meter on `special_ability` (Design.md §4), which staggers and drops
## the attacker's slipper on a full charge but does not end the round by itself —
## see `_act_taya_manage_bump`. The GEOMETRY these numbers measured still holds
## (how far a Taya can usefully chase without abandoning the can), which is why the
## radius is unchanged; the WORDING that follows should be read as "closes to melee
## and lands a bump", not "tags".
##
## ⚠️ 3.6, NOT 5.0, AND THE DIFFERENCE IS THE WHOLE MEASUREMENT ABOVE. 5.0 is
## CONFINEMENT_RADIUS, i.e. "chase anywhere in my box", and it measured 20/20
## rounds won this way. 3.6 sits INSIDE the box: the Taya holds its post while the
## attacker is out at the 6.0 throwing line, and breaks off to chase only once the
## attacker crosses into the defended area — which is exactly the moment it has to
## come in and fetch its own tsinelas. So the Taya closes on the threat worth
## closing on and does not abandon the can to sprint at a thrower it can never reach.
##
## ⚠️ THE TABLE ABOVE PREDATES ATTACKER EVASION. Those runs were recorded when the
## attacker had no dodge at all (`_act_attacker_dodge` did not exist), so 5.0's
## 100% is an upper bound on a defence that could not be evaded, not a current
## number. Re-measure with `tools/ai_probe.tscn -- fairness pursue=` before
## treating any of it as live.
##
## Set from `DIFFICULTY_TIERS` in _ready(); still a `static var` so ai_probe can
## sweep it from the command line without editing this file.
static var taya_pursue_radius: float = 1.8

## ---------------------------------------------------------------------------
## DIFFICULTY TIERS
##
## The fairness log's item 6 has asked for tiers rather than one-off nerfs since
## the first pass, and three separate knobs in this file carry a "⚠️ THIS IS A
## DIFFICULTY KNOB" note pointing at it. This is that, kept deliberately small:
## four numbers, one dictionary, no new machinery.
##
##   pursue   how far from the base circle the Taya will break off to tag.
##   lead     how much of the can's velocity a throw leads by, 0..1.
##   think    seconds between goal re-picks; a slower bot reacts later.
##   charge   seconds the attacker holds a throw, i.e. how hard it throws.
##
## ⚠️ NOT PLAYER-FACING YET, and deliberately so — a difficulty selector is a UI
## and a saved preference, and shipping the mechanism first means the selector is
## one screen rather than a refactor. NORMAL reproduces this pass's tuning.
enum Difficulty { BATA, NORMAL, ASTIG }

##   gait     fraction of SPEED a Person walks at. See `tier_gait`.
##   mistake  chance per goal re-pick that a Taya overcommits. See R-10.
const DIFFICULTY_TIERS: Dictionary = {
	# "Bata" — a kid. Holds its post, aims where the can is rather than where it
	# will be, thinks slowly and never fully winds up. Walks like a kid, too, and
	# overcommits often enough that a human can learn to bait it.
	Difficulty.BATA:   {"pursue": 1.8, "lead": 0.25, "think": 0.50, "charge": 0.40,
		"gait": 0.80, "mistake": 0.22},
	Difficulty.NORMAL: {"pursue": 1.8, "lead": 0.60, "think": 0.35, "charge": 0.65,
		"gait": 0.88, "mistake": 0.09},
	# "Astig" — the one who wins. Chases to the edge of its own box and leads
	# almost perfectly.
	Difficulty.ASTIG:  {"pursue": 4.6, "lead": 0.85, "think": 0.22, "charge": 0.80,
		"gait": 0.96, "mistake": 0.02},
}

static var difficulty: Difficulty = Difficulty.NORMAL
## Live tier values, read by the leaves. Separate from the constants they replace
## so a probe sweeping one knob does not have to know about the others.
static var tier_lead: float = 0.6
static var tier_think: float = 0.35
static var tier_charge: float = 0.65

## ---------------------------------------------------------------------------
## GAIT. 🧑 Human ask, 2026-07-30: the AI must not feel *"too FAST or mechanical"*.
##
## `character_base.gd` normalises an AI unit's movement vector, so a bot has exactly
## two speeds available through the intent dictionary — `SPEED` and zero. The only
## honest way to give it a walking pace instead of a sprint is the public speed API
## gameplay already owns: `enter_speed_zone()` / `exit_speed_zone()`, which
## `_recompute_speed_multiplier()` combines by taking the LOWEST active multiplier.
## That composes correctly with everything else — a bot in mud is still mud-slow, and
## the trait scale (BILIS) still applies on top — and it is a one-way dependency
## (debug/AI calls gameplay, never the reverse).
##
## ⚠️ PERSONS ONLY, DELIBERATELY. The two Props already carry speed scales that exist
## for gameplay reasons — `CRAWL_SPEED_SCALE` on a loose tsinelas is the whole reason
## the retrieval scramble is tense — and stacking a third multiplier on the crawl
## would lengthen every round for no readability gain.
##
## ⚠️ REMOVED WHEN THIS CONTROLLER STOPS DRIVING. `set_enabled(false)` is what runs
## when a human takes the unit over, and a human must not inherit the bot's walk.
const AI_GAIT_NORMAL: float = 0.88
static var tier_gait: float = AI_GAIT_NORMAL
## R-10(c). Chance, per goal re-pick, that a Taya overcommits — see
## `_cond_taya_threat_in_confinement`.
static var tier_mistake: float = 0.09

## ---------------------------------------------------------------------------
## R-10's master switch. ON by default, because "an AI that is fun to lose to" is the
## goal state and not an experiment — but switchable (`fun=off` on tools/ai_probe.gd)
## so the three flavour changes can be measured AGAINST their own absence. R-10's
## acceptance is that they do not move the fairness metrics outside the range Stage 1
## lands on, and that is a claim about a difference, so the difference has to be
## measurable.
##
## ⚠️ IT DOES NOT GATE THE GAIT OR THE TURN RATE. Those two answer a separate human
## ask (movement that does not feel mechanical) and are not balance flavour; gating
## them here would make `fun=off` mean two different things at once.
## ---------------------------------------------------------------------------
static var flavour_enabled: bool = true

## Pushes `difficulty` into the live knobs. Static, so a probe or a future
## settings screen can call it once and every controller in the match follows —
## the knobs are static for the same reason.
static func apply_difficulty(tier: Difficulty) -> void:
	difficulty = tier
	var values: Dictionary = DIFFICULTY_TIERS[tier]
	taya_pursue_radius = float(values["pursue"])
	tier_lead = float(values["lead"])
	tier_think = float(values["think"])
	tier_charge = float(values["charge"])
	tier_gait = float(values["gait"])
	tier_mistake = float(values["mistake"])
## Physics frames to wait after releasing the charge-throw button before
## considering pressing ANY held/edge-triggered action again. Measured live,
## not a guess: `input_just_released()` does not become visible until the
## physics frame AFTER the intent write that caused it — `input_pressed()`
## (the level, not the edge) updates the same frame, but the edge itself is one
## frame behind it. Re-pressing on that very next frame (which an unthrottled
## "not holding -> start charging again" check does by default, since
## `carrier.held()` has not gone null yet) overwrites the pending release before
## `carrier.gd::_step_throw()` ever witnesses it, and the throw silently never
## fires — confirmed by adding a direct print inside carrier.gd during this
## item's own testing, not inferred from behaviour alone. `_tap()`'s own hold
## window exists for the same reason, on the press side instead of the release
## side.
const RELEASE_SETTLE_FRAMES: int = 6

var character: CharacterBase = null
## ⚠️ PER-INSTANCE RNG, deliberately not the global `randf()`. Every bot drawing
## from one shared global stream is a subtler version of the same "they behave
## as one" bug: the sequence is shared, so which bot gets which value depends on
## call order, and identical roles called in the same order get correlated
## picks. Seeded from the instance id in _ready(). Nothing in this file may call
## the global randf()/randi()/randf_range() — use `_rng` exclusively.
var _rng := RandomNumberGenerator.new()
var _enabled: bool = true
var _decision_timer: float = 0.0
## True for the one decide() call on which this controller's slow decision
## cadence fires. Read by the leaves that pick a NEW target (a wander point, a
## throwing spot); range checks and movement run every tick regardless, so a
## threat entering range is reacted to on that frame rather than up to
## DECISION_INTERVAL late.
var _repick: bool = false
## World-space point the character is currently walking toward. Meaning
## differs per role (a wander point for Can/Taya, the loose slipper or the
## throwing/retreat spot for Attacker, the retrieving Person for a loose
## Tsinelas) — always re-picked from that role's own leaves, never carried
## over from a different role's use of the same field.
var _move_target: Vector3 = Vector3.ZERO
var _has_move_target: bool = false
## Held-action state THIS controller currently believes it is pressing, so a
## repeated "still want this pressed" call never re-fires a just_pressed edge
## — see _set_held()'s own doc for why that matters for bump/bump-like taps.
var _held_actions: Dictionary = {}
## One-frame taps (bump, Tag, grab) queued for release on the NEXT decide()
## call — see _tap()'s own doc.
var _pending_release: Dictionary = {}
var _attacker_charging: bool = false
var _attacker_charge_time: float = 0.0
var _release_settle_frames: int = 0
var _taya_tap_cooldown: float = 0.0
var _attacker_grab_cooldown: float = 0.0
## R-10 / fairness: how long the Can has had THIS threat in view, and how long until
## it may raise Guard again. See CAN_GUARD_REACTION.
var _guard_seen_for: float = 0.0
var _guard_cooldown_left: float = 0.0
## R-07. The committed post: the bearing FROM THE CAN it was taken on, how much of
## the reaction window is left, and whether there is one at all. Cleared on a role
## change, on losing sight of the threat, and by _release_all().
var _taya_post_valid: bool = false
var _taya_post_bearing: float = 0.0
var _taya_post_hold_left: float = 0.0
## How far the committed post is currently WRONG, in radians — the angle between
## the bearing the post was taken on and the attacker's bearing right now. Public
## (see taya_post_error) because it is the number that says whether a throw beat the
## post or merely met it, and a probe cannot ask that question any other way.
var _taya_post_error: float = 0.0

## ---------------------------------------------------------------------------
## Behaviour tree — node types.
##
## Deliberately tiny and allocation-free per tick: three composites' worth of
## behaviour in ~80 lines, no plugin, no .tres resources, no scene nodes. The
## alternative considered and rejected was one of the BT addons; this file's
## whole job is four roles' worth of decisions and an addon would add a
## dependency, an editor surface and a serialisation format to own for that.
##
## `tick(ctx, delta)` is the only contract. `ctx` is the AIController the tree
## is currently driving — passed DOWN rather than captured, so the tree itself
## is stateless with respect to any one bot (see the class doc).
## ---------------------------------------------------------------------------

class BTNode extends RefCounted:
	## Unnamed enum, so subclasses inherit SUCCESS/FAILURE/RUNNING as plain
	## constants and outside callers can say `AIController.BTNode.SUCCESS`.
	enum { SUCCESS, FAILURE, RUNNING }

	## Shown in the debug trace. Not used for lookup — purely so a trace reads
	## "attacker/throw/lane-blocked" instead of a list of object ids.
	var node_name: StringName = &""

	func _init(p_name: StringName = &"") -> void:
		node_name = p_name

	func tick(_ctx: AIController, _delta: float) -> int:
		return FAILURE

	## Every method name this subtree will dispatch, so _validate_tree() can
	## check them all against the controller once at build time.
	func method_names() -> Array[StringName]:
		return []


class BTComposite extends BTNode:
	var children: Array[BTNode] = []

	## `p_children` is deliberately untyped: an inline `[...]` literal in
	## _build_tree() is a plain Array, and handing one straight to an
	## `Array[BTNode]` parameter is a runtime type error rather than a
	## conversion. `assign()` is the conversion, and it still type-checks every
	## element on the way in.
	func _init(p_name: StringName = &"", p_children: Array = []) -> void:
		super(p_name)
		children.assign(p_children)

	func method_names() -> Array[StringName]:
		var out: Array[StringName] = []
		for child in children:
			out.append_array(child.method_names())
		return out


## Fallback / OR. Ticks children in order and returns the first result that is
## not FAILURE. All children failed -> FAILURE.
class BTSelector extends BTComposite:
	func tick(ctx: AIController, delta: float) -> int:
		for child in children:
			var status: int = child.tick(ctx, delta)
			if status != FAILURE:
				ctx._trace(child.node_name, status)
				return status
		return FAILURE


## AND. Ticks children in order and returns the first result that is not
## SUCCESS. All children succeeded -> SUCCESS.
class BTSequence extends BTComposite:
	func tick(ctx: AIController, delta: float) -> int:
		for child in children:
			var status: int = child.tick(ctx, delta)
			if status != SUCCESS:
				return status
		return SUCCESS


## Leaf base. Dispatches `method` on the CONTEXT rather than on a captured
## object — see the class doc for why.
class BTLeaf extends BTNode:
	var method: StringName = &""

	func _init(p_name: StringName = &"", p_method: StringName = &"") -> void:
		super(p_name)
		method = p_method

	func method_names() -> Array[StringName]:
		var out: Array[StringName] = []
		out.append(method)
		return out


## A predicate. `ctx.<method>() -> bool`, mapped to SUCCESS / FAILURE.
## Conditions are also where the tree's shared "blackboard" gets filled: a
## condition that finds something (a threat, the tracked can, a loose tsinelas)
## stashes it on the controller so the action right after it does not have to
## repeat the same search. See the _bb_* fields.
class BTCondition extends BTLeaf:
	## Set true to make this condition mean NOT <method> — used so a single
	## predicate can serve both sides of a fork without a second method.
	var negate: bool = false

	func _init(p_name: StringName = &"", p_method: StringName = &"", p_negate: bool = false) -> void:
		super(p_name, p_method)
		negate = p_negate

	func tick(ctx: AIController, _delta: float) -> int:
		var ok: bool = ctx.call(method)
		if negate:
			ok = not ok
		return SUCCESS if ok else FAILURE


## Does something. `ctx.<method>(delta) -> int` (one of the status constants).
## An action that always completes returns SUCCESS; one that is mid-something
## and wants its siblings left alone this tick returns RUNNING.
class BTAction extends BTLeaf:
	func tick(ctx: AIController, delta: float) -> int:
		return ctx.call(method, delta)


## ---------------------------------------------------------------------------
## Behaviour tree — the blackboard.
##
## Scratch space shared between a condition and the action that follows it in
## the same Sequence, so "is there a threat?" and "act on the threat" do not
## each run their own O(roster) search. ⚠️ ONLY EVER VALID IMMEDIATELY AFTER
## THE CONDITION THAT WROTE IT, within one tick — never read one of these from
## a branch whose own condition did not just fill it.
## ---------------------------------------------------------------------------
var _bb_slipper: Carriable = null             ## incoming throw the Can is dodging
## R-06 leg 3. The throw the current sidestep was committed against, and the
## world-space spot that step is walking to. Latched together and cleared
## together — a target without its threat is the stale-intent bug B-125 was,
## one layer down.
var _evade_slipper: Carriable = null
var _evade_target: Vector3 = Vector3.ZERO
var _bb_enemy_attacker: CharacterBase = null  ## the Taya's mark
var _bb_own_attacker: CharacterBase = null    ## a loose Tsinelas' own retriever
var _bb_can: CharacterBase = null             ## the tracked Can, for either side
## Last decide() delta, so an argument-less BTCondition can accumulate time.
var _last_delta: float = 0.0
var _bb_loose_tsinelas: Carriable = null      ## the Attacker's slipper, on the floor
var _bb_carrier: Carrier = null               ## this character's own Carrier node

## Root of the tree, built once in _ready().
var _root: BTNode = null

## ---------------------------------------------------------------------------
## Behaviour tree — debug tracing.
##
## Off by default and costing one bool test per composite when off. Turn it on
## from a probe or the debug bar (`AIController.trace_enabled = true`) and
## `bt_trace()` returns the branch path this controller took on its last tick,
## e.g. "root>attacker>throw>lane-blocked". That readout is the actual reason
## this refactor was worth doing: "why is the bot doing that" used to mean
## reading four nested procedures.
## ---------------------------------------------------------------------------
static var trace_enabled: bool = false
var _trace_path: Array[String] = []

## Called by BTSelector for whichever child it settled on. Selectors are the
## only composite that makes a CHOICE, so recording just their picks gives the
## branch path without also logging every condition a Sequence walked through.
## Written innermost-first (the deepest selector resolves before its parent),
## so bt_trace() reverses it back into reading order.
func _trace(child: StringName, status: int) -> void:
	if not trace_enabled:
		return
	if _trace_path.size() > 16:
		return # runaway guard; only one tick's worth is ever interesting
	_trace_path.append(String(child) + ("*" if status == BTNode.RUNNING else ""))

## The branch path taken on the most recent tick, outermost first — e.g.
## "role/attacker-do/throw-how/slide-open*" (the `*` marks RUNNING). Empty
## unless `AIController.trace_enabled` was true for that tick.
func bt_trace() -> String:
	var ordered := _trace_path.duplicate()
	ordered.reverse()
	return "/".join(ordered)

func _ready() -> void:
	character = get_parent() as CharacterBase
	# Stagger the very first decision so four bots spawned on the same frame do
	# not all think on the same frame for the rest of the match. Seeded from the
	# instance id rather than left to a shared global RNG stream, so two
	# controllers created in the same frame cannot draw the same phase.
	_rng.seed = hash(get_instance_id())
	_decision_timer = _rng.randf_range(0.0, tier_think)
	_root = _build_tree()
	_validate_tree()

## ---------------------------------------------------------------------------
## Behaviour tree — the tree itself.
##
## Read top to bottom as priorities. The state guards come first because a
## Downed or Staggered unit has no role behaviour worth running; then the role
## fork, which is a Selector over four mutually exclusive conditions
## re-evaluated every tick, which is what makes the per-round role swap work
## with nothing here having to know a swap happened.
## ---------------------------------------------------------------------------
func _build_tree() -> BTNode:
	return BTSelector.new(&"root", [
		# --- State guards -----------------------------------------------------
		# Downed reacts immediately regardless of the timed decision cadence —
		# waiting up to DECISION_INTERVAL to start self-righting would read as
		# the AI "not noticing" it fell, which is exactly the kind of standing
		# still this item's acceptance bar rules out.
		BTSequence.new(&"downed", [
			BTCondition.new(&"is-downed", &"_cond_is_downed"),
			BTAction.new(&"self-right", &"_act_self_right"),
		]),
		# Staggered/Sealed: nothing to decide, and pressing movement here would
		# just be silently eaten by character_base.gd's own state handling
		# anyway — release so nothing is left "held" for whenever NORMAL
		# resumes.
		BTSequence.new(&"not-normal", [
			BTCondition.new(&"is-normal", &"_cond_is_normal", true),
			BTAction.new(&"stand-down", &"_act_release_move"),
		]),

		# --- Role fork --------------------------------------------------------
		BTSelector.new(&"role", [
			BTSequence.new(&"can", [
				BTCondition.new(&"is-can", &"_cond_role_can"),
				_build_can_branch(),
			]),
			BTSequence.new(&"taya", [
				BTCondition.new(&"is-taya", &"_cond_role_taya"),
				_build_taya_branch(),
			]),
			BTSequence.new(&"attacker", [
				BTCondition.new(&"is-attacker", &"_cond_role_attacker"),
				_build_attacker_branch(),
			]),
			# Anything that is not a Person and not the Can this round is the
			# Tsinelas. Kept as an explicit condition rather than a bare
			# always-true fallback so a future fifth role cannot silently
			# inherit the slipper's behaviour.
			BTSequence.new(&"tsinelas", [
				BTCondition.new(&"is-person", &"_cond_is_person", true),
				_build_tsinelas_branch(),
			]),
		]),
	])

## ⚠️ DRIVE-HOME OUTRANKS EVERYTHING ELSE THE CAN CAN DO, 2026-07-30. `Design.md`
## §5.2/§1: the auto-seal is deleted, the lata always self-rights within
## `DOWNED_MAX_TIME`, and it can no longer lose the round by lying still — it loses
## by being OUTSIDE its own circle when `RoundManager`'s out-of-circle countdown
## reaches zero. Once that clock is running, nothing else this branch could be
## doing — the idle shuffle, dodging a hit that no longer ends the round by itself
## — outweighs closing the distance back to the mark. See `_cond_can_displaced` /
## `_act_can_drive_home`, which read the SAME `RoundManager.can_out_left()` the
## HUD's "LATA OUT" row does, never a re-derived distance of its own.
##
## Evasion still sits above the mark-holding shuffle, just below drive-home: a
## throw connecting while the can is already out only adds a stagger/knockdown on
## top of a clock that is already running, which is not worth abandoning the drive
## home over — but it is still worth not walking face-first into on the way, or
## anywhere near the mark before the countdown even starts.
func _build_can_branch() -> BTNode:
	return BTSelector.new(&"can-do", [
		BTSequence.new(&"drive-home", [
			BTCondition.new(&"is-displaced", &"_cond_can_displaced"),
			BTAction.new(&"return-to-circle", &"_act_can_drive_home"),
		]),
		BTSequence.new(&"evade", [
			BTCondition.new(&"slipper-incoming", &"_cond_slipper_incoming"),
			BTAction.new(&"sidestep-guard", &"_act_evade"),
		]),
		BTSequence.new(&"smash-opportunity", [
			BTCondition.new(&"smash-worth-it", &"_cond_can_smash_worth_it"),
			BTAction.new(&"slam", &"_act_can_smash"),
		]),
		BTAction.new(&"hold-mark", &"_act_can_hold_mark"),
	])

## ⚠️ BODY-BLOCK, DO NOT CHASE — see _act_taya_body_block for the geometry
## argument. Ordered melee > close-gap > block > wander, so the Taya only ever
## leaves its blocking post for a threat it can actually reach.
##
## ⚠️⚠️ "tag" IS GONE. The tap that used to fire here was `person_action.gd`'s Tag,
## deleted along with `hitbox.gd`'s round-win-by-tag branch (`Design.md` §1: "The
## defence no longer has an instant win at all"). What replaced it is the charged
## bump meter on `special_ability` (`Design.md` §4) — a hold-to-commit, mirror of the
## attacker's own charge, not a one-button instant. `_act_taya_manage_bump` runs on
## EVERY tick a threat is visible (not gated behind a melee check the way the tag
## was) because charging has to start before the attacker arrives, not on arrival —
## see its own doc. `melee` below is now only the MOVEMENT half: hold ground while
## the bump resolves, instead of chasing further in.
func _build_taya_branch() -> BTNode:
	return BTSelector.new(&"taya-do", [
		BTSequence.new(&"engage", [
			BTCondition.new(&"threat-in-detect-range", &"_cond_taya_threat_visible"),
			BTAction.new(&"manage-bump", &"_act_taya_manage_bump"),
			BTSelector.new(&"engage-how", [
				BTSequence.new(&"melee", [
					BTCondition.new(&"threat-in-melee", &"_cond_taya_threat_in_melee"),
					BTAction.new(&"hold-ground", &"_act_taya_hold_ground"),
				]),
				BTSequence.new(&"close-gap", [
					BTCondition.new(&"threat-in-box", &"_cond_taya_threat_in_confinement"),
					BTAction.new(&"charge-threat", &"_act_taya_close_gap"),
				]),
				# R-07. Two ways to be at the post, and the trace tells them apart:
				# `hold-post` is a Taya standing where it decided to stand, which is
				# the state an attacker's slide can beat, and `take-post` is it
				# deciding afresh. Split into a Selector rather than hidden inside one
				# action precisely so bt_trace() can show which one happened — the
				# acceptance test for this item is a trace, and a metric you cannot
				# see is the trap this repo keeps falling into.
				BTSelector.new(&"block-how", [
					BTSequence.new(&"hold-post", [
						BTCondition.new(&"post-still-good", &"_cond_taya_post_committed"),
						BTAction.new(&"walk-to-post", &"_act_taya_walk_to_post"),
					]),
					BTAction.new(&"take-post", &"_act_taya_body_block"),
				]),
			]),
		]),
		BTAction.new(&"patrol", &"_act_taya_wander"),
	])

## Two jobs depending on whether this Person currently holds the slipper:
## retrieve it if not, or hold the throwing line and charge-release it if so.
func _build_attacker_branch() -> BTNode:
	return BTSelector.new(&"attacker-do", [
		# ⚠️ EVASION IS THE HIGHEST-PRIORITY ATTACKER BEHAVIOUR, above both
		# retrieving and throwing, because being tagged ends the round outright.
		# Checklist Phase 9 RUN 4: 18 of 20 rounds ended with the attacker being
		# tagged, and the previous note "the attacker never dodges an incoming tag
		# — it only avoids STANDING in a blocked lane" was the standing explanation
		# for the 90/10 split. This is that missing behaviour.
		# ⚠️ EMPTY-HANDED ONLY, AND THAT CONDITION IS THE WHOLE DIFFERENCE BETWEEN
		# THIS HELPING AND HURTING. Measured, RUN 5 vs RUN 4 (Checklist Phase 9):
		# with evasion pre-empting EVERYTHING, the win rate went 90/10 -> 100/0,
		# blocked 56.1% -> 67.2%, dents 0.30 -> 0.00 and throws that reached the
		# can 4 -> 0. An attacker holding a charged slipper ran away from the taya
		# instead of throwing it, so the offence stopped functioning entirely.
		#
		# Fleeing is only ever the right answer when there is nothing better to do
		# with the moment. Holding the slipper, there always is: throw it.
		# ⚠️⚠️ THE PANIC DODGE, AND IT IS THE FIX FOR THE THING THAT ACTUALLY ENDS
		# EVERY ROUND. Measured directly off bt_trace() at the moment of the tag, over
		# 10 rounds: the attacker was tagged in `throw/approach` (4), `retrieve/settle`
		# (2), `retrieve/fetch` (1) and `retrieve/wait-out-the-guard` (1) — i.e. **it
		# was walking, or standing, and in NO case defending itself.** Two reasons, and
		# both are bugs rather than balance:
		#
		#  1. The `evade` sequence below is gated on EMPTY-HANDED (RUN 5's lesson: an
		#     attacker that flees while holding never throws). So for the whole
		#     approach — slipper in hand, walking to the line — the attacker had no
		#     self-preservation at all.
		#  2. `_threatening_defender()` only counted a defender that was CLOSING at
		#     0.35 m/s or more, and `_act_taya_tag` **releases movement to tag**. So at
		#     the exact instant a tag is coming, the taya's velocity is ~0 and the
		#     attacker's own threat test filtered it out. The dodge was blind to the
		#     only defender that could ever hit it.
		#
		# So: a defender at arm's length is an emergency regardless of role state or
		# closing speed, and it out-prioritises everything. It is deliberately NOT the
		# general flee-from-defenders behaviour RUN 5 measured as a disaster — the
		# radius is one melee range plus a margin, and a throw already past its commit
		# point still goes out (see _cond_attacker_panic), so a committed shot is still
		# committed and still readable.
		#
		# ⚠️⚠️ EVERYTHING ABOVE THIS LINE DESCRIBES THE TAG, AND THE TAG IS GONE,
		# 2026-07-30 (Design.md §1 -- person_action.gd and hitbox.gd's round-win-by-tag
		# branch both deleted; "the defence no longer has an instant win at all").
		# "Being tagged ends the round outright" is no longer true of anything: what a
		# defender at arm's length can land now is the charged bump meter on
		# special_ability (Design.md §4), which drops the slipper and staggers on a
		# FULL charge but does nothing of the kind on a bare TAP ("no stagger, no
		# drop" is Design.md's own line for it). So mere proximity is no longer the
		# danger -- _cond_attacker_panic now reacts to the defender's own bump-charge
		# broadcast instead (CharacterBase.observed_bump_charge(), the same wind-up
		# telegraph Design.md says exists precisely "so the attacker can see the
		# commitment and dash, jump or throw through it"). The radius, the
		# commit-fraction override and the empty-handed/holding split above are all
		# still the right shape and are unchanged; only the trigger question changed,
		# from "is a defender near" to "is a defender near AND winding up".
		BTSequence.new(&"panic", [
			BTCondition.new(&"tagger-at-arms-length", &"_cond_attacker_panic"),
			BTAction.new(&"break-away", &"_act_attacker_dodge"),
		]),
		BTSequence.new(&"evade", [
			BTCondition.new(&"empty-handed", &"_cond_attacker_empty_handed"),
			BTCondition.new(&"tagger-closing", &"_cond_attacker_threatened"),
			BTAction.new(&"break-away", &"_act_attacker_dodge"),
		]),
		BTSequence.new(&"retrieve", [
			BTCondition.new(&"empty-handed", &"_cond_attacker_empty_handed"),
			BTSelector.new(&"retrieve-how", [
				# See _release_settle_frames' own doc: for a couple of frames
				# right after releasing a charge, hold off on grabbing anything
				# new (even a DIFFERENT slipper) rather than only guarding the
				# re-press this release was actually about — simpler to reason
				# about than tracking which action the cooldown applies to, and
				# the window is short enough that a still-loose Tsinelas is not
				# going anywhere in it.
				BTSequence.new(&"settle", [
					BTCondition.new(&"post-release-settle", &"_cond_attacker_settling"),
					BTAction.new(&"wait-out-settle", &"_act_attacker_settle"),
				]),
				# ⚠️ DO NOT WALK INTO THE TAYA'S LAP. Measured: 20/20 rounds in RUN 9
				# and RUN 10 ended with the attacker tagged, and the tag comes during
				# RETRIEVAL — the slipper lands near the can, the taya is standing on
				# it, and `go-grab` below used to march straight at it. The slipper
				# already crawls toward its own attacker (`_act_tsinelas_crawl`), so
				# the patient answer exists and nothing was using it: hold outside the
				# defended area and let the tsinelas come out to you.
				BTSequence.new(&"wait-out-the-guard", [
					BTCondition.new(&"own-tsinelas-loose", &"_cond_own_tsinelas_loose"),
					BTCondition.new(&"tsinelas-is-guarded", &"_cond_own_tsinelas_guarded"),
					BTAction.new(&"let-it-crawl", &"_act_attacker_wait_for_crawl"),
				]),
				BTSequence.new(&"fetch", [
					BTCondition.new(&"own-tsinelas-loose", &"_cond_own_tsinelas_loose"),
					BTAction.new(&"go-grab", &"_act_attacker_retrieve"),
				]),
				# Nothing to retrieve (mid-flight, or already thrown and not yet
				# landed) — hold a spot back from the can rather than drifting
				# toward it with empty hands.
				BTAction.new(&"hold-standoff", &"_act_attacker_hold_standoff"),
			]),
		]),
		BTSequence.new(&"throw", [
			BTCondition.new(&"holding", &"_cond_attacker_holding"),
			BTCondition.new(&"can-tracked", &"_cond_can_tracked"),
			BTSelector.new(&"throw-how", [
				BTSequence.new(&"approach", [
					BTCondition.new(&"out-of-range", &"_cond_attacker_out_of_range"),
					BTAction.new(&"walk-to-line", &"_act_attacker_approach"),
				]),
				# ⚠️ IN RANGE, BUT IS THE LANE OPEN? Human call, 2026-07-29: the
				# AI should "fulfil their roles and try to win (attacker avoid
				# defender...)". Standing still and charging into the Taya's
				# chest is not trying to win — it feeds the block.
				BTSequence.new(&"reposition", [
					BTCondition.new(&"lane-blocked", &"_cond_lane_blocked"),
					BTAction.new(&"slide-open", &"_act_attacker_slide_open"),
				]),
				# ⚠️ R-06, THE AI HALF. The third option beside "slide" and "throw
				# into it anyway": go OVER. Reached exactly when the lane is still
				# blocked and patience has been spent — i.e. on the frame the
				# attacker would otherwise feed the block, which RUN 9 measured at
				# 94.7% of 188 throws. Inert until the PHYSICS half lands
				# (`lob_enabled` is false and holding longer currently just throws
				# late at the same power) — see `attacker_lob_overhold`.
				BTSequence.new(&"lob", [
					BTCondition.new(&"lob-worth-it", &"_cond_attacker_should_lob"),
					BTAction.new(&"charge-lob", &"_act_attacker_charge_lob"),
				]),
				BTAction.new(&"charge-release", &"_act_attacker_charge_release"),
			]),
		]),
		# No carrier node at all, or the can is untracked (pre-round). Stand
		# down rather than leaving a movement key held from a previous tick.
		BTAction.new(&"stand-down", &"_act_release_move"),
	])

## Only ever meaningful while LOOSE (Carriable.drives_movement() already
## bypasses this entirely for CARRIED/FLYING — see character_base.gd — so this
## branch is never even reached in either of those states in practice, but the
## check stays explicit rather than assumed).
##
## ⚠️⚠️ THE SLIPPER IS A PLAYER NOW, NOT JUST CARGO. `Design.md` §6: a LOOSE
## tsinelas can charge a self-launch (hold `jump`, 0.75 s to full, 6-13 m/s at
## 0.62 vertical) and Ground Smash off the top of it (`bump` while airborne — a
## 3.2 m shockwave, and a DIRECT hit within 0.75 m of the lata wins the round
## OUTRIGHT). The human's own instruction: "a loose tsinelas AI should prefer
## launching itself toward the can over crawling home when it has line of sight."
## So the priority is diving (if a dive is already committed, nothing may steer
## it — see `_cond_tsinelas_diving`) > smashing (the payoff, the instant the
## height/state window is open) > launching at the can (the preference the human
## asked for) > crawling home (the old, and now second-choice, retrieval) > settle.
func _build_tsinelas_branch() -> BTNode:
	return BTSelector.new(&"tsinelas-do", [
		# ⚠️ MUST OUTRANK EVERYTHING ELSE. `PropSmash.begin_ground_smash` zeroes
		# horizontal velocity on purpose ("a dive that kept its forward speed would
		# be a very fast, very flat throw the slipper aimed itself — a different,
		# much stronger move" — prop_smash.gd's own doc) and this file's own
		# movement leaves would silently reintroduce it: `is-loose` stays true for
		# the whole dive (carry state never changes), so without this guard
		# `launch-at-can`/`crawl-home` would keep pressing compass keys mid-dive.
		BTSequence.new(&"diving", [
			BTCondition.new(&"is-diving", &"_cond_tsinelas_diving"),
			BTAction.new(&"ride-it-down", &"_act_release_move"),
		]),
		BTSequence.new(&"ground-smash", [
			BTCondition.new(&"smash-ready", &"_cond_tsinelas_can_smash"),
			BTAction.new(&"dive", &"_act_tsinelas_smash"),
		]),
		BTSequence.new(&"launch-at-can", [
			BTCondition.new(&"is-loose", &"_cond_tsinelas_loose"),
			BTCondition.new(&"can-sighted", &"_cond_tsinelas_can_launch"),
			BTAction.new(&"self-launch", &"_act_tsinelas_launch"),
		]),
		BTSequence.new(&"crawl-home", [
			BTCondition.new(&"is-loose", &"_cond_tsinelas_loose"),
			BTCondition.new(&"own-attacker-exists", &"_cond_own_attacker_exists"),
			BTCondition.new(&"not-yet-arrived", &"_cond_tsinelas_arrived", true),
			BTAction.new(&"crawl", &"_act_tsinelas_crawl"),
		]),
		# ⚠️ A LOOSE SLIPPER THAT HAS ARRIVED USED TO STOP DEAD, and it was the single
		# biggest contributor to the stillness figure — 12 of 26 episodes over 2 s long,
		# measured with the branch-naming trace. 🧑 "make sure theyre all capable of
		# movement": this is the unit that most visibly was not. It settles now, which
		# for a tsinelas on the ground reads as it shifting where it lies.
		BTAction.new(&"settle", &"_act_tsinelas_settle"),
	])

## Fail fast on a mistyped method name. Leaves dispatch by name (see the class
## doc for why), and a typo would otherwise be an every-frame runtime error
## from inside a tick rather than one line at startup.
func _validate_tree() -> void:
	for method_name in _root.method_names():
		if not has_method(method_name):
			push_error("AIController behaviour tree references missing method: %s" % method_name)

## Called from character_base.gd's own _physics_process, as its first line —
## see this file's class doc for why the order matters. A no-op once
## disabled (see set_enabled) or before this node has a parent character.
func decide(delta: float) -> void:
	_flush_pending_releases()
	if not _enabled or character == null or _root == null:
		return
	# BTCondition leaves take no arguments — the tree calls them by name — so a
	# condition that needs to accumulate time reads it from here. Only
	# _cond_lane_blocked uses it (see ATTACKER_PATIENCE); kept as one assignment
	# rather than threading delta through every predicate signature.
	_last_delta = delta

	if trace_enabled:
		_trace_path.clear()

	_decision_timer -= delta
	_repick = _decision_timer <= 0.0
	if _repick:
		# ⚠️ JITTERED, NOT A FLAT INTERVAL — this is the other half of "they all
		# move together at the exact same time". Every controller started its
		# timer at 0.0 and decremented by the same delta, so all of them
		# re-picked on the SAME physics frame forever, in perfect lockstep. Even
		# with the shared-Input bug fixed that still reads as one hive mind
		# rather than four players. The initial phase is staggered in _ready()
		# and each interval is jittered here, so they drift apart and stay apart.
		_decision_timer = tier_think * _rng.randf_range(0.75, 1.3)

	# Role-scoped cooldowns tick on wall time, not on "the frame that role's
	# branch happened to run", so a role swap mid-cooldown cannot leave one
	# armed forever.
	_taya_tap_cooldown -= delta
	_attacker_grab_cooldown -= delta
	_guard_cooldown_left -= delta
	# R-07's reaction window, ticked here with the other role-scoped timers and for
	# the same reason: on wall time, not on "the frame that role's branch happened to
	# run", so a role swap mid-window cannot leave one armed forever.
	_taya_post_hold_left -= delta
	_taya_overcommit_left -= delta
	_taya_overcommit_cooldown -= delta
	_track_can_velocity(delta)
	# A Person walks at its tier's pace; a Prop is full speed unless a leaf says
	# otherwise (the Can's shuffle, anyone's settle). Reset before the tick so the
	# leaves that run this frame are the only things deciding it.
	_gait_want = tier_gait if character.is_person else 1.0
	# SPRINT, same reset-before-tick shape as the gait line directly above — see
	# `_sprint_want`'s own doc.
	_sprint_want = false

	_root.tick(self, delta)
	# After the tree, never before: whichever leaf actually ran this tick is the one
	# whose pace applies.
	_apply_gait(_gait_want)
	# ⚠️ STAMINA IS FINITE (`Design.md` §2: a 4.0 s bar, 0.8 s regen delay, a 0.6 s
	# floor that forbids feathering it). Writing the held key every tick regardless
	# of `_sprint_want`'s value — not only on change — is deliberate: character_base.gd
	# already treats "not moving" as free even while this is held (`_step_stamina`
	# gates drain on the frame's real movement intent), so there is no idle-holding
	# cost to guard against here the way `_apply_gait` guards against re-registering
	# an unchanged multiplier.
	_set_held("sprint", _sprint_want)

## The gait multiplier this controller currently has registered on its character, or
## 0.0 for none. Tracked so a tier change swaps one for the other rather than
## stacking, since `_active_speed_multipliers` is a list and `exit_speed_zone()`
## removes by VALUE.
var _gait_applied: float = 0.0
## What this tick's behaviour WANTS the gait to be. Set by leaves and applied once,
## after the tree has ticked, so a role or branch change cannot leave a stale
## multiplier registered — the same reason the role itself is re-derived every tick.
var _gait_want: float = 1.0

## SPRINT (`Design.md` §2 / §3). Mirrors `_gait_want` exactly and for the same
## reason: reset in decide() before the tree runs, set true by whichever leaf is
## closing distance or racing to retrieve something THIS tick, and written to the
## actual held intent exactly once, after the tree ticks — never scattered across
## leaves as bare `_set_held("sprint", ...)` calls, which is precisely the kind of
## stale-multiplier bug `_gait_want` already exists to avoid, one input over.
## Absent from a leaf means "not sprinting" by default, which reads naturally as an
## opt-IN per tick — "sprint when closing distance or retrieving, and not when
## posted" is a much shorter list to opt INTO than to opt every posted leaf OUT of.
var _sprint_want: bool = false

## ⚠️⚠️ THIS IS WHY THE CAN BECAME UNHITTABLE, AND IT IS THE MOST INSTRUCTIVE BUG OF
## THE PASS: TWO CORRECT FIXES THAT BROKE EACH OTHER.
##
## Fixing the Can so that it actually moves (see `_act_can_hold_mark`) gave it a
## 0.22-unit shuffle — but `character_base.gd` NORMALISES an AI movement vector, so
## that shuffle is performed at the full `SPEED` of 6.0 m/s. A throw crosses the 5.5-
## unit gap in about a third of a second, in which 6 m/s covers nearly two units. So
## the Can was darting far enough during every flight to be missed by more than the
## width of the arena's own centre circle, in a direction re-rolled every 0.35 s.
##
## Measured with the new closest-approach geometry, which is the only reason this was
## visible at all: **17 flights, median closest approach 2.49 units, and 0 of 12
## unblocked throws within the 0.50 overlap band.** The hitbox was not lying and the
## aim was not broken — the target was leaving.
##
## The fix is not to freeze the Can again. It is that a shuffle should be performed at
## SHUFFLING PACE. 0.30 makes the Can's weight-shift 1.8 m/s, which reads as a keeper
## rocking on the spot instead of a bluebottle, and puts it back inside the band a
## thrown slipper can find. ⚠️ EVASION IS DELIBERATELY EXEMPT — `_act_evade` never asks
## for a slow gait, so a real dodge is still full speed and the can can still save
## itself. The dodge is supposed to be the Can's skill; the fidget never was.
const CAN_IDLE_GAIT: float = 0.30
## Any unit merely settling on a spot it has already reached moves at this fraction of
## SPEED. Same argument as CAN_IDLE_GAIT, applied to the general case: a taya adjusting
## its stance on its post should not do it at a sprint.
const IDLE_GAIT: float = 0.35

func _apply_gait(want: float) -> void:
	if character == null or not is_instance_valid(character):
		return
	if is_equal_approx(_gait_applied, want):
		return
	_drop_gait()
	if is_equal_approx(want, 1.0):
		return # nothing to register; full speed is the absence of a multiplier
	_gait_applied = want
	character.enter_speed_zone(_gait_applied)

func _drop_gait() -> void:
	if _gait_applied <= 0.0:
		return
	if character != null and is_instance_valid(character):
		character.exit_speed_zone(_gait_applied)
	_gait_applied = 0.0

func _exit_tree() -> void:
	_drop_gait()

## Debug-switcher hand-off (Checklist 5.5 item 4): a human taking manual
## control of an AI-driven unit via F1-F4/Tab must not fight the AI for the
## same buttons. Disabling releases every action this controller might be
## mid-press or mid-charge on, so nothing sticks "held" once a human is
## driving instead — see debug_player_switcher.gd's own call site.
func set_enabled(enabled: bool) -> void:
	if _enabled == enabled:
		return
	_enabled = enabled
	if not enabled:
		# ⚠️ THE BOT'S WALKING PACE MUST NOT SURVIVE ONTO A HUMAN. This is the exact
		# function a human take-over runs through (debug_player_switcher, and
		# ai_probe's own takeover in reverse), and a leftover 0.88 multiplier would
		# make the player mysteriously slower than everyone else for the rest of the
		# match with nothing on screen to explain it.
		_drop_gait()
		_release_all()
		# Wipe the intent too, or CharacterBase keeps answering input_pressed()
		# from a stale dictionary while a human is trying to drive — the unit
		# would walk into a wall on its own. See character_base.gd::_ai_driven.
		if character != null:
			character.ai_clear_intent()

## CharacterBase asks this before deciding whether to read intent or hardware.
## A disabled controller (a human took manual control via the debug switcher)
## must hand the character straight back to the keyboard.
func is_enabled() -> bool:
	return _enabled

func _release_all() -> void:
	_release_move(0.0)
	for base in ["bump", "special_ability", "grab", "guard_dash", "sprint"]:
		_set_held(base, false)
	_pending_release.clear()
	_attacker_charging = false
	_attacker_charge_time = 0.0
	_attacker_hold_target = -1.0
	_release_settle_frames = 0
	_attacker_lane_blocked_for = 0.0
	_taya_overcommit_left = 0.0
	_heading = Vector3.ZERO
	_guard_seen_for = 0.0
	_guard_cooldown_left = 0.0
	# R-07: a post is only ever valid against the attacker it was taken on, and
	# _release_all() runs on exactly the events that replace it (a role swap, a round
	# reset, a human taking this unit over).
	_taya_post_valid = false
	_taya_post_hold_left = 0.0
	_taya_post_error = 0.0
	# Hand the camera-based aim back. _release_all() is what runs when a human
	# takes this unit over or the round resets, and either way an AI's stale
	# target must not survive into someone else's throw (B-125).
	if character != null and is_instance_valid(character):
		character.ai_aim_point = Vector3.INF
	_clear_blackboard()

func _clear_blackboard() -> void:
	_bb_slipper = null
	# R-06 leg 3 — cleared with the blackboard it belongs to. A latched sidestep
	# surviving a round reset or a human takeover is exactly B-125's stale intent.
	_evade_slipper = null
	_evade_target = Vector3.ZERO
	_bb_enemy_attacker = null
	_bb_can = null
	_bb_loose_tsinelas = null
	_bb_carrier = null

## ---------------------------------------------------------------------------
## Leaves — state guards and role predicates.
##
## Everything below is a behaviour-tree leaf. Conditions take no arguments and
## return bool; actions take `delta` and return a BTNode status constant. That
## uniformity is the whole point — a leaf is testable and re-orderable on its
## own, which four nested `if` chains were not.
## ---------------------------------------------------------------------------

func _cond_is_downed() -> bool:
	return character.state == CharacterBase.State.DOWNED

func _cond_is_normal() -> bool:
	return character.state == CharacterBase.State.NORMAL

func _cond_is_person() -> bool:
	return character.is_person

func _cond_role_can() -> bool:
	return character.is_can

func _cond_role_taya() -> bool:
	return character.is_person and character.team_is_can_side

func _cond_role_attacker() -> bool:
	return character.is_person and not character.team_is_can_side

func _act_self_right(_delta: float) -> int:
	_release_move(0.0)
	_set_held("bump", character.is_self_rightable())
	return BTNode.SUCCESS

func _act_release_move(_delta: float) -> int:
	_release_move(0.0)
	return BTNode.SUCCESS

## ---------------------------------------------------------------------------
## Leaves — Can.
## ---------------------------------------------------------------------------

## ⚠️ THE CAN HOLDS ITS CIRCLE. IT DOES NOT WANDER THE BOX.
##
## This used to pick `_random_point_in_confinement(0.6)`, which walks the Can up
## to ~3 units off the base circle. Two things were wrong with that, and the
## second is what got reported:
##
##  1. **It is not the sport.** Tumbang preso is played around a can STANDING on
##     its mark. The whole defending job is to keep it there; a can that strolls
##     off on its own has nothing left to defend.
##  2. **It reads as teleporting.** Every round reset snaps the Can back to
##     Spawn0, so a Can that had wandered visibly jumped across the arena the
##     instant the round turned over. Reported repeatedly as "can keeps on
##     teleporting", and measured with `render_probe.gd`'s `canwatch` mode:
##     velocity a constant 6.0 on a diagonal, then a 1.4-1.8 unit jump back to
##     (0, 0.17, 0) on the transition. The teleport was never the bug — it was
##     the reset correcting a drift that should not have happened.
##
## It still shifts, because a completely static Can reads as a prop rather than
## as a unit and the pillar says take funny — but only within the base circle
## itself, so it never leaves the mark and the reset never has to yank it.
## `base_circle_decal` is 1.4 across, so 0.45 keeps it comfortably inside.
const CAN_HOLD_RADIUS: float = 0.45

## --- Evasion. Playtest 2026-07-29: "the Can (lata) AI doesn't work. It just
## --- stands completely still ... it needs a functioning evasion state."
##
## The Can genuinely had no reactive behaviour at all: the hold-the-circle
## behaviour only ever shuffled inside a 0.45 circle, which is below the speed
## threshold any observer would call movement, and nothing in this file ever
## looked at a slipper.
##
## ⚠️ THESE NUMBERS ARE A BALANCE SURFACE, NOT PHYSICS. A Can that dodges
## perfectly makes the game unwinnable — the whole sport is hitting it. They are
## tuned so a well-aimed throw still lands and a lazy one gets punished, and they
## are the first thing to revisit when the fairness log's win-rate numbers exist.
##
## ⚠️ MEASURED SWEEP, 2026-07-29 (tools/phys_probe.gd, 12 identical dead-centre
## throws — a deliberate worst case, since every throw is perfectly aimed from
## one fixed spot). Contact frames against evasion movement:
##     lookahead 1.10 -> 18 contact frames, 86% moving   (near-unhittable)
##     lookahead 0.70 -> 0                               (UNWINNABLE)
##     lookahead 0.85 -> 57, 72% moving
##     lookahead 0.55 -> 35, 75% moving
## Non-monotonic because the throws are identical and the outcome turns on exact
## sidestep phase — which is itself the reason not to trust a synthetic probe for
## balance. Shipped values sit on the hittable side on purpose; a Can that cannot
## be hit is a broken game, not a hard one.
## How far ahead a throw is tracked, in seconds.
const CAN_EVADE_LOOKAHEAD: float = 0.6
## Only dodge throws that would otherwise come this close, in units.
##
## ⚠️ LOWERED 1.0 -> 0.55, 2026-07-29, on a human call after this was measured
## with `tools/hit_probe.tscn -- --host target=can`: **aiming dead at the can's
## own hurtbox centre at full charge, only 12 of 40 throws made contact at all.**
## That made the can's dodge, not aim and not spread and not the hitbox, the
## single biggest reason a throw misses.
##
## The nerf is deliberately to the MARGIN and not to the lookahead. At 1.0 the can
## dodged anything that would pass within a metre — i.e. it spent most of its
## evasion budget dodging throws that were going to miss anyway, and its own
## sidestep is what then carried it INTO some of them. 0.55 is just above the real
## overlap band for the tightest profile (hurtbox 0.17 + `throw_flick`'s
## hit_radius 0.30 = 0.47), so the can now dodges throws that would genuinely have
## hit it and ignores the rest.
##
## ⚠️ DO NOT "TUNE" THIS BY MOVING CAN_EVADE_LOOKAHEAD INSTEAD. The sweep recorded
## above is non-monotonic — 1.10 gives 18 contact frames, 0.85 gives 57, 0.70
## gives 0 — because those throws are identical and the outcome turns on exact
## sidestep phase. A lever whose response is not monotonic cannot be tuned; the
## margin's is.
const CAN_EVADE_MISS_MARGIN: float = 0.55
## How far to the side one sidestep aims.
const CAN_EVADE_STEP: float = 1.2
## Never sidestep further than this from the base circle.
const CAN_EVADE_RADIUS: float = 1.8
## Below this time-to-impact, stop dodging and spend the Can-Dash instead.
const CAN_GUARD_ETA: float = 0.22
## ---------------------------------------------------------------------------
## ⚠️⚠️ THIS BLOCK USED TO BE ABOUT GUARD, AND GUARD IS DELETED. `Design.md` §1: "Can
## Guard (hold to block a hit outright) ... nullified the attacker's one window per
## throw. Replaced by Can-Dash and Can-Smash, which are commitments rather than a
## hold." `character_base.gd::is_guarding()` now always returns false and
## `apply_dent()`/`apply_stagger()` can never be blocked outright by anything this
## file presses — the paragraph below describing a can that ate 0 dents behind a
## reactive Guard is describing a mechanic that no longer exists.
##
## What survives, and what this block is actually about now: `guard_dash` still names
## an input action, but it now fires the Can's own one-per-round CAN-DASH (`Design.md`
## §5.3 — 16.0 m/s for 0.18 s, ONE use, never a hold). The trigger below — react once
## a throw's time-to-impact drops under `CAN_GUARD_ETA`, no sooner than
## `can_guard_reaction` lets the can notice it, no more often than `can_guard_cooldown`
## — already happens to be the right shape for "spend it to dodge an incoming throw,
## not casually" (Design.md §5.3's own words for Can-Dash): react late enough that a
## dash is not wasted on a throw that would already miss, and do not re-trigger every
## single tick a throw stays in the danger band. The COOLDOWN framing is now cosmetic
## — `character_base.gd::_can_dash_spent` is what actually stops a second spend inside
## one round, not this timer — but it is kept because it still does its real job:
## rate-limiting how often this leaf ATTEMPTS the press, which is worth doing even
## when the attempt beyond the first is a free no-op in the game itself.
##
## ⚠️ NOT A NERF TO THE DODGE. `CAN_EVADE_MISS_MARGIN` is a human-called value (RUN 7)
## and `CAN_EVADE_LOOKAHEAD` is documented as untunable. Neither is touched.
## ---------------------------------------------------------------------------
## Minimum time a throw must have been visible before the can may react by spending
## its dash, scaled by the tier's own thinking speed at the call site.
const CAN_GUARD_REACTION: float = 0.12
static var can_guard_reaction: float = CAN_GUARD_REACTION
## Enforced gap between dash ATTEMPTS — see the block comment above for why this is
## no longer a real cooldown (the dash itself is one-per-round, tracked on
## `character_base.gd`) and is kept anyway as an input rate-limiter.
const CAN_GUARD_COOLDOWN: float = 1.4
static var can_guard_cooldown: float = CAN_GUARD_COOLDOWN

## Is there a tsinelas currently in the air and actually coming at us?
##
## ⚠️ "IN THE AIR" IS NOT ENOUGH — it must be CLOSING. A slipper that has already
## flown past, or one arcing away after a miss, is not a threat, and reacting to
## it is what would make the Can look like it is dodging ghosts. Closing speed
## along the line to us has to be positive and the predicted miss distance small.
func _cond_slipper_incoming() -> bool:
	_bb_slipper = null
	var best_eta := CAN_EVADE_LOOKAHEAD
	for other in _roster():
		if other == null or not is_instance_valid(other):
			continue
		if other.is_person or other == character:
			continue
		var c := other.get_node_or_null("Carriable") as Carriable
		if c == null or c.state != Carriable.CarryState.FLYING:
			continue
		var to_us := character.global_position - other.global_position
		to_us.y = 0.0
		var vel := other.velocity
		vel.y = 0.0
		var speed := vel.length()
		if speed < 0.5:
			continue
		var closing := vel.normalized().dot(to_us.normalized())
		if closing <= 0.2:
			continue # flying past or away, not at us
		var eta := to_us.length() / speed
		if eta > CAN_EVADE_LOOKAHEAD:
			continue
		# Perpendicular miss distance: how far off centre this throw currently is.
		var along := to_us.dot(vel.normalized())
		var miss := (to_us - vel.normalized() * along).length()
		if miss > CAN_EVADE_MISS_MARGIN:
			continue
		if eta < best_eta:
			best_eta = eta
			_bb_slipper = c
	# R-06 leg 3 · HOLD THE STEP UNTIL A LOB HAS ACTUALLY LANDED.
	#
	# ⚠️ THIS IS WHY THE CAN "CAME HOME" MID-LOB, AND IT IS THE LOOP ABOVE, NOT
	# THE STEP. Every gate up there is computed on the HORIZONTAL velocity: the
	# `speed < 0.5` reject, the `closing` dot and the perpendicular `miss` all
	# zero `vel.y` first. A descending lob's horizontal component collapses as it
	# comes down, and `to_us` shrinks toward zero while the slipper is overhead,
	# so the geometry degenerates exactly when the throw is most dangerous: the
	# threat stops registering, the tree falls through to hold-the-circle, and
	# the Can walks back onto the mark to be hit. Measured (`phys_probe -- band`,
	# 🥊 PHYS): peak sidestep 0.84 m against a lob, but only **0.31 m** at the
	# closest frame, inside the lob's own 0.45 m band.
	#
	# ⚠️ SO THE FIX IS NOT A WIDER STEP. `CAN_EVADE_STEP` already aims 2.7x the
	# measured band and widening it moves the peak, which was never the problem.
	# A lob already seen stays the threat until it is no longer FLYING.
	#
	# ⚠️ LOBS ONLY, on `Carriable.flight_is_lob` — set from the launch broadcast
	# on every peer, so the Can answers a lob without re-deriving it from the
	# trajectory. A flat throw crosses in 0.32 s and there is no tail to hold
	# through; holding for one would only make the Can dodge things that have
	# already missed, which is the behaviour CAN_EVADE_MISS_MARGIN exists to stop.
	# ⚠️ THE RESTORE HAS TO COME BEFORE THE RE-LATCH, AND THE FIRST CUT OF THIS
	# HAD IT THE OTHER WAY ROUND AND SILENTLY DID NOTHING. Written as one
	# "different threat? re-latch" test up front, the null the loop leaves on the
	# frame the lob stops registering counts as a different threat — so the latch
	# cleared itself one frame before the branch that was supposed to read it.
	# Measured, not spotted: `phys_probe -- band` still reported the can peaking
	# at 0.84 m and coming back to 0.40 m by the closest frame, i.e. exactly the
	# behaviour the change was meant to remove.
	if _bb_slipper == null:
		if _evade_slipper != null and is_instance_valid(_evade_slipper) \
				and _evade_slipper.flight_is_lob \
				and _evade_slipper.state == Carriable.CarryState.FLYING:
			_bb_slipper = _evade_slipper
		else:
			_evade_slipper = null
			_evade_target = Vector3.ZERO
	elif _bb_slipper != _evade_slipper:
		_evade_slipper = _bb_slipper
		_evade_target = Vector3.ZERO
	# How long this threat has been visible, for the guard's reaction delay. Reset the
	# moment nothing is incoming, so each throw is reacted to on its own merits rather
	# than inheriting the previous one's warning.
	if _bb_slipper != null:
		_guard_seen_for += _last_delta
	else:
		_guard_seen_for = 0.0
	return _bb_slipper != null

## Sidestep out of a throw's path, then let the hold-the-circle behaviour pull
## the Can back once the coast is clear.
##
## ⚠️ IT DODGES SIDEWAYS, NOT BACKWARDS. Running directly away from a slipper
## that is faster than the Can never works — it just gets hit later, further from
## its mark. Stepping perpendicular to the throw line is the only motion that
## actually changes the miss distance, and it is what a real lata-guard does.
##
## ⚠️ AND IT STAYS NEAR ITS MARK. Bounded by CAN_EVADE_RADIUS around the base
## circle. A Can free to flee anywhere inside the confinement box would abandon
## the thing it exists to defend, which is the failure the hold-the-circle rule
## was written for in the first place — this is a sidestep, not a retreat.
func _act_evade(_delta: float) -> int:
	_has_move_target = false
	var slipper := _bb_slipper.get_parent() as CharacterBase
	if slipper == null:
		return BTNode.FAILURE
	var vel := slipper.velocity
	vel.y = 0.0
	var to_us := character.global_position - slipper.global_position
	to_us.y = 0.0
	# R-06 leg 3 · THE STEP IS COMMITTED ONCE AND THEN COMPLETED.
	#
	# ⚠️ IT USED TO BE RE-AIMED EVERY TICK. The target was
	# `character.global_position + side * CAN_EVADE_STEP` — measured from where
	# the Can is NOW — so the destination ran away from it at exactly the pace it
	# walked, and the step was never finished, only continually restated. Against
	# a 0.32 s flat throw there is no time for that to show; across a lob's 1.10 s
	# there is. Latched in world space instead: one spot, walked to, held.
	#
	# ⚠️ AND A DEAD SLIPPER IS NOT A REASON TO ABANDON A LATCHED STEP. The old
	# `vel.length() < 0.1` bail is kept only for the frame that PICKS the spot —
	# once one exists, a lob whose horizontal speed has collapsed on the way down
	# is precisely the case this whole change is about.
	if _evade_target == Vector3.ZERO:
		if vel.length() < 0.1:
			return BTNode.FAILURE
		var dir := vel.normalized()
		# Perpendicular in the ground plane; pick the side we are already off
		# toward so the Can commits rather than oscillating across the line.
		var side := Vector3(-dir.z, 0.0, dir.x)
		if side.dot(to_us) < 0.0:
			side = -side
		var target := character.global_position + side * CAN_EVADE_STEP
		# Clamp back toward the mark. Base circle is world origin on every map.
		var from_mark := Vector3(target.x, 0.0, target.z)
		if from_mark.length() > CAN_EVADE_RADIUS:
			from_mark = from_mark.normalized() * CAN_EVADE_RADIUS
		_evade_target = Vector3(from_mark.x, 0.0, from_mark.z)
	_move_toward(Vector3(_evade_target.x, character.global_position.y, _evade_target.z))
	# Spend the Can-Dash when it is too late to sidestep instead — see the
	# CAN_GUARD_ETA block comment above for why this button still fires the
	# one-per-round CAN-DASH (`Design.md` §5.3) even though the names here still say
	# "guard". This is the Can genuinely trying to survive a throw its own sidestep
	# cannot beat, rather than just jittering — and the one place in this file that
	# is allowed to touch `guard_dash` for a Can at all, per `_act_can_drive_home`'s
	# own note that spending it elsewhere would be exactly the "casually" the human's
	# instruction rules out.
	#
	# ⚠️ BUT NOT INSTANTLY AND NOT EVERY TICK. `can_guard_reaction`/`can_guard_cooldown`
	# keep this from firing (an attempted press — `_can_dash_spent` already stops a
	# second real spend) on every single frame a throw sits in the danger band.
	var eta := to_us.length() / maxf(vel.length(), 0.01)
	var seen_long_enough: bool = _guard_seen_for \
		>= can_guard_reaction * (tier_think / DECISION_INTERVAL)
	var may_dash: bool = eta <= CAN_GUARD_ETA and _guard_cooldown_left <= 0.0 \
		and seen_long_enough
	if may_dash and not bool(_held_actions.get("guard_dash", false)):
		_guard_cooldown_left = can_guard_cooldown
	_set_held("guard_dash", may_dash)
	return BTNode.SUCCESS

## ⚠️ THE CAN GENUINELY NEVER MOVED, AND IT WAS ARITHMETIC, NOT INTENT.
##
## Recorded in RUN 1's own notes and never fixed: `CAN_HOLD_RADIUS` is 0.45 while
## `ARRIVE_DISTANCE` is 0.6, so **the deadzone was wider than the entire circle the
## Can was picking points inside.** `_move_toward` therefore released the movement
## keys on the first frame, every time, and the Can only ever moved when it was
## evading a throw. Measured on the independence audit: longest still run 7.03 s on
## `TeamAProp` — the whole sample, minus its dodges.
##
## 🧑 Human ask, 2026-07-30: *"make sure ... theyre all capable of movement."* The Can
## is the unit that was not.
##
## The fix is an arrival distance small enough to be inside its own circle, not a
## bigger circle: the Can must NOT wander off its mark (that is what made round
## resets look like teleports — see this function's history above), so the circle
## stays 0.45 and the deadzone shrinks to 0.12. It now shuffles on the mark the way a
## keeper shifts their weight, which is what "holds its circle" was always supposed
## to look like.
const CAN_ARRIVE_DISTANCE: float = 0.12

func _act_can_hold_mark(_delta: float) -> int:
	_set_held("guard_dash", false)
	# ⚠️ SHUFFLING PACE. Without this the Can's own fidget makes it unhittable — see
	# CAN_IDLE_GAIT for the numbers. Deliberately NOT set in _act_evade: a dodge is
	# still full speed.
	_gait_want = minf(_gait_want, CAN_IDLE_GAIT)
	if _repick or not _has_move_target:
		var angle := _rng.randf() * TAU
		# ⚠️ AT LEAST CAN_ARRIVE_DISTANCE * 2 OUT, or a point drawn near the centre is
		# already "arrived" and the Can stands still until the next re-pick — the same
		# bug in a smaller form.
		var radius := _rng.randf_range(CAN_ARRIVE_DISTANCE * 2.0, CAN_HOLD_RADIUS)
		_move_target = Vector3(cos(angle) * radius, character.global_position.y,
			sin(angle) * radius)
		_has_move_target = true
	_move_toward(_move_target, CAN_ARRIVE_DISTANCE)
	return BTNode.SUCCESS

## ---------------------------------------------------------------------------
## THE OUT-OF-CIRCLE COUNTDOWN. `Design.md` §5.2. The can's real job now that the
## tag and the auto-seal are both gone — see `_build_can_branch`'s own note for the
## priority argument this pair of leaves exists to serve.
## ---------------------------------------------------------------------------

## Reads the SAME flag the HUD's own "LATA OUT" row reads —
## `RoundManager.can_out_left()` is -1.0 whenever every tracked can is home and the
## seconds remaining on the live countdown otherwise. No geometry of its own, so it
## cannot disagree with the clock that actually decides the round the way a
## re-derived `CAN_HOME_RADIUS` check here could.
func _cond_can_displaced() -> bool:
	return RoundManager.can_out_left() >= 0.0

## Beeline for the mark at full effort. `_sprint_want` is this file's own idiom for
## "closing distance or retrieving" (see its own doc) and nothing about this leaf is
## a post to hold, so `CAN_IDLE_GAIT` does not apply the way it does in
## `_act_can_hold_mark` — this is the one Can movement that is meant to look urgent.
##
## ⚠️ `Vector3.ZERO` IS THE MARK, NOT A PLACEHOLDER. Every map's base circle sits at
## its own local (0,0,0) and `$Map` carries no transform (see `CONFINEMENT_RADIUS`'s
## own doc), so world origin IS the mark on every map this file drives against.
##
## ⚠️ NO CAN-DASH HERE. `Design.md` §5.3 spends the one-per-round dash on dodging an
## incoming throw ("not casually") — see `_act_evade`, the only other leaf in this
## file allowed to touch a Can's `guard_dash`. Burning it to shave a fraction of a
## second off an ordinary walk home is exactly the "casually" that rules out.
func _act_can_drive_home(_delta: float) -> int:
	_sprint_want = true
	_move_toward(Vector3.ZERO, CAN_ARRIVE_DISTANCE)
	return BTNode.SUCCESS

## ---------------------------------------------------------------------------
## CAN-SMASH. `Design.md` §5.3: 0.35 s wind-up, a 3.6 m shockwave, 1.6 s stun on a
## Person / 1.2 s on a tsinelas (dropped LOOSE), 8.0 s cooldown, on `bump` (F).
## ---------------------------------------------------------------------------

## ⚠️ ~3.0, NOT THE SHOCKWAVE'S OWN 3.6 m RADIUS. WRITTEN, NOT MEASURED — there is no
## probe run backing this the way `CAN_EVADE_MISS_MARGIN` or `taya_block_standoff`
## have one. The margin exists for the 0.35 s wind-up: whatever is at the full 3.6 m
## right now may not still be there once the shockwave actually lands.
const CAN_SMASH_TRIGGER_RANGE: float = 3.0

## `_try_prop_smash()` (character_base.gd) already refuses a press silently while
## `smash_cooldown_left() > 0.0` — consumed, no ordinary bump either — so this only
## has to decide whether anything is close enough to be WORTH spending the cooldown
## on, never whether the press would even be legal.
func _cond_can_smash_worth_it() -> bool:
	if character.smash_cooldown_left() > 0.0:
		return false
	for other in _roster():
		if other == null or not is_instance_valid(other) or other.team == character.team:
			continue
		var distance := character.global_position.distance_to(other.global_position)
		if distance > CAN_SMASH_TRIGGER_RANGE:
			continue
		if other.is_person:
			return true
		# The opposing tsinelas — only worth it LOOSE (underfoot, or about to be
		# fetched next to us). One CARRIED or FLYING is not standing in the blast to
		# begin with, and neither state is this leaf's question to answer.
		var carriable := other.get_node_or_null("Carriable") as Carriable
		if carriable != null and carriable.state == Carriable.CarryState.LOOSE:
			return true
	return false

func _act_can_smash(_delta: float) -> int:
	_release_move(0.0)
	_tap("bump")
	return BTNode.SUCCESS

## ---------------------------------------------------------------------------
## Leaves — Taya (the defending Person).
## ---------------------------------------------------------------------------

## An opposing attacker exists AND is within detection range. Fills the
## blackboard for every Taya action below it.
func _cond_taya_threat_visible() -> bool:
	_bb_enemy_attacker = _find_enemy_attacker()
	if _bb_enemy_attacker == null or not is_instance_valid(_bb_enemy_attacker):
		_bb_enemy_attacker = null
		return false
	var distance := character.global_position.distance_to(_bb_enemy_attacker.global_position)
	if distance > TAYA_DETECT_RANGE:
		_bb_enemy_attacker = null
		return false
	# A threat was found; abandon whatever wander point was in flight.
	_has_move_target = false
	return true

func _cond_taya_threat_in_melee() -> bool:
	return character.global_position.distance_to(_bb_enemy_attacker.global_position) <= TAYA_MELEE_RANGE

## ⚠️ BEHAVIOUR CHANGE, AND IT IS THE ONE THAT MOVED THE WIN RATE.
##
## The old `_update_taya` said in a comment that it "falls back to chasing only
## when the threat is already INSIDE the box" — but nothing actually tested
## that; it chased only when no can could be found at all, which is a
## completely different (and much rarer) case. So the documented intent had
## never actually run, and implementing it as written turned out to break the
## game: measured over 20 AI-vs-AI rounds, a Taya that pursues anywhere inside
## CONFINEMENT_RADIUS (5.0) wins essentially 100% of rounds, because the
## attacker MUST cross that radius to retrieve its own slipper and — AT THE TIME —
## a defender's tag ended the round outright (hitbox.gd). The tag and its
## round-win branch are both deleted as of 2026-07-30 (`Design.md` §1), but the
## GEOMETRY this measured (a Taya that can reach anywhere in the box wins the
## engagement it is measuring) still holds for the bump meter that replaced it —
## see `_act_taya_manage_bump`. The radius stays a knob for the same reason.
##
## So the radius is a knob, not the confinement wall — see
## `taya_pursue_radius`. The Taya is clamped to CONFINEMENT_RADIUS around the
## world origin (character_base.gd::_move_and_confine), so pursuit beyond that
## is geometrically pointless regardless of what this returns.
## ---------------------------------------------------------------------------
## R-10(c) · THE HONEST MISTAKE. 🧑 The friendslop pillar, directly.
##
## Competence and fun are different targets, and a defender that is never once
## caught out is not a defender a human tells a story about afterwards. So with
## probability `tier_mistake`, taken on a goal re-pick, the Taya OVERCOMMITS: it
## abandons its post and charges the attacker even though the attacker is outside
## `taya_pursue_radius` and it cannot reach it. For that second and a bit the lane is
## open and the can is unguarded, which is exactly the window a human can learn to
## bait and punish.
##
## ⚠️ IT IS A REAL MISTAKE, NOT A TELL. The Taya really does leave, and really does
## lose the block. Scaled by tier so BATA does it often enough to be learnable and
## ASTIG almost never does it (0.22 / 0.09 / 0.02 per re-pick).
## ---------------------------------------------------------------------------
## ⚠️ MEASURED AND RETUNED IMMEDIATELY, AND THE FIRST VERSION IS WORTH RECORDING
## BECAUSE IT IS THE WHOLE TRAP: at 1.3 s with no cooldown and no reach limit, a
## `tier_mistake` of 0.09 rolled on every 0.35 s re-pick fires about once every four
## seconds and lasts a third of that, so the "occasional mistake" was a taya that
## spent 30% of the round sprinting across the arena — and because ANY tag ended the
## round outright AT THE TIME (the tag is deleted as of 2026-07-30, `Design.md` §1),
## **the mistake won more rounds than the blocking did.** Measured: rounds ending by
## tag at 1.9 s and 3.2 s with ZERO throws taken. The bump meter that replaced the tag
## no longer ends a round by itself, so the specific "won more than the blocking"
## outcome no longer applies — but the mistake still abandons the post and opens the
## lane for its own length regardless of what a chase can land at the end of it,
## which is why the same three bounds below are kept unchanged.
##
## A mistake has to cost the bot something. Three bounds make it one:
##   • 0.9 s, which is less than the ~1.2 s it takes to cross from the post to the
##     throwing line, so an overcommit BREAKS OFF before it arrives;
##   • a cooldown, so it is an event and not a state;
##   • a reach limit, so it is a misjudgement about a threat that is genuinely
##     nearby rather than a decision to cross the whole arena.
const TAYA_OVERCOMMIT_TIME: float = 0.9
const TAYA_OVERCOMMIT_COOLDOWN: float = 6.0
## Only misjudge an attacker this close to us. Beyond it, charging is not a mistake a
## person would make — it is a different bot.
const TAYA_OVERCOMMIT_REACH: float = 4.0
var _taya_overcommit_left: float = 0.0
var _taya_overcommit_cooldown: float = 0.0

func _cond_taya_threat_in_confinement() -> bool:
	# Roll the mistake before the geometry, so an overcommit can start from a
	# perfectly sound blocking position — that is what makes it a mistake.
	if flavour_enabled and _repick and _taya_overcommit_left <= 0.0 \
			and _taya_overcommit_cooldown <= 0.0 \
			and character.global_position.distance_to(_bb_enemy_attacker.global_position) \
				<= TAYA_OVERCOMMIT_REACH \
			and _rng.randf() < tier_mistake:
		_taya_overcommit_left = TAYA_OVERCOMMIT_TIME
		_taya_overcommit_cooldown = TAYA_OVERCOMMIT_COOLDOWN
	if _taya_overcommit_left > 0.0:
		# Committed to the chase. Drop the post: coming back to a stale one after the
		# mistake is over would hide half of what the mistake cost.
		_taya_post_valid = false
		return true
	if taya_pursue_radius <= 0.0:
		return false
	var flat := Vector2(_bb_enemy_attacker.global_position.x, _bb_enemy_attacker.global_position.z)
	return flat.length() <= minf(taya_pursue_radius, CharacterBase.confinement_radius)

## ---------------------------------------------------------------------------
## THE BUMP METER, TAYA SIDE. `Design.md` §4: `special_ability` (LMB) is now a
## charged bump — tap for a light nudge (no stagger, no drop), hold to
## `BUMP_CHARGE_FULL_TIME` (1.35 s) for a power bump that displaces 1 m, drops the
## attacker's slipper, staggers them 0.9 s and slows them for 1.2 s. This runs on
## EVERY tick a threat is visible (see the `engage` sequence), not only once the
## attacker is already in melee, because the whole point of a 1.35 s charge is that
## it has to START before the attacker arrives to be worth anything by then.
## ---------------------------------------------------------------------------

## How close the enemy attacker has to be, WHILE CLOSING, before the Taya will begin
## charging a bump against them. WRITTEN, NOT MEASURED — no probe run backs this the
## way `taya_block_standoff` or `ATTACKER_PANIC_RADIUS` have one. Sized so a charge
## started here has a real chance of reaching a useful power by the time the attacker
## crosses into `TAYA_MELEE_RANGE`: at the walking `SPEED` (4.6) closing this whole
## gap takes ~0.8 s, comfortably past `BUMP_TAP_TIME` (0.18) even before a sprinting
## attacker closes it faster.
const TAYA_BUMP_CHARGE_RANGE: float = 4.5
## Same shape and same idiom as `ATTACKER_DODGE_CLOSING_SPEED` — metres per second of
## approach along the line between the two, so standing near the Taya without
## actually closing on it never starts a charge (the human's own "should NOT hold a
## charge while nobody is near").
const TAYA_BUMP_CLOSING_SPEED: float = 0.35

## The whole charge/tap/release decision, run once per tick regardless of which
## movement leaf (`melee`/`close-gap`/`block-how`) fires alongside it this same
## tick — same shape as `_track_can_velocity` running ahead of the role fork, a
## shared per-tick concern factored out of the movement leaves rather than
## duplicated across them.
func _act_taya_manage_bump(_delta: float) -> int:
	var in_melee := _cond_taya_threat_in_melee()
	var charging := bool(_held_actions.get("special_ability", false))
	if in_melee:
		if charging:
			# RELEASE. Whatever charge has built fires through character_base.gd's
			# own bump meter on the release edge (`_release_bump`) — this leaf only
			# ever decides WHEN, never the power.
			_set_held("special_ability", false)
		elif _taya_tap_cooldown <= 0.0:
			# Nothing was charging — the attacker closed faster than
			# TAYA_BUMP_CHARGE_RANGE gave us credit for, or simply appeared here (a
			# round reset, a dash). A bare TAP still "breaks a stance", the human's
			# own framing for the light bump (Design.md §4) — and reuses
			# TAYA_TAP_INTERVAL/`_taya_tap_cooldown` so this cannot fire every single
			# tick the attacker stays in reach.
			_taya_tap_cooldown = TAYA_TAP_INTERVAL
			_tap("special_ability")
		return BTNode.SUCCESS
	if charging:
		# Already committed. Keep holding unless the threat has genuinely backed
		# off — "release when in melee reach" is the only scripted release point;
		# a threat that retreats out of TAYA_BUMP_CHARGE_RANGE is the one case worth
		# abandoning the charge for, per the human's own "should NOT hold a charge
		# while nobody is near".
		var still_close := character.global_position.distance_to(_bb_enemy_attacker.global_position) \
			<= TAYA_BUMP_CHARGE_RANGE
		_set_held("special_ability", still_close)
		return BTNode.SUCCESS
	# Not charging, not in melee: only START on an attacker that is both within
	# range AND genuinely closing — never idle-charge one that is standing off or
	# already receding, per the same instruction.
	var to_us := character.global_position - _bb_enemy_attacker.global_position
	to_us.y = 0.0
	var distance := to_us.length()
	if distance < 0.05 or distance > TAYA_BUMP_CHARGE_RANGE:
		return BTNode.SUCCESS
	var closing := _bb_enemy_attacker.velocity.dot(to_us.normalized())
	if closing >= TAYA_BUMP_CLOSING_SPEED:
		_set_held("special_ability", true)
	return BTNode.SUCCESS

## Movement half of "melee": stop advancing and let the bump meter (above) resolve,
## rather than continuing to close-gap into a target that is already in reach.
func _act_taya_hold_ground(_delta: float) -> int:
	_release_move(0.0)
	return BTNode.SUCCESS

func _act_taya_close_gap(_delta: float) -> int:
	_sprint_want = true
	_move_toward(_bb_enemy_attacker.global_position)
	return BTNode.SUCCESS

## ⚠️ BODY-BLOCK, DO NOT CHASE. This is the Taya's actual job and chasing was
## the wrong shape for it.
##
## The Taya is confined to CONFINEMENT_RADIUS (5.0) and the attacker throws
## from the 6.0 line, so a Taya that walks straight at the attacker ALWAYS
## ends up pressed against the inside of its own box, out at the edge, having
## achieved nothing — and with the can left completely unguarded behind it.
## It could never reach the thing it was chasing; the geometry forbids it.
##
## What a real taya does, and what actually wins the round, is stand ON the
## line between the slipper and the can. So: interpose. Take the point
## `TAYA_BLOCK_STANDOFF` out from the can along the bearing to the attacker,
## which puts the Taya's body in the throw's path, keeps it near enough to bump
## anyone who closes (see `_act_taya_manage_bump`), and keeps the can covered.
## ⚠️ R-07. THIS LEAF NOW *TAKES* A POST RATHER THAN RE-DERIVING ONE. It runs only
## when `_cond_taya_post_committed` has refused, i.e. when the Taya is genuinely
## deciding where to stand — on first sight of the threat, or after the reaction
## window has expired AND the attacker has swung more than `taya_repost_angle` off
## the posted bearing. See the R-07 block near `taya_post_hold` for why.
func _act_taya_body_block(_delta: float) -> int:
	var can := _find_tracked_can()
	if can == null or not is_instance_valid(can):
		# No can to stand in front of (pre-round, or it was just sealed) —
		# closing on the threat is the only thing left worth doing.
		_taya_post_valid = false
		_move_toward(_bb_enemy_attacker.global_position)
		return BTNode.SUCCESS
	var bearing := _bb_enemy_attacker.global_position - can.global_position
	bearing.y = 0.0
	if bearing.length() < 0.1:
		bearing = Vector3.FORWARD
	_taya_post_bearing = atan2(bearing.z, bearing.x)
	# The reaction window scales with how fast this tier thinks, rather than being a
	# fourth column in DIFFICULTY_TIERS: at NORMAL the ratio is 1.0 and this is
	# exactly taya_post_hold, at BATA (think 0.50) it is ~1.43x longer, at ASTIG
	# (think 0.22) ~0.63x. One number, three consistent difficulties.
	_taya_post_hold_left = taya_post_hold * (tier_think / DECISION_INTERVAL)
	_taya_post_valid = true
	_taya_post_error = 0.0
	_move_toward(_post_position(can))
	return BTNode.SUCCESS

## Is the post this Taya already took still the one it wants? BOTH conditions have
## to hold — see the R-07 block for why requiring both is the design and not a
## belt-and-braces.
##
## Fills `_taya_post_error` on every call, including the calls where it returns
## false, so the number a probe reads is always the CURRENT error rather than the
## last one that happened to keep the post.
func _cond_taya_post_committed() -> bool:
	if not _taya_post_valid:
		return false
	var can := _find_tracked_can()
	if can == null or not is_instance_valid(can):
		return false
	var bearing := _bb_enemy_attacker.global_position - can.global_position
	bearing.y = 0.0
	if bearing.length() < 0.1:
		return true # nothing meaningful to re-post against
	_taya_post_error = absf(angle_difference(atan2(bearing.z, bearing.x), _taya_post_bearing))
	if _taya_post_hold_left > 0.0:
		return true # inside the reaction window: the Taya has not noticed yet
	return _taya_post_error <= taya_repost_angle

## Walk to the post already committed to, wherever the attacker has got to since.
func _act_taya_walk_to_post(_delta: float) -> int:
	var can := _find_tracked_can()
	if can == null or not is_instance_valid(can):
		_taya_post_valid = false
		return BTNode.FAILURE
	_move_toward(_post_position(can))
	return BTNode.SUCCESS

## The world point the committed bearing puts the Taya on. Clamped inside the box
## for the same reason the old code did: the Taya is confined to
## CONFINEMENT_RADIUS, so a post outside it is a post pressed against a wall.
func _post_position(can: CharacterBase) -> Vector3:
	var standoff: float = minf(taya_block_standoff, CharacterBase.confinement_radius - 0.4)
	return can.global_position \
		+ Vector3(cos(_taya_post_bearing), 0.0, sin(_taya_post_bearing)) * standoff

## How wrong the Taya's committed post currently is, in radians, or -1.0 when it has
## no post. Read by tools/ai_probe.gd at the moment a throw is released: a throw
## taken while this is large is a throw the attacker's slide EARNED, and one taken
## while it is ~0 met a defender that was already in the right place. That
## distinction is R-07's whole acceptance test and there is no other way to ask it.
func taya_post_error() -> float:
	return _taya_post_error if _taya_post_valid else -1.0

## No threat in range. Patrol within the confinement box — no pathfinding
## around obstacles, since a straight-line wander is "moves with intent," not
## "plays well," per this item's own acceptance bar.
func _act_taya_wander(_delta: float) -> int:
	# ⚠️ THE ONE PLACE A STALE BUMP CHARGE GETS CLEARED WHEN THE THREAT ITSELF
	# VANISHES. `_act_taya_manage_bump` only runs inside the `engage` sequence,
	# gated on `_cond_taya_threat_visible` — so if the enemy attacker leaves
	# detection range (or the round swaps this unit's role) mid-charge, `engage`
	# fails outright and manage-bump never gets a tick to release what it started.
	# `patrol` is the fallback every such tick lands on, so it is the leaf that has
	# to notice and let go — same shape `_cond_attacker_empty_handed` uses to cancel
	# a stale attacker charge the instant hands go empty.
	if bool(_held_actions.get("special_ability", false)):
		_set_held("special_ability", false)
	# R-07: no threat in range, so the post is stale by definition. Dropped here
	# rather than left to expire, or the Taya would walk back to a post taken
	# against an attacker that has since been replaced by the round swap.
	_taya_post_valid = false
	if _repick or not _has_move_target:
		_move_target = _random_point_in_confinement(0.7)
		_has_move_target = true
	_move_toward(_move_target)
	return BTNode.SUCCESS

## ---------------------------------------------------------------------------
## Leaves — Attacker (the offensive Person).
## ---------------------------------------------------------------------------

func _cond_attacker_empty_handed() -> bool:
	_bb_carrier = character.get_node_or_null("Carrier") as Carrier
	if _bb_carrier == null:
		return false
	if _bb_carrier.held() != null:
		return false
	# Empty-handed cancels any charge state left over from the throw that
	# emptied our hands in the first place.
	_attacker_charging = false
	_attacker_charge_time = 0.0
	_set_held("special_ability", false)
	return true

func _cond_attacker_holding() -> bool:
	_bb_carrier = character.get_node_or_null("Carrier") as Carrier
	return _bb_carrier != null and _bb_carrier.held() != null

func _cond_attacker_settling() -> bool:
	return _release_settle_frames > 0

func _act_attacker_settle(_delta: float) -> int:
	_release_settle_frames -= 1
	_release_move(0.0)
	# The throw has been consumed by now (that is what the settle frames are for),
	# so the aim override can go. Cleared rather than left stale so that anything
	# which later reads it — a human taking this unit over mid-round, a different
	# throw path — falls back to the camera instead of aiming at last round's can.
	if _release_settle_frames <= 0:
		character.ai_aim_point = Vector3.INF
	return BTNode.RUNNING

func _cond_own_tsinelas_loose() -> bool:
	_bb_loose_tsinelas = _find_own_loose_tsinelas()
	if _bb_loose_tsinelas == null or not is_instance_valid(_bb_loose_tsinelas):
		_bb_loose_tsinelas = null
		return false
	return true

## How close an opposing Person has to be to our loose tsinelas before fetching it
## is a losing trade. Walking up to a defender standing on our own tsinelas means
## walking into their bump range with nothing to show for it — a power bump there
## staggers us AND drops the slipper we just crossed the arena for, which resets
## the exact scramble we were trying to end. Slightly outside TAYA_MELEE_RANGE (1.4)
## plus a Person's own width, so a taya merely passing by does not freeze the
## attacker out of its own slipper.
const ATTACKER_FETCH_DANGER: float = 2.4
static var attacker_fetch_danger: float = ATTACKER_FETCH_DANGER

## Is a defender sitting on our loose tsinelas? BOTH halves matter: close to it AND
## closer to it than we are. A taya standing on the slipper 5 units from us owns it;
## the same taya standing on it while we are already a step away does not, and
## backing off there would hand over a slipper we had won.
##
## ⚠️ Reads `_bb_loose_tsinelas`, which `_cond_own_tsinelas_loose` fills immediately
## before this in the same Sequence — the blackboard rule.
## ⚠️ WAIT AT THE INNER EDGE OF THE THROWING BAND, NOT AT ARM'S LENGTH FROM THE MAP.
## The first version of this reused `_act_attacker_hold_standoff`, which retreats to
## `ATTACKER_THROW_RANGE + ATTACKER_RETREAT_DISTANCE` = 9.0 units — and measured
## exactly what that predicts: time-to-first-throw went from 0.6 s to 4.8-9.6 s and
## two rounds in four saw NO THROW AT ALL, because the slipper crawls at
## CRAWL_SPEED_SCALE and had nearly nine units to cover. Waiting is right; waiting
## that far away is dead time, which is pillar 4's own failure mode.
##
## `attacker_min_throw_range` (4.6) is the correct place to stand: outside the taya's
## reach (pursuit 1.8 + melee 1.4 = 3.2) and already inside the band this unit wants
## to throw from, so the moment the slipper arrives it is in position.
func _act_attacker_wait_for_crawl(_delta: float) -> int:
	var can := _find_tracked_can()
	if can == null or not is_instance_valid(can):
		return _act_attacker_hold_standoff(_delta)
	var away := character.global_position - can.global_position
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3.FORWARD
	_move_toward(can.global_position + away.normalized() * attacker_min_throw_range)
	return BTNode.RUNNING

func _cond_own_tsinelas_guarded() -> bool:
	var prop := _bb_loose_tsinelas.get_parent() as CharacterBase
	if prop == null or not is_instance_valid(prop):
		return false
	var ours := character.global_position.distance_to(prop.global_position)
	for other in _roster():
		if other == null or not is_instance_valid(other):
			continue
		if not other.is_person or other.team == character.team:
			continue
		var theirs := other.global_position.distance_to(prop.global_position)
		if theirs <= attacker_fetch_danger and theirs < ours:
			return true
	return false

func _act_attacker_retrieve(_delta: float) -> int:
	_has_move_target = false
	var target_char := _bb_loose_tsinelas.get_parent() as CharacterBase
	if target_char == null:
		return BTNode.FAILURE
	var distance := character.global_position.distance_to(target_char.global_position)
	if distance > ATTACKER_GRAB_RANGE:
		# SPRINT. `Design.md` §2/§3: "the AI should sprint when closing distance or
		# retrieving" — this is the retrieving half, literally. Dropped once inside
		# grab range below: standing over the slipper tapping `grab` is not a race
		# any more, and there is nothing left to close the distance on.
		_sprint_want = true
		_move_toward(target_char.global_position)
		return BTNode.RUNNING
	# ⚠️ A TAP EVERY TICK IS NOT A TAP, IT IS A HOLD — AND A HOLD GIVES ONE EDGE.
	# `_tap()` writes the key pressed and queues its release RELEASE_SETTLE_FRAMES in
	# the future; calling it again next tick RESETS that countdown, so the key never
	# came back up, `input_just_pressed("grab")` fired exactly once, and if that first
	# attempt did not take (the slipper still settling out of FLYING, a scuff, a frame
	# of stagger) the attacker stood over its own tsinelas pressing a button that
	# produced no further edges. Measured with the new stillness trace: 4.05 s of a
	# loose TeamBProp in `tsinelas/stand-down` — arrived, waiting to be picked up —
	# opposite an attacker parked in `retrieve/fetch`.
	#
	# Same shape as the Taya's own TAYA_TAP_INTERVAL, and for the same reason.
	_release_move(0.0)
	if _attacker_grab_cooldown <= 0.0:
		_attacker_grab_cooldown = ATTACKER_GRAB_INTERVAL
		_tap("grab")
	return BTNode.SUCCESS

## Falls back to standing still (no can currently tracked at all) rather than
## moving toward Vector3.ZERO, which reads as "walking to the world origin" the
## moment a map is not centred on it.
func _act_attacker_hold_standoff(_delta: float) -> int:
	if _repick or not _has_move_target:
		var can := _find_tracked_can()
		if can != null and is_instance_valid(can):
			var away := character.global_position - can.global_position
			away.y = 0.0
			if away.length() < 0.1:
				away = Vector3.FORWARD
			_move_target = can.global_position + away.normalized() \
				* (ATTACKER_THROW_RANGE + ATTACKER_RETREAT_DISTANCE)
			_has_move_target = true
	if _has_move_target:
		_move_toward(_move_target)
	else:
		_release_move(0.0)
	return BTNode.SUCCESS

func _cond_can_tracked() -> bool:
	_bb_can = _find_tracked_can()
	if _bb_can == null or not is_instance_valid(_bb_can):
		_bb_can = null
		return false
	return true

## ⚠️ A BAND, NOT A CEILING — see ATTACKER_MIN_THROW_RANGE for the measurement that
## made this two-sided. Too close is as wrong as too far, and it was the more
## expensive of the two: too far only delays a throw, too close loses the round.
func _cond_attacker_out_of_range() -> bool:
	var to_can := _bb_can.global_position - character.global_position
	to_can.y = 0.0
	var distance := to_can.length()
	return distance > ATTACKER_THROW_RANGE or distance < attacker_min_throw_range

func _act_attacker_approach(_delta: float) -> int:
	# SPRINT. `Design.md` §2/§3: "the AI should sprint when closing distance or
	# retrieving" — this is the closing-distance half, moving toward the throwing
	# line rather than away from it.
	_sprint_want = true
	_move_toward(_open_throwing_spot(_bb_can))
	return BTNode.RUNNING

## How much of the can's current velocity to lead by, 0..1. Deliberately NOT 1.0
## — a perfect lead against a target that changes direction is both unbeatable
## and unfair-feeling, and the can's evasion is a reaction rather than a constant
## drift, so extrapolating it fully overshoots as often as it corrects. 0.6 lands
## the throw in the can's neighbourhood without the AI reading its mind.
##
## ⚠️ THIS IS A DIFFICULTY KNOB. Raise it toward 1.0 for a sharper AI, drop it to
## 0.0 for the old aim-at-where-it-is behaviour. Fairness-log item 6 wants
## difficulty TIERS rather than one-off nerfs; when those exist this belongs in
## them alongside DECISION_INTERVAL and ATTACKER_LANE_CLEARANCE.
## ⚠️ SUPERSEDED BY `tier_lead` at its one call site, and this is the knob whose
## own note asked to be moved into the tiers in the first place.
const CAN_LEAD_FRACTION: float = 0.6

## Where to aim so the throw and the can arrive together. Flight time is estimated
## from the profile's own launch speed rather than assumed, so a slow bakya leads
## further than a fast flick — which is the behaviour you want and falls out for
## free instead of needing a per-profile constant.
## ---------------------------------------------------------------------------
## ⚠️⚠️ LEAD THE CAN'S DRIFT, NOT ITS JITTER. THIS IS THE SECOND HALF OF THE BUG THE
## "CAN THAT NEVER MOVED" FIX EXPOSED, AND IT IS WORTH THE PARAGRAPH.
##
## `character_base.gd` NORMALISES an AI unit's movement vector, so a Can shuffling
## 0.2 units on its mark still has an INSTANTANEOUS velocity of the full `SPEED`
## (6.0) — in a direction that changes every re-pick. Reading that velocity raw, as
## this function used to, and extrapolating it over a ~0.5 s flight at `tier_lead`
## 0.6 aims the throw **1.8 units wide of a target that is not going anywhere.**
##
## Measured, and it is the pair of numbers that gave it away: 30 unblocked throws with
## exactly 1 reaching the can, against `phys_probe`'s 3-in-9 for a clean throw. The
## throws were not being blocked and were not arriving — they were being aimed at a
## place the can had no intention of being. Before the Can moved at all this was
## invisible, because a stationary can has a velocity of zero and the lead term
## vanished. One fix uncovered the other.
##
## So the lead reads a SMOOTHED velocity. A shuffle averages to nearly nothing because
## its directions cancel; a real evasion sidestep is sustained and survives the
## average, which is the only motion worth leading in the first place.
## ---------------------------------------------------------------------------

## Seconds of history the smoothing keeps, roughly. Shorter than a sidestep (which
## runs for as long as the throw is in the air) and much longer than a shuffle re-pick.
const CAN_VELOCITY_SMOOTHING: float = 0.35
## Hard ceiling on the lead, in units. Even a correctly-observed drift should not aim
## the throw off the can entirely — past this the honest move is to wait for a better
## moment, and a capped lead degrades to "aim at it", which is never catastrophic.
const CAN_LEAD_MAX: float = 1.2
var _can_velocity_ema: Vector3 = Vector3.ZERO

## Ticked from decide() for every controller, whatever its role, so the estimate is
## already warm on the frame an attacker decides to throw rather than starting from
## zero at the charge.
func _track_can_velocity(delta: float) -> void:
	var can := _find_tracked_can()
	if can == null or not is_instance_valid(can):
		_can_velocity_ema = Vector3.ZERO
		return
	var alpha: float = clampf(delta / maxf(CAN_VELOCITY_SMOOTHING, 0.001), 0.0, 1.0)
	var flat := Vector3(can.velocity.x, 0.0, can.velocity.z)
	_can_velocity_ema = _can_velocity_ema.lerp(flat, alpha)

func _lead_the_can(can: CharacterBase, hold_time: float = -1.0) -> Vector3:
	var here := character.global_position
	var mark := can.global_position + Vector3(0.0, 0.25, 0.0)
	var speed := _own_launch_speed(hold_time)
	if speed <= 0.01:
		return mark
	var flight_time := here.distance_to(mark) / speed
	var drift := _can_velocity_ema * flight_time * tier_lead
	if drift.length() > CAN_LEAD_MAX:
		drift = drift.normalized() * CAN_LEAD_MAX
	return mark + drift

## ⚠️ THREAD THE NEEDLE. This is the direct answer to the biggest number in the log:
## RUN 9 measured 94.7% of 188 throws blocked, RUN 10's committed post brought that
## to 81.3%, and the remainder is the attacker aiming at the CENTRE of a can that
## has a defender's body in front of it. `ATTACKER_PATIENCE` exists precisely so the
## attacker eventually takes the shot anyway — but taking it dead down the middle of
## an occupied lane is throwing the slipper at the taya, not at the can.
##
## So slide the aim point sideways by just enough to clear the body that is in the
## way: the perpendicular offset needed for the flight line to pass the defender at
## more than `ATTACKER_LANE_CLEARANCE`, in whichever direction the defender is NOT.
## Nothing here fakes a hit — the throw still has to reach a can that dodges, and a
## can whose hurtbox is 0.17 wide is still a small target once you are aiming past
## its guard. What it stops is the AI feeding a wall on purpose.
##
## ⚠️ CAPPED, AND THE CAP IS THE WHOLE THING — MEASURED, THEN CORRECTED FROM 1.1.
## At 1.1 this "fix" worked exactly as designed and made the game worse: the block
## rate fell 94.7% -> 23.1% and **`throws that reached the can` stayed at 0 across 20
## unblocked throws**, because a metre of sideways aim clears the defender and misses
## the can as well. Two columns that cannot both be good is the tell, same as always.
##
## So the cap is the width of a hit, not the width of a body: the can's hurtbox is
## 0.17 and `throw_flick`'s `hit_radius` is 0.30, so 0.45 is about the last offset
## that can still connect (the same 0.47 overlap band `CAN_EVADE_MISS_MARGIN`'s own
## doc derives). Past that, threading is not a shot — it is a miss with extra steps,
## and the honest answers are the lob (R-06) or another slide. `thread=0` on the probe
## turns it off entirely so its contribution stays measurable.
const ATTACKER_THREAD_MAX: float = 0.45
static var attacker_thread_max: float = ATTACKER_THREAD_MAX

func _thread_past_defender(aim: Vector3) -> Vector3:
	if _bb_can == null or not is_instance_valid(_bb_can):
		return aim
	var blocker := _blocking_defender(_bb_can)
	if blocker == null:
		return aim
	var lane := aim - character.global_position
	lane.y = 0.0
	if lane.length() < 0.1:
		return aim
	var lane_dir := lane.normalized()
	var to_blocker := blocker.global_position - character.global_position
	to_blocker.y = 0.0
	var along := to_blocker.dot(lane_dir)
	var side_vec := to_blocker - lane_dir * along
	var side_distance := side_vec.length()
	# Which way to go round. If the defender is dead centre the sign is arbitrary, so
	# take the side the can's own motion is heading for — it is going that way anyway.
	var perpendicular := Vector3(-lane_dir.z, 0.0, lane_dir.x)
	if side_distance > 0.01:
		if perpendicular.dot(side_vec) > 0.0:
			perpendicular = -perpendicular # away from the body, not through it
	elif perpendicular.dot(Vector3(_bb_can.velocity.x, 0.0, _bb_can.velocity.z)) < 0.0:
		perpendicular = -perpendicular
	var needed: float = ATTACKER_LANE_CLEARANCE - side_distance
	if needed <= 0.0:
		return aim
	# ⚠️ IF THREADING CANNOT CLEAR THE BODY WITHIN THE CAP, DO NOT HALF-THREAD.
	# A shot offset by the cap when it needed twice that misses the defender AND the
	# can — strictly worse than feeding the block, because a blocked slipper at least
	# drops next to the can where it can be fetched again. Aim true and take the block;
	# the real answer to a lane this well covered is the lob.
	if needed > attacker_thread_max:
		return aim
	return aim + perpendicular * needed

## The launch speed this unit's slipper will actually use, at the charge this
## leaf holds. Read off the held Carriable's own profile so it cannot drift out
## of step with the .tres files (they were retuned twice without this noticing).
func _own_launch_speed(hold_time: float = -1.0) -> float:
	var carrier := character.get_node_or_null("Carrier") as Carrier
	if carrier == null:
		return 0.0
	var held := carrier.held()
	if held == null:
		return 0.0
	var fraction := _charge_fraction(hold_time)
	var prop := held.get_parent() as CharacterBase
	if prop == null or prop.ability == null or not prop.ability.has_method("get_throw_profile"):
		# No ability means carriable.gd falls back to DEFAULT_PROFILE; 21.0 is
		# that resource's launch_speed. Only ever hit by a Prop with no ability.
		return 21.0 * fraction
	var profile := prop.ability.get_throw_profile() as ThrowProfile
	if profile == null:
		return 21.0 * fraction
	return profile.launch_speed * fraction

## What fraction of full power this leaf's charge actually reaches.
##
## ⚠️ MIRRORS `carrier.gd::charge_power()` EXACTLY, floor included. That curve is
## not linear in hold time — it starts at CHARGE_MIN_POWER (0.35) so a panicked
## tap still throws — so a plain `hold / full` ratio underestimates the speed and
## therefore over-leads. At ATTACKER_CHARGE_TIME 0.65 the real figure is ~0.82,
## not 0.72. All three constants are read, never restated.
## `hold_time` < 0 means "whatever this tier's ordinary flat throw holds for" — the
## default, so every existing caller reads unchanged. A lob passes its own longer
## hold; the clamp then correctly reports 1.0 rather than something above full
## power, which is exactly what carrier.gd will do with it.
func _charge_fraction(hold_time: float = -1.0) -> float:
	var hold: float = tier_charge if hold_time < 0.0 else hold_time
	return clampf(
		Carrier.CHARGE_MIN_POWER
			+ (hold / Carrier.CHARGE_FULL_TIME) * (1.0 - Carrier.CHARGE_MIN_POWER),
		Carrier.CHARGE_MIN_POWER, 1.0)

## ⚠️ PATIENCE — THIS IS THE FIX FOR B-124, THE ATTACKER/TAYA LIVELOCK.
##
## Returning a bare "is the lane blocked" here is what gave the attacker EXACTLY
## ONE THROW PER ROUND, every round, at every pursuit setting. Measured off
## bt_trace(): from the moment it re-acquired the slipper (~1.4 s) to the end of
## a 40 s observation the attacker sat in `role/attacker/throw/reposition`, and
## never once reached `charge-release`. The geometry makes it inescapable — it
## orbits the can at r ~ 4-5 looking for an open bearing while the Taya
## body-blocks at r ~ 2.5 and re-derives its post from the attacker's CURRENT
## bearing every tick, so the lane is blocked again the instant the attacker
## arrives anywhere. They rotate together forever. The single throw each round
## actually lands is the opening one at ~0.6 s, before the Taya reaches the lane.
##
## So the attacker gives up sliding after ATTACKER_PATIENCE seconds of continuous
## block and throws into the block anyway. That is also the human behaviour: you
## do not circle a defender indefinitely, you take the shot and accept it might
## get blocked — which is what makes `throws blocked` a meaningful fairness
## number instead of a column that reads 0 because no contested throw is ever
## attempted.
##
## The timer resets the moment the lane genuinely opens, so an attacker that
## finds a clear bearing still takes the free shot rather than burning patience.
const ATTACKER_PATIENCE: float = 2.0
var _attacker_lane_blocked_for: float = 0.0

func _cond_lane_blocked() -> bool:
	if _blocking_defender(_bb_can) == null:
		_attacker_lane_blocked_for = 0.0
		return false
	_attacker_lane_blocked_for += _last_delta
	# Blocked, but out of patience: report the lane CLEAR so the selector falls
	# through to charge-release. Deliberately not a separate BT branch — the
	# decision "stop repositioning" belongs to the same condition that started it.
	return _attacker_lane_blocked_for < ATTACKER_PATIENCE

func _act_attacker_slide_open(_delta: float) -> int:
	_attacker_charging = false
	_attacker_charge_time = 0.0
	_set_held("special_ability", false)
	_move_toward(_open_throwing_spot(_bb_can))
	return BTNode.RUNNING

## ---------------------------------------------------------------------------
## R-06 · THE LOB (`bagsak`) — THE AI'S DECISION TO USE IT.
##
## ⚠️ THE MECHANIC IS THE PHYSICS LANE'S AND IT DOES NOT EXIST YET. This file owns
## only the DECISION; the handoff with the full specification is in
## `docs/Checklist.md` §Phase 9 under "HANDOFF — R-06 (the lob) to the PHYS lane".
## The one-line version, because it shapes what is written here: `carriable.gd::
## _solve_arc()` already computes both solutions of the ballistic quadratic and
## throws away the high one (`(v2 - sqrt(disc))` is the flat root). The lob IS that
## discarded root. Nothing new has to be invented, and no new input action may be
## added — the charge is already an analogue hold and the lob is a region of it.
##
## ⚠️ WHY THIS IS SAFE TO SHIP AHEAD OF THE MECHANIC. `carrier.gd::_step_throw`
## clamps `_charge_time` to `CHARGE_FULL_TIME`, so holding past full power today
## produces the identical throw a fraction of a second later. With `lob_enabled`
## false the branch never runs at all; with it true and the mechanic absent, the
## measured cost is a slightly later throw. Either way this cannot silently change
## a fairness number, and RUN 9's baseline stays comparable.
##
## THE TRIANGLE THIS IS FOR, restated so the next reader does not have to find the
## roadmap: the lob beats the taya (it goes over a body-block), the can's dodge
## beats the lob (it arrives slowly enough that CAN_EVADE_LOOKAHEAD sees it), and
## the flat throw beats the dodge. Not a strictly better shot — a third corner.
## ---------------------------------------------------------------------------

## Off until the physics half lands. `lob=on` on tools/ai_probe.gd flips it, so the
## AI's half can be measured on its own before the mechanic exists and again after.
static var lob_enabled: bool = false
## How far past the full-power point the lob region begins, in seconds of hold.
## ⚠️ THE PHYS LANE OWNS THE REAL THRESHOLD — this is the AI's belief about where it
## is, and the two have to agree or the AI will hold for a lob and throw a flat.
##
## ✅ THE MECHANIC HAS LANDED, SO THIS NOW READS IT rather than restating 0.20,
## exactly as `_charge_fraction()` reads Carrier's three constants. The two agreed
## by coincidence and now agree by construction: a future retune of the commitment
## window moves the AI's belief with it, instead of leaving the AI holding for a
## lob and throwing a flat.
const ATTACKER_LOB_OVERHOLD: float = Carrier.LOB_OVERHOLD_TIME
static var attacker_lob_overhold: float = ATTACKER_LOB_OVERHOLD

## Is going OVER the block the right call this frame? Reached only when the lane is
## blocked and ATTACKER_PATIENCE has already been spent (see the tree), so the
## alternative on offer is the throw RUN 9 measured dying 94.7% of the time.
func _cond_attacker_should_lob() -> bool:
	if not lob_enabled:
		return false
	# Ask the same question _cond_lane_blocked asks, without its patience timer: is
	# there a defender in the lane RIGHT NOW. Re-checked rather than remembered
	# because the taya may have moved since, and lobbing a lane that has just opened
	# throws away a free flat shot.
	return _blocking_defender(_bb_can) != null

## Hold the charge into the lob region and release. Deliberately the same leaf shape
## as the flat throw, sharing one implementation — two copies of the charge/release
## frame dance is how RELEASE_SETTLE_FRAMES' bug would come back.
func _act_attacker_charge_lob(delta: float) -> int:
	return _charge_and_release(delta, Carrier.CHARGE_FULL_TIME + attacker_lob_overhold)

## In range with a clear lane. Stand still to charge and release — moving
## mid-charge is not modelled (carrier.gd allows it; a human sometimes does
## too), keeping this pass simple. Returns RUNNING for the whole charge and
## SUCCESS on the frame the button is released, which is exactly the throw
## event tools/ai_probe.gd's fairness run counts.
func _act_attacker_charge_release(delta: float) -> int:
	return _charge_and_release(delta, _flat_hold_time())

## ---------------------------------------------------------------------------
## R-10(a) and R-10(b) · A THROW THAT VARIES, AND A WIND-UP YOU CAN READ.
##
## (a) `ATTACKER_CHARGE_TIME`/`tier_charge` is a single fixed number, so **every AI
## throw in the history of this project has had identical power.** A human's throws
## do not. Jittered per throw, drawn once at the start of the charge and held for the
## whole of it (redrawing per frame would average out to the fixed value and change
## nothing — which is the kind of no-op that looks implemented and is not).
##
## `carrier.gd::charge_power()` is `CHARGE_MIN_POWER + hold/CHARGE_FULL_TIME * (1 -
## CHARGE_MIN_POWER)`, i.e. 0.35 + hold/0.9 * 0.65. At NORMAL's 0.65 s hold that is
## power 0.82. A jitter of +/-50% ON THE HOLD gives holds of 0.325..0.975 s, i.e.
## powers of 0.585..1.0 — **+/-26% around the mean, which clears R-10's own +/-25%
## acceptance bar** and is not a coincidence: the bar is why the jitter is 0.5 and
## not the 0.25 that would read as a fixed throw with noise on it.
##
## (b) The wind-up is already animated, so the readability problem is only that a
## 0.325 s hold is over before a human can respond to it. A floor of
## `ATTACKER_MIN_WINDUP`, scaled by how slowly the tier thinks, keeps every throw on
## screen long enough to be seen and dodged — and makes BATA the most readable tier,
## which is the right way round.
## ---------------------------------------------------------------------------

## Fraction of the tier's hold time the jitter spans, either side.
const ATTACKER_CHARGE_JITTER: float = 0.5
static var attacker_charge_jitter: float = ATTACKER_CHARGE_JITTER
## No throw winds up faster than this, before the tier scaling below. A human needs
## roughly a third of a second to see a wind-up and start moving.
const ATTACKER_MIN_WINDUP: float = 0.42
static var attacker_min_windup: float = ATTACKER_MIN_WINDUP
## Set once per throw at the start of the charge; -1.0 when not charging.
var _attacker_hold_target: float = -1.0

func _flat_hold_time() -> float:
	if _attacker_hold_target > 0.0:
		return _attacker_hold_target
	var jitter: float = 1.0
	if flavour_enabled:
		jitter = _rng.randf_range(1.0 - attacker_charge_jitter, 1.0 + attacker_charge_jitter)
	# The readable floor scales with the tier's own thinking speed: BATA (think 0.50)
	# holds ~1.43x this, ASTIG (0.22) ~0.63x. One number, three difficulties, same
	# trick R-07's reaction window uses.
	var floor_time: float = attacker_min_windup * (tier_think / DECISION_INTERVAL) \
		if flavour_enabled else 0.0
	_attacker_hold_target = maxf(maxf(tier_charge * jitter, floor_time), _min_hold_to_reach())
	return _attacker_hold_target

## ⚠️⚠️ THE FLOOR THAT MAKES THE JITTER LEGAL, AND IT COST A WHOLE ITERATION TO FIND.
##
## R-10(a)'s charge variance, shipped without this, produced the exact impossible pair
## of numbers this repo's method note warns about: **the block rate fell to 23.8% and
## `throws that reached the can` stayed at 0 over 32 unblocked throws**, while
## `phys_probe target=can` says a clean throw connects 3 times in 9. Both cannot be
## true. The cause was not the metric this time — it was the change: jittering the
## hold DOWNWARD produces launch speeds that cannot cover the throwing line at all.
## `carriable.gd::_solve_arc()` is explicit about what it then does — "no launch angle
## at this speed reaches that point ... throw along the player's own line and let it
## fall short". So half the throws were physically incapable of arriving, which reads
## in the table as an attacker who is not being blocked and is also not scoring.
##
## A human learns in two throws that they have to pull it back far enough. So the AI
## computes the minimum: the shallowest ballistic arc over a flat distance `d` needs
## `v = sqrt(g * d)` (the 45-degree case), which inverts through `charge_power()` into
## a hold. The jitter then varies ABOVE that floor, which is what a person's throws
## actually look like — nobody deliberately throws too short.
##
## +8% of margin on the speed, because the can is 0.25 up rather than on the floor and
## because the arc solver's discriminant goes negative at exactly the boundary.
const ATTACKER_REACH_MARGIN: float = 1.08

func _min_hold_to_reach() -> float:
	var can := _bb_can if _bb_can != null and is_instance_valid(_bb_can) else _find_tracked_can()
	if can == null or not is_instance_valid(can):
		return 0.0
	var flat := can.global_position - character.global_position
	flat.y = 0.0
	var distance := flat.length()
	if distance < 0.5:
		return 0.0
	var full_speed := _own_launch_speed(Carrier.CHARGE_FULL_TIME) / maxf(_charge_fraction(Carrier.CHARGE_FULL_TIME), 0.01)
	if full_speed <= 0.01:
		return 0.0
	var gravity: float = CharacterBase.GRAVITY * _own_gravity_scale()
	var needed_speed: float = sqrt(gravity * distance) * ATTACKER_REACH_MARGIN
	var needed_fraction: float = clampf(needed_speed / full_speed, 0.0, 1.0)
	if needed_fraction <= Carrier.CHARGE_MIN_POWER:
		return 0.0
	# Invert charge_power(): fraction = MIN + hold/FULL * (1 - MIN).
	return (needed_fraction - Carrier.CHARGE_MIN_POWER) / (1.0 - Carrier.CHARGE_MIN_POWER) \
		* Carrier.CHARGE_FULL_TIME

## Read off the held slipper's own profile rather than assumed, same contract
## _own_launch_speed() uses — the .tres files have been retuned twice.
func _own_gravity_scale() -> float:
	var carrier := character.get_node_or_null("Carrier") as Carrier
	if carrier == null:
		return 1.0
	var held := carrier.held()
	if held == null:
		return 1.0
	var prop := held.get_parent() as CharacterBase
	if prop == null or prop.ability == null or not prop.ability.has_method("get_throw_profile"):
		return 1.0
	var profile := prop.ability.get_throw_profile() as ThrowProfile
	return profile.gravity_scale if profile != null else 1.0

func _charge_and_release(delta: float, hold_time: float) -> int:
	_release_move(0.0)
	# ⚠️ TELL THE THROW WHERE THE CAN IS (B-125). Without this the throw is aimed
	# by `carrier.gd::_aim_point()`, which ray-casts from the FPP camera — and
	# this leaf deliberately stands still, so the camera is still pointing along
	# whatever bearing the unit last WALKED. Measured over 20 rounds before this
	# line existed: throws that reached the can, 0. See CharacterBase.ai_aim_point.
	#
	# Aimed at the same +0.25 above the can's origin that phys_probe aims at, so
	# the probe and the AI are asking `_solve_arc` the identical question.
	#
	# ⚠️ AND IT LEADS THE TARGET, BECAUSE THE CAN DODGES. Measured in phys_probe:
	# the can moves on 56% of in-flight frames and gets up to 1.41 m off its mark.
	# Aiming at where it IS therefore misses a dodging can almost every time, and
	# that is not a small effect — it is why "throws that reached the can" stayed
	# at 0 across 80 throws even after the aim itself was fixed (B-125) and the
	# livelock was broken (B-124). The can's own evasion was eating every shot.
	#
	# Leading is the right fix rather than nerfing CAN_EVADE_*: a human-driven can
	# dodges too, so an AI that cannot lead is simply a worse player, and the
	# evasion values are documented as deliberately sitting "on the hittable side".
	if _bb_can != null and is_instance_valid(_bb_can):
		character.ai_aim_point = _thread_past_defender(_lead_the_can(_bb_can, hold_time))
	if not _attacker_charging:
		# ⚠️⚠️ THE THROW LOCK (`Carrier.THROW_LOCK_TIME`, 1.25 s after picking a
		# tsinelas up). `carrier.gd::_step_throw` already refuses the press silently
		# while locked — it never sets `_is_charging` at all — but it does so quietly,
		# and this file has no way to see that refusal unless it asks first. Without
		# this gate, an AI that reached this leaf during the lock would set ITS OWN
		# `_attacker_charging` belief to true, count a fake charge nobody in the real
		# game ever sees, and "release" into a throw that never actually started —
		# the attacker holding the button down and firing nothing, over and over,
		# which is exactly "mashes throw during the lock and looks broken."
		# RUNNING, not FAILURE: this leaf still owns the tick (the aim point above is
		# already set and the attacker should stand ready, not fall through to a
		# different throw-how sibling and flicker between them every frame).
		if _bb_carrier != null and _bb_carrier.throw_lock_left() > 0.0:
			_release_move(0.0)
			return BTNode.RUNNING
		_attacker_charging = true
		_attacker_charge_time = 0.0
		_set_held("special_ability", true)
	_attacker_charge_time += delta
	if _attacker_charge_time < hold_time:
		return BTNode.RUNNING
	_set_held("special_ability", false)
	_attacker_charging = false
	_attacker_charge_time = 0.0
	# R-10(a): the next throw draws its own power. Cleared here rather than at the
	# start of the next charge so a charge interrupted by anything at all (a tag, a
	# round reset, the slipper being knocked loose) does not carry its hold target
	# into a throw taken half a round later.
	_attacker_hold_target = -1.0
	_release_settle_frames = RELEASE_SETTLE_FRAMES
	# ⚠️ SPEND THE PATIENCE ON THE THROW. Without this reset the timer stays over
	# ATTACKER_PATIENCE for the rest of the round — it only clears when the lane
	# genuinely opens — so the attacker stops repositioning FOREVER after its
	# first impatient throw and just charge-releases on a 0.65 s cycle. Measured:
	# 503 throws over 20 rounds, ~25 per round, with the Taya blocking 1% of them
	# because the attacker had stopped trying to get around it at all. That trades
	# one livelock for another and is not what "take the shot" means.
	_attacker_lane_blocked_for = 0.0
	# Cleared one frame AFTER the release would have been consumed, not here —
	# `_set_held` writes intent that carrier.gd reads on its own next step, so
	# dropping the aim point on this frame would race the throw it was set for.
	# _act_attacker_settle does it, and so does take_over() for the human case.
	return BTNode.SUCCESS

## ---------------------------------------------------------------------------
## Leaves — Tsinelas (the slipper Prop, while it is on the floor).
## ---------------------------------------------------------------------------

func _cond_tsinelas_loose() -> bool:
	var carriable := character.get_node_or_null("Carriable") as Carriable
	return carriable != null and carriable.state == Carriable.CarryState.LOOSE

## Crawls toward its own team's Attacker so the two meet in the middle, rather
## than the Attacker having to cross the whole confinement gap alone.
## movement_speed_scale() already applies CRAWL_SPEED_SCALE to whatever
## direction is pressed here — this file does not need to know that.
func _cond_own_attacker_exists() -> bool:
	_bb_own_attacker = _find_own_attacker()
	if _bb_own_attacker == null or not is_instance_valid(_bb_own_attacker):
		_bb_own_attacker = null
		return false
	if _repick:
		_has_move_target = false # always chase the attacker's CURRENT position
	return true

func _cond_tsinelas_arrived() -> bool:
	return character.global_position.distance_to(_bb_own_attacker.global_position) \
		<= TSINELAS_ARRIVE_DISTANCE

func _act_tsinelas_crawl(_delta: float) -> int:
	# SPRINT. `Design.md` §2: "the objects sprint too" — a crawling tsinelas already
	# moves at CRAWL_SPEED_SCALE (0.45x); stacking the sprint multiplier on top of
	# that (character_base.gd::_physics_process multiplies every scale together) is
	# still meaningfully faster than a plain crawl and this IS the "retrieving" half
	# of "sprint when closing distance or retrieving".
	_sprint_want = true
	_move_toward(_bb_own_attacker.global_position, TSINELAS_ARRIVE_DISTANCE)
	return BTNode.SUCCESS

## Settle in place rather than freeze — see the `settle` node's own note. Only ever
## reached while this Prop is not being carried or flown (Carriable.drives_movement()
## takes over entirely in those states), so it cannot fight the carry.
func _act_tsinelas_settle(_delta: float) -> int:
	if _cond_tsinelas_loose():
		_move_toward(character.global_position, 0.0)
		return BTNode.SUCCESS
	_release_move(0.0)
	return BTNode.SUCCESS

## ---------------------------------------------------------------------------
## GROUND SMASH & THE SELF-LAUNCH. `Design.md` §6. `character._dive_active` is the
## one flag both leaves below have to respect: true from the `bump` press that
## starts the dive (`PropSmash.begin_ground_smash`) until the landing that resolves
## it (`PropSmash.step_dive`), and nothing here may steer during it — see
## `_build_tsinelas_branch`'s own note on why `diving` sits above both.
## ---------------------------------------------------------------------------

func _cond_tsinelas_diving() -> bool:
	return character._dive_active

## `Carriable.can_ground_smash()` already asks the real question — LOOSE, airborne,
## and above `PropSmash.GROUND_SMASH_MIN_HEIGHT` by its own downward clearance ray
## (see that function's own doc for why a raw world-Y test would be wrong on a map
## with a raised lane strip). This leaf only has to read the answer.
func _cond_tsinelas_can_smash() -> bool:
	var carriable := character.get_node_or_null("Carriable") as Carriable
	return carriable != null and carriable.can_ground_smash()

## Stop steering — see `_build_tsinelas_branch`'s own note on why — and press the
## dive. `_try_prop_smash()` (character_base.gd) routes a tsinelas's `bump` press to
## `PropSmash.begin_ground_smash` exactly when `can_ground_smash()` agrees, which is
## the same predicate `_cond_tsinelas_can_smash` just checked.
func _act_tsinelas_smash(_delta: float) -> int:
	_release_move(0.0)
	_tap("bump")
	return BTNode.SUCCESS

## Line of sight to the tracked can — a raycast, not a distance check, so a wall or
## a piece of clutter between here and the can refuses the launch rather than
## sending it in blind. Same idiom `Carriable.can_ground_smash()` and
## `Carrier._aim_point()` already use for their own raycasts.
func _cond_tsinelas_can_launch() -> bool:
	_bb_can = _find_tracked_can()
	if _bb_can == null or not is_instance_valid(_bb_can):
		return false
	if not RoundManager.round_active:
		return false
	var space := character.get_world_3d().direct_space_state
	var from := character.global_position + Vector3.UP * 0.15
	var to := _bb_can.global_position + Vector3.UP * 0.15
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [character.get_rid()]
	return space.intersect_ray(query).is_empty()

## Face and close on the can, holding `jump` for `Carriable.SELF_LAUNCH_CHARGE_TIME`
## (0.75 s) before releasing — same charge/release shape `_charge_and_release` uses
## for the attacker's throw, read off the mechanic's own constant rather than
## restated (the file's usual rule — see `_charge_fraction`'s own note on why).
##
## ⚠️ ALWAYS A FULL CHARGE. `Carriable.jump_charge_step` scales speed 6.0 -> 13.0
## m/s by how long `jump` was held; this leaf never has a reason to release early,
## since a bigger jump only ever gets it closer to (or onto) the can it is already
## trying to reach.
##
## ⚠️ `arrive = 0.0`. Unlike every other `_move_toward` call in this file, this one
## must not let the Taya's own body block a settle-radius "arrival" from resolving
## early — it should keep walking and facing the can for the WHOLE charge, since
## `jump_charge_step`'s release reads THIS character's own forward vector
## (`-global_transform.basis.z`) at the moment it fires (see that function's own
## doc), and a body that stopped and started idle-shuffling partway through the
## charge would release toward wherever the shuffle last faced instead.
var _tsinelas_launch_time: float = 0.0

func _act_tsinelas_launch(delta: float) -> int:
	_sprint_want = true
	_move_toward(_bb_can.global_position, 0.0)
	_set_held("jump", true)
	_tsinelas_launch_time += delta
	if _tsinelas_launch_time < Carriable.SELF_LAUNCH_CHARGE_TIME:
		return BTNode.RUNNING
	_set_held("jump", false)
	_tsinelas_launch_time = 0.0
	return BTNode.SUCCESS

## ---------------------------------------------------------------------------
## Shared geometry helpers. Not leaves — called by them.
## ---------------------------------------------------------------------------

## The defender standing between this attacker and the can, if any. "Between"
## is measured as perpendicular distance from the defender to the throw line,
## so a Taya beside the lane does not count and a Taya in it does.
## ---------------------------------------------------------------------------
## ATTACKER EVASION. Human call, 2026-07-29: the AI should "fulfil their roles
## and try to win (attacker avoid defender, defender try to tag, etc)".
##
## The attacker already avoided STANDING in a blocked throwing lane
## (`_cond_lane_blocked`). It did not avoid the taya itself, and — AT THE TIME —
## being tagged ended the round for its whole team, which is how 18 of 20 rounds
## ended in RUN 4. Avoiding a lane and avoiding a person are different behaviours
## and only the first one existed.
##
## ⚠️⚠️ THE TAG THIS SECTION WAS WRITTEN AGAINST IS GONE, 2026-07-30 (`Design.md`
## §1). What a defender can land on a nearby attacker now is the charged bump meter
## on `special_ability` (Design.md §4) — a full charge drops the slipper, staggers
## for 0.9 s and slows for 1.2 s; a bare tap does neither. So "avoid the defender" no
## longer means "avoid being near one"; it means "avoid one who is actually winding
## up", which is exactly what the wind-up broadcast (`CharacterBase.
## observed_bump_charge()`) is FOR — Design.md §4 states it outright: the whole
## 1.35 s charge is visible on every peer "so the attacker can see the commitment
## and dash, jump or throw through it." `_cond_attacker_panic` below reads that
## broadcast; `_threatening_defender`'s two-band shape (arm's length regardless of
## motion, further out only if closing) is otherwise unchanged, because a defender
## can still start a charge from a dead stop.
##
## WHERE THE THREAT ACTUALLY COMES FROM, which is what shapes the dodge: the taya
## does not chase to the throwing line (it is capped at CONFINEMENT_RADIUS and
## `taya_pursue_radius` ships small). It gets a shot at a bump when the ATTACKER
## walks into the confinement box — which the attacker must do to fetch a slipper
## that landed near the can. So the dodge has to work while retrieving, not only
## while throwing, and that is why it sits above BOTH in the tree.
## ---------------------------------------------------------------------------

## How close an opposing Person has to be before the attacker breaks off.
## Comfortably outside TAYA_MELEE_RANGE (1.4) so the dodge starts before a bump
## can land, and inside TAYA_DETECT_RANGE (8.0) so the attacker is not permanently
## fleeing something that is not actually coming for it.
const ATTACKER_DODGE_RADIUS: float = 2.4
## Only dodge a threat that is CLOSING. Without this the attacker flees anything
## standing near it and never retrieves the slipper at all — a livelock of the
## same family as B-124, arriving from the opposite direction. Metres per second
## of approach speed, measured along the line between the two.
const ATTACKER_DODGE_CLOSING_SPEED: float = 0.35
## How far to the side to break. Perpendicular rather than straight back: running
## directly away from a defender that is the same speed as you never opens a gap,
## it just walks you out of the arena.
const ATTACKER_DODGE_STEP: float = 3.0

## ⚠️ ARM'S LENGTH. Inside this, a defender is worth WATCHING regardless of what it
## is doing — including standing perfectly still, which is exactly how a bump charge
## starts (`_act_taya_manage_bump` charges from a stop as often as not). Whether it
## is actually PANIC-worthy is a second question, answered by `_cond_attacker_panic`
## reading the defender's own bump-charge broadcast, not by this radius alone. One
## `TAYA_MELEE_RANGE` (1.4) plus half a Person's width of margin.
const ATTACKER_PANIC_RADIUS: float = 1.9
static var attacker_panic_radius: float = ATTACKER_PANIC_RADIUS
## How far into its charge a throw counts as committed and will not be aborted even
## to save the round. Keeps R-10(b)'s readable wind-up honest: a throw a human has
## already reacted to must still come out.
const ATTACKER_COMMIT_FRACTION: float = 0.6

## The nearest opposing Person worth breaking away from, or null. TWO bands, and the
## inner one is the bug fix — see ATTACKER_PANIC_RADIUS:
##   • inside `attacker_panic_radius`: a threat regardless of closing speed, because a
##     taya that has stopped moving in order to charge a bump at you is exactly as
##     dangerous standing still as it is walking, and the closing-speed test alone
##     would score it as harmless;
##   • out to ATTACKER_DODGE_RADIUS: only if genuinely closing, so the attacker does
##     not flee everything standing near it and never retrieve anything (that failure
##     is B-124's family, arriving from the opposite direction).
func _threatening_defender() -> CharacterBase:
	var best: CharacterBase = null
	var best_distance := maxf(ATTACKER_DODGE_RADIUS, attacker_panic_radius)
	for other in _roster():
		if other == null or not is_instance_valid(other):
			continue
		if not other.is_person or other.team == character.team:
			continue
		var to_us := character.global_position - other.global_position
		to_us.y = 0.0
		var distance := to_us.length()
		if distance > best_distance or distance < 0.01:
			continue
		if distance > attacker_panic_radius:
			# Closing speed along the line between us, from the threat's own velocity.
			# A taya standing still next to the can is not a reason to abandon a fetch.
			var closing := other.velocity.dot(to_us.normalized())
			if closing < ATTACKER_DODGE_CLOSING_SPEED:
				continue
		best = other
		best_distance = distance
	return best

func _cond_attacker_threatened() -> bool:
	return _threatening_defender() != null

## A defender within arm's length who is ALSO winding up a bump, and this throw is
## not already committed. Runs above everything else in the attacker's tree — see
## the `panic` node's own comment for the (now-historical, tag-era) measurement
## that put it there, and the addendum right after it for what changed.
##
## ⚠️ THE BUMP-CHARGE GATE IS THE WHOLE FIX FOR "RAN AWAY INSTEAD OF THROWING",
## ONE LAYER LATER THAN RUN 5 FOUND IT. RUN 5 already learned that fleeing a mere
## defender while HOLDING the slipper breaks the offence outright (see the `evade`
## sequence's own doc) — this is the same lesson applied to the panic band: without
## the charge check, an attacker mid-throw-approach would flinch at every taya that
## merely stood nearby, not only ones actually about to hit it, which is exactly
## the "ran away instead of throwing" failure one radius closer in.
func _cond_attacker_panic() -> bool:
	if _attacker_charging and _attacker_hold_target > 0.0 \
			and _attacker_charge_time >= _attacker_hold_target * ATTACKER_COMMIT_FRACTION:
		return false # the shot is away; taking the bump with it is a fair trade
	var threat := _threatening_defender()
	if threat == null:
		return false
	if character.global_position.distance_to(threat.global_position) > attacker_panic_radius:
		return false
	# A defender not currently charging can only land a TAP — no stagger, no drop
	# (Design.md §4's own table) — which is not worth fleeing over. `-1.0` means "not
	# charging at all"; anything else, including a fresh 0.0, is a real commitment in
	# progress and worth reacting to before it resolves.
	return threat.observed_bump_charge() >= 0.0

## Break perpendicular to the threat's approach, on whichever side we are already
## off toward — the same commit-to-a-side rule the Can's own evasion uses
## (`_act_can_evade`), and for the same reason: alternating sides every tick is
## not a dodge, it is a stutter that stays exactly where it started.
func _act_attacker_dodge(_delta: float) -> int:
	var threat := _threatening_defender()
	if threat == null:
		return BTNode.FAILURE
	# SPRINT. Breaking away is a closing-distance move in reverse — every bit of
	# extra speed here is the gap that decides whether the bump lands.
	_sprint_want = true
	var away := character.global_position - threat.global_position
	away.y = 0.0
	if away.length() < 0.01:
		return BTNode.FAILURE
	away = away.normalized()
	var side := Vector3(-away.z, 0.0, away.x)
	# Commit to the side the threat is NOT already covering.
	var threat_motion := threat.velocity
	threat_motion.y = 0.0
	if threat_motion.length() > 0.01 and side.dot(threat_motion.normalized()) > 0.0:
		side = -side
	# Mostly sideways with a little backward, so the break opens a gap instead of
	# merely orbiting at a fixed radius.
	var target := character.global_position + (side * 0.8 + away * 0.6).normalized() \
		* ATTACKER_DODGE_STEP
	_move_toward(target)
	return BTNode.RUNNING

func _blocking_defender(can: CharacterBase) -> CharacterBase:
	for other in _roster():
		if other == null or not is_instance_valid(other):
			continue
		if not other.is_person or other.team == character.team:
			continue
		var lane := can.global_position - character.global_position
		lane.y = 0.0
		var to_other := other.global_position - character.global_position
		to_other.y = 0.0
		if lane.length() < 0.1:
			continue
		var along := to_other.dot(lane.normalized())
		if along <= 0.0 or along >= lane.length():
			continue # behind us, or past the can
		var perpendicular := (to_other - lane.normalized() * along).length()
		if perpendicular < ATTACKER_LANE_CLEARANCE:
			return other
	return null

## A spot at throwing range from the can whose lane the defender is NOT sitting
## in. Samples bearings around the can starting from the one we already hold, so
## the attacker slides to the nearest open angle rather than teleporting its
## intent to the far side every decision tick.
##
## ⚠️ PREFERS A SPOT BEHIND THE LONG-THROW LINE, WHEN THE SCAN FINDS ONE, PER
## `Design.md` §3.1 — the human's own instruction is that the attacker AI "should
## prefer to release from behind that line." `LONG_THROW_LINE` (6.0) happens to
## equal `ATTACKER_THROW_RANGE` (6.0), the outer edge of the band this leaf is even
## allowed to stand in, but the two are different METRICS: the line is a CHEBYSHEV
## test against the world origin (`Carriable.is_behind_throwing_line`, `max(|x|,
## |z|) >= 6.0`) and this scan is a EUCLIDEAN radius around the can, so standing at
## the very edge of the band only actually crosses the line on a near-axis-aligned
## bearing — the same square-vs-circle gap `CONFINEMENT_RADIUS`'s own doc explains
## for the confinement box. Reaching almost the whole band (0.98, not the old 0.92)
## is what gives an axis-ish bearing room to cross it at all; the scan below then
## asks the game's own predicate directly rather than reasoning about angles, and
## only settles for a nearer, non-bonus spot when nothing open clears the line.
##
## WRITTEN, NOT MEASURED — this cannot guarantee a long-throw spot exists for every
## defender position (most open bearings at 6.0 EUCLIDEAN units do not satisfy the
## CHEBYSHEV test at all), only that the AI takes one when the scan turns one up.
func _open_throwing_spot(can: CharacterBase) -> Vector3:
	var current := character.global_position - can.global_position
	current.y = 0.0
	if current.length() < 0.1:
		current = Vector3.FORWARD
	var base_angle := atan2(current.z, current.x)
	var reach: float = ATTACKER_THROW_RANGE * 0.98
	# 0 first (hold this bearing if it is already open), then alternate outward.
	var steps: Array[float] = [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6, 2.2, -2.2]
	var fallback := Vector3.ZERO
	var have_fallback := false
	for step in steps:
		var a: float = base_angle + step
		var spot := can.global_position + Vector3(cos(a), 0.0, sin(a)) * reach
		if not _throwing_spot_is_clear(can, spot):
			continue
		if not have_fallback:
			fallback = spot
			have_fallback = true
		# Preferred, not required: the long-throw bonus (1.20x speed, 1.25x
		# knockback, a 5 s stun on a max-charge hit — Design.md §3.1) is worth
		# taking the second-open bearing over the nearest one, but never worth
		# abandoning an open lane entirely to chase, which is why this can only
		# ever pick among bearings the scan already found clear.
		if Carriable.is_behind_throwing_line(spot):
			return spot
	if have_fallback:
		return fallback
	# Every bearing covered — take the one furthest from the defender anyway
	# rather than freezing, which is what "the bots suck" looked like.
	return can.global_position + Vector3(cos(base_angle + PI), 0.0, sin(base_angle + PI)) * reach

## Whether `spot` (a candidate throwing position) has a clear lane to `can` — no
## opposing Person standing within `ATTACKER_LANE_CLEARANCE` of the line between
## them. Factored out of `_open_throwing_spot` so the long-throw preference above
## can ask "is this bearing open" without duplicating the geometry.
func _throwing_spot_is_clear(can: CharacterBase, spot: Vector3) -> bool:
	for other in _roster():
		if other == null or not is_instance_valid(other):
			continue
		if not other.is_person or other.team == character.team:
			continue
		var lane := can.global_position - spot
		lane.y = 0.0
		var to_other := other.global_position - spot
		to_other.y = 0.0
		if lane.length() < 0.1:
			continue
		var along := to_other.dot(lane.normalized())
		if along <= 0.0 or along >= lane.length():
			continue
		if (to_other - lane.normalized() * along).length() < ATTACKER_LANE_CLEARANCE:
			return false
	return true

## ---------------------------------------------------------------------------
## Roster lookups. get_parent() resolves to whatever this AI's own character's
## parent actually is, which differs by mode rather than needing a mode check
## here: Single Player's four units are direct siblings under Main.tscn's root
## (see Main.tscn / main.gd::_local_roster), while a networked AI-driven
## character's parent is $Players, the same MultiplayerSpawner.spawn_path
## every real networked character (and every other AI-driven one) is spawned
## under — see main.gd's own MultiplayerSpawner setup. Either way every
## sibling CharacterBase under that same parent is a legitimate roster entry.
## ---------------------------------------------------------------------------

func _roster() -> Array[CharacterBase]:
	var result: Array[CharacterBase] = []
	var parent := character.get_parent()
	if parent == null:
		return result
	for child in parent.get_children():
		if child is CharacterBase:
			result.append(child as CharacterBase)
	return result

## The opposing team's Person while that team is on offence — i.e. the unit
## this Taya's whole job is to stop.
func _find_enemy_attacker() -> CharacterBase:
	for other in _roster():
		if other == character or other.team == character.team:
			continue
		if other.is_person and not other.team_is_can_side:
			return other
	return null

## This Taya's own team's Attacker — same lookup as above, mirrored to the
## other side, for a loose Tsinelas deciding who to crawl toward.
func _find_own_attacker() -> CharacterBase:
	for other in _roster():
		if other == character or other.team != character.team:
			continue
		if other.is_person and not other.team_is_can_side:
			return other
	return null

## This Attacker's own team's Tsinelas Prop, only while it is actually LOOSE
## (can_be_grabbed_by() already encodes the team-ownership rule — reused here
## rather than re-deriving it, same as carrier.gd's own _find_grabbable()).
func _find_own_loose_tsinelas() -> Carriable:
	for other in _roster():
		if other == character or other.is_person:
			continue
		var carriable := other.get_node_or_null("Carriable") as Carriable
		if carriable == null:
			continue
		if carriable.can_be_grabbed_by(character):
			return carriable
	return null

## RoundManager's own tracked-Can list, same accessor offscreen_indicators.gd
## already uses for this exact lookup — reused rather than re-deriving is_can
## a third time across the codebase.
func _find_tracked_can() -> CharacterBase:
	for can in RoundManager.get_tracked_cans():
		if is_instance_valid(can) and can != character:
			return can
	return null

## ---------------------------------------------------------------------------
## Movement and input primitives.
## ---------------------------------------------------------------------------

func _random_point_in_confinement(inner_fraction: float) -> Vector3:
	var angle := _rng.randf() * TAU
	var min_r := CharacterBase.confinement_radius * inner_fraction * 0.3
	var max_r := CharacterBase.confinement_radius * maxf(inner_fraction, 0.35)
	var radius := _rng.randf_range(min_r, max_r)
	return Vector3(cos(angle) * radius, character.global_position.y, sin(angle) * radius)

## World-space direction, matching character_base.gd's own non-mouse-aimed
## movement scheme (`Vector3(input_dir.x, 0, input_dir.y)` — see its
## _physics_process comment on B-60): +X presses move_right, +Z presses
## move_down. AI units never carry CameraRig.AimSource.MOUSE (only the
## human's own rig is ever set to it — see main.gd::_start_local_test), so
## this world-space scheme is always the correct one for anything this file
## drives. ⚠️ tools/ai_probe.gd's fairness mode attaches an AIController to the
## human's own unit, and has to flip that rig to MOVEMENT for exactly this
## reason — see its _take_over_human_slot().
## ---------------------------------------------------------------------------
## NATURAL MOTION. 🧑 Human ask, 2026-07-30: *"i want the AI's movement to feel
## natural and not too FAST or mechanical."*
##
## ⚠️ WHY IT LOOKED MECHANICAL, stated exactly, because the cause is not "the speed
## number is too high". `character_base.gd::input_vector()` builds an AI unit's
## movement from FOUR BOOLEANS and then `_physics_process` NORMALISES the result —
## so every AI unit moves at exactly `SPEED`, in exactly one of EIGHT compass
## directions, and changes between them in a single frame. Three separate artefacts
## fall out of that, and this function is where all three lived:
##
##   1. **Instant reversals.** The old code wrote the compass keys straight from the
##      direction to the target, so a re-picked goal 170 degrees away snapped the
##      unit's velocity in one frame. Nothing alive turns like that.
##   2. **Buzzing on the diagonals.** A single hard threshold (`DEAD = 0.15`) means a
##      heading hovering near it flips a key on and off every few frames. That is
##      what read as twitchy, and it is also what inflated the start/stop transition
##      count the independence audit reports (RUN 10: 598-756 transitions per bot).
##   3. **Always flat out.** Every unit either walks at 6.0 or stands still.
##
## The fixes, in the same order, and none of them touches gameplay code:
##
##   1. A HEADING that turns at a limited rate (`ai_turn_rate`) toward the direction
##      wanted, with the compass keys derived from the heading instead of from the
##      goal. Paths curve; a reversal becomes a turn that takes ~0.4 s.
##   2. A SCHMITT TRIGGER on each key: it takes `AI_PRESS_ON` to start pressing a
##      direction and it keeps pressing until the component falls under
##      `AI_PRESS_OFF`. A heading sitting on a threshold now holds its key instead of
##      chattering.
##   3. A GAIT — see `tier_gait` — so a bot walks with purpose rather than sliding at
##      the engine's maximum.
## ---------------------------------------------------------------------------

## Radians per second the heading may swing. 8.0 turns a full reversal in ~0.39 s,
## which reads as a person changing their mind rather than a turret slewing.
## ⚠️ IT IS A REAL COST, NOT FREE POLISH: for that fraction of a second the unit is
## still moving the OLD way, so a taya can be beaten by a change of direction it has
## not finished answering. That is the same thing R-07 does deliberately, arriving
## from a different direction, and it is why this is a `static var` — if a sweep ever
## shows the defence losing its post because of it, this is the knob.
const AI_TURN_RATE: float = 8.0
static var ai_turn_rate: float = AI_TURN_RATE
## Schmitt trigger thresholds on each compass key. ON is deliberately well above OFF.
const AI_PRESS_ON: float = 0.34
const AI_PRESS_OFF: float = 0.12

## Unit heading this controller is currently walking along, in world space. Persists
## across a release so resuming a walk continues the turn instead of snapping.
var _heading: Vector3 = Vector3.ZERO

## ⚠️ NOBODY STANDS PERFECTLY STILL, AND THE OLD CODE MADE EVERYONE DO IT.
##
## Arriving used to mean releasing every key, so a taya on its post or an attacker
## waiting for its slipper to crawl out froze solid — measured at **5.3 s of dead
## stillness on three of four units**, which is both the thing the independence
## audit's "< 2 s" bar exists to catch and the thing that makes a bot read as a
## cardboard cut-out rather than a player. (The bar was catching something real; the
## per-unit breakdown is what made it obvious that the culprits were units doing
## exactly what they were told.)
##
## So an arrived unit SETTLES instead of freezing: it drifts around its target inside
## a radius small enough to change nothing tactically. 0.22 units is a quarter of a
## Person's own width — it shifts weight, it does not reposition.
const IDLE_SHUFFLE_RADIUS: float = 0.22
const IDLE_SHUFFLE_ARRIVE: float = 0.08
var _idle_offset: Vector3 = Vector3.ZERO

func _move_toward(target: Vector3, arrive: float = ARRIVE_DISTANCE) -> void:
	var offset := target - character.global_position
	offset.y = 0.0
	if offset.length() <= arrive:
		# Settle rather than freeze. Re-picked on the same slow cadence as every other
		# goal, so it is a shift of weight every third of a second and not a vibration.
		var settle := target + _idle_offset - character.global_position
		settle.y = 0.0
		# ⚠️ RE-PICK ON ARRIVAL, NOT ONLY ON THE DECISION TICK. Measured with the
		# stillness trace: waiting for the next re-pick left units motionless for
		# whole seconds at a time in `hold-post` and `stand-down`, which is the
		# freeze this whole mechanism exists to remove. Choosing the next spot the
		# instant the last one is reached keeps the drift continuous.
		if _repick or _idle_offset.is_zero_approx() or settle.length() <= IDLE_SHUFFLE_ARRIVE:
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(IDLE_SHUFFLE_RADIUS * 0.6, IDLE_SHUFFLE_RADIUS)
			_idle_offset = Vector3(cos(a) * r, 0.0, sin(a) * r)
			settle = target + _idle_offset - character.global_position
			settle.y = 0.0
		if settle.length() < 0.01:
			_release_move(0.0)
			return
		# Settling is a shift of weight, not a dart. See CAN_IDLE_GAIT for the
		# measurement that made this necessary rather than decorative.
		_gait_want = minf(_gait_want, IDLE_GAIT)
		_press_compass(settle.normalized())
		return
	_idle_offset = Vector3.ZERO
	var want := offset.normalized()
	if _heading.length() < 0.01:
		_heading = want
	else:
		# Turn toward the goal at a bounded rate. signed_angle_to gives the short way
		# round, so a 179-degree change turns the near way rather than spinning.
		var step: float = ai_turn_rate * maxf(_last_delta, 1.0 / 60.0)
		var angle: float = _heading.signed_angle_to(want, Vector3.UP)
		_heading = _heading.rotated(Vector3.UP, clampf(angle, -step, step)).normalized()
	_press_compass(_heading)

## Write the four compass keys from a heading, with hysteresis per key.
func _press_compass(dir: Vector3) -> void:
	_set_held("move_right", _compass_hold("move_right", dir.x))
	_set_held("move_left", _compass_hold("move_left", -dir.x))
	_set_held("move_down", _compass_hold("move_down", dir.z))
	_set_held("move_up", _compass_hold("move_up", -dir.z))

## One key's Schmitt trigger. Reads the belief `_set_held` already maintains rather
## than keeping a second copy of it.
func _compass_hold(base: String, component: float) -> bool:
	var pressed: bool = bool(_held_actions.get(base, false))
	return component > (AI_PRESS_OFF if pressed else AI_PRESS_ON)

## Takes an ignored `delta` so it can double as a BTAction leaf (see
## `stand-down` in three branches of the tree) without a one-line wrapper.
func _release_move(_delta: float = 0.0) -> void:
	_set_held("move_left", false)
	_set_held("move_right", false)
	_set_held("move_up", false)
	_set_held("move_down", false)

## Presses or releases a HELD action.
func _set_held(base: String, want_pressed: bool) -> void:
	# ⚠️ PER-CHARACTER INTENT, NOT THE GLOBAL `Input` SINGLETON.
	#
	# This used to call `Input.action_press(character.action_name(base))`, which
	# is process-global state keyed only by player_id — and main.gd hands AI
	# slots player_id (index % 2) + 3, so index 0 and index 2 both got p3. Two
	# bots then shared one action set, which is BOTH reported symptoms at once:
	# they moved in lockstep because they were reading each other, and they
	# froze because this function used to be edge-triggered against its own
	# belief, so one bot's release cancelled the other's press and neither
	# re-pressed. character_base.gd::input_pressed carries the full write-up.
	#
	# No transition guard any more, and none is needed: writing an unchanged
	# value into a dictionary is idempotent, and the edge helpers on
	# CharacterBase derive just_pressed/just_released from frame-to-frame
	# difference rather than from anything this function remembers.
	_held_actions[base] = want_pressed
	if character != null:
		character.ai_set_intent(base, want_pressed)

## A short press for an edge-triggered action (bump, Tag/special_ability on
## the defence side, grab) — pressed now, queued to release a few frames into
## the future (see RELEASE_SETTLE_FRAMES' own doc for why a SINGLE frame is
## not enough: input_just_pressed()/input_just_released() lag one physics frame
## behind the intent write that causes them, so a bare one-frame tap can end up
## released again before the game code watching for it ever reads the edge).
## Matches a human's tap: one just_pressed edge, not a hold.
func _tap(base: String) -> void:
	_set_held(base, true)
	_pending_release[base] = RELEASE_SETTLE_FRAMES

func _flush_pending_releases() -> void:
	if _pending_release.is_empty():
		return
	var done := []
	for base in _pending_release.keys():
		_pending_release[base] -= 1
		if _pending_release[base] <= 0:
			_set_held(base, false)
			done.append(base)
	for base in done:
		_pending_release.erase(base)
