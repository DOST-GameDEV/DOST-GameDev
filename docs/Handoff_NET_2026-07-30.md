# HANDOFF — 🌐 NET lane, 2026-07-30

Written for the next NET agent. `integration` @ `d29b732`, **v4.68** (version NOT bumped).
Everything below was measured on this MacBook, not reasoned about.

---

## CLOSED THIS SESSION

### NET-1 · prop stats read as identical — CLOSED, and the documented cause was WRONG

The handoff hypothesis (silent-neutral at `can_index = -1` because the pick never crossed the
wire) was **refuted by measurement**. Instrumenting `main.gd::_build_networked_character` showed
the host holding `{"character":0,"can":4,"slipper":1}` for the peer that sent it. The picks cross
perfectly.

**The real cause is SEATING.** A 2v2 has four seats; each human occupies exactly one. With fewer
than four humans the rest are AI sentinels (`_fill_empty_slots_with_placeholders`, `peer_id < 0`),
and an AI slot has no picks by design — so every lata and tsinelas actually in play belonged to a
bot and read the neutral 3/3/3. The picker was working; it was decorating a chair nobody sat in.

🧑 approved the fix: **an AI-held Prop seat inherits the prop picks of the human on its own team**
(`main.gd::_team_prop_picks`), on both the networked and the local/solo path. A fully-bot team
still resolves neutral, which is correct.

**That uncovered a second, older bug.** `_rpc_reclaim_character` — how an arriving peer steps into
a placeholder's body — never re-applied picks, because `_build_networked_character` does not run
for a body that already exists. Invisible while the placeholder held -1 (indistinguishable from
the fallback); once it held the teammate's picks it became a human visibly wearing someone else's
lata.

⚠️ **And the first fix for THAT measured no change at all.** Writing picks on the host *after*
`set_multiplayer_authority` hands the node over is a write the new authority immediately
overwrites with its stale copy — host set 4→3, client pushed 4 straight back, on both machines.
The write now happens **before** the hand-over, and the peer taking ownership also writes its own
picks from its own `GameLaunch`. No new RPC — these are replicated properties with `spawn = true`.

Measured, `net_spawn_probe -- --host can=pintura slipper=bakya` / `--join=127.0.0.1 can=kape
slipper=luma`, 4 rounds: both peers report `can_index=3 slipper_index=5` on the client's Prop,
byte-identical, and the role swap flips `CANS[3]=kape 5/2/1` ↔ `SLIPPERS[5]=luma 5/1/2` — so
`is_can` is re-read and never cached. A single-peer run confirms inheritance.

⚠️ **What is NOT done: the OBSERVABLE.** Spec item (c) asked for metres walked / m/s of shove, not
a `trait_points()` lookup. The indices and the resolved trait triple are proven to reach the unit
on both peers; **`prop_trait` has still never been measured against a physical observable.** The
PERSON path has that (`Checklist.md` § CHARACTER TRAITS · VERIFIED END TO END); the PROP path does
not. **Pick this up.**

### The left-click wind-up — 🧑 "i cant wind up as attacker?? i cant even throw no more"

The user's own guess ("this broke bcz i overhauled controls earlier") was right.

⚠️ **`project.godot` was never wrong; the runtime was overwriting it.** It binds
`special_ability` to Q, LEFT CLICK and RIGHT CLICK, and the tutorial advertises "Q / LEFT CLICK ·
Special". But `SettingsManager` applied every saved KEY binding with
`InputMap.action_erase_events(action)` — which erases mouse and pad events too — then re-added a
single `InputEventKey`. That ran in `_load()` **at startup, for every action in
`user://settings.cfg`**, so any player with a settings file lost left click on every launch. No
rebind needed to trigger it.

Measured: `settings.cfg` holds `special_ability=81`; a runtime InputMap dump read
`special_ability -> key:Q` with no mouse event, while `grab` (not rebindable, never touched) still
had `E, MOUSE:1` — so left click grabbed and could never wind up. After the fix:
`MOUSE:1, MOUSE:2, key:Q`, and `input_probe` measures **peak charge 0.807** on a held left click,
up from a wind-up that never started.

`project.godot` is **UNCHANGED** — the lock was claimed, the file cleared, the lock released.

### NET-2 · `input_probe` no longer blocks R-30

`input_probe.gd:70` was a bare `DebugPlayerSwitcher._cycle()` — a compile-time autoload reference,
so R-30 deleting that autoload made the file fail to **PARSE**, while "input_probe green" is part
of R-30's own acceptance. Now resolved through `get_node_or_null` at runtime; the switcher half
reports itself skipped when the autoload is absent, and the default-state isolation checks still
run.

