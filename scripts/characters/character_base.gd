extends CharacterBody3D
class_name CharacterBase
## One human player. **Every unit in the match is one of these and there are
## exactly four.** Rewritten 2026-07-31 on branch `HARRYDAKS`.

## ---------------------------------------------------------------------------
## ⚠️⚠️ WHAT THIS FILE STOPPED BEING. It used to be the base class for FOUR kinds
## of thing — a Person, a lata, a tsinelas, and whatever a roster ability made of
## them — carrying every verb any of them had: a charged bump meter with a punt, a
## Can-Dash, a Ground Smash, a self-launch, a guard, a seal, a scuff, a dent
## counter and an `AbilityBase` slot. 🧑 2026-07-31: *"drop the irrelevant
## mechanics now like bump and stuff and slipper being a character and can being a
## character"*.
##
## The lata is now `scripts/objects/lata.gd` and the tsinelas is
## `scripts/objects/slipper.gd`, both props. This file is one role — a person who
## runs, sprints, throws, retrieves, shoves and tags — and `is_defender` is the
## only thing that varies between the four of them.
##
## ⚠️ WHAT WAS KEPT, AND WHY EACH ONE IS NOT DEAD WEIGHT:
##   · `SPAWN_SETTLE_FRAMES` — a real, expensively-diagnosed physics fix (B-100).
##     Roles rotate every round, so players trade marks, and for one physics frame
##     each stands on the other's stale collider. Still true with four of them.
##   · `_shed_character_perch()` — you cannot stand on somebody's head. Also real,
##     also from live play, and MORE likely now that three attackers converge on
##     one box.
##   · The AI intent block and `input_*` indirection — the AI presses the same
##     buttons a human does, which is the only reason a single `_physics_process`
##     serves both. 🧑 deferred the AI rewrite to the last lane; this keeps the
##     harness it will need.
##   · The confinement clamp — see `CONFINEMENT_RADIUS`. It IS the Defender's Box.
## ---------------------------------------------------------------------------

## Base walk speed, metres/second. **The taya's speed** — see `ATTACKER_SPEED_SCALE`.
const SPEED: float = 4.6
## ⚠️⚠️ THE ATTACKER IS PERMANENTLY SLOWER THAN THE TAYA, AND THAT ASYMMETRY IS THE
## POINT. 🧑 2026-08-01: *"Attacker Speed: 75% Base Speed (Permanently 25% slower than
## the Defender to give the Defender a reliable closing advantage during chases)."*
##
## Before this the two moved identically, which made the tag a coin-flip on reaction
## time: a taya who read the retrieval perfectly still could not close, because the
## attacker they were chasing was exactly as fast and had a head start by
## construction. One taya against three attackers needs a structural edge somewhere,
## and speed is the one the player can actually feel.
##
## ⚠️ IT IS A ROLE SCALE, NOT A UNIT STAT — read through `_role_speed_scale()` off
## `is_defender`, which rotates every round. Baking it into a character would make
## the seat rotation change how fast you are for reasons unrelated to your role.
const ATTACKER_SPEED_SCALE: float = 0.75
const FRICTION: float = 30.0
const GRAVITY: float = 20.0
const MAX_FALL_SPEED: float = 26.0
const JUMP_VELOCITY: float = 5.8
const LAND_SFX_MIN_SPEED: float = 2.0

## ---------------------------------------------------------------------------
## STAMINA. `Design.md` §Shared — and the units changed with this rewrite.
##
## ⚠️ THIS BAR IS NOW IN POINTS, NOT SECONDS. It used to be `STAMINA_MAX = 4.0`
## meaning "four seconds of sprint", drained at 1.0/s. The GDD specifies a
## 100-point bar draining at 20/s, which is the same idea at 25× the resolution —
## but the numbers are NOT a straight rescale of the old ones and must not be read
## as one: 100/20 is **5.0 s** of sprint, not 4.0, and regen is 20/s against the
## old 0.7/s-equivalent of 17.5/s. The HUD reads `get_stamina_ratio()` and is
## unaffected either way.
## ---------------------------------------------------------------------------
## ⚠️⚠️ REVISED 2026-08-01 ON HUMAN INSTRUCTION — A 50-POINT POOL DRAINING AT 40/s.
## 🧑: *"Max Stamina Pool: 50 Points. Sprint Drain: Consumes 10 Stamina Points every
## 0.25 seconds (40 Stamina/second)."* That is **1.25 s of sprint**, down from 5.0 s.
##
## ⚠️ THE DRAIN IS EXPRESSED PER SECOND, NOT AS A 0.25 s TICK, and the two are the
## same rule. A quarter-second tick would make sprint free for the first 249 ms and
## then cost 10 in one frame — a player tapping Shift on a 0.2 s rhythm would sprint
## for nothing, which is exactly the feathering `STAMINA_SPRINT_FLOOR` exists to
## stop. 40/s continuous spends the identical 10 points per 0.25 s held.
## ⚠️⚠️ 50 -> 60 ON 2026-08-01, ON HUMAN INSTRUCTION: *"Increase the maximum
## stamina pool from 50 to 60 points."* At the unchanged 40/s drain that is
## **1.50 s of sprint**, up from 1.25 — and the number that actually moved is the
## DISTANCE: a full sprint now covers **8.2 m** against 6.84 (measured,
## `mech_probe`). §2.5 established that the bar is dimensioned to one crossing of
## the danger zone, and the box went to 7.5 in the same session, so this puts the
## two back in step: one sprint crosses the box again with a little to spare.
const STAMINA_MAX: float = 60.0
const STAMINA_DRAIN_RATE: float = 40.0
const STAMINA_REGEN_RATE: float = 20.0
## ⚠️⚠️ 2.5 -> 1.0 ON 2026-08-01, ON HUMAN INSTRUCTION: *"Reduce the stamina
## recovery delay from 2.5 seconds to 1.0 second of absolute non-usage."*
##
## This is the biggest single change to the attacker's tempo in the file. Empty to
## full was 2.5 s of waiting + 3.0 s of refill = 5.5 s; it is now **1.0 + 3.0 =
## 4.0 s**, and more importantly a PARTIAL top-up between two runs starts almost
## immediately instead of after a beat longer than the sprint itself. The retrieval
## loop (§0) is sprint in, grab, sprint out — and the old delay meant the second
## sprint of that pair was never available.
const STAMINA_REGEN_DELAY: float = 1.0
## Sprint is +50% speed.
const SPRINT_SCALE: float = 1.50
## You cannot *start* a sprint below this, so the bar cannot be feathered a frame
## at a time to dodge the fatigue state. Kept from the predecessor, rescaled.
## ⚠️ RESCALED WITH THE POOL: 7.5 on a 50-point bar is the same 15% of full that
## 15.0 was on 100. Not rescaling it would have left the floor at 30% of the new bar
## and made short sprints impossible to start.
const STAMINA_SPRINT_FLOOR: float = 7.5
## Hitting zero costs this long at reduced speed with sprint locked out. This is
## the whole reason the bar is interesting: running out is a punishment, not just
## an absence.
##
## ⚠️⚠️ 2.0 s, AND IT IS NOW A REGEN LOCKOUT AS WELL AS A SPEED PENALTY. 🧑
## 2026-08-01: *"Reaching 0 Stamina triggers the Fatigued State. While fatigued,
## stamina regeneration is completely locked until a 2-second recovery delay
## expires."* Previously the bar started refilling `STAMINA_REGEN_DELAY` after the
## last sprint frame REGARDLESS of fatigue, so a fatigued player was slower but was
## already rebuilding — the penalty was cosmetic on the resource it was supposedly
## punishing. `_step_stamina()` now refuses to regen at all while `_fatigue_left`
## is running.
const FATIGUE_TIME: float = 2.0
const FATIGUE_SPEED_SCALE: float = 0.75

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE DEFENDER'S BOX. THE `const` BELOW MUST STAY, AND MUST STAY IN THAT
## EXACT SYNTAX. `tools/maps/floorcheck.py` reads the box size by regexing
## `^const CONFINEMENT_RADIUS: float = ...` out of this file, and BOTH map builders
## draw the chalk from it. Delete or reshape the const and every map build aborts.
##
## The boundary is a chalk SQUARE at |x| = |z| = this value, and `_move_and_confine()`
## clamps X and Z independently to match — a square and a circle of the same
## "radius" only agree at the four edge midpoints, and on the diagonals they
## disagree by 2.07 units, which is exactly where a Defender moves when covering a
## corner. The square is the real one; that was a human call on 2026-07-29 and it
## survives this rewrite unchanged.
##
## ⚠️ IT NOW MEANS SOMETHING SLIGHTLY DIFFERENT AND THE NUMBER HAS NOT BEEN
## RE-TUNED FOR IT. It used to confine the defending Person and the lata in a 2v2.
## It now confines ONE Defender while THREE Attackers converge on the same box.
##
## ⚠️ RAISED 5.0 -> 6.5 BY 🎨 `build model` ON 2026-08-01, ON HUMAN INSTRUCTION.
## 🧑, twice: *"the current play area feels too small"* and *"i said bugs like play
## area needs to be bigger"*. 5.0 was measured for ONE taya against ONE attacker;
## it now has to hold one taya against three converging ones, and a box that three
## people can flood is a box with no defensive play in it.
##
## 6.5 is +30% on the edge and +69% on the AREA (100 -> 169 square units), which is
## the largest step that still leaves the box coverable. It was chosen against two
## hard limits rather than by taste:
##   · the throw has to reach. The gate is `max(|x|,|z|) >= radius`, so the
##     shortest legal throw is now 6.5 m. `LAUNCH_SPEED` 17.0 against `GRAVITY`
##     20.0 gives a 45-degree range of v^2/g = 14.45 m, so 6.5 sits comfortably
##     inside it — 7.5 would too, 12.0 would not.
##   · the court has to hold it. `COURT_Z` is 13.0 on both maps and the Attacker
##     spawn ring is radius + `SAFE_ZONE_MARGIN` = 8.5, so the ring still lands on
##     paving. Both map builders' `surfaces.verify()` re-checks this on every run.
##
## ⚠️ THIS CONST IS ⚖️ `build fair`'s FILE, NOT `build model`'s, AND THE VALUE IS A
## STARTING POINT THEY OWN. It is moved here only because the maps and the chalk
## are derived FROM it and the human asked for the bigger area twice — a map lane
## that could not move it could not deliver the item at all. `build fair` §2.2 is
## the same number and is filed to re-measure it against a real 1-vs-3 match; note
## that it also pulls on §2.1, since a box three attackers can enter more easily is
## a taya who collects less uncontested passive defence.
##
## ⚠️⚠️ RAISED 6.5 -> 7.5 BY ⚖️ `build fair` ON 2026-08-01, ON HUMAN INSTRUCTION.
## 🧑: *"can you pls make it bigger, it hsould be like up to here"*, and *"pls just
## make our chalk lines longer ... also please edit the actual defender area"*.
## This is §2.2/§2.21 — the box has been this lane's number since the map lane
## moved it, and it had still never been re-tuned for one taya against three.
##
## +15% on the edge and **+33% on the AREA** (169 -> 225 square units).
##
## ⚠️⚠️ 8.0 WAS TRIED FIRST AND ESKINITA REJECTED IT — THE ALLEY IS EXACTLY THAT
## WIDE. `build_eskinita.py`'s `W = 8.0` is "half-width of the playable alley",
## so a box at 8.0 puts the chalk ON the walls: `can_throw()` gates on
## `max(|x|,|z|) >= radius`, which would have left an attacker no legal ground to
## throw from on the EAST and WEST sides at all — only the two open ends. That is
## not a bigger arena, it is a corridor with two firing positions, and it would
## have made the two maps play completely differently. **The throwing line, not
## the box, is what has to fit**: at 7.5 it lands at 8.5, just onto the apron
## outside the paved core, and all four bearings stay usable.
##
## The other two limits are unchanged and both comfortable:
##   * **the throw has to reach.** Shortest legal throw is now 7.5 m against a
##     45-degree range of `LAUNCH_SPEED`^2 / `GRAVITY` = 14.45 m. The per-skin
##     speed scale (§2.8) moves that range 13.0-15.9, so even the slowest slipper
##     clears 7.5 easily.
##   * **the court has to hold it.** `COURT_Z` is 13.0 on both maps and the spawn
##     ring is radius + `SAFE_ZONE_MARGIN` = 9.5. Both builders re-verify and abort.
##
## ⚠️ IT IS ONE NUMBER AND ONE REBUILD. `tools/maps/floorcheck.py` regexes this
## const and both builders draw the chalk from it, so moving it and re-running the
## two builders is the whole change — the painted box, the throwing line at
## radius + 1.0 and the spawn ring all follow. ⚠️ AND SO DOES THE PLAY-AREA
## KEEP-OUT: `mapkit.Placer.play_box` is set from this const, so growing the box
## now EVICTS the street clutter that would otherwise end up inside it (29 pieces
## on Eskinita, 13 on Bayan Plaza at the first rebuild).
##
## ⚠⚠⚠ AND 7.5 WAS STILL TOO BIG — 7.0 IS THE CEILING THIS MAP ALLOWS. 🧑, with a
## clip: *"pathfinding broken, sometimes the bots legit just go up random stuff
## without doing anything, they just walk up the houses"*.
##
## THE THIRD BOUND, AND THE ONE NOBODY HAD WRITTEN DOWN: **the attackers' standoff
## ring has to fit inside the map's walls.** `ai_controller.gd` sends every attacker
## to a point on a square ring at `confinement_radius + THROW_STANDOFF` (1.2) — that
## is where you stand to throw. Eskinita's `Bounds/WallEast|West` are the house
## facades at **x = ±8.6** and they are the only thing a player cannot walk through.
##
##     radius 6.5 -> ring 7.7   fits
##     radius 7.5 -> ring 8.7   0.1 m BEYOND THE WALL
##
## So every bot that picked an east or west bearing walked into a facade and pressed
## into it for as long as it held that plan. That is the reported "walking up the
## houses": they are not climbing anything, they are jammed against the wall the
## houses are drawn on, which is also why it looked like they were *"not doing
## anything"* — they had arrived at a goal they could never reach.
##
## 7.0 puts the ring at 8.2. With a 0.4 capsule radius and `ARRIVE_SLOP` 0.55 the
## bot settles around 7.65 and never touches the facade. It is still **+7.7% on the
## edge and +16% on the area** over 6.5, and the chalk is visibly longer, which is
## what was asked for.
##
## ⚠️ THE GENERAL LESSON, because it will bite the next person who grows this: the
## limit is NOT the throw range and NOT the court size. It is
## `CONFINEMENT_RADIUS + AIController.THROW_STANDOFF + a capsule <= WALL_FACE_X`,
## and two of those three numbers live in files this const does not.
##
## ⚠️ CHANGING THIS AT RUNTIME MOVES THE PHYSICS BOX AND NOT THE PAINTED ONE.
const CONFINEMENT_RADIUS: float = 7.0
## The live value every gameplay read goes through, promoted so a probe can sweep
## the box size without editing this file.
static var confinement_radius: float = CONFINEMENT_RADIUS

