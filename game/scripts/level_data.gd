extends RefCounted
## A level parsed from its ASCII file: the tile grid, where everything starts,
## and the header (name, music, hints). No nodes: the World builds from this,
## and the tests read it directly. The legend is frozen (contract.md §2);
## anything later goes through a header or tools/levels' overlay row.
##
## The file is a header of `key: value` lines, a `---`, then the rows. Every
## character is one 32 px tile; the rows may be ragged (short rows are padded
## with air). The legend (v2):
##
##   #  stone            B  cracked brick (a slash or a bonk from below breaks it)
##   =  ledge (one-way: jump up through it, stand on it, hold down to drop)
##   %  crumbling ledge (one-way; shakes when stood on, falls, comes back)
##   ?  reliquary: three embers      W  reliquary: a wax stub
##   R  gold reliquary: a relic      U  a spent reliquary (just solid)
##   ^  floor spikes     v  ceiling spikes     ~  lava
##   -  moving ledge, side to side (a run of them is one ledge)
##   |  moving ledge, up and down (a run of them side by side is one ledge)
##   o  ember    w  wax    1 2 3  the level's three sigils
##   P  Wick starts here   K  altar (checkpoint)   E  the great bell (the end)
##   @  a sign: the next hint from the header's `hints` (in reading order; the
##      World fills in the hero's calling: {calling} its name, {special} its
##      Special's, {special_tip} its sign line, classes.gd `sign_tip`)
##   c  a wall candle (light)      s  skeleton    b  bat    t  thornback
##   X  the boss (which one: header `boss: tollgrave|snuffer|rootmother|tinker|saint|hush`)
##   :  water (over solid floor: shallow, wade through; over water: deep, a pit)
##   F  false stone (solid; breaks like a brick; its crack shows only in light)
##   a  Bonebow   h  Hollow Helm   g  Gutterwing   k  Dripkin (hangs from the ceiling)
##   f  Brinejaw (in deep water; its cell counts as water)   M  Lidlurk (a mimic, on the floor)
##   D  the level's Dread (header `dread: Name|kind|omen,omen`; a secret level's
##      Warden with `warden:`)
##   N  Gutterwing nest (a sconce)   L  lantern post / brazier   d  drip spout (under a ceiling)
##   !  waxfall head (it flows down to the floor)
##
## v3 (tiles 12..22; DAWN_ON and STILL are runtime states only):
##
##   {  vine (climbable, not solid)        }  rotten vine (a run <= 3 tall)
##   I  wax-ice (solid, slick)             _  frosted ledge (one-way, slick)
##   Z  rime (solid, melts; never a required floor)
##   <  >  gear belt carrying left / right (solid)
##   G  glass (solid, strains)             A  dawnglass (a ledge only while lamplit)
##   *  spore pod    8  glowfruit    V  icicle    O Q  cog hub (clockwise / counter)
##   Y  pendulum weight    T  swing ledge (a run is one)    C  Vigil candle
##   &  wax float (a run is one; the cell stays water)
##   J  bell-buoy    H  Hushgrasp (both in a water surface cell, which stays water)
##   S  silver bell (opens the `secret:` level)    +  boss anchor (arenas)
##   r p m i  Rootling, Weepcap, Rattlehound, Creepbone
##   j q e u  Tickwind, Spurwheel, Frostbuckle, Hoarowl
##   x z y l  Glassmite, Gustling, Refractor, Paneguard
##   n 5 6 7  Hushling, Stillmaw, Unwick, Lurecoil (in deep water; its cell is water)
##   A pod, glowfruit or Creepbone drawn in a vine column (a vine cell above or
##   below it) stands on the vine: its cell is a vine too.
##
## Headers: title, subtitle, music, theme, hints (a|b|c), area (area level),
## area_abs, boss, boss_music, dread, warden, story_start, story_boss,
## story_end, par, tick, secret, secret_prize, gusts, hush, chase, cog_phase,
## weight_phase, rush. Every header, known or not, is also kept raw in
## `headers` (the modes' private keys: kind, tier, tags, deep, ...).
##
## Build 2's level-rule keys, raw only (tools/levels/common.py writes them
## from each world's tables; tests/level_rules.gd holds the file to them; the
## game plays the same without them): roster (the cast it declares:
## headline=..; support=..; guest=..; rattle_max=n; fodder_max=f; count=a-b;
## banned=..; pack_leaders=kind:n,..; stamps=..), threat (its cost per 100
## tiles), roles (a re-cut level's section roles).
## Build 2's elite keys, read from there (elites.gd), both optional: anoint
## (`x,y[:Omen+Omen[:Name]]; ...`: the monsters placed there are Anointed
## every run, in any level) and elite_behave (`nightfall` | `dusk`: turns
## behave_diff on in any world, or off from World 3).
## Build 2's twist keys, read from there, all optional: twist (an id in
## twists.gd TWISTS) and lesson (Title|Line) by twists.gd, belt_flip
## (x0-x1=N, ...) by features/clockwork.gd; a level without them plays as before.
## Build 2's `room: duel 98-109 rows 3-7; ambush 200-229; hold 300-327 @20`
## (sealed fight rooms) is read raw by features/sealed.gd.

