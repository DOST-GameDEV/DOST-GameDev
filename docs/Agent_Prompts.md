# Agent Prompts — the pipeline, the checklist, the log

**Branch `feature/objects-overhaul-v2`, written 2026-07-31.** Replaces every earlier
version of this file. Nothing from the 3 289-line lane board or the nine-agent sequential
board survives here — those prompts described a world that no longer exists and they are
deleted, not archived.

**What this branch is.** `feature/objects-overhaul` was built in one uncontrolled session.
The *code* it produced is good and is carried here in full. The *process* is discarded and
replaced by the seven `build xxx` lanes below, run in order. Read § SALVAGE before
you assume anything is unbuilt: most of the checklist is already written and almost none of
it is measured.

**The goal is a recordable gameplay video.** Everything on this board serves that.

---

## HOW TO RUN A LANE

1. New chat. **Set the model and effort in the client before pasting** — the prompt names
   them, it cannot set them.
2. Paste that lane's block from § THE LANES verbatim, first message, nothing else.
3. It finishes → it ticks its own boxes in § CHECKLIST and appends to § LOG **in the same
   commit as the work**.
4. Only then start the next lane. **One lane at a time, in board order.**

**Every lane, no exceptions:**

* Branch from `feature/objects-overhaul-v2`. No `application/config/version` bump.

> ### 🚨 COMMIT AUTHORSHIP — THE ONE RULE WITH NO EXCEPTIONS
>
> **Every commit is authored by `M4tyu633 <matthewtlabrador@gmail.com>` and nobody else.**
>
> * **NO `Co-Authored-By:` trailer. Ever.** Not for Claude, not for an agent, not for a
>   model name, not "on behalf of".
> * **No "Generated with", no 🤖 line, no tool attribution** anywhere in the subject or
>   body.
> * The message says what changed and why. It does not say who or what wrote it.
> * The repo's `--local` identity is already set to that name and address. Verify before
>   your first commit:
>
>   ```bash
>   git config --local user.name && git config --local user.email
>   ```
>
> * Check yourself after committing — `git log -1 --format='%an <%ae>%n%b'` — and fix it
>   with `git commit --amend --reset-author` before you push if it is wrong.
>
> This is a competition entry. It is submitted as one person's work and the history has to
> read that way in every one of its commits.
* `docs/Design.md` is the balance source of truth. **Move a number in the code → move it
  in `Design.md`, same commit.** Two numbers disagreeing is a bug with your name on it.
* Read before you write: `scripts/characters/`, `scripts/abilities/`,
  `scripts/systems/`. Never speculate about a file you have not opened.
* **You own your paths and only your paths.** Reading anything is fine; writing outside
  your row in § PATHS is not. Sequential order is what replaces the old file mutex.
* **You decide HOW.** Every value on this board is a starting point you may overrule —
  say so in § LOG with the reasoning. You do not ask permission for an implementation
  detail; you record the decision.
* **Do not spawn subagents.** Every lane does its own work in one focused session.
* Godot is not on PATH (`docs/README.md` has the invocation). `--check-only` grepped for
  `Parse Error` is the one cheap real gate. Probes run as `.tscn`, never `-s`.
* **Never claim a verification you did not perform.** `[x]` needs a named probe, a
  screenshot, or a log. Everything else is `[~]`.

> ### 📌 IF YOU FLAG IT, FILE IT — hand every finding to the lane that owns it
>
> **A problem you noticed and only wrote about in § LOG is a problem nobody is going to
> fix.** The log is read once, by a human, after the fact; the checklist is what the next
> lane actually works from.
>
> So whenever you find something outside your own paths — a bug, a stale string, a number
> your change invalidated, a claim you could not verify, a probe that already fails —
> **add it as a numbered `- [ ]` item to that lane's own § CHECKLIST section**, at the end,
> under a bold line saying who filed it and when:
>
> ```markdown
> **Filed by `build mech` 2026-07-31:**
>
> - [ ] 4.8 **`STRANDED` is a new status row and 4.1 must draw it.** …why it matters…
> ```
>
> Rules for a filed item:
>
> * **It goes to the lane that owns the FILE**, per § PATHS — not to whoever is nearest.
> * **State what you observed, not what to type.** The owning lane decides HOW; that is
>   their row and their call. Give them the fact, the file, and why it matters.
> * **Include the evidence** — the measured number, the probe name, the grep, the line.
>   "Might be worth checking" is not a filed item.
> * **Ticking is still theirs alone.** You add the box; you never tick a box outside your
>   own section.
> * **File it even if you think it is small**, and file it even if you suspect the owning
>   lane already knows. A duplicate costs one line; a dropped finding costs a session.
>
> This is not optional bookkeeping — it is how a sequential board with one writer per file
> stays honest. You are the only agent who will ever see what you just saw.

### ⚠️ THE REACHABILITY RULE — read this before you build any UI

**A feature that a player cannot reach from the menus does not exist, and does not tick a
box.** This project has already shipped systems that only a command-line flag could start.
That is the failure mode this rule closes.

Whatever you build, you also **wire into the screen a player actually meets it on**, in the
same commit:

* Name the entry point before you write the feature — which screen, which control, what it
  is called on screen.
* It must be **operable with a mouse and reachable by keyboard focus**, and it must sit in
  the existing focus order rather than beside it.
* It must survive a real path, not just the scene opened alone: Single Player *and*
  Multiplayer where both apply, host *and* client.
* A debug flag, an autoload variable or a console command is **not** an entry point. It may
  exist alongside one.
* Render the screen and look at it. "The control is added to the tree" is not the claim;
  "I can see it and it does the thing" is.

**Worked example — spectator, which is 👁️ `build spec`, the whole of lane 2.** The camera
exists and today only `--spectate` starts it. It needs a **SPECTATE toggle button in the
lobby**:
visible on the multiplayer lobby *and* on the pre-match setup screen, off by default,
showing its own state when toggled, releasing the seat, and carrying that choice into the
match.
`match_setup.gd` already builds one in code and it has never been rendered — start there,
finish it, and put one in `multiplayer_setup.gd` too.

---

## EXECUTION ORDER

Mechanics → Visuals → Physics → Fairness. **A lane may not start until the one above it has
committed.**

⚠️ **One deviation, taken on human instruction 2026-07-31:** 👁️ `build spec` is a
Visuals-phase lane running at position **2**, ahead of the rest of Mechanics, because the
spectator camera is needed for filming as soon as possible. It is safe to move because it
depends on nothing else on this board and nothing depends on it. Recorded here rather than
made silently. The rest of the order stands.

| # | Lane | Model · effort | Owns | Why this model |
|---|---|---|---|---|
| **1** | 🎮 **`build mech`** | **Opus 5 · high** | the rules of the game | Deletes the defence's only win and replaces the whole win-condition set. Novel rule design under ambiguity, no lookup-able answer, and getting the feel wrong here costs the video. |
| **2** | 👁️ **`build spec`** | **Sonnet 5 · high** | spectator, and the lobby toggle that reaches it | **Pulled forward on human instruction — needed as soon as possible.** Split out of `build ux` because it depends on nothing else on the board and nothing depends on it. High, not medium: the seat and ready-gate exclusion is a cross-peer race, and "works solo" is exactly how it has failed so far. |
| **3** | 💥 **`build abil`** | **Sonnet 5 · high** | the five object verbs | Exact radii, durations and host-side resolution against a spec that already exists. High, not medium: a shockwave that resolves on the wrong peer looks perfect solo and does nothing on LAN. |
| **4** | 🖥️ **`build ux`** | **Sonnet 5 · high** | every other screen, the net teardown | Three of its items are races that only reproduce across peers. High because "it works on my machine" is the exact failure mode. |
| **5** | 🎨 **`build model`** | **Opus 5 · medium** | the lata and tsinelas classes, their models and their names | Upgraded 2026-07-31: it now authors real geometry, sets the roster size and names it. *"Does this silhouette read as a sardine tin from across a street, and is that name right in Filipino?"* is taste and cultural specificity — the one thing Sonnet was picked for not needing. Medium, not high: the difficulty is judgement per object, not depth on any one. |
| **6** | 🥊 **`build phys`** | **Sonnet 5 · high** | contact, knockback, ragdoll read | Executing against measured targets with a documented authority trap list. |
| **7** | ⚖️ **`build fair`** | **Opus 5 · xhigh** | every number, the AI | **LAST. ALWAYS.** The only lane allowed to move a shipped number, and the only one that can judge whether the objects are actually fun. Being wrong here costs the submission. |

