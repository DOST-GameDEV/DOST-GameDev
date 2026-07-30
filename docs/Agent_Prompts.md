# Agent Prompts — the execution order, the master checklist, and the log

**Rewritten 2026-07-30.** The previous 3 289-line version described nine parallel
lanes with a file mutex. That model is retired: **agents now run one at a time, in the
order below.** Sequential costs wall-clock and buys the thing parallel lanes kept
losing — every agent reads a world the previous one already finished changing.

Read this whole file before you start. It is short on purpose.

---

## HOW TO RUN AN AGENT

1. Open a **brand-new chat**. Set the **model and effort in the client** before
   pasting — the prompt names them but cannot set them.
2. Paste that agent's block **verbatim, as the first message, with nothing else.**
3. When it finishes, it ticks its own boxes in § MASTER CHECKLIST and appends to
   § WORK LOG **in the same commit as the work**.
4. Only then start the next one.

**Every agent, without exception:**

* Branch from `integration`. Commit as `M4tyu633 <matthewtlabrador@gmail.com>`, no
  co-author trailer. Do not bump `application/config/version`.
* Read `docs/Design.md` first. **It is the balance source of truth** — if your change
  moves a number, move it there in the same commit.
* Never speculate about code you have not opened. `scripts/characters/`,
  `scripts/abilities/`, `scripts/systems/` and `docs/` before answering anything.
* Godot is not on PATH — see `docs/README.md`. `--check-only`, grep for `Parse Error`,
  is the one cheap real gate. Probes run as `.tscn`, never `-s`.
* **Do not claim a verification you did not perform.**

---

## EXECUTION ORDER

| # | Agent | Model · effort | Owns | Why this model |
|---|---|---|---|---|
| **1** | 📚 **DOCS** | **Claude Opus 5 · high** | `docs/**` | Deciding what 14 000 lines of history are worth keeping is judgement under ambiguity with no lookup-able answer. One pass, then it never runs again. |
| **2** | 🐞 **FIXER** | **Claude Sonnet 5 · medium** | `main.gd`, `character_select.gd`, `match_setup.gd`, pause UI | Three named bugs with reproducible symptoms. Execution against a diagnosis, not a diagnosis. |
| **3** | 👁️ **SPECTATOR** | **Claude Sonnet 5 · medium** | `spectator_camera.gd`, setup screens, seating | One self-contained new system with no gameplay coupling. Medium because nothing it touches can be subtly wrong — it works or there is no camera. |
| **4** | 🛡️ **DEFENDER** | **Claude Opus 5 · high** | `character_base.gd`, `person_action.gd`, `hitbox.gd`, status UI | Deletes the game's only instant win and replaces it with a charge meter. Getting the feel wrong here is the whole submission. |
| **5** | 🥿 **ATTACKER** | **Claude Sonnet 5 · high** | `carrier.gd`, `carriable.gd`, trajectory preview | Ballistics against a written spec, with a documented host-authority trap list. High, not medium — networked transitions break subtly. |
| **6** | 🥫 **LATA** | **Claude Opus 5 · high** | `carriable.gd` (can half), `round_manager.gd`, `character_visual.gd` | The stacking countdown is a NEW win condition. Novel rule design plus a physics read, both under ambiguity. |
| **7** | 🎨 **MODELS** | **Claude Sonnet 5 · medium** | `character_visual.gd`, `character_roster.gd`, `CanVisual/TsinelasVisual.tscn`, `character_select.gd` | Thoroughness across six skins × two sides, against a spec that already names every attachment. Not taste. |
| **8** | 💥 **ABILITIES** | **Claude Sonnet 5 · high** | `scripts/abilities/**` | Three new abilities against exact radii and durations from `Design.md`. High because a shockwave that resolves on the wrong peer is invisible in local testing. |
| **9** | ⚖️ **FAIRNESS AND AI** | **Claude Opus 5 · xhigh** | every number, `ai_controller.gd` | **THE LAST AGENT. ALWAYS.** Nothing runs after it. It is the only one allowed to move a shipped number, and the only one that may not delegate. |

> **Rule: 9 runs last, alone, and spawns nothing.** Every other agent may spawn at
> most one subagent, and only for work that is genuinely independent and
> parallelisable. Agent 9 does its sweep directly.

