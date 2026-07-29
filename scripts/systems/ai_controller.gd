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
const TAYA_BLOCK_STANDOFF: float = 2.6
## Distance from the can an Attacker tries to hold before charging — mirrors
## the map's own throwing line (Art_Direction.md §9's 6-unit derivation).
## This file does not import that constant; it just aims for the same number
## so the AI throws from roughly where a human would.
const ATTACKER_THROW_RANGE: float = 6.0
const ATTACKER_GRAB_RANGE: float = 1.5
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
## fairness log (docs/Checklist.md §9). A tag by the defending Person ends the
## round outright (hitbox.gd's own rule, not this file's), so pursuit is not a
## small adjustment:
##     0.0 -> defence 100%, 12/20 by tag,  8/20 timeout, longest still-run 23.6s
##     2.0 -> defence 100%, 10/20 by tag, 10/20 timeout, longest still-run 30.9s
##     5.0 -> defence 100%, 20/20 by tag,  0/20 timeout, longest still-run  2.0s
## Every value gives the defence 100%, because the offence currently cannot win
## at all (B-119/B-120 in the same log) — so this knob does not decide fairness
## today, it only decides HOW the defence wins.
##
## ⚠️ NO LONGER 0.0. Human call: *"ensure the defender AI actively tries to tag
## attackers."* At 0.0 the Taya never leaves its blocking post, so
## `_act_taya_tag` — the only leaf that presses bump — could only ever fire if the
## attacker walked into it. That is body-blocking, not tagging, and the report is
## correct that it does not look like a defender playing.
##
## ⚠️ 3.6, NOT 5.0, AND THE DIFFERENCE IS THE WHOLE MEASUREMENT ABOVE. 5.0 is
## CONFINEMENT_RADIUS, i.e. "chase anywhere in my box", and it measured 20/20
## rounds won by tag. 3.6 sits INSIDE the box: the Taya holds its post while the
## attacker is out at the 6.0 throwing line, and breaks off to chase only once the
## attacker crosses into the defended area — which is exactly the moment it has to
## come in and fetch its own tsinelas. So the Taya tags the thing worth tagging
## and does not abandon the can to sprint at a thrower it can never reach.
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

const DIFFICULTY_TIERS: Dictionary = {
	# "Bata" — a kid. Holds its post, aims where the can is rather than where it
	# will be, thinks slowly and never fully winds up.
	Difficulty.BATA:   {"pursue": 1.8, "lead": 0.25, "think": 0.50, "charge": 0.40},
	Difficulty.NORMAL: {"pursue": 1.8, "lead": 0.60, "think": 0.35, "charge": 0.65},
	# "Astig" — the one who wins. Chases to the edge of its own box and leads
	# almost perfectly.
	Difficulty.ASTIG:  {"pursue": 4.6, "lead": 0.85, "think": 0.22, "charge": 0.80},
}

static var difficulty: Difficulty = Difficulty.NORMAL
## Live tier values, read by the leaves. Separate from the constants they replace
## so a probe sweeping one knob does not have to know about the others.
static var tier_lead: float = 0.6
static var tier_think: float = 0.35
static var tier_charge: float = 0.65

## Pushes `difficulty` into the four live knobs. Static, so a probe or a future
## settings screen can call it once and every controller in the match follows —
## the knobs are static for the same reason.
static func apply_difficulty(tier: Difficulty) -> void:
	difficulty = tier
	var values: Dictionary = DIFFICULTY_TIERS[tier]
	taya_pursue_radius = float(values["pursue"])
	tier_lead = float(values["lead"])
	tier_think = float(values["think"])
	tier_charge = float(values["charge"])
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

## ⚠️ THE CAN HOLDS ITS CIRCLE. IT DOES NOT WANDER THE BOX. Evasion pre-empts
## the hold, and because the tree is reactive that pre-emption happens on the
## frame the throw becomes a threat, not at the next decision tick.
func _build_can_branch() -> BTNode:
	return BTSelector.new(&"can-do", [
		BTSequence.new(&"evade", [
			BTCondition.new(&"slipper-incoming", &"_cond_slipper_incoming"),
			BTAction.new(&"sidestep-guard", &"_act_evade"),
		]),
		BTAction.new(&"hold-mark", &"_act_can_hold_mark"),
	])

