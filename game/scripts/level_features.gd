extends RefCounted
## The level's living scenery: water, drip spouts, waxfalls, lantern posts
## and braziers, Gutterwing nests, false stone's crack, and where elites may
## stand. The World calls build() once, then step/touch/lights/draw every
## tick or frame (see world.gd).
##
## v3: this is the dispatcher (contract.md §4). v2's features stay here; the
## new ones are the modules in scripts/features/ (orchard, clockwork, glass,
## deep, secrets: each extends features/feature.gd), built after v2's and
## called after v2's for every hook. The queries at the end (vine_at ...
## tide_x) forward to the module that owns them, with a fallback from the
## tiles when that module isn't there.
##
##   shallow water  a ':' row over solid floor: light x0.75 while wading and a
##                  ripple crest; movement is untouched
##   deep water     ':' over ':': world._touch_world charges it like a pit
##                  ("water", via level.hurts_at); here only the look and steam
##   drip spout d   every 2.4 s (phase from x): a 0.6 s swelling glint, then a
##                  drop (g 1400) that douses whoever it lands on, and puts out
##                  a lantern it falls into
##   waxfall !      2.0 s on, 1.2 s off, with a 0.4 s gurgle before it starts;
##                  while on it pushes down at 300 px/s and douses
##   lantern L      a slash or a touch lights it: r 140 for 25 s, guttering
##                  (flickering) for the last 3 s. Inside a boss arena an L is
##                  a brazier instead: r 130, lit until snuffed, tagged
##                  "brazier" in world.add_light (the Snuffer reads them).
##                  The fight starts with the floor braziers lit and the
##                  ledge ones dark (climb up and light them)
##   nest N         a violet sconce: 0.8 s tell, then a Gutterwing comes out;
##                  at most 2 alive, the next 6 s after a kill, only with Wick
##                  within 400 px and its cocoon in plain view (world.gd
##                  in_plain_view: its tell never starts off the glass or
##                  behind the HUD; world.gd look_up leans the camera to show
##                  the sconce)
##   false stone F  solid and breakable (tile_view draws it as stone); its
##                  crack shows only inside a light
## Props come from art/props/*.svg (W6b) and are drawn with their
## bottom-centre on the floor (posts, braziers) or their top-centre on the
## ceiling (spout, waxfall head); code-drawn stand-ins until they exist.

const LevelData := preload("res://scripts/level_data.gd")
const Arena := preload("res://scripts/boss_arena.gd")
const Elites := preload("res://scripts/elites.gd")
const Themes := preload("res://scripts/themes/loader.gd")
const TILE := 32
const SPOUT_EVERY := 2.4
const SPOUT_SWELL := 0.6
const FALL_ON := 2.0
const FALL_OFF := 1.2
const FALL_TELL := 0.4
const FALL_PUSH := 300.0
const LANTERN_R := 140.0
const LANTERN_LIFE := 25.0
const LANTERN_GUTTER := 3.0
const BRAZIER_R := 130.0
const NEST_TELL := 0.8
const NEST_MAX := 2
const NEST_AGAIN := 6.0
const NEST_RANGE := 400.0
const WATER := {
	"": Color("1f4f5a"), "waxfall": Color("4a3a24"), "chandlery": Color("1b4a55"),
	"garden": Color("1f4a3c"), "undercandle": Color("2c2450"),
}
const PROPS := ["brazier_lit", "brazier_out", "lantern_post_lit", "lantern_post_out", "drip_spout",
		"waxfall_head", "nest_sconce", "false_stone_crack"]
# Where W6b's props put things (art/props/points_world2.json, in px): up
# from the floor for the standing ones, down from the tile top for the rest.
const BRAZIER_FLAME := 31.5     # the coals' top: the live flame and its light
const LANTERN_FLAME := 33.0     # inside the glass (its flame is painted): the light
const LANTERN_H := 48.0         # the post's height (what a touch or a slash lights)
const SPOUT_DRIP := 18.0        # the spout's nozzle, where drops swell
const FALL_POUR := 26.5         # the waxfall head's mouth: the column's top
const FALL_W := 9.0             # the column's width at the mouth
const NEST_FLAME := 7.0         # the nest sconce's wick tip (its violet flame)
const NEST_COCOON := 26.5       # the cocoon, where a Gutterwing comes out

var world: Node
var level: RefCounted
var water_cells: Array[Vector2i] = []
var surface: Dictionary = {}     # Vector2i -> true: water cells with open air above
var spouts: Array = []           # {cell, tip, phase, state}
var drops: Array = []            # {p, v, big}
var falls: Array = []            # {cell, x, top, bottom, phase, on, tell, douse_t}
var lanterns: Array = []         # {cell, pos, flame, lit, t, id, brazier, rect}
var nests: Array = []            # {cell, pos, tell, cool, wings: [], out, spawned}
var false_cells: Array[Vector2i] = []
var ripples: Array = []          # {p, t}
var splashes: Array = []         # {p, t}
var braziers_locked := false     # Lights Out: they stay out
var _boost := 0.0
var _boost_mult := 1.0
var _t := 0.0
var _wade_t := 0.0
var _tex := {}
var _theme := ""
var _water := {}                 # the water's colours (_water_col)
var _arena := {}
# v3: the feature modules, by name (only those whose files exist).
const MODULES := {
	"orchard": "res://scripts/features/orchard.gd",
	"clockwork": "res://scripts/features/clockwork.gd",
	"glass": "res://scripts/features/glass.gd",
	"deep": "res://scripts/features/deep.gd",
	"secrets": "res://scripts/features/secrets.gd",
}
const MODULE_ORDER := ["orchard", "clockwork", "glass", "deep", "secrets"]
var modules: Array = []          # built modules, in MODULE_ORDER
var by_name := {}                # name -> module


