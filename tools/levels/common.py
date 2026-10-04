"""What every level module shares: drawing sections, joining them, the
overlay row, the header writers, and writing game/levels/<id>.txt.

Every section is 15 rows tall (row 13 is the usual floor), drawn with '.'
for air so the columns line up; see game/scripts/level_data.gd for the
legend. A row may carry a label before a '|' (only the first '|' splits, so
the '|' mover glyph inside a row is safe):

    B_RISE = block('''
     0|..........................
    ...
    14|####~~~~~~~~~~~~~~~~~#####
     Z|......((((................
    ''')

The optional 16th line, labelled Z, is the overlay row (contract.md 2.5):
the same width as the section, '.' everywhere else, and
    ( )  a gust column blowing left / right on phase A
    [ ]  a gust column blowing left / right on phase B (2.4 s later)
    ;    a Hush-zone column
The tool turns the joined overlay into the gusts: and hush: headers (tile
columns, absolute, inclusive) and never writes it into the rows.

Reach, for laying out jumps: a held jump clears 3 tiles up (not 4) and
about 4 tiles across; 2-3 tile gaps are comfortable. A ceiling of spikes 5
rows above a floor kills a fully held jump but not a shorter one. Into a
Dusk gust (120 px/s) the widest gap is 2 tiles; a vine leap carries about
3.7 tiles and lands about a tile lower.

A level module exports LEVELS, a list of entries:

    {'id': '3-1', 'name': 'The Bramble Gate', 'area': 13, 'theme': 'orchard',
     'music': 'orchard', 'story_start': 'beat_3_1', 'hints': [...],
     'cog_phase': {(ES_COG, 4): 0.25},          # (section, dx[, n]) -> turns
     'chase': [((C_A, 2), (C_B, 30))],          # (start, end) ranges
     'sections': [BG_START, BG_CLIMB, ...]}

or, for the v2 levels (kept byte for byte), an explicit ordered 'header'
list of (key, value) pairs. Header values holding x (cog_phase,
weight_phase, chase) may name places as (section, dx) or (section, dx, n)
(the n-th use of that section in the level) and are written with absolute x,
as _order_hints writes the hints in reading order.

Build 2's toolkit (the toolkit part below): swap() edits a copy of a
section, stamp() drops an encounter stamp (STAMPS) into one, span() names a
section's columns for a range header (a sealed room's duel:, ambush: or
room:, a belt_flip: run), and each world's regular levels declare their own
cast and threat density (world_tables: ROSTER and THREAT), checked as each
file is written (check_roster, check_threat), with the world's rules across
them (check_roles: the ramp, the checkpoints, the section roles), and
written as roster: and threat: headers, which tests/level_rules.gd holds
each file to. An entry's 'anoint' may be a list of (section, dx, row[,
omens[, name]]); anoint_header() writes it, Omens and names and all. Every
key is optional; toolkit.py proves the toolkit with every build.
"""
import ast
import functools
import os
import re

H = 15
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'game', 'levels')

# The full v3 legend (contract.md 2.2). Nothing else may appear in a row.
TILE_GLYPHS = set('.#B=%?WRU^v~:F' + '{}I_Z<>GA')
MOVER_GLYPHS = set('-|')
ENTITY_GLYPHS = set('owPKE@csbtX123ahgkfMDNLd!' + '*8VOQYT&JHCS+' + 'rpmijqeuxzylnS567')
LEGEND = TILE_GLYPHS | MOVER_GLYPHS | ENTITY_GLYPHS
OVERLAY_GLYPHS = set('.()[];')
# The Descent's mirror (contract.md 2.5): exactly these, and nothing else.
MIRROR = {'<': '>', '>': '<', 'O': 'Q', 'Q': 'O'}
MIRROR_OVERLAY = {'(': ')', ')': '(', '[': ']', ']': '['}

# The sign budget (check_sign_budget): 1-1 at most 4 signs, every other
# level at most 3, so the count can't creep back (the feel labs are free).
# The sign cut took the campaign from 165 signs to 41: a sign stays only
# where it teaches what no bark, beat or tell says there, plus a boss's rule
# at its door and a lore line at most (the author's review).
SIGN_BUDGET = True

# Where written headers go when an entry doesn't give its own order. Build
# 2's keys sit just before the hints (a secret level's warden_room, then
# anoint, as they always fell): anoint (forced Anointed: anoint_header),
# twist (the level's rule), roster and threat (world_tables), roles (a re-cut
# level's section roles: world_problems), the sealed rooms' duel, ambush and
# room, and belt_flip (range keys: span()).
HEADER_ORDER = ['title', 'subtitle', 'music', 'theme', 'area', 'area_abs', 'boss', 'boss_music', 'dread', 'warden',
                'secret', 'secret_prize', 'tick', 'story_start', 'story_boss', 'story_end', 'par', 'rush',
                'cog_phase', 'weight_phase', 'chase', 'gusts', 'hush', 'warden_room', 'anoint', 'twist',
                'roster', 'threat', 'roles', 'duel', 'ambush', 'room', 'belt_flip', 'hints']


class Section(list):
    """A section's 15 rows (a list of str), and its overlay row or None.
    Hashed and compared by identity, so a section can key a dict (cog_phase:
    {(ES_COG, 4): 0.25})."""
    overlay = None

    def __hash__(self):
        return id(self)

    def __eq__(self, other):
        return self is other

    def __ne__(self, other):
        return self is not other


class Rows(list):
    """A level's joined rows, with the joined overlay and where each section
    starts: parts = [(section, x0)]."""
    overlay = None
    parts = ()


def block(s):
    lines = s.strip('\n').split('\n')
    over = None
    last = lines[-1] if lines else ''
    if '|' in last and last.split('|', 1)[0].strip() == 'Z':
        over = last.split('|', 1)[1]
        lines = lines[:-1]
    lines = [l.split('|', 1)[1] if '|' in l else l for l in lines]
    assert len(lines) == H, 'section has %d rows: %r' % (len(lines), lines[0])
    w = max(len(l) for l in lines)
    # Short rows are padded with air. Never the floor rows (the bottom two)
    # past a solid end: that pads a hole to the bottom of the level (lab-1's
    # chain had one, from rows one wider above).
    for i in range(H - 2, H):
        l = lines[i]
        assert len(l) == w or not l or l[-1] == '.', \
            'floor row %d is %d wide in a %d-wide section: padding would open a hole after %r' % (i, len(l), w, l[-6:])
    out = Section(l.ljust(w, '.') for l in lines)
    if over is not None:
        assert len(over.rstrip('.')) <= w, 'overlay row is wider than its section: %r' % over
        bad = set(over) - OVERLAY_GLYPHS
        assert not bad, 'overlay row has %r' % ''.join(sorted(bad))
        out.overlay = over.ljust(w, '.')
    return out


