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

SLAB = 10.0      # half-width of the hard plaza slab
BOUND = 12.5     # half-width of the playable square (collision sits here)
CELL = 2.0
MARK_Y = 0.07    # above the 0.06-tall tiles — see build_eskinita.py

meshes, ext, order = {}, [], []


def mesh(name):
    if name not in meshes:
        meshes[name] = str(len(meshes) + 1)
        ext.append((meshes[name], f"res://assets/models/env_{name}.obj"))
    return meshes[name]


def xform(x, y, z, yaw=0.0):
    c, s = math.cos(yaw), math.sin(yaw)
    return (f"Transform3D({c:.5f}, 0, {-s:.5f}, 0, 1, 0, {s:.5f}, 0, {c:.5f}, "
            f"{x:.4f}, {y:.4f}, {z:.4f})")


def add(parent, name, mesh_name, x, y, z, yaw=0.0):
    order.append((parent, name, mesh(mesh_name), xform(x, y, z, yaw)))


# --- The slab. A plaza is a hard floor; the dirt apron is the big floor box. --
n = 0
i = int(SLAB / CELL)
for gx in range(-i, i):
    for gz in range(-i, i):
        add("Dressing/Slab", f"Tile_{n}", "plaza_tile",
            gx * CELL + CELL / 2, 0.0, gz * CELL + CELL / 2)
        n += 1

# --- The tree ring. TWO layers, and the second is a DIFFERENT VALUE, not just
# --- a second row — the board rings Province with depth and depth here is
# --- colour. Seeded spacing, never random.
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
        add("Dressing/TreesNear", f"Tree_{n}", "tree", x, 0.0, z, (k % 4) * 0.7)
        n += 1
        # The layer behind, further out and one value darker.
        add("Dressing/TreesFar", f"TreeFar_{n}", "tree_far",
            x * 1.28 - j * 0.4, 0.0, z * 1.28 + j * 0.4, (k % 3) * 0.9)
        n += 1

# --- The landmark. One church, on the long axis, so a player always knows
# --- which way they are facing. Worth more than any three clutter pieces.
add("Dressing/Landmarks", "Church", "church_facade", 0.0, 0.0, -BOUND - 1.6)
add("Dressing/Landmarks", "Flagpole", "flagpole", -4.5, 0.0, -BOUND + 1.5)
# MANDATORY — it IS the Philippine plaza. Two, facing each other, because a
# barangay court has a ring at each end and it doubles as the map's long axis.
add("Dressing/Landmarks", "RingNorth", "basketball_ring", 0.0, 0.0, -SLAB + 0.6)
add("Dressing/Landmarks", "RingSouth", "basketball_ring", 0.0, 0.0, SLAB - 0.6,
    math.pi)

# --- Edge furniture. All of it interior-tier (<= 1.1) so an FPP Person, whose
# --- eye is at 1.25, can aim over every piece of it.
n = 0
for k in range(6):
    t = -7.5 + k * 3.0
    for sx in (-1, 1):
        add("Dressing/Furniture", f"Bench_{n}", "bench",
            sx * (SLAB + 0.9), 0.0, t, math.pi / 2)
        n += 1
for k, (x, z) in enumerate([(-SLAB - 0.9, -10.5), (SLAB + 0.9, -10.5),
                            (-SLAB - 0.9, 10.5), (SLAB + 0.9, 10.5)]):
    add("Dressing/Furniture", f"Planter_{k}", "planter", x, 0.0, z)
for k, (x, z) in enumerate([(-6.0, -6.0), (6.0, 6.0), (-6.5, 7.0), (7.0, -6.5)]):
    add("Dressing/Furniture", f"Chair_{k}", "monobloc_chair", x, 0.0, z,
        [0.5, 2.1, -1.2, 3.0][k])
for k, (x, z) in enumerate([(-8.5, 2.0), (8.5, -2.0)]):
    add("Dressing/Furniture", f"Tire_{k}", "tire", x, 0.0, z)

# --- Field markings. Identical grammar to Eskinita on purpose: a player must
# --- not have to relearn what a base circle looks like when the map changes.
add("Markings", "BaseCircle", "base_circle_decal", 0.0, MARK_Y, 0.0)
add("Markings", "ThrowingLineNorth", "throwing_line_decal", 0.0, MARK_Y, -6.0)
add("Markings", "ThrowingLineSouth", "throwing_line_decal", 0.0, MARK_Y, 6.0)
add("Markings", "TeamSideNorth", "team_side_decal", 0.0, MARK_Y, -9.5)
add("Markings", "TeamSideSouth", "team_side_decal", 0.0, MARK_Y, 9.5)

# =============================================================================

ext_lines = [f'[ext_resource type="Mesh" path="{p}" id="{i}"]' for i, p in ext]
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

[node name="Landmarks" type="Node3D" parent="Dressing"]

[node name="Furniture" type="Node3D" parent="Dressing"]

[node name="Markings" type="Node3D" parent="."]
'''

body = []
for parent, name, mid, tf in order:
    body.append(f'\n[node name="{name}" type="MeshInstance3D" parent="{parent}"]')
    body.append(f'transform = {tf}')
    body.append(f'mesh = ExtResource("{mid}")')

n_sub = SUBS.count("[sub_resource")
load_steps = len(ext_lines) + n_sub + 1

out = (f'[gd_scene load_steps={load_steps} format=3]\n\n'
       + "\n".join(ext_lines) + "\n\n" + SUBS + "\n" + HEAD + "\n".join(body) + "\n")

with open("scenes/maps/BayanPlaza.tscn", "w", encoding="utf-8", newline="\n") as f:
    f.write(out)

print("wrote scenes/maps/BayanPlaza.tscn")
print(f"  ext_resources : {len(ext_lines)}")
print(f"  load_steps    : {load_steps}")
print(f"  mesh instances: {len(order)}")
