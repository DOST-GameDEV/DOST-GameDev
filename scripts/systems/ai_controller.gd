extends Node
class_name AIController
## Fills a seat nobody is sitting in — Single Player, and any empty slot in a
## networked lobby. **Rewritten 2026-08-01 by 🤖 `build ai`**, replacing the
## ~250-line placeholder the HARRYDAKS pivot left behind.

## ---------------------------------------------------------------------------
## ⚠️⚠️ WHAT THIS REPLACES, AND THE TWO MEASURED NUMBERS THAT MADE IT NECESSARY.
##
## The predecessor's own header said *"it is a placeholder that films, not a
## baseline worth tuning"* and *"do not tune it, replace it"*. Two numbers off the
## board (§6.6, §6.7) said the same thing in measurements:
##
##   · **51 slipper flights, 0 knockdowns over a 40 s match.**
##   · **The bots barely moved — 14.2 m and 26.0 m over a 90 s round, against a
##     3.45 m/s attacker walk.** 90 s at 3.45 m/s is 310 m of ground available.
##
## Both had a single cause each, and both causes are worth writing down because
## neither is visible in the branch that contains it.
##
## ⚠️ **CAUSE 1 — EVERY THROW WAS RELEASED AT ALMOST MINIMUM POWER, AND MINIMUM
## POWER CANNOT PHYSICALLY REACH THE LATA.** The old file released a charge when
## it "stopped rising", with `PLATEAU_EPSILON = 0.005` compared against the power
## gained in ONE frame. `charge_power()` is `lerp(0.35, 1.0, t / 2.5)`, so one
## 60 Hz frame adds **0.0043** — permanently below the 0.005 epsilon. The
## plateau detector therefore fired on the third frame of every wind-up, for ever,
## and every throw left the hand at power ≈ 0.36.
##
## Power is a SPEED scale (`slipper.gd`: `17.0 * lerp(0.35, 1.0, power)`), so
## 0.36 is 10.6 m/s, whose 45° range is `v²/g` = **5.6 m**. The throw gate makes
## the shortest legal throw `CONFINEMENT_RADIUS` = **6.5 m**, and the bots stood
## further out than that. Every single shot was launched with no solution:
## `_solve_arc()`'s discriminant went negative, it fell back to "throw along the
## line and let it fall short" exactly as its own comment promises, and 51
## slippers were dropped politely into the dirt. **The AI was not aiming badly.
## It was throwing a ball that could not get there.**
##
## The replacement never guesses at power. `_min_power_for()` inverts the range
## equation — `v_min = sqrt(g · (Δy + sqrt(Δy² + d²)))` — and the bot charges to
## a real margin over it or does not throw at all.
##
## ⚠️ **CAUSE 2 — THE BOTS WERE ALL WALKING TO A SLIPPER THEY WERE FORBIDDEN TO
## TOUCH.** `_nearest_loose_slipper()` picked the nearest LOOSE slipper. Since
## 2026-08-01 a slipper belongs to exactly one attacker (`Design.md` §5.2), and
## `can_be_grabbed_by()` refuses everybody else. So all three attackers walked to
## whichever slipper happened to be nearest, stood on it, and pressed `grab` at a
## prop that would never answer. That is §6.3's "three bots all chasing the same
## slipper" — not a coordination failure to be designed around, a **rule the AI
## had never been told about**. Two of the three bots then had nothing to do and
## nowhere to be, which is most of the missing 280 metres.
##
## ⚠️ **AND THE HUMAN'S REPORT WAS THE THIRD SYMPTOM OF THE SAME THING.** 🧑
## 2026-08-01: *"the ai is so horrible they all move at the same time"*. One
## think interval, one shared plan, three identical bodies: with the same target
## and the same 0.35 s clock started on the same frame, three bots are one bot
## drawn three times. Every bot now carries a `_Personality` derived from its
## seat (§ PERSONALITY) and its think clock starts on a random phase.
## ---------------------------------------------------------------------------
## ⚠️ IT PRESSES BUTTONS, IT DOES NOT MOVE BODIES, AND THAT SURVIVES THE REWRITE.
## Every decision leaves through `CharacterBase.ai_set_intent()`, the same
## indirection a human's keyboard feeds, so `_physics_process` never branches on
## who is driving — the confinement clamp, the stun states, the throw gate, the
## stamina pool and the netcode all apply to a bot for free. An AI that wrote
## `velocity` directly would desync the moment it was not the authority for the
## body it was writing to.
##
## ⚠️ AND THE VOCABULARY IS A KEYBOARD'S, DELIBERATELY. `_drive()` emits four
## digital direction presses, so a bot moves on **exactly the eight headings a
## human has** and turns by walking, exactly as a human does. It would have been
## easy to hand the AI an analogue bearing here; it would also have made every
## fairness number this file prints a comparison between two different games.
##
## ⚠️ RANDOMNESS IS SAFE HERE **BECAUSE AI ONLY EXISTS ON THE HOST.** `main.gd`
## attaches a controller under `NetworkManager.is_host()` (or with no session at
## all), and every consequence of a decision reaches other peers as replicated
## character state, never as a re-simulated decision. This is the opposite of
## `_refresh_ai_prop_picks()`, where `randi()` really would give two peers two
## answers — that one is a value each peer derives for itself.
## ---------------------------------------------------------------------------

## ---------------------------------------------------------------------------
## § DIFFICULTY — three complete configurations, not two knobs.
##
## ⚠️ THE OLD TABLE HAD THREE KEYS AND ITS OWN COMMENT ADMITTED WHY: *"what
## survives is the two things a simple bot can honestly vary"*. A picker that
## sells "the one who wins" against "the kid" on reaction time and aim scatter is
## selling a difference the player cannot see, because neither tier could score.
##
## Every knob below is something the bot visibly DOES differently, and each one
## is read at exactly one place in this file so a tier can be reasoned about by
## reading the table rather than the code:
##
##   react           seconds of tracking lag. The bot's picture of where everyone
##                   is trails the truth by a first-order lag of this constant,
##                   and every reactive trigger has to hold true this long before
##                   it fires. This is the single biggest "is it a person" knob.
##   think           seconds between re-plans.
##   lead            0..1 — how much of a target's velocity it extrapolates when
##                   chasing or lunging. 0 chases where you WERE.
##   aim_error       metres of scatter on the aim point, quoted at 7.5 m and
##                   scaled with range (§ AIM).
##   aim_settle      seconds of holding a wind-up before the scatter is cut to a
##                   third. A big number means it never settles.
##   power_margin    multiplier on the MINIMUM launch speed that reaches the
##                   lata. 1.0 is a throw that only just arrives — slow, lofted
##                   and blockable. Higher is flatter, faster and harder to read.
##   lane_patience   seconds it will hold a charge waiting for the throwing lane
##                   to clear. 0 means it throws through the taya's chest.
##   spacing         0..1 — how hard it works to attack from a bearing its two
##                   rivals are not already using (§ SPACING).
##   fetch_caution   metres of taya proximity to its slipper that will make it
##                   wait for a distraction instead of running in.
##   sabotage        0..1 — willingness to shove a rival who is about to be
##                   tagged, for the +50 (`Design.md` §8).
##   intercept       0..1 — how hard the taya commits to stepping into a slipper
##                   already in the air (the body block).
##   camp            0..1 — how much the taya pre-covers a loose slipper lying in
##                   its own box, waiting for the retrieval.
##   lunge_range     metres at which the taya commits the 2.5 m dash.
##   lunge_cone      degrees of forward error it will accept before dashing. The
##                   lunge fires along `-basis.z`, so a bot that dashes at a bad
##                   angle simply misses.
##   dodge           0..1 — reaction to a visible lunge wind-up.
##   sprint_reserve  fraction of the 50-point bar it refuses to sprint below, so
##                   it is not fatigued at the moment it needs the burst. **Low
##                   is worse**: the kid burns the bar and gets caught standing.
##   mistake         0..1 — chance per plan of deliberately taking the worse
##                   option (see `_blunder()`).
##
## ⚠️ THE TIER NAMES ARE STILL `BATA / NORMAL / ASTIG` IN CODE and still read
## EASY / NORMAL / HARD on screen. `match_setup.gd` owns the strings; the human
## call recorded there (*"only tagalog i want are names"*) is about what a player
## reads, and renaming the enum would break `settings.cfg`'s stored index and
## every probe that names a tier on the command line.
## ---------------------------------------------------------------------------

enum Difficulty { BATA, NORMAL, ASTIG }

const DIFFICULTY_TIERS: Dictionary = {
	Difficulty.BATA: {
		"react": 0.55, "think": 0.34, "lead": 0.00,
		"aim_error": 1.75, "aim_settle": 99.0, "power_margin": 1.04,
		"lane_patience": 0.0, "spacing": 0.15, "fetch_caution": 0.0,
		"sabotage": 0.0,
		"intercept": 0.0, "camp": 0.0, "lunge_range": 1.9, "lunge_cone": 55.0,
		"dodge": 0.0, "sprint_reserve": 0.0, "mistake": 0.30,
	},
	Difficulty.NORMAL: {
		"react": 0.30, "think": 0.24, "lead": 0.45,
		"aim_error": 1.45, "aim_settle": 1.40, "power_margin": 1.18,
		"lane_patience": 1.1, "spacing": 0.60, "fetch_caution": 3.2,
		"sabotage": 0.35,
		"intercept": 0.60, "camp": 0.45, "lunge_range": 2.6, "lunge_cone": 34.0,
		"dodge": 0.55, "sprint_reserve": 0.25, "mistake": 0.10,
	},
	Difficulty.ASTIG: {
		"react": 0.14, "think": 0.16, "lead": 0.85,
		"aim_error": 1.10, "aim_settle": 0.80, "power_margin": 1.32,
		"lane_patience": 2.2, "spacing": 1.00, "fetch_caution": 5.0,
		"sabotage": 0.85,
		"intercept": 1.00, "camp": 1.00, "lunge_range": 3.1, "lunge_cone": 28.0,
		"dodge": 1.00, "sprint_reserve": 0.45, "mistake": 0.02,
	},
}

static var difficulty: Difficulty = Difficulty.NORMAL
## The active tier's row, copied out once by `apply_difficulty()`.
static var tuning: Dictionary = DIFFICULTY_TIERS[Difficulty.NORMAL]
## Bumped on every `apply_difficulty()`. Each controller compares its own copy
## against this and re-reads when they differ, so a difficulty changed from the
## pause menu mid-match reaches bots that were spawned before the change without
## anything having to find and notify them.
static var tuning_stamp: int = 0

## Prints one line per plan change, per bot. Off in play; `tools/ai_probe.gd`
## turns it on. ⚠️ Kept from the predecessor's API on purpose — this is the only
## way to answer "why is that bot standing there" without a debugger.
static var trace_enabled: bool = false

