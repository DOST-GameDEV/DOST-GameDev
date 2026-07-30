# Master Checklist — Tumbang Preso, from here to a submitted entry

**This file is the single place progress is tracked.** Every other document
describes *what* something is or *why* it was decided; this one is the ordered
list of what is left and what is next. If a status table anywhere else
disagrees with this file, this file wins and the other one is stale.

**How to use it:** scroll from the top and find the first unchecked box that is
not marked 🧑 HUMAN or ⛔ BLOCKED. That is the next thing to do. Nothing here is
"pick whatever looks fun" — the order is dependency order and the reasoning for
each step is stated inline.

Legend, unchanged from `Dev_Plan.md` §1:

| | |
|---|---|
| `[x]` | built **and verified** — someone or something confirmed it actually works |
| `[~]` | built but unverified, or partially built. Says what specifically is unverified. |
| `[ ]` | not started |
| 🧑 | **human-owned.** An agent cannot do this one. Not a soft preference. |
| ⛔ | **blocked** on the item named. Do not start it. |
| 🤖 | the model this is routed to (see `Handoff.md` §4 for the full routing table) |

**Last full audit:** 2026-07-27, against `main` @ `2c22f50` (v4.20), verified by
reading the code and by rendering the running game — not by reading the previous
pass's checkboxes. See `Handoff.md` §0.10.

## Jump to

<sub>Auto-added 2026-07-30 so this file stops being one long scroll. Keep it in step when you add a `##` section.</sub>

