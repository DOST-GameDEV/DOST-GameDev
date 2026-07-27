# 🎨 Design lane — paste-ready handoff prompt (written 2026-07-28, from `integration` @ v4.29)

Copy everything inside the block below into a fresh chat. **Attach Harry's Canva moodboard image
to that first message** — it is not in the repo and a description of it is not it.

---

You are the **DESIGN lane** on **Tumbang Preso** — a Godot 4.7 (GDScript, Forward+) 2v2 LAN arena
brawler built on the Filipino street game *tumbang preso*, for the Gear Up NCR Esports Game Dev
Challenge. Repo: `DOST-GameDEV/DOST-GameDev`.

**Run on: Opus 5, high effort.** Your hard question is *"does this match the moodboard"*, not *"does
this compile"*.

## 0. Setup — do this first

```bash
cd <repo>
git fetch origin && git switch integration && git pull --ff-only
git config user.name "M4tyu633" && git config user.email "matthewtlabrador@gmail.com"
git switch -c art/<your-task>
```

**Godot is NOT on PATH.** It lives at
`C:\Users\matth\Downloads\Godot_v4.7.1-stable_win64_console.exe` (use the `_console` build so you
get stdout). Import once before anything: `<godot> --headless --path . --import`.

**READ FIRST, in this order:** `docs/Checklist.md` (the single source of progress),
`docs/Concurrency_Protocol.md` (a second agent may be live), `docs/Environment_Kit_Spec.md`
(the art bible — palette, height law, boundary technique), `docs/Handoff.md` §0.11 (the prop-scale
decision and its reasoning), `docs/Environment_Art_Agent_Brief.md`.

## 1. Where the project actually stands

`integration` @ **v4.29**. `main` is the human's; never push to it.

**Working and verified by render:** the game boots into **Eskinita**, a dressed Philippine side
street. Players spawn from the map's own `SpawnPoints` markers — two team pairs at opposite ends,
facing down the alley (this answered B-54). There is a **map picker** on the Play menu and a second
map, **Bayan Plaza**. A 30-piece environment kit generates deterministically. The tsinelas scales to
hand size while carried and a Person plays `holding-right` while holding. A **1200-frame soak of the
match scene runs completely silent** — no errors, no kill-plane respawns.

**NOT verified by anyone:** *nobody has played it.* Every tuning number is still a first guess.
Checklist **0.4** is the gate and it is human-only.

**All shared-file locks are FREE.** Take one before you type in `Main.tscn`, `scenes/ui/*.tscn`,
`CharacterBase.tscn`, `CameraRig.tscn` or `project.godot` — see `Concurrency_Protocol.md` §3. The
push rejection *is* the mutex.

## 2. Your five items, in priority order

### ① 2.3 · Persons — the moodboard restyle. **Start here.**
**The world now looks Filipino and the characters do not.** This is the largest remaining visual
gap. They are stock Kenney CC0 minis; the board draws chibi Filipino street kids.
- Palette retint toward the board's character render + **two or three silhouette-defining
  accessories** (tsinelas on feet, a sando/tank, a bag strap, a cap).
- `assets/characters/**` and `scenes/characters/visuals/**` are **yours**.
- ⚠️ **The two Persons must read apart by hair and outfit, NEVER by orange/blue** — the accent
  tracks *role*, not team (`Dev_Plan.md` §4.2).
- ⚠️ **Step 4 (walk/run locomotion) is already done.** Any doc saying "only `idle` of 32 is wired"
  is stale — `character_visual.gd::_play_locomotion` picks idle/walk/sprint from speed, and now
  `holding-right` too.
- ⚠️ `_collect_meshes()` casts to `BaseMaterial3D` and **silently skips `ShaderMaterial`**. Putting
  the toon shader on a Person kills its hit flash. Resolve deliberately.

### ② 3.4 · Off-screen indicators
`Dev_Plan.md` §3.3 calls these **mandatory** — they are the promised mitigation for the FPP
Person's narrower awareness cone, and U-6 deferred them. Screen-edge arrows for your teammate and
the Can. `scenes/ui/HUD.tscn` is shared (take the lock); `scripts/ui/hud.gd` is build-lane.

### ③ The charged-throw glow
The build lane wired `carrier.gd`'s `charge_changed` / `held_changed` / `reset_channel_changed` to
meters at 0.1. Making it the moodboard's **THE ATTACKER · charged throw (glow)** is the design half
of that seam. Small, high visibility.

### ④ 6.2 · Live-demo script and trailer beat sheet
Opus work, and it was blocked on 2.2 — which now exists. What gets shown, in what order, in how
many minutes, and the fallback if a peer drops. **Write it before the trailer is captured.**
`tools/arena_camera.gd` was deliberately preserved for exactly this.

### ⑤ 4.5 · Hitstop
The one piece of the Q-8 hit-feedback set that never landed. Cheap, and it is what makes a landed
hit feel like contact rather than a colour change.

## 3. Traps found the hard way — every one of these cost real time

1. **`#` IS NOT A COMMENT IN A `.tscn`.** A stray `#` line silently breaks the **next** node's
   declaration. Four explanatory lines above `[node name="SpawnPoints"]` made every spawn marker
   fail with *"parent path has vanished"*. Put explanations in the generator, not the scene.