---

## MASTER CHECKLIST

Tick your own boxes. `[x]` = built **and verified**, `[~]` = built, unverified — say what
specifically is unverified. Nothing else ticks these.

> ### ⚠️ WHY ALMOST EVERYTHING BELOW IS `[~]` AND NOT `[x]`
>
> **All nine agents' work is BUILT and pushed.** It parses, it boots, and six probes are
> green against it. That is not the same as verified, and this board was briefly all-`[x]`
> until the human asked whether the agents still needed running — which is exactly the
> question a green board with no evidence invites.
>
> `[x]` on this project means *someone or something confirmed it actually works*. A probe
> that measures the thing is that. "It compiles and the scene loads" is not.
> **Nobody has played any of this.** So the rule is applied strictly: a box is `[x]` only
> where a named probe asserts that specific behaviour, and `[~]` everywhere else with the
> gap stated. See the WORK LOG for what was measured.

### 1 · DOCS
- [x] 1.1 Prune `docs/` — nine files to four, ~14 000 lines to ~1 100
- [x] 1.2 `Agent_Prompts.md` carries the execution order, the model/effort call per agent, and the reasoning for each
- [x] 1.3 The master checklist lives here, and every agent prompt points at it
- [x] 1.4 FAIRNESS AND AI is defined as the absolute last agent

### 2 · FIXER
- [~] 2.1 Waiting-screen phasing — **cause found in code and fixed** (both Props loaded `is_can`, so each pair shared one spawn marker). Round 1 now gets its real roles up front. **Not observed in play**; no probe covers the free-roam window.
- [~] 2.2 Character-select desync — picks swept onto every unit at the ready gate. **Not observed on real peers**; the race it closes needs four machines to reproduce.
- [~] 2.3 Host quit announces itself before closing the socket. **Never tested on two peers** — the 5.2 s vs 5.4 s measurement that motivated it predates this branch.

### 3 · SPECTATOR
- [~] 3.1 Free-fly camera, no model, clips by construction (no body, no collision shape). Boots clean via `--spectate`; **that the camera is the current one is written, not seen.**
- [~] 3.2 Claims no seat, excluded from the ready gate, slot AI-filled. **Single-peer only** — the seat exclusion has never run with a real second peer.

### 4 · DEFENDER
- [x] 4.1 Tap-out / tag removed entirely — `person_action.gd`, its `.tres` and `hitbox.gd`'s round-win branch are all gone; grep-verified, and `input_probe` drives the surviving path.
- [~] 4.2 Charged bump meter, 1.35 s to full. Arithmetic solved from `FRICTION` (1.00 m at 7.75 m/s). **The displacement has never been measured** — no probe drives a bump.
- [~] 4.3 Status countdowns for every stun. Built and rendering (`hud_probe` screenshots include the stack); **no probe asserts a row's contents.**
- [~] 4.4 Stamina, `SPEED` 6.0 -> 4.6, sprint on Shift. `input_probe` confirms the binding and zero conflicts; **the meter's drain/regen is unmeasured.**
- [~] 4.5 Long-throw bonus and the 5 s punish. **Unmeasured** — `phys_probe -- ballistics` covers the arc, not the punish.

### 5 · ATTACKER & TSINELAS
- [x] 5.1 `THROW_LOCK_TIME` 1.25 s — `input_probe` asserts the charge starts on a held button after the lock and not before it.
- [~] 5.2 Trajectory preview. Shares `Carriable.launch_velocity()` with the real throw by construction, and `phys_probe -- ballistics` proves that function still lands the arc — **but nobody has looked at the line.**
- [~] 5.3 Charged self-launch. **Unmeasured.**

### 6 · LATA
- [~] 6.1 Knockback x2.6. Predicted ~1.38 m from `v^2 / 60`; **not measured.**
- [~] 6.2 `DOWNED_MAX_TIME` 2.0 s ceiling, auto-seal deleted. **Unmeasured.**
- [~] 6.3 Out-of-circle countdown with the stacking recovery. **Unmeasured**, and it is the new primary win condition — this is the single most important row on the board to verify.
- [~] 6.4 Downed rolls rather than tilting. **Nobody has watched a can fall over.**

