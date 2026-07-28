"""Removes OFFENSE-orange from our copy of a Kenney kit's colour atlas.

    python tools/models/retint_kit_atlas.py       # run from the repo root

⚠️ DEV-TIME TOOL, NOT PART OF THE GAME. Same contract as the map builders:
Godot never runs it and it ships in no export. It is committed for the same
reason they are — a recoloured binary nobody can re-derive is a binary nobody
will ever adjust.

WHY THIS EXISTS
===============

`Dev_Plan.md` §4.2 rule 1: **orange is ALWAYS offense and blue is ALWAYS
defence, everywhere in the project. Never reuse either hue for anything else.**

Kenney's kits know nothing about that rule. The Food Kit's `soda-can` samples a
bright orange off the shared `colormap.png` ramp, so dropping it in unmodified
put a **vividly OFFENSE-orange can** on the DEFENDING team's most important
object — the exact class of error as B-81 (a `DEFENSE`-blue slipper on an
offence-only prop), arriving from the opposite direction. Verified by render
before this script existed.

**So the rule is enforced in the asset, not in a note asking people to be
careful.** After this runs, our copy of the atlas contains no colour that can be
mistaken for `OFFENSE`, and every kit prop textured from it is safe by
construction — including the ones nobody has imported yet (7.4's furniture and
street props all share this ramp).

WHAT IT DELIBERATELY DOES NOT TOUCH
===================================

Only the **bright, saturated** orange band is remapped. Browns, tans, terracotta
and wood are all in the same hue neighbourhood and are perfectly legal — they
are what `ENV_WOOD`, `ENV_RUST` and `PROP_FOAM` already are. Remapping those
would turn every crate and every plank blue, which is a much louder bug than the
one being fixed. The value/saturation floor below is what separates "a colour
that reads as OFFENSE at arena distance" from "a brown thing".

Hue is ROTATED rather than replaced flat, so the ramp's shading steps survive:
a lit face and a shadowed face stay different colours after the remap, which is
what keeps the mesh from going flat.
"""
import colorsys
import pathlib
import sys

from PIL import Image

## The band that reads as OFFENSE #F87020 at arena distance. Measured against
## the actual atlas — `#FF7E44` (the can body, 4379 px) sits at hue 19, sat 0.73,
## val 1.00, and the browns that must survive sit at val 0.56-0.85.
HUE_MIN, HUE_MAX = 5.0, 30.0
SAT_MIN = 0.65
VAL_MIN = 0.88

## The DEFENSE band, dampened in env atlases for exactly the same reason as the
## orange one — the rule forbids BOTH role hues on environment art, not just the
## orange one. Measured: the city atlas has none of this at all, the car atlas
## has 1312 px of it (one blue vehicle). Small, and still a rule break.
## ⚠️ NOT applied in `prop_blue` mode: the can is legitimately DEFENSE-blue
## (`Art_Direction.md` §2, "Can body only"), so damping blue there would undo
## the recolour this script had just done.
BLUE_HUE_MIN, BLUE_HUE_MAX = 190.0, 225.0
BLUE_SAT_MIN = 0.55
BLUE_VAL_MIN = 0.75

## Sarsi blue — the livery the can is headed for anyway (checklist 7.6), so the
## interim colour is a step toward it rather than a throwaway.
PROP_TARGET_HUE = 205.0

## ⚠️ TWO MODES, AND USING THE WRONG ONE IS ITSELF A RULE BREAK.
##
## The first version of this script rotated orange to blue everywhere. That is
## correct for the CAN — `Art_Direction.md` §2 lists `DEFENSE` as legal on the
## "Can body only" — and WRONG for everything else, because **environment art may
## use NEITHER role hue** (`ui_theme.gd`'s `ENV_*` header). Recolouring the city
## and car kits blue would have traded an OFFENSE violation for a DEFENSE one and
## turned the whole street into the defending team's colour.
##
## So env atlases are DAMPENED instead of rotated: the hue is kept, and
## saturation and value are pulled down into the band `ENV_*` already occupies.
## Bright orange becomes terracotta/rust — which is not a workaround, it is
## exactly what `ENV_RUST` (#A65A3A) and `ENV_PAINT_TERRA` (#B5664C) already are,
## and what a Philippine street is actually full of.
ENV_MAX_SAT = 0.60
ENV_MAX_VAL = 0.72

## path -> mode. "prop_blue" rotates hue; "env_damp" keeps hue and dampens.
ATLASES = {
    "assets/models/kits/food/Textures/colormap.png": "prop_blue",
    "assets/models/kits/city/Textures/colormap.png": "env_damp",
    "assets/models/kits/car/Textures/colormap.png": "env_damp",
}


def retint(path: pathlib.Path, mode: str) -> int:
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    width, height = image.size
    changed = 0
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            in_orange = (HUE_MIN / 360.0 <= h <= HUE_MAX / 360.0
                         and s >= SAT_MIN and v >= VAL_MIN)
            in_blue = (mode == "env_damp"
                       and BLUE_HUE_MIN / 360.0 <= h <= BLUE_HUE_MAX / 360.0
                       and s >= BLUE_SAT_MIN and v >= BLUE_VAL_MIN)
            if not (in_orange or in_blue):
                continue
            if mode == "prop_blue" and in_orange:
                nr, ng, nb = colorsys.hsv_to_rgb(PROP_TARGET_HUE / 360.0, s, v)
            else:
                nr, ng, nb = colorsys.hsv_to_rgb(h, min(s, ENV_MAX_SAT), min(v, ENV_MAX_VAL))
            pixels[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
            changed += 1
    if changed:
        image.save(path)
    return changed


if __name__ == "__main__":
    total = 0
    for rel, mode in ATLASES.items():
        path = pathlib.Path(rel)
        if not path.exists():
            print("skip (not imported yet): %s" % rel)
            continue
        n = retint(path, mode)
        total += n
        print("%s [%s]: %d px moved out of the OFFENSE band" % (rel, mode, n))
    # Idempotent by construction, both modes. "prop_blue" lands pixels at hue
    # 205, far outside [HUE_MIN, HUE_MAX]. "env_damp" keeps the hue but drops
    # value to ENV_MAX_VAL (0.72), below the VAL_MIN (0.88) floor that selects a
    # pixel in the first place — so neither mode can re-trigger on itself. That
    # is what makes it safe to re-run after re-extracting a kit.
    print("done — re-run is a no-op (%d px total)" % total)
    sys.exit(0)
