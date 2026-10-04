"""The engine's shape labs (Build 2's shapes, engine work E5, E6 and E10):
small debug levels that differ in shape, not theme, to prove the tall-level camera
(scripts/tall_cam.gd), the bots (reach.gd, reach_search.gd and the
--autoplay bot by route distance: scripts/route_field.gd) and sealed rooms
entered from either side or two decks tall (features/sealed.gd). Not on the
map's path (--autoplay=lab-shape-tower, or main.play_level_id); the
reachability bot in tests/test_core.gd proves each (LAB_LEVELS) and
tests/test_shaped.gd plays them.

  lab-shape-tower   36 x 30: the approved 3-2 tower's height. Up the ledges,
                    a vine and a lift to the bell on the top storey; a
                    catch floor with an altar on each storey; a shaft down
                    the right wall from a lookout ledge to the ground (the
                    camera's fall look-ahead is shot and proved on it).
  lab-shape-climb   24 x 96: 1-3's climb. Three-row terraces, a dip with a
                    ledge, a lift onto the roof, the bell at its far end.
  lab-shape-bowl    24 x 100: 3-3's V. Down in drops of 4, 3 and 2 rows to
                    the floor of the bowl, up three-row steps to the bell.
  lab-shape-loop    24 x 70: 4-2's fold-back. Right along the lower storey,
                    up at the far end, back left along the upper one to the
                    bell right over the start.
  lab-shape-mirror  15 x 100: 4-3 played right to left (facing: left). The
                    start at the right end, a duel entered from the right
                    (the doors seal at both ends), the bell at the far left.
  lab-shape-decks   24 x 130: 5-3's rooms two decks tall. An ambush: in at
                    the bottom left, foes on both decks, out at the top
                    right onto the upper deck; then a hold (20 s), in at the
                    top left, down a stair of ledges to the lower deck and
                    out at its bottom right to the bell. Each deck's foes
                    drop in only once he's on it (features/sealed.gd).
And the shape review's labs, each a shape the redraw needs proved first:
  lab-shape-roads   24 x 110: 2-2's split roads. A high road of shelves
                    and lanterns over a dark low road, apart from x 20 to
                    80 and joined again at an altar (roads: high, low; the
                    dark twist; its threat per road, its gaps per road).
  lab-shape-switchback  24 x 72: 2-3's three tiers, the middle one the
                    mirror of the bottom (mirror_rows): right, back left,
                    right again to the bell, a climb at each turn.
  lab-shape-terraces    24 x 90: 2-1's terraced descent. Three terraces,
                    each a drop of 4 or 5 rows beside a waxfall, never into
                    its column (waxfall_problems).
  lab-shape-islands     22 x 80: 5-2's islands in the wind. Islands 2-4
                    rows apart over the void, a gust zone on its own rows
                    (gusts x0-x1:R:A:y0-y1), landing: 6/2.
  lab-shape-works   24 x 76: 4-2's turn. A loop of clockwork storeys: belts,
                    a weight and a swing on each (never in one column), a
                    belt_flip on the lower storey's belts only, and at the
                    far end a stack of two short lifts and a cog up to the
                    upper storey.
  lab-shape-rootvault   36 x 60: 3-2's tower in the rootvault (the orchard
                    painter): a gallery along the bottom, then the wall in
                    two storeys, each with a catch floor and an altar, up
                    two vine lanes (a Creepbone on one, a pod on the other),
                    a rotten run to sigil 3, ledges to the bell's shelf. The
                    phone's perf route through the storeys (run_phone.sh).

They are drawn on a Grid of their own height, cell by cell (lab_shapes.py
proves the shape tools' sections, placed and stacked: common.block(s, h),
place, stack), and written with common.write(), which holds them to the
shape rules as it does every level (check_shape: the HUD's corners, the
descent and catch rules, the facing). make_levels.py calls this module's
write_levels().

    python3 tools/make_levels.py lab_shaped
"""
import common

LEVELS = []   # (make_levels.py: this module writes its own, write_levels())


