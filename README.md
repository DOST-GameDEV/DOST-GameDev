# TUMBANG PRESO 🥫🩴

A **4-player game** built on the Filipino street game *tumbang preso*, for the **Gear Up NCR —
Esports Game Dev Challenge**. Godot 4.7, Forward+, GDScript.

This file explains **how the code is put together**. Progress, checklists and what is left to do
live in [`docs/Agent_Prompts.md`](docs/Agent_Prompts.md); balance numbers live in
[`docs/Design.md`](docs/Design.md). Nothing here tracks status, deliberately — that is what went
stale last time.

---

## The game, in the terms the code uses

One player is the **taya** (defender), locked inside a chalk box guarding a **lata** (tin can). The
other three are **attackers**, throwing **tsinelas** (slippers) at it from outside. Throwing is
free; the tension is the **retrieval**, because the slipper lands inside the taya's box and picking
it up is what puts you in tagging range. Knock the lata over and the taya must spend time standing
it back up — the one window they cannot defend.

The shape of a match is fixed in code, not configured:

| | | where |
|---|---|---|
| Players | 4 | `NetworkManagerScript.MAX_PLAYERS` |
| Rounds | 4 — one per player, so everyone is taya exactly once | `MatchManagerScript.ROUNDS` |
| Round length | 90 s | `RoundManagerScript.ROUND_TIME` |

`ROUNDS` is 4 *because* there are four seats and the taya rotates; it is definitional, not a knob.
Scoring is cumulative and personal — highest total after round 4 wins, there is no per-round winner:

| event | points | constant |
|---|---|---|
| Knocking the lata over | +100 | `SCORE_LATA_KNOCKED` |
| Tagging an attacker (taya) | +100 | `SCORE_TAG` |
| Sabotage | +50 | `SCORE_SABOTAGE` |
| Passive defence, per tick, while the lata stands | +10 | `SCORE_DEFENSE_PER_TICK` |

All four are in `scripts/systems/round_manager.gd`. `docs/Design.md` is the source of truth for
balance and a number in code must match it.

---

## How a session moves through the scenes

`project.godot` boots `run/main_scene` = `res://scenes/ui/SplashScreen.tscn`. From there:

```
SplashScreen ─> MainMenu ─> ModeSelect ─┬─> MatchSetup ───────────> Main.tscn
                                        │   (lobby: seats, map, ready-up)
                                        └─> MultiplayerSetup ─> MatchSetup ─> Main.tscn
                                            (host or join)
```

**`MatchSetup` is the lobby and `Main.tscn` is the match.** That split matters more than it looks —
a dedicated server parks in `MatchSetup` precisely so it is joinable rather than already playing
(see `docs/Dedicated_Server_Deployment.md` §2, where booting the wrong scene produces a server that
looks healthy and is silently unjoinable).

`MultiplayerSetup` deliberately **does not open a socket**. It records *what kind* of session was
asked for and where to reach the host; the actual `NetworkManager.host_game()` / `join_game()` call
happens one screen later in `match_setup.gd`, because that is the screen that must be alive to hear
`connection_failed`. Connecting here and then changing scene would leave that signal with no
listener. It is also where a dropped client is bounced back to, carrying a status message.

---

## Autoloads, and the one rule that follows from them

Nine autoloads, declared in `project.godot`:

| autoload | owns |
|---|---|
| `NetworkManager` | ENet peer, host/join, peer ids, seats, lobby leader, dedicated mode |
| `RoundManager` | one round: the timer, the taya, scoring |
| `MatchManager` | one match: cumulative score across the four rounds |
| `LanBeacon` | UDP broadcast discovery — the "games on your LAN" list |
| `ServerQuery` | UDP status protocol for the online pool, and join codes |
| `GameLaunch` | intent carried between screens (join address, spectator, status message) |
| `SettingsManager` | settings, persisted |
| `AudioManager` | music, SFX, UI audio |
| `DebugPlayerSwitcher` | test harness — which of the four units you drive |

**⚠️ Because `RoundManager` and `MatchManager` are autoloads, one process holds exactly one score,
one timer and one round state — so ONE PROCESS IS ONE MATCH.** Nothing here is re-entrant and
nothing should be made so. Eight concurrent lobbies is eight processes on eight ports, not one
process juggling eight matches. Every deployment decision follows from this single fact.

---

## Networking — three protocols, deliberately independent

**ENet (`network_manager.gd`)** carries the game itself. `host_game(port, dedicated)` starts a
server; `dedicated = true` makes it referee *without taking a seat*, so all four seats stay open to
humans and are filled by AI until they arrive. It still owns round logic and still answers
`is_host()`; it simply never enters itself into `connected_peer_ids`. Set by `--dedicated` on the
command line only — there is no menu for it.

**UDP broadcast (`lan_beacon.gd`)** is LAN discovery. Hosts broadcast, the browse screen listens,
and rows appear in GAMES ON YOUR LAN. A click **selects** — it fills the address field and leaves
the press to JOIN. There is no second, hidden way to start a connection.