def join(*blocks):
    rows = Rows(''.join(b[i] for b in blocks) for i in range(H))
    parts = []
    x = 0
    over = []
    any_over = False
    for b in blocks:
        parts.append((b, x))
        o = getattr(b, 'overlay', None)
        if o is not None:
            any_over = True
        over.append(o if o is not None else '.' * len(b[0]))
        x += len(b[0])
    rows.parts = parts
    rows.overlay = ''.join(over) if any_over else None
    return rows


def x_of(rows, section, dx=0, n=0):
    """The absolute column of dx within the n-th use of section in rows."""
    k = 0
    for b, x0 in rows.parts:
        if b is section:
            if k == n:
                return x0 + dx
            k += 1
    raise AssertionError('section not in this level (use %d)' % n)


def _place(rows, p):
    """An absolute x (int), or (section, dx) / (section, dx, n)."""
    if isinstance(p, int):
        return p
    return x_of(rows, *p)


# ---------------------------------------------------------------- the overlay

def overlay_runs(line, chars):
    """[(x0, x1, ch)]: runs of the same glyph from chars in an overlay line
    (inclusive columns)."""
    out = []
    x = 0
    while line is not None and x < len(line):
        ch = line[x]
        if ch in chars:
            x1 = x
            while x1 + 1 < len(line) and line[x1 + 1] == ch:
                x1 += 1
            out.append((x, x1, ch))
            x = x1 + 1
        else:
            x += 1
    return out


def gusts_header(line):
    """'120-131:R:A, 150-161:L:B' from an overlay line, or ''."""
    kinds = {'(': ('L', 'A'), ')': ('R', 'A'), '[': ('L', 'B'), ']': ('R', 'B')}
    return ', '.join('%d-%d:%s:%s' % (a, b, kinds[c][0], kinds[c][1]) for a, b, c in overlay_runs(line, '()[]'))


def hush_header(line):
    """'52-75, 200-227' from an overlay line, or ''."""
    return ', '.join('%d-%d' % (a, b) for a, b, _c in overlay_runs(line, ';'))


def ranges_header(pairs):
    return ', '.join('%d-%d' % (a, b) for a, b in pairs)


def phases_header(d):
    """{x: turns} -> '212=0.25, 220=0.5' (x ascending)."""
    return ', '.join('%d=%s' % (x, _num(v)) for x, v in sorted(d.items()))


def _num(v):
    s = ('%.4f' % float(v)).rstrip('0').rstrip('.')
    return s if s else '0'


def mirror_rows(rows):
    """The Descent's mirror of rows (and its overlay): reversed, with exactly
    the MIRROR swaps."""
    out = Rows(''.join(MIRROR.get(c, c) for c in reversed(r)) for r in rows)
    if getattr(rows, 'overlay', None) is not None:
        out.overlay = ''.join(MIRROR_OVERLAY.get(c, c) for c in reversed(rows.overlay))
    return out


# ---------------------------------------------------------------- writing

def _order_hints(kv, rows):
    """Hints are written left to right; the game hands them to the signs in
    reading order (row by row), so reorder them to match."""
    key, value = kv
    if key != 'hints':
        return kv
    hints = value.split('|')
    signs = [(x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == '@']
    assert len(signs) == len(hints), 'level has %d signs but %d hints' % (len(signs), len(hints))
    by_x = sorted(signs)
    text = {pos: hints[i] for i, pos in enumerate(by_x)}
    reading = sorted(signs, key=lambda p: (p[1], p[0]))
    return (key, '|'.join(text[p] for p in reading))


def _report(name, rows):
    """Where the start, altars, bell and boss are, for the checkpoint-gap rule."""
    marks = sorted([x for y, r in enumerate(rows) for x, ch in enumerate(r) if ch in 'PKEX'])
    gaps = [b - a for a, b in zip(marks, marks[1:])]
    return 'checkpoints at %s (gaps %s)' % (marks, gaps)


def check_legend(name, rows):
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            assert ch in LEGEND, '%s: unknown glyph %r at %d,%d' % (name, ch, x, y)


def check_sign_budget(name, rows):
    """A level's signs ('@') stay within the budget: 1-1 at most 4, every
    other level at most 3 (the feel labs, debug only, are free)."""
    n = sum(r.count('@') for r in rows)
    assert name.startswith('lab-') or n <= (4 if name == '1-1' else 3), \
        '%s has %d signs: the budget is %d' % (name, n, 4 if name == '1-1' else 3)


def write(name, header, rows, out_dir=None):
    check_legend(name, rows)
    if SIGN_BUDGET:
        check_sign_budget(name, rows)
    header = list(header)
    keys = [k for k, _v in header]
    over = getattr(rows, 'overlay', None)
    if over is not None:
        extra = []
        g = gusts_header(over)
        if g and 'gusts' not in keys:
            extra.append(('gusts', g))
        hz = hush_header(over)
        if hz and 'hush' not in keys:
            extra.append(('hush', hz))
        # Before the hints (which stay last, as v2 wrote them).
        at = keys.index('hints') if 'hints' in keys else len(header)
        header = header[:at] + extra + header[at:]
    header = [_order_hints(kv, rows) for kv in header]
    text = ''.join('%s: %s\n' % kv for kv in header) + '---\n' + '\n'.join(r.rstrip('.') for r in rows) + '\n'
    d = out_dir or OUT
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, name + '.txt'), 'w') as f:
        f.write(text)
    print('%s: %d x %d  %s' % (name, max(len(r) for r in rows), len(rows), _report(name, rows)))
    return text


def header_of(entry, rows):
    """An entry's ordered header: its own 'header' list verbatim, or one built
    from its keys in HEADER_ORDER (x-valued keys resolved against rows; a
    roster dict, a threat number, an anoint list and any span-valued key
    written by their toolkit helpers). An entry's 'world' (a fixture's) and
    'out_dir' aren't headers."""
    if 'header' in entry:
        return list(entry['header'])
    vals = {}
    if 'name' in entry:
        vals['title'] = entry['name']
    vals['subtitle'] = entry.get('subtitle', entry['id'])
    skip = {'id', 'name', 'sections', 'header', 'subtitle', 'out_dir', 'world'}
    for k, v in entry.items():
        if k in skip:
            continue
        if k == 'hints' and not isinstance(v, str):
            v = '|'.join(v)
        elif k in ('cog_phase', 'weight_phase') and isinstance(v, dict):
            v = phases_header({_place(rows, p): t for p, t in v.items()})
        elif k == 'chase' and not isinstance(v, str):
            v = ranges_header([(_place(rows, a), _place(rows, b)) for a, b in v])
        elif k == 'roster' and isinstance(v, dict):
            v = roster_header(v)
        elif k == 'threat' and not isinstance(v, str):
            v = _num(v)
        elif k == 'anoint' and not isinstance(v, str):
            v = anoint_header(rows, v, entry_world(entry), entry['id'])
        elif _has_span(v):
            v = spans_header(rows, v)
        vals[k] = str(v)
    out = [(k, vals.pop(k)) for k in HEADER_ORDER if k in vals]
    # Keys HEADER_ORDER doesn't know (the modes' private ones) go before the hints.
    extra = [(k, v) for k, v in vals.items()]
    if out and out[-1][0] == 'hints':
        return out[:-1] + extra + [out[-1]]
    return out + extra