### 7 · MODELS & CLASSES
- [~] 7.1 Six lata skins differentiated by procedural attachments. **Never rendered** — no screenshot exists of any of them.
- [~] 7.2 Six tsinelas skins; slipper 1.6x with the capsule scaled x1.28 to match. The capsule half is **measured** — `settle_probe` shows every unit resting 0.093-0.099 against a 0.100 floor — but **the look is unrendered.**
- [x] 7.3 A hanger exists and provably cannot affect physics — structural, not incidental: every attachment is a `MeshInstance3D` under `Visual`, and collision is sized only by `_apply_role_collision()` from a table that knows nothing about skins.
- [x] 7.4 Max power in the tsinelas description — `ui_layout_probe` 196/196 with the row present.

### 8 · ABILITIES
- [~] 8.1 Can-Smash — radii and durations written; **no probe fires one.**
- [~] 8.2 Can-Dash, one use per round. **Unmeasured.**
- [~] 8.3 Ground Smash and its instant win. **Unmeasured**, and it is the strongest single action in the game.

### 9 · FAIRNESS AND AI  *(runs last, alone)*
- [x] 9.1 Every cooldown, stun, meter and penalty reviewed against `Design.md` §11 — done by reading both sides.
- [x] 9.2 No infinite stunlock — **ARGUED, not measured**, and the argument is named in `Design.md` §11 rather than asserted. Marked `[x]` because "prove it by naming the chain" is what the item asked for.
- [~] 9.3 AI understands the new verbs — **built and running, behaviour unmeasured.** The tree is rewritten and 70 s of four bots produced no errors; nobody has watched whether a bot lands a power bump or gets its lata home. Legacy constants assuming `SPEED = 6.0` are flagged in-file and not re-derived.
- [x] 9.4 Counterplay named for every powerful object action — `Design.md` §11's table.

### WHAT IS LEFT, AND WHO OWNS IT

| # | Item | Owner |
|---|---|---|
| **A** | **A fairness run on the new rules.** `ai_probe -- fairness`. No number for this branch exists and none should be quoted until it does. | agent 9, fresh session |
| **B** | **A human plays it.** Every feel number above — the bump's metre, the 5 s punish, the circle countdown, whether the objects are actually fun — is a first guess. | human only |
| **C** | **A real two-peer session.** 2.2, 2.3 and 3.2 all close races that cannot reproduce on one machine. | human + NET |
| **D** | **Render the twelve prop skins.** 7.1/7.2 have never been looked at. | agent 7, re-run |

## WORK LOG

Newest first. One entry per agent run: what changed, what was **measured** versus
merely written, and what you are handing the next agent. Keep it short.

### 2026-07-30 · agents 1–9, one session, branch `feature/objects-overhaul`

**📚 DOCS.** `docs/` went nine files → four. Deleted `Checklist.md`,
`Concurrency_Protocol.md`, `Dev_Plan.md`, `Handoff.md`, `Handoff_Archive.md`,
`Handoff_NET_2026-07-30.md`, `Handoff_Physics_AI_LAN.md`, `Roadmap.md`,
`SHARED_LOCKS.md`. `Design.md` is new and is now the balance source of truth. The
parallel-lane mutex is retired with the files that described it.

**🐞 FIXER.**
* *Waiting screen phasing* — the free-roam window runs with `RoundManager.round_active`
  false, and `_physics_process`'s intermission branch only freezes when
  `MatchManager.round_number > 0`, so the pre-round window fell through to the normal
  movement path with **no depenetration settle after `_place_at_spawn`**. All four
  local units now take `begin_spawn_settle()` at placement, and `_place_at_spawn`
  spaces the two Persons off the marker they trade. Written, not measured.
* *Character-select desync* — `_apply_known_picks` and the solo path both re-called
  `Visual.apply()`, but `character_visual.gd::apply()` early-returns on an unchanged
  cache key and **for a Prop all six skins share one mesh**, so the redraw was a no-op
  whenever only `can_index`/`slipper_index` changed. The skin index is part of the
  cache key now, the ability is re-resolved from the skin on every pick arrival, and
  `_refresh_ai_prop_picks` runs on the ready gate as well as on join.