## ---------------------------------------------------------------------------
## ⚠⚠ HOW FAR A BODY CAN ACTUALLY GO BEFORE IT MEETS A WALL. Published by
## `main.gd` from the loaded map's own `Bounds` colliders; huge until it is.
##
## THIS EXISTS BECAUSE THE AI HAD NO WAY TO KNOW A MAP HAS EDGES. `ai_controller`
## sends attackers to a square ring at `confinement_radius + THROW_STANDOFF`, and on
## 2026-08-01 the box grew until that ring landed 0.1 m PAST Eskinita's house
## facades — so every bot on an east or west bearing walked into a wall and pressed
## into it for the rest of its plan. 🧑: *"the bots legit just go up random stuff
## without doing anything, they just walk up the houses"*.
##
## ⚠️ THE RADIUS WAS PULLED BACK TO FIT (see `CONFINEMENT_RADIUS`), AND THAT ALONE
## IS NOT A FIX. It re-tunes one number on one map until the symptom stops; the
## next map with a narrower street, or the next person who grows the box, gets the
## same bug with no warning. A goal outside the world should be impossible to
## generate, not merely unlikely.
##
## Measured off the colliders rather than declared, so a map that moves its walls
## moves this with them and nothing has to be kept in step by hand.
static var playable_half_x: float = 1000.0
static var playable_half_z: float = 1000.0

## The nearest point to `where` that a body can actually stand in. `margin` is
## normally a capsule radius — a goal ON the wall is a goal you press into.
static func clamp_to_playable(where: Vector3, margin: float = 0.45) -> Vector3:
	var limit_x := maxf(playable_half_x - margin, 0.5)
	var limit_z := maxf(playable_half_z - margin, 0.5)
	return Vector3(clampf(where.x, -limit_x, limit_x), where.y,
		clampf(where.z, -limit_z, limit_z))

## ---------------------------------------------------------------------------
## THE SHOVE. `Design.md` §Attacker.
##
## ⚠️⚠️ REVISED 2026-08-01: SINGLE TAP, NO CHARGE, 2.5 m, 7.5 s COOLDOWN. 🧑:
## *"Input: Single tap of E (No charge time). Cooldown: 7.5 Seconds. Effect:
## Triggers a Hand Shove Animation and blasts neighboring players in front backward
## 2.5 meters and stun them for 1.25 seconds."*
##
## `SHOVE_CHARGE_TIME` is now **0.0** rather than deleted, and that is deliberate:
## `character_visual.gd::_drive_charge_pose()` and `camera_rig.gd`'s viewmodel both
## read `observed_shove_charge()` as a 0..1 ratio, and `hud.gd` draws it. Zeroing the
## time makes the ratio jump 0 → 1 in one frame, which every one of those readers
## already handles (it is the same shape a tap-throw produces); deleting the const
## would have broken three files for a mechanic that still fires.
##
## ⚠️ THE IMPULSE IS RE-DERIVED, AND IT IS THE ONE NUMBER HERE THAT CANNOT BE COPIED.
## The old 7.75 m/s was salvaged precisely because `distance = v² / FRICTION_2` gave
## exactly 1.00 m on this friction model. The spec now asks for **2.5 m**, so the
## same solve runs again rather than the old constant being nudged:
## `v = sqrt(2.5 × 60) = 12.247`. Move `FRICTION` and this number is wrong — it is
## derived from it, not independent of it.
## ---------------------------------------------------------------------------
const SHOVE_CHARGE_TIME: float = 0.0
const SHOVE_SPEED: float = 12.247
const SHOVE_LIFT: float = 2.2
const SHOVE_STUN: float = 1.25
const SHOVE_STAMINA_COST: float = 25.0
const SHOVE_COOLDOWN: float = 7.5
## ⚠️ WHAT A WHIFF COSTS, new 2026-08-01 — see `_release_shove()`. Deliberately
## about a quarter of the full one: long enough that mashing E across the box is
## not a strategy, short enough that trying and missing is not a decision you
## regret for seven and a half seconds.
const SHOVE_MISS_COOLDOWN: float = 2.0
## How far in front of the shover the push reaches. Two capsule radii (0.40 each)
## plus a small band — you have to actually be next to them.
const SHOVE_RANGE: float = 1.6
## Half-angle of the forward arc, degrees. A shove is aimed; it is not a pulse.
const SHOVE_ARC_DEG: float = 70.0

## ---------------------------------------------------------------------------
## THE LUNGE — the taya's tag, made an ACTIVE verb. New 2026-08-01. `Design.md` §6.
##
## 🧑: *"Input: Hold Right-Click to charge, release to fire. Charge Time: 0.5 Seconds
## to reach maximum lunge power. Execution: Triggers a Hand Lunge Animation while
## launching the Defender forward in a rapid 2.5-meter dash. Tag Trigger: Any
## vulnerable Attacker caught in the lunge path is instantly tagged."*
##
## ⚠️⚠️ THIS REPLACES A PROXIMITY TAG THAT THE PLAYER NEVER PRESSED. `RoundManager.
## _step_tag()` awarded 100 points for standing close enough, every physics frame,
## with no input and no animation — the taya was *"simply teleported"* into a score
## (the old §2.14). Making it a charged, aimed commitment does three things at once:
## it gives the tag a wind-up an attacker can read and dodge, it gives the taya
## something to be good at, and it makes the 100 points an earned event rather than
## a proximity accident.
##
## ⚠️ THE DASH DISTANCE IS DERIVED FROM `FRICTION`, exactly like `SHOVE_SPEED`:
## `v = sqrt(2.5 × 60) = 12.247`. The lunge is a velocity impulse the existing
## friction integrates down, NOT a teleport — a teleport would skip the intervening
## space, and "caught in the lunge path" requires there to be a path.
const LUNGE_CHARGE_TIME: float = 0.5
## ⚠️⚠️ 12.247 -> 7.746 ON 2026-08-01, ON HUMAN INSTRUCTION: *"Lunge Tag (Hold E for
## 0.5s): ... a short 1-meter forward dash."* Re-derived on the same `v²/FRICTION_2`
## solve every impulse in this file uses rather than nudged: `sqrt(1.0 × 60) =
## 7.746`. Move `FRICTION` and this number is wrong.
##
## The lunge stops being the taya's only verb in the same change — the PUNCH below
## is the close-range one — so it no longer has to cover the whole box. A 2.5 m dash
## that missed put the tag on cooldown and left the taya three metres from the can;
## a 1 m step is a commitment you can make twice.
const LUNGE_SPEED: float = 7.746
## Radius around the taya, swept every frame the lunge is live, inside which a
## vulnerable attacker is tagged. Wider than `TAG_RADIUS` was, because a moving body
## sampled at 60 Hz covering 2.5 m can otherwise step clean over a narrow band
## between two frames — the classic tunnelling failure, and the reason this is a
## swept check rather than a single test at the end of the dash.
const LUNGE_TAG_RADIUS: float = 1.3
## How long the lunge stays "live" for tagging after release. Slightly longer than
## the dash itself takes to decay, so the tail of the movement still counts.
const LUNGE_ACTIVE_TIME: float = 0.45
const LUNGE_COOLDOWN: float = 1.5
## A minimum commitment, so a tapped right-click is not a free full-power tag. Below
## this the lunge still fires but travels proportionally less far.
const LUNGE_MIN_POWER: float = 0.35

