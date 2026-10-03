extends "res://scripts/features/feature.gd"
## World 6, the Hushdeep (WL6). Everything the black lake does, on one clock
## (world.ftime); the numbers per difficulty are DIFF_KNOBS (the owner's feel
## lab signed off the float's 1.3 s on Dusk).
##
##   wax float &    movers.gd float: its top 4 px over the water line, bobbing;
##                  with Wick on it, it sinks float_sink px/s and is under at 24
##                  px (1.3 s on Dusk: he's in the water); unloaded it rises
##                  30 px/s. Never last_safe; monsters don't sink it.
##   bell-buoy J    a touch, a strike or a hero's shot tolls it (TOLL_COOL
##                  cooldown): a lamplight and haven (r 200, s 0.9) for
##                  TOLL_LIGHT s that no Hush zone dims; the water surface run
##                  through it, STILL_REACH tiles either side (reach.gd's
##                  still_cells: the bot lays out the same cells), goes still
##                  (a STILL ledge) for still_time, the last still_tell
##                  cracking (a hiss, flashing cracks); a toll on still water
##                  lengthens it. It holds the tide TOLL_HOLD s. Brinejaws
##                  under still water can't leap (held here, see _hold_jaws).
##                  Still water holds whoever is in it: a wader under a
##                  stilled shallow run, or a rider on a float in a stilled
##                  pool, rises onto its top (_lift).
##   Hushgrasp H    Wick's centre within GRASP_REACH across: a grasp_tell of
##                  ripples, a cold hiss and pale fingertips, then hands rise
##                  GRASP_H px for GRASP_UP s (grasp_dmg base and a douse),
##                  then sink; GRASP_COOL before it can rise again
##   Hush zones     the header's columns (the Z| overlay's ';'): his light x
##                  hush_light through world.dim, the music and ambience
##                  muffled (Sfx.set_hush 0.6); lanterns and Vigil candles in
##                  a zone burn at HUSH_SHRINK of their radius, buoy tolls at
##                  their full 200 (the one light the Hush can't dim)
##   Vigil candle C a touch, a strike or a shot relights it for good (r 90, a
##                  lamp and a haven), a chime and event_xp("candle") the
##                  first time only; the results count them (candles()). A
##                  candle whose light reaches dawnglass is an anchor (the
##                  Stillmaw never swallows it). The header `vigil_crown:
##                  x:x1,x2,...` makes the candle at column x a crown: it
##                  takes no flame of its own and lights (r CROWN_R) once
##                  every candle at x1, x2, ... is lit; pips over it count
##                  them (6-1's spur to sigil 1)
##   the tide       6-3's `chase:` ranges: leaving a range's start altar, a
##                  wall of black rises TIDE_START tiles behind him and
##                  rubber-bands (tide_far past TIDE_FAR_AT tiles, tide_mid,
##                  tide_near inside TIDE_NEAR_AT); a touch costs tide_touch of
##                  his life (no DR, no shove), TIDE_INVULN s untouchable and a
##                  TIDE_STALL s stall; a toll holds it TOLL_HOLD s; it erases
##                  the monsters it reaches (no XP); the end altar lit (or
##                  Wick past it) ends it;
##                  a snuff resets it. Its edge is always on screen: off the
##                  left, a vignette that widens as it closes.
## The first-time barks (Hollin's how-tos, 6-1 and 6-2 only; the Hush's
## first_tide in 6-3) fire on stone, just before the first of each thing:
## never mid-jump. Floats, buoys and lips have glow edges at EDGE_A (0.30).
## The dispatcher builds this module for every level: its wading steps play
## only in W6 (world 6, or a level with W6 things in it).

const Movers := preload("res://scripts/movers.gd")
const Reach := preload("res://scripts/reach.gd")
const Progression := preload("res://scripts/progression.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const DIFF_KNOBS := {
	"float_sink": {"dusk": 18.5, "nightfall": 21.0, "witching": 24.0},   # owner feel lab 2026-09-26: "floats sink a little too slow"
	"still_time": {"dusk": 7.0, "nightfall": 6.0, "witching": 5.0},
	"still_tell": {"dusk": 1.5, "nightfall": 1.5, "witching": 1.5},
	"hush_light": {"dusk": 0.70, "nightfall": 0.60, "witching": 0.55},
	"grasp_tell": {"dusk": 0.60, "nightfall": 0.51, "witching": 0.43},
	"grasp_dmg": {"dusk": 32.0, "nightfall": 32.0, "witching": 32.0},
	# The tide's rubber band (decisions.md): 200 / 140 / 100 px/s on Dusk by
	# distance; the spec sets the middle per difficulty (150, 160) and the
	# far and near bands keep its ratio.
	"tide_far": {"dusk": 200.0, "nightfall": 214.0, "witching": 229.0},
	"tide_mid": {"dusk": 140.0, "nightfall": 150.0, "witching": 160.0},
	"tide_near": {"dusk": 100.0, "nightfall": 107.0, "witching": 114.0},
	"tide_touch": {"dusk": 0.20, "nightfall": 0.25, "witching": 0.30},
}
const TOLL_COOL := 8.0
const TOLL_LIGHT := 6.0
const TOLL_R := 200.0
const TOLL_S := 0.9
const TOLL_HOLD := 2.0           # s a toll holds the tide
const GRASP_REACH := 64.0
const GRASP_H := 80.0
const GRASP_W := 28.0
const GRASP_UP := 1.0
const GRASP_COOL := 3.0
const CANDLE_R := 90.0
const CANDLE_S := 0.7
const CROWN_R := 120.0           # a crown candle, lit by its ring
const LIFT_V := 420.0            # px/s still water lifts a wader onto its top
const LIFT_SNAP := 12.0          # px: this close under the top, at once
const HUSH_SHRINK := 0.5         # other lights in a Hush zone (not tolls)
const HUSH_SFX := 0.6            # Sfx.set_hush inside a zone
const TIDE_START := 10.0         # tiles behind him as it rises
const TIDE_FAR_AT := 12.0        # tiles: further behind than this, tide_far
const TIDE_NEAR_AT := 6.0        # tiles: closer than this, tide_near
const TIDE_STALL := 2.0
const TIDE_INVULN := 1.0
const TIDE_LEAVE := 1.5          # tiles past the start altar's cell: he has left it
const TIDE_SEE := 14.0           # tiles off screen at which the vignette is at its narrowest
const BARK_BEFORE := 10          # tiles before the first of a thing a stone landing barks
const EDGE_A := 0.30             # decisions.md: W6 floats, buoys and lips
const ANCHOR_REACH := 150.0      # a lantern this near dawnglass feeds it (its light is 140)
# Colours: the Hush's violet-white, drowned brass, old wax, the silver ripple
# (the W6 tell accent decoration never uses).
const WAX := Color("e8dcc0")
const WAX_DARK := Color("8c806a")
const BRASS := Color("7c6a44")
const BRASS_LIT := Color("b89a5a")
const RIPPLE := Color("e0e0ff")
const SILVER := Color("c8c8f0")
const PALE := Color("d8d4f0")
const INK := Color(0.03, 0.025, 0.06)
const STILL_SHEET := Color(0.72, 0.74, 0.9)
const PROP_DIR := "res://art/props/"
const PROPS := ["bell_buoy", "bell_buoy_rung", "buoy_lantern_lit", "buoy_lantern_out", "vigil_candle_out",
		"vigil_candle_lit", "grasp_hand"]

