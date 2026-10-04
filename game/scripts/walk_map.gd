extends RefCounted
## The walk map (Build 2's shapes): a coarse map of where Waxby can go in a
## level, for what needs a level's route where it isn't a strip (taller than
## STRIP_ROWS): the order the route meets things (the first-time barks,
## features/clockwork.gd and features/deep.gd; the hints are the
## generator's) and, in tests/level_rules.gd, how far apart its checkpoints
## are on foot and the descent rules. tools/levels/common.py WalkMap is the
## same map, move for move. A strip's route is x, in its facing (first_of).
##
## A state is standing in a cell (S: it and the cell over it clear of solid,
## no hazard in either, a floor under it: solid, a one-way top, dawnglass, a
## float, or a mover's swept band) or holding a vine cell (C). The moves, in
## this order, each with its cost (columns, rows climbed, a jump's 1, a
## break's 2) and its drop (rows fallen):
##   S: walk a column (onto a cell or off an edge: a fall; into brick, false
##      stone or rime: +2); drop through a one-way top (or a breakable
##      floor, as broken when he came in: +2); grab a vine where he stands
##      or just over him; jump: feet up 0-3 rows, then 0-8 columns at that
##      height, then a fall, landing h rows up at most JUMP_REACH[h] columns
##      away (or a vine caught on the way): at the most a run and the coyote
##      time carry him, so a rule never calls a way the bot proves closed
##   C: climb, slide, stand at its foot, hop off sideways, mount a floor 1-2
##      columns off its top cell (no roof), let go at its bottom, leap: feet
##      up 0-2 rows, a fall, LEAP_REACH (4 columns vine to vine)
## A fall catches the first vine cell it passes (or goes on, down held) and
## ends on the first floor; a hazard (spikes, lava, deep water) or the
## level's bottom ends it with no state (a snuff). Monsters aren't there.
## Breakable cells are floors to land on and doors to walk into. Movers
## sweep: a lift 3 rows up and down, a moving ledge or a swing 3 columns
## either way, a cog's teeth its ring (radius 3). The goal (the bell, else
## the boss, else a silver bell) is touched from its cell, the cells either
## side and the two over it (the rope hangs 70 px).
##
## A level with two ways through (2-2's split roads, 5-3's decks) names
## them, each by the cells it passes (header `roads: high 120,10 200,10;
## low 120,21`): roads() is each one's route, start to goal by way of its
## cells in turn, and road_of() which a cell is on (the nearest; on the
## common stretches every road's), so the rules measure a run along the one
## road it takes (tests/level_rules.gd: the threat, the gaps, the screens,
## the XP walk). With none, the one road is route(). entry_of is the door
## the route comes into a box by (a sealed room's, a boss arena's).
## The search is a queue per cost over flat arrays, falls and bodies worked
## out once a cell (the map is built at a tall level's load: clockwork.gd's
## and deep.gd's first-time barks; a 36-row level's route in a few ms).

const LevelData := preload("res://scripts/level_data.gd")
const STRIP_ROWS := 15
const JUMP_UP := 3
const JUMP_ACROSS := 8
const JUMP_REACH := {3: 4, 2: 5, 1: 6, 0: 7, -1: 7, -2: 7, "low": 8}    # rows up -> columns
const LEAP_UP := 2
const LEAP_ACROSS := 5
const LEAP_REACH := {2: 2, 1: 3, 0: 4, -1: 4, "low": 5}
const MOUNT_REACH := 2
const MOVER_SWEEP := 3
const COG_RING := 3
const BREAKABLE := [LevelData.BRICK, LevelData.FALSE_STONE, LevelData.RIME]
const ONE_WAY := [LevelData.LEDGE, LevelData.CRUMBLE, LevelData.FROST_LEDGE, LevelData.DAWNGLASS, LevelData.DAWN_ON]
const HAZARDS := [LevelData.SPIKES_UP, LevelData.SPIKES_DOWN, LevelData.LAVA]