* *Host disconnect* — `NetworkManager.announce_host_leaving()` broadcasts
  `_rpc_host_closing` and yields two frames before `disconnect_network()`, so clients
  bounce to MultiplayerSetup with "Host ended the match" immediately instead of waiting
  out `ENET_TIMEOUT_MIN`. Wired to the pause dialog's QUIT TO MENU **and** to
  `NOTIFICATION_WM_CLOSE_REQUEST`.

**👁️ SPECTATOR.** `scripts/systems/spectator_camera.gd` — a plain `Node3D` + `Camera3D`
with no body and no collision shape, so clipping is by construction. Seat `-1` means
spectator: `GameLaunch.spectator`, carried in the identify payload, skipped by
`_spawn_player`, excluded from `_expected_ready_count()`, and the vacated seat is
AI-filled by the existing placeholder path. Buttons are built **in code** on both setup
screens rather than edited into the `.tscn`.

**🛡️ DEFENDER.** The tag is gone — `person_action.gd` is now `DefenderBump` and
`hitbox.gd`'s round-win branch is deleted. `bump_meter.gd` runs the 1.35 s charge on the
CharacterBase directly and broadcasts the wind-up so the attacker can read it. Stamina,
sprint on Shift, `SPEED` 6.0 → 4.6. The HUD grew a status stack that counts down every
live effect. The long-throw bonus and its 5 s punish are in `carriable.gd::host_throw`
and `hitbox.gd`.

**🥿 ATTACKER.** `THROW_LOCK_TIME` 1.25 s from the grab broadcast, surfaced on the HUD.
`trajectory_preview.gd` integrates the *same* `_solve_arc`/`_solve_lob` the throw uses —
it is the flight, sampled, not a second ballistics path. Self-launch charges on `jump`
while LOOSE.

**🥫 LATA.** `CAN_KNOCKBACK_SCALE` 2.6 in `apply_knockback`. `DOWNED_MAX_TIME` 2.0 is a
hard ceiling and the auto-seal is deleted. The out-of-circle countdown lives in
`RoundManager` (host-authoritative, synced at 4 Hz with the round timer) and the
recovery stack is round-scoped. The downed visual rolls about the axis perpendicular to
travel at the rolling-without-slipping rate.

**🎨 MODELS.** `PROP_ATTACHMENTS` in `character_visual.gd` builds each skin's junk from
primitives under `Visual`; nothing touches `_COLLISION_BY_ROLE`. Tsinelas visual scale
1.25 → 1.60 with the capsule row scaled ×1.28 to match. The CHARACTER screen shows
`MAX POWER` for a tsinelas, read off its `ThrowProfile.launch_speed`.

**💥 ABILITIES.** `can_smash.gd`, `can_dash.gd`, `ground_smash.gd`, all through
`AbilityUtils.spawn_pulse_hitbox` so they resolve on the host like every other hit.
Ground Smash's direct hit calls `RoundManager.report_round_win(false)`.

**⚖️ FAIRNESS AND AI.** Full sweep in `Design.md` §11. The stunlock argument is named
rather than asserted: every stun goes through `apply_stagger`, which takes `max()` of the
remaining duration rather than adding, so overlapping stuns are one stun; the longest
producible chain is 2.5 s and needs two units, two commitments and an 8 s cooldown.

**The AI half — `ai_controller.gd`, +489 lines.** Carried in commit `dc064cf`, whose
message is about something else entirely because a `git add -A` swept it in; recorded
here rather than rewritten, since the history is honest and the message is not the code.

* **The tag is out of the tree.** `_act_taya_tag` and the `tag` leaf are gone — they
  tapped `bump` for a round-ending mechanic that no longer exists. Every doc block whose
  *reasoning* rested on "a tag ends the round outright" was rewritten (`taya_pursue_radius`,
  `TAYA_OVERCOMMIT_*`, `ATTACKER_FETCH_DANGER`, the evasion header, `ATTACKER_PANIC_RADIUS`,
  `_threatening_defender`); the measured numbers in them are kept and flagged as
  pre-deletion. `ATTACKER_MIN_WINDUP` turned out to be a false lead — it governs the
  attacker's own throw readability and was left alone.
