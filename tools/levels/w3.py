"""World 3, the Bone Orchard: 3-1 to 3-4 (WL3; spec.md §3.4, p_worlds.md §5).
The verb is climbing: vines ({), rotten vines (}: a run of at most 3 that
snaps 1.4 s after the first catch on Dusk), spore pods (*: a cloud that
dims you) and glowfruit (8: lamplight you knock down; fire for the spores).

Since Build 2 the rules bind, not the spec's x (each level's cast and
threat are its rows of ROSTER and THREAT, its twist and set pieces its
entry's keys); the drawing inside each section is this file's. World 3
reads strip, tower, bowl: 3-1 a strip of 15 rows; 3-2 a tower 36 rows tall,
its gallery's 15-row sections placed on its floor and the Ossuary Wall's
storeys stacked at its far end (common.place, crop, stack); 3-3 a bowl 24
rows deep, each section placed at its height. The rules every section keeps
(tests/test_w3.gd checks them):
  - checkpoints (start, altars, bell) at most 90 tiles apart, 3-5 altars;
  - over a pit, stone (a tile last_safe records) at least every 14 tiles,
    and a root knot after at most 4 vines;
  - vine columns 3-5 apart on a chain; a rotten run at most 3 tall; no
    one-cell vine stubs; a Creepbone only ever on a sound vine (its lane is
    fixed as it spawns: a rotten run would snap from under it);
  - each lantern within 3 tiles of the Weepcap it is there for (its fire
    burns her puffs: test_w3 lights it and watches them burn);
  - a ceiling pod hangs at most 7 rows over the floor under it;
  - every monster appears first in the section that teaches it (Rootling
    BG_MOUNDS, Creepbone BG_LADDER, Weepcap BG_WEEP, Rattlehound HO_HOUND),
    rotten vines first in HO_ROTTEN_K, pods first in HO_SPORES;
  - each level's threat cost within 10% of its THREAT row (9, 10.5 and 12
    per 100 tiles of its route: X-1 to X-3 ramping), its cast what its
    ROSTER row declares;
  - sigil 3 of 3-1 ... 3-3 behind its star route (test_w3 STAR_ROUTES);
  - no blind jumps: every required landing in view before take-off (the
    camera shows about 4.7 rows under a standing hero's feet: a required
    drop is 4 rows or less, or has a step on the way: HW_ALTAR's; 3-3's
    bowl says so, max_drop: 4);
  - in 3-2's wall a fall that gives way lands on a catch floor (a snapped
    rotten run within 10 rows), never at the bottom, and no monster waits
    where it lands (common's catch rules); every landing leads on;
  - from every cell of a vine over a pit or thorns a tapped leap catches or
    lands, never bonks the roof into a fall, and each such vine gives a band
    of 2 rows or more that doesn't fall (test_w3 _test_leap_bands).

Reach, for laying out climbs (player.gd): a jump from beside a floor vine
catches about 3 tiles up; the vine leap (a fresh jump press with a way held)
carries 3.6 tiles back to its own height and about 4 tiles to a tile lower,
so vine to vine is 4 tiles, losing a tile each time (climb between leaps).
A leap rises 2.25 tiles, so from a vine's top cell it bonks a roof less
than 3 rows over it: vines on a chain start 2 rows under their roof (the
bonk still carries a 4-tile leap to the next vine) and 3 where the next
landing is a knot or a crumble. At a vine's top cell, jump held toward a
floor whose top is that cell's row (within 2 tiles) mounts it, with the roof
over the vine open (player._clear_above).
"""
import os

import common
from common import block, crop, stack, T_OPEN

# 3-3's silver bell opens 3-S (WLS builds it): the bell and the level's
# `secret:` header are written only once game/levels/3-S.txt is in the build,
# so a build without 3-S has no bell to a level that isn't there (the attic
# stays, empty; features/orchard.gd shows its updraft on the same rule).
# WAXBY_W3_SECRET=1 writes them anyway (the bot's proof of the attic).
SECRET_3S = os.path.exists(os.path.join(common.OUT, '3-S.txt')) or os.environ.get('WAXBY_W3_SECRET') == '1'