## ---------------------------------------------------------------------------
## THE PUNCH — the taya's quick tag. New 2026-08-01, on human instruction:
## *"Melee Punch Tag (Left-Click): Implement a quick close-range punch for non-bot
## defenders. When the punch connects with a vulnerable attacker, it should
## immediately register a tag."*
##
## ⚠️ WHY THE TAYA NEEDED A SECOND VERB. The lunge is a 0.5 s charge, a dash and a
## 1.5 s cooldown — a COMMITMENT, and the right answer to an attacker who is
## running past. It is the wrong answer to one standing next to you, because the
## charge is exactly long enough for them to leave. The punch is the other half:
## no charge, short reach, short cooldown, and it does not move the taya at all.
##
## ⚠️ LEFT-CLICK IS FREE ON A DEFENDER AND ONLY ON A DEFENDER. `special_ability` is
## the throw charge, and `RoundManager.can_throw()` refuses a defender outright
## (`Design.md` §5.1), so nothing is being taken away from anybody. `_step_punch()`
## returns immediately for an attacker for the same reason `_step_lunge()` does.
##
## ⚠️ IT IS AIMED, LIKE EVERYTHING ELSE THAT FIRES ALONG `-basis.z`, and therefore
## subject to §6 trap 13: a taya who walks up and STOPS has frozen their facing.
## That is deliberate and shared with the shove and the lunge — the counterplay to
## all three is the same, and a punch with no arc would be a proximity tag, which
## is exactly what 2026-08-01 deleted.
const PUNCH_RANGE: float = 1.7
const PUNCH_ARC_DEG: float = 75.0
## Short enough to feel like a jab, long enough that mashing is not the strategy.
const PUNCH_COOLDOWN: float = 0.9

const MAX_KNOCKBACK_SPEED: float = 16.0
const MAX_KNOCKBACK_LIFT: float = 7.0
## Default stagger applied by an unqualified hit.
const BASE_STAGGER_TIME: float = 0.25

const HITSTOP_DURATION: float = 0.06
const HITSTOP_TIME_SCALE: float = 0.05
static var _hitstop_active: bool = false
static var _hitstop_restore_scale: float = 1.0

## ⚠️ `SEALED` IS GONE with the seal, and so is every branch that tested for it.
## `DOWNED` survives because a shove that lands on someone mid-air still has to put
## them on the floor, and because the visual has a pose for it.
enum State { NORMAL, STAGGERED, DOWNED }

## ⚠️ KEPT AS EXPORTS ONLY SO `character_visual.gd` AND `character_nameplate.gd`
## KEEP THEIR SIGNATURES. Every unit is a Person now; nothing sets these to
## anything else. They are the last two lines of the objects-are-players thesis
## and a later lane may fold them away entirely.
@export var is_person: bool = true
@export var is_can: bool = false

## ⚠️ RENAMED FROM `team_is_can_side`, and it is the same bit doing a clearer job.
## It meant "this Person is on the defending side"; there are no sides now, so it
## means "this Person is THE Defender this round". Exactly one of the four has it
## true, `MatchManager.defender_slot` decides which, and `main.gd` writes it at
## every round start.
@export var is_defender: bool = false
## ⚠️ RENAMED FROM `team`. 0..3. There are no teams — this is the player's seat,
## the index into `MatchManager.scores`, and the rotation position that decides
## when they defend.
@export var player_slot: int = 0
@export_range(1, 4, 1) var player_id: int = 1

## ⚠️ REPLICATED, AND EMPTY IS A REAL VALUE. What this player calls themselves, from
## the Settings screen. Empty means "never set one", and every reader falls back to
## `display_name()` rather than printing a blank row — which is why nothing that
## draws a name has to know whether one exists.
@export var player_name: String = ""

## ⚠️⚠️ "NO HUMAN IS BEHIND THIS SEAT", AS INTENT RATHER THAN AS A NODE LOOKUP.
## Set inside `main.gd`'s `_rpc_convert_to_ai` / `_rpc_reclaim_character`, which are
## `@rpc("authority", "call_local")` and therefore run on EVERY peer — unlike the
## `AIController` those functions attach, which is guarded by `NetworkManager.is_host()`
## and so exists on exactly one machine.
##
## That difference is the whole reason this exists: `display_name()` needs an answer
## that is the same on the host, on every client and on a spectator, and
## `is_ai_driven()` is only ever true on the host in a networked match.
@export var is_bot: bool = false

## The name to actually draw. One function, so the scoreboard, the 3D nameplate, the
## YOU card and every toast cannot disagree about what an unnamed player is called.
##
## ⚠️⚠️ A BOT IS CALLED BY ITS CHARACTER, NOT "P2" — 🧑 2026-08-02: *"give the bots
## names, not just p1 p2, give them the names of their characters ... KIND OF LIKE
## L4D2!"*. A seat driven by AI reads BEBANG or JUN-JUN off the roster; a seat with a
## human behind it keeps that human's own name, exactly as before.
##
## ⚠️⚠️ AND IT IS DERIVED EVERY CALL RATHER THAN WRITTEN AT THE SWITCH. This is the
## whole reason the fix is four lines instead of a patch in every handover path. 🧑
## flagged it: *"make sure that when human switches to bot or smth the name doesnt bug
## as there are many ways for human and bot to switch (tab, singleplayer and when
## someone disconnects reconnects in multiplayer)"*. There are at least four:
## `_fill_empty_slots_with_placeholders`, `_rpc_convert_to_ai` on a disconnect,
## `_rpc_reclaim_character` on a rejoin, and the Tab switcher. Storing a name at each
## of those is four places to forget — and the forgetting is silent, leaving a bot
## wearing the name of the human who just quit.
##
## `is_ai_driven()` is the same live condition `main.gd` gates input on, and every
## drawer of this name polls rather than caching (`character_nameplate.gd` rebuilds
## its label each update for the role glyph already), so a handover in either
## direction is reflected on the next frame with no notification of any kind.
##
## ⚠️ `player_name` IS DELIBERATELY NOT CLEARED WHEN A SEAT CONVERTS TO AI. It is
## replicated state belonging to the human who may rejoin into it, and this function
## simply stops consulting it while a bot is driving — so a reclaim restores the right
## name without having to have preserved it anywhere special.
## ⚠️⚠️ A HUMAN'S NAME IS UNTOUCHED BY ALL OF THIS, AND THE FIRST VERSION GOT IT
## WRONG — 🧑 2026-08-02: *"make sure human's name doesnt change too"*. That version
## fell an unnamed human through to the character name as well, which was wrong twice:
## it made a human indistinguishable from a bot, and it was not even STABLE, because
## `character_index` is assigned in five places (`_rpc_reclaim_character` and the
## late-join table among them) so the label could move under a player mid-match. The
## seat number cannot move. Humans read exactly what they read before this feature.
## ⚠️ NAMES ARE NOT TRUNCATED HERE. 🧑 2026-08-02: *"lets not truncate the names /
## lets js put a limit to how long names can be"*. The limit is a RULE ON THE DATA
## (`CharacterRoster.NAME_MAX`, asserted by `tools/bot_name_probe.tscn`), not a haircut
## at draw time — a clipped "LOLA PACIN…" on the card would be the layout bug wearing
## a disguise, and it would be found by a player instead of by the probe.
##
## ⚠️⚠️ IT ASKS `is_bot` FIRST, AND ON A CLIENT THAT IS THE ONLY THING THAT WORKS.
## 🧑 2026-08-02: *"make sure multiplayer names work too"* / *"make sure everyone
## including spectator sees names"*. The first version asked `is_ai_driven()` alone,
## which is `ai_controller != null` — and `main.gd` attaches that controller behind
## `if NetworkManager.is_host()`, in BOTH `_rpc_convert_to_ai` and
## `_build_networked_character`. So on every peer that is not the host the node is
## null, the seat did not look AI-driven, and the row fell back to `player_name`: a bot
## wearing the name of the human who disconnected, on all the other screens, including
## a spectator's. Exactly the bug the derivation was supposed to make impossible,
## reintroduced by deriving from a mechanism instead of from intent.
##
## `is_bot` is that intent, and it is set inside the RPCs themselves — which are
## `call_local` and therefore run on every peer — so all four screens agree without
## depending on the synchroniser or on who owns the node.
##
## `is_ai_driven()` is still consulted because Single Player never goes through those
## RPCs: it attaches a controller per seat directly, and `debug_player_switcher.gd`
## flips `set_enabled()` on Tab without touching `is_bot`. Either being true means "no
## human is driving this", which is the question being asked.
## ⚠️⚠️ UPPERCASED HERE, ONCE, FOR EVERY NAME THE GAME DRAWS. 🧑 2026-08-02, with a
## screenshot of the scoreboard: *"can u make all names in the same case no matter
## what"*. A typed name arrives in whatever case the player used, and it sat in a
## column beside MARING and LOLA PACING — which are uppercase because the roster is
## authored that way, not because anything enforced it. One mixed-case row in a column
## of shouted ones reads as a rendering fault.
##
## ⚠️ IT IS A DISPLAY TRANSFORM, NOT A WRITE. `player_name` keeps the case the player
## typed, so the settings field still shows them their own name as they entered it and
## nothing about the stored or replicated value changes. This is the same reason the
## length limit is a rule on the data rather than a clamp here: the two decisions are
## deliberately opposite, because case is cosmetic and length is structural.
##
## ⚠️ `to_upper()` IS UNICODE-AWARE IN GODOT, so a name in any script this font can
## render either uppercases correctly or is left alone, rather than being mangled.
func display_name() -> String:
	if is_bot or is_ai_driven():
		return _character_name().to_upper()
	if player_name != "":
		return player_name.to_upper()
	return "P%d" % [player_slot + 1]

## The roster pick's name, falling back to the seat number. `character_index` is -1
## until a pick arrives (an AI seat on a peer that has not received one yet), and
## `name_at()` answers "?" for that, which is not a name to put over somebody's head.
func _character_name() -> String:
	if character_index < 0 or character_index >= CharacterRoster.size():
		return "P%d" % [player_slot + 1]
	return CharacterRoster.name_at(character_index)

## Roster pick, for the model and the traits. -1 until a pick arrives.
##
## ⚠️⚠️ THIS IS A PLAIN VAR AND A SETTER THAT REPAINTED THE MODEL WAS TRIED HERE AND
## WITHDRAWN, 2026-08-03. Recorded rather than deleted, because it is the obvious fix for
## a REAL open defect and the next person to reach for it should see the measurement
## first.
##
## THE DEFECT IT WAS AIMED AT IS GENUINE. `CharacterVisual.apply()` is the only thing that
## instances a model, and it runs from exactly three places: this node's `_ready()`, a
## role rotation, and the two `main.gd` helpers that call it by hand (`_apply_known_picks`,
## `_refresh_ai_prop_picks`). `main.gd::_apply_reclaimed_picks` is NOT one of them, so when
## a mid-match joiner takes a bot's seat, every peer that did not reload the scene keeps
## the bot's face under the human's number. Measured on `tools/net/run_rejoin.ps1
## -Scenario latecomer`, on the anchor, twice:
##
##     PICK <peer> slot=1 char=11/ALING NENA model=character-female-a.glb mat=person_inday.tres
##
## THE SETTER FIXED THAT AND BROKE SOMETHING WORSE. Repainting on every write makes
## `apply()` fire at an arbitrary moment mid-round, and `apply()` REMOVES AND FREES every
## child of `Visual` — which is where a carried tsinelas lives, reparented onto
## `Skeleton3D/HandAttachment/HandPoint` by `slipper.gd::_attach_to_hand()`. The two
## existing callers are safe only because both fire at a round boundary, when no hand is
## full. Measured, five runs of the latecomer scenario, and it is not run-to-run noise:
##
##     setter absent   3/3 PASS   the newcomer's own peer saw s0(owner=1 state=1 carrier=me)
##     setter present  0/2 PASS   it saw s0(owner=-1 state=0 carrier=<null>) and could
##                                neither pick up nor throw, while the HOST still had the
##                                slipper owned and carried
##
## So the seat's slipper was destroyed on the one peer that rebuilt the model. A repaint
## on reclaim has to detach the hand first, or run at a boundary — it cannot simply hang
## off this write.
##
## ⚠️⚠️ THE SETTER IS BACK, 2026-08-05, AND IT TAKES THE SECOND OF THE TWO OPTIONS THAT
## NOTE ITSELF PRESCRIBES: *"or run at a boundary"*. It repaints ONLY when this unit's
## hand is empty, and defers to `reset_for_new_round()` when it is not — so the measured
## failure above (repaint frees `Visual`'s children, and a carried tsinelas is one of
## them) is unreachable by construction rather than by luck of the caller.
##
## It is needed because REPLICATION writes this property with no repaint at all, and that
## is the whole of the skin bug: measured on two headless peers in the same match, the
## host drawing the roster models and the client drawing `PERSON_MODELS`' -1 fallback off
## an IDENTICAL `character_index`. Every previous fix verified the number and never looked
## at the mesh. `main.gd`'s hand-written `apply()` calls stay exactly as they are — this
## only closes the path none of them cover, which is the synchroniser's own silent write.
var character_index: int = -1:
	set(value):
		if character_index == value:
			return
		character_index = value
		_repaint_for_pick()

