# Netcode Agent Brief — interpolation, rejoin identity, demo-day reliability

**Run this on: Sonnet 5, high effort.** High rather than medium because everything here sits
directly on the replication and authority model, where a subtle mistake is expensive to unwind and
does not show up until four people are in a room.

**Lane:** 🔧 Build. **Worktree:** `.worktrees/build`, branch `code/<task>` off `integration`.
**Checklist items owned:** **4.2** (remote movement interpolation), **4.3** (rejoin identity,
B-65), and the code half of **6.1** (real-device LAN test — the test itself is 🧑 human).
**Paste-ready opener:** [`Agent_Prompts.md`](Agent_Prompts.md) → 🔧 Build lane.

---

## 0. Why this is not "polish"

`Dev_Plan.md` §6 has flagged the same thing for three passes and it is still true:

> **Real-device testing over wifi has never happened and is on the critical path.**

Everything to date is loopback on one machine. Real wifi adds latency and packet loss to a movement
layer with **no interpolation and no reconciliation**. Two consequences:

1. **A desync or a hang in front of judges costs more than a missing map.** Demo-day reliability is
   a feature — arguably the most important one on a judged submission.
2. **If real hardware forces the shared-screen fallback (GDD §7), the team needs to know weeks
   before the deadline.** The FPP/TPP split makes that pivot cost **one to two days, not half a
   day**: four viewports, and only one player per machine can mouse-look, so both FPP Persons would
   fall back to `AimSource.MOVEMENT`. If the pivot looks likely, take it early.

**Do 4.2 before 6.1.** Testing an uninterpolated movement layer over real wifi measures the wrong
thing — you will find out that it snaps, which is already known.

---

## 1. Read these first

1. **[`Checklist.md`](Checklist.md)** — items 4.2, 4.3, 6.1.
2. **[`Concurrency_Protocol.md`](Concurrency_Protocol.md)** — §2 path ownership, §3 the shared-file
   lock (`CharacterBase.tscn` is one), §8 the smoke gate.
3. **`Handoff.md`** §1 (the networking model — **frozen**), §2 (**frozen**), §3 (open bugs —
   **B-55, B-56, B-59, B-65** are yours), and §0.10 for what the last audit actually verified.
4. **`Dev_Plan.md`** §0 (standing directives), §2 (architecture rules 1 and 3), §5 Phase 0 and
   Phase 5, §6 "Testing multiplayer without four laptops".
5. Then the code: `scripts/systems/network_manager.gd`, `scripts/main.gd` (spawning, join index,
   `_reset_world`, `_sync_state_to_late_joiner`), `scenes/characters/CharacterBase.tscn`'s
   `SceneReplicationConfig`, `scripts/characters/carriable.gd` (host-authoritative transitions).

---

## 2. The model you must not break

- **Host-authoritative for anything that decides a round** — hit resolution, the timer, the score,
  the carry state. **Client-authoritative for a peer's own movement**, replicated via
  `MultiplayerSynchronizer`. No reconciliation, no anti-cheat: LAN prototype scope, deliberately.
- **`CharacterBase.tscn`'s `MultiplayerSynchronizer` replicates `position`, `rotation`, `state` and
  `dents`, outward from each character's OWN peer.** `position`/`rotation` are on
  `replication_mode = 1` (always), `state`/`dents` on `2` (on change).
- **Held/carry state is deliberately NOT on that synchronizer**, because routing it there would
  make it client-asserted. Clients call `_rpc_request_*` on the host; the host decides and
  broadcasts `_rpc_set_*` with `call_local`. **Do not "simplify" this into the synchronizer.**
- **Host-sent broadcasts are `"any_peer"`, not `"authority"`.** Resolution runs on the host, but a
  character's multiplayer authority is its own owning peer, so an `"authority"` RPC sent *by* the
  host is silently rejected. `CharacterBase._apply_hit_result` and `carriable.gd` both document
  this at their call sites.
- **`_peer_join_index` is the stable identity, not iteration order.** B-21 introduced it precisely
  so team and role assignment could not shift under a disconnect/rejoin, and B-68 was what happened
  when `_reset_world()` used a loop counter instead. Anything you add that assigns per-peer state
  uses `_peer_join_index`.

---

## 3. 4.2 — interpolation

Remote characters visibly snap. The replicated `position` arrives at the synchronizer's rate and is
applied directly.

Constraints that make this harder than the textbook version:

- **Do not interpolate the locally-driven character.** It is client-authoritative and already
  smooth; interpolating it adds input latency for no gain.
- **Interpolate the VISUAL, not the body.** `CharacterBase` is a `CharacterBody3D` whose collision,
  `Hitbox` (a fixed local offset) and every directional ability (`-transform.basis.z`) read from the
  body transform. Smoothing the body would smear hit registration. The `Visual` node exists as a
  wrapper for exactly this kind of decoupling — and `camera_rig.gd::_apply_fpp_self_hide` already
  treats it as one unit.
- **A carried slipper must not be interpolated at all.** `carriable.gd::_step_carried` snaps it to
  the carrier's hand every frame on every peer, deterministically, at zero bandwidth. Adding
  smoothing on top would make it lag behind the hand that is holding it.
- **A `FLYING` slipper must not be interpolated either.** Its arc is computed locally on every peer
  from the replicated launch origin and velocity, so it is already smooth and already agreed.
- **Round reset teleports.** `_reset_world()` writes `position` directly. Interpolation must
  **snap, not glide**, on a reset — otherwise every round starts with four characters sliding
  across the map from where they died. Give the interpolator an explicit "teleport" call and use it
  from `reset_for_new_round()`. The same applies to the `KillPlane` respawn.

