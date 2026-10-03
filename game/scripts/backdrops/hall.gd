extends RefCounted
## The modes' and secrets' backdrop style (A2), by the theme's "variant":
##   hall   the Proving Hall (theme trialhall, the Vigil Trials): black marble
##          and gold inlay, the brightest level theme (trials test execution,
##          not darkness). far: a vast hourglass inlaid in gold and tall gold
##          windows; mid: an arcade of pointed arches in black marble; near:
##          gold-inlaid pillars.
##   roof   1-S, the Roof of Evenbell (nave_gilt): outdoors at night in the
##          snow. far: a starry sky, the moon, Evenbell's far roofs and
##          spires; mid: Lanternfold's roofs across the gap, their lamps lit
##          (the windows); near: chimney stacks and a weathervane. The snow
##          itself is the theme's motes (modes.gd AMBIENT, 40 flakes at most).
## windows(): the hall's gold windows, Lanternfold's lamps (warm, tinted).
##   static func draw(slice, tb, layer_index, colors, span, x0, x1)
##   static func windows(layer_index, colors, span) -> Array
## (a gilt theme's "near_density" 0.5 halves the near layer.)
## No draw_circle / draw_colored_polygon / draw_polyline (test_render.gd).

const WINDOW_EVERY := 900.0
const HOURGLASS_EVERY := 1500.0
const BAY := 200.0
const PILLAR_EVERY := 520.0
const STAR_EVERY := 15.0
const ROOF_EVERY := 150.0
const TOWN_EVERY := 120.0
const LAMP_EVERY := 330.0
const STACK_EVERY := 430.0
const GOLD := Color("c8a860")


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


static func _arch_pts(x0: float, x1: float, top: float, bottom: float, seg := 8) -> PackedVector2Array:
	## An equilateral pointed arch (convex), top down to bottom.
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


static func draw(slice: Node2D, tb, layer_index: int, colors: Dictionary, span: Vector2, x0: float, x1: float) -> void:
	if str(colors.get("variant", "hall")) == "roof":
		_roof(slice, tb, layer_index, colors, span, x0, x1)
		return
	var sky: Color = colors.get("sky", Color("0c0a10"))
	var far: Color = colors.get("far", Color("16121c"))
	var mid: Color = colors.get("mid", Color("1e1a26"))
	var near: Color = colors.get("near", Color("0e0b14"))
	var glass: Array = colors.get("glass", [Color("ffd84a"), Color("fff2c8")])
	var bottom := span.y + 400.0
	match layer_index:
		0:
			slice.draw_rect(Rect2(x0, -200.0, x1 - x0, bottom + 200.0), sky)
			# The far wall of black marble, its courses picked out in gold.
			slice.draw_rect(Rect2(x0, 40.0, x1 - x0, bottom), far)
			for r in 6:
				slice.draw_rect(Rect2(x0, 70.0 + r * 64.0, x1 - x0, 1.0), Color(GOLD, 0.16))
			for i in _each(HOURGLASS_EVERY, x0, x1, 600.0):
				_hourglass(tb, Vector2(i * HOURGLASS_EVERY + 600.0 + _h(i, 1) * 200.0, span.y * 0.42), span.y * 0.3)
			for w in windows(0, colors, span):
				var r: Rect2 = w["rect"]
				if r.get_center().x < x0 or r.get_center().x >= x1:
					continue
				_gold_window(slice, tb, r, glass, far)
		1:
			# An arcade of pointed arches: piers, arches, the dark beyond.
			slice.draw_rect(Rect2(x0, span.y * 0.2, x1 - x0, bottom), mid.darkened(0.35))
			for i in _each(BAY, x0, x1):
				var x := i * BAY
				slice.draw_rect(Rect2(x - 14.0, 30.0, 28.0, bottom), mid)
				slice.draw_rect(Rect2(x - 18.0, 30.0 + span.y * 0.25, 36.0, 6.0), mid.lightened(0.06))
				slice.draw_rect(Rect2(x - 18.0, 36.0 + span.y * 0.25, 36.0, 1.5), Color(GOLD, 0.35))
				slice.draw_rect(Rect2(x - 1.0, 30.0, 2.0, bottom), Color(GOLD, 0.18))
				var ax := x + BAY * 0.5
				var top := 40.0 + span.y * 0.05
				var arch := _arch_pts(ax - BAY * 0.5 + 14.0, ax + BAY * 0.5 - 14.0, top, top + span.y * 0.9, 8)
				tb.convex(arch, mid.darkened(0.5))
				tb.polyline(arch, 1.5, Color(GOLD, 0.28), true)
		2:
			var density: float = float(colors.get("near_density", 1.0))
			var every := PILLAR_EVERY / maxf(density, 0.1)
			for i in _each(every, x0, x1, 160.0):
				var x := i * every + 160.0 + _h(i, 5) * 100.0
				slice.draw_rect(Rect2(x - 24.0, -60.0, 48.0, bottom + 60.0), near)
				# The gold inlay: a line up the middle, lozenges, a capital.
				slice.draw_rect(Rect2(x - 1.0, -60.0, 2.0, bottom + 60.0), Color(GOLD, 0.45))
				slice.draw_rect(Rect2(x - 20.0, -60.0, 1.0, bottom + 60.0), Color(GOLD, 0.2))
				slice.draw_rect(Rect2(x + 19.0, -60.0, 1.0, bottom + 60.0), Color(GOLD, 0.2))
				var cy := 80.0 + _h(i, 6) * 30.0
				slice.draw_rect(Rect2(x - 32.0, cy, 64.0, 12.0), near.lightened(0.05))
				slice.draw_rect(Rect2(x - 32.0, cy + 12.0, 64.0, 2.0), Color(GOLD, 0.6))
				for k in 3:
					var ly := cy + 60.0 + k * 90.0
					tb.quad(Vector2(x, ly - 9.0), Vector2(x + 6.0, ly), Vector2(x, ly + 9.0), Vector2(x - 6.0, ly), Color(GOLD, 0.45))


