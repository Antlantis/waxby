extends RefCounted
## World 4's backdrop style, the Frozen Carillon (A1; p_artaudio 4.2). The
## style contract (contract.md 12.4): draw() paints one 1024 px slice of one
## layer, rects with slice.draw_rect, the rest into tb; windows() lists the
## glowing bits at build. No draw_circle / draw_colored_polygon /
## draw_polyline. Like orchard.gd, each slice paints exactly its own strip
## [x0, x1): everything reaching into it, cut to it (orchard.gd's Strip and
## clip_strip), so nothing is cut in half at a seam. The mid walls start at
## WALL of the layer's height and the far set pieces (the face, the gears'
## hubs, the bells, the louvres, the wheel) sit in the band above them, the
## band the far layer shows with the hero on the floor (see orchard.gd).
## The theme's "variant" picks the set:
##             far (0.12)                   mid (0.35)                  near (0.65)
##   clockface  the great clock face from    the tower wall: louvred     icicle curtains, brass
##              behind, lit from outside,    windows, girders, frozen    pipes, gear-tooth
##              every 1600 px, and towers    chains, bell niches         fragments
##   gearworks  huge still gear silhouettes  crossed girders and belts,  chains and hooks
##              and chains                   brass lamps (warm windows)
##   icebells   frozen bells in rows with    ice-sheathed beams          long, dense icicles
##              icicle beards, moonlight
##              through louvres
##   escapement the great escapement wheel   workbenches of little       springs and tools on
##              and its anchor, a giant      clocks, all stopped at the  hooks
##              pendulum hanging still       same minute
## Nothing that reads as a clock is on screen in the Tinker's arena (4-4's
## own clock is the boss's: its hand is gameplay): no escape wheel or
## pendulum reaches the far layer's last ARENA_FAR px, and the benches'
## little clocks there have no hands (the mid layer's last ARENA_MID px).
## No gear has the grinder rim (the Spurwheel's). Colours stay at or under
## each layer's own.

const Clip := preload("res://scripts/backdrops/orchard.gd")
const FACE_EVERY := 1600.0
const GEAR_EVERY := 380.0
const BELL_EVERY := 220.0
const WALL := 0.38               # the mid wall's top, x span.y
const OVER := 360.0              # the farthest an element reaches from its anchor (the wheel's pendulum: 250)
const WHEEL_R := 90.0
const WHEEL_REACH := Vector2(100.0, 250.0)   # left of the wheel's centre (its teeth), right (the pendulum's bob)
const ARENA_FAR := 1000.0        # the far layer's last px: what shows over the Tinker's arena
const ARENA_MID := 1400.0        # and the mid layer's


static func _h(i: int, salt: int = 0) -> float:
	var h := (i * 2654435761 + salt * 40503) & 0x7fffffff
	return float(h % 10000) / 10000.0


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


static func _gear(tb, c: Vector2, r: float, teeth: int, col: Color, hole: Color, rot := 0.0) -> void:
	var rim := PackedVector2Array()
	var ri := r * 0.86
	for k in teeth:
		var a0 := rot + TAU * k / teeth
		var st := TAU / teeth
		for fr in [[0.0, ri], [0.2, ri], [0.3, r], [0.6, r], [0.7, ri]]:
			var a: float = a0 + st * float(fr[0])
			rim.append(c + Vector2(cos(a), sin(a)) * float(fr[1]))
	tb.fan(c, rim, col)
	tb.ring(c, r * 0.52, r * 0.1, hole, 20)
	for q in 4:
		var a := rot + TAU * q / 4.0 + 0.4
		tb.fan(c, _arc(c, r * 0.62, r * 0.62, a, a + 0.9, 5), hole)
	tb.circle(c, r * 0.14, col, 12)


static func _variant(colors: Dictionary) -> String:
	return str(colors.get("variant", "clockface"))


static func draw(slice, tb, layer_index: int, colors: Dictionary, span: Vector2, x0: float, x1: float) -> void:
	## The strip [x0, x1) of the layer: everything reaching into it, cut to it.
	var v := _variant(colors)
	var st = Clip.Strip.new(slice, x0, x1)
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
	Clip.clip_strip(tb, x0, x1, i_from)