### NET-4 · the §3.5.5 grep, re-baselined

Confirmed again on this machine: **no `.worktrees/` directory, one worktree, `code/windows-deploy`
merged and deleted.** That paragraph is a Windows-machine artifact — do not add
`--exclude-dir=.worktrees`.

Current baseline, `grep -rl -i debug --include='*.gd' --include='*.tscn' .` excluding `.godot/`:
**18 files** — unchanged from the handoff's own count.

Still the real content of the item: the rewording is **more than the 5 files the plan names**,
`carriable.gd` is a false positive on the words "debug cruft", and **`character_base.gd` is
SHARED-LOCK**, so R-30 needs a mutex its plan omits. **R-30 stays 🔴 BLOCKED**; delete nothing yet.

### Two probe gaps closed — both had been passing over real defects

- `input_probe` checked that every action was bound to *something* and was structurally blind to
  the opposite mistake: one physical input bound to two actions. It now reports conflicts.
- `net_spawn_probe` exempted bot Props via `ai_controller != null`, which is **host-only** — so on
  a client every unit read as human-owned and the exemption silently inverted into "gate
  everything". Caught only because the two logs disagreed about unit `-4` in the same second. Now
  keyed on the sentinel `peer_id`, which both peers share.

---

## OPEN — pick up here

### A. ⚠️ `input_probe` IS RED, ON PURPOSE — Space drives BOTH `jump` and `bump`

The new conflict check immediately found a second, unrelated collision:
`key:Space -> jump, bump`. Both are read (`character_base.gd:942` jump, `:951` bump), and both are
saved in `settings.cfg` as `32`. Pressing Space jumps AND melees.

**Left deliberately unfixed — it is a design call about which action Space should be, and it is
🧑's.** Ask before changing it. Until then `input_probe` exits 1 on a genuine defect, which is the
correct state, but it does mean **"input_probe green" cannot be claimed for R-30 yet.**

### B. ⚠️ A HUD ELEMENT RUNS OFF THE BOTTOM OF THE SCREEN — reported, NOT fixed

🧑, with a screenshot: *"ui goes below screen, pls make sure no ui goes below screen."* The **YOU
card** at bottom-left is clipped — "SLIPPER READY" is cut in half by the screen edge. This is
`scenes/ui/HUD.tscn` / `YouCard.tscn`, in-match, and it is **NOT** the setup-screen overflow that
was fixed earlier (that one is done and verified).

`tools/ui_layout_probe.gd` already renders the HUD, but its `WATCHED` list contains no HUD nodes
beyond `DetailLabel`, so it never looked. **Add `YouCard` (and the other HUD anchors) to `WATCHED`
and fix what it reports.** The probe's containment assertion (`CONTAINED`) is the right shape for
"inside its own panel"; the viewport check is the right shape for "off the bottom".

⚠️ Read `ui_layout_probe.gd`'s own notes first — two of its checks were vacuous and were replaced
this session, and the reasons are written down so they are not re-introduced.

### C. NET-3 · `hit_probe` reports 0 throws on real peers

Untouched. `tools/hit_probe.gd:223` waits on `RoundManager.round_active` and presses nothing;
nothing starts a networked round until every peer sends `_rpc_declare_ready`
(`main.gd::_awaiting_net_ready` — the host counts PEERS, not characters).
`aim_probe.gd::_net_ready_up()` is a working implementation to copy, polled rather than
signal-driven because `_awaiting_net_ready` is only set once the host's own phase RPC arrives.

⚠️ **`hit_probe` DOES drive 40 throws on the LOCAL path** — re-measured clean this session
(`EVERY OVERLAPPING THROW LANDED`, 40 throws). **A green local run is not evidence for this item.**

### D. NET-5 · R-09's remaining acceptance — `lobby_probe` difficulty assertion

Untouched. Spec: `Checklist.md` § "HANDOFF — R-09's REMAINING ACCEPTANCE". Two peers on
deliberately opposite difficulties; the client must end on the HOST's. Add a third field to the
map/mode assertion `lobby_probe` already makes — do not write a new probe.

⚠️ **BOTH call sites matter:** `_rpc_sync_config` (host changed something) AND `_rpc_sync_state`
(the welcome packet — the only thing that configures a peer joining a lobby nobody touches
afterwards). Asserting only the first passes while a quiet-lobby joiner silently keeps its own
tier. Per-peer match-affecting values are the U-8 bug class, fixed twice.

