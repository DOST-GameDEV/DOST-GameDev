"""Emits scenes/maps/BayanPlaza.tscn.  (checklist 2.4 — layout author)

    python tools/maps/build_bayan_plaza.py     # run from the repo root

Same contract as build_eskinita.py: a dev-time tool, Godot never runs it, it
ships in no export, and the project stays GDScript only. EDIT THIS FILE, NOT THE
SCENE — re-running overwrites BayanPlaza.tscn wholesale.

⚠️ NO `#` COMMENTS INSIDE THE EMITTED .tscn. Godot's scene format does not use
`#`, and a stray one silently breaks the NEXT node's declaration. That cost a
debugging round on Eskinita ("parent path has vanished" on every Spawn marker).

WHY THIS MAP IS SHAPED DIFFERENTLY FROM ESKINITA, which is the whole point of
building a second one: an eskinita is a CORRIDOR and a plaza is a ROOM. Eskinita
is 16 wide by 34 long with walls you fight along; this is a 24x24 open square
with a tree ring you fight across. Same kit, same rules, opposite silhouette —
if both maps played the same there would be no reason to ship two.

It also reconciles the board with the GDD, per Art_Direction.md §1: the
board's "Province" (grass, dirt apron, trees ringing the map) is what you see
PAST the GDD's "Bayan Plaza". Three concentric materials — concrete slab, dirt
apron, tree line — satisfy both descriptions at once.
"""
# =============================================================================
# ⚠️⚠️ BAYAN PLAZA IS PARTIALLY UPGRADED. READ THIS BEFORE TOUCHING IT.
# =============================================================================
#
# Paused 2026-07-29 at the human's call ("finish up bayan work for now and add
# comments to fix it ltr and put ur plan there too") to spend the remaining
# budget on Eskinita. What is DONE and what is NOT is listed here so the next
# session does not have to re-derive it.
#
# DONE — this map now shares Eskinita's architecture:
#   * GROUND_Y contract: floor collision top == paving top == 0.100, so nothing
#     stands inside the ground and no spawn is embedded (B-116).
#   * Grounding guard ON. `Surfaces(base_height=GROUND_Y)` with the default
#     check_dressing=True — the Phase 8 deferral is over. `add()`/`add_kit()`
#     default base_y to the ground beneath the piece instead of a literal 0.0.
#   * `piece_extent()` — no kit dimension assumed, all three measured.
#   * Lane law, plaza edition: a protected DISC around the can (LANE_RADIUS)
#     plus the two throwing approaches, because a plaza is fought across rather
#     than along. Enforced at build time, aborts the build.
#   * Court markings: one closed rectangle with cross-lines, corner overlap
#     taken from the SIDE line's half-width (the 20mm overshoot bug).
#   * Four-ring void kill: floor 60 -> 120, paved apron to ±30, two silhouette
#     belt rings at 36/45, depth fog 16 -> 64.
#   * Panorama sky, and the env material pass on Dressing.
#   * Spawn heights derived from GROUND_Y, never typed.
#
# NOT DONE — the plan, in the order it should be picked up:
#   1. ⚠️ HOUSE ORIENTATION IS NOT APPLIED HERE. Eskinita's Layer 1 now faces its
#      buildings at the street after measuring that a City Kit building's front
#      is its local +Z (tools/facing_probe.gd). Bayan's belt rings got the same
#      treatment but its own TreesNear/TreesFar rings and Landmarks were never
#      re-checked. The church and the two basketball rings in particular are
#      placed by eye and have never been verified to face the plaza.
#   2. ⚠️ VOID ACCEPTANCE IS PASSED AT EYE LEVEL AND STILL OPEN FROM ABOVE.
#      Re-rendered 2026-07-29 via tools/bayan_probe.tscn: both corner shots
#      (y=1.6) and the eye shot show ZERO map edge — the belt and tree ring close
#      the horizon in every direction a player can actually stand. That is the
#      part that matters for play and it is done.
#      What is NOT done: the y=30 overhead still shows the paved apron ending in
#      a hard square against bare floor with the void beyond it, exactly as this
#      note originally described. No player camera is ever up there (Person is
#      FPP, Prop is TPP at ~4.5 spring length), so this is a spectator/debug-view
#      fault rather than a gameplay one — but Eskinita's bar includes it and this
#      map does not clear it yet. Widen APRON or pull fog_depth_end in, then
#      re-run the probe.
#   3. [DONE 2026-07-29] Interior clutter pass — 18 pieces in the annulus
#      between LANE_RADIUS and the tree line, all interior-tier, all lane-law
#      asserted at build time. See the Dressing/Clutter block.
#   4. [DONE 2026-07-29] The HazardZone at (-6.5, -4.0) now has a gutter_tile
#      drainage bed over its footprint, the same tell and the same mesh Eskinita
#      uses, sunk flush to GROUND_Y.
#   5. Never played, never networked, never perf-measured on this map.
#
# ⚠️ A TRAP THAT COST A RENDER PASS, 2026-07-29. `add()`/`add_kit()` will happily
# emit children under a parent path that DOES NOT EXIST in the template at the
# bottom of this file. Nothing warns at build time — the builder prints a clean
# instance count and writes the scene — and it fails only when GODOT instantiates
# it, as "Parent path './Dressing/Clutter' has vanished", once per node, with the
# geometry silently absent. Both new groups above needed their own
# `[node name=...]` line added to the template. If you add a new Dressing or
# Hazards subgroup, ADD IT THERE TOO, and re-run tools/bayan_probe.tscn — a build
# that succeeds proves nothing about whether the scene loads.
#
# ⚠️ DO NOT assume a fix that landed on Eskinita is live here. The two builders
# share floorcheck.py and nothing else — every lesson has to be ported by hand,
# and that is exactly how the first five bugs above survived.
# =============================================================================

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from floorcheck import Surfaces, embed_y, mesh_bounds  # noqa: E402

