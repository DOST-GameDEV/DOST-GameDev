import io

def rep_in(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in s, "%s MISSING: %s" % (path, old[:80])
        s = s.replace(old, new, 1)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print("patched", path)


rep_in('docs/Agent_Prompts.md', [
('''**Readability → Balance → Feel → Presentation → Single Player → Ship.**
A lane may not start until the one above it has committed.''',
 '''**Readability → Balance → Presentation → Single Player.**
A lane may not start until the one above it has committed. **Five lanes.**'''),
('''⚠️ **MULTIPLAYER FIRST, SINGLE PLAYER LATER — HUMAN INSTRUCTION, 2026-07-31:** *"we will
fix the ai as well but put that in the end of agent prompts lane, we will focus on making
multiplayer first then single player next time."* That is why 🤖 `build ai` sits at
position **6** despite being the largest single piece of work left. Do not promote it.''',
 '''⚠️ **MULTIPLAYER FIRST, SINGLE PLAYER LATER — HUMAN INSTRUCTION, 2026-07-31:** *"we will
fix the ai as well but put that in the end of agent prompts lane, we will focus on making
multiplayer first then single player next time."* That is why 🤖 `build ai` runs **last**
despite being the largest single piece of work left. Do not promote it. It also carries
§ CHECKLIST §8, the ship checklist, because it is the session that ends the board.'''),
('### 6 · 🤖 `build ai` — Single Player *(Opus 5 · high)* — **RUNS SECOND TO LAST**',
 '### 6 · 🤖 `build ai` — Single Player *(Opus 5 · high)* — **RUNS LAST**'),
('- [ ] 6.5 `tools/ai_probe.gd` is stale and is yours.',
 '''- [ ] 6.5 `tools/ai_probe.gd` is stale and is yours.
- [ ] 6.6 **You also run § CHECKLIST §8, the ship checklist**, at the end of your
  session. It is three mechanical items and it is not worth its own cold start.'''),
('''You own systems/ai_controller.gd and tools/ai_probe.gd, and nothing else.''',
 '''You own systems/ai_controller.gd and tools/ai_probe.gd. You are also the LAST lane on
the board, so you own export_presets.cfg and .gitignore for one job only: § CHECKLIST §8,
the three-item ship checklist, done at the END of your session. It is not worth its own
cold start, which is why it is not its own lane.'''),
('''Measure fairness with a real probe over many rounds, not by watching one match.

Tick your own boxes and append to § LOG in the same commit.''',
 '''Measure fairness with a real probe over many rounds, not by watching one match.

Then do § CHECKLIST §8 and stop.

Tick your own boxes and append to § LOG in the same commit.'''),
('*(🔊 `build sound` and 🎨 `build model` prompts follow in § FUTURE LANES.)*',
 '''*(🔊 `build sound` and 🎨 `build model` prompts follow in § FUTURE LANES — they are lanes
3 and 4, written in full and blocked only on assets.)*'''),
])

rep_in('README.md', [
('''**👉 [`docs/Agent_Prompts.md`](docs/Agent_Prompts.md) is the single place progress is tracked.**
Seven `build xxx` lanes, run one at a time in board order. The first unticked box in a lane's
section is the next thing to do.''',
 '''**👉 [`docs/Agent_Prompts.md`](docs/Agent_Prompts.md) is the single place progress is tracked.**
**Five** `build xxx` lanes, run one at a time in board order. The first unticked box in a lane's
section is the next thing to do. Five and not more is deliberate: the board this replaced had
eleven and never finished them, and a lane is a whole session with a cold start, so the count is a
schedule rather than a taxonomy.'''),
])