# Build 2's tables (common.world_tables, at the end): each regular level's
# cast (headline kinds placed and the world's own, support, guests from
# earlier worlds, a Rattle cap, the fodder share's ceiling, the count) and
# its threat per 100 tiles (within 10%; X-1 to X-3 ramping), written as its
# roster: and threat: headers, checked as it's written and held by
# tests/test_w3.gd. Build 2's redesign: the spec's casts (3-1 teaches the
# world's own three, 3-2 adds the Rattlehound, 3-3 mixes them all with fewer
# fodder) and its ramp, 9 to 10.5 to 12.
ROSTER = {
    '3-1': {'headline': ['rootling', 'creepbone'], 'support': ['weepcap', 'bat', 'bonebow', 'dripkin'], 'guest': ['skeleton'],
            'rattle_max': 1, 'fodder_max': 0.85, 'count': 22},
    '3-2': {'headline': ['rattlehound'], 'support': ['creepbone', 'rootling', 'weepcap', 'bat', 'bonebow'],
            'guest': ['skeleton', 'hollow_helm', 'gutterwing'], 'rattle_max': 3, 'fodder_max': 0.75, 'count': 19},
    '3-3': {'headline': ['weepcap', 'creepbone', 'rattlehound', 'rootling'], 'support': ['bonebow'],
            'guest': ['thornback', 'gutterwing'], 'rattle_max': 1, 'fodder_max': 0.65, 'count': 20,
            'stamps': ['lane_and_thorn', 'hound_and_mounds']},
}
THREAT = {'3-1': 9.0, '3-2': 10.5, '3-3': 12.0}
MAX_GAP = 90                 # tiles between checkpoints (spec §3.1, World 3)

LEVELS = []

# ============================================================ 3-1 The Bramble Gate
# Area 13, World 3's teaching level (Build 2: a strip, the lesson card "Into
# the Orchard", no rule). The verb first: catch a vine (BG_START), climb up
# and slide down (BG_CLIMB), leap vine to vine over a thorn bed to altar 1
# and Brother Pim's stone (BG_LEAP_K). Then the world's three new monsters
# one at a time, each with room: Rootlings on a flat bed (BG_MOUNDS),
# Creepbones on the vines of a bone ladder over flat floor (BG_LADDER), a
# lone Weepcap by a lantern after altar 2 (BG_WEEP). The dark grove lit only
# by the glowfruit you knock down (BG_GROVE); vines over a real pit for the
# first time, to altar 3 on the bank (BG_TRELLIS_K); the root cellar's vault
# with Mister Mandrake's lair over it (BG_CELLAR_D); the skull lantern's two
# Weepcaps and the bell on its knoll with the star route above (BG_BELL).
# Hardly a Rattle (one at the gate): it plays as the Bone Orchard from the
# first screen.

# The orchard gate: a 4-high bone wall (a held jump clears 3) with a vine in
# front of it, as tall as the wall. Catch it, climb to its top, and holding
# jump toward the wall hauls you up onto it (the mount); a leap off it lands
# there too. A glowfruit hangs over the gate; one Rattle waits past it.
BG_START = block('''
 0|######################
 1|######################
 2|######################
 3|######################
 4|...................8..
 5|......................
 6|......................
 7|...............o.o....
 8|......................
 9|............{.####....
10|....c.......{.####....
11|............{.####....
12|..P....@....{.####..s.
13|######################
14|######################
''')

# A tall vine up to a root shelf (embers, a reliquary to bonk from the
# shelf); a second vine at the shelf's end slides you back down. Nothing
# else: the climb is the lesson.
BG_CLIMB = block('''
 0|##############################
 1|##############################
 2|......?.......................
 3|..............................
 4|.......o.o.o..................
 5|....{########{................
 6|....{########{................
 7|....{........{................
 8|....{........{................
 9|....{........{................
10|....{........{...c............
11|....{........{................
12|....{........{................
13|##############################
14|##############################
''')

# Four vines 4 apart over a thorn bed (20%, not a pit): each leap lands a
# tile lower, so climb between leaps. From the last vine any leap lands on
# the floor past the bed. A Flit and a Bonebow wait past it, then altar 1
# and Brother Pim's stone. The vines start 2 rows under the roof (from their
# top a leap bonked it into the thorns).
BG_LEAP_K = block('''
 0|########################################
 1|########################################
 2|########################################
 3|########################################
 4|........................................
 5|........................................
 6|......{.o.{.o.{.o.{.....................
 7|......{...{...{...{.....................
 8|......{...{...{...{.....................
 9|......{...{...{...{.....................
10|..........................b.........c...
11|........................................
12|.....^^^^^^^^^^^^^^^^........a.....K..@.
13|########################################
14|########################################
''')

# Rootlings taught on a flat bed of tilled soil (no pit): one alone to
# watch, then three on a long strip. The keeper nook: a chimney of two root
# walls (Moth Cling kicks up it) to an ember cache.
BG_MOUNDS = block('''
 0|######################################
 1|######################################
 2|..............................o.o.....
 3|..............................ooo.....
 4|.............................#...#....
 5|.............................#...#....
 6|.............................#...#....
 7|.............................#...#....
 8|.............................#...#....
 9|................?............#...#....
10|.....c..........................c.....
11|......................................
12|............r.......r...r...r.........
13|######################################
14|######################################
''')

# The bone ladder: Creepbones taught over flat floor. Two root steps up and
# two down, too tall to jump (4 rows), each with a vine on its face and a
# Creepbone on each vine: climb while it rests, or knock it off.
BG_LADDER = block('''
 0|################################
 1|################################
 2|################################
 3|................................
 4|................................
 5|..........{#######{.............
 6|..........{#######{.............
 7|..........{#######i.............
 8|..........i#######{.............
 9|....{#####{##############{......
10|....{#####{##############{......
11|....i#####{##############i......
12|....{#####{##############{......
13|################################
14|################################
''')

