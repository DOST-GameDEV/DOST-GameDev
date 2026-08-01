#!/usr/bin/env python3
"""Print the speech/silence structure of each delivered VO file.

docs/HUMAN.md asks recorders for ONE second of leading silence and THREE takes
back to back inside each file. Both of those matter to the import and neither can
be assumed:

  * a leading second shipped as-is makes `count_3` arrive a second after the "3"
    is on screen, which is the whole point of a countdown line;
  * if a file really does hold three takes, importing it whole gives the pool one
    long stream instead of three, and `play_vo`'s no-repeat-last has nothing to
    choose between.

So measure it rather than trusting the spec. Prints one line per detected
segment above the gate.

    python tools/audio/vo_probe_takes.py <dir>
"""

import math
import subprocess
import sys
from pathlib import Path

import numpy as np

GATE_DB = -42.0      # anything under this is room tone, not speech
MIN_SEG_MS = 120     # ignore a click or a lip smack
MIN_GAP_MS = 250     # silence shorter than this does not separate two takes


def ffmpeg() -> str:
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def decode(path: Path, rate: int = 48000) -> np.ndarray:
    """Decode any container ffmpeg understands to mono float32 at `rate`."""
    out = subprocess.run(
        [ffmpeg(), "-v", "error", "-i", str(path),
         "-f", "f32le", "-acodec", "pcm_f32le", "-ac", "1", "-ar", str(rate), "-"],
        capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype="<f4")


def segments(x: np.ndarray, rate: int):
    """[(start, end)] sample ranges of everything above the gate."""
    win = max(1, rate // 200)                      # 5 ms envelope
    pad = (-len(x)) % win
    env = np.abs(np.pad(x, (0, pad))).reshape(-1, win).max(axis=1)
    loud = env > (10.0 ** (GATE_DB / 20.0))
    segs, run = [], None
    for i, on in enumerate(loud):
        if on and run is None:
            run = i
        elif not on and run is not None:
            segs.append((run * win, i * win)); run = None
    if run is not None:
        segs.append((run * win, len(x)))
    # Merge anything separated by less than MIN_GAP_MS.
    merged = []
    for s, e in segs:
        if merged and s - merged[-1][1] < rate * MIN_GAP_MS // 1000:
            merged[-1] = (merged[-1][0], e)
        else:
            merged.append((s, e))
    return [(s, e) for s, e in merged if (e - s) * 1000 // rate >= MIN_SEG_MS]


def db(v: float) -> str:
    return "silent" if v <= 0 else "%+.1f dBFS" % (20.0 * math.log10(v))


def main() -> int:
    d = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/audio/vo")
    rate = 48000
    for path in sorted(d.glob("*.wav")):
        x = decode(path, rate)
        segs = segments(x, rate)
        print("%-20s %5.2f s  peak %-11s  %d take(s)" % (
            path.name, len(x) / rate, db(float(np.abs(x).max())), len(segs)))
        for s, e in segs:
            print("      %6.2f s -> %6.2f s  (%.2f s)  peak %s" % (
                s / rate, e / rate, (e - s) / rate, db(float(np.abs(x[s:e]).max()))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
