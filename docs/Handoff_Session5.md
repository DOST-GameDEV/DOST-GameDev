# Handoff — Dev Session 5

Rough networking pass, as requested — real LAN multiplayer instead of the untouched
`NetworkManager` skeleton. Combat is intentionally **not** touched this session; that's
next.

---

## What's new

### `NetworkManager` — actually implemented, `scripts/systems/network_manager.gd`
Was host/join stubs only. Now:
- `host_game(port)` / `join_game(address, port)` — real ENet peers via Godot's
  high-level multiplayer API (`multiplayer.multiplayer_peer`).
- `disconnect_network()`, `is_networked()`, `is_host()`.
- Signals: `server_created`, `connection_succeeded`, `connection_failed`,
  `player_connected(peer_id)`, `player_disconnected(peer_id)`, `server_disconnected` —
  all wired to the underlying `multiplayer.*` signals so other scripts never touch
  `multiplayer` directly.

### Networked spawning — `scenes/main/Main.tscn`, `scripts/main.gd`
- Added a `Players` container `Node3D` and a `MultiplayerSpawner` (spawn path →
  `Players`) to `Main.tscn`.
- `main.gd` now branches on launch args:
  - **No args** — unchanged local single-PC/split-keyboard prototype
    (`CanTestCharacter` / `TsinelasTestCharacter`), exactly as before.
  - **`--host`** — starts a server, frees the two local test characters, and spawns a
    real networked `CharacterBase` for itself (peer id 1) via the spawner.
  - **`--join=<address>`** — connects to a host, frees local test characters, waits for
    the host to spawn it in.
- Host alternates `is_can` true/false by join order so a 1v1 network test has one of
  each — real 2v2 team assignment still needs the Attacker/Defender role-swap logic
  from the GDD, not built yet.
- **How to actually test it right now**: Debug → Run Multiple Instances in the editor,
  set one instance's arguments to `--host` and the other to `--join=127.0.0.1`. For real
  cross-device testing, `--join=<host's LAN IP>` instead. No lobby UI exists yet — this
  is command-line-args only, purely for smoke-testing the plumbing.

### Movement replication — `scenes/characters/CharacterBase.tscn`, `character_base.gd`
- Added a `MultiplayerSynchronizer` child replicating `position`, `rotation` (always)
  and `state` (on change).
- `CharacterBase._physics_process()` now returns immediately for any character that
  isn't locally authoritative once `NetworkManager.is_networked()` is true — i.e. you
  only simulate/read input for your own character; everyone else's copy is purely
  driven by the synchronizer. Zero effect on the non-networked local test flow.
- **This is client-authoritative, unvalidated movement.** No server reconciliation, no
  anti-cheat, no lag compensation, no interpolation/smoothing on the receiving end —
  positions will look like discrete snaps over a real network, not smooth motion. Fine
  for a LAN prototype smoke test, not fine to ship.

---

## What this rough pass deliberately does NOT cover yet

- **Combat is not networked at all.** Bump/Hitbox/Hurtbox/stagger/Downed/seal all still
  run purely locally per-instance. Two peers bumping each other right now will *not*
  see consistent results — this is exactly what "then combat" (the next phase) needs to
  solve: who's authoritative for a hit, how it gets reported to the other peer, and how
  `RoundManager`/`MatchManager` (currently local-only, no host-authoritative reporting)
  get networked too.
- **No lobby/menu UI.** Hosting/joining is command-line args only.
- **No reconnect handling, no NAT traversal** — same-LAN only, which matches the GDD's
  requirement, but there's no graceful handling yet if a peer drops mid-round.
- **No movement smoothing/interpolation** on remote characters — expect visible
  snapping, not a bug, just not addressed yet.
- **RoundManager/MatchManager are still fully local** — each peer runs its own
  independent copy of the round timer/score with no networking between them. This is
  the next big thing combat-networking needs to fix: whoever hosts needs to be the
  single source of truth, broadcasting timer/score/round-state to clients rather than
  each peer computing it independently.

## Suggested next session (combat, per the "both" plan)

1. Make hit detection host-authoritative: client sends "I pressed bump" (already
   effectively local input, needs an RPC), host resolves the actual stagger/downed/seal
   via the existing state machine, then replicates the *result* (already partially
   covered since `state` is synced — but the trigger/timing needs an RPC path, not just
   relying on local Area3D overlap on every peer independently).
2. Network `RoundManager`/`MatchManager` — host computes round/match state, clients
   read-only display it (HUD already just reads from the autoloads, so once those are
   networked the HUD should need little to no change).
3. Only after 1v1 combat feels right networked: revisit real 2v2 team assignment
   (replacing the current "alternate by join order" placeholder) and Option A vs B.

## Repo state

Pushed to `main`. Repo's canonical location is now `DOST-GameDEV/DOST-GameDev` (old
`Hanxavl/DOST-GameDev` remote still auto-redirects for now).