## True while this unit's roster pick changed at a moment it was not safe to rebuild the
## model. Flushed at the next round boundary — see `character_index`'s own note.
var _pick_repaint_pending: bool = false

## Rebuilds the model for a changed roster pick, but ONLY when doing so cannot destroy a
## carried tsinelas. `CharacterVisual.apply()` removes and frees every child of `Visual`,
## and `slipper.gd::_attach_to_hand()` reparents a carried slipper under this unit's
## `Skeleton3D`, so a repaint with a full hand deletes the slipper on this peer only.
func _repaint_for_pick() -> void:
	# Before `_ready()` — the `@onready` `_visual` does not exist yet, and `_ready()`'s own
	# `apply()` will use whatever value we have settled on by then.
	if _visual == null or not is_instance_valid(_visual):
		return
	var carrier := get_node_or_null("Carrier") as Carrier
	if carrier != null and carrier.held() != null:
		_pick_repaint_pending = true
		return
	_pick_repaint_pending = false
	_visual.apply(is_person, is_can, player_slot)

signal state_changed(new_state: State)

## Where this player starts the round, and where a tag sends them back to. Always
## in the Safe Zone; `main.gd` owns choosing it.
var spawn_position: Vector3 = Vector3.ZERO

## ⚠️ THE SETTER IS LOAD-BEARING AND WAS ADDED TO FIX A REAL BUG. `state` is
## replicated, and a `MultiplayerSynchronizer` writes a property DIRECTLY — so
## without this, `state_changed` never fired on a peer that RECEIVED a state, and
## every listener downstream (audio, nameplate, HUD) was silently host-only.
var state: State = State.NORMAL:
	set(value):
		if value == state:
			return
		state = value
		state_changed.emit(state)

var _staggered_time_left: float = 0.0
var _downed_time_left: float = 0.0
var _speed_multiplier: float = 1.0
var _active_speed_multipliers: Array[float] = []

var _stamina: float = STAMINA_MAX
var _stamina_idle: float = 0.0
var _is_sprinting: bool = false
var _fatigue_left: float = 0.0

var _shove_charge: float = 0.0
var _shove_charging: bool = false
var _shove_cooldown_left: float = 0.0
## Mirror of another peer's shove wind-up, so the tell is visible to the person
## about to be shoved and not only to the shover. Same defect the predecessor
## found with its charge wind-up: an action animated only on the presser's own
## machine is an action with no counterplay.
var _observed_shove_charge: float = -1.0

## The lunge. `_lunge_active_left` is what makes the tag land — see `_step_lunge`.
var _lunge_charge: float = 0.0
var _lunge_charging: bool = false
var _lunge_cooldown_left: float = 0.0
## The taya's quick jab. See § THE PUNCH.
var _punch_cooldown_left: float = 0.0
var _lunge_active_left: float = 0.0
## Mirrored to every peer so the wind-up is visible to the attacker about to be
## lunged at, for the same reason `_observed_shove_charge` exists: a commitment
## nobody else can see is a commitment nobody can dodge.
var _observed_lunge_charge: float = -1.0

var _was_airborne: bool = false
var _fall_speed: float = 0.0
var _audio_prev_state: State = State.NORMAL

## The slipper in this player's hand, or null. Written only by `slipper.gd`
## through `notify_holding()`, so there is one owner of the relationship.
var _held_slipper: Slipper = null

@onready var _visual: CharacterVisual = $Visual
@onready var _camera_rig: CameraRig = get_node_or_null("CameraRig")
@onready var _carrier: Carrier = get_node_or_null("Carrier")

var ai_controller: AIController = null

## ---------------------------------------------------------------------------
## TRAITS. Kept: they are the character-select screen's whole payload, they are
## ±5–7% each, and removing them would have broken a screen that works.
## ---------------------------------------------------------------------------
const TRAIT_SPEED_PER_POINT: float = 0.05
const TRAIT_POWER_PER_POINT: float = 0.07
const TRAIT_GRIT_PER_POINT: float = 0.07

func trait_points(key: StringName) -> int:
	return CharacterRoster.person_trait(character_index, key)

## ⚠️ ALL THREE ROUTE THROUGH `CharacterRoster.trait_scale()` SINCE 2026-08-01, and
## so do `slipper.gd`'s and `lata.gd`'s. §2.8 made the two prop tabs live, which
## meant a second and third copy of `1.0 + (points - 3) * per_point` — three
## implementations of one rule is how "neutral is exactly 1.0" stops being true on
## one of them. The per-point constants stay HERE because which one applies is a
## property of the stat, not of the conversion.
func trait_speed_scale() -> float:
	return CharacterRoster.trait_scale(trait_points(&"bilis"), TRAIT_SPEED_PER_POINT)

func trait_power_scale() -> float:
	return CharacterRoster.trait_scale(trait_points(&"lakas"), TRAIT_POWER_PER_POINT)

func trait_grit_scale() -> float:
	return maxf(0.1, CharacterRoster.trait_scale(trait_points(&"tatag"), TRAIT_GRIT_PER_POINT))

func _is_mouse_aimed() -> bool:
	return _camera_rig != null and _camera_rig.aim_source == CameraRig.AimSource.MOUSE

## ---------------------------------------------------------------------------
## ROLE QUERIES — the vocabulary every other file asks in.
## ---------------------------------------------------------------------------

## True while this player can take an action at all: round live, not stunned.
func can_act() -> bool:
	return RoundManager.round_active and state == State.NORMAL

func is_attacker() -> bool:
	return not is_defender

func holding_slipper() -> bool:
	return _held_slipper != null and is_instance_valid(_held_slipper)

func held_slipper() -> Slipper:
	return _held_slipper if holding_slipper() else null

## Called by `slipper.gd` on both halves of the relationship. Pass null to clear.
## ⚠️ FORWARDS TO THE `Carrier` COMPONENT rather than letting the slipper tell both
## of them. Two writers of the same relationship is how it ends up half-cleared:
## a hand that still thinks it is full while the slipper is already in the air.
func notify_holding(what: Slipper) -> void:
	_held_slipper = what
	if _carrier != null:
		_carrier.notify_holding(what)

## ⚠️ THE BOX TEST IS A SQUARE AND IT HAS TO MATCH `_move_and_confine()`. Both are
## `max(|x|, |z|)` against the same number; if one of them ever becomes a radial
## test the throw line and the chalk stop agreeing and nobody will be able to see
## why. That is not hypothetical — it happened on 2026-07-29 and cost a session.
func is_inside_box() -> bool:
	return maxf(absf(global_position.x), absf(global_position.z)) < confinement_radius

## `Design.md` §Attacker: an Attacker is 100% safe inside the box *until* they pick
## their slipper up. This one function is the entire vulnerability rule, and
## `RoundManager._step_tag()` and the HUD's `VULNERABLE` row both read it — so the
## warning the player sees cannot disagree with the rule that tags them.
func is_taggable() -> bool:
	if is_defender or not can_act():
		return false
	if not holding_slipper():
		return false
	return is_inside_box()

## A slipper in flight stops on any standing body. Deliberately includes the
## Attackers: three of them crowding the box means friendly fire is part of the
## traffic, and a slipper that passes through teammates would make the Defender's
## body block the only block in the game.
func can_be_hit_by_slipper() -> bool:
	return state != State.DOWNED

## ⚠️ CONFINEMENT IS THE DEFENDER'S BOX, AND IT IS THIS ONE LINE. The Defender
## cannot leave; everyone else moves freely and the box is merely dangerous to
## them. The predecessor confined "the lata, and the Person on the can side",
## which is the same expression with the lata deleted.
func _is_confined_to_base() -> bool:
	return RoundManager.round_active and is_defender

## ---------------------------------------------------------------------------
## ⚠️ SPAWN SETTLE — DO NOT REMOVE. This is the real fix for B-100, and role
## rotation is exactly what triggers it.
##
## Writing `position` on a PhysicsBody3D updates the SCENE TREE at once and the
## physics BROADPHASE only at the next server step. Roles rotate every round, so
## players trade marks — and for one physics frame each is standing on the OTHER
## one's stale collider. Measured: the incoming player is placed correctly, then
## `move_and_slide()` reports three contacts with the outgoing one (normal 0,1,0 —
## stacked on its head), shoves it 1.60 up, and the next frame slides it 9.89
## units into a wall.
##
## Neither `force_update_transform()` nor `PhysicsServer3D.body_set_state()` fixes
## it, and "park everyone at y=500 first" could not either — all three are writes
## the broadphase does not see until it steps. So nobody MOVES until it has.
## Three frames is 50 ms and is invisible.
## ---------------------------------------------------------------------------
const SPAWN_SETTLE_FRAMES: int = 3
var _spawn_settle: int = 0
var _spawn_settle_at: Transform3D = Transform3D.IDENTITY

func begin_spawn_settle() -> void:
	_spawn_settle = SPAWN_SETTLE_FRAMES
	_spawn_settle_at = global_transform
	velocity = Vector3.ZERO

## ⚠️⚠️ YOU CANNOT STAND ON SOMEBODY'S HEAD. Every unit is on collision layer 1
## with the world and with each other, so one capsule resting on another is a
## perfectly legal floor as far as `CharacterBody3D` is concerned — `is_on_floor()`
## goes true in mid-air, gravity is never applied, and the player hovers with full
## walking control.
##
## ⚠️ THE FIX IS A NUDGE, NOT A COLLISION-LAYER CHANGE. Turning
## character-vs-character collision off would take the BODY BLOCK with it, and the
## Defender standing in the throwing lane is a real mechanic. So only a contact
## steep enough to be a *perch* is answered.
const PERCH_NORMAL_MIN: float = 0.7
const PERCH_SHED_SPEED: float = 2.5
var _perched_on_character: bool = false

func _move_and_confine() -> void:
	move_and_slide()
	_shed_character_perch()
	if not _is_confined_to_base():
		return
	global_position.x = clampf(global_position.x, -confinement_radius, confinement_radius)
	global_position.z = clampf(global_position.z, -confinement_radius, confinement_radius)

func _shed_character_perch() -> void:
	_perched_on_character = false
	if not is_on_floor():
		return
	for i in get_slide_collision_count():
		var contact := get_slide_collision(i)
		var other := contact.get_collider() as CharacterBase
		if other == null or other == self:
			continue
		if contact.get_normal().y <= PERCH_NORMAL_MIN:
			continue # a side contact — that is the body block, and it stays
		_perched_on_character = true
		var away := global_position - other.global_position
		away.y = 0.0
		if away.length() < 0.01:
			away = other.global_transform.basis.x
		away = away.normalized()
		velocity.x += away.x * PERCH_SHED_SPEED
		velocity.z += away.z * PERCH_SHED_SPEED
		return

func _ready() -> void:
	spawn_position = global_position
	_visual.apply(is_person, is_can, player_slot)
	state_changed.connect(_on_state_changed_audio)

