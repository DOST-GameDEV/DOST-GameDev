# Agent Prompts — the board

**Branch `HANSDAKS-test`** (pushes go here; `HARRYDAKS` is the line it came off).
Four players, four 90-second rounds, one taya who rotates clockwise, cumulative
scoring. **The base game is built and playable.** The goal is a recordable
gameplay video.

> **RESTRUCTURED 2026-08-01.** 🧑: *"also clean up agent prompts · its so hard to
> naviagte · remove shit there that i dont need to run or wont need to see"*.
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
| **4** | ⚖️ `build fair` | Opus 5 · xhigh | every number, and the feedback that sells it | **Esports Potential** |
| **5** | 🤖 `build ai` | Opus 5 · high | `ai_controller.gd`, Single Player | Gameplay · Completeness |

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

- [ ] 1.11 ⚠️ **Three CC-BY models ship and their credit is not reachable from any
  screen.** CROCS, PANTULOG and SIKE are CC-BY-4.0, whose one requirement is
  attribution: **fnk**, **The Withered Rose**, **les03**. Table and links in
  `Art_Direction.md` §4b; each `.glb` ships its own `*_LICENSE.txt`. A line in a
  design doc that never ships does not satisfy the licence — these belong on a
  credits screen or in the submission's asset list, beside the existing Kenney CC0
  credits. **Compliance item, not a nicety.**
- [ ] 1.12 **`net_twopeer_probe`'s `[FIN]` snapshot carries prop `skin_index` but
  NOT `character_index`.** Person skins are now dealt to bot seats host-side
  (§5.16) and replicated through the existing `_rpc_sync_picks` table, and
  a single-process run proves the playing and spectator cases agree
  (`roster_spread_probe`, identical `SIGNATURE` lines). **What is still unproven is
  two real peers.** Adding `character_index` to that probe's snapshot is ~2 lines
  and closes it; the probe is this lane's file.
- [ ] 1.13 **`colormap.png` UID mismatch still warns once per character per load.**
  The twelve rigs reference `uid://dpu4hdrq88up6`; `colormap.png.import` declares
  `uid://c0kd7i625gon4`, so Godot falls back to the text path and prints a WARNING
  for each. Harmless on screen, four lines of noise in every probe run and every
  session. In nobody's §3 row — the rigs are explicitly out of `build model`'s.
- [x] 1.14 **`Slipper.owner_slot` was not set at spawn — FIXED by 🎨 `build model`
  2026-08-01, out of row, on direct human instruction** (*"fix the bug u found"*).
  Filed here first because this lane owns the two READERS; the fix landed in
  `slipper.gd` and `main.gd` instead. Full record in §5.20. **Your two
  features now have something to read**: the foot arrow (§1.6) and the owner glow
  (§1.15) can resolve "yours" from the first frame of a round, so both are worth
  re-checking on sight.
- [ ] 1.15 **The fatigue pose and the slipper glow are wired and unseen.** The
  fatigue pose needs someone to sprint a 50-point bar to zero; the glow needs the
  local seat to be an ATTACKER. Both are now unblocked — see §1.14. *(This was
  numbered **2.20** until 2026-08-01, in `build fair`'s range, while sitting in
  this lane's section — it is 1.15 now. Any older reference to "§2.20" means this
  item.)*

### ⚖️ `build fair` — every number, and the feedback  ·  items **2.x**

- [ ] 2.1 ⚠️ **Passive defence is very probably broken and is the first thing to
  measure.** +10/s for 90 s is **900 points** uncontested against **+100** for a
  knockdown. **Measure a real match before choosing.** ⚠️ Re-measure at the 6.5
  box, not 5.0 — see 2.21.
- [ ] 2.2 `CONFINEMENT_RADIUS` has never been tuned for 1-vs-3. ⚠️ A retune needs a
  map rebuild — `tools/maps/floorcheck.py` regexes the `const` out of
  `character_base.gd` and both builders draw the chalk from it.
- [ ] 2.3 `SABOTAGE_WINDOW` 2.5 s is a guess.
- [ ] 2.4 The shove has never been measured.
- [ ] 2.5 Stamina has never been measured in play.
- [ ] 2.6 `LUNGE_TAG_RADIUS` was never measured against a moving target.
- [ ] 2.7 `TAG_STUN_TIME` 5.0 s is 5.6% of a round spent doing nothing.
- [ ] 2.8 **Decide whether lata and tsinelas SKINS carry soft stats, and apply it
  yourself.** The tables carry `bilis`/`lakas`/`tatag` and nothing reads them.
  `build model` preserved them untouched. Record the decision in `Design.md` §9
  either way, **including a decision to leave them cosmetic**.
- [ ] 2.9 `apply_stagger()` uses `max()`, so a short stun inside a longer one is
  invisible.
- [ ] 2.10 **Every probe in `tools/` root is stale** — `mech_probe`, `phys_probe`,
  `round_probe`, `hit_probe`, `abil_probe`, `ai_probe`, `scuff_probe`, `spec_probe`
  all assert deleted mechanics. Rewrite the two or three that earn it.
- [ ] 2.11 A blocked slipper just stops. Body-blocking is the taya's entire passive
  verb and has almost no feedback. **Decide with 2.22.**
- [ ] 2.12 The lata's topple is 88° over 0.22 s — judge it from spectator range.
- [ ] 2.13 A thrown slipper has no trail and no impact VFX.
- [ ] 2.14 The tag's wind-up, animation and contact moment. Decide with 2.6/2.7.
- [ ] 2.15 Confirm the shove wind-up is visible on a second peer — it is the only
  thing that makes it dodgeable, and therefore 2.4's numbers fair.
