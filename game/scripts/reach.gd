extends RefCounted
## The reachability engine: Wick's own physics (player.gd, quirk "" and no
## Special, double jump or "down"-drops) searching a level's standing spots
## and vine holds for a way to every goal. tests/test_core.gd proves every
## level with it (contract.md §15), and the --autoplay bot (autoplay_bot.gd)
## plans its route with it.
##
## States are (x/16, y/32, climbing). From a floor state the actions are v2's
## (walk 0.22 s either way; a jump from standing or after 0.3 s of running,
## held 0.12 s or 0.6 s, either way or straight up). From a vine state: climb
## for 0 / 0.35 / 0.8 / 1.5 s (or slide 0.5 s), then leap left or right, the
## jump held 0.6 s. A sim ends when he lands, catches a vine, is hurt or falls
## out; a spot it ends on is a new state. More than STATE_CAP states is a
## failure, never a silent stop.
##
## The level is searched as a static copy (static_copy): moving ledges laid
## out over their sweep, cog rings and swing arcs as ledges, glass solid,
## dawnglass a ledge, rime, false stone and bricks open, a float a ledge at
## rest, still water within 6 tiles of each buoy a ledge. A BotWorld stands in
## for the World: rotten vines hold ROTTEN_HOLD (Dusk's 1.4 s less a margin),
## every crumble is there, there are no movers. With `push` on, every gust
## zone pushes GUST_PUSH its way (half on the ground, as the World does).
##
## Along the winning path to each goal it also keeps, per timed surface
## (rotten vine, glass, float, still water, dawnglass), the longest stay on
## one: the dwell rule (at most 60% of that surface's Dusk life).

const LevelData := preload("res://scripts/level_data.gd")
const PlayerScript := preload("res://scripts/player.gd")
const Movers := preload("res://scripts/movers.gd")
const TILE := 32
const DT := 1.0 / 120.0
const STATE_CAP := 12000
const GUST_PUSH := 120.0
const ROTTEN_HOLD := 1.2
const STILL_REACH := 6              # tiles of still water either side of a buoy
const SIM_TIME := 2.2
# The timed surfaces' Dusk lives (s) for the dwell rule: the fallbacks; the
# rule reads life(k), from the feature modules' own DIFF_KNOBS (WL5's, WL6's
# and WLS's requests, the track B merge): glass 1.09 s after one landing,
# a loaded float 1.30 s, a rotten vine 1.4, still water 7.
const LIFE := {"rotten": 1.4, "glass": 1.7, "float": 1.7, "still": 7.0, "dawn": 25.0}
const DWELL_SHARE := 0.6
static var _lives := {}


static func life(k: String) -> float:
	## A timed surface's Dusk life, from its feature's knobs (else LIFE).
	if _lives.is_empty():
		_lives = LIFE.duplicate()
		var rot := _dusk_knob("res://scripts/features/orchard.gd", "rotten_hold")
		if rot > 0.0:
			_lives["rotten"] = rot
		var land := _dusk_knob("res://scripts/features/glass.gd", "glass_land")
		var stand := _dusk_knob("res://scripts/features/glass.gd", "glass_stand")
		if land >= 0.0 and stand > 0.0:
			_lives["glass"] = (1.0 - land) / stand
		var sink := _dusk_knob("res://scripts/features/deep.gd", "float_sink")
		if sink > 0.0:
			_lives["float"] = Movers.FLOAT_UNDER / sink
		var still := _dusk_knob("res://scripts/features/deep.gd", "still_time")
		if still > 0.0:
			_lives["still"] = still
	return float(_lives.get(k, 999.0))


static func _dusk_knob(path: String, knob: String) -> float:
	if not ResourceLoader.exists(path):
		return -1.0
	var t: Dictionary = (load(path) as Script).get_script_constant_map().get("DIFF_KNOBS", {})
	var row = t.get(knob)
	return float((row as Dictionary).get("dusk", -1.0)) if row is Dictionary else -1.0


class BotWorld:
	## What the player asks the World, for a sim with no World.
	extends RefCounted
	var ftime := 0.0
	var movers: Array = []
	var level: RefCounted
	var rotten_hold := ROTTEN_HOLD
	var _rot := {}

	func reset() -> void:
		ftime = 0.0
		_rot.clear()

	func vine_present(x: int, y: int) -> bool:
		var t: int = level.tile(x, y)
		if t != LevelData.ROTTEN_VINE:
			return LevelData.is_climb(t)
		# A rotten run holds rotten_hold from the first touch this sim.
		var top := y
		while level.tile(x, top - 1) == LevelData.ROTTEN_VINE:
			top -= 1
		var k := Vector2i(x, top)
		if not _rot.has(k):
			_rot[k] = ftime
		return ftime - float(_rot[k]) < rotten_hold

	func ledge_present(_x: int, _y: int) -> bool:
		return true


