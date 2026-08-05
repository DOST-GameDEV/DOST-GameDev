# Handoff — trajectory arc and the taya's lunge

**What this is:** three small, self-contained fixes made on `fix/trajectory-lunge-backup` before
the skin investigation. All three are one-liners with a long "why", and each was a real reported
defect.

| | |
|---|---|
| **Branch** | `fix/trajectory-lunge-backup` |
| **Cut from** | `backup/dedicated-lobbies-starrayx-2026-08-05` |
| **Commits** | `9ed81d6`, `c250099` |
| **Status** | fixed; verified statically and against the parse baseline, **not confirmed in real play** |

---

## Issue 1 — the aiming arc vanished in Single Player after a networked match

**Symptom:** the dotted throw trajectory works, you play a LAN/online match, you go back to
Single Player in the same session, and the arc is gone.

`carrier.gd::_update_trajectory()` gated on `is_multiplayer_authority()` alone. That check lies in
exactly one sequence: Single Player, **after** the process has hosted or joined earlier.
`NetworkManager.disconnect_network()` (and its failure/disconnect siblings) tear a session down
with `multiplayer.multiplayer_peer = null` rather than restoring the engine's offline default, so
`multiplayer.get_unique_id()` stops returning `1` for the rest of the process's life — even though
the character's own `multiplayer_authority` is still `1` and `is_networked()` correctly reports
false.

Identical root cause to the emote bug already fixed in `character_base.gd::try_emote()`. The same
`is_networked()`-gated fallback was applied:

```gdscript
var is_mine := _character.is_multiplayer_authority() if NetworkManager.is_networked() \
    else _character.player_id == 1
```

⚠️ This is a **class** of bug, not one site. Any unguarded `is_multiplayer_authority()` that can
run in local play has it. `carrier.gd` had exactly one; it was the last.

**Fixed in** `9ed81d6`.

---

## Issue 2 — no Lunge row in Settings

`SettingsManager.REBINDABLE_ACTIONS` listed `"grab"` **twice** and never listed `"lunge"` — a
copy/paste slip from the commit that introduced the tag mechanic. The taya's only scoring verb had
no rebind row. Added, with its `ACTION_LABELS` entry.

**Fixed in** `9ed81d6`.

---

## Issue 3 — E kept lunging regardless of the Lunge keybind

Once the row existed, rebinding it still did nothing:

```gdscript
func _lunge_pressed_now() -> bool:
    return input_just_pressed("lunge") or input_just_pressed("grab")
```

`grab` is a **separate, independently rebindable** action that happens to default to `E`. So E
lunging was always riding on `grab`'s binding, never on `lunge`'s — and `Settings > Lunge` could
not affect it.

Fix: gave `lunge` its own default `E` `InputEventKey` in `project.godot` (alongside its existing
right-click) and dropped the `grab` fallback from both checks. `lunge` is now self-contained.

⚠️ `E` is still **contextual** and the order still matters: `carrier.gd` gets first refusal on the
press for the lata reset channel, and only an unclaimed E falls through to the lunge. That
behaviour is unchanged — see `character_base.gd::_lunge_pressed_now()`'s own note.

**Fixed in** `c250099`.

---

## Verification

Static only, plus the project's parse baseline (0 script errors once the `.godot` cache exists —
see `Handoff_Open_Issues.md` §4 about the misleading 55-error baseline on a cold checkout).

**Not exercised in real play.** Worth one manual pass each:

- throw-charge in Single Player *after* leaving a LAN match — the arc should be drawn
- Settings should list a **Lunge** row, and rebinding it should move the lunge off `E`
- rebinding **Grab** should not move the lunge, and vice versa
