# Interaction Tuning Agent Brief — carry, throw, grab, reset channel

**Run this on: Sonnet 5, high effort.** High rather than medium because this touches
`carriable.gd`, `carrier.gd` and the throw profiles at the same time, and the host-authoritative
state transitions in there break subtly rather than loudly.

**Lane:** 🔧 Build. **Worktree:** `.worktrees/build`, branch `code/<task>` off `integration`.
**Checklist items owned:** **0.5** (retune from playtest notes), and the fixes that fall out of
**0.4**. Prerequisites 0.1, 0.2 and 0.3 belong to
[`UI_Completion_Agent_Brief.md`](UI_Completion_Agent_Brief.md).
**Paste-ready opener:** [`Agent_Prompts.md`](Agent_Prompts.md) → 🔧 Build lane.

---

## 0. The situation, stated plainly

The entire tumbang-preso mechanic — a Person carries a tsinelas, charges a throw, launches it on a
real ballistic arc at a guarded lata, then has to scramble out and retrieve it while the taya tries
to tag them — **is code-complete and has never been played by a human.** `Handoff.md` §0.8 says so
in its own words: *"nobody has pressed a button."*

Every number in it is a first guess made without ever seeing it move:

| Constant | Where | Current | Guessed? |
|---|---|---|---|
| `CHARGE_FULL_TIME`, `CHARGE_MIN_POWER` | `carrier.gd` | — | yes |
| `CRAWL_SPEED_SCALE` | `carriable.gd` | `0.45` | yes |
| `MAX_FLIGHT_TIME` | `carriable.gd` | `6.0` | yes |
| `THROWER_IGNORE_TIME` | `carriable.gd` | `0.25` | yes |
| `RESET_CHANNEL_TIME` | `carrier.gd` | `1.5` | yes |
| `GrabArea` radius | `CharacterBase.tscn` | `1.7` | yes |
| `arc_angle_deg`, `gravity_scale`, `launch_speed`, `steer_strength`, `spin_speed_deg` | 4 × `throw_*.tres` | — | yes, all |

**This is the highest-priority work on the project.** If the throw is wrong, most of the
environment work and all of the balance work gets redone anyway.

---

## 1. Read these first, in this order

1. **[`Checklist.md`](Checklist.md)** — Phase 0 in full. Your item is 0.5; 0.4 is the human
   playtest that produces your input.
2. **[`Concurrency_Protocol.md`](Concurrency_Protocol.md)** — an Opus design lane is working the
   same repo. §2 (path ownership), §3 (shared-file lock — `CharacterBase.tscn` is one), §8 (smoke
   gate).
3. **`Handoff.md`** §1–§2 (**frozen** — follow, do not rewrite), §0.7 (why the mechanic is shaped
   this way, and the alternatives that were rejected), §0.8 (what was and was not verified), §3
   (open bugs — **B-74, B-75, B-76** are yours), §4's `T-1`…`T-4` entries.
4. **`Dev_Plan.md`** §0 (standing directives — these override the GDD), §2 (architecture rules).
5. **`Tumbang_Preso_2v2_GDD.md`** Section 3's beat-by-beat loop and Section 4's throw identities.
6. **Then read the code**: `scripts/characters/carriable.gd`, `carrier.gd`, `throw_profile.gd`,
   `scripts/abilities/resources/throw_*.tres`, and `character_base.gd`'s `_physics_process`.

---

## 2. Traps already found in this code

These are load-bearing. Several were discovered the expensive way.

1. **Held state is deliberately NOT on `CharacterBase.tscn`'s `MultiplayerSynchronizer`,** even
   though that would be less code. That synchronizer replicates outward from each character's *own*
   peer, so routing held state through it would make it **client-asserted** — the exact opposite of
   the requirement. Clients call `_rpc_request_*` on the host; the host decides and broadcasts
   `_rpc_set_*` with `call_local`. **Do not "simplify" this.**

