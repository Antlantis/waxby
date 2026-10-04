extends RefCounted
## World 5's backdrop style (A2): the Shattered Sanctum, glass hanging in
## pieces over a void with no bottom, still lit from inside. Three layers,
## by the theme's "variant":
##   far   the void: stars and a faint glow rising from below, far floating
##         cathedral chunks; choir: a broken rose window of floating shards
##         every ROSE_EVERY px; rose: the same rose, its shards streaming away
##         on the wind; void: almost empty, a far galaxy of shards; prism: the
##         Saint's empty window frame (a huge lancet of lead, a white window)
##         behind the arena at the level's end
##   mid   choir: floating choir stalls and broken arches with chains
##         dangling into the void; rose: ribbons of lead came streaming;
##         void: sparse fragments; prism: floating pews in a ring round the arena
##   near  choir: big dark foreground shards with a coloured edge; rose: torn
##         banners; void: a few shards; prism: pillars with gold capitals
## (a gilt theme's "near_density" 0.5 halves the near layer, spec §11.4).
## windows(): the rose windows (tinted by their glass) and a few lit shards
## on the mid layer, decorative tinted lights (s 0.45, tint = the pane at
## 0.8); the prism's white window.
##   static func draw(slice, tb, layer_index, colors, span, x0, x1, tall := 0.0)
##   static func windows(layer_index, colors, span, tall := 0.0) -> Array
## An element is drawn by the one slice its anchor falls in (backdrops/plain.gd).
## A level taller than 15 rows (tall > 0, backdrop.gd tall(); the shapes
## plan's E9): the strip's composition stays at the top, laid out on the
## strip's span (nothing spreads thinner or grows), the void's glow still
## rises from the level's bottom and the rising shards stand on it, and the
## void goes on down: more stars, and a storey at a time (STOREY) more of
## what floats in the variant's mid layer (stalls and broken arches, came
## ribbons, fragments) and loose shards drifting in the near layer, each
## storey salted by its index. The lights stay the strip's.
## No draw_circle / draw_colored_polygon / draw_polyline (test_render.gd).

const ROSE_EVERY := 1800.0
const CHUNK_EVERY := 640.0
const STAR_EVERY := 17.0
const STALL_EVERY := 460.0
const RIBBON_EVERY := 380.0
const FRAG_EVERY := 900.0
const NEAR_EVERY := 520.0
const SHARD_LIGHT_EVERY := 920.0
const FRAME_W := 250.0            # the Saint's empty window
const VIEW_W := 844.0
const STOREY := 180.0             # a tall level's storey down the mid layer
const NEAR_STOREY := 260.0        # and down the near layer


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


static func _glass(colors: Dictionary) -> Array:
	var g = colors.get("glass", [Color("c83a5a"), Color("3a6ac8")])
	return g if g is Array and not g.is_empty() else [Color("c83a5a")]


static func _variant(colors: Dictionary) -> String:
	return str(colors.get("variant", "choir"))


static func _arena_x(span: Vector2) -> float:
	## Where the level's last screen sits in a layer (the boss arena's middle).
	return maxf(span.x - VIEW_W * 0.5, VIEW_W * 0.5)


static func draw(slice, tb, layer_index: int, colors: Dictionary, span: Vector2, x0: float, x1: float, tall := 0.0) -> void:
	var v := _variant(colors)
	# The strip's span: what the composition is laid out on (tall: how much
	# deeper this level's layer goes).
	var base := Vector2(span.x, span.y - tall)
	match layer_index:
		0:
			_far(slice, tb, colors, base, x0, x1, v, tall)
		1:
			_mid(slice, tb, colors, base, x0, x1, v, tall)
		2:
			_near(slice, tb, colors, base, x0, x1, v, tall)


# ---------------------------------------------------------------- far