# ⚠️ PHASE 10 — THE DEFERRAL IS OVER. This map is now held to Eskinita's standard.
# Human call, 2026-07-29: "Build and generate the other maps ... Apply the exact
# same architectural blueprint and lessons you learned during the Eskinita
# overhaul (the grounding math, the four-ring void boundary, the strict throwing
# lane laws)."
#
# ⚠️ THE GROUNDING GUARD IS ON. `check_dressing=True` (the default) — this map
# was carrying the same 100mm sink and the same 525mm vehicle hover Eskinita had,
# and turning the guard on is what surfaced them.
#
# ⚠️ ONE HEIGHT FOR EVERY SURFACE, exactly as build_eskinita.py does it. The
# floor's COLLISION top and the paving top must be the same number or characters
# stand inside the visible ground and spawn embedded — see B-116.
ROAD_SCALE = 4.0
ROAD_TOP = 0.025 * ROAD_SCALE          # = 0.100
GROUND_Y = ROAD_TOP
ROAD_BASE_Y = GROUND_Y - ROAD_TOP      # a tile's BASE, so its TOP lands on GROUND_Y

surfaces = Surfaces(base_height=GROUND_Y)

SLAB = 10.0      # half-width of the hard plaza slab
BOUND = 12.5     # half-width of the playable square (collision sits here)
CELL = 2.0
MARK_Y = 0.07    # above the 0.06-tall tiles — see build_eskinita.py

meshes, ext, order = {}, [], []


def is_kit(name):
    """Kit pieces are 'kits/<kit>/<piece>' and are .glb SCENES, not Meshes.
    See build_eskinita.py's own note — emitting one as a MeshInstance3D is
    silent and renders nothing."""
    return name.startswith("kits/")


def mesh_path(name):
    return (f"res://assets/models/{name}.glb" if is_kit(name)
            else f"res://assets/models/env_{name}.obj")


def mesh(name):
    if name not in meshes:
        meshes[name] = str(len(meshes) + 1)
        ext.append((meshes[name], mesh_path(name), is_kit(name)))
    return meshes[name]


## One scale per kit, named — Art_Direction.md §0b. Fantasy Town is roughly
## character-scale already (its tree is 2.41 against a 1.6-unit Person), so it
## needs far less than the City Kit's 5x.
TOWN_SCALE = 2.6
FOREST_SCALE = 3.9


def xform_uniform(x, y, z, yaw, s):
    c, sn = math.cos(yaw), math.sin(yaw)
    return (f"Transform3D({c * s:.5f}, 0, {-sn * s:.5f}, 0, {s:.5f}, 0, "
            f"{sn * s:.5f}, 0, {c * s:.5f}, {x:.4f}, {y:.4f}, {z:.4f})")


def piece_extent(mesh_name, yaw=0.0, scale=1.0):
    """World-space footprint offsets of a piece, relative to its placement origin.
    Identical contract to build_eskinita.py's — see its docstring for why no
    dimension of a kit piece may be assumed."""
    lo, hi = mesh_bounds(mesh_name)
    c, sn = math.cos(yaw), math.sin(yaw)
    xs, zs = [], []
    for lx in (lo[0], hi[0]):
        for lz in (lo[2], hi[2]):
            xs.append((lx * c + lz * sn) * scale)
            zs.append((-lx * sn + lz * c) * scale)
    return (min(xs), max(xs), min(zs), max(zs), lo[1] * scale, hi[1] * scale)


# --- The lane law, plaza edition ---------------------------------------------
#
# Same rule as Eskinita (Art_Direction.md Part 6 §8.2) with the geometry a room
# needs rather than a corridor: a plaza is fought ACROSS, so the protected volume
# is a disc around the base circle plus the two throwing approaches, not a single
# north-south slot. Anything inside it turns a skill shot into a coin flip.
LANE_RADIUS = 3.2          # nothing new within this of the can, at any height
LANE_HALF_X = 2.5          # ... and nothing in the throwing approaches
LANE_Z = 7.0


