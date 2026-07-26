# Handoff — Dev Session 2 (+ Session 3 update below)

### Update — Session 3

Added on top of everything below:

- **All 6 abilities now exist** (was just Quick Stand): `shatter_trap.gd`, `spin_guard.gd`,
  `bagsak_bomb.gd`, `bakya_bash.gd`, `flick_dash.gd` — every one extends `AbilityBase` and
  plugs into a character's `ability` slot the same way Quick Stand does.
- **`AbilityUtils.spawn_pulse_hitbox()`** (`scripts/abilities/ability_utils.gd`) — shared
  helper that builds a temporary AoE/forward Hitbox entirely from code, no separate scene
  needed. Spin Guard, Bagsak Bomb, Bakya Bash, and Flick Dash all use it.
- **`HazardZone`** (`scripts/systems/hazard_zone.gd`) — generic slow-zone Area3D. Palayok's
  Shatter Trap uses it now; it's written to double as the map hazards later (Bayan Plaza
  mud, Palengke wet floor — GDD Section 5) without any changes needed.
- **`AbilityBase` gained an optional passive hook**, `_on_owner_downed(character)` — lets an
  ability react to its owner going Downed instead of / in addition to a button press.
  Shatter Trap is the first thing using it; `CharacterBase.go_downed()` calls it if defined.
- **`CharacterBase.set_speed_multiplier()` / `reset_for_new_round()`** — the multiplier is
  what HazardZone drives; the reset clears Downed/Sealed/Staggered state between rounds
  (nothing was calling this before, so Sealed carried over forever).
