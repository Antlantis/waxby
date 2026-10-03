extends Node2D
## Anything that walks, jumps or falls through the tile grid: Wick and the
## walking monsters. position is the middle of the feet; the box is size wide
## and size.y tall above it. Moves one axis at a time against the grid (and
## the moving ledges), so nothing tunnels at these speeds (a step is < 6 px).
##
## A step moves, in order: the ledge it rides (its delta; carried up into a
## ceiling it slides off instead of embedding), the belt under its feet
## (80 px/s the arrows' way, as a displacement: no momentum into the air),
## the push the World hands it (`push`, horizontal px/s, a displacement that
## never walks grounded feet past a floor edge: the edge brake), then its own
## velocity. Terrain moves an actor only this way (contract.md §3); the
## movement constants never change.

const LevelData := preload("res://scripts/level_data.gd")
const TILE := LevelData.TILE
const BELT_SPEED := 80.0

var level: RefCounted             # LevelData
var world: Object                 # the World (or a test's BotWorld stub), for the moving ledges (may be null in tests)
var size := Vector2(20, 30)
var velocity := Vector2.ZERO
var on_floor := false
var on_wall := 0                  # -1 wall on the left, 1 on the right, 0 none
var on_ceiling := false
var riding: Object = null         # the moving ledge under the feet, if any
var drop_through := 0.0           # seconds left of falling through ledges
var bumped: Array[Vector2i] = []  # solid cells the head hit this step, nearest first
var push := Vector2.ZERO          # px/s of displacement this step (world.push_player; x only)
var push_brake := true            # a grounded push stops at a floor edge
var belt_carry := true            # belts carry it (monsters whose rules say otherwise turn it off)
var is_hero := false
var belt_dx := 0.0                # the belt's carry this step (px)
var push_dx := 0.0                # the push's move this step (px), after the brake
var _no_land: Object = null       # a ledge that just slid it off under a ceiling


func rect() -> Rect2:
	return Rect2(position.x - size.x * 0.5, position.y - size.y, size.x, size.y)


func center() -> Vector2:
	return position - Vector2(0, size.y * 0.5)


func move(dt: float) -> void:
	## One physics step of velocity through the level.
	bumped.clear()
	on_wall = 0
	on_ceiling = false
	_no_land = null
	belt_dx = 0.0
	push_dx = 0.0
	if drop_through > 0.0:
		drop_through -= dt
	if riding != null:
		_carry_y(riding.delta.y)
		_move_x(riding.delta.x)
	elif on_floor and belt_carry:
		_belt(dt)
	if push.x != 0.0:
		var dx := push.x * dt
		if push_brake and on_floor and not ground_ahead(1 if dx > 0.0 else -1):
			dx = 0.0
		push_dx = dx
		_move_x(dx)
	_move_x(velocity.x * dt)
	var was_floor := on_floor
	on_floor = false
	riding = null
	_move_y(velocity.y * dt, was_floor)


func _carry_y(dy: float) -> void:
	## The ledge's vertical move, through collision: carried up into a
	## ceiling, it slides off rather than embedding.
	if dy >= 0.0:
		position.y += dy
		return
	position.y += dy
	var r := rect()
	var ty := floori(r.position.y / TILE)
	for tx in range(floori((r.position.x + 0.01) / TILE), floori((r.end.x - 0.01) / TILE) + 1):
		if LevelData.is_solid(level.tile(tx, ty)):
			position.y = (ty + 1) * TILE + size.y
			on_ceiling = true
			_no_land = riding
			return


func _belt(dt: float) -> void:
	## Standing on a belt: carried BELT_SPEED px/s the arrows' way (the World
	## may have reversed a run: world.belt_dir).
	var ty := floori((position.y + 1.0) / TILE)
	var r := rect()
	var dir := 0
	var cell := Vector2i.ZERO
	for tx in [floori(position.x / TILE), floori((r.position.x + 0.01) / TILE), floori((r.end.x - 0.01) / TILE)]:
		var t: int = level.tile(tx, ty)
		if t == LevelData.BELT_L or t == LevelData.BELT_R:
			dir = 1 if t == LevelData.BELT_R else -1
			cell = Vector2i(tx, ty)
			break
	if dir == 0:
		return
	if world != null and world.has_method("belt_dir"):
		dir = world.belt_dir(cell, dir)
	belt_dx = dir * BELT_SPEED * dt
	_move_x(belt_dx)