def build(entry, out_dir=None):
    """Joins an entry's sections, checks its Build 2 tables (check_entry)
    and writes its file."""
    rows = join(*entry['sections'])
    header = header_of(entry, rows)
    check_entry(entry, rows, header)
    return write(entry['id'], header, rows, out_dir or entry.get('out_dir'))


# The seam every section of every world meets at a door (1-4 and 2-4 put it
# before their arenas; the Descent's rooms meet at it).
T_OPEN = block('''
 0|##
 1|##
 2|..
 3|..
 4|..
 5|..
 6|..
 7|..
 8|..
 9|..
10|..
11|..
12|..
13|##
14|##
''')


# ================================================================ the toolkit
# Build 2's (the spec's build_plan step 2): what the level redesigns are cut
# with, and the rules that replace the tests' fixed counts, widths and altar
# x. Every table and key is optional: a level that declares none writes no
# new header and is built and tested as before.

GAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'game', 'scripts')

# A level's threat (cost per 100 tiles, EnemyKinds.COST) within 10% of its
# declared THREAT; in a world each regular level's declared threat at least
# RAMP_STEP over the level before it, less RAMP_TOL (today's worlds are flat,
# so the step is 0 and the tolerance a Rattle or so in 340 tiles; the
# redesign's ramp is +1.0 a step: X-1 < X-2 < X-3).
THREAT_SLACK = 0.10
RAMP_STEP = 0.0
RAMP_TOL = 0.25
# Under the packs twist a placed pack (one kind within PACK_TILES on a floor,
# hushling.gd's pack_tiles) is budgeted at the size it comes to in play: the
# Hushlings' pack and a Glassmite trio 3, a Creepbone's lane partner and an
# Unwick's pair 2 (the spec's menu: hushling, glassmite, creepbone, unwick).
PACK_SIZE = {'hushling': 3, 'glassmite': 3, 'creepbone': 2, 'unwick': 2}
PACK_TILES = 4
# A regular level's altars (3-5, as its gaps need), and a sealed room's door
# (the left column of a duel:, ambush: or room: range) has an altar at most
# 8 tiles before it, as a boss arena's does (test_content).
ALTARS = (3, 5)
DOOR_ALTAR = 8
SEALED_KEYS = ('duel', 'ambush', 'room')
# Each kind's home world, for the roster's rules from World 3 on (a headline
# kind is the level's world's own, a guest an earlier world's): v2's kinds
# are World 1's (the Brinejaw World 2's), v3's their world's (contract §6.3).
HOME = {'brinejaw': 2, 'rootling': 3, 'weepcap': 3, 'rattlehound': 3, 'creepbone': 3,
        'tickwind': 4, 'spurwheel': 4, 'frostbuckle': 4, 'hoarowl': 4,
        'glassmite': 5, 'gustling': 5, 'refractor': 5, 'paneguard': 5,
        'hushling': 6, 'stillmaw': 6, 'unwick': 6, 'lurecoil': 6}
ROSTER_KEYS = ('headline', 'support', 'guest', 'rattle_max', 'fodder_max', 'count')
# Section roles (check_roles): each section's letters, in this order, from
# what it holds (start, a Lidlurk's vault, the Dread, an altar, the bell, a
# boss); a section with none is content, C.
ROLE_MARKS = (('P', 'S'), ('M', 'V'), ('D', 'D'), ('K', 'A'), ('E', 'B'), ('X', 'X'))


def _gd_const(script, name):
    """The literal of `const <name>` in one of the game's scripts (a number,
    or a dict or list of strings and numbers; comments dropped), so the
    checks here read the game's own tables and can't drift from them."""
    with open(os.path.join(GAME, script)) as f:
        src = f.read()
    m = re.search(r'^const %s\s*(?::\s*[\w\[\]]+\s*)?:?=\s*' % name, src, re.M)
    assert m, '%s has no const %s' % (script, name)
    i = m.end()
    if src[i] not in '[{':
        return ast.literal_eval(src[i:].split('\n', 1)[0].split('#', 1)[0].strip())
    out = []
    depth = 0
    quote = None
    while True:
        c = src[i]
        if quote:
            out.append(c)
            if c == '\\':
                out.append(src[i + 1])
                i += 1
            elif c == quote:
                quote = None
        elif c == '#':
            i = src.index('\n', i)
            continue
        else:
            out.append(c)
            if c in '"\'':
                quote = c
            elif c in '[{':
                depth += 1
            elif c in ']}':
                depth -= 1
                if depth == 0:
                    break
        i += 1
    return ast.literal_eval(''.join(out))


@functools.lru_cache(maxsize=None)
def game():
    """The game's tables the toolkit checks against (read once): the legend's
    entities and their PLACEMENT, each kind's COST, TIER_COST and ROLE
    (enemy_kinds.gd), and who may be Anointed with which Omens (elites.gd).
    'monsters' maps a monster glyph to its kind (a nest to its Gutterwing)."""
    g = {
        'glyphs': _gd_const('level_data.gd', 'ENTITY_GLYPHS'),
        'placement': _gd_const('level_data.gd', 'PLACEMENT'),
        'cost': _gd_const('enemy_kinds.gd', 'COST'),
        'tier_cost': _gd_const('enemy_kinds.gd', 'TIER_COST'),
        'role': _gd_const('enemy_kinds.gd', 'ROLE'),
        'eligible': _gd_const('elites.gd', 'ELIGIBLE'),
        'omens': _gd_const('elites.gd', 'OMENS'),
        'v3_omens': _gd_const('elites.gd', 'V3_OMENS'),
        'world_omens': _gd_const('elites.gd', 'WORLD_OMENS'),
        'dusk_waits': _gd_const('elites.gd', 'DUSK_WAITS'),
        'vengeful_from': _gd_const('elites.gd', 'DUSK_VENGEFUL_FROM'),
        'never_on': _gd_const('elites.gd', 'NEVER_ON'),
        'max_omens': _gd_const('elites.gd', 'MAX_OMENS'),
    }
    g['monsters'] = {ch: k for ch, k in g['glyphs'].items() if k in g['cost']}
    g['monsters']['N'] = 'gutterwing'
    return g