func build(w: Node, lv: RefCounted) -> void:
	world = w
	level = lv
	_theme = str(lv.theme)
	# A v3 theme's own lantern post (its props map: W3's skull lantern, W4's
	# brass lamp), same size and flame point as v2's (A1).
	var themed: Dictionary = Themes.theme(_theme).get("props", {}) if Themes.has_theme(_theme) else {}
	var alias := {"lantern_post_lit": "lantern_lit", "lantern_post_out": "lantern_out"}
	for n in PROPS:
		var p := "res://art/props/%s.svg" % n
		# (A1's key is lantern_lit / _out; A2's W5-W6 themes name the prop itself.)
		var alt := str(themed.get(n, themed.get(alias.get(n, ""), ""))) if alias.has(n) else ""
		if alt != "" and ResourceLoader.exists("res://art/props/%s.svg" % alt):
			p = "res://art/props/%s.svg" % alt
		if ResourceLoader.exists(p):
			_tex[n] = load(p)
	for y in lv.height:
		for x in lv.width:
			var t: int = lv.tile(x, y)
			if t == LevelData.WATER:
				water_cells.append(Vector2i(x, y))
				if lv.tile(x, y - 1) != LevelData.WATER:
					surface[Vector2i(x, y)] = true
			elif t == LevelData.FALSE_STONE:
				false_cells.append(Vector2i(x, y))
	for e in lv.entities:
		if e["kind"] == "boss":
			_arena = Arena.find(lv, LevelData.cell_floor(e["cell"]))
	for e in lv.entities:
		var cell: Vector2i = e["cell"]
		match e["kind"]:
			"drip":
				spouts.append({"cell": cell, "tip": Vector2((cell.x + 0.5) * TILE, cell.y * TILE + SPOUT_DRIP),
						"phase": fmod(cell.x * 0.37, SPOUT_EVERY), "state": "wait"})
			"waxfall":
				var bottom := cell.y + 1
				while bottom < lv.height and not LevelData.is_solid(lv.tile(cell.x, bottom)):
					bottom += 1
				falls.append({"cell": cell, "x": (cell.x + 0.5) * TILE, "top": cell.y * TILE + FALL_POUR,
						"bottom": float(bottom * TILE), "phase": fmod(cell.x * 0.53, FALL_ON + FALL_OFF), "on": false,
						"tell": false, "douse_t": 0.0})
			"lantern":
				var f := LevelData.cell_floor(cell)
				var br := _in_arena(f)
				var l := {"cell": cell, "pos": f, "brazier": br, "lit": false, "t": 0.0, "id": -1,
						"start_lit": br and LevelData.is_solid(lv.tile(cell.x, cell.y + 1)),
						"flame": f - Vector2(0, BRAZIER_FLAME if br else LANTERN_FLAME),
						"rect": Rect2(f.x - 14, f.y - 36, 28, 36) if br else Rect2(f.x - 11, f.y - LANTERN_H, 22, LANTERN_H)}
				lanterns.append(l)
			"nest":
				var top := Vector2((cell.x + 0.5) * TILE, cell.y * TILE)
				nests.append({"cell": cell, "pos": LevelData.cell_center(cell), "flame": top + Vector2(0, NEST_FLAME),
						"cocoon": top + Vector2(0, NEST_COCOON), "tell": -1.0, "cool": 0.0,
						"wings": [], "out": 0.0, "spawned": 0})
	reset_braziers()
	for name in MODULE_ORDER:
		var path: String = MODULES[name]
		if not ResourceLoader.exists(path):
			continue
		var m = load(path).new()
		m.build(w, lv)
		modules.append(m)
		by_name[name] = m


func module(name: String) -> Object:
	return by_name.get(name)


func _in_arena(p: Vector2) -> bool:
	if _arena.is_empty():
		return false
	return p.x > float(_arena["left"]) and p.x < float(_arena["right"])


# ---------------------------------------------------------------- the step

func step(dt: float) -> void:
	_t += dt
	_boost = maxf(_boost - dt, 0.0)
	var pl: Node2D = world.player
	# Drip spouts: swell, then let go.
	for s in spouts:
		var ph := fmod(_t + float(s["phase"]), SPOUT_EVERY)
		var swelling := ph > SPOUT_EVERY - SPOUT_SWELL
		if swelling and s["state"] == "wait":
			s["state"] = "swell"
		elif not swelling and s["state"] == "swell":
			s["state"] = "wait"
			add_drop(s["tip"] + Vector2(0, 4))
			if _near(s["tip"], 360.0):
				Elites.play(world, "drip", "", 1.0 + fmod(s["tip"].x, 7.0) * 0.02)
	# Drops in flight.
	for d in drops:
		d["v"].y = minf(float(d["v"].y) + 1400.0 * dt, 900.0)
		d["p"] += d["v"] * dt
		var p: Vector2 = d["p"]
		if world.solid_at(p) or _water_at(p) or p.y > level.height * TILE + 40:
			d["dead"] = true
			_splash(Vector2(p.x, floorf(p.y / TILE) * TILE if world.solid_at(p) else p.y))
			continue
		for l in lanterns:
			if l["lit"] and not l["brazier"] and (l["flame"] as Vector2).distance_to(p) < 10.0:
				_put_out(l)
				d["dead"] = true
		if pl.alive and world.state == "play" and pl.rect().grow(2.0).has_point(p):
			d["dead"] = true
			_splash(p)
			world.douse_player()
	drops = drops.filter(func(d): return not d.get("dead", false))
	# Waxfalls: on, off, and the gurgle before.
	for f in falls:
		var ph := fmod(_t + float(f["phase"]), FALL_ON + FALL_OFF)
		var was: bool = f["on"]
		f["on"] = ph < FALL_ON
		f["tell"] = ph > FALL_ON + FALL_OFF - FALL_TELL
		f["douse_t"] = maxf(float(f["douse_t"]) - dt, 0.0)
		if f["on"] and not was and _near(Vector2(f["x"], f["top"]), 420.0):
			Elites.play(world, "waxfall", "")
	# Lanterns burn down and gutter.
	for l in lanterns:
		if not l["lit"]:
			continue
		if not l["brazier"]:
			l["t"] = float(l["t"]) - dt
			if l["t"] <= 0.0:
				_put_out(l)
				continue
		var r := BRAZIER_R if l["brazier"] else LANTERN_R
		var fl := 1.0 + 0.04 * sin(_t * 11.0 + l["pos"].x)
		if not l["brazier"] and float(l["t"]) < LANTERN_GUTTER:
			fl = 0.7 + 0.3 * absf(sin(_t * 9.0 + sin(_t * 23.0) * 2.0))
		if int(l["id"]) >= 0:
			world.move_light(int(l["id"]), l["flame"], r * fl)
	# Nests.
	for n in nests:
		_nest_step(n, dt, pl)
	# Wading ripples, and steam off deep water.
	_wade_t -= dt
	if pl.alive and wading() and absf(pl.velocity.x) > 30.0 and _wade_t <= 0.0:
		_wade_t = 0.22
		ripples.append({"p": Vector2(pl.position.x, _surface_y(pl.position)), "t": 0.0})
	if pl.alive and _deep_at(pl.center()) and world.glow:
		var sy := _surface_y(pl.center())
		world.glow.burst(Vector2(pl.position.x, sy), 16, Color(0.85, 0.88, 0.92, 0.8), 80.0, 0.9, -120.0, 3.0, 60.0)
	for r in ripples:
		r["t"] += dt
	ripples = ripples.filter(func(r): return r["t"] < 0.8)
	for s in splashes:
		s["t"] += dt
	splashes = splashes.filter(func(s): return s["t"] < 0.45)
	for m in modules:
		m.step(dt)


func _near(p: Vector2, r: float) -> bool:
	return world.player != null and (world.player.position as Vector2).distance_to(p) < r


