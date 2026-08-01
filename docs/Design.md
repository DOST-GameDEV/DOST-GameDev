# Design — the rules, and every number that decides them

**This file is the balance source of truth.** A number in the code must match a number
here, or one of the two is a bug. Any lane that moves one moves it here in the same
commit.

**Rewritten 2026-07-31 on branch `HARRYDAKS`.** It replaces the 2v2
objects-are-players design completely. § 12 records what was deleted and why, because
a deletion nobody wrote down is a deletion the next lane re-derives from a dangling
comment.

## 0 · The premise

**Four players. Four rounds. One taya.**

Tumbang preso as it is actually played. One **Defender** (the *taya*) guards a **lata**
standing inside a chalk box. Three **Attackers** throw slippers at it from outside the
box, then have to run in and retrieve them — which is the only moment they can be
caught. At the end of each 90 s round the taya role rotates clockwise. Everyone plays
taya exactly once. Highest cumulative score after round 4 wins.

**The thesis: the tension is the retrieval, not the throw.** Throwing is safe and free.
Getting your slipper back is what costs you.

## 1 · Match structure

| Constant | Value | Where |
|---|---|---|
| `ROUNDS` | **4** | `match_manager.gd` |
| `PLAYER_COUNT` | **4** | `match_manager.gd` |
| `ROUND_TIME` | **90.0 s** | `round_manager.gd` |
| `INTERMISSION_DURATION` | 3.0 s | `match_manager.gd` |

Total match ≈ 6 minutes plus intermissions.

**Role is derived, never accumulated.** `MatchManager.defender_slot_for(round)` is
`(round - 1) % 4` — a pure function of the round number.

| round | 1 | 2 | 3 | 4 |
|---|---|---|---|---|
| taya | P1 | P2 | P3 | P4 |

⚠️ **That it is a function and not a counter is the whole fairness argument.** A schedule
expressed as a mutating counter has no way to state the invariant it is supposed to
keep, and it desyncs the moment one peer misses one call. "Everyone defends exactly
once, clockwise" is true here by construction. The 2v2 format this replaced needed a
whole paired-set system to reach the same property; four players and four rounds get it
for free.

**At the end of a round:** scores persist, everyone resets to the Safe Zone, the taya
rotates. **There is no per-round winner.**

## 2 · The arena

| Constant | Value | Note |
|---|---|---|
| `CONFINEMENT_RADIUS` | **6.5** | `character_base.gd`. A **square** at \|x\| = \|z\| = 6.5 |
| `SAFE_ZONE_MARGIN` | 2.0 | Attackers spawn on a ring at 6.5 + 2.0 = **8.5** |
| throwing line | **7.5** | = `CONFINEMENT_RADIUS` + 1.0, derived in both map builders |
| `DEFENDER_START_OFFSET` | 2.5 | the taya's mark inside its own box |
| `INTERACTION_RADIUS` | 1.6 | the lata's reset ring, `lata.gd` |

**The Defender's Box (the danger zone).** The taya is clamped inside it and cannot
leave. Attackers move freely everywhere; the box is merely *dangerous* to them.

**The Safe Zone is everything outside the box.** An Attacker there cannot be tagged,
full stop.

⚠️ **A SQUARE, NOT A CIRCLE, AND THE CHALK IS THE TRUTH.** Both map builders draw the
marker as four straight court lines at \|x\| = \|z\| = 5.0, and `_move_and_confine()`
clamps X and Z independently to match. A square and a circle of the same "radius" only
agree at the four edge midpoints; on the diagonals they disagree by 2.07 units, which is
exactly where a taya moves when covering a corner. Human call, 2026-07-29.

⚠️ **`tools/maps/floorcheck.py` REGEXES `^const CONFINEMENT_RADIUS: float = ...` OUT OF
`character_base.gd`,** and both map builders draw the chalk from it. Delete or reshape
that const and every map build aborts.

⚠️ **RAISED 5.0 → 6.5 ON 2026-08-01 BY 🎨 `build model`, ON HUMAN INSTRUCTION** — 🧑,
twice: *"the current play area feels too small"*, *"play area needs to be bigger"*. 5.0
was measured for one taya against one attacker and had never been re-tuned for one taya
against three. +30% on the edge, **+69% on the area** (100 → 169 sq units).

Bounded by two things rather than picked by taste: the shortest legal throw becomes 6.5 m
against a 45° range of `LAUNCH_SPEED`² / `GRAVITY` = **14.45 m**, so the throw still
reaches comfortably; and the spawn ring moves to 8.5 against a `COURT_Z` of 13.0 on both
maps, so it still lands on paving. Both map builders re-verify the second one on every
run.

⚠️ **THE VALUE IS STILL UNMEASURED IN PLAY, AND IT IS ⚖️ `build fair`'s NUMBER** (§2.2).
It moved in a map lane only because the chalk is derived from it. It also pulls on §2.1:
a box three attackers can enter more easily is a taya collecting less uncontested passive
defence, so 2.1 must be re-measured at 6.5 and not at 5.0.

⚠️ **Spawns are computed from the box, not read from map markers** (`main.gd`). "Outside
the box" is the rule; a marker drifting half a metre inside `CONFINEMENT_RADIUS` would
spawn an Attacker VULNERABLE on frame one and read as a rules bug rather than a map bug.