static func _hourglass(tb, c: Vector2, h: float) -> void:
	## A vast hourglass inlaid in gold on the far wall: its frame, two
	## bulbs, sand running.
	var g := Color(GOLD, 0.30)
	var w := h * 0.55
	tb.line(c + Vector2(-w * 0.6, -h), c + Vector2(w * 0.6, -h), 5.0, g)
	tb.line(c + Vector2(-w * 0.6, h), c + Vector2(w * 0.6, h), 5.0, g)
	tb.line(c + Vector2(-w * 0.55, -h), c + Vector2(-w * 0.55, h), 3.0, g)
	tb.line(c + Vector2(w * 0.55, -h), c + Vector2(w * 0.55, h), 3.0, g)
	var bulb := PackedVector2Array([c + Vector2(-w * 0.45, -h + 6.0), c + Vector2(-w * 0.35, -h * 0.35), c + Vector2(-4.0, -3.0),
			c + Vector2(-4.0, 3.0), c + Vector2(-w * 0.35, h * 0.35), c + Vector2(-w * 0.45, h - 6.0), c + Vector2(w * 0.45, h - 6.0),
			c + Vector2(w * 0.35, h * 0.35), c + Vector2(4.0, 3.0), c + Vector2(4.0, -3.0), c + Vector2(w * 0.35, -h * 0.35),
			c + Vector2(w * 0.45, -h + 6.0)])
	tb.polyline(bulb, 2.5, g, true)
	tb.tri(c + Vector2(-w * 0.3, h - 8.0), c + Vector2(w * 0.3, h - 8.0), c + Vector2(0, h * 0.45), Color(GOLD, 0.22))
	tb.line(c, c + Vector2(0, h * 0.45), 1.5, Color(GOLD, 0.25))


