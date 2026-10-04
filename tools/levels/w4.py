"""World 4, the Frozen Carillon (WL4): 4-1 to 4-4, with an altar every 85
tiles or less along the route (spec 3.1; 3-5 altars in a regular level, two
in the boss level). The verb is keeping time: wax-ice, rime, icicles, gear
belts, cogs, pendulum weights and swing ledges, all on one tick (0.536 s,
the carillon's beat; features/clockwork.gd). The drawing inside each section
is this module's (see common.py for the format).

Build 2 re-cut the regular levels, each its own shape (the author's
choices): 4-1 a stair up (24 rows, three landings), 4-2 a fold-back loop
(24 rows, two storeys, the bell over the start), 4-3 a hall played right to
left (mirrored whole). Each declares its tables (roster, threat, roles, its
twist or lesson card, its forced Anointed, 4-3's sealed duel), and the
world's rules across them hold: the threat ramps 4-1 < 4-2 < 4-3, no two
share their landmarks, the fodder ceiling falls (common.world_tables).

Rules this world is laid out to (tests/test_w4.gd holds them):
  - ice slides 134 px (4.2 tiles) from a run (the owner's feel lab, round 2):
    every required ice landing is 3 tiles or more in 4-1 and 4-2 (2 from
    4-3), lone ice blocks are for the star routes only, and no required stop
    on ice is closer than 5 tiles to a pit's edge (waits are on stone);
  - rime is never a required floor (the bot reaches everything with rime
    as air, and with rime solid until he leans on it from firm ground);
  - the first cogs (4-2 ES_COG) run over a sunken floor, the first swings
    (4-3 WT_SWING) and the weights on the ice bridge (WT_WEIGHTS2) over thorn
    beds, never pits; nothing else within 8 tiles of a feature or monster
    taught (spec 0.3 rule 3);
  - every Tickwind on ice charges into a wall (dizzy), never off an edge;
  - nothing that swings or turns passes through the level: a weight's bob
    (r 18) and rod over +-50 deg, a swing ledge over +-40 deg, a cog's
    teeth over a full turn (a 64 px tooth on the 96 px ring reaches 128 px,
    so solids stand 144 px from a hub at tooth height);
  - no weight knocks him toward a pit edge on Dusk (played for real);
  - stone every 14 tiles or less over a pit (a tile last_safe records;
    belts, frosted ledges and thin ice aren't);
  - a Spurwheel rolls round a closed outline (a box hung free, or a pillar
    in a pit), never along the level's floor to an altar or the arena, and
    clear of where a jump off a cog's leading tooth comes down;
  - a Dread's lair is off the main path in 4-1 and 4-2 (spec 4.6): the way on
    passes over or under it; 4-3's is on it, a sealed duel (room:, the
    Grindstone's hall, altar 5 at the door he comes in by);
  - one keeper nook in each regular level (spec 3.1, 3.5.3): 4-1 Stampede
    (RS_ALTAR3), 4-2 Grave Step (ES_GUARD), 4-3 Ledge Grab (WT_VAULT2);
  - each level's Story.INSCRIPTIONS line (none in 4-2) stands on a sign; the
    features teach themselves by Hollin's first-time barks (clockwork.gd),
    and 4-4's only other sign is the Tinker's rule at his door.

Thin ice (%, v2's crumble) keeps the crumble's grip (level_data.gd gives it
no F_SLICK): it's the timing verb, not the slide, and a slick strip before a
pit would stack the two (RS_THIN).
"""
import os

import common
from common import block, T_OPEN

# 4-2's silver bell opens 4-S (WLS builds it): as 3-3's (w3.py SECRET_3S), the
# bell, the loft over the mainspring's vent, the vent's false stone and the
# level's `secret:` header are written only once game/levels/4-S.txt is in
# the build (WLS re-runs make_levels then), so a build without 4-S has no
# bell to a level that isn't there.
# WAXBY_W4_SECRET=1 writes them anyway.
SECRET_4S = os.path.exists(os.path.join(common.OUT, '4-S.txt')) or os.environ.get('WAXBY_W4_SECRET') == '1'

# Build 2's tables (common.world_tables, at the end; w3.py says what a row
# holds): written as each regular level's roster: and threat: headers,
# checked as it's written and held by tests/test_w4.gd. The re-cut's (the
# spec's per-level rosters): 4-1 brings in the Tickwind with the Hoarowl
# and the Spurwheel, 4-2 adds the Frostbuckle and a Rattlehound guest, 4-3
# only mixes; the threat ramps 10.0, 11.5, 13.0 (4-2's Drummer Tock and
# 4-3's two named Anointed counted at x2.5), the fodder ceiling falls.
ROSTER = {
    '4-1': {'headline': ['tickwind'], 'support': ['hoarowl', 'spurwheel', 'bonebow', 'bat'], 'guest': ['rootling'],
            'rattle_max': 2, 'fodder_max': 0.85, 'count': 22},
    '4-2': {'headline': ['frostbuckle', 'spurwheel'], 'support': ['tickwind', 'hoarowl', 'bat'], 'guest': ['rattlehound'],
            'rattle_max': 1, 'fodder_max': 0.75, 'count': 17, 'stamps': ['buckle_on_belts']},
    '4-3': {'headline': ['hoarowl', 'frostbuckle', 'tickwind'], 'support': ['spurwheel', 'bonebow', 'bat'],
            'guest': ['rattlehound', 'hollow_helm'], 'rattle_max': 1, 'fodder_max': 0.65, 'count': 20, 'stamps': ['owl_watch']},
}
THREAT = {'4-1': 10.0, '4-2': 11.5, '4-3': 13.0}
MAX_GAP = 85                 # tiles between checkpoints (spec 3.1, World 4)

LEVELS = []

INSCRIPTIONS = {
    '4-1': ['Wind at eleven. Oil at half past. NEVER be late. — T.'],
    '4-2': [],
    '4-3': ['I was one minute late. If I hold it, I never was. — T.'],
    '4-4': ['Hold it. Hold it. Hold it. — T.'],
}

