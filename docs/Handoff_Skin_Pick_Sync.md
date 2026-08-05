# Handoff — skin picks not reaching the game (Person, lata, tsinelas)

**What this is:** the investigation and fix for "the skin I picked isn't what shows." Reported
four separate times in different words, and it was four different faults stacked on top of each
other. Three of them were only visible if you looked at the **rendered mesh** rather than at the
index the code was passing around — which is why several earlier fixes "verified clean" and
changed nothing on screen.

| | |
|---|---|
| **Branch** | `fix/trajectory-lunge-backup` |
| **Cut from** | `backup/dedicated-lobbies-starrayx-2026-08-05` |
| **Status** | fixed and verified headlessly; **not yet confirmed by a human in real play** |

---

## The one lesson worth keeping

> `character_index` / `skin_index` being correct proves **nothing**. The number and the mesh are
> separate, and every bug here lived in the gap between them.

Every verification in this handoff therefore asserts a **resource path of the mesh actually
loaded**, never the index. Two of the failed fixes in the git history are the direct cost of not
doing that.

---

## Issue 1 — a replicated pick never repainted the model

**Symptom:** other players saw you as the wrong character; "P3 and P4 are inday and totoy."

`character_index` is a replicated property, but a plain `var`. The synchroniser writes it
**silently**, and `CharacterVisual.apply()` — the only thing that ever instances a model — was
called by hand from three places, none of which covers a replicated write. So a seat whose index
changed after `_ready()` kept drawing whatever it drew first.

The "inday and totoy" detail was the tell, and it is not a coincidence:

| | mesh |
|---|---|
| `totoy` (index 2) | `character-male-a.glb` |
| `inday` (index 3) | `character-female-a.glb` |
| `PERSON_MODELS[2]` | `character-male-a.glb` |
| `PERSON_MODELS[3]` | `character-female-a.glb` |

`_model_path()` falls back to `PERSON_MODELS[slot]` at `character_index == -1`, and P3/P4 are
slots 2 and 3. So "hardcoded to inday and totoy" was **the fallback**, i.e. those faces had never
rendered at all. Readying up merely forced the first repaint via `_rpc_sync_picks`.

**Measured** (two headless peers, same match, identical index on both):

```
HOST    s2[idx 7 female-c]  s3[idx 9 female-d]   <- roster models
CLIENT  s2[idx 7 male-a  ]  s3[idx 9 female-a]   <- PERSON_MODELS, the -1 fallback
```

**Fixed in** `b132e43` (setter that repaints) and `afca963` (send the picks table when a client's
scene is ready — `_try_late_join` returned early for lobby peers, so the table reached exactly
the peers that did not need it).

⚠️ The repaint setter is **guarded**. `character_base.gd:513` records, with measurements, why a
naive one was tried and withdrawn: `apply()` frees every child of `Visual`, and a carried
tsinelas is one of them. It now repaints only with an empty hand and defers to
`reset_for_new_round()` otherwise — the second option that note itself prescribes.

---

## Issue 2 — the host's pick table was a connect-time snapshot

**Symptom:** "both of us are still berto", and next match shows the previous match's pick — a
clean one-match lag.

`NetworkManager.peer_characters` is written at `host_game()` / `_rpc_identify` and only refreshed
if `publish_picks()` runs. Anything that misses that leaves the host spawning everyone from
**connect-time** values — which are last match's, because `GameLaunch`'s three picks deliberately
survive `reset()`.

**Fixed in** `7a1ae1c` (publish on panel close), `b132e43` (a peer writes its **own** pick onto
its own body at spawn from local `GameLaunch` — the one copy that cannot be stale) and `72e34d4`
(publish on the way into every match, from both entry points).

Two sharp edges found the hard way:

- The own-pick write **must be deferred a frame**. `character_index` is `spawn = true`, so an
  inline write is overwritten by the host's spawn state. Measured: the client's `11` came back
  as `0`.
- `_apply_known_picks()` then stamped the host's stale value back over the owner's fresh one.
  It now skips a body this peer is authority for and is not a bot.

