# Handoff — Tumbang Preso

The one handoff doc. Design is in [`Dev_Plan.md`](Dev_Plan.md); the
plan, architecture, and build status are in [`Dev_Plan.md`](Dev_Plan.md); the fixed-bug forensic
archive is in [`Handoff.md`](Handoff.md).

> ## 📋 Progress is tracked in ONE place: [`Checklist.md`](Checklist.md)
>
> **[`Checklist.md`](Checklist.md) is the ordered master list from where the project stands right
> now to a submitted entry.** Find the first unchecked box that is not marked 🧑 or ⛔ and that is
> the next thing to do. Every status table in this file, in `Dev_Plan.md` and in the GDD defers to
> it — if one of them disagrees, the checklist wins and the other is stale.
>
> **This file is the *detail* behind that list:** §0 is the session log, §1–§2 are the frozen
> system context and execution protocol, §3 is the open bug ledger, §4 is the task detail with
> acceptance criteria and **the model each task is routed to**, §5 is decisions the team owes.

If you are picking up a specific workstream, start at its **self-contained brief** instead — each
one names the model it should run on, the files to read first, its exact scope, what is explicitly
*not* its scope, and the traps already found in the code it touches:

| Brief | Workstream | Run on |
|---|---|---|
| [`Art_Direction.md`](Art_Direction.md) | 3D modelling — the `M-` block, meshes and the generator | Opus (design) / Sonnet (toolchain) |
| [`Art_Direction.md`](Art_Direction.md) | The maps, the dressed boundary, field markings, skyboxes | **Opus, high** |
| [`Agent_Prompts.md`](Agent_Prompts.md) | Carry / throw / grab / reset channel — playtest and retune | **Sonnet, high** |
| [`Agent_Prompts.md`](Agent_Prompts.md) | Charge meters, character select, off-screen indicators, typeface | **Sonnet, medium** |
| [`Agent_Prompts.md`](Agent_Prompts.md) | The entire audio workstream — **shipped 2026-07-29 (4.1)**, awaiting a listening pass | **Sonnet, medium** |
| [`Agent_Prompts.md`](Agent_Prompts.md) | Interpolation, rejoin identity, real-device LAN hardening | **Sonnet, high** |
| [`Agent_Prompts.md`](Agent_Prompts.md) | Trailer, demo video, synopsis, forms, demo-day script | **Opus, high** |

> **Note for the humans:** §1 (System Context) and §2 (AI Execution Protocol) are **frozen**. They
> are reproduced here unchanged, as every handoff must. Do not edit them without saying so out
> loud in a commit message.

---

## 0. Session log — where the project stands right now

### 0.15 CHECKLIST 2.9 — both hero props rebuilt to their own asset moodboards (2026-07-28)

**Lane:** 🎨 Design. **Lock:** `tools/models/generate_all.gd`, taken and released in this pass.
**Supersedes B-81's colour choice, not B-81's rule.**

The human supplied two asset moodboards — a worn brown flip-flop, and a low-poly
**Sarsi** can — and asked for both props to be built to them. Two steers arrived mid-pass and both
are on the record and acted on: *"u can reproduce sarsi logo, we have to showcase PH in this
project, js give credits"* and *"the magenta shit is just placeholder, we can update it with the
new ones."* The written record of both boards is `Art_Direction.md` §1b; the Sarsi credit is in
`README.md`. Full item breakdown in `Checklist.md` 2.9.

**The one thing the boards ask for that was not built** is printed type on the can — the wordmark,
`330 mL` and the barcode. Both boards are labelled "1024×1024 PBR"; the pipeline emits no UVs and
one flat `Kd` per material, and Harry's board's own reference (`PEAK`) is flat colour, not PBR. So
they were read for silhouette, proportion and colour blocking, and their texture maps were not.
Filed in §5 as a decision the team owes, with the argument for *not* building it.

#### Two things found while rendering this, neither of them fixed here

Filed rather than folded in, per `Concurrency_Protocol.md` §10.

1. **[CLOSED — B-105, fixed 2026-07-28.] The carried tsinelas is visibly detached from the hand.** This pass re-rendered the viewmodel probe as
   that item asked. `HAND_CARRY_OFFSET` is not the suspect it was framed as: the probe's own report
   prints `HandPoint` and `carried slipper` at **exactly the same coordinate**
   `(0.260, 0.600, -0.750)`, so the slipper is precisely where the code puts it. The problem is
   that `HandPoint` itself is nowhere near the Person's visible fist — in `viewmodel_tpp.png` the
   slipper sits up beside the head while the rendered hand is forward and lower. **So this is not a
   number to re-tune, it is an attachment pointing at the wrong place**, and the carry-tilt fix in
   `carriable.gd` was genuinely a different bug. Re-measuring `HAND_CARRY_OFFSET` against the mesh
   would not have found this; the render did.
2. **[FIXED 2026-07-28, checklist 7.1.] The prop ink outline is eating the props it outlines.** `outline.gdshader`'s `outline_width`
   defaults to **0.025** and nothing overrides it for Props (`character_visual.gd::_apply_toon_pass`
   applies the shader as-is; it returns early for Persons, so they never take this path). It
   inflates along the normal in **model space**, and the lata's mesh has `LATA_SCALE` **baked in**
   — so 0.025 is 0.025 *world* units on a can only **0.204 wide**, i.e. ~12% of the can's width per
   side. Visible in this pass's match render as dark slabs down both sides of the can. This is
   pre-existing and predates the re-livery, but it matters more now that the can carries livery
   worth seeing. It is also the exact hazard the environment-outline item (`Art_Direction.md` Part 1
   §6, item C) warns about, so **whoever takes that item should fix the prop width in the same
   pass** — a per-surface `outline_width` set from the mesh's own scale, not one constant for
   meshes that differ by 10× in size.

---

### 0.14 Peer-drop-mid-round — the live account (2026-07-28)

**Branch:** `code/networking`. **Lane:** 🔧 Build. **Checklist item:** 4.7 (new).

Pulled the cable for real rather than reading the code and guessing: a 4-peer LAN session (host + 3
`--join=127.0.0.1`), one join process hard-killed (`kill -9`, no graceful disconnect packet)
mid-round. Findings, all measured live, not assumed:

1. ENet detects the drop via its own peer timeout, **not instantly** — roughly 10-11 seconds after
   the process died in this environment. A hard kill sends no FIN; nothing faster was attempted
   (that would mean lowering ENet's own timeout).
2. `main.gd::_on_player_disconnected` fires on **every remaining peer**, not just the host — each
   one frees its own local copy of the departed character; host-side only, shows "A player left the
   match" and re-registers tracked Cans.
3. **The disconnected unit does not become a frozen obstacle. It is deleted outright** —
   `queue_free()`'d and erased from every peer's own tracking dictionaries. Nothing stands in for
   it: no AI, no ragdoll left lying around, nothing a remaining player can interact with.
4. **If the disconnected peer was the tracked Can:** `RoundManager._tracked_cans` goes empty.
   `_on_tracked_can_state_changed`/`_on_tracked_can_dents_changed` both early-return on an empty
   list, so tag-to-win, the 5-fall cap, and Option A's dent count all go **completely inert** for
   the rest of that round. The round can only end one way from there: the 90-second timer, which
   **always resolves to a Cans-side win** (`RoundManager._on_time_up()` → `report_round_win(true)`
   — "Cans win on timer expiry," true under both Option A and Option B) **regardless of whether a
   Can is even still present.** A Can-side disconnect mid-round silently guarantees the round for
   the defending team once the clock runs out, with no way for the offense to contest it.
5. **If the disconnected peer was the attacking Person or the Tsinelas Prop** (the thrown object
   itself — the same CharacterBase the attacking side's slipper actually is), offense loses its
   only means of winning that round too: nobody left to throw, or — if the Tsinelas player
   specifically drops — the slipper object itself is deleted mid-flight or mid-carry, whatever it
   was doing. Same resolution: timer expires, Cans win.
6. **If the disconnected peer was the defending Taya**, tag-to-win becomes unreachable for that
   team, but the Can itself is still tracked — Option A's dents and Option B's fall-cap/auto-seal
   still apply from throws the offense lands, so this is the one drop that does **not**
   automatically hand the round to one side.
7. **No crash, in any of the above** — but building this test surfaced and fixed two real,
   previously-unreachable UI crashes along the way. See **B-100** and **B-101**, and `Checklist.md`
   4.2's own entry.

**Not done, explicitly out of scope for this pass:** any actual mitigation (a bot taking over an
abandoned role, a grace window before the round auto-resolves, ENet timeout tuning). This is the
truth on record, not a fix — `Checklist.md` 4.7 is `[~]`, deliberately, because the question asked
("what happens") is answered but the underlying UX gap is not closed.

---

### 0.13 Solo-host quality of life — pause and the debug switcher (2026-07-28)

**Branch:** `code/networking`. **Lane:** 🔧 Build. **Checklist item:** 4.6 (new). Own commit, per
the lane's own instructions — a `NetworkManager` semantics change.

The first playtest was run by HOSTING, not Local Match (see `Art_Direction.md`'s "Playtest
findings, 2026-07-28" section), and found two things silently no-op in a networked match on purpose: `get_tree().paused` (Q-3/B-64
— a client pausing its own tree stops sending movement while the host keeps simulating it, and the
host can't stop an authoritative timer for everyone over one player's Esc) and the whole debug
player switcher (each peer owns exactly one character; reassigning `player_id` grants no control).
Both restrictions are real for an actual 2+ peer match and pointless when there is nobody else in
the session to protect — exactly the case of testing alone by hosting.

New `NetworkManager.is_solo_session()`: `is_networked() and connected_peer_ids.size() <= 1`.
`main.gd::_on_pause_toggle_requested()` now takes the real-freeze branch (the same code path Local
Match already used) whenever `not is_networked() or is_solo_session()`, instead of only when
`not is_networked()`.

`debug_player_switcher.gd::_is_active()` now also returns true for a solo networked session — but
**not** by making unit-switching work: a solo Hosted session only ever spawns ONE real character
(`main.gd::_spawn_player` runs once per actually-connected peer, and there is no bot/placeholder
system to fill the other three roles — see 4.7), so there is nothing to Tab to regardless of this
gate. What was actually broken and is now fixed: the on-screen `DebugBar` used to show
`TeamAPerson (missing) / TeamAProp (missing)` the instant you hosted alone, because it was still
looking for the four LOCAL-TEST node names (`_clear_local_test_characters()` had already freed
them) instead of the real networked spawn. New `_solo_networked_unit()` walks the actual `Players`
node (`MultiplayerSpawner.spawn_path`) for the character whose authority is this machine's own
peer, and the readout now correctly describes it. `player_id`/camera reassignment is deliberately
left untouched for this unit — `main.gd`'s spawn already assigned the right `player_id` and
`camera_rig.gd`'s own `_ready()` already activates the right rig from `is_multiplayer_authority()`;
re-driving either here would be redundant at best.

**Verified by running:** two real `--host`/`--join=127.0.0.1` sessions (one while solo, one once a
second peer joined), 600+ frames each, no output — the `DebugBar`/switcher code paths run every
frame regardless of whether anyone is looking at them, so a clean multi-hundred-frame run is real
evidence they don't error, in both the solo and non-solo states. **Not verified:** a human actually
pressing Esc and confirming the overlay visibly freezes, or reading the `DebugBar` text off a
running window — this project's norm is that an unverified interactive claim is not written up as
felt, only as run.

---

### 0.12 Netcode pass — remote movement interpolation and rejoin identity (2026-07-28)

**Branch:** `code/networking`. **Lane:** 🔧 Build. **Checklist items:** 4.2, 4.3. Two bugs found
and fixed along the way — see B-100/B-101 below.

**4.2 — remote movement interpolation.** `character_visual.gd` now lags a world-space copy of the
body's position/yaw behind at `REMOTE_SMOOTH_RATE` and renders the `Visual` node from that, for a
non-authority networked character only — the body itself keeps snapping exactly as replicated,
since collision, the Hitbox offset and every directional ability read it directly
(`Agent_Prompts.md`'s Netcode brief §3). Explicitly skipped (not smoothed toward a no-op, just
never entered) for the locally-driven character, Local Match, and a CARRIED/FLYING slipper — the
last of those is already recomputed identically on every peer by `carriable.gd` at zero bandwidth,
and lagging an already-agreed transform would make it visibly trail the hand or the arc. Teleports
(a round reset, a KillPlane respawn) snap rather than glide via a new
`CharacterBase.snap_visual_interpolation()`, called from `respawn()` and `main.gd::_place_at_spawn()`.
Verified by running two real `--host`/`--join=127.0.0.1` instances (not headless — interpolation
needs `_process()` to actually run frames) for 600+ frames each, silent both times.

**4.3 — rejoin identity (B-65).** The identity half: `NetworkManager.local_player_token`, a random
128-bit token minted once per running process, presented to the host via a new `_rpc_identify` RPC
on every connect; `main.gd`'s join-index map is now keyed by that token instead of the ENet peer
id, so a reconnect under a new peer id lands back on the same team/role. **Deliberately not
persisted-and-reloaded from the `user://` copy it also writes** — this project's own two-instance
test (`Debug > Run Multiple Instances`, or two `godot --path .` processes) shares one `user://`
between "players," and reading the token back would make both instances present the identical
token and collide on the same join index. Measured live, not assumed: this was the first version
tried, and it broke the two-instance test exactly this way before the fix.
The harder half, not obvious from the checklist's own one-line framing: a rejoining peer had
**nowhere to go**. Host/Join both gate behind `Lobby.tscn`, and the host has already left it for
`Main.tscn` by the time a rejoin is even possible — the rejoining peer's own `Lobby.tscn` connects
fine and then waits forever for a Start press the host can never send again. Fixed with
`NetworkManager.match_in_progress` (host-only, set by `main.gd::_start_hosting()`) and a new
`_rpc_route_to_running_match` RPC that redirects a peer identifying after the match has started
straight into `Main.tscn`, plus a `_rpc_client_ready_for_spawn` ping (sent once that peer's own
`Main.tscn`/`MultiplayerSpawner` actually exists) so the host never races a spawn against a scene
that hasn't finished loading on the receiving end. **Verified live:** host + one join (distinct
tokens, sequential join indices, no errors); separately, two *sequential* join processes forced to
present an identical token (simulating a reconnect) — the host reassigned the exact same join
index to both, under two different peer ids. **Not verified:** an actual mid-process ENet
drop-and-rejoin from one still-running client (the test above kills and restarts the process
rather than reconnecting in place) — that is 6.1's job, on real hardware.

**Two real bugs found and fixed while building the multi-instance test rig this pass needed, both
in files this lane owns, neither previously reachable without an actual live multi-peer session —
see B-100 and B-101 below.**

---

### 0.11 CHECKLIST 1.2 — prop scale decided: hero-scaled props, carried-scale tsinelas (2026-07-28)

**Branch:** `art/prop-scale-and-kit`. **Lane:** 🎨 Design. **Supersedes nothing** — 1.2 was open,
never answered. `Art_Direction.md` §7 and `Checklist.md` 1.2 both carried option (a)
as a *recommendation*; this section is the decision, the numbers, and the reasoning.

#### The diagnosis, verified by render and not by arithmetic

Measured from the committed `.obj` files and confirmed in-engine with
`tools/render_probe.gd` (viewmodel mode, real rendering device):

| | Measured | vs. a 1.598-unit Person | Real-world equivalent |
|---|---|---|---|
| Person (Kenney, `PERSON_SCALE` 2.38) | **1.598** tall | — | ~165 cm |
| Person head-mesh alone | **0.781** tall | 49% | — |
| Lata | **1.125** tall, 0.68 across | **70%** | a can is ~7% |
| Tsinelas | **1.350** long, 0.52 wide, **0.165** thick | **84%** | a slipper is ~17% |

The render settles what the numbers only suggest. A Person holding the tsinelas does not read as a
person holding a slipper; it reads as **a toddler holding a blue surfboard**, and in first person
the slipper eats roughly a quarter of the screen as an untranslatable blue slab. The lata, by
contrast, **reads correctly as a can** at the same distance and needs nothing.

So the problem is narrower than "prop scale". It is one case: **the tsinelas while carried.**

#### What the human asked for, and what it actually means

Mid-pass steer, verbatim: *"make humans bigger, objects should fit in hand."*

Those are a mechanism and an outcome, and only the outcome is load-bearing. Visually nothing
distinguishes "make the human bigger" from "make the object smaller" — only *relative* proportion
reaches the screen. **"Objects should fit in hand" is adopted as the acceptance criterion for this
item, in exactly those words.** The mechanism chosen to deliver it is the cheap one, for the
reasons below, and the literal larger-Person option is costed and kept live rather than dropped —
see *The option that stays open*.

#### The decision

**(a) — props stay hero-scaled as units; the tsinelas is scaled down ONLY while `CARRIED`.**

- `TSINELAS_CARRY_SCALE = 0.32`, applied to the `Visual` node, giving a carried slipper
  **0.432 units long — 27% of the Person's height**, against 84% today.
- Chosen, not split-the-difference: the true ratio is 17% and hero scale is 84%. 27% sits
  deliberately at the stylised end, because the moodboard's whole language is chibi exaggeration
  (a head that is half the body). At 0.432 the slipper is ~55% of the Person's own head — the one
  proportional anchor a viewer reads instantly — which is "a big slipper, held", not "a surfboard".
- **Acceptable tuning window without coming back to this lane: 0.28 – 0.40.** Outside that, reopen
  the item.

#### Alternatives considered and rejected

- **(b) Scale the props toward plausible size and retune around them.** Rejected. Both the lata and
  the tsinelas are **player-controlled units inside a 1.6-unit capsule with a TPP camera at ~4.5
  units.** A 0.11-unit lata is not a character; it is a speck with a spring arm pointed at it, and
  it drags in the capsule, the hurtbox (`CapsuleShape3D` r0.4/h1.6 and r0.45/h1.7), every
  `hit_radius` in the four throw profiles, the grab radius, and the TPP distance. It also
  contradicts the board, which gives **THE CAN** and **THE SLIPPER** their own role cards with the
  same weight as **THE ATTACKER** and **THE DEFENDER** — in this game's fiction the can and the
  slipper *are* characters. And decisively: it retunes movement feel **immediately before checklist
  0.4, the first time a human will ever have played this**, which would make 0.4's notes
  unattributable to either the mechanic or the rescale.
- **(c) Raise `PERSON_SCALE` — the human's literal suggestion.** Rejected *for now*, on cost, not on
  merit. `PERSON_SCALE` is visual-only, so raising it desynchronises the model from the 1.6 capsule
  that governs its collision: at 2.85 the Person stands 1.913 tall and its head clears the capsule
  by 0.31. That drags in the capsule height, the hurtbox, `FppPivot` (eye height would move from
  +0.45 to ≈ +0.85 — reopening B-78's exact failure class), `HAND_CARRY_OFFSET`, the TPP spring
  arm, and the arena's read at fixed movement speed. It is (b)'s cost with a different sign, and it
  lands in **shared and build-lane files** (`CameraRig.tscn`, `CharacterBase.tscn`). Kept live —
  see below.
- **(d) Shrink the lata too, for consistency.** Rejected. The lata renders correctly today
  (screenshot in this pass). Changing what reads right, to match a rule that only the tsinelas
  breaks, is churn.

#### What changes, and what explicitly does not

**Changes** — all cosmetic, all in one file, none of it mine to implement (see the handover):

- `character_visual.gd` gains `TSINELAS_CARRY_SCALE` and lerps `self.scale` toward it while the
  sibling `Carriable` reports `CARRIED`, and back to `Vector3.ONE` otherwise.
- `HAND_CARRY_OFFSET` needs a matched retune. **Predicted, not measured:** the model's sole sits at
  CharacterVisual-local `y = -0.8` (dropped there by `_align_to_capsule_floor`), and scaling about
  CharacterVisual's origin lifts it to `-0.8 × 0.32 = -0.256`, so the slipper will float **≈ 0.544
  units higher in the hand** than it does now. Compensating drops `HAND_CARRY_OFFSET.y` from
  `+0.21` toward `≈ -0.33`. That is a starting point to be **confirmed by render**, not a value to
  paste in.

**Does not change — and this is the entire reason (a) is the contained option:**

- No `CollisionShape3D`, no `Hurtbox`, no capsule, no `hit_radius`, no grab radius, no
  `CRAWL_SPEED_SCALE`, no `SPEED`, no camera distance, no `FppPivot`, no arena scale.
- Not the mesh. `assets/models/tsinelas.obj` and `_build_tsinelas()` are untouched, so the LOOSE
  and FLYING slipper — the thing you scramble for and the thing that hits the lata — stays
  hero-scaled and stays readable at range. **Only the hand is small.**
- `_align_to_capsule_floor()` is unaffected: it computes in CharacterVisual-**local** space from
  `model.scale`, not from this node's scale, so a rebuilt model still lands on the capsule floor.

#### Why a per-frame lerp rather than a signal and a tween

`character_visual.gd` already polls `Carriable.state` every frame in `_spin_while_airborne`, and
its comment there gives the reason: Carriable and CharacterVisual are **siblings with no guaranteed
`_ready()` order**. A lerp in the same poll inherits that safety, and — more importantly — is
**self-healing across a model rebuild**: `apply()` runs on every role swap and would otherwise
need a third re-assert beside `_refresh_can_damage` and `_refresh_downed_tilt`. It also buys the
scale-up on release for free, which reads as the slipper "growing" as it leaves the hand and is a
better throw tell than a snap.

#### The option that stays open

**"Make the Person literally larger" is not closed — it is costed and gated on 0.4.** If, after a
human has actually played it, the Person still reads too small against the world, the change is a
named chain and must land as its own pass, never inside an art commit: `PERSON_SCALE` →
capsule + hurtbox height → `FppPivot` → `HAND_CARRY_OFFSET` → TPP spring arm → a re-read of arena
scale at unchanged `SPEED`. Filed as **checklist 1.2b**.

#### Three defects found while measuring, none of them mine to fix

Filed rather than fixed, per `Concurrency_Protocol.md` §10. All three are on the checklist.

1. **B-81 — the tsinelas sole is painted `DEFENSE` blue.** `_build_tsinelas()` sets the sole to
   `UiTheme.DEFENSE`. The tsinelas only ever exists on the **offence** side, so the attacking
   team's prop is wearing the defence colour — a direct breach of `Dev_Plan.md` §4.2's hard rule.
   The board disagrees twice over: **THE SLIPPER's card accent is magenta**, not blue. Visible in
   this pass's `viewmodel_tpp.png`. `Art_Direction.md` §2's table is the source of the error —
   it assigns `DEFENSE` to "Can body, tsinelas sole" — and **that table is wrong**, not the rule.
2. **B-82 — `Main.tscn`'s floor top is `y = +0.5`, not `y = 0`.** `Floor` and its `CollisionShape3D`
   carry no transform, and the shape is a `(40, 1, 40)` box centred on the origin, so it spans
   `-0.5 … +0.5`. `Art_Direction.md` §4.1 and `Checklist.md` both state the top
   surface is `y = 0` and the box extends to `-1`. **Both are wrong.** Consequence: all four units
   are placed at `y = 1.0`, giving a capsule floor of `0.2` — **0.3 units inside the slab** — and
   they depenetrate upward on the first frames of every match.
3. **B-83 — the arena has no boundary where anyone thinks it does.** `Bounds/Wall*` sit at `±41`
   with a half-thickness of 1, so their inner faces are at **`±40`** — while the floor ends at
   **`±20`**. There is a 20-unit ring of empty space on all four sides that the invisible walls do
   not enclose; a player walks off the slab edge and falls to the `KillPlane`. The walls are not
   just invisible, they are **in the wrong place**, and 2.2's dressing belongs at `±20`.

#### Verified by running vs. reasoned about

- **Verified by rendering** (`render_probe.gd`, viewmodel + match, real device, screenshots taken):
  every measurement in the first table; that the carried slipper reads as a surfboard; that the
  lata reads as a can; that the tsinelas sole is blue.
- **Verified by reading the scene text:** B-82 and B-83's node transforms and shape sizes.
- **Reasoned about, NOT verified:** the `0.32` figure itself, the `HAND_CARRY_OFFSET ≈ -0.33`
  compensation, and the claim that units depenetrate upward rather than falling through. All three
  need a render once the build lane has implemented the carry scale. **1.2 is ticked as a
  *decision*; the implementation it specifies is unbuilt and unrendered.**

---

### 0.10 Full audit + replan, and four verified fixes (2026-07-27, v4.20 → v4.23)

**Branch:** `plan/full-overhaul` off `main` @ `2c22f50` (v4.20). **PR, not a direct push** — this
pass rewrites the planning docs every other agent reads as ground truth, which is a much larger
blast radius than a queue item.

#### What is mine to decide, and what is not

Stated up front because this pass touched a lot:

- **Mine, and acted on:** how a fix is implemented, how the docs are restructured, which model
  runs which brief, and the ordering in [`Checklist.md`](Checklist.md).
- **Not mine — flagged and stopped:** the display typeface (§0.5's gate is correct and is not
  being relitigated), anything needing real multi-device hardware, and signing or submitting
  Forms 01–03. These are on the checklist as explicitly human-owned items, not skipped.
- **Deliberately left open:** **Option A vs Option B. Both stay in active, equal development.**
  Every place in these docs that used to say "pick one and delete the other" has been rewritten.
  Neither mode is deprioritised, both get playtested, both get balanced. The ship decision is the
  human's, on their own timeline; it is checklist item 1.5 and it blocks nothing.

#### The screenshot that prompted this pass is not from this project

A live gameplay screenshot was supplied reading `0 - 0 · inning 1 · raid 1 · 0:46 · hits 0`, with
an **ATTACKER** banner, **HIT THE CAN**, a charge-style bar, and **SLIPPER READY — hold LMB to
charge, release to throw**, over an arena walled in by brown boxes with green roof caps. The brief
asked me to find where that copy comes from and fix it.

**It comes from nowhere in this repository.** Verified three independent ways:

1. `git grep` for `\binning\b`, `\braid\b` and `hit the can` across **all 139 commits on every
   ref** — `main`, `origin/design/mechanics-and-models`, and five local branches — returns
   nothing. Not stale copy that was replaced; text that has never existed here.
2. **Rendered the actual running build** (`tools/render_probe.gd`, match mode). The HUD reads
   `01:28`, `Round 1 / 5`, `A · DEFENSE` / `B · OFFENSE` with three Bo5 pips each, a YOU card and
   an FPP crosshair. There is no score string, no hit counter, no role banner, no charge bar.
3. The brown box walls do not exist either — and the truth is **worse than the claim**.
   `Main.tscn`'s `Bounds/Wall{North,South,East,West}` are `StaticBody3D` + `CollisionShape3D`
   with **no `MeshInstance3D` at all**. The arena edge is invisible: the floor simply meets the
   sky.

So the HUD-terminology item is closed as **not applicable**, not as fixed. The *underlying* asks
survive on their own merits and are on the checklist: the boundary genuinely does need the
moodboard's dressing (2.2), and the HUD genuinely is missing the charge and reset-channel meters
(0.1) — just not for the reasons the screenshot suggested. Recorded at length because inheriting a
false premise and "fixing" it would have been the exact failure §2 rule 3 exists to prevent.

#### Grand-vision fidelity: it is the game it says it is, and it does not look like it yet

Checked against the pitch — *2v2 LAN, one Person + one living object per side, both
player-controlled, roles swap every round, Bo5* — and the structure holds everywhere. `is_person`
is fixed for the match and drives the camera directive; `is_can` flips every round and drives the
model and the win condition; `team_is_can_side` drives every role colour. Nothing has quietly
turned a Prop into a second fighter. §0.7's correction held.

**Does it read as *tumbang preso*?** Structurally yes, experientially not yet — and the gap is not
where the docs assumed. The mechanic is right: a Person carries a slipper, charges, throws it on a
real arc at a guarded can, and has to run out and retrieve it. That is the street game. What is
missing is everything that makes it *legible*: no base circle in the world, no throwing line, no
sound when the lata is hit, no charge meter so the player can feel the throw building, and — until
this pass — a first-person camera that could not see its own hands. It currently plays like a
correct prototype of tumbang preso rather than a game about it.

#### Four fixes landed and verified by rendering, not by reasoning

The addendum asked for real runtime verification. `tools/render_probe.gd` (new, committed) loads
either an isolated viewmodel scene or the real `Main.tscn` **with a rendering device**, runs real
frames, and writes PNGs. Everything below was found by looking at the output.

| | Found | Fixed at |
|---|---|---|
| **1** | `FppPivot` at `y = 1.55` sat **0.75 units above the top of its own head** — the Person's head-mesh tops out at `+0.798` in CharacterBase-local space. First person rendered nothing but sky. | v4.21, `y = 0.45` |
| **2** | `HAND_CARRY_OFFSET` was written straight onto a node whose parent chain carries the model's `2.38` scale, so it was applied at 2.38× — a carried tsinelas sat at local `(-1.00, +1.12, -0.45)`, a metre to the character's left and above its own head. | v4.21, divided by `PERSON_SCALE` and retuned to `(0.65, 0.21, -0.25)` |
| **3** | U-6's **"ground ring" was drawn at chest height** (`y = 0.03` against a capsule whose floor is `-0.8`), its colour keyed off `is_person` instead of role — breaking §4.2's hard rule — and it never refreshed on the round swap. The floating tag sat 1.4 units above the head with no distance fade. | v4.22 |
| **4** | **B-77 — `Main.tscn` threw a script error on every single launch.** `_notification` handles `APPLICATION_FOCUS_IN`, which Godot delivers at window creation **before `_ready()`**, so three `@onready` vars were dereferenced while null. Also meant the first focus-in never recaptured the mouse. | v4.23 |

Fixes 1, 3 and 4 share a root cause worth naming: **`CharacterBase`'s origin is the centre of a
1.6-unit capsule, so a model's feet are at `-0.8`, not `0`.** Three separate nodes — the FPP pivot,
the ground ring and the floating tag — were each positioned against an imagined character standing
on `y = 0`. Check that before placing anything else on a character.

`main.gd` now runs 400 real frames of `Main.tscn` with **no output at all**, where it previously
threw on frame one.

#### What this pass did NOT do — read before picking up

- **Nobody played anything.** Every geometry claim above is verified by render; not one tuning
  number was verified by feel. The T-block is still `[~]` and Phase 0 of the checklist exists
  entirely to fix that.
- **No release build.** Godot export templates are not installed here, so F-3's and B-67's
  acceptance tests remain unrunnable. Checklist 5.1, marked human-owned.
- **No real-device LAN test.** Needs hardware. Checklist 6.1.
- **No font.** The gate held. Checklist 1.1.
- **No map, no character select.** Untouched, all queued. (Audio is no longer on this list — 4.1 shipped 2026-07-29.)
- **`HAND_CARRY_OFFSET` is tuned, not final.** It is deliberately not tuned further until the prop
  **scale** question (checklist 1.2) is answered — measured, the tsinelas is **84% of a Person's
  height** and the lata is **70%**, so a Person carrying one reads closer to carrying a surfboard.
  That is an art-direction fork, not a transform bug, and it is not mine to close.

#### One factual note on authorship

The convention in §2 and `Dev_Plan.md` §7.1 is that every commit is authored solely as
`M4tyu633 <matthewtlabrador@gmail.com>`. **The last twelve commits on `main` are all authored
`StarRayX <40836712+StarRayX@users.noreply.github.com>`.** This pass's four commits follow the
stated convention; the history is left alone rather than rewritten. Flagging it because Form 01
(team roles) and Form 02 (declaration of originality) both eventually have to agree with what the
repository says.

---

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

### 0.5 Display typeface — resolved (2026-07-28, v4.21)

✅ **Darumadrop One** (SIL OFL 1.1) shipped on an explicit human yes; the author supplied the
binary directly rather than it being fetched blind. Licence verbatim at
`assets/ui/fonts/DarumadropOne_LICENSE.txt`, tracked in LFS, ready to cite on **Form 03**.
It is now `theme.default_font`, so every Control inherits it.

**One piece of F-2 is still open:** the queue called for a *second*, clean-grotesque body face
(Inter / Work Sans) on the grounds that a display face is illegible at `FONT_SIZE_CAPTION` 13.
Darumadrop One is currently doing both jobs. Display sizes read well (see the main menu); the
13px `Caption` variation is the one to check on a real screen before submission. Picking a body
face needs another explicit yes, so it is deliberately not pre-empted here.

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
highlight* (§4.1 of `Dev_Plan.md`, and §1 of `Art_Direction.md`, recorded
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

- ~~**T-3 · B-46 lata reset channel.** Agreed in scope, zero lines written.~~
  **Built in the following pass, v4.3.** See T-3 in §4.
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
  [`Handoff.md`](Handoff.md). §3 below carries only what is still open, plus the four new
  bugs found while reading code for this plan (B-67 … B-70). An overwrite that dropped the
  forensic record — including its several "the docs were stale, this was already fixed" entries —
  would have re-invited exactly the rewrites protocol rule 3 exists to prevent.
- **No font was downloaded.** See §0.5.
- **The Local Match harness was left alone.** ⚠️ Superseded 2026-07-28 — it is no longer scheduled
  for removal at all; see `Checklist.md` 5.5.

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

**Single Player (formerly "Local Match") is a real, permanent mode, not a test harness — amended
2026-07-28, `Checklist.md` 5.5.** `_start_local_test()` and the four hardcoded units in
`Main.tscn` still exist and still make the loop exercisable on one keyboard, but the human now
plays exactly one of the four (their existing default, `TeamAPerson`) and the other three are
AI-controlled (`ai_controller.gd`), not unbound. **It ships in the final build.** The `p3`/`p4`
input action definitions in `project.godot` are unchanged (still unbound to real keys, still
registered — AI drives them via `Input.action_press()`/`action_release()`, which needs no key
binding at all) and the debug switcher (`debug_player_switcher.gd`) still exists for testing, but
neither shapes the LAN architecture any more than it ever did.

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
10. **Single Player (formerly Local Match) is not scheduled for deletion — amended 2026-07-28,
    `Checklist.md` 5.5** (§1). It is the only way to playtest without four laptops AND, per the
    user's decision, ships in the final build as a real mode in its own right.
11. **Debug-only code follows the removal contract** in `Dev_Plan.md` §0.3, without exception:
    `debug_`/`Debug` prefix on every file, class, node and autoload; debug code calls gameplay
    and **gameplay never calls debug** (no gameplay script may reference a debug class, autoload,
    signal or group — not even behind an `if OS.is_debug_build()`); no `[input]` map entries, read
    raw keys instead; self-disables in a release build; and a removal checklist written into
    `Dev_Plan.md` at the same time as the feature. A debug helper hiding inside a gameplay script
    is invisible to the verification grep and **will ship**. Reject it in review.

---

## 3. Bug & Issue Ledger

**Only open items live here.** B-01 … B-66 are in [`Handoff.md`](Handoff.md); everything
marked `[FIXED]` there is done and settled. New bugs take the next free number **in this file**.

**B-114 · The AI drove the GLOBAL `Input` singleton, so two bots shared one keyboard. [FIXED
2026-07-29]** ⚠️ **Both reported AI symptoms were this one bug.**

Report: *"they randomly stop and freeze completely"* and *"they all move together at the exact same
time in sync ... clearly sharing a global state."* That diagnosis was right, and the shared state was
`Input` itself.

`AIController._set_held()` called `Input.action_press(character.action_name(base))` — process-global
state keyed only by `player_id` — and `main.gd::_build_spawn_data` assigns AI slots
`player_id = (index % 2) + 3`, so **index 0 and index 2 both get p3** and 1 and 3 both get p4. Two
bots pressed and released the same actions:

 - **Lockstep** — they were literally reading each other's input.
 - **Freezing** — `_set_held` was edge-triggered against its OWN belief about what it held. Bot A
   presses `move_left_p3`; bot B, believing that action is not held, calls
   `Input.action_release("move_left_p3")` and stops BOTH. The two beliefs then disagree with the
   global forever and neither re-presses.

*Fix.* The global is out of the path entirely rather than the id range being widened — a human and an
AI on one machine can still collide, and a shared global is the wrong shape for per-unit intent
regardless. `CharacterBase` gained `input_pressed` / `input_just_pressed` / `input_just_released` /
`input_vector`, which read a per-instance intent dictionary when an `AIController` is attached and
the hardware otherwise. Every gameplay read in `character_base.gd`, `carrier.gd` and `carriable.gd`
goes through those now.

⚠️ **`character_base.gd:493`'s movement read was missed on the first pass** and it is the one that
matters most — the bots went completely still because intent was being written and the movement
vector was still being read from `Input.get_vector`. If AI movement ever dies again, check that
every read goes through `input_*` first.

*Second half: lockstep survives an independence fix.* Every controller started `_decision_timer` at
0.0 and decremented by the same delta, so all of them re-picked on the same physics frame forever.
Phase is now staggered in `_ready()` from a per-instance `RandomNumberGenerator` seeded off the
instance id, and each interval is jittered 0.75–1.3×. `randf()` calls were moved to that stream too:
one shared global sequence is a subtler version of the same "they behave as one" bug.

*Verified* with `tools/ai_probe.gd`: frames where two or more bots change movement state together
went to **1 / 846 (0.1%)**, longest still-run **1.1 s**, no freezes.

**B-115 · Two characters trading spawn marks depenetrated off each other's STALE collider. [FIXED
2026-07-29]** — the real root cause of B-100.

Writing `position` on a `PhysicsBody3D` updates the scene tree immediately and the physics
**broadphase** only at the next server step. Roles swap every round, so the two Persons trade marks,
and for one physics frame each of them is standing on the other's previous collider.

Measured with `tools/jump_probe.gd`: the incoming Taya is placed correctly at (2.2, 0.9, −1.5); on
the next step `move_and_slide()` reports three contacts with the outgoing Person (normal 0,1,0 —
stacked on its head) and shoves it to y = 2.50; the frame after that it slides **9.89 units** into
`WallWest`, where the confinement clamp parks it at exactly radius 5.0. Delta was a normal 0.0167 and
`time_scale` 1.0 throughout — not a lag spike, not a velocity bug.

⚠️ **Three "obvious" fixes do not work, and two had already been tried.** B-100's *park everyone at
y=500 first*, `force_update_transform()`, and `PhysicsServer3D.body_set_state()` are all writes the
broadphase does not see until it steps. Toggling `CollisionShape3D.disabled` was tried before that
and failed for the same reason.

*Fix.* Nobody MOVES until it has stepped. `CharacterBase.begin_spawn_settle()` holds the placed
transform, keeps zero velocity and skips `_physics_process` entirely — gravity, AI and
`move_and_slide()` included — for `SPAWN_SETTLE_FRAMES` (3, i.e. 50 ms).

**B-116 · Every character spawned 100 mm inside the floor. [FIXED 2026-07-29]**

Phase 8 raised the floor's collision top from 0.000 to 0.100 so characters would stop standing inside
the visible road, and left the four spawn marker Y values alone on the reasoning that "the paving was
already at 0.1". Wrong: a spawn Y is measured against the FLOOR COLLIDER, which moved. Every unit
therefore started embedded and was ejected by depenetration — the other half of the "weird physics
bounces" report. Spawn heights are now derived from `GROUND_Y` in `build_eskinita.py` rather than
typed, so they cannot drift from the floor again.

**B-117 · A thrown tsinelas had no live hitbox. [FIXED 2026-07-29]**

`CharacterBase.tscn`'s single `Hitbox` has `requires_bump_window = true`, and `is_hitbox_active()`
returned only `_bump_active_time_left > 0.0` — a field written in exactly one place, the **bump**
press. A slipper in the air never presses bump, so its hitbox was gated off for the entire flight and
throws landed only on incidental body contact.

*Fix.* Being `FLYING` is now also an active window — it is the slipper's equivalent of the bump
window, a deliberate time-boxed offensive state the player committed to. `carriable._step_flying`
also calls `sweep_hitbox()` each frame, because `area_entered` only fires on the ENTER edge and a can
already inside the hitbox on the first flight frame would otherwise never register.

*Verified* by A/B over 12 identical throws with `tools/phys_probe.gd`: frames with the can not in
NORMAL state went **180 → 515**.

⚠️ **Note for anyone measuring this:** `GameLaunch.game_mode` defaults to **OPTION_B**, so a hit on
the can produces downed/seal, **not** dents. A dent counter reading zero is correct in the default
mode and is not evidence of a missed hit — that mistake cost a debugging round here.

**B-118 · A freed lambda capture errored on every round reset. [FIXED 2026-07-29]**

`ability_utils.gd` created a transient hitbox area, added it to the `transient_hitbox` group, and
scheduled cleanup as `func(): if is_instance_valid(area): area.queue_free()`. `main.gd::_reset_world`
frees that entire group on every round reset, so an ability cast shortly before a round ends had its
area freed while the timer was still pending.

Godot resolves a lambda's captures when the lambda is **called**, before any of its body runs, and
errors there: *"Lambda capture at index 0 was freed. Passed null instead."* The `is_instance_valid()`
guard inside was dead code for precisely the case it was written for.

Found in a real two-instance `--host`/`--join` session — the host logged it on round transitions and
the client never did, because only the host resolves abilities. *Fix:* capture the **instance id**
(an int cannot dangle) and resolve it with `instance_from_id()` at call time.

**B-119 · `lata_impact` (and every other SFX) still buzzed under sustained contact despite the
retrigger guard. [FIXED 2026-07-29]**

`AudioManager.RETRIGGER_MS` (60 ms) throttles how often a sound NAME can start again, which is
enough to stop `hitbox.gd`'s per-physics-frame re-resolution (see `_on_area_entered`'s note) from
literally hitting `play_at()` 60 times a second. It does nothing about overlap: `lata_impact` itself
rings for ~300 ms (`generate_sfx.py::build_lata()`, `can_hit("lata_impact", 0.30, ...)`), so a
60 ms-spaced retrigger during a sustained hit (slipper resting on a lata, a character standing in a
hitbox for several frames) still starts a new voice roughly 5× before the previous one finishes
decaying. Five overlapping, pitch-jittered (±7%, `PITCH_JITTER`) copies of the same clang is a buzz/
drone, not a series of hits — the exact failure the guard's own doc comment describes, just at 1/5
the rate instead of the full 60/s.

*Fix.* The guard window is now per-sound instead of one constant: `_load_streams()` computes each
stream's own length via `AudioStream.get_length()` and stores it in `_retrigger_ms`; `_take()` reads
that instead of `RETRIGGER_MS` directly. A sound can now only retrigger once its own predecessor has
finished ringing — at most one voice of a given name plays at a time. `RETRIGGER_MS` (60) is kept as
a floor (see `_retrigger_window()`), since it is also what collapses `_flash_hit()` and
`_rpc_play_hit_vfx` firing for the same hit inside one frame, and a corrupt/degenerate stream could
otherwise report a near-zero length.

⚠️ **Not yet heard, and not re-run through `tools/audio_probe.gd`.** This session has no Godot
binary and no audio device, so this is worked through from the generator's own source durations and
the existing probe's assertions (`tools/audio_probe.gd::_check_playback`'s burst-of-8 test still
holds under the new logic — it only asserts a burst inside one frame collapses to ≤1 extra voice,
which a per-sound window ≥ the 60 ms floor still guarantees), not confirmed by ear or by a fresh probe
run. Whoever picks up the audio listening pass (see the Agent_Prompts.md `code/audio-mix` opener)
should re-run the probe and specifically re-test the sustained-contact case (hold a slipper against a
lata) before calling this closed.

