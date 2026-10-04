extends RefCounted
## The plain backdrop style: the fallback when a theme's style file is
## missing, and the reference for the art streams' styles (A1's orchard and
## clockwork, A2's sanctum, hushdeep and hall follow the same shape).
##   static func draw(slice, tb, layer_index, colors, span, x0, x1, tall := 0.0)   one 1024 px slice of one layer
##   static func windows(layer_index, colors, span, tall := 0.0) -> Array           its glowing bits, computed at build
## (tall: how much deeper a level taller than 15 rows shows the layer,
## backdrop.gd tall(); 0 for a strip. A style keeps the strip's composition
## on span.y - tall and fills the band below; this fallback draws as before.)
## A slice draws only the elements whose anchor x is in [x0, x1) (an element
## may overhang into the next slice; each is drawn by exactly one slice), so
## Godot culls the slices off screen. Rects with slice.draw_rect, the rest
## into tb; backdrop_layer.gd flushes tb after draw(). Layer space: x from 0
## to span.x, y from 0 to span.y (the level's height seen through parallax).
## No draw_circle / draw_colored_polygon / draw_polyline (test_render.gd).
## Colours: sky, far, mid, near, glass: [...], banner (the theme's).

const FAR_EVERY := 300.0
const MID_EVERY := 240.0
const NEAR_EVERY := 520.0
const WINDOW_EVERY := 720.0


static func _h(i: int, salt: int = 0) -> float:
	var h := (i * 2654435761 + salt * 40503) & 0x7fffffff
	return float(h % 10000) / 10000.0


static func _each(every: float, x0: float, x1: float) -> Array[int]:
	## The indices i whose anchor i * every falls in [x0, x1).
	var out: Array[int] = []
	var i := ceili(x0 / every)
	while i * every < x1:
		out.append(i)
		i += 1
	return out


static func draw(slice, tb, layer_index: int, colors: Dictionary, span: Vector2, x0: float, x1: float, tall := 0.0) -> void:
	var sky: Color = colors.get("sky", Color("150f1e"))
	var far: Color = colors.get("far", Color("1f1730"))
	var mid: Color = colors.get("mid", Color("2a2040"))
	var near: Color = colors.get("near", Color("181226"))
	var bottom := span.y + 400.0
	match layer_index:
		0:
			# The sky, then far towers with rounded tops.
			slice.draw_rect(Rect2(x0, -200.0, x1 - x0, bottom + 200.0), sky)
			for i in _each(FAR_EVERY, x0, x1):
				var x := i * FAR_EVERY + _h(i) * 60.0
				var w := 70.0 + _h(i, 1) * 70.0
				var top := 40.0 + _h(i, 2) * 90.0
				slice.draw_rect(Rect2(x - w * 0.5, top + w * 0.5, w, bottom), far)
				tb.ellipse(Vector2(x, top + w * 0.5), w * 0.5, w * 0.5, far, 16)
		1:
			# A wall with round-headed arches.
			slice.draw_rect(Rect2(x0, 90.0, x1 - x0, bottom), mid.darkened(0.25))
			for i in _each(MID_EVERY, x0, x1):
				var x := i * MID_EVERY
				slice.draw_rect(Rect2(x - 14.0, 40.0, 28.0, bottom), mid)
				slice.draw_rect(Rect2(x - 20.0, 84.0, 40.0, 10.0), mid.lightened(0.08))
				var ax := x + MID_EVERY * 0.5
				var aw := 70.0
				var atop := 130.0 + _h(i, 3) * 20.0
				slice.draw_rect(Rect2(ax - aw * 0.5, atop + aw * 0.5, aw, 150.0), mid.darkened(0.45))
				tb.ellipse(Vector2(ax, atop + aw * 0.5), aw * 0.5, aw * 0.5, mid.darkened(0.45), 14)
			for w in windows(1, colors, span):
				var r: Rect2 = w["rect"]
				var cx := r.get_center().x
				if cx < x0 or cx >= x1:
					continue
				var cols: Array = w["colors"]
				for row in 4:
					for c in 2:
						var g: Color = cols[(int(w["seed"]) + row * 3 + c) % cols.size()]
						slice.draw_rect(Rect2(r.position.x + c * r.size.x * 0.5 + 2.0, r.position.y + 10.0 + row * (r.size.y - 12.0) / 4.0 + 2.0,
								r.size.x * 0.5 - 4.0, (r.size.y - 12.0) / 4.0 - 4.0), g.darkened(0.2))
				tb.ellipse(Vector2(cx, r.position.y + 10.0), r.size.x * 0.5 - 2.0, 10.0, (cols[0] as Color).darkened(0.1), 12)
		2:
			# Near pillars with a band, and a hanging chain of links.
			for i in _each(NEAR_EVERY, x0, x1):
				var x := i * NEAR_EVERY + _h(i, 5) * 120.0
				slice.draw_rect(Rect2(x - 24.0, -60.0, 48.0, bottom + 60.0), near)
				slice.draw_rect(Rect2(x - 32.0, 90.0 + _h(i) * 40.0, 64.0, 12.0), near.lightened(0.06))
				if _h(i, 9) > 0.4:
					var cx := x + 90.0 + _h(i, 2) * 80.0
					var len := 60.0 + _h(i, 4) * 90.0
					var y := -10.0
					while y < len:
						tb.ring(Vector2(cx, y), 3.5, 1.6, near.lightened(0.12), 8)
						y += 8.0


static func windows(layer_index: int, colors: Dictionary, span: Vector2, tall := 0.0) -> Array:
	## Lancet windows on the wall layer, every WINDOW_EVERY px.
	var out := []
	if layer_index != 1:
		return out
	var glass: Array = colors.get("glass", [Color("b8324e"), Color("3a6ab8")])
	var i := 0
	var x := 360.0
	while x < span.x + 100.0:
		out.append({"layer": 1, "rose": false, "rect": Rect2(x - 22.0, 150.0 + _h(i, 7) * 20.0, 44.0, 120.0), "colors": glass, "seed": i})
		x += WINDOW_EVERY
		i += 1
	return out
