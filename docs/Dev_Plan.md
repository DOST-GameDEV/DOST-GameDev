# Dev Plan — Tumbang Laro: Isang Laban

Integration and development plan for the Godot 4.7 build. Written against the code that is
actually in this repo, not against intent. Design source of truth is
[`Tumbang_Preso_2v2_GDD.md`](Tumbang_Preso_2v2_GDD.md); current state, known bugs, and the
"pick this up next" list are in [`Handoff.md`](Handoff.md).

**Engine:** Godot 4.7, Forward+, GDScript · **Target:** 4-player LAN (2v2), Bo5 · **Deliverable:** playable demo + 1–2 min trailer + 3–5 min gameplay video

---

## 1. Where the build actually stands

Legend: **[x]** built and working · **[~]** built but broken or unverified · **[ ]** not started

### Core systems

| Area | State | Notes |
|---|---|---|
| Project scaffold, folders, `.gitignore`, LFS attributes | [x] | |
| `CharacterBase` — move, gravity, per-player input map | [x] | Playtested. No rotation, no dash — see B-05, B-16. |
| `AbilityBase` resource pattern (one scene + a plugged-in Resource per character) | [x] | Pattern is sound and worth keeping. |
| `Hitbox` / `Hurtbox` + press-to-bump active window | [~] | Misses already-overlapping targets (B-08), no team check (B-09). |
| Downed / self-right / Seal state machine | [~] | Any stagger cancels Downed (B-07). |
| Option A — dents (health) round win | [~] | Wired end to end; never human-verified. |
| Option B — Downed → Seal round win | [~] | Wired end to end; broken by B-07. |
| `RoundManager` (90s timer, win reporting) | [~] | Never starts in networked play (B-01). |
| `MatchManager` (Bo5, role swap) | [~] | Host never sees its own signals (B-01); no match reset (B-14). |
| `NetworkManager` (ENet host/join) | [x] | Connects fine. Everything downstream of it is where the trouble is. |
| Networked spawning + movement replication | [~] | Works; snaps (no interpolation), Props spawn with no ability (B-04). |
| Host-authoritative combat | [~] | Correct for Bump; silently drops every special (B-02). |
| HUD (timer, Bo5, round, role, dent counter, downed flash) | [x] | Reads the autoloads directly, needs no per-scene wiring. |
| Main menu + mode picker | [x] | Stale "coming soon" label (B-25); no way back out of a match (B-20). |
| Settings — rebindable, persistent controls | [x] | Offers to rebind an action nothing reads (B-16); allows duplicates (B-22). |
| `ArenaCamera` follow/zoom | [~] | Errors every frame in networked play (B-03). |
| `HazardZone` slow-zone | [~] | Untested; edge cases in B-17. |

### Content

| Area | State | Notes |
|---|---|---|
| Person's Tag / Throw action | [~] | `person_action.gd` + `.tres` exist. Fires toward world −Z only (B-05). |
| Sardinas — Quick Stand | [~] | Script + `.tres` exist. Cannot be activated at all (B-06). |
| Palayok, Bilao, Dyaryo, Bakya, Havaianas specials | [~] | Scripts exist. **No `.tres` resources, not attached to anything, unreachable in game.** |
| Character selection | [ ] | No UI, no data. Which of the 6 you play is not choosable. |
| Character scenes (`scenes/characters/cans/`, `tsinelas/`) | [ ] | Empty. Everything is one grey capsule. |
| Maps — Eskinita, Bayan Plaza | [ ] | Names only. One 40×40 box floor exists. |
| Map hazards (jeepney lane, mud, carabao) | [ ] | `HazardZone` is the reusable piece; nothing placed. |
| Ring-outs / out-of-bounds | [ ] | No bounds check anywhere (B-15). |
| Art, animation, VFX | [ ] | `assets/` is empty except `.gitkeep`s. |
| Audio | [ ] | Nothing. |
| Broadcast/spectator cam | [ ] | GDD Section 6 stretch. |
| Trailer + demo video | [ ] | |
| Submission forms 01–03, synopsis | [ ] | GDD Section 9. |

### What has and hasn't been verified by a human

Playtested and confirmed: movement, per-player input split, camera follow, main menu
navigation. **Never confirmed by anyone pressing buttons:** bump landing, stagger, Downed,
self-right, seal, dents, any special ability, any round ending, any match ending, and
every network path beyond "the peers connect". Treat all of Section 1's `[~]` rows as
untrusted until someone has actually played them.

---

## 2. Architecture — how the pieces fit

```
MainMenu.tscn ──(GameLaunch autoload)──> Main.tscn
                                            │
        ┌───────────────────────────────────┼───────────────────────────────┐
        │                                   │                               │
   NetworkManager                     MatchManager ── round_started ──> main.gd
   (ENet host/join,                   (Bo5, role swap)                      │
    is_networked/is_host)                   ▲                    assigns is_can / registers Cans
        │                                   │                               │
        └──> MultiplayerSpawner ──> CharacterBase ×4          RoundManager (90s timer,
                    │                (Person | Prop)           tracked Cans, win check)
             MultiplayerSynchronizer        │                          │
             (position, rotation,           ├── AbilityBase (.tres per character)
              state, dents)                 ├── Hitbox  ──> resolves on host only
                                            └── Hurtbox      ──> _apply_hit_result RPC
                                                                    to the target's owner
```

