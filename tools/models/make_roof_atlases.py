"""Emits recoloured copies of the City Kit atlas so every roof is not the same green.

    python tools/models/make_roof_atlases.py      # run from the repo root

⚠️ DEV-TIME TOOL. Godot never runs it and it ships in no export. Same contract as
`retint_kit_atlas.py`, which it deliberately resembles — read that one first, it
carries the reasoning about why touching a shared Kenney atlas is legitimate.

WHY THIS EXISTS
===============

Human call, 2026-07-29, on the first Phase 8 render: *"dont use same green house
for all, it looks so repetitive, try to make it more colorful but in a way that
looks good and not messy."*

The map generator already cycles eleven `building-type-*` meshes, so the
SILHOUETTES vary. The COLOURS cannot: measured, every City Kit building is a
single mesh with a single primitive and a single material pointing at one shared
`colormap.png`, and its roof is a handful of green texels in that atlas. Eleven
different shapes wearing one identical green roof is what read as "the same
house over and over".

Two fixes were possible and only this one works:

  * A PER-INSTANCE `albedo_color` TINT (which `env_toon_pass.gd` also does, for
    the walls) multiplies the whole atlas at once. It cannot separate roof from
    wall, because they are the same material — and green multiplied by anything
    is still green, so it varied the walls nicely and left every roof green.
  * RECOLOURING THE ATLAS ITSELF works, but one atlas means one roof colour for
    the whole street. So this emits SEVERAL atlases, and `env_toon_pass.gd`
    assigns one per building from the same seeded hash it uses for wall tints.

WHAT IT IS CAREFUL ABOUT
========================

⚠️ IT WRITES NEW FILES AND NEVER TOUCHES THE ORIGINAL. `colormap.png` stays
exactly as `retint_kit_atlas.py` left it, so this cannot undo that script's
OFFENSE-orange fix or fight with it. Re-running is idempotent: the variants are
derived from the original every time, not from each other.

⚠️ ONLY GREENS MOVE, AND ONLY IN THE VARIANTS. The band is hue 125-165 at
saturation 0.25 and up, measured against this specific atlas. City Kit foliage
sits in the same band — which is fine, and only because these variants are
applied exclusively to BUILDINGS. Trees keep sampling the untouched original.
See the note on HUE_MIN below before changing that.

⚠️ NO ROLE HUES. `Dev_Plan.md` §4.2 rule 1: orange is ALWAYS offense (#f87020,
hue 20) and blue is ALWAYS defence (#0080e8, hue 206). Every target below is
either well clear of both or deliberately desaturated far enough that it cannot
be mistaken for a team colour on the largest surface in the frame. The
terracotta target sits at hue 12 with saturation pulled DOWN, which is where the
project's own ENV_PAINT_TERRA (#b5664c) already lives.
"""
import colorsys
import os

from PIL import Image

SRC = "assets/models/kits/city/Textures/colormap.png"
OUT_DIR = "assets/models/kits/city/Textures"

## ⚠️ THE ROOF IS A HUE BAND, NOT ONE SWATCH, AND ASSUMING OTHERWISE SHIPPED A
## NO-OP. The first version of this file carried an exact-colour allowlist of
## `["#61CB8B"]` — picked because it was the most common green in the atlas by
## pixel count (8279 px). It remapped all 8279 of them, reported success, and
## changed nothing visible, because the buildings do not use that texel.
##
## Measured by decoding `building-type-a`'s actual TEXCOORD_0 accessor and
## sampling the atlas at every UV it references: a City Kit building samples
## FIVE greens — #42AC7C, #5BC588, #3DA77A, #47B17E and #57C286 — which are the
## lit and shaded faces of the roof. #61CB8B is not among them.
##
## So the band is the definition and there is no allowlist. That is safe here
## specifically because these variants are only ever applied to BUILDINGS
## (`env_toon_pass.gd::_is_building`); trees share this atlas and share this hue
## band, and they keep sampling the ORIGINAL `colormap.png`, untouched.
##
## ⚠️ IF YOU EVER APPLY A VARIANT TO A TREE, THIS BAND BECOMES WRONG and foliage
## gets recoloured with the roofs. Narrow it by value/saturation first, and
## re-measure against the mesh's real UVs — do not eyeball the atlas.
HUE_MIN, HUE_MAX = 125.0, 165.0
SAT_MIN = 0.25

