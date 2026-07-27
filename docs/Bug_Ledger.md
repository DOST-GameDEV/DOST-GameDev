# Bug & Issue Ledger — archive (B-01 … B-66)

Split out of `Handoff.md` on 2026-07-27, when that file was rewritten around the art / 3D /
UI / bugfix queue. **This file is history, not a work queue.** It is the full forensic record
of every bug found and fixed from the first audit through v3.4 — including the reproduction
notes and the "the docs were stale, this was already fixed" corrections, which are the most
useful part of it and would have been lost to a plain overwrite.

**Still-open items were copied forward into `Handoff.md` §3 and are tracked there.** If an entry
here says `[FIXED]`, it is done; do not re-litigate it. New bugs get the next free B-number in
`Handoff.md` §3, never in this file.

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
new assets needed. **Q-8 added screenshake and impact particles** (see B-66) on top of this, both
code-built with no new assets. `landed_on` itself is still unused. Sound and hitstop are still
open — those need real assets/design, not a code fix.

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

**B-60 · Pressing WASD rotated the camera of the unit you were driving. (NEW)**
`character_base.gd` called `look_at(global_position + direction, ...)` on *every* movement input,
including for the unit whose `CameraRig` is mouse-aimed. Because the rig is a **child** of the
body, snapping the body's yaw to the WASD direction dragged the camera round with it: aim 90° left,
hold `D`, and the camera flipped a full **180°**. `camera_rig.gd`'s own header already described the
intended contract — `look_at()` applies "when this rig's aim_source is MOVEMENT" — but
`character_base.gd` never knew about `aim_source` and so never honoured it.
Compounding it, movement was read in **world space** (B-05), which was right when the only camera
was the fixed-angle `ArenaCamera` and became wrong the moment the per-character FPP/TPP rigs made
the camera turn with the player: in first person, `W` has to go where you are looking.
**[FIXED]** the two halves are coupled and both landed together. A mouse-aimed unit now reads WASD
in the **body's** frame (so `W` is "where I'm looking") and does **not** call `look_at()` — the rig
owns yaw. Every other unit (remote peers, local-test dummies, `aim_source = MOVEMENT`) keeps the
original world-space scheme *and* its `look_at()`, which is correct for a unit nobody is aiming.
Attacks now fire where you are looking, which is what B-05 actually wanted.
Verified by driving a live instance: after a 90° mouse-look, holding each of W/A/S/D leaves body
yaw and camera forward **completely unchanged** (0.0° drift, was up to 180°), while movement
resolves to along-facing `+1.00` for W, `-1.00` for S, and right-of-facing `±1.00` for D/A. A
MOVEMENT-aimed unit was regression-checked in the same run: still moves world −Z on `W` from a 90°
yaw, and still turns to face its own movement.

**B-61 · The FPP self-hide made every Person invisible to everyone. (NEW)**
`camera_rig.gd::_apply_fpp_self_hide()` set every Person's meshes to
`SHADOW_CASTING_SETTING_SHADOWS_ONLY` **unconditionally**, never consulting `_active`. The rule it
was supposed to implement was already written in its own doc comment — *"other peers still need to
see the mesh"* — but the code hid the body of every Person in the match, not just the one being
looked through. Result: Persons rendered as walking shadows with no body, teammates and opponents
alike, from every camera. Props were unaffected (TPP never self-hides).
This was latent, not new: the self-hide had silently been a **no-op** because it ran in `_ready()`,
which fires before `character_visual.gd` instances any meshes for it to find. Making it actually
work (v1.5) is what exposed the underlying logic error.
**[FIXED]** the hide is now gated on `_active and _mode == FPP`, restores
`SHADOW_CASTING_SETTING_ON` otherwise, and is re-applied from `set_active()` so it tracks the
camera being handed between units by the debug switcher. Verified: with a Prop active, all four
units read `cast_shadow = 1`; switching the camera onto a Person drops **only that Person** to `3`
and leaves everyone else at `1`. Confirmed in a rendered frame — both Persons visible, and the
one you look through still casts its own shadow.

**B-28 · No export presets, no build, no CI.** `export_presets.cfg` is gitignored and none
exists. The game has never been run outside the editor, and the submission needs a real build.

