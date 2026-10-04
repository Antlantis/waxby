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
as _order_hints writes the hints in reading order. A 'room' list (the sealed
fight rooms, features/sealed.gd) is written by rooms_header and checked by
check_rooms.

Build 2's toolkit (the toolkit part below): swap() edits a copy of a
section, stamp() drops an encounter stamp (STAMPS) into one, span() names a
section's columns for a range header (a belt_flip: run, written x0-x1=N as
features/clockwork.gd reads it; a sealed room is rooms_header's room:), and
each world's regular levels declare their own
cast and threat density (world_tables: ROSTER and THREAT), checked as each
file is written (check_headers: roster_problems, threat_of), with the
world's rules across them (check_roles: the ramp, the checkpoints, the
section roles and, once re-cut, the variety rules), and written as roster:
and threat: headers, which tests/level_rules.gd holds each file to. An
entry's 'anoint' may be a list of (section, dx, row[, omens[, name]]);
anoint_header() writes it, Omens and names and all. Every key is optional;
toolkit.py proves the toolkit with every build.

Whoever writes a header (a world's tables, an explicit v2 'header' list, a
lab), write() holds its Build 2 keys to their rules (check_headers): room:,
anoint:, twist: (an id twists.gd knows), lesson: (Title|Line, short enough
for the band), roster: (it reads, and the rows keep it), threat: and roles:.
A v2 entry's explicit header list takes the toolkit's keys from the entry
too ('roster', 'threat', 'roles', 'anoint', 'twist', 'lesson', 'room'), so
w1.py and w2.py fill ROSTER and THREAT and call world_tables as W3-W6 do.

The spec's tables were written before the toolkit; as the toolkit takes them
(write() refuses the old spellings, SPEC_KEYS):
    the spec                                  the toolkit
    ('duel', '98-109')                        'room': [('duel', (98, 109))]
    'ambush': SEC                             'room': [('ambush', SEC)]
    'ambush': SEC '@20' (5-3)                 'room': [('hold', SEC, {'secs': 20})]
    'twist': 'orchard_lesson' (an X-1's       'lesson': 'Into the Orchard|Roots follow
      card with no rule)                        your steps. Keep moving.'
    ('roster', 'skeleton,bat') (W1-W2)        'roster': {'headline': ['bat'],
                                                'rattle_max': 8, 'fodder_max': 1.0}
    a Rattle in a kind list (3-1, 3-2, 4-1)   fine: rattle_max holds Rattles (never
                                                a headline, so it's left out)
    'banned': [...] (5-3)                     a roster key: those kinds absent
    'pack_leaders': {glassmite: 3, ...}       a roster key: each placed one counted
                                                at that size (threat_of, in_play)
    Brinejaw a W6 headline (6-1, 6-3)         fine: HEADLINE_RETURN (the drowned
                                                deep's water kind comes back)
    'twist': 'restless' (1-2 and 3-2)         one id: Rattles in Worlds 1-2, every
                                                ordinary floor kind from World 3
    'twist': 'duel' (1-3)                     a card only ("Barbs' Loft"); the
                                                room itself is room:
    the set pieces grove_light, bone_niche,   drawn by hand in their sections (they
      spore_door, ice_to_wall and               need terrain: niches, pods, ice up
      pendulum_knight                           to a wall, weights); STAMPS holds
                                                the air-only groups
    'feats'                                   cut (deferred past Build 2)
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
# anoint, as they always fell): elite_behave (the elites' Nightfall moves on
# or off: lab-elites), anoint (forced Anointed: anoint_header), twist (the
# level's rule: twists.gd) and lesson (an X-1's card), roster and threat
# (world_tables), roles (a re-cut level's section roles: world_problems),
# room (the sealed rooms: rooms_header) and belt_flip (span(): x0-x1=N).
HEADER_ORDER = ['title', 'subtitle', 'music', 'theme', 'area', 'area_abs', 'boss', 'boss_music', 'dread', 'warden',
                'secret', 'secret_prize', 'tick', 'story_start', 'story_boss', 'story_end', 'par', 'rush',
                'cog_phase', 'weight_phase', 'chase', 'gusts', 'hush', 'warden_room', 'elite_behave', 'anoint', 'twist',
                'lesson', 'roster', 'threat', 'roles', 'room', 'belt_flip', 'hints']


class Section(list):
    """A section's 15 rows (a list of str), and its overlay row or None.
    Hashed and compared by identity, so a section can key a dict (cog_phase:
    {(ES_COG, 4): 0.25})."""
    overlay = None
    stamps = ()   # [(name, dx, dy)]: the STAMPS drawn into it (stamp())

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


# ---------------------------------------------------------------- sealed rooms

# features/sealed.gd's rooms (Build 2): the header's kinds, and the altar a
# snuff inside relights at, this many tiles before each room's door at most
# (sealed.gd ALTAR_REACH).
ROOM_KINDS = ('duel', 'ambush', 'hold')
ROOM_ALTAR_REACH = 8
MONSTER_GLYPHS = set('sbtahgkfMD' + 'rpmijqeuxzyln567')
SOLID_GLYPHS = set('#B?WRUFIZ<>G')
# A doorway's cells (each end column between the room's ceiling and floor):
# open air, where the slab comes down (sealed.gd seals only air), or what
# never opens: stone, a reliquary or a spent one, wax-ice, a belt. Never
# water, a vine, a ledge or crumble, dawnglass, a mover (a body passes them
# under the slab), brick, false stone, rime or glass (they break or melt).
DOOR_SOLID = set('#?WRUI<>')
# No monster of a room within this many columns of either end (sealed.gd
# DOOR_CLEAR): a drop-in by the door lands on him as he comes in; one in the
# doorway is sealed into the wall.
ROOM_DOOR_CLEAR = 3


def rooms_header(rows, rooms):
    """'duel 98-109 rows 3-7; hold 300-327 @20' from an entry's 'room' list
    (features/sealed.gd reads it). Each room is (kind, where[, opts]): where
    is a section (its columns, end walls included) or a pair of places
    ((section, dx[, n]) or an absolute x); opts may hold rows=(y0, y1) (its
    rows, ceiling and floor included: a room up off the path, which seals
    only once he climbs in), secs=N (the doors open after N s: a hold) and
    foe=(place, y) (a duel's named foe)."""
    out = []
    for room in rooms:
        assert len(room) in (2, 3), 'a room is (kind, where[, opts]): %r' % (room,)
        kind, where = room[0], room[1]
        opts = room[2] if len(room) > 2 else {}
        assert kind in ROOM_KINDS, 'room kind %r (one of %s)' % (kind, ', '.join(ROOM_KINDS))
        if isinstance(where, Section):
            x0 = x_of(rows, where)
            x1 = x0 + len(where[0]) - 1
        else:
            assert len(where) == 2, "a room's where is a section or a pair of places: %r" % (where,)
            x0, x1 = _place(rows, where[0]), _place(rows, where[1])
        s = '%s %d-%d' % (kind, x0, x1)
        if 'rows' in opts:
            s += ' rows %d-%d' % tuple(opts['rows'])
        if 'secs' in opts:
            s += ' @%s' % _num(opts['secs'])
        if 'foe' in opts:
            s += ' foe %d,%d' % (_place(rows, opts['foe'][0]), opts['foe'][1])
        out.append(s)
    return '; '.join(out)


def rooms_of(value):
    """[(kind, x0, x1)] from a written room: header ('duel 98-109 rows 3-7;
    hold 300-327 @20'), as features/sealed.gd parse reads it (a part that
    doesn't read is left out)."""
    out = []
    for part in str(value).split(';'):
        bits = part.split()
        if len(bits) < 2 or bits[0] not in ROOM_KINDS:
            continue
        ab = bits[1].split('-')
        if len(ab) == 2 and ab[0].isdigit() and ab[1].isdigit():
            out.append((bits[0], int(ab[0]), int(ab[1])))
    return out


def room_problems(rows, value):
    """What breaks the sealed rooms of a written 'room' header, as strings:
    each holds a monster, has a way in at an end, and has an altar within
    ROOM_ALTAR_REACH tiles before its door (a snuff inside relights by it,
    as at a boss's door); every doorway cell is air or DOOR_SOLID; no
    monster of it stands within ROOM_DOOR_CLEAR columns of either end
    (tests/level_rules.gd room_problems reads the file the same)."""
    out = []
    altars = [x for r in rows for x, ch in enumerate(r) if ch == 'K']
    for part in str(value).split(';'):
        bits = part.split()
        if len(bits) < 2 or bits[0] not in ROOM_KINDS:
            continue
        x0, x1 = (int(v) for v in bits[1].split('-'))
        y0, y1 = 0, len(rows) - 1
        if 'rows' in bits:
            y0, y1 = (int(v) for v in bits[bits.index('rows') + 1].split('-'))
        door_rows = range(0, len(rows) - 1) if 'rows' not in bits else range(y0 + 1, y1)
        room = 'room "%s"' % part.strip()

        def at(x, y):
            return rows[y][x] if 0 <= y < len(rows) and 0 <= x < len(rows[y]) else '.'
        mons = [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1) if at(x, y) in MONSTER_GLYPHS]
        if not mons:
            out.append('%s holds no monster' % room)
        if not any(at(x, y) == '.' or (at(x, y) in ENTITY_GLYPHS and _tile(rows, x, y, 'solid') == 'air')
                   for x in (x0, x1) for y in door_rows):
            out.append('%s has no doorway at either end' % room)
        for x in (x0, x1):
            for y in door_rows:
                ch = at(x, y)
                open_air = ch == '.' or (ch in ENTITY_GLYPHS and _tile(rows, x, y, 'solid') == 'air')
                if not open_air and ch not in DOOR_SOLID:
                    out.append('%s: its doorway cell %d,%d is %r (air, or stone that never opens: %s)'
                               % (room, x, y, ch, ''.join(sorted(DOOR_SOLID))))
        near = [(x, y) for x, y in mons if x - x0 <= ROOM_DOOR_CLEAR or x1 - x <= ROOM_DOOR_CLEAR]
        if near:
            out.append('%s has monsters within %d columns of a door at %s' % (room, ROOM_DOOR_CLEAR, near))
        if not any(x0 - ROOM_ALTAR_REACH <= x < x0 for x in altars):
            out.append('%s has no altar within %d tiles before its door (altars at %s)' % (room, ROOM_ALTAR_REACH, altars))
    return out


def check_rooms(name, rows, value):
    """Asserts every sealed room of a written 'room' header keeps its rules
    (room_problems)."""
    if not value:
        return
    probs = room_problems(rows, value)
    assert not probs, '%s: %s' % (name, '; '.join(probs))


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


def write(name, header, rows, out_dir=None, world=None):
    """Writes game/levels/<name>.txt (or out_dir's), its header's Build 2
    keys checked first (check_headers; world: the level's, else its id's)."""
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
    check_headers(name, rows, header, world)
    text = ''.join('%s: %s\n' % kv for kv in header) + '---\n' + '\n'.join(r.rstrip('.') for r in rows) + '\n'
    d = out_dir or OUT
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, name + '.txt'), 'w') as f:
        f.write(text)
    print('%s: %d x %d  %s' % (name, max(len(r) for r in rows), len(rows), _report(name, rows)))
    return text


