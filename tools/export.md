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

## Linux dedicated server — `preset.2`, "Linux Server"

```
"C:\Users\StarX\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --export-release "Linux Server" build/TumbangPreso-server.x86_64
```

⚠️ **This command does not currently run on this machine — no export templates are
installed.** See "Export templates" above and the blocker note at the end of this
section. Everything below the command line was still established by running the
parts that *do* work without templates; where a claim is only read rather than run,
it says so.

This is a **dedicated server export**: same project, same scripts, but Godot replaces
every texture, mesh and material in the pack with a zero-byte placeholder on the way
out. The server never draws anything, so it never needs the pixels — it needs the
`Vector2` size and the `AABB`, which is exactly what the placeholders keep.

Output is **one file**, `build/TumbangPreso-server.x86_64` — `binary_format/embed_pck=true`,
unlike the Windows preset, which ships a separate `.pck`. Deliberate: the "both files
or nothing" trap at the top of this document is annoying on a desktop and much worse
on a server, where forgetting the `.pck` produces a systemd unit that flaps forever
instead of a dialog box someone reads.

### What "Export as dedicated server" actually does

Two independent things, which the editor always sets together and which are separate
keys on disk:

| key in `export_presets.cfg` | effect |
| --- | --- |
| `dedicated_server=true` | Bakes the `dedicated_server` **feature tag** into the exported `project.binary`. The engine reads it at boot and forces `--display-driver headless --audio-driver Dummy` on itself, so an exported server is headless whether or not you pass `--headless`. `OS.has_feature("dedicated_server")` is true **only** in such a build — never in the editor, never for a `--headless` run from source. |
| `export_filter="customized"` + `customized_files` | Turns on the **stripping**. Without it, `dedicated_server=true` gives you a headless binary carrying a full-size pack. |

Stripping is one duck-typed call per resource — Godot asks each resource for a
`create_placeholder()` and swaps in the result. So the exhaustive list of what gets
stripped is the list of classes that implement it:

| stripped | becomes | keeps |
| --- | --- | --- |
| `Texture2D` and every subclass | `PlaceholderTexture2D` | its size |
| `Texture3D`, `Texture2DArray`, `Cubemap`, `CubemapArray` | matching `Placeholder*` | size and layer count |
| `Mesh` and every subclass | `PlaceholderMesh` | its `AABB` |
| `Material` and every subclass | `PlaceholderMaterial` | nothing |

⚠️ **AUDIO IS NOT ON THAT LIST, AND IN THIS PROJECT AUDIO IS THE MAJORITY OF WHAT
SURVIVES.** `AudioStream` has no `create_placeholder()`, so every `.mp3` and `.wav`
ships whole. Measured below: **10.7 MiB of the 17.2 MiB stripped pack is audio** — 62%
of it. Fonts, shaders, `Animation`s and `Theme`s are likewise not strippable. This is a
documented Godot limitation, not a misconfiguration.

Stripping happens **at export time**, not at runtime: the placeholders are written to
`.godot/exported/<hash>/export-<md5>-<name>.res|.scn` and the original paths are
remapped to them. Resources embedded inside a `.tscn` are handled too — they inherit
the mode of the file that contains them.

### The measured saving — ⚠️ pack size, NOT memory

**This is a proxy and must not be quoted as a memory number.** The real question is
resident set on the Oracle VM, and that could not be answered here because no export
could be built (no templates) — so there is no "after" process to weigh. What follows
is what `--export-pack` will produce, which is a genuine measurement of a different
thing.

⚠️ **`--export-pack` works without export templates and `--export-release` does not.**
That asymmetry is the only reason any of this is measurable on this machine: a data
pack contains no engine binary, so there is no template to be missing. Both packs
below were produced on 2026-08-02 with `Godot_v4.7.1-stable_win64.exe`.

| pack | bytes | MiB | vs baseline |
| --- | --- | --- | --- |
| baseline — same preset, `export_filter="all_resources"` | 55,172,560 | 52.6 | — |
| **`"Linux Server"` as shipped — `res://` → `strip`** | **18,010,560** | **17.2** | **−35.4 MiB, −67.4%** |
| strip **and** `res://assets/audio/` → `remove` | 6,794,788 | 6.5 | −46.1 MiB, −87.7% |

The third row is **not** what the preset does — see the audio note below. The baseline
row was produced from a throwaway fourth preset that has since been deleted from
`export_presets.cfg`; regenerate it by copying `preset.2` and changing one key if you
want to re-measure. The packs themselves are left in `build/` as
`measure-baseline.pck`, `measure-server.pck` and `measure-noaudio.pck` — gitignored,
regenerable, delete them freely.

### ⚠️ Two traps that cost an export each, both found by running it

**1. A dedicated server still has to name a texture format.**

```
ERROR: Cannot export project with preset "Linux Server" due to configuration errors:
A texture format must be selected to export the project. Please select at least one texture format.
```

