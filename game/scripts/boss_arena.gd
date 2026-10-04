extends RefCounted
## What every boss fight shares: finding its arena (wall to wall, measured
## four rows up so a low doorway doesn't count), the doorway cells, sealing
## them when the fight starts and opening them again if the hero falls.
## The doorway is on the side he comes in by (Build 2's shapes, E10): the
## left wall's, as every arena before the shapes has it; else the right
## wall's (a level played right to left, 4-3's); where both walls are open,
## in a strip the side the level starts him on, in a taller level the side
## its route comes in by (WalkMap.entry_of, as the level rules' room_entry:
## a fold-back storey walked right to left is entered from the right though
## it starts left). find's side says which (-1 left, 1 right) and past_door
## asks whether he's in past it.

const LevelData := preload("res://scripts/level_data.gd")
const WalkMap := preload("res://scripts/walk_map.gd")
const TILE := LevelData.TILE


static func find(level: RefCounted, feet: Vector2, door_on_floor := false) -> Dictionary:
	## {left, right (px), door: [Vector2i], side: -1 | 1} for a boss standing
	## at feet. door_on_floor (WL5's door hint, for a boss that stands off the
	## door's floor: the Saint mid-nave over the void): the doorway is the
	## lowest run of 2-5 air cells standing on a floor in the column outside
	## the wall, as saint_boss.gd finds it, instead of the three rows over the
	## boss's feet.
	var ty := floori(feet.y / TILE)
	var tx := floori(feet.x / TILE)
	var probe := ty - 4
	var l := tx
	while l > 0 and not LevelData.is_solid(level.tile(l - 1, probe)):
		l -= 1
	var r := tx
	while r < level.width - 1 and not LevelData.is_solid(level.tile(r + 1, probe)):
		r += 1
	var door := _doorway(level, [l - 1, l - 2], range(ty - 3, ty), door_on_floor)
	var side := -1
	var start = level.get("start")
	var from_right: bool = start is Vector2i and (start as Vector2i).x > r
	if level.get("height") != null and level.get("headers") is Dictionary and not WalkMap.strip(level):
		# A taller level: the side its route comes in by (the arena's box,
		# wall to wall, its floor's rows up to the probe's).
		from_right = WalkMap.entry_of(level, l - 2, r + 2, Vector2i(probe, ty)).x > 0
	if door.is_empty() or from_right:
		var east := _doorway(level, [r + 1, r + 2], range(ty - 3, ty), door_on_floor)
		if not east.is_empty():
			door = east
			side = 1
	return {"left": l * TILE, "right": (r + 1) * TILE, "door": door, "side": side}


static func _doorway(level: RefCounted, cols: Array, rows: Array, on_floor: bool) -> Array[Vector2i]:
	## The air cells of a wall's two columns (cols: the one by the arena
	## first) in its doorway's rows (on_floor: the lowest floor run of the
	## first column, as find's door_on_floor).
	var door: Array[Vector2i] = []
	if on_floor:
		var run := _floor_run(level, int(cols[0]))
		if not run.is_empty():
			rows = run
	for x in cols:
		for y in rows:
			if level.tile(x, y) == LevelData.AIR:
				door.append(Vector2i(x, y))
	return door


static func past_door(side: int, left: float, right: float, x: float, inset: float) -> bool:
	## He's inset px into the arena past its door (side, find's): past its
	## left wall, or (a door on the right) its right wall.
	return x < right - inset if side > 0 else x > left + inset


static func _floor_run(level: RefCounted, c: int) -> Array:
	## The lowest run of 2-5 air cells in column c that stands on a floor
	## (its rows, bottom first), or [].
	var y: int = level.height - 1
	while y >= 1:
		if level.tile(c, y) == LevelData.AIR and LevelData.is_solid(level.tile(c, y + 1)):
			var run: Array = []
			var yy := y
			while yy >= 1 and level.tile(c, yy) == LevelData.AIR:
				run.append(yy)
				yy -= 1
			if run.size() >= 2 and run.size() <= 5:
				return run
			y = yy
		y -= 1
	return []


static func seal(world: Node, level: RefCounted, door: Array) -> void:
	for c in door:
		level.set_tile(c.x, c.y, LevelData.STONE)
		if world:
			world._redraw_at(c.x, c.y)
			world.dust_at(LevelData.cell_center(c))
	if world and not door.is_empty():
		world._sfx("block_break", 0.7)


static func seal_free(world: Node, level: RefCounted, door: Array, bodies: Array) -> Array:
	## Seals the door's open cells that no living body stands in (a body in a
	## doorway keeps its cell open: never stone round a hero or a monster) and
	## returns the cells it sealed, to unseal later. secrets.gd's Warden rooms
	## and features/sealed.gd's fight rooms.
	var cells: Array = []
	for c in door:
		var cr := Rect2(c.x * TILE, c.y * TILE, TILE, TILE)
		var blocked := false
		for a in bodies:
			if a != null and is_instance_valid(a) and a.alive and (a.rect() as Rect2).intersects(cr):
				blocked = true
				break
		if not blocked and level.tile(c.x, c.y) == LevelData.AIR:
			cells.append(c)
	seal(world, level, cells)
	return cells


static func unseal(world: Node, level: RefCounted, door: Array) -> void:
	for c in door:
		level.set_tile(c.x, c.y, LevelData.AIR)
		if world:
			world._redraw_at(c.x, c.y)