const TILE := 32

enum {AIR, STONE, BRICK, LEDGE, CRUMBLE, BLOCK, SPENT, SPIKES_UP, SPIKES_DOWN, LAVA, WATER, FALSE_STONE,   # v2: 0..11
	VINE, ROTTEN_VINE, ICE, FROST_LEDGE, RIME, BELT_L, BELT_R, GLASS, DAWNGLASS, DAWN_ON, STILL}   # v3: 12..22

# FLAGS[t]: one lookup on the hot path.
const F_SOLID := 1
const F_LEDGE := 2           # one-way top
const F_SAFE := 4            # last_safe may record it (ice: not its outer tile at a pit's edge)
const F_SLICK := 8
const F_CLIMB := 16
const F_BELT := 32
const F_BREAK := 64          # a slash or a bonk breaks it
const F_MELT := 128
const F_HURT := 256
const F_WATERY := 512        # deep when the cell below is water too
const FLAGS: Array[int] = [
	0,                                   # AIR
	F_SOLID | F_SAFE,                    # STONE
	F_SOLID | F_SAFE | F_BREAK,          # BRICK
	F_LEDGE | F_SAFE,                    # LEDGE
	F_LEDGE,                             # CRUMBLE
	F_SOLID | F_SAFE,                    # BLOCK
	F_SOLID | F_SAFE,                    # SPENT
	F_HURT,                              # SPIKES_UP
	F_HURT,                              # SPIKES_DOWN
	F_HURT,                              # LAVA
	F_WATERY,                            # WATER
	F_SOLID | F_BREAK,                   # FALSE_STONE
	F_CLIMB,                             # VINE
	F_CLIMB,                             # ROTTEN_VINE
	F_SOLID | F_SAFE | F_SLICK,          # ICE
	F_LEDGE | F_SLICK,                   # FROST_LEDGE
	F_SOLID | F_MELT,                    # RIME
	F_SOLID | F_BELT,                    # BELT_L
	F_SOLID | F_BELT,                    # BELT_R
	F_SOLID,                             # GLASS
	0,                                   # DAWNGLASS (unlit: air to a body)
	F_LEDGE,                             # DAWN_ON
	F_LEDGE,                             # STILL
]

