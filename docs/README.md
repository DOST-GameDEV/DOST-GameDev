# The docs, what each is for, and which one wins

There are **eight**. This file exists so nobody has to guess which is current, and so two
documents disagreeing is a bug with an owner rather than a thing you work around.

## Source of truth — in order

When two documents disagree, **the one higher in this list wins.** Fix the lower one in the same
commit rather than leaving both standing.

| # | Document | Authoritative for |
|---|---|---|
| 1 | **The running build** | Anything about what the code *does*. A doc claim beaten by a render or a run is wrong — the build is not. |
| 2 | [`Checklist.md`](Checklist.md) | **What is done and what is next.** Every `[x]` / `[~]` / `[ ]` state. |
| 3 | [`Concurrency_Protocol.md`](Concurrency_Protocol.md) | Lane ownership, the shared-file lock, the smoke gate, merge rules. |
| 4 | [`Art_Direction.md`](Art_Direction.md) | Palette, proportion, moodboard record, environment kit, art queue — **and the demo/trailer direction** (Part 5). |
| 5 | [`Dev_Plan.md`](Dev_Plan.md) | Standing directives, phase plan — **and the GDD** (appendix), which owns game-design intent. |
| 6 | [`Handoff.md`](Handoff.md) | Task-block history (`M-`, `U-`), **open bugs in §3**, and the fixed-bug archive (appendix). |

## The other two

| Document | What it is |
|---|---|
| [`Agent_Prompts.md`](Agent_Prompts.md) | Paste-ready lane openers — **current set at the top**, historical prompts and five merged lane briefs below. |
| [`SHARED_LOCKS.md`](SHARED_LOCKS.md) | The mutex. Six files, one line each. **Deliberately its own file** — a lock claim must be a commit that touches nothing else, or the push-rejection mutex stops working. |

> ### What was merged, 2026-07-28
>
> Nineteen files became eight. `Art_Plan_Next_Stage`, `Design_Agent_Brief`, `Environment_Kit_Spec`
> and `Environment_Art_Agent_Brief` → **`Art_Direction.md`**; `Demo_Script_and_Trailer` → its
> Part 5. Five `*_Agent_Brief` files → **`Agent_Prompts.md`**'s appendix.
> `Tumbang_Preso_2v2_GDD` → **`Dev_Plan.md`**. `Bug_Ledger` → **`Handoff.md`**.
> `Handoff_Prompt_Design_Next` deleted outright. Every reference in `docs/`, `scripts/` and
> `tools/` was rewritten; nothing points at a file that no longer exists.

---|---|---|
| 1 | **The running build** | Anything about what the code *does*. A doc claim beaten by a render or a run is wrong, not the build. |
| 2 | [`Checklist.md`](Checklist.md) | **What is done and what is next.** Every `[x]`/`[~]`/`[ ]` state. |
| 3 | [`Concurrency_Protocol.md`](Concurrency_Protocol.md) | Lane ownership, the shared-file lock, the smoke gate, merge rules. |
| 4 | [`Art_Direction.md`](Art_Direction.md) | Palette, proportion, moodboard record, environment kit, art queue. |
| 5 | [`Dev_Plan.md`](Dev_Plan.md) | Game design intent — the rules of the game itself. |
| 6 | [`Dev_Plan.md`](Dev_Plan.md) | Standing directives and phase plan. Older; defer to 2–4. |
| 7 | [`Handoff.md`](Handoff.md) | Task-block history (`M-`, `U-`, `B-`) and the open bug ledger §3. |

## The rest

| Document | What it is |
|---|---|
| [`Agent_Prompts.md`](Agent_Prompts.md) | Paste-ready lane openers. **Current set at the top**, historical prompts and the five merged lane briefs below. |
| [`Art_Direction.md`](Art_Direction.md) | Checklist 6.2 — live-demo running order, failure ladder, trailer beats. |
| [`Handoff.md`](Handoff.md) | Archive of B-01…B-66, all fixed. Open bugs live in `Handoff.md` §3. |
| [`SHARED_LOCKS.md`](SHARED_LOCKS.md) | The mutex. Six files, one line each. |

