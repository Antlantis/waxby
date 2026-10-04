extends "res://scripts/features/feature.gd"
## World 5, the Shattered Sanctum (WL5): glass, gusts and dawnglass
## (spec §3.2, decisions.md "Feel and terrain", contract.md §4). Every number
## that differs by difficulty is in DIFF_KNOBS (still provisional until the
## owner has played W3-W4: tune them there, never in the levels).
##
##   glass G      strain per pane, 0..1. Each pane Wick sets foot on (from the
##                air or walking onto it) takes glass_land once; each second
##                a pane stays under him adds glass_stand. So a pane he has
##                crossed once shows a crack, and the next landing and a
##                short stand breaks it: after one landing a pane lasts
##                (1 - glass_land) / glass_stand s of standing (1.09 s on
##                Dusk, the owner's feel lab). An enemy shot adds SHOT_STRAIN;
##                break_glass (Glassmites, the Saint's Shatter, a Paneguard's
##                Glass Cut, a beam) sets 1. Cracks show at 0.4 and 0.8 (on
##                the glow layer: they read in the dark); at 1 a FLASH, then
##                air, with shards; it reforms glass_reform later over a
##                SHIMMER, never into a body, and the strain starts over.
##                Hero attacks never strain it; monsters walking on it don't.
##                (An enemy shot is caught one step before it meets the pane:
##                the World ends a shot on a solid tile before shot_hit.)
##                Inside a boss arena (Arena.find's span) it takes no standing
##                strain, only a real landing strains it (walking from pane to
##                pane doesn't: he fights on it), and it reforms in
##                ARENA_REFORM, at once on a retry. A snuff puts every pane
##                back (a retry sees the same level).
##   gusts        the header's zones (tools/levels' Z| overlay). A CYCLE of
##                calm, a gust_tell (the look below, `gust_tell` fitted to
##                it), then GUST_ON of push easing in and out over EASE;
##                phase B runs CYCLE / 2 later. A shorter tell (Nightfall,
##                Witching) only lengthens the calm. The push goes through
##                world.push_player (tag "gust:<zone>": the World halves it on
##                the ground, holds one begun in the air until he lands or
##                0.8 s, caps every push at 170 px/s, ignores it while he
##                dashes or climbs, and actor.gd brakes it at a floor edge).
##                The stone brake: a grounded push never carries him off
##                stone onto glass (or lit dawnglass), so a gust is always
##                waited out on a stone post, however narrow. His light is
##                dimmed x gust_dim meanwhile (the pipeline), and the World's
##                playlog notes "gust" while it pushes him. A lamp standing
##                in a zone loses gust_lamp seconds of its lit time as each
##                gust begins. Enemy and hero shots drift at half the push,
##                fliers too (not Gustlings: the wind is theirs; never into a
##                wall); walking monsters stay put.
##   dawnglass A  a one-way ledge while world.lit_at(its centre, 0,
##                {exclude_hero}) (asked DAWN_EVERY): Wick's own light never
##                counts. Lit, it fades from gold toward the ghost over its
##                lamp's last DAWN_FADE s (its own clock: for a lamp in wind,
##                lamp_left() counts the gusts due before it burns out), then,
##                once the light is gone, flickers DAWN_FLICKER (dawnglass_off
##                fitted to it) and is air again ("dawnglass" noted if he
##                stood on it). A lantern post that lights any
##                dawnglass is marked "anchor" (the Stillmaw never swallows
##                it) and its World light keeps its nominal radius for
##                lit_at (rule_r: a guttering flame's flicker never drops
##                the far panes early).
##
## The first-time barks (first_glass, first_wind, first_dawnglass) wait for
## his next landing on stone (never mid-jump), at most one every BARK_GAP.
##
## The look (A2's, through the level's theme, scripts/themes/w5.gd):
##   THEMES[id]["gust"]          a Dictionary for this file's stand-in
##                               {color, alpha, lanes, specks, speck_color}
##   THEMES[id]["gust_painter"]  a painter name (scripts/tiles/<name>.gd) or
##                               a script path whose
##                               static func draw_gust(glow: CanvasItem, tb, g: Dictionary) -> void
##                               draws the wind instead of the stand-in, into
##                               tb (a TriBatch this file flushes once), for
##                               each zone in view that isn't calm:
##                               g = {rect: Rect2 (the air over the zone's
##                               floor, inside the view), dir: -1 | 1,
##                               state: "tell" | "gust", k: 0..1 (the tell's
##                               progress / the gust's ease), t: ftime,
##                               zone: {x0, x1, dir, phase}, floor_y,
##                               x0, x1 (the zone's span in px)}
##   world.ambient.set_wind(dir, k)  is called every tick with the gust Wick
##                               stands in (k 0 in calm; a tell gives up to
##                               0.3), so a theme's AMBIENT "streak" entries
##                               lean and run with it.
## In a theme with a painter (Themes.has_theme) the painter draws the glass
## and dawnglass tiles; this file draws only what changes (cracks, the flash,
## the shimmer, the lit dawnglass and its clock) and the glow edges.
##
## Cost (spec §13.2): cells are bucketed by CHUNK columns; drawing and the
## unlit dawnglass checks touch only the view's chunks and one each side, and
## the step runs only the panes that aren't whole (a break, a reform).

const Arena := preload("res://scripts/boss_arena.gd")
const WalkMap := preload("res://scripts/walk_map.gd")
const Themes := preload("res://scripts/themes/loader.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")

