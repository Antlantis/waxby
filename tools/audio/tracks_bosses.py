"""WAXBY v3's boss and ending music, rendered by tools/audio/music.py.

  rootmother  D Dorian with a Phrygian bridge (Eb, Bb), 6/8, dotted quarter
              138, 48 bars (42 s): Mother Gravebough. A fast bone-marimba
              ostinato, log drums and war kicks, the hurdy's drone growling on
              every beat; the orchard's sixth on the hurdy, bent Phrygian in
              the bridge (D up to Bb), where a low choir chants.
  tinker      D Aeolian, 4/4, 132 BPM, 32 bars (58 s): the Tinker of Hours. A
              hammering harpsichord, a sour organ grinding eighths, the
              quarter chime inverted (D Bb A G / G A Bb D) on the lead, plain
              hunt on six bells, ticks and ratchets, timpani. A breakdown
              winds the spring back to the top. (The engine tape-stops it in
              his time stops.)
  saint       D Phrygian, 3/4, 150 BPM, 36 bars (43 s): the Prism Saint. A
              waltz of fury: the pedal and timpani on one, full organ and choir
              stabs on two and three; the sanctum's leaping fifth with Eb; the
              title motif twice as slow in the choir; celesta runs up the
              Phrygian scale; glass harmonica ringing over it all.
  hush_final  stems, D Aeolian, 4/4, 120 BPM, 32 bars (64 s): the Hush. Five
              stems in step (Sfx plays them as one AudioStreamSynchronized and
              the fight eats them one by one), over i-VII-VI-v (Dm C Bb Am,
              the chords the title tune was written on):
                hush_final_bells  every world's motif on bells, pentatonic
                                  only (the title, the tallow drops, the
                                  orchard's sixth, the quarter chime, the
                                  sanctum's fifth), and rounds; struck at
                                  the pitch written, just under the melody,
                                  so a phone hears them go and come back
                hush_final_choir  organ and choir: the chords
                hush_final_drums  war kicks, timpani, war drums (their slap
                                  lifted, for a phone)
                hush_final_wick   Waxby's own melody: the title tune on music
                                  box and celesta (the fight sets its level
                                  from his flame)
                hush_final_void   the Hush: a D1 + Ab1 tritone drone, beating,
                                  reversed bells swelling into the phrases,
                                  and its breath
              and the pre-mixed stand-ins, should the stems misbehave on the
              phone: hush_final_a (all five), _d (all but the drums: the
              drums are eaten first), _b (void, wick, bells) and _c (void,
              wick), each exactly the sum of its stems (no clipper: the
              stems' gain keeps every sum under the ceiling). The stand-ins
              can't follow the flame (the wick plays at 0 dB in them) or
              bring the bells back a ring at a time.
  lullaby     D major, 4/4, 60 BPM, 16 bars (64 s): the Lull. A music box
              sings A F# D and low bells answer it; a rocking figure on the low
              teeth, a soft organ, a hummed choir from bar 9.

P1:
  evenbell    D major, 4/4, 76 BPM, 32 bars (101 s): homecoming and the
              credits. All six worlds' motifs in D major, four bars each (the
              chapel's title tune, the tallow drops, the orchard's sixth, the
              quarter chime, the sanctum's fifth), then the title melody as
              dawn sang it and the Lull twice, over the tower ringing rounds
              on eight bells and the choir.
P2:
  lament      D Aeolian, 3/4, 60 BPM, 16 bars (48 s), -19 LUFS: the boss-after
              scenes. A solo organ and a choir; the title motif, slowed.
"""

import random

from music import (harpsichord, lead, flute, organ, choir, celesta, bell, rev_bell, war_kick, snap, shaker, timpani,
                   tom, music_box, swell, sour_organ)
from instruments_v3 import (bone_marimba, hurdy, hurdy_drone, slit_drum, glass_harmonica, clock_tick, ratchet,
                            plain_hunt, ring_rows, reedy_drone, breath_loop, line, Loop, faders, presence)


# ---------------------------------------------------------------- rootmother

# Two-bar units of 6/8 in eighths (12 an unit): (start, eighths, midi).
RM_A = [
    [(0, 3, 74), (3, 2, 83), (5, 1, 81), (6, 3, 79), (9, 3, 77)],               # Dm  D5. B5 A5 | G5. F5.
    [(0, 2, 76), (2, 1, 77), (3, 2, 79), (5, 1, 76), (6, 6, 72)],               # C   E5 F5 G5 E5 | C5
    [(0, 3, 74), (3, 2, 83), (5, 1, 86), (6, 3, 83), (9, 3, 79)],               # G   D5. B5 D6 | B5. G5.
    [(0, 1, 74), (1, 1, 69), (2, 1, 74), (3, 2, 77), (5, 1, 81), (6, 6, 74)],   # Dm  the title motif | D5
    [(0, 3, 74), (3, 2, 83), (5, 1, 81), (6, 3, 79), (9, 3, 77)],               # Dm
    [(0, 2, 79), (2, 1, 77), (3, 2, 76), (5, 1, 72), (6, 6, 74)],               # C   G5 F5 E5 C5 | D5
    [(0, 3, 76), (3, 2, 81), (5, 1, 84), (6, 3, 83), (9, 3, 81)],               # Am  E5. A5 C6 | B5. A5.
    [(0, 1, 74), (1, 1, 69), (2, 1, 74), (3, 2, 77), (5, 1, 81), (6, 3, 79), (9, 3, 76)],   # Dm
]
RM_B = [   # the bridge, bent Phrygian: the sixth now D up to Bb
    [(0, 3, 74), (3, 2, 82), (5, 1, 81), (6, 3, 79), (9, 3, 75)],               # Dm  D5. Bb5 A5 | G5. Eb5.
    [(0, 2, 79), (2, 1, 77), (3, 2, 75), (5, 1, 74), (6, 6, 75)],               # Eb  G5 F5 Eb5 D5 | Eb5
    [(0, 3, 74), (3, 2, 82), (5, 1, 86), (6, 3, 82), (9, 3, 81)],               # Dm  D5. Bb5 D6 | Bb5. A5.
    [(0, 2, 79), (2, 1, 75), (3, 2, 72), (5, 1, 75), (6, 6, 79)],               # Cm  G5 Eb5 C5 Eb5 | G5
    [(0, 3, 77), (3, 3, 82), (6, 3, 81), (9, 3, 77)],                           # Bb  F5. Bb5. | A5. F5.
    [(0, 2, 79), (2, 1, 82), (3, 3, 87), (6, 3, 86), (9, 3, 82)],               # Eb  G5 Bb5 Eb6. | D6. Bb5.
    [(0, 1, 74), (1, 1, 69), (2, 1, 74), (3, 2, 75), (5, 1, 74), (6, 6, 69)],   # Dm  D5 A4 D5 Eb5 D5 | A4
    [(0, 3, 75), (3, 3, 79), (6, 3, 82), (9, 3, 86)],                           # Eb  Eb5. G5. | Bb5. D6.
]
RM_FORM_A = ['Dm', 'Dm', 'C', 'C', 'G', 'G', 'Dm', 'Dm', 'Dm', 'Dm', 'C', 'C', 'Am', 'Am', 'Dm', 'Dm']
RM_FORM_B = ['Dm', 'Dm', 'Eb', 'Eb', 'Dm', 'Dm', 'Cm', 'Cm', 'Bb', 'Bb', 'Eb', 'Eb', 'Dm', 'Dm', 'Eb', 'Eb']
RM_FORM = RM_FORM_A + RM_FORM_B + RM_FORM_A
RM_BAR = 6 * 60.0 / 138.0 / 3.0    # a 6/8 bar at dotted quarter 138
# The marimba's figure: root, octave, fifth, root, tenth, fifth.
RM_OST = {'Dm': (62, 74, 69, 62, 77, 69), 'C': (60, 72, 67, 60, 76, 67), 'G': (55, 67, 62, 55, 71, 62),
          'Am': (57, 69, 64, 57, 72, 64), 'Eb': (63, 75, 70, 63, 79, 70), 'Cm': (60, 72, 67, 60, 75, 67),
          'Bb': (58, 70, 65, 58, 74, 65)}
