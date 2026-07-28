# Art Direction — the single art and design document


**This file replaces four separate documents** — `Art_Direction.md`,
`Art_Direction.md`, `Art_Direction.md` and `Art_Direction.md` — which
were merged on 2026-07-28 because nobody could tell which one was current. Anything that pointed
at those now points here.

**Read Part 1 first. It is the only part that is a live plan.** Parts 2-4 are reference and
history: the moodboard record, the palette, the modelling rules and the kit spec are all still
authoritative, but their *task lists* are stale — several items in them have shipped. Where a
task list in Parts 2-4 disagrees with `Checklist.md`, the checklist wins.

## Contents

| Part | What it is | Still live? |
|---|---|---|
| **1** | Design pillar, proportion audit, current queue, playtest findings | **Yes — this is the plan** |
| **2** | Moodboard record, `UiTheme` palette, modelling approach, generator traps | Reference — yes. Task list — no |
| **3** | Environment kit spec: piece list, height tiers, boundary technique, `ENV_*` band | Reference — yes |
| **4** | Original map art-direction brief | History only |

---


<a id="part-1"></a>

# Part 1 — Current plan, pillar and proportion audit

*(was `docs/Art_Direction.md`)*

## Art plan — next stage (proportions, sets, props)

**🎨 Design lane. Written 2026-07-28 after the render pass that landed the painted facades,
the lighting rework and the rebuilt tsinelas.**

Everything below is measured, not estimated. The measurements come from the `.obj` vertex buffers
themselves, so they are the sizes the engine actually loads.

---

---

### 0. Design pillar — this is a *friendslop*

**Stated by the human, 2026-07-28, and it outranks realism everywhere below.**

Tumbang Preso is a chaotic, physical party game you play with friends in the same room or on the
same wifi. It is not a simulation and it is not trying to be tasteful. When a decision is between
*correct* and *funny*, **take funny** — a hopping tin can is the right answer, a physically
accurate one is not.

What that actually changes, concretely:

- **Permissive over strict.** Every unit gets every verb it plausibly could. Jump went on the
  Prop as well as the Person for exactly this reason: nobody needed to justify why a lata can
  jump, somebody would have had to justify why it cannot.
- **Readable over subtle.** Chunky silhouettes, loud impacts, saturated colour. This is why the
  render pass pushed saturation up rather than going for a tasteful filmic grade.
- **Recoverable over punishing.** A player who is confused should still be laughing. Downed
  states, retrieval scrambles and role swaps all exist to keep everyone in the round.
- **Where it does NOT apply:** the colour rule (orange = offense, blue = defence) and the
  proportion audit in §1. Those are legibility, not taste — a game can be silly and still has to
  be readable at arena distance.

### 1. The proportion audit — this is the headline

> ### ✅ FIXED 2026-07-28 — checklist 2.5, verified by render
>
> Everything this section originally described as broken is shipped: per-unit collision on
> `CharacterBase`, both hero props rebuilt at the target scale, `HAND_CARRY_OFFSET` re-measured and
> `TSINELAS_CARRY_SCALE` deleted, `base_circle_decal` resized, and `throw_bakya`'s range bug fixed.
> The table and the numbers below are kept as the historical measurement record — see checklist
> **2.5** for what actually shipped and §1a right below for the collision/offset details.

**The environment is built correctly at 1 unit = 1 metre. The two hero props were not.**

| Asset | Height/length | Real object | Ratio | Verdict |
|---|---|---|---|---|
| Person (capsule) | **1.60** | a teenager, ~1.6 m | 1.00× | ✅ correct |
| monobloc chair | 0.89 | 0.85 m | 1.05× | ✅ |
| oil drum | 0.90 | 0.88 m (200 L) | 1.02× | ✅ |
| basketball ring | 3.85 | 3.95 m to board top | 0.97× | ✅ |
| bench / bollard / crate / tyre | — | — | ~1× | ✅ |
| **lata (the can)** | 1.12 → **0.34** | 0.12 m | 9.3× → **0.7×** | ✅ **fixed 2026-07-28** |
| **tsinelas** | 1.35 → **0.43** | 0.27 m | 5.0× → **1.6×** | ✅ **fixed 2026-07-28** |
| building block a / b | 6.0 / 8.0 | ~10 m for 3 storeys | 0.6–0.8× | ⚠️ *fixed this pass → 9.0 / 12.0* |
| electric post | 4.5 | 8–9 m | 0.5× | ⚠️ open |
| tricycle | 1.64 long | ~2.8 m | 0.6× | ⚠️ open |

**What it looked like before the fix, for the record:** the can was 1.12 m and the monobloc chair
beside it was 0.89 m — *the can was taller than the chair*. Nothing about the set was wrong — the
props were wrong, by a factor of five to nine.

#### Why it was like this, and why that reasoning had expired

`Handoff.md` §0.11 / checklist 1.2 decided the props stay "hero-scaled" and explicitly rejected
rescaling them, because prop size is entangled with `CharacterBase`'s collision capsule, hit
radii, grab radius, throw ranges and camera distance. That was a sound call **when the set was a
grey box** — there was nothing in frame to be out of proportion *with*. Once there was a dressed
street full of correctly-sized objects, the props read as absurd against it, which is what
triggered this fix.

#### The target numbers, hit exactly

| Prop | Was | Target | Shipped | Scale | vs Person |
|---|---|---|---|---|---|
| lata | 1.12 | 0.34 | **0.3375** | 0.30 | 21% |
| tsinelas | 1.35 | 0.43 | **0.432** | 0.32 | 27% |

Both stay deliberately larger than life, because the moodboard's language is chibi exaggeration —
21–27% is *stylised*, where 70–84% was *broken*.