const DIFF_KNOBS := {
	"glass_land": {"dusk": 0.40, "nightfall": 0.50, "witching": 0.50},
	"glass_stand": {"dusk": 0.55, "nightfall": 0.70, "witching": 0.85},   # owner feel lab 2026-09-26: "glass breaks too slow"
	"glass_reform": {"dusk": 5.0, "nightfall": 6.0, "witching": 7.0},
	"gust_tell": {"dusk": 1.0, "nightfall": 0.85, "witching": 0.72},
	"gust_push": {"dusk": 120.0, "nightfall": 135.0, "witching": 150.0},
	"gust_dim": {"dusk": 0.85, "nightfall": 0.85, "witching": 0.85},
	"gust_lamp": {"dusk": 8.0, "nightfall": 8.0, "witching": 8.0},        # s off a lamp in a zone, each gust
	# The W5 void's own share of life (spec §1.4, §14: 33% -> 28% on Dusk if
	# falls are more than half of W5's snuffs in the owner's playlog); W1-W4's
	# pits keep Combat's "pit". Provisional (W5-W6 numbers).
	"void_pct": {"dusk": 0.33, "nightfall": 0.38, "witching": 0.45},
}
const SHOT_STRAIN := 0.5
const CRACKS := [0.4, 0.8]       # the strain stages that show (and sound)
const FLASH := 0.35
const SHIMMER := 0.6
const ARENA_REFORM := 4.0
const CYCLE := 4.8
const GUST_ON := 1.8
const EASE := 0.3
const SHOT_DRIFT := 0.5          # shots and fliers drift at this share of the push
const DAWN_EVERY := 0.1
const DAWN_FLICKER := 0.35
const DAWN_FADE := 5.0
const LANTERN_R := 140.0         # level_features.gd's lantern post (its nominal light)
const LIT_SLACK := 8.0           # world_lights' hysteresis
const BARK_GAP := 8.0
const PANE := Color(0.62, 0.78, 0.92, 0.55)
const PANE_LIP := Color(0.9, 0.97, 1.0, 0.8)
const CRACK := Color(1.0, 1.0, 1.0, 0.95)
const DAWN := Color("ffe9a8")
const WIND := Color(0.86, 0.93, 1.0)
const SPECK := Color(1.0, 0.97, 0.9)
const TILE_F := 32.0
const CHUNK := 16                # columns per bucket

var panes := {}                  # Vector2i -> {strain, state: whole|flash|gone|shimmer, t, stage, arena}
var zones: Array = []            # {x0, x1, dir, phase[, y0, y1]} (a taller level's zone: its rows too)
var dawn := {}                   # Vector2i -> {lit, flicker, remain, lamps: [lantern indices]}
var arena_x := Vector2(-1.0, -1.0)   # the boss arena's span in px (left, right), or (-1, -1)
var arena := false               # the level has a boss arena
var painted := false             # a v3 theme's painter draws the glass tiles
var _under := {}                 # the glass cells under Wick last step
var _air := true                 # airborne last step (a landing's sound)
var _dawn_t := 0.0
var _zstate: Array = []          # each zone's state last step
var _lamp_zone := {}             # lantern index -> zone index (lamps standing in wind)
var _lamps_seen := false         # the lantern tables are read (after the dispatcher's build)
var _due: Array = []             # first-time barks waiting for a stone landing
var _barked := {}
var _bark_t := -100.0
var _dt := 1.0 / 120.0
var _wind_k := 0.0
var _style := {}                 # the theme's "gust" dictionary
var _gust_painter: Script = null
var _tb := TriBatch.new()
# A2's look (scripts/tiles/glass.gd, the W5 themes' painter): the panes'
# cracks, flash and shimmer, lit dawnglass's clock (dawn_k), the sanctum's
# wind over the hero's own floor and its pennants (merged at the track B
# integration from A2's patch). null in a theme it doesn't paint (the feel
# labs, v2's themes): the stand-ins here.
const PENNANTS := {"slack": "res://art/props/pennant_slack.svg", "lift": "res://art/props/pennant_lift.svg",
		"full": "res://art/props/pennant_full.svg"}
var _art: Script = null
var _pal := {}
const GHOST_A := 0.25             # a gone pane's ghost outline (on the glow layer)
const FALL_REFORM := 30           # tiles ahead of a fall's return that its broken panes come back
var _pennant_tex := {}
var _anchors: Array = []         # per zone: the painter's pennant_anchors()
var _tb_under := TriBatch.new()
var _busy := {}                  # the panes that aren't whole (the step runs only these)
var _pchunk := {}                # chunk -> [pane cells]
var _dchunk := {}                # chunk -> [dawnglass cells]
var _dawn_on := {}               # the lit dawnglass cells (checked wherever they are)


func build(w: Node, lv: RefCounted) -> void:
	super.build(w, lv)
	var box := {}
	if str(lv.boss) != "":
		for e in lv.entities:
			if e["kind"] == "boss":
				box = Arena.find(lv, LevelData.cell_floor(e["cell"]))
				break
	arena = not box.is_empty()
	if arena:
		arena_x = Vector2(float(box["left"]), float(box["right"]))
	for y in lv.height:
		for x in lv.width:
			match lv.tile(x, y):
				LevelData.GLASS:
					var c := Vector2i(x, y)
					panes[c] = {"strain": 0.0, "state": "whole", "t": 0.0, "stage": 0, "arena": in_arena(c)}
					_bucket(_pchunk, c)
				LevelData.DAWNGLASS:
					var c := Vector2i(x, y)
					dawn[c] = {"lit": false, "flicker": -1.0, "remain": INF, "lamps": []}
					_bucket(_dchunk, c)
	if not panes.is_empty() and not WalkMap.strip(lv):
		# A taller level's route, now at the build: on_fall asks it which
		# way is ahead (never a route solved mid-play).
		WalkMap.of(lv).route()
	zones = lv.gusts.duplicate(true)
	_zstate.resize(zones.size())
	_zstate.fill("calm")
	var th: Dictionary = Themes.theme(str(lv.theme))
	painted = Themes.has_theme(str(lv.theme))
	var gs = th.get("gust", {})
	if gs is Dictionary:
		_style = gs
	var gp = th.get("gust_painter", "")
	if gp is String and gp != "":
		var path: String = gp if gp.begins_with("res://") else "res://scripts/tiles/%s.gd" % gp
		if ResourceLoader.exists(path):
			var sc = load(path)
			if sc is Script and (sc as Script).get_script_method_list().any(func(m): return str(m["name"]) == "draw_gust"):
				_gust_painter = sc
	var painter: Script = Themes.painter(str(lv.theme)) if painted else null
	if painter != null and painter.get_script_method_list().any(func(m): return str(m["name"]) == "draw_gust_glow"):
		_art = painter
		_pal = Themes.palette(str(lv.theme))
		for k in PENNANTS:
			if ResourceLoader.exists(PENNANTS[k]):
				_pennant_tex[k] = load(PENNANTS[k])
		for z in zones:
			_anchors.append(_art.pennant_anchors(lv, z))


func _bucket(into: Dictionary, c: Vector2i) -> void:
	var k := floori(float(c.x) / CHUNK)
	if not into.has(k):
		into[k] = []
	(into[k] as Array).append(c)


func _near_cells(from: Dictionary, v: Rect2) -> Array:
	## The cells in the chunks over v and one chunk each side.
	var out := []
	var k0 := floori(v.position.x / (TILE_F * CHUNK)) - 1
	var k1 := floori(v.end.x / (TILE_F * CHUNK)) + 1
	for k in range(k0, k1 + 1):
		if from.has(k):
			out.append_array(from[k])
	return out


