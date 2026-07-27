# Audio Agent Brief

**Run this on: Sonnet 5, medium effort.** Sourcing, wiring and licence bookkeeping. It touches no
shared scene and no networking, which makes it the safest workstream to run in parallel with
anything else.

**Lane:** 🔧 Build. **Worktree:** `.worktrees/build`, branch `code/audio-<slice>` off
`integration`. **Checklist item owned:** **4.1** — the entire audio workstream.
**Paste-ready opener:** [`Agent_Prompts.md`](Agent_Prompts.md) → 🔧 Build lane.

---

## 0. Starting position

**There is nothing.** Verified by grep on 2026-07-27: not one `AudioStreamPlayer`,
`AudioStreamPlayer3D`, `AudioStream` or `AudioServer` reference anywhere in `scripts/` or
`scenes/`. `assets/audio/` contains a single `.gitkeep`. There is no bus layout, no volume setting,
no mixer.

This is a bigger deal than its checklist position suggests. **A lata taking a direct hit in silence
reads as a bug to a judge no matter how good the mesh is.** `Handoff.md` §6 has flagged audio as an
unscheduled critical-path item for three passes and it has never had an owner.

---

## 1. Read these first

1. **[`Checklist.md`](Checklist.md)** — item 4.1, and Phase 6 for why licences matter early.
2. **[`Concurrency_Protocol.md`](Concurrency_Protocol.md)** — §2 path ownership, §8 smoke gate.
3. **`Handoff.md`** §1–§2 (**frozen** — follow, do not rewrite), §6 (audio as critical path).
4. **`Dev_Plan.md`** §0 (standing directives), §5 Phase 5, §6 (`git lfs install` before any binary).
5. **`Tumbang_Preso_2v2_GDD.md`** §6 (the esports/spectator layer — the downed state has to read
   instantly on stream) and §9 (submission checklist — Form 03).
6. Then: `scripts/systems/settings_manager.gd` (where a volume setting belongs),
   `scripts/characters/character_visual.gd` (the existing hit-feedback pattern to mirror),
   `scripts/systems/round_manager.gd` and `match_manager.gd` (the signals worth hooking).

---

## 2. The minimum viable set

Ordered by how much each one adds per unit of work. **Ship them in this order** and merge after
each — a partial set that lands is worth more than a complete set that does not.

| # | Cue | Fires on | Why it earns its place |
|---|---|---|---|
| 1 | **Slipper impact on lata** | `Hitbox` resolution, host-broadcast | The single most important sound in the game. It is the win condition being met. |
| 2 | **Lata knocked down / sealed** | `CharacterBase.state_changed` → `DOWNED` / `SEALED` | The round turning. Must read on a stream (GDD §6). |
| 3 | **Slipper release** | `carrier.gd` throw | Confirms the charge released and at what power — pitch or layer it by `charge_power()`. |
| 4 | **Bump connect / blocked** | `flash_hit()` / `flash_blocked()` | Two distinct sounds. A blocked hit must never be mistaken for a landed one — that is exactly why `flash_blocked` is DEFENSE-tinted rather than white. |
| 5 | **Reset channel complete** | `carriable.gd::host_reset_upright` | The defender's payoff beat. Consider a rising tick during the channel too. |
| 6 | **Round win / match win** | `RoundManager.round_won` / `MatchManager.match_won` | |
| 7 | **Slipper lands loose** | `host_land()` | The cue that starts the retrieval scramble. |
| 8 | **Ambience, one loop per map** | map scene | Last, and only after checklist 2.2 exists. |

**Do not add hitstop.** That is checklist 4.5 and it belongs with the feel pass.

---

## 3. How to wire it — follow the existing pattern

The project already solved "a cosmetic reaction to a gameplay event that must reach every peer",
twice. Copy it rather than inventing a third shape.

- **`character_visual.gd` owns what a unit looks like; `character_base.gd` never learns about
  meshes, dents or clip names.** Audio takes the same rule: **`character_base.gd` must not learn
  what anything sounds like.** Put per-unit audio next to the visual, driven by the same signals it
  already listens to (`state_changed`, `dents_changed`).
- **Q-8/B-66 is the precedent for networked cosmetics.** The hit flash originally fired only on the
  struck character's own owning peer; `_rpc_play_hit_vfx()` was added to broadcast it to everyone.
  **Any audio cue attached to a host-resolved event needs the same treatment or three of four
  players hear nothing.** This is the single most likely bug in this workstream.
