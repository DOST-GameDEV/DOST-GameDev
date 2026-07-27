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

- [ ] **0.1 · HUD charge meter, hold meter and reset-channel bar.** 🤖 Sonnet, medium
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
- [ ] **0.2 · Give each side a real default Prop ability (B-76).** 🤖 Sonnet, medium
      `main.gd`'s `PROP_ABILITY` is `quick_stand.tres` for **every** Prop, and
      `Main.tscn` hardcodes the same. Quick Stand has no `get_throw_profile()`,
      so every throw falls back to `throw_default.tres` and **all three Tsinelas
      identities (Bagsak Bomb, Bakya Bash, Flick Dash) are unreachable in the
      running game.** The whole `throw_profile.gd` design is currently dead
      code. Full character select is 3.3; this is the interim: a per-side
      default so a Can gets a Can ability and a Tsinelas gets a throw profile.
      *Blocks:* 0.4 — you cannot playtest three throw identities that cannot be
      selected.
- [ ] **0.3 · Base circle and throwing line, in the current arena.** 🤖 Sonnet, medium
      The game is named after a can standing in a circle and the circle is
      nowhere in the world. Two floor decals in `Main.tscn`, deliberately
      temporary — 2.2 replaces them properly with map geometry. Do them anyway:
      Option B is unreadable without the base circle, and a tester cannot judge
      throw range with no throwing line.
      *Blocks:* 0.4.
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
- [ ] **1.2 · Prop scale — how big is a lata, and how big is a tsinelas?** 🤖 Opus, high
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
      *Blocks:* 2.1, and the final tuning of `HAND_CARRY_OFFSET`.
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
      **Both modes stay in active, equal development.** This is not a "pick one
      and delete the loser" item and every doc that used to say so has been
      corrected. Both are wired end to end, both are selectable from the main
      menu, both get playtested at 0.4, both get balanced at 5.3. The final
      choice of what ships in the demo is the human's, on their own timeline.
      Kept as its own visible line so it does not quietly disappear — but it
      **blocks nothing** and no item below is allowed to slow down on one mode
      because the other might win.

---

## Phase 2 — Build the world

The largest single lever on how finished this reads, and the phase with the
most internal ordering. **2.1 gates 2.2 gates everything else in the phase** —
you cannot lay out a map from a kit that does not exist, and you cannot tune
HUD contrast or hazard placement against a grey box.

- [ ] **2.1 · The environment kit (M-6).** ⛔ 1.2
      Split deliberately into two briefs, because it needs two different hats:
  - [ ] **2.1a · Kit art direction and piece list.** 🤖 Opus, high
        Which pieces, what silhouette, what proportion, what reads as an
        eskinita rather than as generic low-poly. Corrugated GI-sheet fence,
        sari-sari store front, electric post with drooping wire, laundry line,
        tricycle, bollards, crates, tires; plaza set with a basketball ring,
        which is the actual Philippine plaza. ≤400 tris each, 2-unit grid.
  - [ ] **2.1b · Generate the kit through `tools/models/generate_all.gd`.** 🤖 Sonnet, medium
        Determinism rules unchanged (`Handoff.md` M-1): two runs byte-identical,
        `git status` clean after the second. Convex collision per piece.
- [ ] **2.2 · Eskinita — the first real map (M-7).** 🤖 Opus, high ⛔ 2.1
      Opus rather than Sonnet: the hard question is "does this read as a
      Philippine side street", not "does this scene load". Includes, in one
      coherent pass rather than scattered:
  - [ ] `scenes/maps/Eskinita.tscn`, playable area kept at roughly the current
        40×40 — **do not change arena scale in the same commit as arena art**,
        or a movement-feel regression is unattributable.
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
- [ ] **2.3 · Persons — moodboard restyle (M-5).** 🤖 Sonnet, medium ⛔ 2.1a
      Palette retint toward the moodboard's character render plus two or three
      silhouette-defining accessories. **Steps 1–3 only — step 4 (walk/run
      locomotion) is already done** and the docs claiming "only `idle` of 32 is
      wired" are stale: `character_visual.gd::_play_locomotion` selects
      idle/walk/sprint from horizontal speed.
