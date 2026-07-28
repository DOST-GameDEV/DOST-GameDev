# Shared file locks

Six files cannot be partitioned between lanes because both genuinely need them. This file is the
mutex. See [`Concurrency_Protocol.md`](Concurrency_Protocol.md) §3 for the full rule.

**To claim:** switch to `integration`, `git pull --ff-only`, edit **only this file** to put your
lane and branch on the line, commit, and **push**. *If the push is rejected you did not get the
lock* — pull, see who holds it, and work on something else. Never force. The push rejection is the
mutex: atomic, no daemon, and impossible to forget to check.

**To release:** clear the line back to `— free —` in the same push that merges your work.

**Hold for one task, not one session.** Do the thinking first; claim the file when you are ready
to type.

| Shared file | Held by | Branch | Since |
|---|---|---|---|
| `scenes/main/Main.tscn` | — free — | | |
| `scenes/characters/CharacterBase.tscn` | — free — | | |
| `scenes/characters/CameraRig.tscn` | — free — | | |
| `scenes/ui/*.tscn` | 🔧 BUILD-AI | `code/single-player-ai` | 2026-07-28 |
| `project.godot` | — free — | | |
| `tools/models/generate_all.gd` | — free — | | |
| `docs/Checklist.md` | *no lock needed* | | append-only-ish; conflicts resolved by taking both sides |

> ### `generate_all.gd` / 2.1b-0 — resolved, kept for history
>
> 2.1b (the 28-piece environment kit) shipped from the Design lane, per the human's reassignment,
> and 2.1b-0 (the `transform: Transform3D` param on `add_revolve`/`add_extrude`, 🔧 Build) landed
> first to unblock it. Both are `[x]` in `Checklist.md`. Nothing left to coordinate here — the row
> above reads **— free —** and stays that way unless `generate_all.gd` needs a lock again.

## When both lanes need the same scene for one feature

**Structure first, style second.** Never interleave.

> 🔧 Build adds the nodes with placeholder geometry and wires the signals → merges to
> `integration`, releases the lock → 🎨 Design claims it, restyles, positions.

## A reminder about `project.godot`

While two lanes are running, **feature commits do not bump `application/config/version`** — the
merge into `integration` does, naming every task ID it carries. Taking this lock is for real
changes: an input action, an autoload, a display setting.