# Altar 2, then the Weepcap taught alone on flat ground, three tiles past a
# skull lantern: light it, and its fire burns the puffs she sends at you.
BG_WEEP = block('''
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
10|.....c............
11|..................
12|...K......L..p....
13|##################
14|##################
''')

# The dark grove: no sconces, dark by design (no twist). Four glowfruit
# hang under low roots (a jump knocks one down: it lies lit for 30 s), the
# only light. A Dripkin under a root, a Bonebow on a stump shooting from the
# dark over a strip of Rootlings. Sigil 1 on a vine-top shelf.
BG_GROVE = block('''
 0|####################################
 1|####################################
 2|####################################
 3|##......#.........#...#...#.....#...
 4|##......#.........#...#...#.....#...
 5|##..1...#.........#...#...#.....#...
 6|##.{###.#.........#...#...#.....#...
 7|...{....#.........#...k...#.....#...
 8|...{....8.........8.......8.....8...
 9|...{................................
10|...{.........................a......
11|...{.........................##.....
12|...{................r...r....##.....
13|####################################
14|####################################
''')

# Vines over a real pit, strung with bone trellis (crumbling ledges), a
# stone knot every 14 tiles or less, and a root lift at the far end up to
# the bank, where altar 3 stands.
BG_TRELLIS_K = block('''
 0|######################################
 1|######################################
 2|######################################
 3|######################################
 4|......................................
 5|......................................
 6|............o{........o...............
 7|.....{.......{......{......{.......K..
 8|.....{.......{......{......{......####
 9|.....{.......{......{......{.#.||.####
10|.....{..%%%..{..##..{..%%%.{......####
11|..................................####
12|..................................####
13|####..............................####
14|####..............................####
''')

# The root cellar and Mister Mandrake's lair over it, one place: over the
# cellar's mound by its vine and down the far side, its right wall false
# stone (the crack shows in light: a Lidlurk and sigil 2 inside); up the
# next vine through a gap in the roots, the Dread's flat soil room over the
# path (his twins burrow apart). Two Rootlings follow you on.
BG_CELLAR_D = block('''
 0|##################################
 1|##################################
 2|####.....................#########
 3|####.....................#########
 4|####........D............#########
 5|####################{#############
 6|....................{.............
 7|....{...............{.............
 8|....{###########....{.............
 9|....{###########....{.............
10|....{##........#....{.............
11|....{##..2.....F....{.............
12|....{##....M...F....{...r....r....
13|##################################
14|##################################
''')

# The skull lantern between two Weepcaps (light it: its fire burns the puffs
# of both), then the bell on a bone knoll. The star route: a short vine, a
# leap to two lone stones, then sigil 3 at row 3.
BG_BELL = block('''
 0|########################################
 1|########################################
 2|........................................
 3|.............................3..........
 4|........................................
 5|............................#...........
 6|......................{.................
 7|......................{..#..............
 8|......................{.................
 9|..............W.......{.................
10|......................{.................
11|......................{......#######....
12|.........p..L..p......{.r....##.E.##....
13|########################################
14|########################################
''')

LEVELS.append({
    'id': '3-1', 'name': 'The Bramble Gate', 'area': 13, 'theme': 'orchard', 'music': 'orchard',
    'dread': 'Mister Mandrake|rootling|Twinned,Sporebound',
    'story_start': 'beat_3_1',
    'lesson': 'Into the Orchard|Roots follow your steps. Keep moving.',
    'roles': 'S C A C C A C A VD B',
    'hints': ['On a vine, slide up to climb. Arrow and jump to leap',
              'Here lies Brother Pim. He kept the soup warm.'],
    'sections': [BG_START, BG_CLIMB, BG_LEAP_K, BG_MOUNDS, BG_LADDER, BG_WEEP, BG_GROVE, BG_TRELLIS_K, BG_CELLAR_D,
                 BG_BELL],
})


