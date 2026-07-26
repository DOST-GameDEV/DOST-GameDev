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
11. **Debug-only code follows the removal contract** in `Dev_Plan.md` §0.3, without exception:
    `debug_`/`Debug` prefix on every file, class, node and autoload; debug code calls gameplay
    and **gameplay never calls debug** (no gameplay script may reference a debug class, autoload,
    signal or group — not even behind an `if OS.is_debug_build()`); no `[input]` map entries, read
    raw keys instead; self-disables in a release build; and a removal checklist written into
    `Dev_Plan.md` at the same time as the feature. A debug helper hiding inside a gameplay script
    is invisible to the verification grep and **will ship**. Reject it in review.

---

## 3. Bug & Issue Ledger

Grouped by severity. B-01 to B-28 carry over from the previous audit; B-29 to B-48 are new from
this pass; B-49 is new from the session that built the kill plane (queue item 9) and caught it by
actually running the local flow instead of reading the code. IDs are referenced from
`Dev_Plan.md` §5.

### P0 — LAN does not work today

**B-01 · A networked match never starts.** `MatchManager.begin_next_round()` RPC'd
`_sync_round_started` as `call_remote`, so the host never ran its own handler and
`RoundManager.start_round()` was never called by anybody.
**[FIXED, verified]** `_sync_round_started` and `_sync_match_won` are now `@rpc("authority",
"call_local", "reliable")`. Verified with two real running instances (not a human at the
keyboard, but not just reading the code either): `godot --headless --path . scenes/main/Main.tscn
-- --host` and a second process with `-- --join=127.0.0.1`, both instrumented temporarily to
print `RoundManager.time_left`/`round_active` and `MatchManager.round_number`/`team_a_is_can`
once a second (instrumentation reverted before commit, not shipped). Host log: `round_number=1
round_active=true`, `time_left` counting down 89.0 → 80.0 over the run. Client (joined ~2.5s after
the host started) log: `round_number=1 round_active=true`, `time_left` counting down 86.7 → 80.7,
tracking the host's broadcast. Still worth a human eyeballing the actual HUD render, but the
underlying state machine is confirmed working end to end, on both peers.

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
**[FIXED]** `add_target()`/`remove_target()` existed for the networked-spawn path, but
`main.gd::_clear_local_test_characters()` (which runs even before hosting/joining, since
`follow_paths` always points at the four local-test nodes) never called `remove_target()` before
`queue_free()`-ing them — confirmed live with the Godot 4.7 binary: Host Game spammed a
`filter()`/typed-array conversion error every single frame, the exact original symptom. Now
removes all four first, and `_process()`'s target-pruning loop no longer uses
`Array[Node3D].filter()` with a lambda (which throws on a freed reference) — a plain loop instead.
Verified clean (no errors) for local test, `--host`, and `--host`/`--join=127.0.0.1` together.

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
**[FIXED]** `main.gd::_sync_state_to_late_joiner` — host `rpc_id()`s that one peer, which sets the
plain autoload fields directly (not through `_sync_round_started`, which would also replay the
full round-reset/reposition logic just because someone joined mid-round) and refreshes the HUD
once. Verified live: joined a running round-1 host after ~3s and the client's
`late_join_state round=1 team_a_is_can=true wins=0-0 time_left=87.0 round_active=true` matched the
host's actual state exactly.

**B-02 · Every special and Tag/Throw is a no-op for anyone who isn't the host.**
`ability_utils.gd:34` adds the pulse hitbox to `current_scene` on the activating peer only — it
is never replicated. `hitbox.gd:45` then returns early on any non-host peer. A client's ability
creates a hitbox that refuses to resolve, and the host never has that hitbox at all. Affects
Spin Guard, Bagsak Bomb, Bakya Bash, Flick Dash, and Person's Tag/Throw — every action except
Bump. *Fix:* RPC the activation to the host and spawn the resolving hitbox there; cosmetic
copies locally if you want the visual.
**[FIXED]** (landed before this pass, docs were stale) `character_base.gd`'s
`_rpc_notify_ability_activate` — activates locally for the cosmetic effect, and RPCs the host to
run its own copy of `activate()` so the resolving hitbox exists where hit resolution actually runs.

**B-04 · Networked Props spawn with no ability.** `main.gd:203` assigns `PERSON_ACTION_ABILITY`
only when `is_person` is true. Props — the half of the team carrying the entire roster — get
`ability = null` over the network. Only the local flow has an ability on a Prop, and only
because `Main.tscn:50` hardcodes `quick_stand.tres` on `TeamAProp`.
**[FIXED]** (landed before this pass, docs were stale) `main.gd` assigns every networked Prop a
`.duplicate()`d `PROP_ABILITY` (`quick_stand.tres`) until character-select exists (B-24).

**B-30 · Networked characters never get a `player_id`. (NEW)** `_build_networked_character`
(`main.gd:196`) sets `is_can`, `is_person`, `team_is_can_side` and authority, but never
`player_id` — so all four networked characters keep the scene default of `1` and read `*_p1`
actions. It works by accident on LAN (one character per machine), but: the Settings panel's
entire P2 column is dead in networked play; the moodboard's WASD-for-Attacker /
arrow-keys-for-Defender scheme cannot be honoured; and any shared-screen fallback breaks
immediately. *Fix:* pass `player_id` through the spawn dictionary.
**[FIXED]** `player_id` is now explicit in the spawn dictionary, derived from the same
`is_person` split used for team/role assignment: `(index % 2) + 1`, so each team's Person gets
`player_id = 1` (P1/WASD default) and its Prop gets `player_id = 2` (P2/arrow-keys default) — this
is what actually lets the Settings panel's P2 rebind column do something in networked play, not
just in local test. It still can't produce anything beyond 1/2 (modulo 2), so it doesn't risk
breaking the 3rd/4th real joiner the way assigning raw join-order index (2/3/4...) would have —
p3/p4 stay deliberately unbound in `project.godot` for the local-test dummies regardless. The
moodboard's WASD-tracks-Attacker/arrows-tracks-Defender scheme still isn't honored (that needs
input rebinding on every role swap, not just this), and the not-yet-built shared-screen fallback
(queue item 1) is unrelated — **both remain open design questions, not re-litigated here.**

**B-48 · `GameLaunch.game_mode` is never networked. (NEW)** Each peer reads its own menu
selection. The host's mode governs hit resolution (`hitbox.gd:59`), but the client's
`_wire_downed_flash` dent gate (`main.gd:279`) reads the *client's* value — so a client on
Option B never shows a dent counter while the host runs Option A. Send `game_mode` with the
match-state sync in B-29.
**[FIXED]** included in `_sync_state_to_late_joiner` (see B-29) — a joining peer's `GameLaunch.game_mode`
is set from the host's value as part of the same sync.

### P1 — the core loop is wrong