Setting both `texture_format/s3tc_bptc=false` and `texture_format/etc2_astc=false` is
a hard config error even though every texture in this preset is about to become a
zero-byte placeholder. The check is a blanket platform check and does not know about
stripping. `s3tc_bptc=true` is set purely to satisfy it; it costs nothing, because the
formats it would have selected are discarded downstream anyway.

**2. A directory in `customized_files` MUST end with `/`, and without it nothing
happens and nothing complains.**

```ini
customized_files={
"res://": "strip",
"res://assets/audio": "remove"      ; ⚠️ SILENTLY DOES NOTHING
"res://assets/audio/": "remove"     ; ⚠️ this is the one that works
}
```

Measured, same project, same run, the only difference being that slash:
18,018,216 bytes without it against 6,794,788 bytes with it. The lookup takes the
directory path, strips any trailing slash, and then immediately walks to the **parent**
directory — so a key with no slash is compared against nothing and the folder quietly
inherits its parent's mode. `"res://"` is exempt only because it ends in a slash
already, which is why the shipped preset appeared to work while the audio experiment
appeared to be a no-op.

### Why the shipped preset does NOT remove audio, despite it being the biggest win left

10.7 MiB is more than half of what survives stripping, and `remove` is measured to
take all of it. It is off anyway, because **`remove` deletes the file rather than
replacing it, and a scene that still references a removed file no longer loads.** The
Godot docs warn about this in as many words. Every `.tscn` in this project that holds
an `AudioStreamPlayer` with an assigned stream is a candidate, and the failure mode is
a server that boots, reports `active`, and cannot load the match scene.

Turning it on safely means the workaround the docs prescribe: drop the reference from
the scene and `load()` the stream from a script at runtime, so the strip has nothing
to sever. That is a change under `scripts/`, it is not free, and **nobody has verified
this preset boots even without it** — do that first. Until then the extra 10.7 MiB
stays on the table, documented rather than taken.

### ⚠️ BLOCKER: no export templates are installed on this machine

`%APPDATA%\Godot\export_templates\` exists and is **completely empty** — not just
missing the Linux entries, missing every platform. So `--export-release` fails for
this preset, for `"Windows Desktop"` and for `"macOS"` alike:

```
ERROR: Cannot export project with preset "Linux Server" due to configuration errors:
No export template found at the expected path:
C:/Users/StarX/AppData/Roaming/Godot/export_templates/4.7.1.stable/linux_debug.x86_64
No export template found at the expected path:
C:/Users/StarX/AppData/Roaming/Godot/export_templates/4.7.1.stable/linux_release.x86_64
```

To unblock, download **`Godot_v4.7.1-stable_export_templates.tpz`** (~1.28 GB) from
<https://github.com/godotengine/godot/releases/tag/4.7.1-stable> and install it via
`Editor → Manage Export Templates → Install from File`, or let the editor fetch it
with `Download and Install`. It must land in
`%APPDATA%\Godot\export_templates\4.7.1.stable\`, and that folder name has to match
the editor version exactly, `.stable` included.

⚠️ **There is no separate "server" template to look for.** Godot 3 shipped one; Godot 4
does not. The dedicated server is built from the ordinary
`linux_release.x86_64` / `linux_debug.x86_64` templates inside that same `.tpz` — the
"dedicated server" part is entirely the preset, not the binary. Once the `.tpz` is
installed, nothing else in this section needs revisiting.

### ⚠️ Nothing here has been booted

`--export-pack` proves the pack builds and how big it is. It proves nothing about
whether a stripped server can referee a match. Before this replaces the from-source
deployment on the live box, someone with templates installed must build it and run
§7b of `docs/Dedicated_Server_Deployment.md`'s verification, which is two commands.

For the record, what *was* run here, on 2026-08-02: the **from-source** server on
`--port=8980`, which bound UDP 8980 and 8990 and answered a status query with
`{"code":"UEFA","map":"eskinita","players":0,"max":4,...}` at **180.4 MB working set /
128.4 MB private bytes**. That is the baseline the export has to beat, and the
procedure that has to be repeated against the exported binary.

`tools/server/status_probe.gd` is the query half of that, and it exists because
`tools/ui/host_online_shot.gd` can only ask ports 8910-8917 — `ServerQuery`'s pool
range is a compile-time constant, so a lobby on any other port is invisible to it.

```
Godot_v4.7.1-stable_win64.exe --headless --path . --script tools/server/status_probe.gd -- --host=127.0.0.1 --port=8980
```

⚠️ **Kill stale Godot processes before trusting a "no reply" from it.** The first run
of that probe reported nothing on 8990 while `netstat` showed 8990 bound — the port
belonged to a dead-and-reaped earlier server, not the one under test. Check that the
PID holding the port is the PID you started.

## ⚠️ `export_presets.cfg` is machine-written and loses comments

The Godot editor rewrites the whole file the moment anyone opens `Project → Export`
and changes anything, and every `;` comment in it disappears at that instant. There is
a short signpost comment above `preset.1` pointing here; treat it as expendable and
keep the actual reasoning in this file, which git keeps.