func add_drop(p: Vector2, big := false) -> void:
	## A drop that falls and douses (spouts; the Snuffer's choir uses hazards).
	drops.append({"p": p, "v": Vector2.ZERO, "big": big})


func _splash(p: Vector2) -> void:
	splashes.append({"p": p, "t": 0.0})


func _nest_step(n: Dictionary, dt: float, pl: Node2D) -> void:
	n["wings"] = (n["wings"] as Array).filter(func(w): return is_instance_valid(w) and w.alive)
	n["cool"] = maxf(float(n["cool"]) - dt, 0.0)
	n["out"] = maxf(float(n["out"]) - dt, 0.0)
	if float(n["tell"]) >= 0.0:
		n["tell"] = float(n["tell"]) + dt
		if float(n["tell"]) >= NEST_TELL:
			n["tell"] = -1.0
			n["out"] = 1.6
			var wing: Node2D = world.spawn_enemy("gutterwing", n["cocoon"], {"respawned": int(n["spawned"]) >= NEST_MAX})
			n["spawned"] = int(n["spawned"]) + 1
			if wing:
				(n["wings"] as Array).append(wing)
				wing.died.connect(func(_e, _how): n["cool"] = NEST_AGAIN)
				if world.glow:
					world.glow.burst(n["cocoon"], 10, Color("b890ff"), 90.0, 0.5, 0.0, 2.2)
			n["cool"] = maxf(float(n["cool"]), 2.0)
		return
	if not pl.alive or (n["wings"] as Array).size() >= NEST_MAX or float(n["cool"]) > 0.0:
		return
	if (pl.position as Vector2).distance_to(n["pos"]) < NEST_RANGE and _shows(cocoon_rect(n)):
		n["tell"] = 0.0
		Elites.play(world, "wing_sip", "", 0.8)


static func nest_rect(n: Dictionary) -> Rect2:
	## A nest's sconce as drawn (its tile), where its tell glows.
	var c: Vector2i = n["cell"]
	return Rect2(c.x * TILE, c.y * TILE, TILE, TILE)


static func cocoon_rect(n: Dictionary) -> Rect2:
	## Round a nest's cocoon, where a Gutterwing comes out.
	return Rect2((n["cocoon"] as Vector2) - Vector2(8, 8), Vector2(16, 16))


func _shows(r: Rect2) -> bool:
	return world == null or not world.has_method("in_plain_view") or world.in_plain_view(r)


func touch(player: Node2D) -> void:
	## After the player moved: posts lit by touch, the waxfalls' push.
	var pr: Rect2 = player.rect()
	for l in lanterns:
		if not l["lit"] and (l["rect"] as Rect2).intersects(pr):
			light(l)
	for f in falls:
		if not f["on"]:
			continue
		var col := Rect2(float(f["x"]) - 7.0, float(f["top"]), 14.0, float(f["bottom"]) - float(f["top"]))
		if col.intersects(pr.grow(-2.0)):
			player.velocity.y = maxf(player.velocity.y, FALL_PUSH)
			if float(f["douse_t"]) <= 0.0:
				f["douse_t"] = 0.6
				world.douse_player()
				if world.glow:
					world.glow.burst(player.center() + Vector2(0, -12), 6, Color("f4ead6"), 70.0, 0.35, 300.0, 2.0)
	for m in modules:
		m.touch(player)


func strike(r: Rect2, _attack_id: int) -> void:
	## A swing this tick: posts it touches light up.
	for l in lanterns:
		if (l["rect"] as Rect2).intersects(r):
			light(l)
	for m in modules:
		m.strike(r, _attack_id)


func shot_hit(shot: Dictionary) -> void:
	## A live shot this tick (the World calls it after the shot moved).
	for m in modules:
		m.shot_hit(shot)
		if float(shot.get("life", 1.0)) <= 0.0:
			return


func stood_on(who: Node2D, x: int, y: int) -> void:
	## A body standing on (x, y) this step: modules that care say so.
	for m in modules:
		if m.has_method("stood_on"):
			m.stood_on(who, x, y)


func on_respawn() -> void:
	drops.clear()
	for n in nests:
		n["tell"] = -1.0
		n["cool"] = 1.5
	for m in modules:
		m.on_respawn()


func on_boss_reset() -> void:
	for m in modules:
		m.on_boss_reset()


func on_fall(at: Vector2) -> void:
	## A fall (pit, void, deep water) put him back at `at`: the modules that
	## care (glass.gd: the broken panes ahead come back, as a snuff's do).
	for m in modules:
		if m.has_method("on_fall"):
			m.on_fall(at)


func reflectors() -> Array:
	var out := []
	for m in modules:
		out.append_array(m.reflectors())
	return out


# ---------------------------------------------------------------- lanterns and braziers

func light(l: Dictionary, quiet := false) -> bool:
	## Lights a post or brazier (a lit lantern's timer starts over).
	if l["brazier"] and braziers_locked:
		return false
	var fresh: bool = not l["lit"]
	l["lit"] = true
	l["t"] = LANTERN_LIFE
	if int(l["id"]) < 0:
		l["id"] = world.add_light(l["flame"], BRAZIER_R if l["brazier"] else LANTERN_R, 0.9, -1.0, "brazier" if l["brazier"] else "lantern")
	if fresh and not quiet:
		if int(world.get("world_n")) == 3 and not l["brazier"]:
			Elites.play(world, "skull_lantern", "lantern_light")   # W3's skull lamps (A7; its own take at 1.0)
		else:
			Elites.play(world, "lantern_light", "altar", 1.3)
		if world.glow:
			world.glow.burst(l["flame"], 12, Color("f7b64a"), 110.0, 0.5, -80.0, 2.3)
	return fresh


func _put_out(l: Dictionary) -> void:
	if not l["lit"]:
		return
	l["lit"] = false
	if int(l["id"]) >= 0:
		world.remove_light(int(l["id"]))
	l["id"] = -1
	if world.glow:
		for i in 3:
			world.glow.burst(l["flame"] + Vector2(0, -4 - i * 6), 3, Color(0.6, 0.58, 0.66, 0.7), 30.0, 0.9, -60.0, 3.0)


func braziers() -> Array:
	return lanterns.filter(func(l): return l["brazier"])


func lit_braziers() -> Array:
	return lanterns.filter(func(l): return l["brazier"] and l["lit"])


func snuff_brazier(l: Dictionary) -> void:
	## The Snuffer caps one.
	if l["lit"]:
		_put_out(l)
		Elites.play(world, "brazier_snuff", "snuff")


func relight_nearest(p: Vector2) -> Dictionary:
	## A Gutter Call moth killed: the nearest dark brazier catches again.
	var best := {}
	var bd := INF
	for l in braziers():
		if l["lit"]:
			continue
		var d: float = (l["flame"] as Vector2).distance_to(p)
		if d < bd:
			bd = d
			best = l
	if not best.is_empty():
		light(best)
	return best


