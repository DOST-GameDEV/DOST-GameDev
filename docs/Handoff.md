# Handoff — Tumbang Preso

The one handoff doc. Design is in [`Tumbang_Preso_2v2_GDD.md`](Tumbang_Preso_2v2_GDD.md); the
plan, architecture, and build status are in [`Dev_Plan.md`](Dev_Plan.md); the fixed-bug forensic
archive is in [`Bug_Ledger.md`](Bug_Ledger.md). **This file is the work queue.** Read §0 for where
things stand right now, then §1 and §2, then start at the top of §4.

If you are the agent picking up the **M- block (3D modeling)**, start at
[`Design_Agent_Brief.md`](Design_Agent_Brief.md) instead — it is that block's self-contained
brief, and it carries the moodboard record and the code traps you will hit.

> **Note for the humans:** §1 (System Context) and §2 (AI Execution Protocol) are **frozen**. They
> are reproduced here unchanged, as every handoff must. Do not edit them without saying so out
> loud in a commit message.

---

## 0. Session log — where the project stands right now

**Pass date:** 2026-07-27 · **Type:** planning pass, no code written · **Branch:** `design-ui-models-and-fixes`
**Build on `main`:** v3.4 (`6f6d3b7`).

### 0.1 What this pass did

Rewrote §4 as the **Art, 3D Modeling, UI & Bugfix Execution Queue** — the next phase, after the
Q-1 → Q-10 review-feedback batch closed out at v3.4. **No code, scene, or asset was edited.**
Every claim below was checked against the actual files on `main` @ `6f6d3b7`, not against the
previous version of this document, because the previous two passes both found the docs claiming
things the code contradicted.

### 0.2 Repo housekeeping done first, and why

`main` was sitting at `a5ae79c` (v2.3) while **thirteen commits of finished work — v2.4 through
v3.4, +1704 lines — sat unmerged on `docs/execution-queue-pr-feedback`.** Every Q-item in the
last queue (pause freeze, YOU card, Guard/Dash meter, hit feedback, hazard footprint, Quit
button, match-result rebuild) was in that gap. Branching this pass off `main` as originally
instructed would have produced a plan describing work that is already done, and an overwrite of
this file would have silently reverted 1292 lines of Q-1 → Q-10 documentation on merge.

Resolved by fast-forwarding `main` to `6f6d3b7` and pushing, then branching
`design-ui-models-and-fixes` off it. **`main` is now the real tip.** Confirm with
`git log --oneline -1` before starting anything below.

### 0.3 The headline — the art gap is now the biggest risk on the project

Systems work is in good shape. `Dev_Plan.md` §1 has almost everything under Core Systems at `[x]`
or a well-understood `[~]`. What a judge actually sees is not:

| What is on screen today | What the moodboard specifies |
|---|---|
| One 40×40 grey box with grey walls | Eskinita (alley) and Bayan Plaza, a Philippine street |
| A 6-cylinder `CanVisual.tscn` primitive stack | A dented, knocked-down, impact-bursting **lata** with three readable states |
| A 4-box `TsinelasVisual.tscn` | A curved-sole slipper with a real Y-strap, spinning in flight |
| Kenney CC0 mini-characters, one `idle` clip of 32 wired | Chibi Filipino street kids in the moodboard's palette |
| A centred column of stacked `Label`s | Two role-coloured team panels, Bo5 pips, a framed timer, YOU / LATA cards |
| Godot's default font | A heavy hand-drawn unicase marker face |

**Three of the six rows are `[x]` in `Dev_Plan.md` §1.** They are honestly `[x]` — the *systems*
work — and they are all still placeholder-grade *art*. That distinction is what this queue exists
to close.

### 0.4 Camera directive — unchanged and not up for negotiation

**Person → FPP. Prop (Can/Tsinelas) → TPP.** Derived from `is_person`, no toggle, no override, no
exception. `camera_rig.gd` already implements this correctly and derives `_mode` in `_ready()`
from `_character.is_person` with no export backing it — that part is sound and must stay sound.

**But the directive is not actually enforced at the scene level yet.** `Main.tscn` still carries a
scene-level `Camera3D` running `arena_camera.gd`, with `follow_paths` holding four `NodePath`s
straight at the local-test characters. That is a direct violation of `Dev_Plan.md` §2's
architecture rule 4 ("the camera belongs to the character, not to the scene"), it is the node that
caused B-03, and B-58 (it still does full follow-cam maths every frame while retired) is open
because of it. **A-2 in §4 deletes it.** Until then the rule holds only because
`arena_camera.gd::_ready()` politely sets `current = false`.

### 0.5 Blocker — needs a human (carried over, still open, now costed)

🚧 **The moodboard display typeface is Harry's and was not supplied with the brief.** The theme
ships on Godot's default font. Palette, chrome, layout logic and type scale are all
moodboard-accurate; **only the typeface is standing in.** No substitute has been downloaded — an
unvetted font binary is both a licence and a supply-chain question, and Form 03 needs a recorded
licence either way.

This now blocks **F-2, U-1, U-2, U-3 and M-8** from being finishable, not just imperfect: the logo
lockup, the round banner, the match-result headline and the letter sheet on the moodboard are all
that one face. Two ways to unblock, in order of preference:

1. **Get the file from Harry's Canva project** (Canva → Brand Kit / the design's font list). One
   `.ttf`, one licence line on Form 03. Preferred — it is the actual brand.
2. **Ship an SIL OFL substitute** — **Luckiest Guy** is the closest to the moodboard's letter
   sheet; **Chewy** and **Titan One** are the alternates. OFL permits redistribution inside a
   game, so Form 03 is satisfiable. **Needs an explicit human yes before any font binary enters
   this repo.**

### 0.7 TASK 0 — the Slipper is now a thrown, retrieved object (2026-07-27, v4.0)

**Branch:** `design/mechanics-and-models` off `main` @ `3e423ed`. Note `main` was
at **v3.7**, not the v3.4 §0 above still claims — the M-2 pass landed ahead of
these docs.

**The diagnosis.** The human's verdict was *"this doesn't feel like tumbang preso
yet."* Confirmed in code, and architectural rather than cosmetic:

- `TsinelasVisual.tscn` is a `BoxMesh` of size `(0.52, 1.35, 0.16)` — a slipper
  standing on end, walking on a 1.6-unit capsule.
- The only thing called "Throw" was `person_action.gd`'s offence branch:
  `spawn_pulse_hitbox(c, 0.75, 0.2, false, Vector3(0, 0, -4.0))`. An invisible
  sphere blinking on 4m ahead for 0.2s. **Nothing left anyone's hands.**
- No carry state, no attach point, no held-object concept, no projectile, no
  pickup anywhere in the repo.

**The finding that settled it.** The moodboard already disagreed with the GDD.
Its **THE SLIPPER** card is the only one of the four with **no input badge**, and
its three illustrated states are *in-hand ready → thrown trajectory → retrieval
highlight* (§4.1 of `Dev_Plan.md`, and §1 of `Design_Agent_Brief.md`, recorded
independently). The art direction has described a thrown, retrieved slipper the
whole time; the GDD is the doc that was out of step. B-45 and B-46 stop being
open questions and become the spec.

**Agreed with the human: Option B — "a thrown object with a pilot."** Rejected:
*Option A* (attacking team = 2 Persons) would have flipped `is_person` per round
and therefore flipped that unit's camera mode, which breaks the standing camera
directive; *Option C* (projectile only, keep the walking Tsinelas) reads better
but leaves two slippers and still no scramble. **C is a strict subset of B**, so
the staging below is safe to stop at any point.

Also agreed: retrieval works **both ways** (the Person can grab it OR the slipper
can crawl home slowly, both taggable), and **B-46 is IN scope** for this pass.

**What is structurally untouched, and why that mattered to the choice:** 2v2, 1
Person + 1 Prop, `is_person` fixed for the match, the FPP/TPP camera directive,
Bo5, the role swap, `RoundManager`, and both Option A (dents) and Option B
(Downed→Seal) round wins. A thrown slipper hitting a lata goes through the
ordinary `Hitbox` path, so neither win condition needed a single branch.

### 0.8 What was NOT done this pass — READ THIS BEFORE PICKING UP

The pass ended early on budget, mid-queue. Landed work is real and runtime-smoke-
tested; everything else is untouched. Do not assume otherwise.

**Landed (v4.0, one commit):** T-1 and T-2 below — `carriable.gd`, `carrier.gd`,
`throw_profile.gd`, the three re-pointed Tsinelas abilities and their `.tres`
profiles, the `CharacterBase.tscn` nodes, and the new input actions.

**NOT started — the whole rest of the brief:**

- **T-3 · B-46 lata reset channel.** Agreed in scope, zero lines written.
- **Task 2 · the FPP viewmodel.** Still broken. `FppPivot` is still at `y = 1.55`
  in `CameraRig.tscn` (confirmed) while the scaled body tops out ~0.88, so the
  arms still hang low and behind the view. **The one thing the human called
  "highest-visibility" and it is untouched.**
- **Task 3 · arena layout / B-54.** `main.gd`'s `SPAWN_POINTS` still puts all
  four units within 3 units of origin. No base circle, no throwing line, spawn
  points still not in the map.
- **Task 4 · M-3, M-4, M-6, M-7, U-1, U-2.** Nothing. The tsinelas is still the
  four-box brick, and the HUD is still a centred column of Labels.
- **Docs.** `Dev_Plan.md` §1's Content rows and §4 are **still stale** — they
  describe the pre-Task-0 mechanic. The GDD carries a supersession banner and
  amended Sections 2 and 4, but Section 3's round flow was not revisited.
- **Nothing was pushed** if the push at the end of the session failed — see §0.9.

**Verification status of what DID land — be precise about this:** it loads clean
headless, and `Main.tscn` runs 200 frames with no runtime error, which is a
genuine runtime check rather than a `--quit` parse test (the distinction that
caught B-03). **But nobody has pressed a button.** No human has seen a slipper
carried, thrown, landed or retrieved. Every tuning number in it — charge time,
crawl speed, arc angles, `HAND_CARRY_OFFSET`, grab radius — is a first guess made
without ever looking at it in motion. Mark these `[~]`, never `[x]`, until
someone plays it.