func _move_x(dx: float) -> void:
	if dx == 0.0:
		return
	position.x += dx
	var r := rect()
	var y0 := floori(r.position.y / TILE)
	var y1 := floori((r.end.y - 0.01) / TILE)
	if dx > 0.0:
		var tx := floori((r.end.x - 0.01) / TILE)
		for ty in range(y0, y1 + 1):
			if LevelData.is_solid(level.tile(tx, ty)):
				position.x = tx * TILE - size.x * 0.5
				velocity.x = minf(velocity.x, 0.0)
				on_wall = 1
				return
	else:
		var tx := floori(r.position.x / TILE)
		for ty in range(y0, y1 + 1):
			if LevelData.is_solid(level.tile(tx, ty)):
				position.x = (tx + 1) * TILE + size.x * 0.5
				velocity.x = maxf(velocity.x, 0.0)
				on_wall = -1
				return


func _move_y(dy: float, was_floor: bool) -> void:
	var before_bottom := position.y
	position.y += dy
	var r := rect()
	var x0 := floori((r.position.x + 0.01) / TILE)
	var x1 := floori((r.end.x - 0.01) / TILE)
	if dy >= 0.0:
		# Falling (or standing: dy 0 still has to find the floor).
		var ty := floori(position.y / TILE)
		var top := ty * TILE
		for tx in range(x0, x1 + 1):
			var t: int = level.tile(tx, ty)
			var lands := LevelData.is_solid(t)
			if not lands and LevelData.is_ledge(t) and drop_through <= 0.0:
				lands = before_bottom <= top + 0.5 and _ledge_there(tx, ty)
			if lands:
				position.y = top
				velocity.y = minf(velocity.y, 0.0)
				on_floor = true
				_landed_on_tile(tx, ty)
				break
		if not on_floor and world != null:
			_land_on_movers(before_bottom)
		# Stuck to the floor while walking over tile seams: probe 1 px down.
		if not on_floor and was_floor and dy >= 0.0 and velocity.y >= 0.0:
			var probe := floori((position.y + 1.0) / TILE)
			if probe != ty:
				for tx in range(x0, x1 + 1):
					var t2: int = level.tile(tx, probe)
					if LevelData.is_solid(t2) or (LevelData.is_ledge(t2) and drop_through <= 0.0 and _ledge_there(tx, probe)):
						position.y = probe * TILE
						on_floor = true
						_landed_on_tile(tx, probe)
						break
	else:
		var ty := floori(r.position.y / TILE)
		var hit: Array[Vector2i] = []
		for tx in range(x0, x1 + 1):
			if LevelData.is_solid(level.tile(tx, ty)):
				hit.append(Vector2i(tx, ty))
		if hit.size() > 0:
			var nudged := _corner_nudge(hit)
			if not nudged:
				position.y = (ty + 1) * TILE + size.y
				velocity.y = maxf(velocity.y, 0.0)
				on_ceiling = true
				hit.sort_custom(func(a, b): return absf((a.x + 0.5) * TILE - position.x) < absf((b.x + 0.5) * TILE - position.x))
				bumped = hit


func _corner_nudge(_hit: Array[Vector2i]) -> bool:
	## Wick overrides this to slide round a ceiling corner he only clipped.
	return false


func _ledge_there(_tx: int, _ty: int) -> bool:
	## A crumbling ledge that has fallen isn't there; the World knows.
	if world != null and world.has_method("ledge_present"):
		return world.ledge_present(_tx, _ty)
	return true


func _landed_on_tile(_tx: int, _ty: int) -> void:
	if world != null and world.has_method("stood_on"):
		world.stood_on(self, _tx, _ty)


func _land_on_movers(before_bottom: float) -> void:
	if drop_through > 0.0:
		return
	var r := rect()
	for m in world.movers:
		if m == _no_land or not m.present:
			continue
		var mr: Rect2 = m.rect()
		if r.end.x <= mr.position.x or r.position.x >= mr.end.x:
			continue
		var top := mr.position.y
		# Where the ledge's top was before its move this step. A ledge falling
		# faster than a pixel a tick (or jumping after a hitstop) keeps its
		# rider: the tolerance grows by its fall (the riding fix).
		var old_top = top - m.delta.y
		if before_bottom <= old_top + 1.0 + maxf(0.0, m.delta.y) and position.y >= top:
			position.y = top
			velocity.y = minf(velocity.y, 0.0)
			on_floor = true
			riding = m
			m.ride(self, is_hero)
			return


func solid_at(p: Vector2) -> bool:
	return LevelData.is_solid(level.tile(floori(p.x / TILE), floori(p.y / TILE)))


func ground_ahead(dir: int) -> bool:
	## Is there floor just past the front foot? (Walkers turn at edges.)
	var foot := Vector2(position.x + dir * (size.x * 0.5 + 2.0), position.y + 4.0)
	var t: int = level.tile(floori(foot.x / TILE), floori(foot.y / TILE))
	return LevelData.is_solid(t) or LevelData.is_ledge(t)


func wall_ahead(dir: int) -> bool:
	var p := Vector2(position.x + dir * (size.x * 0.5 + 1.0), position.y - size.y * 0.5)
	return solid_at(p)