# ---------------------------------------------------------------- far

static func _far(slice, tb, v: String, c: Dictionary, span: Vector2, x0: float, x1: float) -> void:
	var sky: Color = c.get("sky", Color("0a0e1a"))
	var far: Color = c.get("far", Color("141c30"))
	var bottom := span.y + 420.0
	slice.draw_rect(Rect2(x0, -200.0, x1 - x0, bottom + 200.0), sky)
	slice.draw_rect(Rect2(x0, span.y * 0.6, x1 - x0, bottom), sky.lerp(far, 0.4))
	match v:
		"gearworks":
			for i in _each(GEAR_EVERY, x0, x1, 150.0):
				var cx := 150.0 + i * GEAR_EVERY + (_h(i, 1) - 0.5) * 120.0
				var r := 84.0 + _h(i, 2) * 56.0
				var cy := 52.0 + _h(i, 3) * 70.0
				_gear(tb, Vector2(cx, cy), r, 14 + int(_h(i, 4) * 8.0), far.lightened(0.04), sky.lerp(far, 0.3), _h(i, 5))
				# a chain hanging from the dark
				var chx := cx + r * 0.9
				var y := -10.0
				while y < cy - r * 0.2:
					tb.ring(Vector2(chx, y), 4.0, 1.8, far.lightened(0.02), 8)
					y += 9.0
		"icebells":
			slice.draw_rect(Rect2(x0, 26.0, x1 - x0, 7.0), far.lightened(0.02))
			for i in _each(BELL_EVERY, x0, x1, 60.0):
				var bx := 60.0 + i * BELL_EVERY
				var by := 34.0 + (i % 2) * 40.0
				var bw := 46.0 + _h(i, 1) * 22.0
				slice.draw_rect(Rect2(bx - 2.0, 29.0, 4.0, by - 29.0), far)
				var body := PackedVector2Array([Vector2(bx - bw * 0.32, by), Vector2(bx + bw * 0.32, by), Vector2(bx + bw * 0.5, by + bw * 0.9),
						Vector2(bx - bw * 0.5, by + bw * 0.9)])
				tb.convex(body, far.lightened(0.05))
				tb.ellipse(Vector2(bx, by), bw * 0.32, bw * 0.16, far.lightened(0.05), 12)
				slice.draw_rect(Rect2(bx - bw * 0.56, by + bw * 0.86, bw * 1.12, 6.0), far.lightened(0.08))
				for k in 5:
					var ix := bx - bw * 0.46 + k * bw * 0.23
					tb.tri(Vector2(ix - 3.0, by + bw * 0.9 + 5.0), Vector2(ix + 3.0, by + bw * 0.9 + 5.0),
							Vector2(ix, by + bw * 0.9 + 12.0 + _h(i, 10 + k) * 16.0), far.lightened(0.07))
			for w in _louvres(span):
				var r2: Rect2 = w["rect"]
				if r2.get_center().x < x0 or r2.get_center().x >= x1:
					continue
				slice.draw_rect(r2, far.lerp(Color("c0c8f0"), 0.12))
				for k in 7:
					slice.draw_rect(Rect2(r2.position.x, r2.position.y + 6.0 + k * r2.size.y / 7.0, r2.size.x, 5.0), far.darkened(0.1))
		"escapement":
			for w in _wheels(span):
				var p: Vector2 = w["center"]
				if p.x < x0 or p.x >= x1:
					continue
				var r: float = w["r"]
				var col := far.lightened(0.05)
				var bob := Vector2(p.x + r + 120.0, w["bob_y"])
				# the escape wheel: hooked teeth
				var rim := PackedVector2Array()
				var n := 24
				for k in n:
					var a := TAU * k / n
					rim.append(p + Vector2(cos(a), sin(a)) * r * 0.84)
					rim.append(p + Vector2(cos(a + 0.05), sin(a + 0.05)) * r)
					rim.append(p + Vector2(cos(a + 0.2), sin(a + 0.2)) * r * 0.86)
				tb.fan(p, rim, col)
				tb.ring(p, r * 0.5, r * 0.12, sky.lerp(far, 0.3), 24)
				tb.circle(p, r * 0.12, col, 12)
				# the anchor over it
				var ap := p + Vector2(0, -r - 16.0)
				tb.polyline(PackedVector2Array([ap + Vector2(-r * 0.7, 40.0), ap, ap + Vector2(r * 0.7, 40.0)]), 14.0, col)
				tb.circle(ap, 12.0, col, 12)
				# a giant pendulum hanging still beside it
				slice.draw_rect(Rect2(bob.x - 3.0, -20.0, 6.0, bob.y + 20.0), col)
				tb.circle(bob, 34.0, col, 20)
				tb.ring(bob, 24.0, 3.0, far.lightened(0.09), 20)
		_:
			for i in _each(260.0, x0, x1, 80.0):
				var tx := 80.0 + i * 260.0 + _h(i, 1) * 60.0
				var tw := 50.0 + _h(i, 2) * 40.0
				var top := 56.0 + _h(i, 3) * 70.0
				slice.draw_rect(Rect2(tx - tw * 0.5, top, tw, bottom - top), far)
				tb.tri(Vector2(tx - tw * 0.6, top + 2.0), Vector2(tx + tw * 0.6, top + 2.0), Vector2(tx, top - tw * 0.8), far)
			for f in _faces(span):
				var p: Vector2 = f["center"]
				if p.x < x0 or p.x >= x1:
					continue
				var r: float = f["r"]
				tb.circle(p, r + 9.0, far.lightened(0.03), 36)
				tb.circle(p, r, far.lerp(Color("f4f0e0"), 0.14), 36)
				tb.ring(p, r - 5.0, 2.6, far.lightened(0.07), 36)
				for k in 12:
					var a := TAU * k / 12.0
					var d := Vector2(cos(a), sin(a))
					var o := d.orthogonal() * (3.4 if k % 3 == 0 else 1.9)
					var r0 := r - (20.0 if k % 3 == 0 else 15.0)
					tb.quad(p + d * r0 + o, p + d * (r - 9.0) + o, p + d * (r - 9.0) - o, p + d * r0 - o, far.lightened(0.04))
				# the hands, seen from behind (mirrored), stopped
				for h in [[-0.9, r * 0.5, 6.0], [2.2, r * 0.72, 4.2]]:
					var a2: float = h[0]
					var tip: Vector2 = p + Vector2(cos(a2), sin(a2)) * float(h[1])
					tb.line(p, tip, float(h[2]), far.lightened(0.02))
				tb.circle(p, 6.0, far.lightened(0.04), 12)