# ============================================================ 3-2 The Hanging Ossuary
# Area 14, World 3's twist level (Build 2: Restless, the fallen rise once:
# in World 3 every ordinary floor kind; strike their remains). A tower 36
# rows tall: a long low gallery along its bottom (its sections placed on
# the level's floor), then the Ossuary Wall at its far end, three storeys
# up to the bell. Along the bottom: the restless opener, a lone Rootling on
# a lit shelf (HO_START); the first vine chain over a pit to altar 1
# (HO_CHAIN_K); the Rattlehound taught in its gallery (HO_HOUND); the skull
# niche's vault (HO_NICHE); spore pods taught in a lit hall (HO_SPORES);
# altar 2 (HO_ALTAR2); the Widow's Spore Hall, Weepcaps under ceiling pods
# with the Widow Cap's grotto drawn over it, up a stair of root ledges, and
# a Hollow Helm at its low door (HO_WEEPCAPS_D); altar 3 at the door of the
# Long Ossuary (HO_DOOR_K), where Brother Clatter, a Sporebound Anointed
# Rattlehound, hunts you down 30 flat tiles while the Rattles you stomped
# get up behind you (HO_GALLERY). The wall (HO_WALL, stacked): pod-hung
# vines in two lanes with a Creepbone on each, under a Bonebow (HO_LANES);
# the first catch floor and altar 4, rotten vines taught over it on the way
# up and the Rotten Spur's two runs up the far wall to sigil 3 (HO_ROTTEN_K);
# the second catch floor, bone ledges past a nest on the pillar to sigil 1,
# and the bell on the top shelf (HO_BELL). Every fall in the wall lands on
# a catch floor, never at the bottom.

# Bone shelves hung on chains over nothing: the first sight of the drop.
# The restless opener: one Rootling alone on the lit floor, nothing within
# 8 tiles. Stomp it, watch its remains glow and twitch, and strike them.
HO_START = block('''
 0|######################
 1|######################
 2|######################
 3|######################
 4|......................
 5|......................
 6|......................
 7|......................
 8|......................
 9|..........c...........
10|....c...........c.....
11|...............==.====
12|..P........r..........
13|##############........
14|##############........
''')

# Five vines 4 apart over the pit, a one-tile root knot after the third
# (stone every 14 tiles), embers on the arcs, two Flits; altar 1 on the far
# bank.
HO_CHAIN_K = block('''
 0|########################################
 1|########################################
 2|########################################
 3|########################################
 4|........................................
 5|............b...........................
 6|.{.o.{.o.{.......{.o.{..................
 7|.{...{...{.......{...{..................
 8|.{...{...{.......{...{..................
 9|.{...{...{.......{.b.{..................
10|.{...{...{...#...{...{..................
11|.{......................................
12|.{..................................K...
13|.........................###############
14|.........................###############
''')

# The Rattlehound taught: a long flat gallery with room to turn and jump
# the pounce. The keeper nook: from the far shelf a Drift glides to the
# embers over the altar.
HO_HOUND = block('''
 0|########################
 1|########################
 2|########################
 3|########################
 4|########################
 5|##############..........
 6|##############..........
 7|##############......====
 8|........................
 9|........?...............
10|.....c...........##.....
11|.................##.....
12|................m##.....
13|########################
14|########################
''')

# A skull niche with a plaster back: up the ledge, over the crypt box,
# and its far wall is false stone (a Lidlurk and sigil 2 inside).
HO_NICHE = block('''
 0|########################
 1|########################
 2|########################
 3|########################
 4|........................
 5|........................
 6|........................
 7|........................
 8|..........######........
 9|..........#....F........
10|......===.#..2.F........
11|..........#....F........
12|..........#.M..F........
13|########################
14|########################
''')

# Spore pods taught in a lit hall: walk into one and watch your light
# shrink; run past the next. A Rootling waits between two.
HO_SPORES = block('''
 0|############################
 1|############################
 2|############################
 3|############################
 4|############################
 5|############################
 6|............................
 7|............................
 8|............................
 9|............................
10|.....c.........c.........c..
11|............................
12|........*.......*..r.*...*..
13|############################
14|############################
''')

# Altar 2, and Old Hobb's stone.
HO_ALTAR2 = block('''
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
10|.....c........
11|..............
12|...K.......@..
13|##############
14|##############
''')

# The Widow's Spore Hall (drawn 20 rows: the grotto over it): Weepcaps,
# and two pods hanging over the steps (a jump there sets them off; a slash
# or a shot from further off pops them first); a Hollow Helm guards the
# low door. Over the hall, up a stair of root ledges, the Widow Cap's
# grotto: dark, with one lantern to light just past the gap you climb in
# by, three tiles from her (its fire clears the clouds she puffs at you).
HO_WEEPCAPS_D = block('''
 0|##################################
 1|##################################
 2|##################################
 3|####................##############
 4|####................##############
 5|####.....D..L.......##############
 6|####======..========##############
 7|#.........########################
 8|#.........########################
 9|#.===.....########################
10|#.........########################
11|..........#######.....#.......####
12|.....===..#######.....#.......####
13|..........#######.....#.......####
14|.............*........*.......####
15|..===.........................####
16|............##.......##...........
17|......p.........r........p...h....
18|##################################
19|##################################
''', 20)

# Altar 3, at the door of the Long Ossuary.
HO_DOOR_K = block('''
 0|##############
 1|##############
 2|##############
 3|##############
 4|##############
 5|##############
 6|..............
 7|..............
 8|..............
 9|..............
10|.....c........
11|..............
12|.....K........
13|##############
14|##############
''')