**B-111 · Spawn slots were scrambled because `StringName` does not sort alphabetically. [FIXED
2026-07-29]** ⚠️ **This is the "spawns are still broken" report that survived several sessions.
Read the whole entry before touching spawn code again.**

Report, 2026-07-29: *"spawn still broken, offense spawned next to circle... when the goal of the
entire game is for offense to try to hit CAN in the circle while they're outside."*

*What it was not.* `_role_slot()` was correct, every time. An audit print of every
`_place_at_spawn()` call showed all four units resolving to the right slot — Can→0, Taya→1,
Attacker→2, Tsinelas→3 — with the right `is_can` / `is_person` / `team_is_can_side` flags. The
markers were authored in the right order in the scene, and `Main.tscn`'s role flags were correct
too. Every previous session looked at these and found nothing, because there is nothing there.

*What it was.* `_spawn_transform(slot)` returned the **wrong marker**. `main.gd` built `_map_spawns`
with:

```gdscript
markers.sort_custom(func(a: Node, b: Node) -> bool: return a.name < b.name)
```

**`Node.name` is a `StringName`, and `<` on `StringName` compares the interned POINTER, not the
text.** Measured on this engine build with four nodes authored `Spawn0`…`Spawn3`:

| | order |
|---|---|
| authored / `get_children()` | `Spawn0, Spawn1, Spawn2, Spawn3` |
| `sort_custom` on `.name` (what ran) | **`Spawn3, Spawn2, Spawn0, Spawn1`** |
| `sort_custom` on `String(.name)` | `Spawn0, Spawn1, Spawn2, Spawn3` |

So slot→marker was scrambled: the Can spawned on the Tsinelas's mark, the Taya on the Attacker's,
and **the Attacker on the Taya's** — offense standing next to the base circle it is supposed to be
throwing at from outside the throwing line. Exactly the report.

*Why it survived so long.* Every signal pointed away from it. The line reads as "sort by name". The
comment above it explicitly said *"Sorted by node name, NOT by get_children() order"* and gave a
sound reason (B-68). The resulting order was **stable within a run**, so it looked deterministic and
reproducible rather than random. And it is **not guaranteed stable between runs** — `StringName`
intern order depends on what got interned first — which is why the symptom appeared to change shape
from session to session and never matched anyone's mental model.

*Fix.* Named lookup, not sorting: `points.get_node_or_null("Spawn%d" % slot)` for slot 0..3. This
removes the failure mode rather than correcting one instance of it — there is no ordering left to
get wrong — and a renamed or missing marker is now a loud `push_warning` plus the fallback ring,
instead of a silently shuffled roster.

⚠️ **STANDING RULE FROM THIS BUG: never order anything by `Node.name` directly.** Any
`sort_custom`, `<`, `>` or `min`/`max` on a `StringName` in this project is the same bug waiting.
Cast with `String(...)` if you genuinely need lexicographic order, and prefer an explicit named
lookup over any ordering at all when the names encode a contract (`Spawn0..Spawn3` is a contract).

**B-112 · The held tsinelas floated ~0.44 m off the hand. [FIXED 2026-07-29]**

Report: *"floating slipper when held, fix it pls, make it acc be on the hand."*

`CharacterVisual.HAND_CARRY_OFFSET` was `Vector3(0.237, 0.135, -0.347)` — magnitude **0.441**,
measured bone-to-point in world space on a character **1.6 m tall**. Over a quarter of body height.

The intent was right, the execution was wrong twice:

 - **Wrong magnitude.** It existed to cancel the drop `_align_to_capsule_floor` applies to a carried
   unit's model, so the visible mesh lands at the palm rather than under it. That drop is a measured
   **0.160** for the tsinelas (its capsule half-height). A 0.160 correction was needed; 0.441 was
   applied, two thirds of it sideways and forward rather than up.
 - **Wrong space, and unfixable as a constant.** `HandPoint` is a child of a `BoneAttachment3D`, so
   the offset is expressed in the **hand bone's local frame** — which rotates with every animation
   clip. Whatever it meant in `holding-right` it meant something else in `walk`. No single constant
   could have been correct across poses, which is why re-tuning it never held.

*Fix.* The mesh drop is cancelled in `carriable.gd::_step_carried()`, in **world space**, from the
carried unit's own `CharacterVisual.visual_centre_offset()` — cached by `_align_to_capsule_floor`,
which is the one place that knows the drop. The carried unit is positioned so its **mesh centre**
lands on the hand point, not its origin. Correct for the Can as well, and it cannot drift from the
number it exists to cancel. `HAND_CARRY_OFFSET` is now `(0.04, 0.03, -0.06)` — 0.078, a genuine
wrist-to-palm nudge, which IS a bone-space quantity.

⚠️ **Verified in FPP render only.** Not checked in third person, not while walking (a different
clip — and clip-dependence was the original bug), not mid-throw. The 0.078 nudge is a first guess.

**B-113 · Shadows so dark a character in shade was unreadable. [FIXED 2026-07-29]**

Report: *"shadows are too much, cant see person anymore, lowk feels overwhelming."*

Not one slider — two changes from earlier the same day compounding. Fixing the Phase 8 overexposure
pulled `ambient_light_energy` down to 0.55, and the shadow-acne fix had pushed `shadow_opacity` to
1.0 (fully opaque). Together, anything in shadow lost nearly all of its fill light.

*Fix.* `shadow_opacity` 1.0 → 0.62, `ambient_light_energy` 0.55 → 0.95, `ssao_intensity` 3.2 → 1.8,
`ssao_power` 1.35 → 1.1, `light_energy` 1.75 → 1.35, `adjustment_contrast` 1.09 → 1.03,
`shadow_blur` 0.9 → 1.1.

⚠️ **One iteration, not human-validated.** These were chosen to fix "too dark" without re-checking
that the earlier washed-out look has not partly returned. Lighting on this map has now been retuned
three times in one session in opposite directions; the next pass should change **one** value at a
time and get a human verdict before moving another.

**B-110 · `floorcheck` ignored SCALE, so it measured against the wrong heights. [FIXED
2026-07-28]** Two halves, both the same mistake, found a day apart.
 - **Ground pieces.** `record()` computed a piece's top as `y + hi[1]`, with no scale at all. Every
   kit ground piece therefore reported its UNSCALED height — a road tile placed at 4× reported
   0.025 instead of 0.1 — and every marking resting on one was checked against a surface that was
   not there. **The guard found this itself**, by failing the arena re-paving (7.4b) with errors
   that were arithmetically impossible if its own numbers had been right.
 - **Markings.** The same hole on the other side: `_markings` did not store whether the placement
   was uniformly scaled, `_samples()` scaled only X, and `verify()` read `lo[1]`/`hi[1]` raw.
   Latent today, because nothing places a marking through `add_kit()` — and it would have bitten
   silently the first time anyone did.
*Root cause of the class:* two different scale conventions share one parameter. `xform()` stretches
ONLY the mesh's length axis (right for a lengthenable line decal, leaves Y and Z alone);
`xform_uniform()` scales all three (right for a building). `sx` meant both. Every caller now says
which via an explicit `uniform` flag, and `embed_y()` takes the scale it is embedding at.
*Proven by negative test, not by inspection:* a 3×-scaled marking embedded at its real scale is
accepted, and the same marking placed with the old scale-blind arithmetic is rejected with
`STICKS OUT ... 62.0mm`. Before the fix that second case passed silently.
⚠️ **A guard that is wrong is worse than no guard**, because it is trusted. If you add a third
placement convention here, give it its own flag rather than overloading `sx` again.