static func _far(slice, tb, colors: Dictionary, span: Vector2, x0: float, x1: float, v: String, tall := 0.0) -> void:
	var sky: Color = colors.get("sky", Color("08060e"))
	var far: Color = colors.get("far", Color("120e1e"))
	var glass := _glass(colors)
	var bottom := span.y + tall + 400.0
	slice.draw_rect(Rect2(x0, -200.0, x1 - x0, bottom + 200.0), sky)
	# The void glows faintly from below: the old light in the glass (from
	# the level's bottom, however deep).
	var glow_c: Color = sky.lerp((glass[0] as Color), 0.10)
	for b in 6:
		var f := float(b) / 6.0
		var y := span.y * (0.55 + 0.45 * f) + tall
		slice.draw_rect(Rect2(x0, y, x1 - x0, bottom - y), Color(glow_c, 0.18 + 0.1 * f))
	# Stars.
	for i in _each(STAR_EVERY, x0, x1):
		var sx := i * STAR_EVERY + _h(i, 1) * STAR_EVERY
		var sy := _h(i, 2) * span.y * 0.9
		var s := 1.0 if _h(i, 3) < 0.8 else 2.0
		var a := 0.25 + 0.55 * _h(i, 4)
		if v == "void" and _h(i, 6) < 0.35:
			continue
		slice.draw_rect(Rect2(sx, sy, s, s), Color(0.9, 0.88, 1.0, a))
		if tall > 0.0 and _h(i, 7) < tall / (span.y * 0.9):
			# as many again a pixel down in the deeper void
			slice.draw_rect(Rect2(sx + _h(i, 8) * STAR_EVERY, span.y * 0.9 + _h(i, 9) * tall, s, s), Color(0.9, 0.88, 1.0, a))
	# Far floating chunks of the old cathedral.
	for i in _each(CHUNK_EVERY, x0, x1, 150.0):
		if v == "void" and _h(i, 17) < 0.6:
			continue
		var cx := i * CHUNK_EVERY + 150.0 + _h(i, 11) * 200.0
		var cy := span.y * (0.28 + 0.34 * _h(i, 12))
		_chunk(tb, Vector2(cx, cy), 40.0 + 50.0 * _h(i, 13), far.lightened(0.03), i)
	match v:
		"choir", "rose":
			for i in _each(ROSE_EVERY, x0, x1, 520.0):
				var c := Vector2(i * ROSE_EVERY + 520.0 + _h(i, 21) * 160.0, span.y * 0.3 + _h(i, 22) * 30.0)
				_rose(slice, tb, c, 60.0, glass[absi(i) % glass.size()], far, v == "rose", i)
		"void":
			# A far galaxy of shards, a slow swirl of tiny coloured rects.
			for i in _each(ROSE_EVERY, x0, x1, 700.0):
				var c := Vector2(i * ROSE_EVERY + 700.0 + _h(i, 31) * 300.0, span.y * 0.35)
				for k in 70:
					var a := k * 0.37 + _h(i, 32) * TAU
					var r := 8.0 + k * 1.6
					var p := c + Vector2(cos(a) * r * 1.6, sin(a) * r * 0.55)
					var g: Color = glass[k % glass.size()]
					slice.draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(g, 0.35 + 0.3 * _h(k, 33)))
		"prism":
			var ax := _arena_x(span)
			if ax >= x0 and ax < x1:
				_lancet_frame(slice, tb, Vector2(ax, span.y * 0.02), FRAME_W, span.y * 0.62, colors)


static func _chunk(tb, c: Vector2, w: float, col: Color, i: int) -> void:
	## A far floating chunk of masonry: a broken block, sometimes a turret.
	var hgt := w * (0.45 + 0.3 * _h(i, 14))
	var pts := PackedVector2Array([c + Vector2(-w * 0.5, -hgt * 0.4), c + Vector2(w * 0.5, -hgt * 0.5), c + Vector2(w * 0.42, hgt * 0.2),
			c + Vector2(w * 0.1, hgt * 0.55), c + Vector2(-w * 0.2, hgt * 0.35), c + Vector2(-w * 0.46, hgt * 0.1)])
	tb.convex(pts, col)
	if _h(i, 15) > 0.45:
		var tx := c.x - w * 0.2 + _h(i, 16) * w * 0.3
		tb.rect(Rect2(tx - 6.0, c.y - hgt * 0.4 - 26.0, 12.0, 27.0), col)
		tb.tri(Vector2(tx - 8.0, c.y - hgt * 0.4 - 26.0), Vector2(tx + 8.0, c.y - hgt * 0.4 - 26.0), Vector2(tx, c.y - hgt * 0.4 - 46.0), col)