### 0.6 What was NOT done this pass, and why

- **No code, scene, or asset was touched.** Planner role, by instruction.
- **The full B-01 … B-66 ledger was moved, not deleted.** It is verbatim in
  [`Bug_Ledger.md`](Bug_Ledger.md). §3 below carries only what is still open, plus the four new
  bugs found while reading code for this plan (B-67 … B-70). An overwrite that dropped the
  forensic record — including its several "the docs were stale, this was already fixed" entries —
  would have re-invited exactly the rewrites protocol rule 3 exists to prevent.
- **No font was downloaded.** See §0.5.
- **The Local Match harness was left alone.** It still goes in Phase 6 (§1).

---

## 1. System Context

**Project.** *Tumbang Preso* — a 2v2 LAN arena brawler for the Gear Up NCR Esports Game Dev
Challenge, built on the Filipino street game *tumbang preso*. Theme: Philippine Games and
Sports.

**Engine.** Godot 4.7, Forward+ renderer, GDScript only (no C#/.NET). Text-format `.tscn` and
`.tres`. Binary assets go through Git LFS.

**Shape of a match.** Two teams of two. Each team is **1 Person + 1 Prop**, where the Prop is a
Can (Lata) on defence or a Slipper (Tsinelas) on offence. All four units are player-controlled
and mobile. Teams swap Attacker/Defender role every round. 90-second rounds, best of five,
first to three round wins takes the match.

**Camera paradigm — a standing directive, not a preference.**

- **Person → FPP (first person), always.**
- **Prop (Can and Slipper) → TPP (third person), always.**

Derived from `is_person`; no toggle, no override, no per-map exception. This supersedes GDD
Sections 2 and 6 and the existing scene-level `ArenaCamera`. See `Dev_Plan.md` §0.1 and §3.

**Networking model.** ENet, LAN only, host + join by local IP. Host-authoritative for anything
that decides a round (hit resolution, timer, score). Client-authoritative for a peer's own
movement, replicated via `MultiplayerSynchronizer`. No reconciliation, no anti-cheat — LAN
prototype scope, deliberately.

**Local Match is a test harness.** `_start_local_test()`, the `p3`/`p4` input sets, and the four
hardcoded units in `Main.tscn` exist so one person can exercise the loop on one keyboard. **It
is stripped before submission.** Do not invest polish in it and do not let it shape the LAN
architecture.

**Two undecided design forks that block cleanup.**

- **Option A (dents) vs Option B (Downed→Seal).** Both are implemented behind
  `GameLaunch.game_mode`. Keeping both alive doubles the surface area of every combat change.
  The team has to pick one and delete the other.
- **Does the Person get its own ability roster**, parallel to the six Props, or does every Person
  share one Tag/Throw?

**Art direction.** `Mood Board.pdf` (Harry's Canva assets) is the visual source of truth.
Reference game called out on the board: **PEAK**. Chibi characters with oversized ball heads,
flat saturated colours, Filipino school-kid outfits. UI is deep navy on light blue-grey with a
blueprint grid, orange = offense, blue = defence, hand-drawn unicase marker display type.
Tokens are in `Dev_Plan.md` §4.2.

**Repo layout, git conventions, and the Godot setup walkthrough** are in `Dev_Plan.md` §6–§7.

---

## 2. AI Execution Protocol

For any coding agent picking up this queue.

1. **Work the queue in order.** §4 is sorted by dependency, not by size. P0 first. Do not skip
   ahead to UI because it is more fun — the LAN bugs gate everything, and three separate UI
   items are blocked on `team_id` landing first.
2. **Verify before you claim.** Every task has an *Acceptance* line. Meet it. If you cannot run
   the game to confirm, say so explicitly in the commit and mark the item `[~]`, not `[x]`.
   This project has a documented history of code that was written, reviewed, and never run;
   do not add to it.
3. **Report faithfully.** If something in this doc is wrong, say it is wrong instead of building
   around it. If a task turns out to be already done, say so and move on rather than rewriting
   working code. If you finish 8 of 10 items, say which 2 you did not do and why — do not
   silently narrow scope.
4. **Respect the architecture rules** in `Dev_Plan.md` §2. In particular: round-win logic stays
   out of `character_base.gd` and `hitbox.gd`; one `CharacterBase` scene with abilities as
   Resources; the host decides round outcomes; cameras are children of characters, never
   scene-level nodes holding `NodePath`s to players.
5. **The camera directive in §1 is not negotiable.** If any doc, comment, or older plan implies
   third-person for Persons, it is stale — fix the doc.
6. **One concern per commit,** with the bug ID in the subject (`Fix B-29: sync match state to
   late-joining clients`). Branch per feature off `main`. Keep `main` playable.
7. **Announce shared-scene edits.** `Main.tscn` and `CharacterBase.tscn` are touched by several
   queued items at once. Sequence them; do not run them in parallel.
8. **Duplicate ability Resources.** Cooldown state (`_time_since_use`, `_used_this_round`) lives
   on the `AbilityBase` Resource instance. Always `.duplicate()` a `.tres` per character or two
   characters share one cooldown.
9. **Update the ledger.** When a bug is fixed, mark it `**[FIXED]**` in §3 with a one-line
   description of the actual fix, and tick the matching box in `Dev_Plan.md` §5. When you find
   a new one, add it with the next free B-number.
10. **Do not delete Local Match yet** (§1) — it is the only way to playtest today. It goes in
    Phase 6.
11. **Debug-only code follows the removal contract** in `Dev_Plan.md` §0.3, without exception:
    `debug_`/`Debug` prefix on every file, class, node and autoload; debug code calls gameplay
    and **gameplay never calls debug** (no gameplay script may reference a debug class, autoload,
    signal or group — not even behind an `if OS.is_debug_build()`); no `[input]` map entries, read
    raw keys instead; self-disables in a release build; and a removal checklist written into
    `Dev_Plan.md` at the same time as the feature. A debug helper hiding inside a gameplay script
    is invisible to the verification grep and **will ship**. Reject it in review.

---

## 3. Bug & Issue Ledger

**Only open items live here.** B-01 … B-66 are in [`Bug_Ledger.md`](Bug_Ledger.md); everything
marked `[FIXED]` there is done and settled. New bugs take the next free number **in this file**.

### P0 — none open

The three P0 network soft-locks (B-62, B-63, and the B-01/B-03/B-29 cluster) are all fixed and
runtime-verified. See the archive.

### P1 — real, found this pass

**B-67 · In a release build, Local Match drives a different unit than the one you are looking
through. (NEW)** `Main.tscn` bakes `TeamAProp.player_id = 1` and `TeamAPerson.player_id = 2`, but
`main.gd::_start_local_test()` activates **`TeamAPerson`**'s `CameraRig`. In the editor this is
invisible: `DebugPlayerSwitcher.debug_register_bar()` immediately re-applies
`DEFAULT_P1_UNIT = "TeamAPerson"` via `_apply_slots()`, which rewrites `player_id` and papers over
the disagreement. **In a release build the switcher `queue_free()`s itself in `_ready()`
(`debug_player_switcher.gd:49`) and nothing ever rewrites those values** — so WASD moves the Can
while the camera sits in the Person's head, and the YOU card (which resolves by scanning for
`player_id == 1`, `you_card.gd:124`) confidently labels you `CAN (LATA)`. Three components each
behaving correctly in isolation, disagreeing about the same fact.
*Severity:* P1 — it only bites an exported build, which is precisely the build the judges run.
*Fix:* swap the two baked `player_id` values in `Main.tscn` so the scene's own defaults match
`_start_local_test()` and `DEFAULT_P1_UNIT`. One-line-per-node scene edit; no script change. See
**A-3**.

**B-68 · Round reset hands out spawn points by dictionary iteration order, not by join
index. (NEW)** `main.gd::_reset_world()` walks `_spawned_characters.keys()` with a local `index`
counter and assigns `SPAWN_POINTS[index % 4]`, discarding the stable `_peer_join_index` that B-21
introduced *specifically* so team and role assignment could not shift under a
disconnect/rejoin. `_reset_world` runs independently on **every peer**, so the moment two peers'
`_spawned_characters` insertion orders diverge — which a disconnect (`erase`) followed by a
rejoin (append) is enough to cause — the same character is reset to two different spawn points on
two different machines, and `spawn_position` (the KillPlane respawn target) diverges with it.
*Severity:* P1, latent. Needs a mid-match disconnect+rejoin to trigger, which is exactly what a
LAN demo does.
*Fix:* key the spawn point off `_peer_join_index[peer_id]`, not the loop counter. See **A-4**.

**B-69 · `_reset_world()` is two near-identical branches. (NEW — refactor, not a defect)** The
networked and local-test halves of `main.gd::_reset_world()` compute the same
`team_is_can_side` / `is_can` split, call the same `reset_for_new_round()`, and write the same
`position` / `spawn_position` pair, in ~50 lines of parallel code. B-10's fix had to be written
twice for that reason, and B-68 above exists in only one of the two halves. Collapse to one loop
over a `[character, team, is_person]` list built per mode. See **A-4**.

**B-70 · The build version stamp lies. (NEW)** `project.godot` reads `config/version="3.3"` while
`main` is at `6f6d3b7` — *"Make the debug player switcher discoverable in Local Match (v3.4)"*.
That commit touched only `docs/`, so the bump was skipped as a docs-only change, but the commit
subject still claims v3.4 and `GameVersion.attach_to()` stamps `v3.3` on the menu and the HUD.
The whole point of that stamp (§7) is that a playtester can name their build without diffing
files. Reconcile it in **F-1**.

**B-71 · Tracked `.import` UIDs regenerate on any cache rebuild. (NEW, low)** Opening the
project on a second machine rebuilt `.godot/` and reassigned
`assets/characters/persons/Textures/colormap.png.import`'s `uid://` — a tracked file, so it
surfaced as a permanent dirty working tree until committed (`5a2e0e0`). Nothing references that
texture by UID, so this instance was inert, but it will recur on every fresh clone and machine
switch, and it is exactly the kind of noise that makes a "regenerate and check `git status`"
acceptance test unreliable. *Decision owed:* either accept the churn, or stop tracking `.import`
UIDs. Not urgent; log it before it eats an hour of somebody's debugging.

### P1 — new this pass (Task 0)

**B-74 · A thrown slipper is frozen mid-air by the round-end input freeze.
(NEW, untested)** `character_base.gd::_physics_process` hands the frame to
`Carriable.physics_step()` **before** the `RoundManager.round_active` check, so a
slipper still airborne when a round ends keeps flying through the intermission
until `reset_for_new_round()` sets it LOOSE. Placement is deliberate (every peer
must run the carry maths, and the authority gate is below it) but the interaction
with the freeze was not thought through. *Severity:* P1, cosmetic-to-confusing,
never a wrong round outcome — `report_round_win` has already fired by then.
*Fix:* have `physics_step` no-op on FLYING while `not RoundManager.round_active`.

**B-75 · Nothing drops a carried slipper when its carrier is staggered, downed
or sealed. (NEW, untested)** `Carriable.host_drop()` exists and is correct, but
the only things that call it are a freed carrier and the round reset. A taya
tagging the attacker mid-carry therefore does not make them drop it, which is
most of the point of tagging. *Fix:* call `host_drop()` from the host when a
carrier's state leaves NORMAL. **Do this in `carriable.gd`/`carrier.gd`, not in
`character_base.gd`** — that file must not learn what carrying is.

**B-76 · The local-test flow gives every Prop `quick_stand.tres`, so no slipper
has a real throw profile. (NEW)** `main.gd`'s `PROP_ABILITY` is Quick Stand for
every networked Prop (B-04's stopgap), and `Main.tscn` hardcodes the same for
`TeamAProp`. Quick Stand has no `get_throw_profile()`, so every throw falls back
to `throw_default.tres` and **the three Tsinelas identities are unreachable in
game.** Not a defect in the new code — it is B-24's missing character-select
surfacing through it. *Fix:* character select, or an interim per-side default.

### P2 — open, carried over from the archive

- **B-13 · The match starts before anyone joins.** `_start_hosting()` calls `begin_next_round()`
  immediately. The lobby is the real fix — **U-4**.
- **B-42 · Local Bo5 past round 1 depends on the debug switcher.** Mitigated, not fixed: the
  switcher makes it playable, but the Prop that becomes the Can in round 2 is `player_id = 3`,
  permanently unbound. Dies with Local Match in Phase 6.
- **B-58 · `ArenaCamera._process` still does full follow-cam work every frame while retired.**
  Closed by **A-2**, which deletes the node outright.
- **B-54 · Local spawn points ignore team membership.** Design call. **M-7** puts spawn points in
  the map scene, which is where this gets answered.
- **B-55 · `RoundManager`'s end-of-round state change rides an unreliable RPC.** Low.
- **B-56 · `KillPlane` respawns on every peer, not just the character's authority.** Low.
- **B-57 · Under Option A, `forces_downed` is silently ignored on a Can.** Question, not a defect.
- **B-59 · Unreproduced: a completed match reset itself to round 1 / 0-0.** Watch for it.
- **B-23 · Dead code.** `RoundManager.round_won` and `Hitbox.landed_on` are emitted and unread.
- **B-25 · Option A / Option B interaction with `forces_downed`.** Dies when the fork is decided.
- **B-28 · No export presets, no build, no CI.** `export_presets.cfg` is gitignored. **This is on
  the critical path for B-67's acceptance test** — you cannot verify a release-build bug without
  a release build. See **F-3**.
- **B-45 · The moodboard's throw is charged and aimed; the code's is an instant fixed-range
  pulse.** **[FIXED]** v4.0 — `carrier.gd` implements a real hold-to-charge, camera-aimed throw
  that launches the slipper itself. No longer a design decision; it was the spec (§0.7).
  Untested by a human.
- **B-46 · The "Lata Reset Channel" is on the moodboard and in neither the code nor the GDD.**
  **Decision made — it is IN.** Agreed with the human this pass. **Not built.** See **T-3**.
- **B-65 · No reconnect path** — a rejoining player can come back as a different team and role.

### Doc corrections found this pass

Not bugs; fix them where they sit rather than logging B-numbers.

- `Dev_Plan.md` §4.3 says the Settings restyle "mouse sensitivity + invert-Y (§3.2) still not
  done." **Both are done** — `SettingsManager.mouse_sensitivity` / `invert_y` with persistence
  (`settings_manager.gd:52`, `:144`, `:162`) and a `SensitivitySlider` + `InvertYCheck` in
  `SettingsPanel.tscn`. Only the *restyle* is outstanding. Correct this in **F-4**.
- `Dev_Plan.md` §4.2 names a `PAPER` token that `ui_theme.gd` does not define — the nearest real
  constant is `CARD`. `you_card.gd:90` already carries a comment about tripping over this.
  Reconcile the doc to the code in **F-4**.

---

## 4. Immediate Execution Queue — Art, 3D Modeling, UI & Bugfix

Written 2026-07-27. **The Q-1 → Q-10 queue is retired**; all ten shipped, v2.4 → v3.4.

**Order is dependency order, not size order.** The `F-` block genuinely gates everything: setting
a base resolution *after* building screens means retuning every offset by hand, and the model
toolchain has to exist before any model can be built with it.

**Ground rules for this batch, on top of §2:**

- **Camera directive (§0.4) is inviolable.** No step below may add a mode toggle, a per-item
  override, or a camera that is not a child of its character. **A-1 and A-2 exist to make that
  structurally true rather than merely observed.**
- **The `[x]` in `Dev_Plan.md` §1 for "Character models" meant *the systems that swap models are
  done*, not *the art is finished*.** This batch replaces that art. The previous batch's "do not
  touch `assets/` or any model scene" rule is **lifted for this queue and this queue only** — it
  was scoped to a code-and-UI pass.
- **Every generated mesh is reproducible.** No mesh may be hand-edited into the repo as an opaque
  binary. Either it is a primitive composite in a `.tscn`, or it is an `.obj` emitted by a
  committed generator script (M-1). If a future artist replaces one with a real DCC export, that
  is a deliberate, reviewed swap — not the default.
- **Bump `application/config/version` in `project.godot`** in the same commit as any
  gameplay/UI/model/scene change. F-1 resets the counter to `4.0`; F-2 ships as `4.1`, and so on.
- **One concern per commit** with the task ID and, where one exists, the B-number in the subject.
- **`Main.tscn` is touched by A-2, A-3, M-7, U-1 and U-6.** Sequence them; do not parallelise.
- **`.tscn` merge conflicts are miserable.** Announce before starting anything in the A- or
  M- blocks.

---

### T — Tumbang preso mechanic (Task 0, Option B). START HERE.

This block outranks F-, A-, M- and U-. It is the reason the build did not read as
the game it is named after (§0.7). T-1 and T-2 landed at v4.0; the rest did not.

#### T-1 · The tsinelas becomes a thrown, retrieved object `[~]`

Landed, v4.0. `carriable.gd` (LOOSE / CARRIED / FLYING, host-authoritative),
`carrier.gd` (grab, charge, throw), `throw_profile.gd` + four `.tres` profiles.
`Carriable`/`Carrier`/`GrabArea` added to `CharacterBase.tscn`.

`[~]` **not** `[x]`: loads clean and runs 200 frames of `Main.tscn` with no
runtime error, but **no human has pressed a button.** See §0.8.

Things the next agent would otherwise re-derive:

- **Held state is deliberately NOT on `CharacterBase.tscn`'s
  `MultiplayerSynchronizer`,** even though that is less code. That synchronizer
  replicates outward from each character's OWN peer, so routing held state
  through it would make it client-asserted — the exact opposite of the
  requirement. Clients call `_rpc_request_*` on the host; the host decides and
  broadcasts `_rpc_set_*` with `call_local`.
- **The broadcasts are `"any_peer"`, not `"authority"`,** for the reason
  `CharacterBase._apply_hit_result` already documents: resolution runs on the
  host, but a slipper's multiplayer authority is its own owning peer, so an
  `"authority"` RPC sent by the host is silently rejected.
- **Carrying costs zero bandwidth.** Once every peer knows who is carrying, each
  recomputes the transform locally from that Person's hand.
- **`_step_carried` orthonormalises the hand transform.** A Person's model is
  scaled `PERSON_SCALE` (2.38) and bones inherit it — copying the transform
  wholesale inflates the slipper 2.38×, with no error.
- **The hand is a `Node3D` CHILD of the `BoneAttachment3D`, not the attachment
  itself.** `BoneAttachment3D` overwrites its own transform from the bone pose
  every frame, so an offset written onto it is silently discarded and the item
  sits at the elbow.
- **`get_hand_attachment()` returns null early in a match** — `CharacterVisual`
  instances the model from `CharacterBase._ready()`, so there is a real window
  where a Person exists and its hand does not. That is "not ready", not an error.

#### T-2 · Grab ownership — an opponent's slipper is solid but not grabbable `[~]`

Landed, v4.0, same commit. Enforced in exactly one place —
`Carriable.can_be_grabbed_by()` — built on the existing `CharacterBase.team`
(B-09). **No second team system.** Collision, hitboxes and the physics body are
never touched on account of who owns what: an opponent's slipper is still solid,
still kickable, still an obstacle, still staggerable by your bump. Only pick-up
is gated. Same `[~]` caveat as T-1.

#### T-3 · B-46 lata reset channel `[ ]`

**Agreed in scope with the human and NOT STARTED.** The defending Person (taya)
holds `grab` near a knocked-down lata to channel it back upright, on a progress
bar; interrupting the channel cancels it. `carrier.gd` is the right home — it
already owns "what this Person's hands are doing" and already reads the `grab`
action, and `Carriable.can_be_grabbed_by()` already returns false for a Can with
a comment pointing here. **Round-win logic stays out of `character_base.gd` and
`hitbox.gd`** — the channel calls `self_right()` (Option B) or clears a dent
(Option A) and nothing more.

#### T-4 · Retire the old fake throw `[ ]`

`person_action.gd` is now **Tag-only in effect** — `character_base.gd` gates the
ability press behind `not _carrier_is_holding()`, so an attacker with a slipper
gets the charge-throw instead. **But its offence branch is still in the file and
still reachable** for an attacking Person with no slipper in hand. Decide whether
that is a feature (a desperation lunge) or dead code, then either document it or
delete it. Its header was not updated — do that at the same time.

### F — Foundation (do these first; everything else assumes them)

#### F-1 · Set the base resolution and stretch mode, and reconcile the version stamp `[ ]`

**`Dev_Plan.md` §4.7 and §7 both say to do this before building UI. It has never been done —
`project.godot` has no `[display]` section at all.** Every `offset_*` in `MainMenu.tscn`,
`HUD.tscn`, `MatchResult.tscn` and `YouCard.tscn` was therefore authored against whatever window
size the editor happened to open at. Doing this after U-1 means retuning all of them twice.

Steps:

1. Add to `project.godot`:
   ```ini
   [display]

   window/size/viewport_width=1920
   window/size/viewport_height=1080
   window/stretch/mode="canvas_items"
   window/stretch/aspect="expand"
   ```
   `canvas_items` (not `viewport`) so text stays crisp at any window size; `expand` (not `keep`)
   so an ultrawide gets more arena rather than pillarboxes.
2. Open every existing UI scene at the new base size and confirm nothing has drifted off-screen
   or collided. Fix by anchor, not by nudging offsets — an offset fix re-breaks at the next
   resolution.
3. **Fix B-70.** Set `config/version="4.0"`. Reconciles the stamp with reality and opens this
   batch's numbering.
4. Add a line to `Dev_Plan.md` §6's "Build version" note: **a docs-only commit that names a
   version in its subject must still bump the file**, or the subject and the stamp disagree —
   which is exactly how B-70 happened.

**Acceptance:** launch, resize the window from 1280×720 to maximised. The main menu card stays
centred and legible at both; the HUD's top bar stays pinned to the top centre; no control leaves
the viewport. Menu and HUD both stamp `v4.0`.

**Commit:** `Set the 1920x1080 base resolution and stretch mode, fix B-70 (v4.0)`

---

#### F-2 · Land the display typeface `[ ]` ⚠️ BLOCKED ON A HUMAN

**Read §0.5 first. Do not download a font binary without an explicit yes in writing.** This is
the single highest-leverage change in the whole queue — it is the difference between "a Godot
project" and "the game on the moodboard" — and it is one line of code behind a licensing
question nobody has answered in three passes.

Steps, once a face is chosen:

1. `git lfs install`, then add to `.gitattributes` next to the existing binary rules:
   ```
   *.ttf filter=lfs diff=lfs merge=lfs -text
   *.otf filter=lfs diff=lfs merge=lfs -text
   ```
   **Commit the `.gitattributes` change before the font file**, or the first font lands as a raw
   blob and has to be rewritten out of history.
2. Drop the display face at `assets/ui/fonts/` alongside its licence file, verbatim, named
   `<font>_LICENSE.txt` — the same pattern `assets/characters/persons/KENNEY_LICENSE.txt`
   already uses.
3. A second face for body/caption text: a clean grotesque (**Inter** or **Work Sans**, both OFL).
   The marker face is a display face — it is illegible at `FONT_SIZE_CAPTION` 13.
4. In `ui_theme.gd`, add `DISPLAY_FONT` / `BODY_FONT` `preload()`s and set:
   - `theme.default_font = BODY_FONT`
   - `theme.set_font("font", "Display", DISPLAY_FONT)` and the same for `Heading`, `TimerDisplay`,
     `HudTimer`, `HudBanner`, `PrimaryButton`.
   Type variations only. **Do not reintroduce `theme_override_fonts` on individual nodes** — that
   is what `ui_theme.gd` exists to abolish.
5. Regenerate and commit both files: `godot --headless -s tools/regenerate_ui_theme.gd`.
6. Record the licence for **submission Form 03** and note it in `Dev_Plan.md` §4.2, replacing the
   "get the actual font file from Harry" paragraph with what actually shipped.
7. Delete the ⚠️ blocker note at the top of `ui_theme.gd` and §0.5 of this file. A stale blocker
   is worse than no blocker.

**Acceptance:** the main-menu title, the round banner and the match-result headline all render in
the marker face; every `Caption`-sized label is still readable. `assets/ui/fonts/` contains a
licence file for every binary in it. `git lfs ls-files` lists the fonts.

**Commit:** `Ship the moodboard display typeface and record its licence (v4.1)`

---

#### F-3 · A release export, so release-only bugs are testable `[ ]`

**B-28, promoted out of the backlog because B-67 cannot be verified without it.**
`OS.is_debug_build()` gates real behaviour in this codebase (the whole debug switcher), so "it
works in the editor" is not evidence about the build a judge runs.

Steps:

1. Create an `export_presets.cfg` for **Windows Desktop**, `Release` (not `Debug`).
2. `export_presets.cfg` is currently gitignored. **Un-ignore it** — it holds no secrets, and a
   preset that only exists on one laptop is not a build process. Verify no keystore path or
   password ended up in it before committing.
3. Add a `tools/export.md` note with the exact one-liner:
   `godot --headless --export-release "Windows Desktop" build/TumbangPreso.exe`
4. `build/` goes in `.gitignore`.
5. Run it once and confirm the `.exe` launches to the main menu.

**Acceptance:** a clean checkout plus the command above produces a running `.exe`. The debug bar
is **absent** in it (`debug_player_switcher.gd` self-frees), which is simultaneously the
acceptance test for the §0.3 removal contract and the reproduction case for B-67.

**Commit:** `Add a Windows release export preset and build note (v4.2)`

---

#### F-4 · Reconcile `Dev_Plan.md` to the code `[ ]`

Small, and it stops the next agent building against fiction. Docs-only; no version bump.

1. §4.2: rename the `PAPER` token to `CARD`, matching `ui_theme.gd`. Remove the stale
   `you_card.gd:90` workaround comment once it points at nothing.
2. §4.3: mark mouse sensitivity and invert-Y **done**; the row's remaining work is the restyle
   only.
3. §1: add a "3D art" block that separates *model-swapping systems* (done) from *model quality*
   (this queue). §0.3 above explains why that distinction keeps being lost.
4. §3.4: it offers "either delete the `Camera3D` node outright, or keep the script as a
   `BroadcastCamera`." **A-2 picks delete.** Rewrite §3.4 as a decision, not an option pair.

**Acceptance:** `grep -rn "PAPER" docs/ scripts/` returns nothing.

**Commit:** `Docs: reconcile Dev_Plan with the shipped theme, settings and camera decisions`

---

### A — Architecture and bugfixes (before art, so art isn't built on a moving floor)

#### A-1 · Enforce the camera rule structurally `[ ]`

The rule is currently obeyed by convention. Make it obeyed by construction, so no future pass can
break it without the build telling them.

Steps:

1. `camera_rig.gd::_ready()` already derives `_mode` from `is_person` with no export. **Keep it
   exactly as it is.** Add an `assert()` immediately after, stating the invariant in code:
   ```gdscript
   assert((_mode == Mode.FPP) == _character.is_person,
       "Camera directive: Person is always FPP, Prop is always TPP (Dev_Plan §0.1)")
   ```
   An assert compiles out of a release build and costs nothing, and it names the doc section a
   future reader needs.
2. `set_active()` and `set_aim_source()` are the only public entry points, and neither can change
   `_mode`. **Verify that stays true** — no new public method may take a `Mode`, and `_mode` must
   never be written outside `_ready()`.
3. Add the enforcement grep to `Dev_Plan.md` §3 as a standing check:
   ```bash
   grep -rn "_mode = \|Mode\.FPP\|Mode\.TPP" scripts/ | grep -v camera_rig.gd
   ```
   Anything it returns is a violation. It should return nothing.
4. **Crosshair, FPP only** (`Dev_Plan.md` §4.4: "Props (TPP) get no crosshair"). Add a
   `Crosshair` `Control` to `HUD.tscn`, centred, hidden by default. It must derive its visibility
   from the same source of truth as everything else — the locally-driven character's `is_person`,
   which `you_card.gd::_find_local_character()` already resolves for both modes. Expose that
   resolution as a small public helper rather than writing a third copy of the scan.
   **Do not add a `camera_mode` field to the HUD.** One derivation, one place.

**Acceptance:** the grep in step 3 returns nothing. Drive a Person in Local Match — crosshair
visible, first-person. Press Tab to take the Prop — crosshair gone, third-person. Play into round
2 so the Prop's `is_can` flips: still TPP, still no crosshair.

**Commit:** `Enforce the FPP/TPP directive in code and add the FPP-only crosshair (v4.3)`

---

#### A-2 · Delete the scene-level camera `[ ]`

**Closes B-58 and removes the last violation of `Dev_Plan.md` §2's architecture rule 4.** The
`Camera3D` in `Main.tscn` runs `arena_camera.gd`, caches four `NodePath`s to player nodes, and
does midpoint/spread maths every frame for a camera that is never `current`. It caused B-03. It
is dead weight that still has a way to hurt.

Steps:

1. Delete the `Camera3D` node from `scenes/main/Main.tscn`, and the `ext_resource` line for
   `arena_camera.gd` with it.
2. In `scripts/main.gd`, remove the `@onready var arena_camera` and **all six call sites**: four
   `remove_target()` calls in `_clear_local_test_characters()`, one in `_on_player_disconnected()`,
   one `add_target()` in `_build_networked_character()`. Read each one before deleting —
   `_clear_local_test_characters()`'s comment block documents B-03's residual fix and should be
   reduced to a one-line note that the camera is gone, not deleted wholesale.
3. **Move `scripts/systems/arena_camera.gd` to `tools/`**, do not delete it. `Dev_Plan.md` §3.4
   and GDD Section 6 both want a broadcast/spectator cam for the 3–5 minute demo video, and this
   is 100 lines of working framing maths. In `tools/` it is out of the gameplay tree, cannot be
   instanced by accident, and is still there when the trailer needs it. Add a header comment
   saying exactly that, and that if it ever returns it must register targets at runtime and
   `is_instance_valid()`-check every frame (§3.4).
4. Update `kill_plane.gd:6` and `character_base.gd:277`, whose comments both reference the
   ArenaCamera as if it were live.
5. Rewrite `Dev_Plan.md` §3.4 per **F-4** step 4.

**Acceptance:** `grep -rn "ArenaCamera\|arena_camera" scripts/ scenes/` returns nothing. A Local
Match and a two-instance `--host`/`--join=127.0.0.1` session both run with zero errors and a
working camera on every unit. Nothing renders from a fixed overhead angle at any point.

**Commit:** `Fix B-58: delete the retired scene-level camera, park the script in tools/ (v4.4)`

---

#### A-3 · Fix B-67 — Local Match drives the wrong unit in a release build `[ ]`

**Do not fix this by making `main.gd` or `you_card.gd` reference `DebugPlayerSwitcher`.** That is
protocol rule 11 and it is exactly the trap this bug sets: the tempting fix is to let gameplay ask
the switcher who is driving, and that is forbidden precisely because the switcher does not exist
in the build where the bug appears.

The disagreement is between `Main.tscn`'s baked values and `_start_local_test()`'s camera choice.
Fix the data, not the code.

Steps:

1. In `scenes/main/Main.tscn`: set `TeamAPerson.player_id = 1` and `TeamAProp.player_id = 2`.
   Two lines.
2. Update `main.gd`'s file-header comment, which still says *"the player controls TeamAProp (P1
   keys) and TeamAPerson (P2 keys)"* — the reverse of both the fix and
   `DEFAULT_P1_UNIT`/`DEFAULT_P2_UNIT`.
3. `debug_player_switcher.gd`'s `DEFAULT_P1_UNIT = "TeamAPerson"` already agrees. Leave it, and
   extend the comment at `:33` to note that the scene's baked values are now the fallback the
   release build actually uses, so the two must stay in step in **both** directions.
4. Do **not** change `_start_local_test()`. It is the one of the three that is already right.

**Acceptance:** run the F-3 release `.exe`, start a Local Match. The YOU card reads `PERSON`, the
view is first-person, and WASD moves the unit you are looking through. Then in the editor:
identical behaviour, and `Tab` still hands control over correctly.

**Commit:** `Fix B-67: release-build Local Match drove the Can from the Person's camera (v4.5)`

---

#### A-4 · Fix B-68 and collapse `_reset_world()` `[ ]`

Two concerns, one function, genuinely inseparable — the refactor is what makes the fix land in
both branches at once instead of only the networked one. Say so in the commit body.

Steps:

1. **Fix B-68 first, on its own, before touching the shape of the function.** In the networked
   branch of `main.gd::_reset_world()`, replace the local `index` counter with
   `_peer_join_index.get(peer_id, 0)`. That is the value B-21 introduced to be stable across a
   disconnect/rejoin, and it is already the value `_spawn_player()` uses to pick the *initial*
   spawn point — so this also makes round 2's positions agree with round 1's, which they do not
   today.
2. Then collapse the two branches (**B-69**). Build a single `Array` of
   `{character, team, is_person, slot}` — from `_spawned_characters` + `_peer_teams` +
   `_peer_is_person` when networked, from `_local_roster` with its fixed slot order otherwise —
   and run **one** loop that sets `team_is_can_side`, `is_can`, calls `reset_for_new_round()`, and
   writes `position` / `spawn_position`. The `RoundManager.clear_tracked_cans()` /
   `register_can()` pair collapses with it.
3. Keep the local branch's `if not _local_roster.is_empty()` guard.
   `_clear_local_test_characters()` empties that array, and a networked match must not fall
   through into the local path.
4. Do **not** change *when* `_reset_world` is called. It runs twice per transition on purpose
   (`_on_round_intermission_started` then `_on_match_round_started`) and is written to be
   idempotent — `character_visual.gd::apply()`'s `_current_key` early-out depends on that.

**Acceptance:** local Bo5 into round 3 — all four units return to spawn each round, same four
positions every time. Networked: three instances, disconnect a client mid-round, rejoin it, play
into the next round, and confirm every peer agrees on where every character is. Before the fix,
the rejoined peer's position differs between host and client.

**Commit:** `Fix B-68: round reset assigned spawn points by iteration order, not join index (v4.6)`

---

### M — 3D modeling

**Technical approach — decided, not open.** Three routes were considered:

| Route | Verdict |
|---|---|
| **CSG nodes** (`CSGBox3D`, `CSGCylinder3D`, boolean ops) | **Rejected for shipping geometry.** CSG rebuilds its mesh on the CPU whenever anything in the tree changes and is documented as a level-*prototyping* tool. Four characters plus a street's worth of props would put that cost on every frame for geometry that never changes. Acceptable to *block out* a shape in the editor; the result must be baked before it ships. |
| **Primitive composites in `.tscn`** (the current `CanVisual`/`TsinelasVisual`) | **Kept, for the shapes primitives genuinely nail.** Free, text-diffable, editable in the editor, zero toolchain. But a `CylinderMesh` cannot have a rim recess, a dent, or a curved sole — which is precisely what the moodboard's three can states and the tsinelas need. |
| **Hand-authored `.obj` + `.mtl`, emitted by a committed generator script** | **Chosen for everything primitives can't express.** `.obj` is plain text, so it diffs and merges like code, needs no LFS, and needs no Blender on anyone's machine. Godot imports it natively as a `Mesh`. Because a *script* emits it, the geometry is parameterised and regenerable — a dent depth or a can radius is a constant to change and re-run, not a modelling session to redo. |

**Persons are the deliberate exception. We are not modelling humans from scratch.** A human needs
a skeleton, skin weights and animation clips; `.obj` carries none of those, and hand-authoring a
rig is weeks of work this project does not have. The Kenney *Mini Characters* already in
`assets/characters/persons/` are CC0, already rigged, ship 32 animation clips, and are already
the oversized-ball-head chibi proportion the moodboard's character render shows. **M-5 restyles
them to the moodboard rather than replacing them** — palette retint plus small accessory meshes,
which is where the entire visual delta actually lives.

---

#### M-1 · The mesh generator toolchain `[x]`

**Landed v3.5.** `tools/models/obj_writer.gd` + `tools/models/generate_all.gd`, plus
`tools/models/preview.gd`/`preview.tscn` (frames a mesh at the 4.5-unit TPP distance).
Acceptance met: two consecutive runs are byte-identical and `git status` is clean after the
second. Imports as `type="Mesh"`, one surface per material, albedo exactly `UiTheme.DEFENSE`.

Three things the next M- task should know:

- **Winding was measured, not assumed.** Godot uses *clockwise* front faces and its `.obj`
  importer flips index order, so every face reads as inverted under the familiar
  counter-clockwise test. Godot's own `CylinderMesh` reports identically. `obj_writer.gd`'s
  header carries the warning — do not "fix" it by eye.
- **`_fmt` snaps before formatting.** `cos(3 * PI / 2)` is ~-1.8e-16 and printed as `-0.00000`,
  a different weld key from `0.00000`; the proof cylinder had 28 vertices instead of 26 until
  this was fixed.
- **No screenshot yet.** The geometry is verified mathematically (AABB, surface count, material
  albedo, winding vs. an engine primitive) but nothing has been rendered on screen. The preview
  harness exists and M-2 is where it gets proven, because that is the first mesh whose success
  criterion is "does it read as a can".

Original task text follows.

Nothing else in the M- block can start until this exists. Build it first, prove it on the
simplest possible shape, then use it.

Steps:

1. `tools/models/obj_writer.gd` — a headless-runnable `RefCounted` with:
   - `add_quad(a, b, c, d, material_name)` / `add_tri(...)`, accumulating verts, normals and
     faces with vertex de-duplication (an `.obj` with duplicate verts imports with no shared
     normals and shades faceted where it should be smooth — for this art style that is sometimes
     *wanted*, so make it a flag, not an accident).
   - `add_revolve(profile: PackedVector2Array, segments: int, material_name)` — the workhorse.
     Every rotationally symmetric object in this game (the can, its rim, a bollard, a tricycle
     wheel) is a 2D profile spun around Y. Segment count is the low-poly dial.
   - `add_extrude(outline: PackedVector2Array, height: float, material_name)` — the other
     workhorse: soles, signage, corrugated sheet.
   - `write(path) -> void`, emitting the `.obj` **and** a sibling `.mtl` with one `newmtl` per
     material name, `Kd` set from `UiTheme` constants so the models and the UI cannot drift apart.
2. `tools/models/generate_all.gd` — the single entry point, run headless:
   ```bash
   godot --headless -s tools/models/generate_all.gd
   ```
   It calls one `_build_*()` per asset and writes into `assets/models/`. **Deterministic:** the
   same script must produce a byte-identical `.obj`, or every regeneration shows as a diff and
   nobody will trust it. No `randf()`, no iteration over unordered keys, and format floats to a
   fixed precision (`"%.5f"`).
3. Add `assets/models/` to the repo. **`.obj` and `.mtl` stay text — do not add them to LFS.**
   That is the entire point of choosing the format. Add to `.gitattributes`:
   ```
   *.obj text
   *.mtl text
   ```
4. Godot's `.obj` importer: confirm each asset imports as a `Mesh` resource (not a scene) and
   that the `.mtl` colours survive. If they do not, the fallback is to assign a
   `StandardMaterial3D` in the visual `.tscn` and treat the `.mtl` as documentation — decide this
   **now**, on a test cube, not after twelve models exist.
5. Prove it: generate a single 12-segment cylinder, import it, put it in a scene, screenshot it.
   Then delete the test asset and move on.

**Acceptance:** `godot --headless -s tools/models/generate_all.gd` runs clean twice in a row and
`git status` is clean after the second run. That is the determinism test and it is not optional.

**Commit:** `Add the .obj mesh generator toolchain (v4.7)`

---

#### M-2 · The Lata (can) — three states `[ ]`

The moodboard's THE CAN card specifies exactly three: **standing (stable)**, **knocked down
(tilted, dented)**, **impact effect (particle burst)**. The third is already built
(`character_visual.gd::_spawn_impact_particles`, Q-8). This task builds the first two properly.

Current state: `CanVisual.tscn` is six `CylinderMesh` primitives — body, two rims, a band, and two
face discs. It reads as a blue tube. A real can has a recessed top, a rolled rim that overhangs
the body, a seam, and a slight taper.

Steps:

1. Profile-and-revolve the body in `generate_all.gd` via `add_revolve`, **16 segments** (12 reads
   as polygonal at TPP distance; 24 is wasted on a shape this small). Profile, bottom to top:
   base crimp → slight outward taper → straight wall → seam band step → shoulder taper → rolled
   top rim → recessed lid. Target **≈ 260 tris**.
2. **Materials, three, named for `UiTheme` tokens so `.mtl` and theme cannot drift:** `defense`
   (body, `#0080E8`), `highlight` (label band, `#F8D028`), `ink` (rim and lid, `#040838`). The
   moodboard's can is blue-bodied with a yellow label band — match it exactly.
3. **The dented variant.** A second `.obj` from the same profile with a radial displacement
   applied to a contiguous arc of the wall verts. Parameterise depth so Option A's three dent
   stages are three generated meshes (`lata_dent1/2/3.obj`), not one mesh scaled.
4. `CanVisual.tscn` becomes a thin wrapper: one `MeshInstance3D` whose mesh is swapped by dent
   count. **Wire the swap in `character_visual.gd`, not in `character_base.gd`** — that file owns
   every "how a unit looks" decision by design (see its header) and already listens for the state
   it needs. `CharacterBase` must not learn what a dent looks like.
5. **Knocked-down is a rotation, not a mesh.** `State.DOWNED` already exists and already drives
   the HUD flash. Tilt the `Visual` node ~75° on a tween. Keep it in `character_visual.gd` for the
   same reason as step 4.
6. Keep the existing height (1.13 units). `_align_to_capsule_floor()` measures the AABB at
   runtime, so a new mesh drops in correctly — **but re-verify it**, because that function is the
   one thing standing between a new model and a can hovering 20cm off the ground.

**Acceptance:** the can reads as a can from a TPP camera at 4.5 units. Take three dents in Option
A and the wall visibly deforms further each time. Knock it down: it falls to its side, and
self-rights on Quick Stand. Play into round 2 so the Prop swaps to Tsinelas and back — the mesh
follows and the dents reset.

**Commit:** `Model the lata — revolved body, three dent states, knocked-down tilt (v4.8)`

---

#### M-3 · The Tsinelas (slipper) `[ ]`

Current state: `TsinelasVisual.tscn` is a flat `BoxMesh` sole with two rotated box straps. It
reads as a blue brick.

The moodboard's THE SLIPPER card specifies **in-hand ready (glowing icon)**, **thrown trajectory
(spinning, motion blur)**, **retrieval highlight (arena floor decal)**. Only the mesh is in scope
here; those three states are U- and VFX work.

Steps:

1. `add_extrude` a proper slipper outline — wide at the ball of the foot, waisted at the arch,
   rounded at the heel — then displace the top verts into a shallow footbed dish and round the
   sole edge. **≈ 180 tris.**
2. The Y-strap as real geometry: two swept quad strips from the toe post to each side of the
   sole, meeting at a toe knob. Not two rotated boxes floating above the sole.
3. Materials: `defense` sole, `impact` strap (`#F468A8`), `highlight` toe post. This is what
   `TsinelasVisual.tscn` already uses and it matches the moodboard card — keep the palette,
   replace the geometry.
4. Keep the 1.35-unit length. Same `_align_to_capsule_floor()` re-verification as M-2 step 6.
5. **Orientation matters here in a way it did not for the can.** The character faces −Z
   (`character_base.gd`'s `look_at()`); model the slipper toe-forward along −Z so a thrown
   slipper spins around a sensible axis and the TPP camera sits behind the heel, not the side.

**Acceptance:** recognisably a tsinelas from any angle at TPP distance. Dash (LShift as the
Tsinelas) and it leads with the toe. Round-swap to Can and back and the mesh follows.

**Commit:** `Model the tsinelas — extruded sole, real Y-strap (v4.9)`

---

#### M-4 · Flat-shaded toon material pass `[ ]`

The moodboard and PEAK are both **flat, high-saturation, minimal gradient**. Godot's default
`StandardMaterial3D` under one `DirectionalLight3D` gives soft PBR falloff — the opposite look.
Doing this once at the material level is worth more than any individual model.

Steps:

1. A shared `assets/models/materials/toon.gdshader`: hard-stepped diffuse (2 bands), no specular,
   flat albedo. Keep it genuinely simple — a 2-band ramp is the whole look; a full cel-shading
   framework is not what this needs.
2. **Outlines.** Inverted-hull (a back-face-culled, slightly scaled copy in `INK`) is the cheap,
   reliable route and matches the moodboard's heavy-ink drawing style. Apply it to characters and
   hero props only, **not** to environment geometry — an outlined street is visual noise and
   doubles the draw calls on the largest meshes in the scene.
3. `WorldEnvironment` in `Main.tscn`: keep the sky-blue background, raise ambient so unlit sides
   do not go black. The current `ambient_light_energy = 0.6` is close; verify against real
   geometry, not the grey box.
4. **Do not apply this to the Kenney Persons yet.** M-5 handles them, and their glTF materials
   import as `ORMMaterial3D` — `character_visual.gd::_collect_meshes()` has a documented cast trap
   there (it duplicates as `BaseMaterial3D` and skips anything that is not one). A `ShaderMaterial`
   would be skipped by that same guard and **silently lose the hit flash**. Check that interaction
   before shipping shaders onto any character.

**Acceptance:** side-by-side screenshot, before and after, of the same scene. Flat saturated
colour, readable ink outlines on characters, no black unlit faces. The B-44 hit flash still
fires — this is the step most likely to break it.

**Commit:** `Add the flat-shaded toon material and ink outline pass (v5.0)`

---

#### M-5 · Persons — moodboard restyle, not a rebuild `[ ]`

Read the M- block header before starting. **We keep the Kenney rig.** The delta between what is
on screen and the moodboard's character render is palette and accessories, not topology.

Steps:

1. **Palette retint.** The two match Persons are `PERSON_MODELS[0]` (`male-f`) and `[1]`
   (`female-f`), indexed by team. Retint their imported materials toward the moodboard's
   character render — the yellow/green and the red/blue/orange outfits — while keeping the
   existing rule that made those two the defaults: they must read apart at arena distance on
   **hair value** and **outfit hue**. Do this via material overrides in a visual `.tscn`, not by
   editing the `.glb` (LFS binaries do not diff, and the CC0 source should stay pristine).
2. **Accessories, generated per M-1.** Small `.obj` meshes parented to the rig's head/body bones:
   a `tsinelas` pair on the feet (the game's own iconography, worn), and one silhouette-defining
   headwear piece per Person matching the moodboard render. Keep it to two or three pieces —
   silhouette reads at distance, detail does not.
3. **Team readability is not hue.** `Dev_Plan.md` §4.2's hard rule: orange/blue mean *role*, never
   *team*. Team identity is the A/B letter mark. So the Persons must be distinguishable from each
   other **without** using the role colours — hair and outfit, per step 1.
4. **Wire more than `idle`.** `character_visual.gd::_play_idle()` picks one clip of the 32 that
   ship. Units currently slide around in their idle pose, which reads as broken art more loudly
   than any modelling flaw. Add walk/run selection driven by horizontal velocity, in
   `character_visual.gd` — `CharacterBase` already knows its velocity and must not learn about
   clip names.
5. Leave `PERSON_MODELS[2..11]` alone. They are the character-select roster (U-5) and are fine as
   stock.

**Acceptance:** the two Persons in a match are distinguishable at 20 units without reading the
nameplate, and neither is orange or blue. Walking plays a walk cycle; standing still plays idle.
FPP self-hide still works (`camera_rig.gd::_apply_fpp_self_hide` re-applies on `model_changed`) —
a new accessory that is not under `Visual/` will render inside your own eyes.

**Commit:** `Restyle the Persons to the moodboard — palette, accessories, walk cycle (v5.1)`

---

#### M-6 · The environment kit `[ ]`

Modular, generated per M-1, on a **2-unit grid** so pieces snap and a `MeshLibrary` + `GridMap`
can assemble a map instead of hand-placing two hundred nodes.

Steps:

1. **Eskinita (alley) set** — the primary map, per GDD:
   `road_tile` · `gutter_tile` · `wall_plain` · `wall_corrugated` (the GI-sheet fence, the single
   most Filipino-reading piece in the set) · `sari_sari_store` front with a barred window ·
   `post_electric` with a drooping wire · `laundry_line` · `tricycle` (silhouette-grade, ~300
   tris) · `bollard` · `crate_stack` · `tire`.
2. **Bayan Plaza set** — the second map: `plaza_tile` · `bench` · `flagpole` · `planter` ·
   `church_facade` block · `basketball_ring` (mandatory; it is the actual Philippine plaza).
3. Every piece: flat materials from the M-4 shader, `UiTheme`-derived colours where it makes
   sense, **no outline** (M-4 step 2). Budget **≤ 400 tris** each — these get instanced dozens of
   times.
4. Export the kit as a `MeshLibrary` (the editor's Scene → Export As, or
   `mcp__godot-mcp__export_mesh_library`). Commit the `.meshlib`.
5. **Collision.** Generate a convex collision shape per piece at import, not by hand. A street the
   player walks through is worthless if they walk through the walls too.

**Acceptance:** every piece imports, snaps to the 2-unit grid, and has collision. Screenshot the
full kit laid out in a row.

**Commit:** `Model the Eskinita and Bayan Plaza environment kits (v5.2)`

---

#### M-7 · Build Eskinita as the first real map `[ ]`

This is the task that deletes the grey box. **Sequence it after M-6 and before U-1** — the HUD has
to be tuned against a real background, not a flat grey one, or every contrast decision gets made
twice.

Steps:

1. New scene `scenes/maps/Eskinita.tscn`: a `GridMap` using M-6's `.meshlib`, laid out as a narrow
   alley — long axis for chase, a widened middle for the can's base circle, side alcoves for
   cover. Keep the **playable area at roughly the current 40×40**; do not change arena scale in
   the same commit as changing arena art, or a movement-feel regression is unattributable.
2. **A `SpawnPoints` node holding four `Marker3D`s.** `Dev_Plan.md` §4.6 requires spawn points to
   come from the map, not from `main.gd`'s hardcoded `SPAWN_POINTS` array. This is the commit that
   makes that true: `main.gd` reads the markers if the map provides them and falls back to its
   constant if not. **This is where B-54 (spawn points ignore team membership) gets answered** —
   place them as two team pairs, opposite ends, and say so in the ledger.
3. **The can's base circle** — the game is named after it, and it is currently nowhere in the
   world. A floor decal in `UiTheme.HIGHLIGHT`, at the map centre, sized to the can's reset
   position.
4. Keep the existing `KillPlane`, the four `Bounds` walls (retextured or hidden behind real
   geometry), and the `HazardZone` instance — but reposition the hazard to something the map
   motivates (a mud patch, a gutter), and re-check it clears every spawn marker. Q-7's note still
   applies: `collision_layer = 0`, `collision_mask = 2`, `lifetime = 0.0`, and **do not** add it to
   the `hazard_zone` group or `_reset_world()` will free it every round.
5. `Main.tscn` instances the map instead of carrying `Floor`/`Bounds` directly. This is the step
   that makes a second map (Bayan Plaza) a scene swap rather than a rebuild.

**Acceptance:** a full Local Bo5 in Eskinita. Nobody falls through geometry, nobody gets stuck on
a prop, all four spawn markers are used, the base circle is visible, and the FPP Person can see
over the props well enough to aim. Frame rate holds — check it; a `GridMap` of 400-tri pieces is
cheap but the outline pass is not free.

**Commit:** `Build Eskinita — the first real map, with map-owned spawn points (v5.3)`

---

#### M-8 · The logo as a real asset `[ ]`

`MainMenu.tscn` renders the title as a text `Label`. The moodboard's logo is a finished lockup:
**TUMBANG** over **PRESO**, hand-drawn marker unicase, with the **O of PRESO replaced by a
top-down can lid** (dark ring, pull-tab). No font substitution reproduces that — the can-lid O is
drawn art.

**Depends on F-2 only for the fallback path.** If the real logo bitmap can be exported from
Harry's Canva project, that is the asset and no font is needed for it.

Steps:

1. Export the logo from Canva at **2048px wide, PNG with transparency**. `*.png` is already in
   LFS (`.gitattributes`), so `git lfs install` first.
2. `assets/ui/logo_tumbang_preso.png` + its `.import`. Set **Lossless** compression and disable
   mipmaps — it is UI, always drawn near 1:1.
3. Replace `TitleLabel` in `MainMenu.tscn` with a `TextureRect`, `expand_mode = KEEP_SIZE`,
   `stretch_mode = KEEP_ASPECT_CENTERED`. Keep `SubtitleLabel` as text below it.
4. Keep the text `Label` in the scene, hidden, with a comment — if the PNG ever fails to import,
   a missing title is a worse failure than an unstyled one.
5. **If the export is not available:** build the lockup from the F-2 face plus a generated can-lid
   glyph, and log it as a known deviation rather than shipping a plain text title.

**Acceptance:** the main menu shows the logo lockup at any window size from 1280×720 to
maximised, no aliasing, no stretch.

**Commit:** `Ship the logo lockup as a real asset (v5.4)`

---

### U — UI

All of these assume **F-1** (base resolution) and are much better after **F-2** (typeface) and
**M-7** (a real background to tune contrast against).

#### U-1 · Rebuild the HUD to the moodboard `[ ]`

`Dev_Plan.md` §4.4 has the target layout. The current `HUD.tscn` is a centred `VBoxContainer` of
five stacked labels plus the Q-5 YOU card — functional, and nothing like the spec.

Steps, in this order (each is independently verifiable; do not do them as one commit):

1. **Team panels, top left and top right.** Two `PanelContainer`s on the `OffenseCard` /
   `DefenseCard` theme variations, each carrying: the **A** or **B** letter mark, the side word
   (`OFFENSE`/`DEFENSE`), and **three Bo5 pips**. Colour by role, never by team (§4.2 hard rule) —
   the same derivation `match_result.gd::_on_match_won()` already does correctly; reuse its logic
   rather than writing a third copy.
2. **Bo5 pips replace `ScoreLabel`.** Three squares per team, filled by `MatchManager.team_a_wins`
   / `team_b_wins`. Delete `ScoreLabel` — "0 - 1" and a pip row saying the same thing is worse
   than either alone.
3. **Timer, centre top, framed.** Keep `TimerLabel` on `HudTimer`, put it in a card. Then the two
   behaviours §4.4 asks for and the code does not do: **`HIGHLIGHT` under 15s**, **pulse under
   10s** (a scale or alpha tween, not a colour flash — a flashing timer next to a flashing
   `DownedFlash` is unreadable).
4. **`RoundLabel` becomes `ROUND 3 / 5`,** all caps, under the timer. `RoleLabel` is now redundant
   with the team panels — **delete it**, and remove `set_round_display()`'s role half. Check
   `main.gd::_sync_state_to_late_joiner` and `hud.gd::_on_round_started`, both of which call it.
5. **YOU card, bottom left.** It exists and works (Q-5/Q-6). Anchor it properly at the new base
   resolution and give it the portrait §4.4 asks for.
6. **LATA card, bottom right.** Promote `DentLabel` into a real card: the dent pips (Option A) or
   the seal state (Option B), reading `GameLaunch.game_mode` as `hud.gd::set_dents` already does.
7. **`DownedFlash` becomes a vignette,** not a flat 25% red rectangle over the whole screen. A
   radial `ColorRect` shader in `UiTheme.DANGER`, transparent at centre. The current version makes
   the entire screen unreadable at the exact moment the player most needs to see it.
8. Keep the HUD reading autoloads directly (`Dev_Plan.md` §4.7) — that property is worth
   preserving and costs nothing.

**Acceptance:** at 1920×1080 and at 1280×720, the HUD matches §4.4's diagram. Win a round and the
correct team's pip fills. Play into round 2 and both team panels swap colour. Take the timer under
15s, then under 10s. Take three dents. Get downed — you can still see the arena.

**Commits:** split by step. Suggested: `Rebuild the HUD team panels and Bo5 pips (v5.5)` ·
`Frame the HUD timer and add urgency states (v5.6)` · `Promote the dent readout to the LATA card
and vignette the downed flash (v5.7)`

---

#### U-2 · Main menu and pause to the moodboard `[ ]`

The menu is already themed and has Play/Settings/Quit (Q-9). This is the **blueprint-grid card
chrome** the moodboard's role cards specify, which nothing in the project reproduces yet.

Steps:

1. **The blueprint grid.** The moodboard's cards are light blue-grey with a faint grid. Build it
   once as a reusable piece — a tiling `NinePatchRect` texture or a small shader — and put it
   behind `TitleCard`, `PlayCard`, `SettingsPanel` and the pause `Card`. **One implementation, in
   `ui_theme.gd` or one scene, not four copies.**
2. **The folded dark triangle, bottom-right of each card.** Small, cheap, and it is the detail
   that makes a Godot panel read as the moodboard's card.
3. **The keyword strip.** The moodboard's cards carry a bottom strip of letter-spaced all-caps
   keywords. Reproduce as a `Caption`-variation label row on the title card.
4. Logo from **M-8** replaces `TitleLabel`.
5. **Pause menu restyle** — same card chrome, `PrimaryButton` on Resume. It is currently the only
   screen still on bare defaults.
6. Keep the `GameVersion.attach_to(self)` build stamp. Keep every `Back`/`Esc` path
   (`Dev_Plan.md` §4.7: exitability is part of the definition of done, not a follow-up).

**Acceptance:** menu, play menu, settings and pause all carry the same card chrome. Every button
is legible against the background — this is the B-34/v1.3 contrast trap, and it is why F-1 comes
first. Esc works from every panel.

**Commit:** `Apply the moodboard card chrome to the menu and pause screens (v5.8)`

---

#### U-3 · The role-swap intermission card `[ ]`

`Dev_Plan.md` §4.6 specifies the beat and the timings. **The functional half already exists** —
`MatchManager.round_intermission_started`, a 3s gap, an early `_reset_world()`, and
`hud.show_round_banner()`. What is missing is the card. Do not rebuild the beat.

Steps:

1. New `scenes/ui/RoleSwapCard.tscn` + script, instanced in `HUD.tscn`. Driven by
   `MatchManager.round_intermission_started(next_round, next_team_a_is_can, can_team_won)` — the
   signal already carries everything needed.
2. Follow §4.6's timeline exactly: `0.0s` round-result banner · `1.2s` the swap card · `3.0s`
   world reset (already happens) · `3.5s` "ROUND N — FIGHT" wipe · `4.0s` next round.
3. **The panels physically slide across and recolour.** That motion is the whole point — a static
   card saying "roles swapped" is the text label that already exists.
4. Reuse `HUD.tscn`'s team panels from **U-1** rather than building second copies. If that proves
   awkward, that is a signal U-1's panels should be their own scene — extract them, don't
   duplicate.
5. `hud.gd::show_round_banner()` and `RoundBannerLabel` are superseded. Remove them in the same
   commit, and check `main.gd::_on_round_intermission_started`, their only caller.

**Acceptance:** win a round in Local Match. The banner, the swap, the wipe and the next round
happen on §4.6's timings, the panels visibly move and recolour, and the round starts with both
teams on their new sides. Networked: both peers see it and stay in step.

**Commit:** `Add the moodboard role-swap intermission card (v5.9)`

---

#### U-4 · The lobby `[ ]`

**Fixes B-13.** `_start_hosting()` calls `MatchManager.begin_next_round()` immediately — the match
starts before anyone has joined, which is why `_sync_state_to_late_joiner` (B-29) has to exist at
all. A 2v2 game with no lobby cannot be demoed to four people.

Steps:

1. `scenes/ui/Lobby.tscn` + `scripts/ui/lobby.gd`, entered from Host or Join instead of going
   straight to `Main.tscn`.
2. Peer list from `NetworkManager.connected_peer_ids`, live on `player_connected` /
   `player_disconnected`. Show team (A/B) and role (Person/Prop) per peer, from the same
   `index / 2` and `index % 2` derivation `main.gd::_spawn_player()` uses — **read it from one
   place**, do not re-derive it in the UI.
3. Ready-up per peer; host-only **Start**, disabled until every connected peer is ready.
4. The host's own address, displayed, so the other three can type it. Obvious, and currently
   absent.
5. Only the `begin_next_round()` call moves behind the Start button; `_start_hosting()` keeps
   hosting exactly as it does now.
6. **Do not attempt rejoin identity** (B-65). It needs a stable player token instead of a peer id.
   Note it and move on.

**Acceptance:** two instances. Host lands in the lobby, not a match. Client joins and both see the
peer list. Start is disabled until both are ready, then the match begins on both. Close a client
in the lobby — the host's list updates.

**Commit:** `Fix B-13: add the pre-match lobby with ready-up (v6.0)`

---

#### U-5 · Character select `[ ]`

Six Prop specials have `.tres` resources (B-24) and no way to choose between them. `main.gd`
hardcodes `PROP_ABILITY = quick_stand.tres` for every Prop, with a comment saying so.

Steps:

1. `scenes/ui/CharacterSelect.tscn`, between the lobby and the match.
2. Six Prop cards — Sardinas, Palayok, Bilao, Dyaryo, Bakya, Havaianas — each showing the
   ability's name, its `.tres`, and one line of what it does. Card chrome from U-2.
3. Persons pick from `PERSON_MODELS[2..11]`, the roster stock M-5 deliberately left alone.
4. Selection into `GameLaunch`, replicated to the host with the ready-up state, then read in
   `_build_networked_character()` **in place of the hardcoded `PROP_ABILITY`**. `.duplicate()` the
   chosen `.tres` — protocol rule 8, and the trap that comment already warns about.
5. **Answer the open question first** or this is unbuildable: *does the Person get its own ability
   roster, or does every Person share one Tag/Throw?* Listed in §5. If it is unanswered when this
   comes up, build the Prop half and say plainly that the Person half is blocked.

**Acceptance:** four peers each pick a Prop special, and each Prop's ability in the match is the
one it picked, on its own cooldown.

**Commit:** `Add character select for the six Prop specials (v6.1)`

---

#### U-6 · In-world nameplates and ground rings `[ ]`

`Dev_Plan.md` §4.5. The HUD tells you who *you* are (the YOU card, done). The world does not tell
you who anyone else is. **This matters more in FPP than any HUD element** — §3.3 accepts a
narrower awareness cone for the Person and promises exactly these as the mitigation.

Steps:

1. A `Nameplate` node on `CharacterBase.tscn`, under `Visual` **only if it must be hidden in
   FPP** — think this through, because `camera_rig.gd::_apply_fpp_self_hide()` sets
   `SHADOW_CASTING_SETTING_SHADOWS_ONLY` on every `GeometryInstance3D` under `Visual`, which would
   make a nameplate mesh invisible-but-shadow-casting. **Your own ring must not be hidden; your
   own tag should be.** Put them under different parents accordingly.
2. **Ground ring** — a flat decal in the team's *current role* colour. This is the primary read:
   works from any angle, in both modes, never occluded the way a floating label is.
3. **Floating tag** — `Label3D`, `billboard = BILLBOARD_ENABLED`, `A1`/`A2`/`B1`/`B2` plus a role
   glyph, fading past ~15m.
4. **Your own unit** gets a brighter ring and a chevron, so you can find your body after a
   respawn or a camera cut.
5. **Local test only:** the tag also shows the input set (`A1 · WASD`). Only meaningful with two
   people on one keyboard. **This must not reference `DebugPlayerSwitcher`** — resolve from
   `player_id` and `InputMap`, the same way `you_card.gd::_guard_dash_key_label()` already does.
6. Refresh colours on `MatchManager.round_started` — role colour flips every round. Same trap
   B-42, `debug_refresh_readout()` and the YOU card have each hit independently.
7. **Off-screen indicators** for your teammate and the Can — screen-edge arrows. §3.3 calls these
   mandatory for FPP. If this task is running long, this step is the one to split into its own
   commit, not the one to drop.

**Acceptance:** in a 2v2, every unit's team and role is readable from a Person's FPP camera
without opening the HUD. Your own unit is distinguishable from your teammate's. Roles swap and
every ring recolours. The FPP self-hide still hides your body and still keeps your shadow.

**Commit:** `Add in-world nameplates, ground rings and off-screen indicators (v6.2)`

---

#### U-7 · Settings and match-result polish `[ ]`

The tail. Both screens work; both are the last two on bare-ish styling.

1. `SettingsPanel.tscn` on U-2's card chrome. **The sensitivity slider and invert-Y already exist
   and already persist** (see §3, Doc corrections) — this is styling only, do not rebuild them.
2. Add a **Settings** entry to the pause menu. Q-9 deliberately left it out; with mouse
   sensitivity in the game, a player who cannot adjust it mid-match will quit to change it.
3. `MatchResult.tscn` — already the moodboard Bo5 grid (Q-4). Apply the card chrome and the M-8
   logo, nothing structural.
4. Every panel exits with `Back`/`Esc`. Re-verify after the chrome pass; a restyle that breaks a
   focus chain is easy to miss.

**Acceptance:** every screen in the game carries the same chrome. Settings opens from the pause
menu and a sensitivity change applies immediately, without leaving the match.

**Commit:** `Polish the settings and match-result screens (v6.3)`

---

## 5. Decisions the team owes

Blocking someone's work; a coding agent cannot resolve them. **Unchanged from the previous two
passes — none have been answered.**

- [ ] **The display typeface** (§0.5). Now blocking five queue items. **Most urgent.**
- [ ] **Option A or Option B.** Both alive doubles the cost of every combat change (B-25).
- [ ] **B-45 — charged/aimed throw** (per the moodboard) **or the current instant pulse?** FPP +
      mouse-look makes the moodboard version achievable and it is the better mechanic.
- [ ] **B-46 — is the "Lata Reset Channel" a real mechanic?** On the moodboard, in neither the
      code nor the GDD. Adopt it or cut it from the art.
- [ ] **Does the Person get its own ability roster,** or does every Person share one Tag/Throw?
      **Blocks U-5.**
- [ ] **Maps** — Eskinita + Bayan Plaza locked, Palengke as stretch. **M-7 assumes Eskinita is a
      yes.** Say so, or say otherwise before that task starts.
- [ ] **Title** — adopt the moodboard's **TUMBANG PRESO** (recommended; the logo is finished) or
      keep "Tumbang Laro: Isang Laban". **M-8 assumes the former.**
- [ ] **Ownership tables** — `Dev_Plan.md` §6 and GDD Section 8. Both still blank, fifth time of
      asking.
- [ ] **Circular Economy** as a secondary theme angle in the synopsis — free scoring upside.
- [ ] **Rejoin identity (B-65).** Needs a stable player token instead of a peer id.

---

## 6. Two things nobody has scheduled, both on the critical path

- **Real multi-device LAN testing.** Everything so far is loopback on one machine. Real wifi adds
  latency and packet loss to a movement layer with no interpolation and no reconciliation. If that
  forces the shared-screen fallback (GDD Section 7), you want to know weeks before the deadline —
  and the FPP/TPP split raises the cost of that pivot (four viewports, and only one player per
  machine can mouse-look). **Book four laptops now.**
- **Audio.** Still nothing, and it is deliberately not in this queue. A can hit with no sound
  reads as a bug to a judge no matter how good the mesh is. It is a parallel workstream and it
  needs an owner.

## 7. Working notes

- `.tscn`/`.tres` are text. Give a heads-up before editing `Main.tscn` or `CharacterBase.tscn` at
  the same time as someone else — A-2, A-3, M-7, U-1 and U-6 all touch one of them.
- `git lfs install` before adding any art, font, or audio. **`.obj`/`.mtl` are the exception —
  they stay text** (M-1 step 3).
- Ability cooldown/charge state lives on the Resource instance — always `.duplicate()` an ability
  `.tres` per character, or two characters share one cooldown.
- Combat networking is deliberately unvalidated: the host trusts client-reported bump timing.
  Fine for a LAN demo, out of scope to harden.
- **Build version.** Single source of truth is `application/config/version` in `project.godot`;
  `scripts/systems/game_version.gd` (`GameVersion`, a static-only `class_name`, not an autoload)
  reads it. Bump the minor number in the same commit as any gameplay/UI/model/scene change.
  **A docs-only commit that names a version in its subject must bump it too** — that is B-70.
- Adding a new `class_name` script requires a `godot --headless --import` pass before anything can
  reference it — the global class cache is only rebuilt on import, and until then every
  referencing script fails to parse with "Identifier not declared in the current scope". The same
  pass writes the `.gd.uid` sidecar, which this repo tracks.
- **Regenerating models is `godot --headless -s tools/models/generate_all.gd`, and it must leave
  `git status` clean** if nothing changed. If it doesn't, the generator is non-deterministic and
  every future model commit will carry noise.