# ============================================================ 4-1 The Rime Stair
# Area 18, theme clockface. A stair up (24 rows): three landings rising
# from the bottom left to the top right (floors on rows 22, 17 and 13: the
# sections placed at dy 9, 4 and 0), joined by two flights, so every ice run
# ends at the next riser (walls stop what slides: the lesson card's line).
# The low landing: First Ice into a wall, a lone Tickwind in a stone pocket
# between two walls, the Rime Door and altar 1 with Tickwell's note. The
# first flight climbs under the Icicle Vaults to the Owl's Landing (a
# Hoarowl sweeps the rime stair's peak), altar 2 past it and the walled rink
# for Three on the Ice. The second flight is the Chimes (the Spurwheel
# lesson round its hung box, an ice ramp up under icicles). The top landing
# is the high gallery: the vault, altar 3 and the Stampede nook, the
# thin-ice pits with a Spurwheel on their pillar, Sergeant Sprocket's rink
# below the walkway (optional), the exit altar and the bell past the ice
# shelf, with its Tickwind pair under the star route (sigil 3).

H41 = 24     # 4-1's rows
LOW, MID, TOP = 9, 4, 0    # where each landing's sections sit (dy: floors on rows 22, 17, 13)

RS_START = block('''
 0|##################
 1|##################
 2|..................
 3|..................
 4|..................
 5|..................
 6|..................
 7|..................
 8|..................
 9|..................
10|.....c.......c....
11|.............###..
12|.P...........###..
13|###IIIIIIIIII#####
14|##################
''')

# First Ice twisted over two pits, frosted ledges over them (embers); the
# last ice ends at a riser over a stone pocket a row under the next floor,
# where the lone Tickwind marches: its charge, either way, ends at a wall
# (dizzy), never at a pit's edge. Nothing else within 8 tiles of it.
RS_SLIDE2 = block('''
 0|##############################
 1|##############################
 2|..............................
 3|..............................
 4|..............................
 5|..............................
 6|..............................
 7|..............................
 8|..........o.o.....o.o.........
 9|.........____.....____........
10|....c..........c........c.....
11|..............................
12|IIIIIIII..IIIIIIIII..IIII.....
13|########..#########..####...j.
14|########..#########..#########
''')

# Rime taught: a door under a stone stub (no way over it); a frost lamp on
# a step (an old verb: a lit lamp melts rime within 2 tiles) under a rime
# plug in the roof, too high to lean on, with embers in the niche above it:
# light the lamp, jump up; then a rime floor over an ember hollow you hop out
# of (nothing else is within 8 tiles of the first door). Altar 1 on its far
# stone, with Tickwell's note (the level's inscription).
RS_RIME_K = block('''
 0|##############################
 1|##############################
 2|##############################
 3|##############################
 4|##############################
 5|##############################
 6|############ooo###############
 7|############...###############
 8|..........#.ZZZ...............
 9|..........#...................
10|....c.....Z..L......c.......c.
11|..........Z.###.##ZZZ##.......
12|..........Z.###.#.oooo#..K..@.
13|##############################
14|##############################
''')

# The first flight (drawn 24 rows tall: the low floor on row 22, the middle
# one on row 17), up under the Icicle Vaults: an ice run under the low
# vault's icicles into a 3-row riser, an ice run under the hanging vault's
# into a 2-row step (stopping under one is what gets you hit; the riser
# stops the slide). A Flit roosts in the rafter gap between the vaults, a
# Rattle waits on the top step.
RS_ICESTAIR = block('''
 0|##############################
 1|##############################
 2|##############################
 3|##############################
 4|##############################
 5|##############################
 6|##############..##########....
 7|##############..##########....
 8|##############..##########....
 9|##############..##########....
10|##############..##########....
11|#############...##########....
12|#############...##########....
13|#############.b.##########....
14|#############.....V..V..V.....
15|#############.................
16|#############..............s..
17|.....V..V..V...............###
18|...........................###
19|..............##IIIIIIIIIII###
20|..............################
21|..............################
22|##IIIIIIIIIIII################
23|##############################
''', H41)

# The Owl's Landing: the rime stair (ice steps and a frosted ledge up and
# down) with a Hoarowl on a bracket over its peak, sweeping the steps (seen,
# and three icicles fall where he stands); sigil 1 behind a rime plug in the
# peak's riser (lean on it from the step below); a Bonebow on the far step.
RS_STAIR2 = block('''
 0|##############################
 1|##############################
 2|.................u............
 3|.................##...........
 4|...............o.o............
 5|..............................
 6|..............IIIII...........
 7|..........___.Z..II...........
 8|..............Z.1II..a........
 9|.........IIIII###IIIIIII......
10|.........IIIIIIIIIIIIIII....c.
11|....IIIIIIIIIIIIIIIIIIIIIIII..
12|....IIIIIIIIIIIIIIIIIIIIIIII..
13|##############################
14|##############################
''')

# Altar 2 past the owl, then Three on the Ice (the ice_to_wall set piece,
# drawn by hand: it needs the rink): a pair of Tickwinds 2 tiles apart on
# stone, then a rink of ice a row down, walled at both ends, with three on
# it. Each charges when it sees him and slides into a wall, dizzy (stomp it
# then; a Perfect Guard bowls the leader into the rest). Out over the far
# wall.
RS_TICKWIND_K = block('''
 0|############################
 1|############################
 2|............................
 3|............................
 4|............................
 5|............................
 6|............................
 7|............................
 8|............................
 9|............................
10|....c...........c.......c...
11|..........................##
12|....K..j.j................##
13|##########.....j..j..j....##
14|##########IIIIIIIIIIIIIIII##
''')

