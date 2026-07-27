# Submission Agent Brief — trailer, demo video, synopsis, forms

**Split by design, because this workstream needs two different hats:**

| Part | Run on | Checklist |
|---|---|---|
| **Creative direction** — what to show, in what order, in how long | **Opus 5, high effort** | **6.2** |
| **Capture, edit, drafting, bookkeeping** | **Sonnet 5, medium effort** | 6.3, 6.4, 6.5, 6.8 |
| **Signing and uploading** | 🧑 **human only** | 6.6, 6.7, 6.9 |

**Lane:** 📦 Producer for the drafting and bookkeeping (docs-only, safe to run alongside
everything); 🎨 Design for 6.2's direction. **Paste-ready openers:**
[`Agent_Prompts.md`](Agent_Prompts.md).

---

## 0. The framing that matters

This is a submission to a **judged** challenge, not an open-ended project. A technically complete
but unmemorable or unreliable demo loses to a tighter, better-presented one.

**A judge who never plays the build sees only the trailer and the demo video.** Those two artefacts
carry the entire submission for most of the people scoring it. They need their own pass — not a
phone recording of a debug session with the `DebugBar` visible along the bottom.

`Dev_Plan.md` §6 and GDD §9 both treat this as real scope. Budget it like a feature.

---

## 1. Read these first

1. **[`Checklist.md`](Checklist.md)** — Phase 6 in full, and the "If time runs short" cut list at
   the bottom.
