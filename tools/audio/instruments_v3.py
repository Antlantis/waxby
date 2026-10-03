"""WAXBY v3's new instruments and score helpers, for tools/audio/music.py.

Everything here is built from music.py's primitives (partial, wavetable,
osc, the filters, noise, cached) and renders the same bytes every run.

  bone_marimba(midi)        a hollow, woody knock: partials 1 : 3.93 : 9.2 (W3)
  hurdy(midi, dur)          a hurdy-gurdy's melody string, nasal; its chien buzzing, for a growl (W3)
  hurdy_drone(...)          the hurdy's drone strings for a whole loop, the chien buzzing on the beats (W3)
  slit_drum(midi)           a tuned log drum (Gravebough)
  woodblock(variant)        a dry knock, high and low (W3)
  bone_chime(midi)          a small hanging bone tube, glassy and short (W3)
  glass_harmonica(midi, d)  two sines beating a hair apart, and the octave (W4, W5)
  clock_tick(ping)          a 6 ms noise burst and a ping: tick 3520 Hz, tock 2350 Hz (W4)
  ratchet(clicks, secs)     a spring wound: clicks drawing closer over a stretching sweep (W4)
  plain_hunt(n)             the rows of plain hunt on n bells, rounds to rounds (W4, the Hush)
  lake_lap(variant)         low water lapping under a 0.6 s swell (W6)
  wind_loop(secs, ...)      wind through tracery: noise in a band swept 300-1200 Hz, a whole loop (W5)
  reedy_drone(...)          a drone whose weight sits where a phone can play it (W6, the Hush)
  eaten(sig, seed)          a note whose tail is gated off at 40-70 %: the Hush eating it (W6)
  scale_step(midi, k, mode) the note k degrees along a D mode from midi (a passing note)
  presence(mix, part, f, g) a written part's attacks lifted above f, where a phone plays them

    from instruments_v3 import *
"""

import array
import math
import random
import re
import os
from itertools import repeat
from operator import add, mul

from music import (RATE, HERE, Mix, zeros, add_into, scaled, shape, normalize, ramp_env, partial, wavetable, osc,
                   bandpass, highpass, lowpass, noise, cached, hz, bell, drone, noise_loop)

# The pitch classes of the modes (0 = D). Every v3 cue's mode holds D F G A C
# (spec 12), but for the two major ones, which hold D F# A (as dawn does).
D = 2   # the pitch class of D
MODES = {
    'dorian': (0, 2, 3, 5, 7, 9, 10),
    'aeolian': (0, 2, 3, 5, 7, 8, 10),
    'phrygian': (0, 1, 3, 5, 7, 8, 10),
    'major': (0, 2, 4, 5, 7, 9, 11),
    'pentatonic': (0, 3, 5, 7, 10),
}


def in_mode(midi, mode):
    """Is this note one of the mode's (a mode on D)?"""
    return (midi - D) % 12 in MODES[mode]


def scale_step(midi, steps, mode):
    """The note `steps` degrees of a D mode above (or, negative, below) midi:
    a step along the scale, never a fixed number of semitones."""
    d = 1 if steps > 0 else -1
    m = midi
    for _ in range(abs(steps)):
        m += d
        while not in_mode(m, mode):
            m += d
    return m


GAME_SCRIPTS = os.path.normpath(os.path.join(HERE, '..', '..', 'game', 'scripts'))


def level_tick():
    """The W4 beat, read from game/scripts/level_data.gd (its TICK: the period a
    level with no tick: header keeps), so the carillon plays on it."""
    path = os.path.join(GAME_SCRIPTS, 'level_data.gd')
    try:
        with open(path) as f:
            m = re.search(r'^const TICK\s*:?=\s*([0-9.]+)', f.read(), re.M)
        if m:
            return float(m.group(1))
    except OSError:
        pass
    print('instruments_v3: no TICK in %s; using 0.536' % path)
    return 0.536


def knob_ticks():
    """World 4's own tick knob (features/clockwork.gd's DIFF_KNOBS["tick"], per
    difficulty), or {} while it has none: check_music.py holds it to TICK."""
    path = os.path.join(GAME_SCRIPTS, 'features', 'clockwork.gd')
    try:
        with open(path) as f:
            m = re.search(r'"tick"\s*:\s*\{([^}]*)\}', f.read())
    except OSError:
        return {}
    if not m:
        return {}
    return {k: float(v) for k, v in re.findall(r'"(\w+)"\s*:\s*([0-9.]+)', m.group(1))}


