#!/usr/bin/env python3
"""Cuts the main menu's TUTORIAL pennant to fit the hole between SETTINGS and QUIT.

    python tools/ui/generate_pennant.py

Writes `assets/ui/main-menu/TUTORIAL BUTTON.png` and prints the exact node rect
and caption values for `MainMenu.tscn`. Re-run it after moving any pennant in
that scene — the shape is derived from where its neighbours actually are, so
moving one and not re-running is what puts the gaps back.

WHY THIS EXISTS. The button shipped as a 991x350 canvas next to SETTINGS' 991x226
— identical width, 55% more height, every band measurement a clean 1.55x of
SETTINGS'. It was that button scaled on one axis. A one-axis scale fattens the
horizontal runs of an outline while leaving the vertical ones alone, so the
stroke stops being a constant width, the slant steepens and the point goes blunt.

But the first fix here — redraw it un-stretched, at the family's own fixed
135->194px band taper — was still wrong, and wrong in a way worth writing down,
because it looked correct in isolation and only failed in the stack:

  ⚠️ THE HOLE THIS BUTTON FILLS IS A WEDGE, NOT A BAND.

SETTINGS' underside falls at 0.0999 dy/dx and QUIT's top edge RISES at -0.0651.
The two edges therefore diverge to the left and converge to the right, and the
gap between them is 203px tall at the left of the screen and 119px at the point.
Any constant-thickness band dropped in there gaps along one end and collides
along the other, whichever thickness you pick — which is exactly what happened:
open wedges at the left against both neighbours, and the arrow tip touching QUIT
on the right.

So the shape is not chosen and then placed. It is DERIVED from its neighbours:

  * The top edge is SETTINGS' measured bottom edge, offset down by GUTTER.
  * The bottom edge is QUIT's measured top edge, offset up by GUTTER.
  * Both edges are measured off the neighbours' actual PNG alpha, mapped through
    their actual node rects in `MainMenu.tscn`, so the piece is cut against where
    those buttons really are rather than against numbers typed here.

That yields a tapering pennant — thick where the hole is thick, thin where it is
thin — with a constant GUTTER of daylight on both sides all the way across. A
puzzle piece.

GUTTER is 12px because that is what the stack already uses: PLAY's underside and
SETTINGS' top edge are near-parallel and sit 11.6px apart at the screen edge, so
matching it makes the new seams indistinguishable from the existing one.

WHY A PNG AND NOT A StyleBox. `StyleBoxFlat` and `NinePatchRect` both describe an
axis-aligned rectangle; neither can express a slant, a taper or a point, and a
nine-patch's stretchable middle is the one-axis scale that caused this bug in the
first place. The other three pennants are textures and `arrow_button.gd` takes a
`Texture2D`. So: a texture, but a GENERATED one, in the same spirit as
`tools/models/generate_all.gd` and `tools/audio/generate_sfx.py`.
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageDraw

ASSETS = os.path.join("assets", "ui", "main-menu")
OUT_PATH = os.path.join(ASSETS, "TUTORIAL BUTTON.png")

# --- The neighbours, as MainMenu.tscn places them -----------------------------
#
# ⚠️ KEEP IN SYNC WITH THE SCENE. These are the `offset_*` values on
# SettingsButton and QuitButton. The script asserts each one's aspect ratio
# against its texture, which catches a rect that was resized but not copied here
# — it cannot catch one that was moved.
SETTINGS_RECT = (-143.0, 559.0, 743.0, 170.0)  # left, top, width, height
QUIT_RECT = (-173.0, 845.0, 742.0, 145.0)

## Daylight between this pennant and each neighbour, in screen pixels. Matches
## the existing PLAY/SETTINGS seam — see the module docstring.
GUTTER = 12.0

# --- This pennant -------------------------------------------------------------

## Node rect left edge. Continues the stack's leftward drift: PLAY -123,
## SETTINGS -143, this one, QUIT -173.
RECT_LEFT = -158.0
## Screen x of the arrow point, and where the body stops and the tip starts
## converging. The apex sits between QUIT's tip (568) and SETTINGS' (599).
APEX_X = 592.0
TIP_START_X = 500.0

## Slope of the flat left cut where the shape runs off the viewport, dy/dx.
## Measured off SETTINGS and QUIT, which share it.
LEFT_CUT_SLOPE = -14.4

## The family renders every pennant at this scale — all three existing rects are
## within 0.1% of it. Texture pixels are screen pixels divided by this.
FAMILY_SCALE = 0.74975

## Paint band widths in TEXTURE pixels, measured perpendicular to each edge.
STROKE_WIDTH = 6.0
KEYLINE_WIDTH = 7.0

## Built up from UiTheme.DEFENSE #0080e8, the palette's blue, rather than by
## eyedropping the old asset — same reason `generate_all.gd` reads its diffuse
## values from the palette instead of retyping hex.
##
## The ramp is CANVAS-vertical, not band-vertical, which looks like a bug and is
## not. Measured across SETTINGS, a given canvas y is the same colour at x=60 as
## at x=860 even though the band has slid 30px down between them — so the left
## end of a pennant shows the top of the ramp and the right end shows the bottom,
## and the shape reads as one lit object rather than as a tube.
BODY_TOP = (96, 190, 248)
## The sheen across the upper third. SETTINGS has one at ~17% of canvas height
## and it is most of why that button does not read as flat vinyl.
BODY_SHEEN = (158, 226, 255)
BODY_SHEEN_AT = 0.17
## Deep enough that the top-to-bottom value drop matches the other three. A
## medium blue reads as washed out beside PLAY's deep green and QUIT's deep red.
BODY_BOTTOM = (0, 62, 165)
STROKE = (110, 194, 248)
KEYLINE = (88, 168, 228)

## Everything is drawn at this multiple and boxed back down, which is where the
## edge antialiasing comes from — the reference pennants have soft edges too.
SUPERSAMPLE = 4


# --- Measuring the neighbours -------------------------------------------------

def _alpha(name: str) -> np.ndarray:
    return np.array(Image.open(os.path.join(ASSETS, f"{name}.png")).convert("RGBA"))[..., 3]


def _edge_line(name: str, rect: tuple[float, float, float, float],
               which: str) -> tuple[float, float]:
    """Least-squares fit of one neighbour's top or bottom edge, in screen space.

    Returns (slope, intercept) for `y = slope * x + intercept`.

    Fitted over the body only. The flat left cut and the arrow tip are both
    steep and would drag a whole-width fit badly off the edge that actually
    faces this button. The tip is found as the widest column — the band grows
    monotonically until the point starts.
    """
    al = _alpha(name)
    height, width = al.shape
    left, top, rect_w, _ = rect
    scale = rect_w / width

    tops = np.full(width, -1.0)
    bots = np.full(width, -1.0)
    for x in range(width):
        col = np.nonzero(al[:, x] > 16)[0]
        if col.size:
            tops[x], bots[x] = col.min(), col.max()

    solid = np.nonzero(bots >= 0)[0]
    band = bots[solid] - tops[solid]
    tip_start = solid[int(np.argmax(band))]

    lo, hi = int(tip_start * 0.06), int(tip_start * 0.97)
    xs = np.arange(lo, hi)
    ys = (tops if which == "top" else bots)[lo:hi]
    keep = ys >= 0
    xs, ys = xs[keep], ys[keep]

    # Texture pixels -> screen pixels.
    sx = left + xs * scale
    sy = top + ys * scale
    slope, intercept = np.polyfit(sx, sy, 1)
    return float(slope), float(intercept)


def _assert_aspect(name: str, rect: tuple[float, float, float, float]) -> None:
    al = _alpha(name)
    tex = al.shape[1] / al.shape[0]
    node = rect[2] / rect[3]
    if abs(tex - node) / tex > 0.01:
        raise SystemExit(
            f"{name}: node rect {rect[2]}x{rect[3]} (ratio {node:.4f}) does not match "
            f"the texture's {al.shape[1]}x{al.shape[0]} (ratio {tex:.4f}). "
            "That button is being stretched — fix it before cutting this one to fit.")


# --- The shape ----------------------------------------------------------------

def _inset(poly: list[tuple[float, float]], d: float) -> list[tuple[float, float]]:
    """Offsets a polygon inward by `d`, edge by edge.

    Each edge is pushed along its inward normal and consecutive edges are
    re-intersected, so the stroke keeps a constant width all the way around the
    slant and into the point. Shrinking the polygon toward its centroid instead
    would narrow the thin end faster than the thick one — the same class of
    mistake as scaling on one axis, which is what this file exists to undo.
    """
    n = len(poly)
    cx = sum(p[0] for p in poly) / n
    cy = sum(p[1] for p in poly) / n
    lines: list[tuple[float, float, float]] = []
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        dx, dy = x2 - x1, y2 - y1
        length = (dx * dx + dy * dy) ** 0.5
        if length == 0.0:
            continue
        nx, ny = -dy / length, dx / length
        if (cx - x1) * nx + (cy - y1) * ny < 0.0:  # point the normal inward
            nx, ny = -nx, -ny
        lines.append((nx, ny, nx * (x1 + nx * d) + ny * (y1 + ny * d)))

    out: list[tuple[float, float]] = []
    for i in range(len(lines)):
        a1, b1, c1 = lines[i - 1]
        a2, b2, c2 = lines[i]
        det = a1 * b2 - a2 * b1
        if abs(det) < 1e-9:
            continue  # parallel neighbours have no corner to place
        out.append(((c1 * b2 - c2 * b1) / det, (a1 * c2 - a2 * c1) / det))
    return out


def _gradient(size: tuple[int, int]) -> Image.Image:
    """The three-stop vertical ramp the body is painted with."""
    w, h = size
    stops = ((0.0, BODY_TOP), (BODY_SHEEN_AT, BODY_SHEEN), (1.0, BODY_BOTTOM))
    band = Image.new("RGB", (1, h))
    px = band.load()
    for y in range(h):
        t = y / max(1, h - 1)
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t <= t1 or t1 == 1.0:
                k = 0.0 if t1 == t0 else min(max((t - t0) / (t1 - t0), 0.0), 1.0)
                px[0, y] = tuple(int(round(c0[i] + (c1[i] - c0[i]) * k)) for i in range(3))
                break
    return band.resize((w, h), Image.NEAREST)


def main() -> None:
    _assert_aspect("SETTINGS BUTTON", SETTINGS_RECT)
    _assert_aspect("QUIT BUTTON", QUIT_RECT)

    # The two edges this piece has to nest between, in screen space.
    above_m, above_c = _edge_line("SETTINGS BUTTON", SETTINGS_RECT, "bot")
    below_m, below_c = _edge_line("QUIT BUTTON", QUIT_RECT, "top")

    # Offset vertically rather than perpendicular: at these slopes the two differ
    # by half a percent, and a vertical offset keeps the edges exactly parallel
    # to the neighbours they answer to.
    def top_y(x: float) -> float:
        return above_m * x + above_c + GUTTER

    def bot_y(x: float) -> float:
        return below_m * x + below_c - GUTTER

    if bot_y(APEX_X) <= top_y(APEX_X):
        raise SystemExit("the hole closes before the apex — move APEX_X left")

    # The flat left cut, leaning back off the viewport. Its bottom corner sits on
    # the rect's left edge; its top corner is however far right the cut's slope
    # carries it across the band's full thickness there.
    cut_bottom = (RECT_LEFT, bot_y(RECT_LEFT))
    run = (bot_y(RECT_LEFT) - top_y(RECT_LEFT)) / abs(LEFT_CUT_SLOPE)
    cut_top = (RECT_LEFT + run, top_y(RECT_LEFT + run))

    apex = (APEX_X, (top_y(APEX_X) + bot_y(APEX_X)) / 2.0)
    poly_screen = [
        cut_top,
        (TIP_START_X, top_y(TIP_START_X)),
        apex,
        (TIP_START_X, bot_y(TIP_START_X)),
        cut_bottom,
    ]

    # Screen space -> texture space. One pixel of bleed top and bottom, matching
    # how tightly the reference pennants sit in their own canvases.
    rect_top = min(p[1] for p in poly_screen) - FAMILY_SCALE
    rect_bottom = max(p[1] for p in poly_screen) + FAMILY_SCALE
    rect_w = APEX_X - RECT_LEFT
    rect_h = rect_bottom - rect_top
    tex_w = int(round(rect_w / FAMILY_SCALE))
    tex_h = int(round(rect_h / FAMILY_SCALE))
    poly = [((x - RECT_LEFT) / FAMILY_SCALE, (y - rect_top) / FAMILY_SCALE)
            for x, y in poly_screen]

    s = SUPERSAMPLE
    big = (tex_w * s, tex_h * s)
    img = Image.new("RGBA", big, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    def scaled(p):
        return [(x * s, y * s) for x, y in p]

    draw.polygon(scaled(poly), fill=STROKE + (255,))
    draw.polygon(scaled(_inset(poly, STROKE_WIDTH)), fill=KEYLINE + (255,))

    mask = Image.new("L", big, 0)
    ImageDraw.Draw(mask).polygon(
        scaled(_inset(poly, STROKE_WIDTH + KEYLINE_WIDTH)), fill=255)
    img.paste(_gradient(big), (0, 0), mask)

    out = img.resize((tex_w, tex_h), Image.LANCZOS)
    out.save(OUT_PATH)
    print(f"wrote {OUT_PATH} ({tex_w}x{tex_h})")

    _report(top_y, bot_y, rect_top, rect_h, rect_w)


def _report(top_y, bot_y, rect_top: float, rect_h: float, rect_w: float) -> None:
    """Prints what MainMenu.tscn needs, so the numbers are never hand-derived."""
    import math

    centre_m = ((bot_y(1.0) - bot_y(0.0)) + (top_y(1.0) - top_y(0.0))) / 2.0

    # The caption box spans text_indent..(width - tip_padding); centre it on the
    # band at its own midpoint rather than on the rect, which the taper has
    # pulled the band well off.
    indent, tip_pad = 226.0, 150.0
    cap_mid_x = RECT_LEFT + (indent + (rect_w - tip_pad)) / 2.0
    band_mid = (top_y(cap_mid_x) + bot_y(cap_mid_x)) / 2.0
    offset_y = band_mid - (rect_top + rect_h / 2.0)

    print("\n  MainMenu.tscn / TutorialButton:")
    print(f"    offset_left   = {RECT_LEFT}")
    print(f"    offset_top    = {rect_top:.1f}")
    print(f"    offset_right  = {RECT_LEFT + rect_w}")
    print(f"    offset_bottom = {rect_top + rect_h:.1f}")
    print(f"    text_offset_y = {offset_y:.1f}")
    print(f"    label_rotation = {math.degrees(math.atan(centre_m)):.2f}")
    print(f"    text_indent   = {indent}")
    print(f"    tip_padding   = {tip_pad}")
    print("\n  seam check (screen x -> band thickness, gutter is "
          f"{GUTTER:.0f}px by construction):")
    for x in (0.0, 150.0, 300.0, 450.0, TIP_START_X):
        print(f"    x={x:6.0f}   top={top_y(x):7.1f}  bottom={bot_y(x):7.1f}  "
              f"thickness={bot_y(x) - top_y(x):6.1f}")


if __name__ == "__main__":
    main()