# The second flight, the Chimes: the Spurwheel taught, rolling round a stone
# box hung a tile over the floor (too low to pass under, so it's a closed
# loop: the wheel never leaves it). Hop the box while the wheel is under it,
# or strike it where it catches at a corner. Nothing else within 8 tiles;
# then an ice ramp 3 rows up under icicles, a Bonebow at its top, and a step
# up onto the top landing.
RS_CHIMES2 = block('''
 0|########################
 1|########################
 2|..............##########
 3|..............##########
 4|..............##########
 5|..............##########
 6|..............##########
 7|................V..V..V.
 8|........................
 9|.....................a..
10|.......q........IIIIIIII
11|......#####.....IIIIIIII
12|................IIIIIIII
13|########################
14|########################
''')

# A frosted vault: false stone on the left face of a block you climb over
# (a ledge, then its roof); inside, a Lidlurk and sigil 2.
RS_VAULT = block('''
 0|######################
 1|######################
 2|......................
 3|......................
 4|......................
 5|......................
 6|.........o.o.o........
 7|......................
 8|.......###########....
 9|.......##........#....
10|....===F.........#....
11|.......F.......2.#....
12|.......F....M....#.s..
13|######################
14|######################
''')

# Altar 3. A row over the vault's roof and 6 tiles past its end, a stone
# shelf holds embers: the keeper nook (Stampede, spec 3.5.3). A running jump
# off the roof comes down 8 px short of it; a Bellfounder in her stride (the
# roof is 11 tiles of stone, room to hit it) makes it by 9 px. From the floor
# it's 6 rows up.
RS_ALTAR3 = block('''
 0|##########
 1|##########
 2|..........
 3|..........
 4|..........
 5|..........
 6|..oo......
 7|..##......
 8|..........
 9|..........
10|..c.....c.
11|..........
12|...K......
13|##########
14|##########
''')

# Thin ice over pits (it cracks, then goes: keep moving), a pillar in the
# pit that a Spurwheel patrols (its top, turning back at each lip: its faces
# run down to the open bottom), an ice lift up to the frozen planter (a
# Rootling and a Tickwind: its charge ends at the planter's wall), a second
# lift down, a Tickwind on the far stone.
RS_THIN2 = block('''
 0|##############################
 1|##############################
 2|..............................
 3|..............................
 4|..............................
 5|..................o.o.o.......
 6|..............................
 7|............................j.
 8|........................||.###
 9|..............||.#.r.j#....###
10|.................######....###
11|...........q.....######....###
12|..........###....######....###
13|####%%%...###....######....###
14|####......###....######....###
''')

# Sergeant Sprocket's rink, below the walkway: an ice floor walled at both
# ends (stun him on the walls). The walkway's gap drops in; steps at the far
# end climb out. A side lair (spec 4.6): the walkway is the way on.
RS_DREAD = block('''
 0|############################
 1|############################
 2|............................
 3|............................
 4|............................
 5|............................
 6|..............o.o...........
 7|............................
 8|#######...###########=======
 9|#######...###########.......
10|##......c.........c.....##..
11|##......................##..
12|##......D...............####
13|##IIIIIIIIIIIIIIIIIIIIII####
14|############################
''')

# The exit altar, at the rink's exit steps; a step up toward the ice shelf.
RS_EXIT_K = block('''
 0|##########
 1|##########
 2|..........
 3|..........
 4|..........
 5|..........
 6|..........
 7|..........
 8|..........
 9|..........
10|...c......
11|..........
12|...K...###
13|##########
14|##########
''')

# The bell, past an ice shelf. The star route: a run-up on the shelf, a lone
# ice block (land and go at once), then sigil 3 high on the right. Under it
# a Tickwind pair on the stone (their charge left ends at the shelf's wall),
# a Bonebow, and a Flit by the bell, out of the star route's reach.
RS_BELL2 = block('''
 0|################################
 1|################################
 2|................................
 3|................................
 4|....................3...........
 5|................................
 6|...c.....c......................
 7|.................I..............
 8|...........................b....
 9|IIIIIIIIIIIIII..................
10|IIIIIIIIIIIIII..................
11|IIIIIIIIIIIIII..................
12|IIIIIIIIIIIIII..j..j..a......E..
13|################################
14|################################
''')

LEVELS.append({
    'id': '4-1', 'name': 'The Rime Stair', 'area': 18, 'theme': 'clockface', 'music': 'carillon',
    'dread': 'Sergeant Sprocket|tickwind|Swift,Twinned', 'tick': '0.536', 'story_start': 'beat_4_1',
    'lesson': 'First Frost|Ice carries you. Walls stop what slides.',
    'roles': 'S C A C C A C V A C D A B',
    'hints': [INSCRIPTIONS['4-1'][0]],
    'height': H41,
    'sections': [(RS_START, LOW), (RS_SLIDE2, LOW), (RS_RIME_K, LOW), RS_ICESTAIR, (RS_STAIR2, MID),
                 (RS_TICKWIND_K, MID), (RS_CHIMES2, MID), (RS_VAULT, TOP), (RS_ALTAR3, TOP), (RS_THIN2, TOP),
                 (RS_DREAD, TOP), (RS_EXIT_K, TOP), (RS_BELL2, TOP)],
})


# ============================================================ 4-2 The Escapement
# Area 19, theme gearworks. A fold-back loop (24 rows): two 12-row storeys,
# the lower run right, the upper back left, and at the far end the turn,
# where a lift and the mainspring carry you up, so the bell hangs right
# over the start and every toll rings from above (the toll twist: every 16
# beats each monster in plain view quickens; fight between the bells). The
# lower storey: belts taught, the First Toll (two Tickwinds a belt carries
# at you), the first cogs over a sunken floor, the loft vault off their
# walkway (sigil 2) and altar 1, the Guard (a Frostbuckle alone on flat
# stone; the Grave Step nook over it), the Flip Floor (belts that reverse
# every 8 beats under Drummer Tock, a cog's tooth to sigil 3) and altar 2.
# The turn: the lift, the mainspring (a tall cog whose top tooth passes the
# 4-S vent) under a Hoarowl. The upper storey, going left: the walkway over
# Sir Hoarfrost's hall (optional), the Great Works (a Frostbuckle between
# the belts, sigil 1 on a cog's ring) and altar 3, the train (cog, belt,
# cog over pits: a fall is a ducking in the quench troughs under them, back
# on the last stone), the mainspring floor (a Rattlehound, a Spurwheel's
# box), the bell.
#
# Each storey is drawn in 15-row sections cropped to its 12 rows (crop: the
# rows cut bare), the upper one's sections as the player meets them, facing
# right, and mirrored into place (it's played right to left). Every cog hub,
# weight and swing stands in a column of its own (cog_phase is keyed by
# column), and the flip floor's belt_flip columns hold no belt upstairs.

