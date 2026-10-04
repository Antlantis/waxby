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
  lab-shape-decks   24 x 80: 5-3's hold room. An ambush two decks tall:
                    in at the bottom left, foes on both decks, out at the
                    top right onto the upper deck and the bell.

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
    its right door on the upper deck (rows 8-10) to the bell."""
    W, H = 80, 24
    g = Grid(W, H)
    g.fill(0, W - 1, 0, 0)
    g.fill(0, W - 1, 22, 23)               # the lower deck (stand 21)
    g.put(2, 21, 'P')
    g.put(8, 21, 'K')
    g.put(11, 21, '@')
    # -- the room's shell: the ceiling (row 1), its left wall down to the
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
    # -- outside, on the upper deck: solid under it, the bell at its end
    g.fill(46, W - 1, 11, 23)
    g.put(55, 10, 'K')
    g.put(74, 10, 'E')
    return g.out()


lab({'id': 'lab-shape-decks', 'name': 'The Two Decks', 'subtitle': 'lab-shape-decks', 'music': 'chapel',
     'theme': 'nave', 'area': 3, 'room': 'ambush 14-45 rows 1-22',
     'hints': ['An ambush two decks tall: in at the bottom, out at the top']}, decks())


def write_levels():
    """Writes every shape lab (make_levels.py calls it); returns their ids."""
    out = []
    for entry, rows in SHAPES:
        common.write(entry['id'], common.header_of(entry, rows), rows)
        out.append(entry['id'])
    return out
