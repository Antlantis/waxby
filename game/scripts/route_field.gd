extends RefCounted
## How far a goal is by the way there, not as the crow flies (Build 2's
## shapes, E6): a breadth-first walk out from the goal over the cells
## Waxby's feet can be in. In a tower, a bowl, a loop or a level played right
## to left the goal can be straight overhead or behind him, so the --autoplay
## bot (autoplay_bot.gd) measures its progress, its plan's horizon and its
## greedy order (reach_search.gd's field option) by this instead of by
## rightward x, and its fallback pad heads down it (heading).
##
## A cell is his feet's (x, y: feet at its bottom), open when it and the cell
## over it are neither solid nor hurt (spikes, lava, deep water). He can be in
## an open cell within JUMP_ROWS rows over something to stand on or a vine,
## in its own column or REACH_COLS either side (a held jump's height and a
## gap's width, roughly as reach.gd's actions cover them), or on a vine.
## From a cell he can go sideways or up into such a cell, and down into any
## open one (a fall; through a one-way ledge only where the level's routes
## drop through them: drops). Each move is a tile. It is a measure, not a
## route: reach_search.gd still plans the moves, with Wick's own physics.
## Built once per goal on the level's static copy (reach.gd static_copy:
## movers laid out over their sweep, breakables open): a few ms a level.

const LevelData := preload("res://scripts/level_data.gd")
const TILE := 32
const JUMP_ROWS := 3
const REACH_COLS := 3
const FAR := 1 << 20             # no way there (dist)
const BODY := Vector2(22.0, 44.0)   # his rect (player.gd size), for the goal's cells

var lv: RefCounted
var w := 0
var h := 0
var drops := false
var dist := PackedInt32Array()   # per cell: moves to the goal, FAR where there's no way
var _open := PackedByteArray()   # per cell: OPEN | STAND | VINE
var _lift := PackedByteArray()   # per cell: rows down to a foothold (the reach columns' least), NONE past JUMP_ROWS
const OPEN := 1
const STAND := 2
const VINE := 4
const NONE := 255
const STEPS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]


func build(level: RefCounted, goal: Dictionary, p_drops := false) -> RefCounted:
	## The field toward goal ({p, rope, rect}, reach.gd goals_of's) on level.
	lv = level
	w = int(level.width)
	h = int(level.height)
	drops = p_drops
	_cells()
	dist.resize(w * h)
	dist.fill(FAR)
	var queue := PackedInt32Array()
	for c in _goal_cells(goal):
		var i: int = c.y * w + c.x
		if dist[i] == FAR:
			dist[i] = 0
			queue.append(i)
	var qi := 0
	while qi < queue.size():
		var i: int = queue[qi]
		qi += 1
		var v := Vector2i(i % w, i / w)
		var d: int = dist[i] + 1
		for step in STEPS:
			var u: Vector2i = v + step
			if u.x < 0 or u.x >= w or u.y < 0 or u.y >= h:
				continue
			var j: int = u.y * w + u.x
			if dist[j] != FAR or not _move_ok(u, v):
				continue
			dist[j] = d
			queue.append(j)
	return self


func _cells() -> void:
	_open.resize(w * h)
	_open.fill(0)
	for y in h:
		for x in w:
			var t: int = lv.tile(x, y)
			var above: int = lv.tile(x, y - 1)
			if LevelData.is_solid(t) or LevelData.is_solid(above) or _hurts(x, y, t) or _hurts(x, y - 1, above):
				continue
			var f := OPEN
			if LevelData.is_floor(lv.tile(x, y + 1)):
				f |= STAND
			if LevelData.is_climb(t) or LevelData.is_climb(above):
				f |= VINE
			_open[y * w + x] = f
	# Rows down to a foothold (a floor under the cell, or a vine), in the
	# cell's own column, through open cells, at most JUMP_ROWS.
	var col := PackedByteArray()
	col.resize(w * h)
	col.fill(NONE)
	for x in w:
		for y in h:
			for k in JUMP_ROWS + 1:
				var yy := y + k
				if yy >= h:
					break
				var f: int = _open[yy * w + x]
				if f == 0:
					break
				if f & (STAND | VINE):
					col[y * w + x] = k
					break
	_lift.resize(w * h)
	for y in h:
		for x in w:
			var best := NONE
			for cx in range(maxi(x - REACH_COLS, 0), mini(x + REACH_COLS, w - 1) + 1):
				best = mini(best, col[y * w + cx])
			_lift[y * w + x] = best