# The toolkit's keys a v2 entry's explicit header list takes from the entry
# (header_of), where the list doesn't already hold them.
MERGE_KEYS = ('anoint', 'twist', 'lesson', 'roster', 'threat', 'roles', 'room')


def _header_value(k, v, rows, entry):
    """One header's written value: x-valued keys resolved against rows; a
    roster dict, a threat number, an anoint list and any span-valued key
    written by their toolkit helpers."""
    if k == 'hints' and not isinstance(v, str):
        v = '|'.join(v)
    elif k in ('cog_phase', 'weight_phase') and isinstance(v, dict):
        v = phases_header({_place(rows, p): t for p, t in v.items()})
    elif k == 'chase' and not isinstance(v, str):
        v = ranges_header([(_place(rows, a), _place(rows, b)) for a, b in v])
    elif k == 'room' and not isinstance(v, str):
        v = rooms_header(rows, v)
    elif k == 'roster' and isinstance(v, dict):
        v = roster_header(v)
    elif k == 'threat' and not isinstance(v, str):
        v = _num(v)
    elif k == 'anoint' and not isinstance(v, str):
        v = anoint_header(rows, v, entry_world(entry), entry['id'])
    elif _has_span(v):
        v = spans_header(rows, v, SPAN_SEP.get(k, '@'))
    return str(v)


def header_of(entry, rows):
    """An entry's ordered header: its own 'header' list (v2's, kept as it
    was, with the toolkit's MERGE_KEYS from the entry put before its hints),
    or one built from its keys in HEADER_ORDER (_header_value). An entry's
    'world' (a fixture's) and 'out_dir' aren't headers."""
    if 'header' in entry:
        out = list(entry['header'])
        have = {k for k, _v in out}
        extra = [(k, _header_value(k, entry[k], rows, entry)) for k in HEADER_ORDER if k in MERGE_KEYS and k in entry and k not in have]
        if extra and out and out[-1][0] == 'hints':
            return out[:-1] + extra + [out[-1]]
        return out + extra
    vals = {}
    if 'name' in entry:
        vals['title'] = entry['name']
    vals['subtitle'] = entry.get('subtitle', entry['id'])
    skip = {'id', 'name', 'sections', 'header', 'subtitle', 'out_dir', 'world'}
    for k, v in entry.items():
        if k in skip:
            continue
        vals[k] = _header_value(k, v, rows, entry)
    out = [(k, vals.pop(k)) for k in HEADER_ORDER if k in vals]
    # Keys HEADER_ORDER doesn't know (the modes' private ones) go before the hints.
    extra = [(k, v) for k, v in vals.items()]
    if out and out[-1][0] == 'hints':
        return out[:-1] + extra + [out[-1]]
    return out + extra