> ### The tsinelas number was not a guess, and it is the nicest fact in this document
>
> `character_visual.gd` used to carry `TSINELAS_CARRY_SCALE = 0.32`, applied only while the
> slipper was CARRIED, and **0.32 × 1.35 = 0.432**. That number was arrived at independently, by
> rendering, because the full-size slipper filled a quarter of the FPP screen.
>
> So the carried slipper was **already exactly the right size**. The loose and flying ones were the
> outliers. The mesh is now built at 0.32× natively (`generate_all.gd`'s `TSINELAS_SCALE`), and
> `TSINELAS_CARRY_SCALE`, `_scale_while_carried()` and the `CARRY_SCALE_LERP` tween are gone — a
> feature *removed* rather than added. `HAND_CARRY_OFFSET` was re-measured by rendering afterwards,
> per its own comment block.

#### 1a. What actually shipped — the blast radius this fix had to cross

`CharacterBase.tscn` is shared by Persons and Props, and its collision capsule used to be
`radius 0.4, height 1.6` for all of them — a correctly-sized 0.34 m can inside a 1.6 m invisible
capsule would have been WORSE than the old oversized mesh, because the mismatch would have stopped
being visible. So, in order:

1. **Per-unit collision.** Every shape on `CharacterBase.tscn` (`CollisionShape3D`, `Hurtbox`,
   `Hitbox`, `GrabArea`) is `resource_local_to_scene = true`, and `character_base.gd`'s new
   `_apply_role_collision()` sizes each one from `is_person`/`is_can`, called from `_ready()` and
   again from `reset_for_new_round()` (a Prop's `is_can` flips every round). Person is unchanged
   (0.4/1.6); Can and Tsinelas each get their own small capsule plus a proportionally-scaled melee
   `Hitbox` reach. `GrabArea` is inert on a Prop (only a Person's own is ever queried) and was sized
   anyway for consistency.
2. **Both prop meshes rebuilt at the target scale.** `generate_all.gd`'s `LATA_SCALE` (0.30) and
   `TSINELAS_SCALE` (0.32) are applied as a post-deform `Transform3D.scaled()` on every
   `add_revolve`/`add_extrude` call — the 2.1b-0 `transform` parameter — so not one dent depth or
   strap control point needed touching; only the final emitted vertex shrinks.
3. **`HAND_CARRY_OFFSET` re-measured, `TSINELAS_CARRY_SCALE` deleted.** Re-measuring was not a
   trivial reapplication of the old formula: deleting the runtime scale meant the model's
   `_align_to_capsule_floor()` drop (-0.8 in the Visual node's local space) was no longer being
   compensated by the carry-scale, dropping the mesh 0.544 units lower than it used to read while
   carried. Confirmed by rendering `tools/render_probe.gd`'s viewmodel mode, not by calculation
   alone — the first analytically-derived value put the slipper broadside-close to the FPP camera
   (the arm bone's fixed rotation turns the mesh's long axis nearly broadside to view) and filled
   most of the frame; the shipped value pushes it further out and keeps it below the eyeline.
4. **`base_circle_decal` resized.** 3.0 m outer diameter (drawn around the old 1.12 m can) down to
   1.4 m (radius 0.70), inside this section's own 1.2–1.5 m window. Ring width kept at 0.15 rather
   than shrinking 1:1 with the diameter, for the same foreshortening-at-distance reason it was
   widened from 0.06 in the first place (§9).
5. **Throw range, hit radius retuned.** `throw_bakya`'s range bug (4.4a, 4.81 units) fixed — arc
   12°/gravity_scale 1.0 instead of 8°/1.6, new range ~7.2, still shortest of the four by identity
   rather than by being broken. Every `ThrowProfile.hit_radius` halved — several were larger than
   the entire rescaled tsinelas mesh. Exact combat-feel numbers stay checklist 4.4's job once a
   human has actually played it.

**Jump was deliberately left untouched.** `JUMP_VELOCITY = 5.8` (apex 0.841) is a MAP constraint,
not a feel one — interior clutter is capped at 1.0 so an FPP eye at 1.25 can see over it, and
raising the apex past ~1.0 turns every crate into a platform. Rescaling the props doesn't change
that ceiling, so it wasn't touched.

---

#---

## 1.9 · The throw — how it works, and what was added 2026-07-28

Asked at playtest: *"can ppl grab the tsinelas? supposed to be able to grab the tsinelas, and
then show realistic throwing animation... what button to use, how to control strength / where it
goes and the animation for strength."*

**Grabbing and charged throwing already existed** — `carrier.gd` has carried the whole mechanism
since Task 1. What was missing was any way to *see* strength while aiming. Recorded here so the
next person does not rebuild a system that is already there.

### The verbs, and the buttons

| Verb | Button | Where |
|---|---|---|
| **Pick up** the tsinelas | **Left click** (or `grab_p1`'s key) | `carrier.gd::_step_grab()` |
| **Charge** the throw | **Hold right click** (or `special_ability_p1`) | `carrier.gd::_step_throw()` |
| **Throw** | **Release** right click | `carriable.gd::host_throw(direction, power)` |

Mouse bindings were added at v4.38 as *additional* events, so the keyboard bindings still work
and split-keyboard local play is unaffected.

### How strength works

- `CHARGE_FULL_TIME = 0.9` seconds of hold reaches full power.
- `CHARGE_MIN_POWER = 0.35` is the floor, so a panicked tap still throws rather than dropping the
  slipper at your feet.
- Power scales launch speed linearly: `speed = profile.launch_speed * power`, per the slipper's
  own `ThrowProfile`, so a wooden bakya and a rubber flip-flop can fly differently.

### Where it goes

Direction is the Person's aim — the FPP camera's forward — not a separate aiming mode. The
carried slipper's origin sits at `(0.260, 0.470, -0.480)` in character-local space, deliberately
forward of the eye and to the right so it never covers the crosshair.

### What was added: the wind-up

The throwing arm now **cocks back progressively with charge**, up to `VIEWMODEL_WINDUP_RAD`
(0.62 rad, ~36°) at full power, and snaps forward on release.

This is the point of the change, and it is a design argument rather than a polish one: **in first
person the wind-up is the only readout of throw strength in the player's eyeline.** The HUD's
charge meter is on the YOU card in a bottom corner, and nobody looks at a corner while aiming at
a can across an alley. The arm is where the eye already is.

Driven by polling `carrier.charge_power()` from `character_visual.gd::_process`, matching how that
file already drives carry scale and slipper spin — charge is a continuously-varying value, not an
event, and a poll survives the model rebuild every round swap performs.

⚠️ The idle sway clip animates the same rotation the wind-up writes, so the AnimationPlayer is
stopped while charging and resumes on its own afterwards. Animating position instead of rotation
is what made the arms float earlier; do not reintroduce it.

**Still open (needs the design treatment, not more mechanism):** the moodboard's THE ATTACKER card
draws *"charged throw (glow)"*. The wind-up covers strength; the glow does not exist yet. That is
checklist 0.1's remaining half.

## 2. What landed this pass

- **Lighting and grade.** Ambient was `SKY` at 0.85 off a pale grey sky — a uniform fill that
  removed all form. Now an explicit cool ambient at 0.55 against a warm sun at 1.25, which is the
  warm-light/cool-shadow split that makes flat colour read as 3D. Tonemap FILMIC → LINEAR (FILMIC
  desaturates, which fights a flat-colour palette), plus `adjustment_saturation 1.2` and
  `contrast 1.08`. SSAO on, so objects sit on the ground instead of hovering. Warm horizon haze
  and distance fog in the map's own hue instead of dissolving to white.
- **Facades.** Windows were emitted **only on the −Z face**, so three sides of every building were
  blank slabs — and the map yaws every mass and stands them on both sides of the road, so the
  blank sides were what the player actually saw. Windows now go on all four faces. Added a
  darker ground-floor plinth, a roof parapet, four painted colourways (`ENV_PAINT_*`) instead of
  two greys, and heights of 9 m / 12 m (three and four storeys) instead of 6 m / 8 m.
- **Tsinelas.** The Y-strap was two flat quads at `strap_y = 0.10` — *exactly* the top face of the
  sole, so it was a decal painted on the footbed with no silhouette from any angle. It is now two
  swept bands arching over the foot, so the slipper has a hole through it, which is the entire
  visual signature of a tsinelas and what makes it readable in flight. Sole split into a darker
  midsole and an inset footbed so the edge catches a shadow line.

---

### 3. Next stage, in priority order

**A · Proportions (§1).** Biggest single credibility win available. Blocked on Build for step 1.

**B · Narrow the alley.** Eskinita's playable width is `x = ±8` — a 16 m road, which is a
boulevard, not an eskinita. A real side street is 3–5 m. The layout script already has `W = 8.0`
as one constant. **Do not change it blind:** it is arena scale, and `Art_Direction.md` §4
explicitly warns against changing arena scale in the same commit as arena art, because a
movement-feel regression then becomes unattributable. Sequence it as its own commit, after 0.4.

**C · Give the environment the same ink outline the characters have.** M-6 step 3 says env pieces
get no outline. That decision predates the Persons getting one, and the result is two art styles
in one frame — outlined characters standing in an un-outlined set. Recommend outlining the large
silhouette pieces (walls, buildings, posts, tricycle) and leaving small clutter clean. This is a
direction change, so it is called out rather than done quietly.

**D · Road surface.** A single flat 40×40 slab plus tile seams that read as a grid. Wants: a
crown, a gutter channel at the kerb line, patched asphalt variation, and puddles.

**E · Remaining scale fixes.** Electric post 4.5 → 8.0, tricycle 1.64 → 2.8 long, tree 4.2 → 7.0.

**F · Bayan Plaza gets the same lighting pass.** Its builder still has the old
`ambient_light_source = 3` at energy 1.0 and FILMIC tonemap. Mechanical port of §2's first bullet.

**G · The moodboard's third map, Barong Barong.** Purple/orange sunset skybox, corrugated shanty
stacks, sampay lines, aspins. Stretch goal; only after A–D.

---

### 4. Flagged for a human

1. ~~Item A is a cross-lane change and needs Build to move first.~~ **Shipped 2026-07-28** — see
   §1a.
2. **Item C reverses a documented decision** (M-6 step 3). Worth 30 seconds of your opinion.
3. **Item B changes arena scale**, which is a feel change, not an art change. It should not happen
   before somebody has played the current one (0.4).

---

### 5. Playtest findings, 2026-07-28 — the first time anyone played it (0.4)

Reported by the human after a live session. **Root-caused before any of it was
"planned around"** — three of the four reports turn out to be one bug plus one
documented behaviour, not four separate problems.

#### P0 · Esc opens the pause menu with the mouse still captured, and nothing pauses

Reported as three symptoms: *"mouse disappears when I pause"*, *"it doesn't really pause, the game
keeps playing"*, *"I can't return to menu because no mouse (I have to alt-tab to get it back)"*.

**Root cause: `scripts/ui/settings_panel.gd::_unhandled_input` has no visibility guard.** In Godot
a hidden `Control` still receives `_unhandled_input` — visibility only gates `_gui_input`. So the
*hidden* settings panel swallows the Esc press, calls `set_input_as_handled()`, and emits
`back_pressed`. `main.gd:231` has that signal wired to
`func(): settings_panel.hide(); pause_root.show()` — which shows the pause overlay but **never
touches `Input.mouse_mode` and never sets `get_tree().paused`**, because
`_on_pause_toggle_requested()` was never reached at all.

That single missing guard produces all three symptoms exactly as described. `match_result.gd:29`
already has the guard (`if not visible: return`), which is what makes the omission obvious once
you look at both.

**Fix:** add the same guard. One line. Everything else about the pause system is already correct.

#### P1 · Cannot Tab to the Can

`debug_player_switcher.gd` **self-disables in a networked match** — "every handler no-ops in a
networked match (where each peer owns exactly one character and reassigning `player_id` would be
meaningless)". The pause report above confirms the session was networked: *"it doesn't really
pause, the game keeps playing"* is precisely the `NetworkManager.is_networked()` branch of
`_on_pause_toggle_requested()`, which deliberately refuses to freeze a networked match.

So both reports are the same underlying condition: **the playtest was run as a host, not as Local
Match.** Tab works in Local Match and is meaningless when hosting.

This is defensible design that is nonetheless a bad experience for the one thing anybody actually
does — solo-testing by hosting. **Recommendation:** when a networked match has exactly one human
peer, treat it as local for pause and unit-switching purposes. Flagged rather than done: it is a
`NetworkManager` semantics change.

#### P1 · Nothing can jump

Confirmed absent, not broken: **zero occurrences of "jump" in `project.godot` or
`character_base.gd`.** There is no jump action, no jump input binding and no vertical impulse
anywhere. It was never built.

The human wants it on **both** Persons and Props ("tsinelas can't jump, can you check if can can
jump, they both should be"). Props are `CharacterBody3D` like Persons and already run gravity, so
this is an input action plus an impulse, not a new movement system.

⚠️ **Design consequence worth stating before it ships:** the interior-clutter height law
(`Art_Direction.md` — everything loose in the alley is ≤ 1.0 so an FPP Person at eye height
1.25 can aim over it) assumes players cannot get on top of things. Jump makes every crate, drum
and tricycle a platform, and the boundary walls are 12 units tall but the *dressing* is not. Jump
height must stay below the lowest climbable surface, or the boundary needs revisiting.

#### P2 · No arms visible in first person

This is **B-87**, already filed. Not a regression: `camera_rig.gd::_apply_fpp_self_hide` hides the
entire `Visual` subtree, and the Kenney rig has no separate arm mesh — `body-mesh` is torso, arms
and legs as one skinned mesh, so the arms cannot be kept while the torso is hidden.

Options, in ascending cost: (a) accept it; (b) hide only `head-mesh` and pull the near clip plane
in, accepting that the player sees their own chest; (c) build a dedicated viewmodel arm pair as
generated `.obj`, parented to the arm bone and visible **only** in FPP. (c) is the right answer and
is real modelling work — it belongs in this plan's next stage, not in the P0 fix batch.

---

### 6. Item C attempted and reverted — read this before trying again

**`material_overlay` cannot produce an inverted-hull outline.** Tried at v4.36: an
`env_outline.tres` (M-4's `outline.gdshader`, `cull_front` + vertex inflation) assigned as
`material_overlay` on all 53 silhouette pieces — walls, building masses, posts, tricycles.
Rendered with the width at both 0.022 and 0.085. **No outline appeared at either width.**

The reason is that `material_overlay` re-draws the mesh *depth-tested against the depth the base
pass just wrote*. The inflated hull sits behind the surface everywhere, so every fragment fails
the test, including at the silhouette. `next_pass` works for the Persons because it is part of
the surface material's own pass chain, not a separate overlay draw.

**So the real fix needs per-surface `next_pass`, which means overriding each `.obj` surface
material.** Each env piece carries several materials from its `.mtl` (a building has body, band,
plinth, window), so this means either:

- **(a)** emitting `surface_material_override/N` per node in the map builder, which re-declares
  every colour in the builder and makes the `.mtl` no longer authoritative; or
- **(b)** giving the env pieces the M-4 toon shader with the outline chained as `next_pass`, the
  same treatment the Props already get in `character_visual.gd::_apply_toon_pass()` — but driven
  at import or by a small scene script, since map dressing is plain `MeshInstance3D` and never
  passes through `CharacterVisual`.

**(b) is the right answer** and is a genuine piece of work, not a config change. Note that
`outline_width` is in MODEL space, so it must scale with piece size: 0.008 suits a Person at
`PERSON_SCALE` 2.38, while a 9-metre building needs roughly an order of magnitude more to read
at 20 units. A single shared width will not work across the kit.


---


<a id="part-2"></a>

# Part 2 — Moodboard record, palette and modelling rules

*(was `docs/Art_Direction.md`)*

## Brief — 3D Modeling & Art Agent

> ## ⚠️ PARTLY SUPERSEDED — read this box first (2026-07-27)
>
> **Most of the `M-` block has shipped since this brief was written.** Re-verified against the
> code, not against checkboxes:
>
> | | |
> |---|---|
> | **M-1** generator toolchain | `[x]` shipped v3.5, deterministic |
> | **M-2** lata — revolved body, 3 dent states, knocked-down tilt | `[x]` shipped v3.7, **renders as a can** |
> | **M-3** tsinelas — extruded sole, real Y-strap | `[x]` shipped v4.12. Geometry is good; its **scale** is now the open question |
> | **M-4** flat toon + ink outline | `[x]` shipped v4.11 |
> | **M-5** Persons — restyle | `[ ]` steps 1–3 open. **Step 4 (walk/run) is DONE** — the "only `idle` of 32 clips is wired" claim is stale |
> | **M-6** environment kit · **M-7** Eskinita | `[ ]` — now owned by [`Art_Direction.md`](Art_Direction.md) |
> | **M-8** logo | `[ ]` — blocked on the typeface decision |
>
> **Live state and ordering are in [`Checklist.md`](Checklist.md), not in this file.** The
> branch instructions in §0 below are stale — see the box under it.
>
> **What this brief is still the best source for:** the moodboard record, the generator's traps
> (winding, float snapping, determinism), the material/token rules, and the triangle budgets. Read
> it for those. Take scope and ordering from the checklist.
>
> **Model routing:** the *design* half (silhouette, proportion, what a mesh should look like) is
> **Opus 5, high effort**. The *generator code* half is **Sonnet 5, medium**. If more than one agent
> is running, read [`Concurrency_Protocol.md`](Concurrency_Protocol.md) first — this brief's
> workstream owns `assets/**` and `scenes/characters/visuals/**` and must take a lock before
> touching `CharacterBase.tscn` or `Main.tscn`.

A self-contained brief for the agent taking the **M- block** (3D modeling) of
[`Handoff.md`](Handoff.md) §4. Paste §0 below as the opening prompt; the agent reads the rest of
this file itself.

**Attach the moodboard image to the first message.** It is not in the repo and everything below
describes it second-hand. A description of a logo is not a logo.

---

### 0. The prompt — paste this

> You are the Lead Technical Artist and 3D Modeler for **Tumbang Preso**, a Godot 4.7 (GDScript,
> Forward+) 2v2 LAN arena brawler built on the Filipino street game *tumbang preso*, for the Gear
> Up NCR Esports Game Dev Challenge. Repo: `DOST-GameDEV/DOST-GameDev`.
>
> **Before anything else:**
>
> 1. ⚠️ **STALE — the instruction below is from an earlier pass.** `design-ui-models-and-fixes` has
>    long since merged; `main` carries everything. Branch off `main` (or off `integration` if a
>    second agent is running — see [`Concurrency_Protocol.md`](Concurrency_Protocol.md)) and cut
>    `art/<task>`. The original text is kept only so the history reads honestly:
>
>    > Get on the branch that holds the plan:
>    > ```
>    > git fetch origin
>    > git checkout design-ui-models-and-fixes && git pull
>    > ```
>    > **The plan is not on `main` yet.** `main` is at `6f6d3b7` (v3.4) — correct code, but it does
>    > not have the queue you are about to work, `Handoff.md`, or this brief.
> 2. Set your identity **exactly**:
>    ```
>    git config user.name "M4tyu633"
>    git config user.email "matthewtlabrador@gmail.com"
>    ```
> 3. **AUTHORSHIP RULE — non-negotiable.** Every commit is authored and committed **solely by
>    `M4tyu633`**. Do **not** add a `Co-authored-by:` trailer. Do **not** name Claude, an AI
>    assistant, or any tool as author, co-author, or committer. Do not let your environment inject
>    its own identity. After your first commit, verify with:
>    ```
>    git log -1 --format='%an <%ae> | %cn <%ce>'
>    ```
>    It must print `M4tyu633 <matthewtlabrador@gmail.com>` on **both** sides. If it does not, stop
>    and fix it before continuing — a commit that lands with the wrong author has to be rewritten
>    out of history, which is far more expensive than checking.
> 4. Read, in full: `docs/Handoff.md` (§0–§4), `docs/Dev_Plan.md` (§0, §1, §3, §4), and
>    `docs/Art_Direction.md` (this file — the rest of it is your reference).
> 5. Read the actual code before trusting any doc about it. This project has a documented history
>    of docs describing things the code contradicts, in both directions.
>
> **Your scope is `Handoff.md` §4's M- block: M-1 through M-8.** Work them in order — M-1 is the
> toolchain everything else uses, and nothing can start before it exists and is proven
> deterministic. Do not touch the F-, A- or U- blocks; they belong to other passes.
>
> **The standing camera directive is inviolable: a Person is always first-person, a Prop (Can /
> Tsinelas) is always third-person, derived from `is_person`. No toggle, no override, no
> exception.** Your models are viewed under both. Every mesh must read correctly from a TPP
> spring arm at ~4.5 units *and* be invisible-but-shadow-casting when it is the body you are
> looking out of.
>
> Work to the *Acceptance* line on each task. If you cannot run the game to confirm one, say so
> explicitly in the commit and mark the item `[~]`, not `[x]`. Update `Handoff.md` §4 checkboxes
> and §3's ledger as you go. One concern per commit, with the task ID in the subject, and bump
> `application/config/version` in `project.godot` in the same commit.

---

### 1. What the moodboard actually specifies

Attach the image. This section is the written record of it, so a disagreement between the two is
catchable.

**Logo lockup.** `TUMBANG` over `PRESO`, heavy hand-drawn **unicase** marker face (lowercase
renders as capitals — the board's letter sheet shows a/A, b/B … all mapping to the same glyph),
solid black. **The `O` of `PRESO` is replaced by a top-down can lid** — a dark ring with a pull
tab. That substitution is drawn art; no font reproduces it. See `Handoff.md` **M-8**.

**Reference game, called out on the board: PEAK.** Chunky stylised 3D, high-saturation flat
colour, minimal in-world HUD, readable silhouettes at distance. That is the target look, not
photoreal and not PBR.

**Character render on the board:** three chibi figures in T-pose on a sand-coloured backdrop.
Oversized ball heads, short limbs, simple Filipino school-kid outfits — one yellow with a tall
white hat and green shorts, one with red pigtail hair, a blue-white top and an orange bag strap,
one orange-skinned in a tan tunic and small cap. **Read the proportions, not the specific
outfits:** head roughly a third of total height, no facial geometry beyond simple features, flat
colour blocks with no texture detail. The Kenney *Mini Characters* already in the repo are this
proportion — which is why `Handoff.md` M-5 restyles them rather than replacing them.

**Four role cards.** Light blue-grey panels with a faint blueprint grid, a deep-navy 3px border, a
6px full-height colour bar at the left of each heading, an all-caps heading with a parenthetical
Filipino subtitle, a keycap badge, three captioned state illustrations, a bottom keyword strip,
and a folded dark triangle in the bottom-right corner.

| Card | Subtitle | Accent | Input badge | States illustrated |
|---|---|---|---|---|
| THE ATTACKER | (Striker) | orange | WASD | dynamic movement · aiming arc · charged throw (glow) |
| THE DEFENDER | (Guard/Taya) | blue | arrow keys | stance variations · body-block hitbox · lata reset channel (progress bar) |
| THE SLIPPER | (Tsinelas) | magenta | — | in-hand ready (glow) · thrown trajectory (spin + motion blur) · retrieval highlight (floor decal) |
| THE CAN | (Lata) | magenta | arrow keys | **standing (stable)** · **knocked down (tilted, dented)** · **impact effect (particle burst)** |

**Three of those illustrated states are mechanics that do not exist in code** — the aiming arc /
charged throw (B-45), and the lata reset channel (B-46). They are open design decisions
(`Handoff.md` §5), **not** silent build orders. Do not implement a mechanic because it is drawn on
a card.

**The CAN row is your spec for M-2.** Standing, knocked-down-and-dented, and impact burst are
exactly the three states that task builds. The impact burst is already done (Q-8).

---

### 2. Palette — the single source of truth

Defined in `scripts/ui/ui_theme.gd` as `class_name UiTheme` constants. **Reference the constants,
never retype the hex**, so a palette change is one edit. The `.mtl` files your generator emits
should have their `Kd` values derived from these same constants (`Handoff.md` M-1 step 1).

| Token | Hex | Use in 3D |
|---|---|---|
| `INK` | `#040838` | Outlines (inverted hull), can rim and lid, dark accents |
| `PANEL` | `#E1E5E8` | Neutral light surfaces |
| `CARD` | `#F5F7FA` | Lighter neutral |
| `OFFENSE` | `#F87020` | Attacking side — role colour |
| `DEFENSE` | `#0080E8` | Defending side — role colour. **Can body only.** ⚠️ **NOT the tsinelas sole — see below** |
| `IMPACT` | `#F468A8` | Impact bursts, tsinelas strap, hazard decals |
| `HIGHLIGHT` | `#F8D028` | Can label band, base-circle decal, ready glows |
| `DANGER` | `#F80000` | Downed / out-of-bounds |

> ⚠️ **CORRECTION, 2026-07-28 — this table was the source of B-81.** It used to assign `DEFENSE` to
> "Can body, **tsinelas sole**", and `_build_tsinelas()` implements exactly that. **It is wrong.** A
> Prop is a Tsinelas precisely when its team is on **offence**, so the attacking team's prop is
> painted the defending colour — which breaks rule 1 immediately below. The moodboard disagrees
> independently: **THE SLIPPER's card accent is magenta**, as is THE CAN's. The rule is right and
> the table was wrong. **Fixed 2026-07-28 (B-81):** sole → `IMPACT`, straps → `HIGHLIGHT`, toe post
> → `INK`, and the materials renamed after the PART rather than the token. Verified by render. The
> Can is deliberately not in scope — a blue can on the defending side is consistent and renders well.
>
> **Environment art may use neither hue at all** — see
> [`Art_Direction.md`](Art_Direction.md) §3 for the `ENV_*` band that exists so it
> does not have to.

**Two hard rules, from `Dev_Plan.md` §4.2:**

1. **Orange is always offense, blue is always defence, everywhere in the project.** Never reuse
   either hue for anything else — not for a wall, not for a prop, not to tell two characters
   apart.
2. **The accent tracks *role*, not *team*.** Team A is orange while attacking and blue while
   defending, and it swaps every round. Team identity is carried by the **A / B letter mark**
   only. This is why M-5 says the two Persons must be distinguishable by hair and outfit and
   **not** by orange/blue.

---

### 3. Code you will be working against — read these first

| File | Why it matters to you |
|---|---|
| `scripts/characters/character_visual.gd` | **The single owner of how a unit looks.** Model instancing, per-surface material duplication, the hit flash, the impact particles, the capsule-floor alignment. Every model change lands here. Read its header comment before writing a line. |
| `scenes/characters/visuals/CanVisual.tscn` | Current can — six `CylinderMesh` primitives. M-2 replaces it. |
| `scenes/characters/visuals/TsinelasVisual.tscn` | Current slipper — four boxes. M-3 replaces it. |
| `scripts/systems/camera_rig.gd` | The FPP/TPP rig. Its `_apply_fpp_self_hide()` is the function your new meshes must not break. |
| `scripts/ui/ui_theme.gd` | The palette constants above. |
| `scenes/main/Main.tscn` | The grey box M-7 replaces. Also carries the `WorldEnvironment` M-4 tunes. |

#### Five traps that are already documented in the code, and will bite you anyway

1. **`_align_to_capsule_floor()`** (`character_visual.gd:132`) measures the instanced model's AABB
   at runtime and drops it to the bottom of `CharacterBase`'s 1.6-unit capsule. It exists because
   the can (0.34), the tsinelas (0.43) and the two Kenney Persons (1.60 and 1.85) are all
   different heights. **A new mesh with a stray vertex — a wide bounding box from a helper object,
   an outline hull — shifts the measured AABB and the whole model floats or sinks.** Re-verify
   after every model swap.
2. **Per-surface material duplication** (`_collect_meshes()`, `:155`). Each mesh gets its own
   `BaseMaterial3D` copy so flashing one unit white does not flash the enemy too. It casts to
   `BaseMaterial3D` and **silently skips anything that is not one** — which is exactly what a
   `ShaderMaterial` is. **Putting the M-4 toon shader on a character will silently kill its hit
   flash.** `Handoff.md` M-4 step 4 flags this; resolve it deliberately, don't discover it.
3. **`model_changed` signal** (`:76`). The camera rig listens for it to re-apply the FPP self-hide,
   because rig `_ready()` runs *before* the model is instanced (children are ready before
   parents), and every role swap rebuilds the mesh tree. **Any new code path that replaces meshes
   must emit it**, or a Person's own body renders solid in first person and the player looks at
   the inside of their own head. That was B-61.
4. **`remove_child()` before `queue_free()`** when swapping models (`:100`). `queue_free()` only
   schedules deletion for end of frame, so the outgoing model keeps drawing while its duplicated
   materials are already released — the renderer reports `Parameter 'material' is null` once per
   frame on the swap frame. The existing code does this correctly; keep it that way.
5. **`is_can` flips every round.** A Prop is a Can one round and a Tsinelas the next
   (`main.gd::_reset_world`). Nothing about a model may be baked once in `_ready()`. The
   `_current_key` early-out (`:93`) makes repeat `apply()` calls free — **do not defeat it** by
   making the key less specific, or every round transition rebuilds and restarts animation.

---

### 4. Modeling approach — already decided, do not relitigate

`Handoff.md` §4's M- block header has the full reasoning and the rejected alternatives. In short:

- **`.obj` + `.mtl` emitted by a committed generator script** (`tools/models/`) for anything a
  primitive cannot express. Plain text, so it diffs and merges like code, needs no LFS, and needs
  no Blender on anyone's machine. Parameterised, so a dent depth is a constant to change and
  re-run rather than a modelling session to redo.
- **Primitive composites in `.tscn`** stay, for shapes primitives genuinely nail.
- **CSG is rejected for shipping geometry** — it rebuilds on the CPU every time the tree changes
  and is a prototyping tool. Fine to block out a shape with; bake it before it ships.
- **Persons keep the Kenney CC0 rig.** `.obj` carries no skeleton, no skin weights, no animation.
  The Kenney minis are already rigged, already ship 32 clips, and are already the moodboard's
  chibi proportion. M-5 is a retint-and-accessorise pass, not a rebuild.

**Determinism is the acceptance test for M-1 and it is not negotiable:** running the generator
twice must leave `git status` clean. No `randf()`, no iteration over unordered keys, fixed float
precision. A generator whose output churns is a generator nobody will run.

**Triangle budgets:** can ≈ 260 · tsinelas ≈ 180 · environment pieces ≤ 400 each. These are
generous for the style — the moodboard's look comes from flat colour and clean silhouette, not
from density.

---

### 5. What is NOT yours

- **The F-, A- and U- blocks** in `Handoff.md` §4. In particular, do not "fix" the camera while
  you are in there — **A-2** deletes the scene-level `Camera3D` and is a separate pass with its
  own acceptance test.
- **Gameplay logic.** Round-win logic stays out of `character_base.gd` and `hitbox.gd`.
  `CharacterBase` must never learn what a dent looks like — that is `character_visual.gd`'s job,
  by design.
- **`DebugPlayerSwitcher` and anything `debug_`-prefixed.** Gameplay code — which includes every
  visual script — may never reference debug code, not even behind `if OS.is_debug_build()`. See
  `Dev_Plan.md` §0.3.
- **Audio.** Not in this queue, and it needs an owner (`Handoff.md` §6).

### 6. Reporting

- If a task turns out to be already done, **say so and move on.** Do not rewrite working code.
- If this brief or `Handoff.md` is wrong about the code, **say it is wrong** rather than building
  around it. Both have been wrong before, in both directions.
- If you finish 6 of 8 tasks, say which 2 you did not do and why. Do not silently narrow scope.
- Screenshots beat descriptions for this work. `mcp__godot-mcp__capture_screenshot` exists; use
  it, and put before/after pairs in the commit body or the PR.


---


<a id="part-3"></a>

# Part 3 — Environment kit specification

*(was `docs/Art_Direction.md`)*

## Environment Kit Spec — checklist 2.1a

**Status:** art direction, complete. **Owner of this document:** 🎨 Design lane.
**This is the input to [`Checklist.md`](Checklist.md) 2.1b** (generate the kit) **and then to 2.2**
(Eskinita).

> ### How to use this document
>
> It is written to be **executed without asking the design lane a question.** Every piece has a
> name, a footprint on the grid, a height, a triangle budget, its materials as `UiTheme` tokens,
> and one line saying what it contributes. Where a number is a judgement call rather than a
> measurement, a **tuning window** is given — move inside the window freely; come back only to go
> outside it.
>
> Where this document and any other document disagree about the code, **this one was checked
> against the code on 2026-07-28** and three of the disagreements it found are filed as B-81, B-82
> and B-83. Do not inherit the other one.

---

### 1. The two vocabularies, reconciled — read this before anything else

The moodboard and the GDD name different things, and both have been quoted as authoritative. They
are reconciled here **once**, and the ship names win everywhere downstream.

| Moodboard reference | GDD name | **Ships as** | Status |
|---|---|---|---|
| **2 · Metro** — grey urban block, road with lane markings, sari-sari cart, monobloc chairs, bins | **Eskinita** — urban side street, sari-sari backdrop, jeepney lane hazard | **`Eskinita`** | Map 1. Checklist 2.2. |
| **1 · Province** — grass field, sand/dirt apron, trees ringing the map | **Bayan Plaza** — barangay plaza, fiesta banners, mud, wandering carabao | **`Bayan Plaza`** | Map 2. Checklist 2.4. First to cut. |
| **3 · Barong Barong** — corrugated sheet, stacked shanties, tangled wire, sampay/puspin/aspin | *(not in the GDD)* | **Not a map.** | Folded in — see below. |

**The board's Metro is a mood reference; Eskinita is the map.** "Metro" describes the *material
world* — asphalt, concrete, a sari-sari counter, plastic chairs. "Eskinita" describes the *shape* —
a narrow side street. They are not in conflict; the board supplies the surfaces and the GDD
supplies the plan. Use both, call it Eskinita.

**Bayan Plaza reconciles the same way:** the board's Province is what you see *past* the plaza. A
barangay plaza is a hard slab with a dirt/grass apron and a tree line beyond it. One map, three
concentric materials, both descriptions satisfied.

#### Barong Barong is a dressing layer, not a third map — the argument the brief asked for

`Art_Direction.md` §2 says to treat Barong Barong as a stretch goal "unless you argue
otherwise in writing." Arguing otherwise:

1. **A third arena is indefensible on the schedule.** Bayan Plaza (2.4) is already named the *first
   thing to cut* under time pressure. Proposing a map below the one that gets cut first is
   proposing nothing.
2. **Its vocabulary is the most valuable material in the entire reference set.** Corrugated
   galvanised-iron sheet, sampay strung overhead, tangled service wire and mismatched patchwork
   walls read as *the Philippines specifically* in a way that asphalt and concrete never will.
   Spending that on the map most likely to be cut wastes it.
3. **An eskinita is literally where barong-barong construction is.** A narrow Manila side street is
   walled in GI sheet and roofed in laundry lines. There is no fiction to bend.

**So: Barong Barong's whole material vocabulary is folded into Eskinita's boundary**, where every
judge will see it, and the third map is not built. `wall_corrugated`, `wall_corrugated_leaning`,
`laundry_line` and `post_electric` are the pieces that carry it, and they are the priority pieces
of the set.

---

### 2. The laws every piece obeys

Non-negotiable. A piece that breaks one of these is wrong even if it looks good.

1. **⛔ No `#F87020` and no `#0080E8` anywhere on a map, ever.** Orange is offence and blue is
   defence, project-wide, and the world is the largest surface in the frame. Environment art uses
   the `ENV_*` band of `UiTheme` and nothing else. See §3.
2. **⛔ No outlines on environment geometry.** M-4's inverted-hull pass is for characters and hero
   props. An outlined street is visual noise and doubles the draw calls on the largest meshes in
   the scene. `character_visual.gd::_apply_toon_pass` is the only thing that applies it and it is
   never called on map geometry — keep it that way.
3. **≤ 400 triangles per piece.** Budgets below are per piece and total under it with room to
   spare. The style's readability comes from flat colour and clean silhouette, not density.
4. **Determinism is an acceptance criterion.** Two consecutive `generate_all.gd` runs must be
   byte-identical with `git status` clean after the second. No `randf()`, no unordered iteration,
   no time. **Any scatter is seeded from the piece's own index**, e.g. a crate's tilt is
   `TILTS[i % TILTS.size()]` from a `const` array — never a random draw.
5. **`.obj` + `.mtl` stay plain text and out of LFS.** No hand-edited binaries; the generator is
   the only author of geometry.
6. **Every colour is a `UiTheme` constant, never a retyped hex.** `set_material()` takes the
   constant directly, exactly as the lata and tsinelas already do.

#### The height law — derived, not guessed

Measured this pass with `render_probe.gd`: the Person capsule is 1.6 tall and centred on the
character's origin, and `FppPivot` sits at `+0.45` in that local space. Standing on the ground, a
first-person Person's **eye is at `y = 1.25`**.

That single number tiers the whole kit, and `Art_Direction.md` §6 requires it ("an
FPP Person can see over the props well enough to aim"):

| Tier | Height | Rule |
|---|---|---|
| **Ground** | ≤ 0.20 | Decals, kerbs, tiles. Never blocks anything. |
| **Interior clutter** | ≤ **1.00** | May be placed anywhere in play. An FPP Person sees over it. **This is the default tier — most of the kit lives here.** |
| **Waist cover** | 1.00 – 1.60 | Blocks a body, not a sightline. Deliberate cover only, placed by 2.2, never scattered. |
| **Hard cover / boundary** | ≥ **2.40** | Blocks sight decisively. **Boundary ring only**, or one or two deliberate blockers. |

Anything in the top two tiers placed inside the play area is a design decision made in 2.2, not a
consequence of the kit. Pieces below are labelled with their tier.

---

### 3. Palette

Added to `scripts/ui/ui_theme.gd` in this pass (design-lane file) and **verified not to change the
generated `assets/ui/tumbang_preso.tres`** — `build()` does not read them, by design, because a
Control theme must not carry map paint. Confirmed by re-running
`tools/regenerate_ui_theme.gd`: zero content change.

| Token | Hex | Used for |
|---|---|---|
| `ENV_ASPHALT` | `#4a4e57` | Road surface, gutter channel |
| `ENV_CONCRETE` | `#b7b2a6` | Walls, kerbs, plaza slab, bollards |
| `ENV_CONCRETE_DARK` | `#8c877c` | Damp-course skirts, shadow bands, wall bases |
| `ENV_GI_SHEET` | `#9aa3a2` | Corrugated galvanised-iron sheet |
| `ENV_RUST` | `#a65a3a` | Rust bands, drums, tricycle frame |
| `ENV_WOOD` | `#a8763f` | Crates, counters, bench slats, backboards |
| `ENV_WOOD_DARK` | `#6b4a28` | Posts, framing, tree trunks |
| `ENV_FOLIAGE` | `#4f8c3b` | Canopies, planters — front layer |
| `ENV_FOLIAGE_DARK` | `#35652a` | Canopies — the layer behind |
| `ENV_DIRT` | `#c2a878` | Dirt apron, mud, unpaved shoulder |
| `ENV_TARP` | `#dcd5c4` | Awning canvas, sacks, hung laundry |
| `ENV_RUBBER` | `#2b2b30` | Tires, wheels |

**Three existing tokens are borrowed, sparingly and on purpose:** `INK` for wires, window bars and
tire treads; `HIGHLIGHT` for the base-circle decal (the token's own documented use), awning
stripes, and the one warning band on a bollard; `PANEL` for road markings and the throwing line.
**`IMPACT` is reserved** — it is the props' and the hazard's colour and must not appear on scenery.

**The discipline that keeps this readable:** every `ENV_*` colour is held under ~70% saturation,
and under ~75% value where its hue approaches a role hue. `ENV_RUST` is the test case — same hue
family as `OFFENSE`, deliberately two steps down in both saturation and brightness. **Add nothing
in the cyan-blue band at all.**

---

### 4. The boundary — the thing most likely to be got wrong

The board's own annotation on the Metro map is the entire instruction:

> *"basically just add random assets on the edge that acts like a wall"*

#### Where the boundary actually goes — corrects a live error

**B-83, found this pass.** `Main.tscn`'s `Bounds/Wall*` sit at `±41` with half-depths of 1, so
their inner faces are at **`±40`** — while the floor slab ends at **`±20`**. There is a 20-unit
ring of empty space on all four sides that the colliders do not enclose; a player runs off the
slab and falls past them to the `KillPlane`. The arena does not merely have *invisible* walls, it
has **no working boundary at all**.

**Eskinita's boundary geometry and its colliders both go at `±20`,** flush with the playable
surface, and `Main.tscn`'s `Bounds` node is deleted along with the grey box when 2.2 lands.

#### How it is built

- **Never a bare coloured box.** Not brown, not grey, not textured. A flat wall plane reads as a
  test arena at any distance, and no amount of colour fixes it.
- **Three layers minimum, and they must overlap in silhouette.** The board rings its maps with
  *depth* — buildings behind buildings, trees behind trees. One row of props is a fence.
  - **Layer 1, `y ≤ 2.6`, at `±20`:** the pieces the player touches — `wall_corrugated`,
    `wall_plain`, `sari_sari_store`, `wall_corrugated_leaning`. **Collision lives here**, on the
    dressing itself, as a convex hull per piece.
  - **Layer 2, `y` 3–8, from `±22` to `±26`:** `building_block_a` / `_b`, rotated and offset off
    the grid so no two rooflines align. No collision — Layer 1 already stops the player. Set
    `ENV_CONCRETE_DARK` on the further blocks so the layers separate by value, not just by
    parallax.
  - **Layer 3, overhead:** `post_electric` and `laundry_line` spanning *across* the alley above
    head height, wires crossing the frame. **This is the layer that does the most work for the
    least geometry** — it converts an open box into a roofed street in about 60 triangles, and it
    is the single most Filipino-reading thing you can put in the sky.
- **Collide on the dressing where it is solid; hide a collider just behind it where it is open.**
  A GI-sheet wall collides on itself. A tree line or a laundry-line gap gets a plain invisible
  `StaticBody3D` box at `±20`, sitting *behind* visible geometry so the player never sees the
  surface they are stopped by. Both are correct; **a visible gap the player can walk into and get
  stuck in is not.**
- **Vary the ring.** Every piece in Layer 1 is on the grid, but rotation is `0 / 90 / 180 / 270`
  chosen by a **seeded** index, and every third bay steps back one cell. A perfectly flush wall of
  identical panels reads as a corridor in a level editor.

#### The alley is narrower than the arena — and nothing about the arena changes

**Do not change arena scale in the same commit as arena art** (`Art_Direction.md` §3).
The floor stays 40 × 40. But an eskinita is a *narrow side street*, and the throw ranges measured in
§9 put every real exchange inside about 13 units.

So: **dress the boundary inward.** Keep the floor and the outer collider ring at `±20`, and build
the Layer 1 wall line at **`x = ±8`**, leaving a playable slot roughly **16 wide by 34 long**. The
strip between `x = ±8` and `x = ±20` is filled with Layer 2 and 3 dressing and is not walkable.
The arena's numbers are untouched, the alley reads narrow, and if 0.4 says it is too tight the fix
is moving a wall line, not rebuilding a map.

---

### 5. What the generator can and cannot do today — read before writing any `_build_*`

Checked against `tools/models/obj_writer.gd` on 2026-07-28. It has exactly four emit operations,
and this spec is written to fit inside them:

| Operation | What it does | Cost |
|---|---|---|
| `add_extrude(outline, y_bottom, y_top, mat)` | Closed CCW outline in **XZ**, extruded along **+Y**, both caps. | `4N − 4` tris for an `N`-point outline |
| `add_revolve(profile, segments, mat, smooth, deform)` | `(radius, y)` profile spun around **Y, at the origin**. | `2 × S × (P−1)` tris, less 1 per collapsed end |
| `add_quad(a,b,c,d,mat)` / `add_tri(...)` | Raw faces, arbitrary position. | 2 / 1 |
| `recalculate_normals(deg)` | Smooth-by-angle. **Call once at the end of every piece.** | — |

Two consequences that shape every piece below, so plan for them rather than discovering them:

- **`add_extrude` only ever extrudes vertically.** Anything prismatic and upright is one call — and
  that is most of a street. A *sloping* awning or a *leaning* sheet is not.
- **`add_revolve` is locked to the Y axis at the object's own origin.** A tire lying flat is a
  revolve. A wheel standing upright is not. Neither is a second bollard 2 units to the left.

#### The one generator change this kit needs — hand it to the build lane

> **New item, filed as checklist 2.1b-0. `tools/models/obj_writer.gd` is a 🔧 BUILD-lane file and
> the design lane must not edit it.**
>
> Add an optional trailing `transform: Transform3D = Transform3D.IDENTITY` to `add_extrude` and
> `add_revolve`, applied to every emitted vertex before it reaches `_add_vert`.
>
> - **~6 lines.** It is the difference between "the kit" and "the kit plus hand-rolled vertex fans
>   for every wheel".
> - **It cannot break shading**, because this spec already requires `recalculate_normals()` at the
>   end of every piece, and that rebuilds normals from geometry — so a rotated, offset or even
>   non-uniformly scaled primitive shades correctly with no further work. Do **not** try to
>   transform the analytic normals; they are discarded.
> - **It cannot break determinism**, because `_fmt` snaps every coordinate to the printed precision
>   *after* the transform, and the weld key is built from that same printed form.
>
> **Fallback if the build lane declines:** every piece below marked **`[T]`** is the only one that
> needs it, and each can be built from `add_quad` directly at the cost of hand-written vertex
> maths. Nothing else in the kit is blocked either way.

---

### 6. Core set — used by both maps

Grid: **2.0 × 2.0 cells in XZ.** Every piece's origin is at the **centre of its footprint with its
base at `y = 0`**, so a `GridMap` places it with no per-piece offset and a map root can be moved
vertically in one edit. Heights step in **0.5**.

> ⚠️ **`Main.tscn`'s floor top is at `y = +0.5`, not `y = 0`** (B-82 — two docs say otherwise and
> both are wrong). Kit pieces are authored base-at-zero regardless; **`Eskinita.tscn` puts its own
> floor top at exactly `y = 0`** so that the documented convention becomes true where it matters.

| Piece | Silhouette | Footprint × height | Tris | Materials | What it contributes |
|---|---|---|---|---|---|
| `road_tile` | Flat slab | 2 × 2 × 0.06 | 12 | `ENV_ASPHALT` | The base surface. Deliberately the dullest value in the set so props read against it. |
| `road_tile_line` | Slab + centre dash | 2 × 2 × 0.07 | 24 | `ENV_ASPHALT`, `PANEL` | A dash at `y=0.062`, 1.2 × 0.10. Lane markings are the board's Metro reference, and they give the eye scale on an otherwise featureless plane. |
| `kerb_tile` | Low raised edge | 2 × 0.35 × 0.15 | 12 | `ENV_CONCRETE` | Separates road from walkable edge. The cheapest depth cue in the kit — **build it before anything decorative.** |
| `gutter_tile` | Slab with a channel | 2 × 2, channel 0.35 w × 0.12 deep | 36 | `ENV_ASPHALT`, `ENV_CONCRETE_DARK` | Three rect extrudes (road / channel floor / far lip). The dark line along a kerb is what makes a street look drained and lived-in. |
| `wall_plain` | Flat panel + base skirt | 2 × 0.25 × **3.0** | 24 | `ENV_CONCRETE`, `ENV_CONCRETE_DARK` | Skirt is the bottom **0.4** in `ENV_CONCRETE_DARK` — a damp course. One extra extrude turns a grey rectangle into a Manila wall. Tier: boundary. |
| `wall_corrugated` | **Zigzag GI sheet** | 2 × 0.10 × **2.4** | ~120 | `ENV_GI_SHEET`, `ENV_RUST` | **The single most Filipino-reading piece in the set — build it first.** Outline is a closed zigzag: 11 ridges across 2.0 (period 0.182, amplitude 0.05) forward, 11 back → 22 points → 84 tris. Plus a 0.3-tall `ENV_RUST` band at the base (+36). Tier: boundary. |
| `wall_corrugated_leaning` **`[T]`** | Same sheet, 6° off vertical | 2 × 0.10 × 2.4 | ~120 | as above | One tilted bay every fourth panel. Nothing says "not a level editor" faster than a wall that is not plumb. |
| `post_electric` | Square post + cross-arm + wire | 0.22 × 0.22 × **4.5** | ~70 | `ENV_WOOD_DARK`, `INK` | Post (12) + cross-arm 1.6 × 0.14 × 0.14 at `y=3.8` (12) + 3 insulator nubs (12) + an 8-quad catenary wire ribbon, 0.03 wide, sagging 0.5 over a 6-unit span (32). **Wires are `add_quad` ribbons, not tubes** — no generator change needed, and at distance a ribbon is indistinguishable from a cable. Tier: boundary/overhead. |
| `laundry_line` (*sampay*) | Two posts, a line, hung cloth | 4.0 span × **2.4** | ~90 | `ENV_WOOD_DARK`, `ENV_TARP`, `HIGHLIGHT`, `IMPACT`→**no**, use `ENV_RUST` | Posts (24) + catenary (32) + 5 garments as flat 0.35 × 0.5 quads at seeded alternating 4°/−7° tilts (40). Carries the Barong Barong reference into Eskinita. Strung **overhead across** the alley, never along it. |
| `bollard` | Capped cylinder | r 0.10 × **0.85** | 96 | `ENV_CONCRETE`, `HIGHLIGHT` | `add_revolve`, 16 segments, 4-point profile with a domed cap. One `HIGHLIGHT` band at `y=0.6`. Tier: interior — the tallest thing allowed loose in play. |
| `crate_stack` | 3 stacked boxes, askew | 0.7 × 0.7 × **0.95** | 36 | `ENV_WOOD` | 0.6³ / 0.55³ / 0.5³ at seeded yaws `+8° / −12° / +3°` from a `const` array. **Askew is the whole point** — three axis-aligned boxes read as programmer art. Tier: interior. |
| `tire` | Flat-lying torus | r 0.42 × **0.22** | 160 | `ENV_RUBBER`, `INK` | Lying flat, so it *is* a Y-axis revolve — 16 segments, 6-point profile (outer 0.42, inner 0.18). Stack two for 0.44. Tier: interior. |
| `monobloc_chair` | White plastic stacking chair | 0.46 × 0.46 × **0.89** | ~80 | `CARD` | Seat 0.42 × 0.42 × 0.06 at `y=0.44`, back 0.42 × 0.06 × 0.45, four 0.05 legs. **On the board's Metro reference explicitly**, and instantly recognisable to any Filipino judge. Tier: interior. |

---

### 7. Eskinita set

| Piece | Silhouette | Footprint × height | Tris | Materials | What it contributes |
|---|---|---|---|---|---|
| `sari_sari_store` | Shopfront: counter, barred window, awning | 2 × 1.0 × **2.6** | ~220 | `ENV_CONCRETE`, `ENV_WOOD`, `INK`, `ENV_TARP`, `HIGHLIGHT` | Body (12) + counter shelf 2.0 × 0.4 × 0.08 at `y=0.9` (12) + window recess 1.2 × 0.8 in `INK` (12) + **5 vertical bars** 0.04 (60) + flat awning 2.4 × 0.7 × 0.08 at `y=2.1` (12) with three `HIGHLIGHT` stripes (36) + a hanging sachet strip as 6 quads (24). **The narrative centre of the map.** A wall with a counter in it is a street; a wall without one is a corridor. Tier: boundary. |
| `building_block_a` | Plain mass, banded | 4 × 3 × **6.0** | 40 | `ENV_CONCRETE`, `ENV_CONCRETE_DARK`, `INK` | Body + one horizontal band + 6 window rects as flat `INK` quads inset 0.01. **Windows are painted, not modelled** — at Layer 2 distance a hole and a dark rectangle are the same image for a tenth of the cost. |
| `building_block_b` | Taller, narrower | 4 × 3 × **8.0** | 40 | as above | Same construction, different proportion, `ENV_CONCRETE_DARK` body. Two masses at two heights is enough to make a skyline that never repeats visibly. |
| `tricycle` **`[T]`** | Motorcycle + sidecar + roof | 2.0 × 1.2 × **1.25** | ≤ 300 | `ENV_RUST`, `ENV_GI_SHEET`, `ENV_RUBBER`, `HIGHLIGHT` | Silhouette grade — read from 4 units, never inspected. Sidecar box + GI roof + frame tubing as boxes + 3 upright wheels (r 0.28, 12 segments, `[T]`). **Waist-cover tier at 1.25**: boundary or deliberate cover only, never scattered in play. The one piece that makes the alley a *Philippine* alley rather than any alley. |
| `oil_drum` | Capped cylinder | r 0.30 × **0.90** | 96 | `ENV_RUST`, `INK` | 16-segment revolve, two rim ridges. Interior tier, and the cheapest legal piece of cover in the set. |
| `jeepney_lane_decal` | Hazard footprint | 4 × 12 × 0.01 | 12 | `IMPACT` at 35% alpha | Marks the `HazardZone` on the floor. **The hazard exists in code and is currently a pink sphere at (5, 0.5, 5) with nothing in the map motivating it** — this is what motivates it. Placement and the collider are 2.2's; only the decal mesh is 2.1b's. |

---

### 8. Bayan Plaza set

| Piece | Silhouette | Footprint × height | Tris | Materials | What it contributes |
|---|---|---|---|---|---|
| `plaza_tile` | Flat slab, scored | 2 × 2 × 0.06 | 24 | `ENV_CONCRETE`, `PANEL` | A 0.03-wide inset score line on two edges. Slab joints give a plaza its scale the way lane markings do a road. |
| `bench` | Slatted seat + back | 1.8 × 0.45 × **0.85** | ~70 | `ENV_WOOD`, `ENV_CONCRETE_DARK` | Three seat slats + two back slats on two concrete legs. Slats, not a solid box — the gaps are the whole read. Tier: interior. |
| `planter` | Box + foliage mass | 1.2 × 1.2 × **1.10** | ~40 | `ENV_CONCRETE`, `ENV_FOLIAGE` | Box to 0.5, a low 4-sided foliage mass above. Waist tier — placeable as cover. |
| `flagpole` | Slim pole + flag | r 0.07 × **5.0** | ~70 | `PANEL`, `ENV_WOOD_DARK` | 12-segment revolve + a 2-quad flag. Vertical punctuation; a plaza without one reads as a car park. |
| `tree` | Trunk + bulged canopy | r 1.4 × **4.2** | ~230 | `ENV_WOOD_DARK`, `ENV_FOLIAGE` | Trunk revolve (r 0.16 × 1.8, 8 seg, 32) + canopy revolve, 16 segments, 5-point bulged profile (128). |
| `tree_far` | Same, one value darker | r 1.4 × **4.8** | ~230 | `ENV_WOOD_DARK`, `ENV_FOLIAGE_DARK` | **Exists solely so the tree ring has two layers.** The board rings Province with depth, and depth here is a second colour, not a second row. |
| `church_facade` | Arched door, rose window, cross | 6 × 1.5 × **8.0** | ≤ 400 | `ENV_CONCRETE`, `ENV_WOOD_DARK`, `INK` | Body (12) + a 6-segment arched doorway outline (~40) + a 12-gon `INK` rose window (44) + pediment + cross (~40). **One instance, on the boundary, on the long axis.** It is the landmark that tells a player which way they are facing — worth more than any three clutter pieces. |
| `basketball_ring` | **Backboard, hoop, post** | 1.4 × 0.5 × **3.35** | ~200 | `ENV_WOOD`, `PANEL`, `ENV_CONCRETE` | **MANDATORY — it *is* the Philippine plaza.** Post (r 0.12 × 3.05, 12 seg, 96) + plywood backboard 1.2 × 0.9 × 0.06 (12) + a `PANEL` border rect (12) + hoop as a **horizontal** revolve torus, r 0.23, tube 0.02, 12 segments (~72), rim at `y = 3.05`. Boundary tier. If exactly one piece of this set ships, ship this one. |
| `carabao` | Standing bovine silhouette | 2.2 × 0.9 × **1.5** | ≤ 300 | `ENV_CONCRETE_DARK`, `INK` | **Optional, and named here so it is not silently dropped** — the GDD asks for a wandering carabao. Static prop only; "wandering" is animation and is out of scope for the whole kit. **Cut this before cutting anything else in §8.** |

---

### 9. Field markings — and the throw-range maths behind them

Both round-win modes stay in equal development, and each needs a different thing from the floor:
**Option B needs a legible base circle**, and **Option A needs the dent states to read**, which
means the lata must be lit and unoccluded where it stands. Both are served by the same layout.

| Piece | Geometry | Tris | Material | Notes |
|---|---|---|---|---|
| `base_circle_decal` | Annulus, **1.4 outer diameter** (resized 2026-07-28 from 3.0, which was drawn around the pre-rescale 1.12 m can), ring width 0.15, at `y = 0.02` | 96 | `HIGHLIGHT` | 24-segment flat ring. `HIGHLIGHT`'s documented use is literally "base-circle decal". 1.4 outer against a 0.20-wide lata gives the taya a readable zone to defend without the ring reading as a dinner plate. |
| `throwing_line_decal` | Bar, 8.0 × 0.12, at `y = 0.02` | 12 | `PANEL` | One per side, at **6.0 units from the base-circle centre.** |
| `team_side_decal` | Bar, 6.0 × 0.08, at `y = 0.02` | 12 | `PANEL` at 40% alpha | Marks each team's half. Subordinate to the throwing line — thinner and fainter on purpose. |

#### Why 6.0, and a tuning defect it exposes

Computed from the committed throw profiles, with `CharacterBase.GRAVITY = 20.0` (**not 9.8** — this
matters, and every earlier estimate that assumed otherwise is wrong by a factor of two) and a
release height of **1.248** (the `HandPoint` measured at `+0.448` above a capsule centre that is
`0.8` above the feet):

| Profile | `launch_speed` | `arc` | `gravity_scale` | **Max range at full charge** | Charge needed for a 6.0 line |
|---|---|---|---|---|---|
| `throw_default` (every Prop today, per B-76) | 17.0 | 14° | 1.0 | **10.13** | ~69% |
| `throw_bagsak` | 15.0 | 30° | 1.2 | **9.89** | ~73% |
| `throw_flick` | 23.0 | 5° | 0.75 | **12.90** | ~53% |
| `throw_bakya` | 14.0 | 12° | 1.0 | **7.23** | ~87% |

**6.0 is chosen so the profile that every Prop actually uses today throws at a comfortable ~69%
charge** — enough headroom to arc over a defender, short of the ceiling where charge stops
mattering.

> **✅ FIXED 2026-07-28 (checklist 4.4a).** `throw_bakya`'s maximum range used to be **4.81 units,
> less than half of every other profile** — `gravity_scale 1.6` combined with `arc_angle_deg 8.0`
> was heavy *and* flat enough that it fell out of the air almost immediately, and it could not
> reach any throwing line the other three could. Retuned to `arc_angle_deg 12.0` /
> `gravity_scale 1.0` (launch_speed unchanged at 14.0, still the slowest of the four): new max
> range **7.23**, needing ~87% charge for the 6.0 line — reachable, and still the shortest-range
> profile of the four by identity (heavy, close-range knockdown) rather than by being broken. It
> had never been felt before this fix because nothing had ever selected it (B-76: `PROP_ABILITY`
> was `quick_stand.tres` for every Prop, so all three throw identities were unreachable in the
> running game).

**A second consequence for 2.2, worth stating explicitly:** with every real exchange happening
inside about 13 units, a 40 × 40 arena is larger than the mechanic needs. §4's inward dressing is
the answer that costs nothing — narrow the *read* to a 16-wide alley and leave the arena's numbers
alone until a human has played 0.4.

---

### 10. Skyboxes

`Main.tscn` ships `background_mode = 1` (flat colour `#87BAE6`) and **there is no `Sky` resource
anywhere in the project.** Per-map skyboxes are new work, not a rewire, and each must be verified
*attached to its own map* rather than left on the default.

| Map | Sky | Build |
|---|---|---|
| **Eskinita** | Hazy city — pale grey-blue at the horizon, slightly deeper overhead | `ProceduralSkyMaterial`. `sky_horizon_color` `#c8d0d8`, `sky_top_color` `#8fa8bd`, `ground_horizon_color` `#b7b2a6`. Low `sky_curve` for a flat, smoggy gradient. |
| **Bayan Plaza** | Blue sky, cumulus | `ProceduralSkyMaterial`, `sky_top_color` `#4a8fd0`, `sky_horizon_color` `#cfe4f5`. Clouds only if a `NoiseTexture2D` stays deterministic — **a seeded noise, or none.** Do not ship a cloud layer whose seed churns the repo. |

**Do not add a `Camera3D` to a map scene.** That is the violation A-2 was written to delete and it
caused B-03. Person → FPP, Prop → TPP, derived from `is_person`, no exceptions.

---

### 11. Build order for 2.1b

Ordered by how much read each piece buys per triangle. **If 2.1b runs out of time, stop at a phase
boundary and say so** — every phase below leaves a coherent map.

1. **`wall_corrugated`, `kerb_tile`, `road_tile`, `road_tile_line`.** A dressed alley floor and a
   GI-sheet boundary. This alone stops the arena reading as a grey box.
2. **`base_circle_decal`, `throwing_line_decal`.** The game is named after a can in a circle.
   Supersedes 0.3's temporary decals.
3. **`post_electric`, `laundry_line`.** The overhead layer. Highest read-per-triangle in the kit.
4. **`sari_sari_store`.** The narrative centre.
5. **`building_block_a/_b`, `wall_corrugated_leaning`.** Depth and irregularity.
6. **`bollard`, `crate_stack`, `tire`, `monobloc_chair`, `oil_drum`.** Interior clutter.
7. **`tricycle`, `jeepney_lane_decal`.** Character and hazard motivation.
8. **§8, Bayan Plaza** — and within it, `basketball_ring` first. It is the only mandatory piece.

---

### 12. Acceptance for 2.1b

- `godot --headless -s tools/models/generate_all.gd` **twice**; `git status` clean after the second.
- Every piece ≤ 400 triangles. Report the actual count per piece in the commit body.
- Convex collision per piece.
- **Every kit piece is emitted as `assets/models/env_<piece>.obj`.** The `env_` prefix is not
  cosmetic — it is what makes the next check scopeable, and it keeps 26 new files from burying the
  five prop meshes in the same directory.
- **No `#F87020` and no `#0080E8` in any emitted kit `.mtl`.** Verify by grep, not by eye:
  ```bash
  grep -rnE '0\.97255 0\.43922 0\.12549|0\.00000 0\.50196 0\.90980' assets/models/env_*.mtl
  ```
  Expect **no output**. `Kd` is written as floats, and those two lines are exactly `OFFENSE` and
  `DEFENSE`.
  > ⚠️ **Scope this to `env_*` and nothing wider.** `lata*.mtl` legitimately contains the `DEFENSE`
  > line — the can is the *defending* side's prop and the rule is about **environment** geometry.
  > A grep over all of `assets/models/` fails on the lata and tells you nothing. (Checked: it does,
  > on all four lata variants.)
- **Screenshots.** `godot --path . tools/render_probe.tscn --quit-after 400 --resolution 1280x720
  -- match <dir>`, run **without `--headless`**. A design-lane claim with no picture is not
  evidence; this project has shipped four geometry bugs that every headless check passed.
- All six commands in `Concurrency_Protocol.md` §8 before merging.

---

### 13. Handed to other lanes — nothing here is the design lane's to write

| Item | Lane | Where it is recorded |
|---|---|---|
| **2.1b-0** — `transform` parameter on `add_revolve` / `add_extrude` | 🔧 Build (`obj_writer.gd`) | §5 above, and `Checklist.md` 2.1b |
| **2.1b** — generate the kit from this document | 🔧 Build | `Checklist.md` |
| **0.6** — carried-scale the tsinelas | 🔧 Build (`character_visual.gd`) | `Checklist.md` 0.6, `Handoff.md` §0.11 |
| **0.7 / B-82** — floor top is `y = +0.5`; units spawn inside the slab | 🔧 Build (`Main.tscn`, shared, locked) | `Checklist.md` 0.7, B-82 |
| ~~**B-81**~~ — tsinelas sole was `DEFENSE` blue on an offence-only unit | 🎨 Design | **FIXED 2026-07-28**, verified by render |
| **B-83** — boundary colliders at `±40` around a `±20` floor | 🎨 Design, inside 2.2 | B-83, §4 above |
| ~~**4.4a**~~ — `throw_bakya` max range was 4.81 units | 🔧 Build (tuning) | **FIXED 2026-07-28**, §9 above, `Checklist.md` 4.4a |
| Spawn-point *reading* logic (`main.gd` prefers map markers) | 🔧 Build | `Checklist.md` 2.2 |
| `HazardZone` slow-zone behaviour | 🔧 Build | 2.2 places it; Build owns what it does |


---


<a id="part-4"></a>

# Part 4 — Map art direction (historical brief)

*(was `docs/Art_Direction.md`)*

## Environment Art Agent Brief — the maps

**Run this on: Opus 5, high effort — this is a design-judgement task, not a code task.**
The hard question here is *"does this read as a Philippine side street"*, not *"does this scene
load"*. It is the single biggest visual lever on the submission and one of only four items on the
whole remaining plan routed to Opus.

**Lane:** 🎨 Design. **Worktree:** `.worktrees/design`, branch `art/<task>` off `integration`.
**Checklist items owned:** ~~**2.1a**~~ **done — see below**, **2.2** (Eskinita).
**Paste-ready opener:** [`Agent_Prompts.md`](Agent_Prompts.md) → 🎨 Design lane.

> ### ✅ 1.2 and 2.1a are closed (2026-07-28)
>
> - **1.2 · prop scale** — decided: props stay hero-scaled as units, the tsinelas scales to `0.32`
>   only while `CARRIED`. Reasoning, measurements and the three rejected alternatives are in
>   `Handoff.md` **§0.11**. §7 of this brief stated the fork; it is now answered, and the
>   implementation is checklist **0.6** on the build lane.
> - **2.1a · kit art direction** — delivered as
>   **[`Art_Direction.md`](Art_Direction.md)**. Read that instead of re-deriving §5's
>   suggested piece list; it audits and supersedes it. It also carries the Metro/Eskinita naming
>   reconciliation §2 asks for, the `ENV_*` palette, the boundary technique, the measured
>   **1.25-unit FPP eye height** that tiers every piece by height, and three defects found on the
>   way (B-81, B-82, B-83).
>
> **What is left of this brief for the next agent: 2.2, Eskinita.**

---

### 0. The one-paragraph reason this matters most

The systems on this project are in good shape. What a judge actually sees today is **one 40×40 grey
box**. Not a stylised arena — a literal untextured slab with a beige `BoxMesh` floor, four
**invisible** collision walls, no sky, no props, no markings, and a hazard zone that is a
translucent pink cylinder sitting at (5, 0.5, 5) for no reason the map motivates. Everything else
on the checklist improves a game that still looks like a prototype. This item is what stops it
looking like one.

---

### 1. Read these first, in this order

1. **[`Checklist.md`](Checklist.md)** — the single source of truth for state and order. Your items
   are 2.1a and 2.2.
2. **[`Concurrency_Protocol.md`](Concurrency_Protocol.md)** — a Sonnet build lane is working the
   same repo concurrently. §2 (path ownership), §3 (the shared-file lock), §6 (`.tscn` conflicts),
   §7 (the `.import` UID trap), §8 (the smoke gate).
3. **`Handoff.md`** §0.10 (the last audit — what is actually true right now), §1–§2 (frozen), §4's
   `M-6`/`M-7` entries (the existing plan for this work — audit it, don't assume it).
4. **`Dev_Plan.md`** §0 (standing directives, which override the GDD), §4.1 (what the moodboard
   actually specifies), §4.2 (design tokens), §4.6 (round flow).
5. **`Art_Direction.md`** — the `M-` block's brief. It carries the moodboard record and the
   mesh-generator traps you will hit.
6. **Then open the scenes and the generator.** `scenes/main/Main.tscn`,
   `tools/models/generate_all.gd`, `tools/models/obj_writer.gd`. This repo has a documented history
   of docs claiming things the code contradicts in both directions — the last audit found four.
   Verify; do not inherit.

**The moodboard is the spec and it is not in the repo.** It is Harry's Canva board. **If it has not
been attached to your chat, stop and ask for it** — a description of the board is not the board.

---

### 2. What the moodboard actually asks for

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

### 3. The boundary — the item most likely to be got wrong

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

### 4. Traps already found in this code — read before you start

1. **`CharacterBase`'s origin is the CENTRE of a 1.6-unit capsule, so a model's feet are at
   `-0.8`, not `0`.** Four separate nodes were placed against an imagined character standing on
   `y = 0` and all four were wrong: the FPP camera pivot (B-78), the ground ring (B-80), the
   floating tag, and the hand carry point (B-79). **If you place anything relative to a character,
   check this first.**

   > ⚠️ **CORRECTED 2026-07-28 — the paragraph that used to be here was wrong. See B-82.** It
   > claimed `Main.tscn`'s `Floor` has its **top surface at `y = 0`** and extends to `-1`. It does
   > not. `Floor` and its `CollisionShape3D` carry **no transform**, and the shape is a
   > `BoxShape3D` of `(40, 1, 40)` centred on the origin, so the slab spans **`y = -0.5 … +0.5`**
   > and its **top surface is `y = +0.5`**. Anything placed against the old claim sinks half a
   > metre. The same error consequently put all four units at `y = 1.0`, which is a capsule floor
   > of `0.2` — 0.3 units *inside* the slab. Fixing the scene is checklist **0.7** (build lane,
   > `Main.tscn` is shared). **`Eskinita.tscn` puts its own floor top at exactly `y = 0`** so the
   > convention every other document assumes becomes true where it matters.

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

### 5. Scope

#### Yours

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

#### Explicitly NOT yours

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

### 6. Acceptance

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

### 7. The decision you may need to make first

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

### 8. Non-negotiables, restated inline

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

### 9. Reporting contract

Say what you changed and why. **Screenshot everything visual.** Separate what you verified by
running from what is only reasoned about. Say plainly what you did not get to and why — this
project has an established, enforced norm against silently narrowing scope. If something in these
docs is wrong, say it is wrong instead of building around it; the last three passes each found
stale claims, and saying so is more valuable than working around them.


---

---

# Part 5 — Live demo, trailer and demo video (checklist 6.2)

*(was `docs/Art_Direction.md`)*

Creative direction, which is why it lives with the rest of it. **This part is live** — it is the running order for demo day and the beat sheet 6.3 and 6.4 are captured against.

## 6.2 · Live-demo script, trailer beat sheet, demo-video outline

**Owner: 🎨 Design (Opus). Executes into 6.3 (trailer) and 6.4 (demo video), which are Sonnet
capture-and-edit passes against this document.**

This is the shot list and the running order. It is deliberately written against **what the build
actually does today**, not against the checklist's intentions — every mechanic named below was
read out of the code or seen in a render, and everything unverified is marked as such.

> ### The one-line thesis
>
> **Tumbang Preso is a playground game about a can, a slipper, and the moment you have to run for
> it.** Every beat below exists to land that sentence on someone who will never play the build.

---

---

### 0. Design pillar — this is a *friendslop*

**Stated by the human, 2026-07-28, and it outranks realism everywhere below.**

Tumbang Preso is a chaotic, physical party game you play with friends in the same room or on the
same wifi. It is not a simulation and it is not trying to be tasteful. When a decision is between
*correct* and *funny*, **take funny** — a hopping tin can is the right answer, a physically
accurate one is not.

What that actually changes, concretely:

- **Permissive over strict.** Every unit gets every verb it plausibly could. Jump went on the
  Prop as well as the Person for exactly this reason: nobody needed to justify why a lata can
  jump, somebody would have had to justify why it cannot.
- **Readable over subtle.** Chunky silhouettes, loud impacts, saturated colour. This is why the
  render pass pushed saturation up rather than going for a tasteful filmic grade.
- **Recoverable over punishing.** A player who is confused should still be laughing. Downed
  states, retrieval scrambles and role swaps all exist to keep everyone in the round.
- **Where it does NOT apply:** the colour rule (orange = offense, blue = defence) and the
  proportion audit in §1. Those are legibility, not taste — a game can be silly and still has to
  be readable at arena distance.

### 0. What is actually demoable today

Verified by running the build on 2026-07-28.

| Thing | State | Notes |
|---|---|---|
| Main menu → map picker → match | ✅ works | Two maps selectable |
| **Eskinita** (dressed alley) | ✅ renders | 30-piece kit, road markings, wires, sari-sari frontage |
| **Bayan Plaza** | ⚠️ built, rendered, **never played** | Checklist 2.4, `[~]` |
| Spawns as two team pairs at opposite ends | ✅ verified | From the map's own `SpawnPoints` |
| Person = FPP, Prop = TPP | ✅ verified | Self-hide works; camera at 1.25 above feet |
| Restyled Persons (2.3) | ✅ verified by render | Read apart at 20 units, no orange/blue |
| Pick up + carry the tsinelas | ✅ verified | Scales to hand size, tracks the arm bone |
| Can: 4 dent states, downed tilt | ✅ in code | Not seen in a live hit |
| Hit flash, impact burst, hitstop | ✅ in code (hitstop v4.30) | Not seen in a live hit |
| HUD: Bo5 pips, role panels, timer, LATA + YOU cards | ✅ renders | |
| Bo5, first to 3, 90 s rounds | ✅ in code | `WINS_NEEDED = 3`, `ROUND_TIME = 90.0` |
| Role swap every round (orange↔blue) | ✅ in code | Intermission card is still placeholder |
| Both win modes (A dents / B seal) | ✅ both wired | Selectable at the menu |
| 2v2 over ENet LAN | ⚠️ **loopback only** | 6.1, real wifi never tested — 🧑 human |
| A runnable `.exe` | ❌ **does not exist** | 5.1, export templates never installed — 🧑 human |
| Anyone having played a full match | ❌ **never** | 0.4 — every tuning number below is a guess |
| Audio | ❌ none | No owner assigned |

**Read that table before promising anything to anyone.** Three of the four rows that a live demo
depends on most — a real LAN test, an `.exe`, and one human playthrough — are human-gated and
none of them has happened.

---

### 1. The live demo — 6 minutes, and why 6

Judges at a booth give you the length of their patience, not the length of your slide deck. Six
minutes is two minutes of watching, three of playing, one of questions. **A full Bo5 at 90-second
rounds is up to 7.5 minutes of match alone**, so the demo must never try to play one out.

#### ⚠️ Decision this needs from a human — flagged, not taken

**Build a demo preset with `ROUND_TIME = 45.0` and `WINS_NEEDED = 2`.** A best-of-3 at 45 seconds
is a complete arc — swap, comeback, decider — inside four minutes, and it shows the role swap
*twice*, which is the mechanic nobody understands from a screenshot. At the shipped 90/3 the
audience sees one round and leaves before the swap.

This is not a balance change; it is a presentation preset, and it must not be the submitted
default unless 0.4 says otherwise. **Left undone deliberately — it touches
`scripts/systems/`, which is 🔧 Build's, and it is a judgement call about the submission, not
about art.**

#### Running order

| # | Beat | Time | What the operator does | What it proves |
|---|---|---|---|---|
| 1 | **Cold open on the alley** | 0:00–0:30 | Sit on the Eskinita spawn view. Do not move. Say the thesis line. | The game has a *place*. This is the single strongest first impression the build has. |
| 2 | **The four roles, out loud** | 0:30–1:15 | Point at the HUD: orange panel, blue panel, Bo5 pips, the LATA card. "Orange attacks, blue defends, and it swaps every round." | The colour language. Judges will otherwise assume orange/blue are teams. **It is the single most-misread thing in the build.** |
| 3 | **One throw, in first person** | 1:15–2:00 | Person picks up the tsinelas, charges, throws, hits the can. Let the hitstop land. | The core verb. FPP + the slipper + impact in one motion. |
| 4 | **Hand over the controls** | 2:00–4:30 | Two judges, two devices, one round. Operator plays a Prop so a human is never left without an opponent. | It is a *game*, not a diorama. This is the beat that wins or loses the booth. |
| 5 | **The swap** | 4:30–5:00 | Let the round end. Narrate the role swap as the colours flip. | The design idea. Tumbang preso is a game where *everyone* eventually has to be the taya. |
| 6 | **Second map, 15 seconds** | 5:00–5:15 | Quit to menu, pick Bayan Plaza, stand still. Do not play it. | Content breadth without risking an unplayed map. |
| 7 | **Questions** | 5:15–6:00 | | |

**Beat 6 is deliberately a flyby.** Bayan Plaza has never been played by anyone (2.4 is `[~]`).
Showing it standing still is honest and safe; playing it in front of judges is a bet on untested
ground.

#### Operator rules

1. **Never demo from a debug build.** The debug switcher's overlay (`F1–F4`, `Tab`, `F5`, `F6`)
   is visible at the bottom of the screen in the current build and reads as an unfinished
   prototype. See §3 for the exception.
2. **The operator always plays a Prop, never a Person.** Props are TPP, so the operator can see
   the whole arena and shepherd a lost judge. A Person in FPP cannot see what a confused player
   is doing.
3. **Never restart mid-crowd.** If it breaks, cut to the fallback ladder without commentary. A
   silent switch reads as a planned segment; a visible recovery reads as a bug.
4. **Say "taya" out loud at least once.** It is the game's actual cultural hook and it costs
   nothing.

---

### 2. Controls card — print this and put it on the table

Read out of `project.godot`. Every player index has its own action set (`_p1` … `_p4`).

| Action | Input | Notes |
|---|---|---|
| Move | `move_left/right/up/down` per player | P1 WASD, P2 arrows in the local harness |
| **Grab / pick up** | `grab` | Picks up a loose tsinelas |
| **Throw** | `special_ability` | Charged — hold and release |
| **Bump / shove** | `bump` | The melee shove |
| **Guard / dash** | `guard_dash` | Contextual by role |

**The moodboard's aiming arc and the lata reset channel are drawn on the role cards but are NOT
in the build** (B-45, B-46, open decisions). **Do not narrate them.** Promising a mechanic a judge
then cannot find is worse than not mentioning it.

---

### 3. Failure drills — the fallback ladder

The checklist calls demo-day reliability "arguably the most important feature". This is that
feature. **Rehearse the ladder before the event, in order, with a stopwatch.** Every rung must be
reachable in under 20 seconds.

| Rung | Situation | Action | Recovery time |
|---|---|---|---|
| **0** | Everything works | Full 2v2 on four devices | — |
| **1** | One peer drops mid-match | **Finish the round.** Do not stop to explain. Narrate over it. | 0 s |
| **2** | A peer cannot rejoin | Quit to menu, restart the match with the operator covering the empty slot | ~15 s |
| **3** | LAN is unusable (venue wifi, AP isolation) | **Single machine, local 4-unit harness**, operator cycles units with `Tab` | ~20 s |
| **4** | The build will not run at all | **Play the trailer on loop.** Have it on the machine, not on a URL. | ~10 s |

#### ⚠️ Two things this ladder needs, neither of which exists yet

1. **Rung 3 depends on the local harness, which checklist 5.3 wants stripped before submission.**
   These two requirements are in direct conflict and nobody has noticed. **Recommendation: keep
   the local harness, gate it behind a launch argument rather than deleting it, and strip only
   the on-screen debug overlay.** That satisfies 5.3's real intent (the build must not *look*
   like a prototype) without removing the only fallback that does not need a network.
   **Flagged, not done — `scripts/` is 🔧 Build's lane and 5.3 is blocked on 0.4 anyway.**
2. **Rung 4 depends on the trailer existing (6.3), which depends on this document.** So the
   trailer is not just a submission asset; it is the demo's own safety net. Cut it early.

#### What happens today when a peer drops

**Unknown, and that is a finding.** There is no disconnect handling that anyone has demonstrated,
no bot to take over an abandoned unit, and no test has ever been run over a real network (6.1).
**Rungs 1 and 2 above are written as intentions, not as verified behaviour.** Someone must sit
down with two machines, pull the cable mid-round, and write down what actually happens. That is a
🔬 QA task and it should be filed before the trailer work starts.

---

### 4. Trailer beat sheet — 6.3, 1–2 minutes, loopable

**Target: 75 seconds.** Loopable means the last frame cuts to the first without a bump — so it
opens and closes on the same empty-alley composition.

`tools/arena_camera.gd` was preserved for exactly this: 100 lines of working broadcast-framing
maths. Use it for the spectator shots rather than hand-flying a camera.

| # | Beat | Length | Shot | Audio bed |
|---|---|---|---|---|
| 1 | **Empty alley** | 0:00–0:06 | Slow push down Eskinita. No UI. Hold the emptiness. | Street ambience alone |
| 2 | **The can, alone in its circle** | 0:06–0:12 | Low, close, the lata standing in the base decal | A single tin *tink* |
| 3 | **Title** | 0:12–0:17 | Logo lockup over the alley, held | Music enters |
| 4 | **Feet, then the slipper** | 0:17–0:24 | Ground-level: a Person runs past, grabs the tsinelas | Rhythm starts |
| 5 | **The throw** | 0:24–0:31 | FPP charge → release → **cut on the hitstop** | Beat drop on impact |
| 6 | **Can knocked down** | 0:31–0:38 | TPP: tilt, dents, impact burst, the scramble that follows | Music opens up |
| 7 | **Chase** | 0:38–0:50 | Spectator arc following a retrieval run down the alley | Peak energy |
| 8 | **THE SWAP** | 0:50–1:00 | Role swap: orange↔blue on the HUD, hard cut to the same players in opposite colours | Music drops to a single held note |
| 9 | **Bayan Plaza reveal** | 1:00–1:07 | One wide of the second map. Static. Beautiful. | Note sustains |
| 10 | **Empty alley again** | 1:07–1:15 | The beat-1 composition, logo re-forms, cut to black | Resolves into beat 1 |

**Rules for the cut**

- **Cut on impacts, not on the beat.** The game's rhythm is the *tink* of a can. Let the edit
  follow the game.
- **No UI in beats 1–7.** The HUD appears exactly once, in beat 8, because that is the beat where
  it is the point.
- **Never show a nameplate close enough to read "TeamAProp".** Placeholder strings on screen cost
  more credibility than a missing shot.
- **Nothing in the trailer may show a mechanic that is not in the build.** No aiming arc.

---

### 5. Demo video outline — 6.4, 3–5 minutes, narrated or captioned

**Target: 4:00.** This is the one a judge watches at a desk, alone, at 1.5×. Structure it so it
survives being skimmed.

| Section | Time | Content |
|---|---|---|
| **Hook** | 0:00–0:20 | The thesis line over the trailer's beat-1 shot. Name the street game. |
| **The premise** | 0:20–0:50 | Real tumbang preso in 20 seconds: a can, a slipper, a taya. Then: "we made it 2v2." **Lead with the Philippine Games angle — it is the brief.** |
| **A round, start to finish** | 0:50–2:10 | One uncut 45–80 s round with captions naming each beat as it happens. **Uncut is the point** — it proves the thing runs. |
| **The role swap** | 2:10–2:40 | Why it exists: everyone has to be the taya. This is the design argument. |
| **Both win modes** | 2:40–3:10 | Option A (dents) and Option B (seal) side by side. **Both are in equal development and the submission must show that.** |
| **Maps** | 3:10–3:30 | Eskinita and Bayan Plaza, one wide each. |
| **Circular-economy close** | 3:30–4:00 | The premise is literally about reusing everyday objects as play equipment. Land it, then the logo. |

**Captions, not narration, if there is any doubt about the audio.** A silent captioned video reads
as deliberate; a video with bad audio reads as rushed.

---

### 6. What must be true before capture starts

Do not begin 6.3 or 6.4 until all of these are true. Capturing against a build that then changes
means capturing twice.

1. **0.4 — someone has played a full Bo5.** Until then every number in the capture is unverified
   and the round you record may be unbalanced in a way that is obvious to a judge and invisible
   to us.
2. **4.1 — the round-beat polish.** Both 6.3 and 6.4 are blocked on it in the checklist, and the
   trailer's beats 5, 6 and 8 are *specifically* the hitstop, the impact burst and the role-swap
   card. Beat 8 currently has no animated card to cut to.
3. **The debug overlay is gone from the captured build** (see §3's flagged conflict).
4. **Nameplates read as intended strings**, not `TeamAProp`.
5. **A decision on audio.** There is none, and it has no owner. A trailer with no audio bed is a
   different edit from one with a bed — decide before cutting, not after.

---

### 7. Open items this document deliberately did not resolve

Flagged for a human, per the brief's rule that a design lane files questions rather than guessing.

| # | Question | Why it is not mine to take |
|---|---|---|
| 1 | Demo preset at `ROUND_TIME 45` / `WINS_NEEDED 2` | Touches `scripts/systems/` (🔧 Build) and changes what a judge experiences as "the game" |
| 2 | Keep the local harness as fallback rung 3 vs. 5.3's strip | Directly contradicts a checklist item; needs the human to pick |
| 3 | What actually happens when a peer drops | Needs 🔬 QA with two machines and a pulled cable. **Nobody has ever tested this.** |
| 4 | Audio — whether there is any, and who owns it | No owner assigned anywhere in the plan |
| 5 | Whether Bayan Plaza is shown at all | Depends entirely on whether 0.4 ever plays it |

