# Tumbang Preso 🥫🩴

2v2 arena brawler for **Gear Up NCR — Esports Game Dev Challenge**. Each team is 2 players:
a Person and their Can (or Slipper). Defending Persons tag attackers while their Can holds
the base; attacking Persons throw their Slipper at the Can to try to knock it flat; teams
swap Attacker/Defender role each round, Best of 5.

**Engine:** Godot 4.7 (Forward+, GDScript) · **Theme:** Philippine Games and Sports · **Format:** 2v2 LAN

## Docs

- [`docs/Tumbang_Preso_2v2_GDD.md`](docs/Tumbang_Preso_2v2_GDD.md) — game design doc: pitch,
  locked decisions, roster, maps, esports/spectator layer, submission checklist.
- [`docs/Dev_Plan.md`](docs/Dev_Plan.md) — build status, architecture, phased build order,
  Git workflow, Godot setup.
- [`docs/Handoff.md`](docs/Handoff.md) — **start here.** What exists, the full bug list, and
  what to do next.

## Running it

Open `project.godot` in **Godot 4.7** and press **F5** → **Start** → **Local Match** for the
single-PC 4-unit flow (P1 = WASD/Space/Q, P2 = arrows/Enter/RShift; rebindable in Settings).

For LAN: **Host Game** on one machine, **Join** with the host's local IP on the others. To
test on one PC, use **Debug → Run Multiple Instances → 2** with per-instance arguments
`--host` and `--join=127.0.0.1`.

> ⚠️ Most of the round-start/ability-replication/friendly-fire bugs that used to block a LAN
> demo are fixed, but several networked-only paths (late joiners learning match state, stable
> team assignment on reconnect) are still open. See `docs/Handoff.md` §3 for the current list.

## Status

| | |
|---|---|
| Core systems (movement, combat, states, round/match, LAN, HUD, menu, settings) | scaffolded, mostly unverified |
| Roster | 6 specials have resources now; character-select UI to pick between them doesn't exist yet |
| Maps, art, audio | not started |
| Submission materials | not started |

Movement, input split, camera, and menus have been playtested. Combat, abilities, rounds,
and every network path have **not** — see [`docs/Handoff.md`](docs/Handoff.md) §3 for the
current bug list and §4 for the order to tackle them.

## Project structure

```
assets/            characters, maps, audio, ui — binary, via Git LFS
scenes/            characters, maps, ui, main
scripts/
  characters/      character_base.gd, hitbox.gd, hurtbox.gd
  systems/         round_manager, match_manager, network_manager, game_launch,
                   settings_manager, arena_camera, hazard_zone
  abilities/       ability_base.gd + one script per special + resources/*.tres
docs/
project.godot
```

## Setup

1. Install [Godot 4.7](https://godotengine.org/download), Standard build (not .NET).
2. Clone this repo, open `project.godot` in Godot.
3. `git lfs install` before adding any art/audio — binary files don't merge in Git.
4. One branch per feature off `main` (`feature/can-movement`, `feature/networking`, …).
   Give a heads-up before editing shared scenes at the same time.
