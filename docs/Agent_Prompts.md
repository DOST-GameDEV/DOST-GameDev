# Agent Prompts — the board

**Branch `HANSDAKS-test`** (pushes go here; `HARRYDAKS` is the line it came off).
Four players, four 90-second rounds, one taya who rotates clockwise, cumulative
scoring. **The base game is built and playable.** The goal is a recordable
gameplay video.

> **RESTRUCTURED 2026-08-01.** 🧑: *"also clean up agent prompts · its so hard to
> naviagte · remove stuff there that i dont need to run or wont need to see"*.
> This file was 1 632 lines, more than half of it narrative LOG. What was cut:
> the session-by-session story of work already finished, the § REMOVED IN THE
> HARRYDAKS PIVOT table, the § FUTURE LANES duplicate of the lane prompts, and
> the long-form rubric. **Nothing actionable was deleted** — every open `[ ]`,
> every lane prompt and every trap that cost a session is still here, and the
> traps are now in one place (§6) instead of buried in prose.

## Contents

| § | What it is | Read it when |
|---|---|---|
| [1](#1--where-things-stand) | Where things stand | you are picking up the project |
| [2](#2--how-to-run-a-lane) | How to run a lane · **commit authorship** | every single time |
| [3](#3--order-and-ownership) | Lane order, and who owns which files | before you write anything |
| [4](#4--checklist) | **The checklist** — what is left | this is the working surface |
| [5](#5--the-lanes) | The five lane prompts, to paste verbatim | starting a lane |
| [6](#6--traps) | **Traps that each cost a session** | before you debug anything |
| [7](#7--log) | Log — one short entry per session | you want the reasoning |

---

## 1 · Where things stand

### What the board is scored against

**Screening (each 20%):** Completeness · Theme Relevance · Originality · Gameplay ·
Aesthetics and Creativity
**Final judging:** Gameplay 20 · **Esports Potential 20** · Graphics and Art 10 ·
**Music and Sound Design 10** · Creativity and Innovation 20 · Game Feedback 20
*(audience vote off the trailer and the demo)*

**Where the originality actually is:** a faithful digital tumbang preso, a Filipino
street game nobody else at this competition is adapting, with a role rotation that
makes every player play both sides. Theme Relevance and Originality come from
fidelity, not from invented verbs.

⚠️ **The old board's "do not improve the objects-are-players thesis" clause is
deleted and must not be restored.** That thesis — the lata and the tsinelas as
playable characters with eight abilities between them — is the thing this branch
removed, on human instruction, because it was *"too complicated and far from
tumbang preso"*. The mechanics side of that deletion is `Design.md` §12.

**Built and verified:** four players / four rounds / rotating taya; the scoring bus;
the lata and slipper as props; stamina, shove, the lunge tag, the throw gate;
the HUD, tutorial, lobby, result screen; spectator; netcode and late-join;
four cans and four slippers with per-skin meshes; both maps at the 6.5 box.

> ### 🧑 STANDING ORDER, 2026-08-01 (EVENING) — LANES NO LONGER GATE THE WORK
>
> Verbatim: *"do all fixes i ask u to even if not in ur lane"*, then *"do everything!
> fix everythinG!"*. So §3's one-writer-per-file table is now a record of who
> USUALLY owns a file, not a permission check: whoever the human hands a bug to
> fixes it wherever it lives.
>
> ⚠️ **THE RECORDING RULE SURVIVES AND MATTERS MORE, NOT LESS.** The table's real
> value was never the gate — it was that a change outside your row got written down,
> so the next lane could find it. Keep filing every out-of-row edit into the owning
> lane's §4 section and into §7. Without the gate, the record is the only thing left.
>
> ⚠️ **THE BRANCH IS `ESPORTS`, NOT `HANSDAKS-test`.** Every lane prompt in §5 and
> the first line of this file still say `HANSDAKS-test`; that is stale.
> `HANSDAKS-test`'s copy of this document is ~540 lines behind. Check out `ESPORTS`
> and re-read the board from there, and `git pull --rebase` often — it moved three
> times inside one session.

> ### 🧑 STANDING ORDER, 2026-08-01 — THE LAST TWO LANES ARE DEFERRED
>
> * **⚖️ `build fair` RUNS LAST, after everything else.** Verbatim: *"we will do
>   fairness last"*, and the reason given is a play observation rather than a
>   schedule preference — *"the game already feels fair, its js that the ai is so
>   horrible"*. So the numbers are not the thing in front of the player. **This
>   moves `build fair` from run 4 to run 6**; §3's table is updated to match.
> * **🔊 `build sound` RUNS WHENEVER THE AUDIO EXISTS** — *"do audio whenever its
>   available"*. It is not blocked on a lane, it is blocked on files. Its §4.7
>   (nobody has ever heard this game) does not close until they land.
> * Both are **deferrals, not cancellations.** §2.1 in particular now has its first
>   real measurement to work from — see §7's `build ai` entry and §2.25.

**The three things most likely to be wrong, in order:**

1. **`build fair` §2.1 — passive defence pays the taya 900 points a round
   uncontested against 100 for a knockdown.** Nobody has measured it. It is the
   single most likely balance error in the game.
2. **`build ai` §6 — the bots throw and miss, and score 0 knockdowns.** Measured:
   51 flights, 0 knockdowns over a 40 s match. The AI is a placeholder by
   construction; the human asked for it LAST.
3. **CC-BY credit is not on any screen** (§1.11). This is licence
   compliance, not polish.

**What to run to check the game still works** — all of these are one command:

| Probe | Gates |
|---|---|
| `tools/models/skin_probe.gd` (`-s`) | all 8 prop skins load, size and texture correctly |
| `tools/models/charprop_probe.tscn` | the CHARACTER screen previews each skin's own mesh |
| `tools/models/prop_probe.tscn` | floor clearance, slipper-in-hand, topples, throws, over a live match |
| `tools/models/lata_floor_probe.gd` | the can against the floor, 4 skins × 2 states |
| `tools/models/fpp_carry_probe.tscn` | the held slipper is visible and correct in FIRST PERSON |
| `tools/models/roster_spread_probe.tscn` | four seats wear four different Persons, and every viewer agrees |
| `tools/models/slipper_owner_probe.tscn` | every slipper is owned, ownership rotates with the taya, and non-owners are refused |
| `tools/audio/music_probe.tscn` | menu bed / round bed play in the right states and nowhere else |
| `tools/ui/solo_seat_probe.tscn` | the Single Player seat board actually stores a seat |
| `tools/ui/lobby_address_shot.tscn` | the host address is ranked correctly, legible and copyable |
| `tools/ui/net_twopeer_probe.tscn` | two real peers produce identical causal event streams |
| `tools/ui/bounds_sweep.tscn` | 9 screens × 5 aspect ratios, nothing off-screen |

⚠️ **Anything that renders needs the PLAIN exe** — `--headless` has no rendering
device and every capture comes back blank. `--headless` is still right for
`-s generate_all.gd` and for `--import`.

---

## 2 · How to run a lane

1. New chat. **Set the model and effort in the client before pasting.**
2. Paste that lane's block from §5 verbatim, first message, nothing else.
3. It finishes → it ticks its own boxes in §4 and appends to §7 **in the same
   commit as the work**.
4. **One lane at a time, in board order.**

> ### 🚨 COMMIT AUTHORSHIP — THE ONE RULE WITH NO EXCEPTIONS
>
> **Every commit is authored by `M4tyu633 <matthewtlabrador@gmail.com>` and nobody
> else.**
>
> * **NO `Co-Authored-By:` trailer. Ever.**
> * **No "Generated with", no 🤖 line, no tool attribution** anywhere.
> * The message says what changed and why. It does not say who or what wrote it.
> * Check yourself after committing — `git log -1 --format='%an <%ae>%n%b'` — and
>   fix it with `git commit --amend --reset-author` before you push if it is wrong.
>
> This is submitted as one person's work and the history has to read that way.

**Every lane, no exceptions:**

* ⚠️ **`git pull --rebase` before you start AND immediately before every commit.**
  Several lanes push to this branch and it moves under you.
* `docs/Design.md` is the balance source of truth. **Move a number in the code →
  move it there, same commit.**
* Read before you write. Never speculate about a file you have not opened.
* **You own your paths and only your paths** (§3). Reading anything is fine.
* **You decide HOW.** Every value here is a starting point you may overrule — say
  so in §7 with the reasoning.
* **Do not spawn subagents.**
* **Never claim a verification you did not perform.** `[x]` needs a named probe, a
  screenshot or a log. Everything else is `[~]`.

> ### ⚠️ THE REACHABILITY RULE
>
> **A feature a player cannot reach from the menus does not exist.** Whatever you
> build, wire it into the screen a player meets it on, in the same commit: mouse-
> operable, reachable by keyboard focus, and in the existing focus order. A debug
> flag is not an entry point. Render the screen and look at it.
>
> **AND ITS MIRROR: A CONTROL THAT IS REACHABLE AND DOES NOTHING IS WORSE THAN NO
> CONTROL.** This branch shipped a CHARACTER screen whose tabs picked values
> nothing read, and later one that previewed the same can for every lata skin. If
> you delete what a control drove, delete the control or give it something new.

> ### 📌 IF YOU FLAG IT, FILE IT
>
> A problem you only wrote about in §7 is a problem nobody will fix. Whenever you
> find something outside your paths, **add it as a numbered `- [ ]` item to that
> lane's §4 section**, under a bold line saying who filed it and when.
>
> * It goes to the lane that owns the FILE, per §3.
> * State what you observed, not what to type. Include the evidence — the measured
>   number, the probe name, the line.
> * You add the box; you never tick a box outside your own section.

---

## 3 · Order and ownership

**Presentation → Balance → Single Player.** A lane may not start until the one
above it has committed.

| Run | Lane | Model · effort | Owns | Rubric |
|---|---|---|---|---|
| — | 🎮 `build core` | — | the rules, the props, the loop | **CLOSED** |
| — | 👁️ `build spec` | — | spectator camera + POV | **CLOSED** |
| **1** | 🎨 `build model` | Opus 5 · medium | the lata, the tsinelas, the play area | Graphics · Aesthetics |
| **2** | 🔊 `build sound` | Sonnet 5 · medium | music, VO, SFX, the mix | Music and Sound Design |
| **3** | 🖥️ `build ui` | Sonnet 5 · high | `scripts/ui/**`, `scenes/ui/**`, the tutorial | Gameplay · Esports |
| **4** | 🤖 `build ai` | Opus 5 · high | `ai_controller.gd`, Single Player | Gameplay · Completeness |
| **5** | 🔊 `build sound` *(again)* | Sonnet 5 · medium | the mix, once the files exist | Music and Sound Design |
| **6** | ⚖️ `build fair` | Opus 5 · xhigh | every number, and the feedback that sells it | **Esports Potential** |

⚠️ **REORDERED 2026-08-01 ON HUMAN INSTRUCTION — see the standing order in §1.**
`build fair` was run 4 and is now run 6 (*"we will do fairness last"*), and
`build ai` moved up into its place because the human's own reading was that the
AI, not the balance, was what the game was failing on. `build ai` ran on
2026-08-01 and its §6 is closed; §8's ship list is closed except 8.4, which the
same human deferred explicitly.

⚠️ **`build ai` runs LAST on human instruction** — *"we will focus on making
multiplayer first then single player next time."* Do not promote it. It also
carries the three-item ship checklist (§8).

### Paths — one writer per file

| Lane | Writes |
|---|---|
| 🖥️ `build ui` | `scripts/ui/**` · `scenes/ui/**` · `systems/camera_rig.gd` · `trajectory_preview.gd` · `tools/ui/**` |
| ⚖️ `build fair` | **any number in any file** · `docs/Design.md` · `tools/*_probe.gd` · `character_base.gd` movement/contact · `slipper.gd` flight · `lata.gd` topple |
| 🔊 `build sound` | `systems/audio_manager.gd` · `assets/audio/**` · `default_bus_layout.tres` · the audio rows of `settings_panel.gd` · `docs/HUMAN.md` · `tools/audio/**` |
| 🎨 `build model` | `character_roster.gd` `CANS`/`SLIPPERS` · `scenes/objects/**` and `scenes/characters/visuals/**` · `assets/models/**` · `tools/models/**` · `tools/maps/**` · `docs/Art_Direction.md` |
| 🤖 `build ai` | `systems/ai_controller.gd` · `tools/ai_probe.gd` · `export_presets.cfg` · `.gitignore` |
| 🎬 `build pitch` | `docs/Pitch.md` **only** — writes the trailer, demo and summary; touches no code |

⚠️ **`main.gd` AND `character_visual.gd` HAVE NO OWNER** and have carried live
multiplayer bugs three separate times. Filed as §2.19 and still open.

⚠️ **`build sound` fires from files it does not own.** It exposes what it needs on
`AudioManager` and **files** the trigger onto the owning lane. A voice line with no
trigger is filed, not forced.

---

## 4 · Checklist

`[x]` = built **and verified**, and say by what. `[~]` = built, unverified, and say
what specifically. **Tick only your own section.**

> **HOW THE NUMBERS WORK — one prefix per lane, and it never changes.**
> `build ui` items are **1.x**, `build fair` **2.x**, `build sound` **4.x**,
> `build model` **5.x**, `build ai` **6.x**, the ship list **8.x**. So "§2.1" is
> always passive defence and "§5.2" is always the slipper, wherever it is quoted —
> and it is quoted from code comments all over this repo, which is why the prefixes
> are frozen even though 3 and 7 are gone (`build feel` merged into `build fair`;
> `build spec` closed).
>
> ⚠️ **These headings used to read "4.1", "4.2" … while holding items numbered
> "1.x", "2.x"** — two numbering systems on one line, which is what made this read
> as two checklists stapled together. Each heading now names its lane and states
> its prefix, and carries no section number of its own — so "§2" always means the
> top-level §2 above, and an item is always written with its dot ("2.1").

### 🖥️ `build ui` — screens and readability  ·  items **1.x**

- [x] 1.1 `HUD.tscn` restructured — every 2v2 node deleted, four authored
  `ScoreRow`s. *Verified: 1600×900 render over a live match.*
- [x] 1.2 Tutorial rewritten to the current game, ten pages. *Verified: all ten
  rendered at 1920×1080, and overflow MEASURED by `tutorial_shot.gd` — all `fits`.*
- [x] 1.3 Match-result screen — four authored `Place` rows; the draw is
  first-class. *Verified: both outcomes rendered off the real `Main.tscn`.*
- [x] 1.4 Role-swap card names players; the round-4 boundary is unreachable by
  construction. *Verified: rendered at all three real boundaries.*
- [x] 1.5 Lobby seats are `P1..P4` with the round-1 taya marked, reading real peer
  names. *Verified: rendered at 1920×1080 and 1920×1200.*
- [~] 1.6 The offscreen arrow points at YOUR OWN slipper. *Unverified: no capture
  shows it tracking a loose slipper mid-match.* ⚠️ **And see 1.14 — it cannot
  currently resolve "yours" at all.**
- [x] 1.7 FPP viewmodel arms scaled 0.72 and reseated. *Verified: before/after
  1600×900 renders.*
- [x] 1.8 **Two real peers, a full round, byte-identical 33-event streams.**
  *Verified: `tools/ui/net_twopeer_probe.tscn`, three runs.* Found and fixed
  `_try_late_join` throwing on every join, and remote characters frozen in `fall`.
- [x] 1.9 The player-name row is authored in `SettingsPanel.tscn`, so it sits in
  the keyboard focus order.
- [x] 1.10 The round label prints the taya's name, not `TAYA: P3`.

**Filed by 🎨 `build model` 2026-08-01:**

- [x] 1.11 ⚠️ **Three CC-BY models ship and their credit is not reachable from any
  screen.** CROCS, PANTULOG and IKE are CC-BY-4.0, whose one requirement is
  attribution: **fnk**, **The Withered Rose**, **les03**. Table and links in
  `Art_Direction.md` §4b; each `.glb` ships its own `*_LICENSE.txt`. A line in a
  design doc that never ships does not satisfy the licence — these belong on a
  credits screen or in the submission's asset list, beside the existing Kenney CC0
  credits. **Compliance item, not a nicety.** *Verified: new `CreditsPanel.tscn`
  (`credits_panel.gd`), reachable from a CREDITS button on `MainMenu.tscn`,
  quotes each model's own `*_LICENSE.txt` credit string verbatim. `tools/ui/
  credits_shot.gd` (new) drives the real button press, not a scene load in
  isolation, and rendered the result at 1920×1080.*
- [x] 1.12 **`net_twopeer_probe`'s `[FIN]` snapshot carries prop `skin_index` but
  NOT `character_index`.** Person skins are now dealt to bot seats host-side
  (§5.16) and replicated through the existing `_rpc_sync_picks` table, and
  a single-process run proves the playing and spectator cases agree
  (`roster_spread_probe`, identical `SIGNATURE` lines). **What is still unproven is
  two real peers.** Adding `character_index` to that probe's snapshot is ~2 lines
  and closes it; the probe is this lane's file. *Verified: added the field and ran
  two REAL peer processes (`--host` / `--join=127.0.0.1`) over a full round —
  `character_index=0,0,6,9` for P1..P4, byte-identical on both host and client
  FIN snapshots. ⚠️ The same run surfaced a real, unrelated networking bug —
  filed to `build fair` as §2.24, since it lives in files this lane does not own.*
**Filed by 🤖 `build ai` 2026-08-01:**

- [x] 1.17 ⚠️ **The CREDITS screen was missing the one third-party asset that is not
  CC0, and its AUDIO line had gone stale.** Fixed in `credits_panel.gd`
  **out of row, on direct human instruction** (🧑: *"add ccby i missed"*, *"add
  it to credits too in the game tbh"*). Two changes:
  * **TYPEFACE row added.** `Darumadrop One` is **SIL Open Font License 1.1**, not
    CC0. The OFL is satisfied by shipping the licence text — and
    `assets/ui/fonts/DarumadropOne_LICENSE.txt` does ship — so this was not a
    breach. But a screen that lists eight CC0 Kenney kits and omits the only
    licensed asset in the build reads as an oversight, because it was one. The
    three CC-BY-4.0 models were already correct and untouched.
  * **AUDIO line corrected.** It claimed *"all music and sound effects are
    original, synthesised in-house by this project's own tools"*, which stopped
    being true when the OST landed — 🧑: *"we made the OST tracks btw and will
    add our own sfx later"*. The tracks are **written by the team**, not emitted
    by `generate_sfx.py`. Still all ours; no longer all synthesised.

  *Verified: rendered through `MainMenu.tscn`'s own CREDITS button at 1600×900 and
  looked at — both rows on screen and legible.*
- [x] 1.18 **`tools/ui/credits_shot.gd` takes an optional scroll offset now**, added
  out of row for the same instruction. **The courtesy credits had never been
  photographed**: the panel is a fixed-size `ScrollContainer` so every capture this
  tool had ever produced stopped at the "EVERYTHING ELSE" heading, and a taller
  `--resolution` does not help because the panel does not grow with the window. A
  licence line added below that fold was unverifiable by the only tool that exists
  for it — which is precisely the *"the control is added to the tree is not the
  claim"* failure this probe's own header warns about. The argument is **additive**:
  omit it and the tool behaves exactly as before.
  `... tools/ui/credits_shot.tscn -- <out_dir> 420`
- [ ] 1.16 ⚠️ **The BOTS picker on `MatchSetup.tscn` describes a game that no longer
  exists, in measured-sounding numbers that were never true of this build.**
  `match_setup.gd::DIFFICULTIES[].detail` sells EASY as *"it blocks 29% of throws"*,
  NORMAL *"blocks about 38%"*, HARD *"blocks 62% of throws and rounds end fast"* —
  sourced, per the comment above the table, from `Checklist.md` §Phase 9 RUN 12/14,
  i.e. the deleted 2v2. Nothing in the current build measures "blocks % of throws"
  and the AI those runs measured was replaced today. **This is the reachable-control
  problem from the other side: the control works, and its explanation lies.**
  `scripts/ui/**` is yours, so here are the real numbers, measured over one
  complete 4-round match per tier (`tools/ai_probe.tscn`, mean physics step 0.0167 s)
  — paste or paraphrase, but the figures are honest:
  * **EASY** — hits the lata with **10%** of its throws, and throws the most of the
    three because it will not wait for a clear lane. Never leads a moving target,
    burns its whole stamina bar, and blunders roughly one plan in three.
  * **NORMAL** — **45%**. Reads your wind-up, waits about a second for a throwing
    lane to clear, leads what it chases, and keeps a quarter of its stamina back.
  * **HARD** — **59%**. Steps into slippers already in the air to body-block them,
    camps the loose slipper in its box waiting for the retrieval, and almost never
    makes a mistake.
- [ ] 1.13 **`colormap.png` UID mismatch still warns once per character per load.**
  The twelve rigs reference `uid://dpu4hdrq88up6`; `colormap.png.import` declares
  `uid://c0kd7i625gon4`, so Godot falls back to the text path and prints a WARNING
  for each. Harmless on screen, four lines of noise in every probe run and every
  session. In nobody's §3 row — the rigs are explicitly out of `build model`'s.
  *Investigated 2026-08-01 by 🖥️ `build ui`: still present, unchanged. The fix is
  one line (`colormap.png.import`'s `uid=`), but `assets/characters/persons/**`
  is nobody's §3 row and `build model`'s own lane prompt names `colormap.png`
  itself as explicitly off-limits — so this is left filed rather than
  unilaterally fixed outside every lane's paths. Give this file an owner (same
  ask as §2.19) before anyone patches it.*
- [x] 1.14 **`Slipper.owner_slot` was not set at spawn — FIXED by 🎨 `build model`
  2026-08-01, out of row, on direct human instruction** (*"fix the bug u found"*).
  Filed here first because this lane owns the two READERS; the fix landed in
  `slipper.gd` and `main.gd` instead. Full record in §5.20. **Your two
  features now have something to read**: the foot arrow (§1.6) and the owner glow
  (§1.15) can resolve "yours" from the first frame of a round, so both are worth
  re-checking on sight.
- [x] 1.15 **The fatigue pose and the slipper glow are wired and unseen.** The
  fatigue pose needs someone to sprint a 50-point bar to zero; the glow needs the
  local seat to be an ATTACKER. Both are now unblocked — see §1.14. *(This was
  numbered **2.20** until 2026-08-01, in `build fair`'s range, while sitting in
  this lane's section — it is 1.15 now. Any older reference to "§2.20" means this
  item.)* *Verified: new `tools/ui/fatigue_glow_shot.gd` seats the local player as
  an attacker, drives real `Input.action_press` (sprint+move, then a tap-throw) —
  not synthetic state — through a live `Main.tscn`. Fatigue: `is_fatigued()` true
  after 166 frames, `crouch` pose rendered with the HUD's `FATIGUED 2.0s` row
  showing. Glow: the owned slipper (`owner_slot == player_slot`) rendered LOOSE
  with the rim outline visibly lit, beside the un-lit lata.*

**Filed by 🔊 `build sound` 2026-08-01:**

- [ ] 1.19 **`hud.gd::show_countdown_tick` now calls `AudioManager.play_countdown(text)`
  instead of `AudioManager.play(...)` — one line, in your file, and you should know it
  moved.** The SFX behaviour is byte-for-byte what it was; the wrapper exists because
  `countdown_tick` is the same string for "3", "2" and "1" and the delivered VO has a
  separate recording for each, so the number has to come from the caller. `text` is the
  only place it exists. Nothing to do unless you change the countdown's SHAPE — if it
  ever counts from 5, `play_countdown` will ask for `count_5`, which is a real
  `docs/HUMAN.md` id with no take, and it will go quiet rather than say a wrong number.

**Filed by 🎬 `build pitch` 2026-08-01, found while fact-checking the submission copy
against the code:**

- [x] 1.21 ⚠️ **THE LEFT STATUS STACK WAS DRAWN ON TOP OF THE SCOREBOARD.** Reported
  by a teammate with a screenshot of `STUNNED 0.2s` and its red bar running straight
  through the P2 and P4 score rows: 🧑 *"put you are stunned somewhere else"*. Both
  are anchored `TOP_LEFT`, the board at (16, 28) and the stack at a hardcoded
  (38, **150**) — and 150 px is simply inside a panel that is a title plus four score
  rows. The constant was written when the stack was one centred column under the
  timer and was never re-checked when Handoff A split it into two corners.
  *Fixed: `hud.gd::_follow_scoreboard()` derives the stack's top from the panel's own
  `position.y + size.y`, re-applied on its `resized` signal, with `STATUS_MARGIN.y`
  kept as a floor. Derived rather than nudged to a bigger literal, which would be
  wrong again the next time a row is added or the font grows. **Verified: rendered
  at 1600×900 through a live `Main.tscn` with a real stagger on the local seat, and
  looked at — the STUNNED row now sits clear below the board.***
- [x] 1.22 ⚠️ **`YOU ARE VULNERABLE` SAT ACROSS THE MIDDLE OF THE SCREEN.** 🧑, with
  a first-person screenshot: *"You are vulnerable not in middle"*. The original
  instruction was *"directly below the crosshair"* and that is where it went, 34 px
  under centre — but in first person the thing you are looking at while that warning
  is live is the slipper you are bending down to pick up, so the one line meaning
  "you are about to lose 5 seconds" was drawn over the exact object it is about.
  *Fixed: `PRESET_CENTER_BOTTOM` at −104 px, which clears `ReadyPrompt`'s −158..−118
  band (hidden during a live round anyway) and stays outside the 64 px bottom safe
  band `YouCard.tscn`'s header documents.* ⚠️ **Unverified: not photographed.** It
  cannot share a frame with 1.21's capture — `is_taggable()` opens with
  `not can_act()`, so a stunned player is not vulnerable by construction — and the
  two-state capture tool was abandoned rather than finished. **Look at it once in
  play before filming anything.**
- [ ] 1.20 **`hud.gd`'s §2.7 comment block (line ~688) explains the HUD in terms of two
  functions that no longer exist.** It says the round *"is won by the lata being off its
  circle when the countdown expires"* and that the two numbers explaining the screen are
  `RoundManager.can_out_left()` and `can_out_stacks()`. Grep finds **no such functions**
  anywhere in `scripts/` — only this comment and one historical mention in
  `round_manager.gd`'s own header. Nothing is broken; it is a doc comment, and the code
  under it is fine. It is filed because it is the exact class of thing 🤖 `build ai`'s
  stale-documentation sweep was run for: a comment that confidently describes a deleted
  ruleset is a comment the next person implements against. There is no per-round winner
  and no out-of-circle countdown (`Design.md` §12).

### ⚖️ `build fair` — every number, and the feedback  ·  items **2.x**

- [x] 2.1 ⚠️⚠️ **SETTLED 2026-08-01: THE ARITHMETIC WAS RIGHT, THE CONCLUSION WAS
  WRONG, AND THE NUMBER DOES NOT MOVE.** The load-bearing word was *uncontested*,
  and that is not a state this game has. New `tools/fair_probe.tscn` builds the
  player the alarm predicts — a taya that guards from the shipping bot's own post
  and resets the can instantly but **never lunges** — and plays whole matches with
  it. *Verified: three policies, one complete 4-round match each, attackers at
  NORMAL, mean physics step 0.0167 s.*

  | taya | can upright | DEFENSE/round | of the 900 | DEFENSE share | TAG |
  |---|---|---|---|---|---|
  | `idle` (presses nothing) | **4.7%** | 38 | **4%** | 27.3% | 0 |
  | `turtle` (guards + resets, never lunges) | 86.2% | 733 | 81% | **47.8%** | 0 |
  | `bot` (plays) | 86.5% | 743 | 83% | 39.2% | 1700 |

  **A taya who does nothing collects 4% of the 900**, because the can spends 95% of
  the round lying down. The +10/s is the PRIZE for keeping it up, not income —
  measured spread 600–900 a round, which is a 33% swing of pure defensive skill.
  **And playing strictly dominates hiding**: `turtle` and `bot` bank the same
  passive total (2930 v 2970) because the tag stacks on top of defence rather than
  competing with it, so refusing to play forfeits 1700 points and gains nothing.
  Structurally capped too — everyone is taya once, and in the `turtle` run the seat
  with the HIGHEST passive share (P4, 68.4%) finished **last**. Full record in
  `Design.md` §8.1. ⚠️ **Still unmeasured: a real human**, but the degenerate
  strategy the arithmetic predicted is dominated, which is the half that mattered.
- [x] 2.2 ⚠️ **RAISED 6.5 -> 7.5 AND BOTH MAPS REBUILT**, on direct human instruction
  (🧑: *"can you pls make it bigger"*, *"pls just make our chalk lines longer ...
  also please edit the actual defender area"*), with the reason stated: *"the rsn we
  did bigger area is to make it harder for attackers"*. ⚠️ **8.0 was tried first and
  Eskinita rejected it** — the alley half-width IS 8.0, so the chalk landed on the
  walls and `can_throw()` would have left no legal ground on the east/west sides at
  all. **The throwing line is what has to fit, not the box.** *Verified: both builders
  re-run clean, chalk at ±7.5 and throwing lines at ±8.5 in both scenes, `court_shot`
  rendered from above on BOTH maps (it could only photograph one before — it takes a
  map argument now), and a whole 4-round `ai_probe` match PASSes at the new size.*
  ⚠️ **The measured cost is recorded in `Design.md` §2: throws 71 -> 17 and DEFENSE
  39% -> 73.8%.** That is the intended direction and a large step; `fair_probe` is the
  instrument that will say if it goes too far.
- [ ] 2.3 `SABOTAGE_WINDOW` 2.5 s is a guess. ⚠️ **Still unmeasured, and it is
  blocked on FREQUENCY rather than on effort** — 0 sabotages in every whole-match run
  taken on 2026-08-01 (`ai_probe` x 3 tiers, `fair_probe` x 3 policies). The window
  cannot be measured until the event happens; work it with 🤖 `build ai` §6.10,
  which is the same question from the other side. **What IS measured**: the shove's
  real price is 0.63 s of sprint (3.2 m of escape), not its 25 stamina — see 2.4.
- [x] 2.4 ⚠️ **MEASURED** (`tools/mech_probe.tscn`, rewritten this session; both
  sides pinned to neutral traits so the constant is not silently multiplied by a
  roster pick). Knockback **2.40 m** against a predicted 2.50; stamina **25.0 of 50.0**
  exactly; the cooldown allows at most 12 shoves a round. Stun reads **0.55 s**
  observed against the 1.25 const — the difference is the victim recovering while
  still sliding, so 1.25 is the stun and ~0.55 is how long they cannot act.
  ⚠️ **The finding: the real price is the SPRINT.** Half a stamina bar is 0.63 s of
  sprint = **3.2 m of escape distance**, out of the same pool that gets you back out
  of the box.
- [x] 2.5 ⚠️ **MEASURED** (`tools/mech_probe.tscn`): sprint to empty **1.25 s**,
  fatigue lockout **2.00 s**, empty -> full **2.97 s**. Every constant does exactly what
  `Design.md` §3 says. ⚠️⚠️ **The finding is the DISTANCE, not the time: one full
  sprint covers 6.84 m**, which was almost exactly one box half-width when it was
  measured (6.5). The stamina bar is dimensioned to **one crossing of the danger
  zone** — the retrieval the whole game is about — and nothing had written that down.
  It makes `STAMINA_MAX`, `STAMINA_DRAIN_RATE`, `SPRINT_SCALE` and
  `CONFINEMENT_RADIUS` one interlocked set: **move the box and you change what a
  sprint buys**, which is part of why 2.2 hit offence as hard as it did.
- [x] 2.6 ⚠️ **MEASURED AGAINST A MOVING TARGET AT LAST, AND THERE IS NO
  TUNNELLING.** The furthest start from which a lunge still tags is **3.20 m**
  stationary — the 2.5 m dash plus the 1.3 m sweep, minus the charge — **and 3.20 m
  against a target crossing at the full 3.45 m/s attacker walk. Identical.** The
  every-frame sweep does exactly what its comment claims, and §2.6's worry ("a moving
  body sampled at 60 Hz can step over a narrow band") is answered. **The tag is a LEAD
  problem, not a reach problem**: the taya has to aim it, and that is the counterplay.
  `tools/mech_probe.tscn` scans start distances 0.6-4.2 m in both conditions.
- [x] 2.7 ⚠️ **MEASURED, AND 5.0 s IS NOT THE HARSH NUMBER IT READS AS.** The stun
  is **5.6%** of a round; stun plus a full re-charge is **7.5 s = 8.3%** — about a
  twelfth of one round's throwing, against +100 for the taya. And the attacker keeps
  their slipper (§6's anti-camping rule), so there is no retrieval trip on top of it.
  Left at 5.0.
- [x] 2.8 ⚠️ **DECIDED: YES, ALL THREE TABS CARRY REAL STATS.** On direct human
  instruction (🧑: *"also make sure the stats actually apply u can also change the
  stats around for slippers, cans, characters, be creative with it, try to edit
  their descirptions too to match the stats"*). A prop is not a person, so the
  meters are re-read per tab — LATA: SPEED ÷ reset channel, POWER × the recoil it
  puts on a slipper, GRIT ÷ the hit window. TSINELAS: SPEED × launch speed, POWER ×
  the push a body-block deals the blocker, GRIT ÷ `THROW_LOCK_TIME`. Full table and
  reasoning in `Design.md` §9; all eight prop taglines rewritten so the sentence and
  the meters agree, and **two Person rows that were byte-identical** (KUYA BOY =
  BEBANG, MANG KANOR = ATE GIRLIE) are distinct. *Verified: new
  `tools/trait_probe.tscn` drives REAL call sites on a live `Main.tscn` — a real
  `host_throw` (16.045 v 17.766 m/s), a real pickup (`throw_lock_left` 1.33 v 1.08 s),
  a real body block (4.238 v 5.618 m/s), a real reset channel (1.67 v 1.36 s) and a
  slipper flown 0.536 m past the can that puts PASIP over and misses DECADES. PASS
  twice; **RED on the old code** — restoring `slipper.gd`'s `0.30` literal makes both
  cans answer identically and the probe exits 1.*
- [x] 2.9 ⚠️ **DECIDED: `max()` STAYS AND THE COST IS ACCEPTED.** It is the entire
  bound on a stun chain, and in a 1-vs-3 game an additive path lets three attackers
  hold one taya indefinitely. The specific invisible case (a 1.25 s shove inside the
  5 s tag) is invisible only in the HUD ROW — the shove still announces itself with
  knockback, a hit flash and `bump_swing`. The real fix is a status stack that draws
  two rows for one effect, which is `hud.gd` and therefore 🖥️ `build ui`'s row.
  Reasoning recorded in `Design.md` §11. ⚠️ **It also decided §2.11's shape**: the
  body block is knockback rather than a short stagger precisely because `max()`
  bounds one stun's DURATION without bounding how often the next one starts.
- [ ] 2.10 **Every probe in `tools/` root is stale** — `mech_probe`, `phys_probe`,
  `round_probe`, `hit_probe`, `abil_probe`, `ai_probe`, `scuff_probe`, `spec_probe`
  all assert deleted mechanics. Rewrite the two or three that earn it.
- [~] 2.11 ⚠️ **THE BLOCK NOW DOES SOMETHING TO THE BLOCKER.** It produced only a
  sound at a world position: no flash on the body that made it, no recoil, nothing
  at all on the blocker's own screen — a verb the player cannot tell they performed.
  The blocker now takes a **0.35 m push** along the slipper's line (`v = sqrt(0.35 ×
  60) = 4.583`, derived from `FRICTION` like `SHOVE_SPEED` and `LUNGE_SPEED`), plus
  a hit flash and, for the blocker only, a camera shake. Scaled by the thrower's
  tsinelas POWER and divided by the blocker's own person GRIT, so both stat tables
  are live in one contact. ⚠️ **A push and NOT a stun** — see 2.9. ⚠️ **No hitstop**:
  `_flash_hit()` writes `Engine.time_scale` globally, which is fine on a 7.5 s shove
  cooldown and wrong for something that can happen every few frames. *Verified: the
  push is measured live by `trait_probe` at 4.238 v 5.618 m/s across two slipper
  skins. **Unverified: what it looks like** — no capture shows the flash or the
  shake, and that is the half 2.22 also needs.*
- [ ] 2.12 The lata's topple is 88° over 0.22 s — judge it from spectator range.
- [ ] 2.13 A thrown slipper has no trail and no impact VFX.
- [ ] 2.14 The tag's wind-up, animation and contact moment. Decide with 2.6/2.7.
- [ ] 2.15 Confirm the shove wind-up is visible on a second peer — it is the only
  thing that makes it dodgeable, and therefore 2.4's numbers fair.
- [x] 2.16 ⚠️ **VERIFIED, AND THIS LANE PUT IT AT RISK THIS SESSION.** §2.8 made
  `LAUNCH_SPEED` per-skin, and the aim arc and the flight only ever agreed because
  BOTH come out of `Slipper.launch_velocity_for()` — scaling one and not the other
  would have re-opened this silently. `carrier.gd` passes the held slipper's own
  scale. *Verified per skin: miss **0.000 m** on TSINELAS, PANTULOG and IKE.*
  ⚠️ **CROCS misses by 0.263 m**, and the cause is not the arc: a crocs rests
  **0.161 m** off the ground against the others' 0.034-0.056, while `TrajectoryPreview`
  stops its line at a fixed `FLOOR_EPSILON`. The line is right; the tall skin stops
  higher. Filed to 🖥️ `build ui` as §1.19.
- [~] 2.17 ⚠️ **FIXED — the plain-miss branch has a caller now.** `slipper_land` was
  registered with its own mix level and had never been played: a throw that hit a
  body played `hit_body`, one that hit the can played `can_knockdown`, and one that
  simply missed — **38 of 71 flights in the baseline, by far the most common
  outcome** — landed in silence. It is a parameter on the landing RPC rather than a
  line inside `_apply_landed()`, because that function is shared with the round
  reset, which teleports three slippers home on one frame. *Unverified: by ear. No
  session has had an audio output device (§4.7), so this is proven as a call site
  and not as a sound.*
- [~] 2.18 ⚠️ **FIXED — `round_ended` is broadcast now.** Reliable and `call_local`,
  the same shape `_sync_lata_event()` and `_sync_tag()` already use, and it writes
  `round_active` itself so a client cannot emit "the round ended" while still
  believing it is live. It had zero subscribers, which is exactly why it was worth
  fixing rather than noting: it is the beat the round-end sting, the VO callout and
  the HUD's end-of-round state all hang off, and every one of them would have been
  silently host-only the moment somebody connected one. *Unverified: two real peers.
  `net_twopeer_probe` is the tool and it was not re-run this session.*
- [ ] 2.19 ⚠️ **`character_visual.gd` and `main.gd` have NO OWNER in §3**, and have
  now carried live bugs across three sessions. **Give both files an owner.**
- [ ] 2.21 **`CONFINEMENT_RADIUS` was moved to 6.5 by a map lane and needs your
  measurement.** It also invalidates 2.1's baseline.
- [~] 2.22 **A thrown slipper STOPS DEAD on contact and does not read as physics.**
  🧑: *"the slippers should bounce back a bit when it hits stuff"*. The lata recoil
  and the body-block deflection had both landed; this session added the third
  missing half — **the thing that was hit now reacts too** (2.11) — and made the can's
  recoil scale with its own POWER stat, so a heavy can throws the tsinelas 14%
  further than a light one. ⚠️ Contact still resolves HOST-SIDE ONLY, by distance,
  in all three places. *Unverified, and this is now the ONLY thing left on the item:
  **none of it has been seen in play**. It needs a capture, not more code.*
- [x] 2.23 ⚠️ **FIXED — the physical collider follows the mesh.** One cylinder at
  r 0.13, the mean of four cans, against measured radii **0.1075 / 0.1203 / 0.1250 /
  0.1400** — wrong for all four, worst on PASIP at **22.5 mm**.
  `lata.gd::_fit_collision_to_mesh()` measures it off the worn mesh's own AABB, in
  the same place the topple lift is already re-measured so the two cannot drift, and
  **also at `_ready()`** — the default mesh is PASIP, so the worst case was precisely
  the can nobody picked. Safe to write because `Lata.tscn` marks the shape
  `resource_local_to_scene`. ⚠️ **The SCORING window deliberately does NOT follow the
  mesh** — see `Design.md` §7.1 for that ruling. *Verified: `lata_floor_probe` PASSes
  all four skins upright and downed (+0.0000 / +0.0001), and its reported lifts are
  the per-skin radii the collider now uses.*

**Filed by 🔊 `build sound` 2026-08-01 (evening), measured while chasing *"AI still
doesnt TAG"*:**

- [ ] 2.30 ⚠⚠ **THE TAG HAS ALL BUT STOPPED HAPPENING, AND NOTHING BROKE — THE
  OFFENCE GETTING FIXED IS WHAT DID IT.** Measured, one whole 4-round match at
  NORMAL: **2 tags**, TAG worth **3.6%** of every point. §6.8's own table has TAG at
  **24.5%** at the same tier, and §6.2 claims 15-29 tags a match.
  **The cause is a rule, not the AI.** `CharacterBase.host_resolve_punch()` and the
  lunge sweep both open with *"a tag requires the can standing"* and return early.
  LATA DOWN has gone from **0% → 62-70%** of all points as the bots learned to
  convert, so the can is now over for most of the round and **the taya's only
  scoring verb is legal for the minority of it**. The better the attackers get, the
  less the taya is allowed to tag them — the two terms move against each other by
  construction. `_tag_target()` now carries the same condition so the bot stops
  swinging at people the rules will not let it touch, but **the balance question is
  yours**: either the tag survives a downed lata, or the taya needs a scoring verb
  that does, or DEFENSE is meant to carry that window (it measures 34%).

  ⚠⚠ **AND IT IS A REGRESSION WITH A BEFORE-AND-AFTER, NOT A STANDING CONDITION.**
  ⚖️ `build fair` measured this same term earlier the same day and wrote it into
  2.28: *"The tag pays 22.5% of all points at NORMAL (1700 of 7570) over 17 tags.
  It is not weak."* It was right when it was written. Re-run tonight on the same
  probe, `fair_probe -- policy=bot`, one whole match:

  | | ⚖️ `build fair`'s run | tonight |
  |---|---|---|
  | lata upright | **86%** of live time | **57.8%** |
  | tags | **17** | **1** |
  | TAG share | **22.5%** | **1.8%** |

  Nothing was done to the tag between those two runs. What landed in between was
  the offence getting stronger — the throw buff and the AI's wind-up hold — and the
  can therefore spending 28 points of live time more on its side. **2.28's own note
  says passive defence is paid per second of upright time and calls that "the
  term's driver"; the tag is paid per second of it too, and nobody wrote that down.**
  So the decision in front of you is not "is 100 points too much for a tag" —
  2.6/2.7/2.14 all assume the tag HAPPENS. It is whether the taya should have a
  scoring verb that survives a downed can at all.
  ✅ DEFENSE measures **34.0%**, comfortably inside `policy=turtle`'s ≤50% gate, so
  the catch-up term is NOT what is eating the round — the tag simply stopped paying.

  ✅ **ACTED ON 2026-08-01 (evening), ON A HUMAN RULING, AND IT MOVED.** 🧑:
  *"taya cant tag while can is down, to make it playable for defender, make the
  rebound/recoil of slippers weaker so that the attackers have to pick up the
  slippers inside the box and risk getting tagged"*. The tag rule is UNCHANGED —
  the fix is that a blocked slipper now lands **2.5 m** from the taya instead of
  **5.7 m**, so the retrieval happens inside the box where `is_taggable()` is true.
  `fair_probe -- policy=bot`, whole match, before → after:

  | | before | after |
  |---|---|---|
  | tags | 1 | **3-4** |
  | TAG share | 1.8% | **5.9-7.8%** |
  | lata upright | 57.8% | **62.5-64.4%** |
  | DEFENSE | 34.0% | **41.2-43.1%** |

  ⚠️ **STILL SHORT OF THE 22.5% ⚖️ `build fair` MEASURED, AND THE REST IS NOT THE
  BLOCK.** The offence is simply much stronger than it was then (the can was upright
  86% in that run against 62% now), so the tag window is still narrower than the one
  22.5% was measured in. Closing the rest means toning the OFFENCE down — a separate
  call, and yours. ⚠️ Watch DEFENSE: it has climbed to 41-43% against
  `policy=turtle`'s ≤50% gate, so it now has real headroom left but not much.

  ⚠️ **CONFIRMED AT HARD, WHERE THE BOTS ARE GOOD AND IT IS WORSE.** Whole match:
  hit rate **63.4%** (§6.8 baseline 58.5% — the offence is in fine shape), and the
  four attackers spent **33.9 / 33.7 / 38.9 / 52.4 s** each `is_taggable()`. That is
  **158 combined seconds of standing, uncontested vulnerability converted into 2
  tags.** No amount of AI work moves that number; the verb is switched off for most
  of the window it is needed in. LATA DOWN 69.9%, TAG 3.1%.

- [ ] 2.32 **SABOTAGE IS 0 FOR THE SAME REASON AND IS NOT AN INDEPENDENT ITEM.**
  Sabotage pays +50 only when the shoved rival is then TAGGED inside
  `SABOTAGE_WINDOW` — so a verb whose entire payoff is downstream of the tag cannot
  fire more often than the tag does. §6.10 left this *"unverified: that this is the
  right frequency rather than merely the honest one"*; it is now measurable that the
  frequency is not the shove's own gates at all. **Fix 2.30 and re-measure this
  before touching `SABOTAGE_WINDOW` (§2.3) — tuning it now would be tuning against a
  term that is zero for an unrelated reason.**
- [ ] 2.31 **The punch out-ranges the lunge's own tag radius, so inside 1.7 m the
  lunge is never the right button.** `PUNCH_RANGE` is **1.7 m** and instant;
  `LUNGE_TAG_RADIUS` is **1.3 m** behind a 0.5 s charge. The split the punch was
  added for is real (🧑: the lunge charge is *"exactly long enough for them to
  leave"*) — punch for adjacent, lunge to close 2.5 m — but as numbered, the punch
  strictly dominates everywhere the lunge could also tag. 🧑 asked the question
  directly: *"why even use punch at all"*, which is the same observation from the
  other side. Either number moves this; both are yours.

**Filed by 🤖 `build ai` 2026-08-01 — §2.1 finally has numbers. Read 2.25 FIRST.**

- [x] 2.25 ⚠️⚠️ **PASSIVE DEFENCE MEASURED AT LAST, AND THE 900-POINT ALARM IS
  CONDITIONAL ON THE OFFENCE BEING BROKEN.** §2.1 has been the board's number-one
  suspect on arithmetic alone (+10/s × 90 s = 900 against +100 a knockdown) and
  nobody had ever measured it, because until this session no attacker could score
  at all. `tools/ai_probe.tscn` now reports where every point in a whole 4-round
  match came from. Four runs, one complete match each, mean physics step verified
  at 0.0167 s:

  | run | DEFENSE | LATA DOWN | TAG | note |
  |---|---|---|---|---|
  | **AI with the old broken throw** | **76.6%** | 0.0% | 22.4% | 329 throws, **0** knockdowns |
  | EASY | 47.5% | 19.0% | 33.5% | |
  | NORMAL | 31.5% | 50.8% | 17.7% | |
  | HARD | 21.3% | 51.5% | 27.2% | |

  **Passive defence is 21–32% of all points against a competent offence, and 77%
  against none.** So the term is not dominant by construction — it is dominant
  exactly when the attackers cannot convert, and it degrades smoothly as they get
  better. That is arguably the right shape for a catch-up term. ⚠️ **Two things
  this does NOT settle**, and both are yours: this is bot-vs-bot, and a human taya
  who simply hides behind the lata may collect the uncontested 900 the arithmetic
  warns about; and the taya still wins on cumulative score in most runs. Re-measure
  against a human before moving the number, and note that lowering it now would be
  tuning against the AI's competence rather than against the rule.

  ⚠️ **CLOSED 2026-08-01 by ⚖️ `build fair`, and this filing was right about
  everything except which half was missing.** The half it asked for is now measured
  — `tools/fair_probe.tscn`, a taya that hides and never lunges — and the answer is
  that **the hiding taya collects the same passive total as the playing one and
  forfeits every tag**, so the strategy the arithmetic warned about is dominated
  rather than dominant. The genuinely new finding is the other end of the scale: a
  taya who does NOTHING collects **4%** of the 900, not most of it, because the can
  is only upright 4.7% of the round. See 2.1 for the table.
- [x] 2.26 ⚠️ **FIXED — and the prose stopped naming a number it does not own.**
  Five stale sites, not three: `lata.gd` ×2, `round_manager.gd`, `carrier.gd` ×2,
  plus `character_base.gd`'s controls comment, which was wrong on BOTH counts (it
  called the shove a 1.25 s hold — it has been a single tap since 2026-08-01 — and
  the channel 2.5 s). Every one now quotes `Lata.RESET_CHANNEL_TIME` by name.
  **The code was always self-consistent at 1.5; only the prose described a slower
  game.** ⚠️ The value itself then moved for a different reason: it is divided by
  the can's SPEED stat now (§2.8), 1.30 s on PASIP to 1.79 s on BOYBEN, and
  `carrier.gd` asks the lata rather than the const so the progress bar and the
  completion test cannot disagree. *Verified: grep — no remaining "2.5 s" in the
  project refers to the channel.*

  *As filed by 🤖 `build ai`:* `lata.gd` has `const RESET_CHANNEL_TIME: float = 1.5`;
  `Design.md` §6's table says **1.5 s**; `Design.md` §4's control table and §6's
  prose both say **hold E for 2.5 s**, and `carrier.gd::_step_reset_channel`'s own
  doc comment says *"runs the 2.5 s channel"* while calling
  `Lata.RESET_CHANNEL_TIME`. The CODE is 1.5 and is self-consistent; three pieces of
  prose describe a different game.
- [x] 2.27 **The AI is now a measuring instrument for anything in your list.**
  *Used exactly as described, and it held: `ai_probe` supplied the offence baseline
  (71 throws / 33 knockdowns / 46.5% at NORMAL) that 2.1's whole argument rests on,
  and `fair_probe` was written to its shape — same spectator path, same time-scale
  contract, same refusal to grade on a drifted step. ⚠️ **Two things it does NOT
  do**, both filed below: `matches>1` never completes (6.12), and it is the wrong
  instrument for anything about a HUMAN, which is why 2.1 needed a second probe
  rather than another sweep.* Original filing:
  `tools/ai_probe.tscn` plays whole matches with four bots and prints throws,
  knockdowns, hit rate, near misses, tags, sabotages, metres travelled, seconds
  spent taggable and the full point breakdown, with pass/fail gates and a non-zero
  exit. `AIController.DIFFICULTY_TIERS` is where the bots' own numbers live and is
  **`build ai`'s file, not yours** — but sweeping a GAME number (`SABOTAGE_WINDOW`,
  `TAG_STUN_TIME`, `CONFINEMENT_RADIUS`) and re-running the probe at a fixed tier
  is now a real experiment instead of a look. ⚠️ It refuses to grade if the physics
  step drifted, so `scale=` cannot quietly distort a result.

**Filed by ⚖️ `build fair` 2026-08-01 — two probes added, and what is still open.**

- [ ] 2.28 ⚠️ **THE SHOVE, STAMINA, THE TAG AND THE BOX ARE STILL UNMEASURED, AND
  ONE OF THEM IS BLOCKED ON FREQUENCY RATHER THAN ON EFFORT.** 2.3/2.4/2.5/2.6/2.7/
  2.14/2.15/2.21 were not reached this session. Recording what the runs DID show, so
  the next pass starts from evidence:
  * **Sabotage fires essentially never — 0 in every whole-match run taken today**,
    across `ai_probe` at three tiers and `fair_probe` at three policies. §2.3 asks
    for `SABOTAGE_WINDOW` to be measured and the event has to happen first, so that
    item is blocked on the shove's frequency, not on the window. 🤖 `build ai`'s
    §6.10 already argues the rarity is honest rather than a bug; **the two items are
    the same question and should be worked together.**
  * **The box (`CONFINEMENT_RADIUS` 6.5) held up in every run** — the can was upright
    **86%** of live time with a competent offence, and 4.7% with none, so it is
    neither uncrackable nor undefendable at this size. That is not a measurement of
    2.2/2.21, but it is a reason not to touch the number on a hunch.
  * **The tag pays 22.5% of all points at NORMAL** (1700 of 7570) over 17 tags. It is
    not weak. 2.6/2.7/2.14 should be worked as "does it FEEL earned", not as "is 100
    too much".
- [ ] 2.29 ⚠️ **`Engine.time_scale` HAS ONE OWNER AND FOUR WRITERS.** Fixing the
  hitstop leak (see §7) left the underlying shape intact: `character_base.gd`
  dips it globally for feedback, and `ai_probe` / `fair_probe` / `flow_probe` each
  set it for pacing. They compose only because the hitstop saves and restores
  whatever it found. **That is one static variable away from being wrong again**, and
  the failure mode is silent — a 120× slowdown that reads as a hang. Worth a single
  owner (a small autoload that arbitrates) before somebody adds a fifth writer.

**Filed by 🖥️ `build ui` 2026-08-01, found while verifying §1.12 on two real peers:**

- [ ] 2.24 ⚠️ **A held slipper's reparent onto a dynamically-built hand attachment
  races the round-reset RPC, and it is not rare.** `net_twopeer_probe.tscn --host`
  / `--join=127.0.0.1`, one clean round-1→round-2 transition:
  * **Client: 319 `ERROR: Node not found` / "Invalid packet received"** for paths
    like `Main/Players/-4/Visual/character-female-d2/.../HandAttachment/HandPoint/
    Slipper3` (and its `MultiplayerSynchronizer`). `character_visual.gd` builds
    `HandAttachment`/`HandPoint` at runtime, per peer (~line 1032), independently
    on host and client — so a slipper RPC referencing that path can arrive before
    the receiving peer has finished building its own copy of the hierarchy.
  * **Host: 3× `ERROR: Condition "!is_inside_tree()" is true`**, backtraced to
    `main.gd::_reset_slippers` (lines 1823, 1851, 1863) calling into
    `slipper.gd`'s `host_reset_for_new_round()`/`host_assign_owner()`/the
    `slipper.global_position = character.global_position` line — i.e. the slipper
    and/or the character it is being parked on is mid-reparent (still a child of
    the OLD round's `HandPoint`, not yet back under `_home_parent`) at the exact
    frame the new round's reset runs.
  * **Consequence, also measured**: the two peers' `[FIN]` snapshots disagree on
    which slippers exist at all — host reports only `Slipper2`/`Slipper3`
    (`Slipper1` silently absent from `get_nodes_in_group("slippers")` at
    snapshot time), client reports all three.
  Both call sites live in `main.gd` and `character_visual.gd`, which §2.19 already
  flags as ownerless — filed here rather than fixed blind, since untangling a
  reparent-vs-RPC ordering bug across two files this lane does not own is exactly
  the kind of fix that needs the number-owning lane's judgement on sequencing, not
  a patch from outside. Reproduce with:
  `Godot_..._console.exe --path <repo> tools/ui/net_twopeer_probe.tscn -- --host --secs=120 --out=<dir>/host_`
  then a few seconds later `... -- --join=127.0.0.1 --secs=120 --out=<dir>/client_`,
  and grep both stdout logs for `ERROR`.

**Filed by 🎬 `build pitch` 2026-08-01, found while fact-checking the submission copy
against the code:**

- [x] 2.34 ⚠️⚠️ **A JOINED CLIENT'S LUNGE HAD NO PATH TO THE HOST, SO ONLY THE HOST
  COULD TAG WITH IT.** Found 2026-08-02 while answering 🧑: *"make sure this fix
  works in multiplayer as well, can humans even tag ppl?"* — a fair question, and the
  answer was no for three players out of four.
  * `_step_lunge()` guarded its sweep with
    `if not is_networked() or is_host(): _sweep_lunge_tag()` and had **no `else`**.
    On a client that guard is false, so the sweep never ran there.
  * And it never ran on the HOST either, because `_physics_process` returns at its
    authority gate before `_step_lunge()` for a body this peer does not own (§6 trap
    7, the same shape a third time).
  * **The punch and the shove both already had `_rpc_request_punch` /
    `_rpc_request_shove`.** The lunge, added later, was simply missed — the identical
    omission to §6.13, one file over: a verb gains a second implementation site and
    the older machinery is not told.

  *Fixed: `_rpc_request_lunge` → `host_resolve_lunge()`, mirroring the punch's own
  contract ("the client says where it stood and which way it faced; the host decides
  who that reached"). The host cannot replay 27 frames of a body it does not
  simulate, so it tests the **dash path as one swept segment** — release point to
  `v²/(2·FRICTION)` along the facing, against `LUNGE_TAG_RADIUS` — which covers the
  same region the local per-frame sweep does and cannot tunnel, because a segment has
  no sampling rate.* ⚠️ **Unverified: two real peers.** `net_twopeer_probe` is the
  instrument and it was not re-run. The single-process path is unchanged and still
  measures (see §6.13). **This is the one item on this page that most needs a
  two-peer run before the demo.**
- [ ] 2.33 ⚠️⚠️ **`Design.md` §6 CONTRADICTS ITSELF ABOUT THE LUNGE, AND §2.6'S MEASURED
  REACH WAS TAKEN BEFORE THE NUMBER MOVED.** The const is
  `CharacterBase.LUNGE_SPEED = 7.746`, which is a **1.0 m** dash by the file's own
  `v²/60` solve, and its comment records the change explicitly: *"12.247 -> 7.746 on
  2026-08-01, on human instruction: a short 1-meter forward dash"*. `Design.md` §6's
  **table agrees** (`LUNGE_SPEED` 7.746 → a 1.0 m dash). But §6's **prose still says**
  *"released as a 2.5 m dash (`LUNGE_SPEED` 12.247, the same `v²/60` solve the shove
  uses)"*, which is the pre-change value and is now describing the SHOVE's number.
  * ⚠️ **The consequence is not cosmetic: §2.6's headline number is stale too.** It
    reports the furthest tagging start as **3.20 m** and derives it as *"the 2.5 m dash
    plus the 1.3 m sweep, minus the charge"*. That arithmetic only works at the old
    speed. At 1.0 m the same derivation gives roughly 2.3 m before the charge is
    subtracted, so **the measurement needs re-running on `mech_probe`**, and until it is,
    3.20 m must not be quoted (it is quoted in §2.6, in `Design.md` §6, and it was about
    to be quoted in the submission).
  * ⚠️ **This also changes §2.31's shape.** That item says the punch (1.7 m, instant)
    out-ranges the lunge's 1.3 m tag radius, so *"inside 1.7 m the lunge is never the
    right button"*. With the dash at 1.0 m rather than 2.5 m, the lunge's total reach is
    smaller than that item assumed when it was written, so the overlap it describes is
    **worse**, not better. Both numbers are yours; 2.31 should be re-read against the
    current value before either moves.
  *Evidence: `character_base.gd:319-339` read directly; `Design.md` §6 table against
  §6 prose; no probe re-run by this lane, which writes no code.*

### 🔊 `build sound` — music, voice and the mix  ·  items **4.x**

- [x] 4.1 **The OST is in and it has been listened to.** 🧑 2026-08-01: *"everyones
  listened to the audio, we've put the ost"*. The team wrote the tracks; the menu bed
  and the round bed both play from the scene-state model in 4.2. ⚠️ **The track list
  was TRIMMED** — the "five tracks" this item used to be counting against is not the
  plan any more, and only what the team kept will be uploaded. Do not treat a missing
  track as an outstanding delivery; ask what is still coming.
- [x] 4.2 **Menu bed and round bed are owned by a SCENE STATE, not by a list of
  events.** *Verified: `tools/audio/music_probe.tscn`, 8 checks over the real
  chain splash → menu → mode select → lobby → match → back, and the new
  free-roam check FAILS on the pre-fix code.* See §6.
- [x] 4.3 Round-end / match-win / round-lose register real streams. **Heard.**
- [x] 4.4 **THE VO IS IN — 11 takes across 8 ids, and every one of them plays.**
  🧑 2026-08-01: *"we js have to make it put in the VOs"*, *"i named them already the
  right way"* — and the ids WERE right, all eleven. Two things were not, and neither
  was the naming:
  * ⚠️ **The delivery was AAC-in-3GP carrying a `.wav` extension** — a phone
    recorder export. Godot has no AAC decoder, so `load()` returns null, `_load_vo()`
    skips it, and the folder looks full while every pool stays empty. Transcoded by
    the new `tools/audio/vo_import.py`, which SNIFFS the container and never trusts
    the suffix. **Second time on this project** — TABLE D's OST masters were MP3
    called `.wav`.
  * ⚠️ **`_vo_id_from_filename()` strips the LAST underscore segment**, so
    `clock_10.wav` copied in verbatim resolves to the id `clock`. Eight of eleven
    delivered names have that shape. The repo name is `vo_<id>_<take>.wav` and the
    importer writes it.
  Also trimmed (0.15–0.28 s of head silence — a countdown line a beat late is worse
  than none) and normalised to −6 dBFS (they arrived at −0.9 to **+0.2**).
  *Verified: `tools/audio/vo_probe.tscn` (new) — 11 files on disk, 11 streams pooled,
  every take 0.74–1.45 s, `play_countdown()` routes 3/2/1/GO! to `count_3`/`count_2`/
  `count_1`/`count_go`, and an unrecorded "5" degrades to silence. **Red proof: copy
  the delivered files in unchanged and it reports 11 on disk / 0 pooled, 17 FAIL,
  exit 1.***
  ⚠️ **Six ids stay wired and empty and that is correct** — `tumbang`, `taya`,
  `ayos`, `bilis`, `title`, `lata_restored`. `docs/HUMAN.md` now lists exactly what
  landed against what is still owed and asks which are cut vs pending. **`tumbang` is
  the one that matters** — the lata going over is the whole game and it is silent.
- [~] 4.5 Five of six previously-silent call sites now have a sound. The sixth is
  filed as 2.17.
- [x] 4.6 Ducking implemented inside `play()`. **Heard.**
- [x] 4.7 **BALANCED AGAINST A REAL MATCH WITH THE VOICE IN IT.** 🧑 2026-08-01:
  *"everyones listened to the audio"* — so this was never a first listen, it was the
  balance that could not happen until the thing sitting on top of the buses existed.
  It exists now (4.4), and `tools/audio/vo_mix_probe.tscn` (new, this lane's — the
  root `audio_mix_probe.gd` is ⚖️ `build fair`'s per §3 and never speaks) measures
  three windows under identical conditions: voice alone, match without voice, match
  with voice.

  | window | SFX RMS / peak | Music RMS / peak | Master RMS / peak |
  |---|---|---|---|
  | voice alone | −21.0 / −1.0 | −40.4 / −23.4 | −23.8 / −3.8 |
  | match, no voice | −19.9 / −3.1 | −25.4 / −6.6 | −22.1 / −4.5 |
  | match + voice | −22.0 / −4.9 | −23.0 / −6.1 | −23.2 / −4.7 |

  **Voice sits +2.1 dB peak / −1.1 dB RMS against the effects and +5.6 dB peak over
  the bed, and the full mix peaks at −4.7 dBFS** — above the action, under the
  impacts, nothing clipping.
  * ⚠️ **THE REAL FIX WAS THAT `play_vo()` HAD NO TRIM AT ALL.** `play()`/`play_at()`
    both subtract `HEADROOM_DB` (−7); `play_vo()` never did, because when it was
    written there was nothing to play and an unset `volume_db` is 0. Measured, that
    ships the voice **~7 dB over every sound effect in the game** while ducking the
    music 10 dB every time it speaks. New `VO_TRIM_DB`, and −4.0 is now a
    measurement rather than the guess it started as.
  * ⚠️ **`MUSIC_BASE_DB` IS UNCHANGED AT −6.0 AND THAT IS A RESULT, NOT AN
    OMISSION.** The bed measures 5.5 dB under the effects and 5.6 under the voice —
    it sits where a bed should. This item has said for two sessions that the probe
    "should move" the number; it was run, and the number was already right.
  * ⚠️ **Do not tune this on a short window.** The first run used 5 s phases and the
    two match windows disagreed by 7.3 dB on SFX RMS — not a mix difference, just
    two different slices of a round. The probe uses 14 s and says so.
- [x] 4.8 **Both beds start on the frame they are asked for.** 🧑: *"Remove the audio
  playback delay when transitioning from the intro video"* and *"Remove the audio
  latency during round initialization"*. The delay was never a timer — it was
  `MUSIC_CROSSFADE_TIME`, 1.5 s of ramp on a track starting from silence, at two
  edges where there is nothing to fade FROM. Both call sites pass a 0.0 fade now.
  *Fixed by ⚖️ `build fair`, out of row, on direct instruction.*

### 🎨 `build model` — the props, the play area  ·  items **5.x**

- [x] 5.1 **The play area is bigger** — `CONFINEMENT_RADIUS` 5.0 → **6.5**, both
  maps rebuilt, the throwing line derived at box + 1.0 = 7.5, and the chalk cut to
  a closed square plus one throwing line per side. *Verified: both builders'
  `surfaces.verify()`, plan-view renders.* ⚠️ The VALUE is `build fair`'s (2.21).
- [x] 5.2 **Four slippers**: TSINELAS (this project's own mesh) + CROCS, PANTULOG,
  SIKE (sourced CC-BY, converted by `build_footwear.py`). Origins on their volume
  centroid so the two-axis spin does not wobble.
- [x] 5.3 **Four cans** built from the human's drawings at their own measured
  height:diameter ratios, carrying their flattened label wraps as textures.
- [x] 5.4 Physics moved with the meshes, same commit, and the same numbers moved in
  `Design.md`.
- [x] 5.5 Tint-friendly — white means "do not tint" on both props.
- [~] 5.6 **Low poly, with two exceptions the human accepted.** Cans 400–900 tris,
  original tsinelas 276; crocs 3 532 and **sike 65 974**. 🧑: *"U dont have to
  compress ... its fine gang"*. **Unverified: frame cost on the recording machine.**
- [x] 5.7 `CANS`/`SLIPPERS` re-authored with a `model` key; the dead `ability` key
  dropped.
- [x] 5.8 `traits` carried across unchanged for `build fair` §2.8.
- [x] 5.9 Orphans swept — `lata_dent1..3`, `_apply_dents()`, the layered-strip wall.
- [x] 5.10 **The lata no longer clips the floor**, in either state, mid-animation
  included. *Verified twice: `lata_floor_probe.gd` and `prop_probe.tscn`.*
- [x] 5.11 **The carried slipper is re-parented onto the hand** — measured 0.0000 m
  over 1 800 samples, was 98 mm.
- [x] 5.12 **The bots throw again** (51 flights measured) and their safe spot
  projects onto the square rather than a circle.
- [x] 5.13 **The rejected drawing-derived slippers are DELETED.** 🧑: *"yo thats old
  stale stuff"*, *"delete the old stale models that design lane tried to make"*.
  `tsinelas_bakya.*`, `tsinelas_tsinelas.*`, four orphan textures, and the whole
  slipper half of `build_prop_textures.py` (which was a SECOND generator writing
  `build_footwear.py`'s output paths — see §6). *Verified: grep shows no remaining
  reference; clean `--import`.*
- [x] 5.14 **The four slippers and four cans genuinely reach both the game and the
  CHARACTER screen.** *Verified three ways: `skin_probe` 8/8 (loads, size, texture);
  the new `charprop_probe.tscn`, which drives the real CHARACTER screen and asserts
  the previewed `MeshInstance3D`'s mesh path equals the roster entry's — 8/8, plus a
  PNG each; and `prop_probe.tscn` over a live match.*
- [x] 5.15 **The held slipper is visible and correct in FIRST PERSON.** 🧑: *"slipper
  model can be seen but it doesnt get seen in first person"*. It was rendering the
  whole time at **0.171 m** — two nested viewmodel scales — and was hardcoded to
  `tsinelas_classic.obj` regardless of the pick. Now sized to 0.34 m and copied off
  the world slipper. *Verified: `fpp_carry_probe.tscn` reports visible / meshed /
  in-frustum with the size, plus before-and-after frames, and `slipper=sike` comes
  back `tsinelas_sike.obj`.*
- [x] 5.16 **Every AI seat gets its own Person.** Was `character_index = -1` →
  `PERSON_MODELS[team]` → every bot the same rig. Dealt host-side in
  `_refresh_ai_prop_picks()` (an empty stub until now) and carried by the existing
  `_rpc_sync_picks` table. *Verified: `roster_spread_probe.tscn` — four distinct
  `.glb`s, the human's own pick preserved, and the playing and spectator SIGNATURE
  lines byte-identical.* ⚠️ Two REAL peers still unproven — filed as 1.12.
- [x] 5.17 **Single Player no longer always starts you as taya.** *Measured before
  changing anything:* `solo_seat_probe.tscn` presses all four lobby rows and every
  one stores its seat; `fpp_carry_probe --seat=N` confirms 0..3 drive P1..P4 with
  only P1 defending. Nothing was broken — `GameLaunch.solo_seat` defaulted to **0**
  and `defender_slot_for(1)` is **0**, so the default seat was by construction the
  one that defends first. Default moved to 1. **The rotation is deliberately NOT
  re-based** — see the note on the constant.
- [x] 5.18 **The menu OST is hard-cut when a match starts.** Out of this lane's row,
  on direct human instruction (🧑: *"pls js abruptly cut it"*). See §4.2 and §6.
- [x] 5.19 **Generator ownership is documented and enforced** — `Art_Direction.md`
  §4 now carries the produced-by table, and `glb_tool.py` writes `newline="\n"` so
  the determinism contract can actually be tested on Windows. *Verified: run twice,
  `git status` clean.*
- [x] 5.20 **Every slipper knows whose it is, from the first frame of a round.**
  `owner_slot` had no writer but the grab and the throw, so a slipper nobody had
  touched carried `-1` — and `main.gd::_reset_slippers()`'s courtesy `host_grab()`
  at round start only *looked* like an assignment: it can silently refuse, because
  `can_be_grabbed_by()` needs `can_act()` = `round_active and state == NORMAL`, and
  a character mid-reset is neither. Ownership is now assigned explicitly by
  `Slipper.host_assign_owner()` (a replicated call, not a synchronised property —
  the glow's setter has to run on the peer that RECEIVES it), from seats walked in
  numeric order so every peer and every round agree. ⚠️ **The rotation was the half
  a one-round test would have missed**: the old gate
  (`owner_slot >= 0 and who.player_slot != owner_slot`) *refused* the new owner's
  pickup on round 2, because the slipper still held round 1's slot. *Verified:
  `tools/models/slipper_owner_probe.tscn` (new) checks round 1 AND the rotation into
  round 2, asserts the three owners are exactly the three attacker seats, and asks
  the game's own `can_be_grabbed_by()` whether a non-owner is refused — PASS, and
  it goes RED on the unfixed code (`Slipper1 owner_slot=-1`).*
- [x] 5.21 **"Only the PC that set up Hamachi can host" — and hosting was never
  broken.** `NetworkManager.host_game()` calls `create_server()`, which binds
  **every** interface, so every machine on the tunnel could always accept
  connections. What differed was the address the lobby PRINTED: it returned the
  first non-loopback IPv4 `IP.get_local_addresses()` happened to list, which is
  normally the real adapter (`192.168.x.x`) and is unreachable from across the
  VPN. `host_addresses()` now RANKS them — Hamachi's `25.x` first, then private
  LAN, with `169.254.x` (APIPA, never hostable; this machine reports three) thrown
  out — and offers all of them, because which network the other four people are on
  cannot be known from inside the process. ⚠️ **Nothing is hardcoded**: the list is
  read from the OS at lobby time. *Verified: `tools/ui/lobby_address_shot.tscn`
  (new) renders the HOST and JOIN lobbies and prints the ranked list.*
- [x] 5.22 **The host address is legible and copy-pasteable.** 🧑, with a
  screenshot reading `CONNECTING TO 25.…`: *"cant see ip also make it copy
  pastable rlly easy, make spectate button smaller so that whole ip can be seen,
  make ip smaller too"*. It was interpolated into `%SeatHeading`, which shares an
  HBox with SPECTATE and carries `OVERRUN_TRIM_ELLIPSIS` — so the longest kind of
  address this game shows was trimmed to four characters, and a `Label` cannot be
  selected anyway. It is a read-only `LineEdit` in its own row now (selection and
  Ctrl+C for free), font 20, with COPY and a cycle button when there is more than
  one adapter; SPECTATE went 286×62/27 → 176×46/19. *Verified: both lobbies
  rendered at 1600×900 and looked at — `25.114.207.183:8910` fits whole — and
  `bounds_sweep` still PASSes 9 screens × 5 aspect ratios.*

**Filed by ⚖️ `build fair` 2026-08-01:**

- [ ] 5.23 ⚠️ **`Lata.tscn`'s `Hurtbox` `Area3D` IS DEAD AND SHOULD BE DELETED.**
  Grep found no reader anywhere in the project. Slipper contact is a distance test
  against `Slipper.HIT_RADIUS + Lata.HIT_MARGIN`, resolved on the host, and
  reintroducing overlap-based contact is forbidden by the recorded `hit_probe`
  measurement (16 of 36 overlaps did not land). The node was authored to
  0.30 r / 0.70 h and `Design.md` §7 listed those as if they were the rule — so the
  balance source of truth described a shape the game never consulted, while the real
  number was a bare `0.30` typed into `slipper.gd`. That literal is now
  `Lata.HIT_MARGIN` (same value) and §7.1 records it. **What is left is the node
  itself**, plus the unused `@onready var _hurtbox` that points at it, which is
  commented as dead in `lata.gd`. `scenes/objects/**` is your row, which is the only
  reason this is filed rather than done. ⚠️ **`Body/CollisionShape3D` must STAY** —
  `lata.gd::_fit_collision_to_mesh()` writes it per skin (§2.23) and it relies on
  that shape keeping `resource_local_to_scene = true`.

**Filed by 🔊 `build sound` 2026-08-01, found while moving the sari-sari store on
direct human instruction:**

- [ ] 5.23 ⚠️ **`Placer.report()` truncates its skip list to the first FOUR names, and a
  landmark was missing from the shipped map because of it.** `mapkit.py:278` is
  `", ".join(self.skips[:4])`. Eskinita skips 14–16 pieces on every build, the first four
  are always the same trees, and `SariSari_W` sat past the cut — pinned at z 12.0 its
  footprint was blocked, `try_place` dropped it, and the map shipped with ONE sari-sari
  store while the builder's own loop reads as two and its comment calls the piece "the
  narrative centre of this map". That is precisely the *"a silent skip is how a map loses
  a landmark without anyone noticing"* failure `try_place`'s docstring is about, defeated
  by its own reporting. **The store is fixed** (build_eskinita.py asserts both now); the
  REPORT is not, and it is `mapkit.py`, which is your row. Printing all skips, or marking
  which ones were `ladder=False`, would have made this visible on any build.
- [ ] 5.24 **The tall `atip_yero` lean-tos sit at |x| 7.35 against a 7.0 box — 0.35 m
  outside the chalk, 2.34 m tall.** Not touched: 🧑 has twice said to keep them
  (*"i liked the tires and the tables and the yero walls"*) and they read as canopies on
  legs rather than as walls, which is why they survived the complaint the store did not.
  Recording it only because `CLUTTER_TALL`'s own header still says this tier lives at
  |x| > 6.5 "against the wall line", a clearance written when the box was 5.0. It is
  0.35 m now. Your call whether that is still what the header means.

### 🤖 `build ai` — Single Player *(RUNS LAST)*  ·  items **6.x**

**Every measurement below is `tools/ai_probe.tscn`, one whole 4-round match
(360 live seconds) at `scale=6`, mean physics step verified at 0.0167 s.**

- [x] 6.1 **Replaced, not tuned.** The placeholder is gone; `ai_controller.gd` is a
  three-layer controller (observe with tier-scaled lag → plan one enum on a think
  tick → act every frame) with thirteen plans, a shared read-only board for
  spacing, and a per-seat personality. *Verified: `ai_probe` PASSes every gate at
  all three tiers; the run at HEAD is in §7.*
- [x] 6.2 **Lookahead, dodging, the shove and body-blocking all exist and all
  measure.** Lookahead: `_lane_blocked()` walks the real launch velocity and asks
  the same question `Slipper._first_body_hit()` will. Body-block:
  `_intercept_point()` predicts a slipper already in the air and only commits to
  a point the taya can physically reach in time. Dodging: reads
  `observed_lunge_charge()`, the tell that is replicated for exactly that reason.
  Shove: the sabotage play, +50. *Verified: measured tags 15–29 per match and
  DEFENSE falling 47.5% → 21.3% from EASY to HARD as the offence gets better —
  the two sides scale against each other rather than one being inert.*
- [x] 6.3 **1-vs-3 measured, and the "obvious failure mode" was a rules bug rather
  than a coordination problem.** `_nearest_loose_slipper()` sent all three bots at
  whichever slipper was nearest — but a slipper has belonged to ONE attacker since
  2026-08-01 (`Design.md` §5.2) and `can_be_grabbed_by()` refuses everybody else,
  so two of the three were always standing on a prop pressing a button it would
  never answer. Each bot now fetches its OWN slipper, and the real three-body
  problem — one taya can only cover one bearing — is answered by `spacing`, which
  scores sixteen bearings against where the taya is and where its rivals have
  already committed. **Nobody cooperates**; reading the court is individually
  rational. *Verified over a whole match at NORMAL: throws 18/18/21/22 and
  knockdowns 9/11/11/12 across the four seats, seat score spread **0.23**.*
- [x] 6.4 **Intent harness kept, and narrowed.** Every decision still leaves through
  `ai_set_intent()`. It also now emits only the **eight headings a keyboard has**
  (`_drive()`, threshold sin 22.5°) — the bot has a human's movement vocabulary,
  not an analogue one, which is what makes a fairness number a comparison rather
  than a category error. *Verified: `grep` shows no write to `velocity` in the
  file.*
- [x] 6.5 **`tools/ai_probe.gd` rewritten** — 1 579 lines asserting a deleted 2v2
  down to a fairness harness that plays whole matches through the game's own
  spectator path. Its `_take_over_human_slot()` hack, flagged for removal since
  2026-07-30, is **gone**: `GameLaunch.spectator` is the shipping version of it.
- [x] 6.6 ⚠️ **FIXED: 0 knockdowns → 35–59 per 4-round match, and the cause was
  not aim.** Every throw was released at power ≈ 0.36 because the old plateau
  detector compared a `0.005` epsilon against the **0.0043** one 60 Hz frame
  actually adds — so it fired on the third frame of every wind-up, for ever.
  Power is a SPEED scale (`17.0 × lerp(0.35, 1, power)`), so 0.36 is 10.6 m/s,
  whose range is **5.6 m**, against a shortest legal throw of **6.5 m**. There was
  no launch angle; `_solve_arc()` fell back to "throw along the line and fall
  short", exactly as its own comment promises. `_min_power_for()` now inverts the
  range equation and the bot charges to a real margin over it.
  *Verified BOTH WAYS. Green: 79 throws / 43 knockdowns (54.4%) at NORMAL. **Red:
  re-shim the predecessor's 3-frame release into the new controller and the same
  probe reports `throws 329 knockdowns 0` and exits 1** — the §6.6 signature
  reproduced on demand.*
- [x] 6.7 **FIXED: 14.2 m → 171–250 m per round, every seat.** Two causes. Two of
  three attackers had nothing to do (6.3), and every plan that reached its goal
  called `_stop()` — including one that legally *cannot act*, an armed attacker
  waiting for a lata that is lying down. Measured on the first run of the new
  probe: two bots standing still for 22 s and 57 s, with the lata down for ~70 of
  180 live seconds. Arrival now loiters instead of freezing.
- [x] 6.8 **Three difficulty tiers that are three different opponents**, 17 knobs
  each, every one of them something the bot visibly does (§ DIFFICULTY in the
  file). *Measured, one whole match each:*

  | tier | throws | knockdowns | hit rate | tags | DEFENSE | LATA DOWN | TAG |
  |---|---|---|---|---|---|---|---|
  | EASY | 129 | 13 | **10.1%** | 23 | 47.5% | 19.0% | 33.5% |
  | NORMAL | 83 | 37 | **44.6%** | 21 | 32.4% | 43.1% | 24.5% |
  | HARD | 94 | 55 | **58.5%** | 29 | 21.3% | 51.5% | 27.2% |

  EASY throws the MOST and scores the least — it will not wait for a lane and it
  blunders — which is the shape a weak player actually has.
- [x] 6.9 **The bots stopped moving in lockstep.** 🧑: *"the ai is so horrible they
  all move at the same time"*. Three controllers built in one `for` loop shared one
  think interval started on one frame. Each bot now boots on a random think phase
  and carries a `_Personality` seeded **from its seat** — tempo, hands, nerve,
  hesitation and a favourite bearing — so the four differ from each other while two
  runs of the same match still give the same four characters.
- [~] 6.10 **Sabotage is wired, geometrically correct and measured RARE** — 0–1 per
  match. The shove sends the victim along `shover → victim`, so it only pays if it
  points at the taya; that filter is in. What makes it rare is real and not a bug:
  it needs a rival vulnerable inside the box, the taya within a few metres of them,
  the shover in a 1.6 m arc on the correct side, 25 of a 50-point stamina bar, and
  a 7.5 s cooldown up — while `spacing` is deliberately keeping the attackers
  apart. **Unverified: that this is the right frequency rather than merely the
  honest one.** Left for whoever owns `SABOTAGE_WINDOW` (§2.3).
**Fixed by 🎬 `build pitch` 2026-08-02, out of row on direct instruction, after a
teammate report that the taya never catches a human:**

- [x] 6.13 ⚠️⚠️ **THE TAYA'S PUNCH COULD NEVER FIRE. `_act()` WIPED THE BUTTON THE
  PLAN HAD JUST PRESSED, IN THE SAME FRAME.** 🧑: *"AI cant tag human for some
  reason? I thhink thats why u dont teleport like bots"*.

  The release sweep at the bottom of `_act()` read
  `if _plan != Plan.WINDUP: _press("special_ability", false)`. That was correct while
  WINDUP (the attacker's throw charge) was the only thing that pressed that action.
  **The punch was added on 2026-08-01 as the taya's second tag verb and presses the
  SAME action**, from `_step_lunge_intent()` under `Plan.HUNT` — so every frame ran
  `_do_hunt()` → tap `special_ability` true, and three lines later the sweep set it
  back to false, before `CharacterBase._step_punch()` ever read it.

  *Measured by new `tools/tag_probe.tscn`, holding one attacker taggable in front of
  the taya:*

  | | before | after |
  |---|---|---|
  | tags in 25 game-seconds | **1** | **6** |
  | `special_ability` held | **0.0%**, 0 edges | pressed, cooldown consumed |
  | punch off cooldown | **100%** (never used) | 74% |

  With the taya in `HUNT` for **81%** of those frames, inside `PUNCH_RANGE` for
  **80%** and facing the victim for **84%** the whole time. Every precondition the
  punch has was true and the button was never pressed. After the fix a tag lands
  every **5.0 s**, which is `TAG_STUN_TIME` exactly — the taya re-tags the instant
  the victim can act again.

  ⚠️ **THE FIX TESTS WHAT THE COMMENT ALREADY CLAIMED.** `_press()` records into a
  `_touched` dictionary that `_act()` clears before dispatching, so "buttons this
  plan did not touch" is now literally what is asked instead of a hand-maintained
  plan whitelist. The next verb to share an action is covered by construction.

  ⚠️ **THIS WAS NEVER HUMAN-SPECIFIC, AND THE REPORT'S OWN THEORY WAS THE USEFUL
  PART.** The taya could not punch *anybody*. It read as "only the human is safe"
  because the human is usually the one being chased while the bots are tagged by the
  human. Related: `main.gd:682` gives the human seat a **disabled** `AIController`,
  so `ai_controller != null` is true for humans too — anything that tries to tell a
  human from a bot by that field is wrong.

**Filed by ⚖️ `build fair` 2026-08-01, found while using `ai_probe` as an instrument:**

- [ ] 6.12 ⚠️⚠️ **`ai_probe matches=N` FOR N > 1 HAS NEVER COMPLETED. Match 2 never
  ends.** Reproduced four times, and it is not caused by anything in this session's
  changes — it reproduces identically at HEAD with a clean tree:
  `... tools/ai_probe.tscn -- matches=3 scale=6 tier=NORMAL` prints
  `[match 1] winner=... scores=[...]` and then nothing, for 15+ minutes, against a
  match-1 wall time of ~70 s. `matches=1` always finishes. **This matters because
  every number in §6.8's tier table is a one-match sample**, and the default is
  `matches=3` — so the documented invocation in this file's own header is the one
  that hangs.
  * ⚠️ **The wall-clock cap did not save it either.** `DEFAULT_WALL_CAP` is 900 s and
    `_grade()` should fire from `_physics_process`; it did not print inside 15 min,
    which suggests the second match is not stepping physics at all rather than
    stepping it slowly.
  * **One real cause was found and fixed** (in `character_base.gd`, ⚖️ `build fair`'s
    row — see §7): `_hitstop()` guarded two STATIC flags with a `SceneTreeTimer`
    bound to an INSTANCE method, so a hit landing on the last frame of a match —
    exactly when `_end_match()` frees `Main.tscn` — orphaned the restore and left
    `Engine.time_scale` at **0.05** against the probe's 6.0, a 120× slowdown that
    reads precisely like a hang. **That fix did not make `matches=3` complete**, so
    it was a real bug on the same path and not the whole story. The remaining
    suspect is the teardown/rebuild in `_end_match()` / `_start_match()` against
    `main.gd`'s own lifecycle, and `main.gd` is §2.19's ownerless file again.
- [~] 6.11 **Nothing here has been seen by a human on two real peers.** AI is
  host-only by construction (`main.gd::_attach_ai` under `is_host()`), so this
  should be structurally fine — but "should be" is not a measurement, and
  `net_twopeer_probe` has never been run with bots playing well enough to matter.

### 📦 Ship checklist — **not a lane**  ·  items **8.x**

Done by whoever runs `build ai`, at the end of that session.

- [x] 8.1 **`export_presets.cfg` audited, and the premise of this item was wrong —
  the real defect was 8.2.** Read end to end against the current tree: neither
  preset names a deleted class, scene or feature, so there was nothing "only true
  about code that has since been deleted" to remove. What WAS untrue: the Windows
  preset carried an empty `export_path` while the macOS one had a path, so the
  Windows preset could not be exported from the editor at all and the documented
  one-liner had to supply it. Set to `build/TumbangPreso.exe`, matching
  `tools/export.md`. *Recorded rather than silently reworded — an item that says
  "this file is wrong" and does not say how is an item the next person re-audits
  from scratch.*
- [x] 8.2 ⚠️ **FIXED, AND IT WAS REAL: the probes were shipping.**
  `export_filter="all_resources"` with an empty `exclude_filter` puts every
  resource in the project into the `.pck`, and nothing shipped references `tools/`
  or `docs/` (grepped), so 35 probe scenes, their scripts, the Python map builders
  and every design document were riding along in the build handed to judges.
  Both presets now carry
  `*/tools/*, */docs/*, */.worktrees/*, */__pycache__/*, *.md, *.py, *.blend, *.blend1, *.xcf`.
  *Verified by exporting the same clean tree twice and searching the two `.pck`s:
  **`ai_probe` appears 8 times before and 0 after**, `tools/` 0 after, and the pack
  drops 38 644 400 → 38 179 772 bytes. The "before" run is the red proof.*
- [~] 8.3 **The export itself is proven; the clean-CLONE half is not.** Both
  `--export-release "Windows Desktop"` runs above were done in a **fresh
  `git worktree` at `HEAD`** — a tree with no `.godot/` and no local edits, which
  is most of what a clean clone tests — and both produced a complete `.exe` +
  `.pck` with export templates `4.7.1.stable`. **Unverified: that the exported
  build RUNS**, and a real clone into another directory.
- [ ] 8.4 ⚠️ **The build in `build/` is older than the board says — both zips are
  from 2026-07-29 23:14, which predates the entire HARRYDAKS pivot**, not just the
  music fixes. Anyone playtesting from `TumbangPreso-win64.zip` is playing the 2v2
  game with playable props. **DELIBERATELY NOT REFRESHED THIS SESSION, on direct
  human instruction** — 🧑, during this session: *"dont do it yet"*, *"we will edit
  mroe stuff pa"*, *"odnt fix the .exe yet"*. The presets are now correct, so the
  refresh is the two commands in `tools/export.md` and nothing else; do it when the
  edits stop.

---

## 5 · The lanes

### 🎨 `build model`

```
You are `build model` on branch HANSDAKS-test of the Tumbang Preso repo. Model:
Opus 5, effort medium.

Read docs/Agent_Prompts.md end to end first, then docs/Design.md and
docs/Art_Direction.md. Obey § 2 HOW TO RUN A LANE and the COMMIT AUTHORSHIP rule
exactly. GIT FIRST: git pull --rebase and confirm you are level with the remote
before touching anything, and again immediately before every commit.

You own character_roster.gd's CANS / SLIPPERS tables, the visuals in
scenes/objects/** and scenes/characters/visuals/**, assets/models/**,
tools/models/**, tools/maps/** and docs/Art_Direction.md.

TWO THINGS ARE OUT OF SCOPE AND BOTH WERE TRIED AND REVERTED:
  * NO BLENDER. Not the app, not the MCP tools, not a .glb round trip. The repo
    has its own deterministic mesh pipeline and it is GDScript + Python.
  * DO NOT TOUCH THE CHARACTER RIGS. All twelve stay. Do not edit a .glb,
    colormap.png, the person_*.tres palettes or generate_person_palettes.py.
  * DO NOT REBUILD THE SLIPPERS FROM THE DRAWINGS. The drawing-derived ones were
    rejected four times and deleted; the four that ship are sourced models plus
    the project's own. Art_Direction.md 4a is the record.

Read § 6 TRAPS before you debug anything. The three that have each cost a session
are: two generators sharing an output path, raycasting per frame from a prop, and
believing a probe that only ever passes.

Verify by measuring a whole match, not by looking once. The probes are listed in
§ 1. prop_probe is stochastic — re-run before believing a failure.

Tick your own boxes in §5 and append to §7 in the same commit as the work.
```

### ⚖️ `build fair`

```
You are `build fair` on branch HANSDAKS-test of the Tumbang Preso repo. Model:
Opus 5, effort xhigh.

Read docs/Agent_Prompts.md end to end first, then docs/Design.md — which is the
balance source of truth and which you own. Obey § 2 and the COMMIT AUTHORSHIP
rule exactly. git pull --rebase before you start and before every commit.

You own every number in every file, Design.md, tools/*_probe.gd, the movement and
contact block of character_base.gd, slipper.gd's flight and lata.gd's topple. You
are the only lane allowed to move a shipped number, and every number you move
moves in Design.md in the same commit.

THIS LANE ABSORBED `build feel`. You own the FEEDBACK for the things you tune as
well as the values: you cannot decide whether the tag is worth 100 points without
also noticing what it looks like when it lands.

Start with §2.25, NOT §2.1 — they are the same subject and 2.25 is the evidence.
Passive defence pays the taya +10/s for 90 seconds (900 points) against +100 for a
knockdown, and until 2026-08-01 nobody had measured it because no attacker could
score at all. It is measured now: DEFENSE is **21-32% of every point** against a
competent offence and **77%** against a broken one. The alarming arithmetic is real
but conditional. Read 2.25's table before you touch the number, then go and get the
half it does not have — this is all bot-vs-bot, and a HUMAN taya who hides behind
the lata is the case the arithmetic actually warns about.

You have a real instrument now. `tools/ai_probe.tscn` (🤖 `build ai`'s file — read
it, do not edit it) plays whole 4-round matches with four bots and prints the full
point breakdown, throws, knockdowns, hit rate, near misses, tags, metres travelled
and seconds spent taggable, with gates and a non-zero exit. Sweep one of YOUR
numbers, hold `tier=` fixed, re-run, compare. It refuses to grade if the physics
step drifted, so a fast run cannot quietly lie to you.

⚠️ Do not tune a game number to compensate for how good the bots are. The AI is
three configurable tiers and its knobs are `AIController.DIFFICULTY_TIERS`, which is
not your file. If a number only looks wrong at HARD, it is probably not the number.

Then work the rest. Some are deliberately one decision made twice: 2.6/2.7/2.14
are all the tag; 2.4/2.15 are both the shove; 2.11/2.22 are both "a blocked
slipper just stops", from the feedback side and the physics side.

Contact resolves BY DISTANCE ON THE HOST, not through Area3D overlaps, in three
places: RoundManager._step_tag, Slipper._first_body_hit and Lata.is_in_ring. That
is deliberate and measured — do not reintroduce overlap-based contact.

Tick your own boxes in §2 and append to §7 in the same commit.
```

### 🖥️ `build ui`

```
You are `build ui` on branch HANSDAKS-test of the Tumbang Preso repo. Model:
Sonnet 5, effort high.

Read docs/Agent_Prompts.md end to end first, then docs/Design.md. Obey § 2, THE
REACHABILITY RULE and the COMMIT AUTHORSHIP rule exactly. git pull --rebase
before you start and before every commit.

You own scripts/ui/**, scenes/ui/**, systems/camera_rig.gd, trajectory_preview.gd
and tools/ui/**. You do not write character_base.gd.

Your open items are §1.11 to §1.15, and 1.11 is first because it is
LICENCE COMPLIANCE, not polish: three CC-BY models ship and their authors are
credited nowhere a player can reach. 1.14 is the one with real gameplay
consequence — two shipped features silently do nothing because a field is -1.

Render every screen you touch and look at it. "The control is added to the tree"
is not the claim. Use the PLAIN Godot exe for anything that renders; --headless
captures come back blank.

Tick your own boxes in §1 and append to §7 in the same commit.
```

### 🔊 `build sound`

```
You are `build sound` on branch HANSDAKS-test of the Tumbang Preso repo. Model:
Sonnet 5, effort medium.

Read docs/Agent_Prompts.md end to end first, then docs/Design.md and
docs/HUMAN.md. Obey § 2, THE REACHABILITY RULE and the COMMIT AUTHORSHIP rule
exactly. git pull --rebase before you start and before every commit.

You own systems/audio_manager.gd, assets/audio/**, default_bus_layout.tres, the
audio rows of ui/settings_panel.gd, docs/HUMAN.md and tools/audio/**.

THE OST IS IN AND THE TEAM HAS LISTENED TO IT. 2026-08-01: "everyones listened
to the audio, we've put the ost". So the old framing of this lane — "nobody has
ever heard this game" — is dead, and so is the five-track plan: "we trimmed a
lot of its plan but we will upload only what we kept". Do NOT treat a track
that is not there as an outstanding delivery. Ask what is still coming.

YOUR ONE REMAINING JOB IS THE VO (§4.4). The pooling is built and every pool
activates the moment a file lands; assets/audio/vo/ is simply empty. "we js
have to make it put in the VOs". Files go in assets/audio/** per the existing
layout — VO under assets/audio/vo/, named as the pooling already expects. Put
each file exactly where the code that plays it already looks; don't invent a
path, and ask if the call sites don't make it obvious.

⚠️ docs/HUMAN.md's script is a SUPERSET of what is coming. The list was cut
down. Treat the recorded set as the spec and the document as the wish list, and
FILE rather than force any line whose trigger does not exist.

AFTER THE VO, §4.7 IS A BALANCE PASS AND NOT A FIRST LISTEN. The three buses
cannot be set against each other until the thing that has to sit on top of them
exists. Play four rounds with voice in the mix and balance Master / SFX / Music.
tools/audio_mix_probe.gd is the probe that should move MUSIC_BASE_DB.

The music lifecycle was rewritten on 2026-08-01 and is now gated by
tools/audio/music_probe.tscn — read § 6 before changing it, because the obvious
"start the bed when we reach the menu" shape is what leaked the menu track into
the match.

VO is fully wired and completely silent: assets/audio/vo/ is empty and every pool
activates the moment a file lands. That is expected, not a defect.

YOU FIRE FROM FILES YOU DO NOT OWN. Expose what you need on AudioManager and FILE
the trigger onto the owning lane's § 4 section. A voice line with no trigger is
filed, not forced.

Tick your own boxes in §4 and append to §7 in the same commit.
```

### 🤖 `build ai`

```
You are `build ai` on branch HANSDAKS-test of the Tumbang Preso repo. Model:
Opus 5, effort high. You are the LAST lane on the board.

Read docs/Agent_Prompts.md end to end first, then docs/Design.md, then
scripts/systems/ai_controller.gd in full. Obey § 2 and the COMMIT AUTHORSHIP rule
exactly. git pull --rebase before you start and before every commit.

You own systems/ai_controller.gd and tools/ai_probe.gd. You also own
export_presets.cfg and .gitignore for one job: §8, the ship checklist, at the
END of your session.

The AI you are replacing is deliberately minimal — about 250 lines, written so
the game films rather than so it plays well. Its own header says do not tune it,
replace it.

THE NUMBER THAT DEFINES YOUR JOB: 51 slipper flights and 0 knockdowns over a
40-second match. The bots throw and miss. They also barely move — 14.2 m and
26.0 m over a 90 s round against a 3.45 m/s walk speed.

The hard problem is §6.3: one defender against three attackers is an
asymmetry nothing in this repo has ever measured, and three bots all chasing the
same slipper is the obvious failure mode.

KEEP THE INTENT HARNESS. Every decision goes out through
CharacterBase.ai_set_intent(), the same indirection a human's keyboard feeds. An
AI that writes velocity directly desyncs the moment it is not the authority for
the body it is writing to.

Measure fairness with a real probe over many rounds, not by watching one match.

Then do §8 and stop.

Tick your own boxes in §6 and append to §7 in the same commit.
```

---

### 🎬 `build pitch` — the trailer, the demo and the submission summary

```
You are `build pitch` on branch ESPORTS of the Tumbang Preso repo. Model: Opus 5,
effort high.

YOU WRITE WORDS AND SHOT LISTS, NOT CODE. You own docs/Pitch.md (create it) and
nothing else. Do not edit a .gd, a .tscn or a number. If you find a bug, FILE it
into the owning lane's §4 section per §2's "IF YOU FLAG IT, FILE IT".

READ, IN THIS ORDER, BEFORE WRITING A SINGLE LINE:
  1. docs/Agent_Prompts.md §1 — what the board is scored against. The rubric
     weights are the brief: Screening is Completeness / Theme Relevance /
     Originality / Gameplay / Aesthetics at 20% each; the final is Gameplay 20,
     ESPORTS POTENTIAL 20, Graphics 10, MUSIC AND SOUND 10, Creativity 20,
     Game Feedback 20, with an audience vote off the trailer and the demo.
  2. docs/Agent_Prompts.md §7, the LOG, end to end. This is the only honest record
     of what is actually built versus what was planned, and it is long because the
     plan changed twice. ⚠️ Several §4 items are `[~]` = built but UNVERIFIED.
  3. docs/Design.md — the rules, and the balance source of truth.
  4. docs/Art_Direction.md §4b and scripts/ui/credits_panel.gd — the licence
     position, because a submission asks about assets and three models are CC-BY.
  5. docs/HUMAN.md § TABLE D and § Paperwork — the music and voice provenance.

WHAT TO PRODUCE, in docs/Pitch.md:

  A. THE ONE-PARAGRAPH SUMMARY. What the game is, in the words a judge who has
     never seen it would need. Lead with the thing no other entry has.
  B. THE ORIGINALITY PARAGRAPH. §1 states it: a faithful digital tumbang preso, a
     Filipino street game nobody else at this competition is adapting, with a role
     rotation that makes every player play both sides. Theme Relevance and
     Originality come from FIDELITY, not from invented verbs. The team wrote the
     OST and recorded the Filipino voice-over themselves — that is original by
     construction, needs no licence, and is the single strongest provenance claim
     in the entry. Say what is team-made and what is sourced, precisely.
  C. THE TRAILER SCRIPT. 60-90 s, shot by shot, each shot naming: what is on
     screen, what the player is doing, which rubric line it is buying, and HOW TO
     CAPTURE IT (a real scene or probe from §1's table — tools/map_shot.tscn,
     tools/harrydaks_shot.tscn, tools/ai_probe.tscn, the maps, the CHARACTER
     screen). ⚠️ Anything that renders needs the PLAIN exe; `--headless` returns
     blank frames.
  D. THE DEMO SCRIPT. What to show live, in what order, with the failure modes
     called out — what to do if a bot does something odd on stage.
  E. THE ESPORTS PARAGRAPH. Worth 20 and it is the least self-evident: four
     players, no teams, cumulative scoring, everybody is taya exactly once so
     nobody is handed the easy seat, and the format is symmetric by construction
     (`defender_slot_for()` is a pure function of the round number).

⚠⚠ THE ONE RULE THAT MATTERS MORE THAN THE PROSE: DO NOT CLAIM ANYTHING THE
BOARD DOES NOT SUPPORT. This project has a documented habit of shipping confident
text about things that were never verified — §6 trap 3 is entirely about that, and
a `[~]` box means "built, nobody has checked". A trailer that shows something the
build does not do is the fastest way to lose Game Feedback and Completeness.
Before you write a claim, find the §4 item or the §7 measurement behind it. If
there is neither, either cut the claim or mark it **UNVERIFIED — confirm before
filming**. Prefer measured numbers, of which there are many: hit rates per tier,
the point breakdown, the two-peer byte-identical event streams.

⚠️ ASK THE HUMAN for: the team name and member list, the deadline, the submission
form's actual questions, and whether the trailer has a length limit. Do not invent
any of them.

Append a short entry to §7 when you finish.
```

## 6 · Traps

**Read this before you debug anything.** Every entry cost at least one session.

**1 · TWO GENERATORS MUST NEVER SHARE AN OUTPUT PATH.** `generate_all.gd` silently
overwrote the sourced slippers for hours because both wrote the same filenames.
Found again on 2026-08-01: `build_prop_textures.py` was still writing three of
`build_footwear.py`'s texture files, with `tsinelas_crocs.png` **and** `.jpg` both
on disk as the evidence. **Slippers come from `build_footwear.py` ONLY; cans and
the env kit from `generate_all.gd` ONLY; can textures from
`build_prop_textures.py` ONLY.** The full table is `Art_Direction.md` §4.

**2 · DO NOT RAYCAST PER FRAME FROM A PROP.** It hung the game outright. And any
downward ray from a slipper MUST exclude the players: a slipper leaves the hand
INSIDE its thrower's own capsule, so the ray reports the ground at head height and
every throw lands on the frame it is released — which looks exactly like "the bots
are frozen", and nothing about that symptom points at a raycast.

**3 · A PROBE THAT CANNOT FAIL IS WORSE THAN NO PROBE.** Four have been caught
green-and-wrong on this branch: `intermission_shot.gd` emitted a 2v2 signal every
listener rejected and wrote PNGs the whole time; `music_probe.gd`'s first version
printed "all checks PASS" for a run that never reached the menu, and its second
version passed while the bug was live because it skipped the state the bug was in.
**Prove a new check fails on the unfixed code** — `git stash` the fix, run it,
watch it go red. A capture tool that saves a file is not a capture tool that
captured anything.

**4 · VERIFY BY MEASURING A WHOLE MATCH, NOT BY LOOKING ONCE.** The lata's
mid-topple dip was 22 mm and only existed between the endpoints — a static
end-state check passed it; `prop_probe`, sampling every frame, caught it.
⚠️ `prop_probe` is stochastic: re-run before believing a failure on the topple or
throw items.

**5 · A SCREEN THAT RENDERS IS NOT A SCRIPT THAT LOADED.** A parse error in
`match_setup.gd` did not show up in `--headless --import` and the lobby still
rendered, because the seat buttons fall back to whatever the `.tscn` authored.

**6 · TWO PEERS COMPARED AT TWO DIFFERENT INSTANTS MEASURE SHUTDOWN SKEW.** The
first two-peer run reported a 280-point desync that was purely the host lingering
8 s past the client. Freeze the stream on a CAUSAL marker, never on the clock.

**7 · AUTHORITY GATES SILENTLY BREAK EVERYTHING DOWNSTREAM OF THEM.**
`character_base.gd::_physics_process` returns at its authority gate before
`move_and_slide()`, so on a non-authority peer `is_on_floor()` reads false forever
and `velocity` reads zero forever. Three of four characters on every screen were
frozen in the `fall` pose and it was invisible in Single Player.

**8 · A FILE WITH NO OWNER GETS NO WORK AND ACCUMULATES BUGS.** `main.gd` and
`character_visual.gd` are in nobody's §3 row and have carried live multiplayer
bugs three separate times. It is the same failure that produced a `Music` bus with
no music.

**9 · THE MENU BED IS OWNED BY A SCENE STATE, NOT BY AN EVENT LIST.** "Start the
bed when we reach MainMenu" answers where the music STARTS and says nothing about
where it must STOP — so the title track played over the arena for the whole
free-roam window before the countdown. `_scene_state()` returns splash / match /
menu and each gets its own rule; "menu" is deliberately everything that is neither
of the other two, so a screen nobody thought about is still covered.

**10 · A COPIED TRANSFORM HAS THREE INDEPENDENT WAYS TO BE WRONG.** The held
slipper was chased for several sessions as a float. Copying the hand's transform
once a frame reads it BEFORE the animation moves the bone (98 mm of lag standing
still), needs a fallback that put the slipper inside the carrier's skull, and is
wrong on every frame it misses. **Re-parent instead** — inherit through the scene
tree and it is exact on every frame, at any framerate. ⚠️ Re-parenting inherits
SCALE: the hand hangs off a `Skeleton3D` carrying the rig's 2.38, so divide it
back out, read off the parent's real basis rather than hard-coded.

**12 · A COURTESY CALL IS NOT AN ASSIGNMENT.** `Slipper.owner_slot` was supposed to
be set at round start, and the code that "set" it was `host_grab()` — a *pickup*,
gated on `can_act()`, which is false for a character that is still settling. So the
field was assigned only when the grab happened to land, the failure was
intermittent, and it read as `-1` at the one moment the player most needs to know
which slipper is theirs. ⚠️ **If a value must always hold, write it directly; do
not infer it from an action that has its own preconditions.** The tell was a field
whose own comment claimed it was assigned at spawn while grep showed two writers,
both of them state transitions.

**13 · A BODY ONLY TURNS ON A FRAME IT WALKS, SO ANYTHING AIMED ALONG `-basis.z`
CANNOT BE AIMED STANDING STILL.** `character_base.gd` calls `look_at()` inside the
`if direction:` branch of `_physics_process`. The lunge and the shove both fire
along the facing. So a controller that walks up to its target and then politely
stops has frozen its own aim at whatever heading the last step happened to end on —
and it can never correct, because correcting requires moving. Measured: a taya
standing 0.78 m from a vulnerable attacker for **42.9 s of a 90 s round**, charging
and firing lunges into empty air. **If it is aimed by the body, it is aimed by
walking.** The same shape bit the shove's 70° arc in the same session.

**14 · "NOT MOVING" AND "NOT TRYING TO MOVE" ARE DIFFERENT BUGS AND ONE METRIC
CANNOT SEE BOTH.** `move_and_slide()` writes the RESOLVED velocity back onto the
body, so a unit leaning on a prop or on another capsule reads exactly like a unit
pressing nothing at all. `ai_probe`'s first version gated on speed alone and failed
a good run for "P1 stood still 20.3 s" while P1 was walking into someone every one
of those frames. Ask the game's own `input_pressed()` alongside the speed: still +
no intent is a frozen brain, still + intent is a stuck body, and they need opposite
fixes. **Both are real** — the same split later caught a bot wedged for **64.4 s**
that the speed-only metric would have reported identically to a healthy one.

**15 · A RELEASE CONDITION MUST BE BOUNDED IN SECONDS BY A CLOCK YOU OWN.** The
predecessor AI released a charge when the power "stopped rising", comparing a 0.005
epsilon against the 0.0043 that one 60 Hz frame adds — permanently true, so every
throw fired on frame three at minimum power, and minimum power cannot reach the
lata from outside the box. Its author had already been bitten the other way (a
wind-up held for a whole round) and reached for a condition about a value another
file owns. **51 flights, 0 knockdowns** was the visible result and it read as bad
aim for two sessions. If a commitment must end, end it on your own timer.

**16 · A GLOBAL SET BY ONE OBJECT MUST NOT BE RESTORED BY THAT OBJECT.**
`CharacterBase._hitstop()` wrote `Engine.time_scale` — process-wide — and scheduled the
restore on a `SceneTreeTimer` connected to an **instance** method, while the "is a
hitstop running" flag was `static`. Free that instance inside the 60 ms window and the
connection dies with it: the engine stays at **0.05** for the rest of the process, and
the static flag stays true, which also silently disables every future hitstop. Freeing
a character mid-hit is not exotic — it is what RETURN TO MENU does, and what
`ai_probe`'s `_end_match()` does between matches. **The symptom is not "the effect
stuck", it is "the whole game is 120× slower", which reads as a hang and points at
nothing.** Fixed with a wall-clock deadline any live character clears, plus a forced
restore in `_exit_tree()`. ⚠️ And the clock has to be REAL time (`Time.get_ticks_msec`),
because the thing being timed is a deliberate distortion of `delta` — 60 ms measured in
scaled time lasts 1.2 real seconds.

**17 · `--headless --import` DOES NOT PROVE A TOOL SCRIPT PARSES.** `docs/README.md`
calls it *"the one cheap real gate"* and it is the right gate for `scripts/` — but
`tools/fair_probe.gd` imported clean while containing a hard parse error (a nested class
redeclaring a const that already exists on its parent, which is an error and not a
shadow). It only appeared when the scene was actually RUN. **Run the probe once before
believing it exists**, the same way §3 says to run it once before believing it passes.

**18 · AN ASSET'S EXTENSION IS THE ONE THING YOU CANNOT CHECK BY LOOKING.** Two
deliveries on this project have been misnamed: the OST masters were MP3 data called
`.wav`, and the whole VO batch was **AAC in a 3GP container** called `.wav`. Godot
imports MP3, so the first only cost file size; it has no AAC decoder, so the second
made `load()` return null for every file — and the failure is silent by construction,
because `_load_vo()` skips a null and an absent pool is the SAME state as "not
recorded yet". **The folder was full, the names were right, the wiring was right, and
the game was silent.** Sniff the magic bytes (`tools/audio/vo_import.py`), never the
suffix. ⚠️ And the general form: when a subsystem's "nothing delivered yet" state is
indistinguishable from its "delivery is broken" state, it needs a probe that counts
FILES ON DISK against STREAMS LOADED, or the bug hides in the expected case.

**19 · A NUDGE LADDER'S REACH IS PART OF ANY KEEP-AWAY AND MUST BE SUBTRACTED FROM
IT — AND A SKIP IS ONLY HALF OF WHAT CAN GO WRONG.** `mapkit.try_place` walks a
ladder of offsets and returns a bool, so the position it was ASKED for is not the
position it used. A sari-sari store nominally 12 m up the alley, with a ±6 m ladder,
walked to 2 m outside the play box and became the same "big grey block" the move was
meant to remove — in the render sent as proof of the fix. Two rules came out of it:
**bound the ladder and subtract its longest step from the nominal** before claiming a
clearance, and **assert the PLACED position, not just that something placed.** A piece
that lands in the wrong place reports as a success and is counted under "nudged
clear". ⚠️ Related: `Placer.report()` truncates its skip list to four names, which is
how the west store stayed missing from the shipped map without anyone noticing — if a
landmark must exist, `assert` it rather than printing a count.

**11 · BLENDER IS OUT OF THE PIPELINE — a recorded finding, do not re-litigate.**
A full session was spent editing the Kenney rigs through Blender MCP and was
rejected. The repo already has a deterministic procedural pipeline; the glTF round
trip ships custom split normals that smooth-shade every flat face (the *"bumpy and
unnatural"* read, invisible in Blender's own viewport); and editing someone else's
topology needs a bespoke fix for every quirk. The props have none of these
problems, which is why they are what the lane builds.

---

## 7 · Log

One short entry per session. **The reasoning that is still load-bearing has been
promoted into §6; this is the record of what happened when.**

**2026-07-31 · 🎮 `build core`** — the pivot. Deleted `scripts/abilities/**`,
`carriable.gd` (1 635 lines), `hitbox`/`hurtbox`/`throw_profile`, and the 3 172-line
AI. Rewrote `character_base`, `carrier`, `match_manager`, `round_manager`. Three
decisions worth keeping: contact resolves by distance on the host in all three
places (`hit_probe` had measured 16 of 36 `Area3D` overlaps failing to land); the
confinement clamp needed one line changed; spawns are derived from
`CONFINEMENT_RADIUS`, not from map markers.

**2026-08-01 · 🔊 `build sound`** — the OST, VO pooling, and the pivot's silent
SFX. Six "silent" call sites turned out to be a naming problem, not a missing
feature: the call sites existed and the names had never been registered. Two of
them are reused audio from deleted mechanics. Nothing verified by ear.

**2026-08-01 · 🖥️ `build ui`** — the HUD scene, the tutorial rewrite, the result
screen, the lobby, the viewmodel arms, the bounds sweep, and §1.8's two-peer run.
The two-peer run is the important one: the replication is sound, and two real bugs
were in front of it (`_try_late_join` throwing on every join; every non-simulated
character frozen in `fall`). Both were in files no lane owns.

**2026-08-01 · 🖥️ `build ui`, mechanics revision** — the taya stopped being
passive (the lunge replaced a tag that fired every frame on adjacency), the shove
became a tap, slippers gained owners, and stamina became a 50-point pool draining
at 40/s. `SHOVE_SPEED` was re-derived rather than nudged — `sqrt(2.5 × 60)` on the
same `v²/FRICTION` solve. Caught by probe rather than reasoning: replacing the
passive tag meant the tag now needed a BUTTON, and `ai_controller.gd` did not know
one existed — six tags before the change, zero after.

**2026-08-01 · 🎨 `build model`** — the play area to 6.5, four cans from the
drawings, four slippers. The slippers are the story: four procedural ones were
built from the drawings and rejected four times, and the human sourced CC-BY models
instead. `glb_tool.py` converts a `.glb` without Blender. Findings kept: a
photogrammetry scan brings its table with it, so "keep the biggest island" kept the
TABLE; "biggest island" is wrong for a shoe anyway (a sole and its strap touch
nowhere); and a bounding box cannot tell you which way a diagonal shoe points —
PCA on the vertex cloud can. Textures were allowed on the two hero props on a human
ruling, and cost the tint system nothing.

**2026-08-01 · 🎨 `build model` (follow-up)** — six bugs from play. The two that
mattered came from the same wrong assumption: the floor is at y = 0.1 and every
prop assumed 0, and the naive fix raycast per frame from the slipper (see §6
trap 2). Also: the CHARACTER screen previewed the same can for every lata skin; the
held slipper was fixed properly by re-parenting; twelve rigs have only two named
hand bones; and the bots could not throw from a diagonal because `_safe_spot()`
sent them to a point on a CIRCLE while the box is a SQUARE.

**2026-08-01 · 🎨 `build model` (follow-up 2, this branch)** — verification pass
plus four human-reported bugs.

*Verified rather than assumed, because the ask was "confirm it reaches the game":*
all four slippers and four cans load, size and texture (`skin_probe` 8/8), preview
their **own** mesh on the real CHARACTER screen (`charprop_probe`, new — it asserts
mesh PATHS rather than taking a picture, because four cans that all look like cans
is exactly the failure that survives a look), and behave in a live match
(`prop_probe`: floor +0.1000, slipper-in-hand 0.0000 m, 51 flights).

*The FPP slipper was never invisible.* `fpp_carry_probe` (new) reported it visible,
meshed and inside the frustum the whole time — at **0.171 m**, because
`ViewmodelArms.tscn` authors it at mesh scale and it then inherits two nested
shrinks (0.72 × 0.55). It was also hardcoded to `tsinelas_classic.obj`, so a player
who picked SIKE held a brown flip-flop in their own hands. Now sized to 0.34 m and
copied off the world slipper rather than looked up again in the roster.

*Every bot wore the same face* because an AI seat keeps `character_index = -1` and
`_model_path()` falls back to `PERSON_MODELS[team]`. Dealt host-side in
`_refresh_ai_prop_picks()` — an empty stub since the pivot — and carried by the
`_rpc_sync_picks` table that already existed. ⚠️ `randi()` would give two peers two
faces; a pure function of the slot cannot see which Persons the humans took. Seats
are walked with `range()`, not by iterating a Dictionary, because `taken`
accumulates as it goes and insertion order differs per session.

*"Single Player always starts you as taya" was not a broken control.* All four
lobby rows store their seat (`solo_seat_probe`, new) and all four seats drive the
right unit (`fpp_carry_probe --seat=N`). `GameLaunch.solo_seat` simply defaulted to
0 and `defender_slot_for(1)` is 0, so the default seat was the one that defends
first. Moved the default; deliberately did **not** re-base the rotation, because
that function being pure is the whole fairness argument and it is shared with
multiplayer.

*The menu OST leak was real and the probe had said it was fine* — because the probe
only asserted DURING the round, and the leak is in the free-roam window before the
countdown. Now a scene-state model (§6 trap 9), with a hard cut rather than a
crossfade on 🧑's instruction, and the new check verified red on the unfixed code.

*Deleted:* `tsinelas_bakya.*`, `tsinelas_tsinelas.*`, four orphan textures, and
`build_prop_textures.py`'s slipper half — a second generator writing another
generator's output paths, the same trap that had already cost hours.

⚠️ **Out of this lane's §3 row, on direct human instruction** (*"add this to
fixes"*, *"fix everything"*): `audio_manager.gd` is `build sound`'s,
`camera_rig.gd` is `build ui`'s, and `main.gd` / `game_launch.gd` are nobody's.
Recorded rather than quietly done.

**2026-08-01 · 🎨 `build model` (follow-up 4)** — the Hamachi lobby. The report was
*"it only works on the pc that configured the hamachi"* and the answer is that
hosting was never the broken part: `create_server()` binds every interface, so any
machine on the tunnel could always host. The lobby just advertised the wrong
address, because "first non-loopback IPv4" is whatever order the OS returns and
that is normally the physical adapter. Ranked now, all candidates offered, APIPA
discarded. ⚠️ **The general lesson: a symptom phrased as a capability ("X can't
host") can be a display bug.** The address also moved out of an ellipsis-trimmed
`Label` into a selectable read-only `LineEdit` with COPY, which is the half that
was actually asked for. Out of row (`scripts/ui/**` is 🖥️ `build ui`'s) on direct
instruction — *"pls fix this! first prioritze this"*.

**2026-08-01 · 🎨 `build model` (follow-up 3)** — fixed the bug the previous pass
only filed. `Slipper.owner_slot` had no writer but the grab and the throw, so
ownership rode on a courtesy pickup that can silently refuse (§6 trap 12). It is an
explicit replicated assignment now, from seats walked in numeric order. The half
worth keeping: a one-round test would have passed the old code, because the bug
that actually bites on round 2 is the *opposite* one — the stale owner from round 1
made the gate refuse the new owner's pickup. `slipper_owner_probe` checks the
rotation for that reason, and goes red on the unfixed code.

⚠️ **Not verified:** any of this on two real peers (filed as 1.12); the mix by ear;
frame cost with the 65k-triangle SIKE. `build_prop_textures.py` was edited but not
run — Pillow is not installed on this machine — so it is `py_compile`-clean only,
and its can outputs are unchanged and already committed.

**2026-08-01 · 🖥️ `build ui`** — §1.11 through §1.15, plus four live UI notes and
one rename, all from the human looking at rendered screens in real time.

*§1.11, licence compliance.* New `CreditsPanel.tscn`/`credits_panel.gd`, reached
from a plain `WoodButton` (bottom-right of `MainMenu.tscn` — no fifth pennant
exists, and this control was not worth inventing one for) rather than folded into
SETTINGS or TUTORIAL, because a licence credit search should not require guessing
which existing screen it hides in. Every CC-BY line is the model's own
`*_LICENSE.txt` credit string, copied verbatim rather than paraphrased — that is
what the licence actually asks redistributors to do. *Verified the REACHABILITY
RULE properly*: new `tools/ui/credits_shot.gd` loads the real `MainMenu.tscn` and
emits the button's own `pressed` signal rather than instantiating the panel in
isolation, then renders it.

*§1.12, two real peers.* Added `character_index` to `net_twopeer_probe`'s `[FIN]`
player row and ran it for real — `--host` and `--join=127.0.0.1` as two separate
OS processes, not two in-editor instances. Identical on both ends:
`character_index=0,0,6,9` for P1..P4. ⚠️ **The same run found a live bug this
lane does not own** — filed as §2.24: a carried slipper's hand attachment is
built independently, at runtime, on every peer, and the round-reset RPCs do not
wait for it, producing 319 `Node not found` errors on the client and 3
`!is_inside_tree()` errors in `main.gd::_reset_slippers` on the host, plus a
`[FIN]` slipper-count disagreement between peers. Filed, not fixed — both call
sites are in files §2.19 already flags as ownerless, and this is a reparent-vs-RPC
ordering question that needs the owning lane's sequencing judgement.

*§1.13, investigated, left open.* The UID mismatch is still there. The one-line
fix (`colormap.png.import`'s `uid=`) touches a file `build model`'s own lane
prompt names as explicitly off-limits, and no lane's §3 row covers it at all — so
it stays filed rather than becoming a second unowned-file patch nobody signed off
on.

*§1.15, fatigue and the glow.* New `tools/ui/fatigue_glow_shot.gd`: seats the
local player as an attacker (round 1's defender is always slot 0, so slot 1 is
guaranteed an attacker), drives real `Input.action_press` — sprint held with
forward, then a tap-throw — through a live `Main.tscn`, not synthetic state
pokes. Fatigue: `is_fatigued()` true at frame 166, `crouch` pose rendered with the
HUD's own `FATIGUED 2.0s` row showing. Glow: found the slipper by
`owner_slot == player_slot` rather than by what is currently in-hand (the first
version of this probe assumed "attacker → holding a slipper" and failed dry,
because by the time fatigue finished the slipper was already loose on the ground
— which is in fact the state the glow is FOR) and rendered it LOOSE with the rim
outline lit, beside the unlit lata.

*Four things the human flagged live, from actual screenshots, not from this
lane's own testing pass:*
* `scenes/ui/MatchSetup.tscn`'s CHARACTER row stretched wider than MAP/BOTS —
  `CharacterButton` was the only `size_flags_horizontal = 3` child in its row;
  every other selector is `0` (fixed to its `custom_minimum_size`). Matched it.
* Same screen's `ConfigPanel` left a dead strip of wood panel to the right of the
  (now-narrower) rows, because the panel filled `LeftColumn`'s full 960px while
  its rows never used more than ~700. `size_flags_horizontal = 0` so the panel
  hugs its own content instead of the column's width.
* `ModeSelect.tscn`'s SINGLE PLAYER / MULTIPLAYER buttons sat bunched under the
  banner with ~260px of dead air above `BACK`. Shifted both buttons, their
  captions and `StatusLabel` down 80px as one block; `BackButton` untouched.
* The new CREDITS button's `offset_bottom = -40` clipped in real fullscreen —
  the same class of bug `MatchSetup.tscn`'s own `BackButton` margin comment
  already documents (a control this close to the true screen edge previews fine
  in the editor but not on a real monitor). Matched to that fix's 96px clearance.

*One rename, out of row, on direct human instruction* (*"sike only says IKE so js
change the name to ike on everything"*): `CharacterRoster.SLIPPERS`'
`"sike"` entry's display `"name"` is now `"IKE"` — the model carries the real Nike
wordmark as geometry (`Art_Direction.md` §4b) and only "IKE" reads legibly off it
in play. `id` and every asset path are untouched; only the string a player sees
changed. `character_roster.gd`'s SLIPPERS table is `build model`'s per §3 —
recorded here rather than quietly done.

⚠️ **The Hamachi "only the owner can host" report, re-litigated and closed as
already-fixed.** Re-read `NetworkManager.host_game()` and `match_setup.gd::
host_addresses()` end to end: both are already correct (`create_server()` binds
every interface; addresses are ranked Hamachi-first since commit `0fbb917`,
2026-08-01). No code changed here. The human found the actual remaining cause
independently while this was being explained — Windows Firewall silently
dropping inbound connections on the non-owner's machine, with zero error on the
host's own screen. **Filed, not built**: an in-game hint (lobby-side troubleshooting
text) and/or a raised ENet peer cap so a lobby that is already full of players can
still take a pure spectator (🧑: *"there could be 4 ppl playing and im a 5th or
6th guy just watching"*) were both requested and explicitly deferred to next
session (*"fix bugs firs thto, do lan ltr"*) — `NetworkManager.MAX_PLAYERS` is
used correctly everywhere as the SEAT count (4, a real game-design invariant) and
only incorrectly reused as the ENet connection cap at `network_manager.gd:264`;
decoupling those two is the shape of that fix when it is picked back up.

**2026-08-01 · 🤖 `build ai`** — the AI replaced, measured over whole matches, and
the ship list closed except the one item the human deferred.

*The headline number was not about aim.* §6.6 read "51 flights, 0 knockdowns" and
had been read as an aiming problem since it was taken. It was a release-power
problem: the plateau detector compared a `0.005` epsilon against the **0.0043** one
60 Hz frame adds to `charge_power()`, so it fired on the third frame of every
wind-up and every throw left at power ≈ 0.36. Power is a speed scale, 0.36 is
10.6 m/s, and that reaches **5.6 m** against a shortest legal throw of **6.5 m** —
so `_solve_arc()`'s discriminant went negative on every single shot and it fell back
to "throw along the line and fall short", exactly as its own comment promises. The
replacement inverts the range equation (`v_min = sqrt(g(Δy + sqrt(Δy² + d²)))`) and
charges to a margin over it. **79 throws / 43 knockdowns at NORMAL**, and re-shimming
the 3-frame release into the new controller reproduces `throws 329 knockdowns 0` on
demand — the red proof §6 trap 3 asks for.

*§6.3's "three bots chasing one slipper" was a rules bug, not a coordination
problem.* `_nearest_loose_slipper()` predates ownership. A slipper has belonged to
one attacker since 2026-08-01 and `can_be_grabbed_by()` refuses everybody else, so
two of three bots were always standing on a prop pressing a button it would never
answer — which is also most of §6.7's missing 280 metres. What is left of 1-vs-3 is
a genuine three-body problem (one taya covers one bearing) and it is answered by
scoring sixteen bearings against where the taya is and where the other two have
already committed. **Nobody cooperates** — they are rivals, and reading the court is
individually rational.

*The human's own report was the most useful bug description of the session.* 🧑:
*"the ai is so horrible they all move at the same time"*. Three controllers built in
one `for` loop, one think interval, started on one frame. Random think phase plus a
`_Personality` seeded from the SEAT (so bots differ from each other while two runs
of one match still give the same four characters) is the whole fix, and it is the
difference between three bodies and three players.

*Three things the probe found that no amount of reading would have.* An armed
attacker whose lata is lying down is refused the throw and had nowhere to put the
waiting, so it stood still — two bots for 22 s and 57 s, with the lata down ~70 of
180 live seconds. A taya that walks up to its target and stops can never aim its
lunge again, because `look_at()` only runs on a frame the body moves (§6 trap 13):
42.9 s adjacent to a vulnerable attacker, lunging at nothing. And one bot spent
**64.4 s** wedged, which the first version of the metric could not distinguish from
idling at all (§6 trap 14) — patience is now bounded and there is a general
unstick step.

*Three tiers that are three opponents,* 17 knobs each, all measured: EASY hits
**10%** of its throws (and throws the most, because it will not wait for a lane),
NORMAL **45%**, HARD **59%**. 🧑 asked for exactly this — *"i think its realistic if
the ai sometimes make mistakes and theyre not perma perfect"* — and it is `mistake`,
`react`, `aim_error`, `sprint_reserve` and `hesitation` rather than one difficulty
multiplier.

*§2.1 has evidence for the first time,* filed as §2.25: passive defence is **21-32%**
of every point against a competent offence and **77%** against the broken one, so
the 900-point alarm is real but conditional on the attackers not converting. Not
acted on — it is `build fair`'s number and this is bot-vs-bot.

*The ship list.* 8.2 was real and measurable: `exclude_filter` was empty, so 35
probe scenes, the Python map builders and every design doc were shipping to judges —
`ai_probe` appears **8 times** in the exported `.pck` before the fix and **0** after.
8.1's premise was not: neither preset names deleted code, and what was actually
wrong was a missing `export_path` on the Windows preset. ⚠️ **8.4 deliberately left
open on direct instruction** — 🧑: *"dont do it yet"*, *"odnt fix the .exe yet"*,
*"we will edit mroe stuff pa"*. Both zips in `build/` are from **2026-07-29**, which
is older than the board said and predates the whole pivot.

**2026-08-01 · 🤖 `build ai` (follow-up)** — a stale-documentation sweep, on direct
instruction (🧑: *"can you actually scan read me and docs to make sure theres no
stale stuff"*). Sixteen present-tense claims across four documents were describing a
game that had been deleted, and three of them were instructions somebody would have
followed:

* **`README.md` told a new contributor to branch from `feature/objects-overhaul-v2`**
  — a branch of the 2v2 design — and `docs/README.md` said the same. Both now name
  `HANSDAKS-test`.
* **`README.md`'s "how to verify visual work" command did not run.**
  `tools/render_probe.tscn` builds its match out of `team_is_can_side`, `is_can` and
  `report_round_result()`, all deleted on 2026-07-31, so it cannot boot. Replaced
  with `harrydaks_shot.tscn` and `ai_probe.tscn`, and the dead one is called dead.
* **`docs/README.md` named `--check-only` as *"the one cheap real gate"*.** It is
  not: it does not load autoloads, so it reports a false "Identifier not found" for
  every autoload reference in a file. The real gate is `--headless --path <abs>
  --import` grepped for `Parse Error`. This one cost time in this very session.

Also corrected: the controls table was missing **`lunge` (RMB)** entirely — the only
verb the taya scores with — and `clean_feed` (H); it still described the shove as a
1.25 s hold and the lata reset as 2.5 s (it is a tap and 1.5 s); "there is still no
music" against two OST tracks that play; "thirteen binaries are LFS-tracked" against
**176**; a `scripts/` tree listing `carriable`, `hitbox`, `hurtbox` and
`scripts/abilities/`, none of which exist; "docs/ four files" beside a five-file
table; and a camera directive whose second half directed a camera for props that
stopped being players. `docs/HUMAN.md`'s **"do not record these"** section was the
worst of them and is inverted now: it told the team to hold back round numbers
because 📋 `build rules` was about to introduce paired sets — **the opposite
happened**, paired sets were deleted, and round numbers have been safe to record for
a day while "round winner" and "match point" describe rules the game does not have.

⚠️ **Out of row, all of it recorded**: `docs/Design.md` is ⚖️ `build fair`'s and two
lines of its prose said the reset channel was 2.5 s while its own table and the code
both said 1.5 — prose corrected to the authoritative value, and the decision itself
left filed as §2.26. `docs/HUMAN.md` is 🔊 `build sound`'s. `scripts/ui/credits_panel.gd`
and `tools/ui/credits_shot.gd` are 🖥️ `build ui`'s — see §1.17 and §1.18.

⚠️ **Not verified:** any of this on two real peers (§6.11); that the exported build
RUNS (§8.3); whether sabotage's measured 0-1 per match is the right frequency
(§6.10). ⚠️ **Worked in a `git worktree` for most of the session** because another
lane had an uncommitted parse error in `main.gd` — a file §2.19 still flags as
having no owner, and the second time this session that being ownerless cost
somebody time.

**2026-08-01 · ⚖️ `build fair`** — the board's number-one suspect closed, the prop stat
tabs made real, and a global left at 5% speed by an object that no longer existed.

*§2.1 was right about the arithmetic and wrong about the conclusion, and the error was
one word.* "+10/s for 90 uncontested seconds is 900 points" has led this board since the
pivot. **Nothing in this game is uncontested.** New `tools/fair_probe.tscn` builds the
player the alarm predicts — a taya that guards from the shipping bot's own post and
resets the can instantly but **never lunges** — and plays whole matches with it through
the same spectator path and time-scale contract `ai_probe` uses. Three policies, one
complete match each: a taya that does **nothing** collects **38 of the 900 (4%)**,
because the can is only upright **4.7%** of the round; a taya that hides collects 733
(81%); one that plays collects 743. So the term is the PRIZE for keeping the can up, and
it is fully contested. And hiding is strictly dominated — `turtle` and `bot` bank the
*same* passive total (2930 v 2970) because the tag stacks on top of defence rather than
competing with it, so refusing to play forfeits 1700 points for nothing. The seat with
the highest passive share in the `turtle` run finished **last**. **The number does not
move.** `Design.md` §8.1 is the record, and the probe gates it at ≤50% (measured 47.8%,
close on purpose) so an inflation of the term goes red rather than unnoticed.

*The experiment is one-variable by construction.* `turtle` copies the shipping AI's own
`GUARD_RADIUS` post and its reset behaviour and removes exactly one thing, the lunge —
so `turtle` minus `bot` is the value of the tag and nothing else. The brains EXTEND
`AIController` from the probe's own file and override `decide()`; `ai_controller.gd` is
not edited. ⚠️ The takeover is re-asserted every physics frame rather than on
`round_started`, because `main.gd::_reassert_spectated_bots()` re-enables controllers on
a schedule of its own and a taya that quietly reverted for part of a round would report
a `turtle` number with the lunge back in it.

*§2.8: the two prop tabs were the REACHABILITY RULE's second half, exactly.* 🧑: *"also
make sure the stats actually apply"*. `CharacterRoster.prop_trait()` was written,
documented and had **zero callers** — every lata played identically, every tsinelas
played identically, and the CHARACTER screen drew three meters per pick the whole time.
All six now reach gameplay, re-glossed per tab because a prop does not walk: the can's
SPEED shortens its reset channel, its POWER lengthens the retrieval it forces, its GRIT
shrinks the hit window; the slipper's SPEED is launch speed, its POWER is what a
body-block costs the blocker, its GRIT is how fast it is armed again. **The two tables
compose without knowing about each other** — a block scales by the thrower's tsinelas
POWER and divides by the blocker's own person GRIT (measured 4.238 v 5.618 m/s on one
blocker).

*Two Person rows were byte-identical and nobody could have seen it.* KUYA BOY and
BEBANG were both 2/5/4; MANG KANOR and ATE GIRLIE both 4/3/3. Two characters wearing two
rigs, invisible on the CHARACTER screen because the meters look correct on both.
`trait_probe` asserts all twelve rows are distinct now, which is the kind of thing that
only stays true if something checks it.

*The number that decided every knockdown in the game was an unnamed literal in another
file.* `Design.md` §7 listed a lata "hurtbox 0.30 r / 0.70 h", `Lata.tscn` carries an
`Area3D` authored to exactly that, and **neither had a reader**: the rule ran off a bare
`0.30` in `slipper.gd`. It is `Lata.HIT_MARGIN` now, same value, and it is where the
can's GRIT lands. ⚠️ **The scoring window deliberately does NOT follow the mesh** even
though §2.23's collider now does — the four cans span 32% in radius, and a competitive
difference between cosmetic picks has to be *declared* on a meter rather than fall out
of geometry. Collider follows the art; the rule follows the stat.

*The bug that cost the most time was not a game number.* `matches=3` hung at match 2,
and the cause was `_hitstop()` guarding two **static** flags with a `SceneTreeTimer`
bound to an **instance** method — free that character inside 60 ms and `Engine.time_scale`
stays at 0.05 for ever. It reads as a hang, not as a stuck effect, and it hits the
shipping game too: RETURN TO MENU frees every character. Fixed with a wall-clock deadline
any live character clears plus a forced restore in `_exit_tree()`. ⚠️ **It did not fix
`matches=3`**, so it was a real bug on the same path and not the whole story — filed as
§6.12 with the reproduction, because the remaining suspect is `main.gd`'s lifecycle and
that file is §2.19's ownerless one for the fourth time.

*Also closed:* §2.9 (`max()` stays, and it is why the body block is knockback rather
than a stagger), §2.11 (a block now pushes, flashes and shakes the blocker — it used to
produce only a sound at a world position), §2.17 (`slipper_land` had a mix level and no
caller; **38 of 71 flights** in the baseline landed in silence), §2.18 (`round_ended`
broadcast, reliable and `call_local`), §2.26 (five stale prose sites, not three, and
`character_base.gd`'s controls comment was wrong about the shove as well).

⚠️ **Not verified:** anything by ear (§4.7 — no audio device, so §2.17 is proven as a
call site and not as a sound); §2.18 on two real peers; what any of §2.11/§2.22's
feedback LOOKS like, which is now the only thing left on §2.22 and needs a capture
rather than more code; and a real human taya, which is the half of §2.1 a bot harness
cannot reach by construction. ⚠️ **Not reached:** the shove, stamina, the tag and the box
(§2.28 records what the runs did show about each, so the next pass starts from evidence
rather than from the same blank items).

**2026-08-01 · ⚖️ `build fair` (follow-up)** — the mechanics bench, the box, and two
maps' worth of furniture moved on live human direction.

*`tools/mech_probe.tscn` rewritten from 355 lines of deleted 2v2 into a bench for the
four items that were all "this number has never been measured".* §2.4 the shove, §2.5
stamina, §2.6 the tag against a MOVING target, §2.7 what a tag costs, §2.16 the preview.
Every unit is PUPPETED — an `AIController` subclass that presses exactly what the bench
says, through the same intent harness a keyboard feeds — because a live bot walking
through a measurement is indistinguishable from the mechanic under test.

*Two findings worth more than the numbers they came from.* **One full sprint covers
6.84 m**, which was one box half-width: the stamina bar is dimensioned to one crossing of
the danger zone, so `STAMINA_MAX`, `SPRINT_SCALE` and `CONFINEMENT_RADIUS` are one
interlocked set and nothing had written that down. And **the shove's real price is
0.63 s of sprint**, not its 25 stamina — it is paid for in escape distance out of the
same pool that gets you out of the box.

*§2.6 is answered and the answer is "no tunnelling".* The lunge tags from **3.20 m**
against a stationary target and **3.20 m** against one crossing at full attacker walk —
identical. The every-frame sweep does what it claims; the tag is a LEAD problem.

*The bench lied to me three times before it told the truth, and each lie looked like a
game bug.* A shove reporting 0.00 m (a slipper inside `PICKUP_RADIUS` had eaten the E
press — the contextual-E rule working correctly); a sprint reporting 0.99 m of a
predicted 6.5 (it ran into the body the previous test left in front of it); and a
crossing-target tag reporting 0.00 m, which reads EXACTLY like the tunnelling failure
being hunted — the 38-trial scan simply outlasted the 90 s round, so everything gated on
`can_act()` started refusing. ⚠️ **A harness that runs out of clock reports the bug it
was looking for.** The round is held open now.

*The box went 6.5 → 7.5 on human instruction*, with the reason stated (*"the rsn we did
bigger area is to make it harder for attackers"*). **8.0 was tried first and Eskinita
rejected it**: the alley half-width IS 8.0, so the chalk landed on the walls and
`can_throw()` would have left no legal ground on the east/west sides at all. The throwing
line is what has to fit. ⚠️ **Cost recorded, not argued**: throws 71 → 17 and DEFENSE
39% → 73.8% over a whole match. Intended direction, large step, and `fair_probe` is the
instrument that will say if it went too far.

⚠️ **Out of row, all on direct instruction, all recorded**: `tools/maps/**` and
`scenes/maps/**` are 🎨 `build model`'s. Both maps lost the `gutter_tile` kanal beds AND
the `HazardZone` volumes they existed to explain (🧑: *"this looks bad it keeps phasing in
and out"*, *"yes remove slow zone"*) — **both had to go together**, because the tiles were
laid precisely so the slow field would not be invisible, and Eskinita's sat INSIDE the
box while the plaza's straddled its edge, which made the map pick a balance pick.
`mapkit.Placer` gained an opt-in `play_box` keep-out; it was blanket for one iteration
and evicted 39 props, which was wrong (🧑: *"i was okay with the clutter earlier"*, *"i
liked the tires and the tables and the yero walls"*) — **trees only** now.
`spectator_camera.gd` (nobody's row, §2.19 for the third time) had `BASE_SPEED` 12.0,
2.6× a walk: 6.0 now, floor 3.0 → 1.2 (🧑: *"why is it so fast, barely controllable"*).
Its `_follow_name()` also **threw on every call** — it read `character.team`, renamed to
`player_slot` in the pivot — and built the string "TEAM A · LATA" out of three words that
describe a deleted game.

⚠️ **Not verified:** anything by ear; two real peers; what any of the feedback LOOKS like
in play. ⚠️ **Not reached:** §2.3 (blocked on the shove's frequency, not on effort),
§2.10 beyond the two probes rewritten, §2.12, §2.13, §2.19, §2.24.

**2026-08-01 · 🔊 `build sound`** — the VO landed, and the mix finally had something
to be balanced against.

*The delivery was not a WAV.* Eleven files named `*.wav` were **AAC audio in a 3GP
container** — a phone voice-recorder export. Godot has no AAC decoder, so `load()`
returns null, `_load_vo()` skips the file, and the pooling reports exactly what it
reported when the folder was empty. **The failure mode is that everything looks
right**: the drive folder is full, the filenames are correct, the code is wired, and
the game is silent. `tools/audio/vo_import.py` sniffs the container and never trusts
the suffix, for that reason. It is the second time — TABLE D's OST masters were MP3
called `.wav`, and that one also cost a session before anyone checked the bytes.

*The ids were right and the filenames still could not be used.*
`_vo_id_from_filename()` strips `vo_` and then the LAST underscore-separated segment,
because that segment is the recorder's name. An id that contains an underscore and
has no name after it therefore eats its own tail: `clock_10.wav` resolves to
**`clock`**. Eight of the eleven delivered names have that shape. The importer writes
`vo_<id>_<take>.wav`, and `docs/HUMAN.md`'s naming section now asks for the plain id
rather than a name, because a name in the middle is what makes the parse ambiguous in
the first place.

*Three edits nobody asked for and all three were load-bearing.* 0.15–0.28 s of head
silence trimmed (docs/HUMAN.md actively ASKS for a leading second, and a `count_3`
that arrives after the "3" is off screen is worse than no line at all); normalised to
−6 dBFS from a delivered −0.9 to **+0.2**; 5 ms fades at the cuts, because a trim that
lands mid-waveform is a tick on every play.

*The countdown needed the one thing this lane could not see.* `play("countdown_tick")`
is the same string for 3, 2 and 1, so `count_3`/`count_2`/`count_1` could not be told
apart from inside `audio_manager.gd`. A tick COUNTER was the obvious answer and is
wrong — it infers `main.gd`'s literal `["3","2","1"]` and speaks a wrong number the day
that loop changes length. `play_countdown(text)` reads the digit instead, so a 5-count
asks for `count_5`, which is a real id with no take, and degrades to SILENCE rather
than to a lie. ⚠️ **Out of row**: one line in `hud.gd` (🖥️ `build ui`'s) — the SFX call
it replaces was written by this lane and cites checklist 4.1, and the new call keeps
that file at exactly one audio line.

*§4.7's actual defect was that the voice had no level control at all.* `play()` and
`play_at()` subtract `HEADROOM_DB`; `play_vo()` never did. Measured, that ships the
announcer ~7 dB over every sound effect while ducking the music 10 dB each time it
speaks. With `VO_TRIM_DB` the voice measures +2.1 dB peak / −1.1 dB RMS against the
effects and +5.6 dB over the bed, full mix peaking −4.7 dBFS. **`MUSIC_BASE_DB` was
not moved, and that is the result rather than an omission** — the bed already sits
5.5 dB under the effects.

⚠️ **The first version of the mix probe measured 5 s windows and the two match phases
disagreed by 7.3 dB on SFX RMS.** Not a mix difference — two different five-second
slices of one round, one holding the countdown burst. A level tuned on that window is
tuned to whichever events happened to land in it. 14 s now.

⚠️ **Out of row, twice more, both on direct instruction and both recorded rather than
quietly done.**
* **The crude verbatim quotes in the comments were paraphrased** across 21 files, 55
  of them, including one racial slur in `build_footwear.py`. 🧑: *"yo can u remove
  quotes like that"*. The convention of quoting the human next to the code their
  report caused is what makes this repo traceable and it stays; only the register
  moved, word-for-word, with the original line breaks and comment prefixes preserved.
* **`tools/maps/build_eskinita.py`** — the "big grey rectangular block". See below;
  it is 🎨 `build model`'s file.

⚠️ **AND THE FIRST FIX OF THAT BLOCK MADE A SECOND ONE, WHICH IS THE PART WORTH
KEEPING.** The reported object was not the tall-clutter tier that had already been
moved for the identical complaint — tinting every tall piece on that edge left it
untinted. It was the **sari-sari store**, reading as a blank slab because `front_yaw`
aims the counter at the alley, so the court only ever sees its back. Moving it
surfaced that the WEST store had never been on the map at all: pinned, its footprint
was blocked, `try_place` dropped it, and `Placer.report` truncates its skip list to
four names so nobody read it. Restoring it at z 9.0 — 2 m past a 7.0 box — put a fresh
2.6 m blank panel at the court corner, and **the render sent as proof of the fix had
the block in it.** 🧑: *"in the pic u sent me the block is STILL THERE"*. Two lessons,
both now enforced in the builder: **a nudge ladder's reach is part of a keep-away and
must be subtracted from it** (nominal |z| 12 with a ±6 ladder guarantees |z| 6), and
**a skip is only half of what can go wrong — a piece that places in the WRONG place
reports as a success.** Both stores' PLACED z is asserted now, captured through a
wrapped `place_fn` because `try_place` returns only a bool.

⚠️ **Not verified:** that the recordings say the words they are named for. Nothing in
this repo can assert that `vo_count_3_1.wav` is somebody saying *"Tatlo!"* — the probe
checks format, pooling, routing and level, and a human has to check the rest.
⚠️ **Still owed:** `tumbang` above all (the lata going over is the whole game and it
is silent), plus `taya`, `ayos`, `bilis`, `title`, `lata_restored` — all wired, all
empty, all live the moment a file lands.

**2026-08-01 · 🔊 `build sound` (follow-up)** — a long play-and-point session. The
human played the running game and reported bugs by screenshot; almost none of them
were in this lane, and 🧑 removed the lane gate partway through (*"do all fixes i
ask u to even if not in ur lane"*). Everything below is recorded rather than
quietly done, which is the half of §3 that still applies.

*Two bugs were mine, and both are worth keeping.* **A stale constant reference took
the whole game down** — `RIBBON_WIDTH` renamed to `WIDTH_PER_METRE` with one
straggler, which cascaded `trajectory_preview` → `carrier` → `character_base` →
`ai_controller` → `round_manager`. The human's report was *"the restricted area for
throwing doesnt exist anyjmjore, all bots are just running to the can"*, and both
halves were true because the rules and the brains were dead. ⚠️ **`--headless
--import` reported it CLEAN** — §6 trap 17 says importing does not prove a script
compiles, and this is the second time that has cost real time. Run a probe.
And **the open-pickup change made every bot idle after throwing**: `_my_slipper()`
was rewritten to choose among LOOSE slippers, but `_pick_plan()` asks it while not
holding and immediately tests `mine.is_flying()`, so a slipper became invisible to
its own thrower the instant it left the hand. Measured 27 → 14 throws, 48.1% → 28.6%
hit rate, DEFENSE 31.7% → 70.8%.

⚠️ **`ai_probe` REPORTED `PASS` ON BOTH OF THOSE RUNS**, which is the more useful
finding. Its only offence gate was ≥1 knockdown per match, and a collapsed offence
still lands a lucky shot over four rounds. It has a hit-rate floor now (30%, NORMAL
and HARD only — EASY is *meant* to miss), verified red at a 90% floor and green at
48.4%.

*The "big grey block" was three different objects across two sessions, and only the
third answer was right.* Not the `CLUTTER_TALL` yero tier — that had already been
moved for the identical complaint, and tinting every tall piece on that edge left
the reported object untinted. It was the **sari-sari store**, blank because
`front_yaw` aims the counter at the alley so the court only ever sees its back.
Moving it surfaced that the WEST store had never been on the map: pinned, blocked,
dropped by `try_place`, and past `Placer.report`'s four-name truncation. Restoring
it at z 9.0 put a fresh slab at the court corner — **and the render sent as proof of
the fix had the block in it**. 🧑: *"in the pic u sent me the block is STILL
THERE"*. Two rules came out of it and both are now §6 trap 19: a nudge ladder's
reach is part of any keep-away and must be subtracted from the nominal, and a piece
that PLACES IN THE WRONG PLACE reports as a success, so assert the placed position
and not merely that something placed.

*Slippers disappearing was two unrelated bugs wearing one description.* On other
machines it was the **MultiplayerSynchronizer left silenced**: both halves of the
quiet period were side effects of `_attach_to_hand()`/`_detach_from_hand()` and both
of those return early, so any path that put the slipper back another way never
re-opened it and the prop froze where it was last seen. On the thrower's OWN screen
it was **`SHADOW_CASTING_SETTING_SHADOWS_ONLY`** — 🧑: *"they disappear and are just
a shadow"* — because `camera_rig.gd` blanks the local body in FPP with SHADOWS_ONLY
rather than `hide()` (correct: losing your shadow destroys the ground read), applies
it to every mesh under `Visual`, and a carried slipper is re-parented under that
same `Visual`. Throw it and it leaves the subtree still flagged, and the restore
loop only walks what is under `Visual` now. **Both are §6 trap 12 a third and fourth
time** and both are driven from the carry STATE now rather than from a reparent that
can decline.

*Slipper ownership was reversed, having been reversed the same morning.* Any
attacker may take any slipper; `owner_slot` survives as the label the arrow and the
glow read. That re-opens §6.3, answered by a claim rule (only the nearest eligible
attacker goes) plus a 3.5 m handicap on a human's own slipper — a handicap rather
than a dice roll, because a random refusal is unreadable. `Design.md` §5.2 keeps
both instructions.

*The aim arc was not a styling problem.* Godot 4 rasterises every line primitive at
exactly one pixel and no material property widens it, so no colour would have fixed
it. Camera-facing ribbon now, scaled by distance — and the first version used a
constant WORLD width, which looked right side-on and became a yellow band across a
third of the first-person view. **Caught only by rendering it from the eye the
complaint came from.**

*The CHARACTER panel overflowed on all 20 entries, not just the reported one,* by
20–97 px. `bounds_sweep` passes because it only ever renders the default entry.
`tools/ui/charselect_fit_probe.tscn` walks every entry on every tab now.

⚠️ **Not done, and why:** the *"Tutorial and Credits signboards float"* item from
the handoff. Both are 2D `Control` panels (`Tutorial.tscn`, `CreditsPanel.tscn`) —
there is no 3D signboard in either, and nothing in the project matches
`signboard`/`karatula`. The handoff's own § HOW THE HUMAN WORKS says to ask which
element rather than guess, because a wrong guess there cost two full map rebuilds.
**Which object floats?** Also not reproduced: the *"low-contrast filter over the
main menu"* — the menu was rendered at 1920×1080 and the artwork reads clean, so
either it is already gone or it is a different screen.

⚠️ **Still not verified:** that the arrow RENDERS on the screen edge (it now
resolves a target, which it did not before); that the VO says the words it is named
for; two real peers on any of today's replication changes.

**2026-08-02 · 🎬 `build pitch`** — the submission copy fact-checked against the code,
and three bugs that came out of doing it.

*The pitch documents live OUTSIDE this repo, on human instruction.* 🧑: *"put the docs
here not on the fucking github"*. The synopsis, the trailer storyboard and the demo
storyboard were rebuilt as `.docx` in the team's own format (their originals' paragraph
styles, fonts and page setup reused rather than re-authored) and handed over directly.
Nothing about the pitch is tracked in `docs/` any more.

*Nine claims in the team's drafts described a game this branch has changed.* The three
that mattered: a body-blocked slipper "bounces far into the field" (it lands **2.5 m**
from the taya since `DEFLECT_SPEED_SCALE` went 0.62 → 0.27, and that is the whole point
of the change); "a 2.5-metre dash lunge" (`LUNGE_SPEED` is **7.746**, a **1.0 m** dash —
2.5 m is the SHOVE); and "three players team up as Attackers" (there are no teams, and
saying so throws away the Esports argument). Also a 50-point stamina pool that is 60,
fatigue "disabling abilities" that disables nothing, and colour-coded slippers whose
tint is white on all eight skins.

⚠️ **The competition PDF answered three things this lane's prompt said to ask about, and
one of them moves a deliverable.** The trailer is **1-2 minutes and must loop** (it is
played on repeat at the venue), not 60-90 s. The demo is a **3-5 minute `.mp4`** as well
as the live pitch. The synopsis is a **500-word** form, not a paragraph.

*Then the fixes, all out of row, all on direct instruction* (*"do this as well"*,
*"put good effort in fixing the bugs i told u to"*):

⚠️⚠️ **§6.13 IS THE ONE WORTH READING.** The taya's punch could never fire, in any
match, since the day it was added. `_act()`'s sticky-button sweep released
`special_ability` whenever the plan was not `WINDUP` — written when WINDUP was the only
thing that pressed it — and the punch presses the same action under `HUNT`, three lines
earlier in the same frame. **The janitor ran after the tap and undid it.** New
`tools/tag_probe.tscn` measured it: `special_ability held 0.0%, 0 edges` with the taya
hunting 81% of frames, inside `PUNCH_RANGE` 80% and facing the victim 84%. Tags went
**1 → 6** over 25 game-seconds, and now land every **5.0 s**, which is `TAG_STUN_TIME`
exactly.

⚠️ **The probe exists because every tag number on this board is bot-versus-bot.**
`ai_probe` and `fair_probe` both run through `GameLaunch.spectator`, which makes all four
seats bots — so the configuration a person actually plays had never been under a probe at
all. That is also why the report arrived from a teammate rather than from the board.

*§2.34, found by asking the human's own follow-up question honestly* (*"can humans even
tag ppl?"*): a joined client's LUNGE had no path to the host and never resolved for
anybody but the host. The punch and the shove both had `_rpc_request_*`; the lunge did
not. It does now, resolved host-side as one swept segment along the dash path.
**Unverified on two real peers, and it is the item that most needs that run.**

*§1.21 / §1.22, both from screenshots:* the left status stack was drawn on top of the
scoreboard (both anchored TOP_LEFT, the stack at a hardcoded y=150 that is inside a
four-row board) — it derives its top from the panel's real height now. And
`YOU ARE VULNERABLE` sat across the middle of the frame, over the slipper it is warning
you about; it is bottom-centre now. ⚠️ **1.21 was rendered and looked at. 1.22 was not** —
the two states cannot share a frame, because `is_taggable()` is false while stunned.

*The VO was raised on the first report from somebody who had actually heard it.* 🧑:
*"the bg music overpower them"*. `VO_TRIM_DB` −4.0 → −1.0, and the music duck under a
voice line is now its own depth (−14) and holds for the take's real length instead of a
countdown tick's 0.5 s — the delivered takes run **0.74-1.45 s**, so the bed was climbing
back over the second half of every line. ⚠️ **§4.7's measurement was not wrong, it was
measuring peaks.** A dense sustained bed masks speech by RMS, where the voice measured
only −1.1 dB against the effects. No session that set that number had an audio device.

⚠️ **Not verified:** two real peers on §2.34; §1.22 on screen; anything by ear.
⚠️ **Still open and blocking, unchanged:** §8.4 — the build in `build/` is from
2026-07-29 and predates the pivot, and §8.3, that the exported build RUNS, has never been
checked. Judges play the artifact.

**2026-08-22 · 👁️ spectator POV switching** (`docs/Master_Prompt_Updated_Spectator.md`,
branch `updated-spectator`) — `Tab` is the camera switcher now: from free flight it places
the camera directly in a unit's POV (not over-the-shoulder first), and it wraps at the end
of the roster instead of falling out to free flight — `_cycle_follow()` forces `_pov = true`
only on the frame that leaves free flight, and index math moved to `%` so the list never
drops out. Left click is the new way out of POV: a raw `MOUSE_BUTTON_LEFT` check beside the
wheel's in `_unhandled_input`, gated on `_pov` so it does nothing in free flight or in plain
follow, snapping `_target_position` to the current spot first so the release does not lerp
across the map — same rule `F` now also takes explicitly rather than relying on the POV
snap's invariant. `V` and `F` are unchanged.

The spectated unit's name — `CharacterBase.display_name()` plus TAYA/ATTACKER — is a new
`Label` owned by `hud.gd` (`_spectator_target_name`, top-centre, built in
`enter_spectator_mode()`, freed in `exit_spectator_mode()`), polled every frame off a new
public `SpectatorCamera.spectated_label()` that just wraps the existing (private)
`_follow_name()` — the HUD still has never heard of anything camera-internal, same
one-way dependency `status_text()` already kept. Empty string in free flight, so nothing
draws; inherits the clean feed for free because it is a plain child of the HUD root.

⚠️ **A follow target that dies mid-POV used to leave the camera parked on a dead node
forever** — `_process` checked `is_instance_valid(_follow)` everywhere it read the field
but never actually cleared it, so status text and the HUD label were guarded correctly but
`_follow` itself stayed non-null. Added an explicit clear at the top of `_process`; the
camera already fell back to the right position by accident (`_target_position` was last
written by the POV snap), so this is a correctness fix for the STATE, not the picture.

**Extended `spec_probe.gd`** — 15 new checks: Tab-enters-POV-immediately, POV placement
(reused from the old `V`-specific checks, since Tab now does that job), `V` still toggles
POV/over-the-shoulder on the same target, the wheel/follow-distance checks moved after that
toggle, left click (drops follow, clears POV, moves the camera <5 cm that frame, keeps
yaw/pitch, still holds a beat later), left click as a free-flight no-op, N+1 Tabs never
falling back to free flight and wrapping to the same first unit, the HUD name matching
`display_name()` while spectating and being empty in free flight, and
`exit_spectator_mode()` actually freeing the label (moved to the very end of `_run_solo`,
after the shot capture — it strips the whole spectator HUD, so nothing after it can still
assume spectator state). Verified `--solo` (46/47 — the one failure is §3.11, an unrelated
pre-existing environment issue: this run's Single Player roster spawned four Persons and no
Props at all, nothing to do with this feature), rendered `--shots=` and looked at both
frames (no viewmodel arms, no head in shot, `BERTO · TAYA` legible over both the sky and the
scoreboard panel in POV; nothing drawn in the free-flight shot), and both two-peer modes
(`--lobby-host` 22/22, `--lobby-join` 8/8 — the seat/ready-gate/no-character guarantees are
untouched).

⚠️ **Two pre-existing, unrelated bugs found and fixed while re-running this probe, both
filed here rather than silently left red:**
* `spec_probe.gd`'s own §2.2 flight section called `Input.action_press("guard_dash")`, an
  action deleted along with Can-Dash and Flick Dash — `spectator_camera.gd::_process`'s own
  comment already documents the rename to `spectator_down` and dates it well before this
  session. It threw every frame of that section and never failed a `_check` for it, so the
  ground/ceiling/fence claims had been silently unverified for a while. Fixed the action
  name; that then exposed the wait durations were sized for the old `BASE_SPEED` (12.0,
  since tuned down twice to 3.6 — see that constant's own doc) and no longer cleared their
  thresholds, so those were re-derived from the current speed too.
* `hud.gd::_refresh_lata_card()` runs unconditionally every frame from `_process` and was
  re-asserting `lata_card.visible = true` the instant a round went live, one frame after
  `enter_spectator_mode()` had hidden it — a spectator watching a live round had the lata
  card back on screen with no HUD control able to remove it again. Gated the whole function
  on `not _spectating`, the same rule `enter_spectator_mode()` uses everywhere else.

**Also:** `spectator_camera.gd`'s class doc pointed at `Design.md` §9, which is traits and
skins now — the spectator has no design-doc section any more. Says so plainly instead:
this file is the description. `controls_text()` rewritten for the new `Tab` and the new
click.

**2026-08-22 · 👁️ spectator: the PLAYER'S POV, reversing the placement design**
(`docs/Master_Prompt_Spectator_Player_POV.md`, branch `updated-spectator`) — 🧑, with a
reference frame: *"it's only a camera pov. it should have the player's pov instead. like
the reference picture. it should also reflect when they've been tagged (frost effect).
and the arm retracts when they're charging their tsinelas."* The same session's earlier
entry built POV as a camera PLACEMENT at the unit's eyes; this reverses that call because
a placement shows none of what the player is doing — no arms, no tsinelas, no wind-up, no
frost — and every one of those already exists on `CameraRig`, gated behind `_active and
_mode == FPP`.

**`CameraRig.set_spectated(on)` is a new third state**, alongside `set_active()`'s real
takeover and the deleted placement — *"renders like an active rig and reads like a dead
one."* It flips everything `set_active(true)` does for rendering (fpp_camera.current,
`set_process(true)`, `_apply_fpp_self_hide()`) and explicitly writes
`set_process_unhandled_input(false)` regardless of `aim_source`, rather than trusting the
`aim_source != MOUSE` coincidence bots happen to hold. `set_active()` and
`set_aim_source()` are both gated to no-op while spectated, so nothing else — the debug
switcher, `main.gd::_reassert_spectated_bots()`, a role rotation — can reopen the one path
that would let this machine's mouse steer a body it does not own. `is_local_fpp()` was
left returning true for a spectated rig, deliberately and in writing: its only consumer
already double-gates on multiplayer authority, which a spectator can never hold.

**`spectator_camera.gd`**: `_begin_borrow()`/`_release_borrow()`/`_sync_from_borrowed_rig()`
replace the old eye-placement math entirely; `POV_EYE_HEIGHT_PERSON`,
`POV_EYE_HEIGHT_PROP` and `POV_FORWARD_OFFSET` are deleted (the rig already solves all
three, correctly, per-bot). Exactly one rig is ever borrowed — every place that changes
`_follow`/`_pov` releases first. The wheel is now inert during POV (it used to silently
adjust `_follow_distance`, which did nothing visible but violated "the wheel does not
touch a borrowed rig" once written down). ⚠️ **TRAP #1 hit exactly as predicted**: the
camera's own authoritative `current` reclaim in `_process` had to be gated on
`_borrowed_rig == null`, or it fought the rig's `fpp_camera` for `current` every frame.

**`hud.gd`**: the spectator branch's early return used to skip `_refresh_frost()`
outright; now it calls it with `SpectatorCamera.spectated_pov_character()` (null outside
an actual POV). `_refresh_frost()` itself had a latent bug this exposed rather than
created: its "always trust the countdown" comment was true only because its one caller
was always the local player's own body; a spectated remote unit's `stagger_time_left()`
returns a bare 0 (the timer is deliberately unreplicated), which read as "stun already
over" and would have zeroed the frost the instant it should be heaviest. Fixed with the
same `left > 0.0` guard `character_visual.gd::_process_frost()` already carries for the
identical reason.

**`character_visual.gd::_drive_viewmodel_charge()`**: reads `observed_charge_power()`
for any unit this peer does not truly drive, `charge_power()`/`is_charging()` only for
its own. ⚠️⚠️ **First attempt gated on `rig.aim_source == MOUSE` and was measurably
wrong** — Single Player's spectator flow (`main.gd`) never resets the nominal seat-0
rig's `aim_source` away from whatever the `.tscn` baked (`MOUSE`), so a spectated seat-0
bot kept reading its own always-zero `charge_power()` and the arm never moved.
`spec_probe`'s new WIND-UP check caught it directly: `rotation.x -0.045 -> -0.000 rad`
against an expected `-0.347`. Replaced with the same `is_mine` pattern
`carrier.gd::_update_trajectory()` already uses (`is_multiplayer_authority()` if
networked else `player_id == 1`, `and not is_ai_driven()`), which is correct because
Single Player force-enables every unit's `ai_controller` the moment it spectates — see
`_reassert_spectated_bots()`. Re-measured after the fix: `-0.045 -> -0.347 rad` over 1.4 s
of a 2.5 s charge, which is `-0.62 × (1.4/2.5)` to three decimals.

**`main.gd::_reassert_spectated_bots()`** — TRAP #2. This function calls
`rig.set_active(false)` on every unit's rig, unconditionally, and still has to: it is
what stops a DIFFERENT unit's rig stealing the viewport. Left untouched and noted why it
is safe: `CameraRig.set_active()` is a no-op while `set_spectated(true)` is up, so the
one rig a spectator is standing inside of enforces its own exception rather than needing
this file to know it exists.

**Extended `tools/spec_probe.gd`** — the POV block's assertions were inverted rather than
extended (the old contract asserted the rig was NEVER activated; the new one asserts it
renders like one and never processes input), plus new checks: exactly one rig borrowed
and it is the current target's; the borrowed rig's own `fpp_camera` is the one actually
rendered; the spectator's own camera stands down while borrowing and reclaims on release;
`aim_source` is bit-for-bit unchanged across a full borrow+release cycle; the viewmodel
arms are visible in POV and hidden again after release; the released unit's meshes are
back to real shadows (not `SHADOWS_ONLY`); staggering the spectated player raises and
later clears the screen frost; the viewmodel arm visibly retracts from an
`observed_charge_power()` broadcast. ⚠️ **The frost check only proves the wiring, not the
unreplicated-countdown fallback** — Single Player simulates the bot directly, so
`stagger_time_left()` returns a real number there; the networked case where it returns a
genuine 0 is code-reviewed (see `_refresh_frost()`'s fix above) but not dynamically
measured this session. Verified `--solo` (59/60 — the one failure is §3.11, unrelated:
this run's roster had zero Props), rendered `--shots=` and looked at both frames — the POV
shot matches the reference exactly: real viewmodel arms in the lower third, no head, the
name legible over both the sky and the scoreboard panel — and both two-peer modes
(`--lobby-host` 22/22, `--lobby-join` 8/8, unchanged).

⚠️ **Not run this session**: `tools/charge_tell_probe.tscn`, the instrument the master
prompt names for measuring the wind-up against its 0.247 m first-person reference. It is
already broken independent of this work — `Invalid access to property or key
'team_is_can_side'`, a stale reference to a deleted team mechanic — and fixing an
unrelated probe file was out of scope for this pass. `spec_probe`'s own WIND-UP check
measures the same mechanism (an observed-clock charge reaching the visible arm through a
borrowed rig) as a bone-rotation delta rather than a metres-of-travel figure.
