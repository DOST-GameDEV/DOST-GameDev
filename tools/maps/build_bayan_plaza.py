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
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from floorcheck import Surfaces, mesh_bounds  # noqa: E402

surfaces = Surfaces()

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


def add_kit(parent, name, mesh_name, x, z, yaw=0.0, scale=1.0, base_y=0.0):
    """Places a kit piece with its BASE at `base_y`. Kit meshes do not reliably
    put their origin at their base — see build_eskinita.py's add_kit."""
    lo, _hi = mesh_bounds(mesh_name)
    order.append((parent, name, mesh(mesh_name),
                  xform_uniform(x, base_y - lo[1] * scale, z, yaw, scale)))
    surfaces.record(name, mesh_name, x, base_y - lo[1] * scale, z, yaw, scale,
                    is_marking=False)


def xform(x, y, z, yaw=0.0):
    c, s = math.cos(yaw), math.sin(yaw)
    return (f"Transform3D({c:.5f}, 0, {-s:.5f}, 0, 1, 0, {s:.5f}, 0, {c:.5f}, "
            f"{x:.4f}, {y:.4f}, {z:.4f})")


def add(parent, name, mesh_name, x, y, z, yaw=0.0):
    order.append((parent, name, mesh(mesh_name), xform(x, y, z, yaw)))
    # See build_eskinita.py's add() and tools/maps/floorcheck.py — every piece
    # is recorded so the markings can be checked against real ground heights
    # instead of a hand-picked constant.
    surfaces.record(name, mesh_name, x, y, z, yaw,
                    is_marking=parent.startswith("Markings"))


# --- The slab. A plaza is a hard floor; the dirt apron is the big floor box. --
n = 0
i = int(SLAB / CELL)
for gx in range(-i, i):
    for gz in range(-i, i):
        add("Dressing/Slab", f"Tile_{n}", "plaza_tile",
            gx * CELL + CELL / 2, 0.0, gz * CELL + CELL / 2)
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
add("Dressing/Landmarks", "Church", "church_facade", 0.0, 0.0, -BOUND - 1.6)
add("Dressing/Landmarks", "Flagpole", "flagpole", -4.5, 0.0, -BOUND + 1.5)
# MANDATORY — it IS the Philippine plaza. Two, facing each other, because a
# barangay court has a ring at each end and it doubles as the map's long axis.
add("Dressing/Landmarks", "RingNorth", "basketball_ring", 0.0, 0.0, -SLAB + 0.6)
add("Dressing/Landmarks", "RingSouth", "basketball_ring", 0.0, 0.0, SLAB - 0.6,
    math.pi)
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

# --- Field markings. Identical grammar to Eskinita on purpose: a player must
# --- not have to relearn what a base circle looks like when the map changes.
# ⚠️ MARK_Y IS GONE — the height comes from the geometry now, not from a
# constant somebody has to keep true. Unlike Eskinita, this map's markings all
# sit on the uniform plaza slab, so one height IS correct here; it is asked for
# rather than assumed so it cannot drift if the slab tile ever changes.
# floorcheck aborts the build if any of these floats. See build_eskinita.py.
SLAB_TOP = surfaces.height_at(0.0, 0.0)
add("Markings", "BaseCircle", "base_circle_decal", 0.0, SLAB_TOP, 0.0)
add("Markings", "ThrowingLineNorth", "throwing_line_decal", 0.0, SLAB_TOP, -6.0)
add("Markings", "ThrowingLineSouth", "throwing_line_decal", 0.0, SLAB_TOP, 6.0)
add("Markings", "TeamSideNorth", "team_side_decal", 0.0, SLAB_TOP, -9.5)
add("Markings", "TeamSideSouth", "team_side_decal", 0.0, SLAB_TOP, 9.5)

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
size = Vector3(60, 1, 60)

[sub_resource type="StandardMaterial3D" id="Mat_floor"]
albedo_color = Color(0.76078, 0.65882, 0.47059, 1)
roughness = 1.0

[sub_resource type="BoxMesh" id="Mesh_floor"]
material = SubResource("Mat_floor")
size = Vector3(60, 1, 60)

[sub_resource type="BoxShape3D" id="Shape_wall_z"]
size = Vector3(1, 12, 26)

[sub_resource type="BoxShape3D" id="Shape_wall_x"]
size = Vector3(26, 12, 1)

[sub_resource type="BoxShape3D" id="Shape_killplane"]
size = Vector3(90, 4, 90)

[sub_resource type="BoxShape3D" id="Shape_hazard"]
size = Vector3(5, 3, 5)

[sub_resource type="ProceduralSkyMaterial" id="Sky_mat"]
sky_top_color = Color(0.29020, 0.56078, 0.81569, 1)
sky_horizon_color = Color(0.81176, 0.89412, 0.96078, 1)
sky_curve = 0.18
ground_bottom_color = Color(0.76078, 0.65882, 0.47059, 1)
ground_horizon_color = Color(0.81176, 0.89412, 0.96078, 1)

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
fog_density = 0.004
fog_sky_affect = 0.5
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
HEAD = '''[node name="BayanPlaza" type="Node3D"]

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
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="Floor"]
shape = SubResource("Shape_floor")

[node name="MeshInstance3D" type="MeshInstance3D" parent="Floor"]
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

[node name="Slab" type="Node3D" parent="Dressing"]

[node name="TreesNear" type="Node3D" parent="Dressing"]

[node name="TreesFar" type="Node3D" parent="Dressing"]

[node name="Ground" type="Node3D" parent="Dressing"]

[node name="Landmarks" type="Node3D" parent="Dressing"]

[node name="Furniture" type="Node3D" parent="Dressing"]

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
print(f"  markings      : {n_marks} verified flush")
print(f"  ext_resources : {len(ext_lines)}")
print(f"  load_steps    : {load_steps}")
print(f"  mesh instances: {len(order)}")
