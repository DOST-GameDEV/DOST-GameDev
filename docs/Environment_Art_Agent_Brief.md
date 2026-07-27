# Environment Art Agent Brief — the maps

**Run this on: Opus 5, high effort — this is a design-judgement task, not a code task.**
The hard question here is *"does this read as a Philippine side street"*, not *"does this scene
load"*. It is the single biggest visual lever on the submission and one of only four items on the
whole remaining plan routed to Opus.

**Lane:** 🎨 Design. **Worktree:** `.worktrees/design`, branch `art/<task>` off `integration`.
**Checklist items owned:** **2.1a** (environment kit art direction), **2.2** (Eskinita).
**Paste-ready opener:** [`Agent_Prompts.md`](Agent_Prompts.md) → 🎨 Design lane.

---

## 0. The one-paragraph reason this matters most

The systems on this project are in good shape. What a judge actually sees today is **one 40×40 grey
box**. Not a stylised arena — a literal untextured slab with a beige `BoxMesh` floor, four
**invisible** collision walls, no sky, no props, no markings, and a hazard zone that is a
translucent pink cylinder sitting at (5, 0.5, 5) for no reason the map motivates. Everything else
on the checklist improves a game that still looks like a prototype. This item is what stops it
looking like one.

---

## 1. Read these first, in this order

1. **[`Checklist.md`](Checklist.md)** — the single source of truth for state and order. Your items
   are 2.1a and 2.2.
2. **[`Concurrency_Protocol.md`](Concurrency_Protocol.md)** — a Sonnet build lane is working the
   same repo concurrently. §2 (path ownership), §3 (the shared-file lock), §6 (`.tscn` conflicts),
   §7 (the `.import` UID trap), §8 (the smoke gate).