class Grid:
    """A w x h grid of '.', drawn into by runs. y is the row."""

    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.rows = [['.'] * w for _ in range(h)]

    def put(self, x, y, s):
        for i, ch in enumerate(s):
            self.rows[y][x + i] = ch

    def fill(self, x0, x1, y0, y1, ch='#'):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.rows[y][x] = ch

    def col(self, x, y0, y1, ch):
        self.fill(x, x, y0, y1, ch)

    def out(self):
        r = common.Rows(''.join(row) for row in self.rows)
        r.parts = ()
        r.overlay = None
        return r


SHAPES = []   # (entry, rows)


def lab(entry, rows):
    SHAPES.append((entry, rows))


# ============================================================ the tower (36 rows)

def tower():
    """Rows: the roof is row 0; the storeys stand on rows 34 (the ground),
    22 (B, the left catch floor), 12 (C, at the vine's top) and 6 (D, the
    belfry). Columns 0-1 and 28-29 are the walls; column 27 is open from
    the roof to the ground (the shaft)."""
    W, H = 30, 36
    g = Grid(W, H)
    g.fill(0, W - 1, 0, 0)                 # the roof
    g.fill(0, 1, 0, H - 1)                 # the walls
    g.fill(W - 2, W - 1, 0, H - 1)
    g.fill(0, W - 1, H - 2, H - 1)         # the ground (rows 34-35)
    # -- the ground floor (stand row 33)
    g.put(4, 33, 'P')
    g.put(8, 33, 'K')
    g.put(11, 33, '@')
    # -- three ledges, 3 rows apart, zig-zagging right (a held jump clears 3)
    g.put(11, 31, '====')
    g.put(16, 28, '====')
    g.put(21, 25, '====')
    g.put(13, 30, 'o')
    g.put(18, 27, 'o')
    # -- catch floor B on the left (stand row 21): up and left off the top ledge
    g.fill(2, 18, 22, 22)
    g.put(6, 21, 'K')
    g.put(3, 19, '2')
    # -- the vine up the right side (column 26, rows 12-24): caught from the top
    #    ledge, climbed to its top, mounted onto floor C
    g.col(26, 12, 24, '{')
    g.put(26, 18, '8')                     # a glowfruit on the vine
    # -- floor C (stand row 11), and the lift at its left end: 3 wide, drawn at
    #    row 9, it sweeps rows 6-12, level with floor C at the bottom and the
    #    belfry floor at the top
    g.fill(15, 25, 12, 12)
    g.put(18, 11, 'K')
    g.put(12, 9, '|||')
    # -- the belfry, floor D (stand row 5): the bell by the left wall
    g.fill(2, 11, 6, 6)
    g.put(4, 5, 'E')
    g.put(8, 3, '1')
    g.put(23, 9, '3')                      # over floor C: a jump from it
    # -- a lookout ledge over the shaft: off its right end, 30 rows down
    #    column 27 to the ground (tools/shot_tall.gd and test_shaped.gd's
    #    fall start there; it's off the route)
    g.fill(24, 26, 4, 4)
    return g.out()


lab({'id': 'lab-shape-tower', 'name': 'The Tall Tower', 'subtitle': 'lab-shape-tower', 'music': 'chapel',
     'theme': 'nave', 'area': 3,
     'hints': ['A tower: up the ledges, the vine and the lift']}, tower())


# ============================================================ the climb (24 rows)