---

## SALVAGE — what already exists on this branch

Do not rebuild these. Read them, then improve, verify, or overrule.

| System | File | State |
|---|---|---|
| Tag / tap-out **deleted** | `person_action.gd` gone, `hitbox.gd` win branch gone | grep-verified |
| Bump meter, 1.35 s | `character_base.gd` `BUMP_*` | written, displacement never measured |
| Stamina + sprint, `SPEED` 4.6 | `character_base.gd` `STAMINA_*` | bindings measured, drain unmeasured |
| Throw lock 1.25 s | `carrier.gd` `THROW_LOCK_TIME` | `input_probe` asserts it |
| Long-throw bonus + 5 s punish | `carriable.gd::host_throw`, `hitbox.gd` | written |
| Can knockback ×2.6, `DOWNED_MAX_TIME` 2.0 | `character_base.gd` | ceiling measured (`mech_probe`); ×2.6 still only measured off a *tap* (0.951 m). ⚠️ The ceiling has one exception now — §1.9 |
| Out-of-circle countdown + recovery stacks | `round_manager.gd` `CAN_OUT_*` | **measured end to end by `mech_probe` 2026-07-31** — clock, 0.75 s stack, and the win at zero. Option B only now. **This is the primary win condition** |
| Can-Smash / Ground Smash | `scripts/abilities/prop_smash.gd` | written, no probe fires one |
| Can-Dash, self-launch | `character_base.gd`, `carriable.gd` | written |
| Spectator camera, seat −1 | `scripts/systems/spectator_camera.gd`, `--spectate` flag | boots, single-peer only |
| Trajectory preview | `scripts/systems/trajectory_preview.gd` | shares the real solve; nobody has looked at the line |
| Status stack + countdowns | `scripts/ui/hud.gd` | renders, no probe reads a row |
| Prop attachments + hanger | `character_visual.gd` `PROP_ATTACHMENTS` | **never rendered — no screenshot of any class exists.** And the base meshes under them are placeholders: one `lata.obj` and one `tsinelas.obj` for every class. See §4 |
| Tsinelas ×1.60 + capsule ×1.28 | `character_visual.gd`, `_COLLISION_BY_ROLE` | capsule measured by `settle_probe`, look unrendered |
| MAX POWER row | `character_select.gd` | `ui_layout_probe` 196/196 |
| AI rewritten for the new verbs | `ai_controller.gd`, +489 lines | parses, runs 70 s clean, **behaviour unmeasured** |

~~**Known gap, not built at all:** the lata may currently self-right anywhere.~~ **Built
2026-07-31 by `build mech`** — `self_right()` refuses off the circle, and three things
fell out of it (the seal-on-hit deleted, the reset channel's steps reordered, the channel
re-priced to 1.8 s). `Design.md` §5.1.1, and § LOG.

**Known conflict:** the brief says Can-Smash has a **3.0 s** base cooldown; the salvaged
code ships **8.0 s**. `build abil` decides and records which, in `Design.md` §11.

---

## PATHS — one writer per file

| Lane | Writes |
|---|---|
| 🎮 `build mech` | `characters/character_base.gd` · `carrier.gd` · `carriable.gd` · `hitbox.gd` · `hurtbox.gd` · `throw_profile.gd` · `systems/round_manager.gd` · `match_manager.gd` · `Design.md` |
| 💥 `build abil` | `scripts/abilities/**` · the ability hook sites in `character_base.gd` · `Design.md` §5.3/§6 |
| 👁️ `build spec` | `systems/spectator_camera.gd` · `ui/match_setup.gd` · `ui/multiplayer_setup.gd` · the seat/identify path in `network_manager.gd` · `game_launch.gd` · `main.gd` · the no-character branches of `ui/hud.gd` |
| 🖥️ `build ux` | `scripts/ui/**` · **`systems/camera_rig.gd`** · `trajectory_preview.gd` · `network_manager.gd` · `settings_manager.gd` · `tools/ui/**` |
| 🎨 `build model` | `character_visual.gd` · `character_nameplate.gd` · `systems/character_roster.gd` `CANS`/`SLIPPERS` tables · `scenes/characters/visuals/**` · `assets/models/**` · `tools/models/**` · `Art_Direction.md` |
| 🥊 `build phys` | `character_base.gd` movement/collision block · `carriable.gd` flight · `tools/phys_probe.gd` · `settle_probe.gd` · `aim_probe.gd` |
| ⚖️ `build fair` | **any number in any file** · `systems/ai_controller.gd` · `tools/ai_probe.gd` · `hit_probe.gd` · `round_probe.gd` |

`character_base.gd` is touched by three lanes. Sequential order is the lock: `build mech`
writes it first and completely, `build phys` takes only the movement and collision block
after, `build fair` moves numbers last.

**The two cameras are split.** `spectator_camera.gd` is 👁️ `build spec`'s (§2);
`camera_rig.gd`, the gameplay camera, is 🖥️ `build ux`'s. ⚠️ **The camera directive is not
negotiable:** Person → first person, Prop → third person, derived from `is_person` at
`_ready()`, no toggle, no export, no per-map exception. The spectator is not an exception to
it either — it is a separate camera for a unit that has no body, not a third mode on the
rig, which is why the two files can sit in different lanes at all.

**`build spec` and `build ux` share four files** — `match_setup.gd`,
`multiplayer_setup.gd`, `network_manager.gd` and `hud.gd`. `build spec` runs first and takes
only the seat, the toggle and the no-character branches; `build ux` takes everything else
afterwards and must read what `spec` left before editing them.

---

## CHECKLIST

`[x]` = built **and verified**, and say by what. `[~]` = built, unverified, and say what
specifically is unverified. Tick only your own section.

### 1 · 🎮 `build mech` — Mechanics *(Opus 5 · high)*

**The named probe for this section is `tools/mech_probe.tscn` — 16/16 checks, twice.**
It is a new file; § PATHS gives this lane no `tools/` row and writing to another lane's
probe would have broken one-writer-per-file.

Defender
- [x] 1.1 Tap-out / tag mechanic gone entirely, including its round-win branch — grep: no `person_action.gd`, no `report_round_win` in `hitbox.gd`
- [~] 1.2 Bump power meter on left-click, mirroring the attacker's throw meter, **1.5× the attacker's charge time to fill** — 1.35 s, kept. **Unverified: nobody has watched the meter fill.**
- [~] 1.3 Click = minor bump, mini knockback, no stun — the `nudge` branch is read and correct; **unverified: no probe releases a tap at a standing target and checks no stagger followed**
- [x] 1.4 Full hold = powerful bump: **~1 m** knockback, **drops the attacker's tsinelas far away**, short hit stun + movement penalty — the "far away" half was missing and is now the punt. **Measured 3.13 m, twice, from a pinned origin**
- [~] 1.5 Wind-up is visible on **every peer** — the broadcast is there; **unverified: never observed on a second real peer**
- [~] 1.6 Stamina: sprint is a finite resource, base speed cut — **unverified: drain and regen never measured**

Attacker
- [x] 1.7 Throw cooldown on pickup — 1.25 s. `input_probe` 11/11: a held button charges to 0.627 after the lock rather than dying. ⚠️ The 1.25 s *duration* is a reasoned choice, not a measurement
- [~] 1.8 Throws from **behind the throwing line** are stronger; max-power on the taya = **5 s** stun — written, and **unverified end to end: no probe has landed one**

Lata
- [x] 1.9 **The lata may only stand up while on the circle** — built. Measured: held down 3.0 s off the circle against a 2.0 s ceiling, stands within 6 frames of arriving home, a Person at the same spot is unaffected
- [~] 1.10 High knockback susceptibility: a solid hit displaces it ~1 m — a *tap* bump measured **0.951 m** in passing (`×2.6` is doing what it claims), but a solid hit is not measured and **`build phys` 5.2 owns that**
- [x] 1.11 Actively fights to stay upright; **cannot be down longer than 2 s** — measured for a lata at home and for a Person. ⚠️ **One exception, by design: §1.9's stranded lata.** `Design.md` §11 states it
- [x] 1.12 Game over is the countdown, not the knockdown — measured end to end: clock runs while out, round ends at zero, win goes to the tsinelas side
- [x] 1.13 Each recovery shortens the **next** countdown by **0.75 s**, stacking **5×** to **1.25 s** — measured: a save moved the limit 3.50 → 2.75. ⚠️ The 5-stack floor is only reachable now that the channel is 1.8 s; at 2.2 it was decoration
- [x] 1.14 The defence has a real answer to a displaced lata it cannot itself move — measured: a completed channel stands a **stranded** lata up and returns it to 0.00 m from centre