static func _petal(tb, c: Vector2, a: float, r0: float, r1: float, half_w: float, col: Color) -> void:
	## One almond-shaped petal of tracery pointing out from c.
	var d := Vector2(cos(a), sin(a))
	var o := d.orthogonal()
	var m := c + d * (r0 + r1) * 0.5
	tb.convex(PackedVector2Array([c + d * r0, m + o * half_w, c + d * r1, m - o * half_w]), col)


static func _rose(slice, tb, c: Vector2, r: float, g: Color, far: Color, streaming: bool, seed: int) -> void:
	## A broken rose window, far off: a lead ring round two rings of
	## almond petals of dim glass (six in, twelve out) and a hub, some petals
	## gone; in the wind (streaming) the lost ones trail away to the right as
	## shards. Dim and pointed, so it never reads as coins or embers.
	var lead := far.darkened(0.5)
	var glass := g.darkened(0.62)
	var pale := g.lerp(Color(0.95, 0.9, 1.0), 0.2).darkened(0.62)
	tb.circle(c, r * 1.0, lead, 32)
	tb.circle(c, r * 0.9, far.darkened(0.25), 32)
	for k in 12:
		var a := TAU * k / 12.0 + 0.13
		if _h(seed * 31 + k, 41) < 0.25:
			if streaming:
				var q := c + Vector2(cos(a), sin(a)) * r * 0.68
				for m in 3:
					var sp := q + Vector2(14.0 + m * 16.0 + 20.0 * _h(k * 3 + m, 43), (_h(k + m, 44) - 0.5) * 18.0)
					var sz := 3.0 + 3.0 * _h(k * 5 + m, 45)
					tb.convex(PackedVector2Array([sp + Vector2(-sz, 0), sp + Vector2(0, -sz * 0.6), sp + Vector2(sz * 1.6, 0), sp + Vector2(0, sz * 0.6)]), glass)
			continue
		_petal(tb, c, a, r * 0.44, r * 0.9, r * 0.14, lead)
		_petal(tb, c, a, r * 0.48, r * 0.85, r * 0.10, glass if k % 2 == 0 else pale)
	for k in 6:
		var a := TAU * k / 6.0
		if _h(seed * 17 + k, 46) < 0.18:
			continue
		_petal(tb, c, a, r * 0.14, r * 0.46, r * 0.13, lead)
		_petal(tb, c, a, r * 0.17, r * 0.42, r * 0.09, pale if k % 2 == 0 else glass)
	tb.circle(c, r * 0.13, lead, 12)
	tb.circle(c, r * 0.08, glass, 10)


static func _lancet_frame(slice, tb, top: Vector2, w: float, h: float, colors: Dictionary) -> void:
	## The Saint's empty window: a vast lancet of lead with no glass left,
	## white light standing in it.
	var lead := Color(colors.get("far", Color("16122a"))).darkened(0.45)
	# Pale lavender, faint: never the prism white of the Saint's beams (a
	# white line must read against it).
	var white := Color("c8c0e8")
	var x0 := top.x - w * 0.5
	var spring := top.y + w * 0.866
	# The light in the empty window (soft bands, brightest at its heart).
	for b in 5:
		var inset := b * 12.0
		var pts := _arch_pts(x0 + inset, x0 + w - inset, top.y + inset * 1.2, top.y + h, 10)
		tb.convex(pts, Color(white, 0.025 + 0.014 * b))
	# The lead: the arch's outline, mullions, a traceried eye.
	var outline := _arch_pts(x0, x0 + w, top.y, top.y + h, 14)
	tb.polyline(outline, 7.0, lead, true)
	for m in [0.34, 0.66]:
		var mx: float = x0 + w * m
		tb.line(Vector2(mx, spring - 10.0), Vector2(mx, top.y + h), 5.0, lead)
	for rrow in 4:
		var ry := spring + 30.0 + rrow * (h - (spring - top.y) - 40.0) / 4.0
		tb.line(Vector2(x0 + 6.0, ry), Vector2(x0 + w - 6.0, ry), 3.0, lead)
	tb.ring(Vector2(top.x, spring - 18.0), w * 0.2, 5.0, lead, 24)
	tb.ring(Vector2(top.x, spring - 18.0), w * 0.08, 3.0, lead, 16)