def climb():
    """Up from the floor (stand row 21) to the roof (stand row 12) in
    three-row steps, the last by a lift."""
    W, H = 96, 24
    g = Grid(W, H)
    g.fill(0, W - 1, 22, 23)               # the floor (rows 22-23)
    g.put(2, 21, 'P')
    g.put(6, 21, 'K')
    g.put(9, 21, '@')
    g.put(14, 21, 's')
    # -- terrace 1 (stand 18)
    g.fill(20, 33, 19, 23)
    g.put(27, 16, 'o')
    # -- a dip with a ledge in it, up onto terrace 2 (stand 15)
    g.put(35, 18, '===')
    g.fill(38, 51, 16, 23)
    g.put(42, 15, 'K')
    g.put(46, 13, '1')
    # -- the lift (drawn at row 16: it sweeps rows 13-19; level with terrace 2
    #    halfway, with the roof at the top)
    g.put(52, 16, '|||')
    # -- the roof (stand 12), a step on it, the bell at the far end
    g.fill(55, W - 1, 13, 23)
    g.fill(70, 74, 12, 12)
    g.put(72, 9, 'o')
    g.put(80, 12, 'K')
    g.put(90, 12, 'E')
    return g.out()


lab({'id': 'lab-shape-climb', 'name': 'The Long Climb', 'subtitle': 'lab-shape-climb', 'music': 'chapel',
     'theme': 'nave', 'area': 3,
     'hints': ['A climb: three rows a step, then the lift to the roof']}, climb())


# ============================================================ the bowl (24 rows)

def bowl():
    """Down from the rim (stand row 12) in drops of 4, 3 and 2 rows to the
    floor of the bowl (stand 21), and up three-row steps to the far rim."""
    W, H = 100, 24
    g = Grid(W, H)
    g.fill(0, W - 1, 22, 23)
    g.fill(0, 19, 13, 23)                  # the near rim (stand 12)
    g.put(2, 12, 'P')
    g.put(6, 12, 'K')
    g.put(9, 12, '@')
    g.fill(20, 29, 17, 23)                 # a 4-row drop (stand 16)
    g.fill(30, 39, 20, 23)                 # a 3-row drop (stand 19)
    # -- the floor of the bowl (stand 21)
    g.put(44, 21, 'K')
    g.put(52, 18, '1')
    g.put(58, 21, 's')
    # -- up: a ledge, then stone steps three rows apart
    g.put(64, 19, '====')
    g.fill(68, 79, 16, 23)                 # stand 15
    g.fill(80, W - 1, 13, 23)              # the far rim (stand 12)
    g.put(84, 12, 'K')
    g.put(94, 12, 'E')
    return g.out()


lab({'id': 'lab-shape-bowl', 'name': 'The Bowl', 'subtitle': 'lab-shape-bowl', 'music': 'chapel',
     'theme': 'nave', 'area': 3,
     'hints': ['A bowl: down to the bottom, up the far side']}, bowl())


# ============================================================ the loop (24 rows)

def loop():
    """Two storeys: the lower stands on row 22, the upper on rows 11-12
    (stand 10), solid from the left wall to column 57, so the bell over
    the start is reached only by the long way round: right along the
    bottom, up three ledges at the far end, back left along the top."""
    W, H = 70, 24
    g = Grid(W, H)
    g.fill(0, W - 1, 0, 0)                 # a roof over the upper storey
    g.fill(0, W - 1, 22, 23)               # the lower floor (stand 21)
    g.fill(0, 57, 11, 12)                  # the upper floor (stand 10)
    g.put(3, 21, 'P')
    g.put(8, 21, 'K')
    g.put(11, 21, '@')
    g.put(30, 19, '1')
    g.put(40, 21, 's')
    # -- the far end: up three ledges to the upper floor's end
    g.put(60, 19, '====')
    g.put(65, 16, '====')
    g.put(60, 13, '====')
    # -- back along the top
    g.put(50, 10, 'K')
    g.put(28, 8, '2')
    g.put(4, 10, 'E')
    return g.out()


lab({'id': 'lab-shape-loop', 'name': 'The Loop', 'subtitle': 'lab-shape-loop', 'music': 'chapel',
     'theme': 'nave', 'area': 3,
     'hints': ['A loop: the bell is overhead, the way round is long']}, loop())


# ============================================================ the mirror (15 rows)