## Read by `settings_manager.gd` off the saved difficulty index, and by
## `tools/ai_probe.gd` off `tier=`.
static func apply_difficulty(tier: Difficulty) -> void:
	difficulty = tier
	tuning = DIFFICULTY_TIERS[tier]
	tuning_stamp += 1

## ---------------------------------------------------------------------------
## § GEOMETRY AND CADENCE — the numbers that are the same at every tier.
## ---------------------------------------------------------------------------

## How close the bot gets to a thing before it acts on it. Under
## `Carrier.PICKUP_RADIUS` (1.4) with a real margin, because the pickup is tested
## on the frame the press lands and both bodies are still moving.
const REACH: float = 1.15
## How far outside the box an attacker stands to throw. A metre of margin past
## the line, so a bot that drifts does not lose its own throw to the gate.
const THROW_STANDOFF: float = 1.2
## How far from the lata the taya posts while nothing is happening.
const GUARD_RADIUS: float = 2.2
## Arrival slop. A bot inside this of its goal stops; it does not resume until it
## is `ARRIVE_HYSTERESIS` times further out. ⚠️ WITHOUT THE HYSTERESIS A BOT
## SITTING EXACTLY ON THE BOUNDARY TOGGLES EVERY FRAME, which reads as a shiver
## and, worse, re-aims the body every frame it moves.
const ARRIVE_SLOP: float = 0.55
const ARRIVE_HYSTERESIS: float = 1.8
## A goal that jumps further than this is a different goal, so arrival resets.
const GOAL_MOVED: float = 0.9

## Bodies inside this radius push the bot's heading away from them. This is what
## stops three attackers converging into one pile — and it is steering, not
## collision: `_shed_character_perch()` handles bodies that are already stacked.
const SEPARATION_RADIUS: float = 1.45
const SEPARATION_WEIGHT: float = 0.65

## sin(22.5°). A heading is quantised to the nearest of the eight a keyboard can
## express by pressing each axis whose component clears this — see `_drive()`.
const EIGHT_WAY_THRESHOLD: float = 0.3827

## Above this distance a bot considers sprinting at all. Short legs are walked,
## so nobody spends the round fatigued and is then caught standing still — which
## is what "the AI just gives up" looks like from outside.
const SPRINT_DISTANCE: float = 5.0

## Height above the lata's origin the throw is aimed at. `slipper.gd` accepts a
## hit within `HIT_RADIUS + 0.30` flat and 1.0 vertically, so this only has to be
## inside the band; it is a fifth of a metre so the arc is still descending
## through the can rather than skimming its lip.
const AIM_HEIGHT: float = 0.20
## `aim_error` is quoted at this range and scaled from it (§ AIM).
const AIM_REFERENCE_RANGE: float = 7.5
## How far the scatter may be scaled by range, either way.
const AIM_RANGE_SCALE_MIN: float = 0.65
const AIM_RANGE_SCALE_MAX: float = 1.70
## The most a fully-settled wind-up may shrink its own scatter by.
##
## ⚠️ IT WAS 0.34 AND THAT MADE `aim_error` ALMOST DECORATIVE. The lata's hit
## window is 0.53 m wide; NORMAL's 0.45 m of scatter cut to a third is 0.15 m,
## i.e. inside the can every time. Measured on the first real run: **64.7%** of
## every throw put the lata over, which is not a difficulty tier, it is a
## turret. The settle is a real effect and worth keeping — a held shot IS a
## better shot — but it may not be the whole aim model.
const AIM_SETTLE_FLOOR: float = 0.55

## A wind-up may never last longer than this. ⚠️⚠️ THE HARD CAP IS THE WHOLE
## LESSON OF THE OLD FILE. Its release condition was "the power stopped rising",
## which is a statement about a value it did not own — and when `carrier.gd`'s
## charge behaved differently than assumed, the bot held a wind-up for the entire
## round. **A bot's commitment is bounded in SECONDS, by its own clock, or it is
## not bounded at all.**
const WINDUP_TIMEOUT: float = 3.6

## Lane sampling. `_lane_blocked()` walks the real launch velocity forward in
## steps short enough that a body cannot fall between two of them: the step is
## sized off the speed so that no sample is further apart than half a blocking
## radius.
const LANE_SAMPLE_ARC: float = 0.45
const LANE_STEP_MIN: float = 0.012
const LANE_STEP_MAX: float = 0.050
const LANE_MAX_STEPS: int = 96

## ⚠️ THE BOT LUNGES FROM FURTHER OUT THAN IT CAN TAG, and that gap is the point.
## `LUNGE_TAG_RADIUS` is 1.3 m but the dash exists to COVER 2.5 m; firing only
## once already inside tag range makes it a worse version of walking. The exact
## range is the tier's `lunge_range`.
const LUNGE_HOLD_TIME: float = 0.5

## ⚠️⚠️ `lunge_cone` HAS A HARD FLOOR AND IT IS SET BY THE KEYBOARD, NOT BY TASTE.
## The body faces exactly one of eight headings (`_drive()`), so the angle between
## where a bot is FACING and where its target actually is can be up to **22.5°**
## through no error of its own. A cone tighter than that is a taya that refuses to
## release a charged lunge on the bearings where it happens to be worst — the
## tier would read as "never tags" rather than as "precise". HARD sits at 28°,
## which is the tightest value that still clears the quantisation with margin.
const LUNGE_CONE_FLOOR: float = 26.0

## How far ahead the taya predicts a slipper already in the air, and how finely.
const INTERCEPT_HORIZON: float = 1.4
const INTERCEPT_STEP: float = 0.04
## A body blocks a slipper passing within half its capsule height. Interception
## aims at the part of the arc inside that band and nothing else — running to a
## point the slipper passes two metres above is running nowhere.
const INTERCEPT_BAND: float = 0.45

## Seconds a bot will wait for a safe retrieval before going anyway, before the
## tier's own `fetch_caution` is added on top. See `_fetch_is_safe()`.
const STALK_PATIENCE_BASE: float = 3.5

## ---------------------------------------------------------------------------
## § UNSTICKING. A general safety net rather than a fix for one plan.
##
## ⚠️ A BOT CAN PRESS A DIRECTION AND GO NOWHERE, AND NOTHING ELSE IN THIS FILE
## WOULD EVER NOTICE. `move_and_slide()` writes the RESOLVED velocity back, so a
## unit walking into a prop, a kerb or another body reports ~0 speed while its
## plan is perfectly happy: the goal has not been reached, so it keeps walking at
## it, for as long as the obstacle is there. The probe caught 64 s of exactly
## this on one seat.
##
## Rather than teach every plan about geometry — this file has no navmesh and
## should not grow one — a bot that is trying to move and is not moving steps
## sideways for a moment, which is what a person does when they snag on scenery.
const STUCK_SPEED: float = 0.30
const STUCK_TRIGGER: float = 1.1
const UNSTICK_TIME: float = 0.65

## How long a written intent stays readable on the shared board (§ SPACING).
const CLAIM_TTL: float = 1.2

## Idle repositioning: a bot with nothing to do drifts along the ring rather than
## standing at attention. Small, slow, and it is most of "these look alive".
const LOITER_SPEED: float = 0.55
const LOITER_PERIOD: float = 5.5

