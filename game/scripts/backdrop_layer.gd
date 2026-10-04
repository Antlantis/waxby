extends Node2D
## One parallax layer of the Backdrop, drawn once in its own space: the
## cathedral (vaults, arcade, pillars) or, for the World 2 themes, the
## cavern (a far wall with waxfall curtains, a giant candle or lilies; wax
## terraces with candle stubs; near stalactites, drip columns and roots).
## In a level taller than 15 rows (backdrop.tall(), the shapes plan's E9)
## the strip's drawing stays as it was at the top and its ground at the
## bottom, and the band between goes on down a storey at a time, in one
## TriBatch: the cathedral's arcade under a string course, a triforium of
## blind lancets and a storey of glass by turns (that glass lights, as the
## strip's does), the near pillars' capitals with a lamp chain off them; the
## cavern's wax shelves with drips (moss and leaves in the garden) and near
## rock ledges with stalactites under them. The far layers barely move and
## keep the strip's drawing.

const TriBatch := preload("res://scripts/tri_batch.gd")

var backdrop: Node2D
var index := 0
# v3 styles (backdrop.gd cuts their layers into slices): 0 draws the whole
# layer the v2 way, 1 is a sliced layer's parent (it draws nothing), 2 is one
# slice [x0, x1) drawn by the style's draw() and one TriBatch flush.
var mode := 0
var x0 := 0.0
var x1 := 0.0
var style: Script = null
var _tb = null
const STOREY := 250.0            # a tall level's storey down the arcade (mid)
const NEAR_STOREY := 300.0       # and down the near pillars, the cavern's ledges

func _ready() -> void:
	queue_redraw()


func _h(i: int, salt: int = 0) -> float:
	var h := (i * 2654435761 + salt * 40503) & 0x7fffffff
	return float(h % 10000) / 10000.0


func _draw() -> void:
	if mode == 1:
		return
	var c: Dictionary = backdrop.colors()
	var span: Vector2 = backdrop.span(index)
	if mode == 2:
		if _tb == null:
			_tb = TriBatch.new()
		_tb.origin = Vector2(x0, 0)
		style.draw(self, _tb, index, c, span, x0, x1, backdrop.tall(index))
		_tb.flush(self)
		return
	var tall: float = backdrop.tall(index) if backdrop.has_method("tall") else 0.0
	if str(c.get("style", "cathedral")) == "cavern":
		match index:
			0:
				_cave_far(c, span)
			1:
				_cave_terraces(c, span, tall)
			2:
				_cave_near(c, span)
		if tall > 0.0 and index > 0:
			_tall_cavern(c, span, tall)
		return
	match index:
		0:
			_far(c, span)
		1:
			_arcade(c, span)
		2:
			_near(c, span)
	if tall > 0.0 and index > 0:
		_tall_cathedral(c, span, tall)


func _arch(x: float, w: float, top: float, bottom: float, col: Color) -> void:
	## A pointed (gothic) arch opening from top to bottom.
	# An equilateral arch: two arcs of radius w, each centered on the other
	# side's springing point, meeting in a point 0.866 w above them.
	var pts := PackedVector2Array()
	var spring := top + w * 0.866
	pts.append(Vector2(x, bottom))
	for k in range(0, 9):
		var th := deg_to_rad(180.0 - 60.0 * k / 8.0)
		pts.append(Vector2(x + w + w * cos(th), spring - w * sin(th)))
	for k in range(1, 9):
		var th := deg_to_rad(60.0 - 60.0 * k / 8.0)
		pts.append(Vector2(x + w * cos(th), spring - w * sin(th)))
	pts.append(Vector2(x + w, bottom))
	draw_colored_polygon(pts, col)


func _far(c: Dictionary, span: Vector2) -> void:
	draw_rect(Rect2(Vector2(-200, -200), span + Vector2(400, 600)), c["sky"])
	# Vaults: big faint arches all along.
	var w := 260.0
	var n := int(span.x / w) + 2
	for i in n:
		var x := i * w - 40.0
		_arch(x + 20, w - 40, 30.0 + _h(i) * 20.0, span.y + 200, c["far"])
	# A great rose window every so often.
	var every := 900.0
	var i2 := 0
	var x2 := 380.0
	while x2 < span.x + 200:
		var center := Vector2(x2, 120.0 + _h(i2, 3) * 30.0)
		var r := 58.0
		draw_circle(center, r + 8.0, c["far"].darkened(0.35))
		draw_circle(center, r, c["mid"].darkened(0.2))
		_rose(center, r, c["glass"])
		backdrop.windows.append({"layer": 0, "rose": true, "center": center, "radius": r, "colors": c["glass"]})
		x2 += every
		i2 += 1