static func _arch_pts(x0: float, x1: float, top: float, bottom: float, seg: int) -> PackedVector2Array:
	## An equilateral pointed arch from top down to bottom (convex): two arcs
	## of radius w, each centred on the other side's springing point.
	var w := x1 - x0
	var spring := top + w * 0.866
	var pts := PackedVector2Array([Vector2(x0, bottom), Vector2(x0, spring)])
	for k in range(1, seg):
		var th := PI - (PI / 3.0) * k / seg
		pts.append(Vector2(x1 + w * cos(th), spring - w * sin(th)))
	pts.append(Vector2((x0 + x1) * 0.5, top))
	for k in range(1, seg):
		var th := (PI / 3.0) * (1.0 - float(k) / seg)
		pts.append(Vector2(x0 + w * cos(th), spring - w * sin(th)))
	pts.append(Vector2(x1, spring))
	pts.append(Vector2(x1, bottom))
	return pts


# ---------------------------------------------------------------- mid

static func _mid(slice, tb, colors: Dictionary, span: Vector2, x0: float, x1: float, v: String, tall := 0.0) -> void:
	var mid: Color = colors.get("mid", Color("1c1630"))
	var glass := _glass(colors)
	var lead := mid.darkened(0.55)
	if tall > 0.0 and v != "prism":
		_tall_mid(slice, tb, mid, lead, glass, span, x0, x1, v, tall)
	match v:
		"choir":
			for i in _each(STALL_EVERY, x0, x1, 120.0):
				var x := i * STALL_EVERY + 120.0 + _h(i, 51) * 120.0
				var y := span.y * (0.34 + 0.3 * _h(i, 52))
				if _h(i, 53) < 0.5:
					_stall(slice, tb, Vector2(x, y), mid, lead, glass[absi(i) % glass.size()], i)
				else:
					_broken_arch(slice, tb, Vector2(x, y), mid, lead, glass[absi(i + 1) % glass.size()], i)
		"rose":
			for i in _each(RIBBON_EVERY, x0, x1, 60.0):
				var x := i * RIBBON_EVERY + 60.0 + _h(i, 61) * 140.0
				var y := span.y * (0.2 + 0.5 * _h(i, 62))
				_came_ribbon(tb, Vector2(x, y), mid.lightened(0.05), lead, glass, i)
		"void":
			for i in _each(FRAG_EVERY, x0, x1, 300.0):
				var x := i * FRAG_EVERY + 300.0 + _h(i, 71) * 300.0
				var y := span.y * (0.3 + 0.35 * _h(i, 72))
				_chunk(tb, Vector2(x, y), 30.0 + 30.0 * _h(i, 73), mid, i + 900)
		"prism":
			var ax := _arena_x(span)
			for k in 10:
				var a := TAU * k / 10.0 + 0.3
				var p := Vector2(ax + cos(a) * 330.0, span.y * 0.5 + sin(a) * 90.0)
				if p.x >= x0 and p.x < x1:
					_pew(slice, tb, p, mid, lead, 0.7 + 0.3 * sin(a) * 0.5 + 0.3)
			for i in _each(STALL_EVERY * 1.5, x0, minf(x1, ax - 500.0), 200.0):
				var x := i * STALL_EVERY * 1.5 + 200.0 + _h(i, 81) * 200.0
				_pew(slice, tb, Vector2(x, span.y * (0.35 + 0.3 * _h(i, 82))), mid, lead, 0.8)


