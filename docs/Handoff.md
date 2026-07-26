# Handoff — Tumbang Preso

The one handoff doc. Design is in [`Tumbang_Preso_2v2_GDD.md`](Tumbang_Preso_2v2_GDD.md); the
plan, architecture, and build status are in [`Dev_Plan.md`](Dev_Plan.md). **This file is the
work queue.** Read §1 and §2, then start at the top of §4.

> **Note for the humans:** the previous version of this file had no "System Context" or "AI
> Execution Protocol" sections. They were requested as sections to preserve verbatim, so they
> have been **written fresh** below (§1, §2) rather than carried over. Review them once —
> after that they are frozen and every future handoff must reproduce them unchanged.

---

## 1. System Context

**Project.** *Tumbang Preso* — a 2v2 LAN arena brawler for the Gear Up NCR Esports Game Dev
Challenge, built on the Filipino street game *tumbang preso*. Theme: Philippine Games and
Sports.

**Engine.** Godot 4.7, Forward+ renderer, GDScript only (no C#/.NET). Text-format `.tscn` and
`.tres`. Binary assets go through Git LFS.

**Shape of a match.** Two teams of two. Each team is **1 Person + 1 Prop**, where the Prop is a
Can (Lata) on defence or a Slipper (Tsinelas) on offence. All four units are player-controlled
and mobile. Teams swap Attacker/Defender role every round. 90-second rounds, best of five,
first to three round wins takes the match.

**Camera paradigm — a standing directive, not a preference.**

- **Person → FPP (first person), always.**
- **Prop (Can and Slipper) → TPP (third person), always.**

Derived from `is_person`; no toggle, no override, no per-map exception. This supersedes GDD
Sections 2 and 6 and the existing scene-level `ArenaCamera`. See `Dev_Plan.md` §0.1 and §3.

**Networking model.** ENet, LAN only, host + join by local IP. Host-authoritative for anything
that decides a round (hit resolution, timer, score). Client-authoritative for a peer's own
movement, replicated via `MultiplayerSynchronizer`. No reconciliation, no anti-cheat — LAN
prototype scope, deliberately.

**Local Match is a test harness.** `_start_local_test()`, the `p3`/`p4` input sets, and the four
hardcoded units in `Main.tscn` exist so one person can exercise the loop on one keyboard. **It
is stripped before submission.** Do not invest polish in it and do not let it shape the LAN
architecture.

**Two undecided design forks that block cleanup.**

- **Option A (dents) vs Option B (Downed→Seal).** Both are implemented behind
  `GameLaunch.game_mode`. Keeping both alive doubles the surface area of every combat change.
  The team has to pick one and delete the other.
- **Does the Person get its own ability roster**, parallel to the six Props, or does every Person
  share one Tag/Throw?

**Art direction.** `Mood Board.pdf` (Harry's Canva assets) is the visual source of truth.
Reference game called out on the board: **PEAK**. Chibi characters with oversized ball heads,
flat saturated colours, Filipino school-kid outfits. UI is deep navy on light blue-grey with a
blueprint grid, orange = offense, blue = defence, hand-drawn unicase marker display type.
Tokens are in `Dev_Plan.md` §4.2.

**Repo layout, git conventions, and the Godot setup walkthrough** are in `Dev_Plan.md` §6–§7.

---

## 2. AI Execution Protocol

For any coding agent picking up this queue.

1. **Work the queue in order.** §4 is sorted by dependency, not by size. P0 first. Do not skip
   ahead to UI because it is more fun — the LAN bugs gate everything, and three separate UI
   items are blocked on `team_id` landing first.
2. **Verify before you claim.** Every task has an *Acceptance* line. Meet it. If you cannot run
   the game to confirm, say so explicitly in the commit and mark the item `[~]`, not `[x]`.
   This project has a documented history of code that was written, reviewed, and never run;
   do not add to it.
3. **Report faithfully.** If something in this doc is wrong, say it is wrong instead of building
   around it. If a task turns out to be already done, say so and move on rather than rewriting
   working code. If you finish 8 of 10 items, say which 2 you did not do and why — do not
   silently narrow scope.
4. **Respect the architecture rules** in `Dev_Plan.md` §2. In particular: round-win logic stays
   out of `character_base.gd` and `hitbox.gd`; one `CharacterBase` scene with abilities as
   Resources; the host decides round outcomes; cameras are children of characters, never
   scene-level nodes holding `NodePath`s to players.
5. **The camera directive in §1 is not negotiable.** If any doc, comment, or older plan implies
   third-person for Persons, it is stale — fix the doc.
6. **One concern per commit,** with the bug ID in the subject (`Fix B-29: sync match state to
   late-joining clients`). Branch per feature off `main`. Keep `main` playable.
7. **Announce shared-scene edits.** `Main.tscn` and `CharacterBase.tscn` are touched by several
   queued items at once. Sequence them; do not run them in parallel.
8. **Duplicate ability Resources.** Cooldown state (`_time_since_use`, `_used_this_round`) lives
   on the `AbilityBase` Resource instance. Always `.duplicate()` a `.tres` per character or two
   characters share one cooldown.
9. **Update the ledger.** When a bug is fixed, mark it `**[FIXED]**` in §3 with a one-line
   description of the actual fix, and tick the matching box in `Dev_Plan.md` §5. When you find
   a new one, add it with the next free B-number.
10. **Do not delete Local Match yet** (§1) — it is the only way to playtest today. It goes in
    Phase 6.

---

## 3. Bug & Issue Ledger

Grouped by severity. B-01 to B-28 carry over from the previous audit; B-29 to B-48 are new from
this pass. IDs are referenced from `Dev_Plan.md` §5.

### P0 — LAN does not work today

**B-01 · A networked match never starts.** `MatchManager.begin_next_round()` RPC'd
`_sync_round_started` as `call_remote`, so the host never ran its own handler and
`RoundManager.start_round()` was never called by anybody.
**[FIXED]** `_sync_round_started` and `_sync_match_won` are now `@rpc("authority", "call_local",
"reliable")`. ⚠️ **Still unverified by a human.** Two editor instances (`--host` /
`--join=127.0.0.1`) must both see the timer move before this is closed.

**B-03 · `ArenaCamera` crashes every frame in networked play — this is the reported LAN
freeze.** `Main.tscn:43` points `follow_paths` at the four local-test nodes. Godot runs child
`_ready()` before parent `_ready()`, so `arena_camera.gd:32-37` resolves and **caches** those
four nodes; then `main.gd::_clear_local_test_characters()` (called first thing in *both*
`_start_hosting()` and `_start_joining()`) frees all four. From the next frame on, `_process`
calls `t.global_position` on four freed instances, 60+ times a second, on **both** the host and
every client. In the editor that floods the remote-debugger channel and hangs the editor — which
matches the report exactly ("the testing environment freezes"). "Only 1 player spawns and they
cannot be controlled" is downstream of the freeze: a solo host correctly spawns one character
(itself), and nothing responds because the process is drowning in errors.
*Fix:* the camera rigs (`Dev_Plan.md` §3) remove the scene-level camera entirely. Disable or
delete the `Camera3D` node in `Main.tscn` in the same commit. If `arena_camera.gd` is kept as a
broadcast cam, it must register targets at runtime and `is_instance_valid()`-check every frame.

**B-29 · A client that joins after the host started never learns the match state. (NEW)**
`_start_hosting()` calls `MatchManager.begin_next_round()` immediately (`main.gd:142`), which
broadcasts `_sync_round_started` — **before any client exists**. Godot does not replay reliable
RPCs to late joiners. So on a joining client: `round_number` stays 0, `team_a_is_can` stays at
its default, `main.gd::_on_match_round_started()` never fires, so `is_can` / `team_is_can_side`
are never recomputed and `RoundManager._tracked_cans` stays empty, and the HUD shows the
`.tscn` placeholder text forever. The client is in a different match from the host until round 2
happens to fire. This is the second half of "Host Game (LAN) does not work", alongside B-03.
*Fix:* on `player_connected`, the host `rpc_id()`s the full current state (round number,
`team_a_is_can`, both win counts, `time_left`, `round_active`, `GameLaunch.game_mode`) to that
one peer. Longer term this is the lobby (B-13).

**B-02 · Every special and Tag/Throw is a no-op for anyone who isn't the host.**
`ability_utils.gd:34` adds the pulse hitbox to `current_scene` on the activating peer only — it
is never replicated. `hitbox.gd:45` then returns early on any non-host peer. A client's ability
creates a hitbox that refuses to resolve, and the host never has that hitbox at all. Affects
Spin Guard, Bagsak Bomb, Bakya Bash, Flick Dash, and Person's Tag/Throw — every action except
Bump. *Fix:* RPC the activation to the host and spawn the resolving hitbox there; cosmetic
copies locally if you want the visual.

**B-04 · Networked Props spawn with no ability.** `main.gd:203` assigns `PERSON_ACTION_ABILITY`
only when `is_person` is true. Props — the half of the team carrying the entire roster — get
`ability = null` over the network. Only the local flow has an ability on a Prop, and only
because `Main.tscn:50` hardcodes `quick_stand.tres` on `TeamAProp`.

**B-30 · Networked characters never get a `player_id`. (NEW)** `_build_networked_character`
(`main.gd:196`) sets `is_can`, `is_person`, `team_is_can_side` and authority, but never
`player_id` — so all four networked characters keep the scene default of `1` and read `*_p1`
actions. It works by accident on LAN (one character per machine), but: the Settings panel's
entire P2 column is dead in networked play; the moodboard's WASD-for-Attacker /
arrow-keys-for-Defender scheme cannot be honoured; and any shared-screen fallback breaks
immediately. *Fix:* pass `player_id` through the spawn dictionary.

**B-48 · `GameLaunch.game_mode` is never networked. (NEW)** Each peer reads its own menu
selection. The host's mode governs hit resolution (`hitbox.gd:59`), but the client's
`_wire_downed_flash` dent gate (`main.gd:279`) reads the *client's* value — so a client on
Option B never shows a dent counter while the host runs Option A. Send `game_mode` with the
match-state sync in B-29.

### P1 — the core loop is wrong

**B-09 · No team identity — you can dent and seal your own Can.** `CharacterBase` has `is_can`,
`is_person`, and `team_is_can_side`, but **no `team_id` at all**. `hitbox.gd` only skips
`target == owner_character`, so a defending Person can dent its own Can and a teammate can seal
it. The team id exists in `main.gd::_peer_teams` and is never put on the character.
⚠️ **Do this one first.** Friendly-fire, nameplates (item 4), team colour distinction (item 8),
and the role-swap card (item 9) are all blocked behind it.

**B-15 / B-35 · No out-of-bounds handling, and the camera follows the faller forever. (B-35
NEW)** The arena is one 40×40 box with no walls, no kill plane, and no respawn — walk off the
edge and you fall forever with gravity accumulating. The camera half is separate and separately
broken: `arena_camera.gd` frames the **midpoint** of all targets and zooms out by FOV to fit
their **spread** (`arena_camera.gd:43-58`), so one player at y = −900 drags the whole shot down
and pins `_current_distance` at `max_distance` — everyone still playing is off-screen. *Fix:*
(a) invisible `StaticBody3D` walls at the arena edge; (b) a `KillPlane` Area3D at y ≈ −10 that
respawns the body at its spawn point; (c) per-character camera rigs (`Dev_Plan.md` §3) so no
camera can be dragged by someone else's fall; (d) if a broadcast cam survives, it ignores
targets below the kill plane. Also unblocks **ring-outs**, Option A's second win condition.

**B-10 / B-37 · Round reset covers one unit out of four, and there is no gap between rounds.
(B-37 NEW)** `round_manager.gd:99` loops `_tracked_cans`, which holds exactly the one defending
Can. The two Persons and the other Prop keep their `STAGGERED`/`DOWNED`/`SEALED` state, dent
count, speed multiplier, and spent once-per-round charges across rounds. **Nothing anywhere
writes `position` after spawn**, so round 2 starts wherever round 1 ended. Separately, the whole
chain `report_round_win → report_round_result → begin_next_round → _sync_round_started →
_on_match_round_started → start_round` runs **in a single frame** — there is no intermission
state, so there is nowhere for a role-swap card to live and no moment at which the world could
be reset. *Fix:* add the intermission state and `reset_world()` per `Dev_Plan.md` §4.6.

**B-42 · From round 2 onward the local test has an uncontrollable Can. (NEW)**
`_on_match_round_started` flips `team_a_is_can` each round, so in round 2 the tracked Can becomes
`TeamBProp` — `player_id = 3`, which is **deliberately unbound** in `project.godot`. The Can
cannot be moved, cannot self-right, and the round can only end on the timer. A local Bo5 is
therefore not playable past round 1 today. The requested debug player-switcher (queue item 1) is
what fixes this, which is why it is queued early rather than as a nicety.

**B-05 · Nothing ever rotates, so all directional attacks fire toward world −Z.**
`character_base.gd` never writes `rotation` and there is no aim input. The melee `Hitbox` sits at
a fixed local offset (`CharacterBase.tscn:60`), and `PersonAction`, `BakyaBash` and `FlickDash`
all use `-transform.basis.z`. A player moving east can only attack north. `rotation` is already
in the replication config and already replicated — it is just never written.
*Fix:* comes free with the camera rigs (`Dev_Plan.md` §3.2). The rig writes `rotation.y`. **Do
not build a separate aim axis.**

**B-06 · Quick Stand can never be activated.** `character_base.gd:142` returns early for
`STAGGERED`/`DOWNED`/`SEALED`; the `special_ability` input is read at line 160, *after* that
return. Quick Stand's only effect is self-righting from Downed — the exact state in which its
input is unreachable. Same structural problem for any future escape ability.

**B-07 · Any stagger cancels Downed.** `apply_stagger()` (line 164) overwrites `DOWNED` with
`STAGGERED`, which auto-recovers to `NORMAL` after 0.25s. Under Option B, `hitbox.gd:70` sends
`"stagger"` to a Can that is Downed but still inside its self-right window — so hitting a downed
Can *rescues* it. Any bump from anyone, including its own teammate, is a free escape. Option B's
seal mechanic cannot work until this is fixed.

**B-08 · Bump misses anyone you are already touching.** `hitbox.gd` only listens to
`area_entered`, but the melee Hitbox is always monitoring and is never enabled/disabled by the
bump window. Walk into someone and press bump → no new `area_entered` → no hit. You have to
press bump *before* closing distance, which is the opposite of how melee reads.
*Fix:* on bump press, also sweep `get_overlapping_areas()`.

**B-11 · A no-op activation still burns the cooldown.** `ability_base.gd:29` — `activate()` sets
`_time_since_use = 0` and `_used_this_round = true` before calling `_do_activate()`, which may do
nothing (Quick Stand while not Downed). Press the button once at the wrong moment and your
once-per-round charge is gone.

**B-12 · Friction is a per-frame constant, so there is no momentum and Flick Dash lasts three
frames.** `move_toward(velocity.x, 0, SPEED)` uses `SPEED` (6.0) as an absolute per-tick step,
not per-second — no `delta`. Max walk speed is also 6.0, so releasing a key stops you dead in one
tick, and it is frame-rate dependent if the physics tick ever changes. Flick Dash sets velocity
to 16 and it decays 16 → 10 → 4 → 0 in about 0.05s. The dash also applies a frame late, because
`_do_activate` runs after `move_and_slide()`.

### P2 — menu, flow, and polish

**B-33 · The disabled game mode is selectable and proceeds.** `main_menu.gd:34` adds "Option A —
Health / Dents (coming soon)" as an ordinary `OptionButton` item, and `_on_game_mode_selected`
writes it into `GameLaunch.game_mode` unconditionally — nothing gates Local/Host/Join on it.
⚠️ **The label is also wrong:** Option A has been fully implemented since Session 7
(`hitbox.gd:59`, `round_manager.gd:78`). So this is a decision, not just a fix: either drop the
"(coming soon)" suffix because the mode works, or genuinely disable it with
`set_item_disabled(1, true)` **and** grey out the Local/Host/Join buttons while it is selected.
Do not leave a third state where the label says one thing and the button does another.

**B-34 · No way back from the Play menu.** `_on_start_pressed` hides `TitleScreen` and shows
`PlayMenu`; nothing ever goes back. Settings is only reachable from `TitleScreen`, so once you
press Start you cannot reach Settings without restarting the game. *Fix:* a Back button on
`PlayMenu` and an `ui_cancel` handler doing the same thing.

**B-13 · The match starts before anyone joins.** `main.gd:142` calls `begin_next_round()` the
instant the host starts hosting. No lobby, no ready-up. Root cause of B-29.

**B-14 · Nothing resets between matches.** `MatchManager.team_a_wins` / `team_b_wins` /
`round_number` / `team_a_is_can` and `RoundManager`'s state live on autoloads that survive scene
changes. A second match continues the first one's score. Needs `reset()` on both.

**B-16 · `guard_dash` is bound, rebindable, and read by nothing.** The GDD lists Guard/Dash as a
shared basic for every character. `guard_dash_p1..p4` exist in `project.godot` and appear in the
Settings panel, but no script reads them. Players will press it and nothing happens.

**B-17 · `HazardZone` edge cases.** `_on_area_entered` calls
`owner_character.set_speed_multiplier()` with no null check (a Hurtbox whose owner isn't wired
crashes it). Exiting one zone resets speed to 1.0 even if you are still standing in another. And
a zone that expires while someone is inside relies on Godot firing `area_exited` during free —
verify before map hazards depend on it.

**B-18 · Round end isn't synced on timer expiry.** `round_manager.gd:116` `_on_time_up()` sets
`round_active = false` without a final `_sync_state` RPC.

**B-19 · `_sync_state` RPCs every rendered frame, per client**, purely to drive a HUD label that
changes once a second. Note it is in `_process`, not `_physics_process` as previously recorded —
so at 144 fps that is 144 packets/second/client. Harmless on a LAN, wasteful, trivially
throttled to ~4 Hz.

**B-20 · No way out of a match.** No pause, no Escape handler, no return-to-menu. Once
`Main.tscn` loads, the only exit is Alt+F4 — a bad look in a live demo. Doubly important once
FPP captures the mouse (`Dev_Plan.md` §3.2): a captured cursor with no release path traps the
player.

**B-21 · Team assignment uses `_spawned_peer_ids.size()` as the join index.** A disconnect
followed by a rejoin shifts every subsequent index, so teams and Person/Prop roles get
scrambled.

**B-22 · Settings allows duplicate bindings.** Rebinding P2's "up" to `W` silently makes both
local players move together, with no warning and no conflict detection.

**B-38 · A client's Bo5 score is stale for the whole final round. (NEW)** `hud.gd:23` reads
`MatchManager.team_a_wins` / `team_b_wins` directly every frame, but on a client those only ever
change inside `_sync_round_started` / `_sync_match_won`. So a client sees the *previous* round's
score for the entire round it is playing, and the winning score only lands with the match-won
RPC. Once the score becomes Bo5 pips (`Dev_Plan.md` §4.4) this will be very visible.

**B-23 · Dead code.** `RoundManager.round_won` and `Hitbox.landed_on` are emitted and nothing
listens — `landed_on` in particular is the natural hook for hit VFX/SFX and is currently only
emitted on the host. `CharacterBase.is_person` is read nowhere outside `main.gd`.

### P3 — feel, content gaps, and drift

**B-44 · There is no hit feedback of any kind. (NEW)** No sound, no particles, no hitstop, no
screenshake, no flash on the target, no controller rumble. A landed bump is a 0.25s velocity
change and nothing else. This is the single biggest "game feel" gap in the build, and the
moodboard explicitly specifies the missing pieces: *IMPACT EFFECT (particle burst)*, *CHARGED
THROW (glow effect)*, *BODY-BLOCK HITBOX (contact effect)*. `Hitbox.landed_on` already exists as
the hook (B-23) and needs to fire on every peer, not just the host.

**B-45 · The moodboard's throw is a charged, aimed action; the code's is an instant fixed-range
pulse. (NEW)** The Attacker card specifies *AIMING ARC (mouse pointer trail)* and *CHARGED THROW
(glow effect)* — hold to charge, aim with the mouse, release to throw. `person_action.gd` spawns
an instantaneous pulse hitbox at a fixed 4.0 units directly ahead. FPP + mouse-look
(`Dev_Plan.md` §3) makes the moodboard version genuinely achievable, and it is a far better
mechanic. **Design decision needed** — do not silently build either one.

**B-46 · The moodboard specifies a mechanic that is in neither the code nor the GDD. (NEW)** The
Defender card shows a *LATA RESET CHANNEL* with a progress bar — a defender channelling to stand
the Can back up. Nothing like it exists anywhere. **Design decision needed:** adopt it (it is a
good counterpart to the Downed/Seal window and gives the defending Person something to do), or
cut it from the moodboard so the art doesn't promise a mechanic that never ships.

**B-24 · Five of six roster specials are unreachable.** `shatter_trap.gd`, `spin_guard.gd`,
`bagsak_bomb.gd`, `bakya_bash.gd`, `flick_dash.gd` exist as scripts, but
`scripts/abilities/resources/` contains only `quick_stand.tres` and `person_action.tres`, and
`scenes/characters/cans/` and `tsinelas/` are empty. There is no character-select step.
Effectively the roster is one character.

**B-25 · Option A / Option B interaction with `forces_downed`.** Under Option A, `hitbox.gd:59`
turns any hit on a Can into a dent before the `forces_downed` branch is reached, so Bakya Bash's
"instant-down on direct hit" does nothing to a Can — the only target it is meant for. Whichever
option the team picks, this needs a decision.

**B-43 · Spawned pulse hitboxes are dropped in world space and never move. (NEW)**
`ability_utils.gd:34-35` parents the hitbox to `current_scene` and sets its position once. For
Spin Guard and Bagsak Bomb that is fine. For **Flick Dash** it is not: the script's own comment
says the hitbox "rides along with" the dash, but it is a static sphere at the activation point
while the character dashes away from it. Combined with B-12 (dash decays in ~0.05s) the ability
is close to inert. Also: these hitboxes are never cleaned up on round reset (B-10).

**B-26 · Stale comments and labels.** `hitbox.gd:5-8` says "both Hitbox and Hurtbox default to
layer 1" — they do not; `CharacterBase.tscn` sets Hurtbox to layer 2 / mask 0 and Hitbox to
layer 0 / mask 2, which is correct, so the comment is misleading in a load-bearing place.
`round_manager.gd:74` talks about "both tracked Cans" when only one Can exists per round.
`round_manager.gd:41` says role reassignment "isn't implemented yet" — it has been since
Session 7. The main menu still labels Option A "(coming soon)" (see B-33).

**B-27 · Name inconsistency.** `project.godot` says "Tumbang Laro", the README and GDD say
"Tumbang Laro: Isang Laban", the main menu says "TUMBANG PRESO", and the moodboard ships a
finished **TUMBANG PRESO** logo. Adopt the logo's name everywhere (`Dev_Plan.md` §0.3).

**B-28 · No export presets, no build, no CI.** `export_presets.cfg` is gitignored and none
exists. The game has never been run outside the editor, and the submission needs a real build.

---

## 4. Immediate Execution Queue

Prioritised: **P0 LAN → gameplay/reset → cameras → UI**. Every item has an acceptance test.
Tick items here and mirror them into `Dev_Plan.md` §5.

### P0 — Make LAN work

- [ ] **1. Debug player switcher (do this first — it unblocks all testing).**
      New `scripts/systems/debug_player_switcher.gd`, autoload, guarded by `OS.is_debug_build()`
      and inactive when `NetworkManager.is_networked()`. `F1`–`F4` select a unit directly, `Tab`
      cycles. On switch, move input focus, swap which unit reads the bound input set, and show
      `DEBUG · controlling TEAM A PROP (Can)` in the HUD. Fixes **B-42** — without it a local
      Bo5 cannot be played past round 1, because round 2's Can is `player_id = 3` and unbound.
      *Acceptance:* start a Local Match, press Tab four times, confirm you move a different unit
      each time and the HUD names the one you are driving.

- [ ] **2. Fix the LAN freeze (B-03).**
      Disable or delete the `Camera3D` node in `Main.tscn` (`Main.tscn:40-43`). It caches four
      `NodePath`s in `_ready()` and both `_start_hosting()` and `_start_joining()` free those
      nodes immediately after, so `_process` dereferences freed instances every frame on every
      peer. If `arena_camera.gd` is kept for broadcast use, convert it to runtime
      `register_target()` / `unregister_target()` with an `is_instance_valid()` guard, and
      default `current = false`. Ship this ahead of the camera rigs so LAN is testable today.
      *Acceptance:* Host Game (LAN) from the menu; no "previously freed instance" errors in the
      Output panel; the editor does not hang.

- [ ] **3. Sync full match state to joining clients (B-29, B-48).**
      On `NetworkManager.player_connected`, the host `rpc_id()`s that one peer the current
      `round_number`, `team_a_is_can`, `team_a_wins`, `team_b_wins`, `time_left`, `round_active`,
      and `GameLaunch.game_mode`. The client applies it and runs the same
      `_on_match_round_started` path the host does.
      *Acceptance:* two editor instances. Host first, wait ten seconds, then join. The client's
      timer matches the host's, the HUD shows the same round and roles, and the client's Can is
      registered.

- [ ] **4. Assign `player_id` to networked characters (B-30).**
      Pass it through the spawn dictionary in `_spawn_player` and apply it in
      `_build_networked_character`. Per the moodboard, keep WASD on the Attacker/Person set and
      arrow keys on the Defender/Can set.
      *Acceptance:* a client's character responds to its own bound set, and the Settings panel's
      P2 column has a visible effect in networked play.

- [ ] **5. Replicate ability activation to the host (B-02).**
      Route `AbilityBase.activate()` through an `any_peer` RPC to the host, which spawns the
      resolving hitbox. Spawn a cosmetic-only copy locally for responsiveness if you want; the
      cosmetic one must never resolve hits.
      *Acceptance:* a non-host client presses special and the host sees the target stagger.

- [ ] **6. Give networked Props their ability (B-04).**
      `_build_networked_character` assigns a `.duplicate()`d roster ability to Props, not just
      Persons. Until character select exists, default Props to `quick_stand.tres`.
      *Acceptance:* a client-controlled Prop can activate a special.

- [ ] **7. Verify B-01 with two instances.**
      `--host` and `--join=127.0.0.1`. Both timers must count down together. It is marked fixed
      and has never been run.
      *Acceptance:* screenshot or a note in the commit confirming both windows show a moving
      timer.

### P1 — Gameplay correctness and round reset

- [ ] **8. Add `team_id` to `CharacterBase` (B-09). Blocks items 12, 13, 14.**
      `@export var team_id: int = 0`, set from spawn data (networked) and from `Main.tscn`
      (local). Gate `hitbox.gd` on it so friendly fire cannot dent or seal your own Can.
      *Acceptance:* a Person bumping its own team's Can produces no dent and no seal.

- [ ] **9. Bounds, kill plane, and respawn (B-15, B-35).**
      Invisible `StaticBody3D` walls around the arena, plus a `KillPlane` Area3D at y ≈ −10 that
      returns any body entering it to its spawn point with `velocity = Vector3.ZERO`. Add a
      brief "OUT OF BOUNDS" HUD toast.
      *Acceptance:* walk off the edge — you respawn within ~1s, the camera stays with you, and
      no other player's view is disturbed.

- [ ] **10. Round intermission state + full world reset (B-10, B-37).**
      Add the intermission phase from `Dev_Plan.md` §4.6. `reset_world()` must return **all four**
      units to their map spawn points (position, velocity, facing), call `reset_for_new_round()`
      on all four, free every live `HazardZone` and orphaned pulse `Hitbox`, and re-broadcast
      state from the host. Move spawn points out of `main.gd:55` into a `SpawnPoints` node on the
      map scene.
      *Acceptance:* end a round with units scattered and one Downed — round 2 starts with all
      four at spawn, all `NORMAL`, dents cleared, once-per-round charges restored.

- [ ] **11. Verify and finish the Bo5 early-win (B-14, B-37).**
      ⚠️ **The 3-points-wins rule is already implemented** — `match_manager.gd:11` sets
      `WINS_NEEDED = 3` and `:43-48` calls `_finish_match()` on reaching it. Do not rebuild it.
      What is missing is everything *after* `match_won` fires: no match-result screen, no
      return-to-menu, and no `reset()` on `MatchManager` / `RoundManager`, so a second match
      resumes the first one's score. Build the match-end flow and the resets.
      *Acceptance:* win three rounds — a result screen appears, "Menu" returns to the main menu,
      and starting a new match begins at 0–0 round 1.

- [ ] **12. Fix the core-loop bugs (B-05 via rigs, B-06, B-07, B-08, B-11, B-12).**
      B-05 is delivered by item 15 — do not build a separate aim axis. The rest are independent
      and small. B-07 in particular blocks Option B entirely.
      *Acceptance:* Quick Stand can be pressed while Downed and works; bumping an already-Downed
      Can does not rescue it; walking into someone and then pressing bump lands; a no-op Quick
      Stand does not consume the charge; releasing a movement key decelerates over ~0.2s rather
      than stopping dead.

### P2 — Cameras (standing directive)

- [ ] **13. Build `CameraRig.tscn` + `camera_rig.gd` (`Dev_Plan.md` §3).**
      Mode **derived** from `is_person` at `_ready()` — **FPP for Person, TPP for Prop**, no
      export, no toggle. FPP: pivot at eye height, `near = 0.05`, `fov = 95`, pitch clamped
      −80°…+70° on the rig node only, own mesh set to `SHADOW_CASTING_SETTING_SHADOWS_ONLY`. TPP:
      `SpringArm3D` (length 4.5, y 1.2, x-rot −15°, collision mask = world) → `Camera3D`. The rig
      writes `_character.rotation.y` and must never touch `rotation.x` on the body. Exactly one
      camera `current` at a time; disable `_process` on inactive rigs.
      *Acceptance:* control a Person → first person, no visible body, shadow still present, look
      down far enough to see a Can at your feet. Control a Prop → third person, camera pulls in
      against a wall instead of clipping through. Attacks fire where you are looking (B-05
      closed).

- [ ] **14. Mouse capture and sensitivity.**
      `Input.MOUSE_MODE_CAPTURED` during a match, released on pause/Esc/focus-loss. Sensitivity
      slider and invert-Y in `SettingsManager` next to the keybinds. Local test uses
      `AimSource.MOVEMENT` for every unit that isn't the debug-controlled one — two players on
      one keyboard cannot both mouse-look, and that is accepted, not solved.
      *Acceptance:* Esc releases the cursor and reopens it on resume; sensitivity persists across
      a restart.

### P3 — UI overhaul (moodboard)

- [ ] **15. Design system (`Dev_Plan.md` §4.2).**
      `assets/ui/tumbang_preso.theme` + a `UiTheme` autoload of the same constants.
      `INK #040838`, `PANEL #E1E5E8`, `OFFENSE #F87020`, `DEFENSE #0080E8`, `IMPACT #F468A8`,
      `HIGHLIGHT #F8D028`, `DANGER #F80000`. `StyleBoxFlat` card chrome: 3px `INK` border,
      6px radius, 16px margins, 6px full-height accent bar. Theme type variations for buttons and
      labels — no more per-node `theme_override_*`.
      **Get the display font from Harry** (heavy hand-drawn unicase marker face); if it cannot be
      redistributed, use Luckiest Guy / Chewy / Titan One (SIL OFL). Add `*.ttf` and `*.otf` to
      `.gitattributes` LFS. **Record the licence for submission Form 03.**
      *Acceptance:* setting the theme on a scene root restyles its whole subtree with no per-node
      overrides.

- [ ] **16. Menu fixes and restyle (B-33, B-34, B-27).**
      Add a **Back** button to `PlayMenu` plus an `ui_cancel` handler. Resolve the Option A
      contradiction — either drop "(coming soon)" because it works, or `set_item_disabled()` it
      *and* disable Local/Host/Join while it is selected. Swap the title `Label` for the logo.
      Set the game name to **TUMBANG PRESO** in `project.godot`, the README, and the GDD.
      *Acceptance:* Start → Back → Settings works without restarting; a disabled mode cannot be
      launched; the name is identical in all four places.

- [ ] **17. HUD rebuild (`Dev_Plan.md` §4.4, B-38).**
      Bo5 **pips** instead of "2 - 1". Per-team panels carrying the role colour and the team
      letter. Timer to `HIGHLIGHT` under 15s, pulsing under 10s. Bottom-left "YOU" card with
      portrait, role, and a radial ability cooldown. Crosshair in FPP only. `DownedFlash` becomes
      a vignette. Fix the client-side stale score (B-38).
      *Acceptance:* a client's pips update the moment a round is won, not a round later.

- [ ] **18. Player and team distinction in-world (items 4 and 8; needs item 8's `team_id`).**
      Ground ring decal under every unit in the team's **current role colour** (orange offense,
      blue defence) — this is the primary read, not a floating label. `Label3D` billboard tag
      `A1`/`A2`/`B1`/`B2` with a role glyph, fading past ~15m. A distinct chevron and brighter
      ring on your own unit. **In local test only**, append the input set (`A1 · WASD`,
      `A2 · ARROWS`). Off-screen edge arrows for your teammate and the Can — mandatory for FPP.
      *Acceptance:* from any camera in either mode, you can name every unit's team and role
      within a second, and find your own body after a respawn.

- [ ] **19. Role-swap intermission card (item 9; needs item 10's intermission state).**
      Sequence per `Dev_Plan.md` §4.6: round-result banner → role-swap card with both team panels
      sliding across and recolouring (`TEAM A  🔵 DEFENSE → 🟠 OFFENSE`) → world reset → "ROUND n
      — FIGHT" wipe → next round. Roughly 4s total, skippable by all-ready or a timeout.
      *Acceptance:* at the end of a round it is unmistakable which team is attacking next, and
      the units visibly return to spawn during the card.

- [ ] **20. Match result screen (with item 11).**
      Bo5 grid showing every round's winner, the match winner in display type, Rematch and Menu.
      *Acceptance:* reachable by actually winning three rounds, and Menu leaves both autoloads
      reset.

### Decisions the team owes before Phase 4

These are blocking someone's work and cannot be resolved by a coding agent.

- [ ] **Option A or Option B.** Both are alive and it doubles the cost of every combat change
      (see B-25). Play both, pick one, delete the other.
- [ ] **B-45 — charged/aimed throw** (per the moodboard) **or the current instant pulse?** FPP +
      mouse-look makes the moodboard version achievable and it is the better mechanic.
- [ ] **B-46 — is the "Lata Reset Channel" a real mechanic?** It is on the moodboard and in
      neither the code nor the GDD. Adopt it or cut it from the art.
- [ ] **Does the Person get its own ability roster**, or does every Person share one Tag/Throw?
- [ ] **Maps** — Eskinita + Bayan Plaza locked, Palengke as stretch. Still needs a yes.
- [ ] **Title** — adopt the moodboard's **TUMBANG PRESO** (recommended; the logo is finished) or
      keep "Tumbang Laro: Isang Laban". Pick before the trailer.
- [ ] **Ownership tables** — `Dev_Plan.md` §6 and GDD Section 8. Both still blank, third time of
      asking.
- [ ] **Circular Economy** as a secondary theme angle in the synopsis — free scoring upside, just
      needs someone to write the line.

---

## 5. Two things nobody has scheduled, both on the critical path

- **Real multi-device LAN testing.** Everything so far is loopback on one machine. Real wifi adds
  latency and packet loss to a movement layer with no interpolation and no reconciliation. If
  that forces the shared-screen fallback (GDD Section 7), you want to know weeks before the
  deadline. Note that the FPP/TPP split raises the cost of that pivot — four viewports, and only
  one player per machine can mouse-look (`Dev_Plan.md` §5, Fallback trigger). **Book four laptops
  now.**
- **Art.** `assets/` is still empty. Everything on screen is a grey capsule on a grey box. The
  moodboard is a real step forward, but it is a reference, not a shipped asset. Judges see the
  screen before they see any system working. This is a parallel workstream that should already
  be running.

## 6. Working notes

- `.tscn`/`.tres` are text. Give a heads-up before editing `Main.tscn` or `CharacterBase.tscn` at
  the same time as someone else — items 13 and 18 both touch `CharacterBase.tscn`.
- `git lfs install` before adding any art, font, or audio.
- Ability cooldown/charge state lives on the Resource instance — always `.duplicate()` an ability
  `.tres` per character, or two characters share one cooldown.
- Combat networking is deliberately unvalidated: the host trusts client-reported bump timing.
  Fine for a LAN demo, out of scope to harden.
- Set the base resolution (1920×1080) and stretch mode **before** building the UI theme, or every
  size gets retuned later.