H42 = 24     # 4-2's rows: the upper storey 0-11 (its floor rows 10-11), the lower 12-23 (rows 22-23)
CUT42 = 3    # each storey's section rows 3-14 (rows 0-2 cut)


def storey(*sections):
    """A storey of 4-2: its sections joined, each cropped to rows 3-14."""
    return common.join(*[common.crop(s, CUT42) for s in sections])


# -------------------------------------------------- the lower storey (going right)

# Belts taught on flat ground, embers on them.
ES_START2 = block('''
 0|##########
 1|##########
 2|..........
 3|..........
 4|..........
 5|..........
 6|..........
 7|..........
 8|..........
 9|..........
10|.....c....
11|..........
12|.P...o.o..
13|###>>>>>>#
14|##########
''')

# A belt toward floor spikes (jump them), then two belts running into each
# other (the second is a slog). The First Toll: two Tickwinds ride the
# second belt at him, and the first toll quickens them.
ES_BELTS2 = block('''
 0|######################
 1|######################
 2|......................
 3|......................
 4|......................
 5|......................
 6|......................
 7|......................
 8|......................
 9|......................
10|...c.............c....
11|......................
12|......^^^......j..j...
13|#>>>>>###>>>>><<<<<###
14|######################
''')

# Cogs taught: two cogs (hubs 8 apart, clockwise, their tops carry you
# right) over a sunken floor. Board a tooth rising past the left walkway,
# ride over the top (embers), step across to the second cog as the teeth
# meet at the sides, step off onto the right walkway. A miss drops you to the
# sunken floor, and the stair on its left takes you back up. The walkways end
# 144 px from the hubs, clear of the teeth (a 64 px tooth on the 96 px ring
# reaches 128 px). The pair turns in phase (both 0), not 45 degrees apart as
# spec 3.2 lays neighbours out: this is the teaching pair, and in phase their
# side teeth meet level, end to end, for the step across. Nothing else
# within 8 tiles (the Flit roosts over the loft). Overhead at its right end
# the first of the train's quench troughs (ES_VAULT_K) hangs, 165 px from
# the second hub.
ES_COG = block('''
 0|############################
 1|############################
 2|............................
 3|........................#:::
 4|..........o.o.....o.o...#:::
 5|........................####
 6|............................
 7|............................
 8|...........O.......O........
 9|...####.................####
10|...####.................####
11|########................####
12|########................####
13|############################
14|############################
''')

# The loft: the first cogs' walkway runs on as the roof of a gear housing,
# and its far face is false stone; inside, a Lidlurk and sigil 2. A Flit
# roosts over it. Altar 1 on the floor past it. Overhead, under the train's
# two pits (the upper storey's), the works' quench troughs: cold water a
# fall from the train lands in (a ducking, a share of life, and back on the
# train's last stone, as a strip's pit), walled and floored so the lower
# storey never climbs into them.
ES_VAULT_K = block('''
 0|##################
 1|##################
 2|..................
 3|::::::###::::::::#
 4|::::::###::::::::#
 5|##################
 6|..b...............
 7|.......o.o.o......
 8|..................
 9|##########........
10|#...2....F........
11|#........F....c...
12|#......M.F..K.....
13|##################
14|##################
''')

# Frostbuckles taught on flat stone: the ice cracks along the floor show
# where its spikes will rise (jump the line). Over the hall's start a gear
# housing hangs 5 rows up with embers on it: the keeper nook (Grave Step,
# spec 3.5.3). A jump stops 45 px short, and there's no wall to cling to;
# the Sexton's bone ledge carries him up.
ES_GUARD = block('''
 0|##################################
 1|##################################
 2|..................................
 3|..................................
 4|..................................
 5|..................................
 6|..................................
 7|......oo..........................
 8|......##..........................
 9|..................................
10|....c.............c...............
11|..................................
12|................e.................
13|##################################
14|##################################
''')

# The Flip Floor (belt_flip): a 20-tile run of belts walled at both ends,
# reversing every 8 beats (so every toll lands on a flip), Drummer Tock (an
# Anointed Tickwind, Warded: a stomp from behind for his motes) and two
# Tickwinds marching on it. Sigil 3: from the cog's top tooth to a lone
# block, then across to the sigil (the star route). Altar 2 past the far
# wall.
ES_FLIP_K = block('''
 0|##################################
 1|##################################
 2|..................................
 3|..................................
 4|...................3..............
 5|................#.................
 6|..................................
 7|..................................
 8|..........O.......................
 9|..................................
10|..##....c...........c...##........
11|..##....................##........
12|..##..j..j..j...........##..K.....
13|####>>>>>>>>>>>>>>>>>>>>##########
14|##################################
''')

# -------------------------------------------------- the upper storey (going left; drawn facing right)

# Sir Hoarfrost's hall, a side lair (spec 4.6): flat, with two ledges over
# his spike lines, under a stone walkway that is the way on (up two ledges
# from the floor where the mainspring lets you off, a Hoarowl watching the
# shaft from its edge). He can't see him up there (a Frostbuckle looks 80 px
# up at most; the walkway is 128 px over his floor); the gap in the walkway
# drops in, and the hall's open end lets out onto the works' floor.
ES_DREAD2 = block('''
 0|############################
 1|############################
 2|............................
 3|............................
 4|............................
 5|............................
 6|............o.o.o...........
 7|............................
 8|............................
 9|....=#########...###########
10|.....#......................
11|..==.#......................
12|.u...#..====.D....====......
13|############################
14|############################
''')