- [ ] 2.16 Verify the trajectory preview still lands where the slipper lands.
- [ ] 2.17 **A slipper that lands without hitting a body or the lata plays no sound
  at all.** The asset (`slipper_land`) is registered and has never had a caller on
  the plain-miss branch of `_step_flying`.
- [ ] 2.18 **`RoundManager.round_ended` is emitted HOST-ONLY and never reaches a
  client.** Measured on two peers: the single line differing between two otherwise
  byte-identical streams. Not live today (zero subscribers), which is exactly why
  it needs writing down.
- [ ] 2.19 ⚠️ **`character_visual.gd` and `main.gd` have NO OWNER in §3**, and have
  now carried live bugs across three sessions. **Give both files an owner.**
- [ ] 2.21 **`CONFINEMENT_RADIUS` was moved to 6.5 by a map lane and needs your
  measurement.** It also invalidates 2.1's baseline.
- [ ] 2.22 **A thrown slipper STOPS DEAD on contact and does not read as physics.**
  🧑: *"the slippers should bounce back a bit when it hits shit"*. Partly addressed
  — the lata recoil and the body-block deflection both landed — but **neither has
  been seen in play**; confirm they read as physics rather than as a teleport.
  ⚠️ Contact must still resolve HOST-SIDE ONLY.
- [ ] 2.23 **The lata's collision is the MEAN of four cans, not any one of them.**
  One cylinder (r 0.13) against mesh radii 0.108 / 0.123 / 0.125 / 0.143. Worst
  case **22 mm** on Pasip. The fix is per-skin collision from `lata.gd::apply_skin()`,
  where the mesh swap already happens. *(Was numbered 2.19 by its filer, which
  collided with the ownership item above.)*

### 🔊 `build sound` — music, voice and the mix  ·  items **4.x**

- [~] 4.1 Two of five OST tracks delivered and playing. **Unverified by ear.**
- [x] 4.2 **Menu bed and round bed are owned by a SCENE STATE, not by a list of
  events.** *Verified: `tools/audio/music_probe.tscn`, 8 checks over the real
  chain splash → menu → mode select → lobby → match → back, and the new
  free-roam check FAILS on the pre-fix code.* See §6.
- [~] 4.3 Round-end / match-win / round-lose register real streams. *Unverified by ear.*
- [~] 4.4 **Voice-over pooling built, zero lines recorded.** Does not close until
  the team records against `docs/HUMAN.md`.
- [~] 4.5 Five of six previously-silent call sites now have a sound. The sixth is
  filed as 2.17.
- [~] 4.6 Ducking implemented inside `play()`. *Unverified by ear.*
- [ ] 4.7 **THE MIX HAS NEVER BEEN HEARD.** No session has had an audio output
  device. Balance the three buses against a real match. `tools/audio_mix_probe.gd`
  is the probe that should move `MUSIC_BASE_DB`.

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
  stale shit"*, *"delete the old fucking models that design lane tried to make"*.
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

### 🤖 `build ai` — Single Player *(RUNS LAST)*  ·  items **6.x**

- [ ] 6.1 **`ai_controller.gd` is a placeholder, not a baseline.** ~250 lines against
  the 3 172 it replaced. **Do not tune it. Replace it.**
- [ ] 6.2 No lookahead, no dodging, no shove, no body-blocking intent.
- [ ] 6.3 **1-vs-3 is an asymmetry nothing here has ever measured.** Three attackers
  chasing one slipper is the obvious failure mode.
- [ ] 6.4 **Keep the intent harness** — every decision through
  `CharacterBase.ai_set_intent()`.
- [ ] 6.5 `tools/ai_probe.gd` is stale and is yours.
- [ ] 6.6 ⚠️ **0 KNOCKDOWNS.** The bots throw and miss. Measured: **51 flights, 0
  knockdowns** over a 40 s match (`prop_probe.tscn`). That is aim, and aim is yours.
- [ ] 6.7 The bots barely move: **P3 = 14.2 m, P4 = 26.0 m** over a 90 s round
  against a 3.45 m/s walk.

### 📦 Ship checklist — **not a lane**  ·  items **8.x**

Done by whoever runs `build ai`, at the end of that session.

- [ ] 8.1 `export_presets.cfg` is only true about code that has since been deleted.
- [ ] 8.2 Probes and `tools/**` must not ship in the export.
- [ ] 8.3 A clean-clone build test.
- [ ] 8.4 ⚠️ **The build in `build/` is from 2026-07-31 14:19 and is badly stale** —
  it predates every music fix, the prop meshes and the two-peer bug fixes. If
  anyone is playtesting from that zip they are testing a different game.

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

Start with §2.1. Passive defence pays the taya +10/s for 90 seconds —
900 points — against +100 for a knockdown. Measure a real match before you decide;
do not reason your way to a number. Re-measure at the 6.5 box, not 5.0.

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

**The human has now listened to the mix, in this prompt session.** The actual
audio files (VO and any new OST) will be uploaded LATER, not this session. When
they land, they go in assets/audio/** per the existing layout (VO under
assets/audio/vo/, matching whatever pooling already expects them) — put each
file exactly where the code that plays it already looks, don't invent a new
path. Ask the human where a specific file goes if the existing call sites don't
make it obvious.

YOUR ONE REMAINING ITEM THAT MATTERS IS §4.7: NOBODY HAS EVER HEARD
THIS GAME. Every other box in your section is `[~]` for the same reason — no
session has had an audio output device, so the mix has never been balanced
against a real match. If you have audio, that is the job: play four rounds and
balance Master / SFX / Music against each other. tools/audio_mix_probe.gd is the
probe that should move MUSIC_BASE_DB.

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
