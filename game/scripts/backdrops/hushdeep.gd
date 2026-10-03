extends RefCounted
## World 6's backdrop style (A2): the Hushdeep, sparse by design (and so the
## cheapest). A lake the colour of nothing; every bell that fell silent sank
## here. Three layers, by the theme's "variant":
##   far   near-black, the lake's far line, rings of ripples spreading
##         slowly across it; shore and bell: drowned spires hanging upside
##         down from the dark (the reflection of a town that isn't there);
##         bell: bell-frame silhouettes on the far line; quiet: the rings
##         only; eye: a vast iris of rings round the arena at the level's end
##   mid   shore: sunken bell frames jutting from the lake line and drowned
##         lantern posts leaning (dark: no light in them); bell: broken bells
##         half sunk; quiet, eye: nothing
##   near  shore, bell: snuffed-wick reeds, each with a dim smoke tip; eye:
##         reeds only by the arena's edges; quiet: nothing
## windows(): none. W6 has no decorative lights: every light means something.
##   static func draw(slice, tb, layer_index, colors, span, x0, x1)
##   static func windows(layer_index, colors, span) -> Array
## (a gilt theme's "near_density" thins the reeds.)
## No draw_circle / draw_colored_polygon / draw_polyline (test_render.gd).

const RING_EVERY := 1200.0
const SPIRE_EVERY := 260.0
const FRAME_EVERY := 700.0
const POST_EVERY := 530.0
const REED_EVERY := 46.0
const VIEW_W := 844.0
const RING := Color("1a1830")


static func _h(i: int, salt: int = 0) -> float:
	var h := (i * 2654435761 + salt * 40503) & 0x7fffffff
	return float(h % 10000) / 10000.0


static func _each(every: float, x0: float, x1: float, phase := 0.0) -> Array[int]:
	var out: Array[int] = []
	var i := ceili((x0 - phase) / every)
	while i * every + phase < x1:
		out.append(i)
		i += 1
	return out


static func _variant(colors: Dictionary) -> String:
	return str(colors.get("variant", "shore"))


static func lake_line(span: Vector2, layer_index: int) -> float:
	## Where the lake's surface sits in a layer (it lies near the level's
	## bottom rows: lower on the nearer layers).
	return span.y * [0.66, 0.74, 0.82][clampi(layer_index, 0, 2)]


static func _arena_x(span: Vector2) -> float:
	return maxf(span.x - VIEW_W * 0.5, VIEW_W * 0.5)


static func _oval(tb, c: Vector2, rx: float, ry: float, w: float, col: Color, seg := 40) -> void:
	## A ring seen flat on the water (an ellipse band).
	var pts := PackedVector2Array()
	for k in seg:
		var a := TAU * k / seg
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	tb.polyline(pts, w, col, true)


static func draw(slice: Node2D, tb, layer_index: int, colors: Dictionary, span: Vector2, x0: float, x1: float) -> void:
	var v := _variant(colors)
	match layer_index:
		0:
			_far(slice, tb, colors, span, x0, x1, v)
		1:
			_mid(slice, tb, colors, span, x0, x1, v)
		2:
			_near(slice, tb, colors, span, x0, x1, v)


