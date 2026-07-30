# Agent Prompts — the pipeline, the checklist, the log

**Branch `feature/objects-overhaul-v2`, written 2026-07-31.** Replaces every earlier
version of this file. Nothing from the 3 289-line lane board or the nine-agent sequential
board survives here — those prompts described a world that no longer exists and they are
deleted, not archived.

**What this branch is.** `feature/objects-overhaul` was built in one uncontrolled session.
The *code* it produced is good and is carried here in full. The *process* is discarded and
replaced by the six `build xxx` lanes below, run in a fixed order. Read § SALVAGE before
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

**Worked example — spectator, which is `build ux`'s first item.** The camera exists and
today only `--spectate` starts it. It needs a **SPECTATE toggle button in the lobby**:
visible on the multiplayer lobby *and* on the pre-match setup screen, off by default,
showing its own state when toggled, releasing the seat, and carrying that choice into the
match.
`match_setup.gd` already builds one in code and it has never been rendered — start there,
finish it, and put one in `multiplayer_setup.gd` too.

---

## EXECUTION ORDER — fixed, not negotiable

Mechanics → Visuals → Physics → Fairness. A lane may not start until the one above it has
committed.

| # | Lane | Model · effort | Owns | Why this model |
|---|---|---|---|---|
| **1** | 🎮 **`build mech`** | **Opus 5 · high** | the rules of the game | Deletes the defence's only win and replaces the whole win-condition set. Novel rule design under ambiguity, no lookup-able answer, and getting the feel wrong here costs the video. |
| **2** | 💥 **`build abil`** | **Sonnet 5 · high** | the five object verbs | Exact radii, durations and host-side resolution against a spec that already exists. High, not medium: a shockwave that resolves on the wrong peer looks perfect solo and does nothing on LAN. |
| **3** | 🖥️ **`build ux`** | **Sonnet 5 · high** | every screen, spectator, the net teardown | Three of its items are races that only reproduce across peers. High because "it works on my machine" is the exact failure mode. |
| **4** | 🎨 **`build model`** | **Opus 5 · medium** | the lata and tsinelas classes, their models and their names | Upgraded 2026-07-31: it now authors real geometry, sets the roster size and names it. *"Does this silhouette read as a sardine tin from across a street, and is that name right in Filipino?"* is taste and cultural specificity — the one thing Sonnet was picked for not needing. Medium, not high: the difficulty is judgement per object, not depth on any one. |
| **5** | 🥊 **`build phys`** | **Sonnet 5 · high** | contact, knockback, ragdoll read | Executing against measured targets with a documented authority trap list. |
| **6** | ⚖️ **`build fair`** | **Opus 5 · xhigh** | every number, the AI | **LAST. ALWAYS.** The only lane allowed to move a shipped number, and the only one that can judge whether the objects are actually fun. Being wrong here costs the submission. |

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
| Can knockback ×2.6, `DOWNED_MAX_TIME` 2.0 | `character_base.gd` | written |
| Out-of-circle countdown + recovery stacks | `round_manager.gd` `CAN_OUT_*` | written, **this is the new primary win condition** |
| Can-Smash / Ground Smash | `scripts/abilities/prop_smash.gd` | written, no probe fires one |
| Can-Dash, self-launch | `character_base.gd`, `carriable.gd` | written |
| Spectator camera, seat −1 | `scripts/systems/spectator_camera.gd`, `--spectate` flag | boots, single-peer only |
| Trajectory preview | `scripts/systems/trajectory_preview.gd` | shares the real solve; nobody has looked at the line |
| Status stack + countdowns | `scripts/ui/hud.gd` | renders, no probe reads a row |
| Prop attachments + hanger | `character_visual.gd` `PROP_ATTACHMENTS` | **never rendered — no screenshot of any class exists.** And the base meshes under them are placeholders: one `lata.obj` and one `tsinelas.obj` for every class. See §4 |
| Tsinelas ×1.60 + capsule ×1.28 | `character_visual.gd`, `_COLLISION_BY_ROLE` | capsule measured by `settle_probe`, look unrendered |
| MAX POWER row | `character_select.gd` | `ui_layout_probe` 196/196 |
| AI rewritten for the new verbs | `ai_controller.gd`, +489 lines | parses, runs 70 s clean, **behaviour unmeasured** |

