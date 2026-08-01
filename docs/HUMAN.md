# HUMAN.md — what the team records, and how

**This file is for people with microphones, not for agents.** Everything else in `docs/` is
written for whoever is building; this one is written for whoever is recording. Started
2026-07-31.

🔊 **`build sound` owns this file.** It writes the line list; you record against it; it does the
conversion and the wiring. **If a line here is hard to say, wrong in Filipino, or just bad — say
so and change it.** The team speaks the language and the board does not.

---

## Why we are doing this at all

*"Game has a decent sound design in which music, sound effects, and **voice casting** that create
an immersive gaming environment"* — that is the rubric's own wording, and Music and Sound Design
is **10% of the final score**. The game has **two of five OST tracks in and playing** and **not one
voice line**, which makes the recording below the cheapest block of points left on the board.

It is also the one thing in the entry that no other team can copy: a Filipino street game called
in Filipino, by the people who made it. It is original by construction, it needs no licence, and
it is what an audience at the demo will repeat back.

---

## 🎙️ RECORDING SPEC — read this once, fully, before the first take

### The file

| | |
|---|---|
| **Format** | **WAV**, uncompressed. Not MP3, not M4A, not a voice-memo format |
| **Channels** | **Mono.** One channel, always |
| **Sample rate** | **48 000 Hz** when recording |
| **Bit depth** | **24-bit** when recording |
| **Peak level** | Aim **−6 dBFS**. Never let it touch 0. If it ever sounds crunchy, it is ruined — redo it |

> ⚠️ **The 2026-08-01 batch came in at −0.9 to +0.2 dBFS**, i.e. at and slightly over full scale,
> against the −6 this table asks for. Phone recorders normalise on export and there is usually no
> setting for it, so this is not really something you can fix at your end — `vo_import.py`
> normalises every take down to −6 on the way in, which also makes the takes match each other.
> **It only matters if a take actually clipped while recording**, which no amount of turning down
> afterwards can undo. That is what "if it sounds crunchy, redo it" is for.

> **Record at 48 kHz / 24-bit and send us that.** Everything already in the game is **mono /
> 44 100 Hz / 16-bit**, and `build sound` converts down to match. Do not convert it yourself —
> converting twice loses quality that cannot come back, and the conversion is one command on our
> end. **Send the masters.**

> ### ⚠️⚠️ SEND WHAT YOUR RECORDER MAKES. DO NOT RENAME IT TO `.wav`.
>
> **The 2026-08-01 batch arrived as AAC audio in a 3GP container with a `.wav` extension** —
> i.e. a phone voice-recorder export that had been renamed. Renaming a file does not convert it,
> and **Godot has no AAC decoder**, so all eleven loaded as `null`: the pool stayed empty, every
> line stayed silent, and the folder looked full the whole time. The audio itself was fine (mono,
> 48 kHz, clean) — only the wrapper was wrong.
>
> So: if your recorder saves `.m4a`, `.3gp`, `.aac` or `.opus`, **send it with that extension.**
> `tools/audio/vo_import.py` runs it through ffmpeg and it costs us nothing. A `.wav` that is not
> a WAV costs an entire session, because everything downstream looks like it is working.
>
> This is the second time a delivery has been misnamed this way — see TABLE D, where the OST
> masters arrived as MP3 data called `.wav`. Nobody is in trouble; it is just worth knowing that
> the extension is the one thing we cannot check by looking.

**If your recorder can only do 44.1 kHz / 16-bit mono, that is completely fine** — it is the
format we ship anyway. Do not buy anything.

### The room

- **The quietest room you have**, with soft things in it — a bedroom with a bed and curtains beats
  a kitchen or a bathroom every time. Hard flat rooms add echo that cannot be removed.
- **Kill the hum.** Aircon off, electric fan off, fridge out of the room, windows shut. Phone
  notifications off — a vibration through a table ruins the take under it.
- **Same room, same spot, every session.** If you record half the lines in one room and half in
  another, they will not sound like the same game.

### The microphone

**A phone is fine.** Do not buy a microphone for this.

- **15–20 cm from your mouth**, and **talk slightly past it**, not straight into it. Aiming
  straight in makes P, T, B and K pop and there is no fixing a pop.
- **Turn OFF any "voice enhancement", "noise cancelling", "auto gain" or "clarity" mode** your
  recorder app has. All of them pump and clip the moment you shout, and a shout is most of this
  list.
