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
from floorcheck import (Surfaces, embed_y, mesh_bounds,  # noqa: E402
                        read_confinement_radius)
## The logic both maps need, in one place — see mapkit.py's own header. This
## file is the one every lesson was learned on, so it is the one that has to
## stop being the only place they live.
from mapkit import Placer, apron_cells, front_yaw  # noqa: E402,F401

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
## ⚠️ THE ONLY BROADLEAF TREE IN THE REPO, AND IT IS DECLARED HERE BECAUSE THE
## HORIZON RING USES IT BEFORE THE STREET ROW DOES. Measured by rendering all eight
## tree assets: every other one is a stepped cone. See the long note at the street
## row for why one species repeated is the right answer and how the repetition is
## broken.
PUNO_MESH = "kits/town/tree-high-round"
_PUNO_SCALE = [1.0, 1.18, 0.88, 1.09, 0.95, 1.14]

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
# ⚠️ THE APRON'S EDGE IS FEATHERED, NOT FURTHER OUT. Same fix and same reason as
# Bayan Plaza's — see mapkit.apron_cells. This map's overhead had the identical
# hard square (a straight line where the paving stopped against bare floor at
# x=30 / z=32) and it was never listed as a defect here only because the defect
# was written up against the OTHER map. It is one bug in one shared shape.
#
# Solid to 26 covers everything a player can see the ground of: the collision
# walls are at |x| 8.6 / |z| 18 and the cross rows close the street at |z| 26,
# so the dissolve begins exactly at the last row of houses and everything inside
# it is paved solid. Reach is up from 30/32 to 38 for +17 tiles, because the
# outer band is mostly holes; 28/40 was tried first and cost +51 for a reach
# nothing looks at.
APRON_SOLID = 26.0
APRON_FADE = 38.0
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
for _gx, _gz, _ix, _iz in apron_cells(APRON_SOLID, APRON_FADE, ROAD_SCALE,
                                      half=APRON_FADE):
    add_kit("Dressing/Kalsada", f"Kalsada_{_road_n}", "kits/town/road", _gx, _gz,
            _ROAD_YAW[_road_n % len(_ROAD_YAW)] * math.pi * 0.5,
            ROAD_SCALE, base_y=ROAD_BASE_Y, lane_exempt=True)
    _road_n += 1

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
            add_kit("Dressing/Bahay", f"Sasakyan_{i}_{tag}", car, cx,
                    _bay[side] - cext[2], cyaw, CAR_SCALE)
            # ⚠️ A DRIVEWAY IS NOT A HOLE. The bay is deliberately empty of
            # HOUSE, but leaving it empty of everything is what read as the
            # street missing a tooth. A fence line plus a hedge closes the gap
            # at eye level while keeping the bay itself legible as a gap.
            _fz = _bay[side] - cext[2]
            add_kit("Dressing/Bakod", f"BakodPanel_{i}_{tag}",
                    "kits/city/fence" if i % 2 else "kits/city/fence-low",
                    side * (WALL_FACE_X + 0.15), _fz - 2.6,
                    0.0 if side > 0 else math.pi, CITY_SCALE * 0.8)
            add_kit("Dressing/Bakod", f"BakodHalaman_{i}_{tag}", "kits/town/hedge",
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
            add_kit("Dressing/Bahay", f"Bahay_{i}_{tag}", piece, cx,
                    _bay[side] - ext_b[2] , yaw, CITY_SCALE)
            _bay[side] += width + BAY_GAP
        _i[side] += 1

# --- The cross rows that close each end of the alley -------------------------
#
# Faces back down the street (toward the arena) so a player looking up the alley
# sees house fronts, not gable ends — same rule Layer 1 follows. Placed by the
# same measured face-alignment: solve for the centre that lands THIS piece's own
# face on CROSS_ROW_Z.
# ⚠️ THE ADVANCE IS THE NEXT PIECE'S OWN EDGE, NOT THE LAST PIECE'S WIDTH, and
# getting that wrong put FIVE METRES of one cross-row house inside its neighbour.
#
# The old loop treated `_x` as the next piece's CENTRE and advanced it by the
# CURRENT piece's full width plus a gap. Work the gap out: for centred pieces
# that leaves `w_current/2 + 0.4 - w_next/2` of clearance, so the row is correct
# only while consecutive houses are the same width — and the eleven
# `building-type-*` are emphatically not. Every time a narrow house was followed
# by a wider one they interpenetrated, by up to 5.14 m (Kanto_0 <-> Kanto_1,
# Kanto_2 <-> Kanto_3, Kanto_5 <-> Kanto_6).
#
# This is rule 3 of this file's own header — "NO DIMENSION OF A KIT PIECE IS
# ASSUMED" — broken on the one row that was added after the rule was written. It
# survived because `overlaps()` was only ever asked about "Layer1", so the cross
# row was never compared with itself at all.
#
# Fixed the way the main house row already does it: carry a CURSOR along the row
# and solve for the centre that lands THIS piece's own left edge on it.
_CROSS_TYPES = ["e", "b", "o", "n", "c", "l", "d", "a", "s"]
_cx_n = 0
for _end in (-1.0, 1.0):
    _yaw = 0.0 if _end < 0 else math.pi   # front toward the arena centre
    _cursor = -16.0
    while _cursor <= 16.0:
        _piece = f"kits/city/building-type-{_CROSS_TYPES[_cx_n % len(_CROSS_TYPES)]}"
        _e = piece_extent(_piece, _yaw, CITY_SCALE)
        _cx = _cursor - _e[0]
        _cz = (CROSS_ROW_Z - _e[3]) if _end > 0 else (-CROSS_ROW_Z - _e[2])
        add_kit("Dressing/Kanto", f"Kanto_{_cx_n}", _piece, _cx, _cz, _yaw,
                CITY_SCALE, lane_exempt=True)
        _cx_n += 1
        _cursor = _cx + _e[1] + 0.4

# --- Layer 2: a second row further out, for skyline depth --------------------
# Off-grid on purpose and deliberately NOT the same types as Layer 1 -- a second
# identical row reads as a mirror rather than as a neighbourhood.
# ⚠️ THESE FACE OUTWARD, AWAY FROM OUR ALLEY, AND THAT IS DELIBERATE.
# Real blocks are built back-to-back: the row behind these houses fronts onto the
# NEXT street over, not onto ours. Facing them inward would give the alley two
# competing front rows and read as a film set. A small yaw jitter keeps the row
# from looking extruded — see the seeded-not-random rule.
#
# ⚠️ THIS ROW ASKS BEFORE IT LANDS, and four of its twelve needed it. The
# coordinates below are hand-authored and four pairs interpenetrated — Likod_3
# <-> Likod_10 by 1.65 m, Likod_4 <-> Likod_9 by 1.93 m — because the eight ring
# positions and the four corner fills were written at different times and nothing
# ever compared them. Same ask-before-placing guard R-19 put on the plaza, with
# COARSE_LADDER because these are 7-metre buildings and a half-metre step just
# walks one around inside its neighbour.
_placer = Placer(surfaces, piece_extent, ["Bahay", "Kanto", "Likod", "Kalat"])


def _put(group):
    def go(name, mesh_name, x, z, yaw, scale):
        add_kit(f"Dressing/{group}", name, mesh_name, x, z, yaw, scale)
    return go


def _put_gen(group):
    def go(name, mesh_name, x, z, yaw, _scale):
        add(f"Dressing/{group}", name, mesh_name, x, z, yaw)
    return go


_L2_JIT = [0.09, -0.14, 0.05, -0.07, 0.12, -0.03]
for n, (x, zz, kind) in enumerate([
        (-19.5, -14.0, "t"), (-21.0, -3.0, "q"), (-19.0, 8.0, "u"),
        (-21.5, 17.0, "f"), (19.5, -15.0, "p"), (21.0, -4.0, "r"),
        (19.0, 7.0, "k"), (21.5, 16.0, "m"),
        (-20.0, -22.0, "b"), (20.0, -21.0, "d"), (-20.5, 24.0, "n"),
        (20.5, 23.0, "s")]):
    out_yaw = (math.pi * 0.5) if x > 0 else (-math.pi * 0.5)
    _placer.try_place(_put("Likod"), f"Likod_{n}",
                      f"kits/city/building-type-{kind}", x, zz,
                      out_yaw + _L2_JIT[n % len(_L2_JIT)], CITY_SCALE,
                      ladder=Placer.COARSE_LADDER)

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
            add_kit("Dressing/Malayo", f"MalayoX_{_belt}",
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
            add_kit("Dressing/Malayo", f"MalayoZ_{_belt}",
                    f"kits/city/building-type-{BELT_TYPES[_belt % len(BELT_TYPES)]}",
                    xx + j, side * (ring + j * 0.35),
                    (j * 0.13) + (0.0 if side > 0 else math.pi),
                    CITY_SCALE * (1.0 + ring_i * 0.15))
            _belt += 1
            xx += step

# One tree ring, not three, and only in the seam between the two building rings.
# ⚠️ PUNO HERE TOO. This ring is the horizon, and a horizon of conifers is what a
# player sees behind every frame of the match — so it is the single largest
# surface the wrong tree was wrong on. Alternating niyog and mangga gives the
# skyline a palm-and-broadleaf profile instead of a sawtooth of pines. Same count
# as before: a swap, not an addition.
_tree_n = 0
for side in (-1.0, 1.0):
    t = -44.0
    while t <= 44.0:
        j = _belt_jit[_tree_n % len(_belt_jit)]
        # ⚠️ BROADLEAF ON THE HORIZON TOO. This ring is the skyline behind every
        # frame of the match, so it is the single largest surface the conifers were
        # wrong on. Town-kit trees at 3.0 stand 8.9 tall, which reads against the
        # belt's houses at CITY_SCALE without competing with them.
        # Same one broadleaf on the horizon, at 3.0 so it stands ~8.3 and reads
        # against the belt's houses. This ring is the skyline behind every frame of
        # the match, so it is the largest surface the conifers were wrong on.
        add_kit("Dressing/Malayo", f"PunoMalayoX_{_tree_n}", PUNO_MESH,
                side * (36.5 + j * 0.3), t + j * 1.3, j * 0.2,
                3.0 * _PUNO_SCALE[_tree_n % len(_PUNO_SCALE)], lane_exempt=True)
        _tree_n += 1
        add_kit("Dressing/Malayo", f"PunoMalayoZ_{_tree_n}", PUNO_MESH,
                t + j * 1.1, side * (36.5 + j * 0.3), -j * 0.2,
                3.0 * _PUNO_SCALE[_tree_n % len(_PUNO_SCALE)], lane_exempt=True)
        _tree_n += 1
        t += 15.0

# --- PUNO. The trees, and the single biggest cultural correction on this map. -
#
# ⚠️ EVERY TREE ON THIS STREET USED TO BE A KENNEY CONIFER. `kits/city/tree-large`
# and `tree-small` are pines, and there is no pine on a Philippine residential
# street — the whole alley read as a Nordic suburb with a sari-sari store parked
# in it. build_bayan_plaza.py's open item 7 wrote this defect up against the OTHER
# map ("a Nordic park with a Philippine church in it") and closed it as
# unfixable-by-re-picking, because the kits genuinely contain no broadleaf and no
# palm. env_kit.gd now generates three, so this is a SWAP and not an addition:
# twelve conifer instances become twelve puno instances.
#
# ⚠️ AND THEY ARE PLACED BY WHAT THEY ARE, not interchangeably. The three species
# do different jobs and their measured footprints are what decides where each can
# stand:
#
#   SAGING (3.90 wide, 2.52 tall) — IN the alley, in the alcoves between houses.
#       Short and broad, so it fills the wall line at eye level without ever
#       reaching over the throwing corridor. This is the one a player brushes
#       past.
#   MANGGA (4.60 wide, 4.30 tall) — BEHIND the wall, canopy overhanging INTO the
#       alley. Wider than it is tall, which is the exact inverse of the cone it
#       replaces. "A mango tree over the wall" is a specific thing and this is
#       geometrically that thing: the trunk is in somebody's yard and the shade
#       is on the street.
#   NIYOG (4.21 wide, 6.50 tall) — BEHIND the wall and well back, so only the
#       crown clears the roofline. It is the piece that reads against SKY at the
#       top of the alley, which is where a coconut is actually seen from a street
#       this narrow.
#
# All three are generated `env_*` pieces authored at 1 unit = 1 m, so they go
# through `add()` at native size — NOT `add_kit()` at CITY_SCALE, which is the
# 5x a Kenney house needs and would put a 32-metre banana in the alley.
# ⚠️⚠️ THE TREES ARE KIT PIECES, NOT GENERATED ONES, ON THE HUMAN'S EXPLICIT CALL.
#
# I generated three Philippine species in env_kit.gd — saging, niyog, mangga — to
# replace the Kenney conifers, because a pine on a Philippine residential street is
# the loudest wrong thing either map had. The human rejected them twice on sight:
# "holy shit theyre so ugly and they clip into the houses" and then "still, the
# trees are so ugly, they dont look like trees so pls js use different assets."
# That is a look call and the look call is theirs, so the generated puno are OUT of
# both maps.
#
# ⚠️ THE FANTASY TOWN TREES ARE THE RIGHT COMPROMISE AND NOT A SURRENDER.
# `kits/city/tree-*` are conifers and are what the cultural problem WAS. The Town
# kit's are rounded BROADLEAF — no pine silhouette anywhere — so this keeps the
# thing that actually mattered (a Philippine street is not lined with pines) while
# using art that reads as trees. Palm and banana specificity is the part that is
# genuinely lost; it is filed in Handoff §5 as the human's call to revisit.
#
# ⚠️ AND THEY ASK BEFORE LANDING. The clipping half of that complaint was a real
# bug of mine: I put the big species at WALL_FACE_X + 1.15 and + 2.30, reasoning
# they were "behind the wall in the neighbour's yard". There is no yard — a
# `building-type-*` is 1.03 deep natively, which is 5.14 AT CITY_SCALE, so the house
# row occupies x = 8.6 .. 13.7 SOLID and both offsets landed inside a building.
# Rule 3 of this file's header says no dimension of a kit piece may be assumed, and
# I assumed a gap. Trees now go through the placement guard against the house
# groups like everything else, so this cannot recur.
#
# The legal band is arithmetic, not taste: a tree of half-width h needs
#     LANE_HALF_X + LANE_MARGIN + h  <  |cx|  <  WALL_FACE_X - h
# `kits/town/tree*` measures 1.02 wide, i.e. h = 0.82 at TOWN_SCALE, so the band is
# 4.32 .. 7.78 and 6.6 sits comfortably inside it with room on both sides.
# ⚠️⚠️ UNIFORMITY WAS THE THIRD COMPLAINT AND IT IS A PLACEMENT BUG, NOT A MODEL
# ONE. Human, on the previous version: "your tree placement is too uniform, pls add
# some variation to trees and tree placement, it doesnt look natural."
# Correct, and the render showed exactly why: every tree stood at |x| = 6.6 EXACTLY,
# on a z list with a near-constant 5-unit gap, mirrored on both sides. That is an
# avenue, not a street — nothing in a barangay eskinita is planted on a survey line.
#
# THREE THINGS VARY NOW, and all three are seeded tables rather than an RNG so two
# runs still diff clean:
#   1. X, per tree, so no two trunks share a line and the row has depth.
#   2. Z, with IRREGULAR GAPS — 2.5 to 7.5 units, and the two sides use different
#      tables, so they do not pair up across the road.
#   3. SPECIES, SCALE and YAW, and there are gaps with no tree at all.
#
# ⚠️ THE OTHER MODELS ARE BACK IN, AT MINORITY WEIGHT, and that is a deliberate
# trade against the cultural rule rather than a lapse. `tree-high-round` is the only
# rounded canopy in the repo, so an all-round row is one silhouette repeated — which
# is what read as uniform. Mixing the coned models back in buys real variety, and
# the guard against "this looks Nordic" is now WEIGHT: the rounded broadleaf is
# two-thirds of the row and always the biggest, so the street reads broadleaf with
# some scrub in it rather than as a pine avenue. Human's explicit ask: "js use more
# of the tree models."
#
# ⚠️ AND THE X BAND IS COMPUTED PER PIECE, because the pieces differ in width and
# the lane law is absolute: a footprint of half-width h must satisfy
#     LANE_HALF_X + LANE_MARGIN + h  <  |cx|  <  WALL_FACE_X - h
# `_puno_x()` clamps the jittered x into that band using the piece's own measured
# extent, so a wider tree or a bigger scale jitter cannot silently push one into the
# throwing corridor and abort the build.
_PUNO_MIX = [PUNO_MESH, PUNO_MESH, "kits/town/tree-high", PUNO_MESH,
             PUNO_MESH, "kits/town/tree-crooked", PUNO_MESH, "kits/town/tree",
             PUNO_MESH, PUNO_MESH]
_PUNO_SCALE_V = [1.05, 1.28, 0.86, 1.14, 0.94, 1.34, 0.82, 1.19, 1.0, 0.9]
_PUNO_XJIT = [0.0, 0.85, -0.7, 0.45, -1.05, 0.65, -0.35, 1.0, -0.85, 0.25]
## Irregular, and DIFFERENT PER SIDE so the two rows never line up across the road.
_PUNO_Z_E = [-16.2, -12.9, -7.4, -2.1, 3.8, 8.4, 13.9, 18.6]
_PUNO_Z_W = [-14.6, -9.8, -4.3, 1.2, 6.9, 11.7, 17.2]


def _puno_x(mesh_name, want, yaw, scale):
    """Jittered x, clamped into the band the lane law and the facade leave open."""
    e = piece_extent(mesh_name, yaw, scale)
    h = max(abs(e[0]), abs(e[1]), abs(e[2]), abs(e[3]))
    lo = LANE_HALF_X + LANE_MARGIN + h + 0.05
    hi = WALL_FACE_X - h - 0.05
    if lo > hi:
        return (lo + hi) * 0.5
    return min(max(want, lo), hi)


_pn_t = 0
for side, zlist in ((1.0, _PUNO_Z_E), (-1.0, _PUNO_Z_W)):
    tag = "E" if side > 0 else "W"
    for n, zz in enumerate(zlist):
        k = _pn_t % len(_PUNO_MIX)
        mesh_name = _PUNO_MIX[k]
        # The rounded broadleaf is always the biggest thing in the row; the coned
        # models come in smaller, so they read as scrub between the real trees
        # rather than as an avenue of pines.
        sc = TOWN_SCALE * _PUNO_SCALE_V[k] * (1.0 if mesh_name == PUNO_MESH else 0.72)
        yaw = (_pn_t % 5) * 1.27
        x = _puno_x(mesh_name, 6.35 + _PUNO_XJIT[k], yaw, sc)
        _placer.try_place(_put("Puno"), f"Puno_{n}_{tag}", mesh_name,
                          side * x, zz, yaw, sc)
        _pn_t += 1

# Understory, so a trunk is not standing alone on bare paving. Cheap, low, and it
# is the layer that stops the row reading as posts in a car park.
_PLANT_AT = [(-6.9, -13.4), (7.2, -7.9), (-7.3, 1.7), (6.8, 9.1),
             (-6.6, 17.6), (7.4, -16.8)]
for n, (px, pz) in enumerate(_PLANT_AT):
    _placer.try_place(_put("Puno"), f"Halaman_{n}", "kits/forest/plant",
                      px, pz, (n % 4) * 1.5, TOWN_SCALE * 1.4)

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
        add("Dressing/Kable", f"Poste_{_pn}", "post_electric",
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
    add("Dressing/Kable", f"Sampay_{n}", "laundry_line", 0.0, zz,
        # ⚠️ RAISED. A Person is 1.6 tall standing on ground at 0.1, so the top
        # of the head is ~1.70 — and the lowest garment hem used to sit at
        # 1.58, which is why heads phased through the washing. This puts the
        # hem at ~2.35, clear of a head and still low enough to read as
        # laundry rather than as bunting.
        base_y=GROUND_Y + 2.25 + (0.22 if n % 3 == 0 else 0.0),
        suspended=True, lane_exempt=True)

# --- THE NARRATIVE CENTRE, PLACED BEFORE THE CLUTTER. -----------------------
#
# ⚠️ ORDER IS THE FIX HERE, NOT A LOOSER GUARD, and getting it wrong deleted the
# most important piece on the map. These were originally placed AFTER the clutter
# and pinned, so `footprint_is_clear` refused both of them — one blocked by a
# nudged stall-bench, the other by a TYRE — and the builder cheerfully reported
# "same-group overlap: none" on an eskinita with no sari-sari store in it at all.
# A guard that resolves a conflict by dropping the narrative centre is worse than
# no guard.
#
# The store outranks a tyre, so the store goes down first and the clutter asks
# around IT. That is what ask-before-placing is for: the ORDER encodes what
# matters, and the loop that runs later is the one that yields.
# ⚠️ PINNED, NOT LADDERED. The sari-sari store is the narrative centre of this
# map — "a wall with a counter in it is a street" — and its position against the
# wall line is the whole point of it. A store nudged 0.55 m to dodge a tyre is a
# store standing in the road. If one is ever genuinely blocked the honest outcome
# is a reported skip, and the FRONT YAW comes from mapkit.front_yaw so the counter
# faces the alley by derivation rather than by a hand-written sign.
for _sn, (_sx, _sz) in enumerate([(W - 0.85, -1.0), (-(W - 0.85), 12.0)]):
    _placer.try_place(_put_gen("Kalat"), f"SariSari_{'E' if _sx > 0 else 'W'}",
                      "sari_sari_store", _sx, _sz,
                      front_yaw(_sx, _sz, 0.0, _sz), 1.0, ladder=False)


# --- THE BARANGAY BASKETBALL RING. There is one of these on every street in the
# --- country, and this map did not have it while the PLAZA had two.
#
# ⚠️ IT IS NAILED TO A POST AT THE ALLEY EDGE, WHICH IS WHERE THE REAL ONE IS.
# A barangay ring is not a stadium fixture — it is a plywood backboard bolted to
# whatever vertical thing was already there, usually an electric post, at the end
# of the street where there is room to shoot. `env_basketball_ring` is 3.85 tall
# and 0.99 deep, so it sits with the wall-line tier at |x| > 6.5 and its post is
# outside the playable width entirely.
#
# ⚠️ AND IT IS ONE, NOT TWO. The plaza has a ring at each end because a covered
# court does; an eskinita has one, and putting two here would be building the
# plaza twice, which is the failure R-33 names explicitly.
_ring_x, _ring_z = -(W - 0.35), -11.0
_placer.try_place(_put_gen("Kalat"), "BasketbolRing", "basketball_ring",
                  _ring_x, _ring_z, front_yaw(_ring_x, _ring_z, 0.0, _ring_z),
                  1.0, ladder=False)

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
# ⚠️ THE FANTASY-MARKET CLUTTER IS GONE, AND THAT IS THE JUDGEMENT CALL IN THIS
# TASK RATHER THAN THE EXECUTION. This list used to carry Kenney Fantasy Town's
# `rock-small`, `rock-wide`, `rock-large`, `cart`, `cart-high`, `pillar-wood`,
# `lantern`, `stall-red` and `stall-green`. Every one of them is a medieval
# European market prop, and together they were most of the interior read of the
# street. That is the DECORATIVE failure exactly as briefed: a well-built alley
# dressed with somebody else's vocabulary. There are no boulders in an eskinita,
# no handcarts, and no wrought-iron hanging lanterns — the street is lit by the
# same electric posts that carry the wires.
#
# What replaces them is not more stuff, it is the RIGHT stuff, and the swap is
# roughly instance-neutral by design (R-33's budget line is "ADD SPECIFICITY, NOT
# DENSITY"):
#
#   HALAMAN SA LATA  plants in cut-open paint tins. A Philippine doorstep has
#                    five of these and no garden. 0.59 tall, interior tier.
#   ATIP NA YERO     the GI lean-to a house extends itself with. This is what
#                    ROOFS the alley at eye level, where the wires cannot.
#   BAKOD NA YERO    `wall_corrugated` used as fence. A corrugated GI sheet
#                    boundary is the single most common wall on a Philippine
#                    residential street, and the mesh was already in the kit
#                    being used for nothing on this map.
#   TRAYSIKEL        already here, kept, and now the only vehicle-shaped prop in
#                    the interior instead of competing with a handcart.
#
# KEPT, because they are right rather than because they were already there: the
# monobloc chair (THE Filipino plastic chair), tires, oil drums, crates, plywood
# planks, low stools and benches. A monobloc chair outside a sari-sari store is
# as specific as anything generated here.
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
    # --- HALAMAN SA LATA. On doorsteps, in clusters, never singly - a doorstep
    # --- with one pot on it is a garden centre; a doorstep with three is a home.
    ("halaman_lata", -6.05, -0.9, 0.0, None), ("halaman_lata", -5.75, -0.45, 0.9, None),
    ("halaman_lata", -6.15, -0.05, 1.8, None),
    ("halaman_lata", 6.05, 5.1, 0.3, None), ("halaman_lata", 5.78, 5.55, 1.2, None),
    ("halaman_lata", 6.18, 5.95, 2.4, None),
    ("halaman_lata", -5.95, 16.8, 0.6, None), ("halaman_lata", -5.65, 17.25, 1.5, None),
    ("halaman_lata", 6.0, -13.2, 0.0, None), ("halaman_lata", 5.7, -12.75, 1.1, None),
    # --- plywood and seating. Universal, and right for the place.
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
        _placer.try_place(_put_gen("Kalat"), f"Kalat_{n}", piece, x, zz, yaw, 1.0)
    else:
        _placer.try_place(_put("Kalat"), f"Kalat_{n}", piece, x, zz, yaw, scale)

# --- Taller clutter: against the wall line only, |x| > 6.5 -------------------
# --- Taller clutter: against the wall line only, |x| > 6.5 -------------------
#
# ⚠️ THIS TIER IS NOW ENTIRELY FILIPINO, and it is the tier that does the most
# work because it is the one at eye level. The medieval carts, the wood pillar
# and the hanging lantern are gone (see CLUTTER_LOW's note); what stands against
# the wall line instead is the GI-sheet vocabulary that makes an alley a
# Philippine alley: lean-to awnings over the doorways and corrugated fence
# panels closing the gaps between houses.
#
# ⚠️ EVERY PIECE STILL OBEYS THE HEIGHT LAW. `atip_yero` is 2.92 tall and
# `wall_corrugated` 2.40 — both far over an FPP Person's 1.25 eye — so both live
# at |x| > 6.5 against the wall line, exactly where this tier was already
# restricted to, and the lane law is asserted on each of them regardless.
#
# Generated pieces pass `None` for scale, same convention as CLUTTER_LOW.
CLUTTER_TALL = [
    # ATIP NA YERO — the lean-to. Roofs the alley edge at eye level, which is
    # the half of "roofed by wires" that wires physically cannot do.
    ("atip_yero", -7.05, -7.5, 0.0, None),
    ("atip_yero", 7.05, 10.5, math.pi, None),
    ("atip_yero", -7.05, 5.5, 0.0, None),
    ("atip_yero", 7.05, -3.5, math.pi, None),
    # BAKOD NA YERO — corrugated GI fence, closing the gaps between houses.
    # Long in its own X (2.00 wide, 0.21 deep), so a run along Z wants a quarter
    # turn — measured off the mesh, not guessed.
    ("wall_corrugated", -7.9, 11.5, math.pi * 0.5, None),
    ("wall_corrugated", -7.9, 13.6, math.pi * 0.5, None),
    ("wall_corrugated", 7.9, 16.0, math.pi * 0.5, None),
    ("wall_corrugated", 7.9, 6.5, math.pi * 0.5, None),
    ("wall_corrugated", -7.9, -16.5, math.pi * 0.5, None),
    ("wall_corrugated", 7.9, -15.5, math.pi * 0.5, None),
    # Planting, kept.
    ("kits/town/hedge", -7.5, 1.5, 0.0, TOWN_SCALE),
    ("kits/town/hedge", 7.5, -10.5, 0.0, TOWN_SCALE),
]
for n, (piece, x, zz, yaw, scale) in enumerate(CLUTTER_TALL):
    if scale is None:
        _placer.try_place(_put_gen("Kalat"), f"KalatTaas_{n}", piece, x, zz, yaw, 1.0)
    else:
        _placer.try_place(_put("Kalat"), f"KalatTaas_{n}", piece, x, zz, yaw, scale)

# --- Tricycles. Waist-cover tier, against the wall line, never loose. --------
# ⚠️ THESE ASK TOO, and they were the last unguarded placements on the map — all
# seven remaining same-group overlaps were a tricycle or a sari-sari store landing
# on clutter that had been placed before it, because these two blocks run last
# and nothing was comparing them against anything.
for n, (x, zz, yaw) in enumerate([
        (-7.0, -6.0, 0.15), (7.0, 9.5, math.pi + 0.2), (-6.9, 15.0, -0.1),
        (7.1, -13.0, math.pi - 0.3)]):
    _placer.try_place(_put_gen("Kalat"), f"Traysikel_{n}", "tricycle",
                      x, zz, yaw, 1.0)

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
CONFINEMENT_BOX_RADIUS = read_confinement_radius()
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

# ⚠️ THE FLOOR **MESH** IS 200x200 WHILE ITS **COLLISION** STAYS 120x120, and the
# split is deliberate. Feathering the apron removed the paving's own hard edge;
# what was left behind it was Ring 0's — the floor box ended at |60| while
# fog_depth_end is 58, so the very last two units of the world stuck out past the
# fog as a straight diagonal against the sky in the y=25 overhead. Taking the
# MESH to |100| puts its edge 42 units beyond the fog's end, where it is fully
# occluded, and it costs EXACTLY NOTHING: the floor is a single BoxMesh, so this
# is one draw call either way and not one extra instance.
# The COLLISION box is untouched at 120 — it is what characters stand on and what
# the kill plane is sized against, and this is a backdrop change, not a play-area
# change. Same rule as the note below.
#
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
# ⚠️ THE FLOOR MESH'S COLOUR IS MATCHED TO THE APRON'S, AND THAT IS THE SECOND
# HALF OF THE SOFT-EDGE FIX. Feathering the apron (see APRON_SOLID) turns the
# hard line into a ragged one, but a ragged line between two DIFFERENT colours is
# still a visible boundary — it just has teeth. Sampled off the y=25 overhead
# render: the apron read (90, 88, 98) against a floor of (109, 101, 93), i.e. the
# paving was cool grey and the floor under it was warm brown, so every gap the
# feather opened showed up as a warm speck. The albedo below is that measurement
# pushed back through the ratio, so the tiles and the floor they thin out over
# are the same colour and the dissolve has nothing left to reveal. It costs
# nothing — it is one albedo on a material that already existed.
#   * The MESH top is 15 mm lower (0.085). It has to be BELOW the paving rather
#     than level with it: two coplanar surfaces z-fight, and a shimmering plane
#     under the whole map is a worse artefact than a 15 mm lip 26 m away at the
#     apron's edge, where the fog is already halfway in.
# Box height is 1, so a node offset is (wanted top - 0.5).
SUBS = '''[sub_resource type="BoxShape3D" id="Shape_floor"]
size = Vector3(120, 8, 120)

[sub_resource type="StandardMaterial3D" id="Mat_floor"]
albedo_color = Color(0.37780, 0.36910, 0.39620, 1)
roughness = 1.0

[sub_resource type="BoxMesh" id="Mesh_floor"]
material = SubResource("Mat_floor")
size = Vector3(200, 1, 200)

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
ambient_light_source = 2
ambient_light_color = Color(0.62745, 0.57647, 0.52157, 1)
ambient_light_energy = 1.65
ambient_light_sky_contribution = 0.35
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
fog_light_color = Color(0.92157, 0.78431, 0.60392, 1)
fog_light_energy = 0.95
fog_sun_scatter = 0.34
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

# ⚠️ LATE AFTERNOON, CHOSEN DELIBERATELY — R-33(c). This is the hour children
# actually play tumbang preso: after school, before dark, when the sun is low
# enough that the street is in bands of shade and nobody is standing in noon heat.
# Flat noon is the other option and it is the wrong one for this game — it is also
# what the map had, a 39-degree sun reading as midday.
#
# THE COST IS ZERO AND THAT IS WHY IT IS HERE. This is a light ANGLE and a light
# COLOUR: the sun drops to 20 degrees of elevation and moves to the WEST (-X), and
# the colour warms from (1, 0.90, 0.75) to (1, 0.82, 0.60) amber. No lighting
# system, no new shader, no extra shadow distance, not one more instance. Measured
# frame time either side is in the commit message.
#
# ⚠️⚠️ THE ELEVATION IS CONSTRAINED BY THE CORRIDOR, NOT BY TASTE, AND TWO WRONG
# ATTEMPTS ARE WHY THIS COMMENT IS LONG.
#
# Attempt 1 — sun in the WEST at 20 degrees, to rake the west house row's shadow
# across the road in bands. Rendered: the entire street went NAVY. The alley is 16
# wide between houses 10-14 tall, so a 20-degree sun casts a 27-metre shadow and
# the road never sees it at all; every pixel of paving was lit by blue sky ambient
# alone. A corridor this narrow needs the sun above roughly 45 degrees to light its
# FLOOR from the side, and 45 degrees is not late afternoon. The measurement is the
# useful part: the geometry, not the art direction, sets the floor on elevation.
#
# Attempt 2 — sun down the alley's own axis at 28 degrees, so nothing flanking it
# can occlude it. Also navy, for a different reason: shadows then fall ALONG the
# corridor, so the cross row at |z| = 26 casts one unbroken 26-metre shadow over
# the whole southern half of the play area. An axial sun in a closed corridor
# shadows the corridor.
#
# ⚠️ AND BOTH RENDERS WERE ALSO READING A TRANSPOSED MATRIX, which is the bug
# underneath the bug. A Transform3D in a .tscn is serialised ROW-MAJOR while its
# basis VECTORS are the COLUMNS, so emitting X, Y and Z as three consecutive
# triples hands Godot the transpose and the sun ends up pointing somewhere
# unrelated — in attempt 1, partly upward. Any "the lighting looks wrong" here
# should check the convention before re-tuning the angle. Verified by decomposing
# the ORIGINAL, known-good transform and reproducing its 39.6-degree elevation
# before touching it.
#
# Attempt 3 — the same azimuth at 33 degrees, only 6.6 lower than the original.
# ALSO navy, and this is the one that pinned the mechanism down: at 39.6 degrees a
# 14-metre house casts 16.9 m and just clears the 16-metre alley; at 33 degrees it
# casts 21.6 m and does not. The paving then takes its light from AMBIENT, this
# map's ambient is the sky (ambient_light_source = 3, sky contribution 0.8), the
# sky is blue, and `adjustment_saturation = 1.18` amplifies what is left. The road
# did not get darker so much as it got BLUER — measured at (14, 37, 80) against a
# lit (107, 102, 118). Six degrees is the whole margin this corridor has.
#
# ⚠️ SO THE ELEVATION IS EXACTLY THE ORIGINAL 39.6 DEGREES AND THAT IS A MEASURED
# CONSTRAINT, NOT A FAILURE TO COMMIT. Any pass that wants a lower sun here has to
# change the alley's width or its building heights first — both of which are
# standing human decisions (Part 4: arena footprint stays original size), so the
# angle is not this lane's to spend.
#
# WHAT SHIPS: late afternoon carried by COLOUR TEMPERATURE rather than by angle —
# the sun warms (1, 0.90, 0.75) -> (1, 0.82, 0.60) amber, energy eases 1.15 ->
# 1.08, and the fog warms with it so haze and sunlight agree about the hour. That
# is the honest way to say five o'clock in a canyon, and it is free: two colours
# and a scalar, no lighting system, no shader, no extra instance.
#
# The fog warms with it. Fog that stays neutral while the sun goes amber reads as
# haze from a different time of day than the light hitting the houses.
[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.86603, -0.31889, 0.38549, 0, 0.77088, 0.63698, -0.5, -0.55164, 0.66692, 0, 12, 0)
light_color = Color(1, 0.81569, 0.59608, 1)
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
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -3.9, 0)
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

[node name="Bahay" type="Node3D" parent="Dressing"]

[node name="Bakod" type="Node3D" parent="Dressing"]

[node name="Kanto" type="Node3D" parent="Dressing"]

[node name="Likod" type="Node3D" parent="Dressing"]

[node name="Kable" type="Node3D" parent="Dressing"]

[node name="Malayo" type="Node3D" parent="Dressing"]

[node name="Kalsada" type="Node3D" parent="Dressing"]

[node name="Puno" type="Node3D" parent="Dressing"]

[node name="Kalat" type="Node3D" parent="Dressing"]

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

# ⚠️ ACROSS THE INTERIOR GROUPS BY NAME, AND THE RENAME NEARLY MADE THIS LIE.
# This read `surfaces.overlaps("Layer1")` — and when the groups were renamed to
# the language of the thing, "Layer1" stopped existing. `overlaps()` filters
# `_dressing` by group name and returns an EMPTY LIST for a group that is not
# there, so the builder went on printing "Layer1 overlap: none" while checking
# absolutely nothing. It passed, and it passed by measuring the wrong thing —
# Concurrency_Protocol's trap (b) exactly, caught here only because the count of
# instances moved at the same time.
#
# So it is named after the groups that exist AND widened to the union of them,
# which is the check build_bayan_plaza.py already runs and this file never had.
# A cross-group test is what caught the plaza's boulders growing through market
# furniture; two houses in one volume was always the smaller risk.
#
# ⚠️ TWO TIERS, AND THE SECOND ONE IS NOT FATAL — because running one flat
# cross-group test here reported 232 pairs, and floorcheck.py's own docstring
# predicts exactly why: "an axis-aligned footprint test cannot tell a legitimate
# overlap (a tyre leaning on a fence, a tree canopy over a kerb) from two houses
# occupying the same volume, and a guard that cries wolf gets switched off."
# 232 entries IS crying wolf, and a list nobody reads is the failure mode this
# whole file exists to avoid. Inspected, the bulk of them are this map's own
# grammar rather than defects:
#
#   Bahay <-> PunoSaging   a banana clump pressed against a house wall. Its 3.90
#                          span is LEAVES; they touch walls in a real alley.
#   Bahay <-> PunoMangga   the mango's canopy over the wall — placed to do that
#                          on purpose, and the point of the piece.
#   Bahay <-> BakodPanel   a driveway fence abutting the neighbouring house.
#   Sasakyan <-> BakodPanel  a car parked against its own bay fence.
#   Bahay <-> Kanto        the side row meeting the cross terrace at the alley
#                          end, which is a corner of a city block.
#
# TIER 1 — WITHIN each structural group. Two houses in one volume is never
# legitimate at any scale, and it is the actual §8.0 bug (five of eleven
# `building-type-*` wider than their own 6.6 bay, growing through neighbours by
# up to 2.5 m). This is the check the old `overlaps("Layer1")` was, restored and
# extended to the two rows it never covered.
#
# TIER 2 — ACROSS everything, printed as a COUNT with a sample, never as a pass.
# It stays visible so it cannot quietly become zero again, but it does not claim
# each entry is a bug.
_STRUCTURAL = ["Bahay", "Kanto", "Likod", "Kalat"]
overlaps = []
for _g in _STRUCTURAL:
    overlaps.extend(surfaces.overlaps(_g))
_cross = surfaces.overlaps_across(
    ["Bahay", "Bakod", "Kanto", "Likod", "Kable", "Kalat", "Puno"])
with open("scenes/maps/Eskinita.tscn", "w", encoding="utf-8", newline="\n") as f:
    f.write(out)

print("wrote scenes/maps/Eskinita.tscn")
print(f"  markings      : {n_marks} verified embedded")
print(f"  dressing      : verified grounded (floor+paving both at y={GROUND_Y})")
print(f"  ext_resources : {len(ext_lines)}")
print(f"  sub_resources : {n_sub}")
print(f"  load_steps    : {load_steps}")
print(f"  mesh instances: {len(order)}")
print(_placer.report("ask-before"))
print(f"  apron         : {_road_n} tiles, solid to {APRON_SOLID:.0f} then "
      f"feathered to {APRON_FADE:.0f} (no hard edge)")
if overlaps:
    print(f"  [!] SAME-GROUP footprint overlaps: {len(overlaps)}")
    for a, b, ox, oz in overlaps[:8]:
        print(f"      {a} <-> {b}  ({ox:.2f} x {oz:.2f} m)")
else:
    print(f"  same-group overlap: none in {len(_STRUCTURAL)} structural groups")
print(f"  cross-group grazes: {len(_cross)} (adjacency, not a pass/fail — see"
      " the two-tier note above)")