## ---------------------------------------------------------------------------
## § PERSONALITY — why three identical bots are not one bot drawn three times.
##
## 🧑 2026-08-01: *"they all move at the same time"*. Three controllers running
## one table on one clock produce three bodies doing the same thing on the same
## frame, and no amount of tuning inside a shared plan fixes that: the fix has to
## be that the three bots are not the same bot.
##
## Each seat gets a stable, repeatable personality: its knobs are jittered, its
## think clock starts on a random phase, and it carries a preferred bearing round
## the box so its default post is its own rather than everyone's.
##
## ⚠️ SEEDED FROM THE SEAT, NOT FROM THE CLOCK. Two runs of the same match give
## the same four characters, which is what makes a fairness number reproducible
## and a bug re-findable. The variation is between BOTS, not between RUNS.
## ---------------------------------------------------------------------------
class _Personality:
	## 0.85..1.2 on the think interval — some players deliberate, some snap.
	var tempo: float = 1.0
	## 0.8..1.25 on aim scatter and 0.85..1.15 on reaction. Nobody is exactly the
	## tier.
	var hands: float = 1.0
	var nerves: float = 1.0
	## 0.75..1.3 on how far it will push its luck fetching and shoving.
	var nerve_for_the_box: float = 1.0
	## Radians. Its favourite corner of the ring to work from.
	var home_bearing: float = 0.0
	## Seconds of pause before committing to a NEW plan. Humans do not switch
	## instantly and a bot that does reads as a machine even when it is right.
	var hesitation: float = 0.15

	func _init(seed_value: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("tumbang-preso-bot-%d" % seed_value)
		tempo = rng.randf_range(0.85, 1.20)
		hands = rng.randf_range(0.80, 1.25)
		nerves = rng.randf_range(0.85, 1.15)
		nerve_for_the_box = rng.randf_range(0.75, 1.30)
		home_bearing = rng.randf_range(-PI, PI)
		hesitation = rng.randf_range(0.05, 0.28)

## ---------------------------------------------------------------------------
## § THE SHARED BOARD. Attackers are rivals, not team-mates, so nothing here is
## coordination: it is one bot reading what the others have already committed to,
## exactly as a human reads the court. Writing your bearing down and reading
## everyone else's is what makes "attack from where the taya is not" computable
## without any of them agreeing to anything.
##
## ⚠️ STATIC, AND THAT IS SAFE FOR THE SAME REASON THE RANDOMNESS IS: every
## controller in existence lives in one process, on the host.
## ---------------------------------------------------------------------------
static var _claims: Dictionary = {}

## Flight tracking, shared and refreshed once per physics frame by whichever
## controller happens to run first. ⚠️ THE VELOCITY IS DIFFERENCED, NOT READ OFF
## THE SLIPPER. `Slipper._velocity` is `build fair`'s state and reaching into it
## would make this file depend on another lane's private field; differencing two
## observed positions is also, exactly, what a player watching it can know.
static var _flights: Dictionary = {}
static var _flights_frame: int = -1

## ⚠️ PUBLIC AND NAMED `character`, because `main.gd::_attach_ai` constructs this
## with a bare `.new()` and assigns afterwards. Resolved from the parent in
## `_ready()` as well, so either order works.
var character: CharacterBase = null

var _enabled: bool = true
var _booted: bool = false
var _me: _Personality = null

## Live knobs — the tier's row with this bot's personality folded in, rebuilt
## whenever `tuning_stamp` moves.
var _stamp: int = -1
var _react: float = 0.30
var _think: float = 0.24
var _lead: float = 0.45
var _aim_error: float = 0.45
var _aim_settle: float = 1.20
var _power_margin: float = 1.18
var _lane_patience: float = 1.1
var _spacing: float = 0.60
var _fetch_caution: float = 3.2
var _sabotage: float = 0.35
var _intercept: float = 0.60
var _camp: float = 0.45
var _lunge_range: float = 2.6
var _lunge_cone: float = 34.0
var _dodge: float = 0.55
var _sprint_reserve: float = 0.25
var _mistake: float = 0.10

var _think_left: float = 0.0
var _commit_left: float = 0.0

## Lagged picture of the world, one entry per seat. See `_observe()`.
var _seen_pos: Dictionary = {}
var _seen_vel: Dictionary = {}
## key -> seconds this condition has been continuously true. `_reacted()`.
var _gates: Dictionary = {}
## Mirror of what was pressed last frame, so `_tap()` can produce a real edge.
var _pressed: Dictionary = {}

## THE PLAN. One value, chosen on a think tick, acted on every frame.
enum Plan {
	IDLE,       ## nothing to do — loiter, do not stand at attention
	FETCH,      ## go and pick MY slipper up
	STALK,      ## my slipper is in the box and the taya is on it: wait for an opening
	WITHDRAW,   ## armed and inside the box, which is the one taggable state
	POSITION,   ## walk to a throwing spot with an angle
	WINDUP,     ## planted, aiming, charging
	EVADE,      ## a lunge is winding up at me
	SABOTAGE,   ## shove a rival who is about to be tagged
	RESET,      ## taya: stand the lata back up
	INTERCEPT,  ## taya: step into a slipper already in the air
	HUNT,       ## taya: chase and lunge a vulnerable attacker
	COVER,      ## taya: sit on a loose slipper's retrieval line
	GUARD,      ## taya: post between the lata and the live threat
}
var _plan: Plan = Plan.IDLE
var _goal: Vector3 = Vector3.ZERO
var _goal_valid: bool = false
var _arrived: bool = false

## Wind-up state. `_windup_time` is a clock this file owns, which is the whole
## difference between this and the release condition that broke.
var _windup: bool = false
var _windup_time: float = 0.0
var _windup_power: float = 1.0
var _windup_scatter: Vector3 = Vector3.ZERO
var _windup_wait: float = 0.0
var _blundering: bool = false

var _lunge_held: float = -1.0
## Who this bot guarded on the previous evaluation — see `_live_threat()`.
var _last_threat: CharacterBase = null
var _loiter_phase: float = 0.0
var _stalk_time: float = 0.0
var _stuck_time: float = 0.0
var _unstick_left: float = 0.0
var _unstick_sign: float = 1.0
var _driving: bool = false
var _last_trace: String = ""

func _ready() -> void:
	if character == null:
		character = get_parent() as CharacterBase

## Debug-switcher hand-off: a human taking manual control of an AI-driven unit
## must not fight the AI for the same buttons. Disabling releases everything this
## controller might be mid-press on, so nothing sticks "held" once a human is
## driving instead.
func set_enabled(enabled: bool) -> void:
	if _enabled == enabled:
		return
	_enabled = enabled
	if not enabled and character != null:
		_release_all()
		# Wipe the intent too, or `CharacterBase` keeps answering `input_pressed()`
		# from a stale dictionary while a human is trying to drive — the unit would
		# walk into a wall on its own.
		character.ai_clear_intent()

## `CharacterBase` asks this before deciding whether to read intent or hardware.
func is_enabled() -> bool:
	return _enabled

## ---------------------------------------------------------------------------
## THE FRAME. Called from `CharacterBase._physics_process` before it reads input.
##
## Three layers, in this order and for this reason:
##   1. OBSERVE, every frame — the picture the bot decides from is a lagged copy
##      of the world, never the world.
##   2. PLAN, on a think tick — one enum, chosen from that picture.
##   3. ACT, every frame — the plan turned into presses. Acting every frame is
##      what makes movement smooth on a plan that only changes four times a
##      second; planning every frame is what made the predecessor twitch.
## ---------------------------------------------------------------------------
func decide(delta: float) -> void:
	if not _enabled or character == null or not is_instance_valid(character):
		return
	if not _booted:
		_boot()
	if _stamp != tuning_stamp:
		_read_tuning()
	if not RoundManager.round_active or not character.can_act():
		_release_all()
		_plan = Plan.IDLE
		_windup = false
		return
	_observe(delta)
	_loiter_phase += delta
	_stalk_time = _stalk_time + delta if _plan == Plan.STALK else 0.0
	_step_unstick(delta)
	_think_left -= delta
	_commit_left = maxf(0.0, _commit_left - delta)
	if _think_left <= 0.0 and _commit_left <= 0.0:
		_think_left = _think
		_replan(delta)
	_act(delta)

## Trying to move and not moving. See § UNSTICKING.
func _step_unstick(delta: float) -> void:
	if _unstick_left > 0.0:
		_unstick_left = maxf(0.0, _unstick_left - delta)
		return
	var speed := Vector2(character.velocity.x, character.velocity.z).length()
	if _driving and speed < STUCK_SPEED:
		_stuck_time += delta
		if _stuck_time >= STUCK_TRIGGER:
			_stuck_time = 0.0
			_unstick_left = UNSTICK_TIME
			# Alternate, so a bot that picks the wrong way out of a corner does not
			# keep picking it.
			_unstick_sign = -_unstick_sign
			_trace("UNSTICK")
	else:
		_stuck_time = 0.0
	_driving = false

func _boot() -> void:
	_booted = true
	_me = _Personality.new(character.player_slot)
	_read_tuning()
	# ⚠️ THE THINK CLOCK STARTS ON A RANDOM PHASE. Four controllers created in one
	# `for` loop otherwise tick on the same frame for the whole match, and three
	# bots re-planning on the same frame is three bots changing direction on the
	# same frame — the "they all move at the same time" report, in one line.
	_think_left = randf() * _think
	_loiter_phase = randf() * LOITER_PERIOD

func _read_tuning() -> void:
	_stamp = tuning_stamp
	var t: Dictionary = tuning
	var p := _me if _me != null else _Personality.new(0)
	_react = float(t["react"]) * p.nerves
	_think = float(t["think"]) * p.tempo
	_lead = float(t["lead"])
	_aim_error = float(t["aim_error"]) * p.hands
	_aim_settle = float(t["aim_settle"])
	_power_margin = float(t["power_margin"])
	_lane_patience = float(t["lane_patience"])
	_spacing = float(t["spacing"])
	_fetch_caution = float(t["fetch_caution"]) / p.nerve_for_the_box
	_sabotage = float(t["sabotage"]) * p.nerve_for_the_box
	_intercept = float(t["intercept"])
	_camp = float(t["camp"])
	_lunge_range = float(t["lunge_range"])
	_lunge_cone = maxf(float(t["lunge_cone"]), LUNGE_CONE_FLOOR)
	_dodge = float(t["dodge"])
	_sprint_reserve = float(t["sprint_reserve"])
	_mistake = float(t["mistake"])

## ---------------------------------------------------------------------------
## § PERCEPTION. What the bot is allowed to know, and how late.
##
## ⚠️ THE LAG IS A FILTER, NOT A BUFFER, and that is a deliberate simplification
## worth stating: a ring buffer replaying the world N frames late is more
## faithful and needs a snapshot per frame per bot; a first-order lag with time
## constant `react` costs one lerp per seat and produces the behaviour the
## faithful version exists for — the bot arrives where you WERE, and the slower
## the tier the further behind it arrives. That is exactly what "reads your
## bearing" and "leads almost perfectly" describe.
## ---------------------------------------------------------------------------
func _observe(delta: float) -> void:
	var alpha := 1.0 - exp(-delta / maxf(_react, 0.02))
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		var slot := who.player_slot
		var truth := who.global_position
		var flat_velocity := Vector3(who.velocity.x, 0.0, who.velocity.z)
		if not _seen_pos.has(slot):
			_seen_pos[slot] = truth
			_seen_vel[slot] = flat_velocity
			continue
		# ⚠️ THE BOT'S OWN BODY IS NEVER LAGGED. Proprioception is not perception:
		# a player always knows exactly where their own feet are, and a bot that
		# steers off a lagged copy of ITSELF oscillates around every goal.
		if who == character:
			_seen_pos[slot] = truth
			_seen_vel[slot] = flat_velocity
			continue
		_seen_pos[slot] = (_seen_pos[slot] as Vector3).lerp(truth, alpha)
		_seen_vel[slot] = (_seen_vel[slot] as Vector3).lerp(flat_velocity, alpha)
	_track_flights()

## One shared pass per physics frame over every slipper in the air, differencing
## position into velocity so the taya has something to intercept.
func _track_flights() -> void:
	var frame := Engine.get_physics_frames()
	if _flights_frame == frame:
		return
	_flights_frame = frame
	var seen: Dictionary = {}
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null or not slipper.is_flying():
			continue
		var id := slipper.get_instance_id()
		seen[id] = true
		var here := slipper.global_position
		var record: Dictionary = _flights.get(id, {})
		var last_frame := int(record.get("frame", -99))
		var velocity := Vector3.ZERO
		if frame - last_frame == 1:
			var step := 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)
			velocity = (here - (record["pos"] as Vector3)) / step
		_flights[id] = {"pos": here, "vel": velocity, "frame": frame, "node": slipper}
	for id in _flights.keys():
		if not seen.has(id):
			_flights.erase(id)

## Where this bot believes `who` is.
func _at(who: CharacterBase) -> Vector3:
	if who == null:
		return Vector3.ZERO
	return _seen_pos.get(who.player_slot, who.global_position)

## Where this bot believes `who` will be in `horizon` seconds, at its tier's
## willingness to extrapolate. `lead` 0 is a bot that runs at your shadow.
func _ahead_of(who: CharacterBase, horizon: float) -> Vector3:
	if who == null:
		return Vector3.ZERO
	var base := _at(who)
	var velocity: Vector3 = _seen_vel.get(who.player_slot, Vector3.ZERO)
	return base + velocity * horizon * _lead

## A reactive trigger: true only once `condition` has been continuously true for
## the tier's reaction time. ⚠️ THE RESET IS THE IMPORTANT HALF — a condition
## that flickers never fires, which is why a bot cannot dodge a lunge that was
## cancelled and why a taya does not sprint at a slipper that clipped a wall.
func _reacted(key: String, condition: bool, delta: float) -> bool:
	if not condition:
		_gates[key] = 0.0
		return false
	var held := float(_gates.get(key, 0.0)) + delta
	_gates[key] = held
	return held >= _react