Three rules this codebase is built on. Keep them:

1. **Round-win logic is decoupled from movement, combat, and hit registration.** `RoundManager`
   only watches `state_changed` / `dents_changed` on a registered list of Cans. That is what
   makes Option A vs Option B a config switch instead of a rewrite. Do not let win conditions
   leak into `character_base.gd` or `hitbox.gd` beyond the one `GameLaunch.game_mode` branch
   that already exists.
2. **One `CharacterBase` scene, six abilities as Resources.** Adding or rebalancing a special
   is one `.tres` edit, not a new script per character.
3. **Host is authoritative for anything that decides a round.** Clients own only their own
   character's movement and state; the host resolves hits and tells the owning peer what
   happened. Input is decoupled per player (`*_p1`..`*_p4`), so the GDD's shared-screen
   fallback stays cheap.

### Autoloads

`RoundManager` · `MatchManager` · `NetworkManager` · `GameLaunch` · `SettingsManager`

Autoloads persist across scene changes. Nothing currently resets them between matches —
that is B-14 and it needs a `reset()` on both `RoundManager` and `MatchManager`.

---

## 3. Build order

Ordered so each phase de-risks the next. Phases 0 and 1 are blocking; nothing else is worth
doing until a full 2v2 round can start, be won, and roll into the next round.

### Phase 0 — Make it run (blocking, do first)

Fix the four P0 bugs. Until these are done there is no LAN demo to show anyone.

- [x] **B-01** — `MatchManager` host never emits `round_started` / `match_won` locally, so a
      networked match's timer never starts. One-line class of fix. *(Fixed: `_sync_round_started`
      and `_sync_match_won` are now `call_local` instead of `call_remote`, so the host runs its
      own handler — same RPC, no separate direct-emit path needed. Verify with two editor
      instances, `--host` and `--join=127.0.0.1`, that both see the timer move.)*
- [x] **B-02** — abilities spawn their hitbox only on the activating peer, and hitboxes only
      resolve on the host, so every special and Tag/Throw is a no-op for anyone who isn't
      hosting. Needs an activation RPC to the host. *(Fixed: activation still runs locally on
      the activating peer for its own cosmetic/movement effect, and a new `_rpc_notify_ability_activate`
      RPC — same pattern as the existing bump RPC — additionally tells the host to run
      `ability.activate(self)` on its own copy of the character, so the authoritative resolving
      hitbox actually exists where hitbox.gd can resolve it.)*
- [ ] **B-03** — `ArenaCamera` holds freed local-test nodes in networked play and never picks
      up the spawned networked characters.
- [ ] **B-04** — networked Props spawn with `ability = null`; only Persons get one.

**Exit criteria:** two editor instances, one `--host` one `--join=127.0.0.1`, both see the
timer counting, both can bump each other, and both see the same result.

### Phase 1 — Make the core loop correct

Fix the P1 bugs, then playtest the loop end to end for the first time.

- [ ] **B-05** face-direction (rotate the character toward movement, or add an aim axis)
- [ ] **B-06** special-ability input unreachable while Downed
- [ ] **B-07** stagger cancelling Downed
- [ ] **B-08** bump missing already-overlapping targets
- [ ] **B-09** friendly fire — add a `team_id` to `CharacterBase` and gate `Hitbox`
- [ ] **B-10** per-round reset covers all four units and their positions
- [ ] **B-11** cooldown consumed on a no-op activation
- [ ] **B-12** frame-step friction / Flick Dash lasting three frames
- [ ] Play a full Bo5 locally. Decide **Option A or Option B** and delete the other.

**Exit criteria:** a full best-of-5 completes, roles swap each round, positions and states
reset between rounds, and the team has picked one round-win mode.

### Phase 2 — Roster and selection

The single biggest content gap: five of the six specials cannot be reached in game.

- [ ] `.tres` resource for each of Palayok, Bilao, Dyaryo, Bakya, Havaianas
- [ ] Character-select step (menu or lobby) writing the pick into `GameLaunch`
- [ ] `_build_networked_character` assigns the picked ability (`.duplicate()` per character —
      cooldown state lives on the Resource instance)
- [ ] Implement **Guard/Dash** (`guard_dash_*` is bound, rebindable, and read by nothing — B-16)
- [ ] Balance pass on cooldowns and ranges — every number in the ability scripts is a guess

### Phase 3 — Maps and match flow