def assert_clear_of_lane(name, x, z, extent):
    x0, x1 = x + extent[0], x + extent[1]
    z0, z1 = z + extent[2], z + extent[3]
    # Nearest point of the footprint to the base circle at the origin.
    nx = 0.0 if x0 <= 0.0 <= x1 else (x0 if x0 > 0.0 else x1)
    nz = 0.0 if z0 <= 0.0 <= z1 else (z0 if z0 > 0.0 else z1)
    if math.hypot(nx, nz) < LANE_RADIUS:
        raise SystemExit(
            "\nLANE LAW VIOLATION - build aborted, scene NOT written.\n"
            "  %s occupies x %.2f..%.2f, z %.2f..%.2f, which comes within\n"
            "  %.1f of the base circle. Nothing stands where the can is\n"
            "  defended.\n"
            % (name, x0, x1, z0, z1, LANE_RADIUS))
    if z1 >= -LANE_Z and z0 <= LANE_Z and x1 >= -LANE_HALF_X and x0 <= LANE_HALF_X:
        raise SystemExit(
            "\nLANE LAW VIOLATION - build aborted, scene NOT written.\n"
            "  %s occupies x %.2f..%.2f, z %.2f..%.2f, which enters a\n"
            "  throwing approach (|x| <= %.1f, |z| <= %.1f).\n"
            % (name, x0, x1, z0, z1, LANE_HALF_X, LANE_Z))


def add_kit(parent, name, mesh_name, x, z, yaw=0.0, scale=1.0, base_y=None,
            lane_exempt=False):
    """Places a kit piece with its BASE on the ground under it.

    ⚠️ `base_y` DEFAULTS TO THE GROUND, same as build_eskinita.py's. This map
    used to default it to a literal 0.0, which is the B-116 bug — a placement
    height measured against a floor that has since moved.
    """
    if base_y is None:
        base_y = surfaces.height_at(x, z)
    extent = piece_extent(mesh_name, yaw, scale)
    if not lane_exempt:
        assert_clear_of_lane(name, x, z, extent)
    y = base_y - extent[4]
    order.append((parent, name, mesh(mesh_name), xform_uniform(x, y, z, yaw, scale)))
    surfaces.record(name, mesh_name, x, y, z, yaw, scale, is_marking=False,
                    uniform=True, group=parent.split("/")[-1])


def xform(x, y, z, yaw=0.0):
    c, s = math.cos(yaw), math.sin(yaw)
    return (f"Transform3D({c:.5f}, 0, {-s:.5f}, 0, 1, 0, {s:.5f}, 0, {c:.5f}, "
            f"{x:.4f}, {y:.4f}, {z:.4f})")


def add(parent, name, mesh_name, x, z, yaw=0.0, base_y=None, lane_exempt=False):
    """Places a generated `env_*` piece, GROUNDED on whatever is under it."""
    if base_y is None:
        base_y = surfaces.height_at(x, z)
    lo, _hi = mesh_bounds(mesh_name)
    y = base_y - lo[1]
    extent = piece_extent(mesh_name, yaw, 1.0)
    if not lane_exempt:
        assert_clear_of_lane(name, x, z, extent)
    order.append((parent, name, mesh(mesh_name), xform(x, y, z, yaw)))
    surfaces.record(name, mesh_name, x, y, z, yaw, is_marking=False,
                    group=parent.split("/")[-1])


def add_mark(name, mesh_name, x, z, yaw=0.0, sx=1.0):
    """A field marking, embedded in whatever surface is under it."""
    y = embed_y(surfaces.height_at(x, z), mesh_name)
    c, sn = math.cos(yaw), math.sin(yaw)
    tf = (f"Transform3D({c * sx:.5f}, 0, {-sn * sx:.5f}, 0, 1, 0, {sn:.5f}, 0, "
          f"{c:.5f}, {x:.4f}, {y:.4f}, {z:.4f})")
    order.append(("Markings", name, mesh(mesh_name), tf))
    surfaces.record(name, mesh_name, x, y, z, yaw, sx, is_marking=True)


# --- The slab. A plaza is a hard floor; the dirt apron is the big floor box. --
#
# 2026-07-28, checklist 7.4b — "completely remake the floor arena of all maps
# with the assets." Fantasy Town paving replaces the generated `plaza_tile`, at
# the same 2-unit grid so the layout below is untouched.
#
# ⚠️ This raises the slab surface, and nothing below hardcodes a marking height
# because of it — `SLAB_TOP` asks `surfaces.height_at()` and every marking goes
# through `embed_y()`. Re-paving cannot leave a line buried or hanging; the
# build fails if it would.
## Mirrors CharacterBase.CONFINEMENT_RADIUS. Keep the two in sync.
CONFINEMENT_BOX_RADIUS = 5.0
SLAB_SCALE = CELL   # kit paving is 1x1, so the grid cell IS the scale
n = 0
i = int(SLAB / CELL)
for gx in range(-i, i):
    for gz in range(-i, i):
        # Ground is placed FIRST and is lane-exempt: the paving IS the lane.
        # base_y is the tile's BASE, so its TOP lands exactly on GROUND_Y.
        add_kit("Dressing/Slab", f"Tile_{n}", "kits/town/road",
                gx * CELL + CELL / 2, gz * CELL + CELL / 2, 0.0, SLAB_SCALE,
                base_y=GROUND_Y - 0.025 * SLAB_SCALE, lane_exempt=True)
        n += 1

