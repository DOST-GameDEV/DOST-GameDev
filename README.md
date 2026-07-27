# TUMBANG PRESO 🥫🩴

A **2v2 LAN arena brawler** built on the Filipino street game *tumbang preso*, for the
**Gear Up NCR — Esports Game Dev Challenge**.

Each team is **one Person and one living object**. The defending side fields a **Lata** (tin can)
standing in its base circle; the attacking side fields a **Tsinelas** (rubber slipper). Both units
on a team are player-controlled and mobile — the Person carries the slipper, charges a throw, and
launches it at the guarded can, then has to scramble out and retrieve it before the *taya* tags
them. The taya, meanwhile, body-blocks, tags carriers into dropping their slipper, and holds the
**reset channel** to stand their knocked-down lata back up.

Roles swap every round. Best of five.

**Engine:** Godot 4.7 (Forward+, GDScript) · **Theme:** Philippine Games and Sports, with Circular
Economy as a secondary angle — the whole premise is reusing everyday objects as sports equipment ·
**Format:** 2v2 LAN

---

## Where the project actually stands

*Audited 2026-07-27 against the running build, not against the previous pass's checkboxes.*

**The systems are in good shape and the presentation is not.** The LAN loop hosts, joins, spawns,
syncs late joiners, runs a 90-second round, decides a winner, swaps roles and completes a Bo5.
There is a themed main menu, a lobby with ready-up, settings, a pause menu, a match-result screen,
a role-swap intermission card, in-world nameplates, and a HUD matching its own design spec.

What is missing is the world and the proof:

| | |
|---|---|
| **Maps** | None. One 40×40 grey box with **invisible** boundary colliders, no skybox, no field markings. The single biggest gap. |
| **Audio** | **Nothing.** Not one `AudioStreamPlayer` in the repo. |
| **The core mechanic** | Carry / charge / throw / retrieve / reset-channel is code-complete and **has never been played by a human.** Every tuning number in it is a first guess. |
| **Character select** | Not built — so the three Tsinelas throw identities are currently unreachable in game. |
| **Submission package** | Not started. Trailer, demo video, Forms 01–03, synopsis. |

**👉 [`docs/Checklist.md`](docs/Checklist.md) is the single place progress is tracked.** One
ordered list from here to a submitted entry. Find the first unchecked box that is not marked 🧑 or
⛔ and that is the next thing to do.

---

## Docs

| | |
|---|---|
| **[`docs/Checklist.md`](docs/Checklist.md)** | **Start here.** The ordered master plan and the only status board. |
| [`docs/Handoff.md`](docs/Handoff.md) | Session log, frozen system context and execution protocol, open bug ledger, task detail with model routing. |
| [`docs/Dev_Plan.md`](docs/Dev_Plan.md) | Standing directives (these override the GDD), architecture, camera system, UI system, working agreements, Godot setup. |
| [`docs/Tumbang_Preso_2v2_GDD.md`](docs/Tumbang_Preso_2v2_GDD.md) | Design source of truth — **read its supersession banner first.** |
| [`docs/Bug_Ledger.md`](docs/Bug_Ledger.md) | Forensic archive of closed bugs. Preserved deliberately. |
| [`docs/Concurrency_Protocol.md`](docs/Concurrency_Protocol.md) | How several agents work this repo at once without breaking it. |
| [`docs/Agent_Prompts.md`](docs/Agent_Prompts.md) | Paste-ready opening prompts, one per lane. |
| `docs/*_Agent_Brief.md` | Self-contained per-workstream briefs — scope, traps, acceptance. |

---

## Running it

Open `project.godot` in **Godot 4.7** and press **F5** → **Start** → **Local Match** for the
single-PC four-unit flow.

- **P1** — WASD, Space bump, Shift guard/dash, Q special
- **P2** — arrows, Enter bump, End guard/dash, Right Shift special
- **Tab / F1–F4 / Shift+F1–F4 / F5 / F6** — the debug switcher, to drive any of the four units
- All bindings are rebindable in **Settings**

**LAN:** **Host Game** on one machine, **Join** with the host's local IP on the others. To test on
one PC, use **Debug → Run Multiple Instances → 2** with per-instance arguments `--host` and
`--join=127.0.0.1`.

> ⚠️ **Local Match and the debug switcher are a test harness and are stripped before submission**
> (`Dev_Plan.md` §0.2, removal checklist in §3.5.5). Do not invest polish in them.

### Verifying visual work

`--headless` renders nothing and `--quit` never executes a single frame of `_process()`. Between
them they missed four live bugs. To actually look at the game:

```bash
godot --path . tools/render_probe.tscn --quit-after 400 --resolution 1280x720 -- match /tmp/
```

---

## Setup

1. **`git lfs install` FIRST, before you clone.** Thirteen binaries are LFS-tracked. Cloning
   without LFS makes every character invisible, and it does not present as an LFS problem — it
   presents as broken art. `git lfs install && git lfs pull` fixes it in place.
2. Install [Godot 4.7](https://godotengine.org/download), **Standard** build (not .NET — this is a
   GDScript project).
3. Clone, open `project.godot`. Expect a slow first open while Godot rebuilds `.godot/`.
4. Set your git identity for this repo — it is configured `--local` and does **not** travel with a
   fresh clone:
   ```bash
   git config user.name "M4tyu633"
   git config user.email "matthewtlabrador@gmail.com"
   ```
5. One branch per feature off `main`. Give a heads-up before editing a shared scene
   (`Main.tscn`, `CharacterBase.tscn`) — or use the lock protocol in
   [`docs/Concurrency_Protocol.md`](docs/Concurrency_Protocol.md) if more than one agent is
   working.

Full walkthrough, including moving to another machine: `Dev_Plan.md` §7.

---

## Project structure

```
assets/            characters, models, ui, audio, maps — binaries via Git LFS
                   models/     .obj + .mtl, emitted by tools/models/generate_all.gd — text, NOT LFS
scenes/
  characters/      CharacterBase.tscn, CameraRig.tscn, visuals/
  maps/            (Eskinita.tscn, BayanPlaza.tscn — not built yet)
  ui/              MainMenu, HUD, Lobby, SettingsPanel, MatchResult, RoleSwapCard, YouCard
  main/            Main.tscn — the match scene
scripts/
  characters/      character_base, character_visual, carriable, carrier, hitbox, hurtbox, …
  systems/         round_manager, match_manager, network_manager, camera_rig, settings_manager, …
  abilities/       ability_base.gd + one script per special + resources/*.tres
  ui/              hud, main_menu, lobby, match_result, ui_theme, …
tools/             non-shipping: model generator, render_probe, theme regeneration, broadcast cam
docs/
```

---

## Two things this project is strict about

**Verify before you claim it works.** The status legend is `[x]` built *and verified*, `[~]` built
but unverified — say what specifically is unverified — and `[ ]` not started. This codebase has a
documented history of code that was written, reviewed and never run; three separate passes found
docs claiming things the code contradicted, in both directions.

**The camera directive is not negotiable.** Person → first person, always. Prop (Can or Tsinelas) →
third person, always. Derived from `is_person` at `_ready()`, with no toggle, no export and no
per-map exception. Any doc implying otherwise is stale — fix the doc.