# ---------------------------------------------------------------- the static copy

static func static_copy(lv: RefCounted, opts := {}) -> RefCounted:
	## The level as the bot plays it (see the header). opts: still (buoys'
	## still water as ledges, default true), dawn (dawnglass as ledges, default
	## true), open_breakables (bricks, false stone and rime open, default true).
	var c = LevelData.new()
	c.id = lv.id
	c.world = lv.world
	c.width = lv.width
	c.height = lv.height
	c.tiles = lv.tiles.duplicate()
	c.entities = lv.entities
	c.start = lv.start
	c.gusts = lv.gusts
	c.hush_cols = lv.hush_cols
	c.movers = lv.movers
	for m in (lv.movers if opts.get("movers", true) else []):
		var cell: Vector2i = m["cell"]
		var n: int = m["length"]
		if m["axis"] == "x":
			for x in range(cell.x - 3, cell.x + n + 3):
				if c.tile(x, cell.y) == LevelData.AIR:
					c.set_tile(x, cell.y, LevelData.LEDGE)
		else:
			for y in range(cell.y - 3, cell.y + 4):
				for x in range(cell.x, cell.x + n):
					if c.tile(x, y) == LevelData.AIR:
						c.set_tile(x, y, LevelData.LEDGE)
	for i in c.tiles.size():
		var t: int = c.tiles[i]
		if t == LevelData.DAWNGLASS and opts.get("dawn", true):
			c.tiles[i] = LevelData.DAWN_ON
		elif opts.get("open_breakables", true) and (LevelData.is_breakable(t) or t == LevelData.RIME):
			c.tiles[i] = LevelData.AIR
	for e in lv.entities:
		var cell: Vector2i = e["cell"]
		match e["kind"]:
			"cog":
				var hub := LevelData.cell_center(cell)
				for y in range(cell.y - 4, cell.y + 5):
					for x in range(cell.x - 4, cell.x + 5):
						var d := LevelData.cell_center(Vector2i(x, y)).distance_to(hub)
						if d >= 80.0 and d <= 112.0 and c.tile(x, y) == LevelData.AIR:
							c.set_tile(x, y, LevelData.LEDGE)
			"swing":
				_lay_arc(c, lv, cell, int(e.get("length", 1)))
			"float":
				for k in int(e.get("length", 1)):
					c.set_tile(cell.x + k, cell.y, LevelData.LEDGE)
			"buoy":
				if opts.get("still", true):
					for cc in still_cells(lv, cell):
						c.set_tile(cc.x, cc.y, LevelData.STILL)
	return c


static func still_cells(lv: RefCounted, buoy: Vector2i) -> Array:
	## The water surface a buoy's toll stills: the surface run through its
	## cell, up to STILL_REACH tiles either side.
	var out := []
	for dir in [-1, 1]:
		var x: int = buoy.x if dir < 0 else buoy.x + 1
		while absi(x - buoy.x) <= STILL_REACH and lv.is_surface(x, buoy.y):
			out.append(Vector2i(x, buoy.y))
			x += dir
	return out


static func _lay_arc(c: RefCounted, lv: RefCounted, cell: Vector2i, n: int) -> void:
	## Every cell a swing ledge's arc sweeps becomes a ledge (its top row).
	var anchor_y := -1
	for dy in range(1, 9):
		if LevelData.is_solid(lv.tile(cell.x + n / 2, cell.y - dy)):
			anchor_y = (cell.y - dy + 1) * TILE
			break
	var mid := Vector2((cell.x + n * 0.5) * TILE, cell.y * TILE)
	var anchor := Vector2(mid.x, anchor_y if anchor_y >= 0 else mid.y - 160.0)
	var rod := anchor.distance_to(mid)
	var amp := deg_to_rad(40.0)
	for i in 17:
		var a := lerpf(-amp, amp, i / 16.0)
		var p := anchor + Vector2(sin(a), cos(a)) * rod
		var y := floori(p.y / TILE)
		for x in range(floori((p.x - n * TILE * 0.5) / TILE), floori((p.x + n * TILE * 0.5 - 1.0) / TILE) + 1):
			if c.tile(x, y) == LevelData.AIR:
				c.set_tile(x, y, LevelData.LEDGE)


static func timed_cells(lv: RefCounted) -> Dictionary:
	## Vector2i -> surface type, for the dwell rule.
	var out := {}
	for y in lv.height:
		for x in lv.width:
			match lv.tile(x, y):
				LevelData.GLASS:
					out[Vector2i(x, y)] = "glass"
				LevelData.DAWNGLASS:
					out[Vector2i(x, y)] = "dawn"
				LevelData.ROTTEN_VINE:
					out[Vector2i(x, y)] = "rotten"
	for e in lv.entities:
		var cell: Vector2i = e["cell"]
		if e["kind"] == "float":
			for k in int(e.get("length", 1)):
				out[Vector2i(cell.x + k, cell.y)] = "float"
		elif e["kind"] == "buoy":
			for cc in still_cells(lv, cell):
				out[cc] = "still"
	return out


