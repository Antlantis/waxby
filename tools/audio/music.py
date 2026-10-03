#!/usr/bin/env python3
"""WAXBY's music: eight looping tracks synthesized from scratch in pure Python
(stdlib only), written to game/audio/ as mono 22050 Hz 16-bit WAVs.

  title   D minor, 64 BPM, 8 bars (30 s). Soft organ, a sung "ahh", a distant
          bell now and then, and a celesta remembering the chapel tune.
  chapel  D minor, 120 BPM, 32 bars (64 s), the World 1 level. Harpsichord
          ostinato, an organ pedal bass pumping octaves, a soft pulse lead
          (A A' B A''), a recorder and choir bridge, kick and tambourine.
  boss    D minor with a Phrygian Eb, 140 BPM, 24 bars (41 s). Pounding organ,
          tremolo low strings, timpani and war drum, an urgent lead.
  story   D minor, 3/4, 66 BPM, 24 bars (65 s), the story's warm scenes. The
          title melody (the chapel tune's opening) as a music box waltz over a
          soft organ, a hummed choir in the bridge (A A' B).
  hush    No key to speak of, no beat, 40 s: the Snuffer's scenes. A dark,
          breathing drone on D, a cold wind, and bells swelling up backwards
          out of the dark. A little quieter than the rest (-20 LUFS).
  dawn    D major (the only major-key cue), 3/4, 72 BPM, 24 bars (60 s): the
          bell chain, the ending, the credits. The title melody resolved, on
          celesta over the story's music box and a choir, then the tower's
          bells ringing down each chord in rounds.
  tallow  D minor, 80 BPM, 20 bars (60 s), World 2. A damp harmonium over
          percussion made of dripping: tuned drops, a plopping kick, a wet
          slap; the title motif dragged slow, the drops taking the tune.
  snuffer D minor with a Phrygian Eb, 132 BPM, 24 bars (44 s), boss 2. A sour,
          detuned organ grinding eighths, a low choir that chants, bells
          swelling backwards into the downbeats, war drums, the title motif
          bent Phrygian on top. Voiced to drive on a phone speaker too (a 4'
          on the organ, the choir doubled up an octave, drums struck with
          wood and beaters), so it never sounds thinner there than tallow,
          the level before it.

Every track is rendered as a circle: whatever rings past the loop's end
(note tails, the reverb) is folded back onto its start, and the reverb and
filters are warmed up on the loop's own tail, so the end flows into the
beginning. Each file holds the loop plus PAD frames that repeat its first
ones and a 'smpl' chunk marking the loop as [0, n): Godot's resampler reads
a frame past the loop end and ticks if it finds silence there. Sfx sets
loop_end = frames - PAD itself as well.

Levelled to TARGET_LUFS (BS.1770 integrated loudness, K-weighted and gated)
and soft-clipped under -1 dBFS. The engine plays them a few dB lower still
(Sfx.MUSIC_DB), so the effects cut through.

v3 (spec 12.2) adds its cues in two modules that merge() brings in:
tracks_worlds.py (orchard, carillon, sanctum, hushdeep, secret; trial; the
descent stems; the four ambience beds) and tracks_bosses.py (rootmother,
tinker, saint, the hush_final stems, lullaby; evenbell; lament), both built
on instruments_v3.py. A stem set is mastered by master_stems: every stem
gets the same gain, so the stems add up to the mastered cue exactly, and
its pre-mixed stand-ins are written as the exact sums of the stems they
hold (the gain keeps every sum clear of the ceiling, so none is clipped).
v2's eight render byte for byte as they did.

    python3 tools/audio/music.py [track or stem set ...]    # default: all
    python3 tools/audio/music.py v2                          # just v2's eight
    python3 tools/audio/music.py v3                          # just v3's
    WAXBY_MUSIC_OUT=/tmp/x python3 tools/audio/music.py ...  # render somewhere else
"""

import array
import math
import os
import random
import struct
import sys
import time
import wave
from itertools import accumulate, islice, repeat
from operator import add, mul

RATE = 22050
PAD = 16                       # frames after the loop that repeat its head
TARGET_LUFS = -18.0
CEILING = 10 ** (-1.0 / 20)    # soft-clip ceiling, -1 dBFS
KNEE = 0.6                     # the soft clipper leaves everything below this alone
TAB = 8192                     # wavetable length
MASK = TAB - 1
HERE = os.path.dirname(os.path.abspath(__file__))
# WAXBY_MUSIC_OUT renders somewhere else (a scratch folder), and check_music.py checks there.
OUT_DIR = os.environ.get('WAXBY_MUSIC_OUT') or os.path.normpath(os.path.join(HERE, '..', '..', 'game', 'audio'))
SIN = [math.sin(2 * math.pi * i / TAB) for i in range(TAB)]


# ---------------------------------------------------------------- basics

def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def zeros(n):
    return array.array('d', bytes(8 * n))


def add_into(dst, src, at=0, gain=1.0):
    """dst[at:] += gain * src, in place, cut off at the end of dst."""
    end = min(at + len(src), len(dst))
    if end <= at:
        return
    m = end - at
    s = src if m == len(src) else src[:m]
    if gain != 1.0:
        s = map(mul, s, repeat(gain))
    dst[at:end] = array.array('d', map(add, dst[at:end], s))


def scaled(src, gain):
    return array.array('d', map(mul, src, repeat(gain)))


def shape(buf, attack, release):
    """Raised-cosine fade in over `attack` s and out over the last `release` s."""
    n = len(buf)
    a = min(n, max(1, int(attack * RATE)))
    for i in range(a):
        buf[i] *= 0.5 - 0.5 * math.cos(math.pi * i / a)
    r = min(n - a, max(1, int(release * RATE)))
    for i in range(r):
        buf[n - 1 - i] *= 0.5 - 0.5 * math.cos(math.pi * i / r)
    return buf


def normalize(buf, peak=1.0):
    top = max(map(abs, buf)) or 1.0
    return scaled(buf, peak / top)


def ramp_env(n, attack, release):
    """1.0 with a raised-cosine rise over `attack` s and fall over the last `release` s."""
    a = max(1, min(n, int(attack * RATE)))
    r = max(1, min(n - a, int(release * RATE))) if n > a else 0
    env = [0.5 - 0.5 * math.cos(math.pi * i / a) for i in range(a)]
    env += [1.0] * (n - a - r)
    env += [0.5 + 0.5 * math.cos(math.pi * (i + 1) / r) for i in range(r)]
    return env


def partial(n, freq, amp, decay, phase=0.0):
    """An exponentially decaying sine, n samples long (an iterator)."""
    inc = freq * TAB / RATE
    off = phase * TAB
    g = math.exp(-1.0 / (decay * RATE))
    env = accumulate(repeat(g, n - 1), mul, initial=amp)
    return map(mul, (SIN[int(off + i * inc) & MASK] for i in range(n)), env)


_tables = {}


def wavetable(amps, f0, limit=9000.0):
    """One cycle (peak 1) of harmonics 1, 2, 3... at `amps`, leaving out any
    that would pass `limit` Hz when played at f0."""
    nmax = min(len(amps), max(1, int(limit / f0)))
    key = (tuple(amps[:nmax]), nmax)
    t = _tables.get(key)
    if t is None:
        acc = [0.0] * TAB
        for k in range(1, nmax + 1):
            a = amps[k - 1]
            if a:
                acc = list(map(add, acc, [a * SIN[(i * k) & MASK] for i in range(TAB)]))
        top = max(map(abs, acc)) or 1.0
        t = _tables[key] = [v / top for v in acc]
    return t


def osc(tab, freq, n, phase=0.0, vib=0.0, vib_hz=5.0, vib_delay=0.0, vib_phase=0.0):
    """n samples of a wavetable at freq. A vibrato of `vib` (a ratio) grows
    in over 0.3 s after vib_delay seconds."""
    inc = freq * TAB / RATE
    off = phase * TAB
    if not vib:
        return [tab[int(off + i * inc) & MASK] for i in range(n)]
    d0 = int(vib_delay * RATE)
    grow = 1.0 / (0.3 * RATE)
    w = vib_hz * TAB / RATE
    vo = vib_phase * TAB
    incs = [inc * (1.0 + vib * min(1.0, max(0, i - d0) * grow) * SIN[int(vo + i * w) & MASK]) for i in range(n)]
    return [tab[int(p) & MASK] for p in islice(accumulate(incs, initial=off), n)]


def biquad(x, b0, b1, b2, a1, a2):
    y = zeros(len(x))
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y


def bandpass(x, f0, q):
    w = 2 * math.pi * f0 / RATE
    alpha = math.sin(w) / (2 * q)
    a0 = 1 + alpha
    return biquad(x, alpha / a0, 0.0, -alpha / a0, -2 * math.cos(w) / a0, (1 - alpha) / a0)


def highpass(x, f0, q=0.707):
    w = 2 * math.pi * f0 / RATE
    alpha = math.sin(w) / (2 * q)
    c = math.cos(w)
    a0 = 1 + alpha
    return biquad(x, (1 + c) / 2 / a0, -(1 + c) / a0, (1 + c) / 2 / a0, -2 * c / a0, (1 - alpha) / a0)


def lowpass(x, f0, q=0.707):
    w = 2 * math.pi * f0 / RATE
    alpha = math.sin(w) / (2 * q)
    c = math.cos(w)
    a0 = 1 + alpha
    return biquad(x, (1 - c) / 2 / a0, (1 - c) / a0, (1 - c) / 2 / a0, -2 * c / a0, (1 - alpha) / a0)


def noise(n, seed):
    r = random.Random(seed)
    return array.array('d', (r.random() * 2.0 - 1.0 for _ in range(n)))


_notes = {}


def cached(fn):
    """Render each distinct note once: an ostinato repeats the same few."""
    def wrap(*args):
        key = (fn.__name__,) + args
        v = _notes.get(key)
        if v is None:
            v = _notes[key] = fn(*args)
        return v
    wrap.__name__ = fn.__name__
    wrap.__doc__ = fn.__doc__
    return wrap


BREATH = None


def breath():
    """Eight seconds of airy noise centred near 2.5 kHz, sliced up for the
    recorder's breath, the organ's chiff and the choir's breath."""
    global BREATH
    if BREATH is None:
        BREATH = normalize(bandpass(noise(8 * RATE, 7), 2500.0, 0.8))
    return BREATH


# ---------------------------------------------------------------- instruments

@cached
def harpsichord(midi, gate):
    """A plucked harpsichord note held `gate` seconds, then damped. The quill
    plucks near the end of the string, so it is bright and a little nasal;
    the high harmonics die first; the 4' string rings along an octave up."""
    f = hz(midi)
    n = int((gate + 0.05) * RATE)
    acc = zeros(n)
    t1 = 1.1 * (262.0 / f) ** 0.5
    for k in range(1, 33):
        fk = f * k * math.sqrt(1.0 + 0.0001 * k * k)
        if fk > 8000.0:
            break
        a = abs(math.sin(math.pi * k * 0.14)) / k ** 0.7
        if k % 2 == 0:
            a *= 1.3
        acc = array.array('d', map(add, acc, partial(n, fk, a, t1 / (1.0 + 0.3 * (k - 1)), (k * 0.618) % 1.0)))
    r = random.Random(midi)
    q = int(0.004 * RATE)
    prev = 0.0
    for i in range(q):
        w = r.random() * 2.0 - 1.0
        acc[i] += 0.35 * (w - prev) * (1.0 - i / q)
        prev = w
    return normalize(shape(acc, 0.001, 0.05))


PULSE = [abs(math.sin(math.pi * k * 0.3)) / k for k in range(1, 41)]