# --- The tree ring. TWO layers, and the second is a DIFFERENT SPECIES as well
# --- as further out — the board rings Province with depth, and depth here is
# --- silhouette. Seeded spacing, never random.
#
# 2026-07-28, checklist 7.5 — Fantasy Town and Mini Forest trees replace the
# generated cones. Both rings sit OUTSIDE the playable square (collision is at
# BOUND = 12.5), so nothing here can block a Person's aim no matter how tall it
# grows; that is what lets these be full-height trees rather than the interior
# tier the furniture below is held to.
JITTER = [0.0, 0.9, -0.6, 1.4, -1.1, 0.4, -1.6, 1.1]
n = 0
step = 3.2
count = int((BOUND * 2) / step) + 1
for k in range(count):
    t = -BOUND + k * step
    j = JITTER[k % len(JITTER)]
    for sx, sz, axis in ((1, 0, "x"), (-1, 0, "x"), (0, 1, "z"), (0, -1, "z")):
        if axis == "x":
            x, z = sx * (BOUND + 1.2), t + j
        else:
            x, z = t + j, sz * (BOUND + 1.2)
        near = ["kits/town/tree-high", "kits/town/tree",
                "kits/town/tree-crooked", "kits/town/tree-high-round"][k % 4]
        add_kit("Dressing/TreesNear", f"Tree_{n}", near, x, z,
                (k % 4) * 0.7, TOWN_SCALE)
        n += 1
        # The layer behind: a different kit, so it reads as another species
        # rather than the same tree moved back.
        add_kit("Dressing/TreesFar", f"TreeFar_{n}",
                "kits/forest/tree-high" if k % 2 else "kits/forest/tree",
                x * 1.28 - j * 0.4, z * 1.28 + j * 0.4, (k % 3) * 0.9,
                FOREST_SCALE)
        n += 1

# --- Ground cover between the slab and the tree line, so the apron is not bare.
for k, (x, z) in enumerate([
        (-11.6, -7.0), (11.6, -4.0), (-11.2, 5.5), (11.9, 8.0),
        (-6.0, -11.6), (4.5, -11.9), (-3.5, 11.7), (7.5, 11.4)]):
    add_kit("Dressing/Ground", f"Rock_{k}",
            ["kits/town/rock-small", "kits/forest/rocks-low",
             "kits/town/rock-wide"][k % 3], x, z, (k % 5) * 0.8, TOWN_SCALE)
for k, (x, z) in enumerate([
        (-12.2, 1.5), (12.4, 2.5), (2.0, -12.3), (-1.5, 12.2)]):
    add_kit("Dressing/Ground", f"Plant_{k}", "kits/forest/plant",
            x, z, (k % 4) * 1.1, FOREST_SCALE)

# --- The landmark. One church, on the long axis, so a player always knows
# --- which way they are facing. Worth more than any three clutter pieces.
add("Dressing/Landmarks", "Church", "church_facade", 0.0, -BOUND - 1.6)
add("Dressing/Landmarks", "Flagpole", "flagpole", -4.5, -BOUND + 1.5)
# MANDATORY — it IS the Philippine plaza. Two, facing each other, because a
# barangay court has a ring at each end and it doubles as the map's long axis.
add("Dressing/Landmarks", "RingNorth", "basketball_ring", -5.2, -SLAB + 0.6)
add("Dressing/Landmarks", "RingSouth", "basketball_ring", 5.2, SLAB - 0.6, math.pi)
# Lantern posts mark the slab corners. Thin verticals, like Eskinita's electric
# posts — they read at distance and cost almost nothing to shoot past.
for k, (x, z) in enumerate([(-SLAB, -SLAB), (SLAB, -SLAB),
                            (-SLAB, SLAB), (SLAB, SLAB)]):
    add_kit("Dressing/Landmarks", f"Lantern_{k}", "kits/town/lantern",
            x, z, k * 1.57, TOWN_SCALE)

# --- Edge furniture. ⚠️ EVERY PIECE HERE IS INTERIOR-TIER (<= 1.1 tall) so an
# --- FPP Person, whose eye is at 1.25, can aim over all of it. That is the
# --- height law and the kit swap does not get to break it: at TOWN_SCALE the
# --- market stall is 0.96 and its bench is 0.60, both comfortably under.
# --- `cart` measures 1.40 scaled and is therefore deliberately NOT used here.
n = 0
for k in range(6):
    t = -7.5 + k * 3.0
    for sx in (-1, 1):
        add_kit("Dressing/Furniture", f"Bench_{n}", "kits/town/stall-bench",
                sx * (SLAB + 0.9), t, math.pi / 2, TOWN_SCALE)
        n += 1
