"""WAXBY v3's world music, rendered by tools/audio/music.py (see there).

  orchard   D Dorian, 6/8, dotted quarter 104, 48 bars (55 s): World 3, the
            Bone Orchard. A bone-marimba ostinato over a hurdy-gurdy's drone
            on D and A; the flute's tune leaps a sixth, D up to the Dorian B,
            and the title motif answers it. A A' B B' A'' and a bare breakdown
            where bone chimes knock in the branches. Autumnal, soft, a little
            uncanny.
  carillon  D Aeolian, 4/4, one beat = the W4 tick (level_data.gd's TICK,
            0.536 s: 112 BPM), 32 bars (68.6 s): World 4, the Frozen Carillon.
            A clock ticking sixteenths under everything, tick-tock on the
            beats; the quarter chime D F G A / A G F D on celesta; a
            harpsichord escapement; glass harmonica; plain hunt on six bells
            in the B section. The loop is 128 ticks, so seek_music(ftime)
            keeps every beat on the level's tick.
  sanctum   D Dorian, suspended (no thirds on the downbeats), 3/4, 90 BPM,
            36 bars (72 s): World 5, the Shattered Sanctum. Glass harmonica,
            a celesta arpeggio shimmering in sixteenths, wind in the tracery;
            a leaping fifth; the title motif twice as slow in the choir;
            timpani at the phrase ends.
  hushdeep  No key, no beat (a notional 48 BPM), 16 bars (80 s), -21 LUFS:
            World 6, the Hushdeep. A reedy drone on D and A down in the dark,
            reversed bells (one on the Hush's Eb), lake laps, the breath of
            the Hush, and a music box playing fragments of the title melody
            whose notes are eaten before they end. Two bars in every eight
            are only the drone.
  secret    D Dorian, 3/4, 96 BPM, 24 bars (45 s): the six secret levels. A
            hidden chapel: music box and celesta, a soft choir, sparkle
            chimes; the tune opens on A5 C6 D6, the fragment the secret's hum
            plays near its exit.

P1:
  trial     D Aeolian, 4/4, 150 BPM, 16 bars (25.6 s): the Vigil Trials. A
            harpsichord in sixteenths, plucks on the off-beats, a clock
            ticking the eighths, a bright lead; the quarter chime run like a
            timer in B. Tense, but fun.
  descent   stems, D Aeolian, 4/4, 100 BPM, 24 bars (57.6 s): Endless Descent.
              descent_floor  a harpsichord ostinato, the organ, a recorder's
                             long counter-line (it plays alone for the first
                             nine depths, so it carries the most weight)
              descent_drive  kick, tambourine and shaker, the pulse lead's
                             tune (from depth 10)
              descent_deep   a low choir, reversed bells, a drone (from 25;
                             it leads once the drive drops 6 dB at 40)
            The depths' levels (asked of descent.gd, checked by
            check_music.py so every depth sits level with the other cues):
            floor +2.5 dB alone; +1.5 with the drive; all three at 0 from
            25; from 40 the drive -6 and the deep +2.
P2:
  amb_orchard, amb_carillon, amb_sanctum, amb_hushdeep  the ambience beds,
            12 s loops at -30 LUFS: wind in the branches and far bone chimes;
            wind in the louvres and the works clunking far off; wind and the
            glass still humming; the lake lapping, and nothing.
"""

import array
import random
from operator import add, mul

from music import (RATE, Mix, drone, formant, OO, lowpass, harpsichord, lead, flute, organ, choir, celesta, bell,
                   rev_bell, kick, snap, shaker, tambourine, timpani, music_box, swell, harmony)
from instruments_v3 import (bone_marimba, bone_chime, hurdy, hurdy_drone, woodblock, glass_harmonica, clock_tick,
                            ratchet, plain_hunt, ring_rows, lake_lap, wind_loop, reedy_drone, eaten, breath_loop,
                            loop_env, line, level_tick, scale_step, Loop, faders)


# ---------------------------------------------------------------- orchard

# The Bone Orchard's tune, per 6/8 bar, in eighths: (start, eighths, midi).
ORCHARD_A = [
    [(0, 3, 74), (3, 2, 83), (5, 1, 81)],                          # Dm  D5. B5 A5: the sixth, up to the Dorian B
    [(0, 1, 79), (1, 1, 81), (2, 1, 83), (3, 2, 86), (5, 1, 83)],  # G   G5 A5 B5 D6 B5
    [(0, 2, 81), (2, 1, 77), (3, 3, 74)],                          # Dm  A5 F5 D5.
    [(0, 1, 76), (1, 1, 77), (2, 1, 79), (3, 2, 76), (5, 1, 72)],  # C   E5 F5 G5 E5 C5
    [(0, 1, 74), (1, 1, 69), (2, 1, 74), (3, 2, 77), (5, 1, 81)],  # Dm  D5 A4 D5 F5 A5: the title motif answers
    [(0, 3, 83), (3, 2, 81), (5, 1, 79)],                          # G   B5. A5 G5
    [(0, 1, 76), (1, 1, 77), (2, 1, 79), (3, 2, 81), (5, 1, 76)],  # Am  E5 F5 G5 A5 E5
    [(0, 5, 74), (5, 1, 69)],                                      # Dm  D5 -- A4
]
ORCHARD_A2 = ORCHARD_A[:4] + [
    [(0, 1, 77), (1, 1, 72), (2, 1, 77), (3, 2, 81), (5, 1, 84)],  # F   F5 C5 F5 A5 C6
    [(0, 3, 86), (3, 2, 83), (5, 1, 79)],                          # G   D6. B5 G5
    [(0, 2, 81), (2, 1, 79), (3, 2, 76), (5, 1, 72)],              # Am  A5 G5 E5 C5
    [(0, 6, 74)],                                                  # Dm  D5
]
ORCHARD_B = [
    [(0, 2, 84), (2, 1, 81), (3, 2, 77), (5, 1, 81)],              # F   C6 A5 F5 A5
    [(0, 2, 79), (2, 1, 76), (3, 3, 72)],                          # C   G5 E5 C5.
    [(0, 1, 74), (1, 1, 79), (2, 1, 83), (3, 2, 86), (5, 1, 83)],  # G   D5 G5 B5 D6 B5
    [(0, 3, 81), (3, 3, 77)],                                      # Dm  A5. F5.
    [(0, 2, 84), (2, 1, 81), (3, 2, 77), (5, 1, 81)],              # F
    [(0, 2, 79), (2, 1, 84), (3, 3, 88)],                          # C   G5 C6 E6.
    [(0, 2, 86), (2, 1, 83), (3, 2, 79), (5, 1, 76)],              # Em  D6 B5 G5 E5
    [(0, 6, 81)],                                                  # Am  A5
]
ORCHARD_B2 = ORCHARD_B[:6] + [
    [(0, 2, 79), (2, 1, 83), (3, 2, 86), (5, 1, 88)],              # Em  G5 B5 D6 E6
    [(0, 3, 81), (3, 1, 79), (4, 1, 77), (5, 1, 76)],              # Am  A5. G5 F5 E5, down to the D
]
# The marimba's figure under each chord: root, fifth, octave, fifth, tenth, fifth.
ORCHARD_OST = {'Dm': (62, 69, 74, 69, 77, 69), 'G': (55, 62, 67, 62, 71, 62), 'C': (60, 67, 72, 67, 76, 67),
               'Am': (57, 64, 69, 64, 72, 64), 'F': (53, 60, 65, 60, 69, 60), 'Em': (52, 59, 64, 59, 67, 59)}
