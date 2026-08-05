# Handoff — open issues found but not fixed

**What this is:** things uncovered while fixing the skin picks
(`Handoff_Skin_Pick_Sync.md`) that are real, are **not** fixed, and were left alone deliberately
rather than patched on a hunch. Each says what is known, what is only suspected, and what the
cheapest next step is.

Ordered by how likely they are to bite.

---

## 1. The reported LAN/online skin failure is not reproduced

**Status:** open, blocking confirmation of the whole skin fix.

Reported still broken on LAN/online after `d44fc11`, while working in Single Player. The dedicated
configuration was then reproduced faithfully — dedicated server + two client processes, real
lobby, real CHARACTER panel close, real START — and it **passed**, 31/32 checks with 0 mismatches
and an identical pick table on both clients.

So either the field build differs from what was tested, or there is a trigger the harness does not
reach.

**Most likely, in order:**

1. A **dedicated server process still running old code**. It decides and broadcasts every prop
   skin, and before `d79d01c` it could be in a permanently latched state. Restarting it is the
   first thing to rule out.
2. A client that has not pulled. The three prop commits are only correct together.

**Next step — do this instead of another speculative fix.** Add one log line on the host printing
the resolved `_seat_prop_picks` and the mesh actually applied, then read it from one real match.
That pinpoints it in a single game rather than another guess-and-test cycle. Three fixes in this
investigation were shipped on inference and had to be reverted or corrected; a log line is
cheaper than a fourth.

---

## 2. `publish_picks()` may never fire from the lobby

**Status:** open, currently routed around.

`NetworkManager.publish_picks()` hangs off the CHARACTER panel emitting `closed` with `_can_rpc()`
passing. Evidence from the field — both players wearing the connect-time default, and a clean
one-match lag — is consistent with it never running, but it was **never proven** either way. The
signal *is* connected (`match_setup.gd:250`), `CharacterSelect` is only ever the embedded panel,
and `_can_rpc()` looked satisfiable, so the cause was not found.

It is now routed around in three places: the owner writes its own `character_index` at spawn, and
both match entry points republish. Skins should be correct regardless.

⚠️ **But it is still unexplained**, and the lobby board reads the same table — so seat labels or
readouts there may show stale picks even though the match is now correct. Worth resolving properly
rather than leaving a known-unreliable path under a workaround.

---

## 3. A client that loads the match late gets no characters at all

**Status:** open, observed in the harness, unconfirmed in real play.

When the host entered `Main.tscn` roughly a second ahead of the client, the client received **no
characters** and never recovered: the host spawned everyone from `_start_hosting()`'s loop, which
marks `_spawned_peer_ids`, and `_try_late_join()` then no-ops for exactly those peers. The client's
log filled with `Node not found: Main`.

The real lobby coordinates the scene change, which probably hides this. But the recovery path has a
hole in it, and "probably" is doing real work in that sentence. A slow disk, a big map or a
loading hitch is all it would take.

---

## 4. A false measurement in `main.gd` sends readers down a dead end

**Status:** open, cosmetic but actively misleading.

Two comments (`main.gd:511` and `main.gd:2179`) state that `MultiplayerSpawner`'s custom spawn data
*"silently truncates past 7 entries once it crosses the network (measured, not assumed)"*.

**This is false in Godot 4.7.1.** Tested directly with a two-process ENet spawn, both with plain
ints and with the exact 8-key payload `_build_spawn_data` sends:

```
[host]   RECEIVED 8 keys: [peer_id, position, yaw, is_defender, player_slot, player_id, name, character]
[client] RECEIVED 8 keys: [peer_id, position, yaw, is_defender, player_slot, player_id, name, character]
```

All eight arrive intact. The note cost a full wrong hypothesis during the skin investigation — the
8th key is `"character"`, which made it look like a perfect explanation. Either it was true on an
older Godot and is now stale, or it was a misdiagnosis at the time.

Fixing it is a comment edit. Leaving it will mislead the next person the same way.

---

## 5. Bot faces are re-dealt at the ready gate

**Status:** by design, documented, low severity.

Bots are dealt faces in `_fill_empty_slots_with_placeholders()`, before any client has identified,
so the host cannot yet know what the humans picked. If a bot takes a face a human later chooses,
`_release_bot_picks_colliding_with_humans()` frees it at the ready gate and re-deals — so a bot can
visibly change face once, at ready-up.

`main.gd:2465` calls this out as *"a good guess that gets corrected, rather than a claim that
sticks"*, traded deliberately against an earlier bug where bots showed as P1/P2/P3/P4.

Only worth changing if it is actually noticed in play. The obvious fix — re-deal whenever a human's
pick lands — risks setter re-entrancy now that `character_index` has one.

---

## Working notes for whoever picks this up

**Verify the mesh, never the index.** `character_index` / `skin_index` being right proves nothing;
every bug in the skin investigation lived in the gap between the number and the model. Two failed
fixes in the git history are the direct cost of checking the number.

**Use distinct non-default picks when testing.** `lata_pasip.obj` is both "this seat picked pasip"
and "nothing was ever applied". That ambiguity hid a real failure for a full cycle.

**A cold checkout reports 55 script errors and they are not real.** They are missing-`.godot`-cache
class resolution failures. Run `godot --headless --editor --quit-after 300` once to build the
cache, after which the baseline is **0**. Do not chase them.

**Harness shape that worked:** parent the driver to `get_tree().root` so it survives
`change_scene_to_file`, drive the real UI handlers (`_on_character_panel_closed`,
`_on_primary_pressed`, `_on_start_pressed`) rather than reimplementing the flow, and have the host
broadcast a "go" so both peers change scene together — a peer whose `Main.tscn` loads late silently
misses every spawn (see §3).