var floats: Array = []           # [Mover]
var buoys: Array = []            # {cell, pos, cool_until, light, rung, line}
var still := {}                  # Vector2i -> until (ftime)
var _cracking := {}              # Vector2i -> 1 (just started) | 2 (its tell sounded)
var grasps: Array = []           # {cell, x, y, state: idle|tell|up|cool, t}
var candles_list: Array = []     # {cell, pos, lit, light, hush, paid, anchor, ring: [index] (a crown's), crown}
var chases: Array = []           # {x0, x1, state: idle|on|done, x, hold, band, t}
var _hush_on := false
var _barks: Array = []           # {key, x0, x1, done}
var _tex := {}
var _tb := TriBatch.new()
var _stepped_hooked := false
var _was_on_float := {}          # Mover -> hero_on last step
var _w6 := false                 # a Hushdeep level (its wading steps play)
var _lift_y := INF               # the still top he's rising onto, INF when not
# A2's look (scripts/tiles/hush.gd, the W6 themes' painter; merged at the
# track B integration from A2's patch): the floats, still water's sheen and
# tell, the grasps' tell and the hands rising out of the line, the buoys'
# silver silhouettes and toll rings. null in a theme it doesn't paint (the
# feel labs, v2's themes): the stand-ins below.
const BUOY_WATER := Vector2(32, 70)   # points_w6.json bell_buoy "water" (frame units, 2 a px)
const HAND_FOOT := Vector2(32, 160)   # grasp_hand's wrist on the lake line
var _art: Script = null
var _pal := {}


func build(w: Node, lv: RefCounted) -> void:
	super.build(w, lv)
	for n in PROPS:
		var p: String = PROP_DIR + n + ".svg"
		if ResourceLoader.exists(p):
			_tex[n] = load(p)
	for e in lv.entities:
		var cell: Vector2i = e["cell"]
		match e["kind"]:
			"float":
				var m := Movers.float_on(cell, int(e.get("length", 1)), knob("float_sink"), 8.0 if lv.is_deep(cell.x, cell.y) else 13.0)
				m.owner = self
				w.add_mover(m)
				floats.append(m)
			"buoy":
				buoys.append({"cell": cell, "pos": LevelData.cell_center(cell), "cool_until": -INF, "light": -1, "rung": -INF,
						"line": _line_of(cell)})
			"grasp":
				grasps.append({"cell": cell, "x": (cell.x + 0.5) * TILE, "y": cell.y * TILE + _line_off(cell), "state": "idle", "t": 0.0})
			"vigil":
				candles_list.append({"cell": cell, "pos": LevelData.cell_floor(cell), "lit": false, "light": -1, "hush": false,
						"paid": false, "anchor": false, "crown": false, "ring": []})
	for r in lv.chase:
		chases.append({"x0": int(r["x0"]), "x1": int(r["x1"]), "state": "idle", "x": -INF, "hold": -INF, "band": 0, "t": 0.0})
	_w6 = int(lv.world) == 6 or not (floats.is_empty() and buoys.is_empty() and grasps.is_empty() and candles_list.is_empty()
			and lv.hush_cols.is_empty() and lv.chase.is_empty())
	_plan_crowns(lv)
	_plan_barks(lv)
	_anchor_lanterns(w, lv)
	_anchor_candles(lv)
	var Themes = load("res://scripts/themes/loader.gd")
	var painter: Script = Themes.painter(str(lv.theme)) if Themes.has_theme(str(lv.theme)) else null
	if painter != null and painter.get_script_method_list().any(func(m): return str(m["name"]) == "draw_float"):
		_art = painter
		_pal = Themes.palette(str(lv.theme))


func _bob(cell: Vector2i, t: float) -> float:
	## A buoy's bob on the lake (px), the same for its sprite and its glow (A2).
	return sin(t * PI + cell.x) * 2.0


func _plan_crowns(lv: RefCounted) -> void:
	## `vigil_crown: x:x1,x2,...[;x:...]`: the candle at column x waits for
	## the candles at x1, x2, ... (the header's columns are absolute).
	var spec := str(lv.headers.get("vigil_crown", "")) if "headers" in lv else ""
	for part in spec.split(";", false):
		var bits := part.split(":")
		if bits.size() != 2:
			continue
		var crown := _candle_at(int(bits[0]))
		if crown < 0:
			continue
		var ring := []
		for s in bits[1].split(",", false):
			var i := _candle_at(int(s))
			if i >= 0 and i != crown:
				ring.append(i)
		if not ring.is_empty():
			candles_list[crown]["crown"] = true
			candles_list[crown]["ring"] = ring


func _candle_at(x: int) -> int:
	for i in candles_list.size():
		if (candles_list[i]["cell"] as Vector2i).x == x:
			return i
	return -1


func _anchor_candles(lv: RefCounted) -> void:
	## A Vigil candle whose light reaches dawnglass feeds it: an anchor, as a
	## lantern is (decisions.md): the Stillmaw never swallows it.
	for c in candles_list:
		var at: Vector2 = (c["pos"] as Vector2) - Vector2(0, 30)
		var r := CROWN_R if c["crown"] else CANDLE_R
		for y in range(maxi((c["cell"] as Vector2i).y - 5, 0), mini((c["cell"] as Vector2i).y + 5, lv.height)):
			for x in range((c["cell"] as Vector2i).x - 5, (c["cell"] as Vector2i).x + 6):
				var t: int = lv.tile(x, y)
				if (t == LevelData.DAWNGLASS or t == LevelData.DAWN_ON) and LevelData.cell_center(Vector2i(x, y)).distance_to(at) <= r:
					c["anchor"] = true


func _anchor_lanterns(w: Node, lv: RefCounted) -> void:
	## A lantern post whose light reaches dawnglass feeds it: it's an anchor
	## (decisions.md), so a Stillmaw never swallows the light a crossing needs
	## (6-4's Sanctum crack). The dispatcher built its posts before the modules.
	var lf = w.get("features")
	if lf == null or not ("lanterns" in lf):
		return
	var panes := []
	for y in lv.height:
		for x in lv.width:
			var t: int = lv.tile(x, y)
			if t == LevelData.DAWNGLASS or t == LevelData.DAWN_ON:
				panes.append(LevelData.cell_center(Vector2i(x, y)))
	if panes.is_empty():
		return
	for l in lf.lanterns:
		for p in panes:
			if (l["flame"] as Vector2).distance_to(p) <= ANCHOR_REACH:
				l["anchor"] = true
				break


func _line_off(c: Vector2i) -> float:
	## The water line in a surface cell: deep water 8 px in, shallow 13 (the
	## dispatcher draws it there).
	return 8.0 if level.is_deep(c.x, c.y) else 13.0


func _line_of(c: Vector2i) -> float:
	return c.y * TILE + _line_off(c)


# ---------------------------------------------------------------- queries

func toll(cell: Vector2i) -> void:
	for b in buoys:
		if b["cell"] == cell:
			_toll(b)


func _toll(b: Dictionary) -> void:
	if ftime() < float(b["cool_until"]):
		return
	b["cool_until"] = ftime() + TOLL_COOL
	b["rung"] = ftime()
	b["light"] = world.add_light((b["pos"] as Vector2) + Vector2(0, -20), TOLL_R, TOLL_S, TOLL_LIGHT, "toll,haven,lamp")
	var until := ftime() + knob("still_time")
	for c in Reach.still_cells(level, b["cell"]):
		var t: int = level.tile(c.x, c.y)
		if t == LevelData.WATER or t == LevelData.STILL:
			if t == LevelData.WATER:
				level.set_tile(c, LevelData.STILL)
				world._redraw_at(c.x)
			still[c] = maxf(float(still.get(c, -INF)), until)
			_cracking.erase(c)
	# The jaws under it hold at once (their next think would tell), and
	# whoever is in it now is held up by it.
	_hold_jaws()
	_lift(player(), true)
	for ch in chases:
		if ch["state"] == "on":
			ch["hold"] = maxf(float(ch["hold"]), ftime() + TOLL_HOLD)
	world._sfx("buoy_toll")
	world._sfx("buoy_light", 1.0, 0.0, 0.7)
	if world.glow:
		world.glow.burst((b["pos"] as Vector2) + Vector2(0, -20), 10, RIPPLE, 90.0, 0.6, -40.0, 2.0)


