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
var _route: Array = []
var _routed := false


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


func setup(level: RefCounted) -> void:
	lv = level
	w = int(level.width)
	h = int(level.height)
	for a in [_solid, _break, _hazard, _climb, _support, _oneway]:
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


func breaks(x: int, y: int) -> bool:
	return x >= 0 and x < w and y >= 0 and y < h and _break[y * w + x] == 1


func body(x: int, y: int) -> bool:
	## His body fits at (x, y): it and the cell over it clear, no hazard.
	return y >= 0 and y < h and not solid(x, y) and not solid(x, y - 1) and not hazard(x, y) and not hazard(x, y - 1)


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
	## (caught), then the floor (down held past it); [] a snuff.
	var out := []
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
	var s0 := start()
	var g := goal()
	if s0 < 0 or g.x < 0:
		return _route
	var dist := {s0: 0}
	var parent := {s0: -1}
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
		if int(dist[s]) < c:
			continue
		if touches(s, [g]):
			end = s
			break
		for mv in moves(s):
			var t: int = mv[0]
			var nc: int = c + int(mv[1])
			if not dist.has(t) or nc < int(dist[t]):
				dist[t] = nc
				parent[t] = s
				if not buckets.has(nc):
					buckets[nc] = []
				(buckets[nc] as Array).append(t)
				top = maxi(top, nc)
	if end < 0:
		return _route
	var path := [end]
	while int(parent[path.back()]) >= 0:
		path.append(int(parent[path.back()]))
	path.reverse()
	_route = path
	return _route


func proj(cell: Vector2i) -> int:
	## The index on the route nearest cell (columns, and rows twice over: his
	## own storey first); ties to the earlier.
	var best := -1
	var bi := 0
	var r := route()
	for i in r.size():
		var c := cell_of(r[i])
		var d := absi(c.x - cell.x) + 2 * absi(c.y - cell.y)
		if best < 0 or d < best:
			best = d
			bi = i
	return bi


func run_lengths() -> Array:
	## The route's length on foot to each of its states: columns walked and
	## rows climbed (a fall's rows are free).
	var out := [0]
	var r := route()
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


func reach(max_drop := -1) -> Dictionary:
	## Every state reachable from the start ({state: [[next, drop]]}), only by
	## falls of max_drop rows or less when it's given.
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
			(edges[s] as Array).append([mv[0], mv[2]])
			if not edges.has(mv[0]):
				edges[mv[0]] = []
				todo.append(mv[0])
	return edges
