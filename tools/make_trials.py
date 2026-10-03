"""Writes the Vigil Trials' rooms: game/levels/trials/<id>.txt (spec §7.4,
p_modes §7). One room per trial (k1-k4, w1-w4, r1-r4, f1-f4, x1-x4); this
build has trials 1 and 2 of every calling. game/scripts/modes/trial_data.gd
holds each trial's loadout, lesson and base time.

The rooms are laid out in code (Room below: ground, pits, walls, ledges,
things), 15 rows each, with two private overlays that are never written
into the rows (p_modes §4.3):
    candles   the trial candles that gate the bell:
                *  any hit or touch       s  hero shots only
                w  hero waves and fire    t  touch only
                k  the foe on this cell dies (the candle sits over it)
              -> header  marks: x,y,kind;...
    assist    ledges that stand in for a calling's quirk in the bot's copy
              only (tests/test_modes.gd lays them in; the game never does)
              -> header  assist: x,y;...

The room's E is its bell: trials.gd hides it until every candle burns.
Header: title (the trial's name), subtitle, music (trial, falling back to
chapel), theme, area and area_abs (the loadout's level), hints (in reading
order), trial (the id), cls, marks, assist.

Numbers the layouts lean on (player.gd, measured): a held running jump
rises 3.5 tiles and carries 5 tiles back to its own height (4 to a step 3
up, 5 to one up); a Drift carries 10-11; a Grave Step 7.5-9; a Moth Cling
climbs any shaft 2-3 tiles wide. So: w2's gaps are 7 (a jump can't, a Drift
can), x1's 6, r2's chimneys 7 rows (a jump climbs 3.5), and k1's moat 6 to
a post 1 up (out of any jump's reach); x2's Bonebows sit in cages whose one
slit is too low for Waxby and deeper than a swing.

The tool checks the legend, one P and one E, that candles and assist cells
are air, that a kill candle sits on a monster, and the hints against the signs.

    python3 tools/make_trials.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'levels'))
sys.dont_write_bytecode = True

from common import H, LEGEND  # noqa: E402

OUT = os.path.join(HERE, '..', 'game', 'levels', 'trials')
CANDLE_KINDS = set('*swtk')
MONSTERS = set('sbtahgkfM')


class Room:
    """A trial's grid, laid out in code. y is the row (0 top, 14 bottom); a
    ground's `top` is the row its surface is (13 = the usual floor)."""

    def __init__(self, w, ceiling=2):
        self.w = w
        self.g = [['.'] * w for _ in range(H)]
        self.c = [['.'] * w for _ in range(H)]
        self.a = [['.'] * w for _ in range(H)]
        for y in range(ceiling):
            self.fill(0, w - 1, y, y)

    def fill(self, x0, x1, y0, y1, ch='#'):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g[y][x] = ch
        return self

    def ground(self, x0, x1, top=13):
        return self.fill(x0, x1, top, H - 1)

    def pit(self, x0, x1, spikes=True):
        """A gap to the bottom, spikes on its floor (a hurt and a bounce) or open (a fall)."""
        self.fill(x0, x1, 2, H - 1, '.')
        if spikes:
            self.fill(x0, x1, 13, 13, '^')
            self.fill(x0, x1, 14, 14, '#')
        return self

    def put(self, x, y, ch):
        self.g[y][x] = ch
        return self

    def candle(self, x, y, kind):
        self.c[y][x] = kind
        return self

    def assist(self, x0, x1, y):
        for x in range(x0, x1 + 1):
            self.a[y][x] = '='
        return self

    def rows(self):
        return [''.join(r) for r in self.g]


