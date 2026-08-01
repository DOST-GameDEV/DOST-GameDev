"""Turns the human's own 2D CAN drawings into the game's can textures.

    python tools/models/build_prop_textures.py

⚠️⚠️ THE CANS ONLY. THE SLIPPER HALF OF THIS SCRIPT WAS DELETED 2026-08-01 AND
MUST NOT COME BACK -- IT WAS A SECOND GENERATOR WRITING ANOTHER GENERATOR'S
OUTPUT FILES.

It used to crop four slippers out of the two `tsinelas_sheet*.png` drawings and
write them to `textures/tsinelas_{crocs,bakya,tsinelas,sike}.png`. Three of those
four names are ALSO written by `tools/models/build_footwear.py`, which extracts
the real base-colour image out of each sourced `.glb`. Two scripts, one set of
paths, and whichever ran last won -- exactly the failure that had
`generate_all.gd` silently overwriting the sourced slippers for hours (see
docs/Agent_Prompts.md's LOG). The evidence was still on disk when this was
found: `tsinelas_crocs.png` AND `tsinelas_crocs.jpg` both present, from the two
different producers.

⚠️ THE OWNERSHIP RULE, WHICH IS THE POINT: **slippers come from
`build_footwear.py` ONLY; cans and the env kit come from `generate_all.gd`;
can TEXTURES come from here.** One output path, one producer, always.

The drawings the slipper half read are also no longer what the game ships. The
four procedural drawing-derived slippers were rejected on look and replaced with
sourced 3D models (Art_Direction.md 4b), so cropping those sheets produced
textures for meshes that no longer exist. 🧑 2026-08-01: *"yo thats old stale
shit"*.

WHY THIS SCRIPT EXISTS AT ALL, given docs/Art_Direction.md said "no textures".

The lata is a hero prop and the human drew all four cans by hand -- three of them
parody liveries with readable wordmarks: PASIP, BOYBEN PERMAGAD, DECADES TUNA.
None of that survives being reduced to a flat `Kd` colour: a Pasip can and a
Decades can with their labels removed are the same grey cylinder, and the joke,
the Filipino specificity and the Originality marks all live in the label.

The human supplied FLATTENED 360-degree label wraps alongside the upright
drawings for exactly this reason, and then ruled on it directly, 2026-08-01:
"you can use the flattened shit for textures bcz its easier that way, you cant
redraw this too bro". Art_Direction.md Part 5 is amended to match rather than
quietly broken -- see its "the toon pass" section.

⚠️ THIS DOES NOT FIGHT THE SKIN TINT, WHICH WAS THE STANDING OBJECTION.
`lata.gd::_tint_meshes()` walks every surface and writes the roster entry's
`tint` into `albedo_color`. On the toon shader `albedo_color` MULTIPLIES the
sampled texture (see toon.gdshader's fragment(), and its header, which added
that path for the Kenney kit atlas). So a textured skin carries `tint` WHITE and
multiplies to a no-op. The tint system is untouched and still works for anyone
who wants a coloured variant later.

⚠️ NEAREST-NEIGHBOUR RESAMPLING, NEVER BILINEAR. The drawings are pixel art with
hard black outlines. Bilinear downscaling greys those outlines into mush and the
wordmarks stop being readable at the arena distance that is the whole point --
which is the same readability requirement Agent_Prompts.md 5.3 states for the
silhouette, applied to the label.

Deterministic: fixed sizes, fixed crops, no randomness. Re-running overwrites
with identical bytes.
"""

import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "assets", "models", "textures")

# Where the human's originals live. Kept out of the repo's asset tree on purpose:
# these are the 2897x2173 source drawings, and the repo only needs the
# game-resolution derivatives this script produces.
SRC = os.path.join(REPO, "docs", "refs", "props", "source")

# --- The cans -----------------------------------------------------------------
#
# Each flattened file is a full 360-degree wrap INCLUDING the metal rim bands at
# the very top and bottom, so UV `v` runs 0 at the base to 1 at the lid across
# the whole can and no separate rim material is needed. All four sources are
# already 2:1, which is why they all resample to one size without distortion.
CAN_SIZE = (1024, 512)
CANS = [
    ("Flattened Pasip.png", "lata_pasip.png"),
    ("Flattend BOYBEN Paint.png", "lata_boyben.png"),
    ("Flattended Decades Tuna.png", "lata_decades.png"),
    ("Flattened Metal Can.png", "lata_metal.png"),
]

# --- The slippers: DELETED, see the module header -----------------------------
#
# `SLIPPER_SIZE`, `SLIPPERS` and `SLIPPER_PAD` lived here and produced four
# textures for four meshes the game no longer has, at three paths
# `build_footwear.py` also writes. Both halves of that are reasons to delete it
# rather than to keep it "in case": a dead generator that still writes live files
# is worse than no generator at all.


## `ink_bbox()` WENT WITH `build_slippers()`. It thresholded a drawing down to
## its real inked edge so a slipper could be cropped out of a 2-up sheet; the
## cans need no crop at all (each source is already a full 2:1 wrap), so it had
## exactly one caller and that caller is gone.


def flatten_on_white(image):
    """Composites onto white. The drawings' background is transparent in places
    and Godot samples RGB regardless of alpha here, so an un-composited crop
    renders with black fringing wherever alpha was partial."""
    flat = Image.new("RGB", image.size, (255, 255, 255))
    flat.paste(image, (0, 0), image)
    return flat


def build_cans():
    for source_name, out_name in CANS:
        path = os.path.join(SRC, source_name)
        image = flatten_on_white(Image.open(path).convert("RGBA"))
        image = image.resize(CAN_SIZE, Image.NEAREST)
        image.save(os.path.join(OUT, out_name))
        print("  %-22s <- %s" % (out_name, source_name))


## `build_slippers()` WAS DELETED HERE — see the module header. It cropped the
## two drawing sheets into four slipper textures, three of which shared a path
## with `build_footwear.py`'s glb-extracted output.


def main():
    if not os.path.isdir(OUT):
        os.makedirs(OUT)
    print("prop textures ->", os.path.relpath(OUT, REPO))
    build_cans()


if __name__ == "__main__":
    main()
