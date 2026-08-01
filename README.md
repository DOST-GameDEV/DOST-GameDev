# TUMBANG PRESO 🥫🩴

A **4-player LAN party game** built on the Filipino street game *tumbang preso*, for the
**Gear Up NCR — Esports Game Dev Challenge**.

One player is the **taya** (defender), locked inside a chalk box guarding a **lata** (tin can).
The other three are **attackers**, throwing **tsinelas** (rubber slippers) at it from outside the
box. Throwing is safe and free — the tension is the **retrieval**: the slipper lands inside the
taya's box, and the moment you pick it up you can be tagged. Knock the lata over and the taya has
to spend 1.5 seconds standing it back up, which is the one window they cannot defend.

Two rules make that trade sharper than it looks, and both changed on 2026-08-01:

* **Any attacker may pick up any loose slipper.** You start a round with your own and an arrow
  points at it, but a rival's is fair game if they leave it lying in the open. Ownership is now a
  label, not a lock (`Design.md` §5.2).
* **Neither the punch nor the lunge can tag anybody while the lata is lying over.** Standing it
  back up is what re-arms the taya's only scoring verb — so the reset is not tidying, it is the
  taya loading their weapon. And a slipper the taya body-blocks now drops **2.5 m** from them
  rather than being kicked clear of the court, which is what puts the retrieval back inside
  tagging range (`Design.md` §6.2).

**Four rounds of 90 seconds. The taya role rotates clockwise, so everyone plays it exactly once.**
Scores are cumulative and personal; highest total after round 4 takes the match.

**Engine:** Godot 4.7 (Forward+, GDScript) · **Theme:** Philippine Games and Sports — one theme,
taken all the way down, not two taken halfway · **Format:** 4-player LAN

> **Circular Economy was dropped as a secondary theme on 2026-07-31**, deliberately. The rubric scores
> *"effectively communicates or raises awareness about the chosen theme's goals, values, or lessons"* —
> and nothing in the game ever said it. A theme claimed in a README and absent from the screen is worth
> less than one theme expressed completely, and it invited a bolt-on that would have read as a lecture.
> Philippine Games and Sports is the entry's whole answer.

---

## Where the project stands

The LAN loop hosts, joins, spawns, syncs late joiners, runs a 90-second round, rotates the taya and
completes a four-round match. Two maps are built (**Eskinita**, **Bayan Plaza**); the lata and the
tsinelas have four skins each with their own meshes; **two of five OST tracks are in and playing**,
written by the team, over SFX and ambience beds synthesised in-repo; and there is a themed main
menu, a lobby with ready-up, character select, settings, pause, a match-result screen, a credits
screen, a role-swap card, nameplates, a spectator camera and a HUD. **Single Player is three bots
that actually play** — they retrieve, take an angle, throw at real power, body-block, chase and
tag, at three difficulties that measure apart.

**Still missing:** every voice line (`docs/HUMAN.md` is the brief), three of the five OST tracks,
the team's own SFX, and a balance pass over the numbers.

**The 2v2 design was removed on 2026-07-31**, on branch `HARRYDAKS`. Until then the lata and the
tsinelas were themselves playable characters, with eight abilities between them, dashes, shockwaves
and a self-launch — *"too complicated and far from tumbang preso"*. They are props now, the game is
four players free-for-all, and the rules are the ones the street game actually has: throw, retrieve,
tag, reset. `docs/Design.md` §12 lists everything that went and why.

**👉 [`docs/Agent_Prompts.md`](docs/Agent_Prompts.md) is the single place progress is tracked.**
**Five** `build xxx` lanes, run one at a time in board order. The first unticked box in a lane's
section is the next thing to do. Five and not more is deliberate: the board this replaced had
eleven and never finished them, and a lane is a whole session with a cold start — so the count is
a schedule, not a taxonomy.

| | lane | state |
|---|---|---|
| 1 | 🎨 `build model` | **closed** — the props, both maps, the play area |
| 2 | 🖥️ `build ui` | **closed** — HUD, tutorial, lobby, result screen, credits |
| 3 | 🤖 `build ai` | **closed 2026-08-01** — the bots play, and three difficulties measure apart |
| 4 | 🔊 `build sound` | **blocked on people, not on code.** Every hook is wired and most are silent |
| 5 | ⚖️ `build fair` | **last, by human call** — *"we will do fairness last"*, because *"the game already feels fair"* |

**🔊 `build sound` is the one lane that blocks on people rather than on code** — the team is
recording Filipino voice lines and writing a five-track OST, and that takes calendar time nothing
else on the board can compress. It runs whenever files land rather than at a fixed position.
**[`docs/HUMAN.md`](docs/HUMAN.md) is the brief: what to record, how, and in what format.**

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
| **Space** | `jump` | |
| **Shift** | `sprint` | costs stamina |
| **Ctrl** | `spectator_down` | descend, spectator camera only |
| **E** *or* **LMB** | `grab` | **tap** to pick up a slipper · **tap** with nothing to pick up to shove another attacker · **hold** as the taya, in the lata’s ring, to stand it back up · **hold 0.5 s** as the taya anywhere else to charge a **lunge** |
| **Q** *or* **LMB** | `special_ability` | attacker: hold to charge a throw, release to throw. **Taya: tap to PUNCH** — a quick close-range tag, 1.7 m in a forward arc, no wind-up. ⚠️ Refused while the lata is down |
| **RMB** | `lunge` | **taya only** — hold 0.5 s to charge, release to dash and tag anyone within 1.3 m of the path. Same verb as hold-E, kept as a second binding. ⚠️ Also refused while the lata is down. It is a GAP-CLOSER: inside 1.7 m the punch reaches further and is instant |
| **R** | `ready_up` | before the first round |
| **H** | `clean_feed` | hides the HUD, for recording |
| **Esc** | pause | |

