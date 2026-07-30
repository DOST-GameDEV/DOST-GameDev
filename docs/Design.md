# Design — the rules, and every number that decides them

**This file is the balance source of truth.** A number in the code must match a number
here, or one of the two is a bug. Overhauled 2026-07-30 ("the objects overhaul").

## 0 · The premise, in six lines

2v2. A **team is one Person + one Prop**. The Prop is a **lata** (can) on the defending
round and a **tsinelas** (slipper) on the attacking round; the roles swap every round.
Attackers throw the tsinelas at the lata. Defenders keep the lata standing **on its
circle**. Best of N rounds, 90 s each.

**The 2026-07-30 thesis: the objects are players, not props.** Before this pass the two
objects were passengers — the lata stood still and the tsinelas was ammunition, while
the two Persons decided every round. Both now have their own charge meters, their own
movement verbs and their own win conditions.

## 1 · What was REMOVED, and why

| Removed | Why |
|---|---|
| **The tag / tap-out** (`person_action.gd`, and `hitbox.gd`'s round-win branch) | A defender pressing one button near the attacker ended the round outright. It was the single most decisive event in the game and it had no counterplay worth the name. **The defence no longer has an instant win at all.** |
| **Can Guard** (hold to block a hit outright) | It nullified the attacker's one window per throw. Replaced by Can-Dash and Can-Smash, which are commitments rather than a hold. |
| **Auto-seal on an unrecovered knockdown** | Replaced by the out-of-circle countdown (§5). A lata can no longer lose the round by lying still; it loses by being *displaced*. |

## 2 · Movement and stamina — every unit

| Constant | Value | Note |
|---|---|---|
| `SPEED` (walk) | **4.6** | was 6.0. Everything below is built on the lower base. |
| `SPRINT_SCALE` | **1.45** → 6.67 top | Hold **Shift**. |
| `STAMINA_MAX` | **4.0 s** | of continuous sprint |
| `STAMINA_DRAIN` | 1.0 /s | |
| `STAMINA_REGEN` | 0.7 /s | so a full bar costs 5.7 s to refill |
| `STAMINA_REGEN_DELAY` | 0.8 s | after the last sprint frame |
| `STAMINA_SPRINT_FLOOR` | 0.6 s | you cannot *start* a sprint below this, so the bar cannot be feathered |
| `JUMP_VELOCITY` | 5.8 | unchanged — the map's clutter-height law caps it |
| `GRAVITY` | 20.0 | unchanged |
| `FRICTION` | 30.0 | unchanged. **Knockback distance = v² / 60.** |

## 3 · The attacker (Person, offence side)

| Constant | Value | Note |
|---|---|---|
| `THROW_LOCK_TIME` | **1.25 s** | after picking a tsinelas up before it may be thrown. Anti-cheese: grab-and-fling at the taya's feet was free. Shown on the HUD as `THROW LOCK`. |
| `CHARGE_FULL_TIME` | 0.9 s | unchanged |
| `CHARGE_MIN_POWER` | 0.35 | unchanged |
| `LOB_OVERHOLD_TIME` | 0.20 s | hold past full to arm the `bagsak` lob |
| `LOB_LAUNCH_ANGLE_DEG` | 60° | the lob solves SPEED for a fixed angle |
| **Trajectory preview** | on, whole charge | dotted arc, 48 samples, 2.5 s horizon, role-coloured |

### 3.1 · The long-throw bonus — the attacker's reward for standing back

The throwing line sits **6.0 units** from the base circle; the defended box is a
**square at \|x\| = \|z\| = 5.0**. Standing *behind* the line means
`max(\|x\|, \|z\|) >= 6.0` — outside the box, out of the taya's reach, and exposed.

| Constant | Value |
|---|---|
| `LONG_THROW_LINE` | 6.0 |
| `LONG_THROW_SPEED_BONUS` | ×1.20 |
| `LONG_THROW_KNOCKBACK_BONUS` | ×1.25 |
| `LONG_THROW_PUNISH_POWER` | ≥ 0.98 charge |
| `LONG_THROW_PUNISH_STUN` | **5.0 s** on the defending Person |

A max-charge throw from behind the line that lands on the **taya** stuns them for five
seconds. That is enormous on purpose: it is the answer to a defender who body-blocks
the lane, it costs the attacker their tsinelas and the whole retrieval scramble to set
up, TATAG divides the duration, and the defender's counterplay is simply not to stand
in a straight line at range.

## 4 · The defender (Person, defence side) — the bump meter

The tag is gone. **Left-click is now a charged bump**, the mirror of the attacker's
charged throw and deliberately slower than it.

| Constant | Value | Note |
|---|---|---|
| `BUMP_CHARGE_FULL_TIME` | **1.35 s** | = 1.5 × the attacker's `CHARGE_FULL_TIME` |
| `BUMP_TAP_TIME` | 0.18 s | below this it is a tap |
| **Tap — light bump** | 3.0 m/s flat, 0.6 lift, **no stagger, no drop** | ≈ 0.15 m of displacement. A nudge to break a stance, nothing more. |
| **Full — power bump** | **7.75 m/s flat, 2.2 lift** | = **1.00 m** of displacement by v²/60 |
| Power bump extras | drops the carried tsinelas · `0.9 s` stagger · `1.2 s` hit penalty at 0.55 × speed | |
| `BUMP_LIGHT_COOLDOWN` | 0.45 s | |
| `BUMP_POWER_COOLDOWN` | 0.80 s | |

Partial charges interpolate linearly between the two. The whole 1.35 s is visible on
every peer (the wind-up broadcast), so the attacker can see the commitment and dash,
jump or throw through it.

## 5 · The lata (Prop, defence side)

### 5.1 · It gets knocked around now

| Constant | Value | Note |
|---|---|---|
| `CAN_KNOCKBACK_SCALE` | **×2.6** | applied to every incoming impulse. A clean slipper hit moves the lata ~1 m instead of dropping it in place. |
| `DOWNED_SELF_RIGHT_WINDOW` | 1.25 s | press bump to get up early |
| `DOWNED_MAX_TIME` | **2.0 s** | **a lata can never be down longer than this.** It always rights itself. |

The lata is no longer lost by lying down — it is lost by being displaced. That is what
makes ×2.6 safe and what makes the smash abilities below worth having.

### 5.2 · The circle countdown — the defence's real job

| Constant | Value |
|---|---|
| `CAN_HOME_RADIUS` | 0.9 m (the drawn ring is 0.70; the lata's own capsule is 0.14) |
| `CAN_OUT_LIMIT_BASE` | **5.0 s** |
| `CAN_OUT_RECOVERY_STEP` | **0.75 s** per recovery |
| `CAN_OUT_RECOVERY_MAX` | **5** stacks → floor **1.25 s** |

While the round is live and the lata is outside `CAN_HOME_RADIUS`, a countdown runs.
At zero the **attackers win the round**. Driving the lata back inside the circle stops
and resets it — and **permanently shortens the next one by 0.75 s**, up to five times.
So the fifth save buys you 1.25 seconds, and the defence's ability to keep saving is
itself the clock.

**The taya's counterplay: the reset channel carries it home.** A lata is displaced by
being *hit*, and being hit is exactly the state in which it cannot drive itself — so if
its own player were the only one who could move it, the correct attacking play would be
to knock it out and then keep it stunned, with the taya unable to help (`hitbox.gd`'s
same-team rule forbids even shoving it). Holding `grab` beside your own lata for
`RESET_CHANNEL_TIME` (2.2 s) now stands it up **and**, if it is outside the circle, puts
it back on the mark. The price is unchanged: 2.2 s of standing still inside the arena,
which is the one moment the attacker gets to punish.

### 5.3 · Lata abilities

| Ability | Input | Numbers |
|---|---|---|
| **Can-Smash** | `bump` (F) | 0.35 s wind-up · shockwave **radius 3.6 m** · **1.6 s** stun on a Person, **1.2 s** on a tsinelas (a slipper in flight is dropped LOOSE) · **8.0 s** cooldown |
| **Can-Dash** | `guard_dash` (Ctrl) | 16.0 m/s for 0.18 s · **one use per round** |
| Roster special | `special_ability` (LMB) | Quick Stand / Spin Guard / Shatter Trap, per the picked lata skin |

### 5.4 · Ragdoll read

Downed is still a rotation, not a simulated ragdoll — but it **rolls** now: the visual
tumbles about the axis perpendicular to its own travel, at the rolling-without-slipping
rate for its capsule radius, plus a 78° topple. A lata that gets hit visibly goes over
and keeps going.

## 6 · The tsinelas (Prop, offence side)

| Ability | Input | Numbers |
|---|---|---|
| **Charged self-launch** | hold `jump` while LOOSE | 0.75 s to full · **6.0 → 13.0 m/s**, 0.62 of it vertical · the slipper flings *itself* |
| **Ground Smash** | `bump` (F) while airborne, ≥ 0.6 m up | dive at **22 m/s** · on impact, shockwave **radius 3.2 m**, **1.4 s** stun · **12.0 s** cooldown |
| **Ground Smash, direct hit** | within **0.75 m** of the lata | **the attacking side wins the round instantly** |
| **Flick Dash** | `guard_dash` (Ctrl) | 14.0 m/s, 0.15 s, 2.5 s cooldown (unchanged) |
| Mid-flight steer | movement keys during FLYING | capped at `MAX_STEER_DELTA_V` 3.0 m/s per throw (unchanged) |

Charge the jump, launch yourself over the taya, dive on the can, win the round. That
loop is the point of the whole pass: **the slipper can win a round without its Person
ever touching it.**

## 7 · Round win conditions (Option B — the shipped mode)

**Attackers (tsinelas side) win by:**
1. the lata's out-of-circle countdown reaching zero (§5.2), or
2. a direct Ground Smash on the lata (§6), or
3. `FALL_LIMIT` = 4 scoring knockdowns in one round.

**Defenders (lata side) win by:** the 90 s `ROUND_TIME` running out. That is the only
way. There is no tag.

Option A (dents, `MAX_DENTS` 3) is still maintained in parallel and unchanged.

## 8 · Traits — three numbers, three sites, no new systems

`BILIS` → the `SPEED` term. `LAKAS` → outgoing impulse and throw charge.
`TATAG` → divides incoming knockback and shortens stagger.
Per point: speed ±5 %, power ±7 %, grit ±7 %, on a 1..5 scale with 3 neutral.
The spread is narrow on purpose — a pick must be a personality, not the correct answer.

## 9 · Spectator mode

A free-flying camera with **no body, no collision and no physics layer**, so it clips
through everything by construction rather than by a mask. Available from the setup
screen in **both** Single Player and Multiplayer; a spectating peer claims no seat, is
excluded from the ready count, and its seat is filled by a bot.

Controls: WASD + mouse · `Space` up · `Ctrl` down · `Shift` boost (×3) ·
mouse wheel changes the base speed · `Tab` cycles a follow target · `F` frees the camera.

## 10 · Status readability — every stun has a number on screen

The HUD carries a status stack (top-centre, under the timer). One row per live effect,
each with its own countdown in seconds: `STUNNED`, `DOWNED`, `PENALTY`, `THROW LOCK`,
`SMASH`, `DASH`, `LATA OUT`. **A stun the player cannot time is a stun they cannot play
around**, which is most of what "the defender feels overpowered" was.

## 11 · Cooldown table — the whole game on one screen

| Action | Cooldown | Stun it applies |
|---|---|---|
| Light bump | 0.45 s | — |
| Power bump | 0.80 s | 0.9 s + 1.2 s penalty |
| Can-Smash | 8.0 s | 1.6 s / 1.2 s |
| Can-Dash | once per round | — |
| Ground Smash | 12.0 s | 1.4 s |
| Flick Dash | 2.5 s | — |
| Throw (after pickup) | 1.25 s | — |
| Max-power long throw on the taya | — | 5.0 s |

### The stunlock argument — named, not asserted

**No chain in this game locks a player out for longer than 2.5 seconds, and every one
of them costs more than it buys.** Four properties hold it, and each is a line of code
rather than a convention:

1. **Stuns do not stack — they overlap.** Every stun in the game, without exception,
   arrives through `CharacterBase.apply_stagger()`, which does
   `max(_staggered_time_left, duration / grit)`. Two 1.6 s smashes landing 0.2 s apart
   are 1.8 s of stun, not 3.2 s. There is no additive path.
2. **DOWNED has a hard ceiling.** `DOWNED_MAX_TIME` 2.0 s applies to *every unit*, not
   just the lata, and it is a wall-clock total rather than a refreshable window — so
   repeated knockdowns cannot hold a body on the floor.
3. **The longest producible chain is 2.5 s** — a power bump (0.9 s) into a Can-Smash
   (1.6 s). It needs *two different units* to commit in sequence, one of which then owes
   8.0 s of cooldown, and the bump's own 1.35 s wind-up is visible on every peer before
   it lands. During those 2.5 s the defence is standing next to the attacker instead of
   guarding a circle whose countdown is running.
4. **The one longer effect is the 5 s long-throw punish, and it is not repeatable.**
   Landing it costs the attacker their tsinelas, the whole retrieval scramble, and a
   1.25 s throw lock before they could ever set it up again — at minimum eight seconds
   of round for five seconds of stun, from a position where the taya can simply not be
   standing in a straight line.

**Counterplay, per powerful action.** Nothing here is answered only by "do not be there":

| Action | Answer |
|---|---|
| Power bump | 1.35 s of visible wind-up — dash, jump, throw, or walk out of 1.27 m of reach |
| Can-Smash | 0.35 s wind-up, and 3.6 m never reaches the 6.0 throwing line |
| Can-Dash | one per round; bait it, then commit |
| Ground Smash | needs height, so it is telegraphed on the ground first; Can-Dash beats it, and a miss costs 12 s |
| Long-throw punish | do not stand in the lane at max range |
| Circle countdown | the reset channel carries the lata home (§5.2) |
| Self-launch | it is a committed arc with no steering; a lata that moves is not under it |