def world_of(level_id):
    """'3-2' -> 3, '1-S' -> 1, anything else (a lab, a fixture) 0 (as
    LevelData.world_of)."""
    if len(level_id) >= 2 and level_id[1] == '-' and level_id[0] in '123456789':
        return int(level_id[0])
    return 0


def entry_world(entry):
    """An entry's world: its 'world' (a fixture's, whose id names none), else
    its id's."""
    return int(entry.get('world', world_of(entry['id'])))


def home_of(kind):
    return HOME.get(kind, 1)


# ---------------------------------------------------------------- copies of sections

def swap(sec, cells=None, glyphs=None):
    """A copy of sec (its overlay kept): every glyph in glyphs {old: new}
    swapped (e.g. {'s': '.'}: its Rattles out), then the cells {(x, y):
    glyph} set. Each cell must be inside the section, each glyph in the
    legend, and a glyph swap must find what it swaps (moved from w5.py)."""
    rows = [list(r) for r in sec]
    w = len(sec[0])
    for old, new in (glyphs or {}).items():
        assert new in LEGEND, 'swap: %r is no glyph' % new
        n = 0
        for r in rows:
            for i, ch in enumerate(r):
                if ch == old:
                    r[i] = new
                    n += 1
        assert n, 'swap: no %r in the section to swap for %r' % (old, new)
    for (x, y), ch in (cells or {}).items():
        assert 0 <= y < len(rows) and 0 <= x < w, 'swap: (%d, %d) is outside the %d-wide section' % (x, y, w)
        assert ch in LEGEND, 'swap: %r is no glyph' % ch
        rows[y][x] = ch
    out = Section(''.join(r) for r in rows)
    out.overlay = getattr(sec, 'overlay', None)
    return out


# The frozen legend's tiles (level_data.gd FLAGS, contract.md §2), as the
# placement check needs them: solid, a one-way top, a vine, and the water
# cells (water, a float, and the things that sit in water: a Brinejaw, a
# Lurecoil, a buoy, a grasp). A pod, glowfruit, Creepbone or Dread drawn
# with a vine above or below it stands on the vine (VINE_CARRIERS).
SOLID = set('#B?WRUFIZ<>G')
LEDGE = set('=%_')
CLIMB = set('{}')
WATERY = set(':&fJH7')
CARRIERS = set('*8iD')


def _tile(rows, x, y, edge):
    """'solid', 'ledge', 'climb', 'water' or 'air' at (x, y): past the sides
    edge ('solid' for a level, as LevelData.tile; 'air' for a lone section,
    which can't lean on a neighbour), above and below the rows air."""
    if y < 0 or y >= len(rows):
        return 'air'
    if x < 0 or x >= len(rows[y]):
        return edge
    ch = rows[y][x]
    if ch in SOLID:
        return 'solid'
    if ch in LEDGE:
        return 'ledge'
    if ch in CLIMB:
        return 'climb'
    if ch in WATERY:
        return 'water'
    if ch in CARRIERS:
        for dy in (-1, 1):
            if 0 <= y + dy < len(rows) and x < len(rows[y + dy]) and rows[y + dy][x] in CLIMB:
                return 'climb'
    return 'air'


def placement_problems(rows, edge='solid', only=None):
    """[(x, y, glyph, what)]: every entity drawn where its PLACEMENT row
    (level_data.gd) says it can't stand, judged as test_core judges a level
    file. only: the cells to judge (a stamp's), else every cell."""
    g = game()
    out = []
    cells = only if only is not None else [(x, y) for y in range(len(rows)) for x in range(len(rows[y]))]
    for x, y in cells:
        ch = rows[y][x]
        kind = 'float' if ch == '&' else g['glyphs'].get(ch)
        if kind is None:
            continue
        rule = g['placement'].get(kind, 'air')
        here = _tile(rows, x, y, edge)
        above = _tile(rows, x, y - 1, edge)
        below = _tile(rows, x, y + 1, edge)
        floor = below in ('solid', 'ledge')
        ceiling = above == 'solid'
        vine = here == 'climb'
        ok = {'floor': floor, 'ceiling': ceiling, 'deep_water': here == 'water' and below == 'water',
              'surface': here == 'water' and above != 'water',
              'vine_or_wall': vine or _tile(rows, x - 1, y, edge) == 'solid' or _tile(rows, x + 1, y, edge) == 'solid',
              'hang': ceiling or above == 'ledge', 'mount': floor or ceiling or vine,
              'ceiling_or_vine': ceiling or vine}.get(rule, True)
        if not ok:
            out.append((x, y, ch, '%s (%s)' % (kind, rule)))
    return out


# Encounter stamps (the spec's mixed groups): small authored fights where two
# or three kinds make each other worse, as (dx, dy, glyph) from the stamp's
# anchor (the first monster's cell). stamp() draws one into a copy of a
# section; the section's own drawing gives it the post, the vines, the glass
# or the belts it plays on. Each fits one 26 x 12 view (self_check).
STAMPS = {
    # A Bonebow on a post covers a Thornback on the floor 3 rows down, 4 on.
    'crossfire': [(0, 0, 'a'), (4, 3, 't')],
    # A Thornback holds the floor while Creepbones lunge from the vines 4
    # tiles either side of it, 3 rows up.
    'lane_and_thorn': [(0, 0, 't'), (-4, -3, 'i'), (4, -3, 'i')],
    # A Rattlehound's chase runs onto a strip of Rootling mounds.
    'hound_and_mounds': [(0, 0, 'm'), (5, 0, 'r'), (8, 0, 'r')],
    # A Thornback on a stone island, Glassmites on the glass either side.
    'island_guard': [(0, 0, 't'), (-5, 0, 'x'), (5, 0, 'x')],
    # A Frostbuckle on the stone between belts, two Tickwinds riding at it.
    'buckle_on_belts': [(0, 0, 'e'), (-6, 0, 'j'), (-4, 0, 'j')],
    # A Hoarowl on its bracket watching a Tickwind squad 3 rows down.
    'owl_watch': [(0, 0, 'u'), (2, 3, 'j'), (5, 3, 'j')],
    # Hushlings by a lamp while a Stillmaw drifts in to eat it.
    'lamp_eaters': [(0, 0, 'n'), (2, 0, 'n'), (-4, -4, '5')],
}


