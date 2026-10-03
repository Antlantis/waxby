"""Writes the Waxworks' arenas: game/levels/rush/<boss>.txt, one for every
boss level in the build (spec §7.3, p_modes §6.6).

For each game/levels/<N>-4.txt with a boss: header (1-4 Old Tollgrave, 2-4
the Snuffer; the later worlds' as their files land):
  1. find the arena: the boss X, then the last altar K to its left; cut from
     K.x - 4 to the level's end (the altar at the door, the T_OPEN doorway,
     the arena);
  2. strip the story's things: sigils, signs with their hints, and every
     monster but the boss (the approach's Flits stay in the story);
  3. put Waxley's cellar in front: 12 columns with the start, one sign and a
     sconce, meeting the cut at the seam; `cut: 12` says where the arena
     part starts (the Descent's echo depths append only those columns);
  4. write the header: title (the boss's name), subtitle "The Waxworks", the
     source's theme, music, area, boss and boss_music, the hints, and the
     private keys rush, cut, src (the source level) and clock (Waxley's
     Clock, in seconds).

The Waxworks sets area_abs itself at run time (waxworks.gd). tests/test_modes.gd
checks every file parses, and the bot reaches the arena from the start.

    python3 tools/make_modes.py
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LEVELS = os.path.join(HERE, '..', 'game', 'levels')
OUT = os.path.join(LEVELS, 'rush')
H = 15

NAMES = {'tollgrave': 'Old Tollgrave', 'snuffer': 'The Snuffer', 'rootmother': 'Mother Gravebough',
         'tinker': 'The Tinker of Hours', 'saint': 'The Prism Saint', 'hush': 'The Hush'}
CLOCK = {'tollgrave': 90, 'snuffer': 120, 'rootmother': 120, 'tinker': 120, 'saint': 130, 'hush': 150}
MONSTERS = set('sbtahgkfM' + 'rpmijqeuxzylnD567')
STRIP = set('123@') | MONSTERS
CELLAR = [
    '############',
    '############',
    '............',
    '............',
    '............',
    '............',
    '............',
    '............',
    '............',
    '....c.......',
    '............',
    '............',
    '..P..@......',
    '############',
    '############',
]
CELLAR_SIGN = "Waxley's Waxworks. Mind the drips."


def read_level(path):
    header = []
    rows = []
    in_rows = False
    for line in open(path).read().split('\n'):
        if not in_rows:
            if line.strip() == '---':
                in_rows = True
                continue
            if ':' in line:
                k, v = line.split(':', 1)
                header.append((k.strip(), v.strip()))
            continue
        rows.append(line)
    while rows and not rows[-1].strip():
        rows.pop()
    w = max(len(r) for r in rows)
    return header, [r.ljust(w, '.') for r in rows]


def cut(level_id, header, rows):
    hd = dict(header)
    boss = hd.get('boss', '')
    xs = [(x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == 'X']
    assert len(xs) == 1, '%s: %d bosses' % (level_id, len(xs))
    bx = xs[0][0]
    ks = [x for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == 'K' and x < bx]
    assert ks, '%s: no altar before the boss: make_modes.py needs "... K ... door ... X arena"' % level_id
    x0 = max(ks) - 4
    part = [''.join('.' if ch in STRIP and ch != 'X' else ch for ch in r[x0:]) for r in rows]
    assert len(part) == H, '%s: %d rows' % (level_id, len(part))
    out_rows = [CELLAR[i] + part[i] for i in range(H)]
    hints = [CELLAR_SIGN]   # the only sign left
    out = [('title', NAMES.get(boss, boss.capitalize())), ('subtitle', 'The Waxworks'),
           ('music', hd.get('music', 'chapel')), ('theme', hd.get('theme', 'nave')), ('area', hd.get('area', '1')),
           ('boss', boss)]
    if hd.get('boss_music'):
        out.append(('boss_music', hd['boss_music']))
    out += [('rush', '1'), ('cut', str(len(CELLAR[0]))), ('src', level_id), ('clock', str(CLOCK.get(boss, 120))),
            ('hints', '|'.join(hints))]
    return boss, out, out_rows


def main():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for f in sorted(os.listdir(LEVELS)):
        m = re.match(r'^([1-6])-4\.txt$', f)
        if not m:
            continue
        header, rows = read_level(os.path.join(LEVELS, f))
        if not dict(header).get('boss'):
            continue
        boss, hd, out_rows = cut(f[:-4], header, rows)
        text = ''.join('%s: %s\n' % kv for kv in hd) + '---\n' + '\n'.join(r.rstrip('.') for r in out_rows) + '\n'
        with open(os.path.join(OUT, boss + '.txt'), 'w') as fh:
            fh.write(text)
        made.append(boss)
        print('rush/%s.txt: %d x %d, cut at %d (from %s)' % (boss, max(len(r) for r in out_rows), H, len(CELLAR[0]), f[:-4]))
    return made


if __name__ == '__main__':
    main()
    sys.exit(0)
