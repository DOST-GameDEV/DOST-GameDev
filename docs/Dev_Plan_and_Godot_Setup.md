# Dev Plan & Godot Setup Guide
### Tumbang Laro — coding approach, GitHub workflow, and getting started in Godot

---

## PART 1 — Coding Approach

### Build order (why this order matters)

Build in this sequence, not by feature-owner convenience — each phase de-risks the next:

1. **Single-player prototype first, no networking.** Get one Can and one Tsinelas moving,
   bumping, and using abilities in the SAME editor window (two keyboards/input maps on one
   PC, or even just one character controllable for movement feel). Networking bugs are
   miserable to debug on top of gameplay that's still changing — lock the feel before you
   sync it over the wire.
2. **Round/match logic**, still single-player: timer, Downed state, role swap, Bo5 tracking.
   This is also where we can quickly test-drive Option A vs Option B from the design doc
   since it's decoupled from movement and networking.
3. **Networking.** Take the working single-player loop and wire it up over LAN. This is the
   riskiest phase — see the fallback plan in the design doc if it's not clicking.
4. **Maps + hazards.** Drop the working gameplay into Eskinita and Bayan Plaza.
5. **UI/HUD, juice, audio.** Score display, downed-state flash, hit feedback, sound.
6. **Polish + record trailer/demo footage.**

Whoever's free earliest should start on #1 — everything else depends on it existing.

### Suggested project structure

```
tumbang-laro/
├── assets/
│   ├── characters/
│   │   ├── cans/          (models, textures per Can)
│   │   └── tsinelas/      (models, textures per Tsinelas)
│   ├── maps/               (per-map models, textures)
│   ├── audio/
│   └── ui/
├── scenes/
│   ├── characters/
│   │   ├── CharacterBase.tscn
│   │   ├── cans/           (Sardinas.tscn, Palayok.tscn, Bilao.tscn)
│   │   └── tsinelas/       (Dyaryo.tscn, Bakya.tscn, Havaianas.tscn)
│   ├── maps/                (Eskinita.tscn, BayanPlaza.tscn)
│   ├── ui/
│   └── main/                (Main.tscn — the entry scene)
├── scripts/
│   ├── characters/
│   ├── systems/             (round_manager.gd, match_manager.gd, network_manager.gd)
│   └── abilities/
├── project.godot
└── .gitignore
```

### Character system — build this once, reuse for all 6 characters

Don't write 6 separate character scripts. Build one `CharacterBase.tscn` (CharacterBody3D)
with shared Move/Bump/Guard-or-Dash logic, then give each character an **Ability Resource**
— a small custom Resource script holding that character's special (cooldown, params, an
`activate()` function). Each of the 6 characters is just CharacterBase + a different Ability
Resource plugged into an exported slot, plus its own model/animations. Adding or rebalancing
a special later means editing one resource file, not hunting through a character-specific
script.

```gdscript
# ability_base.gd — extend this per special (quick_stand.gd, shatter_trap.gd, etc.)
extends Resource
class_name AbilityBase

@export var cooldown: float = 5.0

func activate(character: CharacterBody3D) -> void:
    pass # override in each specific ability script
```

### Networking approach

Use Godot's built-in high-level multiplayer (`ENetMultiplayerPeer`) — perfect fit for
same-wifi LAN, no relay/NAT setup needed.

- **Host-authoritative for anything that decides a round/match outcome**: Downed state,
  seal/capture checks, timer, score. The host is the source of truth so nobody's client-side
  quirks can flip a result.
- **Client-predicted for movement feel**: let each client move its own character locally for
  responsiveness, synced via `MultiplayerSynchronizer`; the host still validates hits.
- Keep this logic in a `NetworkManager` autoload (singleton) so gameplay scripts don't need
  to know or care whether they're the host or a client — they just call functions and the
  manager handles whether that becomes an RPC or a local call.
- **Test locally first** using Godot's "Run Multiple Instances" debug option (see Part 3)
  before testing across real devices — saves a ton of walking back and forth.

---

## PART 2 — GitHub Workflow

### Setup
1. One person creates the GitHub repo, adds everyone as collaborators.
2. Add a Godot `.gitignore` (GitHub has a template — search "Godot" when creating the repo,
   or use this):

```gitignore
.godot/
.import/
export.cfg
export_presets.cfg
*.translation
.mono/
data_*/
mono_crash.*.json
```