func still_at(p: Vector2) -> bool:
	return level.tile(floori(p.x / TILE), floori(p.y / TILE)) == LevelData.STILL


func put_out(l: Dictionary) -> void:
	## The Stillmaw swallows a light: never one tagged "anchor".
	if str(l.get("tag", "")).contains("anchor"):
		return
	for c in candles_list:
		if c["pos"] == l.get("pos") and c["lit"] and not c["anchor"]:
			c["lit"] = false
			if int(c["light"]) >= 0:
				world.remove_light(int(c["light"]))
			c["light"] = -1


func relight(l: Dictionary, _extra := 0.0) -> void:
	## A swallowed candle given back (the Stillmaw's choke or death): lit
	## again as it was. A candle burns for good, so the choke's extra seconds
	## mean nothing to it, and its XP was paid the first time.
	for c in candles_list:
		if c["pos"] == l.get("pos"):
			_light_candle(c, c["crown"])


func lamps() -> Array:
	## The fixed lamps here (the Vigil candles), as dicts with pos and tag.
	var out := []
	for c in candles_list:
		out.append({"pos": c["pos"], "lit": c["lit"], "tag": "vigil,haven,anchor" if c["anchor"] else "vigil,haven"})
	return out


func in_hush_zone(p: Vector2) -> bool:
	var x := floori(p.x / TILE)
	for r in level.hush_cols:
		if x >= int(r["x0"]) and x <= int(r["x1"]):
			return true
	return false


func tide_x() -> float:
	for ch in chases:
		if ch["state"] == "on":
			return float(ch["x"])
	return -INF


func candles() -> Dictionary:
	var lit := 0
	for c in candles_list:
		if c["lit"]:
			lit += 1
	return {"lit": lit, "total": candles_list.size()}


func grasp_rect(g: Dictionary) -> Rect2:
	return Rect2(float(g["x"]) - GRASP_W * 0.5, float(g["y"]) - GRASP_H, GRASP_W, GRASP_H)


# ---------------------------------------------------------------- the step

func step(dt: float) -> void:
	var pl := player()
	if _w6:
		_hook_steps(pl)
	for m in floats:
		m.sink = knob("float_sink")
		var was: bool = _was_on_float.get(m, false)
		if m.hero_on and not was:
			world._sfx("float_sink", 1.0, 0.0, 0.8)
		if was and not m.present and world.has_method("note_feature"):
			world.note_feature("float")
		_was_on_float[m] = m.hero_on
	_step_still()
	_lift(pl, false, dt)
	_step_grasps(pl)
	_step_hush(pl)
	_hold_jaws()
	_step_tide(dt, pl)
	_step_barks(pl)


func _step_still() -> void:
	var tell := knob("still_tell")
	var gone := []
	for c in still:
		var left: float = float(still[c]) - ftime()
		if left <= 0.0:
			gone.append(c)
		elif left <= tell and not _cracking.has(c):
			_cracking[c] = 1
	# One tell sound for every run that starts cracking this step.
	var fresh := 0
	for c in _cracking:
		if int(_cracking[c]) == 1:
			_cracking[c] = 2
			fresh += 1
	if fresh > 0:
		world._tell_sfx("still_crack", tell)
	for c in gone:
		still.erase(c)
		_cracking.erase(c)
		if level.tile(c.x, c.y) == LevelData.STILL:
			level.restore_tile(c)
			world._redraw_at(c.x)
			if world.glow and view().grow(64.0).has_point(LevelData.cell_center(c)):
				world.glow.burst(Vector2((c.x + 0.5) * TILE, c.y * TILE + 6.0), 3, STILL_SHEET, 60.0, 0.35, 400.0, 1.8)
	if not gone.is_empty():
		var pl := player()
		if pl != null and pl.alive and world.has_method("note_feature"):
			var feet := Vector2i(floori(pl.position.x / TILE), floori((pl.position.y + 1.0) / TILE))
			if gone.has(feet):
				world.note_feature("still")


func _step_grasps(pl: Node2D) -> void:
	for g in grasps:
		var age := ftime() - float(g["t"])
		match g["state"]:
			"idle":
				if pl != null and pl.alive and world.state == "play" and absf(pl.center().x - float(g["x"])) <= GRASP_REACH:
					g["state"] = "tell"
					g["t"] = ftime()
					world._tell_sfx("grasp_hiss", knob("grasp_tell"))
			"tell":
				if age >= knob("grasp_tell"):
					g["state"] = "up"
					g["t"] = ftime()
					world._sfx("grasp_rise", 1.0, 0.0, 0.8)
			"up":
				if age >= GRASP_UP:
					g["state"] = "cool"
					g["t"] = ftime()
			"cool":
				if age >= GRASP_COOL:
					g["state"] = "idle"


func _step_hush(pl: Node2D) -> void:
	if pl != null and pl.alive:
		var hz := in_hush_zone(pl.center())
		if hz:
			world.dim("hush_zone", knob("hush_light"), 0.1)
		if hz != _hush_on:
			_hush_on = hz
			if hz:
				world._sfx("hush_near", 1.0, 0.0, 0.8)
			var sfx = world.get_node_or_null("/root/Sfx") if world.is_inside_tree() else null
			if sfx != null and sfx.has_method("set_hush") and not world.headless:
				sfx.set_hush(HUSH_SFX if hz else 0.0)
	if level.hush_cols.is_empty():
		return
	# Lanterns in a zone burn at half their radius (the dispatcher set this
	# tick's flicker just before the modules step). Tolls keep theirs.
	var lf = world.features
	var wl = world.get("lights")
	if lf == null or wl == null or not ("dyn" in wl) or not ("lanterns" in lf):
		return
	for l in lf.lanterns:
		if not l["lit"] or l["brazier"] or int(l["id"]) < 0 or not in_hush_zone(l["flame"]):
			continue
		var d = wl.dyn.get(int(l["id"]))
		if d is Dictionary:
			world.move_light(int(l["id"]), l["flame"], float(d["r"]) * HUSH_SHRINK)


func _lift(pl: Node2D, at_toll: bool, dt := 1.0 / 120.0) -> void:
	## Still water holds whoever is in it. A hero standing in a stilled cell
	## (wading on the floor under a shallow run, or riding a float that sank
	## in a deep one) rises onto its top: at once from LIFT_SNAP px or less,
	## else at LIFT_V (a wader, a tile in 0.08 s). At the toll itself, one
	## just under the line in the air is caught too. Never while he jumps up
	## through it (he lands on top), nor into a ceiling.
	if pl == null or not pl.alive or still.is_empty() or pl.climbing or float(pl.get("ledge_t")) >= 0.0:
		_lift_y = INF
		return
	var top := _still_top_in(pl)
	if top == INF:
		_lift_y = INF
		return
	var depth: float = pl.position.y - top
	var standing: bool = pl.on_floor or pl.riding != null or _lift_y < INF
	if not standing and not (at_toll and depth <= LIFT_SNAP):
		return
	if pl.velocity.y < -40.0 or not _room_at(pl, top):
		_lift_y = INF
		return
	pl.velocity.y = minf(pl.velocity.y, 0.0)
	pl.riding = null
	pl.on_floor = true
	if depth <= LIFT_SNAP:
		pl.position.y = top
		_lift_y = INF
	else:
		pl.position.y = maxf(top, pl.position.y - LIFT_V * dt)
		_lift_y = top if pl.position.y > top + 0.01 else INF


