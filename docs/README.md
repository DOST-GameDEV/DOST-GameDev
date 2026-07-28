# The docs, what each is for, and which one wins

There are **eight**. This file exists so nobody has to guess which is current, and so two
documents disagreeing is a bug with an owner rather than a thing you work around.

## Source of truth — in order

When two documents disagree, **the one higher in this list wins.** Fix the lower one in the same
commit rather than leaving both standing.

| # | Document | Authoritative for |

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

**If you find another, add a row here in the same commit that fixes it.**

## Credits and attribution

| What | Whose | How it is used |
|---|---|---|
| **Sarsi** — the livery on the in-game lata (blue body, red sail and ball, white wave) | Registered trademark of its owner | Reproduced as **homage**, at the human's explicit direction, to place the game in the Philippines the way a real tumbang preso can does. Colour-blocked geometry only — no wordmark, no artwork file, no texture is copied. **No affiliation or endorsement is claimed or implied.** If this ever ships commercially, this row is the thing to re-check first. |
| **Kenney kits** — *Mini Characters*, *City Kit (Suburban)*, *Fantasy Town Kit*, *Mini Forest*, *Food Kit*, *Furniture Kit*, *Car Kit* | [kenney.nl](https://kenney.nl), **CC0** — verified in each kit's own `License.txt` | The Person rig (M-5) and, from 2026-07-28, the whole world: buildings, dressing, vehicles, the lata. CC0 means commercial use is fine and **attribution is not required** — this row is courtesy, and Kenney asks only that. See `Checklist.md` phase 7. |