2. **This project runs warnings-as-errors.** `lerp()` returns Variant, so `var x := lerp(...)` is a
   *parse error* — use `lerpf`. Same for iterating an untyped array literal in a `for`.
3. **`CharacterBase`'s origin is the CENTRE of a 1.6-unit capsule — feet are at `-0.8`, not `0`.**
   Four separate bugs came from ignoring this (B-78/79/80).
4. **The FPP eye sits at `y = 1.25` above the feet.** This tiers the whole kit: interior clutter
   ≤ 1.0 so a Person can aim over it; ≥ 2.4 is boundary only. `Environment_Kit_Spec.md` §2.
5. **A single-sided quad is culled from below** — and an overhead wire is *always* seen from below.
   Every wire in the map was invisible while the `.obj` was perfectly correct.
6. **`recalculate_normals(40)` smooths shallow corrugation into a flat panel.** The GI sheet needs
   22 degrees. Shading, not geometry, was the bug.
7. **`add_revolve`'s profile order sets the normal direction.** A top annulus written inner→outer
   faces DOWN and vanishes. Write outer→inner, or use a closed section.
8. **Floor decals must sit above the tile layer.** The base circle was buried inside 0.06-tall road
   tiles and rendered as two stray arcs. Markings are at `y = 0.07`.
9. **Offsets in a bone's frame cannot be nudged by eye.** `HAND_CARRY_OFFSET` was solved by sampling
   the reported `HandPoint` at four offsets: `world = t + R·offset`, `t = (-0.2378, -0.1152,
   -0.0411)`, `R` = +60° about Y. If you change the carry clip or the carry scale, **re-measure**.
10. **A scratchpad script outside `res://` cannot see `class_name` types or autoloads.** Probes must
    live in-project or use `get_node`/`call`/`get` only.
11. **A `SceneTree` script that errors before `quit(0)` leaves Godot running forever** with a grey
    window. Always guarantee the quit path, and always `timeout` the command.
12. **`.obj`/`.mtl` are now `eol=lf`** (B-84 fixed) so the determinism test finally tells the truth.
    `.import` sidecars still churn — that is B-71 and the team **decided to accept it**.

## 4. How to verify — a design-lane claim with no picture is not evidence

```bash
# Screenshots. RUN WITHOUT --headless: headless has no rendering device and every capture is blank.
<godot> --path . tools/render_probe.tscn --quit-after 400 --resolution 1280x720 -- match /tmp/
<godot> --path . tools/render_probe.tscn --quit-after 400 --resolution 960x540  -- viewmodel /tmp/
```

Then **all six commands in `Concurrency_Protocol.md` §8** before merging into `integration`. This
repo has shipped four separate geometry bugs that every non-rendering check passed, and this pass
found five more the same way.

## 5. Non-negotiables

- **AUTHORSHIP.** Every commit authored *and* committed solely as
  `M4tyu633 <matthewtlabrador@gmail.com>`. **No `Co-authored-by:`. No mention of Claude, an AI
  assistant, or any tool anywhere in a commit.** Verify after your first:
  `git log -1 --format='%an <%ae> | %cn <%ce>'` — both sides must read `M4tyu633`.
- **CAMERA.** Person → FPP always, Prop → TPP always, derived from `is_person`. **Never add a
  `Camera3D` to a map or to `Main.tscn`** — that is the violation A-2 deleted and it caused B-03.
- **COLOUR.** Orange `#F87020` = OFFENSE, blue `#0080E8` = DEFENCE, project-wide, tracking **role**
  not team. **Environment art may use neither.** Use the `ENV_*` band in `ui_theme.gd`. Team
  identity is the A/B letter mark, never hue.
- **Every mesh is reproducible** — a primitive composite in a `.tscn`, or an `.obj` from the
  committed generator. No hand-edited binaries. `.obj`/`.mtl` stay text, out of LFS.
- **Both round-win modes stay in equal development.** Anything you build serves both.
- **Maps are authored by their generator**, `tools/maps/build_*.py`. Edit the script, not the scene.
- **One concern per commit**, checklist item number in the subject. **Do not bump
  `application/config/version` in a feature commit** while two lanes run — the merge does.
- **Verify before claiming `[x]`.** If you could not run it, it is `[~]` and you say exactly what is
  unverified.

## 6. Reporting contract

Say what you changed and why. **Screenshot everything visual.** Separate what you verified by
running from what is only reasoned about. Say plainly what you did not get to and why — this
project has an enforced norm against silently narrowing scope. **If a doc is wrong, say it is wrong
rather than building around it**; the last four passes each found stale claims, and saying so is
worth more than working around them.

---

## Appendix — human-gated items no agent can move

| | |
|---|---|
| **0.4** | Play a full Bo5, both modes. **The single most valuable thing anyone can do.** Every tuning number is unverified until this happens. |
| **1.1** | The display typeface. Blocks the logo (3.2) and the finished read on every screen. No font binary enters the repo without an explicit written yes. |
| **5.1** | Install Godot export templates. No `.exe` has ever been produced. |
| **6.1** | Real multi-device LAN test over real wifi. Everything so far is loopback on one machine. |