# The great works: a clockwise cog and a counter-clockwise one meshing at
# their sides over the floor; sigil 1 over the second's top tooth: ride it
# round. Under them the buckle_on_belts stamp: a Frostbuckle on the stone
# between the belts, two Tickwinds riding the first belt at it, so its spike
# line runs while the belt carries you toward it. Altar 3 past the second
# belt.
ES_WORKS0 = block('''
 0|####################################
 1|####################################
 2|....................................
 3|....................................
 4|..................1.................
 5|....................................
 6|....................................
 7|....................................
 8|..........O.......Q.................
 9|....................................
10|...c.......................c........
11|....................................
12|............................K.......
13|##>>>>>>>##########<<<<<<<##########
14|####################################
''')
ES_WORKS2 = common.stamp(ES_WORKS0, 'buckle_on_belts', 12, 12)

# The train: from the floor past a low box hung a tile off it that a
# Spurwheel rolls round (it can't leave it), board the first cog, ride its
# top onto the belt on the middle pillar (it carries you onto its stone end),
# time the second cog from there, and the last belt feeds onto a 3-tile ice
# landing, so you slide off its end with its speed (down onto stone). Its
# pits drop into the quench troughs under them (ES_VAULT_K): a fall is a
# ducking, a share of life and back on the last stone, as a strip's pit,
# never the long way round again (the review's: a fall cost 150-200 tiles
# on foot). Every solid stands 144 px or more from a hub.
ES_TRAIN2 = block('''
 0|##################################
 1|##################################
 2|..................................
 3|..................................
 4|.......o.o...........o.o..........
 5|..................................
 6|..................................
 7|..................................
 8|........O...........O.............
 9|..q..........>>#.........>>>III...
10|.###.........###.........######...
11|.###.........###.........######...
12|.............###.........######...
13|#####........###.........#########
14|#####........###.........#########
''')

# The mainspring floor: a Rattlehound on the stone, and a Spurwheel rolling
# round a low box hung a tile off the floor (too low to pass under).
ES_MAINFLOOR = block('''
 0|##############################
 1|##############################
 2|..............................
 3|..............................
 4|..............................
 5|..............................
 6|..............................
 7|..............................
 8|..............................
 9|..............................
10|....c.........q.....c.........
11|.............###..............
12|.....m....................K...
13|##############################
14|##############################
''')

# The bell, right over the start.
ES_BELL2 = block('''
 0|##################
 1|##################
 2|..................
 3|..................
 4|..................
 5|..................
 6|..................
 7|..................
 8|..................
 9|..................
10|....c.......c.....
11|..................
12|....j..s......E...
13|##################
14|##################
''')

# -------------------------------------------------- the turn (24 rows)

# The far end: a lift up from the lower floor to the mainspring, a tall cog
# whose rising teeth carry you up to the upper storey (jump off left onto
# its floor; the Hoarowl on its edge sweeps the shaft). Its top tooth passes
# a vent in the roof (false stone, the secret exit): bonk it open from the
# apex, jump up through it, and the silver bell's arch is in the loft above
# (it opens 4-S). The hub stands 144 px clear of every solid (the upper
# floor's end, the loft, the wall), and the level's edge is stone.
ES_TURN = block('''
 0|##########
 1|##########
 2|##########
 3|##########
 4|##########
 5|...#.....#
 6|...#...S.#
 7|...#F#####
 8|.........#
 9|.........#
10|.........#
11|.........#
12|....O....#
13|.........#
14|.........#
15|.........#
16|.........#
17|.........#
18||||......#
19|.........#
20|.........#
21|.........#
22|##########
23|##########
''', H42)

if not SECRET_4S:
    for y in (5, 6):
        ES_TURN[y] = ES_TURN[y][:3] + '#' * 7
    ES_TURN[7] = ES_TURN[7].replace('F', '#')

ES_UPPER = storey(*[common.mirror_rows(s) for s in (ES_BELL2, ES_MAINFLOOR, ES_TRAIN2, ES_WORKS2, ES_DREAD2)])
ES_LOWER = storey(ES_START2, ES_BELTS2, ES_COG, ES_VAULT_K, ES_GUARD, ES_FLIP_K)

ESCAPEMENT = {
    'id': '4-2', 'name': 'The Escapement', 'area': 19, 'theme': 'gearworks', 'music': 'carillon',
    'dread': 'Sir Hoarfrost|frostbuckle|Warded,Echoing', 'tick': '0.536', 'story_start': 'beat_4_2',
    'twist': 'toll',
    'roles': 'S C C VA C A C D A C A B',
    # (each (section, dx) as drawn: a mirrored one's cog turns the other way, its phase 1 - turns)
    'cog_phase': {(ES_COG, 11): 0.0, (ES_COG, 19): 0.0, (ES_FLIP_K, 10): 0.0, (ES_TURN, 4): 0.0,
                  (ES_WORKS2, 10): 0.0, (ES_WORKS2, 18): 0.125, (ES_TRAIN2, 8): 0.0, (ES_TRAIN2, 20): 0.0},
    'belt_flip': [(common.span(ES_FLIP_K, 4, 23), 8)],
    'anoint': [(ES_FLIP_K, 9, 12, 'Warded', 'Drummer Tock')],
    'rows': common.join(common.stack(ES_UPPER, ES_LOWER), ES_TURN),
}
if SECRET_4S:
    ESCAPEMENT['secret'] = '4-S'
LEVELS.append(ESCAPEMENT)


# ============================================================ 4-3 The Hall of Weights
# Area 21, theme icebells. Played right to left (its sections are drawn
# left to right, as a player facing right meets them, and the level is
# mirrored whole: 'mirror', written facing: left; each phase turns with it).
# A weight over flat ground (go as it swings away) and altar 1 at once, with
# Tickwell's note (Cold Altars: the dry twist's frost-blue flame); three
# weights over a frosted-ledge bridge above a thorn bed; swings taught over
# a thorn bed (they meet in the middle); the vault behind a weight's slot
# (the Ledge Grab nook); the Owl Hall (Brother Clapper over an ice hall and
# a Tickwind squad); swing, weight, swing over pits; rime doors behind
# weights; the clock wall you climb by riding a cog and a swing (sigil 1
# beside the highest swing); weights over an ice floor to Dame Pendula; the
# Grindstone's hall, a duel that seals until he falls (altar 5 at its
# door; sigil 3's tight route over his box); the tolling bells; the bell.

