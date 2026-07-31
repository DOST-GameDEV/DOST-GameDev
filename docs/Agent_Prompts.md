# Agent Prompts — the pipeline, the checklist, the log

**Branch `HARRYDAKS`, rewritten 2026-07-31.** Replaces the eleven-lane board that ran on
`feature/objects-overhaul-v2`. Those prompts described a 2v2 game in which the lata and
the tsinelas were playable characters with eight abilities between them. That game is
deleted (`Design.md` §12), so the prompts that served it are deleted too — see
§ REMOVED IN THE HARRYDAKS PIVOT, which is the record.

**What this branch is.** Four players, four 90-second rounds, one taya who rotates
clockwise, cumulative scoring. The base game is **built and playable** — see
§ WHAT IS ALREADY DONE before you assume anything is unbuilt.

**The goal is a recordable gameplay video.** Everything on this board serves that.

---

## THE RUBRIC — what the board is scored against

**Screening (each 20%):** Completeness · Theme Relevance · Originality · Gameplay ·
Aesthetics and Creativity
**Final judging:** Gameplay 20 · **Esports Potential 20** · Graphics and Art 10 ·
**Music and Sound Design 10** · Creativity and Innovation 20 · Game Feedback 20
*(audience vote off the trailer and the demo)*

⚠️ **THE OLD BOARD'S "DO NOT IMPROVE THIS" CLAUSE IS DELETED AND MUST NOT BE
RESTORED.** It read: *"What is not broken and must not be 'improved': the
objects-are-players thesis. A slipper that charges a jump and dives onto a can to take a
round without its Person ever touching it is the Creativity and Innovation 20%."* That
is now false in every particular — that thesis is the thing this branch removed, on
human instruction, because it was *"too complicated and far from tumbang preso"*.
Leaving the clause in place would have the next agent rebuild what was just torn out.

**Where the originality actually is now:** it is a faithful digital tumbang preso, a
Filipino street game nobody else at this competition is adapting, with a role rotation
that makes every player play both sides. Theme Relevance and Originality come from
fidelity, not from invented verbs.

---

## HOW TO RUN A LANE

1. New chat. **Set the model and effort in the client before pasting** — the prompt
   names them, it cannot set them.
2. Paste that lane's block from § THE LANES verbatim, first message, nothing else.
3. It finishes → it ticks its own boxes in § CHECKLIST and appends to § LOG **in the
   same commit as the work**.
4. Only then start the next lane. **One lane at a time, in board order.**

**Every lane, no exceptions:**

* Branch from `HARRYDAKS`. No `application/config/version` bump.

> ### 🚨 COMMIT AUTHORSHIP — THE ONE RULE WITH NO EXCEPTIONS
>
> **Every commit is authored by `M4tyu633 <matthewtlabrador@gmail.com>` and nobody
> else.**
>
> * **NO `Co-Authored-By:` trailer. Ever.** Not for Claude, not for an agent, not for a
>   model name, not "on behalf of".
> * **No "Generated with", no 🤖 line, no tool attribution** anywhere in the subject or
>   body.
> * The message says what changed and why. It does not say who or what wrote it.
> * Verify before your first commit:
>
>   ```bash
>   git config --local user.name && git config --local user.email
>   ```
>
> * Check yourself after committing — `git log -1 --format='%an <%ae>%n%b'` — and fix it
>   with `git commit --amend --reset-author` before you push if it is wrong.
>
> This is a competition entry. It is submitted as one person's work and the history has
> to read that way in every one of its commits.

* `docs/Design.md` is the balance source of truth. **Move a number in the code → move it
  in `Design.md`, same commit.** Two numbers disagreeing is a bug with your name on it.
* Read before you write: `scripts/characters/`, `scripts/objects/`, `scripts/systems/`.
  Never speculate about a file you have not opened.
* **You own your paths and only your paths.** Reading anything is fine; writing outside
  your row in § PATHS is not. Sequential order is what replaces a file mutex.
* **You decide HOW.** Every value on this board is a starting point you may overrule —
  say so in § LOG with the reasoning. You do not ask permission for an implementation
  detail; you record the decision.
* **Do not spawn subagents.** Every lane does its own work in one focused session.
* Godot is not on PATH (`docs/README.md` has the invocation). A full
  `--headless --import` grepped for `Parse Error` is the one cheap real gate. Probes run
  as `.tscn`, never `-s`. **Anything that renders needs the PLAIN exe — `--headless` has
  no rendering device and every capture comes back blank.**
* **Never claim a verification you did not perform.** `[x]` needs a named probe, a
  screenshot, or a log. Everything else is `[~]`.

> ### 📌 IF YOU FLAG IT, FILE IT — hand every finding to the lane that owns it
>
> **A problem you noticed and only wrote about in § LOG is a problem nobody is going to
> fix.** The log is read once, by a human, after the fact; the checklist is what the
> next lane actually works from.
>
> So whenever you find something outside your own paths — a bug, a stale string, a
> number your change invalidated, a claim you could not verify — **add it as a numbered
> `- [ ]` item to that lane's own § CHECKLIST section**, at the end, under a bold line
> saying who filed it and when:
>
> ```markdown
> **Filed by `build ui` 2026-08-01:**
>
> - [ ] 2.9 **Passive defence pays 900 a round uncontested.** …why it matters…
> ```
>
> Rules for a filed item:
>
> * **It goes to the lane that owns the FILE**, per § PATHS — not to whoever is nearest.
> * **State what you observed, not what to type.** The owning lane decides HOW.
> * **Include the evidence** — the measured number, the probe name, the grep, the line.
>   "Might be worth checking" is not a filed item.
> * **Ticking is still theirs alone.** You add the box; you never tick a box outside
>   your own section.
> * **File it even if you think it is small.** A duplicate costs one line; a dropped
>   finding costs a session.

### ⚠️ THE REACHABILITY RULE — read this before you build any UI

**A feature a player cannot reach from the menus does not exist, and does not tick a
box.** This project has shipped systems that only a command-line flag could start. That
is the failure mode this rule closes.

Whatever you build, you also **wire into the screen a player actually meets it on**, in
the same commit:

* Name the entry point before you write the feature — which screen, which control, what
  it is called on screen.
* It must be **operable with a mouse and reachable by keyboard focus**, and sit in the
  existing focus order rather than beside it.
* It must survive a real path: Single Player *and* Multiplayer where both apply, host
  *and* client.
* A debug flag, an autoload variable or a console command is **not** an entry point.
* Render the screen and look at it. "The control is added to the tree" is not the claim;
  "I can see it and it does the thing" is.

⚠️ **AND ITS MIRROR IMAGE, ADDED 2026-07-31: A CONTROL THAT IS REACHABLE AND DOES
NOTHING IS WORSE THAN NO CONTROL.** For one commit this branch shipped a character
screen whose LATA and TSINELAS tabs picked values nothing read. It cost the player real
time and taught them the choice mattered. If you delete what a control drove, you either
delete the control or give it something new to drive — in the same commit.

---

## EXECUTION ORDER

**Presentation → Balance → Single Player.**
A lane may not start until the one above it has committed. **Five lanes.**

⚠️ **THE THREE PRESENTATION LANES WERE PULLED TO THE FRONT ON 2026-07-31.** 🧑: *"imma do
model sound and ui first bcz we gonna record demo soon"*. Everything a demo video shows is
in those three, and none of them depends on the two behind them. Recorded first, they also
give `build fair` a match worth measuring instead of a grey one.

⚠️ **IF THE ART AND AUDIO ASSETS ARE NOT IN THE REPO YET, RUN 🖥️ `build ui` FIRST AND
COME BACK.** Lanes 1 and 2 both block on a human delivering files — 🎨 `build model` needs
the tsinelas and lata drawings and 🔊 `build sound` needs recorded audio. 🖥️ `build ui`
blocks on nothing at all, and its two biggest items (the tutorial teaches a game that no
longer exists; half the HUD is built in code over the deleted 2v2 scene) are both squarely
on camera. Swapping it forward costs nothing and no ordering rule here forbids it.

⚠️ **MULTIPLAYER FIRST, SINGLE PLAYER LATER — HUMAN INSTRUCTION, 2026-07-31:** *"we will
fix the ai as well but put that in the end of agent prompts lane, we will focus on making
multiplayer first then single player next time."* That is why 🤖 `build ai` sits at
**last** despite being the largest single piece of work left. Do not promote it. It also
carries § CHECKLIST §8, the ship checklist, because it is the session that ends the board.

