#!/usr/bin/env python3
"""Checks the music WAVs in game/audio/ without Godot: format, the loop
chunk and its padding, length, size, peak, loudness, DC, that the loop
seam is no rougher than the music around it, and that each cue holds its
loudness through a phone speaker (which plays almost nothing under 300 Hz)
and sits level with the others there. Prints PASS/FAIL per check and exits
1 on any failure.

v3 adds (spec 12.2): the twelve new tracks and the four beds; the stem sets
(hush_final, descent), each stem checked alone for its seam and clicks and
all of a set together for loudness, each stage of a set as the game mixes it
(the Descent's depths level with the other cues; the Hush's bells heard
coming back), the pre-mixed stand-ins checked sample for sample against the
sum of the stems they hold; the carillon locked to the W4 tick (its loop 128
ticks of level_data.gd's TICK, the clock's pings on the beats, and every
level that plays it on that tick); every note every v3 maker puts in its mix
in its track's mode (each maker run with its voices stubbed out, so what is
checked is what is played, not a table beside it); and every file music.py
writes a name Sfx plays (sfx.gd's TRACKS, STEMS and PREMIX).

    python3 tools/audio/check_music.py [track or stem set ...]    # default: everything
"""

import array
import math
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.dont_write_bytecode = True   # no __pycache__ beside the tools
import music  # noqa: E402
from music import OUT_DIR, PAD, RATE, TARGET_LUFS, highpass, lufs  # noqa: E402
music.merge()

SFX_GD = os.path.normpath(os.path.join(HERE, '..', '..', 'game', 'scripts', 'sfx.gd'))
LEVELS_DIR = os.path.normpath(os.path.join(HERE, '..', '..', 'game', 'levels'))
LEVEL_TOOLS = os.path.normpath(os.path.join(HERE, '..', 'levels'))

# track -> (shortest, longest) loop in seconds, its tempo (for the report; 0:
# no beat) and its loudness target in LUFS. The spans match test_sfx.gd's.
EXPECT = {'title': (24.0, 32.0, 64, TARGET_LUFS), 'chapel': (48.0, 64.0, 120, TARGET_LUFS),
          'boss': (32.0, 48.0, 140, TARGET_LUFS), 'story': (60.0, 68.0, 66, TARGET_LUFS),
          'hush': (30.0, 48.0, 0, -20.0), 'dawn': (48.0, 66.0, 72, TARGET_LUFS),
          'tallow': (52.0, 66.0, 80, TARGET_LUFS), 'snuffer': (36.0, 56.0, 132, TARGET_LUFS),
          # v3, P0
          'orchard': (44.0, 70.0, 104, TARGET_LUFS), 'carillon': (55.0, 86.0, 112, TARGET_LUFS),
          'sanctum': (58.0, 90.0, 90, TARGET_LUFS), 'hushdeep': (64.0, 100.0, 0, -21.0),
          'rootmother': (34.0, 60.0, 138, TARGET_LUFS), 'tinker': (46.0, 72.0, 132, TARGET_LUFS),
          'saint': (34.0, 60.0, 150, TARGET_LUFS), 'lullaby': (16.0, 80.0, 60, TARGET_LUFS),
          'secret': (36.0, 60.0, 96, TARGET_LUFS),
          # P1
          'trial': (20.0, 40.0, 150, TARGET_LUFS), 'evenbell': (80.0, 126.0, 76, TARGET_LUFS),
          # P2: the lament and the ambience beds (12 dB under the music)
          'lament': (38.0, 60.0, 60, -19.0),
          'amb_orchard': (8.0, 20.0, 0, -30.0), 'amb_carillon': (8.0, 20.0, 0, -30.0),
          'amb_sanctum': (8.0, 20.0, 0, -30.0), 'amb_hushdeep': (8.0, 20.0, 0, -30.0)}