static func _stall(slice, tb, p: Vector2, mid: Color, lead: Color, g: Color, i: int) -> void:
	## A floating choir stall: a canopied bench on a broken block, a chain
	## hanging from it into the void, a sliver of lit glass in its canopy.
	var w := 90.0 + 40.0 * _h(i, 54)
	slice.draw_rect(Rect2(p.x - w * 0.5, p.y, w, 16.0), mid)
	slice.draw_rect(Rect2(p.x - w * 0.5, p.y - 30.0, 8.0, 30.0), mid)
	slice.draw_rect(Rect2(p.x + w * 0.5 - 8.0, p.y - 30.0, 8.0, 30.0), mid)
	slice.draw_rect(Rect2(p.x - w * 0.5 - 4.0, p.y - 36.0, w + 8.0, 7.0), mid)
	for k in 4:
		slice.draw_rect(Rect2(p.x - w * 0.5 + 12.0 + k * (w - 24.0) / 3.0, p.y - 20.0, 3.0, 20.0), mid.darkened(0.25))
	# The canopy: three round-headed arches, plain silhouettes (round, so
	# nothing reads as a spike; no bright insets, so nothing reads as an ember).
	for k in 3:
		var cx := p.x - w * 0.33 + k * w * 0.33
		tb.ellipse(Vector2(cx, p.y - 36.0), 13.0, 11.0, mid, 12)
		tb.rect(Rect2(cx - 1.0, p.y - 44.0, 2.0, 8.0), mid.darkened(0.35))
	# Its broken underside and a chain into the void.
	tb.convex(PackedVector2Array([Vector2(p.x - w * 0.5, p.y + 15.0), Vector2(p.x + w * 0.5, p.y + 15.0), Vector2(p.x + w * 0.2, p.y + 34.0), Vector2(p.x - w * 0.3, p.y + 28.0)]), mid)
	var chx := p.x + w * (0.1 + 0.3 * _h(i, 55))
	var len := 50.0 + 90.0 * _h(i, 56)
	var y := p.y + 26.0
	while y < p.y + 26.0 + len:
		tb.ring(Vector2(chx, y), 3.0, 1.4, mid.lightened(0.08), 8)
		y += 7.0


static func _broken_arch(slice, tb, p: Vector2, mid: Color, lead: Color, g: Color, i: int) -> void:
	## A broken arch floating: two piers, one half of a pointed arch, glass
	## fragments still in it with lead lines.
	var w := 70.0 + 30.0 * _h(i, 57)
	var hgt := 90.0 + 40.0 * _h(i, 58)
	slice.draw_rect(Rect2(p.x - w * 0.5 - 12.0, p.y - hgt * 0.5, 12.0, hgt), mid)
	slice.draw_rect(Rect2(p.x + w * 0.5, p.y - hgt * 0.2, 12.0, hgt * 0.7), mid)
	var top := p.y - hgt * 0.5 - w * 0.866
	var pts := _arch_pts(p.x - w * 0.5, p.x + w * 0.5, top, p.y - hgt * 0.5 + 6.0, 8)
	# Only its left half stands.
	var half := PackedVector2Array()
	for q in pts:
		if q.x <= p.x + 1.0:
			half.append(q)
	half.append(Vector2(p.x, p.y - hgt * 0.5 + 6.0))
	if half.size() >= 3:
		tb.polyline(half, 9.0, mid)
	# Glass bits in the opening.
	for k in 3:
		var gx := p.x - w * 0.35 + k * 14.0
		var gy := p.y - hgt * 0.35 + _h(i * 5 + k, 59) * 30.0
		tb.convex(PackedVector2Array([Vector2(gx, gy), Vector2(gx + 11.0, gy - 3.0), Vector2(gx + 9.0, gy + 12.0), Vector2(gx - 1.0, gy + 10.0)]), g.darkened(0.4))
		tb.line(Vector2(gx, gy), Vector2(gx + 9.0, gy + 12.0), 1.2, lead)
	# The broken end.
	tb.tri(Vector2(p.x - w * 0.5 - 12.0, p.y + hgt * 0.5), Vector2(p.x - w * 0.5, p.y + hgt * 0.5), Vector2(p.x - w * 0.5 - 6.0, p.y + hgt * 0.5 + 14.0), mid)