static func goals_of(lv: RefCounted) -> Array:
	## Every bell, sigil and silver bell (and a boss level's arena).
	var goals := []
	for e in lv.entities:
		match e["kind"]:
			"sigil":
				goals.append({"what": "sigil %d" % (int(e["index"]) + 1), "p": LevelData.cell_center(e["cell"]), "rope": false})
			"bell":
				var f := LevelData.cell_floor(e["cell"])
				goals.append({"what": "bell", "p": f, "rope": true, "rect": Rect2(f.x - 14, f.y - 70, 28, 70)})
			"silver_bell":
				var f := LevelData.cell_floor(e["cell"])
				goals.append({"what": "silver bell", "p": f, "rope": true, "rect": Rect2(f.x - 14, f.y - 44, 28, 44)})
			"boss":
				var f := LevelData.cell_floor(e["cell"])
				goals.append({"what": "boss arena", "p": f, "rope": true, "rect": Rect2(f.x - 40, f.y - 60, 80, 60)})
	return goals


# ---------------------------------------------------------------- actions

# PROTOTYPE (proto-tall): the bot never drops through a ledge, so it can't go
# DOWN a lift (laid out as a stack of ledges over its sweep) or a ledge stack:
# a descent (lab-3) is unprovable. With DROPS on (tools/proto_reach.gd sets it)
# a floor state also tries pure down held 0.3 s (player.gd DROP_HOLD 0.15 s).
static var DROPS := false


static func floor_actions() -> Array:
	var out := []
	for dir in [-1, 1]:
		out.append({"walk": 0.22, "dir": dir, "jump": false})
		for run in [0.0, 0.3]:
			for hold in [0.12, 0.6]:
				out.append({"walk": run, "dir": dir, "jump": true, "hold": hold})
	out.append({"walk": 0.0, "dir": 0, "jump": true, "hold": 0.6})
	if DROPS:
		out.append({"walk": 0.3, "dir": 0, "jump": false, "drop": true})
	return out


static func vine_actions() -> Array:
	var out := []
	for dir in [-1, 1]:
		for t in [0.0, 0.35, 0.8, 1.5]:
			out.append({"vine": true, "mode": "climb", "t": t, "dir": dir})
		out.append({"vine": true, "mode": "slide", "t": 0.5, "dir": dir})
	return out


static func action_pad(a: Dictionary, t: float, st: Dictionary) -> Dictionary:
	## The held buttons at time t into action a (st keeps the action's own
	## little state). The caller turns held into pressed edges as the World's
	## _read_pad does.
	var pd := {}
	var dir := int(a.get("dir", 0))
	if a.get("vine", false):
		var t0 := float(a["t"])
		if t < t0:
			if a["mode"] == "slide":
				pd["down"] = true
			else:
				pd["up"] = true      # climb: the pad's up never leaps (a fresh jump press with a way held would)
			if dir != 0 and a["mode"] == "climb":
				pd["left" if dir < 0 else "right"] = true
			return pd
		if dir != 0:
			pd["left" if dir < 0 else "right"] = true
		# One tick with jump up (so the press is fresh), then the leap, held;
		# never sooner than LEAP_AFTER into the action (the action starts at
		# the catch in a live World: a press sooner would climb, not leap).
		if not st.has("leap_t"):
			st["leap_t"] = maxf(t, PlayerScript.LEAP_AFTER + DT) + DT
		pd["jump"] = t >= float(st["leap_t"]) and t - float(st["leap_t"]) < 0.6
		return pd
	if a.get("drop", false):
		pd["down"] = t < float(a["walk"])   # PROTOTYPE: the drop-through (DROPS)
		return pd
	if dir < 0:
		pd["left"] = true
	elif dir > 0:
		pd["right"] = true
	if a["jump"] and t >= float(a["walk"]):
		if not st.has("jump_t"):
			st["jump_t"] = t
		pd["jump"] = t - float(st["jump_t"]) < float(a["hold"])
	return pd


static func key_of(pos: Vector2, climbing: bool) -> Vector3i:
	return Vector3i(floori(pos.x / 16.0), floori(pos.y / TILE), 1 if climbing else 0)


static func hurts(lv: RefCounted, r: Rect2) -> bool:
	for y in range(floori(r.position.y / TILE), floori((r.end.y - 0.01) / TILE) + 1):
		for x in range(floori(r.position.x / TILE), floori((r.end.x - 0.01) / TILE) + 1):
			if lv.hurts_at(x, y, r):
				return true
	return false