## 3 · Movement and stamina — every player

| Constant | Value | Note |
|---|---|---|
| `SPEED` | **4.6** | walk — **the taya's speed** |
| `ATTACKER_SPEED_SCALE` | **0.75** | an Attacker walks at 3.45. Permanent, by ROLE |
| `SPRINT_SCALE` | **1.50** → 6.90 | hold **Shift**. The GDD's "+50% speed" |
| `STAMINA_MAX` | **50.0** | points, not seconds |
| `STAMINA_DRAIN_RATE` | **40.0 /s** | = **1.25 s** of continuous sprint |
| `STAMINA_REGEN_RATE` | **20.0 /s** | a full bar refills in 5.0 s |
| `STAMINA_REGEN_DELAY` | **2.5 s** | after the last sprint frame |
| `STAMINA_SPRINT_FLOOR` | 7.5 | you cannot *start* a sprint below this, so the bar cannot be feathered |
| `FATIGUE_TIME` | **2.0 s** | triggered by reaching 0. **Regen is locked for its whole duration** |
| `FATIGUE_SPEED_SCALE` | **0.75** | −25% speed, sprint locked out |
| `JUMP_VELOCITY` | 5.8 | |
| `GRAVITY` | 20.0 | |
| `FRICTION` | 30.0 | **knockback distance = v² / 60** |

⚠️ **REVISED 2026-08-01 ON HUMAN INSTRUCTION — A 50-POINT POOL DRAINING AT 40/s**,
i.e. **1.25 s of sprint**, down from 5.0 s. 🧑 specified the drain as *"10 Stamina
Points every 0.25 seconds"*; it is implemented as a continuous 40/s, which spends the
identical 10 points per quarter-second held and cannot be feathered by tapping Shift
on a sub-tick rhythm.

⚠️ **FATIGUE NOW LOCKS REGEN, NOT JUST SPEED.** Reaching 0 costs 2.0 s at 0.75 speed
with sprint locked out **and the bar refusing to refill at all**. Previously it
refilled at full rate during the penalty, so the punishment did not touch the
resource it was punishing.

**Fatigue rides the speed-zone stack** (`enter_speed_zone`/`exit_speed_zone`) rather
than being multiplied in, so it composes with a hazard zone instead of one silently
winning.

## 4 · Controls

| Input | Action |
|---|---|
| **WASD** | 8-way movement |
| **Shift** | sprint |
| **Space** | jump |
| **Left-click** | hold to charge a throw, release to throw |
| **E** | contextual — see below |

⚠️ **E DOES THREE JOBS AND PICKS BY WHAT IS IN FRONT OF YOU.** The GDD gives it all
three; rather than inventing two more keybinds for a game whose brief is "simpler", the
press resolves against context. `carrier.gd` gets first refusal, and only a press
neither pickup nor channel consumed reaches the shove.

| Press | Condition | Result |
|---|---|---|
| **E tap** | Attacker, loose slipper within `PICKUP_RADIUS` | **pick up** |
| **E tap** | Attacker, nothing grabbable | **shove**, instantly |
| **E hold 1.5 s** | Defender, in the lata's ring, lata down | **reset the lata** |
| **Right-click** | Defender | hold 0.5 s to charge, release to **lunge** and tag |

## 5 · The Attacker (three players)

### 5.1 · The throw

| Constant | Value | Where |
|---|---|---|
| `CHARGE_FULL_TIME` | **2.5 s** | `carrier.gd` |
| `CHARGE_MIN_POWER` | 0.35 | a tap still throws |
| `THROW_LOCK_TIME` | **1.25 s** | after a pickup; ÷ the tsinelas' GRIT (§9) → 1.03–1.42 s |
| `LAUNCH_SPEED` | **17.0 m/s** | at full charge, `slipper.gd`; × the tsinelas' SPEED (§9) → 16.15–17.85 |
| `PICKUP_RADIUS` | 1.4 | |
| `MUZZLE_FORWARD` | 0.15 | |
| `HIT_RADIUS` | 0.23 | the slipper's contact radius |
| `MAX_FLIGHT_TIME` | 6.0 s | |
| `THROWER_IGNORE_TIME` | 0.25 s | you cannot block your own throw on release |

**All four of these must hold or the throw is refused** (`RoundManager.can_throw()`):

1. holding a slipper;
2. the lata is **upright**;
3. **outside the box** — `max(|x|,|z|) >= 5.0`;
4. the post-restore cooldown has expired.

⚠️ **THE CROSSHAIR ASKS THE SAME FUNCTION.** It is shown only when a throw would
actually be accepted, so it greys out for exactly the reasons the throw refuses. A
second opinion about legality is a crosshair that promises a throw the rules then
refuse, which is the most confusing possible failure — the player sees no reason for
nothing to happen.

⚠️ **THE THROW LEAVES FROM THE SIGHT LINE, NOT THE HAND.** Measured: leaving from the
hand, the flight sags **0.38–0.43 m** below the line the player is aiming along, peaking
within 0.2 m of them — the slipper drops out of the bottom of the screen the instant it
is released. From the sight line it is **0.001–0.043 m**. The path was right; the
starting height was not.