const SOLID := [STONE, BRICK, BLOCK, SPENT, FALSE_STONE, ICE, RIME, BELT_L, BELT_R, GLASS]
const GLYPH_TILES := {
	"#": STONE, "B": BRICK, "=": LEDGE, "%": CRUMBLE,
	"?": BLOCK, "W": BLOCK, "R": BLOCK, "U": SPENT,
	"^": SPIKES_UP, "v": SPIKES_DOWN, "~": LAVA,
	":": WATER, "F": FALSE_STONE,
	"{": VINE, "}": ROTTEN_VINE, "I": ICE, "_": FROST_LEDGE, "Z": RIME,
	"<": BELT_L, ">": BELT_R, "G": GLASS, "A": DAWNGLASS,
}
const BLOCK_CONTENTS := {"?": "embers", "W": "wax", "R": "relic"}
const ENTITY_GLYPHS := {
	"o": "ember", "w": "wax", "1": "sigil", "2": "sigil", "3": "sigil",
	"P": "start", "K": "altar", "E": "bell", "@": "sign", "c": "sconce",
	"s": "skeleton", "b": "bat", "t": "thornback", "X": "boss",
	"a": "bonebow", "h": "hollow_helm", "g": "gutterwing", "k": "dripkin", "f": "brinejaw", "M": "lidlurk",
	"D": "dread", "N": "nest", "L": "lantern", "d": "drip", "!": "waxfall",
	# v3 features
	"*": "pod", "8": "glowfruit", "V": "icicle", "O": "cog", "Q": "cog", "Y": "weight",
	"J": "buoy", "H": "grasp", "C": "vigil", "S": "silver_bell", "+": "anchor",
	# v3 monsters
	"r": "rootling", "p": "weepcap", "m": "rattlehound", "i": "creepbone",
	"j": "tickwind", "q": "spurwheel", "e": "frostbuckle", "u": "hoarowl",
	"x": "glassmite", "z": "gustling", "y": "refractor", "l": "paneguard",
	"n": "hushling", "5": "stillmaw", "6": "unwick", "7": "lurecoil",
}
# Runs of these are one thing: {kind, cell (leftmost), length}.
const RUN_GLYPHS := {"T": "swing", "&": "float"}
# Entities whose cell stays water (they sit in or on it).
const WATER_KINDS := ["brinejaw", "lurecoil", "buoy", "grasp"]
# Entities that may stand on a vine (their cell takes the vine's tile). A
# Dread (D) too: a Creepbone Dread or Warden in a vine column (3-S's
# Nine-Knuckle Nell) keeps the vine whole under it.
const VINE_CARRIERS := ["pod", "glowfruit", "creepbone", "dread"]
# Where each thing must stand (test_core checks every level against this):
#   floor = on something solid (or a ledge) below; ceiling = solid above;
#   air = anything; deep_water = in a water cell with water below;
#   surface = a water cell with no water above; vine_or_wall = a vine cell,
#   or an air cell beside a solid wall; hang = solid or a ledge above;
#   mount = floor, ceiling or vine; ceiling_or_vine = either.
const PLACEMENT := {
	"skeleton": "floor", "thornback": "floor", "altar": "floor", "bell": "floor", "sign": "floor", "boss": "floor",
	"bonebow": "floor", "hollow_helm": "floor", "lidlurk": "floor", "lantern": "floor", "dread": "air",
	"dripkin": "ceiling", "drip": "ceiling", "waxfall": "air", "brinejaw": "deep_water",
	"bat": "air", "gutterwing": "air", "nest": "air", "ember": "air", "wax": "air", "sigil": "air", "sconce": "air",
	# v3 features
	"pod": "mount", "glowfruit": "ceiling_or_vine", "icicle": "ceiling", "cog": "air", "weight": "hang",
	"swing": "air", "float": "surface", "buoy": "surface", "grasp": "surface", "vigil": "floor",
	"silver_bell": "floor", "anchor": "air",
	# v3 monsters
	"rootling": "floor", "weepcap": "floor", "rattlehound": "floor", "creepbone": "vine_or_wall",
	"tickwind": "floor", "spurwheel": "floor", "frostbuckle": "floor", "hoarowl": "floor",
	"glassmite": "floor", "gustling": "air", "refractor": "air", "paneguard": "floor",
	"hushling": "floor", "stillmaw": "air", "unwick": "floor", "lurecoil": "deep_water",
}
const TICK := 0.536                 # the W4 beat when a level has no `tick:` header