static func _came_ribbon(tb, p: Vector2, col: Color, lead: Color, glass: Array, i: int) -> void:
	## A ribbon of lead came torn from its window, streaming on the wind with
	## a few panes still caught in it.
	var pts := PackedVector2Array()
	var len := 160.0 + 120.0 * _h(i, 63)
	for k in 12:
		var f := k / 11.0
		pts.append(p + Vector2(f * len, sin(f * 5.0 + i) * 10.0 * (0.3 + f) - f * 12.0))
	tb.polyline(pts, 4.0, lead)
	tb.polyline(pts, 2.0, col.lightened(0.1))
	for k in 3:
		var q := pts[2 + k * 3]
		var g: Color = glass[(i + k) % glass.size()]
		tb.convex(PackedVector2Array([q + Vector2(-4, 1), q + Vector2(4, -2), q + Vector2(5, 7), q + Vector2(-3, 8)]), g.darkened(0.4))


static func _pew(slice, tb, p: Vector2, mid: Color, lead: Color, s: float) -> void:
	## A floating pew, tumbled (never level, so it never reads as a ledge),
	## darker than the stone by a long way.
	var c := mid.darkened(0.3)
	var ang := (fposmod(p.x * 0.013 + p.y * 0.007, 1.0) - 0.5) * 1.1
	var w := 70.0 * s
	var u := Vector2(cos(ang), sin(ang))
	var v := u.orthogonal()
	var o := p - u * w * 0.5
	tb.quad(o, o + u * w, o + u * w + v * 7.0 * s, o + v * 7.0 * s, c)
	tb.quad(o - v * 18.0 * s, o - v * 18.0 * s + u * 5.0 * s, o + u * 5.0 * s + v * 9.0 * s, o + v * 9.0 * s, c)
	tb.quad(o + u * (w - 5.0 * s) - v * 18.0 * s, o + u * w - v * 18.0 * s, o + u * w + v * 9.0 * s, o + u * (w - 5.0 * s) + v * 9.0 * s, c)
	tb.quad(o - v * 15.0 * s, o + u * w - v * 15.0 * s, o + u * w - v * 10.0 * s, o - v * 10.0 * s, c.darkened(0.15))


# ---------------------------------------------------------------- near

static func _near(slice, tb, colors: Dictionary, span: Vector2, x0: float, x1: float, v: String, tall := 0.0) -> void:
	var near: Color = colors.get("near", Color("0d0a17"))
	var glass := _glass(colors)
	var density: float = float(colors.get("near_density", 1.0))
	var every := NEAR_EVERY / maxf(density, 0.1)
	if tall > 0.0 and v != "prism":
		_tall_near(tb, near, glass, span, x0, x1, v, tall, every)
	match v:
		"choir", "void":
			var ev := every if v == "choir" else every * 2.6
			for i in _each(ev, x0, x1, 200.0):
				var x := i * ev + 200.0 + _h(i, 91) * 160.0
				var hanging := _h(i, 92) < 0.55
				_near_shard(tb, x, Vector2(span.x, span.y + tall), near, glass[absi(i) % glass.size()], hanging, i)
		"rose":
			for i in _each(every, x0, x1, 140.0):
				var x := i * every + 140.0 + _h(i, 93) * 200.0
				_banner(slice, tb, x, span, near, colors.get("banner", Color("6a2e3a")), i)
		"prism":
			for i in _each(every, x0, x1, 100.0):
				var x := i * every + 100.0 + _h(i, 95) * 80.0
				_pillar(slice, tb, x, span, near, i)


static func _near_shard(tb, x: float, span: Vector2, near: Color, g: Color, hanging: bool, i: int) -> void:
	## A big dark shard in the foreground with a thin coloured edge: hanging
	## from the top, or rising from below the view.
	var w := 50.0 + 40.0 * _h(i, 96)
	var l := 110.0 + 90.0 * _h(i, 97)
	var pts: PackedVector2Array
	if hanging:
		pts = PackedVector2Array([Vector2(x - w * 0.5, -40.0), Vector2(x + w * 0.5, -40.0), Vector2(x + w * 0.2, l * 0.6), Vector2(x - w * 0.05, l)])
	else:
		var b := span.y + 60.0
		pts = PackedVector2Array([Vector2(x - w * 0.4, b), Vector2(x + w * 0.5, b), Vector2(x + w * 0.1, b - l * 0.7), Vector2(x - w * 0.15, b - l)])
	var edge := g.darkened(0.25)
	tb.convex(PackedVector2Array([pts[0] + Vector2(-2, 0), pts[1] + Vector2(2, 0), pts[2] + Vector2(2, 1), pts[3] + Vector2(0, 3 if hanging else -3)]), Color(edge, 0.9))
	tb.convex(pts, near)