- Hold it, or rest it on something soft. Never on a hard table you are also leaning on.

### How to actually record it

1. **Record 10 seconds of the empty room, once per session**, before anything else. Say nothing,
   do not move. Name it `vo_roomtone_<yourname>.wav`. This lets us subtract the room's hiss out of
   every other file — it is the single most useful thing on this page and it costs 10 seconds.
2. **One file per line ID.** Not one long file for everything.
3. **One take per file, and use `_1` / `_2` for extra takes** — `tumbang_1.wav`, `tumbang_2.wav`,
   `tumbang_3.wav`. Vary them a little: one straight, one bigger, one smaller. The game keeps them
   ALL and picks a different one each time, so extra takes are the single cheapest thing on this
   page.
   ⚠️ **This replaces the old "three takes inside one file" instruction.** The import does not
   split a file, so three takes in one file becomes one long clip with two pauses in it. The
   2026-08-01 batch got this right — one take per file — and the note was simply stale.
4. **Leave one second of silence at the start of every file.** Do not start talking immediately.
5. **No music, no effects, no reverb, no editing.** Send it raw. We do the rest.
6. If you fluff a take, **do not stop the file** — pause, breathe, and do it again. Extra takes
   cost us nothing.

### Naming the files

```
<id>.wav              one take
<id>_1.wav  <id>_2.wav    two or more takes of the same line
```

The `<id>` is the **ID column** of the tables below, exactly as written. So the "Tumbang!" line
is `tumbang.wav`, and two takes of it are `tumbang_1.wav` and `tumbang_2.wav`. Room tone is
`vo_roomtone_<yourname>.wav`.

**Do not rename the IDs.** They are what the code looks the file up by.

> ✅ **This is what the 2026-08-01 batch already did, and it was right.** That delivery came in
> as `clock_10.wav`, `count_go_1.wav`, `match_win_2.wav` — all eleven IDs correct, all eleven
> takes correctly numbered. Keep doing exactly that.
>
> ⚠️ **Do not add the `vo_` prefix yourself, and do not put your name in the file.** The repo
> filename is `vo_<id>_<take>.wav` and `tools/audio/vo_import.py` writes it — because the ID and
> the take number are the only two things the code needs, and a name in the middle of them makes
> `clock_10` parse as `clock`. Send the plain IDs; the import does the rest.

### Sending it

Drop the whole folder in the shared drive — **do not commit audio yourself.** `.wav` is Git LFS
tracked in this repo and a wrong `git add` on a big folder is annoying to undo. `build sound`
takes it from the drive and commits it properly.

## ✅ WHAT IS IN THE GAME RIGHT NOW — and what we are still waiting on

**Delivered 2026-08-01 and playing: 11 takes across 8 IDs.** All of Table A's clock and result
lines, and the whole round-start count.

| ID | Takes in | Fires on |
|---|---|---|
| `count_3` `count_2` `count_1` | 1 each | the pre-round 3 · 2 · 1 |
| `count_go` | 2 | "GO!" |
| `clock_30` `clock_10` | 1 each | 30 s and 10 s left |
| `match_win` | 2 | the match ends with a leader |
| `match_draw` | 2 | the match ends tied |

**Still empty, and every one of them is already wired — a file lands and it plays, no code:**

| ID | Line | Why it matters |
|---|---|---|
| `tumbang` | **"TUMBANG!"** | ⭐ the money line. The lata going over is the whole game and it is silent |
| `taya` | **"Taya!"** | round 1 start, and every tag |
| `ayos` | **"Ayos!"** | a tag lands |
| `bilis` | **"Bilis!"** | last 15 s, same beat as the music lift |
| `title` | **"TUMBANG PRESO!"** | the main menu, once — the first thing anyone hears |
| `lata_restored` | **"Nakatayo na!"** | the taya finishes the reset channel |

> 🙋 **Which of these are still coming?** The list was deliberately trimmed and that is fine —
> but the board needs to know the difference between "cut" and "not recorded yet", because a cut
> line gets struck from this page and a pending one stays wired. **If only one more gets
> recorded, make it `tumbang`.**
>
> ⚠️ `count_5` and `count_4` were correctly NOT recorded — the countdown is 3 · 2 · 1. Nothing
> is missing there.

