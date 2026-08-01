# Art Direction — the laws

## 1 · The colour law — the one rule that never bends

**Orange `#f87020` means OFFENSE. Blue `#0080e8` means DEFENCE.** They track the ROLE,
which swaps every round; they never mean a team, a character or decoration. Nothing else in
the frame — no outfit, no can tint, no slipper strap, no environment piece — may sit near
those two hues. Every other palette decision is yours to make; record it and move on.

`ui_theme.gd` is the only place a colour is named. Read it, never restate it.

| Band | Members |
|---|---|
| UI | `INK` `PANEL` `CARD` `OFFENSE` `DEFENSE` `IMPACT` `HIGHLIGHT` `DANGER` |
| Menu wood | `WOOD_DEEP` `WOOD_MID` `WOOD_DARK` `WOOD_EDGE` `CREAM` `AMBER` |
| Environment | `ENV_*` — asphalt, concrete, GI sheet, rust, wood, foliage, dirt, tarp, rubber, four facade paints |
| Hero props | `PROP_FOAM` `PROP_FOAM_DARK` `PROP_WEBBING` `PROP_SARSI_RED` |

A hero prop **may** be more saturated than any `ENV_*` — it is the most-looked-at object in
the game and has to read against asphalt. It may not approach the role hues.

## 2 · The scale and height laws

| Fact | Value | Why it is a law |
|---|---|---|
| Person capsule | r 0.40, h 1.60 | eye at 1.25 |
| Person model scale | 2.38 | measured off the Kenney rig's AABB, not guessed |
| Person model yaw | +180° **on the MODEL node only** | the rig's face is on +Z, Godot's forward is −Z. **Never rotate the body to fix a render.** |
| Lata capsule | r 0.14, h 0.34 | knee-high |
| Tsinelas visual scale | **1.60** (was 1.25) | bigger for drama; the capsule scales with it or you get a slipper you can see and cannot step on |
| Tsinelas capsule | r 0.256, h 0.512 | = the 1.25-era row × 1.28 |
| Interior clutter | **≤ 1.0 tall** | a jump apexes at 0.841; anything taller becomes a platform |

## 3 · Arena geometry

| Mark | Value | Source of truth |
|---|---|---|
| Base circle | ring at r **0.70**, world origin | `env_kit.gd::_base_circle_decal` |
| Lata "home" for the countdown | r **0.9** | `Design.md` §5.2 |
| Confinement marker | **SQUARE** at \|x\| = \|z\| = **6.5** | `CharacterBase.CONFINEMENT_RADIUS`, parsed out of the .gd by both map builders — **do not reshape that `const` line** |
| Throwing line | **7.5** from centre (= box + 1.0), one per side | `throwing_line_decal`, position derived from the box in both builders |

⚠️ **THE BOX WENT 5.0 → 6.5 ON 2026-08-01** (human ask, twice). The court width follows it
automatically — `COURT_X = CONFINEMENT_BOX_RADIUS` — but the throwing line did **not**: it
was a literal `6.0`, which the widened box swallowed, putting the chalk mark 0.5 inside
the area the throw gate refuses from. It is derived now. `Design.md` §2 carries the
reasoning for the value.
| Team-side line | 6.0 × 0.08, `PANEL` at 40 % | subordinate to the throwing line on purpose |

A square and a circle of the same "radius" agree only at the four edge midpoints; on the
diagonals they differ by 2.07 units. The physics clamps X and Z independently to match the
drawn square.

## 4 · The models — kits, not new assets

Everything in the world is CC0 Kenney (City/Suburban, Fantasy Town, Mini Forest, Food,
Furniture, Car) plus the project's own generated `env_kit` decals and `tsinelas.obj`.

**A character is a rig plus a palette, never a new model** — twelve Kenney rigs carry twelve
roster Persons through `person_palette.gdshader` and a generated `.tres`
(`tools/models/generate_person_palettes.py`). Do not hand-edit a `person_*.tres`.

**A prop class is a tint plus ATTACHMENTS, never a new base mesh.** Each lata and each
tsinelas skin carries a small procedural kit of junk — a wire handle, a sardine key, a paint
drip, a hanger — built at runtime in `character_visual.gd` from primitive meshes and
parented under the `Visual` node.

> ⚠️ **Attachments are visual-only children of `Visual`, never of the body.** The collision
> capsule, the hurtbox and the hitbox are sized by `CharacterBase._apply_role_collision()`
> from `_COLLISION_BY_ROLE`, which knows nothing about them. That is the whole reason an
> attachment cannot break physics, and it is the rule to keep if you add more.

⚠️ **Twelve skins exist in code and none has ever been rendered.** See `Agent_Prompts.md`
§4.

## 4b · Third-party assets and credit — **read before shipping**

Everything in this table is **CC-BY-4.0**: free to use commercially, and the
author **must be credited**. Each `.glb` ships with its own `*_LICENSE.txt`
beside it in `assets/models/kits/footwear/`, exactly as delivered — do not delete
those files, they are the licence compliance.

