# UI Completion Agent Brief

**Run this on: Sonnet 5, medium effort.** The HUD, the menus and the theme are already built and
already match the moodboard closely — this is finishing specified work, not designing it. If you
hit a genuine *"I don't know what this should look like"* wall, do **not** guess: write it into
`Handoff.md` §5 and move on. It queues for the Opus design lane.

**Lane:** 🔧 Build. **Worktree:** `.worktrees/build`, branch `code/<task>` off `integration`.
**Checklist items owned:** **0.1** (charge / hold / reset-channel meters — *do this first, it
blocks the playtest*), **0.3** (base circle + throwing line), **3.1** (land the typeface),
**3.3** (character select), **3.4** (off-screen indicators).
**Paste-ready opener:** [`Agent_Prompts.md`](Agent_Prompts.md) → 🔧 Build lane.

---

## 0. Correct a claim you will hear repeated

**The HUD is not placeholder-styled and has not been for some time.** Verified by rendering it on
2026-07-27: it already has role-coloured team panels with three Bo5 pips each, a framed timer with
`HIGHLIGHT` under 15 s and a scale pulse under 10 s, a LATA dent card, the YOU card with its
Guard/Dash meter, an FPP-only crosshair, a downed **vignette** (not the old flat red rectangle),
and a role-swap intermission card. `Dev_Plan.md` §4.4's layout is essentially shipped.

Any doc telling you the HUD is "a centred column of stacked Labels" is describing v2.x. Do not
rebuild it. **What is actually missing is §1 below.**

---

## 1. 0.1 — the meters. Start here; it blocks the first human playtest.

`carrier.gd` emits three signals and **nothing anywhere consumes any of them**:

| Signal | Range | What it is for |
|---|---|---|
| `charge_changed(power)` | `0..1`, `-1` = inactive | hold-to-charge throw strength |
| `held_changed` | — | SLIPPER READY vs GO GET IT |
| `reset_channel_changed(progress)` | `0..1`, `-1` = inactive | the 1.5 s lata reset channel |

Without these, a tester holding the throw button gets **no feedback at all** — they cannot see the
charge build, cannot tell a half-charged throw from a full one, and cannot see a channel they are
1.2 seconds into. Checklist 0.4 (the first human playtest) is what turns a dozen guessed constants
into measured ones, and it is not meaningfully possible until this lands.

It is also the moodboard's own spec: **THE ATTACKER** card illustrates *charged throw (glow)* and
**THE DEFENDER** card illustrates *lata reset channel (progress bar)*.

**Scope discipline on this one:** `scenes/ui/HUD.tscn` is a **shared file** — take the lock in
`SHARED_LOCKS.md` first. Add the nodes with plain styling and prove the values move; the Opus
design lane restyles afterwards. **Structure first, style second** — never interleave.

Read `hud.gd` first: it already reads the autoloads directly and resolves the local character
through `you_card.get_local_character()`. **Reuse that helper. Do not write a third copy of the
scan** — that is exactly what A-1 step 4 was written to prevent.

---

## 2. The other items

- **0.3 · Base circle and throwing line.** Two floor decals in `Main.tscn` (**shared file — take
  the lock**). The game is named after a can standing in a circle and the circle is nowhere in the
  world; Option B's Downed/Seal read is meaningless without it. **Deliberately temporary** —
  checklist 2.2 replaces them with real map geometry. Say so in the commit so nobody polishes them.
- **3.1 · Land the typeface.** ⛔ **Blocked on checklist 1.1, a human decision.** Do not download a
  font binary without an explicit written yes; that gate is correct and is not being relitigated.
  Once a face exists it is mechanical: commit the `.gitattributes` LFS rules for `*.ttf`/`*.otf`
  **before** the binary (or the first font lands as a raw blob and has to be rewritten out of
  history), drop the face plus its verbatim licence at `assets/ui/fonts/` following the
  `KENNEY_LICENSE.txt` pattern, add a clean grotesque for body text (**Inter** or **Work Sans**,
  both OFL — the marker face is illegible at `FONT_SIZE_CAPTION` 13), wire `DISPLAY_FONT` /
  `BODY_FONT` in `ui_theme.gd` **as type variations only**, regenerate with
  `godot --headless -s tools/regenerate_ui_theme.gd`, record the licence for Form 03, and delete
  the stale blocker notes at the top of `ui_theme.gd` and in `Handoff.md` §0.5. A stale blocker is
  worse than no blocker. **`ui_theme.gd` is Design-lane-owned — coordinate, or hand this step over.**
- **3.3 · Character select.** ⛔ Partly blocked on checklist 1.3. Six Prop cards on U-2's existing
  card chrome, selection into `GameLaunch`, replicated with the ready-up state, read in
  `_build_networked_character()` **in place of** the hardcoded `PROP_ABILITY`. If 1.3 (does the
  Person get its own roster?) is still unanswered when you reach this, **build the Prop half and
  say plainly that the Person half is blocked** — do not invent a Person roster.