> ✅ **The wiring is already built and waiting.** Every ID on this page has an event hooked up
> in `audio_manager.gd` (or is filed above as needing one first) — the moment a file lands at
> `assets/audio/vo/vo_<id>_<yourname>.wav` it is in the game's rotation with no code change. A
> second take of the same ID (`vo_tumbang_cy.wav`, `vo_tumbang_jo.wav`) is picked up automatically
> too, and the game will not play the same take twice in a row.

---

## 👥 WHO RECORDS WHAT

Two different jobs, and they should not be the same person if we can help it:

| Voice | Job | Sounds like |
|---|---|---|
| **📢 ANNOUNCER** | The caster. Every line in Table A | Calm, clear, above the action. Not shouting — **certain**. Think a commentator, not a hype man. **One person only**, so the game has one voice |
| **🗣️ STREET** | The players and the crowd. Table B | Loud, casual, real. **Two or three different people**, because four units in an alley should not all sound like one guy. Record the same lines each — variety is the point |

Anyone can do the Table C title shout. Loudest wins.

---

## 📋 TABLE A — ANNOUNCER LINES · record these first

These play flat, non-positional, over the top of the match. **Clear beats loud.**

| ID | Filipino line | English | Takes | When it fires |
|---|---|---|---|---|
| `count_5` | **"Lima!"** | Five | 1 | ⭐ see note below |
| `count_4` | **"Apat!"** | Four | 1 | ⭐ |
| `count_3` | **"Tatlo!"** | Three | 1 | ⭐ |
| `count_2` | **"Dalawa!"** | Two | 1 | ⭐ |
| `count_1` | **"Isa!"** | One | 1 | ⭐ |
| `count_go` | **"Simula!"** | Begin! | 2 | The round actually starts |
| `clock_30` | **"Tatlumpu na lang!"** | Thirty left! | 1 | 30 s left on the 90 s round |
| `clock_10` | **"Sampu na lang!"** | Ten left! | 1 | 10 s left |
| `tumbang` | **"TUMBANG!"** | It's down! | 3 | The lata goes over. **The money line — give it everything** |
| `lata_restored` | **"Nakatayo na!"** | Back up! | 2 | The taya's reset channel completes and the lata stands again |
| `match_win` | **"Panalo!"** | Winner! | 2 | The match ends with a leader — fires for the whole room, not one side |
| `match_draw` | **"Patas!"** | It's a draw! | 2 | The match ends tied at the top |

> ⚠️ **`lata_out`, `lata_safe`, `lata_last`, `win_defence` and `win_offence` are STRUCK, not
> renamed.** They were written for the out-of-circle countdown and the per-round winner the
> pre-pivot ruleset had — `round_manager.gd`'s own header now says it in as many words: *"Nothing
> 'wins' a round any more... There is no per-round winner."* Recording them would record lines for
> a game that no longer exists. `tumbang`, `lata_restored`, `match_win` and `match_draw` are what
> replaced them — the events that are actually real now (`RoundManager.lata_knocked`,
> `RoundManager.lata_restored`, `MatchManager.match_won`).
>
> ⭐ **The count 5→1 was written for the SAME deleted mechanic** (double duty with a 5-second
> out-of-circle countdown that no longer runs) and is kept here anyway, trimmed to what still
> applies: it is now only the round-start 3-2-1. Keep all five recorded — a spare `count_5`/
> `count_4` costs nothing and a future countdown (the intermission, say) may still want them —
> but do not read the old "double duty" reasoning as still true. **Say them evenly, one per
> second, same energy each.**

---

## 📋 TABLE B — STREET LINES · the players and the crowd

These play **from where the character is standing**, so they move around the mix. Loud, short,
real. **Two or three people each**, and do not try to sound like each other.

| ID | Filipino line | English | Takes each | When it fires |
|---|---|---|---|---|
| `taya` | **"Taya!"** | You're it! | 3 | Round 1 start, and every time the taya lands a tag |
| `bilis` | **"Bilis!"** | Hurry! | 3 | The last 15 s of a round — same clock as the music's intensity lift |
| `ayos` | **"Ayos!"** | Nice! | 3 | A tag lands |