var lv: RefCounted
var w := 0
var h := 0
var _solid := PackedByteArray()     # solid, less what breaks
var _break := PackedByteArray()
var _hazard := PackedByteArray()
var _climb := PackedByteArray()
var _support := PackedByteArray()
var _oneway := PackedByteArray()
var _body := PackedByteArray()     # body(x, y), worked out once
var _band := PackedByteArray()     # a mover's swept band (band_at)
var _falls: Array = []             # per cell: falls(x, y) once asked (null till then)
var _route: Array = []
var _routed := false
var _by_col := {}                  # proj(): the route's indices by column
var _roads: Array = []             # roads(): [{name, path}]
var _roaded := false


static func of(level: RefCounted) -> RefCounted:
	## The level's walk map, made once (kept on the level).
	if level.has_meta("walk_map"):
		return level.get_meta("walk_map")
	var m = load("res://scripts/walk_map.gd").new()
	m.setup(level)
	level.set_meta("walk_map", m)
	return m


static func strip(level: RefCounted) -> bool:
	return int(level.height) <= STRIP_ROWS


static func first_of(level: RefCounted, cells: Array) -> int:
	## The index in cells of the one the route meets first: a strip's by x in
	## its facing (the first given on a tie, as the leftmost always was), a
	## taller level's by the walk map's route (proj; ties by x in its
	## facing). -1 for none.
	if cells.is_empty():
		return -1
	var f := int(level.get("facing")) if level.get("facing") != null else 1
	var best := 0
	if strip(level):
		for i in range(1, cells.size()):
			if (cells[i] as Vector2i).x * f < (cells[best] as Vector2i).x * f:
				best = i
		return best
	var m = of(level)
	var bk: Array = [m.proj(cells[0]), (cells[0] as Vector2i).x * f]
	for i in range(1, cells.size()):
		var k: Array = [m.proj(cells[i]), (cells[i] as Vector2i).x * f]
		if k[0] < bk[0] or (k[0] == bk[0] and k[1] < bk[1]):
			best = i
			bk = k
	return best


static func dir_of(level: RefCounted, cell: Vector2i) -> int:
	## Which way the route runs past cell (+1 right, -1 left): a strip's its
	## facing, a taller level's the walk map's there (dir_at).
	var f := int(level.get("facing")) if level.get("facing") != null else 1
	if strip(level):
		return f
	var m = of(level)
	return m.dir_at(m.proj(cell))


static func roads_of(level: RefCounted) -> Array:
	## The level's roads (header `roads: high 120,10 200,10; low 120,21`):
	## [{name, via: [Vector2i]}] in the header's order, [] for none (a part
	## that doesn't read is left out; common.roads_of).
	var hd = level.get("headers")
	var raw := str((hd as Dictionary).get("roads", "")) if hd is Dictionary else ""
	var out := []
	for part in raw.split(";", false):
		var bits := part.strip_edges().split(" ", false)
		if bits.size() < 2:
			continue
		var via: Array = []
		for b in bits.slice(1):
			var xy := (b as String).split(",")
			if xy.size() == 2 and xy[0].strip_edges().is_valid_int() and xy[1].strip_edges().is_valid_int():
				via.append(Vector2i(int(xy[0]), int(xy[1])))
		if not via.is_empty():
			out.append({"name": bits[0], "via": via})
	return out


static func entry_of(level: RefCounted, x0: int, x1: int, ys: Vector2i) -> Vector2i:
	## The door the route comes into the box x0..x1, ys.x..ys.y by: (side,
	## row), side -1 the left (x0), +1 the right (x1), row the route's first
	## cell inside (-1 where there's none). A strip's left door (facing left,
	## its right); a taller level's where the walk map's route first steps
	## inside, from the side it comes from (one it never enters: the way the
	## route runs past it; common.room_entry).
	if strip(level):
		return Vector2i(-int(level.get("facing")) if level.get("facing") != null else -1, -1)
	var m = of(level)
	var r: Array = m.route()
	for i in r.size():
		var c: Vector2i = m.cell_of(r[i])
		if c.x >= x0 and c.x <= x1 and c.y >= ys.x and c.y <= ys.y:
			var px: int = m.cell_of(r[i - 1]).x if i > 0 else c.x
			if px < x0 or px > x1:
				return Vector2i(-1 if px < x0 else 1, c.y)
			return Vector2i(-1 if c.x - x0 <= x1 - c.x else 1, c.y)
	return Vector2i(-m.dir_at(m.proj(Vector2i((x0 + x1) / 2, (ys.x + ys.y) / 2))), -1)