func in_arena(c: Vector2i) -> bool:
	## Is this cell inside the boss arena's span?
	if not arena:
		return false
	var px := (c.x + 0.5) * TILE_F
	return px > arena_x.x and px < arena_x.y


func _read_lamps() -> void:
	## Which lantern posts light dawnglass (anchors), and which stand in wind.
	## (The dispatcher builds its lanterns before this module; they are read
	## on the first step, when world.features is certainly set.)
	_lamps_seen = true
	var ls := lanterns()
	for i in ls.size():
		var l: Dictionary = ls[i]
		var f: Vector2 = l.get("flame", l.get("pos", Vector2.ZERO))
		for c in dawn:
			if LevelData.cell_center(c).distance_to(f) <= LANTERN_R + LIT_SLACK:
				(dawn[c]["lamps"] as Array).append(i)
				l["anchor"] = true
		var zi := _zone_at(f)
		if zi >= 0 and not bool(l.get("brazier", false)):
			_lamp_zone[i] = zi


func lanterns() -> Array:
	## The dispatcher's lantern posts (level_features.gd), or [].
	if world == null or world.get("features") == null:
		return []
	var ls = world.features.get("lanterns")
	return ls if ls is Array else []


# ---------------------------------------------------------------- glass

func strain_glass(cell: Vector2i, amount: float) -> void:
	var p: Dictionary = panes.get(cell, {})
	if p.is_empty() or p["state"] != "whole" or amount <= 0.0:
		return
	p["strain"] = minf(float(p["strain"]) + amount, 1.0)
	var s := float(p["strain"])
	var stage := 0
	for k in CRACKS:
		if s >= float(k):
			stage += 1
	if s >= 1.0:
		p["state"] = "flash"
		p["t"] = ftime()
		_busy[cell] = true
		world._sfx("glass_crack", _note(3))
	elif stage > int(p["stage"]):
		world._sfx("glass_crack", 1.0 if stage == 1 else _note(1))
	p["stage"] = stage


func break_glass(cell: Vector2i) -> void:
	strain_glass(cell, 1.0)


func pane_state(cell: Vector2i) -> String:
	## "whole" | "flash" | "gone" | "shimmer", or "" (not glass).
	return str(panes.get(cell, {}).get("state", ""))


func shot_hit(shot: Dictionary) -> void:
	var pos: Vector2 = shot.get("pos", Vector2.ZERO)
	# Shots drift in a gust, at half its push.
	var g := gust_at(pos)
	if g.x != 0.0 and shot.has("pos"):
		shot["pos"] = pos + Vector2(g.x * SHOT_DRIFT * _dt, 0.0)
	if str(shot.get("owner", "enemy")) == "player":
		return   # hero attacks never strain glass
	var c := Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))
	if panes.has(c) and panes[c]["state"] == "whole":
		strain_glass(c, SHOT_STRAIN)
		shot["life"] = 0.0
		if world.glow:
			world.glow.burst(pos, 6, Color(0.85, 0.95, 1.0, 0.9), 90.0, 0.35, 500.0, 2.0)


func _shots_on_glass(dt: float) -> void:
	## An enemy shot about to meet a whole pane strains it and ends there.
	## (The World ends a shot on a solid tile before it asks shot_hit, and
	## glass is solid: so the feature looks one step ahead, before the shots
	## move.)
	var shots = world.get("shots")
	if not (shots is Array) or panes.is_empty():
		return
	for s in shots:
		if str(s.get("owner", "enemy")) == "player" or float(s.get("life", 0.0)) <= 0.0:
			continue
		var vel: Vector2 = s.get("vel", Vector2.ZERO)
		var nxt: Vector2 = (s.get("pos", Vector2.ZERO) as Vector2) + (vel + Vector2(0, float(s.get("g", 0.0)) * dt)) * dt
		var c := Vector2i(floori(nxt.x / TILE), floori(nxt.y / TILE))
		if panes.has(c) and panes[c]["state"] == "whole" and level.tile(c.x, c.y) == LevelData.GLASS:
			strain_glass(c, SHOT_STRAIN)
			s["life"] = 0.0
			if world.glow:
				world.glow.burst(nxt, 6, Color(0.85, 0.95, 1.0, 0.9), 90.0, 0.35, 500.0, 2.0)


func _cells_under(pl: Node2D) -> Array:
	var out := []
	if not pl.on_floor or pl.riding != null:
		return out
	var r: Rect2 = pl.rect()
	var ty := floori((pl.position.y + 1.0) / TILE)
	for tx in range(floori((r.position.x + 0.01) / TILE), floori((r.end.x - 0.01) / TILE) + 1):
		var c := Vector2i(tx, ty)
		if panes.has(c) and level.tile(tx, ty) == LevelData.GLASS:
			out.append(c)
	return out


func step(dt: float) -> void:
	_dt = dt
	if not _lamps_seen:
		_read_lamps()
	var pl := player()
	if pl != null and pl.alive and not panes.is_empty():
		var now := {}
		var cells := _cells_under(pl)
		if not cells.is_empty() and _air:
			world._sfx("glass_step")
			_want_bark("first_glass")
		for c in cells:
			now[c] = true
			if not _under.has(c):
				# A pane he sets foot on takes a landing's strain; in the
				# arena only a real landing does (he fights on it).
				if _air or not panes[c]["arena"]:
					strain_glass(c, knob("glass_land"))
			elif not panes[c]["arena"]:
				strain_glass(c, knob("glass_stand") * dt)
		_under = now
	if pl != null:
		_air = not pl.on_floor
	_shots_on_glass(dt)
	for c in _busy.keys():
		var p: Dictionary = panes[c]
		var age := ftime() - float(p["t"])
		match p["state"]:
			"flash":
				if age >= FLASH:
					p["state"] = "gone"
					p["t"] = ftime()
					level.set_tile(c, LevelData.AIR)
					world._redraw_at(c.x, c.y)
					world._sfx("glass_shatter")
					if world.glow:
						var mid := LevelData.cell_center(c)
						world.glow.burst(mid, 10, Color(0.8, 0.92, 1.0, 0.9), 120.0, 0.6, 900.0, 2.5)
						world.glow.burst(mid, 4, Color(1.0, 0.95, 0.85, 0.8), 80.0, 0.5, 700.0, 3.0)
					if world.has_method("note_feature"):
						world.note_feature("glass")
			"gone":
				var reform := ARENA_REFORM if p["arena"] else knob("glass_reform")
				if age >= reform and not _body_in(c):
					p["state"] = "shimmer"
					p["t"] = ftime()
			"shimmer":
				if _body_in(c):
					p["state"] = "gone"
				elif age >= SHIMMER:
					_reform(c)
	_step_gusts(dt)
	_dawn_t -= dt
	if _dawn_t <= 0.0 and not dawn.is_empty():
		_dawn_t = DAWN_EVERY
		_step_dawn()
	_step_barks(pl)