- [ ] `Eskinita.tscn` and `BayanPlaza.tscn` with real geometry, spawn points, and base circles
- [ ] Spawn points driven by the map, not `main.gd`'s hardcoded `SPAWN_POINTS`
- [ ] Out-of-bounds handling + **ring-outs** (Option A's second win condition) — B-15
- [ ] Map hazards on `HazardZone` (jeepney lane, mud, carabao) — fix B-17 first
- [ ] Real lobby: wait for 4 players, ready-up, then start round 1 (B-13)
- [ ] Match reset and return-to-menu (B-14, B-20)

### Phase 4 — Feel, presentation, netcode polish

- [ ] Movement interpolation/smoothing for remote characters — currently visibly snaps
- [ ] Hit feedback: the `landed_on` signal already exists and nothing listens to it
- [ ] Real models, materials, animation; replace the capsules
- [ ] Audio: bump, special, downed/seal, ambience per map
- [ ] Broadcast/auto-follow cam for recording (GDD Section 6)

### Phase 5 — Submission

- [ ] Multi-device LAN test on real hardware over real wifi (never done)
- [ ] Export presets (none exist) and a build that runs outside the editor
- [ ] Trailer (1–2 min, loopable), demo video (3–5 min, narrated or captioned)
- [ ] Forms 01–03, waiver, synopsis (≤500 words) — GDD Section 9
- [ ] Mention Circular Economy in the synopsis if the team wants the secondary-theme angle

### Fallback trigger

Per GDD Section 7: if LAN sync is not stable and fun by roughly the halfway point of the
remaining schedule, pivot to single-PC shared-screen for the same 2v2 loop. That pivot is
already cheap — `_start_local_test()` in `main.gd` spawns all four units with independent
input maps today, and every `NetworkManager.is_networked()` check is a no-op in that mode.
The cost of the pivot is real player 3/4 keybinds (`*_p3` / `*_p4` are registered but
deliberately unbound) plus a split or shared camera. Budget half a day, not a week.

---

## 4. Working agreements

### Repo layout

```
assets/            characters, maps, audio, ui — binary, goes through Git LFS
scenes/
  characters/      CharacterBase.tscn + per-character scenes (cans/, tsinelas/)
  maps/            Eskinita.tscn, BayanPlaza.tscn
  ui/              MainMenu.tscn, HUD.tscn, SettingsPanel.tscn
  main/            Main.tscn — the match scene
scripts/
  characters/      character_base.gd, hitbox.gd, hurtbox.gd
  systems/         round_manager, match_manager, network_manager, game_launch,
                   settings_manager, arena_camera, hazard_zone
  abilities/       ability_base.gd + one script per special + resources/*.tres
docs/
```

### Git

- One branch per feature off `main` (`feature/networking`, `feature/map-eskinita`, …).
  Small, frequent merges — long-lived branches are where scene conflicts come from.
- `.tscn` / `.tres` are text and diff like code. Keep them text (don't switch to binary).
- Binary assets do **not** merge. `git lfs install` before adding any model, texture, or
  audio file — `.gitattributes` already tracks `.glb/.gltf/.fbx/.png/.jpg/.wav/.mp3/.ogg`.
- **Give a heads-up in chat before editing a shared `.tscn`** (`Main.tscn`, `CharacterBase.tscn`).
  Splitting work into sub-scenes is the real fix and is already how the structure is set up.
- Keep `main` playable.

### Testing multiplayer without four laptops

Godot's **Debug → Run Multiple Instances → 2+**, with per-instance arguments
`--host` and `--join=127.0.0.1`. The menu's Host/Join buttons do the same thing through the
`GameLaunch` autoload. Real-device testing over wifi still has to happen before submission —
it never has.

### Ownership

Fill these in — GDD Section 8 has the same table and it is still blank.

| Workstream | Owner |
|---|---|
| Gameplay programming (movement, combat, states) | |
| Networking (LAN) | |
| 3D art — characters | |
| 3D art — maps | |
| UI/UX — HUD, menus, scoreboard | |
| Sound/Music | |
| Producer / docs & submission | |

---

## 5. Godot setup (for anyone new to the project)

1. Install **Godot 4.7**, Standard build (not .NET — this project is GDScript), from
   godotengine.org/download. It's a single executable; unzip and run.
2. Clone the repo, open `project.godot` in Godot.
3. `git lfs install` before touching any art or audio.
4. Press **F5**. That runs `scenes/ui/MainMenu.tscn` (the project's main scene) → **Start**
   → **Local Match** for the single-PC 4-unit flow. Or open `scenes/main/Main.tscn` and press
   **F6** to jump straight into a match.

**Local controls** (rebindable in Settings): P1 = WASD, Space bump, Shift guard/dash, Q
special. P2 = arrows, Enter bump, End guard/dash, Right Shift special. P3/P4 exist but are
deliberately unbound — they are the stationary dummy opponents in the local test flow.

### Orientation, quickly

- **FileSystem** (bottom-left) mirrors the folders on disk.
- **Scene** (top-left) is the node tree of the open scene. A "scene" is a reusable prefab.
- **Inspector** (right) shows the selected node's properties — this is where a character's
  `ability`, `is_can`, `is_person`, `player_id` exports live.
- Autoloads are under **Project → Project Settings → Globals → Autoload**.
- Input actions are under **Project → Project Settings → Input Map**.

Deeper reading: docs.godotengine.org — "Your first 3D game" for the basics, and
"High-level multiplayer" for `MultiplayerSpawner` / `MultiplayerSynchronizer`, which is what
the networking layer here is built on.