# The stem sets: their stems, the pre-mixed stand-ins (each the stems it
# sums), the loop span (test_sfx.gd's STEM_LOOPS), the tempo and the whole
# mix's loudness target.
STEM_SETS = {
    'hush_final': dict(stems=['hush_final_bells', 'hush_final_choir', 'hush_final_drums', 'hush_final_wick',
                              'hush_final_void'],
                       premix={'hush_final_a': ['hush_final_bells', 'hush_final_choir', 'hush_final_drums',
                                                'hush_final_wick', 'hush_final_void'],
                               'hush_final_d': ['hush_final_bells', 'hush_final_choir', 'hush_final_wick',
                                                'hush_final_void'],
                               'hush_final_b': ['hush_final_void', 'hush_final_wick', 'hush_final_bells'],
                               'hush_final_c': ['hush_final_void', 'hush_final_wick']},
                       span=(60.0, 68.0), bpm=120, target=TARGET_LUFS,
                       # The fight's stages ({stem: dB}; a stem not named is
                       # off): the Hush eats the drums at 65 %, the choir at
                       # 47 %, the bells at 30 %; the finale rings them back.
                       stages=[('P1', {'hush_final_bells': 0.0, 'hush_final_choir': 0.0, 'hush_final_drums': 0.0,
                                       'hush_final_wick': 0.0, 'hush_final_void': 0.0}),
                               ('65%', {'hush_final_bells': 0.0, 'hush_final_choir': 0.0, 'hush_final_wick': 0.0,
                                        'hush_final_void': 0.0}),
                               ('47%', {'hush_final_bells': 0.0, 'hush_final_wick': 0.0, 'hush_final_void': 0.0}),
                               ('P3', {'hush_final_wick': 0.0, 'hush_final_void': 0.0}),
                               ('the finale', {'hush_final_bells': 0.0, 'hush_final_wick': 0.0,
                                               'hush_final_void': 0.0})],
                       # A stage that must be heard to change on a phone: the
                       # bells coming back (P3 -> the finale), by this much.
                       rises=[('P3', 'the finale', 1.5)]),
    'descent': dict(stems=['descent_floor', 'descent_drive', 'descent_deep'], premix={},
                    span=(54.0, 62.0), bpm=100, target=TARGET_LUFS,
                    # The depths as descent.gd is asked to play them (A6's
                    # request to MO): each is held to the cue's loudness
                    # and, on a phone, level with the other cues.
                    stages=[('depths 1-9', {'descent_floor': 2.5}),
                            ('depths 10-24', {'descent_floor': 1.5, 'descent_drive': 0.0}),
                            ('depths 25-39', {'descent_floor': 0.0, 'descent_drive': 0.0, 'descent_deep': 0.0}),
                            ('depth 40 on', {'descent_floor': 0.0, 'descent_drive': -6.0, 'descent_deep': 2.0})],
                    level=True),
}
# Files music.py writes that Sfx is asked to name (in A6's requests) but
# doesn't yet: written, checked, and not counted as strays until it does.
PENDING = {}   # (hush_final_d went into Sfx.PREMIX at the wave-1 merge)
# What must be written now (v2's and the P0 cues); the rest are checked once
# music.py writes them.
REQUIRED = ('title', 'chapel', 'boss', 'story', 'hush', 'dawn', 'tallow', 'snuffer',
            'orchard', 'carillon', 'sanctum', 'hushdeep', 'rootmother', 'tinker', 'saint', 'lullaby', 'secret',
            'hush_final')
MAX_SECONDS = 127.0     # the longest loop Sfx expects (evenbell's span), as a file size
MAX_BYTES = int(MAX_SECONDS * RATE * 2) + 4096
# A phone speaker, roughly: two 300 Hz high-passes (24 dB an octave). Played
# through it, a track may lose at most PHONE_DROP dB of loudness (v1's title
# and boss lose 1.9; the first cut of snuffer lost 3.4 and sounded 3 dB
# thinner than tallow, the level before it), and every track with a beat
# must come out within PHONE_SPREAD dB of the others' median, so no cue
# jumps or sags when the game changes music on a phone. Hush and hushdeep
# are meant to sit low, lament is a little under the rest, and the beds are
# ambience: they're left out of the median. Hush and the beds aren't held to
# the phone drop either (a bed is lake laps and wind); hushdeep is, since on
# a phone World 6 is nothing but that drone.
PHONE_HZ = 300.0
PHONE_DROP = 2.0
PHONE_SPREAD = 1.0
NO_MEDIAN = ('hush', 'hushdeep', 'lament', 'amb_orchard', 'amb_carillon', 'amb_sanctum', 'amb_hushdeep')
NO_PHONE = ('hush', 'amb_orchard', 'amb_carillon', 'amb_sanctum', 'amb_hushdeep')
# Stems that never sound without the rest (the Descent's deep only ever
# joins the floor and the drive, and is a low choir and a drone): their
# energy may sit low; their set's mix and its stages carry them, and are
# held to the phone checks. Every other stem is held to the 40 % rule and to
# PHONE_DROP, the Hush's as much as any: its void and wick are heard alone
# or nearly at the end, and its bells come back into them.
NEVER_ALONE = ('descent_deep',)
# The carillon's loop is this many ticks (32 bars of 4/4), so seek_music
# (world.ftime) puts every beat on the level's tick.
CARILLON_TICKS = 128

failed = 0
_phone = {}


def check(ok, label):
    global failed
    print(('PASS: ' if ok else 'FAIL: ') + label)
    if not ok:
        failed += 1


