#!/usr/bin/env python3
"""
===============================================================================
 TUMBANG PRESO - PROCEDURAL AMBIENCE GENERATOR             Checklist 4.1 / B-123
===============================================================================

Generates one seamlessly-looping ambience bed per map into
`assets/audio/ambience/`. Same principle as `generate_sfx.py`: it is maths, not
a recording, so it costs nothing to licence and can be retuned by editing a
number instead of re-sourcing an asset.

    python tools/audio/generate_ambience.py     # from the REPO ROOT
    Requires: numpy, scipy.

-------------------------------------------------------------------------------
 WHY THIS REPLACED TWO PERFECTLY GOOD CC0 FILES
-------------------------------------------------------------------------------
4.1 originally shipped two CC0 field recordings from OpenGameArt. They were
correctly licensed, correctly looped, correctly levelled relative to the SFX
bus (measured 18 dB under), and they were still WRONG, for a reason no
measurement I ran could have caught:

    "constant steady static/wind sound, same sound the entire time.
     Ambience to 0 completely removes it."

They are outdoor field recordings. The wind noise on the microphone IS the
asset. You cannot filter that out, because there is nothing underneath it —
and a real recording of a real street is broadband by nature, which is
precisely what "static" means to a listener.

-------------------------------------------------------------------------------
 THE THREE RULES THAT KEEP THIS FROM SOUNDING LIKE STATIC AGAIN
-------------------------------------------------------------------------------
1. **NO BROADBAND NOISE. EVER.** Static is flat-spectrum noise. Every noise
   source here is aggressively low-passed (the beds die away above ~1.2 kHz)
   AND slowly modulated, so it reads as "something far away" rather than as
   hiss. `_verify()` at the bottom FAILS the build if more than 2% of a bed's
   energy lands above 4 kHz. That check is the whole defence, and it is why
   this file asserts rather than trusts.

2. **AMBIENCE IS MOSTLY SILENCE PLUS EVENTS.** A continuous wall of anything,
   however pretty, becomes furniture in ten seconds and irritation in sixty.
   The bed sits very low; what you actually notice is sparse, quiet events —
   a distant tricycle, a dog two streets over, birds. Events are what make a
   place sound alive; beds just make it sound noisy.

3. **IT HAS TO LOOP INVISIBLY.** A click or a level jump at the seam is worse
   than no ambience at all, because it draws attention on a fixed period.
   Everything periodic here has a period that divides the loop length exactly,
   and the whole buffer gets an equal-power head/tail crossfade on top.

Deterministic (seeded per bed), like every other generator in this repo.
===============================================================================
"""

import os
import sys
import wave

import numpy as np
from scipy.signal import lfilter

# 22050 Hz, mono. Nothing here has meaningful content above ~4 kHz by design
# (see rule 1), so a 11 kHz Nyquist is generous, and it makes each bed about a
# megabyte instead of five.
SR = 22050
LOOP_SECONDS = 30.0
CROSSFADE = 2.5
OUT_DIR = os.path.join("assets", "audio", "ambience")


def rng_for(name):
    return np.random.default_rng(abs(hash(name)) % (2 ** 32))


def t(n):
    return np.arange(n) / SR


def lowpass(x, cutoff, order=2):
    """Cascaded one-pole. Gentle on purpose - a steep filter rings."""
    a = 1.0 - np.exp(-2.0 * np.pi * cutoff / SR)
    for _ in range(order):
        x = lfilter([a], [1.0, -(1.0 - a)], x)
    return x


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def lfo(n, period_s, low, high, phase=0.0):
    """
    Slow modulation. `period_s` MUST divide LOOP_SECONDS or the loop seam
    becomes audible as a level step - see rule 3.
    """
    cycles = LOOP_SECONDS / period_s
    assert abs(cycles - round(cycles)) < 1e-9, \
        "LFO period %.3fs does not divide the %.1fs loop" % (period_s, LOOP_SECONDS)
    return low + (high - low) * (0.5 + 0.5 * np.sin(2.0 * np.pi * (t(n) / period_s + phase)))