func _still_top_in(pl: Node2D) -> float:
	## The top of a still cell his feet are inside (below its top), or INF.
	var r: Rect2 = pl.rect()
	var cy := floori((pl.position.y - 0.5) / TILE)
	for cx in range(floori((r.position.x + 0.01) / TILE), floori((r.end.x - 0.01) / TILE) + 1):
		if level.tile(cx, cy) == LevelData.STILL:
			return float(cy * TILE)
	return INF


func _room_at(pl: Node2D, feet_y: float) -> bool:
	var r := Rect2(pl.position.x - pl.size.x * 0.5, feet_y - pl.size.y, pl.size.x, pl.size.y - 0.5)
	for cy in range(floori(r.position.y / TILE), floori(r.end.y / TILE) + 1):
		for cx in range(floori((r.position.x + 0.01) / TILE), floori((r.end.x - 0.01) / TILE) + 1):
			if LevelData.is_solid(level.tile(cx, cy)):
				return false
	return true


func _hold_jaws() -> void:
	## Brinejaws under still water can't leap (spec §3.2). A jaw under a
	## still cell is kept cooling, quietly, until its water opens again (its
	## tell never starts, so no warning splash for a leap that can't come).
	## (MA's brinejaw.gd could ask world.features.still_at itself.)
	if still.is_empty():
		return
	for e in world.enemies:
		if not e.alive or str(e.get("kind")) != "brinejaw":
			continue
		var st = e.get("state")
		if st != "hide" and st != "tell" and st != "cool":
			continue
		var sy = e.get("surface_y")
		if sy == null:
			continue
		var c := Vector2i(floori(e.position.x / TILE), floori((float(sy) - 1.0) / TILE))
		if level.tile(c.x, c.y) == LevelData.STILL and still.has(c):
			e.set("state", "cool")
			e.set("timer", maxf(float(e.get("timer")), float(still[c]) - ftime() + 0.1))


func _step_tide(dt: float, pl: Node2D) -> void:
	if chases.is_empty() or pl == null:
		return
	for i in chases.size():
		var ch: Dictionary = chases[i]
		match ch["state"]:
			"idle":
				var x: float = pl.position.x
				if pl.alive and world.state == "play" and x > (float(ch["x0"]) + TIDE_LEAVE) * TILE and x < float(ch["x1"]) * TILE:
					ch["state"] = "on"
					ch["x"] = x - TIDE_START * TILE
					ch["hold"] = -INF
					ch["band"] = 1
					ch["t"] = ftime()
					world._sfx("tide_rise")
					if i == 0:
						_bark("first_tide")
			"on":
				if _end_lit(ch):
					ch["state"] = "done"
					ch["t"] = ftime()
					continue
				if not pl.alive or world.state != "play":
					continue
				var d: float = (pl.position.x - float(ch["x"])) / TILE
				var band := 2 if d > TIDE_FAR_AT else (1 if d >= TIDE_NEAR_AT else 0)
				if band == 2 and int(ch["band"]) < 2:
					world._sfx("tide_rise", 1.0, 0.0, 0.5)
				ch["band"] = band
				if ftime() >= float(ch["hold"]):
					var v: float = [knob("tide_near"), knob("tide_mid"), knob("tide_far")][band]
					ch["x"] = float(ch["x"]) + v * dt
				_tide_erase(float(ch["x"]))
				var pr: Rect2 = pl.rect()
				if float(ch["x"]) >= pr.position.x + 2.0 and pl.invuln <= 0.0:
					var hit: bool = world.hurt_player(knob("tide_touch"), float(ch["x"]), "tide", null,
							{"pct": true, "no_knock": true, "feature": "tide", "move": "tide"})
					if hit:
						ch["hold"] = maxf(float(ch["hold"]), ftime() + TIDE_STALL)
						pl.invuln = maxf(pl.invuln, TIDE_INVULN)
						if world.glow:
							world.glow.burst(pl.center(), 14, PALE, 120.0, 0.5, 0.0, 2.2)


func _end_lit(ch: Dictionary) -> bool:
	## The range's end altar lit, or Wick past it (a jump over it that
	## didn't light it still ends the chase: the tide never follows him on).
	var pl := player()
	if pl != null and pl.position.x >= (float(ch["x1"]) + 1.0) * TILE:
		return true
	for a in world.altars:
		if int((a["cell"] as Vector2i).x) == int(ch["x1"]):
			return bool(a["lit"])
	return false


func _tide_erase(x: float) -> void:
	for e in world.enemies:
		if e.alive and e != world.boss and e.position.x < x:
			e.alive = false
			e.set("gone", true)
			if world.glow:
				world.glow.burst(e.position + Vector2(0, -12), 10, PALE, 60.0, 0.6, -60.0, 2.0)


# ---------------------------------------------------------------- barks

func _plan_barks(lv: RefCounted) -> void:
	## Hollin's how-tos in 6-1 and 6-2 only (ST: never in 6-3 or 6-4); each
	## fires on stone within BARK_BEFORE tiles before the first of its thing.
	var id := str(lv.id)
	if id != "6-1" and id != "6-2":
		return
	var first := {}
	for e in lv.entities:
		var k := str(e["kind"])
		if k in ["float", "buoy", "grasp", "vigil"]:
			var x: int = (e["cell"] as Vector2i).x
			if not first.has(k) or x < int(first[k]):
				first[k] = x
	var zones: Array = lv.hush_cols.duplicate()
	zones.sort_custom(func(a, b): return int(a["x0"]) < int(b["x0"]))
	if not zones.is_empty():
		first["hush"] = int(zones[0]["x0"])
	if zones.size() > 1 and id == "6-1":
		first["deepdark"] = int(zones[1]["x0"])
	var keys := {"float": "first_float", "buoy": "first_buoy", "grasp": "first_grasp", "vigil": "first_candle",
			"hush": "first_hush_zone", "deepdark": "first_deepdark"}
	for k in first:
		_barks.append({"key": keys[k], "x0": int(first[k]) - BARK_BEFORE, "x1": int(first[k]) + 1, "done": false})


func _step_barks(pl: Node2D) -> void:
	if _barks.is_empty() or pl == null or not pl.alive or not pl.on_floor or pl.riding != null:
		return
	var x := floori(pl.position.x / TILE)
	var under: int = level.tile(x, floori((pl.position.y + 1.0) / TILE))
	if not LevelData.is_safe(under):
		return
	for b in _barks:
		if not b["done"] and x >= int(b["x0"]) and x <= int(b["x1"]):
			b["done"] = true
			_bark(str(b["key"]))
			return   # one at a time


func _bark(key: String) -> void:
	if world.has_method("bark") and world.get("mode") == null:
		world.bark(key)


func _hook_steps(pl: Node2D) -> void:
	if _stepped_hooked or pl == null or not pl.has_signal("stepped"):
		return
	_stepped_hooked = true
	pl.stepped.connect(_on_step)


func _on_step() -> void:
	var pl := player()
	if pl == null:
		return
	var wet := false
	if pl.riding != null and str(pl.riding.get("tag")) == "float":
		wet = true
	elif level.tile(floori(pl.position.x / TILE), floori((pl.position.y + 1.0) / TILE)) == LevelData.STILL:
		wet = true
	elif world.features != null and world.features.has_method("wading") and world.features.wading():
		wet = true
	if wet:
		world._sfx("lake_step", 1.0, 0.0, 0.6)


# ---------------------------------------------------------------- touch

func touch(pl: Node2D) -> void:
	var pr: Rect2 = pl.rect()
	for b in buoys:
		if _buoy_rect(b).intersects(pr):
			_toll(b)
	for c in candles_list:
		if not c["lit"] and not c["crown"] and _candle_rect(c).intersects(pr):
			_light_candle(c)
	for g in grasps:
		if g["state"] == "up" and grasp_rect(g).intersects(pr.grow(-2.0)):
			var dmg: float = Combat.enemy_hit(knob("grasp_dmg"), world.area, world.diff, world.strength)
			if world.hurt_player(dmg, float(g["x"]), "hit", null, {"feature": "grasp", "move": "grasp"}):
				world.douse_player()