> ⚠️ **`bangon`, `balik` and `sayang` are STRUCK.** `bangon` ("your TEAMMATE is down") assumes
> teams, which this pivot removed — four players, no sides. `balik` was shouted at a lata stuck
> outside its circle, a mechanic that no longer exists (see Table A's note above). `sayang` needs
> a "the throw missed everything" signal that does not exist yet — `slipper.gd` only distinguishes
> a body-block, a lata hit, and a plain miss internally, and none of those is exposed as a signal
> a different file can listen for. **Filed to ⚖️ `build fair` § CHECKLIST §2** (it owns
> `slipper.gd`'s flight) as the item below — if that lands, `sayang` un-strikes itself and needs
> nothing more than a `play_vo("sayang")` call in `audio_manager.gd`.

---

## 📋 TABLE C — THE TITLE

| ID | Line | Takes | When |
|---|---|---|---|
| `title` | **"TUMBANG PRESO!"** | 3 | The main menu, once, on load |

Big. Street-corner big. This is the first thing anyone hears.

---

## ✅ UNBLOCKED — these used to be on a "do not record" list

⚠️ **This section said to hold these back because 📋 `build rules` was about to turn single
rounds into paired sets. The opposite happened.** Paired sets were deleted on 2026-07-31 with the
whole 2v2 design, `build rules` is closed, and the format has been settled since: **four rounds of
90 seconds, one taya who rotates clockwise, cumulative personal scores.** So most of the old
blocklist is now safe, and two entries on it describe things that no longer exist at all.

**Safe to record now:**

- **Round numbers** — *"Round one"* through *"Round four"*, and no further. There are exactly
  four, always, and which one you are in is a pure function of the round number.
- **"Match winner"** — highest cumulative score after round four takes it.

**Do NOT record these, because the game has no such concept:**

- **Team names, or anything addressed to a team.** Four players, free-for-all, no teams.
- **"Set point", "Round winner", "Round point".** **A round is not won by anybody** — it is
  90 seconds of scoring, the totals persist, and the taya rotates. A line calling a round for
  somebody would be describing a rule the game does not have.
- **"Match point".** Scores are cumulative with no target, so there is no last point.

---

## ⚠️ Two things that will make this sound bad, and how to avoid them

**1 · Repetition kills a voice line faster than anything else.** A shout you hear four times a
round is charming once and irritating by round two. That is the whole reason the **Takes** column
exists and why the street lines want three *different people*: the game picks a different one each
time. **If a line only has one recording, it will be cut rather than shipped tired.**

**2 · Consistency beats quality.** A quiet, slightly dull take that matches every other take is
worth more than one brilliant one recorded in a different room at a different distance. Same room,
same spot, same phone, same session, all the way through.

---

## 🎵 TABLE D — THE OST · five chiptune tracks, team-composed

**Decided 2026-07-31: the team writes the soundtrack, five tracks, chiptune.** That replaces the
plan to synthesise beds in-repo, and it is a straight upgrade — human-composed music is stronger
on Music and Sound Design *and* on Originality, and a chiptune OST gives the game a sonic identity
that a generated ambience bed never would.

**🔊 `build sound` owns this table** and may revise it when it runs. Everything below is the plan
to compose against today.

> ✅ **DELIVERED, 2026-08-01: two of five.** `Rounds` (track 3, MATCH) and `Main Menu and
> Character Select` (covering tracks 1 and 2, TITLE and LOBBY, as one bed until a dedicated LOBBY
> track exists) are in the build and audible — cross-fading menu → match at round 1 and back at
> match end, with a volume lift standing in for track 4 on the last 15 s of a round (see below).
> **Still owed: a dedicated LOBBY track, track 4 PRESSURE, and track 5 VICTORY.**
>
> ⚠️ **Both files arrived as MP3 data saved with a `.wav` extension**, not the OGG this page asks
> for — Godot imports MP3 natively so nothing broke, but the size saving OGG exists for is not
> happening yet. Not blocking; worth fixing on the next export if it's easy on your end.
>
> ⚠️ **NO PRESSURE TRACK YET, SO THE CROSSFADE THIS SECTION DESCRIBES ISN'T RUNNING YET EITHER.**
> The last 15 s of a round instead gets a volume lift on the SAME match bed
> (`audio_manager.gd::_set_music_lift`) — audible, but not the "angrier version of the same song"
> effect track 4 is for. Swap it for a real cross-fade the moment `ost_4_pressure.ogg` (or
> whatever it's named) lands; the hook already expects it.

### Where the five go

| # | Track | Plays on | Length | Loop? |
|---|---|---|---|---|
| **1** | **TITLE** | Main menu | 60–90 s | ✅ seamless |
| **2** | **LOBBY** | Match setup and character select | 60 s+ | ✅ seamless |
| **3** | **MATCH — base** | The whole round, both maps | **90 s+** | ✅ seamless |
| **4** | **MATCH — pressure** ⭐ | Crossfades in over #3 when the lata is knocked off its circle | **same length as #3** | ✅ seamless |
| **5** | **VICTORY** | The match-result screen | 20–30 s | ❌ plays once |

### ⭐ Track 4 is the one that has to be planned before you write track 3

**It is not a fifth song — it is the same song, angrier.** When the lata gets knocked off its
circle, a countdown starts and the round is actively being lost. The game crossfades from track 3
to track 4 at that moment, and back when the defence saves it.

For that to work, **3 and 4 must be written as a pair**:

- **Same tempo. Same key. Same length.** Ideally the same chord progression.
- 4 is 3 with the intensity added — drums doubled, a lead on top, a driving bass. Not a different
  idea.
- **Write 3 first, then duplicate the project and build 4 on top of it.** In a tracker this is
  ten minutes; writing them separately and trying to match them afterwards is painful.

This is the single most valuable thing in the OST, because the rubric asks in as many words that
music *"show the necessary emotion when playing with such sounds"* — and we have a purpose-built
tension clock to hang it on. **A game whose music reacts to the state of play reads as far more
finished than one with a track playing over the top.**

> **Only doing four?** Drop **#2 (LOBBY)** and let the title track cover the menus. Do **not** drop
> #4 — the pair is worth more than the coverage.

### Music format spec — different from the voice spec above

| | |
|---|---|
| **Format** | **OGG Vorbis** (`.ogg`), quality 6 or higher — *not* WAV. Music files are long, and a WAV of track 3 is ~10 MB against ~2 MB for the same thing in OGG |
| **Channels** | **Stereo** — unlike the voice lines. Music plays flat over the top, so it does not need to be mono |
| **Sample rate** | **44 100 Hz** |
| **Peak level** | **−6 dBFS.** There is a limiter on the master and it will squash anything hotter |
| **Naming** | `ost_1_title.ogg`, `ost_2_lobby.ogg`, `ost_3_match.ogg`, `ost_4_pressure.ogg`, `ost_5_victory.ogg` |

**Seamless looping is a hard requirement for 1–4.** That means:

- **No fade-in at the start and no fade-out at the end.** A fade is what makes a loop audible.
- The last bar must run straight into the first. Export exactly whole bars — no silence at either
  end, not even a few milliseconds.
- **Test it before sending:** play the file on repeat. If you can hear where it restarts, it is not
  done. This is the one thing that is worth redoing until it is right, because a seam that clicks
  every 90 seconds is more noticeable than anything else on this page.

### 📎 Send the project files too

Along with the `.ogg` exports, send the **tracker or DAW project files** — `.ftm`, `.xm`, `.it`,
`.flp`, `.mmpz`, whatever you wrote it in.

Not for the build; they never ship. **They are the best originality evidence the entry has.** The
competition rules say the organisers may request *"supporting documentation, source files, prompts,
development logs, or version-control records to verify compliance"* — and a tracker project with
its pattern data and instrument list is about as complete a proof of authorship as it is possible
to hand somebody. Keep them.

### And if anybody plays a real instrument

Rondalla, kulintang, bamboo percussion, a guitar — **say so**, because a chiptune arrangement with
one real Filipino instrument sitting on top of it would beat either on its own, and it feeds Theme
Relevance at the same time. The **voice** recording spec at the top of this page applies to
anything recorded with a microphone.

**Same rule as the voice lines: it has to be composed and played by the team, or we cannot use
it.** No samples, no loops downloaded from anywhere, no AI-generated music. That keeps the
paperwork to one honest line.

---

## 📄 Paperwork, in one line

Team-recorded voice is **original work**, which is exactly what we want — it needs no licence and
nothing on Form 03 beyond an honest line saying the team recorded it. **Do not record anybody who
is not on the team**, and do not sample anything from anywhere. That is the entire compliance
story and it stays that simple as long as every voice belongs to a team member.
