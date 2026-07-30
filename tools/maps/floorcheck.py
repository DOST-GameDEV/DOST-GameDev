"""Makes floating field markings a BUILD FAILURE instead of a playtest report.

    from floorcheck import Surfaces

Shared by build_eskinita.py and build_bayan_plaza.py. Dev-time only, same
contract as its callers: Godot never runs it and it ships in no export.

WHY THIS EXISTS
===============

Floating markings have been "fixed" three separate times and came back every
time, because every fix was a better guess at one number. The bug is not any
particular number — it is that **a human was deciding a marking's Y by reasoning
about what is underneath it**, and the reasoning is not checkable, so it rots the
moment anything moves.

Three things make it rot, and all three have actually happened:

  1. `env_kit.gd::_box()` authors decals from LOCAL y = 0, so a marking's
     placement Y is its literal UNDERSIDE, not its centre. Place at 0.07 with
     nothing 7cm tall beneath it and it hangs 7cm in the air.
  2. The thing underneath is not always the floor. `road_tile_line` is a 6.2cm
     RAISED STRIP, not paint, so a marking crossing it needs 0.062 there and
     0.0 everywhere else.
  3. **A marking can span both at once.** `throwing_line_decal` is 8m wide and
     the raised strip is 2m, so any single Y is wrong for ~75% of that line.
     No constant can fix it — the shape has to be split. That case is invisible
     to a reviewer and was the one that kept surviving.

So this module does not pick a Y. It CHECKS one, by sampling real points across
a marking's real footprint and comparing what the geometry says is under each
against the marking's actual underside. If they disagree it raises, naming the
node and the gap in millimetres.

WHAT IT CANNOT DO. It reasons about axis-aligned footprints and flat-topped
pieces, which is what every road tile and decal in this kit is. It is a tripwire
for the one failure that keeps recurring, not a general collision system — a
render is still the acceptance test (Concurrency_Protocol.md §8 step 4).
"""
import json
import math
import os
import struct

## ⚠️ A MARKING MUST BE EMBEDDED IN THE GROUND, NOT RESTING ON IT.
##
## The previous rule was "bottom == surface", i.e. flush. That removed the
## FLOATING half of the problem and left the other half, reported 2026-07-28 as
## "the decals of floor still stick out": a marking is a 2cm-thick box, so
## sitting it exactly on the road leaves 2cm of vertical SIDE WALL standing
## proud all the way round. At a grazing angle — which is most of the time, since
## the camera is near ground level — those walls catch the light and every line
## reads as a low kerb rather than as paint.
##
## So the rule is now a SANDWICH: the top face must sit a hair above the surface
## (visible, and never z-fighting with it) and the bottom must be BELOW it (so
## the side walls are inside the ground and cannot be seen from any angle).
## A marking that satisfies both cannot float and cannot stick out.
MARK_PROUD = 0.002
MARK_PROUD_MAX = 0.004

## Anything below this counts as contact. 0.5mm — far tighter than the ~8mm gap
## that was still visibly floating in the 2026-07-28 playtest, and far looser
## than float noise in a %.4f transform.
TOLERANCE = 0.0005

## The same idea for DRESSING, deliberately looser than the marking sandwich.
## A decal is paint and must be embedded to sub-millimetre; a monobloc chair is
## an object resting on a road and 5mm either way is both invisible and often
## physically right (kit meshes are not modelled to a shared floor plane). Tight
## enough to catch the two failures that actually happened — the 100mm sink and
## the 525mm van hover — by two orders of magnitude.
DRESS_TOLERANCE = 0.005

## How much two footprints may intersect before `overlaps()` mentions them.
## 0.15m: eaves, kerbs and canopies legitimately graze each other at this scale;
## the interpenetration this exists to catch was 2.5 METRES.
OVERLAP_SLACK = 0.15

## How finely a marking's footprint is sampled, in metres. 0.1 is well under the
## 2m width of the narrowest raised piece in the kit (`road_tile_line`), so a
## marking cannot step onto or off a tile between two samples and go unnoticed.
SAMPLE_STEP = 0.1

## How far in from a piece's own edge sampling starts. See `_samples`.
EDGE_INSET = 0.02