- [ ] **2.4 · Bayan Plaza — the second map.** 🤖 Sonnet, medium ⛔ 2.2
      A scene swap once 2.2 has proven the pattern. **First candidate to cut**
      under time pressure — see "If time runs short" at the bottom.

---

## Phase 3 — Finish the presentation layer

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
- [ ] **3.4 · Off-screen indicators (U-6b).** 🤖 Sonnet, medium
      Screen-edge arrows for your teammate and the Can. `Dev_Plan.md` §3.3 calls
      these **mandatory** for FPP — they are the promised mitigation for the
      Person's narrower awareness cone — and U-6 deferred them.

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
- [ ] **4.2 · Movement interpolation for remote characters.** 🤖 Sonnet, high
      Remote units visibly snap. High effort because it sits directly on the
      replication model. **Do this before 6.1** — testing over real wifi without
      it measures the wrong thing.
- [ ] **4.3 · Rejoin identity (B-65).** 🤖 Sonnet, high
      A rejoining player can come back as a different team and role. Needs a
      stable player token instead of a peer id. A LAN demo where someone's wifi
      blips is exactly the failure mode judges will see.
- [ ] **4.4 · Balance pass — Guard/Dash, cooldowns, ranges, both game modes.** 🤖 Sonnet, medium ⛔ 0.4
      Never done. Write the numbers down. **Balance both Option A and Option B
      to shippable quality** — per 1.5, neither is deprioritised.
- [ ] **4.5 · Hitstop.** 🤖 Sonnet, medium
      The one piece of the Q-8 hit-feedback set that never landed. Cheap, and it
      is what makes a landed hit feel like contact rather than a colour change.

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
- [ ] **5.3 · Strip Local Match and the debug switcher.** 🤖 Sonnet, high ⛔ 0.4, 4.4
      Run the removal checklist in `Dev_Plan.md` §3.5.5 and confirm the
      verification grep comes back empty. High effort because it touches
      `Main.tscn` and `main.gd`'s spawn paths. **Do it late** — it is the only
      way to playtest without four laptops, so it dies after the last playtest,
      not before.
- [ ] **5.4 · Decide the `.import` UID churn (B-71).** 🤖 Sonnet, medium
      Either accept it or stop tracking `.import` UIDs. Low stakes, but it makes
      every "regenerate and check `git status`" acceptance test unreliable, and
      those are load-bearing for the whole M-block.

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
- [ ] **6.2 · Live-demo script and trailer beat sheet.** 🤖 **Opus, high** ⛔ 2.2
      What gets shown, in what order, in how many minutes, and what the fallback
      is if a peer drops. Demo-day reliability is a feature — arguably the most
      important one. A crash in front of judges costs more than a missing map.
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

## Already done — the ledger this list replaces

Kept short on purpose; the detail is in `Handoff.md` §4 and `Bug_Ledger.md`.
Everything here was re-verified against the code on 2026-07-27 and is **not**
simply carried forward from the previous pass's checkboxes.

| | Item | Note |
|---|---|---|
| `[x]` | LAN host/join, spawning, replication, late-join sync | Runtime-verified headless, two instances |
| `[x]` | Bo5, role swap, 90s round, win reporting, match reset | |
| `[x]` | FPP/TPP camera directive, enforced by `assert` + grep | A-1, A-2 |
| `[x]` | Theme, main menu, play menu, settings, pause, match result | |
| `[x]` | **HUD to `Dev_Plan.md` §4.4** | Bo5 pips, role-coloured panels, framed timer with urgency states, LATA card, YOU card, FPP-only crosshair. Verified by render. |
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
