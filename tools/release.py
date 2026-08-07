"""Publishes a build: bumps the version and writes the update manifest.

    python tools/release.py                    # bump the minor: 4.68 -> 4.69
    python tools/release.py --notes "Fixed the lobby address, new slippers"
    python tools/release.py --version 5.0      # set it explicitly
    python tools/release.py --check            # print what WOULD change, write nothing

WHY THIS EXISTS, AND IT IS NOT CONVENIENCE.

`scripts/systems/update_check.gd` asks GitHub whether a newer build has been
published by reading `build/latest.json`. The obvious alternative -- read
`config/version` straight out of `project.godot` on `main` -- was rejected for a
reason this repo can prove: **that number has read "4.68" for the entire life of
the project**, through the HARRYDAKS pivot, the model overhaul, the audio work
and every merge, because the rule that says to bump it is a rule a human has to
remember and nobody did. An update checker whose trigger depends on a remembered
manual step reports "you are up to date" forever, which is worse than having no
checker: it tells the player something false.

So the bump stops being a thing to remember and becomes a side effect of
publishing. Run this, commit what it changed alongside the new zip, and the
manifest and the version can no longer disagree with each other or with reality.

⚠️ THE ZIP IS NOT BUILT HERE. Exporting needs Godot's export templates and a
platform preset, and this script deliberately does not pretend to own that --
export from the editor (or `godot --export-release "Windows Desktop"`), then run
this, then commit both. It DOES refuse to write a manifest pointing at a zip that
is not there, so the two cannot drift apart silently.
"""

import argparse
import datetime
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, ".."))
PROJECT = os.path.join(REPO, "project.godot")
MANIFEST = os.path.join(REPO, "build", "latest.json")
ZIP_NAME = "TumbangPreso-win64.zip"
ZIP = os.path.join(REPO, "build", ZIP_NAME)
DOWNLOAD_URL = ("https://github.com/DOST-GameDEV/DOST-GameDev/raw/main/build/"
                + ZIP_NAME)

VERSION_RE = re.compile(r'^(config/version=")([^"]*)(")\s*$', re.MULTILINE)


def read_version():
    text = io.open(PROJECT, encoding="utf-8").read()
    found = VERSION_RE.search(text)
    if not found:
        raise SystemExit("release: no config/version line in project.godot")
    return found.group(2), text


def bump(version):
    """4.68 -> 4.69. The MINOR part only, and it is allowed past .99 on purpose:
    this is a build counter, not semver, and `update_check.is_newer()` compares
    the parts as integers so 4.100 really is newer than 4.99."""
    parts = version.split(".")
    if len(parts) < 2 or not parts[-1].isdigit():
        raise SystemExit("release: cannot bump %r automatically; pass --version"
                         % version)
    parts[-1] = str(int(parts[-1]) + 1)
    return ".".join(parts)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", help="set this version instead of bumping")
    parser.add_argument("--notes", default="", help="one line shown in the prompt")
    parser.add_argument("--check", action="store_true",
                        help="print what would change and write nothing")
    args = parser.parse_args()

    current, text = read_version()
    new_version = args.version or bump(current)

    # ⚠️ REFUSES TO PUBLISH A MANIFEST FOR A ZIP THAT DOES NOT EXIST. The whole
    # failure this guards is a prompt that sends every player to a 404.
    if not args.check and not os.path.isfile(ZIP):
        raise SystemExit(
            "release: %s is missing.\n"
            "Export the Windows build first, then run this so the manifest and\n"
            "the zip are published together." % os.path.relpath(ZIP, REPO))

    manifest = {
        "version": new_version,
        "published": datetime.date.today().isoformat(),
        "url": DOWNLOAD_URL,
        "notes": args.notes,
    }

    if args.check:
        print("version   %s -> %s" % (current, new_version))
        print("zip       %s" % ("present" if os.path.isfile(ZIP) else "MISSING"))
        print("manifest  %s" % json.dumps(manifest, indent=2))
        return

    io.open(PROJECT, "w", encoding="utf-8", newline="\n").write(
        VERSION_RE.sub(lambda m: m.group(1) + new_version + m.group(3), text, count=1))
    io.open(MANIFEST, "w", encoding="utf-8", newline="\n").write(
        json.dumps(manifest, indent=2) + "\n")

    print("version   %s -> %s" % (current, new_version))
    print("wrote     %s" % os.path.relpath(MANIFEST, REPO))
    print("")
    print("Now commit BOTH, plus the zip, to main:")
    print("  git add project.godot build/latest.json build/%s" % ZIP_NAME)
    print("  git commit -m \"Publish v%s\"" % new_version)
    print("")
    print("Every running copy older than v%s will show the update prompt within"
          % new_version)
    print("a few minutes (raw.githubusercontent.com caches briefly).")


if __name__ == "__main__":
    sys.exit(main())