**B-109 · Field markings STUCK OUT of the floor — the other half of the floating bug.
[FIXED 2026-07-28]** Reported after B-103 shipped: *"the decals of floor still stick out."* Both
reports are the same object and opposite failures. A marking is a **2cm-thick box**, so B-103's
"sit it flush on the surface" left 2cm of vertical SIDE WALL standing proud all the way round.
The camera lives near ground level, so at a grazing angle those walls catch the light and every
line reads as a low kerb instead of as paint.
*Fix — the rule is now a SANDWICH, not a resting height.* A marking must have its top face a hair
above the surface (visible, never z-fighting) **and its bottom BELOW it**, so the side walls are
inside the ground and cannot be seen from any angle. `floorcheck.embed_y()` is the single source of
that arithmetic and both builders call it; nothing places a marking by a hand-computed number any
more. The guard rejects all three wrong states with distinct messages — `STICKS OUT`, `FLOATS`/
`SPANS`, `BURIED` — and was negative-tested against each before shipping.
⚠️ **"Flush" was never the goal and is not achievable with thick geometry.** Anyone re-deriving
this will land back on flush; the invariant is EMBEDDED.

**B-108 · The Can "kept teleporting" — the teleport was the reset correcting an AI drift.
[FIXED 2026-07-28]** Flagged repeatedly. `ai_controller.gd::_update_can()` picked
`_random_point_in_confinement(0.6)`, walking the Can up to ~3 units off its base circle; every
round reset then snapped it back to Spawn0, and that snap is what a player sees.
*Measured, not guessed:* a new `render_probe.gd` mode, **`canwatch`**, drives a real match and
prints only frames where the Can MOVES more than a step. It showed constant velocity 6.0 on a
diagonal followed by 1.4–1.8 unit jumps back to `(0, 0.17, 0)` on each transition. After the fix
it reports no jumps at all.
*Why the AI was wrong on its own terms:* tumbang preso is played around a can STANDING on its
mark — a Can that strolls off has nothing left to defend. It now holds `CAN_HOLD_RADIUS` (0.45)
inside the 1.4-wide base circle, so it still shifts (the pillar says take funny) but never leaves
the mark and the reset never has to yank it.

**B-107 · The Can's and Slipper's cameras rolled. [FIXED 2026-07-28]** Third report, screenshots
showing the 3D view rolled ~40° while the HUD stayed level — which is a camera roll and nothing
else. Both pivots are CHILDREN of the CharacterBase and inherit its full basis, and a Prop's body
DOES get a full basis written to it: `carriable.gd::_step_carried()` snaps a carried unit to the
carrier's hand every physics frame, tilt included.
*Fix — the rig stops trusting its parent.* `_apply_upright_pose()` gives both pivots an ABSOLUTE
transform every frame, built from the body's **yaw only** plus their own pitch. Whatever the body
does on the other two axes cannot reach the camera, **from any code path, including ones nobody has
written yet** — which is the point, since patching individual writers is what failed twice.
⚠️ Yaw is recovered from the body's FORWARD VECTOR, not `global_rotation.y`: Euler decomposition of
a basis that contains roll does not give back the yaw you want, and a rolled basis is precisely the
case this exists to survive.

**B-106 · "defence hand is on the can" — BOTH mechanical explanations eliminated, no fix made.
[INVESTIGATED 2026-07-28, NOT REPRODUCED]** Reported with a screenshot: a defending Person appearing
to hold the Can, plus an older report that "the defender only has one hand".

Two candidate causes were checked in code and **both are ruled out**, which is the useful part of
this entry — it stops the next person spending the same time:
 - **It is not a carry bug.** `carriable.gd::host_grab()` gates on `can_be_grabbed_by()`, which
   returns false for a Can via `is_throwable()`. A defender genuinely cannot pick the Can up, and
   `_reset_world()`'s auto-grab only ever selects the tsinelas.
 - **It is not the FPP viewmodel leaking into a third-person view** (the leading hypothesis, since
   the viewmodel is camera-mounted and would appear to reach at whatever that player looks at).
   `camera_rig.gd` sets `arms.visible = _active and _mode == Mode.FPP` from `_apply_fpp_self_hide()`,
   which `set_active()` calls — so a rig nobody is looking through never draws arms.

*Most likely remaining explanation, unverified:* the Taya spawns 2.65 units from the Can and guards
it, and the chibi rig's short arm against a wide torso reads as contact at some camera angles. The
outline fix in 7.1 (the Can's border was ~12% of its own width per side and merged with anything
near it) may well have removed the read on its own.
**Needs a fresh screenshot on the current build before anyone changes code for it.**

**B-105 · The carried tsinelas floated beside its carrier's head, and re-measuring the offset
could never have fixed it. [FIXED 2026-07-28]** Reported repeatedly as "slipper floating" and
chased at least three times as a `HAND_CARRY_OFFSET` calibration problem.

*The offset was never wrong.* Its own note says what it was chosen for: put the slipper "a little
above the eye", forward and right so it never covers the crosshair. That is a viewmodel pose. It
was correct for the FIRST-PERSON frame and it was the ONLY thing positioning a real world object,
so every other player saw a slipper hovering next to a head. **One object was being asked to
compose two views at once**, which is why every re-measurement moved the problem instead of
removing it — the probe reported `HandPoint` and the slipper at exactly the same coordinate the
whole time.

*Fix:* the same inversion the viewmodel arms already exist for. `ViewmodelArms.tscn` gained a
`HeldSlipper` under the fist, posed for the local player's frame via `VIEWMODEL_CARRY_ANCHOR`;
`_update_viewmodel_carry()` stopped chasing the world slipper and holds a fixed carry pose; and
`HAND_CARRY_OFFSET` was re-targeted to mean what its name says — the hand.
⚠️ Two consequences worth knowing, both found by rendering:
 - The local player then saw TWO slippers. The carried unit is a separate `CharacterBase`, so the
   body self-hide never covered it. `_apply_carried_self_hide()` handles it on the same
   "`_active` is only true for the rig you look through" basis as the body hide.
 - That hide **must remember what it hid**. Keyed on `carrier.held()` alone, throwing the slipper
   makes `held()` null, the restore never runs, and the slipper stays invisible to the thrower for
   the rest of the round.

**B-104 · Bayan Plaza could never be loaded — both map entries shared one id. [FIXED
2026-07-28]** `GameLaunch.MAPS` declared `"id": &"eskinita"` on BOTH entries, and
`selected_map_scene()` returns the first match, so **every path that loads a map — the picker, the
launch handoff and `render_probe` — could only ever reach Eskinita.** Bayan Plaza has been built,
dressed, spawn-fixed (B-102) and re-dressed (7.5) while being unreachable in play the whole time.
*Why it survived:* it fails silently and in the most misleading way available — you pick the second
map and the first one loads, which reads as "the picker is ignoring my click", not as a duplicate
key. Nothing validates that ids are unique.
*Found* only because the 7.5 re-dress kept rendering as Eskinita three runs in a row.
⚠️ **Any map-select bug report predating this is suspect** — the map was never actually switching.

**B-103 · Field markings float, for the fourth time — and the constant was never the bug.
[FIXED 2026-07-28]** Reported again with a screenshot: *"i keep flaggging this still broken,
thoroughly think about how to make sure this problem doesnt show up again."*

*What was actually wrong,* measured rather than guessed. `throwing_line_decal` is **8m wide**;
the `road_tile_line` strip it crosses is **2m wide and 6.2cm tall**. The line was lifted to 0.070
to clear that strip, so across the ~75% of its length that is over bare road it hung **7cm in the
air**. `base_circle_decal` sat at 0.070 on a 0.062 top — 8mm of float. Ten other markings had the
same fault; nothing had ever checked.

*Why three previous fixes failed.* All three retuned one constant (`0.07 → 0.015 → 0.001`). **No
single Y can be flush for a marking that spans a step**, so every value was wrong somewhere, and
which part floated just moved. The shape has to be split at the step.

*The fix, and the reason it should not recur:* `tools/maps/floorcheck.py` — every placed piece is
recorded, every marking's footprint is sampled against the real ground height beneath it, and the
map build **aborts before writing the scene** with the node name and the gap in millimetres. It
reports "spans two heights" as a distinct error from "floats", because the two need different
fixes. `build_eskinita.py::add_line()` then splits a line marking at every step automatically, so
the eleven faulty markings became 26 verified-flush pieces with no hand-picked heights left.
`MARK_Y`/`MARK_Y_LOW` are deleted from both builders — a human deciding what is under a marking was
the root cause, not any particular value they decided.
**Verified by render** (grazing angle, no gap or shadow under any line) and by both builders
reporting `markings verified flush`. Determinism re-checked: both scripts run twice with a clean
tree.

**B-102 · Bayan Plaza's Taya spawns in FRONT of the Can, not behind it, and a comment asserted
otherwise. [FIXED 2026-07-28]** `build_bayan_plaza.py`'s Spawn1 was `(2.2, 0.8, +1.5)` against
`build_eskinita.py`'s `(2.2, 0.8, -1.5)`, while its own comment read *"same scheme and same
coordinates as build_eskinita.py"*. The Attacker is at `z = +6`, so `+1.5` put the defending Taya
**between** the Can and the attacker, on the attacker's own side — the exact layout the human
rejected on 2026-07-28 ("the person in same team is behind that can"). It was fixed in Eskinita and
never carried across, and the false comment is why nobody caught it: every reader who checked took
the claim instead of the number.
*Root cause of the class:* two map builders duplicate a spawn block with nothing checking that they
agree. **Change one map's spawn block and diff it against the other in the same commit.**
⚠️ **On the reported offense/defense spawn swap, now that B-104 is known.** Eskinita's spawns were
re-verified by data (not by eye) across two round transitions and are correct in both. Combined
with B-104 — the picker could only ever load Eskinita — **the most likely story is that the human
was on Eskinita believing they were on Bayan Plaza, and B-102's mirrored Taya spawn was never what
they were looking at.** The remaining candidate is simply that units walk during the pre-round
free-roam window (and now under the merged Single Player AI), so where they *stand* when you look
is not where they *spawned*. Nothing further to fix without a fresh report on the current build.

### P0 — none open

The three P0 network soft-locks (B-62, B-63, and the B-01/B-03/B-29 cluster) are all fixed and
runtime-verified. See the archive.

### P1 — found by 🔧 Build while building the 4.2/4.3 two-instance test rig (2026-07-28) — both FIXED

Neither is new networking work — both were pre-existing and unreachable without an actual live
multi-peer session, which is exactly what `Checklist.md` 4.2/4.3/4.7 required building. Filed and
fixed in the same pass rather than left for QA, since they directly blocked verifying this lane's
own work (a two-instance session could not run silently with either still open) and are squarely in
files this lane owns (`scripts/ui/*.gd`).

**B-100 · A stale-but-not-yet-freed character reference could crash the HUD the instant a peer
connected or disconnected. [FIXED same session.]** `you_card.gd::get_local_character()` returned
its cached `_character` field with a guard of the form `_character != null and not
is_instance_valid(_character)`. Measured live: for a FREED (not null) Object reference, GDScript's
own `!=` already compares it as equal to null — so the `_character != null` half of that guard is
**false** for exactly the freed case it exists to catch, short-circuits the `and`, and falls
through to `return _character`, handing the caller the same poisoned reference back. It merely
*compares* as null from then on; the variable is never reassigned to an actual null literal, so it
still fails Godot's own argument type-check the moment it is passed into a strongly-typed parameter
— which is what `hud.gd::_process()` does every frame (`offscreen_indicators.update(local_char)`).
Reproduced with a real `--join=127.0.0.1` process: the very first `you_card.gd::_ready()` runs
BEFORE `main.gd`'s own `_ready()` (children ready before parents) and, for the brief window before
`NetworkManager.is_networked()` becomes true, its local-character scan falls through to the
LOCAL-TEST branch and caches `TeamAPerson` — which `main.gd::_start_joining()` frees moments later
via `_clear_local_test_characters()`. Every `hud.gd::_process()` in between crashed with `Invalid
type in function 'update' ... (previously freed) is not a subclass of the expected argument class`.
**Fixed:** `is_instance_valid(_character)` alone, unconditionally — it correctly handles both a
real null and a freed reference with no error either way, which the flawed two-part guard did not.
Verified by running: the exact repro (host + one join, 600+ frames) went from crashing on frame 1
to silent.

**B-101 · `offscreen_indicators.gd` crashed reading a tracked teammate/Can's transform mid-`queue_free()`. [FIXED same session.]**
`_update_one()` guarded its `target` parameter with `is_instance_valid()` only, which is not the
same condition as "safe to call `get_global_transform()` on." A character that just left the tree
(disconnected, or the local peer's own `_on_player_disconnected` freeing a departed teammate — see
4.7) can be a real, non-freed Object for one or more frames after `remove_child`/`queue_free` while
still failing `is_inside_tree()`; `global_position` needs a live parent chain and throws `Condition
"!is_inside_tree()" is true` otherwise. Reproduced live in a 4-peer session: a surviving peer's own
`OffscreenIndicators`, still tracking the just-dropped peer as its teammate or the Can, crashed on
the very next `_process()` after detecting the disconnect. **Fixed:** `_update_one()` now also
checks `target.is_inside_tree()` before reading `global_position`. Verified by running: the same
4-peer drop scenario (host + 3 joins, one hard-killed mid-round), re-run after the fix, produced no
errors on the two surviving peers across 2400+ frames.

### P1 — found by the design lane while rendering for checklist 2.3 (2026-07-28)

Filed, deliberately not fixed. Both live in 🔧 Build's files and `scenes/ui/*.tscn` is under
Build's lock for `code/offscreen-indicators` (3.4), so touching either would breach
`Concurrency_Protocol.md` §2 and §3 at once.

**B-86 · The FPP crosshair never appears, on a Person, in a real match. [COULD NOT REPRODUCE,
2026-07-28, 🔧 build-ux.]** Originally filed against `scripts/ui/hud.gd:74`'s
`crosshair.visible = local_char != null and is_instance_valid(local_char) and
local_char.is_person`, on the theory that `local_char` was still null the moment that line runs.
**Re-ran the exact repro** — `godot --path . tools/render_probe.tscn --quit-after 400
--resolution 1280x720 -- match <out>/` (NOT headless) — six times in a row on this machine.
Every one of the six `match_fpp.png` outputs shows the YOU card reading `PERSON · TEAM A ·
DEFENSE` **and** a `+` at screen centre; zoomed crops of (580,300)-(700,420) confirm it is the
`Crosshair` control, not a background artifact — it sits exactly at the anchor-0.5/0.5 box
`HUD.tscn` places it in. `hud.gd` and `you_card.gd` are byte-identical to the commit this bug was
filed against (`git diff` against `2c22f50` is empty for both), and `main.gd`'s local-match spawn
path has no `await` anywhere the 120-frame probe window could race against, so there is no code
path left to blame. Left open, unresolved and unexplained: why the original filing saw bare
road. Whatever it was, it is not reproducible now, on this build, on this machine. Filed as a
correction rather than closed outright, since "cannot reproduce" is not the same claim as "does
not happen on every machine" — if it recurs, get a screenshot from the machine that shows it
before touching `hud.gd` again. `Dev_Plan.md` §4.4 and `Checklist.md`'s HUD row both call the
FPP-only crosshair verified by render; that claim now has fresh render evidence behind it dated
2026-07-28, superseding the "wrong" correction this entry used to carry.

**B-87 · A carried tsinelas reads as floating, not held, in first person.** Not a regression and
arguably not a bug — recorded because it will be noticed during 6.3/6.4 capture and someone will
otherwise re-derive it. `camera_rig.gd::_apply_fpp_self_hide` hides the whole `Visual` subtree, so
there is no arm in frame; the slipper sits alone at eye level, horizontal, ~0.54 units out. The
placement itself is correct and deliberate (`HAND_CARRY_OFFSET`'s comment block explains the
target and the two rejected alternatives). **This cannot be fixed by moving the offset.** A proper
FPP viewmodel needs a separate arm mesh, and the Kenney rig has none — `body-mesh` is torso, arms
and legs as one skinned mesh, so the arms cannot be kept while the torso is hidden. Either accept
it, or add a dedicated viewmodel arm, which is new geometry and a new task. **Framing note for
6.3:** the trailer's beat 5 is the FPP charge-and-throw, so shoot it tight enough that the slipper
fills frame and the missing arm never becomes the question.

**B-88 · Can/Tsinelas rendered under the floor after the proportion fix (2.5). [FIXED same
session.]** `character_visual.gd::_align_to_capsule_floor()` dropped every model a hardcoded
`CAPSULE_HALF_HEIGHT_DOWN` (0.8) below the character's own origin — correct while every unit
shared the same 1.6-tall capsule, wrong the instant 2.5 gave Can and Tsinelas their own much
shorter one (0.34/0.32 tall). The physics body sat correctly on the floor; the visible mesh kept
dropping the old fixed 0.8 regardless, landing 0.63 units under it. Found by the human immediately
after 2.5 merged ("i dont see can and tsinelas anymore" / "theyre under the map"), not caught by
this session's own render checks because those checks screenshotted a carried slipper and a
standalone preview turntable, never a fresh in-match spawn actually settling onto the floor.
**Fixed:** reads this unit's own, currently-applied `CollisionShape3D` height instead of the
shared constant. Verified by rendering `tools/render_probe.gd`'s viewmodel mode again — the can
that was sunk into the ground now stands on it.

**B-89 · Nameplate ring/label also sized for the old shared capsule. [FIXED same session.]** Same
bug class as B-88, different node: `character_nameplate.gd`'s ring (`y = -0.78`, radius 0.55) and
label (`y = +1.05`) were hardcoded for the Person's 1.6-tall capsule. On a Can the ring drew nearly
a metre below the model's actual feet; on a carried Tsinelas the whole nameplate rides along with
it, so the disconnected ring appeared to float around the held object. Reported: "the slippers
still have a circle around it when holding." **Fixed:** added `CharacterBase.capsule_height()`/
`capsule_radius()` as a shared accessor (`character_visual.gd`'s own copy of this logic simplified
to call it too), and `CharacterNameplate.apply_sizing()` reads it — called explicitly from
`character_base.gd` right after `_apply_role_collision()`, deliberately NOT from the nameplate's
own `_ready()`, which runs before the capsule is resized (children ready before parents). Verified
by render: the can's ring now sits tight at its base, the carried slipper's ring is a small band at
the object instead of a large disconnected circle.

**B-90 · Carried slipper read as a broadside sliver, and swam through the walk cycle while moving.
[FIXED same session.]** Two related reports: "the slippers look weird af when holding it" and "my
arms float during windup and when i run while holding." Two independent causes:
(a) `character_visual.gd::_play_locomotion()` fell back to `walk`/`sprint` the instant a carrying
Person moved (the rig has no `holding-right-walk` clip), and `carriable.gd::_step_carried()` snaps
the carried object to the arm BONE's live position every physics frame — so the walk cycle dragged
the held slipper, and the FPP viewmodel arm chasing that same position (`camera_rig.gd`), through
the animation's swing. **Fixed:** `_is_holding()` now checked before speed, not after — the carry
pose wins outright while holding, legs stop swinging rather than the hand swimming.
(b) The tsinelas is a flat, thin object (0.078 tall vs 0.432 long) and the arm bone's fixed
rotation presented it close to edge-on to a camera at roughly the same height — a sliver, not a
slipper. **Fixed:** a 55° tilt applied in the object's own local frame, before the hand's rotation,
in `carriable.gd::_step_carried()`. Verified by render for (b) — the carried slipper reads as a
recognisable shape in both FPP and third person now. (a) is verified by code-path elimination, not
a screenshot — a single frame cannot capture "stops swinging while running."

**Mechanics audit against Dev_Plan.md §3-4, same session.** User ask: "make sure the code currently
follows intended mechanics, scoring and placement." Found one real gap and one deliberate
simplification worth recording:

- **Missing: Option A's ring-out win condition.** `Dev_Plan.md` §3 names two Can-side win paths —
  "the timer running out, OR knocking Slippers out of bounds a set number of times" — and only the
  first existed. `KillPlane.character_respawned` fired a HUD toast and nothing else. **Fixed:**
  `RoundManager.register_ring_out()`, `RING_OUT_LIMIT = 3`, wired from `main.gd`'s existing KillPlane
  handler. See `Checklist.md` 4.4b.
