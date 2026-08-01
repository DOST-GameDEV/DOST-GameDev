# HANDOFF — what is still open on `ESPORTS`, 2026-08-01

**Paste § THE PROMPT below as the first message of a new chat, on its own.**
Everything after it is the evidence that prompt refers to.

---

## THE PROMPT

```
You are picking up branch ESPORTS of the Tumbang Preso repo
(C:\Users\Matthew\Documents\GitHub\DOST-GameDev). Model: Opus 5, effort xhigh.

Read docs/HANDOFF.md first, then docs/Agent_Prompts.md § 2 (HOW TO RUN A LANE)
and docs/Design.md, which is the balance source of truth.

OBEY THE COMMIT AUTHORSHIP RULE EXACTLY. Every commit is authored by
M4tyu633 <matthewtlabrador@gmail.com>. NO `Co-Authored-By:` trailer, ever. No
"Generated with", no tool attribution, no emoji line. Check with
`git log -1 --format='%an <%ae>%n%b'` after committing and amend if wrong.
This is submitted as one person's work and the history has to read that way.

git pull --rebase before you start and before every commit. Push to ESPORTS.

Design.md is the balance source of truth: move a number in code -> move it there
in the SAME commit. Tick your own boxes in Agent_Prompts.md § 4 and append one
entry to § 7, also in the same commit.

Your job is § A and § B of docs/HANDOFF.md, in that order. § A is a list the
human gave and is unfinished. § B is what the previous session measured and
could not close. § C is traps that already cost this project time — read it
before you debug anything.

Godot 4.7.1 is at C:\Users\Matthew\Downloads\. Use the _console.exe for probes
that print, the plain _win64.exe for anything that RENDERS (--headless has no
rendering device and every capture comes back blank). --headless is still right
for --import.

VERIFY BY MEASURING, NOT BY LOOKING. Every probe command you need is in § D.
A probe that cannot fail is worse than no probe: prove a new check goes RED on
the unfixed code before you believe it.
```

---

## § A — UNFINISHED FROM THE HUMAN'S LIST

All of § A was requested directly. Items not listed here are already done and
committed; do not redo them.

### A1 · HUD restructure  *(`scripts/ui/hud.gd`, `scenes/ui/HUD.tscn`)*

- [ ] **Split the HUD left/right.** Status effects (`FATIGUED`, `STUNNED`) on the
  LEFT; ability cooldowns (`SHOVE CD`, `LUNGE CD`, `THROW CD`) on the RIGHT.
  Today both come out of one `status_effects()` list into one centred
  `StatusStack` built in code (`_ensure_status_root`, anchored `PRESET_CENTER_TOP`,
  offset y 96). The producer already tags every row with a `label`, so the split
  is a routing decision in `_refresh_status_stack()`, not a gameplay change.
- [ ] **Cooldown timers freeze / update inconsistently.** Reported by the human;
  not yet reproduced. Start at `CharacterBase.status_effects()` — the rows carry
  `seconds` and `total`, and `_shove_cooldown_left` / `_lunge_cooldown_left` /
  `_punch_cooldown_left` all tick in `_physics_process`. ⚠️ Suspect the AUTHORITY
  GATE: those three tick BEFORE the `is_multiplayer_authority()` return, but
  `RoundManager.throw_cooldown_left()` is mirrored by an unreliable `_sync_state`
  at 4 Hz, so the THROW row is the one most likely to stutter on a client.
- [ ] **Scale up non-scoreboard HUD elements.** Status rows are font 15
  (`_build_status_row`); the human asked for bigger for readability in motion.
  The new `YOU ARE VULNERABLE` label is already 22 and is a reasonable reference.
  ⚠️ Re-run `bounds_sweep` after — it PASSes 9 screens × 5 aspect ratios today.

### A2 · Menu and world-space UI

- [ ] **Main menu post-processing.** Remove the low-contrast filter over the menu
  background so the artwork reads clean. `scenes/ui/MainMenu.tscn` +
  `scripts/systems/env_toon_pass.gd`.
