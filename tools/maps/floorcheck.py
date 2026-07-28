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

## Anything below this counts as contact. 0.5mm — far tighter than the ~8mm gap
## that was still visibly floating in the 2026-07-28 playtest, and far looser
## than float noise in a %.4f transform.
TOLERANCE = 0.0005

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
    "road_tile", "road_tile_line", "kerb_tile", "gutter_tile", "plaza_tile",
])

_bounds_cache = {}


def _glb_bounds(path):
    """(min, max) per axis of a .glb, straight from its accessor bounds.

    glTF stores per-accessor `min`/`max` for POSITION, so this needs no mesh
    decoding at all — it reads the JSON chunk and stops. Kit pieces have to go
    through the same flush check as generated ones or the guard has a hole in it
    exactly where the new assets are.
    """
    with open(path, "rb") as handle:
        struct.unpack("<III", handle.read(12))
        chunk_len, _chunk_type = struct.unpack("<II", handle.read(8))
        document = json.loads(handle.read(chunk_len).decode("utf-8"))
    lo = [math.inf] * 3
    hi = [-math.inf] * 3
    for mesh in document.get("meshes", []):
        for primitive in mesh["primitives"]:
            accessor = document["accessors"][primitive["attributes"]["POSITION"]]
            for axis in range(3):
                lo[axis] = min(lo[axis], accessor["min"][axis])
                hi[axis] = max(hi[axis], accessor["max"][axis])
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


def _to_world(lx, lz, x, z, yaw, sx):
    """Local XZ -> world XZ under the same basis `xform()` emits.

    Kept in step with the builders' own `xform()` by construction: X basis is
    (cos*sx, 0, -sin*sx) and Z basis is (sin, 0, cos), so only the mesh's own
    length axis takes the `sx` stretch. Getting this wrong would make the
    checker disagree with the scene it is checking, which is worse than no
    checker at all.
    """
    c, s = math.cos(yaw), math.sin(yaw)
    return (x + lx * c * sx + lz * s,
            z - lx * s * sx + lz * c)


class Surfaces:
    """Every placed piece, so the height under any point can be asked for."""

    def __init__(self, models_dir="assets/models"):
        self._models_dir = models_dir
        self._pieces = []   # (name, x0, x1, z0, z1, top)
        self._markings = []  # (name, mesh, x, y, z, yaw, sx)

    def record(self, name, mesh_name, x, y, z, yaw=0.0, sx=1.0, is_marking=False):
        """Called for every `add()` the builder makes, markings included."""
        lo, hi = mesh_bounds(mesh_name, self._models_dir)
        corners = [_to_world(lx, lz, x, z, yaw, sx)
                   for lx in (lo[0], hi[0]) for lz in (lo[2], hi[2])]
        xs = [p[0] for p in corners]
        zs = [p[1] for p in corners]
        if is_marking:
            # Markings are excluded from the surface set on purpose: a marking
            # is not something another marking may rest on, and letting them
            # stack would make two floaters validate each other.
            self._markings.append((name, mesh_name, x, y, z, yaw, sx))
        elif mesh_name in GROUND_MESHES:
            self._pieces.append((name, min(xs), max(xs), min(zs), max(zs), y + hi[1]))

    def height_at(self, wx, wz):
        """Top of the tallest recorded piece covering (wx, wz); 0.0 = bare floor.

        0.0 is the floor's own top surface in both maps (their `Floor` box is
        offset -0.5 with a 1-unit height). If that ever stops being true this
        returns the wrong answer confidently, so it is asserted by the caller
        rather than assumed here.
        """
        best = 0.0
        for _name, x0, x1, z0, z1, top in self._pieces:
            if x0 <= wx <= x1 and z0 <= wz <= z1 and top > best:
                best = top
        return best

    def _samples(self, mesh_name, x, z, yaw, sx):
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
        span_z = hi[2] - lo[2]
        inset_x = min(EDGE_INSET, span_x * 0.25) / max(sx, 1e-9)
        inset_z = min(EDGE_INSET, span_z * 0.25)
        x0, x1 = lo[0] + inset_x, hi[0] - inset_x
        z0, z1 = lo[2] + inset_z, hi[2] - inset_z
        nx = max(2, int(span_x / SAMPLE_STEP) + 1)
        nz = max(2, int(span_z / SAMPLE_STEP) + 1)
        for i in range(nx):
            lx = x0 + (x1 - x0) * i / (nx - 1)
            for j in range(nz):
                lz = z0 + (z1 - z0) * j / (nz - 1)
                yield _to_world(lx, lz, x, z, yaw, sx)

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
        for name, mesh_name, x, y, z, yaw, sx in self._markings:
            lo, _hi = mesh_bounds(mesh_name, self._models_dir)
            bottom = y + lo[1]
            heights = {round(self.height_at(wx, wz), 6)
                       for wx, wz in self._samples(mesh_name, x, z, yaw, sx)}
            if len(heights) > 1:
                problems.append(
                    "%s SPANS %d surface heights (%s) — no single Y is flush "
                    "for it. Split it into one piece per height; see the "
                    "ThrowingLine* segments in build_eskinita.py for how."
                    % (name, len(heights),
                       ", ".join("%.3f" % h for h in sorted(heights))))
                continue
            surface = heights.pop()
            gap = bottom - surface
            if abs(gap) > TOLERANCE:
                problems.append(
                    "%s %s the ground by %.1fmm — its underside is at %.4f, "
                    "the surface beneath it is at %.4f. Place it at y=%.4f."
                    % (name, "FLOATS above" if gap > 0 else "is SUNK into",
                       abs(gap) * 1000.0, bottom, surface, surface - lo[1]))
        if problems:
            raise SystemExit(
                "\nFLOATING GEOMETRY — build aborted, scene NOT written.\n"
                "Art_Direction.md Part 4's standing rule, enforced.\n\n  "
                + "\n  ".join(problems)
                + "\n\nA marking's placement Y is its UNDERSIDE, not its centre "
                  "(env_kit.gd::_box authors from local y=0).\n")
        return len(self._markings)