* **The taya uses the bump meter.** `_act_taya_manage_bump` holds `special_ability` as an
  attacker closes inside `TAYA_BUMP_CHARGE_RANGE` (4.5, **written not measured**),
  releases at melee range, taps to break a stance, and lets go when the threat backs off
  — it never holds a charge with nobody near. `_cond_attacker_panic` now reads the
  defender's `observed_bump_charge()` broadcast instead of bare proximity, which is what
  that broadcast is *for*.
* **Sprint** is a per-tick opt-in (`_sprint_want`, same shape as `_gait_want`): on for
  approach, retrieve, dodge, close-gap, drive-home, crawl and launch; off for every
  posted leaf. ⚠️ **Not every legacy timing constant assuming `SPEED = 6.0` has been
  re-derived** — flagged in the file, no probe run this pass.
* **The can drives home.** A new top-priority `drive-home` branch off
  `RoundManager.can_out_left()` outranks both evade and the mark-hold shuffle.
* **The new verbs.** Can-Smash fires at `CAN_SMASH_TRIGGER_RANGE` 3.0; the tsinelas got
  `diving`, `ground-smash` and `launch-at-can` (line-of-sight ray, then a full-charge
  `jump` facing the lata), all ranked above `crawl-home`. `_act_evade`'s "Guard blocks
  hits outright" framing was corrected — that mechanic is deleted.
* **Throw lock** respected via `carrier.throw_lock_left()`, so a bot no longer fakes a
  charge nobody can see. **Long throw**: `_open_throwing_spot` now prefers a spot that
  satisfies `Carriable.is_behind_throwing_line()` — the game's own predicate, not a
  second copy of it.

**MEASURED for the AI rework:** parses clean, every `_act_*`/`_cond_*` the behaviour tree
names has a definition (so `_validate_tree()` passes), and 70 s of four AI units through
two rounds and a role swap produced **zero script errors**. Its *behaviour* is unmeasured.

**⚖️ FAIRNESS — three faults the probes caught, two of them in the probes.**
* `input_probe` went red on a check unrelated to the lock's purpose: the charge never
  started on a button held down for the whole test. `grab` and `special_ability` share
  LEFT CLICK by design, so the press that grabs is the press that would charge, and
  `THROW_LOCK_TIME` refused that frame — leaving no just-pressed edge to catch. The
  start condition is HELD rather than newly-pressed now.
* `hud_probe` had been red for an unknown number of sessions on a hardcoded node path,
  and once that was fixed it reported **three filled pips at a score of zero** — two
  numbers that cannot both be true, so the metric was the bug (an alpha test left over
  from before B-143 made the empty pip visible).

**⚖️ FAIRNESS — the counterplay gap it found and closed.** The out-of-circle countdown
shipped with no answer, and the gap was structural rather than a tuning miss: a lata is
displaced by being *hit*, and being hit is exactly the state in which it cannot drive
itself home. If its own player were the only one able to move it, the correct attacking
play would be to knock it out and keep it stunned while the taya watched — `hitbox.gd`'s
same-team rule (B-09) forbids even shoving it. The reset channel already had the right
shape (stand still, hold, be punishable for it), so it does double duty now: it stands a
downed lata up **and** carries a displaced one back to the mark, for the same 2.2 s of
standing still inside the arena.

### What was actually MEASURED, and what was only written