**Known gap, not built at all:** the lata may currently self-right anywhere. The brief says
it may only stand up **on the circle** — `character_base.gd::self_right()` has no home
check. That is `build mech` 1.9.

**Known conflict:** the brief says Can-Smash has a **3.0 s** base cooldown; the salvaged
code ships **8.0 s**. `build abil` decides and records which, in `Design.md` §11.

---

## PATHS — one writer per file

| Lane | Writes |
|---|---|
| 🎮 `build mech` | `characters/character_base.gd` · `carrier.gd` · `carriable.gd` · `hitbox.gd` · `hurtbox.gd` · `throw_profile.gd` · `systems/round_manager.gd` · `match_manager.gd` · `Design.md` |
| 💥 `build abil` | `scripts/abilities/**` · the ability hook sites in `character_base.gd` · `Design.md` §5.3/§6 |
| 🖥️ `build ux` | `scripts/ui/**` · `systems/spectator_camera.gd` · **`systems/camera_rig.gd`** · `trajectory_preview.gd` · `network_manager.gd` · `game_launch.gd` · `main.gd` · `settings_manager.gd` · `tools/ui/**` |
| 🎨 `build model` | `character_visual.gd` · `character_nameplate.gd` · `systems/character_roster.gd` `CANS`/`SLIPPERS` tables · `scenes/characters/visuals/**` · `assets/models/**` · `tools/models/**` · `Art_Direction.md` |
| 🥊 `build phys` | `character_base.gd` movement/collision block · `carriable.gd` flight · `tools/phys_probe.gd` · `settle_probe.gd` · `aim_probe.gd` |
| ⚖️ `build fair` | **any number in any file** · `systems/ai_controller.gd` · `tools/ai_probe.gd` · `hit_probe.gd` · `round_probe.gd` |

`character_base.gd` is touched by three lanes. Sequential order is the lock: `build mech`
writes it first and completely, `build phys` takes only the movement and collision block
after, `build fair` moves numbers last.

**Both cameras are 🖥️ `build ux`'s** — `spectator_camera.gd` (new, §3.1–3.2) and
`camera_rig.gd` (the gameplay camera). ⚠️ **The camera directive is not negotiable:** Person
→ first person, Prop → third person, derived from `is_person` at `_ready()`, no toggle, no
export, no per-map exception. The spectator is not an exception to it either — it is a
separate camera for a unit that has no body, not a third mode on the rig.

---

## CHECKLIST

`[x]` = built **and verified**, and say by what. `[~]` = built, unverified, and say what
specifically is unverified. Tick only your own section.

### 1 · 🎮 `build mech` — Mechanics *(Opus 5 · high)*

Defender
- [ ] 1.1 Tap-out / tag mechanic gone entirely, including its round-win branch
- [ ] 1.2 Bump power meter on left-click, mirroring the attacker's throw meter, **1.5× the attacker's charge time to fill**
- [ ] 1.3 Click = minor bump, mini knockback, no stun
- [ ] 1.4 Full hold = powerful bump: **~1 m** knockback, **drops the attacker's tsinelas far away**, short hit stun + movement penalty
- [ ] 1.5 Wind-up is visible on **every peer**, so the commitment can be played around
- [ ] 1.6 Stamina: sprint is a finite resource, base speed cut so the game is not run-forever

Attacker
- [ ] 1.7 Throw cooldown on pickup (1–2 s, you decide) — kills in-circle spam
- [ ] 1.8 Throws from **behind the throwing line** are stronger; a max-power one that lands on the taya applies a **5 s** hit stun

Lata
- [ ] 1.9 **The lata may only stand up while on the circle.** Not built — `self_right()` has no home check
- [ ] 1.10 High knockback susceptibility: a solid hit displaces it ~1 m rather than dropping it in place
- [ ] 1.11 Actively fights to stay upright; **cannot be down longer than 2 s**
- [ ] 1.12 Game over is the countdown, not the knockdown: **5 s outside the circle** loses the round
- [ ] 1.13 Each recovery back inside permanently shortens the **next** countdown by **0.75 s**, stacking **5×** to a floor of **1.25 s**
- [ ] 1.14 The defence has a real answer to a displaced lata it cannot itself move

### 2 · 💥 `build abil` — Abilities *(Sonnet 5 · high)*