---

## The moodboard is a reference, not a contract

**It is fine — expected, even — that the build no longer follows parts of the moodboard.** The
board was made before anything existed. Some of it turned out to be wrong for the game, some
described mechanics that were never built, and some has simply been superseded by decisions made
with the thing actually running.

**You do not need permission to diverge from it. You need to write down that you did, and why.**
A deviation recorded in the file that implements it is a decision; a silent one is a bug nobody
can tell from a mistake.

Deviations already taken, all deliberate:

| Moodboard says | Build does | Why |
|---|---|---|
| Character render: yellow/blue/orange school outfits | Green sando + maroon top, no orange or blue anywhere on a Person | `Dev_Plan.md` §4.2 rule 1 — orange and blue mean **role**, never team or decoration. The board's own outfits would have broken the one colour rule the game cannot bend. |
| Role cards: navy 3px border **and** a 6px colour bar | Full role-coloured border, no separate bar | `StyleBoxFlat` has one `border_color` for all four sides; Godot has no per-side border colour. The full outline also reads better at HUD scale. See `ui_theme.gd::card_style()`. |
| THE ATTACKER: aiming arc (mouse pointer trail) | Not built | B-45. Never a build order — an illustrated idea, flagged as a decision. |
| THE DEFENDER: lata reset channel (progress bar) | Not built | B-46, same. |
| THE SLIPPER card accent: magenta | Sole is `IMPACT` magenta ✅ | This one the board got right and an internal table got wrong — see B-81. |
| Props drawn hero-scale | Being brought toward real scale | The board had no environment to be out of proportion *with*. See `Art_Direction.md` §1. |

**The two things that are not negotiable**, moodboard or not: the role-colour rule (orange =
offense, blue = defence, tracking role) and legibility at arena distance. Everything else is a
judgement call you are allowed to make — record it and move on.

---

## Known contradictions, and how they were resolved

Kept visible rather than quietly patched, because each one cost real time to find.

| Contradiction | Resolution |
|---|---|
| **5.3 says strip Local Match and the debug switcher. `Art_Direction.md` §3 makes the local harness demo-failure-ladder rung 3** — the only fallback that needs no network. | **Keep the harness, gate it behind a launch argument, strip only the on-screen debug overlay.** That satisfies 5.3's real intent (the build must not *look* like a prototype) without deleting the only network-free demo path. `Checklist.md` 5.3 now carries this. |
| **M-6 step 3 says environment pieces get no outline.** The Persons got one in 2.3, leaving two art styles in one frame. | Deliberately reversed for **large silhouette pieces only**. Attempted via `material_overlay` and reverted — that cannot draw an inverted hull. See `Art_Direction.md` Part 1 §6 for the two viable routes. |
| **Docs repeatedly claimed "only `idle` of 32 clips is wired".** | Stale since M-5 step 4. `_play_locomotion()` selects idle/walk/sprint from horizontal velocity. Corrected in `Checklist.md`, `Dev_Plan.md` and `Art_Direction.md`. |
| **`Checklist.md` claimed the FPP crosshair was "verified by render".** | It was never there. Filed as **B-86** and the row corrected. A row asserting verification that never happened is worse than the missing feature. |
| **Round-swap card, downed vignette, impact burst and slipper spin were described as placeholder.** | All four already shipped. Confirmed by driving the card through its timeline. Corrected 2026-07-28. |
| **`Dev_Plan.md` §6 bumps `config/version` every gameplay commit; two lanes make that conflict forever.** | Documented amendment in `Concurrency_Protocol.md` §4: feature commits do not bump, **the merge does**. |
| **`Concurrency_Protocol.md` §0 assigns 2.3 to Sonnet; it was done by the design lane.** | Ownership follows whoever the human points at the task. The protocol's table is a default, not a claim about history. |

**If you find another, add a row here in the same commit that fixes it.**