# The sari-sari stalls — the plaza's own reason to have people in it.
for k, (x, z, yaw) in enumerate([
        (-SLAB - 1.1, -10.5, 0.0), (SLAB + 1.1, -10.5, math.pi),
        (-SLAB - 1.1, 10.5, 0.0), (SLAB + 1.1, 10.5, math.pi)]):
    add_kit("Dressing/Furniture", f"Stall_{k}",
            ["kits/town/stall", "kits/town/stall-green",
             "kits/town/stall-red", "kits/town/stall"][k],
            x, z, yaw, TOWN_SCALE)
for k, (x, z) in enumerate([(-6.0, -6.0), (6.0, 6.0), (-6.5, 7.0), (7.0, -6.5)]):
    add_kit("Dressing/Furniture", f"Stool_{k}", "kits/town/stall-stool",
            x, z, [0.5, 2.1, -1.2, 3.0][k], TOWN_SCALE)

# --- Interior clutter (open item 3). -----------------------------------------
#
# The plaza was Eskinita-pre-Phase-8 sparse: four stalls, twelve benches and
# eight rocks for a 24x24 room, which reads as a car park with furniture round
# the edge rather than as a barangay plaza.
#
# ⚠️ THE SAFE BAND HERE IS A RING, NOT TWO SIDE STRIPS. Eskinita's law is "keep
# out of the middle slot" and its clutter hugs the walls; this map's law is a
# DISC around the can plus two approach corridors, so the band that is legal to
# fill is the annulus between LANE_RADIUS and the tree line MINUS the |x| <=
# LANE_HALF_X corridor. Every coordinate below sits in it and the build asserts
# that rather than trusting this comment — assert_clear_of_lane() aborts and
# writes no scene if any footprint strays.
#
# ⚠️ EVERY PIECE IS INTERIOR-TIER (<= 1.1 tall), same law as the edge furniture
# above, and the heights are MEASURED not assumed. At TOWN_SCALE: stool 0.59,
# bench 0.59, hedge 0.65, fence 0.99, planks 0.16. Note what is NOT here —
# `rock-small` and `rock-wide` measure 2.65 scaled, well over a Person's 1.25
# eye, and would be aim-blocking walls despite reading as "small rocks" from
# their names. They stay out at the edge where the existing Ground layer puts
# them.
n = 0
for k, (x, z, yaw, piece) in enumerate([
        # Hedges break the open floor into readable pockets without hiding a
        # Person — 0.65 is knee-high, so you always see who is behind one.
        (-7.4, 0.6, 0.0, "kits/town/hedge"),
        (7.4, -0.6, 0.0, "kits/town/hedge"),
        (-4.6, -8.4, math.pi / 2, "kits/town/hedge"),
        (4.6, 8.4, math.pi / 2, "kits/town/hedge"),
        # A broken fence line, the classic plaza edge nobody has repaired.
        (-8.6, -6.4, 0.0, "kits/town/fence-broken"),
        (-8.6, -4.0, 0.0, "kits/town/fence"),
        (8.6, 6.4, 0.0, "kits/town/fence-broken"),
        (8.6, 4.0, 0.0, "kits/town/fence"),
        # Seating scattered off the benches at the rim, so the middle distance
        # has something in it at all.
        (-5.2, 4.6, 0.9, "kits/town/stall-stool"),
        (5.2, -4.6, 2.4, "kits/town/stall-stool"),
        (-3.9, -5.2, 1.7, "kits/town/stall-stool"),
        (3.9, 5.2, 0.3, "kits/town/stall-stool"),
        (-6.8, 8.2, math.pi / 2, "kits/town/stall-bench"),
        (6.8, -8.2, math.pi / 2, "kits/town/stall-bench"),
        # Flat planks read as patched paving — pure ground texture, 0.16 tall,
        # and they cannot block a throw at any range.
        (-9.0, 2.6, 0.0, "kits/town/planks"),
        (9.0, -2.6, 0.0, "kits/town/planks"),
        (-4.4, 9.2, 0.0, "kits/town/planks"),
        (4.4, -9.2, 0.0, "kits/town/planks")]):
    add_kit("Dressing/Clutter", f"Clutter_{n}", piece, x, z, yaw, TOWN_SCALE)
    n += 1