def build(entry, out_dir=None):
    """Joins an entry's sections and writes its file (write() checks its
    Build 2 headers as written: check_headers)."""
    rows = join(*entry['sections'])
    header = header_of(entry, rows)
    return write(entry['id'], header, rows, out_dir or entry.get('out_dir'), entry_world(entry))


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
# the ramp over the level before it, less RAMP_TOL: RAMP_STEP (0) while a
# world's levels are today's (flat: the tolerance a Rattle or so in 340
# tiles), RECUT_RAMP (+1.0 a step: X-1 < X-2 < X-3) once they're re-cut
# (they declare their roles:), or world_tables' ramp= for a world's own.
THREAT_SLACK = 0.10
RAMP_STEP = 0.0
RECUT_RAMP = 1.0
RAMP_TOL = 0.25
# Packs (in_play, threat_of): each placed monster counts at the bodies it
# comes to in play. Under the packs twist each placed one of PACK_EACH brings
# its own (every Glassmite two more, a Creepbone its lane partner, an Unwick
# its pair: each script's per-placed rule), and each placed pack of a
# PACK_GROUP kind (one kind within PACK_TILES across and a row of one
# another, hushling.gd's pack_tiles; its leftmost brings it) comes to that
# size at least: the Hushlings' 3-5 at its mean, a Tickwind file at two.
# Hushlings bring a pack without the twist too: DUSK_PACK on a story Dusk
# (2-3, at its mean), ANOINTED_PACK behind a forced Anointed leader from
# World 3 (behave_diff: Nightfall's 3-5). A roster's pack_leaders ({kind: n})
# counts each placed one of a kind at n instead.
PACK_EACH = {'glassmite': 3, 'creepbone': 2, 'unwick': 2}
PACK_GROUP = {'hushling': 4, 'tickwind': 2}
DUSK_PACK = {'hushling': 2.5}
ANOINTED_PACK = {'hushling': 4}
PACK_TILES = 4
# A regular level's altars (3-5, as its gaps need), and a sealed room's door
# (the left column of each room in its room: header, rooms_of) has an altar
# at most 8 tiles before it, as a boss arena's does (test_content; check_rooms
# holds every written file to the same, ROOM_ALTAR_REACH).
ALTARS = (3, 5)
DOOR_ALTAR = 8
# Each kind's home world, for the roster's rules from World 3 on (a headline
# kind is the level's world's own, a guest an earlier world's): v2's kinds
# are World 1's (the Brinejaw World 2's), v3's their world's (contract §6.3).
HOME = {'brinejaw': 2, 'rootling': 3, 'weepcap': 3, 'rattlehound': 3, 'creepbone': 3,
        'tickwind': 4, 'spurwheel': 4, 'frostbuckle': 4, 'hoarowl': 4,
        'glassmite': 5, 'gustling': 5, 'refractor': 5, 'paneguard': 5,
        'hushling': 6, 'stillmaw': 6, 'unwick': 6, 'lurecoil': 6}
# A kind from another world that a world may headline all the same: World
# 6's drowned deep brings back World 2's water kind (the spec's 6-1, 6-3).
HEADLINE_RETURN = {6: ('brinejaw',)}
# A roster's keys: its kinds (a Rattle in a list is rattle_max's, so it's
# left out), the caps, and banned (kinds it must not place: 5-3's share-cap
# ruling), pack_leaders ({kind: n}: each placed one counted at n) and stamps
# (the STAMPS it uses, each stamp() drawn into its sections: check_headers).
ROSTER_KEYS = ('headline', 'support', 'guest', 'rattle_max', 'fodder_max', 'count', 'banned', 'pack_leaders', 'stamps')
# Section roles (check_roles): each section's letters, in this order, from
# what it holds (start, a Lidlurk's vault, the Dread, an altar, the bell, a
# boss); a section with none is content, C.
ROLE_MARKS = (('P', 'S'), ('M', 'V'), ('D', 'D'), ('K', 'A'), ('E', 'B'), ('X', 'X'))
# A re-cut world (every regular level declares its roles:) is held to the
# spec's variety rules across its levels (world_problems): no two with the
# same landmarks (landmarks_of: the roles less the content, a run of one
# landmark as one) or with their altars within ALTAR_NEAR tiles of each
# other's; the fodder ceilings falling X-1 > X-2 > X-3 and at most
# FODDER_CAPS; its X-3 with MIXED_SCREENS screens (SCREEN tiles, apart) of
# MIXED_KINDS kinds or more; no screen with more than AWAKE_MAX bodies in
# play (in_play: packs at their size; what the phone reads at once). Any
# X-1 keeps its stamps to its second half (it teaches alone first).
ALTAR_NEAR = 8
FODDER_CAPS = (0.85, 0.75, 0.65)
SCREEN = 26
MIXED_KINDS = 3
MIXED_SCREENS = 2
AWAKE_MAX = 6
# Header keys the spec wrote that the toolkit spells otherwise (write()
# refuses them, saying how; the module docstring's table).
SPEC_KEYS = {
    'duel': "a sealed room is 'room': [('duel', where[, opts])] (rooms_header)",
    'ambush': "a sealed room is 'room': [('ambush', where)]; a timed one [('hold', where, {'secs': 20})]",
    'hold': "a sealed room is 'room': [('hold', where, {'secs': 20})] (rooms_header)",
    'feats': 'feats were cut (deferred past Build 2)',
    'banned': "banned is a roster key: 'roster': {..., 'banned': [kinds]}",
    'pack_leaders': "pack_leaders is a roster key: 'roster': {..., 'pack_leaders': {kind: n}}",
    'stamps': "stamps is a roster key: 'roster': {..., 'stamps': [names]}",
}


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


@functools.lru_cache(maxsize=None)
def twists():
    """twists.gd's registry, as the header checks need it: its ids, and the
    longest card name and line (NAME_MAX, LINE_MAX)."""
    return {'ids': set(_gd_const('twists.gd', 'TWISTS')), 'name_max': _gd_const('twists.gd', 'NAME_MAX'),
            'line_max': _gd_const('twists.gd', 'LINE_MAX')}


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


def level_no(level_id):
    """'3-2' -> 2 (its place in its world: X-1, X-2, X-3), 0 for anything
    else (a secret, a lab, a fixture)."""
    if len(level_id) == 3 and level_id[1] == '-' and level_id[0].isdigit() and level_id[2].isdigit():
        return int(level_id[2])
    return 0


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
    out.stamps = list(getattr(sec, 'stamps', ()))
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
# section and records it there (Section.stamps: a level's roster names every
# stamp it uses, and an X-1 keeps them to its second half); the section's
# own drawing gives it the post, the vines, the glass or the belts it plays
# on. Each fits one 26 x 12 view (self_check). The designs' set pieces that
# need terrain a stamp can't write (it writes into air only) are drawn by
# hand in their sections: grove_light (3-1), bone_niche and spore_door
# (3-2), ice_to_wall (4-1) and pendulum_knight (4-3).
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
    out.stamps = list(out.stamps) + [(name, dx, dy)]
    return out


def level_stamps(rows):
    """[(name, x, y)]: every stamp drawn into a level's sections (rows: the
    joined Rows), absolute."""
    return [(n, x0 + dx, dy) for sec, x0 in getattr(rows, 'parts', ()) for n, dx, dy in getattr(sec, 'stamps', ())]


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
    """span(SEC): all of a section's columns (its walls included);
    span(SEC, 2, 21): its columns 2-21; n: its n-th use. An entry's value
    may be a Span, a list of Spans or (Span, value) pairs, or {Span: value}:
    'belt_flip': [(span(ES_FLIP, 2, 21), 8)] is written 'x0-x1=8'. (A
    sealed room is a 'room' list: rooms_header.)"""
    return Span(section, dx0, dx1, n)


# The separator before a span key's value where it isn't '@': a belt_flip
# run's beats, as features/clockwork.gd belt_flips reads them.
SPAN_SEP = {'belt_flip': '='}


def _has_span(v):
    if isinstance(v, Span):
        return True
    if isinstance(v, dict):
        return any(isinstance(k, Span) for k in v)
    if isinstance(v, (list, tuple)):
        return any(isinstance(i, Span) or (isinstance(i, tuple) and i and isinstance(i[0], Span)) for i in v)
    return False


