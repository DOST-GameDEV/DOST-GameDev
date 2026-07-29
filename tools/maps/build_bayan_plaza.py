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
#   * Four-ring void kill: floor 60 -> 120, paved apron to ±38, two silhouette
#     belt rings at 36/45, depth fog 14 -> 50 (apron widened this pass).
#   * Panorama sky, and the env material pass on Dressing.
#   * Spawn heights derived from GROUND_Y, never typed.
#
# THE REFERENCE-PHOTO REDRESS — DONE 2026-07-29, rendered and looked at:
#   * THE MONUMENT. env_monument (4.90 tall, tiered plinth + spire) at
#     (-7.6, 6.4), inside a 4 x 6 env_railing enclosure with two gate lamps and
#     two clipped env_planter_hedge, plus five more hedges ringing the slab.
#     ⚠️ NOT CENTRED, and that is a human decision, not a shortcut — the centre
#     is the can's. "dont center monument, js make it seen and we're playing
#     near it". See the MONUMENT block for the four constraints that box in
#     every coordinate. tools/bayan_probe.tscn's new bp_monument shot is aimed
#     from the attacker's own spawn specifically to prove it IS seen.
#   * THE CIVIC BACK EDGE. env_bell_tower (14.3) and env_municipal_hall (red
#     roof, arcade) pulled in beside the church at z ~ -15, with the tree rings
#     stepped aside by _civic_blocked() rather than by a typed x-range.
#   * SIX PARKED TRICYCLES on the rim band, per the reference.
#   * THE PLAZA SLAB IS LIGHT NOW. env_toon_pass.gd gained SLAB_TINT; the slab
#     used to take ROAD_TINT and the plaza was the same dark grey as its ring
#     road, which is the opposite of the reference.
#
# OPEN ITEMS — the honest state:
#   1. [DONE 2026-07-29] LANDMARK FACING, and all three were WRONG. Measured,
#      not eyeballed: every plaza piece in env_kit.gd fronts on -Z (church door
#      at local z = -0.76, basketball rim on the origin with its board behind at
#      +0.52), so the church at z = -14.1 yaw 0 faced AWAY and rendered as a
#      blank grey slab in every shot ever taken of this map, and both basketball
#      rings faced the tree line. The env_kit.gd header claimed fronts are +Z
#      and that claim is now corrected there too — it is what caused this.
#   2. ⚠️ STILL OPEN, IMPROVED BUT NOT CLEARED. APRON 30 -> 38 and fog_depth_end
#      64 -> 50. Eye level and both corners still show ZERO map edge. The y=30
#      OVERHEAD STILL SHOWS A HARD APRON EDGE — it is further out and partly
#      fogged, but it is there, so this does NOT yet meet Eskinita's bar. Do not
#      mark it [x]. Next lever to try: fog_depth_end to ~40 with the belt's
#      outer ring pulled from 45 to ~38 so it is not fogged out with the edge.
#   3. [DONE 2026-07-29] Interior clutter pass — see the Dressing/Clutter block.
#   4. [DONE 2026-07-29] The HazardZone gutter_tile drainage bed.
#   5. [PARTLY DONE 2026-07-29] PERF AND AI MEASURED; still never played by a
#      human, still never networked.
#        * perf_probe gained `map=` (it had none, which is exactly why this map
#          had never been measured — every frame-time number ever recorded was
#          Eskinita wearing the project's name). 1920x1080, everything on:
#            eskinita     517 instances   cpu median  8.41 ms   p95 11.44   171 fps
#            bayan_plaza  671 instances   cpu median 10.19 ms   p95 10.19   167 fps
#          ~30% more instances for ~21% more CPU and 2% fewer fps. Comfortable
#          here, but this is ONE machine (RX 6600) and the standing warning that
#          heavy shading "made the game both ugly and laggy on other PCs" is
#          about other people's hardware, which this does not measure.
#        * ai_probe gained `map=` too and ran 20 rounds here for the first time.
#          Results track Eskinita closely (DEF 90%, dents 0.30, 0 timeouts) and
#          the LONGEST STILL-RUN IS 3.75 s versus Eskinita's 6.83 s — i.e. bots
#          get stuck LESS here, not more. Nothing pathologically snags on the
#          monument.
#        * THE TAYA CANNOT BE PINNED AGAINST MonumentBody, and it is geometry
#          rather than luck: the Can and Taya are clamped to the confinement
#          square (|x|,|z| <= 5, so 7.07 from centre at the corner) and the
#          monument's nearest corner sits ~8.1 out. It is unreachable by a
#          confined unit by ~1.3 units. Note that margin SHRANK when the clamp
#          became square (the circle kept the Taya 3.3 units clear), so it is
#          worth re-checking if CONFINEMENT_RADIUS is ever raised.
#   6. ⚠️ NEW, AND PRE-EXISTING. surfaces.overlaps_across() (added this pass)
#      reports 8 interior footprint overlaps that have nothing to do with the
#      redress: Lantern_1/2 <-> Stall_1/2, three Bench <-> Clutter pairs, and
#      three Clutter <-> Clutter pairs. All are 0.20-0.65 m grazes between flat
#      planks, benches, hedges and fence segments rather than solids sharing a
#      volume, which is why they were left alone rather than shuffled blind.
#      LOOK AT THE PRINTED LIST; do not assume it is empty because the build
#      succeeded. The same test on build_eskinita.py has never been run.
#   7. ⚠️ THE TREES ARE CONIFERS. Every tree in both rings is a Kenney pine, so
#      the plaza reads as a Nordic park with a Philippine church in it. The kits
#      in assets/models/kits/ contain no broadleaf or palm, so this cannot be
#      fixed by re-picking a piece — it needs either a new CC0 tree at this poly
#      budget or a generated one in env_kit.gd. Not attempted this pass.
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
from floorcheck import (Surfaces, embed_y, mesh_bounds,  # noqa: E402
                        read_confinement_radius)
