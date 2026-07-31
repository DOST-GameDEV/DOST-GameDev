# TUMBANG PRESO 🥫🩴

A **2v2 LAN arena brawler** built on the Filipino street game *tumbang preso*, for the
**Gear Up NCR — Esports Game Dev Challenge**.

Each team is **one Person and one living object**. The defending side fields a **Lata** (tin can)
that must stay standing on its base circle; the attacking side fields a **Tsinelas** (rubber
slipper). All four units are player-controlled and mobile — the Person carries the slipper, charges
a throw and launches it at the guarded can, then scrambles to retrieve it while the *taya*
body-blocks and charges a bump to knock the carrier off their slipper. The objects fight too: the
lata smashes the ground and dashes, and the slipper can charge a jump and dive onto the can to take
a round by itself.

Roles swap every round. Best of five.

**Engine:** Godot 4.7 (Forward+, GDScript) · **Theme:** Philippine Games and Sports — one theme, taken
all the way down, not two taken halfway · **Format:** 2v2 LAN

> **Circular Economy was dropped as a secondary theme on 2026-07-31**, deliberately. The rubric scores
> *"effectively communicates or raises awareness about the chosen theme's goals, values, or lessons"* —
> and nothing in the game ever said it. A theme claimed in a README and absent from the screen is worth
> less than one theme expressed completely, and it invited a bolt-on that would have read as a lecture.
> Philippine Games and Sports is the entry's whole answer.

---

## Where the project stands

The LAN loop hosts, joins, spawns, syncs late joiners, runs a 90-second round, decides a winner,
swaps roles and completes a Bo5. Two maps are built (**Eskinita**, **Bayan Plaza**), audio is in
(SFX + ambience beds, all synthesised in-repo), and there is a themed main menu, a lobby with
ready-up, character select, settings, pause, a match-result screen, a role-swap card, nameplates
and a HUD.

**The current work is the objects overhaul**, on `feature/objects-overhaul-v2`: the defender's
instant-win tap-out is gone and replaced by a charged bump meter and stamina; the lata is won and
lost by an out-of-circle countdown instead of a knockdown; and both objects got their own abilities.
Most of it is written and very little of it is measured.

**👉 [`docs/Agent_Prompts.md`](docs/Agent_Prompts.md) is the single place progress is tracked.**
**Eleven** `build xxx` lanes, run one at a time in board order. The first unticked box in a lane's
section is the next thing to do. ⚠️ **The section number is not the run order** — four lanes were
added on 2026-07-31 and took the next free section numbers rather than being inserted, because the
board cross-references sections by number everywhere. Run by the `Run` column of § EXECUTION ORDER.

**🔊 `build voice` runs next, at position 3, and it is the one lane that blocks on people rather
than on code** — the team is recording Filipino voice lines and composing a five-track chiptune
OST, and that takes calendar time nothing else on the board can compress. **[`docs/HUMAN.md`](docs/HUMAN.md)
is the brief: what to record, how, and in what format.**

---

## Docs — five files, and that is the budget

| | |
|---|---|
| **[`docs/Agent_Prompts.md`](docs/Agent_Prompts.md)** | **Start here.** The pipeline, the execution order, the checklist and the log. The only place a box is ticked. |
| [`docs/Design.md`](docs/Design.md) | The rules and every tunable number. The single source of truth for balance. |
| [`docs/Art_Direction.md`](docs/Art_Direction.md) | Colour law, scale law, arena geometry, model and kit rules. |
| **[`docs/HUMAN.md`](docs/HUMAN.md)** | **For teammates with a microphone.** What to record and compose, and the format to deliver it in. The only doc here not addressed to whoever is building. |
| [`docs/README.md`](docs/README.md) | Index, standing rules, and the machine notes for running Godot here. |

Code comments still name documents that no longer exist (`Dev_Plan.md`, `Handoff.md`,
`Checklist.md`, `Roadmap.md`). Read those as "there was a reason, it is now in `Design.md`".

---

## Running it

Open `project.godot` in **Godot 4.7** and press **F5** → **Start** → **Local Match** for the
single-PC flow: **one human unit, three bots**, with a switcher for which unit is yours.

