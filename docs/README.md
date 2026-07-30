# docs/ — four files, and that is the budget

**Every word here is load-bearing. If you add a paragraph, delete one.** Stale content
gets deleted, never labelled outdated.

| File | Authoritative for |
|---|---|
| [`Agent_Prompts.md`](Agent_Prompts.md) | **The `build xxx` pipeline, the execution order, the checklist and the log.** The only place a box is ticked. |
| [`Design.md`](Design.md) | The rules and every tunable number. The single source of truth for balance. |
| [`Art_Direction.md`](Art_Direction.md) | Colour law, scale law, arena geometry, model and kit rules. |
| `README.md` | This index and the machine notes. |

Code comments still name deleted files (`Dev_Plan.md §4`, `Handoff.md`, `Checklist.md`).
Read those as "there was a reason, it is now in `Design.md`". The comments themselves are
the deepest documentation in this project and they stay.

## Standing rules

1. **Branch from `feature/objects-overhaul-v2`** for overhaul work; `integration` is the
   stable line. Never from `main`.
2. **Commit authorship is `M4tyu633 <matthewtlabrador@gmail.com>`.** No co-author trailer.
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