---

## Issue 3 — a failed skin swap latched the prop forever

**Symptom:** the can stopped changing **at all**, and reverting the change that triggered it did
not help.

Both props did this:

```gdscript
func apply_skin(index: int) -> void:
    if index < 0 or index == skin_index:
        return
    skin_index = index      # written FIRST
    _apply_model(entry)     # can silently do nothing
```

`_apply_model()` has several silent early-returns, including "no `MeshInstance3D` under `Visual`
yet" — reachable whenever a push arrives while a peer is still assembling its scene. One failed
call set the number while the mesh stayed default, and the `index == skin_index` gate then killed
**every** later retry, including the round reset. Unrecoverable for the life of the process.

This is why `e2c86b3` (an early push, a good idea) broke the skins outright, and why reverting it
did not bring them back — the revert removed a trigger, not the latch.

**Measured**, by mesh:

| | after a failed apply | after the retry |
|---|---|---|
| before | `skin_index=3` (latched) | `lata_pasip.obj` / `tsinelas_classic.obj` — defaults |
| after | `skin_index=-1` | `lata_metal.obj` / `tsinelas_sike.obj` — correct |

**Fixed in** `d79d01c`. Both props latch only once the swap actually happened. Fixed in
`lata.gd` and `slipper.gd` together — they were identical and must not drift.

---

## Issue 4 — prop picks were resolved once and never again

**Symptom:** the lata and tsinelas showing the previous match's choice.

`_seat_prop_picks` is filled once and **never cleared**, and only `_rpc_begin_ready_countdown`
refreshed it. Two live paths reach a new round without passing that gate:

- **Rematch** — `match_result.gd::_begin_rematch_now()` calls `begin_next_round()` directly: no
  scene reload, no `_start_hosting()`, no ready gate. Measured: after changing the pick from
  metal (3) to boyben (1), the table still read `3`.
- **A dedicated server** — clients reload and republish around it; anything it caches outlives the
  match it refereed.

**Fixed in** `32ace95` (republish + re-resolve every round) and `d44fc11` (dress the props before
READY too, safe only because `d79d01c` removed the latch).

---

## The rule the lata follows

There is **one** lata in the arena and it wears **whoever is defending this round**. The defending
seat rotates every round, so the can changes every round and is usually *not yours* — you only see
your own on the rounds you are the taya. Confirmed as intended.

Acceptance test asserts exactly that invariant:
*the lata's real mesh == the roster model for the currently defending seat's own pick.*

---

## Verification actually performed

All headless, two or three real processes over real ENet, asserting meshes.

| configuration | result |
|---|---|
| Listen host + client, pre-ready + round 1 + 4 defender rotations | host 34 / client 32 checks, **0 mismatches** |
| **Dedicated server + 2 clients**, real lobby, real panel close, real START | P1 31 / P2 32 checks, **0 mismatches** |
| Resolved table, both clients | `{0:{can:3} 1:{can:2} 2:{can:0} 3:{can:2}}` — identical |
| Two matches in one process, pick changed between | both matches correct |

Use **distinct non-default** cans when re-testing. `lata_pasip.obj` is both "seat picked pasip"
and "nothing was ever applied"; that ambiguity hid a real failure once in this investigation.

---

## ⚠️ Deploying this

The three prop commits are only correct **together**:

```
d79d01c   the latch          (without it, an early push permanently kills the skin)
32ace95   per-round re-resolve
d44fc11   pre-ready dressing
```

**Restart any dedicated server.** It decides and broadcasts every prop skin, so a process started
before `d79d01c` keeps the old behaviour — possibly in a permanently-latched state — no matter
what the clients run. Confirm `git log --oneline -1` reads `d44fc11` on the server box *and* on
every client.

---

## Still failing in the field

Reported as still broken on LAN/online after `d44fc11`, working in Single Player. **Not
reproduced** — the dedicated configuration above passes end to end. Most likely a stale server
process or an un-pulled client; see `Handoff_Open_Issues.md` §1 for the next diagnostic step,
which is a log line rather than another speculative fix.
