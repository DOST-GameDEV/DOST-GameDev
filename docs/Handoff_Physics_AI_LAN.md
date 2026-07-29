# Handoff — PHYSICS / AI / LAN lane

Copy-paste this whole file as the opening prompt for whoever picks the lane up.
Written 2026-07-29, from `integration` @ `3cbdb73`.

---

You are the **DESIGN / PHYSICS / AI / NETWORKING** lane on `Tumbang Preso`, a Godot 4 multiplayer
game at `C:\Users\matth\Documents\GitHub\DOST-GameDev`. Work on `integration`. Commit identity is
ALWAYS `M4tyu633 <matthewtlabrador@gmail.com>` and this repo **NEVER** uses a `Co-authored-by`
trailer — it says so in ten places.

Read `docs/Art_Direction.md`, `docs/Dev_Plan.md` and `docs/Checklist.md` before touching anything.
The art and map-dressing lane is done for now — **do not spend budget redressing maps.**

## MACHINE SETUP — not in the repo, you will not find this by looking

- Godot is `C:\Users\matth\Downloads\Godot_v4.7.1-stable_win64.exe`, **not on PATH**. Use the
  `..._console.exe` sibling when you need stdout. Use the PLAIN exe for anything that renders —
  `--headless` has no rendering device and every screenshot comes back blank.
- **`godot -s script.gd` does NOT load autoloads.** Every screen fails to compile under it with
  "Identifier not found: GameLaunch / AudioManager". That is the harness being wrong, not the code.
  **RUN PROBES AS SCENES (`.tscn`).**
- New `.obj` files need `--headless --path . --import` before any scene can load them.
- System Python has numpy, scipy and Pillow. All load-bearing, none recorded.
- Bash tool: cwd persists and ONE `cd` breaks everything after — use absolute paths. `/tmp` is
  msys-only and native Windows Python cannot see it; use `C:\Users\matth\AppData\Local\Temp\...`.
- A bash heredoc mangles tabs. GDScript is tab-indented, so Python-in-heredoc string replacement
  against `.gd` silently matches nothing OR matches at the wrong indent depth. Use the Edit tool.
- **THE REPO IS SHARED AND MOVES UNDER YOU.** It moved twice mid-session on 2026-07-29 (a front-end
  overhaul landed in the middle of an input refactor). `git fetch` and check divergence before
  assuming anything about your own tree.

## THE METHOD THIS REPO REQUIRES — it matters MORE in this lane, not less

Diagnose by measurement, not by taste, and write the measurement into a probe under `tools/`.
Every hard problem here was settled that way and every wrong answer came from reasoning about
physics instead of instrumenting it. **Four traps, all of which bit on 2026-07-29:**

1. ⚠️ **A PASSING PROBE CAN BE MEASURING THE WRONG CODE PATH.** `tools/spawn_probe.gd` passed for
   10+ sessions while the game was broken, because it drives the LOCAL flow and the bugs were on the
   NETWORKED path. Prefer `tools/net_spawn_probe.tscn` (a real two-peer ENet session) for anything
   spawn-, state-, input- or replication-adjacent.
2. ⚠️ **A PROBE THAT NEVER LOOKS AT THE THING YOU CHANGED PASSES ANYWAY.** Fresh example:
   `ai_probe` connected to hitboxes once at setup and so never saw the per-throw pulse hitbox that
   `_spawn_flight_hitbox()` creates inside `host_throw`. It reported "throws that reached the can: 0"
   for every run ever recorded while `dents` climbed in the same table. **Two columns of the same
   event disagreeing is what caught it** — if two numbers cannot both be true, the metric is the bug.
3. ⚠️ **A HARNESS FAULT LOOKS EXACTLY LIKE A GAME FAULT.** The ballistics sweep produced four
   different plausible-but-wrong answers in a row before it produced a real one. Sanity-check every
   result against something you know must hold (a slower, heavier profile cannot out-range a faster
   one; eight identical solved arcs cannot scatter by 9 m; two maps cannot disagree about gravity).
4. ⚠️ **Never mark `[x]` for something only verified by parse/probe.** Use `[~]` plus an explicit
   statement of what is unverified. B-86 is the documented case of a false verification claim
   costing more than a missing feature.

## PROBES IN THIS LANE