def reading_hints(rows, hints):
    """The hints are listed left to right; LevelData hands them out in
    reading order (row by row)."""
    signs = [(x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == '@']
    assert len(signs) == len(hints), '%d signs but %d hints' % (len(signs), len(hints))
    by_x = sorted(signs)
    text = {pos: hints[i] for i, pos in enumerate(by_x)}
    return [text[p] for p in sorted(signs, key=lambda p: (p[1], p[0]))]


def write(tid, name, cls, level, theme, hints, rm):
    rows = rm.rows()
    w = rm.w
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            assert ch in LEGEND, '%s: glyph %r at %d,%d' % (tid, ch, x, y)
    assert sum(r.count('P') for r in rows) == 1, '%s: one start' % tid
    assert sum(r.count('E') for r in rows) == 1, '%s: one bell' % tid
    marks = []
    for y in range(H):
        for x in range(w):
            k = rm.c[y][x]
            if k == '.':
                continue
            assert k in CANDLE_KINDS, '%s: candle %r at %d,%d' % (tid, k, x, y)
            if k == 'k':
                assert rows[y][x] in MONSTERS, '%s: kill candle at %d,%d is not on a monster (%r)' % (tid, x, y, rows[y][x])
            else:
                assert rows[y][x] == '.', '%s: candle at %d,%d is on %r' % (tid, x, y, rows[y][x])
            marks.append('%d,%d,%s' % (x, y, k))
    assist = []
    for y in range(H):
        for x in range(w):
            if rm.a[y][x] == '=':
                assert rows[y][x] == '.', '%s: assist at %d,%d is on %r' % (tid, x, y, rows[y][x])
                assist.append('%d,%d' % (x, y))
    header = [('title', name), ('subtitle', 'Vigil Trial'), ('music', 'trial'), ('theme', theme),
              ('area', str(level)), ('area_abs', str(level)), ('trial', tid), ('cls', cls),
              ('marks', ';'.join(marks)), ('assist', ';'.join(assist)),
              ('hints', '|'.join(reading_hints(rows, hints)))]
    text = ''.join('%s: %s\n' % kv for kv in header if kv[1] != '') + '---\n' + '\n'.join(r.rstrip('.') for r in rows) + '\n'
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, tid + '.txt'), 'w') as f:
        f.write(text)
    kinds = {}
    for m in marks:
        k = m.split(',')[2]
        kinds[k] = kinds.get(k, 0) + 1
    print('trials/%s.txt: %-18s %3d wide, candles %s, %d assist cells' % (
        tid, name, w, ' '.join('%d %s' % (v, k) for k, v in sorted(kinds.items())), len(assist)))
    return text


BELL_HINT = 'Light every candle and the bell rises'


def start(rm, lesson_x=4):
    rm.put(2, 12, 'P').put(lesson_x, 12, '@')


# ============================================================ Candleknight

def k1():
    """Ping! (L8): three Bonebows on posts across a spike moat six tiles
    wide, the posts one, two and three tiles up (no jump carries across to
    the first; the tallest bow's head stays 40 px clear of the view's top at
    the walkway's camera, under the HUD corner where the mode pill sits),
    each bow a little further and higher, every one within its 320 px reach
    of Waxby standing at the moat's edge (so each looses at him there: the
    tallest was 327 px away with a seven-tile moat, and never shot) and
    inside its 35-degree aim. A shot candle hangs in front of each bow, in
    the arrow's line: only an arrow sent back (a Perfect Guard with Mirrored
    Glass throws it home along that line, or a swing timed onto it) lights
    it. The bell rises back on the walkway."""
    rm = Room(42)
    rm.ground(0, 41)
    start(rm)
    rm.fill(34, 41, 5, 12)                  # the wall behind the posts
    rm.fill(24, 29, 12, 12, '^')            # the moat
    rm.fill(30, 30, 12, 12)                 # post 1: one up
    rm.fill(31, 31, 11, 12)                 # post 2: two up
    rm.fill(32, 33, 10, 12)                 # post 3: three up
    rm.put(30, 11, 'a').put(31, 10, 'a').put(32, 9, 'a')
    rm.candle(29, 11, 's').candle(30, 10, 's').candle(31, 9, 's')
    rm.put(9, 9, 'c').put(19, 9, 'c')
    rm.put(14, 12, 'E').put(20, 12, '@')
    return rm, ['Guard as the arrow lands. A perfect guard throws it home.', BELL_HINT]


def k2():
    """Shield and Stair (L12): five gaps over spikes at the very edge of a
    jump (five tiles to a step one up, four to one three up), where a jump a
    hair late meets the wall's face and Ledge Grab hauls him up; between
    them, Rattles on crumbling ledges that a shield-rush clears (a rush
    stops at a ledge's edge). A touch candle just past four of the gaps."""
    rm = Room(100)
    L0, L1, L4, L5 = 13, 12, 9, 8
    rm.ground(0, 11, L0)
    start(rm)
    rm.fill(5, 9, 10, 10, '%').put(7, 9, 's').put(9, 12, 's')
    rm.pit(12, 16)
    rm.ground(17, 26, L1).candle(18, 11, 't')
    rm.fill(20, 24, 8, 8, '%').put(22, 7, 's').put(23, 11, 's')
    rm.pit(27, 30)
    rm.ground(31, 40, L4).candle(32, 8, 't').put(36, 8, 's')
    rm.ground(41, 50, L0)
    rm.fill(43, 47, 10, 10, '%').put(45, 9, 's').put(48, 12, 's')
    rm.pit(51, 55)
    rm.ground(56, 65, L1).put(61, 11, 's')
    rm.pit(66, 69)
    rm.ground(70, 79, L4).candle(71, 8, 't').put(75, 8, 's')
    rm.pit(80, 84)
    rm.ground(85, 99, L5).candle(86, 7, 't')
    rm.put(95, 7, 'E')
    for x, y in [(10, 9), (24, 5), (38, 4), (48, 9), (62, 7), (77, 4), (92, 3)]:
        rm.put(x, y, 'c')
    return rm, ['Hold a direction to rush. Missed a ledge? Reach for it.']