def bed(name, n, cutoff, level, period_s):
    """
    The distant-rumble layer. Low-passed hard and breathing slowly, so it reads
    as depth rather than as hiss. This is the layer that went wrong before, so
    it is deliberately the quietest thing here.
    """
    x = rng_for(name).uniform(-1.0, 1.0, n)
    x = lowpass(x, cutoff, order=3)
    x = x / (np.max(np.abs(x)) + 1e-12)
    return x * lfo(n, period_s, 0.55, 1.0) * level


def events(name, n, count, build, spread=(0.0, 1.0)):
    """
    Scatters `count` one-shots across the loop. Anything landing past the end
    WRAPS to the beginning, so events are seamless across the loop point too -
    a sound cut in half at the seam is exactly the artefact rule 3 is about.
    """
    out = np.zeros(n)
    r = rng_for(name + "_events")
    for i in range(count):
        clip = build(r, i)
        at = int(n * r.uniform(*spread))
        end = at + len(clip)
        if end <= n:
            out[at:end] += clip
        else:
            head = n - at
            out[at:] += clip[:head]
            out[:end - n] += clip[head:]
    return out


def chirp(r, f0, f1, dur, curve=1.0):
    """A bird. Short, pitched, and gone - the opposite of a bed."""
    n = int(SR * dur)
    shape = np.linspace(0.0, 1.0, n) ** curve
    freq = f0 + (f1 - f0) * shape
    phase = 2.0 * np.pi * np.cumsum(freq) / SR
    env = np.sin(np.pi * np.linspace(0.0, 1.0, n)) ** 1.5
    return np.sin(phase) * env


def pass_by(r, peak_f, dur, level):
    """
    A vehicle going past: a low drone that swells and fades. Reads as motion,
    which is what makes a street feel occupied rather than recorded.
    """
    n = int(SR * dur)
    x = r.uniform(-1.0, 1.0, n)
    x = lowpass(x, peak_f, order=3)
    # Add a faint engine-order tone so it is not purely noise.
    tone = np.sin(2.0 * np.pi * np.cumsum(np.full(n, peak_f * 0.35)) / SR)
    x = x / (np.max(np.abs(x)) + 1e-12) * 0.8 + tone * 0.2
    swell = np.sin(np.pi * np.linspace(0.0, 1.0, n)) ** 2.0
    return x * swell * level


def bark(r, dur, f):
    """A dog, two streets over. Low-passed to death so it reads as distance."""
    n = int(SR * dur)
    env = np.exp(-np.linspace(0.0, 6.0, n))
    x = np.sin(2.0 * np.pi * np.cumsum(np.full(n, f)) / SR) * env
    x += r.uniform(-1.0, 1.0, n) * env * 0.4
    return lowpass(x, 900.0, order=2)


def seamless(x):
    """Equal-power head/tail crossfade. See rule 3."""
    f = int(SR * CROSSFADE)
    head = x[:f].copy()
    tail = x[-f:].copy()
    ramp = np.linspace(0.0, 1.0, f)
    x = x[:-f]
    x[:f] = tail * np.cos(ramp * np.pi / 2.0) + head * np.sin(ramp * np.pi / 2.0)
    return x


# =============================================================================

def build_eskinita():
    """
    A Philippine side street: narrow, enclosed, residential. Close walls, so
    the low end is a touch fuller and events are nearer and more frequent than
    the plaza's. Still nothing bright - an alley at street level has no air in
    it.
    """
    n = int(SR * (LOOP_SECONDS + CROSSFADE))
    x = bed("eskinita_low", n, 180.0, 0.055, period_s=15.0)
    x += bed("eskinita_mid", n, 700.0, 0.045, period_s=10.0)
    # Two tricycles through the loop. The signature sound of a Philippine
    # side street, and the reason this bed does not need to be loud to read.
    x += events("eskinita_trike", n, 2,
                lambda r, i: pass_by(r, 150.0 + 40.0 * i, r.uniform(3.5, 5.0), 0.34))
    x += events("eskinita_dog", n, 3,
                lambda r, i: bark(r, r.uniform(0.12, 0.2), r.uniform(160.0, 260.0)) * 0.20)
    # A few distant birds, kept low and never bright.
    x += events("eskinita_bird", n, 5,
                lambda r, i: chirp(r, r.uniform(1500, 2200), r.uniform(1800, 2600),
                                   r.uniform(0.06, 0.12)) * 0.07)
    return seamless(x)