## ---------------------------------------------------------------------------
## § PLANNING.
## ---------------------------------------------------------------------------
func _replan(delta: float) -> void:
	var chosen := _plan_defender(delta) if character.is_defender else _plan_attacker(delta)
	if chosen == _plan:
		return
	# ⚠️ A NEW PLAN COSTS A BEAT. Without this a bot flips plan on the frame the
	# world changes, which is faster than a human can move a hand and is the
	# single most machine-like thing a bot does. `hesitation` is per-bot, so the
	# three of them do not even hesitate together.
	_commit_left = _me.hesitation
	_plan = chosen
	_arrived = false
	# A new plan gets a new goal. Carrying the last one over is how a bot ends up
	# walking to a throwing spot it chose two verbs ago.
	if chosen != Plan.POSITION:
		_goal_valid = false
	if chosen != Plan.WINDUP:
		_windup = false
	_trace(_plan_name(chosen))

## ---------------------------------------------------------------------------
## THE ATTACKER: retrieve → get an angle → throw. And stay alive in between.
## ---------------------------------------------------------------------------
func _plan_attacker(delta: float) -> Plan:
	var lata := RoundManager.lata
	var taya := RoundManager.defender()

	# Nothing outranks not being tagged. The wind-up is broadcast to every peer
	# (`observed_lunge_charge()`) precisely so it can be answered, and the bot is
	# only allowed to answer it after its own reaction time.
	if _should_evade(taya, delta):
		return Plan.EVADE

	# ⚠️ CHECKED IN BOTH HANDS-FULL AND HANDS-EMPTY BRANCHES. The shove is a tap of
	# `grab`, and `carrier.gd` gives the PICKUP first refusal — but `_find_grabbable()`
	# only ever returns THIS bot's own slipper within 1.4 m, so an empty-handed
	# attacker anywhere else is free to spend the press on a rival. Leaving this out
	# of the empty-handed branch is what made the whole verb unreachable for most of
	# a round.
	if _sabotage_target(taya) != null:
		return Plan.SABOTAGE
	if not character.holding_slipper():
		var mine := _my_slipper()
		if mine == null:
			return Plan.IDLE
		if mine.is_flying():
			# ⚠️ WALK TO WHERE IT WILL LAND, not to where it is. This is most of the
			# missing ground in §6.7: after a throw the old bot had no slipper, no
			# target and nothing to do, and simply stood at its spawn until the
			# slipper resolved.
			return Plan.POSITION
		if _fetch_is_safe(mine, taya):
			return Plan.FETCH
		return Plan.STALK

	# Armed. Inside the box is the one state that can be tagged (`is_taggable()`),
	# so it is worth nothing else until it is over.
	if character.is_inside_box():
		return Plan.WITHDRAW
	if lata == null or not lata.is_upright or not RoundManager.can_throw(character):
		# The lata is down or the restore cooldown is live: there is no throw to
		# make. A shove that sets up somebody else's tag is worth +50 and is the
		# only scoring verb available in this window.
		if _sabotage_target(taya) != null:
			return Plan.SABOTAGE
		return Plan.POSITION
	if _sabotage_target(taya) != null:
		return Plan.SABOTAGE
	if _throw_locked():
		return Plan.POSITION
	if _arrived and _plan in [Plan.POSITION, Plan.WINDUP]:
		return Plan.WINDUP
	if _plan == Plan.WINDUP:
		return Plan.WINDUP
	return Plan.POSITION

## ⚠️ `THROW_LOCK_TIME` IS 1.25 s AFTER EVERY PICKUP AND IT IS INVISIBLE FROM
## HERE UNLESS IT IS ASKED FOR. `carrier.gd::_step_throw()` simply *returns*
## while the lock is live — it does not cancel, it does not report, and
## `charge_power()` stays flat at 0. A bot that plants and holds through it burns
## a whole wind-up timeout charging nothing and then "throws" a slipper that never
## left. Walking to the spot is what that second and a quarter is for.
func _throw_locked() -> bool:
	var carrier := character.get_node_or_null("Carrier") as Carrier
	return carrier != null and carrier.throw_lock_left() > 0.0

## ---------------------------------------------------------------------------
## THE DEFENDER: stand it up → block what is already in the air → tag → post.
##
## ⚠️ THE ORDER IS THE WHOLE STRATEGY AND IT IS NOT THE OBVIOUS ONE. Standing the
## lata up outranks a tag because while it is down NOBODY IS TAGGABLE — the
## lunge sweep refuses outright (`_sweep_lunge_tag`: *"a tag requires the lata
## standing"*) — and the +10/s is stopped. Intercepting outranks chasing because
## a slipper already in the air is a 100-point event with a deadline, and a
## retrieval run is not.
## ---------------------------------------------------------------------------
func _plan_defender(delta: float) -> Plan:
	var lata := RoundManager.lata
	if lata == null:
		return Plan.IDLE
	if not lata.is_upright:
		return Plan.RESET
	if _intercept > 0.0 and _intercept_point(lata) != Vector3.INF:
		if _reacted("incoming", true, delta):
			return Plan.INTERCEPT
	else:
		_gates["incoming"] = 0.0
	if _tag_target() != null:
		return Plan.HUNT
	if _camp > 0.0 and _cover_point(lata) != Vector3.INF:
		return Plan.COVER
	return Plan.GUARD

## ---------------------------------------------------------------------------
## § ACTING.
## ---------------------------------------------------------------------------
func _act(delta: float) -> void:
	match _plan:
		Plan.IDLE:
			_do_idle()
		Plan.FETCH:
			_do_fetch()
		Plan.STALK:
			_do_stalk()
		Plan.WITHDRAW:
			_do_withdraw()
		Plan.POSITION:
			_do_position()
		Plan.WINDUP:
			_do_windup(delta)
		Plan.EVADE:
			_do_evade()
		Plan.SABOTAGE:
			_do_sabotage()
		Plan.RESET:
			_do_reset()
		Plan.INTERCEPT:
			_do_intercept()
		Plan.HUNT:
			_do_hunt(delta)
		Plan.COVER:
			_do_cover()
		Plan.GUARD:
			_do_guard()
	# Buttons this plan did not touch are released explicitly. ⚠️ AN INTENT
	# DICTIONARY IS STICKY: it holds whatever was last written, so a plan that
	# simply stops mentioning `special_ability` leaves the previous plan's charge
	# held for the rest of the round.
	if _plan != Plan.WINDUP:
		_press("special_ability", false)
		_windup = false
	if _plan != Plan.HUNT:
		_lunge_held = -1.0
		_press("lunge", false)
	if not (_plan in [Plan.FETCH, Plan.RESET, Plan.SABOTAGE]):
		_press("grab", false)

## --- attacker verbs ------------------------------------------------------

func _do_fetch() -> void:
	var mine := _my_slipper()
	if mine == null:
		_stop()
		return
	var where := mine.global_position
	var distance := _flat(character.global_position, where)
	# Sprint the last stretch INTO the box and nothing else: the retrieval is the
	# only moment an attacker is taggable, and 50 stamina points is 1.25 s of
	# sprint. Spending it anywhere else is spending it where it does not matter.
	var hurry := distance > REACH and (_mine_is_exposed(mine) or distance > SPRINT_DISTANCE)
	_goto(where, REACH * 0.75, hurry)
	# ⚠️ THE PICKUP IS A TAP AND `grab` HELD WOULD DO NOTHING AT ALL. `_step_grab`
	# reads `input_just_pressed`; a held button produces exactly one edge and then
	# a bot that stands on its own slipper for ever. `_tap()` alternates so an
	# edge lands every other frame for as long as it is in range.
	if distance <= REACH:
		_tap("grab")
	else:
		_press("grab", false)

## True while the slipper is somewhere the taya can contest — used only to decide
## whether this is a sprint or a walk.
func _mine_is_exposed(mine: Slipper) -> bool:
	var taya := RoundManager.defender()
	if taya == null:
		return false
	return _flat(_at(taya), mine.global_position) < 4.5

func _do_stalk() -> void:
	# My slipper is in the box and the taya is sitting on it. Standing on the line
	# outside, at my own bearing, is both the safest place to be and the place the
	# run starts from — and it keeps the bot MOVING, which is what a person waiting
	# for an opening actually looks like.
	var mine := _my_slipper()
	var anchor: Vector3 = mine.global_position if mine != null else Vector3.ZERO
	var bearing := atan2(anchor.x, anchor.z)
	_goto(_ring_point(bearing, CharacterBase.confinement_radius + 0.6), ARRIVE_SLOP, false)
	if _arrived:
		_loiter()

func _do_withdraw() -> void:
	# Straight out along the bearing we are already on — a step back, not a lap of
	# the arena — and sprinting, because this is the taggable window.
	_goto(_safe_spot(), ARRIVE_SLOP, true)

func _do_position() -> void:
	if not character.holding_slipper():
		# Waiting for my own throw to resolve: walk to where it will come down, so
		# the retrieval starts from the right side of the court.
		var mine := _my_slipper()
		if mine != null and mine.is_flying():
			var landing := _predicted_landing(mine)
			if landing != Vector3.INF:
				_goto(_pull_outside(landing, 0.4), ARRIVE_SLOP, false)
				return
		_loiter()
		return
	if not _goal_valid:
		_goal = _throw_spot()
		_goal_valid = true
	_goto(_goal, ARRIVE_SLOP, _flat(character.global_position, _goal) > SPRINT_DISTANCE)
	_claim(atan2(_goal.x, _goal.z))
	# ⚠️⚠️ ARRIVING IS NOT A REASON TO STOP EXISTING, AND THIS COST A MEASUREMENT.
	# The first run of the new probe caught two bots standing still for 22 s and
	# 57 s inside live rounds. Both were HERE: armed, in position, and refused the
	# throw because the lata was lying down —  needs it upright — so
	# they walked to their spot, arrived, and  politely stopped them for
	# as long as the taya took to stand it back up. Measured over the same run,
	# the lata was down for about **70 of 180 live seconds**, which is 70 seconds
	# of three statues. A plan that can WAIT needs somewhere to put the waiting.
	if _arrived:
		_loiter()

