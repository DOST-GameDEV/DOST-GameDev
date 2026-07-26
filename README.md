# Tumbang Laro: Isang Laban 🥫🩴

2v2 arena brawler for **Gear Up NCR — Esports Game Dev Challenge**. No human characters —
you play as the Can or the Tsinelas. Two Cans defend their turf while two Tsinelas try to
knock them flat; teams swap Attacker/Defender role each round, Best of 5.

**Engine:** Godot 4.7 (Forward+, GDScript) · **Theme:** Philippine Games and Sports · **Format:** 2v2 LAN

## Docs

- [`docs/Tumbang_Preso_2v2_GDD.md`](docs/Tumbang_Preso_2v2_GDD.md) — game design doc: pitch,
  locked decisions, roster, maps, esports/spectator layer, submission checklist.
- [`docs/Dev_Plan_and_Godot_Setup.md`](docs/Dev_Plan_and_Godot_Setup.md) — coding approach,
  build order, project structure, Git/GitHub workflow, Godot setup walkthrough.

## Build order (see dev plan for details)

1. **Single-player prototype** — one Can + one Tsinelas moving/bumping/using abilities,
   no networking yet. *(scaffolded — see `scenes/main/Main.tscn`)*
2. **Round/match logic**, still single-player — timer, Downed state, role swap, Bo5.
   *(scaffolded — see `scripts/systems/round_manager.gd`, `match_manager.gd`)*
3. **Networking** — wire the working loop over LAN (`ENetMultiplayerPeer`).
   *(skeleton — see `scripts/systems/network_manager.gd`)*
4. **Maps + hazards** — Eskinita, Bayan Plaza.
5. **UI/HUD, juice, audio.**
6. **Polish + record trailer/demo footage.**

Whoever's free earliest: open the project in Godot, hit F5 on `scenes/main/Main.tscn`, and
start feeling out movement — that's the thing everything else depends on.

## Project structure

```
tumbang-laro/
├── assets/            (characters, maps, audio, ui — binary, put through Git LFS)
├── scenes/            (characters, maps, ui, main)
├── scripts/
│   ├── characters/    (character_base.gd — shared Move/Bump/Guard-Dash for all 6 chars)
│   ├── systems/       (round_manager.gd, match_manager.gd, network_manager.gd)
│   └── abilities/     (ability_base.gd — extend per character special)
├── docs/
└── project.godot
```

## Setup

1. Install [Godot 4.7](https://godotengine.org/download), Standard build.
2. Clone this repo, open `project.godot` in Godot.
3. Recommended: `git lfs install && git lfs track "*.glb" "*.png" "*.wav" "*.mp3"` before
   adding any art/audio assets — binary files don't merge in Git.
4. One branch per feature off `main` (`feature/can-movement`, `feature/networking`, ...).
   Give a heads-up before editing shared scenes at the same time.

## Status

See [`docs/Handoff_Session2.md`](docs/Handoff_Session2.md) for the latest detailed handoff.

- [x] Repo + project scaffold, folder structure, `.gitignore`
- [x] `CharacterBase` scene/script (shared movement) + `AbilityBase` resource pattern
- [x] Bump hit detection (`Hitbox`/`Hurtbox`, press-to-bump active window)
- [x] Downed/Sealed state machine (self-right window + seal), option-agnostic by design
- [x] `RoundManager` / `MatchManager` / `NetworkManager` registered as autoloads
- [x] One ability end-to-end (Sardinas' Quick Stand) proving the ability pattern
- [x] Remaining 5 character abilities (Shatter Trap, Spin Guard, Bagsak Bomb, Bakya Bash, Flick Dash)
- [x] Basic HUD (timer, Bo5 score, round, role) wired into `Main.tscn`
- [x] Option B round-win check, testable (`RoundManager.register_can`, see handoff doc)
- [ ] Pick Option A vs Option B for real (Option B has a testbed now; Option A doesn't yet)
- [ ] Maps: Eskinita, Bayan Plaza
- [ ] LAN networking wired up + tested on real devices
- [ ] Downed-state visual flash actually triggered in-game (hook exists in HUD)
- [ ] Audio
- [ ] Trailer + demo recording
