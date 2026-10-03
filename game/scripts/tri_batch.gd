extends RefCounted
## A triangle batch: everything that isn't a rect, built into one vertex
## array and handed to the renderer as ONE draw call by flush(ci). New drawing
## code (tile painters, backdrop styles, feature modules, ambient, edge lines,
## glow's sparks) draws its rects with draw_rect, then puts every circle,
## polygon, line and fan in here, then flushes (at most twice a canvas item).
## No draw_circle, draw_colored_polygon or draw_polyline in new code: each of
## those is a draw call of its own (a grep test in test_render.gd holds it).
##
##   var tb := TriBatch.new()          # const TriBatch := preload("res://scripts/tri_batch.gd")
##   tb.origin = Vector2(x0, 0)        # optional: points are stored relative to it
##   tb.circle(p, 4.0, col); tb.line(a, b, 2.0, col); tb.convex(pts, col)
##   tb.flush(self)                    # in _draw(); clears the batch
##
## Budgets (contract.md §12.3): a static chunk <= 6000 vertices, per-frame
## batches <= 4000 in all. Past MAX_VERTICES a batch refuses more (and
## counts what it dropped), so a runaway burst can't stall a frame.
##
## Precision: concave() triangulates relative to the batch's origin (glow.gd
## found the engine's triangulation failing on float precision past x ~3000),
## and every shape is built from explicit indices, never re-triangulated.

const MAX_VERTICES := 32768      # room for glow's 400 sparks at 65 vertices each

var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()
var origin := Vector2.ZERO        # the chunk's origin: concave() triangulates relative to it
var dropped := 0                  # shapes refused for going past MAX_VERTICES


func clear() -> void:
	points.clear()
	colors.clear()
	indices.clear()
	dropped = 0


func vertex_count() -> int:
	return points.size()


func is_empty() -> bool:
	return indices.is_empty()


func _room(n: int) -> bool:
	if points.size() + n > MAX_VERTICES:
		dropped += 1
		return false
	return true


func _v(p: Vector2, col: Color) -> int:
	points.append(p)
	colors.append(col)
	return points.size() - 1


func tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	if not _room(3):
		return
	var i := points.size()
	points.append_array(PackedVector2Array([a, b, c]))
	colors.append_array(PackedColorArray([col, col, col]))
	indices.append_array(PackedInt32Array([i, i + 1, i + 2]))


func tri3(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	## A triangle with a colour per corner (gradients).
	if not _room(3):
		return
	var i := points.size()
	points.append_array(PackedVector2Array([a, b, c]))
	colors.append_array(PackedColorArray([ca, cb, cc]))
	indices.append_array(PackedInt32Array([i, i + 1, i + 2]))


func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	## Four corners in order round the edge (either winding).
	if not _room(4):
		return
	var i := points.size()
	points.append_array(PackedVector2Array([a, b, c, d]))
	colors.append_array(PackedColorArray([col, col, col, col]))
	indices.append_array(PackedInt32Array([i, i + 1, i + 2, i, i + 2, i + 3]))


func rect(r: Rect2, col: Color) -> void:
	## A rect inside the batch (for rects that must sit over the batch's other
	## shapes; plain rects are cheaper as draw_rect before the flush).
	quad(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), col)


func fan(center: Vector2, rim: PackedVector2Array, col: Color, closed := true) -> void:
	## A fan from center to each rim point in order (a convex blob, a pie).
	var n := rim.size()
	if n < 2 or not _room(n + 1):
		return
	var c := _v(center, col)
	var first := points.size()
	for p in rim:
		points.append(p)
		colors.append(col)
	var last := n if closed else n - 1
	for k in last:
		indices.append_array(PackedInt32Array([c, first + k, first + (k + 1) % n]))


static var _units := {}           # seg -> PackedVector2Array: the centre, then seg rim points of a unit circle
static var _fans := {}            # seg -> PackedInt32Array: the fan's indices for one circle (from 0)
static var _runs := {}            # seg -> PackedInt32Array: the fans of many circles in a row (circles())
static var _fill := PackedColorArray()


static func _unit(seg: int) -> PackedVector2Array:
	if not _units.has(seg):
		var u := PackedVector2Array([Vector2.ZERO])
		var f := PackedInt32Array()
		for k in seg:
			var a := k * 2.0 * PI / seg
			u.append(Vector2(cos(a), sin(a)))
			f.append_array(PackedInt32Array([0, 1 + k, 1 + (k + 1) % seg]))
		_units[seg] = u
		_fans[seg] = f
	return _units[seg]


func circle(c: Vector2, r: float, col: Color, seg := 10) -> void:
	## A filled circle, a fan of seg triangles. At seg 64 it is draw_circle's
	## exact shape (the same pixels), which glow's sparks use.
	if r <= 0.0:
		return
	ellipse(c, r, r, col, seg)


func ellipse(c: Vector2, rx: float, ry: float, col: Color, seg := 12) -> void:
	seg = maxi(seg, 3)
	if not _room(seg + 1):
		return
	var base := points.size()
	points.append_array(Transform2D(Vector2(rx, 0.0), Vector2(0.0, ry), c) * _unit(seg))
	if _fill.size() != seg + 1:
		_fill.resize(seg + 1)
	_fill.fill(col)
	colors.append_array(_fill)
	var f: PackedInt32Array = _fans[seg]
	var i0 := indices.size()
	indices.append_array(f)
	for k in range(i0, indices.size()):
		indices[k] += base