func _reform(c: Vector2i) -> void:
	var p: Dictionary = panes[c]
	p["state"] = "whole"
	p["strain"] = 0.0
	p["stage"] = 0
	_busy.erase(c)
	if level.tile(c.x, c.y) != LevelData.GLASS:
		level.restore_tile(c)
		world._redraw_at(c.x, c.y)


func _body_in(c: Vector2i) -> bool:
	## A body in the cell (glass never reforms into one).
	var r := Rect2(c.x * TILE, c.y * TILE, TILE, TILE)
	if world.player != null and world.player.rect().intersects(r):
		return true
	for e in world.enemies:
		if e.alive and e.rect().intersects(r):
			return true
	return false


func on_respawn() -> void:
	## A snuff: every pane is whole again (a retry sees the same level).
	_under = {}
	_air = true
	for c in panes:
		if (panes[c]["state"] != "whole" or float(panes[c]["strain"]) > 0.0) and not _body_in(c):
			_reform(c)


func on_fall(at: Vector2) -> void:
	## A fall into the void put him back at firm ground: the panes gone within
	## FALL_REFORM tiles ahead of him come back at once, as a snuff's do (the
	## rev5 review: after a fall in 5-1's arches he faced missing capitals,
	## and walked off onto them). Ahead is the way the route runs there
	## (WalkMap.dir_of: a strip's its facing, so right to left facing left;
	## a taller level's the walk map's, its leftward storey's too). Never the
	## boss arena's (its own rule).
	var c0 := floori(at.x / TILE)
	var d := WalkMap.dir_of(level, Vector2i(c0, floori((at.y - 1.0) / TILE)))
	var lo := c0 - 2 if d > 0 else c0 - FALL_REFORM
	var hi := c0 + FALL_REFORM if d > 0 else c0 + 2
	for c in panes:
		var p: Dictionary = panes[c]
		if p["arena"] or p["state"] == "whole" or _body_in(c):
			continue
		if (c as Vector2i).x >= lo and (c as Vector2i).x <= hi:
			_reform(c)


func on_boss_reset() -> void:
	## A retry: the arena's glass is back at once.
	for c in panes:
		var p: Dictionary = panes[c]
		if p["arena"] and (p["state"] != "whole" or float(p["strain"]) > 0.0) and not _body_in(c):
			_reform(c)


func _note(degree: int) -> float:
	## Sfx.note(degree) (the autoload isn't known to a --script test).
	var sfx = world.get_node_or_null("/root/Sfx") if world != null and world.is_inside_tree() else null
	if sfx != null and sfx.has_method("note"):
		return float(sfx.note(degree))
	return [1.0, 1.1892, 1.3348, 1.4983, 1.7818, 2.0][clampi(degree, 0, 5)]


# ---------------------------------------------------------------- gusts

func gust_phase(z: Dictionary) -> Dictionary:
	## {state: calm | tell | gust, k: 0..1 (the tell's progress, the gust's
	## ease)} for zone z now.
	var off := 0.0 if str(z.get("phase", "A")) == "A" else CYCLE * 0.5
	var t := fposmod(ftime() - off, CYCLE)
	var start := CYCLE - GUST_ON
	var tell := knob("gust_tell")
	if t >= start:
		var g := t - start
		var k := minf(clampf(g / EASE, 0.0, 1.0), clampf((GUST_ON - g) / EASE, 0.0, 1.0))
		return {"state": "gust", "k": k}
	if t >= start - tell:
		return {"state": "tell", "k": (t - (start - tell)) / tell}
	return {"state": "calm", "k": 0.0}


func next_gust(z: Dictionary) -> float:
	## Seconds until zone z's next gust begins (0 while it blows).
	var off := 0.0 if str(z.get("phase", "A")) == "A" else CYCLE * 0.5
	var t := fposmod(ftime() - off, CYCLE)
	var start := CYCLE - GUST_ON
	return 0.0 if t >= start else start - t


func _to_gust_start(z: Dictionary) -> float:
	## Seconds until zone z's next gust *begins* (while one blows, the one
	## after it): in (0, CYCLE].
	var off := 0.0 if str(z.get("phase", "A")) == "A" else CYCLE * 0.5
	var t := fposmod(ftime() - off, CYCLE)
	var start := CYCLE - GUST_ON
	var n := start - t if t < start else CYCLE - t + start
	return n if n > 0.0 else CYCLE


func lamp_left(i: int) -> float:
	## How long lantern i will really burn: its own time, less gust_lamp for
	## each gust its zone will blow before it's out (a lamp in wind). INF for
	## a brazier; 0 if it's out.
	var ls := lanterns()
	if i < 0 or i >= ls.size():
		return 0.0
	var l: Dictionary = ls[i]
	if not bool(l.get("lit", false)):
		return 0.0
	if bool(l.get("brazier", false)):
		return INF
	var t := float(l.get("t", 0.0))
	if not _lamp_zone.has(i):
		return maxf(t, 0.0)
	var z: Dictionary = zones[int(_lamp_zone[i])]
	var drain := knob("gust_lamp")
	var n := _to_gust_start(z)
	var clock := 0.0
	for _k in 64:
		if t <= n:
			return clock + maxf(t, 0.0)
		t -= n
		clock += n
		t -= drain
		if t <= 0.0:
			return clock
		n = CYCLE
	return clock + t


func _zone_at(p: Vector2) -> int:
	var x := floori(p.x / TILE)
	var y := floori(p.y / TILE)
	for i in zones.size():
		if x >= int(zones[i]["x0"]) and x <= int(zones[i]["x1"]) and in_rows(zones[i], y):
			return i
	return -1


static func in_rows(z: Dictionary, y: int) -> bool:
	## A zone's rows hold row y: every row, but a taller level's zone with
	## rows (y0, y1: its section's own) only those (another deck's wind never
	## blows on this one).
	return not z.has("y0") or (y >= int(z["y0"]) and y <= int(z["y1"]))