## ---------------------------------------------------------------------------
## THE FRAME.
## ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	# ⚠️ BEFORE THE SETTLE GATE AND BEFORE THE AUTHORITY GATE, DELIBERATELY. Both
	# of those `return` early, and a hitstop left running because every live unit
	# happened to be settling or remote is the same engine-wide 5% speed the fix
	# below exists to prevent (§6 trap 7 is the same shape: a gate that silently
	# breaks everything downstream of it).
	_step_hitstop()
	if _spawn_settle > 0:
		_spawn_settle -= 1
		global_transform = _spawn_settle_at
		velocity = Vector3.ZERO
		return
	if ai_controller != null:
		ai_controller.decide(delta)

	# Cooldowns tick on every peer so the HUD row is honest on a client too.
	if _shove_cooldown_left > 0.0:
		_shove_cooldown_left = maxf(0.0, _shove_cooldown_left - delta)
	if _observed_shove_charge >= 0.0:
		_observed_shove_charge = minf(_observed_shove_charge + delta, SHOVE_CHARGE_TIME)
	if _lunge_cooldown_left > 0.0:
		_lunge_cooldown_left = maxf(0.0, _lunge_cooldown_left - delta)
	if _punch_cooldown_left > 0.0:
		_punch_cooldown_left = maxf(0.0, _punch_cooldown_left - delta)
	if _observed_lunge_charge >= 0.0:
		_observed_lunge_charge = minf(_observed_lunge_charge + delta, LUNGE_CHARGE_TIME)
	if _fatigue_left > 0.0:
		_fatigue_left = maxf(0.0, _fatigue_left - delta)
		if _fatigue_left == 0.0:
			exit_speed_zone(FATIGUE_SPEED_SCALE)

	if NetworkManager.is_networked() and not is_multiplayer_authority():
		return

	var grounded := is_on_floor() and not _perched_on_character
	if grounded and _was_airborne and _fall_speed > LAND_SFX_MIN_SPEED:
		AudioManager.play_at("land", global_position)
	_was_airborne = not grounded
	if not grounded:
		velocity.y -= GRAVITY * delta
		velocity.y = maxf(velocity.y, -MAX_FALL_SPEED)
	_fall_speed = -velocity.y

	# Between rounds: gravity still applies (so nobody is left hovering after an
	# intermission), but nothing else does.
	if not RoundManager.round_active and MatchManager.round_number > 0:
		velocity.x = 0.0
		velocity.z = 0.0
		if is_on_floor():
			velocity.y = 0.0
			return
		_move_and_confine()
		return

	if state == State.NORMAL and is_on_floor() and input_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		AudioManager.play_at("jump", global_position)

	if _carrier != null and state == State.NORMAL:
		_carrier.input_step(delta)
	if state == State.NORMAL:
		_step_shove(delta)
		_step_punch(delta)
		_step_lunge(delta)

	match state:
		State.STAGGERED:
			_staggered_time_left -= delta
			if _staggered_time_left <= 0.0:
				state = State.NORMAL
		State.DOWNED:
			_downed_time_left -= delta
			if _downed_time_left <= 0.0:
				state = State.NORMAL
		State.NORMAL:
			pass

	if state != State.NORMAL:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
		_move_and_confine()
		return

	var input_dir := input_vector("move_left", "move_right", "move_up", "move_down")
	var mouse_aimed := _is_mouse_aimed()
	var direction: Vector3
	if mouse_aimed:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
		direction.y = 0.0
		direction = direction.normalized()
	else:
		direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	var sprint_scale := _step_stamina(delta, direction != Vector3.ZERO)
	if direction:
		var speed_now := SPEED * _role_speed_scale() * _speed_multiplier \
			* trait_speed_scale() * sprint_scale
		velocity.x = direction.x * speed_now
		velocity.z = direction.z * speed_now
		if not mouse_aimed:
			look_at(global_position + direction, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)

	_move_and_confine()
	if ai_controller != null:
		ai_commit_intent_frame()

## ---------------------------------------------------------------------------
## STAMINA AND FATIGUE.
## ---------------------------------------------------------------------------

## 1.0 for the taya, `ATTACKER_SPEED_SCALE` for everyone else. Read off `is_defender`
## every frame rather than cached, because the role rotates at a round boundary and a
## cached copy is one more thing that can be stale on a client.
func _role_speed_scale() -> float:
	return 1.0 if is_defender else ATTACKER_SPEED_SCALE

func _step_stamina(delta: float, moving: bool) -> float:
	if _fatigue_left > 0.0:
		# Sprint is locked out for the whole fatigue window. The speed penalty
		# itself rides the speed-zone stack rather than being multiplied in here,
		# so it composes with a hazard zone instead of one silently winning.
		_is_sprinting = false
		_stamina_idle += delta
		# ⚠️⚠️ NO REGEN WHILE FATIGUED — 🧑 2026-08-01: *"While fatigued, stamina
		# regeneration is completely locked until a 2-second recovery delay
		# expires."* This line used to refill the bar at full rate DURING the
		# penalty, which meant a player who ran themselves to zero was already
		# recovering while "being punished" and walked out of fatigue with a usable
		# bar. The penalty is now the thing it was described as: 2.0 s at reduced
		# speed with the bar genuinely empty, and regen begins after it expires.
		return 1.0
	var wants := moving and input_pressed("sprint")
	var may_start := _is_sprinting or _stamina >= STAMINA_SPRINT_FLOOR
	_is_sprinting = wants and may_start and _stamina > 0.0
	if _is_sprinting:
		_stamina = maxf(0.0, _stamina - STAMINA_DRAIN_RATE * delta)
		_stamina_idle = 0.0
		if _stamina <= 0.0:
			_enter_fatigue()
			return 1.0
		return SPRINT_SCALE
	_stamina_idle += delta
	if _stamina_idle >= STAMINA_REGEN_DELAY:
		_stamina = minf(STAMINA_MAX, _stamina + STAMINA_REGEN_RATE * delta)
	return 1.0

func _enter_fatigue() -> void:
	if _fatigue_left > 0.0:
		return
	_fatigue_left = FATIGUE_TIME
	_is_sprinting = false
	enter_speed_zone(FATIGUE_SPEED_SCALE)
	AudioManager.play_at("stamina_empty", global_position)

func is_fatigued() -> bool:
	return _fatigue_left > 0.0

func get_stamina_ratio() -> float:
	return _stamina / STAMINA_MAX

func spend_stamina(amount: float) -> bool:
	if _fatigue_left > 0.0 or _stamina < amount:
		return false
	_stamina -= amount
	_stamina_idle = 0.0
	if _stamina <= 0.0:
		_stamina = 0.0
		_enter_fatigue()
	return true

## ---------------------------------------------------------------------------
## THE SHOVE. `Design.md` §Attacker — hold E, release, push a neighbour.
##
## ⚠️ E IS CONTEXTUAL AND THAT IS DELIBERATE. E does three jobs: tap to pick a
## slipper up, tap to shove, hold `Lata.RESET_CHANNEL_TIME` (as Defender) to reset
## the lata. ⚠️ THIS SENTENCE DESCRIBED THE PRE-2026-08-01 GAME UNTIL §2.26 WAS
## CLOSED — it said the shove was a 1.25 s hold (it has been `SHOVE_CHARGE_TIME`
## 0.0, a single tap, since the same day this file's own §THE SHOVE header records)
## and the channel 2.5 s (it is 1.5). Rather than inventing two more keybinds for a
## game whose whole brief is
## "simpler", the press resolves against what is actually in front of you.
## `carrier.gd` gets first refusal — if there is a slipper at your feet or a lata
## to channel, the press is that. Only a press with nothing to act on charges a
## shove, which is why this runs AFTER `_carrier.input_step()`.
## ---------------------------------------------------------------------------
func _step_shove(_delta: float) -> void:
	if is_defender:
		# The Defender has the tag; giving them the shove as well would make the
		# box unenterable.
		return
	if _carrier != null and _carrier.is_busy():
		_cancel_shove()
		return
	# ⚠️⚠️ SINGLE TAP SINCE 2026-08-01 — `input_just_pressed`, NOT a hold-and-release.
	# 🧑: *"Input: Single tap of E (No charge time)."* The charge loop this replaces
	# is gone rather than parameterised to zero, because a zero-length hold still
	# needed a release frame to fire and would have made the shove cost one extra
	# frame of input latency for no design reason.
	#
	# ⚠️ `_broadcast_shove_charge(true)` STILL FIRES, and it is not vestigial. It is
	# what puts the wind-up pose on every OTHER peer (`character_visual.gd`), and the
	# spec asks for a *"Hand Shove Animation"* — the animation has to exist on the
	# machines watching it, not just on the one that pressed E. It is immediately
	# followed by the release, so the pose reads as a snap rather than a hold.
	if _shove_cooldown_left > 0.0 or not input_just_pressed("grab"):
		return
	if _stamina < SHOVE_STAMINA_COST or _fatigue_left > 0.0:
		return
	_broadcast_shove_charge(true)
	_release_shove()
	_broadcast_shove_charge(false)

## THE TAYA'S PUNCH. Tap left-click to jab; a vulnerable attacker in front is
## tagged instantly. See the § THE PUNCH constants for why it exists.
func _step_punch(_delta: float) -> void:
	if not is_defender:
		return # the attackers' left-click is the throw charge
	if _punch_cooldown_left > 0.0:
		return
	if _carrier != null and _carrier.is_busy():
		return # mid reset-channel; the press belongs to that
	if not input_just_pressed("special_ability"):
		return
	_punch_cooldown_left = PUNCH_COOLDOWN
	# Its own clip since 2026-08-01 — the arm, not the body. Broadcast so a punch is
	# visible on every machine and not only on the presser's.
	broadcast_visual_action("punch")
	AudioManager.play_at("bump_swing", global_position)
	# Host-only: a tag writes a score, and a score may only be created where
	# `MatchManager.add_score()` is reachable (`Design.md` §8).
	if not NetworkManager.is_networked() or NetworkManager.is_host():
		host_resolve_punch(player_slot, global_position, -global_transform.basis.z)
	else:
		_rpc_request_punch.rpc_id(1, global_position, -global_transform.basis.z)

## ⚠️ RESOLVED ON THE HOST BY DISTANCE, exactly like the shove, the lunge sweep and
## slipper contact. The client says where it stood and which way it faced; the host
## decides who that reached.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_punch(from: Vector3, facing: Vector3) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	host_resolve_punch(player_slot, from, facing)

func host_resolve_punch(puncher_slot: int, from: Vector3, facing: Vector3) -> void:
	if not RoundManager.round_active:
		return
	var lata := RoundManager.lata
	if lata == null or not lata.is_upright:
		return # a tag requires the can standing, same as the lunge
	var flat_facing := Vector3(facing.x, 0.0, facing.z)
	if flat_facing.length() < 0.01:
		return
	flat_facing = flat_facing.normalized()
	var taya := RoundManager.player_at(puncher_slot)
	if taya == null:
		return
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who.player_slot == puncher_slot or who.is_defender:
			continue
		# ⚠️ THE SAME `is_taggable()` THE HUD'S `VULNERABLE` ROW ASKS. `Design.md`
		# §5.2 makes that a rule: the warning a player sees and the check that
		# catches them must be one function.
		if not who.is_taggable():
			continue
		var to_them := who.global_position - from
		to_them.y = 0.0
		var distance := to_them.length()
		if distance > PUNCH_RANGE or distance < 0.01:
			continue
		if rad_to_deg(flat_facing.angle_to(to_them.normalized())) > PUNCH_ARC_DEG:
			continue
		RoundManager.host_resolve_lunge_tag(taya, who)
		return # one tag per punch