### 2 · 👁️ `build spec` — Spectator *(Sonnet 5 · high)* — **RUN THIS NEXT**

> **Split out of `build ux` on 2026-07-31 at the human's request: spectator is needed as
> soon as possible.** It is genuinely independent of everything else on the board — no
> mechanic, no ability and no model depends on it, and nothing it touches depends on them.
> Small, self-contained, run it the moment `build mech` commits.
>
> ⚠️ **This runs a Visuals-phase item before the Mechanics phase finishes** (`build abil` is
> still Mechanics). That is a deliberate deviation from the fixed order, taken on human
> instruction and recorded here rather than made silently.

**The named probe for this section is `tools/spec_probe.tscn` — `--solo` 21/21, and a
two-peer `--lobby-host` / `--lobby-join=127.0.0.1` pair at HOST 15/15, twice.** A new
file, for the same reason `mech_probe` was: § PATHS gives this lane no `tools/` row.

- [x] 2.1 **A SPECTATE toggle button in the lobby** — on the multiplayer lobby *and* the pre-match setup screen, in the focus order, showing its own state, in Single Player and Multiplayer, host and client. Rendered and looked at — `ui_shot` renders of both screens, looked at. The `match_setup.gd` one was already built and added to the tree and had never been *styled*: it drew as a small grey engine-default button under four wood planks
- [x] 2.2 **Spectator mode** — free-flying camera, no physical model, clips through all geometry, flies anywhere. Entered from 2.1, not from `--spectate` — measured: not a `PhysicsBody3D`, zero `CollisionShape3D`, flew **24.02 m straight down through the road** to y = −15.02 m, and the viewport's live camera is `/root/Main/Spectator/SpectatorCamera3D`. ⚠️ **That last check is there because it FAILED**, silently, while every other one passed — see § LOG, "the camera was flying perfectly and nobody was looking through it"
- [x] 2.3 Claims no seat, excluded from the ready gate, its slot bot-filled — **measured on two real peers, twice.** The host learned the client was spectating (`is_spectator` true), the board went to `seats={1: 0}` with the client absent, `playing_peer_count` 2 → **1**, no READY tick held, the vacated seat read `TEAM A · OBJECT   · BOT`, and START MATCH went live without the spectator ever pressing anything. Solo half too: 4 units, **4 of 4** bot-held with the human's seat vacated
- [x] 2.4 Leaving and re-entering the lobby returns the seat cleanly; a spectating host still runs the match — **measured on two real peers, twice.** Un-spectating returned the client to seat **1, the one it vacated** (not "first free"), and `playing_peer_count` went back to 2. The host then spectated itself: its own flag updated (`host_game()` had frozen it), it released seat 0, and START MATCH stayed live
- [x] 2.5 The HUD is sane with no character — no null character lines, no orphaned role colour — measured: YOU card, crosshair and lata card hidden, **zero** status rows built
- [x] 2.6 It is filmable: free look, a follow-target cycle, and a speed control that makes wide shots and close shots both possible — measured: wheel 12.0 → 21.9 m/s, TAB picked up TeamAProp, the same wheel pulled the follow shot 6.5 → 2.6 m, F freed it. ⚠️ **TAB never arrived before this lane**: `Tab` is `ui_focus_next` and the GUI phase ate it before `_unhandled_input`

**Filed by `build spec` 2026-07-31 — the human's own ask, and it is NOT built:**

- [ ] 2.8 **The POV half of the human's 2026-07-31 ask.** *"spectator should be allowed to go to anywhere in the map and watch the povs of people/ai, thats why its called camera."* The first half is built and measured (free flight anywhere, through anything — 2.2). **The POV half is not.** `TAB` cycles a *third-person over-the-shoulder* follow shot at an adjustable 1.2–30 m; it does not give the watched unit its own eyes. A real POV means activating that unit's `CameraRig` for a watcher — and ⚠️ § PATHS puts `camera_rig.gd` in 🖥️ `build ux`, which is why this is filed rather than built. Note the camera directive already decides the shape: Person → first person, Prop → third person, from `is_person`, no toggle — so a Prop POV is a chase cam by law and only a Person POV is genuinely new

**Filed by `build mech` 2026-07-31:**

- [x] 2.7 **The round's drama is now a clock, and a spectator has no character to read it off.** Built as a **spectator-only** readout — `hud.gd::_refresh_spectator_panel()` — drawing the clock, its current limit and the save count: `LATA OUT  3.2 / 3.50 s      SAVES  2 / 5`, in `OFFENSE` while the clock runs and `AMBER` between. Measured reading `SAVES 1 / 5   NEXT LIMIT 4.25 s` in `spec_probe --solo`. ⚠️ **I took the spectator half and left the player half alone**, per your own "the two of you must not both build it": the `_process` spectator branch no longer calls `_refresh_status_stack()` at all, so `build ux` §4.1/§4.9 is untouched and is told so in **4.12**. `STRANDED` is `build mech`'s status row and appears through that same stack, so a spectator does not draw it — see 4.12 Since §1.9 and §5.2 a round is won by the lata being off its circle when the countdown expires — so the two numbers that explain *everything happening on screen* are `RoundManager.can_out_left()` and `can_out_stacks()`, plus the `STRANDED` state on the lata. All three are public and mirrored to every peer, and none of them needs a local character. **2.5's "the HUD is sane with no character" is the floor; this is the ask** — the footage is unreadable without it, and the footage is why this lane was pulled forward. Whether the countdown belongs in the spectator HUD or is left to `build ux` §4.9 is your call, but the two of you must not both build it

### 3 · 💥 `build abil` — Abilities *(Sonnet 5 · high)*

- [ ] 3.1 **Can-Smash** — ground smash, shockwave in a stated radius, **1–2 s** stun on incoming slippers and players, telegraphed wind-up. Base cooldown: resolve 3.0 s (brief) vs 8.0 s (code) and record why
- [ ] 3.2 **Can-Dash** — one evasion per round
- [ ] 3.3 **Ground Smash** — the tsinelas dives downward, shockwave on landing, stun on hit, cooldown
- [ ] 3.4 **Ground Smash direct hit on the lata = the attacking side wins instantly**, and it is bounded on more than one side
- [ ] 3.5 **Charged self-launch** — a loose tsinelas charges a mini-jump and flings *itself*
- [ ] 3.6 Every shockwave resolves **host-side** through `AbilityUtils.spawn_pulse_hitbox`
- [ ] 3.7 The roster's per-class abilities still work beside the new role verbs

**Filed by `build mech` 2026-07-31 — §1.9 landed and it changes three things here:**

- [ ] 3.8 **Quick Stand now refuses off the circle**, because it goes through `CharacterBase.self_right()` and that refuses. Confirm no roster ability stands a lata up by any other route — grep for anything writing `State.NORMAL` on a downed can. **If you think a skin should beat §1.9, argue it in § LOG; do not route around it.** A skin that stands a lata up anywhere deletes the rule for whoever picks it, which makes that skin the correct answer
- [ ] 3.9 **3.4's "bounded on more than one side" got weaker and you own it.** A stranded lata is a *stationary* target that cannot dodge, cannot Can-Dash and cannot smash — so Ground Smash's `within 0.75 m = instant win` is now trivially landable on a can that is already lying there. Either bound it (no instant win on an already-downed lata — the countdown is already winning that round) or say why the free win is fine
- [ ] 3.10 **The lata's kit has to matter *before* it is displaced**, because after it there is nothing: DOWNED blocks Can-Smash and Can-Dash by construction. That is the intended shape of §1.9 — check the radii and cooldowns read as "keep them off the mark" rather than "answer a knockdown"

**Filed by `build spec` 2026-07-31:**

- [ ] 3.11 **`main.gd` cannot pass `--check-only`, and it is your resources.** `godot --check-only --script scripts/main.gd` emits `Parse Error: Cannot assign a value of type Resource to constant "TSINELAS_ABILITY_TEAM_A"` (and `..._TEAM_B`) — `main.gd:107-108` preload `bakya_bash.tres` / `flick_dash.tres` typed as `AbilityBase`, and offline the `.tres` script association does not resolve, so they come back as bare `Resource`. **Verified pre-existing**: identical on a clean checkout of `main.gd` with this lane's change removed. Runtime is fine. But `docs/README.md` calls grepping `--check-only` for `Parse Error` *"the one cheap real gate"*, and that gate is currently useless for the project's largest file