func zone_at(p: Vector2) -> Dictionary:
	## The gust zone over p ({x0, x1, dir, phase}), or {}.
	var i := _zone_at(p)
	return zones[i] if i >= 0 else {}


func gust_at(p: Vector2) -> Vector2:
	var i := _zone_at(p)
	if i < 0:
		return Vector2.ZERO
	var ph := gust_phase(zones[i])
	if ph["state"] != "gust":
		return Vector2.ZERO
	return Vector2(float(zones[i]["dir"]) * knob("gust_push") * float(ph["k"]), 0.0)


func wind_at(p: Vector2) -> float:
	## How far the wind bends a flame or a cape at p, -1..1 (its direction):
	## from the tell on (A2's lean_of: up to 0.5 in the tell, full in the
	## gust); the push's share without A2's painter.
	var i := _zone_at(p)
	if i < 0:
		return 0.0
	if _art == null:
		return clampf(gust_at(p).x / 120.0, -1.0, 1.0)
	return float(zones[i]["dir"]) * float(_art.lean_of(gust_phase(zones[i])))


func _step_gusts(dt: float) -> void:
	if zones.is_empty():
		return
	var pl := player()
	var v := view()
	for i in zones.size():
		var z: Dictionary = zones[i]
		var ph := gust_phase(z)
		var st: String = ph["state"]
		if st != _zstate[i]:
			var near := _gain(z, v)
			if st == "tell" and near > 0.0:
				world._tell_sfx("gust_tell", knob("gust_tell"), near)
				# (On the zone's own rows: under 5-3's relay, the lower deck
				# hears the upper's tell but feels no wind.)
				if pl != null and pl.alive and absf(pl.center().x - (float(z["x0"]) + float(z["x1"]) + 1.0) * 0.5 * TILE) < 12.0 * TILE \
						and in_rows(z, floori(pl.center().y / TILE)):
					_want_bark("first_wind")
			elif st == "gust":
				if near > 0.0:
					world._sfx("gust", 1.0, 0.0, near)
				_drain_lamps(i)
			_zstate[i] = st
	# The push on Wick, and his light.
	var here := -1
	if pl != null and pl.alive:
		here = _zone_at(pl.center())
		if here >= 0:
			var g := gust_at(pl.center())
			if g.x != 0.0:
				if _stone_brake(pl, g.x):
					g = Vector2.ZERO
				world.push_player(g, dt * 1.5, "gust:%d" % here)
				world.dim("gust", knob("gust_dim"), 0.1)
				if g.x != 0.0 and world.has_method("note_feature"):
					world.note_feature("gust")
	# The ambient's wind (a theme's streaks lean and run with it).
	var wk := 0.0
	var wd := 1.0
	if here >= 0:
		var ph2 := gust_phase(zones[here])
		wd = float(zones[here]["dir"])
		wk = float(ph2["k"]) if ph2["state"] == "gust" else (0.3 * float(ph2["k"]) if ph2["state"] == "tell" else 0.0)
	if wk != _wind_k or wk > 0.0:
		_wind_k = wk
		var amb = world.get("ambient")
		if amb != null and amb.has_method("set_wind"):
			amb.set_wind(wd, wk)
	# Fliers drift (not Gustlings: the wind is theirs; not bosses, Dreads or Wardens).
	for e in world.enemies:
		if not e.alive or not bool(e.get("flier")) or str(e.get("kind")) == "gustling" or e.get("boss_id") != null \
				or str(e.get("tier")) == "dread" or str(e.get("tier")) == "warden":
			continue
		var ge := gust_at(e.position)
		if ge.x != 0.0:
			var dx := ge.x * SHOT_DRIFT * dt
			if not _blocked(e, dx):
				e.position.x += dx


func _blocked(e: Node2D, dx: float) -> bool:
	## Would a drift of dx put a flier's leading edge into a solid tile?
	var r: Rect2 = e.rect() if e.has_method("rect") else Rect2(e.position - Vector2(8, 16), Vector2(16, 16))
	var lead := (r.end.x if dx > 0.0 else r.position.x) + dx
	var tx := floori(lead / TILE)
	for y in [r.position.y + 1.0, r.get_center().y, r.end.y - 1.0]:
		if LevelData.is_solid(level.tile(tx, floori(y / TILE))):
			return true
	return false


func _stone_brake(pl: Node2D, gx: float) -> bool:
	## The stone brake: standing on stone, a gust never pushes him onto glass
	## or lit dawnglass (a gust is waited out on a stone post; actor.gd's
	## edge brake keeps him off the void, and glass is floor to it).
	if not pl.on_floor or pl.riding != null:
		return false
	var r: Rect2 = pl.rect()
	var ty := floori((pl.position.y + 1.0) / TILE)
	var on_stone := false
	for tx in range(floori((r.position.x + 0.01) / TILE), floori((r.end.x - 0.01) / TILE) + 1):
		var t: int = level.tile(tx, ty)
		on_stone = on_stone or (LevelData.is_solid(t) and LevelData.is_safe(t))
	if not on_stone:
		return false
	var dir := 1.0 if gx > 0.0 else -1.0
	var lead := (r.end.x if dir > 0.0 else r.position.x) + dir * (absf(gx) * _dt + 0.01)
	var ahead: int = level.tile(floori(lead / TILE), ty)
	return ahead == LevelData.GLASS or ahead == LevelData.DAWN_ON


func _gain(z: Dictionary, v: Rect2) -> float:
	## How loud a zone's sound is: full in view, fading over 8 tiles past it.
	var x0 := float(z["x0"]) * TILE
	var x1 := (float(z["x1"]) + 1.0) * TILE
	var d := maxf(maxf(v.position.x - x1, x0 - v.end.x), 0.0)
	return clampf(1.0 - d / (8.0 * TILE), 0.0, 1.0)


func _drain_lamps(zi: int) -> void:
	## A gust begins: each lit lamp standing in the zone loses gust_lamp s.
	var ls := lanterns()
	for i in _lamp_zone:
		if int(_lamp_zone[i]) != zi or i >= ls.size():
			continue
		var l: Dictionary = ls[i]
		if not bool(l.get("lit", false)):
			continue
		l["t"] = float(l.get("t", 0.0)) - knob("gust_lamp")
		if world.glow:
			var f: Vector2 = l.get("flame", Vector2.ZERO)
			world.glow.burst(f, 5, Color("f7b64a"), 60.0, 0.5, -40.0, 2.0)


