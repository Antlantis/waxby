"""What every level module shares: drawing sections, joining them, the
overlay row, the header writers, and writing game/levels/<id>.txt.

Every section is 15 rows tall (row 13 is the usual floor; block(s, h) draws
a taller one), drawn with '.' for air so the columns line up; see
game/scripts/level_data.gd for the legend. A row may carry a label before a
'|' (only the first '|' splits, so the '|' mover glyph inside a row is safe):

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
columns, absolute, inclusive) and never writes it into the rows. In a level
taller than a strip a gust zone also names its section's rows (x0-x1:R:A:
y0-y1: level_gusts_header), so a deck's wind stays on its deck.

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

Shapes (the shapes part below): a level is 15 to 36 rows tall (H_MIN,
H_MAX). An entry's 'height' places each of its 15-row sections given as
(section, dy) with its row 0 on row dy (place: rock above, its pits and
pools carried down to the level's bottom), so 'sections': [(B_LOW, 9),
(B_STAIR, 4), (B_TOP, 0)] climbs from a floor on row 22 to one on row 13;
seam(dy, h) is T_OPEN at that height. A multi-storey level gives 'rows':
stack() of storeys (each a join(), its sections cropped to the storey's
rows: crop) instead of 'sections'. A level taller than H gets a stone
ceiling row ('ceiling': False leaves its top open). 'mirror': True mirrors
the joined level (mirror_rows: it plays right to left, written with
'facing: left'); mirror_rows(SEC) mirrors one section. Every place, crop and
mirror remembers its source, so (section, dx) places, span(), anoint and
room cells still name the section as drawn (x_of, y_of). A tall level's
route is the walk map's (WalkMap: the hints' order, its checkpoints' gaps on
foot) and it keeps the shape rules as it's written (shape_problems: the
descent and catch rules, the HUD band); a strip's route is x, in its facing.
A shaped level's entry may add 'drops': 'yes' (its route drops through a
one-way ledge: the bots drop through then too, by down + jump), 'roads' (two
ways through, each by the cells it passes: its threat, gaps and screens are
each road's), and its own descent rules ('max_drop': 4, 'landing': '6/2',
'lit_drops': 3, with 'lit_posts': [(section, dx, row)], lantern posts lit
from the start): see the shape rules below.

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
import heapq
import math
import os
import re

# A section's rows (and a strip's): row 13 its usual floor (FLOOR). A level
# is H_MIN to H_MAX rows (shapes: place, stack); the modes' rooms keep H.
H = 15
FLOOR = 13
H_MIN, H_MAX = 15, 36
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
# facing (left: a level played right to left, mirror_rows) follows the area.
# A shaped level's keys follow the overlay's: drops (yes: its routes drop
# through one-way ledges, the bots too: reach.gd drops_of; shape_problems
# asks for it where the walk map's route does), roads (its two ways
# through, each by the cells it passes: 'high 120,10 200,10; low 120,21',
# WalkMap.roads) and its own descent rules (max_drop, landing, lit_drops:
# descent_limits; lit_posts, the posts lit from the start: lit_posts_of).
HEADER_ORDER = ['title', 'subtitle', 'music', 'theme', 'area', 'area_abs', 'facing', 'boss', 'boss_music', 'dread', 'warden',
                'secret', 'secret_prize', 'tick', 'story_start', 'story_boss', 'story_end', 'par', 'rush',
                'cog_phase', 'weight_phase', 'chase', 'gusts', 'hush', 'drops', 'roads', 'max_drop', 'landing', 'lit_drops', 'lit_posts',
                'warden_room', 'elite_behave', 'anoint', 'twist',
                'lesson', 'roster', 'threat', 'roles', 'room', 'belt_flip', 'hints']


class Section(list):
    """A section's 15 rows (a list of str), and its overlay row or None.
    Hashed and compared by identity, so a section can key a dict (cog_phase:
    {(ES_COG, 4): 0.25}). A placed, cropped or mirrored copy (place, crop,
    mirror_rows) keeps its source, where its source's row 0 sits in it (dy)
    and whether it's mirrored (flip), so x_of and y_of find the source's dx
    and rows in it; a swap() copy is a section of its own."""
    overlay = None
    stamps = ()   # [(name, dx, dy)]: the STAMPS drawn into it (stamp())
    source = None
    dy = 0
    flip = False

    def __hash__(self):
        return id(self)

    def __eq__(self, other):
        return self is other

    def __ne__(self, other):
        return self is not other


class Rows(list):
    """A level's joined rows, with the joined overlay and where each section
    starts: parts = [(section, x0, y0)] (y0: the level row of its row 0,
    stack()'s storeys). mirrored: the whole level mirrored (mirror_rows), so
    an absolute x an entry gives is the unmirrored level's (_place)."""
    overlay = None
    parts = ()
    mirrored = False


def block(s, h=H):
    """A section from its drawing: H rows, or h (a taller one, up to H_MAX)."""
    lines = s.strip('\n').split('\n')
    over = None
    last = lines[-1] if lines else ''
    if '|' in last and last.split('|', 1)[0].strip() == 'Z':
        over = last.split('|', 1)[1]
        lines = lines[:-1]
    lines = [l.split('|', 1)[1] if '|' in l else l for l in lines]
    assert H <= h <= H_MAX, 'a section is %d to %d rows, not %d' % (H, H_MAX, h)
    assert len(lines) == h, 'section has %d rows: %r' % (len(lines), lines[0])
    w = max(len(l) for l in lines)
    # Short rows are padded with air. Never the floor rows (the bottom two)
    # past a solid end: that pads a hole to the bottom of the level (lab-1's
    # chain had one, from rows one wider above).
    for i in range(h - 2, h):
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
    """Sections side by side (all as tall: place() pads a 15-row one); a
    stack() of storeys among them keeps its own parts."""
    hs = sorted({len(b) for b in blocks})
    assert len(hs) == 1, 'joined sections are %s rows tall: place() them at the level\'s height' % hs
    rows = Rows(''.join(b[i] for b in blocks) for i in range(hs[0]))
    parts = []
    x = 0
    over = []
    any_over = False
    for b in blocks:
        if isinstance(b, Rows) and b.parts:
            parts += [(pb, x + px, py) for pb, px, py in b.parts]
        else:
            parts.append((b, x, 0))
        o = getattr(b, 'overlay', None)
        if o is not None:
            any_over = True
        over.append(o if o is not None else '.' * len(b[0]))
        x += len(b[0])
    rows.parts = parts
    rows.overlay = ''.join(over) if any_over else None
    return rows


def _root(sec):
    return getattr(sec, 'source', None) or sec


def _part(rows, section, n=0):
    """(b, x0, y0) of the n-th use of section in rows (as drawn: a mirrored
    level keeps its parts' order): the section itself where it's there, else
    the placed, cropped or mirrored copies of its source."""
    mine = [p for p in rows.parts if p[0] is section]
    if not mine:
        mine = [p for p in rows.parts if _root(p[0]) is _root(section)]
    if n < len(mine):
        return mine[n]
    raise AssertionError('section not in this level (use %d)' % n)


def x_of(rows, section, dx=0, n=0):
    """The absolute column of dx within the n-th use of section in rows (dx
    as section is drawn: in a mirrored copy its mirror's column)."""
    b, x0, _y0 = _part(rows, section, n)
    if getattr(b, 'flip', False) != getattr(section, 'flip', False):
        return x0 + len(b[0]) - 1 - dx
    return x0 + dx


def y_of(rows, section, row=0, n=0):
    """The level row of section's row (as it's drawn) in its n-th use: its
    row in a 15-row strip, row + dy where place() put it lower."""
    b, _x0, y0 = _part(rows, section, n)
    return y0 + getattr(b, 'dy', 0) - getattr(section, 'dy', 0) + row


def _flipped(rows, p):
    """True when the place p names a column of a section mirrored in rows
    (its phases turn the other way: _header_value)."""
    if isinstance(p, int):
        return bool(getattr(rows, 'mirrored', False))
    b, _x0, _y0 = _part(rows, p[0], p[2] if len(p) > 2 else 0)
    return getattr(b, 'flip', False) != getattr(p[0], 'flip', False)


def _place(rows, p):
    """An absolute x (int; in a mirrored level the unmirrored level's), or
    (section, dx) / (section, dx, n)."""
    if isinstance(p, int):
        if getattr(rows, 'mirrored', False):
            return max(len(r) for r in rows) - 1 - p
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


def level_gusts_header(rows):
    """A level's gusts header: gusts_header of its joined overlay; in a
    taller level each zone also names the rows its wind blows in, its
    section's own (':y0-y1', the rows the section drew, wherever place,
    crop or stack put it), so a storey's or a deck's wind never blows on the
    one over or under it (features/glass.gd gust_at; level_data.gd reads it).
    A zone over the level's whole height is written as before."""
    over = getattr(rows, 'overlay', None)
    if over is None:
        return ''
    h = len(rows)
    parts = getattr(rows, 'parts', ())
    if h <= H or not parts:
        return gusts_header(over)
    kinds = {'(': ('L', 'A'), ')': ('R', 'A'), '[': ('L', 'B'), ']': ('R', 'B')}
    zones = []
    for b, x0, y0 in parts:
        o = getattr(b, 'overlay', None)
        if o is None:
            continue
        dy = getattr(b, 'dy', 0)
        r0 = y0 + max(0, dy)
        r1 = y0 + min(len(b) - 1, dy + len(_root(b)) - 1)
        for a, c, ch in overlay_runs(o, '()[]'):
            zones.append([x0 + a, x0 + c, ch, r0, r1])
    zones.sort(key=lambda z: (z[3], z[4], z[0]))
    merged = []
    for z in zones:
        if merged and merged[-1][2] == z[2] and merged[-1][3:] == z[3:] and merged[-1][1] + 1 == z[0]:
            merged[-1][1] = z[1]
        else:
            merged.append(z)
    merged.sort(key=lambda z: (z[0], z[3]))
    return ', '.join('%d-%d:%s:%s%s' % (a, c, kinds[ch][0], kinds[ch][1], '' if (r0, r1) == (0, h - 1) else ':%d-%d' % (r0, r1))
                     for a, c, ch, r0, r1 in merged)


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
    foe=(place, y) (a duel's named foe). Rows and a foe's y are the
    section's as drawn where the room names one (y_of: lower in a tall
    level), else the level's; a mirrored section's columns come out left to
    right all the same."""
    out = []
    for room in rooms:
        assert len(room) in (2, 3), 'a room is (kind, where[, opts]): %r' % (room,)
        kind, where = room[0], room[1]
        opts = room[2] if len(room) > 2 else {}
        assert kind in ROOM_KINDS, 'room kind %r (one of %s)' % (kind, ', '.join(ROOM_KINDS))
        sec, sn = None, 0
        if isinstance(where, Section):
            sec = where
            x0, x1 = x_of(rows, where), x_of(rows, where, len(where[0]) - 1)
        else:
            assert len(where) == 2, "a room's where is a section or a pair of places: %r" % (where,)
            x0, x1 = _place(rows, where[0]), _place(rows, where[1])
            if not isinstance(where[0], int):
                sec, sn = where[0][0], (where[0][2] if len(where[0]) > 2 else 0)
        x0, x1 = min(x0, x1), max(x0, x1)
        s = '%s %d-%d' % (kind, x0, x1)
        if 'rows' in opts:
            y0, y1 = opts['rows']
            if sec is not None:
                y0, y1 = y_of(rows, sec, y0, sn), y_of(rows, sec, y1, sn)
            s += ' rows %d-%d' % (y0, y1)
        if 'secs' in opts:
            s += ' @%s' % _num(opts['secs'])
        if 'foe' in opts:
            fp, fy = opts['foe']
            if not isinstance(fp, int):
                fy = y_of(rows, fp[0], fy, fp[2] if len(fp) > 2 else 0)
            s += ' foe %d,%d' % (_place(rows, fp), fy)
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


def room_entry(rows, x0, x1, y0, y1, facing=1):
    """The door the route comes in by: -1 the left (x0), +1 the right (x1).
    A strip's route meets its left door first (its right, facing left); a
    taller level's is where the walk map's route first steps inside the
    room's box, from the side it comes from (a room it never enters: the
    way the route runs past it)."""
    return room_entry_at(rows, x0, x1, y0, y1, facing)[0]


def room_entry_at(rows, x0, x1, y0, y1, facing=1):
    """(side, row): room_entry's door, and the row of the route's first cell
    inside the box (None in a strip, or where it never enters; walk_map.gd
    entry_of)."""
    if len(rows) <= H:
        return -facing, None
    wm = WalkMap(rows)
    path = wm.route() or []
    for i, (_k, x, y) in enumerate(path):
        if x0 <= x <= x1 and y0 <= y <= y1:
            px = path[i - 1][1] if i else x
            if px < x0 or px > x1:
                return (-1 if px < x0 else 1), y
            return (-1 if x - x0 <= x1 - x else 1), y
    return -wm.dir_at(wm.proj(((x0 + x1) // 2, (y0 + y1) // 2))), None


def deck_door_rows(rows, x, y0, y1, row):
    """The doorway run (its rows, inclusive) of column x between rows y0 and
    y1 that the route's entry row comes in at (the run holding it, else the
    nearest), or None: a two-deck room's door on the deck he comes in on."""
    runs = []
    y = y0
    while y <= y1:
        if _tile(rows, x, y, 'solid') != 'solid':
            a = y
            while y + 1 <= y1 and _tile(rows, x, y + 1, 'solid') != 'solid':
                y += 1
            runs.append((a, y))
        y += 1
    if not runs or row is None:
        return None
    return min(runs, key=lambda r: 0 if r[0] <= row <= r[1] else min(abs(row - r[0]), abs(row - r[1])))