func reset_braziers(all := false) -> void:
	## The fight's start (and a retry): the floor braziers lit, the ledge
	## ones dark. all: every one lit (he's gone).
	braziers_locked = false
	for l in braziers():
		if all or l["start_lit"]:
			light(l, true)
		else:
			_put_out(l)


func lights_out() -> void:
	## Phase 3: every brazier goes out for good.
	for l in braziers():
		_put_out(l)
	braziers_locked = true


func boost(mult: float, sec: float) -> void:
	## A brief brighter flame ("Snatched back!").
	_boost_mult = mult
	_boost = sec


# ---------------------------------------------------------------- water

func wading() -> bool:
	var pl: Node2D = world.player
	var r: Rect2 = pl.rect()
	for x in [floori((r.position.x + 2.0) / TILE), floori((r.end.x - 2.0) / TILE)]:
		var y := floori((r.end.y - 4.0) / TILE)
		if level.tile(x, y) == LevelData.WATER and not level.is_deep(x, y):
			return true
	return false


func _water_at(p: Vector2) -> bool:
	var c := Vector2i(floori(p.x / TILE), floori(p.y / TILE))
	return level.tile(c.x, c.y) == LevelData.WATER and p.y > c.y * TILE + 8.0


func _deep_at(p: Vector2) -> bool:
	var c := Vector2i(floori(p.x / TILE), floori(p.y / TILE))
	return level.is_deep(c.x, c.y) and p.y > c.y * TILE + 8.0


func _surface_y(p: Vector2) -> float:
	## The water line above or at p.
	var x := floori(p.x / TILE)
	var y := floori(p.y / TILE)
	while y > 0 and level.tile(x, y - 1) == LevelData.WATER:
		y -= 1
	return y * TILE + _line_off(Vector2i(x, y))


func light_mult() -> float:
	## Multiplies the hero's light: wading x0.75, a moth latching on (its
	## first second; the "latch" status does the rest), a snatch-back boost.
	var m := 1.0
	if world.player != null and world.player.alive and wading():
		m *= 0.75
	for e in world.enemies:
		if e.alive and e.has_method("latch_light"):
			m *= float(e.latch_light())
	if _boost > 0.0:
		m *= _boost_mult
	return m


func lights() -> Array:
	## Spout glints, nest glows (lanterns and braziers are world lights).
	var out := []
	var view: Rect2 = world.view_rect().grow(80.0)
	for s in spouts:
		if s["state"] == "swell" and view.has_point(s["tip"]):
			var k := _swell(s)
			out.append({"p": s["tip"] + Vector2(0, 4), "r": 14.0 + 16.0 * k, "s": 0.6})
	for n in nests:
		if view.has_point(n["pos"]):
			var tell: float = n["tell"]
			if tell >= 0.0:
				out.append({"p": n["flame"], "r": 40.0 + 50.0 * tell / NEST_TELL, "s": 0.75})
			elif float(n["out"]) <= 0.0:
				out.append({"p": n["flame"], "r": 44.0, "s": 0.5})
	for m in modules:
		out.append_array(m.lights())
	return out


func _swell(s: Dictionary) -> float:
	var ph := fmod(_t + float(s["phase"]), SPOUT_EVERY)
	return clampf((ph - (SPOUT_EVERY - SPOUT_SWELL)) / SPOUT_SWELL, 0.0, 1.0)


# ---------------------------------------------------------------- drawing

func draw_under(ci: CanvasItem) -> void:
	## Over the tiles, under the props and monsters: water, spouts, falls,
	## posts, nests and false stone's crack.
	var view: Rect2 = world.view_rect().grow(64.0)
	_draw_water(ci, view)
	for f in falls:
		if view.intersects(Rect2(float(f["x"]) - 20.0, float(f["top"]) - 20.0, 40.0, float(f["bottom"]) - float(f["top"]) + 40.0)):
			_draw_fall(ci, f)
	for s in spouts:
		if view.has_point(s["tip"]):
			_draw_spout(ci, s)
	for l in lanterns:
		if view.has_point(l["pos"]):
			if l["brazier"]:
				_draw_brazier(ci, l)
			else:
				_draw_post(ci, l)
	for n in nests:
		if view.has_point(n["pos"]):
			_draw_nest(ci, n)
	_draw_false_stone(ci, view)
	for m in modules:
		m.draw_under(ci)


func _water_col(deep := false) -> Color:
	## v2's colour for its themes; a v3 theme's own ("water", "water_deep":
	## W3's bog and black sap, W4's cold water), else v2's teal. (Read once
	## at build: _water.)
	if _water.is_empty():
		_water = {"base": WATER.get(_theme, WATER[""])}
		if not WATER.has(_theme) and Themes.has_theme(_theme):
			var th: Dictionary = Themes.theme(_theme)
			_water["base"] = th.get("water", WATER[""])
			if th.has("water_deep"):
				_water["deep"] = th["water_deep"]
	return _water["deep"] if deep and _water.has("deep") else _water["base"]


func _crest_col() -> Color:
	## The crest above the dark: a v3 theme's own "crest" (W6's silver, A2),
	## else the water's colour lightened (v2's, and W3-W4's).
	var fallback := _water_col().lightened(0.55)   # (fills _water's base first)
	if not _water.has("crest"):
		var c = null
		if not WATER.has(_theme) and Themes.has_theme(_theme):
			c = Themes.theme(_theme).get("crest")
		_water["crest"] = c if c is Color else fallback
	return _water["crest"]


func _line_off(c: Vector2i) -> float:
	## Where the water line sits in a surface cell: deep water at +8 (the
	## drowning line), a shallow wade lower, at +13.
	return 8.0 if level.is_deep(c.x, c.y) else 13.0


func _draw_water(ci: CanvasItem, view: Rect2) -> void:
	var base := _water_col()
	for c in water_cells:
		var p := Vector2(c.x * TILE, c.y * TILE)
		if not view.has_point(p + Vector2(16, 16)):
			continue
		if level.tile(c.x, c.y) != LevelData.WATER:
			continue
		var deep: bool = level.is_deep(c.x, c.y) or level.tile(c.x, c.y - 1) == LevelData.WATER
		var col := base.darkened(0.25 if deep else 0.0)
		if deep and _water.has("deep"):
			col = _water_col(true)
		col.a = 0.82 if deep else 0.5
		if surface.has(c):
			var off := _line_off(c)
			# A wade's ends slope down to the floor, like a puddle's edge.
			var end_l: bool = not deep and level.tile(c.x - 1, c.y) != LevelData.WATER
			var end_r: bool = not deep and level.tile(c.x + 1, c.y) != LevelData.WATER
			var band := PackedVector2Array()
			for i in 9:
				var xx := p.x + i * 4.0
				var yy := p.y + off + sin(_t * 2.2 + xx * 0.11) * 1.6
				if end_l and i < 4:
					yy = lerpf(p.y + TILE - 2.0, yy, i / 4.0)
				if end_r and i > 4:
					yy = lerpf(yy, p.y + TILE - 2.0, (i - 4) / 4.0)
				band.append(Vector2(xx, yy))
			var pts := PackedVector2Array(band)
			pts.append(Vector2(p.x + TILE, p.y + TILE))
			pts.append(Vector2(p.x, p.y + TILE))
			ci.draw_colored_polygon(pts, col)
			ci.draw_polyline(band, base.lightened(0.35), 2.0)
			if not deep:
				# The floor showing through.
				ci.draw_rect(Rect2(p + Vector2(0, TILE - 4), Vector2(TILE, 4)), Color(base.lightened(0.2), 0.35))
		else:
			ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), col)
		if deep and (c.x * 7 + c.y * 3) % 5 == 0:
			# A slow bubble rising.
			var k := fmod(_t * 0.4 + c.x * 0.31, 1.0)
			ci.draw_circle(p + Vector2(10 + (c.x % 3) * 6, TILE - k * TILE), 1.6, Color(base.lightened(0.5), 0.5 * (1.0 - k)))