2. **The broadcasts are `"any_peer"`, not `"authority"`.** Resolution runs on the host, but a
   slipper's multiplayer authority is its own owning peer, so an `"authority"` RPC sent *by* the
   host is silently rejected. `CharacterBase._apply_hit_result` documents the same thing.

3. **`_step_carried` orthonormalises the hand transform.** A Person's model is scaled
   `PERSON_SCALE` (2.38) and every bone under its `Skeleton3D` inherits that, so copying the
   transform wholesale inflates the slipper 2.38× — with no error, just a comically large tsinelas.

4. **`HAND_CARRY_OFFSET` is in WORLD units, and is divided by `PERSON_SCALE` at the point of use**
   (`character_visual.gd::_build_hand_attachment`). It was **not**, until v4.21 — that was B-79, and
   it parked a carried slipper a metre to the character's left and above its own head. If you retune
   it, keep the division.

5. **`CharacterBase`'s origin is the CENTRE of a 1.6-unit capsule, so a model's feet are at `-0.8`,
   not `0`.** Four nodes were placed against an imagined character standing on `y = 0` and all four
   were wrong (B-78, B-79, B-80). Check this before positioning anything on a character.

6. **`get_hand_attachment()` returns null early in a match.** `CharacterVisual` instances the model
   from `CharacterBase._ready()`, so there is a real window where a Person exists and its hand does
   not. That is "not ready", never an error — `_step_carried` returns and retries next frame.

7. **The hand is a `Node3D` CHILD of the `BoneAttachment3D`, not the attachment itself.**
   `BoneAttachment3D` overwrites its own transform from the bone pose every frame, so an offset
   written onto it is silently discarded and the item sits at the elbow.

8. **`host_grab()` — not a hand-set state — is what disables the slipper's collision**
   (`_set_physics_enabled(false)` inside `_rpc_set_carried`). Setting `state = CARRIED` directly
   leaves the slipper's capsule solid inside its carrier's, and the two depenetrate and launch the
   pair into the sky. If you write a test harness, go through `host_grab`.

9. **`physics_step()` runs on EVERY peer, above `character_base.gd`'s `round_active` gate,
   deliberately** — every peer must run the carry maths and the authority gate sits below it. B-74
   is the consequence that was not thought through, and its fix (freeze `FLYING` while
   `not RoundManager.round_active`) is already in.

10. **Always `.duplicate()` an ability `.tres` per character.** Cooldown and charge state live on
    the Resource instance; two characters sharing one `.tres` share one cooldown.

---

## 3. Open bugs that are yours

- **B-76 · The three Tsinelas identities are unreachable in the running game.** `main.gd`'s
  `PROP_ABILITY` is `quick_stand.tres` for *every* Prop and `Main.tscn` hardcodes the same. Quick
  Stand has no `get_throw_profile()`, so every throw falls back to `throw_default.tres`. **The whole
  `throw_profile.gd` design is currently dead code in practice.** Checklist 0.2 is the interim fix
  (a per-side default) and it **blocks the playtest** — you cannot feel three throw identities that
  cannot be selected.
- **B-74 · [FIXED, untested]** A thrown slipper frozen mid-air by the round-end input freeze.
  Nobody has thrown one at the bell.
- **B-75 · [FIXED, untested]** Nothing dropped a carried slipper when its carrier was staggered,
  downed or sealed. `carriable.gd` now watches the carrier's `state_changed` while CARRIED. **Nobody
  has been tagged mid-carry.** This is most of the point of tagging — verify it early.

---

## 4. What "retune" actually means here

**Do not re-mark anything `[x]` because it loads without erroring.** That is precisely the failure
mode this project has repeated three times.

The input to this brief is the human's notes from checklist 0.4. For each number:

1. Change it.
2. **Run it and look at it** — `tools/render_probe.gd` renders the viewmodel and the match scene
   with a real rendering device.