| Prop | Model | Author | Source | Licence |
|---|---|---|---|---|
| TSINELAS | — | *this project* | `tools/models/generate_all.gd` | project's own |
| CROCS | "crocs" | **fnk** | [sketchfab.com/3d-models/crocs-fbede59e…](https://sketchfab.com/3d-models/crocs-fbede59e03394e928ed0eccf27e8fc23) | CC-BY-4.0 |
| PANTULOG | "Pink Slipper" | **The Withered Rose** | [sketchfab.com/3d-models/pink-slipper-af5b6388…](https://sketchfab.com/3d-models/pink-slipper-af5b6388d4f240389591a4ac09fedf06) | CC-BY-4.0 |
| SIKE | "Low Poly Nike Sandals" | **les03** | [sketchfab.com/3d-models/low-poly-nike-sandals-8e77c949…](https://sketchfab.com/3d-models/low-poly-nike-sandals-8e77c949319148afb9134ba13f64046f) | CC-BY-4.0 |

**The credit has to be REACHABLE, not just written here.** A licence that says
"author must be credited" is not satisfied by a line in a design doc nobody
ships. These four belong on a credits screen or in the submission's asset list
alongside the existing Kenney CC0 and OpenGameArt CC0 credits.
**Filed to 🖥️ `build ui` as § CHECKLIST 1.11.**

> ### ⚠️ THE SIKE CARRIES REAL NIKE TRADE DRESS, AND THAT IS A KNOWN, ACCEPTED RISK
>
> The human's own drawing is a parody — "SIKE" with a swoosh — and the intent was
> to swap the N for an S on the model. **That could not be done.** The model's
> wordmark and swoosh are **geometry, not texture** (the file carries no images at
> all; every colour is a `baseColorFactor`), so changing the letter means editing
> the mesh, which is modelling, which is the Blender step this lane is forbidden.
>
> The model therefore renders an actual Nike swoosh and wordmark. 🧑, told this:
> *"im lowk okay with nike as long as it doesnt make shit lag man"*. Recorded as a
> decision, not an oversight — for a competition submission a real trademark on a
> hero prop is a small but genuine risk, and the two ways out are a different
> slide model or deleting the wordmark's faces.

## 5 · The toon pass

⚠️ **"NO TEXTURES" IS NO LONGER TRUE OF THE TWO HERO PROPS, AS OF 2026-08-01.**
This law used to read *"Flat colour, no textures, no UVs"* without exception, and
it still governs the environment and the characters. The lata and the tsinelas
are now textured, on a direct human ruling: they drew four cans by hand — three
carrying readable parody wordmarks (PASIP, BOYBEN PERMAGAD, DECADES TUNA) — and
supplied flattened 360° label wraps for the purpose. 🧑: *"you can use the
flattened shit for textures bcz its easier that way, you cant redraw this too
bro"*. Stripped to a flat `Kd`, a Pasip and a Decades are the same grey cylinder
and all of the Filipino specificity is gone with the label.

**It costs the tint system nothing**, which was the objection. `toon.gdshader`
already had a textured path (added for the Kenney kit atlas), and on it
`albedo_color` MULTIPLIES the sampled texture rather than replacing it — so a
textured skin carries `tint` **white**, which multiplies to a no-op, and
`lata.gd::_tint_meshes()` is untouched and still works for anyone who wants a
coloured variant. `obj_writer.gd` gained UV emission and `map_Kd`; the untextured
path is byte-identical, so every environment mesh regenerates unchanged.

**One material per hero prop, and that is forced.** The tint walk overwrites
every surface it finds, so a second untextured material would be repainted flat
white by a white tint. Where a part needs a different colour it gets it by being
projected onto a different part of the ONE texture — which is why the cans' end
caps are UV-pinned to their wrap's rim bands.

Everything else below still holds:

Flat colour, no PBR. Two shaders: `toon.gdshader` (banded lambert + a
rim term) and `outline.gdshader` (inverted hull). Prop outlines are sized in **world** units
(`OUTLINE_WORLD_WIDTH` 0.012) because meshes differ in scale; Persons take an early-out and
keep `person_outline.tres`. Large environment silhouette pieces get an outline; small
dressing does not.

Hit flash drives a separate `flash_amount` uniform, so writing `albedo_color` for a skin
tint is safe and cannot break the flash.

## 6 · Maps

| Map | Read |
|---|---|
| **Eskinita** | urban side street — sari-sari, sampay, kanal, corrugated walls, 10–14 m rooflines |
| **Bayan Plaza** | barangay plaza — church facade, basketball ring, acacia, monument |

Both are emitted **wholesale** by `tools/maps/build_*.py`. Anything you add to a `.tscn` by
hand survives exactly until the next layout run — edit the builder.

## 7 · Deviations from the moodboard, all deliberate

You do not need permission to diverge from the moodboard. You need to write down that you
did.

| Board said | Build does | Why |
|---|---|---|
| Yellow/blue/orange school outfits | Green sando + maroon top | §1 — those hues mean role |
| Magenta slipper / can accents | `PROP_FOAM` brown and Sarsi livery | superseded by the human's own second prop moodboard: *"the magenta shit is just placeholder"* |
| 1024² PBR on both props | Flat colour | the pipeline emits no UVs and the stated reference is flat colour |
| Props at hero scale | Real scale, then the 1.6× slipper for drama | the board had no environment to be out of proportion with |
