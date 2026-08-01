"""Reads a binary glTF (.glb) without Blender: reports its cost, and extracts or
replaces its embedded textures.

    python tools/models/glb_tool.py info    <file.glb>
    python tools/models/glb_tool.py extract <file.glb> <out_dir>
    python tools/models/glb_tool.py replace <file.glb> <index> <png> <out.glb>

WHY THIS EXISTS. `docs/Agent_Prompts.md` § 5 rules Blender out of the pipeline
entirely — not the app, not the MCP tools, not a .glb round trip — and the
recorded reason (§ WHY BLENDER WAS DROPPED) is that the glTF round trip ships
custom split normals that smooth-shade every flat face, which is the exact
"bumpy and unnatural" look the human rejected.

A downloaded CC-BY model still needs two things done to it: its poly cost has to
be KNOWN before it ships, and its texture has to be editable (the Sike is a Nike
parody and the wordmark has to change). Both are file surgery, not modelling, so
both can be done on the container directly. Nothing here touches geometry, so no
round trip happens and no normal is ever recomputed.

A .glb is a 12-byte header followed by chunks: one JSON chunk describing the
scene, then one BIN chunk holding the buffers. Images are `bufferView` slices of
that BIN chunk. Replacing one means rewriting its slice and fixing up every
byteOffset after it, which is what `replace` does.
"""

import json
import os
import struct
import sys

HEADER = struct.Struct("<III")
CHUNK = struct.Struct("<II")
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def read_glb(path):
    with open(path, "rb") as fh:
        data = fh.read()
    magic, version, _length = HEADER.unpack_from(data, 0)
    if magic != 0x46546C67:
        raise SystemExit("%s is not a .glb (bad magic)" % path)
    if version != 2:
        raise SystemExit("%s is glTF version %d; only 2 is handled" % (path, version))
    offset = HEADER.size
    gltf, binary = None, b""
    while offset < len(data):
        clen, ctype = CHUNK.unpack_from(data, offset)
        body = data[offset + CHUNK.size: offset + CHUNK.size + clen]
        if ctype == JSON_CHUNK:
            gltf = json.loads(body.decode("utf-8"))
        elif ctype == BIN_CHUNK:
            binary = body
        offset += CHUNK.size + clen
    if gltf is None:
        raise SystemExit("%s has no JSON chunk" % path)
    return gltf, binary


def write_glb(path, gltf, binary):
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)          # chunks are 4-byte aligned
    binary += b"\x00" * ((4 - len(binary) % 4) % 4)
    total = HEADER.size + CHUNK.size * 2 + len(js) + len(binary)
    with open(path, "wb") as fh:
        fh.write(HEADER.pack(0x46546C67, 2, total))
        fh.write(CHUNK.pack(len(js), JSON_CHUNK))
        fh.write(js)
        fh.write(CHUNK.pack(len(binary), BIN_CHUNK))
        fh.write(binary)


def triangle_count(gltf):
    """Sum over every primitive actually referenced by a mesh.

    ⚠️ COUNTED FROM THE ACCESSORS, NOT TRUSTED FROM THE PAGE. The Sike model is
    published as "Low Poly Nike Sandals" and Sketchfab's own counter says 131.3k
    triangles, which is 260x this game's cans. A prop that heavy spins on two
    axes every frame, up to four at once, so the real number decides whether it
    can ship at all.
    """
    total = 0
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            if prim.get("mode", 4) != 4:          # 4 == TRIANGLES
                continue
            if "indices" in prim:
                total += gltf["accessors"][prim["indices"]]["count"] // 3
            else:
                pos = prim["attributes"].get("POSITION")
                if pos is not None:
                    total += gltf["accessors"][pos]["count"] // 3
    return total


