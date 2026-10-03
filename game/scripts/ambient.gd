extends Node2D
## A level's atmosphere in one draw call: theme motes, wind streaks, caustic
## floor pools, ripple rings, the frost breath, and one-off bursts, all in a
## single TriBatch on the glow layer (above the dark), redrawn every frame.
## The World makes one (world.ambient) under glow and calls set_theme(level.theme);
## a theme with no AMBIENT table (every v2 theme) draws nothing and costs no
## draw call.
##   set_theme(id)          reads AMBIENT[id] from the theme files (themes/loader.gd)
##   burst(kind, p, n, col) a puff of n particles of a kind at p (spores, frost, shards)
##   set_wind(dir, k)       W5's gusts: dir -1/1, k 0..1 (streaks and drift lean with it)
##   mote_count()           what was drawn last frame (the perf line's "motes")
## A table entry: {kind, count, size, color, alpha, drift: Vector2 (px/s),
## sway (px), parallax (0 = stuck to the glass, 1 = in the world), near_light
## (alpha full inside 1.2x the hero's light, else 0.15), floor (a minimum
## alpha: fairness motes like spores keep 0.35)}. Kinds: mote (a diamond),
## star (four points), spore, flake, ember (small discs), petal (an oval),
## streak (a wind line), pool (a caustic floor pool), ripple (a ring on water),
## breath (the hero's frost breath, W4). With the shake setting at 0 the mote
## counts halve and the streaks stop jittering.
## No draw_circle / draw_colored_polygon / draw_polyline (test_render.gd).