| Run | § | Lane | Model · effort | Owns | Rubric it feeds |
|---|---|---|---|---|---|
| **—** | §0 | 🎮 **`build core`** | — | the rules, the props, the loop | — · **CLOSED 2026-07-31** |
| **—** | §7 | 👁️ **`build spec`** | — | spectator camera + POV | — · **CLOSED, carried over intact** |
| **1** | §5 | 🎨 **`build model`** | **Opus 5 · medium** | the lata, the tsinelas, the play area | **Graphics and Art** · Aesthetics |
| **2** | §4 | 🔊 **`build sound`** | **Sonnet 5 · medium** | music, VO, SFX, the mix | **Music and Sound Design 10%** |
| **3** | §1 | 🖥️ **`build ui`** | **Sonnet 5 · high** | `scripts/ui/**`, `scenes/ui/**`, the tutorial | Gameplay · Esports · Completeness |
| **4** | §2 | ⚖️ **`build fair`** | **Opus 5 · xhigh** | every number **and the feedback that sells it** | **Esports Potential** · Gameplay |
| **5** | §6 | 🤖 **`build ai`** | **Opus 5 · high** | `ai_controller.gd`, Single Player | Gameplay · Completeness |

**FIVE LANES, AND THAT IS THE POINT.** 🧑 2026-07-31: *"too many lanes, that was the
problem with last one too, we are short on time"*. The board this replaced had eleven and
never finished them; the first draft of this one had seven. A lane is a whole session
with a cold start, so the count is a schedule, not a taxonomy — **if two lanes would
argue with each other over the same file, they were always one lane.**

**Why these models.**

* **`build ui` — Sonnet, high.** Breadth over depth: many screens, one language. High
  rather than medium because three of its items are cross-peer races and "it works on my
  machine" is the exact failure mode.
* **`build fair` — Opus, xhigh.** It is the only lane allowed to move a shipped number,
  §2.1 is a scoring-economy problem with no lookup-able answer, and it now owns the
  feedback for the things it tunes as well. Being wrong here costs the submission.
  ⚠️ **It used to run second and now runs fourth**, which inverts one dependency: §2.8
  (do prop skins carry soft stats?) was written for `build model` to *read* afterwards.
  `build model` now runs FIRST, so it leaves the stat fields exactly as they are and
  `build fair` applies its own decision to the tables when it gets there.
* **`build sound` — Sonnet, medium.** Breadth and taste over a system that already
  exists and already routes buses correctly.
* **`build model` — Opus, medium.** *"Does this silhouette read as a sardine tin from
  across a street, and is that name right in Filipino?"* is taste and cultural
  specificity. Medium, not high: the difficulty is judgement per object, not depth on
  any one.
* **`build ai` — Opus, high.** Novel behaviour design under a 1-vs-3 asymmetry nothing
  in this repo has ever measured.

**Why `build sound` and `build model` did NOT merge**, when everything else did: they are
different toolchains (an audio bus graph and a procedural mesh generator), they block on different people
delivering different things, and neither can start early. One lane that waits on both
finishes when the slower one arrives.

---

## WHAT IS ALREADY DONE

Do not rebuild these. Read them, then improve, verify, or overrule.

| System | File | State |
|---|---|---|
| 4 players · 4 rounds · rotating taya | `match_manager.gd` | **built**, role derived not accumulated |
| The scoring bus (100/50/100/10) | `round_manager.gd` | **built**, one authority path |
| The lata as a prop | `scripts/objects/lata.gd` | **built**, upright/down, ring, host-authoritative |
| The slipper as a prop | `scripts/objects/slipper.gd` | **built**, LOOSE/CARRIED/FLYING, arc lifted from the old solve |
| Stamina 100 + fatigue | `character_base.gd` | **built**, ⚠️ never measured |
| The shove | `character_base.gd` | **built**, ⚠️ never measured |
| The tag + 5 s penalty + sabotage credit | `round_manager.gd` | **built**, ⚠️ sabotage window is a guess |
| Throw gate (4 conditions) + crosshair tell | `round_manager.gd::can_throw` | **built**, one function, HUD shares it |
| Contextual E (pickup / shove / reset) | `carrier.gd` + `character_base.gd` | **built**, ⚠️ no probe presses it |
| Confinement box | `character_base.gd` | **kept whole**, ⚠️ 5.0 not re-tuned for 4 players |
| Spawns derived from the box | `main.gd` | **built** |
| HUD: scoreboard, lata card, status stack, toasts | `ui/hud.gd` | **built in code**, ⚠️ `HUD.tscn` still has the 2v2 nodes hidden under it |
| Player names, end to end | `settings_manager.gd`, `network_manager.gd` | **built**, ⚠️ not verified on two real peers |
| Prop skins from character select | `lata.gd`, `slipper.gd`, `main.gd` | **built** (tint only) |
| Spectator camera + POV | `spectator_camera.gd` | **carried over intact**, `spectator_down` is its own action now |
| Netcode, lobby, late-join, reclaim | `network_manager.gd`, `main.gd` | **carried over**, adapted to 4 seats |
| AI | `ai_controller.gd` | **deliberately minimal** — see §6 |
| Screenshot probe | `tools/harrydaks_shot.tscn` | **built**, prints match state + saves frames |

**Verified this session:** whole project imports with no parse errors; a headless match
runs a full 90 s round, the intermission and the rotation into round 2 with nothing on
stderr; a rendered 1600×900 capture shows the HUD over live play with the AI retrieving,
throwing, and scoring a knockdown.

---

## PATHS — one writer per file

| Lane | Writes |
|---|---|
| 🖥️ `build ui` | `scripts/ui/**` · `scenes/ui/**` · `systems/camera_rig.gd` · `trajectory_preview.gd` · `tools/ui/**` |
| ⚖️ `build fair` | **any number in any file** · `docs/Design.md` · `tools/*_probe.gd` · `character_base.gd` movement/contact block · `objects/slipper.gd` flight · `objects/lata.gd` topple |
| 🔊 `build sound` | `systems/audio_manager.gd` · `assets/audio/**` · `default_bus_layout.tres` · the audio rows of `ui/settings_panel.gd` · `docs/HUMAN.md` |
| 🎨 `build model` | `character_roster.gd` `CANS`/`SLIPPERS` (and the `ability` key only, in `ROSTER`) · `scenes/objects/**` visuals · `assets/models/**` · `tools/models/**` · `tools/maps/**` · `docs/Art_Direction.md`. ⚠️ **NOT the character rigs, `colormap.png`, `person_*.tres` or `generate_person_palettes.py` — reverted and out of scope, § CHECKLIST §5.** |
| 🤖 `build ai` | `systems/ai_controller.gd` · `tools/ai_probe.gd` · `export_presets.cfg` and `.gitignore` (the ship checklist — it runs last) |

**`character_base.gd` is touched by two lanes.** Sequential order is the lock: `build
fair` owns the numbers, the movement block and the contact block together; `build ai`
touches only the intent harness. **`build ui` never writes it.** That this file used to be
split between three lanes is most of why two of them merged — a boundary drawn through
the middle of one file is a boundary somebody crosses.

⚠️ **`build sound` FIRES FROM FILES IT DOES NOT OWN** — a score callout has to trigger
from `round_manager.gd` and a menu stinger from `scripts/ui/**`. **It does not edit
them.** It exposes what it needs on `AudioManager` and **files** the trigger onto the
owning lane's § CHECKLIST. A voice line with no trigger is filed, not forced.

---

## CHECKLIST

`[x]` = built **and verified**, and say by what. `[~]` = built, unverified, and say what
specifically is unverified. Tick only your own section.

### 0 · 🎮 `build core` — the pivot *(CLOSED 2026-07-31)*

- [x] 0.1 Four players, four rounds, clockwise taya rotation. *Verified: headless match
  reaches round 2 with the role rotated and scores persisting.*
- [x] 0.2 Lata and slipper demoted to props; `carriable.gd`, `hitbox.gd`, `hurtbox.gd`,
  `throw_profile.gd` and `scripts/abilities/**` deleted. *Verified: grep + clean import.*
- [x] 0.3 Stamina, throw gate, contextual E, shove, tag, scoring bus. *Verified: probe
  reports a knockdown scoring +100 to the thrower and +10/s passive to the taya.*
- [x] 0.4 HUD rewired; player names end to end. *Verified: 1600×900 capture.*
- [~] 0.5 Networked play. **Unverified: no two-peer session has been run on this
  branch.** Filed to `build ui` as §1.8.

### 1 · 🖥️ `build ui` — screens and readability *(Sonnet 5 · high)*

**⚠️ START AT 1.8, NOT 1.1.** A two-peer smoke test is the only item here that can
invalidate a whole recording session, and it is the only one nobody has ever run.