def stamp(sec, name, dx, dy):
    """A copy of sec with STAMPS[name] drawn at (dx, dy), its anchor: every
    cell it takes must be inside the section and air (a vine, for a
    Creepbone: it rides it), and every glyph must stand where its PLACEMENT
    row says, judged in the section alone."""
    cells = {}
    for sx, sy, ch in STAMPS[name]:
        x, y = dx + sx, dy + sy
        assert 0 <= y < H and 0 <= x < len(sec[0]), \
            'stamp %s at (%d, %d): (%d, %d) is outside the section' % (name, dx, dy, x, y)
        assert sec[y][x] == '.' or (ch in CARRIERS and sec[y][x] in CLIMB), \
            'stamp %s at (%d, %d): (%d, %d) holds %r, not air (or a vine for a Creepbone)' % (name, dx, dy, x, y, sec[y][x])
        cells[(x, y)] = ch
    out = swap(sec, cells)
    bad = placement_problems(out, 'air', sorted(cells))
    assert not bad, 'stamp %s at (%d, %d): %s' % (name, dx, dy, ', '.join('%s at %d,%d' % (w, x, y) for x, y, _c, w in bad))
    return out


# ---------------------------------------------------------------- range headers

class Span(object):
    """A run of one section's columns in a level (span()), written into a
    range header as 'x0-x1' (absolute, inclusive) or, paired with a value,
    'x0-x1@value'."""

    def __init__(self, section, dx0=0, dx1=None, n=0):
        self.section, self.dx0, self.dx1, self.n = section, dx0, dx1, n

    def cols(self, rows):
        dx1 = len(self.section[0]) - 1 if self.dx1 is None else self.dx1
        return x_of(rows, self.section, self.dx0, self.n), x_of(rows, self.section, dx1, self.n)


def span(section, dx0=0, dx1=None, n=0):
    """span(SEC): all of a section's columns (a sealed room's, its walls
    included); span(SEC, 2, 21): its columns 2-21; n: its n-th use. An
    entry's value may be a Span, a list of Spans or (Span, value) pairs, or
    {Span: value}: 'duel': span(WT_HALL), 'belt_flip': [(span(ES_FLIP, 2, 21), 8)]."""
    return Span(section, dx0, dx1, n)


def _has_span(v):
    if isinstance(v, Span):
        return True
    if isinstance(v, dict):
        return any(isinstance(k, Span) for k in v)
    if isinstance(v, (list, tuple)):
        return any(isinstance(i, Span) or (isinstance(i, tuple) and i and isinstance(i[0], Span)) for i in v)
    return False


def spans_header(rows, v):
    """'x0-x1, x0-x1@value' (x ascending) from a Span, a list of Spans or
    (Span, value) pairs, or {Span: value}."""
    if isinstance(v, Span):
        v = [v]
    elif isinstance(v, dict):
        v = list(v.items())
    out = []
    for item in v:
        sp, val = (item, None) if isinstance(item, Span) else item
        a, b = sp.cols(rows)
        tail = '' if val is None else '@%s' % (_num(val) if isinstance(val, (int, float)) else val)
        out.append((a, '%d-%d%s' % (a, b, tail)))
    return ', '.join(s for _a, s in sorted(out))


def ranges_of(value):
    """[(x0, x1)] from a range header's value ('a-b, c-d@8')."""
    out = []
    for part in str(value).split(','):
        m = re.match(r'^\s*(\d+)\s*-\s*(\d+)', part)
        if m:
            out.append((int(m.group(1)), int(m.group(2))))
    return out


# ---------------------------------------------------------------- forced Anointed

def omen_pool(kind, world, diff='dusk'):
    """The Omens a kind may carry in a world on a difficulty, as elites.gd
    omen_pool: v2's five (no Vengeful on Dusk before DUSK_VENGEFUL_FROM), the
    world's v3 ones (less DUSK_WAITS on Dusk), less NEVER_ON."""
    g = game()
    extra = g['world_omens'].get(world, [])
    waits = g['dusk_waits'].get(world, []) if diff == 'dusk' else []
    pool = []
    for o in g['omens']:
        if o in g['v3_omens'] and (o not in extra or o in waits):
            continue
        if kind in g['never_on'].get(o, []):
            continue
        if diff == 'dusk' and o == 'Vengeful' and world < g['vengeful_from']:
            continue
        pool.append(o)
    return pool


def anoint_header(rows, cells, world=0, level_id=''):
    """The anoint: header (its monsters are Anointed every run):
    'x,y[:Omen+Omen[:Name]]; x,y', from cells (section, dx, row[, omens[,
    name]]) or (x, y[, ...]) absolute, omens 'Swift+Warded' or a list ('':
    rolled as the World would, as 3-S's are). rows: the level's joined rows,
    or its sections. Checked: each cell holds a kind elites.gd may anoint,
    each Omen is in its Dusk pool there (omen_pool: so no difficulty falls
    back to a roll), at most MAX_OMENS; World 1-2 at most one, with one
    Omen, and never in 1-1 (the gentle on-ramp)."""
    g = game()
    if not isinstance(rows, Rows):
        rows = join(*rows)
    out = []
    for c in cells:
        if isinstance(c[0], int):
            x, y, rest = c[0], c[1], list(c[2:])
        else:
            x, y, rest = x_of(rows, c[0], c[1]), c[2], list(c[3:])
        omens = rest[0] if rest else ''
        name = rest[1] if len(rest) > 1 else ''
        omens = [o for o in (omens.split('+') if isinstance(omens, str) else omens) if o]
        where = '%s anoint %d,%d' % (level_id or 'a level', x, y)
        assert 0 <= y < len(rows) and 0 <= x < len(rows[y]), '%s is outside the level' % where
        kind = g['monsters'].get(rows[y][x])
        assert kind in g['eligible'], '%s holds %r, no kind elites.gd may anoint' % (where, rows[y][x])
        pool = omen_pool(kind, world)
        for o in omens:
            assert o in pool, '%s: a %s may not carry %s in World %d on Dusk (%s)' % (where, kind, o, world, '+'.join(pool))
        assert len(set(omens)) == len(omens) and len(omens) <= g['max_omens'], '%s: Omens %s' % (where, omens)
        assert not re.search(r'[;:,]', name) and len(name) <= 24, \
            '%s: its name %r (no ; : or , and 24 letters at most)' % (where, name)
        if 1 <= world <= 2:
            assert level_id != '1-1' and len(cells) <= 1 and len(omens) <= 1, \
                '%s: World 1-2 takes at most one set piece, with one Omen, and none in 1-1' % where
        s = '%d,%d' % (x, y)
        if omens or name:
            s += ':' + '+'.join(omens)
        if name:
            s += ':' + name
        out.append(s)
    return '; '.join(out)


def anoint_cells(value):
    """[(x, y, [omens], name)] from an anoint: header's value."""
    out = []
    for part in str(value).split(';'):
        bits = part.strip().split(':')
        xy = bits[0].split(',')
        if len(xy) != 2 or not xy[0].strip().isdigit() or not xy[1].strip().isdigit():
            continue
        omens = [o.strip() for o in bits[1].split('+') if o.strip()] if len(bits) > 1 else []
        out.append((int(xy[0]), int(xy[1]), omens, bits[2].strip() if len(bits) > 2 else ''))
    return out


