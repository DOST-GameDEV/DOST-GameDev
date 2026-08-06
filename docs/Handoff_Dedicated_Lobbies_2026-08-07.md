# Handoff — `online/dedicated-lobbies`, deploy state, and open items (2026-08-07)

**What this is:** where `online/dedicated-lobbies` actually stands right now — what shipped, what's
deployed, what's open on an unmerged branch, what's a known bug nobody has fixed yet, and what is
explicitly **not** going to happen (the cross-platform export). Written because the session that
produced all of this spanned several features, three separate branches, a live server redeploy, and
a large branch cleanup, and none of that is written down anywhere else in one place.

| | |
|---|---|
| **Branch** | `online/dedicated-lobbies` |
| **Currently equal to** | `origin/main` (`93ce21a`) — pushed as a fast-forward, see §5 |
| **Deployed** | Yes, `139.180.212.110`, at `93ce21a` — checksums confirmed matching |
| **Unmerged work waiting on top** | `fix/eskinita-plaza-props` (`cee4cf3`) — see §2 |

---

## 1. What's live, in commit order

All merged into `online/dedicated-lobbies`, deployed, verified with probes rather than assumed:

1. **Landed-slipper highlight** (`7a46381`) — a thrown tsinelas that's come to rest gets an
   inverted-hull outline in a colour you pick (Blue/Purple/Red/Yellow, or Off), settings-panel
   toggle, colourblind-safe palette. `tools/slipper_highlight_probe.tscn`, 36 checks.
2. **Dance emote** (`51b9bb6`) — replaced PLAY DEAD. The rig has no dance clip and nothing
   downloadable fits its 7-bone skeleton, so the clip is generated at runtime from sine terms
   against the bones that exist. `tools/emote_probe.tscn` covers it.
3. **Stun frost** (`3eed6d3`) — a tagged (STAGGERED) attacker ices over, visible to everyone;
   their own screen frosts at the edges, clear in the centre, receding as the stun ends.
   `tools/ui/frost_shot.tscn`.
4. **Tag-stunned-attacker fix** (`78150ab`) — `is_taggable()` was reading `can_act()`, which
   made a just-shoved (STAGGERED) attacker **immune** to the taya's tag — backwards, and it also
   meant `SCORE_SABOTAGE` had been unreachable since it shipped (the only thing that earns that
   credit is the shove that this bug then made untaggable). `tools/tag_stunned_probe.tscn`,
   validated against the reverted condition, not just the fix.
5. **Grab/shove double-fire fix** (`5e6cc1f`) — picking up a slipper could also fire a shove on
   the same frame, because `is_busy()` was never told a grab had just fired. Cost the player their
   shove cooldown and stamina for a press that only meant to pick something up.
   `tools/grab_shove_probe.tscn`.

Every one of these was verified by rendering the actual scene or driving a real match through a
probe — none of it is "should work," it's "rendered and confirmed." See each probe file's own
header for what it measures and why.

---

## 2. Open — `fix/eskinita-plaza-props`, not merged

Two commits, `cf996a6` and `cee4cf3`, sitting on top of `online/dedicated-lobbies`. Three asset
bugs, all confirmed by rendering the real maps rather than by reading a screenshot:

- **Basketball rim** (BayanPlaza) — the rim sat at the mesh's local origin, 0.32 m short of the
  backboard, with no bracket and no net. Pulled forward via `add_revolve()`'s own transform
  parameter, bracket and a stylised net added.
- **Sari-sari store "floating box"** (Eskinita) — the store was never misrotated; its front
  (counter, barred window, awning) is correct and correctly faces the court. Its **back** has zero
  detail (every fixture in `_sari_sari_store()` sits at negative local z only), and that back
  happens to sit ~0.6 m from `Poste_11`. Fixed by giving the back a small barred vent.