func _buoy_rect(b: Dictionary) -> Rect2:
	## The bell and its float: the cell, and a bell's height over the water.
	return Rect2((b["pos"] as Vector2) - Vector2(16, 24), Vector2(32, 32))


func _candle_rect(c: Dictionary) -> Rect2:
	return Rect2((c["pos"] as Vector2) - Vector2(12, 40), Vector2(24, 40))


func strike(r: Rect2, _attack_id: int) -> void:
	for b in buoys:
		if _buoy_rect(b).intersects(r):
			_toll(b)
	for c in candles_list:
		if not c["lit"] and not c["crown"] and _candle_rect(c).intersects(r):
			_light_candle(c)


func shot_hit(shot: Dictionary) -> void:
	## A hero's shot rings a buoy and lights a Vigil candle as a swing does
	## (the Taperwitch's spark, the Sootrunner's knife, the Bellfounder's
	## toll), and stops there.
	if str(shot.get("owner", "enemy")) != "player":
		return
	var p: Vector2 = shot["pos"]
	var rad := float(shot.get("radius", 6.0))
	for b in buoys:
		if _buoy_rect(b).grow(rad).has_point(p):
			_toll(b)
			shot["life"] = 0.0
			return
	for c in candles_list:
		if not c["lit"] and not c["crown"] and _candle_rect(c).grow(rad).has_point(p):
			_light_candle(c)
			shot["life"] = 0.0
			return


func snapshot() -> Dictionary:
	## What an altar's snapshot keeps of this module (world._write_suspend,
	## "Continue from the altar"): the lit Vigil candles' cells. A relit
	## candle stays lit for good (the rev5 review: after a resume every candle
	## was out again and paid its XP twice).
	var lit: Array = []
	for c in candles_list:
		if c["lit"]:
			lit.append([(c["cell"] as Vector2i).x, (c["cell"] as Vector2i).y])
	return {"candles": lit} if not lit.is_empty() else {}


func restore(d: Dictionary) -> void:
	## A snapshot's candles lit again, quietly (no chime, no XP: paid), and a
	## crown whose ring is whole with them.
	var cells: Array = d.get("candles", []) if d.get("candles") is Array else []
	for c in candles_list:
		var cell: Vector2i = c["cell"]
		for v in cells:
			if v is Array and v.size() == 2 and int(v[0]) == cell.x and int(v[1]) == cell.y:
				c["paid"] = true
				_light_candle(c, true, true)
	for c in candles_list:
		if c["crown"] and not c["lit"]:
			var whole := not (c["ring"] as Array).is_empty()
			for i in c["ring"]:
				if not candles_list[int(i)]["lit"]:
					whole = false
			if whole:
				c["paid"] = true
				_light_candle(c, true, true)


func _light_candle(c: Dictionary, by_ring := false, quiet := false) -> void:
	## Lit for good (a crown only by its ring). Its XP is paid the first time
	## only: a candle a Stillmaw swallowed and gave back pays nothing again.
	## quiet: a snapshot's, lit as it was (no chime, no sparks, no crown check).
	if c["lit"] or (c["crown"] and not by_ring):
		return
	c["lit"] = true
	var hz := in_hush_zone(c["pos"])
	c["hush"] = hz
	var r := (CROWN_R if c["crown"] else CANDLE_R) * (HUSH_SHRINK if hz else 1.0)
	c["light"] = world.add_light((c["pos"] as Vector2) - Vector2(0, 30), r, CANDLE_S, -1.0,
			"vigil,haven,lamp,anchor" if c["anchor"] else "vigil,haven,lamp")
	if quiet:
		return
	world._sfx("candle_light")
	if world.glow:
		world.glow.burst((c["pos"] as Vector2) - Vector2(0, 26), 16 if c["crown"] else 10, Color("f7b64a"), 110.0 if c["crown"] else 80.0,
				0.5, -60.0, 2.0)
	if not c["paid"]:
		c["paid"] = true
		var md = world.get("mode")
		if world.has_method("gain_xp") and (md == null or md.allows("xp")):
			world.gain_xp(Progression.event_xp("candle", world.area), c["pos"])
	_check_crowns()


func _check_crowns() -> void:
	## A crown lights once its whole ring is lit: sparks run from each.
	for c in candles_list:
		if not c["crown"] or c["lit"]:
			continue
		var all_lit := true
		for i in c["ring"]:
			if not candles_list[int(i)]["lit"]:
				all_lit = false
		if not all_lit:
			continue
		if world.glow:
			for i in c["ring"]:
				var from: Vector2 = (candles_list[int(i)]["pos"] as Vector2) - Vector2(0, 26)
				var to: Vector2 = (c["pos"] as Vector2) - Vector2(0, 26)
				for k in 4:
					world.glow.burst(from.lerp(to, (k + 1) / 5.0), 3, Color("f7b64a"), 30.0, 0.5, -30.0, 1.8)
		world._sfx("buoy_light", 1.0, 0.0, 0.6)
		_light_candle(c, true)


func on_respawn() -> void:
	for g in grasps:
		g["state"] = "idle"
	for ch in chases:
		if ch["state"] == "on":
			ch["state"] = "idle"
			ch["x"] = -INF
			ch["hold"] = -INF


# ---------------------------------------------------------------- lights

func lights() -> Array:
	var out := []
	for g in grasps:
		if g["state"] == "tell":
			# The fingertips' glint (a tell light: it counts for nothing).
			out.append({"p": Vector2(g["x"], float(g["y"]) - 6.0), "r": 30.0, "s": 0.5, "gameplay": false, "kind": "tell"})
	var tx := tide_x()
	if tx > -INF:
		var cy := view().get_center().y
		# The wall eats the light round its front (Hush lights: never the
		# hero's own pool, the shader's guard).
		for k in 3:
			out.append({"p": Vector2(tx - 70.0, cy + (k - 1) * 150.0), "r": 170.0, "s": -0.85, "gameplay": false, "kind": "hush"})
	return out


# ---------------------------------------------------------------- drawing