## ⚠️⚠️ THE ONE FUNCTION THE OLD FILE GOT WRONG IN A WAY NOTHING COULD SEE.
## See the header: power is a SPEED scale, the old release fired at ≈ 0.36 of it,
## and 0.36 cannot reach 6.5 m. Nothing else about the aim mattered.
##
## What happens here instead:
##   · the required launch speed is SOLVED, not guessed;
##   · the charge is held to a real margin over it, on a clock this file owns;
##   · the shot is not taken through somebody's chest — `_lane_blocked()` walks
##     the actual arc `slipper.gd` will fly and asks the same question
##     `_first_body_hit()` will ask;
##   · and there is a hard timeout, so a wind-up cannot outlive the round.
func _do_windup(delta: float) -> void:
	var lata := RoundManager.lata
	if lata == null or not character.holding_slipper() \
			or not RoundManager.can_throw(character):
		# The gate closed under us — somebody else knocked the lata down, or the
		# restore cooldown started. `carrier.gd` has already cancelled the charge,
		# so holding the button here would just wait out the timeout for nothing.
		_windup = false
		_press("special_ability", false)
		_plan = Plan.POSITION
		_goal_valid = false
		return
	if not _windup:
		_windup = true
		_windup_time = 0.0
		_windup_wait = 0.0
		_blundering = _blunder()
		_windup_scatter = _roll_scatter()
		_windup_power = _plan_power(lata)
	_windup_time += delta
	_stop()

	var aim := lata.global_position + Vector3.UP * AIM_HEIGHT
	# ⚠️ THE SCATTER SHRINKS AS THE SHOT IS HELD, and that is what `aim_settle`
	# buys. A bot whose error is constant reads as a dice roll; one whose error
	# closes over the wind-up reads as somebody lining a shot up — and it makes
	# the 2.5 s charge time mean something to the AI as well as to a human.
	var settle := 1.0
	if _aim_settle < 90.0:
		settle = lerpf(1.0, AIM_SETTLE_FLOOR, clampf(_windup_time / maxf(_aim_settle, 0.05), 0.0, 1.0))
	character.ai_aim_point = aim + _windup_scatter * settle

	var carrier := character.get_node_or_null("Carrier") as Carrier
	var power: float = carrier.charge_power() if carrier != null else 0.0
	_press("special_ability", true)

	if _windup_time >= WINDUP_TIMEOUT:
		# Out of patience. Throw what we have — it may fall short, and a bot that
		# lets go is still a bot playing the game. This branch existing at all is
		# the fix for the failure the predecessor's release condition WAS.
		_release_throw()
		return
	if power < _windup_power:
		return
	# Charged. Now the only question left is whether the lane is open.
	var origin := Carrier.throw_origin_for(character, character.ai_aim_point)
	if not _blundering and _lane_blocked(origin, character.ai_aim_point, power):
		_windup_wait += delta
		if _windup_wait < _lane_patience:
			return
		# Waited long enough and it is still blocked: give up the angle rather
		# than the round. Dropping the plan sends this bot to a new spot on the
		# ring, which is exactly what a player does when somebody stands in front
		# of them.
		_windup = false
		_goal_valid = false
		_plan = Plan.POSITION
		_press("special_ability", false)
		_trace("POSITION (lane shut)")
		return
	_release_throw()

func _release_throw() -> void:
	_press("special_ability", false) # release IS the throw
	_windup = false
	_goal_valid = false
	_commit_left = 0.0
	_plan = Plan.IDLE

func _do_evade() -> void:
	var taya := RoundManager.defender()
	if taya == null:
		_do_withdraw()
		return
	# Break perpendicular to the lunge, not away from it. A 2.5 m dash along
	# `-basis.z` beats a 3.45 m/s attacker running in a straight line down the
	# same axis; stepping across it is the only answer the geometry allows.
	var toward := character.global_position - _at(taya)
	toward.y = 0.0
	if toward.length() < 0.05:
		toward = Vector3.FORWARD
	var across := Vector3(-toward.z, 0.0, toward.x).normalized()
	if across.dot(_out_of_box_dir()) < 0.0:
		across = -across
	var escape := (across * 0.75 + _out_of_box_dir() * 0.75).normalized()
	_drive(escape, true)
	_press("grab", false)

func _do_sabotage() -> void:
	var victim := _sabotage_target(RoundManager.defender())
	if victim == null:
		_stop()
		return
	# ⚠️ IT DRIVES ALL THE WAY IN AND NEVER PARKS, for the identical reason
	# `_do_hunt()` does: the body only turns on a frame it walks, and
	# `host_resolve_shove()` tests a 70° arc off `-basis.z`. Arriving and stopping
	# freezes the facing at whatever the approach happened to end on, and the shove
	# then fires into the wrong quadrant or never passes its own cone test.
	var distance := _flat(character.global_position, victim.global_position)
	var toward := victim.global_position - character.global_position
	toward.y = 0.0
	_drive(toward, distance > 3.0)
	if distance <= CharacterBase.SHOVE_RANGE * 0.9 			and _facing(victim, CharacterBase.SHOVE_ARC_DEG * 0.6):
		_tap("grab")
	else:
		_press("grab", false)

func _do_idle() -> void:
	_loiter()

## --- defender verbs ------------------------------------------------------

func _do_reset() -> void:
	var lata := RoundManager.lata
	if lata == null:
		_stop()
		return
	var inside := lata.is_in_ring(character.global_position)
	if inside:
		_stop()
	else:
		_goto(lata.global_position, Lata.INTERACTION_RADIUS * 0.55, true)
	# ⚠️ HELD, NOT TAPPED, AND THIS IS THE ONE PLACE THAT IS TRUE. `carrier.gd`'s
	# reset channel reads `input_pressed` and zeroes itself the instant it goes
	# false, so an alternating tap would restart the 1.5 s channel every other
	# frame and never finish it.
	_press("grab", inside)

func _do_intercept() -> void:
	var lata := RoundManager.lata
	var point := _intercept_point(lata)
	if point == Vector3.INF:
		_do_guard()
		return
	_goto(point, 0.3, true)

func _do_hunt(delta: float) -> void:
	var victim := _tag_target()
	if victim == null:
		_do_guard()
		return
	# Close on where they are GOING. `_lead` is the tier's willingness to do that
	# and is 0 on the kid, which is why the kid chases a shadow.
	var aim_at := _ahead_of(victim, 0.35)
	var toward := aim_at - character.global_position
	toward.y = 0.0
	# ⚠️⚠️ IT NEVER STOPS CLOSING, AND THAT IS FORCED BY THE GAME RATHER THAN
	# CHOSEN. `character_base.gd` only calls `look_at()` on a frame the body
	# actually MOVES, so a bot that stands still keeps whatever facing it last
	# walked in — and the lunge fires along `-basis.z`. A taya that parks next to
	# its target therefore can never aim the dash at it.
	#
	# Measured, with an arrival stop here: **P1 stood still for 42.9 s of a 90 s
	# round**, adjacent to a vulnerable attacker, charging and firing lunges into
	# whatever direction it had last walked in. The one thing that would have
	# turned it to face them was the walking it had just stopped doing. Driving
	# into them is also what a human taya does, and body contact is a real part
	# of the box.
	_drive(toward, _may_sprint() and toward.length() > 1.5)
	_step_lunge_intent(victim, delta)

func _do_cover() -> void:
	var point := _cover_point(RoundManager.lata)
	if point == Vector3.INF:
		_do_guard()
		return
	_goto(point, ARRIVE_SLOP, false)
	if _arrived:
		_loiter()

func _do_guard() -> void:
	var lata := RoundManager.lata
	if lata == null:
		_stop()
		return
	var threat := _live_threat()
	if threat == null:
		_goto(_clamp_to_box(lata.global_position), ARRIVE_SLOP, false)
		return
	# Stand between the lata and the threat, not on top of the lata: the body IS
	# the block, and a taya standing on its own can blocks nothing.
	var toward := _at(threat) - lata.global_position
	toward.y = 0.0
	if toward.length() < 0.05:
		_goto(_clamp_to_box(lata.global_position), ARRIVE_SLOP, false)
		return
	var post := lata.global_position + toward.normalized() * GUARD_RADIUS
	_goto(_clamp_to_box(post), ARRIVE_SLOP, _flat(character.global_position, post) > SPRINT_DISTANCE)
	# Same reason as : a taya whose threat is not moving has a post
	# that is not moving, and a bot that has reached a stationary post is a bot
	# that never moves again.
	if _arrived:
		_loiter()

## ⚠️ IT CHARGES BY HOLDING AND FIRES BY RELEASING — the same contract a human's
## right-click has. `CharacterBase._step_lunge()` starts on the press EDGE,
## accumulates while held, and fires on release; holding it for ever charges and
## never lunges.
##
## ⚠️ AND IT ONLY FIRES INSIDE A CONE, which the predecessor did not check. The
## dash goes along `-basis.z` and the body only turns while it WALKS, so a taya
## that releases while side-stepping dashes past the target at 12 m/s and puts
## its own tag on cooldown for 1.5 s. `lunge_cone` is the tier's tolerance.
func _step_lunge_intent(victim: CharacterBase, delta: float) -> void:
	# ⚠⚠ THE PUNCH COMES FIRST WHEN IT IS IN RANGE. New verb 2026-08-01: the taya
	# gained a no-charge close-range jab (`CharacterBase.PUNCH_*`) alongside the
	# lunge, and a bot that only knew the lunge would charge half a second at a
	# target standing next to it — which is exactly the case the punch was added for,
	# and exactly long enough for the attacker to leave.
	#
	# ⚠️ IT STILL HAS TO BE AIMED. Both verbs fire along `-basis.z` and the body only
	# turns on a frame it WALKS (§6 trap 13), so the same `_facing()` gate the lunge
	# uses applies here — a punch thrown at a target behind you is a wasted cooldown,
	# not a tag.
	#
	# ⚠️ AND IT IS A TAP, NOT A HOLD. `_step_punch()` reads `input_just_pressed`, so
	# it needs a false frame before the true one — `_tap()` alternates for exactly
	# that reason, the same way the grab does.
	if character.punch_cooldown_left() <= 0.0 and victim != null 			and _flat(character.global_position, victim.global_position) <= CharacterBase.PUNCH_RANGE 			and _facing(victim, CharacterBase.PUNCH_ARC_DEG):
		_tap("special_ability")
		return
	_press("special_ability", false)
	if character.lunge_cooldown_left() > 0.0:
		_lunge_held = -1.0
		_press("lunge", false)
		return
	var reach := _flat(character.global_position, _ahead_of(victim, LUNGE_HOLD_TIME))
	if _lunge_held < 0.0:
		# ⚠️ THERE IS NO LOWER BOUND, AND THE ONE THAT USED TO BE HERE WAS A
		# DEADLOCK. It refused to start the charge inside 0.9 m on the reasoning
		# that walking would tag them anyway — but the tag is not passive any more
		# (`Design.md` §6: it *"used to fire every physics frame on adjacency"* and
		# does not since 2026-08-01), so a taya standing 0.78 m from a vulnerable
		# attacker had no verb at all. `LUNGE_TAG_RADIUS` is 1.3 m and the sweep
		# runs every frame the dash is live, so a lunge released point-blank tags
		# on its first frame; overshooting afterwards costs nothing.
		if reach > _lunge_range:
			_press("lunge", false)
			return
		_lunge_held = 0.0
	_lunge_held += delta
	if _lunge_held >= LUNGE_HOLD_TIME and _facing(victim, _lunge_cone):
		_lunge_held = -1.0
		_press("lunge", false) # the release edge is what fires it
		return
	if _lunge_held >= LUNGE_HOLD_TIME + 0.45:
		# Fully charged and still not lined up. Let it go rather than hold a dash
		# for ever — the cooldown is 1.5 s and the attacker is leaving.
		_lunge_held = -1.0
		_press("lunge", false)
		return
	_press("lunge", true)