- **Option B is now actually testable, not just supported.** `RoundManager.register_can()` /
  `clear_tracked_cans()` let you tell RoundManager which characters are playing Can this
  round; once every registered Can is Sealed, it reports a Slippers round win automatically.
  `scripts/main.gd` registers the test Can on scene load as a working example. **Caveat**:
  this is opt-in on purpose, not auto-detected — see the comment in `round_manager.gd` for
  why (the Attacker/Defender role swap implies characters change which side they're playing
  each round, and that reassignment isn't built yet).
- `scenes/main/Main.tscn`'s Can now has a real Quick Stand ability resource
  (`scripts/abilities/resources/quick_stand.tres`) plugged in, so pressing `special_ability`
  while Downed actually does something in the test scene.

**Still nobody has opened this in the actual Godot editor** — everything above is
hand-written text-format `.tscn`/`.gd`/`.tres`, consistent as far as static review can
verify, but genuinely untested against the engine. First priority for whoever picks this up:
open it, hit Play, see what breaks.

---


### What's in this commit vs. the last one

The first commit was folder structure + stubs. This one makes the core loop actually
*do something* end to end: bump lands, a Can can go Downed and get sealed, the round
timer and Bo5 tracker run live, and there's a HUD on screen showing all of it. Still
single-player / no networking — that's intentionally the next phase, not this one.

---

## What's implemented

### Hit detection — `scripts/characters/hitbox.gd`, `hurtbox.gd`
- Every `CharacterBase` now has a `Hurtbox` (Area3D, "can be hit here") and a forward
  `Hitbox` (Area3D, "hits here") as children — see `scenes/characters/CharacterBase.tscn`.
- Bump is **press-to-activate**, not always-on contact: pressing `bump` opens a 0.15s
  window (`is_hitbox_active()`) during which the Hitbox actually registers a hit. Matches
  "light melee, no cooldown" from the GDD without letting standing near someone stagger
  them every physics tick.
- `Hitbox.forces_downed` and `requires_bump_window` are exported per-hitbox, so a
  special's hitbox (e.g. Bakya Bash) can be swapped in with different behavior than the
  default melee one without touching `CharacterBase`.

### Downed/Sealed state machine — `scripts/characters/character_base.gd`
- `CharacterBase` now has a real state machine: `NORMAL → STAGGERED → NORMAL`, and
  `NORMAL → DOWNED → (self-right → NORMAL) | (window expires → sealable → SEALED)`.
- The ~2s self-right window from GDD Section 3 (Option B) is implemented: press `bump`
  while Downed and inside the window to self-right; a Tsinelas's Hitbox touching a Can
  that's Downed *and past* the window calls `seal()` automatically.
- **Deliberately still option-agnostic**: this state machine is genuinely shared
  infrastructure for both Option A and Option B — Option A's "denting" can hook into
  `apply_stagger`/health separately, and Option B's capture-base check can hook into
  `state_changed` / `seal()`. Nothing here forces the A vs B decision; that's still open
  for the team to feel out per the GDD.
- `state_changed` signal fires on every transition — HUD/hazards/anything else can listen
  without polling.

### One real ability, end to end — `scripts/abilities/quick_stand.gd`
- Sardinas' Quick Stand implemented against the actual `AbilityBase`/`CharacterBase` API
  (self-rights the character if it's Downed) — proves the ability-resource pattern works
  before the rest of the roster gets built out the same way.
- Left a note in the file: "once per round" vs. the generic cooldown timer is still an
  open call — right now it just uses `AbilityBase`'s cooldown field, set it long in the
  `.tres` resource to approximate once-per-round until `RoundManager` resets charges.

### Round / Match wiring — now autoloaded singletons
- `RoundManager`, `MatchManager`, `NetworkManager` are registered as autoloads in
  `project.godot` so any script can call `RoundManager.start_round()`,
  `MatchManager.report_round_result(...)`, etc. without manual node references.
- (Their `class_name`s were renamed to `RoundManagerScript` / `MatchManagerScript` to
  avoid a Godot class-name-vs-autoload-name collision — the autoload identifiers
  `RoundManager` / `MatchManager` are what you actually use in code.)
- `RoundManager`'s timer expiry now reports a Can-team win to `MatchManager`
  automatically (true under both Option A and B per the GDD). `report_round_win()` is
  the hook for whichever option gets built next to call when a round ends early.
- `MatchManager` swaps Attacker/Defender role each round and fires `match_won` at 3 wins.

### HUD — `scenes/ui/HUD.tscn`, `scripts/ui/hud.gd`
- Live timer (MM:SS), Bo5 score, round number, and Attack/Defense-per-team label — all
  reading straight from the `RoundManager`/`MatchManager` autoloads.
- A `DownedFlash` overlay is wired in and toggleable via `set_downed_flash()` — GDD
  Section 6 wants the Downed state to read instantly on stream; this is the hook,
  something (probably each character, on its own `state_changed` signal) still needs to
  call it.
- Drop this scene under a `CanvasLayer` anywhere and it works — already done in
  `Main.tscn`.

### Playable single-player scene — `scenes/main/Main.tscn`
- Now has **two** test characters (one `is_can = true`, one `is_can = false`) facing off,
  plus the HUD, plus a `main.gd` script that kicks off `MatchManager.begin_next_round()`
  on load so the round timer is actually running the moment you hit Play.
- Both characters currently answer to the *same* input map (single keyboard) — that's
  expected at this stage per the dev plan (step 1 says "two keyboards/input maps on one
  PC, or even just one character controllable for movement feel"). Splitting input per
  local player is a small, isolated change when someone gets to it (new input actions +
  an exported "player index" on `CharacterBase`), not a rewrite.

---

## What to actually do with this (suggested next session)

1. **Open it and press Play on `Main.tscn`.** Move the Can, press `bump` near the
   Tsinelas, confirm it staggers. That's the fastest way to feel whether the 0.15s bump
   window feels right or needs tuning.
2. **Wire `go_downed()` to something reachable in-game** — right now nothing calls it
   except a special with `forces_downed = true`. Pick a first pass: e.g. a heavier bump
   variant, or just call it manually from a debug key to test the self-right/seal flow
   before building the "knocked out of base circle" trigger for real.
3. **This is the natural point to finally test-drive Option A vs Option B** (dev plan
   Part 1, step 2) — the state machine and `RoundManager.report_round_win()` hook are
   ready for either. Whoever picks this up: wire one option, playtest, and if it doesn't
   feel good the swap-cost should be small by design.
4. **Build the remaining 5 abilities** the same way `quick_stand.gd` was built — extend
   `AbilityBase`, override `_do_activate()`, plug into a character's exported `ability`
   slot. Palayok's Shatter Trap and Bakya's Bakya Bash are the two that need a spawned
   Hitbox (`forces_downed = true`, `requires_bump_window = false`) rather than just
   calling a state-machine method directly.
5. **Networking is still untouched** beyond the `NetworkManager` skeleton — don't start
   this until the single-player loop above actually feels good, per the build-order
   reasoning in the dev plan.

## Open questions for the team (unchanged from the GDD, still not decided)

- Option A (stock/dents) vs. Option B (capture-base/downed-seal) for round win.
- Maps: locking Eskinita + Bayan Plaza, Palengke stretch-only — still needs a yes from
  everyone or an alternate pitch.
- Circular Economy as a secondary theme angle in the synopsis — free scoring upside,
  just needs someone to write the line.

## Repo state

Everything above is pushed to `main` on `Hanxavl/DOST-GameDev`. No open branches yet —
first real feature branch (probably `feature/round-win-prototype` for step 3 above) is a
good next move once someone's ready to test Option A/B in-editor.