func punch_cooldown_left() -> float:
	return _punch_cooldown_left

## THE TAYA'S LUNGE. Hold E, release to dash forward and tag.
##
## ⚠️ THE SWEEP RUNS ON EVERY FRAME THE LUNGE IS LIVE, not once on release. A 2.5 m
## dash at 60 Hz moves ~0.2 m per frame at its peak, so a single end-of-dash test
## would miss an attacker standing halfway along the path — and "caught in the lunge
## path" is the rule, not "standing where the taya stopped".
func _step_lunge(delta: float) -> void:
	if not is_defender:
		# The attackers have the shove. Giving the taya both would be the mirror of
		# the mistake the shove's own guard already prevents.
		_cancel_lunge()
		return
	if _lunge_active_left > 0.0:
		_lunge_active_left = maxf(0.0, _lunge_active_left - delta)
		# Host-only: the tag writes a score, and a score may only be created where
		# `MatchManager.add_score()` can be reached — see `Design.md` §8.
		if not NetworkManager.is_networked() or NetworkManager.is_host():
			_sweep_lunge_tag()
	if _carrier != null and _carrier.is_busy():
		_cancel_lunge()
		return
	if _lunge_charging:
		if _lunge_held_now():
			_lunge_charge = minf(_lunge_charge + delta, LUNGE_CHARGE_TIME)
			return
		var power := clampf(_lunge_charge / LUNGE_CHARGE_TIME, LUNGE_MIN_POWER, 1.0)
		_cancel_lunge()
		_release_lunge(power)
		return
	if _lunge_cooldown_left > 0.0 or not _lunge_pressed_now():
		return
	if state != State.NORMAL:
		return
	_lunge_charging = true
	_lunge_charge = 0.0
	_broadcast_lunge_charge(true)

## ⚠⚠ THE LUNGE MOVED TO **HOLD E** ON 2026-08-01, ON HUMAN INSTRUCTION:
## *"Lunge Tag (Hold E for 0.5s)"*. Right-click still works and is deliberately
## kept rather than removed — `ai_controller.gd` presses `lunge` (it is
## 🤖 `build ai`'s file and this lane does not edit it), and a second binding for
## the same verb costs a human nothing.
##
## ⚠️⚠️ E IS `lunge`'S OWN BINDING NOW, NOT BORROWED FROM `grab`. It used to read
## `input_just_pressed("grab")` as well, because `grab` already owned E and adding
## a second real keybind to `lunge` felt redundant — but `grab`'s E is a SEPARATE,
## independently rebindable key, and reading it here meant `Settings > Lunge` had
## no effect on the key that actually fired the lunge: a player who rebound Lunge
## away from E could still lunge themselves forward by pressing E, because that
## press was landing on `grab`, not on `lunge`. `project.godot` now gives `lunge`
## its own `E` `InputEventKey` (alongside its right-click), so rebinding the
## `lunge` action is what changes this, exactly as the Settings row promises.
##
## ⚠️ E IS CONTEXTUAL AND THE ORDER IS WHAT MAKES IT WORK. `carrier.gd` gets first
## refusal on the press: for a DEFENDER that is the lata reset channel, which only
## engages when the can is DOWN and they are in its ring. Any other E press falls
## through to here, exactly as an attacker's falls through to the shove. And while
## the channel IS running, `_carrier.is_busy()` above cancels the charge — so
## resetting the can can never accidentally fire a lunge out of it.
func _lunge_pressed_now() -> bool:
	return input_just_pressed("lunge")


func _lunge_held_now() -> bool:
	return input_pressed("lunge")


func _cancel_lunge() -> void:
	if not _lunge_charging:
		return
	_lunge_charging = false
	_lunge_charge = 0.0
	_broadcast_lunge_charge(false)

func _release_lunge(power: float) -> void:
	_lunge_cooldown_left = LUNGE_COOLDOWN
	_lunge_active_left = LUNGE_ACTIVE_TIME
	# The body-led clip: a dash INTO somebody reads differently from a jab at them.
	broadcast_visual_action("lunge")
	AudioManager.play_at("bump_swing", global_position)
	# ⚠️ A VELOCITY IMPULSE, NOT A TELEPORT. The friction model integrates it down to
	# ~2.5 m at full power (v²/60), and the intervening frames are what the sweep
	# below reads. It is also why the taya can be body-blocked mid-lunge rather than
	# passing through geometry.
	var forward := -global_transform.basis.z
	velocity.x = forward.x * LUNGE_SPEED * power
	velocity.z = forward.z * LUNGE_SPEED * power
	# ⚠️⚠️ A JOINED CLIENT'S LUNGE HAD NO PATH TO THE HOST AT ALL, SO A NON-HOST TAYA
	# COULD NOT TAG WITH IT. Fixed 2026-08-02. The punch and the shove both send
	# `_rpc_request_punch` / `_rpc_request_shove` when this peer is not the host; the
	# lunge, added later, only ever guarded its sweep with
	# `if not is_networked() or is_host()` and had no `else`. On a client that guard
	# is false, so the sweep never ran there — and it never ran on the HOST either,
	# because `_physics_process` returns at its authority gate before `_step_lunge()`
	# for a body this peer does not own (§6 trap 7). The verb was simply dead for
	# three of the four players in every networked match.
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		_rpc_request_lunge.rpc_id(1, global_position, forward, power)

## ⚠️ RESOLVED ON THE HOST BY DISTANCE, the same contract the punch and the shove
## already keep: the client says where it stood, which way it faced and how hard it
## committed, and the host decides who that reached.
##
## ⚠️ ONE SWEPT SEGMENT RATHER THAN THE HOST REPLAYING 27 FRAMES. The host cannot
## step a body it is not the authority for, so it cannot reproduce the per-frame
## sweep the local peer runs. It tests the DASH PATH instead — from the release
## point to where the friction model lands it (`v²/FRICTION`, the same solve the
## impulse above is derived from) — against `LUNGE_TAG_RADIUS`. That is the same
## region the frame-by-frame sweep covers, decided once, and it cannot tunnel
## because a segment has no sampling rate.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_lunge(from: Vector3, facing: Vector3, power: float) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	host_resolve_lunge(player_slot, from, facing, power)

func host_resolve_lunge(taya_slot: int, from: Vector3, facing: Vector3, power: float) -> void:
	if not RoundManager.round_active:
		return
	var lata := RoundManager.lata
	if lata == null or not lata.is_upright:
		return # a tag requires the can standing, same as the punch and the sweep
	var taya := RoundManager.player_at(taya_slot)
	if taya == null or not taya.is_defender:
		return
	var flat_facing := Vector3(facing.x, 0.0, facing.z)
	if flat_facing.length() < 0.01:
		return
	flat_facing = flat_facing.normalized()
	# How far this dash actually carries, by the same `v²/FRICTION` the impulse uses.
	# ⚠️ `2.0 * FRICTION` IS THE `v²/60` EVERY IMPULSE IN THIS FILE IS DERIVED FROM,
	# written as the constant it comes from rather than as the literal 60, so moving
	# `FRICTION` moves this with it instead of silently leaving it wrong.
	var speed := LUNGE_SPEED * clampf(power, LUNGE_MIN_POWER, 1.0)
	var dash := (speed * speed) / (2.0 * FRICTION)
	var start := Vector3(from.x, 0.0, from.z)
	var end := start + flat_facing * dash
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who.player_slot == taya_slot or who.is_defender:
			continue
		if not who.is_taggable():
			continue
		var them := Vector3(who.global_position.x, 0.0, who.global_position.z)
		if Geometry3D.get_closest_point_to_segment(them, start, end).distance_to(them) \
			> LUNGE_TAG_RADIUS:
			continue
		RoundManager.host_resolve_lunge_tag(taya, who)
		return # one tag per lunge, exactly as the local sweep rules it

## Host-side. Any vulnerable attacker within `LUNGE_TAG_RADIUS` is tagged.
##
## ⚠️ IT ASKS `is_taggable()`, THE SAME FUNCTION THE HUD'S `VULNERABLE` ROW ASKS.
## `Design.md` §5.2 makes that a rule rather than a coincidence: the warning a player
## sees and the check that catches them must be one function, or the HUD can promise
## safety the tag then ignores.
func _sweep_lunge_tag() -> void:
	if not RoundManager.round_active:
		return
	var lata := RoundManager.lata
	if lata == null or not lata.is_upright:
		return # a tag requires the lata standing, exactly as the proximity tag did
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who == self or who.is_defender:
			continue
		if not who.is_taggable():
			continue
		if global_position.distance_to(who.global_position) > LUNGE_TAG_RADIUS:
			continue
		RoundManager.host_resolve_lunge_tag(self, who)
		_lunge_active_left = 0.0
		return # one tag per lunge — a dash through two attackers is not a double

func _broadcast_lunge_charge(active: bool) -> void:
	if NetworkManager.is_networked():
		_rpc_lunge_charge_visual.rpc(active)
	else:
		_rpc_lunge_charge_visual(active)

@rpc("any_peer", "call_local", "reliable")
func _rpc_lunge_charge_visual(active: bool) -> void:
	_observed_lunge_charge = 0.0 if active else -1.0

## 0..1 while a lunge is being charged anywhere, -1.0 at rest. Read by the HUD and
## by `character_visual.gd`, the same contract `observed_shove_charge()` keeps.
func observed_lunge_charge() -> float:
	if _lunge_charging:
		return clampf(_lunge_charge / LUNGE_CHARGE_TIME, 0.0, 1.0)
	if _observed_lunge_charge < 0.0:
		return -1.0
	return clampf(_observed_lunge_charge / LUNGE_CHARGE_TIME, 0.0, 1.0)

func lunge_cooldown_left() -> float:
	return _lunge_cooldown_left

func _cancel_shove() -> void:
	if not _shove_charging:
		return
	_shove_charging = false
	_shove_charge = 0.0
	_broadcast_shove_charge(false)

## ⚠️⚠️ A MISS COSTS A SHORT COOLDOWN, A HIT COSTS THE FULL ONE. 2026-08-01, on
## human instruction — first *"Shove should only enter cooldown when it
## successfully hits"*, then revised: *"it should enter cooldown even if it doesnt
## hit anyone, just a shorter one"*.
##
## The old rule punished the ATTEMPT, and the attempt is the hard part: the shove
## reaches 1.6 m inside a 70° arc at a target who is also running, so a 7.5 s
## lockout on a whiff meant the honest answer was never to press it. Measured
## consequence: **0 sabotages in every whole-match run taken on 2026-08-01**
## (`ai_probe` × 3 tiers, `fair_probe` × 3 policies) — a mechanic that never fires.
## A free miss over-corrected the other way, so the miss has its own price.
##
## ⚠️ THE SHORT ONE IS SET LOCALLY AND IMMEDIATELY; the full one arrives from the
## host, because ONLY THE HOST KNOWS IF IT CONNECTED. A client that started the
## full cooldown on its own swing would be guessing, and guessing in the direction
## that costs the player.
##
## ⚠️ AND THE STAMINA IS STILL SPENT EITHER WAY, which is the real bound: 25 of 60
## means two swings before there is nothing left to escape the box with (§2.4 — the
## shove's real price is the sprint, not the seconds).
func _release_shove() -> void:
	if not spend_stamina(SHOVE_STAMINA_COST):
		return
	_shove_cooldown_left = SHOVE_MISS_COOLDOWN
	broadcast_visual_action("shove")
	AudioManager.play_at("bump_swing", global_position)
	if not NetworkManager.is_networked() or NetworkManager.is_host():
		host_resolve_shove(player_slot, global_position, -global_transform.basis.z)
	else:
		_rpc_request_shove.rpc_id(1, global_position, -global_transform.basis.z)