## ⚠️ THE SHARED MODULE IS THE POINT OF THIS PASS, not a convenience import.
## This file's own header records why the first five bugs in it survived: "the
## two builders share floorcheck.py and nothing else. Every Eskinita lesson has
## to be ported by hand." mapkit.py is where a lesson goes so it is ported zero
## times — the placement guard, the feathered apron and the -Z front convention
## now live there and BOTH maps call them.
from mapkit import Placer, apron_cells, front_yaw  # noqa: E402,F401

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
CONFINEMENT_BOX_RADIUS = read_confinement_radius()
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

# --- The civic block (checklist 2.4, the reference-photo redress). -----------
#
# The reference is a real Philippine town plaza and its back edge is CIVIC: a
# church with a bell tower and a municipal hall with a red roof, both close
# enough to read as buildings rather than as shapes in the fog. The brief was
# explicit that they be "pulled IN from the silhouette belt so they become real
# landmarks instead of distant fog shapes".
#
# ⚠️ THEY ARE DECLARED BEFORE THE TREE RING BECAUSE THE TREE RING HAS TO MOVE
# OUT OF THEIR WAY. The near ring sits at z = -13.7 and the far ring at -17.5,
# which is exactly the band a 5.6-deep building standing at z = -16.6 occupies.
# Placing the buildings and leaving the rings alone puts a forest tree through
# the municipal hall's roof. `_civic_blocked()` below is what stops that, and it
# tests the FOOTPRINTS rather than an x-range somebody typed — an x-range is a
# second copy of these coordinates and would rot the first time one moved.
#
# Depths are the measured piece extents, not guesses: church_facade is 6.00 x
# 1.54, env_bell_tower 2.62 x 2.62 and env_municipal_hall 12.40 x 6.00.
CIVIC_MARGIN = 0.6

# (name, mesh, x, z, yaw). ⚠️ YAW = PI FOR ALL THREE, and that is open item 1
# closed by measurement rather than by eye. Every plaza piece in env_kit.gd
# fronts on -Z — the church's door and rose window are at its local z = -0.76,
# the basketball rim sits on the origin with its board behind at +0.52 — so a
# landmark standing at NEGATIVE z and facing the plaza needs yaw = PI. All three
# of this map's landmarks were at yaw 0 (or PI on the +z side, which is the same
# mistake mirrored), so the church rendered as a blank grey slab in every shot
# and both basketball rings faced the tree line. See the corrected convention
# note in env_kit.gd's header.
CIVIC = [
    ("Church", "church_facade", -4.2, -14.8, math.pi),
    ("BellTower", "bell_tower", 0.0, -15.4, math.pi),
    ("MunicipalHall", "municipal_hall", 7.8, -16.6, math.pi),
]
_CIVIC_BOXES = []
for _cn, _cm, _cx, _cz, _cy in CIVIC:
    _ce = piece_extent(_cm, _cy, 1.0)
    _CIVIC_BOXES.append((_cx + _ce[0] - CIVIC_MARGIN, _cx + _ce[1] + CIVIC_MARGIN,
                         _cz + _ce[2] - CIVIC_MARGIN, _cz + _ce[3] + CIVIC_MARGIN))


def _civic_blocked(mesh_name, x, z, yaw, scale):
    """True if a piece placed here would stand inside a civic building."""
    e = piece_extent(mesh_name, yaw, scale)
    x0, x1, z0, z1 = x + e[0], x + e[1], z + e[2], z + e[3]
    for bx0, bx1, bz0, bz1 in _CIVIC_BOXES:
        if x1 > bx0 and x0 < bx1 and z1 > bz0 and z0 < bz1:
            return True
    return False


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
        near_yaw = (k % 4) * 0.7
        if not _civic_blocked(near, x, z, near_yaw, TOWN_SCALE):
            add_kit("Dressing/TreesNear", f"Tree_{n}", near, x, z,
                    near_yaw, TOWN_SCALE)
        n += 1
        # The layer behind: a different kit, so it reads as another species
        # rather than the same tree moved back.
        far = "kits/forest/tree-high" if k % 2 else "kits/forest/tree"
        fx, fz, far_yaw = x * 1.28 - j * 0.4, z * 1.28 + j * 0.4, (k % 3) * 0.9
        if not _civic_blocked(far, fx, fz, far_yaw, FOREST_SCALE):
            add_kit("Dressing/TreesFar", f"TreeFar_{n}", far, fx, fz,
                    far_yaw, FOREST_SCALE)
        n += 1

