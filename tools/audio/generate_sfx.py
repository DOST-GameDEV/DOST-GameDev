#!/usr/bin/env python3
"""
===============================================================================
 TUMBANG PRESO - PROCEDURAL SFX GENERATOR                       Checklist 4.1
===============================================================================

Synthesises EVERY sound effect in the game into `assets/audio/sfx/` as 16-bit
mono 44.1 kHz `.wav`. Nothing here is recorded, sampled or downloaded: the
project has no microphones and no time for foley, so the whole SFX set is
maths. That is also why the licence line for all of it is one row -
"Self / Procedurally Generated" (see docs/README.md's asset register).

    python tools/maps/../audio/generate_sfx.py     # from the REPO ROOT

    Requires: numpy, scipy (both already present in the system Python that
    builds the maps and the model atlases).

-------------------------------------------------------------------------------
 THE DESIGN PILLAR IS THE SPEC, NOT REALISM
-------------------------------------------------------------------------------
This is a chaotic 2v2 party game and four players are shouting over it. Every
sound below is built to three rules, and they are why nothing here sounds like
a real tin can:

  1. SHORT.       Almost everything is under 400 ms. A long tail is a sound
                  that is still playing when the next four things happen.
  2. BRIGHT.      Energy is pushed into 1-4 kHz, where a laptop speaker and a
                  cheap headset both actually reproduce it. A beautiful 60 Hz
                  thump is silence on the hardware a judge will use.
  3. PITCHED.     Cartoon impacts have a NOTE in them, not just a crash. The
                  metal hits use inharmonic partials with a deliberate pitch
                  drop, which is what makes a hit read as comic rather than
                  as a foley recording.

-------------------------------------------------------------------------------
 ZERO HEAD PADDING IS A HARD REQUIREMENT, AND IT IS ENFORCED BELOW
-------------------------------------------------------------------------------
`_write()` trims any leading run of near-silent samples and then ASSERTS that
sample 0 is above the silence floor. This is not housekeeping.

The lata impact is triggered on the exact frame `CharacterBase._hitstop()` dips
`Engine.time_scale` (see hitbox.gd / hurtbox.gd). Hitstop is 60 ms. Two or
three milliseconds of leading silence in the .wav - which is what a naive
`concatenate([fade_in, body])` produces, and what most synthesis code ships by
accident - puts the transient AFTER the freeze has already started releasing,
and the hit stops reading as contact. There is no way to compensate for it at
the call site, because the engine gives you no negative delay. It has to not
be in the file.

-------------------------------------------------------------------------------
 DETERMINISM
-------------------------------------------------------------------------------
Every noise source is drawn from a `numpy.random.default_rng(seed)` seeded from
the sound's own name, so running this twice produces byte-identical files and
`git status` stays clean. Same rule the model generators follow.
===============================================================================
"""

import hashlib
import os
import struct
import sys
import wave

import numpy as np
from scipy.signal import lfilter

SR = 44100
OUT_DIR = os.path.join("assets", "audio", "sfx")
# Below this absolute amplitude a sample counts as silence for the head-trim.
# -60 dBFS: low enough not to chew into a genuine soft attack, high enough to
# catch the numerically-tiny-but-nonzero values a filter's first taps produce.
SILENCE_FLOOR = 10.0 ** (-60.0 / 20.0)

_written = []


# =============================================================================
# PRIMITIVES
# =============================================================================

def _rng(name):
    """Deterministic per-sound RNG - see the determinism note in the header."""
    digest = hashlib.sha256(name.encode("utf-8")).digest()
    return np.random.default_rng(struct.unpack("<Q", digest[:8])[0])


def t(dur):
    """Sample-time vector for `dur` seconds."""
    return np.arange(int(SR * dur)) / SR


def env(dur, attack=0.001, decay=None, power=2.0):
    """
    Percussive envelope: a very short linear attack into an exponential-ish
    decay. `attack` is deliberately ~1 ms rather than 0 - a true instant onset
    is a click at the DAC, which reads as a defect rather than as punch.
    """
    n = int(SR * dur)
    a = max(1, int(SR * attack))
    decay = dur - attack if decay is None else decay
    out = np.ones(n)
    out[:a] = np.linspace(0.0, 1.0, a)
    d = np.linspace(0.0, 1.0, n - a)
    out[a:] = (1.0 - d) ** power
    return out