func _draw_fall(ci: CanvasItem, f: Dictionary) -> void:
	var x: float = f["x"]
	var top: float = f["top"]
	var bot: float = f["bottom"]
	var wax := Color("efe2c0")
	var shade := Color("c9b48a")
	var head := Vector2(x, top)
	if f["on"]:
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var inner := PackedVector2Array()
		var yy := top
		while yy <= bot:
			var k := (yy - top) / maxf(bot - top, 1.0)
			var wob := sin(yy * 0.11 - _t * 14.0) * 1.6 * minf(1.0, (yy - top) / 12.0)
			var wide := FALL_W * 0.5 + k * 3.5
			left.append(Vector2(x - wide + wob, yy))
			right.append(Vector2(x + wide + wob * 0.6, yy))
			inner.append(Vector2(x - wide * 0.35 + wob * 0.8, yy))
			yy += 6.0
		var body := PackedVector2Array(left)
		var rev := right.duplicate()
		rev.reverse()
		body.append_array(rev)
		var outl := PackedVector2Array()
		for q in left:
			outl.append(q + Vector2(-2, 0))
		var rev2 := PackedVector2Array()
		for q in rev:
			rev2.append(q + Vector2(2, 0))
		outl.append_array(rev2)
		ci.draw_colored_polygon(outl, Color("1c1830"))
		ci.draw_colored_polygon(body, shade)
		var gloss := PackedVector2Array(left)
		var rin := inner.duplicate()
		rin.reverse()
		gloss.append_array(rin)
		ci.draw_colored_polygon(gloss, wax)
		# Lumps of wax riding down it.
		var y := top + fmod(_t * 260.0, 24.0)
		while y < bot - 6.0:
			ci.draw_circle(Vector2(x + sin(y * 0.11 - _t * 14.0) * 1.6 - 1.0, y), 3.2, Color("fff6dc"))
			y += 24.0
		# Splashes where it lands.
		for i in 4:
			var k2 := fmod(_t * 2.6 + i * 0.25, 1.0)
			var sx := x + (i - 1.5) * 7.0 + (i - 1.5) * k2 * 6.0
			ci.draw_circle(Vector2(sx, bot - 4.0 - sin(k2 * PI) * 10.0), 2.2 * (1.0 - k2 * 0.5), wax)
		# Where it lands: a sagging pool of wax.
		var pool := PackedVector2Array()
		for i in 13:
			var a := PI * i / 12.0
			pool.append(Vector2(x + cos(a) * 20.0, bot - sin(a) * (6.0 + sin(_t * 8.0 + i) * 1.2)))
		ci.draw_colored_polygon(pool, shade)
	else:
		# Off: a thin dribble, and bubbles at the head just before it starts.
		var len := 10.0 + 6.0 * sin(_t * 3.0 + x)
		ci.draw_rect(Rect2(x - 2, top, 4, len), shade)
		ci.draw_circle(Vector2(x, top + len), 2.6, wax)
		if f["tell"]:
			for i in 3:
				var k := fmod(_t * 3.0 + i * 0.33, 1.0)
				ci.draw_circle(head + Vector2((i - 1) * 6.0, 6.0 + k * 10.0), 2.0 + k * 2.0, wax)
	if _tex.has("waxfall_head"):
		_prop_top(ci, "waxfall_head", Vector2(x, f["cell"].y * TILE))
	else:
		var y0: float = f["cell"].y * TILE
		ci.draw_rect(Rect2(x - 15, y0, 30, top - y0), Color("1c1830"))
		ci.draw_rect(Rect2(x - 13, y0, 26, top - y0 - 3.0), Color("6a5236"))
		ci.draw_rect(Rect2(x - 13, top - 6.0, 26, 3), Color("4a3622"))
		ci.draw_rect(Rect2(x - 5, top - 3.0, 10, 4), wax)


func _draw_spout(ci: CanvasItem, s: Dictionary) -> void:
	var tip: Vector2 = s["tip"]
	var ceil := Vector2(tip.x, s["cell"].y * TILE)
	if _tex.has("drip_spout"):
		_prop_top(ci, "drip_spout", ceil)
	else:
		var pts := PackedVector2Array([ceil + Vector2(-9, 0), ceil + Vector2(9, 0), tip + Vector2(3, -1), tip + Vector2(-3, -1)])
		ci.draw_colored_polygon(PackedVector2Array([ceil + Vector2(-11, -1), ceil + Vector2(11, -1), tip + Vector2(5, 1), tip + Vector2(-5, 1)]), Color("1c1830"))
		ci.draw_colored_polygon(pts, Color("d8c8a0"))
		ci.draw_line(ceil + Vector2(-6, 2), tip + Vector2(-2, -2), Color("f4ead6"), 2.0)
	if s["state"] == "swell":
		var k := _swell(s)
		ci.draw_circle(tip + Vector2(0, 2 + 3 * k), 1.5 + 3.0 * k, Color("bfe0f0"))


func _draw_post(ci: CanvasItem, l: Dictionary) -> void:
	var f: Vector2 = l["pos"]
	var key := "lantern_post_lit" if l["lit"] else "lantern_post_out"
	if _tex.has(key):
		_prop_floor(ci, key, f)
		return
	var ol := Color("1c1830")
	ci.draw_rect(Rect2(f.x - 9, f.y - 5, 18, 5), ol)
	ci.draw_rect(Rect2(f.x - 7, f.y - 4, 14, 3), Color("4a4458"))
	ci.draw_rect(Rect2(f.x - 3, f.y - 40, 6, 36), ol)
	ci.draw_rect(Rect2(f.x - 1.5, f.y - 40, 3, 36), Color("5a5470"))
	# The lantern box: iron frame, glass that glows when lit.
	var box := Rect2(f.x - 8, f.y - 56, 16, 16)
	ci.draw_rect(box.grow(2.0), ol)
	ci.draw_rect(box, Color("ffe2a0") if l["lit"] else Color("2e2a3a"))
	ci.draw_rect(Rect2(box.position.x + 7, box.position.y, 2, 16), ol)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(f.x - 11, f.y - 57), Vector2(f.x + 11, f.y - 57), Vector2(f.x, f.y - 64)]), ol)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(f.x - 8, f.y - 58), Vector2(f.x + 8, f.y - 58), Vector2(f.x, f.y - 62)]), Color("5a5470"))


