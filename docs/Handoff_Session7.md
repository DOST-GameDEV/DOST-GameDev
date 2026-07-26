# Handoff — Dev Session 7

Two things this session: (1) a correction to the core team structure that earlier sessions
(and the GDD itself) had wrong, and (2) finishing Option A (dents) as a real, testable
round-win mode alongside Option B.

---

## Team structure correction — was wrong since Session 1

**Old (wrong) model:** each team = 2 identical Can (or Tsinelas) units, directly
player-controlled, no human character at all. This is what the GDD said in Section 1/2/3
and what Session 6's "real 2v2 team assignment" built on top of.

**Corrected model:** each team = **1 Person + 1 Can/Slipper Prop**, both independently
player-controlled (4 players total, matching the existing `MAX_PLAYERS = 4` spawn
infrastructure — no new plumbing needed there).

- **Person** — the human half. Tags attackers on defense (classic Tumbang Preso "It"/guard);
  throws the Slipper at the Can on offense. Mechanically both are just the existing Bump/hit
  interaction today — there's no dedicated throw/tag mechanic, no unique Person ability.
  That's a real gap, not a subtlety — see "Known gaps" below.
- **Prop** — the Can or Slipper. Carries the roster's class ability (Quick Stand, Bakya
  Bash, etc. — GDD Section 4 is about this half of the team, not the whole roster). This is
  the only unit round-win logic (Option A or B) ever cares about.
- Which peer is Person vs Prop is fixed for the whole match (first peer to join a team is
  its Person, second is its Prop — see `main.gd::_spawn_player`). Which *side* the team's
  Prop plays (Can vs Slipper) still swaps every round, unchanged from Session 6.
- Person-vs-Person and Person-vs-Prop hits still land (stagger) but never affect round
  outcome — only Prop-vs-Prop hits do, matching the GDD's "stun only, no permanent
  elimination" rule for everything except the Can/Slipper contact that actually decides
  rounds.

### Code changes
- `character_base.gd` — new `is_person: bool` export, alongside the existing `is_can`.
  `is_can` is now `false` unconditionally for a Person regardless of team side.
- `main.gd` — `_spawn_player` assigns `is_person` by join order within a team pair;
  `_on_match_round_started` recomputes `is_can` as `team_is_can_side and not is_person`
  instead of just `team_is_can_side`. `_wire_downed_flash` (DownedFlash + dent counter, see
  below) is now only wired for the locally-controlled character if it's actually the Can,
  since the local player might be controlling their team's Person this match.
- `hitbox.gd` / `round_manager.gd` — comments updated to be explicit that hit *resolution*
  is generic across Person/Prop, but hit *relevance to round-win* only ever comes from
  `RoundManager`'s tracked-Cans list, which only ever contains Props.
- `docs/Tumbang_Preso_2v2_GDD.md` and `README.md` — pitch, locked-decisions table, Section 3,
  and the roster intro (Section 4) all corrected to describe the real 4-player Person+Prop
  structure. The old wording is preserved as a struck-through note in the GDD's pitch section
  so the history of the mistake isn't silently erased.

### NOT touched — still needs work
- **The local single-PC test flow** (`CanTestCharacter`/`TsinelasTestCharacter` in
  `Main.tscn`, used when there are no launch args) still models the OLD 1v1 direct
  Can-vs-Tsinelas control. It hasn't been rebuilt for 4 units. Fine as a quick movement/combat
  smoke test, not representative of the real match structure — use the networked flow
  (`--host`/`--join` or the menu) to actually test 2v2 Person+Prop play.
- **Person has no roster/class/ability at all.** Right now every Person is identical:
  Move + Bump, nothing else. No throw mechanic (offense Person "throwing" a Slipper is
  currently just the same melee Bump as everything else), no tag-specific mechanic (defense
  Person "tagging" is also just Bump). Whether Person needs its own roster (parallel to the
  6 Prop characters) or just one generic design is an open design question.

---

## Option A (dents) — now implemented, both modes real

Per the GDD, Option A is a health-bar model: Slippers win by fully denting a Can, instead of
Option B's Downed→Seal state machine.

- `character_base.gd` — new `dents: int` (0 by default, synced like `state`), `MAX_DENTS = 3`
  (3 hits per your call this session), `dents_changed` signal, `apply_dent()` which
  increments dents and applies a brief stagger for feedback but deliberately does **not**
  touch Downed/Seal at all — Option A's win condition is purely the dent count, tracked
  independently.
- `hitbox.gd` — branches on `GameLaunch.game_mode`: under Option A, a landed hit on a Can
  becomes a `"dent"` instead of stagger/downed/seal. Hits on a Person or Slipper still just
  stagger, same as Option B.
- `round_manager.gd` — `register_can()` now also listens for `dents_changed`;
  `_on_tracked_can_dents_changed()` mirrors the existing Option B check but watches `dents`
  instead of `state`. **Default: requires BOTH tracked Cans to hit `MAX_DENTS`** before
  Slippers win the round, for parity with Option B's "every Can Sealed" rule (rather than
  either Can alone ending it). This was a judgment call, not something you confirmed — the
  comment right above `_on_tracked_can_dents_changed` says exactly which line to change if
  you want EITHER Can alone to end the round instead.
- `HUD.tscn` / `hud.gd` / `main.gd` — added a `DentLabel` ("Dents: x / 3"), hidden by
  default, shown and kept live for the locally-controlled Can only when
  `GameLaunch.game_mode == OPTION_A`.
- **Not implemented:** ring-outs (Option A's other stated win condition for Cans — "knocking
  Slippers out of bounds a set number of times"). Needs a bounds/trigger check that doesn't
  exist yet. Separate piece of work.
- **Not implemented:** anti-cheat/validation on the dent RPC — per your call, not a concern
  for this demo. Host trusts the reported hit same as everywhere else in combat.

---

## Known gaps / not yet done (carried over + new)

- Person has no roster/ability (see above) — biggest open item from this session.
- Local single-PC test flow doesn't reflect the 4-unit structure (see above).
- Ring-outs for Option A.
- No movement smoothing/interpolation on remote characters — still snaps (Session 5/6).
- No real lobby/ready-up state — match starts as soon as host starts hosting (Session 6).
- A player who joins mid-round isn't added to `RoundManager`'s tracked-Cans list until the
  next round starts (Session 6).
- Combat networking is unvalidated — no anti-cheat, intentionally out of scope for this demo.
- Human playtesting for feel, real art, and the two map scenes (Eskinita / Bayan Plaza) are
  still untouched.
