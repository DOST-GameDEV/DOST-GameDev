# assets/audio/vo/ — drop recordings here

Read `docs/HUMAN.md` first — this is the landing spot it points to, not a second spec.

Every file: `vo_<id>_<yourname>.wav`, exactly the `ID` column in `docs/HUMAN.md`'s
Table A/B/C. `audio_manager.gd::_load_vo()` scans this folder at boot, groups every
file by `<id>`, and pools every take it finds under that id — drop in a second take
(`vo_tumbang_cy.wav`, `vo_tumbang_jo.wav`) and it is in the rotation with no code
change. An id with zero files here is silent, not broken — that is the same
"missing asset warns once and no-ops" contract the SFX table already uses.

Empty until the team's drive folder lands.