- **3.4 · Off-screen indicators.** Screen-edge arrows for your teammate and the Can. `Dev_Plan.md`
  §3.3 calls these **mandatory** for FPP — they are the promised mitigation for the Person's
  narrower awareness cone, and U-6 deferred them. Derive the local character from
  `you_card.get_local_character()`, same rule as §1.

---

## 3. Traps already found in this code

1. **`.duplicate()` every ability `.tres` per character.** Cooldown and charge state live on the
   Resource instance — two characters sharing one `.tres` share one cooldown. This is the trap
   `main.gd`'s own comment already warns about and 3.3 walks straight into it.
2. **`theme_type_variation`, never `theme_override_*`.** `ui_theme.gd` exists to abolish per-node
   overrides; that is what fixed the B-34 invisible-button contrast trap at the root. Adding one
   back re-creates the problem one control at a time.
3. **`UiTheme` defines `CARD`, not `PAPER`.** Docs naming a `PAPER` token are stale.
4. **Role colour is derived from `team_is_can_side`, not from `is_person` and not from `team`.**
   `you_card.gd::refresh()`, `hud.gd::set_round_display()` and `character_nameplate.gd::refresh()`
   all use the same derivation. **Do not write a fourth copy**, and do not key anything off
   `is_person` — that was B-80(b), which made every Person orange and every Prop blue on both teams
   at once.
5. **Role flips every round, so anything role-coloured must refresh on
   `MatchManager.round_started`.** A value resolved once in `_ready()` is right for round 1 and
   wrong for rounds 2–5. B-42, `debug_refresh_readout()`, the YOU card and B-80(c) each hit this
   independently.
6. **Every panel that can be entered must be exitable.** A `Back`/`Esc` path is part of the
   definition of done for a screen, not a follow-up. Re-verify after any restyle — a change that
   breaks a focus chain is easy to miss.
7. **A late-joining peer never sees `round_started` for the round already in progress** (B-29).
   `main.gd::_sync_state_to_late_joiner` calls the public refresh helpers directly. Anything new
   that caches round state needs the same treatment.
8. **`Main.tscn`'s `MatchResult` runs at `process_mode = 3`** so it survives the pause freeze.
   Anything that must remain clickable while paused needs the same.

---

## 4. Scope

**Yours:** `scripts/ui/*.gd` except `ui_theme.gd`, and the structural half of `scenes/ui/*.tscn`
and `Main.tscn` (both **shared — lock first**).

**Explicitly NOT yours:** `ui_theme.gd` and the generated theme resource (Design lane); the visual
restyle pass that follows your structural work; anything under `assets/` or `scenes/maps/`; the
carry/throw state machine itself (`Interaction_Tuning_Agent_Brief.md` — you surface its signals,
you do not change its behaviour).

---

## 5. Acceptance

- Hold the throw button: the charge bar fills and empties on release. Hold `grab` beside a downed
  own-team lata: the channel bar fills over `RESET_CHANNEL_TIME` and resets when you are
  interrupted. Screenshot both.
- At 1920×1080 **and** 1280×720, nothing collides or leaves the viewport. Fix by anchor, not by
  nudging offsets — an offset fix re-breaks at the next resolution.
- Play into round 2: every role-coloured element recolours.
- `godot --path . scenes/main/Main.tscn --quit-after 400` produces **no output at all**.
- All six commands in `Concurrency_Protocol.md` §8 before merging.

---

## 6. Non-negotiables, restated inline

- **Authorship.** Every commit authored and committed solely as
  `M4tyu633 <matthewtlabrador@gmail.com>`. No `Co-authored-by:`, no mention of Claude, an AI
  assistant, or any tool anywhere in a commit. Verify with
  `git log -1 --format='%an <%ae> | %cn <%ce>'`.
- **Camera directive.** Person → FPP always, Prop → TPP always, derived from `is_person`. **Do not
  add a `camera_mode` field to the HUD** — one derivation, one place (A-1 step 4).
- **Orange = OFFENSE, blue = DEFENCE, project-wide; the accent tracks role, never team.** Team
  identity is the A/B letter mark, never hue.
- **Both round-win modes stay in active, equal development.** Anything you build that reads
  `GameLaunch.game_mode` must work properly in both, not degrade in one.
- **Verify before claiming `[x]`.** A `--quit` smoke test never executes a frame of `_process()`.
- **One concern per commit**, checklist item in the subject. Do not bump
  `application/config/version` in a feature commit while two lanes are running.

## 7. Reporting contract

Say what you changed and why, with a screenshot for anything visual. Separate what you verified by
running from what is only reasoned about. File new defects as the next free `B-` number in
`Handoff.md` §3 with an exact reproduction. Say plainly what you did not get to and why — this
project has an established, enforced norm against silently narrowing scope. If a task is already
done, say so and move on rather than rewriting working code.