const Themes := preload("res://scripts/themes/loader.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const LevelData := preload("res://scripts/level_data.gd")
const TILE := 32
const CAPS := {"mote": 64, "streak": 24, "pool": 8, "ripple": 4, "breath": 1}
const BURST_MAX := 96
const MARGIN := 40.0
const BREATH_EVERY := 2.4

var world: Node
var theme := ""
var table: Array = []
var wind_dir := 1.0
var wind_k := 0.0
var bursts: Array = []           # {kind, p, v, life, max, col, size}
var reduced := false             # the shake setting at 0
var _tb := TriBatch.new()
var _t := 0.0
var _wind_off := 0.0             # the wind's drift so far, integrated (a change in k never jumps the motes)
var _drawn := 0
var _was_empty := true
var _rng := RandomNumberGenerator.new()
var _surf := {}                  # column -> floor / water surface y (px), or -1


func _ready() -> void:
	_rng.seed = 7349
	var g = get_node_or_null("/root/Game")
	if g != null and g.has_method("setting"):
		reduced = float(g.setting("shake")) <= 0.0


func set_theme(id: String) -> void:
	theme = id
	table = Themes.ambient(id)
	# A gilt secret level's motes at half (A2: gilt() sets mote_scale 0.5).
	var ms := float(Themes.theme(id).get("mote_scale", 1.0))
	if ms != 1.0:
		var scaled: Array = []
		for e in table:
			var d: Dictionary = (e as Dictionary).duplicate()
			if d.has("count"):
				d["count"] = maxi(int(round(float(d["count"]) * ms)), 1)
			scaled.append(d)
		table = scaled
	_surf.clear()
	queue_redraw()


func set_wind(dir: float, k: float) -> void:
	wind_dir = signf(dir) if dir != 0.0 else 1.0
	wind_k = clampf(k, 0.0, 1.0)


func burst(kind: String, p: Vector2, n: int, col := Color(1, 1, 1, 0.85), speed := 90.0, life := 0.8) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		var v := Vector2(cos(a), sin(a)) * _rng.randf_range(0.3, 1.0) * speed
		bursts.append({"kind": kind, "p": p, "v": v, "life": life * _rng.randf_range(0.6, 1.0), "max": life,
				"col": col, "size": _rng.randf_range(1.5, 3.0)})
	if bursts.size() > BURST_MAX:
		bursts = bursts.slice(bursts.size() - BURST_MAX)


func mote_count() -> int:
	return _drawn


func _process(dt: float) -> void:
	_t += dt
	_wind_off += wind_dir * wind_k * 60.0 * dt
	for b in bursts:
		b["life"] = float(b["life"]) - dt
		b["v"] = (b["v"] as Vector2) * (1.0 - 1.8 * dt)
		b["p"] = (b["p"] as Vector2) + (b["v"] as Vector2) * dt
	if not bursts.is_empty():
		bursts = bursts.filter(func(b): return float(b["life"]) > 0.0)
	var empty := table.is_empty() and bursts.is_empty()
	if not empty or not _was_empty:
		queue_redraw()
	_was_empty = empty


func _h(i: int, salt: int) -> float:
	var h := (i * 2654435761 + salt * 40503 + 977) & 0x7fffffff
	return float(h % 10000) / 10000.0


func _view() -> Rect2:
	if world != null and world.has_method("view_rect"):
		return world.view_rect()
	return get_viewport_rect()


func _hero() -> Array:
	## [centre, light radius] or [] with no living hero.
	if world == null or world.get("player") == null or not world.player.alive:
		return []
	return [world.player.center(), float(world.hero_light_radius())]


func _draw() -> void:
	_drawn = 0
	if table.is_empty() and bursts.is_empty():
		return
	var view := _view()
	var hero := _hero()
	_tb.origin = view.position
	for e in table:
		var kind := str(e.get("kind", "mote"))
		match kind:
			"streak":
				_streaks(e, view)
			"pool":
				_pools(e, view)
			"ripple":
				_ripples(e, view)
			"breath":
				_breath(e)
			_:
				_motes(e, kind, view, hero)
	for b in bursts:
		var k := clampf(float(b["life"]) / maxf(float(b["max"]), 0.01), 0.0, 1.0)
		var c: Color = b["col"]
		c.a *= k
		_shape(str(b["kind"]), b["p"], float(b["size"]) * (0.6 + 0.4 * k), c, int(b["p"].x))
		_drawn += 1
	_tb.flush(self)


func _alpha(e: Dictionary, p: Vector2, hero: Array) -> float:
	var a: float = float(e.get("alpha", 0.6))
	if bool(e.get("near_light", false)):
		var near := 0.15
		if not hero.is_empty() and p.distance_to(hero[0]) <= float(hero[1]) * 1.2:
			near = 1.0
		a *= maxf(near, float(e.get("floor", 0.0)))
	return a


func _motes(e: Dictionary, kind: String, view: Rect2, hero: Array) -> void:
	var n := mini(int(e.get("count", 24)), int(CAPS["mote"]) - _drawn)
	if reduced:
		n >>= 1
	if n <= 0:
		return
	var size: float = float(e.get("size", 2.0))
	var col: Color = e.get("color", Color(1, 1, 1))
	var drift: Vector2 = e.get("drift", Vector2(0, -6))
	var sway: float = float(e.get("sway", 6.0))
	var par: float = float(e.get("parallax", 1.0))
	var field := view.size + Vector2(MARGIN, MARGIN) * 2.0
	var cam := view.position
	var salt := hash(kind) & 0xffff
	for i in n:
		var base := Vector2(_h(i, salt + 1) * field.x, _h(i, salt + 2) * field.y)
		var ph := _h(i, salt + 3) * TAU
		var m := 0.6 + 0.8 * _h(i, salt + 4)
		var sp := base + drift * _t * m + Vector2(_wind_off * m, 0.0) - cam * par
		sp.x += sin(_t * 0.9 + ph) * sway
		var s := Vector2(fposmod(sp.x, field.x), fposmod(sp.y, field.y)) - Vector2(MARGIN, MARGIN)
		var p := cam + s
		var c := col
		c.a = _alpha(e, p, hero) * (0.75 + 0.25 * sin(_t * 2.0 + ph))
		if c.a <= 0.01:
			continue
		_shape(kind, p, size * (0.8 + 0.4 * _h(i, salt + 5)), c, i)
		_drawn += 1


func _shape(kind: String, p: Vector2, s: float, c: Color, i: int) -> void:
	match kind:
		"star":
			_tb.quad(p + Vector2(0, -s * 2.2), p + Vector2(s * 0.45, 0), p + Vector2(0, s * 2.2), p + Vector2(-s * 0.45, 0), c)
			_tb.quad(p + Vector2(-s * 2.2, 0), p + Vector2(0, s * 0.45), p + Vector2(s * 2.2, 0), p + Vector2(0, -s * 0.45), c)
		"spore", "flake", "ember":
			_tb.circle(p, s, c, 6)
		"petal":
			var a := _t * 1.3 + i
			var d := Vector2(cos(a), sin(a)) * s * 1.4
			var o := d.orthogonal() * 0.45
			_tb.quad(p - d, p + o, p + d, p - o, c)
		_:
			_tb.quad(p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0), c)