def image_slices(gltf, binary):
    out = []
    for i, image in enumerate(gltf.get("images", [])):
        if "bufferView" not in image:
            continue
        view = gltf["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        end = start + view["byteLength"]
        ext = "png" if image.get("mimeType") == "image/png" else "jpg"
        out.append((i, image.get("name", "image%d" % i), ext, start, end,
                    binary[start:end]))
    return out


def cmd_info(path):
    gltf, binary = read_glb(path)
    print("%s" % os.path.basename(path))
    print("  triangles : %d" % triangle_count(gltf))
    print("  meshes    : %d" % len(gltf.get("meshes", [])))
    print("  materials : %d" % len(gltf.get("materials", [])))
    print("  bin bytes : %d" % len(binary))
    albedo = base_color_image(gltf)
    for i, name, ext, start, end, blob in image_slices(gltf, binary):
        tag = "  <-- BASE COLOR" if i == albedo else ""
        print("  image %d   : %-24s %s  %d bytes%s" % (i, name, ext, end - start, tag))


def cmd_extract(path, out_dir):
    gltf, binary = read_glb(path)
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)
    for i, name, ext, _s, _e, blob in image_slices(gltf, binary):
        safe = "".join(c if c.isalnum() or c in "-_" else "_" for c in name)
        dest = os.path.join(out_dir, "%d_%s.%s" % (i, safe, ext))
        with open(dest, "wb") as fh:
            fh.write(blob)
        print("wrote", dest, len(blob), "bytes")


def cmd_replace(path, index, png_path, out_path):
    """Swaps one embedded image and repairs every byteOffset after it.

    ⚠️ THE FIX-UP IS THE WHOLE JOB. Every other bufferView into the BIN chunk —
    all the vertex and index data — is addressed by absolute byte offset, so a
    replacement image of a different length silently shifts the geometry out from
    under its own accessors. The model still loads and renders as noise.
    """
    gltf, binary = read_glb(path)
    with open(png_path, "rb") as fh:
        blob = fh.read()
    image = gltf["images"][index]
    view_index = image["bufferView"]
    view = gltf["bufferViews"][view_index]
    start = view.get("byteOffset", 0)
    old_len = view["byteLength"]
    padded = blob + b"\x00" * ((4 - len(blob) % 4) % 4)
    delta = len(padded) - old_len

    binary = binary[:start] + padded + binary[start + old_len:]
    view["byteLength"] = len(blob)
    image["mimeType"] = "image/png"
    for other in gltf["bufferViews"]:
        if other is view:
            continue
        if other.get("byteOffset", 0) > start:
            other["byteOffset"] = other.get("byteOffset", 0) + delta
    for buf in gltf.get("buffers", []):
        if "byteLength" in buf:
            buf["byteLength"] = len(binary) + ((4 - len(binary) % 4) % 4)
    write_glb(out_path, gltf, binary)
    print("wrote %s (image %d: %d -> %d bytes)" % (out_path, index, old_len, len(blob)))


# -----------------------------------------------------------------------------
# .glb -> .obj, so a downloaded model joins the pipeline the rest of the art uses
# -----------------------------------------------------------------------------
#
# ⚠️ WHY CONVERT AT ALL, RATHER THAN INSTANCING THE .glb DIRECTLY.
# Godot imports a .glb happily, so this is not about loading. It is about the
# THREE things every other prop in this game gets for free and a raw .glb
# instance does not:
#
#   1. `lata.gd`/`slipper.gd`'s `_apply_model()` swaps a `Mesh` onto one
#      MeshInstance3D from the roster entry's `model` path. A .glb loads as a
#      PackedScene, not a Mesh, so a skin pick cannot swap to one.
#   2. `Slipper.REST_HEIGHT` and the two-axis spin both assume the origin is on
#      the mesh's own volume centroid. These models arrive scaled in tens of
#      units and offset from their own origin by more than their own size — the
#      Pantulog's bounding box starts at (-18.4, -16.7, -3.7).
#   3. One material with a flat `Kd` and a `map_Kd`, which is what the toon pass
#      and the skin tint both expect.
#
# Converting fixes all three at once and costs nothing: this reads the vertex
# data and writes it back out unchanged in a different container. NO GEOMETRY IS
# EDITED — no decimation, no re-normalling, no smoothing — so none of the
# WHY BLENDER WAS DROPPED failure modes can occur. Normals are carried through
# exactly as the author baked them.