def build_bayan_plaza():
    """
    An open barangay plaza: wide, airy, more sky than wall. Less low-mid
    congestion than the alley, more space between events, and the events are
    further away.
    """
    n = int(SR * (LOOP_SECONDS + CROSSFADE))
    x = bed("plaza_low", n, 140.0, 0.045, period_s=30.0)
    x += bed("plaza_air", n, 1100.0, 0.035, period_s=6.0)
    # Birds carry this one - a plaza with trees.
    x += events("plaza_bird", n, 11,
                lambda r, i: chirp(r, r.uniform(1600, 2400), r.uniform(2000, 3000),
                                   r.uniform(0.05, 0.13), curve=r.uniform(0.5, 2.0)) * 0.075)
    # One vehicle, far off, to place it in a town rather than a park.
    x += events("plaza_trike", n, 1,
                lambda r, i: pass_by(r, 130.0, r.uniform(5.0, 6.5), 0.18))
    x += events("plaza_dog", n, 1,
                lambda r, i: bark(r, 0.15, 200.0) * 0.10)
    return seamless(x)


# =============================================================================

def verify(name, x):
    """
    ⚠️ THIS IS THE CHECK THAT STOPS B-123 HAPPENING AGAIN. It is not optional
    and it is not decoration.

    A bed that reads as "static" has broadband energy, especially up top. Fail
    the build rather than ship one - the previous version of this asset passed
    every check that existed (licence, duration, loop flag, level relative to
    SFX) and was still unlistenable, because none of those checks measured what
    it sounded like.
    """
    n = len(x)
    rms = float(np.sqrt(np.mean(x ** 2)))
    peak = float(np.max(np.abs(x)))

    spec = np.abs(np.fft.rfft(x * np.hanning(n))) ** 2
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    total = spec.sum() + 1e-30
    bands = {
        "20-250": spec[(freqs >= 20) & (freqs < 250)].sum() / total,
        "250-1k": spec[(freqs >= 250) & (freqs < 1000)].sum() / total,
        "1k-4k": spec[(freqs >= 1000) & (freqs < 4000)].sum() / total,
        "4k+": spec[freqs >= 4000].sum() / total,
    }
    seam = abs(float(x[0]) - float(x[-1]))

    print("  %-22s rms %.4f (%.1f dBFS)  peak %.3f" %
          (name, rms, 20 * np.log10(max(rms, 1e-9)), peak))
    print("  %-22s bands: %s" % ("", "  ".join(
        "%s %.1f%%" % (k, v * 100) for k, v in bands.items())))
    print("  %-22s loop seam discontinuity: %.5f" % ("", seam))

    # Rule 1. Hiss lives up top; this is the number that would have caught the
    # old field recordings.
    assert bands["4k+"] < 0.02, \
        "%s: %.1f%% of energy above 4 kHz — that is hiss, not ambience" % (name, bands["4k+"] * 100)
    # Rule 3. A step at the seam ticks once per loop, forever.
    assert seam < 0.02, "%s: loop seam discontinuity %.4f — will click" % (name, seam)
    # Rule 2, crudely: a bed this quiet cannot dominate anything.
    assert rms < 0.06, "%s: rms %.4f is too loud for a background bed" % (name, rms)
    assert peak < 0.95, "%s: peak %.3f — no headroom" % (name, peak)


def write(name, x):
    verify(name, x)
    pcm = np.clip(x, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("  %-22s wrote %s (%.2f s, %.0f KB)" %
          ("", path.replace(os.sep, "/"), len(x) / SR, os.path.getsize(path) / 1024))
    print("")


def main():
    if not os.path.isfile("project.godot"):
        sys.exit("run this from the repository root (project.godot must be here)")
    os.makedirs(OUT_DIR, exist_ok=True)
    print("ambience, %d Hz mono, %.0f s seamless loops" % (SR, LOOP_SECONDS))
    print("")
    write("eskinita_street", build_eskinita())
    write("bayan_plaza", build_bayan_plaza())


if __name__ == "__main__":
    main()
