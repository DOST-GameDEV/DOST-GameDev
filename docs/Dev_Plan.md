# Dev Plan — Tumbang Preso

Integration and development plan for the Godot 4.7 build. Written against the code that is
actually in this repo, not against intent. Design source of truth is
[`Tumbang_Preso_2v2_GDD.md`](Tumbang_Preso_2v2_GDD.md); current state, the bug ledger, and the
"pick this up next" queue are in [`Handoff.md`](Handoff.md).

**Engine:** Godot 4.7, Forward+, GDScript · **Target:** 4-player LAN (2v2), Bo5 · **Deliverable:** playable demo + 1–2 min trailer + 3–5 min gameplay video

---

## 0. Standing directives

These override anything older in this document, in the GDD, or in previous handoffs. If you
find contradicting guidance elsewhere, this section wins and the other document is stale.

### 0.1 Camera paradigm — locked

| Character type | Camera | Node |
|---|---|---|
| **Person** (`is_person == true`) | **FPP — first person, always** | `CameraRig` in FPP mode |
| **Prop** — Can (Lata) and Slipper (Tsinelas) (`is_person == false`) | **TPP — third person, always** | `CameraRig` in TPP mode |

There is no player-facing toggle, no per-map override, and no export flag. The mode is
**derived** from `is_person` at `_ready()` so it cannot drift. A Person is never third-person;
a Prop is never first-person.

This overrides:
- GDD Section 2 ("Camera/Genre: Full 3D, low-poly, **third-person**")
- GDD Section 6 ("**Third-person cam per player**")
- The existing scene-level `ArenaCamera` in `Main.tscn`, which is retired from gameplay
  entirely (see §3.4).

Both GDD lines predate the split and are now wrong. Section 3 below is the implementation.

### 0.2 Local Match is a test harness, not a shipping mode

`_start_local_test()` and the `p3`/`p4` input sets exist to let one person exercise four units
on one keyboard. **It is removed before submission.** Until then it gets one addition — a debug
switcher for driving any of the four units manually (§3.5) — and nothing else. Do not invest UI
or polish in it, and do not let it constrain the LAN architecture.

### 0.3 Debug-only code — the removal contract

Everything that exists only to make testing possible (the debug player switcher §3.5, the Local
Match flow §0.2, any future noclip / state-force / hitbox-visualiser) must be **removable by
deleting files and one line each, with nothing left behind and no gameplay script edited to put
it back.** That is a design constraint on how it gets written, not a cleanup task for later.

Five rules. A debug feature that breaks any of them is written wrong and should be rejected in
review:

1. **`debug_` / `Debug` prefix on every file, class, node, and autoload.** No exceptions. This is
   what makes the removal verifiable — one `grep` proves the surface is gone (§3.5.5). A debug
   helper hiding inside `character_base.gd` is invisible to that grep and will ship.
2. **One-way dependency: debug code calls gameplay, gameplay never calls debug.** No gameplay
   script may reference a debug class, autoload, signal, or group — not even behind an
   `if OS.is_debug_build()`. If a debug feature needs a hook, it uses a **public API that earns
   its place on gameplay grounds anyway** (e.g. `CameraRig.set_active()`, which the normal local
   and networked paths both need). Deleting the debug file must never leave a dangling reference.
3. **No footprint in `project.godot` beyond a single autoload line.** Debug input actions are
   *not* added to the `[input]` map — read raw keys in `_unhandled_key_input()` instead. That
   also keeps debug keys out of the Settings rebind panel, which iterates
   `SettingsManager.REBINDABLE_ACTIONS`.
4. **Self-disabling at runtime.** First lines of `_ready()`:
   `if not OS.is_debug_build(): queue_free(); return`, and a
   `if NetworkManager.is_networked(): return` guard on every input path. If someone forgets to
   remove it, an exported release build strips it anyway and it can never reach a LAN match.
   This is a safety net, **not** a substitute for deleting it.
5. **A removal checklist ships with the feature**, in this document, written at the same time as
   the feature. See §3.5.5 for the worked example.

Removal is scheduled in Phase 6 (§5) and is part of the definition of done for submission.

### 0.4 Title

The moodboard ships a finished logo reading **TUMBANG PRESO** (with the "O" as a can top).
That is now the display title. `project.godot` says "Tumbang Laro", the README and GDD say
"Tumbang Laro: Isang Laban", the menu says "TUMBANG PRESO" — three names for one game. Adopt
the logo's. See B-27.

---

## 1. Where the build actually stands

Legend: **[x]** built and working · **[~]** built but broken or unverified · **[ ]** not started

### Core systems