# --- The hazard's visual tell (open item 4). ---------------------------------
#
# ⚠️ THE `HazardZone` BELOW IS A LIVE GAMEPLAY VOLUME — speed_multiplier 0.5,
# permanent, a 5x5 box centred on (-6.5, -4.0) — AND IT HAD NO VISUAL AT ALL.
# An invisible slow field in the play area is not a missing decoration, it is a
# player being punished by something they cannot see or learn.
#
# Solved the way Eskinita solved exactly this problem after its pink chalk was
# deleted: with REAL 3D GEOMETRY that explains the slowdown physically rather
# than with a decal that decorates it. `gutter_tile` again, and deliberately the
# same mesh rather than a new one — the markings section below states the rule
# that a player must not have to relearn what a thing means when the map
# changes, and that applies at least as much to "this ground is slow" as it does
# to a base circle.
#
# On a plaza it reads as the drainage bed every real Philippine plaza has along
# its low corner, rather than as Eskinita's roadside kanal, but it is the same
# object and the same lesson.
#
# Sunk so its TOP lands on GROUND_Y (the mesh is 0.15 tall, measured, not
# assumed), so it is flush with the paving and nothing stands on a lip.
_HAZ_X, _HAZ_Z = -6.5, -4.0
_gut_lo, _gut_hi = mesh_bounds("gutter_tile")
_gut_top = _gut_hi[1] - _gut_lo[1]
_hn = 0
for _gx in (-1.0, 1.0):
    for _gz in (-2.0, 0.0, 2.0):
        add("Hazards/KanalVisual", f"Kanal_{_hn}", "gutter_tile",
            _HAZ_X + _gx, _HAZ_Z + _gz, 0.0, base_y=GROUND_Y - _gut_top)
        _hn += 1


# =============================================================================
# THE FOUR-RING VOID KILL, ported verbatim in principle from Eskinita.
# Art_Direction.md Part 6 §8.1. Ring 0 is the Floor box (widened in SUBS below),
# Ring 1 is the paved apron, Ring 2 the silhouette belt, Ring 3 the fog.
#
# ⚠️ A PLAZA NEEDS THIS MORE THAN A CORRIDOR DID, not less. Eskinita's house rows
# hide the horizon at eye level; an open square shows it in every direction, so
# the belt has to close all the way round rather than down two sides.
# =============================================================================
APRON = 30.0
_ap = 0
_gx = -APRON + ROAD_SCALE * 0.5
_ROAD_YAW = [0, 1, 3, 2, 0, 3, 1, 2, 3, 0, 2, 1]
while _gx <= APRON:
    _gz = -APRON + ROAD_SCALE * 0.5
    while _gz <= APRON:
        # Skip the core: the slab above already paves it at a finer grid.
        if abs(_gx) > SLAB + 1.0 or abs(_gz) > SLAB + 1.0:
            add_kit("Dressing/Apron", f"Apron_{_ap}", "kits/town/road", _gx, _gz,
                    _ROAD_YAW[_ap % len(_ROAD_YAW)] * math.pi * 0.5,
                    ROAD_SCALE, base_y=ROAD_BASE_Y, lane_exempt=True)
            _ap += 1
        _gz += ROAD_SCALE
    _gx += ROAD_SCALE

# Ring 2 - the silhouette belt. Two quiet rings, faded into fog by
# env_toon_pass.gd, same as Eskinita after the Phase 9 downgrade.
BELT_TYPES = ["b", "d", "n", "q", "t", "u", "f", "p", "r", "k", "m", "s", "a"]
_belt_jit = [0.0, 2.7, -1.9, 4.1, -3.3, 1.4, -2.2, 3.6, -0.8, 2.1, -4.0, 0.6]
_belt = 0
for _ring_i, _ring in enumerate((36.0, 45.0)):
    _step = 11.0 + _ring_i * 2.0
    for _side in (-1.0, 1.0):
        _zz = -48.0
        while _zz <= 48.0:
            _j = _belt_jit[_belt % len(_belt_jit)]
            add_kit("Dressing/Belt", f"BeltX_{_belt}",
                    f"kits/city/building-type-{BELT_TYPES[_belt % len(BELT_TYPES)]}",
                    _side * (_ring + _j * 0.35), _zz + _j,
                    # Fronts along the ring, so the belt reads as streets rather
                    # than a wall of blank gable ends - see build_eskinita.py.
                    (_j * 0.11) + ((math.pi * 0.5) if _side > 0 else (-math.pi * 0.5)),
                    5.0 * (1.0 + _ring_i * 0.15), lane_exempt=True)
            _belt += 1
            _zz += _step
        _xx = -48.0
        while _xx <= 48.0:
            _j = _belt_jit[_belt % len(_belt_jit)]
            add_kit("Dressing/Belt", f"BeltZ_{_belt}",
                    f"kits/city/building-type-{BELT_TYPES[_belt % len(BELT_TYPES)]}",
                    _xx + _j, _side * (_ring + _j * 0.35),
                    (_j * 0.13) + (0.0 if _side > 0 else math.pi),
                    5.0 * (1.0 + _ring_i * 0.15), lane_exempt=True)
            _belt += 1
            _xx += _step