## Host -> the shover. Called only when a shove actually landed on somebody.
func host_start_shove_cooldown() -> void:
	RoundManager.host_broadcast_shove_cooldown(player_slot)

## Called on EVERY peer by `RoundManager` — see the note on `host_apply_tag_penalty`.
func apply_shove_cooldown_local() -> void:
	_apply_shove_cooldown()

## ⚠️ `maxf`, NOT AN ASSIGNMENT. The miss cooldown is already running by the time
## this arrives, and on a client it arrives a round-trip late — so a plain write
## would SHORTEN a cooldown that had already started ticking down, handing the
## shover time back for having connected.
func _apply_shove_cooldown() -> void:
	_shove_cooldown_left = maxf(_shove_cooldown_left, SHOVE_COOLDOWN)

## ⚠️ RESOLVED ON THE HOST BY DISTANCE, like the tag and like slipper contact. The
## client sends where it was and which way it faced; the host decides who that
## reaches. A client that lies about its position can only lie about a 1 m push.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_shove(from: Vector3, facing: Vector3) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	host_resolve_shove(player_slot, from, facing)

func host_resolve_shove(shover_slot: int, from: Vector3, facing: Vector3) -> void:
	var flat_facing := Vector3(facing.x, 0.0, facing.z)
	if flat_facing.length() < 0.01:
		return
	flat_facing = flat_facing.normalized()
	var connected := false
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who.player_slot == shover_slot or who.is_defender:
			continue # Attackers shove Attackers. The Defender is not shovable.
		if who.state != State.NORMAL:
			continue
		var to_them := who.global_position - from
		to_them.y = 0.0
		var distance := to_them.length()
		if distance > SHOVE_RANGE or distance < 0.01:
			continue
		if rad_to_deg(flat_facing.angle_to(to_them.normalized())) > SHOVE_ARC_DEG:
			continue
		var impulse := to_them.normalized() * SHOVE_SPEED * trait_power_scale() \
			+ Vector3.UP * SHOVE_LIFT
		who.host_apply_shove(impulse, SHOVE_STUN, shover_slot)
		connected = true
	# ⚠️ ONLY A CONNECT COSTS THE COOLDOWN — see `_release_shove()`. Sent to the
	# SHOVER, who may be a client and cannot know this for itself.
	if connected:
		var shover := RoundManager.player_at(shover_slot)
		if shover != null:
			shover.host_start_shove_cooldown()

func host_apply_shove(impulse: Vector3, stun: float, from_slot: int) -> void:
	# Recorded BEFORE the stun, so a shove that leads straight into a tag still
	# pays the shover even if the tag lands on the very next frame.
	RoundManager.note_shove(player_slot, from_slot)
	RoundManager.host_broadcast_shove(player_slot, impulse, stun)

## Called on EVERY peer by `RoundManager` — see the note on `host_apply_tag_penalty`.
func apply_shove_local(impulse: Vector3, stun: float) -> void:
	_apply_shove(impulse, stun)

func _apply_shove(impulse: Vector3, stun: float) -> void:
	apply_knockback(impulse)
	apply_stagger(stun)
	_flash_hit("hit_body")

func _broadcast_shove_charge(active: bool) -> void:
	if NetworkManager.is_networked():
		_rpc_shove_charge_visual.rpc(active)
	else:
		_rpc_shove_charge_visual(active)

@rpc("any_peer", "call_local", "reliable")
func _rpc_shove_charge_visual(active: bool) -> void:
	_observed_shove_charge = 0.0 if active else -1.0
	play_visual_action("charge" if active else "shove")

func shove_cooldown_left() -> float:
	return _shove_cooldown_left

## -1 when not charging. Drives the local player's own meter.
func shove_charge_ratio() -> float:
	if not _shove_charging:
		return -1.0
	return clampf(_shove_charge / SHOVE_CHARGE_TIME, 0.0, 1.0)

## -1 when nobody nearby is winding up. Drives the TELL another player sees.
func observed_shove_charge() -> float:
	if _observed_shove_charge < 0.0:
		return -1.0
	return clampf(_observed_shove_charge / SHOVE_CHARGE_TIME, 0.0, 1.0)

## ---------------------------------------------------------------------------
## THE BODY BLOCK'S RECEIVING END. Called host-side by `slipper.gd` when this body
## stops a thrown slipper. §2.11 / §2.22.
##
## ⚠️ IT IS A PUSH AND A FLASH, DELIBERATELY NOT `_flash_hit()`. That helper also
## fires `_hitstop()`, which writes `Engine.time_scale` globally for 60 ms — fine
## for a shove on a 7.5 s cooldown, wrong for a block, because three attackers
## throwing at one box can produce blocks a few frames apart and the game would
## stutter for the whole round. The sound is already played by the caller at the
## contact point, so playing one here as well would double it.
##
## ⚠️ AND IT IS NOT A STAGGER. See `Slipper.BLOCK_KNOCKBACK_SPEED` for why costing
## the taya POSITION is bounded and costing them AGENCY is not.
## ---------------------------------------------------------------------------
func host_apply_block(impulse: Vector3) -> void:
	RoundManager.host_broadcast_block(player_slot, impulse)

## Called on EVERY peer by `RoundManager` — see the note on `host_apply_tag_penalty`.
func apply_block_local(impulse: Vector3) -> void:
	_apply_block(impulse)

func _apply_block(impulse: Vector3) -> void:
	apply_knockback(impulse)
	_visual.flash_hit()
	# The blocker's own camera, and only theirs — a block is a thing that happened
	# TO you, and the shake is what makes a stopped throw feel stopped.
	var is_mine := (is_multiplayer_authority() and ai_controller == null) \
		if NetworkManager.is_networked() else player_id == 1
	if is_mine and _camera_rig != null:
		_camera_rig.shake()

## ---------------------------------------------------------------------------
## THE TAG PENALTY. Called host-side by `RoundManager._resolve_tag()`.
## ---------------------------------------------------------------------------

## ⚠⚠ BROADCAST THROUGH `RoundManager`, NOT FROM THIS NODE. A player's character
## is authoritative on THEIR OWN PEER (`main.gd`: `set_multiplayer_authority(peer_id)`),
## so an `@rpc("authority")` declared here may only be called BY THE VICTIM — and
## the host was calling it. See `round_manager.gd`'s § THE MULTIPLAYER SOFTLOCK
## for the full post-mortem; the short version is that `call_local` made the host
## apply the change to its own copy while the peer that actually drives that body
## did not, and the synchronizer then argued about it for ever.
func host_apply_tag_penalty(stun: float) -> void:
	RoundManager.host_broadcast_tag_penalty(player_slot, stun, spawn_position)

## Called on EVERY peer by `RoundManager`. Public because the caller is another
## file; the leading verb says it is already-decided rather than a request.
func apply_tag_penalty_local(stun: float, safe_spot: Vector3) -> void:
	_apply_tag_penalty(stun, safe_spot)

## ⚠️⚠️ REVERSED 2026-08-01: THE SLIPPER NOW COMES WITH THEM, AND IT IS AN
## ANTI-CAMPING RULE. This function used to drop the slipper where the tag landed,
## on the reasoning that "the retrieval run has to be made again". 🧑 replaced it:
## *"The Attacker spawns with their slipper already back in hand (eliminates Danger
## Zone slipper camping)."*
##
## The old rule had a failure mode that got worse the better the taya was: every tag
## left one more slipper lying inside the box, so a taya who tagged well accumulated
## a pile of them on their own mark and could simply stand over it. The attackers
## then had to enter a box carpeted with their own equipment, which is the opposite
## of the tension the retrieval is supposed to create. Sending the slipper home with
## its owner keeps the penalty (5 s stunned, and the whole trip to make again) and
## deletes the camping.
##
## ⚠️ THE PENALTY IS STILL REAL, and it is worth being explicit about what remains:
## the attacker loses their position, 5 seconds, and the throw they were about to
## make. What they no longer lose is the ability to try again without first solving
## a pile of slippers under the taya's feet.
## ⚠️⚠️ A TAG CLEANSES, 2026-08-01, ON HUMAN INSTRUCTION: *"ensure the attacker is
## reset to 100% full stamina and has their Fatigued state cleared upon respawning
## in the Safe Zone."*
##
## The reason it matters is compounding. The moment an attacker is most likely to
## be tagged is the moment they are most likely to be EMPTY — they sprinted in,
## grabbed, and were caught on the way out — so the old behaviour handed them a
## 5 s stun AND a spent bar AND, half the time, an active fatigue lockout that
## started ticking again the instant the stun ended. Three punishments stacked on
## one mistake, and the two invisible ones outlasted the one the HUD showed.
##
## The penalty that remains is the one `Design.md` §6 describes and the one worth
## having: the safe-zone teleport, 5 seconds, and the whole trip to make again.
func _apply_tag_penalty(stun: float, safe_spot: Vector3) -> void:
	global_position = safe_spot
	velocity = Vector3.ZERO
	begin_spawn_settle()
	snap_visual_interpolation()
	apply_stagger(stun)
	# ⚠️ `exit_speed_zone` BEFORE zeroing `_fatigue_left`, or the 0.75 multiplier is
	# orphaned on the speed-zone stack for the rest of the round — `_step_stamina()`
	# only pops it on the frame the timer reaches zero, and that frame will not come.
	if _fatigue_left > 0.0:
		_fatigue_left = 0.0
		exit_speed_zone(FATIGUE_SPEED_SCALE)
	_stamina = STAMINA_MAX
	_stamina_idle = 0.0
	_is_sprinting = false
	AudioManager.play_at("tag", global_position)

## ---------------------------------------------------------------------------
## DAMAGE AND STATE.
## ---------------------------------------------------------------------------

func apply_stagger(duration: float = BASE_STAGGER_TIME) -> void:
	if state == State.DOWNED:
		return
	# ⚠️ `max`, NOT `+`. Two stuns overlap, they do not stack — there is no
	# additive path anywhere in the game and that is what bounds a stun chain.
	# ⚠️ ITS KNOWN COST: a short stun landing inside a longer one is INVISIBLE, so
	# a 1.25 s shove inside the 5 s tag penalty reads as nothing happening. Filed
	# to the backlog rather than fixed here, because fixing it means a status
	# stack that can show two rows for the same effect.
	_staggered_time_left = maxf(_staggered_time_left, duration / trait_grit_scale())
	state = State.STAGGERED

func go_downed(duration: float = 1.0) -> void:
	_downed_time_left = duration
	_cancel_shove()
	state = State.DOWNED

func enter_speed_zone(multiplier: float) -> void:
	_active_speed_multipliers.append(multiplier)
	_recompute_speed_multiplier()

func exit_speed_zone(multiplier: float) -> void:
	var idx := _active_speed_multipliers.find(multiplier)
	if idx != -1:
		_active_speed_multipliers.remove_at(idx)
	_recompute_speed_multiplier()

func _recompute_speed_multiplier() -> void:
	var lowest := 1.0
	for m in _active_speed_multipliers:
		lowest = minf(lowest, m)
	_speed_multiplier = lowest

func apply_knockback(impulse: Vector3) -> void:
	if impulse.is_zero_approx() or not RoundManager.round_active:
		return
	impulse /= trait_grit_scale()
	var flat := Vector2(impulse.x, impulse.z)
	if flat.length() > MAX_KNOCKBACK_SPEED:
		flat = flat.normalized() * MAX_KNOCKBACK_SPEED
	velocity.x += flat.x
	velocity.z += flat.y
	velocity.y = maxf(velocity.y, minf(impulse.y, MAX_KNOCKBACK_LIFT))

