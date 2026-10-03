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
"""
import os

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

# Where written headers go when an entry doesn't give its own order.
HEADER_ORDER = ['title', 'subtitle', 'music', 'theme', 'area', 'area_abs', 'boss', 'boss_music', 'dread', 'warden',
                'secret', 'secret_prize', 'tick', 'story_start', 'story_boss', 'story_end', 'par', 'rush',
                'cog_phase', 'weight_phase', 'chase', 'gusts', 'hush', 'hints']


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


def write(name, header, rows, out_dir=None):
    check_legend(name, rows)
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
    from its keys in HEADER_ORDER (x-valued keys resolved against rows)."""
    if 'header' in entry:
        return list(entry['header'])
    vals = {}
    if 'name' in entry:
        vals['title'] = entry['name']
    vals['subtitle'] = entry.get('subtitle', entry['id'])
    skip = {'id', 'name', 'sections', 'header', 'subtitle', 'out_dir'}
    for k, v in entry.items():
        if k in skip:
            continue
        if k == 'hints' and not isinstance(v, str):
            v = '|'.join(v)
        elif k in ('cog_phase', 'weight_phase') and isinstance(v, dict):
            v = phases_header({_place(rows, p): t for p, t in v.items()})
        elif k == 'chase' and not isinstance(v, str):
            v = ranges_header([(_place(rows, a), _place(rows, b)) for a, b in v])
        vals[k] = str(v)
    out = [(k, vals.pop(k)) for k in HEADER_ORDER if k in vals]
    # Keys HEADER_ORDER doesn't know (the modes' private ones) go before the hints.
    extra = [(k, v) for k, v in vals.items()]
    if out and out[-1][0] == 'hints':
        return out[:-1] + extra + [out[-1]]
    return out + extra


def build(entry, out_dir=None):
    """Joins an entry's sections and writes its file."""
    rows = join(*entry['sections'])
    return write(entry['id'], header_of(entry, rows), rows, out_dir or entry.get('out_dir'))


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