# One weight under a low roof: its 172 px rod clears a standing Waxby at the
# ends of its swing and not at the bottom. Watch it, go as it swings away.
WT_START = block('''
 0|########################
 1|########################
 2|########################
 3|########################
 4|########################
 5|########################
 6|########################
 7|...........Y............
 8|........................
 9|........................
10|....c..............c....
11|........................
12|.P......................
13|########################
14|########################
''')

# Altar 1 right past the single weight, with Tickwell's note (the level's
# inscription): the first lit altar burns frost-blue and mends less (dry).
WT_GATE_K = block('''
 0|##########
 1|##########
 2|##########
 3|##########
 4|##########
 5|##########
 6|##########
 7|..........
 8|..........
 9|..........
10|...c......
11|..........
12|..K...@...
13|##########
14|##########
''')

# Three weights over a frosted-ledge bridge above a thorn bed (knockback runs
# along the bridge; fall off and you jump back up through it). Wait on the
# plain-ledge pads between them, where the bobs pass overhead. A Tickwind
# pair holds the stone at the far end.
WT_WEIGHTS2 = block('''
 0|##############################
 1|##############################
 2|##############################
 3|##############################
 4|.....Y........Y........Y......
 5|..............................
 6|..............................
 7|.........c........c...........
 8|..............................
 9|..........................j.j.
10|.##______==_______==______####
11|###.......................####
12|###^^^^^^..^^^^^^^..^^^^^^####
13|##############################
14|##############################
''')

# Swing ledges taught over a thorn bed: board the first as it comes to the
# near end of its swing, ride it out; the two swing half a swing apart, so
# they meet in the middle: step across, ride the second, jump off at its far
# end. The Flit roosts low on the far stone, 7 tiles past the second swing:
# it only swoops once he's landed there (never at a rider above it).
WT_SWING = block('''
 0|############################
 1|############################
 2|############################
 3|############################
 4|############################
 5|............................
 6|............................
 7|............................
 8|............................
 9|...........................b
10|#####...TTT.......TTT...####
11|#####...................####
12|#####^^^^^^^^^^^^^^^^^^^####
13|############################
14|############################
''')

WT_ALTAR2 = block('''
 0|##########
 1|##########
 2|##########
 3|##########
 4|##########
 5|..........
 6|..........
 7|..........
 8|..........
 9|..........
10|..c.......
11|..........
12|...K......
13|##########
14|##########
''')

# The vault behind a weight's slot: a slot to jump with a weight swinging on
# its far lip (over stone, so its rod is 172 px: its bob clears a standing
# head at the ends, and the keeper nook and the vault's wall by 26 px); the
# vault's left wall is false stone, and behind it a Lidlurk and sigil 2.
# The keeper nook (Ledge Grab, spec 3.5.3: "a weight-pit lip 10 px short"):
# a shelf by the slot, 4 rows up (a jump from the floor stops 12.6 px short
# of it), embers on it, a lip of roof over the one-tile step beside it. From
# the step a jump bonks the lip and stops his feet 6 px under the shelf's
# top, which the Candleknight's grab (12 px) takes and no one else can stand
# on; walk off its far end to drop back to the floor.
WT_VAULT2 = block('''
 0|######################
 1|######################
 2|######################
 3|######################
 4|######################
 5|######################
 6|######################
 7|.#........Y...........
 8|..oo..................
 9|..##..................
10|................######
11|................F....#
12|.#..............F.2M.#
13|#######..#############
14|#######..#############
''')

# The Owl Hall (the owl_watch stamp: a Hoarowl on its bracket over two
# Tickwinds, 3 rows down): Brother Clapper, an Anointed Hoarowl (Twinned),
# on a bracket of ledge sweeps a long stone hall hung with icicles, a ledge
# over him to stomp him from, and its far half a belt (the works' floor,
# 4-2's) that carries its three Tickwinds to the far wall. Spotted, his
# alarm drops icicles and the squad charges, alerted, against the belt that
# carries him at them: the exam mixes the stair's owl and icicles with the
# escapement's belts (the review: a walled ice rink was 4-1's Three on the
# Ice again).
WT_OWLHALL0 = block('''
 0|################################
 1|################################
 2|################################
 3|################################
 4|################################
 5|################################
 6|################################
 7|.......V.............V.....V....
 8|..............===...............
 9|................................
10|................................
11|..............===............###
12|.............................###
13|###....................j.....###
14|################>>>>>>>>>>>>>###
''')
WT_OWLHALL = common.stamp(WT_OWLHALL0, 'owl_watch', 15, 10)

WT_ALTAR3 = block('''
 0|##########
 1|##########
 2|##########
 3|##########
 4|##########
 5|..........
 6|..........
 7|..........
 8|..........
 9|..........
10|..c.......
11|..........
12|...K......
13|##########
14|##########
''')

# Swing, weight, swing over pits: step off the first swing into the
# middle landing's left dip, cross the raised middle when the weight is
# away, wait in the right dip (the weight's bob passes over a Waxby standing
# in either: 2 tiles each, a tile below the middle), board the second swing
# from it as both swing left together, ride it to the far landing. A
# Hoarowl watches from its bracket over the far landing's back, clear of a
# jump off the swing's far end. (No Flit here: over these pits it would
# reach a rider.) A fall never comes back to the raised middle
# (world.safe_vetoed: under a weight's sweep).
WT_PENDULA = block('''
 0|##################################
 1|##################################
 2|##################################
 3|##################################
 4|......###.......Y......###......u.
 5|...............................###
 6|..................................
 7|..................................
 8|..................................
 9|..................................
10|####..TTT.....####.....TTT...#####
11|####........########.........#####
12|####........########.........#####
13|####........########.........#####
14|####........########.........#####
''')

