# docs/ — four files, and that is the budget

Pruned hard on 2026-07-30. Nine documents (≈14 000 lines, most of it dated session
narrative) became four. **Every word here is load-bearing; if you add a paragraph,
delete one.**

| File | Authoritative for |
|---|---|
| [`Agent_Prompts.md`](Agent_Prompts.md) | **Execution order, per-agent prompts, the MASTER CHECKLIST, and the work log.** The only place a box is ticked. |
| [`Design.md`](Design.md) | Rules and every tunable number. The single source of truth for balance. |
| [`Art_Direction.md`](Art_Direction.md) | Colour law, scale law, arena geometry, model/kit rules. |
| `README.md` | This index. |

## What was deleted, and why you will not miss it

`Checklist.md`, `Handoff.md`, `Handoff_Archive.md`, `Handoff_NET_2026-07-30.md`,
`Handoff_Physics_AI_LAN.md`, `Dev_Plan.md`, `Roadmap.md`, `Concurrency_Protocol.md`,
`SHARED_LOCKS.md`. They were closed bugs, superseded plans, and lane bookkeeping for
a parallel-lane model that no longer runs — agents now run **in a strict sequence**
(see `Agent_Prompts.md`), so the mutex and the path-ownership tables have no job.

**Code comments still name those files.** That is expected and is not worth a sweep;
the code's own comments are the deepest documentation in this project and they stay.
Read a `docs/Dev_Plan.md §4` reference as "there was a reason, it is now in
`Design.md`".

## Standing rules that survived the prune

1. **Branch from `integration`.** Never from `main`.
2. **Commit authorship is `M4tyu633 <matthewtlabrador@gmail.com>`.** No co-author trailer.
3. **Feature commits do not bump `application/config/version`.** The merge does.
4. **Never claim a verification you did not perform.** Say "written", "measured" or
   "played", and mean it.
5. **Diagnose by measurement.** The impossible-number rule: if two numbers cannot both
   be true, the metric is the bug. It has caught five harness faults on this project.
6. **Delete stale content rather than labelling it outdated.**

## Machine notes (not in git for a reason, repeated here because they cost time)

* Godot is `C:\Users\matth\Downloads\Godot_v4.7.1-stable_win64.exe`, not on PATH.
  Use the `_console.exe` sibling for stdout; use the **plain** exe for anything that
  renders (`--headless` has no rendering device and every capture comes back blank).
* Always pass an absolute `--path`.
* `godot -s script.gd` and `--check-only` do **not** load autoloads. Grep
  `--check-only` output for `Parse Error` — that is the one cheap real gate.
  Run probes as `.tscn`, never with `-s`.
* Long probe runs need a background task, not `nohup ... &`.

## Credits

* **Kenney kits** (Mini Characters, City/Town/Forest/Food/Furniture/Car) — CC0,
  [kenney.nl](https://kenney.nl). Attribution is courtesy, not required.
* **All audio is ours** — synthesised by `tools/audio/generate_sfx.py` and
  `generate_ambience.py`. There is no third-party audio in the build.
* **Sarsi livery** on the lata is homage by colour-blocked geometry only — no
  wordmark, no texture, no affiliation claimed.
