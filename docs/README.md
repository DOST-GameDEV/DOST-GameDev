# docs/ — five files, and that is the budget

**Every word here is load-bearing. If you add a paragraph, delete one.** Stale content
gets deleted, never labelled outdated.

| File | Authoritative for |
|---|---|
| [`Agent_Prompts.md`](Agent_Prompts.md) | **The `build xxx` pipeline, the execution order, the checklist and the log.** The only place a box is ticked. |
| [`Design.md`](Design.md) | The rules and every tunable number. The single source of truth for balance. |
| [`Art_Direction.md`](Art_Direction.md) | Colour law, scale law, arena geometry, model and kit rules. |
| [`HUMAN.md`](HUMAN.md) | **What the team records with a microphone, and in what format.** 🔊 `build sound` owns it. |
| `README.md` | This index and the machine notes. |

⚠️ **The budget went from four to five on 2026-07-31 and that is a deliberate exception, not
drift.** Every other file here is written for whoever is *building* — agent or human, same
audience. `HUMAN.md` is written for **teammates holding a phone**, who will not read a
checklist board and should not have to. A recording brief buried inside `Agent_Prompts.md`
would be a recording brief nobody records against. It is also the one file here with an end
date: when the voice lines are in the game, it stops being instructions and becomes a
record, and the budget goes back to four.

Code comments still name deleted files (`Dev_Plan.md §4`, `Handoff.md`, `Checklist.md`).
Read those as "there was a reason, it is now in `Design.md`". The comments themselves are
the deepest documentation in this project and they stay.

## Standing rules

1. **`HANSDAKS-test` is the working line.** Branch from it, push to it, and open your own
   branch for a lane that will take a while. `integration` is the older stable line and `main`
   is older still; never branch from either. ⚠️ **This rule named
   `feature/objects-overhaul-v2` until 2026-08-01** — a branch of the deleted 2v2 design, so
   anyone obeying it branched off the game this one replaced.
2. **Every commit is authored by `M4tyu633 <matthewtlabrador@gmail.com>` and nobody else.**
   No `Co-Authored-By:` trailer, no "Generated with", no 🤖 line, no model or tool named
   anywhere in the message. This is submitted as one person's work and the history has to
   read that way. Full rule in `Agent_Prompts.md`.
3. **Feature commits do not bump `application/config/version`.** The merge does.
4. **Never claim a verification you did not perform.** Say "written", "measured" or
   "played", and mean it.
5. **Diagnose by measurement.** The impossible-number rule: if two numbers cannot both be
   true, the metric is the bug. It has caught five harness faults here.
6. **One lane at a time, in the order on the board.** One writer per file.

## Machine notes

* Godot is `C:\Users\matth\Downloads\Godot_v4.7.1-stable_win64.exe`, not on PATH. Use the
  `_console.exe` sibling for stdout; use the **plain** exe for anything that renders —
  `--headless` has no rendering device and every capture comes back blank.
* Always pass an absolute `--path`.
* ⚠️ **THE REAL PARSE GATE IS `--headless --path <abs> --import`, GREPPED FOR
  `Parse Error`** — and this line used to name `--check-only` instead, which cost a session.
  `godot -s script.gd` and `--check-only` do **not** load autoloads, so they report a false
  "Identifier not found" for every `RoundManager`, `MatchManager` and `NetworkManager`
  reference in the file, and they cannot see a `class_name` type until an import has run.
  What they DO catch honestly is a syntax error, so they are a first look, never the gate.
  Run probes as `.tscn`, never with `-s`.
* Godot treats some warnings as errors here, so a *warning* can fail the import outright —
  an inferred-`Variant` assignment stopped `main.gd` loading on 2026-08-01. Read the actual
  message rather than assuming a parse failure is a typo.
* Long probe runs need a background task, not `nohup ... &`.

## Credits

* **Kenney kits** (Mini Characters, City/Town/Forest/Food/Furniture/Car) — CC0,
  [kenney.nl](https://kenney.nl). Attribution is courtesy, not required.
* **All audio is ours, in two different senses.** The OST is **written by the team**; the SFX
  and ambience beds are synthesised by `tools/audio/generate_sfx.py` and `generate_ambience.py`.
  The team's own SFX will replace the synthesised ones later. No third-party audio in the build.
  ⚠️ This line said "all synthesised" until 2026-08-01, which stopped being true the moment
  the first OST track landed.
* **Three CC-BY-4.0 models ship and their authors MUST be credited** — CROCS by **fnk**,
  PANTULOG ("Pink Slipper") by **The Withered Rose**, IKE ("Low Poly Nike Sandals") by
  **les03**, all from Sketchfab. Each `.glb` ships its own `*_LICENSE.txt` and the exact
  credit string is quoted verbatim on the in-game CREDITS screen. The full table is
  `Art_Direction.md` §4b. **This is compliance, not courtesy** — unlike everything else here.
* **Darumadrop One** typeface — © 2020 The Darumadrop One Project Authors, **SIL Open Font
  License 1.1**. Satisfied by shipping `assets/ui/fonts/DarumadropOne_LICENSE.txt`, and also
  credited on screen.
* **Sarsi livery** on the lata is homage by colour-blocked geometry only — no wordmark and no
  affiliation claimed. ⚠️ It said "no texture" until 2026-08-01; the four cans carry their
  own flattened label wraps as textures now (`Art_Direction.md` §4), on a human ruling. The
  homage claim is unchanged: the geometry and the palette are the reference, not any mark.
