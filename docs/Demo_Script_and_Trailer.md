# 6.2 · Live-demo script, trailer beat sheet, demo-video outline

**Owner: 🎨 Design (Opus). Executes into 6.3 (trailer) and 6.4 (demo video), which are Sonnet
capture-and-edit passes against this document.**

This is the shot list and the running order. It is deliberately written against **what the build
actually does today**, not against the checklist's intentions — every mechanic named below was
read out of the code or seen in a render, and everything unverified is marked as such.

> ### The one-line thesis
>
> **Tumbang Preso is a playground game about a can, a slipper, and the moment you have to run for
> it.** Every beat below exists to land that sentence on someone who will never play the build.

---

## 0. What is actually demoable today

Verified by running the build on 2026-07-28.

| Thing | State | Notes |
|---|---|---|
| Main menu → map picker → match | ✅ works | Two maps selectable |
| **Eskinita** (dressed alley) | ✅ renders | 30-piece kit, road markings, wires, sari-sari frontage |
| **Bayan Plaza** | ⚠️ built, rendered, **never played** | Checklist 2.4, `[~]` |
| Spawns as two team pairs at opposite ends | ✅ verified | From the map's own `SpawnPoints` |
| Person = FPP, Prop = TPP | ✅ verified | Self-hide works; camera at 1.25 above feet |
| Restyled Persons (2.3) | ✅ verified by render | Read apart at 20 units, no orange/blue |
| Pick up + carry the tsinelas | ✅ verified | Scales to hand size, tracks the arm bone |
| Can: 4 dent states, downed tilt | ✅ in code | Not seen in a live hit |
| Hit flash, impact burst, hitstop | ✅ in code (hitstop v4.30) | Not seen in a live hit |
| HUD: Bo5 pips, role panels, timer, LATA + YOU cards | ✅ renders | |
| Bo5, first to 3, 90 s rounds | ✅ in code | `WINS_NEEDED = 3`, `ROUND_TIME = 90.0` |
| Role swap every round (orange↔blue) | ✅ in code | Intermission card is still placeholder |
| Both win modes (A dents / B seal) | ✅ both wired | Selectable at the menu |
| 2v2 over ENet LAN | ⚠️ **loopback only** | 6.1, real wifi never tested — 🧑 human |
| A runnable `.exe` | ❌ **does not exist** | 5.1, export templates never installed — 🧑 human |
| Anyone having played a full match | ❌ **never** | 0.4 — every tuning number below is a guess |
| Audio | ❌ none | No owner assigned |

**Read that table before promising anything to anyone.** Three of the four rows that a live demo
depends on most — a real LAN test, an `.exe`, and one human playthrough — are human-gated and
none of them has happened.

---

## 1. The live demo — 6 minutes, and why 6

Judges at a booth give you the length of their patience, not the length of your slide deck. Six
minutes is two minutes of watching, three of playing, one of questions. **A full Bo5 at 90-second
rounds is up to 7.5 minutes of match alone**, so the demo must never try to play one out.

### ⚠️ Decision this needs from a human — flagged, not taken

**Build a demo preset with `ROUND_TIME = 45.0` and `WINS_NEEDED = 2`.** A best-of-3 at 45 seconds
is a complete arc — swap, comeback, decider — inside four minutes, and it shows the role swap
*twice*, which is the mechanic nobody understands from a screenshot. At the shipped 90/3 the
audience sees one round and leaves before the swap.

This is not a balance change; it is a presentation preset, and it must not be the submitted
default unless 0.4 says otherwise. **Left undone deliberately — it touches
`scripts/systems/`, which is 🔧 Build's, and it is a judgement call about the submission, not
about art.**

### Running order

| # | Beat | Time | What the operator does | What it proves |
|---|---|---|---|---|
| 1 | **Cold open on the alley** | 0:00–0:30 | Sit on the Eskinita spawn view. Do not move. Say the thesis line. | The game has a *place*. This is the single strongest first impression the build has. |
| 2 | **The four roles, out loud** | 0:30–1:15 | Point at the HUD: orange panel, blue panel, Bo5 pips, the LATA card. "Orange attacks, blue defends, and it swaps every round." | The colour language. Judges will otherwise assume orange/blue are teams. **It is the single most-misread thing in the build.** |
| 3 | **One throw, in first person** | 1:15–2:00 | Person picks up the tsinelas, charges, throws, hits the can. Let the hitstop land. | The core verb. FPP + the slipper + impact in one motion. |
| 4 | **Hand over the controls** | 2:00–4:30 | Two judges, two devices, one round. Operator plays a Prop so a human is never left without an opponent. | It is a *game*, not a diorama. This is the beat that wins or loses the booth. |
| 5 | **The swap** | 4:30–5:00 | Let the round end. Narrate the role swap as the colours flip. | The design idea. Tumbang preso is a game where *everyone* eventually has to be the taya. |
| 6 | **Second map, 15 seconds** | 5:00–5:15 | Quit to menu, pick Bayan Plaza, stand still. Do not play it. | Content breadth without risking an unplayed map. |
| 7 | **Questions** | 5:15–6:00 | | |