# Rime doors, each with a weight sweeping behind it (spec 3.5.3): lean on
# the door where you stand clear of the swing (Dusk: 0.4 s at full flame,
# 0.8 s near empty, and the melt holds 3 s between visits), then go through
# as the weight swings away. Each weight hangs 6 columns past its door, so
# its bob and rod clear the door and the stone over it by 26 px at the end
# of its swing, and its reach at head height stops short of the next door's
# leaning spot. A Bonebow and a Rattle meet him on the stone before the
# first door.
WT_RIMEWEIGHT = block('''
 0|############################
 1|############################
 2|##########################..
 3|##########################..
 4|##########################..
 5|##########################..
 6|##########################..
 7|......#.....Y.....#.....Y...
 8|......#...........#.........
 9|......#...........#.........
10|......Z...........Z.........
11|......Z...........Z.........
12|.a..s.Z...........Z.........
13|############################
14|############################
''')

# Altar 4, on a flat stone a Frostbuckle holds: jump its spike line.
WT_ALTAR4 = block('''
 0|################
 1|################
 2|................
 3|................
 4|................
 5|................
 6|................
 7|................
 8|................
 9|................
10|..c.........c...
11|................
12|.....e.......K..
13|################
14|################
''')

# The clock wall: ride the cog up from the floor and step off near its top
# onto the first landing (a Tickwind), board the swing from its right end,
# ride it out to the upper landing (the Hollow Helm). Sigil 1 hangs beside
# the highest swing: ride that one out and back. (The first landing stands
# 144 px from the cog's hub, clear of its teeth, and ends where the swing's
# near end dips past it.)
WT_CLOCKWALL = block('''
 0|####################################
 1|####################################
 2|.................###.1..............
 3|....................................
 4|...........................h........
 5|........................########....
 6|........................########....
 7|............j.................##....
 8|...........####..TTT..........##....
 9|......O.......................##....
10|..............................##....
11|..............................##....
12|..............................##....
13|####################################
14|####################################
''')

# Weights over an ice floor: you can't stop under one, so choose your stop
# before you start (the slide is 4 tiles from a run). Nothing waits on the
# ice. Dame Pendula (the pendulum_knight set piece, drawn by hand: it needs
# the weights), an Anointed Frostbuckle (Swift), holds the widened stone
# past them, 14 tiles past the last weight, so her spike line and a bob
# never meet.
WT_ICEWEIGHT2 = block('''
 0|####################################
 1|####################################
 2|####################################
 3|####################################
 4|####################################
 5|####################################
 6|####################################
 7|.......Y.........Y..................
 8|....................................
 9|....................................
10|.....c.......c........c.......c.....
11|....................................
12|...............................e....
13|###IIIIIIIIIIIIIIIIIIIIIII##########
14|####################################
''')

# Altar 5, at the Grindstone's door.
WT_DOOR_K = block('''
 0|##########
 1|##########
 2|..........
 3|..........
 4|..........
 5|..........
 6|..........
 7|..........
 8|..........
 9|..........
10|....c.....
11|..........
12|.......K..
13|##########
14|##########
''')

# The Grindstone's hall, a duel (room: features/sealed.gd): walled at both
# ends down to doorways on the floor, which seal once he's inside and open
# when the Grindstone falls. His 7 x 2 box hangs free (spec 4.6), low enough
# that his whole round is on the glass from the hall's floor (the camera
# leans up for a duel's foe, under its bar: world.gd look_up), so he rolls
# round it and never off it; catch him at the corners (the ledges beside it
# reach its sides, the high one on the left its top). The way on walks under
# it: his wheel on the underside clears a standing Waxby by 30 px. Sigil 3's
# tight route runs over his box: from its top to a lone block, then up to
# the sigil by the far wall.
WT_DREAD2 = block('''
 0|##############################
 1|##############################
 2|##..........................##
 3|##.......................3..##
 4|##..........................##
 5|##..........................##
 6|##...................#......##
 7|##......==...D..............##
 8|##..........#######.........##
 9|##..........#######.........##
10|.........==.........==........
11|..............................
12|..............................
13|##############################
14|##############################
''')

# The bell gallery: the great bells swing as weights on their ropes, under a
# Hoarowl. Wait on the stone between them. Past them a Rattlehound, and a
# Spurwheel rolling round a low box hung a tile over the floor (too low to
# pass under): hop it while the wheel is under it, or strike it at a corner.
WT_TOLLS2 = block('''
 0|##########################
 1|##########################
 2|##########################
 3|##########################
 4|##########################
 5|##########################
 6|##########################
 7|.....Y....u....Y..........
 8|.........###..............
 9|..........................
10|......................q...
11|.....................###..
12|..................m.......
13|##########################
14|##########################
''')

# The bell, past a second Spurwheel's box and a Bonebow.
WT_BELL2 = block('''
 0|##########################
 1|##########################
 2|##########################
 3|##########################
 4|..........................
 5|..........................
 6|..........................
 7|..........................
 8|..........................
 9|..........................
10|.......q..........c.......
11|......###.................
12|...a...............E......
13|##########################
14|##########################
''')

LEVELS.append({
    'id': '4-3', 'name': 'The Hall of Weights', 'area': 21, 'theme': 'icebells', 'music': 'carillon',
    'dread': 'The Grindstone|spurwheel|Burning,Echoing', 'tick': '0.536', 'story_start': 'beat_4_3',
    'mirror': True,
    'twist': 'dry',
    'roles': 'S A C C A V C A C C A C C A D C B',
    # WT_PENDULA's second swing swings with the weight before it (both left
    # together: board it at its near end while the bob is away; the
    # alternation by entity order would put them half a swing apart, and the
    # bob would meet a rider at the swing's near end). (As drawn: the mirror
    # turns it, and writes every other phase out.)
    'weight_phase': {(WT_PENDULA, 23): 0.5},
    'anoint': [(WT_OWLHALL, 15, 10, 'Twinned', 'Brother Clapper'), (WT_ICEWEIGHT2, 31, 12, 'Swift', 'Dame Pendula')],
    'room': [('duel', WT_DREAD2)],
    'hints': [INSCRIPTIONS['4-3'][0]],
    'sections': [WT_START, WT_GATE_K, WT_WEIGHTS2, WT_SWING, WT_ALTAR2, WT_VAULT2, WT_OWLHALL, WT_ALTAR3, WT_PENDULA,
                 WT_RIMEWEIGHT, WT_ALTAR4, WT_CLOCKWALL, WT_ICEWEIGHT2, WT_DOOR_K, WT_DREAD2, WT_TOLLS2, WT_BELL2],
})