def chunks(path):
    """The RIFF chunks of a WAV, {id: bytes}."""
    with open(path, 'rb') as f:
        head = f.read(12)
        if head[:4] != b'RIFF' or head[8:12] != b'WAVE':
            return {}
        out = {}
        while True:
            h = f.read(8)
            if len(h) < 8:
                break
            cid, size = h[:4], struct.unpack('<I', h[4:])[0]
            out[cid] = f.read(size)
            if size % 2:
                f.read(1)
        return out


def percentile(values, q):
    s = sorted(values)
    return s[min(len(s) - 1, int(q * len(s)))]


def read_loop(name):
    """The track's loop (without its padding) as floats, or None."""
    path = os.path.join(OUT_DIR, name + '.wav')
    if not os.path.exists(path):
        return None
    c = chunks(path)
    pcm = array.array('h')
    pcm.frombytes(c.get(b'data', b''))
    if sys.byteorder == 'big':
        pcm.byteswap()
    smpl = c.get(b'smpl', b'')
    n = struct.unpack('<9I6I', smpl[:60])[12] if len(smpl) >= 60 else len(pcm) - PAD
    return array.array('d', (v / 32768.0 for v in pcm[:n]))


def phone_lufs(name, x=None):
    """The track's loudness through a phone speaker (see PHONE_HZ), cached."""
    if name not in _phone:
        x = read_loop(name) if x is None else x
        _phone[name] = None if x is None else lufs(highpass(highpass(x, PHONE_HZ), PHONE_HZ))
    return _phone[name]


def set_mix(set_name):
    """A stem set's stems summed, as the game plays them all at 0 dB, or None."""
    loops = [read_loop(s) for s in STEM_SETS[set_name]['stems']]
    if any(x is None for x in loops) or len({len(x) for x in loops}) != 1:
        return None
    out = array.array('d', loops[0])
    for x in loops[1:]:
        out = array.array('d', (a + b for a, b in zip(out, x)))
    return out