# ---------------------------------------------------------------- rosters and threat

def cast_of(rows):
    """{kind: n}: the monsters a level's rows place (a nest counts as its
    Gutterwing; the Dread and the boss have their own headers)."""
    mons = game()['monsters']
    out = {}
    for r in rows:
        for ch in r:
            k = mons.get(ch)
            if k:
                out[k] = out.get(k, 0) + 1
    return out


def _packs(cells):
    """Groups of cells within PACK_TILES across and a row up or down of one
    another (a placed pack, as hushling.gd finds one)."""
    groups = []
    for c in sorted(cells):
        near = [g for g in groups if any(abs(c[0] - o[0]) <= PACK_TILES and abs(c[1] - o[1]) <= 1 for o in g)]
        merged = [c]
        for g in near:
            merged += g
            groups.remove(g)
        groups.append(merged)
    return groups


def threat_of(rows, anoint=(), twist=''):
    """Threat cost per 100 tiles (EnemyKinds.COST, the Dread aside): a
    forced Anointed (a cell in anoint) at TIER_COST's x2.5, and under the
    packs twist each placed pack of a PACK_SIZE kind at that size at least
    (tests/level_rules.gd threat_of counts the same)."""
    g = game()
    forced = set(anoint)
    packs = {}
    cost = 0.0
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            k = g['monsters'].get(ch)
            if not k:
                continue
            cost += g['cost'][k] * (g['tier_cost']['anointed'] if (x, y) in forced else 1.0)
            if twist == 'packs' and k in PACK_SIZE:
                packs.setdefault(k, []).append((x, y))
    for k, cells in packs.items():
        for group in _packs(cells):
            cost += g['cost'][k] * max(0, PACK_SIZE[k] - len(group))
    return cost * 100.0 / max(len(r) for r in rows)


def _band(v):
    return (int(v[0]), int(v[1])) if isinstance(v, (tuple, list)) else (int(v), int(v))


def roster_header(roster):
    """'headline=a,b; support=c; guest=d; rattle_max=3; fodder_max=0.75;
    count=18-24' (empty lists and an absent count left out)."""
    parts = ['%s=%s' % (k, ','.join(roster[k])) for k in ('headline', 'support', 'guest') if roster.get(k)]
    parts.append('rattle_max=%d' % roster['rattle_max'])
    parts.append('fodder_max=%s' % _num(roster['fodder_max']))
    if 'count' in roster:
        lo, hi = _band(roster['count'])
        parts.append('count=%d' % lo if lo == hi else 'count=%d-%d' % (lo, hi))
    return '; '.join(parts)


def roster_problems(level_id, cast, roster, world=None):
    """What breaks a level's declared roster (the spec's per-level rosters),
    as strings: every kind it places is declared (headline, support or
    guest), a Rattle only up to rattle_max (never listed) and one Lidlurk
    (the vault's, never listed); every headline kind placed; from World 3 a
    headline kind is the world's own, a guest an earlier world's and no
    support kind a later one's; the fodder share (EnemyKinds.ROLE, of every
    monster) within fodder_max, and the count within count (n or (lo, hi)).
    world: the level's (else its id's)."""
    g = game()
    out = ['unknown roster key %s' % k for k in sorted(set(roster) - set(ROSTER_KEYS))]
    out += ['the roster has no %s' % k for k in ('headline', 'rattle_max', 'fodder_max') if k not in roster]
    if out:
        return out
    world = world_of(level_id) if world is None else world
    head, sup, guest = list(roster['headline']), list(roster.get('support', [])), list(roster.get('guest', []))
    for k in head + sup + guest:
        if k in ('skeleton', 'lidlurk') or k not in g['cost']:
            out.append('%s is listed (a Rattle is rattle_max, a Lidlurk the vault, else no kind)' % k)
    for k, n in sorted(cast.items()):
        if k == 'skeleton':
            if n > roster['rattle_max']:
                out.append('%d Rattles (rattle_max %d)' % (n, roster['rattle_max']))
        elif k == 'lidlurk':
            if n > 1:
                out.append('%d Lidlurks (one: the vault)' % n)
        elif k not in head + sup + guest:
            out.append('%d %s it does not declare' % (n, k))
    for k in head:
        if cast.get(k, 0) == 0:
            out.append('no %s, a headline kind' % k)
    if world >= 3:
        out += ['%s is World %d\'s, no headline in World %d' % (k, home_of(k), world) for k in head if home_of(k) != world]
        out += ['%s is no guest from an earlier world' % k for k in guest if home_of(k) >= world]
        out += ['%s is from a later world' % k for k in sup if home_of(k) > world]
    n = sum(cast.values())
    fodder = sum(v for k, v in cast.items() if g['role'].get(k) == 'fodder')
    if n and fodder > roster['fodder_max'] * n + 1e-9:
        out.append('fodder %d of %d (fodder_max %s)' % (fodder, n, _num(roster['fodder_max'])))
    if 'count' in roster:
        lo, hi = _band(roster['count'])
        if not lo <= n <= hi:
            out.append('%d monsters (count %d-%d)' % (n, lo, hi))
    return out


def check_roster(name, rows, roster, world=None):
    """Asserts a level's rows keep its declared roster (roster_problems)."""
    probs = roster_problems(name, cast_of(rows), roster, world)
    assert not probs, '%s breaks its roster: %s' % (name, '; '.join(probs))


def check_threat(name, rows, target, anoint=(), twist=''):
    """Asserts a level's threat (threat_of) within THREAT_SLACK of its
    declared one, and returns it."""
    got = threat_of(rows, anoint, twist)
    assert abs(got - target) <= target * THREAT_SLACK + 1e-9, \
        '%s: threat %.2f per 100 tiles, declared %s (within %d%%)' % (name, got, _num(target), round(THREAT_SLACK * 100))
    return got


def check_entry(entry, rows, header):
    """An entry's Build 2 tables, checked as its file is written: its roster
    (roster_problems) and its threat (threat_of within THREAT_SLACK of its
    declared one, its anoint: cells at x2.5). The anoint: cells and the
    stamps are checked where they're made (anoint_header, stamp)."""
    if not isinstance(entry.get('roster'), dict) and 'threat' not in entry:
        return
    hd = dict(header)
    if isinstance(entry.get('roster'), dict):
        check_roster(entry['id'], rows, entry['roster'], entry_world(entry))
    if 'threat' in entry:
        anoint = [(x, y) for x, y, _o, _n in anoint_cells(hd.get('anoint', ''))]
        check_threat(entry['id'], rows, float(entry['threat']), anoint, hd.get('twist', '').strip())


