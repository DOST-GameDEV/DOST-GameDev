# Handoff — Tumbang Laro

The one handoff doc. Replaces the per-session handoffs (Sessions 2–9), which were merged
into this and deleted. Design is in [`Tumbang_Preso_2v2_GDD.md`](Tumbang_Preso_2v2_GDD.md),
the plan and current build status are in [`Dev_Plan.md`](Dev_Plan.md).

---

## 1. What exists

Nine dev sessions of scaffolding. In order of what was built:

- **Scaffold** — folder structure, `.gitignore`, LFS attributes, `CharacterBase` movement,
  the `AbilityBase` Resource pattern, round/match/network skeletons.
- **Combat + state machine** — `Hitbox`/`Hurtbox` with a 0.15s press-to-bump window;
  `NORMAL → STAGGERED → NORMAL` and `NORMAL → DOWNED → (self-right | sealable → SEALED)`;
  HUD with live timer, Bo5 score, round, role, downed flash.
- **All six specials written** — Quick Stand, Shatter Trap, Spin Guard, Bagsak Bomb, Bakya
  Bash, Flick Dash, plus `AbilityUtils.spawn_pulse_hitbox()` and a reusable `HazardZone`.
- **Per-player input split** — `*_p1` … `*_p4` action sets, `player_id` export, `_action()`
  resolver. `ArenaCamera` follow-and-zoom rig.
- **LAN networking** — real ENet host/join, `MultiplayerSpawner` + `MultiplayerSynchronizer`,
  per-peer authority over one's own character.
- **Host-authoritative combat** — clients detect overlaps but only the host resolves them and
  RPCs the result to the target's owning peer. `RoundManager`/`MatchManager` mirrored to
  clients by RPC.
- **2v2 structure** — teams fixed for the match, Attacker/Defender side swapping each round,
  main menu with Local/Host/Join and an Option A/B picker.
- **Team = 1 Person + 1 Prop** — Person tags on defense / throws on offense (`PersonAction`);
  Prop is the Can or Slipper and carries the roster ability. Only Props matter to round-win.
- **Option A (dents) and Option B (Downed→Seal)** both implemented behind
  `GameLaunch.game_mode`.
- **Settings panel** — rebindable, persistent (`user://settings.cfg`) P1/P2 controls.

## 2. What has actually been played

Confirmed by a human: movement, per-player input, camera follow, menu navigation.

**Never confirmed by anyone:** bump landing, stagger, Downed, self-right, seal, dents, any
special, any round ending, any match ending, and every network path past "the peers
connect". Most of the code below was written and reviewed, not run. The bug list reflects
that — several of these would have been caught in the first five minutes of playtesting.

---

## 3. Bugs and problems

Grouped by severity. IDs are referenced from `Dev_Plan.md`'s build order.

### P0 — the LAN demo does not work today

**B-01 · A networked match never starts.**
`scripts/systems/match_manager.gd:29` — `begin_next_round()` does
`if is_networked(): _sync_round_started.rpc(...) else: round_started.emit(...)`. The RPC is
declared `@rpc("authority", "call_remote", ...)`, so it explicitly does **not** run on the
sender. The host therefore never emits `round_started` locally, so `main.gd`'s
`_on_match_round_started` never runs on the host, so `RoundManager.start_round()` — which is
host-only — is never called by anybody. The timer never starts, `round_active` stays false,
no Cans get registered, and no round can ever be won. `_finish_match()` at line 51 has the
identical bug for `match_won`. This is almost certainly the "timer doesn't even move"
report from Session 9, which was investigated only against the local flow and written off as
not reproducible.
*Fix:* emit the signal locally on the host as well as RPCing it, or make the RPCs
`call_local` and drop the `else`.
**[FIXED]** `_sync_round_started` and `_sync_match_won` are now `@rpc("authority", "call_local",
"reliable")`, so the host's own call to `.rpc(...)` also runs its handler locally instead of
only reaching remote peers. Needs verification with two editor instances
(`--host` / `--join=127.0.0.1`) that both see the timer move.