func draw_under(ci: CanvasItem) -> void:
	var v := view().grow(TILE * 2)
	if _art != null:
		_draw_under_art(ci, v)
		return
	# Floats: old wax slabs; a loaded one rides low, an under one is a shape
	# (drawn first: one in stilled water shows under the sheet).
	for m in floats:
		var r: Rect2 = m.rect()
		if not v.intersects(r):
			continue
		var a := 1.0 if m.present else 0.3
		var sink_k: float = clampf(float(m.depth) / maxf(float(m.under), 1.0), 0.0, 1.0)
		var top := WAX.lerp(WAX_DARK, sink_k * 0.6)
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 10)), Color(top, a))
		ci.draw_rect(Rect2(r.position + Vector2(0, 7), Vector2(r.size.x, 3)), Color(WAX_DARK, a))
		for i in int(r.size.x / 16.0):
			ci.draw_rect(Rect2(r.position + Vector2(i * 16 + 6, 3), Vector2(4, 2)), Color(WAX_DARK, 0.5 * a))
	# Still water: a pale sheet over the stilled surface, cracking in its tell.
	for c in still:
		var at := Vector2(c.x * TILE, c.y * TILE)
		if not v.has_point(at):
			continue
		var left: float = float(still[c]) - ftime()
		var a := 0.62
		if left <= knob("still_tell"):
			a = 0.62 if fmod(left, 0.3) > 0.12 else 0.34
		ci.draw_rect(Rect2(at, Vector2(TILE, _line_off(c) + 3.0)), Color(STILL_SHEET.darkened(0.45), a))
		ci.draw_rect(Rect2(at, Vector2(TILE, 3.0)), Color(STILL_SHEET, a))
	# Bell-buoys: a float ring, the bell, a lantern cage.
	for b in buoys:
		var p: Vector2 = b["pos"]
		if not v.has_point(p):
			continue
		var line: float = float(b["line"])
		var rung := ftime() - float(b["rung"])
		var sway := sin(rung * 14.0) * 3.0 * maxf(0.0, 1.0 - rung / 1.2) if rung < 1.2 else 0.0
		var tex: Texture2D = _tex.get("bell_buoy_rung" if rung < TOLL_LIGHT else "bell_buoy")
		if tex != null:
			ci.draw_texture_rect(tex, Rect2(Vector2(p.x - 16.0 + sway, line - 40.0), Vector2(32, 48)), false)
			continue
		ci.draw_rect(Rect2(Vector2(p.x - 13, line - 5), Vector2(26, 8)), WAX_DARK.darkened(0.2))
		ci.draw_rect(Rect2(Vector2(p.x - 13, line - 5), Vector2(26, 2)), WAX_DARK)
		ci.draw_rect(Rect2(Vector2(p.x - 7 + sway, line - 22), Vector2(14, 16)), BRASS)
		ci.draw_rect(Rect2(Vector2(p.x - 9 + sway, line - 8), Vector2(18, 3)), BRASS_LIT)
		ci.draw_rect(Rect2(Vector2(p.x - 3 + sway, line - 30), Vector2(6, 8)), BRASS.darkened(0.3))
	# Vigil candles: old stubs on the rocks.
	for c in candles_list:
		var p: Vector2 = c["pos"]
		if not v.has_point(p):
			continue
		var tex: Texture2D = _tex.get("vigil_candle_lit" if c["lit"] else "vigil_candle_out")
		if tex != null:
			ci.draw_texture_rect(tex, Rect2(p - Vector2(16, 32), Vector2(32, 32)), false)
			continue
		ci.draw_rect(Rect2(p + Vector2(-8, -4), Vector2(16, 4)), WAX_DARK.darkened(0.3))
		ci.draw_rect(Rect2(p + Vector2(-5, -24), Vector2(10, 20)), WAX if c["lit"] else WAX.darkened(0.45))
		ci.draw_rect(Rect2(p + Vector2(-5, -24), Vector2(10, 3)), WAX.lightened(0.2) if c["lit"] else WAX.darkened(0.3))
		ci.draw_rect(Rect2(p + Vector2(-1, -28), Vector2(2, 4)), Color(0.15, 0.12, 0.1))


func _draw_under_art(ci: CanvasItem, v: Rect2) -> void:
	## A2's look under the dark: the floats (hush.gd draw_float: what's under
	## the line shows through the ink), the bell-buoys on their water point,
	## bobbing, and the Vigil candles. Still water is the painter's (a STILL
	## tile, redrawn as it forms and breaks).
	var t := ftime()
	_tb.clear()
	for m in floats:
		var r: Rect2 = m.rect()
		if v.intersects(r):
			_art.draw_float(ci, _tb, r, float(m.rest_y) + Movers.FLOAT_TOP, t, _pal)
	for b in buoys:
		var p: Vector2 = b["pos"]
		if not v.has_point(p):
			continue
		var cell: Vector2i = b["cell"]
		var rung := t - float(b["rung"])
		var tex: Texture2D = _tex.get("bell_buoy_rung" if rung < TOLL_LIGHT else "bell_buoy")
		if tex != null:
			var sway := sin(rung * 14.0) * 3.0 * maxf(0.0, 1.0 - rung / 1.2) if rung < 1.2 else 0.0
			var foot := Vector2(p.x + sway, float(b["line"]) + _bob(cell, t))
			ci.draw_texture_rect(tex, Rect2(foot - BUOY_WATER * 0.5, tex.get_size() * 0.25), false)
	for c in candles_list:
		var p: Vector2 = c["pos"]
		if not v.has_point(p):
			continue
		var tex: Texture2D = _tex.get("vigil_candle_lit" if c["lit"] else "vigil_candle_out")
		if tex != null:
			ci.draw_texture_rect(tex, Rect2(p - Vector2(16, 32), Vector2(32, 32)), false)
	_tb.flush(ci)


func _draw_glow_art(glow: Node2D, v: Rect2) -> void:
	## A2's look above the dark (the tells read in it): the grasps' tell and
	## hands, the floats' silver edges, still water's sheen and its cracking
	## tell (hush.gd draw_still_glow, a run at a time), the buoys' silhouettes
	## (0.32, 0.55 rung), the toll's ring and lantern flame, the candles.
	var t := ftime()
	for g in grasps:
		var x := float(g["x"])
		var y := float(g["y"])
		if not v.has_point(Vector2(x, y)):
			continue
		var age := t - float(g["t"])
		match g["state"]:
			"tell":
				_art.draw_grasp_tell(glow, _tb, Vector2(x, y), clampf(age / maxf(knob("grasp_tell"), 0.01), 0.0, 1.0), t)
			"up":
				_hands(glow, x, y, minf(age / 0.12, 1.0))
			"cool":
				if age < 0.25:
					_hands(glow, x, y, 1.0 - age / 0.25)
	for m in floats:
		if m.present:
			var r: Rect2 = m.rect()
			if v.intersects(r):
				_art.draw_float_glow(glow, _tb, r, float(m.rest_y) + Movers.FLOAT_TOP, bool(m.hero_on) or int(m.rider_count) > 0, t)
	# Still water, a run at a time (the cells of one row side by side).
	var cells: Array = still.keys()
	cells.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var i := 0
	while i < cells.size():
		var c0: Vector2i = cells[i]
		var j := i
		var until := float(still[c0])
		while j + 1 < cells.size() and (cells[j + 1] as Vector2i).y == c0.y and (cells[j + 1] as Vector2i).x == (cells[j] as Vector2i).x + 1:
			j += 1
			until = minf(until, float(still[cells[j]]))
		var x0 := c0.x * TILE
		var x1 := ((cells[j] as Vector2i).x + 1) * TILE
		if x1 >= v.position.x and x0 <= v.end.x:
			var left := until - t
			var tell := clampf(1.0 - left / maxf(knob("still_tell"), 0.01), 0.0, 1.0) if left <= knob("still_tell") else 0.0
			_art.draw_still_glow(glow, _tb, float(x0), float(x1), float(c0.y * TILE), tell, t)
		i = j + 1
	for b in buoys:
		var p: Vector2 = b["pos"]
		if not v.has_point(p):
			continue
		var cell: Vector2i = b["cell"]
		var line: float = float(b["line"])
		var rung := t - float(b["rung"])
		_art.draw_buoy_glow(glow, _tb, Vector2(p.x, line + _bob(cell, t)), rung < TOLL_LIGHT)
		if rung < TOLL_LIGHT:
			glow.flame(Vector2(p.x, line + _bob(cell, t) - 26.0), 8.0 * minf(1.0, TOLL_LIGHT - rung), p.x * 0.1)
			if rung < 1.2:
				_art.draw_buoy_ring(glow, _tb, Vector2(p.x, line), rung / 1.2)
	for c in candles_list:
		var p: Vector2 = c["pos"]
		if not v.has_point(p):
			continue
		if c["lit"]:
			glow.flame(p + Vector2(0, -27), 12.0 if c["crown"] else 9.0, p.x * 0.07)
		else:
			var br := 0.45 + 0.25 * sin(t * 2.2 + p.x * 0.03)
			_tb.circle(p + Vector2(0, -28), 2.0, Color(PALE, br))
			glow.draw_rect(Rect2(p + Vector2(-5, -24), Vector2(10, 1.5)), Color(SILVER, 0.45))
		if c["crown"] and not c["lit"]:
			var n: int = (c["ring"] as Array).size()
			for k in n:
				var ang := PI * (1.15 + 0.7 * (k / maxf(n - 1.0, 1.0)))
				var at := p + Vector2(0, -34) + Vector2(cos(ang), sin(ang)) * 20.0
				if candles_list[int(c["ring"][k])]["lit"]:
					_tb.circle(at, 3.0, Color("f7b64a"))
					_tb.circle(at, 1.4, Color(1.0, 0.95, 0.8))
				else:
					_tb.ring(at, 3.0, 1.2, Color(PALE, 0.55))