- [ ] 2.1 **Can-Smash** — ground smash, shockwave in a stated radius, **1–2 s** stun on incoming slippers and players, telegraphed wind-up. Base cooldown: resolve 3.0 s (brief) vs 8.0 s (code) and record why
- [ ] 2.2 **Can-Dash** — one evasion per round
- [ ] 2.3 **Ground Smash** — the tsinelas dives downward, shockwave on landing, stun on hit, cooldown
- [ ] 2.4 **Ground Smash direct hit on the lata = the attacking side wins instantly**, and it is bounded on more than one side
- [ ] 2.5 **Charged self-launch** — a loose tsinelas charges a mini-jump and flings *itself*
- [ ] 2.6 Every shockwave resolves **host-side** through `AbilityUtils.spawn_pulse_hitbox`
- [ ] 2.7 The six roster skin abilities still work beside the new role verbs

### 3 · 🖥️ `build ux` — Screens, spectator, teardown *(Sonnet 5 · high)*

**Do 3.1 and 3.2 first.** Everything in this section is bound by the REACHABILITY RULE.

- [ ] 3.1 **A SPECTATE toggle button in the lobby** — on the multiplayer lobby *and* the pre-match setup screen, in the focus order, showing its own state, in Single Player and Multiplayer, host and client. Rendered and looked at
- [ ] 3.2 **Spectator mode** — free-flying camera, no physical model, clips through all geometry; claims no seat, excluded from the ready gate, its slot bot-filled. Entered from 3.1, not from `--spectate`
- [ ] 3.3 **UI countdown for every stun and status effect** — a stun the player cannot time is a stun they cannot play around
- [ ] 3.4 **Character-select desync** — lata and tsinelas picks reliably reach the match on every path: solo, host, client, and an AI-held Prop seat beside a human. The model must not change mid-match
- [ ] 3.5 **Host disconnect** — the host announces it is leaving before closing the socket; clients bounce out immediately instead of waiting out the ENet timeout. Wired to the quit dialog
- [ ] 3.6 **Trajectory preview** visible for throws and charge-ups, integrating the *same* solve the throw uses
- [ ] 3.7 Charge/meter readouts for the bump meter, the stamina bar and the throw lock
- [ ] 3.8 Max power shown in the custom slipper description
- [ ] 3.9 **Sweep for orphans.** Every system the other lanes built has a menu entry point a player can find — spectator, hanger, skins, stamina, the smash cooldowns. Anything reachable only by flag or autoload is filed here and fixed

### 4 · 🎨 `build model` — Models, classes and names *(Opus 5 · medium)*

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

- [ ] 4.1 **A lata base mesh per class, each recognisably a specific Filipino tin** — the silhouette does the work, not the tint. Sardinas, gatas, biskwit, pintura, kape, softdrink: all different profiles, all readable from across the arena
- [ ] 4.2 **A tsinelas base mesh per class, with genuinely different shapes** — a bakya is a carved wooden clog, not a tinted rubber flip-flop. Render the tsinelas types real Tumbang Preso is played with
- [ ] 4.3 **Every class is Filipino-themed and newly named by you** — the `name` field in Filipino, specific enough that a player from the street recognises it. **Taglines and everything else stay English.** Rewrite `CANS` / `SLIPPERS` in `character_roster.gd`
- [ ] 4.4 **The roster size is your call** — final count of lata and tsinelas classes decided, justified in § LOG, and consistent everywhere an index is assumed
- [ ] 4.5 Tsinelas **visibly bigger** in game
- [ ] 4.6 A **hanger** in tsinelas customisation that provably cannot affect physics
- [ ] 4.7 Junk and wear still bolted on per class where it adds character — the attachment system stays, it just stops carrying the whole job alone
- [ ] 4.8 **Render every class and look at it.** Nothing here is `[x]` without a screenshot
- [ ] 4.9 Every class reads at gameplay camera distance, not just in the preview
- [ ] 4.10 Collision is unchanged by any of it — `_COLLISION_BY_ROLE` still sizes every shape, and the dent meshes still line up with the new lata

### 5 · 🥊 `build phys` — Contact and readability *(Sonnet 5 · high)*