# ---------------------------------------------------------------- score helpers

class Loop(Mix):
    """A Mix whose every part is put `shift` seconds late: the loop's seam then
    never falls on a note's first sample (an attack there reads as a click to
    check_music.py, though it is only the music starting). Only for a cue
    with no clock to keep (not the carillon)."""

    def __init__(self, seconds, tail=5.0, shift=0.02):
        Mix.__init__(self, seconds, tail)
        self.shift = shift

    def put(self, name, sig, t, gain=1.0):
        Mix.put(self, name, sig, t + self.shift, gain)


def line(mix, stem, notes, t0, unit, voice, gain, rng=None, jitter=0.0, accent=None, shift=0):
    """Put a melody on a stem: notes are (start, length, midi) in `unit` seconds
    from t0; voice(midi, seconds) makes each; accent(start) scales its gain."""
    for start, length, m in notes:
        t = t0 + start * unit + (rng.uniform(-jitter, jitter) if rng and jitter else 0.0)
        g = gain * (accent(start) if accent else 1.0)
        mix.put(stem, voice(m + shift, length * unit), t, g)


def faders(mix, levels):
    """Scale whole parts of a mix after they're written: {part: gain}."""
    for name, g in levels.items():
        mix.stems[name] = scaled(mix.stems[name], g)


def presence(mix, name, f0, gain):
    """Lift a written part's attacks where a phone plays: the part plus `gain`
    times itself through two high-passes at f0 (a drum's slap and knock, not
    its boom). Linear and done before the part is folded, so it wraps round
    the loop's seam as the part does."""
    x = mix.stems[name]
    hp = highpass(highpass(x, f0), f0)
    mix.stems[name] = array.array('d', map(add, x, map(mul, hp, repeat(gain))))


# ---------------------------------------------------------------- instruments

@cached
def bone_marimba(midi, hard=0.5):
    """A bone marimba: a bar of old bone over a gourd. Partials at 1 : 3.93 :
    9.2 (a bar's modes, bent by the bone's grain), amps 1 / 0.35 / 0.12, the
    upper two dying first; a hollow knock at 2f (the gourd's resonance, gone
    in 30 ms) and a mallet's click. Low bars ring longer. `hard` (0..1) is the
    mallet: harder brings the upper partials and the click up, for a phone."""
    f = hz(midi)
    ring = min(1.6, max(0.6, (330.0 / f) ** 0.45))
    n = int((0.45 * ring + 0.1) * RATE)
    acc = zeros(n)
    for ratio, a, d in ((1.0, 1.0, 0.35), (3.93, 0.35 * (0.6 + 0.8 * hard), 0.12), (9.2, 0.12 * (0.5 + hard), 0.05),
                        (2.0, 0.16, 0.03)):
        if f * ratio < 9500.0:
            acc = array.array('d', map(add, acc, partial(n, f * ratio, a, d * ring, (ratio * 0.31) % 1.0)))
    click = highpass(noise(int(0.004 * RATE), 3100 + midi), 3000.0)
    add_into(acc, shape(click, 0.0003, 0.002), 0, 0.2 + 0.2 * hard)
    return normalize(shape(acc, 0.002, 0.05))


@cached
def bone_chime(midi):
    """A small bone tube hanging in the branches, knocked by the wind: a free
    bar's inharmonic modes (1, 2.76, 5.40), glassy and short, a little flat
    and uncanny."""
    f = hz(midi) * 0.994
    n = int(1.4 * RATE)
    acc = zeros(n)
    for ratio, a, d in ((1.0, 1.0, 0.5), (2.76, 0.45, 0.22), (5.40, 0.2, 0.1), (8.93, 0.06, 0.05)):
        if f * ratio < 9500.0:
            acc = array.array('d', map(add, acc, partial(n, f * ratio, a, d, ratio * 0.17 % 1.0)))
    return normalize(shape(acc, 0.001, 0.25))


SAW = [1.0 / k for k in range(1, 19)]


