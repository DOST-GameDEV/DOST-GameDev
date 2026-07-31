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
| `CONFINEMENT_RADIUS` | **5.0** | `character_base.gd`. A **square** at \|x\| = \|z\| = 5.0 |
| `SAFE_ZONE_MARGIN` | 2.0 | Attackers spawn on a ring at 5.0 + 2.0 = **7.0** |
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

⚠️ **5.0 IS INHERITED AND HAS NOT BEEN RE-TUNED FOR FOUR PLAYERS.** It was measured for
one taya and one attacker. It now has to hold one taya against three converging
attackers. Backlog.

⚠️ **Spawns are computed from the box, not read from map markers** (`main.gd`). "Outside
the box" is the rule; a marker drifting half a metre inside `CONFINEMENT_RADIUS` would
spawn an Attacker VULNERABLE on frame one and read as a rules bug rather than a map bug.

## 3 · Movement and stamina — every player

| Constant | Value | Note |
|---|---|---|
| `SPEED` | **4.6** | walk |
| `SPRINT_SCALE` | **1.50** → 6.90 | hold **Shift**. The GDD's "+50% speed" |
| `STAMINA_MAX` | **100.0** | points, not seconds |
| `STAMINA_DRAIN_RATE` | **20.0 /s** | = **5.0 s** of continuous sprint |
| `STAMINA_REGEN_RATE` | **20.0 /s** | a full bar refills in 5.0 s |
| `STAMINA_REGEN_DELAY` | **2.5 s** | after the last sprint frame |
| `STAMINA_SPRINT_FLOOR` | 15.0 | you cannot *start* a sprint below this, so the bar cannot be feathered |
| `FATIGUE_TIME` | **2.5 s** | triggered by reaching 0 |
| `FATIGUE_SPEED_SCALE` | **0.75** | −25% speed, sprint locked out |
| `JUMP_VELOCITY` | 5.8 | |
| `GRAVITY` | 20.0 | |
| `FRICTION` | 30.0 | **knockback distance = v² / 60** |

⚠️ **THE BAR IS IN POINTS NOW AND THE NUMBERS ARE NOT A RESCALE.** It used to be
`STAMINA_MAX = 4.0` meaning four seconds. 100/20 is **5.0 s**, not 4.0.

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
| **E hold 1.25 s** | Attacker, nothing grabbable | **shove**, on release |
| **E hold 2.5 s** | Defender, in the lata's ring, lata down | **reset the lata** |

## 5 · The Attacker (three players)

### 5.1 · The throw

| Constant | Value | Where |
|---|---|---|
| `CHARGE_FULL_TIME` | 0.9 s | `carrier.gd` |
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

* Any Attacker not already holding one may pick up **any** loose slipper, and doing so
  reassigns ownership. Deliberately not "your own only": three attackers converging on
  one box land slippers in a pile, and a rule that makes you hunt for your specific one
  reads as a bug.
* **An Attacker inside the box is 100% safe until they pick a slipper up.** Once
  `holding_slipper` is true they can be tagged, until they cross back out.
* `CharacterBase.is_taggable()` is that entire rule, in one function, read by both the
  tag and the HUD's `VULNERABLE` row — so the warning the player sees cannot disagree
  with the rule that tags them.

### 5.3 · The shove

| Constant | Value |
|---|---|
| `SHOVE_CHARGE_TIME` | **1.25 s** |
| `SHOVE_SPEED` | **7.75 m/s** → **1.00 m** by v²/60 |
| `SHOVE_LIFT` | 2.2 |
| `SHOVE_STUN` | **1.25 s** |
| `SHOVE_STAMINA_COST` | **25.0** |
| `SHOVE_COOLDOWN` | **10.0 s** |
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
| `TAG_RADIUS` | 1.1 m |
| `TAG_STUN_TIME` | **5.0 s** |
| `RESET_CHANNEL_TIME` | 2.5 s |

**Tag penalty:** the Attacker is teleported to the Safe Zone and stunned 5 s.

⚠️ **THE SLIPPER IS DROPPED WHERE THEY WERE TAGGED, NOT CARRIED HOME.** That is the
point of the penalty: the retrieval run has to be made again, against a taya who now
knows exactly where you are going.

⚠️ **THE TAG IS A PROXIMITY CHECK ON THE HOST, NOT AN `Area3D`.** So is slipper contact,
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
| hurtbox | 0.28 r / 0.62 h |

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