3. Record the old value, the new value, and the one-line reason in the commit body. A tuning commit
   with no rationale is unreviewable and will be re-guessed by the next agent.
4. Numbers that are still guesses stay documented as guesses.

**Balance both round-win modes.** Option A (dents) and Option B (Downed → Seal) are both in active,
equal development — see `Handoff.md` §5. Do not deprioritise, skip or half-tune either on the
assumption the other will ship. The ship decision is the human's and blocks nothing.

---

## 5. Scope

### Yours
`scripts/characters/carriable.gd`, `carrier.gd`, `throw_profile.gd`, the four
`scripts/abilities/resources/throw_*.tres`, the Tsinelas ability scripts, `character_base.gd`'s
interaction gating, and the `GrabArea` shape on `CharacterBase.tscn` (**shared file — take the lock
first**).

### Explicitly NOT yours
- **The HUD meters** (checklist 0.1) — `UI_Completion_Agent_Brief.md`. You *depend* on them.
- **The tsinelas mesh and its scale** — Design lane, checklist 1.2.
- **Round-win logic.** `RoundManager` owns it. Nothing you write may put win conditions into
  `character_base.gd` or `hitbox.gd` beyond the single `GameLaunch.game_mode` branch already there.
- **Networking transport and interpolation** — `Netcode_Agent_Brief.md`.
- **Anything under `assets/` or `scenes/maps/`.**

---

## 6. Acceptance

- A human has played a full Bo5 in **both** game modes and the numbers reflect their notes.
- Tagging a carrier mid-carry makes them drop the slipper (B-75), confirmed by someone doing it.
- A slipper thrown at the bell behaves sanely (B-74), confirmed by someone doing it.
- All three Tsinelas throw profiles are reachable and feel distinct (B-76 / checklist 0.2).
- The reset channel completes, cancels on interrupt, refuses on the wrong team, and refuses with
  full hands.
- `godot --path . scenes/main/Main.tscn --quit-after 400` produces **no output at all**.
- All six commands in `Concurrency_Protocol.md` §8 before merging.

---

## 7. Non-negotiables, restated inline

- **Authorship.** Every commit is authored and committed solely as
  `M4tyu633 <matthewtlabrador@gmail.com>`. No `Co-authored-by:`, no mention of Claude, an AI
  assistant, or any tool anywhere in a commit. Verify:
  ```bash
  git log -1 --format='%an <%ae> | %cn <%ce>'
  ```
- **Camera directive.** Person → FPP always, Prop → TPP always, derived from `is_person`, no
  toggles. The enforcement grep must return nothing:
  ```bash
  grep -rn "_mode = \|Mode\.FPP\|Mode\.TPP" scripts/ | grep -v camera_rig.gd
  ```
- **Architecture.** One `CharacterBase` scene, abilities as `.tres` Resources. Round-win logic out
  of `character_base.gd` and `hitbox.gd`. The host is authoritative for anything that decides a
  round.
- **Debug code** follows `Dev_Plan.md` §0.3's removal contract without exception: `debug_`/`Debug`
  prefix, one-way dependency (gameplay never references debug, not even behind
  `OS.is_debug_build()`), no `[input]` map entries, self-disabling in release, and a removal
  checklist written at the same time as the feature.
- **Verify before claiming `[x]`.** A `--quit` smoke test never executes a frame of `_process()`;
  that is how B-77 survived in `main.gd` for weeks, throwing on every single launch.
- **One concern per commit**, checklist item and B-number in the subject. Do not bump
  `application/config/version` in a feature commit while two lanes are running.

## 8. Reporting contract

Say what you changed and why, with old and new values for every number. Separate what a human
confirmed by feel from what you confirmed by running from what is only reasoned about. File any new
defect as the next free `B-` number in `Handoff.md` §3 with an exact reproduction. Say plainly what
you did not get to — silently narrowing scope is against this project's stated norms. If a task
turns out to be already done, say so and move on rather than rewriting working code.