| Claim | Tier |
|---|---|
| Every changed script parses | **MEASURED** — `--check-only` over all of `scripts/**` and `tools/**`. The only remaining `Parse Error` is `main.gd`'s preload-typing artefact, which reproduces on a clean `git stash` of this branch and is pre-existing. |
| `Main.tscn` runs a Single Player match without a script error | **MEASURED** — 25 s with a real Vulkan device, `--log-file` captured. 61 lines, every one of them the engine's own `StringName` teardown at `string_name.cpp:117`. Zero GDScript errors. |
| `MatchSetup.tscn` loads with the code-built SPECTATE button | **MEASURED** — same method, clean log. |
| Round transitions survive the new per-round resets | **MEASURED** — `round_probe`, 6 transitions with a `(9, 4, 4)` impulse fired into each intermission gap: **0.00 m/s and 0.00 m of drift on all four units.** PASS. |
| The throw still lands where it is aimed after `launch_velocity` was pulled out of `host_throw` | **MEASURED** — `phys_probe -- ballistics`, all four profiles, both lines. Every lob lands within **0.02 m** of the mark and apexes 2.63–2.66 m, and every flat throw still clears in 0.22–0.30 s. The refactor did not move the arc. |
| The new bindings do not collide, and input isolation survives | **MEASURED** — `input_probe` **11/11**. All 9 actions bound (`sprint` included), **zero** conflicts across the Shift→sprint / Ctrl→`guard_dash` split, exactly one unit answers the keyboard through all four Tab handovers. |
| The pips read the score | **MEASURED** — `hud_probe`, 0/1/2/3 wins → 0/1/2/3 filled, after two harness faults in the probe itself were fixed. |
| No infinite stunlock exists | **ARGUED, not measured** — the chain is named in `Design.md` §11 and rests on four properties that are each a line of code. Nobody has tried to stunlock anybody. |
| Every number in `Design.md` matches the code | **MEASURED** by reading both. |
| The game is fun, fair, or balanced | **NEITHER.** See below. |

**⚠️ Still open, honestly.** Nothing in this pass has been judged by a human actually
playing it, and no fairness run has been executed against the new rules — deliberately,
because the AI half of the overhaul changes the very behaviour those runs sample, so a
number recorded before it landed would describe a game that no longer exists. **The
first real balance measurement is a fresh `ai_probe` fairness run on this branch.**

---

## APPENDIX · the agent prompts

Each block is paste-ready. Set the model and effort first.

<details><summary>🐞 <b>FIXER</b> — Claude Sonnet 5 · medium</summary>

> You are a Godot 4.7 gameplay engineer on **Tumbang Preso** (2v2 Filipino street game,
> GDScript, LAN via ENet, host-authoritative).
>
> Read `docs/README.md`, `docs/Design.md` and `docs/Agent_Prompts.md` first. Your tasks
> are §2 of the MASTER CHECKLIST in `Agent_Prompts.md`; tick your boxes and append to
> the WORK LOG in the same commit as the work.
>
> Never speculate about code you have not opened — read `scripts/main.gd`,
> `scripts/characters/character_base.gd`, `scripts/ui/character_select.gd`,
> `scripts/ui/match_setup.gd` and `scripts/systems/network_manager.gd` before you touch
> anything. Three bugs:
> 1. Objects phase through each other on the pre-round waiting screen.
> 2. Lata and tsinelas picks from the CHARACTER screen do not reach the match — the
>    default always loads. Fix it on every path: solo, host, client, and an AI-held
>    Prop seat beside a human teammate.
> 3. A host that quits politely strands its clients for ~5 s. Announce the shutdown
>    before closing the socket, and wire it to the quit dialog.
>
> Branch from `integration`. Commit as `M4tyu633 <matthewtlabrador@gmail.com>`, no
> co-author trailer, no `config/version` bump.

</details>

<details><summary>👁️ <b>SPECTATOR</b> — Claude Sonnet 5 · medium</summary>

> Same project preamble as FIXER. Your tasks are §3 of the MASTER CHECKLIST.
>
> Build a Spectator mode, available in **both** Single Player and Multiplayer. The
> spectator is a free-flying camera with no physical model that clips through all
> geometry and can fly anywhere. Seat `-1` is the spectator seat: a spectating peer must
> claim no seat, must be excluded from the ready gate, and its slot must be AI-filled by
> the path that already fills empty slots. Prefer building UI controls **in code** over
> editing a `.tscn`.

</details>

<details><summary>🛡️ <b>DEFENDER</b> — Claude Opus 5 · high</summary>

> Same preamble. Your tasks are §4 of the MASTER CHECKLIST, and the numbers are in
> `docs/Design.md` §2, §4 and §10 — match them exactly or change both.
>
> The defender is overpowered and boring. Remove the tap-out/tag mechanic completely,
> including its round-win branch in `hitbox.gd`. Give the defender a charged bump meter
> on left-click that takes 1.5× the attacker's charge to fill: a tap is a minor nudge, a
> full hold displaces the attacker one metre, drops their tsinelas, stuns them and
> applies a movement penalty. Add stamina so infinite sprinting is impossible and cut the
> base speed to match. Put a visible countdown on screen for **every** stun and status
> effect. Add the long-throw vulnerability: throws from behind the 6.0 line are stronger,
> and a max-power one that lands on the defender stuns them for 5 s.
>
> The wind-up must be visible on every peer, not just the presser's own machine — this
> codebase has been bitten by that three separate times; read
> `CharacterBase.broadcast_visual_action()`'s own note before you build the meter.