# The Long Ossuary: 30 flat tiles of bone floor to the foot of the wall,
# three Rattles in its niches and Brother Clatter at its far end (the
# anoint: Sporebound; he bursts into spores when he falls). Stomp the
# Rattles and they get up behind you while he pounces: strike the remains.
HO_GALLERY = block('''
 0|################################
 1|################################
 2|################################
 3|################################
 4|################################
 5|################################
 6|................................
 7|................................
 8|................................
 9|................................
10|....c.........c.........c.......
11|................................
12|...s.....s.....s..........m.....
13|################################
14|################################
''')

# The Ossuary Wall: three storeys of 12 rows, each drawn under 3 rows of
# stone that crop() cuts, stacked (stack) into the tower's last 40 columns.
# The lanes: in from the gallery, two pod-hung vines up through the first
# catch floor, a Creepbone on each (climb one while the other's rests), a
# Bonebow on a shelf by the far wall.
HO_LANES = block('''
 0|########################################
 1|########################################
 2|########################################
 3|#...................{...{..............#
 4|#...................*...{..............#
 5|#...................{...*..............#
 6|....................{...{..............#
 7|....................i...{.......a......#
 8|......c.......c.....{...{......####....#
 9|....................{ooo{..............#
10|....................{...i..............#
11|....................{...{..............#
12|....................{...{..............#
13|########################################
14|########################################
''')

# The first catch floor and altar 4 (no monster on it: a risen one would
# wait where you land). Up the two left lanes (a Creepbone on one) to a
# ledge, then rotten vines taught over the catch floor: two grey runs to a
# tall sound vine up through the gap in the floor over it (a run snaps 1.4 s
# after the catch on Dusk: it drops you on the catch floor, never further).
# The Rotten Spur: two rotten runs up the far wall to sigil 3.
HO_ROTTEN_K = block('''
 0|########################################
 1|########################################
 2|########################################
 3|#....................{.................#
 4|#....................{.................#
 5|#............}.......{.......3.........#
 6|#..{...{###..}...}...{.................#
 7|#..{...{.....}...}...{..........}......#
 8|#..{...{.........}..............}...}..#
 9|#..{...i....c...................}...}..#
10|#..{...{...................c........}..#
11|#..{...{...............................#
12|#..{...{.......K.......................#
13|####################{###{###############
14|####################{###{###############
''')

# The second catch floor, the top: off the vine onto it, up the bone ledges
# past a Gutterwing nest on the pillar (higher ones to sigil 1), onto the
# pillar's top and along the top shelf to the bell, in the middle of the
# wall and 4 rows under its roof (clear of the HUD's corners).
HO_BELL = block('''
 0|########################################
 1|########################################
 2|########################################
 3|########################################
 4|#............................##........#
 5|#...........c................##.....1..#
 6|#............................##........#
 7|#..............E............N##....===.#
 8|#.........############.......##........#
 9|#......................................#
10|#......c................===.....===....#
11|#......................................#
12|#...o.o.o..............................#
13|##################...{##################
14|##################...{##################
''')

HO_WALL = stack(crop(HO_BELL, 3), crop(HO_ROTTEN_K, 3), crop(HO_LANES, 3))

LEVELS.append({
    'id': '3-2', 'name': 'The Hanging Ossuary', 'area': 14, 'theme': 'rootvault', 'music': 'orchard',
    'dread': 'The Widow Cap|weepcap|Warded,Sporebound',
    'story_start': 'beat_3_2',
    'height': 36,
    'twist': 'restless',
    'anoint': [(HO_GALLERY, 26, 12, 'Sporebound', 'Brother Clatter')],
    'roles': 'S A C V C A D A C C A B',
    'hints': ['Here lies Old Hobb. Planted crooked. Grew anyway.'],
    'sections': [(HO_START, 21), (HO_CHAIN_K, 21), (HO_HOUND, 21), (HO_NICHE, 21), (HO_SPORES, 21), (HO_ALTAR2, 21),
                 (HO_WEEPCAPS_D, 16), (HO_DOOR_K, 21), (HO_GALLERY, 21), HO_WALL],
})


# ============================================================ 3-3 The Sporewood
# Area 16, the darkest World 3 theme, World 3's test (Build 2: the Omens
# twist, more of them glow; nothing new taught). A bowl 24 rows deep: from
# the edge of the wood (SW_START) the ground falls away in drops of 3 rows
# through the mist, a Weepcap, a Creepbone and a Rootling in it
# (SW_MIST2), under Old Tatterjaw's run (SW_DREAD), to the floor of the bowl
# (SW_CLEARING): altar 1 at the door of the Clearing, an ambush that shuts
# its doors till its five are down (the Mourner, a Twinned Anointed
# Weepcap, by a lantern under a glowfruit), sigil 3's knots on its thorny
# roof (a leap from the lip of Tatterjaw's run), the fallen trunk's vault
# past its far door. Then the climb out: Sister Thistle, a Swift Anointed
# Thornback, holding the bramble bridge under Creepbones on its vines
# (SW_BRAMBLE2), altar 2 (SW_ALTAR2), the canopy's vines over a pit
# (SW_CANOPY), rotten vines over black sap to altar 3 on its stone island
# (SW_ROTWELL_K), the secret exit up the updraft (SW_UPDRAFT: its silver
# bell opens 3-S once that level is built) and a Rattlehound chasing you
# onto a strip of Rootlings before the bell (SW_BELL2), back at the height
# you started.