func setup(level: RefCounted) -> void:
	lv = level
	w = int(level.width)
	h = int(level.height)
	for a in [_solid, _break, _hazard, _climb, _support, _oneway, _band]:
		a.resize(w * h)
		a.fill(0)
	var floats := {}
	for e in level.entities:
		if e["kind"] == "float":
			for k in int(e.get("length", 1)):
				floats[e["cell"] + Vector2i(k, 0)] = true
	var band := {}
	for m in level.movers:
		var c: Vector2i = m["cell"]
		for k in int(m["length"]):
			if m["axis"] == "y":
				for o in range(-MOVER_SWEEP, MOVER_SWEEP + 1):
					band[Vector2i(c.x + k, c.y + o)] = true
		for k in range(-MOVER_SWEEP, int(m["length"]) + MOVER_SWEEP):
			if m["axis"] == "x":
				band[Vector2i(c.x + k, c.y)] = true
	for e in level.entities:
		var c: Vector2i = e["cell"]
		if e["kind"] == "swing":
			for k in range(-MOVER_SWEEP, int(e.get("length", 1)) + MOVER_SWEEP):
				band[Vector2i(c.x + k, c.y)] = true
		elif e["kind"] == "cog":
			for j in range(-COG_RING, COG_RING + 1):
				for i in range(-COG_RING, COG_RING + 1):
					var d := sqrt(float(i * i + j * j))
					if d >= COG_RING - 0.5 and d < COG_RING + 0.5:
						band[Vector2i(c.x + i, c.y + j)] = true
	for y in h:
		for x in w:
			var t: int = level.tile(x, y)
			var i := y * w + x
			var solid := LevelData.is_solid(t)
			_break[i] = 1 if BREAKABLE.has(t) else 0
			_solid[i] = 1 if solid and _break[i] == 0 else 0
			_hazard[i] = 1 if HAZARDS.has(t) or (t == LevelData.WATER and level.tile(x, y + 1) == LevelData.WATER) else 0
			_climb[i] = 1 if LevelData.is_climb(t) else 0
			var sup := solid or ONE_WAY.has(t) or floats.has(Vector2i(x, y)) or band.has(Vector2i(x, y))
			_support[i] = 1 if sup else 0
			_oneway[i] = 1 if sup and not solid else 0
			_band[i] = 1 if band.has(Vector2i(x, y)) else 0
	_body.resize(w * h)
	for i in w * h:
		var up := i - w
		var ok := _solid[i] == 0 and _hazard[i] == 0 and (up < 0 or (_solid[up] == 0 and _hazard[up] == 0))
		_body[i] = 1 if ok else 0
	_falls.resize(w * h)


# -- cells

func solid(x: int, y: int) -> bool:
	if x < 0 or x >= w:
		return true
	if y < 0 or y >= h:
		return false
	return _solid[y * w + x] == 1


func hazard(x: int, y: int) -> bool:
	return x >= 0 and x < w and y >= 0 and y < h and _hazard[y * w + x] == 1


func climb(x: int, y: int) -> bool:
	return x >= 0 and x < w and y >= 0 and y < h and _climb[y * w + x] == 1


func support(x: int, y: int) -> bool:
	if x < 0 or x >= w:
		return true
	if y < 0 or y >= h:
		return false
	return _support[y * w + x] == 1


func one_way(x: int, y: int) -> bool:
	return x >= 0 and x < w and y >= 0 and y < h and _oneway[y * w + x] == 1


func band_at(x: int, y: int) -> bool:
	## (x, y) is in a mover's swept band (a lift's, a moving ledge's, a
	## swing's, a cog's ring): something carries him there.
	return x >= 0 and x < w and y >= 0 and y < h and _band[y * w + x] == 1