- [ ] **Tutorial and Credits signboards float.** Their collision/transform anchors
  need to sit on the ground mesh. Both are reached from `MainMenu.tscn`.

### A3 · Anything else the human raises

The human works by looking at the running game and pointing. Expect live
reports; treat a screenshot as the spec. **Ask which element if there is any
ambiguity** — a wrong guess here cost this session two rebuilds of both maps.

---

## § B — FLAGGED AND OPEN

### B1 · `§2.16` fails on CROCS by 0.31 m  *(filed to `build ui` as §1.19)*

`tools/mech_probe.tscn` reports the dotted aim arc and the thrown slipper landing
**0.31 m apart on CROCS only**; TSINELAS, PANTULOG and IKE are all 0.000 m.

**It is not the arc.** A crocs rests **0.161 m** off the ground (it is a tall
hollow shell, centroid at 53% of its height) against the other three at
0.034–0.056, while `TrajectoryPreview.draw_arc()` stops its line at a fixed
`FLOOR_EPSILON` 0.03. The line is right; the tall skin simply stops higher.
The throw buff to 18.5 m/s made it slightly worse.

Fix is in `trajectory_preview.gd` (`build ui`'s row): stop the arc at the HELD
slipper's own `_rest_height` rather than at a constant.

### B2 · `ai_probe matches=N` for N > 1 never completes  *(§6.12)*

Match 2 never ends. Reproduced four times, and **it is pre-existing** — it
reproduces identically at HEAD with a clean tree, before any of this session's
changes. `matches=1` always finishes. This matters because the default is
`matches=3` and every number in §6.8's tier table is therefore a one-match sample.

One real cause was found and fixed (`_hitstop()` orphaning `Engine.time_scale` at
0.05 — see § C4) and **it did not make `matches=3` complete**, so there is more.
Remaining suspect: the teardown/rebuild in `ai_probe`'s `_end_match()` /
`_start_match()` against `main.gd`'s lifecycle. `main.gd` is §2.19's ownerless
file for the fourth time.

### B3 · 30 client-side errors remain on two peers

`net_twopeer_probe` after the replication fix: **host 0, client 30**, down from
123. The remaining ones are a different and milder shape —
`Node not found: "Main/Slipper3"` at JOIN time, an early-join ordering race
rather than a per-peer path that may never exist. Reproduce with the two
commands in § D.

### B4 · Passive defence is close to the line again

`fair_probe -- policy=turtle` gates DEFENSE at ≤ 50% of all points and measured
45.5–47.8% before the arena changes. The box then moved twice and the throw was
buffed. **Re-run it** — if it goes over 50 the catch-up term has become the game,
and `Design.md` §8.1 has the full argument for why the number itself is correct.

### B5 · Never verified, structurally

- **Nothing has been heard.** No session has had an audio output device. §2.17's
  `slipper_land` is proven as a call site, not as a sound.
- **§2.18 `round_ended`** is fixed but unverified on two real peers.
- **§2.11 / §2.22 feedback has never been SEEN** — the block flash, the
  deflection and the lata recoil are all measured and none is captured. This
  needs a screenshot or a clip, not more code.

### B6 · Balance items not reached

- **§2.3 `SABOTAGE_WINDOW`** — blocked on FREQUENCY, not effort. Sabotage fired
  **0 times** in every whole-match run until the shove's miss-cooldown was cut to
  2.0 s; it now fires ~1 a match. There may finally be enough events to measure.
- **§2.12** the lata's topple, judged from spectator range.
- **§2.13** a thrown slipper has no trail and no impact VFX.
- **§2.19** `main.gd` and `character_visual.gd` have NO OWNER and have now carried
  live bugs across five sessions. **Give them an owner.**
- **§2.24** the reparent-vs-RPC race. Much reduced (see § C3) but not closed.
- **§2.29** `Engine.time_scale` has one owner and four writers.

---

## § C — TRAPS FROM THIS SESSION

Each of these cost real time. `Agent_Prompts.md` § 6 has the older ones.

### C1 · A harness that runs out of clock reports the bug it was hunting

`mech_probe`'s tag scan is 38 trials and outlasted the 90 s round. Everything
gated on `can_act()` then started refusing, and the crossing-target scan came
back **0.00 m** — which reads EXACTLY like the tunnelling failure §2.6 was
written to look for. The round is held open now. **Before believing a probe
result, check the probe still had a live round.**

### C2 · A bench measured a bot walking and called it a body block

`trait_probe` reported the shove's knockback as **3.6225 m/s for both skins** —
which is `SPEED 4.6 × ATTACKER_SPEED_SCALE 0.75 × a trait scale of 1.05`. It was
measuring the victim walking away, to four decimal places. Park every unit you
are not measuring (controller off, `input_parked` on, intent cleared) and
re-assert it **every frame**, because `main.gd::_reassert_spectated_bots()` turns
controllers back on.

### C3 · A `MultiplayerSynchronizer` identifies its node BY PATH

Re-parenting the slipper onto a hand moves it under a hierarchy
`character_visual.gd` builds at RUNTIME, per peer — so every packet sent while
carried names a node the receiver may not have built. 123 client errors in one
round. The synchronizer is silenced while carried; a carried slipper never
needed position packets because every peer derives it from the carrier.

### C4 · A global set by one object must not be restored by that object

`_hitstop()` wrote `Engine.time_scale` process-wide and scheduled the restore on
a `SceneTreeTimer` bound to an INSTANCE method, guarding STATIC flags. Free that
instance inside the 60 ms window — which RETURN TO MENU does, and which
`ai_probe` does between matches — and the engine stays at **0.05 for ever**. The
symptom is not "the effect stuck", it is "the whole game is 120× slower", which
reads as a hang and points at nothing.

### C5 · `@rpc("authority")` on a player's character means THE PLAYER, not the host

`main.gd` gives every human's character `set_multiplayer_authority(peer_id)`. Four
host-decided state changes were declared `@rpc("authority")` **on
`character_base.gd`**, so the host was calling RPCs it had no right to call, and
`call_local` meant it applied them to its own copy while the victim's machine did
not. That was the multiplayer tag softlock. They live on `RoundManager` now (an
autoload, so authority 1) and name the victim BY SLOT, never by NodePath.

### C6 · Growing the box has a THIRD bound nobody had written down

`ai_controller` sends attackers to a ring at
`confinement_radius + THROW_STANDOFF`, and Eskinita's wall colliders are the
house facades at **x = ±8.6**. At a 7.5 box the ring was 8.7 — past the wall — so
every bot on an east/west bearing pressed into a facade for the rest of its plan.
The rule is:

    CONFINEMENT_RADIUS + AIController.THROW_STANDOFF + a capsule <= WALL_FACE_X

and two of those three numbers live in files `CONFINEMENT_RADIUS` does not.
`main.gd` publishes `CharacterBase.playable_half_x/z` from the map's own `Bounds`
colliders and the AI clamps to it, so this cannot silently recur.

### C7 · A courtesy call is not an assignment — and forcing it broke the game

The round-start slipper equip was forced during `_reset_slippers()`. Result: **0
throws, 0 knockdowns, three bots stuck in FETCH for a whole match, DEFENSE 100%
of every point.** It reparents onto a `HandAttachment` the visual is REBUILDING on
the same frame. The equip happens at round START now, where the visuals are built
and every precondition is met.

### C8 · `--headless --import` does not prove a tool script parses

`tools/fair_probe.gd` imported clean while containing a hard parse error (a
nested class redeclaring a parent's const, which is an error and not a shadow).
It only appeared when the scene was RUN. **Run every probe once before believing
it exists.**

---

## § D — VERIFICATION COMMANDS

`G` = `C:\Users\Matthew\Downloads\Godot_v4.7.1-stable_win64_console.exe`
`GP` = `C:\Users\Matthew\Downloads\Godot_v4.7.1-stable_win64.exe` (renders)
`R` = `C:\Users\Matthew\Documents\GitHub\DOST-GameDev`

```bash
# the one cheap real gate — but see C8, it does not cover tool scripts
"$G" --headless --path "$R" --import        # grep for "Parse Error" / "SCRIPT ERROR"

# whole matches, the point breakdown, the gates
"$G" --path "$R" tools/ai_probe.tscn -- matches=1 scale=6 tier=NORMAL
#   ⚠️ matches>1 hangs — see B2. Use matches=1.

# the passive-defence experiment (B4)
"$G" --path "$R" tools/fair_probe.tscn -- policy=turtle
"$G" --path "$R" tools/fair_probe.tscn -- policy=bot      # control
"$G" --path "$R" tools/fair_probe.tscn -- policy=idle     # the floor

# the shove, stamina, the tag vs a MOVING target, the aim arc (B1 fails here)
"$G" --path "$R" tools/mech_probe.tscn

# do all nine stats reach a real call site
"$G" --path "$R" tools/trait_probe.tscn

# the slipper is in the hand, the can does not clip, throws fly
"$G" --path "$R" tools/models/prop_probe.tscn
"$G" --headless --path "$R" -s tools/models/lata_floor_probe.gd

# HUD: 9 screens x 5 aspect ratios
"$G" --path "$R" tools/ui/bounds_sweep.tscn

# two REAL peers (B3) — start the host, wait ~12 s, then the client
"$G" --path "$R" tools/ui/net_twopeer_probe.tscn -- --host --secs=110 --out=<dir>/host_
"$G" --path "$R" tools/ui/net_twopeer_probe.tscn -- --join=127.0.0.1 --secs=100 --out=<dir>/client_
# then grep both logs for ERROR / "Node not found" / "not allowed"

# top-down floor plan, BOTH maps (needs the PLAIN exe)
"$GP" --path "$R" tools/maps/court_shot.tscn -- <out_dir>/name eskinita
"$GP" --path "$R" tools/maps/court_shot.tscn -- <out_dir>/name bayan_plaza

# after ANY change to CONFINEMENT_RADIUS — the chalk is derived from it
python tools/maps/build_eskinita.py
python tools/maps/build_bayan_plaza.py
```

---

## § E — WHAT LANDED THIS SESSION, SO IT IS NOT REDONE

Commits `6d1ca5f` → `7f447fb` on `ESPORTS`.

**Balance.** §2.1 settled — passive defence measured three ways and the number
does not move (`Design.md` §8.1). §2.8 — all nine stats now reach gameplay, both
prop tables retuned, all taglines rewritten, two byte-identical Person rows made
distinct. §2.4/2.5/2.6/2.7/2.9/2.16/2.23/2.26 measured or decided. Box 6.5 → 7.0.
`LAUNCH_SPEED` 17.0 → 18.5. Stamina 50 → 60, regen delay 2.5 → 1.0. A tag now
cleanses. A missed shove costs 2.0 s instead of 7.5.

**New verbs.** The taya has a PUNCH (left-click) and the lunge moved to hold-E at
1 m. Bots use both.

**Multiplayer.** The tag softlock (C5). The carried-slipper replication storm (C3).
`round_ended` broadcast.

**Feel.** The taya animates at last (its charge pose read two clocks that a
defender can never satisfy). Pickup and lata-reset broadcast. Lunge and punch have
their own clips. Body blocks push, flash and shake. A landing slipper makes a
sound. The danger vignette is a held state at low alpha; `YOU ARE VULNERABLE` is
text under the crosshair.

**AI.** Bots hold a wind-up, so a human is no longer the only attacker ever
visibly charging. Threat scoring de-biased plus anti-fixation. Ring points clamped
to the map's real walls.

**Maps.** Both `HazardZone` slow fields and their kanal beds deleted. Play-box
keep-out for trees. Yero tier moved to the facade, derived from `WALL_FACE_X`.

**Tools.** `tools/fair_probe.gd`, `tools/trait_probe.gd` new;
`tools/mech_probe.gd` rewritten from 355 lines of deleted 2v2.
