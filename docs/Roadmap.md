# Roadmap — from today to a submitted, genuinely fun entry

**Written 2026-07-30, against `integration` @ `9a700d1`, by reading the code and the docs, not
by reading the previous pass's checkboxes.**

This file answers a different question from every other document here:

| Document | Question it answers |
|---|---|
| `Checklist.md` | *What is left, in order?* — the status board. **Where it disagrees with anything, it wins.** |
| `Dev_Plan.md` | *How is this built and what was decided?* |
| `Art_Direction.md` | *What does it look like and why?* |
| `Handoff.md` | *What happened, and what is broken?* |
| **`Roadmap.md`** (this file) | ***What makes it good, in what order, and how do we know?*** |

`Checklist.md` is a completeness ledger — it drives toward *submitted*. This file drives toward
***fun***, and where the two disagree about priority, this file argues for its ordering and
`Checklist.md` still owns the status. Nothing here is marked done anywhere except there.

---

## Contents

- [Part 0 — The honest audit](#part-0--the-honest-audit)
- [Part 1 — The four verdicts that shape the plan](#part-1--the-four-verdicts-that-shape-the-plan)
- [Part 2 — The roadmap](#part-2--the-roadmap)
  - [Stage 0 — Instruments. Nothing downstream is trustworthy without these.](#stage-0--instruments)
  - [Stage 1 — Fairness. The single biggest gameplay problem.](#stage-1--fairness)
  - [Stage 2 — The tsinelas. Explicit human priority.](#stage-2--the-tsinelas)
  - [Stage 3 — Feel: contact, reaction, sound.](#stage-3--feel)
  - [Stage 4 — Maps, flow, and a street that reads as Filipino.](#stage-4--maps-and-flow)
  - [Stage 5 — The network under real load.](#stage-5--the-network-under-real-load)
  - [Stage 6 — Onboarding and readability under chaos.](#stage-6--onboarding-and-readability-under-chaos)
  - [Stage 7 — Ship.](#stage-7--ship)
- [Part 3 — Cut list, in cut order](#part-3--cut-list-in-cut-order)
- [Part 4 — The three biggest risks](#part-4--the-three-biggest-risks)
- [Part 5 — Decisions taken in this document](#part-5--decisions-taken-in-this-document)

---

# Part 0 — The honest audit

Three tiers of confidence are used throughout, and the distinction is the point of the audit:

| Tier | Meaning |
|---|---|
| **PLAYED** | A human pressed buttons and formed an opinion. |
| **MEASURED** | A probe under `tools/` produced a number, and the number was read. |
| **WRITTEN** | Code exists, parses, and loads. Nobody has looked at what it does. |

⚠️ **Almost nothing in this project is PLAYED.** One informal session on 2026-07-28
(`Art_Direction.md` §5) is the entire body of human play evidence, and it predates the front-end
overhaul, both maps as they now stand, the behaviour-tree AI, the audio system, the character
roster and the ready phase. Every "feel" claim in this repository is therefore an assumption.

## 0.1 · Fairness

| Claim | Tier | Evidence |
|---|---|---|
| Defence wins 100% of rounds on a real four-bot field | **MEASURED** | `Checklist.md` RUN 8, 3 × 10 rounds, Option A, scale 4, Eskinita |
| 90.5–92.0% of throws are blocked | **MEASURED** | RUN 8, all three pursuit rows |
| 0.00–0.10 dents per round; 10/10 rounds end by tag | **MEASURED** | RUN 8 |
| `taya_pursue_radius` is not the lever | **MEASURED** | swept 0.0 / 1.8 / 3.6; all three inside noise |
| RUN 7's DEF 80% / 64.1% blocked | **STALE — DO NOT QUOTE** | RUNS 1–7 measured a 3-v-4; the harness silently stopped taking over the human seat |
| `TAYA_BLOCK_STANDOFF` (2.6) is the open lever | **WRITTEN, NEVER MEASURED** | `ai_controller.gd:98`, a `const`; `tools/ai_probe.gd::_parse_args` has `rounds=`, `scale=`, `mode=`, `map=`, `pursue=` and **no `standoff=`** |
| Difficulty tiers exist | **WRITTEN** | `ai_controller.gd:175` `DIFFICULTY_TIERS` (BATA/NORMAL/ASTIG) and `apply_difficulty()` are real and complete. **Nothing calls `apply_difficulty()` outside the class**, there is no UI, and no tier other than NORMAL has ever been measured. |
| The attacker has an answer to a blocked lane | **NO** | it slides to an open bearing (`_cond_lane_blocked`) and, after `ATTACKER_PATIENCE` 2.0 s, throws into the block anyway. There is no lob, no fake, no wait-for-a-teammate, no bait. |

**The finding this audit adds:** the fairness problem has been framed as a *tuning* problem since
RUN 2, and RUN 8 says it is not. 92% blocked is not a knob being 15% off. It is a **structural
asymmetry** — the taya re-derives its post from the attacker's *current* bearing every tick, so
the only geometry that ever produces an open lane is one the taya has not reacted to yet, and the
attacker's only response to a closed lane is to wait two seconds and throw into it. Stage 1 treats
it as structural.

## 0.2 · Maps and flow

| Claim | Tier | Evidence |
|---|---|---|
| Both maps are generated wholesale by `tools/maps/build_*.py` | **MEASURED** | hand edits to the `.tscn` are destroyed on the next build; every map change is a builder change |
| Both enforce a lane law that aborts the build | **MEASURED** | `build_eskinita.py:189` (corridor), `build_bayan_plaza.py:228` (`LANE_RADIUS` 3.2 disc + `LANE_HALF_X`/`LANE_Z` approaches) |
| 8 interior footprint overlaps in Bayan Plaza | **MEASURED**, unfixed | `build_bayan_plaza.py:106`, reported by `surfaces.overlaps_across()`, pre-existing |
| The paved apron ends in a hard square at the y=30 overhead | **MEASURED**, unfixed | `Checklist.md` 10.3 |
| Bayan Plaza perf and AI are fine | **MEASURED** | `perf_probe`/`ai_probe` gained `map=` on 2026-07-29; before that every number described Eskinita |
| Either map has been judged for FLOW | **NO** | neither map has been played by a human, in any mode |
| Bayan Plaza has ever run in a networked match | **NO** | `Checklist.md` 10.3 |
| The confinement square is the right shape and size | **UNKNOWN** | it is `CharacterBase.CONFINEMENT_RADIUS` 5.0, read by both builders. Its shape was a correctness fix (RUN 3), not a design decision, and its *size* has never been varied. The tutorial deliberately prints no number because the GDD says 3 and the code says 5. |

## 0.3 · Models and assets

| Claim | Tier | Evidence |
|---|---|---|
| The tsinelas is procedural, three-layer, with real swept Y-straps | **MEASURED** | `tools/models/generate_all.gd::_build_tsinelas`, 12-point sole outline, outsole/foam/footbed at y 0.0→0.022→0.085→0.120, toe post to 0.195, two `_strap_band` arcs to a post at y 0.190 |
| It "looks too flat and awkward" | 🧑 **HUMAN VERDICT** — the only tier that outranks a measurement | verbatim ask, 2026-07-30 |
| The world model is 1.25× | **MEASURED** | `TsinelasVisual.tscn` root `Transform3D(1.25, …)` |
| ⚠️ **The FPP slipper is 1.00×** | **MEASURED, AND THIS IS A LIVE DEFECT** | `ViewmodelArms.tscn` → `RightPivot/Arm/HeldSlipper` has an identity basis. **First person already shows a slipper 25% smaller than everyone else sees**, and has since the 1.25× pass. This is exactly the half of the human's ask that names the FPP. |
| ⚠️ **`CharacterBase.TSINELAS_VISUAL_SCALE` is a DEAD CONSTANT** | **MEASURED** | `grep -rn TSINELAS_VISUAL_SCALE` returns its own declaration (`character_base.gd:407`) and its own doc comment. **Nothing reads it.** The `tsinelas` row of `_COLLISION_BY_ROLE` holds hand-derived literals, so the doc comment's claim that "both numbers move together or neither does" is **false in code** — they move together only if a human remembers. |
| The four scale sites | **MEASURED** | (1) `TsinelasVisual.tscn`, (2) `_COLLISION_BY_ROLE["tsinelas"]`, (3) `ViewmodelArms.tscn::HeldSlipper`, (4) `generate_all.gd::TSINELAS_SCALE` 0.32. Confirmed independent; **there is no probe that asserts any relationship between them.** |
| Characters are palette recolours of CC0 Kenney rigs | **MEASURED** | `assets/characters/persons/*.glb` + `KENNEY_LICENSE.txt`, `character_roster.gd` |

## 0.4 · Animations

| Claim | Tier | Evidence |
|---|---|---|
| Locomotion idle/walk/sprint selects from velocity | **MEASURED** | `character_visual.gd::_play_locomotion` |
| One-shot throw/bump/grab exist, with per-clip fallback chains | **MEASURED** | `character_visual.gd:102-111` — each action lists 3 candidate Kenney clips |
| The rig has **no** `holding-right-walk` | **MEASURED** | B-90; a carrying Person holds `CARRY_IDLE_CLIP` outright rather than walk-animating a carrying arm |
| FPP viewmodel wind-up direction is correct | **MEASURED** | B-131, `tools/windup_probe.tscn` |
| Person rig faces +Z, corrected on the MODEL node | **MEASURED** | `character_visual.gd`; ⚠️ **do not re-fix this in the yaw maths** |
| Anything has been judged for FEEL | **NO** | — |
| Reactions, the taya's reset channel, celebration | **DO NOT EXIST** | there is no getting-hit animation, no channel pose, no win pose. A tag — the event that ends 10 out of 10 rounds — has no animation on either side. |

## 0.5 · AI

| Claim | Tier | Evidence |
|---|---|---|
| Reactive behaviour tree, role re-derived every tick | **MEASURED** | `ai_controller.gd`, `BTSelector`/`BTSequence`/`BTCondition`/`BTAction` inner classes, `_validate_tree()` at build time |
| `bt_trace()` gives the branch path per tick | **MEASURED** | found B-124 inside an hour |
| Per-instance RNG, per-instance intent | **MEASURED** | co-transition rate 1/843 frames |
| Difficulty tiers | **WRITTEN, UNREACHABLE** | see 0.1 |
| Multiplayer AI fallback works | **MEASURED ON A TWO-PEER LOOPBACK PROBE ONLY** | `main.gd::_rpc_convert_to_ai` / `_rpc_reclaim_character` / `_fill_empty_slots_with_placeholders` all exist and are wired. **Never exercised with a real drop, a real rejoin, a mid-round drop, a host drop, or four real peers.** |
| `_take_over_human_slot()` is test-only and flagged | **MEASURED** | `tools/ai_probe.gd`, `fairness` mode only, one function + one call site, `tools/` does not ship |

## 0.6 · Net

| Claim | Tier | Evidence |
|---|---|---|
| ENet, host-authoritative for round decisions, client-authoritative movement, no reconciliation | **MEASURED** | replication config audited 2026-07-29: `position`/`rotation` ALWAYS-unreliable, `state`/`dents` ON_CHANGE-reliable |
| Seats survive a reconnect via a stable per-install token | **MEASURED** | `Checklist.md` 4.3, `tools/lobby_probe.gd` 21 assertions over two real instances |
| Map and mode are host-owned and broadcast | **MEASURED** | 10.5 U-8, verified with two instances started on deliberately opposite maps |
| Host quit has a story | **PARTIAL** | `_on_server_disconnected` exists (`main.gd:1678`) and routes out. **There is no host migration**, and no probe covers what a client sees mid-round. |
| Four real peers, real Wi-Fi, packet loss, latency | **NEVER RUN** | `Checklist.md` 9.6: *"Two local peers on loopback is the weakest possible network test."* |

## 0.7 · UX

| Claim | Tier | Evidence |
|---|---|---|
| Splash → menu → mode select → multiplayer setup → one shared setup screen → match | **MEASURED (render + `lobby_probe`)** | 10.5 |
| Tutorial exists, 8 pages, numbers read out of the code | **MEASURED (render)** | `Tutorial.tscn`, `tools/ui/tutorial_shot.tscn` |
| HUD matches `Dev_Plan.md` §4.4 | **MEASURED (render)** | Bo5 pips, role-coloured panels, urgency timer, LATA card, YOU card, FPP-only crosshair |
| Role-swap card runs the full §4.6 timeline | **MEASURED (render)** | `RoleSwapCard.tscn` |
| Anyone has clicked any of it | **NO** | 10.5 and 10.5.1 both say so in capitals |
| It works at any resolution but 1920×1080 | **UNKNOWN** | 10.5.1's own caveat |
| ⚠️ `FoldCorner` in `SettingsPanel.tscn` is a bare `Control` carrying a `canvas_item` shader | **MEASURED** | a bare Control draws nothing; the shader has never run anywhere. Dead node. |

## 0.8 · Physics

| Claim | Tier | Evidence |
|---|---|---|
| The charge-throw solves a real ballistic arc through the crosshair point | **MEASURED** | ballistics re-measured 2026-07-29; every profile reaches the 6.0 line; scatter ≈ 0 |
| Per-throw hitbox from the ThrowProfile; one hit per offensive event per target | **MEASURED** | `_spawn_flight_hitbox()` inside `host_throw`; ⚠️ this is the hitbox `ai_probe` was blind to for every run before RUN 2 |
| Terminal-velocity cap + 8-unit floor colliders prevent tunnelling | **MEASURED** | `phys_probe`: min slipper Y 0.245 vs floor 0.100, never out of bounds |
| A defender can step on / body-check a loose opponent slipper | **MEASURED** | B-135/B-136 |
| The can dodges on 56% of in-flight frames, up to 1.41 m | **MEASURED** | `phys_probe` |
| `CAN_EVADE_MISS_MARGIN` 0.55 (from 1.0) | **MEASURED**, human call | RUN 7 |
| ⚠️ `CAN_EVADE_LOOKAHEAD` is **not** a tunable lever | **MEASURED** | the sweep is non-monotonic: 1.10 → 18 contact frames, 0.85 → 57, 0.70 → 0. **Do not tune it.** |
| Bounce, landing, knockback ceilings, guard, the lucky-fall roll have been judged | **NO** | all WRITTEN |

## 0.9 · Audio

| Claim | Tier | Evidence |
|---|---|---|
| Every SFX is procedural — numpy/scipy, no recordings, one licence row | **MEASURED** | `tools/audio/generate_sfx.py` |
| 33 sounds, pooled voices, retrigger guard, bus limiter, 2 ambience loops, boot sting | **MEASURED** | `audio_probe` 25 checks, `audio_mix_probe`, `audio_combat_probe`, `audio_load_probe` |
| Lata impact is frame-synced to hitstop | **MEASURED** | 4.1 |
| ⚠️ **The mix has never been heard by a human** | **STATED IN THE REPO IN CAPITALS** | `Checklist.md` audio row |
| Music | **DOES NOT EXIST** | there are Music buses and no music |

---

# Part 1 — The four verdicts that shape the plan

**1. The fairness problem is structural, not a tuning problem.** RUN 8's 92% block rate is not a
knob 15% off its mark. Stage 1 changes what the attacker *can do*, and what winning *means*, before
it touches a number. The standoff sweep still runs — it is one hour and it has been owed since
RUN 3 — but the plan does not depend on it succeeding.

**2. Nothing in this project has been PLAYED, and the plan must stop pretending otherwise.** Every
stage below carries a 🧑 human play gate that other work is genuinely blocked on, not a hopeful
"someone should play it" footnote. The single highest-value hour available is still 0.4.

**3. The slipper is the one piece of the game a judge looks at for the whole match.** It is in
flight, in a hand, on the ground and at the bottom of the local player's screen, continuously. The
human called it flat and awkward and the human is right; and the audit found a second defect nobody
had noticed — **first person is already showing a different, smaller slipper than everybody else.**

**4. Two maps that nobody has played is worse than one map that plays well.** A third map is
**CUT** (Part 5). Bayan Plaza survives on the condition that it gets networked and flow-judged; if
it fails that gate it is cut too, per `Checklist.md`'s own "If time runs short" §1.

---

# Part 2 — The roadmap

**Effort key:** **S** ≤ half a session · **M** one session · **L** two-plus sessions · **XL** a
lane's whole first sitting.

**Ordering is by dependency and by risk reduction, not by ease.** Where two items are independent,
the earlier one is the one whose failure would invalidate more downstream work.

**Every item states the pillar it serves.** The pillars, restated: **[1] Filipino roots ·
[2] our own mechanics · [3] low-poly aesthetic · [4] chaotic friendslop.**

---

<a id="stage-0--instruments"></a>
## Stage 0 — Instruments. Nothing downstream is trustworthy without these.

This project has now lost **three** sessions to a probe that measured the wrong thing (spawn_probe
on the local path; ai_probe blind to the flight hitbox; ai_probe silently measuring a 3-v-4). Stage
0 is the tax that stops the fourth.

### R-01 · Make `TAYA_BLOCK_STANDOFF` sweepable · ⚖️ BALANCE · **S**
- **Problem.** The lever flagged since RUN 3 as the obvious suspect has never been measured because
  it is a `const` and `ai_probe` has no argument for it.
- **Fix.** Promote `ai_controller.gd:98` to `static var taya_block_standoff` (keeping the `const`
  as the documented NORMAL baseline, exactly as `DECISION_INTERVAL` already does), add
  `standoff=` to `tools/ai_probe.gd::_parse_args`, and print it in the run header next to
  `taya_pursue_radius`.
- **Pillar.** [2] [4]
- **Acceptance.** `godot --path <abs> tools/ai_probe.tscn -- fairness rounds=20 scale=4 standoff=1.4`
  runs, and the header line reports `taya_block_standoff 1.4`. A sweep over
  `{1.0, 1.4, 1.8, 2.2, 2.6, 3.2, 3.8}` at 20 rounds each is logged as **RUN 9** in
  `Checklist.md` §Phase 9, with the dents column read *first*.
- **Depends on.** Nothing. **Do this first.**

### R-02 · The probe-honesty contract, enforced in code · ⚖️ BALANCE · **S**
- **Problem.** RUN 8 caught the harness measuring a 3-v-4 only because someone looked. Trap 2 has
  now cost this project two sessions.
- **Fix.** Every fairness run asserts, and prints, three things it currently assumes: (a) the number
  of genuinely AI-**driven** units is 4 (already added — keep it and add the same shape elsewhere),
  (b) `GameLaunch.game_mode` and the map actually in the tree, (c) **that the attacking side
  changed hands across the run** — a run in which one team was always the attacker is not a fairness
  measurement. `push_error` on each, so a future change breaks loudly.
- **Pillar.** [2]
- **Acceptance.** Deliberately break each of the three (park a unit, force one mode, pin the role
  swap) and confirm the run refuses. Attach the three refusal outputs.
- **Depends on.** R-01 (same file, same sitting).

### R-03 · One constant that owns the slipper's size · 🩴 ART-FEEL · **S**
- **Problem.** `CharacterBase.TSINELAS_VISUAL_SCALE` is **dead** — nothing reads it — while four
  independent sites carry the scale by hand. A previous pass had to touch all four and got three of
  them; first person is still at 1.00× against the world's 1.25×.
- **Fix.** Make the constant load-bearing: `_apply_role_collision()` multiplies the `tsinelas` row's
  five numbers by it at apply time (store the row as the **unscaled** profile), `TsinelasVisual.tscn`
  and `ViewmodelArms.tscn::HeldSlipper` both read it, and `generate_all.gd::TSINELAS_SCALE` is
  cross-checked against it. Where a scene cannot read a script constant, a two-line `_ready()` that
  writes `scale` from it is correct and is preferred over a baked transform.
- **Pillar.** [2] [3]
- **Acceptance.** **New probe `tools/prop_scale_probe.tscn`** which, in one render run, asserts:
  world slipper bounding-box length == FPP slipper bounding-box length == mesh length ×
  `TSINELAS_VISUAL_SCALE`, and that the `tsinelas` hurtbox radius is within 20% of the mesh's own
  half-width. **Then change `TSINELAS_VISUAL_SCALE` to 1.6 and re-run: every assertion must still
  hold, with no other file edited.** That last sentence is the whole acceptance test.
- **Depends on.** Nothing. Runs in parallel with R-01.
- ⚠️ `character_base.gd` is a **shared-lock** file — claim it in `SHARED_LOCKS.md` first.

### R-04 · 🧑 **HUMAN — play a full Bo5 on both maps, both modes.** · **M**
- **Problem.** `Checklist.md` 0.4 has been the top open item for four passes. Every "feel" item
  below is a guess until it is done.
- **Fix.** Play it. Single Player is enough for the first pass; the AI seats are real. Carry a
  slipper, charge and release at several arcs, miss and retrieve, get tagged mid-carry, crawl a
  loose slipper home, hold the reset channel and be interrupted, win a round, watch the swap.
- **Pillar.** all four.
- **Acceptance.** A written note **per number** — too fast / too slow / right — into
  `Handoff.md` §5. Nothing else.
- **Blocks.** R-12, R-13, R-14, R-17, R-21, R-25, R-27. Those items may be *specced* before it and
  must not be *tuned* before it.

---

<a id="stage-1--fairness"></a>
## Stage 1 — Fairness. The single biggest gameplay problem.

⚠️ **The framing changes here.** RUNS 1–8 treated fairness as tuning. It is not. A 92% block rate
means the attacker's only plan is defeated by the defender's only plan, deterministically. The
first three items give the attacker plans the taya's post does not answer; the fourth asks whether
the win condition itself is the imbalance.

### R-05 · RUN 9 — the standoff sweep, and read it honestly · ⚖️ BALANCE · **S**
- **Problem.** See R-01. It has been owed since RUN 3.
- **Fix.** Run it. Log it. **Do not stack a second nerf on top** if two metrics move opposite ways
  — RUN 7's own warning.
- **Pillar.** [2]
- **Acceptance.** RUN 9 in `Checklist.md` §Phase 9 with all five metric columns and an explicit
  verdict sentence: *"the standoff is / is not a lever, and here is the number that says so."*
  A headline number is re-run at `scale=1` before it is written as final.
- **Depends on.** R-01, R-02.

### R-06 · Give the attacker a second verb: **the lob (`bagsak`)** · ⚖️ BALANCE + 🥊 PHYS · **M**
- **Problem.** The attacker has exactly one answer to a blocked lane — wait 2 s and throw into it —
  and 92% of throws die there. A body-block that cannot be gone *over* is not a block, it is a wall.
- **Fix.** The high arc already exists in the ballistics solver; what does not exist is a way to
  *choose* it under pressure and a reason to. Bind the lob to the existing aim: **charge held past
  the full-power point rolls into a `bagsak` lob** — steeper arc, longer flight, lands short of a
  body-block, and **arrives slowly enough that the can's evasion can beat it**. That last clause is
  the balance: the lob beats the taya, the dodge beats the lob, the flat throw beats the dodge. A
  triangle, not a strictly better shot. The AI's `_cond_lane_blocked` branch gains a *third* option
  beside slide and throw-anyway: lob.
- **Pillar.** [2] deepens the charge-throw and the three throw identities rather than replacing
  them; [1] `bagsak` is already this project's word for a heavy dropping throw; [4] a lob over a
  defender's head is the single funniest thing that can happen in this game.
- **Acceptance.** `tools/hit_probe.tscn -- --host target=can standoff=2.6` — a taya parked exactly
  in the lane — reports **≥ 40% contact for the lob** against the measured **≈ 8%** for the flat
  throw, *and* `phys_probe` shows the lob's flight time is long enough that `CAN_EVADE_LOOKAHEAD`
  (0.6 s) actually sees it. Then a full 20-round `ai_probe` fairness run with the AI allowed to lob:
  **block rate must fall below 70%** or the item has failed and is reverted, not re-tuned.
- **Depends on.** R-05 (so the lob is measured against a known baseline, not a moving one).
- ⚠️ **Do not add a new input action.** The charge is already an analogue hold; the lob is a region
  of it. A fourth button on a four-player party game is a fifth thing to explain in the tutorial.

### R-07 · The taya's post must be *committed*, not re-derived every tick · ⚖️ BALANCE · **M**
- **Problem.** `_act_taya_block` recomputes its post from the attacker's *current* bearing every
  tick, so the lane is re-closed the instant the attacker arrives anywhere. That is not a defender
  reading a threat; it is a lane that cannot be beaten by movement, only by patience — which is
  precisely the shape of B-124's livelock, surviving as a balance problem instead of a hang.
- **Fix.** Commit the post for a reaction window (a `tier_think`-scaled hold, ~0.25–0.5 s) and
  require the attacker's bearing change to exceed a threshold before re-posting. **A defender that
  can be wrong-footed is the whole point of a feint**, and it gives the attacker's existing
  bearing-slide behaviour something to actually earn.
- **Pillar.** [2] [4] — a taya you can juke is a taya four friends will shout about.
- **Acceptance.** 20-round `ai_probe` fairness run: **block rate ≤ 60%** and **dents/round ≥ 0.5**,
  with `bt_trace()` output attached showing at least one round in which the attacker's slide beat
  the post. ⚠️ Longest still-run must not regress past 2.0 s — it has moved independently of
  everything else for three consecutive runs and is due its own `bt_trace()` pass regardless.
- **Depends on.** R-05.

### R-08 · Ask whether the round-win condition is the imbalance · ⚖️ BALANCE · **M**
- **Problem.** A tag by the defending Person ends the round **outright** (`hitbox.gd`'s rule), and
  10/10 rounds end that way. The defence therefore has a one-shot instant win and the offence has
  a repeated-success win. Those are not symmetric objectives and no amount of knob-turning makes
  them one.
- **Fix.** Measure three variants against the same harness and pick on the numbers, not on taste:
  1. **A tag costs the attacker its slipper and a respawn, not the round** (the round ends on the
     clock or on the dents). The tsinelas becomes the currency; the retrieval scramble becomes the
     game, which is what the real street game actually is.
  2. **A tag ends the round only while the attacker is inside the confinement box** — i.e. only
     during retrieval, which is where the exposure genuinely is (RUN 6 already established that).
  3. Unchanged, as the control.
- **Pillar.** [1] the real tumbang preso is *about* the scramble to retrieve, and variant 1 puts
  the scramble at the centre; [2] it deepens the retrieval scramble instead of replacing anything.
- **Acceptance.** A three-row RUN 10 table, 20 rounds each, with win rate, dents/round, throws
  taken, block rate, ended-by, and **average round duration** (new column — a variant that fixes
  the win rate by making rounds twice as long has failed pillar 4). 🧑 **The pick is a human call**;
  the lane produces the table and a recommendation, and does not decide.
- **Depends on.** R-05. Independent of R-06 and R-07 — run it in parallel and combine the winners.

### R-09 · Difficulty tiers made player-facing · ⚖️ BALANCE + 🖥️ UX · **S**
- **Problem.** `DIFFICULTY_TIERS` (BATA / NORMAL / ASTIG) is complete, correct, and **unreachable**
  — nothing outside `ai_controller.gd` calls `apply_difficulty()` and no screen offers it.
- **Fix.** A three-way picker on `MatchSetup.tscn` beside map and mode, host-owned and broadcast
  **on the same path map and mode already take** (`10.5` U-8 — do not invent a second one; a
  per-peer difficulty is the exact bug U-8 fixed twice already), persisted in `SettingsManager`,
  and applied once at match start.
- **Pillar.** [1] the tier names are already Filipino and already carry the characterisation —
  *bata* the kid, *astig* the one who wins; [4] a demo where a judge can pick BATA and score is
  worth more than a perfectly balanced NORMAL they lose to.
- **Acceptance.** `ai_probe` run at each tier, 20 rounds, three rows in `Checklist.md` — the tiers
  must actually differ, which **has never been measured**. Plus `lobby_probe` extended: two peers
  started on deliberately opposite difficulties, client ends on the host's.
- **Depends on.** R-05 (NORMAL has to mean something before BATA and ASTIG can bracket it).

### R-10 · An AI that is fun to lose to · ⚖️ BALANCE · **M**
- **Problem.** Competence and fun are different targets. `ATTACKER_CHARGE_TIME` is a fixed 0.65 s so
  every AI throw has identical power; the can never wanders; the bots never celebrate, never taunt,
  never visibly make a mistake, and never do anything a human would tell a story about afterwards.
- **Fix.** Three cheap, measurable changes, all inside `ai_controller.gd`: (a) **charge variance** —
  jitter `tier_charge` per throw so the AI's throws vary the way a human's do; (b) **visible
  commitment** — the attacker's wind-up is already animated, so make the AI hold it long enough to
  be *read* and dodged; (c) **the honest mistake** — a low-probability overcommit on the taya's
  pursuit that a human can punish, scaled by tier so ASTIG almost never makes it.
- **Pillar.** [4] — this is the friendslop pillar, directly.
- **Acceptance.** Fairness metrics stay inside whatever range Stage 1 lands on (this item must not
  move them), **plus** a 3-minute `bt_trace()` capture showing charge power varying by ≥ ±25% and at
  least one punished overcommit per 10 rounds at BATA. 🧑 Then a human plays one match against each
  tier and says whether it is fun. There is no probe for that and pretending otherwise is how this
  project got here.
- **Depends on.** R-04, R-09, and whatever Stage 1 configuration ships.

---

<a id="stage-2--the-tsinelas"></a>
## Stage 2 — The tsinelas. Explicit human priority.

> 🧑 Verbatim, 2026-07-30: *"fix the slippers model and make it a bit bigger, make sure everyone
> else can see this size change as well as the FPP of the person holding the slipper, because the
> slipper right now looks too flat and awkward."*

⚠️ **THE SCALE LIVES IN FOUR PLACES AND A PLAN THAT MISSES ONE SHIPS A BROKEN SLIPPER.** R-03 exists
so that this is true *once* and never again. **Do R-03 before R-11.**

### R-11 · Rebuild the tsinelas so it reads as a slipper · 🩴 ART-FEEL · **L**
- **Problem.** It is a flat brown lozenge. The three-layer sole and the swept straps are real and
  correct in the generator, and they still do not read at arena distance or in flight, because the
  whole object is 0.432 m long, 0.12 m thick (28% of its own width) and dead flat in profile.
- **Fix.** Four specific geometry changes, all inside `generate_all.gd::_build_tsinelas`, all cheap,
  all inside the existing `toon` + `outline` shader pair — **no new shader**:
  1. **A curved sole.** The sole is currently a flat extrusion between two constant-Y planes. Sweep
     the outline along a shallow **arc in Y** instead: toe lifted ≈ 0.05, heel lifted ≈ 0.03,
     lowest at the ball. That single change is most of "reads as a slipper rather than a slab" and
     it is the thing a silhouette-only outline shader shows off best.
  2. **Real thickness.** Total sole 0.120 → **0.165** on the unscaled profile, distributed
     outsole 0.030 / foam 0.100 / footbed 0.035, keeping the widest point at mid-height so the
     bevel still reads as moulded foam rather than as a cake slice.
  3. **A strap that clears the footbed.** The arcs peak at y 0.285 against a 0.120 footbed — a
     0.165 gap on a 0.432 m object. Raise the peak to ≈ 0.34 and **widen `HALF_WIDTH` 0.046 →
     0.055**, so the hole through the slipper is visible as a hole from side-on and from above.
     ⚠️ Re-check the anchor margin arithmetic the existing comment spells out; the anchors must stay
     inside the footbed outline at their z, measured on the band's **outer edge**.
  4. **A heel step.** A 0.02 lift at the heel end of the outsole. It costs 8 triangles and it is
     what makes the object read as footwear from directly above, which is the angle a loose Prop is
     seen from most.
- **And it gets bigger:** `TSINELAS_VISUAL_SCALE` **1.25 → 1.60**, applied through R-03's single
  constant. At 1.60 the world slipper is ≈ 0.69 m long against a 1.60 m Person capsule — 43% of a
  Person's height, chunky and readable, and still short of the 84% that the proportion audit
  (`Art_Direction.md` §1) flagged as the original problem.
- **Pillar.** [1] a tsinelas is a specific real object and this makes it look like one; [3] chunky,
  high-saturation, readable at arena distance is the literal aesthetic law; [2] it is the hero prop
  of our own mechanic.
- **Acceptance.** **Five renders, all from `tools/render_probe.tscn` (never `--headless`), attached:**
  (a) in flight at mid-arc from a spectator angle, (b) loose on the ground from a Person's FPP at
  6 m, (c) carried, seen in third person by another player, (d) the local player's FPP viewmodel,
  (e) the same object at the arena's far corner. **Plus `tools/prop_scale_probe.tscn` green**, plus
  a `perf_probe` run showing no frame-time regression (the triangle budget goes up; it must go up by
  an amount that does not register). 🧑 **The human looks at the five renders and says yes or no.**
  There is no probe for "reads as a slipper".
- **Depends on.** R-03. **Hard dependency — do not start this first.**
- ⚠️ The model **stays procedural** (standing human decision). Do not import a mesh.
- ⚠️ `assets/models/tsinelas.obj` needs `--headless --path <abs> --import` before any scene loads it.

### R-12 · The FPP slipper, posed rather than scaled · 🩴 ART-FEEL · **M**
- **Problem.** First person and third person deliberately show two different objects
  (`camera_rig.gd` §7.3 — the world one sits in the real hand for everyone else, the viewmodel one
  is posed for the local player's frame). Today the viewmodel one is **also accidentally 25%
  smaller**, and it is posed flat, so the local player sees the least legible version of the hero
  prop for the entire time they are carrying it.
- **Fix.** After R-03 makes the scale agree, **pose** the viewmodel copy: rotate it so the sole
  faces the camera three-quarters rather than edge-on, tilt the toe up so the curved sole reads,
  and re-measure the `HeldSlipper` offset under the fist. ⚠️ `camera_rig.gd::_update_viewmodel_carry`
  already owns this node — change the pose there or in the scene, not in both.
- **Pillar.** [2] [3] — and it is the named half of the human's ask.
- **Acceptance.** `tools/windup_probe.tscn` still reports the correct wind-up direction (B-131 must
  not regress), plus FPP renders at rest, mid-charge and at release, plus `prop_scale_probe` green.
- **Depends on.** R-03, R-11.

### R-13 · Asset management, made a standing rule instead of a habit · 🩴 ART-FEEL + 🧹 CHORE · **S**
- **Problem.** The CC0 Kenney kits, the roof atlases, the retint pipeline and the generated `.obj`s
  are all correct and are all held together by comments in four different files. Form 03 needs a
  licence register and nobody wants to archaeologise it at the deadline.
- **Fix.** One `docs/Asset_Register.md`: every third-party asset, its licence, its source URL, where
  it lives, and which generator (if any) transforms it. Plus the standing rules restated in one
  place: **characters are palette recolours of existing CC0 rigs, never new models**; **every SFX is
  generated, one licence row**; **the slipper and the lata are procedural**; **LFS tracks binaries
  per `.gitattributes` and nothing else**.
- **Pillar.** [3] consistency by construction is the aesthetic strategy, not a chore.
- **Acceptance.** `git ls-files assets/ | wc -l` against the register's row count, reconciled to
  zero unexplained files. 📦 Producer signs off that Form 03 can be filled from it alone.
- **Depends on.** Nothing.

---

<a id="stage-3--feel"></a>
## Stage 3 — Feel: contact, reaction, sound.

⚠️ **Every item in this stage is blocked on R-04.** Feel is the one thing a probe cannot settle,
and this project has three passes of evidence for what happens when it is tuned by taste.

### R-14 · The reaction pass — animation that sells contact · 🩴 ART-FEEL · **L**
- **Problem.** The event that decides 10 out of 10 rounds — the tag — has **no animation on either
  side**. Neither does the reset channel, the win, or being hit by a slipper. Locomotion and the
  three one-shots exist and have never been judged.
- **Fix.** Four clips, all from the Kenney rig's existing 32 (which is what makes this cheap), wired
  through `character_visual.gd`'s existing `play_action()` fallback-chain pattern:
  1. **Tagged / hit** — the missing one. A recoil on the struck Person, a follow-through on the taya.
  2. **The reset channel** — the taya crouching over the lata for `RESET_CHANNEL_TIME`. This is a
     1.5-second commitment with no pose; it is the defender's most interesting decision and it
     currently looks like standing still.
  3. **Celebration** — one round-win pose, played on the winning side during the role-swap card's
     existing timeline. Free comedy, one clip.
  4. **The downed tilt and the in-flight tumble**, re-judged against R-04's notes.
- **Pillar.** [4] readability under chaos — you must be able to tell, at a glance, across a room,
  that someone just got tagged; [1] the reset channel is the taya's whole job and deserves to look
  like it.
- **Acceptance.** A render sequence per clip at arena distance (not close-up — close-up is not the
  question), plus `tools/facing_probe.tscn` green afterwards. ⚠️ **The Person rig's face is on +Z
  and Godot's forward is −Z; it is corrected on the MODEL node in `character_visual.gd`. Do not
  "fix" it again in the yaw maths.** 🧑 Human verdict on whether contact reads.
- **Depends on.** R-04.

### R-15 · The listening pass · 🎵 AUDIO · **M**
- **Problem.** 33 procedurally generated sounds, a pooled voice manager, a bus limiter, two ambience
  loops and a boot sting — **and no human has ever heard the mix.** It is probe-verified only.
- **Fix.** Sit and listen to every sound in context, in a real match, at real density. Fix what is
  wrong. Expect the failures procedural audio actually has: sounds that are individually fine and
  mask each other, transients that vanish under ambience, a retrigger guard tuned by reasoning
  rather than by ear.
- **Pillar.** [4]
- **Acceptance.** A capture of one full round's audio, plus a written per-sound verdict table
  (too loud / too quiet / wrong / fine) in `Handoff.md`. 🧑 Human listens. `audio_mix_probe` stays
  green for level ceilings.
- **Depends on.** R-04 (listen while playing, not in isolation).

### R-16 · Audio that carries information · 🎵 AUDIO · **M**
- **Problem.** Under four people shouting, audio has to answer *whose throw, how charged, where it
  landed* — and today every throw sounds the same regardless of charge, thrower or outcome.
- **Fix.** Three cheap parameterisations of sounds that already exist, no new assets: **pitch by
  charge** on the release (a fully charged `bagsak` sounds heavier than a `flick`), **pan and
  attenuate by world position** on the landing (already positional for some sounds — audit and make
  it universal), and **a distinct, unmissable stinger for the two events that decide rounds** —
  the dent and the tag. If you hear nothing else, you hear those two.
- **Pillar.** [4] [2]
- **Acceptance.** `tools/audio_combat_probe.tscn` extended to assert pitch varies monotonically
  with charge across the range and that the dent and tag stingers clear the mix's own limiter by a
  stated margin. 🧑 Human confirms they can identify the event with their eyes shut.
- **Depends on.** R-15.

### R-17 · Music, and the emotional arc of a round · 🎵 AUDIO · **M**
- **Problem.** There are Music buses and there is no music. A 90-second round has no shape.
- **Fix.** Procedural, same as the SFX, same one licence row — a short loop with **two intensity
  layers** (add the layer under 15 s, matching the HUD's existing urgency threshold so sound and
  picture say the same thing), plus a menu bed and a round-win sting. ⚠️ Cheap by construction:
  layer gain, not a second stream, not a stem mixer.
- **Pillar.** [1] the instrumentation is the place to be specific rather than decorative — a Filipino
  street-game loop, not generic chiptune; [4] no dead time.
- **Acceptance.** `audio_load_probe` green with the new streams, `audio_mix_probe` shows the
  layered version does not clip, and the layer swap is frame-locked to the same 15 s the HUD uses.
  🧑 Human listens to a full round.
- **Depends on.** R-15.

### R-18 · Physics consistency: bounce, landing, knockback ceilings · 🥊 PHYS · **M**
- **Problem.** `BOUNCE_DAMPING`/`MAX_BOUNCES` were tuned down after "ragdolls while flying"
  feedback, the lucky-fall roll is scoped but not implemented, and guard has no UI. All WRITTEN.
- **Fix.** Against R-04's per-number notes: retune bounce and landing; implement the lucky fall
  (⚠️ **roll on the HOST, ride the existing `_apply_hit_result` broadcast, never `randf()` per-peer**
  — `Handoff_Physics_AI_LAN.md` §2 spells out the exact shape and the `_fall_count` threading); put
  a knockback ceiling on so no single hit can send a Prop out of readable space.
- **Pillar.** [2] [4]
- **Acceptance.** `phys_probe` ballistics table re-run and compared row-by-row against the
  2026-07-29 baseline, with every change explained; the lucky fall verified on the **networked**
  path via `net_spawn_probe` (two real peers agreeing on the same outcome for the same hit).
  ⚠️ A local-path pass here is trap 1 and does not count.
- **Depends on.** R-04.

---

<a id="stage-4--maps-and-flow"></a>
## Stage 4 — Maps, flow, and a street that reads as Filipino.

⚠️ **This stage carries pillar 1.** Filipino culture is not a layer over the environment; for a
judge who has never heard of tumbang preso, the environment **is** the first and loudest statement of
it. R-33 is the item that makes that specific rather than decorative, and it is owned by **Opus**
because "does this read as an eskinita or as generic low-poly" is a judgement call with no lookup-able
answer — the same reasoning `Concurrency_Protocol.md` already applies to map layout, which it calls
*the single biggest visual lever on the submission*.

### R-19 · Close the two known map defects · 🌏 MAPS · **S**
- **Problem.** 8 pre-existing interior footprint overlaps in Bayan Plaza; the paved apron ends in a
  hard square visible from the y=30 overhead.
- **Fix.** Both are builder changes (`build_bayan_plaza.py`) — hand edits to the `.tscn` are
  destroyed on the next build. Use `surfaces.ask_before_placing()` rather than fixing the
  post-mortem list by hand, which is what let these survive.
- **Pillar.** [3] — a broken-looking world reads as a broken prototype, which is the risk
  `Checklist.md` names in its own opening paragraph.
- **Acceptance.** `build_bayan_plaza.py` prints `Layer1 overlap: none` and `overlaps_across` reports
  zero, the build does not abort on the lane law, and a `tools/void_probe.tscn` overhead render at
  y=30 shows a soft apron edge. Both maps still load and `perf_probe` shows no regression.
- **Depends on.** Nothing.

### R-33 · The eskinita pass — make the street specifically Filipino · 🌏 MAPS · **L**
- **Problem.** The kit-built world reads as *a well-built street*. It does not yet read as a
  **particular street in a particular country**. Pillar 1 is the one a judge meets before they read
  a word, and the environment is where it lives or does not.
- **Fix.** Four moves, all cheap low-poly geometry with flat colour, **no new shader**:
  1. **The vocabulary of the place, as geometry** — the sari-sari store with its barred window and
     strung sachets, the tangle of overhead wires (the single most recognisable silhouette of a
     Philippine residential street), GI-sheet roofing, a barangay basketball ring on a post, laundry
     on a line, a tricycle at the alley mouth, plants in cut-open paint tins. ⚠️ Every piece passes
     the lane law or it is a build abort, not a cultural addition.
  2. **Name everything in the language of the thing** — `SariSari`, `Bakod`, `Poste`, `Eskinita`,
     not `Shop_01`, `Fence_A`, `Alley`. Those names surface in the scene tree, in every debug print
     and in every future grep. **It costs nothing and it is the cheapest cultural win available.**
     Rename only what this lane owns; grep first.
  3. **Time of day, chosen deliberately** — late afternoon is the hour kids actually play tumbang
     preso, and it is a light angle and a colour, not a lighting system.
  4. **Make the two maps contrast.** Eskinita: close, cluttered, private, roofed by wires, fought
     *along*. Bayan Plaza: open, civic, paved, fought *across*, with the church and covered court a
     bayan actually has. **If a screenshot of one could be a screenshot of the other, one map has
     been built twice.**
- **The standard.** A Filipino should recognise the street; someone who is not should come away
  having learned something specific about it. **Both, or it is decoration.** Specific beats
  decorative: a generic town with a Filipino word painted on a wall is the failure mode.
- **Pillar.** [1] directly and primarily; [3] every item above is flat-coloured low-poly by
  construction; [4] a lived-in alley is funnier to fight in than a clean one.
- **Acceptance.** Lane law does not abort and `Layer1 overlap: none` still holds; `perf_probe` shows
  no frame-time regression on either map — **add specificity, not density**, the instance count came
  down 510 → 382 for performance reasons once already; **six renders at player eye height, three per
  map, each with a written sentence naming what in the frame is specifically Filipino**; and a
  naming audit listing every generic name left and why. 🧑 **Then a human looks and says whether it
  reads.** There is no probe for cultural specificity. Where the lane cannot decide, the question is
  filed with options and costs — a confident wrong guess about somebody's own neighbourhood is worse
  than a question.
- **Depends on.** R-19. **Before R-20**, so the plaza inherits the vocabulary rather than needing a
  second pass.

### R-20 · Port every Eskinita lesson to Bayan Plaza · 🌏 MAPS · **M**
- **Problem.** ⚠️ *"The two builders share `floorcheck.py` and nothing else. Every Eskinita lesson
  has to be ported by hand — that is how those items survived."* House orientation is not applied to
  the plaza's own tree rings and landmarks, there is no five-shot void acceptance, clutter is sparse,
  and the HazardZone still has no visual tell.
- **Fix.** Port them. **And fix the cause:** move the shared logic (grounding contract, void
  acceptance, orientation, the placement guard) into `floorcheck.py` or a sibling module so the
  third lesson does not have to be ported twice.
- **Pillar.** [3]
- **Acceptance.** The five-shot void acceptance passes on Bayan Plaza as it does on Eskinita;
  `bayan_probe` green; the HazardZone is visible in a render.
- **Depends on.** R-19.

### R-21 · Judge both maps for FLOW · 🌏 MAPS + 🧑 · **M**
- **Problem.** Neither map has ever been judged for flow. The specific open questions are:
  **sightlines** (can an attacker at the 6.0 line see the can, and can the taya see the attacker
  coming?), **the retrieval route** (is the walk back interesting or is it dead time?), and the
  **confinement square's shape and size** — currently `CONFINEMENT_RADIUS` 5.0, a number whose
  *shape* was decided by a correctness fix and whose *size* has never been varied.
- **Fix.** Instrument first, then ask. Add a **heatmap mode to `ai_probe`**: log every unit's
  position each second over 40 AI rounds per map and emit a top-down density image. Dead space,
  the retrieval route and whether the plaza's off-centre monument is a feature or an obstacle all
  fall out of that picture without anyone guessing. **Then sweep `CONFINEMENT_RADIUS` at 4.0 / 5.0 /
  6.0** through the fairness harness — both builders already read the constant, so the chalk follows
  the physics automatically, which is exactly what makes this sweep cheap.
- **Pillar.** [4] no dead time; [2] the confinement box is the arena of our own mechanic.
- **Acceptance.** Two heatmaps and a three-row confinement table in `Checklist.md`. 🧑 **The size
  call is the human's**, off the table and their own play. ⚠️ The arena **footprint** stays the
  original size — standing decision, not open here. The confinement box inside it is what is being
  measured.
- **Depends on.** R-04, R-19.

### R-22 · A third map is **CUT** · decision, not a task
- **Rationale.** Two maps that nobody has played is already the wrong side of `Checklist.md`'s own
  "If time runs short" §1 (*"One map, finished and dressed, beats two grey-boxes"*). A third is
  strictly worse. **If Bayan Plaza fails R-21's flow judgement, cut it too and ship Eskinita alone.**
  Reversible only if Stages 1–3 land early and R-04 says the game is fun.

---

<a id="stage-5--the-network-under-real-load"></a>
## Stage 5 — The network under real load.

⚠️ **This is the stage most likely to produce a nasty surprise, because every claim in it rests on
two loopback peers.** `Checklist.md` 9.6 says so in its own words.

### R-23 · Four real peers, real Wi-Fi · 🌐 NET + 🧑 · **M**
- **Problem.** Everything is 127.0.0.1. `Checklist.md` 6.1 has been 🧑 human-only and unrun for the
  whole project, and it is also the trigger for the shared-screen fallback.
- **Fix.** Extend `net_spawn_probe` from two peers to **four** and add a latency/loss shim
  (`ENetConnection` has the knobs; if it does not expose enough, a fixed artificial delay on the
  RPC path under a debug-only flag per `Dev_Plan.md` §0.3 is acceptable and must obey the removal
  contract). Then run it for real on four machines.
- **Pillar.** [4] — a game four friends cannot actually connect to is not a party game.
- **Acceptance.** A four-peer probe run: all four spawn, all four move their own character, one
  full round completes, all four agree on the winner. Then 🧑 the same on real hardware over real
  Wi-Fi, with the result written down either way. **A failure here triggers the fallback and needs
  weeks of warning, which is why it is not later than this.**
- **Depends on.** Nothing. **Start it in parallel with Stage 1 — it is the longest lead time on the
  project.**

### R-24 · Stress the AI fallback with real drops · 🌐 NET · **M**
- **Problem.** `_rpc_convert_to_ai`, `_rpc_reclaim_character` and the empty-seat fill are complete
  and correct-looking and have **only** been exercised on a two-peer probe. Never a real drop, a
  real rejoin, a mid-round drop, a host drop, or four peers.
- **Fix.** Drive each case from the probe: kill a peer mid-round and assert its character keeps
  playing under AI; reconnect it and assert it gets **its own seat and its camera back**; drop the
  host and assert every client lands somewhere sane rather than hanging.
- **Pillar.** [4]
- **Acceptance.** `net_spawn_probe` gains one named assertion per case, each of which **fails if the
  case is broken** — verify that by deliberately breaking each and watching the probe go red.
  ⚠️ Trap 2: a probe that never looks at the thing you changed passes anyway.
- **Depends on.** R-23.

### R-25 · A clean host-quit story · 🌐 NET · **M**
- **Problem.** `server_disconnected` is handled and routes out; there is no host migration. On a LAN
  party that is the most likely disconnection there is.
- **Fix.** **Do not build host migration.** Build the honest version: a clear "the host left" screen,
  a clean return to the main menu with the match state discarded, and — this is the part worth the
  effort — **the host's own quit path asks for confirmation** and tells them what will happen to
  everyone else. Migration is architecturally expensive and buys a case a party of four in one room
  solves by saying "start it again".
- **Pillar.** [4]
- **Acceptance.** `net_spawn_probe`: host quits mid-round, both clients reach the main menu inside
  3 s with no error spam and no orphaned nodes. 🧑 Confirmed on the four-machine run.
- **Depends on.** R-23.

### R-26 · Late join and lobby UX under load · 🌐 NET + 🖥️ UX · **S**
- **Problem.** Late join works on the probe. A four-peer lobby, a mid-lobby disconnect, and a
  mid-match join have never been exercised.
- **Fix.** Extend `lobby_probe` to four peers; cover seat contention with four claimants, a peer
  leaving with a seat held, and a join arriving during the ready countdown.
- **Pillar.** [4]
- **Acceptance.** `lobby_probe` at four peers, every existing assertion still green plus one per new
  case.
- **Depends on.** R-23.

---

<a id="stage-6--onboarding-and-readability-under-chaos"></a>
## Stage 6 — Onboarding and readability under chaos.

### R-27 · Onboarding for someone who has never heard of tumbang preso · 🖥️ UX · **M**
- **Problem.** `Tutorial.tscn` is eight pages of accurate text. A judge with four minutes and three
  friends will not read eight pages of text, and the game's whole premise — *a can on a mark, a
  guard, a thrown slipper, a scramble* — is unfamiliar to most of the world.
- **Fix.** Put the premise **before** the pages: one screen, four pictures, twelve words —
  **LATA · TAYA · TSINELAS · TAKBO** (can, guard, slipper, run). Filipino vocabulary taught by using
  it, with the English underneath, which is the standing rule this project already follows in the
  roster. Keep the eight pages as the reference behind it. Then **the first 15 seconds of a match
  teach the rest**: the existing ready phase is dead air, so put the role's one-line objective on
  it — *"KNOCK THE LATA DOWN"* / *"GUARD THE LATA. TAG THE THROWER."*
- **Pillar.** [1] directly — this is where the culture is taught; [4] no dead time.
- **Acceptance.** Renders of the premise card and both ready-phase objective states.
  🧑 **The real test: someone who has never played it starts a match and knows what to do without
  being told.** Find one person and watch them. That is the acceptance test and there is no
  substitute for it.
- **Depends on.** R-04.

### R-28 · Role and score readable under chaos · 🖥️ UX · **S**
- **Problem.** The HUD matches its spec by render. Nobody has read it while four people were
  shouting and a slipper was in the air. Under FPP, a Person cannot see their own body, and role
  colour is carried by panels at the top of the screen where the eye is not.
- **Fix.** Cheap redundancy, no new systems: the crosshair takes the role colour, the FPP viewmodel
  arms take the team's role colour band, and the off-screen indicators (which already exist and are
  mandatory for FPP per `Dev_Plan.md` §3.3) get a role-coloured objective arrow to the lata.
  ⚠️ Offense is always orange, defence is always blue, project-wide, and the accent tracks **role**,
  not team — `Dev_Plan.md` §4.2's two hard rules. Do not invent a third colour.
- **Pillar.** [4] readability under chaos is the pillar, stated.
- **Acceptance.** Renders in both roles from both camera modes; `hud_probe` green.
  🧑 A player mid-match can answer "what am I and are we winning" in under a second.
- **Depends on.** R-04.

### R-29 · The intermission beat, and whether the result screen earns its keep · 🖥️ UX · **S**
- **Problem.** The role-swap card runs a full four-beat timeline (render-verified, never watched).
  The match result screen exists, is styled, and nobody has decided whether a Bo5 pip grid and two
  buttons is worth the pause at the end of a party match.
- **Fix.** Time the intermission against R-04's notes — four seconds is a long time when it happens
  four times a match. Add the one thing the beat is missing: **what actually just happened**
  ("TAGGED", "LATA DOWN", "TIME") in display type, because the swap card currently tells you the
  score changed and not why. On the result screen: keep it, and make **Rematch** the default focus
  so the fastest path is back into the game.
- **Pillar.** [4] no dead time.
- **Acceptance.** Render of each of the three round-end reasons on the card. 🧑 Human says whether
  the beat is too long. ⚠️ Any timing change must not race the world reset at 3.0 s.
- **Depends on.** R-04.

---

<a id="stage-7--ship"></a>
## Stage 7 — Ship.

### R-30 · Debug removal, per the §0.3 contract · 🥊 PHYS + 🧹 CHORE · **S**
- **Problem.** The debug switcher and `ai_probe::_take_over_human_slot()` are both flagged for
  removal and both must go before submission. ⚠️ **Keep `_take_over_human_slot` flagged and do not
  let it leak into gameplay** — it is one function and one call site inside a folder that does not
  ship, and it stays until the last fairness run.
- **Fix.** Run `Dev_Plan.md` §3.5.5's removal checklist and the enforcement grep. Single Player
  itself **ships** and is explicitly not part of this contract (§0.2).
- **Acceptance.** The §3.5.5 grep returns nothing; the game boots, hosts, joins and completes a Bo5
  afterwards. `input_probe` green.
- **Depends on.** the last fairness run.

### R-31 · An exported build, on the judging laptop · 🧑 + 📦 PRODUCER · **M**
- **Problem.** Export templates have never been installed; the release preset is *"correct,
  unrunnable"*. Everything downstream of handing a judge a build waits on it. `perf_probe` has never
  run on the actual judging hardware, which is the number that decides the remaining renderer
  settings.
- **Acceptance.** An `.exe` that boots, hosts, joins and completes a Bo5 on a machine that has never
  had Godot on it, plus a `perf_probe` frame-time capture from that machine.
- **Depends on.** everything that changes a renderer setting.

### R-32 · Trailer, demo video, synopsis, forms · 📦 PRODUCER + 🧑 · **L**
- **Problem.** `Art_Direction.md` Part 5 has the beat sheet and the shot list already. Nothing is
  captured. Form 03 needs the licence register and the font licence.
- **Acceptance.** `Checklist.md` Phase 6, unchanged. R-13's register fills Form 03 without
  archaeology.
- **Depends on.** R-31, R-13.

---

# Part 3 — Cut list, in cut order

This amends `Checklist.md`'s "If time runs short" with what this roadmap adds. **A stated, reasoned
cut beats a silently unfinished feature.**

1. **A third map** — already cut (R-22).
2. **R-10, the fun-to-lose-to AI pass.** Nice, not load-bearing. A correctly balanced NORMAL bot
   that is a bit robotic still demos.
3. **R-17, music.** The SFX carry the round. Silence between them is survivable; a broken mix is not.
   ⚠️ **R-33 is not on this list and must not join it.** It is the cheapest pillar-1 work on the
   project — geometry and names, no new systems — and the environment is where a judge meets the
   culture before they read a word.
4. **R-25's host-quit confirmation dialog** (keep the "host left" screen — that is the part that
   stops a hang).
5. **Bayan Plaza**, if R-21 says it does not flow.
6. **Never cut:** R-01/R-02 (the instruments — everything else becomes unfalsifiable), R-04 (the
   human play gate), R-11/R-12 (the slipper — explicit human priority and the most-looked-at object
   in the game), R-23 (four real peers — it is also the fallback trigger), R-31 (a build).

---

# Part 4 — The three biggest risks

### RISK 1 — The game may not be fun, and nobody has checked.
One informal play session, on 2026-07-28, before the AI, the audio, the roster, the front end, both
maps as they now stand and the ready phase. Every feel number in this repository is a first guess
that has been iterated on by probe. **A probe cannot tell you a game is boring.** This is the
highest-probability, highest-impact risk on the project, it is not technical, and the mitigation
costs one hour: R-04. Every stage after 0 is gated on it deliberately, because a roadmap that lets
feel work proceed on assumption is how this project accumulated three passes of code nobody ran.

### RISK 2 — The network has only ever been four peers in theory.
Two loopback peers is, in `Checklist.md`'s own words, the weakest possible network test. Movement is
client-authoritative with **no reconciliation**, which is fine on 0 ms loopback and is exactly the
architecture that produces rubber-banding and hit disagreement on real Wi-Fi. The AI-fallback path,
the reclaim path and the seat tokens are all correct-looking and all unexercised. If R-23 fails, the
fallback is a shared-screen pivot budgeted at **one to two days**, and it needs weeks of warning —
which is why R-23 is scheduled in parallel with Stage 1 rather than after it.

### RISK 3 — The fairness problem may not have a knob-shaped solution.
Eight measured runs, one of which invalidated the previous seven, have moved the defence's win rate
from 100% to 100%. `taya_pursue_radius` was swept across its whole useful range and did nothing.
The block rate is 92% and the attacker's only counter-play is patience. **The plan's Stage 1 assumes
this is structural and changes verbs and win conditions**, which is the right bet — but if R-06,
R-07 and R-08 all land and the number is still out of range, the honest remaining move is to change
what winning a round *means* rather than to keep nerfing the taya, and the schedule must leave room
to do that. The failure mode to avoid is another five runs of single-knob nerfs: **do not stack
nerfs without root-causing the metric that moved the wrong way**, which is RUN 7's own unheeded
warning.

---

# Part 5 — Decisions taken in this document

Recorded so nobody re-opens them, and so a human can overrule them knowingly.

| Decision | Rationale |
|---|---|
| **A third map is cut.** | Two unplayed maps is already past the point `Checklist.md`'s own cut list warns about. |
| **The lob is a region of the existing charge, not a new button.** | A fourth verb on a four-player party game is a fifth thing to explain. |
| **No host migration; a clean host-quit story instead.** | Architecturally expensive; solves a case four people in one room solve by restarting. |
| **`TSINELAS_VISUAL_SCALE` 1.25 → 1.60**, via one constant that actually drives all four sites. | The human asked for bigger; 1.60 puts the slipper at 43% of a Person's height — chunky and readable, well short of the 84% the proportion audit flagged. |
| **Fairness is treated as structural before it is treated as tuning.** | 92% blocked is not a knob 15% off. |
| **The arena footprint stays the original size**; only `CONFINEMENT_RADIUS` is swept. | Standing human decision. The confinement box is a separate, never-varied number. |
| **Difficulty tiers ship player-facing.** | The mechanism is already built and unreachable; a judge who can pick BATA and score is worth more than a perfect NORMAL they lose to. |
| **The tsinelas stays procedural.** | Standing human decision. |
| **The 🌏 MAPS lane is Opus, and it owns cultural specificity as well as flow.** | 🧑 Human call, 2026-07-30. The environment carries pillar 1 to a judge before any text does, and "specific rather than decorative" is judgement under ambiguity, not execution against a spec. |
| **Every lane verifies its toolchain before it starts**, and the 🌏 MAPS prompt makes it a numbered Step 0 that blocks all work. | 🧑 Human call, 2026-07-30. This lane's whole loop is regenerate → import → render → look, and a Godot binary that is not on PATH, a `--headless` render device that does not exist, and a builder that is not idempotent have each silently invalidated work here before. |
| **No new shader.** | Standing constraint. Every visual item above is achievable with the existing `toon` + `outline` pair, flat vertex colours and low-poly geometry. |

---

**Owners, and where their prompts live:** every `⚖️ / 🥊 / 🩴 / 🌏 / 🌐 / 🖥️ / 🎵 / 🔬 / 📦 / 🧹`
tag above maps to a lane in [`Agent_Prompts.md`](Agent_Prompts.md), which carries each lane's
charter, exact path ownership, ordered task list, verification contract, model and effort
assignment, and its complete ready-to-paste system prompt.