@cached
def lead(midi, dur):
    """A soft pulse lead (30% duty, its top rolled off): a chiptune voice with
    the edge taken away. A little vibrato comes in on held notes."""
    f = hz(midi)
    amps = [a / math.sqrt(1.0 + (k * f / 2600.0) ** 4) for k, a in enumerate(PULSE, 1)]
    tab = wavetable(amps, f)
    n = int((dur + 0.06) * RATE)
    o = osc(tab, f, n, vib=0.005, vib_hz=5.6, vib_delay=0.16)
    tau = 0.12 * RATE
    env = [0.72 + 0.28 * math.exp(-i / tau) for i in range(n)]
    return shape(array.array('d', map(mul, o, env)), 0.006, 0.06)


@cached
def flute(midi, dur):
    """A recorder: nearly a sine, a breath of noise over it, a chiff at the
    start of each note and a gentle vibrato."""
    f = hz(midi)
    tab = wavetable([1.0, 0.16, 0.1, 0.03, 0.02], f)
    n = int((dur + 0.08) * RATE)
    o = array.array('d', osc(tab, f, n, vib=0.004, vib_hz=5.0, vib_delay=0.22))
    air = breath()
    start = (midi * 977) % (len(air) - n) if n < len(air) else 0
    chiff = int(0.03 * RATE)
    for i in range(min(n, len(air))):
        o[i] += air[start + i] * (0.05 + (0.25 * (1.0 - i / chiff) if i < chiff else 0.0))
    return shape(o, 0.03, 0.08)


STOPS = {
    # harmonic amplitudes of the note (the 'full' organ is built on the 16'
    # an octave below, so its list starts with the sub-octave)
    'flute': [1.0, 0.35, 0.12, 0.06, 0.03],
    'principal': [1.0, 0.5, 0.3, 0.25, 0.12, 0.12, 0.05, 0.08, 0.03, 0.04],
    'pedal': [1.0, 0.85, 0.5, 0.45, 0.25, 0.25, 0.12, 0.15, 0.06, 0.08],
    'full': [0.55, 1.0, 0.35, 0.75, 0.18, 0.5, 0.1, 0.4, 0.08, 0.25, 0.05, 0.3, 0.04, 0.1, 0.05, 0.2],
}


@cached
def organ(midi, dur, stop, attack=0.03, release=0.1):
    """A pipe organ note on one of STOPS, held `dur` s then released. A second
    rank a few cents sharp beats slowly against the first, like a celeste,
    and each note starts with a little chiff of air."""
    f = hz(midi)
    base = f / 2.0 if stop == 'full' else f
    tab = wavetable(STOPS[stop], base)
    n = int((dur + release) * RATE)
    a = osc(tab, base, n)
    b = osc(tab, base * 1.0017, n, phase=0.37)
    sig = array.array('d', map(add, a, map(mul, b, repeat(0.6))))
    air = breath()
    chiff = min(n, int(0.03 * RATE), len(air))
    start = (midi * 331) % (len(air) - chiff)
    for i in range(chiff):
        sig[i] += 0.12 * air[start + i] * (1.0 - i / chiff)
    return array.array('d', map(mul, sig, ramp_env(n, attack, release)))


AH = ((760.0, 1.0, 120.0), (1150.0, 0.5, 130.0), (2800.0, 0.16, 220.0), (3300.0, 0.07, 260.0))
OO = ((330.0, 1.0, 80.0), (760.0, 0.5, 110.0), (2300.0, 0.12, 200.0))
VOWELS = {'ah': AH, 'oo': OO}


def formant(h, formants=AH):
    g = 0.02
    for f, a, w in formants:
        d = (h - f) / w
        g += a / (1.0 + d * d)
    return g


@cached
def choir(midi, dur, attack, release, vowel='ah'):
    """A sung "ahh" (or "ooh"): three voices a few cents apart, each with its
    own slow vibrato, over harmonics shaped by the vowel's formants, and a
    breath."""
    f = hz(midi)
    amps = [(0.25 + 2.0 * formant(f * k, VOWELS[vowel])) / k for k in range(1, 31) if f * k < 4200.0]
    tab = wavetable(amps, f)
    n = int((dur + release) * RATE)
    acc = zeros(n)
    for v, (det, rate, ph) in enumerate(((1.0, 5.1, 0.0), (1.0041, 5.6, 0.33), (0.9959, 4.7, 0.71))):
        acc = array.array('d', map(add, acc, osc(tab, f * det, n, phase=0.29 * v, vib=0.006,
                                                   vib_hz=rate, vib_phase=ph)))
    air = breath()
    start = (midi * 613) % max(1, len(air) - n) if n < len(air) else 0
    for i in range(min(n, len(air) - start)):
        acc[i] += 0.12 * air[start + i]
    env = ramp_env(n, attack, release)
    return array.array('d', map(mul, acc, map(mul, env, repeat(1.0 / 3.0))))


@cached
def celesta(midi):
    """A celesta: a struck steel bar in a wooden box, sweet and glassy."""
    f = hz(midi)
    n = int(2.2 * RATE)
    acc = zeros(n)
    for ratio, a, d in ((1.0, 1.0, 0.9), (2.0, 0.2, 0.35), (3.0, 0.07, 0.2), (2.76, 0.08, 0.25), (5.4, 0.03, 0.1)):
        if f * ratio < 9000.0:
            acc = array.array('d', map(add, acc, partial(n, f * ratio, a, d)))
    return shape(acc, 0.002, 0.3)


BELL = ((0.5, 0.3, 3.0), (1.0, 0.45, 2.2), (1.183, 0.5, 1.8), (1.506, 0.22, 1.2), (2.0, 1.0, 1.5),
        (2.514, 0.45, 0.9), (2.662, 0.4, 0.8), (3.011, 0.45, 0.6), (4.166, 0.3, 0.4), (5.433, 0.2, 0.28),
        (6.796, 0.12, 0.2))


@cached
def bell(prime_midi, length=4.5):
    """A church bell (the partials of a real one, each a beating pair); its
    strike note is the nominal, an octave above prime_midi."""
    f = hz(prime_midi)
    n = int(length * RATE)
    acc = zeros(n)
    for ratio, a, d in BELL:
        beat = 0.35 + 0.25 * ratio
        for fk in (f * ratio - beat / 2, f * ratio + beat / 2):
            if fk < 9000.0:
                acc = array.array('d', map(add, acc, partial(n, fk, a * 0.5, d)))
    return normalize(shape(acc, 0.002, 0.6))


@cached
def strings(midi, dur, pulse):
    """Low strings bowing measured tremolo: three detuned saws, dark, each
    stroke (every `pulse` s) leaning in and easing off."""
    f = hz(midi)
    amps = [1.0 / k ** 1.1 / math.sqrt(1.0 + (k * f / 2200.0) ** 4) for k in range(1, 41)]
    tab = wavetable(amps, f)
    n = int((dur + 0.15) * RATE)
    acc = zeros(n)
    for v, (det, rate) in enumerate(((1.0, 5.5), (1.0045, 6.1), (0.9955, 4.9))):
        acc = array.array('d', map(add, acc, osc(tab, f * det, n, phase=0.21 * v, vib=0.003, vib_hz=rate)))
    p = pulse * RATE
    tau = 0.035 * RATE
    trem = [0.55 + 0.45 * math.exp(-((i % p) / tau)) for i in range(n)]
    env = ramp_env(n, 0.08, 0.15)
    return array.array('d', map(mul, map(mul, acc, trem), env))


@cached
def kick():
    """A soft kick whose body sits in the mids: a sagging sine, gently
    saturated so its harmonics reach a phone speaker, and a small click."""
    n = int(0.3 * RATE)
    out = zeros(n)
    phase = 0.0
    k = math.tanh(1.6)
    for i in range(n):
        t = i / RATE
        phase += 2 * math.pi * (62.0 + 128.0 * math.exp(-t / 0.035)) / RATE
        out[i] = math.tanh(1.6 * math.sin(phase)) / k * math.exp(-t / 0.11)
    add_into(out, shape(bandpass(noise(int(0.004 * RATE), 11), 2500.0, 1.0), 0.0005, 0.003), 0, 0.5)
    return shape(out, 0.001, 0.02)


@cached
def war_kick():
    """The Snuffer's kick, made to be heard on a phone: less boom, more
    beater. A short body sagging from 280 to 70 Hz, driven hard so its odd
    harmonics carry the thump up where a small speaker plays, a woody knock
    at 1.15 kHz and the beater's click on top."""
    n = int(0.3 * RATE)
    out = zeros(n)
    phase = 0.0
    k = math.tanh(4.0)
    for i in range(n):
        t = i / RATE
        phase += 2 * math.pi * (70.0 + 210.0 * math.exp(-t / 0.03)) / RATE
        out[i] = math.tanh(4.0 * math.sin(phase)) / k * math.exp(-t / 0.06)
    add_into(out, array.array('d', partial(int(0.08 * RATE), 1150.0, 0.8, 0.012)), 0)
    add_into(out, shape(bandpass(noise(int(0.006 * RATE), 12), 3200.0, 0.9), 0.0005, 0.004), 0, 1.5)
    return normalize(shape(out, 0.001, 0.02))


@cached
def tambourine(variant):
    """Jingles: a few bright inharmonic rings struck in a quick flurry, over
    a burst of high noise."""
    r = random.Random(100 + variant)
    n = int(0.22 * RATE)
    acc = zeros(n)
    for hit in range(3):
        at = int(r.uniform(0.0, 0.012) * RATE)
        for f in (5200.0, 6150.0, 7300.0, 8350.0, 9400.0):
            fk = f * r.uniform(0.97, 1.03)
            add_into(acc, array.array('d', partial(n - at, fk, r.uniform(0.3, 0.6) / (hit + 1), r.uniform(0.05, 0.09),
                                                   r.random())), at)
    hiss = highpass(noise(n, 200 + variant), 5000.0)
    add_into(acc, array.array('d', map(mul, hiss, (math.exp(-i / (0.05 * RATE)) for i in range(n)))), 0, 0.8)
    return normalize(shape(acc, 0.001, 0.03))


@cached
def shaker(variant):
    """A shaker: high noise with a soft front and a quick fall."""
    n = int(0.09 * RATE)
    hiss = highpass(noise(n, 300 + variant), 6000.0)
    a = 0.012 * RATE
    env = [(0.5 - 0.5 * math.cos(math.pi * i / a)) if i < a else math.exp(-(i - a) / (0.025 * RATE)) for i in range(n)]
    return normalize(shape(array.array('d', map(mul, hiss, env)), 0.001, 0.01))


@cached
def snap():
    """A soft rim on the backbeat: a snap of mid noise over a small body."""
    n = int(0.16 * RATE)
    body = array.array('d', partial(n, 210.0, 0.6, 0.05))
    crack = bandpass(noise(n, 400), 1800.0, 1.2)
    add_into(body, array.array('d', map(mul, crack, (math.exp(-i / (0.035 * RATE)) for i in range(n)))), 0, 1.5)
    return normalize(shape(body, 0.001, 0.02))


@cached
def timpani(midi, stick=0.0):
    """A timpano: the drumhead's modes (not quite harmonic), tuned by a pitch
    that settles as the head relaxes, and a felt mallet's thud. `stick`
    (0..1) trades the felt for a wooden stick, for a drum that has to reach
    a phone: a crack of noise on the strike, the upper modes (and a few
    more above them) louder, and the fundamental thinner."""
    f = hz(midi)
    n = int(1.4 * RATE)
    modes = ((1.0, 1.0, 0.75), (1.504, 0.55, 0.55), (1.742, 0.25, 0.4), (2.0, 0.35, 0.45),
             (2.245, 0.18, 0.3), (2.494, 0.2, 0.3), (2.8, 0.1, 0.22))
    if stick:
        # Wood: three more modes up top, everything from the octave mode up
        # louder, the fundamental thinner.
        modes += ((3.3, 0.12, 0.15), (3.9, 0.08, 0.12), (4.6, 0.06, 0.08))

        def lift(ratio):
            if ratio == 1.0:
                return 1.0 - 0.5 * stick
            return 1.0 + 1.5 * stick if ratio >= 2.0 else 1.0
        modes = tuple((r, a * lift(r), d) for r, a, d in modes)
    out = zeros(n)
    bend = [1.0 + 0.05 * math.exp(-i / (0.03 * RATE)) for i in range(n)]
    for ratio, a, d in modes:
        w = 2 * math.pi * f * ratio / RATE
        g = math.exp(-1.0 / (d * RATE))
        phases = accumulate((w * b for b in bend), initial=0.0)
        env = accumulate(repeat(g, n - 1), mul, initial=a)
        out = array.array('d', map(add, out, map(mul, map(math.sin, islice(phases, n)), env)))
    thud = lowpass(noise(int(0.03 * RATE), 500 + midi), 900.0)
    add_into(out, shape(thud, 0.001, 0.02), 0, 0.5)
    if stick:
        crack = bandpass(noise(int(0.02 * RATE), 520 + midi), 2200.0, 0.8)
        add_into(out, array.array('d', map(mul, crack, (math.exp(-i / (0.004 * RATE)) for i in range(len(crack))))),
                 0, 1.2 * stick)
    return normalize(shape(out, 0.002, 0.2))