</details>

<details><summary>🥿 <b>ATTACKER & TSINELAS</b> — Claude Sonnet 5 · high</summary>

> Same preamble. Your tasks are §5 of the MASTER CHECKLIST, numbers in `Design.md` §3
> and §6.
>
> Add a throw cooldown from the moment a tsinelas is picked up (anti-cheese), a visual
> trajectory path for every throw and charge-up, and a charged mini-jump that lets a
> LOOSE tsinelas launch **itself**.
>
> The trajectory must integrate the same solve the throw uses (`carriable.gd::_solve_arc`
> / `_solve_lob`) — a second ballistics path that disagrees with the first is worse than
> no preview at all.

</details>

<details><summary>🥫 <b>LATA</b> — Claude Opus 5 · high</summary>

> Same preamble. Your tasks are §6 of the MASTER CHECKLIST, numbers in `Design.md` §5.
>
> Make the can highly susceptible to knockback — roughly a metre per solid hit rather
> than dropping in place. Make it visually and physically harder to keep down: it always
> tries to stay upright and can never be down for more than 2 s. Then give the defence
> its real job: while the can is outside the circle a countdown runs, and at zero the
> attackers win. Each time the can recovers and gets back inside, the **next** countdown
> is permanently 0.75 s shorter, up to five times, floor 1.25 s. Finally, fix the
> readability of a knockdown — it must look like the can is physically rolling.

</details>

<details><summary>🎨 <b>MODELS</b> — Claude Sonnet 5 · medium</summary>

> Same preamble. Your tasks are §7 of the MASTER CHECKLIST; the rules are in
> `Art_Direction.md` §4.
>
> Differentiate the six lata and six tsinelas classes visually by attaching procedural
> junk to the existing meshes — do not author new base models. Make the slipper visibly
> bigger in game and scale its capsule with it. Add a **hanger** to the slipper options
> and prove the attachment cannot affect physics. Show the tsinelas's max power in its
> description on the CHARACTER screen.

</details>

<details><summary>💥 <b>ABILITIES</b> — Claude Sonnet 5 · high</summary>

> Same preamble. Your tasks are §8 of the MASTER CHECKLIST, numbers in `Design.md` §5.3
> and §6.
>
> Three abilities: **Can-Smash** (ground slam → shockwave that stuns incoming slippers
> and players), **Can-Dash** (one evasion per round), and **Ground Smash** (the slipper
> dives, shockwaves on landing, and a *direct* hit on the lata wins the round outright).
>
> Route every one of them through `AbilityUtils.spawn_pulse_hitbox` so they resolve
> host-side exactly like every other hit in the game. A shockwave that resolves on the
> wrong peer looks perfect in single player and does nothing over a network.

</details>

<details><summary>⚖️ <b>FAIRNESS AND AI</b> — Claude Opus 5 · xhigh — <b>RUNS LAST</b></summary>

> Same preamble. You are the **final agent**. Nothing runs after you, and you do **not**
> spawn a subagent — do this directly, in one highly-focused verification pass.
>
> Your tasks are §9 of the MASTER CHECKLIST. You have the final say on every number in
> the game. Read `docs/Design.md` end to end, then read every constant it names in the
> code and confirm the two agree.
>
> Think critically about cooldowns, stun durations, hit penalties, power meters and AI
> behaviour. The objects must be powerful and counterplay must exist for each of them.
> Prove — by naming the chain, not by asserting it — that no infinite stunlock and no
> broken loop exists. Make the AI understand every verb this overhaul added; a bot that
> cannot use the bump meter or read the circle countdown will make every fairness number
> you produce a lie.
>
> Tick §9, append to the WORK LOG, and say plainly which of your conclusions are
> measured and which are argued.

</details>