# --- Ground cover, in the band BETWEEN THE TWO TREE RINGS. -------------------
#
# ⚠️ THESE MOVED OUT OF THE PLAY AREA, AND IT IS A BUG FIX RATHER THAN A
# REDRESS. They used to stand at |x| ~ 11.6, i.e. INSIDE the collision walls at
# +/-13, and `rock-small` measures 2.65 tall at TOWN_SCALE — more than double the
# 1.10 interior tier and well over an FPP Person's 1.25 eye. The interior-clutter
# block below already names this piece as the reason it is not used there
# ("would be aim-blocking walls despite reading as small rocks from their
# names") and then the Ground layer put eight of them inside the walls anyway.
#
# The second thing this fixes is that the old ring sat directly on the bench row
# at x = +/-10.9 and on the sari-sari stalls at +/-11.1. The cross-group overlap
# report at the bottom of this file lit up with roughly twenty Rock <-> Bench
# and Rock <-> Stall pairs the moment it was written — boulders growing through
# market furniture, on a map that had been rendered and signed off four times.
# A same-group `overlaps("Ground")` would never have said a word about it.
#
# 14.6..16.4 is the free band: the near tree ring is at 13.7 and the far at
# 17.5, so the boulders sit between the two layers of trees, which is where
# boulders belong and is also the one annulus with nothing else in it.
for k, (x, z) in enumerate([
        (-15.6, -7.0), (15.6, -4.0), (-15.2, 5.5), (15.9, 8.0),
        (-11.0, -16.2), (-15.8, -11.0), (-3.5, 15.6), (7.5, 15.3)]):
    add_kit("Dressing/Ground", f"Rock_{k}",
            ["kits/town/rock-small", "kits/forest/rocks-low",
             "kits/town/rock-wide"][k % 3], x, z, (k % 5) * 0.8, TOWN_SCALE)
for k, (x, z) in enumerate([
        (-16.2, 1.5), (16.4, 2.5), (2.0, 16.4), (-15.0, -2.0)]):
    add_kit("Dressing/Ground", f"Plant_{k}", "kits/forest/plant",
            x, z, (k % 4) * 1.1, FOREST_SCALE)

# --- The landmarks. The whole back edge is civic now (see the CIVIC block
# --- above for the coordinates and for why the yaws changed).
for _cn, _cm, _cx, _cz, _cy in CIVIC:
    add("Dressing/Landmarks", _cn, _cm, _cx, _cz, _cy)
# In front of the municipal hall, which is where a real one stands. Moved off
# the church's frontage, where it used to sit.
add("Dressing/Landmarks", "Flagpole", "flagpole", 4.6, -11.4)
# MANDATORY — it IS the Philippine plaza. Two, facing each other, because a
# barangay court has a ring at each end and it doubles as the map's long axis.
#
# ⚠️ BOTH YAWS ARE THE OPPOSITE OF WHAT THEY WERE, and this is the rest of open
# item 1. `env_basketball_ring` puts the rim on its own origin with the
# backboard and post BEHIND it at local z = +0.52/+0.62, so the ring is shot at
# from -Z. RingNorth stands at negative z and therefore needs yaw = PI to face
# the court; RingSouth stands at positive z and needs yaw = 0. It had exactly
# the reverse, so both rings faced the tree line and neither was playable to
# look at. "Facing each other" is now true rather than asserted.
add("Dressing/Landmarks", "RingNorth", "basketball_ring", -5.2, -SLAB + 0.6,
    math.pi)
add("Dressing/Landmarks", "RingSouth", "basketball_ring", 5.2, SLAB - 0.6, 0.0)
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
# ⚠️ EVERY PIECE FROM HERE DOWN ASKS BEFORE IT LANDS. That is R-19(a), and it
# is deliberately NOT "nudge the eight pairs the report happened to name".
#
# The eight interior overlaps this map shipped were all reported, read, and
# written up in this file's own header as "left alone rather than shuffled
# blind" — and they were still there a session later. A post-mortem list is the
# thing that let them survive: acting on it means hand-editing coordinates,
# hand-editing coordinates cannot be verified, and the next piece anyone adds
# starts the cycle again. Fixing the eight by hand would have left the SEVENTH
# still latent.
#
# So the placement sites themselves refuse. `Placer` (mapkit.py) tries the
# nominal spot, walks a short seeded ladder of small offsets if it is occupied,
# and skips-and-reports if none is clear. Its `avoid` list is exactly the set
# `overlaps_across()` checks at the bottom of this file, so a placement it
# approves cannot be reported by that one afterwards — the guard and the audit
# are looking at the same thing by construction rather than by coincidence.
PLACE_AVOID = ["Monument", "Clutter", "Furniture", "Landmarks", "Ground",
               "Vehicles", "KanalVisual"]
placer = Placer(surfaces, piece_extent, PLACE_AVOID)


def _put_kit(group):
    """A `place_fn` for Placer, bound to one node group."""
    def go(name, mesh_name, x, z, yaw, scale):
        add_kit(f"Dressing/{group}", name, mesh_name, x, z, yaw, scale)
    return go


def _put_gen(group):
    """The same, for a generated `env_*` piece — `add()` takes no scale."""
    def go(name, mesh_name, x, z, yaw, _scale):
        add(f"Dressing/{group}", name, mesh_name, x, z, yaw)
    return go


_furniture = _put_kit("Furniture")

n = 0
for k in range(6):
    t = -7.5 + k * 3.0
    for sx in (-1, 1):
        placer.try_place(_furniture, f"Bench_{n}", "kits/town/stall-bench",
                         sx * (SLAB + 0.9), t, math.pi / 2, TOWN_SCALE)
        n += 1