| Area | State | Notes |
|---|---|---|
| Project scaffold, folders, `.gitignore`, LFS attributes | [x] | |
| `CharacterBase` — move, gravity, per-player input map | [x] | Playtested. Rotation now written via movement-facing `look_at()` (B-05 fixed). No dash — B-16. |
| `AbilityBase` resource pattern (one scene + a plugged-in Resource per character) | [x] | Pattern is sound and worth keeping. |
| `Hitbox` / `Hurtbox` + press-to-bump active window | [x] | Layers are correct (Hurtbox L2/M0, Hitbox L0/M2). Already-overlapping targets fixed (B-08), team check added (B-09). Unverified by a human. |
| Downed / self-right / Seal state machine | [x] | B-07 fixed — a hit during the self-right window no longer rescues a Downed Can. |
| Option A — dents (health) round win | [~] | Wired end to end; never human-verified. Menu still calls it "coming soon" (B-26). |
| Option B — Downed → Seal round win | [x] | Wired end to end; B-07 (the blocker) fixed. Never human-verified. |
| `RoundManager` (90s timer, win reporting) | [~] | Starts on the host now (B-01 fixed, unverified); a **late-joining client never learns a round started** (B-29). |
| `MatchManager` (Bo5, role swap) | [x] | Bo5-to-3 early win **already implemented** (`WINS_NEEDED = 3`, `match_manager.gd:43`). No match reset (B-14), no end-of-match flow (B-37). |
| `NetworkManager` (ENet host/join) | [x] | Connects fine. Everything downstream is where the trouble is. |
| Networked spawning + movement replication | [~] | Works; snaps (no interpolation); Props now get an ability (B-04 fixed); `player_id` still never assigned (B-30). |
| Host-authoritative combat | [~] | Correct for Bump; specials now replicate to the host (B-02 fixed, unverified against a real client). |
| HUD (timer, Bo5, round, role, dent counter, downed flash) | [~] | Functional but placeholder-styled. Client score is stale (B-38). Full rebuild in §4. |
| Main menu + mode picker | [~] | **No back button** (B-34); disabled mode is selectable and proceeds (B-33). |
| Settings — rebindable, persistent controls | [x] | Rebinds an action nothing reads (B-16); allows duplicates (B-22); P2 bindings are dead in LAN (B-30). |
| `ArenaCamera` follow/zoom | [x] | B-03 fixed — runtime target registration + validity check, no more networked-play crash. Superseded by per-character `CameraRig` (§3), not yet built. |
| `HazardZone` slow-zone | [~] | Untested; edge cases in B-17. |
| Out-of-bounds / kill plane / arena walls | [ ] | Nothing. Falling off the map = infinite fall + camera follows forever (B-15, B-35). |
| Per-character camera rigs (FPP/TPP) | [ ] | §3. |
| Round intermission / role-swap beat | [ ] | Rounds currently roll over in the same frame (B-37). §4.6. |
| Team identity on `CharacterBase` | [ ] | No `team_id` exists. Blocks friendly-fire fix **and** three UI items (B-09). |

### Content

| Area | State | Notes |
|---|---|---|
| Person's Tag / Throw action | [~] | `person_action.gd` + `.tres` exist. Fires toward world −Z only (B-05). Moodboard specs a **charged, aimed** throw instead (B-45). |
| Sardinas — Quick Stand | [~] | Script + `.tres` exist. Cannot be activated at all (B-06). |
| Palayok, Bilao, Dyaryo, Bakya, Havaianas specials | [~] | Scripts exist. **No `.tres` resources, not attached to anything, unreachable in game.** |
| Character selection | [ ] | No UI, no data. |
| Character scenes (`scenes/characters/cans/`, `tsinelas/`) | [ ] | Empty. Everything is one grey capsule. |
| Maps — Eskinita, Bayan Plaza | [ ] | Names only. One 40×40 box floor exists. |
| Map hazards (jeepney lane, mud, carabao) | [ ] | `HazardZone` is the reusable piece; nothing placed. |
| Art, animation, VFX | [ ] | `assets/` is empty except `.gitkeep`s. Moodboard now exists — see §4. |
| Audio | [ ] | Nothing. No hit feedback of any kind (B-44). |
| UI theme / design system | [ ] | §4. Moodboard delivered, tokens extracted, nothing built. |
| Broadcast/spectator cam | [ ] | GDD Section 6 stretch. `ArenaCamera` becomes this (§3.4). |
| Trailer + demo video | [ ] | |
| Submission forms 01–03, synopsis | [ ] | GDD Section 9. Note Form 03 now needs the **font license** (§4.2). |

### What has and hasn't been verified by a human

Playtested and confirmed: movement, per-player input split, camera follow, main menu
navigation. **Never confirmed by anyone pressing buttons:** bump landing, stagger, Downed,
self-right, seal, dents, any special ability, any round ending, any match ending, and every
network path beyond "the peers connect". A later pass fixed B-01 through B-12 in code (see §5,
Phase 0/1) but **none of those fixes have been confirmed by a human pressing buttons either** —
only a headless `godot --headless --path . --quit` smoke test (no script/parse errors, loads
clean) has run against them. Treat every `[~]` row above, and every `[x]` row whose fix note says
"unverified", as untrusted until someone actually plays it.

---

## 2. Architecture — how the pieces fit

```
MainMenu.tscn ──(GameLaunch autoload)──> Main.tscn
                                            │
        ┌───────────────────────────────────┼───────────────────────────────┐
        │                                   │                               │
   NetworkManager                     MatchManager ── round_started ──> main.gd
   (ENet host/join,                   (Bo5, role swap,                      │
    is_networked/is_host)              intermission)                        │
        │                                   ▲                    assigns is_can / registers Cans
        │                                   │                               │
        └──> MultiplayerSpawner ──> CharacterBase ×4          RoundManager (90s timer,
                    │                (Person | Prop)           tracked Cans, win check)
             MultiplayerSynchronizer        │                          │
             (position, rotation,           ├── AbilityBase (.tres per character)
              state, dents)                 ├── Hitbox  ──> resolves on host only
                                            ├── Hurtbox      ──> _apply_hit_result RPC
                                            ├── CameraRig    ──> FPP if Person, TPP if Prop   ← NEW (§3)
                                            └── Nameplate    ──> team + player identity       ← NEW (§4.5)
```

Four rules this codebase is built on. Keep them:

1. **Round-win logic is decoupled from movement, combat, and hit registration.** `RoundManager`
   only watches `state_changed` / `dents_changed` on a registered list of Cans. That is what
   makes Option A vs Option B a config switch instead of a rewrite. Do not let win conditions
   leak into `character_base.gd` or `hitbox.gd` beyond the one `GameLaunch.game_mode` branch
   that already exists.
2. **One `CharacterBase` scene, six abilities as Resources.** Adding or rebalancing a special is
   one `.tres` edit, not a new script per character.
3. **Host is authoritative for anything that decides a round.** Clients own only their own
   character's movement and state; the host resolves hits and tells the owning peer what
   happened.
