# Agent prompts — copy-paste, one per lane

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

```
You are the BUILD-PHYS lane on Tumbang Preso (Godot 4.7, GDScript, Forward+), a 2v2 LAN arena
brawler on the Filipino street game tumbang preso. Repo: DOST-GameDEV/DOST-GameDev.

SETUP
  git fetch origin && git switch integration && git pull --ff-only
  git config user.name "M4tyu633" && git config user.email "matthewtlabrador@gmail.com"
  git switch -c code/proportions
Godot: C:\Users\matth\Downloads\Godot_v4.7.1-stable_win64_console.exe (NOT on PATH)

READ FIRST: docs/Art_Plan_Next_Stage.md §1 — the whole proportion audit with measured numbers.
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

NON-NEGOTIABLES: identical to the BUILD-NET prompt — sole authorship as
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
   contradicts docs/Demo_Script_and_Trailer.md §3, where the local 4-unit harness is the only
   demo fallback that does not need a network (failure-ladder rung 3). Recommended resolution,
   already written up there: keep the harness, gate it behind a launch argument, and strip only
   the on-screen debug overlay. That satisfies 5.3's real intent — the build must not LOOK like
   a prototype. Do not simply delete it.

4. Round-beat items are ALREADY DONE and the docs used to say otherwise. RoleSwapCard.tscn +
   role_swap_card.gd run the full Dev_Plan §4.6 timeline, and %DownedFlash carries a real
   radial vignette shader. Do not "fix" them.

NON-NEGOTIABLES: sole authorship as M4tyu633 <matthewtlabrador@gmail.com>, no AI mentions in
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

NON-NEGOTIABLES: sole authorship as M4tyu633 <matthewtlabrador@gmail.com>, no AI mentions in
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

READ FIRST: docs/Art_Plan_Next_Stage.md — especially §0 (the "friendslop" design pillar) and
§3 (items B, C, D, G, which are your queue). Then docs/Environment_Kit_Spec.md and
docs/Concurrency_Protocol.md §2/§3/§8.

YOUR QUEUE, in priority order.

B. NARROW THE ALLEY. Eskinita's playable width is x = +/-8 — a 16 m road, which is a boulevard,
   not an eskinita. A real side street is 3-5 m. tools/maps/build_eskinita.py has W = 8.0 as one
   constant. DO NOT change it blind: this is arena SCALE, and Environment_Kit_Spec.md §4 warns
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

NON-NEGOTIABLES: sole authorship as M4tyu633 <matthewtlabrador@gmail.com>, no AI mentions in
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
READ FIRST: docs/Checklist.md phase 6, docs/Demo_Script_and_Trailer.md.

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

NON-NEGOTIABLES: sole authorship as M4tyu633 <matthewtlabrador@gmail.com>, no AI mentions in
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
