# Design — the rules, and every number that decides them

**This file is the balance source of truth.** A number in the code must match a number
here, or one of the two is a bug. **⚖️ `build fair` has final authority over every value
below**; any lane that moves one moves it here in the same commit.

## 0 · The premise

2v2. A **team is one Person + one Prop**. The Prop is a **lata** (can) on the defending
round and a **tsinelas** (slipper) on the attacking round. Attackers throw the tsinelas at
the lata. Defenders keep the lata standing **on its circle**. Rounds are 90 s and are
scored in **paired sets** — see §7.

**The thesis: the objects are players, not props.** The lata used to stand still and the
tsinelas used to be ammunition, while the two Persons decided every round. Both now have
their own charge meters, movement verbs and win conditions.

## 1 · Removed, and why

| Removed | Why |
|---|---|
| **The tag / tap-out** | One button near the attacker ended the round outright, with no counterplay worth the name. **The defence no longer has an instant win at all.** |
| **Can Guard** (hold to block a hit) | It nullified the attacker's one window per throw. Replaced by Can-Dash and Can-Smash — commitments, not a hold. |
| **Auto-seal on an unrecovered knockdown** | Replaced by the out-of-circle countdown (§5.2). A lata no longer loses by lying still; it loses by being *displaced*. |
| **Seal-on-hit** (touch a lata that is past its self-right window → round over) | The last piece of the auto-seal, and §5.1's stand-up rule turned it into a second tap-out: a stranded lata never leaves that window, so any attacker could walk over, press bump and end the round. **A follow-up hit on a downed lata now just shoves it further from the circle**, which is continuous, legible, and stacks with the clock instead of skipping it. |

## 2 · Movement and stamina — every unit

| Constant | Value | Note |
|---|---|---|
| `SPEED` (walk) | **4.6** | was 6.0. Everything below is built on the lower base. |
| `SPRINT_SCALE` | **1.45** → 6.67 top | Hold **Shift**. |
| `STAMINA_MAX` | **4.0 s** | of continuous sprint |
| `STAMINA_DRAIN_RATE` | 1.0 /s | |
| `STAMINA_REGEN_RATE` | 0.7 /s | a full bar costs 5.7 s to refill |
| `STAMINA_REGEN_DELAY` | 0.8 s | after the last sprint frame |
| `STAMINA_SPRINT_FLOOR` | 0.6 s | you cannot *start* a sprint below this, so the bar cannot be feathered |
| `JUMP_VELOCITY` | 5.8 | the map's clutter-height law caps it |
| `GRAVITY` | 20.0 | |
| `FRICTION` | 30.0 | **knockback distance = v² / 60** |

## 3 · The attacker (Person, offence side)

| Constant | Value | Note |
|---|---|---|
| `THROW_LOCK_TIME` | **1.25 s** | after pickup, before it may be thrown. Anti-cheese: grab-and-fling at the taya's feet was free. HUD: `THROW LOCK`. |
| `CHARGE_FULL_TIME` | 0.9 s | |
| `CHARGE_MIN_POWER` | 0.35 | |
| `LOB_OVERHOLD_TIME` | 0.20 s | hold past full to arm the `bagsak` lob |
| `LOB_LAUNCH_ANGLE_DEG` | 60° | the lob solves SPEED for a fixed angle |
| Trajectory preview | whole charge | dotted arc, 48 samples, 2.5 s horizon, role-coloured |

### 3.1 · The long-throw bonus

The throwing line sits **6.0** from the base circle; the defended box is a **square** at
|x| = |z| = 5.0. Behind the line means `max(|x|,|z|) >= 6.0` — outside the box, out of the
taya's reach, and exposed.

| Constant | Value |
|---|---|
| `LONG_THROW_LINE` | 6.0 |
| `LONG_THROW_SPEED_BONUS` | ×1.20 |
| `LONG_THROW_KNOCKBACK_BONUS` | ×1.25 |
| `LONG_THROW_PUNISH_POWER` | ≥ 0.98 charge |
| `LONG_THROW_PUNISH_STUN` | **5.0 s** on the defending Person |

