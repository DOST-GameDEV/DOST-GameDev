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
| `THROW_LOCK_TIME` | **1.25 s** | after a pickup, before it may be thrown |
| `LAUNCH_SPEED` | **17.0 m/s** | at full charge, `slipper.gd` |
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
on the last frame of the 2.5 s channel.

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

* **Body-block.** Physically stop a slipper before it reaches the lata. A blocked
  slipper drops at the point of contact, which is the trade: the throw stopped, and the
  slipper is now deep inside the box.
* **Reset the lata.** Stand in the ring, hold **E** for `RESET_CHANNEL_TIME` **2.5 s**.
  It goes back on its mark **and then** stands up, in that order — a lata that stands
  up where it was knocked to is a lata the next throw cannot miss. Letting go zeroes the
  channel.
* **Tag.** Touch any Attacker in the box who is holding a slipper, while the lata is
  upright.

| Constant | Value |
|---|---|
| `LUNGE_TAG_RADIUS` | **1.3 m** — swept every frame the lunge is live |
| `TAG_STUN_TIME` | **5.0 s** |
| `RESET_CHANNEL_TIME` | **1.5 s** |

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
| body cylinder | **0.13 r / 0.385 h** |
| hurtbox | **0.30 r / 0.70 h** |

⚠️ **BOTH MOVED 2026-08-01 WITH THE NEW MESHES** (§5.4). There are four cans now,
built from the human's drawings at four different profiles, and `Lata.tscn`
carries ONE collision for whichever is worn — so the body cylinder is the mean
(0.13) rather than any one can's radius, and the heights follow the meshes'
0.377–0.385. The hurtbox keeps its deliberate generosity (🧑 2026-07-31: *"make
can's hitbox larger it's ass to hit it bro"*), scaled with the mesh.

⚠️ **THE WORST-CASE MESH/HITBOX DISAGREEMENT IS PASIP, AT 22 mm.** Its radius is
0.108 against the 0.130 cylinder, so a player stops about a fifth of a can early
on the slimmest skin. Filed to ⚖️ `build fair` §2.19 rather than hidden — the fix
is a per-skin collision, which needs `lata.gd`.

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

⚠️ **`SABOTAGE_WINDOW` 2.5 s IS A GUESS AND HAS NEVER BEEN MEASURED.**

⚠️ **PASSIVE DEFENCE IS A LARGE TERM AND IS UNBALANCED.** 90 uncontested seconds is
**900 points**, against 100 for a knockdown. On the numbers as they stand, a taya who is
simply never challenged out-scores three attackers who each land a throw. This is the
single most likely thing to be wrong in the whole table and it is the balance lane's
first job.

## 9 · Traits and skins

`BILIS` → `SPEED`. `LAKAS` → outgoing impulse. `TATAG` → divides incoming knockback and
shortens stagger. Per point: speed ±5%, power ±7%, grit ±7%, on 1..5 with 3 neutral.
Narrow on purpose — a pick must be a personality, not the correct answer.

**Character select keeps all three tabs** (PERSON / LATA / TSINELAS). The Person pick
drives the model and the traits above; the lata and tsinelas picks tint the real props,
pushed from the host so all four peers see one lata.

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
5 s tag penalty reads as nothing happening. Backlog.

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