### 4 · 🖥️ `build ux` — Screens and teardown *(Sonnet 5 · high)*

Everything in this section is bound by the REACHABILITY RULE. Spectator is `build spec`'s;
do not re-open it.

- [ ] 4.1 **UI countdown for every stun and status effect** — a stun the player cannot time is a stun they cannot play around
- [ ] 4.2 **Character-select desync** — lata and tsinelas picks reliably reach the match on every path: solo, host, client, and an AI-held Prop seat beside a human. The model must not change mid-match
- [ ] 4.3 **Host disconnect** — the host announces it is leaving before closing the socket; clients bounce out immediately instead of waiting out the ENet timeout. Wired to the quit dialog
- [ ] 4.4 **Trajectory preview** visible for throws and charge-ups, integrating the *same* solve the throw uses
- [ ] 4.5 Charge/meter readouts for the bump meter, the stamina bar and the throw lock
- [ ] 4.6 Max power shown in the custom tsinelas description
- [ ] 4.7 **Sweep for orphans.** Every system the other lanes built has a menu entry point a player can find — hanger, classes, stamina, the smash cooldowns. Anything reachable only by flag or autoload is filed here and fixed

**Filed by `build mech` 2026-07-31:**

- [ ] 4.8 **`STRANDED` is a new status row and 4.1 must draw it.** `CharacterBase.status_effects()` emits it in place of `DOWNED` for a lata off its circle, counting the §5.2 clock instead of the 2.0 s ceiling — because that lata is not counting down to standing up, it is counting down to losing the round. A `DOWNED` bar that ticks to 0.00 and then sits there is the exact defect 4.1 exists to prevent
- [ ] 4.9 **The circle countdown and its stack count are the round's main drama and the HUD barely says so.** `RoundManager.can_out_left()` / `can_out_limit()` / `can_out_stacks()` are all public and mirrored to every peer. Both sides need to read it: the defence to panic, the offence to press. The **stack** matters as much as the clock — "this save buys you 2.00 s, the next one 1.25" is the whole escalation
**Filed by `build spec` 2026-07-31:**

- [ ] 4.11 **`debug_player_switcher.gd` switches a bot OFF in a spectated match, and it is the seat nobody is in.** Measured by `spec_probe --solo`: *"every seat including the vacated one is bot-held — FAIL, 3 of 4 ai-driven"*. `_apply_slots()` claims `DEFAULT_P1_UNIT` ("TeamAPerson") for player 1 and disables that unit's controller — which in a spectated Single Player is exactly the seat the spectator just vacated, so one unit stands still for the whole round, on camera. `main.gd` now re-asserts the controllers a frame later and the probe reads 4/4, but that is the cheap half; the switcher is `scripts/ui/**` and the real fix is yours — it should not claim a unit in a session with no local human. ⚠️ **And it does the same thing to the CAMERA, which is worse.** `_apply_slots()` calls `set_active(true)` on that unit's `CameraRig`, and `Camera3D.current` is winner-takes-all per viewport — so a spectated match rendered a Person's first-person view, viewmodel arms and all, while the free camera flew around unseen. `spectator_camera.gd` now re-claims `current` every frame, which is authoritative and correct for a unit with no rig, but the switcher should not be claiming a seat nobody is sitting in in the first place
- [ ] 4.12 **`_refresh_status_stack()` is yours and the spectator no longer calls it.** `hud.gd`'s `_process` spectator branch used to call it with a null character purely to get the one `LATA OUT` row it appends from `RoundManager`; it now calls `_refresh_spectator_panel()`, which draws that clock **plus the save count** (§2.7). Nothing player-facing changed — but when you build §4.1/§4.9, know the spectator has its own readout and the two must not both grow a countdown

- [ ] 4.10 **`scripts/ui/tutorial.gd` is yours and it is wrong twice.** It still teaches *"the defender body-blocks the throw, **tags the attacker**, and stands the lata back up"* — the tag was deleted on 2026-07-30 — and it quotes the reset channel at **2.2 s** in two places when it is now 1.8. It also never mentions that a displaced lata cannot stand up by itself, which is now the single most important rule a new player does not know

### 5 · 🎨 `build model` — Models, classes and names *(Opus 5 · medium)*

> ⚠️ **THE "NO NEW BASE MESH" LAW IS LIFTED FOR THIS LANE.** Human directive, 2026-07-31:
> *"those were just placeholders."* `lata.obj` and `tsinelas.obj` are one mesh each, and
> every one of the twelve classes is that same mesh tinted with junk bolted on — which is
> why they read as identical in play. **Author real geometry per class.** Amend
> `Art_Direction.md` §4 to say so in the same commit; you own that file.
>
> **Filipino goes in the class NAMES only. Everything else stays English.** A class is
> called `LATA NG SARDINAS` or `BAKYA`; its tagline, every UI label, every button, every
> string a player reads outside that name, and all code and comments stay in English.
> Do not translate the interface.
>
> **You set the roster size.** Six of each is what exists, not a requirement. Add classes,
> cut the ones that never earned their slot — say what you chose and why.
>
> ⚠️ **The roster INDEX is the replicated wire format** (`can_index` / `slipper_index` are
> ints on the wire). Renaming is free. **Adding goes on the END. Removing or reordering
> shifts every index after it** — if you do it, do it in one commit, check every default and
> saved pick that names an index, and say so in § LOG.

- [ ] 5.1 **A lata base mesh per class, each recognisably a specific Filipino tin** — the silhouette does the work, not the tint. Sardinas, gatas, biskwit, pintura, kape, softdrink: all different profiles, all readable from across the arena
- [ ] 5.2 **A tsinelas base mesh per class, with genuinely different shapes** — a bakya is a carved wooden clog, not a tinted rubber flip-flop. Render the tsinelas types real Tumbang Preso is played with
- [ ] 5.3 **Every class is Filipino-themed and newly named by you** — the `name` field in Filipino, specific enough that a player from the street recognises it. **Taglines and everything else stay English.** Rewrite `CANS` / `SLIPPERS` in `character_roster.gd`
- [ ] 5.4 **The roster size is your call** — final count of lata and tsinelas classes decided, justified in § LOG, and consistent everywhere an index is assumed
- [ ] 5.5 Tsinelas **visibly bigger** in game
- [ ] 5.6 A **hanger** in tsinelas customisation that provably cannot affect physics
- [ ] 5.7 Junk and wear still bolted on per class where it adds character — the attachment system stays, it just stops carrying the whole job alone
- [ ] 5.8 **Render every class and look at it.** Nothing here is `[x]` without a screenshot
- [ ] 5.9 Every class reads at gameplay camera distance, not just in the preview
- [ ] 5.10 Collision is unchanged by any of it — `_COLLISION_BY_ROLE` still sizes every shape, and the dent meshes still line up with the new lata

### 6 · 🥊 `build phys` — Contact and readability *(Sonnet 5 · high)*

- [ ] 6.1 **Waiting-screen phasing** — objects no longer pass through each other pre-round
- [ ] 6.2 Lata knockback **measured**, not predicted, against the ~1 m target
- [ ] 6.3 **A knocked-down lata visibly rolls.** The current read — "hard to tell it fell" — is the bug being fixed
- [ ] 6.4 Collision tuning for the enlarged tsinelas: capsule, hurtbox and hitbox all agree with the new visual scale
- [ ] 6.5 Bump displacement measured for tap and full charge
- [ ] 6.6 The preview arc and the thrown arc land in the same place

**Filed by `build mech` 2026-07-31:**

- [ ] 6.7 **`round_probe` FAILs today and it is not mine.** `TeamBProp` moves 4.33 m/s and drifts 0.51 m between rounds, against a "fair: 0.00" bar. **Measured identical on a stash with my changes removed**, so it is pre-existing — but nothing on the board owned it and now something does. It is the same family as 6.1
- [ ] 6.8 **A `STRANDED` lata must not look like a lata that is about to get up.** 6.3 is fixing "hard to tell it fell"; §1.9 adds a second read on top — *this* one is never getting up on its own, and the player's answer is to run to it. If a stranded lata and a two-second knockdown look the same, the defence cannot tell which one needs them
- [ ] 6.9 **Measure the punt on the networked path.** §1.4's punt rides a new defaulted argument on `carriable.gd::_rpc_set_loose` and applies its impulse on every peer, the same idiom `_rpc_apply_scuff` uses. Measured **3.13 m locally, twice** (`mech_probe`); never once across two real peers, where the drop is triggered by replicated state arriving frames after the hit
- [ ] 6.10 **6.2's ~1 m target has one real number against it and it came from the wrong end:** a *tap* bump on a lata measured **0.951 m** in `mech_probe`. A tap is `BUMP_LIGHT_SPEED` 3.0 — if the weakest shove in the game already moves the lata a metre, `CAN_KNOCKBACK_SCALE` ×2.6 may be doing more than "~1 m per solid hit" was ever meant to mean