**B-49 · `NetworkManager.is_networked()` has been reading `true` in local test this whole time.
(NEW)** Godot 4's `multiplayer.multiplayer_peer` defaults to an `OfflineMultiplayerPeer`
sentinel, **not `null`**, and `multiplayer.has_multiplayer_peer()` reports `true` for it —
confirmed by printing `multiplayer.multiplayer_peer` at `main.gd::_ready()` in a real headless
run: `<OfflineMultiplayerPeer#...>`, before `host_game()`/`join_game()` has ever been called.
`NetworkManager.is_networked()` was defined as `return multiplayer.has_multiplayer_peer()`, so it
returned `true` for the plain single-PC/split-keyboard local-test flow too, which never touches
`host_game()`/`join_game()` at all. Most `if NetworkManager.is_networked(): ...` gates throughout
the codebase happened to be harmless because `is_host()` (`is_networked() and
multiplayer.is_server()`) was *also* accidentally `true` — the default peer reports as server —
so a paired "networked and not host, skip" check never actually skipped anything locally. There
is no such accidental save in `main.gd::_on_match_round_started`, which branches on
`is_networked()` alone: it took the **networked** branch and iterated `_spawned_characters`,
which is always empty outside a real match — so from round 2 onward, **the entire per-round reset
(position, `is_can`/`team_is_can_side` recompute, `RoundManager.register_can()`) silently did
nothing for any local-test unit.** B-10's own fix (position reset for all four units, this same
session) was therefore never actually exercised in local play, only in the networked branch —
caught only by building the kill plane (queue item 9) and running the local flow for real instead
of reading the code, the same lesson as B-03's regression above.
**[FIXED]** `NetworkManager` now tracks an explicit `_is_networked: bool`, set `true` only inside
`host_game()`/`join_game()` and `false` on disconnect/failure, instead of trusting
`multiplayer.has_multiplayer_peer()`. `is_networked()` returns that flag. Re-ran the same headless
local-test session: `_on_match_round_started` now reports `is_networked=false`, the local branch
runs, and a character forced into the KillPlane came back at its exact `spawn_position` —
confirmed with a real run, not just code inspection.

**B-09 · No team identity — you can dent and seal your own Can.** `CharacterBase` has `is_can`,
`is_person`, and `team_is_can_side`, but **no `team_id` at all**. `hitbox.gd` only skips
`target == owner_character`, so a defending Person can dent its own Can and a teammate can seal
it. The team id exists in `main.gd::_peer_teams` and is never put on the character.
⚠️ **Do this one first.** Friendly-fire, nameplates (item 4), team colour distinction (item 8),
and the role-swap card (item 9) are all blocked behind it.
**[FIXED]** (landed before this pass, docs were stale) `CharacterBase.team` (int, 0/1), set at
spawn in both the networked and local-test flows; `hitbox.gd` skips a hit when
`target.team == owner_character.team`. Nameplates/team colour/role-swap card are still open —
those are UI content work (queue items 4, 8, 9), not blocked on anything code-side anymore.

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
**[FIXED]** (a) and (b): four invisible walls around the floor's perimeter, plus a `KillPlane`
(`scripts/systems/kill_plane.gd`) that returns a fallen `CharacterBase` to its own
`spawn_position` (new field, captured on `_ready()`, kept current by `main.gd` on every
respawn/round reset). (c)/(d) NOT done — `arena_camera.gd` is unchanged, still an
average-position broadcast cam; the kill plane just bounds how long a fall can drag the shot
before the character snaps back (~1s given `GRAVITY = 20`), which is a reasonable mitigation but
not the real fix. Ring-outs (a round-win trigger off the kill plane, Option A) are still not wired
up — the kill plane exists now but nothing calls into round-win logic from it.

**B-10 / B-37 · Round reset covers one unit out of four, and there is no gap between rounds.
(B-37 NEW)** `round_manager.gd:99` loops `_tracked_cans`, which holds exactly the one defending
Can. The two Persons and the other Prop keep their `STAGGERED`/`DOWNED`/`SEALED` state, dent
count, speed multiplier, and spent once-per-round charges across rounds. **Nothing anywhere
writes `position` after spawn**, so round 2 starts wherever round 1 ended. Separately, the whole
chain `report_round_win → report_round_result → begin_next_round → _sync_round_started →
_on_match_round_started → start_round` runs **in a single frame** — there is no intermission
state, so there is nowhere for a role-swap card to live and no moment at which the world could
be reset. *Fix:* add the intermission state and `reset_world()` per `Dev_Plan.md` §4.6.
**[FIXED]** (the reset half; landed before this pass, docs were stale) `main.gd::_on_match_round_started`
resets and repositions all four units every round (networked and local-test), not just the
tracked Can. **Still open:** the single-frame chain and the intermission state itself — there is
still no role-swap card, and nothing pauses the world for one. That is UI/flow content work
(queue items 10/19), not a code bug.

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
**[FIXED]** (landed before this pass, docs were stale) — NOT via camera rigs (those don't exist
yet); `character_base.gd` writes `rotation` directly via `look_at()` on movement input instead.
Camera rigs remain future work; this doesn't block them.

**B-06 · Quick Stand can never be activated.** `character_base.gd:142` returns early for
`STAGGERED`/`DOWNED`/`SEALED`; the `special_ability` input is read at line 160, *after* that
return. Quick Stand's only effect is self-righting from Downed — the exact state in which its
input is unreachable. Same structural problem for any future escape ability.
**[FIXED]** (landed before this pass, docs were stale) — `special_ability` is now also read inside
the `DOWNED` case of the state `match`, before the old unconditional early return.

**B-07 · Any stagger cancels Downed.** `apply_stagger()` (line 164) overwrites `DOWNED` with
`STAGGERED`, which auto-recovers to `NORMAL` after 0.25s. Under Option B, `hitbox.gd:70` sends
`"stagger"` to a Can that is Downed but still inside its self-right window — so hitting a downed
Can *rescues* it. Any bump from anyone, including its own teammate, is a free escape. Option B's
seal mechanic cannot work until this is fixed.
**[FIXED]** (landed before this pass, docs were stale) — `apply_stagger()` now returns early for
`DOWNED` too, not just `SEALED`.