var id := ""
var title := ""
var subtitle := ""
var music := "chapel"
var theme := "nave"
var area := 1
var area_abs := -1        # the area level to use directly (modes), -1 = area_level(area, diff)
var boss := ""
var boss_music := ""      # a track or a stem set for the fight ("" = the World's choice)
var dread := {}           # {name, kind, omens: []}
var warden := {}          # a secret level's Warden: {name, kind, omens: []}
var story := {}           # start / boss / end -> scene id
var par := {}
var hints: PackedStringArray = []
var tick := TICK          # W4: the period tick-locked features keep
var secret := ""          # this level's silver bell opens that secret level
var secret_prize := ""    # a secret level's prize Legendary
var gusts: Array = []     # [{x0, x1, dir: -1 | 1, phase: "A" | "B"}] (tile columns, inclusive)
var hush_cols: Array = [] # [{x0, x1}]
var chase: Array = []     # [{x0, x1}]: 6-3's tide ranges (start altar x, end altar x)
var cog_phase := {}       # hub x -> turns
var weight_phase := {}    # anchor x -> turns
var rush := false         # a Waxworks arena file
var world := 0            # the id's first digit, or 0
var headers := {}         # every header, raw (the modes read their private keys here)
var width := 0
var height := 0
var tiles := PackedByteArray()
var start := Vector2i(2, 2)
var blocks := {}          # Vector2i -> "embers" | "wax" | "relic"
var entities: Array = []  # {kind, cell: Vector2i, ...}
var movers: Array = []    # {axis: "x" | "y", cell: Vector2i (leftmost), length: int}
var errors: PackedStringArray = []
var _restore := {}        # Vector2i -> the tile the cell had before its first set_tile


static func load_file(path: String) -> RefCounted:
	var text := FileAccess.get_file_as_string(path)
	var data = load("res://scripts/level_data.gd").new()
	data.id = path.get_file().get_basename()
	data.world = world_of(data.id)
	if text == "":
		data.errors.append("can't read %s" % path)
		return data
	data.parse(text)
	return data


static func world_of(level_id: String) -> int:
	## The world a level id belongs to: its first digit ("3-2" -> 3, "1-S" ->
	## 1), or 0 (lab-1, a mode's room).
	if level_id.length() >= 2 and level_id[1] == "-" and "123456789".contains(level_id[0]):
		return int(level_id[0])
	return 0


func parse(text: String) -> void:
	if world == 0:
		world = world_of(id)
	var lines := text.replace("\r", "").split("\n")
	var rows: Array[String] = []
	var in_rows := false
	for line in lines:
		if not in_rows:
			if line.strip_edges() == "---":
				in_rows = true
				continue
			var colon := line.find(":")
			if colon > 0:
				_header(line.substr(0, colon).strip_edges(), line.substr(colon + 1).strip_edges())
			continue
		rows.append(line)
	while rows.size() > 0 and rows[rows.size() - 1].strip_edges() == "":
		rows.pop_back()
	height = rows.size()
	width = 0
	for r in rows:
		width = maxi(width, r.length())
	tiles.resize(width * height)
	tiles.fill(AIR)
	var found_start := false
	var sign_index := 0
	var sigil_seen := {}
	var carriers: Array = []
	for y in height:
		var row: String = rows[y]
		var x := 0
		while x < row.length():
			var ch := row[x]
			var cell := Vector2i(x, y)
			if GLYPH_TILES.has(ch):
				tiles[y * width + x] = GLYPH_TILES[ch]
				if BLOCK_CONTENTS.has(ch):
					blocks[cell] = BLOCK_CONTENTS[ch]
			elif ch == "-" or ch == "|":
				var n := 1
				while x + n < row.length() and row[x + n] == ch:
					n += 1
				movers.append({"axis": "x" if ch == "-" else "y", "cell": cell, "length": n})
				x += n
				continue
			elif RUN_GLYPHS.has(ch):
				var n := 1
				while x + n < row.length() and row[x + n] == ch:
					n += 1
				var kind0: String = RUN_GLYPHS[ch]
				entities.append({"kind": kind0, "cell": cell, "length": n})
				if kind0 == "float":
					for k in n:
						tiles[y * width + x + k] = WATER
				x += n
				continue
			elif ENTITY_GLYPHS.has(ch):
				var kind: String = ENTITY_GLYPHS[ch]
				if kind == "start":
					if found_start:
						errors.append("two starts (P) in %s" % id)
					start = cell
					found_start = true
				else:
					var e := {"kind": kind, "cell": cell}
					if WATER_KINDS.has(kind):
						# It lives in the water: its cell is water too.
						tiles[y * width + x] = WATER
					if kind == "sigil":
						e["index"] = int(ch) - 1
						if sigil_seen.has(ch):
							errors.append("sigil %s appears twice" % ch)
						sigil_seen[ch] = true
					elif kind == "sign":
						e["text"] = hints[sign_index] if sign_index < hints.size() else ""
						if sign_index >= hints.size():
							errors.append("sign %d has no hint" % (sign_index + 1))
						sign_index += 1
					elif kind == "cog":
						e["dir"] = 1 if ch == "O" else -1
					if VINE_CARRIERS.has(kind):
						carriers.append(e)
					entities.append(e)
			elif ch != " " and ch != ".":
				errors.append("unknown glyph '%s' at %d,%d" % [ch, x, y])
			x += 1
	# A pod, glowfruit, Creepbone or Dread in a vine column stands on the vine.
	for e in carriers:
		var c: Vector2i = e["cell"]
		for dy in [-1, 1]:
			var t := tile(c.x, c.y + dy)
			if t == VINE or t == ROTTEN_VINE:
				tiles[c.y * width + c.x] = t
				e["on_vine"] = true
				break
	if not found_start:
		errors.append("no start (P)")
	if count("bell") == 0 and count("boss") == 0 and count("silver_bell") == 0:
		errors.append("no bell (E) or boss (X)")