func breaks(x: int, y: int) -> bool:
	return x >= 0 and x < w and y >= 0 and y < h and _break[y * w + x] == 1


func body(x: int, y: int) -> bool:
	## His body fits at (x, y): it and the cell over it clear, no hazard.
	return y >= 0 and y < h and x >= 0 and x < w and _body[y * w + x] == 1


func stand(x: int, y: int) -> bool:
	return body(x, y) and support(x, y + 1)


# -- states: (y * w + x) * 2, + 1 on a vine

func key(c: bool, x: int, y: int) -> int:
	return (y * w + x) * 2 + (1 if c else 0)


func cell_of(s: int) -> Vector2i:
	return Vector2i((s >> 1) % w, (s >> 1) / w)


func on_vine(s: int) -> bool:
	return s & 1 == 1


# -- moves

func falls(x: int, y: int) -> Array:
	## Where a fall from body cell (x, y) ends: the first vine cell it passes
	## (caught), then the floor (down held past it); [] a snuff. Worked out
	## once a cell (the caller only reads it).
	var i := y * w + x
	var inside := x >= 0 and x < w and y >= 0 and y < h
	if inside and _falls[i] != null:
		return _falls[i]
	var out := []
	if inside:
		_falls[i] = out
	var caught := false
	var yy := y
	while yy < h:
		if not body(x, yy):
			return out
		if not caught and climb(x, yy):
			out.append(key(true, x, yy))
			caught = true
		if support(x, yy + 1):
			out.append(key(false, x, yy))
			return out
		yy += 1
	return out


func _arc(x: int, y: int, up: int, across: int, reach: Dictionary, out: Array) -> void:
	## A jump (or a leap) from (x, y): feet up k rows, then n columns at that
	## height, then a fall (a vine caught on the way); landing h rows up at
	## most reach[h] away.
	for k in range(0, up + 1):
		if not body(x, y - k):
			break
		for d in [1, -1]:
			for n in range(0 if (d == 1 and k > 0) else 1, across + 1):
				var cx: int = x + d * n
				if n > 0 and not body(cx, y - k):
					break
				for st in falls(cx, y - k):
					var sy: int = cell_of(st).y
					var hh: int = y - sy
					var lim: int = int(reach.get(hh, reach["low"] if hh < 0 else -1))
					if n <= lim:
						out.append([st, n + maxi(hh, 0) + 1, maxi(0, sy - y)])


func moves(s: int) -> Array:
	## [[state, cost, drop]] from state s, in the map's order (each state once,
	## at its cheapest).
	var c := cell_of(s)
	var x := c.x
	var y := c.y
	var out := []
	if not on_vine(s):
		for d in [1, -1]:
			var nx: int = x + d
			if body(nx, y):
				var cost := 3 if breaks(nx, y) or breaks(nx, y - 1) else 1
				for st in falls(nx, y):
					out.append([st, cost, cell_of(st).y - y])
		if one_way(x, y + 1) or breaks(x, y + 1):
			for st in falls(x, y + 1):
				out.append([st, 1 if one_way(x, y + 1) else 3, cell_of(st).y - y])
		if climb(x, y):
			out.append([key(true, x, y), 1, 0])
		if climb(x, y - 1) and body(x, y - 1):
			out.append([key(true, x, y - 1), 1, 0])
		_arc(x, y, JUMP_UP, JUMP_ACROSS, JUMP_REACH, out)
	else:
		if climb(x, y - 1) and body(x, y - 1):
			out.append([key(true, x, y - 1), 1, 0])
		if climb(x, y + 1) and body(x, y + 1):
			out.append([key(true, x, y + 1), 1, 0])
		if support(x, y + 1):
			out.append([key(false, x, y), 1, 0])
		for d in [1, -1]:
			if body(x + d, y):
				for st in falls(x + d, y):
					out.append([st, 1, cell_of(st).y - y])
		if not climb(x, y - 1) and body(x, y - 1):
			for d in [1, -1]:
				for m in range(1, MOUNT_REACH + 1):
					if not body(x + d * m, y - 1):
						break
					if stand(x + d * m, y - 1):
						out.append([key(false, x + d * m, y - 1), m + 1, 0])
		if not climb(x, y + 1) and not support(x, y + 1):
			for st in falls(x, y + 1):
				out.append([st, 1, cell_of(st).y - y])
		_arc(x, y, LEAP_UP, LEAP_ACROSS, LEAP_REACH, out)
	var best := {}
	for mv in out:
		if mv[0] != s and (not best.has(mv[0]) or int(mv[1]) < int(best[mv[0]][1])):
			best[mv[0]] = mv
	var seen := {}
	var res := []
	for mv in out:
		if best.has(mv[0]) and not seen.has(mv[0]):
			seen[mv[0]] = true
			res.append(best[mv[0]])
	return res


