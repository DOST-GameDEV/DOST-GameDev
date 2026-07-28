"""Emits scenes/maps/Eskinita.tscn.  (checklist 2.2 — layout author)

    python tools/maps/build_eskinita.py        # run from the repo root

⚠️ THIS IS A DEV-TIME TOOL, NOT PART OF THE GAME. Godot never runs it, it ships
in no export, and it adds no runtime dependency — the project stays GDScript
only. It is committed for the same reason the mesh generator is: 123 dressing
instances placed by hand are unmaintainable and unreviewable, and a layout you
cannot re-derive is a layout nobody will ever adjust.

EDIT THIS FILE, NOT THE SCENE. Re-running overwrites Eskinita.tscn wholesale.

A .tscn is hand-written text by policy (Concurrency_Protocol §6: an editor
re-save reorders properties and turns a two-line change into a 200-line diff).
But ~90 dressing instances is too many to hand-place without a typo, so this
script is the author and its output is committed. Re-run it to change the
layout; do not hand-edit the scene.

Layout reasoning lives in docs/Art_Direction.md §4:
  * Floor stays 40x40 (arena scale is NOT changed in the same commit as arena
    art) with its top surface at y=0.
  * The alley reads narrow anyway, because Layer 1 walls come in to x=+/-8.
  * Collision is ONE invisible box ring just behind the wall line, not a shape
    per prop. The spec explicitly permits this where the dressing is continuous,
    and it is both cheaper and impossible to get stuck on.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from floorcheck import Surfaces, embed_y, mesh_bounds  # noqa: E402

surfaces = Surfaces()

W = 8.0          # half-width of the playable alley
Z_END = 17.0     # half-length
CELL = 2.0

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
    # without a new mesh asset — used to tile team_side_decal into a polygonal
    # ring for the confinement-radius marker below.
    c, s = math.cos(yaw), math.sin(yaw)
    return (f"Transform3D({c * sx:.5f}, 0, {-s * sx:.5f}, 0, 1, 0, {s:.5f}, 0, {c:.5f}, "
            f"{x:.4f}, {y:.4f}, {z:.4f})")


def add(parent, name, mesh_name, x, y, z, yaw=0.0, sx=1.0):
    order.append((parent, name, mesh(mesh_name), xform(x, y, z, yaw, sx)))
    # Every piece is recorded, so `surfaces.verify()` below can work out what is
    # actually under each marking instead of a human deciding. Anything under
    # "Markings" is the thing being CHECKED; everything else is what it may rest
    # on. See tools/maps/floorcheck.py for why this is a build gate.
    surfaces.record(name, mesh_name, x, y, z, yaw, sx,
                    is_marking=parent.startswith("Markings"))


# --- Kit placement -----------------------------------------------------------
#
# ⚠️ KIT PIECES DO NOT SHARE THE GENERATED KIT'S "ORIGIN AT THE BASE" HABIT.
# `env_*` meshes are authored from local y=0 up, so placing one at y=0 puts it on
# the floor. Kenney's are not consistent about it — measured, `kits/car/van`
# spans local y -0.300..1.150, so the same y=0 placement buries 30cm of it in the
# road. That is the floating-geometry bug with the sign flipped, and it would be
# just as invisible in a diff.
#
# So kit pieces are never placed by raw Y. `add_kit()` takes the height its BASE
# should sit at and works the rest out from the mesh's own bounds, the same way
# floorcheck.py does — one source of truth for "where is the bottom of this
# thing", read from the file rather than assumed.
#
# ⚠️ ONE SCALE PER KIT, NAMED. Art_Direction.md §0b's measured table: every kit
# is authored at a different native scale and none matches this project's
# 1 unit = 1 metre. Two pieces from one kit at different scales is the "assets
# suck" failure in its purest form, so the factor lives here, once, per kit.
CITY_SCALE = 5.0   # a City Kit house is 0.74-1.24 tall natively -- SHORTER than
                   # a Person. 5x puts it at 2-3 believable storeys.
CAR_SCALE = 1.75   # a van is 2.75 long / 1.45 tall natively; 1.75x reaches the
                   # ~4.8 length a real one has against a 1.6-unit Person.


def add_kit(parent, name, mesh_name, x, z, yaw=0.0, scale=1.0, base_y=0.0):
    """Places a kit piece with its BASE at `base_y`, scaled uniformly."""
    lo, hi = mesh_bounds(mesh_name)
    order.append((parent, name, mesh(mesh_name),
                  xform_uniform(x, base_y - lo[1] * scale, z, yaw, scale)))
    surfaces.record(name, mesh_name, x, base_y - lo[1] * scale, z, yaw, scale,
                    is_marking=False)


def xform_uniform(x, y, z, yaw, s):
    """A uniformly-scaled yaw transform.

    Distinct from `xform()` on purpose: that one scales ONLY the mesh's local X
    row, which is what a stretchable line decal needs and what a building must
    never get — a non-uniform scale on a house shears its roof.
    """
    c, sn = math.cos(yaw), math.sin(yaw)
    return (f"Transform3D({c * s:.5f}, 0, {-sn * s:.5f}, 0, {s:.5f}, 0, "
            f"{sn * s:.5f}, 0, {c * s:.5f}, {x:.4f}, {y:.4f}, {z:.4f})")


# --- Layer 1: the wall line the player actually touches, at x = +/-8 ---------
#
# 2026-07-28, checklist 7.4 — City Kit (Suburban) houses replace the generated
# corrugated panels. An eskinita is the gap BETWEEN people's houses, so the
# houses themselves are the wall.
#
# ⚠️ THE PLAYABLE WIDTH IS UNCHANGED AT x = +/-8, AND SO IS THE COLLISION.
# Arena scale is not touched in the same commit as arena art (Part 4's standing
# rule), and dressing still carries NO collision of its own — the one invisible
# Bounds box ring behind the wall line is still the only thing a player can hit.
# Every piece below is a visual instance and nothing more.
#
# Buildings are rotated a quarter turn so their long axis runs down the alley,
# and pushed out by half their depth so the FACE lands on the wall line rather
# than the centre. Seeded variety, never random: the type cycle is prime-ish
# against the bay count so the same house does not land opposite itself.
BUILDING_TYPES = ["a", "c", "e", "j", "b", "o", "d", "s", "i", "n", "l"]
## Depth of a rotated building, so its face lands on x = +/-W.
_bt_lo, _bt_hi = mesh_bounds("kits/city/building-type-a")
BUILDING_DEPTH = (_bt_hi[2] - _bt_lo[2]) * CITY_SCALE
BUILDING_BAY = 6.6          # spacing down the alley, ~ a building's own width
## Every Nth bay is left empty and gets a parked vehicle instead — a driveway.
## It is also what stops the wall line reading as one extruded ribbon.
DRIVEWAY_EVERY = 4

i = 0
z = -Z_END
while z <= Z_END:
    for side in (-1.0, 1.0):
        tag = "E" if side > 0 else "W"
        if (i + (0 if side > 0 else 2)) % DRIVEWAY_EVERY == 0:
            # A gap in the house line. The vehicle sits OUTSIDE the playable
            # width, so it never blocks an FPP Person's aim no matter how tall
            # it is -- see the height law on the clutter block below.
            car = ["kits/car/van", "kits/car/sedan", "kits/car/delivery",
                   "kits/car/taxi", "kits/car/truck"][i % 5]
            add_kit("Dressing/Layer1", f"Car_{i}_{tag}", car,
                    side * (W + 1.9), z, math.pi * 0.5 * side, CAR_SCALE)
        else:
            kind = BUILDING_TYPES[i % len(BUILDING_TYPES)]
            # +X row faces -X and vice versa, so front doors look into the alley.
            yaw = (math.pi * 0.5) if side > 0 else (-math.pi * 0.5)
            add_kit("Dressing/Layer1", f"L1_{i}_{tag}",
                    f"kits/city/building-type-{kind}",
                    side * (W + BUILDING_DEPTH * 0.5), z, yaw, CITY_SCALE)
    i += 1
    z += BUILDING_BAY

# --- Layer 2: a second row further out, for skyline depth --------------------
# Off-grid on purpose and deliberately NOT the same types as Layer 1 -- a second
# identical row reads as a mirror rather than as a neighbourhood.
for n, (x, zz, kind) in enumerate([
        (-19.0, -14.0, "t"), (-20.0, -3.0, "q"), (-18.5, 8.0, "u"),
        (-20.5, 17.0, "f"), (19.0, -15.0, "p"), (20.0, -4.0, "r"),
        (18.5, 7.0, "k"), (20.5, 16.0, "m")]):
    add_kit("Dressing/Layer2", f"L2_{n}", f"kits/city/building-type-{kind}",
            x, zz, 0.35 if n % 2 else -0.22, CITY_SCALE)

# --- Street trees and fences, between the houses and the kerb ----------------
for n, zz in enumerate([-15.5, -9.0, -2.5, 4.0, 10.5, 16.0]):
    for side in (-1.0, 1.0):
        piece = "kits/city/tree-large" if (n + (0 if side > 0 else 1)) % 2 else "kits/city/tree-small"
        add_kit("Dressing/Layer2", f"Tree_{n}_{'E' if side > 0 else 'W'}",
                piece, side * (W - 0.6), zz + (0.7 if side > 0 else -0.7),
                (n % 3) * 0.8, CITY_SCALE)

# --- Layer 3: overhead. Highest read-per-triangle in the kit. ---------------
for n, zz in enumerate([-14.0, -8.0, -2.0, 4.0, 10.0, 16.0]):
    add("Dressing/Layer3", f"Post_{n}", "post_electric", -W + 0.4, 0.0, zz,
        math.pi * 0.5)
for n, zz in enumerate([-11.0, -5.0, 1.0, 7.0, 13.0]):
    add("Dressing/Layer3", f"Sampay_{n}", "laundry_line", 0.0, 0.0, zz)

# --- Lane markings down the middle of the road ------------------------------
for n in range(-8, 9):
    add("Dressing/Road", f"Lane_{n + 8}", "road_tile_line", 0.0, 0.0, n * 2.0)

# --- Kerbs, both sides ------------------------------------------------------
for n in range(-8, 9):
    for side in (-1.0, 1.0):
        add("Dressing/Road", f"Kerb_{n + 8}_{'E' if side > 0 else 'W'}",
            "kerb_tile", side * (W - 1.2), 0.0, n * 2.0, math.pi * 0.5)

# --- Interior clutter. Every piece here is <= 1.0 tall so an FPP Person, whose
# --- eye sits at y=1.25, can aim over all of it. That is the height law.
CLUTTER = [
    ("crate_stack", -5.5, -9.0), ("crate_stack", 5.0, 8.5),
    ("tire", -6.2, 3.0), ("tire", 6.4, -6.0), ("tire", -6.0, 12.0),
    ("oil_drum", 6.0, 11.0), ("oil_drum", -6.4, -14.0),
    ("monobloc_chair", 5.6, -11.5), ("monobloc_chair", -5.2, 6.0),
    ("bollard", -6.8, -2.0), ("bollard", 6.8, 2.0),
]
for n, (piece, x, zz) in enumerate(CLUTTER):
    add("Dressing/Clutter", f"Clutter_{n}", piece, x, 0.0, zz,
        [0.4, -0.9, 1.7, 2.6, -2.1][n % 5])

# --- Tricycles. Waist-cover tier (1.25 tall) so they sit AGAINST the wall line,
# --- never loose in the alley where they would block an FPP Person's aim.
for n, (x, zz, yaw) in enumerate([
        (-6.6, -6.0, 0.15), (6.6, 9.5, math.pi + 0.2), (-6.5, 15.0, -0.1)]):
    add("Dressing/Clutter", f"Tricycle_{n}", "tricycle", x, 0.0, zz, yaw)

# --- Field markings. These serve BOTH round-win modes. ----------------------
# ⚠️⚠️⚠️ EVERY MARKING BELOW MUST SIT FLUSH ON WHATEVER IS UNDER IT, AND YOU NO
# LONGER HAVE TO GET THAT RIGHT BY HAND. `surfaces.verify()` at the bottom of
# this file samples the real footprint of every marking against the real height
# of every piece beneath it and ABORTS THE BUILD if any of them floats. Place a
# marking wrong and you get an error naming the node and the gap in millimetres,
# not a scene that looks fine until someone plays it.
#
# What you still need to know, because it is what makes the mistake so easy:
# `_box()`'s y0/y1 in env_kit.gd are LOCAL coordinates starting at the mesh's
# own origin (y0 is 0.0), so a marking's placement Y is its LITERAL UNDERSIDE,
# not its centre. Placing one at 0.07 with bare road beneath puts its underside
# 7cm in the air. Adding clearance "to be safe" is the bug, not the fix.
#
# Three sessions were spent retuning a single constant here (0.07 -> 0.015 ->
# 0.001) and the lines kept floating, because the real failure was never a
# constant: `throwing_line_decal` is 8m wide and crosses a 2m raised lane strip,
# so it spans TWO ground heights and no single Y was ever going to be flush for
# it. floorcheck.py reports that case separately — "SPANS n surface heights" —
# because the fix is to split the piece, not to nudge the number.
ROAD_Y = 0.0         # bare asphalt: the Floor box's own top surface


def add_line(name, mesh_name, x, z, yaw=0.0, sx=1.0):
    """A straight line marking, SPLIT AUTOMATICALLY wherever the ground steps.

    ⚠️ USE THIS FOR EVERY LINE MARKING. Placing one with plain `add()` means
    choosing a Y by hand, and that is the decision that has produced a floating
    line in three separate playtests.

    Every line here crosses the 6.2cm raised `road_tile_line` strip running down
    the middle of the road, so each one genuinely sits on two different heights
    and no single Y is flush for it. Rather than making eleven judgement calls,
    this walks the line's own length, asks `surfaces` how high the ground
    actually is at each step, and emits one sub-piece per run of constant
    height — each placed at exactly that height. `sx` scales the decal's own
    length axis, so no new mesh is needed for the shorter runs.

    A line that never crosses a step comes out as a single piece with the same
    name it would have had, so this costs nothing where it is not needed.
    """
    lo, hi = mesh_bounds(mesh_name)
    span = hi[0] - lo[0]
    length = span * sx
    # Finer than floorcheck's own EDGE_INSET (0.02), so the midpoint boundary
    # below is always inside the inset and a correctly-split line verifies.
    steps = max(2, int(length / 0.01) + 1)
    c, s = math.cos(yaw), math.sin(yaw)
    # Sample the ground under the centreline, from one end to the other.
    samples = []
    for i in range(steps):
        t = -0.5 + i / (steps - 1.0)          # -0.5 .. +0.5 along the line
        d = t * length
        samples.append((t, round(surfaces.height_at(x + d * c, z - d * s), 6)))
    # Collapse into contiguous runs of equal height.
    # ⚠️ The boundary goes at the MIDPOINT between the two differing samples,
    # not at the first sample of the new height. Ending a run on a sample that
    # already reads the NEW height pushes that run past the step by one sample,
    # so the piece overhangs the edge it was split at and floats there — the
    # original bug, reintroduced by the fix for it. Caught by floorcheck.
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
        # embed_y, never `h` — a marking sits INSIDE the ground, not on it.
        add("Markings", name + suffix, mesh_name,
            x + mid * length * c, embed_y(h, mesh_name), z - mid * length * s,
            yaw, run_len / span)


# The base circle sits entirely on the raised strip (it is 1.4 across, the strip
# is 2.0), so it is a single piece at the strip's own top. It was at 0.070
# against a 0.062 top — 8mm of float, the "still a couple of thinsg floating"
# report. Taken from the measured mesh now, not from a round number.
add("Markings", "BaseCircle", "base_circle_decal", 0.0,
    embed_y(surfaces.height_at(0.0, 0.0), "base_circle_decal"), 0.0)

add_line("ThrowingLineNorth", "throwing_line_decal", 0.0, -6.0)
add_line("ThrowingLineSouth", "throwing_line_decal", 0.0, 6.0)
add_line("TeamSideNorth", "team_side_decal", 0.0, -13.0)
add_line("TeamSideSouth", "team_side_decal", 0.0, 13.0)
# Narrowed from its native 3.76 width so it stops clear of the kerb at x=6.63
# rather than running underneath it — the same class of fault as the floaters
# (a decal resting on something it was never meant to touch), caught by the
# same check.
add("Markings", "JeepneyLane", "jeepney_lane_decal", 5.2,
    embed_y(ROAD_Y, "jeepney_lane_decal"), 0.0, 0.0, 0.6)

# --- Confinement-radius SQUARE. 2026-07-28: the Can/Taya's actual restricted
# --- play area (CharacterBase.CONFINEMENT_RADIUS) was invisible on the
# --- ground -- the only markers were the tiny base circle and the distant
# --- throwing line, with nothing showing where the confinement edge itself
# --- sits. This is the mark that matters for "outplays" (juking a defender
# --- along the actual edge of their box), not a boundary around the whole
# --- map. A SQUARE, not a circle/ring (tried first, user feedback: "the
# --- circle you made was ugly ... can we just use a square" -- a real
# --- tumbang preso chalk box is a straight-edged rectangle, not a drawn
# --- circle). Built by tiling team_side_decal's straight line along all
# --- four sides, scaled per-segment via xform()'s sx, rather than authoring
# --- a new mesh in env_kit.gd, which stays Design-owned.
# --- CONFINEMENT_BOX_RADIUS mirrors CharacterBase.CONFINEMENT_RADIUS -- keep
# --- the two in sync if either is retuned again. Spawn layout inside this
# --- box is unchanged: Taya (Spawn1) is inside it, the Can (Spawn0) sits on
# --- BaseCircle at its centre, and the Attacker (Spawn2) spawns OUTSIDE it
# --- at ThrowingLineSouth's 6-unit line -- see main.gd's _role_slot doc.
CONFINEMENT_BOX_RADIUS = 5.0
BOX_SEG = 6.0  # team_side_decal's native length
_box_segs_per_side = math.ceil((2 * CONFINEMENT_BOX_RADIUS) / BOX_SEG)
_box_scale = ((2 * CONFINEMENT_BOX_RADIUS) / _box_segs_per_side) / BOX_SEG
for i in range(_box_segs_per_side):
    along = -CONFINEMENT_BOX_RADIUS + BOX_SEG * _box_scale * (i + 0.5)
    add_line(f"ConfinementBoxNorth_{i}", "team_side_decal",
             along, -CONFINEMENT_BOX_RADIUS, 0.0, _box_scale)
    add_line(f"ConfinementBoxSouth_{i}", "team_side_decal",
             along, CONFINEMENT_BOX_RADIUS, 0.0, _box_scale)
    add_line(f"ConfinementBoxEast_{i}", "team_side_decal",
             CONFINEMENT_BOX_RADIUS, along, math.pi * 0.5, _box_scale)
    add_line(f"ConfinementBoxWest_{i}", "team_side_decal",
             -CONFINEMENT_BOX_RADIUS, along, math.pi * 0.5, _box_scale)

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

SUBS = '''[sub_resource type="BoxShape3D" id="Shape_floor"]
size = Vector3(40, 1, 40)

[sub_resource type="StandardMaterial3D" id="Mat_floor"]
albedo_color = Color(0.29020, 0.30588, 0.34118, 1)
roughness = 1.0

[sub_resource type="BoxMesh" id="Mesh_floor"]
material = SubResource("Mat_floor")
size = Vector3(40, 1, 40)

[sub_resource type="BoxShape3D" id="Shape_wall_z"]
size = Vector3(1, 12, 40)

[sub_resource type="BoxShape3D" id="Shape_wall_x"]
size = Vector3(20, 12, 1)

[sub_resource type="BoxShape3D" id="Shape_killplane"]
size = Vector3(90, 4, 90)

[sub_resource type="BoxShape3D" id="Shape_hazard"]
size = Vector3(3.6, 3, 11)

[sub_resource type="ProceduralSkyMaterial" id="Sky_mat"]
sky_top_color = Color(0.286, 0.565, 0.851, 1)
sky_horizon_color = Color(0.91, 0.784, 0.604, 1)
sky_curve = 0.18
ground_bottom_color = Color(0.227, 0.243, 0.278, 1)
ground_horizon_color = Color(0.91, 0.784, 0.604, 1)

[sub_resource type="Sky" id="Sky_res"]
sky_material = SubResource("Sky_mat")

[sub_resource type="Environment" id="Env_eskinita"]
background_mode = 2
sky = SubResource("Sky_res")
ambient_light_source = 2
ambient_light_color = Color(0.416, 0.514, 0.671, 1)
ambient_light_energy = 0.55
tonemap_mode = 0
tonemap_white = 1.2
ssao_enabled = true
ssao_radius = 1.1
ssao_intensity = 2.6
ssao_power = 1.6
ssao_detail = 0.4
fog_enabled = true
fog_light_color = Color(0.855, 0.784, 0.667, 1)
fog_light_energy = 1.0
fog_sun_scatter = 0.15
fog_density = 0.0048
fog_sky_affect = 0.55
fog_aerial_perspective = 0.35
adjustment_enabled = true
adjustment_brightness = 1.0
adjustment_contrast = 1.08
adjustment_saturation = 1.2
'''

# ⚠️ NO `#` COMMENTS INSIDE THE EMITTED .tscn. Godot's scene format does not use
# `#` for comments, so a stray one silently breaks the NEXT node's declaration —
# it cost a debugging round when four `#` lines above [node name="SpawnPoints"]
# made every Spawn marker fail to instantiate with "parent path has vanished".
# Explain things HERE, in the generator, where they also survive an editor save.
#
# Spawn0-3 are ROLE slots (Can / Taya / Attacker / Tsinelas), not team slots —
# main.gd's _role_slot() picks which one each unit occupies THIS round, and it
# changes every round since team_a_is_can flips. Centred on this map's own
# base_circle_decal (0,0,0) and its south throwing_line_decal (0,0,6) below,
# instead of the old scheme that put both of one team's units at one end of
# the alley and both of the other team's at the far end regardless of which
# side was actually defending. Spawn0 (Can) sits ON the circle; Spawn1 (Taya)
# stands a couple of units BEHIND it at negative Z (2026-07-28, user
# feedback: "the person in same team is behind that can") -- the opposite
# side from Spawn2, so the Taya is watching past the Can toward the
# attacker rather than standing off to the attacker's own side; Spawn2
# (Attacker) is AT the throwing line Art_Direction.md §9 derived the 6.0
# distance for, facing back toward the Can/Taya (-Z, "the person with
# tsinelas should be staring at them"); Spawn3 (Tsinelas) starts beside the
# Attacker -- main.gd auto-hands it to them at round start, so it is rarely
# loose there for more than an instant.
HEAD = '''[node name="Eskinita" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env_eskinita")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.8, -0.4, 0.45, 0, 0.75, 0.66, -0.6, -0.53, 0.6, 0, 8, 0)
light_color = Color(1, 0.941, 0.847, 1)
light_energy = 1.25
light_angular_distance = 1.2
shadow_enabled = true
shadow_bias = 0.03
shadow_normal_bias = 1.5
directional_shadow_max_distance = 60.0

[node name="Floor" type="StaticBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="Floor"]
shape = SubResource("Shape_floor")

[node name="MeshInstance3D" type="MeshInstance3D" parent="Floor"]
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

[node name="SpawnPoints" type="Node3D" parent="."]

[node name="Spawn0" type="Marker3D" parent="SpawnPoints"]
transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0.0, 0.17, 0.0)

[node name="Spawn1" type="Marker3D" parent="SpawnPoints"]
transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 2.2, 0.8, -1.5)

[node name="Spawn2" type="Marker3D" parent="SpawnPoints"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.0, 0.8, 6.0)

[node name="Spawn3" type="Marker3D" parent="SpawnPoints"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.3, 0.16, 6.3)

[node name="Dressing" type="Node3D" parent="."]

[node name="Layer1" type="Node3D" parent="Dressing"]

[node name="Layer2" type="Node3D" parent="Dressing"]

[node name="Layer3" type="Node3D" parent="Dressing"]

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
        # rendered as empty road on the first run of checklist 7.4: the nodes
        # were all present, the transforms were all correct, and nothing drew.
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

# ⚠️ BEFORE WRITING, NOT AFTER. A floating marking must not reach the scene file
# at all — half the cost of this bug every previous time was that a broken scene
# got committed, imported and played before anyone looked at it.
n_marks = surfaces.verify()

with open("scenes/maps/Eskinita.tscn", "w", encoding="utf-8", newline="\n") as f:
    f.write(out)

print(f"wrote scenes/maps/Eskinita.tscn")
print(f"  markings      : {n_marks} verified embedded")
print(f"  ext_resources : {len(ext_lines)}")
print(f"  sub_resources : {n_sub}")
print(f"  load_steps    : {load_steps}")
print(f"  mesh instances: {len(order)}")