# The sari-sari stalls — the plaza's own reason to have people in it.
#
# ⚠️ THESE GET THE LADDER RATHER THAN A SKIP, and the distinction is the whole
# reason Placer has one. Stall_1 and Stall_2 are two of the eight reported
# overlaps (against the slab-corner lanterns), and "ask before placing" applied
# naively would resolve that by DELETING two of the four sari-sari stalls — the
# plaza's only market vocabulary — to save a 0.5 m graze with a lamp post. A
# stall is content; a boundary hedge is filler. The ladder moves the stall half
# a metre and keeps both.
for k, (x, z, yaw) in enumerate([
        (-SLAB - 1.1, -10.5, 0.0), (SLAB + 1.1, -10.5, math.pi),
        (-SLAB - 1.1, 10.5, 0.0), (SLAB + 1.1, 10.5, math.pi)]):
    placer.try_place(_furniture, f"Stall_{k}",
                     ["kits/town/stall", "kits/town/stall-green",
                      "kits/town/stall-red", "kits/town/stall"][k],
                     x, z, yaw, TOWN_SCALE)
for k, (x, z) in enumerate([(-6.0, -6.0), (6.0, 6.0), (-6.0, 2.4), (7.0, -6.5)]):
    placer.try_place(_furniture, f"Stool_{k}", "kits/town/stall-stool",
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
# ⚠️ THE FENCE RUN'S PITCH IS MEASURED, AND THAT IS TWO OF THE EIGHT OVERLAPS.
# Clutter_4 <-> Clutter_5 and Clutter_6 <-> Clutter_7 were both 0.20 x 0.20
# grazes between CONSECUTIVE SEGMENTS OF THE SAME FENCE — the run was stepped by
# a typed 2.4 while `kits/town/fence` measures 1.0 in its own Z, i.e. 2.6 at
# TOWN_SCALE. The segments were simply 200 mm too close.
#
# ⚠️ AND THE LADDER MUST NOT TOUCH THESE. A fence is a LINE: nudging one segment
# 0.55 m clear of its neighbour resolves the overlap by putting a hole in the
# fence, which is a worse artefact than the 200 mm interpenetration it fixes and
# one no probe would ever report. This is the case Placer's `ladder=False`
# exists for — but it does not even get that far, because the pitch is now
# derived from the piece and the run does not overlap itself at all. A guard is
# the wrong tool for a number that was simply wrong.
#
# ⚠️ AND ITS X IS OFF-ORIGIN BY 1.2 m, WHICH IS THE THIRD OVERLAP. `kits/town/
# fence` is modelled at local x = 0.425..0.500 — the panel is NOT centred on its
# own origin, it hangs a metre and a bit to one side of it. So "put the fence
# line at x = 8.6" actually put the panels at x = 9.7..9.9, hard against the
# bench row whose footprint starts at 9.68. That is the reported Bench_11 <->
# Clutter_6 pair, and it is the same class of bug as the hovering van: a piece
# placed by its origin when its origin is not where its geometry is.
#
# FENCE_OFF re-centres the run on the x it was asked for, measured off the piece
# rather than typed. Rule 3 of build_eskinita.py's header, applied on the axis
# nobody checked.
_fence_lo, _fence_hi = mesh_bounds("kits/town/fence")
FENCE_PITCH = (_fence_hi[2] - _fence_lo[2]) * TOWN_SCALE + 0.05
FENCE_OFF = (_fence_lo[0] + _fence_hi[0]) * 0.5 * TOWN_SCALE

n = 0
for k, (x, z, yaw, piece) in enumerate([
        # Hedges break the open floor into readable pockets without hiding a
        # Person — 0.65 is knee-high, so you always see who is behind one.
        (-7.4, 0.6, 0.0, "kits/town/hedge"),
        (7.4, -0.6, 0.0, "kits/town/hedge"),
        (-5.8, -7.0, math.pi / 2, "kits/town/hedge"),
        (4.6, 8.4, math.pi / 2, "kits/town/hedge"),
        # A broken fence line, the classic plaza edge nobody has repaired.
        (-8.6 - FENCE_OFF, -6.4, 0.0, "kits/town/fence-broken"),
        (-8.6 - FENCE_OFF, -6.4 + FENCE_PITCH, 0.0, "kits/town/fence"),
        (8.6 - FENCE_OFF, 6.4, 0.0, "kits/town/fence-broken"),
        (8.6 - FENCE_OFF, 6.4 - FENCE_PITCH, 0.0, "kits/town/fence"),
        # Seating scattered off the benches at the rim, so the middle distance
        # has something in it at all.
        # ⚠️ TWO OF THESE MOVED WHEN THE MONUMENT LANDED, and the enclosure is
        # why: the railing ring occupies x -9.6..-5.6, z 4.0..10.0, which is
        # where the (-5.2, 4.6) stool and the (-6.8, 8.2) bench used to stand.
        # They are not deleted — the plaza still needs seating on that side —
        # they are moved clear, and surfaces.overlaps_across() at the bottom of
        # this file is what proves it rather than this comment.
        (-5.6, 1.4, 0.9, "kits/town/stall-stool"),
        (5.2, -4.6, 2.4, "kits/town/stall-stool"),
        (-3.9, -5.2, 1.7, "kits/town/stall-stool"),
        (3.9, 5.2, 0.3, "kits/town/stall-stool"),
        (2.0, 8.6, 0.0, "kits/town/stall-bench"),
        (6.8, -8.2, math.pi / 2, "kits/town/stall-bench"),
        # Flat planks read as patched paving — pure ground texture, 0.16 tall,
        # and they cannot block a throw at any range.
        (-8.3, 1.2, 0.0, "kits/town/planks"),
        (9.0, -2.6, 0.0, "kits/town/planks"),
        (-2.0, -10.6, 0.0, "kits/town/planks"),
        (4.4, -9.2, 0.0, "kits/town/planks")]):
    # ⚠️ THE FENCE SEGMENTS ARE PINNED (`ladder=False`) AND EVERYTHING ELSE IS
    # NOT. See FENCE_PITCH above: a fence run must stay a run, so if a segment
    # is ever genuinely blocked the right answer is a reported skip, not a
    # silently displaced post. The hedges, stools, benches and planks are
    # scatter and may move half a metre without meaning anything.
    _is_run = "fence" in piece
    placer.try_place(_put_kit("Clutter"), f"Clutter_{n}", piece, x, z, yaw,
                     TOWN_SCALE, ladder=not _is_run)
    n += 1

# --- THE MONUMENT (checklist 2.4, the reference-photo redress). --------------
#
# The reference photo's entire identity is its centre: a tiered monument on a
# plinth, inside an iron railing ring, with clipped hedges in planters. This map
# had NOTHING there — a bare slab with a tree ring round it.
#
# ⚠️ IT CANNOT GO IN THE MIDDLE, AND THAT IS A GAMEPLAY FACT, NOT A COMPROMISE.
# The middle of this plaza is where the lata stands. LANE_RADIUS = 3.2 is a hard
# no-build disc around it and assert_clear_of_lane() ABORTS THE BUILD on
# violation, plus the two throwing approaches at |x| <= 2.5, |z| <= 7.0. A
# monument at the origin would be a permanent wall between every attacker and
# the can.
#
# Human call, 2026-07-29, when this was put to them as a gameplay decision
# rather than an art one: "dont center monument, js make it seen and we're
# playing near it". So the composition moves off-axis and the SIZE does the work
# the centre position would have done — 4.90 tall against a 1.6 Person, in a
# railed enclosure 4 x 6, standing on the plaza slab a metre outside the
# confinement box's south-west corner. From the south throwing line it fills the
# left of the frame; you fight beside it, which is what was asked for.
#
# ⚠️ EVERY NUMBER BELOW IS BOXED IN BY FOUR CONSTRAINTS AT ONCE, so none of them
# is free to nudge:
#   * outside LANE_RADIUS and both throwing approaches (asserted, aborts)
#   * outside the confinement box (|x| <= 5, |z| <= 5, CONFINEMENT_BOX_RADIUS) —
#     the Taya's own arena must not have scenery standing in it
#   * inside the slab (|x| <= 10, |z| <= 10), so nothing stands on the apron
#   * clear of the bench row at x = +/-10.9 and of the Clutter pieces, which is
#     checked by surfaces.overlaps_across() at the bottom of this file rather
#     than by reading coordinates
# The enclosure is RECTANGULAR (4 wide, 6 long) for exactly this reason: a 6 x 6
# square is what the composition wants and its east rail would land at x = -4.4,
# inside the confinement box. 4 x 6 keeps the long axis where there is room.
MON_X, MON_Z = -7.6, 6.4
MON_HALF_X, MON_HALF_Z = 2.0, 3.0     # the railing ring, in bay-multiples of 2.0

add("Dressing/Monument", "Monument", "monument", MON_X, MON_Z)

# The railing. One 2.0-unit bay per grid step, posts shared between neighbours
# (see env_kit.gd::_railing). ⚠️ ONE BAY IS DELIBERATELY MISSING — the east face
# nearest the court is the ENTRANCE. A closed ring reads as a cage and, more to
# the point, a plaza monument you cannot walk into is a prop rather than a place.
_rail = 0
for _bx in (-1.0, 1.0):
    for _side in (-1.0, 1.0):
        add("Dressing/Monument", f"Rail_{_rail}", "railing",
            MON_X + _bx, MON_Z + _side * MON_HALF_Z, 0.0)
        _rail += 1
for _bz in (-2.0, 0.0, 2.0):
    for _side in (-1.0, 1.0):
        if _side > 0 and _bz < 0.0:
            continue   # the entrance, facing the court
        add("Dressing/Monument", f"Rail_{_rail}", "railing",
            MON_X + _side * MON_HALF_X, MON_Z + _bz, math.pi * 0.5)
        _rail += 1

# Gate lamps, flanking the entrance. Same thin-vertical trick as the slab-corner
# lanterns: they read at distance and there is nothing to a lantern's silhouette
# to shoot past.
#
# ⚠️ TWO, ON THE EAST CORNERS ONLY, and the west pair is deleted rather than
# moved. The west strip is the busiest 1.5 m on the map — the bench row's
# footprint reaches x = -9.68 and the slab-corner lantern stands at (-10, 10) —
# so a lamp on either west corner overlapped something no matter where it went.
# The east corners are the ones seen from the court anyway, which is the side
# the entrance is on, so two gate lamps is also the better composition. Found by
# the overlap report, not by looking at a render.
_lamp = 0
for _sz in (-1.0, 1.0):
    add_kit("Dressing/Monument", f"MonLantern_{_lamp}", "kits/town/lantern",
            MON_X + MON_HALF_X, MON_Z + _sz * MON_HALF_Z,
            _lamp * 1.57, TOWN_SCALE)
    _lamp += 1

# Clipped hedges in planters. TWO inside the enclosure, on its long axis — the
# only place they fit: a 2.60 monument inside a 4.0-wide ring leaves 0.7 of
# walkway on the short axis, which is less than a 1.20 planter. Measured, not
# eyeballed; the first layout put four in the corners and every one of them
# grew through either the monument's bottom step or the railing.
for _p, _pz in enumerate((-2.25, 2.25)):
    add("Dressing/Monument", f"MonHedge_{_p}", "planter_hedge",
        MON_X, MON_Z + _pz)
# ... and five more ringing the slab edge, which is the other half of what the
# reference has: the plaza's rim is planted, not bare. All five sit outside both
# throwing approaches and outside the confinement box.
#
# ⚠️ THESE ASK TOO. RimHedge_1 landed on a plank patch (Clutter_15) — the last
# of the eight, and the one that shows why the guard has to be at EVERY site
# rather than at the sites the report happened to name. The Monument group is
# built after Clutter, so it is the newcomer here, and a newcomer dropped onto a
# slab that already has eighteen things on it is exactly the case a post-mortem
# catches too late.
_monument_gen = _put_gen("Monument")
for _p, (_px, _pz) in enumerate([
        (9.0, 4.6), (9.0, -4.6), (-9.0, -4.6), (-2.0, 9.6), (2.0, -9.6)]):
    placer.try_place(_monument_gen, f"RimHedge_{_p}", "planter_hedge",
                     _px, _pz, 0.0, 1.0)

# --- Parked tricycles (the reference's ring of them round the edge). ---------
#
# ⚠️ THE TRICYCLE IS 1.26 TALL AND THEREFORE ABOVE THE 1.10 INTERIOR TIER. That
# is not an oversight and it is not a licence to scatter them: env_kit.gd's own
# note on the piece says it is WAIST-COVER TIER and "goes at the boundary or as
# deliberate cover — never scattered in the play area". Every one of these is on
# the rim band at |x| or |z| >= 11.7, which is 4.7 outside CONFINEMENT_BOX_RADIUS
# and 11.5+ from the base circle — further out than the bench row and the stalls
# that already stand there. Nothing thrown at the can from either approach can
# be occluded by geometry that far off the axis, and the build asserts the lane
# law on each of them anyway.
for _v, (_vx, _vz, _vyaw) in enumerate([
        (-9.0, -11.9, 0.4), (1.0, -11.7, 2.1), (8.6, -11.9, -0.7),
        (-8.8, 11.9, 3.0), (0.6, 11.7, 1.2), (9.0, 11.9, -2.4)]):
    add("Dressing/Vehicles", f"Tricycle_{_v}", "tricycle", _vx, _vz, _vyaw)

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
# ⚠️ 38, NOT 30, AND fog_depth_end MOVED WITH IT — that is open item 2.
# The eye-level and corner shots have shown zero map edge since the last pass;
# what stayed open was the y=30 overhead, where the paved apron ended in a hard
# square against bare floor with the void beyond. Two levers and BOTH are needed:
# widening the apron alone just moves the hard square further out, and pulling
# the fog in alone leaves the square visible inside the fog's reach. At 38 with
# fog_depth_end 50 the apron's own edge is past the point where the fog has
# fully closed, so there is nothing there to see from any height.
# Cost is measured, not assumed: the apron is one draw call per 4x4 tile, so
# 30 -> 38 is +136 instances on a map that was at 506. The alternative — a
# second 120x120 floor mesh — is one draw call but reintroduces the flat-plane
# read that the four-ring kill exists to prevent.
# ⚠️ THE APRON NO LONGER HAS AN EDGE — that is R-19(b), and it is a different
# KIND of fix from the two that came before it. Open item 2 above records both
# previous attempts: apron 30 -> 38, then fog_depth_end 64 -> 50. Neither worked
# and neither ever could, because a filled square of tiles has a straight edge at
# every radius and fog only lowers its contrast. The y=30 overhead is the one
# shot that looks along the fog's thinnest axis, so it is precisely the shot fog
# cannot rescue — which is why it stayed open through two "further out" passes.
#
# APRON_SOLID is paved solid; from there to APRON_FADE the tiles thin out on a
# per-cell hash until there are none. There is no line anywhere for the overhead
# to find. See mapkit.apron_cells.
#
# AND IT IS CHEAPER: the old hard square to 38 was ~325 tiles; this reaches SIX
# UNITS FURTHER OUT for fewer, because half the outer band is holes. The exact
# count is printed below, next to the instance total, so the claim is checkable.
APRON_SOLID = 26.0
APRON_FADE = 44.0
_ap = 0
_ROAD_YAW = [0, 1, 3, 2, 0, 3, 1, 2, 3, 0, 2, 1]
for _gx, _gz, _ix, _iz in apron_cells(
        APRON_SOLID, APRON_FADE, ROAD_SCALE, half=APRON_FADE,
        # The slab above already paves the core at a finer grid.
        skip_core=lambda x, z: abs(x) <= SLAB + 1.0 and abs(z) <= SLAB + 1.0):
    add_kit("Dressing/Apron", f"Apron_{_ap}", "kits/town/road", _gx, _gz,
            _ROAD_YAW[_ap % len(_ROAD_YAW)] * math.pi * 0.5,
            ROAD_SCALE, base_y=ROAD_BASE_Y, lane_exempt=True)
    _ap += 1

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
# THE PLAY-AREA BOUNDARY, MADE VISIBLE.
#
# Human ask: *"add or fix the play-area bounding box in the Bayan Plaza map."*
#
# ⚠️ THE COLLISION WAS NEVER MISSING. `Bounds/Wall*` are four StaticBody3D at
# |x| = |z| = 13.0 with 26-unit spans, so they close a square exactly at BOUND
# = 12.5 with the corners overlapping. Walking into them works. What does not
# exist is any REASON for them: they carry no MeshInstance3D at all, and this
# map's apron paves out to 38 units, so a player sees open plaza in every
# direction and then stops dead in the middle of it against nothing. That is the
# same defect `Dev_Plan.md` §1 records against the original arena ("the four
# Bounds/Wall* nodes are StaticBody3D + CollisionShape3D with no MeshInstance3D
# at all - functionally containing, visually absent"), never fixed here.
#
# So the boundary gets a read, in two layers, and both are things a real town
# plaza already has:
#
#   1. A chalk kerb line ON the wall plane. Four quads, the same `court_line`
#      mechanism the confinement square and the throwing line already use, so it
#      costs four marking instances and reads from any height including the
#      overhead shot. This is the layer that says WHERE the edge is.
#   2. A hedge row just inside it. This is the layer that says there IS an edge
#      at eye level, where a floor decal cannot be seen.
#
# ⚠️ THE HEDGES SIT INSIDE THE WALL, NOT ON IT. A piece straddling the collision
# plane is half in a place the player can never reach, which is both wasted and
# wrong: you would be able to see through your own boundary. HEDGE_INSET pulls
# them clear, and it is measured against the piece's own footprint rather than
# guessed - `piece_extent` is what every other placement in this file uses.
#
# ⚠️ AND THE COUNT IS DELIBERATELY SPARSE. A continuous wall of hedge is both a
# draw-call bill on a map already carrying ~640 instances and, per this file's
# own height law, an aim-blocking solid; a broken row reads as a boundary while
# staying a boundary you can throw over. `Art_Direction.md`'s lighting-and-perf
# decision ("lighting and shaders stay cheap") is the same constraint.
BOUNDARY_HEDGE_STEP = 3.2
BOUNDARY_HEDGE_INSET = 0.9
## Which groups a boundary hedge must not land on. Everything a player can walk
## into, and nothing a player walks ON. See try_edge_hedge for what happens when
## this includes the paving.
BOUNDARY_AVOID_GROUPS = ["Clutter", "Furniture", "Landmarks", "Ground",
                         "Vehicles", "Monument", "KanalVisual", "TreesNear"]

court_line("BoundaryNorth", "x", -BOUND, BOUND)
court_line("BoundarySouth", "x", BOUND, BOUND)
court_line("BoundaryEast", "z", BOUND, BOUND)
court_line("BoundaryWest", "z", -BOUND, BOUND)

def try_edge_hedge(name, x, z, yaw):
    """Places one boundary hedge, or skips it if something is already there.

    ⚠️ ASKS FIRST. The perimeter walk lands on stalls, benches and the flagpole
    that were placed before it, and a fixed-step loop has no way to know that.
    Placing anyway produced 19 reported footprint overlaps in the first build of
    this row. See `Surfaces.footprint_is_clear`.
    """
    # ⚠️ AGAINST THE SOLID GROUPS ONLY, NOT EVERYTHING. `_dressing` also holds
    # the Apron and Slab paving, which by definition covers every square metre
    # of the map — so an unfiltered clearance test refuses EVERY placement and
    # the row silently comes out as four hedges out of twenty-eight. Measured
    # exactly that on the first run of this. The paving is a surface to stand a
    # hedge ON, not an obstacle to avoid.
    extent = piece_extent("kits/town/hedge", yaw, TOWN_SCALE)
    if not surfaces.footprint_is_clear(x + extent[0], x + extent[1],
                                       z + extent[2], z + extent[3],
                                       BOUNDARY_AVOID_GROUPS):
        return False
    # NOT lane-exempt. The row sits at |11.6| and LANE_RADIUS is 3.2, so it can
    # never trip the lane law - which is exactly why it should stay subject to
    # it. An exemption that is never needed is an exemption that silently covers
    # the next person who moves this row inward.
    add_kit("Dressing/Ground", name, "kits/town/hedge", x, z, yaw, TOWN_SCALE)
    return True


_edge = 0
_skipped = 0
_inner = BOUND - BOUNDARY_HEDGE_INSET
_step = -_inner
while _step <= _inner + 0.001:
    # The corners are skipped outright: two rows meeting at a right angle put two
    # pieces in the same volume, which is exactly what `overlaps_across` reports
    # and what `_shared_pier` had to be written to excuse for the railing.
    # Leaving the corner open avoids needing a second exception, and a plaza's
    # planting does not usually turn a hard corner either.
    if abs(_step) < _inner - 0.5:
        for _side in (-1.0, 1.0):
            # ⚠️ THE YAWS ARE NOT INTERCHANGEABLE AND THEY WERE SWAPPED FIRST
            # TIME. `kits/town/hedge` measures 0.65 x 0.65 x 2.6 at TOWN_SCALE,
            # i.e. it is LONG IN ITS OWN Z. So a row running along Z (the east
            # and west edges) wants yaw 0, and a row running along X (north and
            # south) wants a quarter turn. With the two the other way round every
            # piece lay ACROSS its own row: 2.6 units of it stuck into the arena,
            # consecutive pieces overlapped each other by 1.8, and the clearance
            # test then correctly refused 24 of the 28 placements. The symptom
            # was "the boundary is four hedges"; the cause was the rotation.
            for _x, _z, _yaw in ((_side * _inner, _step, 0.0),
                                 (_step, _side * _inner, math.pi * 0.5)):
                if try_edge_hedge(f"EdgeHedge_{_edge}", _x, _z, _yaw):
                    _edge += 1
                else:
                    _skipped += 1
    _step += BOUNDARY_HEDGE_STEP
print(f"  boundary      : 4 chalk kerbs + {_edge} hedges at |x|=|z|={_inner:.1f}"
      f" ({_skipped} skipped, already occupied)")

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

# ⚠️ Mat_floor's ALBEDO IS MATCHED TO THE APRON'S RENDERED COLOUR, and it is the
# second half of R-19(b). Feathering the apron turns its hard edge ragged; a
# ragged edge between two different colours is still an edge with teeth. Measured
# off this map's own y=30 overhead: apron (90, 88, 98) against floor (109, 101,
# 93) — cool paving over warm ground, so every gap the feather opened read as a
# warm speck. This is that ratio applied back to the albedo, so paving and floor
# are one colour and there is nothing for the dissolve to expose. One albedo on a
# material that already existed; no new resource, no shader, no cost.
SUBS = '''[sub_resource type="BoxShape3D" id="Shape_floor"]
size = Vector3(120, 8, 120)

[sub_resource type="StandardMaterial3D" id="Mat_floor"]
albedo_color = Color(0.36929, 0.36889, 0.40506, 1)
roughness = 1.0

[sub_resource type="BoxMesh" id="Mesh_floor"]
material = SubResource("Mat_floor")
size = Vector3(200, 1, 200)

[sub_resource type="BoxShape3D" id="Shape_wall_z"]
size = Vector3(1, 12, 26)

[sub_resource type="BoxShape3D" id="Shape_wall_x"]
size = Vector3(26, 12, 1)

[sub_resource type="BoxShape3D" id="Shape_killplane"]
size = Vector3(260, 4, 260)

[sub_resource type="BoxShape3D" id="Shape_hazard"]
size = Vector3(5, 3, 5)

[sub_resource type="BoxShape3D" id="Shape_monument"]
size = Vector3(2.6, 5, 2.6)

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
fog_depth_begin = 14.0
fog_depth_end = 50.0
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
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -3.9, 0)
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

[node name="Monument" type="Node3D" parent="Dressing"]

[node name="Vehicles" type="Node3D" parent="Dressing"]

[node name="Obstacles" type="Node3D" parent="."]

[node name="MonumentBody" type="StaticBody3D" parent="Obstacles"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {MON_X}, {GROUND_Y + 2.5:.3f}, {MON_Z})

[node name="CollisionShape3D" type="CollisionShape3D" parent="Obstacles/MonumentBody"]
shape = SubResource("Shape_monument")

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

# ⚠️ ACROSS the interior groups, not within each one. The monument enclosure is
# a NEW group dropped into a part of the slab that already had clutter and edge
# furniture on it, so a same-group test — which is all `overlaps()` does, and all
# build_eskinita.py has ever run — would have reported a clean sheet while the
# railing grew through a bench. A warning, not a failure, for the reason
# floorcheck.py's own docstring gives: an axis-aligned footprint test cannot tell
# a tree canopy over a kerb from two solids in the same volume. LOOK AT WHAT IT
# PRINTS; do not assume an empty list because the build succeeded.
_INTERIOR = ["Monument", "Clutter", "Furniture", "Landmarks", "Ground",
             "Vehicles", "KanalVisual"]


def _shared_pier(a, b):
    """The one coincidence that is BY DESIGN, named so it cannot hide others.

    `env_railing` carries a post at each end, at local x = +/-1.0, so two
    adjacent bays put a post in the same place on purpose — see that piece's own
    note for why a corner variant was rejected. The doubled post is exactly
    coincident and invisible, and at 0.19 it is just over OVERLAP_SLACK, so it
    would otherwise fill this report with fifteen entries and train the next
    reader to skim past it. Filtered by NAME PREFIX and nothing else: any pier
    overlapping something that is not another pier still reports.
    """
    pier = ("Rail_", "MonLantern")
    return a.startswith(pier) and b.startswith(pier)


_ov = [o for o in surfaces.overlaps_across(_INTERIOR)
       if not _shared_pier(o[0], o[1])]
if _ov:
    print(f"  [!] interior footprint overlaps: {len(_ov)}")
    for _a, _b, _ox, _oz in _ov[:10]:
        print(f"      {_a} <-> {_b}  ({_ox:.2f} x {_oz:.2f})")
else:
    print("  interior overlaps: none across "
          f"{len(_INTERIOR)} groups")

with open("scenes/maps/BayanPlaza.tscn", "w", encoding="utf-8", newline="\n") as f:
    f.write(out)

print("wrote scenes/maps/BayanPlaza.tscn")
print(f"  markings      : {n_marks} verified embedded")
print(placer.report("ask-before"))
print(f"  apron         : {_ap} tiles, solid to {APRON_SOLID:.0f} then feathered "
      f"to {APRON_FADE:.0f} (no hard edge)")
print(f"  ext_resources : {len(ext_lines)}")
print(f"  load_steps    : {load_steps}")
print(f"  mesh instances: {len(order)}")
