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
scramble to retrieve it — that **no human has ever pressed a button on.** The
two biggest risks are, in order: *the central mechanic has never been felt*, and
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
(T-1 … T-3) is code-complete and has never been played. Every number in it —
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
- [~] **2.2 · Eskinita — the first real map (M-7).** 🎨 Design — **built, wired and rendered; never played**
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
      human:** nobody has played it, so this stays `[~]`. That is 0.4.
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
- [~] **2.4 · Bayan Plaza — the second map.** 🎨 Design — **built and rendered, never played**
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
- [ ] **3.3 · Character select (U-5).** 🤖 Sonnet, medium ⛔ 1.3, 0.2
      Six Prop cards on U-2's card chrome, selection into `GameLaunch`,
      replicated with ready-up state, read in `_build_networked_character()` in
      place of the hardcoded `PROP_ABILITY`. `.duplicate()` the chosen `.tres`
      or two characters share one cooldown.
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

- [ ] **4.1 · Audio — the entire workstream.** 🤖 Sonnet, medium
      **Nothing exists. Not one `AudioStreamPlayer` anywhere in the repo.** A can
      taking a direct hit in silence reads as a bug to a judge no matter how good
      the mesh is. Minimum viable set: bump, slipper release, slipper impact on
      lata, lata knocked down, reset-channel complete, round win, match win, and
      one ambience loop per map. Licences go on Form 03 with everything else.
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

- [ ] **5.1 · 🧑 Install Godot export templates.** ⛔ HUMAN — environment
      `export_presets.cfg` and `tools/export.md` both exist and are correct.
      The `.exe` has never been produced because
      `%APPDATA%\Godot\export_templates\4.7.1.stable\` is absent on the machines
      tried so far. Editor → Manage Export Templates. **Until this happens,
      F-3's acceptance test and B-67's acceptance test are both unrunnable —
      neither can be honestly ticked.**
- [ ] **5.2 · Produce a release build and confirm it launches to the menu.** 🤖 Sonnet, medium ⛔ 5.1
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
      display and body typefaces from 3.1, every audio asset from 4.1, and an
      AI-usage line. Keep a running list as assets land rather than
      archaeologising at the deadline.
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
      Main routing** from the PR #13 merge, which has never been click-tested.
- [ ] **The held slipper in THIRD person and while WALKING** (B-112). Verified in an FPP render
      only, and clip-dependence was the original bug — so the one pose it was checked in is the
      least informative one.
- [ ] **Bayan Plaza** (8.1h), deferred by explicit human decision.

## Phase 9 · AI FAIRNESS LOG — the running record for balance testing

**Human call, 2026-07-29:** *"Make sure the AI's fulfil their roles as well and try to win (attacker
avoid defender, defender try to tag, etc), log somewhere that we will test fairness thru this and
make changes accordingly."*

**This section is the log.** It is where AI balance findings go, and it is deliberately a *running*
record rather than a one-off writeup — the whole point is that the numbers move as the AI and the
mechanics change, and that nobody has to re-derive last week's result.

### How fairness is measured

`tools/ai_probe.gd` is the harness. It already reports independence and freezing; balance runs
should extend it rather than adding a second tool. The measurements that matter:

| Metric | Why | Fair range |
|---|---|---|
| **Round win rate, attacker vs defender**, over ≥20 rounds | The single number that says whether the sides are balanced at all | 40–60% either way |
| **Time-to-first-throw** | An attacker that dithers is not "hard", it is broken | < 8 s |
| **Throws blocked by the Taya / throws taken** | Is body-blocking doing anything, or is it decoration? | 25–50% |
| **Can dents per round** | Rounds that never resolve are a worse failure than an unfair one | ≥ 1 on most rounds |
| **Longest still-run per bot** | A frozen bot is not a difficulty setting | < 2 s |

⚠️ **A win rate on its own is not a fairness result.** A 50% split where neither side ever scores
and every round times out is not balanced, it is broken twice. Always read it next to dents-per-round.

### Role intent as implemented (2026-07-29) — what "trying to win" currently means

- **Taya (defending Person): BODY-BLOCKS, does not chase.** It used to walk straight at the
  attacker, which the geometry forbids it from ever reaching — the Taya is capped at
  `CONFINEMENT_RADIUS` 5.0 and the attacker throws from the 6.0 line, so chasing parked it against
  the inside of its own box with the can left unguarded behind it. It now stands on the line between
  the can and the attacker at `TAYA_BLOCK_STANDOFF` (2.6), and only closes to melee and taps when
  the threat is genuinely inside the box.
- **Attacker (offensive Person): AVOIDS THE DEFENDER.** It checks whether a defender is sitting in
  the throwing lane (perpendicular distance to the attacker→can line under `ATTACKER_LANE_CLEARANCE`
  1.3) and, if so, slides around the can to the nearest open bearing instead of charging into the
  block. Bearings are sampled outward from the one it already holds, so it edges around rather than
  teleporting its intent to the far side each tick.
- **Can:** holds its circle (`CAN_HOLD_RADIUS` 0.45). Deliberately does not wander — a can that
  strolls off its mark has nothing left to defend and made round resets look like teleports.
- **Tsinelas:** crawls toward its own attacker so the two meet, rather than the attacker crossing the
  whole gap alone.

### ⚠️ Open — not yet measured, and the balance numbers above are therefore UNKNOWN

Nothing in the table has been run yet. The role behaviours above are implemented and verified only
for *independence and liveness* (`tools/ai_probe.gd`: 1/846 frames with two bots changing state
together, longest still-run 1.1 s, no freezes). **Whether they are FAIR is untested**, and the first
balance run is the next AI task.

Known things that will probably need retuning once it is run, recorded now so the first run has
hypotheses to check rather than starting cold:

1. **`TAYA_BLOCK_STANDOFF` 2.6 is a first guess.** Too small and the Taya hugs the can and blocks
   nothing; too large and it leaves a gap behind itself.
2. **`ATTACKER_CHARGE_TIME` 0.65 is fixed**, so every AI throw has identical power. A human varies
   it. If the AI reads as robotic, this is why.
3. **The attacker never dodges an incoming tag** — it only avoids *standing in a blocked lane*.
   Real evasion is a separate behaviour and is not implemented.
4. **`DECISION_INTERVAL` 0.35 jittered 0.75–1.3×** sets reaction time and is the obvious global
   difficulty knob if the bots turn out to be too sharp or too dull.
5. **No difficulty tiers exist.** If fairness testing says the AI is too strong for a demo, the fix
   is a tier that scales `DECISION_INTERVAL` and `ATTACKER_LANE_CLEARANCE`, not one-off nerfs.

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
| `[~]` | Carry / charge-throw / grab / reset channel | T-1…T-3. Loads, runs, **never played** — Phase 0. |
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