# ============================================================ Taperwitch

def w1():
    """Lanterns of Wax (L8): no sconces at all; the only light is hers and
    her flares' (a Beacon where one lands, 160 px for 6 s). Pits and Flits in
    the dark. Five candles hang six tiles over the floor, higher than her
    reach, where a flare thrown at the top of a jump arcs through them (any
    hit lights them)."""
    rm = Room(84)
    rm.ground(0, 83)
    start(rm)
    for x0, x1 in [(11, 14), (27, 29), (41, 43), (54, 56), (63, 65)]:
        rm.pit(x0, x1, spikes=False)
    rm.put(23, 6, 'b').put(49, 6, 'b').put(70, 7, 'b').put(50, 12, 's')
    for x in [17, 33, 47, 60, 72]:
        rm.candle(x, 7, '*')
    rm.put(79, 12, 'E')
    return rm, ['A flare leaves a light. Throw one before you jump.']


def w2():
    """Drift (L12): five gaps over spikes, seven tiles wide (a jump carries
    five, a Drift ten or more), a touch candle in the middle of each, four
    tiles up, where the float passes; drip spouts over two of them douse her
    on the way. The bot gets a ledge under each candle."""
    rm = Room(92)
    rm.ground(0, 91)
    start(rm)
    x = 14
    for i in range(5):
        rm.pit(x, x + 6)
        rm.candle(x + 3, 9, 't')
        rm.assist(x + 2, x + 4, 11)
        if i in (1, 3):
            rm.fill(x - 1, x + 7, 2, 3)
            rm.put(x + 3, 4, 'd')
        x += 13
    for cx in [9, 33, 59, 85]:
        rm.put(cx, 9, 'c')
    rm.put(86, 12, 'E')
    return rm, ['Press jump again as you fall, and float.']


# ============================================================ Sootrunner

def r1():
    """Through the Smoke (L8): four low halls (four rows of room), each held
    by a wall of three Rattles shoulder to shoulder with a Bonebow loosing
    through them from the far end; a Smoke Step goes through all of it (a
    landing or a stomp gives the Step back). A touch candle just behind
    each wall."""
    rm = Room(100)
    rm.ground(0, 99)
    start(rm)
    x = 10
    for i in range(4):
        rm.fill(x, x + 17, 2, 8)          # the hall's low roof
        rm.put(x + 5, 12, 's').put(x + 6, 12, 's').put(x + 7, 12, 's')
        rm.candle(x + 9, 11, 't')
        rm.put(x + 16, 12, 'a')
        rm.put(x + 1, 9, 'c')
        x += 22
    rm.put(96, 12, 'E')
    return rm, ['Step through them. Arrows too.']


def r2():
    """Moth Cling (L12): two chimneys three tiles wide and seven rows deep
    (a jump climbs three and a half): slide down a wall, kick off it to the
    other, and up. A touch candle halfway up each and one at each top. The
    bot gets ledges up the chimneys."""
    rm = Room(66)
    rm.ground(0, 65)
    start(rm)
    for x in [12, 38]:
        # The chimney: walls at x and x + 4, open at the bottom left (the way
        # in) and at the top, where a shelf leads on over the right wall.
        rm.fill(x, x, 5, 10)
        rm.fill(x + 4, x + 12, 6, 12)
        rm.candle(x + 2, 8, 't').candle(x + 5, 5, 't')
        rm.assist(x + 1, x + 3, 10).assist(x + 1, x + 3, 7)
        rm.put(x + 9, 3, 'c')
    rm.put(62, 12, 'E')
    return rm, ['Slide down a wall, kick off it. A cling gives your step back.']


# ============================================================ Bellfounder