func _arcade(c: Dictionary, span: Vector2) -> void:
	# A wall with a row of pointed windows and pillars between them.
	var wall_top := 60.0
	var bay := 200.0
	var n := int(span.x / bay) + 2
	draw_rect(Rect2(Vector2(-200, wall_top + 40.0), Vector2(span.x + 400, span.y + 400)), c["mid"].darkened(0.25))
	for i in n:
		var x := i * bay
		# Pillar.
		draw_rect(Rect2(x - 16, wall_top - 20, 32, span.y + 300), c["mid"])
		draw_rect(Rect2(x - 22, wall_top + 30, 44, 10), c["mid"].lightened(0.08))
		draw_rect(Rect2(x + 8, wall_top - 20, 8, span.y + 300), c["mid"].darkened(0.2))
		# Window between pillars.
		if _h(i, 7) > 0.2:
			var wx := x + bay * 0.5 - 26.0
			var wtop := wall_top + 60.0 + _h(i, 1) * 20.0
			_arch(wx - 6, 64, wtop - 6, wtop + 150, c["mid"].darkened(0.45))
			_arch(wx, 52, wtop, wtop + 144, c["far"].darkened(0.3))
			_lancet(Rect2(wx, wtop, 52, 144), c["glass"], i)
			backdrop.windows.append({"layer": 1, "rose": false, "rect": Rect2(wx, wtop, 52, 144),
					"colors": c["glass"], "seed": i})


func _near(c: Dictionary, span: Vector2) -> void:
	var gap := 520.0
	var n := int(span.x / gap) + 2
	var dens := float(c.get("near_density", 1.0))   # a gilt secret's near layer at half (spec §11.4)
	for i in n:
		if dens < 1.0 and _h(i, 31) >= dens:
			continue
		var x := i * gap + _h(i, 5) * 120.0
		# A heavy pillar silhouette.
		draw_rect(Rect2(x - 26, -60, 52, span.y + 400), c["near"])
		draw_rect(Rect2(x - 34, 90 + _h(i) * 40.0, 68, 14), c["near"].lightened(0.06))
		# Chains hanging from the dark.
		if _h(i, 9) > 0.35:
			var cx := x + 90.0 + _h(i, 2) * 80.0
			var len := 60.0 + _h(i, 4) * 90.0
			var y := -10.0
			while y < len:
				draw_arc(Vector2(cx, y), 3.5, 0.0, TAU, 10, c["near"].lightened(0.12), 1.6)
				y += 8.0
		# A banner.
		if _h(i, 11) > 0.45:
			var bx := x + 160.0 + _h(i, 6) * 60.0
			var bw := 34.0
			var bh := 90.0 + _h(i, 8) * 40.0
			var ban := PackedVector2Array([Vector2(bx, 20), Vector2(bx + bw, 20), Vector2(bx + bw, 20 + bh), Vector2(bx + bw * 0.5, 20 + bh - 16), Vector2(bx, 20 + bh)])
			draw_colored_polygon(ban, c["banner"].darkened(0.35))
			draw_rect(Rect2(bx - 4, 16, bw + 8, 5), c["near"].lightened(0.15))
			# A pale flame emblem.
			var e := Vector2(bx + bw * 0.5, 20 + bh * 0.45)
			var fl := PackedVector2Array([e + Vector2(0, -12), e + Vector2(6, 2), e + Vector2(0, 8), e + Vector2(-6, 2)])
			draw_colored_polygon(fl, c["banner"].lightened(0.2).darkened(0.2))