4. **The camera belongs to the character, not to the scene.** *(New — §3.)* Every camera is a
   child of the `CharacterBase` it serves. No scene-level camera holds a `NodePath` to a
   player. This is what permanently kills B-03 and half of the out-of-bounds camera bug.

### Autoloads

`RoundManager` · `MatchManager` · `NetworkManager` · `GameLaunch` · `SettingsManager`
*(planned: `UiTheme` §4.2, `DebugPlayerSwitcher` §3.5 — debug-only, stripped for release)*

Autoloads persist across scene changes. Nothing currently resets them between matches — that
is B-14 and it needs a `reset()` on both `RoundManager` and `MatchManager`.

---

## 3. Camera architecture — FPP / TPP split

Implements directive §0.1. This is a new subsystem, not a patch on `ArenaCamera`.

### 3.1 Node structure

One rig scene, `scenes/characters/CameraRig.tscn`, instanced as a child of `CharacterBase.tscn`:

```
CharacterBase (CharacterBody3D)
├── MultiplayerSynchronizer      (position, rotation, state, dents)
├── CollisionShape3D
├── Visual (Node3D)              ← wrap the mesh so FPP can hide it as one unit
│   └── MeshInstance3D
├── Hurtbox / Hitbox
├── Nameplate (Node3D)           ← §4.5
└── CameraRig (Node3D)           ← scripts/systems/camera_rig.gd
    ├── FppPivot (Node3D)        y ≈ 1.55 (eye height)
    │   └── FppCamera (Camera3D) near = 0.05, fov = 95
    └── TppArm (SpringArm3D)     y ≈ 1.2, x-rot −15°, spring_length = 4.5,
        │                        collision_mask = world layer only
        └── TppCamera (Camera3D) fov = 70
```

`SpringArm3D` is doing the wall-clipping work in TPP; do not hand-roll a raycast.

### 3.2 `camera_rig.gd` contract

```gdscript
enum Mode { FPP, TPP }

# DERIVED, never exported. Directive §0.1 — a Person is always FPP, a Prop always TPP.
func _ready() -> void:
    _mode = Mode.FPP if _character.is_person else Mode.TPP
```

- **Activation.** Exactly one camera in the scene has `current = true`. Networked:
  `is_multiplayer_authority()`. Local test: whichever unit `DebugPlayerSwitcher` currently
  targets (§3.5). Everyone else's rig has `current = false` and should have `_process`
  disabled — four active rigs is four cameras' worth of work for nothing.
- **Yaw lives on the body, pitch lives on the rig.** The rig writes
  `_character.rotation.y`; it must never touch `rotation.x` on the body. `Hitbox` sits at a
  fixed local offset and every directional ability uses `-transform.basis.z` — tilting the body
  would tilt the hitboxes into the floor.
- **This is the fix for B-05.** Once yaw is a real value, `-transform.basis.z` becomes a real
  aim vector, the melee `Hitbox` finally points where you're looking, and `Input.get_vector`'s
  existing `transform.basis * input_dir` becomes camera-relative movement for free. Do **not**
  build a separate aim axis — `rotation` is already in the replication config
  (`CharacterBase.tscn:11`) and is already replicated. It has simply never been written to.
- **Pitch clamp:** −80° … +70°. The low end has to be generous: a Person in FPP has to look
  down at a knee-height Can to throw at it.
- **FPP self-hide:** set `Visual.cast_shadow = SHADOW_CASTING_SETTING_SHADOWS_ONLY` — do not
  `hide()` it. Losing your own shadow in FPP destroys the ground read, and other peers still
  need to see the mesh.
- **Aim source** — one export, because the two flows genuinely differ:
  - `AimSource.MOUSE` — LAN, and the debug-controlled unit in local test. Mouse capture on,
    `Input.MOUSE_MODE_CAPTURED`, released on pause/Esc and on focus loss.
  - `AimSource.MOVEMENT` — auto-face the movement vector. Used by every unit that isn't the
    locally-driven one, and by the whole local-test flow.

  **Two players sharing one keyboard cannot both mouse-look.** That is not solvable and is not
  worth solving — local test is dying anyway (§0.2). LAN is one player per machine, so mouse
  look is correct there.
- **Mouse sensitivity** goes in `SettingsManager` alongside the keybinds, plus an invert-Y
  toggle. FPP without a sensitivity slider will read as broken to anyone testing it.

### 3.3 Known asymmetry — accept it, mitigate it

FPP gives the Person a much narrower cone of awareness than the TPP Prop. That is a real
competitive asymmetry, but it is **symmetric across teams** (both teams field one Person and
one Prop, and roles swap every round), so it does not favour anyone. Mitigate the feel, not the
structure:

- Wide FPP FOV (95, tunable).
- Off-screen indicators for your teammate and for the Can (§4.5).
- A hit taken from off-screen shows a directional damage arc.

### 3.4 Retiring `ArenaCamera`

`scripts/systems/arena_camera.gd` stops being a gameplay camera. Either delete the `Camera3D`
node from `Main.tscn` outright, or keep the script and repurpose it as `BroadcastCamera` for
recording the 3–5 min demo video (GDD Section 6) — in which case it must:

- resolve targets at **runtime** via a `register_target()` / `unregister_target()` API, never
  by caching `NodePath`s in `_ready()`;
- hold `WeakRef`s or re-check `is_instance_valid()` every frame;
- default to `current = false`, activated only by a spectator/record toggle;
- ignore any target whose `global_position.y` is below the kill plane, so one player falling
  out of the world can't drag the framing (B-35).

Until then, **it is the LAN freeze** (B-03) and it must be disabled in the same commit that
introduces the rigs.

### 3.5 Debug player switcher — manual control of any unit in local mode