func _hurts(x: int, y: int, t: int) -> bool:
	return (LevelData.flags(t) & LevelData.F_HURT) != 0 or (t == LevelData.WATER and lv.is_deep(x, y))


func _move_ok(u: Vector2i, v: Vector2i) -> bool:
	## From cell u to its neighbour v (feet first).
	var fv: int = _open[v.y * w + v.x]
	if fv == 0:
		return false
	if v.y > u.y:
		# Down: a fall, or a slide down a vine; never through a one-way
		# ledge but where the level's routes drop.
		return drops or not LevelData.is_ledge(lv.tile(v.x, v.y))
	var fu: int = _open[u.y * w + u.x]
	if v.y < u.y and (fu & VINE):
		return true
	return (fv & VINE) != 0 or _lift[v.y * w + v.x] <= JUMP_ROWS


func _goal_cells(goal: Dictionary) -> Array:
	## The cells whose body touches the goal (its rope, or within 6 px of its point).
	var p: Vector2 = goal["p"]
	var out := []
	var cx := floori(p.x / TILE)
	var cy := floori((p.y - 1.0) / TILE)
	for y in range(maxi(cy - 2, 0), mini(cy + 3, h)):
		for x in range(maxi(cx - 2, 0), mini(cx + 3, w)):
			if _open[y * w + x] == 0:
				continue
			var feet := Vector2((x + 0.5) * TILE, (y + 1) * TILE)
			var body := Rect2(feet.x - BODY.x * 0.5, feet.y - BODY.y, BODY.x, BODY.y)
			var hit: bool = body.intersects(goal["rect"]) if bool(goal.get("rope", false)) and goal.has("rect") else body.grow(6.0).has_point(p)
			if hit:
				out.append(Vector2i(x, y))
	if out.is_empty() and cx >= 0 and cx < w and cy >= 0 and cy < h:
		out.append(Vector2i(cx, cy))
	return out


func cell_of(feet: Vector2) -> Vector2i:
	return Vector2i(floori(feet.x / TILE), floori((feet.y - 1.0) / TILE))


func at(feet: Vector2) -> int:
	## Moves from feet to the goal (FAR where there's no way): the cell his
	## feet are in, else the one over or under it (mid-climb, mid-jump).
	var c := cell_of(feet)
	var best := FAR
	for dy in [0, -1, 1]:
		var y: int = c.y + dy
		if c.x >= 0 and c.x < w and y >= 0 and y < h:
			best = mini(best, dist[y * w + c.x])
			if best < FAR and dy == 0:
				return best
	return best


func heading(feet: Vector2, steps := 4) -> Vector2i:
	## Which way the goal lies by the way there: down the field from his cell
	## (or the one over or under it, as at()) for up to `steps` moves, the net
	## move; (0, 0) where there's no way, or he's there.
	var c := cell_of(feet)
	var start := Vector2i(-1, -1)
	for dy in [0, -1, 1]:
		var y: int = c.y + dy
		if c.x >= 0 and c.x < w and y >= 0 and y < h and dist[y * w + c.x] < FAR:
			start = Vector2i(c.x, y)
			break
	if start.x < 0:
		return Vector2i.ZERO
	c = start
	for i in steps:
		var best := c
		var bd: int = dist[c.y * w + c.x]
		for step in STEPS:
			var n: Vector2i = c + step
			if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h and dist[n.y * w + n.x] < bd:
				bd = dist[n.y * w + n.x]
				best = n
		if best == c:
			break
		c = best
	return c - start
