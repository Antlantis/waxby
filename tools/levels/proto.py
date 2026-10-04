"""PROTOTYPE (branch proto-tall): two tall feel labs, to test levels that
differ in SHAPE, not only in theme. Not on the map's path; debug only.

  lab-2  The Bone Tower   (orchard, plays as World 3)  46 rows x 30: a climb
         from the floor to a belfry: zig-zag ledges, a vine with a Creepbone,
         an altar shelf, a lift, a bonebow under the bell.
  lab-3  The Clock Shaft  (clockface, plays as World 4)  46 rows x 30: a
         descent from a shelf under the roof to the bell at the bottom: drops
         past ledges, a vine caught on the way down, an altar landing, a lift
         down through a floor, icicles, a spike bed under a blind drop.

The common.block() helper is fixed at 15 rows (common.H), so these are drawn
on a Grid of their own height and written with common.write(), which takes
any number of rows (level_data.gd: the height is just the number of rows).
The `world:` header is a prototype-only key (level_data.gd reads it on this
branch): a lab plays as that World (themed movers, W4's icicle lean) while
is_lab() still keeps it out of the save.

    python3 tools/make_levels.py proto
"""
import common

LEVELS = []


class Grid:
    """A w x h grid of '.', drawn into by row/column runs. y is the row."""

    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.rows = [['.'] * w for _ in range(h)]

    def put(self, x, y, s):
        for i, ch in enumerate(s):
            self.rows[y][x + i] = ch

    def run(self, x0, x1, y, ch):
        for x in range(x0, x1 + 1):
            self.rows[y][x] = ch

    def col(self, x, y0, y1, ch):
        for y in range(y0, y1 + 1):
            self.rows[y][x] = ch

    def fill(self, x0, x1, y0, y1, ch):
        for y in range(y0, y1 + 1):
            self.run(x0, x1, y, ch)

    def out(self):
        r = common.Rows(''.join(row) for row in self.rows)
        r.parts = ()
        r.overlay = None
        return r


# ============================================================ lab-2: the tower climb

def tower():
    W, H = 30, 46
    g = Grid(W, H)
    g.fill(0, W - 1, 0, 0, '#')            # the belfry roof
    g.fill(0, 1, 0, H - 1, '#')            # the tower's walls
    g.fill(W - 2, W - 1, 0, H - 1, '#')
    g.fill(0, W - 1, H - 2, H - 1, '#')    # the floor (rows 44-45)
    # -- the ground floor (stand row 43)
    g.put(3, 43, 'P')
    g.put(6, 43, '@')
    g.put(15, 43, 'r')                     # a Rootling on the floor
    g.put(9, 42, 'o')
    g.put(12, 42, 'o')
    g.put(2, 40, 'c')                      # wall candles on the way up
    g.put(27, 34, 'c')
    g.put(2, 26, 'c')
    g.put(2, 14, 'c')
    # -- zig-zag ledges, 3 rows apart (a held jump clears 3)
    g.run(7, 11, 41, '=')
    g.put(9, 40, 'o')
    g.run(13, 17, 38, '=')
    g.put(15, 37, 'o')
    g.run(19, 23, 35, '=')
    g.put(21, 34, 'p')                     # a Weepcap on the third ledge
    g.run(3, 6, 38, '%')                   # a crumbling side ledge off the first, sigil 1 on it
    g.put(4, 37, '1')
    # -- the vine up the right side, rows 23-35, to the altar shelf (row 22)
    g.col(25, 22, 35, '{')
    g.put(25, 28, 'i')                     # a Creepbone on the vine
    g.put(25, 31, '8')                     # a glowfruit on the vine
    g.run(13, 24, 22, '#')                 # the altar shelf (stand row 21)
    g.run(13, 24, 23, '#')
    g.put(17, 21, 'K')
    g.put(21, 21, 'o')
    # -- the lift: 3 wide at x 9-11, drawn at row 18 (sweeps rows 15-21)
    g.put(9, 18, '|||')
    g.put(10, 13, 'o')
    # -- the upper climb
    g.run(3, 7, 12, '=')                   # off the lift's top, up and left
    g.put(4, 11, 'o')
    g.run(9, 13, 9, '=')
    g.put(11, 8, 'o')
    g.put(12, 6, '2')                      # sigil 2 over the second ledge
    g.run(16, 18, 6, '=')                  # into the belfry
    g.run(19, 27, 6, '#')
    g.put(21, 5, 'a')                      # a Bonebow under the bell
    g.put(25, 5, 'E')
    g.put(2, 9, 'c')
    # -- sigil 3: a side room off the vine's left (leap from the vine)
    g.run(18, 21, 28, '=')
    g.put(19, 27, '3')
    return g.out()


