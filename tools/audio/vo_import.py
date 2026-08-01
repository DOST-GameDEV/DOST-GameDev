#!/usr/bin/env python3
"""Convert a drive folder of recorded voice takes into `assets/audio/vo/`.

    python tools/audio/vo_import.py <src_dir> [--out assets/audio/vo] [--dry-run]

WHY THIS EXISTS AT ALL, AND WHY IT IS NOT `copy *.wav`
------------------------------------------------------
The first VO delivery (2026-08-01, 11 files) arrived as **AAC-LC audio in a 3GP
container carrying a `.wav` extension** -- a phone voice-recorder export. Godot
has no AAC decoder, so `load()` returns null, `_load_vo()` skips the file, and
the result is a VO system that looks wired and is silent: exactly the state the
lane was already in. This is the SECOND time a delivery has been misnamed on
this project (docs/HUMAN.md TABLE D: the OST masters were MP3 data with a `.wav`
extension), which is why the format is SNIFFED here and never inferred from the
suffix.

WHAT IT DOES, AND WHY EACH STEP IS NOT OPTIONAL
-----------------------------------------------
1. **Transcode** whatever ffmpeg can read to mono 44 100 Hz -- the format every
   other asset in the game already ships as (docs/HUMAN.md RECORDING SPEC).
2. **Trim leading and trailing silence.** The measured delivery carries
   0.19-0.28 s of head silence, and docs/HUMAN.md actively ASKS recorders for a
   leading second. Shipped as-is, `count_3` is heard a second after the "3" is
   on screen -- and a countdown line that lands late is worse than no line.
3. **Normalise to a single peak target.** The delivery arrived at -0.9 to
   **+0.2 dBFS**, i.e. at and over full scale, against a spec asking for -6.
   Every SFX in the game plays through `AudioManager.HEADROOM_DB` (-7 dB) and
   its own trim, so untouched VO would sit roughly 7 dB over every sound effect
   in the game and duck the music while doing it.
   +-- The IN-GAME balance is NOT baked in here. This only makes the takes
       consistent WITH EACH OTHER at a known reference; `AudioManager.VO_TRIM_DB`
       is the number that sets voice against SFX and music, for the same reason
       `generate_sfx.py` does not bake in `HEADROOM_DB` -- a mix number belongs
       with the mix, where a probe can move it without a re-import.
4. **Rename to what the pooling actually reads.** `AudioManager._load_vo()`
   scans for `vo_*.wav` and `_vo_id_from_filename()` strips the `vo_` prefix and
   the LAST underscore segment. So `clock_10.wav` copied in verbatim would be
   read as the id `clock` -- the delivered names cannot be used unchanged.

DETERMINISTIC: same input bytes -> same output bytes. No randomness, no clock.
"""

import argparse
import math
import struct
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

## The shipping format. Everything else in assets/audio/ is mono/44100/16-bit and
## a voice pool that disagrees would resample at load for no benefit.
OUT_RATE = 44100

## Peak target for every delivered take, in dBFS. docs/HUMAN.md's own recording
## spec asks for -6 and the delivery came in at ~0; normalising DOWN to the spec
## is what makes "consistency beats quality" (that file's own rule) true across
## takes recorded at different distances.
TARGET_PEAK_DB = -6.0

## Silence gate for the trim, matched to tools/audio/vo_probe_takes.py so the
## measurement and the edit agree about what counts as speech.
GATE_DB = -42.0
## Kept either side of the detected speech. The head pad is short because a late
## line is the bug being fixed; the tail is longer so a word's own decay is not
## chopped into a click.
HEAD_PAD_MS = 40
TAIL_PAD_MS = 150
## Ramped in and out at the cut points. A trim that lands mid-waveform is a step
## discontinuity, which is an audible tick on every single play.
FADE_MS = 5

## docs/HUMAN.md TABLE A/B/C, verbatim. An id NOT on this list is a hard error
## rather than a silent skip: a typo'd file name would otherwise import cleanly,
## register under a pool nothing ever plays, and read as "that line was never
## recorded" (§6 trap 3 -- a step that cannot fail is worse than no step).
KNOWN_IDS = {
    # TABLE A -- announcer
    "count_5", "count_4", "count_3", "count_2", "count_1", "count_go",
    "clock_30", "clock_10", "tumbang", "lata_restored", "match_win", "match_draw",
    # TABLE B -- street
    "taya", "bilis", "ayos",
    # TABLE C -- the title
    "title",
}


def ffmpeg() -> str:
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def sniff(path: Path) -> str:
    """The container the BYTES say it is. Never trust the extension -- see above."""
    head = path.read_bytes()[:12]
    if head[:4] == b"RIFF" and head[8:12] == b"WAVE":
        return "wav"
    if head[4:8] == b"ftyp":
        return "mp4/3gp"
    if head[:3] == b"ID3" or (len(head) > 1 and head[0] == 0xFF and (head[1] & 0xE0) == 0xE0):
        return "mp3"
    if head[:4] == b"OggS":
        return "ogg"
    return "unknown"