## A floor on how much of the atlas must land in the band. A kit update that
## re-authors the roof out of this hue range should fail loudly rather than
## quietly emit five identical atlases, which is exactly what the allowlist
## version did — it "succeeded" while doing nothing.
MIN_EXPECTED_PX = 2000

## (suffix, target hue, saturation multiplier, value multiplier).
##
## ⚠️ NO LEAF GREEN. Playtest 2026-07-29: "houses you made are off theme look
## theyre js green". Two separate causes and this is one of them — the shipped
## kit roof is a saturated mint, and the original variant set kept a "jade" entry
## that stayed in the same family, so a fifth of every street still read green.
## A Philippine roofline is red oxide, weathered rust, BARE galvanised iron and
## the odd painted teal or mustard. Green is not on it.
VARIANTS = [
    ("terra", 12.0, 0.80, 0.92),   # red oxide - by far the commonest painted roof
    ("rust", 26.0, 0.70, 0.78),    # older, browner, weathered
    ("galv", 205.0, 0.10, 0.82),   # BARE galvanised iron: near-neutral silver
    ("ochre", 41.0, 0.66, 0.95),   # mustard
    ("teal", 186.0, 0.42, 0.80),   # painted iron, muted - not a leaf green
]


def main():
    if not os.path.exists(SRC):
        raise SystemExit("make_roof_atlases: %s not found" % SRC)
    source = Image.open(SRC).convert("RGB")
    pixels = list(source.getdata())

    # Locate the roof pixels ONCE, so every variant remaps exactly the same set
    # and the atlases stay in register with each other.
    targets = []
    for index, pixel in enumerate(pixels):
        r, g, b = [c / 255.0 for c in pixel]
        h, s, _v = colorsys.rgb_to_hsv(r, g, b)
        if HUE_MIN / 360.0 <= h <= HUE_MAX / 360.0 and s >= SAT_MIN:
            targets.append(index)

    if len(targets) < MIN_EXPECTED_PX:
        raise SystemExit(
            "make_roof_atlases: only %d px landed in the roof hue band "
            "(expected >= %d).\n"
            "The City Kit atlas has probably been re-authored. RE-MEASURE\n"
            "against a building's real TEXCOORD_0 accessor before touching the\n"
            "band — the first version of this file guessed the roof swatch from\n"
            "atlas pixel counts, guessed a texel the buildings never sample, and\n"
            "silently emitted five identical atlases."
            % (len(targets), MIN_EXPECTED_PX))

    for suffix, hue, sat_mul, val_mul in VARIANTS:
        out = list(pixels)
        for index in targets:
            r, g, b = [c / 255.0 for c in pixels[index]]
            _h, s, v = colorsys.rgb_to_hsv(r, g, b)
            nr, ng, nb = colorsys.hsv_to_rgb(
                hue / 360.0, min(1.0, s * sat_mul), min(1.0, v * val_mul))
            out[index] = (round(nr * 255), round(ng * 255), round(nb * 255))
        image = Image.new("RGB", source.size)
        image.putdata(out)
        path = os.path.join(OUT_DIR, "colormap_roof_%s.png" % suffix)
        image.save(path)
        print("  wrote %s  (%d px remapped -> hue %.0f)" % (path, len(targets), hue))

    print("make_roof_atlases: %d variants, %d roof px each" % (len(VARIANTS), len(targets)))


if __name__ == "__main__":
    main()