@cached
def tom(hard=0.0):
    """A war drum for the backbeat: a sagging, saturated body and a slap.
    `hard` (0..1) hits it harder, for a phone: the body driven further and
    the slap louder and longer."""
    n = int(0.35 * RATE)
    out = zeros(n)
    phase = 0.0
    drive = 1.4 + 1.6 * hard
    for i in range(n):
        t = i / RATE
        phase += 2 * math.pi * (120.0 + 70.0 * math.exp(-t / 0.04)) / RATE
        out[i] = math.tanh(drive * math.sin(phase)) * math.exp(-t / 0.16)
    slap = bandpass(noise(n, 600), 1200.0, 1.0)
    ring = (0.04 + 0.02 * hard) * RATE
    add_into(out, array.array('d', map(mul, slap, (math.exp(-i / ring) for i in range(n)))), 0, 0.9 + 3.1 * hard)
    return normalize(shape(out, 0.001, 0.03))


@cached
def music_box(midi):
    """A music box tooth: a steel reed plucked by a pin. Its first overtone
    is a clamped bar's 6.27x, bright and quickly gone; a twin tooth tuned a
    hair apart makes it shimmer as it rings; the pin's tick starts it. Low
    teeth ring longer than high ones."""
    f = hz(midi)
    n = int(2.8 * RATE)
    ring = 1.9 * (880.0 / f) ** 0.35
    acc = zeros(n)
    for ratio, a, d in ((1.0, 1.0, ring), (1.0 + 0.7 / f, 0.35, ring * 0.8), (2.0, 0.06, ring * 0.25),
                        (6.27, 0.28, 0.1), (6.27 * 1.004, 0.1, 0.07)):
        if f * ratio < 9500.0:
            acc = array.array('d', map(add, acc, partial(n, f * ratio, a, d)))
    tick = highpass(noise(int(0.003 * RATE), midi), 3000.0)
    add_into(acc, shape(tick, 0.0003, 0.002), 0, 0.25)
    return normalize(shape(acc, 0.0008, 0.4))


REED = [1.0, 0.75, 0.62, 0.5, 0.45, 0.4, 0.33, 0.3, 0.25, 0.22, 0.18, 0.16, 0.13, 0.11, 0.09, 0.08, 0.07, 0.06]


@cached
def harmonium(midi, dur, bright=0.5):
    """A harmonium, the reed organ of a country chapel, pumped by foot: free
    reeds give a full, slightly nasal ladder of harmonics, rolled off above
    2-3 kHz (damp; `bright` 0..1 opens it); a second rank of reeds tuned a
    few cents sharp (the voix celeste) beats slowly against the first; the
    bellows ease each chord in and breathe a little under it."""
    f = hz(midi)
    top = 1800.0 + 1600.0 * bright
    amps = [a / math.sqrt(1.0 + (k * f / top) ** 4) for k, a in enumerate(REED, 1)]
    tab = wavetable(amps, f)
    n = int((dur + 0.3) * RATE)
    a = osc(tab, f, n)
    b = osc(tab, f * 1.0032, n, phase=0.41)
    sig = array.array('d', map(add, a, map(mul, b, repeat(0.65))))
    r = random.Random(midi * 31 + int(dur * 100))
    wob, ph = r.uniform(0.35, 0.55), r.random() * 2 * math.pi
    swell = 0.4 * RATE
    breath = [(0.82 + 0.18 * min(1.0, i / swell)) * (1.0 + 0.035 * math.sin(2 * math.pi * wob * i / RATE + ph))
              for i in range(n)]
    env = ramp_env(n, 0.09, 0.3)
    return array.array('d', map(mul, map(mul, sig, breath), env))


@cached
def drip(midi, variant=0):
    """A drop falling into a still pool, tuned to a note: the bubble it
    traps rings as it closes, its pitch leaping up to the note in a few
    milliseconds, with a tiny tick of the impact first."""
    f = hz(midi)
    n = int(0.3 * RATE)
    out = zeros(n)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        fi = f * (1.0 - 0.45 * math.exp(-t / 0.006))
        phase += 2 * math.pi * fi / RATE
        out[i] = math.sin(phase) * math.exp(-t / 0.06)
    tick = highpass(noise(int(0.002 * RATE), 900 + midi * 7 + variant), 2500.0)
    add_into(out, shape(tick, 0.0002, 0.001), 0, 0.3)
    return shape(out, 0.001, 0.02)


@cached
def plop():
    """The pool's kick: a big drop into deep water, a low bubble whooping up
    from 110 to 240 Hz, driven a little so it reaches a phone, over a wet
    thud of noise."""
    n = int(0.35 * RATE)
    out = zeros(n)
    phase = 0.0
    k = math.tanh(1.8)
    for i in range(n):
        t = i / RATE
        phase += 2 * math.pi * (240.0 - 130.0 * math.exp(-t / 0.025)) / RATE
        out[i] = math.tanh(1.8 * math.sin(phase)) / k * math.exp(-t / 0.09)
    wet = lowpass(noise(int(0.05 * RATE), 1700), 1200.0)
    add_into(out, shape(wet, 0.001, 0.04), 0, 0.6)
    return normalize(shape(out, 0.001, 0.03))


@cached
def splat():
    """A soft, wet backbeat: a slap of mid noise over a small hollow body,
    like a hand on a wet drum."""
    n = int(0.2 * RATE)
    body = array.array('d', partial(n, 260.0, 0.5, 0.04))
    wet = bandpass(noise(n, 1800), 1100.0, 0.9)
    add_into(body, array.array('d', map(mul, wet, (math.exp(-i / (0.045 * RATE)) for i in range(n)))), 0, 1.6)
    return normalize(shape(body, 0.002, 0.03))


@cached
def patter(variant):
    """Drops pattering on stone: two or three tiny high ticks close together."""
    r = random.Random(1900 + variant)
    n = int(0.08 * RATE)
    acc = zeros(n)
    for _ in range(r.randint(2, 3)):
        at = int(r.uniform(0.0, 0.03) * RATE)
        tick = bandpass(noise(int(0.01 * RATE), r.randint(0, 9999)), r.uniform(4000.0, 7000.0), 2.0)
        add_into(acc, array.array('d', map(mul, tick, (math.exp(-i / (0.002 * RATE)) for i in range(len(tick))))),
                 at, r.uniform(0.4, 1.0))
    return normalize(shape(acc, 0.0005, 0.01))


@cached
def rev_bell(prime_midi, length):
    """A church bell played backwards: its ring swells up out of nothing
    over `length` seconds into the strike, and stops. The strike is eased
    off over 60 ms so the stop is a hush, not a click."""
    b = bell(prime_midi, length)
    r = array.array('d', reversed(b))
    return shape(r, 0.05, 0.06)


@cached
def sour_organ(midi, dur, attack=0.01, release=0.08):
    """The full organ gone wrong: two ranks a quarter-tone's worth of cents
    apart (+-14), a faint third an octave down, and a 4' principal an octave
    up and a few cents flat, so every note sours and churns; a hollow,
    reedy, driving sound. The 16' is thinned and the 4' leads, so the grind
    is still there on a phone speaker, which plays nothing under 300 Hz."""
    f = hz(midi)
    full = list(STOPS['full'])
    full[0] *= 0.5                       # the 16' sub-octave, thinned
    tab = wavetable(full, f / 2.0)
    n = int((dur + release) * RATE)
    a = osc(tab, f / 2.0 * 0.992, n)
    b = osc(tab, f / 2.0 * 1.008, n, phase=0.3)
    c = osc(wavetable(STOPS['principal'], f / 4.0), f / 4.0 * 1.003, n, phase=0.6)
    d = osc(wavetable(STOPS['principal'], 2.0 * f), 2.0 * f * 0.996, n, phase=0.8)
    sig = array.array('d', (x + y + 0.2 * z + w for x, y, z, w in zip(a, b, c, d)))
    return array.array('d', map(mul, sig, ramp_env(n, attack, release)))


@cached
def swell(secs, seed):
    """A breath of high noise swelling up over `secs` into a downbeat (a
    cymbal played backwards), cut off with a 40 ms fade."""
    n = int(secs * RATE)
    x = bandpass(noise(n, seed), 3500.0, 0.7)
    env = [(i / n) ** 3 for i in range(n)]
    return shape(array.array('d', map(mul, x, env)), 0.01, 0.04)


def drone(midi, loop_secs, amps, gain=1.0, lfo=(), detune=0.0):
    """A tone that runs the whole loop and meets itself exactly at the seam:
    its pitch is nudged to a whole number of cycles per loop, and so is
    every slow swell of its level in `lfo` ([(cycles per loop, depth,
    phase)...]); `detune` adds a second copy that many whole beats per loop
    sharp. No attack, no release: it never starts or stops."""
    n = int(round(loop_secs * RATE))
    cycles = round(hz(midi) * loop_secs)
    f = cycles / loop_secs
    tab = wavetable(amps, f)
    sig = array.array('d', osc(tab, f, n))
    if detune:
        f2 = (cycles + detune) / loop_secs
        sig = array.array('d', map(add, sig, map(mul, osc(tab, f2, n, phase=0.37), repeat(0.7))))
    level = [gain] * n
    for k, depth, ph in lfo:
        w = 2 * math.pi * k / n
        level = [lv * (1.0 + depth * math.sin(w * i + ph)) for i, lv in enumerate(level)]
    return array.array('d', map(mul, sig, level))


def noise_loop(loop_secs, seed, f0, q):
    """Band-passed noise exactly a loop long, filtered round the loop (warmed
    up on its own tail), so it flows across the seam like any other part."""
    n = int(round(loop_secs * RATE))
    x = noise(n, seed)
    w = int(0.5 * RATE)
    y = bandpass(x[n - w:] + x, f0, q)
    return y[w:]


# ---------------------------------------------------------------- mixing

class Mix:
    """A loop of n samples, one buffer per stem (with some headroom past the
    end for tails, which fold back onto the start), each with its own send
    to the reverb."""

    def __init__(self, seconds, tail=5.0):
        self.n = int(round(seconds * RATE))
        self.size = self.n + int(tail * RATE)
        self.stems = {}
        self.sends = {}

    def stem(self, name, send):
        self.stems[name] = zeros(self.size)
        self.sends[name] = send

    def put(self, name, sig, t, gain=1.0):
        add_into(self.stems[name], sig, int(round(t * RATE)) % self.n, gain)

    def fold(self, name):
        """The stem as one period of the loop: its tail added onto its head."""
        buf = self.stems[name]
        out = buf[:self.n]
        tail = buf[self.n:]
        out[:len(tail)] = array.array('d', map(add, out[:len(tail)], tail))
        return out


def _comb(x, delay, feedback, damp):
    out = [0.0] * len(x)
    buf = [0.0] * delay
    j = 0
    store = 0.0
    keep = 1.0 - damp
    for i, v in enumerate(x):
        y = buf[j]
        store = y * keep + store * damp
        buf[j] = v + store * feedback
        out[i] = y
        j += 1
        if j == delay:
            j = 0
    return out