static func _far(slice: Node2D, tb, colors: Dictionary, span: Vector2, x0: float, x1: float, v: String) -> void:
	var sky: Color = colors.get("sky", Color("040406"))
	var far: Color = colors.get("far", Color("09090e"))
	var bottom := span.y + 400.0
	var ll := lake_line(span, 0)
	slice.draw_rect(Rect2(x0, -200.0, x1 - x0, bottom + 200.0), sky)
	# The lake: a shade apart from the dark above it, its far line faint.
	slice.draw_rect(Rect2(x0, ll, x1 - x0, bottom - ll), far.darkened(0.2))
	slice.draw_rect(Rect2(x0, ll - 0.5, x1 - x0, 1.0), RING.lightened(0.05))
	# Rings spreading across it.
	for i in _each(RING_EVERY, x0, x1, 300.0):
		var c := Vector2(i * RING_EVERY + 300.0 + _h(i, 1) * 400.0, ll + 26.0 + _h(i, 2) * 30.0)
		for k in 5:
			var r := 30.0 + k * 34.0 + _h(i, 3 + k) * 8.0
			_oval(tb, c, r, r * 0.16, 1.4, Color(RING, 0.9 - k * 0.14))
	if v == "shore" or v == "bell":
		# Drowned spires hanging from the top, upside down.
		for i in _each(SPIRE_EVERY, x0, x1, 80.0):
			if _h(i, 11) < 0.25:
				continue
			var x := i * SPIRE_EVERY + 80.0 + _h(i, 12) * 90.0
			var w := 18.0 + 22.0 * _h(i, 13)
			var l := span.y * (0.18 + 0.2 * _h(i, 14))
			slice.draw_rect(Rect2(x - w * 0.5, -40.0, w, 40.0 + l * 0.55), far)
			tb.tri(Vector2(x - w * 0.5, l * 0.55), Vector2(x + w * 0.5, l * 0.55), Vector2(x, l), far)
			# One dark window in it, no light.
			slice.draw_rect(Rect2(x - 2.0, l * 0.3, 4.0, 8.0), sky)
			if _h(i, 15) > 0.5:
				tb.tri(Vector2(x + w * 0.5, l * 0.2), Vector2(x + w * 0.5 + 10.0, l * 0.2), Vector2(x + w * 0.5 + 5.0, l * 0.42), far)
	if v == "bell":
		for i in _each(FRAME_EVERY, x0, x1, 250.0):
			var x := i * FRAME_EVERY + 250.0 + _h(i, 21) * 200.0
			_bell_frame(slice, tb, Vector2(x, ll), 0.7, far.lightened(0.02))
	if v == "eye":
		var c := Vector2(_arena_x(span), span.y * 0.42)
		if c.x >= x0 and c.x < x1:
			for k in 9:
				var r := 60.0 + k * 34.0
				_oval(tb, c, r, r * 0.62, 2.0 - k * 0.12, Color(Color("2a2448"), 0.85 - k * 0.07), 48)
			_oval(tb, c, 40.0, 26.0, 3.0, Color("3a3060"), 36)


static func _bell_frame(slice: Node2D, tb, foot: Vector2, s: float, col: Color) -> void:
	## A bell frame's top jutting out of the lake: two leaning posts, a beam,
	## a bell hanging half under.
	var w := 90.0 * s
	var hgt := 70.0 * s
	tb.quad(foot + Vector2(-w * 0.5, 4), foot + Vector2(-w * 0.5 + 7 * s, 4), foot + Vector2(-w * 0.3 + 7 * s, -hgt), foot + Vector2(-w * 0.3, -hgt), col)
	tb.quad(foot + Vector2(w * 0.5, 4), foot + Vector2(w * 0.5 - 7 * s, 4), foot + Vector2(w * 0.3 - 7 * s, -hgt), foot + Vector2(w * 0.3, -hgt), col)
	slice.draw_rect(Rect2(foot.x - w * 0.42, foot.y - hgt - 8.0 * s, w * 0.84, 8.0 * s), col)
	var bt := foot.y - hgt + 6.0 * s
	tb.convex(PackedVector2Array([Vector2(foot.x - 8 * s, bt), Vector2(foot.x + 8 * s, bt), Vector2(foot.x + 14 * s, foot.y), Vector2(foot.x - 14 * s, foot.y)]), col)


static func _mid(slice: Node2D, tb, colors: Dictionary, span: Vector2, x0: float, x1: float, v: String) -> void:
	var mid: Color = colors.get("mid", Color("0e0e14"))
	var ll := lake_line(span, 1)
	if v == "quiet" or v == "eye":
		return
	# The nearer lake line (faint), so the layers stack like distance.
	slice.draw_rect(Rect2(x0, ll, x1 - x0, 1.0), Color(RING, 0.8))
	if v == "shore":
		for i in _each(FRAME_EVERY, x0, x1, 120.0):
			var x := i * FRAME_EVERY + 120.0 + _h(i, 31) * 240.0
			_bell_frame(slice, tb, Vector2(x, ll), 1.0, mid)
		for i in _each(POST_EVERY, x0, x1, 380.0):
			var x := i * POST_EVERY + 380.0 + _h(i, 32) * 120.0
			_post(slice, tb, Vector2(x, ll), mid, (_h(i, 33) - 0.5) * 0.5)
	else:
		for i in _each(FRAME_EVERY * 0.8, x0, x1, 200.0):
			var x := i * FRAME_EVERY * 0.8 + 200.0 + _h(i, 34) * 220.0
			_sunk_bell(tb, Vector2(x, ll), 34.0 + 22.0 * _h(i, 35), mid, _h(i, 36) - 0.5)