3. **`Handoff.md`** §0.10 (the last audit — what is actually true right now), §1–§2 (frozen), §4's
   `M-6`/`M-7` entries (the existing plan for this work — audit it, don't assume it).
4. **`Dev_Plan.md`** §0 (standing directives, which override the GDD), §4.1 (what the moodboard
   actually specifies), §4.2 (design tokens), §4.6 (round flow).
5. **`Design_Agent_Brief.md`** — the `M-` block's brief. It carries the moodboard record and the
   mesh-generator traps you will hit.
6. **Then open the scenes and the generator.** `scenes/main/Main.tscn`,
   `tools/models/generate_all.gd`, `tools/models/obj_writer.gd`. This repo has a documented history
   of docs claiming things the code contradicts in both directions — the last audit found four.
   Verify; do not inherit.

**The moodboard is the spec and it is not in the repo.** It is Harry's Canva board. **If it has not
been attached to your chat, stop and ask for it** — a description of the board is not the board.

---

## 2. What the moodboard actually asks for

| Map | Setting | Boundary | Skybox |
|---|---|---|---|
| **1 · Province** | Grass field, sand/dirt apron | **Trees ringing the whole map** | Blue sky, cumulus clouds |
| **2 · Metro** | Grey urban block, road with lane markings, sari-sari cart, plastic monobloc chairs, bins | **Buildings ringing the map** | Hazy city skyline |
| **3 · Barong Barong** | Informal settlement — corrugated sheet, stacked shanties, tangled wire | **Sampay (laundry lines), puspins, aspins, clutter** | Purple/orange sunset |

The board's own annotation on the Metro map is the whole instruction for the boundary:

> *"basically just add random assets on the edge that acts like a wall"*

Note the GDD names the two locked maps **Eskinita** (urban side street, sari-sari backdrop, jeepney
lane hazard) and **Bayan Plaza** (barangay plaza, fiesta banners, mud patches, wandering carabao).
Those map cleanly onto the board's Metro and Province references respectively — **reconcile the
naming explicitly in your first commit** rather than leaving two vocabularies running. Barong
Barong is the board's third reference and is not in the GDD; treat it as the Palengke-tier stretch
unless you argue otherwise in writing.

---

## 3. The boundary — the item most likely to be got wrong

**Correction to a claim you will hear repeated: the current build does not have brown box walls.**
It has four `StaticBody3D` + `CollisionShape3D` nodes under `Bounds` in `Main.tscn` with **no
`MeshInstance3D` at all**. They are invisible. The arena edge renders as the floor meeting the sky.

That is worse than a visible wall, not better, and the fix is the same one the board specifies:

- **Never a bare coloured box.** Not brown, not grey, not textured. A flat wall plane reads as a
  test arena at any distance.
- **Collide on the dressing itself where the dressing is solid** (a building facade, a wall of
  corrugated sheet), **or hide an invisible collider just behind visible geometry** where the
  dressing is open (a tree line, a laundry line). Either is fine; a visible gap a player can walk
  into and get stuck on is not.
- **Depth, not a line.** The board rings its maps with *layers* of objects — trees behind trees,
  buildings behind buildings. A single row of props at the boundary still reads as a fence.
- **Keep the playable area at roughly 40×40.** Do **not** change arena scale in the same commit as
  arena art, or the next movement-feel regression is unattributable to either.

---

## 4. Traps already found in this code — read before you start

1. **`CharacterBase`'s origin is the CENTRE of a 1.6-unit capsule, so a model's feet are at
   `-0.8`, not `0`.** Four separate nodes were placed against an imagined character standing on
   `y = 0` and all four were wrong: the FPP camera pivot (B-78), the ground ring (B-80), the
   floating tag, and the hand carry point (B-79). **If you place anything relative to a character,
   check this first.** For map geometry the equivalent question is the floor: `Main.tscn`'s `Floor`
   is a `BoxShape3D` of `(40, 1, 40)` centred at the origin, so its **top surface is `y = 0`** and
   the box extends to `-1`.

2. **`HazardZone` must not join the `hazard_zone` group.** `main.gd::_reset_world()` frees every
   member of that group every round. The permanent map hazard is placed as a scene node with
   `collision_layer = 0`, `collision_mask = 2`, `lifetime = 0.0`, and stays out of the group. This
   is Q-7's note and it is easy to undo by accident.

3. **The `.obj` generator's winding was measured, not assumed.** Godot uses *clockwise* front faces
   and its `.obj` importer flips index order, so every face reads as inverted under the familiar
   counter-clockwise test — Godot's own `CylinderMesh` reports identically. `obj_writer.gd`'s
   header carries the warning. **Do not "fix" it by eye.**

4. **Determinism is an acceptance criterion, not a nicety.** `generate_all.gd` must produce
   byte-identical output on two consecutive runs and leave `git status` clean after the second. No
   `randf()`, no iteration over unordered keys, fixed float precision. If a "random" scatter of
   boundary props is wanted, seed it explicitly and deterministically.

5. **`_align_to_capsule_floor()` measures the AABB at runtime**, so a new mesh drops in correctly —
   but it is the one thing standing between a new model and a prop hovering 20cm off the ground.
   Re-verify it whenever you change a mesh's bounds.

6. **No outlines on environment geometry.** `M-4`'s inverted-hull outline pass is for characters and
   hero props only. An outlined street is visual noise and doubles the draw calls on the largest
   meshes in the scene.

7. **`Main.tscn` ships a flat `background_color`, not a sky.** `Environment_default` has
   `background_mode = 1` (colour) with `ambient_light_energy = 0.75`. There is no `Sky` resource
   anywhere in the project. Per-map skyboxes are new work, not a rewire — and **verify each one is
   actually attached to its own map** rather than left on the default.

---

## 5. Scope

### Yours

- **2.1a** — the environment kit's art direction: which pieces, what silhouette, what proportion,
  what palette, what reads as an *eskinita* rather than as generic low-poly. Write it as a
  specification precise enough that the Sonnet lane can generate it without asking you anything.
  Suggested Eskinita set (audit it, don't just accept it): `road_tile`, `gutter_tile`, `wall_plain`,
  `wall_corrugated` (the GI-sheet fence — the single most Filipino-reading piece in the set),
  `sari_sari_store` front with a barred window, `post_electric` with a drooping wire, `laundry_line`,
  `tricycle` (~300 tris, silhouette-grade), `bollard`, `crate_stack`, `tire`. ≤400 tris each,
  authored on a **2-unit grid** so a `MeshLibrary` + `GridMap` can assemble a map instead of
  hand-placing two hundred nodes.
- **2.2** — `scenes/maps/Eskinita.tscn`: layout, the dressed boundary, field markings, the hazard's
  placement and motivation, the skybox, and a `SpawnPoints` node holding four `Marker3D`s.
- The **prop-scale decision (1.2)** if it has not already been made — see §7.

### Explicitly NOT yours

- **The generator code** (`obj_writer.gd`, and the plumbing of `generate_all.gd`). You specify the
  shapes; checklist 2.1b implements them on the Sonnet lane. If you find yourself debugging
  `.obj` output, hand it over.
- **`main.gd`'s spawn-point reading logic.** You add the `SpawnPoints` node and the markers; the
  Build lane makes `main.gd` prefer them over its hardcoded `SPAWN_POINTS` array.
- **`HazardZone`'s behaviour.** You place it and motivate it in the fiction; its slow-zone logic is
  Build's.
- **Anything under `scripts/` except `ui_theme.gd`.**
- **The HUD.** `scenes/ui/HUD.tscn` is a shared file with its own lock and its own brief.

---

## 6. Acceptance

- A full Local Bo5 in Eskinita. **Nobody falls through geometry, nobody gets stuck on a prop, all
  four spawn markers are used, the base circle is visible, and an FPP Person can see over the props
  well enough to aim.**
- **The boundary contains play and is never a bare box.** Walk into it from four directions and
  screenshot each.
- Frame rate holds. A `GridMap` of 400-tri pieces is cheap; check anyway.
- `godot --headless -s tools/models/generate_all.gd` twice, `git status` clean after the second.
- **Screenshots.** Not optional for this lane:
  ```bash
  godot --path . tools/render_probe.tscn --quit-after 400 --resolution 1280x720 -- match /tmp/
  ```
  Run it **without** `--headless` — headless has no rendering device and every capture comes back
  blank. A design-lane claim with no picture is not evidence; the last audit found four live bugs
  this way that every headless check had passed.
- All six commands in `Concurrency_Protocol.md` §8 before merging.

---

## 7. The decision you may need to make first

**Checklist 1.2 — prop scale.** Measured in-engine on 2026-07-27:

| | Height / length | As a fraction of a 1.598-unit Person |
|---|---|---|
| Lata (can) | 1.125 | **70%** |
| Tsinelas (slipper) | 1.35 long | **84%** |

Rendered, a Person carrying the slipper reads closer to carrying a surfboard. But both are
player-controlled units inside a 1.6-unit capsule, so this is a genuine fork rather than a bug:

- **(a)** Keep props hero-scaled and shrink the tsinelas *only while carried*. **Recommended** — it
  is contained, it protects the movement numbers that will have just been playtested, and the
  moodboard's role cards draw the can and slipper as hero objects.
- **(b)** Scale the props toward plausible size and retune capsules, hitboxes, camera distance and
  movement feel with them. Honest, and much more expensive.

**Decide this before 2.1a**, because the kit's 2-unit grid is sized against these props. Write the
reasoning down the way `Handoff.md` §0.7 did — diagnosis, alternatives rejected, what changes, what
stays — and supersede rather than silently overwrite.

---

## 8. Non-negotiables, restated inline

A fresh agent has not read the conversation that produced this brief.

- **Authorship.** Every commit is authored and committed solely as
  `M4tyu633 <matthewtlabrador@gmail.com>`. No `Co-authored-by:` trailer, no mention of Claude, an AI
  assistant, or any tool as author or committer anywhere in a commit. Verify after your first commit:
  ```bash
  git log -1 --format='%an <%ae> | %cn <%ce>'
  ```
  Both sides must read `M4tyu633 <matthewtlabrador@gmail.com>`.
- **Camera directive.** Person → FPP always, Prop → TPP always, derived from `is_person`. No
  toggles, no per-map exceptions. **Do not add a camera to a map scene** — that is the violation
  A-2 was written to delete, and it caused B-03.
- **Orange = OFFENSE, blue = DEFENCE, project-wide**, and the accent tracks **role**, never team.
  Team identity is the A/B letter mark, never hue. Never reuse either colour for anything else —
  which in practice means **environment art may not use `#F87020` or `#0080E8`.**
- **Every mesh is reproducible.** No hand-edited binaries. Either a primitive composite in a `.tscn`
  or an `.obj` emitted by the committed generator.
- **`.obj`/`.mtl` stay text and out of LFS.** That is the entire reason the format was chosen.
- **One concern per commit**, checklist item number in the subject. Do not bump
  `application/config/version` in a feature commit while two lanes are running — the merge does.
- **Verify before claiming `[x]`.** If you could not run it, it is `[~]` and you say exactly what is
  unverified.

## 9. Reporting contract

Say what you changed and why. **Screenshot everything visual.** Separate what you verified by
running from what is only reasoned about. Say plainly what you did not get to and why — this
project has an established, enforced norm against silently narrowing scope. If something in these
docs is wrong, say it is wrong instead of building around it; the last three passes each found
stale claims, and saying so is more valuable than working around them.