# ============================================================ 4-4 The Hour Chamber
# Area 22, theme escapement. Ice, a belt and a cog in one room (the cog is
# the only way over the escapement wall); a stair of weights, rime and
# icicles under a Hoarowl (sigil 1 behind a rime plug under the weight); the
# altar high up; cogs and swings over the shaft (sigil 2 on a lone block
# off the swing's far end), down to the altar at the arena door; the
# Tinker's clock (spec 3.5.4: the hour bells are anchors, the pivot Y under
# the XII beam is the boss's own; sigil 3 on the XII beam).

HC_START = block('''
 0|############################
 1|############################
 2|............................
 3|............................
 4|............................
 5|.......................##...
 6|.......................##...
 7|..................O....##...
 8|.......................##...
 9|.......................##...
10|....c..................##.c.
11|.......................##...
12|.P....j.....s..........##...
13|###IIIIIII>>>>>>############
14|############################
''')

# Up the stair under the weight and the icicles, the Hoarowl watching step
# two. The weight sweeps step one (its bob clears step two's riser by 26 px
# at the end of its swing); sigil 1 is behind the rime plug in step two's
# riser at the far end of the sweep: cross under it between swings, then
# lean on the plug.
HC_CLIMB = block('''
 0|########################################
 1|########################################
 2|########################################
 3|########################################
 4|############################..u..#######
 5|........Y.........V...V...V..###........
 6|........................................
 7|..................................s.....
 8|..............##########################
 9|..............Z..#######################
10|..............Z.1#######################
11|......##################################
12|..j...##################################
13|########################################
14|########################################
''')

HC_ALTAR = block('''
 0|##############
 1|##############
 2|..............
 3|..............
 4|..............
 5|..............
 6|..............
 7|...K...@......
 8|##############
 9|##############
10|##############
11|##############
12|##############
13|##############
14|##############
''')

# Cogs and swings over the shaft: ride the cog over, step off onto the
# pillar, board the swing, ride it out; from its far end a lone block holds
# sigil 2. The way on drops to the landing below, a pillar in the shaft that
# a Spurwheel patrols (top and faces, turning at the shaft's bottom), and
# down onto the floor past it, where a ledge fills the gap at its foot (a
# ledge, not stone, so the wheel's outline stays the pillar's). The
# Tickwinds wait past it, at the arena door's section (8 tiles from the drop),
# and the Bonebow on a shelf over them (out from under the Special button,
# and out of range of the pillar: it shot him there and in the drop). Every solid stands 144 px or more from
# the cog's hub, clear of its teeth. A fall never comes back to the pillar's
# top (world.safe_vetoed: a Spurwheel's outline).
HC_GEARS = block('''
 0|######################################
 1|######################################
 2|......................................
 3|...........................2..........
 4|...........................#..........
 5|......................................
 6|......................................
 7|........O....####..TTT................
 8|####.........####.....................
 9|####.........####........q............
10|####.........####........#####........
11|####.........####........#####........
12|####.........####........#####........
13|####.........####........#####=#######
14|####.........####........#####.#######
''')

# Altar 2, at the arena door: x 131 (spec 3.5.3 lists x 123), 3 tiles from
# the door, as 2-4's rule puts a boss's altar (spec 3.1: "an altar at the
# arena door"); test_w4 holds it within 8 tiles.
HC_DOOR = block('''
 0|##############
 1|##############
 2|..............
 3|..............
 4|..............
 5|..............
 6|..............
 7|..............
 8|....a.........
 9|...===........
10|..c.......c...
11|..............
12|.jj........K..
13|##############
14|##############
''')

# The Tinker of Hours' clock (spec 3.5.4, p_monsters 13.2): the hour bells
# are anchors (XII, IX, III, VI), the two cogs' tops reach toward the XII
# beam, the pivot Y under the beam is the boss's own (still until his P2),
# ice patches in the floor. Sigil 3 on the XII beam.
K_ARENA = block('''
 0|##################################
 1|##################################
 2|##..............................##
 3|##..............+.3.............##
 4|##.............=====............##
 5|##..............Y...............##
 6|##..............................##
 7|##........O.............O.......##
 8|##..............................##
 9|##...+.....................+....##
10|...=====..................=====.##
11|................................##
12|..@.......X......+..............##
13|####IIIIII##########IIIIII########
14|##################################
''')

LEVELS.append({
    'id': '4-4', 'name': 'The Hour Chamber', 'area': 22, 'theme': 'escapement', 'music': 'carillon',
    'boss': 'tinker', 'boss_music': 'tinker', 'tick': '0.536',
    'story_start': 'beat_4_4', 'story_boss': 'boss_4_before', 'story_end': 'boss_4_after',
    'cog_phase': {(HC_START, 18): 0.0, (HC_GEARS, 8): 0.0, (K_ARENA, 10): 0.0, (K_ARENA, 24): 0.5},
    'hints': [INSCRIPTIONS['4-4'][0],
              'Ring the bell the clock shows. Then hit his spring'],
    'sections': [HC_START, HC_CLIMB, HC_ALTAR, HC_GEARS, HC_DOOR, T_OPEN, K_ARENA],
})

# Build 2: each regular level's ROSTER and THREAT rows, and the world's rules
# across them (the ramp, the checkpoints, the section roles).
common.world_tables(LEVELS, ROSTER, THREAT, MAX_GAP)
