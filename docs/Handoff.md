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

## Jump to

<sub>Auto-added 2026-07-30 so this file stops being one long scroll. Keep it in step when you add a `##` section.</sub>

- [0. Session log — condensed 2026-07-30](#0-session-log-condensed-2026-07-30)
- [1. System Context](#1-system-context)
- [2. AI Execution Protocol](#2-ai-execution-protocol)
- [3. Bug & Issue Ledger](#3-bug-issue-ledger)
- [4. Execution Queue — condensed 2026-07-30](#4-execution-queue-condensed-2026-07-30)
- [5. Decisions the team owes](#5-decisions-the-team-owes)
- [6. Two things nobody has scheduled, both on the critical path](#6-two-things-nobody-has-scheduled-both-on-the-critical-path)
- [7. Working notes](#7-working-notes)

| [`Agent_Prompts.md`](Agent_Prompts.md) | Charge meters, character select, off-screen indicators, typeface | **Sonnet, medium** |
| [`Agent_Prompts.md`](Agent_Prompts.md) | The entire audio workstream — **shipped 2026-07-29 (4.1)**, awaiting a listening pass | **Sonnet, medium** |
| [`Agent_Prompts.md`](Agent_Prompts.md) | Interpolation, rejoin identity, real-device LAN hardening | **Sonnet, high** |
| [`Agent_Prompts.md`](Agent_Prompts.md) | Trailer, demo video, synopsis, forms, demo-day script | **Opus, high** |

> **Note for the humans:** §1 (System Context) and §2 (AI Execution Protocol) are **frozen**. They
> are reproduced here unchanged, as every handoff must. Do not edit them without saying so out
> loud in a commit message.

---

## 0. Session log — condensed 2026-07-30

**Twelve dated narrative entries (0.1 … 0.15, ~600 lines) were deleted.** They recorded how the
project got here between 2026-07-27 and 07-28; `git log` and `Checklist.md` both carry that better.
What survived is only what still CONSTRAINS work.

### Standing decisions — do not relitigate these

| Decision | Detail |
|---|---|
| **Camera** | **Person → FPP. Prop (Can/Tsinelas) → TPP.** Derived from `is_person`, no toggle, no override, no exception. `camera_rig.gd` derives `_mode` in `_ready()` with no export backing it; keep it that way. ⚠️ Still not enforced at scene level — `Main.tscn` carries a scene-level `Camera3D` on `arena_camera.gd` with `follow_paths` at the local-test characters. That violates `Dev_Plan.md` §2 rule 4, caused B-03, and keeps B-58 open. A-2 deletes it; until then the rule holds only because `arena_camera.gd::_ready()` sets `current = false`. |
| **Typeface** | **Darumadrop One** (SIL OFL 1.1), explicit human yes, licence at `assets/ui/fonts/DarumadropOne_LICENSE.txt`, in LFS, citable on Form 03. It is `theme.default_font`. Open: F-2 wanted a second clean-grotesque body face because a display face is thin at `FONT_SIZE_CAPTION` 13 — Darumadrop is doing both jobs. Needs another explicit yes, so it is deliberately not pre-empted. |
| **Hero prop colour** | The second asset moodboard supersedes B-81's *colour choice*, not B-81's *rule*: a sole must not wear a role hue. Sole `PROP_FOAM` brown, strap `PROP_WEBBING` tan; the can is Sarsi livery. |
| **Single Player** | A permanent shipping mode, not a harness to strip. Starts on confirm — a solo player has nobody to wait for. The in-MATCH ready prompt (`_awaiting_local_ready`, "3 · 2 · 1 · GO") is a different thing and stays. |
| **Arena footprint** | Original size. Not an art-pass variable. |
| **Map shading split** | Characters keep the toon pass; the map does not. A toon + inverted-hull pass across ~510 map instances shipped once, read as horizontal banding on flat walls, and was laggy elsewhere. The rollback measured 90 → 203 fps. No new map shader without a measured frame-time justification and a cheaper fallback. |


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

**B-137 · THE SLIPPER'S COLLISION AND HURTBOX RE-ENABLE WAS SILENTLY DROPPED ON EVERY PATH THAT
STARTS WITH A HIT. [FIXED 2026-07-29]**

Found by the round-reset audit, using `tools/ai_probe.tscn -- fairness` as the instrument — a single
20-round run logged **11 blocked `monitorable` writes and 3 blocked `disabled` writes**. Nothing in
the game reported anything: the writes simply did not happen.

`Carriable._set_physics_enabled()` wrote `CollisionShape3D.disabled` and `Area3D.monitorable`
directly. Godot refuses both while the physics server is mid-step — *"Can't change this state while
flushing queries"* and *"Function blocked during in/out signal"* — and **every important caller
reaches this function from inside an `area_entered` callback, because that is where hits resolve:**

 1. **Tagged mid-carry.** `hitbox.gd::_on_area_entered` → `_apply_hit_result` → `apply_stagger` →
    `_set_state` → `_on_carrier_state_changed` → `host_drop` → `_rpc_set_loose` → here. The
    re-enable was dropped, so **the slipper knocked out of a tagged carrier's hands came back with
    its collision shape still disabled**, free to sink through the floor. B-75 calls knocking the
    slipper loose "most of the point of tagging"; B-101 is this same failure from the other side.
 2. **A round won by a tag.** The same callback → `report_round_win` → `report_round_result` →
    `_reset_world` → `reset_for_new_round` → here. **The hurtbox stayed non-monitorable into the
    next round**, and `carrier.gd::_find_grabbable()` finds slippers by scanning its GrabArea for
    Hurtboxes — so the attacker could not pick their own tsinelas up at all. A tag ends 18 of 20
    rounds, so this is the common path, not an edge case.

*Fix.* `set_deferred()` on both, which is what each engine message asks for. The change lands at idle
rather than instantly — one frame in which the slipper is still intangible, which is invisible and is
strictly better than never.

*Verified:* the same 20-round run goes from 14 blocked writes to **0**. And the fairness table moved
where the bug predicts it should: **longest still-run 6.83 s → 1.92 s, inside the < 2 s bar for the
first time this project has ever measured it.** That is the causal signature — an attacker standing
next to a slipper it could not pick up is exactly what a long still-run is.

⚠️ **This is the class B-128 fixed one instance of, and the class is now known to be wider than
"knockback between rounds".** Any state write reached from a hit callback is suspect. The generic
rule: **hits resolve inside a physics callback, so anything they touch that changes collision or
monitoring state must be deferred.**

**B-136 · STEP AND TOUCH ON AN OPPONENT'S TSINELAS. [ADDED 2026-07-29 — both branches verified
firing; the shove's MAGNITUDE is not]**

Human request: *"add a mechanic that defender can step or touch the slipper of enemy team and it will
slow down or get knocked back (knock back for the touch)."*

This is the missing half of the ownership rule `carriable.gd` already stated: an opponent's slipper
"is still a solid, kickable obstacle — you can body-check it." The rule said kickable and the code
only meant collidable.

Detection sits in `character_base.gd::_scuff_enemy_slippers()`, read off `move_and_slide()`'s own
collision results — the only place that knows both WHAT was touched and FROM WHAT ANGLE, and the
angle is the mechanic. It only ASKS; `Carriable.host_scuff()` re-validates and broadcasts, same
client-asks/host-decides split as every grab and throw. Harness: **`tools/scuff_probe.tscn`**.

*Two traps hit while building it, both worth more than the feature:*

 1. **STEP vs TOUCH cannot be told apart by the contact point.** The first version asked whether the
    contact happened near the walker's feet — but a tsinelas lies on the ground, so *every* contact
    with it does, including walking squarely into its side. TOUCH became unreachable. It now compares
    the slipper's TOP against the walker's feet, which is the actual question. (Nor can it be told
    apart by the normal alone: a 0.16-radius capsule returns an angled normal unless you land dead
    centre — the step branch fired 0 times in 40 frames of a Person dropped straight onto one.)
 2. **DISPLACEMENT IS NOT EVIDENCE THAT THE MECHANIC RAN.** A Person walking through a loose slipper
    displaces it by ordinary depenetration whether or not any of this code executes. The probe
    "passed" on 0.417 m while the touch branch was never firing at all. What caught it: setting
    `TOUCH_KNOCKBACK_SPEED` to 2.6, 8.5 and 14.0 and getting **0.417 m every time** — a number that
    does not respond to the constant it depends on is not measuring that constant. `Carriable` now
    carries `scuffs_stepped` / `scuffs_touched` counters so the test observes the branch itself.

*Verified* — `tools/scuff_probe.tscn`, 7/7:

 - an opponent may scuff a loose enemy tsinelas; its own team's Person may not; it may not scuff
   itself; a **lata** may not be scuffed at all (it is hit or reset, never kicked);
 - TOUCH: the branch applies (1 scuff) and the slipper travels 0.417 m;
 - STEP: the branch applies (30 scuffs over 30 contact-frames, best normal.y 0.96) and the crawl
   scale drops 0.450 → 0.158, i.e. exactly `CRAWL_SPEED_SCALE × STEP_SLOW_SCALE`.

**The shove's magnitude checks out too, on the corrected harness: 1.272 m measured against 1.20 m
predicted from `v² / (2 × FRICTION)`.** ⚠️ An earlier version of this entry said 0.417 m and "does
not scale with the constant". That was a true measurement of the wrong thing — the touch branch was
not firing then, and 0.417 m was ordinary depenetration, which naturally ignores the constant.

⚠️ **STILL NOT VERIFIED, and honest gaps:**

 - **The client→host `_rpc_request_scuff` path.** A two-peer run had the HOST owning the Person doing
   the scuffing, so the client only ran the predicate half and printed *"this peer does not own 1."*
   The RPC is written to the same shape as `carrier.gd::_rpc_request_grab` but has not been executed.
   Re-run with enough peers that a CLIENT owns a Person opposing the slipper.
 - **`scuff_probe` is FLAKY, roughly 1 run in 2 on the current build, and it fails honestly rather
   than falsely.** It drives a live AI match, and the AI re-grabs the slipper and knocks the test
   Person down constantly; each such run prints a `HARNESS:` line saying it proved nothing rather
   than reporting a mechanic failure. Both branches have passed repeatedly with direct branch
   counters (TOUCH 1 scuff / 1.272 m; STEP 25–30 scuffs / crawl 0.450 → 0.158). **Re-run it a couple
   of times before believing a red result**, and read the `HARNESS:` lines first.

**B-138 · A PERSON COULD BE SEALED — PERMANENTLY OUT OF THE ROUND — BY ONE THROWN SLIPPER.
[FIXED 2026-07-29, regression from B-134]**

SEALED has no recovery: `_physics_process`'s SEALED branch is literally `pass # awaiting round
reset`. For a lata that is the entire Option B win condition. For a **Person** it means one hit
removes a player from the round for good, and both routes to it applied to Persons:

 - `character_base.gd`'s DOWNED branch auto-sealed anything whose self-right window lapsed;
 - `hitbox.gd` resolved `kind = "seal"` against any DOWNED, non-self-rightable target.

Neither was ever intended — the GDD's "reach it and seal it" is about the can standing in its circle.
It went unnoticed because a thrown slipper used to resolve on the melee hitbox and merely stagger
(B-134). **The moment throws started actually knocking things down, every Person hit by one was
DOWNED for 2 s and then SEALED for the rest of the round.**

Caught by `tools/scuff_probe.tscn`, which could not drive its test Person and printed `state=2` then
`state=3` on four consecutive calibration attempts. Both paths are now gated on `is_can`; a
knocked-down Person gets back up.

**B-134 · A THROWN SLIPPER RESOLVED ON THE CHARACTER'S BODY-CHECK HITBOX, SO THE THROW PROFILE WAS
BYPASSED AND THE CAN COULD NOT FALL OVER. [FIXED 2026-07-29]**

Human question: *"can the can even fall?"* Measured answer, with `tools/hit_probe.tscn -- --host
target=can` aiming dead at the can's own hurtbox centre at full charge: **0 knockdowns in 40 throws.**

A flying tsinelas carries two live hitboxes. One is its ThrowProfile's pulse box
(`Carriable._spawn_flight_hitbox`), which knows what was thrown. The other is `CharacterBase.tscn`'s
own melee Hitbox — the unit's **body-check reach**, radius 0.14 at a 0.16 offset, carrying
`forces_downed = false` and no knowledge of the profile at all. `is_hitbox_active()` deliberately
returned true for it during flight (added when the profile box could not be relied on), so whenever
it won the race `hitbox.gd` resolved the throw as a plain `"stagger"` no matter what was thrown.

**It won constantly, and the reason is arithmetic rather than luck.** Against a Person the melee band
is `0.14 + 0.45 = 0.59` and the profile band is `0.30 + 0.45 = 0.75` — a 0.16 m difference, against
0.433 m of travel per physics frame. The two therefore start overlapping on the *same* frame, and
`_step_flying()` calls `sweep_hitbox()` at the top of that frame, before the profile box's own
`area_entered` is delivered. Measured on a four-peer session: **33 of 40 throws resolved on melee.**

*Fix.* `is_hitbox_active()` no longer reports the melee box live during flight, so the profile's box
is the only thing that resolves a throw; and `sweep_hitbox()` now sweeps the transient hitboxes too,
which is what the flying clause was originally added to provide. `register_hit_once()` is already
keyed on the owner, so the two boxes cannot double-resolve.

Also fixed alongside, same symptom: **`throw_flick.forces_downed` was `false`**, so the flick slipper
could never knock the can over at all and could not win an Option B round by any route. Now `true`,
making all four profiles uniform — which is what `Checklist.md` already claimed was the case.

Measured either side, 40 dead-centre full-charge throws at the can:

| | before | after |
|---|---|---|
| contacts | 12 | 14 |
| resolved on the melee box | 6 | **0** |
| reached DOWNED | **0** | **14** |

⚠️ **A SECOND, SEPARATE PROBLEM SURFACED BY THE SAME MEASUREMENT: only 12–14 of 40 dead-centre
throws made contact at all.** Not this bug — the can evades (`CAN_EVADE_*`) and its hurtbox radius is
0.17, which made the dodge (not aim, not spread, not the hitbox) the single biggest reason a throw
misses. **Human call, 2026-07-29: nerf the dodge.** Done via `CAN_EVADE_MISS_MARGIN` 1.0 → 0.55 —
see that constant for why the MARGIN and not the lookahead, and why `CAN_EVADE_STEP` was tried and
reverted. Contacts measured 12–14 → 15–17, and every contact still knocks the can down.

**B-135 · THE LUCKY FALL — a knockdown that costs the attacking side nothing. [ADDED 2026-07-29]**

Human request: *"make it easier to fall, but sometimes make it so that it can land on its head/back
and this isnt a point for the enemy."*

`CharacterBase.LUCKY_FALL_CHANCE` (0.25, **a first guess — the tuning pass has not happened**). Rolled in
`hitbox.gd` where `kind` is decided, which is already past the host gate, and shipped as its own kind
`"downed_lucky"` through the `_apply_hit_result` broadcast every other outcome already uses. ⚠️ It is
never rolled inside `_apply_hit_result` — that runs per-peer, and peers would disagree about whether
the round had just been decided.

Two things had to change for "no point for the enemy" to actually be true:

 1. `RoundManager._on_tracked_can_state_changed` does not count it toward `FALL_LIMIT`. That handler
    received only the new state and so could not tell WHICH can fell; `register_can()` now **binds
    the can into the connection**. ⚠️ `bind()` returns a different Callable, so the `is_connected`
    guard and the `disconnect` had to be bound too — `register_can()` runs every round, and getting
    that wrong would stack a connection per round and count every fall twice by round 2.
 2. It **self-rights instead of auto-sealing**. Skipping the fall count alone would not have been
    enough: under Option B an unrecovered fall auto-seals and a seal loses the round outright, so a
    "free" fall would still have cost the defence the round.

The sound and the faceslop are deliberately identical to a scoring knockdown — the can really did go
over, and telling the attacker their hit was worthless before it lands is the opposite of the beat.

*Verified* by `tools/hit_probe.tscn -- target=can`, which samples `RoundManager._fall_count` either
side of each knockdown and asserts the delta — 0 for a lucky fall, 1 for a scoring one. Reading the
counter once at the end proves nothing: `start_round()` zeroes it every round.

 - **Local, 1 peer:** 12 knockdowns, 3 lucky, 9 scoring — **0 deltas wrong of 12.**
 - **Networked, 3 peers:** 26 knockdowns, 14 lucky, 12 scoring — **0 deltas wrong of 26.** This
   exercises the real path, where `kind` crosses the wire as an RPC argument.

⚠️ **THE OBSERVED LUCKY SHARE IS NOT `LUCKY_FALL_CHANCE`, AND IT IS NOT SUPPOSED TO BE.** 14 of 26 is
54% against a 0.25 roll — more than three standard deviations out, so it looks like a bug and is not
one. It is a **selection effect the feature creates**: a scoring fall that goes unrecovered
auto-seals and ENDS the round, so a round contains at most one of them, while a lucky fall self-rights
and puts the can straight back in play to be knocked over again. Lucky falls are therefore
over-represented among the falls anyone can observe. Do not "correct" the constant against this
number — the roll itself is fair, and the per-fall delta assertion above is the thing that actually
validates the feature. The real balance consequence to watch is the other one: **lucky falls make
rounds longer.**

**B-133 · A LATE-JOINING PEER SILENTLY DISCARDS EVERY SYNC PACKET FOR CHARACTERS THAT ALREADY
EXISTED WHEN IT CONNECTED. [OPEN — root-caused and measured, NOT fixed]**

Report: *"there are times you can't hit an opposing player."* Harness: **`tools/hit_probe.tscn`**,
a real multi-peer ENet session. ⚠️ **Two peers cannot reproduce this.** With two peers `main.gd`
fills the other two slots with host-owned AI, so every opposing Person is local to the resolving
host and the failing condition never arises. `net_spawn_probe` passes clean throughout. **Run four.**

*What was ruled OUT, by measurement, so nobody re-checks them:*

 - **Collision layers/masks.** Correct on every peer, every character, every round: Hurtbox
   `layer 2 / mask 0`, Hitbox `layer 0 / mask 2`, `monitorable` true. `ability_utils.gd`'s
   "first-pass / untested in-editor: double check the collision layers" comment is stale — they
   are right. Not the bug.
 - **Tunnelling.** The fastest profile (`throw_flick`, 26.0) steps **0.433 m** per physics frame
   against an overlap band **1.50 m** wide for a Person — about 3.5 frames of contact. Not the bug.
   ⚠️ The first version of the probe reported 1.62 m/frame, which at 60 Hz is 97 m/s from a slipper
   that launches at 26. Two numbers that could not both be true: it was sampling past the landing,
   where the AI attacker re-grabs the slipper and `_step_carried()` snaps it to the hand in one
   frame. The metric was the bug, exactly as the method note warns.
 - **The host missing hits.** 40/40 throws aimed dead at an opposing Person's hurtbox centre
   resolved on the host — including **20/20 against a remotely-owned target**. Host-side resolution
   is not where this fails.

*What it actually is.* On any peer that joins after other clients, the engine rejects the
MultiplayerSynchronizer of every pre-existing client-owned character:

    The MultiplayerSynchronizer at path "/root/Main/Players/<id>/MultiplayerSynchronizer" is
    unable to process the pending spawn since it has no network ID.

and then discards its traffic for the rest of the match. Measured, one four-peer run:

| peer | joined | rejected synchronizers | discarded sync packets |
|---|---|---|---|
| 1 (host) | — | 0 | 0 |
| 2 | 1st | 0 | 0 |
| 3 | 2nd | 1 | 12,760 |
| 4 | 3rd | 2 | 25,225 |

**The rejected count is exactly (characters already present) − 1** — every pre-existing character
except the host's own, which is the only one whose authority was never changed from the default.
That arithmetic is what identifies the cause as the authority assignment rather than anything else.

*What the player sees.* The affected peer's copy of that opponent keeps a stale transform —
measured up to **1.12 m** from where the host had them, against 0.56 m for a healthy one — and never
visibly reacts to a hit. The throw is resolved correctly by the host and the struck peer really is
downed; the peer watching just never learns. From that seat it reads as the slipper passing through
somebody. That is the report.

*Three fixes tried. Do not repeat these.*

 1. **Set the authority in `CharacterBase._enter_tree()`** (what the engine's own error message
    asks for, and the canonical Godot demo pattern). **No effect** — 12,698 / 25,070 discards.
    `_enter_tree` runs inside `add_child`, which is still inside the spawn window.
 2. **`set_multiplayer_authority.call_deferred()` from `_ready()`.** **No effect** — 12,731 /
    25,218.
 3. **Await two `process_frame`s, then assign.** ✅ **Discards 12,731 / 25,218 → 0 / 0.** But it
    ⚠️ **races `_rpc_reclaim_character` and cost the client its own character** — `net_spawn_probe`
    failed reproducibly with *"this peer owns no human character at all"*. Not landable as-is.
    Also tried: skipping the call when the value is already correct, which is safe but does
    **nothing** (12,760 / 25,225) — so the cure is the delay, not the redundancy.

*Where to look next.* **`_rpc_reclaim_character` is the real suspect, not `_build_networked_character`.**
The host pre-fills all four slots with AI placeholders at authority 1, so the spawn function's
assignment is usually a no-op; the assignment that actually hands a slot to a human happens in
`_rpc_reclaim_character`, on a node that is **already in the tree with a live synchronizer**, and
that same function **renames the node** (`character.name = str(new_peer_id)`) — which
MultiplayerSpawner and MultiplayerSynchronizer both address by PATH. A peer that joins afterwards
never receives that RPC. Either half is sufficient to break replication for that character, and
neither has been tested in isolation yet.

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

> ⚠️ **Superseded by B-121.** This change is correct hygiene and is kept, but measurement afterwards showed the stacking it describes **does not occur in play** (peak concurrency is 4 voices on 0.1% of frames). It was not the cause of the buzz.
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

**B-120 · A follow-up report ("still very loud during actual play") after B-119 pointed at a second,

> ⚠️ **Superseded by B-121.** The Master limiter is kept as a backstop, but it could not have fixed the report: the clipping was on the **SFX bus, upstream of Master**, and a limiter cannot undo distortion already in the signal reaching it.
unrelated cause: nothing on the Master bus stops the mix from clipping. [FIXED 2026-07-29, UNTESTED
AGAINST A REAL BUILD]**

`default_bus_layout.tres` has three buses, all at 0 dB, no effects on any of them. `AudioManager`
gives itself 20 voices (`UI_VOICES` 8 + `WORLD_VOICES` 12) specifically so a busy 2v2 fight can have
several things ringing at once — the class doc's own sizing note says "four units, two of them being
hit, an ability firing and a slipper landing." Several individual SFX are already mixed close to full
scale (`generate_sfx.py`'s `soft_clip` drive runs as high as 1.9–2.2 for `ability_bagsak_bomb`). None
of that is wrong on its own — it's the summed total at Master with nothing capping it that clips.
B-119's fix stops one sound from stacking copies of *itself*; it does nothing about six *different*
sounds landing in the same window, which is the normal shape of actual combat rather than an edge
case.

Considered and rejected: turning down `_TRIM_DB` further, or capping `WORLD_VOICES` lower. Both
reduce how loud things can THEORETICALLY get, but neither stops a mix that happens to land several
full-scale sounds at once from clipping — they only make it rarer, and rarer-but-still-possible is
the wrong target for something a limiter solves outright.

*Fix.* `AudioManager._install_master_limiter()`, called from `_ready()` after the voice pools exist,
adds an `AudioEffectLimiter` to the Master bus in code (`ceiling_db = -0.3`, `threshold_db = 0.0`) —
Godot's own audio-effects docs call this "always recommended" on Master for exactly this reason. Done
in script rather than by hand-editing `default_bus_layout.tres`'s effect block: this session cannot
load the project in Godot to confirm a hand-authored resource entry parses, and a script-level
`AudioServer.add_bus_effect()` call is something a `--quit`-only parse check (smoke gate step 2)
would at least catch if the class name were wrong. `AudioEffectLimiter` (not the newer
`AudioEffectHardLimiter`) was used because its properties are documented and stable back to 3.0;
nobody here could check the replacement class's property names against a running 4.7 to be sure they
still applied.

⚠️ **This is genuinely unverified.** No Godot binary, no audio device, no way to confirm the limiter
engages, sounds different, or doesn't itself introduce an artifact under real playback. It is a
standard, low-risk fix (a limiter that never triggers is inaudible; it only acts when the mix would
otherwise clip), but "standard and low-risk" is not the same claim as "verified," and this entry
does not claim the latter. Run the smoke gate (`Concurrency_Protocol.md` §8, all six, plus the
seventh since this touches `AudioManager`) and play an actual 2v2 before marking this closed.


**B-121 · The gameplay buzz was digital clipping on the SFX bus. B-119 and B-120 were both wrong. (NEW, FIXED)**

User report after B-120 shipped: *"when game is happening, not in menu, there is a loud buzz or noise
that seems unnecessary."* B-119 and B-120 were each reasoned out from source without a Godot binary,
and **neither addressed the actual cause**. This entry supersedes both as the explanation; their
changes are kept because both are independently correct hygiene, but neither fixed the report.

*Measured, not reasoned.* Three new probes, all runnable:

| Probe | Question it answered | Result |
|---|---|---|
| `tools/audio_load_probe.gd` | Is any sound retriggering into a buzzsaw? | **No.** Peak concurrency **4 voices on 2 frames of 1800** (0.1%); nothing retriggers faster than 0.4/sec. B-119's stacking theory does not occur in play. |
| `tools/audio_mix_probe.gd` | Which bus is actually too loud? | **SFX bus peak +2.0 dBFS — over full scale.** Master read −1.4 dBFS at the same moment. |
| (same, Music bus) | Is the ambience the buzz? | **No.** Ambience sits **18 dB under SFX**. Ruled out. |

*Root cause, two parts.*

1. **`_TRIM_DB` boosted three sounds above full scale.** `generate_sfx.py` normalises every sound to
   peak 0.85; `_TRIM_DB` then added gain on top. `lata_impact` at **+1.5 dB is 0.85 × 1.189 = 1.010**
   — over full scale **on its own, before any summing**. It is also the most frequently played sound
   in combat, so the loudest, most important sound in the game clipped on every single hit. The
   comment next to it ("the single most important sound in the game") is exactly what motivated the
   boost, and boosting an already-normalised sample is what broke it.
2. **No headroom for summed voices.** Voices sum. Four concurrent is normal in a fight (measured
   above, and it is what the pool is sized for), and four sounds each peaking at 0.85 exceed 1.0
   together no matter how well-behaved each is alone.

*Why the Master limiter could not have fixed it.* It sits **downstream** of the SFX bus. By the time
the signal reaches Master it has already clipped, and no limiter can undo distortion — only prevent
it. That is also why a check watching Master alone reported a healthy mix throughout.

*Fix.* (a) Every `_TRIM_DB` value is now ≤ 0 — the table makes things quieter relative to a 0 dB
reference, never louder — and `_trim()` clamps positives as a backstop. (b) New `HEADROOM_DB = −7.0`,
applied to every voice inside `_trim()`. **Deliberately not bus volume:** `_apply_bus()` overwrites
the SFX bus volume from the player's slider every time it moves, so static headroom parked there
would be silently wiped the first time settings loaded. Mix headroom belongs with the mix; bus volume
belongs to the player. (c) An `AudioEffectLimiter` on **SFX** (ceiling −1.0 dB) as the safety net
under the headroom, on the bus that actually generates the overload.

*Verified by re-running the same probe on the same match.* **SFX peak +2.0 → −1.0 dBFS, Master
−1.4 → −3.2 dBFS, no bus clipping.** `tools/audio_probe.gd` still passes 25/25; smoke gate steps 2
and 3 clean. `audio_mix_probe.gd` now **fails on any bus exceeding full scale**, so this cannot
silently regress — and it watches every bus, not just Master, which is the specific blind spot that
let this through.

*Still open:* whether the mix is any good is a judgement call, not a measurement. Clipping is gone as a measurement; whether the mix is
now too quiet is a listening judgement. `HEADROOM_DB` is the one number to turn.

**B-122 · A recovery chime fired on every stagger for the rest of the round, after any knockdown. (NEW, FIXED)**

Second half of the same "unnecessary noise during gameplay" report as B-121, and a genuinely
separate bug — B-121 was clipping (a mix fault), this is a wrong trigger (a logic fault). Found
because B-121's fix measurably removed the clipping and the report persisted.

*Why the first probe missed it.* `audio_load_probe.gd` measured a real AI-driven match and reported
nothing wrong — but in that run **no unit ever entered DOWNED** (`lata_impact` fired once in 1800
frames). It measured the throw loop and never touched the stagger/knockdown/self-right path, which
is most of what a human generates in a fight. A probe that exercises only what the AI happens to do
is not a probe of the game.

*Cause.* `CharacterBase._on_state_changed_audio()`'s NORMAL branch decided "did this unit just get
back UP?" by testing `_downed_time_left > 0.0`. But `self_right()` clears `_downed_self_rightable`
and deliberately does **not** clear `_downed_time_left` — recovering early leaves the remainder of
the 2 s window sitting there, permanently nonzero for the rest of the round. So after any knockdown
that was recovered from, every subsequent `STAGGERED -> NORMAL` transition passed that guard and
fired a 450 ms metallic chime. Staggers are bumps, bumps happen constantly, and the chime has no
visible cause — which is what "a noise that seems unnecessary" describes.

*Measured, with `tools/audio_combat_probe.gd` (new).* It drives the transitions directly rather than
waiting for the AI to produce them:

| Phase | Before | After |
|---|---|---|
| three staggers, clean unit | no recovery sound | no recovery sound |
| knockdown + early self-right | `reset_channel_complete` x1 | `reset_channel_complete` x1 |
| three IDENTICAL staggers, after the knockdown | **`reset_channel_complete` x2** | **none** |

*Fix.* A dedicated `_audio_prev_state` field, recorded at the end of the audio handler, so the NORMAL
branch tests the actual transition (`DOWNED -> NORMAL`) instead of inferring it. Kept separate from
`state` itself: nothing in gameplay needs a previous-state field, and adding one to the real state
machine would be a second source of truth to get out of step with. `reset_for_new_round()` resets it
before its own `state_changed.emit()`, or a unit that ended a round DOWNED would chime at the start
of every following round.

*The general lesson, and it is the one worth keeping:* **a timer that outlives the state it describes
cannot stand in for that state.** The guard was written to avoid adding a field, and the field was
the correct answer.

**B-123 · The ambience beds were the buzz. Both CC0 field recordings replaced with generated ones. (NEW, FIXED)**

Third and final cause of the "unnecessary noise in gameplay" report, and the one the user isolated
exactly: *"constant steady static/wind sound, same sound the entire time. Ambience to 0 completely
removes it."* That single observation was worth more than every measurement taken before it.

*Why nothing caught this.* The two CC0 loops passed **every check that existed** — licence verified
on the source page, correct duration and format, `loop=true` pinned, and measured sitting a healthy
18 dB under the SFX bus. They were still unusable, because none of those checks measure what a sound
is LIKE. They are outdoor field recordings; the wind noise on the microphone IS the asset. There is
nothing underneath it to recover, and a real recording of a real street is broadband by nature —
which is exactly what "static" means to a listener.

*Fix.* `tools/audio/generate_ambience.py` (new) generates both beds, the same way `generate_sfx.py`
already generated every sound effect. The two `.ogg` files and their licence file are deleted.
**There is now no third-party audio in the build at all**, which collapses the Form 03 audio
disclosure to a single "own work" row.

Three rules encoded in the generator, each with an assertion behind it so this cannot recur quietly:

1. **No broadband noise.** Every noise source is hard low-passed and slowly modulated, so it reads as
   distance rather than hiss. The generator **fails the build** if more than 2% of a bed's energy
   lands above 4 kHz. Measured result: **0.0%** on both. This is the check that would have rejected
   the field recordings.
2. **Ambience is mostly silence plus events.** The beds sit very low; the character comes from sparse
   quiet events — tricycles and a distant dog for the eskinita, birds and space for the plaza.
3. **It must loop invisibly.** Every periodic component has a period dividing the loop length, plus an
   equal-power head/tail crossfade. Seam discontinuity asserted under 0.02; measured 0.0026 and 0.0020.

Levels: eskinita −30.8 dBFS, plaza −36.0 dBFS as files (the old eskinita was ~−18 dBFS before its
−12 dB node trim, i.e. **the new bed is about 12 dB quieter**).

*One trap worth recording.* Godot's WAV importer enum for `edit/loop_mode` is
**"Detect From WAV, Disabled, Forward, Ping-Pong, Backward"** — so **1 is DISABLED, and Forward is 2**.
Setting 1 looks exactly like enabling a loop and silently disables it. Caught by `audio_probe.gd`,
which reads `loop_mode` back off the imported resource; it would otherwise have shipped as "the
ambience stops after 30 seconds and never comes back".

*Still open:* not yet heard. The generator is the tuning surface — bed levels and event counts are
one constant each, and it is deterministic, so re-running changes only what you changed.
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
slipper in mid-air. **Still `[~]`-grade: see the remaining work below.**

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

## 4. Execution Queue — condensed 2026-07-30

**~1,200 lines of task prose were deleted; every item is still here with its status.** The T/F/A/M/U
numbering is historical and superseded twice over — `Roadmap.md` owns what comes next (R-19 … R-22)
and `Checklist.md` owns per-phase status with acceptance criteria. Three queues meant three places
to tick and two of them rotted. Full prose for any item is in `git log` before this commit.

`[x]` done · `[~]` partial, with what remains · `[ ]` not started.

| Item | St | Title | What remains (empty = done) |
|---|---|---|---|
| `T-1` | [~] | The tsinelas becomes a thrown, retrieved object | Landed, v4.0. carriable.gd (LOOSE / CARRIED / FLYING, host-authoritative), carrier.gd (grab, charge, throw), throw_profile.gd + four .tres profiles. Carriable/Carrier/GrabArea added to CharacterBase.tscn. [~] not [x]: loads clean  |
| `T-2` | [~] | Grab ownership — an opponent's slipper is solid but not grabbable | Landed, v4.0, same commit. Enforced in exactly one place — Carriable.can_be_grabbed_by() — built on the existing CharacterBase.team (B-09). No second team system. Collision, hitboxes and the physics body are never touched on accou |
| `T-3` | [~] | B-46 lata reset channel | Landed v4.3, built where the plan said: carrier.gd runs the channel (_step_reset_channel, RESET_CHANNEL_TIME = 1.5s), carriable.gd owns the rule (can_be_reset_by) and the host-side apply (host_reset_upright), and the apply calls s |
| `T-4` | [x] | Retire the old fake throw |  |
| `F-1` | [~] | Set the base resolution and stretch mode, and reconcile the version st | Dev_Plan.md §4.7 and §7 both say to do this before building UI. It has never been done — project.godot has no [display] section at all. Every offset_ in MainMenu.tscn, HUD.tscn, MatchResult.tscn and YouCard.tscn was therefore auth |
| `F-2` | [~] | Land the display typeface | Read §0.5 first. Darumadrop One landed at v4.21 with an explicit human yes and its OFL licence. Steps 1, 2, 4, 5 and 7 are done; step 3 (a separate body/caption face) is still open and still needs a yes before any second binary en |
| `F-3` | [x] | A release export, so release-only bugs are testable |  |
| `F-4` | [x] | Reconcile `Dev_Plan.md` to the code |  |
| `A-1` | [~] | Enforce the camera rule structurally | The rule is currently obeyed by convention. Make it obeyed by construction, so no future pass can break it without the build telling them. Steps: 1. camera_rig.gd::_ready() already derives _mode from is_person with no export. Keep |
| `A-2` | [~] | Delete the scene-level camera | Closes B-58 and removes the last violation of Dev_Plan.md §2's architecture rule 4. The Camera3D in Main.tscn runs arena_camera.gd, caches four NodePaths to player nodes, and does midpoint/spread maths every frame for a camera tha |
| `A-3` | [~] | Fix B-67 — Local Match drives the wrong unit in a release build | Do not fix this by making main.gd or you_card.gd reference DebugPlayerSwitcher. That is protocol rule 11 and it is exactly the trap this bug sets: the tempting fix is to let gameplay ask the switcher who is driving, and that is fo |
| `A-4` | [~] | Fix B-68 and collapse `_reset_world()` | Two concerns, one function, genuinely inseparable — the refactor is what makes the fix land in both branches at once instead of only the networked one. Say so in the commit body. Steps: 1. Fix B-68 first, on its own, before touchi |
| `M-1` | [x] | The mesh generator toolchain |  |
| `M-2` | [x] | The Lata (can) — three states |  |
| `M-3` | [~] | The Tsinelas (slipper) | Current state: TsinelasVisual.tscn is a flat BoxMesh sole with two rotated box straps. It reads as a blue brick. The moodboard's THE SLIPPER card specifies in-hand ready (glowing icon), thrown trajectory (spinning, motion blur), r |
| `M-4` | [~] | Flat-shaded toon material pass | The moodboard and PEAK are both flat, high-saturation, minimal gradient. Godot's default StandardMaterial3D under one DirectionalLight3D gives soft PBR falloff — the opposite look. Doing this once at the material level is worth mo |
| `M-5` | [ ] | Persons — moodboard restyle, not a rebuild | Read the M- block header before starting. We keep the Kenney rig. The delta between what is on screen and the moodboard's character render is palette and accessories, not topology. Steps: 1. Palette retint. The two match Persons a |
| `M-6` | [ ] | The environment kit | Modular, generated per M-1, on a 2-unit grid so pieces snap and a MeshLibrary + GridMap can assemble a map instead of hand-placing two hundred nodes. Steps: 1. Eskinita (alley) set — the primary map, per GDD: road_tile · gutter_ti |
| `M-7` | [ ] | Build Eskinita as the first real map | This is the task that deletes the grey box. Sequence it after M-6 and before U-1 — the HUD has to be tuned against a real background, not a flat grey one, or every contrast decision gets made twice. Steps: 1. New scene scenes/maps |
| `M-8` | [ ] | The logo as a real asset | MainMenu.tscn renders the title as a text Label. The moodboard's logo is a finished lockup: TUMBANG over PRESO, hand-drawn marker unicase, with the O of PRESO replaced by a top-down can lid (dark ring, pull-tab). No font substitut |
| `U-1` | [~] | Rebuild the HUD to the moodboard | Dev_Plan.md §4.4 has the target layout. The current HUD.tscn is a centred VBoxContainer of five stacked labels plus the Q-5 YOU card — functional, and nothing like the spec. Steps, in this order (each is independently verifiable;  |
| `U-2` | [~] | Main menu and pause to the moodboard | The menu is already themed and has Play/Settings/Quit (Q-9). This is the blueprint-grid card chrome the moodboard's role cards specify, which nothing in the project reproduces yet. Steps: 1. The blueprint grid. The moodboard's car |
| `U-3` | [~] | The role-swap intermission card | Dev_Plan.md §4.6 specifies the beat and the timings. The functional half already exists — MatchManager.round_intermission_started, a 3s gap, an early _reset_world(), and hud.show_round_banner(). What is missing is the card. Do not |
| `U-4` | [~] | The lobby | Fixes B-13. _start_hosting() calls MatchManager.begin_next_round() immediately — the match starts before anyone has joined, which is why _sync_state_to_late_joiner (B-29) has to exist at all. A 2v2 game with no lobby cannot be dem |
| `U-8` | [x] | Sync the host's map and mode to joining clients |  |
| `U-5` | [~] | Character select | Six Prop specials have .tres resources (B-24) and no way to choose between them. main.gd hardcodes PROP_ABILITY = quick_stand.tres for every Prop, with a comment saying so. Steps: 1. scenes/ui/CharacterSelect.tscn, between the lob |
| `U-6` | [~] | In-world nameplates and ground rings | <!-- [DONE nameplate+ring @ v4.19; off-screen indicators deferred to U-6b] -- Dev_Plan.md §4.5. The HUD tells you who you are (the YOU card, done). The world does not tell you who anyone else is. This matters more in FPP than any  |
| `U-7` | [~] | Settings and match-result polish | <!-- [DONE @ v4.20] Settings panel + keybind viewer, Settings button in pause menu, MatchResult FoldCorner, Esc everywhere. lobby.gd Esc added inline at cherry-pick. -- The tail. Both screens work; both are the last two on bare-is |

## 5. Decisions the team owes

Only genuinely open questions live here. Anything answered has been moved out and written into the
document that acts on it, so this list shrinks instead of accumulating.

### Still open — a coding agent cannot resolve these

#### From the MAPS lane, 2026-07-30 (R-19 … R-33, R-20, R-21)

- [ ] ⚠️ **THE FLOW HEATMAP IS BUILT AND WORKING, AND WHAT IT MEASURES RIGHT NOW IS
      THE AI, NOT THE MAP. PAUSED ON THE HUMAN'S CALL 2026-07-30.**
      `tools/flow_probe.tscn heatmap map=<id> rounds=N scale=30` drives real
      AI-vs-AI rounds, samples every unit's XZ once per second of GAME time, blurs
      the counts into a density field and writes three images per map (combined,
      attackers, defence) with the confinement square and both throwing lines drawn
      over them for reference. 40 rounds is ~2 minutes per map.
      **The pictures come out as four or five tight blobs sitting on the spawn
      points, and the two maps are near-identical** — i.e. the bots are barely
      traversing at all, which matches the human's own note that "only defender has
      been winning". Neither map can be judged for flow until the AI moves, so the
      question is not "is the instrument right", it is "re-run it after BALANCE
      fixes the AI". **Nothing about map layout should be inferred from the current
      images.**
      ⚠️ **AND A BUG FOR BALANCE, FOUND BY THIS:** `Engine.time_scale` set once in
      `_ready()` does not survive the first dent, because
      `character_base.gd::_hitstop()` restores it to a HARDCODED `1.0` rather than
      to its previous value. `tools/ai_probe.gd`'s `scale=` argument has exactly
      this shape, so **every fairness number recorded with `scale=4` was actually
      measured at scale 1 after the first hit landed.** flow_probe reasserts the
      scale every physics frame; ai_probe is another lane's file and was not
      touched.

- [ ] **Eskinita's HOUSES are still American suburban, and that is the largest remaining
      cultural gap on either map.** The dressing is now specifically Filipino — GI-sheet lean-tos
      and fences, a wire tangle, banana/coconut/mango, sampay, a sari-sari store, a barangay
      basketball ring — but the *walls* are Kenney City Kit: clapboard siding and shingle gables.
      Three routes, and this is a human call because the cheap one may be good enough:
      **(a)** accept it — the dressing carries the read at match distance, cost zero;
      **(b)** re-skin the roofs to corrugated GI through the roof-atlas mechanism
      `env_toon_pass.gd` already uses for facade variety — about half a day, no instance cost,
      fixes the loudest half; **(c)** generate hollow-block houses in `env_kit.gd` — the only
      fully-correct answer and much the most expensive.
- [ ] **Late afternoon cannot be had by sun ANGLE in Eskinita, only by colour.** Measured, three
      times: the alley is 16 wide between houses 10–14 tall, so at 20° a house casts 27 m and the
      road never sees the sun; an axial sun shadows the corridor down its own length; and at 33° —
      6.6° below what ships — a 14 m house casts 21.6 m and no longer clears the street. **Six
      degrees is the entire margin.** A genuinely raking late-afternoon light needs a narrower
      alley or shorter houses, and the arena footprint is a standing human decision. Ship the
      amber-colour version, or change the footprint — not a lane call.
- [ ] **Is `puno_saging` (the banana clump) good enough?** It reads as broad tropical foliage at
      match distance; close up a Filipino may still find it agave-ish. Cheap to add leaves.
- [ ] **The confinement square's SIZE and SHAPE — see the two flow heatmaps.** R-21 produced the
      picture; the call is the human's. The recommendation, and what the picture is evidence for,
      is in the MAPS lane's report: the square is drawn from `CharacterBase.CONFINEMENT_RADIUS` by
      both builders, so changing the value costs the maps nothing. The **value sweep belongs to
      BALANCE**, not here.


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
  about whether the mix is any good**. Whether the mix is any good is the outstanding item, and it is a judgement call.

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

---

# APPENDIX — Bug ledger archive: DELETED 2026-07-30

B-01 … B-66 were all fixed and closed. ~840 lines of settled history removed; **open bugs
live in §3 of this file.** Where one of those entries explained *why* something is shaped
the way it is, that reasoning already lives as a comment in the file it constrains — which
is where it actually stops someone "fixing" it back. `git log` has the rest.
