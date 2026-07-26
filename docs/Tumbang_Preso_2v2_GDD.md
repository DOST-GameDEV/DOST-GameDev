# TUMBANG LARO: Isang Laban 🥫🩴
### Our 2v2 plan for Gear Up NCR — Esports Game Dev Challenge

Hey team! Sending this over so we're all building off the same page for the rest of the
sprint. This covers the core concept, what's locked in, and a couple things I still want your
take on before we commit. Read through, drop thoughts, let's move fast.

**Engine:** Godot 4.x | **Theme:** Philippine Games and Sports | **Format:** 2v2 LAN

---

## 1. The Pitch

A 2v2 arena brawler built on the classic street game. **Each team is 2 players: a Person
and their Can (or Slipper).** On defense, one teammate plays the human guard tagging
attackers while the other plays the living tin can they're protecting; on offense, one
teammate plays the human thrower while the other plays the living slipper trying to knock
the can flat — then the whole team swaps sides and does it again. Low-poly Filipino
locations — kalye, probinsya, palengke. Built to look good live on demo day.

*(Corrected Session 7: earlier drafts of this doc described "no human characters, two Cans
vs two Tsinelas" — that's wrong, see Section 3.)*

---

## 2. What We've Locked In

| Decision | Answer |
|---|---|
| Player characters | Each team = **1 Person** (tags on defense / throws on offense) + **1 Can or Slipper Prop** (carries the roster class ability). NOT two interchangeable Can/Tsinelas units — see Session 7 correction, Section 3. |
| Match structure | **Round-based**, teams swap Attacker/Defender role each round, **Best of 5** |
| Camera/Genre | **Full 3D, low-poly, third-person** |
| Multiplayer | **LAN**, same wifi, different devices (Godot ENet, host + join by local IP) |
| Roster size | **Small roster** — 2-3 character types per class, one unique special each |
| Can vs. Tsinelas contact | **Knockback/stun only — no permanent elimination.** Keeps rounds fast, keeps every round comeback-able instead of snowballing off one tag. |

---

## 3. How a Match Actually Works

**Session 7 correction:** it's 4 players total, not 2. Each team is 2 players — a **Person**
and a **Prop** (their Can or Slipper) — not two identical Can/Tsinelas units. Both units on
a team move independently and are separately player-controlled.

- Each round: **Team A's Person + Can** defend vs **Team B's Person + Slipper** attack (or
  vice versa). The whole team's *side* (Can vs Slipper) swaps next round; a given player
  stays Person or stays Prop for the whole match, only which side their team is on flips.
- **Person's job:** the human half of the team. On defense, tags attackers (the classic
  Tumbang Preso "It"/guard). On offense, throws the Slipper at the Can. Mechanically both
  are the same Bump/hit interaction today (see character_base.gd) — no unique Person
  ability yet, that's an open item.
- **Prop's job:** the Can or Slipper. Carries the roster's class ability (Quick Stand,
  Bakya Bash, etc. — Section 4) and is what the round-win check (Option A/B below) actually
  watches. Hits on a Person are stun-only flavor with no effect on round outcome.
- **Round timer:** 90 seconds.
- **Match winner:** first team to 3 round wins (Bo5).

### Round-win mechanic — deliberately still open, keeping 2 options alive

Not locking this until we've felt the movement/combat in-engine — could go either way and
both are good. Keeping both on the table for now:

**Option A — Stock/Life (dents):** Cans have a health bar. Slippers win the round by fully
denting a Can. Cans win by the timer running out, or by knocking Slippers out of bounds a
set number of times (new ring-out idea, not previously in the doc).
*(Implemented Session 7: 3 dents fully dents a Can, both tracked Cans need to be fully
dented — see round_manager.gd. Ring-outs are still not implemented — separate item.)*

**Option B — Capture the Base + Downed/Seal:** A circle marks each Can's home base. A solid
hit knocks the Can out of the circle, which puts it in a **Downed** state — it gets a short
window (~2 sec) to self-right before a Tsinelas can reach it and "seal" it for the round.
Cans win by still being up/in-base when time's up.

Both options keep our **stun-only, no permanent elimination** rule for Tsinelas intact —
whether they're bounced off a Can or knocked out of bounds, they're straight back in the
fight either way, not out for the round.

**Build note so this doesn't block anyone:** let's keep the round-win check as its own
separate system/function, decoupled from movement, combat, and hit registration. That way
whichever one we feel out first, swapping to the other later is a small change, not a
rewrite.

---

## 4. Roster (draft)