# ---------------------------------------------------------------- dawnglass

func _step_dawn() -> void:
	var ls := lanterns()
	for i in ls.size():
		# Its World light keeps its nominal radius for lit_at (a guttering
		# flame's flicker would drop the far panes before the lamp is out).
		var l: Dictionary = ls[i]
		if bool(l.get("lit", false)) and bool(l.get("anchor", false)) and int(l.get("id", -1)) >= 0 and world.has_method("light_by_id"):
			var wl: Dictionary = world.light_by_id(int(l["id"]))
			if not wl.is_empty() and not wl.has("rule_r"):
				wl["rule_r"] = float(wl.get("r", LANTERN_R)) if bool(l.get("brazier", false)) else LANTERN_R
	var v := view().grow(2.0 * TILE)
	var sounded := {}             # one dawnglass_on / _off a check, however many panes
	# The unlit cells near the view (nothing lights one far off: a lamp is lit
	# where he stands) and every lit one, wherever it is (its lamp burns out).
	var cells := _near_cells(_dchunk, v)
	for c in _dawn_on:
		if not cells.has(c):
			cells.append(c)
	var pl := player()
	for c in cells:
		var d: Dictionary = dawn[c]
		var lit: bool = world.lit_at(LevelData.cell_center(c), 0.0, {"exclude_hero": true, "key": c})
		if lit:
			d["flicker"] = -1.0
			# Its clock: the longest-burning lantern that lights it (another
			# lamplight, a beacon or a toll, holds it steady), counting the
			# gusts a lamp in wind will lose before it's out.
			var remain := INF
			var any := false
			for li in d["lamps"]:
				if li < ls.size() and bool(ls[li].get("lit", false)) \
						and LevelData.cell_center(c).distance_to(ls[li].get("flame", Vector2.ZERO)) <= LANTERN_R + LIT_SLACK:
					remain = lamp_left(li) if not any else maxf(remain, lamp_left(li))
					any = true
			d["remain"] = remain
			if not d["lit"]:
				d["lit"] = true
				_dawn_on[c] = true
				level.set_tile(c, LevelData.DAWN_ON)
				world._redraw_at(c.x, c.y)
				if v.has_point(LevelData.cell_center(c)):
					if not sounded.has("on"):
						world._sfx("dawnglass_on")
						sounded["on"] = true
					_want_bark("first_dawnglass")
		elif d["lit"]:
			if float(d["flicker"]) < 0.0:
				d["flicker"] = ftime()
				if v.has_point(LevelData.cell_center(c)) and not sounded.has("off"):
					world._tell_sfx("dawnglass_off", DAWN_FLICKER)
					sounded["off"] = true
			elif ftime() - float(d["flicker"]) >= DAWN_FLICKER:
				d["lit"] = false
				d["flicker"] = -1.0
				d["remain"] = INF
				_dawn_on.erase(c)
				var under := _stands_on(pl, c)
				level.restore_tile(c)
				world._redraw_at(c.x, c.y)
				if under and world.has_method("note_feature"):
					world.note_feature("dawnglass")


func _stands_on(pl: Node2D, c: Vector2i) -> bool:
	## Is Wick standing on cell c?
	if pl == null or not pl.alive or not pl.on_floor:
		return false
	var r: Rect2 = pl.rect()
	return floori((pl.position.y + 1.0) / TILE) == c.y and r.end.x > c.x * TILE_F + 0.01 and r.position.x < (c.x + 1) * TILE_F - 0.01


func dawn_k(c: Vector2i) -> float:
	## A lit pane's clock, 1 (bright) down to 0 (its lamp about to go), or -1
	## unlit.
	var d: Dictionary = dawn.get(c, {})
	if d.is_empty() or not d["lit"]:
		return -1.0
	if float(d["flicker"]) >= 0.0:
		return 0.0
	return clampf(float(d["remain"]) / DAWN_FADE, 0.0, 1.0)


# ---------------------------------------------------------------- barks

func _want_bark(key: String) -> void:
	if not _barked.has(key) and not _due.has(key):
		_due.append(key)


func _step_barks(pl: Node2D) -> void:
	## A first-time line waits for a landing on stone (never mid-jump).
	if _due.is_empty() or pl == null or not pl.alive or not pl.on_floor or pl.riding != null:
		return
	if ftime() - _bark_t < BARK_GAP:
		return
	var t: int = level.tile(floori(pl.position.x / TILE), floori((pl.position.y + 1.0) / TILE))
	if not LevelData.is_safe(t):
		return
	var key: String = _due.pop_front()
	_barked[key] = true
	_bark_t = ftime()
	world.bark(key)


# ---------------------------------------------------------------- drawing

func draw_under(ci: CanvasItem) -> void:
	## Over the tiles: the panes themselves when no painter draws them, and
	## the lit dawnglass, which changes (always).
	var v := view().grow(TILE)
	if not painted:
		for c in _near_cells(_pchunk, v):
			var p: Dictionary = panes[c]
			var at := Vector2(c.x * TILE, c.y * TILE)
			if not v.has_point(at) or p["state"] == "gone" or p["state"] == "shimmer":
				continue
			var col := PANE
			if p["state"] == "flash":
				col = Color(1, 1, 1, 0.9) if fmod(ftime(), 0.1) < 0.05 else PANE
			ci.draw_rect(Rect2(at, Vector2(TILE, TILE)), col)
			if not LevelData.is_solid(level.tile(c.x, c.y - 1)):
				ci.draw_rect(Rect2(at, Vector2(TILE, 3)), PANE_LIP)
	if _art != null:
		# A2's look: lit dawnglass fading toward its ghost by its clock (the
		# painter paints the slab), and the zones' pennants.
		_tb_under.clear()
		for c in _near_cells(_dchunk, v):
			var k := dawn_k(c)
			if k >= 0.0 and v.has_point(Vector2(c.x * TILE, c.y * TILE)):
				_art.draw_dawn_overlay(ci, _tb_under, c, k, float(dawn[c]["flicker"]) >= 0.0, ftime(), _pal)
		for i in zones.size():
			var zx0 := float(zones[i]["x0"]) * TILE
			var zx1 := (float(zones[i]["x1"]) + 1.0) * TILE
			if zx1 + 4.0 * TILE >= v.position.x and zx0 - 4.0 * TILE <= v.end.x:
				_art.draw_gust_under(ci, _tb_under, zones[i], gust_phase(zones[i]), _anchors[i], ftime(), _pennant_tex, level)
		_tb_under.flush(ci)
		return
	for c in _near_cells(_dchunk, v):
		var at := Vector2(c.x * TILE, c.y * TILE)
		if not v.has_point(at):
			continue
		var k := dawn_k(c)
		if k < 0.0:
			continue
		var flick: bool = float(dawn[c]["flicker"]) >= 0.0 and fmod(ftime(), 0.08) < 0.04
		var a := 0.35 + 0.6 * k
		ci.draw_rect(Rect2(at, Vector2(TILE, 10)), Color(DAWN, 0.2 if flick else a))
		ci.draw_rect(Rect2(at, Vector2(TILE, 2)), Color(1, 1, 1, 0.3 + 0.5 * k))


