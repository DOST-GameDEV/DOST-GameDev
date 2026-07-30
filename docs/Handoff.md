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

<sub>Keep this in step when you add a `##` section.</sub>

- [0. Session log — where the project stands right now](#0-session-log-where-the-project-stands-right-now)
- [1. System Context](#1-system-context)
- [2. AI Execution Protocol](#2-ai-execution-protocol)
- [3. Bug & Issue Ledger](#3-bug-issue-ledger)
- [4. Execution Queue — task detail, acceptance criteria, and model routing](#4-execution-queue-task-detail-acceptance-criteria-and-model-routing)
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

## 0. Session log — where the project stands right now

> The dated session-log narratives moved to [`Handoff_Archive.md`](Handoff_Archive.md).
> What stays here is only what still CONSTRAINS work.

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

**B-143 · THE MID-GAME HUD WAS A DIFFERENT DESIGN LANGUAGE FROM THE GAME IT IS IN. [FIXED 2026-07-30 — first pass]**

Reported from play: the HUD and mid-game UI *"kinda doesnt look like our theme (menu and lobby), it looks
ugly and plain and confusing."* Three separate problems, and all three were real.

1. **OFF-THEME.** The front end ships wood and amber — `WOOD_DEEP` bodies, `WOOD_EDGE` edges, a 12px
   radius, a hard drop shadow, `CREAM` body text, `AMBER` values. The HUD was near-white `card_style`
   cards with a navy translucent timer. Two design languages on one screen, and the HUD is the one the
   player looks at for the whole match.
2. **PLAIN.** Flat fills, no shadow, one text weight, no hierarchy between the timer, the score and the
   role.
3. **CONFUSING**, and this half was a genuine defect, not taste:
   - **An unwon round pip was drawn at alpha 0.** `_fill_pips` painted the *filled* state and left the
     empty state fully transparent. On the old white card that was survivable; the scoreboard's empty
     state was invisible either way, so "best of 5, you have won none" looked like *no scoreboard*.
     ⚠️ **This is the readable half of the older "the indicator boxes remain empty" report** — that fix
     corrected the FILL colour and never touched the empty state. Now a dark `WOOD_DARK` well with a
     `WOOD_EDGE` rim: an empty slot has to be drawn to be seen.
   - **Team identity was one character buried mid-string** in `"A · OFFENSE"` at body size, so in
     practice **hue was doing the job the letter mark is supposed to do** — against the §4.2 rule that
     team is the letter and never the colour. The letter is now its own AMBER glyph at 48px on the
     card's outer edge, and the label beside it carries the role alone.

**Fix:** `hud.gd::_apply_wood_skin()` + `_style_team_card()`, built from **`UiTheme.wood_style()`** — the
same static call the menu's own `WoodSlot` variation uses, so the HUD cannot drift from the front end
again. Timer is the menu's *recessed* slot (`WOOD_DARK`, `sink = true`), which is the front end's existing
idiom for "a value being shown to you". `you_card.gd` moved to the same face. The ready-phase objective
plate is re-skinned per role in `_refresh_ready_objective` — authored INK in the scene, which was right
while the HUD was navy and became the one navy element on a wood screen the moment the skin landed.

⚠️ **IT IS PER-NODE OVERRIDES IN CODE, NOT THEME VARIATIONS, AND THAT IS A COMPROMISE.** The `Hud*`
variations live in `ui_theme.gd`, which is 🩴 **ART's file and not writable by the UX lane**. The tokens
are all still `UiTheme`'s, but the application is scattered across `hud.gd`/`you_card.gd` instead of being
one `_register_variations` block. 🩴 **FOR ART: promote these into `HudCard`/`OffenseCard`/`DefenseCard`
and delete the overrides.**

**Verified:** rendered both role states off the real `Main.tscn`
(`tools/ui/ready_objective_shot.tscn`) and looked at them; layout probe still **PASS, 44 assertions** at
16:9 and 21:9 — the cards widened 200→250 for the letter mark and `TopLeft`/`TopCentre`/`TopRight` are
still pairwise disjoint at both aspects.

**Second pass, same day — three pieces of play feedback, all correct:**

- *"big negative space in the ingame hud"* — the team cards were a fixed 250px around a glyph and a
  seven-letter word, so the right third was empty wood. **Zero-width boxes now**
  (`offset_right == offset_left`): a Control's size is clamped **up** to its content minimum, which is
  the one place that rule helps rather than bites. `TopRight` grows leftward with `grow_horizontal = 0`.
  ⚠️ **That forced `clip_text` OFF the role labels** — `clip_text` makes a Label report a **zero**
  minimum width, correct inside a fixed card and fatal inside a hugging one, where it collapses the word
  to nothing. The two role strings are fixed constants, so they may size the card; **anything
  variable-length must give the card a floor back first.**
- *"in knock the lata down, the 2 and walk around freely, it kinda looks ugly with that hud/ui, can u js
  do text there but stylized"* — **the plates are gone.** The legibility problem they solved is real, so
  it is solved with a heavy **INK outline** on the glyphs instead: the same trick the screen-edge arrows
  use. CREAM for instruction, AMBER for alert, role colour for the objective.
- *"big negative space in … the tutorial"* — see 10.5.2/10.5.3; new
  `CharacterPreview.set_tile_framing()`.

**Third pass — the last two mid-game screens, with R-29 (see below):** `RoleSwapCard` and `MatchResult`
are now on the same wood face, including `MatchResult`'s two **buttons**, which had stayed on the
theme's default near-white `card_style` and read as dialog buttons pasted onto a wooden sign.
`MatchResult`'s unfilled pips were `UiTheme.CARD` — the same invisible-empty-state problem, now a dark
well.

**Still on this item:** the `Hud*` font-size ladder (six sizes of the same shout, per `ui_theme.gd`'s own
note) is untouched, and the overrides still want promoting into variations by 🩴 ART.

**B-141 · CHARACTER SELECT PUT THE FIGURE ON ONE FLAT NAVY FILL. [FIXED 2026-07-30]**

Reported from play: *"im not sure if theres a background for chara selection or its just blue."* It was
just blue. The backdrop node stack (`CharacterPreview` + `Scrim` + `ConfigPanel`) was all present, but
the preview `Environment` was `background_mode = 1` (**BG_COLOR**) filling `#161F35`, and an opaque
`SubViewport` means nothing placed behind it could ever have shown.

**Fix:** `SubViewport.transparent_bg = true` + `background_mode = 0`, then a `Backdrop` TextureRect
(vertical `GradientTexture2D`, PANEL-haze → INK floor) and a `BackdropGlow` (`FILL_RADIAL`, neutral
PANEL at ≤0.30 alpha) as the first two children of the root. Textures, **no shader**. The gradient runs
light-at-top so dark hair reads against the light end and pale shoes against the dark one; the tsinelas
tab benefits most — brown-on-navy was the worst pairing on the screen.

**Verified:** rendered and looked at, at both 16:9 and 21:9 — `ui_character_select{,_lata,_tsinelas}.png`.

⚠️ **AND AS THE OVERLAY, which is how a player actually reaches it.** `MatchSetup.tscn` instances this
scene as `%CharacterSelectPanel` over a **live 3D map render**, and the panel's opacity used to come from
that flat `BG_COLOR`. New probe `tools/ui/charselect_overlay_shot.tscn` opens the panel through its own
button and shoots all three tabs: the map does not show through. No existing probe covered this — they all
load `CharacterSelect.tscn` standalone, where there is nothing behind it to leak.

**B-142 · THE LAYOUT PROBE'S "SECOND RESOLUTION" RE-MEASURED THE FIRST ONE. [FIXED 2026-07-30]**

`ui_layout_probe.gd` printed a `########## 1280 x 720 ##########` banner and then `viewport 1920x1080`
with every rect identical to the 1080p pass, digit for digit. So "verified at a second resolution" — the
claim in `Checklist.md` 10.5.1 — **was not true**, and 42 of the 42 assertions were one resolution twice.

**Cause is not the resize.** `_apply_size()` works; `2560x1080` reports `viewport 2560x1080`. It is
`project.godot`'s `stretch/mode="canvas_items"` + `stretch/aspect="expand"`: under `expand` the content
rect follows the window's **aspect**, not its pixel count, and 1280x720 is the same 16:9 as the base — so
the content rect is *obliged* to stay 1920x1080. 720p was a second window size dressed as a second layout
case.

**Worth knowing before picking presets:** `expand` only ever **grows** the content rect — 1440x1080 (4:3)
lays out at `1920x1440`, taller, never narrower. No window can push a control off the **right** edge, and
**16:9 is permanently the tightest case vertically**, which is why R-09's 7px `BackButton` overflow only
ever appeared at 1080p.

**Fix:** second preset → `2560x1080` (21:9), where the content rect genuinely widens and anything
right-anchored or centred moves relative to the left-anchored panels — the drift the overlap assertion
exists for. Plus a **`SAME CONTENT RECT` assertion**: a pass whose content rect equals an earlier pass's
now **fails** instead of printing. **44 assertions pass** at 16:9 + 21:9.

**Verified in both directions** — the assertion was proven to fire, not just to pass: the explicit-size
argument now takes a comma list, and `-- "" 1920x1080,1280x720` reports
`** SAME CONTENT RECT **` and `FAIL — 1 of 44`.

**B-139 · THE AI HAD EIGHT DEFECTS THAT LOOKED LIKE BALANCE, AND THE HARNESS HAD A NINTH. [FIXED 2026-07-30 — `534fe36`, `d900209`]**

Kept as one entry because they share one cause: nine runs of the fairness log read the aggregate columns
and nobody instrumented the events underneath them. Full numbers in `Checklist.md` §Phase 9 RUNS 10–15;
this is the index so a future session can grep it.

 1. **The attacker threw from inside the defended area** — `_cond_attacker_out_of_range` only asked "am
    I too far". Fixed with a band, `[4.6, 6.0]`.
 2. **It walked into the taya's lap to fetch its slipper**, when its own tsinelas already crawls out to
    meet it. Now waits at the band's inner edge.
 3. ⚠️ **Its dodge was blind to the only defender that could hit it.** Threat detection required a
    defender *closing* at ≥ 0.35 m/s, and `_act_taya_tag` **releases movement in order to tag** — so at
    the instant a tag was coming the taya's velocity was ~0 and the attacker scored it harmless. Found
    with `bt_trace()` at the moment of contact: tagged in `approach` ×4, `settle` ×2, `fetch` ×1,
    `wait-out-the-guard` ×1 — never once defending itself. Now: arm's length is an emergency regardless.
 4. **The Can never moved.** `CAN_HOLD_RADIUS` 0.45 vs `ARRIVE_DISTANCE` 0.6 — the deadzone was wider
    than the circle it picked points in. Fixed with a 0.12 arrival distance.
 5. ⚠️ **Fixing 4 made the Can unhittable**, because `character_base.gd` NORMALISES an AI movement
    vector: a 0.22-unit shuffle was performed at the full 6.0 m/s, ~2 units of travel per flight. Fixed
    by shuffling at shuffling pace; evasion stays full speed.
 6. **The same normalisation broke the AI's lead** — it extrapolated instantaneous velocity. Smoothed.
 7. ⚠️ **The Guard was a free perfect third layer.** A hit is not a dent while Guard is up, and the can
    raised it in reaction to every throw: 23 throws, 19 blocked, **2 reached the can, 0 dents.** Now
    needs a reaction delay and cannot guard twice in a row.
 8. **The grab fired exactly one edge ever.** `_tap()` called every tick resets its own release
    countdown, so the key never came back up. Fixed with a grab interval.
 9. ⚠️ **`ai_probe`'s `scale=` was distorting the physics** — see B-140.

**B-140 · `Engine.time_scale` MAKES EACH PHYSICS STEP LONGER, NOT THE GAME FASTER. [FIXED in `ai_probe`, OPEN for `flow_probe`]**

At the default 60 ticks/second, `scale=N` makes one physics step cover N/60 s of game time — so at
`scale=16` a unit at `SPEED` 6.0 **teleports 1.6 units per step** and every distance-based decision is
made on a world that jumps a body-width at a time. Caught by an impossible number: the probe reported the
AI *asking* for an aim point 3.1 units from the can when the aiming code cannot offset more than 1.65.

**Fix:** raise `Engine.physics_ticks_per_second` in proportion to `time_scale` (`ai_probe.gd::_parse_args`).
**Validated:** scale 1 and 4 now agree (aim error 0.28 vs 0.34 units; block 82.6% vs 78.6%). **Scale 8
does not** — 480 ticks/s for four units exceeds real time on this machine. **Ceiling is 4.**

⚠️ **THIS IS NOT THE HITSTOP BUG, AND BOTH ARE REAL.** The MAPS lane's handoff reported that ai_probe's
`scale=` "has never worked past the first dent" because `_end_hitstop()` restores `time_scale` to a
hardcoded 1.0. That one was already fixed — `ai_probe.gd::_reassert_scale()` has been called every
physics frame since the fairness mode was written, and its own doc records the measurement that prompted
it. B-140 is a second, independent fault in the same argument.

🌏 **FOR THE MAPS LANE:** `tools/flow_probe.gd` copies the `_reassert_scale` line but **not** the tick-rate
fix, and its documented invocation is `scale=30` — i.e. **0.5 s per physics step, 3 units of travel per
step.** The blob-shaped heatmaps in `Handoff.md` §5 were measured under that. Re-run at `scale=4` before
concluding anything about flow from them; the AI-movement half of that entry is now fixed either way.

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


> **32 closed `[FIXED]` entries moved to [`Handoff_Archive.md`](Handoff_Archive.md).**
> Grep it by `B-` number if you need one. Only open items live here now.

---

## 5. Decisions the team owes

Only genuinely open questions live here. Anything answered has been moved out and written into the
document that acts on it, so this list shrinks instead of accumulating.

### Still open — a coding agent cannot resolve these

#### From the MAPS lane, 2026-07-30

- [ ] **Eskinita's HOUSES are still American suburban** — the dressing is specifically
      Filipino now (GI lean-tos and fences, wire tangle, sampay, sari-sari store,
      barangay basketball ring, children's chalk drawings incl. piko) but the walls are
      Kenney City Kit clapboard with shingle gables. Three routes: **(a)** accept, cost
      zero; **(b)** re-skin roofs to corrugated GI through the roof-atlas mechanism
      `env_toon_pass.gd` already uses — about half a day, no instance cost; **(c)**
      generate hollow-block houses in `env_kit.gd` — correct and expensive.
- [ ] **The TREES are not signed off on look.** Rejected three times. Placement is fixed
      (clumped, leaning, off the road, guarded against houses/fences); the limit is an
      ASSET gap — `kits/town/tree-high-round` is the only rounded canopy in the repo,
      measured by rendering all eight. Needs a sourced CC0 broadleaf/palm or a better
      generated one. The rejected generated species are still in `env_kit.gd`, uncalled.
- [ ] **Late afternoon cannot be had by sun ANGLE in Eskinita, only by colour.** Measured
      three times: the alley is 16 wide between houses 10–14 tall, so at 20° a house
      casts 27 m and the road never sees the sun; at 33° — 6.6° below what ships — a 14 m
      house casts 21.6 m and still does not clear. **Six degrees is the entire margin.**
      A raking light needs a narrower alley or shorter houses; the footprint is a
      standing human decision.
- [ ] ⚠️ **THE FLOW HEATMAP IS BUILT AND WORKING; WHAT IT MEASURES RIGHT NOW IS THE AI.**
      `tools/flow_probe.tscn heatmap map=<id> rounds=40 scale=30` drives real AI-vs-AI
      rounds and writes combined/attack/defence density images with the court drawn over
      them. The pictures are four or five blobs sitting on the spawns, near-identical
      between maps — the bots barely traverse. **Re-run after BALANCE fixes the AI;**
      infer nothing about map layout from the current images. The confinement square's
      size/shape call is the human's once that picture is real.
      ⚠️ **A bug for BALANCE:** `Engine.time_scale` set once in `_ready()` does not
      survive the first dent — `character_base.gd::_hitstop()` restores it to a hardcoded
      `1.0`. `tools/ai_probe.gd`'s `scale=` has exactly this shape, so **every fairness
      number recorded at `scale=4` was measured at scale 1.**


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