## What counts as GROUND a marking may rest on.
##
## ⚠️ AN ALLOWLIST, NOT A HEIGHT TEST, and the first version got this wrong. It
## treated every recorded piece as ground, so a wall standing BESIDE a line —
## whose bounding box overlaps it in plan view — reported as a 2.62m surface
## "underneath" it. A marking next to a wall is a different problem (or no
## problem); only things you can actually stand a line on belong here.
##
## Add a mesh here when it becomes something markings sit on. Leaving one out is
## the safe direction: the checker then measures against bare floor and, if the
## marking really was resting on it, reports a float rather than staying quiet.
GROUND_MESHES = frozenset([
    # Generated.
    "road_tile", "road_tile_line", "kerb_tile", "gutter_tile", "plaza_tile",
    # Kit paving. ⚠️ A kit ground piece MUST be listed here or every marking
    # resting on it measures against bare floor instead and the guard reports a
    # float that is not there — see checklist 7.4's note.
    "kits/town/road", "kits/town/road-curb", "kits/town/road-edge",
    "kits/city/driveway-long", "kits/city/path-long",
])

_bounds_cache = {}


def _mat_identity():
    return [1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0]


def _mat_mul(a, b):
    """Column-major 4x4 multiply, glTF's own convention. Returns a*b."""
    out = [0.0] * 16
    for col in range(4):
        for row in range(4):
            out[col * 4 + row] = sum(a[k * 4 + row] * b[col * 4 + k]
                                     for k in range(4))
    return out


def _mat_from_node(node):
    """A glTF node's local transform, from either `matrix` or its T/R/S trio."""
    if "matrix" in node:
        return list(node["matrix"])
    out = _mat_identity()
    if "rotation" in node:
        x, y, z, w = node["rotation"]
        out = [
            1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w), 0.0,
            2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w), 0.0,
            2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y), 0.0,
            0.0, 0.0, 0.0, 1.0,
        ]
    if "scale" in node:
        sx, sy, sz = node["scale"]
        for row in range(4):
            out[0 + row] *= sx
            out[4 + row] *= sy
            out[8 + row] *= sz
    if "translation" in node:
        out[12], out[13], out[14] = node["translation"]
    return out


def _mat_apply(m, p):
    return (m[0] * p[0] + m[4] * p[1] + m[8] * p[2] + m[12],
            m[1] * p[0] + m[5] * p[1] + m[9] * p[2] + m[13],
            m[2] * p[0] + m[6] * p[1] + m[10] * p[2] + m[14])