func _draw_brazier(ci: CanvasItem, l: Dictionary) -> void:
	var f: Vector2 = l["pos"]
	var key := "brazier_lit" if l["lit"] else "brazier_out"
	if _tex.has(key):
		_prop_floor(ci, key, f)
		return
	var ol := Color("1c1830")
	var iron := Color("4a4458")
	ci.draw_rect(Rect2(f.x - 12, f.y - 4, 24, 4), ol)
	ci.draw_rect(Rect2(f.x - 3, f.y - 18, 6, 15), ol)
	ci.draw_rect(Rect2(f.x - 1.5, f.y - 18, 3, 15), iron)
	var bowl := PackedVector2Array()
	for i in 11:
		var a := PI * i / 10.0
		bowl.append(Vector2(f.x + cos(a) * 15.0, f.y - 22.0 + sin(a) * 7.0))
	ci.draw_colored_polygon(bowl, ol)
	var inner := PackedVector2Array()
	for i in 11:
		var a := PI * i / 10.0
		inner.append(Vector2(f.x + cos(a) * 13.0, f.y - 22.0 + sin(a) * 5.5))
	ci.draw_colored_polygon(inner, Color("6a5a70"))
	ci.draw_rect(Rect2(f.x - 15, f.y - 24, 30, 3), ol)
	ci.draw_rect(Rect2(f.x - 13, f.y - 24, 26, 2), Color("8a7a90") if not l["lit"] else Color("f7b64a"))


func _draw_nest(ci: CanvasItem, n: Dictionary) -> void:
	var p: Vector2 = n["pos"]
	if _tex.has("nest_sconce"):
		var tx: Texture2D = _tex["nest_sconce"]
		var sz := tx.get_size() * 0.25
		ci.draw_texture_rect(tx, Rect2(p - sz * 0.5, sz), false)
	else:
		var ol := Color("1c1830")
		ci.draw_rect(Rect2(p.x - 3, p.y - 2, 6, 14), ol)
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -3), p + Vector2(10, -3), p + Vector2(6, 6), p + Vector2(-6, 6)]), ol)
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -2), p + Vector2(8, -2), p + Vector2(5, 4), p + Vector2(-5, 4)]), Color("5a4a78"))
		# Wisps of cocoon silk.
		for i in 3:
			ci.draw_line(p + Vector2(-7 + i * 7, 5), p + Vector2(-5 + i * 6, 12 + (i % 2) * 3), Color("d8e8c8", 0.6), 1.2)


func _draw_false_stone(ci: CanvasItem, view: Rect2) -> void:
	## The hairline crack, only where a light reaches.
	if false_cells.is_empty():
		return
	var pl: Node2D = world.player
	var hero_r: float = world.hero_light_radius() if pl and pl.alive else 0.0
	var lit: Array = world.lights_tagged("lantern") + world.lights_tagged("brazier")
	for c in false_cells:
		if level.tile(c.x, c.y) != LevelData.FALSE_STONE:
			continue
		var mid := LevelData.cell_center(c)
		if not view.has_point(mid):
			continue
		var k := 0.0
		if hero_r > 0.0:
			k = clampf((hero_r * 0.85 - mid.distance_to(pl.center())) / 40.0, 0.0, 1.0)
		for l in lit:
			k = maxf(k, clampf((float(l["r"]) * 0.8 - mid.distance_to(l["p"])) / 40.0, 0.0, 1.0))
		if k <= 0.0:
			continue
		var p := Vector2(c.x * TILE, c.y * TILE)
		if _tex.has("false_stone_crack"):
			ci.draw_texture_rect(_tex["false_stone_crack"], Rect2(p, Vector2(TILE, TILE)), false, Color(1, 1, 1, k))
			continue
		var a := p + Vector2(9, 3)
		var crack := PackedVector2Array([a, a + Vector2(4, 6), a + Vector2(2, 11), a + Vector2(8, 17), a + Vector2(6, 25)])
		ci.draw_polyline(crack, Color(0.08, 0.05, 0.1, 0.9 * k), 1.6)
		ci.draw_line(a + Vector2(4, 6), a + Vector2(11, 8), Color(0.08, 0.05, 0.1, 0.8 * k), 1.2)
		ci.draw_line(a + Vector2(8, 17), a + Vector2(15, 15), Color(0.08, 0.05, 0.1, 0.8 * k), 1.2)
		ci.draw_polyline(crack, Color(1.0, 0.9, 0.7, 0.18 * k), 0.8)


func _prop_floor(ci: CanvasItem, key: String, f: Vector2) -> void:
	var tx: Texture2D = _tex[key]
	var sz := tx.get_size() * 0.25
	ci.draw_texture_rect(tx, Rect2(f - Vector2(sz.x * 0.5, sz.y), sz), false)


func _prop_top(ci: CanvasItem, key: String, top: Vector2) -> void:
	var tx: Texture2D = _tex[key]
	var sz := tx.get_size() * 0.25
	ci.draw_texture_rect(tx, Rect2(top - Vector2(sz.x * 0.5, 0), sz), false)