# --- Field markings. Identical grammar to Eskinita on purpose: a player must
# --- not have to relearn what a base circle looks like when the map changes.
# ⚠️ MARK_Y IS GONE — the height comes from the geometry now, not from a
# constant somebody has to keep true. Unlike Eskinita, this map's markings all
# sit on the uniform plaza slab, so one height IS correct here; it is asked for
# rather than assumed so it cannot drift if the slab tile ever changes.
# floorcheck aborts the build if any of these floats. See build_eskinita.py.
# ⚠️⚠️ ONE CLOSED RECTANGLE WITH CROSS-LINES, exactly as Eskinita does it.
# Free-floating line segments with nothing to terminate on are what read as
# "overshooting" and "not closing" there, and the fix transfers verbatim: the
# court's two long sides bound everything and every cross-line ends INSIDE them.
#
# ⚠️ The overlap is the SIDE line's half-width, never the drawn line's own.
# throwing_line_decal is 0.12 wide against team_side_decal's 0.08, and using a
# line's own width overshoots the corner by 20mm — measured on Eskinita.
SIDE_LINE_MESH = "team_side_decal"
COURT_X = CONFINEMENT_BOX_RADIUS
COURT_Z = 9.5


def court_line(name, axis, at, half_len, mesh_name=SIDE_LINE_MESH):
    lo, hi = mesh_bounds(mesh_name)
    side_lo, side_hi = mesh_bounds(SIDE_LINE_MESH)
    half_w = (side_hi[2] - side_lo[2]) * 0.5
    sx = ((half_len + half_w) * 2.0) / (hi[0] - lo[0])
    if axis == "x":
        add_mark(name, mesh_name, 0.0, at, 0.0, sx)
    else:
        add_mark(name, mesh_name, at, 0.0, math.pi * 0.5, sx)


add_mark("BaseCircle", "base_circle_decal", 0.0, 0.0)
court_line("CourtEast", "z", COURT_X, COURT_Z)
court_line("CourtWest", "z", -COURT_X, COURT_Z)
court_line("CourtNorth", "x", -COURT_Z, COURT_X)
court_line("CourtSouth", "x", COURT_Z, COURT_X)
# The confinement square mirrors CharacterBase.CONFINEMENT_RADIUS, same as
# Eskinita — its east/west edges ARE the court sides, so they are not redrawn.
court_line("ConfinementNorth", "x", -CONFINEMENT_BOX_RADIUS, COURT_X)
court_line("ConfinementSouth", "x", CONFINEMENT_BOX_RADIUS, COURT_X)
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
# The panorama sky - see build_eskinita.py's note. One texture fetch, cheaper
# than the ProceduralSkyMaterial it replaces, and it is what stops the horizon
# reading as "an endless desert".
ext_lines.append('[ext_resource type="Texture2D" '
                 'path="res://assets/models/materials/sky_panorama.png" id="SKY"]')
# Checklist 4.1 - this map's own ambience bed. A DIFFERENT file from Eskinita's
# on purpose: see build_eskinita.py's note on why the bed belongs to the map.
# An open barangay plaza is airy and wide where an eskinita is close and
# enclosed, and one shared loop would flatten the only cue the player has that
# they have changed venue. CC0 - source, author and licence in
# assets/audio/ambience/OPENGAMEART_CC0_LICENSE.txt, which is what Form 03 needs.
ext_lines.append('[ext_resource type="AudioStream" '
                 'path="res://assets/audio/ambience/bayan_plaza.wav" id="AMB"]')

SUBS = '''[sub_resource type="BoxShape3D" id="Shape_floor"]
size = Vector3(120, 1, 120)

[sub_resource type="StandardMaterial3D" id="Mat_floor"]
albedo_color = Color(0.44706, 0.42353, 0.38431, 1)
roughness = 1.0

[sub_resource type="BoxMesh" id="Mesh_floor"]
material = SubResource("Mat_floor")
size = Vector3(120, 1, 120)

[sub_resource type="BoxShape3D" id="Shape_wall_z"]
size = Vector3(1, 12, 26)

[sub_resource type="BoxShape3D" id="Shape_wall_x"]
size = Vector3(26, 12, 1)

[sub_resource type="BoxShape3D" id="Shape_killplane"]
size = Vector3(260, 4, 260)

[sub_resource type="BoxShape3D" id="Shape_hazard"]
size = Vector3(5, 3, 5)

[sub_resource type="PanoramaSkyMaterial" id="Sky_mat"]
panorama = ExtResource("SKY")
energy_multiplier = 1.0

[sub_resource type="Sky" id="Sky_res"]
sky_material = SubResource("Sky_mat")

[sub_resource type="Environment" id="Env_plaza"]
background_mode = 2
sky = SubResource("Sky_res")
ambient_light_source = 2
ambient_light_color = Color(0.451, 0.545, 0.686, 1)
ambient_light_energy = 0.6
tonemap_mode = 0
tonemap_white = 1.2
ssao_enabled = true
ssao_radius = 1.1
ssao_intensity = 2.4
ssao_power = 1.6
ssao_detail = 0.4
fog_enabled = true
fog_light_color = Color(0.878, 0.847, 0.741, 1)
fog_light_energy = 1.0
fog_sun_scatter = 0.12
fog_mode = 1
fog_density = 0.0
fog_sky_affect = 0.22
fog_depth_curve = 1.1
fog_depth_begin = 16.0
fog_depth_end = 64.0
fog_aerial_perspective = 0.3
adjustment_enabled = true
adjustment_brightness = 1.0
adjustment_contrast = 1.07
adjustment_saturation = 1.18
'''