static func _post(slice: Node2D, tb, foot: Vector2, col: Color, lean: float) -> void:
	## A drowned lantern post, leaning, its lantern dark.
	var top := foot + Vector2(sin(lean) * 90.0, -cos(lean) * 90.0)
	tb.line(foot + Vector2(0, 6), top, 5.0, col)
	var lp := top + Vector2(0, 4)
	tb.quad(lp + Vector2(-8, 0), lp + Vector2(8, 0), lp + Vector2(6, 16), lp + Vector2(-6, 16), col)
	tb.tri(lp + Vector2(-10, 0), lp + Vector2(10, 0), lp + Vector2(0, -9), col)
	tb.rect(Rect2(lp + Vector2(-3, 4), Vector2(6, 8)), col.darkened(0.5))


static func _sunk_bell(tb, foot: Vector2, r: float, col: Color, tilt: float) -> void:
	## A broken bell half under the lake: its shoulder and a crack.
	var pts := PackedVector2Array()
	for k in 9:
		var a := PI + PI * k / 8.0
		var rr := r * (1.0 if k != 5 else 0.82)
		pts.append(foot + Vector2(cos(a) * rr * 1.1, sin(a) * rr * 1.3).rotated(tilt * 0.4))
	tb.fan(foot, pts, col, false)
	var cr := foot + Vector2(r * 0.2, -r * 1.1).rotated(tilt * 0.4)
	tb.line(cr, cr + Vector2(-4, 12), 2.0, col.darkened(0.5))
	tb.ring(foot + Vector2(0, -r * 1.25).rotated(tilt * 0.4), 5.0, 3.0, col, 10)


static func _near(slice: Node2D, tb, colors: Dictionary, span: Vector2, x0: float, x1: float, v: String) -> void:
	if v == "quiet":
		return
	var near: Color = colors.get("near", Color("050507"))
	var density: float = float(colors.get("near_density", 1.0))
	var every := REED_EVERY / maxf(density, 0.1)
	var ll := lake_line(span, 2)
	var ax := _arena_x(span)
	for i in _each(every, x0, x1):
		var x := i * every + _h(i, 41) * every * 0.8
		if v == "eye" and absf(x - ax) < VIEW_W * 0.32:
			continue
		if v == "eye" and absf(x - ax) > VIEW_W * 0.62:
			continue
		if _h(i, 42) < 0.3:
			continue
		var hgt := 40.0 + 90.0 * _h(i, 43)
		var w := 2.0 + 1.5 * _h(i, 44)
		var lean := (_h(i, 45) - 0.5) * 10.0
		var base := Vector2(x, ll + 40.0 + _h(i, 46) * 30.0)
		var tip := base + Vector2(lean, -hgt)
		tb.quad(base + Vector2(-w, 0), base + Vector2(w, 0), tip + Vector2(w * 0.6, 0), tip + Vector2(-w * 0.6, 0), near)
		# The snuffed wick at its tip: a dim grey curl of old smoke.
		tb.rect(Rect2(tip + Vector2(-1.2, -4.0), Vector2(2.4, 4.0)), Color("1c1a22"))
		tb.circle(tip + Vector2(1.0, -6.0), 1.6, Color(0.36, 0.34, 0.42, 0.35), 6)
	slice.draw_rect(Rect2(x0, span.y + 60.0, x1 - x0, 400.0), near)


static func windows(layer_index: int, colors: Dictionary, span: Vector2) -> Array:
	## None: the Hushdeep has no decorative lights (spec §4.4's rule 3).
	return []