COMPONENT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_accessor(gltf, binary, index):
    acc = gltf["accessors"][index]
    n = COUNT[acc["type"]]
    fmt = COMPONENT[acc["componentType"]]
    size = struct.calcsize("<" + fmt)
    view = gltf["bufferViews"][acc["bufferView"]]
    base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride") or (size * n)
    out = []
    for i in range(acc["count"]):
        off = base + i * stride
        out.append(struct.unpack_from("<" + fmt * n, binary, off))
    return out


def node_transforms(gltf):
    """World matrix per node, walking the scene graph from its roots.

    ⚠️ NEEDED, NOT OPTIONAL. These models place their mesh with a node transform
    rather than baking it into the vertices — the Sike's four parts are laid out
    entirely by node translation. Ignoring it stacks every part on the origin.
    """
    import math

    def compose(node):
        if "matrix" in node:
            m = node["matrix"]           # glTF matrices are column-major
            return [[m[0], m[4], m[8], m[12]],
                    [m[1], m[5], m[9], m[13]],
                    [m[2], m[6], m[10], m[14]],
                    [m[3], m[7], m[11], m[15]]]
        t = node.get("translation", [0, 0, 0])
        r = node.get("rotation", [0, 0, 0, 1])
        s = node.get("scale", [1, 1, 1])
        x, y, z, w = r
        rot = [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
        return [[rot[i][j] * s[j] for j in range(3)] + [t[i]] for i in range(3)] \
            + [[0, 0, 0, 1]]

    def mul(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)]
                for i in range(4)]

    out = {}
    nodes = gltf.get("nodes", [])
    scene = gltf.get("scenes", [{}])[gltf.get("scene", 0)]

    def walk(i, parent):
        world = mul(parent, compose(nodes[i]))
        out[i] = world
        for child in nodes[i].get("children", []):
            walk(child, world)

    ident = [[1 if i == j else 0 for j in range(4)] for i in range(4)]
    for root in scene.get("nodes", range(len(nodes))):
        walk(root, ident)
    return out


def apply(m, p):
    return (m[0][0] * p[0] + m[0][1] * p[1] + m[0][2] * p[2] + m[0][3],
            m[1][0] * p[0] + m[1][1] * p[1] + m[1][2] * p[2] + m[1][3],
            m[2][0] * p[0] + m[2][1] * p[1] + m[2][2] * p[2] + m[2][3])


def apply_dir(m, p):
    return (m[0][0] * p[0] + m[0][1] * p[1] + m[0][2] * p[2],
            m[1][0] * p[0] + m[1][1] * p[1] + m[1][2] * p[2],
            m[2][0] * p[0] + m[2][1] * p[1] + m[2][2] * p[2])


def base_color_image(gltf):
    """Which embedded image is the ALBEDO, as opposed to a normal or roughness map.

    A downloaded model routinely ships three images and only one of them is the
    colour. Guessing by size picks the normal map about half the time, and a
    normal map used as albedo renders as a lilac slipper.
    """
    for mat in gltf.get("materials", []):
        pbr = mat.get("pbrMetallicRoughness", {})
        tex = pbr.get("baseColorTexture")
        if tex is None:
            continue
        source = gltf["textures"][tex["index"]].get("source")
        if source is not None:
            return source
    return None


def _pick_component(verts, faces, mode, tolerance=1e-6):
    """Keeps the part of a multi-object model that is actually the slipper.

    `mode` -1 groups the components by position and keeps one side — the right
    answer for a model saved as a left-and-right PAIR.

    `mode` 2 keeps the TALLEST component instead, which is the right answer for a
    PHOTOGRAMMETRY SCAN. The crocs the human supplied is one: it was scanned
    sitting on a wooden table and the table came with it, so most of its 100k
    triangles are tabletop and the shoe is a small object standing on it. Keeping
    the biggest island therefore kept the TABLE, and normalising a tabletop to
    slipper length shrank the actual shoe to a speck — which is what rendered as
    shredded foil and read as a decimation failure when decimation was already
    off. A scanned ground plane is always wide and flat; the subject standing on
    it is always the tallest thing in the scene.
    """
    groups = _components(verts, faces, tolerance)
    if len(groups) <= 1:
        return faces

    if mode == 2:
        def height(group):
            ys = [verts[i - 1][1] for f in group for i in (f[0], f[1], f[2])]
            return max(ys) - min(ys)
        return max(groups, key=height)

    if mode == 3:
        # ⚠️ KEEP THE WHOLE SHOE, DROP THE CRUMBS. One crocs is a shell PLUS a
        # heel strap plus a few scraps of scan noise, and neither of the other
        # two modes handles that: "tallest" throws the strap away, and the
        # pair-split cuts the single shoe in half down its own middle (measured —
        # it halved 7064 triangles to 3532 and left only the toe). Dropping every
        # island under 5% of the face count removes the noise and keeps every
        # part a person would call part of the shoe.
        total = sum(len(g) for g in groups)
        kept = [f for g in groups if len(g) >= total * 0.05 for f in g]
        return kept or faces

    return _split_pair(verts, groups)