def mirror():
    """Right to left on one floor (stand row 12): the start at the right
    end, a duel room (columns 40-65, its end walls included) entered from
    the right, the bell at the far left. Written facing: left, the room
    keeps common.py's door rule by the door he comes in at (an altar within
    8 tiles of its right door); the one by its left door is the next
    checkpoint."""
    W, H = 100, 15
    g = Grid(W, H)
    g.fill(0, W - 1, 13, 14)
    g.put(96, 12, 'P')
    g.put(92, 12, 'K')
    g.put(88, 12, '@')
    g.put(80, 10, '===')
    g.put(81, 7, '1')
    g.put(70, 12, 'K')
    # -- the duel room: roofed, walled down to its doorways (rows 10-12)
    g.fill(40, 65, 0, 3)
    g.fill(40, 41, 4, 9)
    g.fill(64, 65, 4, 9)
    g.put(50, 9, '====')
    g.put(52, 12, 't')
    g.put(35, 12, 'K')
    # -- on to the bell
    g.fill(20, 23, 13, 14, '.')            # a pit, with a ledge over it
    g.put(20, 10, '====')
    g.put(5, 12, 'E')
    return g.out()


lab({'id': 'lab-shape-mirror', 'name': 'The Mirror Hall', 'subtitle': 'lab-shape-mirror', 'music': 'chapel',
     'theme': 'nave', 'area': 3, 'facing': 'left', 'room': 'duel 40-65',
     'hints': ['Backward: the bell is at the far left']}, mirror())


# ============================================================ the decks (24 rows)

def decks():
    """An ambush two decks tall (columns 14-45, rows 1-22: its ceiling and
    floor included): in through its left door on the lower deck (rows
    19-21), foes on both decks, a stair of ledges between them, out through
    its right door on the upper deck (rows 8-10). Then a hold two decks tall
    (columns 60-95): in through its left door on the upper deck (the altar
    at 55 by it, on that deck), down a stair of ledges inside (3 rows a
    step), out through its right door on the lower deck to the bell."""
    W, H = 130, 24
    g = Grid(W, H)
    g.fill(0, W - 1, 0, 0)
    g.fill(0, W - 1, 22, 23)               # the lower deck (stand 21)
    g.put(2, 21, 'P')
    g.put(8, 21, 'K')
    g.put(11, 21, '@')
    # -- the ambush's shell: the ceiling (row 1), its left wall down to the
    #    lower door, its right wall above and below the upper door
    g.fill(14, 45, 1, 1)
    g.col(14, 1, 18, '#')
    g.col(45, 1, 7, '#')
    g.col(45, 11, 21, '#')
    # -- inside: a stair of ledges up to the upper deck (stand 10, columns 26-44)
    g.put(19, 19, '====')
    g.put(24, 16, '====')
    g.put(19, 13, '====')
    g.fill(26, 44, 11, 11)
    g.put(32, 21, 's')
    g.put(39, 21, 's')
    g.put(33, 10, 's')
    g.put(39, 10, 's')
    # -- between them, on the upper deck: solid under it, the altar by the
    #    hold's door
    g.fill(46, 60, 11, 23)
    g.put(55, 10, 'K')
    # -- the hold's shell: its ceiling, its left wall above the upper door,
    #    its right wall down to the lower door
    g.fill(60, 95, 1, 1)
    g.col(60, 1, 7, '#')
    g.col(95, 1, 18, '#')
    # -- inside: the upper deck (stand 10) to 75, a stair of ledges down
    #    (3 rows a step, a walk off each), the lower deck to its door
    g.fill(61, 75, 11, 11)
    g.put(76, 14, '====')
    g.put(80, 17, '====')
    g.put(84, 20, '====')
    g.put(66, 10, 's')
    g.put(71, 10, 's')
    g.put(72, 21, 's')
    g.put(86, 21, 's')
    # -- out on the lower deck: the bell
    g.put(110, 21, 'K')
    g.put(124, 21, 'E')
    return g.out()


lab({'id': 'lab-shape-decks', 'name': 'The Two Decks', 'subtitle': 'lab-shape-decks', 'music': 'chapel',
     'theme': 'nave', 'area': 3, 'room': 'ambush 14-45 rows 1-22; hold 60-95 rows 1-22 @20',
     'hints': ['Two rooms two decks tall: in at the bottom, out at the top, and back down']}, decks())