# Spawn0-3 are ROLE slots (Can / Taya / Attacker / Tsinelas), same scheme and
# same coordinates as build_eskinita.py — see that file's comment above its
# own SpawnPoints block for the full reasoning. Centred on this map's own
# base_circle_decal (0,0,0) and south throwing_line_decal (0,0,6) below.
#
# ⚠️ Spawn1's Z IS NEGATIVE, and this comment used to be a lie about it.
# It read "same coordinates as build_eskinita.py" while Spawn1 sat at z = +1.5
# against Eskinita's -1.5 — mirrored. The Attacker is at z = +6, so +1.5 put the
# Taya BETWEEN the Can and the attacker, on the attacker's own side, instead of
# guarding from behind. That is the exact layout the human rejected in the
# 2026-07-28 playtest ("the person in same team is behind that can"), fixed once
# in Eskinita and never carried across. If you change one map's spawn block,
# diff it against the other in the same commit — the claim that they match is
# load-bearing and nothing was checking it.
HEAD = f'''[node name="BayanPlaza" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env_plaza")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.86, -0.28, 0.42, 0, 0.83, 0.55, -0.51, -0.47, 0.72, 0, 9, 0)
light_color = Color(1, 0.953, 0.878, 1)
light_energy = 1.2
light_angular_distance = 1.2
shadow_enabled = true
shadow_bias = 0.03
shadow_normal_bias = 1.5
directional_shadow_max_distance = 60.0

[node name="Floor" type="StaticBody3D" parent="."]

[node name="CollisionShape3D" type="CollisionShape3D" parent="Floor"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.4, 0)
shape = SubResource("Shape_floor")

[node name="MeshInstance3D" type="MeshInstance3D" parent="Floor"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.415, 0)
mesh = SubResource("Mesh_floor")

[node name="Bounds" type="Node3D" parent="."]

[node name="WallEast" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 13.0, 6, 0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="Bounds/WallEast"]
shape = SubResource("Shape_wall_z")

[node name="WallWest" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -13.0, 6, 0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="Bounds/WallWest"]
shape = SubResource("Shape_wall_z")

[node name="WallNorth" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 6, -13.0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="Bounds/WallNorth"]
shape = SubResource("Shape_wall_x")

[node name="WallSouth" type="StaticBody3D" parent="Bounds"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 6, 13.0)

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
volume_db = -14.0

[node name="Hazards" type="Node3D" parent="."]

[node name="HazardZone" type="Area3D" parent="Hazards"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -6.5, 1.5, -4.0)
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

[node name="Apron" type="Node3D" parent="Dressing"]

[node name="Belt" type="Node3D" parent="Dressing"]

[node name="Slab" type="Node3D" parent="Dressing"]

[node name="TreesNear" type="Node3D" parent="Dressing"]

[node name="TreesFar" type="Node3D" parent="Dressing"]

[node name="Ground" type="Node3D" parent="Dressing"]

[node name="Landmarks" type="Node3D" parent="Dressing"]

[node name="Furniture" type="Node3D" parent="Dressing"]

[node name="Clutter" type="Node3D" parent="Dressing"]

[node name="Markings" type="Node3D" parent="."]
'''

body = []
kit_ids = {i for i, _p, kit in ext if kit}
for parent, name, mid, tf in order:
    if mid in kit_ids:
        # A .glb is a PackedScene and must be INSTANCED. Emitting it as a
        # MeshInstance3D is silent and draws nothing — see build_eskinita.py.
        body.append(f'\n[node name="{name}" parent="{parent}" instance=ExtResource("{mid}")]')
        body.append(f'transform = {tf}')
    else:
        body.append(f'\n[node name="{name}" type="MeshInstance3D" parent="{parent}"]')
        body.append(f'transform = {tf}')
        body.append(f'mesh = ExtResource("{mid}")')

n_sub = SUBS.count("[sub_resource")
load_steps = len(ext_lines) + n_sub + 1

out = (f'[gd_scene load_steps={load_steps} format=3]\n\n'
       + "\n".join(ext_lines) + "\n\n" + SUBS + "\n" + HEAD + "\n".join(body) + "\n")

# Before writing, never after — a floating marking must not reach the scene file
# at all. See build_eskinita.py's own note.
n_marks = surfaces.verify()

with open("scenes/maps/BayanPlaza.tscn", "w", encoding="utf-8", newline="\n") as f:
    f.write(out)

print("wrote scenes/maps/BayanPlaza.tscn")
print(f"  markings      : {n_marks} verified embedded")
print(f"  ext_resources : {len(ext_lines)}")
print(f"  load_steps    : {load_steps}")
print(f"  mesh instances: {len(order)}")