func _rose(c: Vector2, r: float, cols: Array) -> void:
	## A rose window's glass: twelve petals round a hub, leaded.
	for i in 12:
		var a0 := TAU * i / 12.0
		var a1 := a0 + TAU / 12.0
		var col: Color = cols[i % cols.size()]
		var pts := PackedVector2Array([c + Vector2(cos(a0), sin(a0)) * r * 0.3, c + Vector2(cos(a0), sin(a0)) * r * 0.92,
				c + Vector2(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5)) * r * 0.98, c + Vector2(cos(a1), sin(a1)) * r * 0.92,
				c + Vector2(cos(a1), sin(a1)) * r * 0.3])
		draw_colored_polygon(pts, col.darkened(0.15))
	draw_circle(c, r * 0.26, (cols[0] as Color).lightened(0.1))
	draw_arc(c, r * 0.28, 0, TAU, 24, Color(0, 0, 0, 0.6), 2.5)
	for i in 12:
		var a := TAU * i / 12.0
		draw_line(c + Vector2(cos(a), sin(a)) * r * 0.28, c + Vector2(cos(a), sin(a)) * r * 0.95, Color(0, 0, 0, 0.6), 2.5)


func _lancet(rr: Rect2, cols: Array, seed: int) -> void:
	## A lancet window's glass: panes in two columns under a pointed head.
	var spring := rr.position.y + rr.size.x * 0.866
	var rows := 5
	var ph := (rr.end.y - spring) / rows
	for row in rows:
		for colm in 2:
			var col: Color = cols[(seed * 7 + row * 3 + colm) % cols.size()]
			draw_rect(Rect2(rr.position.x + colm * rr.size.x * 0.5 + 2.0, spring + row * ph + 2.0, rr.size.x * 0.5 - 4.0, ph - 4.0), col.darkened(0.2))
	var w2 := rr.size.x
	var pts := PackedVector2Array()
	for k in range(0, 9):
		var th := deg_to_rad(180.0 - 60.0 * k / 8.0)
		pts.append(Vector2(rr.position.x + w2 + w2 * cos(th), spring - w2 * sin(th)))
	for k in range(1, 9):
		var th := deg_to_rad(60.0 - 60.0 * k / 8.0)
		pts.append(Vector2(rr.position.x + w2 * cos(th), spring - w2 * sin(th)))
	var inner := PackedVector2Array()
	var ctr := Vector2(rr.get_center().x, spring - w2 * 0.3)
	for q in pts:
		inner.append(ctr + (q - ctr) * 0.82)
	draw_colored_polygon(inner, (cols[seed % cols.size()] as Color).darkened(0.1))


# ---------------------------------------------------------------- a tall level (E9)

func _arch_pts(x: float, w: float, top: float, bottom: float) -> PackedVector2Array:
	## _arch's outline for a TriBatch: an equilateral pointed arch, top to bottom.
	var pts := PackedVector2Array()
	var spring := top + w * 0.866
	pts.append(Vector2(x, bottom))
	for k in range(0, 9):
		var th := deg_to_rad(180.0 - 60.0 * k / 8.0)
		pts.append(Vector2(x + w + w * cos(th), spring - w * sin(th)))
	for k in range(1, 9):
		var th := deg_to_rad(60.0 - 60.0 * k / 8.0)
		pts.append(Vector2(x + w * cos(th), spring - w * sin(th)))
	pts.append(Vector2(x + w, bottom))
	return pts


func _tb_lancet(tb, rr: Rect2, cols: Array, seed: int) -> void:
	## _lancet's glass into a TriBatch: panes in two columns under a pointed head.
	var spring := rr.position.y + rr.size.x * 0.866
	var ph := (rr.end.y - spring) / 5.0
	for row in 5:
		for colm in 2:
			var col: Color = cols[(seed * 7 + row * 3 + colm) % cols.size()]
			tb.rect(Rect2(rr.position.x + colm * rr.size.x * 0.5 + 2.0, spring + row * ph + 2.0, rr.size.x * 0.5 - 4.0, ph - 4.0), col.darkened(0.2))
	var head := _arch_pts(rr.position.x, rr.size.x, rr.position.y, spring)
	var ctr := Vector2(rr.get_center().x, spring - rr.size.x * 0.3)
	var inner := PackedVector2Array()
	for q in head:
		inner.append(ctr + (q - ctr) * 0.82)
	tb.convex(inner, (cols[seed % cols.size()] as Color).darkened(0.1))