def spans_header(rows, v, sep='@'):
    """'x0-x1, x0-x1@value' (x ascending) from a Span, a list of Spans or
    (Span, value) pairs, or {Span: value}; sep goes before a value (a
    belt_flip's is '=': SPAN_SEP)."""
    if isinstance(v, Span):
        v = [v]
    elif isinstance(v, dict):
        v = list(v.items())
    out = []
    for item in v:
        sp, val = (item, None) if isinstance(item, Span) else item
        a, b = sp.cols(rows)
        tail = '' if val is None else '%s%s' % (sep, _num(val) if isinstance(val, (int, float)) else val)
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
    or its sections. Checked as written (anoint_problems): each cell holds a
    kind elites.gd may anoint, each Omen is in its Dusk pool there
    (omen_pool: so no difficulty falls back to a roll), at most MAX_OMENS;
    World 1-2 at most one, with one Omen, and never in 1-1 (the gentle
    on-ramp)."""
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
        # (A name or an Omen with ; : , or + would write a header that reads otherwise.)
        assert not re.search(r'[;:,]', name) and len(name) <= 24, \
            '%s anoint %d,%d: its name %r (no ; : or , and 24 letters at most)' % (level_id or 'a level', x, y, name)
        assert not any(re.search(r'[;:,+]', o) for o in omens), '%s anoint %d,%d: Omens %s' % (level_id or 'a level', x, y, omens)
        s = '%d,%d' % (x, y)
        if omens or name:
            s += ':' + '+'.join(omens)
        if name:
            s += ':' + name
        out.append(s)
    value = '; '.join(out)
    probs = anoint_problems(rows, value, world, level_id)
    assert not probs, '%s: %s' % (level_id or 'a level', '; '.join(probs))
    return value


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


def anoint_problems(rows, value, world=0, level_id=''):
    """What breaks a written anoint: header, as strings (anoint_header's
    rules, read back from the value as tests/level_rules.gd anoint_problems
    reads the file; write() runs it on every header, an explicit v2 list's
    too): each part reads, each cell inside the level holding a kind
    elites.gd may anoint, its Omens from that kind's Dusk pool there,
    distinct and at most MAX_OMENS, its name with no ; : or , and 24 letters
    at most; World 1-2 at most one, with one Omen, and none in 1-1."""
    g = game()
    out = ["the anoint part %r doesn't read (x,y[:Omen+Omen[:Name]])" % p.strip()
           for p in str(value).split(';') if p.strip() and not anoint_cells(p)]
    cells = anoint_cells(value)
    for x, y, omens, name in cells:
        where = 'the anoint at %d,%d' % (x, y)
        if not (0 <= y < len(rows) and 0 <= x < len(rows[y])):
            out.append('%s is outside the level' % where)
            continue
        kind = g['monsters'].get(rows[y][x])
        if kind not in g['eligible']:
            out.append('%s holds %r, no kind elites.gd may anoint' % (where, rows[y][x]))
            continue
        pool = omen_pool(kind, world)
        out += ['%s: a %s may not carry %s in World %d on Dusk (%s)' % (where, kind, o, world, '+'.join(pool)) for o in omens if o not in pool]
        if len(set(omens)) != len(omens) or len(omens) > g['max_omens']:
            out.append('%s: Omens %s' % (where, omens))
        if re.search(r'[;:,]', name) or len(name) > 24:
            out.append('%s: its name %r (no ; : or , and 24 letters at most)' % (where, name))
        if 1 <= world <= 2 and (level_id == '1-1' or len(cells) > 1 or len(omens) > 1):
            out.append('%s: World 1-2 takes at most one set piece, with one Omen, and none in 1-1' % where)
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


def in_play(rows, anoint=(), twist='', world=0, pack_leaders=None):
    """[(x, y, kind, n)]: each placed monster (the Dread and the boss aside)
    and the bodies it comes to in play, itself and the pack it brings: a
    roster's pack_leaders at its n; under the packs twist PACK_EACH apiece;
    each placed pack of a PACK_GROUP or DUSK_PACK kind up to its size, on its
    leftmost (ANOINTED_PACK when that one is a forced Anointed, from World 3;
    else PACK_GROUP under the twist; else DUSK_PACK). A cell in anoint is a
    forced Anointed. tests/level_rules.gd in_play counts the same."""
    g = game()
    forced = set(anoint)
    leaders = dict(pack_leaders or {})
    placed = []
    groups = {}
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            k = g['monsters'].get(ch)
            if not k:
                continue
            p = [x, y, k, 1.0]
            placed.append(p)
            if k in leaders:
                p[3] = float(leaders[k])
            elif twist == 'packs' and k in PACK_EACH:
                p[3] = float(PACK_EACH[k])
            elif k in PACK_GROUP or k in DUSK_PACK:
                groups.setdefault(k, {})[(x, y)] = p
    for k, by in groups.items():
        for group in _packs(list(by)):
            lead = by[min(group)]
            if (lead[0], lead[1]) in forced and world >= 3 and k in ANOINTED_PACK:
                size = ANOINTED_PACK[k]
            elif twist == 'packs' and k in PACK_GROUP:
                size = PACK_GROUP[k]
            else:
                size = DUSK_PACK.get(k, 0.0)
            lead[3] += max(0.0, size - len(group))
    return [tuple(p) for p in placed]


def threat_of(rows, anoint=(), twist='', world=0, pack_leaders=None):
    """Threat cost per 100 tiles (EnemyKinds.COST, the Dread aside): each
    placed monster at the bodies it comes to in play (in_play: its pack's
    extras at its kind's cost), a forced Anointed (a cell in anoint) itself
    at TIER_COST's x2.5 (tests/level_rules.gd threat_of counts the same)."""
    g = game()
    forced = set(anoint)
    cost = 0.0
    for x, y, k, n in in_play(rows, anoint, twist, world, pack_leaders):
        cost += g['cost'][k] * ((g['tier_cost']['anointed'] if (x, y) in forced else 1.0) + n - 1.0)
    return cost * 100.0 / max(len(r) for r in rows)


def _band(v):
    return (int(v[0]), int(v[1])) if isinstance(v, (tuple, list)) else (int(v), int(v))


def roster_header(roster):
    """'headline=a,b; support=c; guest=d; rattle_max=3; fodder_max=0.75;
    count=18-24; banned=e; pack_leaders=glassmite:3; stamps=crossfire'
    (empty lists and an absent count left out)."""
    parts = ['%s=%s' % (k, ','.join(roster[k])) for k in ('headline', 'support', 'guest') if roster.get(k)]
    parts.append('rattle_max=%d' % roster['rattle_max'])
    parts.append('fodder_max=%s' % _num(roster['fodder_max']))
    if 'count' in roster:
        lo, hi = _band(roster['count'])
        parts.append('count=%d' % lo if lo == hi else 'count=%d-%d' % (lo, hi))
    if roster.get('banned'):
        parts.append('banned=%s' % ','.join(roster['banned']))
    if roster.get('pack_leaders'):
        parts.append('pack_leaders=%s' % ','.join('%s:%d' % (k, n) for k, n in sorted(roster['pack_leaders'].items())))
    if roster.get('stamps'):
        parts.append('stamps=%s' % ','.join(roster['stamps']))
    for k in sorted(set(roster) - set(ROSTER_KEYS)):
        parts.append('%s=%s' % (k, roster[k]))
    return '; '.join(parts)


def roster_of(value):
    """A written roster: header read back as roster_header's dict (as
    tests/level_rules.gd roster_of reads it): lists, numbers, a count band,
    pack_leaders {kind: n}; a key it doesn't know kept as written (so
    roster_problems names it); {} for none."""
    out = {}
    for part in str(value).split(';'):
        if not part.strip():
            continue
        k, _eq, v = part.partition('=')
        k, v = k.strip(), v.strip()
        if k in ('headline', 'support', 'guest', 'banned', 'stamps'):
            out[k] = [s.strip() for s in v.split(',') if s.strip()]
        elif k == 'rattle_max':
            out[k] = int(v)
        elif k == 'fodder_max':
            out[k] = float(v)
        elif k == 'count':
            ab = v.split('-')
            out[k] = (int(ab[0]), int(ab[-1]))
        elif k == 'pack_leaders':
            out[k] = {a.split(':')[0].strip(): int(a.split(':')[1]) for a in v.split(',') if ':' in a}
        else:
            out[k] = v
    return out


def roster_problems(level_id, cast, roster, world=None):
    """What breaks a level's declared roster (the spec's per-level rosters),
    as strings: every kind it places is declared (headline, support or
    guest; a Rattle listed is left out: rattle_max holds Rattles), a Rattle
    only up to rattle_max and one Lidlurk (the vault's, never listed); every
    headline kind placed; from World 3 a headline kind is the world's own
    (or one HEADLINE_RETURN brings back), a guest an earlier world's and no
    support kind a later one's; no banned kind placed; pack_leaders and
    stamps naming what's there; the fodder share (EnemyKinds.ROLE, of every
    monster) within fodder_max, and the count within count (n or (lo, hi)).
    world: the level's (else its id's)."""
    g = game()
    out = ['unknown roster key %s' % k for k in sorted(set(roster) - set(ROSTER_KEYS))]
    if any('=' not in str(k) and ',' in str(k) for k in roster):
        out.append("a roster is keys (headline=..; rattle_max=..; fodder_max=..), not a list of kinds: "
                   "write the dict, {'headline': [...], 'rattle_max': n, 'fodder_max': f}")
    out += ['the roster has no %s' % k for k in ('headline', 'rattle_max', 'fodder_max') if k not in roster]
    if out:
        return out
    world = world_of(level_id) if world is None else world
    head, sup, guest = ([k for k in roster.get(n, []) if k != 'skeleton'] for n in ('headline', 'support', 'guest'))
    listed = head + sup + guest
    if not head:
        out.append('the roster has no headline kind but the Rattle (rattle_max holds Rattles)')
    for k in listed:
        if k == 'lidlurk' or k not in g['cost']:
            out.append('%s is listed (a Lidlurk is the vault, else no kind)' % k)
    banned = list(roster.get('banned', []))
    for k in banned:
        if k not in g['cost']:
            out.append('%s is banned, but no kind' % k)
        elif k in listed:
            out.append('%s is both listed and banned' % k)
        elif cast.get(k, 0):
            out.append('%d %s, banned' % (cast[k], k))
    for k, n in sorted(dict(roster.get('pack_leaders', {})).items()):
        if k not in listed or int(n) < 1:
            out.append('pack_leaders %s:%s (a listed kind, at 1 or more)' % (k, n))
    for st in roster.get('stamps', []):
        if st not in STAMPS:
            out.append('stamps names %s, no stamp (STAMPS)' % st)
    for k, n in sorted(cast.items()):
        if k == 'skeleton':
            if n > roster['rattle_max']:
                out.append('%d Rattles (rattle_max %d)' % (n, roster['rattle_max']))
        elif k == 'lidlurk':
            if n > 1:
                out.append('%d Lidlurks (one: the vault)' % n)
        elif k not in listed and k not in banned:
            out.append('%d %s it does not declare' % (n, k))
    for k in head:
        if cast.get(k, 0) == 0:
            out.append('no %s, a headline kind' % k)
    if world >= 3:
        back = HEADLINE_RETURN.get(world, ())
        out += ['%s is World %d\'s, no headline in World %d' % (k, home_of(k), world) for k in head if home_of(k) != world and k not in back]
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


def check_threat(name, rows, target, anoint=(), twist='', world=0, pack_leaders=None):
    """Asserts a level's threat (threat_of) within THREAT_SLACK of its
    declared one, and returns it."""
    got = threat_of(rows, anoint, twist, world, pack_leaders)
    assert abs(got - target) <= target * THREAT_SLACK + 1e-9, \
        '%s: threat %.2f per 100 tiles, declared %s (within %d%%)' % (name, got, _num(target), round(THREAT_SLACK * 100))
    return got


def lesson_problems(value):
    """What breaks a lesson: header (an X-1's card, twists.gd lesson_in), as
    strings: Title|Line, the title at most NAME_MAX characters and the line
    at most LINE_MAX (the band's 14 px on the phone; test_twists measures)."""
    t = twists()
    title, bar, line = str(value).partition('|')
    title, line = title.strip(), line.strip()
    out = []
    if not bar or not title or not line:
        out.append('a lesson is Title|Line: %r' % value)
    if len(title) > t['name_max']:
        out.append('the lesson title %r is %d characters (at most %d)' % (title, len(title), t['name_max']))
    if len(line) > t['line_max']:
        out.append('the lesson line %r is %d characters (at most %d)' % (line, len(line), t['line_max']))
    return out


def check_headers(name, rows, header, world=None):
    """The Build 2 keys of a header about to be written, whoever wrote it (a
    world's tables, an explicit v2 header list, a lab): a spelling the spec
    used that the toolkit replaced is refused (SPEC_KEYS, saying how);
    room: (check_rooms), anoint: (anoint_problems), twist: (an id in
    twists.gd TWISTS), lesson: (lesson_problems), roster: (it reads and the
    rows keep it, roster_problems, and it names every stamp the sections
    hold), threat: (threat_of within THREAT_SLACK, its anoint: cells, twist
    and pack_leaders counted) and roles: (what the sections hold) keep their
    rules. world: the level's (else its id's)."""
    world = world_of(name) if world is None else world
    hd = dict(header)
    for k in hd:
        assert k not in SPEC_KEYS, '%s: a %r header: %s' % (name, k, SPEC_KEYS[k])
    check_rooms(name, rows, hd.get('room', ''))
    if hd.get('anoint', '').strip():
        probs = anoint_problems(rows, hd['anoint'], world, name)
        assert not probs, '%s: %s' % (name, '; '.join(probs))
    tw = hd.get('twist', '').strip()
    assert not tw or tw.lower() in twists()['ids'], \
        "%s: twist %r is none of twists.gd's (%s); an X-1's card with no rule is lesson: Title|Line" % (
            name, tw, ', '.join(sorted(twists()['ids'])))
    if 'lesson' in hd:
        probs = lesson_problems(hd['lesson'])
        assert not probs, '%s: %s' % (name, '; '.join(probs))
    roster = {}
    if hd.get('roster', '').strip():
        roster = roster_of(hd['roster'])
        probs = roster_problems(name, cast_of(rows), roster, world)
        assert not probs, '%s breaks its roster: %s' % (name, '; '.join(probs))
        used = sorted({n for n, _x, _y in level_stamps(rows)})
        assert used == sorted(set(roster.get('stamps', []))), \
            '%s: its roster names stamps %s, its sections hold %s' % (name, sorted(set(roster.get('stamps', []))), used)
    if hd.get('threat', '').strip():
        anoint = [(x, y) for x, y, _o, _n in anoint_cells(hd.get('anoint', ''))]
        check_threat(name, rows, float(hd['threat']), anoint, tw.lower(), world, roster.get('pack_leaders'))
    parts = [sec for sec, _x in getattr(rows, 'parts', ())]
    if hd.get('roles', '').strip() and parts:
        assert ' '.join(hd['roles'].split()) == roles_of(parts), \
            '%s declares roles %s but its sections hold %s' % (name, hd['roles'], roles_of(parts))


# ---------------------------------------------------------------- a world's rules

def roles_of(sections):
    """'S C C A ...': each section's roles (ROLE_MARKS; C for content)."""
    out = []
    for sec in sections:
        s = ''.join(sec)
        out.append(''.join(r for ch, r in ROLE_MARKS if ch in s) or 'C')
    return ' '.join(out)


def landmarks_of(roles):
    """A roles string's landmarks: its content (C) left out and a run of one
    landmark taken as one ('S C C A C A C V A D B' -> 'S A V A D B'), so a
    content section added or split, or an altar more in a run, is no change."""
    out = []
    for r in str(roles).split():
        if r != 'C' and (not out or out[-1] != r):
            out.append(r)
    return ' '.join(out)


def checkpoint_problems(rows, header, max_gap, altar_band=ALTARS):
    """A regular level's checkpoints (start, altars, bell): at most max_gap
    apart, altar_band altars (ALTARS; World 1-2's own, w1.py and w2.py), and
    an altar at most DOOR_ALTAR tiles before every sealed room's door (the
    left column of each room: room, rooms_of)."""
    marks = sorted(x for r in rows for x, ch in enumerate(r) if ch in 'PKEX')
    altars = sorted(x for r in rows for x, ch in enumerate(r) if ch == 'K')
    out = []
    worst = max([b - a for a, b in zip(marks, marks[1:])] or [0])
    if worst > max_gap:
        out.append('checkpoints %d tiles apart (at most %d): %s' % (worst, max_gap, marks))
    if not altar_band[0] <= len(altars) <= altar_band[1]:
        out.append('%d altars (%d-%d)' % (len(altars), altar_band[0], altar_band[1]))
    for kind, x0, _x1 in rooms_of(header.get('room', '')):
        if not any(0 <= x0 - a <= DOOR_ALTAR for a in altars):
            out.append('no altar within %d tiles of the %s door at %d (altars %s)' % (DOOR_ALTAR, kind, x0, altars))
    return out


def mixed_screens(rows):
    """How many screens (SCREEN tiles wide, none overlapping: the most such
    a level holds) have MIXED_KINDS kinds or more of monster in them."""
    mons = game()['monsters']
    cols = {}
    for r in rows:
        for x, ch in enumerate(r):
            if ch in mons:
                cols.setdefault(x, set()).add(mons[ch])
    width = max(len(r) for r in rows)
    n = 0
    x0 = 0
    while x0 < width:
        kinds = set()
        for x in range(x0, x0 + SCREEN):
            kinds |= cols.get(x, set())
        if len(kinds) >= MIXED_KINDS:
            n += 1
            x0 += SCREEN
        else:
            x0 += 1
    return n


def crowded_screens(rows, anoint=(), twist='', world=0, pack_leaders=None):
    """[(x0, n)]: each screen (SCREEN tiles from x0) with more than
    AWAKE_MAX bodies in play in it (in_play: packs at their size)."""
    at = {}
    for x, _y, _k, n in in_play(rows, anoint, twist, world, pack_leaders):
        at[x] = at.get(x, 0.0) + n
    width = max(len(r) for r in rows)
    out = []
    for x0 in range(0, max(width - SCREEN, 0) + 1):
        n = sum(at.get(x, 0.0) for x in range(x0, x0 + SCREEN))
        if n > AWAKE_MAX + 1e-9:
            out.append((x0, n))
    return out


def world_problems(entries, max_gap, ramp=None, altar_band=ALTARS):
    """What breaks a world's rules across its regular levels (the entries
    with a roster), as strings: the threat ramp (each declared threat at
    least the ramp over the one before, less RAMP_TOL: ramp, else RECUT_RAMP
    in a re-cut world, else RAMP_STEP), each level's checkpoint_problems,
    any X-1's stamps in its first half; and once any level is re-cut (it
    declares its roles:, which must be what its sections hold), every one
    declares them, and the variety rules (ALTAR_NEAR and on): no two share
    their landmarks (landmarks_of) or line their altars up, the fodder
    ceilings fall within FODDER_CAPS, the X-3 mixes MIXED_SCREENS screens and
    no screen of an X-1..X-3 holds more than AWAKE_MAX in play (a fixture,
    unnumbered, is no X-n)."""
    regular = sorted((e for e in entries if 'roster' in e), key=lambda e: e['id'])
    recut = any('roles' in e for e in regular)
    step = ramp if ramp is not None else (RECUT_RAMP if recut else RAMP_STEP)
    out = []
    prev = None
    for e in regular:
        t = e.get('threat')
        if t is None:
            continue
        if prev is not None and float(t) < prev[1] + step - RAMP_TOL:
            out.append('threat %s in %s after %s in %s (the ramp: +%s, less %s)'
                       % (_num(t), e['id'], _num(prev[1]), prev[0], _num(step), _num(RAMP_TOL)))
        prev = (e['id'], float(t))
    info = {}
    for e in regular:
        rows = join(*e['sections'])
        hd = dict(header_of(e, rows))
        out += ['%s: %s' % (e['id'], p) for p in checkpoint_problems(rows, hd, max_gap, altar_band)]
        seq = roles_of(e['sections'])
        if 'roles' in e and ' '.join(e['roles'].split()) != seq:
            out.append('%s declares roles %s but its sections hold %s' % (e['id'], e['roles'], seq))
        width = max(len(r) for r in rows)
        if level_no(e['id']) == 1:
            early = [(n, x) for n, x, _y in level_stamps(rows) if x < width // 2]
            if early:
                out.append('%s: stamps in its first half %s (an X-1 teaches alone first)' % (e['id'], early))
        roster = e['roster'] if isinstance(e['roster'], dict) else roster_of(e['roster'])
        info[e['id']] = {'rows': rows, 'hd': hd, 'seq': seq, 'roster': roster,
                         'altars': sorted(x for r in rows for x, ch in enumerate(r) if ch == 'K')}
    if not recut:
        return out
    out += ['%s declares no roles: (a re-cut world\'s levels all do)' % e['id'] for e in regular if 'roles' not in e]
    for i, a in enumerate(regular):
        for b in regular[i + 1:]:
            ia, ib = info[a['id']], info[b['id']]
            if landmarks_of(ia['seq']) == landmarks_of(ib['seq']):
                out.append('%s and %s share their landmarks (%s)' % (a['id'], b['id'], landmarks_of(ia['seq'])))
            if len(ia['altars']) == len(ib['altars']) and all(abs(p - q) <= ALTAR_NEAR for p, q in zip(ia['altars'], ib['altars'])):
                out.append('%s and %s have their altars within %d tiles of each other\'s (%s, %s)'
                           % (a['id'], b['id'], ALTAR_NEAR, ia['altars'], ib['altars']))
    last = None
    for e in regular:
        n = level_no(e['id'])
        fm = float(info[e['id']]['roster']['fodder_max'])
        if 1 <= n <= len(FODDER_CAPS) and fm > FODDER_CAPS[n - 1] + 1e-9:
            out.append('%s: fodder_max %s (an X-%d at most %s)' % (e['id'], _num(fm), n, _num(FODDER_CAPS[n - 1])))
        if last is not None and fm >= last[1] - 1e-9:
            out.append('%s: fodder_max %s, not under %s\'s %s (it falls X-1 to X-3)' % (e['id'], _num(fm), last[0], _num(last[1])))
        last = (e['id'], fm)
        it = info[e['id']]
        anoint = [(x, y) for x, y, _o, _n in anoint_cells(it['hd'].get('anoint', ''))]
        if n == 3 and mixed_screens(it['rows']) < MIXED_SCREENS:
            out.append('%s: %d screens with %d kinds or more (an X-3 mixes: at least %d)'
                       % (e['id'], mixed_screens(it['rows']), MIXED_KINDS, MIXED_SCREENS))
        crowd = crowded_screens(it['rows'], anoint, it['hd'].get('twist', '').strip(), entry_world(e), it['roster'].get('pack_leaders')) if n else []
        if crowd:
            x0, k = max(crowd, key=lambda c: c[1])
            out.append('%s: %s in play on the screen from x %d (at most %d a screen)' % (e['id'], _num(k), x0, AWAKE_MAX))
    return out


def check_roles(entries, max_gap, ramp=None, altar_band=ALTARS):
    """Asserts a world's rules across its regular levels (world_problems:
    the threat ramp, each level's checkpoints and altar gaps, its section
    roles and, once re-cut, the variety rules)."""
    probs = world_problems(entries, max_gap, ramp, altar_band)
    assert not probs, 'the world\'s rules: ' + '; '.join(probs)


def world_tables(entries, roster, threat, max_gap, ramp=None, altar_band=ALTARS):
    """Hands each regular level its row of its world's ROSTER and THREAT
    (written as its roster: and threat: headers, and checked as it's
    written: check_headers; a v2 entry's explicit header list takes them
    too, header_of), then checks the world's rules across them (check_roles;
    ramp: this world's step, else RECUT_RAMP once it's re-cut, else
    RAMP_STEP; altar_band: its levels' altars, ALTARS but World 1-2's). A
    level in neither table keeps its old header."""
    for e in entries:
        if e['id'] in roster:
            e['roster'] = roster[e['id']]
        if e['id'] in threat:
            e['threat'] = threat[e['id']]
    check_roles(entries, max_gap, ramp, altar_band)


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
    flip = header_of({'id': 'x', 'sections': [sec, T_OPEN, sec], 'belt_flip': [(span(sec, 2, 5, n=1), 8)]}, lvl)
    assert flip[-1] == ('belt_flip', '24-27=8') and ranges_of('24-27=8') == [(24, 27)], 'belt_flip, as clockwork.gd reads it (%s)' % (flip,)
    assert rooms_of('duel 98-109 rows 3-7; brawl 1-9; hold 300-327 @20') == [('duel', 98, 109), ('hold', 300, 327)], 'rooms_of'
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
    # threat: a forced Anointed at x2.5; a lone Hushling brings its Dusk pack
    # (2.5), under packs the twist's (4), behind a forced Anointed leader from
    # World 3 Nightfall's (4); each placed Glassmite under packs a trio, a
    # Tickwind file two; a roster's pack_leaders its own size.
    t = swap(sec, {(3, 12): 's', (12, 12): 't', (16, 12): 'n'})
    c = g['cost']
    assert abs(threat_of(t) - (c['skeleton'] + c['thornback'] + 2.5 * c['hushling']) * 5) < 1e-9, 'threat_of'
    assert abs(threat_of(t, [(12, 12)]) - (c['skeleton'] + 2.5 * c['thornback'] + 2.5 * c['hushling']) * 5) < 1e-9, 'threat_of forced'
    assert abs(threat_of(t, (), 'packs') - (c['skeleton'] + c['thornback'] + 4 * c['hushling']) * 5) < 1e-9, 'threat_of packs'
    assert abs(threat_of(t, [(16, 12)], '', 6) - (c['skeleton'] + c['thornback'] + (2.5 + 3) * c['hushling']) * 5) < 1e-9, 'an Anointed leader'
    gx = swap(sec, {(3, 12): 'x', (5, 12): 'x', (16, 12): 'j'})
    assert abs(threat_of(gx, (), 'packs') - (6 * c['glassmite'] + 2 * c['tickwind']) * 5) < 1e-9, 'threat_of packs: trios apiece, a file of two'
    assert abs(threat_of(gx) - (2 * c['glassmite'] + c['tickwind']) * 5) < 1e-9, 'no twist: as drawn'
    assert abs(threat_of(gx, (), '', 5, {'glassmite': 3, 'tickwind': 2}) - (6 * c['glassmite'] + 2 * c['tickwind']) * 5) < 1e-9, 'pack_leaders'
    assert len(_packs([(1, 12), (4, 12), (8, 11), (20, 12)])) == 2, 'packs chain within 4 tiles and a row'
    # roster: each rule caught; a Rattle listed is rattle_max's (left out);
    # banned kinds, pack_leaders and stamps; World 6 may headline the Brinejaw.
    cast = {'hushling': 4, 'skeleton': 2, 'lidlurk': 1, 'thornback': 1, 'bonebow': 1}
    good = {'headline': ['hushling'], 'support': ['bonebow'], 'guest': ['thornback'], 'rattle_max': 2, 'fodder_max': 0.8, 'count': (8, 10)}
    assert roster_problems('6-1', cast, good) == [], roster_problems('6-1', cast, good)
    assert roster_header(good) == 'headline=hushling; support=bonebow; guest=thornback; rattle_max=2; fodder_max=0.8; count=8-10', 'roster_header'
    full = dict(good, support=['bonebow', 'skeleton'], banned=['frostbuckle'], pack_leaders={'hushling': 3}, stamps=['crossfire'])
    assert roster_of(roster_header(full)) == dict(full, count=(8, 10)), 'roster_of reads roster_header back (%s)' % (roster_of(roster_header(full)),)
    assert roster_problems('6-1', cast, dict(full, stamps=[])) == [], 'a Rattle listed, a banned kind absent, pack_leaders on a listed kind'
    for bad, what in ((dict(good, rattle_max=1), 'Rattles'), (dict(good, headline=['hushling', 'stillmaw']), 'no stillmaw'),
                      (dict(good, guest=[]), 'thornback it does not declare'), (dict(good, fodder_max=0.7), 'fodder'),
                      (dict(good, count=8), 'count'), (dict(good, guest=['thornback', 'unwick']), 'no guest'),
                      (dict(good, support=['bonebow', 'lidlurk']), 'listed'), (dict(good, oops=1), 'unknown'),
                      (dict(good, guest=[], banned=['thornback']), 'banned'), (dict(good, banned=['thornback']), 'listed and banned'),
                      (dict(good, pack_leaders={'stillmaw': 2}), 'pack_leaders'), (dict(good, stamps=['nope']), 'no stamp'),
                      (dict(good, headline=['skeleton']), 'no headline kind'), (roster_of('skeleton,bat'), 'not a list of kinds')):
        p = roster_problems('6-1', cast, bad)
        assert any(what in s for s in p), 'roster catches %s (%s)' % (what, p)
    assert any('later world' in s for s in roster_problems('5-1', cast, dict(good, support=['bonebow', 'hushling']))), 'a later world'
    jaws = {'brinejaw': 3, 'hushling': 2}
    assert roster_problems('6-1', jaws, {'headline': ['brinejaw', 'hushling'], 'rattle_max': 0, 'fodder_max': 1.0}) == [] \
        and any('World 2' in s for s in roster_problems('5-1', jaws, {'headline': ['brinejaw'], 'guest': ['hushling'], 'rattle_max': 0, 'fodder_max': 1.0})), \
        'World 6 headlines the Brinejaw (HEADLINE_RETURN), World 5 may not'
    # A sealed room: a monster, a doorway of air or stone that never opens, no
    # monster by a door, an altar before it.
    rm = block('\n'.join(['#' * 24] * 2 + ['#' + '.' * 22 + '#'] * 7 + ['.' * 24] * 3 + ['.' * 12 + 's' + '.' * 11] + ['#' * 24] * 2))
    door_k = block('\n'.join(['.' * 10] * 12 + ['....K.....'] + ['#' * 10] * 2))
    lvr = join(door_k, rm)
    assert room_problems(lvr, 'ambush 10-33') == [], room_problems(lvr, 'ambush 10-33')
    for bad, what in ((swap(rm, {(0, 10): ':'}), 'doorway cell'), (swap(rm, {(23, 11): '{'}), 'doorway cell'),
                      (swap(rm, {(0, 9): 'B'}), 'doorway cell'), (swap(rm, {(21, 12): 's'}), 'within 3 columns'),
                      (swap(rm, {(12, 12): '.'}), 'no monster')):
        lb = join(door_k, bad)
        p = room_problems(lb, 'ambush 10-33')
        assert any(what in s for s in p), 'a room catches %s (%s)' % (what, p)
    assert any('altar' in s for s in room_problems(join(rm), 'ambush 0-23')), 'a room with no altar before it'
    # The written headers (check_headers): a spec spelling, an unknown twist, a
    # long lesson, a roster that's a list of kinds or misses a stamp all fail.
    lv0 = join(block('\n'.join(['.' * 20] * 12 + ['..P.....s.....K...E.'] + ['#' * 20] * 2)))
    ok_hd = [('twist', 'restless'), ('lesson', 'First Frost|Ice carries you.'), ('roster', 'headline=bat; rattle_max=1; fodder_max=1')]
    assert not _fails(check_headers, 'x-lab', lv0, ok_hd[:2]), 'check_headers passes a known twist and a lesson'
    for bad in ([('duel', '98-109')], [('twist', 'orchard_lesson')], [('lesson', 'Into the Orchard')],
                [('lesson', 'A Title Far Too Long For Its Band|x')], [('lesson', 'T|' + 'x' * 49)],
                [('roster', 'skeleton,bat')], [('anoint', '8,12:Glassed')], [('anoint', '9,12')]):
        assert _fails(check_headers, '3-9', lv0, bad), 'check_headers refuses %s' % (bad,)
    stamped = join(st, T_OPEN)
    assert level_stamps(stamped) == [('crossfire', 13, 9)] and level_stamps(join(T_OPEN, swap(st, {}))) == [('crossfire', 15, 9)], 'stamps recorded'
    rost = 'headline=bonebow,thornback; rattle_max=0; fodder_max=1'
    assert _fails(check_headers, 'x-lab', stamped, [('roster', rost)]) and not _fails(check_headers, 'x-lab', stamped, [('roster', rost + '; stamps=crossfire')]), \
        'a roster names the stamps its sections hold'
    # A v2 entry's explicit header list takes the toolkit's keys from the entry.
    v2 = header_of({'id': '1-9', 'header': [('title', 'T'), ('hints', 'h')], 'twist': 'restless', 'threat': 4.5,
                    'roster': {'headline': ['bat'], 'rattle_max': 8, 'fodder_max': 1.0}, 'sections': [sec]}, join(sec))
    assert [k for k, _v in v2] == ['title', 'twist', 'roster', 'threat', 'hints'] and dict(v2)['threat'] == '4.5', 'merged into a v2 list (%s)' % (v2,)
    # A world: the ramp, the gaps, an altar by a sealed room's door; once
    # re-cut, every level declares its roles, none shares its landmarks or its
    # altars' places, the ramp is +1, fodder falls, X-3 mixes, no crowding.
    alt = block('\n'.join(['.' * 20] * 12 + ['.' * 14 + 'K' + '.' * 5] + ['#' * 20] * 2))
    plain = block('\n'.join(['.' * 20] * 13 + ['#' * 20] * 2))
    room = block('\n'.join(['#' * 24] * 2 + ['#' + '.' * 22 + '#'] * 11 + ['#' * 24] * 2))
    start = swap(alt, {(14, 12): 'P'})
    bell = swap(alt, {(14, 12): 'E'})
    vault = swap(plain, {(10, 12): 'M'})
    mix = swap(plain, {(2, 12): 's', (8, 12): 't', (14, 12): 'h'})

    def ent(i, t, secs, **kw):
        return dict({'id': i, 'roster': good, 'threat': t, 'sections': secs}, **kw)
    w = [ent('6-1', 10.0, [start, alt, alt, alt, bell]), ent('6-2', 11.0, [start, alt, alt, room, alt, bell]),
         ent('6-3', 12.0, [start, alt, room, alt, alt, bell], room=[('duel', room)])]
    assert world_problems(w, 78) == [], world_problems(w, 78)
    assert roles_of(w[2]['sections']) == 'S A C A A B', roles_of(w[2]['sections'])
    assert landmarks_of('S C C A C C A C V A C D A C B') == 'S A V A D A B' and landmarks_of('S A A C A V') == 'S A V', 'landmarks_of'
    for bad, what in (([w[0], dict(w[1], threat=9.0), w[2]], 'ramp'),
                      ([w[0], dict(w[1], sections=[start, alt, plain, room, alt, bell], room=[('ambush', room)]), w[2]], 'ambush door'),
                      ([w[0], w[1], dict(w[2], sections=[start, alt, room, room, room, alt, alt, bell])], 'apart'),
                      ([w[0], dict(w[1], sections=w[0]['sections'], roles='S A A A B'), w[2]], 'share'),
                      ([dict(w[0], roles='S C C'), w[1], w[2]], 'declares'),
                      ([w[0], dict(w[1], sections=[start] + [alt] * 6 + [bell]), w[2]], 'altars')):
        p = world_problems(bad, 30 if what == 'apart' else 78)
        assert any(what in s for s in p), 'a world catches %s (%s)' % (what, p)
    # Re-cut: three levels with their own landmarks and altars, the ramp +1,
    # fodder falling, the X-3 mixing on two screens.
    r1 = dict(good, fodder_max=0.85)
    r2 = dict(good, fodder_max=0.75)
    r3 = dict(good, fodder_max=0.65, headline=['thornback'], support=['bonebow', 'hollow_helm'], guest=[])
    rc = [ent('6-1', 10.0, [start, plain, alt, plain, alt, vault, alt, bell], roster=r1, roles='S C A C A V A B'),
          ent('6-2', 11.0, [start, vault, alt, alt, plain, plain, alt, bell], roster=r2, roles='S V A A C C A B'),
          ent('6-3', 12.0, [start, mix, alt, plain, mix, alt, alt, vault, plain, bell], roster=r3, roles='S C A C C A A V C B')]
    assert world_problems(rc, 78) == [], world_problems(rc, 78)
    assert any('ramp: +1' in s for s in world_problems([rc[0], dict(rc[1], threat=10.5), rc[2]], 78)), 'a re-cut world ramps +1'
    assert world_problems([rc[0], dict(rc[1], threat=10.5), rc[2]], 78, 0.5) == [], "world_tables' ramp= is the world's own"
    for bad, what in (([rc[0], {k: v for k, v in rc[1].items() if k != 'roles'}, rc[2]], 'declares no roles'),
                      ([rc[0], dict(rc[1], sections=[start, plain, alt, plain, plain, alt, vault, alt, bell], roles='S C A C C A V A B'), rc[2]], 'landmarks'),
                      ([rc[0], dict(rc[1], sections=[start, vault, alt, plain, alt, plain, alt, bell], roles='S V A C A C A B'), rc[2]], 'within 8 tiles'),
                      ([dict(rc[0], roster=dict(r1, fodder_max=0.9)), rc[1], rc[2]], 'at most 0.85'),
                      ([rc[0], dict(rc[1], roster=dict(r2, fodder_max=0.86)), rc[2]], 'not under'),
                      ([rc[0], rc[1], dict(rc[2], sections=[start, plain, alt, plain, mix, alt, alt, vault, plain, bell], roles='S C A C C A A V C B')], 'screens with 3 kinds'),
                      ([rc[0], rc[1], dict(rc[2], sections=[start, swap(mix, {(4, 12): 'h', (6, 12): 'h', (10, 12): 'h', (12, 12): 'h'}), alt, plain, mix, alt, alt, vault, plain, bell])], 'in play')):
        p = world_problems(bad, 78)
        assert any(what in s for s in p), 'a re-cut world catches %s (%s)' % (what, p)
    assert any('first half' in s for s in world_problems([dict(rc[0], sections=[start, st, alt, plain, alt, vault, alt, bell], roster=dict(r1, stamps=['crossfire']))] + rc[1:], 78)), \
        'an X-1 keeps its stamps to its second half'