⚠️ **`THROW_RESTORE_COOLDOWN` 1.25 s.** After the taya stands the lata back up, nobody
may throw. It stops the lata being re-knocked by a slipper already charged and waiting
on the last frame of the reset channel.

### 5.2 · Retrieval and vulnerability

* ⚠️ **A SLIPPER BELONGS TO ONE ATTACKER AND NOBODY ELSE MAY TOUCH IT.** Reversed
  2026-08-01 (🧑: *"Each slipper is uniquely color-coded and tied strictly to its
  owner. Opponents cannot pick up or tamper with another player's slipper."*). The old
  any-attacker rule quietly deleted the three-way rivalry — if any slipper serves any
  attacker, the nearest is always correct and there is nothing to contest. Ownership is
  also what makes the floor glow and the foot arrow well-defined.
* **An Attacker inside the box is 100% safe until they pick a slipper up.** Once
  `holding_slipper` is true they can be tagged, until they cross back out.
* `CharacterBase.is_taggable()` is that entire rule, in one function, read by both the
  tag and the HUD's `VULNERABLE` row — so the warning the player sees cannot disagree
  with the rule that tags them.

### 5.3 · The shove

| Constant | Value |
|---|---|
| `SHOVE_CHARGE_TIME` | **0.0 s** — single tap |
| `SHOVE_SPEED` | **12.247 m/s** → **2.50 m** by v²/60 |
| `SHOVE_LIFT` | 2.2 |
| `SHOVE_STUN` | **1.25 s** |
| `SHOVE_STAMINA_COST` | **25.0** |
| `SHOVE_COOLDOWN` | **7.5 s** |
| `SHOVE_RANGE` | 1.6 m |
| `SHOVE_ARC_DEG` | 70° half-angle |

**Attackers shove Attackers.** The Defender cannot be shoved and cannot shove — they
have the tag, and giving them both would make the box unenterable.

⚠️ **7.75 IS SALVAGED, NOT RE-DERIVED.** The GDD asks for 1 metre of knockback. The
deleted power bump was already tuned to 7.75 m/s against `FRICTION` 30, and
`distance = v²/60` — so 7.75 *is* one metre on this exact friction model.

## 6 · The Defender (the taya)

* **Body-block.** Physically stop a slipper before it reaches the lata. It deflects out
  of the box, and **it pushes you** — see 6.1.
* **Reset the lata.** Stand in the ring, hold **E** for `RESET_CHANNEL_TIME` **1.5 s at
  neutral**, divided by the can's own SPEED (§9): 1.30 s on PASIP, 1.79 s on BOYBEN.
  It goes back on its mark **and then** stands up, in that order — a lata that stands
  up where it was knocked to is a lata the next throw cannot miss. Letting go zeroes the
  channel.
* **Tag.** Touch any Attacker in the box who is holding a slipper, while the lata is
  upright.

| Constant | Value |
|---|---|
| `LUNGE_TAG_RADIUS` | **1.3 m** — swept every frame the lunge is live |
| `TAG_STUN_TIME` | **5.0 s** |
| `RESET_CHANNEL_TIME` | **1.5 s** at neutral, ÷ the can's SPEED |
| `BLOCK_KNOCKBACK_SPEED` | **4.583 m/s** → **0.35 m**, × the tsinelas' POWER |

⚠️ **`RoundManager.TAG_RADIUS` 1.1 IS DELETED, 2026-08-01.** It was the passive
proximity tag's reach, that tag was replaced by the lunge on the same day, and grep
showed the const had no reader left — only its own doc comment. It was never in this
file, which is the tell: **a shipped number the balance source of truth does not list is
a number nobody can reconcile.** Left in place, "the tag radius" resolved to 1.1 in
`round_manager.gd` and 1.3 in `character_base.gd`.

### 6.1 · A block costs the taya position

⚠️ **§2.11 / §2.22 — THE BODY BLOCK NOW DOES SOMETHING TO THE BLOCKER.** Body-blocking is
the taya's entire passive verb and until 2026-08-01 the only thing it produced was a
sound at a world position: no flash on the body that made the block, no recoil, nothing
at all on the blocker's own screen. A verb with no feedback is a verb the player cannot
tell they performed, which is why §2.11 and §2.22 were the same complaint written from
two sides.

The blocker now takes a **0.35 m push along the slipper's line of travel** plus a hit
flash and, for the blocker only, a camera shake. Scaled by the THROWER's tsinelas POWER
and divided by the BLOCKER's own person GRIT, so both stat tables are live in one
contact (§9.2).

⚠️ **A PUSH AND NOT A STUN, AND THAT WAS A DELIBERATE REVERSAL.** `apply_stagger()` was
the obvious way to make a block cost something and it is wrong here: three attackers
throwing at one box would chain stuns onto the defender, and `max()` bounds the DURATION
of one stun without bounding how often the next one starts (§11). Knockback costs the
taya **position**, which is the resource the body block is actually about, and it cannot
lock anybody out of the game.

⚠️ **DERIVED FROM `FRICTION`, LIKE EVERY OTHER IMPULSE IN THE GAME.**
`v = sqrt(0.35 × 60) = 4.583`. Move `FRICTION` and this number is wrong.

⚠️ **NO HITSTOP ON A BLOCK.** `_flash_hit()` also fires `_hitstop()`, which writes
`Engine.time_scale` globally for 60 ms — fine for a shove on a 7.5 s cooldown, wrong for
something that can happen every few frames.

**Tag penalty:** the Attacker is teleported to the Safe Zone and stunned 5 s.

⚠️ **REVERSED 2026-08-01 — THE SLIPPER GOES HOME WITH THEM, AND IT IS AN ANTI-CAMPING
RULE.** 🧑: *"The Attacker spawns with their slipper already back in hand (eliminates
Danger Zone slipper camping)."* The old rule compounded with itself: every tag left
another slipper inside the box, so a taya who tagged well ended up standing on a heap
of them. The penalty that remains is real — the safe-zone teleport, 5 s stunned, and
the whole trip to make again.