func _tall_cathedral(c: Dictionary, span: Vector2, tall: float) -> void:
	## The cathedral on down a tall level (mid: the arcade's storeys; near:
	## the pillars' capitals and lamp chains), each storey salted by its index.
	var tb := TriBatch.new()
	if index == 1:
		var mid: Color = c["mid"]
		var wall_top := 60.0
		var bay := 200.0
		var n := int(span.x / bay) + 2
		var k := 1
		while wall_top + 60.0 + k * STOREY < span.y + 60.0:
			var oy := k * STOREY
			# the string course across the wall, the pillars' capitals again
			tb.rect(Rect2(-200.0, wall_top + oy - 22.0, span.x + 400.0, 8.0), mid.darkened(0.08))
			tb.rect(Rect2(-200.0, wall_top + oy - 22.0, span.x + 400.0, 2.0), mid.lightened(0.04))
			for i in n:
				var x := i * bay
				tb.rect(Rect2(x - 22.0, wall_top + 30.0 + oy, 44.0, 10.0), mid.lightened(0.08))
				if _h(i, 40 + k) < 0.15:
					continue
				var wtop := wall_top + 60.0 + oy + _h(i, 41 + k) * 20.0
				if k % 2 == 1:
					# a triforium: three blind lancets in the bay
					for q in 3:
						var lx := x + 34.0 + q * 46.0
						tb.convex(_arch_pts(lx - 4.0, 34.0, wtop - 4.0, wtop + 96.0), mid.darkened(0.3))
						tb.convex(_arch_pts(lx, 26.0, wtop, wtop + 92.0), mid.darkened(0.5))
				else:
					# a storey of glass: the strip's lancet, lit as the strip's are
					var wx := x + bay * 0.5 - 26.0
					tb.convex(_arch_pts(wx - 6.0, 64.0, wtop - 6.0, wtop + 150.0), mid.darkened(0.45))
					tb.convex(_arch_pts(wx, 52.0, wtop, wtop + 144.0), (c["far"] as Color).darkened(0.3))
					_tb_lancet(tb, Rect2(wx, wtop, 52.0, 144.0), c["glass"], i + 100 * k)
					backdrop.windows.append({"layer": 1, "rose": false, "rect": Rect2(wx, wtop, 52.0, 144.0),
							"colors": c["glass"], "seed": i + 100 * k})
			k += 1
	else:
		var near: Color = c["near"]
		var gap := 520.0
		var n := int(span.x / gap) + 2
		var dens := float(c.get("near_density", 1.0))
		var k := 1
		while 90.0 + k * NEAR_STOREY < span.y + 40.0:
			for i in n:
				if dens < 1.0 and _h(i, 31) >= dens:
					continue
				var x := i * gap + _h(i, 5) * 120.0
				var cy := 90.0 + k * NEAR_STOREY + _h(i + k, 50) * 40.0
				tb.rect(Rect2(x - 34.0, cy, 68.0, 14.0), near.lightened(0.06))
				if _h(i, 51 + k) > 0.4:
					# a lamp chain off the capital, its iron lamp dark
					var cx := x + 34.0 + _h(i, 52 + k) * 40.0
					var ln := 50.0 + _h(i, 53 + k) * 80.0
					var y := cy + 14.0
					while y < cy + 14.0 + ln:
						tb.ring(Vector2(cx, y), 3.5, 1.6, near.lightened(0.12), 10)
						y += 8.0
					tb.convex(PackedVector2Array([Vector2(cx - 7.0, y), Vector2(cx + 7.0, y), Vector2(cx + 5.0, y + 16.0), Vector2(cx - 5.0, y + 16.0)]),
							near.lightened(0.1))
			k += 1
	tb.flush(self)