func circles(centers: PackedVector2Array, radii: PackedFloat32Array, cols: PackedColorArray, seg := 64) -> void:
	## Many circles at once (glow's sparks): the fastest way in, the points
	## moved by the engine and the indices from a cached run. Starts a batch
	## of its own: call it on an empty batch.
	var n := centers.size()
	if n == 0:
		return
	var per := seg + 1
	if not _room(n * per):
		n = maxi((MAX_VERTICES - points.size()) / per, 0)
		if n == 0:
			return
	var u := _unit(seg)
	var base := points.size()
	var one := PackedColorArray()
	one.resize(per)
	for i in n:
		var r: float = radii[i]
		points.append_array(Transform2D(Vector2(r, 0.0), Vector2(0.0, r), centers[i]) * u)
		one.fill(cols[i])
		colors.append_array(one)
	var run: PackedInt32Array = _runs.get(seg, PackedInt32Array())
	if run.size() < n * seg * 3:
		# Grow the cached run only as far as this batch needs (no hitch up front).
		var f: PackedInt32Array = _fans[seg]
		for k in range(run.size() / (seg * 3), n):
			var at := run.size()
			run.append_array(f)
			var off := k * per
			for j in range(at, run.size()):
				run[j] += off
		_runs[seg] = run
	var i0 := indices.size()
	indices.append_array(run.slice(0, n * seg * 3))
	if base > 0:
		for k in range(i0, indices.size()):
			indices[k] += base


func ring(c: Vector2, r: float, w: float, col: Color, seg := 16, a0 := 0.0, a1 := TAU) -> void:
	## An arc band of width w centred on radius r (a whole ring by default).
	seg = maxi(seg, 2)
	var full := is_equal_approx(absf(a1 - a0), TAU)
	var n := seg if full else seg + 1
	if not _room(n * 2):
		return
	var i0 := points.size()
	for k in n:
		var a := a0 + (a1 - a0) * k / seg
		var d := Vector2(cos(a), sin(a))
		_v(c + d * (r - w * 0.5), col)
		_v(c + d * (r + w * 0.5), col)
	for k in seg:
		var a := i0 + k * 2
		var b := i0 + ((k + 1) % n) * 2
		indices.append_array(PackedInt32Array([a, a + 1, b + 1, a, b + 1, b]))


func line(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	## A straight line w wide (a quad).
	var d := b - a
	if d.length_squared() < 1e-8:
		return
	var o := d.normalized().orthogonal() * (w * 0.5)
	quad(a + o, b + o, b - o, a - o, col)


func polyline(pts: PackedVector2Array, w: float, col: Color, closed := false) -> void:
	## A line through the points, w wide, with mitred joints (a mitre longer
	## than 3 widths is cut back to a bevel-ish square, so sharp turns don't spike).
	var n := pts.size()
	if n < 2:
		return
	if n == 2 and not closed:
		line(pts[0], pts[1], w, col)
		return
	if not _room(n * 2 + 2):
		return
	var hw := w * 0.5
	var i0 := points.size()
	var cnt := n
	for k in n:
		var p := pts[k]
		var prev: Vector2
		var next: Vector2
		if closed:
			prev = pts[(k - 1 + n) % n]
			next = pts[(k + 1) % n]
		else:
			prev = pts[k - 1] if k > 0 else p - (pts[1] - pts[0])
			next = pts[k + 1] if k < n - 1 else p + (pts[n - 1] - pts[n - 2])
		var d0 := (p - prev).normalized()
		var d1 := (next - p).normalized()
		if d0 == Vector2.ZERO:
			d0 = d1
		if d1 == Vector2.ZERO:
			d1 = d0
		var n0 := d0.orthogonal()
		var mit := (n0 + d1.orthogonal())
		var ml := mit.length()
		var off: Vector2
		if ml < 1e-4:
			off = n0 * hw
		else:
			mit /= ml
			var dotv := mit.dot(n0)
			var len := hw / maxf(dotv, 1.0 / 3.0)
			off = mit * len
		_v(p + off, col)
		_v(p - off, col)
	var segs := cnt if closed else cnt - 1
	for k in segs:
		var a := i0 + k * 2
		var b := i0 + ((k + 1) % cnt) * 2
		indices.append_array(PackedInt32Array([a, a + 1, b + 1, a, b + 1, b]))


func convex(pts: PackedVector2Array, col: Color) -> void:
	## A convex polygon (a fan from its first point).
	var n := pts.size()
	if n < 3 or not _room(n):
		return
	var i0 := points.size()
	for p in pts:
		points.append(p)
		colors.append(col)
	for k in range(1, n - 1):
		indices.append_array(PackedInt32Array([i0, i0 + k, i0 + k + 1]))


func concave(pts: PackedVector2Array, col: Color) -> void:
	## Any simple polygon, triangulated (relative to origin, for precision).
	## Build-time use only: triangulation costs far more than the others.
	var n := pts.size()
	if n < 3 or not _room(n):
		return
	var rel := PackedVector2Array()
	rel.resize(n)
	for k in n:
		rel[k] = pts[k] - origin
	var tris := Geometry2D.triangulate_polygon(rel)
	if tris.is_empty():
		return
	var i0 := points.size()
	for p in pts:
		points.append(p)
		colors.append(col)
	for t in tris:
		indices.append(i0 + t)


func append(other: RefCounted) -> void:
	## Another batch's shapes onto this one.
	var base := points.size()
	if not _room(other.points.size()):
		return
	points.append_array(other.points)
	colors.append_array(other.colors)
	for t in other.indices:
		indices.append(base + t)


func flush(ci: CanvasItem) -> void:
	## Hands the batch to ci's canvas item as one draw call, then clears it.
	## Call from ci's _draw (or a draw signal). An empty batch draws nothing
	## and costs nothing.
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, points, colors)
	clear()


func flush_rid(item: RID) -> void:
	## flush() for a raw canvas item RID.
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(item, indices, points, colors)
	clear()