def room_problems(rows, value, facing=1):
    """What breaks the sealed rooms of a written 'room' header, as strings:
    each holds a monster, has a way in at an end, and has an altar within
    ROOM_ALTAR_REACH tiles before the door the route comes in by
    (room_entry: the left one in a strip, the right facing left; a snuff
    inside relights by it, as at a boss's door); every doorway cell is air
    or DOOR_SOLID; no monster of it stands within ROOM_DOOR_CLEAR columns of
    either end (tests/level_rules.gd room_problems reads the file the
    same)."""
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
        side, row = room_entry_at(rows, x0, x1, y0, y1, facing)
        before = [(x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == 'K'
                  and ((x0 - ROOM_ALTAR_REACH <= x < x0) if side < 0 else (x1 < x <= x1 + ROOM_ALTAR_REACH))]
        if not before:
            out.append('%s has no altar within %d tiles before its %s door (altars at %s)'
                       % (room, ROOM_ALTAR_REACH, 'left' if side < 0 else 'right', altars))
        else:
            band = deck_door_rows(rows, x0 if side < 0 else x1, y0, y1, row)
            if band is not None and not any(band[0] - 1 <= ay <= band[1] for _ax, ay in before):
                out.append('%s has no altar on the deck of its %s door (its doorway rows %d-%d; altars at %s)'
                           % (room, 'left' if side < 0 else 'right', band[0], band[1], before))
    return out


def check_rooms(name, rows, value, facing=1):
    """Asserts every sealed room of a written 'room' header keeps its rules
    (room_problems)."""
    if not value:
        return
    probs = room_problems(rows, value, facing)
    assert not probs, '%s: %s' % (name, '; '.join(probs))


def mirror_rows(rows):
    """The mirror of a section or a level (the Descent's mirror too):
    reversed, with exactly the MIRROR swaps (a belt's way, a cog's turn) and
    its overlay's gusts turned. A Section comes back a Section that knows its
    source (flip), its stamps mirrored, so x_of finds the source's dx in it; a
    level's Rows keeps its parts (in their order as drawn), each mirrored in
    its new place, and is marked mirrored (an absolute x an entry gives is
    the unmirrored level's: _place). The phases that turn with the mirror
    (weight_phase, cog_phase) are header_of's (mirror_phases)."""
    w = max(len(r) for r in rows) if rows else 0
    flipped = [''.join(MIRROR.get(c, c) for c in reversed(r.ljust(w, '.'))) for r in rows]
    over = getattr(rows, 'overlay', None)
    if isinstance(rows, Section):
        out = Section(flipped)
        out.source = _root(rows)
        out.dy = rows.dy
        out.flip = not rows.flip
        out.stamps = [(nm, w - 1 - sx, sy) for nm, sx, sy in rows.stamps]
    else:
        out = Rows(flipped)
        out.parts = [(mirror_rows(b), w - x0 - len(b[0]), y0) for b, x0, y0 in getattr(rows, 'parts', ())]
        out.mirrored = not getattr(rows, 'mirrored', False)
    if over is not None:
        out.overlay = ''.join(MIRROR_OVERLAY.get(c, c) for c in reversed(over.ljust(w, '.')))
    return out


# ---------------------------------------------------------------- writing

def _order_hints(kv, rows, facing=1):
    """Hints are written in the order the route meets their signs (a
    strip's left to right, or right to left facing left; a taller level's
    along the walk map's route: route_order); the game hands them to the
    signs in reading order (row by row), so reorder them to match."""
    key, value = kv
    if key != 'hints':
        return kv
    hints = value.split('|')
    signs = [(x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == '@']
    assert len(signs) == len(hints), 'level has %d signs but %d hints' % (len(signs), len(hints))
    by_route = route_order(rows, signs, facing)
    text = {pos: hints[i] for i, pos in enumerate(by_route)}
    reading = sorted(signs, key=lambda p: (p[1], p[0]))
    return (key, '|'.join(text[p] for p in reading))


def _report(name, rows, roads=''):
    """Where the start, altars, bell and boss are, for the checkpoint-gap rule
    (a taller level's along its route: checkpoint_gaps; each road's)."""
    if len(rows) <= H:
        marks, gaps = checkpoint_gaps(rows)
        return 'checkpoints at %s (gaps %s)' % (marks, gaps)
    return '; '.join('checkpoints along the %sroute at %s (gaps %s)' % (('%s road\'s ' % n) if n else '', m, g)
                     for n, m, g in road_gaps(rows, roads))


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
    keys and its shape checked first (check_headers, check_shape; world: the
    level's, else its id's)."""
    check_legend(name, rows)
    if SIGN_BUDGET:
        check_sign_budget(name, rows)
    header = list(header)
    keys = [k for k, _v in header]
    over = getattr(rows, 'overlay', None)
    if over is not None:
        extra = []
        g = level_gusts_header(rows)
        if g and 'gusts' not in keys:
            extra.append(('gusts', g))
        hz = hush_header(over)
        if hz and 'hush' not in keys:
            extra.append(('hush', hz))
        # Before the hints (which stay last, as v2 wrote them).
        at = keys.index('hints') if 'hints' in keys else len(header)
        header = header[:at] + extra + header[at:]
    header = [_order_hints(kv, rows, facing_of(header)) for kv in header]
    check_headers(name, rows, header, world)
    check_shape(name, rows, header)
    text = ''.join('%s: %s\n' % kv for kv in header) + '---\n' + '\n'.join(r.rstrip('.') for r in rows) + '\n'
    d = out_dir or OUT
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, name + '.txt'), 'w') as f:
        f.write(text)
    print('%s: %d x %d  %s' % (name, max(len(r) for r in rows), len(rows), _report(name, rows, dict(header).get('roads', ''))))
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
        v = phases_header({_phase_key(rows, k, _place(rows, p), _flipped(rows, p)): _turned(k, t, _flipped(rows, p))
                           for p, t in v.items()})
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
    elif k == 'lit_posts' and not isinstance(v, str):
        v = '; '.join('%d,%d' % (x_of(rows, sec, dx), y_of(rows, sec, dy)) for sec, dx, dy in v)
    elif _has_span(v):
        v = spans_header(rows, v, SPAN_SEP.get(k, '@'))
    return str(v)


def _turned(k, t, flipped):
    """A phase in a mirrored section: a weight's or swing's half a swing on,
    a cog's 1 - turns (mirror_phases)."""
    if not flipped:
        return t
    return (float(t) + 0.5) % 1.0 if k == 'weight_phase' else (1.0 - float(t)) % 1.0


def _phase_key(rows, k, x, flipped):
    """A weight_phase key in a mirrored section: a swing's is its run's
    first column, which the mirror made its last."""
    if k == 'weight_phase' and flipped:
        for r in rows:
            if x < len(r) and r[x] == 'T':
                while x > 0 and r[x - 1] == 'T':
                    x -= 1
                return x
    return x


def header_of(entry, rows):
    """An entry's ordered header: its own 'header' list (v2's, kept as it
    was, with the toolkit's MERGE_KEYS from the entry put before its hints),
    or one built from its keys in HEADER_ORDER (_header_value). An entry's
    'world' (a fixture's) and 'out_dir' aren't headers, nor its shape's
    keys ('rows', 'height', 'ceiling', 'mirror'); a mirrored one is written
    'facing: left', its every weight's, swing's and cog's phase turned with
    it (mirror_phases)."""
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
    skip = {'id', 'name', 'sections', 'header', 'subtitle', 'out_dir', 'world', 'rows', 'height', 'ceiling', 'mirror'}
    mirrored = bool(entry.get('mirror'))
    if mirrored:
        vals['facing'] = entry.get('facing', 'left')
        rows0 = level_rows(entry, False)
        wp, cp = mirror_phases(rows0, {_place(rows0, p): t for p, t in entry.get('weight_phase', {}).items()},
                               {_place(rows0, p): t for p, t in entry.get('cog_phase', {}).items()})
        if wp:
            vals['weight_phase'] = phases_header(wp)
        if cp:
            vals['cog_phase'] = phases_header(cp)
        skip |= {'facing', 'weight_phase', 'cog_phase'}
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
    """Joins an entry's sections (level_rows: placed, stacked, mirrored) and
    writes its file (write() checks its Build 2 headers and its shape as
    written: check_headers, check_shape)."""
    rows = level_rows(entry)
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


# ================================================================ shapes
# Build 2's shaped levels (the shape plan's E1, E2, E7, E8): a level up to
# H_MAX rows, cut from 15-row sections placed at a height, storeys stacked,
# or mirrored to play right to left; the walk map that finds its route; and
# the rules a shaped level keeps (shape_problems). A strip (H rows, played
# left to right) is written and checked exactly as before.

# The cells under a placed section's bottom row (place): rock under solid,
# water under its water (a pool stays deep), air under the rest (a pit stays
# a pit to the level's bottom).
_UNDER_WATER = set(':&fJH7')


def place(section, dy, h, above='#'):
    """section (15 rows, or any up to h) as h rows with its row 0 on row dy:
    rock above it ('.': open air), and under its bottom row rock under each
    solid cell, water under water, air under the rest. Its stamps move down
    with it; it remembers its source and dy (x_of, y_of find the source's
    columns and rows)."""
    n, w = len(section), len(section[0])
    assert 0 <= dy and dy + n <= h <= H_MAX, 'place: %d rows at dy %d in %d (at most %d)' % (n, dy, h, H_MAX)
    assert above in ('#', '.'), "place: above is '#' (rock) or '.' (air), not %r" % above
    under = ''.join('#' if c in SOLID else (':' if c in _UNDER_WATER else '.') for c in section[-1])
    out = Section([above * w] * dy + list(section) + [under] * (h - dy - n))
    out.overlay = getattr(section, 'overlay', None)
    out.stamps = [(nm, sx, sy + dy) for nm, sx, sy in getattr(section, 'stamps', ())]
    out.source = _root(section)
    out.dy = getattr(section, 'dy', 0) + dy
    out.flip = getattr(section, 'flip', False)
    return out


def crop(section, top=0, bottom=0):
    """section less its top rows and bottom rows (a storey's rows, for
    stack()); what's cut must be bare air and stone, so nothing drawn is
    lost."""
    n = len(section)
    cut = list(section[:top]) + list(section[n - bottom:] if bottom else [])
    assert all(set(r) <= set('.#') for r in cut), 'crop: the rows cut hold more than air and stone: %r' % cut
    out = Section(section[top:n - bottom])
    out.overlay = getattr(section, 'overlay', None)
    out.stamps = [(nm, sx, sy - top) for nm, sx, sy in getattr(section, 'stamps', ())]
    assert all(0 <= sy < len(out) for _nm, _sx, sy in out.stamps), 'crop: a stamp is in the rows cut'
    out.source = _root(section)
    out.dy = getattr(section, 'dy', 0) - top
    out.flip = getattr(section, 'flip', False)
    return out


def seam(dy=0, h=H):
    """T_OPEN (the doorway every world's sections meet at) with its floor on
    row FLOOR + dy of an h-row level."""
    return T_OPEN if (dy, h) == (0, H) else place(T_OPEN, dy, h)


def floor_row(dy=0):
    """The usual floor row of a section placed at dy."""
    return FLOOR + dy


def stack(*storeys):
    """Storeys top to bottom (each a join() or a section, all as wide), as
    one level's rows: their parts keep their rows (y0), and their overlays
    merge (a gust or Hush column is a whole column of the level)."""
    out = Rows()
    parts = []
    over = None
    width = None
    top = 0
    for s in storeys:
        r = s if isinstance(s, Rows) else join(s)
        w = max(len(x) for x in r)
        assert width is None or w == width, 'stack: storeys are %d and %d wide' % (width, w)
        width = w
        out.extend(x.ljust(w, '.') for x in r)
        parts += [(b, x0, y0 + top) for b, x0, y0 in r.parts]
        o = getattr(r, 'overlay', None)
        if o is not None:
            o = o.ljust(w, '.')
            if over is None:
                over = o
            else:
                assert all(a == '.' or b == '.' or a == b for a, b in zip(over, o)), 'stack: two storeys overlay one column'
                over = ''.join(b if a == '.' else a for a, b in zip(over, o))
        top += len(r)
    out.parts = parts
    out.overlay = over
    return out


def ceiling(rows):
    """A tall level's stone ceiling: row 0's air made stone (nothing climbs
    out of the top of a tower)."""
    out = Rows([rows[0].replace('.', '#')] + list(rows[1:]))
    out.parts, out.overlay = getattr(rows, 'parts', ()), getattr(rows, 'overlay', None)
    out.mirrored = getattr(rows, 'mirrored', False)
    return out


def level_rows(entry, mirror=True):
    """An entry's rows: its 'rows' (a stack() of storeys), or its 'sections'
    joined, a (section, dy) among them placed at the entry's 'height' (H by
    default); a tall level's stone ceiling (ceiling(); 'ceiling': False
    leaves it open), and 'mirror': True mirrors the lot (mirror=False: as
    drawn, the phases' reference: mirror_phases)."""
    if 'rows' in entry:
        rows = entry['rows']
    else:
        h = int(entry.get('height', H))
        secs = [place(s[0], s[1], h) if isinstance(s, tuple) else s for s in entry['sections']]
        rows = join(*secs)
    if len(rows) > H and entry.get('ceiling', True):
        rows = ceiling(rows)
    if mirror and entry.get('mirror'):
        rows = mirror_rows(rows)
    return rows


def phases_of(rows, weight_phase=None):
    """{x: turns} for every pendulum weight (Y, keyed by its column) and
    swing (a T run, by its first column) as features/clockwork.gd sets them:
    weight_phase's {x: turns}, else 0 and 0.5 in turn in reading order (one
    count for the weights, one for the swings)."""
    given = dict(weight_phase or {})
    out = {}
    n_weight = n_swing = 0
    for r in rows:
        x = 0
        while x < len(r):
            ch = r[x]
            if ch == 'T':
                x1 = x
                while x1 + 1 < len(r) and r[x1 + 1] == 'T':
                    x1 += 1
                out[x] = given.get(x, 0.5 * (n_swing % 2))
                n_swing += 1
                x = x1 + 1
                continue
            if ch == 'Y':
                out[x] = given.get(x, 0.5 * (n_weight % 2))
                n_weight += 1
            x += 1
    return out


def mirror_phases(rows, weight_phase=None, cog_phase=None):
    """A level's phases in its mirror (rows: the unmirrored level): every
    weight and swing written (phases_of: the defaults count in reading order,
    which a mirror reverses), each at its mirrored column (a swing's first
    column is its run's mirrored end) half a swing on (the mirror's angle is
    the other way); each cog_phase at its mirrored hub, 1 - turns (the MIRROR
    swap turns it the other way). Returns (weight_phase, cog_phase) {x: turns}."""
    w = max(len(r) for r in rows)
    runs = {}
    for r in rows:
        x = 0
        while x < len(r):
            if r[x] == 'T':
                x1 = x
                while x1 + 1 < len(r) and r[x1 + 1] == 'T':
                    x1 += 1
                runs[x] = x1 - x + 1
                x = x1 + 1
            else:
                x += 1
    wp = {}
    for x, t in phases_of(rows, weight_phase).items():
        mx = w - x - runs[x] if x in runs else w - 1 - x
        wp[mx] = (float(t) + 0.5) % 1.0
    cp = {w - 1 - x: (1.0 - float(t)) % 1.0 for x, t in (cog_phase or {}).items()}
    return wp, cp


# ---------------------------------------------------------------- the walk map
# A coarse map of where Waxby can go, for the rules that need a level's
# route where it isn't a strip (taller than H): the order the route meets
# things (the hints, the barks), how far apart its checkpoints are on foot,
# and the descent rules. game/scripts/walk_map.gd is the same map, move for
# move (the barks and tests/level_rules.gd read it). A strip's route is x, in
# its facing.
#
# A state is standing in a cell (S: it and the cell over it clear of solid,
# no hazard in either, a floor under it: solid, a one-way top, dawnglass, a
# float, or a mover's swept band) or holding a vine cell (C). The moves, in
# this order, each with its cost (columns, rows climbed, a jump's 1, a
# break's 2) and its drop (rows fallen):
#   S: walk a column (onto a cell or off an edge: a fall; into brick, false
#      stone or rime: +2); drop through a one-way top (or a breakable floor,
#      as broken when he came in: +2); grab a vine where he
#      stands or just over him; jump: feet up 0-3 rows, then 0-8 columns at
#      that height, then a fall, landing h rows up at most JUMP_REACH[h]
#      columns away (or a vine caught on the way), counted cell to cell at
#      the most a run and the coyote time carry him (a held jump clears 3
#      rows; on the flat a 6-tile gap at a pinch: generous, so a rule never
#      calls a way the bot proves closed)
#   C: climb, slide, stand at its foot, hop off sideways, mount a floor 1-2
#      columns off its top cell (no roof), let go at its bottom, leap: feet
#      up 0-2 rows, a fall, LEAP_REACH (4 columns vine to vine)
# A fall catches the first vine cell it passes (or goes on, down held) and
# ends on the first floor; a hazard (spikes, lava, deep water) or the
# level's bottom ends it with no state (a snuff). Monsters aren't there.
# The goal is touched from its cell, the cells either side and the two over
# it (the bell's rope hangs 70 px: rung from its roof, as 3-1's alcove is).
# Breakable cells (brick, false stone, rime) are floors to land on and
# doors to walk into. Movers sweep: a lift 3 rows up and down, a moving
# ledge or a swing 3 columns either way, a cog's teeth its ring (radius 3).
JUMP_UP = 3
JUMP_ACROSS = 8
JUMP_REACH = {3: 4, 2: 5, 1: 6, 0: 7, -1: 7, -2: 7}    # rows up -> columns (lower: 8)
LEAP_UP = 2
LEAP_ACROSS = 5
LEAP_REACH = {2: 2, 1: 3, 0: 4, -1: 4}                 # lower: 5
MOUNT_REACH = 2
MOVER_SWEEP = 3
COG_RING = 3
BREAKABLE = set('BFZ')
HAZARD_GLYPHS = set('^v~')
WALK_SUPPORT = SOLID_GLYPHS | set('=%_A')


def roads_of(value):
    """[(name, [(x, y), ...])] from a written roads header ('high 120,10
    200,10; low 120,21'): each road by the cells it passes, in turn (a part
    that doesn't read is left out; walk_map.gd roads_of reads it the same)."""
    out = []
    for part in str(value or '').split(';'):
        bits = part.split()
        if len(bits) < 2:
            continue
        via = []
        for b in bits[1:]:
            xy = b.split(',')
            if len(xy) == 2 and xy[0].strip().lstrip('-').isdigit() and xy[1].strip().lstrip('-').isdigit():
                via.append((int(xy[0]), int(xy[1])))
        if via:
            out.append((bits[0], via))
    return out


class WalkMap(object):
    """The walk map of a level's rows (see above). route() is the cheapest
    way from the start to the goal (the bell, else the boss, else a silver
    bell), as states (kind, x, y); proj(cell) the index on it nearest a
    cell; reach() every state reachable and the edges between them. A level
    with two ways through names its roads (a 'roads' header: roads_of):
    roads() is each one's route, by way of its cells in turn, and road_of()
    which a cell is on (the nearest; the stretches they share, every one's).
    t is the rows as the game reads their tiles: a pod, glowfruit, Creepbone
    or Dread drawn in a vine column is that vine (level_data.gd: the vine
    over it first, else the one under it), so the catch rules find a rotten
    run's foot where the game does."""

    def __init__(self, rows, roads=''):
        self.w = max(len(r) for r in rows)
        self.h = len(rows)
        self.g = [r.ljust(self.w, '.') for r in rows]
        w, h = self.w, self.h
        t = [list(r) for r in self.g]
        for y in range(h):
            for x in range(w):
                if self.g[y][x] in CARRIERS:
                    for dy in (-1, 1):
                        if 0 <= y + dy < h and t[y + dy][x] in CLIMB:
                            t[y][x] = t[y + dy][x]
                            break
        self.t = [''.join(r) for r in t]
        self.roads_spec = roads_of(roads)
        self._roads = None
        self.cls = [[_tile(self.g, x, y, 'solid') for x in range(w)] for y in range(h)]
        self.band = set()
        for y, r in enumerate(self.g):
            x = 0
            while x < w:
                ch = r[x]
                if ch in '-|T':
                    x1 = x
                    while x1 + 1 < w and r[x1 + 1] == ch:
                        x1 += 1
                    if ch == '|':
                        self.band |= {(cx, y + o) for cx in range(x, x1 + 1) for o in range(-MOVER_SWEEP, MOVER_SWEEP + 1)}
                    else:
                        self.band |= {(cx, y) for cx in range(x - MOVER_SWEEP, x1 + MOVER_SWEEP + 1)}
                    x = x1 + 1
                    continue
                if ch in 'OQ':
                    for j in range(-COG_RING, COG_RING + 1):
                        for i in range(-COG_RING, COG_RING + 1):
                            if COG_RING - 0.5 <= math.hypot(i, j) < COG_RING + 0.5:
                                self.band.add((x + i, y + j))
                x += 1
        self.marks = {}
        for y, r in enumerate(self.g):
            for x, ch in enumerate(r):
                if ch in 'PEXS' and ch not in self.marks:
                    self.marks[ch] = (x, y)
        self._route = None

    # -- cells
    def solid(self, x, y):
        if x < 0 or x >= self.w:
            return True
        if y < 0 or y >= self.h:
            return False
        return self.cls[y][x] == 'solid' and self.g[y][x] not in BREAKABLE

    def hazard(self, x, y):
        if x < 0 or x >= self.w or y < 0 or y >= self.h:
            return False
        if self.g[y][x] in HAZARD_GLYPHS:
            return True
        return self.cls[y][x] == 'water' and y + 1 < self.h and self.cls[y + 1][x] == 'water'

    def climb(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h and self.cls[y][x] == 'climb'

    def support(self, x, y):
        if x < 0 or x >= self.w:
            return True
        if y < 0 or y >= self.h:
            return False
        return self.g[y][x] in WALK_SUPPORT or self.g[y][x] == '&' or (x, y) in self.band

    def one_way(self, x, y):
        """A floor he can drop through (a one-way top, a float, a mover)."""
        return 0 <= x < self.w and 0 <= y < self.h and self.support(x, y) and self.cls[y][x] != 'solid'

    def body(self, x, y):
        """His body fits at (x, y): it and the cell over it clear, no hazard."""
        return 0 <= y < self.h and not self.solid(x, y) and not self.solid(x, y - 1) \
            and not self.hazard(x, y) and not self.hazard(x, y - 1)

    def stand(self, x, y):
        return self.body(x, y) and self.support(x, y + 1)

    def breaks(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h and self.g[y][x] in BREAKABLE

    # -- moves
    def falls(self, x, y):
        """Where a fall from body cell (x, y) ends: [(state, ...)], the first
        vine cell it passes (caught), then the floor (down held past it); []
        a snuff."""
        out = []
        caught = False
        yy = y
        while yy < self.h:
            if not self.body(x, yy):
                return out
            if not caught and self.climb(x, yy):
                out.append(('C', x, yy))
                caught = True
            if self.support(x, yy + 1):
                out.append(('S', x, yy))
                return out
            yy += 1
        return out

    def _arc(self, x, y, up, across, reach, out, base):
        """A jump (or a leap) from (x, y): feet up k rows, then n columns at
        that height, then a fall (a vine caught on the way); landing h rows
        up at most reach(h) away."""
        for k in range(0, up + 1):
            if not self.body(x, y - k):
                break
            for d in (1, -1):
                for n in range(0 if d == 1 and k else 1, across + 1):
                    cx = x + d * n
                    if n and not self.body(cx, y - k):
                        break
                    for st in self.falls(cx, y - k):
                        hh = y - st[2]
                        if n <= reach.get(hh, (reach['low'] if hh < 0 else -1)):
                            out.append((st, n + max(hh, 0) + base, max(0, st[2] - y)))

    def moves(self, s):
        """[(state, cost, drop)] from state s, in the map's order (each state
        once, at its cheapest: the drop from s to it is the same however he
        gets there)."""
        kind, x, y = s
        out = []
        if kind == 'S':
            for d in (1, -1):
                nx = x + d
                if self.body(nx, y):
                    cost = 3 if self.breaks(nx, y) or self.breaks(nx, y - 1) else 1
                    for st in self.falls(nx, y):
                        out.append((st, cost, st[2] - y))
            if self.one_way(x, y + 1) or self.breaks(x, y + 1):
                for st in self.falls(x, y + 1):
                    out.append((st, 1 if self.one_way(x, y + 1) else 3, st[2] - y))
            if self.climb(x, y):
                out.append((('C', x, y), 1, 0))
            if self.climb(x, y - 1) and self.body(x, y - 1):
                out.append((('C', x, y - 1), 1, 0))
            self._arc(x, y, JUMP_UP, JUMP_ACROSS, dict(JUMP_REACH, low=8), out, 1)
        else:
            if self.climb(x, y - 1) and self.body(x, y - 1):
                out.append((('C', x, y - 1), 1, 0))
            if self.climb(x, y + 1) and self.body(x, y + 1):
                out.append((('C', x, y + 1), 1, 0))
            if self.support(x, y + 1):
                out.append((('S', x, y), 1, 0))
            for d in (1, -1):
                if self.body(x + d, y):
                    for st in self.falls(x + d, y):
                        out.append((st, 1, st[2] - y))
            if not self.climb(x, y - 1) and self.body(x, y - 1):
                for d in (1, -1):
                    for m in range(1, MOUNT_REACH + 1):
                        if not self.body(x + d * m, y - 1):
                            break
                        if self.stand(x + d * m, y - 1):
                            out.append((('S', x + d * m, y - 1), m + 1, 0))
            if not self.climb(x, y + 1) and not self.support(x, y + 1):
                for st in self.falls(x, y + 1):
                    out.append((st, 1, st[2] - y))
            self._arc(x, y, LEAP_UP, LEAP_ACROSS, dict(LEAP_REACH, low=5), out, 1)
        best = {}
        for st, c, dr in out:
            if st != s and (st not in best or c < best[st][0]):
                best[st] = (c, dr)
        seen = set()
        moves = []
        for st, _c, _dr in out:
            if st in best and st not in seen:
                seen.add(st)
                moves.append((st,) + best[st])
        return moves

    def start(self):
        p = self.marks.get('P')
        return ('S', p[0], p[1]) if p and self.stand(*p) else None

    def goal(self):
        for ch in 'EXS':
            if ch in self.marks:
                return ('S',) + self.marks[ch]
        return None

    def touches(self, s, cells=None):
        """s touches the goal (its cell, either side, or the two over it), or
        one of cells."""
        for g in (cells if cells is not None else [self.goal()]):
            if g is not None and abs(s[1] - g[1]) <= 1 and 0 <= g[2] - s[2] <= 2:
                return True
        return False

    def exits(self):
        """Every way out: the bell, the boss, each silver bell (it clears the
        level by its secret way: an attic needs no way back down)."""
        return [('S', x, y) for y, r in enumerate(self.g) for x, ch in enumerate(r) if ch in 'EXS']

    def route(self):
        """The cheapest way from the start to the goal, [(kind, x, y)] (None:
        there's none). Ties go to the state found first (the moves' order)."""
        if self._route is not None:
            return self._route or None
        goal = self.goal()
        self._route = (self._search(self.start(), [goal], False) if goal else None) or []
        return self._route or None

    def _search(self, start, cells, exact):
        """The cheapest way from state start to one touching cells (exact:
        standing or hanging in one of them), [(kind, x, y)]; None for none."""
        if start is None:
            return None
        want = {(c[-2], c[-1]) for c in cells}
        dist = {start: 0}
        parent = {start: None}
        pq = [(0, 0, start)]
        n = 1
        goal = None
        while pq:
            c, _i, s = heapq.heappop(pq)
            if c > dist[s]:
                continue
            if ((s[1], s[2]) in want) if exact else self.touches(s, cells):
                goal = s
                break
            for t, cost, _drop in self.moves(s):
                nc = c + cost
                if t not in dist or nc < dist[t]:
                    dist[t] = nc
                    parent[t] = s
                    heapq.heappush(pq, (nc, n, t))
                    n += 1
        if goal is None:
            return None
        path = [goal]
        while parent[path[-1]] is not None:
            path.append(parent[path[-1]])
        return path[::-1]

    def route_via(self, via):
        """The cheapest way from the start to the goal by way of the cells via
        in turn (standing or hanging in each); None when a leg has none."""
        start, goal = self.start(), self.goal()
        if start is None or goal is None:
            return None
        path = [start]
        for c in via:
            leg = self._search(path[-1], [c], True)
            if leg is None:
                return None
            path += leg[1:]
        last = self._search(path[-1], [goal], False)
        return None if last is None else path + last[1:]

    def roads(self):
        """[(name, path)]: each named road's route (a road whose way isn't
        there: an empty path), or the one road, route(), named ''."""
        if self._roads is None:
            if not self.roads_spec:
                self._roads = [('', self.route() or [])]
            else:
                self._roads = [(name, self.route_via(via) or []) for name, via in self.roads_spec]
        return self._roads

    @staticmethod
    def near(path, cell):
        """How far cell is from a route (columns, and rows twice over, as
        proj): its nearest state's; a large number for an empty one."""
        return min([abs(x - cell[0]) + 2 * abs(y - cell[1]) for _k, x, y in path] or [1 << 20])

    def road_of(self, cell):
        """The roads (indices into roads()) a cell is on: the nearest, every
        one as near."""
        d = [self.near(p, cell) for _n, p in self.roads()]
        return [i for i, v in enumerate(d) if v == min(d)]

    def proj(self, cell):
        """The index on the route nearest cell (columns, and rows twice over:
        his own storey first); ties to the earlier."""
        best, bi = None, 0
        for i, (_k, x, y) in enumerate(self.route() or []):
            d = abs(x - cell[0]) + 2 * abs(y - cell[1])
            if best is None or d < best:
                best, bi = d, i
        return bi

    def run_lengths(self, path=None):
        """The route's (or path's) length on foot to each of its states:
        columns walked and rows climbed (a fall's rows are free)."""
        out = [0]
        path = (self.route() or []) if path is None else path
        for a, b in zip(path, path[1:]):
            out.append(out[-1] + abs(b[1] - a[1]) + max(0, a[2] - b[2]))
        return out

    def dir_at(self, i):
        """Which way the route runs at index i (+1 right, -1 left): the
        columns it covers over the next few states, else the last few."""
        path = self.route() or []
        for j0, j1 in ((i, min(i + 6, len(path) - 1)), (max(i - 6, 0), i)):
            if j1 > j0 and path[j1][1] != path[j0][1]:
                return 1 if path[j1][1] > path[j0][1] else -1
        return 1

    def reach(self, max_drop=None, allow=None):
        """Every state reachable from the start ({state: [(next, drop)]}), only
        by falls of max_drop rows or less when it's given, and only by the
        moves allow(from, to, drop) passes when it's given (a level's own
        descent rules: descent_limits)."""
        start = self.start()
        if start is None:
            return {}
        edges = {start: []}
        todo = [start]
        while todo:
            s = todo.pop()
            for t, _c, drop in self.moves(s):
                if max_drop is not None and drop > max_drop:
                    continue
                if allow is not None and not allow(s, t, drop):
                    continue
                edges[s].append((t, drop))
                if t not in edges:
                    edges[t] = []
                    todo.append(t)
        return edges


def route_order(rows, cells, facing=1):
    """cells in the order the route meets them: a strip's by x in its facing
    (ties as given), a taller level's by the walk map's route (WalkMap.proj;
    ties by x in its facing)."""
    if len(rows) <= H:
        return sorted(cells, key=lambda c: c[0] * facing)
    wm = WalkMap(rows)
    return sorted(cells, key=lambda c: (wm.proj(c), c[0] * facing))


def parts_in_route_order(rows, facing=1):
    """A level's parts [(section, x0, y0)] in the order the route meets them:
    a strip's by x in its facing, a taller level's by where the walk map's
    route first steps into each (one it never enters: its middle's nearest
    index)."""
    parts = list(getattr(rows, 'parts', ()))
    if len(rows) <= H:
        return sorted(parts, key=lambda p: p[1] * facing)
    wm = WalkMap(rows)
    path = wm.route() or []

    def key(p):
        b, x0, y0 = p
        x1, y1 = x0 + len(b[0]) - 1, y0 + len(b) - 1
        for i, (_k, x, y) in enumerate(path):
            if x0 <= x <= x1 and y0 <= y <= y1:
                return (i, x0 * facing)
        return (wm.proj(((x0 + x1) // 2, (y0 + y1) // 2)), x0 * facing)
    return sorted(parts, key=key)


def first_half(rows, cells, facing=1):
    """The cells in the first half of a level's route (a strip's first half
    of its width, in its facing; a taller level's by the walk map's route)."""
    width = max(len(r) for r in rows)
    if len(rows) <= H:
        return [c for c in cells if (c[0] if facing > 0 else width - 1 - c[0]) < width // 2]
    wm = WalkMap(rows)
    n = len(wm.route() or [])
    return [c for c in cells if wm.proj(c) < n // 2]


def facing_of(header):
    """-1 for a 'facing: left' header, else 1."""
    return -1 if str(dict(header).get('facing', '')).strip() == 'left' else 1


# ---------------------------------------------------------------- the shape rules
# What a level keeps whatever its shape (shape_problems, as it's written;
# tests/level_rules.gd reads the file the same): H_MIN to H_MAX rows; no
# goal under the HUD's top corners where the camera stops at the level's top
# (hud_problems: the view and the HUD's corners in px, world.gd's camera and
# hud.gd's layout). A level taller than H keeps the descent rules: its goal
# reached with no fall over MAX_DROP rows (what he sees under his feet
# standing: a required drop's landing is in view), and from every state the
# walk map reaches, the goal still reached (every landing leads somewhere:
# a fall inside a tall level isn't a snuff); and the catch rules: a fall
# from a floor that gives way (a crumble, dawnglass, glass, a rotten vine)
# lands within CATCH_ROWS rows (a catch floor, not the bottom of the climb)
# or snuffs, and no monster stands within CATCH_CLEAR columns of where it
# lands (nor, where the landing gives way too, a lily over a pool, of the
# next catch or the water it ends in: _catch_rows). A strip's falls are pits
# (a snuff), as before.
#
# A level may hold itself to more (its header; descent_limits, and
# tests/level_rules.gd reads the same keys back):
#   max_drop: 4     its goal reached with no fall over 4 rows (1-2, 3-3,
#                   6-1: a teaching level's every drop lands in view)
#   landing: 6/2    ...and none landing more than 6 columns off and more
#                   than 2 rows lower (5-2's wind jumps: further and lower is
#                   under the right thumb's buttons; 6-1's 5/0: in view ahead)
#   lit_drops: 3    ...and every fall onto a floor (a vine or a lift is no
#                   fall) at most 3 rows, onto a landing lit before he gets
#                   there: in a sconce's light (where the theme's sconces
#                   give light: not W6's), a lit post's, or a lantern's, an
#                   altar's or a Vigil candle's that the route has passed
#                   (they burn only once touched: lit_cells; LIGHTS; 6-2: no
#                   blind drops)
#   lit_posts: x,y  lantern posts lit from the start that never burn down
#                   (level_features.gd: a steady flame; 6-2's landing lights)
#   drops: yes      the bots drop through one-way ledges (reach.gd drops_of):
#                   a taller level whose route drops through one must say so
# A lamplit level (twist: lamplit) keeps its lilies in its lanterns' reach
# (lamp_problems): a run of soft wax by a lantern is held whole when it
# burns (a far run may stay soft, as the lab's does).
# A taller level with waxfalls ('!', level_features.gd: on FALL_ON s, off
# FALL_OFF) keeps its drops clear of them (waxfall_problems): its goal
# reached with no fall landing in a douse column (one never covers the only
# landing), and a fall through one fits its off window (the fall and a step
# out of the column). A level with roads and the dark twist keeps its roads'
# lights apart (light_problems: no lantern of one road lights the other's
# way). The boss and secret levels (x-4, x-S) stay strips (STRIP_ONLY:
# their rooms and doors are cut for 15 rows).
MAX_DROP = 5
CATCH_ROWS = 10
CATCH_CLEAR = 3
VIEW_W, VIEW_H = 844, 390
FEET_LINE = 193          # world.gd feet_line(): his feet's view y, standing
BELOW_PX = 160           # world.gd BELOW: the stone the camera shows under a level
# The HUD's top corners in view px, with the phone's landscape safe-area
# inset (47) taken on both sides: the left block (the badge, life, the
# resource, the embers: hud.gd layout) and the right (the sigils, pause).
HUD_LEFT = (0, 0, 237, 58)
HUD_RIGHT = (672, 0, 844, 44)
GIVE_WAY = set('%AG}')


def goal_rects(rows):
    """[(glyph, x, y, (x0, y0, x1, y1) px)]: each goal as drawn: a sigil its
    cell, the bell its beam and bell over its floor (world.gd add_bell), a
    silver bell its smaller one."""
    out = []
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            fx, fy = x * 32 + 16, (y + 1) * 32
            if ch in '123':
                out.append((ch, x, y, (x * 32, y * 32, x * 32 + 32, y * 32 + 32)))
            elif ch == 'E':
                out.append((ch, x, y, (fx - 32, fy - 105, fx + 32, fy)))
            elif ch == 'S':
                out.append((ch, x, y, (fx - 16, fy - 70, fx + 16, fy)))
    return out


def hud_problems(rows):
    """Each goal under the HUD's top corners where the camera stops: with
    him at the goal (his feet on its floor), the camera holding his feet on
    FEET_LINE but stopped at the level's top (and its bottom), and its x on
    him (70 px ahead either way) but stopped at the level's sides."""
    w, h = max(len(r) for r in rows) * 32, len(rows) * 32
    out = []
    for ch, x, y, (x0, y0, x1, y1) in goal_rects(rows):
        top = min(max(0, y1 - FEET_LINE), max(0, h + BELOW_PX - VIEW_H))
        for look in (-70, 70):
            cx = (w - VIEW_W) / 2.0 if w <= VIEW_W else min(max((x0 + x1) / 2.0 - VIEW_W / 2.0 + look, 0), w - VIEW_W)
            vr = (x0 - cx, y0 - top, x1 - cx, y1 - top)
            for name, (a0, b0, a1, b1) in (('left', HUD_LEFT), ('right', HUD_RIGHT)):
                if vr[0] < a1 and vr[2] > a0 and vr[1] < b1 and vr[3] > b0:
                    out.append("the %s at %d,%d is under the HUD's top %s corner where the camera stops" % (
                        {'E': 'bell', 'S': 'silver bell'}.get(ch, 'sigil ' + ch), x, y, name))
                    break
            else:
                continue
            break
    return out


def descent_problems(rows, wm=None):
    """A tall level's descent rules (see above), as strings."""
    wm = wm or WalkMap(rows)
    start, goal = wm.start(), wm.goal()
    if start is None or goal is None:
        return ['no start on a floor, or no goal (bell, boss or silver bell)']
    out = []
    if not any(wm.touches(s) for s in wm.reach(MAX_DROP)):
        out.append('the %s at %d,%d needs a drop of more than %d rows' % ('bell' if 'E' in wm.marks else 'goal', goal[1], goal[2], MAX_DROP))
    edges = wm.reach()
    exits = wm.exits()
    ends = [s for s in edges if wm.touches(s, exits)]
    if not ends:
        return out + ['the walk map finds no way from the start to the goal']
    back = {}
    for s, ts in edges.items():
        for t, _d in ts:
            back.setdefault(t, []).append(s)
    seen = set(ends)
    todo = list(ends)
    while todo:
        t = todo.pop()
        for s in back.get(t, ()):
            if s not in seen:
                seen.add(s)
                todo.append(s)
    stuck = sorted((s[1], s[2]) for s in edges if s not in seen and s[0] == 'S')
    if stuck:
        out.append('%d landings lead nowhere (no way out from them), e.g. %s' % (len(stuck), stuck[:6]))
    return out


def _landing(wm, x, y):
    """The row a fall from just under (x, y) ends on (a floor, or a vine
    caught), None for no fall or a snuff."""
    yy = y + 1
    while yy < wm.h:
        if wm.solid(x, yy) or wm.hazard(x, yy):
            return None
        if wm.climb(x, yy) or wm.support(x, yy + 1):
            return yy
        yy += 1
    return None


def _catch_rows(wm, x, ly):
    """[(y0, y1)]: the rows a catch at (x, ly) can set him down in: ly's, a
    row either side; on a floor that gives way itself (a crumble on a
    crumble, a lily over a pool), the next landing's too, and so on; one
    that ends in water or a hazard, its rows (both of a pool's: a Brinejaw
    lies in them)."""
    out = [(ly - 1, ly + 1)]
    while 0 <= ly + 1 < wm.h and wm.t[ly + 1][x] in GIVE_WAY:
        nxt = _landing(wm, x, ly + 1)
        if nxt is not None:
            ly = nxt
            out.append((ly - 1, ly + 1))
            continue
        yy = ly + 2
        while yy < wm.h and not wm.solid(x, yy) and not wm.hazard(x, yy):
            yy += 1
        if yy < wm.h and wm.hazard(x, yy):
            out.append((yy - 1, yy + 1))
        break
    return out


def catch_problems(rows, wm=None):
    """A tall level's catch rules (see above), as strings."""
    wm = wm or WalkMap(rows)
    mons = game()['monsters']
    out = []
    seen = set()
    for y, r in enumerate(wm.t):
        for x, ch in enumerate(r):
            # A floor he stands on that gives way, or the foot of a rotten run.
            if ch not in GIVE_WAY or (ch == '}' and wm.climb(x, y + 1)) or (ch != '}' and not wm.body(x, y - 1)):
                continue
            ly = _landing(wm, x, y)
            if ly is None:
                continue
            if ly - y > CATCH_ROWS:
                out.append('a fall through the %r at %d,%d lands %d rows down (a catch floor within %d)' % (ch, x, y, ly - y, CATCH_ROWS))
            # A landing that gives way itself drops him on: the next catch
            # (or the water it ends in) is where he lands too.
            near = sorted({(mx, my) for y0, y1 in _catch_rows(wm, x, ly) for my in range(y0, y1 + 1)
                           for mx in range(x - CATCH_CLEAR, x + CATCH_CLEAR + 1)
                           if 0 <= my < wm.h and 0 <= mx < wm.w and wm.g[my][mx] in mons})
            for c in near:
                if c not in seen:
                    seen.add(c)
                    out.append('a monster at %d,%d waits where a fall through the %r at %d,%d lands' % (c[0], c[1], ch, x, y))
    return out


# The level's own descent keys (see above), and the lights a lit landing
# counts: glyph -> (radius px, the light's height over the cell's floor; a
# sconce's flame hangs 7 px under its cell's top: world.gd).
DESCENT_KEYS = ('max_drop', 'landing', 'lit_drops')
LIGHTS = {'L': (140, 33), 'K': (150, 30), 'C': (90, 30), 'c': (110, 25)}
STRIP_ONLY = re.compile(r'^\d-[4S]$')
ONE_WAY_GLYPHS = set('=%_A')
STOREY_ROWS = 6       # a belt_flip's belts in a taller level: one storey (within these rows)


def descent_limits(header):
    """(max_drop, landing, lit_drops, problems): a header's own descent keys
    read (None where it has none) and what doesn't read, as strings."""
    hd = dict(header)
    out = []
    md = ld = lit = None
    if str(hd.get('max_drop', '')).strip():
        v = str(hd['max_drop']).strip()
        if v.isdigit() and 1 <= int(v) <= MAX_DROP:
            md = int(v)
        else:
            out.append('max_drop %r (a number of rows, 1-%d)' % (v, MAX_DROP))
    if str(hd.get('landing', '')).strip():
        ab = str(hd['landing']).strip().split('/')
        if len(ab) == 2 and ab[0].strip().isdigit() and ab[1].strip().isdigit():
            ld = (int(ab[0]), int(ab[1]))
        else:
            out.append('landing %r (columns/rows: 6/2)' % hd['landing'])
    if str(hd.get('lit_drops', '')).strip():
        v = str(hd['lit_drops']).strip()
        if v.isdigit() and 1 <= int(v) <= MAX_DROP:
            lit = int(v)
        else:
            out.append('lit_drops %r (a number of rows, 1-%d)' % (v, MAX_DROP))
    return md, ld, lit, out


LIGHT_TOUCH = 2       # a lantern, an altar or a candle he passes this near (WalkMap.near) is lit as he goes


def lit_posts_of(header):
    """([(x, y)], problems): a header's lit posts (`lit_posts: x,y; x,y`:
    lantern posts lit from the start that never burn down, level_features.gd;
    6-2's landing lights in the dark), and what doesn't read, as strings."""
    out, bad = [], []
    for part in str(dict(header).get('lit_posts', '')).split(';'):
        part = part.strip()
        if not part:
            continue
        xy = part.split(',')
        if len(xy) == 2 and xy[0].strip().isdigit() and xy[1].strip().isdigit():
            out.append((int(xy[0]), int(xy[1])))
        else:
            bad.append('lit_posts %r (x,y; x,y)' % part)
    return out, bad


@functools.lru_cache(maxsize=None)
def dead_sconce_themes():
    """{theme}: the themes whose `c` gives no light (themes/*.gd
    "sconce_light": false: W6's dead sconces, world.gd)."""
    out = set()
    d = os.path.join(GAME, 'themes')
    for f in sorted(os.listdir(d)):
        if not f.endswith('.gd'):
            continue
        cur = None
        for line in open(os.path.join(d, f)):
            m = re.match(r'^\t"(\w+)": \{', line)
            if m:
                cur = m.group(1)
            if cur and '"sconce_light": false' in line:
                out.add(cur)
    return out


def lit_cells(wm, steady=(), sconces=True):
    """{(x, y): i}: the cells where his middle, standing in them, is in a
    light's reach (LIGHTS) once it burns, and the route index from which the
    first light on it burns: a sconce (in a theme whose sconces give light)
    and a lit post (steady: a lit_posts: cell) from the start (-1); a
    lantern, an altar or a Vigil candle (none of them lit till he touches it)
    once the route has passed it (WalkMap.proj, when the route comes within
    LIGHT_TOUCH of it: one it never nears is never lit)."""
    path = wm.route() or []
    srcs = []
    for y, r in enumerate(wm.g):
        for x, ch in enumerate(r):
            if ch in LIGHTS:
                rad, up = LIGHTS[ch]
                cy = y * 32 + 7 if ch == 'c' else (y + 1) * 32 - up
                if ch == 'c':
                    if not sconces:
                        continue
                    i = -1
                elif ch == 'L' and (x, y) in steady:
                    i = -1
                elif path and WalkMap.near(path, (x, y)) <= LIGHT_TOUCH:
                    i = wm.proj((x, y))
                else:
                    continue
                srcs.append((x * 32 + 16, cy, rad, i))
    out = {}
    for y in range(wm.h):
        for x in range(wm.w):
            px, py = x * 32 + 16, (y + 1) * 32 - 22
            on = [i for sx, sy, rad, i in srcs if (px - sx) ** 2 + (py - sy) ** 2 <= rad * rad]
            if on:
                out[(x, y)] = min(on)
    return out


def limit_allow(wm, landing=None, lit_drops=None, steady=(), sconces=True):
    """allow(from, to, drop) for WalkMap.reach: a level's landing and
    lit_drops rules (descent_limits); None with neither. A lit landing is lit
    before he gets there: by a sconce or a lit post, or by a light the route
    passed by the state he falls from (lit_cells)."""
    if landing is None and lit_drops is None:
        return None
    lit = lit_cells(wm, set(steady), sconces) if lit_drops is not None else {}
    at = {}

    def allow(s, t, drop):
        if drop <= 0:
            return True
        if landing is not None and abs(t[1] - s[1]) > landing[0] and drop > landing[1]:
            return False
        if lit_drops is not None and t[0] == 'S' and (t[1], t[2] + 1) not in wm.band:
            if s not in at:
                at[s] = wm.proj((s[1], s[2]))
            return drop <= lit_drops and (t[1], t[2]) in lit and lit[(t[1], t[2])] <= at[s]
        return True
    return allow


def own_descent_problems(rows, header, wm):
    """A level's own descent keys (descent_limits) kept: its goal reached by
    falls within them; and a taller level whose route drops through a
    one-way ledge says drops: (the bots drop through only then)."""
    md, ld, lit, out = descent_limits(header)
    posts, bad = lit_posts_of(header)
    out = out + bad + ['lit_posts %d,%d is no lantern post' % c for c in posts
                       if not (0 <= c[1] < wm.h and 0 <= c[0] < wm.w and wm.g[c[1]][c[0]] == 'L')]
    sconces = str(dict(header).get('theme', '')).strip() not in dead_sconce_themes()
    if out or (md, ld, lit) == (None, None, None):
        pass
    elif not any(wm.touches(s) for s in wm.reach(md, limit_allow(wm, ld, lit, posts, sconces))):
        keys = ', '.join('%s %s' % (k, dict(header)[k]) for k in DESCENT_KEYS if str(dict(header).get(k, '')).strip())
        out.append('its goal needs a fall past its own descent rules (%s)' % keys)
    hd = dict(header)
    drops = str(hd.get('drops', '')).strip().lower() not in ('', '0', 'no', 'false')
    path = wm.route() or []
    for a, b in zip(path, path[1:]):
        if a[0] == 'S' and b[1] == a[1] and b[2] > a[2] and wm.g[a[2] + 1][a[1]] in ONE_WAY_GLYPHS and not drops:
            out.append('its route drops through the one-way ledge at %d,%d: write drops: yes (the bots drop through only then)' % (a[1], a[2] + 1))
            break
    return out


def _fall_secs(rows_down):
    """The seconds a fall of rows_down rows takes (player.gd GRAVITY_DOWN to
    MAX_FALL)."""
    g, top = float(_gd_const('player.gd', 'GRAVITY_DOWN')), float(_gd_const('player.gd', 'MAX_FALL'))
    d = rows_down * 32.0
    t1 = top / g
    d1 = 0.5 * g * t1 * t1
    return math.sqrt(2.0 * d / g) if d <= d1 else t1 + (d - d1) / top


def waxfall_columns(wm):
    """[(x, y0, y1)]: each waxfall's douse column, its head's row down to the
    first solid row under it (level_features.gd)."""
    out = []
    for y, r in enumerate(wm.g):
        for x, ch in enumerate(r):
            if ch == '!':
                b = y + 1
                while b < wm.h and _tile(wm.g, x, b, 'solid') != 'solid':
                    b += 1
                out.append((x, y, b - 1))
    return out


def waxfall_problems(wm):
    """A taller level's waxfalls kept off its drops (see above), as strings."""
    cols = waxfall_columns(wm)
    if not cols:
        return []

    def under(x, y):
        return any(cx == x and y0 <= y <= y1 for cx, y0, y1 in cols)
    out = []
    if not any(wm.touches(s) for s in wm.reach(None, lambda s, t, drop: drop <= 0 or not under(t[1], t[2]))):
        out.append("a waxfall's column covers the only landing of a drop on the way to the goal")
    off = float(_gd_const('level_features.gd', 'FALL_OFF'))
    step = 32.0 / float(_gd_const('player.gd', 'RUN_SPEED'))
    path = wm.route() or []
    for a, b in zip(path, path[1:]):
        drop = b[2] - a[2]
        if drop > 0 and any(cx == b[1] and y0 <= b[2] and y1 >= a[2] for cx, y0, y1 in cols) and _fall_secs(drop) + step > off:
            out.append('the drop at %d,%d through a waxfall takes %.2f s and a step (its off window %.1f s)' % (b[1], a[2], _fall_secs(drop), off))
    return out


def light_problems(wm, header):
    """A dark level's roads kept apart (see above): no lantern on one road
    alone lights a cell of another's way that's its alone."""
    hd = dict(header)
    if str(hd.get('twist', '')).strip().lower() != 'dark' or len(wm.roads()) < 2:
        return []
    rad, up = LIGHTS['L']
    out = []
    roads = wm.roads()
    for y, r in enumerate(wm.g):
        for x, ch in enumerate(r):
            if ch != 'L':
                continue
            mine = wm.road_of((x, y))
            if len(mine) != 1:
                continue
            lx, ly = x * 32 + 16, (y + 1) * 32 - up
            for j, (name, path) in enumerate(roads):
                if j in mine:
                    continue
                for _k, sx, sy in path:
                    if mine[0] in wm.road_of((sx, sy)):
                        continue
                    if (sx * 32 + 16 - lx) ** 2 + ((sy + 1) * 32 - 22 - ly) ** 2 <= rad * rad:
                        out.append("the lantern at %d,%d on the %s road lights the %s road's way at %d,%d" % (x, y, roads[mine[0]][0], name, sx, sy))
                        break
    return out


LAMP_NEAR = 64        # px past a lantern's reach: a lily run this near one is by it (lamp_problems)


def lamp_problems(rows, header=()):
    """A lamplit level's lilies kept in their lanterns' reach (see above):
    each run of soft wax by a lantern (a cell within twists.gd LAMP_R +
    LAMP_NEAR px of its flame) is held whole, every cell of it within LAMP_R
    of some lantern's flame (twists.gd _find_lamp_cells: the cell's middle)."""
    if str(dict(header).get('twist', '')).strip() != 'lamplit':
        return []
    reach = float(_gd_const('twists.gd', 'LAMP_R'))
    up = float(_gd_const('level_features.gd', 'LANTERN_FLAME'))
    flames = [(x * 32 + 16, (y + 1) * 32 - up) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == 'L']

    def far(c, f):
        return math.hypot(c[0] * 32 + 16 - f[0], c[1] * 32 + 16 - f[1])
    out = []
    for y, r in enumerate(rows):
        x = 0
        while x < len(r):
            if r[x] != '%':
                x += 1
                continue
            x1 = x
            while x1 + 1 < len(r) and r[x1 + 1] == '%':
                x1 += 1
            cells = [(cx, y) for cx in range(x, x1 + 1)]
            if any(far(c, f) <= reach + LAMP_NEAR for c in cells for f in flames):
                dark = [c[0] for c in cells if not any(far(c, f) <= reach for f in flames)]
                if dark:
                    out.append("the lily run at %d-%d,%d is by a lantern, but its cells at %s are out of every lantern's reach" % (x, x1, y, dark))
            x = x1 + 1
    return out


def shape_problems(name, rows, header=()):
    """What breaks a level's shape rules (see above), as strings."""
    out = []
    if not H_MIN <= len(rows) <= H_MAX:
        out.append('%d rows (%d-%d)' % (len(rows), H_MIN, H_MAX))
    if STRIP_ONLY.match(name) and len(rows) != H:
        out.append('%d rows: a boss or secret level stays a strip (%d)' % (len(rows), H))
    out += hud_problems(rows) + lamp_problems(rows, header)
    hd = dict(header)
    if len(rows) > H:
        wm = WalkMap(rows, hd.get('roads', ''))
        out += descent_problems(rows, wm) + catch_problems(rows, wm) + own_descent_problems(rows, header, wm)
        out += waxfall_problems(wm) + light_problems(wm, header)
        out += ['the %s road finds no way to the goal by its cells' % n for n, path in wm.roads() if n and not path]
    else:
        out += descent_limits(header)[3]
    f = str(hd.get('facing', 'right')).strip()
    if f not in ('left', 'right'):
        out.append("facing %r (left or right)" % f)
    elif f == 'left':
        sx = [x for r in rows for x, ch in enumerate(r) if ch == 'P']
        ex = [x for r in rows for x, ch in enumerate(r) if ch in 'EX']
        if sx and ex and sx[0] < max(ex):
            out.append('facing left, but it starts left of its bell (%d, %d)' % (sx[0], max(ex)))
    return out


def check_shape(name, rows, header=()):
    """Asserts a level keeps its shape rules (shape_problems)."""
    probs = shape_problems(name, rows, header)
    assert not probs, '%s: %s' % (name, '; '.join(probs))


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
# Worlds 1-2 stay gentle on Dusk (GENTLE_WORLDS, the author's ruling): their
# X-1 and X-2 keep the on-ramp's fodder (1-2's Restless and 2-2's dark make
# their fodder the lesson), so there only the X-3 is held: its fodder_max
# under its X-1's and at most GENTLE_X3 (2-3's nests count as moths).
ALTAR_NEAR = 8
FODDER_CAPS = (0.85, 0.75, 0.65)
GENTLE_WORLDS = (1, 2)
GENTLE_X3 = 0.85
SCREEN = 26
SCREEN_ROWS = 12      # a taller level's screen (the view's rows; a strip's is its height)
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
        assert 0 <= y < len(sec) and 0 <= x < len(sec[0]), \
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
    return [(n, x0 + dx, y0 + dy) for sec, x0, y0 in getattr(rows, 'parts', ()) for n, dx, dy in getattr(sec, 'stamps', ())]


# ---------------------------------------------------------------- range headers

class Span(object):
    """A run of one section's columns in a level (span()), written into a
    range header as 'x0-x1' (absolute, inclusive) or, paired with a value,
    'x0-x1@value'."""

    def __init__(self, section, dx0=0, dx1=None, n=0):
        self.section, self.dx0, self.dx1, self.n = section, dx0, dx1, n

    def cols(self, rows):
        dx1 = len(self.section[0]) - 1 if self.dx1 is None else self.dx1
        a, b = x_of(rows, self.section, self.dx0, self.n), x_of(rows, self.section, dx1, self.n)
        return min(a, b), max(a, b)


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
    name]]: the row as the section's drawn, y_of) or (x, y[, ...]) absolute,
    omens 'Swift+Warded' or a list ('':
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
            x, y, rest = _place(rows, c[0]), c[1], list(c[2:])
        else:
            x, y, rest = x_of(rows, c[0], c[1]), y_of(rows, c[0], c[2]), list(c[3:])
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


def threat_of(rows, anoint=(), twist='', world=0, pack_leaders=None, roads=''):
    """Threat cost per 100 tiles (EnemyKinds.COST, the Dread aside): each
    placed monster at the bodies it comes to in play (in_play: its pack's
    extras at its kind's cost), a forced Anointed (a cell in anoint) itself
    at TIER_COST's x2.5 (tests/level_rules.gd threat_of counts the same).
    A strip's tiles are its width. A taller level's are its route's length
    on foot (WalkMap.run_lengths: a loop's two storeys, a switchback's
    tiers and a tower's climb are all walked), and with roads (its 'roads'
    header: two ways through) each road is counted on its own, its monsters
    (WalkMap.road_of: the nearest road's; on the stretches they share,
    every road's) over its length, and the heavier road is the level's: a
    run takes one road, so the two are never added up."""
    g = game()
    forced = set(anoint)
    bodies = []
    for x, y, k, n in in_play(rows, anoint, twist, world, pack_leaders):
        bodies.append(((x, y), g['cost'][k] * ((g['tier_cost']['anointed'] if (x, y) in forced else 1.0) + n - 1.0)))
    if len(rows) <= H:
        return sum(c for _cell, c in bodies) * 100.0 / max(len(r) for r in rows)
    wm = WalkMap(rows, roads)
    best = None
    for i, (_name, path) in enumerate(wm.roads()):
        tiles = wm.run_lengths(path)[-1] if path else 0
        if tiles <= 0:
            continue
        cost = sum(c for cell, c in bodies if i in wm.road_of(cell))
        best = max(best or 0.0, cost * 100.0 / tiles)
    if best is None:
        return sum(c for _cell, c in bodies) * 100.0 / max(len(r) for r in rows)
    return best


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


def check_threat(name, rows, target, anoint=(), twist='', world=0, pack_leaders=None, roads=''):
    """Asserts a level's threat (threat_of) within THREAT_SLACK of its
    declared one, and returns it."""
    got = threat_of(rows, anoint, twist, world, pack_leaders, roads)
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


def clockwork_problems(rows, header=()):
    """What a level's clockwork headers can't tell apart, as strings: they're
    keyed by column (cog_phase by a hub's, weight_phase by a weight's or a
    swing's first: level_data.gd), so no two cog hubs share a column, nor two
    weights or swings; and in a taller level a belt_flip span reverses the
    belts of one storey only (features/clockwork.gd reverse_belts takes
    every belt in its columns: within STOREY_ROWS rows of each other), so a
    storey stacked over another (4-2's loop) never flips its own with it."""
    out = []
    hubs = {}
    keys = {}
    for y, r in enumerate(rows):
        x = 0
        while x < len(r):
            ch = r[x]
            if ch in 'OQ':
                hubs.setdefault(x, []).append(y)
            elif ch == 'Y':
                keys.setdefault(x, []).append(y)
            elif ch == 'T':
                keys.setdefault(x, []).append(y)
                while x + 1 < len(r) and r[x + 1] == 'T':
                    x += 1
            x += 1
    out += ['two cog hubs in column %d (rows %s): cog_phase is keyed by column' % (x, ys) for x, ys in sorted(hubs.items()) if len(ys) > 1]
    out += ['two weights or swings in column %d (rows %s): weight_phase is keyed by column' % (x, ys) for x, ys in sorted(keys.items()) if len(ys) > 1]
    if len(rows) > H:
        for x0, x1 in ranges_of(dict(header).get('belt_flip', '')):
            ys = sorted({y for y, r in enumerate(rows) for x in range(x0, min(x1, len(r) - 1) + 1) if r[x] in '<>'})
            if ys and ys[-1] - ys[0] > STOREY_ROWS:
                out.append('belt_flip %d-%d reverses belts on rows %d and %d (two storeys)' % (x0, x1, ys[0], ys[-1]))
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
    probs = clockwork_problems(rows, header)
    assert not probs, '%s: %s' % (name, '; '.join(probs))
    check_rooms(name, rows, hd.get('room', ''), facing_of(header))
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
        check_threat(name, rows, float(hd['threat']), anoint, tw.lower(), world, roster.get('pack_leaders'), hd.get('roads', ''))
    parts = [sec for sec, _x, _y in parts_in_route_order(rows, facing_of(header))]
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


def checkpoint_gaps(rows, roads=''):
    """(marks, gaps): a level's checkpoints (start, altars, bell or boss) in
    the route's order and how far apart they are on it: a strip's by x
    (either way), a taller level's along the walk map's route (each
    checkpoint at its nearest index, WalkMap.proj; the columns walked and
    rows climbed between: run_lengths). marks: their x in a strip, their
    distance along the route in a taller level. With roads (two ways
    through), along each road its own checkpoints (WalkMap.road_of) and the
    road with the widest gap's: a run takes one road, so the slower road is
    held to the gap too (road_gaps has them all)."""
    worst = None
    for _name, marks, gaps in road_gaps(rows, roads):
        if worst is None or max(gaps or [0]) > max(worst[1] or [0]):
            worst = (marks, gaps)
    return worst or ([], [10 ** 6])


def road_gaps(rows, roads=''):
    """[(road, marks, gaps)]: checkpoint_gaps along each road ('' the one
    road; a strip's by x)."""
    cells = [(x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch in 'PKEX']
    if len(rows) <= H:
        marks = sorted(x for x, _y in cells)
        return [('', marks, [b - a for a, b in zip(marks, marks[1:])])]
    wm = WalkMap(rows, roads)
    out = []
    for i, (name, path) in enumerate(wm.roads()):
        if not path:
            out.append((name, [], [10 ** 6]))
            continue
        run = wm.run_lengths(path)
        mine = [c for c in cells if i in wm.road_of(c)]
        marks = sorted(run[min(range(len(path)), key=lambda j: (abs(path[j][1] - c[0]) + 2 * abs(path[j][2] - c[1]), j))] for c in mine)
        out.append((name, marks, [b - a for a, b in zip(marks, marks[1:])]))
    return out


def checkpoint_problems(rows, header, max_gap, altar_band=ALTARS):
    """A regular level's checkpoints (start, altars, bell): at most max_gap
    apart along its route (checkpoint_gaps: x in a strip; with roads, along
    each road), altar_band altars (ALTARS; World 1-2's own, w1.py and
    w2.py), and an altar at most DOOR_ALTAR tiles before every sealed room's
    door (the one the route comes in by: room_entry; rooms_of), in a taller
    level on the deck he comes in on (in that door's rows: door_rows)."""
    out = []
    for name, marks, gaps in road_gaps(rows, header.get('roads', '')):
        worst = max(gaps or [0])
        if worst > max_gap:
            out.append('checkpoints %d tiles apart (at most %d)%s: %s' % (worst, max_gap, ' on the %s road' % name if name else '', marks))
    altars = sorted(x for r in rows for x, ch in enumerate(r) if ch == 'K')
    cells = [(x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == 'K']
    if not altar_band[0] <= len(altars) <= altar_band[1]:
        out.append('%d altars (%d-%d)' % (len(altars), altar_band[0], altar_band[1]))
    for kind, x0, x1, y0, y1 in _room_boxes(rows, header.get('room', '')):
        side, row = room_entry_at(rows, x0, x1, y0, y1, facing_of(header))
        door = x0 if side < 0 else x1
        band = deck_door_rows(rows, door, y0, y1, row)
        ok = [(ax, ay) for ax, ay in cells if 0 <= (door - ax) * -side <= DOOR_ALTAR]
        if not ok:
            out.append('no altar within %d tiles of the %s door at %d (altars %s)' % (DOOR_ALTAR, kind, door, altars))
        elif band is not None and not any(band[0] - 1 <= ay <= band[1] for _ax, ay in ok):
            out.append('no altar on the deck of the %s door at %d (its doorway rows %d-%d; altars %s)' % (kind, door, band[0], band[1], ok))
    return out


def _room_boxes(rows, value):
    """[(kind, x0, x1, y0, y1)] of a written room: header (its rows, else
    the level's)."""
    out = []
    for part in str(value).split(';'):
        bits = part.split()
        if len(bits) < 2 or bits[0] not in ROOM_KINDS:
            continue
        ab = bits[1].split('-')
        if len(ab) != 2 or not ab[0].isdigit() or not ab[1].isdigit():
            continue
        y0, y1 = 0, len(rows) - 1
        if 'rows' in bits:
            y0, y1 = (int(v) for v in bits[bits.index('rows') + 1].split('-'))
        out.append((bits[0], int(ab[0]), int(ab[1]), y0, y1))
    return out


FEET_UP, FEET_DOWN = 5, 6   # rows the camera shows over and under his feet's row, standing (FEET_LINE of VIEW_H)


def screen_rows(rows, x0=None, width=SCREEN):
    """[(y0, y1)]: the rows a screen spans (inclusive): a strip's one screen
    is its whole height (its camera shows it all as it goes); a taller
    level's are the views over each row he can stand on (WalkMap.stand) in
    the columns x0..x0+width-1 (every column with no x0): FEET_UP rows over
    it and FEET_DOWN under (SCREEN_ROWS in all; at the level's top the
    camera stops, so the first SCREEN_ROWS rows), so two roads or decks a
    screen apart are never counted together where he can't see both."""
    h = rows.h if isinstance(rows, WalkMap) else len(rows)
    if h <= H:
        return [(0, h - 1)]
    wm = rows if isinstance(rows, WalkMap) else WalkMap(rows)
    xs = range(wm.w) if x0 is None else range(max(x0, 0), min(x0 + width, wm.w))
    feet = sorted({y for x in xs for y in range(h) if wm.stand(x, y)})
    out = []
    for f in feet:
        y0 = max(0, f - FEET_UP)
        y1 = min(h - 1, (y0 + SCREEN_ROWS - 1) if f - FEET_UP < 0 else f + FEET_DOWN)
        if (y0, y1) not in out:
            out.append((y0, y1))
    return out


def mixed_screens(rows):
    """How many screens (SCREEN tiles wide, none overlapping: the most such
    a level holds; screen_rows tall) have MIXED_KINDS kinds or more of
    monster in them."""
    mons = game()['monsters']
    at = {}
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in mons:
                at.setdefault(x, []).append((y, mons[ch]))
    width = max(len(r) for r in rows)
    wm = WalkMap(rows) if len(rows) > H else rows
    n = 0
    x0 = 0
    while x0 < width:
        best = 0
        for y0, y1 in screen_rows(wm, x0):
            kinds = set()
            for x in range(x0, x0 + SCREEN):
                kinds |= {k for y, k in at.get(x, ()) if y0 <= y <= y1}
            best = max(best, len(kinds))
        if best >= MIXED_KINDS:
            n += 1
            x0 += SCREEN
        else:
            x0 += 1
    return n


def crowded_screens(rows, anoint=(), twist='', world=0, pack_leaders=None):
    """[(x0, n)]: each screen (SCREEN tiles from x0, screen_rows tall) with
    more than AWAKE_MAX bodies in play in it (in_play: packs at their size)."""
    at = {}
    for x, y, _k, n in in_play(rows, anoint, twist, world, pack_leaders):
        at.setdefault(x, []).append((y, n))
    width = max(len(r) for r in rows)
    wm = WalkMap(rows) if len(rows) > H else rows
    out = []
    for x0 in range(0, max(width - SCREEN, 0) + 1):
        for y0, y1 in screen_rows(wm, x0):
            n = sum(m for x in range(x0, x0 + SCREEN) for y, m in at.get(x, ()) if y0 <= y <= y1)
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
    ceilings fall within FODDER_CAPS (in GENTLE_WORLDS only the X-3's, under
    the X-1's and GENTLE_X3), the X-3 mixes MIXED_SCREENS screens and
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
        rows = level_rows(e)
        hd = dict(header_of(e, rows))
        facing = facing_of(hd)
        out += ['%s: %s' % (e['id'], p) for p in checkpoint_problems(rows, hd, max_gap, altar_band)]
        seq = roles_of([b for b, _x, _y in parts_in_route_order(rows, facing)])
        if 'roles' in e and ' '.join(e['roles'].split()) != seq:
            out.append('%s declares roles %s but its sections hold %s' % (e['id'], e['roles'], seq))
        if level_no(e['id']) == 1:
            stamps = level_stamps(rows)
            half = first_half(rows, [(x, y) for _n, x, y in stamps], facing)
            early = [(n, x) for n, x, y in stamps if (x, y) in half]
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
    before = []
    for e in regular:
        n = level_no(e['id'])
        fm = float(info[e['id']]['roster']['fodder_max'])
        if entry_world(e) in GENTLE_WORLDS:
            if n == 3:
                if fm > GENTLE_X3 + 1e-9:
                    out.append('%s: fodder_max %s (a gentle world\'s X-3 at most %s)' % (e['id'], _num(fm), _num(GENTLE_X3)))
                out += ['%s: fodder_max %s, not under %s\'s %s (a gentle world\'s X-3 under its X-1)'
                        % (e['id'], _num(fm), b[0], _num(b[1])) for b in before if level_no(b[0]) == 1 and fm >= b[1] - 1e-9]
            before.append((e['id'], fm))
        else:
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
    shapes_check()


def shapes_check():
    """The shape tools' own proof (self_check runs it): place, crop, stack,
    seam and the ceiling; x_of and y_of through a placed, cropped or mirrored
    copy; mirror_rows and mirror_phases; the walk map's route and the shape
    rules, each passing what it should and catching what it shouldn't."""
    flat = block('\n'.join(['.' * 12] * 13 + ['#' * 12] * 2))
    pit = swap(flat, {(5, 13): '.', (5, 14): '.', (6, 13): ':', (6, 14): ':'})
    # place: rock above, rock under rock, the pit and the pool carried down.
    pl = place(stamp(pit, 'hound_and_mounds', 2, 12), 4, 24)
    assert len(pl) == 24 and pl[0] == '#' * 12 and pl[23][5] == '.' and pl[23][6] == ':' and pl[23][0] == '#', 'place pads'
    assert pl.dy == 4 and pl.stamps == [('hound_and_mounds', 2, 16)] and _fails(place, flat, 10, 24) and _fails(place, flat, 0, 37), 'place'
    assert list(place(flat, 0, 15, '.')) == list(flat) and seam(4, 24)[17] == '##' and seam() is T_OPEN and floor_row(9) == 22, 'seam, floor_row'
    assert _fails(join, flat, pl), 'join refuses sections of two heights'
    # crop and stack: storeys of 12 rows; a cut row with a glyph fails.
    up = crop(flat, 3)
    assert len(up) == 12 and up.dy == -3 and _fails(crop, swap(flat, {(2, 1): 'o'}), 3), 'crop'
    st2 = stack(join(up, crop(pit, 3)), join(crop(pit, 3), up))
    assert len(st2) == 24 and len(st2.parts) == 4 and st2.parts[2][1:] == (0, 12) and _fails(stack, join(up), join(up, up)), 'stack'
    lvl = join(place(flat, 9, 24), st2)
    assert x_of(lvl, pit, 2, 1) == 14 and y_of(lvl, pit, 13, 1) == 22 and y_of(lvl, flat, 13) == 22 and y_of(lvl, pit, 13) == 10, 'x_of, y_of'
    p4, p9 = place(flat, 4, 24), place(flat, 9, 24)
    assert y_of(join(p9, p4), p4, 13) == 13 and y_of(join(p9, p4), flat, 13, 1) == 17 and x_of(mirror_rows(join(p9, p4)), flat, 0, 1) == 11, \
        'a placed copy names itself; a mirror keeps the uses\' order'
    assert ceiling(lvl)[0] == '#' * 36 and len(level_rows({'sections': [(flat, 9), (pit, 0)], 'height': 24})) == 24, 'ceiling, level_rows'
    # mirror_rows: a section knows its source; a level its parts, flipped.
    belt = swap(flat, {(1, 13): '>', (2, 13): '>', (9, 6): 'O', (3, 12): 's'})
    mb = mirror_rows(belt)
    assert mb[13][10] == '<' and mb[6][2] == 'Q' and mb.flip and mb.source is belt and x_of(join(flat, mb), belt, 9) == 14, 'mirror a section'
    ml = mirror_rows(join(flat, belt))
    assert ml.mirrored and x_of(ml, belt, 9) == 2 and x_of(ml, flat, 0) == 23 and _place(ml, 0) == 23 and mirror_rows(ml)[6] == join(flat, belt)[6], \
        'mirror a level'
    assert any('before its right door' in p for p in room_problems(ml, rooms_header(ml, [('duel', belt)]), -1)), 'a mirrored room is met by its right door'
    # mirror_phases: every weight and swing written, half a swing on, at its
    # mirrored column (a swing's first); a cog's 1 - turns at its mirror.
    wt = swap(flat, {(2, 2): 'Y', (8, 2): 'Y', (4, 8): 'T', (5, 8): 'T', (6, 8): 'T'})
    assert phases_of(wt, {8: 0.25}) == {2: 0.0, 8: 0.25, 4: 0.0}, phases_of(wt, {8: 0.25})
    assert mirror_phases(wt, {8: 0.25}, {6: 0.125}) == ({9: 0.5, 3: 0.75, 5: 0.5}, {5: 0.875}), mirror_phases(wt, {8: 0.25}, {6: 0.125})
    # The route: a strip's by x in its facing; a taller level's the walk
    # map's (a sign up on the storey it comes back along comes after).
    assert route_order(flat, [(9, 12), (2, 12), (5, 3)], -1) == [(9, 12), (5, 3), (2, 12)], 'route_order, a strip facing left'
    lo = block('\n'.join(['.' * 20] * 3 + ['.' * 18 + '{.'] * 10 + ['#' * 20] * 2))
    hi = block('\n'.join(['.' * 20] * 13 + ['.' * 6 + '#' * 12 + '{#'] * 2))
    loop = stack(join(crop(swap(hi, {(8, 12): '@', (7, 12): 'E'}), 3)), join(crop(swap(lo, {(2, 12): 'P', (12, 12): '@'}), 3)))
    wm = WalkMap(loop)
    assert wm.route() is not None and route_order(loop, [(8, 9), (12, 21)]) == [(12, 21), (8, 9)], 'route_order, along a loop'
    marks, gaps = checkpoint_gaps(loop)
    assert gaps == [16 + 12 + 10], 'checkpoint_gaps along the route: 16 right, 12 up, 10 back (%s)' % (gaps,)
    assert room_entry(loop, 9, 15, 0, 11) == 1 and room_entry(loop, 9, 15, 12, 23) == -1, 'room_entry from the route'
    assert descent_problems(loop) == [] and catch_problems(loop) == [] and hud_problems(loop) == [], 'a loop keeps the shape rules'
    # Descent: a 6-row drop the only way on; a landing with no way out.
    drop = block('\n'.join(['#' * 24] * 6 + ['.' * 24] * 6 + ['#' * 8 + '.' * 16] + ['.' * 24] * 6 + ['#' * 24] * 2), 21)
    drop = swap(drop, {(2, 11): 'P', (20, 18): 'E'})
    assert any('drop of more than 5' in p for p in descent_problems(drop)), 'a 6-row drop is caught'
    pocket = swap(drop, {(14, y): '#' for y in range(13, 19)})
    pocket = swap(pocket, {(x, 12): '=' for x in range(8, 14)})
    assert any('lead nowhere' in p for p in descent_problems(pocket)), 'a pocket with no way out is caught (%s)' % descent_problems(pocket)
    # Catch: a crumble 12 rows over its floor; a monster where it lands.
    tall = block('\n'.join(['.' * 20] * 4 + ['....%%%%............'] + ['.' * 20] * 13 + ['#' * 20] * 2), 20)
    assert any('lands 13 rows down' in p for p in catch_problems(tall)), catch_problems(tall)
    assert any('waits where' in p for p in catch_problems(swap(tall, {(7, 17): 's'}))), 'a monster at a catch floor is caught'
    assert catch_problems(swap(tall, {(x, 12): '=' for x in range(3, 9)})) == [], 'a catch floor within 10 rows'
    # A catch that gives way itself (a lily over a pool) drops him on: a
    # Brinejaw in the pool's second row under it is where he lands too.
    pond = swap(tall, dict([((x, 12), '%') for x in range(3, 9)] + [((x, y), ':') for x in range(2, 10) for y in (18, 19)]))
    assert catch_problems(pond) == [], 'a lily over a pool catches (%s)' % catch_problems(pond)
    assert any('waits where' in p for p in catch_problems(swap(pond, {(6, 19): 'f'}))), 'a Brinejaw under the lily it lands on is caught'
    # The HUD: a sigil in the top right corner where the camera stops; the
    # bell clear of it 6 tiles in; the height and the facing.
    corner = swap(block('\n'.join(['.' * 40] * 13 + ['#' * 40] * 2)), {(38, 1): '1', (1, 12): 'P', (6, 12): 'E'})
    assert any('top right corner' in p for p in hud_problems(corner)) and hud_problems(swap(corner, {(38, 1): '.'})) == [], 'the HUD rule'
    assert shape_problems('x', ['.'] * 14) and shape_problems('x', corner, [('facing', 'left')]) and shape_problems('x', corner, [('facing', 'up')]), 'shape_problems'
    assert screen_rows(flat) == [(0, 14)] and screen_rows(['.'] * 24) == [], 'screen_rows'
    review_check()


def _grid(w, h):
    """A blank level of w x h air, for the checks below: (rows, put, fill)."""
    g = [['.'] * w for _ in range(h)]

    def put(x, y, s):
        for i, ch in enumerate(s):
            g[y][x + i] = ch

    def fill(x0, x1, y0, y1, ch='#'):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                g[y][x] = ch
    return g, put, fill


def _rows_of(g):
    return [''.join(r) for r in g]


def review_check():
    """The shape rules the shape review asked for, each passing what it
    should and catching what it shouldn't (shapes_check runs it): a taller
    level's threat per tile of its route on foot, and per road; the gaps
    along each road; screens anchored on the rows he stands on; a level's
    own descent keys; drops: where the route drops through a ledge;
    waxfalls off the drops; a dark level's roads lit apart; the clockwork's
    column keys; the boss and secret levels kept strips; a two-deck room's
    door altar on his deck; a carrier at a rotten run's foot; a deck's
    gusts on its rows."""
    c = game()['cost']
    # A loop: right along the bottom (stand 21), up at the far end, back left
    # along the top (stand 10) to the bell over the start: its threat is per
    # tile of the route (about twice its width), not of its width.
    g, put, fill = _grid(40, 24)
    fill(0, 39, 0, 0)
    fill(0, 39, 22, 23)
    fill(0, 31, 11, 12)
    put(2, 21, 'P')
    put(3, 10, 'E')
    put(34, 19, '====')
    put(36, 16, '===')
    put(34, 13, '====')
    put(12, 21, 's')
    put(20, 10, 's')
    loop = _rows_of(g)
    wm = WalkMap(loop)
    run = wm.run_lengths()[-1]
    assert run > 60 and abs(threat_of(loop) - 2 * c['skeleton'] * 100.0 / run) < 1e-9, \
        'a loop\'s threat is per tile of its route on foot (%.2f over %d tiles)' % (threat_of(loop), run)
    # Two roads (split by a wall, rejoining): each road's threat on its own,
    # the heavier the level's; the gaps along each road.
    g, put, fill = _grid(60, 24)
    fill(0, 59, 0, 0)
    fill(0, 59, 22, 23)
    fill(14, 45, 11, 12)                   # the high road's floor (stand 10)
    for x, y in ((10, 19), (12, 16), (10, 13)):
        put(x, y, '===')                   # up to the high road at its start
    for x, y in ((47, 13), (49, 16), (47, 19)):
        put(x, y, '===')                   # down from it at its end
    put(2, 21, 'P')
    put(56, 21, 'E')
    put(5, 21, 'K')
    put(52, 21, 'K')
    put(20, 10, 's')
    put(30, 10, 's')
    put(25, 21, 's')
    two = _rows_of(g)
    roads = 'high 30,10; low 30,21'
    wr = WalkMap(two, roads)
    hi, lo = wr.roads()
    assert hi[1] and lo[1] and wr.road_of((20, 10)) == [0] and wr.road_of((25, 21)) == [1] and set(wr.road_of((2, 21))) == {0, 1}, 'road_of'
    t_hi = 2 * c['skeleton'] * 100.0 / wr.run_lengths(hi[1])[-1]
    t_lo = c['skeleton'] * 100.0 / wr.run_lengths(lo[1])[-1]
    assert abs(threat_of(two, roads=roads) - max(t_hi, t_lo)) < 1e-9 and threat_of(two, roads=roads) < threat_of(two) * 1.01 + 1.0, \
        'two roads: the heavier road\'s threat (%.2f; both counted on one: %.2f)' % (threat_of(two, roads=roads), threat_of(two))
    gaps = road_gaps(two, roads)
    assert [n for n, _m, _g in gaps] == ['high', 'low'] and all(m for _n, m, _g in gaps), 'road_gaps names each road %s' % (gaps,)
    assert any('on the high road' in p for p in checkpoint_problems(two, {'roads': roads}, max(g2 for _n, _m, gg in gaps for g2 in gg) - 1)), \
        'a gap too wide on a road is named by its road'
    assert any('no way to the goal' in p for p in shape_problems('lab-x', two, [('roads', 'high 30,10; nowhere 30,5')])), 'a road that goes nowhere'
    # Screens: the views over the rows he stands on, so two roads 11 rows
    # apart never count together; four Rattles on each is no crowd, eight on
    # one road is.
    crowd = [list(r) for r in two]
    for x in (16, 18, 22, 24, 26, 28, 32):
        crowd[10][x] = 's'
    for x in (16, 18, 22, 24, 26, 28, 32):
        crowd[21][x] = 's'
    crowd = [''.join(r) for r in crowd]
    sr = screen_rows(crowd, 16)
    assert (5, 16) in sr and (16, 23) in sr and not any(a <= 10 and b >= 21 for a, b in sr), 'screen_rows: the roads apart (%s)' % (sr,)
    assert crowded_screens(crowd) and not crowded_screens(two), 'eight a road crowds its screen'
    # A level's own descent keys: a 5-row drop the only way on passes the
    # shape rules but not max_drop 4; a long low leap fails landing 6/2; a
    # dark drop fails lit_drops 3, a lantern by its landing passes it.
    g, put, fill = _grid(40, 24)
    fill(0, 39, 22, 23)
    fill(0, 17, 17, 23)                    # the upper floor (stand 16), a 5-row drop off its end
    put(2, 16, 'P')
    put(30, 21, 'E')
    dr = _rows_of(g)
    assert not [p for p in shape_problems('lab-x', dr) if 'descent' in p or 'drop' in p], 'a 5-row drop keeps the shape rules'
    assert any('own descent rules (max_drop 4)' in p for p in shape_problems('lab-x', dr, [('max_drop', '4')])), 'max_drop 4 catches it'
    assert not [p for p in shape_problems('lab-x', dr, [('max_drop', '5')]) if 'descent' in p], 'max_drop 5 passes it'
    assert any('own descent rules (lit_drops 3)' in p for p in shape_problems('lab-x', dr, [('lit_drops', '3')])), 'lit_drops: a 5-row drop is too far'
    g2 = [list(r) for r in dr]
    for x in range(18, 24):
        g2[19][x] = '='                    # a ledge 2 rows down, then 3 more to the floor
    g2[16][15] = 'L'                       # posts he passes (and lights) before each drop
    g2[18][23] = 'L'
    lit = [''.join(r) for r in g2]
    assert not [p for p in shape_problems('lab-x', lit, [('lit_drops', '3')]) if 'descent' in p], 'lit_drops: lit 3- and 2-row drops pass'
    dark = [r.replace('L', '.') for r in lit]
    assert any('lit_drops 3' in p for p in shape_problems('lab-x', dark, [('lit_drops', '3')])), 'lit_drops: the same in the dark fails'
    # A post at the landing isn't lit till he gets there; a sconce is.
    late = swap(dark, {(19, 18): 'L', (26, 21): 'L'})
    assert any('lit_drops 3' in p for p in shape_problems('lab-x', late, [('lit_drops', '3')])), 'lit_drops: posts at the landings are dark when he lands'
    sconce = swap(dark, {(19, 17): 'c', (25, 20): 'c'})
    assert not [p for p in shape_problems('lab-x', sconce, [('lit_drops', '3')]) if 'descent' in p], 'lit_drops: sconces over the landings pass'
    assert any('lit_drops 3' in p for p in shape_problems('lab-x', sconce, [('lit_drops', '3'), ('theme', 'stillshore')])), \
        "lit_drops: W6's dead sconces light nothing"
    # Lit posts (lit_posts:) burn from the start: the posts at the landings
    # light them; a lit post names a lantern post.
    steady = [('lit_drops', '3'), ('lit_posts', '19,18; 26,21')]
    assert not [p for p in shape_problems('lab-x', late, steady) if 'descent' in p or 'lit_posts' in p], \
        'lit_posts: posts lit from the start light their landings (%s)' % shape_problems('lab-x', late, steady)
    assert any('no lantern post' in p for p in shape_problems('lab-x', late, [('lit_drops', '3'), ('lit_posts', '5,5')])) and \
        any("lit_posts 'x'" in p for p in shape_problems('lab-x', late, [('lit_drops', '3'), ('lit_posts', 'x')])), 'a lit post names a lantern post'
    assert any('landing 0/0' in p for p in shape_problems('lab-x', lit, [('landing', '0/0')])) and \
        not [p for p in shape_problems('lab-x', lit, [('landing', '1/0')]) if 'descent' in p], 'landing: walk-offs land a column ahead'
    g3 = [list(r) for r in lit]
    for x in range(18, 24):
        g3[19][x] = '.'
    leap = _rows_of(g3)
    assert not [p for p in shape_problems('lab-x', leap, [('landing', '6/2')]) if 'descent' in p], 'landing 6/2: a walk-off 5 down lands a column ahead'
    assert any("landing 'x'" in p for p in shape_problems('lab-x', lit, [('landing', 'x')])), 'a landing that does not read'
    # drops: a route down through a ledge says so.
    g, put, fill = _grid(30, 24)
    fill(0, 29, 22, 23)
    fill(0, 9, 13, 23)
    put(10, 13, '=====')
    fill(15, 29, 13, 21)
    put(2, 12, 'P')
    put(12, 21, 'E')
    led = _rows_of(g)
    assert any('drops: yes' in p for p in shape_problems('lab-x', led)) and \
        not [p for p in shape_problems('lab-x', led, [('drops', 'yes')]) if 'drops' in p], 'drops: required where the route drops through a ledge'
    # Waxfalls: one pouring onto the only landing of a drop is caught; beside
    # it, it passes.
    g, put, fill = _grid(40, 24)
    fill(0, 39, 22, 23)
    fill(0, 17, 17, 23)                    # the upper floor (stand 16)
    fill(19, 39, 17, 19)                   # a roof over the corridor below (stand 21)
    put(2, 16, 'P')
    put(30, 21, 'E')
    put(18, 12, '!')                       # pours down the one way down
    wx = _rows_of(g)
    assert any("only landing" in p for p in shape_problems('lab-x', wx)), 'a waxfall over the only landing (%s)' % shape_problems('lab-x', wx)
    assert not [p for p in shape_problems('lab-x', [r.replace('!', '.') for r in wx]) if 'waxfall' in p], 'without it, none'
    assert _fall_secs(5) + 32.0 / float(_gd_const('player.gd', 'RUN_SPEED')) < float(_gd_const('level_features.gd', 'FALL_OFF')), \
        'a 5-row drop and a step fit a waxfall\'s off window'
    assert not [p for p in waxfall_problems(WalkMap(wx)) if 'off window' in p], 'so the drop through it fits'
    for x in range(25, 28):
        for y in (17, 18, 19):
            g[y][x] = '.'
    beside = _rows_of(g)
    assert not [p for p in shape_problems('lab-x', beside) if 'waxfall' in p], 'another way down beside it: not its only landing'

    # The dark: a lantern on the high road lighting the low road's way.
    hd = [('roads', roads), ('twist', 'dark')]
    lamp = [list(r) for r in two]
    lamp[10][34] = 'L'
    assert not light_problems(WalkMap(_rows_of(lamp), roads), hd), 'a lantern on the high road, 11 rows up: apart'
    near_rows = [list(r) for r in two]
    for x in range(14, 46):
        near_rows[11][x] = '.'
        near_rows[12][x] = '.'
        near_rows[19][x] = '#'
    near_rows[18][34] = 'L'
    nr = _rows_of(near_rows)
    nroads = 'high 30,18; low 30,21'
    assert all(p for _n, p in WalkMap(nr, nroads).roads()) and \
        any('lights the low road' in p for p in light_problems(WalkMap(nr, nroads), [('roads', nroads), ('twist', 'dark')])), \
        'a lantern on a high road 3 rows up lights the low one'
    assert not light_problems(WalkMap(nr, nroads), [('roads', nroads)]), 'only in the dark'
    # The clockwork's column keys.
    ck = [list(r) for r in loop]
    ck[5][10] = 'O'
    ck[17][10] = 'Q'
    assert any('two cog hubs in column 10' in p for p in clockwork_problems(_rows_of(ck))), 'two cogs in a column'
    ck[17][10] = '.'
    ck[8][12] = 'Y'
    ck[19][12] = 'T'
    assert any('two weights or swings in column 12' in p for p in clockwork_problems(_rows_of(ck))), 'a weight over a swing'
    bf = [list(r) for r in loop]
    for x in range(5, 9):
        bf[11][x] = '>'
        bf[22][x] = '<'
    assert any('two storeys' in p for p in clockwork_problems(_rows_of(bf), [('belt_flip', '5-8=8')])) and \
        not clockwork_problems(_rows_of(bf), [('belt_flip', '20-24=8')]), 'a belt_flip over both storeys'
    # The boss and secret levels stay strips.
    assert any('stays a strip' in p for p in shape_problems('4-4', loop)) and any('stays a strip' in p for p in shape_problems('3-S', loop)) \
        and not any('stays a strip' in p for p in shape_problems('4-2', loop)), 'STRIP_ONLY'
    # A two-deck room: its door altar on the deck he comes in on.
    g, put, fill = _grid(60, 24)
    fill(0, 59, 0, 0)
    fill(0, 59, 22, 23)
    fill(20, 50, 1, 1)
    fill(20, 20, 1, 18)
    fill(50, 50, 1, 7)
    fill(50, 50, 11, 21)
    for x, y in ((24, 19), (29, 16), (24, 13)):
        put(x, y, '====')
    fill(31, 49, 11, 11)
    fill(51, 59, 11, 21)
    put(2, 21, 'P')
    put(56, 10, 'E')
    put(36, 21, 's')
    put(40, 10, 's')
    put(14, 21, 'K')
    deck = _rows_of(g)
    assert not room_problems(deck, 'ambush 20-50 rows 1-22'), room_problems(deck, 'ambush 20-50 rows 1-22')
    up = [list(r) for r in deck]
    up[21][14] = '.'
    for x in range(10, 19):
        up[9][x] = '#'
    up[8][14] = 'K'
    up = _rows_of(up)
    assert any('on the deck of its left door' in p for p in room_problems(up, 'ambush 20-50 rows 1-22')), \
        'an altar over the lower door, on another deck (%s)' % room_problems(up, 'ambush 20-50 rows 1-22')
    # A Creepbone at a rotten run's foot is the run (as level_data.gd reads it):
    # the catch rule finds the foot there.
    g, put, fill = _grid(20, 24)
    fill(0, 19, 22, 23)
    fill(0, 19, 0, 0)
    for y in range(3, 6):
        put(6, y, '}')
    put(6, 6, 'i')
    put(2, 21, 'P')
    put(15, 21, 'E')
    fill(0, 5, 3, 3)
    rv = _rows_of(g)
    assert WalkMap(rv).t[6][6] == '}' and any('lands' in p for p in catch_problems(rv)), \
        'a Creepbone at a rotten run\'s foot: the run\'s foot, 15 rows over the floor (%s)' % catch_problems(rv)
    # Gusts: a deck's wind on its rows (a stacked level), a strip's whole columns.
    windy = block('\n'.join(['.' * 20] * 13 + ['#' * 20] * 2) + '\n Z|....((((............\n')
    calm = block('\n'.join(['.' * 20] * 13 + ['#' * 20] * 2))
    st2 = stack(join(crop(windy, 3)), join(crop(calm, 3)))
    assert level_gusts_header(st2) == '4-7:L:A:0-11' and level_gusts_header(join(windy)) == '4-7:L:A', \
        'a deck\'s gusts on its rows (%s)' % level_gusts_header(st2)
    # A lamplit level's lilies: a run by a post held whole (three cells from
    # it), one run on past its reach caught, a far run soft and fine; and no
    # rule without the twist.
    lamp = block('\n'.join(['.' * 40] * 11 + ['.........%%%..................%%%%......', '.P......L.............................E.'] + ['#' * 40] * 2))
    lit = [('twist', 'lamplit')]
    assert lamp_problems(lamp, lit) == [], 'a run three cells from its post is held whole (%s)' % lamp_problems(lamp, lit)
    long = swap(lamp, {(x, 11): '%' for x in range(12, 15)})
    assert any("12, 13, 14" in p for p in lamp_problems(long, lit)) and lamp_problems(long) == [], \
        'a run on past its post\'s reach (%s)' % lamp_problems(long, lit)