# ---------------------------------------------------------------- mid

static func _mid(slice, tb, v: String, c: Dictionary, span: Vector2, x0: float, x1: float) -> void:
	var mid: Color = c.get("mid", Color("1e2a44"))
	var bottom := span.y + 420.0
	var wt := wall_top(v, span)
	slice.draw_rect(Rect2(x0, wt, x1 - x0, bottom - wt), mid.darkened(0.28))
	match v:
		"gearworks":
			for i in _each(240.0, x0, x1):
				var x := i * 240.0
				slice.draw_rect(Rect2(x - 9.0, wt - 20.0, 18.0, bottom), mid.darkened(0.08))
				# a crossed truss to the next post
				var a := Vector2(x + 9.0, wt + 40.0)
				var b := Vector2(x + 231.0, wt + 140.0)
				tb.line(a, b, 6.0, mid.darkened(0.12))
				tb.line(Vector2(a.x, b.y), Vector2(b.x, a.y), 6.0, mid.darkened(0.12))
				slice.draw_rect(Rect2(x, wt + 36.0, 240.0, 8.0), mid.darkened(0.06))
				slice.draw_rect(Rect2(x, wt + 136.0, 240.0, 8.0), mid.darkened(0.06))
			for i in _each(470.0, x0, x1, 120.0):
				# a belt between two wheels
				var ax := 120.0 + i * 470.0
				var ay := span.y * 0.62
				var bxx := ax + 200.0
				var byy := ay - 60.0
				tb.circle(Vector2(ax, ay), 26.0, mid.darkened(0.04), 16)
				tb.circle(Vector2(bxx, byy), 18.0, mid.darkened(0.04), 14)
				tb.line(Vector2(ax, ay - 26.0), Vector2(bxx, byy - 18.0), 4.0, mid.darkened(0.16))
				tb.line(Vector2(ax, ay + 26.0), Vector2(bxx, byy + 18.0), 4.0, mid.darkened(0.16))
			for w in _lamps(v, span):
				var p: Vector2 = w["center"]
				if p.x < x0 or p.x >= x1:
					continue
				slice.draw_rect(Rect2(p.x - 1.5, wt - 20.0, 3.0, p.y - wt + 12.0), mid.darkened(0.1))
				tb.ellipse(p, 6.0, 8.0, mid.lightened(0.04), 10)
				slice.draw_rect(Rect2(p.x - 5.0, p.y - 11.0, 10.0, 3.0), mid.darkened(0.05))
		"icebells":
			for i in _each(200.0, x0, x1):
				var x := i * 200.0
				var y := wt + 30.0 + _h(i, 1) * 90.0
				var a := Vector2(x, y)
				var b := Vector2(x + 200.0, y + (_h(i, 2) - 0.5) * 80.0)
				tb.line(a, b, 12.0, mid.darkened(0.1))
				tb.line(a + Vector2(0, -5.5), b + Vector2(0, -5.5), 2.5, mid.lightened(0.05))
				for k in 5:
					var q := a.lerp(b, (k + 0.5) / 5.0) + Vector2(0, 5.0)
					tb.tri(q + Vector2(-3, 0), q + Vector2(3, 0), q + Vector2(0, 8.0 + _h(i, 3 + k) * 14.0), mid.darkened(0.02))
		"escapement":
			for i in _each(260.0, x0, x1, 70.0):
				var x := 70.0 + i * 260.0
				var ty := span.y * 0.64
				slice.draw_rect(Rect2(x, ty, 150.0, 8.0), mid.darkened(0.04))
				slice.draw_rect(Rect2(x + 8.0, ty + 8.0, 7.0, 80.0), mid.darkened(0.14))
				slice.draw_rect(Rect2(x + 135.0, ty + 8.0, 7.0, 80.0), mid.darkened(0.14))
				# little clocks on the bench and on a shelf above, all at the same stopped minute
				var hands := x + 150.0 < span.x - ARENA_MID
				for k in 3:
					_little_clock(tb, Vector2(x + 28.0 + k * 46.0, ty - 12.0 - (k % 2) * 4.0), 10.0 + (k % 2) * 3.0, mid, hands)
				slice.draw_rect(Rect2(x + 20.0, ty - 90.0, 110.0, 5.0), mid.darkened(0.06))
				for k in 2:
					_little_clock(tb, Vector2(x + 50.0 + k * 50.0, ty - 102.0), 9.0, mid, hands)
		_:
			for i in _each(300.0, x0, x1, 120.0):
				var x := 120.0 + i * 300.0
				# a louvred window
				var r := Rect2(x - 26.0, wt + 40.0, 52.0, 100.0)
				slice.draw_rect(r, mid.darkened(0.5))
				tb.ellipse(Vector2(x, r.position.y), 26.0, 18.0, mid.darkened(0.5), 14)
				for k in 6:
					slice.draw_rect(Rect2(r.position.x, r.position.y + 6.0 + k * 15.0, r.size.x, 6.0), mid.darkened(0.2))
				# a bell niche beside it
				var nx := x + 130.0
				slice.draw_rect(Rect2(nx - 18.0, wt + 90.0, 36.0, 50.0), mid.darkened(0.45))
				tb.ellipse(Vector2(nx, wt + 90.0), 18.0, 12.0, mid.darkened(0.45), 12)
				tb.convex(PackedVector2Array([Vector2(nx - 7, wt + 96), Vector2(nx + 7, wt + 96), Vector2(nx + 11, wt + 118), Vector2(nx - 11, wt + 118)]),
						mid.darkened(0.08))
			slice.draw_rect(Rect2(x0, wt + 16.0, x1 - x0, 10.0), mid.darkened(0.08))
			slice.draw_rect(Rect2(x0, wt + 16.0, x1 - x0, 2.0), mid.lightened(0.04))
			for i in _each(250.0, x0, x1, 40.0):
				var chx := 40.0 + i * 250.0 + _h(i, 4) * 60.0
				var y := wt + 26.0
				var ln := 60.0 + _h(i, 5) * 120.0
				while y < wt + 26.0 + ln:
					tb.ring(Vector2(chx, y), 3.6, 1.6, mid.darkened(0.04), 8)
					y += 8.0