# ============================================================ the split roads (24 rows)

ROADS = 'high 50,10; low 50,21'


def roads():
    """One road in (stand 21), then from x 20 a high road of shelves (stand
    10) with lanterns, Rattles and a sigil over a dark low road (stand 21)
    with a Rattle, a bat and a sigil, the high road 11 rows up (its lights
    never reach the low road: light_problems), joined again at x 84 (an
    altar), then the bell."""
    W, H = 110, 24
    g = Grid(W, H)
    g.fill(0, W - 1, 0, 0)
    g.fill(0, W - 1, 22, 23)               # the low road and the common floor (stand 21)
    g.put(2, 21, 'P')
    g.put(6, 21, 'K')
    g.put(9, 21, '@')
    # -- up to the high road: ledges 3 rows apart at its start
    g.put(15, 19, '===')
    g.put(17, 16, '===')
    g.put(15, 13, '===')
    g.fill(20, 78, 11, 12)                 # the high road (stand 10)
    g.put(28, 10, 'L')
    g.put(44, 10, 'L')
    g.put(62, 10, 'L')
    g.put(36, 10, 's')
    g.put(54, 10, 's')
    g.put(48, 7, '1')
    # -- down from it at its end
    g.put(80, 13, '===')
    g.put(82, 16, '===')
    g.put(80, 19, '===')
    # -- the low road, dark: shorter and faster
    g.put(40, 21, 's')
    g.put(58, 18, 'b')
    g.put(66, 20, '2')
    # -- together again
    g.put(88, 21, 'K')
    g.put(96, 19, '3')
    g.put(104, 21, 'E')
    return g.out()


_roads = roads()
lab({'id': 'lab-shape-roads', 'name': 'The Two Roads', 'subtitle': 'lab-shape-roads', 'music': 'chapel',
     'theme': 'nave', 'area': 3, 'twist': 'dark', 'roads': ROADS,
     'threat': round(common.threat_of(_roads, roads=ROADS), 2),
     'hints': ['Two roads: the lit shelves above, the dark water road below']}, _roads)


# ============================================================ the switchback (24 rows)

def _tier(w, hole, climb):
    """One tier of the switchback, 8 rows, going right: 6 rows of air over
    its 2 floor rows (rows 6-7), its floor open over columns hole (the
    climb up from the tier under it comes through there), and at its right
    end a climb to the tier over it: ledges 3 rows apart (climb: their x)."""
    rows = [['.'] * w for _ in range(8)]
    for y in (6, 7):
        for x in range(w):
            if x not in hole:
                rows[y][x] = '#'
    for x, y in climb:
        for k in range(3):
            rows[y][x + k] = '='
    return common.Section(''.join(r) for r in rows)


def switchback():
    """Three tiers (floors on rows 6-7, 14-15 and 22-23): along the bottom
    to the right, up through the middle tier's floor at its right end, back
    left along it (the bottom tier mirrored: mirror_rows), up through the top
    tier's floor at its left end, right again to the bell."""
    W = 72
    climb = [(W - 9, 3), (W - 5, 0)]
    bottom = _tier(W, range(0, 0), climb)
    # the bottom tier with a way up through its floor's left end, mirrored:
    # its way up at the right (over the bottom's climb), its climb at the left
    middle = common.mirror_rows(_tier(W, range(1, 8), climb))
    top = _tier(W, range(1, 8), [])
    rows = [list(r) for r in list(top) + list(middle) + list(bottom)]
    g = Grid(W, 24)
    g.rows = rows
    g.fill(0, W - 1, 0, 0)                 # the roof
    g.put(2, 21, 'P')
    g.put(6, 21, 'K')
    g.put(9, 21, '@')
    g.put(30, 21, 's')
    g.put(40, 13, 's')
    g.put(36, 13, 'K')
    g.put(22, 11, '1')
    g.put(44, 5, 's')
    g.put(30, 5, 'K')
    g.put(66, 5, 'E')
    return g.out()