@cached
def hurdy(midi, dur, buzz_from=-1.0, bright=1.0):
    """A hurdy-gurdy's melody string: a bowed saw (18 partials) rolled off at
    3 kHz (times `bright`), with the box's nasal bump near 1.1 kHz and the
    wheel's slight wobble; from `buzz_from` seconds (if >= 0) the chien
    buzzes at 11 Hz (depth 0.25), for a growl. Its drone strings are
    hurdy_drone's, held on D and A under the whole loop. (Cached: pass
    every argument by position.)"""
    f = hz(midi)
    top = 3000.0 * bright
    amps = [a / math.sqrt(1.0 + (k * f / top) ** 4) * (1.0 + 0.9 * math.exp(-((k * f - 1100.0) / 450.0) ** 2))
            for k, a in enumerate(SAW, 1)]
    n = int((dur + 0.12) * RATE)
    sig = array.array('d', osc(wavetable(amps, f), f, n, vib=0.0025, vib_hz=5.3, vib_delay=0.15))
    if buzz_from >= 0.0:
        b0 = int(buzz_from * RATE)
        w = 2 * math.pi * 11.0 / RATE
        for i in range(b0, n):
            s = math.sin(w * (i - b0))
            sig[i] *= 1.0 - 0.25 * (s * s)
    rasp = bandpass(noise(n, 700 + midi), 2200.0, 1.5)
    add_into(sig, rasp, 0, 0.05)
    return array.array('d', map(mul, sig, ramp_env(n, 0.035, 0.12)))


def hurdy_drone(loop_secs, midis, gain, buzz=(), buzz_len=0.2, depth=0.35, seed=0):
    """The hurdy's drone strings for the whole loop (each pitch nudged to a
    whole number of cycles, so it meets itself at the seam), the chien
    rattling at 11 Hz for `buzz_len` s from each time in `buzz` (the player's
    wrist on the beats), the wheel's rasp under it all."""
    n = int(round(loop_secs * RATE))
    acc = zeros(n)
    for j, m in enumerate(midis):
        cycles = round(hz(m) * loop_secs)
        f = cycles / loop_secs
        amps = [a / math.sqrt(1.0 + (k * f / 2600.0) ** 4) * (1.0 + 0.9 * math.exp(-((k * f - 1100.0) / 450.0) ** 2))
                for k, a in enumerate(SAW, 1)]
        acc = array.array('d', map(add, acc, map(mul, osc(wavetable(amps, f), f, n, phase=0.27 * j),
                                                  repeat(1.0 / (1 + 0.4 * j)))))
    env = [1.0] * n
    w = 2 * math.pi * 11.0 / RATE
    blen = int(buzz_len * RATE)
    for t in buzz:
        s0 = int(round(t * RATE)) % n
        for i in range(blen):
            k = (s0 + i) % n
            fall = 1.0 - i / blen
            s = math.sin(w * i)
            env[k] *= 1.0 - depth * fall * (s * s)
    acc = array.array('d', map(mul, acc, env))
    rasp = noise_loop(loop_secs, 900 + seed, 2000.0, 1.2)
    acc = array.array('d', map(add, acc, map(mul, rasp, repeat(0.12))))
    return scaled(acc, gain)


@cached
def slit_drum(midi, hard=0.6):
    """A log drum: a hollowed log's two tongues, knocked. A woody body at the
    note sagging a few percent as it rings, its second mode at 2.6x, and the
    beater's knock of mid noise, so a phone hears the pitch."""
    f = hz(midi)
    n = int(0.45 * RATE)
    out = zeros(n)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        phase += 2 * math.pi * f * (1.0 + 0.04 * math.exp(-t / 0.02)) / RATE
        out[i] = math.sin(phase) * math.exp(-t / 0.12)
    out = array.array('d', map(add, out, partial(n, 2.6 * f, 0.35 * (0.5 + hard), 0.05, 0.2)))
    knock = bandpass(noise(int(0.02 * RATE), 800 + midi), 1400.0, 1.0)
    add_into(out, array.array('d', map(mul, knock, (math.exp(-i / (0.004 * RATE)) for i in range(len(knock))))),
             0, 0.6 + 0.8 * hard)
    return normalize(shape(out, 0.001, 0.04))


@cached
def woodblock(variant=0):
    """A dry woodblock: high (0) or low (1). A short resonance with a hint of
    its second mode, and the stick's click."""
    f = (1250.0, 820.0)[variant % 2]
    n = int(0.12 * RATE)
    out = array.array('d', partial(n, f, 1.0, 0.025))
    out = array.array('d', map(add, out, partial(n, f * 2.37, 0.3, 0.012, 0.4)))
    click = highpass(noise(int(0.002 * RATE), 1300 + variant), 3000.0)
    add_into(out, click, 0, 0.3)
    return normalize(shape(out, 0.0005, 0.02))