def parse_name(stem: str):
    """`<id>` or `<id>_<take>` -> (id, take|None).

    Order matters and is the whole subtlety: `count_1` IS an id (TABLE A's
    "Isa!") while `count_go_1` is the id `count_go` with a take number. Testing
    the FULL stem against KNOWN_IDS before splitting is what keeps those apart.
    """
    if stem in KNOWN_IDS:
        return stem, None
    base, _, suffix = stem.rpartition("_")
    if base in KNOWN_IDS and suffix.isdigit():
        return base, int(suffix)
    return None, None


def decode(path: Path) -> np.ndarray:
    out = subprocess.run(
        [ffmpeg(), "-v", "error", "-i", str(path),
         "-f", "f32le", "-acodec", "pcm_f32le", "-ac", "1", "-ar", str(OUT_RATE), "-"],
        capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype="<f4").astype(np.float64)


def trim(x: np.ndarray):
    """Cut to the speech, with pads and fades. Returns (audio, head_s, tail_s)."""
    win = max(1, OUT_RATE // 200)
    pad_n = (-len(x)) % win
    env = np.abs(np.pad(x, (0, pad_n))).reshape(-1, win).max(axis=1)
    loud = np.nonzero(env > 10.0 ** (GATE_DB / 20.0))[0]
    if len(loud) == 0:
        return x, 0.0, 0.0
    start = max(0, loud[0] * win - OUT_RATE * HEAD_PAD_MS // 1000)
    end = min(len(x), (loud[-1] + 1) * win + OUT_RATE * TAIL_PAD_MS // 1000)
    head, tail = start / OUT_RATE, (len(x) - end) / OUT_RATE
    y = x[start:end].copy()
    n = min(OUT_RATE * FADE_MS // 1000, len(y) // 2)
    if n > 0:
        ramp = np.linspace(0.0, 1.0, n)
        y[:n] *= ramp
        y[-n:] *= ramp[::-1]
    return y, head, tail


def write_wav16(path: Path, x: np.ndarray) -> None:
    clipped = np.clip(x, -1.0, 1.0)
    pcm = np.round(clipped * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(OUT_RATE)
        w.writeframes(pcm.tobytes())


def db(v: float) -> float:
    return 20.0 * math.log10(v) if v > 0 else -120.0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--out", default="assets/audio/vo")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    src, out = Path(args.src), Path(args.out)
    if not src.is_dir():
        print("no such directory: %s" % src); return 2
    out.mkdir(parents=True, exist_ok=True)

    # Group by id first so take numbers are assigned deterministically (sorted by
    # source name) rather than by whatever order the filesystem lists.
    found, unknown = {}, []
    for path in sorted(src.iterdir()):
        if path.is_dir() or path.name.startswith("."):
            continue
        stem = path.stem
        if stem.startswith("vo_"):
            stem = stem[3:]
        if stem.startswith("roomtone"):
            print("  skip %-24s room tone, not a line" % path.name)
            continue
        line_id, take = parse_name(stem)
        if line_id is None:
            unknown.append(path.name); continue
        found.setdefault(line_id, []).append((take, path))

    if unknown:
        print("\nUNRECOGNISED, NOT IMPORTED -- these ids are not in docs/HUMAN.md:")
        for n in unknown:
            print("    %s" % n)
        print("  Fix the name or add the id to TABLE A/B/C first.\n")

    written, rows = [], []
    for line_id in sorted(found):
        takes = sorted(found[line_id], key=lambda t: (t[0] is None, t[0], t[1].name))
        for i, (take, path) in enumerate(takes, start=1):
            number = take if take is not None else i
            dest = out / ("vo_%s_%d.wav" % (line_id, number))
            container = sniff(path)
            x = decode(path)
            raw_peak = db(float(np.abs(x).max()))
            y, head, tail = trim(x)
            peak = float(np.abs(y).max())
            gain = (10.0 ** (TARGET_PEAK_DB / 20.0)) / peak if peak > 0 else 1.0
            y = y * gain
            rows.append((path.name, container, dest.name, line_id, number,
                         len(x) / OUT_RATE, len(y) / OUT_RATE, head, tail,
                         raw_peak, db(gain)))
            if not args.dry_run:
                write_wav16(dest, y)
            written.append(dest)

    print("\n%-20s %-8s -> %-22s %-13s %6s %6s %7s %7s" % (
        "SOURCE", "REALFMT", "DEST", "ID/TAKE", "IN s", "OUT s", "PEAK", "GAIN"))
    for (srcn, cont, dstn, lid, num, dur_in, dur_out, head, tail, rawpk, gain) in rows:
        print("%-20s %-8s -> %-22s %-13s %6.2f %6.2f %+6.1f %+6.1f  (cut %.2fs head / %.2fs tail)" % (
            srcn, cont, dstn, "%s #%d" % (lid, num), dur_in, dur_out, rawpk, gain, head, tail))

    print("\n%d file(s) %s -> %s" % (
        len(written), "would be written" if args.dry_run else "written", out))
    print("ids covered: %s" % ", ".join(sorted(found)))
    missing = sorted(KNOWN_IDS - set(found))
    if missing:
        print("\nNO TAKE DELIVERED for %d id(s) -- expected, the list was trimmed:" % len(missing))
        print("    %s" % ", ".join(missing))
        print("  Each stays an empty pool; play_vo() no-ops. Ask what is still coming.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