⚠️ The tier labels are now **EASY / NORMAL / HARD** (were BATA / NORMAL / ASTIG) — a copy change
landed this session. Index order is unchanged.

### E. B-144 · `aim_probe` fails its own aim clause and exits 1

Untouched, and 🧑 has granted the fix. Full entry `docs/Handoff.md` §3 B-144. 0.41 m against a
0.40 m mark; `aim_probe.gd:514` calls `get_tree().quit(1)`, so any exit-code gate is red.

⚠️ **ANSWER THE RANGE QUESTION FIRST — it is cheap and it decides everything else.** `PITCHES`
aims at whatever the ray hits, which at +0.0 and +10.0 pitch is a wall **~24 m** out. **The
throwing line is z = -6.0. Six metres.** `phys_probe -- band` at gameplay range reports flat 3/3
on the can out to 0.30 m. If no throw in the game travels 24 m, the audit is failing on a shot
nobody takes and the fix is the AUDIT'S GEOMETRY. Only if the miss reproduces inside ~10 m is it a
solve bug.

⚠️ **DO NOT relax `PASS_WITHIN` and DO NOT make it proportional** — that recommendation was
formally withdrawn. `PASS_WITHIN`'s own comment justifies 0.40 m by the tightest shipped
`hit_radius`, 0.30 for flick.

⚠️ **SCOPE:** you may edit `tools/aim_probe.gd`. You may **NOT** touch `carriable.gd` or
`carrier.gd` — 🥊 PHYS's, and `character_base.gd` next door is shared-lock. If the answer is in the
solve, produce the numbers and **HAND IT BACK**.

### F. Granted but not started — `ai_controller.gd` and `ai_probe.gd`

🧑 granted both explicitly this session ("fix 2"). Neither was touched.

- **`scripts/systems/ai_controller.gd`** — R-06 leg 3: **hold the sidestep, do NOT widen it**
  (`CAN_EVADE_STEP` already aims 2.7× the measured 0.45 m band, and the can returns to 0.31 m of
  the mark by impact). And `ATTACKER_LOB_OVERHOLD` should **READ** `Carrier.LOB_OVERHOLD_TIME`
  rather than restating 0.20. PHYS side of both is done. Spec: `Checklist.md` § "R-06 leg 3 ·
  MEASURED".
- **`tools/ai_probe.gd`** — dents/round fell 1.75 → 1.00 while `blocked` *improved* 43.5% → 41.2%;
  one of those columns is wrong. And **`GameLaunch.game_mode` DEFAULTS TO OPTION_B, which has
  never been in a fairness run at all** — FALL_LIMIT 4 and all-Sealed have no measured rate. That
  is the larger hole.

### G. The lane charter, still untouched

R-23 four peers + a loss/latency shim (**longest lead time on the project**) → R-24 stress the AI
fallback with real drops → R-25 a clean host-quit story → R-26 late join and lobby under load.
R-26's lobby half is marked 🔴 on this lane by the UX lane.

---

## CONTEXT WORTH NOT RE-DERIVING

- **Seating decides who wears a pick.** Seats are `[person, prop]` per team; `team = index / 2`,
  even index is the Person. `_token_join_index` maps token → seat and `NetworkManager.peer_tokens`
  maps peer_id → token; that pair is how you get from a seat to a peer.
- **`peer_characters` is host-only.** A client asking about anyone gets -1, and that is correct —
  the picks arrive as replicated properties, not by asking. Do not invent a second broadcast path
  (U-8, fixed twice).
- **`set_multiplayer_authority` changes who wins.** After the hand-over the ARRIVING peer's values
  are what the synchronizer pushes. Any host-side write to a replicated property must happen
  before it.
- **A copy change can break a layout.** Renaming `SINO:` → `CHARACTER:` doubled a caption's
  minimum width and pushed its row-mate through the panel edge. `ui_layout_probe.gd` now has a
  containment assertion for exactly this.
- **The trait `key` StringNames (`&"bilis"` etc.) are internal and unchanged**, even though the
  displayed stat names are now English. Renaming a key is a silent flat-3 fallback on every roster
  entry — `_trait_value()` resolves a missing key to `TRAIT_NEUTRAL` without erroring.
- **Impossible-number rule, still earning its keep.** Three faults were caught by it this session
  and none by inspection: the client log calling unit `-4` human-owned while the host called it a
  bot; the client printing `can=kape(3)` while its unit reported `can_index=4`; and a text-overflow
  check reporting "every label fits" against a screenshot showing a control hanging off its panel.