static func _gold_window(slice: Node2D, tb, r: Rect2, glass: Array, far: Color) -> void:
	## A tall arched window of gold glass in lead.
	var outer := _arch_pts(r.position.x - 6.0, r.end.x + 6.0, r.position.y - 6.0, r.end.y + 4.0, 8)
	tb.convex(outer, far.darkened(0.4))
	var inner := _arch_pts(r.position.x, r.end.x, r.position.y, r.end.y, 8)
	tb.convex(inner, (glass[0] as Color).darkened(0.35))
	for row in 5:
		var y := r.position.y + r.size.x * 0.866 + row * (r.size.y - r.size.x * 0.866) / 5.0
		tb.line(Vector2(r.position.x, y), Vector2(r.end.x, y), 1.5, far.darkened(0.4))
	tb.line(Vector2(r.get_center().x, r.position.y + 8.0), Vector2(r.get_center().x, r.end.y), 1.5, far.darkened(0.4))
	var hi: Color = glass[1 % glass.size()]
	tb.convex(_arch_pts(r.position.x + 6.0, r.get_center().x - 3.0, r.position.y + r.size.x * 0.4, r.position.y + r.size.x * 1.2, 4), Color(hi, 0.18))


# ---------------------------------------------------------------- 1-S: the roof

static func _roof(slice: Node2D, tb, layer_index: int, colors: Dictionary, span: Vector2, x0: float, x1: float) -> void:
	var sky: Color = colors.get("sky", Color("0e1024"))
	var far: Color = colors.get("far", Color("1a1c34"))
	var mid: Color = colors.get("mid", Color("24264a"))
	var near: Color = colors.get("near", Color("14142a"))
	var snow := Color("d8dcf0")
	var bottom := span.y + 400.0
	match layer_index:
		0:
			slice.draw_rect(Rect2(x0, -200.0, x1 - x0, bottom + 200.0), sky)
			for b in 5:
				var y := span.y * (0.45 + 0.11 * b)
				slice.draw_rect(Rect2(x0, y, x1 - x0, bottom - y), Color(far.lightened(0.04), 0.16))
			for i in _each(STAR_EVERY, x0, x1):
				var sx := i * STAR_EVERY + _h(i, 1) * STAR_EVERY
				var sy := _h(i, 2) * span.y * 0.6
				slice.draw_rect(Rect2(sx, sy, 1.0 if _h(i, 3) < 0.85 else 2.0, 1.0 if _h(i, 3) < 0.85 else 2.0), Color(0.92, 0.94, 1.0, 0.25 + 0.6 * _h(i, 4)))
			# The moon, once, early on (the far layer barely moves).
			var mx := 520.0
			if mx >= x0 and mx < x1:
				tb.circle(Vector2(mx, 70.0), 50.0, Color(snow, 0.05), 28)
				tb.circle(Vector2(mx, 70.0), 34.0, Color(snow, 0.08), 24)
				tb.circle(Vector2(mx, 70.0), 22.0, Color("eef0ff"), 24)
				tb.circle(Vector2(mx + 6.0, 64.0), 5.0, Color("d0d4ec"), 10)
				tb.circle(Vector2(mx - 8.0, 76.0), 3.5, Color("d0d4ec"), 8)
			# Evenbell's far roofs and spires, snow on their tops.
			for i in _each(TOWN_EVERY, x0, x1):
				var x := i * TOWN_EVERY + _h(i, 5) * 40.0
				var top := span.y * (0.5 + 0.14 * _h(i, 6))
				var w := 50.0 + 40.0 * _h(i, 7)
				slice.draw_rect(Rect2(x - w * 0.5, top, w, bottom), far)
				tb.tri(Vector2(x - w * 0.5 - 4.0, top), Vector2(x + w * 0.5 + 4.0, top), Vector2(x, top - w * 0.45), far)
				tb.tri(Vector2(x - w * 0.22, top - w * 0.25), Vector2(x + w * 0.22, top - w * 0.25), Vector2(x, top - w * 0.45), Color(snow, 0.35))
				if _h(i, 8) > 0.8:
					slice.draw_rect(Rect2(x - 5.0, top - w * 0.45 - 60.0, 10.0, 62.0), far)
					tb.tri(Vector2(x - 8.0, top - w * 0.45 - 60.0), Vector2(x + 8.0, top - w * 0.45 - 60.0), Vector2(x, top - w * 0.45 - 90.0), far)
		1:
			# Lanternfold's roofs across the gap, and their lamps.
			for i in _each(ROOF_EVERY, x0, x1):
				var x := i * ROOF_EVERY + _h(i, 11) * 50.0
				var top := span.y * (0.56 + 0.12 * _h(i, 12))
				var w := 90.0 + 50.0 * _h(i, 13)
				slice.draw_rect(Rect2(x - w * 0.5, top, w, bottom), mid)
				tb.tri(Vector2(x - w * 0.5 - 6.0, top + 1.0), Vector2(x + w * 0.5 + 6.0, top + 1.0), Vector2(x, top - w * 0.38), mid)
				tb.tri(Vector2(x - w * 0.3, top - w * 0.15), Vector2(x + w * 0.3, top - w * 0.15), Vector2(x, top - w * 0.38), Color(snow, 0.55))
				slice.draw_rect(Rect2(x - w * 0.5 - 6.0, top, w + 12.0, 3.0), Color(snow, 0.45))
				if _h(i, 14) > 0.55:
					slice.draw_rect(Rect2(x + w * 0.2, top - w * 0.36, 10.0, w * 0.26), mid)
					slice.draw_rect(Rect2(x + w * 0.2 - 1.0, top - w * 0.36, 12.0, 3.0), Color(snow, 0.6))
			for w in windows(1, colors, span):
				var r: Rect2 = w["rect"]
				var c := r.get_center()
				if c.x < x0 or c.x >= x1:
					continue
				slice.draw_rect(r.grow(2.0), mid.darkened(0.4))
				slice.draw_rect(r, Color("f2b84b"))
				slice.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.4)), Color("ffe6a0"))
				slice.draw_rect(Rect2(c.x - 0.75, r.position.y, 1.5, r.size.y), mid.darkened(0.4))
		2:
			var density: float = float(colors.get("near_density", 1.0))
			var every := STACK_EVERY / maxf(density, 0.1)
			for i in _each(every, x0, x1, 120.0):
				var x := i * every + 120.0 + _h(i, 21) * 120.0
				var hgt := 80.0 + 60.0 * _h(i, 22)
				var top := span.y * 0.62 - hgt
				slice.draw_rect(Rect2(x - 16.0, top, 32.0, bottom), near)
				slice.draw_rect(Rect2(x - 20.0, top - 6.0, 40.0, 7.0), near.lightened(0.05))
				slice.draw_rect(Rect2(x - 20.0, top - 9.0, 40.0, 3.5), Color(snow, 0.5))
				if _h(i, 23) > 0.7:
					# A weathervane: a little bell on a rod.
					slice.draw_rect(Rect2(x - 1.0, top - 44.0, 2.0, 36.0), near)
					tb.convex(PackedVector2Array([Vector2(x - 3.0, top - 40.0), Vector2(x + 3.0, top - 40.0), Vector2(x + 6.0, top - 30.0), Vector2(x - 6.0, top - 30.0)]), near)
					tb.line(Vector2(x - 12.0, top - 46.0), Vector2(x + 12.0, top - 46.0), 1.5, near)