lab({'id': 'lab-shape-switchback', 'name': 'The Switchback', 'subtitle': 'lab-shape-switchback', 'music': 'chapel',
     'theme': 'nave', 'area': 3,
     'hints': ['A switchback: right, back left over it, right again']}, switchback())


# ============================================================ the terraces (24 rows)

def terraces():
    """Three terraces (stand 12, 16 and 21) down to the right, each drop a
    walk-off beside a waxfall pouring over the terrace's lip one column on
    (never into its column: waxfall_problems), drip spouts over the first."""
    W, H = 90, 24
    g = Grid(W, H)
    g.fill(0, W - 1, 0, 0)
    g.fill(0, 29, 13, 23)                  # terrace 1 (stand 12)
    g.fill(30, 59, 17, 23)                 # terrace 2 (stand 16): a 4-row drop
    g.fill(60, W - 1, 22, 23)              # terrace 3 (stand 21): a 5-row drop
    g.put(2, 12, 'P')
    g.put(6, 12, 'K')
    g.put(9, 12, '@')
    g.put(14, 1, 'd')
    g.put(22, 1, 'd')
    g.put(31, 1, '!')                      # pours onto terrace 2, beside the drop off 1
    g.put(61, 1, '!')                      # pours onto terrace 3, beside the drop off 2
    g.put(40, 16, 's')
    g.put(44, 16, 'K')
    g.put(36, 13, '1')
    g.put(70, 21, 's')
    g.put(76, 21, 'K')
    g.put(84, 21, 'E')
    return g.out()


lab({'id': 'lab-shape-terraces', 'name': 'The Terraces', 'subtitle': 'lab-shape-terraces', 'music': 'chapel',
     'theme': 'waxfall', 'area': 3,
     'hints': ['Terraces: step off beside the falls, never under them']}, terraces())


# ============================================================ the islands (22 rows)

def islands():
    """Stone islands over the void (no floor under them: a fall is a pit),
    their tops 2 to 4 rows apart and 3 or 4 columns, a gust zone over the
    middle islands' rows only, landing: 6/2 (no drop or wind jump lands more
    than 6 columns on and more than 2 rows lower)."""
    W, H = 80, 22
    g = Grid(W, H)
    g.fill(0, W - 1, 0, 0)
    for x0, x1, top in ((0, 12, 12), (16, 24, 14), (28, 36, 11), (40, 50, 13), (54, 62, 12), (66, W - 1, 13)):
        g.fill(x0, x1, top, top + 3)
    g.put(2, 11, 'P')
    g.put(6, 11, 'K')
    g.put(9, 11, '@')
    g.put(20, 13, 's')
    g.put(32, 10, 'K')
    g.put(31, 7, '1')
    g.put(46, 12, 's')
    g.put(58, 11, 'K')
    g.put(74, 12, 'E')
    return g.out()


lab({'id': 'lab-shape-islands', 'name': 'The Islands', 'subtitle': 'lab-shape-islands', 'music': 'chapel',
     'theme': 'nave', 'area': 3, 'landing': '6/2', 'gusts': '26-52:R:A:4-16',
     'hints': ['Islands in the wind: it blows only up here']}, islands())


# ============================================================ the works (24 rows)