**Session 7 note:** the roster below is for the **Prop** half of a team (the Can or
Slipper) — see Section 3. The **Person** half doesn't have a roster/class yet; it's
currently just Move + Bump with no special ability. Adding a Person roster (or at least one
generic Person) is an open item, not yet designed.

Shared basics for everyone: **Move**, **Bump** (light melee, small stagger, no cooldown),
**Guard/Dash** (Cans block, Tsinelas dash-evade), one **Special Ability** per character.

### 🥫 Can Class (Defense)
| Character | Vibe | Special |
|---|---|---|
| **Sardinas** | Classic tin can, balanced | *Quick Stand* — instantly self-rights from Downed once/round |
| **Palayok** | Clay pot, provincial, tanky/slow | *Shatter Trap* — downed state leaves a hazard patch that slows nearby attackers |
| **Bilao** | Festive woven tray, light/fast | *Spin Guard* — knockback pulse pushes attackers away |

### 🩴 Tsinelas Class (Offense)
| Character | Vibe | Special |
|---|---|---|
| **Dyaryo** | Everyday rubber slipper, balanced | *Bagsak Bomb* — leap-slam, small AoE knockback |
| **Bakya** | Wooden clog, provincial, heavy/slow | *Bakya Bash* — big charge, instant-down on direct hit, long cooldown |
| **Havaianas** | Beach flip-flop, agile | *Flick Dash* — short ranged dash-throw |

3×3 matchups, regional flavor built in without needing a huge art pipeline.

---

## 5. Maps — team, weigh in here

Leaning toward locking these two:

| Map | Setting | Hazard |
|---|---|---|
| **Eskinita** | Urban side-street, sari-sari store backdrop | Jeepney/tricycle passes through a lane every ~20s |
| **Bayan Plaza** | Barangay plaza, fiesta banners | Mud patches (slow zone), wandering carabao as movable obstacle |

**Palengke** (wet floor patches, pushable vendor carts) as a stretch goal only if we have
time after the core loop is solid.

If anyone's got a stronger location in mind — Baguio, Boracay, Banaue, a jeepney terminal,
whatever — speak up now, otherwise this is what we're building toward.

---

## 6. Esports/Spectator Layer

- HUD: current round, Bo5 tracker, timer, who's Attack vs Defense this round
- Clear visual flash/color on the "Downed" state so it reads instantly on stream/live demo
- Third-person cam per player, maybe a simple auto-follow "broadcast cam" for recording our
  3-5 min gameplay video

---

## 7. Tech Plan

- Godot 4.x, high-level multiplayer (`ENetMultiplayerPeer`) — LAN only, host creates server,
  rest join by local IP. No internet matchmaking needed.
- **Fallback trigger:** if LAN sync isn't stable and fun by roughly the halfway point of our
  remaining time, we pivot to single-PC shared-screen/split-input for the same 2v2 loop.
  Building player input as its own decoupled layer from day one so this swap is cheap if we
  need it.
- Core systems: movement/physics per class, Bump + Special ability w/ cooldowns, Downed/
  self-right state machine, round timer + Bo5 match manager, hazard triggers per map, HUD.

---

## 8. Who's Owning What

| Workstream | Owner | Notes |
|---|---|---|
| Gameplay programming (movement, combat, states) | | Core loop first, always playable |
| Networking (LAN) | | Build early, test on real devices ASAP |
| 3D art — characters (6 total) | | Can share rigs/animations within a class |
| 3D art — maps (2-3) | | Environment + hazard props |
| UI/UX — HUD, menus, scoreboard | | |
| Sound/Music | | Bump, specials, downed/seal moment, ambient per map |
| Producer / Docs & Submission | | Forms 01-03, waiver, synopsis, trailer edit, demo recording |

Tag your name next to what you've got.

---

## 9. Submission Checklist

- [ ] Form 01 — Game Development Team Roles
- [ ] Form 02 — Team Waiver and Declaration of Originality (signed, all members)
- [ ] Form 03 — Asset and AI Usage Disclosure (if we use any AI/external assets — disclose it)
- [ ] Template 01 — Game Title & Synopsis (500 words max)
- [ ] Game Trailer (1-2 min, loopable)
- [ ] Prototype/Demo video (3-5 min gameplay, .mp4, narrated or captioned)
- [ ] Everything uploaded through the official submission link

---

## 10. Still Open — Team Discussion

- **Maps:** locking Eskinita + Bayan Plaza, Palengke as stretch — good with everyone, or
  does someone have a location they'd rather push for?
- **Theme stretch:** we're already covering Philippine Games/Sports. Worth also leaning into
  Circular Economy since the can/slipper premise is literally about reused everyday objects?
  Could be a small scoring bump for basically free if we mention it right in our synopsis.