---

## 4. 4.3 — rejoin identity (B-65)

A rejoining player can come back as a different team and role, because identity is the ENet peer
id and a reconnect assigns a new one. Needs a **stable player token** minted at first join,
persisted client-side, and presented on reconnect.

U-4 (the lobby) deliberately did **not** attempt this and said so. Its `_peer_join_index` derivation
(`index / 2` for team, `index % 2` for role) is read from one place — keep it that way, and make
the token map to a join index rather than duplicating the derivation.

**This is a demo-day feature, not a nicety.** A LAN demo where somebody's wifi blips is exactly the
failure the judges will see.

---

## 5. Traps

1. **`--quit` proves nothing.** It never executes a frame of `_process()`. That is how B-03 shipped
   "fixed" once already, and how B-77 threw on every launch of `Main.tscn` for weeks. The real
   check is `--quit-after 400` with a rendering device.
2. **The two-instance test is the minimum bar:**
   ```bash
   godot --path . --host &
   godot --path . --join=127.0.0.1
   ```
   or Godot's **Debug → Run Multiple Instances → 2** with per-instance arguments. Four gameplay
   files carry comments pointing at that menu — they are the documented workflow, not debug code,
   and the §0.3 removal grep explicitly filters them out.
3. **`_reset_world()` runs independently on every peer** and is deliberately idempotent — it runs
   twice per transition (`_on_round_intermission_started` then `_on_match_round_started`) and
   `character_visual.gd::apply()`'s `_current_key` early-out depends on that. **Do not change when
   it is called.**
4. **B-56 · `KillPlane` respawns on every peer, not just the character's authority.** Open, low, and
   directly in your path if you touch respawn.
5. **B-55 · `RoundManager`'s end-of-round state change rides an unreliable RPC.** Open, low.
6. **B-59 · Unreproduced: a completed match reset itself to round 1 / 0-0.** Watch for it while
   you are in here; it is the kind of thing a real-hardware session surfaces.
7. **Combat networking is deliberately unvalidated** — the host trusts client-reported bump timing.
   Fine for a LAN demo, **explicitly out of scope to harden.** Do not spend time on it.
8. **`.import` UID churn (B-71).** Two worktrees means two import caches. If a staged `.import`
   file's only change is its `uid://` line, unstage it — `Concurrency_Protocol.md` §7.

---

## 6. Scope

**Yours:** `scripts/systems/network_manager.gd`, the replication-facing parts of `scripts/main.gd`,
`CharacterBase.tscn`'s `SceneReplicationConfig` (**shared file — take the lock**), and a new
interpolation component under `scripts/characters/`.

**Explicitly NOT yours:** the carry/throw state machine's *behaviour*
(`Interaction_Tuning_Agent_Brief.md`) — you may not change what `carriable.gd` decides, only how
its results are smoothed; round-win logic (`RoundManager` owns it); anything under `assets/` or
`scenes/maps/`; the HUD.

---

## 7. Acceptance

- Two instances, `--host` and `--join=127.0.0.1`: a remote character moves smoothly, and **snaps
  rather than glides** on a round reset and on a kill-plane respawn.
- A carried slipper still sits in its carrier's hand with no lag on the non-carrying peer.
- Disconnect a client mid-round, rejoin it, play into the next round: **every peer agrees on every
  character's team, role and position.** Before 4.3 this is where it breaks.
- `godot --path . scenes/main/Main.tscn --quit-after 400` produces **no output at all**.
- All six commands in `Concurrency_Protocol.md` §8 before merging.
- **⛔ The real-device test (6.1) is 🧑 human and cannot be faked.** Report loopback results as
  loopback results. Say explicitly that real-wifi behaviour is unverified — this project's norm is
  that an unverifiable claim is `[~]` with the reason stated, never `[x]`.

---

## 8. Non-negotiables, restated inline

- **Authorship.** Every commit authored and committed solely as
  `M4tyu633 <matthewtlabrador@gmail.com>`. No `Co-authored-by:`, no mention of Claude, an AI
  assistant, or any tool anywhere in a commit. Verify with
  `git log -1 --format='%an <%ae> | %cn <%ce>'`.
- **Camera directive.** Person → FPP always, Prop → TPP always, derived from `is_person`, no
  toggles. The enforcement grep must return nothing:
  ```bash
  grep -rn "_mode = \|Mode\.FPP\|Mode\.TPP" scripts/ | grep -v camera_rig.gd
  ```
  Cameras are children of characters — **never** a scene-level node holding `NodePath`s to players.
  That is what caused B-03 and what A-2 deleted.
- **Architecture.** One `CharacterBase` scene, abilities as `.tres` Resources. Round-win logic out
  of `character_base.gd` and `hitbox.gd`. Host authoritative for anything that decides a round.
- **Debug code** follows `Dev_Plan.md` §0.3's removal contract without exception.
- **Both round-win modes stay in active, equal development.**
- **One concern per commit**, checklist item and B-number in the subject. Do not bump
  `application/config/version` in a feature commit while two lanes are running.

## 9. Reporting contract

Say what you changed and why. **Separate loopback results from real-hardware results** and never
present the first as the second. File new defects as the next free `B-` number in `Handoff.md` §3
with an exact reproduction. If your work makes the shared-screen fallback look more or less likely,
**say so explicitly and early** — that is a schedule decision the team needs weeks of warning on,
and it is the single most valuable thing this lane can report.