Enormous on purpose: it answers a defender who body-blocks the lane, it costs the attacker
their tsinelas and the whole retrieval scramble to set up, TATAG divides the duration, and
the counterplay is simply not standing in a straight line at range.

## 4 · The defender (Person, defence side) — the bump meter

The tag is gone. **Left-click is a charged bump**, the mirror of the attacker's charged
throw and deliberately slower than it.

| Constant | Value | Note |
|---|---|---|
| `BUMP_CHARGE_FULL_TIME` | **1.35 s** | = 1.5 × the attacker's `CHARGE_FULL_TIME` |
| `BUMP_TAP_TIME` | 0.18 s | below this it is a tap |
| **Tap — light bump** | 3.0 m/s flat, 0.6 lift | ≈ 0.15 m. No stagger, no drop. A nudge to break a stance. |
| **Full — power bump** | **7.75 m/s flat, 2.2 lift** | = **1.00 m** by v²/60 |
| Power bump extras | **punts** the carried tsinelas · **0.9 s** stagger · **1.2 s** penalty at 0.55× speed | |
| `PUNT_SPEED` / `PUNT_LIFT` | **13.5** / 3.8 → **3.13 m** | scaled by the charge; a tap punts nothing |
| `BUMP_LIGHT_COOLDOWN` | 0.45 s | |
| `BUMP_POWER_COOLDOWN` | 0.80 s | |

**The punt is the "far away" half of the drop, and it was missing.** A stagger already
dropped the slipper for free — any non-NORMAL state does — but it dropped it *at the
carrier's own feet*, so eating a 1.35 s bump cost the attacker one bend of the knees.
It now leaves along the line the bump sent its carrier. **3.13 m measured**
(`tools/mech_probe.tscn`, full charge, default skin, two runs) is ~1.5 s of crawling
back at `CRAWL_SPEED_SCALE` plus the 1.25 s throw lock: about 2.8 s of tempo. The lift
is cosmetic — a loose slipper is bled by `FRICTION` in the air too, so distance is
`v²/60` and airtime adds nothing.

Partial charges interpolate linearly. The whole 1.35 s is visible on **every peer** (the
wind-up broadcast), so the attacker can dash, jump or throw through the commitment.

## 5 · The lata (Prop, defence side)

### 5.1 · It gets knocked around now

| Constant | Value | Note |
|---|---|---|
| `CAN_KNOCKBACK_SCALE` | **×2.6** | on every incoming impulse. A clean hit moves it ~1 m instead of dropping it in place. |
| `DOWNED_SELF_RIGHT_WINDOW` | 1.25 s | press bump to get up early |
| `DOWNED_MAX_TIME` | **2.0 s** | the ceiling on being down. Applies to every Person and every tsinelas wherever they lie, and to a lata **on its circle** — see below |

The lata is lost by being displaced, not by lying down. That is what makes ×2.6 safe.

### 5.1.1 · The lata may only stand up on its circle

**A lata knocked out of its circle does not get up.** Not at `DOWNED_SELF_RIGHT_WINDOW`,
not at the 2.0 s ceiling, not by mashing bump, not by Quick Stand. It is `STRANDED`, and
the only clock that means anything to it is the one in §5.2 that ends the round.

The rule is written once, as **"the out-of-circle countdown is not running"**, rather
than as a second radius test — one line on the floor, one source of truth. It therefore
does not apply during the intermission or the pre-round free-roam window, because no
countdown runs there.

What bounds it is the round, not the body: at most `CAN_OUT_LIMIT_BASE` seconds, less
0.75 per save, at the end of which the attackers have won. That is deliberate — being
displaced is the thing that loses the round, so it has to be the thing that costs.

Its price is that the lata has no verb while stranded; its answers are all upstream
(Can-Dash out of the throw, Can-Smash to keep bodies off the mark, walking home when it
was merely shoved) and its last one is its teammate. **This is the one moment in a round
the two defenders must actually cooperate**, which is worth having in a 2v2.