func _ghost_pane(tb, c: Vector2i, at: Vector2) -> void:
	## A pane that's gone, waiting to reform: a faint ghost of its edges on
	## the glow layer (0.25), so a player back at the altar after a fall can
	## plan on it coming back, as unlit dawnglass keeps its 0.30 outline (the
	## rev5 review: missing capitals read as the void).
	var top_open := not LevelData.is_solid(level.tile(c.x, c.y - 1)) and not panes.has(Vector2i(c.x, c.y - 1))
	if top_open:
		tb.rect(Rect2(at, Vector2(TILE, 2)), Color(0.85, 0.95, 1.0, GHOST_A))
	if not panes.has(Vector2i(c.x - 1, c.y)):
		tb.rect(Rect2(at, Vector2(1.5, TILE)), Color(0.85, 0.95, 1.0, GHOST_A * 0.6))
	if not panes.has(Vector2i(c.x + 1, c.y)):
		tb.rect(Rect2(at + Vector2(TILE - 1.5, 0), Vector2(1.5, TILE)), Color(0.85, 0.95, 1.0, GHOST_A * 0.6))


func draw_glow(glow: Node2D) -> void:
	var v := view()
	var vg := v.grow(TILE)
	var tb := _tb
	tb.clear()
	# Dawnglass: unlit, a ghost outline (alpha 0.30) so you can plan; lit, a
	# bright edge that fades with its lamp's clock and flickers at the end.
	for c in _near_cells(_dchunk, vg):
		var at := Vector2(c.x * TILE, c.y * TILE)
		if not vg.has_point(at):
			continue
		var k := dawn_k(c)
		if k < 0.0:
			var gc := Color(DAWN, 0.30)
			tb.rect(Rect2(at, Vector2(TILE, 2)), gc)
			tb.rect(Rect2(at + Vector2(0, 8), Vector2(TILE, 2)), gc)
			tb.rect(Rect2(at, Vector2(2, 10)), gc)
			tb.rect(Rect2(at + Vector2(TILE - 2, 0), Vector2(2, 10)), gc)
		else:
			var flick: bool = float(dawn[c]["flicker"]) >= 0.0 and fmod(ftime(), 0.08) < 0.04
			var a := 0.0 if flick else 0.30 + 0.55 * k
			var sh := 0.5 + 0.5 * sin(ftime() * 3.0 + c.x * 0.9)
			tb.rect(Rect2(at, Vector2(TILE, 3)), Color(DAWN, a))
			tb.rect(Rect2(at + Vector2(4 + sh * 18.0, 3), Vector2(6, 2)), Color(1, 1, 1, a * 0.7))
	# Glass: a faint top edge on every pane, the cracks (a white core >= 1.5
	# px), the flash, and the shimmer of a pane coming back.
	for c in _near_cells(_pchunk, vg):
		var p: Dictionary = panes[c]
		var at := Vector2(c.x * TILE, c.y * TILE)
		if not vg.has_point(at):
			continue
		if _art != null:
			# A2's cracks, flash and shimmer, on the glow layer so they read
			# in the dark (the tells outrank the look), with the bright top
			# edge that says glass in the dark.
			if p["state"] == "whole" and not LevelData.is_solid(level.tile(c.x, c.y - 1)):
				tb.rect(Rect2(at, Vector2(TILE, 2)), Color(0.85, 0.95, 1.0, 0.35))
			if p["state"] != "gone":
				_art.draw_pane_overlay(glow, tb, c, float(p["strain"]), str(p["state"]), ftime() - float(p["t"]), _pal)
			else:
				_ghost_pane(tb, c, at)
			continue
		match p["state"]:
			"gone":
				_ghost_pane(tb, c, at)
			"whole":
				# Glass reads as glass in the dark: a bright top edge and a
				# faint glint across it (stone has neither).
				if not LevelData.is_solid(level.tile(c.x, c.y - 1)):
					tb.rect(Rect2(at, Vector2(TILE, 2)), Color(0.85, 0.95, 1.0, 0.35))
				tb.line(at + Vector2(6, 26), at + Vector2(22, 6), 1.2, Color(0.85, 0.95, 1.0, 0.16))
				var stage := int(p["stage"])
				if stage >= 1:
					tb.line(at + Vector2(9, 2), at + Vector2(13, 14), 1.6, CRACK)
					tb.line(at + Vector2(13, 14), at + Vector2(10, 24), 1.6, CRACK)
				if stage >= 2:
					tb.line(at + Vector2(21, 2), at + Vector2(18, 12), 1.6, CRACK)
					tb.line(at + Vector2(18, 12), at + Vector2(24, 20), 1.6, CRACK)
					tb.line(at + Vector2(13, 14), at + Vector2(18, 12), 1.6, CRACK)
			"flash":
				var on: bool = fmod(ftime() - float(p["t"]), 0.1) < 0.06
				tb.rect(Rect2(at + Vector2(1, 1), Vector2(TILE - 2, TILE - 2)), Color(1, 1, 1, 0.75 if on else 0.3))
			"shimmer":
				var s := 0.12 + 0.12 * sin(ftime() * 30.0)
				tb.rect(Rect2(at + Vector2(1, 1), Vector2(TILE - 2, TILE - 2)), Color(0.8, 0.92, 1.0, s))
				tb.rect(Rect2(at, Vector2(TILE, 2)), Color(0.9, 0.97, 1.0, 0.4))
	# The gusts: A2's wind over the hero's own floor (his rect and the
	# camera's ground line: tiles/glass.gd band_floor), else a theme's
	# draw_gust painter, else a light stand-in.
	if _art != null:
		var hero: Rect2 = world.player.rect() if world.player != null else Rect2()
		var feet: float = (world.feet_line() + world.look_up()) if world.has_method("feet_line") else 211.0
		for z in zones:
			var zx0 := float(z["x0"]) * TILE
			var zx1 := (float(z["x1"]) + 1.0) * TILE
			if zx1 < v.position.x or zx0 > v.end.x:
				continue
			_art.draw_gust_glow(glow, tb, level, z, gust_phase(z), v, ftime(), _pal, hero, feet)
		tb.flush(glow)
		return
	for z in zones:
		var ph := gust_phase(z)
		if ph["state"] == "calm":
			continue
		var zx0 := float(z["x0"]) * TILE
		var zx1 := (float(z["x1"]) + 1.0) * TILE
		if zx1 < v.position.x or zx0 > v.end.x:
			continue
		var gy := _gust_floor(z, v)
		var top := maxf(gy - 6.0 * TILE, v.position.y + 78.0)   # under the HUD's top row
		if gy - 8.0 - top <= 8.0:
			continue
		var g := {"rect": Rect2(maxf(zx0, v.position.x), top, minf(zx1, v.end.x) - maxf(zx0, v.position.x), gy - 8.0 - top),
				"dir": float(z["dir"]), "state": ph["state"], "k": float(ph["k"]), "t": ftime(), "zone": z, "floor_y": gy,
				"x0": zx0, "x1": zx1}
		if _gust_painter != null:
			_gust_painter.call("draw_gust", glow, tb, g)
		else:
			_standin_gust(tb, g)
	tb.flush(glow)