def median_phone():
    """The median phone loudness of the cues held level (the tracks with a
    beat, and each stem set as a whole)."""
    vals = [phone_lufs(t) for t in EXPECT if t not in NO_MEDIAN]
    for s in STEM_SETS:
        if ('mix:' + s) not in _phone:
            x = set_mix(s)
            _phone['mix:' + s] = None if x is None else lufs(highpass(highpass(x, PHONE_HZ), PHONE_HZ))
        vals.append(_phone['mix:' + s])
    vals = sorted(v for v in vals if v is not None)
    return vals[len(vals) // 2]


def check_file(name, lo, hi, bpm):
    """Format, loop chunk, padding, length, size, peak, DC, seam and clicks:
    what every WAV must pass, a stem as much as a track. Returns the loop."""
    path = os.path.join(OUT_DIR, name + '.wav')
    c = chunks(path)
    fmt = c.get(b'fmt ', b'')
    tag, channels, rate, _, _, bits = struct.unpack('<HHIIHH', fmt[:16]) if len(fmt) >= 16 else (0,) * 6
    check(tag == 1 and channels == 1 and rate == RATE and bits == 16, '%s is 16-bit mono PCM at %d Hz' % (name, RATE))
    pcm = array.array('h')
    pcm.frombytes(c.get(b'data', b''))
    if sys.byteorder == 'big':
        pcm.byteswap()
    frames = len(pcm)
    smpl = c.get(b'smpl', b'')
    loop = struct.unpack('<9I6I', smpl[:60]) if len(smpl) >= 60 else None
    n = loop[12] if loop else frames - PAD
    check(loop is not None and loop[7] == 1 and loop[10] == 0 and loop[11] == 0 and n == frames - PAD,
          '%s has a smpl chunk: one forward loop over [0, %d) of %d frames' % (name, n, frames))
    check(list(pcm[n:]) == list(pcm[:PAD]), '%s: the %d frames after the loop repeat its head' % (name, PAD))
    secs = n / RATE
    check(lo <= secs <= hi, '%s loops every %.2f s (%s; wanted %g-%g s)' % (name, secs, '%d BPM' % bpm if bpm else 'no beat', lo, hi))
    size = os.path.getsize(path)
    check(size < MAX_BYTES, '%s is %.2f MB (at most %.2f)' % (name, size / 1e6, MAX_BYTES / 1e6))

    x = array.array('d', (v / 32768.0 for v in pcm[:n]))
    peak = max(abs(v) for v in pcm[:n])
    check(0 < peak < 32767 and 20 * math.log10(peak / 32768.0) <= -0.9,
          '%s peaks at %.1f dBFS, never clipping' % (name, 20 * math.log10(max(peak, 1) / 32768.0)))
    mean = sum(x) / n
    check(abs(mean) < 0.001, '%s has no DC offset (%.5f)' % (name, mean))

    # The seam, played as the loop plays it: ... x[n-2], x[n-1], x[0], x[1] ...
    d1 = [abs(x[i + 1] - x[i]) for i in range(n - 1)]
    d2 = [abs(x[i + 1] - 2 * x[i] + x[i - 1]) for i in range(1, n - 1)]
    p1, p2 = percentile(d1, 0.999), percentile(d2, 0.999)
    seam1 = abs(x[0] - x[n - 1])
    seam2 = max(abs(x[0] - 2 * x[n - 1] + x[n - 2]), abs(x[1] - 2 * x[0] + x[n - 1]))
    # A step at the seam is fine if the music is simply steep there (a loud
    # low drone wrapping mid-swing): it must not stand out from the steps
    # beside it. The curve is the strict test: a click is a kink.
    beside = max(d1[n - 6:n - 1] + d1[0:5])
    check((seam1 <= p1 or seam1 <= 1.25 * beside) and seam2 <= p2,
          '%s loops without a click: seam step %.4f (beside it %.4f), curve %.4f (99.9%% of the music: %.4f, %.4f)'
          % (name, seam1, beside, seam2, p1, p2))
    worst = max(d2)
    check(worst <= 5.0 * p2, '%s has no clicks anywhere: sharpest turn %.4f (%.1fx the 99.9th percentile)'
          % (name, worst, worst / p2))
    # Phones drop the lows: most of the energy should be up where they play.
    high = highpass(x, 300.0)
    share = sum(v * v for v in high) / max(1e-20, sum(v * v for v in x))
    if name in NEVER_ALONE:
        print('note: %s keeps %.0f%% of its energy above 300 Hz (it never plays alone; its set\'s mix is checked)'
              % (name, 100 * share))
    else:
        check(share >= 0.4, '%s keeps %.0f%% of its energy above 300 Hz, where a phone speaker plays' % (name, 100 * share))
    return x


def check_loudness(name, x, target, median=True, phone=True, key=None):
    loud = lufs(x)
    rms = 10 * math.log10(max(1e-20, sum(v * v for v in x) / len(x)))
    check(abs(loud - target) <= 1.0, '%s is %.1f LUFS integrated (RMS %.1f dBFS; target %g)' % (name, loud, rms, target))
    if not phone:
        return
    key = key or name
    if key not in _phone:
        _phone[key] = lufs(highpass(highpass(x, PHONE_HZ), PHONE_HZ))
    ph = _phone[key]
    check(loud - ph <= PHONE_DROP, '%s through a phone speaker: %.1f LUFS, %.1f dB under its full %.1f (at most %g)'
          % (name, ph, loud - ph, loud, PHONE_DROP))
    if median:
        mid = median_phone()
        check(abs(ph - mid) <= PHONE_SPREAD, '%s sits level with the other cues on a phone: %+.1f dB from their median %.1f LUFS'
              % (name, ph - mid, mid))


def check_track(name):
    lo, hi, bpm, target = EXPECT[name]
    path = os.path.join(OUT_DIR, name + '.wav')
    if not os.path.exists(path):
        if name in REQUIRED:
            check(False, '%s.wav exists' % name)
        else:
            print('skipped: %s.wav not written yet' % name)
        return
    x = check_file(name, lo, hi, bpm)
    check_loudness(name, x, target, name not in NO_MEDIAN, name not in NO_PHONE)
    if name == 'carillon':
        check_tick(x)


def check_set(set_name):
    spec = STEM_SETS[set_name]
    names = spec['stems'] + list(spec['premix'])
    have = [s for s in names if os.path.exists(os.path.join(OUT_DIR, s + '.wav'))]
    if not have:
        if set_name in REQUIRED:
            check(False, 'the %s stems exist' % set_name)
        else:
            print('skipped: the %s stems are not written yet' % set_name)
        return
    lo, hi = spec['span']
    loops = {}
    for s in names:
        if not os.path.exists(os.path.join(OUT_DIR, s + '.wav')):
            check(False, '%s.wav exists' % s)
            continue
        loops[s] = check_file(s, lo, hi, spec['bpm'])
    lengths = {s: len(x) for s, x in loops.items()}
    check(len(set(lengths.values())) == 1, 'every stem and premix of %s loops on the same frame (%s)'
          % (set_name, ', '.join('%s %d' % kv for kv in lengths.items())))
    if any(s not in loops for s in spec['stems']) or len(set(lengths.values())) != 1:
        return
    # A stem heard alone, or nearly, holds its loudness on a phone too.
    for s in spec['stems']:
        if s in NEVER_ALONE:
            continue
        full, ph = lufs(loops[s]), phone_lufs(s, loops[s])
        check(full - ph <= PHONE_DROP, '%s through a phone speaker: %.1f LUFS, %.1f dB under its full %.1f (at most %g)'
              % (s, ph, full - ph, full, PHONE_DROP))
    # All the stems at 0 dB, as play_stems starts them: the cue itself.
    whole = set_mix(set_name)
    check_loudness(set_name + ' (all its stems)', whole, spec['target'], True, True, key='mix:' + set_name)
    high = highpass(whole, 300.0)
    share = sum(v * v for v in high) / max(1e-20, sum(v * v for v in whole))
    check(share >= 0.4, '%s (all its stems) keeps %.0f%% of its energy above 300 Hz' % (set_name, 100 * share))
    top = max(map(abs, whole))
    check(20 * math.log10(max(top, 1e-9)) <= -0.9, '%s: its stems summed peak at %.1f dBFS' % (set_name, 20 * math.log10(max(top, 1e-9))))
    # Each premix is the sum of the stems it names, every sample of it (no
    # clipper touches it): off by no more than the rounding of each stem and
    # of the premix, half a step each.
    for mixed, held in spec['premix'].items():
        if mixed not in loops:
            continue
        acc = array.array('d', loops[held[0]])
        for s in held[1:]:
            acc = array.array('d', (a + b for a, b in zip(acc, loops[s])))
        diff = max(abs(a - b) for a, b in zip(acc, loops[mixed]))
        bound = 0.5 * (len(held) + 1)
        check(diff * 32768.0 <= bound + 0.01, '%s is %s summed, every sample (within %.1f LSB; the rounding allows %.1f)'
              % (mixed, ' + '.join(held), diff * 32768.0, bound))
    check_stages(set_name, spec, loops)


def stage_mix(loops, levels):
    """The stems at these levels ({stem: dB}; the rest off), summed."""
    out = None
    for stem, db in levels.items():
        g = 10 ** (db / 20.0)
        out = (array.array('d', (v * g for v in loops[stem])) if out is None
               else array.array('d', (a + v * g for a, v in zip(out, loops[stem]))))
    return out


def check_stages(set_name, spec, loops):
    """Each stage of a set as the game plays it: a set that must stay level
    (the Descent) holds the cue's loudness and sits with the other cues on a
    phone at every stage; a change that must be heard (the Hush's bells
    coming back) moves the phone loudness by at least so much."""
    phone_of = {}
    for label, levels in spec.get('stages', []):
        x = stage_mix(loops, levels)
        full, ph = lufs(x), lufs(highpass(highpass(x, PHONE_HZ), PHONE_HZ))
        phone_of[label] = ph
        top = 20 * math.log10(max(max(map(abs, x)), 1e-9))
        desc = ', '.join('%s %+g' % (k.replace(set_name + '_', ''), v) for k, v in levels.items())
        if spec.get('level'):
            mid = median_phone()
            check(abs(full - spec['target']) <= 1.0 and abs(ph - mid) <= PHONE_SPREAD and top <= -0.9,
                  '%s, %s (%s dB): %.1f LUFS (target %g), %.1f on a phone (%+.1f from the cues\' median), peak %.1f dBFS'
                  % (set_name, label, desc, full, spec['target'], ph, ph - mid, top))
        else:
            print('note: %s, %s (%s dB): %.1f LUFS, %.1f on a phone, peak %.1f dBFS' % (set_name, label, desc, full, ph, top))
    for a, b, least in spec.get('rises', []):
        rise = phone_of[b] - phone_of[a]
        check(rise >= least, '%s: from %s to %s the phone hears %+.1f dB (at least %+g)' % (set_name, a, b, rise, least))


def check_tick(x):
    """The carillon on the W4 tick: its loop is CARILLON_TICKS ticks, and the
    clock's pings land on the beats (the band over 3 kHz just after each
    tick, well above the same band a 32nd later, where nothing strikes)."""
    import instruments_v3
    tick = instruments_v3.level_tick()
    # What sets a level's beat is its tick: header (clockwork.gd keeps
    # lv.tick, TICK when there's none): every level that plays the carillon
    # must keep the tick it was rendered on.
    plays, others = level_ticks(tick)
    off = ['%s %.3f (%s)' % (lid, t, where) for lid, (t, where) in sorted(plays.items()) if abs(t - tick) > 1e-6]
    check(not off, 'every level that plays the carillon keeps its tick, %.3f s (%s)%s' % (
        tick, ', '.join(sorted(plays)) or 'none yet: no W4 level written',
        ('; not: %s; re-render the carillon on that tick, or keep TICK' % ', '.join(off)) if off else ''))
    for lid, (t, where) in sorted(others.items()):
        if abs(t - tick) > 1e-6:
            print('note: %s has tick: %.3f (%s) but doesn\'t play the carillon; its music isn\'t tick-locked' % (lid, t, where))
    # A second guard: World 4's own knob, should anything come to read it.
    knobs = instruments_v3.knob_ticks()
    check(all(abs(v - tick) < 1e-6 for v in knobs.values()),
          'World 4\'s tick knob (features/clockwork.gd: %s) is LevelData.TICK (%.3f), the beat the carillon was rendered on'
          % (', '.join('%s %.3f' % kv for kv in knobs.items()) or 'none yet', tick))
    want = CARILLON_TICKS * tick * RATE
    check(abs(len(x) - want) <= 1.0, 'carillon loops on the tick: %d frames, %d ticks of %.3f s = %.1f frames'
          % (len(x), CARILLON_TICKS, tick, want))
    band = highpass(highpass(x, 3000.0), 3000.0)
    w = int(0.012 * RATE)

    def energy(t):
        a = int(round(t * RATE))
        return sum(band[(a + i) % len(band)] ** 2 for i in range(w))
    on = sum(energy(k * tick) for k in range(CARILLON_TICKS))
    off = sum(energy(k * tick + tick / 8.0) for k in range(CARILLON_TICKS))
    ratio = 10 * math.log10(max(on, 1e-20) / max(off, 1e-20))
    check(ratio >= 6.0, 'the carillon\'s clock strikes on the tick: %.1f dB more click on the beats than a 32nd after them' % ratio)


def level_ticks(default):
    """({level id: (tick, where)} for the levels that play the carillon, the
    same for the other levels with a tick: header), from the written level
    files (game/levels/*.txt) and the level modules (tools/levels/*.py),
    which make_levels.py writes them from."""
    plays, others = {}, {}

    def note(lid, headers, where):
        music_ids = {str(headers.get('music', '')).strip(), str(headers.get('boss_music', '')).strip()}
        raw = str(headers.get('tick', '')).strip()
        try:
            t = float(raw) if raw else 0.0
        except ValueError:
            t = 0.0
        t = t if t > 0.0 else default      # as level_data.gd reads it
        if 'carillon' in music_ids:
            plays.setdefault(lid, (t, where))
        elif raw:
            others.setdefault(lid, (t, where))
    if os.path.isdir(LEVEL_TOOLS):
        import importlib.util
        sys.path.insert(0, LEVEL_TOOLS)     # for their `import common`
        try:
            for f in sorted(os.listdir(LEVEL_TOOLS)):
                if not f.endswith('.py') or f == 'common.py':
                    continue
                try:
                    # Loaded by path under a name of its own: secrets.py mustn't
                    # stand in for the standard library's secrets.
                    spec = importlib.util.spec_from_file_location('waxby_levels_' + f[:-3],
                                                                  os.path.join(LEVEL_TOOLS, f))
                    mod = importlib.util.module_from_spec(spec)
                    spec.loader.exec_module(mod)
                except Exception as e:   # another stream's module, mid-change
                    print('note: tools/levels/%s would not load (%s); its written levels are still read' % (f, e))
                    continue
                for entry in getattr(mod, 'LEVELS', []):
                    if not isinstance(entry, dict) or 'id' not in entry:
                        continue
                    headers = dict(entry.get('header', [])) if 'header' in entry else entry
                    note(str(entry['id']), headers, 'tools/levels/' + f)
        finally:
            sys.path.remove(LEVEL_TOOLS)
    if os.path.isdir(LEVELS_DIR):
        for f in sorted(os.listdir(LEVELS_DIR)):
            if not f.endswith('.txt'):
                continue
            headers = {}
            with open(os.path.join(LEVELS_DIR, f)) as fh:
                for line in fh:
                    line = line.rstrip('\n')
                    if line.strip() == '---':
                        break
                    if ':' in line:
                        k, v = line.split(':', 1)
                        headers[k.strip()] = v.strip()
            # The written file is what the game plays: it overrides the module.
            lid = f[:-4]
            plays.pop(lid, None)
            others.pop(lid, None)
            note(lid, headers, 'game/levels/' + f)
    return plays, others


# The voices a v3 maker may call, for check_scores' probe: each pitched one
# with the argument that holds its pitch (hurdy_drone's is a list of them;
# a bell's is its prime, the strike's pitch class); the unpitched ones, made
# silent too so the probe costs a fraction of a render; and the helpers the
# makers call as they are. A name a maker imports that is none of these
# fails the check, so no new voice slips past it.
PITCHED = {'harpsichord': 0, 'lead': 0, 'flute': 0, 'organ': 0, 'choir': 0, 'celesta': 0, 'bell': 0, 'rev_bell': 0,
           'strings': 0, 'timpani': 0, 'music_box': 0, 'harmonium': 0, 'drip': 0, 'sour_organ': 0, 'drone': 0,
           'bone_marimba': 0, 'bone_chime': 0, 'hurdy': 0, 'slit_drum': 0, 'glass_harmonica': 0, 'reedy_drone': 0,
           'hurdy_drone': 1}
UNPITCHED = ('kick', 'war_kick', 'snap', 'shaker', 'tambourine', 'tom', 'swell', 'noise_loop', 'clock_tick', 'ratchet',
             'woodblock', 'wind_loop', 'breath_loop', 'lake_lap', 'loop_env', 'breath', 'plop', 'splat', 'patter')
HELPERS = ('Mix', 'Loop', 'line', 'faders', 'presence', 'plain_hunt', 'ring_rows', 'level_tick', 'harmony', 'formant', 'lowpass',
           'highpass', 'bandpass', 'eaten', 'scaled', 'shape', 'normalize', 'zeros', 'add_into', 'hz', 'scale_step',
           'in_mode', 'bars_of', 'chord_at')


def played_notes(maker, modules):
    """Every pitched note a maker puts in its mix, as (part, seconds, midi):
    the maker run with every voice in `modules` swapped for one that notes
    its pitch and makes a moment of silence, and Mix.put stamping the notes
    made since the last put with the part and time it puts them at."""
    notes, pending = [], []
    blip = music.zeros(64)

    def voice(arg):
        def play(*args, **kw):
            v = args[arg] if len(args) > arg else next(iter(kw.values()))
            pending.extend(int(m) for m in (v if isinstance(v, (list, tuple)) else [v]))
            return array.array('d', blip)
        return play

    def silent(*args, **kw):
        return array.array('d', blip)

    def put(self, name, sig, t, gain=1.0):
        notes.extend((name, t, m) for m in pending)
        del pending[:]

    def stem(self, name, send):
        self.stems[name] = music.zeros(1)
        self.sends[name] = send
    saved = []
    for mod in modules:
        for name in list(PITCHED) + list(UNPITCHED):
            if name in vars(mod):
                saved.append((mod, name, getattr(mod, name)))
                if name == 'loop_env':
                    setattr(mod, name, lambda secs, points: [1.0])
                else:
                    setattr(mod, name, voice(PITCHED[name]) if name in PITCHED else silent)
    saved_mix = (music.Mix.put, music.Mix.stem)
    music.Mix.put, music.Mix.stem = put, stem
    try:
        maker()
    finally:
        music.Mix.put, music.Mix.stem = saved_mix
        for mod, name, fn in saved:
            setattr(mod, name, fn)
    return notes


def mode_at(modes, t):
    """A track's mode at t seconds: one mode, or [(from seconds, mode), ...]."""
    if isinstance(modes, str):
        return modes
    now = modes[0][1]
    for start, mode in modes:
        if t >= start - 0.001:
            now = mode
    return now


def check_scores():
    """Every note every v3 maker plays in its track's mode (the mode it's in
    at that moment, for a score that changes mode), but for the parts left
    out on purpose (FREE: the Hush's own notes); and every mode a D mode
    holding D F G A C (or, for a major cue, D F# A)."""
    import instruments_v3
    names = {'C': 0, 'C#': 1, 'D': 2, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'Ab': 8, 'A': 9, 'Bb': 10, 'B': 11}
    spell = {v: k for k, v in names.items()}
    mods = [sys.modules[m] for m in music.MODULES]
    for m in mods:
        for name, fn in sorted(vars(m).items()):
            if callable(fn) and getattr(fn, '__module__', '') in ('music', 'instruments_v3') \
                    and name not in PITCHED and name not in UNPITCHED and name not in HELPERS:
                check(False, '%s calls %s, which check_music.py doesn\'t know as a voice or a helper (add it to '
                             'PITCHED, UNPITCHED or HELPERS)' % (m.__name__, name))
    for m in mods:
        modes = getattr(m, 'MODES', {})
        free = getattr(m, 'FREE', {})
        makers = dict(getattr(m, 'TRACKS', {}))
        makers.update(getattr(m, 'STEM_SETS', {}))
        for track, maker in makers.items():
            if track not in modes:
                check(False, '%s has a mode in %s.MODES' % (track, m.__name__))
                continue
            notes = played_notes(maker, mods + [instruments_v3])
            if modes[track] is None:
                check(not notes, '%s plays no note (a bed of noise)%s' % (
                    track, (' (but it plays %d)' % len(notes)) if notes else ''))
                continue
            kept = [(part, t, n) for part, t, n in notes if part not in free.get(track, ())]
            bad = sorted({(mode_at(modes[track], t), n) for part, t, n in kept
                          if not instruments_v3.in_mode(n, mode_at(modes[track], t))})
            which = modes[track] if isinstance(modes[track], str) else ' then '.join(md for _, md in modes[track])
            check(not bad and bool(kept), '%s: all %d notes it plays are in D %s%s%s' % (
                track, len(kept), which,
                (' (%s left out on purpose)' % ', '.join(free[track])) if track in free else '',
                (' (not: %s)' % ', '.join('%s%d in %s' % (spell[n % 12], n // 12 - 1, md) for md, n in bad)) if bad else ''))
            for md in {mode_at(modes[track], t) for _, t, _ in kept}:
                pcs = set(instruments_v3.MODES[md])
                core = {0, 7} | ({3, 5, 10} if md != 'major' else {4})
                check(core <= pcs, '%s\'s mode (D %s) holds %s' % (track, md, 'D F G A C' if md != 'major' else 'D F# A'))


def check_names():
    """Every file music.py writes is one Sfx plays, and every track Sfx names
    is one checked here."""
    try:
        with open(SFX_GD) as f:
            src = f.read()
    except OSError:
        print('skipped: no %s' % SFX_GD)
        return
    tracks = set(re.findall(r'"([a-z_0-9]+)"', re.search(r'const TRACKS := \[(.*?)\]', src, re.S).group(1)))
    stems = set(re.findall(r'"([a-z_0-9]+)"', re.search(r'const STEMS := \{(.*?)\n\}', src, re.S).group(1)))
    premix = set(re.findall(r'"([a-z_0-9]+)": \[', re.search(r'const PREMIX := \{(.*?)\}\}', src, re.S).group(1)))
    sfx_names = tracks | stems | premix
    ours = set(music.TRACKS)
    for s in STEM_SETS.values():
        ours |= set(s['stems']) | set(s['premix'])
    for n in sorted(ours & set(PENDING)):
        if n in sfx_names:
            print('note: %s is now a name Sfx plays: take it out of PENDING' % n)
        else:
            print('note: %s is written for a request (%s); Sfx does not name it yet' % (n, PENDING[n]))
    stray = sorted(n for n in ours if n not in sfx_names and n not in PENDING)
    check(not stray, 'every file music.py writes is a name Sfx plays%s' % ((' (not: %s)' % ', '.join(stray)) if stray else ''))
    unmade = sorted((set(music.STEM_SETS) - set(STEM_SETS)) | {s for s in STEM_SETS if s in REQUIRED and s not in music.STEM_SETS})
    check(not unmade, 'the stem sets checked here are the ones music.py makes%s' % ((' (not: %s)' % ', '.join(unmade)) if unmade else ''))
    unchecked = sorted(t for t in tracks if t not in EXPECT) + sorted(t for t in music.TRACKS if t not in EXPECT)
    check(not unchecked, 'every track Sfx names or music.py makes is checked here%s' % (
        (' (not: %s)' % ', '.join(unchecked)) if unchecked else ''))
    for set_name, spec in STEM_SETS.items():
        want = re.search(r'"%s": \[(.*?)\]' % set_name, src)
        listed = re.findall(r'"([a-z_0-9]+)"', want.group(1)) if want else []
        check(listed == spec['stems'], 'Sfx.STEMS["%s"] names these stems in this order (%s)' % (set_name, ', '.join(listed)))
    # Each premix Sfx names holds the stems music.py summed into it.
    block = re.search(r'const PREMIX := \{(.*?)\}\}', src, re.S).group(1)
    for set_name, spec in STEM_SETS.items():
        for mixed, held in spec['premix'].items():
            m = re.search(r'"%s": \[(.*?)\]' % mixed, block)
            if m is None:
                continue
            listed = re.findall(r'"([a-z_0-9]+)"', m.group(1))
            check(sorted(listed) == sorted(held), 'Sfx.PREMIX["%s"]["%s"] holds the stems music.py sums into it (%s)'
                  % (set_name, mixed, ', '.join(listed)))


def main(names):
    if not names:
        check_names()
        check_scores()
    for name in names or list(EXPECT) + list(STEM_SETS):
        if name in STEM_SETS:
            check_set(name)
        elif name in EXPECT:
            check_track(name)
        else:
            check(False, '%s is a track or a stem set' % name)
    print('%d failed' % failed if failed else 'all music checks passed')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main(sys.argv[1:])