func _tall_cavern(c: Dictionary, span: Vector2, tall: float) -> void:
	## The cavern on down a tall level (mid: wax shelves jutting from the wall,
	## moss and leaves off them in the garden; near: rock ledges with
	## stalactites, roots in the garden, under them), a storey at a time.
	var tb := TriBatch.new()
	var th := _theme()
	var wax: Color = c.get("wax", Color("cdb88e"))
	if index == 1:
		var mid: Color = c["mid"]
		var y0 := (span.y - tall) - 150.0
		var k := 0
		while y0 + k * 200.0 < span.y - 230.0:
			var sy := y0 + k * 200.0
			for i in int(span.x / 300.0) + 2:
				if _h(i, 60 + k) < 0.3:
					continue
				var x := i * 300.0 + 140.0 * (k % 2) + _h(i, 61 + k) * 80.0
				var w := 90.0 + _h(i, 62 + k) * 80.0
				var y := sy + _h(i, 63 + k) * 60.0
				# under it, a wedge of rock back into the wall
				tb.convex(PackedVector2Array([Vector2(x - w * 0.5, y + 12.0), Vector2(x + w * 0.5, y + 12.0), Vector2(x + w * 0.2, y + 40.0),
						Vector2(x - w * 0.3, y + 34.0)]), mid.darkened(0.1))
				tb.rect(Rect2(x - w * 0.5, y, w, 12.0), mid.darkened(0.04))
				tb.rect(Rect2(x - w * 0.5 - 4.0, y - 4.0, w + 8.0, 7.0), mid.lightened(0.08))
				tb.circle(Vector2(x - w * 0.5, y + 1.0), 5.0, mid.lightened(0.08), 10)
				tb.circle(Vector2(x + w * 0.5, y + 1.0), 5.0, mid.lightened(0.08), 10)
				for d in 4:
					var dx := x - w * 0.45 + _h(i * 5 + d, 64 + k) * w * 0.9
					var ln := 6.0 + _h(i * 5 + d, 65 + k) * 18.0
					if th == "garden":
						tb.line(Vector2(dx, y + 3.0), Vector2(dx + 2.0, y + 3.0 + ln * 1.6), 2.0, mid.lightened(0.06))
						tb.tri(Vector2(dx + 2.0, y + 3.0 + ln * 1.6), Vector2(dx + 12.0, y + ln * 1.6), Vector2(dx + 7.0, y + 8.0 + ln * 1.6), mid.lightened(0.1))
					else:
						tb.rect(Rect2(dx - 2.5, y + 3.0, 5.0, ln), wax.darkened(0.55))
						tb.circle(Vector2(dx, y + 3.0 + ln), 3.0, wax.darkened(0.55), 8)
			k += 1
	else:
		var near: Color = c["near"]
		var y0 := (span.y - tall) * 0.6
		var k := 0
		while y0 + k * NEAR_STOREY < span.y - 150.0:
			var sy := y0 + k * NEAR_STOREY
			for i in int(span.x / 430.0) + 2:
				if _h(i, 70 + k) < 0.45:
					continue
				var x := i * 430.0 + 200.0 + 170.0 * (k % 2) + _h(i, 71 + k) * 100.0
				var w := 70.0 + _h(i, 72 + k) * 70.0
				var y := sy + _h(i, 73 + k) * 80.0
				tb.convex(PackedVector2Array([Vector2(x - w, y + 6.0), Vector2(x - w * 0.4, y - 8.0), Vector2(x + w * 0.5, y - 4.0), Vector2(x + w, y + 8.0),
						Vector2(x + w * 0.4, y + 22.0), Vector2(x - w * 0.6, y + 20.0)]), near)
				for q in 4:
					var sx := x - w * 0.6 + q * w * 0.4 + _h(i * 4 + q, 74 + k) * 10.0
					var ln := 14.0 + _h(i * 4 + q, 75 + k) * 40.0
					if th == "garden":
						tb.line(Vector2(sx, y + 18.0), Vector2(sx + 3.0, y + 18.0 + ln * 1.5), 2.6, near.lightened(0.1))
					else:
						tb.tri(Vector2(sx - 6.0, y + 18.0), Vector2(sx + 6.0, y + 18.0), Vector2(sx, y + 18.0 + ln), near.lightened(0.05))
			k += 1
	tb.flush(self)


# ---------------------------------------------------------------- the cavern (World 2)

func _theme() -> String:
	return str(backdrop.theme)


func _wavy_band(x: float, w: float, top: float, bottom: float, col: Color, seed: int) -> void:
	## A curtain of wax running down: wavy sides, a rounded foot.
	var pts := PackedVector2Array()
	var n := 12
	for k in n + 1:
		var y := lerpf(top, bottom, float(k) / n)
		pts.append(Vector2(x - w * 0.5 + sin(y * 0.035 + seed) * w * 0.12, y))
	for k in range(n, -1, -1):
		var y := lerpf(top, bottom, float(k) / n)
		pts.append(Vector2(x + w * 0.5 + sin(y * 0.03 + seed * 1.7) * w * 0.12, y))
	draw_colored_polygon(pts, col)