⚠️ **THE TAG IS NO LONGER PASSIVE — IT IS THE LUNGE.** Replaced 2026-08-01. It used to
fire every physics frame on adjacency, with no input and no animation: 100 points for
standing close enough. It is now charged on right-click (`LUNGE_CHARGE_TIME` 0.5 s),
released as a **2.5 m dash** (`LUNGE_SPEED` 12.247, the same `v²/60` solve the shove
uses), and any vulnerable Attacker swept inside `LUNGE_TAG_RADIUS` during
`LUNGE_ACTIVE_TIME` 0.45 s is tagged. `LUNGE_COOLDOWN` 1.5 s. The sweep runs **every
frame the lunge is live**, not once at the end, or a 2.5 m dash at 60 Hz tunnels past
a body standing halfway along it.

⚠️ **A BLOCKED SLIPPER DEFLECTS, IT DOES NOT DROP DEAD.** `DEFLECT_SPEED_SCALE` 0.62 of
`LAUNCH_SPEED`, lifted by 5.0, directed **away from the blocker** rather than mirrored —
a true reflection sends it wherever the incoming angle points, which is as often as not
deeper into the box, i.e. the clustering this exists to remove.

⚠️ **AND A SLIPPER THAT SIMPLY LANDS NOW MAKES A SOUND — §2.17, fixed 2026-08-01.**
`slipper_land` had been registered in `audio_manager.gd` with a mix level of its own
since the sound pass and had **never had a caller**. A throw that hit a body played
`hit_body`, a throw that hit the can played `can_knockdown`, and a throw that simply
missed — *by far the most common outcome, 38 of 71 flights in the baseline* — landed in
total silence. The one shot whose result the attacker most needs to hear was the one
shot the game said nothing about. It is a parameter on the landing RPC rather than a
line inside `_apply_landed()`, because that function is shared with the round reset,
which teleports three slippers home on one frame.

⚠️ **CONTACT IS A DISTANCE CHECK ON THE HOST, NOT AN `Area3D`.** So is slipper contact,
and so is the reset ring. An overlap fires on whichever peer owns the body — `hit_probe`
measured the consequence directly: **16 of 36 overlaps did not land, split by target**.
Sixteen distance checks a frame on the host is cheaper than one correct networked
overlap, and it can only happen where the score is written.

## 7 · The lata

| Constant | Value |
|---|---|
| `INTERACTION_RADIUS` | 1.6 m |
| `DOWNED_TILT_DEG` | 88° |
| `TOPPLE_TIME` | 0.22 s |
| `HIT_MARGIN` | **0.30 m** — the scoring window, ÷ the can's GRIT |
| body cylinder | **measured off the worn mesh**, per skin |

### 7.1 · The hit window is not the collider, and that is the fairness ruling

⚠️⚠️ **THE NUMBER THAT DECIDES EVERY KNOCKDOWN IN THE GAME WAS AN UNNAMED LITERAL IN
ANOTHER FILE UNTIL 2026-08-01.** A thrown slipper connects when its flat distance to the
can is inside `Slipper.HIT_RADIUS + Lata.HIT_MARGIN` = **0.53 m** at neutral, tested per
physics frame, host-side. This table used to list a *"hurtbox 0.30 r / 0.70 h"* and
`Lata.tscn` carries an `Area3D` authored to exactly that — and **grep found no reader for
either**. The rule ran off a bare `0.30` typed into `slipper.gd`. Three numbers that were
supposed to be one; the balance source of truth documented a shape the game never
consulted. `HIT_MARGIN` is that number, named, and **0.30 is unchanged** — every
measurement on the board was taken against this window and still is.

⚠️ **THE `Area3D` IS DEAD AND IS FILED, NOT DELETED** (§5.23). Removing it means editing
`scenes/objects/Lata.tscn`, which is 🎨 `build model`'s row.

⚠️⚠️ **THE SCORING WINDOW IS SKIN-INDEPENDENT EXCEPT THROUGH A DECLARED STAT, AND THE
COLLIDER IS NOT.** The four cans measure **0.108 to 0.143** in radius — a 32% spread.
Deriving the scoring window from that geometry would make the prettiest can quietly the
hardest to hit with nothing on screen saying so. A competitive difference between
cosmetic picks has to be **declared**, and the CHARACTER screen's GRIT meter declares it:
DECADES (grit 5) shrinks the window 12.3% to 0.493 m total, PASIP (grit 1) opens it to
0.579 m. *Verified live: a slipper flown 0.536 m past the can puts PASIP over and misses
DECADES (`tools/trait_probe.tscn`), and goes red on the old literal.*