func _header(key: String, value: String) -> void:
	headers[key] = value
	match key:
		"title":
			title = value
		"subtitle":
			subtitle = value
		"music":
			music = value
		"theme":
			theme = value
		"area":
			area = maxi(int(value), 1)
		"area_abs":
			area_abs = int(value) if value.strip_edges() != "" else -1
		"boss":
			boss = value
		"boss_music":
			boss_music = value
		"dread":
			dread = _named(value)
		"warden":
			warden = _named(value)
		"story_start":
			story["start"] = value
		"story_boss":
			story["boss"] = value
		"story_end":
			story["end"] = value
		"par":
			for kv in value.split(","):
				var p2 := kv.split("=")
				if p2.size() == 2:
					par[p2[0].strip_edges()] = float(p2[1])
		"hints":
			hints = value.split("|")
			for i in hints.size():
				hints[i] = hints[i].strip_edges()
		"tick":
			tick = float(value) if float(value) > 0.0 else TICK
		"secret":
			secret = value
		"secret_prize":
			secret_prize = value
		"gusts":
			gusts = []
			for part in value.split(","):
				var bits := part.strip_edges().split(":")
				if bits.size() < 2:
					continue
				var r := _range(bits[0])
				if r.is_empty():
					continue
				r["dir"] = -1 if bits[1].strip_edges().to_upper() == "L" else 1
				r["phase"] = bits[2].strip_edges().to_upper() if bits.size() > 2 else "A"
				gusts.append(r)
		"hush":
			hush_cols = _ranges(value)
		"chase":
			chase = _ranges(value)
		"cog_phase":
			cog_phase = _phases(value)
		"weight_phase":
			weight_phase = _phases(value)
		"rush":
			rush = value.strip_edges() not in ["", "0", "false", "no"]


static func _named(value: String) -> Dictionary:
	## "Name|kind|omen,omen" (a Dread's, a Warden's).
	var parts := value.split("|")
	return {"name": parts[0].strip_edges(), "kind": parts[1].strip_edges() if parts.size() > 1 else "skeleton",
			"omens": Array(parts[2].split(",")).map(func(o): return o.strip_edges()).filter(func(o): return o != "") if parts.size() > 2 else []}


static func _range(s: String) -> Dictionary:
	var ab := s.strip_edges().split("-")
	if ab.size() == 1 and ab[0].strip_edges().is_valid_int():
		return {"x0": int(ab[0]), "x1": int(ab[0])}
	if ab.size() != 2 or not ab[0].strip_edges().is_valid_int() or not ab[1].strip_edges().is_valid_int():
		return {}
	var a := int(ab[0])
	var b := int(ab[1])
	return {"x0": mini(a, b), "x1": maxi(a, b)}


static func _ranges(value: String) -> Array:
	var out := []
	for part in value.split(","):
		var r := _range(part)
		if not r.is_empty():
			out.append(r)
	return out


static func _phases(value: String) -> Dictionary:
	var out := {}
	for part in value.split(","):
		var kv := part.strip_edges().split("=")
		if kv.size() == 2 and kv[0].strip_edges().is_valid_int():
			out[int(kv[0])] = float(kv[1])
	return out