func draw_glow(glow: Node2D) -> void:
	## Above the dark: water crests, drops, flames on lit posts, shine on falls.
	var view: Rect2 = world.view_rect().grow(64.0)
	var base := _crest_col()
	for c in surface:
		var p := Vector2(c.x * TILE, c.y * TILE)
		if not view.has_point(p) or level.tile(c.x, c.y) != LevelData.WATER:
			continue
		var off := _line_off(c)
		var shallow: bool = not level.is_deep(c.x, c.y)
		var pts := PackedVector2Array()
		for i in 9:
			var xx := p.x + i * 4.0
			var yy := p.y + off + sin(_t * 2.2 + xx * 0.11) * 1.6
			if shallow and level.tile(c.x - 1, c.y) != LevelData.WATER and i < 4:
				yy = lerpf(p.y + TILE - 2.0, yy, i / 4.0)
			if shallow and level.tile(c.x + 1, c.y) != LevelData.WATER and i > 4:
				yy = lerpf(yy, p.y + TILE - 2.0, (i - 4) / 4.0)
			pts.append(Vector2(xx, yy))
		glow.draw_polyline(pts, Color(base, 0.35), 1.5)
	for r in ripples:
		var k: float = r["t"] / 0.8
		var pts2 := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			pts2.append(r["p"] + Vector2(cos(a) * (4.0 + k * 18.0), sin(a) * (1.5 + k * 3.0)))
		glow.draw_polyline(pts2, Color(base, 0.6 * (1.0 - k)), 1.5)
	for d in drops:
		var p: Vector2 = d["p"]
		var sz := 1.4 if d["big"] else 1.0
		glow.draw_circle(p, 6.0 * sz, Color(0.75, 0.9, 1.0, 0.18))
		glow.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6) * sz, p + Vector2(3.5, 1) * sz, p + Vector2(0, 4) * sz, p + Vector2(-3.5, 1) * sz]), Color("d8f0ff"))
	for s in splashes:
		var k: float = s["t"] / 0.45
		for i in 4:
			var a := -PI * (0.15 + 0.7 * i / 3.0)
			glow.draw_circle(s["p"] + Vector2(cos(a), sin(a)) * (3.0 + k * 12.0) + Vector2(0, k * k * 8.0), 1.6 * (1.0 - k) + 0.4, Color(0.85, 0.95, 1.0, 1.0 - k))
	for s in spouts:
		if s["state"] == "swell" and view.has_point(s["tip"]):
			var k := _swell(s)
			var tip: Vector2 = s["tip"] + Vector2(0, 2 + 3 * k)
			glow.draw_circle(tip, 2.0 + 3.0 * k, Color(0.8, 0.95, 1.0, 0.35 + 0.5 * k))
			if k > 0.6:
				# The glint: a small four-point star.
				var g := 3.0 + 5.0 * (k - 0.6) / 0.4
				glow.draw_line(tip + Vector2(-g, 0), tip + Vector2(g, 0), Color(1, 1, 1, 0.9), 1.2)
				glow.draw_line(tip + Vector2(0, -g), tip + Vector2(0, g), Color(1, 1, 1, 0.9), 1.2)
	for f in falls:
		if not view.intersects(Rect2(float(f["x"]) - 20.0, float(f["top"]), 40.0, float(f["bottom"]) - float(f["top"]))):
			continue
		if f["on"]:
			var y := float(f["top"]) + fmod(_t * 260.0 + 12.0, 24.0)
			while y < float(f["bottom"]) - 4.0:
				glow.draw_line(Vector2(float(f["x"]) - 3, y), Vector2(float(f["x"]) - 3, y + 7), Color(1.0, 0.97, 0.85, 0.45), 2.0)
				y += 24.0
		elif f["tell"]:
			glow.draw_circle(Vector2(f["x"], float(f["top"]) + 2.0), 7.0, Color(1.0, 0.95, 0.8, 0.25 + 0.2 * sin(_t * 30.0)))
	for l in lanterns:
		if not view.has_point(l["flame"]):
			continue
		if l["lit"]:
			var gut: bool = not l["brazier"] and float(l["t"]) < LANTERN_GUTTER
			if l["brazier"]:
				# A live flame on the coals.
				glow.flame(l["flame"] + Vector2(0, 2), 16.0, l["pos"].x, true)
			elif _tex.has("lantern_post_lit"):
				# The flame is painted in the glass: the glass just glows,
				# and flickers when the lantern is nearly spent.
				var fl := 1.0 if not gut else 0.55 + 0.45 * absf(sin(_t * 9.0 + sin(_t * 23.0) * 2.0))
				glow.draw_circle(l["flame"], 11.0, Color(1.0, 0.75, 0.35, 0.14 * fl))
				glow.draw_circle(l["flame"], 5.5, Color(1.0, 0.85, 0.5, 0.22 * fl))
			else:
				glow.flame(l["flame"] + Vector2(0, 4), 9.0, l["pos"].x, false, gut)
		elif l["brazier"] and braziers_locked:
			var k := fmod(_t * 0.6 + l["pos"].x, 1.0)
			glow.draw_circle(l["flame"] + Vector2(sin(_t + k * 4.0) * 3.0, -k * 24.0), 2.0 + k * 3.0, Color(0.6, 0.58, 0.68, 0.35 * (1.0 - k)))
	for n in nests:
		if not view.has_point(n["pos"]):
			continue
		var tell: float = n["tell"]
		var p: Vector2 = n["flame"]
		if tell >= 0.0:
			var k := tell / NEST_TELL
			glow.draw_circle(p + Vector2(0, -3), 6.0 + 8.0 * k, Color(0.7, 0.5, 1.0, 0.25 + 0.3 * k))
			_violet_flame(glow, p, 7.0 + 3.0 * k, Color("e0d0ff"))
		elif float(n["out"]) <= 0.0:
			glow.draw_circle(p + Vector2(0, -3), 5.0, Color(0.7, 0.5, 1.0, 0.25))
			_violet_flame(glow, p, 6.0, Color("c8a8ff"))
	for m in modules:
		m.draw_glow(glow)
	# Vengeful shards (world's glow has no picture for them yet).
	for h in world.hazards:
		if h["kind"] == "shard" and h.get("delay", 0.0) <= 0.0:
			var c: Vector2 = (h["rect"] as Rect2).get_center()
			var dv: Vector2 = (h["vel"] as Vector2).normalized()
			glow.draw_circle(c, 8.0, Color(1.0, 0.3, 0.3, 0.22))
			glow.draw_colored_polygon(PackedVector2Array([c + dv * 7.0, c + dv.orthogonal() * 3.0, c - dv * 5.0, c - dv.orthogonal() * 3.0]), Color("ffd0c8"))


func _violet_flame(glow: Node2D, base: Vector2, h: float, col: Color) -> void:
	## A nest's little violet flame on its wick: a flickering teardrop.
	var hh := h * (1.0 + 0.1 * sin(_t * 15.0 + base.x))
	var r := h * 0.3
	var sway := sin(_t * 6.0 + base.x) * 0.8
	var pts := PackedVector2Array()
	for k in range(0, 9):
		var a := PI * k / 8.0
		pts.append(base + Vector2(r * cos(a), -r + r * sin(a)))
	pts.append(base + Vector2(-r * 0.8, -hh * 0.55))
	pts.append(base + Vector2(sway, -hh))
	pts.append(base + Vector2(r * 0.8, -hh * 0.55))
	glow.draw_colored_polygon(pts, col)


func assign_elites(rng: RandomNumberGenerator) -> void:
	## Dreads (placed by 'D') and the Anointed picked here never count as
	## fodder and never respawn: first the anoint: header's (_anoint_forced),
	## then the random picks (Elites.pick_elites).
	for e in world.enemies:
		if e.tier != "":
			e.ordinary = false
	_anoint_forced()
	for pick in Elites.pick_elites(world, level, rng):
		var en: Node2D = pick["enemy"]
		en.make_elite("anointed", pick["omens"])
		var cell = en.spawn.get("cell", Vector2i(-1, -1))
		world.spawns = world.spawns.filter(func(sp): return sp["cell"] != cell)


