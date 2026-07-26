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
**[FIXED]** — in two passes. `arena_camera.gd` exposes `add_target()`/`remove_target()`; every
networked spawn registers itself at runtime (`main.gd::_build_networked_character`) instead of
relying on the `_ready()`-time `follow_paths` cache. That alone was **not sufficient**: the first
attempt filtered `_targets` with `_targets.filter(func(t: Node3D) -> bool: return
is_instance_valid(t))` — a `Node3D`-typed lambda parameter over a typed `Array[Node3D]`. Passing
an already-freed reference as an argument to that typed parameter throws *"Cannot convert
argument 1 from Object to Object"* from inside `filter()` itself, every single frame, which is
the exact per-frame error flood B-03 describes — a `--quit`-only smoke test never runs a frame of
`_process()` so it couldn't catch this, but an actual two-instance run (`godot --headless --path
. scenes/main/Main.tscn -- --host` / `--join=127.0.0.1`, left running several seconds) reproduced
it immediately on both peers. Replaced with a plain `for t in _targets: if is_instance_valid(t):
...` loop building a fresh array — untyped iteration doesn't trigger the same argument-conversion
check. Re-ran the same two-instance test: **zero errors on either peer** across an 8-second run,
confirming the fix for real this time. The `Camera3D` node itself is retained as the
broadcast/local-test cam per `Dev_Plan.md` §3.4 and will be superseded by the per-character
`CameraRig` (queue item 13), not deleted outright.

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
**[FIXED]** `main.gd::_on_player_connected` now calls a new `_sync_state_to_late_joiner` RPC
targeted (`rpc_id`) at just the newly connected peer, carrying exactly that bundle. It sets the
`MatchManager`/`RoundManager`/`GameLaunch` fields directly and calls the new
`Hud.set_round_display()` and `RoundManager.register_can()` for already-known Cans — deliberately
*not* by replaying `_on_match_round_started`'s reset cascade, which would wrongly re-zero the
position/state/dents of characters that already arrived on this peer correctly via
`MultiplayerSynchronizer`'s `spawn=true` replication. Since `_start_hosting()` still calls
`begin_next_round()` before anyone can be connected (B-13), this fires for every join, not only a
literal "late" one. **Verified** by the same two-instance run as B-01: the client, joined ~2.5s
after the host (by which point the host was already at `round_number=1 round_active=true`), logs
`round_number=1 round_active=true team_a_is_can=true game_mode=0` from its very first tick instead
of the stale `round_number=0` default — the late-join sync landed and applied correctly.

**B-02 · Every special and Tag/Throw is a no-op for anyone who isn't the host.**
`ability_utils.gd:34` adds the pulse hitbox to `current_scene` on the activating peer only — it
is never replicated. `hitbox.gd:45` then returns early on any non-host peer. A client's ability
creates a hitbox that refuses to resolve, and the host never has that hitbox at all. Affects
Spin Guard, Bagsak Bomb, Bakya Bash, Flick Dash, and Person's Tag/Throw — every action except
Bump. *Fix:* RPC the activation to the host and spawn the resolving hitbox there; cosmetic
copies locally if you want the visual.
**[FIXED]** `character_base.gd::_rpc_notify_ability_activate` is an `any_peer`/`call_local` RPC
to peer 1: a non-host activator runs `ability.activate(self)` locally for its own cosmetic copy
(unchanged), then RPCs the host to run `activate()` on the host's own copy of that same
character, so the authoritative resolving hitbox exists where `hitbox.gd`'s host-only check can
actually land it. Same pattern reused for the special-ability press inside the `DOWNED` branch
(B-06). ⚠️ Still unverified by a human against a real non-host client.

**B-04 · Networked Props spawn with no ability.** `main.gd:203` assigns `PERSON_ACTION_ABILITY`
only when `is_person` is true. Props — the half of the team carrying the entire roster — get
`ability = null` over the network. Only the local flow has an ability on a Prop, and only
because `Main.tscn:50` hardcodes `quick_stand.tres` on `TeamAProp`.
**[FIXED]** `main.gd::_build_networked_character` now assigns a `.duplicate()`d `PROP_ABILITY`
(`quick_stand.tres`) to every networked Prop, matching what `Main.tscn` already hardcoded for
the local flow's `TeamAProp`. Full per-Prop roster selection is still Phase 2 (B-24) — every
networked Prop defaults to Quick Stand until character select exists.

**B-30 · Networked characters never get a `player_id`. (NEW)** `_build_networked_character`
(`main.gd:196`) sets `is_can`, `is_person`, `team_is_can_side` and authority, but never
`player_id` — so all four networked characters keep the scene default of `1` and read `*_p1`
actions. It works by accident on LAN (one character per machine), but: the Settings panel's
entire P2 column is dead in networked play; the moodboard's WASD-for-Attacker /
arrow-keys-for-Defender scheme cannot be honoured; and any shared-screen fallback breaks
immediately. *Fix:* pass `player_id` through the spawn dictionary.
**[FIXED]** `main.gd::_spawn_player` now computes `player_id := (index % 2) + 1` — same `index %
2` split that already decides `is_person` — and includes it in the spawn dictionary;
`_build_networked_character` applies it. Each team's Person gets slot 1 (WASD default), its Prop
gets slot 2 (arrows default), fixed for the match, so the Settings panel's P2 rebind column now
has a real effect over LAN. ⚠️ This does **not** deliver the moodboard's WASD-tracks-Attacker /
arrows-tracks-Defender scheme — that would need re-binding input on every role swap, since
Attacker/Defender flips each round while `is_person`/`player_id` don't. Flagging, not silently
building around it. Unverified by a human.

**B-48 · `GameLaunch.game_mode` is never networked. (NEW)** Each peer reads its own menu
selection. The host's mode governs hit resolution (`hitbox.gd:59`), but the client's
`_wire_downed_flash` dent gate (`main.gd:279`) reads the *client's* value — so a client on
Option B never shows a dent counter while the host runs Option A. Send `game_mode` with the
match-state sync in B-29.
**[FIXED]** — the same `_sync_state_to_late_joiner` RPC that fixes B-29 also carries
`game_mode`, and since every join goes through it (B-13 means every join is effectively a "late"
one), this is fixed for every join, not only a literal late one. **Verified** by the same
two-instance run: client log shows `game_mode=0` (Option B, the host's default) from its first
tick — matching the host instead of silently defaulting.

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
**[FIXED]** `CharacterBase.team: int` export added, set from spawn data in
`_build_networked_character` and explicitly on all four units in `_start_local_test()`.
`hitbox.gd::_on_area_entered` now skips a hit where `target.team == owner_character.team`. Items
4, 8, and 9 are unblocked.

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
**B-10 [FIXED]:** `main.gd::_on_match_round_started` (via the new `_reset_world()`, see queue item
10) calls `reset_for_new_round()` **and** repositions **all four** units (networked and local flow
both) to a `SPAWN_POINTS` slot every round, not just the tracked Can. ⚠️ **Correction:** this was
first written as "fixed" based on reading the code, but the local-flow branch was never actually
exercised — B-49 (this section, above) meant `is_networked()` always read `true` in local test, so
`_on_match_round_started` always took the *networked* branch, which iterates an empty
`_spawned_characters` and does nothing. B-49's fix made this reachable for real, and it's now been
confirmed with a real run twice over (the KillPlane test in B-49's note, and the full intermission
cycle test in queue item 10). **B-37 also fixed** — see queue item 10 for the intermission state
machine that closes it.

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
**[FIXED] (interim, pre-camera-rig)** `character_base.gd::_physics_process` now `look_at()`s the
world-space movement direction whenever there is movement input, writing `rotation.y` for real —
attacks fire the way the character is actually moving. This landed before the camera rig (queue
item 13) existed; it is exactly `AimSource.MOVEMENT` from `Dev_Plan.md` §3.2, so when the rig
lands it only needs to *add* `AimSource.MOUSE` for the locally-driven FPP unit and otherwise
leave this alone. Still no separate aim axis, per the directive.

**B-06 · Quick Stand can never be activated.** `character_base.gd:142` returns early for
`STAGGERED`/`DOWNED`/`SEALED`; the `special_ability` input is read at line 160, *after* that
return. Quick Stand's only effect is self-righting from Downed — the exact state in which its
input is unreachable. Same structural problem for any future escape ability.
**[FIXED]** `special_ability` is now also read inside the `DOWNED` branch of the state `match`,
before the STAGGERED/DOWNED/SEALED early return, using the same activate-locally +
RPC-to-host-if-networked path as the normal (NORMAL-state) special-ability press.

**B-07 · Any stagger cancels Downed.** `apply_stagger()` (line 164) overwrites `DOWNED` with
`STAGGERED`, which auto-recovers to `NORMAL` after 0.25s. Under Option B, `hitbox.gd:70` sends
`"stagger"` to a Can that is Downed but still inside its self-right window — so hitting a downed
Can *rescues* it. Any bump from anyone, including its own teammate, is a free escape. Option B's
seal mechanic cannot work until this is fixed.
**[FIXED]** `apply_stagger()` now returns early on `state == State.DOWNED` too (previously only
guarded `SEALED`). A hit landing during the self-right window does nothing instead of rescuing
the Can; `hitbox.gd` already routes a hit after the window expires to `"seal"` instead, so this
only ever closes the free-rescue case.

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
**[FIXED]** `_do_activate()` now returns `bool`; `activate()` only sets `_used_this_round = true`
when it returns `true`. `quick_stand.gd` returns `false` for the real no-op case (not Downed);
the other five ability scripts return `true` unconditionally, preserving their previous
always-succeeds behaviour.

**B-12 · Friction is a per-frame constant, so there is no momentum and Flick Dash lasts three
frames.** `move_toward(velocity.x, 0, SPEED)` uses `SPEED` (6.0) as an absolute per-tick step,
not per-second — no `delta`. Max walk speed is also 6.0, so releasing a key stops you dead in one
tick, and it is frame-rate dependent if the physics tick ever changes. Flick Dash sets velocity
to 16 and it decays 16 → 10 → 4 → 0 in about 0.05s. The dash also applies a frame late, because
`_do_activate` runs after `move_and_slide()`.
**[FIXED]** Added `FRICTION: float = 30.0` (units/sec²) used with `delta` in every
`move_toward()` deceleration call, replacing the old bare `SPEED` per-tick step. The
special-ability check (and therefore `_do_activate()`) now runs *before* `move_and_slide()` each
physics tick instead of after, so a velocity-setting ability like Flick Dash's dash burst applies
the same tick it's pressed.

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
finished **TUMBANG PRESO** logo. Adopt the logo's name everywhere (`Dev_Plan.md` §0.4).

**B-28 · No export presets, no build, no CI.** `export_presets.cfg` is gitignored and none
exists. The game has never been run outside the editor, and the submission needs a real build.

---

## 4. Immediate Execution Queue

Prioritised: **P0 LAN → gameplay/reset → cameras → UI**. Every item has an acceptance test.
Tick items here and mirror them into `Dev_Plan.md` §5.

### P0 — Make LAN work

- [ ] **1. Debug player switcher — manual control of any unit in local mode (do this first; it
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

- [x] **2. Fix the LAN freeze (B-03).**
      Disable or delete the `Camera3D` node in `Main.tscn` (`Main.tscn:40-43`). It caches four
      `NodePath`s in `_ready()` and both `_start_hosting()` and `_start_joining()` free those
      nodes immediately after, so `_process` dereferences freed instances every frame on every
      peer. If `arena_camera.gd` is kept for broadcast use, convert it to runtime
      `register_target()` / `unregister_target()` with an `is_instance_valid()` guard, and
      default `current = false`. Ship this ahead of the camera rigs so LAN is testable today.
      *Acceptance:* Host Game (LAN) from the menu; no "previously freed instance" errors in the
      Output panel; the editor does not hang.

- [x] **3. Sync full match state to joining clients (B-29, B-48).**
      On `NetworkManager.player_connected`, the host `rpc_id()`s that one peer the current
      `round_number`, `team_a_is_can`, `team_a_wins`, `team_b_wins`, `time_left`, `round_active`,
      and `GameLaunch.game_mode`. The client applies it and runs the same
      `_on_match_round_started` path the host does.
      *Acceptance:* two editor instances. Host first, wait ten seconds, then join. The client's
      timer matches the host's, the HUD shows the same round and roles, and the client's Can is
      registered.

- [x] **4. Assign `player_id` to networked characters (B-30).**
      Pass it through the spawn dictionary in `_spawn_player` and apply it in
      `_build_networked_character`. Per the moodboard, keep WASD on the Attacker/Person set and
      arrow keys on the Defender/Can set.
      *Acceptance:* a client's character responds to its own bound set, and the Settings panel's
      P2 column has a visible effect in networked play.

- [x] **5. Replicate ability activation to the host (B-02).**
      Route `AbilityBase.activate()` through an `any_peer` RPC to the host, which spawns the
      resolving hitbox. Spawn a cosmetic-only copy locally for responsiveness if you want; the
      cosmetic one must never resolve hits.
      *Acceptance:* a non-host client presses special and the host sees the target stagger.

- [x] **6. Give networked Props their ability (B-04).**
      `_build_networked_character` assigns a `.duplicate()`d roster ability to Props, not just
      Persons. Until character select exists, default Props to `quick_stand.tres`.
      *Acceptance:* a client-controlled Prop can activate a special.

- [x] **7. Verify B-01 with two instances.**
      `--host` and `--join=127.0.0.1`. Both timers must count down together. It is marked fixed
      and has never been run.
      *Acceptance:* screenshot or a note in the commit confirming both windows show a moving
      timer.
      Ran `godot --headless --path . scenes/main/Main.tscn -- --host` and a second process with
      `-- --join=127.0.0.1`, temporarily instrumented to print state once a second (reverted
      before commit). Host: `round_number=1 round_active=true`, `time_left` 89.0 → 80.0. Client
      (joined ~2.5s later): `round_number=1 round_active=true`, `time_left` 86.7 → 80.7, both
      counting down together. Confirms B-01, and incidentally B-29/B-48 (see §3). No screenshot —
      headless has no display — but the printed state is the same information a screenshot of the
      HUD would show, from two real separate processes actually talking over ENet on localhost.
      This same run also caught and fixed a **real regression in the already-"[FIXED]" B-03**: see
      §3 — the original filter()-based fix threw a per-frame error on both peers that a
      `--quit`-only smoke test can't detect because it never runs a frame.

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
      Four `StaticBody3D` walls at a ±41 boundary (well outside the 40×40 floor's ±20 extent, so
      you can genuinely walk/get bumped off the edge — no wall right at the floor boundary) plus a
      90×4×90 `KillPlane` Area3D at y=-10. `CharacterBase.spawn_position` is kept up to date by
      `main.gd` everywhere it already sets `position` (initial spawn and every round-start
      reposition); `KillPlane.character_respawned` → `main.gd` shows the toast only for a
      locally-relevant character (own unit when networked, any unit in local test). Verified for
      real: forced a local-test unit into the kill zone in a running headless instance — it came
      back at its exact recorded `spawn_position`, zero velocity, one `body_entered` event, no
      errors. Camera-stays-with-you and no-other-view-disturbed aren't meaningfully testable until
      the per-character camera rig (item 13) exists — today's broadcast `ArenaCamera` frames
      everyone's midpoint regardless, so this is `[x]` for the respawn mechanic itself, not for
      those two camera-specific acceptance clauses.

- [x] **10. Round intermission state + full world reset (B-10, B-37).**
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
      **B-14 fixed.** `MatchManager.reset()` / `RoundManager.reset()` added; called defensively at
      the top of `main.gd::_ready()` (the one scene every match path loads through) and explicitly
      by the new `scenes/ui/MatchResult.tscn` / `scripts/ui/match_result.gd` on both its buttons.
      `MatchResult` is self-sufficient like `Hud` — connects to `MatchManager.match_won` itself,
      no wiring needed beyond being instanced under `Main.tscn`'s `HUDLayer`. **Rematch** resets
      both autoloads and calls `MatchManager.begin_next_round()` **in place, without reloading the
      scene** — a networked rematch would lose the connection and every spawned character on a
      reload, and everyone's already reset to spawn via the normal round-start path anyway. Hidden
      for a non-host client, since `begin_next_round()` is host-gated and pressing it would be a
      silent no-op. **Menu** disconnects the network, resets both autoloads and `GameLaunch`, and
      returns to `MainMenu.tscn`. Plain placeholder styling — item 20 replaces this with the
      moodboard's Bo5 grid.
      **Verified live:** forced three round wins for Team A in a running headless local-test
      instance (`RoundManager.report_round_win(MatchManager.team_a_is_can)` each time, crediting
      Team A regardless of which side it was on that round). `match_won` fired with
      `winning_team=0`, `wins=3-0`, `round_active=false` (input frozen), `MatchResult.visible=true`.
      Called `_on_rematch_pressed()` directly: immediately `round=1 wins=0-0`,
      `match_result.visible=false`. Four seconds later the fresh round 1's timer was running
      normally and the reset unit was back at its exact spawn X/Z. Re-ran the two-instance
      networked test afterward — zero errors on either peer.

- [x] **12. Fix the core-loop bugs (B-05 via rigs, B-06, B-07, B-08, B-11, B-12).**
      B-05 is delivered by item 15 — do not build a separate aim axis. The rest are independent
      and small. B-07 in particular blocks Option B entirely.
      *Acceptance:* Quick Stand can be pressed while Downed and works; bumping an already-Downed
      Can does not rescue it; walking into someone and then pressing bump lands; a no-op Quick
      Stand does not consume the charge; releasing a movement key decelerates over ~0.2s rather
      than stopping dead.
      All six sub-bugs fixed in code (see §3). B-05 landed as movement-facing `look_at()` rather
      than waiting for item 15's camera rig — compatible with `AimSource.MOVEMENT` in
      `Dev_Plan.md` §3.2, not a conflict. ⚠️ None of the five behavioural acceptance criteria have
      been confirmed by a human pressing buttons; only a headless no-crash smoke test has run.

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
      ⚠️ **What headless testing can and can't confirm.** No display exists in this environment, so
      nothing about how the camera actually *looks* — framing, the TPP wall pull-in, whether the
      `SpringArm3D`'s baked `rotation_degrees = (-15, 180, 0)` really produces "behind and above
      the character, tilted down" rather than something backwards — has been eyeballed. That needs
      a human in the editor. What **was** verified with real running instances, not just reading
      the code:
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