## ---------------------------------------------------------------------------
## § THE THROW SOLVE. Everything here is arithmetic on `slipper.gd`'s own model,
## deliberately, so the AI cannot be right about a flight the game then flies
## differently.
## ---------------------------------------------------------------------------

## The smallest `power` whose launch speed has ANY solution to `origin -> target`
## under `CharacterBase.GRAVITY`.
##
## `_solve_arc()`'s discriminant is `v⁴ - g(g·d² + 2·Δy·v²) >= 0`. Solving that
## for `u = v²` gives `u >= g·(Δy + sqrt(Δy² + d²))`, so
##
##     v_min = sqrt( g · ( Δy + sqrt(Δy² + d²) ) )
##
## and power inverts `speed = LAUNCH_SPEED · lerp(MIN_POWER_SCALE, 1, power)`.
## ⚠️ AT EXACTLY `v_min` THE SOLUTION IS THE 45°-ish grazing one: maximum range,
## maximum airtime, minimum speed — the easiest possible throw to body-block and
## the one most damaged by aim scatter. `power_margin` is what buys a flatter
## shot, and it is a tier knob for exactly that reason.
func _min_power_for(origin: Vector3, target: Vector3) -> float:
	var flat := Vector2(target.x - origin.x, target.z - origin.z).length()
	var rise := target.y - origin.y
	var speed := sqrt(maxf(CharacterBase.GRAVITY * (rise + sqrt(rise * rise + flat * flat)), 0.0))
	return _power_for_speed(speed)

func _power_for_speed(speed: float) -> float:
	var scale := speed / Slipper.LAUNCH_SPEED
	return clampf((scale - Slipper.MIN_POWER_SCALE) / (1.0 - Slipper.MIN_POWER_SCALE), 0.0, 1.0)

func _plan_power(lata: Lata) -> float:
	var aim := lata.global_position + Vector3.UP * AIM_HEIGHT
	var origin := Carrier.throw_origin_for(character, aim)
	var floor_power := _min_power_for(origin, aim)
	# The margin is applied in SPEED, not in power, because it is a statement
	# about the flight and power is only a dial onto it.
	var flat := Vector2(aim.x - origin.x, aim.z - origin.z).length()
	var rise := aim.y - origin.y
	var wanted := sqrt(maxf(CharacterBase.GRAVITY * (rise + sqrt(rise * rise + flat * flat)), 0.0))
	var margin := _power_margin
	if _blundering:
		# The kid's characteristic miss: a throw that only just gets there, which
		# floats, and which the taya can walk into. This is a readable mistake
		# rather than noise — the point of `mistake` is that a player can SEE the
		# bot make one.
		margin = 1.0
	return clampf(maxf(_power_for_speed(wanted * margin), floor_power + 0.02), 0.0, 1.0)

## Metres of scatter, rolled once per wind-up.
##
## ⚠️ ROLLED PER SHOT, NOT PER FRAME AND NOT PER THINK TICK. Re-rolling inside a
## charge averages to a perfect shot over the length of it, which is the opposite
## of what an aim error is for — the predecessor re-rolled every think tick and
## then aimed with whatever the last roll happened to be, so the error was real
## but uncorrelated with anything the player could read.
##
## ⚠️ AND IT SCALES WITH RANGE. A fixed metre of scatter is a wide miss at 7 m
## and an impossible one at 12 m; quoting it at a reference range and scaling
## keeps the tier's ANGULAR error constant, which is what a person's actually is.
func _roll_scatter() -> Vector3:
	var lata := RoundManager.lata
	var range_scale := 1.0
	if lata != null:
		var distance := _flat(character.global_position, lata.global_position)
		range_scale = clampf(distance / AIM_REFERENCE_RANGE,
			AIM_RANGE_SCALE_MIN, AIM_RANGE_SCALE_MAX)
	var spread := _aim_error * range_scale * (2.2 if _blundering else 1.0)
	var bearing := randf_range(-PI, PI)
	var reach := sqrt(randf()) * spread
	return Vector3(cos(bearing) * reach, 0.0, sin(bearing) * reach)

## Walks the arc `slipper.gd` will actually fly and asks the same question
## `Slipper._first_body_hit()` will ask of it, frame by frame.
##
## ⚠️ THE STEP IS SIZED OFF THE SPEED, not fixed. At 17 m/s a 0.04 s step is
## 0.68 m, against a blocking radius of about 0.63 — so a fixed step lets a body
## fall clean between two samples and the bot throws through somebody. The step
## is set so no two samples are further apart than `LANE_SAMPLE_ARC`.
##
## ⚠️ IT RETURNS TRUE FOR A THROW THAT NEVER ARRIVES, and that is not a shortcut:
## a shot that falls short is as useless as a blocked one and the bot should go
## and find a better angle either way.
func _lane_blocked(origin: Vector3, target: Vector3, power: float) -> bool:
	var launch := Slipper.launch_velocity_for(origin, target, power)
	var speed := maxf(launch.length(), 1.0)
	var step := clampf(LANE_SAMPLE_ARC / speed, LANE_STEP_MIN, LANE_STEP_MAX)
	var others := RoundManager.players()
	var t := 0.0
	for _i in range(LANE_MAX_STEPS):
		t += step
		var point := origin + launch * t \
			+ Vector3.DOWN * (0.5 * CharacterBase.GRAVITY * t * t)
		if Vector2(point.x - target.x, point.z - target.z).length() \
				<= Slipper.HIT_RADIUS + 0.30:
			return false # it gets there
		if point.y < target.y - 1.0:
			return true # it fell short of the can's own hit band
		for node in others:
			var who := node as CharacterBase
			if who == null or who == character:
				continue
			if not who.can_be_hit_by_slipper():
				continue
			if Vector2(point.x - who.global_position.x,
					point.z - who.global_position.z).length() \
					> Slipper.HIT_RADIUS + who.capsule_radius():
				continue
			var rise := point.y - who.global_position.y
			if rise < -who.capsule_height() * 0.5 or rise > who.capsule_height() * 0.5:
				continue
			return true
	return true

## ---------------------------------------------------------------------------
## § SPACING — where to throw from, and why it is not teamwork.
##
## §6.3 names 1-vs-3 as the asymmetry nothing here has measured, and names three
## bots chasing one slipper as the obvious failure. The chasing half was a RULES
## bug (see the header) and is gone. What remains is genuinely a three-body
## problem: one taya can only stand in one place, so the attacker who throws from
## the bearing the taya is not covering has a clear lane and the other two do not.
##
## ⚠️ NOBODY IS COOPERATING. Each bot picks the bearing that is best FOR IT, and
## "not where my rivals already are" is part of that for the same reason it is
## for a human: two attackers on the same bearing share one taya, one blocking
## body and one blocked lane. The board (`_claims`) is a way to read the court,
## not an agreement.
##
## Scored over sixteen bearings, cheaply, because the lane test is not cheap and
## `_do_windup()` already re-checks the real arc before releasing.
## ---------------------------------------------------------------------------
const SPOT_SAMPLES: int = 16

func _throw_spot() -> Vector3:
	var lata := RoundManager.lata
	if lata == null:
		return _safe_spot()
	var ring: float = CharacterBase.confinement_radius + THROW_STANDOFF
	var here := character.global_position
	var taya := RoundManager.defender()
	var taya_bearing := 0.0
	var have_taya := taya != null
	if have_taya:
		var offset := _at(taya) - lata.global_position
		taya_bearing = atan2(offset.x, offset.z)
	var rivals := _rival_bearings()
	var best := _safe_spot()
	var best_score := -INF
	for i in range(SPOT_SAMPLES):
		var bearing := -PI + TAU * float(i) / float(SPOT_SAMPLES)
		var point := _ring_point(bearing, ring)
		var score := 0.0
		# Away from the taya. Half a turn is the ideal and is worth the most.
		if have_taya:
			score += 2.4 * (absf(_angle_between(bearing, taya_bearing)) / PI)
		# Away from my rivals — weighted by the tier's `spacing`.
		var nearest_rival := PI
		for claimed in rivals:
			nearest_rival = minf(nearest_rival, absf(_angle_between(bearing, claimed)))
		score += 2.0 * _spacing * (nearest_rival / PI)
		# My own corner of the court, so the four of them do not all drift to the
		# same side of the map over a round.
		score += 0.5 * (1.0 - absf(_angle_between(bearing, _me.home_bearing)) / PI)
		# And it has to be worth walking to.
		score -= 0.11 * _flat(here, point)
		if score > best_score:
			best_score = score
			best = point
	return best

func _rival_bearings() -> Array:
	var out: Array = []
	var now := Time.get_ticks_msec() / 1000.0
	for slot in _claims.keys():
		if slot == character.player_slot:
			continue
		var record: Dictionary = _claims[slot]
		if now - float(record.get("at", -99.0)) > CLAIM_TTL:
			continue
		out.append(float(record.get("bearing", 0.0)))
	return out

func _claim(bearing: float) -> void:
	_claims[character.player_slot] = {
		"bearing": bearing, "at": Time.get_ticks_msec() / 1000.0,
	}

## ---------------------------------------------------------------------------
## § READING THE BOARD — the queries every plan is built out of.
## ---------------------------------------------------------------------------

## ⚠️ MINE, NOT THE NEAREST. `Design.md` §5.2: a slipper belongs to one attacker
## and `can_be_grabbed_by()` refuses everybody else. The predecessor asked for
## the nearest LOOSE one, which is how three bots ended up standing on one prop
## pressing a button it would never answer.
func _my_slipper() -> Slipper:
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null:
			continue
		if slipper.owner_slot == character.player_slot:
			return slipper
	return null

