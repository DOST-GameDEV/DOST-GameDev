# Art plan — next stage (proportions, sets, props)

**🎨 Design lane. Written 2026-07-28 after the render pass that landed the painted facades,
the lighting rework and the rebuilt tsinelas.**

Everything below is measured, not estimated. The measurements come from the `.obj` vertex buffers
themselves, so they are the sizes the engine actually loads.

---

## 1. The proportion audit — this is the headline

**The environment is built correctly at 1 unit = 1 metre. The two hero props are not.**

| Asset | Height/length | Real object | Ratio | Verdict |
|---|---|---|---|---|
| Person (capsule) | **1.60** | a teenager, ~1.6 m | 1.00× | ✅ correct |
| monobloc chair | 0.89 | 0.85 m | 1.05× | ✅ |
| oil drum | 0.90 | 0.88 m (200 L) | 1.02× | ✅ |
| basketball ring | 3.85 | 3.95 m to board top | 0.97× | ✅ |
| bench / bollard / crate / tyre | — | — | ~1× | ✅ |
| **lata (the can)** | **1.12** | 0.12 m | **9.3×** | ❌ |
| **tsinelas** | **1.35** | 0.27 m | **5.0×** | ❌ |
| building block a / b | 6.0 / 8.0 | ~10 m for 3 storeys | 0.6–0.8× | ⚠️ *fixed this pass → 9.0 / 12.0* |
| electric post | 4.5 | 8–9 m | 0.5× | ⚠️ open |
| tricycle | 1.64 long | ~2.8 m | 0.6× | ⚠️ open |

**The single clearest way to see it:** the can is 1.12 m and the monobloc chair beside it is
0.89 m. *The can is taller than the chair.* Nothing about the set is wrong — the props are wrong,
and they are wrong by a factor of five to nine.

### Why it is like this, and why that reasoning has expired

`Handoff.md` §0.11 / checklist 1.2 decided the props stay "hero-scaled" and explicitly rejected
rescaling them, because prop size is entangled with `CharacterBase`'s collision capsule, hit
radii, grab radius, throw ranges and camera distance. That was a sound call **when the set was a
grey box** — there was nothing in frame to be out of proportion *with*. Now there is a dressed
street full of correctly-sized objects, and the props read as absurd against it.

### The target numbers

| Prop | Now | Target | Scale | vs Person | Real-life ratio |
|---|---|---|---|---|---|
| lata | 1.12 | **0.34** | 0.30 | 21% | 7% |
| tsinelas | 1.35 | **0.43** | 0.32 | 27% | 17% |

Both stay deliberately larger than life, because the moodboard's language is chibi exaggeration —
but 21–27% is *stylised*, where 70–84% is *broken*.

> ### The tsinelas number is not a guess, and this is the nicest fact in this document
>
> `character_visual.gd` already carries `TSINELAS_CARRY_SCALE = 0.32`, applied only while the
> slipper is CARRIED, and **0.32 × 1.35 = 0.432**. That number was arrived at independently, by
> rendering, because the full-size slipper filled a quarter of the FPP screen.
>
> So the carried slipper is **already exactly the right size**. The loose and flying ones are the
> outliers. Rebuild the mesh at 0.43 natively and `TSINELAS_CARRY_SCALE` becomes 1.0 and can be
> deleted, along with `_scale_while_carried()` and the `CARRY_SCALE_LERP` tween — a feature
> *removed* rather than added. `HAND_CARRY_OFFSET` must be re-measured afterwards; its own comment
> block says so and gives the method.

### Blast radius — why this is not a one-line change

The hard part is that **`CharacterBase.tscn` is shared by Persons and Props**, and its collision
capsule is `radius 0.4, height 1.6` for all of them. Shrinking the can's mesh to 0.34 leaves a
1.6 m invisible capsule around a 0.34 m object: it would block doorways it appears to fit through
and get hit by throws that visibly miss.

So the change is, in order:

1. **Per-unit collision.** `CollisionShape3D`, `Hurtbox`, `Hitbox` and `GrabArea` sized from the
   unit's role instead of baked once. 🔧 **Build** — `CharacterBase.tscn` (shared, needs the lock)
   plus `character_base.gd`.
2. **Rebuild the two prop meshes at the new scale.** 🎨 Design — `generate_all.gd`, one constant
   each. Trivial once step 1 exists.
3. **Re-measure `HAND_CARRY_OFFSET`** by the sampling method its comment documents. Delete
   `TSINELAS_CARRY_SCALE`. 🔧 Build.
4. **Resize the floor markings.** `base_circle_decal` is 3.0 m across because it was drawn around
   a 1.12 m can. Against a 0.34 m can it wants ~1.2–1.5 m. 🎨 Design.
5. **Retune throw range, hit radius and grab radius**, all of which were tuned by eye against
   oversized props. Note **4.4a** already flags `throw_bakya`'s max range as 4.81 units — less than
   half of every other throw — so this retune is owed anyway. 🔧 Build, and it needs 0.4 first.

**Do not start step 2 before step 1.** A correctly-sized can with a person-sized capsule is worse
than what is there now, because the error becomes invisible instead of obvious.

---

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

## 3. Next stage, in priority order

**A · Proportions (§1).** Biggest single credibility win available. Blocked on Build for step 1.

**B · Narrow the alley.** Eskinita's playable width is `x = ±8` — a 16 m road, which is a
boulevard, not an eskinita. A real side street is 3–5 m. The layout script already has `W = 8.0`
as one constant. **Do not change it blind:** it is arena scale, and `Environment_Kit_Spec.md` §4
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

## 4. Flagged for a human

1. **Item A is a cross-lane change and needs Build to move first.** Design cannot size a collision
   shape. If Build has no capacity, the fallback is to shrink only the *meshes* and accept
   mismatched collision — **I do not recommend it**, for the reason in §1.
2. **Item C reverses a documented decision** (M-6 step 3). Worth 30 seconds of your opinion.
3. **Item B changes arena scale**, which is a feel change, not an art change. It should not happen
   before somebody has played the current one (0.4).