func _candles(at: Vector2, n: int, c: Dictionary, layer: int, seed: int) -> void:
	## A cluster of stubs left burning in the deep: a glow for the World.
	var wax: Color = c.get("wax", Color("cdb88e"))
	var glass: Array = c["glass"]
	for k in n:
		var x := at.x + (k - n * 0.5) * 7.0 + _h(seed, k) * 3.0
		var h := 8.0 + _h(seed, k + 7) * 12.0
		draw_rect(Rect2(x - 2.5, at.y - h, 5, h), wax.darkened(0.35))
		draw_rect(Rect2(x - 2.5, at.y - h, 2, h), wax.darkened(0.15))
		draw_circle(Vector2(x, at.y - h - 3.0), 2.2, (glass[(seed + k) % glass.size()] as Color))
	backdrop.windows.append({"layer": layer, "rose": true, "center": at + Vector2(0, -14), "radius": 16.0 + n * 2.0, "colors": glass})


func _cave_far(c: Dictionary, span: Vector2) -> void:
	draw_rect(Rect2(Vector2(-200, -200), span + Vector2(400, 600)), c["sky"])
	var far: Color = c["far"]
	var wax: Color = c.get("wax", Color("cdb88e"))
	var th := _theme()
	# The giant shapes first, so the rock frames them.
	var x := 260.0
	var i := 0
	while x < span.x + 300:
		match th:
			"undercandle":
				# A candle the size of a tower, long melted: a slumped, uneven
				# top, wax run down its face, a dead wick with an ember on it.
				var w := 150.0 + _h(i, 2) * 60.0
				var top := 70.0 + _h(i, 3) * 40.0
				var body := far.lightened(0.06)
				var pts := PackedVector2Array([Vector2(x - w * 0.5, span.y + 300)])
				for k in 13:
					var xx := x - w * 0.5 + w * k / 12.0
					var dip := sin(k * 1.7 + i) * 5.0 + (14.0 if k == 0 or k == 12 else 0.0) + (6.0 if k == 1 or k == 11 else 0.0)
					pts.append(Vector2(xx, top + dip))
				pts.append(Vector2(x + w * 0.5, span.y + 300))
				draw_colored_polygon(pts, body)
				draw_rect(Rect2(x + w * 0.22, top + 10, w * 0.28, span.y + 300), far.darkened(0.1))
				for k in 7:
					var dx := x - w * 0.5 + 8.0 + (k + 0.5) * (w - 16.0) / 7.0
					var len := 30.0 + _h(i, k + 10) * 110.0
					var dc := body.lightened(0.05) if dx < x + w * 0.2 else far.darkened(0.04)
					draw_rect(Rect2(dx - 6, top + 4, 12, len), dc)
					draw_circle(Vector2(dx, top + 4 + len), 6.0, dc)
				draw_line(Vector2(x, top + 2), Vector2(x + 5, top - 22), Color("0e0a14"), 5.0)
				var glass: Array = c["glass"]
				draw_circle(Vector2(x + 5, top - 25), 4.0, (glass[1] as Color).darkened(0.35))
				backdrop.windows.append({"layer": 0, "rose": true, "center": Vector2(x + 5, top - 26), "radius": 26.0, "colors": glass})
				x += 1100.0 + _h(i, 4) * 300.0
			"garden":
				# Pale wax lilies taller than the cave.
				var base := Vector2(x, span.y + 40)
				var tip := Vector2(x + (_h(i, 5) - 0.5) * 120.0, 60.0 + _h(i, 6) * 60.0)
				var pts := PackedVector2Array()
				for k in 11:
					var s := k / 10.0
					pts.append(base.lerp(tip, s) + Vector2(sin(s * PI) * 40.0 * (1.0 if i % 2 == 0 else -1.0), 0))
				draw_polyline(pts, far.lightened(0.07), 9.0)
				var bell := PackedVector2Array([tip + Vector2(-34, 30), tip + Vector2(-22, -6), tip + Vector2(0, -14), tip + Vector2(22, -6), tip + Vector2(34, 30), tip + Vector2(10, 18), tip + Vector2(-10, 18)])
				draw_colored_polygon(bell, far.lightened(0.13))
				var glass2: Array = c["glass"]
				draw_circle(tip + Vector2(0, 16), 5.0, (glass2[0] as Color).darkened(0.35))
				backdrop.windows.append({"layer": 0, "rose": true, "center": tip + Vector2(0, 14), "radius": 24.0, "colors": glass2})
				x += 520.0 + _h(i, 4) * 260.0
			_:
				# Far waxfalls, pale against the rock.
				var w2 := 40.0 + _h(i, 2) * 50.0
				_wavy_band(x, w2, -20.0, span.y + 200, far.lightened(0.09), i)
				_wavy_band(x - w2 * 0.12, w2 * 0.35, -20.0, span.y + 200, far.lightened(0.16), i + 3)
				x += 380.0 + _h(i, 4) * 300.0
		i += 1
	# The cave's roof: rock with drips hanging off it.
	var roof := PackedVector2Array([Vector2(-200, -200)])
	var rx := -200.0
	var k2 := 0
	while rx < span.x + 240:
		var y := 26.0 + _h(k2, 1) * 26.0
		roof.append(Vector2(rx, y))
		if _h(k2, 2) > 0.6:
			roof.append(Vector2(rx + 12, y + 40.0 + _h(k2, 3) * 60.0))
			roof.append(Vector2(rx + 24, y + 4.0))
		rx += 40.0
		k2 += 1
	roof.append(Vector2(span.x + 240, -200))
	draw_colored_polygon(roof, far.darkened(0.25))
	# Its floor: heaped wax and rock.
	var fl := PackedVector2Array([Vector2(-200, span.y + 300)])
	var fx := -200.0
	var k3 := 0
	while fx < span.x + 240:
		fl.append(Vector2(fx, span.y - 70.0 - _h(k3, 8) * 50.0))
		fx += 60.0
		k3 += 1
	fl.append(Vector2(span.x + 240, span.y + 300))
	draw_colored_polygon(fl, far.darkened(0.12))
	# Candles someone left down here.
	var cx := 180.0
	var n := 0
	while cx < span.x:
		_candles(Vector2(cx, span.y - 70.0 - _h(n, 8) * 20.0), 3 + int(_h(n, 9) * 3.0), c, 0, n)
		cx += 480.0 + _h(n, 12) * 260.0
		n += 1