- **Tab / F1–F4 / F6** — the debug switcher, to choose which of the four players you drive
- All bindings are rebindable in **Settings**

> ⚠️ **E IS CONTEXTUAL AND THAT IS DELIBERATE.** The GDD gives it three jobs — pick up, shove,
> reset the lata. Rather than invent two more keybinds for a game whose whole brief is "simpler",
> the press resolves against what is actually in front of you: `carrier.gd` gets first refusal, and
> only a press that neither the pickup nor the reset channel consumed reaches the shove.
>
> ⚠️ **`bump` and `guard_dash` were DELETED from `project.godot` on 2026-07-31** along with the
> bump meter, Can-Dash, Flick Dash, Can-Smash and Ground Smash. The spectator camera’s descend
> key kept Ctrl but has its own action now (`spectator_down`) rather than borrowing a gameplay one.
>
> ⚠️ **THE SHOVE IS A TAP AND THE TAYA HAS A LUNGE, AND THIS TABLE SAID NEITHER.** Both changed
> on 2026-08-01. The shove was a 1.25 s hold and is now a single tap (`SHOVE_CHARGE_TIME` is
> **0.0**, kept rather than deleted because three files read it as a 0..1 ratio). The tag stopped
> being passive — it used to fire every physics frame on adjacency, for no input and no animation
> — and became a charged right-click dash. **`lunge` and `clean_feed` were never added to this
> table at all**, so the one verb the defender scores with was undocumented.
>
> ⚠️ **This table is the `[input]` block of `project.godot`, and several earlier
> claims here were wrong.** **There is no P2 binding set** — the file defines exactly twelve
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
> is 🖥️ `build ui`'s and the conflict is filed on its checklist.

**LAN:** **Host Game** on one machine, **Join** with the host's local IP on the others. To test on
one PC, use **Debug → Run Multiple Instances → 2** with per-instance arguments `--host` and
`--join=127.0.0.1`.

> ⚠️ **Local Match and the debug switcher are a test harness and are stripped before submission.**
> Do not invest polish in them.

### Verifying visual work

`--headless` renders nothing and `--quit` never executes a single frame of `_process()`. Between
them they missed four live bugs. To actually look at the game, run a probe as a `.tscn` with the
**plain** exe:

```bash
godot --path . tools/harrydaks_shot.tscn -- C:/tmp/
```

⚠️ **`tools/render_probe.tscn` is DEAD, and the command that used to be printed here did not
run.** It builds its match by hand out of `team_is_can_side`, `is_can` and `report_round_result()`
— three things the 2026-07-31 pivot deleted — so it cannot boot at all. `harrydaks_shot.tscn`
replaced it: it loads the real `Main.tscn`, starts the round through the same path a human's READY
press takes, saves frames and prints the match state. Rewriting `render_probe` is filed as
`build fair` §2.10.

To watch four bots play a whole match and get numbers out of it:

```bash
godot --path . tools/ai_probe.tscn -- matches=1 scale=6 tier=NORMAL
```

---

## Setup

1. **`git lfs install` FIRST, before you clone.** **176 binaries** are LFS-tracked. Cloning
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
5. **`HANSDAKS-test` is the working line** — branch from it, push to it, and open a branch of your
   own for a lane that will take a while. `integration` is the older stable line and `main` is
   older still; never branch from either. ⚠️ **`feature/objects-overhaul-v2` was named here until
   2026-08-01, and it belongs to the deleted 2v2 design** — anyone who followed this step branched
   off the game this one replaced. One lane at a time, one writer per file — the ownership table
   is `docs/Agent_Prompts.md` §3.

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
  characters/      character_base, character_visual, carrier, character_nameplate
  objects/         lata.gd, slipper.gd — the two props. NOT players; see Design.md §12
  systems/         round_manager, match_manager, network_manager, spectator_camera, ai_controller, …
  ui/              hud, main_menu, match_setup, character_select, credits_panel, ui_theme, …
  main.gd          the match scene's entry point
tools/             non-shipping: model generator, map builders, probes, render harnesses
docs/              five files — see the table above
```

---

## Three things this project is strict about

**Verify before you claim it works.** The legend is `[x]` built *and verified* — say by what —
`[~]` built but unverified — say what specifically is unverified — and `[ ]` not started. This
codebase has a documented history of code that was written, reviewed and never run.

**A feature a player cannot reach from the menus does not exist.** Wire the entry point in the
same commit as the feature. A command-line flag is not an entry point. See the reachability rule
in `docs/Agent_Prompts.md`.

**The camera directive is not negotiable.** A player is a person, and a person is **first person,
always** — no toggle, no export, no per-map exception. ⚠️ This rule used to have a second half
("Prop → third person") and it went with the thing it described: the lata and the tsinelas were
playable characters until 2026-07-31 and are props now, so there is no prop camera to direct. The
spectator camera is the only other view in the game. Any doc implying otherwise is stale — fix
the doc.