T_ROWS = tower()

LEVELS.append({
    'id': 'lab-2', 'name': 'The Bone Tower', 'subtitle': 'lab-2 (tall prototype)', 'music': 'orchard',
    'theme': 'orchard', 'area': 13, 'world': '3',
    'hints': ['A tower. The bell is at the top'],
    'rows': T_ROWS,
})


# ============================================================ lab-3: the shaft descent

def shaft():
    W, H = 30, 46
    g = Grid(W, H)
    g.fill(0, W - 1, 0, 0, '#')            # the roof
    g.fill(0, 1, 0, H - 1, '#')
    g.fill(W - 2, W - 1, 0, H - 1, '#')
    g.fill(0, W - 1, H - 2, H - 1, '#')    # the bottom (rows 44-45)
    # -- 1. the start shelf under the roof (stand row 3); walk off its end
    g.run(2, 10, 4, '#')
    g.put(3, 3, 'P')
    g.put(6, 3, '@')
    g.put(2, 2, 'c')
    # -- 2. a ledge below to the right; an icicle under the shelf's end (an
    #       icicle hangs from stone, not a ledge: test_core's placement rule)
    g.run(13, 18, 8, '=')
    g.put(15, 7, 'o')
    g.put(9, 5, 'V')
    # -- 3. a frosted (slick) ledge further down and right, a Tickwind on it
    g.run(21, 26, 12, '_')
    g.put(25, 11, 'j')
    g.put(24, 9, '2')                      # sigil 2 over it
    g.put(27, 10, 'c')
    # -- 4. a vine hanging in the shaft (leap left onto it, slide down)
    g.col(17, 14, 24, '{')
    g.put(17, 19, '8')                     # a glowfruit on the vine
    g.put(17, 13, '1')                     # sigil 1 at its top
    # -- 5. the altar landing (row 27, stand row 26), a hole at x 19-21
    g.run(2, 18, 27, '#')
    g.run(22, 27, 27, '#')
    g.put(5, 26, 'K')
    g.put(9, 26, 'o')
    g.put(2, 24, 'c')
    g.put(25, 26, 'e')                     # a Frostbuckle past the hole
    # -- 6. the lift down through the hole: x 19-21, drawn at row 30 (tops rows 27-33)
    g.put(19, 30, '|||')
    # -- 7. a ledge left of the lift's bottom, then one lower; a spike bed
    #       under the lift and the right side (step off the lift blind: spikes)
    g.run(10, 15, 35, '=')
    g.put(12, 34, 'o')
    g.put(13, 28, 'V')                     # an icicle under the landing, over that ledge
    g.run(3, 7, 39, '=')
    g.put(5, 38, 'o')
    g.put(27, 38, 'c')
    # (the first draft's bed ran x 16-26 in one: a slip off the frosted ledge's
    # right end, or the frostbuckle side, fell down the right wall into a corner
    # walled off by 11 tiles of spikes, a soft-lock the autoplay bot found; now
    # two 3-wide beds with an island, so the bottom's right side leads back)
    g.run(17, 19, 43, '^')
    g.run(22, 24, 43, '^')
    g.put(2, 41, 'c')
    g.put(6, 43, 'q')                      # a Spurwheel on the bottom
    g.put(8, 42, '3')
    g.put(12, 43, 'E')
    return g.out()


S_ROWS = shaft()

LEVELS.append({
    'id': 'lab-3', 'name': 'The Clock Shaft', 'subtitle': 'lab-3 (tall prototype)', 'music': 'carillon',
    'theme': 'clockface', 'area': 18, 'world': '4', 'tick': '0.536', 'look': 'down',
    'hints': ['A shaft. The bell is at the bottom'],
    'rows': S_ROWS,
})


def build(entry):
    rows = entry['rows']
    e = {k: v for k, v in entry.items() if k != 'rows'}
    return common.write(entry['id'], common.header_of(e, rows), rows)
