extends RefCounted
## World 3's backdrop style, the Bone Orchard (A1; p_artaudio 4.1). The style
## contract (contract.md 12.4): draw() paints one 1024 px slice of one layer,
## rects with slice.draw_rect and the rest into tb (backdrop_layer.gd flushes
## it); windows() lists the glowing bits, computed at build. No draw_circle /
## draw_colored_polygon / draw_polyline.
## Each slice paints exactly its own strip [x0, x1) of the whole layer: every
## element that reaches into it (anchors from x0 - OVER to x1 + OVER), its
## rects cut to the strip (Strip) and its triangles clipped to it
## (clip_strip). The slices are siblings, so an element left to overhang into
## the next slice would be painted over by that slice's sky or wall: cut in
## half at every seam (test_world_art.gd checks the slices add up to the whole
## layer). clockwork.gd uses the same two helpers.
## The theme's "variant" picks the set (else orchard):
##            far (0.12)                  mid (0.35)                   near (0.65)
##   orchard  a pale haze moon, bone      an ossuary wall of skull     hanging roots and vines,
##            trees (femur trunks, rib    niches, roots threading it,  rib arches framing the view
##            branches, skull fruit)      a skull lantern every 700 px
##   rootvault vaults choked with root    niches packed close, coffins thick root pillars
##            curtains, one moon in a     stacked end-on, cobweb roots
##            broken oculus
##   sporewood giant mushroom caps,       rows of stalks, a haze band  hanging moss strands
##            every other one glowing
##   rootheart root masses, and the heart- root walls ribbed like a    thick roots with bone
##            knot round a buried bell    ribcage                      knuckles
##            (toward the level's end,
##            over the arena)
## Everything stays at or under the layer's own colour (a small lighter edge
## at most), so the tiles keep their contrast (test_world_art.gd).
## Composition: with the hero on the floor the camera sits about 225 px down
## (world.gd's BELOW), so a layer shows from y = 0.12 x 225 (far) and
## 0.35 x 225 (mid) down. The mid walls start at WALL of the layer's height
## (at the floor, about the screen's top fifth), and the far set pieces (the
## moons, the bone trees' crowns, the oculus, the heart-knot and its bell)
## sit in the band above them, so every window's light comes from something
## you can see.

const MOON_EVERY := 1400.0
const TREE_EVERY := 420.0
const NICHE_EVERY := 64.0
const LANTERN_EVERY := 700.0
const HANG_EVERY := 150.0
const RIB_EVERY := 520.0
const CAP_EVERY := 330.0
const WALL := {"orchard": 0.38, "rootvault": 0.36, "rootheart": 0.38}   # the mid wall's top, x span.y
const OVER := 360.0              # the farthest an element reaches from its anchor (the wall's root threads: 322)


static func _h(i: int, salt: int = 0) -> float:
	var h := (i * 2654435761 + salt * 40503) & 0x7fffffff
	return float(h % 10000) / 10000.0


class Strip:
	## The slice as the drawing sees it: draw_rect cuts every rect to [x0, x1).
	var ci
	var x0 := 0.0
	var x1 := 0.0

	func _init(p_ci, p_x0: float, p_x1: float) -> void:
		ci = p_ci
		x0 = p_x0
		x1 = p_x1

	func draw_rect(r: Rect2, col: Color) -> void:
		var rr := r.abs()
		var a := maxf(rr.position.x, x0)
		var b := minf(rr.end.x, x1)
		if b > a:
			ci.draw_rect(Rect2(a, rr.position.y, b - a, rr.size.y), col)


static func _cut(pa: Vector2, pb: Vector2, ca: Color, cb: Color, x: float, out_p: PackedVector2Array, out_c: PackedColorArray) -> void:
	var t := (x - pa.x) / (pb.x - pa.x)
	out_p.append(Vector2(x, lerpf(pa.y, pb.y, t)))
	out_c.append(ca.lerp(cb, t))