⚠️ **§2.23 CLOSED — THE PHYSICAL COLLIDER NOW FOLLOWS THE MESH.** `Lata.tscn` carried ONE
cylinder at r 0.13, the **mean** of the four cans, so it was wrong for all four and worst
on PASIP at **22 mm** — a player stopped a fifth of a can early on the slimmest skin.
`lata.gd::_fit_collision_to_mesh()` measures it off the worn mesh's own AABB, in the same
place the topple lift is re-measured, so the two cannot drift. Safe to write because
`Lata.tscn` marks the shape `resource_local_to_scene`. Fitted at `_ready()` too, because
the default mesh is PASIP — the worst case was exactly the can nobody picked.

⚠️ **THE BIGGER WINDOW SURVIVES THE REWRITE.** 🧑 2026-07-31: *"make can's hitbox larger
it's ass to hit it bro."* `HIT_MARGIN` 0.30 against a body radius of 0.108–0.143 is that
generosity, and it is now the only place it lives.

⚠️ **A TOPPLED CAN IS LIFTED BY ITS OWN RADIUS, AND THAT IS LOAD-BEARING.** The
tilt rotates the visual about its BASE, so a lying-down cylinder's axis would sit
at floor level and half the can would be underground — reported directly (🧑:
*"the cans are phasing thru the floor"*). `lata.gd` measures the lift off the
mesh's own AABB so it follows the skin. **Verified: `tools/models/lata_floor_probe.gd`
reports all four skins at +0.0001 or better, upright and downed** — it exits
non-zero if any skin sinks, so re-run it after touching a profile or the topple.

`is_upright` gates **four** separate rules: the throw, the tag, passive scoring and the
reset channel. It is host-authoritative and replicated through an **explicit RPC, not a
`MultiplayerSynchronizer` property** — a synchronizer writes a property directly, so a
setter's `signal` never fires on the peer that *received* it. That exact defect cost a
whole session on 2026-07-30 (one setter, three symptoms).

**The bigger hurtbox survives the rewrite.** 🧑 2026-07-31: *"make can's hitbox larger
it's ass to hit it bro."* Body radius stays 0.14; the hurtbox is what you hit.

## 8 · Scoring

| Event | Points | To |
|---|---|---|
| Knock the lata down | **+100** | the thrower |
| **Sabotage** — shove an Attacker who is tagged within 2.5 s | **+50** | the shover |
| Tag a vulnerable Attacker | **+100** | the Defender |
| Passive defence, per 1.0 s the lata is upright | **+10** | the Defender |

Highest cumulative score at the end of round 4 wins. A tie at the top reports
`winning_slot = -1` and is an honest draw.

⚠️ **EVERY POINT IN THE GAME IS AWARDED IN ONE FILE**, host-side, through
`MatchManager.add_score()`. The predecessor spread its win conditions across four files
and the recurring bug class was a rule that fired on the wrong peer. A point that can
only be created in one function cannot be created on a client at all.

⚠️ **`SABOTAGE_WINDOW` 2.5 s IS A GUESS AND HAS NEVER BEEN MEASURED.** ⚠️ It also
almost never fires: **0 sabotages in every whole-match run taken on 2026-08-01**, across
`ai_probe` at three tiers and `fair_probe` at three policies. Measuring the WINDOW needs
the event to happen first, so this is blocked on frequency, not on the number.

### 8.1 · Passive defence is not broken, and the alarm's own word was the error

⚠️⚠️ **§2.1 IS SETTLED, 2026-08-01, AND THE ANSWER IS: DO NOT MOVE THE NUMBER.**

This paragraph used to read *"90 uncontested seconds is 900 points ... a taya who is
simply never challenged out-scores three attackers who each land a throw ... the single
most likely thing to be wrong in the whole table."* The arithmetic was right. The
conclusion was wrong, and the load-bearing word was **uncontested** — which is simply
not a state this game has.

`tools/fair_probe.tscn` was built to produce the player the arithmetic warns about: a
taya that guards the can from the shipping bot's own post and resets it the instant it
goes down, but **never lunges**. Three policies, one whole 4-round match each, attackers
at NORMAL, mean physics step verified at 0.0167 s:

| taya policy | can upright | DEFENSE/round | of the theoretical 900 | DEFENSE share | TAG |
|---|---|---|---|---|---|
| **`idle`** — presses nothing | **4.7%** | 38 | **4%** | 27.3% | 0 |
| **`turtle`** — guards + resets, never lunges | 86.2% | 733 | **81%** | **47.8%** | 0 |
| **`bot`** — plays the game | 86.5% | 743 | **83%** | 39.2% | 1700 |

**Three things fall out, and together they close the item.**

1. **Nothing about the term is uncontested.** A taya who does nothing collects **38 of
   the 900 — four per cent** — because the attackers put the can down and it stays down:
   upright **4.7%** of the round. The +10/s is not income, it is the **prize for keeping
   the can standing**, and it is paid out in full only to a taya who actually works.
   Measured spread across seats in a real match: **600–900 per round**, a 33% swing that
   is entirely defensive skill.