### 7 · ⚖️ `build fair` — Balance and AI *(Opus 5 · xhigh)* — **RUNS LAST, ALONE**

- [ ] 7.1 A fairness run **on this branch**. No number for these rules exists yet; none may be quoted until it does
- [ ] 7.2 The Defender is no longer the strongest role — proven by win rate, not by argument
- [ ] 7.3 The objects have equal presence: a round can be decided by the lata or the tsinelas without either Person acting
- [ ] 7.4 Final pass on every cooldown, stun duration, hit penalty and meter
- [ ] 7.5 **No stunlock.** Prove it by naming the chain, not by asserting it
- [ ] 7.6 Named counterplay for every powerful object action
- [ ] 7.7 The AI uses every new verb — bump meter, smash, dash, dive, self-launch, sprint, and driving the lata home
- [ ] 7.8 Legacy AI constants derived from the old `SPEED = 6.0` re-derived or explicitly kept

**Filed by `build mech` 2026-07-31:**

- [ ] 7.9 **The bots do not reach the new win conditions at all.** A 6-round `ai_probe fairness` run after §1.9 completes with no script errors, but the probe's own report says *"half or more of these rounds timed out"* — a timeout is a **defender** win, so 7.2's headline claim cannot even be asked yet. Fix the bots before quoting a win rate; that is 7.7's real acceptance
- [ ] 7.10 **`ai_controller.gd` mashes bump to self-right and that is now a no-op off the circle** (`_set_held("bump", character.is_self_rightable())`). A bot lata lies there pressing a dead button while its round runs out. It needs the other half too: **a bot taya must run to a stranded lata and hold the 1.8 s channel**, which is the defence's only answer and the one behaviour that decides whether §5.2's escalation is playable at all
- [ ] 7.11 **The power bump got materially stronger and its price did not move.** It was ~1 m + 0.9 s stagger + 1.2 s slow; it now also punts the tsinelas **3.13 m**, i.e. ~2.8 s of retrieval tempo. `BUMP_CHARGE_FULL_TIME` was deliberately left at 1.35 s (the 1.5× symmetry with the throw charge is worth keeping) — **you are the lane that decides whether 1.35 s of visible wind-up still buys all of that.** `PUNT_SPEED` is the cheaper knob if it does not
- [ ] 7.12 **7.5's stunlock argument has a new exception to re-argue, not to inherit.** `Design.md` §11 item 2 now reads "`DOWNED_MAX_TIME` bounds every unit **except a lata off its circle**". My claim is that this is not a stunlock because the state is bounded by a countdown that *ends the round* (≤5.0 s, 1.25 s at full stacks) and can be cut short by the channel. **Break it or confirm it by naming the chain** — in particular check that re-downing a stranded lata (`go_downed()` has no already-downed guard) cannot be used to stall anything
- [ ] 7.13 **The §5.2 recovery table is now load-bearing and has never been played.** The whole round is designed to escalate along it — save 4 is a knife-edge, save 5 is unsurvivable-by-channel. If real rounds never reach 3 stacks, the escalation is theatre; if they reach 5 in the first 30 s, the round is over before it starts. `CAN_OUT_RECOVERY_STEP` and `RESET_CHANNEL_TIME` are the two knobs

---

## THE LANES

Each block is paste-ready. Set model and effort first.

<details><summary>🎮 <b><code>build mech</code></b> — Mechanics · Opus 5 · high</summary>

> You are a Godot 4.7 gameplay engineer on **Tumbang Preso** — 2v2 Filipino street game,
> GDScript, LAN over ENet, host-authoritative. Repo:
> `C:\Users\matth\Documents\GitHub\DOST-GameDev`, branch
> `feature/objects-overhaul-v2`.
>
> Read `docs/README.md`, `docs/Design.md`, and `docs/Agent_Prompts.md` § SALVAGE, § PATHS
> and § CHECKLIST §1 — those boxes are your task list. Open
> `scripts/characters/character_base.gd`, `carrier.gd`, `carriable.gd`, `hitbox.gd` and
> `scripts/systems/round_manager.gd` before you change anything.
>
> **Why you exist.** The Defender is overpowered and the tap-out that made it so is
> boring — one button near the attacker ended the round with no counterplay. And the two
> objects are passengers: the lata stands still, the tsinelas is ammunition. This lane
> makes the defence pay for its power and gives the lata a win condition a player can see
> coming.
>
> Most of §1 is already written on this branch. **Your job is to finish it, correct it,
> and make it feel right** — not to re-implement it. §1.9 is genuinely missing.
>
> You decide every final number. The values on the board are starting points; if 1.5×
> feels wrong for the bump charge, change it and say why in § LOG. Design the rules to be
> **suspenseful**: the lata's countdown shortening every time it is saved is the beat the
> whole round should build around.
>
> Tick §1, append to § LOG, and keep `Design.md` in step with every number you move.
> Do not spawn subagents.

</details>

<details><summary>👁️ <b><code>build spec</code></b> — Spectator · Sonnet 5 · high — <b>RUN THIS NEXT</b></summary>

> You are a Godot 4.7 gameplay engineer on **Tumbang Preso** — 2v2 Filipino street game,
> GDScript, LAN over ENet, host-authoritative. Repo:
> `C:\Users\matth\Documents\GitHub\DOST-GameDev`, branch `feature/objects-overhaul-v2`.
>
> Read `docs/README.md` and `docs/Agent_Prompts.md` § HOW TO RUN A LANE, § THE REACHABILITY
> RULE, § SALVAGE, § PATHS and § CHECKLIST §2 — those six boxes are your whole task list.
>
> **Why you exist, and why you are urgent.** A gameplay video is being recorded off this
> branch and there is currently no way to film the match from outside it. You are a small,
> self-contained lane pulled ahead of the rest of the board for exactly that reason.
>
> Build **spectator mode**: a free-flying camera with no body, no collision and no physics
> layer, so it clips through all geometry by construction rather than by a mask. It must fly
> anywhere, in **both Single Player and Multiplayer**.
>
> **It is entered from a SPECTATE toggle button in the lobby, not from a command-line flag.**
> `scripts/systems/spectator_camera.gd` already exists and boots, and today only
> `--spectate` reaches it — which is the exact failure § THE REACHABILITY RULE describes.
> `ui/match_setup.gd` already builds a toggle in code that has never been rendered: finish
> that one, add one to `ui/multiplayer_setup.gd`, put both in the focus order, and look at
> them.
>
> Seat −1 is the spectator seat: claim no seat, be excluded from the ready count, and let
> the vacated slot be AI-filled by the path that already fills empty slots. **That exclusion
> has never run beside a real second peer** — verify it with two, not with one.
>
> It has to be usable as a camera, not just present: free look, a follow-target cycle, and a
> speed control, so both wide shots and close shots are possible. And the HUD must be sane
> for a unit with no character.
>
> ⚠️ **`build mech` owns `character_base.gd`, `round_manager.gd`, `carrier.gd`,
> `carriable.gd` and `Design.md`. Do not touch them** — if you need something from one, file
> it in § LOG instead. ⚠️ **`build ux` runs after you** and shares `match_setup.gd`,
> `multiplayer_setup.gd`, `network_manager.gd` and `hud.gd`: take only the seat, the toggle
> and the no-character branches, and say in § LOG what you left.
>
> **If you flag something outside your own paths — a bug, a stale string, a number your
> change invalidated, a claim you could not verify — FILE IT as a numbered `- [ ]` item
> on the owning lane's § CHECKLIST section, under a `**Filed by ‹your lane› ‹date›:**`
> line. See § HOW TO RUN A LANE. A finding that only appears in § LOG does not get
> fixed.
>
> Prefer building controls in code over editing a `.tscn`. Tick §2, append to § LOG.
> Do not spawn subagents.

</details>

<details><summary>💥 <b><code>build abil</code></b> — Abilities · Sonnet 5 · high</summary>