**Beat 6 is deliberately a flyby.** Bayan Plaza has never been played by anyone (2.4 is `[~]`).
Showing it standing still is honest and safe; playing it in front of judges is a bet on untested
ground.

### Operator rules

1. **Never demo from a debug build.** The debug switcher's overlay (`F1–F4`, `Tab`, `F5`, `F6`)
   is visible at the bottom of the screen in the current build and reads as an unfinished
   prototype. See §3 for the exception.
2. **The operator always plays a Prop, never a Person.** Props are TPP, so the operator can see
   the whole arena and shepherd a lost judge. A Person in FPP cannot see what a confused player
   is doing.
3. **Never restart mid-crowd.** If it breaks, cut to the fallback ladder without commentary. A
   silent switch reads as a planned segment; a visible recovery reads as a bug.
4. **Say "taya" out loud at least once.** It is the game's actual cultural hook and it costs
   nothing.

---

## 2. Controls card — print this and put it on the table

Read out of `project.godot`. Every player index has its own action set (`_p1` … `_p4`).

| Action | Input | Notes |
|---|---|---|
| Move | `move_left/right/up/down` per player | P1 WASD, P2 arrows in the local harness |
| **Grab / pick up** | `grab` | Picks up a loose tsinelas |
| **Throw** | `special_ability` | Charged — hold and release |
| **Bump / shove** | `bump` | The melee shove |
| **Guard / dash** | `guard_dash` | Contextual by role |

**The moodboard's aiming arc and the lata reset channel are drawn on the role cards but are NOT
in the build** (B-45, B-46, open decisions). **Do not narrate them.** Promising a mechanic a judge
then cannot find is worse than not mentioning it.

---

## 3. Failure drills — the fallback ladder

The checklist calls demo-day reliability "arguably the most important feature". This is that
feature. **Rehearse the ladder before the event, in order, with a stopwatch.** Every rung must be
reachable in under 20 seconds.

| Rung | Situation | Action | Recovery time |
|---|---|---|---|
| **0** | Everything works | Full 2v2 on four devices | — |
| **1** | One peer drops mid-match | **Finish the round.** Do not stop to explain. Narrate over it. | 0 s |
| **2** | A peer cannot rejoin | Quit to menu, restart the match with the operator covering the empty slot | ~15 s |
| **3** | LAN is unusable (venue wifi, AP isolation) | **Single machine, local 4-unit harness**, operator cycles units with `Tab` | ~20 s |
| **4** | The build will not run at all | **Play the trailer on loop.** Have it on the machine, not on a URL. | ~10 s |

### ⚠️ Two things this ladder needs, neither of which exists yet

1. **Rung 3 depends on the local harness, which checklist 5.3 wants stripped before submission.**
   These two requirements are in direct conflict and nobody has noticed. **Recommendation: keep
   the local harness, gate it behind a launch argument rather than deleting it, and strip only
   the on-screen debug overlay.** That satisfies 5.3's real intent (the build must not *look*
   like a prototype) without removing the only fallback that does not need a network.
   **Flagged, not done — `scripts/` is 🔧 Build's lane and 5.3 is blocked on 0.4 anyway.**
2. **Rung 4 depends on the trailer existing (6.3), which depends on this document.** So the
   trailer is not just a submission asset; it is the demo's own safety net. Cut it early.

### What happens today when a peer drops

**Unknown, and that is a finding.** There is no disconnect handling that anyone has demonstrated,
no bot to take over an abandoned unit, and no test has ever been run over a real network (6.1).
**Rungs 1 and 2 above are written as intentions, not as verified behaviour.** Someone must sit
down with two machines, pull the cable mid-round, and write down what actually happens. That is a
🔬 QA task and it should be filed before the trailer work starts.

---

## 4. Trailer beat sheet — 6.3, 1–2 minutes, loopable

**Target: 75 seconds.** Loopable means the last frame cuts to the first without a bump — so it
opens and closes on the same empty-alley composition.

`tools/arena_camera.gd` was preserved for exactly this: 100 lines of working broadcast-framing
maths. Use it for the spectator shots rather than hand-flying a camera.