func _cave_terraces(c: Dictionary, span: Vector2, tall := 0.0) -> void:
	## Wax terraces stepping up the cave wall, with curtains between.
	var mid: Color = c["mid"]
	var wax: Color = c.get("wax", Color("cdb88e"))
	var th := _theme()
	var bay := 300.0
	var n := int(span.x / bay) + 2
	for i in n:
		var x := i * bay + _h(i, 1) * 80.0
		# A curtain of wax from the roof (not in the garden: vines instead).
		if th != "garden" and _h(i, 2) > 0.35:
			var wx := x + bay * 0.5
			var w := 22.0 + _h(i, 3) * 16.0
			_wavy_band(wx, w, -40.0, span.y - 120.0, mid.lightened(0.10), i)
			_wavy_band(wx - w * 0.15, w * 0.3, -40.0, span.y - 120.0, mid.lightened(0.18), i + 5)
			draw_circle(Vector2(wx, span.y - 116.0), w * 0.6, mid.lightened(0.10))
		elif th == "garden":
			var vx := x + bay * 0.5
			var pts := PackedVector2Array()
			for k in 12:
				var y := -20.0 + k * ((span.y - tall) * 0.06)   # (a tall level's vines: the strip's length)
				pts.append(Vector2(vx + sin(k * 0.8 + i) * 10.0, y))
			draw_polyline(pts, mid.lightened(0.08), 3.0)
			for k in range(1, 12, 2):
				draw_colored_polygon(PackedVector2Array([pts[k], pts[k] + Vector2(12, -4), pts[k] + Vector2(6, 4)]), mid.lightened(0.12))
		# The terrace: three rounded tiers.
		var ground := span.y - 30.0
		for tier in 3:
			var tw := 190.0 - tier * 50.0
			var tt := ground - (tier + 1) * 44.0 - _h(i, 4 + tier) * 10.0
			var tx := x - tw * 0.5 + tier * 14.0
			draw_rect(Rect2(tx, tt, tw, ground - tt + 200.0), mid.darkened(0.08 * tier))
			draw_rect(Rect2(tx - 4, tt - 4, tw + 8, 10), mid.lightened(0.08))
			draw_circle(Vector2(tx, tt + 1), 6.0, mid.lightened(0.08))
			draw_circle(Vector2(tx + tw, tt + 1), 6.0, mid.lightened(0.08))
			# Drips off each lip.
			for d in 4:
				var dx := tx + 10.0 + _h(i * 3 + tier, d) * (tw - 20.0)
				var len := 6.0 + _h(i + tier, d + 20) * 16.0
				draw_rect(Rect2(dx - 2.5, tt + 4, 5, len), wax.darkened(0.55))
				draw_circle(Vector2(dx, tt + 4 + len), 3.0, wax.darkened(0.55))
			if tier == 2 and _h(i, 9) > 0.45:
				_candles(Vector2(tx + tw * 0.5, tt - 2), 2 + int(_h(i, 10) * 2.0), c, 1, i + 40)