# -- the start, the goal, the route

func start() -> int:
	var p: Vector2i = lv.start
	return key(false, p.x, p.y) if stand(p.x, p.y) else -1


func goal() -> Vector2i:
	## The bell, else the boss, else a silver bell (the first of each in
	## reading order); (-1, -1) for none.
	for k in ["bell", "boss", "silver_bell"]:
		for e in lv.entities:
			if e["kind"] == k:
				return e["cell"]
	return Vector2i(-1, -1)


func exits() -> Array:
	## Every way out: the bell, the boss, each silver bell (it clears the
	## level by its secret way: an attic needs no way back down).
	var out := []
	for e in lv.entities:
		if e["kind"] in ["bell", "boss", "silver_bell"]:
			out.append(e["cell"])
	return out


func touches(s: int, cells: Array) -> bool:
	## s touches one of cells (its cell, either side, or the two over it).
	var c := cell_of(s)
	for g in cells:
		if g.x >= 0 and absi(c.x - g.x) <= 1 and g.y - c.y >= 0 and g.y - c.y <= 2:
			return true
	return false


func route() -> Array:
	## The cheapest way from the start to the goal, as states ([] when
	## there's none). Ties go to the state found first (the moves' order): a
	## queue per cost, first in first out, as common.py's heap.
	if _routed:
		return _route
	_routed = true
	var g := goal()
	if g.x >= 0:
		_route = _search(start(), [g], false)
	return _route


func _search(s0: int, cells: Array, exact: bool) -> Array:
	## The cheapest way from state s0 to one touching cells (exact: standing
	## or hanging in one of them), as states; [] when there's none.
	if s0 < 0:
		return []
	var n := w * h * 2
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var parent := PackedInt32Array()
	parent.resize(n)
	parent.fill(-1)
	var want := {}
	for c in cells:
		want[c] = true
	dist[s0] = 0
	var buckets := {0: [s0]}
	var c := 0
	var top := 0
	var end := -1
	var heads := {}
	while c <= top:
		var b: Array = buckets.get(c, [])
		var i: int = int(heads.get(c, 0))
		if i >= b.size():
			c += 1
			continue
		heads[c] = i + 1
		var s: int = b[i]
		if dist[s] < c:
			continue
		if (want.has(cell_of(s)) if exact else touches(s, cells)):
			end = s
			break
		for mv in moves(s):
			var t: int = mv[0]
			var nc: int = c + int(mv[1])
			if dist[t] < 0 or nc < dist[t]:
				dist[t] = nc
				parent[t] = s
				if not buckets.has(nc):
					buckets[nc] = []
				(buckets[nc] as Array).append(t)
				top = maxi(top, nc)
	if end < 0:
		return []
	var path := [end]
	while parent[path.back()] >= 0:
		path.append(parent[path.back()])
	path.reverse()
	return path


func route_via(via: Array) -> Array:
	## The cheapest way from the start to the goal by way of the cells via in
	## turn (standing or hanging in each), as states; [] when a leg has none.
	var g := goal()
	var s0 := start()
	if s0 < 0 or g.x < 0:
		return []
	var path := [s0]
	for c in via:
		var leg := _search(path.back(), [c], true)
		if leg.is_empty():
			return []
		path += leg.slice(1)
	var last := _search(path.back(), [g], false)
	if last.is_empty():
		return []
	return path + last.slice(1)