**B-02 · Every special and Tag/Throw is a no-op for anyone who isn't the host.**
`scripts/abilities/ability_utils.gd:34` adds the pulse hitbox to `current_scene` on the
activating peer only — it is never replicated. `scripts/characters/hitbox.gd:45` then returns
early on any non-host peer. So a client's ability creates a hitbox that refuses to resolve,
and the host never has that hitbox at all. Affects Spin Guard, Bagsak Bomb, Bakya Bash,
Flick Dash, and Person's Tag/Throw — i.e. every action except Bump.
*Fix:* RPC the activation to the host and spawn the resolving hitbox there (cosmetic copies
locally if you want the visual).
**[FIXED]** `CharacterBase._physics_process` still calls `ability.activate(self)` locally
(cosmetic hitbox/movement effect on the activating peer, e.g. Flick Dash's velocity kick), and
now also RPCs `_rpc_notify_ability_activate` to the host (id 1) when the activator isn't the
host — same pattern as the existing bump RPC. The host runs `activate()` on its own copy of
the character/ability, so the authoritative resolving hitbox exists on the host where
hitbox.gd can actually process it. Needs verification with two editor instances that a
client's special/Tag-Throw lands on the host.

**B-03 · `ArenaCamera` breaks in networked play.**
`scenes/main/Main.tscn:43` points `follow_paths` at the four local-test nodes. Godot runs
child `_ready()` before parent `_ready()`, so the camera resolves and caches those nodes,
and then `main.gd::_clear_local_test_characters()` frees all four. `_process` dereferences
freed objects every frame. Networked characters are never added as targets, so even without
the errors the camera would sit still while everyone plays off-screen.
*Fix:* register/unregister targets at runtime instead of caching from `_ready()`.
**[FIXED]** `ArenaCamera` now has `add_target()`/`remove_target()` and filters freed instances
out of `_targets` every `_process()` frame instead of dereferencing them (fixes the crash from
`_clear_local_test_characters()`). `main.gd` calls `add_target()` on every networked spawn
(`_build_networked_character`) and `remove_target()` on disconnect, so real network peers are
now actually followed. `follow_paths` still works unchanged for the local-test flow. Needs
verification in networked play that the camera frames both peers instead of sitting still.

**B-04 · Networked Props spawn with no ability.**
`scripts/main.gd:205` assigns `PERSON_ACTION_ABILITY` only when `is_person` is true. Props —
the half of the team that carries the entire roster (Quick Stand, Bakya Bash, …) — get
`ability = null` over the network. Only the local test flow has an ability on a Prop, and
only because `Main.tscn` hardcodes `quick_stand.tres` on `TeamAProp`.
**[FIXED]** `_build_networked_character` now assigns a `.duplicate()` of a new `PROP_ABILITY`
constant (`quick_stand.tres`, the only roster resource that currently exists) to every
networked Prop, mirroring what `Main.tscn` already hardcodes for the local flow. This does
NOT give each Prop its own distinct roster ability — that needs the other five `.tres`
resources and a character-select step (B-24/Phase 2) — it just stops Props from spawning with
`ability = null` over the network.

### P1 — the core loop is wrong

**B-05 · Nothing ever rotates, so all directional attacks fire toward world −Z.**
`character_base.gd` never writes `rotation` and there is no aim input. The melee `Hitbox` sits
at a fixed local offset (`CharacterBase.tscn:60`), and `PersonAction`, `BakyaBash`, and
`FlickDash` all use `-transform.basis.z`. A player moving east can only attack north. The
`rotation` property is in the replication config and is replicated — it's just never changed.
**[FIXED]** Movement direction is now computed as `Vector3(input_dir.x, 0, input_dir.y)`
directly (world space) instead of `transform.basis * input_dir` — the old formula made
movement direction depend on current facing, which would have produced relative/tank-style
turning the moment facing started changing. The character now `look_at()`s its movement
direction whenever `direction` is nonzero, so `-transform.basis.z` (and the melee Hitbox's
local offset) actually points where the player is moving. Needs verification in-editor that
movement still feels like absolute WASD and that Bump/specials land in the facing direction.

**B-06 · Quick Stand can never be activated.**
`character_base.gd:142` returns early for `STAGGERED`/`DOWNED`/`SEALED`; the
`special_ability` input is read at line 160, *after* that return. Quick Stand's only effect
is self-righting from Downed — the exact state in which its input is unreachable. Same
structural problem for any future "escape" ability.
**[FIXED]** The `State.DOWNED` branch of the state `match` (which runs before the
STAGGERED/DOWNED/SEALED early return) now also checks `special_ability` and calls
`ability.activate(self)` there, same RPC-to-host call as the main check further down. Other
states (STAGGERED, SEALED) still can't activate anything — only DOWNED needed the carve-out.
`is_ready()`/`once_per_round` on the ability itself still gates whether anything actually
happens; a non-escape ability (e.g. Spin Guard) pressed while Downed will still run its
`_do_activate()` if off cooldown, same as it always could from NORMAL — worth a look once
someone's playtesting, but not a new bug introduced by this fix.

**B-07 · Any stagger cancels Downed.**
`apply_stagger()` (line 164) overwrites `DOWNED` with `STAGGERED`, which auto-recovers to
`NORMAL` after 0.25s. Under Option B, `hitbox.gd:65` sends `"stagger"` to a Can that's Downed
but still inside its self-right window — so hitting a downed Can *rescues* it. Any bump from
anyone, including its own teammate, is a free escape. Option B's seal mechanic cannot work
until this is fixed.
**[FIXED]** `apply_stagger()` now returns early for `DOWNED` as well as `SEALED`, so a hit
landing on a still-self-rightable Can does nothing instead of bumping it back to STAGGERED/
NORMAL. `hitbox.gd` still separately routes a hit AFTER the self-right window expires to
`"seal"` rather than `"stagger"`, so sealing is unaffected — this only closes the free-rescue
window. Needs verification that a teammate/opponent bumping a Downed Can no longer un-downs
it, and that self-right (via the Can's own bump input, `character_base.gd`'s DOWNED match
branch) still works.

**B-08 · Bump misses anyone you're already touching.**
`hitbox.gd` only listens to `area_entered`, but the melee Hitbox is always monitoring and is
never enabled/disabled by the bump window. Walk into someone and press bump → no new
`area_entered` → no hit. You have to press bump *before* closing distance, which is the
opposite of how melee reads.
*Fix:* on bump press, also sweep `get_overlapping_areas()`.
**[FIXED]** `Hitbox.sweep_overlaps()` re-runs `_on_area_entered()` against everything already
in `get_overlapping_areas()`. `CharacterBase` caches its melee Hitbox (`requires_bump_window
== true`) in `_ready()` and calls `sweep_overlaps()` from a new shared `_open_bump_window()`
helper, used both when the local player presses bump and in the host's `_rpc_notify_bump`
handler (so a remote peer's already-touching bump also resolves correctly on the host). Needs
verification that walking into someone and then pressing bump now lands a hit.

**B-09 · No team check — you can dent and seal your own Can.**
`CharacterBase` has `is_can`, `is_person`, and `team_is_can_side`, but no team identity at
all. `hitbox.gd` only skips `target == owner_character`. So under Option A a defending
Person bumping its own Can adds a dent, and three of those lose your own round. Under Option
B a teammate can seal your Can. The team id exists in `main.gd::_peer_teams` but is never
put on the character.
**[FIXED]** New `team: int` export on `CharacterBase` (0 = Team A, 1 = Team B). `main.gd` sets
it from spawn data (`data["team"]`) in `_build_networked_character`, and explicitly for all
four local-test units in `_start_local_test()` (they'd otherwise all sit at the default 0 and
block every bump against each other once the check below exists). `hitbox.gd`'s
`_on_area_entered` now returns early when `target.team == owner_character.team`. Needs
verification that bumping a teammate no longer does anything, and bumping an opponent still
does.

**B-10 · Only one of the four units is reset between rounds.**
`round_manager.gd:99` loops `_tracked_cans`, which holds exactly the one Can. The two Persons
and the Slipper-side Prop keep their `STAGGERED`/`DOWNED`/`SEALED` state, their dent count,
their speed multiplier, and their spent once-per-round ability charges across rounds. Nothing
resets any character's *position* between rounds either, so round 2 starts wherever round 1
ended.
**[FIXED]** `main.gd::_on_match_round_started` now calls `character.reset_for_new_round()` and
sets `character.position` from `SPAWN_POINTS` for all four units every round, in both the
networked branch (looping `_spawned_characters`) and the local-test branch (looping
`_local_roster`) — not just whichever Prop happens to be the tracked Can this round.
`RoundManager.start_round()`'s own tracked-Can-only reset is now redundant for that one
character but harmless (idempotent). Needs verification that Downed/dent/speed-multiplier
state and position don't carry over into round 2.

**B-11 · A no-op activation still burns the cooldown.**
`ability_base.gd:29` — `activate()` sets `_time_since_use = 0` and `_used_this_round = true`
before calling `_do_activate()`, which may do nothing (Quick Stand while not Downed). Press
the button once at the wrong moment and your once-per-round charge is gone.
**[FIXED]** `_do_activate()` now returns `bool` (default `true` in the base class);
`activate()` only sets `_time_since_use = 0` / `_used_this_round = true` when it returns
`true`. `quick_stand.gd` returns `false` when the character isn't Downed (the real no-op
case); the other five ability scripts (`shatter_trap`, `spin_guard`, `bagsak_bomb`,
`bakya_bash`, `flick_dash`, `person_action`) always return `true`, matching their existing
always-succeeds behavior — no change to when they fire, just to the return type.

**B-12 · Friction is a per-frame constant, so there is no momentum and Flick Dash lasts three frames.**
`move_toward(velocity.x, 0, SPEED)` uses `SPEED` (6.0) as an absolute per-tick step, not
per-second — no `delta`. Max walk speed is also 6.0, so releasing a key stops you dead in one
tick, and it's frame-rate dependent if the physics tick is ever changed. Flick Dash sets
velocity to 16 and it decays 16 → 10 → 4 → 0 in about 0.05s. The dash also applies a frame
late, because `_do_activate` runs after `move_and_slide()`.

### P2 — real problems, not blocking a first playtest

**B-13 · The match starts before anyone joins.** `main.gd:144` calls `begin_next_round()` the
instant the host starts hosting. Anyone who joins after that never receives the
`_sync_round_started` RPC, so their HUD shows placeholder text and their `is_can` is never
recomputed. There is no lobby or ready-up.

**B-14 · Nothing resets between matches.** `MatchManager.team_a_wins` / `team_b_wins` /
`round_number` / `team_a_is_can` and `RoundManager`'s state live on autoloads that survive
scene changes. A second match continues the first one's score. Needs a `reset()` on both.

**B-15 · No out-of-bounds handling.** The arena is one 40×40 box. Walk off the edge and you
fall forever with gravity accumulating; there is no respawn and no kill plane. This is also
what blocks **ring-outs**, Option A's second win condition for Cans.

**B-16 · `guard_dash` is bound, rebindable, and read by nothing.** The GDD lists Guard/Dash as
a shared basic for every character. `guard_dash_p1..p4` exist in `project.godot` and appear
in the Settings panel, but no script reads them. Players will press it and nothing happens.

**B-17 · `HazardZone` edge cases.** `_on_area_entered` calls
`owner_character.set_speed_multiplier()` with no null check (a Hurtbox whose owner isn't wired
crashes it). Exiting one zone resets speed to 1.0 even if you're still standing in another.
And a zone that expires while someone is inside relies on Godot firing `area_exited` during
free — worth verifying before map hazards depend on it.

**B-18 · Round end isn't synced on timer expiry.** `round_manager.gd:116` `_on_time_up()` sets
`round_active = false` without a final `_sync_state` RPC, so clients keep believing the round
is live until the next round's sync arrives.

**B-19 · `_sync_state` RPCs every physics frame, per client**, purely to drive a HUD label
that changes once a second. Harmless on a LAN, wasteful, and easy to throttle.

**B-20 · No way out of a match.** No pause, no Escape handler, no return-to-menu. Once
`Main.tscn` loads, the only exit is Alt+F4 — which is a bad look in a live demo.

**B-21 · Team assignment uses `_spawned_peer_ids.size()` as the join index.** A disconnect
followed by a rejoin shifts every subsequent index, so teams and Person/Prop roles get
scrambled.

**B-22 · Settings allows duplicate bindings.** Rebinding P2's "up" to `W` silently makes both
local players move together, with no warning and no conflict detection.

**B-23 · Dead code.** `RoundManager.round_won` and `Hitbox.landed_on` are emitted and nothing
listens — `landed_on` in particular is the natural hook for hit VFX/SFX and is currently only
emitted on the host. `CharacterBase.is_person` is set everywhere and read nowhere outside
`main.gd`.

### P3 — content gaps and drift

**B-24 · Five of six roster specials are unreachable.** `shatter_trap.gd`, `spin_guard.gd`,
`bagsak_bomb.gd`, `bakya_bash.gd`, `flick_dash.gd` exist as scripts, but
`scripts/abilities/resources/` only contains `quick_stand.tres` and `person_action.tres`, and
`scenes/characters/cans/` and `tsinelas/` are empty. There is also no character-select step.
Effectively the roster is one character.

**B-25 · Option A / Option B interaction with `forces_downed`.** Under Option A,
`hitbox.gd:59` turns any hit on a Can into a dent before the `forces_downed` branch is
reached, so Bakya Bash's "instant-down on direct hit" does nothing to a Can — the only target
it's meant for. Whichever option the team picks, this needs a decision.

**B-26 · Stale comments and labels.** `round_manager.gd:74` and the Session 7 notes talk about
"both tracked Cans" needing to be dented, but only one Can exists per round (the defending
team's Prop) — the loop is effectively a single check. The main menu still labels Option A
"(coming soon)" though it has been implemented since Session 7.

**B-27 · Name inconsistency.** `project.godot` says "Tumbang Laro", the README and GDD say
"Tumbang Laro: Isang Laban", and the main menu on screen says "TUMBANG PRESO". Pick one
before recording the trailer.

**B-28 · No export presets, no build, no CI.** `export_presets.cfg` is gitignored and none
exists. The game has never been run outside the editor, and the submission needs a real
build.

---

## 4. How to continue

### Right now, in order

1. **Open the project and press F5.** Confirm the menu → Local Match flow still runs after
   the doc changes. Nothing below matters if it doesn't.
2. **Fix B-01.** It is a few lines and it is the difference between having a networked demo
   and not having one. Verify with two editor instances (`--host` / `--join=127.0.0.1`) that
   both see the timer move.
3. **Fix B-02, B-03, B-04.** After these four, a LAN match is playable end to end for the
   first time. That is Phase 0 in `Dev_Plan.md`.
4. **Play a full round and write down what feels wrong.** B-05 through B-12 are all things a
   real playtest will make obvious and prioritise better than this list can.
5. **Decide Option A or Option B and delete the loser.** Both being alive is now costing more
   than it buys — it doubles the surface area of every combat change (see B-25). The
   architecture made the swap cheap; take the payoff and commit.

### Then

Phase 2 onward in [`Dev_Plan.md`](Dev_Plan.md): roster resources and character select, then
maps, then feel and presentation, then submission. Ring-outs (B-15) and Guard/Dash (B-16) are
the two GDD-promised mechanics that don't exist yet.

### Two things nobody has scheduled and both are on the critical path

- **Real multi-device LAN testing.** Everything so far is loopback on one machine. Real wifi
  adds latency and packet loss to a movement layer that has no interpolation and no
  reconciliation. If this is going to force the shared-screen fallback (GDD Section 7), you
  want to know weeks before the deadline, not days. **Book a session with four laptops now.**
- **Art.** `assets/` is empty. Everything on screen is a grey capsule on a grey box. Judges
  see this before they see any of the systems work above, and no amount of camera or gameplay
  work compensates. This is a parallel workstream that should already be running.

### Still open for the team (from the GDD)

- Option A vs Option B — see above, decide it.
- Maps: Eskinita + Bayan Plaza locked, Palengke as stretch — still needs a yes or an
  alternate pitch.
- Does Person get its own roster of distinct abilities, parallel to the six Props, or does
  every Person stay identical with one shared Tag/Throw?
- Circular Economy as a secondary theme angle in the synopsis — free scoring upside, just
  needs someone to write the line.
- Ownership table in `Dev_Plan.md` Section 4 and GDD Section 8 — still blank.

### Working notes

- `.tscn`/`.tres` are text; give a heads-up before editing `Main.tscn` or
  `CharacterBase.tscn` at the same time as someone else.
- `git lfs install` before adding any art or audio.
- Ability cooldown/charge state lives on the Resource instance — always `.duplicate()` an
  ability `.tres` per character, or two characters share one cooldown.
- Combat networking is deliberately unvalidated: the host trusts client-reported bump timing.
  Fine for a LAN demo, out of scope to harden.