- **Cars removed from Eskinita entirely** — first pass dropped only the sedan and van (the two
  models named in the report, confirmed by their baked colour — neither is tinted, so "the red
  sedan" and "a blue van" identify the models, not one instance); a follow-up widened it to all
  five. The driveway *gaps* stay (fence + hedge dressing, so it reads as a driveway and not a
  hole) — only the vehicle mesh is gone.

**Not merged.** Needs `python3 tools/maps/build_eskinita.py` and `python3
tools/maps/build_bayan_plaza.py` re-run if anyone edits the map builders further before this
lands, and a redeploy is **not** required once it is merged — this is client-side assets and a map
scene, the server doesn't care what a slipper or a hoop looks like.

---

## 3. Known bugs, found but not fixed

Both surfaced as side effects of the stun-frost work and were flagged as separate spawned tasks
rather than fixed inline, because fixing them was out of scope for what was being worked on at the
time.

### 3a. A Person never flashes white when hit

`character_visual.gd::_collect_meshes()` sorts materials into two lists, and a Person's palette
material (`person_palette.gdshader`) qualifies for **neither**: it's a `ShaderMaterial` so it fails
the `BaseMaterial3D` branch, and it has no `flash_amount` uniform so it fails the shader-material
filter too. `flash_hit()` / `flash_blocked()` therefore write into two empty lists on a Person —
only the impact particles fire, the character itself never flashes. The shader's own header
documents how the flash is *supposed* to work via `albedo_color` as a blend target; that design is
intact, the collector's filter just moved to a uniform the palette shader doesn't have.

### 3b. Settings panel dies after the first BACK press

The panel is instanced once and hidden/shown, never re-instanced, so `_ready()` — including
`SettingsManager.begin_edit()` — runs exactly once per process. `_on_back_pressed()` calls
`revert_edit()`, which closes the transaction, and nothing reopens it. After the first BACK:
`has_unsaved_changes()` returns false unconditionally, so APPLY is permanently disabled, and every
setter writes `settings.cfg` immediately with nothing left revertible. Needs a re-entry point
(`visibility_changed`, or an `open()` both callers use) that calls `begin_edit()` and re-seeds
every control.

---

## 4. Pre-existing, not from this session

`tools/mech_probe.tscn` §2.16 fails on CROCS: the trajectory preview predicts z=0.03, the slipper
lands at z=0.32, 0.289 m apart against a 0.25 m tolerance. Confirmed byte-identical on the base
branch before any of this session's work — not a regression, just still open.

---

## 5. Deploy and distribution state

- **Server** is at `93ce21a`, matching `origin/online/dedicated-lobbies` and `origin/main`
  exactly (checksummed via `tools/server/deploy.sh`, not assumed).
- **`origin/main`** was fast-forwarded to `online/dedicated-lobbies`'s tip directly (`git push
  origin online/dedicated-lobbies:main`) rather than merged with a merge commit, since `origin/main`
  had zero commits `online/dedicated-lobbies` didn't already contain — verified before pushing.
- **The tracked build zips are stale.** `build/TumbangPreso-win64.zip` and
  `build/TumbangPreso-macos-UNTESTED.zip` are committed in git from `6dea881`, which predates
  every feature in §1 — no highlight, no dance, no frost, no tag fix, no grab/shove fix, no icon.
- **The macOS export needs an extra step that isn't automated anywhere.** Godot's macOS export has
  `codesign/codesign=0`, so the shipped `.app`'s `Contents/_CodeSignature` is missing entirely —
  not merely unsigned, genuinely malformed. Gatekeeper reports it as **damaged**, not "unidentified
  developer," and right-click → Open does **not** rescue that; only actually running
  `codesign --force --deep --sign - "Tumbang Preso.app"` after export fixes it (still not
  notarized, so a downloaded copy needs one right-click → Open past Gatekeeper — but at least it
  isn't reported as damaged).
- **The Windows icon got per-size treatment; macOS did not.** `.ico` carries the full bottle-cap
  art at 48px and up, and a cropped, bezel-free version at 16/24/32 (the ridged bezel was ~20% of
  the canvas at those sizes and the shoe read as a smudge). The macOS `.icns` still derives every
  size from the same full-logo `icon.png`, so the Dock at small sizes has the identical mush
  problem, unaddressed.
- **The user will not be exporting the game to both Mac and Windows.** Stated directly, 2026-08-07.
  Whoever picks up the next release build needs to do that export themselves — it is not something
  to assume is already covered, and the codesign step above is not optional if a macOS build ships.

---

## 6. Repo/branch state

A large stale-branch cleanup ran this session: ~40 branches deleted (local and origin) that were
either fully merged into `online/dedicated-lobbies` or pre-dated it by weeks with no unique content
worth keeping. Two branches could **not** be deleted — `claude/backup-branches-lobbies-esports-b362b6`
and `code/deploy-brief` — because the worktrees checked out on them (`networking-lan-review-3fae9a`,
`opus-orchestration-prompt-fb2b7a`) each have an uncommitted, untracked file sitting in them
(`docs/Handoff_Dedicated_Lobbies_Backup.md`, and two `.uid` sidecar files respectively) that were
never mine to discard. Still there.

`origin/NOCHARA` and `origin/ESPORTS` were deliberately left alone — the first for unclear purpose
(never confirmed abandoned), the second because it looks like active parallel work (it merged
`online/dedicated-lobbies` *into itself* the day before this cleanup).

**Commit attribution:** 65 commits across `origin/main` carry a `Co-Authored-By: Claude` trailer,
from three different human authors (`polandreei`, `StarRayX`, `M4tyu633`) — so this is not only the
repo owner's own commits. Removing the trailer from those 65 would mean rewriting all 711 commits'
hashes and force-pushing over `origin/main`, which is safe for the game itself (the server deploys
from plain files, not a git checkout, and nothing in the codebase reads a commit hash) but breaks
every other clone and in-progress branch built on the current history, including everyone else's
local checkouts. **Decision, 2026-08-07: not rewriting existing history.** New commits from this
point on omit the trailer.

---

## Working notes for whoever picks this up

**The two probes worth running before touching gameplay code again:**
`tools/tag_stunned_probe.tscn` and `tools/grab_shove_probe.tscn` both pin down real, previously
shipped bugs by reverting the fix and confirming the probe actually goes red — not just "it looks
plausible." Any future change to `is_taggable()`, `is_busy()`, or the shove/grab input path should
run both.

**Don't trust a screenshot for a map/asset bug without rendering it yourself.** Every one of the
three §2 reports looked, from a still image, like it could have been a placement or rotation bug.
None of them were — one was a camera-framing mistake in the diagnostic tooling itself, twice over
(a `SpectatorCamera` that reclaims `Camera3D.current` every frame, and a sign error that showed a
prop's back instead of its front). Load the real scene and move a camera to the object's own
transform before proposing a fix.

**A changed `.obj`/`.mtl` in `assets/models/` needs an explicit `godot --headless --path . --import`
before a probe or the editor will see it.** Godot's own file-watching did not pick up the change
during this session; a "fixed" mesh rendered as the old one until the import was forced.