2. **`Tumbang_Preso_2v2_GDD.md`** §9 (the submission checklist), §10 (settled theme decisions), §1
   (the pitch, in the team's own words), §6 (the esports/spectator layer).
3. **`Dev_Plan.md`** §5 Phase 6, §6 (the fallback trigger).
4. **`Handoff.md`** §0.10 for what is actually built right now, so the trailer does not promise
   something that is not in the build.
5. **[`Concurrency_Protocol.md`](Concurrency_Protocol.md)** if any other lane is running.

---

## 2. 6.2 — the demo script and trailer beat sheet · **Opus, high**

⛔ **Blocked on checklist 2.2.** There is no point scripting shots of a grey box.

This is the Opus item, and the reason is that it is editorial judgement under a hard constraint:
**what do you show, in what order, in ninety seconds, to people who will never play it?**

Produce two artefacts:

- **A live-demo script.** What gets shown, in what order, in how many minutes, **and what the
  fallback is if a peer drops mid-demo.** Rehearse it. Demo-day reliability is a feature — a crash
  or a desync in front of judges costs more than a missing map, and this is the document that keeps
  a bad moment from becoming a bad impression.
- **A trailer beat sheet** the Sonnet lane can shoot against: shot list, order, rough durations,
  what each shot has to communicate, and the one image the whole thing has to land.

**What the game is actually about, and what the trailer has to sell:** a can standing in a circle,
a slipper thrown at it, and the scramble to get the slipper back before you are tagged. Not
"3D arena brawler". The retrieval scramble is the tension of the street game and it is what makes
this entry different from every other arena game in the competition.

---

## 3. 6.3 / 6.4 — capture and edit · **Sonnet, medium**

⛔ Blocked on 6.2, and on 2.2 (a real map) and 4.1 (audio).

- **Trailer: 1–2 min, loopable.** Shoot 6.2's shot list.
- **Demo video: 3–5 min, narrated or captioned, `.mp4`.** A walkthrough against the same script.
- **`tools/arena_camera.gd` was deliberately preserved for exactly this.** It is ~100 lines of
  working follow/framing maths, moved out of the gameplay tree at A-2 rather than deleted,
  precisely so the trailer would have a broadcast camera. If you re-instance it, its header states
  the conditions: register targets at **runtime**, never cache `NodePath`s in `_ready()`,
  `is_instance_valid()`-check every frame, default to `current = false`, and ignore any target
  below the kill plane. Ignoring those is what caused **B-03**, the original LAN freeze.
- **Strip the debug surface first.** Checklist 5.3 removes Local Match and the `DebugBar`. A
  trailer with a debug readout along the bottom edge reads as unfinished no matter what is above
  it. If 5.3 has not landed, at minimum shoot from a release build.

---

## 4. 6.5 — the synopsis · **Sonnet (📦 Producer), medium**

Template 01, **500 words maximum**. Two decisions are already made — do not reopen them:

- **Title: TUMBANG PRESO.** The moodboard's lockup. B-27 is closed and the old
  "Tumbang Laro: Isang Laban" is gone from every tracked file.
- **Primary theme: Philippine Games and Sports. Secondary: Circular Economy — take it.** GDD §10
  settled this. The premise is *literally* about reusing everyday objects — a discarded tin can and
  a rubber slipper — as sports equipment. It costs two sentences, needs no build work, and it is a
  scoring lever the rubric offers for free. **Say it explicitly rather than hoping a judge
  infers it.**

Lead with the street game, not the engine. The people scoring this grew up playing tumbang preso.

---

## 5. 6.8 — the Form 03 licence register · **Sonnet (📦 Producer), medium**

**Keep this as a running list from now, not an excavation at the deadline.** Form 03 is an Asset
and AI Usage Disclosure and it needs every third-party asset in the build.

Known already:

| Asset | Source | Licence | Where |
|---|---|---|---|
| Kenney *Mini Characters* (12 `.glb`) | Kenney | **CC0** | `assets/characters/persons/KENNEY_LICENSE.txt` |
| Display + body typefaces | ⛔ checklist 1.1 / 3.1 | **undecided** | must land at `assets/ui/fonts/` with a verbatim licence |
| All audio | ⛔ checklist 4.1 | not yet sourced | prefer CC0 so disclosure is one line |
| Moodboard-derived art | Harry's Canva project | needs a stated position | ask |
| **AI usage** | — | — | **required, and this project used AI agents extensively** |

Note the pattern the repo already uses: the licence file sits **beside** what it covers, verbatim,
named `<SOURCE>_LICENSE.txt`. Follow it. Chase the other lanes as they add assets rather than
reconstructing later.

---

## 6. 6.6 / 6.7 / 6.9 — 🧑 human only

- **Form 01 — Game Development Team Roles.** This form **is** the ownership table in
  `Dev_Plan.md` §6, which is still blank after five passes of asking. It is now a submission
  blocker rather than hygiene. **Chase it; do not fill it in on anyone's behalf.**
- **Form 02 — Waiver and Declaration of Originality, signed by all members.** A model does not sign
  a declaration of originality. Prepare it to the point of signature and stop.
- **6.9 — upload through the official submission link.** Human.

**Prepare these; do not submit them.** They stay marked 🧑 on the checklist for a reason.

---

## 7. Traps

1. **Do not promise what is not in the build.** Check `Checklist.md` before scripting a shot. As of
   the last audit there is one map in progress, no character select, and both round-win modes live.
2. **Shoot a release build, not the editor.** ⛔ Checklist 5.1 — Godot export templates are not
   installed on the machines tried so far, so no `.exe` has ever been produced. That is a human
   task and it blocks a clean capture.
3. **Both round-win modes are still live.** The trailer should show *one* clearly rather than
   cutting between two rule sets — that reads as indecision. Which one leads is checklist 1.5, the
   human's call; ask rather than picking by default.
4. **The nameplate tags fade past 12–18 m** and the `DebugBar` is present in debug builds. Both
   affect framing. Screenshot before you commit to a shot.
5. **Authorship applies to your commits too** — see §8.

---

## 8. Non-negotiables, restated inline

- **Authorship.** Every commit authored and committed solely as
  `M4tyu633 <matthewtlabrador@gmail.com>`. No `Co-authored-by:` trailer, no mention of Claude, an
  AI assistant, or any tool as author or committer anywhere in a commit. Verify with
  `git log -1 --format='%an <%ae> | %cn <%ce>'`. **Note this is about commit metadata and is
  entirely separate from Form 03, which requires AI usage to be disclosed honestly — disclose it.**
- **Verify before claiming `[x]`.** An unshot video is `[ ]`. A shot but unedited one is `[~]`.
- **One concern per commit**, checklist item in the subject.
- **📦 Producer writes only to `docs/`.** No code, no scenes, no assets.

## 9. Reporting contract

Say what is drafted, what is captured, what is edited, and what is waiting on a human signature or
decision. Keep the licence register current in the same commit as any asset change you learn about.
Say plainly what you did not get to and why.