2. **Playing strictly dominates hiding.** `turtle` and `bot` collect the *same* passive
   income (2930 against 2970 over a match — inside the noise), because the tag does not
   compete with defence, it stacks on top of it. So refusing to play forfeits **1700
   TAG points and gains nothing at all**. There is no passive exploit to close because
   the passive line is not on the frontier.

3. **The rotation caps it structurally.** Everyone is taya exactly once (§1), so the
   most passive defence anybody can bank is one round of it. In the `turtle` run the
   seat with the HIGHEST passive share — P4 at 68.4% — finished **last** (950), and the
   winner (P3, 2200) took 59% of its points from knockdowns.

⚠️ **THE NUMBER STAYS AT +10/s.** Lowering it would have been tuning against an
arithmetic worst case that the game cannot actually reach, and it would have flattened
the one thing a taya is scored on. `fair_probe` gates the finding at **DEFENSE ≤ 50% of
all points under `turtle`** — it measured 47.8%, deliberately close to the line, so a
future change that inflates the passive term goes red instead of going unnoticed.

⚠️ **STILL NOT MEASURED: A REAL HUMAN.** `turtle` is the best passive game the *rules*
allow, not the best a person would find. What it does establish is that the degenerate
strategy the arithmetic predicted is dominated, which is the part that mattered.

## 9 · Traits and skins

Per point: **speed ±5%, power ±7%, grit ±7%**, on 1..5 with **3 neutral**. Narrow on
purpose — a pick must be a personality, not the correct answer. One conversion for all
three tabs: `CharacterRoster.trait_scale(points, per_point)`, and neutral is exactly
1.0 by construction, which is what makes "no pick", "an AI seat" and "a peer on an
older build" all play the same game.

⚠️ **ALL THREE TABS REACH GAMEPLAY SINCE 2026-08-01. §2.8 IS CLOSED AND THE ANSWER WAS
YES.** 🧑: *"also make sure the stats actually apply u can also change the stats around
for slippers, cans, characters, be creative with it, try to edit their descirptions too
to match the stats"*. Until this commit the six PROP stats were the exact failure THE
REACHABILITY RULE's second half describes: `CharacterRoster.prop_trait()` existed, was
documented, and had **zero callers**, while the CHARACTER screen drew three meters per
pick. Every lata played identically and every tsinelas played identically.

### 9.1 · What each meter means, per tab

A prop is not a person: a lata is a target that stands or lies and a tsinelas is
ammunition, so neither of them walks. The meters are re-read per tab.

| | **PERSON** (you) | **LATA** (your can, on the mark during YOUR taya round) | **TSINELAS** (yours, every round you attack) |
|---|---|---|---|
| **SPEED** | walk speed | ÷ `RESET_CHANNEL_TIME` — how fast you stand it back up | × `LAUNCH_SPEED` — flatter arc, less reaction time |
| **POWER** | outgoing shove impulse | × the recoil it puts on a slipper that hits it | × the push a body-block deals to the blocker |
| **GRIT** | ÷ incoming knockback and stagger | ÷ the hit window — harder to knock over at all | ÷ `THROW_LOCK_TIME` — armed again sooner after a pickup |

⚠️ **THE THREE LATA STATS ARE THREE ROUTES TO ONE GOAL, AND THAT IS THE DESIGN.** A taya
wants the can upright, because that is what passive defence is paid for (§8). GRIT
refuses the knockdown, SPEED shortens the recovery, POWER punishes the attempt by
lengthening somebody's retrieval. A can that did all three would be the correct answer.

⚠️ **THE TSINELAS' GRIT PLAYS THE GAME'S ACTUAL THESIS.** §0: *the tension is the
retrieval, not the throw*. A shorter throw lock is less time stood inside the box
`VULNERABLE`, so GRIT buys exposure back rather than buying damage.

⚠️ **TSINELAS SPEED IS DELIBERATELY THE NARROWEST STAT IN THE GAME — the table only
spans `bilis` 2..4, i.e. ±5% of `LAUNCH_SPEED`.** That ceiling is not taste.
`ai_controller.gd::_min_power_for()` inverts the range equation against
`Slipper.LAUNCH_SPEED` to decide how long to charge, so a per-skin launch speed is an
error term inside a solve that lives in another lane's file. 5% sits inside the margin
it already charges to; 20% would have made every bot holding a slow slipper fall short,
which would have read as an AI regression rather than as a balance change.

⚠️ **THE PREVIEW SCALES WITH IT.** `Slipper.launch_velocity_for()` takes the skin's
speed scale and `carrier.gd` passes the held slipper's own, so the dotted aim arc and
the flight stay one line by construction (§12, and §2.16).

### 9.2 · The tables

**LATA** — `bilis` / `lakas` / `tatag`:

| can | SPEED | POWER | GRIT | plays as |
|---|---|---|---|---|
| **PASIP** | 5 | 1 | 1 | goes over instantly, back up instantly |
| **BOYBEN PERMAGAD** | 1 | 5 | 4 | the fortress, and slow to right once it does go |
| **DECADES TUNA** | 3 | 2 | 5 | hardest can in the game to knock over |
| **LATANG KALAWANG** | 2 | 4 | 3 | middleweight; punishes the throw |