func _streaks(e: Dictionary, view: Rect2) -> void:
	if wind_k <= 0.0:
		return
	var n := mini(int(float(e.get("count", 16)) * wind_k), int(CAPS["streak"]))
	if reduced:
		n >>= 1
	var col: Color = e.get("color", Color(0.95, 0.95, 1.0))
	var a: float = float(e.get("alpha", 0.35)) * wind_k
	var len: float = float(e.get("size", 3.0)) * 12.0
	var speed := 520.0 * wind_dir
	for i in n:
		var y := view.position.y + _h(i, 71) * view.size.y
		var x := view.position.x + fposmod(_h(i, 72) * view.size.x + _t * speed * (0.7 + 0.6 * _h(i, 73)), view.size.x + len * 2.0) - len
		var jit := 0.0 if reduced else sin(_t * 9.0 + i) * 1.5
		_tb.line(Vector2(x, y + jit), Vector2(x + len * wind_dir, y + jit), 1.2, Color(col, a))
		_drawn += 1


func _surface(x: int, water: bool) -> float:
	## The first floor (or water) surface in column x, from the top.
	var key := x * 2 + (1 if water else 0)
	if _surf.has(key):
		return _surf[key]
	var y := -1.0
	if world != null and world.get("level") != null:
		var lv: RefCounted = world.level
		for ty in range(1, lv.height):
			var t: int = lv.tile(x, ty)
			var above: int = lv.tile(x, ty - 1)
			if water:
				if t == LevelData.WATER and above != LevelData.WATER:
					y = ty * TILE + 6.0
					break
			elif LevelData.is_solid(t) and not LevelData.is_solid(above) and above != LevelData.WATER:
				y = ty * TILE
				break
	_surf[key] = y
	return y


func _pools(e: Dictionary, view: Rect2) -> void:
	var n := mini(int(e.get("count", 6)), int(CAPS["pool"]))
	var col: Color = e.get("color", Color(0.9, 0.9, 1.0))
	var a: float = float(e.get("alpha", 0.25))
	var c0 := floori(view.position.x / TILE)
	var cols := ceili(view.size.x / TILE)
	for i in n:
		var cx := c0 + int(_h(i + (c0 >> 4) * 13, 81) * cols)
		var y := _surface(cx, false)
		if y < 0.0:
			continue
		var w := 18.0 + 14.0 * sin(_t * 1.7 + i * 2.1)
		_tb.ellipse(Vector2(cx * TILE + 16, y + 1.5), w, 3.0, Color(col, a * (0.6 + 0.4 * sin(_t * 2.3 + i))), 10)
		_drawn += 1


func _ripples(e: Dictionary, view: Rect2) -> void:
	var n := mini(int(e.get("count", 3)), int(CAPS["ripple"]))
	var col: Color = e.get("color", Color("e0e0ff"))
	var a: float = float(e.get("alpha", 0.3))
	var c0 := floori(view.position.x / TILE)
	var cols := ceili(view.size.x / TILE)
	for i in n:
		var period := 2.6 + _h(i, 91)
		var k := fposmod(_t / period + _h(i, 92), 1.0)
		var cycle := floori(_t / period + _h(i, 92))
		var cx := c0 + int(_h(i + cycle * 7, 93) * cols)
		var y := _surface(cx, true)
		if y < 0.0:
			continue
		var r := 4.0 + 26.0 * k
		_tb.ring(Vector2(cx * TILE + 16, y), r, 1.4, Color(col, a * (1.0 - k)), 14)
		_drawn += 1


func _breath(e: Dictionary) -> void:
	if world == null or world.get("player") == null or not world.player.alive:
		return
	var k := fposmod(_t, BREATH_EVERY) / 0.9
	if k > 1.0:
		return
	var pl: Node2D = world.player
	var mouth: Vector2 = pl.center() + Vector2(float(pl.get("facing")) * 8.0, -10.0)
	var col: Color = e.get("color", Color("e8fcff"))
	var a: float = float(e.get("alpha", 0.35)) * (1.0 - k)
	for i in 3:
		var p := mouth + Vector2(float(pl.get("facing")) * (4.0 + 10.0 * k + i * 3.0), -2.0 * k - i)
		_tb.circle(p, 2.0 + 3.0 * k + i, Color(col, a * (1.0 - i * 0.25)), 8)
	_drawn += 1
