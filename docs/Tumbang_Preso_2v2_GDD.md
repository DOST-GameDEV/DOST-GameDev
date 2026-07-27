# TUMBANG PRESO 🥫🩴
### Our 2v2 plan for Gear Up NCR — Esports Game Dev Challenge

> ## ⚠️ SUPERSEDED IN PART — read this first (2026-07-27)
>
> **The Tsinelas is no longer a character that walks around. It is a thrown,
> retrieved object.** Agreed with the human as **Option B** of the Task 0
> diagnosis; the reasoning, the rejected alternatives and the implementation are
> in [`Handoff.md`](Handoff.md) §0.7 and §4's **T-block**.
>
> Why: this document specified a Slipper that moves under its own power, so
> nothing was ever thrown, nothing landed, nothing was picked up, and there was
> no retrieval scramble — the entire tension of the street game was absent, by
> design rather than by bug. The human's verdict was *"this doesn't feel like
> tumbang preso yet."* They were right.
>
> Note the **moodboard already agreed with them.** Its THE SLIPPER card is the
> only one of the four with **no input badge**, and the three states it
> illustrates are *in-hand ready → thrown trajectory → retrieval highlight*
> (`Dev_Plan.md` §4.1). The art direction has described a thrown slipper the
> whole time; this document is the one that was out of step.
>
> **What changed:** Sections 2 (Player characters row), 3 (round flow) and 4
> (Tsinelas Class specials). Everything else — 2v2, 1 Person + 1 Prop, Bo5,
> role swap, 90s rounds, stun-only, the Can class, the maps — stands unchanged.
> Inline markers below say which is which.

Hey team! Sending this over so we're all building off the same page for the rest of the
sprint. This covers the core concept, what's locked in, and a couple things I still want your
take on before we commit. Read through, drop thoughts, let's move fast.

**Engine:** Godot 4.x | **Theme:** Philippine Games and Sports | **Format:** 2v2 LAN

---

## 1. The Pitch

Each team is **one person + one living object** — Team 1 is a **Player + a Can**, Team 2 is
a **Player + a Tsinelas**, and both units on a team can move and act. A 2v2 arena brawler
where the classic street game becomes a full-contact sport: the Can side defends its turf
while the Tsinelas side tries to knock it flat, then we swap sides and do it again. Low-poly
Filipino locations — kalye, probinsya, palengke. Built to look good live on demo day.

---

## 2. What We've Locked In

| Decision | Answer |
|---|---|
| Player characters | Each team = **1 Person + 1 object**. Team 1: Player controls a **Person**, teammate controls the **Can**. Team 2: Player controls a **Person**, teammate controls the **Tsinelas**. Both units per team are player-controlled and can move. ⚠️ **AMENDED — the Tsinelas no longer walks around under its own power.** It is carried and thrown by its team's Person, and while loose on the ground its player can only crawl it slowly home. It is still a player-controlled unit with its own camera (so the 2v2 headcount, the 1 Person + 1 Prop structure and the standing camera directive are all unchanged) — it is simply an object that gets thrown rather than a fighter that charges in. See `Handoff.md` §0.7. |
| Match structure | **Round-based**, teams swap Attacker/Defender role each round, **Best of 5** |
| Camera/Genre | **Full 3D, low-poly, third-person** |
| Multiplayer | **LAN**, same wifi, different devices (Godot ENet, host + join by local IP) |
| Roster size | **Small roster** — 2-3 character types per class, one unique special each |
| Can vs. Tsinelas contact | **Knockback/stun only — no permanent elimination.** Keeps rounds fast, keeps every round comeback-able instead of snowballing off one tag. |

---

## 3. How a Match Actually Works

- Each round: **Team A (Person + Can)** defends vs **Team B (Person + Tsinelas)** attacks. Roles swap next round.
- **Round timer:** 90 seconds.
- **Match winner:** first team to 3 round wins (Bo5).

### Round-win mechanic — deliberately still open, keeping 2 options alive

Not locking this until we've felt the movement/combat in-engine — could go either way and
both are good. Keeping both on the table for now:

**Option A — Stock/Life (dents):** Cans have a health bar. Slippers win the round by fully
denting a Can. Cans win by the timer running out, or by knocking Slippers out of bounds a
set number of times (new ring-out idea, not previously in the doc).

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

Each team pairs one **Person** with one **Can** (Team 1) or **Tsinelas** (Team 2) — both
units are player-controlled and mobile. Shared basics for everyone: **Move**, **Bump**
(light melee, small stagger, no cooldown), **Guard/Dash** (Cans block, Tsinelas dash-evade),
one **Special Ability** per character. Person units use a separate, simpler moveset (TBD —
likely Move + Bump + an assist/support action to help their Can or Tsinelas teammate) since
they're the new addition to the roster.

### 🥫 Can Class (Defense)
| Character | Vibe | Special |
|---|---|---|
| **Sardinas** | Classic tin can, balanced | *Quick Stand* — instantly self-rights from Downed once/round |
| **Palayok** | Clay pot, provincial, tanky/slow | *Shatter Trap* — downed state leaves a hazard patch that slows nearby attackers |
| **Bilao** | Festive woven tray, light/fast | *Spin Guard* — knockback pulse pushes attackers away |

### 🩴 Tsinelas Class (Offense) — ⚠️ AMENDED

**These are no longer buttons the slipper presses. They are how each slipper
FLIES when its Person throws it** — see `throw_profile.gd` and the three
`throw_*.tres` resources. The identities survive intact; only the delivery
changed. A slipper's escape tool while loose is the Prop-side Dash it already
shares with every Tsinelas, not a second self-propelled attack.

| Character | Vibe | Throw identity |
|---|---|---|
| **Dyaryo** | Everyday rubber slipper, balanced | *Bagsak Bomb* — **the lob.** High arc (30°), heavy gravity, wide impact radius. Comes down hard and bursts. |
| **Bakya** | Wooden clog, provincial, heavy/slow | *Bakya Bash* — **the heavy.** Lowest arc (8°), heaviest gravity, barely steerable. Keeps `forces_downed`: a direct hit knocks the lata flat outright. |
| **Havaianas** | Beach flip-flop, agile | *Flick Dash* — **the line drive.** Fastest launch, flattest arc, most mid-air steer, and the only profile that does **not** force Downed — a poke that sets up rather than finishes. |

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