| # | Beat | Length | Shot | Audio bed |
|---|---|---|---|---|
| 1 | **Empty alley** | 0:00–0:06 | Slow push down Eskinita. No UI. Hold the emptiness. | Street ambience alone |
| 2 | **The can, alone in its circle** | 0:06–0:12 | Low, close, the lata standing in the base decal | A single tin *tink* |
| 3 | **Title** | 0:12–0:17 | Logo lockup over the alley, held | Music enters |
| 4 | **Feet, then the slipper** | 0:17–0:24 | Ground-level: a Person runs past, grabs the tsinelas | Rhythm starts |
| 5 | **The throw** | 0:24–0:31 | FPP charge → release → **cut on the hitstop** | Beat drop on impact |
| 6 | **Can knocked down** | 0:31–0:38 | TPP: tilt, dents, impact burst, the scramble that follows | Music opens up |
| 7 | **Chase** | 0:38–0:50 | Spectator arc following a retrieval run down the alley | Peak energy |
| 8 | **THE SWAP** | 0:50–1:00 | Role swap: orange↔blue on the HUD, hard cut to the same players in opposite colours | Music drops to a single held note |
| 9 | **Bayan Plaza reveal** | 1:00–1:07 | One wide of the second map. Static. Beautiful. | Note sustains |
| 10 | **Empty alley again** | 1:07–1:15 | The beat-1 composition, logo re-forms, cut to black | Resolves into beat 1 |

**Rules for the cut**

- **Cut on impacts, not on the beat.** The game's rhythm is the *tink* of a can. Let the edit
  follow the game.
- **No UI in beats 1–7.** The HUD appears exactly once, in beat 8, because that is the beat where
  it is the point.
- **Never show a nameplate close enough to read "TeamAProp".** Placeholder strings on screen cost
  more credibility than a missing shot.
- **Nothing in the trailer may show a mechanic that is not in the build.** No aiming arc.

---

## 5. Demo video outline — 6.4, 3–5 minutes, narrated or captioned

**Target: 4:00.** This is the one a judge watches at a desk, alone, at 1.5×. Structure it so it
survives being skimmed.

| Section | Time | Content |
|---|---|---|
| **Hook** | 0:00–0:20 | The thesis line over the trailer's beat-1 shot. Name the street game. |
| **The premise** | 0:20–0:50 | Real tumbang preso in 20 seconds: a can, a slipper, a taya. Then: "we made it 2v2." **Lead with the Philippine Games angle — it is the brief.** |
| **A round, start to finish** | 0:50–2:10 | One uncut 45–80 s round with captions naming each beat as it happens. **Uncut is the point** — it proves the thing runs. |
| **The role swap** | 2:10–2:40 | Why it exists: everyone has to be the taya. This is the design argument. |
| **Both win modes** | 2:40–3:10 | Option A (dents) and Option B (seal) side by side. **Both are in equal development and the submission must show that.** |
| **Maps** | 3:10–3:30 | Eskinita and Bayan Plaza, one wide each. |
| **Circular-economy close** | 3:30–4:00 | The premise is literally about reusing everyday objects as play equipment. Land it, then the logo. |

**Captions, not narration, if there is any doubt about the audio.** A silent captioned video reads
as deliberate; a video with bad audio reads as rushed.

---

## 6. What must be true before capture starts

Do not begin 6.3 or 6.4 until all of these are true. Capturing against a build that then changes
means capturing twice.

1. **0.4 — someone has played a full Bo5.** Until then every number in the capture is unverified
   and the round you record may be unbalanced in a way that is obvious to a judge and invisible
   to us.
2. **4.1 — the round-beat polish.** Both 6.3 and 6.4 are blocked on it in the checklist, and the
   trailer's beats 5, 6 and 8 are *specifically* the hitstop, the impact burst and the role-swap
   card. Beat 8 currently has no animated card to cut to.
3. **The debug overlay is gone from the captured build** (see §3's flagged conflict).
4. **Nameplates read as intended strings**, not `TeamAProp`.
5. **A decision on audio.** There is none, and it has no owner. A trailer with no audio bed is a
   different edit from one with a bed — decide before cutting, not after.

---

## 7. Open items this document deliberately did not resolve

Flagged for a human, per the brief's rule that a design lane files questions rather than guessing.

| # | Question | Why it is not mine to take |
|---|---|---|
| 1 | Demo preset at `ROUND_TIME 45` / `WINS_NEEDED 2` | Touches `scripts/systems/` (🔧 Build) and changes what a judge experiences as "the game" |
| 2 | Keep the local harness as fallback rung 3 vs. 5.3's strip | Directly contradicts a checklist item; needs the human to pick |
| 3 | What actually happens when a peer drops | Needs 🔬 QA with two machines and a pulled cable. **Nobody has ever tested this.** |
| 4 | Audio — whether there is any, and who owns it | No owner assigned anywhere in the plan |
| 5 | Whether Bayan Plaza is shown at all | Depends entirely on whether 0.4 ever plays it |