# ---------------------------------------------------------------- a world's rules

def roles_of(sections):
    """'S C C A ...': each section's roles (ROLE_MARKS; C for content)."""
    out = []
    for sec in sections:
        s = ''.join(sec)
        out.append(''.join(r for ch, r in ROLE_MARKS if ch in s) or 'C')
    return ' '.join(out)


def checkpoint_problems(rows, header, max_gap):
    """A regular level's checkpoints (start, altars, bell): at most max_gap
    apart, ALTARS altars, and an altar at most DOOR_ALTAR tiles before every
    sealed room's door (the left column of each SEALED_KEYS range)."""
    marks = sorted(x for r in rows for x, ch in enumerate(r) if ch in 'PKEX')
    altars = sorted(x for r in rows for x, ch in enumerate(r) if ch == 'K')
    out = []
    worst = max([b - a for a, b in zip(marks, marks[1:])] or [0])
    if worst > max_gap:
        out.append('checkpoints %d tiles apart (at most %d): %s' % (worst, max_gap, marks))
    if not ALTARS[0] <= len(altars) <= ALTARS[1]:
        out.append('%d altars (%d-%d)' % (len(altars), ALTARS[0], ALTARS[1]))
    for k in SEALED_KEYS:
        for x0, _x1 in ranges_of(header.get(k, '')):
            if not any(0 <= x0 - a <= DOOR_ALTAR for a in altars):
                out.append('no altar within %d tiles of the %s door at %d (altars %s)' % (DOOR_ALTAR, k, x0, altars))
    return out


def world_problems(entries, max_gap):
    """What breaks a world's rules across its regular levels (the entries
    with a roster), as strings: the threat ramp (each declared threat at
    least RAMP_STEP over the one before, less RAMP_TOL), each level's
    checkpoint_problems, a declared 'roles' that isn't what its sections
    hold, and a re-cut level (one that declares its 'roles') that shares its
    section roles with a sibling (the spec: no two alike)."""
    regular = sorted((e for e in entries if 'roster' in e), key=lambda e: e['id'])
    out = []
    prev = None
    for e in regular:
        t = e.get('threat')
        if t is None:
            continue
        if prev is not None and float(t) < prev[1] + RAMP_STEP - RAMP_TOL:
            out.append('threat %s in %s after %s in %s (the ramp: +%s, less %s)'
                       % (_num(t), e['id'], _num(prev[1]), prev[0], _num(RAMP_STEP), _num(RAMP_TOL)))
        prev = (e['id'], float(t))
    seqs = {}
    for e in regular:
        rows = join(*e['sections'])
        out += ['%s: %s' % (e['id'], p) for p in checkpoint_problems(rows, dict(header_of(e, rows)), max_gap)]
        seqs[e['id']] = roles_of(e['sections'])
        if 'roles' in e and ' '.join(e['roles'].split()) != seqs[e['id']]:
            out.append('%s declares roles %s but its sections hold %s' % (e['id'], e['roles'], seqs[e['id']]))
    for i, a in enumerate(regular):
        for b in regular[i + 1:]:
            if ('roles' in a or 'roles' in b) and seqs[a['id']] == seqs[b['id']]:
                out.append('%s and %s share their section roles (%s)' % (a['id'], b['id'], seqs[a['id']]))
    return out


def check_roles(entries, max_gap):
    """Asserts a world's rules across its regular levels (world_problems:
    the threat ramp, each level's checkpoints and altar gaps, and its
    section roles)."""
    probs = world_problems(entries, max_gap)
    assert not probs, 'the world\'s rules: ' + '; '.join(probs)


def world_tables(entries, roster, threat, max_gap):
    """Hands each regular level its row of its world's ROSTER and THREAT
    (written as its roster: and threat: headers, and checked as it's
    written: check_entry), then checks the world's rules across them
    (check_roles). A level in neither table keeps its old header."""
    for e in entries:
        if e['id'] in roster:
            e['roster'] = roster[e['id']]
        if e['id'] in threat:
            e['threat'] = threat[e['id']]
    check_roles(entries, max_gap)


# ---------------------------------------------------------------- the toolkit's proof

def _fails(fn, *args):
    """True when fn(*args) trips one of the toolkit's asserts."""
    try:
        fn(*args)
    except AssertionError:
        return True
    return False