def _components(verts, faces, tolerance=1e-6):
    """The biggest island of connected triangles.

    Connectivity is by POSITION, not by vertex index: a glTF exporter splits a
    vertex wherever its normal or UV differs, so the two halves of one shoe share
    a location but not an index and an index-only walk finds dozens of fragments
    rather than two shoes. Positions are quantised onto a fine grid before being
    compared, because two coincident vertices are rarely bit-identical.
    """
    scale = 1.0 / max(tolerance, 1e-9)
    key_of = {}
    node = []
    for v in verts:
        key = (int(round(v[0] * scale)), int(round(v[1] * scale)),
               int(round(v[2] * scale)))
        if key not in key_of:
            key_of[key] = len(key_of)
        node.append(key_of[key])

    parent = list(range(len(key_of)))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    for f in faces:
        a, b, c = f[0], f[1], f[2]
        union(node[a - 1], node[b - 1])
        union(node[b - 1], node[c - 1])

    buckets = {}
    for f in faces:
        root = find(node[f[0] - 1])
        buckets.setdefault(root, []).append(f)
    # Sorted by root id, so the order never depends on dict iteration.
    return [group for _root, group in sorted(buckets.items())]


def _split_pair(verts, groups):
    """Keeps one shoe of a left-and-right pair.

    ⚠️ ONE SHOE IS USUALLY SEVERAL COMPONENTS, so "keep the biggest island" is
    wrong — it was an earlier failed attempt. The flip-flops' sole and its
    Y-strap are separate objects that touch nowhere, so the biggest island is one
    SOLE: that split returned 82 of 252 triangles and threw the strap away.

    The parts of one shoe are near EACH OTHER and far from the other shoe, so the
    components are grouped by position instead: find the axis their centroids
    spread along most, cut at the median, keep the busier side. That keeps a sole
    with its own strap and drops the other shoe entire.
    """
    centroids = []
    for group in groups:
        n = 0
        acc = [0.0, 0.0, 0.0]
        for f in group:
            for idx in (f[0], f[1], f[2]):
                for k in range(3):
                    acc[k] += verts[idx - 1][k]
                n += 1
        centroids.append([acc[k] / max(n, 1) for k in range(3)])

    axis = max(range(3), key=lambda k: max(c[k] for c in centroids)
               - min(c[k] for c in centroids))
    values = sorted(c[axis] for c in centroids)
    mid = values[len(values) // 2] if len(values) % 2 else \
        (values[len(values) // 2 - 1] + values[len(values) // 2]) / 2.0

    low, high = [], []
    for group, centre in zip(groups, centroids):
        (low if centre[axis] <= mid else high).extend(group)
    if not low or not high:
        return max(groups, key=len)
    return low if len(low) >= len(high) else high


def decimate(verts, norms, uvs, faces, cells):
    """Vertex-clustering decimation: snap to a grid, weld, drop collapsed faces.

    ⚠️ WHY CLUSTERING RATHER THAN QUADRIC EDGE COLLAPSE, which is what Blender's
    Decimate modifier does and what "proper" decimation means. Two reasons, and
    the second is the real one:

      · It is ~40 lines and completely deterministic, so it satisfies the
        generator's determinism contract with no tuning and no dependencies.
      · **Its failure mode is exactly this game's art style.** Clustering
        produces hard, faceted planes and loses fine surface curvature — which is
        what everything else in this project already looks like (flat colour, no
        smooth shading, `recalculate_normals` at a 40-degree threshold). A
        quadric collapse would preserve smooth curvature far better and land the
        model in the uncanny middle the § WHY BLENDER WAS DROPPED note describes:
        a smooth-shaded high-detail prop standing next to flat-shaded low-poly
        everything.

    `cells` is the grid resolution along the model's longest axis.
    """
    lo = [min(v[i] for v in verts) for i in range(3)]
    hi = [max(v[i] for v in verts) for i in range(3)]
    longest = max(hi[i] - lo[i] for i in range(3)) or 1.0
    step = longest / float(cells)

    cluster_of = []
    order = []
    index_of = {}
    for v in verts:
        key = (int(round((v[0] - lo[0]) / step)),
               int(round((v[1] - lo[1]) / step)),
               int(round((v[2] - lo[2]) / step)))
        if key not in index_of:
            index_of[key] = len(order)
            order.append(key)
        cluster_of.append(index_of[key])

    # Average each cluster, so the surface sits where the geometry was rather
    # than snapping out to the grid corners.
    sums = [[0.0, 0.0, 0.0] for _ in order]
    nsums = [[0.0, 0.0, 0.0] for _ in order]
    usums = [[0.0, 0.0] for _ in order]
    counts = [0] * len(order)
    for i, c in enumerate(cluster_of):
        for k in range(3):
            sums[c][k] += verts[i][k]
            nsums[c][k] += norms[i][k]
        usums[c][0] += uvs[i][0]
        usums[c][1] += uvs[i][1]
        counts[c] += 1
    new_verts, new_norms, new_uvs = [], [], []
    for c in range(len(order)):
        n = float(counts[c])
        new_verts.append(tuple(sums[c][k] / n for k in range(3)))
        length = sum(x * x for x in nsums[c]) ** 0.5 or 1.0
        new_norms.append(tuple(x / length for x in nsums[c]))
        new_uvs.append((usums[c][0] / n, usums[c][1] / n))

    new_faces = []
    seen = set()
    for f in faces:
        a, b, c = f[0], f[1], f[2]
        ca, cb, cc = cluster_of[a - 1], cluster_of[b - 1], cluster_of[c - 1]
        if ca == cb or cb == cc or ca == cc:
            continue                      # collapsed to a line or a point
        key = tuple(sorted((ca, cb, cc)))
        if key in seen:
            continue                      # duplicate face from two collapsed ones
        seen.add(key)
        new_faces.append((ca + 1, cb + 1, cc + 1, f[3]))
    return new_verts, new_norms, new_uvs, new_faces


def cmd_obj(path, out_base, target_length, texture_rel, yaw_deg=0.0, cells=0, half=0, recolor=None, only_material=None, roll_deg=0.0):
    """Writes <out_base>.obj + .mtl, normalised to `target_length` along Z and
    centred on its own volume centroid.

    `yaw_deg` turns the model about Y first, because these are authored pointing
    whichever way their author liked and this game's props must point -Z at the
    toe (`slipper.gd` spins about the long axis).
    """
    import math

    gltf, binary = read_glb(path)
    worlds = node_transforms(gltf)
    verts, norms, uvs, faces = [], [], [], []
    for ni, node in enumerate(gltf.get("nodes", [])):
        if "mesh" not in node:
            continue
        world = worlds.get(ni)
        for prim in gltf["meshes"][node["mesh"]].get("primitives", []):
            if prim.get("mode", 4) != 4:
                continue
            attrs = prim["attributes"]
            base = len(verts)
            pos = read_accessor(gltf, binary, attrs["POSITION"])
            nrm = read_accessor(gltf, binary, attrs["NORMAL"]) if "NORMAL" in attrs else None
            tex = read_accessor(gltf, binary, attrs["TEXCOORD_0"]) if "TEXCOORD_0" in attrs else None
            for i, p in enumerate(pos):
                verts.append(apply(world, p))
                norms.append(apply_dir(world, nrm[i]) if nrm else (0.0, 1.0, 0.0))
                uvs.append(tex[i] if tex else (0.0, 0.0))
            idx = [i[0] for i in read_accessor(gltf, binary, prim["indices"])] \
                if "indices" in prim else list(range(len(pos)))
            # ⚠️ THE MATERIAL INDEX IS CARRIED PER FACE, and dropping it was why
            # the flip-flops and the Sike both rendered pure WHITE. Neither has a
            # texture at all — their colour lives entirely in each material's
            # `baseColorFactor` (a purple sole with a darker purple strap, a black
            # sandal with a white swoosh). Collapsing them onto one white material
            # threw all of it away, and the roster tint could not put it back:
            # one tint over every surface repaints the swoosh too.
            mat = prim.get("material", -1)
            for i in range(0, len(idx) - 2, 3):
                faces.append((base + idx[i] + 1, base + idx[i + 1] + 1,
                              base + idx[i + 2] + 1, mat))

    if not verts:
        raise SystemExit("%s has no triangle geometry" % path)

    # ⚠️ A MODEL CAN BE A VARIANT PACK, NOT ONE OBJECT. The crocs the human
    # settled on holds FIVE complete crocs in one file — five meshes, five
    # materials, one colourway each — and the game wants exactly one of them.
    # 🧑: *"pick dirty looking crocs"*. Selecting by material index is the stable
    # way to say which: mesh and node order are an exporter's business, but the
    # material is what carries the colourway, and the choice was made by looking
    # at the extracted textures rather than by guessing from names.
    if only_material is not None:
        faces = [f for f in faces if f[3] == only_material] or faces

    # ⚠️ MOST OF THESE MODELS ARE A PAIR, AND THE GAME THROWS ONE SLIPPER.
    # Left in, the prop is two slippers, the normalise step shrinks both to half
    # size to make the PAIR the target length, and the spin axis runs down the
    # gap between them.
    #
    # ⚠️ SEPARATED BY CONNECTED COMPONENT, NOT BY AN AXIS MIDPOINT. Splitting on
    # the x midpoint was the obvious first try and it silently failed on all
    # three pairs: none of them is axis-aligned (the Poly Pizza flip-flops sit on
    # a diagonal), so a midpoint cut takes half of each shoe and the result still
    # measures as wide as it is long. Components are exact regardless of pose.
    if half != 0:
        faces = _pick_component(verts, faces, half)

    # ⚠️ PRUNE THE ORPHANED VERTICES, AND DO IT BEFORE ANYTHING MEASURES THEM.
    # Both filters above drop FACES and leave their vertices in the list, and
    # every step that follows — the PCA that finds the long axis, the scale
    # normalisation, the volume centroid — reads `verts`. So a model split from a
    # pair was still being measured as a PAIR: the crocs reported a plausible
    # L 0.432 while rendering at a third of that, because the discarded shoe was
    # still inflating the bounding box it was being scaled against. Godot's
    # importer does the same thing, so even the AABB in-engine was wrong.
    #
    # Silent, and it survived several rounds of chasing the wrong cause. The tell
    # was a mesh whose printed dimensions and rendered size disagreed.
    used_verts = sorted(set(i for f in faces for i in (f[0], f[1], f[2])))
    remap = {old: new + 1 for new, old in enumerate(used_verts)}
    verts = [verts[i - 1] for i in used_verts]
    norms = [norms[i - 1] for i in used_verts]
    uvs = [uvs[i - 1] for i in used_verts]
    faces = [(remap[f[0]], remap[f[1]], remap[f[2]], f[3]) for f in faces]

    before = len(faces)
    if cells > 0:
        verts, norms, uvs, faces = decimate(verts, norms, uvs, faces, cells)

    # ⚠️ AUTO-ORIENTED BY PCA, NOT BY THE BOUNDING BOX. "Is it longer in X or in
    # Z" was the obvious test and it is useless here: three of these four models
    # are posed DIAGONALLY, and a diagonal shoe has a near-square axis-aligned
    # box — the flip-flops measured W 0.428 against L 0.432 and the test could
    # not tell which way the shoe pointed. The principal axis of the vertex cloud
    # is the actual long axis whatever the pose, so it is rotated onto Z.
    #
    # Closed form for the leading eigenvector of a symmetric 2x2 covariance;
    # no iteration, no library, fully deterministic.
    n = float(len(verts))
    mx = sum(v[0] for v in verts) / n
    mz = sum(v[2] for v in verts) / n
    sxx = sum((v[0] - mx) ** 2 for v in verts) / n
    szz = sum((v[2] - mz) ** 2 for v in verts) / n
    sxz = sum((v[0] - mx) * (v[2] - mz) for v in verts) / n
    theta = 0.5 * math.atan2(2.0 * sxz, sxx - szz)
    # `theta` is the angle of the LONG axis away from +X; rotate it onto +Z.
    turn = theta - math.pi / 2.0
    ct, st = math.cos(-turn), math.sin(-turn)
    verts = [(v[0] * ct - v[2] * st, v[1], v[0] * st + v[2] * ct) for v in verts]
    norms = [(nn[0] * ct - nn[2] * st, nn[1], nn[0] * st + nn[2] * ct)
             for nn in norms]

    # ⚠️ ROLL IS SEPARATE FROM YAW BECAUSE THE PCA CANNOT FIND "UP".
    # The auto-orient above finds a shoe's long axis, which fixes which way it
    # POINTS but says nothing about which way is up — a model saved sole-up is
    # still sole-up afterwards, and the crocs arrived that way: the render showed
    # its tread and vent holes facing the sky. 180 degrees about Z turns it over.
    if roll_deg != 0.0:
        roll = math.radians(roll_deg)
        cr, sr = math.cos(roll), math.sin(roll)
        verts = [(v[0] * cr - v[1] * sr, v[0] * sr + v[1] * cr, v[2]) for v in verts]
        norms = [(n[0] * cr - n[1] * sr, n[0] * sr + n[1] * cr, n[2]) for n in norms]

    yaw = math.radians(yaw_deg)
    cy, sy = math.cos(yaw), math.sin(yaw)
    verts = [(v[0] * cy + v[2] * sy, v[1], -v[0] * sy + v[2] * cy) for v in verts]
    norms = [(n[0] * cy + n[2] * sy, n[1], -n[0] * sy + n[2] * cy) for n in norms]

    lo = [min(v[i] for v in verts) for i in range(3)]
    hi = [max(v[i] for v in verts) for i in range(3)]
    span_z = hi[2] - lo[2]
    scale = target_length / span_z if span_z > 1e-9 else 1.0
    verts = [(v[0] * scale, v[1] * scale, v[2] * scale) for v in verts]

    # Volume centroid, same divergence-theorem sum ObjWriter uses, so a converted
    # model spins about the same kind of origin a generated one does.
    total, acc = 0.0, [0.0, 0.0, 0.0]
    for f in faces:
        va, vb, vc = verts[f[0] - 1], verts[f[1] - 1], verts[f[2] - 1]
        cross = (vb[1] * vc[2] - vb[2] * vc[1],
                 vb[2] * vc[0] - vb[0] * vc[2],
                 vb[0] * vc[1] - vb[1] * vc[0])
        vol = (va[0] * cross[0] + va[1] * cross[1] + va[2] * cross[2]) / 6.0
        total += vol
        for k in range(3):
            acc[k] += vol * (va[k] + vb[k] + vc[k]) / 4.0
    if abs(total) > 1e-9:
        centre = [acc[k] / total for k in range(3)]
    else:
        centre = [(min(v[k] for v in verts) + max(v[k] for v in verts)) / 2.0
                  for k in range(3)]
    verts = [(v[0] - centre[0], v[1] - centre[1], v[2] - centre[2]) for v in verts]

    lo = [min(v[i] for v in verts) for i in range(3)]
    hi = [max(v[i] for v in verts) for i in range(3)]

    # ⚠️ ONE .mtl ENTRY PER glTF MATERIAL, EACH KEEPING ITS OWN baseColorFactor.
    # Collapsing them all onto one white material is why the flip-flops and the
    # Sike first rendered PURE WHITE: neither carries a texture at all, and every
    # scrap of their colour lives in these factors (a purple sole with a darker
    # purple strap; a black sandal with a white swoosh). The roster tint cannot
    # put that back either — one tint over every surface repaints the swoosh too,
    # which is why those entries carry no `tint` key at all.
    used = sorted(set(f[3] for f in faces))
    materials = gltf.get("materials", [])
    with open(out_base + ".mtl", "w") as fh:
        fh.write("# Converted from %s by tools/models/glb_tool.py - DO NOT EDIT BY HAND.\n"
                 % os.path.basename(path))
        for mi in used:
            mat = materials[mi] if 0 <= mi < len(materials) else {}
            pbr = mat.get("pbrMetallicRoughness", {})
            colour = pbr.get("baseColorFactor", [1.0, 1.0, 1.0, 1.0])
            fh.write("newmtl m%d\n" % max(mi, 0))
            fh.write("Kd %.5f %.5f %.5f\n" % (colour[0], colour[1], colour[2]))
            fh.write("Ks 0.00000 0.00000 0.00000\n")
            # Ns 1000 == metallic 0 through Godot's importer; see obj_writer.gd.
            fh.write("Ns 1000.00000\nd %.5f\nillum 1\n"
                     % (colour[3] if len(colour) > 3 else 1.0))
            # ⚠️ THE TEXTURE GOES ONLY ON THE MATERIAL THAT ACTUALLY HAD ONE.
            # map_Kd on all of them paints every part with the sole's photo.
            if texture_rel and pbr.get("baseColorTexture") is not None:
                fh.write("map_Kd %s\n" % texture_rel)

    with open(out_base + ".obj", "w") as fh:
        fh.write("# Converted from %s by tools/models/glb_tool.py - DO NOT EDIT BY HAND.\n"
                 % os.path.basename(path))
        fh.write("# Geometry is carried through unchanged; only scale, yaw and origin move.\n")
        fh.write("mtllib %s\n" % (os.path.basename(out_base) + ".mtl"))
        fh.write("o %s\n" % os.path.basename(out_base))
        for v in verts:
            fh.write("v %.5f %.5f %.5f\n" % v)
        for t in uvs:
            fh.write("vt %.5f %.5f\n" % (t[0], t[1]))
        for n in norms:
            fh.write("vn %.5f %.5f %.5f\n" % n)
        # Grouped by material so the importer emits one surface per material in a
        # stable order — the same contract obj_writer.gd keeps.
        for mi in used:
            fh.write("usemtl m%d\n" % max(mi, 0))
            for f in faces:
                if f[3] != mi:
                    continue
                a, b, c = f[0], f[1], f[2]
                fh.write("f %d/%d/%d %d/%d/%d %d/%d/%d\n"
                         % (a, a, a, b, b, b, c, c, c))
        for a, b, c in []:
            fh.write("f %d/%d/%d %d/%d/%d %d/%d/%d\n" % (a, a, a, b, b, b, c, c, c))

    print("%s  tris %d -> %d  L %.3f W %.3f H %.3f  centroid->floor %.4f"
          % (os.path.basename(out_base), before, len(faces),
             hi[2] - lo[2], hi[0] - lo[0], hi[1] - lo[1], -lo[1]))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    verb = sys.argv[1]
    if verb == "info":
        cmd_info(sys.argv[2])
    elif verb == "extract":
        cmd_extract(sys.argv[2], sys.argv[3])
    elif verb == "replace":
        cmd_replace(sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5])
    elif verb == "obj":
        # glb_tool.py obj <in.glb> <out_base> <length> [texture_rel] [yaw_deg]
        cmd_obj(sys.argv[2], sys.argv[3], float(sys.argv[4]),
                sys.argv[5] if len(sys.argv) > 5 else "",
                float(sys.argv[6]) if len(sys.argv) > 6 else 0.0,
                int(sys.argv[7]) if len(sys.argv) > 7 else 0,
                int(sys.argv[8]) if len(sys.argv) > 8 else 0, None)
    else:
        raise SystemExit(__doc__)
