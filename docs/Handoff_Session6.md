# Handoff — Dev Session 6

Picked up straight from the Session 5 networking pass. This session: networked combat
(item 1), real 2v2 team assignment (item 3), a main menu / lobby (item 7), and the
smaller loose ends (item 8) from the Session 5 "suggested next session" list.

---

## What's new

### Host-authoritative combat — `character_base.gd`, `hitbox.gd`
- `Hitbox._on_area_entered` still runs on every peer (Area3D overlap is detected
  locally from replicated positions), but only the **host** now acts on it. Clients
  skip resolution entirely and just wait for the resulting `state` change to arrive
  via the existing `MultiplayerSynchronizer`.
- Since state authority for a character stays with its own owning peer, the host
  doesn't set `state` directly — it RPCs the target's owning peer
  (`CharacterBase._apply_hit_result`) with what happened (`stagger` / `downed` /
  `seal`), and that peer applies it locally exactly like the old local-only flow.
- The bump-active window (`_bump_active_time_left`) now decays on every peer, and a
  client RPCs the host (`_rpc_notify_bump`) the instant its own bump window opens, so
  the host has an accurate copy to gate hits against.
- **Still not validated** — no anti-cheat, no rollback, trusts whatever the owning
  peer reports about its own input. Fine for LAN prototyping.

### Networked RoundManager / MatchManager — `round_manager.gd`, `match_manager.gd`
- Both are host-authoritative now when networked: the host runs the real
  timer/round/match logic, clients mirror it via RPC (`_sync_state`,
  `_sync_round_started`, `_sync_match_won`) purely for HUD display.
- `MatchManager.begin_next_round()` is now actually called for networked games too
  (`main.gd::_start_hosting`) — previously it was only wired for the local single-PC
  flow, so a networked match's timer/round state never started at all.

### Real 2v2 team assignment — `main.gd`
- Replaced the "alternate Can/Tsinelas by join order" 1v1 smoke-test placeholder.
  First two peers to connect are fixed as Team A, next two as Team B, for the whole
  match (GDD: 2v2, whole team swaps Attacker/Defender each round, not per-player).
- On every `MatchManager.round_started`, every peer independently recomputes
  `is_can` for each spawned character from `(character's fixed team) ==
  MatchManager.team_a_is_can` — no RPC needed, since team assignment and
  `team_a_is_can` are both already known identically on every peer.
- `RoundManager`'s tracked-Cans list gets rebuilt each round to match whichever two
  characters are actually Cans that round.

### Main menu / lobby — `scenes/ui/MainMenu.tscn`, `main_menu.gd`, `game_launch.gd`
- New entry scene (`project.godot`'s `run/main_scene`), titled **TUMBANG PRESO**. A
  "Start" button reveals Local / Host / Join options plus a game-mode picker.
- Hosting/joining from the menu hands off to `Main.tscn` via a new `GameLaunch`
  autoload (`pending_action`, `pending_join_address`) instead of command-line args.
  The old `--host` / `--join=<ip>` flow (Debug > Run Multiple Instances) still works
  standalone — `main.gd` checks `GameLaunch` first, falls back to cmdline args.
- Game-mode picker sets `GameLaunch.game_mode` (`OPTION_A` / `OPTION_B`) — see "Known
  gaps" below, this is a real switch but Option A has no rules behind it yet.

### Small loose ends (item 8)
- HUD's `DownedFlash` now actually triggers, wired in `main.gd` to whichever
  character is locally-controlled and a Can (both local-test and networked flows).
- Quick Stand is a real once-per-round charge now (`AbilityBase.once_per_round`,
  `reset_round_charge()` called from `CharacterBase.reset_for_new_round()`) instead
  of approximating it with a 90s cooldown.

---

## Known gaps / not yet done

- **Option A (health/dents) still has zero rules implemented.** The menu lets you
  pick it (`GameLaunch.game_mode`), but `round_manager.gd`'s Option B testbed is what
  actually runs regardless of the selection — see the comment there for where to hook
  in real Option A logic.
- **No movement smoothing/interpolation** on remote characters — still snaps.
- **Match start is still "host starts hosting = match begins"** — no ready-up /
  waiting-for-4-players lobby state. Fine for a 1v1 or ad-hoc smoke test, not real
  tournament flow.
- **A player who joins mid-round** gets correct initial team/role, but isn't added to
  `RoundManager`'s tracked-Cans list until the *next* round starts.
- **Combat networking is unvalidated** — host trusts client-reported bump timing, no
  anti-cheat.
- Items 4–6 from the Session 5 list are still untouched: human playtesting for feel,
  real art, and the two map scenes (Eskinita / Bayan Plaza).