def _allpass(x, delay, feedback=0.5):
    out = [0.0] * len(x)
    buf = [0.0] * delay
    j = 0
    for i, v in enumerate(x):
        b = buf[j]
        out[i] = b - v
        buf[j] = v + b * feedback
        j += 1
        if j == delay:
            j = 0
    return out


def reverb(x, room=0.82, damp=0.3, predelay=0.02, warm=3.0):
    """A Freeverb-style hall (four damped combs into two allpasses) run round
    the loop: it first plays the loop's last `warm` seconds, so the tail is
    already ringing when the loop starts and the result loops seamlessly."""
    n = len(x)
    w = min(n, int(warm * RATE))
    pd = int(predelay * RATE)
    src = x[n - w - pd:n - pd] + x[n - pd:] + x[:n - pd]   # the warm-up, then the loop delayed by pd
    src = highpass(src, 180.0)                             # keep the bass out of the hall
    acc = [0.0] * len(src)
    for d in (557, 593, 641, 683):
        acc = list(map(add, acc, _comb(src, d, room, damp)))
    for d in (223, 173):
        acc = _allpass(acc, d)
    return array.array('d', map(mul, acc[w:], repeat(0.25)))


def highpass_loop(x, f0, warm=2.0):
    """A one-pole high-pass run round the loop (warmed up on its tail)."""
    n = len(x)
    w = min(n, int(warm * RATE))
    a = 1.0 / (1.0 + 2 * math.pi * f0 / RATE)
    out = zeros(n)
    y = prev = 0.0
    src = x[n - w:] + x
    for i, v in enumerate(src):
        y = a * (y + v - prev)
        prev = v
        if i >= w:
            out[i - w] = y
    return out


def _k_weight(x):
    """BS.1770's K-weighting (a high shelf and a high-pass) at RATE."""
    fs = RATE
    g, q, f0 = 3.999843853973347, 0.7071752369554196, 1681.974450955533
    A = 10 ** (g / 40)
    w = 2 * math.pi * f0 / fs
    c, s = math.cos(w), math.sin(w)
    alpha = s / (2 * q)
    sa = 2 * math.sqrt(A) * alpha
    a0 = (A + 1) - (A - 1) * c + sa
    y = biquad(x, A * ((A + 1) + (A - 1) * c + sa) / a0, -2 * A * ((A - 1) + (A + 1) * c) / a0,
               A * ((A + 1) + (A - 1) * c - sa) / a0, 2 * ((A - 1) - (A + 1) * c) / a0,
               ((A + 1) - (A - 1) * c - sa) / a0)
    return highpass(y, 38.13547087602444, 0.5003270373238773)


def lufs(x, loop=True):
    """Integrated loudness (BS.1770-4: 400 ms blocks every 100 ms, absolute
    and relative gates), in LUFS, for a mono signal. A loop's blocks wrap."""
    k = _k_weight(x[-RATE:] + x if loop else x)
    if loop:
        k = k[RATE:]
    n = len(k)
    sq = list(accumulate(v * v for v in (k + k[:int(0.4 * RATE)] if loop else k)))
    size, hop = int(0.4 * RATE), int(0.1 * RATE)
    last = n if loop else n - size
    blocks = []
    for s in range(0, max(1, last), hop):
        e = s + size
        if e > len(sq):
            break
        z = (sq[e - 1] - (sq[s - 1] if s > 0 else 0.0)) / size
        blocks.append(z)
    def loud(z):
        return -0.691 + 10 * math.log10(z) if z > 0 else -200.0
    gated = [z for z in blocks if loud(z) > -70.0]
    if not gated:
        return -200.0
    rel = loud(sum(gated) / len(gated)) - 10.0
    gated = [z for z in gated if loud(z) > rel]
    return loud(sum(gated) / len(gated))


def rms_db(x):
    return 10 * math.log10(max(1e-20, sum(v * v for v in x) / len(x)))