static func _banner(slice, tb, x: float, span: Vector2, near: Color, banner: Color, i: int) -> void:
	## A torn banner hanging from the dark, its ragged end lifting.
	var w := 34.0 + 14.0 * _h(i, 98)
	var l := 90.0 + 80.0 * _h(i, 99)
	var b := banner.darkened(0.55)
	slice.draw_rect(Rect2(x - w * 0.5 - 6.0, -10.0, w + 12.0, 6.0), near)
	slice.draw_rect(Rect2(x - w * 0.5, -6.0, w, l), b)
	slice.draw_rect(Rect2(x - w * 0.5, -6.0, 4.0, l), b.darkened(0.3))
	# Ragged tails, blown to the right.
	for k in 3:
		var tx := x - w * 0.5 + k * w / 3.0
		tb.tri(Vector2(tx, l - 6.0), Vector2(tx + w / 3.0, l - 6.0), Vector2(tx + w / 3.0 + 8.0, l + 14.0 + 10.0 * _h(i * 3 + k, 100)), b)


static func _pillar(slice, tb, x: float, span: Vector2, near: Color, i: int) -> void:
	## A near pillar of the Lightwell with a gold capital.
	var gold := Color("6a5424")
	slice.draw_rect(Rect2(x - 22.0, -60.0, 44.0, span.y + 460.0), near)
	var cy := 70.0 + _h(i, 101) * 40.0
	slice.draw_rect(Rect2(x - 30.0, cy, 60.0, 12.0), near.lightened(0.04))
	slice.draw_rect(Rect2(x - 30.0, cy + 12.0, 60.0, 2.0), gold)
	slice.draw_rect(Rect2(x - 26.0, cy - 3.0, 52.0, 2.0), gold)
	slice.draw_rect(Rect2(x - 3.0, cy + 18.0, 2.0, span.y), near.lightened(0.05))


# ---------------------------------------------------------------- a tall level's void

static func _tall_mid(slice, tb, mid: Color, lead: Color, glass: Array, span: Vector2, x0: float, x1: float, v: String, tall: float) -> void:
	## More of what floats in the mid layer, a storey at a time under the
	## strip's (its own salts: no storey is the strip's again).
	var k := 0
	while span.y * 0.74 + k * STOREY < span.y + tall + 20.0:
		var sy := span.y * 0.74 + k * STOREY
		match v:
			"choir":
				for i in _each(STALL_EVERY, x0, x1, 120.0 + 200.0 * (k % 2)):
					var x := i * STALL_EVERY + 120.0 + 200.0 * (k % 2) + _h(i, 151 + k) * 120.0
					var y := sy + _h(i, 152 + k) * STOREY * 0.6
					if _h(i, 153 + k) < 0.5:
						_stall(slice, tb, Vector2(x, y), mid, lead, glass[absi(i + k) % glass.size()], i + 40 * (k + 1))
					else:
						_broken_arch(slice, tb, Vector2(x, y), mid, lead, glass[absi(i + k + 1) % glass.size()], i + 40 * (k + 1))
			"rose":
				for i in _each(RIBBON_EVERY, x0, x1, 60.0 + 150.0 * (k % 2)):
					var x := i * RIBBON_EVERY + 60.0 + 150.0 * (k % 2) + _h(i, 161 + k) * 140.0
					_came_ribbon(tb, Vector2(x, sy + _h(i, 162 + k) * STOREY * 0.7), mid.lightened(0.05), lead, glass, i + 50 * (k + 1))
			"void":
				for i in _each(FRAG_EVERY * 0.7, x0, x1, 200.0 + 260.0 * (k % 2)):
					var x := i * FRAG_EVERY * 0.7 + 200.0 + 260.0 * (k % 2) + _h(i, 171 + k) * 300.0
					_chunk(tb, Vector2(x, sy + _h(i, 172 + k) * STOREY * 0.7), 26.0 + 30.0 * _h(i, 173 + k), mid, i + 900 + 60 * (k + 1))
		k += 1


