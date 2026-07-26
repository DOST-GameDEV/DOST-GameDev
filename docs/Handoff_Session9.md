# Handoff — Dev Session 9

Picks up a session that never got pushed (editor crash/context issue on the previous pass —
same intended scope, redone from scratch here and actually committed this time). Three things:
(1) rebuild the local single-PC test flow to match the real 4-unit Person+Prop structure,
(2) a rebindable/persistent Settings panel, (3) fixes for what testing turned up.

---

## Bug reports this session was meant to fix

- **"Where are the 4 characters?"** — the local single-PC flow (`Main.tscn`, no launch args)
  still spawned the old 1v1 `CanTestCharacter`/`TsinelasTestCharacter` pair from before the
  Session 7 team-structure correction. Never rebuilt for the real 4-unit Person+Prop match
  structure — see "known gaps" in `docs/Handoff_Session7.md`.
- **"Why can't I throw and stuff?"** — Person's Tag/Throw ability (Session 8) was only ever
  wired for the networked spawn path (`_build_networked_character`). The local flow had no
  Person at all, so there was nothing to throw with.
- **"Can you add a settings section with all the supposed keys, make it so we can edit it
  too"** — no settings/rebinding UI existed at all before this session.
- **"Timer doesn't even move anymore man"** — not reproducible against what's actually in
  this repo (last pushed commit, Session 8) — the round timer starts correctly there. Almost
  certainly a regression introduced by the unpushed Session 8.5 work this redoes; rebuilt from
  scratch here with the round-start path double-checked (see "Local test flow" below).

## Local test flow — now the real 4-unit structure

- `scenes/main/Main.tscn` — `CanTestCharacter`/`TsinelasTestCharacter` replaced with
  `TeamAProp`, `TeamAPerson`, `TeamBProp`, `TeamBPerson`. Player controls one full team:
  `TeamAProp` (P1 keys — Move/Bump/Guard/Special, `player_id = 1`) and `TeamAPerson` (P2 keys,
  `player_id = 2`), so both a roster Prop ability (Quick Stand, already wired) and Person's
  Tag/Throw are directly testable with one keyboard. `TeamBProp`/`TeamBPerson` are local-test
  dummies (`player_id` 3/4) standing in as a stationary opponent team — see next section for
  why they don't move.
- `scripts/characters/character_base.gd` — `player_id` widened from `@export_range(1, 2, 1)`
  to `@export_range(1, 4, 1)` to allow the two new dummy slots.
- `project.godot` — added `move_left_p3` .. `special_ability_p3` and the `_p4` equivalents,
  all with **empty event lists** (unbound) — registered so `Input.is_action_just_pressed`
  doesn't error for `player_id` 3/4, but deliberately given no key so those two characters
  never receive input. That's the whole "dummy" mechanism — no separate AI/idle script needed.
- `scripts/main.gd`:
  - `_start_local_test()` (replaces the old inline local branch in `_ready()`) — populates
    `_local_roster`, gives `TeamAPerson`/`TeamBPerson` each their own `.duplicate()`d
    `PersonAction` instance (same cooldown-sharing trap as the networked path — see the
    doc comment on `PERSON_ACTION_ABILITY`), wires `DownedFlash`/dents for both Props (not
    just one — see below), registers whichever Prop is currently the Can, then calls
    `MatchManager.begin_next_round()` — which is what actually starts the round timer, via
    the `round_started` signal this function connects to.
  - `_on_match_round_started` — now has a local-flow branch (`elif not _local_roster.is_empty()`)
    that mirrors the networked one: recomputes `is_can`/`team_is_can_side` for all 4 local
    nodes from `team_a_is_can`, then re-registers whichever Prop is now the Can. Closes the
    "role-swap isn't wired for local play" gap called out in Session 7.
  - `_clear_local_test_characters()` — updated to free the 4 new nodes (was hardcoded to the
    2 old ones — would have been a hard crash the moment `--host`/`--join` ran against this
    scene otherwise).
  - `_wire_downed_flash()` — the `is_can` check moved from gating the *connection* to inside
    the connected callback, so DownedFlash/dents keep working for a character whose `is_can`
    flips after the fact (true for both local Props now, and for networked Props too, which
    had the same latent issue — a player whose team starts on the Slipper side never got this
    wired at all previously). Now called for both `TeamAProp` and `TeamBProp` locally.

## Settings panel — rebindable, persistent controls

- `scripts/systems/settings_manager.gd` (new autoload, `SettingsManager`) — owns the
  rebindable-action list (P1/P2's 7 actions each; P3/P4 excluded, they're unbound dummy slots
  with nothing to rebind), reads/writes `InputMap` directly, and persists to
  `user://settings.cfg` via `ConfigFile`. Captures each action's project-default keycode on
  first `_ready()` so "Reset to Default" doesn't need a second hardcoded key list.
- `scenes/ui/SettingsPanel.tscn` + `scripts/ui/settings_panel.gd` (new) — one row per
  rebindable action, click its button then press any key to rebind (Esc cancels). Built as
  its **own scene**, instanced into `MainMenu.tscn`, rather than nodes added straight into
  `MainMenu.tscn` — see next item for why.
- **Fixed while building this:** originally tried adding the settings UI directly as nodes
  inside `MainMenu.tscn`, using `unique_name_in_owner` (`%NodeName`) for its status label —
  but `PlayMenu` already owns a node named `StatusLabel` with the same flag, and Godot's
  unique names have to be unique scene-wide, not just within a container, so this collided.
  Making `SettingsPanel` its own instanced scene sidesteps it entirely: its unique names
  resolve within its own instance, independent of whatever `MainMenu.tscn` already has.
- `scenes/ui/MainMenu.tscn` / `scripts/ui/main_menu.gd` — added a `SettingsButton` on the
  title screen and wired it to show/hide `SettingsPanel` alongside the existing
  `TitleScreen`/`PlayMenu` swap.

## Not touched / still open

- Ring-outs (Option A), movement interpolation, real lobby/ready-up, mid-round join tracking,
  combat anti-cheat, human playtesting, real art/maps — all still open from Session 7/8.
- Settings panel only covers input rebinding — no audio/graphics settings, no gamepad support.
- P3/P4 dummies are purely stationary (no idle animation, no AI) — fine for testing collision/
  camera/HUD against a fixed target, not a real practice-mode opponent.
