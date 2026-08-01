"""Turns the human's own 2D prop drawings into the game's prop textures.

    python tools/models/build_prop_textures.py

WHY THIS SCRIPT EXISTS AT ALL, given docs/Art_Direction.md said "no textures".

The lata and the tsinelas are the only two hero props in the game and the human
drew all eight of them by hand -- four cans (three of them parody liveries with
readable wordmarks: PASIP, BOYBEN PERMAGAD, DECADES TUNA) and four slippers.
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
REFS = os.path.join(REPO, "docs", "refs", "props")
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

# --- The slippers -------------------------------------------------------------
#
# The two sheets are 2-up, one pair per sheet, drawn TOP-DOWN -- which is exactly
# the projection `add_extrude`'s `uv_map` applies, so these need no unwrapping
# step at all, only cropping. Toe is at the top of every drawing and `uv_map`
# sends the toe (-Z) to v = 0, so the art lands the right way round with no flip.
SLIPPER_SIZE = (512, 512)
SLIPPERS = [
    ("tsinelas_sheet1_crocs_bakya.png", "left", "tsinelas_crocs.png"),
    ("tsinelas_sheet1_crocs_bakya.png", "right", "tsinelas_bakya.png"),
    ("tsinelas_sheet2_rubber_sike.png", "left", "tsinelas_tsinelas.png"),
    ("tsinelas_sheet2_rubber_sike.png", "right", "tsinelas_sike.png"),
]

# Padding around a cropped slipper, as a fraction of its longest side. The sole
# mesh's own outline is slightly tighter than the drawing's silhouette, so a
# crop with no margin clips the art at the widest point of the ball of the foot.
SLIPPER_PAD = 0.04


def ink_bbox(image):
    """Bounding box of everything that is not the white page.

    Alpha is unreliable here -- the exports carry a soft alpha halo well outside
    the drawn shape (measured: 100 px of it on every side), so `getbbox()`
    returns a box that is visibly too large and leaves the art floating small in
    the middle of its texture. Thresholding on ink finds the real edge.
    """
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    min_x, min_y, max_x, max_y = width, height, -1, -1
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            if r + g + b < 720:  # anything meaningfully darker than paper
                if x < min_x:
                    min_x = x
                if x > max_x:
                    max_x = x
                if y < min_y:
                    min_y = y
                if y > max_y:
                    max_y = y
    if max_x < 0:
        raise SystemExit("build_prop_textures: found no ink in an image")
    return (min_x, min_y, max_x + 1, max_y + 1)


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


def build_slippers():
    for source_name, side, out_name in SLIPPERS:
        path = os.path.join(REFS, source_name)
        sheet = flatten_on_white(Image.open(path).convert("RGBA"))
        width, height = sheet.size
        half = sheet.crop((0, 0, width // 2, height)) if side == "left" \
            else sheet.crop((width // 2, 0, width, height))
        box = ink_bbox(half)
        cropped = half.crop(box)

        # Square canvas, art centred, aspect preserved. The sole's UV map spans
        # the mesh's own bounding box in x and z, so a non-square texture would
        # stretch the art along whichever axis it disagreed on.
        longest = max(cropped.size)
        pad = int(longest * SLIPPER_PAD)
        canvas_side = longest + 2 * pad
        canvas = Image.new("RGB", (canvas_side, canvas_side), (255, 255, 255))
        canvas.paste(cropped, ((canvas_side - cropped.size[0]) // 2,
                               (canvas_side - cropped.size[1]) // 2))
        canvas = canvas.resize(SLIPPER_SIZE, Image.NEAREST)
        canvas.save(os.path.join(OUT, out_name))
        print("  %-22s <- %s (%s)" % (out_name, source_name, side))


def main():
    if not os.path.isdir(OUT):
        os.makedirs(OUT)
    print("prop textures ->", os.path.relpath(OUT, REPO))
    build_cans()
    build_slippers()


if __name__ == "__main__":
    main()