func _anoint_forced() -> void:
	## The level's anoint: header (Elites.anoint_specs), any level: the
	## monster placed at each cell is Anointed every run, with the header's
	## Omens where its kind may carry them (Elites.forced_omens, else rolled
	## as the World's would be) and its name on the plate. Outside
	## pick_elites' max; it never respawns. The seed is the secrets' own
	## (3-S's two roll what they always rolled).
	var specs := Elites.anoint_specs(level)
	if specs.is_empty():
		return
	var by_cell := {}
	for s in specs:
		by_cell[s["cell"]] = s
	var r := RandomNumberGenerator.new()
	r.seed = hash("anoint|%s|%s" % [level.id, str(world.diff)])
	var rules: Dictionary = world.elite_rules() if world.has_method("elite_rules") else {}
	var wn = world.get("world_n")
	for en in world.enemies:
		if not is_instance_valid(en) or en.tier != "" or not en.has_method("make_elite") or en.get("copy"):
			continue
		var c = en.spawn.get("cell", Vector2i(-1, -1))
		if not by_cell.has(c):
			continue
		var s: Dictionary = by_cell[c]
		if str(s["name"]) != "":
			en.elite_name = str(s["name"])
		en.make_elite("anointed", Elites.forced_omens(en.kind, s["omens"], str(world.diff), int(wn) if wn != null else 0, r, rules))
		var cc: Vector2i = c
		world.spawns = world.spawns.filter(func(sp): return sp["cell"] != cc)


# ---------------------------------------------------------------- the v3 queries
# Each forwards to the module that owns it; without that module, an answer
# from the tiles (or "nothing here").

func _call(name: String, method: String, args: Array, fallback):
	var m = by_name.get(name)
	if m != null and m.has_method(method):
		return m.callv(method, args)
	return fallback


func vine_at(cell: Vector2i) -> bool:
	return _call("orchard", "vine_at", [cell], LevelData.is_climb(level.tile(cell.x, cell.y)))


func vine_lane(cell: Vector2i) -> Dictionary:
	## {x, y0, y1}: the vine run through cell (tile coordinates), or {}.
	var m = by_name.get("orchard")
	if m != null and m.has_method("vine_lane"):
		return m.vine_lane(cell)
	if not LevelData.is_climb(level.tile(cell.x, cell.y)):
		return {}
	var y0 := cell.y
	var y1 := cell.y
	while LevelData.is_climb(level.tile(cell.x, y0 - 1)):
		y0 -= 1
	while LevelData.is_climb(level.tile(cell.x, y1 + 1)):
		y1 += 1
	return {"x": cell.x, "y0": y0, "y1": y1}


func vine_present(x: int, y: int) -> bool:
	return _call("orchard", "vine_present", [x, y], LevelData.is_climb(level.tile(x, y)))


func add_spores(p: Vector2, r: float, life: float, source: Object = null) -> void:
	_call("orchard", "add_spores", [p, r, life, source], null)


func spores_at(p: Vector2) -> bool:
	return _call("orchard", "spores_at", [p], false)


func burn_spores(p: Vector2, r: float) -> void:
	_call("orchard", "burn_spores", [p, r], null)


func slick_at(p: Vector2) -> bool:
	var m = by_name.get("clockwork")
	if m != null and m.has_method("slick_at"):
		return m.slick_at(p)
	return LevelData.is_slick(level.tile(floori(p.x / TILE), floori(p.y / TILE)))


func break_glass(cell: Vector2i) -> void:
	_call("glass", "break_glass", [cell], null)


func strain_glass(cell: Vector2i, amount: float) -> void:
	_call("glass", "strain_glass", [cell, amount], null)


func reverse_belts(x0: int, x1: int) -> void:
	_call("clockwork", "reverse_belts", [x0, x1], null)


func belt_dir(cell: Vector2i, dir: int) -> int:
	return int(_call("clockwork", "belt_dir", [cell, dir], dir))


func toll(cell: Vector2i) -> void:
	_call("deep", "toll", [cell], null)


func still_at(p: Vector2) -> bool:
	var m = by_name.get("deep")
	if m != null and m.has_method("still_at"):
		return m.still_at(p)
	return level.tile(floori(p.x / TILE), floori(p.y / TILE)) == LevelData.STILL


func put_out(l: Dictionary) -> void:
	## The Stillmaw swallows a light (never one tagged "anchor"): a v2
	## lantern post or brazier here, a module's lamp there (deep.gd).
	if _is_lantern(l):
		if not _anchored(l):
			_put_out(l)
		return
	_call("deep", "put_out", [l], null)


func relight(l: Dictionary, extra := 0.0) -> void:
	## A swallowed light comes back (the Stillmaw's choke: extra seconds on it).
	if _is_lantern(l):
		light(l)
		if l.has("t"):
			l["t"] = float(l["t"]) + extra
		return
	_call("deep", "relight", [l, extra], null)


func _is_lantern(l: Dictionary) -> bool:
	for x in lanterns:
		if is_same(x, l):
			return true
	return false


func _anchored(l: Dictionary) -> bool:
	## A light tagged "anchor" (it feeds required dawnglass): on the dict, or
	## on the World light it lit.
	if bool(l.get("anchor", false)) or str(l.get("tag", "")).contains("anchor"):
		return true
	if int(l.get("id", -1)) >= 0 and world.has_method("light_by_id"):
		var wl: Dictionary = world.light_by_id(int(l["id"]))
		return str(wl.get("tag", "")).contains("anchor")
	return false


func lamps() -> Array:
	## The fixed lamp dicts (for the Stillmaw): v2's lanterns and the modules'.
	var out: Array = lanterns.duplicate()
	var m = by_name.get("deep")
	if m != null and m.has_method("lamps"):
		out.append_array(m.lamps())
	return out


func gust_at(p: Vector2) -> Vector2:
	return _call("glass", "gust_at", [p], Vector2.ZERO)


func wind_at(p: Vector2) -> float:
	## How far the wind bends a flame or a cape at p, -1..1 (0 when calm):
	## glow.gd's flame and wick_rig.gd's cape (A2).
	return _call("glass", "wind_at", [p], clampf(gust_at(p).x / 120.0, -1.0, 1.0))


func in_hush_zone(p: Vector2) -> bool:
	var m = by_name.get("deep")
	if m != null and m.has_method("in_hush_zone"):
		return m.in_hush_zone(p)
	var x := floori(p.x / TILE)
	for r in level.hush_cols:
		if x >= int(r["x0"]) and x <= int(r["x1"]):
			return true
	return false


func tide_x() -> float:
	return float(_call("deep", "tide_x", [], -INF))


func candles() -> Dictionary:
	## {lit, total}: the Vigil candles (the results screen counts them).
	return _call("deep", "candles", [], {"lit": 0, "total": 0})