- [Where this actually stands, in one paragraph](#where-this-actually-stands-in-one-paragraph)
- [Phase 0 — Unblock the playtest](#phase-0-unblock-the-playtest)
- [Phase 1 — Decisions that gate everything downstream](#phase-1-decisions-that-gate-everything-downstream)
- [Phase 2 — Build the world](#phase-2-build-the-world)
- [Phase 4 — Feel, audio and networking hardening](#phase-4-feel-audio-and-networking-hardening)
- [Phase 5 — Strip, harden, and prove it runs outside the editor](#phase-5-strip-harden-and-prove-it-runs-outside-the-editor)
- [Phase 6 — Submission. This is graded work, not paperwork.](#phase-6-submission-this-is-graded-work-not-paperwork)
- [Phase 7 — The kit overhaul. Real asset kits replace the generated world.](#phase-7-the-kit-overhaul-real-asset-kits-replace-the-generated-world)
- [Phase 8 — The environment pass. Kill the void, ground the props, light the street.](#phase-8-the-environment-pass-kill-the-void-ground-the-props-light-the-street)
- [Phase 9 — Graphics downgrade, AI rewrite, and a game-wide bug sweep](#phase-9-graphics-downgrade-ai-rewrite-and-a-game-wide-bug-sweep)
- [Phase 10 — Boot sequence, menu, house logic, Can AI, and the second map](#phase-10-boot-sequence-menu-house-logic-can-ai-and-the-second-map)
- [Phase 9 · AI FAIRNESS LOG — the running record for balance testing](#phase-9-ai-fairness-log-the-running-record-for-balance-testing)
- [Already done — the ledger this list replaces](#already-done-the-ledger-this-list-replaces)
- [If time runs short](#if-time-runs-short)


> ### 🧭 Where the project is trying to GO — [`Roadmap.md`](Roadmap.md), written 2026-07-30
>
> This file tracks *what is left*. **[`Roadmap.md`](Roadmap.md) argues *what makes it good, in what
> order, and how we know*** — an ordered, dependency-aware plan from here to a submitted entry,
> every item carrying the problem, the fix, the pillar it serves, the acceptance test that proves
> it, the owning lane, and an effort size.
>
> It opens with a confidence audit in three tiers — **PLAYED** (a human pressed buttons),
> **MEASURED** (a probe produced a number someone read), **WRITTEN** (it parses and nobody has
> looked). **Almost nothing on this project is the first kind**, and two live defects fell out of
> writing it down: the FPP slipper is 1.00× against the world's 1.25×, and
> `CharacterBase.TSINELAS_VISUAL_SCALE` is a dead constant that nothing reads.
>
> Where the two files disagree about *priority*, the roadmap argues its case. **Where they disagree
> about STATUS, this file still wins** — that rule is unchanged.
>
> The nine lanes that execute it, with path ownership, model and effort, and ready-to-paste system
> prompts, are in **[`Agent_Prompts.md`](Agent_Prompts.md) § THE ROADMAP PIPELINE**.

> ### 👥 Running more than one agent at once
>
> **Read [`Concurrency_Protocol.md`](Concurrency_Protocol.md) before starting.** It defines four
> lanes — 🎨 Design (Opus), 🔧 Build (Sonnet), 🔬 QA (Sonnet, docs-only) and 📦 Producer (Sonnet,
> docs-only) — with a hard path-ownership table, separate git worktrees so the two Godot import
> caches cannot corrupt each other, an optimistic lock for the six genuinely shared files, an
> amendment to the version-bump rule, and a six-command smoke gate every lane runs before merging.
>
> Paste-ready opening prompts for each lane are in
> **[`Agent_Prompts.md`](Agent_Prompts.md)**.
>
> **Opus takes only four items on this entire list — 1.2, 2.1a, 2.2 and 6.2.** Those are the
> places where the difficulty is judgement under ambiguity rather than execution. Everything else
> is Sonnet work against a specification.
>
> **Item 5.4 (`.import` UID churn, B-71) is promoted from "low, not urgent" to a
> prerequisite for two-lane working** — with two import caches it produces continuous phantom
> diffs and makes the `M-` block's only objective acceptance test unreliable. See
> `Concurrency_Protocol.md` §7 for the interim rule.

---

## Where this actually stands, in one paragraph

The **systems are in good shape and the presentation is not**. The LAN loop
hosts, joins, spawns, syncs late joiners, runs a 90-second round, decides a
winner, swaps roles, and completes a Bo5. There is a themed main menu, a lobby
with ready-up, a settings panel, a pause menu, a match-result screen, a
role-swap intermission card, and a HUD that already matches `Dev_Plan.md` §4.4
closely. What a judge would see is one **40×40 grey box with invisible walls**,
no map, no audio, no field markings, and a core mechanic — throw the slipper,
scramble to retrieve it — that is **not yet signed off in play.** The
two biggest risks are, in order: *the central mechanic is still being tuned*, and
*the game has no world*.

> **Updated 2026-07-29 — the paragraph above is now history, and the risk has moved.** Phase 7 put a
> real kit-built world in (houses, paving, trees, cars, overhead lines), Phase 2 put the field
> markings in, and the mechanic has been played. What a judge would see today is **a well-built
> street standing on a 40×40 island in an empty void**, with every interior prop 100 mm underground
> and five of eleven house fronts standing in front of their own collision wall. The biggest risk is
> no longer "there is no world" — it is that **the world that exists reads as a broken prototype**.
> That is what **Phase 8** below exists to fix; its measured audit is `Art_Direction.md` §8.0.

---

## Phase 0 — Unblock the playtest

**Nothing below Phase 0 is worth doing until the core mechanic has been felt by
a person.** The entire carry / charge / throw / retrieve / reset-channel system
(T-1 … T-3) is code-complete and not yet signed off in play. Every number in it —
charge time, crawl speed, arc angle per throw profile, grab radius,
`RESET_CHANNEL_TIME` — is a first guess. If the throw is wrong, most of Phase 2
and all of Phase 4 get retuned anyway, so spending a week on environment art
first is spending a week on a bet.

Three things have to land before that playtest is even *possible*. They are not
polish; they are the instruments.

- [x] **0.1 · HUD charge meter, hold meter and reset-channel bar.** 🤖 Sonnet, medium
      `carrier.gd` emits `charge_changed(0..1)`, `held_changed`, and
      `reset_channel_changed(0..1)`. **All three are emitted and nothing
      consumes them** (`Handoff.md` T-3). You cannot tune a hold-to-charge throw
      with no visible charge, and you cannot tune a 1.5-second channel with no
      progress bar — the tester has no feedback loop at all. This is the single
      highest-leverage item on the list because it converts "we guessed" into
      "we can measure". Also the moodboard's own spec: THE ATTACKER card
      illustrates *charged throw (glow)* and THE DEFENDER card illustrates
      *lata reset channel (progress bar)*.
      *Blocks:* 0.4.
      **Done, verified by running** (not by a human): a headless probe drove
      grab→charge→release and grab→hold→complete/cancel via `Input.action_press`
      and read the live bar/label values back — all three signals wired
      correctly. Screenshots at 1280x720 and 1920x1080, idle and mid-fill.
      Plain styling only; the design lane restyles on top once merged.
      **2026-07-28 addendum, 🔧 build-ux:** the charge-glow HOOK now exists —
      `you_card.gd::_on_charge_changed` drives a `charge_ratio` (0..1) shader
      uniform on `charge_bar.material` whenever the design lane assigns a
      `ShaderMaterial` there; a no-op until one is assigned. Verified by a
      scripted run (`ShaderMaterial` attached, charge driven to 0.6 then to
      "stopped", uniform read back both times) — not by render, since there is
      no shader to render yet. The moodboard treatment itself is still the
      design lane's, per the comment this replaces nothing of.
- [x] **0.2 · Give each side a real default Prop ability (B-76).** 🤖 Sonnet, medium
      `main.gd`'s `PROP_ABILITY` is `quick_stand.tres` for **every** Prop, and
      `Main.tscn` hardcodes the same. Quick Stand has no `get_throw_profile()`,
      so every throw falls back to `throw_default.tres` and **all three Tsinelas
      identities (Bagsak Bomb, Bakya Bash, Flick Dash) are unreachable in the
      running game.** The whole `throw_profile.gd` design is currently dead
      code. Full character select is 3.3; this is the interim: a per-side
      default so a Can gets a Can ability and a Tsinelas gets a throw profile.
      *Blocks:* 0.4 — you cannot playtest three throw identities that cannot be
      selected.
      **Done, verified by running.** Also worse than described: `is_can` flips
      every round and nothing re-picked a Prop's ability on the flip, so a
      spawn-time-only fix would have gone stale one round later — fixed at
      every spawn path and every round reset. Only 2 of the 3 Tsinelas
      identities are reachable in a single 2v2 sitting (Bakya Bash / Flick
      Dash) — a hard limit of 2 Props per match, not something this item can
      close; 3.3 does that. See `Handoff.md` B-76.
- [x] **0.3 · Base circle and throwing line, in the current arena.** 🤖 Sonnet, medium
      The game is named after a can standing in a circle and the circle is
      nowhere in the world. Two floor decals in `Main.tscn`, deliberately
      temporary — 2.2 replaces them properly with map geometry. Do them anyway:
      Option B is unreadable without the base circle, and a tester cannot judge
      throw range with no throwing line.
      *Blocks:* 0.4.
      **Done, verified by rendering** (`tools/render_probe.gd`, real device, not
      headless) at 1280x720 and 1920x1080 — both visible from a Person's FPP
      camera. Centred at world origin as a nominal marker, not the Can's actual
      spawn point, which isn't fixed (varies by ~3 units by which team holds it
      — a `SPAWN_POINTS` limitation 2.2 is scoped to fix, not this item).
- [ ] **0.4 · 🧑 PLAY A FULL BO5 IN LOCAL MATCH. Both game modes.** ⛔ 0.1, 0.2, 0.3
      Carry a slipper. Charge and release it at several arcs. Miss, and go get
      it back. Get tagged mid-carry. Crawl a loose slipper home. Hold the reset
      channel on a downed lata and get interrupted. Win a round; watch the swap.
      Then write down, per number, whether it was too fast, too slow or right.
      **This is the one item on this list that no model can do for you.** The
      project has burned three passes writing code nobody has run.
- [ ] **0.5 · Retune from 0.4's notes and fix what it broke.** 🤖 Sonnet, high ⛔ 0.4
      High effort rather than medium: this will touch `carriable.gd`,
      `carrier.gd` and the throw profiles at the same time, and the
      host-authoritative transitions in there are easy to break subtly.
      **Early progress, 2026-07-28, from informal playtesting ahead of a full 0.4 pass:** B-97
      (carried Tsinelas TPP camera could mount above the carrier's head and gave its player no
      look control at all — both fixed), B-98 (carried unit's nameplate ring stayed visible, now
      hidden while carried), B-99 (a thrown slipper's carry-tilt rotation was never reset on
      release, so it could land tilted and tunnel through the floor — fixed), and
      `BOUNCE_DAMPING`/`MAX_BOUNCES` tuned down after "ragdolls while flying" feedback. See
      `Handoff.md`'s session log. **Still blocked on an actual full 0.4 pass** — this is real bugs
      found and fixed along the way, not the systematic retune 0.5 itself calls for.
- [x] **0.6 · Carried-scale the tsinelas (implements the 1.2 decision).** 🎨 Design (reassigned)
      **Design lane specified this; it is build-lane code and design must not write it.** Do it
      before 0.4 — in first person the carried slipper currently occupies about a quarter of the
      screen as an opaque slab, and a tester cannot judge an aiming arc through it.
      In `scripts/characters/character_visual.gd` only:
      1. `const TSINELAS_CARRY_SCALE: float = 0.32` and
         `const CARRY_SCALE_LERP: float = 12.0`.
      2. In the existing `_process` poll — **beside `_spin_while_airborne`, not on a signal**;
         its comment explains why (Carriable and CharacterVisual are siblings with no guaranteed
         `_ready()` order, and a poll self-heals across the model rebuild that every role swap
         performs) — lerp `self.scale` toward `Vector3.ONE * TSINELAS_CARRY_SCALE` while the
         sibling `Carriable.state == CARRIED`, and toward `Vector3.ONE` otherwise. Guard it to
         `carriable.is_throwable()` so a Can is never touched.
      3. Retune `HAND_CARRY_OFFSET`. **Predicted, not measured:** the sole sits at
         CharacterVisual-local `y = -0.8`, so scaling about this node's origin lifts the slipper
         ≈ `0.544` units; `y` wants to go from `+0.21` toward `≈ -0.33`. **Confirm by render, do
         not paste the number in.**
      *Acceptance:* `godot --path . tools/render_probe.tscn --quit-after 400 --resolution 960x540
      -- viewmodel <dir>` — **without `--headless`** — and both shots show a slipper that reads as
      held. Attach them. Tuning window `0.28 – 0.40` without consulting the design lane.
      *Explicitly NOT in this item:* the mesh, any collision shape, any `hit_radius`, any speed,
      the camera. `_align_to_capsule_floor()` needs no change — it computes from `model.scale` in
      this node's local space, not from this node's scale.
      ⚠️ **Superseded 2026-07-28 by 2.5.** `TSINELAS_CARRY_SCALE`, `CARRY_SCALE_LERP` and the lerp
      in `_process` described above are deleted — the mesh is built at 0.32× natively now
      (`Art_Direction.md` §1), so there is nothing left to scale at runtime. Kept here as the
      record of the original, now-superseded mechanism; see 2.5 for what replaced it.
- [x] **0.7 · B-82 — units spawn 0.3 units inside the floor slab. OBSOLETE, not fixed.** 🎨 Design
**The offending floor no longer exists.** 2.2a deleted `Main.tscn`'s whole world
      half, and both maps put their floor top at exactly `y = 0` with spawn markers at `y = 0.8`,
      which is the convention every doc already assumed. **B-83 is retired the same way** — the
      boundary colliders that sat at `±40` around a `±20` floor went with it. Closed as obsolete
      rather than as fixed, deliberately: nobody edited the numbers, the thing holding them was
      removed. `Art_Direction.md` §4.1 was corrected separately.

---

## Phase 1 — Decisions that gate everything downstream

These run **in parallel with Phase 0**, on different people. None of them is
code. All three have been open for at least three passes and each is now
blocking real work.

- [ ] **1.1 · 🧑 The display typeface.** ⛔ HUMAN — hardest blocker on the project
      Open since the first pass. It now blocks the logo lockup (3.2), the round
      banner, the match-result headline, and the "does this look finished"
      read on **every screen in the game**. Two ways to close it, in order of
      preference: (a) export the real face from Harry's Canva project — one
      `.ttf`, one licence line on Form 03; (b) approve an SIL OFL substitute —
      **Luckiest Guy** is closest to the moodboard's letter sheet, with **Chewy**
      and **Titan One** as alternates. **No font binary enters this repo without
      an explicit written yes.** That gate is correct and is not being
      relitigated here. What *is* being escalated: this is now the difference
      between "a Godot project" and "the game on the moodboard", and it is one
      line of code behind a question nobody has answered.
- [x] **1.2 · Prop scale — how big is a lata, and how big is a tsinelas? DECIDED 2026-07-28.**
      **Option (a): props stay hero-scaled as units; the tsinelas scales to `0.32`** (0.432 units
      long = 27% of a Person, against 84% at the time). Reasoning, the measured numbers, the three
      rejected alternatives and the two follow-up items are in `Handoff.md` §0.11. Ticked as a
      **decision** — the implementation was 0.6 below. The kit's 2-unit grid in 2.1a is sized
      against this and 2.1 is unblocked.
      ⚠️ **Superseded mechanism, same-day, same decision:** 0.6 originally implemented "0.32 ONLY
      while CARRIED" via a runtime scale on the whole mesh. 2.5 (`Art_Direction.md` §1) replaced
      that with the mesh built at 0.32× natively, always — the *decision* (hero-scaled props, 0.32
      tsinelas) is unchanged; only the *mechanism* moved from a runtime hack to the mesh itself.
      *Original statement of the fork, kept so the history reads honestly:* 🤖 Opus, high
      Measured on 2026-07-27: the tsinelas mesh is **1.35 units long against a
      1.598-unit Person — 84% of the character's own height**, and the lata is
      **1.125 units, 70% of a Person**. Rendered, a Person carrying the slipper
      reads closer to carrying a surfboard. But both are player-controlled units
      inside a 1.6-unit capsule, so this is a real design fork and not a bug:
      either (a) keep props hero-scaled and shrink the tsinelas *only while
      carried*, or (b) scale the props toward plausible size and retune capsules,
      hitboxes, camera distance and movement feel with them. **(a) is the
      recommendation** — it is contained, it protects the playtested movement
      numbers, and the moodboard's role cards draw the can and slipper as hero
      objects. Decide it before 2.1: the environment kit's 2-unit grid is sized
      against these props.
      *Blocked:* 2.1, and the final tuning of `HAND_CARRY_OFFSET`. **Both now released.**
- [ ] **1.2b · Should the Person be literally larger? Deferred to after 0.4, deliberately.** 🧑 ⛔ 0.4
      The human's steer during the 1.2 pass was *"make humans bigger, objects should fit in hand."*
      The second half is delivered by 1.2/0.6. The first half is **not rejected — it is costed**:
      `PERSON_SCALE` is visual-only, so raising it desynchronises the model from the 1.6 capsule and
      drags in the capsule and hurtbox heights, `FppPivot` (reopening B-78's failure class),
      `HAND_CARRY_OFFSET`, the TPP spring arm, and the arena's read at unchanged `SPEED`. That is a
      pass of its own, in shared and build-lane files, and it must never land inside an art commit.
      **Gate it on a human having actually played 0.4** — the question "is the Person too small"
      cannot be answered from a screenshot. See `Handoff.md` §0.11.
- [ ] **1.3 · 🧑 Does the Person get its own ability roster?** ⛔ HUMAN
      Or does every Person share the one Tag? Open since the GDD. **Blocks 3.3
      (character select)** — the Prop half of that screen is buildable without
      an answer, the Person half is not.
- [ ] **1.4 · 🧑 Circular Economy as a secondary theme angle — DECIDED: yes.** 
      Recorded here rather than left open: the can/slipper premise is literally
      about reusing everyday objects as sports equipment, the judging rubric
      offers it as a secondary theme, and it costs two sentences in the synopsis.
      **Written into the synopsis plan at 6.5.** The human can veto it there; it
      does not need to stay an open question blocking a document.
- [ ] **1.5 · 🧑 Option A vs Option B — the ship decision. Deliberately still open.**
      **Both modes stay in active, equal development** as separate, selectable ruleset —
      **AMENDED 2026-07-28: Option A is now parked, not equal.** User decision after the 2.7
      rules pass below: Option B is the primary ruleset going forward; Option A stays correct,
      selectable, and untouched, but is deprioritized and "will build option a another day, not
      sure if we have time for it." Every doc that used to say "pick one and delete the loser" is
      still corrected — Option A is not being deleted — but "equal development" no longer holds.
      Both are wired end to end and both are still selectable from the main menu. The final choice
      of what ships in the demo is the human's, on their own timeline. Kept as its own visible line
      so it does not quietly disappear — but it **blocks nothing** and no item below is allowed to
      slow down on Option A because it might still be chosen.

---

## Phase 2 — Build the world

The largest single lever on how finished this reads, and the phase with the
most internal ordering. **2.1 gates 2.2 gates everything else in the phase** —
you cannot lay out a map from a kit that does not exist, and you cannot tune
HUD contrast or hazard placement against a grey box.

- [ ] **2.1 · The environment kit (M-6).** ~~⛔ 1.2~~ **unblocked — 1.2 decided 2026-07-28**
      Split deliberately into two briefs, because it needs two different hats:
  - [x] **2.1a · Kit art direction and piece list.** 🤖 Opus, high
        **Delivered as [`Art_Direction.md`](Art_Direction.md).** 26 pieces across a
        core set, an Eskinita set and a Bayan Plaza set, each with footprint on the 2-unit grid,
        height, triangle budget, materials by `UiTheme` token and what it contributes. Also: the
        Metro/Eskinita and Province/Bayan-Plaza naming reconciled explicitly, the argument for
        folding **Barong Barong into Eskinita's boundary rather than building a third map**, a
        twelve-token `ENV_*` environment palette added to `ui_theme.gd`, the three-layer boundary
        technique, and the height law derived from the measured **1.25-unit FPP eye height**.
        Ticked as a **specification** — no geometry exists yet; that is 2.1b.
  - [x] **2.1b-0 · `transform` parameter on `add_revolve` / `add_extrude`.** 🤖 Sonnet, medium
        **Prerequisite for 2.1b.** `obj_writer.gd`'s revolve is locked to the Y axis at the
        object's origin and its extrude only ever extrudes vertically, so an upright wheel or a
        leaning sheet is not expressible. Add an optional trailing
        `transform: Transform3D = Transform3D.IDENTITY` applied to every emitted vertex — ~6 lines.
        It cannot break shading (`recalculate_normals()` rebuilds from geometry and the spec
        already mandates it per piece) and cannot break determinism (`_fmt` snaps after the
        transform, and the weld key is the printed form). Rationale and the no-change fallback are
        in `Art_Direction.md` §5.
        **Done, verified by running:** a 90°-about-X transform on a flat revolve profile produced
        vertices spread across 5 distinct Y values (confirmed upright, not still flat); an
        identity-transform call produced byte-identical vertices to the old no-arg call (zero
        behaviour change for every existing caller); a translated `add_extrude` moved every
        vertex. Generator run twice — clean. `wall_corrugated_leaning` and `tricycle` are
        unblocked for whoever builds 2.1b.
  - [x] **2.1b · Generate the kit — 28 pieces, in `tools/models/env_kit.gd`.** 🎨 Design (reassigned)
        Reassigned from Sonnet to Design by the human because the path-ownership table already
        gives Design `generate_all.gd`'s shape functions; claimed in `SHARED_LOCKS.md` first.
        **Verified by running:** determinism (three runs, output hashed, byte-identical); every
        piece under 400 tris (largest `sari_sari_store` at 216); no `#f87020`/`#0080e8` in any
        `env_*.mtl`; imports clean; and **rendered** — five bugs were found that way and fixed
        (invisible wires, unreadable corrugation, sampay posts standing in the road, a hazard decal
        that shouted over the Props, and a base circle buried inside the road tiles).
        **Complete as of 2026-07-28 — 30 pieces.** `wall_corrugated_leaning` and `tricycle` landed
        once the Build lane shipped 2.1b-0; they are the only two pieces that pass a `transform`.
        Tricycle 192 tris, leaning sheet 144. Both placed in Eskinita and rendered.
        *Deferred, do not lose:* **convex collision per piece was NOT generated** — Eskinita
        collides on one invisible box ring behind the wall line instead, which
        `Art_Direction.md` §4 permits for a continuous wall. A `GridMap` map would need the
        per-piece shapes.
- [~] **2.2 · Eskinita — the first real map (M-7).** 🎨 Design — **built, wired and rendered**
      Opus rather than Sonnet: the hard question is "does this read as a
      Philippine side street", not "does this scene load".
      **`scenes/maps/Eskinita.tscn` exists, loads, and renders as a street** — asphalt, kerbs,
      GI-sheet wall line with rust skirts, electric posts with sagging service wire, sampay strung
      overhead, building masses behind, seeded clutter, lane markings, base circle, throwing lines
      and a chevroned jeepney lane. Authored by `tools/maps/build_eskinita.py` (123 instances is
      too many to hand-place); edit the script, not the scene. Screenshots in the PR.
      **Wired in at 2.2a (v4.28).** `Main.tscn` no longer carries a world at all; `main.gd`
      instances the picked map into `$Map` and reads its `SpawnPoints`. A 1200-frame soak of the
      match scene runs silent — no errors, no kill-plane respawns. **What is still missing is a
      human:** this stays `[~]` until the remaining work below is done. That is 0.4.
      Includes, in one coherent pass rather than scattered:
  - [ ] `scenes/maps/Eskinita.tscn`, playable area kept at roughly the current
        40×40 — **do not change arena scale in the same commit as arena art**,
        or a movement-feel regression is unattributable.
        ⚠️ A same-day resize to a bigger square (W/Z_END 24.0) was tried and fully reverted
        2026-07-28 — the actual complaint was the confinement radius, not map footprint. See
        2.7's entry below and `Handoff.md`'s session log.
  - [ ] **A `SpawnPoints` node with four `Marker3D`s**, read by `main.gd` in
        preference to its hardcoded `SPAWN_POINTS`. This is where **B-54** (spawn
        points ignore team membership) finally gets answered — two team pairs,
        opposite ends.
  - [ ] **The boundary, dressed — no bare walls.** The moodboard's own
        annotation on the Metro map: *"basically just add random assets on the
        edge that acts like a wall."* Trees ringing the province map, buildings
        ringing the metro map, sampay/puspin/aspin clutter on the barong-barong
        map. **Correction to a widely-repeated claim: the current build does not
        have brown box walls. It has four invisible `StaticBody3D` colliders
        with no mesh at all** (`Main.tscn` `Bounds/Wall*`), so the arena edge is
        literally the floor meeting the sky. That is worse, not better, and the
        fix is the same: visible dressing with collision, or an invisible
        collider hidden just behind visible geometry. Never a bare coloured box.
  - [ ] **Field markings as real geometry** — base circle, throwing line, team
        side markings, and the `HazardZone` footprint. Supersedes 0.3.
  - [ ] Per-map skybox — province = blue sky with clouds, metro = hazy city,
        barong barong = the purple/orange sunset. **Verify each is actually
        wired to its own map and not left on the default;** `Main.tscn` currently
        ships a flat `background_color` and no sky at all.
  - [ ] `Main.tscn` instances the map instead of carrying `Floor`/`Bounds`
        directly, so map #2 is a scene swap rather than a rebuild.
- [x] **2.2a · Wire Eskinita into the game.** 🎨 Design (reassigned) — **verified by render**
      The map is built and rendered but nothing loads it. Three things, all build-lane:
      1. `Main.tscn` instances `scenes/maps/Eskinita.tscn` in place of its own `Floor` and
         `Bounds` — which also retires B-83 (the old colliders sit at ±40 around a ±20 floor) and
         B-82 (its floor top is y=+0.5; Eskinita's is y=0, as every doc assumes).
      2. `main.gd` prefers the map's `SpawnPoints/Spawn0..3` `Marker3D`s over its hardcoded
         `SPAWN_POINTS`. **This is where B-54 finally gets answered** — the four markers were
         placed as two team pairs at opposite ends of the alley.
         ⚠️ **Superseded 2026-07-28, same day, after 0.4-adjacent playtest feedback** ("two teams
         spawn on completely different ends and i dont think thats how it should go"). The four
         slots are now ROLE-based (Can / Taya / Attacker / Tsinelas), not team-based, centred on
         the map's own base circle and 6-unit throwing line — see the new checklist item below.
         B-54's underlying complaint (team membership was being ignored) is still answered, just by
         a different, more accurate layout.
      3. Delete the temporary decals from 0.3; the map carries real ones now.
      *Then* 0.4 can be played in a real map rather than a grey box.
- [~] **2.3 · Persons — moodboard restyle (M-5).** 🎨 Design — **steps 1+3 done and
      render-verified; step 2 (accessories) NOT done, step 4 was already done.**
      Palette retint landed as a UV-cell palette-remap shader
      (`assets/characters/persons/materials/`), wired through each `.glb.import`'s
      `use_external` material. Verified by render at 1.5u, 3.6u and the 20u the
      acceptance criterion names. **Step 2 (accessory meshes on bones) is blocked
      on lane ownership, not on art** — attaching a mesh to a bone is
      `scripts/characters/character_visual.gd`, which is 🔧 Build's. See
      `Handoff.md` M-5 for the exact 20 lines needed. Stays `[~]` until 0.4 plays it.
- [~] **2.4 · Bayan Plaza — the second map.** 🎨 Design — **built and rendered**
      A scene swap once 2.2 has proven the pattern. **First candidate to cut**
      under time pressure — see "If time runs short" at the bottom.
- [x] **2.5 · Proportion fix — Item A, `Art_Direction.md` §1.** 🔧 Build — **verified by render**
      The two hero props (lata 1.12, tsinelas 1.35) were the single biggest credibility problem in
      the build — the can was taller than the monobloc chair beside it. Fixed in dependency order:
  - [x] **Per-unit collision.** `CharacterBase.tscn`'s `CollisionShape3D`/`Hurtbox`/`Hitbox`/
        `GrabArea` are now `resource_local_to_scene = true`; `character_base.gd`'s new
        `_apply_role_collision()` sizes each from `is_person`/`is_can`, called from `_ready()` and
        `reset_for_new_round()` (a Prop's `is_can` flips every round). Person unchanged
        (0.4/1.6); Can and Tsinelas each get their own capsule and a proportionally-scaled melee
        reach. Took the `CharacterBase.tscn` lock in `SHARED_LOCKS.md` first, per protocol.
  - [x] **Both prop meshes rescaled.** `generate_all.gd`'s `LATA_SCALE` (0.30) and
        `TSINELAS_SCALE` (0.32) applied as a post-deform `Transform3D.scaled()` on every
        `add_revolve`/`add_extrude` call (the 2.1b-0 `transform` param) — no dent depth or strap
        control point needed touching. Shipped: lata 0.3375 tall (target 0.34), tsinelas 0.432
        long (target 0.43). Took the `generate_all.gd` lock first.
  - [x] **`HAND_CARRY_OFFSET` re-measured, `TSINELAS_CARRY_SCALE` deleted.** Along with
        `_scale_while_carried()` and `CARRY_SCALE_LERP` — a feature removed, not reimplemented, per
        the audit's own prediction (`TSINELAS_CARRY_SCALE` 0.32 × 1.35 = 0.432, so the carried
        slipper was already the right size). Re-measuring was not a trivial reapplication of the
        old target: deleting the runtime scale meant the model's capsule-floor drop was no longer
        compensated, dropping the mesh 0.544 units lower than before. Confirmed by rendering
        `tools/render_probe.gd`'s viewmodel mode (screenshots, not calculation alone) — the first
        analytically-derived value put the slipper broadside-close to the FPP camera and filled
        most of the frame; iterated to the shipped value, which reads attached to the hand in both
        the FPP viewmodel shot and the third-person debug camera, without covering the crosshair.
  - [x] **`base_circle_decal` resized.** 3.0 m outer diameter (drawn around the old 1.12 m can)
        down to 1.4 m (radius 0.70), inside the audit's own 1.2–1.5 m window. Ring width kept at
        0.15 rather than shrinking 1:1, for the same foreshortening-at-distance reason it was
        widened from 0.06 originally.
  - [x] **4.4a fixed as part of the same pass.** `throw_bakya`'s range (4.81 units, less than half
        of every other profile) was a tuning bug, not an identity — `gravity_scale` 1.6 → 1.0,
        `arc_angle_deg` 8° → 12°, `launch_speed` unchanged at 14.0. New max range 7.23, still
        shortest of the four by design (heavy, close-range) rather than by being broken.
        `ThrowProfile.hit_radius` halved across all four `.tres` files — several were larger than
        the entire rescaled tsinelas mesh. Exact combat-feel numbers stay 4.4's job.
  - [x] **Jump left untouched, deliberately.** `JUMP_VELOCITY` is a MAP constraint (interior
        clutter capped at 1.0 for the 1.25 FPP eye height to see over), not a feel one, and
        rescaling the props doesn't move that ceiling.
      **What is NOT verified:** combat feel (does a can's shrunk melee reach feel fair, does
      `throw_bakya` at 87% charge feel right) — that needs a human on the keyboard and is 4.4's
      job, not this item's.
  - [x] **B-88, found and fixed same session.** The render checks above screenshotted a carried
        slipper and a standalone preview turntable — neither actually spawns a unit and lets it
        settle onto a floor. In a real match, both props rendered UNDER the floor:
        `_align_to_capsule_floor()` dropped every model a hardcoded 0.8 below the character's own
        origin, correct only while every unit shared one 1.6-tall capsule. Found by the human
        immediately after this item merged. Fixed same session — see `Handoff.md` B-88. Re-verified
        by render.
  - [x] **B-89, found and fixed same session.** Same bug class as B-88, different node:
        `character_nameplate.gd`'s ring (`y = -0.78`, radius 0.55) and label (`y = +1.05`) were also
        hardcoded for the old shared 1.6-tall capsule. On a Can the ring drew nearly a metre below
        the model's actual feet; on a carried Tsinelas the whole nameplate rides along with it, so
        the disconnected ring appeared to float around the held object — "the slippers still have a
        circle around it when holding". Fixed by adding `CharacterBase.capsule_height()`/
        `capsule_radius()` as a shared accessor and having the ring/label read it, applied explicitly
        from `character_base.gd` right after `_apply_role_collision()` (not from the nameplate's own
        `_ready()`, which runs before the capsule is resized — see the code comment). Re-verified by
        render: the can's ring now sits tight at its base, the carried slipper's ring is a small band
        at the object.
  - [x] **B-90, found and fixed same session.** Two related reports: "the slippers look weird af when
        holding it" and "my arms float during windup and when i run while holding". (a)
        `character_visual.gd::_play_locomotion()` fell back to `walk`/`sprint` the instant a carrying
        Person moved — the rig has no `holding-right-walk` clip — and `carrier.gd`'s
        `_step_carried()` snaps the carried object to the arm BONE's live position every physics
        frame, so the walk cycle dragged the held slipper (and the FPP viewmodel arm chasing that
        same position) through its swing. Fixed by checking `_is_holding()` before speed, not after:
        the carry pose now wins outright, legs stop swinging while holding+moving instead of the hand
        swimming. (b) The tsinelas is a flat, thin object and the arm bone's fixed rotation presented
        it close to edge-on from the camera — a sliver, not a slipper. Fixed with a 55° tilt applied
        in the object's own local frame before the hand's rotation, in `carriable.gd::_step_carried()`.
        Re-verified by render: the carried slipper reads as a recognisable shape in both FPP and
        third person. (a) is verified by code-path elimination — a single frame cannot capture
        "stops swinging while running".
- [x] **2.6 · Spawn layout redesigned as role-based, not team-based.** 🔧 Build — **verified by
      render and a 400-frame soak**
      User feedback after playing the proportion-fixed build: "two teams spawn on completely
      different ends and i dont think thats how it should go." Correct, and it was more than
      distance: the old scheme spawned `TeamAProp`/`TeamAPerson` at one fixed end of the alley and
      `TeamBProp`/`TeamBPerson` at the other, unconditionally, while the map's own
      `base_circle_decal` and `throwing_line_decal` (`Art_Direction.md` §9) sit at the centre
      regardless of who is spawning where — position tracked TEAM (fixed all match) instead of ROLE
      (flips every round via `team_is_can_side`), so the Can/Taya pair sometimes spawned at the
      north end and sometimes the south, never actually AT the base the mechanic is built around.
  - [x] `main.gd`'s four spawn slots are now roles — `SLOT_CAN`/`SLOT_TAYA`/`SLOT_ATTACKER`/
        `SLOT_TSINELAS` via the new `_role_slot()` — instead of a stored team-fixed index. Both
        `_spawn_player` (initial spawn) and `_reset_world` (every round reset) compute the slot from
        the character's current role.
  - [x] `build_eskinita.py` / `build_bayan_plaza.py`: Spawn0 sits on the base circle
        `(0, 0.17, 0)`, Spawn1 (Taya) a couple of units off it, Spawn2 (Attacker) at the 6-unit
        throwing line, Spawn3 (Tsinelas) beside the Attacker. Both `.tscn` files regenerated; diff is
        exactly the four spawn transforms in each.
  - [x] **Auto-grab at round start.** `_reset_world` now hands the tsinelas to the attacking Person
        directly (`Carriable.host_grab()`, already host-gated internally) instead of leaving it loose
        for them to walk over and pick up first — matches `Dev_Plan.md` §3's beat-by-beat loop, which
        opens with "the attacking Person carries the tsinelas," not a pre-round chore.
      **Not verified:** how this plays with a human — whether the Taya's distance from the Can, or
      the Attacker's distance from the throwing line, feels right. That is 4.4's job once someone has
      actually played it.
- [x] **2.7 · Option B rewritten — confinement, tag-to-win, auto-seal, 5-fall cap.** 🔧 Build —
      **verified by parse + two 800-frame soaks + a driven lobby-flow render; NOT verified by play**
      User design pass, 2026-07-28, after playing the spawn-redesigned build: bring the rules
      closer to real tumbang preso, with both sides getting a clear, fast win condition instead of
      a health bar or a manual seal-hit. Rewrites Option B in place — same `GameLaunch.GameMode`
      enum value, Option A untouched (see 1.5's amendment: Option A is now parked, not equal).
  - [x] **Team-can confinement.** The Can and its Taya are confined to a `CONFINEMENT_RADIUS`
        (3 units, first guess) circle around the base circle (world origin) for the whole round.
        `character_base.gd::_move_and_confine()` wraps every `move_and_slide()` call site in the
        file so no code path can bypass it. Gives the Taya room to body-block without being able
        to chase the attacker back to the 6-unit throwing line — the load-bearing assumption
        behind the next item being fair rather than a guaranteed instant loss for team slipper.
  - [x] **Tag-to-win.** Any hit from the Taya landing on the attacking Person — Bump or the Tag
        ability, both resolve through `hitbox.gd`'s one function — ends the round for team can,
        after the normal stagger/VFX still plays. Previously a Person hit was stun-only with no
        round effect.
  - [x] **Auto-seal.** The existing 2s self-right window is unchanged, but `character_base.gd` now
        calls `seal()` itself the instant the window lapses unrecovered, instead of waiting for an
        attacker to walk up and physically seal it (the old Option B behaviour, retired). Falling
        and staying down is sufficient on its own for team slipper to win.
  - [x] **5-fall cap.** `round_manager.gd` counts every Downed transition on a tracked Can this
        round, saved or not; reaching `FALL_LIMIT` (5, first guess) auto-wins for team slipper
        regardless of whether that particular fall was recoverable. Independent of and in addition
        to auto-seal — stops a Taya who can save everything from making a round unloseable.
  - [x] **Ready-up gate for local matching.** Local previously skipped straight to the match; it
        now routes through `Lobby.tscn` like Host/Join always did. `lobby.gd` gained a `"local"`
        branch that does no networking (nothing to actually wait for on one PC) but keeps the same
        READY → START rhythm. `main_menu.gd`'s old direct-to-Main `_go_to_match()` is deleted.
      **Verified:** parse clean; two 800-frame soaks of the real match scene, silent; a new `lobby`
      mode in `tools/render_probe.gd` drives the actual Ready button (`pressed.emit()`, not a
      hand-set flag) and confirms Start goes disabled → enabled exactly once, with screenshots of
      both states.
      **First human playtest, 2026-07-28:** 5-fall cap and the new spawn distances (2.6) confirmed
      good, no change needed. Tag-to-win is fine for now, but the human wants it **re-checked
      again** once more changes land — treat as still open, not closed.
      **Second playtest round, same day:** confinement radius reported too small — "the box that
      defend can move in is so small, he can barely move, theres no room for outplays."
      `CharacterBase.CONFINEMENT_RADIUS` raised 3.0 → 5.0 (still a full unit short of the 6.0
      throwing line, so the Taya still can't reach the attacker's line). `build_eskinita.py` now
      draws the actual confinement boundary on the ground — first as a chalk-style ring
      (`CONFINEMENT_RING_RADIUS`), then **replaced same day** with a chalk-style SQUARE
      (`CONFINEMENT_BOX_RADIUS`, tiling `team_side_decal` — see `Handoff.md`'s session log) per
      user feedback ("the circle you made was ugly ... can we just use a square" — a real tumbang
      preso boundary is a straight-edged box). Before this there was nothing marking the edge of
      the box at all — only the tiny base circle and the distant throwing line. Also fixed while
      touching this: several markings (`TeamSide*`, `JeepneyLane`, and the new square) were sitting
      with their underside `MARK_Y` (0.07) above the floor regardless of whether they actually
      overlapped a raised tile — reported as "all assets like lines are floating off the floor."
      Only `BaseCircle`/`ThrowingLine*` (which do overlap `road_tile_line` tiles) still use
      `MARK_Y`; everything else uses a new, much smaller `MARK_Y_LOW`. A standing warning about
      this class of bug is now in `Art_Direction.md` Part 4 and the DESIGN-ART paste-ready prompt.
      **`build_bayan_plaza.py` does not have the confinement square yet.**
      Re-tune both together if either moves again — they're coupled, see `Dev_Plan.md`'s Option B
      section. Auto-seal timing itself: still not separately confirmed by feel. **Verified by
      render only, not yet by play.**
- [~] **2.8 · Pre-round free-roam + in-world ready-up, Single Player only.** 🔧 Build — **verified by
      render, not yet by play**
      User feedback, 2026-07-28: "i wanted the ready button to be in the game itself not in home
      screen, i want ppl to be able to move around with no restrictions whiile waiting for ready
      THEN everyone gets teleported in the right restricted area." Local now skips `Lobby.tscn`
      entirely (`main_menu.gd::_on_local_pressed()`) and goes straight into `Main.tscn`.
      Characters spawn as before, but `MatchManager.begin_next_round()` is deliberately **not**
      called yet — `CharacterBase._is_confined_to_base()` and `Carriable.movement_speed_scale()`
      are both now gated on `RoundManager.round_active`, so with the round not yet active nobody
      is confined and the Tsinelas Prop isn't stuck at crawl speed either. A new HUD prompt
      (`%ReadyPrompt`) reads "Walk around freely. Press [R] when you're ready to start the round."
      Pressing the new `ready_up` input action calls `begin_next_round()`, whose existing
      `round_started` → `_on_match_round_started()` chain already repositions everyone to their
      role spawn and starts the round — no new teleport code needed, that infrastructure already
      existed.
      **Explicitly NOT done:** Host/Join are unchanged and still gate behind `Lobby.tscn`'s
      ready-up screen. Extending this same free-roam pattern to networked play needs per-peer
      ready state replicated live inside the match scene rather than in the lobby, which is a
      separate, real pass — see `Handoff.md` §5.
      **Second pass, same day, first real playtest of this item:** B-94 (free-roam was completely
      frozen — a separate, pre-existing input gate also fired whenever `round_active` was false)
      and B-95 (Can fell through the floor when the match's LAST round ended, since no reset ever
      runs after `match_won`) both found and fixed — see `Handoff.md`. Also: B-96 (spawn layout was
      never actually role-based for Single Player, the free-roam window just exposed it — fixed), the
      Taya's spawn moved behind the Can instead of beside it, a 3-2-1-GO countdown added between
      the ready press and the round actually starting, and the confinement marker rebuilt as a
      square (see 2.7). **Verified by render, including a corrected spawn-layout screenshot with
      the Can now inside the base circle. Still not verified by play.**
      **Third pass, same day — the real root cause of "cann fell off map again":** B-100 (role
      swaps routinely teleport two characters through each other's old spot, one at a time, and
      the physics engine depenetrates the resulting overlap with a real impulse — fixed by parking
      everyone at a separated holding spot before any of them move to a real one) and B-101 (a
      unit that was CARRIED when the round ended came out of reset with its own collision still
      disabled, free to sink through the floor — fixed). Found via a new permanent diagnostic,
      `tools/render_probe.gd`'s `round2` mode, which drives two real round transitions and prints
      every unit's role/position at each step — see `Handoff.md` for the exact numbers before and
      after each fix. **Confirmed by the probe: round 2's actual gameplay-start positions are now
      exactly correct. Still open: the probe shows transient bad positions for two units *during*
      the frozen intermission window itself, before settling correctly — not root-caused further
      this pass.**

- [~] **2.9 · The two hero props, rebuilt to their own asset moodboards.** 🎨 Design —
      **verified by render at 0.85, at 1.1 and at match distance; NOT verified by play**
      User request, 2026-07-28, with two asset moodboards attached: a worn brown
      flip-flop with a tan webbing Y-strap, and a low-poly **Sarsi** can. Recorded in
      `Art_Direction.md` §1b, which is now the written spec for both props — the images
      themselves are not in the repo, so attach them to any task that touches either.
  - [x] **A `PROP_*` palette band.** `PROP_FOAM`, `PROP_FOAM_DARK`, `PROP_WEBBING`,
        `PROP_SARSI_RED` in `ui_theme.gd`. The props were wearing UI tokens because B-81 had no
        others to hand; the human confirmed that magenta was a placeholder, not a decision.
        Neither role hue appears on either prop, so **B-81's rule survives intact** — see the
        superseded-colours note on it in `Handoff.md`.
  - [x] **Tsinelas.** Three-layer foam sole (inset outsole → full-width foam → inset footbed) so
        the widest point sits at mid-height and the edge reads as a moulded bevel; total thickness
        0.10 → 0.120. Strap section widened and flattened to real webbing proportions. Strap
        anchors were **overhanging the footbed edge by 0.019 in mid-air** — the old comment checked
        the band's centreline against the sole outline instead of its outer edge against the
        *inset* footbed. Fixed by winning the margin back from the band width rather than by
        shortening the strap span, which a first attempt tried and which rendered as one band
        across the toe instead of a Y.
  - [x] **Lata — Sarsi livery.** Aluminium lid, rolled rim and base crimp; banded blue body
        standing in for the moodboard's gradient; wavy white band; red sail and ball. Lid
        flattened from its slight dome and given a **pull tab** — the same shape the game's own
        logo uses for the O of PRESO (3.2).
  - [x] **`_lata_wall()` — the printed wall is no longer a revolve.** `add_revolve` paints one
        material per full ring, so it cannot express a sail. The wall is emitted strip by strip as
        stacked layers sharing boundary functions. ⚠️ **Deliberately not decals on a plain wall:**
        this wall gets dented, and an offset decal shell would shear off the crease and hang in
        mid-air — `Art_Direction.md` Part 4's floating-geometry rule arriving through a side door,
        on the one prop whose job is to get hit. The sail *is* the wall, in a different colour, and
        runs through the same `deform`. Dent depth re-measured after the rebuild: **0.027 world
        units against 0.029 before.**
  - [ ] **No printed type on the can.** The `sarsi` wordmark, `330 mL` and the barcode are not
        buildable: `obj_writer.gd` emits no UVs and the `.mtl` carries one flat `Kd`. Needs a UV +
        texture pipeline that does not exist — filed in `Handoff.md` §5 with the reason it may not
        be worth building (the wordmark lands ≈13 px tall at the distance the can is actually
        read). **Everything else on both boards is in.**

- [x] **2.10 · Floating markings made a build failure instead of a playtest report (B-103).**
      🎨 Design — **verified by render + both builders' own gate; the gate itself is the
      regression test**
      Fourth report of the same bug: *"i keep flaggging this still broken, thoroughly think about
      how to make sure this problem doesnt show up again."* So this item is deliberately not
      another Y tweak.
  - [x] **Root cause, measured.** `throwing_line_decal` is 8m wide; the `road_tile_line` strip it
        crosses is 2m wide and 6.2cm tall. Lifted to 0.070 to clear the strip, it hung **7cm in
        the air across ~75% of its length**. The base circle floated 8mm. **No single Y can be
        flush for a marking that spans a step** — which is why retuning the constant three times
        (0.07 → 0.015 → 0.001) never worked and never could.
  - [x] **`tools/maps/floorcheck.py` — the gate.** Samples every marking's real footprint against
        the real ground height beneath it and **aborts the build before the `.tscn` is written**,
        naming the node and the gap in millimetres. Reports "spans n surface heights" as a
        separate error from "floats", because that one needs the shape split, not the number
        changed. Reads mesh bounds from the `.obj` rather than trusting the "decals start at
        local y=0" claim written in two other places.
  - [x] **`add_line()` splits line markings at every step automatically.** Eleven faulty markings
        became 26 verified-flush pieces. `MARK_Y`/`MARK_Y_LOW` deleted from both builders — a
        human deciding what is underneath a marking was the root cause, not the value chosen.
  - [x] **Both maps.** Eskinita (26 markings) and Bayan Plaza (5). Determinism re-checked.

- [ ] **3.1 · Land the display typeface (F-2).** 🤖 Sonnet, medium ⛔ 1.1
      Mechanical once the decision exists: `.gitattributes` LFS rules committed
      *before* the binary, face + verbatim licence file in `assets/ui/fonts/`, a
      clean grotesque for body text, `DISPLAY_FONT`/`BODY_FONT` wired through
      `ui_theme.gd` **as type variations only**, regenerate the theme, record the
      licence for Form 03, and delete the stale blocker notes.
- [ ] **3.2 · The logo as a real asset (M-8).** 🤖 Sonnet, medium ⛔ 1.1
      The moodboard's lockup has the **O of PRESO replaced by a top-down can
      lid**. No font substitution reproduces that. Export from Canva at 2048px
      PNG if possible; otherwise build the lockup from 3.1's face plus a
      generated can-lid glyph and log it as a known deviation.
- [~] **3.3 · Character select (U-5).** 🤖 — **appearance shipped earlier; the KIT half shipped in 10.5. Person abilities still ⛔ 1.3**
      The select screen (12 Persons, 6 lata, 6 tsinelas) landed as an appearance
      picker: a rig plus a palette, with `main.gd` still choosing a Prop's
      ability by TEAM (`TSINELAS_ABILITY_TEAM_A`/`_TEAM_B`). So the screen was
      real but the six Prop `.tres` were still unreachable by choice, which is
      what this item actually asks for.
      **10.5 closed that by attaching an `ability` to each lata and tsinelas
      entry** in `character_roster.gd`, rather than adding a fourth and fifth
      picker. That works because the player already picks a lata AND a tsinelas
      separately — and the reason that split exists is the reason a single
      "fighter" pick could not work: a Prop is a lata one round and a tsinelas
      the next, so `_prop_ability_for()` asks the list matching the side being
      played and gets the right answer across every role swap (B-76).
      ⚠️ **Six looks, three kits per side** — two skins share each ability,
      because three `.tres` exist per side and six entries do not. Entry 0 of
      each list keeps today's behaviour. Pairings follow the taglines already
      written in the roster and are a **balance surface**; see the Phase 9
      fairness log before moving any.
      ⚠️ **Persons remain appearance-only.** 1.3 is 🧑 HUMAN and unanswered, so
      every Person shares one Tag/Throw and the screen says so.
      `[~]` not `[x]`: probe-verified across two real instances.
- [x] **3.5 · Map picker in the opening UI.** 🎨 Design (new item) — **verified by render**
      An `OptionButton` plus a one-line tagline on the Play card, mirroring the existing
      `GameModeOption` exactly so it inherits the card chrome for free. Built from
      **`GameLaunch.MAPS`**, not hardcoded in `main_menu.gd`: adding a map is one entry in the
      autoload plus a scene, and the picker, the launch path and the fallback all read the same
      list so they cannot disagree about what exists. `GameLaunch.selected_map` is deliberately
      **not** cleared by `reset()` — it is a preference, not a one-shot handoff like
      `pending_action`, so a player who picks Bayan Plaza does not re-pick it after every match.
      The tagline exists because "ESKINITA" means nothing to a judge who has never played it.
- [x] **3.4 · Off-screen indicators (U-6b).** 🤖 Sonnet, medium
      Screen-edge arrows for your teammate and the Can. `Dev_Plan.md` §3.3 calls
      these **mandatory** for FPP — they are the promised mitigation for the
      Person's narrower awareness cone — and U-6 deferred them.
      **Done, verified by running.** New `OffscreenIndicators.tscn`/`.gd`, driven from `hud.gd`
      with the same cached local character `you_card.gd` already resolves for the crosshair — no
      second scan. Teammate found by team + not-self (a team is 1 Person + 1 Prop, never two of
      the same, so no `is_person` check needed); the Can via a new `RoundManager.get_tracked_cans()`
      accessor rather than re-deriving `is_can` a third time. Standard radar-arrow projection:
      hidden when on-screen, clamped to the inset screen edge and rotated toward the target
      otherwise, including the behind-camera case (`unproject_position()` mirrors instead of
      flagging it — corrected for). Found and fixed one real bug while testing: a target sitting
      exactly perpendicular to the camera's forward axis hits a `p.d == 0` divide inside
      `unproject_position()` and logs an engine error every such frame — guarded against. Verified
      by a headless probe forcing on-screen/behind/far-off-to-the-side cases, and visually via
      `render_probe.gd` at 1280x720 and 1920x1080 (screenshot: an arrow correctly pinned to the
      right edge, pointing at an off-screen teammate). Plain glyph styling; design lane restyles.

---

## Phase 4 — Feel, audio and networking hardening

Genuinely parallel with Phase 2 and Phase 3, on different agents. None of these
touch map scenes.

- [~] **4.1 · Audio — the entire workstream.** 🤖 Sonnet, medium — **landed 2026-07-29,
      probe-verified, NOT yet heard by a human.**
      The whole minimum viable set and more. **32 SFX, all procedurally
      synthesised** by `tools/audio/generate_sfx.py` (numpy + scipy; no
      microphones, no samples, no downloads — the licence line for all of it is
      one row). **Two CC0 ambience loops**, one per map, sourced from
      OpenGameArt and logged in `assets/audio/ambience/OPENGAMEART_CC0_LICENSE.txt`.
      - **Buses:** `default_bus_layout.tres` — Master / SFX / Music, both
        children sending to Master. Registered in `project.godot` under
        `audio/buses/default_bus_layout`.
      - **`AudioManager`** (autoload, listed FIRST so `SettingsManager` can push
        volumes into it on load): the name→stream table, an 8-voice UI pool and a
        12-voice positional pool, per-sound level trim, pitch jitter, and a
        real-millisecond retrigger guard.
      - **Settings:** Master / SFX / Ambience sliders in `SettingsPanel.tscn`,
        persisted to `user://settings.cfg` alongside the rebinds.
      - **Hitstop sync:** the lata impact fires in `CharacterBase._flash_hit()`
        on the statement before `_hitstop()`. The sound NAME is chosen by
        `hurtbox.gd::impact_sfx()` (the struck object owns what it sounds like)
        and routed by `hitbox.gd` through the existing `_rpc_play_hit_vfx`
        broadcast, so it lands on the same frame on every peer.
      - Also wired: knockdown, seal, bump, tag, throw whoosh + charge, slipper
        land/bounce, grab, both halves of the reset channel, round win/loss,
        match win, countdown, jump, land, dash, guard block, downed, respawn,
        all five abilities, and the whole menu front end.
      - **Verified by `tools/audio_probe.gd`** (25 checks, 0 failures): buses
        exist and route correctly, all 32 streams load, **zero leading silence in
        every imported sample**, `play()`/`play_at()` start real voices, the
        retrigger guard holds, and both maps' `Ambience/AmbienceLoop` autoplays
        on the Music bus with `loop=true`.
      - `[~]` **not `[x]`: nobody has listened to it yet.** Every claim above is
        measurement, not taste. Whether the mix is right, whether the impacts are
        punchy enough over four players shouting, and whether the ambience beds
        suit the two maps are all open until a human plays it.
      - **B-119, 2026-07-29:** the retrigger guard held off the trigger RATE but
        not the overlap — a 300 ms `lata_impact` retriggering every 60 ms still
        stacked ~5 ringing copies into a buzz under sustained contact. Fixed by
        keying the guard window to each sound's own `AudioStream.get_length()`
        instead of the flat 60 ms constant; see `Handoff.md` B-119. Worked
        through from the generator's source durations, not re-heard or
        re-probed (no Godot binary in this session) — the listening pass this
        item is already waiting on should cover it.
      - **B-120, 2026-07-29:** separately, nothing on the Master bus stopped
        the summed mix from clipping — a busy 2v2 fight regularly lands
        several full-scale SFX in the same window, and 0 dB on every bus with
        no ceiling anywhere means that overs and clips. `AudioManager` now
        installs an `AudioEffectLimiter` on Master in `_ready()`. See
        `Handoff.md` B-120. **Unverified against a real build** — no Godot
        binary in this session; run the smoke gate and play a real 2v2
        before treating this as closed.
      - **B-121, 2026-07-29 — the buzz, actually found and actually measured.**
        B-119 and B-120 were both reasoned out without a Godot binary and
        **neither was the cause.** Measured with the new `tools/audio_mix_probe.gd`
        (captures each bus separately during a real match): the **SFX bus was
        clipping at peak +2.0 dBFS**, over full scale, while Master read a
        healthy −1.4 — which is why the Master limiter could not help and why
        watching Master alone missed it. Two causes, both fixed:
        (a) `_TRIM_DB` ADDED gain to three sounds on top of `generate_sfx.py`'s
        0.85 normalisation, so `lata_impact` at +1.5 dB was 1.010 — **clipping
        on its own, on every hit, before any summing**; every trim is now ≤ 0
        and `_trim()` clamps as a backstop. (b) No headroom for summed voices:
        new `HEADROOM_DB = −7.0` attenuates every voice, applied in `_trim()`
        rather than as bus volume because `_apply_bus()` overwrites bus volume
        from the player's slider. A limiter was also added on **SFX**, since
        the Master one sits downstream of where the overload happens.
        **Re-measured after the fix: SFX peak −1.0 dBFS, no bus clipping, and
        the ambience sits 14 dB under SFX** (it was never the problem — that
        was checked and ruled out). The probe now fails on any bus going over,
        so this cannot silently regress. Still `[~]`: measured, not yet heard.
      - **B-122, 2026-07-29 — a second, separate cause of the same report.**
        After B-121 measurably removed the clipping, the noise was still there.
        `_on_state_changed_audio()` decided "did this unit just get back up?"
        from `_downed_time_left > 0.0`, but `self_right()` never clears that
        timer — so after ANY knockdown, every later stagger recovery fired a
        450 ms chime for the rest of the round. Fixed with a real
        `_audio_prev_state` field. Found by `tools/audio_combat_probe.gd`
        (new), which drives the stagger/knockdown path directly — the earlier
        probe missed it because in an AI-only match **nothing ever went
        DOWNED**. See `Handoff.md` B-122.
      - **B-123, 2026-07-29 — THE ONE THE USER ACTUALLY HEARD.** *"Constant
        steady static/wind sound... Ambience to 0 completely removes it."* The
        two CC0 field recordings passed every check that existed (licence,
        format, loop flag, 18 dB under SFX) and were still unusable: they are
        outdoor recordings, the wind noise on the mic IS the asset, and a real
        recording is broadband — which is what "static" means. **Both replaced
        by `tools/audio/generate_ambience.py`**, so every sound in the game is
        now generated and **there is no third-party audio in the build**. The
        generator asserts <2% of energy above 4 kHz (measured 0.0%), a loop
        seam under 0.02, and a background-bed level — the checks that would
        have rejected the recordings. See `Handoff.md` B-123.
- [x] **4.1a · Jump — every unit, Person and Prop.** 🎨 Design — **playtest 0.4 request.**
      Did not exist: zero occurrences of "jump" in `project.godot` or
      `character_base.gd`. Added `jump_p1..p4` (P1 Space, P2 Numpad-0, P3 RShift,
      P4 Numpad-Enter), rebindable for P1/P2, and one impulse in
      `character_base.gd`. Props jump too — the design pillar is *friendslop*, and
      a hopping lata needs no justification where refusing one would.
      ⚠️ `JUMP_VELOCITY = 5.8` apexes at **0.841**, and that ceiling is a MAP
      constraint: interior clutter is capped at 1.0 so an FPP eye at 1.25 sees
      over it. Above ~1.0 every crate becomes a platform. Verified to parse and
      run 300 frames silent; **not yet felt by a human.**
- [x] **4.1b · P0 from playtest 0.4 — Esc left the mouse captured and never paused.**
      🎨 Design. Three reported bugs, one cause: `settings_panel.gd` had no
      visibility guard on `_unhandled_input`, and a hidden Control still receives
      it in Godot. The hidden panel ate Esc and emitted `back_pressed`, which
      shows the overlay without setting `mouse_mode` or `get_tree().paused`.
- [x] **4.1c · Tab could not reach the Can.** 🎨 Design. Two independent causes.
      Godot binds Tab to `ui_focus_next` and the GUI layer eats it before
      `_unhandled_key_input`, so the switcher never saw it — moved to `_input`.
      Separately, the switcher no-ops in a **real (2+ peer) networked** match by
      design; the 0.4 session was hosted, not Single Player, which is also why
      pause did not freeze. **Solo-test a real 2v2 through Single Player.** ⚠️
      **Narrowed by 4.6, 2026-07-28** — a **solo** networked session (hosting,
      nobody else has joined) now gets a real pause and a correct (not
      "(missing)") debug readout; see 4.6. The "real 2v2" case above is
      unchanged. ⚠️ **Narrowed by 5.5, 2026-07-28** — Single Player now drives its
      other three units with real AI (`Checklist.md` 5.5), and the debug
      switcher's interaction with that is its own item; see 5.5 for the current
      behaviour.
- [x] **4.2 · Movement interpolation for remote characters.** 🤖 Sonnet, high —
      **verified by two real `--host`/`--join=127.0.0.1` instances, 600+ frames, no
      output**
      Remote units used to visibly snap — the replicated `position`/`rotation`
      (`CharacterBase.tscn`'s `MultiplayerSynchronizer`) were written straight onto
      the body every time an update landed. Per `Agent_Prompts.md`'s Netcode
      brief: the body itself must keep snapping (collision, the Hitbox offset and
      every directional ability read it directly), so this smooths the **`Visual`
      node only** — `character_visual.gd` now lags a world-space copy of the
      body's position/yaw behind at `REMOTE_SMOOTH_RATE` and renders the mesh from
      that, converting the gap into the body's local frame every frame.
      Deliberately skipped (zero overhead, not just zero visible effect) for: the
      locally-driven character (client-authoritative, already smooth), anything
      not networked (Single Player), and a CARRIED or FLYING slipper
      (`carriable.gd` already recomputes both identically on every peer at zero
      bandwidth — smoothing an already-agreed transform would make it visibly lag
      the hand or the arc). **Teleports snap, not glide**, per the brief's own
      requirement: `character_base.gd::respawn()` (KillPlane) and
      `main.gd::_place_at_spawn()` (every round reset, and the initial local-test
      placement) both call the new `CharacterBase.snap_visual_interpolation()`
      immediately after repositioning.
      **Verified by running**, not by a human watching it glide: two real Godot
      instances (`--host` / `--join=127.0.0.1`, not `--headless` — a rendering
      device is required for `_process()` to run at all), 600+ frames each,
      produced no output. Confirmed by reading the code, not felt: whether
      `REMOTE_SMOOTH_RATE` (18.0) is the right *feel* is unverified and cheap to
      retune later, same tuning-window caveat as the rest of this phase.
      **⚠️ Two pre-existing bugs found and fixed while building the two-instance
      test rig this item needed** (see `Handoff.md`'s session log and its own new
      `B-` entries): a stale, non-freed-but-tree-detached character reference
      could crash `you_card.gd::get_local_character()`'s caller
      (`offscreen_indicators.update()`) the instant a peer joined or disconnected,
      and `offscreen_indicators.gd::_update_one()` itself crashed reading
      `global_position` off a target mid-`queue_free()`. Neither is new
      networking work; both were unreachable without an actual live multi-peer
      session, which is exactly what this item required building.
- [x] **4.3 · Rejoin identity (B-65).** 🤖 Sonnet, high — **verified live: two
      sequential `--join=127.0.0.1` processes presenting the same identity token,
      host reassigns the same team/role slot to the second one under a brand-new
      peer id**
      A rejoining player used to come back as a different team and role, because
      identity was the ENet peer id and a reconnect assigns a new one.
      `NetworkManager.local_player_token` is now a random 128-bit token minted
      once per running instance (see its own doc for why NOT reloaded from the
      `user://` copy it also writes — two local test instances sharing one
      `user://`, exactly how this project's own two-instance test works, would
      otherwise read back the identical token and collide on the same join
      index) and presented to the host via `_rpc_identify` on every connect.
      `main.gd`'s `_peer_join_index` (peer_id -> slot) is now `_token_join_index`
      (token -> slot): a reconnect presents the same token under a new peer id
      and maps straight back to its original team/role.
      **The harder half of this item, not in the original brief's own framing:**
      a rejoining peer had nowhere to go. Host/Join both gate behind
      `Lobby.tscn`'s ready-up screen, and the host has already left it for
      `Main.tscn` by the time anyone could realistically disconnect and rejoin —
      the rejoining peer's own `Lobby.tscn` would connect fine and then wait
      forever for a Start press the host can never send again.
      `NetworkManager.match_in_progress` (host-only, set true by
      `main.gd::_start_hosting()`) plus a new `_rpc_route_to_running_match` RPC
      (sent to a peer that identifies after the match has already started) now
      redirects that peer straight into `Main.tscn`; a new
      `_rpc_client_ready_for_spawn` ping (sent once that peer's own
      `Main.tscn`/`MultiplayerSpawner` actually exists) tells the host it is safe
      to replicate a spawn, closing the race where the host could otherwise spawn
      a peer before its own receiving scene was ready.
      **Verified live**, not just reasoned about: host + one join process
      (distinct tokens, sequential slots 0/1, no errors, 600+ frames each);
      separately, two *sequential* join processes forced to present the identical
      token (simulating the same human reconnecting under a new peer id) — the
      host reused the exact same join index (`1`) for both, under two different
      peer ids, with no errors either side. **Not verified:** a literal
      mid-process ENet drop-and-manual-rejoin from the SAME running client (the
      test above simulates the identity/redirect mechanism correctly but kills
      and restarts the client process rather than reconnecting in place) — that
      is the real-hardware wifi-blip case 6.1 will exercise. `Handoff.md`'s B-65
      entry is closed; see it for the full account.
- [ ] **4.4 · Balance pass — Guard/Dash, cooldowns, ranges, both game modes.** 🤖 Sonnet, medium ⛔ 0.4
      Never done. Write the numbers down. **Balance both Option A and Option B
      to shippable quality** — per 1.5, neither is deprioritised.
- [x] **4.4a · `throw_bakya`'s maximum range was 4.81 units — less than half of every other
      profile.** 🔧 Build — **fixed 2026-07-28 as part of 2.5, verified by the same maths
      `Art_Direction.md` §9 uses**
      `gravity_scale 1.6` with `arc_angle_deg 8.0` was heavy *and* flat, so it dropped out of the
      air almost immediately — Bakya Bash could not reach any throwing line the other three could.
      Retuned to `arc_angle_deg 12.0` / `gravity_scale 1.0` (launch_speed unchanged at 14.0): new
      max range **7.23**, needing ~87% charge for the 6.0 throwing line. Still the shortest-range
      profile of the four, now by identity (heavy, close-range) rather than by being broken. Not
      yet felt in play — nothing has selected it since B-76 (`PROP_ABILITY` is `quick_stand.tres`
      for every Prop); that unlock is 3.3's job, and whether 87% charge feels right is 4.4's.
      **Superseded 2026-07-29 by the game-feel pass (4.4d below), which re-tuned every profile.**
      Bakya is now `launch_speed 19.0` / `arc 12.0` / `gravity_scale 1.35` — max range **8.05**,
      ~86% charge for the 6.0 line, i.e. deliberately the same reachability this entry settled on.
      The first attempt at that pass had it at 6.77 / ~94%, which would have quietly re-broken
      exactly what this entry fixed; caught by re-deriving the range instead of trusting the edit.
- [x] **4.4b · Option A's ring-out win condition was missing entirely.** 🔧 Build — **fixed
      2026-07-28, verified by parse + a 400-frame soak**
      `Dev_Plan.md` §3: "Cans win by the timer running out, OR by knocking Slippers out of bounds a
      set number of times." Only the timer half existed —
      `KillPlane.character_respawned` fired an "OUT OF BOUNDS" toast and nothing else, so a Can-side
      round win could only ever come from the 90s clock. Found auditing the round-win system against
      the GDD. `RoundManager.register_ring_out(character)` is the new entry point (host-gated like
      `report_round_win()`, filtered to this round's Tsinelas specifically, Option A only —
      `RING_OUT_LIMIT = 3`), called from `main.gd`'s existing KillPlane handler. **Not verified by
      play:** whether 3 is the right number. Same tuning-window caveat as everything else in this
      phase.
- [x] **4.4c · B-126 · A THROWN SLIPPER RE-RESOLVED THE SAME HIT EVERY PHYSICS FRAME.** 🔧 Build —
      **fixed 2026-07-29, measured before and after with `tools/phys_probe.gd`**
      Reported as "the hit animation triggers repeatedly and severely lags the game". Measured, 12
      throws per row:

      | aimed at | worst single throw, before | after |
      |---|---|---|
      | `target=can`   | 1 resolution   | 1 |
      | `target=taya`  | **35** resolutions (344 total) | 1 (11 total) |
      | `target=graze` | **59** resolutions | 1 |

      Every duplicate re-ran a full state transition, a VFX flash, a **global `Engine.time_scale`
      hitstop** (4.5) and a positional sound — that is the lag, and the hitstop dip is why it hurt
      the whole frame and not just the struck unit. Two independent causes, which is why the fix is
      not where you would first look:
      **(a)** `carriable.gd::_step_flying()` calls `sweep_hitbox()` every physics frame, and
      `sweep_overlaps()` re-runs resolution for everything already inside — a hurtbox overlapped for
      35 frames resolved 35 times. **(b)** a thrown slipper carries **two** live hitboxes at once
      (`CharacterBase.tscn`'s own melee one, live for the whole flight per `is_hitbox_active()`,
      plus the per-profile pulse one from `_spawn_flight_hitbox()`), so even one clean frame
      resolved **twice**.
      Fixed with a hit memory on `CharacterBase` (`register_hit_once()` / `clear_hit_memory()`),
      **not** inside `hitbox.gd` — per-Hitbox memory could never have caught (b), since the two
      areas are different nodes. `carriable.gd` clears it on every carry transition (thrown, caught,
      come to rest, round reset), which is what makes the rule "once per throw" rather than
      "once, ever". Connection rate is unchanged (11/12 before and after), so detection is intact.
      ⚠️ **Aiming at the can is why this survived so long**: a square hit on a body ends the flight
      via `move_and_collide` the same frame, which hides the window entirely. The bug only shows
      against a Person, and worst on a graze that never touches a body at all.
- [x] **4.4d · Throw weight and the faceslop.** 🔧 Build — **2026-07-29, numbers measured with
      `tools/phys_probe.gd`; how it FEELS is unverified and is still 4.4's job**
      "The current throw feels weak and floaty." All four profiles re-tuned faster *and* heavier
      (higher `launch_speed`, higher `gravity_scale`) so the arc is decisive rather than lazy;
      ranges re-derived to guarantee every profile still reaches the 6.0 throwing line (see 4.4a).
      `ThrowProfile` gains `mass`, `knockback_scale`, `knockback_lift`, `faceslop_multiplier` and
      `tumble_speed_deg`.
      ⚠️ **`mass` is not a RigidBody mass and there is no RigidBody here** — a slipper is a
      `CharacterBody3D` integrated by hand in `_step_flying()`, so Godot never uses a mass and
      setting one would do nothing. It is the knockback coefficient, and it is what differentiates
      the profiles (`knockback_scale` is deliberately the same 0.35 on all four).
      **Knockback path:** `hitbox.gd` computes the impulse from the striker's own motion →
      `hurtbox.gd::absorb_knockback()` decides how much this particular body takes (same ownership
      rule `impact_sfx()` already established: the struck object owns the answer) →
      `CharacterBase.apply_knockback()` writes `velocity`. Measured on a struck Person, against a
      control of its own pre-hit speed: **+6.8 m/s** horizontal from the lightest profile, up to a
      capped 16.0 for a downing hit from the heaviest.
      ⚠️ **There is no ragdoll and this is not one.** DOWNED is a state on the existing machine;
      "physically knocked backward" means the impulse goes into `velocity` and the ordinary
      `move_and_slide`/gravity path carries it. A second physics path would have to re-implement
      confinement, the floor check and the round freeze.
      Knockback is clamped (`MAX_KNOCKBACK_SPEED` 16.0, `MAX_KNOCKBACK_LIFT` 7.0) — anchored just
      above `DASH_SPEED` 14.0 and `JUMP_VELOCITY` 5.8, because the impulse is the product of four
      independently-tunable fields and it is easy to pick four innocuous numbers that launch a
      player out of the arena.
      The in-flight tumble now advances **two** axes (`spin_speed_deg` about the slipper's own long
      axis, `tumble_speed_deg` end-over-end); one axis alone was what read as "flying perfectly
      flat" however fast it was cranked. ⚠️ It writes `rotation.x`/`.z` only, never `basis` or `.y`
      — `_process_remote_smoothing()` writes `.y` *after* it in `_process()` and would silently
      undo a full-basis write.
- [x] **4.4e · B-127 · THE THROW'S ARC TILT WAS INVERTED — every throw left the hand BELOW the
      crosshair.** 🔧 Build — **fixed 2026-07-29, measured against the expression as it stood**
      Reported twice, both times as a feel problem rather than a bug: "barely has power even during
      full windup", then "the height when you throw it is still too low".
      `carriable.gd::host_throw()` has always been documented as "tilt the aim **upward** by the
      profile's arc" and did the exact opposite. For a forward aim of `(0,0,-1)`,
      `horizontal.cross(UP)` is `(+1,0,0)`, and rotating about `+X` by a **negative** angle drives
      `y` negative. Measured:

      | crosshair pitch | launch pitch, before |
      |---|---|
      | level | **-14°** |
      | +20° | +6° |
      | -20° | -34° |

      So every throw left the hand a full `arc_angle_deg` under where the player was pointing — 28°
      low for Bagsak, whose entire identity is the lob. It went unnoticed because the arc error and
      the gravity drop compound in the same direction, so it never read as "aiming is wrong", only
      as "the throw is weak".
      Sign corrected, **and `arc_angle_deg` is now 0.0 on all four profiles** per the request that
      the launch be aligned with the crosshair — any non-zero arc, in either direction, is by
      definition a hidden offset from it. The field is kept and now finally works in the direction
      it claims, so a lob can be dialled back in deliberately.
      ⚠️ **Consequence, stated because it changes how the game is aimed:** the player now owns the
      arc. From the 6.0 throwing line at eye height 1.55, a level crosshair lands at **7.00 m**;
      hitting the can wants roughly **-3.7°**, i.e. still visibly *above* the can itself, since
      aiming straight at it (-12.9°) lands at 3.9 m. Bagsak no longer lobs on its own.
      `tools/phys_probe.gd -- target=taya` went from 11/12 to **12/12** connections on the fix.
- [x] **4.4f · B-128 · CHARACTERS COULD BE LAUNCHED ACROSS THE ARENA BETWEEN ROUNDS.** 🔧 Build —
      **fixed 2026-07-29, A/B'd with the new `tools/round_probe.gd`**
      Reported as "whenever a round ends, players get launched to multiple directions".
      The between-rounds branch in `character_base.gd::_physics_process` froze *input* but not
      *motion*: it decayed velocity by `FRICTION` and still called `_move_and_confine()`, so any
      velocity already present — or written **during** the gap — kept being integrated.
      ⚠️ **The reset itself was never the problem, and that is why this is easy to look for in the
      wrong place.** Driving transitions with the AI disabled and no impulse reports a clean pass.
      What breaks it is an impulse *arriving* in the gap, and there are two routine sources: the
      round-winning **tag** applies knockback in the same frame it ends the round (hitbox.gd
      resolves the hit before calling `report_round_win`), and networked, `_apply_hit_result` is an
      `rpc_id` to the struck peer that can land frames after `_reset_world()` has already teleported
      everyone home.
      Fixed at both ends: `apply_knockback()` refuses to write velocity while the round is inactive,
      and the gap is now a **hard freeze** — zero horizontal velocity and, once grounded, no
      `move_and_slide()` at all, so there is no depenetration impulse and nothing for a stray write
      to act on. Still falls if airborne, preserving the original "nobody floats" intent.
      Measured, same probe, 6 transitions with a `(9,4,4)` impulse fired into each gap:
      **before 10.63 m/s and 5.20 m of drift -> after 0.00 and 0.00.**
- [x] **4.4g · B-129 · THE THROW STILL DID NOT GO WHERE THE CROSSHAIR POINTED.** 🔧 Build —
      **fixed 2026-07-29, A/B'd with the new `tools/aim_probe.gd`**
      The third report of the same symptom ("the height is still too low"), after 4.4e had already
      corrected the inverted arc and zeroed it. ⚠️ **Aligning the launch DIRECTION with the crosshair
      is not the same thing as the throw going where you point, and that is the whole lesson here.**
      Two independent reasons, both measured from the 6.0 throwing line:
      * the slipper leaves the **hand at y 0.89** while the camera eye is at **y 1.35**, so a
        launch parallel to the look direction starts 0.46 m below the line the player is sighting
        along and only diverges from there;
      * gravity then bends it away from that line by an amount **that grows with range**, so the
        crosshair and the landing point agree at exactly ONE distance. Measured: a target 7.04 m out
        landed **1.70 m short**, one 3.38 m out landed **1.47 m long**.
      Fixed by aiming at a **point** instead of along a bearing. `carrier.gd::_aim_point()`
      raycasts from the camera to find what the crosshair is actually on, sends that point (a
      networked signature change: `host_throw` and `_rpc_request_throw` take a target point now, not
      a direction), and `carriable.gd::_solve_arc()` solves the standard ballistic launch angle that
      passes through it — taking the **flat root**, so the throw stays direct and the solved angle
      stays near where the player is already pointing. Out of range falls back to the plain bearing
      and visibly drops short, deliberately *not* to a 45° max-range lob: aiming at a distant wall
      firing a mortar straight up would be a far stranger thing to happen.
      ⚠️ **The metric is closest approach to the aim point, not where it lands** — `MAX_BOUNCES`
      lets a slipper skip once after first contact, so a perfectly aimed throw can rest a metre or
      two past the target. A/B, same probe:

      | camera pitch | aim point range | closest approach, before | after |
      |---|---|---|---|
      | +0° | 23.45 m | **12.25 m** | 0.18 m |
      | −10° | 7.04 m | 0.77 m | 0.19 m |
      | −20° | 3.38 m | 3.90 m | 0.31 m |
      | −30° | 2.12 m | 2.67 m | 0.30 m |
      | +10° | 23.45 m | 5.12 m | 0.20 m |

      Every pitch missed before; every pitch now passes within the slipper's own `hit_radius`.
      Knock-on: `phys_probe -- target=can` went from **2/12 to 9/12** connections against a Can that
      actively dodges, and `target=taya` to 12/12.
      Because the solve uses the profile's own effective gravity, a heavy Bakya picks a steeper
      angle than a floaty Havaianas for the same target — the profiles differentiate the *flight*
      without fighting the *aim*. `arc_angle_deg` survives as a deliberate offset on top of the
      solve, 0.0 everywhere, for a profile that wants to lob above the crosshair on purpose.
- [x] **4.5 · Hitstop.** 🤖 Sonnet, medium
      The one piece of the Q-8 hit-feedback set that never landed. Cheap, and it
      is what makes a landed hit feel like contact rather than a colour change.
      **Done, verified by running.** `character_base.gd::_flash_hit()` now dips `Engine.time_scale`
      to 0.05 for 60ms real time (a `SceneTreeTimer` with `ignore_time_scale` restores it, so the
      dip's own length doesn't get stretched by the dip). Global, not per-node, and broadcast the
      same way the existing flash/particles/shake already are — every peer feels the same beat on
      the same trigger. A headless probe forced a real bump between two opposing units and
      confirmed `time_scale` dropped to 0.05 immediately and returned to exactly 1.0 shortly after.
      Not verified: how 60ms/0.05 actually feels — a tuning number like every other one in the
      T-block, cheap to adjust after 0.4.
- [x] **4.6 · Solo-host quality of life — pause and the debug switcher work with exactly one
      human peer.** 🔧 Build — **`NetworkManager` semantics change, its own commit, verified by two
      real multi-instance sessions with no output**
      The first playtest was run by HOSTING, not Single Player, and two things silently no-op'd in a
      networked match on purpose: `get_tree().paused` (Q-3/B-64 — a client pausing its own tree
      stops sending movement while the host keeps simulating it, and the host can't stop an
      authoritative timer for everyone over one player's Esc) and the whole debug player switcher
      (each peer owns exactly one character; reassigning `player_id` grants no control). Both
      restrictions are real for an actual 2+ peer match and pointless when there is nobody else in
      the session to protect — which is exactly what testing alone by hosting is.
      New `NetworkManager.is_solo_session()`: `is_networked() and connected_peer_ids.size() <= 1`.
      `main.gd::_on_pause_toggle_requested()` now takes the real-freeze branch (same code path
      Single Player already used) whenever `not is_networked() or is_solo_session()`, instead of
      only when `not is_networked()`.
      `debug_player_switcher.gd::_is_active()` now also returns true for a solo networked session —
      but **not** by making unit-switching work: a solo Hosted session only ever spawns ONE real
      character (`main.gd::_spawn_player` runs once per actually-connected peer, and there is no
      bot/placeholder system to fill the other three roles — see 4.7), so there is nothing to Tab
      to regardless of this gate. What was actually broken and is now fixed: the on-screen
      `DebugBar` used to show `TeamAPerson (missing) / TeamAProp (missing)` the instant you hosted
      alone, because it was still looking for the four LOCAL-TEST node names
      (`_clear_local_test_characters()` had already freed them) instead of the real networked
      spawn. New `_solo_networked_unit()` walks the actual `Players` node
      (`MultiplayerSpawner.spawn_path`) for the character whose authority is this machine's own
      peer, and the readout now correctly describes it. `player_id`/camera reassignment is
      deliberately left untouched for this unit — `main.gd`'s spawn already assigned the right
      `player_id` and `camera_rig.gd`'s own `_ready()` already activates the right rig from
      `is_multiplayer_authority()`; re-driving either here would be redundant at best.
      **Verified by running:** two real `--host`/`--join=127.0.0.1` sessions (one while solo, one
      once a second peer joined), 600+ frames each, no output — the `DebugBar`/switcher code paths
      run every frame regardless of whether anyone is looking at them, so a clean multi-hundred-frame
      run is real evidence they don't error, in both the solo and non-solo states. **Not verified:**
      a human actually pressing Esc and confirming the overlay visibly freezes, or reading the
      `DebugBar` text off a running window — this project's norm is that an unverified interactive
      claim is not written up as felt, only as run.
- [~] **4.7 · Peer-drop-mid-round — what actually happens, recorded rather than assumed.** 🔧 Build
      — **verified live: a real ENet peer killed mid-round, both host and a third surviving peer
      observed**
      No demonstrated disconnect handling existed and there is no bot to cover an abandoned unit.
      Pulled the cable for real rather than reading the code and guessing: a 4-peer LAN session
      (host + 3 `--join=127.0.0.1`), one join process hard-killed (`kill -9`, no graceful
      disconnect packet) mid-round.
      **What happens, measured:**
      1. ENet detects the drop via its own peer timeout, **not instantly** — roughly 10-11 seconds
         after the process died in this environment (`kill -9` sends no FIN; there is nothing
         faster to detect here without lowering ENet's own timeout, which was not attempted).
      2. `main.gd::_on_player_disconnected` fires on **every remaining peer**, not just the host —
         each one frees its own local copy of the departed character and, host-side only, shows "A
         player left the match" and re-registers tracked Cans.
      3. **The disconnected unit does not become a frozen obstacle. It is deleted outright** —
         `queue_free()`'d and erased from every peer's own tracking dictionaries. Nothing stands in
         for it; there is no AI, no ragdoll left lying around, nothing a remaining player can walk
         up to and interact with.
      4. **If the disconnected peer was the tracked Can:** `RoundManager._tracked_cans` becomes
         EMPTY. `_on_tracked_can_state_changed`/`_on_tracked_can_dents_changed` both early-return on
         an empty list, so tag-to-win, the 5-fall cap, and Option A's dent count all go **completely
         inert** for the remainder of that round — there is no can left to tag, cap, or dent. The
         round can only end one way from that point on: the 90-second timer, which **always resolves
         to a Cans-side win** (`RoundManager._on_time_up()` → `report_round_win(true)` — "Cans win on
         timer expiry," true under both Option A and Option B) **regardless of whether a Can is even
         still present.** A Can-side disconnect mid-round silently guarantees the round for the
         defending team once the clock runs out, with no way for the offense to contest it.
      5. **If the disconnected peer was the attacking Person or the Tsinelas Prop** (the thrown
         object itself — the SAME CharacterBase the attacking side's slipper actually is), offense
         loses its only means of winning that round too: nobody left to throw, or — if the Tsinelas
         player specifically drops — the slipper object itself is deleted from the match entirely,
         mid-flight or mid-carry, whatever it was doing. Same resolution: timer expires, Cans win.
      6. **If the disconnected peer was the defending Taya**, tag-to-win becomes unreachable for
         that team (nobody left to land the tag), but the Can itself is still tracked — Option A's
         dents and Option B's fall-cap/auto-seal still apply from throws the offense lands, so this
         is the one drop that does NOT automatically hand the round to one side.
      7. **No crash, in any of the above** — but building this test surfaced and fixed two real,
         previously-unreachable UI crashes along the way (`you_card.gd`, `offscreen_indicators.gd` —
         see 4.2's own entry and `Handoff.md`'s new `B-` numbers for both).
      **Not done, explicitly out of scope for this pass:** any actual FIX for the above (a bot
      taking over an abandoned role, a grace window before the round auto-resolves, ENet timeout
      tuning). This item is the truth on record, not a mitigation — `[~]` rather than `[x]` because
      the *fix* the human asked for ("what happens") is answered, but the underlying UX gap is not
      closed and nobody should read this box as saying it is. ⚠️ **Narrowed by 4.8, below** — a
      disconnected unit is no longer deleted (a later networking-lane pass made it a frozen
      placeholder instead), and 4.8 gives that placeholder, and every unfilled team/role slot,
      real AI instead of standing frozen.
- [x] **4.8 · Networked AI takeover — an unfilled slot or a disconnected player's character gets a
      real bot instead of standing frozen forever.** 🤖 Sonnet, high — **verified live: real
      `--host`/`--join=127.0.0.1` processes, an ENet peer killed mid-session and both a brand-new
      and a same-identity-token reconnect exercised**
      A prior networking-lane pass (see `Handoff.md`'s session log) turned a disconnected player's
      character and every never-filled team/role slot into a **frozen placeholder** — nobody's
      `is_multiplayer_authority()` is ever true for it, so `character_base.gd`'s own authority gate
      just stops simulating it — explicitly stationary-only per that session's own brief, with the
      AI half handed off as its own lane (see that lane's own handoff doc). This item is that
      hand-off: every such placeholder is now `add_child()`'d an `AIController` (Checklist 5.5's
      class, unmodified) instead of sitting frozen, giving it the same "moves with intent" behaviour
      Single Player's unpiloted units already have.
      **The real trap, flagged by the prior lane's own handoff before any of this was wired in:**
      `AIController` drives its character by calling `Input.action_press()`/`action_release()` on
      that character's own `_pN`-suffixed actions — global process state, not per-node. Networked
      placeholders were being assigned `player_id` 1 or 2, the exact values every real human's own
      character uses, so an AI-driven placeholder would fight the HOST's real keyboard input over
      the same global action state the instant the host was also a real player. **Fixed** by giving
      every AI-driven character `player_id` 3 or 4 instead (`main.gd::_build_spawn_data`) — `p3`/`p4`
      are registered in `project.godot` but deliberately left unbound to any real key (see
      `CharacterBase.player_id`'s own doc), so no real keystroke can ever land on them.
      **Authority:** an AI-driven character's multiplayer authority is the **host's own peer_id**
      (not the negative sentinel used for bookkeeping) — the host already runs round logic, and
      someone's machine has to actually execute the AI's presses. `main.gd::_build_networked_character`
      only `add_child()`s the driving `AIController` on the host's own process; every other peer's
      local copy of that same character has `ai_controller == null` and simply never calls
      `decide()`, since only the host's presses land anywhere once `_physics_process`'s own
      authority gate is reached.
      **Hand-off, both directions**, via two RPCs run identically on every peer (`call_local`, same
      pattern the existing `_rpc_reclaim_character` already used for a reconnect):
      - **Human → AI** (`_rpc_convert_to_ai`, called from `_on_player_disconnected`): re-keys the
        character's bookkeeping to a fresh negative sentinel (same convention
        `_fill_empty_slots_with_placeholders` already used), sets authority to the host, and bumps
        `player_id` into the 3/4 range.
      - **AI → human** (`_rpc_reclaim_character`, extended): detaches and frees the `ai_controller`
        so the reclaiming human doesn't fight it, restores `player_id` to the human 1/2 scheme, and
        re-keys bookkeeping to the new real `peer_id` — unchanged from before for the "was already
        frozen, no AI" case, since detaching a null `ai_controller` is a no-op.
      A `get_local_character()` edge case (host-only): an AI-driven character's authority is *also*
      the host's own peer_id, so `is_multiplayer_authority()` alone can no longer tell "the host's
      own played character" from "an AI-driven one the host's machine happens to simulate" — fixed
      by excluding any character with a non-null `ai_controller`.
      **Verified live**, not just reasoned about: real Godot processes (not headless — see the smoke
      gate's own note on why), `--host` alone confirmed all three unfilled slots correctly got
      `player_id` 3/4 + host authority + a driving `AIController`, with the AI actually pressing
      input and running physics (the Taya patrols, the Attacker retrieves and charges its throw).
      A brand-new peer joining reclaimed a never-filled AI slot correctly (`player_id` back to 2,
      authority to its own real peer_id, `ai_controller` detached). A joined peer was `kill -9`'d;
      after ENet's own ~10-11s disconnect timeout (same figure 4.7 measured), the host correctly
      converted that exact character to AI (`player_id` 4, host authority). A second process
      presenting the **same** identity token (simulating the same human reconnecting, via a
      temporary `--force-token=` override reverted before committing — same technique the
      networking lane's own handoff describes) correctly reclaimed that exact character back to
      human control. All four transitions logged and confirmed via temporary print instrumentation,
      reverted before committing. Full six-command smoke gate run clean before and after.
      **Not done / left alone, on purpose:** an existing `ai_controller.gd`/`carrier.gd` interaction
      where the Attacker AI's charge-throw sometimes resets before completing (confirmed to
      reproduce identically in Single Player under the same map spawn distances, so it predates this
      item and is not a networking regression) — a Single Player AI tuning question, not this item's
      scope. Real multi-device/Hamachi testing of AI takeover specifically is still unverified, same
      standing caveat as every other networking item.
      **Follow-up bug, found and fixed the same day by human playtest:** giving an AI-driven
      character the host's own multiplayer authority (above) meant every OTHER place in the codebase
      that used `is_multiplayer_authority()` to mean "this is MY OWN played character" broke on the
      host's machine specifically, the instant the host was also a real player — `camera_rig.gd`'s
      own rig-activation check is the one that actually surfaced, live: **every** AI-driven
      character's `CameraRig` also saw itself as "mine" and activated, so whichever rig activated
      LAST silently became the host's actual view (reported as "I'm not controlling the POV of the
      character I have — it's an FPP of another character controlled by AI"), and each of those
      AI-driven rigs also ran its own FPP self-hide, hiding that character's head/body as if the
      host were looking through ITS eyes (reported as "other characters have an FPP model with a
      TPP view"). Same root cause, same fix as `get_local_character()` above — exclude
      `ai_controller != null` — applied at the one place that actually renders
      (`camera_rig.gd::_ready()`), plus two more `is_multiplayer_authority()`-as-"mine" call sites
      the same bug class was latent in: `character_base.gd::_flash_hit()`'s camera-shake gate and
      `debug_player_switcher.gd::_solo_networked_unit()`'s solo-host readout. Verified live: a
      temporary print in `camera_rig.gd` confirmed exactly one rig (the host's own real character,
      no `ai_controller`) reports `is_mine = true` on a solo host with three AI-driven slots, where
      before the fix every one of the four reported `true`.
      **Second follow-up, user request — a solo host couldn't even reach any of the above.**
      `scripts/ui/lobby.gd::_refresh_start_button()` hard-required **two or more** connected peers
      before the host's Start button would enable at all — predates AI takeover, back when an
      unfilled slot really was just an empty seat. Fixed: the only requirement now is that every
      peer who HAS joined (host included, always at least themselves) is readied up; a solo host is
      a complete, startable match on its own, joinable by anyone else on the LAN afterward. Verified
      live via a temporary test hook driving `Lobby.tscn` directly (`--test-solo-host`, reverted
      before committing): `start_button.disabled` was `true` before Ready, `false` after, and
      pressing Start actually transitioned to `Main.tscn` with 4 characters spawned, 3 of them
      AI-driven.

---

## Phase 5 — Strip, harden, and prove it runs outside the editor

- [x] **5.1 · Install Godot export templates.** 🤖 Sonnet, medium — **done 2026-07-29**
      `export_presets.cfg` and `tools/export.md` both exist and are correct.
      Installed `4.7.1.stable` export templates via the `.tpz` from the Godot GitHub
      releases page to `%APPDATA%\Godot\export_templates\4.7.1.stable\` on this Windows
      machine, verified `windows_release_x86_64.exe` present in that folder. **Templates
      are per-machine** — this unblocks exporting only on this machine; `tools/export.md`
      now documents the macOS/Linux paths too so the rest of the team can do the same.
- [x] **5.2 · Produce a release build and confirm it launches to the menu.** 🤖 Sonnet, medium ⛔ 5.1
      **Done 2026-07-29, Windows 10 (10.0.19045).** `godot --headless --export-release
      "Windows Desktop" build/TumbangPreso.exe` completed with no errors, emitting both
      `TumbangPreso.exe` and `TumbangPreso.pck` (no `.console.exe` — `export_console_wrapper=1`
      only adds it to debug exports). Personally launched the `.exe` and walked the front
      end live: main menu ("TÜMP — 2v2 ARENA BRAWLER — CANS VS TSINELAS") → PLAY → SINGLE
      PLAYER → picked map/mode/seat → START MATCH → a real round with an AI-controlled
      teammate (A2 · DEF) → ESC opened the pause menu (Resume/Settings/Return to Menu) →
      Return to Menu worked cleanly → PLAY → MULTIPLAYER → HOST GAME (LAN) opened a lobby
      showing `LOBBY – HOST 192.168.1.7`. No SmartScreen prompt appeared (build has no
      internet Mark-of-the-Web, since it was built locally rather than downloaded) and no
      Windows Firewall prompt appeared when hosting on this run — worth re-checking on a
      machine where this exe truly arrives over the network, since SmartScreen in
      particular is a per-provenance behaviour, not a per-binary one. See F-3 in
      `Handoff.md` for the acceptance-test writeup this closes out.
- [x] **5.3 · ⚠️ REDIRECTED 2026-07-28 — no longer "strip Local Match," see 5.5.** 🧑 human decision,
      recorded here so nobody reads the old text below and starts deleting things
      This item used to say "strip Local Match and the debug switcher, keep the harness only as a
      network-free demo fallback." **User decision, same day: Local Match is being promoted to a
      real, permanent SINGLE PLAYER mode that ships in the final build — not stripped, not just a
      fallback.** The three units the human isn't personally controlling get real AI instead of
      sitting unbound. See **5.5** for the actual scope and the new agent brief in
      `Agent_Prompts.md`. Original text, kept for history only, superseded in full:
      *"Strip Local Match and the debug switcher. RESOLVED CONFLICT — do NOT simply delete the
      harness. Art_Direction.md Part 5 §3 makes the local 4-unit harness the demo failure-ladder's
      rung 3 — the only fallback that needs no network. Keep the harness, gate it behind a launch
      argument, and strip only the on-screen debug overlay."* That framing (harness = fallback,
      not a real mode) is what 5.5 replaces.
      **Reconciled by 5.5, 2026-07-28:** `Art_Direction.md` Part 5 §3's failure-ladder table,
      `Dev_Plan.md`'s harness/removal-contract sections, `Handoff.md`'s frozen §1, and
      `README.md`'s contradiction register all corrected to the new framing in the same commit
      that built the AI — see 5.5's own entry for the full list.
- [x] **5.4 · Decide the `.import` UID churn (B-71) — and the EOL churn (B-84).** 🤖 Sonnet, medium
      Either accept it or stop tracking `.import` UIDs. Low stakes, but it makes
      every "regenerate and check `git status`" acceptance test unreliable, and
      those are load-bearing for the whole M-block.
      **B-84, found 2026-07-28, is the second half of the same problem and is cheaper to fix.**
      `.gitattributes` marks `*.obj`/`*.mtl` as `text` while `core.autocrlf = true`, so git checks
      them out CRLF and `FileAccess.store_line()` rewrites them LF — the files show as modified
      after every generator run with **zero** lines changed (measured: `git diff --numstat` empty
      both with and without `--ignore-cr-at-eol`). **The generator is deterministic; the test is
      broken.** Fix: `*.obj text eol=lf`, `*.mtl text eol=lf`, then `git add --renormalize .`.
      **Do this before 2.1b**, which adds ~26 more generated meshes to an acceptance test that
      currently cries wolf on every run.
      **Done.** B-84 fixed (`eol=lf` pinned, renormalized, determinism test run twice clean).
      B-71 decided: accept the churn, formalized as a standing pre-commit check rather than a
      two-lane-period workaround. See `Handoff.md` B-71/B-84.
- [x] **5.5 · Rename Local Match to Single Player; give the AI-controlled units real AI.** 🤖 Sonnet,
      high — **built 2026-07-28, verified live (real Godot runs, not headless)**
      User decision: Local Match stops being a dev-only testing harness / network-outage fallback
      and becomes a real, permanent SINGLE PLAYER mode in the final submission.

      **Rename.** `MainMenu.tscn`'s `LocalButton` text → "SINGLE PLAYER" (was "LOCAL MATCH (SINGLE
      PC)"); every player-visible/standing-description "Local Match" across `docs/` and `scripts/`
      comments renamed to "Single Player," with dated historical entries (specific playtest
      sessions, verbatim quotes, commit-message subjects) deliberately left alone — renaming those
      would misrepresent what a past test was actually run against. Internal identifiers
      (`GameLaunch.pending_action == "local"`, `_on_local_pressed`, node names) kept as-is, per the
      brief's own instruction — this was a UI/doc rename, not a launch-flow restructure.

      **AI architecture — the actual decision, stated up front as asked.** A new
      `scripts/systems/ai_controller.gd` (`class_name AIController`) is a plain `Node`,
      `add_child()`'d onto each AI-driven `CharacterBase` at runtime by
      `main.gd::_start_local_test()` (never baked into `CharacterBase.tscn`, which is shared with
      the networked spawn path and has no use for this). It writes into the SAME input surface a
      human would — `Input.action_press()`/`action_release()` on the character's own
      `action_name()`-suffixed actions — rather than a parallel "intent" struct. `character_base.gd`
      gets exactly one hook, the first line of `_physics_process()`
      (`if ai_controller != null: ai_controller.decide(delta)`), and nothing else changes: movement,
      abilities, `carrier.gd`, confinement, the Staggered/Downed/Sealed state machine and
      round-active gating all read Input exactly as before, unaware whether a press came from
      hardware or from here. `_physics_process()` was never forked.
      **Two real timing bugs found and fixed while getting a throw to actually complete, worth
      recording since they are not obvious and apply to any future scripted-input work in this
      codebase:** `Input.is_action_just_pressed()`/`is_action_just_released()` lag ONE physics frame
      behind the `action_press()`/`action_release()` call that causes them — confirmed with a direct
      print inside `carrier.gd::_step_throw()`, not inferred. A same-frame (or same-decide-call)
      release-then-repress silently drops the edge before any reader ever witnesses it, which is
      exactly what made the AI Attacker charge forever and never release. Fixed with
      `AIController.RELEASE_SETTLE_FRAMES` (6 physics frames): both the release side (a cooldown
      before re-entering "start charging") and the tap side (`_tap()`'s hold-then-release window for
      bump/grab) now give the edge time to be seen before the button can be pressed again.
      `carrier.gd` itself was not touched — it works correctly for real input; the fix lives
      entirely in how the AI drives it.

      **Role-based behaviour**, re-derived every `decide()` call from `is_can`/`is_person`/
      `team_is_can_side` (never cached — a Prop's job flips every round, same rule B-76 already
      established for ability re-picking):
      - **Can AI:** wanders to a random point inside `CONFINEMENT_RADIUS` on a slow cadence;
        `_move_and_confine()` already hard-clamps regardless, this just keeps it from looking pinned
        to the centre. Presses `bump` continuously the instant it is Downed and self-rightable —
        reacts the same physics frame, not on the slow decision cadence.
      - **Taya AI:** patrols the confinement box; on spotting the opposing Attacker within
        `TAYA_DETECT_RANGE`, closes in and taps `bump` on a cooldown once in melee range.
      - **Attacker AI:** retrieves its own team's loose Tsinelas (moves to it, taps `grab`) if not
        already holding it; once holding, closes to `ATTACKER_THROW_RANGE` of the tracked Can, holds
        `special_ability` for `ATTACKER_CHARGE_TIME`, releases, then holds a retreat spot behind the
        throwing line rather than walking back toward the Can empty-handed.
      - **Loose Tsinelas AI:** only acts while `Carriable.state == LOOSE` (CARRIED/FLYING already
        bypass `character_base.gd`'s normal input path entirely); crawls toward its own team's
        Attacker so the two meet partway rather than the Attacker crossing the whole gap alone.
      Difficulty is explicitly out of scope, per the brief — nothing here is tuned against a human
      or has any notion of a mistake. "Moves with intent and does not stand still" was the bar and
      is what was built; anything more is a follow-up item, not a silent extension of this one.

      **Removed/repurposed, decided rather than assumed:**
      - `project.godot`'s P2/P3/P4 input action bindings are **unchanged**. `Input.action_press()`/
        `action_release()` need the action registered in the InputMap, not bound to a real key — P3/
        P4 were already unbound and stay that way; deleting the action *definitions* (not just the
        bindings) would break `action_name()` lookups for AI-driven units using those player_ids.
        P2 stays bound too: it is still a genuine debug affordance (see next point).
      - `debug_player_switcher.gd` is **kept as a debug-only manual override**, not deleted: taking
        a slot now disables that unit's `AIController` (`_apply_slots()`) for as long as the slot
        holds it, and hands control straight back — including F5's "solo drive," which now correctly
        returns the parked unit to AI control instead of leaving it inert. This was an explicit
        choice, not an assumption: the switcher remains genuinely useful for driving a specific unit
        during testing without fighting its own AI over the same buttons.
      - The Settings panel's P2 rebind column is **removed** —
        `SettingsManager.REBINDABLE_ACTIONS`/`ACTION_LABELS` are now P1-only. The underlying P2
        bindings still exist in `project.godot` for the debug switcher above; there is just no
        player-facing UI to rebind keys a shipped Single Player session never uses. Verified by
        reading the code path (`settings_panel.gd::_build_rows()` iterates `REBINDABLE_ACTIONS`
        directly, no hardcoded P1/P2 column structure in the scene) rather than by render — no
        `render_probe.gd` mode exists for the Settings panel.

      **Doc hygiene**, same commit: `Dev_Plan.md` §0.2/§0.3/§3.5/§3.5.5 (the mode is no longer part
      of the debug removal contract; the switcher's purpose and removal timing are rewritten
      accordingly), `Art_Direction.md`'s failure-ladder table and its own §7 open-question #2 (now
      answered), `Handoff.md`'s frozen §1 System Context and §2 rule 10 (both previously said the
      mode "is stripped before submission"), and `README.md`'s contradiction register — all
      corrected rather than left to contradict the new reality. `Agent_Prompts.md`'s BUILD-AI brief
      marked done, same pattern as the other completed lane briefs in that file.

      **Verified by running**, not by reasoning alone: real (non-headless) Godot runs of the local
      test flow, 500-1400 frames, silent both before and after every fix. Directly confirmed a full
      grab → approach → charge → release → fly cycle completes (`carrier.held()` observed
      transitioning non-null → null after a charge, via a temporary diagnostic since removed) and
      that AI-driven units visibly leave their spawn points (render-probe screenshot, `B1·OFF` and
      `A2·DEF` both well off their starting marks). **Not verified:** a human actually playing a full
      Single Player Bo5 against the AI and judging whether it reads as a credible opponent — that is
      feel, and this item's own acceptance bar is explicitly narrower than that.
- [~] **5.6 · Track a packaged build in git; attempt a macOS export.** 🤖 Sonnet, medium — **2026-07-29,
      user request, not part of the original phase 5 scope**
      **Distribution change:** `build/TumbangPreso-win64.zip` (exe + pck + a player-facing
      `build/README.txt`) is now tracked in git — `.gitignore` allows `build/*.zip` and
      `build/README.txt` specifically while the loose `.exe`/`.pck` stay ignored (the `.exe` alone
      is ~104MB, over GitHub's 100MB hard push limit). A teammate can now clone or download the repo
      and get a runnable Windows build with no Godot install. See `tools/export.md` for the re-zip
      steps; **this needs a manual re-zip-and-commit after every build that should reach it** — there
      is no automation keeping it fresh.
      **macOS: attempted, unverified — do not report as supported.** Added an `export_presets.cfg`
      macOS preset and cross-exported it from this Windows machine to
      `build/TumbangPreso-macos-UNTESTED.zip` (also tracked). It genuinely completes and produces a
      real `Tumbang Preso.app` bundle, which required enabling
      `textures/vram_compression/import_etc2_astc=true` in `project.godot` (additive; Windows still
      uses its existing `s3tc_bptc` format, one `.import` file's diff shown as the representative
      sample). **Nobody has opened this on a Mac.** Codesigning/notarization are off, by design — see
      `tools/export.md` for what that means for Gatekeeper and what to try before concluding it's
      broken. This is a best-effort attempt per explicit user request, not a completed acceptance
      test; do not tick 6.-block submission items against it.

---

## Phase 6 — Submission. This is graded work, not paperwork.

A judge who never plays the build sees only the trailer and the demo video.
Budget this like a feature.

- [ ] **6.1 · 🧑 Real multi-device LAN test over real wifi.** ⛔ HUMAN — hardware, 4.2
      **Never done. On the critical path and has been flagged as such for three
      passes.** Everything so far is loopback on one machine. Real wifi adds
      latency and loss to a movement layer with no reconciliation. If this
      forces the shared-screen fallback (GDD §7), you need to know **weeks**
      before the deadline, and the FPP/TPP split makes that pivot cost one to
      two days, not half a day. **Book four laptops now.** No model can run this.
- [x] **6.2 · Live-demo script and trailer beat sheet.** 🎨 Design (Opus) — **delivered as
      [`Art_Direction.md`](Art_Direction.md).** Six-minute live running
      order, a printed controls card, a four-rung failure ladder, the 75-second
      loopable trailer beat sheet for 6.3 and the four-minute outline for 6.4.
      Written against what the build actually does — §0 is a verified/not-verified
      inventory. **Three findings a human must act on:** a full Bo5 at 90s/first-to-3
      is longer than any booth demo, so the demo needs a shorter preset; **5.3's
      "strip the local harness" directly contradicts the only network-free demo
      fallback**; and nobody has ever tested what happens when a peer drops.
      §7 lists all five open questions. `[x]` for the document, which is the
      deliverable — 6.3 and 6.4 remain the capture work.
- [ ] **6.3 · Trailer, 1–2 min, loopable — capture and edit.** 🤖 Sonnet, medium ⛔ 6.2, 4.1
      Needs the real map and audio to exist. `tools/arena_camera.gd` was
      deliberately preserved for exactly this — it is 100 lines of working
      broadcast-framing maths waiting for a spectator cam.
- [ ] **6.4 · Demo video, 3–5 min, narrated or captioned.** 🤖 Sonnet, medium ⛔ 6.2, 4.1
      Not a phone recording of a debug session. Its own pass.
- [ ] **6.5 · Template 01 — title and synopsis (≤500 words).** 🤖 Sonnet (📦 producer) drafts, 🧑 human approves
      Lead on Philippine Games and Sports; include the Circular Economy angle
      per 1.4 — the premise is literally about reusing everyday objects as
      sports equipment.
- [ ] **6.6 · 🧑 Form 01 — Game Development Team Roles.** ⛔ HUMAN
      Needs the ownership table filled in — see `Dev_Plan.md` §6, which is now
      the single canonical copy.
- [ ] **6.7 · 🧑 Form 02 — Waiver and Declaration of Originality, signed by all members.** ⛔ HUMAN
      Signing is not something a model may do on anyone's behalf.
- [ ] **6.8 · Form 03 — Asset and AI Usage Disclosure.** 🤖 Sonnet (📦 producer) keeps the register, 🧑 human signs ⛔ 3.1
      Already needs: Kenney Mini Characters (CC0, `KENNEY_LICENSE.txt`), the
      display and body typefaces from 3.1, and an AI-usage line. Keep a running
      list as assets land rather than archaeologising at the deadline.
      **Audio (4.1) is already done and is ONE row, not thirty-four:** every
      sound in the game — all 32 SFX and both map ambience beds — is generated
      by `tools/audio/generate_sfx.py` and `tools/audio/generate_ambience.py`.
      No recordings, no samples, no downloads, **no third-party audio in the
      build at all** (the two CC0 loops that briefly supplied the ambience were
      removed in B-123). Copy from `README.md`'s credits table.
- [ ] **6.9 · 🧑 Upload everything through the official submission link.** ⛔ HUMAN

---

## Phase 7 — The kit overhaul. Real asset kits replace the generated world.

**Spec: [`Art_Direction.md`](Art_Direction.md) §0b.** Read it before starting any item here — it
carries the measured scale table, and scale is where this goes wrong.

**Opened 2026-07-28 on the human's call:** *"ill be honest, assets suck so bad right now and its so
buggy."* Six Kenney kits (all CC0, verified) plus a supplied flip-flop `.glb`.

> ⚠️ **THIS PHASE CHANGES NO MECHANICS.** Explicit instruction: *"make sure all mechanics stay ok,
> focus on implementing the new assets and designs tho, let another agent do the mechanics."* Every
> item is an asset swap behind an unchanged interface. The camera directive, `is_person`/`is_can`,
> carry/throw, confinement, spawn slots, the round loop and the dent-count health model are all
> untouched. **7.1 is the only item that edits gameplay-adjacent code**, it is scoped to the
> material pipeline, and it exists because the swap cannot land without it.

> ⚠️ **ARENA SCALE IS NOT TOUCHED IN THIS PHASE** (Part 4's standing rule). Re-dressing a map and
> resizing it in the same commit makes a movement-feel regression unattributable. Item B (narrow
> the alley) stays open and stays separate.

- [~] **7.1 · The toon/outline pass must stop destroying kit textures. ⛔ BLOCKS 7.2–7.5.**
      🎨 Design (material pipeline only — not a mechanics item)
      **Shipped 2026-07-28, and honestly `[~]` not `[x]`:** the texture path is written but
      **cannot be proven until a kit mesh is in the project (7.2)** — there is nothing textured to
      point it at yet. What IS verified: parse clean, 400 real frames silent, and the existing
      procedural props render **pixel-identically** to before, which is the regression half.
  - [x] **`toon.gdshader` takes a texture.** `albedo_texture` + `use_texture`, multiplied by
        `albedo_color` as a tint. `hint_default_white` so an unset sampler multiplies to a no-op
        instead of sampling black and rendering every kit prop invisible. `use_texture` stays
        false for generated `.obj` props, so their maths is bit-for-bit unchanged.
  - [x] **`_apply_toon_pass()` carries the source texture across** instead of dropping it.
  - [x] **The hit flash is its own uniform now (`flash_amount` / `flash_color`).** It had to be:
        the flash tweened `albedo_color` white → base, and a textured mesh's resting tint IS white,
        so "flash to white" would have been a silent no-op and a hit on a kit prop would show
        nothing. `albedo_color` and "am I being hit" were two meanings sharing one uniform, which
        is why a texture broke both at once. Both flavours still differ (WHITE for a landed hit,
        `DEFENSE` for a block, Q-6). `_shader_base_albedos` is deleted — with the flash tweening
        1 → 0 there is no base colour left to restore.
  - [x] **Outline width per mesh, derived from its own scale.** Done once kit meshes existed to
        tune against. `outline.gdshader` inflates along the normal in MODEL space, so one shared
        `outline_width` meant the ink border's real thickness was whatever that mesh happened to be
        scaled by — the 0.34-unit Can wore a 0.025 border, ~12% of its own width per side, and
        rendered as dark slabs down both sides. Kit pieces differ by 10× in scale, so no single
        constant could ever have been right for more than one of them. Now `OUTLINE_WORLD_WIDTH`
        (0.012 world units) divided by the node's actual scale, one material per mesh. Persons are
        untouched — they take the early-out and keep `person_outline.tres`.
      `character_visual.gd::_apply_toon_pass()` replaces every surface material on a Prop with a
      flat `albedo_color` toon material. Kenney kits are textured off a shared palette atlas, so
      applied unchanged **every kit prop becomes one flat colour** — the swap cannot be evaluated,
      let alone shipped, until this is settled. Either sample the kit texture in the toon shader or
      skip the toon pass for kit-sourced meshes. Decide by rendering both.
      Fold in the outline width at the same time: `outline.gdshader`'s 0.025 is in MODEL space
      against meshes that now differ by 10× in scale (`Handoff.md` §0.12).
- [~] **7.2 · The lata → `soda-can.glb`.** 🎨 Design — **verified by render, not by play**
      Landed 2026-07-28. `CanVisual.tscn` instances the kit `.glb`; `CAN_MESHES` points at it and
      at `soda-can-crushed`, with `CAN_DENT_SQUASH` covering the two states the kit does not ship.
      **This is what proved 7.1** — the kit texture survives the toon pass, confirmed by render.
  - [x] **`_mesh_from()` — a `.glb` imports as a PackedScene, not a Mesh.** `load(path) as Mesh`
        silently returned `null`, which would have meant a can that never changed on damage: no
        error, no missing mesh, just a dent count that never showed.
  - [x] **⚠️ THE KIT CAN WAS OFFENSE-ORANGE, and that is a hard-rule break.** `Dev_Plan.md` §4.2
        rule 1 — orange is ALWAYS offense — and this put a vividly orange can on the DEFENDING
        team's most important object. Same class as B-81, from the opposite direction. Caught by
        rendering it, not by reading the kit. Fixed **at the asset level** by
        `tools/models/retint_kit_atlas.py`, which moves the bright orange band of our copy of
        Kenney's shared `colormap.png` to Sarsi blue: 11,390 px, idempotent, and it protects every
        kit prop 7.4 imports later rather than just this one. Browns and tans are deliberately
        untouched — they are legal and remapping them would turn every crate blue.
  - [ ] **Residual:** a thin orange rim survives at the can's base (a swatch outside the remapped
        band) and the outline width is still the flat 0.025. Both fold into 7.6's retexture.
      Dropped in at **native scale** — 0.351 against the old 0.335, the one free win in the whole
      overhaul; no rescale was needed anywhere.
      **Acceptance, still owed by a human:** knock it over, take three dents, win a round and see
      it reset. Behaviour is unchanged by construction but has not been played.

- [x] **7.2a · The Can's own camera — "BROKEN LATA CAMERA".** 🎨 Design — **verified by render**
      Playtest report with a screenshot of an empty road. `TppArm`'s baked 4.5-unit spring length
      was tuned for a 1.6-unit Person; the Can is **0.34**, so playing as the Can framed it as a
      speck. The arm length and pitch now scale to the unit's own capsule, re-applied on every
      model change so a role swap re-frames.
      ⚠️ **The mount height deliberately does NOT scale.** That was tried in an earlier pass and
      reverted — it dropped the shapecast's origin low enough to collapse the camera into solid
      geometry. Length and pitch change only where the cast *points*, never where it *starts*, so
      the fix cannot reintroduce that failure. Renders before and after confirm: subject centred,
      no collapse, arena still readable.
- [ ] **7.3 · The tsinelas stays OURS.** 🎨 Design — **not blocked by anything**
      Human call, 2026-07-28: *"nahh js remove the flipflop in the plan, lets make our own."* The
      supplied `.glb` is dropped and **the procedural tsinelas is the shipping slipper.** It
      already matches the §1b asset moodboard — brown `PROP_FOAM` foam, tan `PROP_WEBBING` Y-strap,
      three-layer bevelled sole — and it is the one prop nobody has complained about the look of.
      **This item is therefore refinement, not replacement**, and it is the exception to phase 7's
      "kits replace generated geometry" rule: authored beats sourced here because the moodboard is
      specific and the mesh is already on it.
      *Deleting the `.glb` also deleted the phase's only licence blocker* — every remaining asset is
      either CC0 (Kenney) or ours.
  - [x] **The carried slipper no longer floats beside the carrier's head (B-105).** Fixed
        2026-07-28 by splitting the two views instead of re-tuning a number — see the ledger.
  - [ ] **Readability follow-up:** brown slipper against a tan chibi body is low-contrast at
        arena distance, and the rig's hand sits close to a wide torso. It is in the hand and no
        longer floating; making it *read* from across the arena is a separate pass.
- [~] **7.4 · Eskinita re-dressed from City Kit (Suburban) + Car Kit.** 🎨 Design —
      **verified by render + the full smoke gate; not verified by play**
      Landed 2026-07-28. The generated corrugated wall panels and building blocks are gone; an
      eskinita is the gap BETWEEN people's houses, so City Kit houses now ARE the wall line, with
      street trees on the verge and a vehicle parked in every fourth bay where a house is left out
      for a driveway. `CITY_SCALE = 5.0` and `CAR_SCALE = 1.75`, one constant per kit as §0b requires.
  - [x] **Mechanics untouched, and checked rather than asserted.** Playable width still `x = ±8`;
        `SpawnPoints` transforms byte-identical; `Bounds`/`WallEast..South`, `KillPlane`,
        `HazardZone` and `Floor` all present; and **the dressing still carries zero collision** —
        grepped, 0 `CollisionShape3D` under `Dressing/`. The single invisible Bounds ring behind
        the wall line is still the only thing a player can touch.
  - [x] **The height law survives.** Vehicles are 2.5 tall, which would break the ≤1.25 rule for
        anything inside the alley — so they are parked at `x = ±9.9`, OUTSIDE the playable width,
        seen through the driveway gaps. Interior clutter is unchanged and still ≤1.0.
  - [x] **⚠️ A `.glb` is a PackedScene, not a Mesh, and getting that wrong is SILENT.** The first
        build emitted kit pieces as `MeshInstance3D` with `mesh = ExtResource(...)`. No error, no
        warning, correct transforms, 134 nodes present — **and an entirely empty street**, because
        Godot loads a mesh property pointed at a scene as blank. Caught only by rendering it. The
        builder now branches on kit vs generated and the trap is written down at the emit site.
  - [x] **⚠️ Kit meshes do NOT put their origin at their base.** `kits/car/van` spans local
        `y = -0.300..1.150`, so a naive `y = 0` placement buries 30cm of it in the road — the
        floating-geometry bug with the sign flipped. `add_kit()` takes the height the BASE should
        sit at and reads the offset from the mesh's own bounds, same source of truth as floorcheck.
  - [x] **`floorcheck` reads `.glb` bounds now**, so kit pieces go through the same flush gate as
        generated ones instead of leaving a hole in the guard exactly where the new assets are.
  - [ ] **Deferred:** Furniture Kit dressing (sari-sari interior, street furniture) and the
        procedural clutter/tricycle swap. Both are detail passes on a map that now reads correctly;
        neither blocks 7.5.

- [~] **7.5 · The probinsya map from Fantasy Town Kit + Mini Forest.** 🎨 Design —
      **verified by render + full smoke gate; not verified by play**
      Landed 2026-07-28. The generated cone trees, bench, planter, chair and tire are gone. Two
      tree rings of DIFFERENT species (Fantasy Town near at `TOWN_SCALE` 2.6, Mini Forest behind at
      `FOREST_SCALE` 3.9) so the far layer reads as another species rather than the same tree moved
      back; market stalls, stall benches and stools; lantern posts on the slab corners; rocks and
      plants across the dirt apron. Church, flagpole and both basketball rings kept — they are the
      map's landmarks and its Filipino read.
  - [x] **Mechanics untouched and checked:** `SpawnPoints` transforms byte-identical, `Bounds`,
        `KillPlane`, `HazardZone`, `Floor` all present, and **0 collision shapes under
        `Dressing/`** — the `BOUND = 12.5` ring is still the only thing a player can touch.
  - [x] **Height law honoured through the swap.** Everything inside the playable square is
        interior-tier: stall 0.96, stall-bench 0.60, stool lower. `cart` measures 1.40 scaled and is
        therefore deliberately NOT used. The full-height trees are all outside `BOUND`, which is
        what earns them the exemption.
  - [x] **⚠️ B-104 — Bayan Plaza was UNREACHABLE and had been all along.** Both `GameLaunch.MAPS`
        entries carried `"id": &"eskinita"`, so `selected_map_scene()`'s first-match lookup
        resolved the plaza to Eskinita: the picker, the launch path and the render harness could
        every one of them only ever load map 1. Silent — you pick the second map and the first
        loads, which reads as an unresponsive picker rather than a duplicate key. **Found only
        because the re-dressed plaza kept rendering as Eskinita three times running.**
  - [x] **A new `Dressing/*` group must be declared in the scene template.** Adding `Ground`
        placements without the node emitted `Parent path './Dressing/Ground' has vanished` for
        every piece — a warning, not an error, so the pieces just silently do not exist.
- [ ] **7.6 · Sarsi livery, as a retexture of `soda-can.glb`.** 🎨 Design ⛔ 7.2
      **Deliberately deferred, on the human's own instruction:** *"js add to plan that we will make
      that better later and make it sarsi or something."* Checklist 2.9 shipped a Sarsi-liveried
      *procedural* can hours before this overhaul and 7.2 replaces it — the livery does not survive
      the swap and is rebuilt here as a texture instead. The trademark note and the credit in
      `README.md` stay valid throughout and do not need revisiting.
- [~] **7.7 · Wire the animation clips the kit already ships.** 🎨 Design —
      **verified by parse + two 400-frame soaks incl. a driven double round transition;
      not verified by play**
      Human instruction: *"the assets i sent has animation built in, pls use."* Verified: **Mini
      Characters ships 32 baked clips per `.glb`; every other kit ships zero.** So this is a
      character item only — there is nothing to wire on props or the world.
      Eight clips are already wired (`idle`, `walk`, `sprint`, `holding-right`,
      `holding-right-shoot`, `attack-melee-right`, `attack-kick-right`, `pick-up`). Wire these,
      each of which reads state the game **already tracks**:
  - [x] **`jump` / `fall`.** Split by VERTICAL velocity so a rising jump and a falling one are not
        the same pose. `_play_locomotion()` selected on horizontal speed alone, so a Person at the
        apex of a jump — horizontal speed near zero — played `idle`, and one drifting sideways
        through the air played `walk`. Every unit can jump (§0's pillar put it on the Prop too),
        which made this the most-seen missing pose in the build.
  - [x] **`die` on `State.DOWNED`**, checked before everything else. Being knocked down read only
        in the HUD flash and the `Visual` tilt; a downed unit and a standing one played the same
        idle clip.
  - [x] **`emote-yes` on the `ready_up` press.** Goes through the existing `play_visual_action()`
        path, so the two views cannot disagree about whether a ready happened. Guarded on the local
        roster, which is empty on every non-local path.
  - [ ] **`holding-right-shoot` held and scaled by `Carrier.charge_power()`** — a candidate answer
        to the long-open third-person windup tell, using a clip that already exists instead of new
        geometry. ⚠️ If reading charge from another peer's `Carrier` needs a **new synced field**,
        that half is a Build-lane wall — file it in `Handoff.md` §5 and hand it back; the visual
        half stays ours.
  - [ ] **Do NOT wire `interact-right`.** It maps to the lata reset channel (B-46), which is not
        built. Listed only so nobody wires a clip to a mechanic that does not exist.
      ⚠️ **Scope boundary:** every sub-item reads existing state and plays a clip — no new state,
      no new input, no new networking. That is what keeps this in the design lane.

## Phase 8 — The environment pass. Kill the void, ground the props, light the street.

**Spec: [`Art_Direction.md`](Art_Direction.md) Part 6.** ⚠️ **Read §8.8 first** — it is the
execution record, and six of the real defects were not in the original audit at all.

**Opened and executed 2026-07-29.** Human call: *"the visuals are atrocious, sterile, and look like a
broken prototype test grid ... WORST OF ALL: the map is a literal floating island."*

> ⚠️ **NO MECHANICS CHANGED.** `Bounds/Wall*` are still at ±8.6 / ±18.0 in the built scene (verified
> by reading it back after instantiation), and `CONFINEMENT_RADIUS`, spawn slots, the round loop,
> carry/throw and the dent-count model are untouched. The Floor box went 40 → 120 as a **backdrop**;
> not one collider moved. `env_toon_pass.gd` adds no state, signal, group or RPC.

> ⚠️ **EVERYTHING BELOW IS `[~]`, NOT `[x]`.** All of it is render- and parse-verified and none of it
> has been played by a human, which is this project's own standing bar. See 8.7.

### 8.1 · Grounding and footprints `[~]`

- [~] **8.1a · `floorcheck.py` checks DRESSING, not just markings.** All 510 instances now gated;
      `suspended=True` is the one explicit opt-out (sampay is *meant* to hang).
- [~] **8.1b · The 100 mm sink is gone.** `add()` takes `base_y` defaulting to
      `surfaces.height_at()`. ⚠️ **Ground is now emitted FIRST** — the road block sits at the top of
      the builder, because `height_at()` can only see what is already recorded. The old file placed
      buildings before the road, which is *why* everything grounded against bare floor.
- [~] **8.1c/d · Per-piece face alignment and width-aware bays** via `piece_extent()`. Facades land
      on x = ±8.6, the collision plane, so you can no longer walk into a visible house front.
      `surfaces.overlaps("Layer1")` reports **none**.
- [~] **8.1e · Footprint-overlap warning** added.
- [~] **8.1f · ⚠️ THE HOVERING VAN — not in the audit.** `_glb_bounds()` ignored glTF node
      transforms, so every Car Kit vehicle floated **exactly 525 mm**. See Part 6 §8.8 item 1.
- [~] **8.1g · ⚠️ Characters' feet were 100 mm inside the road — not in the audit.** Floor collision
      top now equals paving top. See §8.8 item 2.
- [ ] **8.1h · Bayan Plaza — DEFERRED by explicit human call.** Opted out with
      `Surfaces(check_dressing=False)`. **Delete that argument to start; the failures are the list.**

### 8.2 · The void is dead `[~]`

- [~] **Ring 0** Floor 40 → 120. **Ring 1** paved apron to ±26, one tile scale, seeded quarter-turns
      for variation (the city driveway/path pieces are a different footprint and would have holed
      the grid). **Ring 2** three silhouette rings at 30/37/44 plus distant tree mass. **Ring 3**
      depth fog 18 → 72 matched to the sky horizon colour. **Ring 4** ground colour pulled to fog.
- [~] **Acceptance met: five renders** via `tools/void_probe.gd` — y=25 down the alley plus all four
      collision-wall corners looking outward. No ground edge, no sky seam.

### 8.3 · Lighting and renderer `[~]`

- [~] **8.3a · `[rendering]` section created** — the project had none, so AA was off entirely.
      MSAA 2x + FXAA + debanding, 4096 directional shadows, soft-shadow quality 3, occlusion culling.
- [~] **8.3b · ACES** (`tonemap_mode` 0 → 3). Retuned after the first render came back badly
      overexposed: white 6.0 → 1.9, exposure 0.92, ambient pulled back, contrast into the sun.
- [~] **8.3c · SSIL on. SDFGI on** (human call).
- [~] **8.3d · ⚠️ Shadow bias swept, not guessed.** Lowering it per plan produced acne — the
      reported "lines". Landed at 0.06 / 3.0, angular 0.5, blur 0.9. See §8.8 item 4.
- [~] **8.3f · Frame time MEASURED, 2026-07-29** (`tools/perf_probe.gd`, real match scene,
      1920x1080, AMD RX 6600):

      | case | fps |
      |---|---|
      | everything on (SDFGI + SSIL + SSAO + glow) | **81** |
      | no SDFGI | 90 |
      | no SDFGI + no SSIL | 90 |
      | no GI/SSAO/glow | 90 |

      **SDFGI is the entire cost** — ~9 fps, and it is what pushes the scene below the vsync cap.
      SSIL, SSAO and glow together are free at this resolution. ⚠️ **This is a DISCRETE GPU.** The
      submission machine is still unprofiled, and SDFGI is exactly the feature that collapses on
      integrated graphics. **Re-run `tools/perf_probe.tscn` on the judging laptop before submission**
      — if it cannot hold 60, turn `sdfgi_enabled` off in `build_eskinita.py`'s Environment block and
      re-run the builder. Nothing else in Phase 8 needs to change to do that.

### 8.4 · Shaders and the world's shading model `[~]`

- [~] **8.4a · The banners were cardboard because they WERE cardboard** — extruded solid prisms with
      two vertex rings. Rebuilt as segmented double-sided sheets that can actually bend.
- [~] **8.4b · Wind.** ⚠️ Lives *inside* `toon.gdshader`, not a separate material: `env_toon_pass.gd`
      replaces every map material, so a standalone cloth shader would be overwritten on load.
      `outline.gdshader` carries an identical copy, or the cloth swims inside a still ink border.
- [~] **8.4c · Rim light added, uniform-gated, DEFAULT 0.0** — it is on the Can, whose colour is
      load-bearing for the OFFENSE/DEFENSE rule.
- [~] **8.4d · Toon pass extended to the whole map** (human call). 514/530 meshes; kit textures
      preserved (468 surfaces). Belt and road skip the outline pass — an ink line on 300 distant
      roofs reads as a sticker sheet.
- [~] **8.4e · ⚠️ Colour variety — new requirement mid-run.** Seeded facade tints + five recoloured
      roof atlases + foliage tints. ⚠️ The roof tool's first version did nothing and said it worked;
      read §8.8 item 5 before touching it.

### 8.5 · Camera `[~]`

- [~] **8.5a · Physics interpolation enabled** (there was no `[physics]` section) and
      `_update_tpp_carry_follow()` now reads `get_global_transform_interpolated()` instead of
      sampling a 60 Hz transform from a render-rate `_process`.
- [~] **8.5b · Spring-arm margin 0.15 vs camera near 0.05,** both explicit. A default 0.01 margin
      under a 0.05 near plane guarantees wall clip-through when the arm bottoms out.
- [x] **8.5c · Camera already ignores clutter — no change needed, and this was checked.** Map
      dressing carries **no collision at all** (the built scene has 12 collision nodes: floor, four
      bounds walls, kill plane, hazard). `TppArm.collision_mask = 1` can only ever hit those. The
      same fact answers "slippers bouncing off invisible walls": there is nothing invisible in the
      dressing to bounce off.
- [ ] **8.5d · Viewmodel arm clipping — still needs a playtest repro.** Unchanged deliberately;
      `camera_rig.gd:718–726` records a previous attempt making it worse.

### 8.6 · Density and the lane law `[~]`

- [~] **8.6a · The lane law is enforced by code, not comment.** `assert_clear_of_lane()` fails the
      build on the piece's real footprint. ⚠️ It caught the author on its first run — the parked cars
      were nose-in and reached 3.2 m from the alley centre.
- [~] **8.6b–d · Heavy side clutter** (human call): market carts, stalls, benches, stools, rocks,
      planks, crates, tyres, drums, chairs, hedges, fences, lanterns, two sari-sari stores and four
      tricycles; nine posts and six sampay lines overhead. Lanes stay empty.
- [~] **8.6e · ⚠️ Pink chalk DELETED, generator and asset included.** It was also the cause of BOTH
      reported line faults. Replaced with a `gutter_tile` kanal so the live `HazardZone` keeps a
      visual tell — deleting it alone would have left an invisible slow-field. See §8.8.
- [~] **8.6f · White court lines close.** Corners were notched by exactly the crossing line's
      half-width; every edge now overruns by that much and all lines share one `COURT_X`.

### 8.8 · Playtest round 1 — three bugs, all root-caused by measurement `[~]`

First human play of Phase 8, 2026-07-29. All three fixed; none was what it looked like.

- [~] **8.8a · ⚠️⚠️ THE RECURRING SPAWN BUG, FINALLY ROOT-CAUSED. Read this before touching
      spawns again.** Report: *"spawn still broken, offense spawned next to circle."*
      `_role_slot()` was **always correct** — the audit print showed it returning the right slot for
      all four units. `_spawn_transform(slot)` returned the **wrong marker**, because
      `main.gd` sorted the markers with `markers.sort_custom(func(a, b): return a.name < b.name)`
      and **`Node.name` is a `StringName`, whose `<` compares the interned POINTER, not the text.**
      Measured on this engine build, Spawn0..Spawn3 authored in order came back as
      **`[Spawn3, Spawn2, Spawn0, Spawn1]`** — so the Attacker stood on the Taya's mark, right
      beside the base circle it is supposed to be throwing at from outside the line.
      Everything about it invited trust: the comment said "sorted by node name", the markers were
      authored correctly, and the wrong order was *stable within a run* so it looked deterministic.
      It is **not guaranteed stable between runs**, which is why this appeared to move around from
      session to session. Replaced with an explicit `get_node("Spawn%d")` lookup — there is no
      ordering left to get wrong, and a missing marker now warns instead of shuffling the roster.
      ⚠️ **Any `sort_custom` on `.name` anywhere in this project is the same bug.**
- [~] **8.8b · The floating held slipper.** `CharacterVisual.HAND_CARRY_OFFSET` was
      `(0.237, 0.135, -0.347)` — **0.441 m measured bone-to-point**, on a 1.6 m character. It
      existed to cancel the mesh drop `_align_to_capsule_floor` applies to a carried unit, which is
      a measured **0.160**, and it was expressed in the **hand bone's local frame**, which rotates
      with every animation clip — so it could never have held across poses. The drop is now
      cancelled in `carriable.gd::_step_carried()` in world space from the carried unit's own
      `visual_centre_offset()`, so the **mesh** lands in the hand rather than the origin, and it is
      correct for the Can too. `HAND_CARRY_OFFSET` is now a 0.078 wrist→palm nudge and nothing else.
- [~] **8.8c · Shadows overwhelming.** *"cant see person anymore."* Not one slider: `shadow_opacity`
      had been pushed to fully opaque **and** ambient cut to 0.55 while fighting the earlier
      overexposure, so anything in shade lost its fill. Opacity 0.62, ambient 0.95, SSAO intensity
      3.2 → 1.8, sun 1.75 → 1.35. A character in shadow reads again.

### 8.7 · ⛔ What is owed before Phase 8 is finished

- [ ] **A human plays it.** Nothing here is `[x]` until then — the standing rule.
- [x] **8.3f frame-time capture — DONE** (see 8.3, and `tools/perf_probe.gd`). Still owed: the
      same run **on the actual judging laptop**, which is the number that decides SDFGI.
- [ ] **Two-instance networked test.** Nothing touches the network layer and `env_toon_pass.gd` is
      inert, but that is reasoning, not evidence. Now also covers the **new GameSetup → Lobby →
      Main routing** from the PR #13 merge, which the UI lane should re-check when it next touches routing.
- [ ] **The held slipper in THIRD person and while WALKING** (B-112). Verified in an FPP render
      only, and clip-dependence was the original bug — so the one pose it was checked in is the
      least informative one.
- [ ] **Bayan Plaza** (8.1h), deferred by explicit human decision.

## Phase 9 — Graphics downgrade, AI rewrite, and a game-wide bug sweep

**Opened and executed 2026-07-29.** Human call: *"we have introduced severe visual regressions, lag,
and AI breaking bugs ... a game-wide audit, a graphics rollback, and the eradication of all bugs
across Physics, Networking, AI, and UX/UI."*

Full root-cause writeups: `Handoff.md` **B-114 … B-118**. Everything here is `[~]` — measured by
probe, not played by a human.

### 9.1 · Graphics downgrade `[~]`

- [~] **Toon shading and the inverted-hull outline removed from the MAP.** Two draw calls and a
      unique ShaderMaterial per surface across ~510 instances, and `diffuse_toon`'s hard 2-band step
      landed as a wide horizontal stripe across every flat kit wall — the reported "ugly horizontal
      banded shadows". `env_toon_pass.gd` now applies a plain `StandardMaterial3D` and keeps only
      the seeded facade tints, roof-variant atlases, foliage variation and the road correction.
      ⚠️ **Characters KEEP their toon pass.** The shading split is now deliberate.
- [~] **SDFGI, SSIL and glow off.** SSAO kept but softened; shadow distance 58 → 42.
- [~] **Measured: 90 → 203 fps** at 1080p on an RX 6600 (`tools/perf_probe.gd`).
- [~] **Background quieted.** Three belt rings plus three tree rings → two rings plus one, further
      out and faded harder into fog. 510 → 382 instances.

### 9.2 · Court lines `[~]`

- [~] **One closed outer rectangle with cross-lines.** The confinement square was already closed;
      the throwing and team-side lines were free-floating segments with nothing to terminate on,
      which is what "overshoot / do not close" described. Now `CourtEast/West/North/South` bound
      everything and every cross-line ends inside the side lines.
- [~] **A real 20 mm overshoot fixed.** `court_line()` extended each line by ITS OWN half-width,
      which is only correct when every line shares a mesh — `throwing_line_decal` is 0.12 wide
      against `team_side_decal`'s 0.08, so throwing lines poked to ±5.060 past a side line ending at
      5.040. Verified programmatically: zero overshoot.

### 9.3 · AI `[~]` — see also the fairness log below

- [~] **B-114 · independence.** The global `Input` singleton is out of the AI path; per-instance
      intent + per-instance RNG + jittered decision phase. Co-transition rate 1/846 frames.
- [~] **Roles now try to win.** The Taya BODY-BLOCKS (stands on the can→attacker line) instead of
      chasing something the confinement geometry forbids it from reaching; the attacker checks its
      throwing lane and slides to an open bearing instead of charging the block.
- [~] **Fairness IS measured now** — corrected 2026-07-30; this row used to read "NOT measured".
      Nine logged runs, of which **only RUN 8 is trustworthy** (RUNS 1–7 measured a 3-v-4). The
      result is bad and honest: DEFENCE 100%, 92% of throws blocked, 0.00–0.10 dents per round.
      `[~]` because the measurement exists and **the balance does not**. See the fairness log below
      and [`Roadmap.md`](Roadmap.md) Stage 1.

### 9.4 · UX / UI `[~]`

- [~] **Scoreboard pips.** Reported as "remain empty and do not update" — they were filling with
      `UiTheme.CARD` (#f5f7fa) on a near-white card, so contrast was zero. Now the team's ROLE
      colour, matching `match_result.gd`. Verified by render at 0/1/2/3 wins.
- [~] **HUD stopped rebuilding six StyleBoxFlat objects every frame** (~360/s) to redraw a value
      that changes a handful of times per match.

### 9.5 · Physics & interaction `[~]`

- [~] **B-115 · spawn depenetration** — the real root cause of B-100, and three "obvious" fixes that
      do not work are recorded so nobody retries them.
- [~] **B-116 · spawns embedded 100 mm in the floor.**
- [~] **B-117 · a thrown tsinelas had no live hitbox.**
- [~] **Audited clean:** slipper never below the floor (min Y 0.245 vs floor 0.100), never outside
      bounds, no snagging — `tools/phys_probe.gd`.

### 9.6 · Networking `[~]`

- [~] **B-118 · freed lambda capture on round reset**, found in a real two-instance session.
- [~] **A real `--host` / `--join` session now runs clean on both sides** — the first time this has
      been done in this project. Replication config audited: `position`/`rotation` ALWAYS
      (unreliable, correct for continuous data), `state`/`dents` ON_CHANGE (reliable). Authority
      gating confirmed: non-authority peers return before reading input, so the new AI intent path
      is host-only by construction.
- [ ] **Still not covered:** packet loss / latency simulation, mid-match disconnect and reclaim, and
      a 4-peer session. Two local peers on loopback is the weakest possible network test.

## Phase 10 — Boot sequence, menu, house logic, Can AI, and the second map

**Executed 2026-07-29.** Assets supplied by the human in
`TITLE SCREEN AND OPENING ANIMATION.zip`. Everything `[~]` — probe/render
verified, not played.

### 10.1 · Boot and menu `[~]`
- [~] **Opening animation plays at every launch.** `Opening Animation.mp4`
      (1920x1080, 60fps, 3s) converted to `assets/video/opening_animation.ogv`
      — ⚠️ **Godot 4 ships only `VideoStreamTheora`; there is no h.264 or webm
      support in core.** 1280x720/30fps keeps a boot-path asset at ~180 KB.
      `SplashScreen.tscn` is `run/main_scene` and hands off to `MainMenu`.
      ⚠️ Two independent exits — any key skips, and a `MAX_WAIT` watchdog fires
      if the video never reports finishing. A boot screen that can hang is worse
      than no boot screen. Verified: `tools/boot_probe.gd` (a **SceneTree**
      script, because a probe node is freed by `change_scene_to_file`).
- [~] **Menu backdrop.** The street/can/slipper plate extracted from
      `Menu Screen Possible Ideas.pdf`, given the PEAK treatment the human asked
      for — blurred, desaturated, darkened, warm haze, left-side scrim and a
      vignette — so the UI reads on top of it instead of fighting it.
- [x] **TUTORIAL button** in the gap between SETTINGS and QUIT. Superseded by
      10.4 below: the pennant art it reused was a one-axis scale of the SETTINGS
      one and is now cut to fit, and the `print()` stub now opens a real screen.

### 10.2 · Architecture and AI `[~]`
- [~] **House orientation.** ⚠️ **Measured, not guessed** — `tools/facing_probe.gd`
      rendered a kit building from all four cardinal directions: the front is its
      local **+Z**, both ±X sides are blank gable walls. The old `yaw = ±90°` put
      the front at ±X, i.e. **both rows faced away from the street**. Sign
      flipped; Layer 2 now faces outward (back-to-back lots, how real blocks are
      built) and the belt fronts run along their rings.
- [~] **Can evasion.** The Can had no reactive behaviour at all. It now tracks a
      FLYING tsinelas, ignores throws that are not closing or would already miss,
      **sidesteps perpendicular** (running away from a faster object never
      works), stays inside `CAN_EVADE_RADIUS` of its mark, and raises Guard when
      it is too late to dodge. Measured: moves on ~89% of in-flight frames.
      ⚠️ **Tuned toward hittable on purpose** — a sweep showed lookahead 0.70
      made the Can literally unhittable (0 contact frames). Balance surface; see
      the fairness log.
- [~] **Sky.** Replaced `ProceduralSkyMaterial` (a two-colour ramp that the fog
      washed to the same cream as the ground — the "endless desert") with a
      generated cloud panorama. ⚠️ **One texture fetch, cheaper than the
      procedural sky it replaces**, so it costs nothing against the Phase 9
      performance rollback and adds no shader.
- [~] **Electric wires and sampay.** `_post_electric()` draws its wire a fixed
      6.0 units to where the NEXT post should be; posts were alternating sides
      every 4.0 with the yaw flipping, so **no span ever reached another post**.
      One evenly-spaced row per side at exactly 6.0 with a shared yaw. The
      clothesline now spans wall-face to wall-face (±8.6) with visible tie-off
      blocks, and is raised so its hem clears a Person's head (was 1.58 against a
      ~1.70 head).
- [~] **House-row gaps.** `BAY_GAP` 1.1 → 0.35, and every driveway bay gets a
      fence plus a hedge so a gap is never bare asphalt.

### 10.3 · Bayan Plaza `[~]` — PARTIAL, PAUSED, PLAN IN THE FILE
- [~] Ported: the GROUND_Y contract, the grounding guard (deferral over),
      `piece_extent()`, a plaza-shaped lane law (a protected **disc**, since a
      plaza is fought across not along), the closed court, the four-ring void
      kill, the panorama sky and the material pass.
- [ ] ⚠️ **NOT DONE and documented at the top of `build_bayan_plaza.py`:** house
      orientation not applied to its own tree rings/landmarks, no five-shot void
      acceptance, clutter still sparse, the HazardZone still has no visual tell,
      and it is not yet signed off in play, networked or profiled.
- [ ] ⚠️ **The two builders share `floorcheck.py` and nothing else.** Every
      Eskinita lesson has to be ported by hand — that is how those items survived.

### 10.4 · Front-end UI overhaul `[~]` — render-verified, not played

**Executed 2026-07-29** against the four fixes in the human's brief. Everything
here is verified by looking at renders (`tools/ui_shot.gd`,
`tools/ui/tutorial_shot.gd`, `tools/ui/gamesetup_shot.gd`,
`tools/ui/pause_shot.gd`) and by the full smoke gate including the conditional
audio seventh. **None of it has been clicked by a human.**

- [~] **TUTORIAL pennant cut to fit, not scaled.** The shipped asset was a
      991x350 canvas beside SETTINGS' 991x226 — same width, every band
      measurement a clean 1.55x. A one-axis scale fattens an outline's
      horizontal runs and leaves its vertical ones alone, so the stroke stops
      being constant width, the slant steepens and the point goes blunt.
      ⚠️ **Redrawing it un-stretched was still wrong**, and that is the lesson:
      the hole between SETTINGS and QUIT is a WEDGE, not a band. Those two edges
      diverge left and converge right (203px of gap at the screen edge, 119px at
      the point), so any constant thickness gaps at one end and collides at the
      other — which is exactly what the first attempt did, both at once.
      `tools/ui/generate_pennant.py` now derives the silhouette from the
      neighbours' measured alpha and node rects, insetting both by the 12px
      gutter the PLAY/SETTINGS seam already uses. Re-run it after moving any
      pennant in `MainMenu.tscn`; it prints the rect and caption values.
- [~] **`Tutorial.tscn`** — eight pages covering the loop, the two sides, the
      round beat-by-beat, controls, both win modes and the two rosters. Every
      number is read out of the code that implements it (`RoundManager`,
      `MatchManager`, `Carrier`, `project.godot`'s `[input]`), not out of the
      GDD. ⚠️ **The confinement radius is deliberately given no number** — the
      GDD says 3 units and `CharacterBase.CONFINEMENT_RADIUS` says 5.0, so the
      page describes the rule instead. Put a number there once they agree.
- [~] **Live map behind the GAME and LOBBY screens**, replacing the blueprint
      grid, swapping the frame the picker cycles. Per-map framing lives in
      `GameLaunch.MAPS` because `tools/maps/build_*.py` emit the map scenes
      wholesale. ⚠️ Maps are re-parented, never hidden: `visible` does not
      propagate to WorldEnvironment or DirectionalLight3D, so a hidden map keeps
      lighting the world and fighting the other map's environment for it.
- [~] **Pause card rebuilt** on the new wood theme variations. The networked
      "match is still running" caveat moved from the title to its own caption
      line — at display size the old appended string overflowed the card.
- [x] ⚠️ **Was: nothing syncs the selected map across peers.** `main.gd` read
      `GameLaunch.selected_map_scene()` locally on every peer, so a client who
      picked a different map loaded a different map than the host. **Fixed in
      10.5 (U-8), along with the same hole in `game_mode` that nobody had
      written down** — mode was only ever sent to a peer joining MID-match, so a
      lobby joiner kept its own ruleset while `hitbox.gd`/`carriable.gd` branch
      on it per-peer. Both are host-owned and broadcast now, and a client's
      arrows are disabled. Verified with two real instances started on
      deliberately opposite maps and modes — see 10.5.
- [ ] ⚠️ **Not addressed, found in passing:** `FoldCorner` is a bare `Control`
      carrying a `canvas_item` shader, and a bare Control draws nothing, so the
      shader never runs — the fold has never rendered anywhere. Removed from the
      pause card; `SettingsPanel.tscn` still has its own dead copy.

### 10.5 · Front-end flow overhaul `[~]` — probe-verified across two real instances, not played

**Executed 2026-07-29**, against the human's brief: ask Single Player vs
Multiplayer first, then Host vs Join; make the solo and multiplayer setup
screens the same screen; give the host sole control of map and mode; and take
the pointless ready gate off Single Player.

⚠️ **THIS PASS WAS FIRST BUILT ON A STALE BASE AND HAD TO BE REDONE.** It was
cut from `main`, which was 24 commits behind `integration`, so it did not know
`CharacterSelect.tscn` existed and built a competing ability picker of its own.
Recorded because the lesson is cheap here and expensive later: **branch from
`integration`, not from `main`** (`Concurrency_Protocol.md` §1 says so and it was
not followed). The rebuild kept every line of the character-select work and threw
away the competing picker.

**Two live defects closed, one never previously written down.** Both the same
shape — a per-peer value nobody reconciled:

- [x] **The map (U-8, recorded open in 10.4).** `main.gd::_load_map()` read
      `GameLaunch.selected_map_scene()` locally on every peer and nothing synced
      it. Not a crash — worse: everyone played a *different arena*, spawn points
      came from their own local map, and movement being client-authoritative,
      players walked through walls that only existed on someone else's screen.
- [x] **The mode — the same hole, undocumented.** `GameLaunch.game_mode` was
      only ever transmitted to a peer joining **mid-match**. A lobby joiner kept
      its own pick while `hitbox.gd` and `carriable.gd` branch on it per-peer, so
      a client on DENTS dented a can the host on CAPTURE did not.

- [x] **The flow.** `MainMenu → ModeSelect → (MultiplayerSetup) → MatchSetup`.
      The Single-Player-vs-Multiplayer question used to be the *last* of three
      sibling buttons on the GAME screen and looked identical to the other two.
- [x] **One setup screen for both.** `MatchSetup.tscn` replaces **both**
      `GameSetup.tscn` and `Lobby.tscn`, which are deleted. Same layout and same
      positions in solo and multiplayer; what differs is which controls are live.
- [x] **`CharacterSelect` became a panel, not a step.** It is instanced hidden
      inside `MatchSetup.tscn` and toggled, the way `MainMenu.tscn` already shows
      Settings and Tutorial. ⚠️ A scene change would have torn down the live 3D
      backdrop and, on a client, the ENet connection and the whole lobby board,
      behind a panel about to be closed. **Its content is untouched** — only the
      two exits changed, from `change_scene_to_file` to a `closed` signal.
- [x] **3.3's kit half** — see that item. The picker was appearance-only; lata
      and tsinelas entries now carry the ability that skin brings.
- [x] **Single Player starts on confirm.** ⚠️ **The in-MATCH ready prompt is
      untouched** — `main.gd`'s `_awaiting_local_ready` / "3 · 2 · 1 · GO" beat
      still runs. What went is the *second*, redundant ready in a waiting room
      with nobody to wait for.
- [x] **Seats are chosen, exclusive and refereed.** Team and role used to come
      from connection order alone (`_next_join_index`), which no player could see
      or influence. A seat is still exactly the old join index, so nothing
      downstream needed touching; only who decides the number changed. The host
      is the sole writer, so two peers clicking one seat cannot both get it.
      Connection order survives as the fallback for `--host`/`--join` runs and
      mid-match late joiners.
- [x] **Solo seat selection**, which is what makes the character pick mean
      something in Single Player. ⚠️ Needed a real fix: only player_id 1 and 2
      are bound to keys, so a human dropped into Team B would have had a
      character they could not move. `_give_human_player_one()` swaps ids rather
      than reassigning, keeping all four unique and both unbound ones in AI
      hands. The solo picks also follow the chosen seat now — Prop skins onto a
      Prop, the Person pick onto a Person, which matters more than it did before
      because a skin now carries a kit.
- [x] **A real bug fixed in passing:** the old address placeholder read
      `192.168.1.12:7777`, but the string went straight to `create_client()`,
      which takes host and port separately and does not parse a colon. **Anyone
      who typed the format the placeholder demonstrated got a silent failure.**

**How it was verified — and what was NOT.**

- **`tools/lobby_probe.gd` is new**: two real instances over loopback, 21
  assertions, both exiting 0. It covers the client taking the host's map and mode
  (started on deliberately *opposite* values, so a pass cannot be both sides
  defaulting to the same thing), the client's arrows being locked, a seat request
  refused when occupied and granted when free, the START gate holding, and — after
  the scene change, which is why it is a `SceneTree` script — both peers reaching
  `Main.tscn` on the host's map with the seat each chose.
- **`tools/render_probe.gd`'s `lobby` mode is now `setup`.** It asserted Single
  Player's START was disabled until READY. That assertion is not stale, it is
  *inverted* — removing that gate is the point.
- **Audio: all 25 controls across the three setup screens** were checked to carry
  both a press and a hover path. The audit found a real gap it was not looking
  for: the character panel had click on every control and hover on none. Fixed.
- **Smoke gate green**, including the conditional audio seventh (25 checks, 0
  failures). Step 3 produced no output.
- ⚠️ **NOBODY HAS CLICKED ANY OF IT.** Every claim above is a probe result or a
  render. `[~]`, not `[x]`, for that reason and no other.
- ⚠️ **Not covered:** a four-peer lobby, a mid-lobby disconnect, and the new
  kit-per-skin mapping's effect on balance — that last one belongs to the Phase 9
  fairness log and has not been measured.

**One deliberate cross-lane edit, recorded rather than hidden.**
`scripts/ui/ui_theme.gd` is 🎨 Design's file and §10 says to file a defect rather
than fix it. Its header named `GameSetup.tscn` and `Lobby.tscn`, which this pass
deleted, and §12.6 requires references to deleted things be rewritten. The names
in that one historical sentence were corrected — **no colour, no variation and no
styling was touched.** No second lane was running to hand it to.

**No `SHARED_LOCKS.md` claim was taken for `scenes/ui/*.tscn`.** The lock's mutex
is a push to `integration`, and no second lane was running to lose a race to.
`project.godot` was not touched at all.

### 10.5.1 · The setup screen's layout, made a constraint instead of a guess `[~]` — render-verified, still not played

**Executed 2026-07-29**, off a screenshot of 10.5's result. Three items, one of
them a real layout defect and two of them wording.

- [x] **The two panels overlapped in the build.** 10.5 placed both at absolute
      offsets — config at x 83..946, roster at x 1000..1820 — which is correct
      right up until a string grows. **A Control's size is clamped UP to its
      combined minimum size**, so when the PLAYERS button's label reached its
      real length ("BERTO · SARSILYA · TSINELAS NA GOMA ▸" — three roster names,
      and the roster is data, not a constant), the button widened, the row
      widened, and `ConfigPanel` grew straight through its own `offset_right`
      and under `SeatPanel`. Nothing in that chain could push back: **absolute
      offsets are a starting guess, not a constraint.**
      Now `Body` (MarginContainer) → `Columns` (HBoxContainer, separation 54) →
      two VBox columns, both `EXPAND|FILL` at the same stretch ratio with
      `custom_minimum_size` floors of 960 and 700. The worst a long string can do
      is squeeze its own column to its floor; it cannot reach into the other one.
      The strings that grow unpredictably — the PLAYERS button, the roster rows,
      the map/mode values — carry `clip_text` + an ellipsis overrun so their
      preferred width stops driving layout at all, and every descriptive Label
      (`DetailLabel`, `SeatHint`, `StatusLabel`) is `autowrap_mode = 2` inside a
      VBox, so it grows *downward* into reserved space rather than sideways into
      a button. `BackButton` is pinned to the bottom by an expanding Spacer
      instead of by a y offset.
      ⚠️ `Banner` and `CharacterSelectPanel` are still hand-placed **on purpose**
      — one bleeds off the left edge, the other is a full-screen overlay. Neither
      belongs in the column flow.
- [x] **"bot" → "BOT"** in the roster rows, both the solo and the unclaimed-seat
      branch of `_seat_row_text`. It sat in lowercase next to `TEAM A · PROP` and
      read as a footnote rather than as the roster entry it is.
- [x] **"SEAT" → "CHARACTER" in everything the player reads.** The heading, the
      hint under it in all three branches (solo/host/join), the detail line, and
      the two contention messages. **The code still says `seat` everywhere** —
      variables, RPCs, `_peer_seats`, the node names — and deliberately so: a
      seat is exactly `main.gd`'s join index (team = `seat / 2`, even = Person),
      and renaming the concept to match the label would have desynced the board
      from the spawner for a word.

**How it was verified.**

- `tools/ui/matchsetup_shot.tscn` at 1920×1080, both maps — the real screen, real
  roster names, scrim and live 3D backdrop included. The gutter between the
  panels measures 54 px and the PLAYERS label is no longer trimmed.
- A throwaway `SceneTree` probe printed the laid-out rects at the design
  resolution: `LeftColumn` 83..1043, `RightColumn` 1097..1824, `Rect2.intersects`
  false. Re-run with both pennants visible and the longest lobby strings — the
  tallest state the screen has — `BackButton` still lands above 1080.
- ⚠️ **What backs this entry is renders and rect arithmetic**, same as 10.5 — no
  probe here drives input. `[~]` for that reason.
- ⚠️ ~~**Not covered:** any resolution other than 1920×1080.~~ **Addressed in
  10.5.2, and the first attempt at it was fake — see B-142.** A second *aspect*
  (21:9) is now measured; a second *pixel count* at the same aspect turns out to
  be a no-op under `stretch/aspect="expand"`.

### 10.5.2 · The character-select backdrop, and the resolution claim that was not one `[x]`

**Executed 2026-07-30**, 🖥️ UX lane, branch `ux/onboarding-readability`. Both items
are render-verified — the PNGs were opened and looked at, which is the only
acceptance test for either of them.

- [x] **A real backdrop behind the character** — B-141, reported from play
      (*"or its just blue"*). It was one flat `#161F35` fill from the preview
      `Environment`'s `BG_COLOR`, and an opaque `SubViewport` meant the backdrop
      nodes already in the scene could never have shown. Now
      `transparent_bg = true` + `background_mode = 0`, with a `Backdrop`
      (vertical `GradientTexture2D`, PANEL-haze → INK floor) and a `BackdropGlow`
      (`FILL_RADIAL`, neutral PANEL ≤0.30 alpha, `fill_from` in **UV** so it
      tracks the figure's screen fraction as the viewport grows) as the root's
      first two children. **Textures, not a shader.** Light-at-top so the dark
      hair reads against the light end and the pale shoes against the dark one.
- [x] **The overlay case, which no probe covered.** `MatchSetup.tscn` instances
      `CharacterSelect.tscn` as `%CharacterSelectPanel` over a **live 3D map
      render**, and the panel's opacity used to come from exactly the flat fill
      that was removed. New `tools/ui/charselect_overlay_shot.tscn` opens the
      panel through its own button and shoots all three tabs — the map does not
      show through. Every pre-existing probe loads `CharacterSelect.tscn`
      standalone, where there is nothing behind it to leak.
- [x] **The "second resolution" was the 1080p pass twice** — B-142. The probe
      banner said `1280 x 720` and the next line said `viewport 1920x1080`, with
      every rect identical. Under `stretch/aspect="expand"` the content rect
      follows **aspect**, not pixel count, so a same-aspect window cannot change
      it. Second preset → `2560x1080` (21:9), plus a **`SAME CONTENT RECT`**
      assertion so this cannot recur silently. **44 assertions pass** across
      16:9 + 21:9.
      ⚠️ **The new assertion was proven to fire, not just to pass**:
      `-- "" 1920x1080,1280x720` gives `FAIL — 1 of 44`. An assertion that has
      only ever passed is untested.
      ⚠️ **`expand` only ever grows the content rect** (4:3 lays out `1920x1440`),
      so nothing can be pushed off the **right** edge and **16:9 stays the
      tightest case vertically** — which is why R-09's 7px `BackButton` overflow
      showed only at 1080p.

### 10.5.3 · R-27 onboarding, and the HUD moved onto the front end's own theme `[~]`

**Executed 2026-07-30**, 🖥️ UX lane. Render-verified — every claim below was checked
by opening the PNG.

- [x] **R-27(a) · the premise card, in front of the eight reference pages.** Page 1 is
      four pictures and twelve words: LATA/can · TAYA/guard in defence blue,
      TSINELAS/slipper · TAKBO/run in offence orange, over a four-word lede. The
      colour rule is taught by being used, like the vocabulary. The pictures are the
      **real can, slipper and person rigs** through `CharacterPreview` — there is no
      icon art in `assets/ui/` and drawing four pieces of it is ART's call, but the
      real rigs mean the card cannot go stale when a model is reskinned. New
      `scenes/ui/PremiseIcon.tscn`. The eight reference pages are unchanged.
      ⚠️ Tile height is a **stretch flag, not a number** — 210 stranded the strip at
      the top of an empty panel, 330 clipped the gloss and raised a scrollbar, and a
      card you have to scroll cannot be read at a glance.
      ⚠️ The confinement radius still has **no number** (GDD 3 vs `CONFINEMENT_RADIUS`
      5.0) — page 3 still describes the rule. Unchanged on purpose.
- [x] **R-27(b) · the ready phase says what your job is.** It previously said only how
      to start the round. `hud.gd` **derives** the objective from `you_card`'s local
      character plus `MatchManager.team_a_is_can` rather than taking it as an argument,
      because `main.gd` owns all four call sites and is not this lane's file. Blank when
      the role cannot be established — a late-joining peer reaches the ready phase
      before its character spawns.
      **Both states rendered and measured**, `tools/ui/ready_objective_shot.tscn`:
      `0080e8` / "GUARD THE LATA.  TAG THE THROWER." and `f87020` / "KNOCK THE LATA
      DOWN". ⚠️ That probe's own limit is in its header — it flips `team_a_is_can`, which
      the team cards follow but the YOU card does not.
- [~] **B-143 · the HUD restyled onto the menu's wood-and-amber language.** Reported as
      *"ugly and plain and confusing"*. Built from `UiTheme.wood_style()`, the same call
      the menu's `WoodSlot` uses. Two real defects fixed inside the "confusing" half: an
      **unwon score pip was drawn at alpha 0** (invisible empty state — the readable half
      of the older "boxes remain empty" report, which only ever fixed the fill), and
      **team identity was a single character mid-string at body size**, leaving hue doing
      the letter mark's job against §4.2. Letter is now its own 48px amber glyph.
      `[~]` because **`RoleSwapCard` and `MatchResult` are still on the old face**, and
      because the overrides are per-node in code — the `Hud*` variations live in
      `ui_theme.gd`, which is ART's file. 🩴 **Filed for ART to promote.**

### 10.5.4 · R-29 · the intermission says WHY, and REMATCH is the default `[x]`

**Executed 2026-07-30**, 🖥️ UX lane. New probe `tools/ui/intermission_shot.tscn` drives
the real replicated signal off `Main.tscn` and prints the word each case resolved.

- [x] **The round-end reason, in display type on `RoleSwapCard`.** The intermission said
      only who won, so losing to the clock and losing to a tag looked identical.
      **All four cases rendered and asserted:** `TAGGED` / `TIME` in defence blue
      (`0080e8`), `LATA DOWN` / `DENTED` in offence orange (`f87020`) — the reason takes
      the colour of the side it favoured.
      ⚠️ **CLASSIFIED AT `round_intermission_started`, NOT AT `round_won`, and the brief's
      instruction to use `round_won` would have shipped a host-only feature.**
      `RoundManager.report_round_win()` early-returns on a client, so **`round_won` never
      fires on a client** and the reason would have been blank for every non-hosting peer.
      The intermission broadcast is the replicated one — the same reasoning
      `hud.gd::_on_round_intermission_audio` already documents for its fanfare. The state
      it needs is valid there too: `report_round_win()` RPCs `_sync_state(time_left, …)`
      on the line *before* it emits, so every peer has the ended round's final `time_left`
      first, same host frame, same ordered reliable channel.
      ⚠️ **RING-OUT ×3 READS AS `TAGGED`** — `register_ring_out()` calls
      `report_round_win(true)` exactly as a tag does and nothing records which clause
      fired. Not wrong (the can side did win by punishing the attacker) but not specific.
      A real fix needs the reason on the signal, which is 🥊/🌐's call, not this lane's.
      ⚠️ **No new tween beat**, so the §4.6 timeline is untouched — the reason is raised at
      0.0s alongside the winner line and nothing races the 3.0s world reset.
- [x] **REMATCH takes focus on `MatchResult`**, so Enter is the fast path back into the
      game. ⚠️ **Falls back to MAIN MENU when REMATCH is hidden** — it is hidden on a
      client (`begin_next_round()` is host-gated) and `grab_focus()` on a hidden Control
      does nothing, which would have left the screen with no focus and keyboard navigation
      dead. Verified: probe reports `focus=RematchButton`.
- [x] **Both screens moved onto the wood face** (B-143's third pass), buttons included.

## Phase 9 · AI FAIRNESS LOG — the running record for balance testing

**Human call, 2026-07-29:** *"Make sure the AI's fulfil their roles as well and try to win (attacker
avoid defender, defender try to tag, etc), log somewhere that we will test fairness thru this and
make changes accordingly."*

**This section is the log.** It is where AI balance findings go, and it is deliberately a *running*
record rather than a one-off writeup — the whole point is that the numbers move as the AI and the
mechanics change, and that nobody has to re-derive last week's result.

### How fairness is measured

`tools/ai_probe.gd` is the harness, and as of 2026-07-29 it has the balance mode as well as the
original independence one — extended, not replaced, per this section's own instruction.

```bash
# Independence / freeze audit (unchanged; every older number in this doc came from this).
godot --path . tools/ai_probe.tscn

# Balance. Plays whole AI-vs-AI matches back to back and self-scores against the table below.
godot --path . tools/ai_probe.tscn -- fairness rounds=20 scale=6

# Same, sweeping the Taya's pursuit radius. ⚠️ NOT THE LEVER — corrected 2026-07-30. RUN 8 swept it
# at 0.0 / 1.8 / 3.6 on an honest four-bot field and all three rows are within noise of each other.
# It decides HOW the defence wins, not THAT it wins. The comment here used to call it "the lever".
godot --path . tools/ai_probe.tscn -- fairness rounds=20 scale=6 pursue=0
```

```bash
# The standoff sweep. ⚠️ NOT THE LEVER EITHER — corrected 2026-07-30 by RUN 9, which swept it at
# 1.0 / 1.4 / 1.8 / 2.2 / 2.6 / 3.2 / 3.8 and got DEF 100% and <= 0.10 dents at every value. What it
# does decide is ROUND LENGTH, non-monotonically: outside 2.2-2.6 a round is over in ~2s.
godot --path . tools/ai_probe.tscn -- fairness rounds=20 scale=4 standoff=1.4

# R-07's two knobs, and R-09's tiers — no tier but NORMAL had ever been measured before `tier=`
# existed, because nothing outside AIController called apply_difficulty().
godot --path . tools/ai_probe.tscn -- fairness rounds=20 scale=4 posthold=0.5 repost=0.5
godot --path . tools/ai_probe.tscn -- fairness rounds=20 scale=4 tier=BATA

# R-08's three round-win variants, imposed from the probe and never from hitbox.gd.
godot --path . tools/ai_probe.tscn -- fairness rounds=20 scale=4 tag=control|slipper|inside

# R-21's position heatmap (ASCII grid + a PNG), and bt_trace() at every throw.
godot --path . tools/ai_probe.tscn -- fairness rounds=20 scale=4 heatmap trace

# R-02's acceptance test: break one honesty assertion on purpose and watch the run refuse.
godot --path . tools/ai_probe.tscn -- fairness rounds=2 scale=8 break=park|map|swap
```

⚠️ **`--headless --path <abs> --import` FIRST, on any fresh checkout.** A map whose `.obj` meshes
have never been imported loads with `Parse Error: [ext_resource] referenced non-existent resource`
and the probe runs anyway, producing a complete and wrong table. See RUN 9.

⚠️ **Never `--headless`**, same rule as smoke-gate commands 3 and 4. ⚠️ **The fairness mode attaches
a fourth `AIController` to `TeamAPerson`**, the slot `main.gd::_start_local_test()` leaves for the
human — without that, whenever Team A is on offence its Attacker is a unit that never moves and the
defence wins for free. It also flips that unit's `CameraRig` off `MOUSE` aim (B-60).

The measurements that matter:

| Metric | Why | Fair range |
|---|---|---|
| **Round win rate, attacker vs defender**, over ≥20 rounds | The single number that says whether the sides are balanced at all | 40–60% either way |
| **Time-to-first-throw** | An attacker that dithers is not "hard", it is broken | < 8 s |
| **Throws blocked by the Taya / throws taken** | Is body-blocking doing anything, or is it decoration? | 25–50% |
| **Can dents per round** | Rounds that never resolve are a worse failure than an unfair one | ≥ 1 on most rounds |
| **Longest still-run per bot** | A frozen bot is not a difficulty setting | < 2 s |

⚠️ **A win rate on its own is not a fairness result.** A 50% split where neither side ever scores
and every round times out is not balanced, it is broken twice. Always read it next to dents-per-round.

### The role logic is a behaviour tree now (2026-07-29)

`ai_controller.gd`'s four `_update_<role>(repick, delta)` procedures are gone. The same logic is a
reactive behaviour tree — `BTSelector` / `BTSequence` / `BTCondition` / `BTAction` as inner classes
in that same file, ~80 lines, no addon — built once in `_ready()` and ticked once per `decide()`.
`decide(delta)` is still the entry point and is still called as the first line of
`CharacterBase._physics_process`; nothing outside `ai_controller.gd` changed.

Three things this bought, in the order they mattered:

1. **The role swap is structural, not remembered.** The role fork is a `Selector` over four
   conditions re-evaluated every tick, so the per-round `is_can`/`team_is_can_side` flip needs no
   cooperation from anything.
2. **`AIController.trace_enabled = true` gives you the branch path per tick** via `bt_trace()` —
   e.g. `role/attacker/throw/reposition*` (`*` = RUNNING). Both findings below were found with it
   inside an hour; the equivalent in four nested `if` chains was reading control flow by eye.
3. **Method names are validated at build time** (`_validate_tree()`), so a leaf dispatching a
   typo'd name is one `push_error` at startup rather than a per-frame runtime error.

⚠️ The tree is **reactive — no node memory.** Every tick starts at the root. `RUNNING` propagates and
stops sibling evaluation for that tick, but never pins the tree to a subtree across ticks. That is
what lets a Can pre-empt its own hold-the-circle behaviour on the exact frame a throw becomes a
threat.

### Role intent as implemented (2026-07-29) — what "trying to win" currently means

- **Taya (defending Person): BODY-BLOCKS, and now pursues inside `taya_pursue_radius`.** It used to
  walk straight at the attacker, which the geometry forbids it from ever reaching — the Taya is
  capped at `CONFINEMENT_RADIUS` 5.0 and the attacker throws from the 6.0 line, so chasing parked it
  against the inside of its own box with the can left unguarded behind it. It stands on the line
  between the can and the attacker at `TAYA_BLOCK_STANDOFF` (2.6) and closes to melee only when the
  threat is inside `taya_pursue_radius`.
  ⚠️ **That pursuit condition is new and it is the balance lever — read the findings below before
  touching it.** The old code's comment claimed it chased "only when the threat is already INSIDE
  the box", but nothing ever tested that; the condition had never actually run.
- **Attacker (offensive Person): AVOIDS THE DEFENDER.** It checks whether a defender is sitting in
  the throwing lane (perpendicular distance to the attacker→can line under `ATTACKER_LANE_CLEARANCE`
  1.3) and, if so, slides around the can to the nearest open bearing instead of charging into the
  block. Bearings are sampled outward from the one it already holds, so it edges around rather than
  teleporting its intent to the far side each tick.
- **Can:** holds its circle (`CAN_HOLD_RADIUS` 0.45). Deliberately does not wander — a can that
  strolls off its mark has nothing left to defend and made round resets look like teleports.
- **Tsinelas:** crawls toward its own attacker so the two meet, rather than the attacker crossing the
  whole gap alone.

### RUN 1 — 2026-07-29, the first balance numbers this project has ever had

Harness: `tools/ai_probe.gd -- fairness rounds=20 scale=6 pursue=<r>`, 4 AI units, **Option A**,
default map. 20 rounds per row, all rendering (never `--headless`).

| `pursue=` | Round win rate | 1st throw | Throws taken | Blocked | **Reached the can** | **Dents/round** | Ended by tag | Timed out | Longest still-run |
|---|---|---|---|---|---|---|---|---|---|
| **0.0** (pure body-block, = pre-BT behaviour, **the shipping default**) | DEFENCE **100 %** | 0.6 s | 20 | 0 | **0** | **0.00** | 12/20 | 8/20 | 23.62 s |
| **2.0** | DEFENCE **100 %** | 0.7 s | 20 | 0 | **0** | **0.00** | 10/20 | 10/20 | 30.87 s |
| **5.0** (the confinement box) | DEFENCE **100 %** | 0.7 s | 20 | 0 | **0** | **0.00** | 20/20 | 0/20 | 2.02 s |

**Read the dents column first, exactly as this section's own warning says.** The win rate is not
the finding. The finding is that **the offence has never won a round, no throw has ever reached the
can, and no can has ever been dented by an AI attacker** — and that "20 throws over 20 rounds" is
not a coincidence, it is **exactly one throw per round, every round, at every setting.** The three
rows differ only in *how* the defence wins and how long the round drags first.

⚠️ **These are Option A numbers and that is load-bearing.** `GameLaunch.game_mode` defaults to
OPTION_B, where `dents` is never written at all, so a fairness run on the default reports
"0.00 dents" no matter how well the attacker plays. The first pass of this run was made on the
default and its dents column measured nothing — the same trap Handoff.md records under B-118.
`ai_probe.gd` now forces OPTION_A for a fairness run and prints the mode next to the dents row;
pass `mode=b` to measure Option B deliberately.

⚠️ **No row here is a balance result and none of them should be used to tune anything.** They are the
measurement that found two structural bugs, both of which predate the behaviour-tree pass:

1. **B-124 · THE ATTACKER AND THE TAYA LIVELOCK. THE ATTACKER GETS EXACTLY ONE THROW PER ROUND.**
   Measured directly off `bt_trace()`: from the moment it re-acquires the slipper (t = 1.4 s) to the
   end of a 40 s observation, the attacker sits in `role/attacker/throw/reposition` — *lane blocked
   → slide to the nearest open bearing* — and never once reaches `charge-release`. It orbits the can
   at r ≈ 4–5 holding the slipper; the Taya body-blocks at r ≈ 2.5 and re-derives its post from the
   attacker's *current* bearing every tick, so the lane is blocked again the instant the attacker
   arrives anywhere. They rotate together indefinitely. `_blocking_defender()` and
   `_open_throwing_spot()` are both unchanged from before the BT pass — this is not a refactor
   regression, it is a bug the refactor's trace made visible. The one throw every round does get is
   the opening one, at ~0.6 s, before the Taya has reached the lane at all. **Fix candidates, none
   implemented:** a patience timer that throws into a blocked lane anyway after N seconds; requiring
   the block to persist before believing it; sampling the open bearing relative to the *Taya's* post
   rather than the attacker's own.
2. **B-125 · THE AI ATTACKER NEVER AIMS AT THE CAN.** `carrier.gd::_aim_direction()` takes the throw
   direction from the CameraRig, which for a non-mouse-aimed unit follows the body, and the body's
   yaw is written by `character_base.gd`'s `look_at(global_position + direction)` — i.e. **the
   direction it last pressed movement in.** The attacker's charge leaf deliberately stands still
   (`_release_move()`), so it throws along whatever bearing it last *walked*, never at the can. This
   is why "reached the can" is 0 even for the one throw per round that does happen. Not fixed here:
   aiming is outside the refactor's scope and the obvious fix (press toward the can for a frame to
   set facing) quantises to the 8 keyboard compass directions, ±22.5°, which at 5.5 units is a
   ±1 unit miss. Wants a real decision, not a patch.

Also measured, and it corrects a stale claim in this doc and in `Handoff.md`: **the longest
still-run figure of "1.1 s" is no longer true and has not been for a while.** The Can holds a
`CAN_HOLD_RADIUS` of 0.45 while `ARRIVE_DISTANCE` is 0.6 — the deadzone is *wider than the circle*,
so the Can never moves at all unless it is evading. A/B'd against `origin/integration`'s own
`ai_controller.gd` on the same seed, which scores **worse** (10.50 s vs 6.73 s), so this is not a
refactor regression either. Independence itself is unchanged and still good: 1/843 frames with two
bots changing state together (the recorded figure was 1/846). The 20–30 s still-runs in the table
above are the livelock of B-124, not this.

**`taya_pursue_radius` ships at 0.0**, which reproduces the pre-behaviour-tree Taya exactly, so the
refactor is behaviour-neutral by default. The pursuit branch the BT adds is implemented and one
assignment away; it is off because the table above shows it changes *how* the defence wins without
changing *that* it wins, and a refactor should not smuggle in a balance change.

### RUN 2 — 2026-07-29, after B-124, B-125 and B-132. The first numbers that mean anything.

Same harness, same 20 rounds, `scale=6`, Option A, `taya_pursue_radius 0.0`.

| Metric | RUN 1 | **RUN 2** | Fair range | |
|---|---|---|---|---|
| Round win rate | DEFENCE 100% | **DEFENCE 85% / OFFENCE 15%** | 40–60% | still out |
| Time-to-first-throw | 0.6 s | **0.8 s** | < 8 s | OK |
| Throws taken | **20** (exactly 1/round) | **91** | — | |
| Throws blocked | 0 (0%) | **41 / 91 = 45.1%** | 25–50% | **OK — first time ever** |
| Throws that reached the can | **0** | **7** | — | |
| Dents per round | 0.00 | **0.50** (4/20 rounds) | ≥ 1 | still out |
| Rounds timed out | 8/20 | **0/20** | — | |
| Longest still-run | 23.62 s | **4.18 s** | < 2 s | still out |

**Three bugs closed, and each one was hiding the next.**

1. **B-124 · the livelock is gone.** `_cond_lane_blocked` now runs an `ATTACKER_PATIENCE` (2.0 s)
   timer and reports the lane clear once it expires, so the attacker takes a contested shot instead
   of orbiting forever. Throws went 20 → 91 and timeouts 8 → 0.
   ⚠️ The timer must be **reset on release**, and the first attempt did not: it only cleared when the
   lane genuinely opened, so after one impatient throw the attacker stopped repositioning for the
   rest of the round and spammed on a 0.65 s cycle — 503 throws over 20 rounds with a 1% block rate,
   one livelock traded for another.
2. **B-125 · the attacker aims at the can now.** `CharacterBase.ai_aim_point`, written by the charge
   leaf and read by `carrier.gd::_aim_point()`, which otherwise ray-casts from a camera that follows
   the body — i.e. the direction the unit last *walked*.
3. **The can dodges, and the AI now leads it.** Measured in phys_probe: the can moves on **56% of
   in-flight frames**, up to **1.41 m** off its mark. Aiming at where it *is* missed nearly every
   time, which is why "reached the can" stayed at 0 even after B-125 was fixed. `CAN_LEAD_FRACTION`
   (0.6) leads by the can's own velocity over the estimated flight time. Leading rather than nerfing
   `CAN_EVADE_*`, because a human-driven can dodges too.

⚠️ **A metric was lying, and two columns of the same event disagreeing is what caught it.**
"Reached the can: 0" sat next to "dents 0.60" for three consecutive runs, which is impossible.
`ai_probe` connected to hitboxes once at setup and so never saw the **per-throw pulse hitbox**
`_spawn_flight_hitbox()` creates inside `host_throw` — the one most throws actually resolve on.
Re-armed per flight, as `phys_probe` has been since the multi-hit work. This is trap 2 in this
document's own method note, found in this document's own harness.

### ⚠️ Still open

Three of five ranges are still unmet, and the shape of what is left has changed completely — this is
now a **tuning** problem rather than a structural one, which it was not before RUN 2.

- **Win rate 85/15.** The defence still wins, but by tagging (17/20) rather than by the offence being
  incapable. `TAYA_BLOCK_STANDOFF` (2.6, "a first guess") and the attacker's total lack of evasion
  are the two obvious levers — fairness item 3 notes the attacker never dodges an incoming tag, and
  85% of rounds now end exactly that way.
- **Dents 0.50/round.** Throws reach the can now but rarely dent it. See the human's own question,
  *"can the can even fall?"* — measured, 9/12 clean hits in `phys_probe` produced 0 dents under
  Option B (which never writes `dents` at all) and staggers rather than knockdowns. The knockdown
  threshold itself is the next thing to look at, not the aim.
- **Longest still-run 4.18 s.** Down from 23.62 s, so no longer a livelock, but still above 2 s.

`CAN_LEAD_FRACTION` and `ATTACKER_PATIENCE` are both difficulty knobs and belong in the tiers
fairness item 6 asks for, alongside `DECISION_INTERVAL` and `ATTACKER_LANE_CLEARANCE`.

### RUN 3 — 2026-07-29, the square confinement. A correctness fix with a balance cost.

`_move_and_confine()` clamped a CIRCLE while both map builders drew a SQUARE, so at the corners the
chalk promised 7.07 units and the physics stopped the player at 5.0. The square is now the real one
(human call). Measured either side, same harness, nothing else changed:

| Metric | RUN 2 (circle) | **RUN 3 (square)** | Fair |
|---|---|---|---|
| Round win rate | DEF 85% / OFF 15% | **DEF 90% / OFF 10%** | 40–60% |
| Throws blocked | 41/91 = **45.1%** (in range) | **55/103 = 53.4%** (over) | 25–50% |
| Reached the can | 7 | **4** | — |
| Dents per round | 0.50 | **0.30** | ≥ 1 |
| Longest still-run | 4.18 s | **6.83 s** | < 2 s |

**The defence got stronger, and that is the expected direction, not a surprise.** A square of
half-width 5.0 has 4/π (~27%) more area than a circle of radius 5.0 and gives the Taya up to 2.07
extra units of reach on the diagonals — so it body-blocks more, which is exactly what the numbers
say. Block rate went from inside the fair range to just above it.

⚠️ **Do not "fix" this by reverting the shape.** The circle was a bug: the marker on the floor is
the boundary the player reads, and it was lying by 2.07 units at every corner. What this run says is
that the Taya now needs a compensating nerf to land back in range — `TAYA_BLOCK_STANDOFF` (2.6, and
documented as "a first guess") is the obvious lever, and it is the one that was always going to need
measuring once somebody actually played the box.

Known things that will probably need retuning once that is done, recorded now so the next run has
hypotheses to check rather than starting cold:

1. **`TAYA_BLOCK_STANDOFF` 2.6 is a first guess.** Too small and the Taya hugs the can and blocks
   nothing; too large and it leaves a gap behind itself.
2. **`ATTACKER_CHARGE_TIME` 0.65 is fixed**, so every AI throw has identical power. A human varies
   it. If the AI reads as robotic, this is why.
3. **The attacker never dodges an incoming tag** — it only avoids *standing in a blocked lane*.
   Real evasion is a separate behaviour and is not implemented.
4. **`DECISION_INTERVAL` 0.35 jittered 0.75–1.3×** sets reaction time and is the obvious global
   difficulty knob if the bots turn out to be too sharp or too dull.
5. **Can evasion (`CAN_EVADE_*`) is now the biggest single balance lever.** A
   measured sweep showed the difference between "dodges everything, game
   unwinnable" and "never dodges" is about 0.3s of lookahead. Shipped values sit
   deliberately on the hittable side. Re-measure the moment real win-rate numbers
   exist — this is the first thing that will need moving.
6. **No difficulty tiers exist.** If fairness testing says the AI is too strong for a demo, the fix
   is a tier that scales `DECISION_INTERVAL` and `ATTACKER_LANE_CLEARANCE`, not one-off nerfs.
   ⚠️ **STALE AS OF 2026-07-30, kept as the record of when it was true.** `DIFFICULTY_TIERS` and
   `apply_difficulty()` now exist in `ai_controller.gd` and carry `pursue` / `lead` / `think` /
   `charge`. Nothing outside that class calls them, no screen offers them, and no tier but NORMAL
   has been measured — so the *mechanism* is built and the *feature* is not. See "Still open after
   RUN 8" below.

### RUNS 4, 5 and 6 — 2026-07-29. Attacker evasion, and the one negative result worth keeping.

Same harness, 20 rounds, `scale=6`, Option A, `taya_pursue_radius 0.0`. Three runs, because RUN 5 is
a **measured regression** and deleting it would leave the next person free to make the same change.

| Metric | RUN 3 | RUN 4 | RUN 5 | **RUN 6** | Fair |
|---|---|---|---|---|---|
| Round win rate | DEF 90% | DEF 90% | DEF **100%** | **DEF 85% / OFF 15%** | 40–60% |
| Throws taken | 103 | 66 | 67 | **81** | — |
| Throws blocked | 53.4% | 56.1% | **67.2%** | **50.6%** | 25–50% |
| Reached the can | 4 | 4 | **0** | **6** | — |
| Dents per round | 0.30 | 0.30 | **0.00** | **0.45** | ≥ 1 |
| Longest still-run | 6.83 s | **1.92 s** | 1.07 s | 3.05 s | < 2 s |
| Ended by tag | 18/20 | 18/20 | 20/20 | 17/20 | — |

**RUN 4 — B-134, B-135 and B-137 landed; no evasion yet.** The headline is the still-run:
**6.83 s → 1.92 s, inside the bar for the first time this project has measured it.** That is B-137's
signature, not a coincidence — the slipper's hurtbox was staying non-monitorable after any round that
ended in a tag, and `carrier.gd::_find_grabbable()` finds slippers by scanning for Hurtboxes, so the
attacker was standing next to a slipper it was unable to pick up. An attacker that cannot pick
anything up is precisely what a long still-run looks like. Everything else was flat, which is
expected: under Option A a hit on the Can was already a dent whichever hitbox resolved it, so B-134
does not move these numbers (it transforms Option B, where the can now falls on every clean contact).

**RUN 5 — attacker evasion, at top priority. ⚠️ A REGRESSION. DO NOT REDO IT.** Evasion pre-empted
*everything*, so an attacker holding a charged slipper ran away from the taya instead of throwing
it. The offence stopped functioning: win rate 90/10 → **100/0**, blocked 56.1% → **67.2%**, dents
0.30 → **0.00**, throws that reached the can 4 → **0**. Fleeing is only the right answer when there
is nothing better to do with the moment, and while holding the slipper there always is.

**RUN 6 — evasion gated on EMPTY-HANDED. The best configuration measured so far, and shipped.**
One extra condition on the same behaviour tree node, and four of the five metrics improve on RUN 4:

 - win rate **90/10 → 85/15**, the best since RUN 2;
 - block rate **56.1% → 50.6%**, back to the very edge of the fair range;
 - throws that reached the can **4 → 6**, dents **0.30 → 0.45**, throws taken **66 → 81**.

The gate is right on the merits as well as on the numbers: **the tag does not come from the throwing
line.** The taya is capped at `CONFINEMENT_RADIUS` and does not chase; it gets its tag when the
ATTACKER walks into the confinement box, which it must do to fetch a slipper that landed near the
can. Retrieval is the whole exposure, so retrieval is where the dodge belongs.

⚠️ **The still-run went the wrong way — 1.92 s → 3.05 s, back out of range.** Not root-caused. The
dodge itself is the obvious suspect (`_act_attacker_dodge` re-picks a break bearing every tick and
`_move_toward` releases input inside `ARRIVE_DISTANCE`, so an oscillation is plausible). Worth a
`bt_trace()` pass — that is how B-124 was found inside an hour.

### RUN 7 — 2026-07-29. The can's dodge nerfed, on a human call. Mixed, and kept.

`tools/hit_probe.tscn -- --host target=can` measured the thing nobody had measured: **aiming dead at
the can's own hurtbox centre, at full charge, only 12 of 40 throws made contact at all.** That made
the can's evasion — not aim, not spread, not the hitbox — the single biggest reason a throw misses.
Put to the human with the numbers; the call was **nerf the dodge.**

Done as `CAN_EVADE_MISS_MARGIN` **1.0 → 0.55**. ⚠️ The MARGIN, not the lookahead: at 1.0 the can
dodged anything passing within a metre, i.e. it spent most of its evasion budget on throws that were
going to miss anyway and sometimes sidestepped INTO them. 0.55 sits just above the real overlap band
for the tightest profile (hurtbox 0.17 + `throw_flick` hit_radius 0.30 = 0.47). **The lookahead is
not a tunable lever** — the sweep in `ai_controller.gd` is non-monotonic (1.10 → 18 contact frames,
0.85 → 57, 0.70 → 0). `CAN_EVADE_STEP` 1.2 → 0.85 was also tried, produced no change (15–16 contacts
against 15–17), and was reverted.

| Metric | RUN 4 | RUN 6 | **RUN 7** | Fair |
|---|---|---|---|---|
| Round win rate | DEF 90% | DEF 85% | **DEF 80% / OFF 20%** | 40–60% |
| Throws taken | 66 | 81 | **198** | — |
| Throws blocked | 56.1% | **50.6%** | 64.1% | 25–50% |
| Reached the can | 4 | 6 | **10** | — |
| Dents per round | 0.30 | 0.45 | **0.65** | ≥ 1 |
| Longest still-run | **1.92 s** | 3.05 s | 9.00 s | < 2 s |
| Ended by tag | 18/20 | 17/20 | **16/20** | — |

**Kept, because every metric the change was made to move, moved.** Contacts on a dead-centre throw
15–17 of 40 (from 12–14), throws that reached the can 4 → 10, dents 0.30 → 0.65, win rate 90/10 →
80/20 — all the best figures this project has recorded.

⚠️ **Two metrics went the wrong way and neither is root-caused. Do not stack another nerf on top
until they are.**

 - **Block rate 50.6% → 64.1%.** Partly arithmetic — throws went 81 → 198, so rounds now run long
   with the attacker throwing repeatedly into a taya parked in the lane. Whether that is the taya
   being strong or the attacker being repetitive is exactly what `TAYA_BLOCK_STANDOFF` (still
   unmeasured) would separate.
 - **Longest still-run 3.05 s → 9.00 s**, the worst since the B-124 livelock. This is the third run
   in a row where the still-run moved independently of everything else, and it now wants its own
   `bt_trace()` pass rather than another guess. Suspects, in order: `_act_attacker_dodge` re-picking
   a break bearing every tick, and the much longer rounds simply giving a stall more chances to be
   observed.

### RUN 8 — 2026-07-30. ⚠️ RUNS 1–7 ABOVE MEASURED A 3-v-4, AND RUN 8 IS THE FIRST THAT DID NOT.

**Read this before trusting any number in RUNS 1–7.**

`ai_probe.gd::_take_over_human_slot()` exists so the human's own Single Player seat is driven by a
bot too — without it the fairness table is measuring three bots and one statue. It found that seat
by testing `ai_controller == null`, which was correct while `main.gd::_start_local_test()` attached
controllers only to the three units the human was NOT playing.

On 2026-07-30 every unit started getting a controller, with the human's created **disabled** (see
`main.gd`'s note on *"only one AI person works at a time"*). The null test then matched nothing, the
takeover silently did nothing, **and the probe's own `AI units found: 4` line kept saying 4, because
it counts CONTROLLERS rather than asking whether anything is driving them.**

Measured consequence, before it was caught: every round in which that seat drew the ATTACKER
reported `0 throws` and was handed to the defence on the clock. That reads as a balance finding. It
is a broken harness. This is the repo's own trap 2 — *a probe that never LOOKS at the thing you
changed passes anyway* — and it is the second time that trap has cost this project a run.

Fixed by asking `is_enabled()` rather than `!= null`, clearing `input_parked`, and **printing the
number of genuinely AI-driven units every run with a `push_error` when it is not 4.** A future
change to how control is granted can now break this loudly instead of quietly.

**THE HUMAN-SLOT TAKEOVER IS TEST-ONLY. 🧑 Human ask, 2026-07-30: flag it for removal.** It exists
solely so AI-vs-AI fairness can be measured; nothing in the shipping game may depend on it. It lives
entirely inside `tools/ai_probe.gd`, is reached only from the `fairness` command-line mode, and
`tools/` does not ship — so removing it is deleting that one function and its one call site, with no
gameplay file touched. That is the same one-way-dependency rule `Dev_Plan.md` §0.3 sets for the debug
switcher, and it already holds here; it is written down now so nobody has to re-derive it.

#### What RUN 8 actually measured, on a real four-bot field

Three runs, 10 rounds each, Option A, scale 4, Eskinita. Only `taya_pursue_radius` differs:

| pursue | Round win rate | Throws blocked | Dents/round | Reached the can | Ended by tag |
|---|---|---|---|---|---|
| **0.0** (RUN 7's value) | DEF **100%** | **92.0%** | 0.10 | 1 | 10/10 |
| **1.8** (shipped) | DEF **100%** | **91.8%** | 0.00 | 0 | 10/10 |
| **3.6** | DEF **100%** | **90.5%** | 0.00 | 0 | 10/10 |

**Two conclusions, and the first one matters more than the second.**

1. ⚠️ **FAIRNESS IS WORSE THAN RUN 7 RECORDED, AND THIS PASS DID NOT CAUSE IT.** RUN 7 logged DEF 80%
   and 64.1% blocked; the baseline row above is the *same* pursuit value on today's `integration` and
   reads DEF 100% / 92.0%. Several commits landed between them (B-134/135/136, B-138, the attacker
   evasion runs). **RUN 7's table is stale and must not be quoted as current.** The open problem is
   the BLOCK RATE: the attacker throws into a taya parked in the lane and essentially never scores.
   `TAYA_BLOCK_STANDOFF` (2.6, still unmeasured, still not a `static var`) is now the single most
   obvious next lever, exactly as RUN 3 and RUN 7 both said.
2. Pursuit costs nothing measurable in either direction — the three rows are within noise of each
   other. That is consistent with `taya_pursue_radius`'s own doc ("this knob does not decide fairness
   today, it only decides HOW the defence wins"). It ships at **1.8** because the human asked for a
   defender that *actively tries to tag*, and at 1.8 the taya breaks off to chase only once the
   attacker crosses into the defended area to fetch its own tsinelas — which is the behaviour that
   was asked for, bought at no measured cost.

**Nothing in this pass claims to have balanced the AI.** It made the measurement honest and left the
number where it found it.

### RUN 9 — 2026-07-30. THE STANDOFF SWEEP, OWED SINCE RUN 3. It is not the lever, and the way it fails is the finding.

**R-01 and R-02 landed first**, so this is the first run in the log taken with the harness asserting
its own honesty rather than being trusted. Every row below printed
`honesty contract: PASSED` — four genuinely AI-driven units (asked with `is_enabled()`, never
`!= null`), Eskinita actually in the tree and compared against the scene the row claims, OPTION_A in
effect, and the attacking side changing hands across the run. All three assertions were also
deliberately broken to confirm they refuse; the three refusals are quoted in `git log` for
`d82b56d`.

⚠️ **ONE SETUP STEP THAT INVALIDATED THE FIRST ATTEMPT, RECORDED SO IT IS NOT RE-DISCOVERED.**
`cd9ecc2` (the eskinita dressing pass) added `.obj` meshes that had never been imported on this
machine, and `Eskinita.tscn` therefore loaded with `Parse Error: [ext_resource] referenced
non-existent resource` for every one of them. The probe ran anyway and produced a complete,
plausible, **wrong** table — rounds were about a third shorter than the real ones.
`--headless --path <abs> --import` is a precondition of a fairness run on a fresh checkout, exactly
as `Handoff_Physics_AI_LAN.md` says, and the numbers below are all post-import. The dressing itself
has no collision (Eskinita's only `StaticBody3D`s are `Floor` and the four `Bounds/Wall*`), so it is
not a physics confound — only an import one.

Harness: `godot --path <abs> tools/ai_probe.tscn -- fairness rounds=20 scale=4 standoff=<s>`,
Eskinita, Option A, four AI-driven units, 20 rounds per row, `taya_pursue_radius` at its shipped
1.8. **Only `taya_block_standoff` differs between rows.** Nothing but `ai_controller.gd`'s R-01
promotion has touched gameplay since RUN 8 was logged, so this is a clean comparison to it.

| `standoff=` | Round win rate | 1st throw | Throws taken | **Blocked** | Reached the can | **Dents/round** | Ended by tag | Timed out | **Avg round** | Longest still-run |
|---|---|---|---|---|---|---|---|---|---|---|
| **1.0** | DEF **100%** | 0.6 s | 20 | 60.0% | 0 | **0.00** | 20/20 | 0/20 | **2.4 s** | 1.38 s |
| **1.4** | DEF **100%** | 0.6 s | 21 | 61.9% | 0 | **0.00** | 20/20 | 0/20 | **2.6 s** | 2.48 s |
| **1.8** | DEF **100%** | 0.6 s | 35 | 77.1% | 0 | **0.00** | 20/20 | 0/20 | **4.4 s** | 2.35 s |
| **2.2** | DEF **100%** | 0.8 s | 221 | **94.1%** | 2 | **0.10** | 20/20 | 0/20 | **33.3 s** | 3.13 s |
| **2.6** (shipped) | DEF **100%** | 0.8 s | 188 | **94.7%** | 1 | **0.05** | 19/20 | 1/20 | **28.2 s** | 6.88 s |
| **3.2** | DEF **100%** | 0.6 s | 23 | 65.2% | 0 | **0.00** | 20/20 | 0/20 | **2.1 s** | 2.10 s |
| **3.8** | DEF **100%** | 0.6 s | 20 | 60.0% | 0 | **0.00** | 20/20 | 0/20 | **1.5 s** | 1.12 s |

**VERDICT, in the sentence R-05 asks for: `TAYA_BLOCK_STANDOFF` IS NOT A FAIRNESS LEVER, and the
number that says so is the dents column — 0.00 at five of seven values and 0.10 at its best, with
the defence winning 100% of rounds at every single value from 1.0 to 3.8.** There is no setting of
this knob at which the offence scores. Two runs and three documents have called it "the single most
obvious next lever"; it is now measured, and it decides how the defence wins, not whether. That is
the same shape as `taya_pursue_radius`'s own result in RUN 8, arrived at independently.

**But the SECOND finding is bigger than the first, and it is a mechanism rather than a number.**

**Read the dents column first, then read the AVG ROUND column, because that is where the response
lives — and it is not monotonic.** There is a narrow band, 2.2–2.6, where a round lasts ~30 seconds
and the attacker gets 10–30 throws. Outside it, in BOTH directions, **a round is over in about two
seconds and the attacker gets exactly one throw.** 1.0 and 3.8 produce almost identical tables from
opposite geometry, which is the tell:

- **At a SMALL standoff the taya is parked on the can** — which is exactly where the attacker's own
  slipper lands and where it must therefore walk to retrieve it. It is tagged on the way in, at
  ~2.4 s, every round.
- **At a LARGE standoff the taya walks out to its own wall.** `_act_taya_body_block` clamps the post
  to `CONFINEMENT_RADIUS - 0.4` = 4.6, and `_open_throwing_spot` puts the attacker at
  `ATTACKER_THROW_RANGE * 0.92` = 5.52. That is a gap of **0.92 units against a `TAYA_MELEE_RANGE`
  of 1.4** — the post is inside tagging distance of the throwing line, so the taya simply walks up
  and tags. At ~1.5 s, every round.
- **The middle band is the only place the taya is too far from the can to tag on retrieval and too
  far from the line to tag at the throw.** The shipped 2.6 is inside it, which is the only reason
  the game currently lasts long enough to look like a game at all.

⚠️ **THE HEADLINE ROW IS BIMODAL AND THE AGGREGATE HIDES IT** — §9's own warning, and it fires here.
"28.2 s average" at the shipped standoff is not what any round looked like. The per-round table is
two populations: **1.6–2.5 s rounds with one throw** (the attacker tagged almost immediately) and
**20–90 s rounds with 10–30 throws, every one of them blocked**. Nothing in between. A single
90.2 s round timed out having taken **30 throws, 30 blocked, 0 on the can**.

⚠️ **RUN 7's WARNING, HONOURED RATHER THAN QUOTED: two metrics move in opposite directions here —
block rate rises with the standoff while round length collapses at both ends — so this pass
ROOT-CAUSED IT INSTEAD OF STACKING A SECOND NERF.** The root cause is the two geometric collisions
above (post-on-the-can, and post-inside-melee-range-of-the-line), and it is not a tuning problem:
both of them end the round with a **tag**, which ends it **outright**. That is
[`Roadmap.md`](Roadmap.md) R-08's premise, and RUN 9 has now measured its mechanism rather than
inferring it. **Do not "fix" this by moving the standoff.** Every value away from 2.2–2.6 makes
rounds two seconds long, which is a worse failure than an unfair one.

**A cross-check, because a dents column that reads 0.00 seven times is exactly when a metric should
be doubted.** `tools/phys_probe.tscn -- target=can` on the same build: `RESULT: CONTACT RESOLVES`,
3 of 9 perfectly-aimed throws connected, one resolution per connecting throw. So the hitbox path is
alive and **33% is the ceiling for a completely unopposed, dead-centre throw** — the can's own
evasion eats the other two thirds (it moved on 40% of in-flight frames, up to 0.92 units). RUN 9's
`reached the can` values are consistent with that ceiling applied to the 5–6% of throws the taya
does not block: 13 unblocked throws at standoff 2.2 produced 2 hits. Two columns of the same event
agree, so the metric is not the bug this time.

**What this changes for the plan.** RUN 8 said the framing had to move from tuning to structural.
RUN 9 is the confirmation, from the other direction: the one knob everyone was waiting on has been
swept end to end and there is no value of it that makes the game fair. R-07 (a post that can be
wrong-footed) and R-08 (whether an instant-win tag is the imbalance) are now the whole of Stage 1's
fairness argument, and R-06's lob has a measured target to beat: **94.7% blocked.**

### ⚠️ RUN 9's NUMBERS WERE THE LAST ONES TAKEN ON A HARNESS THAT DISTORTED THE PHYSICS. Read this before comparing anything to them.

**Found 2026-07-30, after RUN 9 and before RUN 10.** `Engine.time_scale` does not make the
simulation run faster — it makes **each physics step cover more game time.** At the default 60
ticks/second and `scale=4`, one step is 4/60 = 0.067 s, so a unit at `SPEED` 6.0 **jumps 0.40 units
per step**; at the `scale=16` an exploratory sweep briefly used, 1.6 units per step — a body-width at
a time.

**How it was caught, because it looked exactly like an AI bug.** A new probe column reported the AI
*asking* for an aim point up to **3.1 units** from the can, when the aiming code cannot offset by more
than 1.65 (lead capped at 1.2, threading at 0.45). An impossible number is not a bad bot, it is a
broken measurement: the can had moved a step and a half between the aim being written and the slipper
leaving the hand. `ai_probe` now raises `Engine.physics_ticks_per_second` in proportion to the scale,
so a step stays 1/60 s of GAME time and a high scale is what it claims to be — the same simulation,
wall-clock faster, paid for in CPU.

**Validated, not assumed:** scale 1 and scale 4 now agree (aim error 0.28 vs 0.34 units; block rate
82.6% vs 78.6%). **Scale 8 does not** — aim error goes back to 1.31, because 480 physics ticks a
second for four units is more than this machine delivers in real time. ⚠️ **Use `scale=4`. Anything
above it has to prove itself against a `scale=1` run before its numbers are used.**

RUN 9's *conclusion* survives this — the standoff is still not a lever, and the two instant-tag
geometries are still real, both of which were visible at scale 4 where the distortion is 0.4 units
rather than 1.6. Its absolute dents and block numbers should be treated as indicative.

### RUN 10 — 2026-07-30. THE AI ITSELF WAS BROKEN IN SEVEN PLACES, AND THAT WAS NOT A BALANCE PROBLEM.

🧑 Human ask, 2026-07-30: *"make sure u actually fix the ai and that theyre all capable of movement"*
and *"i want the AI's movement to feel natural and not too FAST or mechanical."*

Every one of these was found by **measuring**, most of them with two new probe instruments, and each
had been invisible behind the aggregate columns for nine runs.

| # | What was wrong | How it was found | Fix |
|---|---|---|---|
| 1 | **The attacker threw from INSIDE the defended area.** `_cond_attacker_out_of_range` only asked "am I too far", so an attacker standing 3 units from the can counted as in position and charged from inside the taya's own reach. | RUN 9's per-round table: a fifth of rounds ended by tag at **1.4–1.7 s** with one throw. | A throwing **band**, `[4.6, 6.0]`. 4.6 is derived: pursuit 1.8 + melee 1.4 = 3.2, plus one more melee range of margin. |
| 2 | **The attacker walked into the taya's lap to fetch its slipper** — and its own tsinelas already crawls out to meet it, which nothing used. | `bt_trace()` at the moment of every tag. | Hold at the band's inner edge and let the slipper come. ⚠️ The first version waited at 9.0 units and measured time-to-first-throw going 0.6 s → 9.6 s with 2 rounds in 4 taking **no throw at all**. Waiting is right; waiting that far away is dead time. |
| 3 | ⚠️ **The attacker's dodge was blind to the only defender that could ever hit it.** Threat detection required a defender **closing at 0.35 m/s**, and `_act_taya_tag` **releases movement in order to tag**. At the exact instant a tag was coming, the taya's velocity was ~0 and the attacker's own threat test scored it harmless. | `bt_trace()` at contact, 10 rounds: tagged in `approach` ×4, `settle` ×2, `fetch` ×1, `wait-out-the-guard` ×1 — **never once defending itself.** | A defender at arm's length (1.9) is an emergency whatever it is doing, and it out-prioritises everything except a throw already past its commit point. |
| 4 | ⚠️ **The Can never moved.** `CAN_HOLD_RADIUS` 0.45 against `ARRIVE_DISTANCE` 0.6 — **the deadzone was wider than the circle it was picking points inside.** Recorded in RUN 1's own notes and never fixed. | Independence audit: 7.03 s longest still run on `TeamAProp`, the whole sample minus its dodges. | A 0.12 arrival distance, inside its own circle. The circle stays 0.45 — the Can must not wander off the mark. |
| 5 | ⚠️ **Fixing 4 made the Can UNHITTABLE, and this is the most instructive bug of the pass.** `character_base.gd` **normalises** an AI movement vector, so a 0.22-unit shuffle is performed at the full 6.0 m/s — nearly two units of travel during every flight, re-rolled every 0.35 s. | The new closest-approach geometry: **median 2.49 units, 0 of 12 unblocked throws inside the 0.50 overlap band.** | A shuffle is performed at **shuffling pace** (0.30 of SPEED). ⚠️ Evasion is exempt and still full speed — the dodge is the Can's skill, the fidget never was. |
| 6 | **The same normalisation broke the AI's lead.** `_lead_the_can` extrapolated the can's *instantaneous* velocity, which for a shuffling can is 6 m/s of noise. | Same instrument. | Lead a **smoothed** velocity: a shuffle averages to nothing, a real sidestep survives. Capped at 1.2 units. |
| 7 | ⚠️ **The Guard was a free, perfect third layer of defence.** A hit is not a dent while Guard is up (`apply_dent` refuses outright), and the can raised it in reaction to **every single throw**. | scale-1 run: 23 throws, 19 blocked, **2 that genuinely reached the can, 0 dents.** | A reaction delay (`tier_think`-scaled) and a cooldown, so a fast flat throw arrives before the guard and a **barrage punches through where one throw does not**. Neither `CAN_EVADE_MISS_MARGIN` (a human call) nor `CAN_EVADE_LOOKAHEAD` (untunable) was touched. |
| 8 | **The grab never re-fired.** `_tap()` was called every tick, which resets its own release countdown, so the key never came back up and `input_just_pressed` fired **exactly once**. A first attempt that did not take left the attacker standing over its own slipper pressing a dead button. | The new stillness trace: **4.05 s** of a loose prop in `tsinelas/stand-down` opposite an attacker parked in `retrieve/fetch`. | A grab interval, same shape as `TAYA_TAP_INTERVAL`. |
| 9 | **A loose tsinelas that had arrived stopped dead**, and it was the largest single contributor to the stillness figure. | Stillness trace: 12 of 26 episodes over 2 s. | It settles instead of freezing. |

**MOVEMENT NO LONGER READS MECHANICAL** — the other half of the ask, and the cause was not the speed
number. An AI unit's movement is **four booleans**, normalised: eight compass directions, full speed,
changing in a single frame. Four fixes, none of them touching gameplay code: a **heading that turns at
a bounded rate** (8 rad/s, so a reversal is a ~0.4 s turn and not a frame); a **Schmitt trigger** per
compass key, so a heading sitting on a threshold holds it instead of chattering (that chatter is also
what inflated the transition counts every independence audit has reported); a **walking gait** per
tier through the public `enter_speed_zone()` API, dropped the instant a human takes the unit over; and
an **idle settle** so an arrived unit shifts its weight instead of freezing.

#### The RUN 10 table — 20 rounds, Option A, Eskinita, scale 4, standoff 2.6, on honest physics

| Metric | RUN 9 (2.6 row) | **RUN 10** | Fair |
|---|---|---|---|
| Round win rate | DEF 100% | DEF **100%** | 40–60% |
| Time-to-first-throw | 0.8 s | 0.8 s | < 8 s |
| Throws taken | 188 | 73 | — |
| **Throws blocked** | **94.7%** | **78.1%** | 25–50% |
| Reached the can | 1 | 2 | — |
| **Dents/round** | 0.05 | **0.10** | ≥ 1 |
| Ended by tag | 19/20 | **20/20** | — |
| Avg round duration | 28.2 s | **13.2 s** | — |
| Aim error at release | *not measured* | **0.39 units mean** | — |
| Went-nowhere (displacement) | *not measured* | **3.85 s worst** | < 2 s |

**RE-RUN AT `scale=1` BEFORE BEING WRITTEN AS FINAL, per this section's own rule** — and on the map as
it stood after the chalk/children's-drawings pass, so it is also a re-check against a changed world.
20 rounds, scale 1: **throws blocked 78.3%** (scale 4 said 78.1%), aim error **0.21 units** mean / 0.40
worst, dents 0.05, 20/20 by tag, first throw 0.6 s. The headline reproduces; the scale-4 figures above
are admissible.

**INDEPENDENCE MODE IS GREEN AGAIN, AND IT WAS NOT BEFORE THIS PASS.** `godot --path <abs>
tools/ai_probe.tscn`: **longest still run 1.70 s (fair < 2 s)**, frames where 2+ bots changed state
together **0 / 843** (recorded figure: 1/843), 37 transitions across three driven bots, none frozen.
Before the fixes the same audit read **7.03 s** on `TeamAProp` — the Can that could not move.

**VERDICT, stated plainly: the AI is materially better and the game is still not fair.** Seven real
defects are gone, the block rate is down 16.6 points, the attacker no longer walks into the tag at the
opening whistle, and every unit moves. **But the defence still wins 100% of rounds and 20/20 still end
by tag**, which is now firmly R-08's problem and not the AI's — see RUN 11 immediately below, which
was measured for exactly this reason.

⚠️ **R-07's OWN ACCEPTANCE BAR IS NOT MET AND IS NOT CLAIMED.** It asked for block rate ≤ 60% and
dents/round ≥ 0.5. Measured: **78.1% and 0.10.** The committed post is a real improvement (94.7 → 78.1
across RUN 9 → RUN 10, with the AI fixes in between) but it is not sufficient on its own.
`throws released while the post was already wrong: 0 / 73` — the attacker's slide is not yet beating
the post at all, because the post's reaction window (0.35 s) is shorter than the attacker's own charge
(0.42–0.98 s), so the taya re-posts *during the wind-up*. **`posthold=` and `repost=` exist to sweep
exactly this and the sweep has not been run.** That is the next concrete piece of work and it is one
hour.

⚠️ **THE STILLNESS METRIC WAS ITSELF WRONG, AND BOTH VERSIONS ARE NOW PRINTED.** `STILL_SPEED` 0.35 m/s
was written against Persons walking at 6.0, but every other unit moves through a speed scale — a
tsinelas crawling home at `CRAWL_SPEED_SCALE` is at 2.7 m/s, a stood-on one at 0.95, a settling unit
lower again. **A slipper crawling home at 0.33 m/s scored as "frozen" while doing exactly its job**,
which is a large part of why "the longest still run has moved independently of everything else for
three consecutive runs". `ai_probe` now reports stillness by **displacement** as well, per unit, with
the branch named. The residual 3.85 s of went-nowhere is **a charging attacker (a deliberately
readable wind-up) and a taya on its post** — both nameable now, neither a freeze.

#### R-10's own acceptance, measured — and one half of it is NOT proven

R-10(a) asks for AI throw power varying by **≥ ±25%** (a 50% spread), against a history in which
`tier_charge` was one fixed number and **every AI throw ever taken had identical power**. Measured off
the slipper's own peak launch speed, 10 rounds at BATA:

| Configuration | Throws | Launch speed min / mean / max | Spread |
|---|---|---|---|
| flavour **on** (`fun=on`, shipped) | 25 | 7.09 / 12.69 / 19.73 m/s | **100% of the mean** |
| flavour **off** (`fun=off`) | 134 | 7.09 / 11.87 / 23.18 m/s | **136% of the mean** |

⚠️ **THE BAR IS MET AND THE CLAIM IS NOT.** Power varies by well over 50% either way — but it varies
just as much with the flavour switched OFF, because `_min_hold_to_reach()` scales the hold with the
distance to the can, so a throw from 6.0 units is legitimately harder than one from 4.6. **That
range-dependence, not the per-throw jitter, is what this metric is seeing.** Isolating the jitter needs
power sampled at a fixed release range, which has not been done. So: **AI throws do vary, the jitter is
implemented and is inert-safe, and "the jitter is what makes them vary" is UNVERIFIED.**

⚠️ **Sampling note, because it cost a run.** `carry_state_changed` fires from `Carriable::_set_state()`
**before** `_rpc_set_flying` writes the velocity, so reading launch speed at the signal returns 0.00 for
every throw — which reads as "the jitter does nothing" rather than as "the probe sampled a frame early".
Peak planar speed over the flight is used instead.

The other two thirds of R-10 — a readable wind-up and a punishable overcommit — are claims about what a
*human* can react to, so **they close on play, not on a probe.** The overcommit's own bound IS measured
(RUN 12's `mistake` column, and `_cond_taya_threat_in_confinement`'s note on the first version that spent
a third of every round sprinting and won more rounds by "mistake" than by blocking). 🧑 **Next session:
ask whether ASTIG reads as hard or merely fast, and whether the wind-up is long enough to dodge — then
log the answer as a test result** (a `B-` entry in `Handoff.md` §3, a tick here, and the lane board in
`Agent_Prompts.md`, same commit).

### RUN 11 — 2026-07-30. R-08: IS THE INSTANT-WIN TAG THE IMBALANCE? Three variants, one harness. 🧑 THE PICK IS THE HUMAN'S.

⚠️ **Imposed from the probe, never from `hitbox.gd`.** That file is another lane's, R-08's deliverable
is a table to choose from, and shipping a rule in order to measure it would be making the decision.
The interception is honest because of the order inside `hitbox.gd::_on_area_entered`: `landed_on.emit()`
runs **before** `RoundManager.report_round_win(true)`, and that function no-ops on `not round_active`.
Stated cost: the round clock does not advance for the fraction of a frame between suppression and the
deferred restore — far below the noise on every column here.

20 rounds each, Option A, Eskinita, scale 4, standoff 2.6, identical AI.

| Variant | Round win rate | Throws taken | Blocked | Reached can | **Dents/round** | Ended by | **Avg round duration** | Tags suppressed |
|---|---|---|---|---|---|---|---|---|
| **3 · CONTROL** (any tag ends the round) | DEF **100%** | 73 | 78.1% | 2 | **0.10** | 20/20 tag | **13.2 s** | — |
| **1 · a tag costs the slipper + a respawn** | DEF **100%** | **398** | 83.2% | **11** | **0.55** | **20/20 clock** | **90.0 s** | **162** |
| **2 · a tag only counts inside the box** | DEF **100%** | 102 | 77.5% | 3 | **0.05** | 20/20 tag | 19.0 s | **0** |

**READ THE DENTS COLUMN FIRST, THEN THE DURATION COLUMN, EXACTLY AS THIS SECTION SAYS.** Three findings,
and the second is the one nobody predicted:

1. **VARIANT 1 IS THE ONLY ONE THAT CHANGES ANYTHING: 5.5× the dents (0.10 → 0.55), 5.5× the throws
   (73 → 398), 5.5× the throws reaching the can (2 → 11).** 162 tags happened and cost the attacker its
   slipper and a walk home instead of the round. That is the retrieval scramble becoming the game,
   which is what the real street game is. ⚠️ **AND IT COSTS EVERY ROUND THE FULL 90-SECOND CLOCK** —
   20/20 timed out. It does not fix the win rate; it converts an instant loss into a slow one.
2. ⚠️ **VARIANT 2 IS A NULL RESULT, AND THAT IS USEFUL: `tags suppressed: 0 / 102`.** **Every single
   tag in the run already happened while the attacker was inside the confinement square.** "Only count
   a tag during retrieval" changes nothing because retrieval is *already* the only place tags occur —
   which independently confirms RUN 6's finding about where the real exposure is, and retires the
   variant. It cannot be the fix; there is nothing for it to fix.
3. ⚠️ **THE WIN CONDITION IS OUT BY MORE THAN THE TAG RULE — AND HERE IS THE ARITHMETIC.** Under Option A
   the offence must land **`MAX_DENTS` = 3 dents on one can inside one round** while the defence needs
   **one tag**. Variant 1's own numbers say what that costs: at **0.55 dents per round** the offence
   reaches 3 essentially never, which is why its win rate is 100–0 despite 398 throws. **At a
   requirement of 1 dent, variant 1's 9-in-20 dented rounds would be ≈45% offence.** The lever with
   the most fairness per unit of change is therefore `CharacterBase.MAX_DENTS`, **not** the tag rule.

**RECOMMENDATION (the lane produces it; 🧑 the decision is the human's):** **variant 1, paired with a
lower dent requirement, and not variant 1 alone.** Variant 1 by itself trades an unfair game for a slow
one and fails the no-dead-time pillar outright. Variant 2 is retired by its own null result. ⚠️
`MAX_DENTS` lives in `character_base.gd`, a **shared-lock** file the balance lane may not write — it
needs claiming in `SHARED_LOCKS.md`, and the number above is the argument for the claim.

### RUN 12 — 2026-07-30. R-09: THE DIFFICULTY TIERS, MEASURED FOR THE FIRST TIME.

⚠️ **Nothing outside `AIController` called `apply_difficulty()` until `tools/ai_probe.gd` gained a
`tier=` argument on 2026-07-30, so no tier but NORMAL had ever been measured.** Two new columns were
added to `DIFFICULTY_TIERS` in the same pass — `gait` (walking pace) and `mistake` (the overcommit
chance) — so all three tiers now differ in feel as well as in sharpness.

20 rounds each, Option A, Eskinita, scale 4, standoff 2.6, control tag rule.

| Tier | pursue / lead / think / charge / gait / mistake | Win rate | 1st throw | Throws | Blocked | **Dents/round** | **Avg round** |
|---|---|---|---|---|---|---|---|
| **BATA** | 1.8 / 0.25 / 0.50 / 0.40 / 0.80 / 0.22 | DEF 100% | 0.4 s | 68 | **61.8%** | 0.15 | **9.1 s** |
| **NORMAL** | 1.8 / 0.60 / 0.35 / 0.65 / 0.88 / 0.09 | DEF 100% | 0.8 s | 73 | **78.1%** | 0.10 | **13.2 s** |
| **ASTIG** | 4.6 / 0.85 / 0.22 / 0.80 / 0.96 / 0.02 | DEF 100% | 0.5 s | 29 | **58.6%** | **0.00** | **3.7 s** |

**THE TIERS DO DIFFER, WHICH HAD NEVER BEEN SHOWN — but ⚠️ NOT MONOTONICALLY, AND THE REASON MATTERS.**
ASTIG's block rate is the *lowest* of the three, and that is not it defending worse: at `pursue` 4.6
the taya chases anywhere inside its box, so **rounds end in 3.7 seconds** and there is no time for
throws to accumulate. Its dents column is the honest one: **0.00, the only tier where the offence never
scores at all.** BATA is the most beatable (61.8% blocked, 0.15 dents) and gives the longest usable
round. ⚠️ **Read `pursue` 4.6 against RUN 9's second geometry** — a taya that chases to the box edge is
inside melee range of the throwing line, which is the same instant-tag mechanism RUN 9 found at high
standoff. ASTIG being "hard" is largely that, not superior play, and if a human finds it unfun rather
than difficult, **lowering ASTIG's `pursue` is the first thing to try.**

### RUN 13 — 2026-07-30. R-21's HEATMAP: WHERE THE FOUR UNITS ACTUALLY ARE.

⚠️ **Two implementations now exist and one should go.** The 🌏 MAPS lane built `tools/flow_probe.tscn`
(heatmap + sightlines) on 2026-07-30, stating in its own header that it built the capture only because
`ai_probe` had no heatmap hook and that *"if it has one, this file can keep only `_write_heatmap()`"*.
`ai_probe` now has one — sampling, an ASCII grid and a PNG — so **the hook flow_probe asked for exists
and the duplicate capture can be collapsed into it.** That is the MAPS lane's call, not this one's.

⚠️ **The artefact in this log is TEXT on purpose.** `docs/` is another lane's directory and a binary
image there is a merge conflict waiting to happen; the ASCII grid survives a diff. The PNG is written
to `user://heatmap_<map>_<variant>.png` and its absolute path is printed by the run.

Eskinita, 20 AI rounds, 1408 samples at 1/s of game time, peak cell 267 (`#` ≥ 50% of peak, `+` ≥ 20%,
`:` ≥ 5%, `.` > 0, `[`/`-` mark the ±5.0 confinement square, `o` the can's mark):

```
  |                             |
  |              .              |
  |            .. ...           |
  |           .. ....           |
  |         -.-.....-.-         |
  |        ............         |
  |        ... ......... .      |
  |      ..........+..:.        |
  |        .:....:.::....       |
  |       ....:.:#:.:.:..       |
  |      ........:.:..:.        |
  |        .....:.....:.        |
  |      .. ....::.....         |
  |         ...:......[         |
  |         --..:....--         |
  |        .   ..+...           |
  |            .... .           |
  |            .. .             |
  |                ..           |
  |                             |
```

**THE FINDING IS DEAD SPACE, AND IT IS LARGE.** Every one of 1408 samples falls inside roughly ±7 units
of the can, in a rough disc barely wider than the confinement square itself — the peak cell sits
**on the mark**, and the ±14-unit sampled area is more than half empty in every direction. The play
happens in a ring one to two units outside the chalk and nowhere else. ⚠️ **This does not license
shrinking the arena — the FOOTPRINT is a standing decision.** What it says is that map dressing and
readability spent outside ~8 units of the centre is spent where nobody goes, and that
`CONFINEMENT_RADIUS` is not obviously too small: the units use the whole box and a margin beyond it.
🧑 **The size call remains the human's, and the sweep that would inform it is still filed, not run** —
see the R-21 handoff below for the two reasons why.

### RUN 14 — 2026-07-30. R-07 CLOSED, and the first time the offence has ever won a round.

**R-07's post did nothing at 0.35 s for a measurable reason: the window has to outlast the thing it is
meant to be beaten by.** The attacker's charge is 0.42–0.98 s, so a taya re-posting after 0.35 s
re-posts *during* the wind-up — RUN 10 measured it exactly, **0 of 73 throws released while the post was
wrong.** Swept {0.35, 0.70, 1.10, 1.60} × {0.35, 0.50, 0.55, 0.70}; the block rate falls as the hold
crosses the charge time, which is the mechanism confirming itself. **Shipped: `taya_post_hold` 1.6 s,
`taya_repost_angle` 0.50 rad**, both tier-scaled (BATA holds 2.3 s, ASTIG 1.0 s).

| Metric | RUN 10 (post at 0.35) | **RUN 14 (post at 1.6/0.50)** | scale=1 check | Fair |
|---|---|---|---|---|
| **Throws blocked** | 78.1% | **38.4%** | 49.3% | 25–50% ✅ |
| Dents/round | 0.10 | 0.25 | 0.25 | ≥ 1 |
| Throws the slide **beat** | **0 / 73** | **13 / 86** | 10 / 75 | ≥ 1 ✅ |
| Reached the can | 2 | 5 | 5 | — |
| Avg round | 13.2 s | 10.5 s | 9.7 s | — |
| Win rate | DEF 100% | DEF 100% | DEF 100% | 40–60% |

**R-07's acceptance: block ≤ 60% ✅ (38.4%), the slide beats the post ✅ (13 throws), still-run not
regressed ✅ (independence 1.70 s). The dents ≥ 0.5 clause is NOT met under the shipping tag rule — and
it is not the post's to meet.** Same AI, same post, against R-08's variant 1:

| Configuration | Win rate | Throws | Blocked | Reached can | **Dents/round** | Avg round |
|---|---|---|---|---|---|---|
| R-07 post + **shipping tag rule** | DEF 100% | 86 | 38.4% | 5 | 0.25 | 10.5 s |
| R-07 post + **R-08 variant 1** | **DEF 70% / OFF 30%** | **508** | 43.5% | **29** | **1.75** | 82.0 s |

⚠️ **THAT SECOND ROW IS THE LARGEST NUMBER THIS LOG HAS PRODUCED.** From DEF 100/0 across every one of
RUNS 1–13, to **70/30**, with the block rate inside its fair band and **17 of 20 rounds dented**. The
offence wins rounds. It is still outside 40–60 and every round still runs long (14/20 on the clock), but
the two levers that move fairness are now identified and quantified: **the committed post, and the tag
not ending the round.**

**RECOMMENDATION, updated with numbers rather than intent (🧑 the pick stays the human's):** ship
**R-07's post (already in) + R-08 variant 1 + `MAX_DENTS` 3 → 2.** At 1.75 dents landing per round, a
3-dent requirement converts to 30% offence; a 2-dent requirement is what turns those 17 dented rounds
into wins and shortens the 82 s average at the same time. `MAX_DENTS` is in `character_base.gd`.

### RUN 15 — 2026-07-30. Two things that turned out NOT to be levers, and the noise floor.

**R-10(a), the charge jitter, isolated.** RUN 12 showed throw power varying by >100% of the mean, but
`_min_hold_to_reach()` already varies power with range, so the jitter's own contribution had to be
separated: `jitter=0.0` → **123% spread**, `jitter=0.5` → **127%**. **The jitter adds ~4 points on top of
the range effect, i.e. essentially nothing measurable.** AI throw power genuinely varies — the "every
throw identical" defect is gone — but it varies because a longer throw needs more charge, not because of
the jitter. The jitter is implemented, inert-safe, and **not the cause of the variance.**

**R-21's sweep, physics-only.** ⚠️ `confine=` moves the runtime clamp and **not the painted chalk** —
both map builders draw the square from the `const` and emit their `.tscn` wholesale, and `tools/maps/**`
and `scenes/maps/**` are the MAPS lane's, explicitly hands-off. So `ai_probe` now asserts the two agree
and **refuses to call a divergent run a fairness measurement** (the 4.0 and 6.0 rows below print
`honesty contract: FAILED` by design). What the rows do say is how sensitive fairness is to the box size:

| `confine=` | Blocked | Dents/round | Avg round | Chalk agrees? |
|---|---|---|---|---|
| 4.0 | 44.3% | 0.15 | 8.9 s | ✗ sensitivity only |
| **5.0** (shipped) | 47.0% | 0.30 | 8.9 s | ✅ |
| 6.0 | 46.3% | 0.10 | 8.1 s | ✗ sensitivity only |

**All three rows are inside the noise. The confinement size is not a fairness lever** — which is the
third knob in a row to come back that way, after `taya_pursue_radius` (RUN 8) and `taya_block_standoff`
(RUN 9). 🧑 **The size call is therefore a FEEL call, not a balance one**, and it needs the const changed
plus both builders re-run to be judged properly.

⚠️ **THE NOISE FLOOR, MEASURED, AND EVERY TABLE ABOVE SHOULD BE READ AGAINST IT.** Two 20-round runs of
the *identical* configuration returned **dents/round 0.05 and 0.25**, and RUN 9's two 1.60-standoff rows
returned block rates 40.0% and 42.5%. **So at n=20: ±0.2 on dents/round and ±2.5 points on block rate.**
Any difference smaller than that is not a finding. Use 40+ rounds before acting on a small one.

### ⚠️ Still open after RUN 15

**Corrected 2026-07-30, twice.** This section used to be headed "after RUN 7" and to quote RUN 7's figures.
**RUN 8 invalidated them** — RUNS 1–7 all measured a 3-v-4 — so the numbers below are RUN 8's.

- **Win rate DEF 100% and dents 0.10 (RUN 10).** Not "improved, still out". **The offence does not
  score.** 78.1% of throws are blocked and 20/20 rounds end by tag — down from 94.7% and unchanged
  respectively. ⚠️ **The AI is no longer the reason.** RUN 10 removed seven measured defects from it;
  what is left is the win condition, and RUN 11 quantifies it: the offence must land 3 dents in one
  round while the defence needs one tag, and even with the tag rule removed the offence manages
  **0.55 dents a round.** The single highest-leverage change on the table is
  `CharacterBase.MAX_DENTS`, which is a shared-lock file and needs claiming.
- ~~**sweep `posthold=` and `repost=`**~~ **DONE, RUN 14.** Shipped at 1.6 s / 0.50 rad; block rate
  78.1% → 38.4%. R-07 is closed on its block-rate and slide-beats-the-post clauses.
- **THE NEXT DECISION IS THE HUMAN'S, AND IT IS ONE NUMBER:** `CharacterBase.MAX_DENTS` 3 → 2, taken
  together with R-08 variant 1. RUN 14 measured 1.75 dents landing per round and a 70/30 split under
  variant 1; the arithmetic says a 2-dent requirement is what converts those 17 dented rounds into wins
  and shortens the 82 s average at the same time. **Nothing else in the balance lane's reach moves the
  win rate further** — three knobs in a row (pursuit, standoff, confinement) have each come back inside
  the noise.
- **`ATTACKER_LANE_CLEARANCE` and `ATTACKER_DODGE_RADIUS` / `ATTACKER_DODGE_STEP` are still outside
  `DIFFICULTY_TIERS`** and still belong in it. `gait` and `mistake` were added there in RUN 12; these
  three are the remainder. Do not one-off-nerf any of them.
- ~~**`TAYA_BLOCK_STANDOFF` (2.6) IS STILL UNMEASURED**~~ **CLOSED BY RUN 9, 2026-07-30.** It is a
  `static var`, `ai_probe` takes `standoff=`, and it has been swept end to end over
  {1.0, 1.4, 1.8, 2.2, 2.6, 3.2, 3.8}. **It is not a fairness lever at any value** — DEF 100% and
  ≤ 0.10 dents throughout. It IS a round-length lever with a non-monotonic response, and the shipped
  2.6 sits in the only band where a round lasts more than about two seconds. ⚠️ **Three documents
  called this the most obvious next lever and all three were wrong**, which is the argument for
  R-01-style promotion in general: the cost of that belief was three runs.
  ⚠️ RUN 6's 50.6% block rate is not a baseline to start from — it is a 3-v-4 number like every other
  figure before RUN 8. The live number to beat is RUN 9's **94.7%**.
- **THE CAN'S EVASION IS A SECOND CEILING, and it is not in anyone's task list.** `phys_probe
  target=can` on today's build: a dead-centre, full-charge, completely unopposed throw connects
  **3 times in 9**. So even a perfectly beaten taya leaves the offence converting at ~33%. Any
  fairness target that assumes an open lane is a scored dent is off by a factor of three. Do NOT
  answer this by moving `CAN_EVADE_LOOKAHEAD` — its sweep is non-monotonic and documented as
  untunable; `CAN_EVADE_MISS_MARGIN` is the knob with a monotonic response.
- **Difficulty tiers EXIST IN CODE and are UNREACHABLE.** ⚠️ **This entry used to say tiers did not
  exist and that entry is now stale.** `ai_controller.gd`'s `DIFFICULTY_TIERS`
  (BATA / NORMAL / ASTIG) and `apply_difficulty()` are complete and correct, and they already carry
  `pursue` / `lead` / `think` / `charge`. What is missing is that **nothing outside that class calls
  `apply_difficulty()`, there is no player-facing selector, and no tier but NORMAL has ever been
  measured.** `ATTACKER_LANE_CLEARANCE` and `ATTACKER_DODGE_RADIUS` / `ATTACKER_DODGE_STEP` are
  still outside the table and still belong in it. Do not one-off-nerf any of them.
- **⚠️ The framing has changed, and the next pass should know it.** RUNS 2–7 treated fairness as a
  *tuning* problem. A 92% block rate on an honest field is not a knob 15% off its mark — the taya
  re-derives its post from the attacker's *current* bearing every tick, so the only open lane is one
  it has not reacted to yet, and the attacker's only reply is to wait `ATTACKER_PATIENCE` and throw
  into the block. **[`Roadmap.md`](Roadmap.md) Stage 1 treats it as structural** and proposes three
  measured changes — a lob, a committed taya post, and a test of whether an instant-win tag is
  itself the imbalance. Sweeping the standoff (RUN 9) still runs first; the plan does not depend on
  it succeeding.

### HANDOFFS OUT OF THE ⚖️ BALANCE LANE — written 2026-07-30

⚠️ **Why they are here and not in `Handoff.md` §5.** The balance lane's write list is
`ai_controller.gd`, `character_roster.gd`, the three probes it owns, and this section.
`docs/Handoff.md` belongs to another lane, so a pointer to these three blocks needs adding there by
whoever owns it — the specifications themselves are complete below and nothing is waiting on that
pointer.

#### HANDOFF — R-06 (the lob, `bagsak`) to the 🥊 PHYS lane

**The target to beat is measured, not assumed: 94.7% of 188 throws blocked (RUN 9, standoff 2.6).**
A body-block that cannot be gone over is not a block, it is a wall.

⚠️ **THE HIGH ARC IS ALREADY COMPUTED AND THEN THROWN AWAY.**
`carriable.gd::_solve_arc()` solves the ballistic quadratic and takes
`tangent := (v2 - sqrt(discriminant)) / (gravity * distance)`. **That minus sign is the flat root.
`(v2 + sqrt(discriminant))` is the lob, at the same launch speed, to the same target point.** The
mechanic is therefore a root selection plus the plumbing to choose it — not new ballistics, and not
a new `ThrowProfile` field.

Specification, in the order it has to be built:

1. **The input region. DO NOT ADD AN INPUT ACTION.** The charge is already an analogue hold and the
   lob is a region of it. `carrier.gd::_step_throw` currently clamps
   `_charge_time = minf(_charge_time + delta, CHARGE_FULL_TIME)` (0.9 s). Let the hold keep
   accumulating past that into a `LOB_HOLD_TIME` region (the AI lane's belief is
   `CHARGE_FULL_TIME + 0.20`, `AIController.attacker_lob_overhold` — **make the real constant public
   and have the AI read it rather than restating it**, the way `_charge_fraction()` already reads
   `Carrier.CHARGE_MIN_POWER`/`CHARGE_FULL_TIME`). `charge_power()` must still clamp to 1.0, so the
   HUD meter fills and stops rather than overflowing.
2. **The flag has to travel with the throw, not be re-derived at the far end.** `_request_throw(power)`
   → `_rpc_request_throw(target_point, power)` → `host_throw(target_point, power)` → `_solve_arc`.
   Adding `lob: bool` to that chain keeps the decision on the machine that made it. ⚠️ **Do not infer
   "it was a lob" from the power value** — power clamps at 1.0, so a full-power flat throw and a lob
   are indistinguishable by then. That is the whole reason for a separate flag.
3. **It must arrive slowly enough to be dodged, and that is the balance clause, not a side effect.**
   `CAN_EVADE_LOOKAHEAD` is 0.6 s and ⚠️ **is documented as untunable — its sweep is non-monotonic
   (1.10 → 18 contact frames, 0.85 → 57, 0.70 → 0). Do not touch it.** So the lob has to satisfy the
   existing lookahead: **flight time > 0.6 s over the 6.0-unit throwing line.** The high root gives
   that for free — verify it with `phys_probe -- ballistics` and log the number.
4. **It must land short of a body-block.** The high root over-flies a defender standing at
   `taya_block_standoff` 2.6 from the can while still descending onto the can. Confirm with
   `hit_probe -- --host target=can standoff=2.6`: **the acceptance bar is ≥ 40% contact for the lob
   against the ≈ 8% the flat throw manages into a parked taya** (RUN 9's own figure for a blocked
   lane is 5.3% unblocked, which is the same statement from the other side).
5. **Animation and audio are NOT in scope for the mechanic**, but the wind-up must be visibly
   longer, because R-10's whole premise is that a committed throw is readable.

**The AI half is already built and shipped inert.** `AIController._cond_attacker_should_lob` /
`_act_attacker_charge_lob` add a third option to the `throw-how` selector, beside slide and
throw-anyway, and it fires on exactly the frame the attacker would otherwise feed the block.
`AIController.lob_enabled` is **false** and `tools/ai_probe.tscn -- ... lob=on` turns it on, so the
decision can be measured before and after the mechanic exists. With the mechanic absent, holding
longer produces the identical throw slightly later — it cannot silently move a fairness number.

⚠️ **ACCEPTANCE IS A REVERT, NOT A RE-TUNE.** Once the mechanic lands, a 20-round `ai_probe` run
with `lob=on` must bring the block rate **below 70%** (from 94.7%). If it does not, the item has
failed and comes out.

#### R-06 · BUILT AND MEASURED, 2026-07-30 — 🥊 PHYS. The lob is a FIXED-ANGLE solve.

**The spec above asked for the high root. It was built exactly as written, measured, and
rejected on the numbers.** The high root at full launch speed is a mortar, and it scales
the wrong way — the lightest, fastest slipper produces the highest, slowest lob:

| profile | high-root angle | flight | apex above the hand |
|---|---|---|---|
| `throw_bagsak` | 74.8° | 1.22 s | 5.06 m |
| `throw_bakya` | 77.4° | 1.40 s | 6.22 m |
| `throw_default` | 80.5° | 1.68 s | 8.41 m |
| `throw_flick` | **85.6°** | **2.90 s** | **18.45 m** |

18 m is above Eskinita's 10–14 m rooflines and outside an FPP player's field of view —
they would have to look at the sky to watch their own throw — and 2.9 s is a dead beat in
a 90 s round. The cause is structural: the high root's angle is a function of surplus
speed over the minimum needed to reach the target, and a full charge at the 6.0 line has
plenty.

**So the lob fixes the angle at 60° and solves the SPEED** — `v² = g·d² / (2·cos²θ·(d·tanθ
− h))`. That is the same arc read from the other end of the same equation: it IS the high
root, at the speed that makes the high root 60°. Every clause of the spec survives — it
passes exactly through the crosshair point, no new `ThrowProfile` field, no new input
action, and it uses LESS speed than the charge earned so it is never a power buff.

60° is derived, not chosen: a taya at `taya_block_standoff` 2.6 stands 3.4 m along a 6.0 m
lane and its Hurtbox tops out at world y 1.75 against a hand at 0.90. At 60° the arc is
**2.42 m above the hand there — clearing the defender's head by 1.57 m.** 45° is the
flattest arc that reaches at all and clears by 0.09 m, i.e. inside one frame of travel.

**Ballistics, re-run in full on BOTH maps, row by row against the 2026-07-29 baseline:**

| profile | flat flight | LOB flight | LOB apex | reach floor (flat) | baseline reach floor |
|---|---|---|---|---|---|
| `throw_flick` | 0.27 s | 1.10 s | 2.32 m | 50% | 50% ✅ |
| `throw_default` | 0.32 s | 0.93 s | 2.31 m | 65% | 65% ✅ |
| `throw_bakya` | 0.33 s | 0.89 s | 2.31 m | 65–80% | 65–80% ✅ |
| `throw_bagsak` | 0.35 s | 0.86 s | 2.31 m | 80% | 80% ✅ |

**Every flat row reproduces the baseline to the charge step**, which is the regression test
on the root selection: picking the minus root explicitly did not change the throw the game
already had. Scatter is still 0.00–0.02 m. Eskinita and Bayan Plaza agree to 0.02 m — the
cross-check that matters, since ballistics is map-independent.

**Apex is profile-INDEPENDENT (2.31–2.53 m) because `g` cancels out of it.** So every
slipper lobs to one readable height and the profile identity survives as *timing*: the
floaty flick hangs longest at 1.10 s, the heavy bagsak arrives soonest at 0.86 s. All four
exceed `CAN_EVADE_LOOKAHEAD`'s 0.6 s; **no flat throw does.**

⚠️ **`eta` in `_cond_slipper_incoming()` is exactly time-to-impact** (horizontal distance ÷
horizontal speed, and horizontal speed is constant under gravity), so the can's warning is
`min(flight_time, 0.6)`. A flat throw gives it 0.32 s; every lob gives it the full
lookahead. That is the balance clause, and it is a property of the arc, not of the AI.

**The triangle — `phys_probe -- lane`, 10 throws per cell, taya parked at standoff 2.6:**

| throw | lane | can | contact | stopped by taya |
|---|---|---|---|---|
| flat | blocked | parked | **0%** | 100% |
| flat | blocked | dodging | 0% | 100% |
| **LOB** | **blocked** | **parked** | **100%** | 0% |
| LOB | blocked | dodging | 40% | 0% |
| flat | open | parked | 100% | 0% |
| flat | open | dodging | **0%** | 0% |
| LOB | open | parked | 100% | 0% |
| LOB | open | dodging | **50%** | 0% |

- **Leg 1 — the lob beats the taya: PASS.** 100% vs 0%, against a bar of ≥ 40%.
- **Leg 2 — the dodge beats the lob: PASS.** 50% dodging vs 100% parked.
- **Leg 3 — the flat throw beats the dodge: FAIL, and the cause is not the lob.**
  ⚠️ **DO NOT REVERT THE LOB ON THIS ROW.** Nothing in it is a property of the arc.
  ⚠️⚠️ **THE CAUSE FIRST WRITTEN HERE WAS WRONG, AND THE `-- band` BLOCK BELOW MEASURED
  IT.** This row used to read: *"`_act_can_evade` sidesteps LATERALLY with
  `CAN_EVADE_STEP` 1.2 m against a ~0.52 m overlap band. A lateral step of twice the band
  is … a poor [answer] to something arriving nearly vertically — you cannot sidestep out
  from under a drop."* The band is **0.45 m** measured, the step aims **2.7× it**, and the
  can is observed completing a full-size sidestep against a lob. **The step was never too
  small.** Quoted rather than deleted because it is the reasoned diagnosis the measurement
  replaced — and because widening `CAN_EVADE_STEP` was the fix it would have bought.
  The real cause and the corrected handover are two blocks down.

⚠️ **A STEER CEILING CAME WITH IT AND IS NOT COSMETIC.** `steer_strength` is an
acceleration, so authority is strength × flight time, and the lob multiplies flight time by
six: `throw_default` would have gone from 1.7 to 10.0 m/s of lateral correction, letting the
slipper's own pilot steer back onto a dodging can and erasing the lob's counterplay.
`Carriable.MAX_STEER_DELTA_V` bounds the product at 3.0 — above every profile's existing
flat-throw authority (flick is the highest at 2.3), so **no flat throw moves at all.**

⚠️ **`AIController.ATTACKER_LOB_OVERHOLD` should now READ `Carrier.LOB_OVERHOLD_TIME`**
rather than restating 0.20, exactly as `_charge_fraction()` already reads
`CHARGE_MIN_POWER`/`CHARGE_FULL_TIME`. The values agree today by coincidence; they should
agree by construction. `ai_controller.gd` is not the PHYS lane's file.

#### R-18(a) · BOUNCE MEASURED, NOT TUNED, 2026-07-30 — 🥊 PHYS

`BOUNCE_DAMPING` and `MAX_BOUNCES` are `static var` now (the `const` kept as the shipped
baseline), swept with `phys_probe -- bounce`. The gameplay consequence of a bounce setting
is a DISTANCE — how far past first contact the slipper ends up — because that distance *is*
the retrieval scramble, and `CRAWL_SPEED_SCALE` is 0.45.

| damping | bounces | skid past first contact | settle |
|---|---|---|---|
| 0.00 | 1 | 0.00 m (stops dead — the original complaint) | 0.02 s |
| 0.15 | 1 | 0.17 m | 0.07 s |
| **0.30** | **1** | **0.79 m  ← SHIPPED** | **0.13 s** |
| 0.45 | 1 | 1.86 m | 0.20 s |
| 0.60 | 1 | 3.37 m | 0.28 s |
| 0.45 | 2 | 2.20 m (the PRE-NERF setting) | 0.29 s |
| 0.60 | 2 | 4.47 m | 0.44 s |

The 0.45/2 → 0.30/1 retune cut the skid from 2.20 m to 0.79 m. At crawl speed that is 0.81 s
versus 0.29 s of retrieval — **under a second either way, so this is a feel call and not a
balance one.** 🧑 Left at the shipped values and asked rather than guessed. If more life is
wanted, **0.45 / 1 bounce** is the row to try: the complaint was about `MAX_BOUNCES = 2`
chaining into a ragdoll, not about the damping.

#### THE ROUNDS TIME OUT BECAUSE OF ARITHMETIC, AND `MAX_DENTS` 3 → 2 DOES NOT FIX IT, 2026-07-30 — 🥊 PHYS

The tag fix is correct and the consequence is 10/10 rounds reaching the 90 s clock with the
defence at 100%. **Before treating that as a balance number, the round-win shape was
measured** — `phys_probe` now prints it at startup, before any sweep calls `_freeze_round()`
and un-tracks the cans (which is the only window in a run where the live registration is
observable at all):

```
round-win shape : 1 tracked can(s) ["TeamAProp"] | MAX_DENTS 3 | FALL_LIMIT 4 | OPTION_B
-> offence must land 3 dent(s) total to win by denting, 4 knockdown(s) by FALL_LIMIT
```

- ✅ **Exactly ONE tracked can per round.** This kills a real candidate cause:
  `_on_tracked_can_dents_changed` and the all-Sealed check both require **every** tracked can
  to be finished, so a second registration would have silently doubled the offence's whole
  win requirement. `main.gd::_reregister_tracked_cans` registers every spawned character with
  `is_can` true, and that it comes to one is a fact about the role swap, not a guarantee.
  Measured, not assumed.
- ⚠️ **So the timeout is arithmetic.** The offence needs **3** dents and RUN 14's successor
  measured **1.00 dents/round**. Three is not reachable in 90 s at that rate, and a round
  that cannot be won ends on the clock by definition.

⚠️⚠️ **AND THE STANDING RECOMMENDATION IS NOT ENOUGH, ON ITS OWN NUMBERS.** RUN 14 proposed
`MAX_DENTS` **3 → 2** against **1.75** dents/round, where it converts. The dent rate has since
fallen to **1.00**, so 2 dents is still twice what a round delivers. **2 will not turn these
timeouts into offence wins.** Either the dent rate has to come up or the requirement has to
go to 1 — and a 1-dent round is a different game, not a tuning step. 🧑 **The pick is the
human's and `MAX_DENTS` is left alone**, per RUN 14's own note; what is new here is that the
number it was chosen against has moved.

⚠️ **Also worth the balance lane's attention: 1.75 → 1.00 dents/round happened while
`blocked` IMPROVED, 43.5% → 41.2%.** Fewer throws stopped, fewer dents landed. Those two
pull opposite ways and one of them is probably not measuring what its column says — which is
the same shape as the four instrument faults already logged in this file. Not this lane's
probe and not diagnosed here, but it should be resolved before either number is used to pick
`MAX_DENTS`.

⚠️ **A GAP NOBODY HAS NAMED: the SHIPPED default mode has never been in a fairness run.**
`GameLaunch.game_mode` defaults to **OPTION_B** (downed/seal). `ai_probe` *forces* OPTION_A
for fairness runs and `push_error`s if it is not set — correctly, since under OPTION_B
`hitbox.gd` never takes the dent branch and the dents column would measure nothing. The
consequence is that **every fairness figure in this log, and both round-win levers argued
from them, describe OPTION_A** — while OPTION_B's own offence paths (all-Sealed, and
`FALL_LIMIT` 4 knockdowns) have no measured rate at all. This is what the session brief means
by needing R-08's variants beside the tag fix, and it is the larger of the two holes.

#### R-06 leg 3 · MEASURED, AND THE HANDOVER IS THE OPPOSITE OF THE ONE ABOVE, 2026-07-30 — 🥊 PHYS. `phys_probe -- band`

**The can steps out of the way and then comes back before the lob lands. The sidestep is
the right size and it is not being HELD.** Leg 3's original diagnosis — a lateral step too
small for a vertical drop — is refuted on its own numbers.

Why it needed measuring at all: the diagnosis rested on "`CAN_EVADE_STEP` 1.2 m against a
~0.52 m band", and **the 0.52 was measured nowhere.** It is near `ai_controller.gd`'s
arithmetic for a different quantity (hurtbox 0.17 + `throw_flick`'s hit_radius 0.30 = 0.47)
and neither matches the 0.45 capsule radius in `CharacterBase.tscn`. Three numbers, none of
them the band. And the argument on top of them predicted the opposite of leg 3 twice over:
a lob's flight is 0.86–1.10 s against a flat throw's 0.32, and `CAN_EVADE_LOOKAHEAD` caps
the warning at 0.6 s for both — so the can gets **more** dodging time against a lob and
still gets hit more.

**PHASE 1 — THE BAND.** Can PARKED at a fixed lateral offset; the throw aimed at the
**MARK**, never at where the can actually is, because that is what a sidestep is — the arc
is committed before the can moves.

| throw | contact out to | none from | band half-width |
|---|---|---|---|
| flat | 0.30 m | 0.45 m | **0.30–0.45 m** |
| LOB | 0.45 m | 0.60 m | **0.45–0.60 m** |

Geometry **read off the live nodes, not restated**: hurtbox world r = **0.170**, hit_radius
**0.300**, sum **0.47** — which is exactly where contact stops. So the closest-approach
column and the contact column are two independent measurements of one band and they agree.

⚠️ **`CAN_EVADE_STEP` AIMS 2.7× THE LOB'S BAND.** The step is not too small. The lob's band
*is* 0.15 m wider than the flat throw's — a descending slipper sweeps a longer footprint
through the capsule, a real effect — and 0.15 m against a 1.2 m step is not a cause.

**PHASE 2 — THE DODGE ACTUALLY ACHIEVED.** Can starts ON the mark, controller LIVE, 10
throws each:

| throw | contact | peak perp | **at the closest frame** | flight |
|---|---|---|---|---|
| flat | **0%** | 0.82 m | **0.72 m** | 0.44 s |
| LOB | **80%** | 0.84 m | **0.31 m** | 1.40 s |

**The can performs the same sidestep against both throws** — 0.82 vs 0.84 m of peak
displacement — and against the lob it is back within **0.31 m** of the mark by the frame the
slipper is closest. It steps out and walks home during the lob's long tail. Peak and
at-closest are sampled **on one frame** for exactly this reason: peak alone reads a dodge
that happens too EARLY as a dodge that worked.

⚠️ **PHASE 1 PREDICTS PHASE 2 IN BOTH ROWS** — 0.72 m clears a 0.30 m band so the flat
throw misses; 0.31 m sits inside a 0.45 m band so the lob connects. Two independent
measurements agreeing is what makes either one usable.

**HANDOVER TO ⚖️ BALANCE — `ai_controller.gd`, not this lane's file:**

1. ⚠️ **DO NOT WIDEN `CAN_EVADE_STEP`.** It is already 2.7× the band. Widening it moves the
   peak, and the peak is not the problem.
2. **The sidestep has to be HELD until the threat is gone.** `_act_evade` re-derives its
   target from the can's *current* position every tick (`character.global_position + side *
   CAN_EVADE_STEP`), so the step is re-aimed rather than completed, and hold-the-circle
   reclaims it as soon as the tree stops choosing evade. Against a 0.32 s flat throw there
   is no time for that to matter; across a 1.10 s lob there is.
3. **`Carriable.flight_is_lob` is the flag to branch on, and the PHYS side is done** — it is
   set on every peer from the launch broadcast (`_rpc_set_flying`), so the can can answer a
   lob without re-deriving it from the trajectory. Verified present, replicated, and
   meaningful only while FLYING.
4. Spending the lob's extra warning on **Guard** remains the other option and is untouched
   by this measurement — Guard blocks dents outright, and the probe counts contact from
   `landed_on`, which fires regardless.
5. ⚠️ **The function is `_act_evade`, not `_act_can_evade`.** Both the leg-3 note and
   `_lane_verdict`'s printed diagnosis named a function that does not exist; corrected in
   the probe.

**`AIController.ATTACKER_LOB_OVERHOLD` → `Carrier.LOB_OVERHOLD_TIME`: the PHYS half is
already in place.** `LOB_OVERHOLD_TIME` is public and its own doc says the AI must read it
rather than restate 0.20. One `const` line in `ai_controller.gd` closes it; the values agree
today by coincidence and should agree by construction.

#### R-18(b) · THE LUCKY FALL ON TWO REAL PEERS — [x] PASSES. THE FINDING WAS THE INSTRUMENT, 2026-07-30 — 🥊 PHYS

**`downed_lucky` DOES apply on a remote peer. It always did.** The row above it that said
otherwise — *"the client that owns that can reports `last_fall_scored == true`, 0 of 28 of
its own knockdowns"* — was reading a **hardcoded constant**, not the flag:

```gdscript
# tools/aim_probe.gd, as it stood
"flag_scored": can.last_fall_scored if _net_host else true,
```

On a client that `true` is a literal, and the classifier forty lines below turns it straight
back into a verdict — `mark = "L" if not flag_scored else "S"` — so a client could only ever
print `S`. **0 lucky in 28 at a pinned chance of 0.5 is p ≈ 3.7 × 10⁻⁹**, which is the
impossible number that should have condemned the metric the first time rather than the
mechanic. Fifth harness fault caught by that rule alone; the tally in the session brief was
four.

⚠️ **`_net_host` was the wrong question.** `_apply_hit_result` is an `rpc_id` to
`target.get_multiplayer_authority()`, so the peer that is *told* the kind is the peer that
**OWNS** the can — for a client-owned lata that is the CLIENT. The client was the one machine
holding first-hand evidence and the harness discarded it. The cause was one sentence in the
probe's own header, *"no other peer is ever told the flag at all"*, read one step too far: the
owner is a peer too. Both the sentence and the code are corrected.

**Re-measured, `aim_probe.tscn -- net --host` / `-- net --join=127.0.0.1`, headless, chance
pinned to 0.50:**

| | knockdowns | lucky | scoring |
|---|---|---|---|
| HOST, all rows | 42 | 19 | 23 |
| HOST, on the CLIENT-owned can | 21 | — | — |
| CLIENT, on the can it OWNS | 19 | **7** | 12 |

- **The cross-peer test: 19/19 identical.** Host roll vs client applied flag, on the same can,
  every row. Was 0/28 agreeing before.
- **The host's within-machine check: 21/21.** New column. On its OWN can the host holds both
  facts — the roll it made and the flag `call_local` wrote — and they cannot legitimately
  disagree on one machine. This is the half a cross-peer diff cannot answer, and it separates
  "the wire is wrong" from "the mechanic is wrong".
- 7 lucky in 19 at 0.50 is p ≈ 0.18 two-sided. Ordinary.

⚠️ **ALIGN BY SUFFIX, PER CAN — 42 vs 39 IS NOT A DISCREPANCY.** The host starts driving when
its own ready-up returns; a client's `_net_watch_can` is not assigned until `_net_observe()`
runs, so it legitimately misses the first knockdown or two. Filter both logs to one can name,
then slide the shorter sequence along the longer: agreement scored **11, 12, 19** at offsets
0, 1, 2, so the offset is the unique maximum and not a choice. Documented at the print site.

⚠️ **THE `_apply_hit_result` KIND TRACE THE HANDOFF ASKED FOR WAS NOT NEEDED, and the reason
is structural rather than a shortcut.** "The RPC did not arrive" is already excluded: `state`
replicates FROM the can's authority outward, so a DOWNED row observed on *any* peer proves
`go_downed()` ran on the owning peer, and `go_downed` is reachable only from
`_apply_hit_result`. And `last_fall_scored` has exactly one writer in the codebase
(`character_base.gd:1244`), so on the owning peer that flag **is** the kind, one to one.
Reading it correctly is strictly stronger evidence than a print — it is the applied result
rather than the received argument — and it costs no edit to `character_base.gd`, which is a
shared-lock file and an R-30 debug-removal target.

#### CHARACTER TRAITS · VERIFIED END TO END, 2026-07-30 — 🥊 PHYS. `phys_probe -- traits`

Human ask: *"can u make sure the change in stats actually work? in character selection?"*
**Nothing had ever asked.** All three were built as "one multiplier at one site that already
existed" — the right design, and also the shape that fails silently, because a scalar folded
into an expression yields a plausible number whatever the scalar is.

Measured against the OBSERVABLE, not the multiplier — a `trait_speed_scale() == 1.10`
assertion proves only that arithmetic works — and the roster → character chain is checked
separately, by setting `character_index` to a real roster entry rather than by writing the
multiplier:

| trait | roster → `trait_points()` | observable | 1 / low | 3 | 5 |
|---|---|---|---|---|---|
| **BILIS** | ok at 1, 3, 5 | metres walked in 60 frames | 4.90 m | 5.50 m | 6.10 m |
| **LAKAS** | ok | m/s of shove its own Hitbox produces | 2.92 | 3.40 | 3.88 |
| **TATAG** | ok | m/s kept of a 10.0 shove | 10.75 (at 2) | 10.00 | 8.77 |
| **TATAG** | ok | stagger worn | 0.2688 s (at 2) | 0.2500 s | 0.2193 s |

**VERDICT: all three reach the character and change an observable.** Full spread is 1.20 m
of walk, 0.95 m/s of shove and 1.98 m/s of absorbed knockback. 🧑 **Whether that is enough to
FEEL is a human call** — the per-point steps are deliberately small (`character_base.gd`:
"a party game cannot afford a pick that is simply correct").

Two things the measurement turned up:

- ⚠️ **The Person roster carries no TATAG 1**, so the sturdiest-to-frailest spread a player
  can actually pick is 2 → 5, not 1 → 5. Worth knowing before anyone reasons about "full
  range".
- ⚠️ **`apply_stagger` uses `max(_staggered_time_left, duration / grit)`, so TATAG is
  invisible on every hit that lands inside an existing stagger** — a shorter flinch cannot
  replace a longer one already running. Flagged, not changed: whether a stagger should
  refresh or extend is a balance call with no play notes behind it.

Two harness faults were fixed on the way, both caught by the impossible-number rule rather
than by inspection: the walk test did not re-place the unit between runs, so it walked into
the dressing and reported the SLOWEST pick travelling furthest (4.90 / 2.80 / 0.00 m); and
the stagger test did not clear `_staggered_time_left`, so `max()` swallowed every shorter
value and reported an identical 0.2500 s at every TATAG while the knockback divisor beside
it was plainly working.

#### HANDOFF — R-09 (the difficulty picker) to the 🖥️ UX lane

**The mechanism is complete and measured; only the screen is missing.**
`AIController.DIFFICULTY_TIERS` (BATA / NORMAL / ASTIG) and `apply_difficulty()` have been correct
and unreachable — ⚠️ **nothing outside that class called `apply_difficulty()` until
`tools/ai_probe.gd`'s `tier=` argument did on 2026-07-30**, which is why no tier but NORMAL had ever
been measured. See RUN 12 below for the three rows.

- **One three-way picker on `MatchSetup.tscn`, beside map and mode.**
- ⚠️⚠️ **IT MUST RIDE THE SAME HOST-OWNED BROADCAST PATH MAP AND MODE ALREADY TAKE** (`10.5` U-8).
  Do not invent a second path. **A per-peer difficulty is exactly the bug U-8 fixed twice already**,
  and it fails silently: each peer's own bots play at that peer's setting and only the host's
  actually decide the match.
- Persist in `SettingsManager` alongside the other preferences; apply **once at match start** by
  calling the static `AIController.apply_difficulty()`, which every controller in the process then
  follows because the knobs are `static var`s.
- **Acceptance:** `lobby_probe` extended — two peers started on deliberately opposite difficulties,
  the client ends on the host's. Same shape as the map/mode assertion it already makes.
- Copy note: the tier names are already Filipino and already carry the characterisation — *bata* the
  kid, *astig* the one who wins. They do not need translating in the UI.

#### HANDOFF — R-09's REMAINING ACCEPTANCE, from 🖥️ UX to the 🌐 NET lane (2026-07-30)

**The picker is built and shipped** (`ux/onboarding-readability` @ `59871e6`, branch not yet merged).
**One acceptance clause is not run, and the UX lane cannot run it**: `tools/lobby_probe.gd` is the NET
lane's file and read-only here.

**What to assert:** start two peers on **deliberately opposite** difficulties; **the client must end on
the host's**. Exactly the shape of the map/mode assertion `lobby_probe` already makes — add a third
field to it rather than a new probe.

**What to read, so this is not re-derived:**
- `scripts/ui/match_setup.gd` — `DIFFICULTIES` (~line 114), `_difficulty_index` (~181),
  `_apply_difficulty()`, `_cycle_difficulty()`. Clients apply with `persist = false`.
- The value rides the **existing host-owned path, at TWO call sites**, and both matter:
  `_rpc_sync_config` (host changed something) **and** `_rpc_sync_state` (the welcome packet — the only
  thing that configures a peer joining a lobby nobody touches afterwards). ⚠️ **If only the first is
  asserted the probe passes while a silently-joined peer keeps its own tier.**
- `SettingsManager.ai_difficulty` / `set_ai_difficulty()` (stores **and** applies), `[match]` section.
- Applied once at match start via the static `AIController.apply_difficulty()`; the knobs are
  `static var`s, so every controller in the process follows.

⚠️ **WHY THIS IS WORTH A REAL ASSERTION AND NOT A GLANCE:** a per-peer match-affecting value is the bug
**U-8 fixed twice**, and it fails *silently* — each peer's bots play at that peer's setting and only the
host's actually decide the match. Nothing on screen looks wrong.

**Also for 🌐 NET — R-26's lobby half is the blocker on the UX half.** The UX lane stopped at the
boundary deliberately; `tools/lobby_probe.tscn` was not touched.

#### FILED, NOT RUN — R-21's confinement-size sweep

**The heatmap half of R-21 is done (RUN 13 below). The SIZE SWEEP is blocked on file ownership and
is filed here rather than half-done.**

`CharacterBase.CONFINEMENT_RADIUS` is a `const` (`character_base.gd:115`) and `character_base.gd` is
a **shared-lock** file that the balance lane may not write. Sweeping it needs exactly two things,
and both belong to whoever takes that lock:

1. Promote it to a `static var` keeping the `const` as the documented baseline — **the identical
   shape R-01 just used for `TAYA_BLOCK_STANDOFF`**, which took one edit and closed a question three
   runs old. Then `tools/ai_probe.gd` gains `confine=` in one line beside `standoff=`.
2. ⚠️ **The chalk follows the physics automatically but only via a REBUILD.** Both map builders read
   the constant (`build_eskinita.py`, `build_bayan_plaza.py`), and both emit their `.tscn`
   **wholesale**, so each row of the sweep needs the builders re-run and the maps re-imported. A row
   measured without rebuilding is a row where the physics box and the drawn box disagree — which is
   precisely the RUN 3 defect, re-introduced by a test.

Sweep {4.0, 5.0, 6.0}. ⚠️ **The arena FOOTPRINT stays the original size — standing decision, not
open.** ⚠️ **The SIZE CALL IS THE HUMAN'S**, and RUN 9 is the reason to be careful with it: the
defence's two instant-tag geometries are both distance relationships between
`CONFINEMENT_RADIUS`, `taya_block_standoff` and `ATTACKER_THROW_RANGE`, so changing the box moves
all three at once.

## Already done — the ledger this list replaces

Kept short on purpose; the detail is in `Handoff.md` §4 and `Handoff.md`.
Everything here was re-verified against the code on 2026-07-27 and is **not**
simply carried forward from the previous pass's checkboxes.

| | Item | Note |
|---|---|---|
| `[x]` | LAN host/join, spawning, replication, late-join sync | Runtime-verified headless, two instances |
| `[x]` | Bo5, role swap, 90s round, win reporting, match reset | |
| `[x]` | FPP/TPP camera directive, enforced by `assert` + grep | A-1, A-2 |
| `[x]` | Theme, main menu, play menu, settings, pause, match result | |
| `[x]` | **HUD to `Dev_Plan.md` §4.4** | Bo5 pips, role-coloured panels, framed timer with urgency states, LATA card, YOU card, FPP-only crosshair. Verified by render — including the crosshair, re-rendered 2026-07-28 (six runs, `match_fpp.png`, zoomed crop of screen centre) by 🔧 build-ux after **B-86** filed it absent. Could not reproduce the absence; see `Handoff.md` B-86 for the full account. |
| `[x]` | **Round beats — verified present, 2026-07-28** | The design-lane brief listed the role-swap card, the downed vignette, the impact burst and the slipper spin as "still placeholder". **All four already exist.** `RoleSwapCard.tscn` + `role_swap_card.gd` run the full §4.6 timeline (result banner → panels slide in on a BACK/EASE_OUT overshoot and recolour to the *incoming* roles → "ROUND N — FIGHT!" wipe → reset); `%DownedFlash` carries `assets/ui/downed_vignette.gdshader`, a real radial vignette, not a flat rect. Confirmed by rendering the card mid-timeline. Nothing to do here. |
| `[x]` | Lobby with ready-up (B-13) | U-4 |
| `[x]` | Role-swap intermission card | U-3 |
| `[x]` | `.obj` generator toolchain, deterministic | M-1 |
| `[x]` | Lata — revolved body, 3 dent states, knocked-down tilt | M-2. Reads as a can; verified by render. |
| `[x]` | Tsinelas mesh — extruded sole, real Y-strap | M-3. Geometry good; **scale is question 1.2.** |
| `[x]` | Flat toon shading + ink outline on Props | M-4 |
| `[x]` | Walk/run locomotion from velocity | M-5 step 4 — **docs saying "only idle is wired" are stale** |
| `[x]` | In-world nameplates: ground rings, tags, role colour, fade | U-6, **repaired v4.22** |
| `[x]` | FPP viewmodel — eye height, held-object position | **repaired v4.21** |
| `[~]` | Carry / charge-throw / grab / reset channel | T-1…T-3. Loads, runs — Phase 0. |
| `[~]` | Both round-win modes | Wired end to end, never human-verified |
| `[~]` | Release export preset | Correct, unrunnable — 5.1 |

---

## If time runs short

A stated, reasoned cut beats a silently unfinished feature. In descending order
of what to sacrifice, using `Dev_Plan.md` §5's fallback trigger as the template:

1. **Cut Bayan Plaza (2.4).** One map, finished and dressed, beats two
   grey-boxes. This is the first and cheapest cut.
2. **Cut character select (3.3)** down to a fixed, hand-picked matchup, and
   pick the three most distinct Props. The six specials still exist as data.
3. **Cut the Person accessory meshes (2.3 step 2)**, keep the palette retint.
   Silhouette reads at arena distance; detail does not.
4. **Cut off-screen indicators (3.4)** only if 0.4 says FPP awareness is
   survivable without them. If it says otherwise, cut a map instead.
5. **Never cut:** audio (4.1), the dressed boundary and base circle (2.2), the
   real-device LAN test (6.1), or the trailer and demo video (6.3, 6.4). A
   silent, grey-boxed, untested build with no video loses to a smaller one that
   has all four, and the moodboard-fidelity work is itself a scoring lever — a
   game that looks like its own concept art reads as finished even where it is
   narrower.

**The fallback trigger still stands:** if LAN is not stable and fun on real
hardware by the halfway point of the remaining schedule, pivot to single-PC
shared-screen. Budget **one to two days** for that pivot, not half a day — four
viewports, and only one player per machine can mouse-look, so both FPP Persons
would fall back to `AimSource.MOVEMENT`. If the pivot looks likely, take it
early.
