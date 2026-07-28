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

W = 8.0          # half-width of the playable alley
Z_END = 17.0     # half-length
CELL = 2.0

meshes, ext, order = {}, [], []


def mesh(name):
    if name not in meshes:
        meshes[name] = str(len(meshes) + 1)
        ext.append((meshes[name], f"res://assets/models/env_{name}.obj"))
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


# --- Layer 1: the wall line the player actually touches, at x = +/-8 ---------
# Seeded, never random: the pattern repeats on a 5-bay cycle and every third bay
# steps back one cell. A flush wall of identical panels reads as a corridor in a
# level editor, which is the failure this ring exists to avoid.
PATTERN = ["wall_corrugated", "wall_corrugated_leaning", "wall_plain",
           "wall_corrugated", "sari_sari_store", "wall_corrugated",
           "wall_plain", "wall_corrugated_leaning"]
i = 0
z = -Z_END
while z <= Z_END:
    for side in (-1.0, 1.0):
        piece = PATTERN[i % len(PATTERN)]
        step_back = 0.5 if (i % 3 == 0) else 0.0  # a jog, not a hole
        # +X wall faces -X (yaw pi), -X wall faces +X (yaw 0). Pieces are
        # authored facing +Z, so add a quarter turn to stand them along Z.
        yaw = (math.pi * 0.5) if side > 0 else (-math.pi * 0.5)
        add("Dressing/Layer1", f"L1_{i}_{'E' if side > 0 else 'W'}",
            piece, side * (W + step_back), 0.0, z, yaw)
    i += 1
    z += CELL

# --- Layer 2: masses standing behind the wall line, off-grid on purpose ------
for n, (x, zz, kind) in enumerate([
        (-13.5, -12.0, "a"), (-14.5, -4.0, "c"), (-13.0, 5.0, "d"),
        (-15.0, 13.0, "b"), (13.5, -13.0, "b"), (14.0, -3.0, "a"),
        (13.0, 6.5, "c"), (15.0, 14.0, "d")]):
    add("Dressing/Layer2", f"L2_{n}", f"building_block_{kind}",
        x, 0.0, zz, 0.35 if n % 2 else -0.22)

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
# y = MARK_Y, not 0. Found by rendering: `road_tile_line` is a whole 2x2 asphalt
# tile 0.06 tall WITH a painted dash on top, and a strip of them runs down the
# centre of this road. At y=0 the base circle's 0.03-tall ring was buried inside
# those tiles for |x| < 1, so it rendered as two stray yellow arcs with its near
# and far thirds missing. Every floor marking now sits above the tile layer.
MARK_Y = 0.07
add("Markings", "BaseCircle", "base_circle_decal", 0.0, MARK_Y, 0.0)
add("Markings", "ThrowingLineNorth", "throwing_line_decal", 0.0, MARK_Y, -6.0)
add("Markings", "ThrowingLineSouth", "throwing_line_decal", 0.0, MARK_Y, 6.0)
add("Markings", "TeamSideNorth", "team_side_decal", 0.0, MARK_Y, -13.0)
add("Markings", "TeamSideSouth", "team_side_decal", 0.0, MARK_Y, 13.0)
add("Markings", "JeepneyLane", "jeepney_lane_decal", 5.4, MARK_Y, 0.0)

# --- Confinement-radius ring. 2026-07-28: the Can/Taya's actual restricted
# --- play area (CharacterBase.CONFINEMENT_RADIUS) was invisible on the
# --- ground -- the only markers were the tiny base circle and the distant
# --- throwing line, with nothing showing where the confinement edge itself
# --- sits. This is the mark that matters for "outplays" (juking a defender
# --- along the actual edge of their box), not a boundary around the whole
# --- map. Built the same way the (reverted) map-perimeter border was: tiling
# --- team_side_decal's straight line, scaled per-segment via xform()'s new
# --- sx to approximate a circle rather than authoring a new ring mesh in
# --- env_kit.gd, which stays Design-owned.
# --- CONFINEMENT_RING_RADIUS mirrors CharacterBase.CONFINEMENT_RADIUS --
# --- keep the two in sync if either is retuned again.
CONFINEMENT_RING_RADIUS = 5.0
N_RING = 12
_ring_chord = 2 * CONFINEMENT_RING_RADIUS * math.sin(math.pi / N_RING)
_ring_scale = _ring_chord / 6.0  # team_side_decal's native length
for i in range(N_RING):
    theta = i * (2 * math.pi / N_RING)
    rx = CONFINEMENT_RING_RADIUS * math.cos(theta)
    rz = CONFINEMENT_RING_RADIUS * math.sin(theta)
    add("Markings", f"ConfinementRing_{i}", "team_side_decal", rx, MARK_Y, rz,
        theta + math.pi / 2.0, _ring_scale)

# =============================================================================

ext_lines = [f'[ext_resource type="Mesh" path="{p}" id="{i}"]' for i, p in ext]
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
# stands a couple of units off it, facing the attack line; Spawn2 (Attacker)
# is AT the throwing line Art_Direction.md §9 derived the 6.0 distance for;
# Spawn3 (Tsinelas) starts beside the Attacker — main.gd auto-hands it to them
# at round start, so it is rarely loose there for more than an instant.
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
transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 2.2, 0.8, 1.5)

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

body = []
for parent, name, mid, tf in order:
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

with open("scenes/maps/Eskinita.tscn", "w", encoding="utf-8", newline="\n") as f:
    f.write(out)

print(f"wrote scenes/maps/Eskinita.tscn")
print(f"  ext_resources : {len(ext_lines)}")
print(f"  sub_resources : {n_sub}")
print(f"  load_steps    : {load_steps}")
print(f"  mesh instances: {len(order)}")