- **Not changed, flagged instead: Option B's "circle" is semantic, not physical.** The GDD says a
  solid hit "knocks the Can out of the circle" into Downed. The actual trigger is
  `ThrowProfile.forces_downed` / `Hitbox.forces_downed` — a flag on the hit, not a real
  knockback-then-distance-from-base-circle check. No positional/circle code exists anywhere in
  `scripts/`. This reads as a deliberate simplification (the round-win system is explicitly built
  decoupled from movement/physics — see `Dev_Plan.md` §3's own "Build note") rather than a bug.
  Building real physics-based circle-exit detection is a materially bigger feature than a bug-fix
  pass and was not attempted; flagging for the team to decide whether it is worth doing.

**B-91 · Carried Tsinelas's own TPP camera was blocked by the carrier's body. [FIXED same
session.]** `carriable.gd::_step_carried()` teleports the whole CharacterBase into the carrier's
hand every physics frame; the TPP spring arm (a child) inherited that transform and had nowhere
sensible to cast toward, with the carrier's own body never excluded from its shapecast. **Fixed:**
`camera_rig.gd::_update_tpp_carry_follow()` bases the TPP camera on the CARRIER while held (same
mount height/pitch a normal rig uses, carrier's body excluded from the cast) instead of this unit's
own nonsensical transform. A first attempt also scaled a Prop's own STANDALONE mount height down
for its shorter capsule, on the B-88/B-89 theory — reverted after rendering it: the spring arm
collapsed into solid geometry (the cast origin ended up too close to the ground/the prop's own
mesh). Only the carried case was reported broken; the standalone case was untouched. Verified by
rendering through each unit's own CameraRig directly.

**Spawn layout redesigned as role-based, same session — see `Checklist.md` 2.6.** User feedback:
"two teams spawn on completely different ends and i dont think thats how it should go." Correct: the
old scheme spawned each team's pair at a fixed end of the alley regardless of which side was
defending that round, disconnected from the map's own base circle and throwing line
(`Art_Direction.md` §9). `main.gd`'s four spawn slots are now roles (Can/Taya/Attacker/Tsinelas via
the new `_role_slot()`) instead of a stored team index, and `_reset_world` auto-hands the tsinelas
to the attacking Person at round start rather than leaving it loose to be walked over first.

**Option B rewritten — confinement, tag-to-win, auto-seal, 5-fall cap, same session — see
`Checklist.md` 2.7.** User design pass, closer to real tumbang preso, after playing the
spawn-redesigned build. Four rules changes plus a UI addition, all in one commit:

- **Confinement.** The Can and its Taya are now confined to a 3-unit radius around the base
  circle (`CharacterBase.CONFINEMENT_RADIUS`) for the whole round —
  `_move_and_confine()` wraps every `move_and_slide()` call site so nothing bypasses it.
- **Tag-to-win.** A defending Person's hit (Bump or the Tag ability) landing on the attacking
  Person now ends the round for team can outright — previously stun-only, no round effect.
  Added directly in `hitbox.gd`'s resolution function.
- **Auto-seal.** The 2s self-right window is unchanged, but `character_base.gd` now calls
  `seal()` itself the instant it lapses unrecovered, instead of requiring a follow-up hit from an
  attacker (the old Option B behaviour, retired).
- **5-fall cap.** `round_manager.gd` tracks every Downed transition on a tracked Can this round
  (`FALL_LIMIT = 5`), saved or not; reaching it auto-wins for team slipper regardless of whether
  that fall was individually recoverable.
- **Local ready-up.** Local matching previously skipped straight to Main.tscn; it now routes
  through `Lobby.tscn` like Host/Join, with a `"local"` branch in `lobby.gd` that does no
  networking but keeps the same READY → START rhythm.

Option A is unchanged and stays selectable, but is now explicitly parked (`Checklist.md` 1.5) —
this is Option B's ruleset changing in place, not a third mode. Verified by parse, two 800-frame
soaks, and a `render_probe.gd` lobby mode that drives the real Ready button and confirms Start's
enabled state flips exactly once. **Not verified by play** — confinement radius, tag-to-win and
the fall-cap number are all brand new and nobody has felt them yet.

**First human playtest of 2.6/2.7, same day — confinement/tag-to-win provisionally fine (human
wants a recheck after further changes), 5-fall cap and spawn distances confirmed good.** Also
surfaced two real bugs and a request, all 🔧 Build, on `code/option-b-tuning`:

**B-92 · `build_eskinita.py`'s throwing-line and team-side decals sat flush on the road instead
of raised. [FIXED same session.]** `add(parent, name, mesh, x, y, z)` calls for
`ThrowingLineNorth/South` and both `TeamSide` decals put `MARK_Y` (the offset that lifts a
marking above the `road_tile_line` tile layer — see 2.5/2.2a's own note on why `BaseCircle` needs
it) in the **x** argument slot instead of **y**. `BaseCircle` had it right, which is why the base
circle rendered fine and the throwing/team-side lines didn't. Reported as "the pink lines are
floating" / "a big line in the middle." Fixed; `Eskinita.tscn` regenerated.

**B-93 · A unit airborne when a round resets could fall through the floor. [FIXED same
session.]** `character_base.gd::reset_for_new_round()` repositions every unit (via
`main.gd::_place_at_spawn()`) but never zeroed `velocity`, unlike the sibling teleport path
`respawn()` (used by `KillPlane`) which already does. Spawn markers sit with zero vertical
clearance against the floor by design (same as every role); a unit still carrying downward
velocity from a jump or knockback at the instant a round ends can tunnel through that gap before
the next `move_and_slide()` re-establishes floor contact. Reported as "when round resets the can
randomly falls thru the void." Fixed by zeroing velocity in the same place `respawn()` already
does.

**Arena resize to a bigger square — TRIED, then FULLY REVERTED same session.** First attempt at
the "playing area feels too small" complaint below widened the whole map footprint (`W`/`Z_END`
24.0/24.0, was 8.0/17.0) instead of the actual thing the human meant. Human's correction: "i
wanted you to expand playing AREA, Not the entire map" — the complaint was
`CharacterBase.CONFINEMENT_RADIUS` (the box the Can/Taya can actually move in), not the map's
footprint, and stretching the whole map made that box feel *more* cramped by comparison, not less.
Also broke Layer3 dressing (posts/sampay wires positioned for the old width, now visibly
disconnected from the wall line — reported as "floating elements everywhere"). Reverted in full:
`tools/maps/build_eskinita.py` restored to its post-B-92-fix state (`git show
088d09a:tools/maps/build_eskinita.py`), `Eskinita.tscn` regenerated, `docs/Agent_Prompts.md`'s
DESIGN-ART item B and `Checklist.md`'s 2.2 bullet restored to their original text. **Lesson,
recorded so it isn't repeated:** "make the playing area bigger" in this project means the
confinement box, not the map — see the fix below.

**Confinement radius raised 3.0 → 5.0, plus a chalk-style boundary marking it — ring tried first,
replaced with a square same day, plus a real floating-geometry bug fixed along the way.**
`CharacterBase.CONFINEMENT_RADIUS` is now 5.0 — still a full unit short of the 6.0 throwing line,
so the Taya still cannot reach the attacker's line, same design constraint as before, just more
room inside it. `build_eskinita.py` first drew the boundary as a ring of tiled `team_side_decal`
segments (`CONFINEMENT_RING_RADIUS`, a 12-gon approximation), added via a new `sx` parameter on
`xform()`/`add()` that scales a decal along its own authored length axis (no new mesh added to
`env_kit.gd`, which stays Design-owned). User feedback, same day: "the circle you made was ugly,
can we just use a square" — a real tumbang preso boundary is a straight-edged chalk box, not a
drawn circle. Replaced with `CONFINEMENT_BOX_RADIUS`, four tiled sides using the same `sx`
technique.

**While looking at this, a real bug: several markings were floating above the floor with a
visible gap, reported as "all assets like lines are floating off the floor."** Root cause:
`env_kit.gd`'s `_box()` authors most flat decals starting at local Y=0, so a marking's world-space
Y position becomes its literal *underside*, not its centre — placing one at `MARK_Y` (0.07, chosen
to clear the 0.06-tall `road_tile_line` tiles) puts its bottom 7cm above the floor **even where it
never overlapped a tile in the first place**. Only `BaseCircle` and `ThrowingLine*` genuinely
overlap tile geometry (`x=0`, `z` a multiple of `CELL`) and need that clearance; `TeamSide*`,
`JeepneyLane`, and the new confinement square never did. Introduced `MARK_Y_LOW` (0.015) for
everything that doesn't need tile clearance. **A standing warning about this exact class of bug is
now in `Art_Direction.md` Part 4 (a callout at the top, before the Environment Art Agent Brief) and
directly in the DESIGN-ART paste-ready prompt in `Agent_Prompts.md`** — this had already cost more
than one session before being run down properly.

Before this there was nothing on the ground marking the edge of the confinement box at all — only
the tiny base circle and the distant throwing line — so a Taya had no way to see how much room
they actually had. **`build_bayan_plaza.py` does NOT have the confinement square yet** — same
treatment needed there before that map is played under Option B. Keep `CONFINEMENT_BOX_RADIUS` and
`CONFINEMENT_RADIUS` in sync if either is retuned again. **Verified by render**
(`tools/render_probe.gd`, real device) — geometry lands where computed, no visible gap under any
marking, no parse errors, no console warnings. **NOT verified by play.**

**Pre-round free-roam + in-world ready-up, Local Match only — see `Checklist.md` 2.8.** User
feedback, same session: "i wanted the ready button to be in the game itself not in home screen, i
want ppl to be able to move around with no restrictions whiile waiting for ready THEN everyone
gets teleported in the right restricted area." `main_menu.gd`'s Local button now skips
`Lobby.tscn` and loads `Main.tscn` directly; characters spawn as before but
`MatchManager.begin_next_round()` is deliberately deferred until the player presses the new
`ready_up` action (bound to R), read off a new HUD prompt. `CharacterBase._is_confined_to_base()`
and `Carriable.movement_speed_scale()` are both now gated on `RoundManager.round_active` — false
until `begin_next_round()` fires — so nobody is confined and the Tsinelas Prop isn't stuck at
crawl speed during the wait. No new teleport-to-role-spawn code was needed: `begin_next_round()`
already fires `MatchManager.round_started`, which `main.gd` was already listening on to call
`_reset_world()` (repositions everyone) and `RoundManager.start_round()` (re-engages confinement)
— the exact same chain an ordinary between-round intermission already runs.

**⚠️ Host/Join deliberately NOT touched.** Both still gate behind `Lobby.tscn`'s ready-up screen
exactly as before. Extending this same free-roam-then-teleport pattern to networked play is real,
separate follow-up work — per-peer ready state would need to replicate live inside the match
scene (extending lobby.gd's existing `_rpc_set_ready` pattern into `main.gd`/a HUD component)
rather than gating scene transition from the lobby, and touches the stable peer-identity
machinery (B-21) that the current Lobby flow is built on. Not attempted blind in this pass.

**B-94 · Free-roam shipped broken — "walk around freely doesn't work, cant walk around just stuck
in place." [FIXED same session.]** A SEPARATE, pre-existing gate in
`character_base.gd::_physics_process` (Item 10 / B-37, "freeze input during the round
intermission... and before the very first round begins") froze ALL movement input whenever
`RoundManager.round_active` was false — which the free-roam window above deliberately also is.
The confinement fix alone was not enough; this gate blocked movement entirely, independent of
confinement. Fixed by additionally gating the freeze on `MatchManager.round_number > 0` (already
correctly synced to clients for networked play, no new RPC needed) — 0 only during the genuine
pre-match window (nobody has pressed ready yet), 1+ for every other `round_active == false` state
(ordinary intermission, waiting for a rematch after a match ends), which should still freeze
exactly as before. Do not simplify this back to a bare `not round_active` check.

**B-95 · The Can can fall through the floor when the LAST round of a match ends. [FIXED same
session, distinct from B-93.]** Every OTHER round transition calls `_reset_world()`
(`MatchManager.round_intermission_started`), which clears velocity per B-93 — but the match's
final round fires `match_won` instead, and nothing ever resets characters afterward.
`RoundManager.round_active` stays permanently false, the movement-freeze gate stops input, but
gravity is still applied every physics frame (deliberately, so a unit mid-jump still settles) —
with no reset ever coming again, a unit airborne right as the match ended just keeps falling under
gravity for as long as the result screen is up, long enough to tunnel through the floor's thin
collision shape. Fixed with a new `main.gd::_on_match_won_freeze_physics()` handler that zeroes
velocity on every character once, the moment `MatchManager.match_won` fires — nothing moves them
again after that since `round_active` never becomes true again for that match.

**B-96 · The Can/Taya/Attacker spawn layout was never actually role-based for Local Match — the
new free-roam window just exposed it. [FIXED same session.]** `_start_local_test()` left every
local unit at Main.tscn's own hand-authored default transforms, which predate the 2.6 role-based
`SpawnPoints` redesign entirely — before this session, `begin_next_round()` fired immediately and
`_reset_world()` (which DOES use role-based spawns) repositioned everyone before the first frame
was ever shown, so nobody had actually seen the stale defaults. With a real pre-round wait now,
they were visible and wrong: the Can nowhere near the base circle, the Attacker not facing the
Can/Taya. Fixed by calling `_place_at_spawn()`/`_role_slot()` — the exact call `_reset_world()`
already makes every round — once up front in `_start_local_test()`, for every local unit.

**Taya spawn moved to the opposite side of the Can from the Attacker.** User feedback: "the
person in same team is behind that can." `Spawn1` was at `z=+1.5` (Attacker side), now `z=-1.5`
(same yaw, so the Taya still faces back through the Can toward the attack line) — see
`build_eskinita.py`'s `Spawn0-3` doc comment.

**B-97 · The carried Tsinelas's TPP camera could end up "inside the head," and gave its player no
look control at all. [FIXED same session — B-91 only fixed HALF of this.]** Two real bugs, found
by tracing `camera_rig.gd::_update_tpp_carry_follow()` all the way through rather than guessing:
1. Its mount-height formula (`_mount_height_for(carrier.capsule_height())`) was written for a
   STANDALONE Prop mounting 1.2 units above ITS OWN short capsule; B-91 reused it against the
   CARRIER's 1.6-tall capsule instead, which resolves to the same number (1.2) but a different
   meaning — 0.4 units ABOVE the carrier's own head (head-top sits at local `+0.8` from a Person's
   origin). A spring-arm cast starting already above someone's head collapses into the first thing
   it touches, which is exactly the reported "extreme close-up on wire geometry" / "it's just
   inside the head." Replaced with a dedicated `TPP_CARRY_MOUNT_HEIGHT` (0.6, just below head
   height) instead of reusing a formula meant for something else.
2. The carried player never had ANY camera control, B-91 or not — `apply_mouse_delta()`'s TPP path
   writes `_character.rotation.y`, but `carriable.gd::_step_carried()` overwrites that same field
   every physics frame to match the carrier's hand, so the write had zero visible effect. Reported
   as "so awkward for them to be watching the gameplay happen like this" and "should be movable but
   anchored to person." Fixed with a separate look-offset (`_tpp_carry_yaw_deg`/`_tpp_carry_pitch_deg`)
   added on top of the carrier's own facing in `_update_tpp_carry_follow()` — the view starts
   anchored behind the carrier and the carried player can still swivel it from there. Resets to
   zero on drop/throw so the next pick-up starts anchored again, not wherever this player last
   looked.

**B-98 · A carried unit's ground-ring nameplate still showed, riding along near the carrier's
hand.** B-89 (earlier this project) fixed the ring's SIZE/position but never addressed the
complaint it quotes — a carried object doesn't stand on the ground, so a ground ring makes no
sense for it regardless of how correctly it's sized. Reported again this session: "the circle is
still attached to slipper even when it's held." Fixed by hiding `character_nameplate.gd`'s ring
and label outright while `Carriable.state == CARRIED`, rather than sizing them to something that
still shouldn't be there.

**B-99 · A thrown slipper could land tilted instead of flat, and tunnel through the floor when it
did.** `carriable.gd::_step_carried()` overwrites a carried unit's entire transform — BASIS
included — to the carrier's hand orientation (`CARRY_TILT_DEG`, 55°) every physics frame. Nothing
ever reset that basis on release: `_rpc_set_flying()`/`_rpc_set_loose()` only ever wrote
`global_position`, so the 55° tilt rode straight through the whole flight and into landing.
`character_visual.gd::_spin_while_airborne()`'s own rotation reset (already correct) is on the
VISUAL node, a CHILD of this transform, and could never fix a tilt baked into the parent. A capsule
resting on the floor at an angle instead of upright is exactly the kind of resolved-collision edge
case that can clip through thin geometry — matches the floor-tunnelling half of the report. Fixed
by resetting `_character.rotation = Vector3.ZERO` in both RPC handlers.

**Bounce physics tuned down — "ragdolls while flying," connected to "barely has power even during
full windup."** `BOUNCE_DAMPING` 0.45 → 0.3, `MAX_BOUNCES` 2 → 1. An early clip on nearby interior
clutter (crates, tires — up to 1.0 tall, and a throw launches around hand height) previously cost
a two-bounce sequence each keeping a still-substantial 45% of speed, which reads as chaotic and as
the whole throw losing its power, not as "bounces a bit." Checked the throw profiles'
`launch_speed` values themselves (14-23, comfortably faster than `DASH_SPEED` 14.0) and
`charge_power()`'s math (correctly reaches 1.0 at full charge) — neither looks like a numeric bug
on paper, so this is the fix that's actually justified by evidence; if throws still feel weak after
this, that needs a fresh report of exactly when (every throw, or only ones that clip something
early).

**3-2-1-GO countdown added before a (Local Match) round starts.** User request: "add a 3 2 1 timer
before each match starts too, think about how to make it look good." Sits between the ready press
and `MatchManager.begin_next_round()` actually firing — `hud.gd::show_countdown_tick()` pops each
digit in oversize and settles to normal scale (`TRANS_BACK`/`EASE_OUT`) rather than just swapping
text, in the existing `HIGHLIGHT` colour the round timer itself uses under 15s. `main.gd`'s
`_run_ready_countdown()` sequences it with `await get_tree().create_timer(...).timeout` between
ticks; `_counting_down` guards against a second `ready_up` press restarting it mid-count.

All of the above verified by render (`tools/render_probe.gd` now shows the Can correctly inside
the base circle) and the full six-command smoke gate. NOT yet verified by play.

**B-100/B-101 · The Can (or any unit) could fall through the floor, or be flung far off its real
spawn point, specifically on a ROUND TRANSITION. [ROOT-CAUSED AND FIXED — this is the real
explanation for "cann fell off map again," which B-93/B-95 did not fully cover.]** Found by
writing an actual diagnostic (`tools/render_probe.gd`'s new `round2` mode — see below) rather than
continuing to guess from screenshots, after two earlier attempts to explain the report from
code-reading alone both turned out to be incomplete. Two distinct bugs, confirmed by the probe's
console output before and after each fix:
1. **B-100.** `main.gd::_reset_world()` teleports four characters to new ROLE-based spawn points one at a
   time via a plain `position =` write. Roles swap every round, so two characters routinely trade
   spots with each other — this round's Attacker often lands exactly where last round's Attacker
   was standing. A plain position write does not itself resolve collisions, but the very next
   `move_and_slide()` does, the instant it finds two capsules deeply overlapping because the
   second character in the loop hadn't been moved out of the way yet when the first one arrived.
   Godot's own depenetration response is a genuine physics impulse, not a gentle nudge — the probe
   showed characters ending up many units off their real spawn markers, airborne, sometimes far
   enough to clear the confinement box or the floor's collision entirely.
   **Fix, and what didn't work first:** toggling each character's `CollisionShape3D.disabled`
   around the reposition was tried first and did NOT reliably fix it — disable, reposition and
   re-enable all happen within the same script frame, before any physics step, and Godot's physics
   server appears to sync only the FINAL state (enabled, new position) rather than replaying the
   toggle, so the depenetration still fired. Replaced with something purely geometric instead:
   every character is parked at a widely-separated, per-index holding spot (`y = 500 + i*20`)
   BEFORE any of them move to a real spot, so nobody can ever overlap anyone else's target or
   holding position regardless of loop order or physics-sync timing.
2. **B-101.** `Carriable.reset_for_new_round()` cleared the carry relationship (`carrier = null`, state →
   `LOOSE`) but never re-enabled the collision that gets disabled the instant a unit is grabbed
   (`_rpc_set_carried()`'s `_set_physics_enabled(false)`). A Prop that was CARRIED when the round
   ended — the common case, since the attacker is usually still holding it — came out of
   `reset_for_new_round()` marked LOOSE but with its body collision STILL disabled, free to sink
   straight through the floor with nothing to stop it. This Prop can become next round's Can.
   Fixed with an unconditional (idempotent) `_set_physics_enabled(true)` in `reset_for_new_round()`.
**New test infrastructure kept, not thrown away:** `tools/render_probe.gd` gained a `round2` mode
that drives two real round transitions (`MatchManager.begin_next_round()`,
`RoundManager.report_round_win()`, `begin_next_round()` again) without waiting out real timers or
simulating a ready-up keypress, and prints every local unit's role and position at each step —
turning "is the spawn layout right after a role swap" into a console diff instead of a screenshot
guessing game. Use it: `godot --path . tools/render_probe.tscn --quit-after 100 -- round2 <dir>`.
**Still open:** even with both fixes, the probe still shows transient chaotic positions for two of
the four units *during* the frozen intermission window itself (between `report_round_win()` and
the next `begin_next_round()`) — by the time the round actually starts (`round_active` becomes
true again) everyone is back at the correct spot, confirmed by the probe, but a player watching
the intermission may still see it happen. Not root-caused further this session; flagged rather
than guessed at again.

**Floating decals, second pass — `MARK_Y_LOW` (0.015) was STILL visibly floating once actually
looked at closely.** Lowered to `0.001`, a near-zero epsilon rather than a "safe-looking" round
number — see `build_eskinita.py`'s own updated warning comment. Verified by a fresh render; no
visible gap under the confinement square or team-side lines this time.

**Three items handed to the 🎨 DESIGN-ART lane (docs only, no code) — see `Agent_Prompts.md`'s
DESIGN-ART prompt, new items 1-3, ahead of its standing B-G environment-art queue.** From the same
playtest batch, not yet investigated or fixed by Build this session:
1. Third-person charge/windup tell — a charged throw is currently only visible to the thrower
   (FPP viewmodel + their own UI charge bar); nobody else watching that character in third person
   can see it. The moodboard's own THE ATTACKER card already specifies "charged throw (glow)" —
   this is that spec's world-space half, which `you_card.gd`'s UI-only hook was deliberately built
   to leave for Design rather than guess at.
2. "Why does the defender only have one hand" — reported with a screenshot, not root-caused.
   Genuinely unclear yet whether this is an art/animation issue or a code bug; routed to Design
   to look at rendered first, with instructions to hand it back to Build if it turns out not to be
   a "does this look right" question.
3. "Slipper still floating" re-verification — the carry-TILT rotation bug (55° not resetting on
   throw/drop) was found and fixed by Build this session, but the report may be about the carried
   POSITION (`HAND_CARRY_OFFSET`) rather than rotation, which is Design's own previously-calibrated
   number to re-measure if still wrong.

**Local Match → Single Player, planned (docs only, no code) — see `Checklist.md` 5.5 and the new
🔧 BUILD-AI brief in `Agent_Prompts.md`.** User decision: Local Match stops being a dev-only
testing harness / network-outage fallback (the old plan, `Checklist.md` 5.3) and becomes a real,
permanent single-player mode in the final submission — the human plays one unit, real AI drives
the other three (their own Prop teammate, and the whole opposing team) instead of sitting on
unbound input. No prior art for this in the codebase — the brief's main job is choosing an
architecture that doesn't fork `character_base.gd::_physics_process` into a human path and a
separate AI path, since the confinement/state-machine/round-active gating all have to keep
applying identically either way. `Checklist.md` 5.3 marked as redirected rather than deleted, with
the original text kept for history. This is planning only, explicitly per the user's own request
("on the docs can u plan how to add a new agent") — nothing here changes runtime behaviour.

**Still open, not root-caused this session:** a report of a carried tsinelas reading as
permanently frozen/slanted, and a Can appearing stuck mid-animation at the same time, with no
locomotion or spin animation visibly playing. Read `carriable.gd` (carry tilt, `_step_flying`) and
`character_visual.gd` (`_spin_while_airborne`, `_play_locomotion`, the hitstop `Engine.time_scale`
dip in `character_base.gd`) closely; nothing is obviously broken in isolation, and the leading
hypothesis (the hitstop timer's restore callback isn't `is_instance_valid`-guarded, so a freed
character could leave `time_scale` stuck low) is weakened by this being a Local Match session,
where characters aren't normally freed mid-match. Needs a human to describe what immediately
preceded the freeze next time it happens, or a longer live capture than one static frame.

### P1 — found by the design lane while measuring for checklist 1.2 (2026-07-28)

Filed, deliberately not fixed — `Concurrency_Protocol.md` §10. Full reasoning and the screenshot
evidence are in §0.11. B-81 is in the design lane's own territory and is still filed rather than
folded into an unrelated commit, because changing a hero prop's colour deserves its own commit and
its own render.

**B-81 · The tsinelas sole is painted `DEFENSE` blue, on a unit that only ever exists on
offence. [FIXED 2026-07-28]** The materials were renamed from palette tokens
(`defense`/`impact`/`highlight`) to parts (`sole`/`strap`/`post`) — a material literally named
`defense` is a bug that reads as correct in every diff, and renaming also changes the `.obj`, which
is what forces the reimport the `.mtl` alone would not. The sole was repainted off the role hue.
**Verified by render:** no role hue anywhere on the slipper.

⚠️ **The colours this fix chose are superseded — same day.** B-81 painted the sole `IMPACT` magenta
and the straps `HIGHLIGHT` yellow because they were the only non-role tokens available. The human
then supplied an asset moodboard for the prop and ruled: *"the magenta shit is just placeholder, we
can update it with the new ones."* **The slipper is now `PROP_FOAM` brown with a `PROP_WEBBING` tan
strap** (`Art_Direction.md` §1b). B-81's *rule* is untouched — brown and tan are neither role hue —
and its material-naming half stands, extended to the lata in the same pass. Do not restore magenta.
Original report follows. `tools/models/generate_all.gd::_build_tsinelas()` sets the sole material to
`UiTheme.DEFENSE` (`#0080e8`). A Prop is a Tsinelas exactly when its team is **attacking**, so the
attacking team's prop wears the defending colour — a direct breach of `Dev_Plan.md` §4.2 ("never
reuse either hue for anything else"). The moodboard disagrees independently: **THE SLIPPER's card
accent is magenta**, as is **THE CAN's**. Visible in this pass's `viewmodel_tpp.png` as a bright
blue slab.
*Root cause of the error:* `Art_Direction.md` §2's palette table assigns `DEFENSE` to "Can
body, **tsinelas sole**". **That table is wrong and the rule is right.**
*Severity:* P1 — it teaches the player the wrong colour language on the most-looked-at object in
the game.
*Fix:* repaint the sole off the role hue, keep the straps readable against it; regenerate; render
both viewmodel shots. Correct the brief's table in the same commit. The lata was **not** in scope
here — a blue can on the defending side is consistent, and it renders well. *(It came into scope
later the same day for a different reason: the Sarsi livery moodboard. It is still blue.)*

**B-82 · `Main.tscn`'s floor top surface is `y = +0.5`, not `y = 0` — and two docs say
otherwise. (NEW)** `Floor` and its `CollisionShape3D` carry **no transform**, and the shape is a
`BoxShape3D` of `(40, 1, 40)`, so the slab spans `y = -0.5 … +0.5`.
`Art_Direction.md` §4.1 and `Checklist.md` both assert the top surface is `y = 0` and
the box extends to `-1`. Both are wrong, in the same direction, and §4.1 offers it as the
authoritative fact to place map geometry against.
*Consequence:* `Main.tscn` places all four units at `y = 1.0`. With a 1.6 capsule that puts the
capsule floor at `0.2` — **0.3 units inside the slab** — so every unit begins each match
interpenetrating the floor and depenetrates on the first frames.
*Severity:* P1 — it is load-bearing for 2.2, and any kit piece placed against the documented
`y = 0` sinks half a metre.
*Fix:* correct both docs; then either move `Floor` to `y = -0.5` or drop the spawn `y` to `0.8`.
The scene edit is the **build lane's** (`Main.tscn` is shared and currently locked).

**B-83 · The boundary colliders are 20 units outside the floor they are meant to
contain. (NEW)** `Bounds/Wall{North,South,East,West}` sit at `±41` with `BoxShape3D` half-depths
of 1, so their inner faces are at **`±40`**. The floor ends at **`±20`**. There is a 20-unit ring
of nothing on every side that the walls do not enclose: a player runs off the slab edge and falls
past them to the `KillPlane`.
*Severity:* P1 — the arena has no working boundary at all, which is a different and worse problem
than §0.10's "the walls are invisible".
*Fix:* belongs to **2.2**, not to a patch. Eskinita's dressed boundary and its colliders both go at
`±20`, and `Main.tscn`'s `Bounds` node dies with the grey box. Specified in
`Art_Direction.md` §4.

**B-84 · The generator's determinism test cannot pass on a Windows checkout, and the generator is
not at fault. (NEW)** `.gitattributes` declares `*.obj text` and `*.mtl text`, and `core.autocrlf`
is `true` on this machine, so git checks those files out **CRLF** while `FileAccess.store_line()`
writes them **LF**. Running `generate_all.gd` therefore leaves `assets/models/*.obj` and `*.mtl`
showing as modified in `git status` even when the bytes are semantically identical.
*Measured this pass:* two consecutive runs, then `git diff --numstat` on the rewritten files —
**empty, with and without `--ignore-cr-at-eol`.** Zero lines added or removed. **The generator is
deterministic.** What is broken is the test.
*Why it matters:* "run the generator twice and `git status` must be clean" is the **only objective
acceptance criterion the entire `M-` block has**, and 2.1b is about to add ~26 more generated
meshes to it. An acceptance test that fails for a reason unrelated to what it measures is one
nobody will keep running — and this is the same class of problem as B-71, which
`Concurrency_Protocol.md` §7 already promoted to a prerequisite for two-lane working.
*Fix:* pin the generated formats: `*.obj text eol=lf` and `*.mtl text eol=lf` in `.gitattributes`,
then re-normalise once (`git add --renormalize .`). **`.gitattributes` is a 🔧 BUILD-lane file** —
filed, not fixed. Fold into **5.4**, which is already the item for "stop the acceptance test lying".

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
files.
**[FIXED]** F-1, v4.5. The T-block work already brought the stamp into sync with real changes
(v4.0 through v4.4). F-1 set 1920×1080 + stretch mode and bumped to v4.5, and added a rule to
`Dev_Plan.md §6` that docs-only commits naming a version must still bump the file.

**B-71 · Tracked `.import` UIDs regenerate on any cache rebuild. (low)** Opening the
project on a second machine rebuilt `.godot/` and reassigned
`assets/characters/persons/Textures/colormap.png.import`'s `uid://` — a tracked file, so it
surfaced as a permanent dirty working tree until committed (`5a2e0e0`). Nothing references that
texture by UID, so this instance was inert, but it will recur on every fresh clone and machine
switch, and it is exactly the kind of noise that makes a "regenerate and check `git status`"
acceptance test unreliable. *Decision owed:* either accept the churn, or stop tracking `.import`
UIDs.
**[DECIDED]** checklist 5.4, this pass: **accept the churn.** Untracking `.import` entirely trades
a known, narrow annoyance for an unknown one — some `.import` files may carry hand-tuned settings
(compression, filters) that a machine's first re-import wouldn't reproduce identically, and nobody
has audited which ones. Formalizing what `Concurrency_Protocol.md` §7 already had lanes doing as an
interim workaround into the standing rule, not just a two-lane-period one: **before any commit that
touches `assets/`, run `git diff --cached -- '*.import'` and unstage any file whose only change is
its `uid://` line.** The generator-determinism test (M-block) already only checks tracked `.obj`/
`.mtl` output, which B-84 (above) just made reliable — a stray `.import` UID diff was never part of
that check's own pass/fail and doesn't need to become one.

### P1 — found and fixed this pass (2026-07-27 audit)

All four were found by **rendering the running game** (`tools/render_probe.gd`), not by reading
code. Every one of them had passed a headless load, a `--quit` smoke test and a code review.

**B-77 · `Main.tscn` threw a script error on every single launch. (NEW)**
`Invalid access to property or key 'visible' on a base object of type 'Nil'` at
`main.gd:293`. Godot delivers `NOTIFICATION_APPLICATION_FOCUS_IN` once at **window creation**,
before `_ready()` has run, so the B-72 mouse-recapture branch dereferenced `pause_root`,
`match_result` and `settings_panel` while all three were still null. Beyond the log line, the
handler never reached its `MOUSE_MODE_CAPTURED` call, so the first focus-in never recaptured the
cursor. Present since B-72 landed.
*Severity:* P1 — non-fatal, so the scene loads and plays straight through it, which is exactly why
it survived this long. It also appears in an exported build, in front of judges.
**[FIXED]** v4.23. Guarded on `is_node_ready()`. `_ready()` sets the initial mouse mode itself
(`main.gd:120`), so declining to recapture before it has run is correct behaviour rather than a
workaround. Verified: 400 real frames of `Main.tscn` now produce no output at all.

**B-78 · The FPP camera sat above its own character's head. (NEW)** `FppPivot` was at
`y = 1.55`, a guess at eye height made before any Person model existed. Measured in-engine, the
Person occupies `-0.800 .. +0.076` (body) and `+0.017 .. +0.798` (head) in CharacterBase-local
space — so the camera was **0.752 above the top of the head**, and a first-person capture showed
nothing but sky and horizon. This is the concrete cause of "you can't see your arms in FPP", which
§0.8 diagnosed correctly in direction and estimated at `y ≈ 0.88`; the real figure is `0.798`.
**[FIXED]** v4.21, `y = 0.45` — 55% up the head mesh, which `_apply_fpp_self_hide` already hides.

**B-79 · `HAND_CARRY_OFFSET` was applied at 2.38×. (NEW)** The `HandPoint` node hangs off a
`BoneAttachment3D` whose parent chain runs through the `Skeleton3D` and therefore already carries
`PERSON_SCALE`. Writing the constant straight onto it multiplied every component by 2.38, parking a
carried tsinelas at CharacterBase-local `(-1.00, +1.12, -0.45)` — a metre out to the character's
left and above the top of its own head. The constant's own doc comment describes a world-space
offset, so the code never did what the comment said.
**[FIXED]** v4.21. Divided by `PERSON_SCALE` at the point of use and retuned against renders.
*Still open behind it:* the tsinelas mesh is **1.35 units against a 1.598-unit Person**. That is a
prop-scale design fork, not a bug — `Checklist.md` 1.2.

**B-80 · U-6's ground ring was not on the ground, was the wrong colour, and never refreshed.
(NEW)** Three defects in one node. (a) The ring sat at `y = 0.03` against a capsule whose floor is
`-0.8`, so it drew a hoop around the character's chest — and around a carried tsinelas, in mid-air
beside its carrier's head. (b) Its colour keyed off `is_person`, making every Person orange and
every Prop blue on both teams at once, which breaks `Dev_Plan.md` §4.2's hard rule that orange and
blue mean OFFENSE and DEFENCE **project-wide** and directly contradicted the HUD panel above it.
(c) Resolved once in `_ready()`, so it was correct for round 1 and wrong for rounds 2–5 —
`team_is_can_side` flips every round. The floating tag additionally sat 1.4 units above the head
with no distance fade, so four billboards hung permanently across every first-person view.
**[FIXED]** v4.22. Ring to `-0.78`, colour derived from `team_is_can_side` (the same derivation
`you_card.gd` and `hud.gd` already use — not a third copy), refreshed on
`MatchManager.round_started`, tag to `1.05` with a 12 m → 18 m fade, and `A1`/`A2`/`B1`/`B2` +
`DEF`/`OFF` text per §4.5.

> **The pattern behind B-78, B-79 and B-80(a):** `CharacterBase`'s origin is the **centre** of a
> 1.6-unit capsule, so a model's feet are at `-0.8` and not at `0`. Four separate nodes were placed
> against an imagined character standing on `y = 0`. Check this before positioning anything else on
> a character.

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
**[FIXED]** v4.2, exactly as prescribed: the FLYING branch of
`Carriable.physics_step()` zeroes velocity and returns while `not
RoundManager.round_active`, so a slipper in the air at the bell hangs where it is
until `reset_for_new_round()` puts it back on the floor. The round is already
decided by then (`report_round_win` has fired), so freezing the arc cannot change
an outcome. **Untested by a human — nobody has thrown one at the bell.**

**B-75 · Nothing drops a carried slipper when its carrier is staggered, downed
or sealed. (NEW, untested)** `Carriable.host_drop()` exists and is correct, but
the only things that call it are a freed carrier and the round reset. A taya
tagging the attacker mid-carry therefore does not make them drop it, which is
most of the point of tagging. *Fix:* call `host_drop()` from the host when a
carrier's state leaves NORMAL. **Do this in `carriable.gd`/`carrier.gd`, not in
`character_base.gd`** — that file must not learn what carrying is.
**[FIXED]** v4.1. `carriable.gd` subscribes to the carrier's existing
`CharacterBase.state_changed` while (and only while) the slipper is CARRIED, and
calls `host_drop()` on any state that is not NORMAL. Nothing was added to
`character_base.gd`. The watch is dropped in `_rpc_set_flying` as well as on
landing/reset — otherwise tagging the thrower mid-flight would have landed the
slipper in mid-air. **Still `[~]`-grade: no human has been tagged mid-carry.**

**B-76 · The local-test flow gives every Prop `quick_stand.tres`, so no slipper
has a real throw profile.** `main.gd`'s `PROP_ABILITY` is Quick Stand for
every networked Prop (B-04's stopgap), and `Main.tscn` hardcodes the same for
`TeamAProp`. Quick Stand has no `get_throw_profile()`, so every throw falls back
to `throw_default.tres` and **the three Tsinelas identities are unreachable in
game.** Not a defect in the new code — it is B-24's missing character-select
surfacing through it. *Fix:* character select, or an interim per-side default.
**[FIXED]** checklist 0.2, this pass. Turned out worse than stated: `is_can`
flips every round (`_reset_world`) and nothing ever re-picked a Prop's ability
on that flip, so even a correct spawn-time assignment would have gone stale one
round later — same trap as B-42/B-80(c). `_prop_ability_for(is_can, team)` now
runs at every spawn path AND every round reset. Team A's Tsinelas is Bakya Bash,
Team B's is Flick Dash — two of the three identities, chosen for contrast; a
single 2v2 sitting cannot reach all three without 3.3 (character select).
Verified by running a headless probe through three consecutive
`MatchManager.begin_next_round()` calls and dumping each Prop's ability class —
correct at every transition, and `.duplicate()`d (not shared) confirmed too.

**B-85 · Headless-only: a role-swap round transition throws three
`material_get_instance_shader_parameters` / "Parameter material is null"
errors. (NEW, unconfirmed in real rendering)** Found while writing a headless
verification probe for checklist 0.2: instantiate `Main.tscn` and call
`MatchManager.begin_next_round()` — the errors appear right after the first
call that actually flips a role (round 1→2), not on the initial round-1 setup.
Almost certainly `character_visual.gd`'s Can↔Tsinelas model swap touching a
shader-based material that Godot's **dummy** (headless, no GPU) rendering
driver can't resolve — possibly the same material B-81 (this file, above)
just touched fixing the tsinelas's role-colour paint, though this pass didn't
chase that far. `tools/render_probe.gd`'s real-device 400-frame runs through
round 1 show nothing, and B-77/78/79/80's own lesson (`--headless` never
renders a pixel) cuts the other way here too: this may be a dummy-driver
artifact with no real-render equivalent, not a shipped-build defect. *Not
fixed, not chased further* — outside checklist 0.1/0.2/0.3's scope
(`character_visual.gd` is Design lane's file besides), and I could not
reproduce it with a real rendering device in the time I had. Flagging with an
exact repro rather than either silently fixing something in someone else's
file or silently dropping it.

### P2 — open, carried over from the archive

- **B-13 · The match starts before anyone joins.** `_start_hosting()` calls `begin_next_round()`
  immediately. The lobby is the real fix — **U-4**.
- **B-42 · Local Bo5 past round 1 depends on the debug switcher.** Mitigated, not fixed: the
  switcher makes it playable, but the Prop that becomes the Can in round 2 is `player_id = 3`,
  permanently unbound. Dies with Local Match in Phase 6.
- **[FIXED] B-58 · `ArenaCamera._process` still does full follow-cam work every frame while retired.**
  Closed by **A-2** (v4.8) — node deleted from Main.tscn, script moved to tools/.
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
  **[FIXED]** v4.3 — the decision was made in §0.7 (it is IN) and it is now **built**, as
  **T-3**: the taya holds `grab` by their own downed lata to stand it back up. Still absent
  from the GDD; fold it into Section 3's round flow, which §0.8 already flags as owed.
- **B-65 · No reconnect path** — a rejoining player can come back as a different team and role.
  **[FIXED]** 2026-07-28, `Checklist.md` 4.3 — a stable per-instance token (`NetworkManager.
  local_player_token`) replaces the peer id as the identity `main.gd` keys team/role off, and a
  new host redirect (`NetworkManager.match_in_progress` / `_rpc_route_to_running_match`) gets a
  mid-match rejoin out of `Lobby.tscn` and back into `Main.tscn` at all, which nothing did before.
  See this file's session log and the full account near this section's end.

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

## 4. Execution Queue — task detail, acceptance criteria, and model routing

> **Ordering and progress live in [`Checklist.md`](Checklist.md), not here.** This section is the
> detail behind those lines: what each task actually involves, what "done" means for it, and what
> the previous passes already learned about the code it touches. The `Checklist ref` column below
> is the link between the two.

### 4.0 Model routing — who works this queue

Every remaining item, the model it runs on, and why in one line. The routing survives independently
of the briefs; each brief repeats its own line in its opening block.

> **Running more than one agent at once?** Read
> **[`Concurrency_Protocol.md`](Concurrency_Protocol.md)** first. It defines four lanes (two that
> write code, two that write only docs), a hard path-ownership table, an optimistic lock for the six
> genuinely shared files, an amendment to the version-bump rule, and the six-command smoke gate every
> lane runs before merging. Two agents in one working directory will corrupt each other's Godot
> import cache; two agents bumping `config/version` will conflict on every single merge.

**The split, stated once.** *Sonnet* takes anything whose hard question is "does this code do the
right thing" — gameplay systems, networking, physics, the carry/throw state machine, generator
scripts, bug fixes, doc reconciliation, playtest-and-retune passes. *High* effort specifically
where a subtle mistake is expensive to unwind: shared scenes (`Main.tscn`, `CharacterBase.tscn`),
the networking and authority model, and the host-authoritative carry transitions. *Medium* is right
for contained, well-specified work. *Opus* takes anything whose hard question is "does this match
the moodboard" — silhouette and proportion, how a generated mesh should actually look, screen
layout, environment art direction, and the presentation package. Where a workstream needs both
hats it is **split into two briefs** rather than handed to one agent wearing the wrong one.

**Opus is deliberately scarce.** Only four items on the whole remaining plan are routed to it —
prop scale (1.2), the environment kit's art direction (2.1a), the Eskinita layout and boundary
dressing (2.2), and the demo/trailer direction (6.2). Those are the four places where the
difficulty is judgement under ambiguity rather than execution. Everything else, including the
second map, the Person restyle, the logo swap and the video edits, is Sonnet work following a
specification Opus already wrote.

| Checklist ref | Task | Model | Effort | Why |
|---|---|---|---|---|
| 0.1 | HUD charge / hold / reset-channel meters | Sonnet | medium | Contained UI wiring against three signals that already exist |
| 0.2 | Per-side default Prop ability (B-76) | Sonnet | medium | Data plumbing in `main.gd`; well specified |
| 0.3 | Base circle + throwing line decals | Sonnet | medium | Two decals in a scene, explicitly temporary |
| 0.4 | **Play a full Bo5** | 🧑 human | — | No model can feel a charge time |
| 0.5 | Retune the T-block from playtest notes | Sonnet | **high** | Touches `carriable.gd` + `carrier.gd` + profiles at once; host-authoritative transitions break subtly |
| 1.1 | Display typeface decision | 🧑 human | — | Licence + brand call, correctly gated |
| 1.2 | Prop scale — lata and tsinelas | **Opus** | **high** | "How big should a hero prop be" is a proportion judgement, not a number |
| 1.3 | Person ability roster | 🧑 human | — | Design scope call |
| 2.1a | Environment kit — art direction, piece list | **Opus** | **high** | "Does this read as an eskinita" is the whole question |
| 2.1b | Environment kit — generator code | Sonnet | medium | Determinism and collision; the shape is already specified by 2.1a |
| 2.2 | Eskinita — layout, boundary dressing, markings, skybox | **Opus** | **high** | Composition and art direction; the largest single visual lever |
| 2.3 | Persons — moodboard restyle | Sonnet | medium | Execution once 2.1a has specified the palette: retint materials, parent two accessory meshes |
| 2.4 | Bayan Plaza | Sonnet | medium | 2.2 solves the layout, kit and boundary technique; map two applies it |
| 3.1 | Land the typeface (F-2) | Sonnet | medium | Mechanical once 1.1 exists |
| 3.2 | Logo lockup (M-8) | Sonnet | medium | A `TextureRect` swap if the Canva export exists. **Escalate to Opus only if it doesn't** — hand-constructing the can-lid "O" is drawn art |
| 3.3 | Character select (U-5) | Sonnet | medium | Data + a screen on existing chrome |
| 3.4 | Off-screen indicators (U-6b) | Sonnet | medium | Screen-space maths against an existing derivation |
| 4.1 | Audio — whole workstream | Sonnet | medium | Sourcing, wiring, licence recording; no shared-scene risk |
| 4.2 | Remote movement interpolation | Sonnet | **high** | Sits directly on the replication model |
| 4.3 | Rejoin identity (B-65) | Sonnet | **high** | Authority model; a wrong token scheme is expensive to unwind |
| 4.4 | Balance pass, both modes | Sonnet | medium | Numbers with a written rationale, after 0.4 |
| 4.5 | Hitstop | Sonnet | medium | Contained feel work |
| 5.1 | Install export templates | 🧑 human | — | Environment, not code |
| 5.2 | Produce and launch a release build | Sonnet | medium | Mechanical once 5.1 is done |
| 5.3 | ⚠️ Redirected — see 5.5 | — | — | No longer "strip Local Match"; superseded by Single Player, `Checklist.md` 5.3/5.5 |
| 5.5 | Rename to Single Player + AI for the other three units | Sonnet | **high** | No prior art for AI in this codebase — the hard part is the architecture choice, not the behaviour |
| 5.4 | `.import` UID churn (B-71) | Sonnet | medium | Repo hygiene decision |
| 6.1 | Real-device LAN test | 🧑 human | — | Four laptops in a room |
| 6.2 | Live-demo script + trailer beat sheet | **Opus** | **high** | What to show, in what order, in 90s, to people who will never play it — editorial judgement under a hard constraint |
| 6.3 | Trailer — capture and edit | Sonnet | medium | Executes 6.2's shot list; `tools/arena_camera.gd` is the preserved broadcast cam |
| 6.4 | Demo video — capture and edit | Sonnet | medium | A narrated walkthrough against 6.2's script |
| 6.5, 6.8 | Synopsis draft, Form 03 licence register | Sonnet (📦 producer lane) | medium | Drafting and bookkeeping; the human approves and signs |
| 6.6, 6.7, 6.9 | Forms 01–02 signature, portal upload | 🧑 human | — | Signing a declaration of originality and submitting are not a model's to do |
| — | Verification of everything above | Sonnet (🔬 QA lane) | medium | Runs the smoke gate, plays what can be played, files `B-` numbers. **Never fixes them.** |

---

### 4.1 Task detail (historical numbering preserved)

Written 2026-07-27. **The Q-1 → Q-10 queue is retired**; all ten shipped, v2.4 → v3.4. The `T-`,
`F-`, `A-` blocks below are **complete**; `M-` and `U-` are partially complete. Their entries are
kept because they carry the traps and the reasoning the next agent would otherwise re-derive —
read the block for anything you are about to touch, even where the box is ticked.

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

#### T-3 · B-46 lata reset channel `[~]`

Landed v4.3, built where the plan said: `carrier.gd` runs the channel
(`_step_reset_channel`, `RESET_CHANNEL_TIME = 1.5s`), `carriable.gd` owns the
rule (`can_be_reset_by`) and the host-side apply (`host_reset_upright`), and the
apply calls `self_right()` (Option B) or the new `clear_dent()` (Option A) and
nothing more. No round-win logic moved: `RoundManager` already re-evaluates off
`dents_changed` / `state_changed`, so dropping back below the threshold needs no
cooperation from the channel.

Decisions taken while building, each of which could reasonably have gone the
other way — revisit if play disagrees:

- **DOWNED is resettable, SEALED is not.** There is one tracked Can per round and
  sealing it ends the round (`round_manager.gd::_on_tracked_can_state_changed`),
  so a channel that un-sealed would be reversing a decided round from the wrong
  file. Under Option A the same logic makes `dents == MAX_DENTS` non-resettable.
- **Own team only**, mirroring `can_be_grabbed_by()` and built on the same
  `CharacterBase.team`. No second team system.
- **Hands must be empty.** You cannot right the lata while holding a slipper.
- **The apply is `rpc_id`'d to the Can's own authority**, not broadcast — the
  idiom `hitbox.gd`/`_apply_hit_result` already uses. Broadcasting would have
  every peer write state it does not own and the `MultiplayerSynchronizer` would
  overwrite it immediately.
- **Cancel-on-interrupt needed its own signal hookup.** `input_step()` stops
  being called the moment the Person leaves NORMAL, so without watching
  `state_changed` the timer would freeze and resume rather than reset.

`[~]` not `[x]`: the rules and the apply are verified (a throwaway headless
harness exercised both game modes, the ownership refusal and the host-side
rejection — 16/16), but **the input half is not**. Nobody has held the button for
1.5s, been tagged out of a channel, or seen the `GrabArea` overlap search find a
lata in motion. `RESET_CHANNEL_TIME` is a guess.

**No progress bar exists.** `reset_channel_changed` is emitted 0..1 and nothing
consumes it — exactly like `charge_changed` and `held_changed`, which the HUD
also still ignores. All three are U-1's job.

#### T-4 · Retire the old fake throw `[x]`

Done v4.4. The question was whether the orphaned offence branch was a feature or
dead code; **the answer taken was both, split apart.**

- **As a throw it is dead code** and actively harmful — a 0.75m pulse blinking on
  4m ahead of an attacker is the exact thing Task 0 removed. **Deleted**, along
  with the `throw_range` / `throw_radius` / `throw_duration` exports (none were
  serialised in `person_action.tres`, so no resource churn).
- **As a Person's empty-handed action it is a real need.** An attacker whose
  slipper is on the ground is mid-scramble with the taya closing, and leaving
  them no action at all is worse than the fake throw was.

So `person_action.gd` is now one behaviour for every Person regardless of side: a
short Tag. `character_base.gd`'s existing `not _carrier_is_holding()` gate
already means a Person holding a slipper never reaches it. Header rewritten;
`ability_name` in the `.tres` corrected from `"Tag / Throw"` to `"Tag"`.

⚠️ **Balance change, called out deliberately because a playtest may want it
back:** an attacking Person's reach drops from 4.0 to 1.5, since 4.0 was the
reach of a ranged attack that no longer exists. Reversing it means giving the
offence side its own range export again; nothing else depends on the
distinction.

`[x]` rather than `[~]`: this item was "decide, then document or delete", and
both halves are done and verified by grep + a clean load. The Tag behaviour it
leaves behind is old code that predates this queue, unchanged.

### F — Foundation (do these first; everything else assumes them)

#### F-1 · Set the base resolution and stretch mode, and reconcile the version stamp `[~]`

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
the viewport. Menu and HUD both stamp the current build version.

**[DONE]** v4.5. `[display]` section added. B-70 fixed. Dev_Plan §6 "Build version" note added.
Version bumped from 4.4 → 4.5 with this change. Step 3's "Set version to 4.0" instruction was
superseded — T-block commits already consumed 4.0 through 4.4, so the correct next version is
4.5. Step 2 (open existing UI scenes and confirm no layout drift) is `[~]`: no human has launched
and resized the window.

**Commit:** `Set the 1920x1080 base resolution and stretch mode, fix B-70 (v4.5)`

---

#### F-2 · Land the display typeface `[~]` [DONE for the display face @ v4.21]

**Read §0.5 first.** Darumadrop One landed at v4.21 with an explicit human yes and its OFL
licence. Steps 1, 2, 4, 5 and 7 are done; **step 3 (a separate body/caption face) is still
open** and still needs a yes before any second binary enters the repo.

Original steps, for the body face that is still outstanding:

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

#### F-3 · A release export, so release-only bugs are testable `[~]`

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

**[DONE @ v4.10]** `export_presets.cfg` created (Windows Desktop, x86_64, Release-compatible).
`export_presets.cfg` un-ignored from `.gitignore`; `build/` added to `.gitignore`.
`tools/export.md` documents the one-liner export command and template install step.
`[~]` not `[x]`: Godot export templates are not installed on this machine
(`%APPDATA%\Godot\export_templates\4.7.1.stable\` absent) so the `.exe` could not be
produced and launch-confirmed. Install templates via `Editor → Manage Export Templates`
then run the command in `tools/export.md` to complete the acceptance test.

---

#### F-4 · Reconcile `Dev_Plan.md` to the code `[x]`

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

#### A-1 · Enforce the camera rule structurally `[~]`

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

**[DONE]** v4.7. Assert added after `_mode` derivation in `_ready()`. Comment added above `_mode`
var declaration confirming it is never written outside `_ready()`. §3.3.1 enforcement grep added
to `Dev_Plan.md` §3. `Crosshair` `Control` + centered `Label` ("+") added to `HUD.tscn`, hidden
by default; visibility driven from `you_card.get_local_character().is_person` in
`hud.gd::_process()`. `YouCard.get_local_character()` public helper added so `hud.gd` reads the
cached scan result rather than duplicating it. `[~]` not `[x]`: the assert and grep are verified
by code inspection only — the crosshair has not been confirmed visible/hidden in a running Local
Match by a human.

**Commit:** `Enforce the FPP/TPP directive in code and add the FPP-only crosshair (v4.7)`

---

#### A-2 · Delete the scene-level camera `[~]`

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

**Commit:** `Fix B-58: delete the retired scene-level camera, park the script in tools/ (v4.8)`

**[DONE]** v4.8. Camera3D node deleted from Main.tscn. arena_camera.gd moved to
tools/. Six call sites removed from main.gd. kill_plane.gd and character_base.gd
comments updated. B-58 closed.

---

#### A-3 · Fix B-67 — Local Match drives the wrong unit in a release build `[~]`

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

**[DONE]** v4.6. Data fix only: `TeamAPerson.player_id = 1`, `TeamAProp.player_id = 2` in
`Main.tscn`. `main.gd` header comment corrected. `debug_player_switcher.gd` comment at `:33`
extended to note that all three sources (baked ids, switcher defaults, `_start_local_test()`)
must stay in step. `[~]` not `[x]`: no release build exists yet (F-3 is still open), so the
actual acceptance test (run the `.exe`, check YOU card reads PERSON) is unverified.

**Commit:** `Fix B-67: release-build Local Match drove the Can from the Person's camera (v4.6)`

---

#### A-4 · Fix B-68 and collapse `_reset_world()` `[~]`

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

**[DONE @ v4.9]** B-68 fixed and B-69 collapsed in one edit. Both networked and local
branches now build a `{character, team, is_person, slot}` roster and share one loop.
Networked slot = `_peer_join_index.get(peer_id, 0)` (stable across disconnect/rejoin).
Local slot = `_local_roster` index (unchanged ordering, matches SPAWN_POINTS 1:1).
`RoundManager.clear_tracked_cans()` / `register_can()` unified into the same loop.
Acceptance test pending human verification.

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

#### M-2 · The Lata (can) — three states `[x]`

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
2. **Materials named for the PART, with their colours taken from `UiTheme` constants so `.mtl` and
   theme cannot drift:** `aluminium` / `aluminium_shade` (lid, rolled rim, base crimp, pull tab),
   `body_bright` / `body` / `body_deep` (the banded blue gradient), `wave` (the white band) and
   `sail` (`PROP_SARSI_RED`). **Sarsi livery, per the 2026-07-28 asset moodboard** — see
   `Art_Direction.md` §1b. *(This step used to specify a blue body with a yellow `highlight` label
   band and an `ink` rim, and materials named after tokens. Both are gone: the livery changed with
   the moodboard, and a material called `defense` on a label is a bug that reads as correct in
   every diff — the same rename B-81 made on the tsinelas.)*
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

**[DONE @ v3.7]** Landed in commit 50ec425. `generate_all.gd` has the full profile-and-revolve
body. Three dent states generated via `_apply_dents` deform callable. `CanVisual.tscn` updated to
use `lata.obj`. Dent mesh swap wired in `character_visual.gd::_on_dents_changed` /
`_refresh_can_damage`. Downed tilt (78° on 0.28s Back/Out tween) in `_refresh_downed_tilt`. Walk/run
locomotion also added in the same session. Acceptance test pending human play session.

**[RE-LIVERIED 2026-07-28]** Same profile, new skin, per the Sarsi asset moodboard. The base,
shoulder, rolled rim and now-flat lid are still revolves; **the printed wall between them is no
longer one** — `_lata_wall()` emits it strip by strip as stacked layers sharing boundary functions,
because a sail is not rotationally symmetric and `add_revolve` can only paint full rings. Read that
function's header before touching it: the sail is *the wall in a different colour*, not a decal
shell, specifically so a dent through it deforms it instead of shearing it off into mid-air. A pull
tab was added to the lid, and the lid was flattened from its slight dome so the tab makes contact
across its whole length. Dent depth re-measured after the rebuild: 0.027 world units, against 0.029
before — preserved. Verified by render at 0.85 and at match distance.

---

#### M-3 · The Tsinelas (slipper) `[~]`

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
3. Materials named for the PART: `outsole` / `foam` / `footbed` (`PROP_FOAM_DARK` → `PROP_FOAM`),
   `strap` and `post` (`PROP_WEBBING`). **Worn brown foam with a tan webbing Y-strap, per the
   2026-07-28 asset moodboard** — see `Art_Direction.md` §1b. *(This step used to specify a
   `defense` sole with an `impact` strap. The blue sole was B-81 — a role hue on an offence-only
   prop — and the magenta that replaced it was explicitly a placeholder.)*
4. Keep the 1.35-unit length. Same `_align_to_capsule_floor()` re-verification as M-2 step 6.
5. **Orientation matters here in a way it did not for the can.** The character faces −Z
   (`character_base.gd`'s `look_at()`); model the slipper toe-forward along −Z so a thrown
   slipper spins around a sensible axis and the TPP camera sits behind the heel, not the side.

**Acceptance:** recognisably a tsinelas from any angle at TPP distance. Dash (LShift as the
Tsinelas) and it leads with the toe. Round-swap to Can and back and the mesh follows.

**Commit:** `Model the tsinelas — extruded sole, real Y-strap (v4.9)`
[DONE @ v4.12] Generated tsinelas.obj via `_build_tsinelas()` in `generate_all.gd`: 12-point
extruded sole, 8-segment toe-post knob, two Y-strap quads. TsinelasVisual.tscn replaced with a
single MeshInstance3D referencing the .obj. Geometry is deterministic (second headless run clean).

---

#### M-4 · Flat-shaded toon material pass `[~]` [DONE @ v4.11]

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

#### U-1 · Rebuild the HUD to the moodboard `[~]`

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

#### U-2 · Main menu and pause to the moodboard `[~]`

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

**[DONE @ v3.8]** `assets/ui/blueprint_grid.gdshader` and `assets/ui/card_fold.gdshader` created. `MainMenu.tscn` Background switched to a ShaderMaterial with the blueprint grid. `FoldCorner` Control (16×16, bottom-right anchor, mouse_filter=ignore) added as a direct child of `TitleCard` and `PlayCard` with the fold shader. `KeywordSpacer` + `KeywordStrip` (Caption variation, centred) appended to `TitleCardContent` after `QuitButton`. `FoldCorner` added to the pause `Card` in `Main.tscn`. `[~]` not `[x]`: F-2 (display typeface) is still blocked on a human licence decision, and M-8 (logo asset) has not landed — steps 4 and 5 of U-2 are open. No human has visually verified the grid or triangle on screen.

---

#### U-3 · The role-swap intermission card `[~]`

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

**Commit:** `Add the moodboard role-swap intermission card (v4.18)`

**[DONE @ v4.18]** `scenes/ui/RoleSwapCard.tscn` + `scripts/ui/role_swap_card.gd` created.
`RoleSwapCard` connects to `MatchManager.round_intermission_started` and `round_started`
directly. Timeline: 0.0s result banner, 1.2s panels slide in (BACK/EASE_OUT tween, 0.5s),
3.5s FIGHT wipe label, hidden on `round_started`. Panels start off-screen (±700px from
centre) and animate to ±250/30px; `_on_round_started` resets offsets for the next
intermission. `HUD.tscn`: `RoundBannerLabel` removed, `RoleSwapCard` instanced as last
child, `load_steps` bumped 5→6. `hud.gd`: `show_round_banner()`, the `round_banner_label`
`@onready`, and its two `visible = false` calls all removed. `main.gd::
_on_round_intermission_started`: `hud.show_round_banner(...)` call and its local variables
removed; parameter `can_team_won` prefixed with `_` since it is now unused here (consumed
by RoleSwapCard instead). `[~]` not `[x]`: no human has won a round to see the animation
play.

---

#### U-4 · The lobby `[~]`

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
**[DONE @ v4.13]** `scenes/ui/Lobby.tscn` + `scripts/ui/lobby.gd` added. Host/Join
in `main_menu.gd` redirected to Lobby. Lobby starts ENet (host_game/join_game),
shows peer list with team/role, ready-up per peer, host-only Start (disabled until
all connected peers ready and ≥2 connected). `main.gd` patched with two is_networked()
guards so host_game()/join_game() are not double-called when arriving from the lobby,
and _start_hosting() now iterates connected_peer_ids to spawn all pre-lobby peers.
B-65 (rejoin identity) is noted but not attempted here — needs a stable player token.

---

#### U-8 · Sync the host's map and mode to joining clients `[ ]`

**Every peer picks its own map and mode, and nothing reconciles them.** `GameLaunch.selected_map`
and `GameLaunch.game_mode` are set locally by whoever touches the GAME screen. A client that
toggles MODE to Dents, or picks Bayan Plaza, then joins a host running Capture on Eskinita, keeps
its own values: `main.gd` reads its local `GameLaunch` on the way into `Main.tscn`, so the two
peers load different geometry and score by different rules for the whole match.

Not a UI bug — the picker is wired correctly on both sides. The handoff is what is missing:
`lobby.gd::_rpc_begin_match()` carries no payload, so the host's choice never leaves the host.

Steps:

1. Give `_rpc_begin_match` the host's `selected_map` and `game_mode` as arguments.
2. Every peer writes both into its own `GameLaunch` **before** `change_scene_to_file`, so
   `main.gd` reads the host's values rather than its own. It is `call_local`, so the host takes the
   same path and there is no branch to keep in sync.
3. Show the host's pick to joiners while they wait — a client currently sees whatever it last
   selected, which is exactly the disagreement this fixes. Disable the arrows for a joined client
   and mirror the host's values via the existing `_rpc_sync_state` snapshot.

**Acceptance:** a client picks Bayan Plaza + Dents, joins a host on Eskinita + Capture, and both
peers load Eskinita and score by Capture. The client's GAME screen shows the host's map and mode
while it waits in the lobby rather than its own.

**Commit:** `Sync the host's map and mode to joining clients (vX.Y)`

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

#### U-6 · In-world nameplates and ground rings `[~]`
<!-- [DONE nameplate+ring @ v4.19; off-screen indicators deferred to U-6b] -->

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

#### U-7 · Settings and match-result polish `[~]`
<!-- [DONE @ v4.20] Settings panel + keybind viewer, Settings button in pause menu, MatchResult FoldCorner, Esc everywhere. lobby.gd Esc added inline at cherry-pick. -->

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

Only genuinely open questions live here. Anything answered has been moved out and written into the
document that acts on it, so this list shrinks instead of accumulating.

### Still open — a coding agent cannot resolve these

- [ ] **The display typeface.** See §0.5 for the two routes and the licence reasoning. Now blocks
      the logo, the round banner, the match-result headline and the finished look of every screen.
      **Most urgent decision on the project.** `Checklist.md` 1.1.
- [ ] **Does the Person get its own ability roster,** or does every Person share one Tag? Blocks
      the Person half of character select. `Checklist.md` 1.3.
- [ ] **Prop scale.** How big is a lata, and how big is a tsinelas, relative to a Person?
      Measured today: 70% and 84% of a Person's height respectively. Routed to Opus as an
      art-direction call, but a human veto is welcome. `Checklist.md` 1.2.
- [ ] **Ownership.** `Dev_Plan.md` §6 is now the **single canonical table** — the duplicate copies
      in this file and in GDD §8 have been removed and replaced with pointers. Still blank, and
      **submission Form 01 is literally this table**, so it is no longer just hygiene.

- [ ] **Is printed type on the lata worth a UV + texture pipeline?** The 2026-07-28 Sarsi asset
      moodboard carries a `sarsi` wordmark, `330 mL` and a barcode. **None of them are buildable
      today, and the gap is structural, not an oversight:** `obj_writer.gd` emits no `vt` lines at
      all and `_write_mtl` writes a single flat `Kd` per material with no `map_Kd`. The rest of
      that board's can — blue banding, red sail and ball, white wave, aluminium lid, pull tab — is
      shipped as colour-blocked geometry and reads correctly at match distance (`Checklist.md`
      2.9).
      Building it means: UV support in `obj_writer`, a label-texture generator (Godot *can* render
      a font to an `Image` in a tool script, so the wordmark is reachable without hand-drawing
      letterforms), UV coordinates for the can wall, and import settings for the PNG.
      **The argument against is the size the can is actually read at.** It stands 0.34 units tall
      and is seen from ~4.5 — the label lands ≈13 px, so a wordmark would be a smudge and the
      barcode nothing at all. It would only pay off in a close-up: a menu render, a key art shot,
      or the 3.2 logo lockup. **A human should decide whether any of those are planned** before
      anyone builds a texture pipeline for a 13 px payoff. Flat colour is also what Harry's board
      asked for in the first place (`PEAK`, "not photoreal and not PBR"), so *not* building it is a
      defensible final answer, not a deferral.

### Deliberately open, and blocking nothing

- [ ] **Option A vs Option B — the ship decision.** **Both modes stay in active, equal
      development.** This is *not* a "pick one and delete the other" item, and the language saying
      so has been removed from this file, `Dev_Plan.md` and the GDD. Both are wired end to end,
      both are selectable from the main menu, both get playtested (`Checklist.md` 0.4) and both get
      balanced to shippable quality (4.4). Keeping both does genuinely cost surface area on every
      combat change (B-25) — that cost is accepted deliberately, not overlooked. The human makes
      the final call on their own timeline. **No item anywhere may deprioritise one mode's polish
      on the assumption the other will win.**

### Answered — recorded here only so nobody reopens them

- [x] **B-45 — charged, aimed throw or instant pulse?** **Charged and aimed.** It was never
      really a design question: §0.7 established the moodboard had specified a thrown, retrieved
      slipper the whole time. Built in `carrier.gd` at v4.0; the fake pulse was deleted at v4.4.
- [x] **B-46 — is the Lata Reset Channel a real mechanic?** **Yes.** Built at v4.3 as T-3. Now
      folded into the GDD's Section 3 round flow, which §0.8 flagged as owed.
- [x] **Maps.** **Eskinita + Bayan Plaza, Palengke as a stretch only.** `Checklist.md` 2.2 and 2.4
      proceed on that basis; 2.4 is the first thing to cut under time pressure.
- [x] **Title.** **TUMBANG PRESO**, the moodboard's lockup. `project.godot`'s
      `application/config/name` already reads it; the README and the GDD have been brought into
      line and the stale "Tumbang Laro: Isang Laban" is gone from every tracked file. B-27 closed.
- [x] **Circular Economy as a secondary theme angle.** **Yes — take it.** The can/slipper premise
      is literally about reusing everyday objects as sports equipment, and it costs two sentences.
      Written into the synopsis plan (`Checklist.md` 6.5) rather than left as an open question.
- [x] **Rejoin identity (B-65).** Not a decision — it is scheduled work needing a stable player
      token instead of a peer id. `Checklist.md` 4.3.

---

## 6. Two things nobody has scheduled, both on the critical path

- **Real multi-device LAN testing.** Everything so far is loopback on one machine. Real wifi adds
  latency and packet loss to a movement layer with remote-visual interpolation (`Checklist.md` 4.2)
  but still no reconciliation. If that forces the shared-screen fallback (GDD Section 7), you want
  to know weeks before the deadline — and the FPP/TPP split raises the cost of that pivot (four
  viewports, and only one player per machine can mouse-look). **Book four laptops now.**
- **Audio — now built, and needing exactly one thing: ears.** 4.1 shipped 2026-07-29 (buses,
  `AudioManager`, 32 generated SFX, two CC0 ambience loops, hooks throughout, volume sliders). It
  is verified by `tools/audio_probe.gd`, which proves every sound loads and plays and that the
  lata impact has no head padding to desync it from hitstop — and proves **nothing whatsoever
  about whether the mix is any good**. Nobody has heard it. That is the outstanding item.

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

---

# APPENDIX — Bug ledger archive (B-01 … B-66, all fixed)

*(was `docs/Handoff.md`)*

Closed and settled. **Open bugs live in §3 of this file, not here.** Kept because several entries record *why* a thing is the way it is, and deleting that invites someone to "fix" it back.

﻿# Bug & Issue Ledger — archive (B-01 … B-66)

Split out of `Handoff.md` on 2026-07-27, when that file was rewritten around the art / 3D /
UI / bugfix queue. **This file is history, not a work queue.** It is the full forensic record
of every bug found and fixed from the first audit through v3.4 — including the reproduction
notes and the "the docs were stale, this was already fixed" corrections, which are the most
useful part of it and would have been lost to a plain overwrite.

**Still-open items were copied forward into `Handoff.md` §3 and are tracked there.** If an entry
here says `[FIXED]`, it is done; do not re-litigate it. New bugs get the next free B-number in
`Handoff.md` §3, never in this file.

---

### 3. Bug & Issue Ledger

Grouped by severity. B-01 to B-28 carry over from the previous audit; B-29 to B-48 are new from
this pass; B-49 is new from the session that built the kill plane (queue item 9) and caught it by
actually running the local flow instead of reading the code. IDs are referenced from
`Dev_Plan.md` §5.

#### P0 — LAN does not work today

**B-01 · A networked match never starts.** `MatchManager.begin_next_round()` RPC'd
`_sync_round_started` as `call_remote`, so the host never ran its own handler and
`RoundManager.start_round()` was never called by anybody.
**[FIXED, verified]** `_sync_round_started` and `_sync_match_won` are now `@rpc("authority",
"call_local", "reliable")`. Verified with two real running instances (not a human at the
keyboard, but not just reading the code either): `godot --headless --path . scenes/main/Main.tscn
-- --host` and a second process with `-- --join=127.0.0.1`, both instrumented temporarily to
print `RoundManager.time_left`/`round_active` and `MatchManager.round_number`/`team_a_is_can`
once a second (instrumentation reverted before commit, not shipped). Host log: `round_number=1
round_active=true`, `time_left` counting down 89.0 → 80.0 over the run. Client (joined ~2.5s after
the host started) log: `round_number=1 round_active=true`, `time_left` counting down 86.7 → 80.7,
tracking the host's broadcast. Still worth a human eyeballing the actual HUD render, but the
underlying state machine is confirmed working end to end, on both peers.

**B-03 · `ArenaCamera` crashes every frame in networked play — this is the reported LAN
freeze.** `Main.tscn:43` points `follow_paths` at the four local-test nodes. Godot runs child
`_ready()` before parent `_ready()`, so `arena_camera.gd:32-37` resolves and **caches** those
four nodes; then `main.gd::_clear_local_test_characters()` (called first thing in *both*
`_start_hosting()` and `_start_joining()`) frees all four. From the next frame on, `_process`
calls `t.global_position` on four freed instances, 60+ times a second, on **both** the host and
every client. In the editor that floods the remote-debugger channel and hangs the editor — which
matches the report exactly ("the testing environment freezes"). "Only 1 player spawns and they
cannot be controlled" is downstream of the freeze: a solo host correctly spawns one character
(itself), and nothing responds because the process is drowning in errors.
*Fix:* the camera rigs (`Dev_Plan.md` §3) remove the scene-level camera entirely. Disable or
delete the `Camera3D` node in `Main.tscn` in the same commit. If `arena_camera.gd` is kept as a
broadcast cam, it must register targets at runtime and `is_instance_valid()`-check every frame.
**[FIXED]** `add_target()`/`remove_target()` existed for the networked-spawn path, but
`main.gd::_clear_local_test_characters()` (which runs even before hosting/joining, since
`follow_paths` always points at the four local-test nodes) never called `remove_target()` before
`queue_free()`-ing them — confirmed live with the Godot 4.7 binary: Host Game spammed a
`filter()`/typed-array conversion error every single frame, the exact original symptom. Now
removes all four first, and `_process()`'s target-pruning loop no longer uses
`Array[Node3D].filter()` with a lambda (which throws on a freed reference) — a plain loop instead.
Verified clean (no errors) for local test, `--host`, and `--host`/`--join=127.0.0.1` together.

**B-29 · A client that joins after the host started never learns the match state. (NEW)**
`_start_hosting()` calls `MatchManager.begin_next_round()` immediately (`main.gd:142`), which
broadcasts `_sync_round_started` — **before any client exists**. Godot does not replay reliable
RPCs to late joiners. So on a joining client: `round_number` stays 0, `team_a_is_can` stays at
its default, `main.gd::_on_match_round_started()` never fires, so `is_can` / `team_is_can_side`
are never recomputed and `RoundManager._tracked_cans` stays empty, and the HUD shows the
`.tscn` placeholder text forever. The client is in a different match from the host until round 2
happens to fire. This is the second half of "Host Game (LAN) does not work", alongside B-03.
*Fix:* on `player_connected`, the host `rpc_id()`s the full current state (round number,
`team_a_is_can`, both win counts, `time_left`, `round_active`, `GameLaunch.game_mode`) to that
one peer. Longer term this is the lobby (B-13).
**[FIXED]** `main.gd::_sync_state_to_late_joiner` — host `rpc_id()`s that one peer, which sets the
plain autoload fields directly (not through `_sync_round_started`, which would also replay the
full round-reset/reposition logic just because someone joined mid-round) and refreshes the HUD
once. Verified live: joined a running round-1 host after ~3s and the client's
`late_join_state round=1 team_a_is_can=true wins=0-0 time_left=87.0 round_active=true` matched the
host's actual state exactly.

**B-02 · Every special and Tag/Throw is a no-op for anyone who isn't the host.**
`ability_utils.gd:34` adds the pulse hitbox to `current_scene` on the activating peer only — it
is never replicated. `hitbox.gd:45` then returns early on any non-host peer. A client's ability
creates a hitbox that refuses to resolve, and the host never has that hitbox at all. Affects
Spin Guard, Bagsak Bomb, Bakya Bash, Flick Dash, and Person's Tag/Throw — every action except
Bump. *Fix:* RPC the activation to the host and spawn the resolving hitbox there; cosmetic
copies locally if you want the visual.
**[FIXED]** (landed before this pass, docs were stale) `character_base.gd`'s
`_rpc_notify_ability_activate` — activates locally for the cosmetic effect, and RPCs the host to
run its own copy of `activate()` so the resolving hitbox exists where hit resolution actually runs.

**B-04 · Networked Props spawn with no ability.** `main.gd:203` assigns `PERSON_ACTION_ABILITY`
only when `is_person` is true. Props — the half of the team carrying the entire roster — get
`ability = null` over the network. Only the local flow has an ability on a Prop, and only
because `Main.tscn:50` hardcodes `quick_stand.tres` on `TeamAProp`.
**[FIXED]** (landed before this pass, docs were stale) `main.gd` assigns every networked Prop a
`.duplicate()`d `PROP_ABILITY` (`quick_stand.tres`) until character-select exists (B-24).

**B-30 · Networked characters never get a `player_id`. (NEW)** `_build_networked_character`
(`main.gd:196`) sets `is_can`, `is_person`, `team_is_can_side` and authority, but never
`player_id` — so all four networked characters keep the scene default of `1` and read `*_p1`
actions. It works by accident on LAN (one character per machine), but: the Settings panel's
entire P2 column is dead in networked play; the moodboard's WASD-for-Attacker /
arrow-keys-for-Defender scheme cannot be honoured; and any shared-screen fallback breaks
immediately. *Fix:* pass `player_id` through the spawn dictionary.
**[FIXED]** `player_id` is now explicit in the spawn dictionary, derived from the same
`is_person` split used for team/role assignment: `(index % 2) + 1`, so each team's Person gets
`player_id = 1` (P1/WASD default) and its Prop gets `player_id = 2` (P2/arrow-keys default) — this
is what actually lets the Settings panel's P2 rebind column do something in networked play, not
just in local test. It still can't produce anything beyond 1/2 (modulo 2), so it doesn't risk
breaking the 3rd/4th real joiner the way assigning raw join-order index (2/3/4...) would have —
p3/p4 stay deliberately unbound in `project.godot` for the local-test dummies regardless. The
moodboard's WASD-tracks-Attacker/arrows-tracks-Defender scheme still isn't honored (that needs
input rebinding on every role swap, not just this), and the not-yet-built shared-screen fallback
(queue item 1) is unrelated — **both remain open design questions, not re-litigated here.**

**B-48 · `GameLaunch.game_mode` is never networked. (NEW)** Each peer reads its own menu
selection. The host's mode governs hit resolution (`hitbox.gd:59`), but the client's
`_wire_downed_flash` dent gate (`main.gd:279`) reads the *client's* value — so a client on
Option B never shows a dent counter while the host runs Option A. Send `game_mode` with the
match-state sync in B-29.
**[FIXED]** included in `_sync_state_to_late_joiner` (see B-29) — a joining peer's `GameLaunch.game_mode`
is set from the host's value as part of the same sync.

#### P1 — the core loop is wrong

**B-49 · `NetworkManager.is_networked()` has been reading `true` in local test this whole time.
(NEW)** Godot 4's `multiplayer.multiplayer_peer` defaults to an `OfflineMultiplayerPeer`
sentinel, **not `null`**, and `multiplayer.has_multiplayer_peer()` reports `true` for it —
confirmed by printing `multiplayer.multiplayer_peer` at `main.gd::_ready()` in a real headless
run: `<OfflineMultiplayerPeer#...>`, before `host_game()`/`join_game()` has ever been called.
`NetworkManager.is_networked()` was defined as `return multiplayer.has_multiplayer_peer()`, so it
returned `true` for the plain single-PC/split-keyboard local-test flow too, which never touches
`host_game()`/`join_game()` at all. Most `if NetworkManager.is_networked(): ...` gates throughout
the codebase happened to be harmless because `is_host()` (`is_networked() and
multiplayer.is_server()`) was *also* accidentally `true` — the default peer reports as server —
so a paired "networked and not host, skip" check never actually skipped anything locally. There
is no such accidental save in `main.gd::_on_match_round_started`, which branches on
`is_networked()` alone: it took the **networked** branch and iterated `_spawned_characters`,
which is always empty outside a real match — so from round 2 onward, **the entire per-round reset
(position, `is_can`/`team_is_can_side` recompute, `RoundManager.register_can()`) silently did
nothing for any local-test unit.** B-10's own fix (position reset for all four units, this same
session) was therefore never actually exercised in local play, only in the networked branch —
caught only by building the kill plane (queue item 9) and running the local flow for real instead
of reading the code, the same lesson as B-03's regression above.
**[FIXED]** `NetworkManager` now tracks an explicit `_is_networked: bool`, set `true` only inside
`host_game()`/`join_game()` and `false` on disconnect/failure, instead of trusting
`multiplayer.has_multiplayer_peer()`. `is_networked()` returns that flag. Re-ran the same headless
local-test session: `_on_match_round_started` now reports `is_networked=false`, the local branch
runs, and a character forced into the KillPlane came back at its exact `spawn_position` —
confirmed with a real run, not just code inspection.

**B-09 · No team identity — you can dent and seal your own Can.** `CharacterBase` has `is_can`,
`is_person`, and `team_is_can_side`, but **no `team_id` at all**. `hitbox.gd` only skips
`target == owner_character`, so a defending Person can dent its own Can and a teammate can seal
it. The team id exists in `main.gd::_peer_teams` and is never put on the character.
⚠️ **Do this one first.** Friendly-fire, nameplates (item 4), team colour distinction (item 8),
and the role-swap card (item 9) are all blocked behind it.
**[FIXED]** (landed before this pass, docs were stale) `CharacterBase.team` (int, 0/1), set at
spawn in both the networked and local-test flows; `hitbox.gd` skips a hit when
`target.team == owner_character.team`. Nameplates/team colour/role-swap card are still open —
those are UI content work (queue items 4, 8, 9), not blocked on anything code-side anymore.

**B-15 / B-35 · No out-of-bounds handling, and the camera follows the faller forever. (B-35
NEW)** The arena is one 40×40 box with no walls, no kill plane, and no respawn — walk off the
edge and you fall forever with gravity accumulating. The camera half is separate and separately
broken: `arena_camera.gd` frames the **midpoint** of all targets and zooms out by FOV to fit
their **spread** (`arena_camera.gd:43-58`), so one player at y = −900 drags the whole shot down
and pins `_current_distance` at `max_distance` — everyone still playing is off-screen. *Fix:*
(a) invisible `StaticBody3D` walls at the arena edge; (b) a `KillPlane` Area3D at y ≈ −10 that
respawns the body at its spawn point; (c) per-character camera rigs (`Dev_Plan.md` §3) so no
camera can be dragged by someone else's fall; (d) if a broadcast cam survives, it ignores
targets below the kill plane. Also unblocks **ring-outs**, Option A's second win condition.
**[FIXED]** (a) and (b): four invisible walls around the floor's perimeter, plus a `KillPlane`
(`scripts/systems/kill_plane.gd`) that returns a fallen `CharacterBase` to its own
`spawn_position` (new field, captured on `_ready()`, kept current by `main.gd` on every
respawn/round reset). (c)/(d) NOT done — `arena_camera.gd` is unchanged, still an
average-position broadcast cam; the kill plane just bounds how long a fall can drag the shot
before the character snaps back (~1s given `GRAVITY = 20`), which is a reasonable mitigation but
not the real fix. Ring-outs (a round-win trigger off the kill plane, Option A) are still not wired
up — the kill plane exists now but nothing calls into round-win logic from it.

**B-10 / B-37 · Round reset covers one unit out of four, and there is no gap between rounds.
(B-37 NEW)** `round_manager.gd:99` loops `_tracked_cans`, which holds exactly the one defending
Can. The two Persons and the other Prop keep their `STAGGERED`/`DOWNED`/`SEALED` state, dent
count, speed multiplier, and spent once-per-round charges across rounds. **Nothing anywhere
writes `position` after spawn**, so round 2 starts wherever round 1 ended. Separately, the whole
chain `report_round_win → report_round_result → begin_next_round → _sync_round_started →
_on_match_round_started → start_round` runs **in a single frame** — there is no intermission
state, so there is nowhere for a role-swap card to live and no moment at which the world could
be reset. *Fix:* add the intermission state and `reset_world()` per `Dev_Plan.md` §4.6.
**[FIXED]** (the reset half; landed before this pass, docs were stale) `main.gd::_on_match_round_started`
resets and repositions all four units every round (networked and local-test), not just the
tracked Can. **Still open:** the single-frame chain and the intermission state itself — there is
still no role-swap card, and nothing pauses the world for one. That is UI/flow content work
(queue items 10/19), not a code bug.

**B-42 · From round 2 onward the local test has an uncontrollable Can. (NEW)**
`_on_match_round_started` flips `team_a_is_can` each round, so in round 2 the tracked Can becomes
`TeamBProp` — `player_id = 3`, which is **deliberately unbound** in `project.godot`. The Can
cannot be moved, cannot self-right, and the round can only end on the timer. A local Bo5 is
therefore not playable past round 1 today. The requested debug player-switcher (queue item 1) is
what fixes this, which is why it is queued early rather than as a nicety.

**B-05 · Nothing ever rotates, so all directional attacks fire toward world −Z.**
`character_base.gd` never writes `rotation` and there is no aim input. The melee `Hitbox` sits at
a fixed local offset (`CharacterBase.tscn:60`), and `PersonAction`, `BakyaBash` and `FlickDash`
all use `-transform.basis.z`. A player moving east can only attack north. `rotation` is already
in the replication config and already replicated — it is just never written.
*Fix:* comes free with the camera rigs (`Dev_Plan.md` §3.2). The rig writes `rotation.y`. **Do
not build a separate aim axis.**
**[FIXED]** (landed before this pass, docs were stale) — NOT via camera rigs (those don't exist
yet); `character_base.gd` writes `rotation` directly via `look_at()` on movement input instead.
Camera rigs remain future work; this doesn't block them.

**B-06 · Quick Stand can never be activated.** `character_base.gd:142` returns early for
`STAGGERED`/`DOWNED`/`SEALED`; the `special_ability` input is read at line 160, *after* that
return. Quick Stand's only effect is self-righting from Downed — the exact state in which its
input is unreachable. Same structural problem for any future escape ability.
**[FIXED]** (landed before this pass, docs were stale) — `special_ability` is now also read inside
the `DOWNED` case of the state `match`, before the old unconditional early return.

**B-07 · Any stagger cancels Downed.** `apply_stagger()` (line 164) overwrites `DOWNED` with
`STAGGERED`, which auto-recovers to `NORMAL` after 0.25s. Under Option B, `hitbox.gd:70` sends
`"stagger"` to a Can that is Downed but still inside its self-right window — so hitting a downed
Can *rescues* it. Any bump from anyone, including its own teammate, is a free escape. Option B's
seal mechanic cannot work until this is fixed.
**[FIXED]** (landed before this pass, docs were stale) — `apply_stagger()` now returns early for
`DOWNED` too, not just `SEALED`.

**B-08 · Bump misses anyone you are already touching.** `hitbox.gd` only listens to
`area_entered`, but the melee Hitbox is always monitoring and is never enabled/disabled by the
bump window. Walk into someone and press bump → no new `area_entered` → no hit. You have to
press bump *before* closing distance, which is the opposite of how melee reads.
*Fix:* on bump press, also sweep `get_overlapping_areas()`.
**[FIXED]** `Hitbox.sweep_overlaps()` re-runs `_on_area_entered()` against everything already
in `get_overlapping_areas()`. `CharacterBase` caches its melee Hitbox (`requires_bump_window
== true`) in `_ready()` and calls `sweep_overlaps()` from a new shared `_open_bump_window()`
helper, used both when the local player presses bump and in the host's `_rpc_notify_bump`
handler (so a remote peer's already-touching bump also resolves correctly on the host). Needs
verification that walking into someone and then pressing bump now lands a hit.

**B-11 · A no-op activation still burns the cooldown.** `ability_base.gd:29` — `activate()` sets
`_time_since_use = 0` and `_used_this_round = true` before calling `_do_activate()`, which may do
nothing (Quick Stand while not Downed). Press the button once at the wrong moment and your
once-per-round charge is gone.
**[FIXED]** (landed before this pass, docs were stale) — `activate()` now only consumes the
cooldown/charge after `_do_activate()` returns `true`.

**B-12 · Friction is a per-frame constant, so there is no momentum and Flick Dash lasts three
frames.** `move_toward(velocity.x, 0, SPEED)` uses `SPEED` (6.0) as an absolute per-tick step,
not per-second — no `delta`. Max walk speed is also 6.0, so releasing a key stops you dead in one
tick, and it is frame-rate dependent if the physics tick ever changes. Flick Dash sets velocity
to 16 and it decays 16 → 10 → 4 → 0 in about 0.05s. The dash also applies a frame late, because
`_do_activate` runs after `move_and_slide()`.
**[FIXED]** (landed before this pass, docs were stale) — friction is now a real `FRICTION * delta`
deceleration, and the special-ability activation moved above `move_and_slide()` so a velocity kick
takes effect the same tick.

#### P2 — menu, flow, and polish

**B-33 · The disabled game mode is selectable and proceeds.** `main_menu.gd:34` adds "Option A —
Health / Dents (coming soon)" as an ordinary `OptionButton` item, and `_on_game_mode_selected`
writes it into `GameLaunch.game_mode` unconditionally — nothing gates Local/Host/Join on it.
⚠️ **The label is also wrong:** Option A has been fully implemented since Session 7
(`hitbox.gd:59`, `round_manager.gd:78`). So this is a decision, not just a fix: either drop the
"(coming soon)" suffix because the mode works, or genuinely disable it with
`set_item_disabled(1, true)` **and** grey out the Local/Host/Join buttons while it is selected.
Do not leave a third state where the label says one thing and the button does another.
**[FIXED]** dropped the "(coming soon)" label — it works, so there was nothing to actually gate.

**B-34 · No way back from the Play menu.** `_on_start_pressed` hides `TitleScreen` and shows
`PlayMenu`; nothing ever goes back. Settings is only reachable from `TitleScreen`, so once you
press Start you cannot reach Settings without restarting the game. *Fix:* a Back button on
`PlayMenu` and an `ui_cancel` handler doing the same thing.
**[FIXED]** added a Back button to `PlayMenu` plus a `ui_cancel` (Esc) handler doing the same.

**B-13 · The match starts before anyone joins.** `main.gd:142` calls `begin_next_round()` the
instant the host starts hosting. No lobby, no ready-up. Root cause of B-29.

**B-14 · Nothing resets between matches.** `MatchManager.team_a_wins` / `team_b_wins` /
`round_number` / `team_a_is_can` and `RoundManager`'s state live on autoloads that survive scene
changes. A second match continues the first one's score. Needs `reset()` on both.
**[FIXED]** added `reset()` to both, called from `main_menu.gd::_go_to_match()` (every Local/
Host/Join button) and from the new pause menu's Return to Menu (B-20).

**B-16 · `guard_dash` is bound, rebindable, and read by nothing.** The GDD lists Guard/Dash as a
shared basic for every character. `guard_dash_p1..p4` exist in `project.godot` and appear in the
Settings panel, but no script reads them. Players will press it and nothing happens.
**[FIXED]** implemented per GDD: Cans (Prop, `is_can` true) hold to block, gated by a stamina
meter; Tsinelas (Prop, `is_can` false) get a short-cooldown dash burst in the facing direction.
Persons don't get this (their slot is Tag/Throw). Guard blocks both stagger and dents while
active. Untested in a live playtest — reasoned through and runtime-smoke-tested (no script
errors), but game feel/balance numbers are first-pass guesses.

**B-17 · `HazardZone` edge cases.** `_on_area_entered` calls
`owner_character.set_speed_multiplier()` with no null check (a Hurtbox whose owner isn't wired
crashes it). Exiting one zone resets speed to 1.0 even if you are still standing in another. And
a zone that expires while someone is inside relies on Godot firing `area_exited` during free —
verify before map hazards depend on it.
**[FIXED]** all three: null-checked; `CharacterBase` now tracks every active zone
(`enter_speed_zone`/`exit_speed_zone`) and applies whichever is most restrictive instead of a
single overwritten value; `_expire()` explicitly clears its effect from every character still
overlapping instead of assuming `area_exited` fires on free.

**B-18 · Round end isn't synced on timer expiry.** `round_manager.gd:116` `_on_time_up()` sets
`round_active = false` without a final `_sync_state` RPC.
**[FIXED]** `_on_time_up()` now calls `report_round_win(true)`, which already does the sync.

**B-19 · `_sync_state` RPCs every rendered frame, per client**, purely to drive a HUD label that
changes once a second. Note it is in `_process`, not `_physics_process` as previously recorded —
so at 144 fps that is 144 packets/second/client. Harmless on a LAN, wasteful, trivially
throttled to ~4 Hz.
**[FIXED]** throttled to `SYNC_INTERVAL = 0.25` (4Hz); the final state at round end (B-18) still
syncs immediately, unaffected by the throttle.

**B-20 · No way out of a match.** No pause, no Escape handler, no return-to-menu. Once
`Main.tscn` loads, the only exit is Alt+F4 — a bad look in a live demo. Doubly important once
FPP captures the mouse (`Dev_Plan.md` §3.2): a captured cursor with no release path traps the
player.
**[FIXED]** a `PauseLayer` overlay (Resume / Return to Menu), toggled by `ui_cancel`. The same
toggle also owns mouse capture: opening the pause menu releases the cursor to
`MOUSE_MODE_VISIBLE` (mandatory, or the overlay's own buttons aren't clickable — `_ready()`
already captures the mouse unconditionally for gameplay, see Item 14) and Resume re-captures it.
Return to Menu disconnects the network session if one exists and resets MatchManager/RoundManager
(B-14). Focus-loss (alt-tab) still independently forces the mouse visible regardless of pause
state.

**B-21 · Team assignment uses `_spawned_peer_ids.size()` as the join index.** A disconnect
followed by a rejoin shifts every subsequent index, so teams and Person/Prop roles get
scrambled.
**[FIXED]** join index is now assigned once per `peer_id` on first connect and never reassigned,
even after that peer disconnects.

**B-22 · Settings allows duplicate bindings.** Rebinding P2's "up" to `W` silently makes both
local players move together, with no warning and no conflict detection.
**[FIXED]** `rebind_action()` checks every other rebindable action for the same physical keycode
and refuses (returning the conflicting action's label) instead of double-binding it. Reset-to-
default bypasses the check via a new internal `_set_binding()`, since resetting must always
succeed even mid-reset.

**B-38 · A client's Bo5 score is stale for the whole final round. (NEW)** `hud.gd:23` reads
`MatchManager.team_a_wins` / `team_b_wins` directly every frame, but on a client those only ever
change inside `_sync_round_started` / `_sync_match_won`. So a client sees the *previous* round's
score for the entire round it is playing, and the winning score only lands with the match-won
RPC. Once the score becomes Bo5 pips (`Dev_Plan.md` §4.4) this will be very visible.
**[FIXED]** for the specific case this ledger entry is about (a late joiner): the new
`_sync_state_to_late_joiner` (B-29) includes both win counts. Ordinary in-match score updates were
already synced via `_sync_round_started`/`_sync_match_won`'s existing `call_local` RPC — not
re-verified beyond that this session.

**B-23 · Dead code.** `RoundManager.round_won` and `Hitbox.landed_on` are emitted and nothing
listens — `landed_on` in particular is the natural hook for hit VFX/SFX and is currently only
emitted on the host. `CharacterBase.is_person` is read nowhere outside `main.gd`.

#### P3 — feel, content gaps, and drift

**B-44 · There is no hit feedback of any kind. (NEW)** No sound, no particles, no hitstop, no
screenshake, no flash on the target, no controller rumble. A landed bump is a 0.25s velocity
change and nothing else. This is the single biggest "game feel" gap in the build, and the
moodboard explicitly specifies the missing pieces: *IMPACT EFFECT (particle burst)*, *CHARGED
THROW (glow effect)*, *BODY-BLOCK HITBOX (contact effect)*. `Hitbox.landed_on` already exists as
the hook (B-23) and needs to fire on every peer, not just the host.
**[FIXED]** (partial) added a brief white mesh flash on any landed hit, triggered from
`_apply_hit_result()` (runs on the target's own owning peer, any hit kind, either game mode) — no
new assets needed. **Q-8 added screenshake and impact particles** (see B-66) on top of this, both
code-built with no new assets. `landed_on` itself is still unused. **Hitstop closed in 4.5;
sound closed in 4.1 (2026-07-29)** — and the "needs real assets" assumption behind this note was
wrong: the whole SFX set is synthesised from maths by `tools/audio/generate_sfx.py`, so it needed
no assets at all. The impact sound fires on the statement immediately before `_hitstop()` in
`CharacterBase._flash_hit()`, so B-44's last two gaps close together and in sync.

**B-45 · The moodboard's throw is a charged, aimed action; the code's is an instant fixed-range
pulse. (NEW)** The Attacker card specifies *AIMING ARC (mouse pointer trail)* and *CHARGED THROW
(glow effect)* — hold to charge, aim with the mouse, release to throw. `person_action.gd` spawns
an instantaneous pulse hitbox at a fixed 4.0 units directly ahead. FPP + mouse-look
(`Dev_Plan.md` §3) makes the moodboard version genuinely achievable, and it is a far better
mechanic. **Design decision needed** — do not silently build either one.

**B-46 · The moodboard specifies a mechanic that is in neither the code nor the GDD. (NEW)** The
Defender card shows a *LATA RESET CHANNEL* with a progress bar — a defender channelling to stand
the Can back up. Nothing like it exists anywhere. **Design decision needed:** adopt it (it is a
good counterpart to the Downed/Seal window and gives the defending Person something to do), or
cut it from the moodboard so the art doesn't promise a mechanic that never ships.

**B-24 · Five of six roster specials are unreachable.** `shatter_trap.gd`, `spin_guard.gd`,
`bagsak_bomb.gd`, `bakya_bash.gd`, `flick_dash.gd` exist as scripts, but
`scripts/abilities/resources/` contains only `quick_stand.tres` and `person_action.tres`, and
`scenes/characters/cans/` and `tsinelas/` are empty. There is no character-select step.
Effectively the roster is one character.
**[FIXED]** (partial) created `.tres` resources for all five, mirroring `quick_stand.tres`'s
format (Bakya Bash gets the GDD's "long cooldown", the rest use `AbilityBase` defaults). They can
now be assigned/tested manually. **Still open:** character-select UI/data to actually pick between
them in game — that's the content-heavy half of this bug (Phase 2 item), not attempted here.

**B-25 · Option A / Option B interaction with `forces_downed`.** Under Option A, `hitbox.gd:59`
turns any hit on a Can into a dent before the `forces_downed` branch is reached, so Bakya Bash's
"instant-down on direct hit" does nothing to a Can — the only target it is meant for. Whichever
option the team picks, this needs a decision.

**B-43 · Spawned pulse hitboxes are dropped in world space and never move. (NEW)**
`ability_utils.gd:34-35` parents the hitbox to `current_scene` and sets its position once. For
Spin Guard and Bagsak Bomb that is fine. For **Flick Dash** it is not: the script's own comment
says the hitbox "rides along with" the dash, but it is a static sphere at the activation point
while the character dashes away from it. Combined with B-12 (dash decays in ~0.05s) the ability
is close to inert. Also: these hitboxes are never cleaned up on round reset (B-10).
**[FIXED]** (the movement half) `spawn_pulse_hitbox()` gained a `follow_character` option that
parents the hitbox to the character as a local-offset child instead of `current_scene`; Flick
Dash opts in, the stationary pulses (Spin Guard, Bagsak Bomb, Bakya Bash, Person's Tag/Throw)
don't. **Still open:** round-reset cleanup — low risk given these all have sub-0.4s durations,
but not explicitly handled.

**B-26 · Stale comments and labels.** `hitbox.gd:5-8` says "both Hitbox and Hurtbox default to
layer 1" — they do not; `CharacterBase.tscn` sets Hurtbox to layer 2 / mask 0 and Hitbox to
layer 0 / mask 2, which is correct, so the comment is misleading in a load-bearing place.
`round_manager.gd:74` talks about "both tracked Cans" when only one Can exists per round.
`round_manager.gd:41` says role reassignment "isn't implemented yet" — it has been since
Session 7. The main menu still labels Option A "(coming soon)" (see B-33).
**[FIXED]** fixed the `hitbox.gd` layer comment and the `round_manager.gd` reassignment comment;
Option A's label is fixed too (see B-33).

**B-27 · Name inconsistency.** `project.godot` says "Tumbang Laro", the README and GDD say
"Tumbang Laro: Isang Laban", the main menu says "TUMBANG PRESO", and the moodboard ships a
finished **TUMBANG PRESO** logo. Adopt the logo's name everywhere (`Dev_Plan.md` §0.4).
**[FIXED]** `project.godot`, README, and GDD title all now say **Tumbang Preso**, matching the
main menu and the moodboard logo.

**B-50 · P1's Guard/Dash was bound to a Godot 3 keycode, so it never fired. (NEW)**
`project.godot`'s `guard_dash_p1` held `physical_keycode = 16777237` — that is Godot **3**'s
`KEY_SHIFT`. Godot 4's is `4194325`, and `16777237` is not a valid Godot 4 keycode at all, so the
action could never be triggered by any key. The whole B-16 Guard/Dash mechanic was dead for
player 1: the Can could not block (so `apply_stagger`/`apply_dent`'s guard checks were
unreachable) and the Tsinelas could not dash. The settings panel rendered it as the nonsense
string "Command+", which is what surfaced it. Nothing in the code was wrong — only the binding.
**[FIXED]** `guard_dash_p1` is now `KEY_SHIFT`. That collided with `special_ability_p2`, which was
also on Shift, so both were split by `location` (LEFT for P1's guard, RIGHT for P2's special) —
otherwise one physical keypress fires two different players' actions on a shared keyboard.
`guard_dash_p2` moved from Ctrl to **End**, matching the scheme `Dev_Plan.md` §3.5.1 already
documented. Verified by matching synthetic `InputEventKey`s against the InputMap: left Shift
resolves to `guard_dash_p1` only, right Shift to `special_ability_p2` only, and all 14 bound
actions now have 14 distinct key+location pairs (no conflicts).

**B-51 · The match-result screen appeared with the cursor still captured, so neither of its
buttons could be clicked. (NEW)** `main.gd::_ready()` sets `Input.mouse_mode = MOUSE_MODE_CAPTURED`
for the whole match, and nothing released it when the match ended — `match_result.gd` only released
it inside `_on_menu_pressed`, i.e. *after* a click that could not happen. Winning a Bo5 therefore
left you on a result screen with an invisible, captured cursor and no way to press **Rematch** or
**Menu**. Recoverable only via Esc, which opens the pause overlay *over* the result screen.
**[FIXED]** released in `_on_match_won`, re-captured in `_on_rematch_pressed` (a rematch goes
straight back into gameplay, and `camera_rig.gd` only mouse-aims while the cursor is captured).
Verified by driving a real local Bo5 to 3-0 in a live instance: the result screen shows with
`mouse_mode = VISIBLE`, and pressing Rematch returns round 1 / 0-0 with `mouse_mode = CAPTURED`.

**B-52 · Ability cooldowns carried across the round boundary. (NEW)**
`AbilityBase.reset_round_charge()` — called from `CharacterBase.reset_for_new_round()` — cleared
`_used_this_round` but not `_time_since_use`, so a cooldown-based ability kept its remaining
cooldown into the next round. The intermission does not absorb it either:
`character_base.gd::_physics_process` returns before `ability.tick(delta)` whenever
`RoundManager.round_active` is false, so the cooldown does not decay during the 3s gap at all.
Worst case is Bakya Bash at **18s** — used near the end of a round, the next round started with
most of that still to run, a fifth of a 90s round with no special. Not cosmetic: the whole point
of a per-round reset is that both teams start a round on equal footing.
**[FIXED]** `reset_round_charge()` now also resets `_time_since_use`. Verified: activate an
ability, call `reset_round_charge()`, `is_ready()` goes back to `true` (it stayed `false` before).

**B-53 · Esc could bury the match-result screen under the pause overlay. (NEW)**
`PauseLayer` is `layer = 10`; `MatchResult` lives in `HUDLayer` at layer 0. Pressing Esc after a
match ended therefore drew the pause overlay *over* the result screen, and Resume re-captured the
cursor and handed back a result screen that could not be clicked — re-creating B-51 by another
route. **[FIXED]** `main.gd::_unhandled_input` ignores `ui_cancel` entirely while the result
screen is visible; there is nothing to pause once the match is decided. Verified live.

**B-54 · Local spawn points ignore team membership. (OPEN — needs a design call, not a code fix)**
`main.gd`'s `SPAWN_POINTS` are assigned in `_local_roster` order — `TeamAProp`, `TeamAPerson`,
`TeamBProp`, `TeamBPerson` — against the fixed list `(0,1,-2) (0,1,2) (-3,1,0) (3,1,0)`. So Team A's
two units start at opposite ends of the arena while Team B's start on the left/right flanks:
teammates are not together and opponents are not separated. Worse for the camera, `TeamAPerson`
spawns at `(0,1,2)` and `TeamAProp`'s third-person camera sits at `(0,3.66,2.35)` — your own
teammate spawns essentially *inside* your camera, filling the frame at round start. Not fixed
here because the right answer is per-map base placement (the GDD's Eskinita / Bayan Plaza bases),
which is queue item 10's deferred "move `SPAWN_POINTS` into a `SpawnPoints` node on the map scene"
— guessing at coordinates now would just be re-guessed when real maps land.

**B-55 · `RoundManager`'s end-of-round state change rides an unreliable RPC. (OPEN — low)**
`_sync_state` is `@rpc("unreliable_ordered")`, which is right for the 4Hz timer it was written for,
but `report_round_win()` uses that same channel to broadcast the one-shot `round_active = false`.
If that packet drops, the client keeps believing the round is live — and `_process` won't resend,
because it returns early once `round_active` is false. Self-heals when the next round's
`_sync_round_started` (reliable) arrives ~3s later, so the blast radius is a stale client HUD for
one intermission. Left alone: the fix is to split the one-shot state change onto a reliable RPC,
which is a networking change worth making deliberately rather than in passing.

**B-56 · `KillPlane` respawns on every peer, not just the character's authority. (OPEN — low)**
`_on_body_entered` calls `character.respawn()` wherever the Area3D overlap is detected, which is
every peer. For a non-authoritative copy the position is immediately overwritten by
`MultiplayerSynchronizer`, so the visible effect is at most a one-frame snap, and the
"OUT OF BOUNDS" toast is already correctly gated on `is_multiplayer_authority()` in `main.gd`.
Flagged rather than fixed because it is cosmetic and the correct guard placement depends on
whether respawn should stay client-authoritative at all (see B-49's note on the movement model).

**B-57 · Under Option A, `forces_downed` is silently ignored on a Can. (OPEN — question, not a bug)**
`hitbox.gd` resolves any hit on a Can under Option A as `"dent"` before it ever consults
`forces_downed`, so Bakya Bash's advertised "instant-down on direct hit" does nothing distinct in
that mode. That may well be intended — Option A has no Downed/Seal state machine at all — but it
means a heavy special and a light bump are worth exactly the same against a Can. **Someone needs
to decide** whether Option A wants weighted hits (e.g. a heavy special costing 2 dents) or whether
every hit really is one dent. Not changed: it is a balance decision, not a defect.

**B-58 · `ArenaCamera._process` still does full follow-cam work every frame while retired.
(OPEN — trivial)** `_ready()` sets `current = false` (§3.4, it lost the viewport to the per-character
rigs), but `_process` still runs every frame computing the target midpoint, the pairwise spread and
a lerped position for a camera nothing renders through. Harmless, just wasted work; worth
`set_process(false)` whenever it isn't current, once someone decides whether the spectator/broadcast
use-case it was kept for is real.

**B-59 · Unreproduced: a completed match reset itself to round 1 / 0-0. (OPEN — question)**
Twice, early in testing B-51, a scripted local Bo5 that had just reached 3-0 came back on the next
sample reading `round_number = 1`, `wins = 0-0`, `round_active = true` and the result screen hidden
— which is precisely the post-`_on_rematch_pressed()` state, with no input sent. It has not
reproduced in six subsequent runs (including one with `print_stack()` instrumentation on both
`_on_rematch_pressed` and `MatchManager.reset`, which showed `reset` called exactly once, from
`main.gd::_ready`). The obvious suspect — `ui_accept` sharing Space/Enter with `bump_p1`/`bump_p2`,
so a player still mashing bump when the match ends would trigger a focused Rematch button — was
tested and does **not** hold: neither key matches `ui_accept`, and the button holds no focus.
Recorded rather than closed, because "I could not reproduce it" is not "it does not happen". If a
match ever restarts itself in a real playtest, start here.

**B-60 · Pressing WASD rotated the camera of the unit you were driving. (NEW)**
`character_base.gd` called `look_at(global_position + direction, ...)` on *every* movement input,
including for the unit whose `CameraRig` is mouse-aimed. Because the rig is a **child** of the
body, snapping the body's yaw to the WASD direction dragged the camera round with it: aim 90° left,
hold `D`, and the camera flipped a full **180°**. `camera_rig.gd`'s own header already described the
intended contract — `look_at()` applies "when this rig's aim_source is MOVEMENT" — but
`character_base.gd` never knew about `aim_source` and so never honoured it.
Compounding it, movement was read in **world space** (B-05), which was right when the only camera
was the fixed-angle `ArenaCamera` and became wrong the moment the per-character FPP/TPP rigs made
the camera turn with the player: in first person, `W` has to go where you are looking.
**[FIXED]** the two halves are coupled and both landed together. A mouse-aimed unit now reads WASD
in the **body's** frame (so `W` is "where I'm looking") and does **not** call `look_at()` — the rig
owns yaw. Every other unit (remote peers, local-test dummies, `aim_source = MOVEMENT`) keeps the
original world-space scheme *and* its `look_at()`, which is correct for a unit nobody is aiming.
Attacks now fire where you are looking, which is what B-05 actually wanted.
Verified by driving a live instance: after a 90° mouse-look, holding each of W/A/S/D leaves body
yaw and camera forward **completely unchanged** (0.0° drift, was up to 180°), while movement
resolves to along-facing `+1.00` for W, `-1.00` for S, and right-of-facing `±1.00` for D/A. A
MOVEMENT-aimed unit was regression-checked in the same run: still moves world −Z on `W` from a 90°
yaw, and still turns to face its own movement.

**B-61 · The FPP self-hide made every Person invisible to everyone. (NEW)**
`camera_rig.gd::_apply_fpp_self_hide()` set every Person's meshes to
`SHADOW_CASTING_SETTING_SHADOWS_ONLY` **unconditionally**, never consulting `_active`. The rule it
was supposed to implement was already written in its own doc comment — *"other peers still need to
see the mesh"* — but the code hid the body of every Person in the match, not just the one being
looked through. Result: Persons rendered as walking shadows with no body, teammates and opponents
alike, from every camera. Props were unaffected (TPP never self-hides).
This was latent, not new: the self-hide had silently been a **no-op** because it ran in `_ready()`,
which fires before `character_visual.gd` instances any meshes for it to find. Making it actually
work (v1.5) is what exposed the underlying logic error.
**[FIXED]** the hide is now gated on `_active and _mode == FPP`, restores
`SHADOW_CASTING_SETTING_ON` otherwise, and is re-applied from `set_active()` so it tracks the
camera being handed between units by the debug switcher. Verified: with a Prop active, all four
units read `cast_shadow = 1`; switching the camera onto a Person drops **only that Person** to `3`
and leaves everyone else at `1`. Confirmed in a rendered frame — both Persons visible, and the
one you look through still casts its own shadow.

**B-28 · No export presets, no build, no CI.** `export_presets.cfg` is gitignored and none
exists. The game has never been run outside the editor, and the submission needs a real build.

**Q-7 verification note.** `HazardZone` gained a visual — a code-built `CylinderMesh` decal (no art
asset), radius read from the actual `CollisionShape3D`'s `SphereShape3D` rather than a second
exported number, `UiTheme.IMPACT` at 0.35 alpha, unshaded so it reads the same under any light.
Placed one permanent instance (`Hazards/HazardZone` in `Main.tscn`, radius 3.0, `speed_multiplier
= 0.5`, `lifetime = 0.0`, at `(5, 0.5, 5)` — clear of every `SPAWN_POINTS` entry) with
`collision_layer = 0` / `collision_mask = 2` set directly in the scene, matching what `spawn()`
already does for the ability-spawned case (a scene-placed zone doesn't run through that helper).
Found and fixed two real bugs while wiring this up, neither visible from reading the code:
(1) `HazardZone.spawn()` set `global_position` **after** `add_child()`, but `_ready()` — which now
also builds the visual, positioned relative to `global_position` — fires synchronously **during**
`add_child()`, so the ability-spawned path (Shatter Trap) would have built its decal at whatever
position the zone happened to be at *before* being placed. Reordered to set position first.
(2) The naive fix (`zone.global_position = at_position` before `add_child()`) throws
`"!is_inside_tree()"` and silently leaves the zone at the origin — `global_position`'s setter
requires already being in the tree. Switched to local `position`, safe because every caller passes
an already-world-space `at_position` to a parent with an identity transform. Verified live,
headless: the placed hazard's decal computes to exactly the expected world position and colour;
it is not in the `hazard_zone` group and survives a forced round transition unfreed; a separately
spawned Shatter-Trap-style hazard (elevated origin, unlike the floor-level map hazard) still
projects its decal onto the floor correctly and does join the group. Not independently
re-verified: the pre-existing speed-multiplier gameplay logic itself (B-17), since Q-7 only added
the visual and didn't touch `_on_area_entered`/`_on_area_exited`.

**Q-6 verification note.** Guard/Dash (B-16) was confirmed already fully implemented, exactly per
§0.2 — this task was surfacing it on the HUD, not building it. Added read-only
`get_guard_stamina_ratio()`/`get_dash_cooldown_ratio()` accessors to `CharacterBase`, a meter on
the Q-5 YOU card (one bar, GUARD or DASH picked by `is_can`, hidden for Persons), a key-label read
live from `InputMap` so a Settings rebind stays truthful, and a `hit_blocked` signal +
`CharacterVisual.flash_blocked()` (DEFENSE-tinted, deliberately distinct from B-44's white landed-
hit flash) wired into `apply_stagger()`/`apply_dent()`'s existing `_is_guarding` early-returns.
Verified live, headless: the meter is hidden while driving a Person; holding the bound key as a
Can drains the stamina ratio and the YOU card's bar mirrors it in lockstep; a dent landed on a
guarding Can changes neither `state` nor `dents` and fires `hit_blocked` exactly once (confirmed
via a signal-count check — the first attempt used a bare `bool` in a lambda closure and read as a
false negative, since GDScript lambdas capture locals **by value**; switching to a boxed `Array`
counter confirmed the real behavior was correct all along); releasing the key regenerates stamina
back to a full ratio; switching to a Tsinelas shows the dash cooldown ratio, a press drops it near
0 and it climbs back to 1.0 after `DASH_COOLDOWN` elapses. One documentation note: the Handoff/
Dev_Plan text calls the "ready again" flash colour `UiTheme.PAPER`, which isn't an actual defined
constant — substituted `UiTheme.CARD` (the theme's actual near-white token) instead.

**B-65 · No reconnect path — a rejoining player can come back as a different team and role.
[FIXED 2026-07-28, `Checklist.md` 4.3]** Originally: a rejoining player gets a brand-new peer id, so
`main.gd::_peer_join_index` assigns them the next free slot rather than restoring their previous
one. Fixed with a stable per-instance token (`NetworkManager.local_player_token`, minted once per
running process and presented to the host on every connect via `_rpc_identify`) — `main.gd`'s join
index is now keyed by token, not peer id, so a reconnect under a new peer id maps straight back to
the same team/role slot. The token itself is deliberately NOT reloaded from the `user://` copy it
also writes: two local test instances (this project's own two-instance test — `Debug > Run Multiple
Instances`, or two `godot --path .` processes) share one `user://`, and reading the token back would
make both instances present the identical token and collide on the same join index. This closes the
identity half of the bug, but identity alone does not get a rejoining peer back into the match — see
the fuller account in this file's session log for the `Lobby.tscn` redirect that was also needed.

**Q-5 verification note.** Added the HUD "YOU" card (`scenes/ui/YouCard.tscn` +
`scripts/ui/you_card.gd`), instanced into `HUD.tscn`. Shows class (`PERSON`/`CAN (LATA)`/`TSINELAS`),
team letter, and side this round, with a role-coloured (`UiTheme.OFFENSE`/`DEFENSE`) 6px accent
bar — never team-coloured, per §4.2's hard rule. Resolves the local character two ways: networked
via a new `main.gd::get_local_character()` (scans `_spawned_characters` for
`is_multiplayer_authority()`); Local Match by scanning the scene tree for whichever unit currently
holds `player_id == 1`. The card polls every 0.15s rather than listening for a debug-switcher
event, since protocol rule 11 (`Dev_Plan.md` §0.3) forbids gameplay code from referencing anything
debug-only — a plain public-var poll stays correct with zero coupling in either direction. Also
connects to `MatchManager.round_started` directly and gets an explicit `hud.refresh_you_card()`
call from `main.gd::_sync_state_to_late_joiner` so a joining client doesn't wait out the poll
interval. Verified live, headless: Local Match round 1 reads `PERSON · TEAM A · DEFENSE` (matching
the actual default-driven unit); reassigning `player_id` the same way the debug switcher does (Tab)
correctly flips the card to the newly-selected unit; ending round 1 and starting round 2 flips the
side the instant the role swap happens (`TEAM A · DEFENSE` → `TEAM A · OFFENSE`). Networked: a
client joining ~3s into a running match already shows a populated, correct card
(`CAN (LATA) · TEAM A · DEFENSE`, matching its actual spawned role) within 0.5s of connecting — not
blank.

**Q-4 verification note (2026-07-27).** Confirmed the match-result screen already works exactly as
Handoff.md §0.2 said: driven a Local Match to a real 3-0 via direct `MatchManager.report_round_result()`
calls spaced past `INTERMISSION_DURATION` (so `begin_next_round()` fires between them the same way
it would in real play, rather than compressing three rounds into under a second) — the result
screen appeared with the correct `TEAM A WINS THE MATCH!` text and score, and Rematch correctly
returned to a fresh 0-0 round 1. **B-59 did not reproduce** across this run (round_number and both
win counts stayed stable while the result screen sat idle for 3+ seconds). One thing worth
recording for whoever chases B-59 next: an EARLIER, unrealistically-fast version of this same test
(three `report_round_result()` calls 0.2s apart, bypassing the normal round-duration timing
entirely) DID produce a spurious `round_number` increment after the match had already ended — but
root-caused to `MatchManager._intermission_time_left` staying set from a non-finishing round's
call when the very next call finishes the match before that timer naturally elapses.
`_finish_match()` doesn't clear it. Confirmed this can't happen via the real `RoundManager.report_round_win()`
→ `MatchManager.report_round_result()` path, because `begin_next_round()` (which would need to
start a new round for `report_round_result()` to be called again) can only fire once
`_intermission_time_left` has already reached zero — so a second call can never find it still
positive under real gameplay timing, only under a synthetic test that skips actual round durations
entirely. Not fixed here (unreachable through any real code path today), but flagged in case a
future change (e.g. an admin "force-end round" debug command) ever calls `report_round_result()`
outside the normal `RoundManager` chain.

**The one real functional gap in Q-4 — the world kept running behind the result screen — is now
fixed.** `match_result.gd::_on_match_won` sets `get_tree().paused = true` when not networked
(reusing Q-3/B-64's `PROCESS_MODE_ALWAYS` on this node so its own buttons stay clickable);
`_on_rematch_pressed()` and `_on_menu_pressed()` both clear it before doing anything else, for the
same reason Q-3's `_on_return_to_menu_pressed()` does. Networked play is untouched — freezing one
peer's tree while the host's authoritative match state keeps running for everyone else would
desync it, same split as Q-3. Verified live, headless: Local Match — `tree_paused` reads `true`
the instant `match_won` fires, `false` again immediately after Rematch, and the new round starts
active. Networked — both host and client show the result screen (confirming the existing
`_sync_match_won` RPC reaches the client fine) with `tree_paused` staying `false` on both the whole
time.

**Q-4 restyle to the moodboard Bo5 grid, done.** `MatchResult.tscn`/`match_result.gd` replace the
plain message-only card with: a winner headline at `UiTheme.FONT_SIZE_DISPLAY`; a two-team pip row
(three squares each, filled for rounds won, from `MatchManager.team_a_wins`/`team_b_wins`); and a
card accent bar. Per §4.2's hard rule, colour tracks **role**, never team — the accent bar and both
teams' pip fill colours are `UiTheme.OFFENSE`/`DEFENSE` keyed off `MatchManager.team_a_is_can` as
it stood in the just-concluded final round (read before anything resets it), not by which team A/B
letter the pips sit under. Verified live, headless, by reading the actual computed `StyleBoxFlat`s
back off the nodes after driving to a real 3-0: winner headline text correct, card's accent
`border_width_left` = `ACCENT_BAR_WIDTH + BORDER_WIDTH` (9, confirming the accent path actually
ran, not the plain no-accent branch), accent `border_color` matched `UiTheme.DEFENSE` exactly
(Team A won this run holding the Can/Defense side in the final round), all three Team A pips
filled with that same `DEFENSE` color, and all three Team B pips at `UiTheme.CARD` (empty/unfilled,
matching its 0 wins). Buttons unchanged (`Rematch`, relabelled `MAIN MENU` per `Dev_Plan.md` §4.3)
through the existing theme; non-host Rematch hide untouched.

**Q-10 verification note — no code changed.** Confirmed §0.2's characterization exactly: the
switcher and `DebugBar` are both fully built, wired into `Main.tscn`, and **already discoverable**.
`debug_bar.gd`'s `_keys_label.text` has read `"F1-F4 set P1 · Shift+F1-F4 set P2 · Tab cycle · F5
solo · F6 reset"` since the feature's original commit (v1.4) — this is not new. Step 1's concern
(bar reading `"(missing)"`) does not reproduce: verified live, headless, that `Slots` reads a fully
populated `"P1▶ TeamAPerson (Person · Team A · DEFENSE)   P2▶ TeamAProp (Can · Team A · DEFENSE)"`
on a fresh Local Match — `_match_root()`'s walk-up-from-the-bar resolution is working correctly.
Step 4 (does the switcher still work during Q-3's pause) — verified live: paused the tree, sent a
real synthetic Tab keypress via `Input.parse_input_event`, and the readout correctly updated
(`P1` cycled from `TeamAPerson` to `TeamBProp`) while `get_tree().paused` was still `true` —
`DebugPlayerSwitcher`'s `PROCESS_MODE_ALWAYS` continues to work correctly after Q-3's changes.
**Flagging a real conflict in the queue's own instructions, not building around it (protocol rule
3):** step 2 asks for the key hint to be styled "at `UiTheme.FONT_SIZE_CAPTION` in
`UiTheme.INK_MUTED`" — but `debug_bar.gd`'s own header comment explicitly states the opposite
design intent: *"Deliberately ugly: plain white monospace on a black strip, with NO reference to
`UiTheme` and no theme of its own, so nobody mistakes it for shipping UI and so removing it can
never leave a hole in the real design system."* Styling this debug-only bar with real design-system
tokens would violate that stated rationale and the §0.3 removal contract's spirit (a debug feature
should never look like it belongs to the shipped product). Left `debug_bar.gd` completely
unmodified rather than apply the conflicting instruction. No `Dev_Plan.md` §3.5 update needed —
step 1 found no behavior change to record.

**Q-9 verification note.** Added a `QuitButton` to `TitleScreen` (order: Play · Settings · Quit,
per `Dev_Plan.md` §4.3 — `StartButton`'s label also changed from "START" to "PLAY" to match), wired
to a plain `get_tree().quit()`. Deliberately title-screen-only, not the in-match pause menu — a
mid-match quit that skips `NetworkManager.disconnect_network()` would strand other peers, the same
soft-lock Q-1 fixed from the other end. Moodboard pass: wrapped `TitleScreen`'s and `PlayMenu`'s
existing content each in a new `PanelContainer` card (`UiTheme.card_style(PANEL, INK, IMPACT)` —
IMPACT chosen as a neutral brand accent since neither panel is role-specific), applied in code via
`add_theme_stylebox_override`, same pattern as the Q-4/Q-5 cards. Kept the existing node types
(`VBoxContainer` positioning containers, unchanged anchors) and only added one nesting level rather
than restructuring the proven layout — there is no way to visually inspect pixel layout in this
headless-only session, so a larger structural rewrite would have been an unverifiable risk for a
task whose acceptance criteria don't require one. Button font sizes and consistent width were
already satisfied by the theme applied project-wide since v1.3 — no per-node change needed there.
`GameVersion.attach_to(self)` build stamp untouched. Display typeface remains the open blocker in
§0.5 — shipped on the default font, as before.
Verified live, headless: `MainMenu.tscn` and the full `Main.tscn` flow both load with zero script
errors after the restructure; pressing `QuitButton` (via its own `pressed` signal, connected
identically to every other button on the screen) exits the process cleanly (exit code 0) with no
further code executing afterward — confirmed by a print statement placed after the signal emission
that correctly never ran.

**B-66 · Hit feedback only ever played on the struck character's own owning peer. (NEW, Q-8)**
`_apply_hit_result` is `@rpc("any_peer", "call_local", "reliable")`, sent by the host via
`rpc_id(target_authority, ...)` — reaching only that one peer. Every other peer watching the same
hit land saw nothing at all: no flash, no shake, no particles.
**[FIXED]** split the cosmetic half out into a new `_rpc_play_hit_vfx()`, broadcast to every peer
from `hitbox.gd` right after the existing state-resolution call; state resolution
(`apply_stagger`/`go_downed`/`seal`/`apply_dent`) stays exactly where it was, on the authority.
Also added, per Q-8's scope: `CameraRig.shake()` — a decaying positional offset on the camera node
(never the character body's rotation, which would fight `_is_mouse_aimed()` and reproduce B-60),
FPP at half TPP's strength, clamped via `max(current, new)` so rapid multi-hits can't stack; and
`CharacterVisual._spawn_impact_particles()` — a code-built one-shot `GPUParticles3D` burst in
`UiTheme.IMPACT`, no art asset, self-freeing on `finished`. `CharacterBase._flash_hit()` gates the
shake call to only the struck player's own screen (`is_multiplayer_authority()` when networked,
`player_id == 1` in Local Match — same resolution Q-5's YOU card already uses).
Found and fixed a second real bug while verifying this one, in code from THIS same task, not
pre-existing: the queue's own instructions specified `_rpc_play_hit_vfx` as
`@rpc("authority", ...)`. Confirmed live with two real headless peers that this is wrong — hit
resolution always runs on the **host** (`hitbox.gd`), but a struck character's multiplayer
authority is its *owning peer*, which for any non-host player's own unit is **not** the host.
Godot's `"authority"` RPC mode only accepts a call sent **by** that specific node's own authority,
so the host calling it on a client's own character was silently rejected — the client's console
logged `RPC '_rpc_play_hit_vfx' is not allowed ... Mode is "authority"`, meaning the fix would have
shipped working only for hits landing on the host's own unit and doing nothing for anyone else,
the exact bug it was meant to close. Switched to `"any_peer"`, matching `_apply_hit_result`'s
already-correct pattern one line above it.
Verified live, headless: Local Match — the driven unit's rig shows an active shake and exactly one
`GPUParticles3D` child after a simulated hit, a second (not-mine) character's rig never activates
its shake, holding a movement key through the hit leaves body `rotation.y` provably unchanged
(the B-60 regression check), the shake fully decays and the camera returns to its exact cached
base position, and the particle node frees itself afterward. Networked, after the `any_peer` fix —
both a hit landing on the host's own character and one landing on the client's own character
broadcast correctly to both peers with no errors, where the initial `"authority"` version failed
for the second case exactly as predicted.

**B-64 · The pause menu never actually paused anything. (NEW, Q-3)** `main.gd::_unhandled_input`
toggled `pause_root.visible` and the cursor, never `get_tree().paused` — `RoundManager`'s round
timer, `MatchManager`'s intermission countdown, and every `CharacterBase._physics_process` (input,
gravity) kept running behind the overlay.
**[FIXED]** Local Match now gets a real `get_tree().paused` freeze; networked play stays a
non-freezing overlay that says so ("The match is still running.", under the title — one line since the
card was restyled, appended to the title before that) (a naive freeze would
stop the host's authoritative timer for everyone, or stop a client's own movement while the host
keeps simulating it — Handoff.md §0.3). Caught a second, undocumented bug while implementing the
first: Godot gates `_unhandled_input` by `process_mode` exactly like `_process`, and `Main`'s own
script (running the Esc-toggle) sits at the default `PROCESS_MODE_INHERIT` — so the instant Local
Match actually paused, `Main` would stop receiving input entirely, including the Esc press meant
to resume it, permanently soft-locking the game. Confirmed with a standalone headless
`SceneTree`-script test before touching the real scene: an `INHERIT`-mode node's
`_unhandled_input` never fires while `paused` is true, only an `ALWAYS`-mode node's does. Fixed by
moving the Esc listener onto a new `scripts/ui/pause_layer.gd` (`class_name PauseLayer`) attached
to `PauseLayer` itself, which is already `PROCESS_MODE_ALWAYS`; it emits `toggle_requested`, which
`main.gd` connects to. `HUDLayer/MatchResult` is also now `PROCESS_MODE_ALWAYS` (Q-4 needs it to
stay clickable if a match ends the same frame pause fires). `_on_return_to_menu_pressed()` clears
`get_tree().paused` as its first line, before `change_scene_to_file` — a scene change with the
tree still paused would otherwise load `MainMenu.tscn` paused and kill every button on it.
Verified live, headless, with real key-event injection (`Input.parse_input_event`, not calling the
handler function directly) exercising the exact input path: Local Match — timer frozen bit-for-bit
during a 3s pause, Esc correctly resumes it (confirming the `PauseLayer` fix), timer decreasing
again after, Return to Menu leaves `tree_paused=false`, and a second Local Match started
immediately after is fully interactive (`round_active=true`, timer counting from a fresh 90.0).
Networked — client's overlay shows the "still running" label, `get_tree().paused` stays `false`
throughout, the client's own timer read kept decreasing across the pause, and the host's timer
ticked continuously and identically the whole time, unaffected by the client's local overlay.

**B-63 · A mid-round client disconnect left `RoundManager` tracking a freed Can. (NEW, Q-2)**
`main.gd::_on_player_disconnected()` freed the leaver's node and erased its dictionary entries,
but never told `RoundManager` — if the leaver was the tracked Can, `_tracked_cans` kept a freed
reference for the rest of that round (self-heals on the next round transition via `_reset_world`,
which already clears and rebuilds it, but not before then). No toast either — remaining peers had
no idea anyone had left.
**[FIXED]** extracted the reregistration loop `_sync_state_to_late_joiner` already ran into a
shared `_reregister_tracked_cans()` helper, called from both that function and
`_on_player_disconnected()` (host-only, same gate `RoundManager` uses throughout). Added
`@rpc("authority", "call_local", "reliable") func _rpc_show_toast()`, broadcast to every peer on
disconnect. Verified live, headless, three real instances (one host, two clients): disconnecting
the client holding the Can produced a clean re-registration with no dangling reference, and both
remaining peers (host and the other client) printed the toast (temporary instrumentation,
reverted before commit). One caveat, honestly reported: with only one Can per round by design
(the Prop of whichever team holds the defensive side), disconnecting that exact Can leaves nobody
left to dent/seal for the remainder of that round — the round can still only end by timer, same as
before the fix. That is correct given the current 1-Can-per-round design, not a regression; the
fix's actual contribution is the toast and the elimination of the dangling reference, not a new
way to end a Can-less round early. A one-off `ERR_UNAUTHORIZED` replication error surfaced on the
first test run (`on_despawn_receive`) but did not reproduce on a repeat with a longer settle time
between join and disconnect — concluded to be a test-timing artifact (killing a client within ~2s
of it joining, before spawn replication had settled), not a defect in this fix.

**B-62 · Clients hung forever when the host quit. (NEW, Q-1)** `NetworkManager.server_disconnected`
already fired and already nulled the peer / cleared `connected_peer_ids`, but nothing in the
codebase listened to it — a client was left in `Main.tscn` with a dead peer, a frozen timer, and
no way out but Alt+F4. A join to an unreachable address (`connection_failed`) had the same
soft-lock, just triggered before anyone ever connected.
**[FIXED]** `main.gd::_start_joining()` connects both signals (not `_ready()` — a host has no
server to lose and Local Match has no `NetworkManager` session at all). Both handlers release the
mouse, reset `MatchManager`/`RoundManager`/`GameLaunch`, set a new
`GameLaunch.pending_status_message`, and return to `MainMenu.tscn`; `main_menu.gd` lands on the
Play menu (not the title screen) and shows that message once. Verified live, headless, with the
real Godot 4.7 binary: joining `127.0.0.1` with no host running printed
`connection_failed fired` and the menu consumed `"Could not reach that host."`; hosting, joining
from a second instance, then force-killing the host process printed `server_disconnected fired`
and the client's menu consumed `"Host ended the match."` (temporary print instrumentation,
reverted before commit, same as B-01/B-29's verification pattern).

---