## ⚠️ BODY-BLOCK, DO NOT CHASE — see _act_taya_body_block for the geometry
## argument. Ordered melee > close-gap > block > wander, so the Taya only ever
## leaves its blocking post for a threat it can actually reach.
func _build_taya_branch() -> BTNode:
	return BTSelector.new(&"taya-do", [
		BTSequence.new(&"engage", [
			BTCondition.new(&"threat-in-detect-range", &"_cond_taya_threat_visible"),
			BTSelector.new(&"engage-how", [
				BTSequence.new(&"tag", [
					BTCondition.new(&"threat-in-melee", &"_cond_taya_threat_in_melee"),
					BTAction.new(&"tap-bump", &"_act_taya_tag"),
				]),
				BTSequence.new(&"close-gap", [
					BTCondition.new(&"threat-in-box", &"_cond_taya_threat_in_confinement"),
					BTAction.new(&"charge-threat", &"_act_taya_close_gap"),
				]),
				BTAction.new(&"body-block", &"_act_taya_body_block"),
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
func _build_tsinelas_branch() -> BTNode:
	return BTSelector.new(&"tsinelas-do", [
		BTSequence.new(&"crawl-home", [
			BTCondition.new(&"is-loose", &"_cond_tsinelas_loose"),
			BTCondition.new(&"own-attacker-exists", &"_cond_own_attacker_exists"),
			BTCondition.new(&"not-yet-arrived", &"_cond_tsinelas_arrived", true),
			BTAction.new(&"crawl", &"_act_tsinelas_crawl"),
		]),
		BTAction.new(&"stand-down", &"_act_release_move"),
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

	_root.tick(self, delta)

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
	for base in ["bump", "special_ability", "grab", "guard_dash"]:
		_set_held(base, false)
	_pending_release.clear()
	_attacker_charging = false
	_attacker_charge_time = 0.0
	_release_settle_frames = 0
	_attacker_lane_blocked_for = 0.0
	# Hand the camera-based aim back. _release_all() is what runs when a human
	# takes this unit over or the round resets, and either way an AI's stale
	# target must not survive into someone else's throw (B-125).
	if character != null and is_instance_valid(character):
		character.ai_aim_point = Vector3.INF
	_clear_blackboard()

func _clear_blackboard() -> void:
	_bb_slipper = null
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
## Below this time-to-impact, stop dodging and raise Guard instead.
const CAN_GUARD_ETA: float = 0.22

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
	if vel.length() < 0.1:
		return BTNode.FAILURE
	var dir := vel.normalized()
	# Perpendicular in the ground plane; pick the side we are already off toward
	# so the Can commits rather than oscillating across the line each tick.
	var side := Vector3(-dir.z, 0.0, dir.x)
	var to_us := character.global_position - slipper.global_position
	to_us.y = 0.0
	if side.dot(to_us) < 0.0:
		side = -side
	var target := character.global_position + side * CAN_EVADE_STEP
	# Clamp back toward the mark. Base circle is world origin on every map.
	var from_mark := Vector3(target.x, 0.0, target.z)
	if from_mark.length() > CAN_EVADE_RADIUS:
		from_mark = from_mark.normalized() * CAN_EVADE_RADIUS
	_move_toward(Vector3(from_mark.x, character.global_position.y, from_mark.z))
	# Guard as well when it is too late to move — the Can's Guard blocks dents
	# outright (character_base.apply_dent), so a throw that cannot be dodged can
	# still be eaten. This is the Can genuinely trying to survive rather than
	# just jittering.
	var eta := to_us.length() / maxf(vel.length(), 0.01)
	_set_held("guard_dash", eta <= CAN_GUARD_ETA)
	return BTNode.SUCCESS

func _act_can_hold_mark(_delta: float) -> int:
	_set_held("guard_dash", false)
	if _repick or not _has_move_target:
		var angle := _rng.randf() * TAU
		var radius := _rng.randf() * CAN_HOLD_RADIUS
		_move_target = Vector3(cos(angle) * radius, character.global_position.y,
			sin(angle) * radius)
		_has_move_target = true
	_move_toward(_move_target)
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
## attacker MUST cross that radius to retrieve its own slipper and a defender's
## tag ends the round outright (hitbox.gd).
##
## So the radius is a knob, not the confinement wall — see
## `taya_pursue_radius`. The Taya is clamped to CONFINEMENT_RADIUS around the
## world origin (character_base.gd::_move_and_confine), so pursuit beyond that
## is geometrically pointless regardless of what this returns.
func _cond_taya_threat_in_confinement() -> bool:
	if taya_pursue_radius <= 0.0:
		return false
	var flat := Vector2(_bb_enemy_attacker.global_position.x, _bb_enemy_attacker.global_position.z)
	return flat.length() <= minf(taya_pursue_radius, CharacterBase.CONFINEMENT_RADIUS)

func _act_taya_tag(_delta: float) -> int:
	_release_move(0.0)
	if _taya_tap_cooldown <= 0.0:
		_taya_tap_cooldown = TAYA_TAP_INTERVAL
		_tap("bump")
	return BTNode.SUCCESS

func _act_taya_close_gap(_delta: float) -> int:
	_set_held("bump", false)
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
## which puts the Taya's body in the throw's path, keeps it near enough to
## tag anyone who closes, and keeps the can covered.
func _act_taya_body_block(_delta: float) -> int:
	_set_held("bump", false)
	var can := _find_tracked_can()
	if can == null or not is_instance_valid(can):
		# No can to stand in front of (pre-round, or it was just sealed) —
		# closing on the threat is the only thing left worth doing.
		_move_toward(_bb_enemy_attacker.global_position)
		return BTNode.SUCCESS
	var bearing := _bb_enemy_attacker.global_position - can.global_position
	bearing.y = 0.0
	if bearing.length() < 0.1:
		bearing = Vector3.FORWARD
	var standoff: float = minf(TAYA_BLOCK_STANDOFF, CharacterBase.CONFINEMENT_RADIUS - 0.4)
	_move_toward(can.global_position + bearing.normalized() * standoff)
	return BTNode.SUCCESS

## No threat in range. Patrol within the confinement box — no pathfinding
## around obstacles, since a straight-line wander is "moves with intent," not
## "plays well," per this item's own acceptance bar.
func _act_taya_wander(_delta: float) -> int:
	_set_held("bump", false)
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

func _act_attacker_retrieve(_delta: float) -> int:
	_has_move_target = false
	var target_char := _bb_loose_tsinelas.get_parent() as CharacterBase
	if target_char == null:
		return BTNode.FAILURE
	var distance := character.global_position.distance_to(target_char.global_position)
	if distance > ATTACKER_GRAB_RANGE:
		_move_toward(target_char.global_position)
		return BTNode.RUNNING
	_release_move(0.0)
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

func _cond_attacker_out_of_range() -> bool:
	var to_can := _bb_can.global_position - character.global_position
	to_can.y = 0.0
	return to_can.length() > ATTACKER_THROW_RANGE

func _act_attacker_approach(_delta: float) -> int:
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
func _lead_the_can(can: CharacterBase) -> Vector3:
	var here := character.global_position
	var mark := can.global_position + Vector3(0.0, 0.25, 0.0)
	var speed := _own_launch_speed()
	if speed <= 0.01:
		return mark
	var flight_time := here.distance_to(mark) / speed
	var drift := Vector3(can.velocity.x, 0.0, can.velocity.z) * flight_time * tier_lead
	return mark + drift

## The launch speed this unit's slipper will actually use, at the charge this
## leaf holds. Read off the held Carriable's own profile so it cannot drift out
## of step with the .tres files (they were retuned twice without this noticing).
func _own_launch_speed() -> float:
	var carrier := character.get_node_or_null("Carrier") as Carrier
	if carrier == null:
		return 0.0
	var held := carrier.held()
	if held == null:
		return 0.0
	var prop := held.get_parent() as CharacterBase
	if prop == null or prop.ability == null or not prop.ability.has_method("get_throw_profile"):
		# No ability means carriable.gd falls back to DEFAULT_PROFILE; 21.0 is
		# that resource's launch_speed. Only ever hit by a Prop with no ability.
		return 21.0 * _charge_fraction()
	var profile := prop.ability.get_throw_profile() as ThrowProfile
	if profile == null:
		return 21.0 * _charge_fraction()
	return profile.launch_speed * _charge_fraction()

## What fraction of full power this leaf's charge actually reaches.
##
## ⚠️ MIRRORS `carrier.gd::charge_power()` EXACTLY, floor included. That curve is
## not linear in hold time — it starts at CHARGE_MIN_POWER (0.35) so a panicked
## tap still throws — so a plain `hold / full` ratio underestimates the speed and
## therefore over-leads. At ATTACKER_CHARGE_TIME 0.65 the real figure is ~0.82,
## not 0.72. All three constants are read, never restated.
func _charge_fraction() -> float:
	return clampf(
		Carrier.CHARGE_MIN_POWER
			+ (tier_charge / Carrier.CHARGE_FULL_TIME) * (1.0 - Carrier.CHARGE_MIN_POWER),
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

## In range with a clear lane. Stand still to charge and release — moving
## mid-charge is not modelled (carrier.gd allows it; a human sometimes does
## too), keeping this pass simple. Returns RUNNING for the whole charge and
## SUCCESS on the frame the button is released, which is exactly the throw
## event tools/ai_probe.gd's fairness run counts.
func _act_attacker_charge_release(delta: float) -> int:
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
		character.ai_aim_point = _lead_the_can(_bb_can)
	if not _attacker_charging:
		_attacker_charging = true
		_attacker_charge_time = 0.0
		_set_held("special_ability", true)
	_attacker_charge_time += delta
	if _attacker_charge_time < tier_charge:
		return BTNode.RUNNING
	_set_held("special_ability", false)
	_attacker_charging = false
	_attacker_charge_time = 0.0
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
	_move_toward(_bb_own_attacker.global_position)
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
## (`_cond_lane_blocked`). It did not avoid the taya itself, and being tagged
## ends the round for its whole team — which is how 18 of 20 rounds ended in
## RUN 4. Avoiding a lane and avoiding a person are different behaviours and
## only the first one existed.
##
## WHERE THE TAG ACTUALLY COMES FROM, which is what shapes the dodge: the taya
## does not chase to the throwing line (it is capped at CONFINEMENT_RADIUS and
## `taya_pursue_radius` ships at 0). It gets its tag when the ATTACKER walks into
## the confinement box — which the attacker must do to fetch a slipper that
## landed near the can. So the dodge has to work while retrieving, not only while
## throwing, and that is why it sits above BOTH in the tree.
## ---------------------------------------------------------------------------

## How close an opposing Person has to be before the attacker breaks off.
## Comfortably outside TAYA_MELEE_RANGE (1.4) so the dodge starts before the tag
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

## The nearest opposing Person that is close enough AND closing fast enough to be
## worth breaking away from, or null.
func _threatening_defender() -> CharacterBase:
	var best: CharacterBase = null
	var best_distance := ATTACKER_DODGE_RADIUS
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

## Break perpendicular to the threat's approach, on whichever side we are already
## off toward — the same commit-to-a-side rule the Can's own evasion uses
## (`_act_can_evade`), and for the same reason: alternating sides every tick is
## not a dodge, it is a stutter that stays exactly where it started.
func _act_attacker_dodge(_delta: float) -> int:
	var threat := _threatening_defender()
	if threat == null:
		return BTNode.FAILURE
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
func _open_throwing_spot(can: CharacterBase) -> Vector3:
	var current := character.global_position - can.global_position
	current.y = 0.0
	if current.length() < 0.1:
		current = Vector3.FORWARD
	var base_angle := atan2(current.z, current.x)
	var reach: float = ATTACKER_THROW_RANGE * 0.92
	# 0 first (hold this bearing if it is already open), then alternate outward.
	var steps: Array[float] = [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6, 2.2, -2.2]
	for step in steps:
		var a: float = base_angle + step
		var spot := can.global_position + Vector3(cos(a), 0.0, sin(a)) * reach
		var clear := true
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
				clear = false
				break
		if clear:
			return spot
	# Every bearing covered — take the one furthest from the defender anyway
	# rather than freezing, which is what "the bots suck" looked like.
	return can.global_position + Vector3(cos(base_angle + PI), 0.0, sin(base_angle + PI)) * reach

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
	var min_r := CharacterBase.CONFINEMENT_RADIUS * inner_fraction * 0.3
	var max_r := CharacterBase.CONFINEMENT_RADIUS * maxf(inner_fraction, 0.35)
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
func _move_toward(target: Vector3) -> void:
	var offset := target - character.global_position
	offset.y = 0.0
	if offset.length() <= ARRIVE_DISTANCE:
		_release_move(0.0)
		return
	var dir := offset.normalized()
	const DEAD := 0.15
	_set_held("move_right", dir.x > DEAD)
	_set_held("move_left", dir.x < -DEAD)
	_set_held("move_down", dir.z > DEAD)
	_set_held("move_up", dir.z < -DEAD)

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