> Same project, same branch, same reading rules. Your tasks are § CHECKLIST §3, and the
> current numbers are `Design.md` §5.3 and §6.
>
> **Why you exist.** The objects need verbs of their own, powerful enough that a round can
> turn on one. Five: Can-Smash, Can-Dash, Ground Smash, Ground Smash's instant win, and
> the tsinelas' charged self-launch. The loop worth protecting is *charge the jump, clear
> the taya, dive on the lata, win* — the slipper taking a round without its Person ever
> touching it.
>
> Read `scripts/abilities/prop_smash.gd` first; most of this exists and its own comments
> explain why each radius is what it is. Argue with them if you disagree, then change
> them.
>
> Two hard rules. Every shockwave resolves through `AbilityUtils.spawn_pulse_hitbox` so it
> lands on the host like every other hit — a hand-rolled `Area3D` is perfect in Single
> Player and inert on LAN. And every powerful action needs a telegraph: an undodgeable
> radius around the object the attacker *must* approach is a rule that says "stay away
> from the can", which is the opposite of this game.
>
> Resolve the Can-Smash cooldown conflict in § SALVAGE. You have final say on radii,
> **If you flag something outside your own paths — a bug, a stale string, a number your
> change invalidated, a claim you could not verify — FILE IT as a numbered `- [ ]` item
> on the owning lane's § CHECKLIST section, under a `**Filed by ‹your lane› ‹date›:**`
> line. See § HOW TO RUN A LANE. A finding that only appears in § LOG does not get
> fixed.
>
> durations and cooldowns — record each decision. Tick §3, append to § LOG.
> Do not spawn subagents.

</details>

<details><summary>🖥️ <b><code>build ux</code></b> — Screens and teardown · Sonnet 5 · high</summary>

> Same project, same branch, same reading rules. Your tasks are § CHECKLIST §4.
>
> **Why you exist.** A gameplay video is being recorded off this branch. Two things
> currently spoil it: a player cannot see how long they are stunned, and the character the
> player picked is not the character that loads.
>
> **§ THE REACHABILITY RULE applies to every line you write.** A screen nobody can get to
> is not a feature. Name the entry point first, wire it in the same commit, render it and
> look at it.
>
> ⚠️ **Spectator is 👁️ `build spec`'s and is already done — do not re-open it.** You share
> `match_setup.gd`, `multiplayer_setup.gd`, `network_manager.gd` and `hud.gd` with that
> lane: read its § LOG entry and what it left before you edit any of the four.
>
> Four pieces of work:
> * **Status timers** — one visible countdown per live effect. This is most of what "the
>   defender feels overpowered" actually was.
> * **The character-select desync** — the human's report is that the lata and tsinelas
>   picks are ignored and the default loads, then the model changes mid-match. Fix it on
>   every path: solo, host, client, and an AI-held Prop seat next to a human teammate. A
>   previous pass found the visual cache key ignored the skin index; verify that is the
>   whole of it rather than assuming so.
> * **Host disconnect** — quitting politely currently strands clients for the same ~5 s as
>   a crash. Announce the shutdown before closing the socket, and tie it to the quit
>   dialog. Do not shorten the ENet timeout.
> * **The trajectory preview and the charge readouts** — the preview must integrate the
>   same solve `carriable.gd` throws with. A second ballistics path that disagrees with
>   the first is worse than no preview.
>
> **If you flag something outside your own paths — a bug, a stale string, a number your
> change invalidated, a claim you could not verify — FILE IT as a numbered `- [ ]` item
> on the owning lane's § CHECKLIST section, under a `**Filed by ‹your lane› ‹date›:**`
> line. See § HOW TO RUN A LANE. A finding that only appears in § LOG does not get
> fixed.
>
> Prefer building controls in code over editing a `.tscn`. Tick §4, append to § LOG.
> Do not spawn subagents.

</details>

<details><summary>🎨 <b><code>build model</code></b> — Models, classes and names · Opus 5 · medium</summary>

> Same project, same branch, same reading rules. Your tasks are § CHECKLIST §5; the laws
> are `Art_Direction.md` §1 (colour), §2 (scale) and §4 (attachments).
>
> **Why you exist.** `lata.obj` and `tsinelas.obj` are placeholders, and every class is one
> of those two meshes tinted with junk bolted on — so the character screen promises twelve
> objects and the arena delivers two. **Author real geometry per class.** The "never a new
> base mesh" law in `Art_Direction.md` §4 is lifted for you by human directive; update that
> section yourself in the same commit.
>
> **Filipino goes in the class NAMES and nowhere else.** `LATA NG SARDINAS`, `BAKYA` — but
> the tagline under it, every UI label, every button, and all code and comments stay in
> **English**. You are naming twelve objects, not translating an interface.
>
> The lata should be **specifically Filipino tins** — sardinas, gatas, biskwit, pintura,
> kape — told apart by silhouette from across the arena, not by colour. The tsinelas need
> genuinely different shapes: a bakya is a carved wooden clog, a worn-through rubber pair is
> thin and floppy, a foam pair is thick. **Every class is Filipino-themed and newly named by
> you** — the current names are a starting point, not a constraint.
>
> **You also decide how many there are.** Six of each is what exists, not a requirement.
> Add classes worth having, cut ones that never earned a slot, and justify the final count.
>
> Keep the good parts of what exists: procedural junk and wear still bolt on per class —
> the attachment system just stops carrying the whole job alone. The tsinelas must read
> **visibly bigger**, and the **hanger** must provably not affect physics: attachments are
> visual-only children of `Visual`, and collision is sized by `_apply_role_collision()`
> from a table that knows nothing about skins. That property is the whole reason this is
> safe — do not lose it while you are replacing the meshes under it.
>
> ⚠️ The roster **index** is the replicated wire format. Rename freely; **add on the end**;
> and if you remove or reorder, fix every default and saved pick that assumes an index, in
> the same commit. The three `lata_dent*.obj` meshes must keep lining up with the new lata.
>
> ⚠️ **`build mech` may still be running.** Do not touch `character_base.gd`,
> `round_manager.gd`, `carrier.gd`, `carriable.gd` or `Design.md` — if a model change needs
> something from one of them, file it in § LOG for that lane instead of editing it.
>
> `tools/models/generate_all.gd` and `obj_writer.gd` are how meshes get emitted here —
> read them before you decide how to author a dozen.
>
> ⚠️ **Twelve skins exist in code and not one has ever been rendered.** No box here is
> `[x]` without a screenshot you looked at, at gameplay camera distance, not only in the
> preview. Godot's `--headless` has no rendering device and returns blank captures — use
> the plain exe.
>
> **If you flag something outside your own paths — a bug, a stale string, a number your
> change invalidated, a claim you could not verify — FILE IT as a numbered `- [ ]` item
> on the owning lane's § CHECKLIST section, under a `**Filed by ‹your lane› ‹date›:**`
> line. See § HOW TO RUN A LANE. A finding that only appears in § LOG does not get
> fixed.
>
> Tick §5, append to § LOG. Do not spawn subagents.

</details>

<details><summary>🥊 <b><code>build phys</code></b> — Contact and readability · Sonnet 5 · high</summary>

> Same project, same branch, same reading rules. Your tasks are § CHECKLIST §6.
>
> **Why you exist.** The mechanics above are written and predicted; almost none of them
> are measured. You are the lane that puts numbers on them and fixes what the numbers
> show.
>
> * Objects phase through each other on the pre-round waiting screen — the free-roam
>   window runs outside the normal round path and may skip depenetration.
> * A knocked-down lata is **hard to tell apart from a standing one**. That is the
>   headline defect: it must read as physically rolling, and keep going.
> * The lata's knockback target is ~1 m per solid hit and the power bump's is ~1 m of
>   displacement. Both are currently arithmetic from `v² / 60`, not observations.
> * The tsinelas grew; confirm the capsule, hurtbox and hitbox all grew with it and that
>   nothing rests below the floor.
> * The preview arc and the real throw must land in the same place.
>
> Measure with the cheapest probe that actually looks at the thing, and apply the
> project's impossible-number rule: if two numbers cannot both be true, the metric is the
> **If you flag something outside your own paths — a bug, a stale string, a number your
> change invalidated, a claim you could not verify — FILE IT as a numbered `- [ ]` item
> on the owning lane's § CHECKLIST section, under a `**Filed by ‹your lane› ‹date›:**`
> line. See § HOW TO RUN A LANE. A finding that only appears in § LOG does not get
> fixed.
>
> bug. It has caught five harness faults here already. Tick §6, append to § LOG.
> Do not spawn subagents.

