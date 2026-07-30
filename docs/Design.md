# Design — the rules, and every number that decides them

**This file is the balance source of truth.** A number in the code must match a number
here, or one of the two is a bug. **⚖️ `build fair` has final authority over every value
below**; any lane that moves one moves it here in the same commit.

## 0 · The premise

2v2. A **team is one Person + one Prop**. The Prop is a **lata** (can) on the defending
round and a **tsinelas** (slipper) on the attacking round; roles swap every round.
Attackers throw the tsinelas at the lata. Defenders keep the lata standing **on its
circle**. Best of N rounds, 90 s each.

**The thesis: the objects are players, not props.** The lata used to stand still and the
tsinelas used to be ammunition, while the two Persons decided every round. Both now have
their own charge meters, movement verbs and win conditions.

## 1 · Removed, and why

| Removed | Why |
|---|---|
| **The tag / tap-out** | One button near the attacker ended the round outright, with no counterplay worth the name. **The defence no longer has an instant win at all.** |
| **Can Guard** (hold to block a hit) | It nullified the attacker's one window per throw. Replaced by Can-Dash and Can-Smash — commitments, not a hold. |
| **Auto-seal on an unrecovered knockdown** | Replaced by the out-of-circle countdown (§5.2). A lata no longer loses by lying still; it loses by being *displaced*. |

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
| Power bump extras | drops the carried tsinelas · **0.9 s** stagger · **1.2 s** penalty at 0.55× speed | |
| `BUMP_LIGHT_COOLDOWN` | 0.45 s | |
| `BUMP_POWER_COOLDOWN` | 0.80 s | |

Partial charges interpolate linearly. The whole 1.35 s is visible on **every peer** (the
wind-up broadcast), so the attacker can dash, jump or throw through the commitment.

## 5 · The lata (Prop, defence side)

### 5.1 · It gets knocked around now

| Constant | Value | Note |
|---|---|---|
| `CAN_KNOCKBACK_SCALE` | **×2.6** | on every incoming impulse. A clean hit moves it ~1 m instead of dropping it in place. |
| `DOWNED_SELF_RIGHT_WINDOW` | 1.25 s | press bump to get up early |
| `DOWNED_MAX_TIME` | **2.0 s** | **no body can be down longer than this** — it applies to Persons too, which is what closes the old seal-a-Person bug by construction |

The lata is lost by being displaced, not by lying down. That is what makes ×2.6 safe.

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

**The taya's counterplay: the reset channel carries it home.** A lata is displaced by being
*hit*, and being hit is exactly the state in which it cannot drive itself — so if its own
player were the only one who could move it, the correct attacking play would be to knock it
out and keep it stunned while the taya watched (`hitbox.gd`'s same-team rule forbids even
shoving it). Holding `grab` beside your own lata for `RESET_CHANNEL_TIME` (2.2 s) stands it
up **and** puts it back on the mark. The price is 2.2 s of standing still inside the arena
— the one moment the attacker gets to punish.

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

## 7 · Round win conditions (Option B — the shipped mode)

**Attackers win by:** the out-of-circle countdown reaching zero (§5.2) · a direct Ground
Smash on the lata (§6) · `FALL_LIMIT` = 4 scoring knockdowns in one round.

**Defenders win by:** the 90 s `ROUND_TIME` running out. That is the only way. There is no
tag.

Option A (dents, `MAX_DENTS` 3) is maintained in parallel and unchanged.

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
speed · `Tab` cycles a follow target · `F` frees the camera.

## 10 · Status readability

The HUD carries a status stack (top-centre, under the timer), one row per live effect with
its own countdown: `STUNNED`, `DOWNED`, `PENALTY`, `THROW LOCK`, `SMASH`, `DASH`,
`LATA OUT`. **A stun the player cannot time is a stun they cannot play around**, which is
most of what "the defender feels overpowered" was.

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
2. **DOWNED has a hard ceiling.** `DOWNED_MAX_TIME` 2.0 s applies to every unit and is a
   wall-clock total, not a refreshable window.
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
| Can-Smash | 0.35 s wind-up, and 3.6 m never reaches the 6.0 throwing line |
| Can-Dash | one per round; bait it, then commit |
| Ground Smash | needs height, so it is telegraphed on the ground first; Can-Dash beats it, a miss costs 12 s |
| Long-throw punish | do not stand in the lane at max range |
| Circle countdown | the reset channel carries the lata home (§5.2) |
| Self-launch | a committed arc with no steering; a lata that moves is not under it |