def self_check():
    """The toolkit's own proof, run with every build (tools/levels/toolkit.py):
    each tool and check passes what it should and catches what it shouldn't,
    on made-up sections. tests/test_toolkit.gd proves the game's side (the
    rules read back from tests/fixtures/toolkit-*.txt)."""
    g = game()
    # The game's tables read whole: every monster glyph has a cost and a role.
    assert len(g['cost']) >= 25 and g['tier_cost']['anointed'] == 2.5 and 'Swift' in g['omens'], 'the game tables'
    assert all(k in g['role'] for k in g['monsters'].values()), 'every monster kind has a ROLE'
    # A floor 20 wide with a stone post (x 13, rows 10-12) and two vines (x 2
    # and 10, rows 6-10), and a gust overlay.
    rows = ['.' * 20] * 13 + ['#' * 20] * 2
    for y in range(6, 11):
        rows[y] = '..{.......{.........'
    for y in range(10, 13):
        rows[y] = rows[y][:13] + '#' + rows[y][14:]
    sec = block('\n'.join(rows) + '\n Z|....((((............\n')
    # swap: glyphs, then cells; the overlay kept; out of bounds, no glyph, a
    # glyph swap that finds nothing all fail.
    s2 = swap(sec, {(6, 9): 's'}, {'{': '}'})
    assert s2[9][6] == 's' and s2[7][2] == '}' and sec[7][2] == '{' and s2.overlay == sec.overlay, 'swap'
    assert _fails(swap, sec, {(20, 0): 's'}) and _fails(swap, sec, {(0, 0): '!?'}) and _fails(swap, sec, None, {'n': '.'}), 'swap fails'
    # stamp: a Bonebow on the post covering a Thornback; a Thornback between
    # the vines with a Creepbone on each; in the air, on stone or past the
    # edge it fails.
    st = stamp(sec, 'crossfire', 13, 9)
    assert st[9][13] == 'a' and st[12][17] == 't' and sec[9][13] == '.', 'stamp'
    lt = stamp(sec, 'lane_and_thorn', 6, 12)
    assert lt[12][6] == 't' and lt[9][2] == 'i' and lt[9][10] == 'i' and placement_problems(lt) == [], 'stamp on vines'
    assert _fails(stamp, sec, 'crossfire', 4, 5) and _fails(stamp, sec, 'crossfire', 13, 10) and _fails(stamp, sec, 'crossfire', 17, 9), 'stamp fails'
    for name, cells in STAMPS.items():
        xs, ys = [c[0] for c in cells], [c[1] for c in cells]
        assert max(xs) - min(xs) < 26 and max(ys) - min(ys) < 12 and cells[0][:2] == (0, 0), 'stamp %s fits a view' % name
        assert all(ch in g['monsters'] for _x, _y, ch in cells), 'stamp %s holds monsters' % name
    # placement: a Rattle in the air and a Creepbone off its vine are caught.
    assert placement_problems(swap(sec, {(4, 5): 's', (5, 8): 'i'}), 'air') == [(4, 5, 's', 'skeleton (floor)'), (5, 8, 'i', 'creepbone (vine_or_wall)')], 'placement'
    # span: a section's columns, its n-th use, with a value.
    lvl = join(sec, T_OPEN, sec)
    assert spans_header(lvl, [span(sec, n=1), (span(sec, 2, 5), 8)]) == '2-5@8, 22-41' and ranges_of('2-5@8, 22-41') == [(2, 5), (22, 41)], 'span'
    # anoint: written with Omens and a name, read back; a cell holding no
    # anointable kind, an Omen the kind can't carry there, World 1-2's
    # limits all fail.
    a = swap(sec, {(13, 9): 'a', (12, 12): 't', (15, 12): 'q'})
    assert anoint_header([a], [(a, 13, 9, 'Swift', 'Ash'), (12, 12, ['Warded', 'Burning']), (a, 13, 9)], 6, '6-1') \
        == '13,9:Swift:Ash; 12,12:Warded+Burning; 13,9', 'anoint_header'
    assert anoint_cells('13,9:Swift:Ash; 12,12:Warded+Burning; 13,9::The Mourner') \
        == [(13, 9, ['Swift'], 'Ash'), (12, 12, ['Warded', 'Burning'], ''), (13, 9, [], 'The Mourner')], 'anoint_cells'
    assert _fails(anoint_header, [a], [(15, 12)], 6) and _fails(anoint_header, [a], [(12, 12, 'Glassed')], 3), 'anoint fails'
    assert _fails(anoint_header, [a], [(12, 12, 'Vengeful')], 5) and not _fails(anoint_header, [a], [(12, 12, 'Vengeful')], 6), 'Vengeful from W6'
    assert _fails(anoint_header, [a], [(12, 12, 'Swift+Warded')], 2, '2-2') and _fails(anoint_header, [a], [(12, 12)], 1, '1-1'), 'W1-W2'
    # threat: a forced Anointed at x2.5; under packs a lone Hushling as 3.
    t = swap(sec, {(3, 12): 's', (12, 12): 't', (16, 12): 'n'})
    c = g['cost']
    assert abs(threat_of(t) - (c['skeleton'] + c['thornback'] + c['hushling']) * 5) < 1e-9, 'threat_of'
    assert abs(threat_of(t, [(12, 12)]) - (c['skeleton'] + 2.5 * c['thornback'] + c['hushling']) * 5) < 1e-9, 'threat_of forced'
    assert abs(threat_of(t, (), 'packs') - (c['skeleton'] + c['thornback'] + 3 * c['hushling']) * 5) < 1e-9, 'threat_of packs'
    assert len(_packs([(1, 12), (4, 12), (8, 11), (20, 12)])) == 2, 'packs chain within 4 tiles and a row'
    # roster: each rule caught.
    cast = {'hushling': 4, 'skeleton': 2, 'lidlurk': 1, 'thornback': 1, 'bonebow': 1}
    good = {'headline': ['hushling'], 'support': ['bonebow'], 'guest': ['thornback'], 'rattle_max': 2, 'fodder_max': 0.8, 'count': (8, 10)}
    assert roster_problems('6-1', cast, good) == [], roster_problems('6-1', cast, good)
    assert roster_header(good) == 'headline=hushling; support=bonebow; guest=thornback; rattle_max=2; fodder_max=0.8; count=8-10', 'roster_header'
    for bad, what in ((dict(good, rattle_max=1), 'Rattles'), (dict(good, headline=['hushling', 'stillmaw']), 'no stillmaw'),
                      (dict(good, guest=[]), 'thornback it does not declare'), (dict(good, fodder_max=0.7), 'fodder'),
                      (dict(good, count=8), 'count'), (dict(good, guest=['thornback', 'unwick']), 'no guest'),
                      (dict(good, support=['bonebow', 'skeleton']), 'listed'), (dict(good, oops=1), 'unknown')):
        p = roster_problems('6-1', cast, bad)
        assert any(what in s for s in p), 'roster catches %s (%s)' % (what, p)
    assert any('later world' in s for s in roster_problems('5-1', cast, dict(good, support=['bonebow', 'hushling']))), 'a later world'
    # A world: the ramp, the gaps, an altar by a sealed room's door, re-cut
    # levels' roles.
    alt = block('\n'.join(['.' * 20] * 12 + ['.' * 14 + 'K' + '.' * 5] + ['#' * 20] * 2))
    plain = block('\n'.join(['.' * 20] * 13 + ['#' * 20] * 2))
    room = block('\n'.join(['#' * 24] * 2 + ['#' + '.' * 22 + '#'] * 11 + ['#' * 24] * 2))
    start = swap(alt, {(14, 12): 'P'})
    bell = swap(alt, {(14, 12): 'E'})

    def ent(i, t, secs, **kw):
        return dict({'id': i, 'roster': good, 'threat': t, 'sections': secs}, **kw)
    w = [ent('6-1', 10.0, [start, alt, alt, alt, bell]), ent('6-2', 11.0, [start, alt, alt, room, alt, bell]),
         ent('6-3', 12.0, [start, alt, room, alt, alt, bell], duel=span(room))]
    assert world_problems(w, 78) == [], world_problems(w, 78)
    assert roles_of(w[2]['sections']) == 'S A C A A B', roles_of(w[2]['sections'])
    for bad, what in (([w[0], dict(w[1], threat=9.0), w[2]], 'ramp'),
                      ([w[0], dict(w[1], sections=[start, alt, plain, room, alt, bell], duel=span(room)), w[2]], 'door'),
                      ([w[0], w[1], dict(w[2], sections=[start, alt, room, room, room, alt, alt, bell])], 'apart'),
                      ([w[0], dict(w[1], sections=w[0]['sections'], roles='S A A A B'), w[2]], 'share'),
                      ([dict(w[0], roles='S C C'), w[1], w[2]], 'declares'),
                      ([w[0], dict(w[1], sections=[start] + [alt] * 6 + [bell]), w[2]], 'altars')):
        p = world_problems(bad, 30 if what == 'apart' else 78)
        assert any(what in s for s in p), 'a world catches %s (%s)' % (what, p)