static func _tall_near(tb, near: Color, glass: Array, span: Vector2, x0: float, x1: float, v: String, tall: float, every: float) -> void:
	## Loose shards drifting in the near layer's deeper void, a storey at a
	## time: dark, a thin coloured edge, tilted (never level: nothing to
	## stand on).
	var ev := every * (1.4 if v == "choir" else 2.2)
	var k := 0
	while span.y * 0.55 + k * NEAR_STOREY < span.y + tall - 80.0:
		var sy := span.y * 0.55 + k * NEAR_STOREY
		for i in _each(ev, x0, x1, 90.0 + 230.0 * (k % 2)):
			var c := Vector2(i * ev + 90.0 + 230.0 * (k % 2) + _h(i, 181 + k) * 200.0, sy + _h(i, 182 + k) * NEAR_STOREY * 0.6)
			var w := 26.0 + 26.0 * _h(i, 183 + k)
			var l := 60.0 + 60.0 * _h(i, 184 + k)
			var ang := (_h(i, 185 + k) - 0.5) * 1.6
			var u := Vector2(cos(ang), sin(ang))
			var n := u.orthogonal()
			var pts := PackedVector2Array([c - n * l * 0.5 - u * w * 0.4, c - n * l * 0.3 + u * w * 0.5, c + n * l * 0.5 + u * w * 0.1, c + n * l * 0.2 - u * w * 0.3])
			var edge := (glass[absi(i + k) % glass.size()] as Color).darkened(0.25)
			tb.convex(PackedVector2Array([pts[0] - u * 2.0, pts[1] + u * 2.0, pts[2] + n * 2.0, pts[3] - u * 2.0]), Color(edge, 0.9))
			tb.convex(pts, near)
		k += 1


# ---------------------------------------------------------------- lights

static func windows(layer_index: int, colors: Dictionary, span: Vector2, tall := 0.0) -> Array:
	var out := []
	var glass := _glass(colors)
	var v := _variant(colors)
	span = Vector2(span.x, span.y - tall)   # (laid out on the strip's span, as draw() does)
	if layer_index == 0:
		if v == "choir" or v == "rose":
			var i := 0
			while i * ROSE_EVERY + 520.0 < span.x + 200.0:
				var c := Vector2(i * ROSE_EVERY + 520.0 + _h(i, 21) * 160.0, span.y * 0.3 + _h(i, 22) * 30.0)
				var g: Color = glass[absi(i) % glass.size()]
				out.append({"layer": 0, "rose": true, "center": c, "radius": 60.0, "colors": glass, "s": 0.30,
						"tint": Color(g.r, g.g, g.b, 0.6)})
				i += 1
		elif v == "prism":
			var ax := _arena_x(span)
			out.append({"layer": 0, "rose": true, "center": Vector2(ax, span.y * 0.3), "radius": 80.0, "colors": [Color("c8c0e8")], "s": 0.22})
	elif layer_index == 1 and v != "prism":
		# A few lit shards on the mid layer: tinted decorative lights.
		var i := 0
		var ev := SHARD_LIGHT_EVERY * (1.6 if v == "void" else 1.0)
		while i * ev + 400.0 < span.x + 200.0:
			var x := i * ev + 400.0 + _h(i, 111) * 200.0
			var y := span.y * (0.3 + 0.3 * _h(i, 112))
			var g: Color = glass[absi(i + 2) % glass.size()]
			out.append({"layer": 1, "rose": false, "rect": Rect2(x - 20.0, y - 20.0, 40.0, 40.0), "colors": [g], "seed": i, "s": 0.45,
					"tint": Color(g.r, g.g, g.b, 0.8)})
			i += 1
	return out