**Purpose.** Local Match spawns all four units, but only two of them (`player_id` 1 and 2) have
bound keys; `p3`/`p4` are deliberately unbound dummies. This lets one tester drive **any** of the
four on demand, so the whole Bo5 loop, both roles, and every character can be exercised without
four people in a room.

**This is not a nicety.** From round 2 onward, `_on_match_round_started` flips `team_a_is_can`, so
the tracked Can becomes `TeamBProp` — `player_id = 3`, unbound. The Can cannot be moved, cannot
self-right, and the round can only end on the timer. **A local Bo5 is not playable past round 1
today** (B-42). This switcher is what makes local playtesting possible at all, which is why it is
first in the execution queue.

Written to the removal contract in §0.3. §3.5.5 is the checklist that takes it back out.

#### 3.5.1 Behaviour

Two control slots, matching the two bound input sets in `project.godot`:

| Slot | Keys | Default holder |
|---|---|---|
| **P1** | WASD · Space bump · Shift guard/dash · Q special | `TeamAProp` |
| **P2** | Arrows · Enter bump · End guard/dash · RShift special | `TeamAPerson` |

| Key | Action |
|---|---|
| `F1` `F2` `F3` `F4` | Assign that unit to the **P1** slot |
| `Shift` + `F1`…`F4` | Assign that unit to the **P2** slot |
| `Tab` | Cycle the P1 slot to the next unit |
| `Shift`+`Tab` | Cycle the P2 slot to the next unit |
| `F5` | Drop the P2 slot entirely (solo drive — one unit live, three inert) |
| `F6` | Reset both slots to their defaults |

Cycle order is the `Main.tscn` order: `TeamAProp` → `TeamAPerson` → `TeamBProp` → `TeamBPerson`.
A slot skips a unit already held by the other slot, so the two can never collide.

#### 3.5.2 How control actually moves — no gameplay edits

`CharacterBase._physics_process` resolves its input through
`_action(name) -> "%s_p%d" % [name, player_id]`, and `player_id` is already a public `@export`. So
the switcher moves control by **reassigning `player_id` from the outside** — every unit not
currently in a slot is parked on `4`, which is registered and permanently unbound, making it an
inert dummy.

That is the whole mechanism. It needs **zero** changes to `character_base.gd`, which is why rule
0.3.2 (one-way dependency) holds for free.

Three details that will bite otherwise:

- **Park unused units on `4`; never leave two units sharing an id.** Two units on `player_id = 1`
  both move on the same W press.
- **`Input.is_action_just_pressed` is edge-triggered.** Reassign slots in `_unhandled_key_input`,
  not mid-`_physics_process`, or a unit can inherit a half-consumed press and stutter on the frame
  it gains control.
- **`main.gd::_on_match_round_started` does not touch `player_id`**, so slot assignments survive
  the round swap — which is what you want. Re-check that after B-10's world reset lands, since
  `reset_world()` will be writing to all four units.

#### 3.5.3 Camera handoff

The switcher calls the rig's ordinary public API — `CameraRig.set_active(bool)` and
`CameraRig.set_aim_source(...)` — which the normal local and networked paths need anyway (§3.2).
`camera_rig.gd` never mentions the switcher and does not know it exists.

On a slot change: deactivate the outgoing unit's rig, activate the incoming one's, set the
incoming to `AimSource.MOUSE` and the outgoing back to `AimSource.MOVEMENT`.

Only the **P1** slot drives the camera. With two slots live on one screen, the P2 unit is being
driven blind off the P1 camera — fine and expected for a test harness, and exactly why `F5` (solo
drive) exists. Do not build split-screen for this.

The rig mode itself is untouchable: switching to a Person still gives FPP, switching to a Prop
still gives TPP (§0.1). The switcher chooses *which* rig is active, never *what mode* it is in.

#### 3.5.4 On-screen readout

A `DebugBar` strip pinned to the bottom of the screen, deliberately ugly so nobody mistakes it for
shipping UI — plain white monospace on a black bar, no theme, no `UiTheme` reference:

```
DEBUG  P1▶ TeamAProp (Can · Team A · DEFENSE)   P2▶ TeamAPerson (Person · Team A)
       F1-F4 set P1 · Shift+F1-F4 set P2 · Tab cycle · F5 solo · F6 reset
```

Live-update the role/side text on `MatchManager.round_started` — after a swap you need to see at a
glance that the unit you are holding is now the Can. It must show each held unit's `is_person`,
`is_can`, team and current side, because that is precisely the state that silently changes under
you between rounds.

#### 3.5.5 Removal checklist

Total footprint: **3 files, 2 lines.**

- [ ] Delete `scripts/systems/debug_player_switcher.gd`
- [ ] Delete `scripts/ui/debug_bar.gd`
- [ ] Delete `scenes/ui/DebugBar.tscn`
- [ ] Remove the single autoload line
      `DebugPlayerSwitcher="*res://scripts/systems/debug_player_switcher.gd"` from `project.godot`
- [ ] Remove the single `DebugBar` instance line from `Main.tscn` (under `HUDLayer`)
- [ ] Verify nothing is left behind:

```bash
grep -rin "debug" --include="*.gd" --include="*.tscn" --include="*.tres" --include="project.godot" . | grep -iv "is_debug_build"
```

That grep returning nothing is the acceptance test for removal, and it only works because of the
`debug_`/`Debug` prefix rule (§0.3.1). A hit inside a gameplay script means rule 0.3.2 was broken
somewhere and the removal is not finished.

- [ ] Open the project, press F5, play a Local Match round — confirm P1/P2 still work on their
      `Main.tscn` defaults with the switcher gone.

Removal happens in Phase 6 (§5), in the same pass that strips Local Match itself (§0.2). Since
Local Match is going too, the switcher's entire reason to exist goes with it — expect to delete
both together rather than one at a time.

---

## 4. UI architecture — moodboard implementation

