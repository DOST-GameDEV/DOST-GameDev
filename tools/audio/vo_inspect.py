#!/usr/bin/env python3
"""Report the real format of every delivered VO file, before any conversion.

docs/HUMAN.md's recording spec asks for 48 kHz / 24-bit mono WAV masters and
says `build sound` converts down to the shipping format (mono / 44 100 Hz /
16-bit). This prints what actually arrived, so the conversion is decided from a
measurement rather than from the spec's assumption -- the OST arrived as MP3
data carrying a `.wav` extension (docs/HUMAN.md TABLE D), so "it is named .wav"
has already been wrong once on this project.

    python tools/audio/vo_inspect.py <dir> [<dir> ...]
"""

import struct
import sys
import wave
from pathlib import Path


def sniff(path: Path) -> str:
    """What the first bytes say the container really is, ignoring the suffix."""
    head = path.read_bytes()[:12]
    if head[:4] == b"RIFF" and head[8:12] == b"WAVE":
        return "wav"
    if head[:3] == b"ID3" or (len(head) > 1 and head[0] == 0xFF and (head[1] & 0xE0) == 0xE0):
        return "mp3"
    if head[:4] == b"OggS":
        return "ogg"
    return "unknown(%s)" % head[:4].hex()


def peak_dbfs(path: Path) -> str:
    """Peak level of a 16- or 24-bit PCM WAV, in dBFS. '?' for anything else."""
    try:
        with wave.open(str(path), "rb") as w:
            width = w.getsampwidth()
            frames = w.readframes(w.getnframes())
    except Exception:
        return "?"
    if width == 2:
        n = len(frames) // 2
        peak = max(abs(v) for v in struct.unpack("<%dh" % n, frames[: n * 2])) if n else 0
        full = 32768.0
    elif width == 3:
        peak, full = 0, 8388608.0
        for i in range(0, len(frames) - 2, 3):
            v = int.from_bytes(frames[i:i + 3], "little", signed=True)
            peak = max(peak, abs(v))
    else:
        return "?"
    if peak == 0:
        return "silent"
    import math
    return "%+.1f dBFS" % (20.0 * math.log10(peak / full))


def main() -> int:
    dirs = [Path(a) for a in sys.argv[1:]] or [Path("assets/audio/vo")]
    for d in dirs:
        print("=== %s ===" % d)
        for path in sorted(d.glob("*.wav")):
            kind = sniff(path)
            if kind != "wav":
                print("  %-24s %8d B  ** %s DATA, NOT WAV **" % (path.name, path.stat().st_size, kind.upper()))
                continue
            with wave.open(str(path), "rb") as w:
                ch, width, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
            print("  %-24s %8d B  %d ch  %6d Hz  %2d-bit  %5.2f s  peak %s" % (
                path.name, path.stat().st_size, ch, rate, width * 8, n / float(rate), peak_dbfs(path)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
