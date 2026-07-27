# Building a release .exe

```
"C:\Users\StarX\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --export-release "Windows Desktop" build/TumbangPreso.exe
```

Run from the project root (`DOST-GameDev/`). The output lands at `build/TumbangPreso.exe`
(the `build/` directory is gitignored). The debug bar is absent in a release build —
`debug_player_switcher.gd` self-frees — which is simultaneously the acceptance test for
the §0.3 removal contract and the reproduction case for B-67.

**Export templates** must be installed first. In the Godot editor:
`Editor → Manage Export Templates → Download`. Alternatively, download the
`Godot_v4.7.1-stable_export_templates.tpz` from the Godot GitHub releases page and
install via the same dialog. Templates live at
`%APPDATA%\Godot\export_templates\4.7.1.stable\`.
