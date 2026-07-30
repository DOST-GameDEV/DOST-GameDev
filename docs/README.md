# The docs, what each is for, and which one wins

There are **eight**. This file exists so nobody has to guess which is current, and so two
documents disagreeing is a bug with an owner rather than a thing you work around.

## Source of truth — in order

When two documents disagree, **the one higher in this list wins.** Fix the lower one in the same
commit rather than leaving both standing.

| # | Document | Authoritative for |
|---|---|---|
| 1 | `Concurrency_Protocol.md` | How lanes coordinate: branching, the shared-file mutex, the smoke gate, commit authorship. Wins over everything on *process*. |
| 2 | `Roadmap.md` | **What is next.** The R- queue. The only place a "do this now" lives. |
| 3 | `Checklist.md` | **Per-phase status and acceptance criteria.** The only place a box is ticked. |
| 4 | `Dev_Plan.md` | Architecture rules and the project-wide colour/role laws. |
| 5 | `Art_Direction.md` | Visual and environment spec: the kit, the maps, the shading split. |
| 6 | `Handoff.md` | Standing decisions, the open bug ledger (§3), and the questions the team owes (§5). |
| 7 | `Agent_Prompts.md` | Paste-ready lane openers and the per-subsystem reference appendices. **Also carries the LANE STATUS BOARD — the one place a lane is marked finished.** |
| 8 | `SHARED_LOCKS.md` | Live mutex state for the six unpartitionable files. |


## Marking a lane finished