- [ ] 1.1 **`HUD.tscn` still carries the 2v2 layout underneath the new HUD.** The
  scoreboard, the lata card's second line and the status stack are all built in
  **code** by `hud.gd`, on top of scene nodes that are hidden rather than removed —
  `TeamALetter`, `TeamBLetter`, `TeamAPipsBox`, `TeamBPipsBox`, `TeamBLabel`,
  `DentPipsBox`, and the whole `TopRight` panel. That was deliberate (the scene is your
  file, not `build core`'s) and it is now yours to restructure properly.
- [ ] 1.2 **The tutorial teaches a game that no longer exists.** `tutorial.gd` still
  describes 2v2, the can and slipper as playable, Guard, Bump, dashes and the circle
  countdown. Every control it names is wrong. Rewrite it against `Design.md` §4.
- [ ] 1.3 **The match-result screen was gutted, not designed.** `_fill_pips` is replaced
  by a text standings list appended in code. Give it a real final-standings layout, and
  handle `winning_slot == -1` (an honest draw) as a first-class result.
- [ ] 1.4 **The role-swap card announces a round with no winner.** It now shows who
  defends next and who leads; check it reads correctly at the round-4 boundary, where
  there is no next round.
- [ ] 1.5 **Show names in the lobby.** `network_manager.gd::picks_for(peer)["name"]`
  carries them already; neither `multiplayer_setup.gd` nor `match_setup.gd` displays
  one. A four-player lobby where everyone is "Player 3" is the first thing a judge sees.
- [ ] 1.6 **The offscreen indicator for a teammate is a stub returning null.** There are
  no teammates. Decide whether a "nearest threat" or "your slipper" arrow earns the
  slot, or delete the arrow and its node.
- [ ] 1.7 **The FPP viewmodel arms are enormous** and dominate the lower third of every
  frame — visible in every capture in § LOG. That is the shot the trailer is filmed in.
- [ ] 1.8 ⚠️⚠️ **DO THIS ONE FIRST, BEFORE ANYTHING ELSE IN THIS SECTION. NOTHING ON
  THIS BRANCH HAS EVER RUN ON TWO REAL PEERS, AND THE DEMO IS BEING RECORDED IN
  MULTIPLAYER.** 🧑 2026-07-31: *"the record is in multiplayer bruh"*.
  Every one of these resolves host-side and is therefore untested by definition on a
  single machine: the tag (`RoundManager._step_tag`), slipper contact
  (`Slipper._first_body_hit`), the shove request (`_rpc_request_shove`), every score
  award (`MatchManager._sync_score`), the round rotation and world reset, the lata's
  upright RPCs, prop skin push, and player names arriving on the identify packet.
  A failure in any of them is invisible in Single Player and ruins a recording session
  that has four people in a room. `tools/aim_probe.gd` has a `--host` / `--join`
  harness to copy, and `tools/harrydaks_shot.tscn` already prints per-player match state
  — point one at each end and diff the two reports.
- [ ] 1.9 **Settings has a player-name row built in code** (`_build_name_row`), for the
  same reason as 1.1. Promote it into `SettingsPanel.tscn` and into the focus order.

**Filed by `build sound` 2026-08-01:**

- [ ] 1.10 **The round label prints "TAYA: P3", never the taya's set name.**
  `hud.gd::set_round_display`, line 786-787: `round_label.text = "ROUND %d / %d ·
  TAYA: P%d" % [..., defender_slot + 1]` — a raw seat number, not
  `RoundManager.player_at(defender_slot).display_name()`. Contrast
  `_refresh_scoreboard()` a few dozen lines down, which already reads
  `who.display_name()` correctly for every row including the taya's — this one
  line is the odd one out. Reported by a human as "username doesn't show if
  you're taya."

### 2 · ⚖️ `build fair` — every number, and the feedback that sells it *(Opus 5 · xhigh)*

**⚠️ THIS SECTION ABSORBED `build feel` (the old §3) ON 2026-07-31.** Items 2.11–2.16
 came from it. They merged because they are the same judgement made twice: you cannot
decide whether the tag is worth 100 points without also deciding that it currently has no
wind-up, no animation and no contact moment. They also shared files.

- [ ] 2.1 **Passive defence is very probably broken and it is the first thing to
  measure.** +10/s for 90 s is **900 points** uncontested, against **+100** for a
  knockdown. A taya nobody challenges out-scores three attackers who each land a throw.
  Either the rate is far too high, or it should only tick while an attacker is inside
  the box, or it should decay. **Measure a real match before choosing.**
- [ ] 2.2 **`CONFINEMENT_RADIUS` 5.0 has never been tuned for 1-vs-3.** It was measured
  for one taya against one attacker. ⚠️ `tools/maps/floorcheck.py` regexes the `const`
  line out of `character_base.gd` and both map builders draw the chalk from it — a
  retune needs a map rebuild.
- [ ] 2.3 **`SABOTAGE_WINDOW` 2.5 s is a guess.** Nothing has measured how often a shove
  actually leads to a tag inside it, or whether players ever notice the +50.
- [ ] 2.4 **The shove has never been measured.** 1.00 m of knockback is derived from
  v²/60, not observed. 25 stamina against a 100 bar and a 10 s cooldown is a guess.
- [ ] 2.5 **Stamina has never been measured in play.** 5 s of sprint, 2.5 s regen delay,
  2.5 s fatigue.
- [ ] 2.6 **`TAG_RADIUS` 1.1 was never measured against a moving target.** Both capsules
  are 0.45; 1.1 is contact plus a lag band picked by eye.
- [ ] 2.7 **`TAG_STUN_TIME` 5.0 s is a long time to hold a controller and do nothing** in
  a 90 s round — 5.6% of it, and it can happen repeatedly.
- [ ] 2.8 **Decide whether lata and tsinelas SKINS carry soft stats, and apply it
  yourself.** ⚠️ `build model` runs before you now and was told to preserve the `traits`
  fields untouched rather than guess, so the tables are waiting for you. 🧑 2026-07-31:
  *"maybe the skins could have soft stats? (dunno what those stats are yet though)"*.
  The `CANS` and `SLIPPERS` roster entries already carry `bilis`/`lakas`/`tatag` and
  nothing reads them. **You own whether they should, and what they would mean on an
  object nobody drives** — a heavier bakya flying slower is a real idea; a lata with
  `bilis` is not. Record the decision in `Design.md` §9 either way, including a decision
  to leave them cosmetic. Coordinate with 🎨 `build model` §5, which owns the tables.
- [ ] 2.9 **`apply_stagger()` uses `max()`, so a short stun inside a longer one is
  invisible** — a 1.25 s shove stun inside the 5 s tag penalty reads as nothing
  happening. Decide whether that is acceptable or whether the status stack needs two
  rows.
- [ ] 2.11 **A blocked slipper just stops.** No stagger, no sound beyond `hit_body`, no
  visual. Body-blocking is the taya's entire passive verb and currently has almost no
  feedback. *(was `build feel` §3.1)*
- [ ] 2.12 **The lata's topple is an 88° rotation over 0.22 s.** Judge whether it reads
  as a can being knocked over from the spectator camera at range. *(§3.2)*
- [ ] 2.13 **A thrown slipper has no trail, no impact VFX and no landing sound.** It is
  the object the whole game is about. *(§3.3)*
- [ ] 2.14 **The tag has no wind-up, no animation and no contact moment** — you are
  simply teleported. It is worth 100 points and it is invisible. Decide this together
  with 2.6 and 2.7, which are the same action's radius and penalty. *(§3.4)*
- [ ] 2.15 **The shove's 1.25 s wind-up broadcasts a bone pose** (`character_visual.gd`
  reads `observed_shove_charge()`); confirm it is actually visible on a second peer,
  which is the only thing that makes it dodgeable — and therefore the only thing that
  makes 2.4's numbers fair. *(§3.5)*
- [ ] 2.16 **Verify the trajectory preview still lands where the slipper lands.** The arc
  is drawn from `Slipper.launch_velocity_for()` and integrated at the physics tick; the
  old measurement was 0.000 m of error and nothing has re-checked it since the throw
  profiles were deleted. *(§3.6)*
- [ ] 2.10 **Every probe in `tools/` is stale.** `mech_probe`, `phys_probe`,
  `round_probe`, `hit_probe`, `abil_probe`, `ai_probe`, `scuff_probe` and `spec_probe`
  all assert deleted mechanics. They still parse only because nothing runs them. You are
  the lane that needs them; budget for rewriting the two or three that earn it rather
  than all of them.

**Filed by `build sound` 2026-08-01:**

