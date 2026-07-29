# Building a release .exe

```
"C:\Users\StarX\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --export-release "Windows Desktop" build/TumbangPreso.exe
```

Run from the project root (`DOST-GameDev/`). The output lands at `build/TumbangPreso.exe`
and `build/TumbangPreso.pck` — both required, the `.exe` alone will not run. The debug bar
is absent in a release build — `debug_player_switcher.gd` self-frees — which is
simultaneously the acceptance test for the §0.3 removal contract and the reproduction case
for B-67.

## Packaging the build for teammates (`build/TumbangPreso-win64.zip`)

The loose `.exe`/`.pck` in `build/` stay **gitignored** — they're regenerated locally by
the command above, and the `.exe` alone (~104MB) exceeds GitHub's 100MB hard push limit on
its own. Instead, **`build/TumbangPreso-win64.zip` is tracked in git** (`.gitignore` allows
`build/*.zip` specifically), so a teammate can clone or download the repo and get a runnable
build with no Godot install — extract the zip, double-click `TumbangPreso.exe`.

To refresh it after any change that should reach that zip:

```
# from build/, with a fresh TumbangPreso.exe + TumbangPreso.pck already exported above
Compress-Archive -Path TumbangPreso.exe,TumbangPreso.pck,README.txt -DestinationPath TumbangPreso-win64.zip -Force
git add build/TumbangPreso-win64.zip
```

`build/README.txt` is the player-facing readme shipped inside the zip (controls, how to
host/join, the SmartScreen and firewall notes) — it is a separate file from this one, which
is for whoever is exporting, not whoever is playing. Keep both in sync when controls or the
menu flow change. **Re-zip and re-commit whenever the exported build changes** — a stale
zip in git is worse than no zip, since nothing points anyone at the fact that it's out of
date. This is a real, if small, maintenance cost taken on deliberately for teammate/judge
convenience; each refresh adds ~45MB to git history since git can't diff binary zips.

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

## macOS — a preset exists, but it is UNTESTED

`export_presets.cfg` has a `macOS` preset (`preset.1`) added 2026-07-29, cross-exported
*from a Windows machine* with:

```
godot --headless --path . --export-release "macOS" build/TumbangPreso-macos-UNTESTED.zip
```

This actually completes and produces a real `Tumbang Preso.app` bundle (a universal
binary, `Info.plist`, `.icns`, the `.pck`) inside the zip — Godot's macOS export doesn't
require running on a Mac to produce the bundle, only to sign or run one. **Nobody has
opened, run, or even unzipped this on a Mac.** Concretely unverified:

- Whether it actually launches. Untested code paths, a bad icon conversion, or anything
  else that only shows up at runtime would not be caught by a successful export.
- Codesigning and notarization are **off** (`codesign/codesign=0`,
  `notarization/notarization=0`) — this is explicitly a human/paid-account decision, not
  something to attempt here. Expect macOS Gatekeeper to be considerably stricter about
  this than Windows SmartScreen is about an unsigned `.exe`: an unsigned, unnotarized app
  downloaded from the internet is quarantined, and the standard workaround is right-click
  → Open (accept the dialog) rather than a single "Run anyway" click, or in some Gatekeeper
  configurations, `xattr -cr "Tumbang Preso.app"` from a Terminal first. **Try
  right-click → Open before concluding it's broken.**
- `application/min_macos_version="10.13"` and the Xcode/SDK fields are left blank
  (defaults) — nobody has confirmed what that resolves to at export time or whether it's
  reasonable for this project's dependencies.

Enabling this preset required `textures/vram_compression/import_etc2_astc=true` in
`project.godot` (`[rendering]`) — the export fails outright without it, with an explicit
error naming the setting. This adds an ETC2/ASTC-compressed variant to every imported
texture (visible as a second `path.etc2`/`imported_formats` entry in each `.import` file)
on top of the existing `s3tc_bptc` variant already used by Windows/desktop; it does not
remove or replace anything, so it should not affect the Windows build.

**Do not report macOS as supported or working until someone actually runs the app on a
Mac.** This preset exists so that step is possible, not so that it can be skipped.