</details>

<details><summary>⚖️ <b><code>build fair</code></b> — Balance and AI · Opus 5 · xhigh — <b>RUNS LAST</b></summary>

> Same project, same branch, same reading rules. You are the **final lane**. Nothing runs
> after you. Do this directly in one focused pass and **do not spawn subagents**.
>
> Your tasks are § CHECKLIST §7, and you have final authority over **every number in the
> game** — that is your row in § PATHS and nobody else's.
>
> **Why you exist.** Two claims are being made about this branch and neither has been
> measured: that the Defender is no longer overpowered, and that the objects now matter as
> much as the people. Read `Design.md` end to end, read every constant it names in the
> code, confirm the two agree, then run a real fairness sweep and find out whether the
> claims are true.
>
> Then think critically and adversarially about the whole set. Every cooldown, stun,
> penalty and meter. Prove — by naming the chain, not by asserting it — that no infinite
> stunlock and no broken loop exists. Name the counterplay for every powerful object
> action; "don't be there" does not count.
>
> The AI is the multiplier on all of it: a bot that cannot charge a bump, dive on the lata
> or drive its can home makes every number you produce a lie. It has been rewritten for
> the new verbs and its behaviour has never been observed. Legacy constants derived from
> the old `SPEED = 6.0` are flagged in-file and not re-derived.
>
> **If you flag something outside your own paths — a bug, a stale string, a number your
> change invalidated, a claim you could not verify — FILE IT as a numbered `- [ ]` item
> on the owning lane's § CHECKLIST section, under a `**Filed by ‹your lane› ‹date›:**`
> line. See § HOW TO RUN A LANE. A finding that only appears in § LOG does not get
> fixed.
>
> Tick §7, append to § LOG, and say plainly which conclusions are **measured** and which
> are **argued**.

</details>

---

## LOG

Newest first. One entry per lane run: what changed, what was **measured** versus written,
what decision you made and why, and what you are handing the next lane. Short.

### 2026-07-31 · 👁️ `build spec` · §2 · branch `feature/objects-overhaul-v2`

**Almost all of §2 was already written, and almost none of it worked off this machine.**
The camera itself was complete and good. What was missing was every join between it and a
player.

**The toggle had been built and never looked at.** `match_setup.gd::_build_spectate_button()`
correctly created a `Button` and correctly added it to the seat rows' VBox — with no
`theme_type_variation`, so it drew as a small grey engine-default button under four 66 px
wood planks. "The control is added to the tree" was true, and it is not the claim
§ THE REACHABILITY RULE asks for. It is now styled off the last seat row rather than
restated, so it cannot drift from the four it sits under, and there is a second one on
`multiplayer_setup.gd` — placed by offsets, because that screen has no container at all
and the container idiom would have silently built nothing there. Both are in the focus
order explicitly (`focus_neighbor_bottom`, not merely tree order: a VBox is navigated with
the arrow keys and those read the neighbour).

**The spectate choice never left the machine that made it, and that is the real bug of this
lane.** `NetworkManager._local_picks()` is snapshotted ONCE — at `host_game()` for a host,
at `_on_connected_to_server()` for a client — and the toggle lives one screen later, in the
lobby, while connected. So `is_spectator()` was reading a value frozen before the player had
any way to set it: a client that pressed SPECTATE was spawned a character anyway and counted
in the ready gate, and a host that pressed it got a body too. Every consumer downstream
(`_spawn_player`, `_expected_ready_count`, `playing_peer_count`) was already correct and was
being fed a stale fact. New: `publish_spectator()`, `_rpc_set_spectator` and a
`peer_spectator_changed` signal, host-authoritative like every other pick. It fires from
`_rpc_identify` too, because `player_connected` lands BEFORE the identify packet and the
lobby has already seated the peer by then.

**The seat is now RELEASED, and the note in that function said the opposite.** It read
"a player who spectates keeps whichever seat they had highlighted" — not compatible with
§2.3's *claims no seat*, because a chair listed under your peer id is a chair the other
three cannot use, for a match you are not in. It is released to the bot pool and remembered
host-side (`_vacated_seats`), so un-spectating returns you to your OWN seat if it is still
free and to first-free if it is not. An all-spectator lobby is deliberately startable: that
is the filming case, and the empty-board guard would have disabled the one button a
spectator is there to press.

**⚠️⚠️ THE ONE THE PROBE DID NOT FIND, AND LOOKING AT THE PICTURE DID.** Twenty checks
passed — the camera flew, TAB picked up a target, the wheel retuned, the HUD stripped to
nothing — and the rendered frame was **a Person's first-person view with its orange
viewmodel arms across the bottom of the shot**. `Camera3D.current` is winner-takes-all per
viewport and the last writer wins; `debug_player_switcher.gd::_apply_slots()` claims
`DEFAULT_P1_UNIT` ("TeamAPerson") when the DebugBar registers and calls `set_active(true)`
on its rig — the seat the spectator had just vacated. `_ready()` set `current` once at
spawn and lost it silently a few frames later. The camera was flying perfectly and nobody
was looking through it, which is the entire feature failing while every assertion about it
held. It now re-claims `current` every frame — authoritative rather than a one-shot
re-assert, because a spectator has no rig, no body and no seat and there is no other
legitimate owner of the view — and `spec_probe` gained the check that would have caught
it, asked of the VIEWPORT rather than of the node. **This is what "render the screen and
look at it" is for, and it is the second time this session that the thing which was
verified and the thing which was true came apart.**

**Three more defects the probe itself found, that no amount of reading would have.**

* **`TAB` never arrived.** It is bound to `ui_focus_next`, the Viewport consumes
  focus-navigation keys during the GUI phase, and that runs before `_unhandled_input`. The
  follow cycle — the one control that makes this camera anything but a static wide shot —
  was unreachable, which reads as "not built". Moved into a deliberately narrow `_input`
  that handles exactly `Tab` and `F` and consumes only those.
* **`debug_player_switcher.gd` turns a bot off in a spectated match**, and it is the seat
  the spectator just vacated (`DEFAULT_P1_UNIT` = "TeamAPerson"). One unit standing still
  for a whole round, on camera. `main.gd` re-asserts a frame later; the real fix is
  `build ux`'s and is filed as **4.11**.
* **A solo spectator was stuck in the pre-round window forever.** `enter_spectator_mode()`
  strips the ready prompt — correctly, since it says "press [R] to start" to somebody who
  is not in the match — so nothing ever started the round and the §2.7 strip read empty
  forty seconds in. A solo spectator now auto-readies. There is nobody to wait for.

**Decisions I made rather than asked about.** The wheel means two things depending on mode —
fly speed when free, follow DISTANCE when following (1.2–30 m) — because in each mode only
one of the two does anything, and a fixed 6.5 m follow could not frame a close-up. §2.7's
countdown is drawn in a **spectator-only** readout, not in `_refresh_status_stack()`: that
stack is `build ux`'s §4.1/§4.9 and I am not pre-empting it, so the spectator branch of
`_process` calls its own panel instead of the shared one. Filed as **4.12** so they know.

**Measured — `tools/spec_probe.tscn --solo`, 21/21.** (The two-peer run is below.) Not a physics body, zero collision
shapes, no `AIController` anywhere on it, flew **24.02 m straight down through the road** to
y = −15.02 m, four units with 4 of 4 bot-held, wheel 12.0 → 21.9 m/s, TAB picked up
TeamAProp, the same wheel pulled the shot 6.5 → 2.6 m, F freed it, and the HUD stripped to
**zero** status rows with the §2.7 strip reading `SAVES 1 / 5   NEXT LIMIT 4.25 s`. **Screens rendered
and looked at**, not merely built — the PNGs are regenerable rather than committed, same as
every other harness output here:

```
godot --path . --resolution 1920x1080 tools/ui_shot.tscn -- <dir>/
godot --path . tools/spec_probe.tscn -- --solo --shots=<dir>
```

**Measured — the two-peer run, `--lobby-host` + `--lobby-join=127.0.0.1`, HOST 15/15,
twice.** This is the one the board said had never been done, and it is the reason the lane
was rated high. The host learned the client was watching, the board went to `seats={1: 0}`
with the client gone from it, `playing_peer_count` dropped 2 → 1, no READY tick was held,
the vacated seat read `TEAM A · OBJECT   · BOT`, and START MATCH went live without the
spectator pressing anything. Un-spectating returned the client to **seat 1, the one it
vacated**, not first-free. Then the host spectated itself: its own flag updated — the one
`host_game()` had frozen — it released seat 0, and START stayed live.