def active_db(x):
    """How loud a part is while it plays: the mean power of its 400 ms blocks
    within 20 dB of its loudest, in dB. (A bell that rings three times in 30 s
    has a tiny RMS but is not quiet.)"""
    size = int(0.4 * RATE)
    sq = list(accumulate((v * v for v in x), initial=0.0))
    blocks = [(sq[s + size] - sq[s]) / size for s in range(0, len(x) - size, size // 4)]
    top = max(blocks) if blocks else 0.0
    if top <= 0.0:
        return -200.0
    live = [z for z in blocks if z > top * 0.01]
    return 10 * math.log10(sum(live) / len(live))


def soft(v):
    """Leave it alone below KNEE; above, bend it smoothly toward CEILING."""
    a = v if v >= 0 else -v
    if a <= KNEE:
        return v
    y = KNEE + (CEILING - KNEE) * math.tanh((a - KNEE) / (CEILING - KNEE))
    return y if v > 0 else -y


def master(mix, room, damp, wet, target=TARGET_LUFS):
    """Fold the stems, add the hall, take out sub-sonics and DC, level to
    `target` LUFS and soft-clip. Returns the loop and each stem's level."""
    n = mix.n
    dry = zeros(n)
    send = zeros(n)
    levels = {}
    for name in mix.stems:
        loop = mix.fold(name)
        levels[name] = active_db(loop)
        dry = array.array('d', map(add, dry, loop))
        if mix.sends[name]:
            send = array.array('d', map(add, send, map(mul, loop, repeat(mix.sends[name]))))
    whole = rms_db(dry)
    hall = scaled(reverb(send, room, damp), wet)
    levels['hall'] = active_db(hall)
    out = array.array('d', map(add, dry, hall))
    out = highpass_loop(out, 28.0)
    mean = sum(out) / n
    out = array.array('d', (v - mean for v in out))
    gain = 10 ** ((target - lufs(out)) / 20)
    out = array.array('d', map(soft, map(mul, out, repeat(gain))))
    mean = sum(out) / n
    out = array.array('d', (v - mean for v in out))
    return out, {k: v - whole for k, v in levels.items()}


def write_wav(path, loop):
    """16-bit mono: the loop, then PAD frames repeating its head, then a
    'smpl' chunk with one forward loop over [0, len(loop))."""
    frames = array.array('h', (int(round(max(-1.0, min(1.0, v)) * 32767.0)) for v in loop))
    frames.extend(frames[:PAD])
    if sys.byteorder == 'big':
        frames.byteswap()
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames.tobytes())
    smpl = struct.pack('<9I', 0, 0, int(1e9 / RATE), 62, 0, 0, 0, 1, 0)
    smpl += struct.pack('<6I', 0, 0, 0, len(loop), 0, 0)
    with open(path, 'r+b') as f:
        f.seek(0, 2)
        f.write(b'smpl' + struct.pack('<I', len(smpl)) + smpl)
        size = f.tell()
        f.seek(4)
        f.write(struct.pack('<I', size - 8))


# ---------------------------------------------------------------- the score

def bars_of(form):
    """['Dm', ('Gm', 'A'), ...] -> per bar, [(chord, first beat, beats), ...]."""
    out = []
    for bar in form:
        if isinstance(bar, tuple):
            out.append([(c, 4.0 * i / len(bar), 4.0 / len(bar)) for i, c in enumerate(bar)])
        else:
            out.append([(bar, 0.0, 4.0)])
    return out


def chord_at(segments, beat):
    for c, s, d in segments:
        if s <= beat < s + d:
            return c
    return segments[-1][0]


def harmony(notes, segments, chords):
    """A second voice under a melody: for each note, the highest chord tone at
    least a minor third below it, so it always agrees with the harmony."""
    out = []
    for beat, dur, m in notes:
        pcs = {p % 12 for p in chords[chord_at(segments, beat)]}
        h = m - 3
        while h % 12 not in pcs:
            h -= 1
        out.append((beat, dur, h))
    return out


def chapel():
    bpm = 120.0
    spb = 60.0 / bpm
    form = ['Dm', 'C', 'Bb', 'A', 'Dm', 'C', 'Gm', 'A',
            'Dm', 'C', 'Bb', 'A', 'Dm', 'C', ('Gm', 'A'), 'Dm',
            'Bb', 'F', 'C', 'Dm', 'Bb', 'F', 'Gm', 'A',
            'Dm', 'C', 'Bb', 'A', 'Dm', 'C', 'Gm', 'A']
    bars = bars_of(form)
    mix = Mix(len(bars) * 4 * spb)
    for name, send in (('harpsichord', 0.25), ('bass', 0.06), ('lead', 0.3), ('flute', 0.35),
                       ('organ', 0.5), ('choir', 0.6), ('drums', 0.1)):
        mix.stem(name, send)
    arp = {'Dm': (62, 65, 69, 74), 'C': (60, 64, 67, 72), 'Bb': (58, 62, 65, 70), 'A': (57, 61, 64, 69),
           'Gm': (55, 58, 62, 67), 'F': (57, 60, 65, 69)}
    pad = {'Dm': (50, 57, 62, 65), 'C': (48, 55, 60, 64), 'Bb': (46, 53, 58, 62), 'A': (45, 52, 57, 61),
           'Gm': (43, 50, 55, 58), 'F': (41, 48, 53, 57)}
    root = {'Dm': 38, 'C': 36, 'Bb': 34, 'A': 33, 'Gm': 31, 'F': 29}
    hum = random.Random(1)

    A = [
        [(0, .5, 74), (.5, .5, 69), (1, .5, 74), (1.5, .5, 77), (2, .75, 81), (2.75, .25, 79), (3, .5, 77), (3.5, .5, 76)],
        [(0, .5, 76), (.5, .5, 72), (1, .5, 76), (1.5, .5, 79), (2, 1.0, 84), (3, .5, 82), (3.5, .5, 79)],
        [(0, .5, 77), (.5, .5, 74), (1, .5, 77), (1.5, .5, 82), (2, .75, 81), (2.75, .25, 79), (3, .5, 77), (3.5, .5, 74)],
        [(0, 1.5, 76), (1.5, .5, 73), (2, .5, 76), (2.5, .5, 81), (3, 1.0, 79)],
    ]
    A += [A[0], A[1],
          [(0, .5, 74), (.5, .5, 70), (1, .5, 74), (1.5, .5, 79), (2, .75, 82), (2.75, .25, 81), (3, .5, 79), (3.5, .5, 77)],
          [(0, 1.0, 76), (1, .5, 73), (1.5, .5, 76), (2, 2.0, 81)]]
    A2 = A[:3] + [
        [(0, .5, 73), (.5, .5, 76), (1, .5, 81), (1.5, .5, 76), (2, 1.0, 85), (3, .5, 81), (3.5, .5, 79)],
        [(0, .5, 81), (.5, .5, 77), (1, .5, 81), (1.5, .5, 86), (2, .75, 84), (2.75, .25, 82), (3, .5, 81), (3.5, .5, 77)],
        [(0, .5, 79), (.5, .5, 76), (1, .5, 79), (1.5, .5, 84), (2, .75, 82), (2.75, .25, 81), (3, .5, 79), (3.5, .5, 76)],
        [(0, .5, 74), (.5, .5, 79), (1, .5, 82), (1.5, .5, 81), (2, .5, 73), (2.5, .5, 76), (3, .5, 81), (3.5, .5, 79)],
        [(0, .5, 77), (.5, .5, 76), (1, 2.5, 74), (3.5, .5, 72)],
    ]
    B = [
        [(0, 1.5, 74), (1.5, .5, 77), (2, 1.5, 82), (3.5, .5, 81)],
        [(0, 1.0, 81), (1, .5, 79), (1.5, .5, 77), (2, 2.0, 72)],
        [(0, 1.5, 76), (1.5, .5, 79), (2, 1.5, 84), (3.5, .5, 82)],
        [(0, 2.0, 81), (2, 1.0, 77), (3, 1.0, 74)],
        [(0, 1.5, 74), (1.5, .5, 77), (2, 1.0, 82), (3, 1.0, 86)],
        [(0, 1.0, 84), (1, .5, 81), (1.5, .5, 77), (2, 2.0, 81)],
        [(0, 1.0, 82), (1, .5, 81), (1.5, .5, 79), (2, 1.0, 74), (3, 1.0, 79)],
        [(0, 1.0, 81), (1, .5, 79), (1.5, .5, 77), (2, .5, 76), (2.5, .5, 73), (3, .5, 76), (3.5, .5, 79)],
    ]

    for b, segments in enumerate(bars):
        section = b // 8                 # 0 A, 1 A', 2 B, 3 A''
        t0 = b * 4 * spb
        last_of_b = b == 23
        for chord, s, d in segments:
            # Harpsichord: running sixteenths (eighths in the bridge).
            notes = arp[chord]
            if section == 2:
                steps, order = 2, (0, 1, 2, 3, 2, 1, 2, 3)
            else:
                steps, order = 4, (0, 2, 1, 2, 3, 2, 1, 2)
            for j in range(int(d * steps)):
                beat = s + j / steps
                accent = 1.0 if j % steps == 0 else (0.8 if j % 2 == 0 else 0.68)
                t = t0 + beat * spb + hum.uniform(-0.004, 0.004)
                mix.put('harpsichord', harpsichord(notes[order[j % 8]], 0.2 if steps == 4 else 0.32), t,
                        0.45 * accent * hum.uniform(0.92, 1.0))
            # Pedal bass: octaves pumping in eighths; long notes in the bridge.
            r = root[chord]
            if section == 2:
                for j in range(int(d / 2)):
                    mix.put('bass', organ(r, 2 * spb - 0.08, 'pedal', 0.02, 0.08), t0 + (s + 2 * j) * spb, 0.22)
                    mix.put('bass', organ(r + 12, 2 * spb - 0.08, 'pedal', 0.02, 0.08), t0 + (s + 2 * j) * spb, 0.16)
            else:
                for j in range(int(d * 2)):
                    m = r + (12 if j % 2 else 0)
                    mix.put('bass', organ(m, 0.19, 'pedal', 0.008, 0.05), t0 + (s + j / 2) * spb,
                            0.26 if j % 4 == 0 else 0.2)
            # Organ pad from the second verse on; the choir sings the bridge.
            if section >= 1:
                for m in pad[chord]:
                    mix.put('organ', organ(m, d * spb, 'principal', 0.06, 0.25), t0 + s * spb,
                            0.05 if section == 1 else 0.07)
            if section == 2:
                for m in arp[chord][1:]:
                    mix.put('choir', choir(m + 12 if m < 64 else m, d * spb, 0.35, 0.6), t0 + s * spb, 0.13)
        # The tune.
        k = b % 8
        if section == 0 or section == 3:
            for beat, dur, m in A[k]:
                mix.put('lead', lead(m, dur * spb - 0.03), t0 + beat * spb, 0.34)
        if section == 1:
            for beat, dur, m in A2[k]:
                mix.put('lead', lead(m, dur * spb - 0.03), t0 + beat * spb, 0.34)
        if section == 2:
            for beat, dur, m in B[k]:
                mix.put('flute', flute(m, dur * spb - 0.02), t0 + beat * spb, 0.34)
        if section == 3:
            for beat, dur, m in harmony(A[k], segments, arp):
                mix.put('flute', flute(m, dur * spb - 0.02), t0 + beat * spb, 0.16)
        # Drums.
        if section == 2:
            kicks, tambs, snaps = [0.0], [2.0], []
            shakes = [0.5, 1.5, 2.5, 3.5]
            if last_of_b:
                kicks, tambs = [0.0, 1.0, 2.0, 3.0], [1.0 + j / 4 for j in range(12)]
        else:
            kicks = [0.0, 2.0] if section == 0 else [0.0, 1.5, 2.0]
            if k == 7 and section != 0:
                kicks.append(3.5)
            tambs, snaps = [1.0, 3.0], ([1.0, 3.0] if section >= 1 else [])
            shakes = [j / 2 for j in range(8)]
        for beat in kicks:
            mix.put('drums', kick(), t0 + beat * spb, 0.42)
        for i, beat in enumerate(tambs):
            level = 0.13 if not last_of_b else 0.05 + 0.1 * i / len(tambs)
            mix.put('drums', tambourine(i % 3), t0 + beat * spb + hum.uniform(-0.003, 0.003), level)
        for beat in snaps:
            mix.put('drums', snap(), t0 + beat * spb, 0.1)
        for j, beat in enumerate(shakes):
            mix.put('drums', shaker(j % 2), t0 + beat * spb + hum.uniform(-0.004, 0.004),
                    0.05 if beat % 1 else 0.035)
    return mix, dict(room=0.8, damp=0.3, wet=0.9), bpm


def title():
    bpm = 64.0
    spb = 60.0 / bpm
    form = ['Dm', 'Bb', 'Gm', 'A', 'Dm', 'F', 'Gm', 'A']
    mix = Mix(len(form) * 4 * spb, tail=6.0)
    for name, send in (('organ', 0.5), ('choir', 0.7), ('bell', 0.9), ('celesta', 0.6)):
        mix.stem(name, send)
    organ_v = {'Dm': (50, 57, 62, 65), 'Bb': (46, 53, 58, 62), 'Gm': (43, 50, 55, 58), 'A': (45, 52, 57, 61),
               'F': (41, 48, 53, 57)}
    voices = {'Dm': (65, 69, 74), 'Bb': (65, 70, 74), 'Gm': (67, 70, 74), 'A': (64, 69, 73), 'F': (65, 69, 72)}
    bar = 4 * spb
    for b, chord in enumerate(form):
        t0 = b * bar
        sus = b == 7   # the last A leans on a suspended fourth first
        for m in organ_v[chord]:
            if sus and m == 61:
                mix.put('organ', organ(62, bar / 2, 'flute', 0.5, 0.5), t0, 0.08)
                mix.put('organ', organ(61, bar / 2 + 0.4, 'flute', 0.4, 0.8), t0 + bar / 2, 0.08)
            else:
                mix.put('organ', organ(m, bar + 0.2, 'flute', 0.6, 0.9), t0, 0.08)
        mix.put('organ', organ(organ_v[chord][0] - 12, bar + 0.2, 'pedal', 0.8, 0.9), t0, 0.04)
        for m in voices[chord]:
            if sus and m == 73:
                mix.put('choir', choir(74, bar / 2 + 0.3, 0.9, 0.6), t0, 0.2)
                mix.put('choir', choir(73, bar / 2 + 0.6, 0.5, 1.2), t0 + bar / 2, 0.2)
            else:
                mix.put('choir', choir(m, bar + 0.5, 1.2, 1.4), t0, 0.2)
    # A distant bell, now and then.
    for b, beat, prime, level in ((0, 0.0, 62, 0.8), (4, 0.0, 62, 0.7), (7, 2.0, 57, 0.5)):
        mix.put('bell', bell(prime), b * bar + beat * spb, level)
    # The celesta half-remembers the chapel tune, slowly.
    tune = [(4, 0, 74), (4, 1, 69), (4, 2, 74), (4, 3, 77),
            (5, 0, 81), (5, 2, 79), (5, 3, 77),
            (6, 0, 74), (6, 1, 70), (6, 2, 74), (6, 3, 79),
            (7, 0, 76), (7, 2, 73), (7, 3, 76)]
    for b, beat, m in tune:
        mix.put('celesta', celesta(m), b * bar + beat * spb, 0.28)
    return mix, dict(room=0.88, damp=0.35, wet=0.6), bpm


def boss():
    bpm = 140.0
    spb = 60.0 / bpm
    form = ['Dm', 'Bb', 'Eb', 'A', 'Dm', 'Bb', 'Eb', 'A',
            'Gm', 'Dm', 'Gm', 'A', 'Bb', 'Gm', 'Eb', 'A',
            'Dm', 'Bb', 'Eb', 'A', 'Dm', 'Bb', ('Eb', 'A'), 'A']
    bars = bars_of(form)
    mix = Mix(len(bars) * 4 * spb)
    for name, send in (('organ', 0.3), ('strings', 0.25), ('drums', 0.12), ('lead', 0.25), ('harpsichord', 0.2)):
        mix.stem(name, send)
    stab = {'Dm': (50, 57, 62, 65), 'Bb': (46, 53, 58, 62), 'Eb': (51, 55, 58, 63), 'A': (45, 52, 57, 61),
            'Gm': (43, 50, 55, 58)}
    low = {'Dm': 38, 'Bb': 34, 'Eb': 39, 'A': 33, 'Gm': 31}
    hum = random.Random(3)
    A = [
        [(0, .75, 81), (.75, .25, 81), (1, .5, 81), (1.5, .5, 82), (2, 1.0, 81), (3, .5, 77), (3.5, .5, 74)],
        [(0, .75, 77), (.75, .25, 77), (1, .5, 77), (1.5, .5, 79), (2, 1.0, 77), (3, .5, 74), (3.5, .5, 70)],
        [(0, .75, 79), (.75, .25, 79), (1, .5, 79), (1.5, .5, 80), (2, 1.0, 79), (3, .5, 75), (3.5, .5, 70)],
        [(0, .5, 73), (.5, .5, 76), (1, .5, 81), (1.5, .5, 85), (2, 1.0, 82), (3, .5, 81), (3.5, .5, 76)],
    ]
    A = A + A[:3] + [[(0, .5, 85), (.5, .5, 82), (1, .5, 81), (1.5, .5, 79), (2, .25, 77), (2.25, .25, 76),
                      (2.5, .25, 74), (2.75, .25, 73), (3, 1.0, 76)]]
    B = [
        [(0, 1.5, 86), (1.5, .5, 84), (2, 1.0, 82), (3, 1.0, 79)],
        [(0, 1.5, 81), (1.5, .5, 79), (2, 1.0, 77), (3, 1.0, 74)],
        [(0, 1.5, 79), (1.5, .5, 81), (2, 1.0, 82), (3, 1.0, 86)],
        [(0, 2.0, 85), (2, .5, 82), (2.5, .5, 81), (3, .5, 79), (3.5, .5, 76)],
        [(0, 1.5, 77), (1.5, .5, 79), (2, 1.0, 82), (3, 1.0, 86)],
        [(0, 1.5, 86), (1.5, .5, 84), (2, 1.0, 82), (3, 1.0, 79)],
        [(0, 1.0, 79), (1, 1.0, 82), (2, 1.0, 87), (3, 1.0, 86)],
        [(0, .5, 85), (.5, .5, 81), (1, .5, 76), (1.5, .5, 73), (2, 2.0, 76)],
    ]
    C = A[:6] + [
        [(0, .5, 79), (.5, .5, 82), (1, .5, 87), (1.5, .5, 82), (2, .5, 85), (2.5, .5, 81), (3, .5, 76), (3.5, .5, 73)],
        [(0, .5, 76), (.5, .5, 81), (1, .5, 85), (1.5, .5, 81), (2, 2.0, 81)],
    ]
    for b, segments in enumerate(bars):
        section = b // 8
        t0 = b * 4 * spb
        k = b % 8
        for chord, s, d in segments:
            # Pounding organ: every eighth a staccato chord, the downbeats hardest.
            for j in range(int(d * 2)):
                beat = s + j / 2
                accent = (1.0, 0.62, 0.78, 0.62)[j % 4]
                for m in stab[chord]:
                    mix.put('organ', organ(m, 0.13, 'full', 0.006, 0.05), t0 + beat * spb, 0.19 * accent)
            # Low strings in measured tremolo: root and fifth, and the octave above.
            r = low[chord]
            for m, g in ((r, 0.075), (r + 7, 0.05), (r + 12, 0.06)):
                mix.put('strings', strings(m, d * spb, spb / 4), t0 + s * spb, g)
        # Timpani on D and A; a roll into each section's return.
        dom = segments[0][0] == 'A'
        drum = timpani(45 if dom else 50)
        if k == 7:
            for j in range(16):
                beat = 2.0 + j / 8
                mix.put('drums', timpani(45 if j % 2 else 50), t0 + beat * spb, 0.12 + 0.3 * j / 16)
            hits = [0.0]
        else:
            hits = [0.0, 2.0, 3.5] if section != 1 else [0.0, 2.0]
        for beat in hits:
            mix.put('drums', drum, t0 + beat * spb, 0.45 if beat == 0 else 0.32)
        for beat in (1.0, 3.0):
            mix.put('drums', tom(), t0 + beat * spb + hum.uniform(-0.003, 0.003), 0.3)
        if section == 1:
            for beat in (0.5, 1.5, 2.5, 3.5):
                mix.put('drums', shaker(int(beat) % 2), t0 + beat * spb, 0.05)
        # The tune: the lead, doubled by harpsichord an octave down on the return.
        for beat, dur, m in (A, B, C)[section][k]:
            mix.put('lead', lead(m, dur * spb - 0.025), t0 + beat * spb, 0.3)
            if section == 2:
                mix.put('harpsichord', harpsichord(m - 12, min(0.3, dur * spb)), t0 + beat * spb, 0.28)
    return mix, dict(room=0.82, damp=0.3, wet=1.05), bpm


# The title melody (the chapel tune's opening) slowed into a waltz: one list
# of (beat, beats, midi) per 3/4 bar. A, then A' (the same, turning home to
# D), then a bridge that climbs to D6 and runs back down to the dominant.
STORY_TUNE = [
    [(0, 1.5, 74), (1.5, .5, 69), (2, .5, 74), (2.5, .5, 77)],     # Dm   D5 . A4 D5 F5
    [(0, 2, 81), (2, .5, 79), (2.5, .5, 77)],                      # Dm   A5 -- G5 F5
    [(0, 1.5, 76), (1.5, .5, 72), (2, .5, 76), (2.5, .5, 79)],     # C
    [(0, 2, 84), (2, .5, 82), (2.5, .5, 79)],                      # C    C6 -- Bb5 G5
    [(0, 1.5, 77), (1.5, .5, 74), (2, .5, 77), (2.5, .5, 82)],     # Bb
    [(0, 2, 81), (2, .5, 79), (2.5, .5, 77)],                      # Bb
    [(0, 1.5, 76), (1.5, .5, 73), (2, .5, 76), (2.5, .5, 81)],     # A
    [(0, 1, 79), (1, 1, 76), (2, 1, 73)],                          # A    G5 E5 C#5, down the A7
    [(0, 1.5, 74), (1.5, .5, 69), (2, .5, 74), (2.5, .5, 77)],     # Dm
    [(0, 2, 81), (2, .5, 79), (2.5, .5, 77)],                      # Dm
    [(0, 1.5, 76), (1.5, .5, 72), (2, .5, 76), (2.5, .5, 79)],     # C
    [(0, 1.5, 84), (1.5, .5, 82), (2, .5, 81), (2.5, .5, 79)],     # C
    [(0, 1.5, 74), (1.5, .5, 70), (2, .5, 74), (2.5, .5, 79)],     # Gm
    [(0, 2, 82), (2, .5, 81), (2.5, .5, 79)],                      # Gm
    [(0, 1, 77), (1, 1, 76), (2, 1, 73)],                          # A    F5 leaning on E5, C#5
    [(0, 3, 74)],                                                  # Dm   home
    [(0, 1.5, 74), (1.5, .5, 77), (2, 1, 82)],                     # Bb   the bridge
    [(0, 2, 81), (2, 1, 77)],                                      # F
    [(0, 1.5, 79), (1.5, .5, 76), (2, 1, 84)],                     # C
    [(0, 1.5, 81), (1.5, .5, 79), (2, 1, 77)],                     # Dm
    [(0, 2, 86), (2, 1, 82)],                                      # Bb   D6, the top
    [(0, 1.5, 84), (1.5, .5, 81), (2, 1, 77)],                     # F
    [(0, 1, 82), (1, 1, 81), (2, 1, 79)],                          # Gm
    [(0, 1, 81), (1, .5, 79), (1.5, .5, 77), (2, .5, 76), (2.5, .5, 73)],   # A  running home
]


def story():
    bpm = 66.0
    spb = 60.0 / bpm
    bar = 3 * spb
    form = ['Dm', 'Dm', 'C', 'C', 'Bb', 'Bb', 'A', 'A',
            'Dm', 'Dm', 'C', 'C', 'Gm', 'Gm', 'A', 'Dm',
            'Bb', 'F', 'C', 'Dm', 'Bb', 'F', 'Gm', 'A']
    mix = Mix(len(form) * bar, tail=6.0)
    for name, send in (('box', 0.5), ('waltz', 0.4), ('organ', 0.55), ('choir', 0.7)):
        mix.stem(name, send)
    triad = {'Dm': (62, 65, 69), 'C': (60, 64, 67), 'Bb': (58, 62, 65), 'A': (57, 61, 64), 'Gm': (55, 58, 62),
             'F': (60, 65, 69)}
    pad = {'Dm': (50, 57, 62, 65), 'C': (48, 55, 60, 64), 'Bb': (46, 53, 58, 62), 'A': (45, 52, 57, 61),
           'Gm': (43, 50, 55, 58), 'F': (41, 48, 53, 57)}
    root = {'Dm': 50, 'C': 48, 'Bb': 46, 'A': 45, 'Gm': 43, 'F': 41}
    hum = random.Random(5)
    for b, chord in enumerate(form):
        t0 = b * bar
        section = b // 8                      # 0 A, 1 A', 2 the bridge
        # The tune, an octave up on the box, a hair unsteady like a real
        # one; the second time through a harmony rings under it.
        for beat, dur, m in STORY_TUNE[b]:
            t = t0 + beat * spb + hum.uniform(-0.006, 0.006)
            mix.put('box', music_box(m + 12), t, (0.36 if beat == 0 else 0.3) * hum.uniform(0.9, 1.0))
        if section == 1:
            for beat, dur, m in harmony(STORY_TUNE[b], [(chord, 0.0, 3.0)], triad):
                mix.put('box', music_box(m + 12), t0 + beat * spb + 0.014, 0.12)
        # Oom-pah-pah on the low teeth: the root, then the chord's upper pair
        # on two and three.
        mix.put('waltz', music_box(root[chord] + 12), t0 + hum.uniform(0.0, 0.006), 0.22)
        for beat in (1, 2):
            for m in triad[chord][1:]:
                mix.put('waltz', music_box(m), t0 + beat * spb + hum.uniform(-0.005, 0.005), 0.09)
        # A soft organ under it all, fuller after the first eight bars, with
        # the pedal; the choir hums the bridge.
        for m in pad[chord]:
            mix.put('organ', organ(m, bar + 0.15, 'flute', 0.5, 0.9), t0, 0.032 if section == 0 else 0.045)
        if section >= 1:
            mix.put('organ', organ(root[chord] - 12, bar + 0.15, 'pedal', 0.5, 0.9), t0, 0.022)
        if section == 2:
            for m in triad[chord]:
                mix.put('choir', choir(m, bar + 0.4, 0.7, 1.0, 'oo'), t0, 0.1)
    return mix, dict(room=0.86, damp=0.35, wet=0.7), bpm


def hush():
    L = 40.0
    mix = Mix(L, tail=6.0)
    for name, send in (('drone', 0.35), ('air', 0.3), ('bells', 0.9)):
        mix.stem(name, send)
    # The drone: D2 and A2 as a dark, reedy organ whose weight sits in the
    # low mids (a phone can't play a bare 73 Hz), and D3 hummed on "oo";
    # each breathes on a slow cycle of its own that fits the loop.
    reedy = [0.45, 0.6, 0.8, 0.9, 1.0, 0.9, 0.75, 0.6, 0.5, 0.4, 0.32, 0.25, 0.2, 0.15, 0.1, 0.08]
    mix.put('drone', drone(38, L, reedy, 0.2, [(2, 0.22, 0.0), (5, 0.1, 1.3)], detune=3), 0.0)
    mix.put('drone', drone(45, L, reedy, 0.11, [(3, 0.45, 2.0)], detune=2), 0.0)
    oo = [(0.3 + 2.0 * formant(hz(50) * k, OO)) / k for k in range(1, 25) if hz(50) * k < 4000.0]
    mix.put('drone', drone(50, L, oo, 0.12, [(1, 0.6, 4.0), (4, 0.2, 0.5)], detune=1), 0.0)
    # A thin shimmer high over it, a fifth and an octave, fading in and out.
    mix.put('drone', drone(74, L, [1.0, 0.1], 0.022, [(2, 0.95, 3.0)], detune=3), 0.0)
    mix.put('drone', drone(81, L, [1.0, 0.1], 0.016, [(3, 0.95, 1.0)], detune=4), 0.0)
    # A cold wind through the nave, rising and falling.
    n = mix.n
    wind = noise_loop(L, 21, 650.0, 1.4)
    gust = [0.5 + 0.35 * math.sin(2 * math.pi * 3 * i / n + 0.7) + 0.15 * math.sin(2 * math.pi * 7 * i / n) for i in range(n)]
    mix.put('air', array.array('d', map(mul, wind, gust)), 0.0, 0.3)
    # Bells swelling up backwards out of the dark and stopping short: D5,
    # A4, the Phrygian Eb5 (the dark one), C5, A4 and D5 again, spaced
    # unevenly so they never fall into a beat.
    for end, prime, level in ((3.0, 62, 0.8), (10.5, 57, 0.65), (16.2, 63, 0.58), (23.6, 60, 0.68),
                              (30.2, 57, 0.74), (36.0, 62, 0.55)):
        mix.put('bells', rev_bell(prime, 4.0), end - 4.0, level)
    return mix, dict(room=0.92, damp=0.4, wet=0.9, target=-20.0), 0


DAWN_TUNE = [
    [(0, 1.5, 74), (1.5, .5, 69), (2, .5, 74), (2.5, .5, 78)],     # D    D5 . A4 D5 F#5
    [(0, 2, 81), (2, .5, 79), (2.5, .5, 78)],                      # D
    [(0, 1.5, 76), (1.5, .5, 73), (2, .5, 76), (2.5, .5, 81)],     # A
    [(0, 2, 85), (2, .5, 83), (2.5, .5, 81)],                      # A    C#6 -- B5 A5
    [(0, 1.5, 74), (1.5, .5, 71), (2, .5, 74), (2.5, .5, 79)],     # G
    [(0, 2, 83), (2, .5, 81), (2.5, .5, 79)],                      # G
    [(0, 1.5, 76), (1.5, .5, 73), (2, .5, 76), (2.5, .5, 81)],     # A
    [(0, 1, 79), (1, 1, 76), (2, 1, 73)],                          # A
    [(0, 1.5, 74), (1.5, .5, 69), (2, .5, 74), (2.5, .5, 78)],     # D
    [(0, 2, 81), (2, .5, 79), (2.5, .5, 78)],                      # D
    [(0, 1.5, 78), (1.5, .5, 74), (2, .5, 78), (2.5, .5, 83)],     # Bm
    [(0, 1.5, 86), (1.5, .5, 85), (2, .5, 83), (2.5, .5, 81)],     # Bm
    [(0, 1.5, 74), (1.5, .5, 71), (2, .5, 74), (2.5, .5, 79)],     # G
    [(0, 2, 83), (2, .5, 81), (2.5, .5, 79)],                      # Em
    [(0, 1.5, 81), (1.5, .5, 79), (2, 1, 76)],                     # A
    [(0, 1.5, 78), (1.5, .5, 76), (2, 1, 74)],                     # D    F#5 E5 D5: resolved
    [(0, 1.5, 74), (1.5, .5, 79), (2, 1, 83)],                     # G    the bells ring out
    [(0, 2, 81), (2, 1, 78)],                                      # D
    [(0, 1.5, 79), (1.5, .5, 76), (2, 1, 83)],                     # Em
    [(0, 1.5, 81), (1.5, .5, 79), (2, 1, 76)],                     # A
    [(0, 2, 86), (2, 1, 83)],                                      # G    D6
    [(0, 1.5, 81), (1.5, .5, 78), (2, 1, 86)],                     # D
    [(0, 1, 85), (1, 1, 83), (2, 1, 81)],                          # A
    [(0, 3, 86)],                                                  # D    home, high
]


def dawn():
    bpm = 72.0
    spb = 60.0 / bpm
    bar = 3 * spb
    form = ['D', 'D', 'A', 'A', 'G', 'G', 'A', 'A',
            'D', 'D', 'Bm', 'Bm', 'G', 'Em', 'A', 'D',
            'G', 'D', 'Em', 'A', 'G', 'D', 'A', 'D']
    mix = Mix(len(form) * bar, tail=6.0)
    for name, send in (('celesta', 0.6), ('box', 0.45), ('choir', 0.7), ('organ', 0.5), ('bells', 0.75)):
        mix.stem(name, send)
    triad = {'D': (62, 66, 69), 'A': (61, 64, 69), 'G': (59, 62, 67), 'Bm': (59, 62, 66), 'Em': (59, 64, 67)}
    pad = {'D': (50, 57, 62, 66), 'A': (45, 52, 57, 61), 'G': (43, 50, 55, 59), 'Bm': (47, 54, 59, 62),
           'Em': (40, 47, 52, 55)}
    root = {'D': 50, 'A': 45, 'G': 43, 'Bm': 47, 'Em': 40}
    tones = {'D': (2, 6, 9), 'A': (9, 1, 4), 'G': (7, 11, 2), 'Bm': (11, 2, 6), 'Em': (4, 7, 11)}
    hum = random.Random(9)
    for b, chord in enumerate(form):
        t0 = b * bar
        section = b // 8
        # The tune on celesta an octave up; in the last eight bars the choir
        # sings it too.
        for beat, dur, m in DAWN_TUNE[b]:
            t = t0 + beat * spb + hum.uniform(-0.005, 0.005)
            mix.put('celesta', celesta(m + 12), t, 0.25 if beat == 0 else 0.21)
            if section == 2:
                mix.put('choir', choir(m, dur * spb + 0.1, 0.07, 0.35), t, 0.17)
        # The story's music box waltz, lighter once the bells take over.
        g = 0.07 if section == 2 else 0.1
        mix.put('box', music_box(root[chord] + 12), t0, g * 2.2)
        for beat in (1, 2):
            for m in triad[chord][1:]:
                mix.put('box', music_box(m), t0 + beat * spb + hum.uniform(-0.004, 0.004), g)
        # The choir holds the chord, swelling section by section; the organ
        # under it, the pedal from the second eight.
        for m in triad[chord]:
            mix.put('choir', choir(m, bar + 0.3, 0.5, 0.8), t0, (0.1, 0.15, 0.18)[section])
        for m in pad[chord]:
            mix.put('organ', organ(m, bar + 0.1, 'principal' if section == 2 else 'flute', 0.3, 0.6), t0,
                    (0.03, 0.04, 0.05)[section])
        if section >= 1:
            mix.put('organ', organ(root[chord] - 12, bar + 0.1, 'pedal', 0.3, 0.6), t0, 0.025)
        # Bells: a toll on D every fourth bar at first; then the tower rings
        # out, each bar's chord rung down in eighths like a peal in rounds.
        if section < 2 and b % 4 == 0:
            mix.put('bells', bell(62), t0, 0.55)
            mix.put('bells', bell(50), t0, 0.4)
        if section == 2:
            peal = sorted((m for m in range(66, 87) if m % 12 in tones[chord]), reverse=True)[:6]
            for j, m in enumerate(peal):
                mix.put('bells', bell(m - 12, 3.5), t0 + j * 0.5 * spb + hum.uniform(-0.01, 0.01),
                        (0.3 if j == 0 else 0.22) * hum.uniform(0.85, 1.0))
    return mix, dict(room=0.88, damp=0.3, wet=0.7), bpm


# World 2's tune, per 4/4 bar. A: the title motif dragged slow on a solo
# reed; B: the drops take the tune higher; C: a bare breakdown.
TALLOW_TUNE = [
    [(0, 1.5, 74), (1.5, .5, 69), (2, 1, 74), (3, 1, 77)],     # Dm   D5 . A4 D5 F5
    [(0, 2, 74), (2, 1, 70), (3, 1, 74)],                      # Bb
    [(0, 1.5, 79), (1.5, .5, 77), (2, 1, 74), (3, 1, 70)],     # Gm
    [(0, 3, 73), (3, 1, 76)],                                  # A
    [(0, 1.5, 74), (1.5, .5, 69), (2, 1, 74), (3, 1, 77)],     # Dm
    [(0, 2, 81), (2, 1, 79), (3, 1, 77)],                      # F
    [(0, 1.5, 79), (1.5, .5, 82), (2, 1, 81), (3, 1, 79)],     # Gm
    [(0, 2, 76), (2, 1, 73), (3, 1, 69)],                      # A
    [(0, 1, 86), (1, 1, 82), (2, 2, 77)],                      # Bb   the drops sing
    [(0, 1, 84), (1, 1, 81), (2, 2, 77)],                      # F
    [(0, 1, 82), (1, 1, 79), (2, 1, 74), (3, 1, 79)],          # Gm
    [(0, 3, 81), (3, 1, 77)],                                  # Dm
    [(0, 1, 86), (1, 1, 82), (2, 1.5, 77), (3.5, .5, 79)],     # Bb
    [(0, 1, 84), (1, 1, 79), (2, 2, 76)],                      # C
    [(0, 1, 77), (1, 1, 76), (2, 1, 74), (3, 1, 72)],          # Dm
    [(0, 2, 73), (2, 2, 76)],                                  # A
    [(0, 2, 69), (2, 2, 74)],                                  # Dm   breakdown
    [(0, 4, 77)],                                              # Dm
    [(0, 2, 74), (2, 2, 70)],                                  # Bb
    [(0, 4, 73)],                                              # A
]


def tallow():
    bpm = 80.0
    spb = 60.0 / bpm
    form = ['Dm', 'Bb', 'Gm', 'A', 'Dm', 'F', 'Gm', 'A',
            'Bb', 'F', 'Gm', 'Dm', 'Bb', 'C', 'Dm', 'A',
            'Dm', 'Dm', 'Bb', 'A']
    mix = Mix(len(form) * 4 * spb, tail=6.0)
    for name, send in (('harmonium', 0.45), ('lead', 0.4), ('glass', 0.6), ('bass', 0.08), ('drips', 0.4),
                       ('drums', 0.18)):
        mix.stem(name, send)
    voicing = {'Dm': (57, 62, 65, 69), 'Bb': (58, 62, 65, 70), 'Gm': (55, 58, 62, 67), 'A': (57, 61, 64, 69),
               'F': (57, 60, 65, 69), 'C': (55, 60, 64, 67)}
    root = {'Dm': 38, 'Bb': 34, 'Gm': 31, 'A': 33, 'F': 41, 'C': 36}
    pent = [74, 77, 79, 81, 84, 86, 89, 91, 93]
    hum = random.Random(11)
    # One drip pattern per two bars: which sixteenths drip, on which notes.
    steps = [(0, 5), (3, 8), (6, 3), (10, 6), (13, 4)]
    for b, chord in enumerate(form):
        t0 = b * 4 * spb
        section = 0 if b < 8 else (1 if b < 16 else 2)
        # The harmonium: the chord held through the bar, the bellows easing
        # it in; its low reed for the bass.
        for m in voicing[chord]:
            mix.put('harmonium', harmonium(m, 4 * spb - 0.05, 0.35), t0, 0.065 if section < 2 else 0.055)
        mix.put('bass', harmonium(root[chord] + 12, 4 * spb - 0.05, 0.15), t0, 0.16)
        if section < 2:
            mix.put('bass', harmonium(root[chord] + 12, 1.5 * spb, 0.15), t0 + 2.5 * spb, 0.07)
        # The tune: a brighter solo reed in A and the breakdown; the drops
        # (a plink with a glassy ring) in B, the reed answering softly under.
        for beat, dur, m in TALLOW_TUNE[b]:
            t = t0 + beat * spb
            if section == 1:
                mix.put('glass', drip(m + 12, 1), t, 0.2)
                mix.put('glass', celesta(m + 12), t + 0.004, 0.18)
                mix.put('lead', harmonium(m - 12, dur * spb - 0.04, 0.6), t, 0.07)
            else:
                mix.put('lead', harmonium(m, dur * spb - 0.04, 0.8), t, 0.26 if section == 0 else 0.2)
        # The drips: a lazy figure on the pentatonic, shifting every two bars.
        shift = (b // 2) % 3
        for j, (step, deg) in enumerate(steps):
            m = pent[(deg + shift * 2 + j) % len(pent)]
            mix.put('drips', drip(m + 12, j), t0 + step * spb / 4 + hum.uniform(-0.006, 0.006),
                    0.34 * hum.uniform(0.7, 1.0) * (1.0 if section < 2 else 1.25))
        for s16 in range(16):
            if s16 % 4 != 0 or section == 2:
                mix.put('drips', patter(s16 % 5), t0 + s16 * spb / 4 + hum.uniform(-0.005, 0.005),
                        (0.06 if s16 % 2 else 0.085) * hum.uniform(0.6, 1.0))
        # The kit: a big drop plopping for the kick, a wet slap on the backbeat.
        if section < 2:
            for beat in ((0.0, 2.5) if b % 2 == 0 else (0.0, 1.75, 2.5)):
                mix.put('drums', plop(), t0 + beat * spb, 0.34 if beat == 0 else 0.26)
            for beat in (1.0, 3.0):
                mix.put('drums', splat(), t0 + beat * spb + hum.uniform(-0.004, 0.004), 0.13)
        elif b == len(form) - 1:
            for beat in (2.0, 2.5, 3.0, 3.5):
                mix.put('drums', plop(), t0 + beat * spb, 0.12 + 0.05 * beat)
    return mix, dict(room=0.87, damp=0.5, wet=0.95), bpm


# The Snuffer's chant (B) and the title motif bent Phrygian (C).
SNUFFER_CHANT = [
    [(0, 2, 62), (2, 1, 63), (3, 1, 62)],     # Gm   D4 Eb4 D4
    [(0, 2, 67), (2, 1, 65), (3, 1, 63)],     # Eb   G4 F4 Eb4
    [(0, 4, 62)],                             # Gm
    [(0, 2, 61), (2, 1, 62), (3, 1, 64)],     # A    C#4 D4 E4
    [(0, 2, 65), (2, 1, 63), (3, 1, 62)],     # Bb   F4 Eb4 D4
    [(0, 2, 63), (2, 2, 67)],                 # Eb
    [(0, 2, 70), (2, 1, 69), (3, 1, 67)],     # Gm   Bb4 A4 G4
    [(0, 4, 69)],                             # A
]
SNUFFER_MOTIF = [
    [(0, 1.5, 74), (1.5, .5, 69), (2, 1, 74), (3, 1, 77)],     # Dm   D5 . A4 D5 F5
    [(0, 2, 75), (2, 2, 74)],                                  # Dm   Eb5 sighing to D5
    [(0, 1.5, 79), (1.5, .5, 75), (2, 1, 79), (3, 1, 82)],     # Eb
    [(0, 2, 82), (2, 1, 80), (3, 1, 79)],                      # Eb   Bb5 Ab5 G5
    [(0, 1.5, 74), (1.5, .5, 69), (2, 1, 74), (3, 1, 77)],     # Dm
    [(0, 2, 81), (2, 2, 80)],                                  # Dm   A5 bent to Ab5
    [(0, 2, 77), (2, 2, 74)],                                  # Bb
    [(0, 4, 73)],                                              # A
]


def snuffer():
    bpm = 132.0
    spb = 60.0 / bpm
    form = ['Dm', 'Dm', 'Eb', 'Eb', 'Dm', 'Dm', 'Bb', 'A',
            'Gm', 'Eb', 'Gm', 'A', 'Bb', 'Eb', 'Gm', 'A',
            'Dm', 'Dm', 'Eb', 'Eb', 'Dm', 'Dm', 'Bb', 'A']
    bar = 4 * spb
    mix = Mix(len(form) * bar, tail=6.0)
    for name, send in (('organ', 0.3), ('choir', 0.6), ('bells', 0.8), ('drums', 0.12), ('lead', 0.3)):
        mix.stem(name, send)
    pedal = {'Dm': 62, 'Eb': 62, 'Bb': 58, 'A': 57, 'Gm': 55}
    low = {'Dm': (50, 53, 57, 62), 'Eb': (51, 55, 58, 63), 'Bb': (46, 53, 58, 62), 'A': (45, 52, 57, 61),
           'Gm': (43, 50, 55, 58)}
    grind = (0, 0, 12, 0, 1, 0, 7, 0)
    accent = (1.0, 0.6, 0.8, 0.6, 0.9, 0.6, 0.8, 0.65)
    hum = random.Random(13)
    for b, chord in enumerate(form):
        t0 = b * bar
        section = b // 8                     # 0 A, 1 B (the chant), 2 C (everything)
        k = b % 8
        # The sour organ grinding eighths on the pedal.
        for j in range(8):
            m = pedal[chord] + grind[j]
            mix.put('organ', sour_organ(m, 0.17, 0.004, 0.05), t0 + j * spb / 2, 0.18 * accent[j])
        # The low choir holding the chord: "oo" first, "ah" once it's all in,
        # with a thinner "ah" an octave over it (the low voices alone are
        # mostly lost on a phone); in C the lead carries the top instead.
        vowel = 'oo' if section == 0 else 'ah'
        for m in low[chord]:
            mix.put('choir', choir(m, bar + 0.2, 0.3, 0.5, vowel), t0, 0.1 if section == 0 else 0.085)
            mix.put('choir', choir(m + 12, bar + 0.2, 0.3, 0.5, 'ah'), t0, 0.06 if section < 2 else 0.035)
        if section == 1:
            for beat, dur, m in SNUFFER_CHANT[k]:
                mix.put('choir', choir(m, dur * spb, 0.06, 0.25, 'ah'), t0 + beat * spb, 0.2)
                mix.put('choir', choir(m - 12, dur * spb, 0.06, 0.25, 'oo'), t0 + beat * spb, 0.13)
        if section == 2:
            for beat, dur, m in SNUFFER_MOTIF[k]:
                mix.put('lead', lead(m, dur * spb - 0.03), t0 + beat * spb, 0.17)
                mix.put('lead', lead(m - 12, dur * spb - 0.03), t0 + beat * spb, 0.08)
        # Bells swelling backwards into every fourth downbeat, and struck
        # there: a great bell on D3 and a smaller one an octave up with it,
        # which is the one a phone speaker carries.
        if k % 4 == 3:
            mix.put('bells', rev_bell(50, 2 * bar), t0 + bar - 2 * bar, 0.42)
            mix.put('bells', rev_bell(62, 2 * bar), t0 + bar - 2 * bar, 0.36)
        if k % 4 == 0:
            mix.put('bells', bell(50, 3.0), t0, 0.32 if section else 0.26)
            mix.put('bells', bell(62, 3.0), t0, 0.3 if section else 0.24)
        # Drums: timpani and kick driving, war drums once it builds, a swell
        # of breath into each new section. All of them struck hard, with wood
        # and beaters, so the drive is in their crack and not only in a boom
        # a phone would drop; the timpani are tuned D3 and A3 for the same
        # reason (an A2 is felt, not heard, on a small speaker).
        drum = timpani(57 if chord == 'A' else 50, 1.0)
        mix.put('drums', drum, t0, 0.44)
        kicks = (0.0, 1.5, 2.0) if section == 0 else (0.0, 1.5, 2.0, 3.5)
        for beat in kicks:
            mix.put('drums', war_kick(), t0 + beat * spb, 0.42)
        if section >= 1 or k >= 4:
            for beat in (1.0, 3.0):
                mix.put('drums', tom(0.8), t0 + beat * spb + hum.uniform(-0.003, 0.003), 0.38)
        if section >= 1:
            for j in range(8):
                mix.put('drums', shaker(j % 2), t0 + j * spb / 2 + hum.uniform(-0.003, 0.003), 0.05 if j % 2 else 0.035)
        if section == 2 and k in (3, 7):
            for j in range(8):
                mix.put('drums', tom(0.8), t0 + (2.0 + j / 4) * spb, 0.16 + 0.26 * j / 8)
        if k == 7:
            mix.put('drums', swell(bar, 40 + b), t0, 0.35)
    return mix, dict(room=0.84, damp=0.35, wet=0.95), bpm


TRACKS = {'title': title, 'chapel': chapel, 'boss': boss, 'story': story, 'hush': hush, 'dawn': dawn,
          'tallow': tallow, 'snuffer': snuffer}
V2 = tuple(TRACKS)

# ---------------------------------------------------------------- v3: the merge
#
# v3's tracks live in their own modules (so the world and boss music could be
# written side by side): tracks_worlds.py and tracks_bosses.py, built on
# instruments_v3.py. Each does `from music import ...` and exports TRACKS
# ({id: maker}, a maker returning (mix, fx, bpm) like the ones above) and
# may export STEM_SETS ({set: maker}, a maker returning (mix, fx, bpm, stems,
# premix): `stems` maps each stem file to the mix's parts it holds, `premix`
# maps each pre-mixed stand-in to the stems it sums). Sfx.STEMS and
# Sfx.PREMIX name the same files. merge() brings them in.

STEM_SETS = {}
MODULES = ('tracks_worlds', 'tracks_bosses')
_merged = []


def merge():
    """Add the v3 modules' TRACKS and STEM_SETS to this module's (once).
    main() does it; so must anything else that wants every track."""
    if _merged:
        return
    _merged.append(True)
    import importlib
    # Run as a script this module is __main__; the track modules import it as
    # `music`, and must get this one (its caches, its TRACKS), not a copy.
    sys.modules.setdefault('music', sys.modules[__name__])
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    for name in MODULES:
        mod = importlib.import_module(name)
        for k, fn in getattr(mod, 'TRACKS', {}).items():
            if k in TRACKS or k in STEM_SETS:
                sys.exit('music: %s defines %r twice' % (name, k))
            TRACKS[k] = fn
        for k, fn in getattr(mod, 'STEM_SETS', {}).items():
            if k in TRACKS or k in STEM_SETS:
                sys.exit('music: %s defines %r twice' % (name, k))
            STEM_SETS[k] = fn


def master_stems(mix, stems, room, damp, wet, target=TARGET_LUFS, premix=None):
    """master() for a stem set: each stem is its parts folded, with its own
    share of the hall, the sub-sonic high-pass and DC taken out (all linear,
    so the stems add up to exactly the mastered whole), then one gain for
    every stem that brings their sum to `target` LUFS, held down if need be
    so neither the sum nor any premix (`premix`: {name: the stems it sums})
    passes KNEE + 0.25, well under the ceiling. No soft clip (it isn't
    linear), so a premix is exactly its stems added up.
    Returns ({stem: loop}, the gain in dB, each stem's level vs the whole)."""
    n = mix.n
    outs = {}
    for stem, parts in stems.items():
        dry = zeros(n)
        send = zeros(n)
        sent = False
        for name in parts:
            loop = mix.fold(name)
            dry = array.array('d', map(add, dry, loop))
            if mix.sends[name]:
                send = array.array('d', map(add, send, map(mul, loop, repeat(mix.sends[name]))))
                sent = True
        out = array.array('d', map(add, dry, scaled(reverb(send, room, damp), wet))) if sent else dry
        out = highpass_loop(out, 28.0)
        mean = sum(out) / n
        outs[stem] = array.array('d', (v - mean for v in out))
    whole = zeros(n)
    for out in outs.values():
        whole = array.array('d', map(add, whole, out))
    gain = 10 ** ((target - lufs(whole)) / 20)
    top = max(map(abs, whole))
    for held in (premix or {}).values():
        acc = zeros(n)
        for stem in held:
            acc = array.array('d', map(add, acc, outs[stem]))
        top = max(top, max(map(abs, acc)))
    top *= gain
    if top > KNEE + 0.25:
        gain *= (KNEE + 0.25) / top
    levels = {}
    ref = rms_db(whole)
    for stem in outs:
        levels[stem] = active_db(outs[stem]) - ref
        outs[stem] = scaled(outs[stem], gain)
    return outs, 20 * math.log10(gain), levels


def render_stems(name):
    t = time.time()
    mix, fx, bpm, stems, premix = STEM_SETS[name]()
    outs, gain, levels = master_stems(mix, stems, fx['room'], fx['damp'], fx['wet'], fx.get('target', TARGET_LUFS),
                                      premix)
    whole = zeros(mix.n)
    for stem, loop in outs.items():
        write_wav(os.path.join(OUT_DIR, stem + '.wav'), loop)
        whole = array.array('d', map(add, whole, loop))
        print('%-18s %5.1f s  %5.1f LUFS alone  peak %5.1f dBFS  (%+.1f dB vs the whole, while it plays)' % (
            stem, len(loop) / RATE, lufs(loop), 20 * math.log10(max(map(abs, loop)) or 1e-9), levels[stem]))
    for mixed, held in premix.items():
        acc = zeros(mix.n)
        for stem in held:
            acc = array.array('d', map(add, acc, outs[stem]))
        write_wav(os.path.join(OUT_DIR, mixed + '.wav'), acc)
        print('%-18s %5.1f s  %5.1f LUFS  peak %5.1f dBFS  (%s)' % (
            mixed, len(acc) / RATE, lufs(acc), 20 * math.log10(max(map(abs, acc)) or 1e-9), ' + '.join(held)))
    print('%-18s %5.1f s  %3d BPM  %5.1f LUFS all together  peak %5.1f dBFS  gain %+.1f dB  (%.1f s)' % (
        name, len(whole) / RATE, bpm, lufs(whole), 20 * math.log10(max(map(abs, whole))), gain, time.time() - t))


def render(name):
    if name in STEM_SETS:
        render_stems(name)
        return
    t = time.time()
    mix, fx, bpm = TRACKS[name]()
    loop, levels = master(mix, fx['room'], fx['damp'], fx['wet'], fx.get('target', TARGET_LUFS))
    path = os.path.join(OUT_DIR, name + '.wav')
    write_wav(path, loop)
    peak = max(map(abs, loop))
    print('%-7s %5.1f s  %3d BPM  %5.1f LUFS  peak %5.1f dBFS  %4.2f MB  (%.1f s)' % (
        name, len(loop) / RATE, bpm, lufs(loop), 20 * math.log10(peak), os.path.getsize(path) / 1e6,
        time.time() - t))
    print('        parts while playing, vs the whole dry mix (dB): ' + ', '.join('%s %+.1f' % kv for kv in levels.items()))


def main(argv):
    merge()
    os.makedirs(OUT_DIR, exist_ok=True)
    names = argv or list(TRACKS) + list(STEM_SETS)
    if names == ['v2']:
        names = list(V2)
    elif names == ['v3']:
        names = [k for k in TRACKS if k not in V2] + list(STEM_SETS)
    for name in names:
        if name not in TRACKS and name not in STEM_SETS:
            sys.exit('unknown track %r (have: %s)' % (name, ', '.join(list(TRACKS) + list(STEM_SETS))))
        _notes.clear()
        render(name)



if __name__ == '__main__':
    main(sys.argv[1:])