**UDP unicast (`server_query.gd`)** is the online pool's status protocol and the join-code system.
It runs *beside* ENet, never on top of it, so a build that cannot reach the status ports still plays
exactly as before by typing an address — which is how this game worked first.

Two design choices in `server_query.gd` are worth knowing before touching it:

- **There is no registry.** No master list, no process to keep alive, no single point whose death
  takes online mode down. The pool is a small fixed set of ports on one known address, so a client
  simply asks every one of them and assembles the list itself. A join code is resolved the same
  way — nothing maps codes to servers; the client asks each server what *its* code is and keeps the
  match. The price is that the pool is a compile-time constant, so growing it ships a build.
- **The address comes from the packet, not the payload.** A host cannot reliably know its own
  address — a machine here reports its LAN card, a Hamachi 25.x, a Radmin 26.x and some link-local
  169.254s in no promised order, and a VM is worse. The receiver has no such problem, so replies
  carry only the *port* and the client supplies the host half from the datagram envelope. Anything
  that later "helpfully" puts an address in the payload has put the bug back.

**⚠️ Status ports are game port + 10** (`STATUS_PORT_OFFSET`). ENet owns the game port and a second
socket on it would fight the server for its own datagrams. That +10 spacing is also what bounds the
pool at ten processes — widen the offset before widening the pool.

### Online play needs a server, and ships without one

`ServerQuery.POOL_ADDRESS` is `""` in the repo. That is the honest state for a build with nowhere
to point: `multiplayer_setup.gd` checks it and refuses HOST ONLINE with an explanation rather than
failing obscurely. **LAN play is unaffected and always works.**

To bring online up you need an address reachable by the players, then set that constant — see
[`docs/Dedicated_Server_Deployment.md`](docs/Dedicated_Server_Deployment.md), which covers the
launch command, both firewalls, the architecture trap and what it costs. To exercise the whole path
with no server at all, override it for one run:

```bash
godot --path . -- --pool=127.0.0.1
```

…with one or more lobbies running locally:

```bash
godot --headless --path . res://scenes/ui/MatchSetup.tscn -- --dedicated --port=8910
```

`tools/server/lobby-pool.ps1` (Windows) and `lobby-pool.sh` (Linux) start, stop and inspect a whole
pool. **⚠️ The scene path is required and `--` is required** — without the scene, `--dedicated` is
never parsed, and the process runs, uses normal memory, logs nothing and never binds its port.

---

## Code layout

```
assets/            characters, models, ui, audio, maps — 187 binaries via Git LFS
                   models/     .obj + .mtl emitted by tools/models/generate_all.gd — text, NOT LFS
scenes/
  characters/      CharacterBase.tscn, CameraRig.tscn, visuals/
  maps/            Eskinita.tscn, BayanPlaza.tscn — emitted wholesale by tools/maps/build_*.py
  ui/              SplashScreen, MainMenu, ModeSelect, MultiplayerSetup, MatchSetup,
                   CharacterSelect, HUD, MatchResult, SettingsPanel, Tutorial, CreditsPanel, …
  main/            Main.tscn — the match scene
scripts/
  characters/      character_base, character_visual, carrier, character_nameplate
  objects/         lata.gd, slipper.gd — props, NOT players (Design.md §12)
  systems/         the nine autoloads, plus camera_rig, ai_controller, spectator_camera,
                   character_roster, trajectory_preview, hazard_zone, kill_plane, env_toon_pass
  ui/              one script per UI scene, plus ui_theme.gd and arrow_button.gd
  main.gd          the match scene's entry point
tools/             non-shipping: model generator, map builders, probes, shot harnesses,
                   server/ — the lobby pool scripts and a systemd unit
docs/              six files — see below
```

`ArrowButton` is the pennant control every menu uses. It is a `Button` with the artwork behind it
and a real `Label` on top rather than the button's own text, so the caption can be rotated to follow
the pennant's slant. Hover and press audio is hooked **there**, once, for the whole front end;
non-pennant controls (the wood BACK buttons, seat rows, arrows) carry their own connections.

---

## Running it

Open `project.godot` in **Godot 4.7** (Standard, not .NET) and press **F5**.

| Key | Action | |
|---|---|---|
| **WASD** | move | |
| **Mouse** | look, and aim the throw | |
| **Space** | `jump` | |
| **Shift** | `sprint` | costs stamina |
| **Ctrl** | `spectator_down` | descend, spectator camera only |
| **E** *or* **LMB** | `grab` | **tap** to pick up a slipper · **tap** with nothing to grab to shove an attacker · **hold** as taya in the lata's ring to stand it back up · **hold 0.5 s** as taya elsewhere to charge a lunge |
| **Q** *or* **LMB** | `special_ability` | attacker: hold to charge a throw, release to throw. Taya: tap to **punch** — instant close-range tag |
| **RMB** | `lunge` | taya only — hold to charge, release to dash and tag along the path. A gap-closer; inside punch range the punch is faster |
| **R** | `ready_up` | before the first round |
| **H** | `clean_feed` | hides the HUD, for recording |
| **Esc** | pause | |