def f1():
    """Stampede (L8): a long run crowded with Rattles, Flits and Dripkins
    (hanging from low roofs) that a Stampede, flat out for 0.8 s, bowls
    over; stopping means being hit. Six touch candles along the way."""
    rm = Room(128)
    rm.ground(0, 127)
    start(rm)
    rm.fill(18, 36, 2, 5).fill(46, 56, 2, 7).fill(69, 79, 2, 4)
    for x in [16, 24, 30, 38, 50, 56, 71, 76, 84, 90, 97, 106, 111]:
        rm.put(x, 12, 's')
    for x, y in [(18, 8), (71, 8), (101, 8)]:
        rm.put(x, y, 'b')
    for x, y in [(27, 6), (48, 8), (53, 8), (74, 5)]:
        rm.put(x, y, 'k')
    for x in [21, 40, 58, 77, 96, 115]:
        rm.candle(x, 11, 't')
    for x in [10, 64, 88, 118]:
        rm.put(x, 9, 'c')
    rm.put(121, 12, 'E')
    return rm, ['Keep running. Small things get out of the way.']


def f2():
    """Anvil (L12): four Hollow Helms, each under a high ledge reached by a
    step. A shield only faces front; an Anvil (a Peal in the air, falling
    hard) lands on them from above and keeps its sideways speed. A kill
    candle on each Helm."""
    rm = Room(100)
    rm.ground(0, 99)
    start(rm)
    for x in [16, 38, 60, 82]:
        rm.fill(x - 6, x - 4, 9, 9, '=')     # the step up
        rm.fill(x - 2, x + 3, 6, 6, '=')     # the ledge over the Helm
        rm.put(x, 12, 'h').candle(x, 12, 'k')
        rm.put(x - 9, 10, 'c')
    rm.put(96, 12, 'E')
    return rm, ['Peal in the air, and fall like an anvil.']


# ============================================================ Sexton

def x1():
    """Grave Step (L8): five gaps over spikes, six tiles wide (a jump carries
    five; a jump and a Grave Step off its bone ledge, eight), a touch candle
    over the middle of each, four tiles up, where the second jump rises. The
    bot gets a ledge in each gap."""
    rm = Room(92)
    rm.ground(0, 91)
    start(rm)
    x = 13
    for i in range(5):
        rm.pit(x, x + 5)
        rm.candle(x + 3, 9, 't')
        rm.assist(x + 2, x + 3, 11)
        x += 13
    for cx in [9, 35, 61, 83]:
        rm.put(cx, 8, 'c')
    rm.put(84, 12, 'E')
    return rm, ['Jump again in the air: the dead lend you a step.']


def x2():
    """The Knell (L12): five pairs. A Rattle on the walkway to hit (the
    wisps strike only in the 0.8 s after a hit, at the foe nearest them),
    and a Bonebow shut in a low cage two tiles thick, with one slit at its
    feet (too low for Waxby, too deep for a swing; the bow looses through
    it): the wisps' motes reach it (170 px). Put the Rattle out, and the
    wisps fly at the caged bow: a kill candle on each (the draft's shot
    candles, made kills so a stray mote can't strand a run). The cages are
    low enough to jump onto."""
    rm = Room(106)
    rm.ground(0, 105)
    start(rm)
    x = 12
    for i in range(5):
        rm.put(x, 12, 's')                  # the near Rattle
        c = x + 3
        rm.fill(c, c + 4, 10, 12)           # the cage: roof row 10, walls two thick
        rm.fill(c, c + 1, 12, 12, '.')      # the slit, at its feet
        rm.fill(c + 2, c + 3, 11, 12, '.')  # the inside
        rm.put(c + 3, 12, 'a').candle(c + 3, 12, 'k')
        rm.put(x - 3, 8, 'c')
        x += 18
    rm.put(101, 12, 'E')
    return rm, ['Wisps strike only just after you do.']


# Every trial in A2's Proving Hall (spec §11.4: the Trials use it; the rev5
# review: on v2's story themes the garden rooms drew 836-1080 calls, against
# the Trials' 450 and the 900 ceiling; x2 in the hall drew 138-167).
HALL = 'trialhall'
TRIALS = [
    ('k1', 'Ping!', 'knight', 8, HALL, k1),
    ('k2', 'Shield and Stair', 'knight', 12, HALL, k2),
    ('w1', 'Lanterns of Wax', 'witch', 8, HALL, w1),
    ('w2', 'Drift', 'witch', 12, HALL, w2),
    ('r1', 'Through the Smoke', 'runner', 8, HALL, r1),
    ('r2', 'Moth Cling', 'runner', 12, HALL, r2),
    ('f1', 'Stampede', 'founder', 8, HALL, f1),
    ('f2', 'Anvil', 'founder', 12, HALL, f2),
    ('x1', 'Grave Step', 'sexton', 8, HALL, x1),
    ('x2', 'The Knell', 'sexton', 12, HALL, x2),
]


def main():
    for tid, name, cls, level, theme, fn in TRIALS:
        rm, hints = fn()
        write(tid, name, cls, level, theme, hints, rm)


if __name__ == '__main__':
    main()
