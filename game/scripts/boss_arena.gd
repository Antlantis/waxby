extends RefCounted
## What every boss fight shares: finding its arena (wall to wall, measured
## four rows up so a low doorway doesn't count), the doorway cells, sealing
## them when the fight starts and opening them again if the hero falls.

const LevelData := preload("res://scripts/level_data.gd")
const TILE := LevelData.TILE


static func find(level: RefCounted, feet: Vector2, door_on_floor := false) -> Dictionary:
	## {left, right (px), door: [Vector2i]} for a boss standing at feet.
	## door_on_floor (WL5's door hint, for a boss that stands off the door's
	## floor: the Saint mid-nave over the void): the doorway is the lowest run
	## of 2-5 air cells standing on a floor in the column left of the wall,
	## as saint_boss.gd finds it, instead of the three rows over the boss's feet.
	var ty := floori(feet.y / TILE)
	var tx := floori(feet.x / TILE)
	var probe := ty - 4
	var l := tx
	while l > 0 and not LevelData.is_solid(level.tile(l - 1, probe)):
		l -= 1
	var r := tx
	while r < level.width - 1 and not LevelData.is_solid(level.tile(r + 1, probe)):
		r += 1
	var door: Array[Vector2i] = []
	var rows: Array = range(ty - 3, ty)
	if door_on_floor:
		var run := _floor_run(level, l - 1)
		if not run.is_empty():
			rows = run
	for x in [l - 1, l - 2]:
		for y in rows:
			if level.tile(x, y) == LevelData.AIR:
				door.append(Vector2i(x, y))
	return {"left": l * TILE, "right": (r + 1) * TILE, "door": door}


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
			world._redraw_at(c.x)
			world.dust_at(LevelData.cell_center(c))
	if world and not door.is_empty():
		world._sfx("block_break", 0.7)


static func unseal(world: Node, level: RefCounted, door: Array) -> void:
	for c in door:
		level.set_tile(c.x, c.y, LevelData.AIR)
		if world:
			world._redraw_at(c.x)
