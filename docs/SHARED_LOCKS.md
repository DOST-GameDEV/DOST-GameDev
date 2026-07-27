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
| `scenes/ui/*.tscn` | — free — | | |
| `project.godot` | — free — | | |
| `tools/models/generate_all.gd` | 🎨 **Design** | `art/environment-kit` | 2026-07-28 |
| `docs/Checklist.md` | *no lock needed* | | append-only-ish; conflicts resolved by taking both sides |

> ### ⚠️ Why `generate_all.gd` has a line here, and why it is temporary
>
> It is **not** one of the six genuinely shared files — `Concurrency_Protocol.md` §2 assigns its
> `_build_*()` shape functions to 🎨 Design outright. But `Checklist.md` **2.1b routes "generate the
> kit" to 🔧 Sonnet**, so the two documents disagree about who writes the same file, and 2.1b is
> ~26 new `_build_env_*()` functions — far too much to discover as a merge conflict.
>
> **Resolved by the human, 2026-07-28: the Design lane builds 2.1b's shape functions.** This line
> exists so the Build lane finds out by reading the mutex instead of by colliding. **🔧 Build: do
> not start 2.1b.** `obj_writer.gd` and `generate_all.gd`'s plumbing remain yours, and **2.1b-0 is
> still yours and is still wanted** — see below.
>
> Remove this row when 2.1b is merged.
>
> **2.1b-0 done, 2026-07-28** (🔧 Build) — `add_revolve` and `add_extrude` both take an optional
> trailing `transform: Transform3D = Transform3D.IDENTITY` now, verified by running (see
> `Checklist.md` 2.1b-0). **`wall_corrugated_leaning` and `tricycle` are unblocked.** Remember:
> `recalculate_normals()` after any non-identity call — the analytic normals are dead the moment
> `transform` isn't a pure translation, same rule `deform` already has.

## When both lanes need the same scene for one feature

**Structure first, style second.** Never interleave.

> 🔧 Build adds the nodes with placeholder geometry and wires the signals → merges to
> `integration`, releases the lock → 🎨 Design claims it, restyles, positions.

## A reminder about `project.godot`

While two lanes are running, **feature commits do not bump `application/config/version`** — the
merge into `integration` does, naming every task ID it carries. Taking this lock is for real
changes: an input action, an autoload, a display setting.