def sweep(dur, f0, f1, curve=1.0):
    """
    Oscillator with a frequency envelope, phase-integrated rather than
    evaluated pointwise. `sin(2*pi*f(t)*t)` - the obvious-looking version - is
    WRONG for a sweep: it produces a chirp whose instantaneous frequency is
    f(t) + t*f'(t), i.e. roughly double the intended sweep rate, and the error
    grows with duration. Integrating the frequency is the only correct form.
    """
    tt = t(dur)
    shape = np.linspace(0.0, 1.0, len(tt)) ** curve
    freq = f0 + (f1 - f0) * shape
    phase = 2.0 * np.pi * np.cumsum(freq) / SR
    return np.sin(phase)


def square(dur, f0, f1=None, duty=0.5):
    """Hard square wave, the cartoon/chiptune voice. Used for UI and fanfares."""
    f1 = f0 if f1 is None else f1
    tt = t(dur)
    freq = np.linspace(f0, f1, len(tt))
    phase = np.cumsum(freq) / SR
    return np.where((phase % 1.0) < duty, 1.0, -1.0)


def noise(name, dur):
    return _rng(name).uniform(-1.0, 1.0, int(SR * dur))


def biquad(x, kind, freq, q=0.707):
    """RBJ cookbook biquad. One scipy call; everything else here is numpy."""
    w0 = 2.0 * np.pi * min(freq, SR * 0.45) / SR
    alpha = np.sin(w0) / (2.0 * q)
    cw = np.cos(w0)
    if kind == "lp":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
    elif kind == "hp":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
    elif kind == "bp":
        b = [alpha, 0.0, -alpha]
    else:
        raise ValueError(kind)
    a = [1 + alpha, -2 * cw, 1 - alpha]
    return lfilter(np.array(b) / a[0], np.array(a) / a[0], x)


def sweep_bp(x, f0, f1, q=1.4, blocks=64):
    """
    Band-pass whose centre frequency moves across the sound - the whoosh
    workhorse. Done in blocks with per-block filter state carried forward,
    because a true time-varying biquad needs a coefficient update per sample
    and the audible difference at 64 blocks is nil.
    """
    n = len(x)
    edges = np.linspace(0, n, blocks + 1).astype(int)
    freqs = np.geomspace(max(f0, 20.0), max(f1, 20.0), blocks)
    out = np.zeros(n)
    for i in range(blocks):
        lo, hi = edges[i], edges[i + 1]
        if hi > lo:
            out[lo:hi] = biquad(x[lo:hi], "bp", freqs[i], q)
    return out


def modes(dur, partials, decays, amps, detune=0.0, bend=0.0):
    """
    A struck resonant body: a sum of decaying sinusoids at INHARMONIC
    frequencies. This is what separates metal and wood from a drum - a can's
    partials are not integer multiples of anything, which is why a stack of
    harmonics sounds like a synth and this sounds like an object.

    `bend` drops every partial by that fraction over the sound's life. Real
    metal barely bends; a CARTOON metal hit bends audibly, and that is the
    single most effective knob here for "punchy and comic" over "recorded".
    """
    tt = t(dur)
    out = np.zeros(len(tt))
    for f, d, a in zip(partials, decays, amps):
        f = f * (1.0 + detune)
        freq = f * (1.0 - bend * np.linspace(0.0, 1.0, len(tt)))
        phase = 2.0 * np.pi * np.cumsum(freq) / SR
        out += a * np.sin(phase) * np.exp(-tt / d)
    return out


def click(name, dur=0.004, cutoff=6000.0):
    """The transient. Every impact gets one; it is what the ear times the hit by."""
    return biquad(noise(name, dur), "hp", cutoff) * env(dur, 0.0002, power=3.0)


def pad(x, dur):
    """Right-pads to `dur` seconds. NEVER pads the front - see the header."""
    n = int(SR * dur)
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n]


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def soft_clip(x, drive=1.0):
    """tanh saturation - adds the harmonics that make a sound cut through."""
    return np.tanh(x * drive)