RM_CHANT = {'Dm': (62, 65, 69), 'Eb': (63, 67, 70), 'Cm': (60, 63, 67), 'Bb': (58, 62, 65), 'C': (60, 64, 67),
            'G': (59, 62, 67), 'Am': (57, 60, 64)}
RM_SLIT_A = ((1, 62), (2, 69), (4, 62), (5, 67))
RM_SLIT_B = ((1, 62), (2, 63), (4, 62), (5, 60))


def rootmother():
    e = 60.0 / 138.0 / 3.0         # an eighth (the dotted quarter is 138 BPM)
    bar = 6 * e
    form = RM_FORM
    mix = Loop(len(form) * bar, tail=5.0)
    for name, send in (('marimba', 0.18), ('growl', 0.15), ('hurdy', 0.25), ('lead', 0.3), ('choir', 0.55),
                       ('drums', 0.12)):
        mix.stem(name, send)
    hum = random.Random(81)
    L = len(form) * bar
    buzz = []
    for n, chord in enumerate(form):
        t0 = n * bar
        section = n // 16              # 0 A, 1 B (the bridge), 2 A'
        k = n % 16
        # The marimba, fast and hard.
        for j, m in enumerate(RM_OST[chord]):
            accent = (1.0, 0.7, 0.75, 0.9, 0.7, 0.75)[j]
            mix.put('marimba', bone_marimba(m, 0.85), t0 + j * e + hum.uniform(-0.003, 0.003),
                    0.28 * accent * hum.uniform(0.92, 1.0))
        buzz += [t0, t0 + 3 * e]
        # The tune, a two-bar unit at a time.
        if k % 2 == 0:
            unit = (RM_A, RM_B, RM_A)[section][k // 2]
            line(mix, 'hurdy', unit, t0, e, lambda m, d: hurdy(m - 12, d - 0.02, 0.08), 0.22)
            if section >= 1:
                line(mix, 'lead', unit, t0, e, lambda m, d: lead(m, d - 0.02), 0.12 if section == 1 else 0.15)
        # The low choir chants the bridge; it holds the chords in A'.
        if section == 1 and k % 2 == 0:
            for m in RM_CHANT[chord]:
                mix.put('choir', choir(m - 12, 2 * bar, 0.08, 0.3, 'oo'), t0, 0.1)
                mix.put('choir', choir(m, 2 * bar, 0.08, 0.3, 'ah'), t0, 0.07)
        if section == 2 and k % 2 == 0:
            for m in RM_CHANT[chord]:
                mix.put('choir', choir(m, 2 * bar, 0.2, 0.4, 'ah'), t0, 0.06)
        # Log drums and war kicks.
        mix.put('drums', war_kick(), t0, 0.42)
        if section == 2:
            mix.put('drums', war_kick(), t0 + 3 * e, 0.3)
        toms = {0: (3,), 1: (2, 3, 5), 2: (3, 4, 5)}[section]
        for j in toms:
            mix.put('drums', tom(0.9), t0 + j * e + hum.uniform(-0.002, 0.002), 0.34 if j == 3 else 0.22)
        for j, m in (RM_SLIT_B if section == 1 else RM_SLIT_A):
            mix.put('drums', slit_drum(m, 0.7), t0 + j * e + hum.uniform(-0.002, 0.002), 0.18)
        if section == 2:
            for j in range(6):
                mix.put('drums', shaker(j % 2), t0 + j * e, 0.05 if j % 3 == 0 else 0.03)
        if k == 15:
            for j in range(6):
                mix.put('drums', tom(0.9), t0 + j * e, 0.14 + 0.05 * j)
            mix.put('drums', swell(bar, 90 + n), t0, 0.3)
    # The hurdy's drone growling on every beat.
    mix.put('growl', hurdy_drone(L, (50, 57), 0.08, buzz, 0.22, 0.55, seed=5), 0.0)
    return mix, dict(room=0.8, damp=0.35, wet=0.85), 138


# ---------------------------------------------------------------- tinker

# The quarter chime inverted, per 4/4 bar in beats.
TK_A = [
    [(0, 1, 74), (1, 1, 70), (2, 1, 69), (3, 1, 67)],          # Dm  D5 Bb4 A4 G4
    [(0, 1, 67), (1, 1, 69), (2, 1, 70), (3, 1, 74)],          # Bb  G4 A4 Bb4 D5
    [(0, 1.5, 76), (1.5, .5, 74), (2, 1, 72), (3, 1, 67)],     # C   E5. D5 C5 G4
    [(0, 2, 69), (2, 1, 72), (3, 1, 76)],                      # Am  A4 C5 E5
    [(0, 1, 86), (1, 1, 82), (2, 1, 81), (3, 1, 79)],          # Dm  D6 Bb5 A5 G5: from above
    [(0, 1, 79), (1, 1, 81), (2, 1, 82), (3, 1, 86)],          # Bb  G5 A5 Bb5 D6
    [(0, 1.5, 84), (1.5, .5, 82), (2, 1, 81), (3, 1, 79)],     # Gm  C6. Bb5 A5 G5
    [(0, 2, 81), (2, 2, 76)],                                  # Am  A5 E5
]
TK_FORM = (['Dm', 'Bb', 'C', 'Am', 'Dm', 'Bb', 'Gm', 'Am'] +      # A  the hammering, the chime inverted
           ['Dm', 'Dm', 'C', 'C', 'Bb', 'Bb', 'Am', 'Am'] +       # B  plain hunt, fast
           ['Dm', 'Bb', 'C', 'Am', 'Dm', 'Bb', 'Gm', 'Am'] +      # C  all of it
           ['Dm', 'Dm', 'Dm', 'Dm', 'Bb', 'Bb', 'Am', 'Am'])      # D  the clock alone, winding back up
TK_HAMMER = {'Dm': (74, 62, 69, 62, 77, 62, 69, 62), 'Bb': (70, 58, 65, 58, 74, 58, 65, 58),
             'C': (72, 60, 67, 60, 76, 60, 67, 60), 'Am': (69, 57, 64, 57, 72, 57, 64, 57),
             'Gm': (67, 55, 62, 55, 70, 55, 62, 55)}
TK_ROOT = {'Dm': 50, 'Bb': 46, 'C': 48, 'Am': 45, 'Gm': 43}
TK_GRIND = (0, 0, 12, 0, 7, 0, 12, 0)
TK_BELLS = (74, 72, 69, 67, 65, 62)


def tinker():
    b = 60.0 / 132.0
    bar = 4 * b
    form = TK_FORM
    mix = Loop(len(form) * bar, tail=5.0)
    for name, send in (('harpsichord', 0.2), ('organ', 0.25), ('lead', 0.28), ('bells', 0.55), ('clock', 0.05),
                       ('drums', 0.1)):
        mix.stem(name, send)
    hum = random.Random(91)
    L = len(form) * bar
    hunt = plain_hunt(6)
    rows = [hunt[0], hunt[0]] + hunt[1:13] + [hunt[0], hunt[0]]
    for n, chord in enumerate(form):
        t0 = n * bar
        section = n // 8               # 0 A, 1 B, 2 C, 3 D
        k = n % 8
        # The harpsichord hammering sixteenths (eighths under the ringing,
        # the bare pulse in the breakdown).
        pat = TK_HAMMER[chord]
        steps = {0: 4, 1: 2, 2: 4, 3: 1}[section]
        for j in range(4 * steps):
            m = pat[j % 8] if steps == 4 else pat[(j * 8 // (4 * steps)) % 8]
            accent = 1.0 if j % steps == 0 else 0.7
            mix.put('harpsichord', harpsichord(m, 0.12 if steps == 4 else 0.25), t0 + j * b / steps + hum.uniform(-0.002, 0.002),
                    0.3 * accent * hum.uniform(0.93, 1.0))
        # The sour organ grinding eighths on the root; held in the breakdown.
        r = TK_ROOT[chord] + 12
        if section == 3:
            mix.put('organ', sour_organ(r, bar - 0.05, 0.1, 0.2), t0, 0.12)
        else:
            for j in range(8):
                mix.put('organ', sour_organ(r + TK_GRIND[j], 0.16, 0.004, 0.05), t0 + j * b / 2,
                        (0.13 if section != 1 else 0.1) * (1.0, 0.6, 0.8, 0.6, 0.9, 0.6, 0.8, 0.65)[j])
        # The tune: the lead in A and C (a celesta over it in C); in the
        # breakdown the celesta keeps only its first notes.
        if section in (0, 2):
            line(mix, 'lead', TK_A[k], t0, b, lambda m, d: lead(m, d - 0.03), 0.22)
            if section == 2:
                line(mix, 'lead', TK_A[k], t0, b, lambda m, d: celesta(m + 12), 0.14)
        elif section == 3 and k < 4:
            line(mix, 'lead', TK_A[k][:2], t0, b, lambda m, d: celesta(m + 12), 0.2)
        # The clock: tick-tock on the beats, a faint tick between.
        for j in range(8):
            t = t0 + j * b / 2
            if j % 2 == 0:
                mix.put('clock', clock_tick(3520.0 if (j // 2) % 2 == 0 else 2350.0, j), t, 0.32)
            else:
                mix.put('clock', clock_tick(0.0, j), t, 0.1)
        # Drums: timpani and war drums; the kick joins in C.
        drum = 45 if chord == 'Am' else 50
        if section in (0, 2):
            for beat in (0, 2):
                mix.put('drums', timpani(drum, 1.0), t0 + beat * b, 0.4 if beat == 0 else 0.3)
            for beat in (1, 3):
                mix.put('drums', tom(0.8), t0 + beat * b + hum.uniform(-0.002, 0.002), 0.3)
            if section == 2:
                for beat in (0, 1.5, 2):
                    mix.put('drums', war_kick(), t0 + beat * b, 0.34)
        elif section == 1:
            mix.put('drums', timpani(drum, 1.0), t0, 0.38)
            mix.put('drums', tom(0.8), t0 + 2 * b, 0.3)
        else:
            mix.put('drums', timpani(drum, 1.0), t0, 0.32)
        # A ratchet at the ends of the phrases.
        if section in (0, 2) and k in (3, 7):
            mix.put('clock', ratchet(8, 1.8 * b, 20 + n), t0 + 2 * b, 0.14)
    # Plain hunt on six bells, fast (two rows a bar), in B; again, lower, in C.
    ring_rows(mix, 'bells', rows, 8 * bar, b / 3, TK_BELLS, 0.2, 1.0, hum, 0.003,
              strike=lambda bell_no, place: 0.8 + 0.07 * bell_no)
    ring_rows(mix, 'bells', rows, 16 * bar, b / 3, TK_BELLS, 0.1, 1.0, hum, 0.003)
    # The breakdown's last two bars: the spring wound, the timpani rolling back in.
    mix.put('clock', ratchet(22, 7.5 * b, 60), L - 2 * bar, 0.2)
    for j in range(16):
        mix.put('drums', timpani(50 if j % 2 else 45, 1.0), L - bar + j * b / 4, 0.1 + 0.25 * j / 16)
    return mix, dict(room=0.8, damp=0.3, wet=0.85), 132


# ---------------------------------------------------------------- saint

# The sanctum's leaping fifth, gone Phrygian: per 3/4 bar in beats.
SAINT_A = [
    [(0, 1, 74), (1, 2, 81)],                  # Dm  D5 A5, the leap
    [(0, 1, 82), (1, 1, 81), (2, 1, 79)],      # Dm  Bb5 A5 G5
    [(0, 2, 79), (2, 1, 75)],                  # Eb  G5 Eb5
    [(0, 3, 82)],                              # Eb  Bb5
    [(0, 1, 74), (1, 2, 81)],                  # Dm
    [(0, 1, 86), (1, 1, 84), (2, 1, 82)],      # Dm  D6 C6 Bb5
    [(0, 2, 84), (2, 1, 79)],                  # Cm  C6 G5
    [(0, 1, 75), (1, 1, 79), (2, 1, 84)],      # Cm  Eb5 G5 C6
    [(0, 2, 86), (2, 1, 82)],                  # Bb  D6 Bb5
    [(0, 1, 81), (1, 1, 79), (2, 1, 77)],      # Bb  A5 G5 F5
    [(0, 2, 75), (2, 1, 79)],                  # Eb  Eb5 G5
    [(0, 1, 79), (1, 1, 77), (2, 1, 75)],      # Eb  G5 F5 Eb5, falling to D
]
SAINT_B = [   # the title motif twice as slow, Phrygian (its E is Eb)
    [(0, 3, 74)], [(0, 1, 69), (1, 1, 74), (2, 1, 77)], [(0, 3, 81)], [(0, 1, 81), (1, 1, 79), (2, 1, 77)],
    [(0, 3, 75)], [(0, 1, 72), (1, 1, 75), (2, 1, 79)], [(0, 3, 84)], [(0, 1, 84), (1, 1, 82), (2, 1, 79)],
    [(0, 3, 74)], [(0, 1, 77), (1, 1, 79), (2, 1, 82)], [(0, 3, 79)], [(0, 1, 77), (1, 1, 75), (2, 1, 74)],
]
SAINT_FORM = (['Dm', 'Dm', 'Eb', 'Eb', 'Dm', 'Dm', 'Cm', 'Cm', 'Bb', 'Bb', 'Eb', 'Eb'] +
              ['Gm', 'Gm', 'Dm', 'Dm', 'Eb', 'Eb', 'Cm', 'Cm', 'Bb', 'Bb', 'Eb', 'Eb'] +
              ['Dm', 'Dm', 'Eb', 'Eb', 'Dm', 'Dm', 'Cm', 'Cm', 'Bb', 'Bb', 'Eb', 'Eb'])
SAINT_STAB = {'Dm': (62, 65, 69, 74), 'Eb': (63, 67, 70, 75), 'Cm': (60, 63, 67, 72), 'Bb': (62, 65, 70, 74),
              'Gm': (62, 67, 70, 74)}
SAINT_ROOT = {'Dm': 38, 'Eb': 39, 'Cm': 36, 'Bb': 34, 'Gm': 31}
SAINT_GLASS = {'Dm': 81, 'Eb': 82, 'Cm': 79, 'Bb': 77, 'Gm': 74}
SAINT_SCALE = (74, 75, 77, 79, 81, 82, 84, 86, 87, 89, 91, 93)     # D5 Eb5 F5 G5 A5 Bb5 C6 D6 ...


def saint():
    b = 60.0 / 150.0
    bar = 3 * b
    form = SAINT_FORM
    mix = Loop(len(form) * bar, tail=5.0)
    for name, send in (('organ', 0.3), ('choir', 0.5), ('glass', 0.55), ('lead', 0.3), ('celesta', 0.45),
                       ('drums', 0.12)):
        mix.stem(name, send)
    hum = random.Random(101)
    for n, chord in enumerate(form):
        t0 = n * bar
        section = n // 12              # 0 A, 1 B, 2 C
        k = n % 12
        stab = SAINT_STAB[chord]
        # The waltz: the pedal on one, the full organ stabbing two and three,
        # the choir stabbing with it from B on.
        r = SAINT_ROOT[chord]
        mix.put('organ', organ(r + 12, b * 0.9, 'pedal', 0.01, 0.1), t0, 0.26)
        mix.put('organ', organ(r + 24, b * 0.9, 'principal', 0.01, 0.1), t0, 0.1)
        for beat in (1, 2):
            for m in stab:
                mix.put('organ', organ(m, 0.16, 'full', 0.005, 0.06), t0 + beat * b, 0.12 if beat == 1 else 0.1)
            if section >= 1:
                for m in stab[1:]:
                    mix.put('choir', choir(m, 0.18, 0.015, 0.14, 'ah'), t0 + beat * b, 0.07)
        # The glass harmonica rings the chord's fifth high over it all.
        if k % 2 == 0:
            g = SAINT_GLASS[chord]
            mix.put('glass', glass_harmonica(g, 2 * bar - 0.1, 0.2, 0.5), t0, 0.1)
            mix.put('glass', glass_harmonica(g + 12, 2 * bar - 0.1, 0.2, 0.5), t0, 0.05)
        # The tunes.
        if section == 0:
            line(mix, 'lead', SAINT_A[k], t0, b, lambda m, d: lead(m, d - 0.03), 0.26)
            if k % 2 == 0:
                for m in stab[1:]:
                    mix.put('choir', choir(m, 2 * bar, 0.3, 0.4, 'ah'), t0, 0.05)
        elif section == 1:
            line(mix, 'choir', SAINT_B[k], t0, b, lambda m, d: choir(m, d, 0.06, 0.3, 'ah'), 0.26)
            line(mix, 'choir', SAINT_B[k], t0, b, lambda m, d: choir(m - 12, d, 0.06, 0.3, 'ah'), 0.12)
        else:
            line(mix, 'lead', SAINT_A[k], t0, b, lambda m, d: lead(m, d - 0.03), 0.24)
            line(mix, 'lead', SAINT_A[k], t0, b, lambda m, d: lead(m - 12, d - 0.03), 0.1)
            # Celesta runs up the Phrygian scale into every other downbeat.
            if k % 2 == 1:
                top = SAINT_STAB[form[(n + 1) % len(form)]][-1] + 12
                start = max(i for i, m in enumerate(SAINT_SCALE) if m <= top) - 3
                for j in range(4):
                    m = SAINT_SCALE[max(0, start + j)]
                    mix.put('celesta', celesta(m), t0 + (2 + j / 4) * b, 0.12 + 0.03 * j)
        # Drums: timpani and a war kick on one; the war drum on three (on two
        # and three in C); a roll into each section.
        drum = 55 if chord in ('Eb', 'Cm') else 50
        mix.put('drums', timpani(drum, 1.0), t0, 0.4)
        mix.put('drums', war_kick(), t0, 0.36)
        for beat in ((2,) if section < 2 else (1, 2)):
            if section == 0 and k % 2 == 0:
                continue
            mix.put('drums', tom(0.9), t0 + beat * b + hum.uniform(-0.002, 0.002), 0.3)
        if k == 11:
            for j in range(8):
                mix.put('drums', timpani(50, 1.0), t0 + (1 + j / 4) * b, 0.1 + 0.3 * j / 8)
            mix.put('drums', swell(bar, 110 + n), t0, 0.3)
    return mix, dict(room=0.85, damp=0.3, wet=0.9), 150


# ---------------------------------------------------------------- hush_final

# The title tune (the chapel's A and A'), set over Dm C Bb Am: Waxby's own.
WICK_A = [
    [(0, .5, 74), (.5, .5, 69), (1, .5, 74), (1.5, .5, 77), (2, .75, 81), (2.75, .25, 79), (3, .5, 77), (3.5, .5, 76)],
    [(0, .5, 76), (.5, .5, 72), (1, .5, 76), (1.5, .5, 79), (2, 1.0, 84), (3, .5, 82), (3.5, .5, 79)],
    [(0, .5, 77), (.5, .5, 74), (1, .5, 77), (1.5, .5, 82), (2, .75, 81), (2.75, .25, 79), (3, .5, 77), (3.5, .5, 74)],
    [(0, 1.5, 76), (1.5, .5, 72), (2, .5, 76), (2.5, .5, 81), (3, 1.0, 79)],
    [(0, .5, 74), (.5, .5, 69), (1, .5, 74), (1.5, .5, 77), (2, .75, 81), (2.75, .25, 79), (3, .5, 77), (3.5, .5, 76)],
    [(0, .5, 76), (.5, .5, 72), (1, .5, 76), (1.5, .5, 79), (2, 1.0, 84), (3, .5, 82), (3.5, .5, 79)],
    [(0, .5, 74), (.5, .5, 70), (1, .5, 74), (1.5, .5, 79), (2, .75, 82), (2.75, .25, 81), (3, .5, 79), (3.5, .5, 77)],
    [(0, 1.0, 76), (1, .5, 72), (1.5, .5, 76), (2, 2.0, 81)],
]
WICK_A2 = WICK_A[:3] + [
    [(0, .5, 72), (.5, .5, 76), (1, .5, 81), (1.5, .5, 76), (2, 1.0, 84), (3, .5, 81), (3.5, .5, 79)],
    [(0, .5, 81), (.5, .5, 77), (1, .5, 81), (1.5, .5, 86), (2, .75, 84), (2.75, .25, 82), (3, .5, 81), (3.5, .5, 77)],
    [(0, .5, 79), (.5, .5, 76), (1, .5, 79), (1.5, .5, 84), (2, .75, 82), (2.75, .25, 81), (3, .5, 79), (3.5, .5, 76)],
    [(0, .5, 74), (.5, .5, 79), (1, .5, 82), (1.5, .5, 81), (2, .5, 77), (2.5, .5, 74), (3, .5, 77), (3.5, .5, 79)],
    [(0, .5, 77), (.5, .5, 76), (1, 2.5, 74), (3.5, .5, 72)],
]
# Every world's motif on the bells, pentatonic only, a four-bar phrase each
# (None: the phrase rings rounds).
HF_BELLS = [
    [[(0, 1.5, 74), (1.5, .5, 69), (2, 1, 74), (3, 1, 77)], [(0, 2, 81), (2, 1, 79), (3, 1, 77)],
     [(0, 2, 77), (2, 2, 74)], [(0, 2, 72), (2, 2, 69)]],                                   # the title
    [[(0, 1, 86), (1, 1, 84), (2, 2, 81)], [(0, 1, 84), (1, 1, 81), (2, 2, 79)],
     [(0, 1, 77), (1, 1, 74), (2, 2, 77)], [(0, 4, 81)]],                                   # the tallow drops
    [[(0, 1.5, 69), (1.5, .5, 77), (2, 1, 74), (3, 1, 72)], [(0, 2, 79), (2, 2, 72)],
     [(0, 2, 77), (2, 2, 74)], [(0, 2, 69), (2, 2, 72)]],                                   # the orchard's sixth
    [[(0, 1, 74), (1, 1, 77), (2, 1, 79), (3, 1, 81)], [(0, 1, 81), (1, 1, 79), (2, 1, 77), (3, 1, 74)],
     [(0, 1, 74), (1, 1, 77), (2, 2, 79)], [(0, 1, 81), (1, 1, 79), (2, 2, 72)]],           # the quarter chime
    [[(0, 1, 74), (1, 3, 81)], [(0, 1, 72), (1, 3, 79)], [(0, 1, 65), (1, 3, 72)],
     [(0, 1, 62), (1, 3, 69)]],                                                             # the sanctum's fifth
    None,                                                                                  # rounds
    [[(0, 1.5, 86), (1.5, .5, 81), (2, 1, 86), (3, 1, 89)], [(0, 2, 93), (2, 1, 91), (3, 1, 89)],
     [(0, 2, 89), (2, 2, 86)], [(0, 2, 84), (2, 2, 81)]],                                   # the title, high
    None,                                                                                  # rounds, then the chime
]
HF_ROUNDS = (74, 72, 69, 67, 65, 62)       # D5 C5 A4 G4 F4 D4, the carillon's six
HF_FORM = ['Dm', 'C', 'Bb', 'Am'] * 8
HF_PAD = {'Dm': (62, 65, 69, 74), 'C': (60, 64, 67, 72), 'Bb': (62, 65, 70, 74), 'Am': (60, 64, 69, 72)}
HF_ROOT = {'Dm': 38, 'C': 36, 'Bb': 34, 'Am': 33}
HF_STEMS = {'hush_final_bells': ['bells'], 'hush_final_choir': ['choir', 'organ'], 'hush_final_drums': ['drums'],
            'hush_final_wick': ['wick'], 'hush_final_void': ['void', 'revbells', 'breath']}
HF_PREMIX = {'hush_final_a': ['hush_final_bells', 'hush_final_choir', 'hush_final_drums', 'hush_final_wick',
                              'hush_final_void'],
             'hush_final_d': ['hush_final_bells', 'hush_final_choir', 'hush_final_wick', 'hush_final_void'],
             'hush_final_b': ['hush_final_void', 'hush_final_wick', 'hush_final_bells'],
             'hush_final_c': ['hush_final_void', 'hush_final_wick']}


def hush_final():
    b = 0.5                          # 120 BPM
    bar = 4 * b
    form = HF_FORM
    L = len(form) * bar
    mix = Loop(L, tail=6.0)
    for name, send in (('bells', 0.6), ('choir', 0.6), ('organ', 0.4), ('drums', 0.12), ('wick', 0.4),
                       ('void', 0.25), ('revbells', 0.8), ('breath', 0.3)):
        mix.stem(name, send)
    hum = random.Random(111)
    rounds_rows = [list(range(6))] * 8
    for n, chord in enumerate(form):
        t0 = n * bar
        phrase = n // 4               # eight phrases of four bars
        k = n % 4
        # Bells: a world's motif a phrase, or rounds. They strike at the pitch
        # written, as the rounds do: an octave lower (220-440 Hz) a phone
        # lost them under Waxby's melody (3.9 dB of their loudness), and the
        # finale is their coming back. They move in quarters and halves under
        # the melody's eighths, and ring where it runs.
        motif = HF_BELLS[phrase]
        if motif is not None:
            line(mix, 'bells', motif[k], t0, b, lambda m, d: bell(m - 12, 3.0), 0.34, hum, 0.004)
        elif k == 0:
            rows = rounds_rows if phrase == 5 else rounds_rows[:4]
            ring_rows(mix, 'bells', rows, t0, b / 3, HF_ROUNDS, 0.16, 1.6, hum, 0.004,
                      strike=lambda bell_no, place: 0.75 + 0.06 * bell_no)
        if phrase == 7 and k >= 2:
            line(mix, 'bells', HF_BELLS[3][k - 2], t0, b, lambda m, d: bell(m - 12, 3.0), 0.34, hum, 0.004)
        # The choir and organ: the chord, held; the choir sings "oo" in the
        # first phrases, "ah" from the third, doubled up an octave late on.
        pad = HF_PAD[chord]
        for m in pad:
            mix.put('organ', organ(m, bar + 0.05, 'principal', 0.06, 0.25), t0, 0.05)
        mix.put('organ', organ(HF_ROOT[chord] + 12, bar + 0.05, 'pedal', 0.05, 0.2), t0, 0.12)
        vowel = 'oo' if phrase < 2 else 'ah'
        for m in pad[1:]:
            mix.put('choir', choir(m, bar + 0.3, 0.3, 0.5, vowel), t0, 0.1)
            if phrase >= 4:
                mix.put('choir', choir(m + 12, bar + 0.3, 0.3, 0.5, 'ah'), t0, 0.04)
        # The drums.
        drum = 45 if chord == 'Am' else 50
        mix.put('drums', timpani(drum, 1.0), t0, 0.24)
        for beat in (0, 1.5, 2):
            mix.put('drums', war_kick(), t0 + beat * b, 0.24 if beat == 0 else 0.18)
        for beat in (1, 3):
            mix.put('drums', tom(1.0), t0 + beat * b + hum.uniform(-0.002, 0.002), 0.46)
            mix.put('drums', snap(), t0 + beat * b, 0.14)
        per = 4 if phrase >= 4 else 2
        for j in range(4 * per):
            mix.put('drums', shaker(j % 2), t0 + j * b / per + hum.uniform(-0.002, 0.002),
                    (0.07 if j % per == 0 else 0.045) * (1.0 if phrase >= 2 else 0.7))
        if k == 3 and phrase % 2 == 1:
            for j in range(8):
                mix.put('drums', tom(0.8), t0 + (2 + j / 4) * b, 0.14 + 0.24 * j / 8)
            mix.put('drums', swell(bar, 120 + n), t0, 0.3)
        # Waxby's melody: the title tune on the music box with the celesta
        # over it; the celesta leads the second time through.
        half = n // 16
        tune = (WICK_A if (n // 8) % 2 == 0 else WICK_A2)[n % 8]
        if half == 0:
            line(mix, 'wick', tune, t0, b, lambda m, d: music_box(m), 0.3, hum, 0.004)
            line(mix, 'wick', tune, t0 + 0.008, b, lambda m, d: celesta(m + 12), 0.08)
        else:
            line(mix, 'wick', tune, t0, b, lambda m, d: celesta(m), 0.28, hum, 0.004)
            line(mix, 'wick', tune, t0 + 0.008, b, lambda m, d: music_box(m - 12), 0.12)
    # The void: D1 and Ab1, a tritone, each beating against a copy of itself;
    # reversed bells on the dark notes swelling into the phrases; the breath.
    # (Its reed leans on the harmonic nearest 480 Hz: at a low flame the void
    # is all but alone, and must hold its loudness on a phone.)
    mix.put('void', reedy_drone(26, L, 0.16, [(4, 0.2, 0.0), (8, 0.08, 1.1)], detune=8, lift=1.15, top=1600.0), 0.0)
    mix.put('void', reedy_drone(32, L, 0.12, [(2, 0.3, 2.2)], detune=21, lift=1.15, top=1600.0), 0.0)
    for at in (0.0, 16.0, 32.0, 48.0):
        mix.put('revbells', rev_bell(44, 4.0), at - 4.0, 0.3)
        mix.put('revbells', rev_bell(51, 4.0), at - 4.0, 0.22)
    mix.put('breath', breath_loop(L, 131, 800.0, 0.9, ((4, 0.7, 0.0), (1, 0.3, 1.0))), 0.0, 0.04)
    # The balance: the drums drive, the void is always there under it (and
    # with only Waxby's melody left, it has to be heard), the melody leads
    # without drowning the rest, and the bells sit just under it (on a
    # phone they come back into the void and the melody 1.7 dB loud). The
    # void and the melody are set so the two of them alone (P3) stay near
    # where they were before the bells came up (-21.8 LUFS, from -21.4).
    # The drums' slap and knock lifted over 800 Hz, so a phone hears them in
    # the same balance a pair of headphones does (their boom it can't play:
    # without this they lost 3.3 dB there, more than anything else in it).
    faders(mix, {'drums': 1.9, 'void': 2.38, 'revbells': 1.73, 'breath': 2.16, 'bells': 2.0, 'wick': 0.78})
    presence(mix, 'drums', 800.0, 1.0)
    return mix, dict(room=0.84, damp=0.35, wet=0.9), 120, HF_STEMS, HF_PREMIX


# ---------------------------------------------------------------- lullaby

# The Lull is A F# D. Per 4/4 bar in beats; the bells answer where the box rests.
LULL = [(0, 1, 81), (1, 1, 78), (2, 2, 74)]
LULLABY_TUNE = [
    LULL,                                                     # D   the Lull
    [(3, 1, 79)],                                             # G   (the bells answer) G5
    [(0, 1, 78), (1, 1, 76), (2, 1, 74), (3, 1, 76)],         # D   F#5 E5 D5 E5
    [(0, 2, 76), (2, 1, 73), (3, 1, 69)],                     # A   E5 C#5 A4
    LULL,                                                     # D
    [(3, 1, 78)],                                             # Bm  (the bells) F#5
    [(0, 1, 79), (1, 1, 78), (2, 1, 76), (3, 1, 74)],         # G   G5 F#5 E5 D5
    [(0, 3, 76), (3, 1, 73)],                                 # A   E5 C#5
    LULL,                                                     # D   the choir comes in
    [(2, 1, 83), (3, 1, 81)],                                 # G   (the bells) B5 A5
    [(0, 1, 78), (1, 1, 81), (2, 2, 86)],                     # Bm  F#5 A5 D6
    [(0, 2, 85), (2, 1, 83), (3, 1, 81)],                     # A   C#6 B5 A5
    [(0, 2, 83), (2, 1, 81), (3, 1, 79)],                     # G   B5 A5 G5
    LULL,                                                     # D
    [(0, 2, 76), (2, 2, 73)],                                 # A   E5 C#5
    [(0, 4, 74)],                                             # D   home; the bells, far off
]
LULLABY_FORM = ['D', 'G', 'D', 'A', 'D', 'Bm', 'G', 'A', 'D', 'G', 'Bm', 'A', 'G', 'D', 'A', 'D']
LULLABY_ROCK = {'D': (62, 69, 74, 69), 'G': (55, 62, 67, 62), 'A': (57, 64, 69, 64), 'Bm': (59, 66, 71, 66)}
LULLABY_TRIAD = {'D': (62, 66, 69), 'G': (62, 67, 71), 'A': (61, 64, 69), 'Bm': (62, 66, 71)}
LULLABY_ROOT = {'D': 50, 'G': 43, 'A': 45, 'Bm': 47}
LULL_BELLS = (69, 66, 62)                                     # A4 F#4 D4, the low bells' answer


def lullaby():
    b = 1.0
    bar = 4 * b
    form = LULLABY_FORM
    mix = Loop(len(form) * bar, tail=6.0)
    for name, send in (('box', 0.5), ('rock', 0.4), ('bells', 0.75), ('choir', 0.7), ('organ', 0.5)):
        mix.stem(name, send)
    hum = random.Random(121)
    for n, chord in enumerate(form):
        t0 = n * bar
        line(mix, 'box', LULLABY_TUNE[n], t0, b, lambda m, d: music_box(m), 0.34, hum, 0.006,
             accent=lambda s: 1.0 if s == 0 else 0.88)
        # The low bells answer the Lull.
        if n in (1, 5, 9):
            for j, m in enumerate(LULL_BELLS):
                mix.put('bells', bell(m - 12, 4.0), t0 + j * b + hum.uniform(-0.01, 0.01), 0.3 - 0.03 * j)
        if n == 15:
            for j, m in enumerate(LULL_BELLS):
                mix.put('bells', bell(m - 12, 4.0), t0 + (1 + j * 0.9) * b, 0.16 - 0.02 * j)
        # A rocking figure on the low teeth.
        for j, m in enumerate(LULLABY_ROCK[chord]):
            mix.put('rock', music_box(m), t0 + j * b + hum.uniform(-0.006, 0.006), (0.16 if j == 0 else 0.11))
        # The organ, soft; the choir hums from bar 9.
        root = LULLABY_ROOT[chord]
        for m in (root, root + 7, root + 12):
            mix.put('organ', organ(m, bar + 0.2, 'flute', 0.8, 1.2), t0, 0.03)
        if n >= 8:
            for m in LULLABY_TRIAD[chord]:
                mix.put('choir', choir(m, bar + 0.5, 1.0, 1.4, 'oo'), t0, 0.08)
    return mix, dict(room=0.9, damp=0.35, wet=0.75), 60



# ---------------------------------------------------------------- evenbell (P1)

# Evenbell rises for good: all six worlds' motifs in D major, over the tower's
# bells ringing rounds and the choir. Per 4/4 bar in beats.
EVENBELL_TUNE = [
    # the chapel: the title tune, major
    [(0, .5, 74), (.5, .5, 69), (1, .5, 74), (1.5, .5, 78), (2, .75, 81), (2.75, .25, 79), (3, .5, 78), (3.5, .5, 76)],
    [(0, .5, 76), (.5, .5, 73), (1, .5, 76), (1.5, .5, 81), (2, 1, 85), (3, .5, 83), (3.5, .5, 81)],
    [(0, .5, 78), (.5, .5, 74), (1, .5, 78), (1.5, .5, 83), (2, .75, 81), (2.75, .25, 79), (3, .5, 78), (3.5, .5, 74)],
    [(0, 1.5, 76), (1.5, .5, 73), (2, .5, 76), (2.5, .5, 81), (3, 1, 79)],
    # the tallow drops
    [(0, 1, 86), (1, 1, 83), (2, 2, 78)], [(0, 1, 86), (1, 1, 83), (2, 2, 79)],
    [(0, 1, 81), (1, 1, 78), (2, 1, 74), (3, 1, 78)], [(0, 3, 81), (3, 1, 76)],
    # the orchard's sixth, D up to B, and the title's answer
    [(0, 1.5, 74), (1.5, 1, 83), (2.5, .5, 81), (3, 1, 78)],
    [(0, .5, 79), (.5, .5, 81), (1, .5, 83), (1.5, 1.5, 86), (3, 1, 83)],
    [(0, .5, 74), (.5, .5, 69), (1, .5, 74), (1.5, .5, 78), (2, 2, 81)],
    [(0, 2, 85), (2, 1, 83), (3, 1, 81)],
    # the carillon's quarter chime
    [(0, 1, 74), (1, 1, 78), (2, 1, 79), (3, 1, 81)], [(0, 1, 81), (1, 1, 79), (2, 1, 78), (3, 1, 74)],
    [(0, 1, 76), (1, 1, 79), (2, 1, 83), (3, 1, 79)], [(0, 2, 81), (2, 2, 76)],
    # the sanctum's leaping fifth
    [(0, 1, 74), (1, 3, 81)], [(0, 1, 76), (1, 3, 83)], [(0, 1, 79), (1, 3, 86)], [(0, 1, 81), (1, 3, 88)],
    # the title melody, as dawn sang it
    [(0, 2, 74), (2, .5, 69), (2.5, .5, 74), (3, 1, 78)], [(0, 3, 81), (3, .5, 79), (3.5, .5, 78)],
    [(0, 2, 76), (2, .5, 73), (2.5, .5, 76), (3, 1, 81)], [(0, 3, 85), (3, .5, 83), (3.5, .5, 81)],
    [(0, 2, 74), (2, .5, 71), (2.5, .5, 74), (3, 1, 79)], [(0, 3, 83), (3, .5, 81), (3.5, .5, 79)],
    [(0, 2, 76), (2, .5, 73), (2.5, .5, 76), (3, 1, 81)], [(0, 1, 79), (1, 1, 76), (2, 2, 73)],
    # and the Lull, twice, home
    [(0, 1, 81), (1, 1, 78), (2, 2, 74)], [(0, 1, 83), (1, 1, 79), (2, 2, 74)],
    [(0, 1, 81), (1, 1, 78), (2, 2, 74)], [(0, 2, 76), (2, 1, 73), (3, 1, 69)],
]
EVENBELL_FORM = (['D', 'A', 'G', 'A'] + ['Bm', 'G', 'D', 'A'] + ['D', 'G', 'D', 'A'] + ['D', 'G', 'Em', 'A'] +
                 ['D', 'A', 'G', 'A'] + ['D', 'D', 'A', 'A', 'G', 'G', 'A', 'A'] + ['D', 'G', 'D', 'A'])
EVENBELL_PAD = {'D': (62, 66, 69, 74), 'A': (61, 64, 69, 73), 'G': (62, 67, 71, 74), 'Bm': (62, 66, 71, 74),
                'Em': (64, 67, 71, 76)}
EVENBELL_ROOT = {'D': 38, 'A': 33, 'G': 31, 'Bm': 35, 'Em': 40}
EVENBELL_ROUNDS = (86, 85, 83, 81, 79, 78, 76, 74)      # D6 down to D5, the tower's eight


def evenbell():
    b = 60.0 / 76.0
    bar = 4 * b
    form = EVENBELL_FORM
    mix = Loop(len(form) * bar, tail=6.0)
    for name, send in (('celesta', 0.55), ('choir', 0.7), ('organ', 0.5), ('bells', 0.75), ('lead', 0.45),
                       ('drums', 0.3)):
        mix.stem(name, send)
    hum = random.Random(161)
    for n, chord in enumerate(form):
        t0 = n * bar
        phrase = n // 4
        tune = EVENBELL_TUNE[n]
        # The tune on the celesta; the choir sings it from the sanctum's
        # phrase on; the bells ring the quarter chime with it.
        line(mix, 'celesta', tune, t0, b, lambda m, d: celesta(m + 12), 0.22, hum, 0.004)
        line(mix, 'lead', tune, t0, b, lambda m, d: flute(m, d - 0.03), 0.16 if phrase < 4 else 0.1)
        if phrase >= 4:
            line(mix, 'choir', tune, t0, b, lambda m, d: choir(m, d + 0.1, 0.07, 0.3), 0.16)
        if phrase == 3:
            line(mix, 'bells', tune, t0, b, lambda m, d: bell(m - 12, 2.5), 0.26)
        # The choir and organ hold the chord, swelling as it goes.
        pad = EVENBELL_PAD[chord]
        g = min(1.0, 0.55 + 0.07 * phrase)
        for m in pad[1:]:
            mix.put('choir', choir(m, bar + 0.3, 0.5, 0.8), t0, 0.09 * g)
        for m in pad:
            mix.put('organ', organ(m, bar + 0.1, 'principal' if phrase >= 4 else 'flute', 0.3, 0.6), t0, 0.04 * g)
        mix.put('organ', organ(EVENBELL_ROOT[chord] + 12, bar + 0.1, 'pedal', 0.3, 0.6), t0, 0.1 * g)
        # The tower rings rounds, eight bells down the scale a bar, softly
        # at first, fuller in the last phrases.
        if phrase >= 1:
            ring_rows(mix, 'bells', [list(range(8))], t0, b / 2, EVENBELL_ROUNDS, 0.09 if phrase < 5 else 0.13,
                      2.2, hum, 0.008, strike=lambda bell_no, place: 1.0 if place == 0 else 0.8)
        # A great bell on each phrase's first downbeat; timpani under it.
        if n % 4 == 0:
            mix.put('bells', bell(50, 5.0), t0, 0.3)
            mix.put('drums', timpani(50, 0.3), t0, 0.3)
        if n % 8 == 7:
            for j in range(6):
                mix.put('drums', timpani(45, 0.3), t0 + (2.5 + j * 0.25) * b, 0.1 + 0.04 * j)
    faders(mix, {'bells': 1.8})
    return mix, dict(room=0.9, damp=0.3, wet=0.75), 76


# ---------------------------------------------------------------- lament (P2)

LAMENT_TUNE = [   # the title motif, slowed to a lament: per 3/4 bar in beats
    [(0, 2, 74), (2, 1, 69)], [(0, 1, 74), (1, 2, 77)], [(0, 3, 81)], [(0, 1, 79), (1, 1, 77), (2, 1, 76)],
    [(0, 2, 74), (2, 1, 69)], [(0, 1, 74), (1, 2, 77)], [(0, 2, 82), (2, 1, 81)], [(0, 3, 76)],
    [(0, 2, 77), (2, 1, 74)], [(0, 2, 81), (2, 1, 77)], [(0, 1, 79), (1, 1, 82), (2, 1, 86)], [(0, 3, 84)],
    [(0, 1, 82), (1, 1, 81), (2, 1, 79)], [(0, 2, 77), (2, 1, 79)], [(0, 2, 76), (2, 1, 72)], [(0, 3, 74)],
]
LAMENT_FORM = ['Dm', 'Bb', 'F', 'C', 'Dm', 'Bb', 'Gm', 'Am', 'Bb', 'F', 'Gm', 'Am', 'Bb', 'Gm', 'Am', 'Dm']
LAMENT_PAD = {'Dm': (62, 65, 69), 'Bb': (62, 65, 70), 'F': (60, 65, 69), 'C': (60, 64, 67), 'Gm': (62, 67, 70),
              'Am': (60, 64, 69)}
LAMENT_ROOT = {'Dm': 38, 'Bb': 34, 'F': 41, 'C': 36, 'Gm': 43, 'Am': 45}


def lament():
    b = 1.0
    bar = 3 * b
    form = LAMENT_FORM
    mix = Loop(len(form) * bar, tail=6.0)
    for name, send in (('organ', 0.55), ('choir', 0.7), ('solo', 0.5)):
        mix.stem(name, send)
    hum = random.Random(171)
    for n, chord in enumerate(form):
        t0 = n * bar
        line(mix, 'solo', LAMENT_TUNE[n], t0, b, lambda m, d: organ(m, d - 0.05, 'principal', 0.08, 0.4), 0.13)
        for m in LAMENT_PAD[chord]:
            mix.put('organ', organ(m, bar + 0.1, 'flute', 0.4, 0.8), t0, 0.05)
        mix.put('organ', organ(LAMENT_ROOT[chord] + 12, bar + 0.1, 'pedal', 0.4, 0.8), t0, 0.07)
        vowel = 'oo' if n < 8 else 'ah'
        for m in LAMENT_PAD[chord]:
            mix.put('choir', choir(m, bar + 0.4, 0.7, 1.0, vowel), t0, 0.08 if n < 8 else 0.1)
    return mix, dict(room=0.9, damp=0.4, wet=0.8, target=-19.0), 60


TRACKS = {'rootmother': rootmother, 'tinker': tinker, 'saint': saint, 'lullaby': lullaby, 'evenbell': evenbell,
          'lament': lament}
STEM_SETS = {'hush_final': hush_final}

# Each track's mode, for check_music.py, which runs every maker with its
# voices stubbed out and checks every note it puts in the mix against it:
# one mode, or [(from seconds, mode), ...] for rootmother, whose bridge (its
# middle 16 bars) turns Phrygian. FREE: the parts left out on purpose (the
# Hush's void: its Ab and Eb are the Hush's).
MODES = {'rootmother': [(0.0, 'dorian'), (16 * RM_BAR, 'phrygian'), (32 * RM_BAR, 'dorian')], 'tinker': 'aeolian',
         'saint': 'phrygian', 'hush_final': 'aeolian', 'lullaby': 'major', 'evenbell': 'major', 'lament': 'aeolian'}
FREE = {'hush_final': ('void', 'revbells')}