**Q-7 verification note.** `HazardZone` gained a visual — a code-built `CylinderMesh` decal (no art
asset), radius read from the actual `CollisionShape3D`'s `SphereShape3D` rather than a second
exported number, `UiTheme.IMPACT` at 0.35 alpha, unshaded so it reads the same under any light.
Placed one permanent instance (`Hazards/HazardZone` in `Main.tscn`, radius 3.0, `speed_multiplier
= 0.5`, `lifetime = 0.0`, at `(5, 0.5, 5)` — clear of every `SPAWN_POINTS` entry) with
`collision_layer = 0` / `collision_mask = 2` set directly in the scene, matching what `spawn()`
already does for the ability-spawned case (a scene-placed zone doesn't run through that helper).
Found and fixed two real bugs while wiring this up, neither visible from reading the code:
(1) `HazardZone.spawn()` set `global_position` **after** `add_child()`, but `_ready()` — which now
also builds the visual, positioned relative to `global_position` — fires synchronously **during**
`add_child()`, so the ability-spawned path (Shatter Trap) would have built its decal at whatever
position the zone happened to be at *before* being placed. Reordered to set position first.
(2) The naive fix (`zone.global_position = at_position` before `add_child()`) throws
`"!is_inside_tree()"` and silently leaves the zone at the origin — `global_position`'s setter
requires already being in the tree. Switched to local `position`, safe because every caller passes
an already-world-space `at_position` to a parent with an identity transform. Verified live,
headless: the placed hazard's decal computes to exactly the expected world position and colour;
it is not in the `hazard_zone` group and survives a forced round transition unfreed; a separately
spawned Shatter-Trap-style hazard (elevated origin, unlike the floor-level map hazard) still
projects its decal onto the floor correctly and does join the group. Not independently
re-verified: the pre-existing speed-multiplier gameplay logic itself (B-17), since Q-7 only added
the visual and didn't touch `_on_area_entered`/`_on_area_exited`.

**Q-6 verification note.** Guard/Dash (B-16) was confirmed already fully implemented, exactly per
§0.2 — this task was surfacing it on the HUD, not building it. Added read-only
`get_guard_stamina_ratio()`/`get_dash_cooldown_ratio()` accessors to `CharacterBase`, a meter on
the Q-5 YOU card (one bar, GUARD or DASH picked by `is_can`, hidden for Persons), a key-label read
live from `InputMap` so a Settings rebind stays truthful, and a `hit_blocked` signal +
`CharacterVisual.flash_blocked()` (DEFENSE-tinted, deliberately distinct from B-44's white landed-
hit flash) wired into `apply_stagger()`/`apply_dent()`'s existing `_is_guarding` early-returns.
Verified live, headless: the meter is hidden while driving a Person; holding the bound key as a
Can drains the stamina ratio and the YOU card's bar mirrors it in lockstep; a dent landed on a
guarding Can changes neither `state` nor `dents` and fires `hit_blocked` exactly once (confirmed
via a signal-count check — the first attempt used a bare `bool` in a lambda closure and read as a
false negative, since GDScript lambdas capture locals **by value**; switching to a boxed `Array`
counter confirmed the real behavior was correct all along); releasing the key regenerates stamina
back to a full ratio; switching to a Tsinelas shows the dash cooldown ratio, a press drops it near
0 and it climbs back to 1.0 after `DASH_COOLDOWN` elapses. One documentation note: the Handoff/
Dev_Plan text calls the "ready again" flash colour `UiTheme.PAPER`, which isn't an actual defined
constant — substituted `UiTheme.CARD` (the theme's actual near-white token) instead.

**B-65 · No reconnect path — a rejoining player can come back as a different team and role. (NEW,
logged while doing Q-5)** A rejoining player gets a brand-new peer id, so `main.gd::_peer_join_index`
assigns them the next free slot rather than restoring their previous one. **OPEN — needs a design
call, not a code fix**: preserving identity across a rejoin needs a stable player token instead of
a peer id, which is real work. Q-5 makes the *current* role legible (the new YOU card) but
deliberately does not attempt reconnection — see the decision list in §4.

**Q-5 verification note.** Added the HUD "YOU" card (`scenes/ui/YouCard.tscn` +
`scripts/ui/you_card.gd`), instanced into `HUD.tscn`. Shows class (`PERSON`/`CAN (LATA)`/`TSINELAS`),
team letter, and side this round, with a role-coloured (`UiTheme.OFFENSE`/`DEFENSE`) 6px accent
bar — never team-coloured, per §4.2's hard rule. Resolves the local character two ways: networked
via a new `main.gd::get_local_character()` (scans `_spawned_characters` for
`is_multiplayer_authority()`); Local Match by scanning the scene tree for whichever unit currently
holds `player_id == 1`. The card polls every 0.15s rather than listening for a debug-switcher
event, since protocol rule 11 (`Dev_Plan.md` §0.3) forbids gameplay code from referencing anything
debug-only — a plain public-var poll stays correct with zero coupling in either direction. Also
connects to `MatchManager.round_started` directly and gets an explicit `hud.refresh_you_card()`
call from `main.gd::_sync_state_to_late_joiner` so a joining client doesn't wait out the poll
interval. Verified live, headless: Local Match round 1 reads `PERSON · TEAM A · DEFENSE` (matching
the actual default-driven unit); reassigning `player_id` the same way the debug switcher does (Tab)
correctly flips the card to the newly-selected unit; ending round 1 and starting round 2 flips the
side the instant the role swap happens (`TEAM A · DEFENSE` → `TEAM A · OFFENSE`). Networked: a
client joining ~3s into a running match already shows a populated, correct card
(`CAN (LATA) · TEAM A · DEFENSE`, matching its actual spawned role) within 0.5s of connecting — not
blank.

**Q-4 verification note (2026-07-27).** Confirmed the match-result screen already works exactly as
Handoff.md §0.2 said: driven a Local Match to a real 3-0 via direct `MatchManager.report_round_result()`
calls spaced past `INTERMISSION_DURATION` (so `begin_next_round()` fires between them the same way
it would in real play, rather than compressing three rounds into under a second) — the result
screen appeared with the correct `TEAM A WINS THE MATCH!` text and score, and Rematch correctly
returned to a fresh 0-0 round 1. **B-59 did not reproduce** across this run (round_number and both
win counts stayed stable while the result screen sat idle for 3+ seconds). One thing worth
recording for whoever chases B-59 next: an EARLIER, unrealistically-fast version of this same test
(three `report_round_result()` calls 0.2s apart, bypassing the normal round-duration timing
entirely) DID produce a spurious `round_number` increment after the match had already ended — but
root-caused to `MatchManager._intermission_time_left` staying set from a non-finishing round's
call when the very next call finishes the match before that timer naturally elapses.
`_finish_match()` doesn't clear it. Confirmed this can't happen via the real `RoundManager.report_round_win()`
→ `MatchManager.report_round_result()` path, because `begin_next_round()` (which would need to
start a new round for `report_round_result()` to be called again) can only fire once
`_intermission_time_left` has already reached zero — so a second call can never find it still
positive under real gameplay timing, only under a synthetic test that skips actual round durations
entirely. Not fixed here (unreachable through any real code path today), but flagged in case a
future change (e.g. an admin "force-end round" debug command) ever calls `report_round_result()`
outside the normal `RoundManager` chain.

**The one real functional gap in Q-4 — the world kept running behind the result screen — is now
fixed.** `match_result.gd::_on_match_won` sets `get_tree().paused = true` when not networked
(reusing Q-3/B-64's `PROCESS_MODE_ALWAYS` on this node so its own buttons stay clickable);
`_on_rematch_pressed()` and `_on_menu_pressed()` both clear it before doing anything else, for the
same reason Q-3's `_on_return_to_menu_pressed()` does. Networked play is untouched — freezing one
peer's tree while the host's authoritative match state keeps running for everyone else would
desync it, same split as Q-3. Verified live, headless: Local Match — `tree_paused` reads `true`
the instant `match_won` fires, `false` again immediately after Rematch, and the new round starts
active. Networked — both host and client show the result screen (confirming the existing
`_sync_match_won` RPC reaches the client fine) with `tree_paused` staying `false` on both the whole
time.

**Q-4 restyle to the moodboard Bo5 grid, done.** `MatchResult.tscn`/`match_result.gd` replace the
plain message-only card with: a winner headline at `UiTheme.FONT_SIZE_DISPLAY`; a two-team pip row
(three squares each, filled for rounds won, from `MatchManager.team_a_wins`/`team_b_wins`); and a
card accent bar. Per §4.2's hard rule, colour tracks **role**, never team — the accent bar and both
teams' pip fill colours are `UiTheme.OFFENSE`/`DEFENSE` keyed off `MatchManager.team_a_is_can` as
it stood in the just-concluded final round (read before anything resets it), not by which team A/B
letter the pips sit under. Verified live, headless, by reading the actual computed `StyleBoxFlat`s
back off the nodes after driving to a real 3-0: winner headline text correct, card's accent
`border_width_left` = `ACCENT_BAR_WIDTH + BORDER_WIDTH` (9, confirming the accent path actually
ran, not the plain no-accent branch), accent `border_color` matched `UiTheme.DEFENSE` exactly
(Team A won this run holding the Can/Defense side in the final round), all three Team A pips
filled with that same `DEFENSE` color, and all three Team B pips at `UiTheme.CARD` (empty/unfilled,
matching its 0 wins). Buttons unchanged (`Rematch`, relabelled `MAIN MENU` per `Dev_Plan.md` §4.3)
through the existing theme; non-host Rematch hide untouched.

**Q-10 verification note — no code changed.** Confirmed §0.2's characterization exactly: the
switcher and `DebugBar` are both fully built, wired into `Main.tscn`, and **already discoverable**.
`debug_bar.gd`'s `_keys_label.text` has read `"F1-F4 set P1 · Shift+F1-F4 set P2 · Tab cycle · F5
solo · F6 reset"` since the feature's original commit (v1.4) — this is not new. Step 1's concern
(bar reading `"(missing)"`) does not reproduce: verified live, headless, that `Slots` reads a fully
populated `"P1▶ TeamAPerson (Person · Team A · DEFENSE)   P2▶ TeamAProp (Can · Team A · DEFENSE)"`
on a fresh Local Match — `_match_root()`'s walk-up-from-the-bar resolution is working correctly.
Step 4 (does the switcher still work during Q-3's pause) — verified live: paused the tree, sent a
real synthetic Tab keypress via `Input.parse_input_event`, and the readout correctly updated
(`P1` cycled from `TeamAPerson` to `TeamBProp`) while `get_tree().paused` was still `true` —
`DebugPlayerSwitcher`'s `PROCESS_MODE_ALWAYS` continues to work correctly after Q-3's changes.
**Flagging a real conflict in the queue's own instructions, not building around it (protocol rule
3):** step 2 asks for the key hint to be styled "at `UiTheme.FONT_SIZE_CAPTION` in
`UiTheme.INK_MUTED`" — but `debug_bar.gd`'s own header comment explicitly states the opposite
design intent: *"Deliberately ugly: plain white monospace on a black strip, with NO reference to
`UiTheme` and no theme of its own, so nobody mistakes it for shipping UI and so removing it can
never leave a hole in the real design system."* Styling this debug-only bar with real design-system
tokens would violate that stated rationale and the §0.3 removal contract's spirit (a debug feature
should never look like it belongs to the shipped product). Left `debug_bar.gd` completely
unmodified rather than apply the conflicting instruction. No `Dev_Plan.md` §3.5 update needed —
step 1 found no behavior change to record.

**Q-9 verification note.** Added a `QuitButton` to `TitleScreen` (order: Play · Settings · Quit,
per `Dev_Plan.md` §4.3 — `StartButton`'s label also changed from "START" to "PLAY" to match), wired
to a plain `get_tree().quit()`. Deliberately title-screen-only, not the in-match pause menu — a
mid-match quit that skips `NetworkManager.disconnect_network()` would strand other peers, the same
soft-lock Q-1 fixed from the other end. Moodboard pass: wrapped `TitleScreen`'s and `PlayMenu`'s
existing content each in a new `PanelContainer` card (`UiTheme.card_style(PANEL, INK, IMPACT)` —
IMPACT chosen as a neutral brand accent since neither panel is role-specific), applied in code via
`add_theme_stylebox_override`, same pattern as the Q-4/Q-5 cards. Kept the existing node types
(`VBoxContainer` positioning containers, unchanged anchors) and only added one nesting level rather
than restructuring the proven layout — there is no way to visually inspect pixel layout in this
headless-only session, so a larger structural rewrite would have been an unverifiable risk for a
task whose acceptance criteria don't require one. Button font sizes and consistent width were
already satisfied by the theme applied project-wide since v1.3 — no per-node change needed there.
`GameVersion.attach_to(self)` build stamp untouched. Display typeface remains the open blocker in
§0.5 — shipped on the default font, as before.
Verified live, headless: `MainMenu.tscn` and the full `Main.tscn` flow both load with zero script
errors after the restructure; pressing `QuitButton` (via its own `pressed` signal, connected
identically to every other button on the screen) exits the process cleanly (exit code 0) with no
further code executing afterward — confirmed by a print statement placed after the signal emission
that correctly never ran.

**B-66 · Hit feedback only ever played on the struck character's own owning peer. (NEW, Q-8)**
`_apply_hit_result` is `@rpc("any_peer", "call_local", "reliable")`, sent by the host via
`rpc_id(target_authority, ...)` — reaching only that one peer. Every other peer watching the same
hit land saw nothing at all: no flash, no shake, no particles.
**[FIXED]** split the cosmetic half out into a new `_rpc_play_hit_vfx()`, broadcast to every peer
from `hitbox.gd` right after the existing state-resolution call; state resolution
(`apply_stagger`/`go_downed`/`seal`/`apply_dent`) stays exactly where it was, on the authority.
Also added, per Q-8's scope: `CameraRig.shake()` — a decaying positional offset on the camera node
(never the character body's rotation, which would fight `_is_mouse_aimed()` and reproduce B-60),
FPP at half TPP's strength, clamped via `max(current, new)` so rapid multi-hits can't stack; and
`CharacterVisual._spawn_impact_particles()` — a code-built one-shot `GPUParticles3D` burst in
`UiTheme.IMPACT`, no art asset, self-freeing on `finished`. `CharacterBase._flash_hit()` gates the
shake call to only the struck player's own screen (`is_multiplayer_authority()` when networked,
`player_id == 1` in Local Match — same resolution Q-5's YOU card already uses).
Found and fixed a second real bug while verifying this one, in code from THIS same task, not
pre-existing: the queue's own instructions specified `_rpc_play_hit_vfx` as
`@rpc("authority", ...)`. Confirmed live with two real headless peers that this is wrong — hit
resolution always runs on the **host** (`hitbox.gd`), but a struck character's multiplayer
authority is its *owning peer*, which for any non-host player's own unit is **not** the host.
Godot's `"authority"` RPC mode only accepts a call sent **by** that specific node's own authority,
so the host calling it on a client's own character was silently rejected — the client's console
logged `RPC '_rpc_play_hit_vfx' is not allowed ... Mode is "authority"`, meaning the fix would have
shipped working only for hits landing on the host's own unit and doing nothing for anyone else,
the exact bug it was meant to close. Switched to `"any_peer"`, matching `_apply_hit_result`'s
already-correct pattern one line above it.
Verified live, headless: Local Match — the driven unit's rig shows an active shake and exactly one
`GPUParticles3D` child after a simulated hit, a second (not-mine) character's rig never activates
its shake, holding a movement key through the hit leaves body `rotation.y` provably unchanged
(the B-60 regression check), the shake fully decays and the camera returns to its exact cached
base position, and the particle node frees itself afterward. Networked, after the `any_peer` fix —
both a hit landing on the host's own character and one landing on the client's own character
broadcast correctly to both peers with no errors, where the initial `"authority"` version failed
for the second case exactly as predicted.

**B-64 · The pause menu never actually paused anything. (NEW, Q-3)** `main.gd::_unhandled_input`
toggled `pause_root.visible` and the cursor, never `get_tree().paused` — `RoundManager`'s round
timer, `MatchManager`'s intermission countdown, and every `CharacterBase._physics_process` (input,
gravity) kept running behind the overlay.
**[FIXED]** Local Match now gets a real `get_tree().paused` freeze; networked play stays a
non-freezing overlay whose label says "PAUSED — the match is still running" (a naive freeze would
stop the host's authoritative timer for everyone, or stop a client's own movement while the host
keeps simulating it — Handoff.md §0.3). Caught a second, undocumented bug while implementing the
first: Godot gates `_unhandled_input` by `process_mode` exactly like `_process`, and `Main`'s own
script (running the Esc-toggle) sits at the default `PROCESS_MODE_INHERIT` — so the instant Local
Match actually paused, `Main` would stop receiving input entirely, including the Esc press meant
to resume it, permanently soft-locking the game. Confirmed with a standalone headless
`SceneTree`-script test before touching the real scene: an `INHERIT`-mode node's
`_unhandled_input` never fires while `paused` is true, only an `ALWAYS`-mode node's does. Fixed by
moving the Esc listener onto a new `scripts/ui/pause_layer.gd` (`class_name PauseLayer`) attached
to `PauseLayer` itself, which is already `PROCESS_MODE_ALWAYS`; it emits `toggle_requested`, which
`main.gd` connects to. `HUDLayer/MatchResult` is also now `PROCESS_MODE_ALWAYS` (Q-4 needs it to
stay clickable if a match ends the same frame pause fires). `_on_return_to_menu_pressed()` clears
`get_tree().paused` as its first line, before `change_scene_to_file` — a scene change with the
tree still paused would otherwise load `MainMenu.tscn` paused and kill every button on it.
Verified live, headless, with real key-event injection (`Input.parse_input_event`, not calling the
handler function directly) exercising the exact input path: Local Match — timer frozen bit-for-bit
during a 3s pause, Esc correctly resumes it (confirming the `PauseLayer` fix), timer decreasing
again after, Return to Menu leaves `tree_paused=false`, and a second Local Match started
immediately after is fully interactive (`round_active=true`, timer counting from a fresh 90.0).
Networked — client's overlay shows the "still running" label, `get_tree().paused` stays `false`
throughout, the client's own timer read kept decreasing across the pause, and the host's timer
ticked continuously and identically the whole time, unaffected by the client's local overlay.

**B-63 · A mid-round client disconnect left `RoundManager` tracking a freed Can. (NEW, Q-2)**
`main.gd::_on_player_disconnected()` freed the leaver's node and erased its dictionary entries,
but never told `RoundManager` — if the leaver was the tracked Can, `_tracked_cans` kept a freed
reference for the rest of that round (self-heals on the next round transition via `_reset_world`,
which already clears and rebuilds it, but not before then). No toast either — remaining peers had
no idea anyone had left.
**[FIXED]** extracted the reregistration loop `_sync_state_to_late_joiner` already ran into a
shared `_reregister_tracked_cans()` helper, called from both that function and
`_on_player_disconnected()` (host-only, same gate `RoundManager` uses throughout). Added
`@rpc("authority", "call_local", "reliable") func _rpc_show_toast()`, broadcast to every peer on
disconnect. Verified live, headless, three real instances (one host, two clients): disconnecting
the client holding the Can produced a clean re-registration with no dangling reference, and both
remaining peers (host and the other client) printed the toast (temporary instrumentation,
reverted before commit). One caveat, honestly reported: with only one Can per round by design
(the Prop of whichever team holds the defensive side), disconnecting that exact Can leaves nobody
left to dent/seal for the remainder of that round — the round can still only end by timer, same as
before the fix. That is correct given the current 1-Can-per-round design, not a regression; the
fix's actual contribution is the toast and the elimination of the dangling reference, not a new
way to end a Can-less round early. A one-off `ERR_UNAUTHORIZED` replication error surfaced on the
first test run (`on_despawn_receive`) but did not reproduce on a repeat with a longer settle time
between join and disconnect — concluded to be a test-timing artifact (killing a client within ~2s
of it joining, before spawn replication had settled), not a defect in this fix.

**B-62 · Clients hung forever when the host quit. (NEW, Q-1)** `NetworkManager.server_disconnected`
already fired and already nulled the peer / cleared `connected_peer_ids`, but nothing in the
codebase listened to it — a client was left in `Main.tscn` with a dead peer, a frozen timer, and
no way out but Alt+F4. A join to an unreachable address (`connection_failed`) had the same
soft-lock, just triggered before anyone ever connected.
**[FIXED]** `main.gd::_start_joining()` connects both signals (not `_ready()` — a host has no
server to lose and Local Match has no `NetworkManager` session at all). Both handlers release the
mouse, reset `MatchManager`/`RoundManager`/`GameLaunch`, set a new
`GameLaunch.pending_status_message`, and return to `MainMenu.tscn`; `main_menu.gd` lands on the
Play menu (not the title screen) and shows that message once. Verified live, headless, with the
real Godot 4.7 binary: joining `127.0.0.1` with no host running printed
`connection_failed fired` and the menu consumed `"Could not reach that host."`; hosting, joining
from a second instance, then force-killing the host process printed `server_disconnected fired`
and the client's menu consumed `"Host ended the match."` (temporary print instrumentation,
reverted before commit, same as B-01/B-29's verification pattern).

---

