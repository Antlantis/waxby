"""Writes the Endless Descent's room library: game/levels/rooms/<biome>.txt.

Spec §7.2 (the room library) and p_modes.md §5.4. Every biome has 14 rooms:
a landing, a rest, a bell room, a warden room, and ten challenge rooms (4 of
tier 1, 3 of tier 2, 3 of tier 3). At least 8 of each biome's rooms are
LIFTED from the story's sections (tools/levels/w1.py, w2.py, imported by
name, so they are the very rows the bot already proved): the sigils, signs,
altars, Dreads and the start are taken out, and the seam columns are put on
both ends. The landings, rests, bells, warden rooms and a few tier-3 remixes
are drawn here.

The seam is T_OPEN (tools/levels/common.py): the first two and last two
columns of a room are stone in rows 0-1 and 13-14 and air in rows 2-12, so
rooms join with nothing between them (a landing needs only its right seam,
a bell room only its left: the level's own edges wall them).

Every room is 15 rows, uses only the shared legend, and gets these header
keys (the bundle is read by game/scripts/modes/rooms.gd):
    kind      landing | rest | bell | warden | challenge
    tier      1..3 (challenge rooms; 0 otherwise)
    tags      combat, platform, hazard, vertical, water, dark, cache
    mirror    yes | no (a mirrorable room is also played flipped: < > and
              O Q swap, nothing else)
    width     its columns
    src       the story section it was lifted from ("" when drawn here)
    deep      <depth>|<glyph>@<x>,<y>;... the deep overlay: monsters that
              join from that depth on (written into air cells at build time)
    hint      a landing's or bell room's sign text
    cart      the landing's spot for Waxley's cart (P2)
    seal      the warden room's door cells (both doors), room-relative
    spawn     the warden room's D: floor (a floor kind is drawn for it)
    cog_phase, weight_phase
              room-relative x=turns (a lifted section's own, moved by its seam)

A room lifted from a section with an overlay row (contract.md 2.5: gusts
( ) [ ] and Hush columns ;) keeps it as a 16th line, Z|..., under its rows;
rooms.gd offsets it by the room's place in a depth, mirrors it with the
room ( ) and [ ] swapping), and writes the depth's gusts: and hush: from it.

The tool checks what it can (the seams, the legend, the widths, the story
glyphs, the lights and monster caps, the deep cells on air and standing
where their kind stands); tests/test_modes.gd proves every room with the
reachability bot, seam to seam, both ways when mirrorable.

    python3 tools/make_rooms.py            every biome
    python3 tools/make_rooms.py tallow     only these
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'levels'))
sys.dont_write_bytecode = True

import common  # noqa: E402
from common import block, H, LEGEND, MIRROR  # noqa: E402

OUT = os.path.join(HERE, '..', 'game', 'levels', 'rooms')

SEAM = ['##', '##'] + ['..'] * 11 + ['##', '##']
STORY = set('123@PKEXD')           # never in a challenge room
LIGHTS = set('cLN')
MONSTERS = set('sbtahgkfM' + 'rpmijqeuxzylnS567'.replace('S', ''))
FLOOR_KINDS = set('sthaM' + 'rpmjqeuxln6')
CEILING_KINDS = set('kd')
AIR_KINDS = set('bgz y5'.replace(' ', ''))
WIDTH = {'landing': (18, 18), 'rest': (14, 14), 'bell': (22, 22), 'warden': (34, 34),
         1: (24, 48), 2: (28, 52), 3: (30, 60)}
DEEP_AT = {1: 8, 2: 14, 3: 20}


def _import(name):
    mod = __import__(name)
    return mod


def lift(section, strip=STORY, left=True, right=True):
    """A story section as a room: story glyphs out, seams on (its overlay
    row, if it has one, padded to match). A room is 15 rows: a section drawn
    taller (block(s, 24): a shaped level's) can't be lifted, and room() says
    which (the level keeps a 15-row section and place()s it instead:
    common.place, its rows padded with rock above and under)."""
    if len(section) != H:
        out = common.Rows(section[:H])
        out.lifted_rows = len(section)
        return out
    rows = []
    for i in range(H):
        r = ''.join('.' if ch in strip else ch for ch in section[i])
        rows.append((SEAM[i] if left else '') + r + (SEAM[i] if right else ''))
    out = common.Rows(rows)
    over = getattr(section, 'overlay', None)
    out.overlay = None
    if over is not None and over.strip('.'):
        out.overlay = ('..' if left else '') + over.ljust(len(section[0]), '.') + ('..' if right else '')
    return out


def draw(s):
    """A room drawn here (a Z| line under its rows is its overlay)."""
    return block(s)


def room(name, kind, rows, tier=0, tags='', mirror=None, src='', deep=None, hint='', cart='', spawn='', extra=None,
         cog_phase=None, weight_phase=None):
    """extra: monsters the Descent adds to a lifted room's base (a story
    section is sparser than a gauntlet): [(glyph, x, y)] into air cells.
    cog_phase / weight_phase: {room x: turns} (a lifted section's dx + 2)."""
    if mirror is None:
        mirror = kind == 'challenge'
    n = getattr(rows, 'lifted_rows', H)
    assert n == H, ('%s: its section %s is %d rows: the Descent lifts 15-row sections (rooms are 15 rows). '
                    'Keep %s drawn at 15 rows and place() it into the taller level (common.place), '
                    'or lift a 15-row copy' % (name, src or '(unnamed)', n, src or 'it'))
    overlay = getattr(rows, 'overlay', None)
    rows = list(rows)
    for ch, x, y in (extra or []):
        assert rows[y][x] == '.', '%s: extra %r at %d,%d is not on air' % (name, ch, x, y)
        rows[y] = rows[y][:x] + ch + rows[y][x + 1:]
    return {'name': name, 'kind': kind, 'tier': tier, 'tags': tags, 'mirror': mirror, 'rows': rows,
            'src': src, 'deep': deep or [], 'hint': hint, 'cart': cart, 'spawn': spawn, 'extra': extra or [],
            'overlay': overlay, 'cog_phase': cog_phase or {}, 'weight_phase': weight_phase or {}}


# ---------------------------------------------------------------- the checks

def _solid(ch):
    return ch in '#B?WRUIZ<>GF'


def _floorlike(ch):
    return _solid(ch) or ch in '=%_'


def check(rm, biome):
    name = '%s/%s' % (biome, rm['name'])
    rows = rm['rows']
    assert len(rows) == H, '%s: %d rows' % (name, len(rows))
    w = len(rows[0])
    assert all(len(r) == w for r in rows), '%s: ragged rows' % name
    rm['width'] = w
    kind = rm['kind']
    lo, hi = WIDTH[rm['tier'] if kind == 'challenge' else kind]
    assert lo <= w <= hi, '%s: %d wide, not %d-%d' % (name, w, lo, hi)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            assert ch in LEGEND, '%s: glyph %r at %d,%d' % (name, ch, x, y)
    # The seams.
    left = kind not in ('landing',)
    right = kind not in ('bell',)
    for i in range(H):
        if left:
            assert rows[i][:2] == SEAM[i], '%s: left seam row %d is %r' % (name, i, rows[i][:2])
        if right:
            assert rows[i][-2:] == SEAM[i], '%s: right seam row %d is %r' % (name, i, rows[i][-2:])
    # Story things only where they belong.
    allowed = {'landing': set('PK@'), 'rest': set('K'), 'bell': set('E@'), 'warden': set('D'), 'challenge': set()}[kind]
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in STORY:
                assert ch in allowed, '%s: %r at %d,%d does not belong in a %s room' % (name, ch, x, y, kind)
    if kind == 'landing':
        assert sum(r.count('P') for r in rows) == 1 and sum(r.count('K') for r in rows) == 1, '%s: one P and one K' % name
    if kind == 'bell':
        assert sum(r.count('E') for r in rows) == 1, '%s: one E' % name
    # Lights: at most 5, at most 2 in any 12 columns.
    lx = [x for r in rows for x, ch in enumerate(r) if ch in LIGHTS]
    assert len(lx) <= 5, '%s: %d static lights' % (name, len(lx))
    for x0 in range(0, w):
        n = sum(1 for x in lx if x0 <= x < x0 + 12)
        assert n <= 2, '%s: %d lights in columns %d-%d' % (name, n, x0, x0 + 11)
    # Monsters: at most 7, 10 with the deep overlay.
    base = sum(1 for r in rows for ch in r if ch in MONSTERS)
    assert base <= 7, '%s: %d monsters' % (name, base)
    assert base + len(rm['deep']) <= 10, '%s: %d monsters with the deep overlay' % (name, base + len(rm['deep']))
    for ch, x, y in rm['extra']:
        below = rows[y + 1][x] if y + 1 < H else '#'
        above = rows[y - 1][x] if y > 0 else '#'
        assert ch not in FLOOR_KINDS or _floorlike(below), '%s: extra %r at %d,%d has no floor' % (name, ch, x, y)
        assert ch not in CEILING_KINDS or _solid(above), '%s: extra %r at %d,%d has no ceiling' % (name, ch, x, y)
    for ch, x, y in rm['deep']:
        assert ch in MONSTERS, '%s: deep %r is not a monster' % (name, ch)
        assert 0 <= x < w and 0 <= y < H and rows[y][x] == '.', '%s: deep %r at %d,%d is not on air' % (name, ch, x, y)
        below = rows[y + 1][x] if y + 1 < H else '#'
        above = rows[y - 1][x] if y > 0 else '#'
        if ch in FLOOR_KINDS:
            assert _floorlike(below), '%s: deep %r at %d,%d has no floor' % (name, ch, x, y)
        if ch in CEILING_KINDS:
            assert _solid(above), '%s: deep %r at %d,%d has no ceiling' % (name, ch, x, y)
    # Dripkins hang at most 7 rows over their floor.
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == 'k':
                d = 1
                while y + d < H and not _floorlike(rows[y + d][x]):
                    d += 1
                assert d <= 8, '%s: a Dripkin at %d,%d hangs %d rows up' % (name, x, y, d - 1)
    # The overlay row: as wide as the room, overlay glyphs only.
    if rm.get('overlay'):
        assert len(rm['overlay']) == w, '%s: overlay row is %d wide, not %d' % (name, len(rm['overlay']), w)
        assert set(rm['overlay']) <= common.OVERLAY_GLYPHS, '%s: overlay row has %r' % (name, rm['overlay'])
    for key in ('cog_phase', 'weight_phase'):
        for x in rm.get(key, {}):
            assert 0 <= x < w, '%s: %s x %d is outside the room' % (name, key, x)
    # Warden rooms: the doors are air.
    if kind == 'warden':
        for (sx, sy) in rm['seal']:
            assert rows[sy][sx] == '.', '%s: door cell %d,%d is %r' % (name, sx, sy, rows[sy][sx])


def mirror_rows(rows):
    return [''.join(MIRROR.get(c, c) for c in reversed(r)) for r in rows]


# ---------------------------------------------------------------- writing

def write_bundle(biome, rooms):
    lines = ['# rooms/%s.txt, written by tools/make_rooms.py: do not hand-edit' % biome]
    for rm in rooms:
        check(rm, biome)
        lines.append('=== %s' % rm['name'])
        lines.append('kind: %s' % rm['kind'])
        lines.append('tier: %d' % rm['tier'])
        lines.append('tags: %s' % rm['tags'])
        lines.append('mirror: %s' % ('yes' if rm['mirror'] else 'no'))
        lines.append('width: %d' % rm['width'])
        if rm['src']:
            lines.append('src: %s' % rm['src'])
        if rm['deep']:
            at = DEEP_AT.get(rm['tier'], 14)
            lines.append('deep: %d|%s' % (at, ';'.join('%s@%d,%d' % d for d in rm['deep'])))
        if rm['hint']:
            lines.append('hint: %s' % rm['hint'])
        if rm['cart']:
            lines.append('cart: %s' % rm['cart'])
        if rm.get('seal'):
            lines.append('seal: %s' % ';'.join('%d,%d' % c for c in rm['seal']))
        if rm['spawn']:
            lines.append('spawn: %s' % rm['spawn'])
        for key in ('cog_phase', 'weight_phase'):
            if rm.get(key):
                lines.append('%s: %s' % (key, common.phases_header(rm[key])))
        lines.append('---')
        lines.extend(rm['rows'])
        if rm.get('overlay'):
            lines.append('Z|' + rm['overlay'])
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, biome + '.txt')
    with open(path, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    kinds = {}
    for rm in rooms:
        k = rm['kind'] if rm['kind'] != 'challenge' else 't%d' % rm['tier']
        kinds[k] = kinds.get(k, 0) + 1
    lifted = sum(1 for rm in rooms if rm['src'])
    print('rooms/%s: %d rooms (%s), %d lifted from the story' % (
        biome, len(rooms), ', '.join('%s %d' % kv for kv in sorted(kinds.items())), lifted))
    return path


# ---------------------------------------------------------------- the shared rooms

def landing(biome_name):
    return room('%s_landing' % biome_name, 'landing', draw('''
 0|##################
 1|##################
 2|..................
 3|..................
 4|..................
 5|..................
 6|..................
 7|..................
 8|..................
 9|.........R........
10|..................
11|......c...........
12|..P.@.......K.....
13|##################
14|##################
'''), tags='rest,cache', mirror=False, hint='Depth {depth}. {line}', cart='15,12')


def rest(biome_name):
    return room('%s_rest' % biome_name, 'rest', draw('''
 0|##############
 1|##############
 2|..............
 3|..............
 4|..............
 5|..............
 6|..............
 7|..............
 8|..............
 9|..............
10|.......c......
11|..............
12|.....K........
13|##############
14|##############
'''), tags='rest', mirror=False)


def bell(biome_name, shape):
    return room('%s_bell' % biome_name, 'bell', draw(shape), tags='rest', mirror=False,
                hint='Ring it to go deeper')


def warden(biome_name, shape):
    rm = room('%s_warden' % biome_name, 'warden', draw(shape), tags='combat', mirror=False, spawn='floor')
    w = len(rm['rows'][0])
    rm['seal'] = [(2, 10), (2, 11), (2, 12), (w - 3, 10), (w - 3, 11), (w - 3, 12)]
    return rm


# ---------------------------------------------------------------- the cathedral (World 1)

def cathedral():
    w1 = _import('w1')
    rooms = [landing('cathedral'), rest('cathedral')]
    rooms.append(bell('cathedral', '''
 0|######################
 1|######################
 2|......................
 3|......................
 4|......................
 5|......................
 6|......................
 7|......................
 8|......................
 9|..............c.......
10|......................
11|......................
12|..@.........E.........
13|######################
14|######################
'''))
    rooms.append(warden('cathedral', '''
 0|##################################
 1|##################################
 2|..##############################..
 3|..##..........................##..
 4|..##..........................##..
 5|..##..........................##..
 6|..##.......c..........c.......##..
 7|..##..........................##..
 8|..##....=====........=====....##..
 9|..##..........................##..
10|..................................
11|..................................
12|................D.................
13|##################################
14|##################################
'''))
    # Tier 1: one threat at a time, flat stretches.
    rooms.append(room('nave_spikes', 'challenge', lift(w1.N_SPIKES), 1, 'combat,hazard,cache', src='w1.N_SPIKES',
                      deep=[('s', 12, 12), ('b', 30, 5)], extra=[('s', 34, 12), ('a', 18, 9)]))
    rooms.append(room('nave_ledges', 'challenge', lift(w1.N_LEDGES), 1, 'platform,combat', src='w1.N_LEDGES',
                      deep=[('s', 24, 12), ('a', 8, 9)], extra=[('b', 26, 5), ('s', 20, 12), ('b', 14, 3)]))
    rooms.append(room('tower_climb', 'challenge', lift(w1.T_CLIMB), 1, 'platform,combat,vertical', src='w1.T_CLIMB',
                      deep=[('a', 14, 7), ('s', 22, 12)], extra=[('s', 26, 12), ('b', 28, 3)]))
    rooms.append(room('choir_lava', 'challenge', lift(w1.B_LAVA), 1, 'hazard,platform', src='w1.B_LAVA',
                      deep=[('b', 20, 5)], extra=[('b', 30, 4), ('b', 12, 4), ('b', 26, 6), ('a', 16, 9), ('b', 21, 2)]))
    # Tier 2: two threat types and a hazard line.
    rooms.append(room('crypt_crumble', 'challenge', lift(w1.C_CRUMBLE), 2, 'platform,hazard', src='w1.C_CRUMBLE',
                      deep=[('b', 22, 4), ('b', 10, 3)], extra=[('a', 13, 8), ('s', 31, 12), ('b', 16, 6), ('s', 3, 12), ('b', 26, 5)]))
    rooms.append(room('crypt_mover', 'challenge', lift(w1.C_MOVER), 2, 'platform,hazard,cache', src='w1.C_MOVER',
                      deep=[('a', 20, 10), ('b', 12, 4)], extra=[('a', 30, 12), ('s', 3, 12), ('b', 20, 6)]))
    rooms.append(room('choir_thorns', 'challenge', lift(w1.B_THORNS), 2, 'combat,cache', src='w1.B_THORNS',
                      deep=[('t', 18, 12), ('b', 16, 5)], extra=[('b', 8, 4), ('s', 26, 12), ('s', 16, 12)]))
    # Tier 3: vertical beats, crumble and movers.
    rooms.append(room('choir_glide', 'challenge', lift(w1.B_GLIDE), 3, 'platform,hazard,cache', src='w1.B_GLIDE',
                      deep=[('b', 14, 4), ('g', 28, 6)], extra=[('b', 8, 3), ('b', 24, 5)]))
    rooms.append(room('choir_organ', 'challenge', lift(w1.B_ORGAN), 3, 'combat,hazard,cache', src='w1.B_ORGAN', mirror=False,
                      deep=[('s', 10, 12), ('b', 26, 5)]))
    rooms.append(room('crypt_crumble_bridge', 'challenge', draw('''
 0|############################################
 1|############################################
 2|............................................
 3|............................................
 4|............................................
 5|............................................
 6|....................a.......................
 7|...................===......................
 8|............................................
 9|........c......................c...........
10|............................................
11|................%%%%%%%%%%%%................
12|..........s.................................
13|################............################
14|################............################
'''), 3, 'platform,combat,hazard', deep=[('b', 11, 8), ('a', 33, 12)], extra=[('s', 38, 12), ('b', 25, 4)]))
    return rooms


# ---------------------------------------------------------------- the tallow (World 2)

def tallow():
    w2 = _import('w2')
    rooms = [landing('tallow'), rest('tallow')]
    rooms.append(bell('tallow', '''
 0|######################
 1|######################
 2|..####################
 3|..####################
 4|......................
 5|......................
 6|......................
 7|......................
 8|......................
 9|..............c.......
10|......................
11|......................
12|..@.........E.........
13|######################
14|######################
'''))
    rooms.append(warden('tallow', '''
 0|##################################
 1|##################################
 2|..##############################..
 3|..##############################..
 4|..##..........................##..
 5|..##..........................##..
 6|..##.......L..........L.......##..
 7|..##..........................##..
 8|..##.....====........====.....##..
 9|..##..........................##..
10|..................................
11|..................................
12|........::::....D....::::.........
13|##################################
14|##################################
'''))
    rooms.append(room('waxfall_dripkins', 'challenge', lift(w2.W_DRIPKIN), 1, 'combat,dark', src='w2.W_DRIPKIN',
                      deep=[('s', 22, 12), ('k', 24, 9)]))
    rooms.append(room('waxfall_archers', 'challenge', lift(w2.W_ARCHERS), 1, 'combat,platform', src='w2.W_ARCHERS',
                      deep=[('a', 29, 5), ('s', 6, 12)]))
    rooms.append(room('chandlery_helms', 'challenge', lift(w2.C2_HELMS), 1, 'combat,water', src='w2.C2_HELMS',
                      deep=[('s', 22, 12), ('a', 15, 9)], extra=[('s', 32, 12)]))
    rooms.append(room('chandlery_shelves', 'challenge', lift(w2.C2_SHELVES), 1, 'platform,water', src='w2.C2_SHELVES',
                      deep=[('s', 10, 7), ('k', 19, 5)], extra=[('s', 20, 7), ('k', 9, 5)]))
    rooms.append(room('waxfall_drips', 'challenge', lift(w2.W_DRIPS), 2, 'platform,hazard', src='w2.W_DRIPS',
                      deep=[('g', 16, 7), ('s', 31, 12)], extra=[('b', 22, 5), ('g', 26, 6), ('s', 3, 12)]))
    rooms.append(room('chandlery_rafts', 'challenge', lift(w2.C2_RAFTS), 2, 'platform,water', src='w2.C2_RAFTS',
                      deep=[('g', 22, 6), ('a', 37, 12)], extra=[('s', 3, 12), ('b', 20, 4)]))
    rooms.append(room('chandlery_jaws', 'challenge', lift(w2.C2_JAWS), 2, 'hazard,water,combat', src='w2.C2_JAWS',
                      deep=[('g', 20, 6), ('s', 35, 12)]))
    rooms.append(room('garden_flowers', 'challenge', lift(w2.G_FLOWERS), 3, 'platform,hazard', src='w2.G_FLOWERS', mirror=False,
                      deep=[('g', 26, 4), ('g', 10, 4)], extra=[('g', 38, 5)]))
    rooms.append(room('garden_archers', 'challenge', lift(w2.G_ARCHERS), 3, 'combat,platform', src='w2.G_ARCHERS',
                      deep=[('s', 30, 12), ('a', 14, 10)]))
    rooms.append(room('garden_terrace', 'challenge', lift(w2.G_TERRACE), 3, 'combat,platform,vertical', src='w2.G_TERRACE',
                      deep=[('s', 22, 12), ('g', 36, 6)]))
    return rooms


BIOMES = {'cathedral': cathedral, 'tallow': tallow}


def self_check():
    """A section drawn taller than a room (a shaped level's block(s, 24))
    is refused by name, never cut to its top 15 rows."""
    tall = block('\n'.join(['.' * 24] * 22 + ['#' * 24] * 2), 24)
    try:
        room('tall_lab', 'challenge', lift(tall), 1, 'combat', src='lab.TALL')
    except AssertionError as e:
        assert 'lab.TALL is 24 rows' in str(e), str(e)
    else:
        raise AssertionError('make_rooms: a 24-row section was lifted')


def main(names):
    self_check()
    for name in names:
        write_bundle(name, BIOMES[name]())


if __name__ == '__main__':
    main(sys.argv[1:] or list(BIOMES))