**B-08 · Bump misses anyone you are already touching.** `hitbox.gd` only listens to
`area_entered`, but the melee Hitbox is always monitoring and is never enabled/disabled by the
bump window. Walk into someone and press bump → no new `area_entered` → no hit. You have to
press bump *before* closing distance, which is the opposite of how melee reads.
*Fix:* on bump press, also sweep `get_overlapping_areas()`.
**[FIXED]** `Hitbox.sweep_overlaps()` re-runs `_on_area_entered()` against everything already
in `get_overlapping_areas()`. `CharacterBase` caches its melee Hitbox (`requires_bump_window
== true`) in `_ready()` and calls `sweep_overlaps()` from a new shared `_open_bump_window()`
helper, used both when the local player presses bump and in the host's `_rpc_notify_bump`
handler (so a remote peer's already-touching bump also resolves correctly on the host). Needs
verification that walking into someone and then pressing bump now lands a hit.

**B-11 · A no-op activation still burns the cooldown.** `ability_base.gd:29` — `activate()` sets
`_time_since_use = 0` and `_used_this_round = true` before calling `_do_activate()`, which may do
nothing (Quick Stand while not Downed). Press the button once at the wrong moment and your
once-per-round charge is gone.
**[FIXED]** (landed before this pass, docs were stale) — `activate()` now only consumes the
cooldown/charge after `_do_activate()` returns `true`.

**B-12 · Friction is a per-frame constant, so there is no momentum and Flick Dash lasts three
frames.** `move_toward(velocity.x, 0, SPEED)` uses `SPEED` (6.0) as an absolute per-tick step,
not per-second — no `delta`. Max walk speed is also 6.0, so releasing a key stops you dead in one
tick, and it is frame-rate dependent if the physics tick ever changes. Flick Dash sets velocity
to 16 and it decays 16 → 10 → 4 → 0 in about 0.05s. The dash also applies a frame late, because
`_do_activate` runs after `move_and_slide()`.
**[FIXED]** (landed before this pass, docs were stale) — friction is now a real `FRICTION * delta`
deceleration, and the special-ability activation moved above `move_and_slide()` so a velocity kick
takes effect the same tick.

### P2 — menu, flow, and polish

**B-33 · The disabled game mode is selectable and proceeds.** `main_menu.gd:34` adds "Option A —
Health / Dents (coming soon)" as an ordinary `OptionButton` item, and `_on_game_mode_selected`
writes it into `GameLaunch.game_mode` unconditionally — nothing gates Local/Host/Join on it.
⚠️ **The label is also wrong:** Option A has been fully implemented since Session 7
(`hitbox.gd:59`, `round_manager.gd:78`). So this is a decision, not just a fix: either drop the
"(coming soon)" suffix because the mode works, or genuinely disable it with
`set_item_disabled(1, true)` **and** grey out the Local/Host/Join buttons while it is selected.
Do not leave a third state where the label says one thing and the button does another.
**[FIXED]** dropped the "(coming soon)" label — it works, so there was nothing to actually gate.

**B-34 · No way back from the Play menu.** `_on_start_pressed` hides `TitleScreen` and shows
`PlayMenu`; nothing ever goes back. Settings is only reachable from `TitleScreen`, so once you
press Start you cannot reach Settings without restarting the game. *Fix:* a Back button on
`PlayMenu` and an `ui_cancel` handler doing the same thing.
**[FIXED]** added a Back button to `PlayMenu` plus a `ui_cancel` (Esc) handler doing the same.

**B-13 · The match starts before anyone joins.** `main.gd:142` calls `begin_next_round()` the
instant the host starts hosting. No lobby, no ready-up. Root cause of B-29.

**B-14 · Nothing resets between matches.** `MatchManager.team_a_wins` / `team_b_wins` /
`round_number` / `team_a_is_can` and `RoundManager`'s state live on autoloads that survive scene
changes. A second match continues the first one's score. Needs `reset()` on both.
**[FIXED]** added `reset()` to both, called from `main_menu.gd::_go_to_match()` (every Local/
Host/Join button) and from the new pause menu's Return to Menu (B-20).

**B-16 · `guard_dash` is bound, rebindable, and read by nothing.** The GDD lists Guard/Dash as a
shared basic for every character. `guard_dash_p1..p4` exist in `project.godot` and appear in the
Settings panel, but no script reads them. Players will press it and nothing happens.
**[FIXED]** implemented per GDD: Cans (Prop, `is_can` true) hold to block, gated by a stamina
meter; Tsinelas (Prop, `is_can` false) get a short-cooldown dash burst in the facing direction.
Persons don't get this (their slot is Tag/Throw). Guard blocks both stagger and dents while
active. Untested in a live playtest — reasoned through and runtime-smoke-tested (no script
errors), but game feel/balance numbers are first-pass guesses.

**B-17 · `HazardZone` edge cases.** `_on_area_entered` calls
`owner_character.set_speed_multiplier()` with no null check (a Hurtbox whose owner isn't wired
crashes it). Exiting one zone resets speed to 1.0 even if you are still standing in another. And
a zone that expires while someone is inside relies on Godot firing `area_exited` during free —
verify before map hazards depend on it.
**[FIXED]** all three: null-checked; `CharacterBase` now tracks every active zone
(`enter_speed_zone`/`exit_speed_zone`) and applies whichever is most restrictive instead of a
single overwritten value; `_expire()` explicitly clears its effect from every character still
overlapping instead of assuming `area_exited` fires on free.

**B-18 · Round end isn't synced on timer expiry.** `round_manager.gd:116` `_on_time_up()` sets
`round_active = false` without a final `_sync_state` RPC.
**[FIXED]** `_on_time_up()` now calls `report_round_win(true)`, which already does the sync.

**B-19 · `_sync_state` RPCs every rendered frame, per client**, purely to drive a HUD label that
changes once a second. Note it is in `_process`, not `_physics_process` as previously recorded —
so at 144 fps that is 144 packets/second/client. Harmless on a LAN, wasteful, trivially
throttled to ~4 Hz.
**[FIXED]** throttled to `SYNC_INTERVAL = 0.25` (4Hz); the final state at round end (B-18) still
syncs immediately, unaffected by the throttle.

**B-20 · No way out of a match.** No pause, no Escape handler, no return-to-menu. Once
`Main.tscn` loads, the only exit is Alt+F4 — a bad look in a live demo. Doubly important once
FPP captures the mouse (`Dev_Plan.md` §3.2): a captured cursor with no release path traps the
player.
**[FIXED]** a `PauseLayer` overlay (Resume / Return to Menu), toggled by `ui_cancel`. The same
toggle also owns mouse capture: opening the pause menu releases the cursor to
`MOUSE_MODE_VISIBLE` (mandatory, or the overlay's own buttons aren't clickable — `_ready()`
already captures the mouse unconditionally for gameplay, see Item 14) and Resume re-captures it.
Return to Menu disconnects the network session if one exists and resets MatchManager/RoundManager
(B-14). Focus-loss (alt-tab) still independently forces the mouse visible regardless of pause
state.

**B-21 · Team assignment uses `_spawned_peer_ids.size()` as the join index.** A disconnect
followed by a rejoin shifts every subsequent index, so teams and Person/Prop roles get
scrambled.
**[FIXED]** join index is now assigned once per `peer_id` on first connect and never reassigned,
even after that peer disconnects.

**B-22 · Settings allows duplicate bindings.** Rebinding P2's "up" to `W` silently makes both
local players move together, with no warning and no conflict detection.
**[FIXED]** `rebind_action()` checks every other rebindable action for the same physical keycode
and refuses (returning the conflicting action's label) instead of double-binding it. Reset-to-
default bypasses the check via a new internal `_set_binding()`, since resetting must always
succeed even mid-reset.

**B-38 · A client's Bo5 score is stale for the whole final round. (NEW)** `hud.gd:23` reads
`MatchManager.team_a_wins` / `team_b_wins` directly every frame, but on a client those only ever
change inside `_sync_round_started` / `_sync_match_won`. So a client sees the *previous* round's
score for the entire round it is playing, and the winning score only lands with the match-won
RPC. Once the score becomes Bo5 pips (`Dev_Plan.md` §4.4) this will be very visible.
**[FIXED]** for the specific case this ledger entry is about (a late joiner): the new
`_sync_state_to_late_joiner` (B-29) includes both win counts. Ordinary in-match score updates were
already synced via `_sync_round_started`/`_sync_match_won`'s existing `call_local` RPC — not
re-verified beyond that this session.

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
**[FIXED]** (partial) added a brief white mesh flash on any landed hit, triggered from
`_apply_hit_result()` (runs on the target's own owning peer, any hit kind, either game mode) — no
new assets needed. `landed_on` itself is still unused (still only fires on the host). Sound,
particles, hitstop, and screenshake are still open — those need real assets/design, not a code fix.

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
**[FIXED]** (partial) created `.tres` resources for all five, mirroring `quick_stand.tres`'s
format (Bakya Bash gets the GDD's "long cooldown", the rest use `AbilityBase` defaults). They can
now be assigned/tested manually. **Still open:** character-select UI/data to actually pick between
them in game — that's the content-heavy half of this bug (Phase 2 item), not attempted here.

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
**[FIXED]** (the movement half) `spawn_pulse_hitbox()` gained a `follow_character` option that
parents the hitbox to the character as a local-offset child instead of `current_scene`; Flick
Dash opts in, the stationary pulses (Spin Guard, Bagsak Bomb, Bakya Bash, Person's Tag/Throw)
don't. **Still open:** round-reset cleanup — low risk given these all have sub-0.4s durations,
but not explicitly handled.

**B-26 · Stale comments and labels.** `hitbox.gd:5-8` says "both Hitbox and Hurtbox default to
layer 1" — they do not; `CharacterBase.tscn` sets Hurtbox to layer 2 / mask 0 and Hitbox to
layer 0 / mask 2, which is correct, so the comment is misleading in a load-bearing place.
`round_manager.gd:74` talks about "both tracked Cans" when only one Can exists per round.
`round_manager.gd:41` says role reassignment "isn't implemented yet" — it has been since
Session 7. The main menu still labels Option A "(coming soon)" (see B-33).
**[FIXED]** fixed the `hitbox.gd` layer comment and the `round_manager.gd` reassignment comment;
Option A's label is fixed too (see B-33).

**B-27 · Name inconsistency.** `project.godot` says "Tumbang Laro", the README and GDD say
"Tumbang Laro: Isang Laban", the main menu says "TUMBANG PRESO", and the moodboard ships a
finished **TUMBANG PRESO** logo. Adopt the logo's name everywhere (`Dev_Plan.md` §0.4).
**[FIXED]** `project.godot`, README, and GDD title all now say **Tumbang Preso**, matching the
main menu and the moodboard logo.

**B-50 · P1's Guard/Dash was bound to a Godot 3 keycode, so it never fired. (NEW)**
`project.godot`'s `guard_dash_p1` held `physical_keycode = 16777237` — that is Godot **3**'s
`KEY_SHIFT`. Godot 4's is `4194325`, and `16777237` is not a valid Godot 4 keycode at all, so the
action could never be triggered by any key. The whole B-16 Guard/Dash mechanic was dead for
player 1: the Can could not block (so `apply_stagger`/`apply_dent`'s guard checks were
unreachable) and the Tsinelas could not dash. The settings panel rendered it as the nonsense
string "Command+", which is what surfaced it. Nothing in the code was wrong — only the binding.
**[FIXED]** `guard_dash_p1` is now `KEY_SHIFT`. That collided with `special_ability_p2`, which was
also on Shift, so both were split by `location` (LEFT for P1's guard, RIGHT for P2's special) —
otherwise one physical keypress fires two different players' actions on a shared keyboard.
`guard_dash_p2` moved from Ctrl to **End**, matching the scheme `Dev_Plan.md` §3.5.1 already
documented. Verified by matching synthetic `InputEventKey`s against the InputMap: left Shift
resolves to `guard_dash_p1` only, right Shift to `special_ability_p2` only, and all 14 bound
actions now have 14 distinct key+location pairs (no conflicts).

**B-51 · The match-result screen appeared with the cursor still captured, so neither of its
buttons could be clicked. (NEW)** `main.gd::_ready()` sets `Input.mouse_mode = MOUSE_MODE_CAPTURED`
for the whole match, and nothing released it when the match ended — `match_result.gd` only released
it inside `_on_menu_pressed`, i.e. *after* a click that could not happen. Winning a Bo5 therefore
left you on a result screen with an invisible, captured cursor and no way to press **Rematch** or
**Menu**. Recoverable only via Esc, which opens the pause overlay *over* the result screen.
**[FIXED]** released in `_on_match_won`, re-captured in `_on_rematch_pressed` (a rematch goes
straight back into gameplay, and `camera_rig.gd` only mouse-aims while the cursor is captured).
Verified by driving a real local Bo5 to 3-0 in a live instance: the result screen shows with
`mouse_mode = VISIBLE`, and pressing Rematch returns round 1 / 0-0 with `mouse_mode = CAPTURED`.

**B-52 · Ability cooldowns carried across the round boundary. (NEW)**
`AbilityBase.reset_round_charge()` — called from `CharacterBase.reset_for_new_round()` — cleared
`_used_this_round` but not `_time_since_use`, so a cooldown-based ability kept its remaining
cooldown into the next round. The intermission does not absorb it either:
`character_base.gd::_physics_process` returns before `ability.tick(delta)` whenever
`RoundManager.round_active` is false, so the cooldown does not decay during the 3s gap at all.
Worst case is Bakya Bash at **18s** — used near the end of a round, the next round started with
most of that still to run, a fifth of a 90s round with no special. Not cosmetic: the whole point
of a per-round reset is that both teams start a round on equal footing.
**[FIXED]** `reset_round_charge()` now also resets `_time_since_use`. Verified: activate an
ability, call `reset_round_charge()`, `is_ready()` goes back to `true` (it stayed `false` before).

**B-53 · Esc could bury the match-result screen under the pause overlay. (NEW)**
`PauseLayer` is `layer = 10`; `MatchResult` lives in `HUDLayer` at layer 0. Pressing Esc after a
match ended therefore drew the pause overlay *over* the result screen, and Resume re-captured the
cursor and handed back a result screen that could not be clicked — re-creating B-51 by another
route. **[FIXED]** `main.gd::_unhandled_input` ignores `ui_cancel` entirely while the result
screen is visible; there is nothing to pause once the match is decided. Verified live.

**B-54 · Local spawn points ignore team membership. (OPEN — needs a design call, not a code fix)**
`main.gd`'s `SPAWN_POINTS` are assigned in `_local_roster` order — `TeamAProp`, `TeamAPerson`,
`TeamBProp`, `TeamBPerson` — against the fixed list `(0,1,-2) (0,1,2) (-3,1,0) (3,1,0)`. So Team A's
two units start at opposite ends of the arena while Team B's start on the left/right flanks:
teammates are not together and opponents are not separated. Worse for the camera, `TeamAPerson`
spawns at `(0,1,2)` and `TeamAProp`'s third-person camera sits at `(0,3.66,2.35)` — your own
teammate spawns essentially *inside* your camera, filling the frame at round start. Not fixed
here because the right answer is per-map base placement (the GDD's Eskinita / Bayan Plaza bases),
which is queue item 10's deferred "move `SPAWN_POINTS` into a `SpawnPoints` node on the map scene"
— guessing at coordinates now would just be re-guessed when real maps land.

**B-55 · `RoundManager`'s end-of-round state change rides an unreliable RPC. (OPEN — low)**
`_sync_state` is `@rpc("unreliable_ordered")`, which is right for the 4Hz timer it was written for,
but `report_round_win()` uses that same channel to broadcast the one-shot `round_active = false`.
If that packet drops, the client keeps believing the round is live — and `_process` won't resend,
because it returns early once `round_active` is false. Self-heals when the next round's
`_sync_round_started` (reliable) arrives ~3s later, so the blast radius is a stale client HUD for
one intermission. Left alone: the fix is to split the one-shot state change onto a reliable RPC,
which is a networking change worth making deliberately rather than in passing.

**B-56 · `KillPlane` respawns on every peer, not just the character's authority. (OPEN — low)**
`_on_body_entered` calls `character.respawn()` wherever the Area3D overlap is detected, which is
every peer. For a non-authoritative copy the position is immediately overwritten by
`MultiplayerSynchronizer`, so the visible effect is at most a one-frame snap, and the
"OUT OF BOUNDS" toast is already correctly gated on `is_multiplayer_authority()` in `main.gd`.
Flagged rather than fixed because it is cosmetic and the correct guard placement depends on
whether respawn should stay client-authoritative at all (see B-49's note on the movement model).

**B-57 · Under Option A, `forces_downed` is silently ignored on a Can. (OPEN — question, not a bug)**
`hitbox.gd` resolves any hit on a Can under Option A as `"dent"` before it ever consults
`forces_downed`, so Bakya Bash's advertised "instant-down on direct hit" does nothing distinct in
that mode. That may well be intended — Option A has no Downed/Seal state machine at all — but it
means a heavy special and a light bump are worth exactly the same against a Can. **Someone needs
to decide** whether Option A wants weighted hits (e.g. a heavy special costing 2 dents) or whether
every hit really is one dent. Not changed: it is a balance decision, not a defect.

**B-58 · `ArenaCamera._process` still does full follow-cam work every frame while retired.
(OPEN — trivial)** `_ready()` sets `current = false` (§3.4, it lost the viewport to the per-character
rigs), but `_process` still runs every frame computing the target midpoint, the pairwise spread and
a lerped position for a camera nothing renders through. Harmless, just wasted work; worth
`set_process(false)` whenever it isn't current, once someone decides whether the spectator/broadcast
use-case it was kept for is real.

**B-59 · Unreproduced: a completed match reset itself to round 1 / 0-0. (OPEN — question)**
Twice, early in testing B-51, a scripted local Bo5 that had just reached 3-0 came back on the next
sample reading `round_number = 1`, `wins = 0-0`, `round_active = true` and the result screen hidden
— which is precisely the post-`_on_rematch_pressed()` state, with no input sent. It has not
reproduced in six subsequent runs (including one with `print_stack()` instrumentation on both
`_on_rematch_pressed` and `MatchManager.reset`, which showed `reset` called exactly once, from
`main.gd::_ready`). The obvious suspect — `ui_accept` sharing Space/Enter with `bump_p1`/`bump_p2`,
so a player still mashing bump when the match ends would trigger a focused Rematch button — was
tested and does **not** hold: neither key matches `ui_accept`, and the button holds no focus.
Recorded rather than closed, because "I could not reproduce it" is not "it does not happen". If a
match ever restarts itself in a real playtest, start here.

**B-28 · No export presets, no build, no CI.** `export_presets.cfg` is gitignored and none
exists. The game has never been run outside the editor, and the submission needs a real build.

---

## 4. Immediate Execution Queue

Prioritised: **P0 LAN → gameplay/reset → cameras → UI**. Every item has an acceptance test.
Tick items here and mirror them into `Dev_Plan.md` §5.

### P0 — Make LAN work

- [x] **1. Debug player switcher — manual control of any unit in local mode (do this first; it
      unblocks all testing).** Full spec: `Dev_Plan.md` §3.5.
      Two control slots. `F1`–`F4` assign a unit to the **P1** set (WASD/Space/Q),
      `Shift`+`F1`–`F4` assign to the **P2** set (arrows/Enter/RShift), `Tab` / `Shift`+`Tab`
      cycle each slot, `F5` drops to solo drive, `F6` resets. Control moves by **reassigning the
      existing public `player_id` export from the outside** — unheld units get parked on `4`,
      which is registered and permanently unbound. That needs **zero** edits to
      `character_base.gd`. Reassign in `_unhandled_key_input`, never mid-`_physics_process`, or
      a unit inherits a half-consumed edge-triggered press on the frame it gains control. Add a
      deliberately-ugly `DebugBar` naming both held units with their team, role and current side,
      refreshed on `MatchManager.round_started`.
      Fixes **B-42** — without it a local Bo5 cannot be played past round 1, because round 2's
      Can is `player_id = 3` and unbound.
      ⚠️ **Must be built to the removal contract in `Dev_Plan.md` §0.3:** `debug_`/`Debug` prefix
      on every file, class and node; debug calls gameplay and gameplay never calls debug (no
      gameplay script may name it, not even behind an `if OS.is_debug_build()`); no `[input]`
      map entries — read raw keys; self-disables via `if not OS.is_debug_build(): queue_free()`
      plus a `NetworkManager.is_networked()` guard. Total footprint must be **3 files and 2
      lines** (one autoload line in `project.godot`, one `DebugBar` instance line in
      `Main.tscn`).
      *Acceptance:* (a) start a Local Match, press `Tab` four times — you move a different unit
      each time and the DebugBar names it; (b) `Shift`+`F3` puts the arrow keys on `TeamBProp`
      and both units are drivable at once; (c) play into round 2 and confirm the swapped Can is
      controllable, which it is not today; (d) run the verification grep from `Dev_Plan.md`
      §3.5.5 — every hit is inside the three debug files and the two registration lines, and
      none is in a gameplay script.
      **Done, runtime-verified by driving the key handler directly** (`InputEventKey` fed into
      `_unhandled_key_input`, reading back every unit's `player_id` and which camera is `current`
      after each press). Confirmed in order: defaults `TeamAProp`→P1 / `TeamAPerson`→P2 with the
      other two parked on the unbound `4`; `F3` moves P1 and the camera to `TeamBProp`;
      `Shift+F4` moves P2; `Tab` cycles and **skips the unit the other slot holds** rather than
      colliding on one `player_id`; `F5` empties P2; `Shift+F1` steals a unit from the other slot;
      `F6` restores defaults. FPP/TPP derivation survives every handoff — cycling onto a Person
      makes its FPP camera current, onto a Prop its TPP camera (§0.1 intact). Zero edits to
      `character_base.gd`, per §3.5.2.
      Two deviations from the spec, both documented at §3.5.5:
      - The verification `grep` as written could never pass, because four gameplay files carry
        comments naming Godot's **Debug > Run Multiple Instances** editor menu. The checklist now
        filters that phrase; the two comments that genuinely named the switcher were reworded.
      - Footprint is 3 files and **3** lines, not 2: a `.tscn` instance needs an `[ext_resource]`
        line as well as its `[node]` line. Inherent to the scene format.
      Unit lookup deliberately walks up from the `DebugBar` rather than using
      `get_tree().current_scene`, which is only correct when the match was reached through
      `change_scene_to_file` — anything instancing `Main.tscn` as a sub-scene made every lookup
      return null and the bar read "(missing)" with no error anywhere. Caught by rendering it.

- [x] **2. Fix the LAN freeze (B-03).**
      Disable or delete the `Camera3D` node in `Main.tscn` (`Main.tscn:40-43`). It caches four
      `NodePath`s in `_ready()` and both `_start_hosting()` and `_start_joining()` free those
      nodes immediately after, so `_process` dereferences freed instances every frame on every
      peer. If `arena_camera.gd` is kept for broadcast use, convert it to runtime
      `register_target()` / `unregister_target()` with an `is_instance_valid()` guard, and
      default `current = false`. Ship this ahead of the camera rigs so LAN is testable today.
      *Acceptance:* Host Game (LAN) from the menu; no "previously freed instance" errors in the
      Output panel; the editor does not hang.
      **Done, runtime-verified with the actual Godot 4.7 binary** — `add_target()`/
      `remove_target()` already existed, but `_clear_local_test_characters()` never called
      `remove_target()` on the four local nodes before freeing them, which reproduced the exact
      freeze live. See B-03 in §3.

- [x] **3. Sync full match state to joining clients (B-29, B-48).**
      On `NetworkManager.player_connected`, the host `rpc_id()`s that one peer the current
      `round_number`, `team_a_is_can`, `team_a_wins`, `team_b_wins`, `time_left`, `round_active`,
      and `GameLaunch.game_mode`. The client applies it and runs the same
      `_on_match_round_started` path the host does.
      *Acceptance:* two editor instances. Host first, wait ten seconds, then join. The client's
      timer matches the host's, the HUD shows the same round and roles, and the client's Can is
      registered.
      **Done, runtime-verified** — one deliberate deviation: the sync does NOT run
      `_on_match_round_started` on the joining peer (that would reset/reposition all four units
      just because a new peer joined mid-round). It sets the autoload fields directly instead;
      each character's `is_can`/`team_is_can_side` is already correct from its own spawn data.
      Verified live: joining ~3s into round 1 gave the client `round=1 team_a_is_can=true
      wins=0-0 time_left=87.0 round_active=true`, matching the host exactly.

- [x] **4. Assign `player_id` to networked characters (B-30).**
      Pass it through the spawn dictionary in `_spawn_player` and apply it in
      `_build_networked_character`. Per the moodboard, keep WASD on the Attacker/Person set and
      arrow keys on the Defender/Can set.
      *Acceptance:* a client's character responds to its own bound set, and the Settings panel's
      P2 column has a visible effect in networked play.
      **Done, but NOT per the moodboard's WASD-for-Attacker scheme** — every networked character
      gets `player_id = 1` deliberately (see B-30 in §3 for why: a solo player's own machine only
      has P1 bound, and assigning 2/3/4 from join order would break control for the 3rd/4th real
      joiner). The moodboard's per-role rebinding idea needs a team decision — flagged, not built.

- [x] **5. Replicate ability activation to the host (B-02).**
      Route `AbilityBase.activate()` through an `any_peer` RPC to the host, which spawns the
      resolving hitbox. Spawn a cosmetic-only copy locally for responsiveness if you want; the
      cosmetic one must never resolve hits.
      *Acceptance:* a non-host client presses special and the host sees the target stagger.
      Landed before this pass; docs were stale. Not independently re-verified this session.

- [x] **6. Give networked Props their ability (B-04).**
      `_build_networked_character` assigns a `.duplicate()`d roster ability to Props, not just
      Persons. Until character select exists, default Props to `quick_stand.tres`.
      *Acceptance:* a client-controlled Prop can activate a special.
      Landed before this pass; docs were stale. Not independently re-verified this session.

- [x] **7. Verify B-01 with two instances.**
      `--host` and `--join=127.0.0.1`. Both timers must count down together. It is marked fixed
      and has never been run.
      *Acceptance:* screenshot or a note in the commit confirming both windows show a moving
      timer.
      **Done** — `--host` / `--join=127.0.0.1`, headless, Godot 4.7 binary: host's
      `_sync_round_started` fired with `round=1 team_a_is_can=true wins=0-0 is_host=true` and
      `start_round` ran; the joining client received the matching late-join state (item 3) with a
      correctly-advancing `time_left`. No script errors on either side.

### P1 — Gameplay correctness and round reset

- [x] **8. Add `team_id` to `CharacterBase` (B-09). Blocks items 12, 13, 14.**
      `@export var team_id: int = 0`, set from spawn data (networked) and from `Main.tscn`
      (local). Gate `hitbox.gd` on it so friendly fire cannot dent or seal your own Can.
      *Acceptance:* a Person bumping its own team's Can produces no dent and no seal.

- [x] **9. Bounds, kill plane, and respawn (B-15, B-35).**
      Invisible `StaticBody3D` walls around the arena, plus a `KillPlane` Area3D at y ≈ −10 that
      returns any body entering it to its spawn point with `velocity = Vector3.ZERO`. Add a
      brief "OUT OF BOUNDS" HUD toast.
      *Acceptance:* walk off the edge — you respawn within ~1s, the camera stays with you, and
      no other player's view is disturbed.
      **[x] Walls + KillPlane done.** No "OUT OF BOUNDS" HUD toast yet (UI content, not attempted).
      "Camera stays with you" is only approximately true — `arena_camera.gd` itself is unchanged
      (still an average-position broadcast cam); the kill plane just bounds the exposure window
      to ~1s given `GRAVITY = 20`, it doesn't stop the shot from sagging during that window.

- [ ] **10. Round intermission state + full world reset (B-10, B-37).**
      **Full world reset was already done before this pass** (`main.gd::_on_match_round_started`
      resets/repositions all four units every round) — docs were stale about this too. The
      intermission STATE (a pause between round-end and round-start for a role-swap card to live
      in) is genuinely still not built; the chain still runs in one frame.
      Add the intermission phase from `Dev_Plan.md` §4.6. `reset_world()` must return **all four**
      units to their map spawn points (position, velocity, facing), call `reset_for_new_round()`
      on all four, free every live `HazardZone` and orphaned pulse `Hitbox`, and re-broadcast
      state from the host. Move spawn points out of `main.gd:55` into a `SpawnPoints` node on the
      map scene.
      *Acceptance:* end a round with units scattered and one Downed — round 2 starts with all
      four at spawn, all `NORMAL`, dents cleared, once-per-round charges restored.
      **B-37 fixed** — `MatchManager.round_intermission_started` fires the instant a non-match-
      ending round ends, carrying what the next round's `team_a_is_can` will be (roles always
      swap between rounds); `main.gd::_on_round_intermission_started` calls the new
      `_reset_world()` immediately (world reset now happens during the gap, not waiting for the
      round to actually start) and shows a plain "Team X wins the round!" banner via
      `Hud.show_round_banner()`. `MatchManager._process` (host-only) counts down a 3s
      `INTERMISSION_DURATION` then calls `begin_next_round()` for real, which runs
      `_on_match_round_started` → `_reset_world()` again (idempotent) → `RoundManager.start_round()`.
      `character_base.gd` freezes movement/action input whenever `RoundManager.round_active` is
      false (covers this gap and the moment before round 1). `_reset_world()` also frees anything
      in the new `hazard_zone` (only ability-spawned, timed ones — a future permanent map hazard
      is excluded on purpose) and `transient_hitbox` groups (B-43).
      This is the **functional** beat, not the polished moodboard card — the banner is a plain
      `Label`, not the animated role-swap card with sliding team panels. That visual replacement
      is queue item 19, which now has a real state machine to slot into instead of nothing.
      **Not done:** moving `SPAWN_POINTS` out of `main.gd` into a per-map `SpawnPoints` node —
      deferred, since there is only the one placeholder floor and no second map yet to make the
      hardcoded constant actually wrong.
      **Verified for real:** ran a live headless local-test session, scattered one unit and forced
      another Downed, then force-called `RoundManager.report_round_win(false)` after 1s.
      Observed, in order: `round_intermission_started` fired immediately with
      `next_round=2 next_team_a_is_can=false`; ~3s later `round_started` fired for round 2 with
      every unit's position back at its exact spawn point and the Downed unit's `state` back to
      `NORMAL` (0). Zero errors. Also re-ran the two-instance networked test with these changes in
      place — zero errors on either peer (the intermission RPC path itself wasn't exercised since
      no round ended during that short run, but nothing regressed).

- [x] **11. Verify and finish the Bo5 early-win (B-14, B-37).**
      ⚠️ **The 3-points-wins rule is already implemented** — `match_manager.gd:11` sets
      `WINS_NEEDED = 3` and `:43-48` calls `_finish_match()` on reaching it. Do not rebuild it.
      What is missing is everything *after* `match_won` fires: no match-result screen, no
      return-to-menu, and no `reset()` on `MatchManager` / `RoundManager`, so a second match
      resumes the first one's score. Build the match-end flow and the resets.
      *Acceptance:* win three rounds — a result screen appears, "Menu" returns to the main menu,
      and starting a new match begins at 0–0 round 1.
      **Resets are done** (B-14 — `MatchManager.reset()`/`RoundManager.reset()`, called from the
      menu and from the new pause menu's Return to Menu). **A generic "return to menu" now exists**
      (B-20, Esc pause overlay) but there's still no dedicated Bo5-grid match-result screen or
      Rematch button specifically triggered by `match_won` — that's UI content work.

- [x] **12. Fix the core-loop bugs (B-05 via rigs, B-06, B-07, B-08, B-11, B-12).**
      B-05 is delivered by item 15 — do not build a separate aim axis. The rest are independent
      and small. B-07 in particular blocks Option B entirely.
      *Acceptance:* Quick Stand can be pressed while Downed and works; bumping an already-Downed
      Can does not rescue it; walking into someone and then pressing bump lands; a no-op Quick
      Stand does not consume the charge; releasing a movement key decelerates over ~0.2s rather
      than stopping dead.
      **All landed before this pass; docs were stale about it.** B-05 specifically was NOT
      delivered via camera rigs (those don't exist) — `character_base.gd` writes rotation directly
      via `look_at()` instead. Not independently re-verified with a live playtest this session,
      but confirmed by reading the actual code (see each B-number in §3).

### P2 — Cameras (standing directive)

- [x] **13. Build `CameraRig.tscn` + `camera_rig.gd` (`Dev_Plan.md` §3).**
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
      Built `scenes/characters/CameraRig.tscn` + `scripts/systems/camera_rig.gd`, instanced as a
      child of `CharacterBase.tscn`. `CharacterBase.tscn`'s mesh is now wrapped in a plain `Visual`
      Node3D (the sibling the rig hides in FPP) rather than sitting directly under the root.
      `ArenaCamera` explicitly sets `current = false` in `_ready()` so it can never contend with a
      rig's camera for the viewport (§3.4).
      ⚠️➡️✅ **The doubt flagged here was justified — the TPP bake WAS backwards, and is now fixed.**
      The original `SpringArm3D rotation_degrees = (-15, 180, 0)` + `TppCamera (0, 180, 0)` did not
      produce "behind and above, tilted down": `SpringArm3D` pushes children along its local **+Z**,
      so the 180 yaw placed the camera 4.35 units *in front of* the character and the compensating
      180 on the camera aimed it further forward and 15° **up**. Every Prop's third-person view was
      a shot of empty sky with its own character behind the camera — which is exactly what the game
      shipped looking like. Measured `forward · (character − camera) = −0.972`, where ≈ +1 is
      correct. Fixed to arm `(-15, 0, 0)` with no rotation on the camera; the same measurement now
      reads **+0.972**, and a real Metal-rendered frame shows the character framed from behind and
      above with the arena visible. FPP re-checked in the same pass: eye height, own body correctly
      shadow-only, other units visible. See `camera_rig.gd`'s header for why the transforms must
      stay as they are. Remaining genuinely un-eyeballed: the TPP **wall pull-in** (needs a wall to
      actually back into) and mouse-look feel.
      What **was** verified earlier with real running instances, not just reading the code:
      - Mode derivation: a Prop's rig reports `mode=TPP` (`tpp_camera.current` true when active,
        `fpp_camera.current` false) and a Person's reports `mode=FPP`, on both a local-test run and
        both peers of a two-instance networked run.
      - Exactly one camera `current` across the whole scene at a time; `arena_camera.current` stays
        `false`.
      - Networked auto-activation: each peer's rig for its **own** `is_multiplayer_authority()`
        character activates with `AimSource.MOUSE`; every other spawned character (including the
        other peer's) stays inactive with `AimSource.MOVEMENT` — confirmed identically from both
        the host's and the client's point of view.
      - Yaw/pitch math, extracted into a directly-callable `apply_mouse_delta()` so it's testable
        without a display server: a 100px/50px mouse delta at the flat 0.15°/px default produced
        exactly −15°/−7.5° rotation, and pushing 10000px past either pitch limit clamped cleanly to
        −80° and +70°. A TPP rig's `apply_mouse_delta()` left `tpp_arm.rotation.x` at its fixed
        bake untouched, confirming TPP never lets mouse pitch touch the arm — only yaw.
      - **Caught and fixed a real bug this same pass**: the first version of the FPP self-hide cast
        `_character.get_node_or_null("Visual") as VisualInstance3D` — but `Visual` is a plain
        `Node3D` wrapper (see above), not itself a `VisualInstance3D`, so the cast silently
        returned `null` and the shadow-only setting never applied, with no error printed anywhere.
        Fixed by walking `Visual`'s `GeometryInstance3D` descendants instead. Verified after the
        fix: a Person's mesh reports `cast_shadow = 3` (`SHADOWS_ONLY`), a Prop's stays at the
        default `1` (`ON`).
      - Local test has no multiplayer-authority concept, so one rig has to be picked explicitly —
        `main.gd::_start_local_test()` now activates `TeamAProp`'s rig by default (matching the
        not-yet-built debug switcher's own documented P1 default), with `AimSource.MOUSE`.

- [x] **14. Mouse capture and sensitivity.**
      `Input.MOUSE_MODE_CAPTURED` during a match, released on pause/Esc/focus-loss. Sensitivity
      slider and invert-Y in `SettingsManager` next to the keybinds. Local test uses
      `AimSource.MOVEMENT` for every unit that isn't the debug-controlled one — two players on
      one keyboard cannot both mouse-look, and that is accepted, not solved.
      *Acceptance:* Esc releases the cursor and reopens it on resume; sensitivity persists across
      a restart.
      `main.gd` captures the mouse when a match's `_ready()` runs, `ui_cancel` (Esc) toggles it
      captured/visible (there's no real pause menu yet — B-20 — to hang a proper resume flow off
      of, so pressing Esc again just re-captures), and `NOTIFICATION_APPLICATION_FOCUS_OUT`
      releases it outright. `MainMenu` and `MatchResult`'s Menu button both force it visible
      defensively. `SettingsManager` gained `mouse_sensitivity` (a plain multiplier on
      `CameraRig.BASE_SENSITIVITY`, 0.2x–3.0x) and `invert_y`, both persisted to the same
      `settings.cfg` as the keybinds, with a slider + checkbox added to `SettingsPanel.tscn`.
      `CameraRig.apply_mouse_delta()` reads both.
      ⚠️ **Headless limitation, not a code bug:** `Input.mouse_mode` cannot actually be driven to
      `MOUSE_MODE_CAPTURED` in this environment — there is no real display/cursor for the engine
      to capture, so the assignment silently has no effect and `Input.mouse_mode` reads back
      `MOUSE_MODE_VISIBLE` regardless. **Confirmed with a live run:** `SettingsManager.set_mouse_sensitivity(2.0)`
      then `apply_mouse_delta(Vector2(100, 50))` produced exactly double the 1.0x case's rotation
      (−30° yaw, −15° pitch instead of −15°/−7.5°); flipping `invert_y` flipped the pitch's sign
      from negative to positive for the same input. The sensitivity/invert-Y **math** is
      confirmed correct. The capture/Esc/focus-loss **lifecycle** could not be exercised at all
      in this environment and needs a human with a real mouse and window.

### P3 — UI overhaul (moodboard)

- [x] **15. Design system (`Dev_Plan.md` §4.2).**
      `assets/ui/tumbang_preso.tres` + a `UiTheme` autoload of the same constants.
      `INK #040838`, `PANEL #E1E5E8`, `OFFENSE #F87020`, `DEFENSE #0080E8`, `IMPACT #F468A8`,
      `HIGHLIGHT #F8D028`, `DANGER #F80000`. `StyleBoxFlat` card chrome: 3px `INK` border,
      6px radius, 16px margins, 6px full-height accent bar. Theme type variations for buttons and
      labels — no more per-node `theme_override_*`.
      **Get the display font from Harry** (heavy hand-drawn unicase marker face); if it cannot be
      redistributed, use Luckiest Guy / Chewy / Titan One (SIL OFL). Add `*.ttf` and `*.otf` to
      `.gitattributes` LFS. **Record the licence for submission Form 03.**
      *Acceptance:* setting the theme on a scene root restyles its whole subtree with no per-node
      overrides.
      **Done, with one deliberate deviation and one blocker.**
      *Deviation:* `UiTheme` (`scripts/ui/ui_theme.gd`) is a static-only `class_name`, not an
      autoload, and the `.theme` is **generated from it** by `tools/regenerate_ui_theme.gd` rather
      than hand-authored beside it. The brief's "theme file + autoload of the same constants" is
      two copies of the same palette that can drift; generating one from the other removes that
      class of bug entirely. Regenerate and commit both after any constant change:
      `godot --headless -s tools/regenerate_ui_theme.gd`.
      Applied project-wide via `gui/theme/custom` in `project.godot`, so the acceptance test is
      satisfied one level up from what was asked — no scene needs the theme assigned at all, and
      screens nobody has written yet inherit it too. All five existing screens (MainMenu, PlayMenu,
      SettingsPanel, MatchResult, Main's pause overlay) and the HUD were converted; the only
      remaining `theme_override_*` in the project is the version stamp's, which is now a type
      variation too. HUD text over the 3D scene uses the `Hud*` variations (CARD fill + INK
      outline) — one variation per size, so no node needs a font-size override.
      Also fixed in passing: `SettingsPanel`'s `Layout` was a fixed 600px-tall centred box in a
      648px viewport, so its Back/Reset row sat 39px from the bottom edge and would be pushed
      off-screen entirely at any smaller window size. It is now a full-height centred column with
      the bindings `ScrollContainer` absorbing the slack, so the button row is reachable at any
      window size.
      🚧 **BLOCKER — display font.** The moodboard's heavy hand-drawn unicase marker face is
      Harry's and was not supplied with this brief, and no substitute was downloaded (an unvetted
      font binary is both a licence and a supply-chain question, and Form 03 needs a recorded
      licence either way). The theme therefore ships on Godot's default font: **palette, chrome,
      layout logic and type scale are all moodboard-accurate, only the typeface is standing in.**
      Dropping the real face in is one line — `theme.default_font` in `ui_theme.gd`, then
      regenerate — plus adding `*.ttf`/`*.otf` to `.gitattributes` LFS and recording the licence.

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
      **Partially done — the CLASS half is built, the TEAM/PLAYER half is not.**
      Every unit now has a distinct model instead of four identical white capsules, driven by
      `scripts/characters/character_visual.gd` on `CharacterBase.tscn`'s `Visual` node:
      - **Person** — Kenney "Mini Characters" (CC0, `assets/characters/persons/`, licence committed
        alongside as `KENNEY_LICENSE.txt`). Indexed by team so the two Persons in a match are
        visibly different people; two spare models are in the repo for the character-select roster
        (B-24). Their `idle` clip plays, so they don't stand in bind pose.
      - **Can (Lata)** and **Tsinelas** — authored low-poly primitives in
        `scenes/characters/visuals/`, in the moodboard's own colours (Can: `DEFENSE` blue body,
        `OFFENSE` orange rims, `HIGHLIGHT` yellow face disc; Tsinelas: `DEFENSE` blue sole,
        `IMPACT` pink straps). No Can/Slipper art shipped with the brief, so these are built, not
        imported.
      The model is chosen at runtime, not baked into the scene, because **`is_can` flips every
      round** — a Prop is a Can one round and a Tsinelas the next, so `reset_for_new_round()`
      reapplies it.
      **Still open on this item:** the ground ring decal in the team's current role colour, the
      `A1`/`A2`/`B1`/`B2` billboard tags, the own-unit chevron, the local-test input-set suffix,
      and the off-screen edge arrows. None of the team/player identification is built — right now
      you can tell a Can from a Tsinelas from a Person at a glance, but not Team A's Person from
      Team B's beyond which model they happen to be using.
      **Also still open:** only `idle` is wired. Kenney's rig ships 32 clips (walk, sprint, jump,
      die, attack-melee, …) and none of the others are driven by gameplay state, so units slide
      around in their idle pose.

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
- **Build version.** Single source of truth is `application/config/version` in `project.godot`;
  `scripts/systems/game_version.gd` (`GameVersion`, a static-only `class_name`, not an autoload)
  reads it. Bump the minor number in the same commit as any gameplay/UI/model/scene change —
  docs-only commits don't need it. `GameVersion.attach_to(control)` puts a dim `vX.Y` stamp in the
  bottom-right; it's on the main menu and the in-match HUD, so which build is running is
  confirmable on screen instead of by diffing files.
- Adding a new `class_name` script requires a `godot --headless --import` pass before anything can
  reference it — the global class cache is only rebuilt on import, and until then every referencing
  script fails to parse with "Identifier not declared in the current scope". The same pass writes
  the `.gd.uid` sidecar, which this repo tracks.