# A pod on the floor with a glowfruit over it: jump for the fruit first and
# it falls on the pod (it bursts and the fire takes the cloud at once).
SW_START = block('''
 0|######################
 1|######################
 2|######################
 3|######################
 4|######################
 5|######################
 6|######################
 7|######################
 8|..........8...........
 9|......................
10|......................
11|......................
12|..P..@....*...........
13|######################
14|######################
''')

# The mist, 3 rows down from the wood's edge: a low field of floor pods and
# ceiling pods, three glowfruit, and three kinds at once: a Weepcap in the
# haze, a Creepbone on a vine into the roots, a Rootling.
SW_MIST2 = block('''
 0|####################################
 1|####################################
 2|####################################
 3|####################################
 4|####################################
 5|####################################
 6|........############################
 7|........############{###############
 8|.........8..*.......{.8......*...8..
 9|....................i...............
10|....................{...............
11|....................{...............
12|......*......p......{..*...r........
13|####################################
14|####################################
''')

# Old Tatterjaw's run, 3 rows further down: a long corridor in the roots
# over the path, up a vine, with one ledge to jump his pounce from. Its far
# end is open: the lip over the Clearing, where sigil 3's knots start.
SW_DREAD = block('''
 0|########################
 1|########################
 2|########################
 3|#.......................
 4|#........===............
 5|#.......................
 6|#..............D........
 7|.{####################..
 8|.{####################..
 9|.{......................
10|.{......................
11|.{......................
12|.{......................
13|########################
14|########################
''')

# The floor of the bowl (drawn at the level's 24 rows), 3 rows under the
# run: altar 1 and the gravestone at the Clearing's door. The Clearing
# (columns 14-39, its roof row 12 to its floor) is an ambush: its doors
# grind shut once you're in and open when its five are down, two Rootlings
# in the floor, Creepbones on the two wall vines, and the Mourner by a
# lantern, under a glowfruit hung from a root (knock it onto her clouds).
# Over its roof, thorns, and root knots from the lip of Tatterjaw's run (4
# over the gap, 5 on the roof) to sigil 3 at its far end; the knots lead
# back the way they came. Past its far door, the fallen trunk: over the
# stump, and its near end is false stone (a Lidlurk and sigil 2 inside).
SW_CLEARING = block('''
 0|##########################################################
 1|##########################################################
 2|##########################################################
 3|##########################################################
 4|##########################################################
 5|##########################################################
 6|.......................................###################
 7|.......................................###################
 8|.......................................###################
 9|.......................................###################
10|.....................................3.###################
11|.#...#...#...#^^^#^^^#^^^#^^^#^^^#^^######################
12|..............############################################
13|..............#..........###...........#..................
14|..............#..c........#.........c..#..................
15|..............#...{.......#........{...#..................
16|..............#...{.......#........{...#..................
17|..............#...i.......8........{...#..................
18|..................{................i........##########....
19|......c...........{................{........F........#....
20|..................{................{.....##.F..2.....#....
21|....@....K............rL..p....r.........##.F....M...#....
22|##########################################################
23|##########################################################
''', 24)

# The bramble bridge, the climb out begun 3 rows up: Sister Thistle holds
# the floor under a row of vines while Creepbones lunge from vines 2 and 4
# (going over on the vines is contested too): the lane_and_thorn stamp.
# The keeper nook (Ledge Grab): a root mass hangs over the hall's door,
# with a hollow in it. From the branch ledge under its left end, a jump
# bonks the root lip over the slot (row 5), which stops his feet 6 px short
# of the hollow's floor (row 7): the Candleknight's grab (12 px) hauls him
# in; no one else gets his feet over it. Out through the bone trellis at its
# back, down the shaft to the floor. Only a quirk reaches it (test_w3
# checks both).
SW_BRAMBLE0 = block('''
 0|##############################
 1|##############################
 2|##############################
 3|.####.........................
 4|.####.........................
 5|.#.o#.{...{...{...{...{.......
 6|..oo#.{...{...{...{...{.......
 7|..#%#.{...{...{...{...{.......
 8|..#.#.{...{...{...{...{.====..
 9|..#.#.........................
10|==............................
11|..............................
12|..............................
13|##############################
14|##############################
''')
SW_BRAMBLE2 = common.stamp(SW_BRAMBLE0, 'lane_and_thorn', 14, 12)

