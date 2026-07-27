# Environment Kit Spec — checklist 2.1a

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

## 1. The two vocabularies, reconciled — read this before anything else

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

### Barong Barong is a dressing layer, not a third map — the argument the brief asked for

`Environment_Art_Agent_Brief.md` §2 says to treat Barong Barong as a stretch goal "unless you argue
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

## 2. The laws every piece obeys

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

### The height law — derived, not guessed

Measured this pass with `render_probe.gd`: the Person capsule is 1.6 tall and centred on the
character's origin, and `FppPivot` sits at `+0.45` in that local space. Standing on the ground, a
first-person Person's **eye is at `y = 1.25`**.

That single number tiers the whole kit, and `Environment_Art_Agent_Brief.md` §6 requires it ("an
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

## 3. Palette

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

## 4. The boundary — the thing most likely to be got wrong

The board's own annotation on the Metro map is the entire instruction:

> *"basically just add random assets on the edge that acts like a wall"*

### Where the boundary actually goes — corrects a live error

**B-83, found this pass.** `Main.tscn`'s `Bounds/Wall*` sit at `±41` with half-depths of 1, so
their inner faces are at **`±40`** — while the floor slab ends at **`±20`**. There is a 20-unit
ring of empty space on all four sides that the colliders do not enclose; a player runs off the
slab and falls past them to the `KillPlane`. The arena does not merely have *invisible* walls, it
has **no working boundary at all**.

**Eskinita's boundary geometry and its colliders both go at `±20`,** flush with the playable
surface, and `Main.tscn`'s `Bounds` node is deleted along with the grey box when 2.2 lands.

### How it is built

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

### The alley is narrower than the arena — and nothing about the arena changes

**Do not change arena scale in the same commit as arena art** (`Environment_Art_Agent_Brief.md` §3).
The floor stays 40 × 40. But an eskinita is a *narrow side street*, and the throw ranges measured in
§9 put every real exchange inside about 13 units.

So: **dress the boundary inward.** Keep the floor and the outer collider ring at `±20`, and build
the Layer 1 wall line at **`x = ±8`**, leaving a playable slot roughly **16 wide by 34 long**. The
strip between `x = ±8` and `x = ±20` is filled with Layer 2 and 3 dressing and is not walkable.
The arena's numbers are untouched, the alley reads narrow, and if 0.4 says it is too tight the fix
is moving a wall line, not rebuilding a map.

---

## 5. What the generator can and cannot do today — read before writing any `_build_*`

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

### The one generator change this kit needs — hand it to the build lane

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

## 6. Core set — used by both maps

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

## 7. Eskinita set

| Piece | Silhouette | Footprint × height | Tris | Materials | What it contributes |
|---|---|---|---|---|---|
| `sari_sari_store` | Shopfront: counter, barred window, awning | 2 × 1.0 × **2.6** | ~220 | `ENV_CONCRETE`, `ENV_WOOD`, `INK`, `ENV_TARP`, `HIGHLIGHT` | Body (12) + counter shelf 2.0 × 0.4 × 0.08 at `y=0.9` (12) + window recess 1.2 × 0.8 in `INK` (12) + **5 vertical bars** 0.04 (60) + flat awning 2.4 × 0.7 × 0.08 at `y=2.1` (12) with three `HIGHLIGHT` stripes (36) + a hanging sachet strip as 6 quads (24). **The narrative centre of the map.** A wall with a counter in it is a street; a wall without one is a corridor. Tier: boundary. |
| `building_block_a` | Plain mass, banded | 4 × 3 × **6.0** | 40 | `ENV_CONCRETE`, `ENV_CONCRETE_DARK`, `INK` | Body + one horizontal band + 6 window rects as flat `INK` quads inset 0.01. **Windows are painted, not modelled** — at Layer 2 distance a hole and a dark rectangle are the same image for a tenth of the cost. |
| `building_block_b` | Taller, narrower | 4 × 3 × **8.0** | 40 | as above | Same construction, different proportion, `ENV_CONCRETE_DARK` body. Two masses at two heights is enough to make a skyline that never repeats visibly. |
| `tricycle` **`[T]`** | Motorcycle + sidecar + roof | 2.0 × 1.2 × **1.25** | ≤ 300 | `ENV_RUST`, `ENV_GI_SHEET`, `ENV_RUBBER`, `HIGHLIGHT` | Silhouette grade — read from 4 units, never inspected. Sidecar box + GI roof + frame tubing as boxes + 3 upright wheels (r 0.28, 12 segments, `[T]`). **Waist-cover tier at 1.25**: boundary or deliberate cover only, never scattered in play. The one piece that makes the alley a *Philippine* alley rather than any alley. |
| `oil_drum` | Capped cylinder | r 0.30 × **0.90** | 96 | `ENV_RUST`, `INK` | 16-segment revolve, two rim ridges. Interior tier, and the cheapest legal piece of cover in the set. |
| `jeepney_lane_decal` | Hazard footprint | 4 × 12 × 0.01 | 12 | `IMPACT` at 35% alpha | Marks the `HazardZone` on the floor. **The hazard exists in code and is currently a pink sphere at (5, 0.5, 5) with nothing in the map motivating it** — this is what motivates it. Placement and the collider are 2.2's; only the decal mesh is 2.1b's. |

---

## 8. Bayan Plaza set

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

## 9. Field markings — and the throw-range maths behind them

Both round-win modes stay in equal development, and each needs a different thing from the floor:
**Option B needs a legible base circle**, and **Option A needs the dent states to read**, which
means the lata must be lit and unoccluded where it stands. Both are served by the same layout.

| Piece | Geometry | Tris | Material | Notes |
|---|---|---|---|---|
| `base_circle_decal` | Annulus, **3.0 outer diameter**, ring width 0.12, at `y = 0.02` | 96 | `HIGHLIGHT` | 24-segment flat ring. `HIGHLIGHT`'s documented use is literally "base-circle decal". 3.0 outer against a 0.68-wide lata gives the taya a readable zone to defend without the ring reading as a dinner plate. |
| `throwing_line_decal` | Bar, 8.0 × 0.12, at `y = 0.02` | 12 | `PANEL` | One per side, at **6.0 units from the base-circle centre.** |
| `team_side_decal` | Bar, 6.0 × 0.08, at `y = 0.02` | 12 | `PANEL` at 40% alpha | Marks each team's half. Subordinate to the throwing line — thinner and fainter on purpose. |

### Why 6.0, and a tuning defect it exposes

Computed from the committed throw profiles, with `CharacterBase.GRAVITY = 20.0` (**not 9.8** — this
matters, and every earlier estimate that assumed otherwise is wrong by a factor of two) and a
release height of **1.248** (the `HandPoint` measured at `+0.448` above a capsule centre that is
`0.8` above the feet):

| Profile | `launch_speed` | `arc` | `gravity_scale` | **Max range at full charge** | Charge needed for a 6.0 line |
|---|---|---|---|---|---|
| `throw_default` (every Prop today, per B-76) | 17.0 | 14° | 1.0 | **10.13** | ~69% |
| `throw_bagsak` | 15.0 | 30° | 1.2 | **9.89** | ~73% |
| `throw_flick` | 23.0 | 5° | 0.75 | **12.90** | ~53% |
| `throw_bakya` | 14.0 | 8° | 1.6 | **4.81** | ⛔ **impossible** |

**6.0 is chosen so the profile that every Prop actually uses today throws at a comfortable ~69%
charge** — enough headroom to arc over a defender, short of the ceiling where charge stops
mattering.

> **⛔ Finding, handed to the tuning lane — filed as checklist 4.4a.** `throw_bakya`'s maximum range
> is **4.81 units, less than half of every other profile.** `gravity_scale 1.6` combined with
> `arc_angle_deg 8.0` is heavy *and* flat, so it falls out of the air almost immediately. Bakya Bash
> cannot reach any throwing line the other three can use. **Do not design the map around this
> number** — it is far more likely a tuning bug than an intended identity. It has never been felt,
> because nothing has ever selected it (B-76: `PROP_ABILITY` is `quick_stand.tres` for every Prop,
> so all three throw identities are unreachable in the running game). Retune it at 0.5 or 4.4, then
> re-check this table.

**A second consequence for 2.2, worth stating explicitly:** with every real exchange happening
inside about 13 units, a 40 × 40 arena is larger than the mechanic needs. §4's inward dressing is
the answer that costs nothing — narrow the *read* to a 16-wide alley and leave the arena's numbers
alone until a human has played 0.4.

---

## 10. Skyboxes

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

## 11. Build order for 2.1b

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

## 12. Acceptance for 2.1b

- `godot --headless -s tools/models/generate_all.gd` **twice**; `git status` clean after the second.
- Every piece ≤ 400 triangles. Report the actual count per piece in the commit body.
- Convex collision per piece.
- **No `#F87020` and no `#0080E8` in any emitted `.mtl`.** Verify by grep, not by eye:
  ```bash
  grep -rniE '0\.9725|0\.4392|0\.1255|0\.5020|0\.9098' assets/models/*.mtl
  ```
  (`Kd` is written as floats — those are the components of the two forbidden colours.)
- **Screenshots.** `godot --path . tools/render_probe.tscn --quit-after 400 --resolution 1280x720
  -- match <dir>`, run **without `--headless`**. A design-lane claim with no picture is not
  evidence; this project has shipped four geometry bugs that every headless check passed.
- All six commands in `Concurrency_Protocol.md` §8 before merging.

---

## 13. Handed to other lanes — nothing here is the design lane's to write

| Item | Lane | Where it is recorded |
|---|---|---|
| **2.1b-0** — `transform` parameter on `add_revolve` / `add_extrude` | 🔧 Build (`obj_writer.gd`) | §5 above, and `Checklist.md` 2.1b |
| **2.1b** — generate the kit from this document | 🔧 Build | `Checklist.md` |
| **0.6** — carried-scale the tsinelas | 🔧 Build (`character_visual.gd`) | `Checklist.md` 0.6, `Handoff.md` §0.11 |
| **0.7 / B-82** — floor top is `y = +0.5`; units spawn inside the slab | 🔧 Build (`Main.tscn`, shared, locked) | `Checklist.md` 0.7, B-82 |
| **B-81** — tsinelas sole is `DEFENSE` blue on an offence-only unit | 🎨 Design, its own commit | B-81 |
| **B-83** — boundary colliders at `±40` around a `±20` floor | 🎨 Design, inside 2.2 | B-83, §4 above |
| **4.4a** — `throw_bakya` max range is 4.81 units | 🔧 Build (tuning) | §9 above, `Checklist.md` 4.4a |
| Spawn-point *reading* logic (`main.gd` prefers map markers) | 🔧 Build | `Checklist.md` 2.2 |
| `HazardZone` slow-zone behaviour | 🔧 Build | 2.2 places it; Build owns what it does |
