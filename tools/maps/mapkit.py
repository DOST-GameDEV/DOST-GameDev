"""The logic BOTH map builders need, so the next lesson is ported ZERO times.

    from mapkit import Placer, apron_cells, front_yaw

Sibling of floorcheck.py, and it exists for a reason written down in
build_bayan_plaza.py's own header:

    "the two builders share floorcheck.py and nothing else. Every Eskinita
     lesson has to be ported by hand, and that is exactly how the first five
     bugs above survived."

floorcheck.py owns the GROUNDING contract — what height a thing sits at, and
whether it floats. This module owns everything else the two maps had
independently reinvented or, more often, failed to reinvent:

  * `Placer`      — ask-before-placing, so an overlap is never created rather
                    than reported afterwards.
  * `apron_cells` — the feathered void-kill apron, so neither map ends in a
                    hard square.
  * `front_yaw`   — the -Z front convention, applied rather than restated.

⚠️ NOTHING IN HERE PLACES ANYTHING ITSELF. It takes the builder's own `add`
callables so each map keeps its own grounding, its own lane law and its own
node-group names. A shared module that also owned placement would need to know
about both maps' lane geometry, and a corridor and a room do not share one.
"""
import math


# =============================================================================
# DETERMINISTIC NOISE
# =============================================================================
#
# ⚠️ NOT `random`, NOT `hash()`, AND NOT AN RNG SEEDED ONCE. Both builders state
# the rule — "SEEDED, NEVER RANDOM. A layout that differs between two runs of
# this file cannot be reviewed in a diff and cannot be bisected when something
# floats" — and a stream RNG breaks it in a subtler way than `random` does: its
# Nth value depends on how many times it was called BEFORE, so inserting one
# tile anywhere upstream reshuffles every tile downstream and the diff is the
# whole map. This is a pure function of the cell's own coordinates, so a tile's
# fate depends on nothing but where it is.
#
# Python's `hash()` is unusable here for the same class of reason: it is
# randomised per process for str/bytes, and its int behaviour is an
# implementation detail rather than a promise.

def cell_noise(ix, iz):
    """A stable 0.0..1.0 per integer cell. Same answer on every run, every OS."""
    h = (ix * 73856093) ^ (iz * 19349663)
    h &= 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 1274126177) & 0xFFFFFFFF
    h ^= h >> 16
    return (h & 0xFFFF) / 65535.0


# =============================================================================
# THE FEATHERED APRON — the fix for "the paved apron ends in a hard square"
# =============================================================================

def apron_cells(inner, outer, step, half=None, skip_core=None):
    """Yields (x, z, ix, iz) for a paved apron whose EDGE DISSOLVES.

    ⚠️ THE HARD SQUARE WAS NEVER A DISTANCE PROBLEM, WHICH IS WHY WIDENING IT
    TWICE DID NOT FIX IT. Bayan Plaza's own open item 2 records both attempts:
    the apron went 30 -> 38 and the fog came in 64 -> 50, and the y=30 overhead
    still showed a straight line where the paving stopped. It always will. A
    filled square of tiles has a straight edge at ANY radius, and fog only
    lowers its contrast — at the overhead the camera looks along the fog's
    thinnest axis, so the one shot that shows the edge is the one shot the fog
    cannot help with.

    So the edge stops being an edge. Tiles in the band `inner..outer` survive
    with a probability that falls from 1 to 0 across it, keyed on the cell's own
    coordinates, so the paving thins into scattered patches and there is no line
    anywhere to see. Past `outer` there is nothing, but by then there is nothing
    to notice either — the last tiles out there are isolated specks.

    THIS IS CHEAPER THAN WHAT IT REPLACES, which is the rare direction for a
    fix in this lane. A solid apron to `outer` would be the full square; this
    keeps roughly half the band, so a WIDER apron costs FEWER instances than the
    narrow hard-edged one it replaces. Measured counts are printed by both
    builders.

    `half` clamps the grid to a square of that half-width (the old APRON), and
    `skip_core(x, z)` is how a map excludes the area it paves at a finer grid.
    """
    limit = outer if half is None else half
    span = max(outer - inner, 1e-6)
    gx = -limit + step * 0.5
    ix = 0
    while gx <= limit:
        gz = -limit + step * 0.5
        iz = 0
        while gz <= limit:
            if skip_core is None or not skip_core(gx, gz):
                # Square rings, not circular: the apron is a square grid and a
                # circular falloff inside it leaves the SQUARE's own corners
                # sticking out past the dissolve — the hard edge again, in the
                # four places the overhead shot looks straight at.
                d = max(abs(gx), abs(gz))
                t = (d - inner) / span
                if t <= 0.0 or cell_noise(ix, iz) > t:
                    yield gx, gz, ix, iz
            iz += 1
            gz += step
        ix += 1
        gx += step