One place, one convention: the **LANE STATUS BOARD** at the top of `Agent_Prompts.md`.
Set the Status cell to `🟢 DONE` / `🟡 IN PROGRESS` / `⚪ NOT STARTED` / `🔴 BLOCKED`, and put the
date, the commit hashes and **what was actually verified** in the Evidence cell — in the same
commit as the work. A green cell with an empty Evidence cell is not a finished lane, it is a
claim, and this project has been bitten by those before (§ "never claim a verification you did
not perform").

Every lane prompt below the board is inside a `<details>` block, so the file opens as a
one-screen index instead of three thousand lines of paste-text.

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
| THE SLIPPER card accent: magenta | Sole is `PROP_FOAM` brown, strap `PROP_WEBBING` tan | Superseded, 2026-07-28, by a second asset moodboard the human supplied for this prop specifically: *"the magenta shit is just placeholder."* The board's magenta settled B-81's *rule* (the sole must not wear a role hue) and was never meant to settle the colour. See `Art_Direction.md` §1b. |
| THE CAN card accent: magenta | Sarsi livery — blue body, red sail, aluminium lid | Same second moodboard. The can was always blue-bodied; what changed is that it is now a specific, recognisably Filipino can rather than a generic one. |
| Both prop moodboards: "1024×1024 PBR" | Flat-colour materials, no textures, no UVs | The pipeline emits no UVs and Harry's board's own stated reference (`PEAK`) is flat colour, *not* PBR. Silhouette and colour blocking were taken; the texture maps were not. Consequence: **no printed type on the can** — see `Handoff.md` §5. |
| Props drawn hero-scale | Being brought toward real scale | The board had no environment to be out of proportion *with*. See `Art_Direction.md` §1. |

**The two things that are not negotiable**, moodboard or not: the role-colour rule (orange =
offense, blue = defence, tracking role) and legibility at arena distance. Everything else is a
judgement call you are allowed to make — record it and move on.

---

## Keeping it this way — read before you finish an item

**`Concurrency_Protocol.md` §12 is the rule and it applies to every lane.** In short: tick the
checklist box in the same commit as the work; grep `docs/`, `scripts/` and `tools/` for whatever
your change just made untrue and fix *all* of it, not the nearest one; delete stale content
rather than labelling it outdated; never claim a verification you did not perform; and if you
find two documents disagreeing, fix the lower-ranked one and add a row below in the same commit.

Eight files is the budget. Do not add a ninth without a reason you can defend.

## Known contradictions, and how they were resolved

Kept visible rather than quietly patched, because each one cost real time to find.

| Contradiction | Resolution |
|---|---|
| **5.3 said strip Local Match and the debug switcher. `Art_Direction.md` §3 makes the local harness demo-failure-ladder rung 3** — the only fallback that needs no network. | **Superseded 2026-07-28, not just resolved: Single Player (formerly "Local Match") is promoted to a real, permanent mode that ships in the final build.** The original resolution ("keep the harness, gate it behind a launch argument, strip only the on-screen debug overlay") is no longer needed — there is nothing left to gate, since the mode itself is not being removed. Only the debug switcher/overlay still follows the removal contract. `Checklist.md` 5.5 now carries this. |
| **M-6 step 3 says environment pieces get no outline.** The Persons got one in 2.3, leaving two art styles in one frame. | Deliberately reversed for **large silhouette pieces only**. Attempted via `material_overlay` and reverted — that cannot draw an inverted hull. See `Art_Direction.md` Part 1 §6 for the two viable routes. |
| **Docs repeatedly claimed "only `idle` of 32 clips is wired".** | Stale since M-5 step 4. `_play_locomotion()` selects idle/walk/sprint from horizontal velocity. Corrected in `Checklist.md`, `Dev_Plan.md` and `Art_Direction.md`. |
| **`Checklist.md` claimed the FPP crosshair was "verified by render"; filed as B-86 (not there).** | Re-rendered 2026-07-28 by 🔧 build-ux, six times, with zoomed crops of screen centre — the crosshair is present every time, on unchanged code. Could not reproduce B-86's absence. `Checklist.md` and `Handoff.md` B-86 both carry the fresh evidence; B-86 stays open as an unexplained one-off rather than closed, since "cannot reproduce" isn't proof it never happens elsewhere. |
| **Round-swap card, downed vignette, impact burst and slipper spin were described as placeholder.** | All four already shipped. Confirmed by driving the card through its timeline. Corrected 2026-07-28. |
| **`Dev_Plan.md` §6 bumps `config/version` every gameplay commit; two lanes make that conflict forever.** | Documented amendment in `Concurrency_Protocol.md` §4: feature commits do not bump, **the merge does**. |
| **`Concurrency_Protocol.md` §0 assigns 2.3 to Sonnet; it was done by the design lane.** | Ownership follows whoever the human points at the task. The protocol's table is a default, not a claim about history. |
| **CC0 ambience was sourced, then removed.** The register briefly listed two OpenGameArt field recordings. | Replaced by generated beds in B-123: they were correctly licensed and correctly levelled, and still read as "constant steady static/wind" in play, because a real outdoor recording is broadband and broadband is what static means to a listener. `README.md` credits, `Agent_Prompts.md`'s register and `Checklist.md` 6.8 all updated; there is now no third-party audio in the build. |
| **The audio brief's trap 2 said "`.ogg` for everything"; 4.1 shipped `.wav` for all 32 SFX.** | The trap's reasoning was about ambience — minutes-long loops, where lossy is free — and it over-generalised. The SFX are all sub-millisecond transient, which is exactly what a lossy codec smears, and all 32 together are under a megabyte. Ambience is `.ogg`, SFX are PCM `.wav` with `compress/mode=0` pinned in their `.import`. Corrected in the Audio appendix of `Agent_Prompts.md` 2026-07-29. |
| **Three docs said audio was "nothing" / "no owner" / "still nothing".** | Stale as of 2026-07-29 — `Checklist.md` 4.1 shipped. Corrected in `Checklist.md`, `Dev_Plan.md`, `Art_Direction.md`, `Handoff.md` and `Agent_Prompts.md` in the same commit. Note 4.1 is `[~]`, not `[x]`: it is probe-verified and has never been listened to. |

| **`Handoff.md` U-5 specifies six Prop cards; the build ships six SKINS that each carry a kit.** | Same destination, different shape, and the shape is forced. A Prop is not a Tsinelas *or* a Can for a match — the role swaps every round, which is why B-76 re-picks a Prop's ability on every swap. A standalone six-card kit picker would let a player choose an identity they lose one round later. Attaching the kit to the lata/tsinelas skins the select screen ALREADY picks separately solves it with no new UI. `Checklist.md` 3.3 and `Handoff.md` U-5 both carry it. Recorded 2026-07-29 (10.5). |
| **Docs described the single-player pre-match lobby's READY → START rhythm as intended.** | Superseded 2026-07-29 (10.5) on the human's call: a solo player has nobody to wait for. Single Player now starts on confirm. ⚠️ **The in-MATCH ready prompt is a different thing and still exists** — `main.gd`'s `_awaiting_local_ready` / "3 · 2 · 1 · GO". |
| **A front-end pass was branched from `main`, which was 24 commits behind `integration`, and rebuilt a feature `integration` already had.** | `Concurrency_Protocol.md` §1 already says to branch from `integration`; it was not followed and cost a full rebuild. The rebuild kept every line of the existing character-select work. Left visible here rather than quietly fixed, because "branch from integration" reads as bookkeeping until it costs a day. Recorded 2026-07-29 (10.5). |

**If you find another, add a row here in the same commit that fixes it.**

## Credits and attribution

| What | Whose | How it is used |
|---|---|---|
| **Sarsi** — the livery on the in-game lata (blue body, red sail and ball, white wave) | Registered trademark of its owner | Reproduced as **homage**, at the human's explicit direction, to place the game in the Philippines the way a real tumbang preso can does. Colour-blocked geometry only — no wordmark, no artwork file, no texture is copied. **No affiliation or endorsement is claimed or implied.** If this ever ships commercially, this row is the thing to re-check first. |
| **Kenney kits** — *Mini Characters*, *City Kit (Suburban)*, *Fantasy Town Kit*, *Mini Forest*, *Food Kit*, *Furniture Kit*, *Car Kit* | [kenney.nl](https://kenney.nl), **CC0** — verified in each kit's own `License.txt` | The Person rig (M-5) and, from 2026-07-28, the whole world: buildings, dressing, vehicles, the lata. CC0 means commercial use is fine and **attribution is not required** — this row is courtesy, and Kenney asks only that. See `Checklist.md` phase 7. |
| **All audio** — 32 sound effects and both map ambience beds | **Ours.** Synthesised by `tools/audio/generate_sfx.py` and `tools/audio/generate_ambience.py` from numpy/scipy maths | No microphone, no sample library, no download. **There is no third-party audio in the build at all**, so the Form 03 audio disclosure is a single "own work" row. The two CC0 field recordings that originally supplied the ambience were removed in B-123 — correctly licensed, but a real outdoor recording is broadband by nature and read as constant static in play. |