func draw_glow(glow: Node2D) -> void:
	var v := view().grow(TILE * 2)
	_tb.clear()
	if _art != null:
		_draw_glow_art(glow, v)
		_draw_tide(glow)
		_tb.flush(glow)
		return
	# Grasps: the tell's ripples and fingertips, then the hands.
	for g in grasps:
		var x := float(g["x"])
		var y := float(g["y"])
		if not v.has_point(Vector2(x, y)):
			continue
		var age := ftime() - float(g["t"])
		match g["state"]:
			"tell":
				var k: float = clampf(age / maxf(knob("grasp_tell"), 0.01), 0.0, 1.0)
				for i in 3:
					var rk := fmod(k * 1.5 + i / 3.0, 1.0)
					_ring(Vector2(x, y), 12.0 + 40.0 * rk, 3.5 + 7.0 * rk, 2.0, Color(RIPPLE, 0.95 * (1.0 - rk)))
				for i in 4:
					var fx := x - 9.0 + i * 6.0
					var fy := y - 3.0 - (5.0 + 9.0 * k) * (0.6 + 0.4 * sin(i * 1.7))
					_tb.ellipse(Vector2(fx, fy), 2.2, 3.4, Color(PALE, 0.6 + 0.4 * k))
					_tb.line(Vector2(fx, fy + 3.0), Vector2(fx, y), 1.5, Color(SILVER, 0.35 * k))
			"up":
				_hands(glow, x, y, minf(age / 0.12, 1.0))
			"cool":
				if age < 0.25:
					_hands(glow, x, y, 1.0 - age / 0.25)
	# Buoys: the glow edge, the lantern, the toll's rings on the water.
	for b in buoys:
		var p: Vector2 = b["pos"]
		if not v.has_point(p):
			continue
		var line: float = float(b["line"])
		glow.draw_rect(Rect2(Vector2(p.x - 13, line - 5), Vector2(26, 2)), Color(SILVER, EDGE_A))
		glow.draw_rect(Rect2(Vector2(p.x - 7, line - 22), Vector2(14, 2)), Color(SILVER, EDGE_A))
		var rung := ftime() - float(b["rung"])
		if rung < TOLL_LIGHT:
			glow.flame(Vector2(p.x, line - 30.0), 8.0 * minf(1.0, TOLL_LIGHT - rung), p.x * 0.1)
			if rung < 1.2:
				for i in 3:
					var rk := clampf((rung - i * 0.25) / 0.9, 0.0, 1.0)
					if rk > 0.0 and rk < 1.0:
						_ring(Vector2(p.x, line), 14.0 + 90.0 * rk, 3.0 + 8.0 * rk, 1.5, Color(RIPPLE, 0.7 * (1.0 - rk)))
		else:
			# Out: a cold glint where the lantern hangs, so it reads in the dark.
			_tb.circle(Vector2(p.x, line - 27.0), 2.0, Color(PALE, 0.5))
	# Floats: the glow edge (EDGE_A), riding with them.
	for m in floats:
		if m.present:
			var r: Rect2 = m.rect()
			if v.intersects(r):
				glow.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(SILVER, EDGE_A))
	# Still water: the crack tell's white glints.
	for c in still:
		var left: float = float(still[c]) - ftime()
		if left > knob("still_tell"):
			continue
		var at := Vector2(c.x * TILE, c.y * TILE)
		if not v.has_point(at):
			continue
		var k: float = 1.0 - left / maxf(knob("still_tell"), 0.01)
		# Cracks run across the sheet as the breath runs out (white core, 2 px).
		var seed := float((c.x * 7 + c.y * 3) % 11)
		var x0 := at.x + 2.0
		var y0 := at.y + 1.5
		var pts := PackedVector2Array([Vector2(x0, y0)])
		for j in 4:
			pts.append(Vector2(x0 + (7.0 + 0.6 * seed) * (j + 1) * minf(k * 1.4, 1.0), y0 + (2.5 if (j + int(seed)) % 2 == 0 else 0.5)))
		_tb.polyline(pts, 2.0, Color(1, 1, 1, 0.55 + 0.4 * k))
		var cx := at.x + 8.0 + seed
		_tb.line(Vector2(cx, y0), Vector2(cx + 3.0, y0 + 5.0 * k), 1.5, Color(RIPPLE, 0.7))
		if fmod(ftime() * 4.0 + seed, 1.0) < 0.2:
			glow.draw_rect(Rect2(at + Vector2(0, 0), Vector2(TILE, 1.5)), Color(1, 1, 1, 0.5 * k))
	# Vigil candles: a flame when lit; unlit, a cold rim so they read in the dark.
	for c in candles_list:
		var p: Vector2 = c["pos"]
		if not v.has_point(p):
			continue
		if c["lit"]:
			glow.flame(p + Vector2(0, -27), 12.0 if c["crown"] else 9.0, p.x * 0.07)
		else:
			var br := 0.45 + 0.25 * sin(ftime() * 2.2 + p.x * 0.03)
			_tb.circle(p + Vector2(0, -28), 2.0, Color(PALE, br))
			glow.draw_rect(Rect2(p + Vector2(-5, -24), Vector2(10, 1.5)), Color(SILVER, 0.45))
			glow.draw_rect(Rect2(p + Vector2(-5, -24), Vector2(1.5, 20)), Color(SILVER, 0.3))
			glow.draw_rect(Rect2(p + Vector2(3.5, -24), Vector2(1.5, 20)), Color(SILVER, 0.3))
		if c["crown"] and not c["lit"]:
			# A crown's pips in an arc over it, one per candle of its ring:
			# warm when that candle is lit, a cold ring while it isn't.
			var n: int = (c["ring"] as Array).size()
			for k in n:
				var ang := PI * (1.15 + 0.7 * (k / maxf(n - 1.0, 1.0)))
				var at := p + Vector2(0, -34) + Vector2(cos(ang), sin(ang)) * 20.0
				if candles_list[int(c["ring"][k])]["lit"]:
					_tb.circle(at, 3.0, Color("f7b64a"))
					_tb.circle(at, 1.4, Color(1.0, 0.95, 0.8))
				else:
					_tb.ring(at, 3.0, 1.2, Color(PALE, 0.55))
	_draw_tide(glow)
	_tb.flush(glow)