SW_ALTAR2 = block('''
 0|##############
 1|##############
 2|..............
 3|..............
 4|..............
 5|..............
 6|..............
 7|..............
 8|..............
 9|.........?....
10|.....c........
11|..............
12|...K..........
13|##############
14|##############
''')

# The canopy, 2 rows up: sound and rotten vines over a pit, a root knot in
# the middle, pods on two vines and a Gutterwing nest. Sigil 1 up in the
# canopy past two pods, a Bonebow on its shelf; a Weepcap under a hanging
# root's glowfruit on the landing stone. The knot is two tiles, the first
# two vines start 2 rows under the roof, the roof over the last vine is
# open (it hauls him onto sigil 1's ledge), and the landing stone reaches a
# tile further out: a leap off the last vine lands a tile clear of the
# edge.
SW_CANOPY = block('''
 0|########################################
 1|#########################......#########
 2|.........................{..1a......###.
 3|.........................{====......###.
 4|.....{.......{.....N.....{..........###.
 5|.....{.......{.......}...*..........###.
 6|.....{...}...{.......}...{..........###.
 7|.....{...}...*.......}...{..}.......###.
 8|.....{...}...{...........*..}........8..
 9|.....{.......{...........{..}...........
10|.....{.......{...##......{..............
11|.....{.......{...........{..............
12|.....................................p..
13|####..........................##########
14|####..........................##########
''')

# Black sap (deep: it drowns) under rotten vines, a stone island between,
# altar 3 on it. Past the island one tall sound vine, watched from the
# island; then a rotten run to the far bank, a Thornback on it.
SW_ROTWELL_K = block('''
 0|################################
 1|################################
 2|################################
 3|################################
 4|................................
 5|................................
 6|...................{............
 7|......}............{............
 8|......}...}........{...}........
 9|......}...}........{...}........
10|..........}...K....{...}........
11|.............###................
12|....:::::::::###::::::::::....t.
13|####:::::::::###::::::::::######
14|####:::::::::###::::::::::######
''')

# The secret exit, back at the wood's height, 3 rows up: pale spores drift
# UP the tall vine and slip into a crack in the ceiling. Climb, leap left to
# the ledge under the crack, bonk it open (false stone), and the attic above
# holds the silver bell (3-S; the S is written only once 3-S.txt exists:
# SECRET_3S). A Rattlehound on the floor.
SW_UPDRAFT = block('''
 0|############################
 1|####.........###############
 2|####....S....#..............
 3|##########FF##..{...........
 4|................{...........
 5|................{...........
 6|..........====..{...........
 7|................{...........
 8|................{...........
 9|................{...........
10|....c...........{.......c...
11|................{...........
12|........m.......{*..........
13|############################
14|############################
''')

# The bell, under a pod on a hanging root: before it a Rattlehound's chase
# runs onto a strip of Rootlings (the hound_and_mounds stamp).
SW_BELL0 = block('''
 0|##############################
 1|##############################
 2|##############################
 3|.....#........................
 4|.....#........................
 5|.....#........................
 6|.....*........................
 7|.........................{....
 8|.........................{....
 9|.........................{....
10|.........................{....
11|.........................{....
12|...*..................E..{.*..
13|##############################
14|##############################
''')
SW_BELL2 = common.stamp(SW_BELL0, 'hound_and_mounds', 8, 12)

# Until 3-S is in the build the whole set piece waits for it: no bell, and
# the attic and its crack plain stone (the updraft's motes are off on the
# same rule, orchard.gd). They all come back with 3-S.txt (WLS re-runs
# make_levels). No sign points at it: secret_hint_3 says it, near the sight.
if not SECRET_3S:
    SW_UPDRAFT[1] = '#' * len(SW_UPDRAFT[1])
    SW_UPDRAFT[2] = '#' * len(SW_UPDRAFT[2])
    SW_UPDRAFT[3] = SW_UPDRAFT[3].replace('F', '#')

SPOREWOOD = {
    'id': '3-3', 'name': 'The Sporewood', 'area': 16, 'theme': 'sporewood', 'music': 'orchard',
    'dread': 'Old Tatterjaw|rattlehound|Swift,Burning',
    'story_start': 'beat_3_3',
    'height': 24,
    'max_drop': 4,
    'twist': 'omens',
    'anoint': [(SW_BRAMBLE2, 14, 12, 'Swift', 'Sister Thistle'), (SW_CLEARING, 26, 21, 'Twinned', 'The Mourner')],
    'room': [('ambush', ((SW_CLEARING, 14), (SW_CLEARING, 39)), {'rows': (12, 22)})],
    'roles': 'S C D VA C A C A C B',
    'hints': ['Knock a glowfruit onto spores to burn them away',
              'Here lies nobody yet. Mother Yarrow is patient.'],
    'sections': [(SW_START, 0), (SW_MIST2, 3), (SW_DREAD, 6), SW_CLEARING, (SW_BRAMBLE2, 6), (SW_ALTAR2, 5),
                 (SW_CANOPY, 3), (SW_ROTWELL_K, 3), (SW_UPDRAFT, 0), (SW_BELL2, 0)],
}
if SECRET_3S:
    SPOREWOOD['secret'] = '3-S'
