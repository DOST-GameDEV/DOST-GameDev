# Handoff — Tumbang Preso

The one handoff doc. Design is in [`Tumbang_Preso_2v2_GDD.md`](Tumbang_Preso_2v2_GDD.md); the
plan, architecture, and build status are in [`Dev_Plan.md`](Dev_Plan.md); the fixed-bug forensic
archive is in [`Bug_Ledger.md`](Bug_Ledger.md).

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
| [`Design_Agent_Brief.md`](Design_Agent_Brief.md) | 3D modelling — the `M-` block, meshes and the generator | Opus (design) / Sonnet (toolchain) |
| [`Environment_Art_Agent_Brief.md`](Environment_Art_Agent_Brief.md) | The maps, the dressed boundary, field markings, skyboxes | **Opus, high** |
| [`Interaction_Tuning_Agent_Brief.md`](Interaction_Tuning_Agent_Brief.md) | Carry / throw / grab / reset channel — playtest and retune | **Sonnet, high** |
| [`UI_Completion_Agent_Brief.md`](UI_Completion_Agent_Brief.md) | Charge meters, character select, off-screen indicators, typeface | **Sonnet, medium** |
| [`Audio_Agent_Brief.md`](Audio_Agent_Brief.md) | The entire audio workstream — nothing exists today | **Sonnet, medium** |
| [`Netcode_Agent_Brief.md`](Netcode_Agent_Brief.md) | Interpolation, rejoin identity, real-device LAN hardening | **Sonnet, high** |
| [`Submission_Agent_Brief.md`](Submission_Agent_Brief.md) | Trailer, demo video, synopsis, forms, demo-day script | **Opus, high** |

> **Note for the humans:** §1 (System Context) and §2 (AI Execution Protocol) are **frozen**. They
> are reproduced here unchanged, as every handoff must. Do not edit them without saying so out
> loud in a commit message.

---

## 0. Session log — where the project stands right now

### 0.11 CHECKLIST 1.2 — prop scale decided: hero-scaled props, carried-scale tsinelas (2026-07-28)

**Branch:** `art/prop-scale-and-kit`. **Lane:** 🎨 Design. **Supersedes nothing** — 1.2 was open,
never answered. `Environment_Art_Agent_Brief.md` §7 and `Checklist.md` 1.2 both carried option (a)
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
   this pass's `viewmodel_tpp.png`. `Design_Agent_Brief.md` §2's table is the source of the error —
   it assigns `DEFENSE` to "Can body, tsinelas sole" — and **that table is wrong**, not the rule.
2. **B-82 — `Main.tscn`'s floor top is `y = +0.5`, not `y = 0`.** `Floor` and its `CollisionShape3D`
   carry no transform, and the shape is a `(40, 1, 40)` box centred on the origin, so it spans
   `-0.5 … +0.5`. `Environment_Art_Agent_Brief.md` §4.1 and `Checklist.md` both state the top
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
- **No map, no audio, no character select.** Untouched, all queued.
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

### P1 — found by the design lane while measuring for checklist 1.2 (2026-07-28)

Filed, deliberately not fixed — `Concurrency_Protocol.md` §10. Full reasoning and the screenshot
evidence are in §0.11. B-81 is in the design lane's own territory and is still filed rather than
folded into an unrelated commit, because changing a hero prop's colour deserves its own commit and
its own render.

**B-81 · The tsinelas sole is painted `DEFENSE` blue, on a unit that only ever exists on
offence. [FIXED 2026-07-28]** Sole → `IMPACT`, straps → `HIGHLIGHT`, toe post → `INK`, and the
materials renamed from palette tokens (`defense`/`impact`/`highlight`) to parts
(`sole`/`strap`/`post`) — a material literally named `defense` is a bug that reads as correct in
every diff, and renaming also changes the `.obj`, which is what forces the reimport the `.mtl`
alone would not. **Verified by render:** no role hue anywhere on the slipper, and the Y-strap reads
*better* than it did — yellow on magenta separates at FPP distance where pink on blue did not.
Original report follows. `tools/models/generate_all.gd::_build_tsinelas()` sets the sole material to
`UiTheme.DEFENSE` (`#0080e8`). A Prop is a Tsinelas exactly when its team is **attacking**, so the
attacking team's prop wears the defending colour — a direct breach of `Dev_Plan.md` §4.2 ("never
reuse either hue for anything else"). The moodboard disagrees independently: **THE SLIPPER's card
accent is magenta**, as is **THE CAN's**. Visible in this pass's `viewmodel_tpp.png` as a bright
blue slab.
*Root cause of the error:* `Design_Agent_Brief.md` §2's palette table assigns `DEFENSE` to "Can
body, **tsinelas sole**". **That table is wrong and the rule is right.**
*Severity:* P1 — it teaches the player the wrong colour language on the most-looked-at object in
the game.
*Fix:* sole → `UiTheme.IMPACT`, keep the straps readable against it (they are `IMPACT` today, so
they move to `HIGHLIGHT`); regenerate; render both viewmodel shots. Correct the brief's table in
the same commit. The lata is **not** in scope — a blue can on the defending side is consistent, and
it renders well.

**B-82 · `Main.tscn`'s floor top surface is `y = +0.5`, not `y = 0` — and two docs say
otherwise. (NEW)** `Floor` and its `CollisionShape3D` carry **no transform**, and the shape is a
`BoxShape3D` of `(40, 1, 40)`, so the slab spans `y = -0.5 … +0.5`.
`Environment_Art_Agent_Brief.md` §4.1 and `Checklist.md` both assert the top surface is `y = 0` and
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
`Environment_Kit_Spec.md` §4.

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

**B-71 · Tracked `.import` UIDs regenerate on any cache rebuild. (NEW, low)** Opening the
project on a second machine rebuilt `.godot/` and reassigned
`assets/characters/persons/Textures/colormap.png.import`'s `uid://` — a tracked file, so it
surfaced as a permanent dirty working tree until committed (`5a2e0e0`). Nothing references that
texture by UID, so this instance was inert, but it will recur on every fresh clone and machine
switch, and it is exactly the kind of noise that makes a "regenerate and check `git status`"
acceptance test unreliable. *Decision owed:* either accept the churn, or stop tracking `.import`
UIDs. Not urgent; log it before it eats an hour of somebody's debugging.

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
| 5.3 | Strip Local Match + debug switcher | Sonnet | **high** | `Main.tscn` and `main.gd` spawn paths; the removal grep must come back empty |
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

**[DONE @ v3.7]** Landed in commit 50ec425. `generate_all.gd` has the full profile-and-revolve
body (five stacked revolves: ink base crimp, defense lower wall, highlight label band,
defense upper wall, ink shoulder+rolled rim+recessed lid). Three dent states generated
via `_apply_dents` deform callable. `CanVisual.tscn` updated to use `lata.obj`. Dent mesh
swap wired in `character_visual.gd::_on_dents_changed` / `_refresh_can_damage`. Downed tilt
(78° on 0.28s Back/Out tween) in `_refresh_downed_tilt`. Walk/run locomotion also added
in the same session. Acceptance test pending human play session.

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