Those are the twelve actions in `project.godot`'s `[input]` block, and **none of them is
per-player** — there is no P2 binding set. Two people on one keyboard is not a supported mode:
two players means two machines. Rebinding in **Settings** is therefore one profile, not two.

> **⚠️ `E` is contextual and that is deliberate.** It has three jobs — pick up, shove, reset the
> lata. Rather than invent keybinds for a game whose brief is "simpler", the press resolves against
> what is in front of you: `carrier.gd` gets first refusal, and only a press neither the pickup nor
> the reset channel consumed reaches the shove.
>
> **⚠️ `LMB` is bound to both `grab` and `special_ability`.** Recorded as an observation, not a
> decision — one left-click can fire both.

**Multiplayer:** HOST GAME (LAN) on one machine; the others JOIN with the host's address, or pick it
out of the LAN list. A bare address falls back to port 8910; `<ip>:<port>` reaches a specific lobby.

### Looking at the game

**`--headless` renders nothing and `--quit` never runs a frame of `_process()`.** Between them they
missed four live bugs. To actually see something, run a probe as a `.tscn` with the **plain** exe:

```bash
godot --path . tools/harrydaks_shot.tscn -- C:/tmp/
```

`tools/ui/*_shot.tscn` do the same for individual screens, and several print the measurement beside
the picture — `mp_shift_shot` prints the multiplayer screen's status-line clearance, so an overflow
shows up as a negative number rather than as something spotted in a screenshot later.
`tools/ui/mp_click_probe.tscn` answers "is this button actually reachable" by asking the viewport
who receives the click, which is a different question from whether the signal is connected.

---

## Setup

1. **`git lfs install` FIRST, before you clone.** 187 binaries are LFS-tracked. Cloning without LFS
   makes every character invisible, and it does not present as an LFS problem — it presents as
   broken art. `git lfs install && git lfs pull` fixes it in place.
2. Install [Godot 4.7](https://godotengine.org/download), **Standard** build.
3. Clone, open `project.godot`. Expect a slow first open while Godot rebuilds `.godot/`.
4. Set your git identity for this repo — it is `--local` and does not travel with a fresh clone:
   ```bash
   git config user.name "M4tyu633" && git config user.email "matthewtlabrador@gmail.com"
   ```
   **Every commit is authored by that name and nobody else.** No `Co-Authored-By:` trailer, no
   "Generated with", no 🤖 line, no model or tool named in the message. This is submitted as one
   person's work and the history has to read that way.
5. **Keep ONE working copy.** Two clones of this repo on one machine cost a full session once: the
   edits went to one and the editor was running the other, which presents as "my change did nothing"
   and as bugs that cannot be reproduced. For parallel work use `git worktree add .worktrees/<lane>`
   — `.worktrees/` is already gitignored.

---

## Docs — six files

| | |
|---|---|
| **[`docs/Agent_Prompts.md`](docs/Agent_Prompts.md)** | **Start here.** The pipeline, execution order, checklist and log. The only place a box is ticked. |
| [`docs/Design.md`](docs/Design.md) | The rules and every tunable number. Source of truth for balance. |
| [`docs/Art_Direction.md`](docs/Art_Direction.md) | Colour law, scale law, arena geometry, model and kit rules. |
| [`docs/Dedicated_Server_Deployment.md`](docs/Dedicated_Server_Deployment.md) | Standing up the online lobby pool: the launch command, both firewalls, free-tier costs, and the four things that fail silently. |
| **[`docs/HUMAN.md`](docs/HUMAN.md)** | **For teammates with a microphone.** What to record and compose, and in what format. |
| [`docs/README.md`](docs/README.md) | Index, standing rules, and the machine notes for running Godot here. |

Code comments still name documents that no longer exist (`Dev_Plan.md`, `Handoff.md`,
`Checklist.md`, `Roadmap.md`). Read those as "there was a reason, it is now in `Design.md`".

---

## Three things this project is strict about

**Verify before you claim it works.** The legend is `[x]` built *and verified* — say by what —
`[~]` built but unverified — say what specifically is unverified — and `[ ]` not started. This
codebase has a documented history of code that was written, reviewed and never run.

**A feature a player cannot reach from the menus does not exist.** Wire the entry point in the same
commit as the feature. A command-line flag is not an entry point.

**A player is a person, and a person is first person, always** — no toggle, no export, no per-map
exception. The lata and the tsinelas are props, not playable characters, so there is no prop camera
to direct. The spectator camera is the only other view in the game.

---

## The house style, if you are writing here

The codebase documents **why**, at length, in ⚠️-marked comments above the thing being explained —
including what was deleted and the reasoning that killed it. Match it. A comment recording a
decision that was reversed is worth more than one describing code you can already read.