**TSINELAS**:

| slipper | SPEED | POWER | GRIT | plays as |
|---|---|---|---|---|
| **TSINELAS** | 3 | 3 | 3 | neutral, and **must stay neutral** — see below |
| **CROCS** | 2 | 5 | 2 | slow through the air, punishes a body block |
| **PANTULOG** | 3 | 1 | 5 | hits like nothing, armed again fastest |
| **IKE** | 4 | 2 | 3 | flattest, fastest arc |

⚠️ **ENTRY 0 OF EACH LIST STAYS NEUTRAL ON PURPOSE.** `_trait_value()` resolves every
missing pick to neutral, and entry 0 is what an unpicked prop wears — so giving
TSINELAS or a default can a non-neutral row would silently retune every AI seat and
every peer that never reached the CHARACTER screen.

⚠️ **TWO PERSON ROWS WERE BYTE-IDENTICAL AND ARE NOT ANY MORE.** KUYA BOY was 2/5/4
against BEBANG's 2/5/4, and MANG KANOR was 4/3/3 against ATE GIRLIE's 4/3/3 — two
characters wearing two rigs, invisible on the CHARACTER screen because the meters look
right on both. Now 3/5/3 and 5/3/2. `LOLA PACING` went 3 → 4 POWER because *"she does
not miss"* promised something the meters did not pay out. All twelve rows are distinct
and `tools/trait_probe.tscn` asserts it.

⚠️ **THE TWO TABLES COMPOSE AND NEITHER KNOWS ABOUT THE OTHER.** A body block scales by
the THROWER's tsinelas POWER and divides by the BLOCKER's own person GRIT, so a CROCS
thrown at BEBANG (grit 5) barely moves her and the same throw rocks JUN-JUN (grit 2).
*Measured: 4.238 m/s against 5.618 m/s on one blocker, `tools/trait_probe.tscn`.*

### 9.3 · Skins are picks, not geometry

**Character select keeps all three tabs** (PERSON / LATA / TSINELAS). The Person pick
drives the model and the traits; the lata and tsinelas picks drive the mesh, the tint
**and now the stats above**.