## Is the retrieval run worth making right now?
##
## ⚠️ THE ANSWER IS ABOUT THE TAYA, NOT ABOUT THE DISTANCE. An attacker is 100%
## safe in the box until the moment they pick the slipper up, so the run is only
## dangerous at its far end — and it is free whenever the taya is busy elsewhere.
## Three things count as busy and each is a real rule: the lata is down (the taya
## is channelling and cannot tag at all), the lunge is on cooldown, or somebody
## else is already vulnerable and drawing it.
func _fetch_is_safe(mine: Slipper, taya: CharacterBase) -> bool:
	if _fetch_caution <= 0.0 or taya == null:
		return true
	# ⚠️⚠️ PATIENCE IS BOUNDED, AND IT COST A WHOLE ROUND BEFORE IT WAS.
	# Measured: **P4 spent 64.4 s of one 90 s round in STALK**, and the round's
	# numbers show what that means — 13 throws against 22..28 for the other three,
	# 171 m against 212..248, and 14.2 s taggable against 25..45. Its slipper was
	# camped by the taya (`camp` puts the taya on the retrieval line by design),
	# every one of the four "the taya is busy" conditions below stayed false, and
	# the bot waited for an opening that a good taya never gives.
	#
	# That is correct reasoning with no stopping rule, which is not what a person
	# does: a player who cannot get a free run eventually takes an unfree one.
	# Patience is a tier property, so this is scaled by `fetch_caution` — the kid
	# never waits at all, HARD waits longest, and none of them wait for ever.
	if _stalk_time >= STALK_PATIENCE_BASE + _fetch_caution:
		return true
	var lata := RoundManager.lata
	if lata != null and not lata.is_upright:
		return true
	if taya.lunge_cooldown_left() > 0.35:
		return true
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who != null and who != character and who.is_taggable():
			return true
	return _flat(_at(taya), mine.global_position) > _fetch_caution

## A rival worth shoving: vulnerable, in reach, and with the taya close enough
## that the tag is plausible inside `SABOTAGE_WINDOW`. +50 (`Design.md` §8).
func _sabotage_target(taya: CharacterBase) -> CharacterBase:
	if _sabotage <= 0.0 or taya == null:
		return null
	if character.shove_cooldown_left() > 0.0:
		return null
	if character.get_stamina_ratio() * CharacterBase.STAMINA_MAX \
			< CharacterBase.SHOVE_STAMINA_COST + 2.0:
		return null
	var best: CharacterBase = null
	# The knob is a REACH, not a coin flip. Measured over a whole match at NORMAL:
	# zero sabotages, because it was only ever read as `> 0.0` and the fixed
	# search radius was 4.16 m — while `spacing` is deliberately pushing the three
	# attackers apart, so two of them are rarely that close. A willingness dial
	# that changes nothing is the same defect as a control that does nothing.
	var best_distance: float = CharacterBase.SHOVE_RANGE * (1.0 + 3.0 * _sabotage)
	var taya_window: float = 2.5 + 4.0 * _sabotage
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who == character or who.is_defender:
			continue
		if not who.is_taggable():
			continue
		if _flat(_at(taya), who.global_position) > taya_window:
			continue
		var distance := _flat(character.global_position, who.global_position)
		if distance >= best_distance:
			continue
		# ⚠️⚠️ AND THE SHOVE HAS TO POINT AT THE TAYA, WHICH IS THE WHOLE PLAY.
		# `host_resolve_shove()` sends the victim along `shover -> victim`, so a
		# shove taken from the wrong side launches them 2.5 m AWAY from the person
		# who was about to tag them — the shover pays 25 stamina and a 7.5 s
		# cooldown to RESCUE their rival. Sabotage is +50 only if the tag lands
		# inside `SABOTAGE_WINDOW`, so the geometry is not a refinement, it is the
		# difference between the play and its opposite.
		var push := who.global_position - character.global_position
		push.y = 0.0
		var to_taya := _at(taya) - who.global_position
		to_taya.y = 0.0
		if push.length() < 0.05 or to_taya.length() < 0.05:
			continue
		if push.normalized().dot(to_taya.normalized()) < 0.15:
			continue
		best_distance = distance
		best = who
	return best

## A lunge is winding up, it is aimed near enough to matter, and I am the kind of
## thing it can tag. `observed_lunge_charge()` is replicated precisely so this is
## knowable — the tell exists for the counterplay.
func _should_evade(taya: CharacterBase, delta: float) -> bool:
	if _dodge <= 0.0 or taya == null or not character.is_taggable():
		_gates["lunge"] = 0.0
		return false
	var winding := taya.observed_lunge_charge() >= 0.0 \
		and _flat(character.global_position, _at(taya)) < 4.5
	return _reacted("lunge", winding, delta)

func _tag_target() -> CharacterBase:
	var best: CharacterBase = null
	var best_distance := INF
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who == character or not who.is_taggable():
			continue
		var distance := _flat(character.global_position, _at(who))
		if distance < best_distance:
			best_distance = distance
			best = who
	return best

## The attacker the taya should be standing in front of: whoever is closest to
## actually releasing a throw, then whoever is nearest.
##
## ⚠️ `observed_charge_power()` IS THE TELL AND THE TAYA IS ALLOWED TO READ IT.
## It ticks on every peer for exactly that reason (`carrier.gd`'s header: *"a
## wind-up drawn from it is invisible to the person being aimed at — which is the
## whole counterplay"*), and this is that counterplay being used.
func _live_threat() -> CharacterBase:
	var best: CharacterBase = null
	var best_score := -INF
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who.is_defender:
			continue
		var score := 0.0
		if who.holding_slipper():
			score += 2.0
		if not who.is_inside_box():
			score += 1.0
		var carrier := who.get_node_or_null("Carrier") as Carrier
		if carrier != null and carrier.observed_charge_power() >= 0.0:
			# ⚠⚠ WAS `4.0 + power * 2.0`, i.e. up to +6, AND IT SINGLED OUT HUMANS.
			# 2026-08-01, from a playtest: *"the defender ai only attack him"*.
			#
			# Nothing here reads whether a player is human — the bias is emergent and
			# it is entirely about TIME. `CHARGE_FULL_TIME` is 2.5 s and a person aims
			# for most of it; `_do_windup()` releases the moment it has enough power,
			# so a bot is "charging" for a fraction of a second. A +6 that only one of
			# the three attackers ever holds is not a threat model, it is a lock, and
			# the taya spent whole rounds standing in front of one player.
			#
			# At +2 max it is what it was meant to be: a tiebreak that says "this one
			# is about to throw", which distance and possession can still outweigh.
			score += 1.0 + carrier.observed_charge_power() * 1.0
		score -= 0.08 * _flat(character.global_position, _at(who))
		# ⚠️ ANTI-FIXATION. Whoever this bot guarded last tick is worth slightly less
		# than an equal rival, so a genuine tie rotates instead of sticking. Small on
		# purpose — it must not pull the taya off somebody who is actually the threat,
		# only break the deadlock that made one attacker feel hunted.
		if who == _last_threat:
			score -= 0.6
		if score > best_score:
			best_score = score
			best = who
	_last_threat = best
	return best

## Where to stand to put a body in front of a slipper already in the air.
##
## Returns `Vector3.INF` when there is nothing to block. Otherwise: the earliest
## point on the arc that is (a) inside the band a standing body actually
## occupies, (b) heading for the lata, and (c) somewhere this taya can physically
## get to before the slipper does.
##
## ⚠️ (c) IS WHAT STOPS IT LOOKING STUPID. Without a reachability test the taya
## sprints at a point the slipper passes half a second before it arrives, every
## time, and spends the round chasing throws it was never going to reach.
func _intercept_point(lata: Lata) -> Vector3:
	if lata == null or not lata.is_upright:
		return Vector3.INF
	var speed := CharacterBase.SPEED * character.trait_speed_scale()
	var here := character.global_position
	for id in _flights.keys():
		var record: Dictionary = _flights[id]
		var slipper := record.get("node") as Slipper
		if slipper == null or not is_instance_valid(slipper) or not slipper.is_flying():
			continue
		var launch: Vector3 = record["vel"]
		if launch.length() < 1.0:
			continue
		var from: Vector3 = record["pos"]
		var t := 0.0
		while t < INTERCEPT_HORIZON:
			t += INTERCEPT_STEP
			var point := from + launch * t \
				+ Vector3.DOWN * (0.5 * CharacterBase.GRAVITY * t * t)
			if _flat(point, lata.global_position) <= Slipper.HIT_RADIUS + 0.30:
				break # it is going to arrive; nothing further along matters
			var rise := point.y - here.y
			if rise < -INTERCEPT_BAND or rise > INTERCEPT_BAND:
				continue
			if not _heading_for(point, launch, lata):
				continue
			var travel := _flat(here, point)
			# A little slack for the tier: a perfect reachability test is a taya
			# that only ever attempts blocks it makes, which no player is.
			if travel > speed * t * (0.75 + 0.55 * _intercept):
				continue
			return _clamp_to_box(point)
	return Vector3.INF

## Is this arc still pointed at the can, or has it already gone past?
func _heading_for(point: Vector3, launch: Vector3, lata: Lata) -> bool:
	var to_can := lata.global_position - point
	to_can.y = 0.0
	var flat_launch := Vector3(launch.x, 0.0, launch.z)
	if to_can.length() < 0.05 or flat_launch.length() < 0.05:
		return true
	return to_can.normalized().dot(flat_launch.normalized()) > 0.55

## Where a taya should wait for a retrieval: between a loose slipper in its box
## and the attacker who has to come and get it.
func _cover_point(lata: Lata) -> Vector3:
	if lata == null:
		return Vector3.INF
	var best: Vector3 = Vector3.INF
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null or not slipper.is_loose():
			continue
		if maxf(absf(slipper.global_position.x), absf(slipper.global_position.z)) \
				>= CharacterBase.confinement_radius:
			continue # outside the box: not the taya's problem and not reachable
		var holder := RoundManager.player_at(slipper.owner_slot)
		if holder == null or holder.is_defender:
			continue
		var toward := _at(holder) - slipper.global_position
		toward.y = 0.0
		if toward.length() < 0.05:
			continue
		# Sit on the approach line, one body-length out from the slipper, so the
		# retrieval has to come through the taya rather than around it. `camp`
		# decides how far up the line that is — 0 leaves it standing on the can.
		var point := slipper.global_position + toward.normalized() * (0.6 + 0.9 * _camp)
		var distance := _flat(character.global_position, point)
		if distance < best_distance:
			best_distance = distance
			best = point
	if best == Vector3.INF:
		return best
	return _clamp_to_box(best)

## ---------------------------------------------------------------------------
## § MOVEMENT. Everything below turns a point into presses.
## ---------------------------------------------------------------------------

## Walk to `point`, stopping inside `stop_at` and not resuming until well outside
## it. Returns true once arrived.
func _goto(point: Vector3, stop_at: float, sprint: bool) -> bool:
	if _flat(_goal, point) > GOAL_MOVED:
		_arrived = false
	_goal = point
	var delta := point - character.global_position
	delta.y = 0.0
	var distance := delta.length()
	var threshold := stop_at * ARRIVE_HYSTERESIS if _arrived else stop_at
	if distance <= threshold:
		_arrived = true
		_stop()
		return true
	_arrived = false
	var heading := delta / maxf(distance, 0.001)
	heading += _separation() * SEPARATION_WEIGHT
	_drive(heading, sprint and distance > REACH)
	return false

