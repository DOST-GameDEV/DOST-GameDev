"""Emits scenes/maps/Eskinita.tscn.  (checklist 2.2 / Phase 8 — layout author)

    python tools/maps/build_eskinita.py        # run from the repo root

⚠️ THIS IS A DEV-TIME TOOL, NOT PART OF THE GAME. Godot never runs it, it ships
in no export, and it adds no runtime dependency — the project stays GDScript
only. It is committed for the same reason the mesh generator is: several hundred
dressing instances placed by hand are unmaintainable and unreviewable, and a
layout you cannot re-derive is a layout nobody will ever adjust.

EDIT THIS FILE, NOT THE SCENE. Re-running overwrites Eskinita.tscn wholesale.

A .tscn is hand-written text by policy (Concurrency_Protocol §6: an editor
re-save reorders properties and turns a two-line change into a 200-line diff).

Layout reasoning lives in docs/Art_Direction.md Part 6 (the environment pass).

===============================================================================
PHASE 8 — WHAT CHANGED, AND THE FOUR RULES THAT CAME OUT OF IT
===============================================================================

1.  ⚠️ **GROUND IS PLACED FIRST, AND NOTHING MAY BE EMITTED BEFORE IT.**
    Every prop asks `surfaces.height_at()` for its own base height. That query
    can only see what has already been recorded, so the road and the apron are
    built at the TOP of this file and everything else follows. The previous
    version placed the buildings, trees and posts BEFORE the road, so they all
    grounded against bare floor at 0.000 while the road they stood on rendered
    at 0.100 — 111 instances sunk 100 mm, invisible to a diff. Moving a block of
    placement code above the road block is now a real bug, not a formatting
    choice. `floorcheck` fails the build if it happens again.

2.  ⚠️ **NOTHING IS PLACED BY A HARDCODED Y. EVER.** `add()` and `add_kit()`
    both take a `base_y` that DEFAULTS TO THE GROUND UNDER THE PIECE. There is
    no call in this file that passes a literal height except the sampay lines,
    which are `suspended=True` and say so.

3.  ⚠️ **NO DIMENSION OF A KIT PIECE IS ASSUMED — ALL THREE ARE MEASURED.**
    The old code measured `building-type-a`'s depth once and placed all eleven
    types as if they shared it. Five of them did not: three stood up to 0.87 m
    IN FRONT of the collision wall (you walked into a house and were stopped by
    nothing), one left a 0.28 m gap showing bare floor, and five were wider than
    their own 6.6 m bay so they grew through their neighbours by up to 2.5 m.
    `piece_extent()` below returns a piece's real world-space footprint for the
    yaw and scale it is actually being placed at, and the building row uses it
    for BOTH face alignment and bay advance.

4.  ⚠️ **THE LANE LAW.** `assert_clear_of_lane()` rejects, at build time, any
    dressing inside the throwing corridor. See its docstring.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from floorcheck import Surfaces, embed_y, mesh_bounds  # noqa: E402

# --- The one height every surface on this map shares --------------------------
#
# ⚠️ THE FLOOR'S COLLISION TOP AND THE PAVING TOP ARE THE SAME NUMBER NOW, AND
# THEY WERE NOT BEFORE. The Floor box's top was 0.000 while the kit road tiles on
# top of it rendered to 0.100, which means every character on this map stood with
# its feet 100 mm INSIDE the visible road. That is the sunk-prop bug on the one
# surface a player touches every single frame, and it also put a 100 mm lip
# wherever the paving stopped. Both go away by paving and floor agreeing.
ROAD_SCALE = 4.0                     # kit road is 1x1x0.025; 4x gives 4-unit slabs
ROAD_TOP = 0.025 * ROAD_SCALE        # = 0.100
GROUND_Y = ROAD_TOP                  # bare floor top == paved top. One surface.

surfaces = Surfaces(base_height=GROUND_Y)

W = 8.0          # half-width of the playable alley, and of the paved core
Z_END = 23.0     # half-length
## ⚠️ THE ALLEY'S ENDS ARE CLOSED BY A CROSS ROW, and that is what the "huge
## empty space" report was. The house rows used to stop at z = +/-17 while the
## paving and the apron ran on to +/-26, so both ends of the street opened into a
## bare grey plain with the silhouette belt floating beyond it. A real eskinita
## does not end; it meets another street. `CROSS_ROW_Z` puts a terrace across
## each end, facing back down the alley, which closes the view and turns the end
## of the map into a T-junction instead of a void.
CROSS_ROW_Z = 26.0

# ⚠️ THE HOUSE FRONTS LAND ON THE COLLISION PLANE, NOT 0.6 m BEHIND IT.
# `Bounds/WallEast|West` sit at x = ±8.6 and are the only thing a player can
# actually hit. The old code aligned facades to ±8.0, so there was a 600 mm shell
# of walkable space INSIDE every visible wall — you pressed into the house and
# stopped in mid-air short of it. The colliders are untouched; the ART moved out
# to meet them.
WALL_FACE_X = 8.6

meshes, ext, order = {}, [], []


def is_kit(name):
    """Kit pieces are given as 'kits/<kit>/<piece>' and are .glb SCENES.

    ⚠️ The distinction is load-bearing all the way through this file. A
    generated `env_*` piece imports as a Mesh and is emitted as a MeshInstance3D
    with `mesh = ExtResource(...)`; a `.glb` imports as a PackedScene and has to
    be emitted as an `instance=ExtResource(...)` node instead. Get it the wrong
    way round and Godot loads the scene with that node simply missing.
    """
    return name.startswith("kits/")


def mesh_path(name):
    return (f"res://assets/models/{name}.glb" if is_kit(name)
            else f"res://assets/models/env_{name}.obj")


def mesh(name):
    if name not in meshes:
        meshes[name] = str(len(meshes) + 1)
        ext.append((meshes[name], mesh_path(name), is_kit(name)))
    return meshes[name]


def xform(x, y, z, yaw=0.0, sx=1.0):
    # sx scales only the mesh's own local-X row (its authored length axis for
    # every line-shaped decal in this file — see _box() calls in env_kit.gd),
    # leaving Y/Z untouched. Lets a straight decal be shortened/lengthened
    # without a new mesh asset.
    c, s = math.cos(yaw), math.sin(yaw)
    return (f"Transform3D({c * sx:.5f}, 0, {-s * sx:.5f}, 0, 1, 0, {s:.5f}, 0, {c:.5f}, "
            f"{x:.4f}, {y:.4f}, {z:.4f})")


def xform_uniform(x, y, z, yaw, s):
    """A uniformly-scaled yaw transform.

    Distinct from `xform()` on purpose: that one scales ONLY the mesh's local X
    row, which is what a stretchable line decal needs and what a building must
    never get — a non-uniform scale on a house shears its roof.
    """
    c, sn = math.cos(yaw), math.sin(yaw)
    return (f"Transform3D({c * s:.5f}, 0, {-sn * s:.5f}, 0, {s:.5f}, 0, "
            f"{sn * s:.5f}, 0, {c * s:.5f}, {x:.4f}, {y:.4f}, {z:.4f})")


# --- Measurement, not assumption ---------------------------------------------

def piece_extent(mesh_name, yaw=0.0, scale=1.0):
    """World-space footprint offsets of a piece, relative to its placement origin.

    Returns (dx_lo, dx_hi, dz_lo, dz_hi, dy_lo, dy_hi). Placing the piece at
    (x, z) puts its footprint at x+dx_lo .. x+dx_hi and z+dz_lo .. z+dz_hi.

    ⚠️ THIS EXISTS BECAUSE THE OLD CODE MEASURED ONE BUILDING AND PLACED ELEVEN.
    Every "how wide/deep is this thing" question in this file goes through here,
    at the yaw and scale the piece is ACTUALLY being placed at, because a kit
    building rotated a quarter turn swaps the two axes and half the bugs in
    Art_Direction §8.0 came from a depth being measured on the wrong one.

    Kept in step with `xform_uniform()`/`_to_world()` by construction: the X
    basis is (cos*s, 0, -sin*s) and the Z basis is (sin*s, 0, cos*s).
    """
    lo, hi = mesh_bounds(mesh_name)
    c, sn = math.cos(yaw), math.sin(yaw)
    xs, zs = [], []
    for lx in (lo[0], hi[0]):
        for lz in (lo[2], hi[2]):
            xs.append((lx * c + lz * sn) * scale)
            zs.append((-lx * sn + lz * c) * scale)
    return (min(xs), max(xs), min(zs), max(zs), lo[1] * scale, hi[1] * scale)


# --- The lane law -------------------------------------------------------------
#
# Art_Direction.md Part 6 §8.2. The two throwing lanes are the corridor an
# attacker actually throws down and the corridor a defender scrambles back up.
# Anything standing in them — at ANY height, because a slipper arcs — turns a
# skill shot into a coin flip.
LANE_HALF_X = 2.5     # the protected corridor, |x| <= this ...
LANE_Z = 7.0          # ... for |z| <= this (both throwing lines are at z = ±6)
LANE_MARGIN = 1.0     # new dressing keeps this much clear of the corridor edge


def assert_clear_of_lane(name, x, z, extent):
    """Build failure if a piece of dressing intrudes on a throwing lane.

    ⚠️ A COMMENT SAYING "KEEP THE LANES CLEAR" IS NOT A RULE, IT IS A HOPE.
    Phase 8 adds several hundred props to a map that had fourteen, so the odds
    of one landing in the corridor by arithmetic rather than by intent went from
    negligible to near-certain. This is checked against the piece's real
    footprint, not its origin, because a 2 m wide cart placed at x=3.6 is inside
    the lane even though its centre is not.
    """
    x0, x1, z0, z1 = x + extent[0], x + extent[1], z + extent[2], z + extent[3]
    if z1 < -LANE_Z or z0 > LANE_Z:
        return
    if x1 < -(LANE_HALF_X + LANE_MARGIN) or x0 > (LANE_HALF_X + LANE_MARGIN):
        return
    raise SystemExit(
        "\nLANE LAW VIOLATION — build aborted, scene NOT written.\n"
        "Art_Direction.md Part 6 §8.2.\n\n"
        "  %s occupies x %.2f..%.2f, z %.2f..%.2f, which enters the protected\n"
        "  throwing corridor (|x| <= %.1f + %.1f margin, |z| <= %.1f).\n\n"
        "Move it to |x| > %.1f. Dressing never enters a throwing lane, at any\n"
        "height — a slipper arcs, so 'it is short enough to throw over' is not a\n"
        "defence.\n" % (name, x0, x1, z0, z1, LANE_HALF_X, LANE_MARGIN, LANE_Z,
                        LANE_HALF_X + LANE_MARGIN))


# --- Placement ----------------------------------------------------------------

def add(parent, name, mesh_name, x, z, yaw=0.0, sx=1.0, base_y=None,
        suspended=False, lane_exempt=False):
    """Places a generated `env_*` piece, GROUNDED on whatever is under it.

    ⚠️ `base_y` DEFAULTS TO THE GROUND, and that default is the whole point.
    This used to take a raw `y` and every caller passed 0.0, so when checklist
    7.4b raised the walkable surface to 0.100 the entire dressing set stayed
    behind, buried. A prop's vertical position is now a derived value; passing
    one by hand is possible but has to be deliberate and is worth a comment.
    """
    if base_y is None:
        base_y = surfaces.height_at(x, z)
    lo, _hi = mesh_bounds(mesh_name)
    y = base_y - lo[1]
    extent = piece_extent(mesh_name, yaw, 1.0)
    if not lane_exempt:
        assert_clear_of_lane(name, x, z, extent)
    order.append((parent, name, mesh(mesh_name), xform(x, y, z, yaw, sx)))
    surfaces.record(name, mesh_name, x, y, z, yaw, sx, is_marking=False,
                    group=parent.split("/")[-1], suspended=suspended)


def add_kit(parent, name, mesh_name, x, z, yaw=0.0, scale=1.0, base_y=None,
            lane_exempt=False):
    """Places a kit piece with its BASE on the ground, scaled uniformly.

    ⚠️ KIT PIECES DO NOT SHARE THE GENERATED KIT'S "ORIGIN AT THE BASE" HABIT,
    and the fix for that had its own bug. `env_*` meshes are authored from local
    y=0 up. Kenney's are not consistent about it, so this derives the offset from
    the mesh's own measured bounds — but until 2026-07-29 `floorcheck` measured
    those bounds from raw glTF ACCESSORS and ignored the node hierarchy. Every
    Car Kit vehicle is five nodes with the wheels translated +0.30 up, so the
    measured base read -0.300 when the real base was 0.000 and this function
    dutifully lifted every van, taxi and truck by 0.3 * 1.75 = 525 mm of hover.
    Fixed in `_glb_bounds`; recorded here because THIS is where it showed up.
    """
    if base_y is None:
        base_y = surfaces.height_at(x, z)
    extent = piece_extent(mesh_name, yaw, scale)
    if not lane_exempt:
        assert_clear_of_lane(name, x, z, extent)
    y = base_y - extent[4]
    order.append((parent, name, mesh(mesh_name),
                  xform_uniform(x, y, z, yaw, scale)))
    surfaces.record(name, mesh_name, x, y, z, yaw, scale, is_marking=False,
                    uniform=True, group=parent.split("/")[-1])


def add_mark(name, mesh_name, x, z, yaw=0.0, sx=1.0):
    """A field marking, embedded in whatever surface is under it.

    Separate from `add()` on purpose: a marking is paint and lives INSIDE the
    ground (floorcheck's sandwich rule), while a prop is an object and sits ON
    it. Two different vertical rules, so two different functions.
    """
    y = embed_y(surfaces.height_at(x, z), mesh_name)
    order.append((parent_mark, name, mesh(mesh_name), xform(x, y, z, yaw, sx)))
    surfaces.record(name, mesh_name, x, y, z, yaw, sx, is_marking=True)


parent_mark = "Markings"

# ⚠️ ONE SCALE PER KIT, NAMED. Art_Direction.md §0b's measured table: every kit
# is authored at a different native scale and none matches this project's
# 1 unit = 1 metre. Two pieces from one kit at different scales is the "assets
# suck" failure in its purest form, so the factor lives here, once, per kit.
CITY_SCALE = 5.0   # a City Kit house is 0.74-1.24 tall natively -- SHORTER than
                   # a Person. 5x puts it at 2-3 believable storeys.
CAR_SCALE = 1.75   # a van is 2.75 long / 1.45 tall natively; 1.75x reaches the
                   # ~4.8 length a real one has against a 1.6-unit Person.
TOWN_SCALE = 1.6   # Fantasy Town props (carts, stalls, rocks, planks) are the
                   # nearest kit to 1u=1m already; 1.6 matches a 1.6-unit Person.

# =============================================================================
# GROUND FIRST. Nothing above this line places anything that stands on the road.
# =============================================================================

# --- Ring 0 / Ring 1: the paved world ----------------------------------------
#
# Ring 0 is the Floor box itself, widened 40 -> 120 in the scene header below.
# Ring 1 is this: real kit paving, tiled at ONE scale so the texture density is
# identical everywhere (explicit human call, 2026-07-29 — "use tiled road
# instances so the texture resolution matches perfectly"). It runs well past the
# collision walls, because the void the player could see started right behind
# them.
#
# ⚠️ EVERY TILE IS THE SAME SCALE AND THEREFORE THE SAME HEIGHT. A coarser tile
# further out would halve the instance count and put a 100 mm step across the
# map at the seam, which is the exact fault Phase 8 exists to remove.
APRON_X = 30.0
APRON_Z = 32.0
## ⚠️ THE PAVING'S TOP MUST LAND ON GROUND_Y, SO ITS BASE GOES A THICKNESS BELOW.
## Passing `base_y=GROUND_Y` here instead — which is the obvious-looking thing to
## write — stands every tile 100 mm proud of the floor it is paving, and the very
## first run of this file did exactly that. `add_kit` places a BASE; the height
## everything else on the map cares about is the TOP.
ROAD_BASE_Y = GROUND_Y - ROAD_TOP
## Seeded quarter-turns. A 1x1 square tile rotated 90° re-uses the same texels at
## the same density, so this breaks up the "one huge tiled plane" read without
## introducing a second tile size — which is what the city kit's driveway/path
## pieces would have done (they are 0.36x0.40 against road's 1.0x1.0 and would
## have left holes in the grid). Human call, 2026-07-29: "use tiled road
## instances so the texture resolution matches perfectly."
_ROAD_YAW = [0, 1, 3, 2, 0, 3, 1, 2, 3, 0, 2, 1, 1, 3, 0, 2]
_road_n = 0
_gx = -APRON_X + ROAD_SCALE * 0.5
while _gx <= APRON_X:
    _gz = -APRON_Z + ROAD_SCALE * 0.5
    while _gz <= APRON_Z:
        add_kit("Dressing/Road", f"Road_{_road_n}", "kits/town/road", _gx, _gz,
                _ROAD_YAW[_road_n % len(_ROAD_YAW)] * math.pi * 0.5,
                ROAD_SCALE, base_y=ROAD_BASE_Y, lane_exempt=True)
        _road_n += 1
        _gz += ROAD_SCALE
    _gx += ROAD_SCALE

# --- Layer 1: the wall line the player actually touches ----------------------
#
# An eskinita is the gap BETWEEN people's houses, so the houses are the wall.
# Buildings are rotated a quarter turn so their long axis runs down the alley.
#
# ⚠️ FACE ALIGNMENT AND BAY ADVANCE ARE BOTH MEASURED PER PIECE. See rule 3 in
# the module header for what happened when they were not. `yaw` is ±90°, so a
# piece's local Z becomes world X (its depth) and its local X becomes world Z
# (its width) — `piece_extent()` does that arithmetic rather than this loop.
#
# ⚠️ DRESSING CARRIES NO COLLISION, HERE OR ANYWHERE. The one invisible Bounds
# box ring is still the only thing a player can hit. Every piece below is a
# visual instance and nothing more — which is also why the camera's spring arm
# (mask 1) cannot catch on any of it.
BUILDING_TYPES = ["a", "c", "e", "j", "b", "o", "d", "s", "i", "n", "l"]
# ⚠️ TIGHT. Playtest 2026-07-29 showed wide bare gaps between houses (with a
# screenshot circling one). A Philippine residential street is built shoulder to
# shoulder; 1.1m of daylight between every pair of houses read as a film set with
# missing pieces. 0.35 leaves just enough to see the wall thickness.
BAY_GAP = 0.35              # alley-side alcove between neighbours, in metres
## Every Nth bay is left empty and gets a parked vehicle instead — a driveway.
## It is also what stops the wall line reading as one extruded ribbon.
DRIVEWAY_EVERY = 4

CARS = ["kits/car/van", "kits/car/sedan", "kits/car/delivery",
        "kits/car/taxi", "kits/car/truck"]

_bay = {-1.0: -Z_END, 1.0: -Z_END}   # each side advances independently now
_i = {-1.0: 0, 1.0: 0}
for side in (-1.0, 1.0):
    tag = "E" if side > 0 else "W"
    # ⚠️⚠️ A CITY KIT BUILDING'S FRONT FACES ITS OWN LOCAL +Z. MEASURED, NOT GUESSED.
    #
    # Rendered `building-type-a` at yaw 0 from all four cardinal directions
    # (tools/facing_probe.gd): the +Z side carries the door, the porch planting
    # and the window detailing; the -Z side is a plainer elevation; and BOTH ±X
    # sides are blank gable walls with nothing on them at all.
    #
    # A yaw of +90 deg maps local +Z onto world +X. The previous code used
    # `+90 for the east row, -90 for the west`, which pointed the +Z front at +X
    # on the east side and at -X on the west side — i.e. **both rows had their
    # front doors facing away from the street**, presenting blank gable ends to
    # the alley. That is the reported "houses don't generate facing sideways or
    # away from the street".
    #
    # The alley lies toward -X from the east row and toward +X from the west row,
    # so the sign is simply the other way round: east row yaw -90 (front -> -X),
    # west row yaw +90 (front -> +X). Both rows now face each other across the
    # street, which is what a street IS.
    #
    # ⚠️ This also keeps `piece_extent()`-based face alignment honest: the surface
    # being aligned to WALL_FACE_X is now genuinely the facade rather than a
    # gable end, so "the front door sits on the collision plane" is true in the
    # literal sense.
    yaw = (-math.pi * 0.5) if side > 0 else (math.pi * 0.5)
    while _bay[side] <= Z_END:
        i = _i[side]
        if (i + (0 if side > 0 else 2)) % DRIVEWAY_EVERY == 0:
            car = CARS[i % len(CARS)]
            # ⚠️ PARALLEL-PARKED, NOT NOSE-IN, AND THE LANE LAW IS WHY.
            # Nose-in (yaw ±90°) turns the car's 4.8 m LENGTH into its world-X
            # footprint, which reaches 3.2 m from the alley centre — straight
            # through the throwing corridor. `assert_clear_of_lane()` failed the
            # build on the first run and named the car. At yaw 0 the length runs
            # down Z against the kerb, which is how a car is parked on a street
            # this narrow anyway, and its 2.6 m width stays outside the wall.
            cyaw = 0.0 if i % 2 else math.pi
            cext = piece_extent(car, cyaw, CAR_SCALE)
            cx = ((WALL_FACE_X - cext[0]) if side > 0
                  else (-WALL_FACE_X - cext[1]))
            add_kit("Dressing/Layer1", f"Car_{i}_{tag}", car, cx,
                    _bay[side] - cext[2], cyaw, CAR_SCALE)
            # ⚠️ A DRIVEWAY IS NOT A HOLE. The bay is deliberately empty of
            # HOUSE, but leaving it empty of everything is what read as the
            # street missing a tooth. A fence line plus a hedge closes the gap
            # at eye level while keeping the bay itself legible as a gap.
            _fz = _bay[side] - cext[2]
            add_kit("Dressing/BayFill", f"BayFence_{i}_{tag}",
                    "kits/city/fence" if i % 2 else "kits/city/fence-low",
                    side * (WALL_FACE_X + 0.15), _fz - 2.6,
                    0.0 if side > 0 else math.pi, CITY_SCALE * 0.8)
            add_kit("Dressing/BayFill", f"BayHedge_{i}_{tag}", "kits/town/hedge",
                    side * (WALL_FACE_X + 0.5), _fz + 2.6,
                    0.0, TOWN_SCALE)
            _bay[side] += (cext[3] - cext[2]) + BAY_GAP
        else:
            kind = BUILDING_TYPES[i % len(BUILDING_TYPES)]
            piece = f"kits/city/building-type-{kind}"
            ext_b = piece_extent(piece, yaw, CITY_SCALE)
            width = ext_b[3] - ext_b[2]
            # Solve for the centre X that lands THIS piece's own face exactly on
            # the collision plane. For the +X row the face is its minimum X, for
            # the -X row its maximum.
            cx = (WALL_FACE_X - ext_b[0]) if side > 0 else (-WALL_FACE_X - ext_b[1])
            add_kit("Dressing/Layer1", f"L1_{i}_{tag}", piece, cx,
                    _bay[side] - ext_b[2] , yaw, CITY_SCALE)
            _bay[side] += width + BAY_GAP
        _i[side] += 1

# --- The cross rows that close each end of the alley -------------------------
#
# Faces back down the street (toward the arena) so a player looking up the alley
# sees house fronts, not gable ends — same rule Layer 1 follows. Placed by the
# same measured face-alignment: solve for the centre that lands THIS piece's own
# face on CROSS_ROW_Z.
_CROSS_TYPES = ["e", "b", "o", "n", "c", "l", "d", "a", "s"]
_cx_n = 0
for _end in (-1.0, 1.0):
    _yaw = 0.0 if _end < 0 else math.pi   # front toward the arena centre
    _x = -16.0
    while _x <= 16.0:
        _piece = f"kits/city/building-type-{_CROSS_TYPES[_cx_n % len(_CROSS_TYPES)]}"
        _e = piece_extent(_piece, _yaw, CITY_SCALE)
        _cz = (CROSS_ROW_Z - _e[3]) if _end > 0 else (-CROSS_ROW_Z - _e[2])
        add_kit("Dressing/CrossRow", f"Cross_{_cx_n}", _piece, _x, _cz, _yaw,
                CITY_SCALE, lane_exempt=True)
        _cx_n += 1
        _x += (_e[1] - _e[0]) + 0.4

# --- Layer 2: a second row further out, for skyline depth --------------------
# Off-grid on purpose and deliberately NOT the same types as Layer 1 -- a second
# identical row reads as a mirror rather than as a neighbourhood.
# ⚠️ THESE FACE OUTWARD, AWAY FROM OUR ALLEY, AND THAT IS DELIBERATE.
# Real blocks are built back-to-back: the row behind these houses fronts onto the
# NEXT street over, not onto ours. Facing them inward would give the alley two
# competing front rows and read as a film set. A small yaw jitter keeps the row
# from looking extruded — see the seeded-not-random rule.
_L2_JIT = [0.09, -0.14, 0.05, -0.07, 0.12, -0.03]
for n, (x, zz, kind) in enumerate([
        (-19.5, -14.0, "t"), (-21.0, -3.0, "q"), (-19.0, 8.0, "u"),
        (-21.5, 17.0, "f"), (19.5, -15.0, "p"), (21.0, -4.0, "r"),
        (19.0, 7.0, "k"), (21.5, 16.0, "m"),
        (-20.0, -22.0, "b"), (20.0, -21.0, "d"), (-20.5, 24.0, "n"),
        (20.5, 23.0, "s")]):
    out_yaw = (math.pi * 0.5) if x > 0 else (-math.pi * 0.5)
    add_kit("Dressing/Layer2", f"L2_{n}", f"kits/city/building-type-{kind}",
            x, zz, out_yaw + _L2_JIT[n % len(_L2_JIT)], CITY_SCALE)

# --- Ring 2: the silhouette belt. Read at distance through fog, never reached.
#
# ⚠️ SEEDED, NEVER RANDOM. A layout that differs between two runs of this file
# cannot be reviewed in a diff and cannot be bisected when something floats.
# The jitter below is a fixed table, not an RNG.
# ⚠️ DELIBERATELY QUIET, AND SMALLER THAN IT WAS. Human call, 2026-07-29: the
# background "feels overwhelming and ugly for no reason". Phase 8 had THREE
# building rings at 30/37/44 scaled up to 1.55x plus THREE tree rings — roughly
# 300 instances of loud, fully-saturated silhouette stacked directly behind the
# play space, competing with the characters for attention and costing draw calls
# for scenery nobody looks at.
#
# Two rings now, further out, at closer to native scale, and faded harder toward
# the fog colour in env_toon_pass.gd. The job of this layer is to make the
# horizon opaque, not to be looked at.
#
# ⚠️ SEEDED, NEVER RANDOM. A layout that differs between two runs of this file
# cannot be reviewed in a diff and cannot be bisected when something floats.
BELT_TYPES = ["b", "d", "n", "q", "t", "u", "f", "p", "r", "k", "m", "s", "a"]
_belt_jit = [0.0, 2.7, -1.9, 4.1, -3.3, 1.4, -2.2, 3.6, -0.8, 2.1, -4.0, 0.6]
_belt = 0
for ring_i, ring in enumerate((32.0, 41.0)):
    step = 11.0 + ring_i * 2.0
    for side in (-1.0, 1.0):
        zz = -46.0
        while zz <= 46.0:
            j = _belt_jit[_belt % len(_belt_jit)]
            add_kit("Dressing/Belt", f"BeltX_{_belt}",
                    f"kits/city/building-type-{BELT_TYPES[_belt % len(BELT_TYPES)]}",
                    side * (ring + j * 0.35), zz + j,
                    # Fronts turned along the ring so the belt reads as streets
                    # rather than as a wall of blank gable ends.
                    (j * 0.11) + ((math.pi * 0.5) if side > 0 else (-math.pi * 0.5)),
                    CITY_SCALE * (1.0 + ring_i * 0.15))
            _belt += 1
            zz += step
        xx = -46.0
        while xx <= 46.0:
            j = _belt_jit[_belt % len(_belt_jit)]
            add_kit("Dressing/Belt", f"BeltZ_{_belt}",
                    f"kits/city/building-type-{BELT_TYPES[_belt % len(BELT_TYPES)]}",
                    xx + j, side * (ring + j * 0.35),
                    (j * 0.13) + (0.0 if side > 0 else math.pi),
                    CITY_SCALE * (1.0 + ring_i * 0.15))
            _belt += 1
            xx += step

# One tree ring, not three, and only in the seam between the two building rings.
_tree_n = 0
for side in (-1.0, 1.0):
    t = -44.0
    while t <= 44.0:
        j = _belt_jit[_tree_n % len(_belt_jit)]
        add_kit("Dressing/Belt", f"BeltTreeX_{_tree_n}", "kits/city/tree-large",
                side * (36.5 + j * 0.3), t + j * 1.3, j * 0.2, CITY_SCALE * 1.15)
        _tree_n += 1
        add_kit("Dressing/Belt", f"BeltTreeZ_{_tree_n}", "kits/city/tree-large",
                t + j * 1.1, side * (36.5 + j * 0.3), -j * 0.2, CITY_SCALE * 1.15)
        _tree_n += 1
        t += 15.0

# --- Street trees, between the houses and the kerb ---------------------------
# Pushed OUT to sit against the wall line rather than at x=±7.4, where they were
# standing inside the playable width. Still tall, so they must not be loose.
for n, zz in enumerate([-15.5, -9.0, -2.5, 4.0, 10.5, 16.0]):
    for side in (-1.0, 1.0):
        piece = "kits/city/tree-large" if (n + (0 if side > 0 else 1)) % 2 else "kits/city/tree-small"
        add_kit("Dressing/Layer2", f"Tree_{n}_{'E' if side > 0 else 'W'}",
                piece, side * (W - 0.15), zz + (0.7 if side > 0 else -0.7),
                (n % 3) * 0.8, CITY_SCALE)

# --- Layer 3: overhead. Highest read-per-triangle in the kit. ---------------
# ⚠️⚠️ THE WIRE SPAN IS 6.0 AND THE POST SPACING MUST EQUAL IT, OR THE WIRES
# HANG IN MID-AIR. Playtest 2026-07-29: "the electric pole wires ... are just
# floating in the air ... connect the electric pole wires to the poles."
#
# `env_kit.gd::_post_electric()` draws its service wire from its own cross-arm to
# where the NEXT post would be — a fixed 6.0 units along the mesh's local +X —
# precisely so a row of them strings itself together with no per-instance work.
# That only holds if consecutive posts on the SAME side are exactly 6.0 apart and
# share a yaw. The previous layout alternated sides every 4.0 units with the yaw
# flipping per side, so no post's wire ever reached another post: every span
# ended in empty air, twice per post.
#
# Local +X maps to world (cos y, 0, -sin y), so yaw = -pi/2 sends the wire toward
# +Z, i.e. straight down the alley. The last post on each side is emitted from
# the same row but its wire simply overshoots the end of the street, which reads
# as the line continuing out of the map — correct, and better than stopping dead.
POST_SPAN = 6.0          # must match _post_electric()'s own wire length
POST_YAW = -math.pi * 0.5
_pn = 0
for side in (-1.0, 1.0):
    zz = -15.0
    while zz <= 16.0:
        add("Dressing/Layer3", f"Post_{_pn}", "post_electric",
            side * (W - 0.25), zz, POST_YAW)
        _pn += 1
        zz += POST_SPAN

# Sampay: strung ACROSS the alley, hanging from the houses. The ONE thing on
# this map that is legitimately not on the ground — hence `suspended`, which is
# an explicit opt-out of the grounding check rather than a hole in it.
# ⚠️ ONE LINE PER POST PAIR, AT THE POSTS' OWN Z. Playtest 2026-07-29: the
# anchors still floated. Burying the ends in the facades was only half the
# answer, because a sampay at an arbitrary z can land on a DRIVEWAY BAY where
# there is no wall to bury into. Strung between the two posts instead — they are
# already at matching z on both sides, they are the tallest thing on the street,
# and a washing line tied to the electric posts is what an eskinita actually
# looks like. SAMPAY_Z is therefore derived from the post row, never typed.
SAMPAY_Z = [-15.0, -9.0, -3.0, 3.0, 9.0, 15.0]
for n, zz in enumerate(SAMPAY_Z):
    add("Dressing/Layer3", f"Sampay_{n}", "laundry_line", 0.0, zz,
        # ⚠️ RAISED. A Person is 1.6 tall standing on ground at 0.1, so the top
        # of the head is ~1.70 — and the lowest garment hem used to sit at
        # 1.58, which is why heads phased through the washing. This puts the
        # hem at ~2.35, clear of a head and still low enough to read as
        # laundry rather than as bunting.
        base_y=GROUND_Y + 2.25 + (0.22 if n % 3 == 0 else 0.0),
        suspended=True, lane_exempt=True)

# --- Interior clutter. HEAVY on the sides, ZERO in the lanes. ----------------
#
# Explicit human call, 2026-07-29: "go heavy on the clutter on the sides, but
# STRICTLY enforce your new lane law". Both halves of that are enforced by code
# rather than by care: every entry below goes through `assert_clear_of_lane()`,
# which measures the piece's real footprint and fails the build on contact.
#
# ⚠️ THE HEIGHT LAW STILL APPLIES INSIDE THE SAFE BAND (Part 3 §2). An FPP
# Person's eye is at y=1.25 above the ground. Anything in the 3.5..6.5 band is
# <= 1.0 tall so it can be aimed over; the taller stuff lives at |x| > 6.5,
# against the wall line, where a throwing arc has already left the ground.
#
# Format: (piece, x, z, yaw, kit_scale or None for a generated env_* piece)
CLUTTER_LOW = [
    # --- generated env_* pieces, the ones that carry the project's own palette
    ("crate_stack", -5.5, -9.0, 0.4, None), ("crate_stack", 5.0, 8.5, -0.9, None),
    ("crate_stack", -4.6, 13.5, 1.7, None), ("crate_stack", 5.9, -14.5, 2.6, None),
    ("tire", -6.2, 3.0, -2.1, None), ("tire", 6.4, -6.0, 0.4, None),
    ("tire", -6.0, 12.0, -0.9, None), ("tire", 4.3, 15.5, 1.7, None),
    ("tire", -3.9, -15.5, 2.6, None), ("tire", 6.1, 4.4, -2.1, None),
    ("oil_drum", 6.0, 11.0, 0.4, None), ("oil_drum", -6.4, -14.0, -0.9, None),
    ("oil_drum", 5.4, -2.6, 1.7, None), ("oil_drum", -5.1, 8.0, 2.6, None),
    ("monobloc_chair", 5.6, -11.5, -2.1, None), ("monobloc_chair", -5.2, 6.0, 0.4, None),
    ("monobloc_chair", -6.1, -4.4, -0.9, None), ("monobloc_chair", 6.3, 14.0, 1.7, None),
    ("monobloc_chair", 4.4, -16.2, 2.6, None),
    ("bollard", -6.8, -2.0, 0.0, None), ("bollard", 6.8, 2.0, 0.0, None),
    ("bollard", -6.9, 10.5, 0.0, None), ("bollard", 6.9, -9.5, 0.0, None),
    ("tire", -6.6, -11.8, 0.9, None), ("tire", 6.6, 17.0, -1.4, None),
    # --- Fantasy Town kit: the market-street vocabulary
    ("kits/town/rock-small", -6.3, -6.8, 0.5, TOWN_SCALE),
    ("kits/town/rock-small", 6.2, 6.2, -1.1, TOWN_SCALE),
    ("kits/town/rock-wide", -5.8, 16.5, 2.2, TOWN_SCALE),
    ("kits/town/rock-wide", 5.7, -17.0, -0.4, TOWN_SCALE),
    ("kits/town/planks", -6.5, 0.5, 1.5, TOWN_SCALE),
    ("kits/town/planks", 6.5, -12.5, -1.6, TOWN_SCALE),
    ("kits/town/planks", -4.8, -1.9, 0.2, TOWN_SCALE),
    ("kits/town/stall-stool", 5.2, 12.2, 0.8, TOWN_SCALE),
    ("kits/town/stall-stool", -5.4, -12.6, -0.6, TOWN_SCALE),
    ("kits/town/stall-stool", 4.7, -5.1, 2.4, TOWN_SCALE),
    ("kits/town/stall-bench", -6.0, 4.6, 1.55, TOWN_SCALE),
    ("kits/town/stall-bench", 6.1, -0.8, -1.55, TOWN_SCALE),
]
for n, (piece, x, zz, yaw, scale) in enumerate(CLUTTER_LOW):
    if scale is None:
        add("Dressing/Clutter", f"Clutter_{n}", piece, x, zz, yaw)
    else:
        add_kit("Dressing/Clutter", f"Clutter_{n}", piece, x, zz, yaw, scale)

# --- Taller clutter: against the wall line only, |x| > 6.5 -------------------
CLUTTER_TALL = [
    ("kits/town/cart", -7.2, -7.5, 0.15, TOWN_SCALE),
    ("kits/town/cart", 7.3, 10.5, math.pi + 0.2, TOWN_SCALE),
    ("kits/town/cart-high", -7.1, 5.5, -0.1, TOWN_SCALE),
    ("kits/town/stall", 7.4, -3.5, -math.pi * 0.5, TOWN_SCALE),
    ("kits/town/stall-red", -7.4, 11.5, math.pi * 0.5, TOWN_SCALE),
    ("kits/town/stall-green", 7.4, 16.0, -math.pi * 0.5, TOWN_SCALE),
    ("kits/town/hedge", -7.5, -16.5, 0.0, TOWN_SCALE),
    ("kits/town/hedge", 7.5, -15.5, 0.0, TOWN_SCALE),
    ("kits/town/fence-broken", -7.6, 1.5, math.pi * 0.5, TOWN_SCALE),
    ("kits/town/fence", 7.6, 6.5, math.pi * 0.5, TOWN_SCALE),
    ("kits/town/lantern", -7.3, -3.0, 0.0, TOWN_SCALE),
    ("kits/town/lantern", 7.3, 13.0, 0.0, TOWN_SCALE),
    ("kits/town/pillar-wood", -7.5, 8.5, 0.0, TOWN_SCALE),
    ("kits/town/rock-large", 7.5, -10.5, 0.7, TOWN_SCALE),
]
for n, (piece, x, zz, yaw, scale) in enumerate(CLUTTER_TALL):
    add_kit("Dressing/Clutter", f"Tall_{n}", piece, x, zz, yaw, scale)

# --- Tricycles. Waist-cover tier, against the wall line, never loose. --------
for n, (x, zz, yaw) in enumerate([
        (-7.0, -6.0, 0.15), (7.0, 9.5, math.pi + 0.2), (-6.9, 15.0, -0.1),
        (7.1, -13.0, math.pi - 0.3)]):
    add("Dressing/Clutter", f"Tricycle_{n}", "tricycle", x, zz, yaw)

# --- The narrative centre. A wall with a counter in it is a street. ----------
add("Dressing/Clutter", "SariSari_E", "sari_sari_store", W - 0.85, -1.0,
    -math.pi * 0.5)
add("Dressing/Clutter", "SariSari_W", "sari_sari_store", -(W - 0.85), 12.0,
    math.pi * 0.5)

# --- The kanal. This REPLACES the pink jeepney-lane chalk. -------------------
#
# ⚠️ 2026-07-29, EXPLICIT HUMAN INSTRUCTION: "completely remove and delete all
# pink chalk lines and their generation logic ... do not render them at all."
# `env_jeepney_lane_decal` was the only piece on this map using the `hazard`
# material (#F468A8), it ran z=-6..+6 at x=4.07..6.33, and that band crosses the
# confinement box's whole east edge — which is exactly the reported "the pink
# lines overshoot and merge with the white lines". It is gone, and so is its
# `_jeepney_lane_decal()` generator in env_kit.gd.
#
# ⚠️ BUT THE `HazardZone` AT x=5.4 IS A LIVE GAMEPLAY VOLUME (speed_multiplier
# 0.5, permanent) AND THE PINK STRIP WAS ITS ONLY TELL. Deleting the marking and
# stopping there would have left an INVISIBLE slow-field in the play area, which
# is a worse bug than the one being fixed. So the hazard keeps a visual — as
# real 3D geometry rather than chalk: a `gutter_tile` kanal, which is what a
# Philippine side street actually has running along its edge and which explains
# the slow zone physically instead of decorating it. Same footprint, no pink,
# no chalk, and it reads at a glance.
_kanal_lo, _kanal_hi = mesh_bounds("gutter_tile")
_kanal_len = _kanal_hi[2] - _kanal_lo[2]
_kn = 0
_kz = -5.5
while _kz < 5.5:
    add("Hazards/KanalVisual", f"Kanal_{_kn}", "gutter_tile", 5.4,
        _kz + _kanal_len * 0.5, 0.0, base_y=GROUND_Y - 0.15)
    _kn += 1
    _kz += _kanal_len

# =============================================================================
# FIELD MARKINGS. One court, one width, closed corners.
# =============================================================================
#
# ⚠️ EVERY MARKING SITS FLUSH IN WHATEVER IS UNDER IT, AND YOU NO LONGER HAVE TO
# GET THAT RIGHT BY HAND. `surfaces.verify()` samples the real footprint of every
# marking against the real height of everything beneath it and ABORTS THE BUILD
# if any of them floats, sticks out or spans a step.
#
# ⚠️ THE COURT HAS ONE WIDTH NOW, AND THAT IS THE FIX FOR "THE LINES SHOOT PAST".
# The old layout had four different line lengths — the confinement box at ±5.0,
# the throwing lines at ±4.0, the team-side lines at ±3.0, and the pink lane
# running past all of them — so nothing lined up with anything and no shape
# closed. Every white line is now clamped to COURT_X, so the box, the throwing
# lines and the team lines share one edge and read as a single court.
## Every long side of the court is drawn with this mesh, so it is also the
## width every cross-line must overlap INTO to close a corner. See court_line().
SIDE_LINE_MESH = "team_side_decal"
CONFINEMENT_BOX_RADIUS = 5.0   # mirrors CharacterBase.CONFINEMENT_RADIUS
COURT_X = CONFINEMENT_BOX_RADIUS


def add_line(name, mesh_name, x, z, yaw=0.0, sx=1.0):
    """A straight line marking, SPLIT AUTOMATICALLY wherever the ground steps.

    ⚠️ USE THIS FOR EVERY LINE MARKING. Placing one with a hand-picked Y is the
    decision that produced a floating line in three separate playtests.

    Walks the line's own length, asks `surfaces` how high the ground actually is
    at each step, and emits one sub-piece per run of constant height. A line that
    never crosses a step comes out as a single piece with the same name it would
    have had, so this costs nothing where it is not needed — which, now that the
    floor and the paving are the same height, is everywhere on this map.
    """
    lo, hi = mesh_bounds(mesh_name)
    span = hi[0] - lo[0]
    length = span * sx
    steps = max(2, int(length / 0.01) + 1)
    c, s = math.cos(yaw), math.sin(yaw)
    samples = []
    for i in range(steps):
        t = -0.5 + i / (steps - 1.0)
        d = t * length
        samples.append((t, round(surfaces.height_at(x + d * c, z - d * s), 6)))
    # ⚠️ The boundary goes at the MIDPOINT between two differing samples, not at
    # the first sample of the new height — ending a run on a sample that already
    # reads the NEW height pushes that run past the step and it floats there.
    runs, start, height, prev_t = [], samples[0][0], samples[0][1], samples[0][0]
    for t, h in samples[1:]:
        if h != height:
            edge = (prev_t + t) * 0.5
            runs.append((start, edge, height))
            start, height = edge, h
        prev_t = t
    runs.append((start, samples[-1][0], height))
    for n, (t0, t1, h) in enumerate(runs):
        mid = (t0 + t1) * 0.5
        run_len = (t1 - t0) * length
        if run_len <= 0.0:
            continue
        suffix = "" if len(runs) == 1 else "_%d" % n
        add_mark(name + suffix, mesh_name,
                 x + mid * length * c, z - mid * length * s, yaw, run_len / span)


def court_line(name, axis, at, half_len, mesh_name="team_side_decal"):
    """One edge of the court, scaled to land its ENDS exactly on `±half_len`.

    ⚠️ THIS IS WHY THE CORNERS USED TO HAVE NOTCHES IN THEM. The old confinement
    box tiled a fixed-length decal `ceil(2R / seg)` times per side, which put
    each side's outer end exactly ON the corner point — and since the crossing
    line is 80 mm wide and centred on that same point, the last 40 mm of every
    corner was never covered by either. Four little bites out of the box,
    reported as "the lines fail to intersect cleanly".
    #
    # Each side now runs to half_len + the crossing line's own half-width, so the
    # two edges overlap through the corner and the box closes. Overlapping paint
    # is invisible; a 40 mm gap is not.
    """
    lo, hi = mesh_bounds(mesh_name)
    # ⚠️ THE OVERLAP IS THE **CROSSING** LINE'S HALF-WIDTH, NOT THIS LINE'S OWN.
    # This used to use `(hi[2] - lo[2]) * 0.5` — the width of the line being
    # drawn — which is only correct when every line in the court is the same
    # mesh. `throwing_line_decal` is 0.12 wide against `team_side_decal`'s 0.08,
    # so a throwing line reached x = ±5.060 while the side line it terminates on
    # only spans 4.960..5.040. That is a 20mm overshoot poking out past the
    # court's own edge, at both ends of both throwing lines — measured, and
    # exactly the "overshoot the corners" report.
    side_lo, side_hi = mesh_bounds(SIDE_LINE_MESH)
    half_w = (side_hi[2] - side_lo[2]) * 0.5
    reach = half_len + half_w
    sx = (reach * 2.0) / (hi[0] - lo[0])
    if axis == "x":      # runs along X, sits at z = at
        add_line(name, mesh_name, 0.0, at, 0.0, sx)
    else:                # runs along Z, sits at x = at
        add_line(name, mesh_name, at, 0.0, math.pi * 0.5, sx)


# ⚠️⚠️ EVERY WHITE LINE IS AN EDGE OF A CLOSED RECTANGLE. NOTHING DANGLES.
#
# Human call, 2026-07-29, with a screenshot: "the white court lines are still
# broken. They do not form closed boxes and overshoot the corners. Calculate the
# offsets properly so the white lines form perfectly closed rectangles with ZERO
# overshooting."
#
# The confinement square itself was already geometrically closed — measured, its
# four edges met corner-to-corner with the crossing line's own half-width of
# overlap and no gap. What was actually broken is that the OTHER four lines were
# free-floating segments: the two throwing lines at z = ±6 and the two team-side
# lines at z = ±13 ran across the road with nothing at either end. From a low
# camera that reads exactly as "lines that overshoot and do not close", because
# there is no perpendicular for them to terminate on.
#
# So the court is now ONE closed outer rectangle with cross-lines inside it, the
# way a real tumbang preso court is chalked:
#
#     z=-13  +---------------------------+   CourtNorth
#            |                           |
#     z=-6   |---------------------------|   ThrowingLineNorth
#     z=-5   |---------------------------|   ConfinementNorth
#            |            (o)            |   BaseCircle at 0,0
#     z=+5   |---------------------------|   ConfinementSouth
#     z=+6   |---------------------------|   ThrowingLineSouth
#            |                           |
#     z=+13  +---------------------------+   CourtSouth
#          x=-5                        x=+5
#
# CourtEast/West run the full length at x = ±COURT_X, so every cross-line's ends
# land ON them. `court_line()` extends each edge by the crossing line's own
# half-width so corners overlap rather than notch — overlapping paint is
# invisible, a 40mm gap is not.
#
# The confinement box's own east/west edges are GONE: they sat at x = ±5.0, which
# is exactly where CourtEast/West now run, so drawing them again would be two
# coincident coplanar decals — z-fighting for no visual gain. The court sides do
# that job.
COURT_Z = 13.0

# The base circle sits at the centre of the court, on flat paving.
add_mark("BaseCircle", "base_circle_decal", 0.0, 0.0)

# The two long sides. These are what every other line terminates on.
court_line("CourtEast", "z", COURT_X, COURT_Z)
court_line("CourtWest", "z", -COURT_X, COURT_Z)
# The two ends.
court_line("CourtNorth", "x", -COURT_Z, COURT_X)
court_line("CourtSouth", "x", COURT_Z, COURT_X)

# The confinement square's north/south edges — the Can/Taya's actual restricted
# play area (CharacterBase.CONFINEMENT_RADIUS). Kept as a SQUARE per user
# feedback ("the circle you made was ugly ... can we just use a square").
court_line("ConfinementNorth", "x", -CONFINEMENT_BOX_RADIUS, COURT_X)
court_line("ConfinementSouth", "x", CONFINEMENT_BOX_RADIUS, COURT_X)

# The throwing lines, at the 6.0 distance Art_Direction §9 derived — the mark an
# attacker must stay behind.
court_line("ThrowingLineNorth", "x", -6.0, COURT_X, "throwing_line_decal")
court_line("ThrowingLineSouth", "x", 6.0, COURT_X, "throwing_line_decal")

# =============================================================================

ext_lines = [
    '[ext_resource type="%s" path="%s" id="%s"]'
    % ("PackedScene" if kit else "Mesh", p, i)
    for i, p, kit in ext
]
ext_lines.append('[ext_resource type="Script" '
                 'path="res://scripts/systems/hazard_zone.gd" id="H"]')
ext_lines.append('[ext_resource type="Script" '
                 'path="res://scripts/systems/kill_plane.gd" id="K"]')
ext_lines.append('[ext_resource type="Script" '
                 'path="res://scripts/systems/env_toon_pass.gd" id="T"]')
# ⚠️ A PANORAMA SKY, NOT ProceduralSkyMaterial. Playtest 2026-07-29: "sky feels
# lacking, feels like an endless desert". The procedural sky is a bare two-colour
# vertical ramp — no clouds, nothing to read distance against — and with the fog
# tinting it toward the same warm haze the ground uses, sky and ground converged
# on one flat cream and the whole frame read as desert.
# `sky_panorama.png` is generated by a deterministic value-noise pass (see the
# generator note in docs) and is ONE TEXTURE FETCH — cheaper than the procedural
# sky it replaces, so this costs nothing against the Phase 9 performance rollback
# and adds no shader.
ext_lines.append('[ext_resource type="Texture2D" '
                 'path="res://assets/models/materials/sky_panorama.png" id="SKY"]')
# Checklist 4.1 - the map's ambience bed. CC0, sourced (not generated): see
# assets/audio/ambience/OPENGAMEART_CC0_LICENSE.txt for the source URL, author
# and licence text, which Form 03 needs.
#
# THE AMBIENCE BELONGS TO THE MAP, NOT TO AudioManager. Same rule that put the
# WorldEnvironment, the kill plane and the spawn markers in here rather than in
# Main.tscn: what a place sounds like is part of that place. An eskinita and a
# plaza are different rooms and must not share a bed.
ext_lines.append('[ext_resource type="AudioStream" '
                 'path="res://assets/audio/ambience/eskinita_street.wav" id="AMB"]')

# ⚠️ THE FLOOR IS 120x120 AND THAT IS A BACKDROP CHANGE, NOT AN ARENA RESIZE.
# The colliders that bound play — Bounds/Wall* at ±8.6 and ±18.0 — are byte-for-
# byte what they were. Part 4's standing rule bans changing arena SCALE in the
# same commit as arena ART; this changes neither. It stops the world ending in a
# visible edge 20 m from the player.
#
# ⚠️ THE FLOOR'S COLLISION AND ITS MESH ARE AT DIFFERENT HEIGHTS ON PURPOSE, AND
# IT IS NOT A MISTAKE TO TIDY UP.
#   * The COLLISION top is at GROUND_Y (0.100) — the paving top. That is what a
#     character stands on, and it is the fix for feet sinking 100 mm into the
#     visible road, which is what a 0.0 collision top under 0.1 paving meant.
#   * The MESH top is 15 mm lower (0.085). It has to be BELOW the paving rather
#     than level with it: two coplanar surfaces z-fight, and a shimmering plane
#     under the whole map is a worse artefact than a 15 mm lip 26 m away at the
#     apron's edge, where the fog is already halfway in.
# Box height is 1, so a node offset is (wanted top - 0.5).
SUBS = '''[sub_resource type="BoxShape3D" id="Shape_floor"]
size = Vector3(120, 1, 120)

[sub_resource type="StandardMaterial3D" id="Mat_floor"]
albedo_color = Color(0.32941, 0.31765, 0.29412, 1)
roughness = 1.0

[sub_resource type="BoxMesh" id="Mesh_floor"]
material = SubResource("Mat_floor")
size = Vector3(120, 1, 120)

[sub_resource type="BoxShape3D" id="Shape_wall_z"]
size = Vector3(1, 12, 40)

[sub_resource type="BoxShape3D" id="Shape_wall_x"]
size = Vector3(20, 12, 1)

[sub_resource type="BoxShape3D" id="Shape_killplane"]
size = Vector3(260, 4, 260)

[sub_resource type="BoxShape3D" id="Shape_hazard"]
size = Vector3(3.6, 3, 11)

[sub_resource type="PanoramaSkyMaterial" id="Sky_mat"]
panorama = ExtResource("SKY")
energy_multiplier = 1.0

[sub_resource type="Sky" id="Sky_res"]
sky_material = SubResource("Sky_mat")

[sub_resource type="Environment" id="Env_eskinita"]
background_mode = 2
sky = SubResource("Sky_res")
ambient_light_source = 3
ambient_light_energy = 1.15
ambient_light_sky_contribution = 0.8
reflected_light_source = 2
tonemap_mode = 3
tonemap_exposure = 0.92
tonemap_white = 1.9
ssao_enabled = true
ssao_radius = 0.9
ssao_intensity = 1.1
ssao_power = 1.1
ssao_detail = 0.6
ssao_horizon = 0.05
ssil_enabled = false
sdfgi_enabled = false
glow_enabled = false
fog_enabled = true
fog_mode = 1
fog_light_color = Color(0.8784, 0.8118, 0.6941, 1)
fog_light_energy = 0.9
fog_sun_scatter = 0.28
fog_density = 0.0
fog_sky_affect = 0.22
fog_depth_curve = 1.1
fog_depth_begin = 14.0
fog_depth_end = 58.0
adjustment_enabled = true
adjustment_brightness = 1.0
adjustment_contrast = 1.03
adjustment_saturation = 1.18
'''

# ⚠️ NO `#` COMMENTS INSIDE THE EMITTED .tscn. Godot's scene format does not use
# `#` for comments, so a stray one silently breaks the NEXT node's declaration —
# it cost a debugging round when four `#` lines above [node name="SpawnPoints"]
# made every Spawn marker fail to instantiate with "parent path has vanished".
# Explain things HERE, in the generator, where they also survive an editor save.
#
# ⚠️⚠️ SPAWN HEIGHTS ARE DERIVED FROM GROUND_Y, NOT TYPED. DO NOT HARDCODE THEM.
#
# These are offsets ABOVE THE FLOOR'S COLLISION TOP — a capsule's origin is its
# centre, so a 1.6-tall Person needs its origin 0.8 above whatever it stands on.
# Phase 8 raised the floor collision top from 0.000 to GROUND_Y (0.100) so that
# characters would stop standing 100mm inside the visible road, and left these
# four numbers alone on the reasoning that "the paving was already at 0.1".
#
# That was wrong, and it is the "weird physics bounces" report. The spawn Y is
# measured against the FLOOR COLLIDER, which moved. Every unit therefore spawned
# 100mm EMBEDDED in the floor and Godot's depenetration ejected it — measured
# with tools/jump_probe.gd: a Person placed at y=0.8 was shoved to y=2.50 on the
# next physics step and then slid 9.84 units sideways in a single
# move_and_slide() call, at a normal 0.0167 delta and time_scale 1.0. Not a
# velocity bug and not a lag spike: a body starting inside a collider.
#
# Spawn0-3 are ROLE slots (Can / Taya / Attacker / Tsinelas), not team slots —
# main.gd's _role_slot() picks which one each unit occupies THIS round. Their
# heights are unchanged: the paving under them was already at 0.100 and still is,
# so raising the FLOOR to meet it moved nothing they stand on.
HEAD = f'''[node name="Eskinita" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env_eskinita")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.86603, -0.31889, 0.38549, 0, 0.77088, 0.63698, -0.5, -0.55164, 0.66692, 0, 12, 0)
light_color = Color(1, 0.90196, 0.75294, 1)
light_energy = 1.15
light_indirect_energy = 1.3
light_angular_distance = 0.5
light_specular = 0.35
shadow_enabled = true
shadow_bias = 0.06
shadow_normal_bias = 3.0
shadow_blur = 1.1
shadow_opacity = 0.62
directional_shadow_mode = 2
directional_shadow_split_1 = 0.08
directional_shadow_split_2 = 0.22
directional_shadow_split_3 = 0.52
directional_shadow_blend_splits = true
directional_shadow_fade_start = 0.9
directional_shadow_max_distance = 42.0

[node name="Floor" type="StaticBody3D" parent="."]

[node name="CollisionShape3D" type="CollisionShape3D" parent="Floor"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.4, 0)
shape = SubResource("Shape_floor")

[node name="MeshInstance3D" type="MeshInstance3D" parent="Floor"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.415, 0)
mesh = SubResource("Mesh_floor")

[node name="Bounds" type="Node3D" parent="."]

[node name="WallEast" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 8.6, 6, 0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="Bounds/WallEast"]
shape = SubResource("Shape_wall_z")

[node name="WallWest" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -8.6, 6, 0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="Bounds/WallWest"]
shape = SubResource("Shape_wall_z")

[node name="WallNorth" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 6, -18.0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="Bounds/WallNorth"]
shape = SubResource("Shape_wall_x")

[node name="WallSouth" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 6, 18.0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="Bounds/WallSouth"]
shape = SubResource("Shape_wall_x")

[node name="KillPlane" type="Area3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -10, 0)
script = ExtResource("K")

[node name="CollisionShape3D" type="CollisionShape3D" parent="KillPlane"]
shape = SubResource("Shape_killplane")

[node name="Ambience" type="Node3D" parent="."]

[node name="AmbienceLoop" type="AudioStreamPlayer" parent="Ambience"]
stream = ExtResource("AMB")
autoplay = true
bus = &"Music"
volume_db = -12.0

[node name="Hazards" type="Node3D" parent="."]

[node name="HazardZone" type="Area3D" parent="Hazards"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 5.4, 1.5, 0)
collision_layer = 0
collision_mask = 2
script = ExtResource("H")
speed_multiplier = 0.5
lifetime = 0.0

[node name="CollisionShape3D" type="CollisionShape3D" parent="Hazards/HazardZone"]
shape = SubResource("Shape_hazard")

[node name="KanalVisual" type="Node3D" parent="Hazards"]

[node name="SpawnPoints" type="Node3D" parent="."]

[node name="Spawn0" type="Marker3D" parent="SpawnPoints"]
transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0.0, {GROUND_Y + 0.17:.3f}, 0.0)

[node name="Spawn1" type="Marker3D" parent="SpawnPoints"]
transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 2.2, {GROUND_Y + 0.80:.3f}, -1.5)

[node name="Spawn2" type="Marker3D" parent="SpawnPoints"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.0, {GROUND_Y + 0.80:.3f}, 6.0)

[node name="Spawn3" type="Marker3D" parent="SpawnPoints"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.3, {GROUND_Y + 0.16:.3f}, 6.3)

[node name="Dressing" type="Node3D" parent="."]
script = ExtResource("T")

[node name="Layer1" type="Node3D" parent="Dressing"]

[node name="BayFill" type="Node3D" parent="Dressing"]

[node name="CrossRow" type="Node3D" parent="Dressing"]

[node name="Layer2" type="Node3D" parent="Dressing"]

[node name="Layer3" type="Node3D" parent="Dressing"]

[node name="Belt" type="Node3D" parent="Dressing"]

[node name="Road" type="Node3D" parent="Dressing"]

[node name="Clutter" type="Node3D" parent="Dressing"]

[node name="Markings" type="Node3D" parent="."]
'''

kit_ids = {i for i, _p, kit in ext if kit}
body = []
for parent, name, mid, tf in order:
    if mid in kit_ids:
        # ⚠️ A .glb is a PackedScene, so it is INSTANCED, not assigned to a
        # `mesh` property. Emitting a kit piece as a MeshInstance3D with
        # `mesh = ExtResource(...)` does NOT error — Godot loads the scene with
        # that node simply blank. That is exactly how an entire street of houses
        # rendered as empty road on the first run of checklist 7.4.
        body.append(f'\n[node name="{name}" parent="{parent}" instance=ExtResource("{mid}")]')
        body.append(f'transform = {tf}')
    else:
        body.append(f'\n[node name="{name}" type="MeshInstance3D" parent="{parent}"]')
        body.append(f'transform = {tf}')
        body.append(f'mesh = ExtResource("{mid}")')

# load_steps counts ext_resource + sub_resource entries, plus one. A wrong value
# does not error — it silently truncates resource loading (Concurrency_Protocol
# §6), which is exactly why it is computed here rather than typed.
n_sub = SUBS.count("[sub_resource")
load_steps = len(ext_lines) + n_sub + 1

out = (f'[gd_scene load_steps={load_steps} format=3]\n\n'
       + "\n".join(ext_lines) + "\n\n" + SUBS + "\n" + HEAD + "\n".join(body) + "\n")

# ⚠️ BEFORE WRITING, NOT AFTER. A floating marking or a sunk prop must not reach
# the scene file at all — half the cost of this bug every previous time was that
# a broken scene got committed, imported and played before anyone looked at it.
n_marks = surfaces.verify()

overlaps = surfaces.overlaps("Layer1")
with open("scenes/maps/Eskinita.tscn", "w", encoding="utf-8", newline="\n") as f:
    f.write(out)

print("wrote scenes/maps/Eskinita.tscn")
print(f"  markings      : {n_marks} verified embedded")
print(f"  dressing      : verified grounded (floor+paving both at y={GROUND_Y})")
print(f"  ext_resources : {len(ext_lines)}")
print(f"  sub_resources : {n_sub}")
print(f"  load_steps    : {load_steps}")
print(f"  mesh instances: {len(order)}")
if overlaps:
    print(f"  [!] Layer1 footprint overlaps: {len(overlaps)}")
    for a, b, ox, oz in overlaps[:8]:
        print(f"      {a} <-> {b}  ({ox:.2f} x {oz:.2f} m)")
else:
    print("  Layer1 overlap: none")