def _glb_bounds(path):
    """(min, max) per axis of a .glb, in the SCENE's space, not the mesh's.

    glTF stores per-accessor `min`/`max` for POSITION, so this needs no mesh
    decoding at all — it reads the JSON chunk and stops.

    ⚠️ IT MUST STILL WALK THE NODE HIERARCHY, AND NOT DOING SO IS WHAT PUT A VAN
    IN THE AIR. This function used to union raw accessor bounds and ignore the
    scene graph entirely. That is correct for a single-node kit piece — every
    `building-type-*`, every `road` tile — and silently wrong for any piece
    assembled from several nodes, because glTF puts the assembly offsets on the
    NODES, not in the vertex data.

    Kenney's Car Kit is exactly that: `kits/car/van` is five nodes, and every
    wheel carries `translation: [±0.3, 0.30, ±0.76]` while its wheel MESH is
    modelled centred on its own origin (-0.3 .. +0.3). So the raw accessor
    minimum read -0.300 when the van's real base is 0.000, and `add_kit()`'s
    `base_y - lo[1] * scale` dutifully lifted every vehicle by 0.3 * 1.75 =
    **exactly 0.525 units of hover**. Reported from a playtest as "the blue van
    is hovering", and invisible to every check in this file, because the file
    itself was the thing that was wrong.

    So: compose each node's local transform down from the scene roots, push each
    primitive's accessor AABB through the composed matrix, and union the eight
    transformed corners. A rotated node makes that AABB conservative rather than
    exact, which is the safe direction — it can only ever report a piece as
    slightly larger than it is.
    """
    with open(path, "rb") as handle:
        struct.unpack("<III", handle.read(12))
        chunk_len, _chunk_type = struct.unpack("<II", handle.read(8))
        document = json.loads(handle.read(chunk_len).decode("utf-8"))
    nodes = document.get("nodes", [])
    accessors = document.get("accessors", [])
    meshes = document.get("meshes", [])
    lo = [math.inf] * 3
    hi = [-math.inf] * 3

    def visit(index, parent):
        node = nodes[index]
        world = _mat_mul(parent, _mat_from_node(node))
        if "mesh" in node:
            for primitive in meshes[node["mesh"]]["primitives"]:
                accessor = accessors[primitive["attributes"]["POSITION"]]
                amin, amax = accessor["min"], accessor["max"]
                for cx in (amin[0], amax[0]):
                    for cy in (amin[1], amax[1]):
                        for cz in (amin[2], amax[2]):
                            wx, wy, wz = _mat_apply(world, (cx, cy, cz))
                            for axis, value in enumerate((wx, wy, wz)):
                                lo[axis] = min(lo[axis], value)
                                hi[axis] = max(hi[axis], value)
        for child in node.get("children", []):
            visit(child, world)

    roots = []
    if document.get("scenes"):
        scene = document["scenes"][document.get("scene", 0)]
        roots = scene.get("nodes", [])
    if not roots:
        # No scene declaration: treat every node that is nobody's child as a
        # root. Falling back to "union the accessors" here would reintroduce the
        # hovering-van bug in exactly the files least likely to be looked at.
        children = {c for n in nodes for c in n.get("children", [])}
        roots = [i for i in range(len(nodes)) if i not in children]
    for root in roots:
        visit(root, _mat_identity())
    if lo[0] is math.inf:
        raise ValueError("floorcheck: %s has no positioned mesh nodes" % path)
    return lo, hi


def mesh_bounds(mesh_name, models_dir="assets/models"):
    """Local-space (min, max) per axis of a mesh, read from the file.

    Takes either a generated `env_<name>.obj` or a kit piece given as
    `kits/<kit>/<piece>` (a `.glb`).

    ⚠️ READ FROM THE .obj, NEVER ASSUMED. "Decals start at local y=0" is true
    today and is written down in two places, and it is exactly the kind of
    claim that silently stops being true when someone edits the generator. The
    whole point of this module is to not take that on faith.
    """
    if mesh_name in _bounds_cache:
        return _bounds_cache[mesh_name]
    if mesh_name.startswith("kits/"):
        path = os.path.join(models_dir, "%s.glb" % mesh_name)
        _bounds_cache[mesh_name] = _glb_bounds(path)
        return _bounds_cache[mesh_name]
    path = os.path.join(models_dir, "env_%s.obj" % mesh_name)
    lo = [math.inf] * 3
    hi = [-math.inf] * 3
    with open(path) as handle:
        for line in handle:
            if not line.startswith("v "):
                continue
            parts = line.split()
            for axis in range(3):
                value = float(parts[axis + 1])
                lo[axis] = min(lo[axis], value)
                hi[axis] = max(hi[axis], value)
    if lo[0] is math.inf:
        raise ValueError("floorcheck: %s has no vertices" % path)
    _bounds_cache[mesh_name] = (lo, hi)
    return _bounds_cache[mesh_name]


def embed_y(surface, mesh_name, models_dir="assets/models", scale=1.0):
    """The placement Y that embeds `mesh_name` in a surface at `surface`.

    The single source of truth for the sandwich rule above — both map builders
    call it rather than doing the arithmetic, so a marking cannot be placed by a
    number somebody worked out by hand. That is the whole lesson of this file.
    """
    _lo, hi = mesh_bounds(mesh_name, models_dir)
    return surface + MARK_PROUD - hi[1] * scale