static func _clip_side(pp: PackedVector2Array, pc: PackedColorArray, x: float, keep_right: bool) -> Array:
	## One Sutherland-Hodgman pass: the polygon's part at or right of x (or left).
	var op := PackedVector2Array()
	var oc := PackedColorArray()
	var n := pp.size()
	for k in n:
		var a := pp[k]
		var b := pp[(k + 1) % n]
		var ina := a.x >= x if keep_right else a.x <= x
		var inb := b.x >= x if keep_right else b.x <= x
		if ina:
			op.append(a)
			oc.append(pc[k])
			if not inb:
				_cut(a, b, pc[k], pc[(k + 1) % n], x, op, oc)
		elif inb:
			_cut(a, b, pc[k], pc[(k + 1) % n], x, op, oc)
	return [op, oc]


static func clip_strip(tb, x0: float, x1: float, i_from := 0) -> void:
	## Clips the batch's triangles from index i_from on to the strip x0 <= x <= x1
	## (a crossing triangle becomes the fan of its clipped part, its corner
	## colours interpolated), and drops the vertices nothing uses any more.
	var pts: PackedVector2Array = tb.points
	var cols: PackedColorArray = tb.colors
	var idx: PackedInt32Array = tb.indices
	var n := pts.size()
	var side := PackedByteArray()
	side.resize(n)
	for i in n:
		var x := pts[i].x
		side[i] = 1 if x < x0 else (2 if x > x1 else 0)
	var remap := PackedInt32Array()
	remap.resize(n)
	remap.fill(-1)
	var np := PackedVector2Array()
	var nc := PackedColorArray()
	var ni := PackedInt32Array()
	for t in range(0, i_from):
		var v := idx[t]
		if remap[v] < 0:
			remap[v] = np.size()
			np.append(pts[v])
			nc.append(cols[v])
		ni.append(remap[v])
	var t := i_from
	var m := idx.size()
	while t < m:
		var a := idx[t]
		var b := idx[t + 1]
		var c := idx[t + 2]
		t += 3
		var sa := side[a]
		var sb := side[b]
		var sc := side[c]
		if sa == 0 and sb == 0 and sc == 0:
			var ra := remap[a]
			if ra < 0:
				ra = np.size()
				remap[a] = ra
				np.append(pts[a])
				nc.append(cols[a])
			var rb := remap[b]
			if rb < 0:
				rb = np.size()
				remap[b] = rb
				np.append(pts[b])
				nc.append(cols[b])
			var rc := remap[c]
			if rc < 0:
				rc = np.size()
				remap[c] = rc
				np.append(pts[c])
				nc.append(cols[c])
			ni.append(ra)
			ni.append(rb)
			ni.append(rc)
			continue
		if sa == sb and sb == sc:
			continue
		var poly := [PackedVector2Array([pts[a], pts[b], pts[c]]), PackedColorArray([cols[a], cols[b], cols[c]])]
		if sa == 1 or sb == 1 or sc == 1:
			poly = _clip_side(poly[0], poly[1], x0, true)
		if (sa == 2 or sb == 2 or sc == 2) and (poly[0] as PackedVector2Array).size() >= 3:
			poly = _clip_side(poly[0], poly[1], x1, false)
		var pp: PackedVector2Array = poly[0]
		var pc: PackedColorArray = poly[1]
		if pp.size() < 3:
			continue
		var base := np.size()
		np.append_array(pp)
		nc.append_array(pc)
		for k in range(1, pp.size() - 1):
			ni.append(base)
			ni.append(base + k)
			ni.append(base + k + 1)
	tb.points = np
	tb.colors = nc
	tb.indices = ni


static func _each(every: float, x0: float, x1: float, off := 0.0) -> Array[int]:
	var out: Array[int] = []
	var i := ceili((x0 - off) / every)
	while i * every + off < x1:
		if i >= 0:
			out.append(i)
		i += 1
	return out