func _hands(glow: Node2D, x: float, y: float, k: float) -> void:
	## The Hush's hands out of the water: black, a silver rim, pale fingertips.
	var h := GRASP_H * k
	if h < 2.0:
		return
	var tex: Texture2D = _tex.get("grasp_hand")
	var r := Rect2(x - GRASP_W * 0.5, y - h, GRASP_W, h)
	if tex != null:
		# A2's two hands (32 x 80 px, the wrist on the line): rising out of
		# the lake, only what's over the line shows (a region of the frame).
		var sz := tex.get_size() * 0.25
		var shown := minf(h, sz.y)
		var top_left := Vector2(x, y) - HAND_FOOT * 0.5 + Vector2(0, sz.y - shown)
		glow.draw_texture_rect_region(tex, Rect2(top_left, Vector2(sz.x, shown)), Rect2(Vector2.ZERO, Vector2(tex.get_size().x, shown * 4.0)))
		return
	# Two gaunt arms out of one swirl of water, splaying apart as they rise,
	# the hands hooked in toward each other at the top: a grasp (never a
	# slab). Each arm narrows to the wrist, the palm widens, four long
	# fingers fan up and curl in, a thumb reaches across; a silver rim on
	# the outer edges, pale fingertips with a faint glow.
	var t := ftime()
	for side in [-1, 1]:
		var s := float(side)
		var ah := h * (1.0 if side < 0 else 0.92)
		var sway := sin(t * 3.0 + s) * 1.5 * k
		var base := Vector2(x + s * 4.0, y)
		var wrist := Vector2(x + s * 10.5 + sway, y - ah * 0.64)
		var palm := Vector2(x + s * 9.0 + sway * 1.3, y - ah * 0.76)
		_tb.convex(PackedVector2Array([base + Vector2(-3.0, 0), wrist + Vector2(-2.0, 0), wrist + Vector2(2.0, 0), base + Vector2(3.0, 0)]),
				Color(INK, 0.94))
		_tb.convex(PackedVector2Array([wrist + Vector2(-2.2, 0), palm + Vector2(-5.5, -1.0), palm + Vector2(5.5, -1.0), wrist + Vector2(2.2, 0)]),
				Color(INK, 0.94))
		var fl := ah * 0.26
		for f in 4:
			var root := palm + Vector2(-4.2 + f * 2.8, -1.0)
			var len_k := 1.0 if f == 1 or f == 2 else 0.8
			var mid := root + Vector2(s * (f - 1.5) * 1.2, -fl * 0.62 * len_k)
			var tip := mid + Vector2(-s * (2.5 + 0.5 * f) * k, -fl * 0.38 * len_k)
			_tb.polyline(PackedVector2Array([root, mid, tip]), 2.2, Color(INK, 0.94))
			_tb.circle(tip, 3.2, Color(PALE, 0.18 * k))
			_tb.circle(tip, 1.4, Color(PALE, 0.95))
		var th0 := palm + Vector2(-s * 5.0, 2.0)
		var th1 := th0 + Vector2(-s * 4.5, -ah * 0.11)
		_tb.line(th0, th1, 2.2, Color(INK, 0.94))
		_tb.circle(th1, 1.2, Color(PALE, 0.85))
		# The rim: up the arm's outer edge and round the palm; a fainter
		# inner one.
		_tb.polyline(PackedVector2Array([base + Vector2(s * 3.0, -2.0), wrist + Vector2(s * 2.0, 0), palm + Vector2(s * 5.5, -1.0)]),
				1.4, Color(SILVER, 0.9))
		_tb.line(base + Vector2(-s * 3.0, -2.0), wrist + Vector2(-s * 2.0, 0), 1.0, Color(SILVER, 0.3))
	# Where they break the water: a pale churn.
	_tb.ellipse(Vector2(x, y - 1.0), 13.0, 2.6, Color(RIPPLE, 0.4 * k))


func _ring(c: Vector2, rx: float, ry: float, w: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	_tb.polyline(pts, w, col)


func _draw_tide(glow: Node2D) -> void:
	var tx := tide_x()
	var fade := 1.0
	if tx == -INF:
		# A tide just ended sinks away over a second.
		for ch in chases:
			if ch["state"] == "done" and ftime() - float(ch["t"]) < 1.2 and float(ch["x"]) > -INF:
				tx = float(ch["x"])
				fade = 1.0 - (ftime() - float(ch["t"])) / 1.2
		if tx == -INF:
			return
	var v := view()
	var t := ftime()
	if tx > v.position.x:
		# The wall: black, a feathered front, a wavering silver rim, eyes.
		var left := v.position.x - 8.0
		var body := tx - 36.0
		if body > left:
			glow.draw_rect(Rect2(left, v.position.y - 8.0, body - left, v.size.y + 16.0), Color(INK, 0.94 * fade))
		for i in 6:
			var x0 := tx - 36.0 + i * 6.0
			glow.draw_rect(Rect2(x0, v.position.y - 8.0, 6.0, v.size.y + 16.0), Color(INK, (0.85 - i * 0.12) * fade))
		var y := v.position.y
		while y < v.end.y:
			var wob := sin(t * 3.1 + y * 0.045) * 4.0 + sin(t * 5.3 + y * 0.11) * 2.0
			# A cold mist on the front, the rim, and a fainter rim behind it.
			glow.draw_rect(Rect2(tx + wob - 16.0, y, 14.0, 12.0), Color(PALE, 0.10 * fade))
			glow.draw_rect(Rect2(tx + wob - 1.5, y, 3.0, 12.0), Color(RIPPLE, 0.7 * fade))
			glow.draw_rect(Rect2(tx + wob * 0.6 - 12.0, y, 1.5, 12.0), Color(SILVER, 0.3 * fade))
			y += 12.0
		# Tendrils reaching on along the floor he runs on.
		var pl := player()
		if pl != null:
			var fy: float = pl.position.y
			for i in 3:
				var reach := 18.0 + 14.0 * (0.5 + 0.5 * sin(t * 2.3 + i * 2.1))
				var ty := fy - 6.0 - i * 13.0
				var pts := PackedVector2Array()
				for j in 5:
					pts.append(Vector2(tx + reach * j / 4.0, ty + sin(t * 4.0 + j + i) * 3.0))
				_tb.polyline(pts, 3.0 - i * 0.6, Color(INK, 0.85 * fade))
				_tb.circle(pts[4], 1.8, Color(PALE, 0.5 * fade))
		_eyes(tx, v, t, fade)
	else:
		# Off the left edge: a vignette that widens as it closes.
		var behind := (v.position.x - tx) / TILE
		var k := clampf(1.0 - behind / TIDE_SEE, 0.0, 1.0)
		var w := lerpf(10.0, 72.0, k)
		var x0 := v.position.x
		for i in 6:
			var a := (0.8 - i * 0.13) * (0.45 + 0.55 * k) * fade
			glow.draw_rect(Rect2(x0 + w * i / 6.0, v.position.y, w / 6.0 + 1.0, v.size.y), Color(INK, a))
		var y := v.position.y
		while y < v.end.y:
			var wob := sin(t * 3.1 + y * 0.045) * 2.0
			glow.draw_rect(Rect2(x0 + w * 0.45 + wob, y, 2.0, 12.0), Color(RIPPLE, (0.25 + 0.4 * k) * fade))
			y += 12.0
		glow.draw_rect(Rect2(x0 + w - 2.0, v.position.y, 2.0, v.size.y), Color(PALE, (0.12 + 0.2 * k) * fade))
		var ey := v.get_center().y + sin(t * 0.7) * 40.0
		var blink := 0.2 if fmod(t, 2.7) < 0.12 else 1.0
		var ea := (0.35 + 0.55 * k) * blink * fade
		_tb.circle(Vector2(x0 + maxf(w * 0.3, 5.0), ey), 2.6, Color(PALE, ea))
		_tb.circle(Vector2(x0 + maxf(w * 0.3, 5.0) + 9.0, ey), 2.6, Color(PALE, ea))


func _eyes(tx: float, v: Rect2, t: float, fade: float) -> void:
	## Faint pairs of eyes just behind the front, blinking out of step.
	for i in 7:
		var s := float(i) * 1.618
		var ex := tx - 18.0 - fmod(s * 37.0, 90.0)
		if ex < v.position.x:
			continue
		var ey := v.position.y + 30.0 + fmod(s * 131.0, maxf(v.size.y - 60.0, 1.0))
		ey += sin(t * 0.9 + s) * 6.0
		var open := fmod(t * 0.8 + s * 0.37, 3.0)
		var a := 0.75 if open > 0.15 else 0.1
		var r := 2.4 + fmod(s, 1.0)
		_tb.circle(Vector2(ex, ey), r, Color(PALE, a * fade))
		_tb.circle(Vector2(ex + r * 3.4, ey), r, Color(PALE, a * fade))
