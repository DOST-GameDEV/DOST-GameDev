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
install via the same dialog. **Templates live outside the repo, per machine** — nothing
in git installs them, and every person who exports must install them once, themselves:

```
Windows   %APPDATA%\Godot\export_templates\4.7.1.stable\
macOS     ~/Library/Application Support/Godot/export_templates/4.7.1.stable/
Linux     ~/.local/share/godot/export_templates/4.7.1.stable/
```

The folder name must match the editor version exactly, including `.stable` — a mismatch
does not warn, export just fails with "export templates not found." Verify before trusting
an install: the folder above should contain `windows_release_x86_64.exe` regardless of
which OS you installed on (templates for every export target ship together).