static func _little_clock(tb, c: Vector2, r: float, mid: Color, hands := true) -> void:
	tb.circle(c, r + 2.0, mid.darkened(0.1), 14)
	tb.circle(c, r, mid.lightened(0.06), 14)
	if not hands:
		# over the Tinker's arena: faces with their hands taken
		tb.circle(c, r * 0.16, mid.darkened(0.3), 8)
		return
	# 11:57, every one of them
	tb.line(c, c + Vector2(cos(-PI * 0.5 - 0.1), sin(-PI * 0.5 - 0.1)) * r * 0.55, 1.8, mid.darkened(0.3))
	tb.line(c, c + Vector2(cos(-PI * 0.5 - 0.3), sin(-PI * 0.5 - 0.3)) * r * 0.8, 1.2, mid.darkened(0.3))


# ---------------------------------------------------------------- near

static func _near(slice, tb, v: String, c: Dictionary, span: Vector2, x0: float, x1: float) -> void:
	var near: Color = c.get("near", Color("0e1528"))
	var bottom := span.y + 420.0
	match v:
		"gearworks":
			_chains(tb, near, span, x0, x1, 170.0, true)
		"escapement":
			for i in _each(190.0, x0, x1, 50.0):
				var x := 50.0 + i * 190.0 + _h(i, 1) * 50.0
				var ln := 40.0 + _h(i, 2) * 90.0
				tb.line(Vector2(x, -20.0), Vector2(x, ln), 2.0, near.lightened(0.04))
				if _h(i, 3) > 0.5:
					# a coil spring
					var pts := PackedVector2Array()
					for k in 13:
						pts.append(Vector2(x + (8.0 if k % 2 == 0 else -8.0), ln + k * 6.0))
					tb.polyline(pts, 2.4, near.lightened(0.05))
				else:
					# a wrench
					tb.line(Vector2(x, ln), Vector2(x, ln + 60.0), 6.0, near.lightened(0.05))
					tb.ring(Vector2(x, ln + 66.0), 8.0, 4.0, near.lightened(0.05), 12)
			_icicles(tb, near, span, x0, x1, 0.35, 90.0)
		"icebells":
			_icicles(tb, near, span, x0, x1, 1.0, 180.0)
		_:
			_icicles(tb, near, span, x0, x1, 0.7, 140.0)
			for i in _each(450.0, x0, x1, 200.0):
				var x := 200.0 + i * 450.0 + _h(i, 1) * 80.0
				slice.draw_rect(Rect2(x - 7.0, -40.0, 14.0, bottom + 40.0), near.lightened(0.03))
				for k in 4:
					slice.draw_rect(Rect2(x - 10.0, 60.0 + k * 110.0, 20.0, 8.0), near.lightened(0.06))
			for i in _each(330.0, x0, x1, 90.0):
				if _h(i, 5) < 0.5:
					continue
				var p := Vector2(90.0 + i * 330.0, span.y * 0.7 + _h(i, 6) * 60.0)
				_gear(tb, p, 26.0, 10, near.lightened(0.03), near.darkened(0.2), _h(i, 7))