func _cave_near(c: Dictionary, span: Vector2) -> void:
	## Stalactites, drip columns and (in the garden) hanging roots.
	var near: Color = c["near"]
	var wax: Color = c.get("wax", Color("cdb88e"))
	var th := _theme()
	var gap := 430.0
	var n := int(span.x / gap) + 2
	var dens := float(c.get("near_density", 1.0))   # a gilt secret's near layer at half (spec §11.4)
	for i in n:
		if dens < 1.0 and _h(i, 31) >= dens:
			continue
		var x := i * gap + _h(i, 5) * 140.0
		var w := 46.0 + _h(i, 1) * 40.0
		if _h(i, 7) > 0.62:
			# A full column: roof to floor, pinched in the middle.
			var pts := PackedVector2Array([Vector2(x - w, -60), Vector2(x + w, -60), Vector2(x + w * 0.35, span.y * 0.5),
					Vector2(x + w, span.y + 300), Vector2(x - w, span.y + 300), Vector2(x - w * 0.35, span.y * 0.5)])
			draw_colored_polygon(pts, near)
			draw_colored_polygon(PackedVector2Array([Vector2(x + w * 0.35, -60), Vector2(x + w, -60), Vector2(x + w * 0.35, span.y * 0.5),
					Vector2(x + w, span.y + 300), Vector2(x + w * 0.6, span.y + 300), Vector2(x + w * 0.15, span.y * 0.5)]), near.lightened(0.05))
		else:
			# A stalactite with a drip hanging at its point.
			var len := 90.0 + _h(i, 2) * 110.0
			var tip := Vector2(x + (_h(i, 3) - 0.5) * 20.0, len)
			draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.5, -60), Vector2(x + w * 0.5, -60), tip]), near)
			draw_colored_polygon(PackedVector2Array([Vector2(x + w * 0.1, -60), Vector2(x + w * 0.5, -60), tip]), near.lightened(0.05))
			draw_circle(tip + Vector2(0, 6), 3.5, wax.darkened(0.6))
			# And a stubby mound under it.
			var mw := 50.0 + _h(i, 4) * 40.0
			draw_colored_polygon(PackedVector2Array([Vector2(tip.x - mw, span.y + 300), Vector2(tip.x - mw * 0.3, span.y - 40.0 - _h(i, 8) * 60.0),
					Vector2(tip.x + mw * 0.2, span.y - 30.0 - _h(i, 9) * 40.0), Vector2(tip.x + mw, span.y + 300)]), near)
		if th == "garden" and _h(i, 11) > 0.3:
			# Roots hanging down, with pale leaves.
			var rx := x + 150.0 + _h(i, 12) * 80.0
			var pts2 := PackedVector2Array()
			var rl := 80.0 + _h(i, 13) * 120.0
			for k in 9:
				var y := -20.0 + k * rl / 8.0
				pts2.append(Vector2(rx + sin(k * 1.1 + i) * 8.0, y))
			draw_polyline(pts2, near.lightened(0.1), 3.0)
			for k in range(2, 9, 2):
				draw_colored_polygon(PackedVector2Array([pts2[k], pts2[k] + Vector2(-10, 3), pts2[k] + Vector2(-4, -3)]), near.lightened(0.16))
		elif th != "garden" and _h(i, 14) > 0.5:
			# Wax strings hanging from the roof.
			var sx := x + 170.0 + _h(i, 15) * 90.0
			for k in 3:
				var l2 := 30.0 + _h(i, k + 16) * 70.0
				draw_line(Vector2(sx + k * 9.0, -20), Vector2(sx + k * 9.0, l2), wax.darkened(0.62), 3.0)
				draw_circle(Vector2(sx + k * 9.0, l2), 3.5, wax.darkened(0.62))