## ---------------------------------------------------------------------------
## THE HUD'S STATUS STACK. `Design.md` §Status readability — a stun the player
## cannot time is a stun they cannot play around, which is most of what "the
## defender feels overpowered" was.
##
## ⚠️ THE PRODUCER CHANGED AND THE CONSUMER DID NOT. `hud.gd::_refresh_status_stack`
## reads `[{label, seconds, total}]` and draws a labelled bar per row; every row
## below is new but the contract is the one it already had.
## ---------------------------------------------------------------------------
func status_effects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match state:
		State.STAGGERED:
			out.append({"label": "STUNNED", "seconds": _staggered_time_left,
				"total": maxf(_staggered_time_left, BASE_STAGGER_TIME)})
		State.DOWNED:
			out.append({"label": "DOWNED", "seconds": _downed_time_left,
				"total": maxf(_downed_time_left, 1.0)})
		State.NORMAL:
			pass
	if _fatigue_left > 0.0:
		out.append({"label": "FATIGUED", "seconds": _fatigue_left, "total": FATIGUE_TIME})
	# ⚠️ VULNERABLE IS THE MOST IMPORTANT ROW ON THE HUD and it has no countdown —
	# it lasts exactly as long as you choose to stay in the box holding a slipper.
	# `seconds` 0 with a non-zero `total` is the contract hud.gd reads as "solid
	# bar, no timer", which is the honest drawing of a state you control.
	if is_taggable():
		out.append({"label": "VULNERABLE", "seconds": 0.0, "total": 1.0})
	if _shove_cooldown_left > 0.0:
		out.append({"label": "SHOVE CD", "seconds": _shove_cooldown_left,
			"total": SHOVE_COOLDOWN})
	# The taya's lunge. Same contract as SHOVE CD — a cooldown the player cannot see
	# is a cooldown they mash into, and the lunge is now the only way to score a tag.
	if _lunge_cooldown_left > 0.0:
		out.append({"label": "LUNGE CD", "seconds": _lunge_cooldown_left,
			"total": LUNGE_COOLDOWN})
	if RoundManager.throw_cooldown_left() > 0.0 and not is_defender:
		out.append({"label": "THROW CD", "seconds": RoundManager.throw_cooldown_left(),
			"total": RoundManagerScript.THROW_RESTORE_COOLDOWN})
	return out

## ---------------------------------------------------------------------------
## FEEDBACK.
## ---------------------------------------------------------------------------

func _flash_hit(sfx: String = "") -> void:
	_visual.flash_hit()
	if sfx != "":
		AudioManager.play_at(sfx, global_position)
	_hitstop()
	var is_mine := (is_multiplayer_authority() and ai_controller == null) \
		if NetworkManager.is_networked() else player_id == 1
	if is_mine and _camera_rig != null:
		_camera_rig.shake()

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE HITSTOP OUTLIVED THE CHARACTER THAT STARTED IT, AND IT LEFT THE WHOLE
## ENGINE AT 5% SPEED. Found and fixed 2026-08-01 by ⚖️ `build fair`.
##
## This used to be `create_timer(...).timeout.connect(_end_hitstop)` — a
## `SceneTreeTimer` whose one listener is an **instance** method — guarding a pair
## of **static** flags. Free that instance inside the 60 ms window and the
## connection dies with it, so `_end_hitstop()` never ran: `Engine.time_scale`
## stayed at **0.05** for the rest of the process and `_hitstop_active` stayed
## true, which also silently disabled every future hitstop in the game.
##
## ⚠️ IT IS NOT A THEORETICAL LIFETIME BUG — IT COST THIS SESSION A MEASUREMENT.
## `ai_probe.tscn -- matches=3` frees the whole `Main.tscn` between matches
## (`_end_match`). A hit landing on the last frame of a match orphaned the timer,
## and match 2 then ran at time_scale 0.05 against the probe's own 6.0 — a **120x**
## slowdown that reads exactly like a hang. It reproduces on demand: `matches=1`
## always finished, `matches=3` never got past match 2. The shipping game has the
## same shape — `main.gd` frees every character on RETURN TO MENU, so quitting a
## match on the same frame somebody was hit left the menus running at 5% speed.
##
## THE FIX HAS NO OWNER PROBLEM: a wall-clock deadline that ANY live character
## clears, plus a forced restore when a character leaves the tree with one
## outstanding. Nothing depends on a particular instance surviving.
##
## ⚠️ `Time.get_ticks_msec()` AND NOT A `delta` ACCUMULATOR, because the thing
## being timed is a deliberate distortion of `delta`. Sixty milliseconds of
## hitstop measured in scaled time would last 60 / 0.05 = 1.2 REAL seconds.
static var _hitstop_until_msec: int = 0

func _hitstop() -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	_hitstop_restore_scale = Engine.time_scale
	_hitstop_until_msec = Time.get_ticks_msec() + int(HITSTOP_DURATION * 1000.0)
	Engine.time_scale = HITSTOP_TIME_SCALE

## Called at the top of every character's `_physics_process`, so whichever units
## are alive share the job and none of them owns it.
static func _step_hitstop() -> void:
	if not _hitstop_active or Time.get_ticks_msec() < _hitstop_until_msec:
		return
	_end_hitstop()

## ⚠️ STATIC, so the last character in the world can still end a hitstop it did
## not start.
static func _end_hitstop() -> void:
	if not _hitstop_active:
		return
	Engine.time_scale = _hitstop_restore_scale
	_hitstop_active = false

## The belt for the case the deadline cannot cover: the tree is being torn down
## and there may be no `_physics_process` left to run at all.
func _exit_tree() -> void:
	_end_hitstop()

func _on_state_changed_audio(new_state: State) -> void:
	match new_state:
		State.DOWNED:
			AudioManager.play_at("downed", global_position)
		State.NORMAL, State.STAGGERED:
			pass
	_audio_prev_state = new_state

## ---------------------------------------------------------------------------
## INPUT — the one indirection that lets the AI press the same buttons a human
## does, so `_physics_process` above never branches on who is driving.
## ---------------------------------------------------------------------------
var _ai_intent: Dictionary = {}      ## base action -> bool, this frame
var _ai_intent_prev: Dictionary = {} ## base action -> bool, previous frame
var ai_aim_point: Vector3 = Vector3.INF
var input_parked: bool = false

func is_ai_driven() -> bool:
	return ai_controller != null and ai_controller.is_enabled()

func _ai_driven() -> bool:
	return is_ai_driven()

func ai_set_intent(base_name: String, pressed: bool) -> void:
	_ai_intent[base_name] = pressed

func ai_commit_intent_frame() -> void:
	_ai_intent_prev = _ai_intent.duplicate()

func ai_clear_intent() -> void:
	_ai_intent.clear()
	_ai_intent_prev.clear()

func _reads_hardware() -> bool:
	return not _ai_driven() and not input_parked

func input_pressed(base_name: String) -> bool:
	if _ai_driven():
		return _ai_intent.get(base_name, false)
	return _reads_hardware() and Input.is_action_pressed(base_name)

func input_just_pressed(base_name: String) -> bool:
	if _ai_driven():
		return _ai_intent.get(base_name, false) and not _ai_intent_prev.get(base_name, false)
	return _reads_hardware() and Input.is_action_just_pressed(base_name)

func input_just_released(base_name: String) -> bool:
	if _ai_driven():
		return _ai_intent_prev.get(base_name, false) and not _ai_intent.get(base_name, false)
	return _reads_hardware() and Input.is_action_just_released(base_name)

func input_vector(neg_x: String, pos_x: String, neg_y: String, pos_y: String) -> Vector2:
	if _ai_driven():
		var v := Vector2(
			(1.0 if _ai_intent.get(pos_x, false) else 0.0) - (1.0 if _ai_intent.get(neg_x, false) else 0.0),
			(1.0 if _ai_intent.get(pos_y, false) else 0.0) - (1.0 if _ai_intent.get(neg_y, false) else 0.0))
		return v.normalized() if v.length() > 1.0 else v
	if not _reads_hardware():
		return Vector2.ZERO
	return Input.get_vector(neg_x, pos_x, neg_y, pos_y)

func action_name(base_name: String) -> String:
	return base_name

## ---------------------------------------------------------------------------
## VISUAL PASSTHROUGH.
##
## ⚠️ `broadcast_visual_action` EXISTS BECAUSE EVERY SWING AND LUNGE WAS ONCE
## ANIMATED ONLY ON THE PRESSER'S OWN MACHINE. An action nobody else can see is an
## action nobody else can answer.
## ---------------------------------------------------------------------------

func get_hand_attachment() -> Node3D:
	return _visual.get_hand_attachment()

func play_visual_action(kind: String) -> void:
	_visual.play_action(kind)
	# ⚠️ AND THE FIRST-PERSON HAND, WHICH THE BODY CLIP CANNOT COVER. In FPP the
	# body is SHADOWS_ONLY and the player sees the viewmodel instead, so every verb
	# animated on the body was invisible to the one person who pressed it. Hooked
	# HERE rather than at each call site so it can never disagree with the clip —
	# both come off the same call, including the replicated one.
	var rig := get_node_or_null("CameraRig") as CameraRig
	if rig != null:
		rig.play_viewmodel_action(kind)

func broadcast_visual_action(kind: String) -> void:
	if NetworkManager.is_networked():
		_rpc_visual_action.rpc(kind)
	else:
		play_visual_action(kind)

@rpc("any_peer", "call_local", "reliable")
func _rpc_visual_action(kind: String) -> void:
	play_visual_action(kind)

func snap_visual_interpolation() -> void:
	_visual.snap_remote_transform()

func capsule_height() -> float:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		return (shape_node.shape as CapsuleShape3D).height
	return 1.6

func capsule_radius() -> float:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		return (shape_node.shape as CapsuleShape3D).radius
	return 0.4

## ---------------------------------------------------------------------------
## LIFECYCLE.
## ---------------------------------------------------------------------------

func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	begin_spawn_settle()
	snap_visual_interpolation()
	AudioManager.play_at("respawn", global_position)
	_was_airborne = false
	_fall_speed = 0.0

func reset_for_new_round() -> void:
	# ⚠️ THE DEFERRED PICK REPAINT, FLUSHED AT THE BOUNDARY THAT MAKES IT SAFE. A roster
	# pick that landed while this unit was carrying could not rebuild the model then
	# without freeing the slipper in its hand — see `character_index`'s own note. A round
	# reset is exactly the "run at a boundary" the withdrawn setter's measurement asked
	# for: hands are emptied by the reset itself.
	if _pick_repaint_pending:
		_pick_repaint_pending = false
		if _visual != null and is_instance_valid(_visual):
			_visual.apply(is_person, is_can, player_slot)
	velocity = Vector3.ZERO
	_staggered_time_left = 0.0
	_downed_time_left = 0.0
	_active_speed_multipliers.clear()
	_speed_multiplier = 1.0
	_stamina = STAMINA_MAX
	_stamina_idle = 0.0
	_is_sprinting = false
	_fatigue_left = 0.0
	_cancel_shove()
	_shove_cooldown_left = 0.0
	_observed_shove_charge = -1.0
	_held_slipper = null
	_audio_prev_state = State.NORMAL
	var was_state := state
	state = State.NORMAL
	# ⚠️ The setter above suppresses a same-value write, so a unit that was ALREADY
	# NORMAL would never re-emit — and the nameplate and HUD both refresh off this
	# signal at a role rotation. Emit it by hand in exactly that case.
	if was_state == State.NORMAL:
		state_changed.emit(state)
	if _carrier != null:
		_carrier.reset_for_new_round()
	_visual.apply(is_person, is_can, player_slot)