**⚠️ The probe's FIRST two-peer run reported `§2.4 the client is a player again — FAIL`, and
that was the probe's fault, not the product's.** The host is launched first and both sides
counted from their own zero, so the host sampled 2 s before the client had pressed the
button the sample was about; the host then quit first and
`match_setup.gd::_on_server_disconnected` swapped the client's scene out mid-run, which is
the silent-empty-log trap `net_spawn_probe.gd` documents. The impossible-number rule caught
it — a seat cannot be returned before it is asked for. The clock table is now written into
`spec_probe.gd` rather than left as four bare numbers.

**⚠️ WHAT I DID NOT VERIFY, AND NOBODY SHOULD QUOTE AS IF I HAD.** Two real peers were
verified in the **lobby**, not in the **match**: nothing here watched a spectating client
actually load `Main.tscn` beside a live host and confirm the bot took its seat there — the
seat and gate are proven, the spawn skip is inherited from code that already existed. The
POV ask (2.8) is not built. And nobody has flown this camera by hand yet; every control is
measured, none is *played*.

**Left for `build ux`, per the shared-file rule.** In `match_setup.gd` I took only the
spectate button, the seat/ready path around it, and `_seat_detail`'s spectator line. In
`multiplayer_setup.gd`, only the new button. In `network_manager.gd`, only the
spectator/identify path. In `hud.gd`, only the no-character branches — `_refresh_status_stack`,
the timer, the pips and everything a *player* sees are untouched.

**Handed on — filed as checklist items, not left here:** **2.8** (the human's POV ask, which
needs `camera_rig.gd` and is therefore not mine), **3.11** (`main.gd` fails `--check-only` on
two pre-existing ability preloads), **4.11** (the debug switcher kills the vacated seat's
bot), **4.12** (the spectator no longer shares the player status stack).

### 2026-07-31 · 🎮 `build mech` · §1 · branch `feature/objects-overhaul-v2`

**§1.9 built, and it turned out to be four changes, not one.** `self_right()` now refuses
for a lata that is off its circle. The rule is written once, as *"the out-of-circle
countdown is not running"*, rather than as a second radius test — one line on the floor,
one source of truth, and it inherits the Option A gate and the round-active gate for
free. Three things fell out of it that were not optional:

* **`hitbox.gd`'s seal-on-hit had to go.** It sealed any lata past its 1.25 s appeal
  window, and one sealed lata ends the round. That was survivable while the 2.0 s ceiling
  always stood the lata up — a 0.75 s window you had to be standing in. Stranded, the
  window never closes, so the branch became **an unbounded instant win for anyone who
  walks over and presses bump**: the tap-out, rebuilt by accident, eight commits after
  this file deleted it. A follow-up hit now just shoves the lata further out, which is
  continuous and stacks with the clock instead of skipping it.
* **The reset channel's two steps were in the wrong order.** It stood the lata up and
  *then* carried it home; with §1.9 the stand-up is refused and the defence's only answer
  silently did nothing. Carry home, then stand up.
* **`RESET_CHANNEL_TIME` 2.2 → 1.8.** The channel used to be the lazier of two ways home;
  it is now the only one, so it has to be priced against the clock it races rather than
  against the attacker's cycle. At 2.2 the fifth stack and its 1.25 s floor were
  unreachable decoration — the round was decided a row above them. At 1.8 the cliff lands
  on the floor: the fourth save is the knife-edge and at max stacks a knockdown outside
  the circle simply ends the round. It is still longer than the defender's own full bump
  commitment, so it is still punishable, which is the property the 1.5 → 2.2 rise bought.

**§1.4's "far away" was never built.** A stagger dropped the tsinelas for free — at the
carrier's own feet — so eating a 1.35 s bump cost the attacker one bend of the knees.
There is a punt now, noted by `hitbox.gd` at the strike and spent by `host_drop()`
whenever the drop resolves, because networked those are frames apart and the hit is gone
by then.

**Also gated `_step_can_out` to Option B.** `Design.md` claimed Option A was "maintained
in parallel and unchanged" and it was not — the countdown ran there too, so an Option A
round could be lost to a clock nothing in that mode explains.

**Numbers I moved, all in `Design.md` in this commit:** `RESET_CHANNEL_TIME` 2.2 → 1.8,
new `PUNT_SPEED` 13.5 / `PUNT_LIFT` 3.8. **1.35 s for the bump charge is kept** — the
board offered it as changeable and the 1.5× symmetry with the throw is worth more than
any number I'd have replaced it with, especially now that the punt has made the full bump
much stronger. That is a `build fair` question and it is flagged as one.

**Measured, `tools/mech_probe.tscn`, 16/16 twice** — a new probe, because § PATHS gives
this lane no `tools/` row and writing to `phys_probe`/`hit_probe`/`round_probe` would
have broken one-writer-per-file. §1.9 both ways, the ceiling for a lata at home and for a
Person, the channel curing a strand, the 0.75 s stack, no-seal-on-hit, the punt, and the
countdown run to zero awarding the round to the tsinelas side.

**Two impossible numbers, both caught by the rule and both the metric's fault.** The punt
measured 3.30 m at 9.0 and 2.69 m at 10.5 — a bigger shove going less far — because the
origin was wherever the previous check had left the attacker; pinned, it is 3.13 m on
every run. And `round_active` read TRUE right after a countdown that had already fired
`round_won` correctly: `main.gd` starts the next round ~3.5 s later, inside the probe's
own wait, so that flag is not samplable from outside the instant it changes.

**What I did NOT verify, and nobody should quote as if I had:** the bump meter filling,
a tap producing no stagger, the wind-up on a second real peer, the long-throw punish end
to end, the ~1 m knockback on a *solid* hit (a tap measured 0.951 m in passing; `build
phys` 5.2 owns the real one), and the punt's networked `_rpc_set_loose` path. `round_probe`
still FAILs at 4.33 m/s and 0.51 m of between-round drift — **identical before and after
these changes**, measured on a stash, so it is pre-existing and is `build phys`'s.

**Handed on — filed as checklist items, not left here.** Eleven findings went onto the
lanes that own the files, per the new § HOW TO RUN A LANE rule this session added:
**2.7** (the countdown is unreadable to a spectator, and the video is the point),
**3.8–3.10** (Quick Stand now refuses off the circle; Ground Smash's instant win is
trivially landable on a stationary stranded lata; the lata's kit only matters before it
is displaced), **4.8–4.10** (`STRANDED` must be drawn; the clock and its stack deserve
real HUD presence; `tutorial.gd` still teaches the deleted tag and quotes 2.2 s),
**6.7–6.10** (`round_probe`'s pre-existing FAIL now has an owner; a stranded lata must
not look like a recoverable one; the punt is unmeasured across peers; a *tap* already
moves the lata 0.951 m), **7.9–7.13** (the bots time out instead of reaching the new win
conditions; a bot lata mashes a dead button while a bot taya ignores the channel; the
power bump got stronger and its 1.35 s price did not move; §11's stunlock argument has a
new exception to break or confirm; the §5.2 recovery table is load-bearing and unplayed).

### 2026-07-31 · pipeline reset · branch `feature/objects-overhaul-v2`

Branched from `feature/objects-overhaul`, which is itself a strict descendant of
`integration` — so this branch carries the salvaged code in full and loses nothing from
the stable line.

**What changed here is the process, not the code.** The nine-agent free-run is retired and
replaced by the six ordered `build xxx` lanes above, with single-writer path ownership
restored. Every prompt in the previous version of this file was deleted rather than
edited; they described lanes and a mutex that no longer exist, and stale prompts in a doc
this size cost more than they save.

**Deliberately carried forward:** the whole `feature/objects-overhaul` code tree — bump
meter, stamina, throw lock, out-of-circle countdown, prop smashes, spectator camera,
trajectory preview, status stack, prop attachments, and the AI rewrite. See § SALVAGE for
the state of each.

**Two things the previous session got wrong that this board fixes.** The gap between what
was *written* and what was *measured* was recorded honestly but never closed — so every box
here starts unticked regardless of whether code exists behind it. And the brief's "the can
may only stand up on the circle" was never implemented at all; it is now §1.9.

**Open and owned by the human alone:** playing it. Every feel number on this board — the
bump's metre, the 5 s punish, the circle countdown, whether the objects are fun — is a
first guess until it is played.