func roads() -> Array:
	## [{name, path}]: each road's route (roads_of; a road whose way isn't
	## there keeps an empty path), or the one road, route(), named "".
	if _roaded:
		return _roads
	_roaded = true
	var named := roads_of(lv)
	if named.is_empty():
		_roads = [{"name": "", "path": route()}]
	else:
		for r in named:
			_roads.append({"name": r["name"], "path": route_via(r["via"])})
	return _roads


func near(path: Array, cell: Vector2i) -> int:
	## How far cell is from a route (columns, and rows twice over, as proj):
	## its nearest state's; a large number for an empty one.
	var best := 1 << 20
	for s in path:
		var c := cell_of(s)
		best = mini(best, absi(c.x - cell.x) + 2 * absi(c.y - cell.y))
	return best


func road_of(cell: Vector2i) -> Array:
	## The roads (indices into roads()) a cell is on: the nearest, every one
	## as near (the stretches they share: all of them).
	var rs := roads()
	var d := []
	var best := 1 << 20
	for r in rs:
		d.append(near(r["path"], cell))
		best = mini(best, int(d.back()))
	var out := []
	for i in rs.size():
		if int(d[i]) == best:
			out.append(i)
	return out


func proj(cell: Vector2i) -> int:
	## The index on the route nearest cell (columns, and rows twice over: his
	## own storey first); ties to the earlier. Searched out from cell's
	## column (the route's states by column, made once).
	var r := route()
	if r.is_empty():
		return 0
	if _by_col.is_empty():
		for i in r.size():
			var cx := cell_of(r[i]).x
			if not _by_col.has(cx):
				_by_col[cx] = []
			(_by_col[cx] as Array).append(i)
	var best := -1
	var bi := 0
	for dx in w + absi(cell.x) + 1:
		if best >= 0 and dx > best:
			break
		for x in ([cell.x] if dx == 0 else [cell.x - dx, cell.x + dx]):
			for i in _by_col.get(x, []):
				var d: int = dx + 2 * absi(cell_of(r[i]).y - cell.y)
				if best < 0 or d < best or (d == best and i < bi):
					best = d
					bi = i
	return bi


func run_lengths(path: Array = []) -> Array:
	## The route's (or path's) length on foot to each of its states: columns
	## walked and rows climbed (a fall's rows are free).
	var out := [0]
	var r := route() if path.is_empty() else path
	for i in range(1, r.size()):
		var a := cell_of(r[i - 1])
		var b := cell_of(r[i])
		out.append(int(out.back()) + absi(b.x - a.x) + maxi(0, a.y - b.y))
	return out


func dir_at(i: int) -> int:
	## Which way the route runs at index i (+1 right, -1 left): the columns it
	## covers over the next few states, else the last few.
	var r := route()
	for pair in [[i, mini(i + 6, r.size() - 1)], [maxi(i - 6, 0), i]]:
		var j0: int = pair[0]
		var j1: int = pair[1]
		if j1 > j0 and cell_of(r[j1]).x != cell_of(r[j0]).x:
			return 1 if cell_of(r[j1]).x > cell_of(r[j0]).x else -1
	return 1


func reach(max_drop := -1, allow := Callable()) -> Dictionary:
	## Every state reachable from the start ({state: [[next, drop]]}), only by
	## falls of max_drop rows or less when it's given, and only by the moves
	## allow(from, to, drop) passes when it's given (a level's own descent
	## rules: tests/level_rules.gd descent_limits).
	var s0 := start()
	if s0 < 0:
		return {}
	var edges := {s0: []}
	var todo := [s0]
	while not todo.is_empty():
		var s: int = todo.pop_back()
		for mv in moves(s):
			if max_drop >= 0 and int(mv[2]) > max_drop:
				continue
			if allow.is_valid() and not bool(allow.call(s, int(mv[0]), int(mv[2]))):
				continue
			(edges[s] as Array).append([mv[0], mv[2]])
			if not edges.has(mv[0]):
				edges[mv[0]] = []
				todo.append(mv[0])
	return edges