static func windows(layer_index: int, colors: Dictionary, span: Vector2) -> Array:
	var out := []
	var roof := str(colors.get("variant", "hall")) == "roof"
	if roof:
		if layer_index == 1:
			var i := 0
			while i * LAMP_EVERY + 200.0 < span.x + 200.0:
				var x := i * LAMP_EVERY + 200.0 + _h(i, 31) * 90.0
				var y := span.y * (0.6 + 0.1 * _h(i, 32))
				out.append({"layer": 1, "rose": false, "rect": Rect2(x - 5.0, y, 10.0, 14.0), "colors": [Color("f2b84b")], "seed": i,
						"s": 0.5, "tint": Color(1.0, 0.72, 0.36, 0.35)})
				i += 1
		return out
	if layer_index == 0:
		var glass: Array = colors.get("glass", [Color("ffd84a")])
		var g: Color = glass[0]
		var i := 0
		while i * WINDOW_EVERY + 300.0 < span.x + 200.0:
			var x := i * WINDOW_EVERY + 300.0 + _h(i, 41) * 120.0
			out.append({"layer": 0, "rose": false, "rect": Rect2(x - 26.0, 90.0, 52.0, span.y * 0.5), "colors": glass, "seed": i,
					"s": 0.42, "tint": Color(g.r, g.g, g.b, 0.35)})
			i += 1
	return out
