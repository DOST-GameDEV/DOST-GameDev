"""Converts the sourced CC-BY footwear .glb files into the game's own prop format.

    python tools/models/build_footwear.py

WHAT THIS IS FOR. `docs/Agent_Prompts.md` § 5 asked for four tsinelas built from
the human's drawings. Four procedural ones were built and rejected on look
(🧑: *"the slippers are so bad"*, *"i think u gen js suck in 3d modelling"*), and
the human then sourced real models instead and told this lane to use them:
*"js look for assets that look like them and edit it a bit in color or texture"*.

Every model here is **CC-BY-4.0 and credited** in `docs/Art_Direction.md` § 8.
Nothing is redistributed without its licence file beside it.

WHAT IT DOES TO THEM, and why each step is needed rather than optional:

  · **DECIMATES.** Two of the four arrive at ~100k and ~131k triangles against a
    game whose cans are ~500 and whose character rigs are ~900. Grid clustering
    takes them to roughly the same budget as everything else, and its faceted
    output is this project's actual art style rather than a compromise — see
    `glb_tool.decimate`'s own note.
  · **NORMALISES scale and origin.** They arrive 20-40 units long and offset from
    their own origin by more than their own size. `slipper.gd` spins the visual
    about the mesh origin on two axes at once, so an off-centre origin wobbles
    like a bent wheel (§ 5.2), and `REST_HEIGHT` is measured from that origin.
  · **RE-AIMS them down -Z.** The game's props point their toe at -Z. Each model
    was authored pointing wherever its author liked.
  · **Extracts the base-colour texture** to a plain PNG referenced by `map_Kd`,
    so the prop takes exactly the same one-material, tint-multiplied,
    toon-shaded path as the generated cans. Picked by following the glTF
    material's `baseColorTexture` rather than by file size — a normal map used
    as albedo renders as a lilac slipper.

Deterministic: fixed inputs, fixed grid, no randomness. Re-running overwrites
with identical bytes.
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
KIT = os.path.join(REPO, "assets", "models", "kits", "footwear")
OUT = os.path.join(REPO, "assets", "models")
TEXOUT = os.path.join(REPO, "assets", "models", "textures")

sys.path.insert(0, HERE)
import glb_tool  # noqa: E402

# The toe-to-heel length every slipper is normalised to, in MESH units.
# `TsinelasVisual.tscn` multiplies by Art_Direction §2's 1.6 drama scale on top,
# giving 0.691 in the world — which is what `Slipper.HIT_RADIUS` and
# `REST_HEIGHT` are quoted against. Do not change one without the others.
LENGTH = 0.432

# name, source .glb, grid cells along the longest axis, yaw in degrees, half.
#
# `cells` is chosen per model against its own starting density: the two already
# low-poly models are passed through untouched (0 = no decimation) because
# clustering a 252-triangle mesh would destroy it, and the two heavy ones are
# clustered hard. `yaw` turns the toe to -Z. `half` is -1/+1 to keep one slipper
# of a pair and 0 for a model that is already a single — measured, not assumed:
# a pair shows up as a width at or above the model's own length.
## ⚠️ DECIMATION IS OFF ON ALL FOUR, AND THAT IS A CORRECTED CALL.
## The first pass clustered the two heavy models to ~26 cells and the human's
## verdict was immediate and right — *"man what happened to sike, honestly its js
## bad now"*. The crocs came out as shredded foil. Worse, the argument for
## decimating in the first place was overstated: 🧑 asked *"whats bad with us
## using a model thats a bit high poly? will it make the game lag or smth"*, and
## the honest answer is NO. 131k triangles is nothing to a modern GPU — a slipper
## is one to four draw calls whatever its density, and this map already places
## ~600 mesh instances. The real costs of a heavy model here are repository size
## and style-match, not frame rate, and neither justifies destroying the asset.
## 🧑: *"U dont have to compress js change n to s ... its fine gang"*.
##
## `cells` is kept as a knob rather than deleted: if repo size ever does become
## the binding constraint, a GENTLE pass (150-250 cells) removes the redundant
## coplanar triangles a photoscan is full of with no visible change. 26 was not
## gentle.
## Per-material colour overrides, `{glTF material index: (r, g, b)}`.
##
## ⚠️ RECOLOURED HERE RATHER THAN THROUGH THE ROSTER `tint`, because the tint
## walk writes ONE colour over EVERY surface of the prop. Tinting the flip-flops
## green would turn the strap green as well and lose the two-tone entirely; the
## human's drawing is a GREEN SOLE with a YELLOW strap, which is two materials.
## Colours sampled from `docs/refs/props/tsinelas_sheet2_rubber_sike.png`.
RECOLOR = {
    "tsinelas_tsinelas": {
        0: (0.36, 0.74, 0.53),   # sole, the drawing's green rubber
        1: (0.95, 0.89, 0.20),   # strap, its yellow thong
    },
}

# name, source .glb, grid cells, yaw in degrees, component pick.
#
# `pick` says how to find the slipper inside a model that contains more than one
# object: -1 for a left-and-right PAIR (group the parts by position, keep one
# side), 2 for a PHOTOGRAMMETRY SCAN (keep the tallest component, because the
# scan's ground plane is wide and flat and the subject stands on it), 0 to keep
# everything. The crocs is a scan complete with the wooden table it was shot on —
# most of its 100k triangles are tabletop.
# The fifth column is `only_material`: which colourway to keep out of a variant
# pack, or None for a model that is a single object.
JOBS = [

    ("tsinelas_pantulog", "pantulog.glb", 0, 0.0, -1, None, 0.0),
    # Material 0 (`lambert2SG`, image0) is the dusty beige pair — the grubbiest
    # of the five, which is what a street tumbang preso slipper should be.
    # ⚠️ roll STAYS 0 — a 180 turn was tried and made it worse, so the model is
    # already the right way up. Its 3/4 view reads oddly because the crocs is the
    # one slipper with a deep opening, not because it is inverted.
    ("tsinelas_crocs", "crocs.glb", 0, 0.0, -1, 0, 0.0),
    ("tsinelas_sike", "sike_sandals.glb", 0, 0.0, -1, None, 0.0),
]


def recentre_obj(path):
    """Moves an existing .obj onto its own volume centroid, in place.

    ⚠️ NEEDED BECAUSE THE ORIGIN CONVENTION CHANGED UNDER IT. `tsinelas_classic`
    is the slipper that shipped in the game before this session, restored from git
    on human instruction — 🧑: *"can we js use old slippers that already exist ...
    the one working in the game"*, after the sourced purple flip-flops were
    rejected. It was authored with y = 0 at the SOLE'S UNDERSIDE, which was
    correct when `Slipper.REST_HEIGHT` was 0.08 and measured to that convention.
    Every other slipper now sits on its volume centroid so the two-axis spin does
    not wobble (§ 5.2), and REST_HEIGHT moved to 0.045 to match. Mixing the two
    conventions would leave this one skin floating half a slipper off the floor —
    exactly the bug the human reported earlier: *"in earlier iterations the shoe
    would float"*.

    Same divergence-theorem sum `ObjWriter.center_on_volume_centroid()` uses, so
    the restored mesh lands on the same kind of origin the generated ones do.
    """
    verts, faces, lines = [], [], []
    with open(path) as fh:
        for line in fh:
            lines.append(line)
            if line.startswith("v "):
                verts.append([float(x) for x in line.split()[1:4]])
            elif line.startswith("f "):
                idx = [int(tok.split("/")[0]) for tok in line.split()[1:4]]
                faces.append(idx)
    total, acc = 0.0, [0.0, 0.0, 0.0]
    for a, b, c in faces:
        va, vb, vc = verts[a - 1], verts[b - 1], verts[c - 1]
        cross = (vb[1] * vc[2] - vb[2] * vc[1],
                 vb[2] * vc[0] - vb[0] * vc[2],
                 vb[0] * vc[1] - vb[1] * vc[0])
        vol = (va[0] * cross[0] + va[1] * cross[1] + va[2] * cross[2]) / 6.0
        total += vol
        for k in range(3):
            acc[k] += vol * (va[k] + vb[k] + vc[k]) / 4.0
    if abs(total) < 1e-9:
        lo = [min(v[k] for v in verts) for k in range(3)]
        hi = [max(v[k] for v in verts) for k in range(3)]
        centre = [(lo[k] + hi[k]) / 2.0 for k in range(3)]
    else:
        centre = [acc[k] / total for k in range(3)]

    out, vi = [], 0
    for line in lines:
        if line.startswith("v "):
            v = verts[vi]
            vi += 1
            out.append("v %.5f %.5f %.5f\n" % (v[0] - centre[0], v[1] - centre[1],
                                               v[2] - centre[2]))
        else:
            out.append(line)
    with open(path, "w", newline="\n") as fh:
        fh.writelines(out)

    moved = [[verts[i][k] - centre[k] for k in range(3)] for i in range(len(verts))]
    lo = [min(v[k] for v in moved) for k in range(3)]
    hi = [max(v[k] for v in moved) for k in range(3)]
    print("%-18s tris %d  L %.3f W %.3f H %.3f  centroid->floor %.4f"
          % (os.path.basename(path).replace(".obj", ""), len(faces),
             hi[2] - lo[2], hi[0] - lo[0], hi[1] - lo[1], -lo[1]))


def main():
    if not os.path.isdir(TEXOUT):
        os.makedirs(TEXOUT)
    classic = os.path.join(OUT, "tsinelas_classic.obj")
    if os.path.isfile(classic):
        recentre_obj(classic)
    for name, source, cells, yaw, half, only_material, roll in JOBS:
        path = os.path.join(KIT, source)
        if not os.path.isfile(path):
            print("  SKIP %-20s (%s not present)" % (name, source))
            continue
        gltf, binary = glb_tool.read_glb(path)

        # Pull the base-colour image out beside the .obj, if there is one. A
        # model with no texture keeps a plain white Kd and takes its colour from
        # the roster tint instead, which is the pre-texture path and still works.
        albedo = glb_tool.base_color_image(gltf)
        texture_rel = ""
        if albedo is not None:
            for i, _n, ext, _s, _e, blob in glb_tool.image_slices(gltf, binary):
                if i != albedo:
                    continue
                out_name = "%s.%s" % (name, "png" if ext == "png" else "jpg")
                with open(os.path.join(TEXOUT, out_name), "wb") as fh:
                    fh.write(blob)
                texture_rel = "textures/" + out_name

        glb_tool.cmd_obj(path, os.path.join(OUT, name), LENGTH, texture_rel,
                         yaw, cells, half, RECOLOR.get(name), only_material, roll)


if __name__ == "__main__":
    main()