# =============================================================================
# ASK BEFORE PLACING
# =============================================================================

class Placer:
    """Wraps a builder's own `add`/`add_kit` so a piece ASKS before it lands.

    ⚠️ THIS IS THE HALF THAT WAS MISSING, AND THE POST-MORTEM IS WHY THE EIGHT
    SURVIVED. `Surfaces.overlaps_across()` runs after the scene is built and
    prints a list; a human is then expected to go and nudge coordinates by hand.
    That is how Bayan Plaza shipped eight interior overlaps that were reported,
    read, written up in the file header as "left alone rather than shuffled
    blind", and still there a session later. A warning nobody can act on cheaply
    is a warning that becomes furniture.

    `try_place` refuses instead. And because refusing outright would quietly
    delete content the map wants — a sari-sari stall is not a spare tile — it
    first walks a small ladder of SEEDED offsets and takes the first that is
    clear. Content survives, the overlap does not, and neither outcome needs
    anybody to look at a list.

    ⚠️ THE LADDER IS ORDERED AND FIXED, NOT SEARCHED. Same rule as everything
    else here: two runs must produce the same map. The offsets are deliberately
    small (<= 1.2 m) — this is for resolving a graze, not for relocating a piece
    that was placed somewhere wrong. If everything on the ladder is blocked the
    piece is SKIPPED and counted, and the count is printed, because a silent
    skip is how a map loses a landmark without anyone noticing.
    """

    ## Tried in this order, in metres, relative to the nominal position. First
    ## the four cardinals at half a metre, then at 1.2 — a graze is 0.2-0.65 m
    ## by the report, so the first ring clears nearly all of them.
    LADDER = [(0.0, 0.0),
              (0.55, 0.0), (-0.55, 0.0), (0.0, 0.55), (0.0, -0.55),
              (0.9, 0.9), (-0.9, 0.9), (0.9, -0.9), (-0.9, -0.9),
              (1.2, 0.0), (-1.2, 0.0), (0.0, 1.2), (0.0, -1.2)]

    ## ⚠️ A SECOND LADDER, BECAUSE A 1.2 m NUDGE CANNOT CLEAR A 7 m HOUSE.
    ## The fine ladder above is sized for the 0.2-0.65 m grazes between props that
    ## it was written for. Eskinita's back row (`Likod`) is City Kit buildings at
    ## CITY_SCALE, overlapping each other by up to 1.93 m, and offering them
    ## half-metre steps just walks a 7 m box around inside its neighbour and then
    ## reports a skip — deleting a building to resolve a graze, which is the worst
    ## of the three outcomes. Scale the ladder to the piece.
    COARSE_LADDER = [(0.0, 0.0),
                     (0.0, 2.6), (0.0, -2.6), (2.6, 0.0), (-2.6, 0.0),
                     (0.0, 4.4), (0.0, -4.4), (3.4, 3.4), (-3.4, -3.4),
                     (0.0, 6.2), (0.0, -6.2)]

    ## ⚠️⚠️ THE DEFENDER'S BOX IS A KEEP-OUT **FOR PIECES THAT ASK FOR IT**, and
    ## the opt-in is the whole design. Added 2026-08-01 by ⚖️ `build fair` when
    ## `CONFINEMENT_RADIUS` grew and the rebuild put clutter, four solid electric
    ## posts and Bayan Plaza's monument inside the play area.
    ##
    ## ⚠️ IT WAS BLANKET FOR ONE ITERATION AND THAT WAS WRONG. Applied to every
    ## piece it evicted 28 props from Eskinita and 11 from the plaza — 🧑: *"i was
    ## okay with the clutter earlier, js put the tree out of the play area"*. A
    ## street with nothing on it is not the fix; the fix is that the things a
    ## player COLLIDES with at running height stay out. Litter on the road is set
    ## dressing and reads as the game's whole setting; a tree trunk is a wall.
    ##
    ## So `keep_out=True` is passed per call site, by the builder, for the pieces
    ## that are genuinely obstacles. Everything else places exactly as before.
    ##
    ## ⚠️ SET FROM `CONFINEMENT_RADIUS`, NEVER TYPED. Both builders read that const
    ## through `floorcheck.read_confinement_radius()`, so the keep-out follows the
    ## box automatically and a future resize cannot leave it stale — which is the
    ## failure that produced this in the first place.
    ##
    ## ⚠️ IT REJECTS ON FOOTPRINT, NOT ON ORIGIN. A canopy whose TRUNK sits outside
    ## the line while its crown hangs over the court is exactly the piece that
    ## reads as "a tree in the play area", so the piece's own extent is tested.
    play_box = None
    ## How far OUTSIDE the chalk a piece must also stay. Half a body width: a prop
    ## flush against the line is still something you collide with while running it.
    PLAY_BOX_MARGIN = 0.45

    def __init__(self, surfaces, piece_extent, avoid_groups):
        self._surfaces = surfaces
        self._extent = piece_extent
        self._avoid = avoid_groups
        self.placed = 0
        self.nudged = 0
        self.skipped = 0
        self.skips = []
        self.evicted = 0

    def in_play_box(self, mesh_name, x, z, yaw, scale):
        """True if any part of this piece's footprint enters the play area."""
        if self.play_box is None:
            return False
        e = self._extent(mesh_name, yaw, scale)
        limit = self.play_box + Placer.PLAY_BOX_MARGIN
        # The footprint is a box; it intrudes unless it is wholly on one side.
        outside = (x + e[1] <= -limit or x + e[0] >= limit
                   or z + e[3] <= -limit or z + e[2] >= limit)
        return not outside

    def clear_at(self, mesh_name, x, z, yaw, scale, avoid=None):
        """`avoid` overrides the default group list for THIS piece only.

        ⚠️ WHAT A PIECE MUST DODGE IS A PROPERTY OF THE PIECE, NOT OF THE MAP, and a
        single shared list gets one of the two cases wrong. A crate inside a tree is
        a bug; two tree CANOPIES interleaving is what a clump of trees IS, and the
        plaza already had to take `TreesNear` off its hedge row for the same reason
        (a plan-view footprint test has no notion of the 2 m of air under a canopy).
        With trees in their own avoid list, clumps at 1.8-2.6 m spacing refused each
        other and 23 pieces were dropped — including four trees, which is the guard
        deleting content to prevent a non-problem.
        """
        e = self._extent(mesh_name, yaw, scale)
        return self._surfaces.footprint_is_clear(
            x + e[0], x + e[1], z + e[2], z + e[3],
            self._avoid if avoid is None else avoid)

    def try_place(self, place_fn, name, mesh_name, x, z, yaw=0.0, scale=1.0,
                  ladder=True, avoid=None, keep_out=False):
        """Places via `place_fn(name, mesh, x, z, yaw, scale)`, or skips.

        Returns True if the piece landed.

        `ladder` takes three forms, and choosing is a real decision:
          True      — the fine ladder. Props, scatter, anything that may drift
                      half a metre without meaning anything.
          False     — pinned. For a piece whose position is load-bearing (a
                      landmark, a fence run, a spawn-adjacent marker), where
                      moving it to dodge a bench is the wrong trade and a
                      reported skip is the honest outcome.
          a list    — your own offsets. `Placer.COARSE_LADDER` is the one for
                      building-sized pieces; see its note.
        """
        if ladder is True:
            steps = Placer.LADDER
        elif ladder is False:
            steps = [(0.0, 0.0)]
        else:
            steps = ladder
        blocked_by_box = False
        for k, (dx, dz) in enumerate(steps):
            # ⚠️ THE PLAY BOX IS CHECKED FIRST AND SEPARATELY FROM `clear_at`. A
            # piece that only fails the box test is not a graze against another
            # prop — it is in the wrong place entirely — and counting the two the
            # same way would hide a map full of evictions inside the ordinary
            # "nudged clear" number.
            if keep_out and self.in_play_box(mesh_name, x + dx, z + dz, yaw, scale):
                blocked_by_box = True
                continue
            if self.clear_at(mesh_name, x + dx, z + dz, yaw, scale, avoid):
                place_fn(name, mesh_name, x + dx, z + dz, yaw, scale)
                self.placed += 1
                if k:
                    self.nudged += 1
                return True
        if blocked_by_box:
            self.evicted += 1
        else:
            self.skipped += 1
            self.skips.append(name)
        return False

    def report(self, label):
        line = ("  %-14s: %d placed" % (label, self.placed))
        if self.nudged:
            line += ", %d nudged clear" % self.nudged
        if self.evicted:
            line += ", %d kept out of the play box" % self.evicted
        if self.skipped:
            line += ", %d SKIPPED (%s)" % (
                self.skipped, ", ".join(self.skips[:4]))
        return line