def _to_world(lx, lz, x, z, yaw, sx, sz=1.0):
    """Local XZ -> world XZ under the same basis the builders emit.

    ⚠️ TWO DIFFERENT SCALES SHARE THIS. `xform()` stretches ONLY the mesh's local
    X row, which is what a lengthenable line decal needs. `xform_uniform()`
    scales all three axes, which is what a kit building needs. Passing `sz` is
    how the caller says which one it meant — and getting it wrong is not
    cosmetic: a kit road tile recorded at X-only scale reports a footprint a
    quarter of its real size and a TOP HEIGHT that ignores the scale entirely,
    so every marking on it measures against the wrong ground.

    Kept in step with the builders' own `xform()` by construction: X basis is
    (cos*sx, 0, -sin*sx) and Z basis is (sin, 0, cos), so only the mesh's own
    length axis takes the `sx` stretch. Getting this wrong would make the
    checker disagree with the scene it is checking, which is worse than no
    checker at all.
    """
    c, s = math.cos(yaw), math.sin(yaw)
    return (x + lx * c * sx + lz * s * sz,
            z - lx * s * sx + lz * c * sz)


class Surfaces:
    """Every placed piece, so the height under any point can be asked for."""

    def __init__(self, models_dir="assets/models", base_height=0.0,
                 check_dressing=True):
        """`base_height` is the top of the map's own Floor box — bare ground.

        ⚠️ IT IS NO LONGER SAFE TO ASSUME 0.0, AND ASSUMING IT HID A REAL BUG.
        Eskinita's floor collision top was at 0.0 while its paving rendered to
        0.100, so a character standing on the floor had its feet 100 mm INSIDE
        the visible road — the same class of fault as the sunk props, on the one
        surface every player touches every frame. Eskinita now sets its floor top
        to the paving height and passes it here, so "bare ground" and "paved
        ground" are the same number and there is no step anywhere on the map.

        `check_dressing=False` opts a map out of the prop-grounding check. Only
        Bayan Plaza uses it, deliberately and temporarily — see its own header.
        """
        self._models_dir = models_dir
        self._base_height = base_height
        self._check_dressing = check_dressing
        self._pieces = []   # (name, x0, x1, z0, z1, top)  — GROUND only
        self._markings = []  # (name, mesh, x, y, z, yaw, sx)
        ## Every non-marking, non-ground piece: the dressing. Recorded so
        ## `verify()` can check it is standing ON something instead of hovering
        ## over it or sunk into it. See DRESS_TOLERANCE.
        self._dressing = []  # (name, mesh, bottom, x0, x1, z0, z1, group)

    def record(self, name, mesh_name, x, y, z, yaw=0.0, sx=1.0,
               is_marking=False, uniform=False, group="", suspended=False):
        """Called for every `add()` the builder makes, markings included.

        `uniform` says the placement scaled all three axes (a kit piece via
        `add_kit`) rather than only the mesh's length (a stretched line decal).
        It is what makes the recorded TOP HEIGHT correct, which is what every
        marking on top of that piece is then measured against.

        `group` is the dressing layer a piece belongs to ("Layer1", "Clutter",
        ...). Only used by the overlap check, which is per-group: two houses in
        the same row sharing a volume is a bug, a tyre leaning on a fence is not.
        """
        lo, hi = mesh_bounds(mesh_name, self._models_dir)
        sz = sx if uniform else 1.0
        sy = sx if uniform else 1.0
        corners = [_to_world(lx, lz, x, z, yaw, sx, sz)
                   for lx in (lo[0], hi[0]) for lz in (lo[2], hi[2])]
        xs = [p[0] for p in corners]
        zs = [p[1] for p in corners]
        if is_marking:
            # Markings are excluded from the surface set on purpose: a marking
            # is not something another marking may rest on, and letting them
            # stack would make two floaters validate each other.
            self._markings.append((name, mesh_name, x, y, z, yaw, sx, uniform))
        elif mesh_name in GROUND_MESHES:
            self._pieces.append((name, min(xs), max(xs), min(zs), max(zs),
                                 y + hi[1] * sy))
        elif not suspended:
            self._dressing.append((name, mesh_name, y + lo[1] * sy,
                                   min(xs), max(xs), min(zs), max(zs), group))
        # `suspended` is the ONE legitimate way to be off the ground, and it is
        # an explicit named opt-out rather than a hole: a sampay line is strung
        # between two houses and is SUPPOSED to hang 1.5m up. Without this the
        # grounding check reports five true-positive-shaped false positives and
        # the next person to see them switches the whole check off.

    def height_at(self, wx, wz):
        """Top of the tallest recorded piece covering (wx, wz), else bare floor.

        Bare floor is `base_height`, passed in by the map rather than assumed —
        see `__init__`. A map whose Floor box top is not that number gets wrong
        answers confidently, which is why it is a constructor argument and the
        builder derives it from the same constant it writes into the scene.
        """
        best = self._base_height
        for _name, x0, x1, z0, z1, top in self._pieces:
            if x0 <= wx <= x1 and z0 <= wz <= z1 and top > best:
                best = top
        return best

    def _samples(self, mesh_name, x, z, yaw, sx, sz=1.0):
        """Points across the piece's footprint, INSET from its own edges.

        ⚠️ The inset is load-bearing, not a rounding fudge. Two markings that
        abut exactly on a step — which is what splitting a line at that step
        produces — each have one edge lying precisely on the boundary, where
        "what is underneath" is genuinely both answers. Sampling the edge makes
        every correctly-split line report as spanning two heights, i.e. the
        checker rejects the exact fix it just asked for.

        Insetting asks about the piece's INTERIOR instead, which is the thing
        that actually shows a gap. It does not weaken the check: the 8m line
        this was built to catch spans a 2m strip, three orders of magnitude
        wider than this inset.
        """
        lo, hi = mesh_bounds(mesh_name, self._models_dir)
        span_x = (hi[0] - lo[0]) * sx
        span_z = (hi[2] - lo[2]) * sz
        inset_x = min(EDGE_INSET, span_x * 0.25) / max(sx, 1e-9)
        inset_z = min(EDGE_INSET, span_z * 0.25) / max(sz, 1e-9)
        x0, x1 = lo[0] + inset_x, hi[0] - inset_x
        z0, z1 = lo[2] + inset_z, hi[2] - inset_z
        nx = max(2, int(span_x / SAMPLE_STEP) + 1)
        nz = max(2, int(span_z / SAMPLE_STEP) + 1)
        for i in range(nx):
            lx = x0 + (x1 - x0) * i / (nx - 1)
            for j in range(nz):
                lz = z0 + (z1 - z0) * j / (nz - 1)
                yield _to_world(lx, lz, x, z, yaw, sx, sz)

    def verify(self):
        """Raises on the first marking that floats or spans a step.

        Two distinct failures, reported differently because the fixes differ:

          FLOATS   — uniform ground underneath, wrong Y. Change the Y to the
                     number in the message.
          SPANS    — the ground under it is not uniform, so NO Y is correct.
                     Split the marking into one piece per surface height. This
                     is the one that kept coming back.
        """
        problems = []
        for name, mesh_name, x, y, z, yaw, sx, uniform in self._markings:
            lo, _hi = mesh_bounds(mesh_name, self._models_dir)
            # ⚠️ SCALE THE HEIGHTS. This used to read `lo[1]`/`hi[1]` raw, which
            # is right for `xform()`'s length-only stretch (Y is untouched there)
            # and WRONG the moment a marking is placed through `add_kit()`, whose
            # scale is uniform. The ground-piece side of exactly this bug shipped
            # a whole re-paving measured against unscaled tile heights; this is
            # the same hole on the marking side, closed before it could bite.
            sy = sx if uniform else 1.0
            sz = sx if uniform else 1.0
            bottom = y + lo[1] * sy
            heights = {round(self.height_at(wx, wz), 6)
                       for wx, wz in self._samples(mesh_name, x, z, yaw, sx, sz)}
            if len(heights) > 1:
                problems.append(
                    "%s SPANS %d surface heights (%s) — no single Y is flush "
                    "for it. Split it into one piece per height; see the "
                    "ThrowingLine* segments in build_eskinita.py for how."
                    % (name, len(heights),
                       ", ".join("%.3f" % h for h in sorted(heights))))
                continue
            surface = heights.pop()
            top = y + _hi[1] * sy
            proud = top - surface
            if proud < -TOLERANCE:
                problems.append(
                    "%s is BURIED — its top face is %.1fmm BELOW the surface at "
                    "%.4f, so it will not be visible at all. Place it at y=%.4f."
                    % (name, -proud * 1000.0, surface,
                       embed_y(surface, mesh_name, self._models_dir, sy)))
            elif proud > MARK_PROUD_MAX:
                problems.append(
                    "%s STICKS OUT — its top face stands %.1fmm above the "
                    "surface at %.4f, so its side walls show as a kerb at a "
                    "grazing angle. Place it at y=%.4f."
                    % (name, proud * 1000.0, surface,
                       embed_y(surface, mesh_name, self._models_dir, sy)))
            elif bottom >= surface - TOLERANCE:
                problems.append(
                    "%s RESTS ON the ground instead of being embedded in it — "
                    "its underside is at %.4f against a surface at %.4f, so %.1fmm "
                    "of side wall is exposed all the way round. Place it at "
                    "y=%.4f."
                    % (name, bottom, surface, (top - bottom) * 1000.0,
                       embed_y(surface, mesh_name, self._models_dir, sy)))
        problems.extend(self._verify_dressing())
        if problems:
            raise SystemExit(
                "\nFLOATING GEOMETRY — build aborted, scene NOT written.\n"
                "Art_Direction.md Part 4's standing rule, enforced.\n\n  "
                + "\n  ".join(problems)
                + "\n\nA marking's placement Y is its UNDERSIDE, not its centre "
                  "(env_kit.gd::_box authors from local y=0).\n")
        return len(self._markings)

    def _verify_dressing(self):
        """Every prop must stand on whatever is actually beneath it.

        ⚠️ THIS IS THE HALF OF THE GUARD THAT WAS MISSING, AND IT COST A WHOLE
        MAP. `verify()` iterated `self._markings` and nothing else, so all 111
        dressing instances were recorded and then never compared against
        anything. When checklist 7.4b re-paved the alley and moved the walkable
        surface from 0.000 to 0.100, every marking followed it (they ask
        `height_at()`) and **every prop did not** — crates, tyres, drums, chairs,
        bollards, tricycles and the electric posts were all left sunk exactly
        100 mm into the new road, and nothing in this file noticed.

        The failure is symmetric with the marking one and so is the check: a
        prop's bottom must equal the ground under its own centre. Sunk reads as
        clipping, proud reads as hovering, and the 2026-07-29 "the blue van is
        hovering" report was the proud direction (see `_glb_bounds`).
        """
        if not self._check_dressing:
            return []
        problems = []
        for name, _mesh, bottom, x0, x1, z0, z1, _group in self._dressing:
            surface = self.height_at((x0 + x1) * 0.5, (z0 + z1) * 0.5)
            gap = bottom - surface
            if gap > DRESS_TOLERANCE:
                problems.append(
                    "%s HOVERS %.0fmm above the surface at %.4f — its base is at "
                    "%.4f. Place it with base_y=%.4f."
                    % (name, gap * 1000.0, surface, bottom, surface))
            elif gap < -DRESS_TOLERANCE:
                problems.append(
                    "%s is SUNK %.0fmm into the surface at %.4f — its base is at "
                    "%.4f. Place it with base_y=%.4f."
                    % (name, -gap * 1000.0, surface, bottom, surface))
        return problems

    def footprint_is_clear(self, x0, x1, z0, z1, groups=None):
        """Would a piece with this footprint land on top of something already placed?

        ⚠️ THE ASK-BEFORE-PLACING COUNTERPART OF `overlaps_across`, and it exists
        because that one is a POST-MORTEM. `overlaps_across` runs at the end of a
        build and prints a warning about geometry that is already in the scene
        file; the reader is then expected to go and move something by hand. That
        is fine for a handful of hand-placed landmarks and useless for anything
        placed by a LOOP, where the right answer is simply "skip this one".

        Bayan Plaza's boundary hedge row is exactly that case: it walks the whole
        perimeter on a fixed step and some of those steps land on stalls, benches
        and the flagpole that were placed there first. Asking first turns 19
        reported overlaps into a row with gaps in it, which is also the better
        LOOK - a solid ring of hedge reads as a fence, and a plaza does not have
        one.

        Same slack and same footprint maths as `overlaps_across`, so a placement
        this function approves cannot be reported by that one afterwards.
        `groups` defaults to every recorded piece.
        """
        for name, _mesh, _bottom, ox0, ox1, oz0, oz1, group in self._dressing:
            if groups is not None and group not in groups:
                continue
            ox = min(x1, ox1) - max(x0, ox0)
            oz = min(z1, oz1) - max(z0, oz0)
            if ox > OVERLAP_SLACK and oz > OVERLAP_SLACK:
                return False
        return True

    def overlaps(self, group):
        """Pieces in `group` whose footprints intersect. A WARNING, not a failure.

        Deliberately not fatal. An axis-aligned footprint test cannot tell a
        legitimate overlap (a tyre leaning on a fence, a tree canopy over a
        kerb) from two houses occupying the same volume, and a guard that cries
        wolf gets switched off. It is here because §8.0's building-interpenetration
        bug — five of eleven `building-type-*` wider than their own 6.6 bay —
        would have been caught the day it landed, by exactly this test.
        """
        return self.overlaps_across([group])

    def overlaps_across(self, groups):
        """The same test, over the UNION of several groups.

        ⚠️ `overlaps()` compares within ONE group, and that is exactly the hole
        a new group falls through. Bayan Plaza's monument enclosure went into a
        new `Monument` group and had to be checked against the `Clutter`,
        `Furniture` and `Hazards` pieces that were already standing where it was
        going — a same-group test would have reported nothing and the railing
        would have grown through a bench. Same slack, same warning-not-failure
        contract, same reason (see `overlaps`).
        """
        found = []
        items = [d for d in self._dressing if d[7] in groups]
        for i in range(len(items)):
            an, _am, _ab, ax0, ax1, az0, az1, _ag = items[i]
            for j in range(i + 1, len(items)):
                bn, _bm, _bb, bx0, bx1, bz0, bz1, _bg = items[j]
                ox = min(ax1, bx1) - max(ax0, bx0)
                oz = min(az1, bz1) - max(az0, bz0)
                if ox > OVERLAP_SLACK and oz > OVERLAP_SLACK:
                    found.append((an, bn, ox, oz))
        return found