- **Use `AudioStreamPlayer3D` for anything with a position in the world** (impacts, the lata, the
  slipper) so it pans and attenuates — that is free spatial information for an FPP player with a
  narrow awareness cone. Use plain `AudioStreamPlayer` only for UI and music.
- **Add a bus layout** (`Master` → `SFX`, `Music`, `UI`) and put **master / SFX / music volume in
  `SettingsManager`** along`mouse_sensitivity` and `invert_y`, with the same persistence. A game
  that gains audio and no volume slider is a regression for anyone testing it.

---

## 4. Traps

1. **`git lfs install` before adding a single audio file.** `.gitattributes` already tracks
   `.wav/.mp3/.ogg`. A binary committed without LFS has to be rewritten out of history.
2. **`.ogg` for everything.** Godot imports `.wav` as uncompressed; a handful of ambience loops will
   bloat the repo and the export.
3. **Every asset needs a recorded licence, at the moment it lands, not at the deadline.**
   Submission **Form 03** is an asset and AI usage disclosure. Follow the existing pattern:
   `assets/characters/persons/KENNEY_LICENSE.txt` sits beside what it covers, verbatim. Prefer CC0
   (freesound.org CC0, Kenney's own audio packs) so the disclosure is one line and redistribution
   is unambiguous. **Tell the 📦 Producer lane about every asset you add** — it maintains the
   running register.
4. **Do not put audio in `character_base.gd`.** See §3.
5. **Do not add debug-only sound.** If you want an audible probe, it follows the full removal
   contract in `Dev_Plan.md` §0.3 — `debug_` prefix, one-way dependency, no `[input]` entries,
   self-disabling, removal checklist written at the same time. Simpler not to.
6. **Autoloads persist across scene changes.** If you add an audio manager autoload, give it a
   `reset()` and call it where `MatchManager.reset()` is called, or a looping cue survives into the
   menu. That was B-14's whole lesson.

---

## 5. Scope

**Yours:** `assets/audio/**`, a new audio autoload or per-unit audio nodes,
`scripts/systems/settings_manager.gd`'s volume settings, and the bus layout.

**Explicitly NOT yours:** the visual half of hit feedback (already done — Q-8); hitstop (4.5);
anything under `scenes/maps/` (Design lane — hand them the ambience stream and let them place it);
`ui_theme.gd`; the carry/throw state machine's behaviour. If a cue needs a signal that does not
exist, **ask for it in `Handoff.md` §5** rather than adding logic to a gameplay script yourself.

---

## 6. Acceptance

- All eight cues fire, in a two-instance networked session, **on every peer** — not just on the one
  whose character was involved. This is the B-66 failure mode and it is the acceptance test that
  matters most.
- Volume sliders exist, apply immediately, and persist across a restart.
- Nothing loops into the main menu after a match ends.
- Every file in `assets/audio/` has a licence file beside it, and `git lfs ls-files` lists them.
- `godot --path . scenes/main/Main.tscn --quit-after 400` produces **no output at all**.
- All six commands in `Concurrency_Protocol.md` §8 before merging.

---

## 7. Non-negotiables, restated inline

- **Authorship.** Every commit authored and committed solely as
  `M4tyu633 <matthewtlabrador@gmail.com>`. No `Co-authored-by:`, no mention of Claude, an AI
  assistant, or any tool anywhere in a commit. Verify with
  `git log -1 --format='%an <%ae> | %cn <%ce>'`.
- **Camera directive.** Person → FPP always, Prop → TPP always, derived from `is_person`. Audio
  must not assume a listener position that contradicts it — the `AudioListener3D` follows the
  active camera, whichever mode that is.
- **Architecture.** `character_base.gd` never learns what anything looks or sounds like. Host is
  authoritative for anything that decides a round; cosmetics broadcast to every peer.
- **Both round-win modes stay in active, equal development.** Option B's seal beat and Option A's
  third dent both need a sound; do not cover only one.
- **Verify before claiming `[x]`.** If you could not run it, it is `[~]` and you say what is
  unverified.
- **One concern per commit.** Do not bump `application/config/version` in a feature commit while
  two lanes are running.

## 8. Reporting contract

List every asset added with its source and licence, so Form 03 is a copy-paste and not an
excavation. Say which cues you confirmed on a second peer versus which you only heard locally. Say
plainly what you did not get to and why.