| Probe | What it measures |
|---|---|
| `tools/net_spawn_probe.tscn` | real two-peer ENet session — the trustworthy one. Now also asserts **each peer can actually move its own character** |
| `tools/input_probe.tscn` | **NEW.** At most one local character may be AI-free at a time (the invariant the input overhaul created) |
| `tools/phys_probe.tscn` | physics/ballistics. `-- ballistics map=eskinita\|bayan_plaza`, `-- target=can\|taya\|graze` |
| `tools/windup_probe.tscn` | **NEW.** Which way the FPP throwing arm rotates |
| `tools/ai_probe.tscn` | `-- fairness rounds=20 scale=6 map=... pursue=...`. Never `--headless` |
| `tools/perf_probe.tscn` | frame timing. `-- map=...` |
| `tools/spawn_probe.tscn` | LOCAL flow only. See trap 1 |
| `tools/diag_probe.tscn` | general state dump |

## WHAT LANDED 2026-07-29 — do not redo; verify if you depend on it

- **B-130 · LAN movement.** Nobody could move in LAN. Regression from B-30, which made `player_id`
  slot-based on the networked path — but each LAN peer has its own keyboard, so the peer dealt an odd
  index got `player_id = 2` (arrow keys) while the player pressed WASD. `grab_p2` had no mouse
  binding either. Nothing errored.
- **Input overhaul (v4.65/4.66).** Split-keyboard local play retired per the human. The 36 suffixed
  actions (`*_p1..*_p4`) collapsed to 9 unsuffixed ones; `_action()` is now the identity.
  ⚠️ **The suffixes were silently providing a guard** — p3/p4 were bound to no key, so an AI or a
  parked unit could never answer a keystroke. Replaced with an explicit `CharacterBase.input_parked`.
  "Just rely on the AIController" is NOT enough: `_attach_ai` never gives `TeamAPerson` one.
  `debug_player_switcher` went from two slots to one and grants control by moving AI control.
- **B-131 · the throw wind-up was inverted.** The arm dropped instead of cocking back. Measured, not
  eyeballed: the old sign moved the fist dY −0.461 / dZ −0.241 (down and forward).
- **B-132 · a thrown slipper was intangible for most of its flight.** `_step_flying` ignored **every**
  collision for `THROWER_IGNORE_TIME` (0.25 s), not just the thrower's — and a 6.0-line throw lasts
  ~0.29 s. It sank through the floor and landed 10.14 m out on a 6.0 m throw. **Re-read every old
  note about "weird bounces" and floor clipping against this.**
- **Ballistics, measured.** `Art_Direction.md` §9's table was wrong through two supersessions and is
  now replaced with real numbers. Every profile reaches the 6.0 line; the `throw_bakya` reach problem
  is gone. Scatter is essentially zero, so a missed throw is aim or charge, never spread.
- **B-124 · the AI livelock** (exactly one throw per round) — fixed with `ATTACKER_PATIENCE`.
- **B-125 · the AI never aimed at the can** — fixed with `CharacterBase.ai_aim_point`.
- **The can dodges and the AI now leads it** (`CAN_LEAD_FRACTION`). The can moves on 56% of
  in-flight frames, up to 1.41 m.
- **Confinement is a square in physics now**, matching the chalk. It was a circle; at the corners the
  marker promised 7.07 units and the player stopped at 5.0. Both map builders now READ
  `CONFINEMENT_RADIUS` out of `character_base.gd` instead of restating it.
- **Bayan Plaza measured for the first time** — perf and AI. Neither probe had a `map=` argument, so
  every number this project had ever recorded described Eskinita.

## YOUR TASK — what is actually open

### 1. AI fairness is a TUNING problem now, not a structural one

That is new as of 2026-07-29 and it is the headline. See the Phase 9 fairness log in
`docs/Checklist.md` for RUN 1 / RUN 2 / RUN 3 in full.

| Metric | RUN 1 (before) | RUN 3 (now) | Fair |
|---|---|---|---|
| Round win rate | DEFENCE **100%** | DEFENCE 90% | 40–60% |
| Throws taken | 20 (exactly 1/round) | 103 | — |
| Throws blocked | 0 (0%) | 53.4% | 25–50% |
| Reached the can | **0** | 4 | — |
| Dents/round | 0.00 | 0.30 | ≥ 1 |
| Rounds timed out | 8/20 | **0/20** | — |
| Longest still-run | 23.62 s | 6.83 s | < 2 s |

**Three ranges still unmet.** 18/20 rounds end in a TAG. The obvious levers, in order:
- `ATTACKER` has **no evasion at all** — it only avoids standing in a blocked lane, and 90% of rounds
  end with it being tagged. Real dodging is unimplemented and is probably the single biggest win.