# =============================================================================
# GAMEPLAY CONSTANTS THE MAPS MUST NOT RESTATE
# =============================================================================

def read_confinement_radius():
    """CharacterBase.CONFINEMENT_RADIUS, parsed out of the GDScript that owns it.

    ⚠️ READ, NOT COPIED, AND THAT IS THE ENTIRE POINT. Both map builders used to
    declare their own `CONFINEMENT_BOX_RADIUS = 5.0` next to a "keep the two in
    sync" comment — one gameplay number written out longhand in three files and
    kept aligned by hand. The chalk box on the floor IS the confinement boundary,
    so the moment those drift the map lies to the player about where they can go.

    That is not hypothetical: the same number already disagreed with itself in a
    subtler way. The builders drew a SQUARE while `_move_and_confine()` clamped a
    CIRCLE, so at the corners the chalk promised 7.07 units and the physics stopped
    the player at 5.0. Fixed 2026-07-29 by making the clamp square; this function
    is the other half, so the two cannot drift again.

    Raises rather than falling back to a literal. A silent default would restore
    exactly the failure mode this removes — the build would keep working while
    quietly drawing the wrong boundary.
    """
    import os
    import re

    here = os.path.dirname(os.path.abspath(__file__))
    gd = os.path.normpath(os.path.join(here, "..", "..", "scripts", "characters",
                                       "character_base.gd"))
    try:
        with open(gd, encoding="utf-8") as handle:
            source = handle.read()
    except OSError as exc:
        raise SystemExit(
            "build aborted: cannot read %s to get CONFINEMENT_RADIUS (%s)" % (gd, exc))
    match = re.search(r"^const\s+CONFINEMENT_RADIUS\s*:\s*float\s*=\s*([0-9.]+)",
                      source, re.M)
    if not match:
        raise SystemExit(
            "build aborted: no `const CONFINEMENT_RADIUS: float = ...` in %s. "
            "If it was renamed, update read_confinement_radius() rather than "
            "hardcoding the number back into the map builders." % gd)
    return float(match.group(1))