# =============================================================================
# ORIENTATION
# =============================================================================

def front_yaw(x, z, face_x=0.0, face_z=0.0, snap=True):
    """The yaw that turns a kit piece's FRONT toward (face_x, face_z).

    ⚠️ EVERY PIECE IN env_kit.gd FRONTS ON ITS OWN LOCAL -Z, measured 2026-07-29
    from the geometry rather than from the convention comment, which said +Z and
    was wrong. That single wrong comment cost Bayan Plaza three backwards
    landmarks: the church rendered as a blank grey slab in every shot ever taken
    of the map, and both basketball rings faced the tree line.

    Both builders then hand-derived the yaw at each site — Bayan Plaza's Landmark
    block still carries a nine-line comment doing the reasoning in prose, and
    Eskinita's house rows carry another. Two copies of one rule, in prose, is
    exactly the shape of the thing that was wrong in the first place. This is the
    rule as a function, so a caller says WHERE THE PIECE SHOULD LOOK and never
    thinks about the sign again.

    `snap` quantises to quarter turns, which is what a piece standing in a grid
    row wants; pass False for something aimed at an arbitrary point.
    """
    # ⚠️ DERIVED FROM THE BUILDERS' OWN BASIS AND CHECKED AGAINST TWO KNOWN-GOOD
    # CASES, because the obvious atan2 is off by a sign and the first version of
    # this line had it. Both builders emit
    #     Transform3D(c, 0, -s,   0, 1, 0,   s, 0, c,  ...)
    # so the X basis is (c, 0, -s) and the Z basis is (s, 0, c). A piece's front
    # is local -Z, which therefore lands on (-s, 0, -c). Setting that equal to the
    # unit direction d = (face - pos) gives s = -d.x and c = -d.z, i.e.
    # atan2(-d.x, -d.z) — NOT atan2(d.x, -d.z).
    #
    # Verified against the two cases env_kit.gd's header already establishes as
    # correct rather than against the algebra alone:
    #   a landmark at NEGATIVE z facing the plaza centre  -> d = (0, +1) -> PI  ✓
    #   a landmark at POSITIVE z facing the plaza centre  -> d = (0, -1) -> 0   ✓
    # The wrong sign passes both of those (atan2 of ±0) and fails only on the X
    # axis, which is exactly where Eskinita needs it and where the plaza never
    # exercised it. That is why this is a checked function and not a comment.
    yaw = math.atan2(-(face_x - x), -(face_z - z))
    if snap:
        yaw = round(yaw / (math.pi * 0.5)) * (math.pi * 0.5)
    return yaw