- [ ] 2.17 **A slipper that lands without hitting a body or the lata plays no sound at
  all.** `slipper.gd::_step_flying`'s plain-miss branch (the `if global_position.y <=
  REST_HEIGHT:` case, around line 280) calls `_apply_landed()` directly with no
  preceding `AudioManager` call — contrast the body-block branch three lines up, which
  calls `AudioManager.play_at("hit_body", ...)` before the same `_apply_landed()`. The
  asset is already there and already registered (`slipper_land` — see
  `audio_manager.gd`'s `SFX_NAMES`) and has been since the 4.1 pass; it has simply never
  had a caller for this specific path. `slipper.gd`'s flight is this lane's file, not
  🔊 `build sound`'s, which is why this is filed rather than fixed directly.

### 4 · 🔊 `build sound` — music, voice and the mix *(Sonnet 5 · medium)*

*The full prompt is in § THE LANES.*

- [~] 4.1 **No longer no music.** Two of five OST tracks delivered by the human team
  (`docs/HUMAN.md` § TABLE D) — `ost_menu.mp3` (title/character-select/lobby) and
  `ost_match.mp3` (the 90 s round) — are loaded and playing through a real
  `AudioStreamPlayer` pair on the `Music` bus. *Verified: `--headless --import`
  reimports both with no Parse Error.* **Unverified: nobody has heard it** — this
  session has no audio output to confirm against, and `docs/HUMAN.md`'s own OGG spec
  was not followed by the delivered files (they arrived as MP3 data saved with a
  `.wav` extension — noted there, not blocking, Godot imports MP3 natively).
- [~] 4.2 **Menu bed and match bed cross-fade** on `MatchManager.round_started`
  (round 1) and `match_won`, from `AudioManager`'s own `_ready()` and signal
  subscriptions — no `scripts/ui/**` or `main.gd` file touched. **The last-15s
  intensity lift is a volume lift on the SAME match bed, not a real track 4
  cross-fade** — no PRESSURE track has been delivered yet; `_set_music_lift()` is
  the hook to swap it out the day one lands. *Unverified by ear, same caveat as 4.1.*
  **Three sequencing bugs found after this item was first ticked, all fixed same
  session:** (1) the menu bed started straight from `AudioManager._ready()` and
  raced `SplashScreen`'s intro clip — audible under the boot video, ahead of its
  own sting; (2) the match bed only started at `round_started`, which fires
  AFTER the pre-round 3-2-1-GO countdown, so the menu bed played under the whole
  countdown; (3) nothing crossfaded back to the menu bed on a path OTHER than
  `match_won` (a network-disconnect bounce, the result screen's own "back to
  menu" button, a solo quit). All three are now driven by
  `_poll_main_menu_edge()` (checks `get_tree().current_scene is MainMenu` every
  frame, fires only on the false→true edge) and a `countdown_tick`-name hook
  inside `play()` — both self-contained inside `audio_manager.gd`, no other file
  touched. *Still unverified by ear — same caveat.*
- [~] 4.3 **Round-end/match-win/round-lose now register real streams** —
  `hud.gd::_on_round_intermission_audio` and `_on_match_won` already called
  `AudioManager.play("round_end"/"match_win"/"round_lose")`; `round_end` had no
  stream registered at all and now does (`tools/audio/generate_sfx.py`'s new
  `build_pivot_extras()`). The 3-2-1 (`countdown_tick`/`countdown_go`) already
  worked before this session. *Verified: generator ran with no assertion failure
  (see `_write()`'s silence/head-trim checks) and `--import` is clean. Unverified
  by ear.*
- [~] 4.4 **Voice-over pooling built, zero lines recorded.** `audio_manager.gd`
  scans `assets/audio/vo/` for `vo_<id>_<name>.wav`, pools every take per id,
  never repeats the last take, and cooldowns per id (`VO_COOLDOWN_MS`) — wired to
  every event this lane could reach without editing a file it does not own
  (`title` at boot, `taya`/`ayos` off `RoundManager.attacker_tagged`, `tumbang` off
  `lata_knocked`, `lata_restored`, `match_win`/`match_draw` off `match_won`,
  `clock_30`/`clock_10`/`bilis` off its own `_process` poll of
  `RoundManager.time_left`). `docs/HUMAN.md`'s Table A/B were also corrected —
  three lines each struck for describing mechanics the HARRYDAKS pivot deleted
  (the out-of-circle countdown, teams) and replaced with the events that are
  actually real now. **This item does not close: it depends on the team
  recording**, which is the whole reason `docs/HUMAN.md` exists. `sayang` stays
  struck until 2.17 (filed above) gives it a trigger.
- [~] 4.5 **Five of six previously-silent call sites now have a registered sound**:
  `hit_body`/`bump_swing` (the shove connecting — reuses the orphaned `bump`/`dash`
  SFX from the deleted 2v2 bump and dash mechanics), `can_knockdown`/
  `reset_complete` (the lata's own knockdown/restore audio, aliased to the
  existing `lata_knockdown`/`reset_channel_complete` assets), `pickup`/
  `throw_release` (aliased to `grab`/`throw_whoosh`), and a new `score_award` ding
  on every non-DEFENSE `MatchManager.score_changed` (DEFENSE deliberately
  excluded — it fires every second of every round). **The sixth — a slipper
  landing with no body or lata in the way — is filed as 2.17** above rather than
  fixed here: the call site does not exist yet and the file is `build fair`'s.
- [~] 4.6 **Ducking implemented inside `AudioManager.play()` itself** —
  `countdown_tick`/`countdown_go`/`round_end`/`match_win`/`round_lose`/
  `score_award` all duck the active music player (fast attack, slower release)
  the instant they play, with no other file needing to know the duck exists.
  *Unverified by ear.*

### 5 · 🎨 `build model` — the two props, and the play area *(Opus 5 · medium)*

*The full prompt is in § THE LANES.*

> ### 🚨 OVERHAULED 2026-08-01, MID-SESSION, ON HUMAN INSTRUCTION
>
> 🧑: *"overhaul the model plan · remove blender and shit · we wont remove the
> characters anymore just add cans and slippers from my drawing but without blender"*.
>
> **THE CHARACTERS ARE OUT OF SCOPE. ALL TWELVE STAY.** The previous version of this
> lane cut the roster to four and edited the Kenney rigs in Blender. That work was
> attempted, rejected by the human on look, and **fully reverted** — the twelve `.glb`
> files, `colormap.png`, the palettes and `generate_person_palettes.py` are all back at
> their committed state. Do not restart it. Do not "improve" a character. The only art
> this lane makes now is the lata and the tsinelas.
>
> **BLENDER IS OUT OF THE PIPELINE.** No Blender, no Blender MCP, no `.glb` authoring,
> no round trip. See § WHY BLENDER WAS DROPPED below — it is a recorded finding, not a
> preference, and re-introducing it re-runs a failed session.

- [ ] 5.1 ⚠️⚠️ **THE PLAY AREA IS TOO SMALL AND IT IS THE FIRST ITEM.** 🧑, 2026-08-01:
  *"We recently overhauled the mechanics of the game and the current play area feels too
  small"* and *"i said bugs like play area needs to be bigger"*. Expand the Defender's
  allowed area, adjust the map meshes to suit, and **redraw the chalk on BOTH maps** so
  the play area and the throwing line visually demarcate the new boundary.
  ⚠️ The box is `CharacterBase.CONFINEMENT_RADIUS` (5.0), which
  `tools/maps/floorcheck.py` regexes straight out of the `.gd` and both map builders draw
  the chalk from — so a retune is a map rebuild, and **the `const` itself is
  ⚖️ `build fair`'s file, not this lane's** (§2.2 is the same number). Move the maps and
  the chalk; agree the value with them or file it.
- [ ] 5.2 The slipper — the object the game is named after — **built new** from the
  human's drawing, in `tools/models/generate_all.gd`. Its origin must sit at its centre
  of mass: it spins on two axes in flight (`SPIN_SPEED_DEG` 900 about its long axis,
  `TUMBLE_SPEED_DEG` 520 end over end) and an off-centre origin wobbles like a bent wheel.
- [ ] 5.3 The lata **built new** from the human's drawing, same generator. Its silhouette
  has to read as a can from across the arena, at spectator camera distance, **while lying
  on its side at 88°**. That readability is a gameplay requirement, not a look: a crowd
  that cannot tell a fallen lata from a standing one cannot follow the round.
- [ ] 5.4 ⚠️ **SIZES MAY CHANGE — PHYSICS CONSTANTS MOVE WITH THEM.** The old fixed-size
  rules are lifted (🧑 2026-08-01). Scale either prop to match the drawings, then update
  `Slipper.HIT_RADIUS` / `REST_HEIGHT` and the lata's body and hurtbox radii to match the
  new mesh **in the same commit**, and move the same numbers in `Design.md`.
- [ ] 5.5 **Tint-friendly materials.** `lata.gd` and `slipper.gd` walk every
  `MeshInstance3D` and write `albedo_color` from the roster entry's `tint`. A fully baked
  multi-colour texture fights that; author for a tint.
- [ ] 5.6 **LOW POLY ONLY.** Match the existing assets. No subdivision surfaces, no
  high-res detailing, no smooth shading that breaks the flat toon style.
- [ ] 5.7 `CANS` / `SLIPPERS` re-authored against the new meshes, and the dead `ability`
  key dropped from every entry in all three tables — `scripts/abilities/**` is deleted and
  the field is inert. **`ROSTER` is otherwise untouched**: the twelve characters stay.
- [ ] 5.8 **Carry the `traits` dictionaries across unchanged.** ⚖️ `build fair` §2.8
  decides whether prop skins carry soft stats and it runs *after* this lane, so preserving
  them is how that decision stays open.
- [ ] 5.9 Orphaned assets swept: `lata_dent1..3.obj` and the dent generator in
  `tools/models/generate_all.gd` describe a mechanic that no longer exists.

#### WHY BLENDER WAS DROPPED — a recorded finding, do not re-litigate

A full session was spent editing the Kenney rigs through Blender MCP. It reached four
re-modelled characters and was rejected. What went wrong is worth keeping, because every
item is a property of the APPROACH rather than of the effort:

* **The repo already has a mesh pipeline and it is not Blender.**
  `tools/models/generate_all.gd` + `obj_writer.gd` build `lata.obj`, `tsinelas.obj`,
  `viewmodel_arm.obj` and the whole `env_kit` procedurally, run by `godot --headless -s`.
  It is deterministic by contract (run it twice, `git status` must be clean), diffable,
  and needs no second application installed. A Blender step is a parallel pipeline for a
  job this one already does.
* **Blender MCP is not a reliable build step.** A `raise SystemExit` inside a guard killed
  the Blender process outright and took the session's connection with it; the addon also
  leaves a stray `Icosphere` in every scene, which a name-based mesh lookup silently
  treated as a character's head.
* **The glTF round trip loses the embedded texture** and, worse, ships **custom split
  normals** that smooth-shade every flat face. That mismatch — low-poly silhouette,
  high-poly shading — is what the human called *"bumpy and unnatural"* and *"very
  uncanny"*, and it is invisible in Blender's own viewport.
* **Editing someone else's topology is a bad trade.** Kenney's garment UV regions match no
  drawing, its arms are three boxes of differing widths (a lump at every wrist), and its
  limbs are chamfered so any hem drawn through them lands mid-polygon. Each needed a
  bespoke fix, and the human rejected the result four times.

**The props have none of these problems**, which is exactly why they are what is left: no
skeleton, no rig, no clip, no weights, and a generator that already knows how to build
them.

### 6 · 🤖 `build ai` — Single Player *(Opus 5 · high)* — **RUNS LAST**

*The full prompt is in § THE LANES.*

- [ ] 6.1 **`ai_controller.gd` is deliberately minimal and is a placeholder, not a
  baseline.** It is ~250 lines against the 3 172 it replaced. It plays the real rules —
  retrieve, leave the box, throw; guard, reset, chase — badly but legibly, so that the
  game films. **Do not tune it. Replace it.**
- [ ] 6.2 It has **no lookahead, no dodging, no shove, no body-blocking intent, no
  anticipation**, and its difficulty tiers scale only reaction time and aim scatter.
- [ ] 6.3 **1-vs-3 is an asymmetry nothing in this repo has ever measured.** Three
  attackers who all chase the same slipper is the obvious failure mode.
- [ ] 6.4 **Keep the intent harness.** Every decision goes out through
  `CharacterBase.ai_set_intent()`, the same indirection a human's keyboard feeds. An AI
  that writes `velocity` directly desyncs the moment it is not the authority for the
  body it is writing to.
- [ ] 6.5 `tools/ai_probe.gd` is stale and is yours.
- [ ] 6.6 **You also run § CHECKLIST §8, the ship checklist**, at the end of your
  session. Three mechanical items, not worth their own cold start.

### 7 · 👁️ `build spec` — spectator *(CLOSED)*

- [x] 7.1 Free-fly camera, POV on `V`, `Tab` cycles, seat −1, lobby toggle. *Carried
  over from the previous board intact.*
- [x] 7.2 Its descend key is now its own action, `spectator_down` (Ctrl), rather than
  borrowing the deleted `guard_dash`. *Verified: a 130 s spectator run is clean.*

### 8 · 📦 SHIP CHECKLIST — **not a lane**

**⚠️ THIS STOPPED BEING A LANE ON 2026-07-31.** The board's own description of it was
already *"a checklist, not a design lane"*, and spending a whole cold-start session on
three mechanical items is exactly the overhead the five-lane cut exists to remove.
**Whoever runs `build ai` (the last lane) does this at the end of that session**, or the
human does it by hand. It owns `export_presets.cfg` and `.gitignore`.

- [ ] 8.1 `export_presets.cfg` is only true about the code that existed when it was
  written, and a great deal has been deleted since. Re-check it against the current file
  set.
- [ ] 8.2 Probes and `tools/**` must not ship in the export.
- [ ] 8.3 A clean-clone build test.

---

## THE LANES

### 🖥️ `build ui`

```
You are `build ui` on branch HARRYDAKS of the Tumbang Preso repo. Model: Sonnet 5,
effort high.

Read docs/Agent_Prompts.md end to end first, then docs/Design.md. Obey HOW TO RUN A
LANE, THE REACHABILITY RULE and the COMMIT AUTHORSHIP rule exactly.

You own scripts/ui/**, scenes/ui/**, systems/camera_rig.gd, trajectory_preview.gd and
tools/ui/**. You do not write character_base.gd.

Your job: the game is playable and the HUD works, but half of it is built in code on
top of a scene that still describes the deleted 2v2 layout, and the tutorial teaches a
game that no longer exists.

⚠️ START AT 1.8 AND DO IT BEFORE ANYTHING ELSE. Nothing on this branch has ever run on
two real peers and the demo is being recorded in multiplayer. Every scoring, contact and
rotation path resolves host-side, so all of it is untested by definition on one machine,
and a failure there is invisible in Single Player and ruins a session with four people in
a room. Get a host and a client into the same match, play a full round, and diff what the
two ends report before you touch a single scene file.

Then work 1.1 through 1.9 in order. 1.1 (the HUD scene) and 1.2 (the tutorial) are the
two that matter most for a recordable video.

Render every screen you touch and look at it. "The control is added to the tree" is not
the claim. Use the PLAIN Godot exe for anything that renders; --headless captures come
back blank. tools/harrydaks_shot.tscn saves frames of a live match and prints match
state — copy it rather than inventing a new harness.

Tick your own boxes in § CHECKLIST and append to § LOG in the same commit as the work.
```

### ⚖️ `build fair`

```
You are `build fair` on branch HARRYDAKS of the Tumbang Preso repo. Model: Opus 5,
effort xhigh.

Read docs/Agent_Prompts.md end to end first, then docs/Design.md — which is the balance
source of truth and which you own. Obey HOW TO RUN A LANE and the COMMIT AUTHORSHIP
rule exactly.

You own every number in every file, Design.md, tools/*_probe.gd, the movement and
contact block of character_base.gd, slipper.gd's flight and lata.gd's topple. You are
the only lane allowed to move a shipped number, and every number you move moves in
Design.md in the same commit.

⚠️ THIS LANE ABSORBED THE OLD `build feel`. You own the FEEDBACK for the things you
tune as well as the values, and the two halves are one job: you cannot decide whether
the tag is worth 100 points without also noticing it currently has no wind-up, no
animation and no contact moment at all — the player is simply teleported.

Start with § CHECKLIST §2.1. Passive defence pays the taya +10/s for 90 seconds — 900
points — against +100 for knocking the lata down. On those numbers a taya nobody
challenges beats three attackers who each score. Measure a real match before you decide
what to do about it; do not reason your way to a number.

Then work 2.2 through 2.16. Some of them are deliberately adjacent and should be decided
together rather than in list order: 2.6, 2.7 and 2.14 are all the tag; 2.4 and 2.15 are
both the shove, and the wind-up being visible on a second peer is the only thing that
makes its numbers fair.

Note that 2.2 (the box size) requires a map rebuild: tools/maps/floorcheck.py regexes
the CONFINEMENT_RADIUS const line out of character_base.gd and both map builders draw
the chalk from it.

2.8 is a design decision the human explicitly handed to a lane rather than a new one:
decide whether lata and tsinelas SKINS carry soft stats, what they would mean on an
object nobody drives, and record the answer in Design.md §9 — including a decision to
leave them purely cosmetic. `build model` reads your § LOG entry and implements it.

⚠️ Contact resolves BY DISTANCE ON THE HOST, not through Area3D overlaps, in three
places: RoundManager._step_tag, Slipper._first_body_hit and Lata.is_in_ring. That is
deliberate — hit_probe measured 16 of 36 Area3D overlaps failing to land, split by
target. Do not reintroduce overlap-based contact while tuning it.

Every probe in tools/ asserts deleted mechanics. Rewrite the two or three you actually
need rather than all of them. tools/harrydaks_shot.tscn already renders a live match and
prints match state — copy it rather than inventing a new harness.

Tick your own boxes and append to § LOG in the same commit.
```

### 🤖 `build ai`

```
You are `build ai` on branch HARRYDAKS of the Tumbang Preso repo. Model: Opus 5, effort
high. You are the LAST lane on the board.

Read docs/Agent_Prompts.md end to end first, then docs/Design.md, then
scripts/systems/ai_controller.gd in full. Obey HOW TO RUN A LANE and the COMMIT
AUTHORSHIP rule exactly.

You own systems/ai_controller.gd and tools/ai_probe.gd. You also own export_presets.cfg
and .gitignore for one job only: § CHECKLIST §8, the three-item ship checklist, done at
the END of your session. It is not worth its own cold start, which is why it is not its
own lane.

The AI you are replacing is deliberately minimal — about 250 lines, written so that the
game films rather than so that it plays well. It is a placeholder, not a baseline: do
not tune it, replace it. Its own header says so.

Work § CHECKLIST §6. The hard problem is 6.3: one defender against three attackers is
an asymmetry nothing in this repo has ever measured, and three bots all chasing the same
slipper is the obvious failure mode.

⚠️ KEEP THE INTENT HARNESS. Every decision goes out through
CharacterBase.ai_set_intent(), the same indirection a human's keyboard feeds, so one
_physics_process serves both and the confinement clamp, the stun states, the throw gate
and the netcode all apply to a bot for free. An AI that writes velocity directly desyncs
the moment it is not the authority for the body it is writing to.

Measure fairness with a real probe over many rounds, not by watching one match.

Then do § CHECKLIST §8 and stop.

Tick your own boxes and append to § LOG in the same commit.
```

*(🔊 `build sound` and 🎨 `build model` prompts follow in § FUTURE LANES — they are lanes
3 and 4, written in full and blocked only on assets.)*

---

## FUTURE LANES

⚠️ **"FUTURE" IS NOW A MISNOMER AND THE SECTION IS KEPT ONLY SO EVERY LINK TO IT STILL
RESOLVES.** These two are lanes **1 and 2** — the front of the board, not the back. They
are blocked on assets and on humans rather than on code, which is exactly why they were
written in full before they were needed.

### 🔊 `build sound` — audio integration *(Sonnet 5 · medium — **RUNS 2nd**)*

```
You are `build sound` on branch HARRYDAKS of the Tumbang Preso repo. Model: Sonnet 5,
effort medium.

Read docs/Agent_Prompts.md end to end first, then docs/Design.md and docs/HUMAN.md
(the recording brief the team records against). Obey HOW TO RUN A LANE, THE REACHABILITY
RULE and the COMMIT AUTHORSHIP rule exactly.

You own systems/audio_manager.gd, assets/audio/**, default_bus_layout.tres, the audio
rows of ui/settings_panel.gd, and docs/HUMAN.md.

THE PROBLEM: this game has 34 SFX and two ambience beds, and NO MUSIC AT ALL.
audio_manager.gd applies a volume to a `Music` bus that plays nothing. Music and Sound
Design is 10% of the final score on its own and it is the cheapest 10% on the board.
The pivot to four-player tumbang preso also created five new events that are completely
silent.

YOUR WORK, in this order:

1. DYNAMIC OST. Three beds minimum: menu, match, and an intensity lift for the last 15
   seconds of a round. Cross-fade rather than cut. The match bed must survive four
   rounds without becoming irritating — that is 6 minutes of continuous play, so favour
   a loop with variation over a short hook.

2. ROUND AND MATCH COUNTDOWNS. The 3-2-1 before a round (hud.gd already calls
   show_countdown_tick), the round-end, the intermission, and the match-end. These are
   the beats a spectator uses to follow the match, so they must cut through the bed —
   duck the music under them rather than hoping they are loud enough.

3. VOICE OVER. Wire what the team has recorded against HUMAN.md. Handle the repetition
   problem: a line that fires on every tag will be heard 20 times a match. Pools with
   no-repeat-last, and a cooldown per line category.

4. THE FIVE SILENT EVENTS this pivot created. Each has a signal or a call site already:
     - the TAG landing            RoundManager.attacker_tagged
     - the SHOVE connecting       CharacterBase._apply_shove
     - the RESET CHANNEL completing  RoundManager.lata_restored
     - a SLIPPER landing          Slipper._apply_landed
     - a SCORE award              MatchManager.score_changed (carries the reason string:
                                  LATA DOWN / TAG / SABOTAGE / DEFENSE)
   ⚠️ DEFENSE fires every single second of every round. It must NOT get a sound.

5. THE MIX. Master / SFX / Music already have sliders in settings_panel.gd and route
   correctly. Balance the three buses against a real match, not against a menu.

⚠️ YOU FIRE FROM FILES YOU DO NOT OWN. A score callout triggers from round_manager.gd
and a menu stinger from scripts/ui/** — both other lanes' files. DO NOT EDIT THEM.
Expose what you need on AudioManager and FILE the trigger onto the owning lane's
§ CHECKLIST, per § IF YOU FLAG IT, FILE IT. A voice line with no trigger is filed, not
forced.

Verify by running a real match with audio and listening to it, not by checking that a
stream loaded. Tick your own boxes in § CHECKLIST §4 and append to § LOG in the same
commit as the work.
```

### 🎨 `build model` — the two props, and the play area *(Opus 5 · medium — **RUNS 1st**)*

```
You are `build model` on branch HARRYDAKS of the Tumbang Preso repo. Model: Opus 5,
effort medium.

Read docs/Agent_Prompts.md end to end first, then docs/Design.md and
docs/Art_Direction.md. Obey HOW TO RUN A LANE and the COMMIT AUTHORSHIP rule exactly.

You own character_roster.gd's CANS / SLIPPERS tables, the visuals inside
scenes/objects/**, assets/models/**, tools/models/**, tools/maps/** and
docs/Art_Direction.md.

TWO THINGS ARE OUT OF SCOPE AND BOTH WERE TRIED AND REVERTED. Read
"WHY BLENDER WAS DROPPED" in CHECKLIST 5 before you do anything.

  * NO BLENDER. Not the app, not the MCP tools, not a .glb round trip. The repo
    already has its own mesh pipeline and it is GDScript.
  * DO NOT TOUCH THE CHARACTERS. All twelve rigs stay exactly as they are. Do not
    cut the roster, do not edit a .glb, do not touch colormap.png, the person_*.tres
    palettes or generate_person_palettes.py. ROSTER changes only to drop the dead
    `ability` key.

THE PIPELINE YOU ACTUALLY USE:

    godot --headless -s tools/models/generate_all.gd

  tools/models/generate_all.gd + obj_writer.gd build every generated mesh in
  assets/models/ procedurally - lata.obj and tsinelas.obj included, today. You add or
  rewrite a `_build_*()` there and re-run it. Read obj_writer.gd's header first.

  ITS ACCEPTANCE TEST IS DETERMINISM: run the generator twice and `git status` must be
  clean after the second run. A generator that rolls dice or iterates a Dictionary
  makes every future model commit unreviewable noise.

  Look at what you made, on a turntable, without launching a match:
      godot --path . res://tools/models/preview.tscn -- --model=res://assets/models/lata.obj

THE HUMAN PROVIDES 2D DRAWINGS of the tsinelas and the lata. These are their own
designs, not drawn over anything. Ask for them before you start if they are not in
docs/refs/ already, and do not invent a design to fill the gap.

YOUR WORK, in this order:

1. THE PLAY AREA IS TOO SMALL. Do this first - it is the item the human raised twice.
   Expand the Defender's allowed area, adjust both maps' meshes, and redraw the chalk
   on BOTH maps so the play area and the throwing line demarcate the new boundary.
   tools/maps/floorcheck.py regexes CONFINEMENT_RADIUS out of character_base.gd and
   both map builders draw the chalk from it - that const is `build fair`'s file (2.2 is
   the same number), so agree the value with them or file it, and move the maps and the
   chalk yourself.

2. THE SLIPPER - new mesh from the drawing, in generate_all.gd. It is the object the
   game is named after and it is thrown at every throw. Its origin MUST sit at its
   centre of mass: it spins on two axes in flight (SPIN_SPEED_DEG 900 about its long
   axis, TUMBLE_SPEED_DEG 520 end over end) and an off-centre origin wobbles like a
   bent wheel.

3. THE LATA - new mesh from the drawing. Its silhouette has to read as a can from
   across the arena, at spectator camera distance, WHILE LYING ON ITS SIDE AT 88
   DEGREES. That is a gameplay requirement, not a look: a crowd that cannot tell a
   fallen lata from a standing one cannot follow the round.

4. SIZES MAY CHANGE, AND THE PHYSICS MOVES WITH THEM. The old fixed-size rule is
   lifted. Scale either prop to match the drawing - then update Slipper.HIT_RADIUS,
   Slipper.REST_HEIGHT and the lata's body and hurtbox radii to match the new mesh IN
   THE SAME COMMIT, and move the same numbers in Design.md. A mesh and a hitbox that
   disagree is the bug this clause exists to prevent.

5. TINT-FRIENDLY, AND LOW POLY. lata.gd and slipper.gd walk every MeshInstance3D and
   write albedo_color from the roster entry's `tint`, so a baked multi-colour texture
   fights them. And keep both strictly low poly, matching the rest of the game: no
   subdivision, no smooth shading, flat faces only.

6. RE-AUTHOR CANS / SLIPPERS against the new meshes, and drop the `ability` key from
   every entry in all three tables - scripts/abilities/** is deleted and the field is
   inert. Leave ROSTER otherwise alone.

7. SOFT STATS - LEAVE THEM ALONE. `build fair` 2.8 decides whether lata and tsinelas
   skins carry bilis/lakas/tatag and it runs AFTER you. Carry the existing `traits`
   dictionaries across UNCHANGED even though nothing reads them yet, and do not invent
   values to match your new meshes. Note in the LOG that you preserved them.

8. SWEEP THE ORPHANS: lata_dent1..3.obj and the dent generator in generate_all.gd
   describe a mechanic that no longer exists.

VERIFY WITH SCREENSHOTS, IN GODOT. A prop that looks right on the preview turntable and
wrong at arena distance under the toon pass is the failure mode here.
tools/harrydaks_shot.tscn renders a live match. Use the PLAIN Godot exe for anything
that renders - --headless has no rendering device and every capture comes back blank.
--headless is still correct for `-s generate_all.gd` and for `--import`.

SHOW THE HUMAN RENDERS OF THE MAP, THE CANS AND THE SLIPPERS before you call any of it
done, and act on the notes rather than defending the build.

Tick your own boxes in CHECKLIST 5 and append to the LOG in the same commit as the work.
```

---

## REMOVED IN THE HARRYDAKS PIVOT

**Recorded rather than silently dropped, because a deletion nobody wrote down is a
deletion the next lane re-derives from a dangling comment.** The mechanics side of this
is `Design.md` §12; this section is about the *board*.

| Lane | Was | Why it is gone |
|---|---|---|
| 💥 `build abil` | the five object verbs — Can-Smash, Can-Dash, Ground Smash, and the roster specials | **Deleted outright.** `scripts/abilities/**` no longer exists. There are no abilities to build. |
| 📋 `build rules` | the match format and deleting Option A | **Absorbed into `build core`,** which replaced the format wholesale. Its fairness finding survives as `Design.md` §1. |
| 🎮 `build mech` | the rules of the game | **Superseded by `build core`,** closed above. |
| 🔊 `build voice` | the recording brief, and wiring the voice that comes back | **Merged into `build sound`.** It was split out because it blocked on humans recording; `docs/HUMAN.md` is written and the team can record against it today, so the remaining work is plumbing and does not need its own lane. |
| 👁️ `build spec` | spectator | **Closed, not deleted.** Spectator was kept whole on human instruction and needs no further work. |
| 🥊 `build feel` | contact, knockback and readability | **Merged into ⚖️ `build fair` 2026-07-31** as §2.11–§2.16. They shared `character_base.gd`'s contact block, `slipper.gd`'s flight and `lata.gd`'s topple, and they were the same judgement made twice — a value and the feedback that sells it. |
| 📦 `build ship` | exports and the submission build | **Demoted to § CHECKLIST §8, a checklist rather than a lane.** The board already described it that way; a cold-start session for three mechanical items is the overhead the five-lane cut exists to remove. |

**Also deleted from the board:** the rubric's "do not improve the objects-are-players
thesis" clause (see § THE RUBRIC), the § SALVAGE table (replaced by § WHAT IS ALREADY
DONE, because most of its rows described deleted code), and the two-ruleset discussion,
which had already been resolved before this branch.

---

## LOG

### 2026-07-31 · 🎮 `build core` · §0 · branch `HARRYDAKS`

**The pivot.** Branched from `feature/objects-overhaul-v2` at `2228579`.

**What the human asked for, in their words, across the session:** *"we're making the
game way simpler basically, there were so many skills and shit earlier, it was too
complicated and far from tumbang preso"* · *"drop the irrelevant mechanics now like bump
and shit and slipper being a character and can being a character, but keep spectator"* ·
*"you can keep map too and physics and net and ui models and shit, there's so much you
can keep just tweak"* · *"we will fix the ai as well but put that in the end of agent
prompts lane, we will focus on making multiplayer first then single player next time"* ·
*"build a working multiplayer game with updated mechanics now"*.

**Two commits.**

**1 — `Rebuild the match as four players, one taya, and a can that is just a can`.**
Deleted `scripts/abilities/**` (8 scripts, 10 resources), `carriable.gd` (1 635 lines),
`hitbox.gd`, `hurtbox.gd`, `throw_profile.gd`, and the 3 172-line `ai_controller.gd`.
Rewrote `character_base.gd`, `carrier.gd`, `match_manager.gd`, `round_manager.gd`. Added
`scripts/objects/lata.gd` and `slipper.gd`. Reworked `main.gd`'s seat, spawn and reset
paths for four Persons plus world props.

**Three decisions worth recording:**

* **Contact resolves by distance on the host, in all three places** (tag, slipper
  contact, reset ring) rather than through `Area3D` overlaps. `hit_probe` had already
  measured the alternative: 16 of 36 overlaps did not land, and the misses were split by
  TARGET. Sixteen distance checks a frame is cheaper than one correct networked overlap
  and it can only happen where the score is written.
* **The confinement clamp needed no work at all.** `_is_confined_to_base()` already read
  "the lata, and the Person on the can side"; deleting the lata leaves "the Defender",
  which is exactly the Defender's Box. One line changed.
* **Spawns are derived from `CONFINEMENT_RADIUS`, not read from map markers.** "Outside
  the box" is the rule, and a marker drifting half a metre inside it would spawn an
  Attacker VULNERABLE on frame one — which reads as a rules bug, not a map bug.

**The shove's impulse number was salvaged rather than re-derived.** The GDD asks for 1 m
of knockback; the deleted power bump was tuned to 7.75 m/s against `FRICTION` 30, and
`distance = v²/60` — so 7.75 already *was* one metre on this friction model.

**2 — `Give players a name, put the HUD back on theme, and stop the screen going red`.**
Every item in this commit was found by **looking at the first rendered frame**, not by
reading code:

* The whole arena was washed red. The knockdown vignette was a persistent state driven
  by the lata, which is down for most of a round. A full-screen `ColorRect` left on for
  forty seconds reads as a broken renderer, not as feedback. Now a 0.45 s pulse peaking
  at 0.45 alpha.
* The scoreboard rendered on the stock theme — a flat white box beside a wood-and-amber
  timer — because the two team panels were painted by `set_round_display()` calling
  `_style_team_card()`, and that call went with the two-team layout. 🧑: *"ugly ui btw,
  not even same theme wtf is that white shit"*.
* Two stamina bars, forty pixels apart, drawn from the same call. The HUD's own is gone;
  `YouCard` keeps it and now carries the FATIGUED read.
* The YOU card repeated a score the scoreboard already showed. 🧑: *"why are there points
  here, it's already up top it feels redundant"*.
* Player names end to end, on the identify packet and as a replicated property.
* The debug bar had been printing `TeamAPerson (missing)` over a live match.

⚠️ **The character screen's LATA and TSINELAS tabs picked nothing for exactly one
commit,** and that is the origin of the new half of § THE REACHABILITY RULE. They now
tint the real props.

**Verified:** clean `--headless --import` (no parse errors); a 130 s headless match runs
a full round, the intermission and the rotation into round 2 with nothing on stderr; a
1600×900 render off `tools/harrydaks_shot.tscn` shows the HUD over live play, with the
AI retrieving a slipper, leaving the box, throwing, and scoring a knockdown (+100 to the
thrower, +10/s passive to the taya).

⚠️ **NOT verified: anything networked.** No two-peer session has been run on this
branch. Filed to `build ui` §1.8.

⚠️ **The single biggest known risk is `build fair` §2.1.** Passive defence pays 900 a
round uncontested against 100 for a knockdown. It is very probably wrong and it is the
first number anybody should measure.

### 2026-08-01 · 🔊 `build sound` · §4 · branch `HARRYDAKS`

**Music, VO wiring, and the pivot's silent SFX.** The human team is now composing the
soundtrack directly (`docs/HUMAN.md` § TABLE D, decided 2026-07-31) rather than this
lane synthesising beds — the brief for that shift was written before this session and
this session is the first to receive actual files against it: two masters, `Rounds`
(the match bed) and `Main Menu and Character Select` (the menu bed), landed mid-session
and are now integrated and cross-fading. Both were MP3 data saved with a `.wav`
extension — renamed to `.mp3` rather than reconverted, since Godot imports MP3 natively
and re-encoding a delivered master loses quality for no reason.

**Every new hook is an autoload signal subscription or a call made from inside
`AudioManager` itself** — `RoundManager`/`MatchManager` are autoloads, so
`play_music()`/`play_vo()`/the duck/lift logic all reach round starts, tags, knockdowns,
score awards and match end without a single line touched in `scripts/ui/**`,
`main.gd`, `character_base.gd`, `lata.gd` or `slipper.gd`. Where an event genuinely had
no reachable hook (a slipper's clean-miss landing), it is filed to `build fair` as
§2.17 rather than forced by editing a file outside this lane's row.

**Six previously-silent call sites turned out to be a naming problem, not a missing
feature.** `character_base.gd`, `lata.gd` and `slipper.gd` already called
`AudioManager.play_at()` with names (`hit_body`, `bump_swing`, `can_knockdown`,
`reset_complete`, `pickup`, `throw_release`) that had never been registered in
`SFX_NAMES` — the pivot wired the call sites and moved on. Two of those six are reused
audio, not new synthesis: `bump.wav` and `dash.wav` were generated for the deleted 2v2
bump and dash mechanics and have had no caller since — a body-on-body thump already
existed and needed nothing but a second name pointing at it.

**`docs/HUMAN.md` had drifted with the mechanics it predates by about a day.** Its Table
A/B were written before this exact session but described the out-of-circle countdown and
team framing the HARRYDAKS pivot deleted (`lata_out`/`lata_safe`/`lata_last`,
`win_defence`/`win_offence`, `bangon`, `balik`). Struck and replaced with the events that
are real now (`tumbang`, `lata_restored`, `match_win`, `match_draw`) rather than left to
be recorded against a game that no longer exists.

**Verified:** `--headless --import` reimports the whole project with no Parse Error,
including the two new `.mp3` masters and three newly-synthesised `.wav`s.
`tools/audio/generate_sfx.py` ran clean (its own `_write()` asserts against pure silence
and head-padding on every file, so a clean run is a real check, not just "no exception").

⚠️ **NOT verified: any of it by ear.** This session has no audio output device to
confirm against, and nobody has run a live rendered match with sound during it — every
`[~]` in § CHECKLIST §4 says so explicitly rather than claiming an `[x]` for a stream
that merely loaded. Checklist item 5, the mix pass ("balance the three buses against a
real match"), could not be done for the same reason and is the first thing to actually
listen to.

⚠️ **VO is fully wired and completely silent** — `assets/audio/vo/` is empty. That is
expected, not a defect: `docs/HUMAN.md` is the recording brief and nobody has recorded
against it yet. The pool activates per line the moment a file lands at
`vo_<id>_<name>.wav`, no code change required.

### 2026-08-01 · 🔊 `build sound` · §4 · branch `HARRYDAKS` (follow-up)

**Four bugs reported directly from play, after the first two commits landed.** Three
were music sequencing, one was a HUD bug outside this lane's paths.

* **The menu bed started under the intro video.** `AudioManager._ready()` called
  `play_music("menu", 0.0)` unconditionally at autoload boot, which runs before
  `SplashScreen` even starts its clip — so the bed was audible under the boot video,
  ahead of `splash_screen.gd`'s own `AudioManager.play("boot_sting")`.
* **The match bed started a full countdown late.** `MatchManager.round_started` — the
  only signal this lane had hooked — does not fire until AFTER the pre-round 3-2-1-GO
  countdown finishes (`main.gd`'s ready-phase coroutine calls `begin_next_round()` last).
  So the menu bed played straight through the entire countdown and only handed off on
  "GO!", which reads as late by design once you look at the call order.
* **Nothing brought the menu bed back except `match_won`.** A network-disconnect
  bounce, the match-result screen's own "back to menu" button, and a solo quit all
  return to `MainMenu.tscn` without ever emitting `match_won` — so the match bed kept
  playing over the main menu on every one of those paths.

**All three fixed by watching state instead of chasing every path that can produce
it.** `_poll_main_menu_edge()`, called every frame from `AudioManager._process()`,
checks `get_tree().current_scene is MainMenu` — `MainMenu` is `main_menu.gd`'s own
`class_name`, so this reads a type off a scene this lane does not own without writing a
line into it — and fires only on the false→true edge. That is simultaneously the splash
hand-off, the "return from a match" case for every path that produces it, and needs no
signal from `SplashScreen`, `NetworkManager` or `match_result.gd` individually. The
countdown fix hooks `play()`'s own `sound_name == "countdown_tick"` — already unique to
one call site (`hud.gd::show_countdown_tick`) — the same pattern the music duck already
used.

**The fourth bug is not this lane's file.** "Username doesn't show if you're taya" is
`hud.gd::set_round_display` printing `"TAYA: P%d"` off the raw seat number instead of
`display_name()`, one line above a scoreboard row that gets this right. Filed to
🖥️ `build ui` § CHECKLIST as 1.10 rather than fixed here — `hud.gd` is not in this
lane's § PATHS row.

**Verified:** `--headless --check-only` clean, no Parse Error, both before and after
these changes. **Unverified by ear** — same standing caveat as the first two commits
this session; nobody has run a rendered match with sound during it.

### 2026-08-01 · 🎨 `build model` · §5 · branch `HARRYDAKS` — **PLAN OVERHAUL, NO ART SHIPPED**

**This session produced no asset. It produced a corrected plan, and the correction is
the deliverable.** Recording it in full because the failed approach was expensive and is
the kind of thing a cold-start lane would cheerfully try again.

**What was attempted.** The lane as written called for editing the twelve Kenney rigs in
Blender via MCP against the human's four character drawings, and cutting the roster to
four. That was built: four rigs re-modelled (garments re-UV'd by height band, faces
rebuilt to one shared design, limbs boxed, hair rebuilt from block tufts), a print atlas
painted into the unused top half of `colormap.png`, and three generators to drive it.
It survived its own contract tests — 32 clips, 7 bones, 7 vertex groups, no unweighted
vertices, ~900 tris each.

**The human rejected it, repeatedly and correctly.** 🧑: *"what the fuck did u make. it
does not look anything like my drawing"* · *"none of your drawings look like mine"* ·
*"this is supposed to be low poly as well... it was very uncanny earlier"* · and finally
*"i give up holy shit · overhaul the model plan · remove blender and shit · we wont
remove the characters anymore"*.

**All of it is reverted.** The twelve `.glb` files, `colormap.png`, the `person_*.tres`
palettes and `generate_person_palettes.py` are back at their committed state; the four
Blender-era generators are deleted. The only thing kept is `docs/refs/`, the human's own
drawings, which are now the reference for whatever comes next.

**Why it failed, structurally** — the full record is § CHECKLIST §5's *WHY BLENDER WAS
DROPPED*. In short: this repo already has a deterministic procedural mesh pipeline
(`tools/models/generate_all.gd` + `obj_writer.gd`, run by `godot --headless -s`) that
builds `lata.obj` and `tsinelas.obj` today, so Blender was a second pipeline for a job
the first one does; the glTF round trip ships custom split normals that smooth-shade
every flat face, which is exactly the *"bumpy and unnatural"* read and is invisible in
Blender's own viewport; and editing someone else's topology meant a bespoke fix for
every one of Kenney's quirks (garment UV regions that match no drawing, three-box arms
with a lump at each wrist, chamfered limbs that any hem cuts through mid-polygon).

**⚠️ THE ONE PROCESS FINDING WORTH MORE THAN THE ART.** Two agents were running on this
branch at once, and the other one repeatedly reverted files under this session —
`generate_person_palettes.py` twice, `colormap.png`, eight `.glb` files, and both large
edits to this document. A black chest on a rendered character was chased as a UV bug for
a full pass before the cause turned out to be the atlas being rolled back underneath it.
**One lane at a time is not a style rule on this board, it is the thing that makes a
render trustworthy** — see § HOW TO RUN A LANE, which already said so.

**What the lane is now:** the lata, the tsinelas, and the play area. No Blender, no
character work. The play-area item is first because the human raised it twice and it is
the only one of the three that is not blocked on a drawing.

⚠️ **NOT verified, because nothing was built:** no Godot render, no `--import`, no
determinism run of `generate_all.gd`. No § CHECKLIST box is ticked.