## Four digital presses in WORLD space — see the header on why the bot is given a
## keyboard rather than a bearing. `CharacterBase.input_vector()` reads a
## non-mouse-aimed unit's stick as world-relative, which is what a bot is.
##
## ⚠️ `EIGHT_WAY_THRESHOLD` IS sin(22.5°) AND NOT A ROUND NUMBER ON PURPOSE. It
## is the exact bisector between two adjacent keyboard headings, so a desired
## bearing always resolves to its NEAREST of the eight. The predecessor used
## 0.35, which is 20.5° — a 2° band near each diagonal where both neighbours
## qualify and the bot presses three keys.
func _drive(direction: Vector3, sprint: bool) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.001:
		_stop()
		return
	flat = flat.normalized()
	_driving = true
	if _unstick_left > 0.0:
		# Ninety degrees off the wanted heading: enough to clear a corner, and it
		# still makes progress along the obstacle rather than backing away from it.
		flat = Vector3(-flat.z * _unstick_sign, 0.0, flat.x * _unstick_sign)
	_press("move_right", flat.x > EIGHT_WAY_THRESHOLD)
	_press("move_left", flat.x < -EIGHT_WAY_THRESHOLD)
	_press("move_down", flat.z > EIGHT_WAY_THRESHOLD)
	_press("move_up", flat.z < -EIGHT_WAY_THRESHOLD)
	_press("sprint", sprint and _may_sprint())

## ⚠️ THE RESERVE IS THE POINT AND IT IS A DIFFICULTY KNOB. The bar is 50 points
## draining at 40/s — **1.25 seconds** — and fatigue is 2 s at 0.75 speed with
## regen locked. A bot that sprints whenever it is far away arrives fatigued and
## is then tagged standing still, which is precisely what "the AI gives up" looks
## like from the stands. `sprint_reserve` 0 on the kid is that mistake, kept.
func _may_sprint() -> bool:
	if character.is_fatigued():
		return false
	return character.get_stamina_ratio() > _sprint_reserve

## Steers away from bodies that are too close. Not collision — that is
## `_shed_character_perch()`'s job — but the reason three attackers converging on
## one box read as three people rather than as one clump.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	var here := character.global_position
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who == character:
			continue
		var away := here - who.global_position
		away.y = 0.0
		var distance := away.length()
		if distance > SEPARATION_RADIUS or distance < 0.01:
			continue
		push += (away / distance) * (1.0 - distance / SEPARATION_RADIUS)
	return push

## A bot with nothing to do shifts its weight instead of standing at attention.
## Slow, small, and per-bot out of phase — this is most of "they look alive", and
## it costs one sine.
func _loiter() -> void:
	var swing := sin(TAU * _loiter_phase / LOITER_PERIOD)
	if absf(swing) < 0.72:
		_stop()
		return
	var lata := RoundManager.lata
	var pivot: Vector3 = lata.global_position if lata != null else Vector3.ZERO
	var out := character.global_position - pivot
	out.y = 0.0
	if out.length() < 0.05:
		out = Vector3.FORWARD
	out = out.normalized()
	var across := Vector3(-out.z, 0.0, out.x)
	_drive(across * signf(swing) * LOITER_SPEED, false)

## The nearest point outside the box, straight out along the bearing this bot is
## already on.
##
## ⚠️⚠️ IT PROJECTS ONTO THE SQUARE, NOT ONTO A CIRCLE, AND THAT IS WHY THE BOTS
## USED TO FREEZE. The box is a SQUARE — `_move_and_confine()` clamps X and Z
## independently and `can_throw()` gates on `max(|x|,|z|) >= radius`. Normalising
## the bearing and multiplying lands on a CIRCLE, and a circle of radius r is
## INSIDE a square of half-width r everywhere except the four edge midpoints: on
## a diagonal the answer measured `ring / sqrt(2)`, so the bot walked to its
## "safe spot", was still inside the box, was refused the throw, and walked to the
## same spot again for the whole round. Scaling by the CHEBYSHEV distance puts the
## point exactly on the square ring for every bearing, by construction.
func _safe_spot() -> Vector3:
	var here := character.global_position
	var flat := Vector2(here.x, here.z)
	var reach := maxf(absf(flat.x), absf(flat.y))
	if reach < 0.01:
		flat = Vector2(0.0, 1.0)
		reach = 1.0
	var ring: float = CharacterBase.confinement_radius + THROW_STANDOFF
	flat *= ring / reach
	# ⚠⚠ CLAMPED TO THE MAP'S OWN WALLS. This ring is `confinement_radius + 1.2`
	# and it knows nothing about the world it is drawn in — on 2026-08-01 the box
	# grew until it landed 0.1 m past Eskinita's house facades, and every bot on an
	# east or west bearing walked into a wall and pressed into it for the rest of its
	# plan. 🧑: *"the bots legit just go up random shit without doing anything, they
	# just walk up the houses"*. `main.gd` measures the walls at load; a goal outside
	# them is now impossible to hand out rather than merely unlikely.
	return CharacterBase.clamp_to_playable(Vector3(flat.x, 0.0, flat.y))

## A point on the square ring at `ring` Chebyshev radius, on the given bearing.
## Same projection as `_safe_spot()`, for a bearing this bot chose rather than
## the one it happens to be standing on.
func _ring_point(bearing: float, ring: float) -> Vector3:
	var direction := Vector2(sin(bearing), cos(bearing))
	var reach := maxf(absf(direction.x), absf(direction.y))
	if reach < 0.001:
		return Vector3(0.0, 0.0, ring)
	direction *= ring / reach
	# Clamped for the same reason `_safe_spot()` is: every bearing this returns is a
	# place a bot will walk to, and a bearing pointing at a wall used to mean walking
	# into it until the plan changed.
	return CharacterBase.clamp_to_playable(Vector3(direction.x, 0.0, direction.y))

## The shortest way out of the box from here, as a unit heading.
func _out_of_box_dir() -> Vector3:
	var here := character.global_position
	if absf(here.x) >= absf(here.z):
		return Vector3(signf(here.x) if absf(here.x) > 0.01 else 1.0, 0.0, 0.0)
	return Vector3(0.0, 0.0, signf(here.z) if absf(here.z) > 0.01 else 1.0)

## Pushes a point `margin` outside the box along its own bearing. Used to stand
## NEAR a landing spot without standing inside the danger zone waiting for it.
func _pull_outside(point: Vector3, margin: float) -> Vector3:
	var reach := maxf(absf(point.x), absf(point.z))
	var ring: float = CharacterBase.confinement_radius + margin
	if reach >= ring or reach < 0.01:
		return point
	var flat := Vector2(point.x, point.z) * (ring / reach)
	return Vector3(flat.x, 0.0, flat.y)

## Keeps a taya's goal inside its own box, so it walks to somewhere it can stand
## rather than pressing itself against the confinement clamp — which looks
## exactly like a bot stuck on a wall, because it is one.
func _clamp_to_box(point: Vector3) -> Vector3:
	var edge: float = CharacterBase.confinement_radius - 0.35
	return Vector3(clampf(point.x, -edge, edge), point.y, clampf(point.z, -edge, edge))

## Where a slipper already in flight is going to come down. Sampled off the same
## observed velocity the interception uses.
func _predicted_landing(slipper: Slipper) -> Vector3:
	var record: Dictionary = _flights.get(slipper.get_instance_id(), {})
	if record.is_empty():
		return Vector3.INF
	var launch: Vector3 = record["vel"]
	if launch.length() < 0.5:
		return Vector3.INF
	var from: Vector3 = record["pos"]
	var t := 0.0
	while t < Slipper.MAX_FLIGHT_TIME:
		t += 0.05
		var point := from + launch * t \
			+ Vector3.DOWN * (0.5 * CharacterBase.GRAVITY * t * t)
		if point.y <= from.y - 1.2 or point.y <= 0.2:
			return Vector3(point.x, 0.0, point.z)
	return Vector3.INF

## Is `who` inside `cone` degrees of the way this body is facing? The lunge and
## the shove both fire along `-basis.z`, so this is the difference between a dash
## that tags and a dash that misses by a metre.
func _facing(who: CharacterBase, cone: float) -> bool:
	if who == null:
		return false
	var forward := -character.global_transform.basis.z
	forward.y = 0.0
	var toward := who.global_position - character.global_position
	toward.y = 0.0
	if forward.length() < 0.01 or toward.length() < 0.01:
		return false
	return rad_to_deg(forward.normalized().angle_to(toward.normalized())) <= cone

## ---------------------------------------------------------------------------
## § SMALL HELPERS.
## ---------------------------------------------------------------------------

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## Signed shortest angle from `b` to `a`, in radians.
func _angle_between(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)

## One coin flip per plan, at the tier's `mistake` rate.
func _blunder() -> bool:
	return randf() < _mistake

func _stop() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "sprint"]:
		_press(action, false)

func _release_all() -> void:
	_windup = false
	# ⚠️ `_lunge_held` RESETS HERE TOO, not just the button. A bot stunned
	# mid-charge otherwise resumes from wherever its accumulator stopped and fires
	# the instant it recovers, which is a lunge nobody saw wind up.
	_lunge_held = -1.0
	_goal_valid = false
	_arrived = false
	_stuck_time = 0.0
	_unstick_left = 0.0
	_driving = false
	for action in ["move_left", "move_right", "move_up", "move_down", "sprint",
			"grab", "special_ability", "jump", "lunge"]:
		_press(action, false)

func _press(action: String, pressed: bool) -> void:
	if character == null:
		return
	character.ai_set_intent(action, pressed)
	_pressed[action] = pressed

## Produces a real press EDGE by alternating. `_step_grab()` and `_step_shove()`
## both read `input_just_pressed`, which needs a false frame before every true
## one — a button simply held down fires once in a lifetime, which is how a bot
## ends up standing on its own slipper for ninety seconds.
func _tap(action: String) -> void:
	_press(action, not bool(_pressed.get(action, false)))

func _plan_name(plan: Plan) -> String:
	return Plan.keys()[plan]

## What this bot is doing right now, in one word. Read by `tools/ai_probe.gd` when
## it catches a unit standing still, so the report can name the branch responsible
## instead of leaving somebody to bisect for it. ⚠️ It is the ONLY thing this file
## exposes about its own decisions — the probe measures the game's transforms and
## signals for everything else, deliberately, so it cannot grade the AI on what the
## AI believed it was doing.
func current_plan() -> String:
	return _plan_name(_plan)

func _trace(what: String) -> void:
	if not trace_enabled or what == _last_trace:
		return
	_last_trace = what
	print("[ai] P%d %s %s" % [character.player_slot + 1,
		"taya" if character.is_defender else "atk", what])