def _write(name, x, peak=0.85):
    """
    Normalise, trim leading silence, assert the trim worked, write.

    THE TRIM IS THE POINT OF THIS FUNCTION. See the header's head-padding note:
    the lata impact is frame-synced to a 60 ms hitstop and cannot afford a
    leading gap. Enforced rather than trusted, because the failure is silent -
    the sound still plays, it just lands late, and "the hit feels mushy" is not
    a bug report anyone traces back to a .wav header.

    ⚠️ NORMALISE **BEFORE** TRIMMING. Doing it the other way round measures the
    head against the pre-gain signal, and the quiet sounds (`ui_hover` is
    written at peak 0.32) then get scaled BELOW the silence floor after the
    trim has already run - so the file ships with leading samples that are
    silent at playback level even though the trim reported success. Caught by
    the assertion below on the first run, which is exactly what it is for.
    """
    x = np.asarray(x, dtype=np.float64)
    x = np.nan_to_num(x)
    if np.max(np.abs(x)) <= 0.0:
        raise ValueError("%s: generated pure silence" % name)

    x = x / np.max(np.abs(x)) * peak

    loud = np.nonzero(np.abs(x) > SILENCE_FLOOR)[0]
    if len(loud) == 0:
        raise ValueError("%s: entirely below the silence floor at peak %.2f" % (name, peak))
    x = x[loud[0]:loud[-1] + 1]

    # A ~2 ms tail fade. Without it the file ends on a nonzero sample and the
    # DAC clicks on every playback - the exact artefact the head-trim would
    # otherwise re-introduce at the other end.
    tail = min(len(x), int(SR * 0.002))
    x[-tail:] *= np.linspace(1.0, 0.0, tail)

    assert abs(x[0]) > SILENCE_FLOOR, "%s: head padding survived the trim" % name

    pcm = np.clip(x, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    _written.append((name, len(pcm) / SR))


# =============================================================================
# THE LATA - the sounds the whole game is built around
# =============================================================================
#
# One shared partial set, so every can sound is recognisably the SAME OBJECT.
# Measured off nothing: these are tuned by ear for "struck tin", stretched
# inharmonically (the ratios are deliberately not 1:2:3) and kept bright.
CAN_PARTIALS = [523.0, 1187.0, 1733.0, 2549.0, 3391.0, 4507.0]
CAN_AMPS = [1.00, 0.72, 0.55, 0.40, 0.26, 0.15]


def can_hit(name, dur, decay_scale=1.0, bend=0.10, gain=1.0):
    """One strike on the lata. Shared by impact, knockdown, seal and reset."""
    decays = [d * decay_scale for d in [0.34, 0.20, 0.15, 0.10, 0.07, 0.05]]
    body = modes(dur, CAN_PARTIALS, decays, CAN_AMPS, bend=bend)
    # The strike itself: a short bright noise burst filtered up where the ear
    # localises impacts, riding on top of the ringing body.
    strike = biquad(noise(name + "_strike", min(dur, 0.05)), "bp", 3200.0, 0.8)
    strike *= env(min(dur, 0.05), 0.0003, power=4.0) * 0.9
    return mix(body * gain, pad(strike, dur), pad(click(name + "_c") * 0.6, dur))


def build_lata():
    # 4.1 core: slipper connects with the can. Frame-synced to hitstop, so it
    # is the shortest and hardest of the four - all transient, minimal ring.
    _write("lata_impact", soft_clip(can_hit("lata_impact", 0.30, 0.75, 0.14), 1.6))

    # The can goes over. One big hit, then it tumbles: three progressively
    # quieter, higher, faster strikes. The accelerating gaps are what makes it
    # read as "falling over" rather than "hit four times".
    parts = [pad(can_hit("lata_knockdown", 0.55, 1.0, 0.18), 1.0)]
    for i, (delay, amp, det) in enumerate([(0.14, 0.52, 0.09), (0.26, 0.34, 0.19), (0.35, 0.20, 0.31)]):
        hit = can_hit("lata_kd_%d" % i, 0.30, 0.55, 0.22, gain=amp)
        seg = np.zeros(int(SR * 1.0))
        start = int(SR * delay)
        seg[start:start + len(hit)] += hit[:len(seg) - start] * (1.0 + det * 0.0)
        parts.append(seg)
    _write("lata_knockdown", soft_clip(mix(*parts), 1.3))

    # Sealed - the round is over. Same object, but the bend is heavy and
    # downward and the tail is allowed to ring: this is the one lata sound
    # that is ALLOWED to be long, because nothing follows it.
    seal = can_hit("lata_seal", 1.10, 2.2, 0.34, gain=1.0)
    seal += pad(sweep(0.5, 180.0, 60.0) * env(0.5, 0.002, power=1.6) * 0.5, 1.10)
    _write("lata_seal", soft_clip(seal, 1.2))

    # T-3's reset channel completing: the taya stands their can back up. The
    # SAME can partials, but bending UP instead of down - which is the whole
    # trick for "repaired" versus "hit", and costs one sign.
    up = can_hit("lata_reset", 0.45, 1.1, -0.16, gain=0.9)
    ding = sweep(0.35, 880.0, 1320.0, curve=0.5) * env(0.35, 0.003, power=2.2) * 0.45
    _write("reset_channel_complete", soft_clip(mix(up, pad(ding, 0.45)), 1.1))

    # The channel starting - a low mechanical wind-up, so holding `grab` next
    # to your can has an audible commitment the attacker can hear and punish.
    wind = sweep(0.35, 90.0, 260.0, curve=1.6) * env(0.35, 0.01, power=1.2)
    grit = sweep_bp(noise("reset_start", 0.35), 400.0, 1400.0, q=2.0) * env(0.35, 0.01, power=1.4)
    _write("reset_channel_start", mix(wind * 0.7, grit * 0.35))


# =============================================================================
# BODIES - bump, tag, downed, jump, land, dash, guard
# =============================================================================

def build_bodies():
    # Player-on-player bump. Cartoon body check: a low pitched thump with a
    # fast downward bend (the "boff") plus a bright pop so it survives a mix
    # with three other things happening.
    thump = sweep(0.16, 190.0, 68.0, curve=0.7) * env(0.16, 0.001, power=2.4)
    pop = biquad(noise("bump", 0.06), "bp", 1500.0, 1.1) * env(0.06, 0.0005, power=3.5)
    _write("bump", soft_clip(mix(thump, pad(pop * 0.8, 0.16), pad(click("bump_c") * 0.5, 0.16)), 1.7))

    # The taya tags the attacker - the round-ending one on the defence side.
    # A slap: almost all noise, band-limited high, gone in 120 ms, with a tiny
    # pitched blip so it is not just a hiss.
    slap = biquad(noise("tag", 0.12), "bp", 2400.0, 0.9) * env(0.12, 0.0004, power=3.0)
    blip = sweep(0.09, 1400.0, 700.0) * env(0.09, 0.001, power=3.0) * 0.35
    _write("tag", soft_clip(mix(slap, pad(blip, 0.12)), 1.5))

    # A unit goes Downed. Deliberately comic - a falling slide, not a grunt.
    fall = sweep(0.42, 620.0, 170.0, curve=1.8) * env(0.42, 0.004, power=1.5)
    flop = biquad(noise("downed", 0.18), "lp", 900.0) * env(0.18, 0.001, power=2.5)
    _write("downed", soft_clip(mix(fall * 0.8, pad(flop * 0.6, 0.42)), 1.2))

    # 4.1a's jump - every unit, Person and Prop. A hopping lata needs a boing.
    boing = sweep(0.17, 260.0, 760.0, curve=0.45) * env(0.17, 0.002, power=1.8)
    boing *= 1.0 + 0.25 * np.sin(2.0 * np.pi * 22.0 * t(0.17))  # the wobble
    _write("jump", soft_clip(boing, 1.4))

    # Coming back down.
    dust = biquad(noise("land", 0.13), "lp", 1100.0) * env(0.13, 0.0006, power=3.0)
    tap = sweep(0.10, 150.0, 80.0) * env(0.10, 0.001, power=2.6)
    _write("land", soft_clip(mix(dust * 0.7, pad(tap * 0.8, 0.13)), 1.3))

    # Tsinelas-side Dash (character_base._process_dash).
    air = sweep_bp(noise("dash", 0.22), 600.0, 3800.0, q=1.2)
    _write("dash", soft_clip(air * env(0.22, 0.006, power=1.7), 1.3))

    # Can-side Guard actually blocking a hit (B-16 / _flash_blocked).
    tink = modes(0.24, [1760.0, 2640.0, 3960.0], [0.10, 0.07, 0.05], [1.0, 0.6, 0.35], bend=0.04)
    _write("guard_block", soft_clip(mix(tink, pad(click("guard_c") * 0.5, 0.24)), 1.3))

    # KillPlane put someone back on their mark.
    a = sweep(0.16, 500.0, 900.0) * env(0.16, 0.002, power=2.0)
    b = np.concatenate([np.zeros(int(SR * 0.12)), sweep(0.22, 900.0, 1500.0) * env(0.22, 0.002, power=2.0)])
    _write("respawn", soft_clip(mix(a, b) * 0.9, 1.2))


# =============================================================================
# THE SLIPPER - the mechanic the game is named after
# =============================================================================

def build_slipper():
    # Release. A rising-then-falling band of noise, which is what a thrown
    # object actually does to the air, plus a faint pitched core so it reads
    # over a busy mix.
    body = sweep_bp(noise("throw", 0.28), 400.0, 2600.0, q=1.1)
    body *= env(0.28, 0.004, power=1.3)
    core = sweep(0.28, 320.0, 700.0, curve=0.8) * env(0.28, 0.006, power=1.8) * 0.25
    _write("throw_whoosh", soft_clip(mix(body, core), 1.4))

    # Holding `special_ability` to charge the throw. A rise with vibrato, so
    # the taya can HEAR a committed throw coming - carrier.gd's own comment
    # calls that "a real decision the taya can read and punish", and until now
    # it was readable only visually.
    dur = 0.55
    vib = 1.0 + 0.03 * np.sin(2.0 * np.pi * 9.0 * t(dur))
    ch = sweep(dur, 220.0, 760.0, curve=1.4) * vib
    ch *= np.linspace(0.35, 1.0, len(ch)) * env(dur, 0.02, power=0.7)
    _write("throw_charge", soft_clip(ch, 1.2))

    # It lands and goes LOOSE - somebody has to go and get it.
    rub = biquad(noise("slipper_land", 0.16), "lp", 1400.0) * env(0.16, 0.0008, power=2.8)
    slap = sweep(0.12, 210.0, 95.0) * env(0.12, 0.001, power=2.2)
    _write("slipper_land", soft_clip(mix(rub * 0.85, pad(slap * 0.7, 0.16)), 1.4))

    # One clean skip mid-flight (carriable.MAX_BOUNCES = 1).
    b = biquad(noise("slipper_bounce", 0.09), "bp", 1900.0, 0.9) * env(0.09, 0.0005, power=3.2)
    _write("slipper_bounce", soft_clip(mix(b, pad(sweep(0.07, 380.0, 220.0) * env(0.07, 0.001, power=3.0) * 0.4, 0.09)), 1.3))

    # Picked up.
    c1 = click("grab_a", 0.006, 4000.0)
    c2 = np.concatenate([np.zeros(int(SR * 0.035)), click("grab_b", 0.006, 5200.0) * 0.7])
    tick = sweep(0.07, 900.0, 1400.0) * env(0.07, 0.001, power=3.0) * 0.5
    _write("grab", soft_clip(mix(pad(c1, 0.08), pad(c2, 0.08), pad(tick, 0.08)), 1.4))


# =============================================================================
# ABILITIES - one signature sound each, per checklist 4.1
# =============================================================================

def build_abilities():
    # Dyaryo - BAGSAK BOMB. "Goes up, comes down hard, bursts on impact."
    # Heavy and bass-boosted, as specified: a sub drop under a wide burst.
    # The sub is DOUBLED an octave up as well, because a 45 Hz fundamental is
    # inaudible on a laptop and the octave is what carries the weight there.
    sub = sweep(0.55, 130.0, 42.0, curve=0.6) * env(0.55, 0.002, power=1.4)
    sub_oct = sweep(0.55, 260.0, 84.0, curve=0.6) * env(0.55, 0.002, power=1.8) * 0.45
    burst = biquad(noise("bagsak", 0.40), "lp", 2200.0) * env(0.40, 0.0006, power=2.2)
    shrap = sweep_bp(noise("bagsak_s", 0.55), 2400.0, 500.0, q=1.0) * env(0.55, 0.01, power=1.2)
    boom = mix(sub * 1.0, sub_oct, pad(burst * 0.8, 0.55), shrap * 0.30)
    _write("ability_bagsak_bomb", soft_clip(boom, 1.9))

    # Bakya - BAKYA BASH. A wooden clog. Wood is the opposite of the lata:
    # far fewer partials, MUCH faster decay, and no pitch bend at all - the
    # dryness is the whole identity, and it is what stops this reading as
    # another metal hit.
    wood = modes(0.24, [430.0, 1090.0, 1830.0, 2570.0], [0.055, 0.038, 0.026, 0.018],
                 [1.0, 0.68, 0.42, 0.24], bend=0.02)
    knock = biquad(noise("bakya", 0.03), "bp", 1800.0, 0.7) * env(0.03, 0.0003, power=4.0)
    _write("ability_bakya_bash", soft_clip(mix(wood, pad(knock * 1.1, 0.24), pad(click("bakya_c") * 0.7, 0.24)), 1.8))

    # Havaianas - FLICK DASH. "The line drive" - the light, fast one. A quick
    # cartoon wind-whoosh with a whistle riding on top; the whistle is what
    # makes it cartoonish rather than just a filtered hiss.
    wind = sweep_bp(noise("flick", 0.26), 900.0, 5200.0, q=1.3) * env(0.26, 0.004, power=1.5)
    whistle = sweep(0.26, 1200.0, 3000.0, curve=0.7) * env(0.26, 0.01, power=2.0) * 0.30
    _write("ability_flick_dash", soft_clip(mix(wind, whistle), 1.4))

    # Palayok - SHATTER TRAP. The snap of it arming/springing, then crunch:
    # a handful of tiny scattered noise grains, which is how you get "broken
    # pottery" without a sample of broken pottery.
    snap = biquad(noise("shatter", 0.02), "hp", 3000.0) * env(0.02, 0.0002, power=5.0)
    crack = modes(0.18, [1470.0, 2310.0, 3670.0], [0.030, 0.022, 0.014], [1.0, 0.7, 0.5])
    total = 0.42
    crunch = np.zeros(int(SR * total))
    rng = _rng("shatter_grains")
    for i in range(14):
        at = int(SR * (0.03 + rng.uniform(0.0, 0.30)))
        gd = 0.012 + rng.uniform(0.0, 0.02)
        g = biquad(noise("shard_%d" % i, gd), "bp", rng.uniform(1400.0, 5200.0), 1.6)
        g *= env(gd, 0.0003, power=4.0) * rng.uniform(0.25, 0.75)
        crunch[at:at + len(g)] += g[:len(crunch) - at]
    _write("ability_shatter_trap", soft_clip(mix(pad(snap * 1.2, total), pad(crack, total), crunch), 1.5))

    # Bilao - SPIN GUARD. "Knockback pulse pushes attackers away." A whirring
    # deflection: an FM tone under a hard tremolo (the whir), sweeping up and
    # back down so it reads as a spin that spends itself rather than a siren.
    dur = 0.50
    tt = t(dur)
    carrier = 300.0 + 260.0 * np.sin(np.pi * np.linspace(0.0, 1.0, len(tt)))  # up then down
    fm = 1.0 + 0.55 * np.sin(2.0 * np.pi * 170.0 * tt)
    phase = 2.0 * np.pi * np.cumsum(carrier * fm) / SR
    whir = np.sin(phase)
    whir *= 0.55 + 0.45 * np.sin(2.0 * np.pi * 32.0 * tt)  # the rotating tremolo
    whir *= env(dur, 0.012, power=1.3)
    air = sweep_bp(noise("spin", dur), 800.0, 2600.0, q=1.5) * env(dur, 0.02, power=1.4) * 0.30
    _write("ability_spin_guard", soft_clip(mix(whir, air), 1.5))


# =============================================================================
# MATCH STATE - countdown, round win/loss, match win
# =============================================================================

def note(freq, dur, at, total, amp=1.0, duty=0.5, wobble=0.0):
    """One cartoon-square note placed at `at` seconds inside a `total` buffer."""
    out = np.zeros(int(SR * total))
    v = square(dur, freq, freq * (1.0 + wobble), duty)
    v = biquad(v, "lp", 5200.0)                  # take the worst of the edge off
    v *= env(dur, 0.004, power=1.1) * amp
    start = int(SR * at)
    out[start:start + len(v)] += v[:len(out) - start]
    return out


def build_match():
    # main.gd's 3-2-1-GO before the round starts.
    _write("countdown_tick", soft_clip(note(660.0, 0.13, 0.0, 0.14, duty=0.35), 1.2))
    go = mix(note(990.0, 0.30, 0.0, 0.32, duty=0.5),
             note(1320.0, 0.30, 0.0, 0.32, amp=0.55, duty=0.25),
             note(660.0, 0.30, 0.0, 0.32, amp=0.4, duty=0.5))
    _write("countdown_go", soft_clip(go, 1.3))

    # Round won - a short rising triad. Short on purpose: a round win is
    # followed immediately by the intermission banner and the next round.
    win = mix(note(523.0, 0.12, 0.00, 0.62, duty=0.5),
              note(659.0, 0.12, 0.10, 0.62, duty=0.5),
              note(784.0, 0.30, 0.20, 0.62, duty=0.5),
              note(1046.0, 0.30, 0.20, 0.62, amp=0.45, duty=0.25))
    _write("round_win", soft_clip(win, 1.3))

    # Round lost - the same shape, falling, and duller (a wider duty cycle is
    # a mellower square). Both sides of a round result need a sound or the
    # winner's fanfare plays into the loser's silence and reads as a bug.
    lose = mix(note(587.0, 0.12, 0.00, 0.62, duty=0.5),
               note(494.0, 0.12, 0.10, 0.62, duty=0.5),
               note(392.0, 0.32, 0.20, 0.62, duty=0.5, wobble=-0.04))
    _write("round_lose", soft_clip(lose, 1.2))

    # Match won - the big one, and the only sound in the game over a second.
    seq = [(523.0, 0.00, 0.12), (659.0, 0.10, 0.12), (784.0, 0.20, 0.12),
           (1046.0, 0.30, 0.14), (784.0, 0.44, 0.10), (1046.0, 0.54, 0.55)]
    total = 1.45
    parts = [note(f, d, a, total, duty=0.5) for f, a, d in seq]
    parts += [note(f * 1.5, d, a, total, amp=0.35, duty=0.25) for f, a, d in seq]
    # A shimmer tail so the last chord decays into something instead of
    # stopping dead.
    shimmer = np.zeros(int(SR * total))
    tail = sweep(0.6, 2093.0, 3136.0, curve=0.4) * env(0.6, 0.02, power=2.0) * 0.18
    shimmer[int(SR * 0.54):int(SR * 0.54) + len(tail)] += tail[:len(shimmer) - int(SR * 0.54)]
    _write("match_win", soft_clip(mix(*(parts + [shimmer])), 1.25))


# =============================================================================
# UI
# =============================================================================

def build_boot():
    """
    THE BOOT STING - the BH Studios entrance screen, which plays on every single
    launch (splash_screen.gd's own header: "every time is literal") and which
    until now played in complete silence.

    ⚠️ THE VIDEO CARRIES NO AUDIO AND CANNOT. `Opening Animation.mp4` is
    converted with `-an`, deliberately: Godot 4 ships exactly one video codec in
    core and Theora's audio path is not worth the file size on a three-second
    clip that plays a thousand times. So the sting is a separate stream the
    splash scene starts alongside the video, which also means it can be skipped
    cleanly with the video rather than being welded to a frame count.

    ⚠️ IT IS 2.4 s AGAINST A 3.0 s CLIP, ON PURPOSE. A sting that is still going
    when the fade starts gets cut off mid-note, which is the one thing a logo
    sting must never do - it is the last thing the player hears before the menu
    and a truncated one reads as a crash. Ending early leaves the last half
    second to the fade, which is where a sting is supposed to end anyway.

    The shape, and why: a rising perfect-fifth swell into a bright major chord,
    then a single hard SLAP on the beat the chord lands. The slap is the
    tsinelas - the same `click` + short mid-band body every impact in this game
    is built from - because the one sound this project owns is a rubber slipper
    hitting something, and a studio sting that opens a game about throwing them
    should be that sound rather than a generic orchestral hit.
    """
    total = 2.4
    land = 1.05                       # the beat everything is aimed at

    # The swell in. A filtered noise riser plus a fifth held underneath, both
    # arriving exactly at `land` rather than a moment before it.
    riser = np.zeros(int(SR * total))
    swell_dur = land
    up = noise("boot_riser", swell_dur)
    up = sweep_bp(up, 420.0, 3600.0, q=1.1)
    up *= np.linspace(0.0, 1.0, len(up)) ** 2.2 * 0.30
    riser[:len(up)] += up

    drone = np.zeros(int(SR * total))
    fifth = mix(square(swell_dur, 131.0, 196.0, 0.5) * 0.16,
                square(swell_dur, 196.0, 294.0, 0.25) * 0.09)
    fifth *= np.linspace(0.0, 1.0, len(fifth)) ** 1.6
    fifth = biquad(fifth, "lp", 2600.0)
    drone[:len(fifth)] += fifth

    # The chord it lands on. A major triad plus its octave, the same cartoon
    # square voice the match fanfares use so the boot and the game sound like one
    # instrument set rather than two.
    chord = mix(
        note(392.0, 1.10, land, total, duty=0.5),
        note(494.0, 1.10, land, total, amp=0.72, duty=0.5),
        note(587.0, 1.10, land, total, amp=0.72, duty=0.35),
        note(784.0, 1.10, land, total, amp=0.45, duty=0.25),
    )

    # The slipper. `click` is the transient every impact in this file times
    # itself by; the body under it is a short mid-band thwack rather than a
    # metallic ring, because rubber has no note in it.
    slap = np.zeros(int(SR * total))
    hit = mix(click("boot_slap", 0.006, 5200.0) * 0.9,
              biquad(noise("boot_body", 0.16), "bp", 1150.0, 0.9)
              * env(0.16, 0.001, power=2.6) * 0.75)
    at = int(SR * land)
    slap[at:at + len(hit)] += hit[:len(slap) - at]

    # A shimmer tail so the chord decays into something instead of stopping
    # dead - lifted verbatim in principle from `match_win`, for the same reason.
    shimmer = np.zeros(int(SR * total))
    tail = sweep(0.9, 1568.0, 2637.0, curve=0.45) * env(0.9, 0.03, power=2.2) * 0.14
    st = int(SR * (land + 0.05))
    shimmer[st:st + len(tail)] += tail[:len(shimmer) - st]

    _write("boot_sting", soft_clip(mix(riser, drone, chord, slap, shimmer), 1.15),
           peak=0.72)


def build_ui():
    _write("ui_click", soft_clip(note(1046.0, 0.055, 0.0, 0.06, duty=0.3), 1.2), peak=0.55)
    _write("ui_hover", soft_clip(note(1568.0, 0.035, 0.0, 0.04, duty=0.2), 1.1), peak=0.32)
    back = mix(note(784.0, 0.05, 0.00, 0.13, duty=0.3),
               note(523.0, 0.07, 0.05, 0.13, duty=0.3))
    _write("ui_back", soft_clip(back, 1.2), peak=0.5)
    # The rebind-conflict buzz (settings_panel.gd's B-22 message). Low, ugly
    # and short - it has to read as "no" without being painful.
    err = mix(note(196.0, 0.09, 0.00, 0.22, duty=0.5, wobble=0.02),
              note(185.0, 0.11, 0.09, 0.22, duty=0.5, wobble=-0.02))
    _write("ui_error", soft_clip(err, 1.4), peak=0.55)


# =============================================================================

def main():
    if not os.path.isdir("scenes") or not os.path.isfile("project.godot"):
        sys.exit("run this from the repository root (project.godot must be here)")
    os.makedirs(OUT_DIR, exist_ok=True)

    build_lata()
    build_bodies()
    build_slipper()
    build_abilities()
    build_match()
    build_boot()
    build_ui()

    print("wrote %d sfx to %s/" % (len(_written), OUT_DIR.replace(os.sep, "/")))
    longest = max(len(n) for n, _ in _written)
    for name, dur in sorted(_written):
        print("  %-*s  %6.3f s" % (longest, name, dur))
    total = sum(d for _, d in _written)
    print("  %-*s  %6.3f s total" % (longest, "", total))


if __name__ == "__main__":
    main()