func count(kind: String) -> int:
	var n := 0
	for e in entities:
		if e["kind"] == kind:
			n += 1
	return n


func of_kind(kind: String) -> Array:
	return entities.filter(func(e): return e["kind"] == kind)


func tile(x: int, y: int) -> int:
	## Outside the sides and the top the level is walled; below it is open (a pit).
	if x < 0 or x >= width:
		return STONE
	if y < 0:
		return AIR
	if y >= height:
		return AIR
	return tiles[y * width + x]


func set_tile(a, b, c = null) -> void:
	## set_tile(cell: Vector2i, t) or set_tile(x, y, t). The first change to a
	## cell remembers what it was, so restore_tile(cell) can put it back (the
	## restore list: dawnglass, still water, melted rime, shattered glass, a
	## sealed door).
	var cell: Vector2i
	var t: int
	if a is Vector2i:
		cell = a
		t = int(b)
	else:
		cell = Vector2i(int(a), int(b))
		t = int(c)
	if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
		return
	var i := cell.y * width + cell.x
	if not _restore.has(cell):
		_restore[cell] = tiles[i]
	tiles[i] = t


func restore_tile(cell: Vector2i) -> void:
	## Back to the tile the file had (a no-op for a cell never set).
	if _restore.has(cell):
		tiles[cell.y * width + cell.x] = _restore[cell]
		_restore.erase(cell)


func original_tile(cell: Vector2i) -> int:
	## What the file has at cell, whatever set_tile did since.
	if _restore.has(cell):
		return _restore[cell]
	return tile(cell.x, cell.y)


func changed_cells() -> Array:
	return _restore.keys()


static func flags(t: int) -> int:
	return FLAGS[t] if t >= 0 and t < FLAGS.size() else 0


static func is_solid(t: int) -> bool:
	return (FLAGS[t] & F_SOLID) != 0


static func is_breakable(t: int) -> bool:
	return (FLAGS[t] & F_BREAK) != 0


static func is_ledge(t: int) -> bool:
	return (FLAGS[t] & F_LEDGE) != 0


static func is_safe(t: int) -> bool:
	return (FLAGS[t] & F_SAFE) != 0


static func is_slick(t: int) -> bool:
	return (FLAGS[t] & F_SLICK) != 0


static func is_climb(t: int) -> bool:
	return (FLAGS[t] & F_CLIMB) != 0


static func is_belt(t: int) -> bool:
	return (FLAGS[t] & F_BELT) != 0


static func is_floor(t: int) -> bool:
	## Something to stand on: solid, or a one-way top.
	return (FLAGS[t] & (F_SOLID | F_LEDGE)) != 0


func is_deep(x: int, y: int) -> bool:
	## Water with water under it: deep (it drowns, like a pit).
	return tile(x, y) == WATER and tile(x, y + 1) == WATER


func is_surface(x: int, y: int) -> bool:
	## A water cell with open air (not water) above it.
	return tile(x, y) == WATER and tile(x, y - 1) != WATER


func hurts_at(x: int, y: int, r: Rect2) -> bool:
	## Does this tile hurt a body with rect r? (spikes' pointy half, lava below
	## its crest, deep water covering the body's middle.) The bot uses it too.
	var t := tile(x, y)
	match t:
		SPIKES_UP:
			return Rect2(x * TILE + 3, y * TILE + 14, TILE - 6, TILE - 14).intersects(r)
		SPIKES_DOWN:
			return Rect2(x * TILE + 3, y * TILE, TILE - 6, TILE - 14).intersects(r)
		LAVA:
			return Rect2(x * TILE, y * TILE + 12, TILE, TILE - 12).intersects(r)
		WATER:
			return is_deep(x, y) and Rect2(x * TILE, y * TILE + 8, TILE, TILE - 8).has_point(r.get_center())
	return false


func pixel_size() -> Vector2:
	return Vector2(width * TILE, height * TILE)


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * TILE, (cell.y + 0.5) * TILE)


static func cell_floor(cell: Vector2i) -> Vector2:
	## The bottom middle of a cell: where something standing in it has its feet.
	return Vector2((cell.x + 0.5) * TILE, (cell.y + 1) * TILE)