static func _icicles(tb, near: Color, span: Vector2, x0: float, x1: float, k: float, max_len: float) -> void:
	for i in _each(24.0, x0, x1):
		if _h(i, 80) > k:
			continue
		var x := i * 24.0 + _h(i, 81) * 12.0
		var ln := 20.0 + _h(i, 82) * max_len
		var w := 5.0 + _h(i, 83) * 7.0
		tb.tri(Vector2(x - w, -30.0), Vector2(x + w, -30.0), Vector2(x + 1.0, ln), near.lightened(0.05))
		tb.line(Vector2(x - w * 0.3, -30.0), Vector2(x, ln * 0.7), 1.0, near.lightened(0.1))


static func _chains(tb, near: Color, span: Vector2, x0: float, x1: float, every: float, hooks: bool) -> void:
	for i in _each(every, x0, x1, 30.0):
		var x := 30.0 + i * every + _h(i, 1) * 60.0
		var ln := 60.0 + _h(i, 2) * span.y * 0.45
		var y := -20.0
		while y < ln:
			tb.ring(Vector2(x, y), 5.0, 2.2, near.lightened(0.05), 8)
			y += 10.0
		if hooks:
			tb.polyline(PackedVector2Array([Vector2(x, ln), Vector2(x, ln + 12.0), Vector2(x + 4.0, ln + 20.0), Vector2(x + 11.0, ln + 17.0),
					Vector2(x + 11.0, ln + 10.0)]), 3.4, near.lightened(0.06))