Source: `Mood Board.pdf` (Harry's Canva assets). Reference game called out on the board: **PEAK**
— chunky stylised 3D, high-saturation, minimal in-world HUD.

### 4.1 What the moodboard actually specifies

Four role cards, each with a coloured accent bar, an all-caps display heading with a
parenthetical Filipino subtitle, a keycap badge, three captioned state icons, and a keyword
strip:

| Card | Subtitle | Accent | Input badge | States illustrated |
|---|---|---|---|---|
| THE ATTACKER | (Striker) | orange | WASD | dynamic movement · **aiming arc (mouse pointer trail)** · **charged throw (glow)** |
| THE DEFENDER | (Guard/Taya) | blue | arrow keys | stance variations · body-block hitbox (contact effect) · **lata reset channel (progress bar)** |
| THE SLIPPER | (Tsinelas) | magenta | — | in-hand ready (glowing icon) · thrown trajectory (spinning trail + motion blur) · retrieval highlight (arena floor decal) |
| THE CAN | (Lata) | magenta | arrow keys | standing (stable) · knocked down (tilted, dented) · impact effect (particle burst) |

Card chrome to reproduce in the Godot theme: deep-navy 3px border, light blue-grey fill with a
faint blueprint grid, a 6px full-height colour bar at the left of each heading, a bottom keyword
strip, and a folded dark triangle in the bottom-right corner.

**Three of these are mechanics that do not exist in code.** Flagged as decisions, not silently
built — see B-45, B-46, B-16 in the ledger.

### 4.2 Design tokens

Sampled from the moodboard's embedded art at native resolution. Ship these as a `UiTheme`
autoload of constants **and** a Godot `Theme` resource at `assets/ui/tumbang_preso.theme`, so
`.tscn` files style themselves and code-built UI reads the same values.

| Token | Hex | Use |
|---|---|---|
| `INK` | `#040838` | Borders, headings, body text, card outline. The single darkest value on the board. |
| `PANEL` | `#E1E5E8` | Card and panel fill. |
| `PAPER` | `#FFFFFF` | Inner wells, input fields. |
| `OFFENSE` / `ATTACKER` | `#F87020` | Team-on-offense accent, WASD keycaps, charged-throw glow. |
| `DEFENSE` / `DEFENDER` | `#0080E8` | Team-on-defence accent, Can body, arrow keycaps. |
| `IMPACT` | `#F468A8` | Slipper/Can accent bar, impact bursts, retrieval decal edge. |
| `HIGHLIGHT` | `#F8D028` | Can label, ready-state glow, timer urgency, progress-bar fill. |
| `DANGER` | `#F80000` | Downed flash, kill-plane warning. |

Two hard rules:

- **Offense is always orange, defence is always blue, for the whole project** — HUD, nameplates,
  team rings, scoreboard, role-swap card. A player must be able to learn one colour pair and
  read every screen. Never reuse orange or blue for anything else.
- The accent tracks **role**, not team. Team A is not "the orange team" — it is orange *while
  attacking* and blue *while defending*, and it swaps on the intermission card (§4.6). Team
  identity is carried separately by the **A / B letter mark**, not by hue.

**Typography.** The logo and letter sheet are a heavy hand-drawn *unicase* marker face —
lowercase renders as capitals. Get the actual font file from Harry (it is in the Canva project);
if it can't be extracted or its licence doesn't permit redistribution, the closest free
equivalents are **Luckiest Guy**, **Chewy**, or **Titan One** (all SIL OFL). Scale:

| Role | Face | Size |
|---|---|---|
| Display (title, round banner, match result) | marker unicase | 64–96 |
| Heading (panel titles, card headings) | marker unicase | 32–40 |
| Body / labels | a clean grotesque (Inter, Work Sans) | 16–20 |
| Caption (icon captions, keyword strips) | grotesque, all-caps, letter-spaced | 12–14 |

**Whatever font ships, its licence goes on submission Form 03 (Asset and AI Usage Disclosure).**
Settle it before the deadline, not during it.

### 4.3 Screen inventory

| Screen | Exists | Work |
|---|---|---|
| Title | [~] | Logo bitmap replaces the `Label`. Buttons: Play · Settings · Quit. |
| Play menu | [~] | Restyle. **Add Back** (B-34). **Disable Option A properly or drop the "coming soon" label** (B-33). |
| Character select | [ ] | 6 Props + Person. Feeds `GameLaunch`. Phase 3. |
| Lobby | [ ] | Peer list, team assignment, ready-up, host "Start" (B-13). |
| HUD | [~] | Full rebuild, §4.4. |
| Round intermission / role swap | [ ] | §4.6. Requested item. |
| Match result | [ ] | Bo5 grid, winner, Rematch / Menu. |
| Pause | [ ] | Esc → Resume / Settings / Quit to Menu (B-20). |
| Settings | [x] | Restyle only. Add mouse sensitivity + invert-Y (§3.2), add duplicate-binding detection (B-22). |

### 4.4 HUD layout

```
┌──────────────────────────────────────────────────────────────────────┐
│  ┌── TEAM A ─────┐        ╔═══════════╗        ┌───── TEAM B ──┐     │
│  │ ● OFFENSE     │        ║   01:30   ║        │ ● DEFENSE     │     │
│  │  ■ ■ □         │        ╚═══════════╝        │  ■ □ □         │     │
│  └───────────────┘         ROUND 3 / 5         └───────────────┘     │
│                                                                      │
│                                                                      │
│                              ✛  (FPP only)                           │
│                                                                      │
│  ┌───────────────┐                              ┌───────────────┐    │
│  │ YOU           │                              │  LATA         │    │
│  │ ▣ PROP · Can  │                              │  ●●○  dents   │    │
│  │ [Q] ████░ 2.1s│                              │  (Option A)   │    │
│  └───────────────┘                              └───────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

- **Bo5 pips, not "2 - 1".** Three squares per team, filled as rounds are won. A judge reads
  pips instantly and a score string not at all.
- Team panels carry the **role colour** (orange/blue) and the **team letter**. They swap sides
  visually on the intermission card so the swap is impossible to miss.
- Timer goes `HIGHLIGHT` under 15s and pulses under 10s.
- Bottom-left "YOU" card: your character portrait, your role this round, ability icon with a
  radial cooldown and a "READY" flash. This is item 4 (player distinction) at the HUD level;
  the in-world half is §4.5.
- Crosshair only in FPP. Props (TPP) get no crosshair.
- `DownedFlash` stays but becomes a vignette rather than a flat 25% red rectangle over the
  whole screen.

### 4.5 In-world player and team distinction (items 4 and 8)

The HUD tells you who *you* are. The world has to tell you who *everyone else* is. Add a
`Nameplate` node to `CharacterBase`:

- **Ground ring** — a flat decal under each unit, in the team's current role colour. This is the
  primary read: visible from any camera angle, works in both FPP and TPP, never occluded by
  geometry the way a floating label is.
- **Floating tag** (`Label3D`, `billboard = BILLBOARD_ENABLED`, `no_depth_test` off) — `A1` /
  `A2` / `B1` / `B2` plus a role glyph. Fades out past ~15m.
- **Your own unit** gets a distinct marker — a chevron above the tag, and a brighter ring — so
  the local player can find their body after a respawn or a camera cut.
- **In local test only**, the tag also shows the input set: `A1 · WASD`, `A2 · ARROWS`. That is
  the literal ask in item 4, and it is genuinely only meaningful when two people share a
  keyboard. LAN players each own their whole machine and don't need it.
- Teammate and objective **off-screen indicators** — arrows pinned to the screen edge. Mandatory
  for FPP (§3.3), useful in TPP.

**Prerequisite: `CharacterBase` has no team identity at all today.** `team_id` has to be added
and set from spawn data before any of §4.5 — or the friendly-fire fix (B-09) — can work. Do that
first; three separate items are blocked behind it.

### 4.6 Round flow, intermission, and the role-swap card (items 9, 10, 11)

**Today there is no gap between rounds.** `RoundManager.report_round_win()` →
`MatchManager.report_round_result()` → `begin_next_round()` → `_sync_round_started` →
`main.gd::_on_match_round_started()` → `RoundManager.start_round()` all runs in a single frame.
There is no beat in which a role-swap card could be shown, and no point at which the world is
reset. That missing state is the actual work (B-37):

```
round ends
  → RoundManager.round_active = false, freeze input on all units
  → MatchManager.report_round_result(can_team_won)
      │
      ├─ wins >= 3 ──> match_won ──> MATCH RESULT screen ──> Rematch | Menu
      │                              (Bo5 is already correct — WINS_NEEDED = 3,
      │                               match_manager.gd:43. Verify it, don't rebuild it.
      │                               What's missing is everything *after* it fires.)
      │
      └─ else ──> MatchManager.round_intermission_started(next_round, next_team_a_is_can)
                    │
                    ├─ [0.0s] ROUND RESULT banner — who won and how
                    ├─ [1.2s] ROLE SWAP card:
                    │            ROUND 3
                    │            TEAM A  🔵 DEFENSE  →  🟠 OFFENSE
                    │            TEAM B  🟠 OFFENSE  →  🔵 DEFENSE
                    │          Panels physically slide across and recolour.
                    ├─ [3.0s] WORLD RESET (item 10) — see below
                    ├─ [3.5s] "ROUND 3 — FIGHT" wipe
                    └─ [4.0s] MatchManager.begin_next_round()
```

**World reset must cover all four units, not one.** `RoundManager.start_round()` currently loops
`_tracked_cans`, which holds exactly the single defending Can (B-10). A `reset_world()` has to:

1. Move **every** unit back to its map spawn point (`position` + `velocity = Vector3.ZERO` +
   `rotation.y` facing the arena centre). **Nothing in the codebase writes `position` after
   spawn today** — round 2 currently starts wherever round 1 ended.
2. Call `reset_for_new_round()` on all four (state, dents, speed multiplier, ability charges) —
   not just the Can.
3. Free every live `HazardZone` and every orphaned pulse `Hitbox` from
   `AbilityUtils.spawn_pulse_hitbox`.
4. Reset the Can to its base circle, upright.
5. On the host, re-broadcast full match state so clients cannot drift.

Spawn points must come from the **map**, not from `main.gd`'s hardcoded `SPAWN_POINTS`
(`main.gd:55`) — add a `SpawnPoints` node to each map scene and read it.

### 4.7 Godot implementation notes

- **One `Theme` resource** at `assets/ui/tumbang_preso.theme` with `StyleBoxFlat` variants for
  the card chrome (border `INK` 3px, corner radius 6, content margins 16). Set it once on the
  root `Control` of each scene; children inherit. Do not scatter
  `theme_override_*` properties across `.tscn` files — that is how the current HUD is built and
  it is why restyling it means touching every node.
- **Theme type variations** for `Button` (`PrimaryButton`, `GhostButton`) and `Label`
  (`Display`, `Heading`, `Caption`) instead of per-node font-size overrides.
- **9-patch** (`NinePatchRect`) for the card frame so one exported PNG scales to any panel.
- Every panel that can be entered must be exitable: a `Back`/`Esc` path is part of the
  definition of done for each screen, not a follow-up.
- Set a base resolution (1920×1080) and `canvas_items` / `expand` stretch mode in Project
  Settings before building the theme, or every size gets retuned later.
- Keep the HUD reading autoloads directly (as it does now) — it needs no per-scene wiring and
  that property is worth preserving.

---

## 5. Build order

Ordered so each phase de-risks the next. Phase 0 is blocking: nothing else matters until a LAN
match starts, is playable, can be won, and rolls into the next round.

### Phase 0 — Make LAN work (blocking, do first)

- [x] **B-01** — `MatchManager` host never emitted `round_started` / `match_won` locally.
      *(Fixed: `_sync_round_started` / `_sync_match_won` are now `call_local`. **Still unverified
      by a human** — two editor instances, `--host` / `--join=127.0.0.1`, both must see the
      timer move.)*
- [x] **B-03** — `ArenaCamera` dereferences four freed nodes every frame after
      `_clear_local_test_characters()`. **This is the reported LAN freeze.** Disable the
      scene-level camera in the same commit as the rigs (§3.4).
      *(Fixed: runtime `add_target()`/`remove_target()` + `is_instance_valid()` filter every
      frame, per §3.4's "keep the script" branch. Superseded, not deleted, once the per-character
      `CameraRig` lands — §3.)*
- [ ] **B-29** — a client joining after the host started never receives `_sync_round_started`,
      so its round number, roles, tracked Cans and HUD are permanently stale. Host must
      `rpc_id()` full match state to each peer on connect.
- [x] **B-02** — abilities spawn their hitbox only on the activating peer and only resolve on
      the host, so every special and Tag/Throw is a no-op for anyone who isn't hosting.
      *(Fixed: `_rpc_notify_ability_activate` RPCs the host to run its own `activate()`. Still
      unverified against a real non-host client.)*
- [x] **B-04** — networked Props spawn with `ability = null`; only Persons get one.
      *(Fixed: every networked Prop gets a `.duplicate()`d `quick_stand.tres` until character
      select exists — B-24.)*
- [ ] **B-30** — `player_id` is never assigned to networked characters; all four read `*_p1`.
- [ ] **B-48** — `GameLaunch.game_mode` is never sent over the network; host and client can run
      different modes.

**Exit criteria:** two editor instances, one `--host` one `--join=127.0.0.1`, both see the timer
counting, both spawn and control their own character, both can bump each other, both see the
same result, and a client that joins late is in the same round as the host.

### Phase 1 — Make the core loop correct

- [x] **B-09** — add `team_id` to `CharacterBase` (**do this first — B-09, §4.5 and §4.6 are all
      blocked on it**) and gate `Hitbox` on it
      *(Fixed: `team` export + same-team skip in `hitbox.gd`. §4.5/§4.6 unblocked.)*
- [ ] **B-15 / B-35** — kill plane, arena walls, respawn
- [~] **B-10 / B-37** — round intermission state + full four-unit world reset with positions
      *(B-10 half fixed: `_on_match_round_started` resets + repositions all four units every
      round, not just the tracked Can. B-37 still open — no intermission gap/beat exists yet.)*
- [x] **B-05** — face direction, delivered by the camera rigs (§3.2), not as separate work
      *(Landed as `look_at()` on movement direction, ahead of the camera rig — equivalent to
      `AimSource.MOVEMENT`. The rig only needs to add `AimSource.MOUSE` for the FPP-controlled
      unit; do not build a second aim path.)*
- [x] **B-06** — special-ability input unreachable while Downed
- [x] **B-07** — stagger cancelling Downed
- [x] **B-08** — bump missing already-overlapping targets
- [x] **B-11** — cooldown consumed on a no-op activation
- [x] **B-12** — frame-step friction / Flick Dash lasting three frames
- [ ] **B-14 / B-20** — match reset, pause menu, return to menu
- [ ] Play a full Bo5 locally. Decide **Option A or Option B and delete the loser.**

**Exit criteria:** a full Bo5 completes, roles swap with a visible transition, all four units
reset to spawn between rounds, falling off the map respawns you, and the team has picked one
round-win mode.

### Phase 2 — Cameras and player readability

- [ ] `CameraRig.tscn` + `camera_rig.gd`, FPP and TPP branches (§3.1, §3.2)
- [ ] Retire / repurpose `ArenaCamera` (§3.4)
- [ ] Mouse capture, sensitivity + invert-Y in `SettingsManager`
- [ ] `DebugPlayerSwitcher` (§3.5)
- [ ] Nameplates, team ground rings, off-screen indicators (§4.5)

### Phase 3 — UI overhaul

- [ ] `tumbang_preso.theme` + `UiTheme` autoload from the tokens in §4.2
- [ ] Font decision + licence recorded for Form 03
- [ ] Title / Play menu restyle, **Back button**, Option A gating
- [ ] HUD rebuild (§4.4)
- [ ] Intermission + role-swap card (§4.6)
- [ ] Match result screen, pause menu
- [ ] Character select + lobby with ready-up

### Phase 4 — Content

- [ ] `.tres` for Palayok, Bilao, Dyaryo, Bakya, Havaianas
- [ ] Character models replacing the capsules — moodboard direction: chibi, oversized ball head,
      flat saturated colours, Filipino school-kid outfits with a sling bag
- [ ] `Eskinita.tscn` and `BayanPlaza.tscn` with geometry, `SpawnPoints`, base circles, bounds
- [ ] Map hazards on `HazardZone` (fix B-17 first)
- [ ] Implement **Guard/Dash** (B-16) — bound, rebindable, read by nothing
- [ ] Balance pass on cooldowns and ranges

### Phase 5 — Feel and presentation

- [ ] Hit feedback: `landed_on` already exists and nothing listens (B-44). Hitstop, screenshake,
      target flash, impact particles per the moodboard's "IMPACT EFFECT (PARTICLE BURST)"
- [ ] Movement interpolation for remote characters — currently visibly snaps
- [ ] Audio: bump, special, downed/seal, round win, ambience per map
- [ ] Broadcast/auto-follow cam for recording (GDD Section 6)

### Phase 6 — Submission

- [ ] Multi-device LAN test on real hardware over real wifi (never done)
- [ ] Export presets (none exist) and a build that runs outside the editor
- [ ] **Strip Local Match mode** (§0.2) and the debug switcher — run the removal checklist in
      §3.5.5 and confirm the verification `grep` comes back empty
- [ ] Trailer (1–2 min, loopable), demo video (3–5 min, narrated or captioned)
- [ ] Forms 01–03, waiver, synopsis (≤500 words) — GDD Section 9. Form 03 needs the font and
      moodboard-asset licences.
- [ ] Mention Circular Economy in the synopsis if the team wants the secondary-theme angle

### Fallback trigger

Per GDD Section 7: if LAN sync is not stable and fun by roughly the halfway point of the
remaining schedule, pivot to single-PC shared-screen for the same 2v2 loop.

**The FPP/TPP split raises the cost of this pivot and that should be said plainly.** Split-screen
means four viewports, and FPP mouse-look does not work for more than one player on one machine —
the two FPP Persons would have to fall back to `AimSource.MOVEMENT` (§3.2). Budget one to two
days for the pivot now, not half a day. If the pivot looks likely, take it early.

---

## 6. Working agreements

### Repo layout

```
assets/            characters, maps, audio, ui — binary, goes through Git LFS
                   ui/  tumbang_preso.theme, logo, 9-patch frames, keycap glyphs, icons
scenes/
  characters/      CharacterBase.tscn, CameraRig.tscn, per-character scenes (cans/, tsinelas/)
  maps/            Eskinita.tscn, BayanPlaza.tscn
  ui/              MainMenu.tscn, HUD.tscn, SettingsPanel.tscn, Intermission.tscn,
                   MatchResult.tscn, PauseMenu.tscn, CharacterSelect.tscn, Lobby.tscn
  main/            Main.tscn — the match scene
scripts/
  characters/      character_base.gd, hitbox.gd, hurtbox.gd
  systems/         round_manager, match_manager, network_manager, game_launch,
                   settings_manager, camera_rig, debug_player_switcher, hazard_zone
  ui/              hud.gd, main_menu.gd, settings_panel.gd, intermission.gd, …
docs/
```

### Git

- One branch per feature off `main` (`feature/camera-rigs`, `feature/ui-theme`, …). Small,
  frequent merges — long-lived branches are where scene conflicts come from.
- `.tscn` / `.tres` are text and diff like code. Keep them text.
- Binary assets do **not** merge. `git lfs install` before adding any model, texture, font, or
  audio file — `.gitattributes` already tracks `.glb/.gltf/.fbx/.png/.jpg/.wav/.mp3/.ogg`.
  **Add `*.ttf` and `*.otf`** before the display font lands.
- **Give a heads-up in chat before editing a shared `.tscn`** (`Main.tscn`, `CharacterBase.tscn`).
  The camera rig and the nameplate both touch `CharacterBase.tscn` — sequence them, or one of
  you loses work.
- Keep `main` playable.

### Testing multiplayer without four laptops

Godot's **Debug → Run Multiple Instances → 2+**, with per-instance arguments `--host` and
`--join=127.0.0.1`. The menu's Host/Join buttons do the same thing through `GameLaunch`.

⚠️ **Real-device testing over wifi has never happened and is on the critical path.** Real wifi
adds latency and packet loss to a movement layer with no interpolation and no reconciliation. If
that forces the shared-screen fallback, you want to know weeks before the deadline. Book a
session with four laptops.

### Ownership

Still blank. GDD Section 8 has the same table and it is also still blank. This is the third
document to ask.

| Workstream | Owner |
|---|---|
| Gameplay programming (movement, combat, states) | |
| Networking (LAN) | |
| Cameras + player readability | |
| UI/UX — theme, HUD, menus, scoreboard | |
| 3D art — characters | |
| 3D art — maps | |
| Sound/Music | |
| Producer / docs & submission | |

---

## 7. Godot setup (for anyone new to the project)

1. Install **Godot 4.7**, Standard build (not .NET — this project is GDScript), from
   godotengine.org/download. Single executable; unzip and run.
2. Clone the repo, open `project.godot` in Godot.
3. `git lfs install` before touching any art, font, or audio.
4. Press **F5**. That runs `scenes/ui/MainMenu.tscn` → **Start** → **Local Match** for the
   single-PC 4-unit flow. Or open `scenes/main/Main.tscn` and press **F6** to jump straight
   into a match.

**Local controls** (rebindable in Settings): P1 = WASD, Space bump, Shift guard/dash, Q special.
P2 = arrows, Enter bump, End guard/dash, Right Shift special. P3/P4 are registered but
deliberately unbound — they are the dummy opponents.

Once §3.5 lands, you can point either input set at **any** of the four units: `F1`–`F4` assign
the P1 slot, `Shift`+`F1`–`F4` assign P2, `Tab` cycles, `F5` drops to solo drive, `F6` resets.
A `DebugBar` at the bottom of the screen always names what you are holding. **Debug-only, and it
is deleted before submission — see §0.3 and the checklist in §3.5.5.**

### Orientation, quickly

- **FileSystem** (bottom-left) mirrors the folders on disk.
- **Scene** (top-left) is the node tree of the open scene. A "scene" is a reusable prefab.
- **Inspector** (right) shows the selected node's properties — a character's `ability`,
  `is_can`, `is_person`, `player_id` exports live here.
- Autoloads: **Project → Project Settings → Globals → Autoload**.
- Input actions: **Project → Project Settings → Input Map**.

Deeper reading: docs.godotengine.org — "Your first 3D game", "High-level multiplayer"
(`MultiplayerSpawner` / `MultiplayerSynchronizer`), "GUI skinning and themes" (for §4.7), and
`SpringArm3D` (for §3.1).