- `TAYA_BLOCK_STANDOFF` (2.6) is documented as "a first guess" and now needs measuring — the square
  confinement made the Taya stronger (block rate 45.1% → 53.4%).
- `CAN_LEAD_FRACTION` (0.6) and `ATTACKER_PATIENCE` (2.0) are difficulty knobs and belong in the
  difficulty TIERS fairness item 6 asks for, not in one-off nerfs.

### 2. Can falling — SCOPED, NOT IMPLEMENTED

Human request: *"can the can even fall? make it easier to fall, but sometimes make it so that it can
land on its head/back and this isnt a point for the enemy."*

Measured answer to the question itself: **under Option A the can never visibly falls** —
`apply_dent()` "deliberately does NOT use the Downed/Seal state machine at all". Under Option B every
profile has `forces_downed = true`, so a clean hit downs it.

**The no-score fall already has a natural home.** `round_manager.gd::_on_tracked_can_state_changed()`
already counts every transition into DOWNED toward `_fall_count`/`FALL_LIMIT` ("if can falls 5 times
they lose"). So *"lands on its head/back, no point for the enemy"* == **a DOWNED transition that does
not increment `_fall_count`**. No new state machine required.

⚠️ **The roll must be made on the HOST and ride the existing broadcast or peers desync.**
`hitbox.gd` already resolves `kind` host-side and ships it via
`target._apply_hit_result.rpc_id(...)`. Add a new kind there (`"downed_lucky"` / `"dent_lucky"`).
Do **not** call `randf()` inside `_apply_hit_result` — that runs per-peer.

⚠️ `_on_tracked_can_state_changed(new_state)` receives only the state, not which can, so it cannot
currently distinguish a scoring fall from a lucky one. The flag has to be threaded through.

### 3. Defender step/touch on the enemy slipper — NOT STARTED

Human request: *"add a mechanic that defender can step or touch the slipper of enemy team and it will
slow down or get knocked back (knock back for the touch)."* Two interactions on an OPPONENT's
tsinelas: STEP (stand on it) slows it, TOUCH (body contact) knocks it back.

The ownership half is already correct — `carriable.gd`'s rule says an opponent's slipper "is still a
solid, kickable obstacle — you can body-check it, your bump still staggers it" but cannot be picked
up. What is missing is the slow/knockback effect. Verify on the NETWORKED path.

### 4. Networked round-reset audit — NOT DONE

`reset_for_new_round()` has already produced one silent cross-object state leak (the held-slipper
bug). Audit the rest of that path on the networked flow with `net_spawn_probe`. Note that
`_apply_hit_result` is an `rpc_id` to the struck peer and **can land frames after `_reset_world()`
has teleported everyone home** — B-128 fixed one instance of that class, not the class.

### 5. Bayan Plaza has still never been PLAYED or NETWORKED

Perf and AI are now measured (see above) and both are fine. Nobody has played it and it has never
run in a networked match.

### 6. Nothing in this lane has been judged by a human playing it

Confinement feel, spawn layout, thrown-slipper landing, bounce feel, the ready countdown and all
audio remain unjudged. Where a question is about FEEL rather than correctness, instrument it, produce
a number or a short clip, and **ASK** — do not tune it by taste and declare it done.

## DECISIONS ALREADY MADE — DO NOT RE-ASK

- Arena footprint: keep the ORIGINAL size.
- Confinement marker: **SQUARE**, not circle ("the circle you made was ugly"). As of 2026-07-29 the
  physics is square too. **Do not "fix" the balance by reverting the shape** — the circle was a bug.
- Split-keyboard local 2-player is **retired**. One human per PC. One unsuffixed input action set.
- Single Player / Local Match is a permanent mode with real AI, not a stripped one.
- The slipper stays procedural.
- Characters are palette recolours of existing CC0 rigs — do NOT author or import new character models.
- The plaza monument is deliberately OFF-CENTRE; `LANE_RADIUS = 3.2` is a hard no-build disc that
  aborts the map build. Changing the protected disc IS a gameplay decision — raise it, do not edit it.
- Lighting and shaders stay cheap. Heavy shaders/shadows previously made the game both ugly and
  laggy on other PCs.

## WORKING AGREEMENT

Plan first, then execute. **Commit and push to `integration` as you go** rather than in one lump —
the repo is shared and a session can be interrupted (not hypothetical; it happened twice on
2026-07-29). Report honestly: if something is unverified, say so plainly rather than claiming it.