@cached
def glass_harmonica(midi, dur, attack=0.15, release=0.4):
    """A glass harmonica: a wet rim sung by a finger. Two sines a hair apart
    (f and f x 1.0015) beating slowly, the octave at 0.25 and a breath of the
    twelfth; a slow 4.5 Hz vibrato of 3 cents; it swells in over `attack` s
    and rings off over `release`."""
    f = hz(midi)
    n = int((dur + release) * RATE)
    a = osc(wavetable([1.0, 0.25, 0.05], f), f, n, vib=0.0017, vib_hz=4.5, vib_delay=0.05)
    b = osc(wavetable([1.0], f * 1.0015), f * 1.0015, n, phase=0.41, vib=0.0017, vib_hz=4.5, vib_delay=0.05,
            vib_phase=0.2)
    sig = array.array('d', map(add, a, map(mul, b, repeat(0.8))))
    return array.array('d', map(mul, sig, ramp_env(n, attack, release)))


@cached
def clock_tick(ping=3520.0, seed=0):
    """A clock's escapement: a 6 ms burst of noise high-passed at 3 kHz and a
    30 ms ping (3520 Hz for the tick, 2350 for the tock)."""
    n = int(0.05 * RATE)
    out = zeros(n)
    burst = highpass(noise(int(0.006 * RATE), 1700 + seed), 3000.0)
    add_into(out, array.array('d', map(mul, burst, (math.exp(-i / (0.0015 * RATE)) for i in range(len(burst))))),
             0, 1.0)
    if ping:
        add_into(out, array.array('d', partial(int(0.03 * RATE), ping, 0.6, 0.008)), 0)
    return normalize(shape(out, 0.0003, 0.008))


@cached
def ratchet(clicks, secs, seed=0):
    """A spring being wound: `clicks` pawl clicks over `secs`, each gap 0.85 of
    the last, over a stretching hum sweeping 300 -> 500 Hz."""
    n = int((secs + 0.08) * RATE)
    out = zeros(n)
    gaps = [0.85 ** k for k in range(clicks)]
    scale = secs / sum(gaps)
    t = 0.0
    for k in range(clicks):
        add_into(out, clock_tick(0.0, seed + k), int(t * RATE), 0.6 + 0.4 * k / max(1, clicks - 1))
        t += gaps[k] * scale
    phase = 0.0
    m = int(secs * RATE)
    for i in range(m):
        x = i / m
        phase += 2 * math.pi * (300.0 + 200.0 * x) / RATE
        out[i] += 0.12 * math.sin(phase) * math.sin(math.pi * x) * (0.6 + 0.4 * math.sin(3 * phase))
    return normalize(shape(out, 0.002, 0.04))


def plain_hunt(n=6):
    """Plain hunt on n bells (n even): rounds, then swapping the pairs from the
    front and from the second place in turn, until rounds come round again
    (2n changes). Returns the 2n + 1 rows, each the bells in striking order."""
    row = list(range(n))
    rows = [row[:]]
    for k in range(2 * n):
        for i in range(k % 2, n - 1, 2):
            row[i], row[i + 1] = row[i + 1], row[i]
        rows.append(row[:])
    return rows


def ring_rows(mix, stem, rows, t0, gap, bells, gain, length=1.2, rng=None, jitter=0.0, strike=None):
    """Strike rows of change ringing, one bell every `gap` seconds from t0.
    `bells` are the bells' strike notes, treble first; strike(bell, place)
    scales each strike (a heavier bell struck harder, say)."""
    for r, row in enumerate(rows):
        for j, b in enumerate(row):
            t = t0 + (r * len(row) + j) * gap + (rng.uniform(-jitter, jitter) if rng and jitter else 0.0)
            g = gain * (strike(b, j) if strike else 1.0)
            mix.put(stem, bell(bells[b] - 12, length), t, g)


@cached
def lake_lap(variant=0):
    """Black water lapping at a jetty: noise low-passed at 500 Hz under a 0.6 s
    swell, with a small wet tick where the wave meets the wood."""
    n = int(0.9 * RATE)
    x = lowpass(lowpass(noise(n, 2100 + variant), 500.0), 700.0)
    env = [math.sin(math.pi * min(1.0, i / (0.6 * RATE))) ** 2 if i < 0.6 * RATE else 0.0 for i in range(n)]
    out = array.array('d', map(mul, x, env))
    tick = bandpass(noise(int(0.01 * RATE), 2200 + variant), 1600.0, 2.0)
    add_into(out, shape(tick, 0.001, 0.006), int(0.42 * RATE), 0.08)
    return normalize(shape(out, 0.01, 0.05))