# ---------------------------------------------------------------- the windows

static func _faces(span: Vector2) -> Array:
	var out := []
	var i := 0
	var x := 700.0
	while x < span.x + 100.0:
		out.append({"center": Vector2(x + (_h(i, 90) - 0.5) * 160.0, 78.0), "r": 70.0})
		x += FACE_EVERY
		i += 1
	return out


static func _louvres(span: Vector2) -> Array:
	var out := []
	var x := 420.0
	while x < span.x + 100.0:
		out.append({"rect": Rect2(x - 20.0, 40.0, 40.0, 84.0)})
		x += 900.0
	return out


static func _wheels(span: Vector2) -> Array:
	## The escapement's great wheels and their pendulums, every one clear of
	## the far layer's last ARENA_FAR px (what the far layer shows while the
	## camera is in the Tinker's arena): nothing there that reads as his
	## clock. A 170-column 4-4 has one, seen on the way in.
	var out := []
	var x := 120.0
	while x + WHEEL_REACH.y < span.x - ARENA_FAR:
		out.append({"center": Vector2(x, 100.0), "r": WHEEL_R, "bob_y": 176.0})
		x += 2000.0
	return out


static func wheel_extent(w: Dictionary) -> Vector2:
	## [left, right] layer x of a wheel with its anchor and pendulum.
	var cx: float = (w["center"] as Vector2).x
	return Vector2(cx - WHEEL_REACH.x, cx + WHEEL_REACH.y)


static func wall_top(_v: String, span: Vector2) -> float:
	## Where the mid layer turns opaque (its wall): the far layer shows above it.
	return span.y * WALL


static func _lamps(v: String, span: Vector2) -> Array:
	var out := []
	if v != "gearworks":
		return out
	var x := 300.0
	var i := 0
	while x < span.x + 100.0:
		out.append({"center": Vector2(x, wall_top(v, span) + 40.0 + _h(i, 70) * 50.0)})
		x += 520.0
		i += 1
	return out


static func windows(layer_index: int, colors: Dictionary, span: Vector2) -> Array:
	## The clock faces lit from outside (far), the louvres' moonlight (far,
	## icebells), the brass lamps (mid, gearworks): decorative lights.
	var v := _variant(colors)
	var out := []
	var glass: Array = colors.get("glass", [Color("f4f0e0")])
	match layer_index:
		0:
			if v == "clockface":
				for f in _faces(span):
					out.append({"rose": true, "center": f["center"], "radius": 50.0, "s": 0.4, "tint": Color(Color("f4f0e0"), 0.4),
							"colors": glass})
			if v == "icebells":
				for w in _louvres(span):
					out.append({"rose": false, "rect": w["rect"], "s": 0.36, "tint": Color(Color("c0c8f0"), 0.5), "colors": glass, "seed": 0})
		1:
			for w in _lamps(v, span):
				out.append({"rose": true, "center": w["center"], "radius": 14.0, "s": 0.45, "colors": [Color("f0d080")]})
	return out