func _standin_gust(tb: RefCounted, g: Dictionary) -> void:
	## The wind until A2's painter lands (see the header). The tell must read
	## on a muted phone in the dark: from its first moment, lanes of wind
	## lines across the whole zone in view, thickening, lengthening and
	## brightening as it nears (alpha >= 0.5 from half way), gathering in a
	## bright rank at the upwind edge. The gust: long fast streaks and specks
	## of dust and glass carried along.
	var zx0: float = g["x0"]
	var zx1: float = g["x1"]
	var r: Rect2 = g["rect"]
	var top := r.position.y
	var band := r.size.y
	var dir: float = g["dir"]
	var span := zx1 - zx0
	var t: float = g["t"]
	var k: float = g["k"]
	var telling: bool = g["state"] == "tell"
	var col: Color = _style.get("color", WIND)
	var base := float(_style.get("alpha", 1.0))
	var a := ((0.30 + 0.45 * k) if telling else (0.38 + 0.45 * k)) * base
	var lanes := maxi(int(_style.get("lanes", 8)), 6)
	var per := 2 if telling else 3          # streaks per lane: the zone full of wind, the gust fuller
	var seed := float((g["zone"] as Dictionary).get("x0", 0))
	var seed2 := float((g["zone"] as Dictionary).get("x1", 0))
	for i in lanes:
		var r1 := fposmod(sin(i * 12.9898 + seed) * 43758.5453, 1.0)
		var r2 := fposmod(sin(i * 78.233 + seed2) * 12543.917, 1.0)
		var y := top + band * (i + 0.5) / float(lanes) + sin(t * 1.7 + i * 2.1) * 5.0
		for j in per:
			var length := (14.0 + 34.0 * k + 8.0 * r1) if telling else (34.0 + 46.0 * r1)
			var speed := (55.0 + 35.0 * r2) if telling else (230.0 + 90.0 * r2)
			var head := fposmod(t * speed + i * 131.0 + r2 * span + j * span / float(per), span)
			var hx := (zx0 + head) if dir > 0.0 else (zx1 - head)
			for sgm in 4:
				var f := float(sgm) / 4.0
				var sx := hx - dir * length * (1.0 - f)
				var seg := length / 4.0
				var x_left := sx if dir > 0.0 else sx - seg
				if x_left < zx0 or x_left + seg > zx1 or x_left + seg < r.position.x or x_left > r.end.x:
					continue
				var curl := sin((sx / 58.0) + t * 2.3 + i) * 2.5
				var thick := (1.0 if sgm < 2 else 2.0) + (1.0 if (not telling or k >= 0.5) and sgm >= 2 else 0.0)
				tb.rect(Rect2(x_left, y + curl, seg, thick), Color(col, a * (0.35 + 0.65 * f)))
	if telling:
		# The rank at the upwind edge, where the wind comes in: short bright
		# dashes pulsing, longer as it nears.
		var up := zx1 if dir < 0.0 else zx0
		if up >= r.position.x - 4.0 and up <= r.end.x + 4.0:
			var ln := 10.0 + 22.0 * k
			var pulse := 0.75 + 0.25 * sin(t * 14.0)
			for i in lanes:
				var y2 := top + band * (i + 0.5) / float(lanes)
				var x_left := up - ln - 2.0 if dir < 0.0 else up + 2.0
				tb.rect(Rect2(x_left, y2 - 1.0, ln, 3.0), Color(col, minf(a * 1.15 * pulse, 1.0)))
	var specks := maxi(int(_style.get("specks", 12)), 8)
	var scol: Color = _style.get("speck_color", SPECK)
	for j in specks:
		var q1 := fposmod(sin(j * 3.7 + seed * 1.3) * 9731.1, 1.0)
		var q2 := fposmod(sin(j * 9.1 + seed2 * 0.7) * 5113.7, 1.0)
		var sp := (45.0 + 30.0 * q2) if telling else (260.0 + 120.0 * q2)
		var d := fposmod(t * sp + q1 * span, span)
		var px := (zx0 + d) if dir > 0.0 else (zx1 - d)
		if px < r.position.x or px > r.end.x:
			continue
		var py := top + band * q1 + sin(t * 3.1 + j) * 7.0
		tb.rect(Rect2(px, py, 2.0 if q2 < 0.6 else 3.0, 2.0), Color(scol, minf(a * 1.1, 1.0)))


func _gust_floor(z: Dictionary, v: Rect2) -> float:
	## The top of the floor under a gust zone's middle, seen from the view's
	## top down (the air the wind blows through sits above it: a floor with
	## air over it, never a ceiling); the view's bottom over the void.
	var cx := int((int(z["x0"]) + int(z["x1"])) / 2)
	var row0 := maxi(floori(v.position.y / TILE), 1)
	for ty in range(row0, level.height):
		for dx in [0, -2, 2, -4, 4]:
			if LevelData.is_floor(level.tile(cx + dx, ty)) and not LevelData.is_solid(level.tile(cx + dx, ty - 1)):
				return float(ty * TILE)
	return minf(v.end.y, float(level.height * TILE))