def wind_loop(loop_secs, seed, lo=300.0, hi=1200.0, cycles=5, q=1.2, gusts=((3, 0.35, 0.7), (7, 0.15, 0.0))):
    """Wind through broken tracery for a whole loop: noise through a band-pass
    (Q `q`) whose centre sweeps lo..hi and back `cycles` times a loop (about
    0.07 Hz for a minute's loop), its level gusting on whole cycles too, run
    round the loop (warmed on its own tail) so it meets itself at the seam."""
    n = int(round(loop_secs * RATE))
    x = noise(n, seed)
    warm = int(1.0 * RATE)
    src = x[n - warm:] + x
    out = zeros(n)
    x1 = x2 = y1 = y2 = 0.0
    b0 = a1 = a2 = 0.0
    step = 32
    ln_lo, ln_hi = math.log(lo), math.log(hi)
    for i, v in enumerate(src):
        j = i - warm
        if i % step == 0:
            ph = (j % n) / n
            c = math.exp(ln_lo + (ln_hi - ln_lo) * (0.5 - 0.5 * math.cos(2 * math.pi * cycles * ph)))
            w = 2 * math.pi * c / RATE
            alpha = math.sin(w) / (2 * q)
            a0 = 1 + alpha
            b0, a1, a2 = alpha / a0, -2 * math.cos(w) / a0, (1 - alpha) / a0
        o = b0 * v - b0 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        if j >= 0:
            out[j] = o
    level = [1.0] * n
    for k, depth, ph in gusts:
        w = 2 * math.pi * k / n
        level = [lv * (1.0 + depth * math.sin(w * i + ph)) for i, lv in enumerate(level)]
    return normalize(array.array('d', map(mul, out, level)))


def reedy_drone(midi, loop_secs, gain, lfo=(), detune=0, lift=1.0, top=2600.0):
    """A drone that a phone can hear even on D1: a reed's ladder of
    harmonics rising to the one nearest 420 Hz (times `lift`) and falling
    away above it, so its weight lands between ~250 Hz and 1 kHz whatever
    the note, cut at `top`; whole cycles per loop (see music.drone)."""
    f0 = hz(midi)
    peak = max(1, int(round(420.0 * lift / f0)))      # the harmonic near 420 Hz leads
    kmax = max(8, int(top / f0))
    amps = []
    for k in range(1, kmax + 1):
        x = k / peak
        a = x * math.exp(1.0 - x) if x > 0 else 0.0   # rises to 1 at the peak, then falls away
        amps.append(a * (1.0 if k > 1 else 0.3))
    return drone(midi, loop_secs, amps, gain, lfo, detune)


def eaten(sig, seed, lo=0.4, hi=0.7):
    """A note the Hush eats: its tail gated to nothing at a point 40-70 % of
    the way through (chosen by `seed`), with a 10 ms fade."""
    r = random.Random(seed)
    n = len(sig)
    cut = int(n * r.uniform(lo, hi))
    fade = max(1, int(0.01 * RATE))
    out = array.array('d', sig)
    for i in range(cut, n):
        k = i - cut
        out[i] = sig[i] * (0.5 + 0.5 * math.cos(math.pi * k / fade)) if k < fade else 0.0
    return out


def breath_loop(loop_secs, seed, f0=900.0, q=0.9, cycles=((2, 0.6, 0.0), (5, 0.3, 1.1))):
    """A slow breath of air a whole loop long (band-passed noise round the
    loop), rising and falling on whole cycles."""
    n = int(round(loop_secs * RATE))
    air = noise_loop(loop_secs, seed, f0, q)
    level = [1.0] * n
    for k, depth, ph in cycles:
        w = 2 * math.pi * k / n
        level = [lv * max(0.0, 1.0 + depth * math.sin(w * i + ph)) for i, lv in enumerate(level)]
    return normalize(array.array('d', map(mul, air, level)))


def loop_env(loop_secs, points):
    """A level for the whole loop, from (seconds, level) points joined by
    raised-cosine glides, wrapping from the last point back to the first."""
    n = int(round(loop_secs * RATE))
    pts = sorted(points)
    out = [0.0] * n
    for idx, (t, v) in enumerate(pts):
        t2, v2 = pts[(idx + 1) % len(pts)]
        if idx + 1 == len(pts):
            t2 += loop_secs
        a, b = int(round(t * RATE)), int(round(t2 * RATE))
        span = max(1, b - a)
        for i in range(a, b):
            x = (i - a) / span
            out[i % n] = v + (v2 - v) * (0.5 - 0.5 * math.cos(math.pi * x))
    return out