*Measured*, `tools/mech_probe.tscn`: held down 3.0 s off the circle against a 2.0 s
ceiling; stands within 6 frames of arriving home with no fresh input; a Person downed at
the same spot still gets up by 2.0 s.

### 5.2 · The circle countdown — the defence's real job

| Constant | Value |
|---|---|
| `CAN_HOME_RADIUS` | 0.9 m (drawn ring 0.70; the lata's capsule 0.14) |
| `CAN_OUT_LIMIT_BASE` | **5.0 s** |
| `CAN_OUT_RECOVERY_STEP` | **0.75 s** per recovery |
| `CAN_OUT_RECOVERY_MAX` | **5** stacks → floor **1.25 s** |

While the round is live and the lata is outside `CAN_HOME_RADIUS`, a countdown runs; at
zero the **attackers win the round**. Getting back inside stops and resets it — and
permanently shortens the next one by 0.75 s, five times over. The fifth save buys 1.25
seconds, so the defence's ability to keep saving is itself the clock.

**This is the only ruleset.** The countdown used to be gated to Option B, because an
Option A round could otherwise be lost to a clock nothing in that mode explained. Option A
is deleted (§7.1) and the gate went with it — the countdown now runs unconditionally.

**The channel time is set against this table, not against feel.** With `RESET_CHANNEL_TIME`
at 2.2 s the fifth stack was unreachable decoration — the round was already decided a row
above it. At 1.8 s the cliff lands on the floor:

| saves | 0 | 1 | 2 | 3 | 4 | 5+ |
|---|---|---|---|---|---|---|
| limit | 5.00 | 4.25 | 3.50 | 2.75 | 2.00 | **1.25** |
| save by channel (1.8 s + travel) | easy | easy | easy | ok | knife-edge | **impossible** |

So at maximum stacks a knockdown outside the circle simply ends the round, and the lata's
only survival is not to be knocked over. That escalation is the beat the round is built
around.

**The taya's counterplay: the reset channel carries it home.** A lata is displaced by being
*hit*, and being hit is exactly the state in which it cannot drive itself — so if its own
player were the only one who could move it, the correct attacking play would be to knock it
out and keep it stunned while the taya watched (`hitbox.gd`'s same-team rule forbids even
shoving it). Holding `grab` beside your own lata for `RESET_CHANNEL_TIME` (**1.8 s**) puts
it back on the mark **and then** stands it up — in that order, because §5.1.1 refuses the
stand-up anywhere else. The price is 1.8 s of standing still inside the arena, longer than
the defender's own full bump commitment and twice a full throw charge — the one moment the
attacker gets to punish.

*Measured*, `tools/mech_probe.tscn`: a completed channel on a stranded lata stands it up
and returns it to 0.00 m from centre, and the save shortens the next countdown by exactly
0.75 s.

### 5.3 · Lata abilities

| Ability | Input | Numbers |
|---|---|---|
| **Can-Smash** | `bump` (F) | 0.35 s wind-up · radius **3.6 m** · **1.6 s** stun on a Person, **1.2 s** on a tsinelas (a slipper in flight is dropped LOOSE) · **8.0 s** cooldown ⚠️ the brief says 3.0 s — `build abil` resolves |
| **Can-Dash** | `guard_dash` (Ctrl) | 16.0 m/s for 0.18 s · **one use per round** |
| Roster special | `special_ability` (LMB) | Quick Stand / Spin Guard / Shatter Trap, per the picked skin |

Radius 3.6 is derived: the taya's standoff post is 2.6 m from the can and the confinement
square's edge is 5.0, so it covers the approach lane and stops short of the 6.0 throwing
line. **The can cannot hit anybody who kept their distance.**

### 5.4 · Ragdoll read

Downed is a rotation, not a simulated ragdoll — but it **rolls**: the visual tumbles about
the axis perpendicular to its travel, at the rolling-without-slipping rate for its capsule
radius, plus a 78° topple. Readability is `build phys` 5.3 and is not yet confirmed.

## 6 · The tsinelas (Prop, offence side)

| Ability | Input | Numbers |
|---|---|---|
| **Charged self-launch** | hold `jump` while LOOSE | 0.75 s to full · **6.0 → 13.0 m/s**, 0.62 vertical · the slipper flings *itself* |
| **Ground Smash** | `bump` (F) airborne, ≥ 0.6 m up | dive at **22 m/s** · on impact radius **3.2 m**, **1.4 s** stun · **12.0 s** cooldown |
| **Ground Smash, direct hit** | within **0.75 m** of the lata | **the attacking side wins the round instantly** |
| **Flick Dash** | `guard_dash` (Ctrl) | 14.0 m/s, 0.15 s, 2.5 s cooldown |
| Mid-flight steer | movement keys while FLYING | capped at `MAX_STEER_DELTA_V` 3.0 m/s per throw |

Charge the jump, launch over the taya, dive on the can, win. That loop is the point of the
whole pass: **the slipper can win a round without its Person ever touching it.**

## 7 · Round and match win conditions — the only ruleset

**Attackers win a round by:** the out-of-circle countdown reaching zero (§5.2) · a direct
Ground Smash on the lata (§6) · `FALL_LIMIT` = 4 scoring knockdowns in one round.

**Defenders win a round by:** the 90 s `ROUND_TIME` running out. That is the only way.
There is no tag.

**There is no seal.** Sealing a lata by touching it is gone (§1). `seal()` and the SEALED
state survive as the state machine's own shape — nothing in this ruleset reaches them; see
§7.1 for why they were kept rather than deleted.

### 7 · a · The match is scored in paired sets

| Constant | Value | Note |
|---|---|---|
| `SETS_NEEDED` | **2** | first to two sets takes the match |
| `ROUNDS_PER_SET` | **2** | definitional: both teams attack exactly once |
| `MAX_SETS` | 5 | termination guard, not a format choice |
| `NEVER` | 999999.0 | the attack-time sentinel for "never took the lata out" |

**A set is two rounds in which both teams attack exactly once.** Sets are the scoring
unit. A set is not awarded until both teams have done both jobs, so the format cannot pay
a team for the side it was handed.

**Role is derived, never accumulated.** `MatchManager._team_a_is_can_for(set, round_in_set)`
is a pure function of the schedule:

| | round 1 of the set | round 2 of the set |
|---|---|---|
| **odd sets** (1, 3, 5) | A defends, B attacks | A attacks, B defends |
| **even sets** (2, 4) | A attacks, B defends | A defends, B attacks |

**Which team attacks FIRST alternates with the set number**, because attacking second means
knowing the time you have to beat. Without that alternation the old bug simply moves up one
level, from *"A always defends round 1"* to *"A always attacks second"*.

**The tiebreak is one comparison, not two rules.** Each team's **attack time** is how long
it took to take the lata out on its own attacking round, or `NEVER` if it did not
(`RoundManager.last_attack_time()`, measured host-side as `ROUND_TIME - time_left`). **The
lower number takes the set.** Any finite time beats `NEVER`, so "scored when the other side
did not" and "scored faster than the other side" are the same test. Two `NEVER`s is a drawn
set and awards nothing; `MAX_SETS` then resolves the match on sets, then on aggregate attack
time, and a genuine dead heat reports `winning_team = -1`.

⚠️ **The acceptance test is "the seat draw stops mattering", not the format.** It is met
because every scoring event is a comparison between the two teams doing *the same job*, and
because role comes from the schedule rather than from a bool that was seeded `true`.

### 7.1 · Removed: Option A

**Deleted 2026-07-31** by 📋 `build rules` §8.2, on the rubric finding that two shipped
rulesets is not an esport. Recorded here because 🧑 asked for it in those words — *"remove
gamemode completely but document that it was there"* — and because a deletion nobody wrote
down is a deletion the next lane re-derives from a dangling comment.

**What it was.** A second, host-selectable win-condition set, picked from a MODE row on the
match setup screen (`CAPTURE` vs `DENTS`) and carried to every peer on the lobby config
broadcast:

| Piece | Value | What it did |
|---|---|---|
| `CharacterBase.MAX_DENTS` | 3 | the lata had a **health bar**. `apply_dent()` converted every landed hit into a dent instead of a knockdown, bypassing the Downed/Seal machine entirely |
| `CharacterBase.clear_dent()` | — | the taya's reset channel beat **one dent back out** rather than carrying the lata home |
| `RoundManager.RING_OUT_LIMIT` | 3 | **ring-outs**: the defending side won by knocking the attacking tsinelas off the arena three times, counted off the kill plane |
| defender timer win | 90 s | unchanged from the shipped ruleset |
| `CAN_MESHES` / `lata_dent1..3.obj` | 4 states | the dent count was the lata's only in-world damage read |

**Why it went.** One ruleset is a rubric position, not a cleanup. Two doubled the balance
surface `build fair` has to measure, doubled what a tutorial has to teach, and had already
produced a real bug class: the §5.2 countdown shipped ungated, so an Option A round could be
lost to a clock that mode never explained. The circle countdown is the game.

**What was left behind on purpose, and why.**

* **`seal()` and the `SEALED` state stay.** They were previously justified as *"for Option A
  and for the state machine's own shape"*; with Option A gone only the second half survives,
  and it is still load-bearing. `SEALED` is a terminal non-NORMAL state that four call sites
  test for (drop-the-slipper, knockback refusal, audio, nameplates), and collapsing it into
  `DOWNED` would make those tests mean something subtly different. Nothing reaches it in
  play. **If a later lane wants it gone, that is a state-machine change, not a mode cleanup.**
* **The kill plane still respawns.** `register_ring_out()` is deleted; falling off the arena
  still returns a unit to its spawn, it just no longer scores.
* **`lata_dent1/2/3.obj` and `tools/models/generate_all.gd`'s dent generator are now
  orphaned** — and they were already half-orphaned before this pass, since `CAN_MESHES`
  points at Kenney `.glb` files. Filed to 🎨 `build model` as §5.11.
* **The MODE row is hidden, not deleted from the scene.** `match_setup.gd` no longer has a
  picker; `MatchSetup.tscn` still carries the row for 🖥️ `build ux` §4.18 to remove with the
  focus order.

## 8 · Traits

`BILIS` → the `SPEED` term. `LAKAS` → outgoing impulse and throw charge. `TATAG` → divides
incoming knockback and shortens stagger. Per point: speed ±5 %, power ±7 %, grit ±7 %, on
1..5 with 3 neutral. Narrow on purpose — a pick must be a personality, not the correct
answer.

## 9 · Spectator mode

A free-flying camera with **no body, no collision and no physics layer**, so it clips
through everything by construction rather than by a mask. Reachable from the setup screen
in **both** Single Player and Multiplayer; a spectating peer claims no seat, is excluded
from the ready count, and its seat is bot-filled.

Controls: WASD + mouse · `Space` up · `Ctrl` down · `Shift` boost (×3) · wheel changes base
speed (or the follow distance while following) · `Tab` cycles a follow target · **`V` drops into
that unit's POV** · `F` frees the camera.

⚠️ **`V` was missing from this section until 2026-07-31** and it is not a minor omission — POV is
half of what the human asked spectator for (*"watch the povs of people/ai, thats why its called
camera"*). It is a **placement, not a takeover**: this camera parks at the unit's eye height
(1.45 m on a Person, 0.42 m on a Prop) and takes its yaw, and the watched unit's own `CameraRig`
stays inactive on purpose — activating it would feed the spectator's mouse into a live unit's aim
pipeline, and watching somebody must not change what they do. Pitch stays with the operator.
`V` is sticky across a `Tab` cycle, so a filmed POV pass steps through all four units without
re-pressing it. Source: `spectator_camera.gd`, and § LOG's `build spec` entry.

## 10 · Status readability

The HUD carries a status stack (top-centre, under the timer), one row per live effect with
its own countdown: `STUNNED`, `DOWNED`, `STRANDED`, `SLOWED`, `THROW LOCK`, `SMASH`,
`DASH`, `LATA OUT`. **A stun the player cannot time is a stun they cannot play around**,
which is most of what "the defender feels overpowered" was.

`STRANDED` replaces `DOWNED` on a lata that is off its circle, and the swap is the whole
point: that lata is not counting down to standing up, it is counting down to losing the
round, so it reads the §5.2 clock instead. A `DOWNED` bar ticking to 0.00 and then sitting
there while nothing happens is exactly the defect this section exists to prevent.

## 11 · Cooldown table — the whole game on one screen

| Action | Cooldown | Stun it applies |
|---|---|---|
| Light bump | 0.45 s | — |
| Power bump | 0.80 s | 0.9 s + 1.2 s penalty |
| Can-Smash | 8.0 s ⚠️ under review | 1.6 s / 1.2 s |
| Can-Dash | once per round | — |
| Ground Smash | 12.0 s | 1.4 s |
| Flick Dash | 2.5 s | — |
| Throw (after pickup) | 1.25 s | — |
| Max-power long throw on the taya | — | 5.0 s |

### The stunlock argument — the starting position, not a verdict

⚠️ **Argued, never measured. `build fair` 6.5 owns proving or breaking it.** Four
properties are claimed to bound every chain at 2.5 s:

1. **Stuns overlap, they do not stack.** Every stun arrives through
   `CharacterBase.apply_stagger()`, which takes `max(_staggered_time_left, duration/grit)`.
   Two 1.6 s smashes 0.2 s apart are 1.8 s, not 3.2 s. There is no additive path.
2. **DOWNED has a hard ceiling.** `DOWNED_MAX_TIME` 2.0 s is a wall-clock total, not a
   refreshable window. ⚠️ **It has exactly one exception and it is §5.1.1**: a lata off
   its circle stays down. That is not a stunlock, and the distinction is worth stating
   rather than waving at — a stunlock is a state you cannot act out of *and cannot lose
   out of*, so it stalls the game. A stranded lata is bounded by a countdown that ends
   the round in at most 5.0 s (1.25 s at full stacks), it can be ended early by the
   taya's channel, and nothing about it touches a Person. *Measured*, not argued:
   `tools/mech_probe.tscn` holds a lata down 3.0 s off the circle and a Person 2.4 s at
   the same spot, and only the lata is still there.
3. **The longest producible chain is 2.5 s** — power bump (0.9) into Can-Smash (1.6). It
   needs two units committing in sequence, one of which then owes 8.0 s of cooldown, and
   the bump's 1.35 s wind-up is visible on every peer first.
4. **The 5 s long-throw punish is not repeatable** — it costs the tsinelas, the retrieval
   scramble and a 1.25 s throw lock before it could be set up again.

### Counterplay, per powerful action

Nothing here is answered only by "do not be there".

| Action | Answer |
|---|---|
| Power bump | 1.35 s of visible wind-up — dash, jump, throw, or leave 1.27 m of reach |
| The punt (losing your tsinelas 3 m away) | it only lands off a *charged* bump, so the same 1.35 s tell answers it; and a loose tsinelas self-launches home far faster than it crawls |
| A stranded lata (§5.1.1) | do not be displaced: Can-Dash out of the throw, Can-Smash to keep bodies off the mark — and failing both, the taya's 1.8 s channel |
| Can-Smash | 0.35 s wind-up, and 3.6 m never reaches the 6.0 throwing line |
| Can-Dash | one per round; bait it, then commit |
| Ground Smash | needs height, so it is telegraphed on the ground first; Can-Dash beats it, a miss costs 12 s |
| Long-throw punish | do not stand in the lane at max range |
| Circle countdown | the reset channel carries the lata home (§5.2) |
| Self-launch | a committed arc with no steering; a lata that moves is not under it |
