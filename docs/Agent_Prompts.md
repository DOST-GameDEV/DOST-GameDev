# Agent Prompts — paste-ready openers for each lane

## FOR THE HUMAN — what to run, on what, in what order

Each row is a block further down this file. **Copy the block verbatim into a brand-new chat**
with no other context, and **set the model and effort in the client before pasting** — the prompt
names them but cannot set them.

| # | Lane | Model | Effort | Run it when | Why here in the order |
|---|---|---|---|---|---|
| **1** | ~~🔧 **BUILD-PHYS**~~ | **Sonnet** | high | ✅ **Done 2026-07-28 — `Checklist.md` 2.5.** | Per-unit collision, both props rescaled, `HAND_CARRY_OFFSET` re-measured, `base_circle_decal` resized, 4.4a fixed. Row 4 is unblocked. |
| **2** | 🔧 **BUILD-UX** | **Sonnet** | medium | Any time | Independent files. Fixes the missing FPP crosshair (**B-86**) and builds the charge-glow hook, which is the half of the throw the design lane cannot finish alone. |
| **3** | 🔧 **BUILD-NET** | **Sonnet** | high | Before the real LAN test (6.1) | Remote units visibly snap. Testing over real wifi without interpolation measures the wrong thing, so this must precede 6.1. |
| **4** | 🎨 **DESIGN-ART** | **Opus** | high | **Unblocked — row 1 is done** | Its first job was rescaling props, which depended on 1; that shipped (`generate_all.gd`'s meshes), so this lane's remaining scope is whatever `Checklist.md` still lists open under 2.x. Opus because its question is *"does this match the moodboard"* — a judgement call, not a testable one. **Attach the moodboard image.** |
| **5** | 🎵 **BUILD-AUDIO** | **Sonnet** | medium | Any time | Nothing exists — not one `AudioStreamPlayer` in the repo. Fully independent of every other lane. |
| **6** | 🔬 **QA** | **Sonnet** | medium | **Alongside anything** | Writes only `docs/`, so it can never collide. Good to keep running continuously. |
| **7** | 📦 **PRODUCER** | **Sonnet** | medium | **Alongside anything** | Also `docs/`-only. Submission paperwork has a deadline that does not move. |

### Rules for running more than one at a time

- **At most TWO code lanes at once** (1, 2, 3, 5 are code lanes), and never two whose file sets
  overlap — see [`Concurrency_Protocol.md`](Concurrency_Protocol.md) §2 for the ownership table.
- **QA and PRODUCER are always safe** to add on top; they touch no code.
- **One person does the setup in `Concurrency_Protocol.md` §11 once** before any lane starts.
- If a lane needs a shared file it must claim it in [`SHARED_LOCKS.md`](SHARED_LOCKS.md) first.
  **A rejected push means it did not get the lock** — that rejection *is* the mutex.

### Only Opus for one lane, and why

Opus is for *"I do not know what this should look like."* Every other lane has a known target and
a testable answer, which is Sonnet work. Paying Opus rates for a task with a right answer is
waste; running Sonnet on a taste call is how you get something that compiles and looks wrong.

### These four are human-only — no model can do them

| Task | Why it is blocking |
|---|---|
| **5.1** Install Godot export templates | **No `.exe` has ever been produced.** Everything downstream of handing a judge a build waits on this. |
| **6.1** Real multi-device LAN test | Everything so far is loopback on one machine. If it forces the shared-screen fallback you need weeks of warning. |
| **1.1** Pick the display typeface | Blocks the logo and every screen's finished read. |
| **0.4** Keep playing it | One session found four bugs, three of which were a single missing line. Highest-value hour available. |

---

> ## ⚠️ START HERE — the current set is [§ CURRENT, v4.36+](#current-set--v436-after-the-first-playtest)
> 
> Everything below that heading is the live queue, written after the first real playtest.
> The older lane prompts kept further down are **historical** — several of their items have
> since shipped. Use them only for the standing rules (setup, locks, smoke gate), not for scope.

---

<a id="current-set--v436-after-the-first-playtest"></a>

# CURRENT SET — v4.36+, after the first playtest

**Written 2026-07-28 at v4.36, after the first real playtest.** Every prompt below is
self-contained: paste it as the FIRST message of a fresh session, nothing else needed.

## How to run these

| Lane | Model | Effort | Run how many at once |
|---|---|---|---|
| 🔧 **BUILD-NET** | **Sonnet** | high | 1 |
| 🔧 **BUILD-PHYS** | **Sonnet** | high | 1 — **must finish before DESIGN-ART's proportion step** |
| 🔧 **BUILD-UX** | **Sonnet** | medium | 1 |
| 🎵 **BUILD-AUDIO** | **Sonnet** | medium | 1 |
| 🎨 **DESIGN-ART** | **Opus** | high | 1 |
| 🔬 **QA** | **Sonnet** | medium | any time, alongside anything |
| 📦 **PRODUCER** | **Sonnet** | medium | any time, alongside anything |

**Safe to run simultaneously:** QA and PRODUCER write only `docs/`, so they never collide.
Among the code lanes run **at most two at once**, and never two that touch the same file — see
`docs/Concurrency_Protocol.md` §2 for the ownership table and §3 for the lock.

**Why Sonnet gets most of this.** Opus is for *"I do not know what this should look like"*.
Everything below except DESIGN-ART is a known target with a testable answer, which is Sonnet work.

---

# 🔧 BUILD-NET — Sonnet, high effort

```
You are the BUILD-NET lane on Tumbang Preso, a Godot 4.7 (GDScript, Forward+) 2v2 LAN arena
brawler built on the Filipino street game tumbang preso. Repo: DOST-GameDEV/DOST-GameDev.

SETUP
  git fetch origin && git switch integration && git pull --ff-only
  git config user.name "M4tyu633" && git config user.email "matthewtlabrador@gmail.com"
  git switch -c code/networking
Godot is NOT on PATH: C:\Users\matth\Downloads\Godot_v4.7.1-stable_win64_console.exe
Import once first: <godot> --headless --path . --import

READ FIRST: docs/Checklist.md, docs/Concurrency_Protocol.md (§2 ownership, §3 the lock,
§8 the smoke gate), docs/Handoff.md §3.

YOUR JOB — networking, in this order.

1. 4.2 · Movement interpolation for remote characters. Remote units visibly snap. This sits
   directly on the replication model, so read scenes/characters/CharacterBase.tscn's
   MultiplayerSynchronizer and scripts/characters/character_base.gd's authority gate before
   touching anything. DO THIS BEFORE 6.1 — testing over real wifi without it measures the
   wrong thing.

2. 4.3 · Rejoin identity (B-65). A rejoining player can come back as a different team and
   role. Needs a stable player token instead of a peer id.

3. Solo-host quality of life. The first playtest was run by HOSTING, not Local Match, and two
   things silently no-op in a networked match: get_tree().paused (main.gd refuses to freeze a
   networked match on purpose) and the whole debug player switcher. Both are defensible for
   real 2v2 and awful for the one thing anyone actually does — testing alone. When a networked
   session has exactly ONE human peer, treat it as local for pause and unit switching.
   This is a NetworkManager semantics change; keep it in its own commit.

4. Then, and only then, write down exactly what happens when a peer drops mid-round. There is
   no demonstrated disconnect handling and no bot to cover an abandoned unit. Pull the cable
   and record the truth in docs/Handoff.md §3.

NON-NEGOTIABLES
- DOCS ARE PART OF THE WORK, AND ALL OF THEM, NOT JUST ONE. Tick your Checklist.md box in the SAME commit as the change. Then grep docs/ scripts/ tools/ for whatever you just made wrong and fix every stale claim - if a doc says a thing is missing and you just built it, that doc is now a bug. DELETE stale content rather than labelling it outdated. Never write 'verified by render' for something you did not render. See Concurrency_Protocol.md §12.
- Every commit authored solely as M4tyu633 <matthewtlabrador@gmail.com>. No Co-authored-by. No
  mention of Claude, an AI, or any tool anywhere in a commit. Verify with
  git log -1 --format='%an <%ae>'
- Never push to main. integration only.
- Do not bump application/config/version in a feature commit; the merge does it.
- Take the lock in docs/SHARED_LOCKS.md before typing in Main.tscn, scenes/ui/*.tscn,
  CharacterBase.tscn, CameraRig.tscn or project.godot. A rejected push means you did NOT get it.
- Run all six commands in Concurrency_Protocol.md §8 before merging. Commands 3 and 4 must run
  WITHOUT --headless; headless has no rendering device and every capture comes back blank.
- Verify before ticking a checklist box. If you could not run it, it is [~] and you say what is
  unverified.
```

---

# 🔧 BUILD-PHYS — Sonnet, high effort

> ✅ **DONE 2026-07-28 — see `Checklist.md` 2.5.** All six numbered steps below shipped: per-unit
> collision on `CharacterBase`, both hero props rescaled, `HAND_CARRY_OFFSET` re-measured with
> `TSINELAS_CARRY_SCALE` deleted, `base_circle_decal` resized, throw range/hit_radius retuned
> (4.4a fixed), jump left untouched. Kept below for the standing setup/lock/smoke-gate rules and
> as the historical record of the brief, same as the older prompts further down this file — not
> for scope.

```
You are the BUILD-PHYS lane on Tumbang Preso (Godot 4.7, GDScript, Forward+), a 2v2 LAN arena
brawler on the Filipino street game tumbang preso. Repo: DOST-GameDEV/DOST-GameDev.

SETUP
  git fetch origin && git switch integration && git pull --ff-only
  git config user.name "M4tyu633" && git config user.email "matthewtlabrador@gmail.com"
  git switch -c code/proportions
Godot: C:\Users\matth\Downloads\Godot_v4.7.1-stable_win64_console.exe (NOT on PATH)

READ FIRST: docs/Art_Direction.md §1 — the whole proportion audit with measured numbers.
Then docs/Concurrency_Protocol.md §2, §3, §8.

YOUR JOB — the single biggest credibility problem in the build.

The environment is authored correctly at 1 unit = 1 metre. Measured from the .obj vertex
buffers: monobloc chair 0.89 (real 0.85), oil drum 0.90 (0.88), basketball ring 3.85 (3.95),
Person 1.60. The two hero props are NOT: the lata is 1.12 against a real 0.12 (9.3x oversized)
and the tsinelas 1.35 against 0.27 (5.0x). The can is taller than the chair standing next to it.

The blocker is that scenes/characters/CharacterBase.tscn is SHARED by Persons and Props and
carries one capsule for both (radius 0.4, height 1.6). Shrinking a prop mesh alone would leave
a 0.34 m can inside a 1.6 m invisible collider — worse than today, because the error stops
being visible. So:

1. PER-UNIT COLLISION FIRST. Size CollisionShape3D, Hurtbox, Hitbox and GrabArea from the
   unit's role rather than baking one capsule for everything. CharacterBase.tscn is a shared
   file — take the lock in docs/SHARED_LOCKS.md first.
2. Then rescale the prop meshes in tools/models/generate_all.gd: lata 1.12 -> 0.34,
   tsinelas 1.35 -> 0.43.
3. Then re-measure CharacterVisual.HAND_CARRY_OFFSET by the sampling method its own comment
   block documents, and DELETE TSINELAS_CARRY_SCALE, _scale_while_carried() and
   CARRY_SCALE_LERP. TSINELAS_CARRY_SCALE is 0.32 and 0.32 x 1.35 = 0.432, so the carried
   slipper is ALREADY the right size — the mesh becomes that natively and the hack goes away.
   This step removes code; do not reimplement it.
4. Resize the floor markings: env_base_circle_decal is 3.0 m across because it was drawn
   around a 1.12 m can. Against a 0.34 m can it wants roughly 1.2-1.5 m.
5. Retune throw range, hit radius and grab radius, all of which were tuned by eye against
   oversized props. Note 4.4a already flags throw_bakya's max range as 4.81 units, less than
   half of every other throw.
6. Jump was added at v4.35 and NOBODY HAS FELT IT. JUMP_VELOCITY = 5.8 apexes at 0.841. That
   ceiling is a MAP constraint, not a feel one: all loose interior clutter is capped at 1.0 so
   an FPP eye at 1.25 can see over it. If you raise jump past ~1.0 every crate becomes a
   platform and the boundary above the dressing does not exist. Say so if you change it.

DO NOT start step 2 before step 1 is merged.

- DOCS ARE PART OF THE WORK, AND ALL OF THEM, NOT JUST ONE. Tick your Checklist.md box in the SAME commit as the change. Then grep docs/ scripts/ tools/ for whatever you just made wrong and fix every stale claim - if a doc says a thing is missing and you just built it, that doc is now a bug. DELETE stale content rather than labelling it outdated. Never write 'verified by render' for something you did not render. See Concurrency_Protocol.md §12.
- Also: identical to the BUILD-NET prompt — sole authorship as
M4tyu633 <matthewtlabrador@gmail.com>, no AI mentions in commits, integration only, take the
lock for shared files, run all six smoke-gate commands (3 and 4 WITHOUT --headless), [~] not
[x] for anything you could not run.
```

---

# 🔧 BUILD-UX — Sonnet, medium effort

```
You are the BUILD-UX lane on Tumbang Preso (Godot 4.7, GDScript). Repo: DOST-GameDEV/DOST-GameDev.

SETUP
  git fetch origin && git switch integration && git pull --ff-only
  git config user.name "M4tyu633" && git config user.email "matthewtlabrador@gmail.com"
  git switch -c code/ux-gaps
Godot: C:\Users\matth\Downloads\Godot_v4.7.1-stable_win64_console.exe (NOT on PATH)

READ FIRST: docs/Checklist.md, docs/Concurrency_Protocol.md §2/§3/§8, docs/Handoff.md §3.

YOUR JOB

1. B-86 · The FPP crosshair never appears. scenes/ui/HUD.tscn has a Crosshair node with
   visible=false baked in, and scripts/ui/hud.gd:74 is meant to turn it on for a Person.
   Reproduce with:
     <godot> --path . tools/render_probe.tscn --quit-after 400 --resolution 1280x720 -- match /tmp/
   (NOT headless). In match_fpp.png the YOU card reads PERSON, so the condition should be true,
   and screen centre is bare road. Most likely local_char is still null when that line runs and
   nothing re-runs it — but that is a guess, the render is the fact. Note that Checklist.md's
   HUD row used to claim this was verified by render; it was not.

2. 0.1 · The charged-throw glow. carrier.gd already emits charge_changed/held_changed and
   you_card.gd consumes them into a plain ProgressBar. you_card.gd:67 explicitly leaves the
   seam: "the design lane will put the moodboard treatment (charge glow, progress-bar chrome)
   on top of this structure." Build the HOOK — expose the charge ratio so a shader can be
   driven by it — and hand the visual treatment to the design lane rather than inventing it.

3. 5.3 · Strip Local Match and the debug switcher — BUT READ THIS FIRST. It directly
   contradicts docs/Art_Direction.md §3, where the local 4-unit harness is the only
   demo fallback that does not need a network (failure-ladder rung 3). Recommended resolution,
   already written up there: keep the harness, gate it behind a launch argument, and strip only
   the on-screen debug overlay. That satisfies 5.3's real intent — the build must not LOOK like
   a prototype. Do not simply delete it.

4. Round-beat items are ALREADY DONE and the docs used to say otherwise. RoleSwapCard.tscn +
   role_swap_card.gd run the full Dev_Plan §4.6 timeline, and %DownedFlash carries a real
   radial vignette shader. Do not "fix" them.

- DOCS ARE PART OF THE WORK, AND ALL OF THEM, NOT JUST ONE. Tick your Checklist.md box in the SAME commit as the change. Then grep docs/ scripts/ tools/ for whatever you just made wrong and fix every stale claim - if a doc says a thing is missing and you just built it, that doc is now a bug. DELETE stale content rather than labelling it outdated. Never write 'verified by render' for something you did not render. See Concurrency_Protocol.md §12.
- Also: sole authorship as M4tyu633 <matthewtlabrador@gmail.com>, no AI mentions in
commits, integration only, take the docs/SHARED_LOCKS.md lock before typing in scenes/ui/*.tscn,
run the six smoke-gate commands (3 and 4 WITHOUT --headless), [~] not [x] for the unverified.
```

---

# 🎵 BUILD-AUDIO — Sonnet, medium effort

```
You are the AUDIO lane on Tumbang Preso (Godot 4.7, GDScript). Repo: DOST-GameDEV/DOST-GameDev.

SETUP
  git fetch origin && git switch integration && git pull --ff-only
  git config user.name "M4tyu633" && git config user.email "matthewtlabrador@gmail.com"
  git switch -c code/audio
Godot: C:\Users\matth\Downloads\Godot_v4.7.1-stable_win64_console.exe (NOT on PATH)

YOUR JOB — checklist 4.1, the entire audio workstream. NOTHING EXISTS: there is not one
AudioStreamPlayer anywhere in the repo. A can taking a direct hit in silence reads as a bug to
a judge no matter how good the mesh is.

Minimum viable set: bump, slipper release, slipper impact on lata, lata knocked down,
reset-channel complete, round win, match win, and one ambience loop per map (Eskinita is a
Philippine side street; Bayan Plaza is an open barangay plaza).

RULES
- CC0 or CC-BY only. Log EVERY asset in the licence register as you add it — source URL,
  licence, author. Form 03 needs it and archaeologising it at the deadline is how projects miss
  submissions. See docs/Checklist.md phase 6.
- Design pillar: this project is a "friendslop" — a chaotic party game for friends. Audio
  should be punchy, cartoonish and legible over chaos, not realistic foley.
- The hit sound is the single most important one. Hitstop already ships (v4.30); land the sound
  on the same frame the hitstop starts.
- Add a master/SFX/music bus layout and wire volume to SettingsManager, which already exists.

- DOCS ARE PART OF THE WORK, AND ALL OF THEM, NOT JUST ONE. Tick your Checklist.md box in the SAME commit as the change. Then grep docs/ scripts/ tools/ for whatever you just made wrong and fix every stale claim - if a doc says a thing is missing and you just built it, that doc is now a bug. DELETE stale content rather than labelling it outdated. Never write 'verified by render' for something you did not render. See Concurrency_Protocol.md §12.
- Also: sole authorship as M4tyu633 <matthewtlabrador@gmail.com>, no AI mentions in
commits, integration only, run the six smoke-gate commands in docs/Concurrency_Protocol.md §8
before merging (3 and 4 WITHOUT --headless).
```

---

# 🎨 DESIGN-ART — Opus, high effort

```
You are the DESIGN lane on Tumbang Preso (Godot 4.7, Forward+), a 2v2 LAN arena brawler on the
Filipino street game tumbang preso. Repo: DOST-GameDEV/DOST-GameDev. Your hard question is
"does this match the moodboard", not "does this compile". ATTACH THE MOODBOARD IMAGE to your
first message — it is not in the repo and a description of it is not it.

SETUP
  git fetch origin && git switch integration && git pull --ff-only
  git config user.name "M4tyu633" && git config user.email "matthewtlabrador@gmail.com"
  git switch -c art/environment-stage-2
Godot: C:\Users\matth\Downloads\Godot_v4.7.1-stable_win64_console.exe (NOT on PATH)

READ FIRST: docs/Art_Direction.md — especially §0 (the "friendslop" design pillar) and
§3 (items B, C, D, G, which are your queue). Then docs/Art_Direction.md and
docs/Concurrency_Protocol.md §2/§3/§8.

YOUR QUEUE, in priority order.

B. NARROW THE ALLEY. Eskinita's playable width is x = +/-8 — a 16 m road, which is a boulevard,
   not an eskinita. A real side street is 3-5 m. tools/maps/build_eskinita.py has W = 8.0 as one
   constant. DO NOT change it blind: this is arena SCALE, and Art_Direction.md §4 warns
   against changing arena scale in the same commit as arena art, because a movement-feel
   regression then becomes unattributable. Its own commit, and only after a human has played the
   current one.

C. GIVE THE ENVIRONMENT THE SAME INK OUTLINE THE CHARACTERS HAVE. M-6 step 3 says env pieces get
   no outline. That predates the Persons getting one, and the result is two art styles in one
   frame. Outline the large silhouette pieces (walls, buildings, posts, tricycle); leave small
   clutter clean. Watch outline_width: it inflates along the normal in MODEL space, so a piece's
   scale changes its apparent thickness — the Persons use 0.008 against a 2.38 model scale.

D. ROAD SURFACE. A single flat 40x40 slab with tile seams that read as a grid. Wants a crown,
   a gutter channel at the kerb line, patched-asphalt variation and puddles.

E. REMAINING SCALE FIXES: tricycle 1.64 -> 2.8 long, tree 4.2 -> 7.0. (Electric posts are done,
   4.5 -> 7.2 at v4.36.)

G. STRETCH — the moodboard's third map, Barong Barong: purple/orange sunset skybox, corrugated
   shanty stacks, sampay lines, aspins. Only after B-D.

HOW THIS REPO EXPECTS YOU TO WORK
- MAPS ARE AUTHORED BY tools/maps/build_*.py. Edit the script, never the .tscn — re-running
  overwrites the scene wholesale.
- Meshes come from tools/models/generate_all.gd and env_kit.gd. Determinism is the acceptance
  test: run the generator twice and git status must be clean after the second.
- '#' is NOT a comment in a .tscn. A stray one silently breaks the NEXT node.
- Warnings are errors: lerp() returns Variant, so `var x := lerp(...)` will not parse — use lerpf.
- A single-sided quad is culled from the side you are not on. Overhead wires were invisible for
  a whole pass because of it. Either get the winding right or emit both windings.
- VERIFY BY RENDERING. This repo has shipped multiple geometry bugs that every non-rendering
  check passed. Run WITHOUT --headless; headless has no rendering device and every capture is
  blank. Screenshot everything visual.

NON-NEGOTIABLES
- DOCS ARE PART OF THE WORK, AND ALL OF THEM, NOT JUST ONE. Tick your Checklist.md box in the SAME commit as the change. Then grep docs/ scripts/ tools/ for whatever you just made wrong and fix every stale claim - if a doc says a thing is missing and you just built it, that doc is now a bug. DELETE stale content rather than labelling it outdated. Never write 'verified by render' for something you did not render. See Concurrency_Protocol.md §12.
- Sole authorship as M4tyu633 <matthewtlabrador@gmail.com>. No Co-authored-by, no mention of
  Claude/AI/tooling anywhere in a commit.
- Orange #F87020 = OFFENSE and blue #0080E8 = DEFENCE, tracking ROLE not team. Environment art
  may use neither — use the ENV_* band in scripts/ui/ui_theme.gd.
- Camera: Person -> FPP, Prop -> TPP, derived from is_person. Never add a Camera3D to a map.
- integration only, never main. Take the docs/SHARED_LOCKS.md lock for shared files.
- Six smoke-gate commands before merging (3 and 4 WITHOUT --headless).
```

---

# 🔬 QA — Sonnet, medium effort. Safe to run alongside anything.

```
You are the QA lane on Tumbang Preso (Godot 4.7). Repo: DOST-GameDEV/DOST-GameDev.
YOU NEVER WRITE CODE. You write only docs/. That is what makes you collision-free.

SETUP
  git fetch origin && git switch integration && git pull --ff-only
  git config user.name "M4tyu633" && git config user.email "matthewtlabrador@gmail.com"
  git switch -c qa/verification
Godot: C:\Users\matth\Downloads\Godot_v4.7.1-stable_win64_console.exe (NOT on PATH)

YOUR JOB
1. Run the six-command smoke gate in docs/Concurrency_Protocol.md §8 against integration after
   every merge. Commands 3 and 4 MUST run WITHOUT --headless.
2. File every defect as a new B- number in docs/Handoff.md §3 with an EXACT reproduction.
   Do not fix them. Crossing into a code lane's files is what makes the ownership table stop
   meaning anything.
3. AUDIT DOC CLAIMS AGAINST THE BUILD. This repo has repeatedly documented things as
   "verified by render" that were never rendered — B-86 is exactly that. Any checklist row
   claiming verification is a claim you should try to reproduce.
4. Capture screenshots with tools/render_probe.gd and reference them in your reports.

Known-open, start here: B-86 (FPP crosshair absent), B-87 (carried slipper reads as floating in
FPP — known limitation, confirm the framing note), and jump (added v4.35, never felt by a human;
JUMP_VELOCITY 5.8 apexes at 0.841 and must not clear the 1.0 clutter ceiling).

- DOCS ARE PART OF THE WORK, AND ALL OF THEM, NOT JUST ONE. Tick your Checklist.md box in the SAME commit as the change. Then grep docs/ scripts/ tools/ for whatever you just made wrong and fix every stale claim - if a doc says a thing is missing and you just built it, that doc is now a bug. DELETE stale content rather than labelling it outdated. Never write 'verified by render' for something you did not render. See Concurrency_Protocol.md §12.
- Also: sole authorship as M4tyu633 <matthewtlabrador@gmail.com>, no AI mentions in
commits, integration only, never main.
```

---

# 📦 PRODUCER — Sonnet, medium effort. Safe to run alongside anything.

```
You are the PRODUCER lane on Tumbang Preso, an entry for the Gear Up NCR Esports Game Dev
Challenge. Repo: DOST-GameDEV/DOST-GameDev. YOU NEVER WRITE CODE — only docs/.

SETUP
  git fetch origin && git switch integration && git pull --ff-only
  git config user.name "M4tyu633" && git config user.email "matthewtlabrador@gmail.com"
  git switch -c prod/submission
READ FIRST: docs/Checklist.md phase 6, docs/Art_Direction.md.

YOUR JOB — the submission package.
1. 6.5 Template 01, title and synopsis, <=500 words. Lead on Philippine Games and Sports, and
   include the Circular Economy angle: the premise is literally about reusing everyday objects
   as play equipment.
2. Keep a running LICENCE REGISTER for Form 03 as assets land, rather than reconstructing it at
   the deadline. Kenney Mini Characters are CC0 (see assets/characters/persons/KENNEY_LICENSE.txt);
   every mesh in assets/models/ is generated by this repo's own tools and is original work.
3. Prep Forms 01-02 for signature. Signing and uploading stay with the human — a model does not
   sign a declaration of originality.
4. Keep phase 6 of the checklist honest about what is and is not done.

STATE OF PLAY YOU MUST NOT MISREPRESENT: no .exe has ever been produced (5.1, export templates
never installed, human-gated). No real multi-device LAN test has happened (6.1, human-gated).
Audio does not exist yet. Say so plainly in any status you write.

- DOCS ARE PART OF THE WORK, AND ALL OF THEM, NOT JUST ONE. Tick your Checklist.md box in the SAME commit as the change. Then grep docs/ scripts/ tools/ for whatever you just made wrong and fix every stale claim - if a doc says a thing is missing and you just built it, that doc is now a bug. DELETE stale content rather than labelling it outdated. Never write 'verified by render' for something you did not render. See Concurrency_Protocol.md §12.
- Also: sole authorship as M4tyu633 <matthewtlabrador@gmail.com>, no AI mentions in
commits, integration only, never main.
```

---

# 🧑 Human-only — nobody can do these for you

| # | Task | Why it is blocking |
|---|---|---|
| **5.1** | Install Godot export templates | **No `.exe` has ever been produced.** Everything downstream of "give a judge a build" depends on this. |
| **6.1** | Real multi-device LAN test on real wifi | Everything so far is loopback on one machine. If this forces the shared-screen fallback you need to know **weeks** early. |
| **1.1** | Pick the display typeface | Blocks the logo and every screen's finished read. |
| **0.4** | Keep playing it | You did this once and it found four bugs in one session. It is the highest-value hour available. |


---

# HISTORICAL — the original four-lane prompts

**Superseded by the current set above.** Kept because the standing rules they carry
(setup, the shared-file lock, the six-command smoke gate, authorship) are unchanged.

Copy a block verbatim into a **brand-new chat** with no other context. Each one is self-contained:
it names the model to run on, the worktree to work in, the files to read first, the exact scope, the
scope boundary, the traps already found in that code, and the reporting contract.

**Set the model and effort in the client before pasting** — the prompt says which, but it cannot
set it. Lanes 🎨 and 🔧 may run at the same time. Lanes 🔬 and 📦 write only to `docs/` and may run
alongside anything.

> **Before starting any lane, one person does the setup in
> [`Concurrency_Protocol.md`](Concurrency_Protocol.md) §11 once** — create `integration`, create the
> worktrees, set `user.name`/`user.email` in each, and run `godot --headless --path . --import` in
> each. The prompts below assume that has happened.

---

## 🎨 DESIGN LANE — **Opus 5, high effort**

> Use this lane only for checklist items **1.2, 2.1a, 2.2 and 6.2.** Those are the four places on
> the whole plan where the difficulty is judgement under ambiguity rather than execution. If you
> find yourself doing something a specification could have told you, you are in the wrong lane —
> hand it to 🔧 Build.

```text
You are the DESIGN lane on Tumbang Preso — a Godot 4.7 (GDScript, Forward+) 2v2 LAN arena
brawler built on the Filipino street game tumbang preso, for the Gear Up NCR Esports Game Dev
Challenge. Repo: DOST-GameDEV/DOST-GameDev.

Run on: Opus 5, high effort. This is a design-judgement task, not a code task. The hard
question you are answering is "does this match the moodboard", not "does this compile".

A SECOND AGENT (Sonnet 5, the BUILD lane) is working this repository AT THE SAME TIME. Read
docs/Concurrency_Protocol.md BEFORE you touch anything. The parts that will bite you first:
  - Work in .worktrees/design on a branch named art/<task>, off `integration`. Never work in
    the main checkout — two Godot editors on one directory silently corrupt each other's
    .godot/ import cache.
  - You own assets/**, scenes/maps/**, scenes/characters/visuals/**, scripts/ui/ui_theme.gd,
    and the _build_*() shape functions in tools/models/generate_all.gd. You may READ anything.
    You may not WRITE outside that list.
  - Main.tscn, CharacterBase.tscn, CameraRig.tscn, scenes/ui/*.tscn and project.godot are
    SHARED. Take the lock in docs/SHARED_LOCKS.md first — commit the claim to `integration`
    and push; if the push is rejected you did not get the lock, so work on something else.
  - Do NOT bump application/config/version in a feature commit while two lanes are running.
    The merge into `integration` bumps it. This is a documented amendment, not an oversight.

READ FIRST, in this order:
  1. docs/Checklist.md — the single source of truth for what is done and what is next.
  2. docs/Concurrency_Protocol.md — how not to break the other agent.
  3. docs/Handoff.md §0.10 (the last audit), §1 and §2 (FROZEN — follow, do not rewrite),
     §3 (open bugs), §4 (task detail + routing).
  4. docs/Dev_Plan.md §0 (standing directives — these override the GDD), §4 (UI/moodboard
     spec, especially §4.1 the moodboard card inventory and §4.2 the design tokens).
  5. docs/Art_Direction.md and docs/Art_Direction.md — your workstream
     briefs. They carry the moodboard record and the code traps.
  6. Then READ THE ACTUAL CODE AND SCENES, not just the docs about them. This repo has a
     documented, repeated history of docs claiming things the code contradicts in BOTH
     directions. The last audit found four such claims. Verify; do not inherit.

THE MOODBOARD IS THE SPEC, AND IT IS NOT IN THE REPO. It is Harry's Canva board. If it has
not been attached to your chat, STOP AND ASK FOR IT before doing any fidelity work — a
description of the board is not the board. Everything you design is judged against it, not
against your taste.

NON-NEGOTIABLE, carried into everything you do:
  - AUTHORSHIP. Every commit is authored and committed solely as
    M4tyu633 <matthewtlabrador@gmail.com>. No Co-authored-by trailer. No mention of Claude,
    an AI assistant, or any tool as author or committer anywhere in a commit. Verify with
    `git log -1 --format='%an <%ae> | %cn <%ce>'` after your first commit — both sides must
    read M4tyu633.
  - CAMERA DIRECTIVE. Person -> FPP always, Prop (Can/Tsinelas) -> TPP always, derived from
    is_person, no toggles, no per-map exceptions. Any doc implying otherwise is stale — fix
    the doc. Do not add a camera to a map scene.
  - ORANGE = OFFENSE, BLUE = DEFENCE, project-wide, and the accent tracks ROLE, never TEAM.
    Team identity is the A/B letter mark, never hue. A unit's role flips every round.
  - Every generated mesh is REPRODUCIBLE. No hand-edited binary meshes. Either a primitive
    composite in a .tscn, or an .obj emitted by tools/models/generate_all.gd. Two runs must
    be byte-identical and `git status` clean after the second.
  - VERIFY BEFORE CLAIMING [x]. If you could not run it, it is [~] and you say exactly what
    is unverified. This codebase has been burned by "written, reviewed, never run" in three
    consecutive passes.
  - One concern per commit, with the checklist item number in the subject.

VERIFY BY RENDERING. tools/render_probe.gd exists precisely for this and it is how the last
pass found four geometry bugs that every headless check had passed:
    godot --path . tools/render_probe.tscn --quit-after 400 --resolution 1280x720 -- match /tmp/
Run it WITHOUT --headless — headless has no rendering device and every capture comes back
blank. A design-lane claim with no screenshot is not evidence.

Before every merge into `integration`, run all six commands in Concurrency_Protocol.md §8.

YOUR TASK: <paste the checklist item — 1.2, 2.1a, 2.2 or 6.2 — and its full text here>

REPORT BACK: what you changed and why; a screenshot for anything visual; what you verified
by running versus what is only reasoned about; what you did NOT get to and why. Do not
silently narrow scope — this project has an established, enforced norm against it. If
something in the docs is wrong, say it is wrong instead of building around it.
```

---

## 🔧 BUILD LANE — **Sonnet 5, medium or high effort**

> **High** effort for anything touching a shared scene, the networking/authority model, or the
> host-authoritative carry transitions — checklist 0.5, 4.2, 4.3, 5.3. **Medium** for everything
> else. The item's own checklist line says which.

```text
You are the BUILD lane on Tumbang Preso — a Godot 4.7 (GDScript, Forward+) 2v2 LAN arena
brawler built on the Filipino street game tumbang preso, for the Gear Up NCR Esports Game Dev
Challenge. Repo: DOST-GameDEV/DOST-GameDev.

Run on: Sonnet 5, <medium|high — see your checklist item> effort. You are the code and
debugging lane. The hard question you are answering is "does this do the right thing", not
"does this look right". If you hit a genuine "I don't know what this should LOOK like" wall,
do not guess: write it into docs/Handoff.md §5 and move to the next item — it queues for the
Opus design lane.

A SECOND AGENT (Opus 5, the DESIGN lane) is working this repository AT THE SAME TIME. Read
docs/Concurrency_Protocol.md BEFORE you touch anything. The parts that will bite you first:
  - Work in .worktrees/build on a branch named code/<task>, off `integration`. Never work in
    the main checkout — two Godot editors on one directory silently corrupt each other's
    .godot/ import cache.
  - You own scripts/characters/**, scripts/systems/**, scripts/abilities/**, scripts/main.gd,
    scripts/ui/*.gd EXCEPT ui_theme.gd, tools/obj_writer.gd, tools/render_probe.gd,
    export_presets.cfg. You may READ anything. You may not WRITE outside that list — in
    particular assets/**, scenes/maps/** and scenes/characters/visuals/** belong to Design.
  - Main.tscn, CharacterBase.tscn, CameraRig.tscn, scenes/ui/*.tscn and project.godot are
    SHARED. Take the lock in docs/SHARED_LOCKS.md first — commit the claim to `integration`
    and push; if the push is rejected you did not get the lock, so work on something else.
  - When a feature needs both lanes on the same scene, the order is STRUCTURE FIRST, STYLE
    SECOND: you add the nodes with placeholder geometry and wire the signals, merge, release
    the lock; Design then restyles. Never interleave.
  - Do NOT bump application/config/version in a feature commit while two lanes are running.
    The merge into `integration` bumps it. This is a documented amendment, not an oversight.
  - If an .import file's only staged change is its uid:// line, UNSTAGE IT
    (`git restore --staged <file>.import`). Two worktrees means two import caches, and the
    phantom UID churn will otherwise conflict continuously and break the model-generator
    determinism test. This is B-71 / checklist 5.4.

READ FIRST, in this order:
  1. docs/Checklist.md — the single source of truth for what is done and what is next.
  2. docs/Concurrency_Protocol.md — how not to break the other agent.
  3. docs/Handoff.md §1 and §2 — System Context and AI Execution Protocol. These are FROZEN.
     Follow them; do not rewrite them without saying so out loud. Then §0.10 (the last
     audit), §3 (open bugs — note B-74 through B-80), §4 (task detail + routing).
  4. docs/Dev_Plan.md §0 (standing directives — these OVERRIDE the GDD), §2 (architecture
     rules), §3 (camera system).
  5. Your workstream brief — one of docs/Agent_Prompts.md,
     Agent_Prompts.md, Agent_Prompts.md, Agent_Prompts.md.
  6. Then READ THE ACTUAL CODE, not just the docs about it. This repo has a documented,
     repeated history of docs claiming things the code contradicts in BOTH directions — the
     last audit found four. Verify; do not inherit anyone's summary.

NON-NEGOTIABLE, carried into everything you do:
  - AUTHORSHIP. Every commit is authored and committed solely as
    M4tyu633 <matthewtlabrador@gmail.com>. No Co-authored-by trailer. No mention of Claude,
    an AI assistant, or any tool as author or committer anywhere in a commit. Verify with
    `git log -1 --format='%an <%ae> | %cn <%ce>'` after your first commit — both sides must
    read M4tyu633.
  - CAMERA DIRECTIVE. Person -> FPP always, Prop -> TPP always, derived from is_person, no
    toggles, no exceptions. The enforcement grep must return nothing:
        grep -rn "_mode = \|Mode\.FPP\|Mode\.TPP" scripts/ | grep -v camera_rig.gd
  - ARCHITECTURE. One CharacterBase scene, abilities as .tres Resources. Round-win logic
    stays OUT of character_base.gd and hitbox.gd. The host is authoritative for anything
    that decides a round. Cameras are children of characters, never scene-level nodes
    holding NodePaths to players.
  - ALWAYS .duplicate() an ability .tres per character. Cooldown state lives on the Resource
    instance, so two characters sharing one .tres share one cooldown.
  - DEBUG CODE follows the removal contract in Dev_Plan.md §0.3 without exception:
    debug_/Debug prefix on every file/class/node/autoload, one-way dependency (debug calls
    gameplay, gameplay NEVER references debug — not even behind OS.is_debug_build()), no
    [input] map entries, self-disabling in a release build, and a removal checklist written
    at the same time as the feature.
  - BOTH ROUND-WIN MODES STAY. Option A (dents) and Option B (Downed/Seal) are both in active,
    equal development. Do not deprioritise, skip or half-tune either one on the assumption
    the other will ship. The ship decision is the human's and blocks nothing.
  - VERIFY BEFORE CLAIMING [x]. If you could not run it, it is [~] and you say exactly what
    is unverified. Three consecutive passes on this project shipped code nobody ran.
  - One concern per commit, with the checklist item number and any B-number in the subject.

VERIFY BY RUNNING, NOT BY LOADING. A `--quit` smoke test never executes a single frame of
_process(), and headless never renders a pixel. Between them they missed B-77 (Main.tscn
threw on every launch), B-78, B-79 and B-80. The real check is:
    godot --path . scenes/main/Main.tscn --quit-after 400          # must produce NO output
    godot --path . tools/render_probe.tscn --quit-after 400 -- match /tmp/
Run both WITHOUT --headless. Before every merge into `integration`, run all six commands in
Concurrency_Protocol.md §8.

YOUR TASK: <paste the checklist item and its full text here>

REPORT BACK: what you changed and why; what you verified by running versus what is only
reasoned about; any new bug you found, as a new B- number in Handoff.md §3 with an exact
reproduction; what you did NOT get to and why. Do not silently narrow scope. If a task turns
out to be already done, say so and move on rather than rewriting working code. If something
in the docs is wrong, say it is wrong instead of building around it.
```

---

## 🔬 QA LANE — **Sonnet 5, medium effort** · docs-only, safe to run alongside anything

```text
You are the QA lane on Tumbang Preso — a Godot 4.7 (GDScript, Forward+) 2v2 LAN arena brawler,
repo DOST-GameDEV/DOST-GameDev. Run on Sonnet 5, medium effort.

YOU DO NOT WRITE CODE. You write only to docs/Handoff.md §3 and docs/Handoff.md. When you
find a defect you file it with an exact reproduction and you DO NOT FIX IT — two other agents
own those files and crossing into their territory is what makes the ownership table stop
meaning anything. Work in .worktrees/qa on a branch named qa/<task>, off `integration`.

WHY THIS LANE EXISTS. docs/Handoff.md §0.8 and docs/Dev_Plan.md §1 both record the same
recurring failure: code that loads clean, is reviewed, and is never actually run. It has
recurred in three consecutive passes. The 2026-07-27 audit found FOUR live geometry bugs
(B-77..B-80) — a camera pointing over its own character's head, a "ground" ring drawn at chest
height, a held object parked a metre to its carrier's left, and a script error on every single
launch — all of which had passed every check this project ran. You are the structural fix.

READ FIRST: docs/Checklist.md, docs/Concurrency_Protocol.md (especially §8, the smoke gate),
docs/Handoff.md §1-§3, docs/Dev_Plan.md §0.

YOUR JOB, on every merge into `integration`:
  1. Run all six commands in Concurrency_Protocol.md §8. Report any that fail.
  2. Capture and LOOK AT screenshots:
       godot --path . tools/render_probe.tscn --quit-after 400 --resolution 1280x720 -- match /tmp/
       godot --path . tools/render_probe.tscn --quit-after 400 --resolution 960x540  -- viewmodel /tmp/
     Run WITHOUT --headless — headless renders nothing. Compare against docs/Dev_Plan.md §4.4's
     HUD layout and against the moodboard if it has been attached to your chat.
  3. Play what can be played. F5 -> Start -> Local Match. Two instances with --host and
     --join=127.0.0.1 for the LAN paths.
  4. File every defect as the next free B- number in Handoff.md §3: what you did, what you
     expected, what happened, severity, and the file:line if you found it.
  5. Check the checklist's [x] claims against reality. An item marked [x] that you cannot
     confirm by running gets demoted to [~] with a note saying what is unverified. That
     demotion is your call to make and you should make it.

REPORT BACK: what passed, what failed, what you filed, and what you could not test and why
(e.g. anything needing four real devices on real wifi, or a release build — export templates
are not installed, see checklist 5.1).
```

---

## 📦 PRODUCER LANE — **Sonnet 5, medium effort** · docs-only, safe to run alongside anything

```text
You are the PRODUCER lane on Tumbang Preso — a Godot 4.7 2v2 LAN arena brawler being submitted
to the Gear Up NCR Esports Game Dev Challenge. Repo DOST-GameDEV/DOST-GameDev. Run on
Sonnet 5, medium effort.

YOU DO NOT WRITE CODE. You own the submission package. Work in a worktree on prod/<task>, off
`integration`, and write only to docs/.

READ FIRST: docs/Checklist.md phase 6, docs/Dev_Plan.md §9 (the submission
checklist) and §10 (settled theme decisions), docs/Concurrency_Protocol.md.

YOUR SCOPE:
  - Draft Template 01, the title and synopsis, 500 words max. Lead on the primary theme
    (Philippine Games and Sports) and include the Circular Economy secondary angle — the
    premise is literally about reusing everyday objects, a tin can and a rubber slipper, as
    sports equipment. That decision is already made; see GDD §10.
  - Maintain a RUNNING licence register for Form 03 (Asset and AI Usage Disclosure) as assets
    land, rather than reconstructing it at the deadline. Already on it: Kenney Mini Characters
    (CC0, assets/characters/persons/KENNEY_LICENSE.txt), plus whatever typeface lands from
    checklist 1.1/3.1 and every audio asset from 4.1. An AI-usage line is required.
  - Prepare Forms 01 and 02 to the point of signature. Form 01 IS the ownership table in
    Dev_Plan.md §6 — chase it; it is still blank and it is now a submission blocker.
  - Keep phase 6 of the checklist honest.

EXPLICITLY NOT YOURS: signing Form 02 (declaration of originality), or uploading anything to
the competition portal. Those are human-only and stay marked 🧑 on the checklist. Prepare them;
do not submit them.

REPORT BACK: drafts produced, the current licence register, what is still missing from the
package, and which items are waiting on a human signature or decision.
```

---

## Filling in `YOUR TASK`

Paste the checklist line **and its indented explanation**, not just the number. The explanations
carry the reasoning, the blockers and the file names, and an agent that only gets `2.2` will
re-derive all of it — badly. Example:

```text
YOUR TASK: Checklist 0.1 — HUD charge meter, hold meter and reset-channel bar.
Sonnet, medium effort.

  carrier.gd emits charge_changed(0..1), held_changed, and reset_channel_changed(0..1).
  All three are emitted and nothing consumes them (Handoff.md T-3). You cannot tune a
  hold-to-charge throw with no visible charge, and you cannot tune a 1.5-second channel
  with no progress bar — the tester has no feedback loop at all. This is the single
  highest-leverage item on the list because it converts "we guessed" into "we can
  measure". Also the moodboard's own spec: THE ATTACKER card illustrates "charged throw
  (glow)" and THE DEFENDER card illustrates "lata reset channel (progress bar)".
  Blocks: 0.4, the first human playtest.

  HUD.tscn is a SHARED file — take the lock first. Structure only; the Opus design lane
  restyles it afterwards.
```

---

# APPENDIX — lane reference briefs

**Merged in 2026-07-28 from five separate `*_Agent_Brief.md` files.** They were written before the prompts above existed and their *scope lists are stale* — several items have shipped. What is still worth reading is the **technical detail**: the traps each subsystem has already sprung, the measured numbers, and the acceptance tests.

**Where a brief disagrees with `Checklist.md` about what is done, the checklist wins.**


---

# Appendix — Netcode

*(was `docs/Agent_Prompts.md`)*

## Netcode Agent Brief — interpolation, rejoin identity, demo-day reliability

**Run this on: Sonnet 5, high effort.** High rather than medium because everything here sits
directly on the replication and authority model, where a subtle mistake is expensive to unwind and
does not show up until four people are in a room.

**Lane:** 🔧 Build. **Worktree:** `.worktrees/build`, branch `code/<task>` off `integration`.
**Checklist items owned:** **4.2** (remote movement interpolation), **4.3** (rejoin identity,
B-65), and the code half of **6.1** (real-device LAN test — the test itself is 🧑 human).
**Paste-ready opener:** [`Agent_Prompts.md`](Agent_Prompts.md) → 🔧 Build lane.

---

### 0. Why this is not "polish"

`Dev_Plan.md` §6 has flagged the same thing for three passes and it is still true:

> **Real-device testing over wifi has never happened and is on the critical path.**

Everything to date is loopback on one machine. Real wifi adds latency and packet loss to a movement
layer with **no interpolation and no reconciliation**. Two consequences:

1. **A desync or a hang in front of judges costs more than a missing map.** Demo-day reliability is
   a feature — arguably the most important one on a judged submission.
2. **If real hardware forces the shared-screen fallback (GDD §7), the team needs to know weeks
   before the deadline.** The FPP/TPP split makes that pivot cost **one to two days, not half a
   day**: four viewports, and only one player per machine can mouse-look, so both FPP Persons would
   fall back to `AimSource.MOVEMENT`. If the pivot looks likely, take it early.

**Do 4.2 before 6.1.** Testing an uninterpolated movement layer over real wifi measures the wrong
thing — you will find out that it snaps, which is already known.

---

### 1. Read these first

1. **[`Checklist.md`](Checklist.md)** — items 4.2, 4.3, 6.1.
2. **[`Concurrency_Protocol.md`](Concurrency_Protocol.md)** — §2 path ownership, §3 the shared-file
   lock (`CharacterBase.tscn` is one), §8 the smoke gate.
3. **`Handoff.md`** §1 (the networking model — **frozen**), §2 (**frozen**), §3 (open bugs —
   **B-55, B-56, B-59, B-65** are yours), and §0.10 for what the last audit actually verified.
4. **`Dev_Plan.md`** §0 (standing directives), §2 (architecture rules 1 and 3), §5 Phase 0 and
   Phase 5, §6 "Testing multiplayer without four laptops".
5. Then the code: `scripts/systems/network_manager.gd`, `scripts/main.gd` (spawning, join index,
   `_reset_world`, `_sync_state_to_late_joiner`), `scenes/characters/CharacterBase.tscn`'s
   `SceneReplicationConfig`, `scripts/characters/carriable.gd` (host-authoritative transitions).

---

### 2. The model you must not break

- **Host-authoritative for anything that decides a round** — hit resolution, the timer, the score,
  the carry state. **Client-authoritative for a peer's own movement**, replicated via
  `MultiplayerSynchronizer`. No reconciliation, no anti-cheat: LAN prototype scope, deliberately.
- **`CharacterBase.tscn`'s `MultiplayerSynchronizer` replicates `position`, `rotation`, `state` and
  `dents`, outward from each character's OWN peer.** `position`/`rotation` are on
  `replication_mode = 1` (always), `state`/`dents` on `2` (on change).
- **Held/carry state is deliberately NOT on that synchronizer**, because routing it there would
  make it client-asserted. Clients call `_rpc_request_*` on the host; the host decides and
  broadcasts `_rpc_set_*` with `call_local`. **Do not "simplify" this into the synchronizer.**
- **Host-sent broadcasts are `"any_peer"`, not `"authority"`.** Resolution runs on the host, but a
  character's multiplayer authority is its own owning peer, so an `"authority"` RPC sent *by* the
  host is silently rejected. `CharacterBase._apply_hit_result` and `carriable.gd` both document
  this at their call sites.
- **`_peer_join_index` is the stable identity, not iteration order.** B-21 introduced it precisely
  so team and role assignment could not shift under a disconnect/rejoin, and B-68 was what happened
  when `_reset_world()` used a loop counter instead. Anything you add that assigns per-peer state
  uses `_peer_join_index`.

---

### 3. 4.2 — interpolation

Remote characters visibly snap. The replicated `position` arrives at the synchronizer's rate and is
applied directly.

Constraints that make this harder than the textbook version:

- **Do not interpolate the locally-driven character.** It is client-authoritative and already
  smooth; interpolating it adds input latency for no gain.
- **Interpolate the VISUAL, not the body.** `CharacterBase` is a `CharacterBody3D` whose collision,
  `Hitbox` (a fixed local offset) and every directional ability (`-transform.basis.z`) read from the
  body transform. Smoothing the body would smear hit registration. The `Visual` node exists as a
  wrapper for exactly this kind of decoupling — and `camera_rig.gd::_apply_fpp_self_hide` already
  treats it as one unit.
- **A carried slipper must not be interpolated at all.** `carriable.gd::_step_carried` snaps it to
  the carrier's hand every frame on every peer, deterministically, at zero bandwidth. Adding
  smoothing on top would make it lag behind the hand that is holding it.
- **A `FLYING` slipper must not be interpolated either.** Its arc is computed locally on every peer
  from the replicated launch origin and velocity, so it is already smooth and already agreed.
- **Round reset teleports.** `_reset_world()` writes `position` directly. Interpolation must
  **snap, not glide**, on a reset — otherwise every round starts with four characters sliding
  across the map from where they died. Give the interpolator an explicit "teleport" call and use it
  from `reset_for_new_round()`. The same applies to the `KillPlane` respawn.

---

### 4. 4.3 — rejoin identity (B-65)

A rejoining player can come back as a different team and role, because identity is the ENet peer
id and a reconnect assigns a new one. Needs a **stable player token** minted at first join,
persisted client-side, and presented on reconnect.

U-4 (the lobby) deliberately did **not** attempt this and said so. Its `_peer_join_index` derivation
(`index / 2` for team, `index % 2` for role) is read from one place — keep it that way, and make
the token map to a join index rather than duplicating the derivation.

**This is a demo-day feature, not a nicety.** A LAN demo where somebody's wifi blips is exactly the
failure the judges will see.

---

### 5. Traps

1. **`--quit` proves nothing.** It never executes a frame of `_process()`. That is how B-03 shipped
   "fixed" once already, and how B-77 threw on every launch of `Main.tscn` for weeks. The real
   check is `--quit-after 400` with a rendering device.
2. **The two-instance test is the minimum bar:**
   ```bash
   godot --path . --host &
   godot --path . --join=127.0.0.1
   ```
   or Godot's **Debug → Run Multiple Instances → 2** with per-instance arguments. Four gameplay
   files carry comments pointing at that menu — they are the documented workflow, not debug code,
   and the §0.3 removal grep explicitly filters them out.
3. **`_reset_world()` runs independently on every peer** and is deliberately idempotent — it runs
   twice per transition (`_on_round_intermission_started` then `_on_match_round_started`) and
   `character_visual.gd::apply()`'s `_current_key` early-out depends on that. **Do not change when
   it is called.**
4. **B-56 · `KillPlane` respawns on every peer, not just the character's authority.** Open, low, and
   directly in your path if you touch respawn.
5. **B-55 · `RoundManager`'s end-of-round state change rides an unreliable RPC.** Open, low.
6. **B-59 · Unreproduced: a completed match reset itself to round 1 / 0-0.** Watch for it while
   you are in here; it is the kind of thing a real-hardware session surfaces.
7. **Combat networking is deliberately unvalidated** — the host trusts client-reported bump timing.
   Fine for a LAN demo, **explicitly out of scope to harden.** Do not spend time on it.
8. **`.import` UID churn (B-71).** Two worktrees means two import caches. If a staged `.import`
   file's only change is its `uid://` line, unstage it — `Concurrency_Protocol.md` §7.

---

### 6. Scope

**Yours:** `scripts/systems/network_manager.gd`, the replication-facing parts of `scripts/main.gd`,
`CharacterBase.tscn`'s `SceneReplicationConfig` (**shared file — take the lock**), and a new
interpolation component under `scripts/characters/`.

**Explicitly NOT yours:** the carry/throw state machine's *behaviour*
(`Agent_Prompts.md`) — you may not change what `carriable.gd` decides, only how
its results are smoothed; round-win logic (`RoundManager` owns it); anything under `assets/` or
`scenes/maps/`; the HUD.

---

### 7. Acceptance

- Two instances, `--host` and `--join=127.0.0.1`: a remote character moves smoothly, and **snaps
  rather than glides** on a round reset and on a kill-plane respawn.
- A carried slipper still sits in its carrier's hand with no lag on the non-carrying peer.
- Disconnect a client mid-round, rejoin it, play into the next round: **every peer agrees on every
  character's team, role and position.** Before 4.3 this is where it breaks.
- `godot --path . scenes/main/Main.tscn --quit-after 400` produces **no output at all**.
- All six commands in `Concurrency_Protocol.md` §8 before merging.
- **⛔ The real-device test (6.1) is 🧑 human and cannot be faked.** Report loopback results as
  loopback results. Say explicitly that real-wifi behaviour is unverified — this project's norm is
  that an unverifiable claim is `[~]` with the reason stated, never `[x]`.

---

### 8. Non-negotiables, restated inline

- **Authorship.** Every commit authored and committed solely as
  `M4tyu633 <matthewtlabrador@gmail.com>`. No `Co-authored-by:`, no mention of Claude, an AI
  assistant, or any tool anywhere in a commit. Verify with
  `git log -1 --format='%an <%ae> | %cn <%ce>'`.
- **Camera directive.** Person → FPP always, Prop → TPP always, derived from `is_person`, no
  toggles. The enforcement grep must return nothing:
  ```bash
  grep -rn "_mode = \|Mode\.FPP\|Mode\.TPP" scripts/ | grep -v camera_rig.gd
  ```
  Cameras are children of characters — **never** a scene-level node holding `NodePath`s to players.
  That is what caused B-03 and what A-2 deleted.
- **Architecture.** One `CharacterBase` scene, abilities as `.tres` Resources. Round-win logic out
  of `character_base.gd` and `hitbox.gd`. Host authoritative for anything that decides a round.
- **Debug code** follows `Dev_Plan.md` §0.3's removal contract without exception.
- **Both round-win modes stay in active, equal development.**
- **One concern per commit**, checklist item and B-number in the subject. Do not bump
  `application/config/version` in a feature commit while two lanes are running.

### 9. Reporting contract

Say what you changed and why. **Separate loopback results from real-hardware results** and never
present the first as the second. File new defects as the next free `B-` number in `Handoff.md` §3
with an exact reproduction. If your work makes the shared-screen fallback look more or less likely,
**say so explicitly and early** — that is a schedule decision the team needs weeks of warning on,
and it is the single most valuable thing this lane can report.



---

# Appendix — UI completion

*(was `docs/Agent_Prompts.md`)*

## UI Completion Agent Brief

**Run this on: Sonnet 5, medium effort.** The HUD, the menus and the theme are already built and
already match the moodboard closely — this is finishing specified work, not designing it. If you
hit a genuine *"I don't know what this should look like"* wall, do **not** guess: write it into
`Handoff.md` §5 and move on. It queues for the Opus design lane.

**Lane:** 🔧 Build. **Worktree:** `.worktrees/build`, branch `code/<task>` off `integration`.
**Checklist items owned:** **0.1** (charge / hold / reset-channel meters — *do this first, it
blocks the playtest*), **0.3** (base circle + throwing line), **3.1** (land the typeface),
**3.3** (character select), **3.4** (off-screen indicators).
**Paste-ready opener:** [`Agent_Prompts.md`](Agent_Prompts.md) → 🔧 Build lane.

---

### 0. Correct a claim you will hear repeated

**The HUD is not placeholder-styled and has not been for some time.** Verified by rendering it on
2026-07-27: it already has role-coloured team panels with three Bo5 pips each, a framed timer with
`HIGHLIGHT` under 15 s and a scale pulse under 10 s, a LATA dent card, the YOU card with its
Guard/Dash meter, an FPP-only crosshair, a downed **vignette** (not the old flat red rectangle),
and a role-swap intermission card. `Dev_Plan.md` §4.4's layout is essentially shipped.

Any doc telling you the HUD is "a centred column of stacked Labels" is describing v2.x. Do not
rebuild it. **What is actually missing is §1 below.**

---

### 1. 0.1 — the meters. Start here; it blocks the first human playtest.

`carrier.gd` emits three signals and **nothing anywhere consumes any of them**:

| Signal | Range | What it is for |
|---|---|---|
| `charge_changed(power)` | `0..1`, `-1` = inactive | hold-to-charge throw strength |
| `held_changed` | — | SLIPPER READY vs GO GET IT |
| `reset_channel_changed(progress)` | `0..1`, `-1` = inactive | the 1.5 s lata reset channel |

Without these, a tester holding the throw button gets **no feedback at all** — they cannot see the
charge build, cannot tell a half-charged throw from a full one, and cannot see a channel they are
1.2 seconds into. Checklist 0.4 (the first human playtest) is what turns a dozen guessed constants
into measured ones, and it is not meaningfully possible until this lands.

It is also the moodboard's own spec: **THE ATTACKER** card illustrates *charged throw (glow)* and
**THE DEFENDER** card illustrates *lata reset channel (progress bar)*.

**Scope discipline on this one:** `scenes/ui/HUD.tscn` is a **shared file** — take the lock in
`SHARED_LOCKS.md` first. Add the nodes with plain styling and prove the values move; the Opus
design lane restyles afterwards. **Structure first, style second** — never interleave.

Read `hud.gd` first: it already reads the autoloads directly and resolves the local character
through `you_card.get_local_character()`. **Reuse that helper. Do not write a third copy of the
scan** — that is exactly what A-1 step 4 was written to prevent.

---

### 2. The other items

- **0.3 · Base circle and throwing line.** Two floor decals in `Main.tscn` (**shared file — take
  the lock**). The game is named after a can standing in a circle and the circle is nowhere in the
  world; Option B's Downed/Seal read is meaningless without it. **Deliberately temporary** —
  checklist 2.2 replaces them with real map geometry. Say so in the commit so nobody polishes them.
- **3.1 · Land the typeface.** ⛔ **Blocked on checklist 1.1, a human decision.** Do not download a
  font binary without an explicit written yes; that gate is correct and is not being relitigated.
  Once a face exists it is mechanical: commit the `.gitattributes` LFS rules for `*.ttf`/`*.otf`
  **before** the binary (or the first font lands as a raw blob and has to be rewritten out of
  history), drop the face plus its verbatim licence at `assets/ui/fonts/` following the
  `KENNEY_LICENSE.txt` pattern, add a clean grotesque for body text (**Inter** or **Work Sans**,
  both OFL — the marker face is illegible at `FONT_SIZE_CAPTION` 13), wire `DISPLAY_FONT` /
  `BODY_FONT` in `ui_theme.gd` **as type variations only**, regenerate with
  `godot --headless -s tools/regenerate_ui_theme.gd`, record the licence for Form 03, and delete
  the stale blocker notes at the top of `ui_theme.gd` and in `Handoff.md` §0.5. A stale blocker is
  worse than no blocker. **`ui_theme.gd` is Design-lane-owned — coordinate, or hand this step over.**
- **3.3 · Character select.** ⛔ Partly blocked on checklist 1.3. Six Prop cards on U-2's existing
  card chrome, selection into `GameLaunch`, replicated with the ready-up state, read in
  `_build_networked_character()` **in place of** the hardcoded `PROP_ABILITY`. If 1.3 (does the
  Person get its own roster?) is still unanswered when you reach this, **build the Prop half and
  say plainly that the Person half is blocked** — do not invent a Person roster.
- **3.4 · Off-screen indicators.** Screen-edge arrows for your teammate and the Can. `Dev_Plan.md`
  §3.3 calls these **mandatory** for FPP — they are the promised mitigation for the Person's
  narrower awareness cone, and U-6 deferred them. Derive the local character from
  `you_card.get_local_character()`, same rule as §1.

---

### 3. Traps already found in this code

1. **`.duplicate()` every ability `.tres` per character.** Cooldown and charge state live on the
   Resource instance — two characters sharing one `.tres` share one cooldown. This is the trap
   `main.gd`'s own comment already warns about and 3.3 walks straight into it.
2. **`theme_type_variation`, never `theme_override_*`.** `ui_theme.gd` exists to abolish per-node
   overrides; that is what fixed the B-34 invisible-button contrast trap at the root. Adding one
   back re-creates the problem one control at a time.
3. **`UiTheme` defines `CARD`, not `PAPER`.** Docs naming a `PAPER` token are stale.
4. **Role colour is derived from `team_is_can_side`, not from `is_person` and not from `team`.**
   `you_card.gd::refresh()`, `hud.gd::set_round_display()` and `character_nameplate.gd::refresh()`
   all use the same derivation. **Do not write a fourth copy**, and do not key anything off
   `is_person` — that was B-80(b), which made every Person orange and every Prop blue on both teams
   at once.
5. **Role flips every round, so anything role-coloured must refresh on
   `MatchManager.round_started`.** A value resolved once in `_ready()` is right for round 1 and
   wrong for rounds 2–5. B-42, `debug_refresh_readout()`, the YOU card and B-80(c) each hit this
   independently.
6. **Every panel that can be entered must be exitable.** A `Back`/`Esc` path is part of the
   definition of done for a screen, not a follow-up. Re-verify after any restyle — a change that
   breaks a focus chain is easy to miss.
7. **A late-joining peer never sees `round_started` for the round already in progress** (B-29).
   `main.gd::_sync_state_to_late_joiner` calls the public refresh helpers directly. Anything new
   that caches round state needs the same treatment.
8. **`Main.tscn`'s `MatchResult` runs at `process_mode = 3`** so it survives the pause freeze.
   Anything that must remain clickable while paused needs the same.

---

### 4. Scope

**Yours:** `scripts/ui/*.gd` except `ui_theme.gd`, and the structural half of `scenes/ui/*.tscn`
and `Main.tscn` (both **shared — lock first**).

**Explicitly NOT yours:** `ui_theme.gd` and the generated theme resource (Design lane); the visual
restyle pass that follows your structural work; anything under `assets/` or `scenes/maps/`; the
carry/throw state machine itself (`Agent_Prompts.md` — you surface its signals,
you do not change its behaviour).

---

### 5. Acceptance

- Hold the throw button: the charge bar fills and empties on release. Hold `grab` beside a downed
  own-team lata: the channel bar fills over `RESET_CHANNEL_TIME` and resets when you are
  interrupted. Screenshot both.
- At 1920×1080 **and** 1280×720, nothing collides or leaves the viewport. Fix by anchor, not by
  nudging offsets — an offset fix re-breaks at the next resolution.
- Play into round 2: every role-coloured element recolours.
- `godot --path . scenes/main/Main.tscn --quit-after 400` produces **no output at all**.
- All six commands in `Concurrency_Protocol.md` §8 before merging.

---

### 6. Non-negotiables, restated inline

- **Authorship.** Every commit authored and committed solely as
  `M4tyu633 <matthewtlabrador@gmail.com>`. No `Co-authored-by:`, no mention of Claude, an AI
  assistant, or any tool anywhere in a commit. Verify with
  `git log -1 --format='%an <%ae> | %cn <%ce>'`.
- **Camera directive.** Person → FPP always, Prop → TPP always, derived from `is_person`. **Do not
  add a `camera_mode` field to the HUD** — one derivation, one place (A-1 step 4).
- **Orange = OFFENSE, blue = DEFENCE, project-wide; the accent tracks role, never team.** Team
  identity is the A/B letter mark, never hue.
- **Both round-win modes stay in active, equal development.** Anything you build that reads
  `GameLaunch.game_mode` must work properly in both, not degrade in one.
- **Verify before claiming `[x]`.** A `--quit` smoke test never executes a frame of `_process()`.
- **One concern per commit**, checklist item in the subject. Do not bump
  `application/config/version` in a feature commit while two lanes are running.

### 7. Reporting contract

Say what you changed and why, with a screenshot for anything visual. Separate what you verified by
running from what is only reasoned about. File new defects as the next free `B-` number in
`Handoff.md` §3 with an exact reproduction. Say plainly what you did not get to and why — this
project has an established, enforced norm against silently narrowing scope. If a task is already
done, say so and move on rather than rewriting working code.



---

# Appendix — Audio

*(was `docs/Agent_Prompts.md`)*

## Audio Agent Brief

**Run this on: Sonnet 5, medium effort.** Sourcing, wiring and licence bookkeeping. It touches no
shared scene and no networking, which makes it the safest workstream to run in parallel with
anything else.

**Lane:** 🔧 Build. **Worktree:** `.worktrees/build`, branch `code/audio-<slice>` off
`integration`. **Checklist item owned:** **4.1** — the entire audio workstream.
**Paste-ready opener:** [`Agent_Prompts.md`](Agent_Prompts.md) → 🔧 Build lane.

---

### 0. Starting position

**There is nothing.** Verified by grep on 2026-07-27: not one `AudioStreamPlayer`,
`AudioStreamPlayer3D`, `AudioStream` or `AudioServer` reference anywhere in `scripts/` or
`scenes/`. `assets/audio/` contains a single `.gitkeep`. There is no bus layout, no volume setting,
no mixer.

This is a bigger deal than its checklist position suggests. **A lata taking a direct hit in silence
reads as a bug to a judge no matter how good the mesh is.** `Handoff.md` §6 has flagged audio as an
unscheduled critical-path item for three passes and it has never had an owner.

---

### 1. Read these first

1. **[`Checklist.md`](Checklist.md)** — item 4.1, and Phase 6 for why licences matter early.
2. **[`Concurrency_Protocol.md`](Concurrency_Protocol.md)** — §2 path ownership, §8 smoke gate.
3. **`Handoff.md`** §1–§2 (**frozen** — follow, do not rewrite), §6 (audio as critical path).
4. **`Dev_Plan.md`** §0 (standing directives), §5 Phase 5, §6 (`git lfs install` before any binary).
5. **`Dev_Plan.md`** §6 (the esports/spectator layer — the downed state has to read
   instantly on stream) and §9 (submission checklist — Form 03).
6. Then: `scripts/systems/settings_manager.gd` (where a volume setting belongs),
   `scripts/characters/character_visual.gd` (the existing hit-feedback pattern to mirror),
   `scripts/systems/round_manager.gd` and `match_manager.gd` (the signals worth hooking).

---

### 2. The minimum viable set

Ordered by how much each one adds per unit of work. **Ship them in this order** and merge after
each — a partial set that lands is worth more than a complete set that does not.

| # | Cue | Fires on | Why it earns its place |
|---|---|---|---|
| 1 | **Slipper impact on lata** | `Hitbox` resolution, host-broadcast | The single most important sound in the game. It is the win condition being met. |
| 2 | **Lata knocked down / sealed** | `CharacterBase.state_changed` → `DOWNED` / `SEALED` | The round turning. Must read on a stream (GDD §6). |
| 3 | **Slipper release** | `carrier.gd` throw | Confirms the charge released and at what power — pitch or layer it by `charge_power()`. |
| 4 | **Bump connect / blocked** | `flash_hit()` / `flash_blocked()` | Two distinct sounds. A blocked hit must never be mistaken for a landed one — that is exactly why `flash_blocked` is DEFENSE-tinted rather than white. |
| 5 | **Reset channel complete** | `carriable.gd::host_reset_upright` | The defender's payoff beat. Consider a rising tick during the channel too. |
| 6 | **Round win / match win** | `RoundManager.round_won` / `MatchManager.match_won` | |
| 7 | **Slipper lands loose** | `host_land()` | The cue that starts the retrieval scramble. |
| 8 | **Ambience, one loop per map** | map scene | Last, and only after checklist 2.2 exists. |

**Do not add hitstop.** That is checklist 4.5 and it belongs with the feel pass.

---

### 3. How to wire it — follow the existing pattern

The project already solved "a cosmetic reaction to a gameplay event that must reach every peer",
twice. Copy it rather than inventing a third shape.

- **`character_visual.gd` owns what a unit looks like; `character_base.gd` never learns about
  meshes, dents or clip names.** Audio takes the same rule: **`character_base.gd` must not learn
  what anything sounds like.** Put per-unit audio next to the visual, driven by the same signals it
  already listens to (`state_changed`, `dents_changed`).
- **Q-8/B-66 is the precedent for networked cosmetics.** The hit flash originally fired only on the
  struck character's own owning peer; `_rpc_play_hit_vfx()` was added to broadcast it to everyone.
  **Any audio cue attached to a host-resolved event needs the same treatment or three of four
  players hear nothing.** This is the single most likely bug in this workstream.
- **Use `AudioStreamPlayer3D` for anything with a position in the world** (impacts, the lata, the
  slipper) so it pans and attenuates — that is free spatial information for an FPP player with a
  narrow awareness cone. Use plain `AudioStreamPlayer` only for UI and music.
- **Add a bus layout** (`Master` → `SFX`, `Music`, `UI`) and put **master / SFX / music volume in
  `SettingsManager`** along`mouse_sensitivity` and `invert_y`, with the same persistence. A game
  that gains audio and no volume slider is a regression for anyone testing it.

---

### 4. Traps

1. **`git lfs install` before adding a single audio file.** `.gitattributes` already tracks
   `.wav/.mp3/.ogg`. A binary committed without LFS has to be rewritten out of history.
2. **`.ogg` for everything.** Godot imports `.wav` as uncompressed; a handful of ambience loops will
   bloat the repo and the export.
3. **Every asset needs a recorded licence, at the moment it lands, not at the deadline.**
   Submission **Form 03** is an asset and AI usage disclosure. Follow the existing pattern:
   `assets/characters/persons/KENNEY_LICENSE.txt` sits beside what it covers, verbatim. Prefer CC0
   (freesound.org CC0, Kenney's own audio packs) so the disclosure is one line and redistribution
   is unambiguous. **Tell the 📦 Producer lane about every asset you add** — it maintains the
   running register.
4. **Do not put audio in `character_base.gd`.** See §3.
5. **Do not add debug-only sound.** If you want an audible probe, it follows the full removal
   contract in `Dev_Plan.md` §0.3 — `debug_` prefix, one-way dependency, no `[input]` entries,
   self-disabling, removal checklist written at the same time. Simpler not to.
6. **Autoloads persist across scene changes.** If you add an audio manager autoload, give it a
   `reset()` and call it where `MatchManager.reset()` is called, or a looping cue survives into the
   menu. That was B-14's whole lesson.

---

### 5. Scope

**Yours:** `assets/audio/**`, a new audio autoload or per-unit audio nodes,
`scripts/systems/settings_manager.gd`'s volume settings, and the bus layout.

**Explicitly NOT yours:** the visual half of hit feedback (already done — Q-8); hitstop (4.5);
anything under `scenes/maps/` (Design lane — hand them the ambience stream and let them place it);
`ui_theme.gd`; the carry/throw state machine's behaviour. If a cue needs a signal that does not
exist, **ask for it in `Handoff.md` §5** rather than adding logic to a gameplay script yourself.

---

### 6. Acceptance

- All eight cues fire, in a two-instance networked session, **on every peer** — not just on the one
  whose character was involved. This is the B-66 failure mode and it is the acceptance test that
  matters most.
- Volume sliders exist, apply immediately, and persist across a restart.
- Nothing loops into the main menu after a match ends.
- Every file in `assets/audio/` has a licence file beside it, and `git lfs ls-files` lists them.
- `godot --path . scenes/main/Main.tscn --quit-after 400` produces **no output at all**.
- All six commands in `Concurrency_Protocol.md` §8 before merging.

---

### 7. Non-negotiables, restated inline

- **Authorship.** Every commit authored and committed solely as
  `M4tyu633 <matthewtlabrador@gmail.com>`. No `Co-authored-by:`, no mention of Claude, an AI
  assistant, or any tool anywhere in a commit. Verify with
  `git log -1 --format='%an <%ae> | %cn <%ce>'`.
- **Camera directive.** Person → FPP always, Prop → TPP always, derived from `is_person`. Audio
  must not assume a listener position that contradicts it — the `AudioListener3D` follows the
  active camera, whichever mode that is.
- **Architecture.** `character_base.gd` never learns what anything looks or sounds like. Host is
  authoritative for anything that decides a round; cosmetics broadcast to every peer.
- **Both round-win modes stay in active, equal development.** Option B's seal beat and Option A's
  third dent both need a sound; do not cover only one.
- **Verify before claiming `[x]`.** If you could not run it, it is `[~]` and you say what is
  unverified.
- **One concern per commit.** Do not bump `application/config/version` in a feature commit while
  two lanes are running.

### 8. Reporting contract

List every asset added with its source and licence, so Form 03 is a copy-paste and not an
excavation. Say which cues you confirmed on a second peer versus which you only heard locally. Say
plainly what you did not get to and why.



---

# Appendix — Interaction tuning (carries the FPP measuring harness)

*(was `docs/Agent_Prompts.md`)*

## Interaction Tuning Agent Brief — carry, throw, grab, reset channel

**Run this on: Sonnet 5, high effort.** High rather than medium because this touches
`carriable.gd`, `carrier.gd` and the throw profiles at the same time, and the host-authoritative
state transitions in there break subtly rather than loudly.

**Lane:** 🔧 Build. **Worktree:** `.worktrees/build`, branch `code/<task>` off `integration`.
**Checklist items owned:** **0.5** (retune from playtest notes), and the fixes that fall out of
**0.4**. Prerequisites 0.1, 0.2 and 0.3 belong to
[`Agent_Prompts.md`](Agent_Prompts.md).
**Paste-ready opener:** [`Agent_Prompts.md`](Agent_Prompts.md) → 🔧 Build lane.

---

### 0. The situation, stated plainly

The entire tumbang-preso mechanic — a Person carries a tsinelas, charges a throw, launches it on a
real ballistic arc at a guarded lata, then has to scramble out and retrieve it while the taya tries
to tag them — **is code-complete and has never been played by a human.** `Handoff.md` §0.8 says so
in its own words: *"nobody has pressed a button."*

Every number in it is a first guess made without ever seeing it move:

| Constant | Where | Current | Guessed? |
|---|---|---|---|
| `CHARGE_FULL_TIME`, `CHARGE_MIN_POWER` | `carrier.gd` | — | yes |
| `CRAWL_SPEED_SCALE` | `carriable.gd` | `0.45` | yes |
| `MAX_FLIGHT_TIME` | `carriable.gd` | `6.0` | yes |
| `THROWER_IGNORE_TIME` | `carriable.gd` | `0.25` | yes |
| `RESET_CHANNEL_TIME` | `carrier.gd` | `1.5` | yes |
| `GrabArea` radius | `CharacterBase.tscn` | `1.7` | yes |
| `arc_angle_deg`, `gravity_scale`, `launch_speed`, `steer_strength`, `spin_speed_deg` | 4 × `throw_*.tres` | — | yes, all |

**This is the highest-priority work on the project.** If the throw is wrong, most of the
environment work and all of the balance work gets redone anyway.

---

### 1. Read these first, in this order

1. **[`Checklist.md`](Checklist.md)** — Phase 0 in full. Your item is 0.5; 0.4 is the human
   playtest that produces your input.
2. **[`Concurrency_Protocol.md`](Concurrency_Protocol.md)** — an Opus design lane is working the
   same repo. §2 (path ownership), §3 (shared-file lock — `CharacterBase.tscn` is one), §8 (smoke
   gate).
3. **`Handoff.md`** §1–§2 (**frozen** — follow, do not rewrite), §0.7 (why the mechanic is shaped
   this way, and the alternatives that were rejected), §0.8 (what was and was not verified), §3
   (open bugs — **B-74, B-75, B-76** are yours), §4's `T-1`…`T-4` entries.
4. **`Dev_Plan.md`** §0 (standing directives — these override the GDD), §2 (architecture rules).
5. **`Dev_Plan.md`** Section 3's beat-by-beat loop and Section 4's throw identities.
6. **Then read the code**: `scripts/characters/carriable.gd`, `carrier.gd`, `throw_profile.gd`,
   `scripts/abilities/resources/throw_*.tres`, and `character_base.gd`'s `_physics_process`.

---

### 2. Traps already found in this code

These are load-bearing. Several were discovered the expensive way.

1. **Held state is deliberately NOT on `CharacterBase.tscn`'s `MultiplayerSynchronizer`,** even
   though that would be less code. That synchronizer replicates outward from each character's *own*
   peer, so routing held state through it would make it **client-asserted** — the exact opposite of
   the requirement. Clients call `_rpc_request_*` on the host; the host decides and broadcasts
   `_rpc_set_*` with `call_local`. **Do not "simplify" this.**

2. **The broadcasts are `"any_peer"`, not `"authority"`.** Resolution runs on the host, but a
   slipper's multiplayer authority is its own owning peer, so an `"authority"` RPC sent *by* the
   host is silently rejected. `CharacterBase._apply_hit_result` documents the same thing.

3. **`_step_carried` orthonormalises the hand transform.** A Person's model is scaled
   `PERSON_SCALE` (2.38) and every bone under its `Skeleton3D` inherits that, so copying the
   transform wholesale inflates the slipper 2.38× — with no error, just a comically large tsinelas.

4. **`HAND_CARRY_OFFSET` is in WORLD units, and is divided by `PERSON_SCALE` at the point of use**
   (`character_visual.gd::_build_hand_attachment`). It was **not**, until v4.21 — that was B-79, and
   it parked a carried slipper a metre to the character's left and above its own head. If you retune
   it, keep the division.

5. **`CharacterBase`'s origin is the CENTRE of a 1.6-unit capsule, so a model's feet are at `-0.8`,
   not `0`.** Four nodes were placed against an imagined character standing on `y = 0` and all four
   were wrong (B-78, B-79, B-80). Check this before positioning anything on a character.

6. **`get_hand_attachment()` returns null early in a match.** `CharacterVisual` instances the model
   from `CharacterBase._ready()`, so there is a real window where a Person exists and its hand does
   not. That is "not ready", never an error — `_step_carried` returns and retries next frame.

7. **The hand is a `Node3D` CHILD of the `BoneAttachment3D`, not the attachment itself.**
   `BoneAttachment3D` overwrites its own transform from the bone pose every frame, so an offset
   written onto it is silently discarded and the item sits at the elbow.

8. **`host_grab()` — not a hand-set state — is what disables the slipper's collision**
   (`_set_physics_enabled(false)` inside `_rpc_set_carried`). Setting `state = CARRIED` directly
   leaves the slipper's capsule solid inside its carrier's, and the two depenetrate and launch the
   pair into the sky. If you write a test harness, go through `host_grab`.

9. **`physics_step()` runs on EVERY peer, above `character_base.gd`'s `round_active` gate,
   deliberately** — every peer must run the carry maths and the authority gate sits below it. B-74
   is the consequence that was not thought through, and its fix (freeze `FLYING` while
   `not RoundManager.round_active`) is already in.

10. **Always `.duplicate()` an ability `.tres` per character.** Cooldown and charge state live on
    the Resource instance; two characters sharing one `.tres` share one cooldown.

---

### 3. Open bugs that are yours

- **B-76 · The three Tsinelas identities are unreachable in the running game.** `main.gd`'s
  `PROP_ABILITY` is `quick_stand.tres` for *every* Prop and `Main.tscn` hardcodes the same. Quick
  Stand has no `get_throw_profile()`, so every throw falls back to `throw_default.tres`. **The whole
  `throw_profile.gd` design is currently dead code in practice.** Checklist 0.2 is the interim fix
  (a per-side default) and it **blocks the playtest** — you cannot feel three throw identities that
  cannot be selected.
- **B-74 · [FIXED, untested]** A thrown slipper frozen mid-air by the round-end input freeze.
  Nobody has thrown one at the bell.
- **B-75 · [FIXED, untested]** Nothing dropped a carried slipper when its carrier was staggered,
  downed or sealed. `carriable.gd` now watches the carrier's `state_changed` while CARRIED. **Nobody
  has been tagged mid-carry.** This is most of the point of tagging — verify it early.

---

### 4. What "retune" actually means here

**Do not re-mark anything `[x]` because it loads without erroring.** That is precisely the failure
mode this project has repeated three times.

The input to this brief is the human's notes from checklist 0.4. For each number:

1. Change it.
2. **Run it and look at it** — `tools/render_probe.gd` renders the viewmodel and the match scene
   with a real rendering device.
3. Record the old value, the new value, and the one-line reason in the commit body. A tuning commit
   with no rationale is unreviewable and will be re-guessed by the next agent.
4. Numbers that are still guesses stay documented as guesses.

**Balance both round-win modes.** Option A (dents) and Option B (Downed → Seal) are both in active,
equal development — see `Handoff.md` §5. Do not deprioritise, skip or half-tune either on the
assumption the other will ship. The ship decision is the human's and blocks nothing.

---

### 5. Scope

#### Yours
`scripts/characters/carriable.gd`, `carrier.gd`, `throw_profile.gd`, the four
`scripts/abilities/resources/throw_*.tres`, the Tsinelas ability scripts, `character_base.gd`'s
interaction gating, and the `GrabArea` shape on `CharacterBase.tscn` (**shared file — take the lock
first**).

#### Explicitly NOT yours
- **The HUD meters** (checklist 0.1) — `Agent_Prompts.md`. You *depend* on them.
- **The tsinelas mesh and its scale** — Design lane, checklist 1.2.
- **Round-win logic.** `RoundManager` owns it. Nothing you write may put win conditions into
  `character_base.gd` or `hitbox.gd` beyond the single `GameLaunch.game_mode` branch already there.
- **Networking transport and interpolation** — `Agent_Prompts.md`.
- **Anything under `assets/` or `scenes/maps/`.**

---

### 6. Acceptance

- A human has played a full Bo5 in **both** game modes and the numbers reflect their notes.
- Tagging a carrier mid-carry makes them drop the slipper (B-75), confirmed by someone doing it.
- A slipper thrown at the bell behaves sanely (B-74), confirmed by someone doing it.
- All three Tsinelas throw profiles are reachable and feel distinct (B-76 / checklist 0.2).
- The reset channel completes, cancels on interrupt, refuses on the wrong team, and refuses with
  full hands.
- `godot --path . scenes/main/Main.tscn --quit-after 400` produces **no output at all**.
- All six commands in `Concurrency_Protocol.md` §8 before merging.

---

### 7. Non-negotiables, restated inline

- **Authorship.** Every commit is authored and committed solely as
  `M4tyu633 <matthewtlabrador@gmail.com>`. No `Co-authored-by:`, no mention of Claude, an AI
  assistant, or any tool anywhere in a commit. Verify:
  ```bash
  git log -1 --format='%an <%ae> | %cn <%ce>'
  ```
- **Camera directive.** Person → FPP always, Prop → TPP always, derived from `is_person`, no
  toggles. The enforcement grep must return nothing:
  ```bash
  grep -rn "_mode = \|Mode\.FPP\|Mode\.TPP" scripts/ | grep -v camera_rig.gd
  ```
- **Architecture.** One `CharacterBase` scene, abilities as `.tres` Resources. Round-win logic out
  of `character_base.gd` and `hitbox.gd`. The host is authoritative for anything that decides a
  round.
- **Debug code** follows `Dev_Plan.md` §0.3's removal contract without exception: `debug_`/`Debug`
  prefix, one-way dependency (gameplay never references debug, not even behind
  `OS.is_debug_build()`), no `[input]` map entries, self-disabling in release, and a removal
  checklist written at the same time as the feature.
- **Verify before claiming `[x]`.** A `--quit` smoke test never executes a frame of `_process()`;
  that is how B-77 survived in `main.gd` for weeks, throwing on every single launch.
- **One concern per commit**, checklist item and B-number in the subject. Do not bump
  `application/config/version` in a feature commit while two lanes are running.

### 8. Reporting contract

Say what you changed and why, with old and new values for every number. Separate what a human
confirmed by feel from what you confirmed by running from what is only reasoned about. File any new
defect as the next free `B-` number in `Handoff.md` §3 with an exact reproduction. Say plainly what
you did not get to — silently narrowing scope is against this project's stated norms. If a task
turns out to be already done, say so and move on rather than rewriting working code.



---

# Appendix — Submission

*(was `docs/Agent_Prompts.md`)*

## Submission Agent Brief — trailer, demo video, synopsis, forms

**Split by design, because this workstream needs two different hats:**

| Part | Run on | Checklist |
|---|---|---|
| **Creative direction** — what to show, in what order, in how long | **Opus 5, high effort** | **6.2** |
| **Capture, edit, drafting, bookkeeping** | **Sonnet 5, medium effort** | 6.3, 6.4, 6.5, 6.8 |
| **Signing and uploading** | 🧑 **human only** | 6.6, 6.7, 6.9 |

**Lane:** 📦 Producer for the drafting and bookkeeping (docs-only, safe to run alongside
everything); 🎨 Design for 6.2's direction. **Paste-ready openers:**
[`Agent_Prompts.md`](Agent_Prompts.md).

---

### 0. The framing that matters

This is a submission to a **judged** challenge, not an open-ended project. A technically complete
but unmemorable or unreliable demo loses to a tighter, better-presented one.

**A judge who never plays the build sees only the trailer and the demo video.** Those two artefacts
carry the entire submission for most of the people scoring it. They need their own pass — not a
phone recording of a debug session with the `DebugBar` visible along the bottom.

`Dev_Plan.md` §6 and GDD §9 both treat this as real scope. Budget it like a feature.

---

### 1. Read these first

1. **[`Checklist.md`](Checklist.md)** — Phase 6 in full, and the "If time runs short" cut list at
   the bottom.
2. **`Dev_Plan.md`** §9 (the submission checklist), §10 (settled theme decisions), §1
   (the pitch, in the team's own words), §6 (the esports/spectator layer).
3. **`Dev_Plan.md`** §5 Phase 6, §6 (the fallback trigger).
4. **`Handoff.md`** §0.10 for what is actually built right now, so the trailer does not promise
   something that is not in the build.
5. **[`Concurrency_Protocol.md`](Concurrency_Protocol.md)** if any other lane is running.

---

### 2. 6.2 — the demo script and trailer beat sheet · **Opus, high**

⛔ **Blocked on checklist 2.2.** There is no point scripting shots of a grey box.

This is the Opus item, and the reason is that it is editorial judgement under a hard constraint:
**what do you show, in what order, in ninety seconds, to people who will never play it?**

Produce two artefacts:

- **A live-demo script.** What gets shown, in what order, in how many minutes, **and what the
  fallback is if a peer drops mid-demo.** Rehearse it. Demo-day reliability is a feature — a crash
  or a desync in front of judges costs more than a missing map, and this is the document that keeps
  a bad moment from becoming a bad impression.
- **A trailer beat sheet** the Sonnet lane can shoot against: shot list, order, rough durations,
  what each shot has to communicate, and the one image the whole thing has to land.

**What the game is actually about, and what the trailer has to sell:** a can standing in a circle,
a slipper thrown at it, and the scramble to get the slipper back before you are tagged. Not
"3D arena brawler". The retrieval scramble is the tension of the street game and it is what makes
this entry different from every other arena game in the competition.

---

### 3. 6.3 / 6.4 — capture and edit · **Sonnet, medium**

⛔ Blocked on 6.2, and on 2.2 (a real map) and 4.1 (audio).

- **Trailer: 1–2 min, loopable.** Shoot 6.2's shot list.
- **Demo video: 3–5 min, narrated or captioned, `.mp4`.** A walkthrough against the same script.
- **`tools/arena_camera.gd` was deliberately preserved for exactly this.** It is ~100 lines of
  working follow/framing maths, moved out of the gameplay tree at A-2 rather than deleted,
  precisely so the trailer would have a broadcast camera. If you re-instance it, its header states
  the conditions: register targets at **runtime**, never cache `NodePath`s in `_ready()`,
  `is_instance_valid()`-check every frame, default to `current = false`, and ignore any target
  below the kill plane. Ignoring those is what caused **B-03**, the original LAN freeze.
- **Strip the debug surface first.** Checklist 5.3 removes Local Match and the `DebugBar`. A
  trailer with a debug readout along the bottom edge reads as unfinished no matter what is above
  it. If 5.3 has not landed, at minimum shoot from a release build.

---

### 4. 6.5 — the synopsis · **Sonnet (📦 Producer), medium**

Template 01, **500 words maximum**. Two decisions are already made — do not reopen them:

- **Title: TUMBANG PRESO.** The moodboard's lockup. B-27 is closed and the old
  "Tumbang Laro: Isang Laban" is gone from every tracked file.
- **Primary theme: Philippine Games and Sports. Secondary: Circular Economy — take it.** GDD §10
  settled this. The premise is *literally* about reusing everyday objects — a discarded tin can and
  a rubber slipper — as sports equipment. It costs two sentences, needs no build work, and it is a
  scoring lever the rubric offers for free. **Say it explicitly rather than hoping a judge
  infers it.**

Lead with the street game, not the engine. The people scoring this grew up playing tumbang preso.

---

### 5. 6.8 — the Form 03 licence register · **Sonnet (📦 Producer), medium**

**Keep this as a running list from now, not an excavation at the deadline.** Form 03 is an Asset
and AI Usage Disclosure and it needs every third-party asset in the build.

Known already:

| Asset | Source | Licence | Where |
|---|---|---|---|
| Kenney *Mini Characters* (12 `.glb`) | Kenney | **CC0** | `assets/characters/persons/KENNEY_LICENSE.txt` |
| Display + body typefaces | ⛔ checklist 1.1 / 3.1 | **undecided** | must land at `assets/ui/fonts/` with a verbatim licence |
| All audio | ⛔ checklist 4.1 | not yet sourced | prefer CC0 so disclosure is one line |
| Moodboard-derived art | Harry's Canva project | needs a stated position | ask |
| **AI usage** | — | — | **required, and this project used AI agents extensively** |

Note the pattern the repo already uses: the licence file sits **beside** what it covers, verbatim,
named `<SOURCE>_LICENSE.txt`. Follow it. Chase the other lanes as they add assets rather than
reconstructing later.

---

### 6. 6.6 / 6.7 / 6.9 — 🧑 human only

- **Form 01 — Game Development Team Roles.** This form **is** the ownership table in
  `Dev_Plan.md` §6, which is still blank after five passes of asking. It is now a submission
  blocker rather than hygiene. **Chase it; do not fill it in on anyone's behalf.**
- **Form 02 — Waiver and Declaration of Originality, signed by all members.** A model does not sign
  a declaration of originality. Prepare it to the point of signature and stop.
- **6.9 — upload through the official submission link.** Human.

**Prepare these; do not submit them.** They stay marked 🧑 on the checklist for a reason.

---

### 7. Traps

1. **Do not promise what is not in the build.** Check `Checklist.md` before scripting a shot. As of
   the last audit there is one map in progress, no character select, and both round-win modes live.
2. **Shoot a release build, not the editor.** ⛔ Checklist 5.1 — Godot export templates are not
   installed on the machines tried so far, so no `.exe` has ever been produced. That is a human
   task and it blocks a clean capture.
3. **Both round-win modes are still live.** The trailer should show *one* clearly rather than
   cutting between two rule sets — that reads as indecision. Which one leads is checklist 1.5, the
   human's call; ask rather than picking by default.
4. **The nameplate tags fade past 12–18 m** and the `DebugBar` is present in debug builds. Both
   affect framing. Screenshot before you commit to a shot.
5. **Authorship applies to your commits too** — see §8.

---

### 8. Non-negotiables, restated inline

- **Authorship.** Every commit authored and committed solely as
  `M4tyu633 <matthewtlabrador@gmail.com>`. No `Co-authored-by:` trailer, no mention of Claude, an
  AI assistant, or any tool as author or committer anywhere in a commit. Verify with
  `git log -1 --format='%an <%ae> | %cn <%ce>'`. **Note this is about commit metadata and is
  entirely separate from Form 03, which requires AI usage to be disclosed honestly — disclose it.**
- **Verify before claiming `[x]`.** An unshot video is `[ ]`. A shot but unedited one is `[~]`.
- **One concern per commit**, checklist item in the subject.
- **📦 Producer writes only to `docs/`.** No code, no scenes, no assets.

### 9. Reporting contract

Say what is drafted, what is captured, what is edited, and what is waiting on a human signature or
decision. Keep the licence register current in the same commit as any asset change you learn about.
Say plainly what you did not get to and why.