⚠️ **REVERSED 2026-08-01, ON DIRECT HUMAN INSTRUCTION — EVERY SEAT OWNS ITS OWN LATA
AND TSINELAS NOW, NOT ONE SHARED PAIR.** This used to say "pushed from the host so all
four peers see one lata" and that was the whole design: one can pick and one slipper
pick, read once from the host's own `GameLaunch`, applied to everybody. 🧑: *"allow
bots in single player to have random cans and random slippers, their respective cans
show when theyre defender, let my respective can show when im defender as well."*
Every seat — a real player's own CHARACTER-screen pick, or a bot's host-rolled random
one — now has its own can and slipper. Only one lata physically exists, so it wears
**whichever seat currently defends**, re-applied every round as the role rotates; each
slipper wears its own owner's pick. `main.gd::_seat_prop_picks` / `_refresh_seat_prop_
picks()` / `_push_prop_skins()`.

⚠️⚠️ **THAT ROTATION IS WHAT MAKES THE LATA STATS FAIR.** Your can is on the mark for
exactly the one round you defend, and every seat defends exactly once (§1). The stat
and the object are on screen together or not at all.

⚠️ **THE `ability` FIELD ON EVERY ROSTER ENTRY IS INERT.** `scripts/abilities/**` is
deleted.

**Character select keeps all three tabs** (PERSON / LATA / TSINELAS). The Person pick
drives the model and the traits above; the lata and tsinelas picks tint the real props.

⚠️ **REVERSED 2026-08-01, ON DIRECT HUMAN INSTRUCTION — EVERY SEAT OWNS ITS OWN LATA
AND TSINELAS NOW, NOT ONE SHARED PAIR.** This used to say "pushed from the host so all
four peers see one lata" and that was the whole design: one can pick and one slipper
pick, read once from the host's own `GameLaunch`, applied to everybody. 🧑: *"allow
bots in single player to have random cans and random slippers, their respective cans
show when theyre defender, let my respective can show when im defender as well."*
Every seat — a real player's own CHARACTER-screen pick, or a bot's host-rolled random
one — now has its own can and slipper. Only one lata physically exists, so it wears
**whichever seat currently defends**, re-applied every round as the role rotates; each
slipper wears its own owner's pick. `main.gd::_seat_prop_picks` / `_refresh_seat_prop_
picks()` / `_push_prop_skins()`. Out of row — this file is `build fair`'s.

⚠️ **THE "SOFT STATS" QUESTION IS OPEN.** Every roster entry — Person, lata and tsinelas
alike — already carries `bilis`/`lakas`/`tatag`. The Person ones reach gameplay. Whether
the **prop** ones should is undecided and is filed to a lane.

⚠️ **THE `ability` FIELD ON EVERY ROSTER ENTRY IS INERT.** `scripts/abilities/**` is
deleted.

## 10 · Player names

Set in Settings, capped at `PLAYER_NAME_MAX` **14** characters, sanitised once on the
host on arrival. Empty is legal and falls back to the seat label (`P1`..`P4`) through
`CharacterBase.display_name()`, so nothing that draws a name needs a null check. The
property is replicated, so a rename from the pause menu reaches every peer without
waiting for a round boundary.

## 11 · Status readability

The HUD carries a status stack, one row per live effect with its own countdown:
`STUNNED`, `DOWNED`, `FATIGUED`, `VULNERABLE`, `SHOVE CD`, `THROW CD`. **A stun the
player cannot time is a stun they cannot play around.**

⚠️ **`VULNERABLE` HAS NO COUNTDOWN AND THAT IS CORRECT** — it lasts exactly as long as
you choose to stand in the box holding a slipper. It draws as a solid bar with no timer;
printing "VULNERABLE 0.0s" would read as an effect that had already expired.

⚠️ **`apply_stagger()` USES `max()`, SO STUNS OVERLAP RATHER THAN STACK.** There is no
additive path anywhere in the game, which is what bounds a stun chain. **Its known cost:
a short stun landing inside a longer one is invisible** — a 1.25 s shove stun inside the
5 s tag penalty reads as nothing happening.

⚠️ **§2.9 DECIDED 2026-08-01: `max()` STAYS, AND THE COST IS ACCEPTED.** Three reasons,
in order of weight. **(1)** The only unbounded thing in a 1-vs-3 game is a stun chain,
and `max()` is the entire bound — an additive path would let three attackers hold one
taya, or one taya hold one attacker, indefinitely. **(2)** The specific invisible case
is the shove-inside-a-tag, and both events already announce themselves through channels
that are *not* the status stack: the shove has its own knockback, hit flash and
`bump_swing`, and the tag has its own toast. Nothing is silent; only the HUD ROW is
merged. **(3)** Fixing it properly means a status stack that can draw two rows for the
same effect, which is a `hud.gd` change — 🖥️ `build ui`'s row, not this lane's — for a
readability gain that no play report has ever asked for.

⚠️ **AND THE ONE CASE THAT WOULD HAVE MADE IT WORSE WAS DELIBERATELY AVOIDED.** The body
block (§6.1) was very nearly implemented as a short `apply_stagger()`. It is knockback
instead, precisely because a stun applied by a thrown object can arrive as often as
three attackers can throw, and `max()` bounds the DURATION of one stun without bounding
how often the next one starts.

## 12 · Removed, and why

**Recorded rather than silently dropped.** 🧑 2026-07-31: *"we're making the game way
simpler basically, there were so many skills and shit earlier, it was too complicated
and far from tumbang preso"*, and *"drop the irrelevant mechanics now like bump and shit
and slipper being a character and can being a character"*.

| Removed | What it was | Why |
|---|---|---|
| **The objects-are-players thesis** | the lata and tsinelas were full `CharacterBase` player units with lobby seats, cameras, roster entries and AI | It is not tumbang preso. Both are props now |
| **The whole ability layer** | `scripts/abilities/**` — Can-Smash, Can-Dash, Ground Smash, Quick Stand, Spin Guard, Shatter Trap, Bakya Bash, Flick Dash, + 10 `.tres` | Eight verbs nobody asked for |
| **The bump meter** | LMB-charged bump, tap/power split, the punt, the hit penalty | Replaced by the shove, which kept its impulse number |
| **2v2 and paired sets** | `SETS_NEEDED`, `ROUNDS_PER_SET`, attack-time tiebreak, `NEVER` | Four players do not have teams. The fairness property it existed to guarantee is structural now |
| **The out-of-circle countdown** | `CAN_OUT_*`, recovery stacks, `STRANDED` | It was the primary win condition of a game with win conditions. Rounds are scored, not won |
| **`FALL_LIMIT`, ring-outs, dents, the seal** | four more win conditions | Same |
| **The lob** (`bagsak`) | overhold past full charge, 60° fixed-angle solve | One throw, one arc |
| **Long-throw bonuses** | speed ×1.20, knockback ×1.25, a 5 s punish stun | |
| **Self-launch, mid-flight steer, scuffing, bouncing** | `carriable.gd` | |
| **`ThrowProfile`** | per-class launch speed, gravity, mass, spin | Every slipper flies the same way |
| **`Hitbox` / `Hurtbox`** | Area3D contact | Contact resolves by distance on the host |
| **`guard_dash` and `bump` input actions** | | Nothing pressed them. The spectator's descend key became `spectator_down` |

**Kept deliberately, and each for a stated reason:**

* **`SPAWN_SETTLE_FRAMES`** — a real, expensively-diagnosed physics fix (B-100), and
  role rotation is exactly what triggers it.
* **`_shed_character_perch()`** — you cannot stand on somebody's head. From live play,
  and *more* likely with three attackers converging on one box.
* **`_solve_arc()`** — measured, and `trajectory_preview.gd` shares it, so the aim line
  and the flight line are one line by construction.
* **The AI intent indirection** — a bot presses the same buttons a human does, which is
  the only reason one `_physics_process` serves both.
* **`CANS` / `SLIPPERS` roster tables** — the models are still wanted.
* **Spectator** — kept whole, on human instruction.