static func _arc(c: Vector2, rx: float, ry: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n + 1:
		var a := lerpf(a0, a1, float(k) / n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _wavy(x: float, y0: float, y1: float, amp: float, seed: float, n := 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n + 1:
		var t := float(k) / n
		pts.append(Vector2(x + sin(t * 5.0 + seed) * amp * t, lerpf(y0, y1, t)))
	return pts


static func _variant(colors: Dictionary) -> String:
	return str(colors.get("variant", "orchard"))


static func draw(slice, tb, layer_index: int, colors: Dictionary, span: Vector2, x0: float, x1: float) -> void:
	## The strip [x0, x1) of the layer: everything reaching into it, cut to it.
	var v := _variant(colors)
	var st := Strip.new(slice, x0, x1)
	var i_from: int = tb.indices.size()
	var a0 := x0 - OVER
	var a1 := x1 + OVER
	match layer_index:
		0:
			_far(st, tb, v, colors, span, a0, a1)
		1:
			_mid(st, tb, v, colors, span, a0, a1)
		2:
			_near(st, tb, v, colors, span, a0, a1)
	clip_strip(tb, x0, x1, i_from)


# ---------------------------------------------------------------- far

static func _far(slice, tb, v: String, c: Dictionary, span: Vector2, x0: float, x1: float) -> void:
	var sky: Color = c.get("sky", Color("0e0d0a"))
	var far: Color = c.get("far", Color("1a1914"))
	var bottom := span.y + 420.0
	slice.draw_rect(Rect2(x0, -200.0, x1 - x0, bottom + 200.0), sky)
	slice.draw_rect(Rect2(x0, span.y * 0.58, x1 - x0, bottom), sky.lerp(far, 0.45))
	for m in _moons(v, span):
		var p: Vector2 = m["center"]
		if p.x < x0 or p.x >= x1:
			continue
		var r: float = m["r"]
		var moon: Color = c.get("moon", Color("e8dcb0"))
		tb.circle(p, r + 10.0, far.lerp(moon, 0.10), 28)
		tb.circle(p, r, far.lerp(moon, 0.24), 28)
		tb.ellipse(p + Vector2(-r * 0.3, -r * 0.2), r * 0.22, r * 0.18, far.lerp(moon, 0.17), 12)
		tb.ellipse(p + Vector2(r * 0.35, r * 0.25), r * 0.16, r * 0.12, far.lerp(moon, 0.18), 10)
		if v == "rootvault":
			# the broken oculus round it
			tb.ring(p, r + 16.0, 18.0, far, 32)
			for k in 7:
				var a := TAU * k / 7.0 + 0.3
				var q := p + Vector2(cos(a), sin(a)) * (r + 7.0)
				tb.tri(q + Vector2(cos(a + 1.6), sin(a + 1.6)) * 9.0, q - Vector2(cos(a + 1.6), sin(a + 1.6)) * 9.0,
						q - Vector2(cos(a), sin(a)) * (10.0 + _h(k, 3) * 12.0), far)
		else:
			slice.draw_rect(Rect2(p.x - r * 1.6, p.y + r * 0.3, r * 3.2, 7.0), Color(sky.lerp(far, 0.6), 0.85))
	match v:
		"rootvault":
			_vaults(slice, tb, far, span, x0, x1)
		"sporewood":
			_caps(slice, tb, far, span, x0, x1)
		"rootheart":
			_root_masses(slice, tb, far, span, x0, x1, 300.0, 0.9)
			var hk := _heart_knot(span)
			if hk.x >= x0 and hk.x < x1:
				_draw_heart_knot(slice, tb, far, hk, span)
		_:
			_bone_trees(slice, tb, far, span, x0, x1)


static func _bone_trees(slice, tb, far: Color, span: Vector2, x0: float, x1: float) -> void:
	var bottom := span.y + 420.0
	for i in _each(TREE_EVERY, x0, x1, 180.0):
		var x := 180.0 + i * TREE_EVERY + (_h(i, 1) - 0.5) * 120.0
		var top := 44.0 + _h(i, 3) * 46.0
		var w := 14.0 + _h(i, 4) * 10.0
		var col := far.lightened(0.05)
		slice.draw_rect(Rect2(x - w * 0.5, top, w, bottom - top), col)
		# the femur's head: two knobs
		tb.ellipse(Vector2(x - w * 0.45, top), w * 0.62, w * 0.5, col, 12)
		tb.ellipse(Vector2(x + w * 0.45, top + 2.0), w * 0.58, w * 0.48, col, 12)
		# rib branches arcing out and down, skull fruit at their tips
		var nb := 3 + int(_h(i, 5) * 2.0)
		for b in nb:
			var side := -1.0 if b % 2 == 0 else 1.0
			var len := 60.0 + _h(i, 6 + b) * 50.0
			var lift := 30.0 + _h(i, 12 + b) * 40.0
			var base := Vector2(x + side * w * 0.3, top + 6.0 + b * 10.0)
			var ctr := base + Vector2(side * len * 0.5, 0.0)
			var pts := _arc(ctr, len * 0.5, lift, PI, TAU - 0.15, 7) if side > 0 else _arc(ctr, len * 0.5, lift, 0.0, -PI + 0.15, 7)
			tb.polyline(pts, 5.0 - b * 0.6, col)
			var tip := pts[pts.size() - 1]
			tb.line(tip, tip + Vector2(0, 10), 1.4, col)
			tb.ellipse(tip + Vector2(0, 17), 7.0, 6.2, col.lightened(0.04), 10)
			tb.rect(Rect2(tip + Vector2(-3.8, 15.5), Vector2(2.4, 2.4)), far.darkened(0.25))
			tb.rect(Rect2(tip + Vector2(1.4, 15.5), Vector2(2.4, 2.4)), far.darkened(0.25))


static func _vaults(slice, tb, far: Color, span: Vector2, x0: float, x1: float) -> void:
	var bottom := span.y + 420.0
	for i in _each(260.0, x0, x1):
		var x := i * 260.0
		var w := 220.0
		var top := 30.0 + _h(i) * 24.0
		slice.draw_rect(Rect2(x - 20.0, top, 40.0, bottom - top), far)
		# the pointed vault between this pier and the next
		var spring := top + 110.0
		var pts := PackedVector2Array([Vector2(x + 20.0, bottom)])
		pts.append_array(_arc(Vector2(x + 20.0 + w, spring), w, w * 0.8, PI, PI * 1.33, 8))
		pts.append_array(_arc(Vector2(x + 20.0, spring), w, w * 0.8, PI * 1.67, TAU, 8))
		pts.append(Vector2(x + 20.0 + w, bottom))
		tb.convex(pts, far.lightened(0.03))
		# root curtains hanging in it
		for k in 4:
			var rx := x + 50.0 + k * 45.0 + _h(i, k) * 20.0
			tb.polyline(_wavy(rx, spring - 60.0 + _h(i, k + 5) * 30.0, spring + 80.0 + _h(i, k + 9) * 90.0, 6.0, k + i), 3.0, far.darkened(0.12))


static func _caps(slice, tb, far: Color, span: Vector2, x0: float, x1: float) -> void:
	var bottom := span.y + 420.0
	for i in _each(CAP_EVERY, x0, x1, 120.0):
		var cap := _cap(i, span)
		var x: float = cap["x"]
		var top: float = cap["top"]
		var w: float = cap["w"]
		var col := far.lightened(0.04)
		var sw := 18.0 + _h(i, 4) * 20.0
		slice.draw_rect(Rect2(x - sw * 0.5, top, sw, bottom - top), far)
		# the cap: a half-ellipse, its gills underneath
		var rim := _arc(Vector2(x, top + 6.0), w * 0.5, w * 0.34, PI, TAU, 14)
		tb.fan(Vector2(x, top + 6.0), rim, col)
		slice.draw_rect(Rect2(x - w * 0.5, top + 2.0, w, 8.0), far.darkened(0.2))
		for g in 7:
			slice.draw_rect(Rect2(x - w * 0.42 + g * w * 0.13, top + 4.0, 2.0, 6.0), far.darkened(0.35))
		# pale spots on the cap
		for s in 3:
			tb.ellipse(Vector2(x + (_h(i, 20 + s) - 0.5) * w * 0.7, top - w * 0.12 - _h(i, 30 + s) * w * 0.12), 6.0, 3.6, col.lightened(0.05), 8)


static func _cap(i: int, span: Vector2) -> Dictionary:
	return {"x": 120.0 + i * CAP_EVERY + (_h(i, 1) - 0.5) * 90.0, "top": span.y * 0.34 + _h(i, 2) * 70.0, "w": 160.0 + _h(i, 3) * 100.0}


static func _root_masses(slice, tb, col: Color, span: Vector2, x0: float, x1: float, every: float, k: float) -> void:
	var bottom := span.y + 420.0
	for i in _each(every, x0, x1, 60.0):
		var x := 60.0 + i * every + (_h(i, 7) - 0.5) * 80.0
		var w := (40.0 + _h(i, 8) * 40.0) * k
		var pts := _wavy(x, -40.0, bottom, 24.0, i * 1.7, 10)
		tb.polyline(pts, w, col)
		tb.polyline(_wavy(x + w * 0.6, span.y * 0.2, bottom, 30.0, i * 2.3, 8), w * 0.45, col)


static func _heart_knot(span: Vector2) -> Vector2:
	## The heart-knot's centre: toward the level's end, over her arena.
	return Vector2(maxf(span.x - 520.0, 300.0), 76.0)


static func _draw_heart_knot(slice, tb, far: Color, c: Vector2, span: Vector2) -> void:
	var col := far.lightened(0.07)
	for k in 7:
		var r := 58.0 + k * 10.0
		var a0 := k * 0.9
		tb.polyline(_arc(c, r, r * 0.8, a0, a0 + PI * 1.4, 14), 10.0 - k * 0.8, col)
	# the buried bell in its heart
	var b := PackedVector2Array([c + Vector2(-17, -22), c + Vector2(17, -22), c + Vector2(26, 20), c + Vector2(-26, 20)])
	tb.convex(b, far.lightened(0.12))
	tb.ellipse(c + Vector2(0, -22), 17.0, 8.0, far.lightened(0.12), 12)
	tb.rect(Rect2(c + Vector2(-29, 18), Vector2(58, 4)), far.lightened(0.15))


# ---------------------------------------------------------------- mid

static func _mid(slice, tb, v: String, c: Dictionary, span: Vector2, x0: float, x1: float) -> void:
	var mid: Color = c.get("mid", Color("26241c"))
	var bottom := span.y + 420.0
	match v:
		"sporewood":
			for i in _each(90.0, x0, x1):
				var x := i * 90.0 + _h(i, 1) * 40.0
				var top := span.y * 0.3 + _h(i, 2) * 90.0
				var sw := 10.0 + _h(i, 3) * 8.0
				slice.draw_rect(Rect2(x - sw * 0.5, top, sw, bottom - top), mid.darkened(0.12))
				var cw := 34.0 + _h(i, 4) * 30.0
				tb.fan(Vector2(x, top + 3.0), _arc(Vector2(x, top + 3.0), cw * 0.5, cw * 0.3, PI, TAU, 10), mid.darkened(0.04))
			# a spore haze band, soft at both edges
			var hz := span.y * 0.5
			for k in 4:
				var a: float = [0.05, 0.1, 0.14, 0.1][k]
				slice.draw_rect(Rect2(x0, hz + k * 18.0, x1 - x0, 18.0), Color(mid.lightened(0.08), a))
			slice.draw_rect(Rect2(x0, hz + 72.0, x1 - x0, 24.0), Color(mid.darkened(0.3), 0.5))
			slice.draw_rect(Rect2(x0, hz + 96.0, x1 - x0, bottom), mid.darkened(0.3))
		"rootheart":
			var wt := wall_top(v, span)
			slice.draw_rect(Rect2(x0, wt, x1 - x0, bottom - wt), mid.darkened(0.3))
			for i in _each(180.0, x0, x1):
				var x := i * 180.0 + 60.0
				# a ribcage: a spine and curved ribs either side
				slice.draw_rect(Rect2(x - 5.0, wt + 20.0, 10.0, bottom), mid.darkened(0.06))
				for r in 5:
					var y := wt + 50.0 + r * 34.0
					for s in [-1.0, 1.0]:
						tb.polyline(_arc(Vector2(x + s * 30.0, y + 14.0), 30.0, 18.0, -PI * 0.5 - s * PI * 0.5, -PI * 0.5 + s * 0.2, 6), 5.0,
								mid.darkened(0.04))
			_threads(slice, tb, mid, span, x0, x1, wt)
		_:
			var wt2 := wall_top(v, span)
			slice.draw_rect(Rect2(x0, wt2, x1 - x0, bottom - wt2), mid.darkened(0.24))
			slice.draw_rect(Rect2(x0, wt2 - 6.0, x1 - x0, 8.0), mid.darkened(0.08))
			var every := NICHE_EVERY if v == "orchard" else 48.0
			var rows := 3 if v == "orchard" else 4
			for i in _each(every, x0, x1):
				for r in rows:
					if _h(i, 40 + r) < 0.2:
						continue
					var cx := i * every + every * 0.5 + (r % 2) * every * 0.25
					var cy := wt2 + 46.0 + r * 58.0
					_niche(slice, tb, mid, Vector2(cx, cy), 0.02 if v == "orchard" else 0.14)
			if v == "rootvault":
				for i in _each(210.0, x0, x1, 90.0):
					var x := 90.0 + i * 210.0
					var by := span.y * 0.72
					for k in 3:
						var cy2 := by - k * 24.0
						slice.draw_rect(Rect2(x - 20.0, cy2 - 20.0, 40.0, 20.0), mid.darkened(0.08))
						slice.draw_rect(Rect2(x - 20.0, cy2 - 20.0, 40.0, 3.0), mid.lightened(0.03))
						slice.draw_rect(Rect2(x - 3.0, cy2 - 16.0, 6.0, 12.0), mid.darkened(0.3))
				# cobweb roots
				for i in _each(330.0, x0, x1, 40.0):
					var o := Vector2(40.0 + i * 330.0, wt2 + 10.0)
					for k in 5:
						tb.line(o, o + Vector2(cos(0.3 + k * 0.6), sin(0.3 + k * 0.6)) * (50.0 + _h(i, k) * 30.0), 1.2, mid.darkened(0.02))
			_threads(slice, tb, mid, span, x0, x1, wt2)
			# a skull lantern every 700 px
			for w in _mid_lamps(v, span):
				var p: Vector2 = w["center"]
				if p.x < x0 or p.x >= x1:
					continue
				slice.draw_rect(Rect2(p.x - 2.0, p.y + 8.0, 4.0, 60.0), mid.darkened(0.08))
				tb.ellipse(p, 10.0, 9.0, mid.lightened(0.04), 12)
				tb.rect(Rect2(p + Vector2(-5.4, -1.4), Vector2(3.6, 3.4)), (w["colors"][0] as Color).darkened(0.25))
				tb.rect(Rect2(p + Vector2(1.8, -1.4), Vector2(3.6, 3.4)), (w["colors"][0] as Color).darkened(0.25))


static func wall_top(v: String, span: Vector2) -> float:
	## Where the mid layer turns opaque (its wall; the Sporewood's is under its
	## haze band): the far layer shows above it.
	if v == "sporewood":
		return span.y * 0.5 + 96.0
	return span.y * float(WALL.get(v, 0.38))


static func _niche(slice, tb, mid: Color, c: Vector2, dim := 0.02) -> void:
	slice.draw_rect(Rect2(c.x - 13.0, c.y - 6.0, 26.0, 22.0), mid.darkened(0.55))
	tb.ellipse(c + Vector2(0, -6), 13.0, 9.0, mid.darkened(0.55), 10)
	tb.ellipse(c + Vector2(0, 3), 7.4, 6.6, mid.darkened(dim), 10)
	tb.rect(Rect2(c + Vector2(-4.4, 1.0), Vector2(3.0, 2.8)), mid.darkened(0.6))
	tb.rect(Rect2(c + Vector2(1.4, 1.0), Vector2(3.0, 2.8)), mid.darkened(0.6))


static func _threads(slice, tb, mid: Color, span: Vector2, x0: float, x1: float, wt: float) -> void:
	## Roots threading across the wall.
	for i in _each(300.0, x0, x1):
		var x := i * 300.0
		var y := wt + 30.0 + _h(i, 50) * (span.y * 0.5)
		var pts := PackedVector2Array()
		for k in 9:
			pts.append(Vector2(x + k * 40.0, y + sin(k * 1.3 + i) * 14.0))
		tb.polyline(pts, 4.0, mid.darkened(0.1))
		var hp := PackedVector2Array()
		for q in pts:
			hp.append(q + Vector2(0, -1.4))
		tb.polyline(hp, 1.0, mid.darkened(0.02))


static func _mid_lamps(v: String, span: Vector2) -> Array:
	var out := []
	if v != "orchard" and v != "rootvault":
		return out
	var i := 0
	var x := 350.0
	var wt := wall_top(v, span)
	while x < span.x + 100.0:
		out.append({"center": Vector2(x, wt + 22.0), "colors": [Color("ffc870")]})
		x += LANTERN_EVERY
		i += 1
	return out


# ---------------------------------------------------------------- near

static func _near(slice, tb, v: String, c: Dictionary, span: Vector2, x0: float, x1: float) -> void:
	var near: Color = c.get("near", Color("12110c"))
	var bottom := span.y + 420.0
	match v:
		"rootvault":
			for i in _each(420.0, x0, x1, 100.0):
				var x := 100.0 + i * 420.0 + _h(i, 1) * 90.0
				var w := 54.0 + _h(i, 2) * 30.0
				var pts := _wavy(x, -60.0, bottom, 18.0, i * 1.9, 10)
				tb.polyline(pts, w, near)
				tb.polyline(_wavy(x + w * 0.35, -60.0, bottom, 18.0, i * 1.9, 10), 3.0, near.lightened(0.05))
				for k in 3:
					tb.ellipse(pts[2 + k * 3], w * 0.36, w * 0.24, near.lightened(0.02), 10)
		"sporewood":
			for i in _each(110.0, x0, x1):
				var x := i * 110.0 + _h(i, 1) * 50.0
				if _h(i, 2) < 0.3:
					continue
				for k in 2 + int(_h(i, 3) * 2.0):
					var sx := x + k * 9.0
					var ln := 60.0 + _h(i, 4 + k) * 170.0
					tb.line(Vector2(sx, -20.0), Vector2(sx + 3.0, ln), 1.6, near.lightened(0.04))
					tb.circle(Vector2(sx + 3.0, ln + 2.0), 2.4, near.lightened(0.07), 6)
			_hanging(slice, tb, near, span, x0, x1, 0.5)
		"rootheart":
			for i in _each(380.0, x0, x1, 150.0):
				var x := 150.0 + i * 380.0 + _h(i, 1) * 90.0
				var w := 60.0 + _h(i, 2) * 30.0
				var pts := _wavy(x, -60.0, bottom, 26.0, i * 2.1, 10)
				tb.polyline(pts, w, near)
				for k in 3:
					var q := pts[2 + k * 3]
					tb.ellipse(q + Vector2(w * 0.1, 0), 10.0, 7.0, near.lightened(0.09), 10)
					tb.ellipse(q + Vector2(w * 0.1 + 12.0, 2.0), 7.0, 5.0, near.lightened(0.09), 8)
			_hanging(slice, tb, near, span, x0, x1, 0.6)
		_:
			_hanging(slice, tb, near, span, x0, x1, 1.0)
			for i in _each(RIB_EVERY, x0, x1, 260.0):
				var x := 260.0 + i * RIB_EVERY + (_h(i, 7) - 0.5) * 100.0
				var r := 170.0 + _h(i, 8) * 40.0
				var pts := _arc(Vector2(x + r * 0.9, bottom - 120.0), r * 0.9, bottom - 40.0, PI, PI * 1.5, 12)
				tb.polyline(pts, 20.0, near)
				var hl := PackedVector2Array()
				for q in pts:
					hl.append(q + Vector2(-7, 0))
				tb.polyline(hl, 2.0, near.lightened(0.05))
				tb.ellipse(pts[0] + Vector2(0, -6), 16.0, 12.0, near, 12)


static func _hanging(slice, tb, near: Color, span: Vector2, x0: float, x1: float, k: float) -> void:
	## Hanging roots and vines with leaves.
	for i in _each(HANG_EVERY, x0, x1, 40.0):
		if _h(i, 60) > k:
			continue
		var x := 40.0 + i * HANG_EVERY + _h(i, 61) * 70.0
		var ln := span.y * 0.25 + _h(i, 62) * span.y * 0.45
		var pts := _wavy(x, -30.0, ln, 10.0, i * 1.1, 9)
		tb.polyline(pts, 5.0, near)
		for q in range(2, pts.size() - 1, 2):
			var p := pts[q]
			var d := 1.0 if q % 4 == 0 else -1.0
			tb.tri(p, p + Vector2(d * 12.0, -4.0), p + Vector2(d * 7.0, 4.0), near.lightened(0.04))


# ---------------------------------------------------------------- windows

static func _moons(v: String, span: Vector2) -> Array:
	var out := []
	if v == "rootvault":
		out.append({"center": Vector2(maxf(span.x * 0.45, 300.0), 70.0), "r": 42.0})
		return out
	if v != "orchard":
		return out
	var i := 0
	var x := 520.0
	while x < span.x + 100.0:
		out.append({"center": Vector2(x + (_h(i, 90) - 0.5) * 200.0, 64.0 + _h(i, 91) * 14.0), "r": 50.0})
		x += MOON_EVERY
		i += 1
	return out


static func windows(layer_index: int, colors: Dictionary, span: Vector2) -> Array:
	## The haze moons and the heart-knot's bell (far), the glowing caps (far,
	## sporewood), the skull lanterns (mid): decorative, tinted lights.
	var v := _variant(colors)
	var out := []
	var glass: Array = colors.get("glass", [Color("d8d0a0")])
	match layer_index:
		0:
			var moon: Color = colors.get("moon", Color("e8dcb0"))
			for m in _moons(v, span):
				out.append({"rose": true, "center": m["center"], "radius": float(m["r"]) * 0.7, "s": 0.35,
						"tint": Color(moon, 0.5), "colors": glass})
			if v == "sporewood":
				var i := 0
				while 120.0 + i * CAP_EVERY < span.x + 200.0:
					if i % 2 == 1:
						var cap := _cap(i, span)
						out.append({"rose": true, "center": Vector2(cap["x"], float(cap["top"]) + 12.0), "radius": 26.0, "s": 0.32,
								"tint": Color(glass[i % glass.size()], 0.55), "colors": glass})
					i += 1
			if v == "rootheart":
				out.append({"rose": true, "center": _heart_knot(span), "radius": 28.0, "s": 0.4,
						"tint": Color(Color("f2b84b"), 0.4), "colors": glass})
		1:
			for w in _mid_lamps(v, span):
				out.append({"rose": true, "center": w["center"], "radius": 14.0, "s": 0.45, "colors": w["colors"]})
	return out