ORCHARD_TONES = {'Dm': (62, 65, 69), 'G': (67, 71, 74), 'C': (60, 64, 67), 'Am': (57, 60, 64), 'F': (65, 69, 72),
                 'Em': (64, 67, 71)}
ORCHARD_FORM = (['Dm', 'G', 'Dm', 'C', 'Dm', 'G', 'Am', 'Dm'] +      # A    the flute
                ['Dm', 'G', 'Dm', 'C', 'F', 'G', 'Am', 'Dm'] +       # A'   the hurdy, the flute under it
                ['F', 'C', 'G', 'Dm', 'F', 'C', 'Em', 'Am'] +        # B    the marimba sings, the flute holds
                ['F', 'C', 'G', 'Dm', 'F', 'C', 'Em', 'Am'] +        # B'   marimba and flute together
                ['Dm', 'G', 'Dm', 'C', 'Dm', 'G', 'Am', 'Dm'] +      # A''  flute and hurdy, everything in
                ['Dm', 'Dm', 'C', 'C', 'Dm', 'Dm', 'Am', 'Am'])      # C    the breakdown: bones in the wind


def orchard():
    e = 60.0 / 104.0 / 3.0        # an eighth (the dotted quarter is 104 BPM)
    bar = 6 * e
    form = ORCHARD_FORM
    mix = Mix(len(form) * bar, tail=5.0)
    for name, send in (('marimba', 0.22), ('drone', 0.2), ('flute', 0.38), ('hurdy', 0.28), ('high', 0.35),
                       ('perc', 0.1), ('chimes', 0.75)):
        mix.stem(name, send)
    hum = random.Random(31)
    L = len(form) * bar
    buzz = []
    for b, chord in enumerate(form):
        t0 = b * bar
        section = b // 8                # 0 A, 1 A', 2 B, 3 B', 4 A'', 5 C
        k = b % 8
        # The bone marimba: the figure in running eighths (sparser in the
        # breakdown), each bar's first eighth struck hardest.
        fig = ORCHARD_OST[chord]
        for j, m in enumerate(fig):
            if section == 5 and j in (1, 4):
                continue
            accent = (1.0, 0.62, 0.72, 0.85, 0.6, 0.7)[j]
            mix.put('marimba', bone_marimba(m, 0.55), t0 + j * e + hum.uniform(-0.004, 0.004),
                    0.3 * accent * hum.uniform(0.9, 1.0) * (0.85 if section == 5 else 1.0))
        # The chien buzzes on the beats once the hurdy has come in.
        if section in (1, 2, 3, 4):
            buzz += [t0, t0 + 3 * e]
        # The tune.
        if section == 0:
            line(mix, 'flute', ORCHARD_A[k], t0, e, lambda m, d: flute(m, d - 0.02), 0.3)
        elif section == 1:
            line(mix, 'hurdy', ORCHARD_A2[k], t0, e, lambda m, d: hurdy(m - 12, d - 0.03), 0.2)
            under = harmony(ORCHARD_A2[k], [(chord, 0.0, 6.0)], ORCHARD_TONES)
            line(mix, 'flute', under, t0, e, lambda m, d: flute(m, d - 0.02), 0.13)
        elif section == 2:
            line(mix, 'high', ORCHARD_B[k], t0, e, lambda m, d: bone_marimba(m, 0.8), 0.3,
                 accent=lambda s: 1.0 if s == 0 else 0.85)
            hold = sorted(ORCHARD_TONES[chord])[1] + (12 if chord in ('Am', 'C') else 0)
            mix.put('flute', flute(hold, bar - 0.05), t0, 0.12)
        elif section == 3:
            line(mix, 'high', ORCHARD_B2[k], t0, e, lambda m, d: bone_marimba(m, 0.8), 0.24)
            line(mix, 'flute', ORCHARD_B2[k], t0, e, lambda m, d: flute(m, d - 0.02), 0.2)
        elif section == 4:
            line(mix, 'flute', ORCHARD_A[k], t0, e, lambda m, d: flute(m, d - 0.02), 0.26)
            line(mix, 'hurdy', ORCHARD_A[k], t0, e, lambda m, d: hurdy(m - 12, d - 0.03), 0.15)
        else:
            # Bone chimes knocked by the wind: a few high notes, never on the beat.
            for j in range(hum.choice((2, 3))):
                at = t0 + (hum.randint(0, 11) + 0.5) * e / 2
                m = hum.choice((81, 84, 86, 89, 91, 93))
                mix.put('chimes', bone_chime(m), at, 0.13 * hum.uniform(0.7, 1.0))
        # The drums: a soft kick on the beat, the shaker rustling like
        # branches, a woodblock on the off-beats once it gets going.
        if section != 5:
            mix.put('perc', kick(), t0, 0.3)
            if section >= 1:
                mix.put('perc', kick(), t0 + 3 * e, 0.2)
            for j in range(6):
                g = (0.05, 0.022, 0.032, 0.04, 0.022, 0.032)[j] * (0.6 if section == 0 else 1.0)
                mix.put('perc', shaker(j % 2), t0 + j * e + hum.uniform(-0.004, 0.004), g)
            if section in (2, 3, 4):
                for j in (2, 5):
                    mix.put('perc', woodblock(j // 5), t0 + j * e + hum.uniform(-0.003, 0.003), 0.1 if j == 5 else 0.07)
        else:
            for j in (0, 3):
                mix.put('perc', shaker(j % 2), t0 + j * e, 0.025)
    # The hurdy's drone strings, D3 and A3, all the way round.
    mix.put('drone', hurdy_drone(L, (50, 57), 0.075, buzz, 0.2, 0.4, seed=3), 0.0)
    # A bell swelling backwards out of the breakdown into the top of the loop.
    mix.put('chimes', rev_bell(62, 2 * bar), L - 2 * bar, 0.28)
    mix.put('chimes', rev_bell(50, 2 * bar), L - 2 * bar, 0.2)
    return mix, dict(room=0.84, damp=0.4, wet=0.8), 104


# ---------------------------------------------------------------- carillon

# The quarter chime, D F G A / A G F D, is the tune's seed. Per 4/4 bar, in
# beats: (start, beats, midi).
CARILLON_A = [
    [(0, 1, 74), (1, 1, 77), (2, 1, 79), (3, 1, 81)],              # Dm  D5 F5 G5 A5: the chime up
    [(0, 1, 81), (1, 1, 79), (2, 1, 77), (3, 1, 74)],              # Bb  A5 G5 F5 D5: and down
    [(0, 1.5, 76), (1.5, .5, 79), (2, 2, 84)],                     # C   E5. G5 C6
    [(0, 1, 81), (1, 1, 79), (2, 2, 76)],                          # Am  A5 G5 E5
    [(0, 1, 74), (1, 1, 77), (2, 1, 79), (3, 1, 81)],              # Dm
    [(0, 2, 86), (2, 1, 84), (3, 1, 82)],                          # Bb  D6 C6 Bb5
    [(0, 1, 81), (1, 1, 79), (2, 1, 77), (3, 1, 79)],              # Gm  A5 G5 F5 G5
    [(0, 3, 81), (3, 1, 76)],                                      # Am  A5 -- E5
]
CARILLON_A2 = CARILLON_A[:4] + [
    [(0, 1, 86), (1, 1, 84), (2, 1, 81), (3, 1, 79)],              # Dm  D6 C6 A5 G5: the chime from above
    [(0, 1, 77), (1, 1, 79), (2, 2, 82)],                          # Bb  F5 G5 Bb5
    [(0, 1.5, 81), (1.5, .5, 79), (2, 1, 77), (3, 1, 76)],         # Gm  A5. G5 F5 E5
    [(0, 4, 74)],                                                  # Dm  D5
]
CARILLON_FORM = (['Dm', 'Bb', 'C', 'Am', 'Dm', 'Bb', 'Gm', 'Am'] +     # A    the chime on celesta
                 ['Dm', 'Bb', 'C', 'Am', 'Dm', 'Bb', 'Gm', 'Dm'] +     # A'   the escapement in sixteenths
                 ['Dm', 'Bb', 'C', 'Dm', 'Dm', 'Bb', 'C', 'Am'] +      # B    plain hunt on six bells
                 ['Dm', 'Bb', 'C', 'Am', 'Dm', 'Bb', 'Gm', 'Am'])      # A''  the tune on the bells
# The harpsichord's escapement: root, fifth, octave, fifth, tenth, fifth, octave, fifth.
CARILLON_ESC = {'Dm': (62, 69, 74, 69, 77, 69, 74, 69), 'Bb': (58, 65, 70, 65, 74, 65, 70, 65),
                'C': (60, 67, 72, 67, 76, 67, 72, 67), 'Am': (57, 64, 69, 64, 72, 64, 69, 64),
                'Gm': (55, 62, 67, 62, 70, 62, 67, 62)}
CARILLON_PAD = {'Dm': (69, 74, 77), 'Bb': (70, 74, 77), 'C': (67, 72, 76), 'Am': (69, 72, 76), 'Gm': (67, 70, 74)}
CARILLON_ROOT = {'Dm': 38, 'Bb': 34, 'C': 36, 'Am': 33, 'Gm': 31}
# The six bells, treble to tenor: D5 C5 A4 G4 F4 D4 (all on the pentatonic).
CARILLON_BELLS = (74, 72, 69, 67, 65, 62)


def carillon():
    b = level_tick()               # one beat is the level's tick
    bar = 4 * b
    form = CARILLON_FORM
    mix = Mix(len(form) * bar, tail=5.0)
    for name, send in (('clock', 0.04), ('harpsichord', 0.2), ('lead', 0.4), ('glass', 0.45), ('bells', 0.6),
                       ('pedal', 0.05), ('drums', 0.08)):
        mix.stem(name, send)
    hum = random.Random(41)
    L = len(form) * bar
    hunt = plain_hunt(6)
    rounds = hunt[0]
    for n, chord in enumerate(form):
        t0 = n * bar
        section = n // 8                # 0 A, 1 A', 2 B, 3 A''
        k = n % 8
        # The clock, exactly on the grid: tick-tock on the beats, a faint
        # escapement tick every sixteenth between.
        for s in range(16):
            t = t0 + s * b / 4
            if s % 4 == 0:
                beat = s // 4
                mix.put('clock', clock_tick(3520.0 if beat % 2 == 0 else 2350.0, beat), t, 0.5 if beat == 0 else 0.42)
            else:
                mix.put('clock', clock_tick(0.0, s), t, 0.09 if s % 2 else 0.12)
        # The harpsichord escapement: eighths, sixteenths in A' and A'',
        # quarters under the ringing.
        esc = CARILLON_ESC[chord]
        steps = {0: 2, 1: 4, 2: 1, 3: 4}[section]
        for j in range(4 * steps):
            m = esc[(j * 8 // (4 * steps)) % 8] if steps < 4 else esc[j % 8]
            accent = 1.0 if j % steps == 0 else 0.72
            mix.put('harpsichord', harpsichord(m, 0.2 if steps == 4 else 0.3), t0 + j * b / steps + hum.uniform(-0.002, 0.002),
                    (0.34 if steps == 4 else 0.4) * accent * hum.uniform(0.93, 1.0))
        # The glass harmonica holds the chord; the organ's pedal from A' on.
        for m in CARILLON_PAD[chord]:
            mix.put('glass', glass_harmonica(m, bar - 0.1, 0.2, 0.5), t0, (0.05, 0.065, 0.08, 0.065)[section])
        if section >= 1:
            mix.put('pedal', organ(CARILLON_ROOT[chord] + 12, bar - 0.1, 'pedal', 0.08, 0.2), t0, 0.12)
        # The tune: the celesta; in A'' the bells ring it and the celesta
        # sparkles an octave over them.
        if section in (0, 1):
            tune = CARILLON_A if section == 0 else CARILLON_A2
            line(mix, 'lead', tune[k], t0, b, lambda m, d: celesta(m), 0.3)
        elif section == 3:
            line(mix, 'bells', CARILLON_A[k], t0, b, lambda m, d: bell(m - 12, 1.8), 0.34)
            line(mix, 'lead', CARILLON_A[k], t0, b, lambda m, d: celesta(m + 12), 0.16)
        # Drums: a kick on one (and three once it moves), a snap on the backbeat.
        kicks = (0,) if section == 0 else (0, 2)
        for beat in kicks:
            mix.put('drums', kick(), t0 + beat * b, 0.36 if beat == 0 else 0.28)
        if section in (1, 3):
            for beat in (1, 3):
                mix.put('drums', snap(), t0 + beat * b, 0.1)
    # B: plain hunt on six bells in triplet eighths, rounds to rounds (two
    # rows a bar), a great bell tolling in the first downbeat.
    rows = [rounds, rounds] + hunt[1:13] + [rounds, rounds]
    ring_rows(mix, 'bells', rows, 16 * bar, b / 3, CARILLON_BELLS, 0.2, 1.2, hum, 0.004,
              strike=lambda bell_no, place: 0.8 + 0.07 * bell_no)
    mix.put('bells', bell(50, 4.0), 16 * bar, 0.3)
    # The spring wound at the very end, back to the top.
    mix.put('drums', ratchet(10, 1.6 * b, 7), L - 2 * b, 0.12)
    return mix, dict(room=0.86, damp=0.3, wet=0.8), 60.0 / b



# ---------------------------------------------------------------- sanctum

# Suspended chords (no thirds): the glass rings open.
SANCTUM_PAD = {'Dsus2': (62, 64, 69, 74), 'Dsus4': (62, 67, 69, 74), 'Csus2': (60, 62, 67, 72),
               'Gsus2': (62, 67, 69, 74), 'Gsus4': (60, 67, 72, 74), 'Asus4': (62, 64, 69, 76),
               'Fsus2': (65, 67, 72, 77), 'Esus4': (64, 69, 71, 76)}
SANCTUM_ROOT = {'Dsus2': 50, 'Dsus4': 50, 'Csus2': 48, 'Gsus2': 43, 'Gsus4': 43, 'Asus4': 45, 'Fsus2': 41,
                'Esus4': 40}
SANCTUM_FORM = (['Dsus2', 'Csus2', 'Gsus2', 'Asus4', 'Dsus2', 'Fsus2', 'Csus2', 'Asus4',
                 'Dsus4', 'Csus2', 'Gsus2', 'Asus4'] +                  # A  the glass leaps a fifth
                ['Dsus2', 'Dsus2', 'Asus4', 'Gsus2', 'Esus4', 'Csus2', 'Fsus2', 'Gsus4',
                 'Dsus4', 'Csus2', 'Asus4', 'Asus4'] +                  # B  the choir: the title, twice as slow
                ['Dsus2', 'Csus2', 'Gsus2', 'Asus4', 'Dsus2', 'Fsus2', 'Csus2', 'Asus4',
                 'Dsus4', 'Csus2', 'Gsus2', 'Asus4'])                   # C  the pulse lead, the timpani
# Per 3/4 bar, in beats: (start, beats, midi). Nothing lands a third on a downbeat.
SANCTUM_A = [
    [(0, 1, 74), (1, 2, 81)], [(0, 2, 79), (2, 1, 76)], [(0, 1, 74), (1, 2, 79)], [(0, 3, 81)],
    [(0, 1, 74), (1, 2, 81)], [(0, 2, 84), (2, 1, 79)], [(0, 2, 74), (2, 1, 76)], [(0, 3, 76)],
    [(0, 1, 79), (1, 2, 86)], [(0, 2, 84), (2, 1, 79)], [(0, 1, 81), (1, 1, 79), (2, 1, 76)], [(0, 3, 74)],
]
SANCTUM_B = [   # D5 . A4 D5 F5 | A5 -- G5 F5 | E5 . C5 E5 G5 | C6 -- B5 G5, each note twice as long
    [(0, 3, 74)], [(0, 1, 69), (1, 1, 74), (2, 1, 77)], [(0, 3, 81)], [(0, 1, 81), (1, 1, 79), (2, 1, 77)],
    [(0, 3, 76)], [(0, 1, 72), (1, 1, 76), (2, 1, 79)], [(0, 3, 84)], [(0, 1, 84), (1, 1, 83), (2, 1, 79)],
    [(0, 3, 79)], [(0, 2, 79), (2, 1, 76)], [(0, 3, 74)], [(0, 3, 76)],
]
SANCTUM_C = [
    [(0, 1, 69), (1, 2, 76)], [(0, 1, 74), (1, 2, 79)], [(0, 1, 74), (1, 2, 81)], [(0, 3, 81)],
    [(0, 1, 81), (1, 2, 88)], [(0, 2, 84), (2, 1, 79)], [(0, 2, 79), (2, 1, 76)], [(0, 3, 76)],
    [(0, 1, 74), (1, 2, 81)], [(0, 1, 79), (1, 1, 76), (2, 1, 74)], [(0, 3, 74)], [(0, 2, 69), (2, 1, 76)],
]


def sanctum():
    b = 60.0 / 90.0
    bar = 3 * b
    form = SANCTUM_FORM
    mix = Mix(len(form) * bar, tail=6.0)
    for name, send in (('glass', 0.5), ('arp', 0.55), ('lead', 0.4), ('choir', 0.65), ('organ', 0.4),
                       ('drums', 0.3), ('wind', 0.15)):
        mix.stem(name, send)
    hum = random.Random(51)
    L = len(form) * bar
    for n, chord in enumerate(form):
        t0 = n * bar
        section = n // 12               # 0 A, 1 B, 2 C
        k = n % 12
        pad = SANCTUM_PAD[chord]
        # The glass harmonica holds the open chord; a soft organ under it.
        for m in pad:
            mix.put('glass', glass_harmonica(m, bar - 0.05, 0.35, 0.7), t0, (0.05, 0.04, 0.05)[section])
        mix.put('organ', organ(SANCTUM_ROOT[chord], bar + 0.1, 'flute', 0.4, 0.6), t0, 0.08)
        mix.put('organ', organ(SANCTUM_ROOT[chord] + 12, bar + 0.1, 'flute', 0.4, 0.6), t0, 0.05)
        # The celesta shimmering over it: sixteenths up and down the chord an
        # octave up (eighths while the choir sings).
        arp = [m + 12 for m in pad]
        steps = 2 if section == 1 else 4
        order = (0, 1, 2, 3, 2, 1)
        for j in range(3 * steps):
            m = arp[order[j % 6]]
            g = (0.06, 0.07, 0.075)[section] * (1.0 if j % steps == 0 else 0.7) * hum.uniform(0.85, 1.0)
            mix.put('arp', celesta(m), t0 + j * b / steps + hum.uniform(-0.003, 0.003), g)
        # The tunes.
        if section == 0:
            line(mix, 'lead', SANCTUM_A[k], t0, b, lambda m, d: glass_harmonica(m, d - 0.05, 0.12, 0.5), 0.3)
        elif section == 1:
            line(mix, 'choir', SANCTUM_B[k], t0, b, lambda m, d: choir(m, d, 0.25, 0.6, 'oo'), 0.3)
            line(mix, 'choir', SANCTUM_B[k], t0, b, lambda m, d: choir(m - 12, d, 0.25, 0.6, 'oo'), 0.14)
            line(mix, 'lead', SANCTUM_A[k], t0, b, lambda m, d: glass_harmonica(m + 12, d - 0.05, 0.12, 0.5), 0.08)
        else:
            line(mix, 'lead', SANCTUM_C[k], t0, b, lambda m, d: lead(m, d - 0.04), 0.24)
            for m in pad[1:]:
                mix.put('choir', choir(m, bar + 0.2, 0.5, 0.8, 'oo'), t0, 0.07)
        # Timpani closing the phrases: the fourth bar in C, the last of each section.
        if k == 11 or (section == 2 and k in (3, 7)):
            root = SANCTUM_ROOT[chord]
            drum = 45 if root in (45, 40) else 50
            if k == 11:
                for j in range(6):
                    mix.put('drums', timpani(drum, 0.3), t0 + (1.5 + j * 0.25) * b, 0.12 + 0.05 * j)
            mix.put('drums', timpani(drum, 0.3), t0 + 2 * b, 0.38)
        if section == 2 and k % 4 == 0:
            mix.put('drums', timpani(50, 0.3), t0, 0.26)
    # The wind through the broken tracery, all the way round.
    mix.put('wind', wind_loop(L, 55, 300.0, 1200.0, 5), 0.0, 0.12)
    return mix, dict(room=0.9, damp=0.3, wet=0.8), 90



# ---------------------------------------------------------------- hushdeep

# Fragments of the title melody on a lone music box, each note eaten before
# it ends: (seconds into the loop, [(seconds, midi), ...]). None falls in the
# silences (bars 7-8 and 15-16), where only the drone is left.
HUSHDEEP_BOX = [
    (1.3, [(0.9, 74), (0.45, 69), (0.45, 74), (1.4, 77)]),        # D5 . A4 D5 F5
    (9.6, [(1.5, 81), (0.6, 79), (0.6, 77), (1.8, 76)]),          # A5 -- G5 F5 E5
    (19.8, [(0.9, 74), (0.45, 69), (1.6, 74)]),                   # D5 . A4 D5
    (25.2, [(1.2, 72), (0.6, 76), (1.6, 79)]),                    # C5 E5 G5 ...
    (41.5, [(0.9, 74), (0.45, 69), (0.45, 74), (0.8, 77), (1.8, 81)]),   # the whole opening, almost
    (50.8, [(1.5, 81), (0.7, 79), (2.0, 77)]),                    # A5 G5 F5
    (58.4, [(1.0, 76), (1.0, 74)]),                               # E5 D5
    (63.9, [(2.2, 69)]),                                          # A4, and gone
]
# (strike, prime, level): on D, A, then Eb (the Hush's own note, a semitone
# over the drone's D, as in hush_final's void) and D again.
HUSHDEEP_BELLS = [(8.8, 50, 0.5), (22.4, 45, 0.42), (46.6, 51, 0.4), (61.8, 62, 0.34)]
HUSHDEEP_LAPS = [3.1, 7.9, 13.4, 17.2, 23.8, 27.5, 43.3, 48.9, 54.1, 57.2, 65.6]
HUSHDEEP_QUIET = ((30.0, 40.0), (70.0, 80.0))   # the two bars in every eight: only the drone


def hushdeep():
    L = 80.0                        # 16 bars of a notional 48 BPM
    mix = Mix(L, tail=6.0)
    for name, send in (('drone', 0.3), ('box', 0.25), ('bells', 0.85), ('lake', 0.2), ('air', 0.3)):
        mix.stem(name, send)
    # The drone: D1 and A1, reed-voiced so their weight sits where a phone
    # plays, each breathing on its own slow cycle; a D3 hum over them.
    # Everything else falls silent for two bars in every eight, and the
    # drone sinks under them: near-silence.
    gate = loop_env(L, [(0.0, 1.0), (28.5, 1.0), (30.0, 0.0), (39.0, 0.0), (41.0, 1.0), (68.5, 1.0), (70.0, 0.0),
                        (79.0, 0.0)])
    sink = [0.45 + 0.55 * g for g in loop_env(L, [(0.0, 1.0), (27.0, 1.0), (31.0, 0.0), (38.0, 0.0), (41.5, 1.0),
                                                  (67.0, 1.0), (71.0, 0.0), (78.5, 0.0)])]
    body = reedy_drone(26, L, 0.17, [(2, 0.2, 0.0), (5, 0.08, 1.3)], detune=3, top=1400.0)
    body = array.array('d', map(add, body, reedy_drone(33, L, 0.09, [(3, 0.35, 2.0)], detune=2, top=1400.0)))
    hum = drone(50, L, [(0.3 + 2.0 * formant(146.8 * k, OO)) / k for k in range(1, 25)], 0.05,
                [(1, 0.7, 4.2), (4, 0.2, 0.5)], detune=1)
    body = array.array('d', map(add, body, hum))
    mix.put('drone', array.array('d', map(mul, body, sink)), 0.0)
    air = breath_loop(L, 61, 950.0, 0.9)
    mix.put('air', array.array('d', (a * g for a, g in zip(air, gate))), 0.0, 0.05)
    # The music box, eaten: each note stops somewhere between 40 and 70 % of
    # the way through what it should have held.
    seed = 0
    for at, notes in HUSHDEEP_BOX:
        t = at
        for secs, m in notes:
            seed += 1
            sig = music_box(m)[:int((secs + 0.3) * RATE)]
            mix.put('box', eaten(sig, 700 + seed), t, 0.26)
            t += secs
    for strike, prime, level in HUSHDEEP_BELLS:
        mix.put('bells', rev_bell(prime, 4.0), strike - 4.0, level)
    for j, t in enumerate(HUSHDEEP_LAPS):
        mix.put('lake', lake_lap(j), t, 0.16)
    return mix, dict(room=0.93, damp=0.45, wet=0.8, target=-21.0), 0



# ---------------------------------------------------------------- secret

# A hidden chapel. The tune opens on A5 C6 D6, the fragment secret_hum plays
# near a secret exit, so the level plays the song its hum was hinting at.
SECRET_A = [
    [(0, 1, 81), (1, 1, 84), (2, 1, 86)],     # Dm  A5 C6 D6: the hum
    [(0, 2, 83), (2, 1, 79)],                 # G   B5 G5
    [(0, 1, 81), (1, 1, 77), (2, 1, 74)],     # Dm  A5 F5 D5
    [(0, 1, 76), (1, 1, 79), (2, 1, 83)],     # G   E5 G5 B5
    [(0, 2, 81), (2, 1, 84)],                 # F   A5 C6
    [(0, 2, 79), (2, 1, 76)],                 # C   G5 E5
    [(0, 1, 74), (1, 1, 79), (2, 1, 83)],     # G   D5 G5 B5
    [(0, 3, 81)],                             # Am  A5
]
SECRET_A2 = SECRET_A[:6] + [
    [(0, 1, 79), (1, 1, 83), (2, 1, 88)],     # Em  G5 B5 E6
    [(0, 2, 84), (2, 1, 81)],                 # Am  C6 A5
]
SECRET_B = [
    [(0, 1, 84), (1, 1, 81), (2, 1, 77)],     # F   C6 A5 F5
    [(0, 1, 83), (1, 1, 79), (2, 1, 74)],     # G   B5 G5 D5
    [(0, 2, 79), (2, 1, 76)],                 # Em  G5 E5
    [(0, 3, 81)],                             # Am  A5
    [(0, 1, 77), (1, 1, 81), (2, 1, 84)],     # F   F5 A5 C6
    [(0, 1, 86), (1, 1, 83), (2, 1, 79)],     # G   D6 B5 G5
    [(0, 1, 81), (1, 1, 84), (2, 1, 86)],     # Am  A5 C6 D6: the hum again
    [(0, 1, 88), (1, 1, 86), (2, 1, 84)],     # Am  E6 D6 C6, down to the top
]
SECRET_FORM = (['Dm', 'G', 'Dm', 'G', 'F', 'C', 'G', 'Am'] +
               ['Dm', 'G', 'Dm', 'G', 'F', 'C', 'Em', 'Am'] +
               ['F', 'G', 'Em', 'Am', 'F', 'G', 'Am', 'Am'])
SECRET_TRIAD = {'Dm': (62, 65, 69), 'G': (62, 67, 71), 'F': (60, 65, 69), 'C': (60, 64, 67), 'Am': (60, 64, 69),
                'Em': (59, 64, 67)}
SECRET_ROOT = {'Dm': 50, 'G': 43, 'F': 41, 'C': 48, 'Am': 45, 'Em': 40}
SECRET_SPARKLE = (86, 88, 91, 93, 96, 98)      # D6 E6 G6 A6 C7 D7


def secret():
    b = 60.0 / 96.0
    bar = 3 * b
    form = SECRET_FORM
    mix = Loop(len(form) * bar, tail=6.0)
    for name, send in (('box', 0.5), ('waltz', 0.4), ('celesta', 0.55), ('choir', 0.7), ('organ', 0.5),
                       ('sparkle', 0.8)):
        mix.stem(name, send)
    hum = random.Random(71)
    for n, chord in enumerate(form):
        t0 = n * bar
        section = n // 8                 # 0 A, 1 A', 2 B
        k = n % 8
        tune = (SECRET_A, SECRET_A2, SECRET_B)[section][k]
        # The tune on the music box, a little unsteady like a real one; the
        # celesta takes it in B, the box ringing a harmony under it.
        if section < 2:
            line(mix, 'box', tune, t0, b, lambda m, d: music_box(m), 0.32, hum, 0.006,
                 accent=lambda s: 1.0 if s == 0 else 0.85)
            if section == 1:
                line(mix, 'celesta', tune, t0 + 0.012, b, lambda m, d: celesta(m - 12), 0.12)
        else:
            line(mix, 'celesta', tune, t0, b, lambda m, d: celesta(m), 0.26, hum, 0.004)
            under = harmony(tune, [(chord, 0.0, 3.0)], SECRET_TRIAD)
            line(mix, 'box', under, t0 + 0.01, b, lambda m, d: music_box(m), 0.14)
        # Oom-pah-pah on the low teeth.
        mix.put('waltz', music_box(SECRET_ROOT[chord] + 12), t0 + hum.uniform(0.0, 0.005), 0.2)
        for beat in (1, 2):
            for m in SECRET_TRIAD[chord][1:]:
                mix.put('waltz', music_box(m), t0 + beat * b + hum.uniform(-0.004, 0.004), 0.075)
        # A soft organ under it all; the choir hums from the second verse.
        root = SECRET_ROOT[chord]
        for m in (root, root + 7, root + 12):
            mix.put('organ', organ(m, bar + 0.15, 'flute', 0.5, 0.9), t0, 0.035)
        if section >= 1:
            for m in SECRET_TRIAD[chord]:
                mix.put('choir', choir(m, bar + 0.4, 0.7, 1.0, 'oo'), t0, 0.075 if section == 1 else 0.09)
        # Sparkle: a few high chimes off the beat, like dust in a sunbeam.
        if section >= 1 or k % 2 == 1:
            for j in range(hum.choice((1, 2))):
                at = t0 + (hum.randint(0, 5) + 0.5) * b / 2
                mix.put('sparkle', celesta(hum.choice(SECRET_SPARKLE)), at, 0.07 * hum.uniform(0.6, 1.0))
    return mix, dict(room=0.88, damp=0.35, wet=0.75), 96



# ---------------------------------------------------------------- trial (P1)

TRIAL_A = [
    [(0, .5, 74), (.5, .5, 77), (1, .5, 81), (1.5, .5, 77), (2, 1, 86), (3, .5, 84), (3.5, .5, 81)],   # Dm
    [(0, .5, 79), (.5, .5, 76), (1, .5, 72), (1.5, .5, 76), (2, 1, 79), (3, 1, 84)],                    # C
    [(0, .5, 82), (.5, .5, 81), (1, .5, 79), (1.5, .5, 77), (2, 1, 74), (3, 1, 77)],                    # Bb
    [(0, 1.5, 76), (1.5, .5, 72), (2, 2, 69)],                                                          # Am
    [(0, .5, 74), (.5, .5, 77), (1, .5, 81), (1.5, .5, 77), (2, 1, 86), (3, .5, 84), (3.5, .5, 81)],   # Dm
    [(0, .5, 79), (.5, .5, 84), (1, .5, 88), (1.5, .5, 84), (2, 1, 86), (3, 1, 84)],                    # C
    [(0, .5, 82), (.5, .5, 79), (1, .5, 74), (1.5, .5, 79), (2, 1, 82), (3, 1, 81)],                    # Gm
    [(0, 2, 81), (2, .5, 79), (2.5, .5, 77), (3, .5, 76), (3.5, .5, 72)],                               # Am
]
TRIAL_B = [   # the quarter chime, run in eighths like a timer
    [(0, .5, 74), (.5, .5, 77), (1, .5, 79), (1.5, .5, 81), (2, 2, 82)],                                # Bb
    [(0, .5, 76), (.5, .5, 79), (1, .5, 81), (1.5, .5, 84), (2, 2, 86)],                                # C
    [(0, 1, 86), (1, 1, 84), (2, 1, 81), (3, 1, 77)],                                                   # Dm
    [(0, 2, 74), (2, 2, 81)],                                                                           # Dm
    [(0, .5, 74), (.5, .5, 77), (1, .5, 79), (1.5, .5, 81), (2, 2, 82)],                                # Bb
    [(0, .5, 79), (.5, .5, 81), (1, .5, 84), (1.5, .5, 86), (2, 2, 88)],                                # C
    [(0, 1, 88), (1, 1, 84), (2, 1, 81), (3, 1, 76)],                                                   # Am
    [(0, .5, 81), (.5, .5, 79), (1, .5, 77), (1.5, .5, 76), (2, .5, 74), (2.5, .5, 72), (3, 1, 69)],   # Am
]
TRIAL_FORM = ['Dm', 'C', 'Bb', 'Am', 'Dm', 'C', 'Gm', 'Am', 'Bb', 'C', 'Dm', 'Dm', 'Bb', 'C', 'Am', 'Am']
TRIAL_ESC = {'Dm': (62, 69, 74, 69, 77, 69, 74, 69), 'C': (60, 67, 72, 67, 76, 67, 72, 67),
             'Bb': (58, 65, 70, 65, 74, 65, 70, 65), 'Am': (57, 64, 69, 64, 72, 64, 69, 64),
             'Gm': (55, 62, 67, 62, 70, 62, 67, 62)}
TRIAL_ROOT = {'Dm': 38, 'C': 36, 'Bb': 34, 'Am': 33, 'Gm': 31}
TRIAL_PLUCK = {'Dm': (65, 69, 74), 'C': (64, 67, 72), 'Bb': (65, 70, 74), 'Am': (64, 69, 72), 'Gm': (67, 70, 74)}


def trial():
    b = 60.0 / 150.0
    bar = 4 * b
    form = TRIAL_FORM
    mix = Loop(len(form) * bar, tail=4.0)
    for name, send in (('harpsichord', 0.2), ('pluck', 0.25), ('lead', 0.3), ('bass', 0.05), ('clock', 0.05),
                       ('drums', 0.1)):
        mix.stem(name, send)
    hum = random.Random(141)
    for n, chord in enumerate(form):
        t0 = n * bar
        section = n // 8
        k = n % 8
        esc = TRIAL_ESC[chord]
        for j in range(16):
            mix.put('harpsichord', harpsichord(esc[j % 8], 0.11), t0 + j * b / 4 + hum.uniform(-0.002, 0.002),
                    0.27 * (1.0 if j % 4 == 0 else 0.72) * hum.uniform(0.93, 1.0))
        # Plucks on the off-beats: the chord, short.
        for beat in (0.5, 1.5, 2.5, 3.5):
            for m in TRIAL_PLUCK[chord]:
                mix.put('pluck', harpsichord(m + 12, 0.06), t0 + beat * b, 0.1)
        r = TRIAL_ROOT[chord]
        for j in range(8):
            m = r + (12 if j % 2 else 0) + 12
            mix.put('bass', organ(m, 0.17, 'pedal', 0.006, 0.05), t0 + j * b / 2, 0.26 if j % 4 == 0 else 0.2)
        line(mix, 'lead', (TRIAL_A, TRIAL_B)[section][k], t0, b, lambda m, d: lead(m, d - 0.03), 0.26)
        for j in range(8):
            if j % 2 == 0:
                mix.put('clock', clock_tick(3520.0 if (j // 2) % 2 == 0 else 2350.0, j), t0 + j * b / 2, 0.3)
            else:
                mix.put('clock', clock_tick(0.0, j), t0 + j * b / 2, 0.12)
        for beat in ((0, 2) if section == 0 else (0, 1.5, 2)):
            mix.put('drums', kick(), t0 + beat * b, 0.4)
        for beat in (1, 3):
            mix.put('drums', snap(), t0 + beat * b, 0.14)
        if section == 1:
            for beat in (0.5, 1.5, 2.5, 3.5):
                mix.put('drums', tambourine(int(beat * 2) % 3), t0 + beat * b + hum.uniform(-0.002, 0.002), 0.1)
        if k == 7:
            mix.put('drums', swell(bar, 150 + n), t0, 0.26)
    return mix, dict(room=0.78, damp=0.3, wet=0.75), 150


# ---------------------------------------------------------------- descent (P1, stems)

# Endless Descent: three stems a floor deep. descent_floor always (the
# harpsichord's ostinato, the organ, a recorder's long counter-line),
# descent_drive from depth 10 (kick, tambourine, the pulse lead's tune),
# descent_deep from 25 (a low choir, reversed bells, a drone); from depth 40
# the drive drops 6 dB and the deep leads, 2 dB up (Sfx.set_stem does it).
# The floor plays 2.5 dB up while it's alone and 1.5 up with the drive, so
# every depth is as loud as the other cues (check_music.py's stages).
DESCENT_TUNE = [
    [(0, 1.5, 74), (1.5, .5, 77), (2, 1, 81), (3, 1, 79)],       # Dm  D5. F5 A5 G5
    [(0, 2, 77), (2, 1, 74), (3, 1, 70)],                        # Bb  F5 D5 Bb4
    [(0, 1.5, 79), (1.5, .5, 77), (2, 1, 74), (3, 1, 79)],       # Gm  G5. F5 D5 G5
    [(0, 3, 76), (3, 1, 72)],                                    # Am  E5 C5
    [(0, 1.5, 74), (1.5, .5, 77), (2, 1, 81), (3, 1, 86)],       # Dm  D5. F5 A5 D6
    [(0, 2, 84), (2, 1, 82), (3, 1, 81)],                        # Bb  C6 Bb5 A5
    [(0, 1.5, 79), (1.5, .5, 76), (2, 1, 72), (3, 1, 76)],       # C   G5. E5 C5 E5
    [(0, 4, 81)],                                                # Am  A5
]
DESCENT_FORM = ['Dm', 'Bb', 'Gm', 'Am', 'Dm', 'Bb', 'C', 'Am'] * 3
DESCENT_ESC = {'Dm': (50, 57, 62, 57, 65, 57, 62, 57), 'Bb': (46, 53, 58, 53, 62, 53, 58, 53),
               'Gm': (43, 50, 55, 50, 58, 50, 55, 50), 'Am': (45, 52, 57, 52, 60, 52, 57, 52),
               'C': (48, 55, 60, 55, 64, 55, 60, 55)}
DESCENT_PAD = {'Dm': (62, 65, 69), 'Bb': (62, 65, 70), 'Gm': (62, 67, 70), 'Am': (60, 64, 69), 'C': (60, 64, 67)}
DESCENT_COUNTER = {'Dm': 77, 'Bb': 74, 'Gm': 74, 'Am': 76, 'C': 76}
DESCENT_STEMS = {'descent_floor': ['harpsichord', 'organ', 'recorder'], 'descent_drive': ['drums', 'lead'],
                 'descent_deep': ['choir', 'bells', 'drone']}


def descent():
    b = 0.6                          # 100 BPM
    bar = 4 * b
    form = DESCENT_FORM
    L = len(form) * bar
    mix = Loop(L, tail=6.0)
    for name, send in (('harpsichord', 0.25), ('organ', 0.45), ('recorder', 0.4), ('drums', 0.1), ('lead', 0.3),
                       ('choir', 0.6), ('bells', 0.85), ('drone', 0.3)):
        mix.stem(name, send)
    hum = random.Random(151)
    for n, chord in enumerate(form):
        t0 = n * bar
        rep = n // 8                 # three times round, a little different each time
        k = n % 8
        esc = DESCENT_ESC[chord]
        for j in range(8):
            mix.put('harpsichord', harpsichord(esc[j] + 12, 0.28), t0 + j * b / 2 + hum.uniform(-0.003, 0.003),
                    0.36 * (1.0 if j % 4 == 0 else 0.75) * hum.uniform(0.92, 1.0))
        for m in DESCENT_PAD[chord]:
            mix.put('organ', organ(m, bar - 0.05, 'principal', 0.1, 0.3), t0, 0.05)
        mix.put('organ', organ(esc[0] + 12, bar - 0.05, 'pedal', 0.1, 0.3), t0, 0.1)
        # The floor's own voice: a recorder holding a counter-line, so the
        # first floors aren't bare. Its pickup into the next held note is that
        # note the first time round, a step of the scale above it the second
        # and a step below it the third.
        if k % 2 == 0:
            mix.put('recorder', flute(DESCENT_COUNTER[chord], 2 * bar - 0.1), t0, 0.16)
        else:
            nxt = DESCENT_COUNTER[form[(n + 1) % len(form)]]
            pick = scale_step(nxt, (0, 1, -1)[rep], 'aeolian')
            mix.put('recorder', flute(pick, b * 0.9), t0 + 3 * b, 0.08)
        # The drive.
        shift = 12 if rep == 2 and k < 4 else 0
        line(mix, 'lead', DESCENT_TUNE[k], t0, b, lambda m, d: lead(m + shift, d - 0.03), 0.26)
        for beat in (0, 2) if k % 2 == 0 else (0, 1.5, 2):
            mix.put('drums', kick(), t0 + beat * b, 0.42)
        for beat in (1, 3):
            mix.put('drums', tambourine(beat % 3), t0 + beat * b + hum.uniform(-0.003, 0.003), 0.14)
            mix.put('drums', snap(), t0 + beat * b, 0.1)
        for j in range(8):
            mix.put('drums', shaker(j % 2), t0 + j * b / 2 + hum.uniform(-0.003, 0.003), 0.05 if j % 2 else 0.035)
        # The deep: the choir low, bells swelling backwards into every fourth bar.
        for m in DESCENT_PAD[chord]:
            mix.put('choir', choir(m - 12, bar + 0.2, 0.4, 0.6, 'oo'), t0, 0.11)
            mix.put('choir', choir(m, bar + 0.2, 0.4, 0.6, 'ah'), t0, 0.04)
        if k % 4 == 3:
            mix.put('bells', rev_bell(50, 2 * bar), t0 + bar - 2 * bar, 0.3)
            mix.put('bells', rev_bell(57, 2 * bar), t0 + bar - 2 * bar, 0.22)
    mix.put('drone', reedy_drone(38, L, 0.08, [(3, 0.3, 0.0), (8, 0.1, 1.0)], detune=6, top=1800.0), 0.0)
    # The floor plays alone for the first nine depths: it carries most of the
    # weight, and the deep is strong enough to lead once the drive drops.
    faders(mix, {'harpsichord': 1.35, 'organ': 1.35, 'recorder': 1.35, 'choir': 1.4, 'bells': 1.4, 'drone': 1.4})
    return mix, dict(room=0.84, damp=0.35, wet=0.85), 100, DESCENT_STEMS, {}



# ---------------------------------------------------------------- the beds (P2)

# The ambience beds: 12 s loops on the Ambience bus, rendered at -30 LUFS
# (12 dB under the music). No clocks in them: a bed isn't kept in step.

def amb_orchard():
    L = 12.0
    mix = Loop(L, tail=4.0)
    mix.stem('wind', 0.2)
    mix.stem('chimes', 0.9)
    mix.put('wind', wind_loop(L, 181, 500.0, 1800.0, 1, 0.8, ((2, 0.4, 0.3), (5, 0.15, 1.0))), 0.0, 0.5)
    for at, m, g in ((1.3, 93, 0.3), (1.52, 89, 0.22), (5.8, 91, 0.26), (8.9, 86, 0.3), (9.07, 93, 0.2)):
        mix.put('chimes', bone_chime(m), at, g)
    return mix, dict(room=0.9, damp=0.4, wet=0.9, target=-30.0), 0


def amb_carillon():
    L = 12.0
    mix = Loop(L, tail=4.0)
    mix.stem('wind', 0.2)
    mix.stem('works', 0.6)
    mix.put('wind', wind_loop(L, 183, 700.0, 2400.0, 1, 2.2, ((3, 0.35, 0.0),)), 0.0, 0.45)
    # Far off in the works: a gear's clunk now and then, a spring creaking.
    for at, v, g in ((2.1, 1, 0.3), (2.37, 1, 0.18), (7.4, 1, 0.26), (10.2, 0, 0.12)):
        mix.put('works', lowpass(woodblock(v), 1400.0), at, g)
    mix.put('works', ratchet(5, 0.9, 190), 4.6, 0.1)
    return mix, dict(room=0.9, damp=0.3, wet=0.9, target=-30.0), 0


def amb_sanctum():
    L = 12.0
    mix = Loop(L, tail=4.0)
    mix.stem('wind', 0.2)
    mix.stem('glass', 0.8)
    mix.put('wind', wind_loop(L, 185, 300.0, 1200.0, 1, 1.2, ((2, 0.4, 0.8),)), 0.0, 0.45)
    # The glass still humming with the old light: D6 and A6, beating slowly.
    mix.put('glass', drone(86, L, [1.0, 0.2], 0.05, [(1, 0.5, 0.0)], detune=2), 0.0)
    mix.put('glass', drone(93, L, [1.0], 0.03, [(2, 0.6, 1.5)], detune=3), 0.0)
    for at, m, g in ((3.3, 98, 0.12), (3.45, 93, 0.09), (9.6, 96, 0.1)):
        mix.put('glass', celesta(m), at, g)
    return mix, dict(room=0.9, damp=0.3, wet=0.9, target=-30.0), 0


def amb_hushdeep():
    L = 12.0
    mix = Loop(L, tail=4.0)
    mix.stem('lake', 0.3)
    mix.stem('air', 0.3)
    for j, at in enumerate((0.8, 3.1, 5.9, 8.2, 10.4)):
        mix.put('lake', lake_lap(20 + j), at, 0.4)
    mix.put('air', breath_loop(L, 187, 900.0, 0.9, ((1, 0.6, 0.0), (3, 0.2, 1.0))), 0.0, 0.12)
    return mix, dict(room=0.92, damp=0.45, wet=0.7, target=-30.0), 0


TRACKS = {'orchard': orchard, 'carillon': carillon, 'sanctum': sanctum, 'hushdeep': hushdeep, 'secret': secret,
          'trial': trial, 'amb_orchard': amb_orchard, 'amb_carillon': amb_carillon, 'amb_sanctum': amb_sanctum,
          'amb_hushdeep': amb_hushdeep}
STEM_SETS = {'descent': descent}

# Each track's mode, for check_music.py, which runs every maker with its
# voices stubbed out and checks every note it puts in the mix against it.
# The beds are their worlds' (None: a bed of noise, with no note in it).
# FREE: the parts left out on purpose (hushdeep's reversed bells, whose Eb
# is the Hush's, as in hush_final's void).
MODES = {'orchard': 'dorian', 'carillon': 'aeolian', 'sanctum': 'dorian', 'hushdeep': 'aeolian', 'secret': 'dorian',
         'trial': 'aeolian', 'descent': 'aeolian', 'amb_orchard': 'dorian', 'amb_carillon': None,
         'amb_sanctum': 'dorian', 'amb_hushdeep': None}
FREE = {'hushdeep': ('bells',)}