3. Godot 4 saves scenes/resources as **text** (`.tscn`, `.tres`) by default — that's great,
   it means Git can actually diff and merge them like code. Keep it that way (Project
   Settings → General → don't switch to binary format).
4. Binary assets (3D models, textures, audio) **do not** merge — if two people edit the same
   `.glb` or `.png`, one person's changes get silently lost. Consider **Git LFS**
   (`git lfs install`, then `git lfs track "*.glb" "*.png" "*.wav" "*.mp3"`) to handle these
   properly and keep repo size sane.

### Working together without stepping on each other
- **One branch per feature**, off `main`: `feature/can-movement`, `feature/networking`,
  `feature/map-eskinita`, etc. Small, frequent commits and merges — don't let branches sit
  for days, that's when conflicts pile up.
- **Scene files are the main conflict risk.** If two people are editing the *same* `.tscn`
  at the same time (e.g. the main arena scene), give each other a heads-up in chat first.
  Splitting shared scenes into smaller sub-scenes (e.g. each character is its own scene
  instanced into the map, rather than everything built inline in one giant scene) massively
  reduces this — it's already how the project structure above is set up.
- `main` should always be in a playable state if possible — merge into it deliberately, not
  as a dumping ground mid-feature.

---

## PART 3 — Getting Started with Godot

### 1. Install
- Download **Godot 4.7** (current stable) from **godotengine.org/download** — grab the
  Standard build (skip the .NET/C# build unless someone specifically wants C#; GDScript is
  faster to write and plenty for this scope).
- It's a single executable — no installer, just unzip and run it.

### 2. Create the project
- Open Godot → **New Project** → name it, pick a folder (this becomes your Git repo folder),
  set **Renderer** to **Forward+** (good default for 3D on desktop).
- This generates `project.godot` — that's the file that marks a folder as a Godot project.

### 3. The editor, quickly
- **FileSystem panel** (bottom-left): your project's files, mirrors the folders on disk.
- **Scene panel** (top-left): the node tree of whatever scene you have open — a "scene" in
  Godot is basically a reusable prefab/blueprint made of nodes (think: a character, a map, a
  UI screen — all scenes, all can be instanced inside other scenes).
- **Viewport** (center): the 2D/3D view of your current scene.
- **Inspector** (right): properties of whatever node you've selected.
- **Script editor**: opens when you attach/open a `.gd` script on a node.

### 4. Your first scene: basic character movement
- Create a new scene → root node type **CharacterBody3D**, rename it `CharacterBase`.
- Add a **CollisionShape3D** child (gives it a physical body) and a **MeshInstance3D** child
  (temporary capsule/box mesh is fine for prototyping — swap for real art later).
- Attach a new script to the root node:

```gdscript
extends CharacterBody3D

const SPEED = 6.0
const GRAVITY = 20.0

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= GRAVITY * delta

    var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

    if direction:
        velocity.x = direction.x * SPEED
        velocity.z = direction.z * SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED)
        velocity.z = move_toward(velocity.z, 0, SPEED)

    move_and_slide()
```

- Go to **Project → Project Settings → Input Map** and add the four actions
  (`move_left`, `move_right`, `move_up`, `move_down`) mapped to WASD or arrow keys — this
  is also where you'll later remap for multiple local players if you ever need the
  shared-screen fallback.
- Drop this scene into a test level with a floor (a big flat **StaticBody3D** + collision
  shape) and hit **Play** (F5) to try it.

### 5. Connect Git + GitHub
- If you don't have Git installed, install it, then in the project folder:
  ```
  git init
  git remote add origin <your-repo-url>
  git add .
  git commit -m "initial project setup"
  git push -u origin main
  ```
- After that, it's just normal Git — Godot doesn't require anything special beyond the
  `.gitignore` from Part 2. GitHub Desktop is a fine option if the command line isn't
  everyone's thing.

### 6. Testing multiplayer without needing 4 devices yet
- **Debug → Run Multiple Instances → 2 (or more)** lets you launch several copies of your
  game at once on one PC, each acting as a separate "player" — huge for testing your LAN
  networking code before dragging four laptops onto the same wifi to test.

### 7. Where to go deeper
- Official docs: **docs.godotengine.org** — the "Your first 3D game" tutorial in the official
  docs is a genuinely good next step after the above if you want a guided full build.
- Official multiplayer docs: search "High-level multiplayer" in the Godot docs when you get
  to Phase 3 (networking) — walks through `MultiplayerSpawner`/`MultiplayerSynchronizer`
  step by step.
