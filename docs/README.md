# docs/ — five files, and that is the budget

**Every word here is load-bearing. If you add a paragraph, delete one.** Stale content
gets deleted, never labelled outdated.

| File | Authoritative for |
|---|---|
| [`Agent_Prompts.md`](Agent_Prompts.md) | **The `build xxx` pipeline, the execution order, the checklist and the log.** The only place a box is ticked. |
| [`Design.md`](Design.md) | The rules and every tunable number. The single source of truth for balance. |
| [`Art_Direction.md`](Art_Direction.md) | Colour law, scale law, arena geometry, model and kit rules. |
| [`HUMAN.md`](HUMAN.md) | **What the team records with a microphone, and in what format.** 🔊 `build voice` owns it. |
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

1. **Branch from `feature/objects-overhaul-v2`** for overhaul work; `integration` is the
   stable line. Never from `main`.
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
* `godot -s script.gd` and `--check-only` do **not** load autoloads. Grep `--check-only`
  output for `Parse Error` — that is the one cheap real gate. Run probes as `.tscn`,
  never with `-s`.
* Long probe runs need a background task, not `nohup ... &`.

## Credits

* **Kenney kits** (Mini Characters, City/Town/Forest/Food/Furniture/Car) — CC0,
  [kenney.nl](https://kenney.nl). Attribution is courtesy, not required.
* **All audio is ours** — synthesised by `tools/audio/generate_sfx.py` and
  `generate_ambience.py`. No third-party audio in the build.
* **Sarsi livery** on the lata is homage by colour-blocked geometry only — no wordmark,
  no texture, no affiliation claimed.