| Key | Action | |
|---|---|---|
| **WASD** | move | |
| **Mouse** | look, and aim the throw | |
| **Space** | `jump` | as a loose tsinelas, **hold** to charge the self-launch |
| **Shift** | `sprint` | costs stamina |
| **Ctrl** | `guard_dash` | Can-Dash · Flick Dash |
| **F** | `bump` | Person's instant melee · **Can-Smash** as a lata · **Ground Smash** as an airborne tsinelas · press to self-right when downed |
| **E** *or* **LMB** | `grab` | pick up the tsinelas · **hold** beside your own downed lata for the reset channel |
| **Q** *or* **LMB / RMB** | `special_ability` | charge the throw while carrying · **charge the bump** empty-handed · roster special as a lata |
| **R** | `ready_up` | before the first round |
| **Esc** | pause | |

- **Tab / F1–F4 / F6** — the debug switcher, to choose which of the four units you drive
- All bindings are rebindable in **Settings**

> ⚠️ **This table is the `[input]` block of `project.godot`, read on 2026-07-31, and three earlier
> claims here were wrong.** **There is no P2 binding set** — the file defines exactly eleven
> actions and not one of them is per-player. 🧑 2026-07-31: *"theres no p2 at all — only one
> settings bcz back then ppl could play on one pc but now its local multiplayer not same pc."*
> **The second seat was removed when the project moved from same-PC to LAN**, and the
> "arrows / Enter / End / Right Shift" row simply outlived it. The switcher's **second slot went
> with it** (`debug_player_switcher.gd`: *"Shift is no longer read at all… solo is now the only
> mode"*), which retires `Shift+F1–F4` and `F5`. And **Space is `jump`, not `bump`** — bump moved
> to `F` on 2026-07-30 after `input_probe` caught one press doing both.
>
> **Two people on one keyboard is not a supported mode and is not coming back.** Two players means
> two machines on a LAN. Rebinding in **Settings** is therefore one profile, not two, and that is
> the design rather than a limitation.
>
> ⚠️ **`LMB` is bound to BOTH `grab` and `special_ability`** in `project.godot`. That is recorded
> here as an observation, not a decision — one left-click can fire both actions. `scripts/ui/**`
> is 🖥️ `build ux`'s and the conflict is filed on its checklist.

**LAN:** **Host Game** on one machine, **Join** with the host's local IP on the others. To test on
one PC, use **Debug → Run Multiple Instances → 2** with per-instance arguments `--host` and
`--join=127.0.0.1`.

> ⚠️ **Local Match and the debug switcher are a test harness and are stripped before submission.**
> Do not invest polish in them.

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
   git config user.name "M4tyu633" && git config user.email "matthewtlabrador@gmail.com"
   ```
   **Every commit is authored by that name and nobody else.** No `Co-Authored-By:` trailer, no
   "Generated with", no 🤖 line, no model or tool named in the message. This is submitted as one
   person's work and the history has to read that way.
5. **Branch from `feature/objects-overhaul-v2`** for overhaul work; `integration` is the stable
   line. Never from `main`. One lane at a time, one writer per file — the ownership table is in
   `docs/Agent_Prompts.md` § PATHS.

---

## Project structure

```
assets/            characters, models, ui, audio, maps — binaries via Git LFS
                   models/     .obj + .mtl, emitted by tools/models/generate_all.gd — text, NOT LFS
scenes/
  characters/      CharacterBase.tscn, CameraRig.tscn, visuals/
  maps/            Eskinita.tscn, BayanPlaza.tscn — emitted wholesale by tools/maps/build_*.py
  ui/              MainMenu, HUD, MatchSetup, MultiplayerSetup, CharacterSelect, SettingsPanel, …
  main/            Main.tscn — the match scene
scripts/
  characters/      character_base, character_visual, carriable, carrier, hitbox, hurtbox, …
  systems/         round_manager, match_manager, network_manager, spectator_camera, ai_controller, …
  abilities/       ability_base.gd + one script per special + resources/*.tres
  ui/              hud, main_menu, match_setup, character_select, ui_theme, …
tools/             non-shipping: model generator, map builders, probes, render harnesses
docs/              four files — see the table above
```

---

## Three things this project is strict about

**Verify before you claim it works.** The legend is `[x]` built *and verified* — say by what —
`[~]` built but unverified — say what specifically is unverified — and `[ ]` not started. This
codebase has a documented history of code that was written, reviewed and never run.

**A feature a player cannot reach from the menus does not exist.** Wire the entry point in the
same commit as the feature. A command-line flag is not an entry point. See the reachability rule
in `docs/Agent_Prompts.md`.

**The camera directive is not negotiable.** Person → first person, always. Prop (Can or Tsinelas) →
third person, always. Derived from `is_person` at `_ready()`, with no toggle, no export and no
per-map exception. Any doc implying otherwise is stale — fix the doc.