LEVELS.append(SPOREWOOD)


# ============================================================ 3-4 The Heartwood
# Area 17. Root steps (HW_START), the mastery climb up a root spiral over a
# pit (HW_CLIMB), Rootlings under a vine run (HW_GAUNTLET), the altar at the
# arena door (HW_DOOR), and Mother Gravebough's arena (R_ARENA).

HW_START = block('''
 0|############################
 1|############################
 2|############################
 3|############################
 4|############################
 5|############################
 6|..................8.........
 7|............................
 8|............................
 9|....................#####...
10|....c............##.#####...
11|.................##.#####...
12|..P.......r...r..##p#####...
13|############################
14|############################
''')

# The mastery climb: sound and rotten vines rising over a pit, a root knot
# after every two vines, pods on the tall vines, a Creepbone. Sigil 1 at the
# top of a rotten spur off the second tall vine (leap back to go on). The
# roof is raised over the climb (row 1 open) and the tall vines start at
# row 4, so no leap bonks it; the knot after the rotten x 49 is two tiles
# (x 52-53, a tile left of where it was): every leap off that vine lands on
# it (2.6 rows of it, where 0.7 did), and it's firm ground a fall comes back
# to. No Rootling on the floor before the pit (a fall's respawn there had two
# swelling under it): HW_START's second waits left of the root steps, and
# HW_CLIMB's is in HW_GAUNTLET.
HW_CLIMB = block('''
 0|########################################
 1|##########..............................
 2|........................................
 3|.............1..........................
 4|.............}...{...}......{...}.......
 5|.............}...{...}..##..*...}.......
 6|......{...}..}...*...}......{...}...r.s.
 7|......{...}......{..........{......#####
 8|......{...}...#..{..........i......#####
 9|......{..........{..........{......#####
10|......{.....................{......#####
11|......{............................#####
12|...................................#####
13|#####..............................#####
14|#####..............................#####
''')

HW_ALTAR = block('''
 0|##############
 1|##############
 2|..............
 3|..............
 4|..............
 5|..............
 6|..............
 7|..............
 8|..............
 9|.........?....
10|##...c........
11|##............
12|##.K.....@....
13|##############
14|##############
''')

# Rootlings in the soil under a vine run (three: HW_CLIMB's start floor has
# none, so a fall's respawn by the pit has no mound swelling under it); the
# Rattlehound on the far floor. Sigil 2 on a ledge above the run, under a
# ceiling pod.
HW_GAUNTLET = block('''
 0|######################################
 1|######################################
 2|................#####.................
 3|..................*...................
 4|....{...{...{...{.2..{...{............
 5|....{...{...{...{===.{...{............
 6|....{...{...{...{....{...{............
 7|....{...{...{...{....{...{............
 8|....{...{...{...{....{...{............
 9|....{...{...{...{....{...{............
10|......................................
11|......................................
12|.......r....r.....r.......s......m...
13|######################################
14|######################################
''')

HW_DOOR = block('''
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
10|..............
11|..............
12|..........K...
13|##############
14|##############
''')

# Mother Gravebough's arena (spec §3.4.4): her trunk is columns 28-35 (X her
# placement; the boss stands at x 944 of the arena by her art's rule), the
# bloom sockets are the anchors (+), two glowfruit under the roof are fire
# for her Spore Breath, and sigil 3 hangs over the top of the left vine.
R_ARENA = block('''
 0|####################################
 1|####################################
 2|##...3....8.......8.........########
 3|##.+.{......................########
 4|##==={......................########
 5|##...{...................{..########
 6|##...{..........+........{+.########
 7|##...{.......======......{..########
 8|##...{...................{..########
 9|##...{...+...............{..########
10|.....{.=====.............{..########
11|.....{...................{..########
12|..@..{..+...........+....{.X########
13|####################################
14|####################################
''')

LEVELS.append({
    'id': '3-4', 'name': 'The Heartwood', 'area': 17, 'theme': 'rootheart', 'music': 'orchard',
    'boss': 'rootmother', 'boss_music': 'rootmother',
    'story_start': 'beat_3_4', 'story_boss': 'boss_3_before', 'story_end': 'boss_3_after',
    'hints': ['Here lies Mother Yarrow. Water the trees.',
              'Follow her heart. Hit it where it blooms'],
    'sections': [HW_START, HW_CLIMB, HW_ALTAR, HW_GAUNTLET, HW_DOOR, T_OPEN, R_ARENA],
})

# Build 2: each regular level's ROSTER and THREAT rows, and the world's rules
# across them (the ramp, the checkpoints, the section roles).
common.world_tables(LEVELS, ROSTER, THREAT, MAX_GAP)
