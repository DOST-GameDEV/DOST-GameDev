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

## Known contradictions — the ones that still bind

Fifteen resolved-contradiction rows were deleted on 2026-07-30: they recorded doc-vs-doc conflicts
that are now settled in the files themselves, which is where they actually stop someone undoing
them. These four are kept because each is still a *live* rule someone can trip over.

| Rule | Why it exists |
|---|---|
| **Branch from `integration`, never `main`.** | A front-end pass branched from a `main` that was 24 commits behind and rebuilt a feature `integration` already had. Reads as bookkeeping until it costs a day. |
| **A feature commit does not bump `config/version`; the MERGE does.** | `Dev_Plan.md` §6 as written made two lanes conflict forever. Amendment in `Concurrency_Protocol.md` §4. |
| **The map gets no outline; characters keep the toon pass.** | The inverted hull across ~510 map instances was half the map's draw calls and read as horizontal banding on flat walls. Rollback measured 90 → 203 fps. |
| **Ambience is `.ogg`, SFX are PCM `.wav` (`compress/mode=0` pinned).** | The audio brief said ".ogg for everything"; that reasoning was about minutes-long loops and over-generalised. All 32 SFX are sub-millisecond transients, which is what a lossy codec smears, and together they are under a megabyte. |

**If you find another, add a row here in the same commit that fixes it.**

## Credits and attribution

| What | Whose | How it is used |
|---|---|---|
| **Sarsi** — the livery on the in-game lata (blue body, red sail and ball, white wave) | Registered trademark of its owner | Reproduced as **homage**, at the human's explicit direction, to place the game in the Philippines the way a real tumbang preso can does. Colour-blocked geometry only — no wordmark, no artwork file, no texture is copied. **No affiliation or endorsement is claimed or implied.** If this ever ships commercially, this row is the thing to re-check first. |
| **Kenney kits** — *Mini Characters*, *City Kit (Suburban)*, *Fantasy Town Kit*, *Mini Forest*, *Food Kit*, *Furniture Kit*, *Car Kit* | [kenney.nl](https://kenney.nl), **CC0** — verified in each kit's own `License.txt` | The Person rig (M-5) and, from 2026-07-28, the whole world: buildings, dressing, vehicles, the lata. CC0 means commercial use is fine and **attribution is not required** — this row is courtesy, and Kenney asks only that. See `Checklist.md` phase 7. |
| **All audio** — 32 sound effects and both map ambience beds | **Ours.** Synthesised by `tools/audio/generate_sfx.py` and `tools/audio/generate_ambience.py` from numpy/scipy maths | No microphone, no sample library, no download. **There is no third-party audio in the build at all**, so the Form 03 audio disclosure is a single "own work" row. The two CC0 field recordings that originally supplied the ambience were removed in B-123 — correctly licensed, but a real outdoor recording is broadband by nature and read as constant static in play. |
