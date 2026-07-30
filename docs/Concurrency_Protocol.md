# Two-Agent Concurrency Protocol

How an **Opus 5 design agent** and a **Sonnet 5 builder agent** work this repository at the same
time without breaking each other or the build.

Read this **before** either agent starts. It is not advice; every rule below exists because of a
specific, named way this repository breaks when two writers touch it at once.

---


## Jump to

<sub>Auto-added 2026-07-30 so this file stops being one long scroll. Keep it in step when you add a `##` section.</sub>

- [0. The four lanes](#0-the-four-lanes)
- [1. Topology — separate worktrees, one integration branch](#1-topology-separate-worktrees-one-integration-branch)
- [2. Path ownership — the primary mechanism](#2-path-ownership-the-primary-mechanism)
- [3. Shared files — an optimistic lock built on `git push`](#3-shared-files-an-optimistic-lock-built-on-git-push)
- [4. `project.godot` — the version bump rule changes](#4-projectgodot-the-version-bump-rule-changes)
- [5. `docs/Checklist.md` — ticking boxes without fighting](#5-docschecklistmd-ticking-boxes-without-fighting)
- [6. `.tscn` and `.tres` — how Godot text scenes actually conflict](#6-tscn-and-tres-how-godot-text-scenes-actually-conflict)
- [7. `.import` UIDs — the trap that two lanes turn from annoying into blocking](#7-import-uids-the-trap-that-two-lanes-turn-from-annoying-into-blocking)
- [8. The smoke gate — one shared definition of "I did not break it"](#8-the-smoke-gate-one-shared-definition-of-i-did-not-break-it)
- [9. Merge cadence and direction](#9-merge-cadence-and-direction)
- [10. Reporting across the seam](#10-reporting-across-the-seam)
- [11. Setup, start to finish](#11-setup-start-to-finish)
- [12. Documentation hygiene — every lane, every merge, not just your own file](#12-documentation-hygiene-every-lane-every-merge-not-just-your-own-file)

## 0. The four lanes

Two lanes write code. Two lanes write only documentation, which makes them **collision-free by
construction** — they can run alongside anything, because their path set is disjoint from the code
lanes'. That is deliberate: it buys two extra concurrent workers for free.

| | **🎨 DESIGN** | **🔧 BUILD** | **🔬 QA** | **📦 PRODUCER** |
|---|---|---|---|---|
| **Model** | **Opus 5, high** | Sonnet 5, med/high | Sonnet 5, medium | Sonnet 5, medium |
| **Hard question** | *"Does this match the moodboard?"* | *"Does this code do the right thing?"* | *"Does this actually work when run?"* | *"Is this submittable?"* |
| **Writes code?** | Yes — assets, scenes | Yes — scripts, scenes | **No** | **No** |
| **Owns** | Meshes, map layout, environment art direction, proportion, palette | Gameplay systems, networking, physics, state machines, generators, bug fixes, tooling | `Handoff.md` §3, `Handoff.md`, screenshots | `Checklist.md` phase 6, synopsis drafts, forms prep, licence register |
| **Branch prefix** | `art/<task>` | `code/<task>` | `qa/<task>` | `prod/<task>` |
| **Worktree** | `.worktrees/design` | `.worktrees/build` | `.worktrees/qa` | shares `qa` or its own |
| **Checklist items** | **1.2, 2.1a, 2.2** and the 6.2/6.3 creative direction | 0.1, 0.2, 0.3, 0.5, 2.1b, 2.3, 2.4, 3.1, 3.3, 3.4, 4.1–4.5, 5.2–5.4, 6.3, 6.4 | verification of everything; files `B-` numbers | 6.5–6.9 drafting; 6.6/6.7/6.9 stay 🧑 human |

**Neither code lane is senior to the other.** They collide over files, not over authority.

### Why Opus gets so few items

**Opus is reserved for the tasks where the difficulty is judgement under ambiguity, not
execution** — and that is a genuinely short list on this project:

| Item | Why it is Opus work |
|---|---|
| **1.2 · Prop scale** | "How big should a hero prop be relative to a person" has no correct answer to look up. Measured, the tsinelas is 84% of a Person's height. Deciding whether that is wrong or *stylised* is a proportion call that cascades into map scale, capsule sizes and camera distance. |
| **2.1a · Environment kit art direction** | Choosing the eleven objects that make a street read as an **eskinita** rather than as generic low-poly — and specifying silhouette, proportion and palette for each — is the whole task. The generator code that emits them is not. |
| **2.2 · Eskinita layout and boundary dressing** | Composition. Where the alley narrows, where cover sits, how the boundary is dressed so it contains play without ever reading as a wall. **The single biggest visual lever on the submission**, and the one place where "does this look like the moodboard" is genuinely the hard question. |
| **6.2/6.3 · Demo script and trailer direction** | What to show, in what order, in ninety seconds, to people who will never play it. Editorial judgement under a hard constraint. **Opus writes the shot list and the beat sheet; Sonnet executes the capture and the edit.** |

**Everything else goes to Sonnet**, including several things an earlier draft of this plan routed to
Opus and shouldn't have:

- **2.3 Person restyle** — once 2.1a has specified the palette, retinting materials and parenting
  two accessory meshes is execution.
- **2.4 Bayan Plaza** — 2.2 establishes the pattern, the kit, and the boundary technique. The
  second map is applying a solved problem, not solving it.
- **3.2 Logo** — if the Canva export exists it is a `TextureRect` swap. Only the fallback path
  (constructing the can-lid "O" by hand) would need Opus, and only if the export fails.
- **6.4 Demo video** — a 3–5 minute narrated walkthrough against 6.2's script is capture and edit.

If a Sonnet lane hits a genuine "I do not know what this should look like" wall, the correct move
is **not** to guess: file it in `Handoff.md` §5 and let it queue for the design lane.

---

## 1. Topology — separate worktrees, one integration branch

```
main                      ← protected. ONLY the human merges here, via PR.
 └── integration          ← both agents branch from and merge into this
      ├── art/eskinita-layout        (Opus, in .worktrees/design)
      └── code/hud-charge-meter      (Sonnet, in .worktrees/build)
```

```bash
git worktree add .worktrees/design  -b art/<task>   integration
git worktree add .worktrees/build   -b code/<task>  integration
```

**Use worktrees, not two clones and not one shared directory.** This is the single most important
line in this document, and the reason is specific to Godot:

- Each worktree gets its **own `.godot/` import cache**, which is gitignored. Two agents sharing one
  directory would have Godot rebuilding and invalidating one cache underneath the other's running
  process — non-deterministic import failures that look like corrupted assets.
- Worktrees share one `.git`, so branches, refs and `git log` are common. Neither agent can be
  looking at a stale view of what the other has landed.
- `git status` stays honest per-lane. In a shared directory, one agent's uncommitted work shows up
  in the other's `git status` and gets swept into the wrong commit.

**Never run two Godot editors on the same worktree.** Godot does not lock `.godot/`, and the
second process silently wins.

---

## 2. Path ownership — the primary mechanism

**If a path is not in your column, you may read it and must not write to it.** Ninety percent of
collisions are prevented here rather than resolved later.

| Path | Owner |
|---|---|
| `assets/models/**`, `assets/ui/**`, `assets/maps/**`, `assets/characters/**` | 🎨 Design |
| `scenes/maps/**` | 🎨 Design |
| `tools/maps/build_*.py` — the `Ambience` node and its `AudioStream` ext_resource ONLY | 🔧 Build |
| `scenes/characters/visuals/**` (`CanVisual.tscn`, `TsinelasVisual.tscn`) | 🎨 Design |
| `tools/models/generate_all.gd` — the `_build_*()` shape functions | 🎨 Design |
| `scripts/ui/ui_theme.gd` + the generated `assets/ui/tumbang_preso.tres` | 🎨 Design |
| `scripts/characters/**`, `scripts/systems/**`, `scripts/abilities/**`, `scripts/main.gd` | 🔧 Build |
| `scripts/ui/*.gd` **except** `ui_theme.gd` | 🔧 Build |
| `tools/models/obj_writer.gd`, `tools/render_probe.gd`, `tools/regenerate_ui_theme.gd` | 🔧 Build |
| `export_presets.cfg`, `.gitignore`, `.gitattributes` | 🔧 Build |
| `assets/audio/**`, `tools/audio/**`, `default_bus_layout.tres` | 🔧 Build |
| **`scenes/ui/*.tscn`** (MainMenu, HUD, Lobby, MatchResult, SettingsPanel, YouCard, RoleSwapCard) | ⚠️ **SHARED** |
| **`scenes/main/Main.tscn`** | ⚠️ **SHARED** |
| **`scenes/characters/CharacterBase.tscn`**, **`CameraRig.tscn`** | ⚠️ **SHARED** |
| **`project.godot`** | ⚠️ **SHARED — special rule, §4** |
| **`docs/Checklist.md`** | ⚠️ **SHARED — append-only-ish, §5** |
| `docs/Handoff.md` §3 (open bugs), `docs/Handoff.md` | 🔬 QA |
| `docs/Checklist.md` phase 6, synopsis and forms drafts, the licence register | 📦 Producer |
| `docs/*_Agent_Brief.md` | whichever lane the brief belongs to |

### The two docs-only lanes

**🔬 QA never writes code.** It runs the smoke gate (§8) against `integration` after every merge,
plays what can be played, captures screenshots with `tools/render_probe.gd`, and files defects as
`B-` numbers in `Handoff.md` §3 with exact reproductions. It **does not fix them** — crossing into a
code lane's files is what makes the ownership table stop meaning anything. This lane exists because
this repository has now shipped four separate geometry bugs (B-77 … B-80) that every non-rendering
check passed, and because `Handoff.md` §0.8's "written, reviewed, never run" pattern has recurred in
three consecutive passes. A dedicated verifier is the structural fix for that.

**📦 Producer never writes code either.** It owns the submission package: drafting the synopsis,
maintaining a running licence register for Form 03 as assets land (rather than archaeologising it at
the deadline), prepping Forms 01–02 for signature, and keeping phase 6 of the checklist honest.
Signing and uploading remain 🧑 human — a model does not sign a declaration of originality.

Because both lanes write only to `docs/`, they need no shared-file lock and can run at any time
alongside both code lanes. Their merge conflicts are always resolved by **taking both sides**.

Note the deliberate split on UI: **`scripts/ui/hud.gd` is Build, `scenes/ui/HUD.tscn` is shared.**
Wiring a signal to a meter is code; deciding where the meter sits and what it looks like is design.
That is the seam, and it runs straight through the middle of the HUD — hence §3.

---

## 3. Shared files — an optimistic lock built on `git push`

Six files cannot be partitioned because both lanes genuinely need them. They are protected by a
claim file whose mutex is git's own atomic ref update.

`docs/SHARED_LOCKS.md` holds one line per shared file. **To claim one:**

1. `git switch integration && git pull --ff-only`
2. Edit **only** `docs/SHARED_LOCKS.md`, putting your lane and branch on that file's line.
3. `git commit -m "lock: claim Main.tscn for art/eskinita-layout"` and **push to `integration`.**
4. **If the push is rejected, you did not get the lock.** Pull, look at who holds it, and work on
   something else. Do not force. The push rejection *is* the mutex — it is atomic, it needs no
   daemon, and it cannot be fooled by an agent that forgot to check.
5. Release by removing your line **in the same push** that merges your work.

**Hold a lock for one task, not one session.** If you are going to think about a layout for an
hour, do the thinking first and claim the file when you are ready to type.

**When both lanes need the same shared scene for the same feature, sequence it — do not
interleave.** The rule is **structure first, style second**:

> 🔧 Build adds the nodes with placeholder geometry and wires the signals → merges to `integration`
> and releases the lock → 🎨 Design claims it, restyles, and positions.

Checklist 0.1 (the charge meter) is exactly this shape: Sonnet adds a `ProgressBar` fed by
`carrier.gd::charge_changed` and proves it moves; Opus then makes it the moodboard's charged-throw
glow. Two commits, two lanes, one file, never at the same moment.

---

## 4. `project.godot` — the version bump rule changes

`application/config/version` is bumped in **every** gameplay commit under the current convention
(`Dev_Plan.md` §6). With two agents that guarantees a conflict on the same line of the same file on
essentially every merge, forever.

> ### ⚠️ Documented amendment, not a silent break
>
> **While two lanes are running: feature commits do NOT bump `config/version`. The merge into
> `integration` does.** The merge commit's subject names every task ID it carries, e.g.
> `Merge code/hud-charge-meter + art/eskinita-layout — 0.1, 2.2 (v4.26)`.
>
> This preserves the rule's actual purpose — that a playtester can name the build they are holding
> without diffing files — because `integration` is what anyone ever runs. Feature branches are
> transient and nobody plays them. Revert to per-commit bumps when the project drops back to one
> writer.

Any other `project.godot` change (an input action, an autoload, a display setting) takes the §3
lock like any other shared file.

---

## 5. `docs/Checklist.md` — ticking boxes without fighting

Both lanes tick their own boxes, and a merge conflict on a checklist is a stupid way to lose ten
minutes.

- **Tick only your own lane's lines.** Never restructure the file, never reorder items, never
  reflow paragraphs you did not write — a reflow turns a one-line change into a whole-file conflict.
- Tick the box **in the same commit as the work**, so the checklist and the code can never drift.
- If you need a *new* item, append it at the end of its phase rather than inserting mid-list.
- Conflicts here are always resolved by **taking both sides**. Never `--ours`/`--theirs` on this
  file; two agents ticking two different boxes is not a disagreement.

---

## 6. `.tscn` and `.tres` — how Godot text scenes actually conflict

They are text and they diff like code, which is why this project keeps them text. They still have
three failure modes that are not obvious:

1. **`load_steps=N` on line 1.** It counts `ext_resource` + `sub_resource` entries and changes
   whenever either lane adds one — so two agents adding unrelated things to the same scene conflict
   on line 1 every time. Resolve by **recounting the entries in the merged file**, not by picking a
   side. A wrong `load_steps` does not error; it silently truncates resource loading.
2. **An editor re-save rewrites the entire file.** Godot reorders properties, renumbers
   `ext_resource` ids and strips comments on save, turning a two-line change into a 200-line diff
   that will conflict with anything. **Edit `.tscn` as text wherever the change is small enough to
   hand-write.** If you must use the editor, `git diff` before committing and be prepared to
   hand-reduce the diff.
3. **Comments do not survive.** Anything a future reader needs to know about a scene's baked
   numbers goes in the script that reads them — `camera_rig.gd`'s two warning blocks about the TPP
   spring arm and the FPP eye height are the pattern to copy.

---

## 7. `.import` UIDs — the trap that two lanes turn from annoying into blocking

**This is now the highest-risk item in this document and it has a checklist entry of its own
(5.4 / B-71).**

`.import` sidecars are **tracked**, and they carry a `uid://` that Godot **regenerates whenever the
import cache is rebuilt**. Two worktrees means two caches, which means the two lanes will
continuously hand each other `.import` diffs whose only content is a changed UID — noise that
conflicts, that nothing references, and that makes the "`generate_all.gd` twice, then `git status`
must be clean" determinism test — the acceptance criterion for the entire `M-` block — unreliable.

Until 5.4 is resolved, both lanes follow this rule:

```bash
# Before every commit that touches assets/, check what you are actually staging:
git diff --cached -- '*.import'
```

**If the only change in an `.import` file is its `uid://` line, unstage it:**

```bash
git restore --staged <file>.import
```

Resolving 5.4 properly means either accepting the churn as policy or stopping tracking the UID
line. **Do it early.** It was logged as "low, not urgent" when one person worked the repo; with two
lanes it corrupts the M-block's only objective acceptance test.

Related: adding a new `class_name` script requires a `godot --headless --path . --import` pass
before anything can reference it, and that pass writes the `.gd.uid` sidecar this repo tracks.
**Stage only your own new sidecar**, not everything the import pass happened to touch.

---

## 8. The smoke gate — one shared definition of "I did not break it"

**Run all six. Before every merge into `integration`. No exceptions, either lane.** This is the
only thing standing between two concurrent writers and a broken `integration` branch that neither
of them can bisect.

```bash
# 1. Imports cleanly, and the cache rebuild introduced no tracked churn.
godot --headless --path . --import && git status --short

# 2. No parse errors anywhere in the project.
godot --headless --path . --quit

# 3. 400 REAL frames of the match scene. Must produce NO OUTPUT AT ALL.
#    This is the check that caught B-77, which every headless test passed.
godot --path . scenes/main/Main.tscn --quit-after 400

# 4. Look at it. Not optional for a design-lane merge.
godot --path . tools/render_probe.tscn --quit-after 400 --resolution 1280x720 -- match /tmp/

# 5. Model determinism — run twice; git status must be clean after the second.
godot --headless -s tools/models/generate_all.gd
godot --headless -s tools/models/generate_all.gd && git status --short

# 6. Authorship, per Handoff.md §2 and Dev_Plan.md §7.1.
git log -1 --format='%an <%ae> | %cn <%ce>'
```

**If you touched anything under `assets/audio/`, `tools/audio/`, `AudioManager`, the bus layout
or a map's `Ambience` node, run the seventh as well** (checklist 4.1). It is not one of the six
because it is not universal, and it is worth having because every failure it catches is SILENT —
an unregistered bus layout, a missing stream, a lossy re-import that smears the frame-synced lata
impact, or Godot's ogg importer quietly resetting an ambience bed to `loop=false`. None of those
error; they just make the game wrong.

```bash
# 7. Audio integrity. 25 checks; exits non-zero on any failure.
godot --path . tools/audio_probe.tscn --quit-after 600

# 8. Audio MIX. Captures each bus separately during a real match and fails if
#    ANY of them exceeds full scale. B-121 was a +2.0 dBFS clip on the SFX bus
#    while Master read a healthy -1.4 — a check that only watches Master is
#    exactly the check that missed it.
godot --path . tools/audio_mix_probe.tscn --quit-after 1800
```

Note that **3 and 4 require a real rendering device** — do not pass `--headless` to them. A
`--quit`-only test never executes a frame of `_process()` and a headless run never renders a pixel;
between them they miss the entire class of bug that B-77, B-78, B-79 and B-80 all belonged to.

---

## 9. Merge cadence and direction

- **Merge into `integration` at every completed checklist item**, not at the end of a session. A
  lane that hoards five items produces one unreviewable merge and five simultaneous conflicts.
- **Rebase onto `integration` before every merge**, so conflicts are resolved by whoever created
  them, while they still remember what they were doing.
- **Whoever merges second resolves.** No negotiation, no ownership dispute — the second one in owns
  the conflict, runs the smoke gate on the *merged* result, and fixes what it reports.
- **`main` is the human's.** Neither lane pushes to it. `integration` → `main` is a PR the human
  reviews and merges. This is unchanged from the standing rule and applies to both lanes equally.

---

## 10. Reporting across the seam

The two lanes never talk directly. Everything one needs from the other goes in the repo:

- **A blocking question** → add it to `Handoff.md` §5 with the checklist item it blocks, and work
  on something else. Do not guess and do not build both branches speculatively.
- **A defect in the other lane's territory** → new `B-` number in `Handoff.md` §3, with the exact
  reproduction, and **do not fix it yourself**. Crossing lanes to fix "just one line" in someone
  else's file is how the ownership table stops meaning anything.
- **A finished item** → tick its checklist box in the same commit, and say in the commit body what
  is verified versus what is only reasoned about. `[~]` not `[x]` if you could not run it.
- **Anything visual** → attach or reference a screenshot from `tools/render_probe.gd`. This project
  has shipped four separate geometry bugs that every non-rendering check passed; a design-lane claim
  with no picture is not evidence.

---

## 11. Setup, start to finish

```bash
# Once, by the human or whichever lane starts first:
git switch main && git pull --ff-only
git switch -c integration && git push -u origin integration

git worktree add .worktrees/design -b art/<first-task>  integration
git worktree add .worktrees/build  -b code/<first-task> integration

# In EACH worktree, once — identity does not travel with a worktree:
git config user.name  "M4tyu633"
git config user.email "matthewtlabrador@gmail.com"

# In EACH worktree, once — builds that worktree's own import cache. Slow, expected.
godot --headless --path . --import
```

Add to `.gitignore` if it is not already there:

```
.worktrees/
```

**Sanity check before starting work:** `git worktree list` shows two entries plus `main`, each
worktree's `git log -1` shows the same `integration` tip, and `git config user.email` reads
`matthewtlabrador@gmail.com` in both.
---

## 12. Documentation hygiene — every lane, every merge, not just your own file

**This section exists because nineteen markdown files had to be merged into eight, and the same
five claims had to be corrected three times each.** That cleanup was avoidable, and the thing
that made it necessary was every lane updating only the one doc it happened to be looking at.

**When you finish an item, you are not finished until every document the change touches is
correct.** Not the nearest one. All of them.

The rule, in full:

1. **Tick the box in `Checklist.md` in the SAME COMMIT as the work.** Never a follow-up commit —
   the checklist and the code must not be able to drift apart even for one commit.
2. **Grep for what you just made wrong.** After any behaviour change, search `docs/` for the
   thing you changed and fix every stale claim you find:
   ```bash
   grep -rn "<the thing you changed>" docs/ scripts/ tools/
   ```
   If a doc says a feature is missing and you just built it, that doc is now a bug.
3. **Delete stale content. Do not annotate it.** A paragraph marked "(outdated)" is still read,
   still believed and still costs somebody a session. If it is wrong, remove it; if it is history
   worth keeping, move it under a clearly-marked appendix and say what superseded it.
4. **A claim of verification is a claim.** Never write "verified by render" for something you did
   not render. `Checklist.md` asserted exactly that about the FPP crosshair, which was never
   there — see **B-86**. A false verification claim is worse than a missing feature, because it
   is the thing that stops anyone looking again.
5. **Two documents disagreeing is a defect with an owner: you.** If you find a contradiction, fix
   the lower-ranked one per `README.md`'s source-of-truth order and **add a row to that file's
   contradiction register in the same commit**.
6. **If you merge or delete a doc, rewrite every reference to it** — across `docs/`, `scripts/`
   and `tools/` headers, which carry doc links too. Then prove it:
   ```bash
   grep -rn "<deleted-doc-name>" docs/ scripts/ tools/     # must return nothing
   ```
7. **Do not create a new markdown file if an existing one is the right home.** Eight is the
   budget. `README.md` says what each is for; adding a ninth needs a reason you can defend.

**Nothing here is optional and none of it is separate from "the work".** A feature whose
documentation still describes the old behaviour is half-finished.

