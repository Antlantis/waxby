"""The tall render labs (the shapes plan's E3, E4, E9, E11): today's 15-row
levels stacked into 24 and 36 rows, for the rendering work only. Not on the
map's path and not played for balance: debug labs, written to
game/levels/tall/ (the 15-row rule in tests/test_core.gd reads game/levels
only), each as lab-tall-<level>-<rows>:

  24 rows  the level, then its bottom 9 rows again under it: two floors,
           the start on the lower one
  36 rows  the level, its bottom 12 rows, then its bottom 9: three storeys
           (the 3-2 tower's height)

Only the bottom storey keeps the level's things (the start, altars, the
bell, monsters, signs); the storeys above keep its terrain, movers and
scenery (candles, lanterns, glowfruit, pods, icicles, cogs, weights, swings,
floats, buoys, waxfalls, drip spouts), so every painter and the edge lines
see real terrain at every height. A thing drawn in a vine column becomes
vine, a thing in water becomes water.

Sources, one a world, each shot in its world's other themes too
(tools/shot_tall.gd): 1-2 crypt, 2-1 waxfall, 3-1 orchard (with 5-3 the
slowest painters: the perf gate, tools/perf/paint_probe.gd), 3-2 rootvault
(the 36-row tower's backdrop, backdrops/orchard.gd's tall rootvault), 4-1
clockface (and 4-2 escapement: with 4-1 and 6-1 the levels whose load
builds the walk map, the phone gate's), 5-3 voidnave, 6-1 stillshore.

    python3 tools/levels/lab_tall.py      (after make_levels.py; reads its output)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.dont_write_bytecode = True

import common  # noqa: E402

SOURCES = ['1-2', '2-1', '3-1', '3-2', '4-1', '4-2', '5-3', '6-1']
STACKS = {24: [15, 9], 36: [15, 12, 9]}       # rows: the level's bottom n rows, top storey first
OUT = os.path.join(common.OUT, 'tall')
# What the storeys above keep: terrain (common.TILE_GLYPHS), movers, and
# these things (scenery and lights; no monsters, goals or signs).
SCENERY = set('c' 'L' 'N' 'd' '!' '8' '*' 'V' 'O' 'Q' 'Y' 'T' 'C' '&' 'J' 'o' 'w')
VINES = set('{}')
IN_WATER = set('f7H')                           # their cells are water
# Headers kept: the look and the column-wide zones (x is unchanged).
KEEP = ['music', 'theme', 'area', 'dread', 'tick', 'gusts', 'hush']


def _read(level_id):
    with open(os.path.join(common.OUT, level_id + '.txt')) as f:
        head, body = f.read().split('---\n', 1)
    header = [tuple(s.split(': ', 1)) for s in head.splitlines() if ': ' in s]
    rows = body.rstrip('\n').split('\n')
    w = max(len(r) for r in rows)
    return header, [r.ljust(w, '.') for r in rows]


def _upper(rows):
    """The storey's rows with only terrain, movers and scenery left."""
    out = []
    for y, r in enumerate(rows):
        line = []
        for x, ch in enumerate(r):
            if ch in common.TILE_GLYPHS or ch in common.MOVER_GLYPHS or ch in SCENERY:
                line.append(ch)
            elif ch in IN_WATER:
                line.append(':')
            elif any(0 <= y + d < len(rows) and rows[y + d][x] in VINES for d in (-1, 1)):
                line.append('{')
            else:
                line.append('.')
        out.append(''.join(line))
    return out


def stack(rows, height):
    """rows (15) stacked to height: the bottom storey whole, the ones above
    cut to their floors (STACKS)."""
    parts = STACKS[height]
    out = []
    for k, n in enumerate(parts):
        part = rows[len(rows) - n:]
        # (the bottom storey without its silver bell: a lab opens no secret)
        out += [r.replace('S', '.') for r in part] if k == len(parts) - 1 else _upper(part)
    assert len(out) == height
    return out


def build(level_id, height):
    header, rows = _read(level_id)
    assert len(rows) == common.H, '%s is %d rows' % (level_id, len(rows))
    vals = dict(header)
    name = 'lab-tall-%s-%d' % (level_id, height)
    tall = stack(rows, height)
    common.check_legend(name, tall)
    head = [('title', '%s, %d rows' % (vals.get('title', level_id), height)), ('subtitle', name)]
    head += [(k, vals[k]) for k in KEEP if k in vals]
    if '@' in ''.join(tall) and 'hints' in vals:
        head.append(('hints', vals['hints']))
    text = ''.join('%s: %s\n' % kv for kv in head) + '---\n' + '\n'.join(r.rstrip('.') for r in tall) + '\n'
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name + '.txt'), 'w') as f:
        f.write(text)
    return name


def main():
    for lid in SOURCES:
        for h in sorted(STACKS):
            name = build(lid, h)
            print('%s: %d rows' % (name, h))


if __name__ == '__main__':
    main()