- [ ] 5.1 **Waiting-screen phasing** — objects no longer pass through each other pre-round
- [ ] 5.2 Can knockback **measured**, not predicted, against the ~1 m target
- [ ] 5.3 **A knocked-down lata visibly rolls.** The current read — "hard to tell it fell" — is the bug being fixed
- [ ] 5.4 Collision tuning for the enlarged tsinelas: capsule, hurtbox and hitbox all agree with the new visual scale
- [ ] 5.5 Bump displacement measured for tap and full charge
- [ ] 5.6 The preview arc and the thrown arc land in the same place

### 6 · ⚖️ `build fair` — Balance and AI *(Opus 5 · xhigh)* — **RUNS LAST, ALONE**

- [ ] 6.1 A fairness run **on this branch**. No number for these rules exists yet; none may be quoted until it does
- [ ] 6.2 The Defender is no longer the strongest role — proven by win rate, not by argument
- [ ] 6.3 The objects have equal presence: a round can be decided by the lata or the tsinelas without either Person acting
- [ ] 6.4 Final pass on every cooldown, stun duration, hit penalty and meter
- [ ] 6.5 **No stunlock.** Prove it by naming the chain, not by asserting it
- [ ] 6.6 Named counterplay for every powerful object action
- [ ] 6.7 The AI uses every new verb — bump meter, smash, dash, dive, self-launch, sprint, and driving the lata home
- [ ] 6.8 Legacy AI constants derived from the old `SPEED = 6.0` re-derived or explicitly kept

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

<details><summary>💥 <b><code>build abil</code></b> — Abilities · Sonnet 5 · high</summary>

> Same project, same branch, same reading rules. Your tasks are § CHECKLIST §2, and the
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
> durations and cooldowns — record each decision. Tick §2, append to § LOG.
> Do not spawn subagents.

</details>

<details><summary>🖥️ <b><code>build ux</code></b> — Screens, spectator, teardown · Sonnet 5 · high</summary>

> Same project, same branch, same reading rules. Your tasks are § CHECKLIST §3.
>
> **Why you exist.** A gameplay video is being recorded off this branch. Three things
> currently spoil it: a player cannot see how long they are stunned, the character the
> player picked is not the character that loads, and there is no way to film the match
> from outside it.
>
> **§ THE REACHABILITY RULE applies to every line you write.** A screen nobody can get to
> is not a feature. Name the entry point first, wire it in the same commit, render it and
> look at it.
>
> Five pieces of work, **spectator first**:
> * **Spectator mode, entered from a SPECTATE toggle button in the lobby.** The camera
>   itself exists (`spectator_camera.gd`) and today only the `--spectate` command-line flag
>   starts it, which is exactly the failure the rule above describes. Put a real toggle on
>   the multiplayer lobby and on the pre-match setup screen — `match_setup.gd` already
>   builds one in code that has never been rendered. Free-flying camera, no body, no
>   collision, clips through everything, Single Player and Multiplayer. Seat −1: no seat
>   claimed, out of the ready count, slot bot-filled. It has never run beside a real second
>   peer.
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
> Prefer building controls in code over editing a `.tscn`. Tick §3, append to § LOG.
> Do not spawn subagents.

</details>

<details><summary>🎨 <b><code>build model</code></b> — Models, classes and names · Opus 5 · medium</summary>

> Same project, same branch, same reading rules. Your tasks are § CHECKLIST §4; the laws
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
> Tick §4, append to § LOG. Do not spawn subagents.

</details>

<details><summary>🥊 <b><code>build phys</code></b> — Contact and readability · Sonnet 5 · high</summary>

> Same project, same branch, same reading rules. Your tasks are § CHECKLIST §5.
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
> bug. It has caught five harness faults here already. Tick §5, append to § LOG.
> Do not spawn subagents.

</details>

<details><summary>⚖️ <b><code>build fair</code></b> — Balance and AI · Opus 5 · xhigh — <b>RUNS LAST</b></summary>

> Same project, same branch, same reading rules. You are the **final lane**. Nothing runs
> after you. Do this directly in one focused pass and **do not spawn subagents**.
>
> Your tasks are § CHECKLIST §6, and you have final authority over **every number in the
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
> Tick §6, append to § LOG, and say plainly which conclusions are **measured** and which
> are **argued**.

</details>

---

## LOG

Newest first. One entry per lane run: what changed, what was **measured** versus written,
what decision you made and why, and what you are handing the next lane. Short.

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