def works():
    """lab-shape-loop's fold-back in clockwork: the lower storey (stand 21)
    right, belts carrying right and a weight under the upper floor; at the
    far end two short lifts one over the other and a cog; the upper storey
    (stand 10) left, belts carrying left, a weight under the roof and a
    swing, every one in a column of its own (cog_phase and weight_phase are
    keyed by column), the bell over the start; belt_flip on the lower
    storey's belts only."""
    W, H = 76, 24
    g = Grid(W, H)
    g.fill(0, W - 1, 0, 0)
    g.fill(0, W - 1, 22, 23)
    g.fill(0, 63, 11, 12)
    g.put(3, 21, 'P')
    g.put(8, 21, 'K')
    g.put(11, 21, '@')
    g.put(20, 22, '>>>>>>')
    g.put(34, 13, 'Y')                     # a weight under the upper floor
    g.put(44, 21, 'K')
    # -- the turn: two lifts (each sweeps 3 rows up and down) and a cog
    g.put(64, 18, '|||')                   # 15-21: from the floor up
    g.put(67, 12, '|||')                   # 9-15: from the first up past the upper floor's end
    g.put(72, 18, 'O')                     # (112 px clear of the floor and the wall: its teeth's ring)
    # -- back along the top
    g.put(40, 11, '<<<<<<')
    g.put(26, 1, 'Y')                      # a weight under the roof
    g.put(14, 5, 'TTT')                    # a swing
    g.put(50, 10, 'K')
    g.put(30, 8, '1')
    g.put(4, 10, 'E')
    return g.out()


lab({'id': 'lab-shape-works', 'name': 'The Works', 'subtitle': 'lab-shape-works', 'music': 'chapel',
     'theme': 'clockface', 'area': 3, 'belt_flip': '20-25=8',
     'hints': ['The works: round and up the lifts, back along the top']}, works())


# ============================================================ the rootvault tower (36 rows)

def rootvault():
    """3-2's tower in the rootvault (36 rows): a gallery along the bottom
    (stand 33), then the wall: two vine lanes (a Creepbone on one, a pod on
    the other) up 12 rows to storey 1's catch floor (stand 21) with its
    altar, a vine up 12 more to storey 2's (stand 9) with its altar, a
    rotten run up from it to sigil 3, ledges up to the bell's shelf (stand
    3) in the middle of the wall."""
    W, H = 60, 36
    g = Grid(W, H)
    g.fill(0, W - 1, 0, 0)
    g.fill(0, 1, 0, H - 1)
    g.fill(W - 1, W - 1, 0, H - 1)
    g.fill(0, W - 1, 34, 35)               # the gallery's floor (stand 33)
    g.put(3, 33, 'P')
    g.put(7, 33, 'K')
    g.put(10, 33, '@')
    g.put(18, 33, 'r')
    g.put(26, 33, 's')
    g.put(24, 30, '2')
    # -- the wall's foot: two vine lanes up to storey 1 (through a gap in its floor)
    g.col(37, 21, 33, '{')
    g.col(39, 21, 33, '{')
    g.put(37, 27, 'i')                     # a Creepbone on the first lane
    g.put(39, 25, '*')                     # a pod on the second
    g.fill(40, W - 2, 22, 22)              # storey 1's catch floor (stand 21)
    g.fill(34, 36, 22, 22)
    g.put(50, 21, 'K')
    g.put(46, 21, 's')
    # -- up to storey 2: a vine through the gap at its floor's right end
    g.col(56, 10, 21, '{')
    g.put(56, 15, '8')                     # a glowfruit on it
    g.fill(34, 55, 10, 10)                 # storey 2's catch floor (stand 9)
    g.put(46, 9, 'K')
    # -- a rotten run up from storey 2 to sigil 3 (a snap: back onto the floor)
    g.col(38, 7, 9, '}')
    g.put(38, 6, '3')
    # -- ledges up to the bell's shelf (stand 3)
    g.put(51, 7, '===')
    g.fill(40, 49, 4, 4)
    g.put(44, 3, 'E')
    g.put(42, 1, '1')
    return g.out()


lab({'id': 'lab-shape-rootvault', 'name': 'The Rootvault Tower', 'subtitle': 'lab-shape-rootvault', 'music': 'chapel',
     'theme': 'rootvault', 'area': 13,
     'hints': ['The wall: up the lanes, a catch floor and an altar each storey']}, rootvault())


def write_levels():
    """Writes every shape lab (make_levels.py calls it); returns their ids."""
    out = []
    for entry, rows in SHAPES:
        common.write(entry['id'], common.header_of(entry, rows), rows)
        out.append(entry['id'])
    return out
