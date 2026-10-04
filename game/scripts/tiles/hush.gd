extends RefCounted
## World 6's tile painter (A2): the Hushdeep, in ink and silver. Quiet,
## smooth, minimal: stone with no mortar and a thin silver lip, wet silver
## drips under one lip in five; ledges of old black wood with silver nails;
## crumbles as rotten rafts; spikes as black thorns with silver tips; the
## vines as drowned wick-reeds with charred tips; still water as a silvered
## sheet you can stand on. The lake itself is level_features.gd's (its theme
## colour "water"); 6-4's memory rooms (ice, belts, rime) are plain.gd's
## looks drained to grey by this world's palette; glass and dawnglass are
## glass.gd's in ink-silver panes (dawnglass keeps W5's gold: one tell
## language).
##   static func paint_chunk(ci, tb, level, x0, x1, pal, world, y0, y1)   the painter contract (contract.md §12.4)
##   static func paint_cell(ci, tb, level, x, y, t, pal, world)
## The live looks the deep feature (features/deep.gd, WL6) draws each frame,
## kept here so the world's look has one owner:
##   draw_float(ci, tb, r, water_y, t, pal)            a wax float (1-3 tiles; r its rect now), sinking
##                                                     below the lake line (what's under shows through)
##   draw_float_glow(glow, tb, r, water_y, loaded, t)  its silver edge (0.45, over the crest's 0.35) and ends;
##                                                     loaded, rings at its ends
##   draw_still_glow(glow, tb, x0, x1, y, tell, t)     still water's silver sheen; tell 0..1 over its last
##                                                     1.5 s: cracks spreading, the sheen shivering
##   draw_grasp_tell(glow, tb, p, k, t)                a Hushgrasp's 0.60 s: rings of ripples and pale
##                                                     fingertips glinting (the silver accent)
##   draw_buoy_glow(glow, tb, p, rung)                 a bell-buoy's silver silhouette (0.32; 0.55 rung) at
##                                                     its water point p, bobbing with its sprite
##   draw_buoy_ring(glow, tb, p, k)                    a toll's ring going out over the water (k 0..1)
##   flat_ring(tb, c, rx, w, col, a0, a1, seg, flat)   a ripple on the lake (an ellipse seen edge-on)
## (tb is appended to; the caller flushes it once.)
## No draw_circle / draw_colored_polygon / draw_polyline (test_render.gd).

const LevelData := preload("res://scripts/level_data.gd")
const Plain := preload("res://scripts/tiles/plain.gd")
const Glass := preload("res://scripts/tiles/glass.gd")
const TILE := 32
const BEDROCK_ROWS := 5

const VINE := 12
const ROTTEN_VINE := 13
const GLASS := 19
const DAWNGLASS := 20
const DAWN_ON := 21
const STILL := 22

const OUTLINE := Color("0c0a12")
const DEFAULTS := {
	"stone": Color("3e3c52"), "shade": Color("302e40"), "lip": Color("7a789e"), "mortar": Color("34324a"),
	"buried": Color("1c1a26"), "buried_mortar": Color("181622"), "brick": Color("3a3444"), "brick_shade": Color("2a2634"),
	"brick_lip": Color("5a5470"), "slab": Color("5a5468"), "slab_lip": Color("7a7490"), "drip": Color("8a88b0"),
	"wood": Color("2a2634"), "wood_lip": Color("5a5470"), "wood_shade": Color("1a1822"), "nail": Color("c8c8f0"),
	"silver": Color("c8c8f0"), "violet": Color("4a3a7a"), "violet_hi": Color("6a5a9a"), "eye": Color("d8d4f0"),
	"accent": Color("e0e0ff"), "iron": Color("1e1c28"), "still": Color("c8c8f0"),
	"vine": Color("3a3a4c"), "vine_lit": Color("8a88b0"), "rot": Color("34303e"), "rot_lit": Color("6a6680"),
}
const REED_X := 14.5               # a reed's stem centre in its cell (features/orchard.gd's vein: x * 32 + 13..16)
const WAX := Color("b8b2a4")        # a float: old candle wax gone grey in the dark
const WAX_TOP := Color("d4cec0")
const WAX_SHADE := Color("7e786c")


static func col(pal: Dictionary, key: String) -> Color:
	if pal.has(key):
		return pal[key]
	if DEFAULTS.has(key):
		return DEFAULTS[key]
	return Plain.col(pal, key)


static func _hash(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(absi(h) % 1000) / 1000.0


static func _solid(level: RefCounted, x: int, y: int) -> bool:
	if y >= level.height:
		return true
	return Plain.is_solid_id(level.tile(x, y))


# ---------------------------------------------------------------- the chunk

static func paint_chunk(ci: CanvasItem, tb, level: RefCounted, x0: int, x1: int, pal: Dictionary, world: Node, y0 := 0, y1 := -1) -> void:
	var ye: int = level.height if y1 < 0 else y1
	tb.origin = Vector2(x0 * TILE, y0 * TILE)
	for x in range(x0, x1):
		for y in range(y0, ye):
			var t: int = level.tile(x, y)
			if t != LevelData.AIR:
				paint_cell(ci, tb, level, x, y, t, pal, world)
		if ye >= level.height and Plain.is_solid_id(level.tile(x, level.height - 1)):
			for y in range(level.height, level.height + BEDROCK_ROWS):
				ci.draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), col(pal, "buried").darkened(0.15 * (y - level.height + 1)))
	tb.flush(ci)


static func paint_cell(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, t: int, pal: Dictionary, world: Node) -> void:
	var p := Vector2(x * TILE, y * TILE)
	match t:
		LevelData.STONE, LevelData.FALSE_STONE:
			_stone(ci, tb, level, x, y, p, pal)
		LevelData.BRICK:
			_stone(ci, tb, level, x, y, p, pal, true)
		LevelData.LEDGE:
			_plank(ci, tb, level, x, y, p, pal)
		LevelData.CRUMBLE:
			if world == null or not world.has_method("ledge_present") or world.ledge_present(x, y):
				var sh: Vector2 = world.ledge_shake(x, y) if world != null and world.has_method("ledge_shake") else Vector2.ZERO
				_raft(ci, tb, level, x, y, p + sh, pal)
		LevelData.SPIKES_UP, LevelData.SPIKES_DOWN:
			_thorns(ci, tb, x, p, t == LevelData.SPIKES_UP, pal)
		LevelData.WATER:
			pass   # the lake: level_features.gd
		STILL:
			_still(ci, tb, level, x, y, p, pal)
		VINE, ROTTEN_VINE:
			if t == ROTTEN_VINE and world != null and world.has_method("vine_present") and not world.vine_present(x, y):
				return
			_reed(ci, tb, level, x, y, p, t == ROTTEN_VINE, pal)
		GLASS, DAWNGLASS, DAWN_ON:
			Glass.paint_cell(ci, tb, level, x, y, t, pal, world)
		_:
			Plain.paint_cell(ci, tb, level, x, y, t, pal, world)


static func _stone(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary, cracked := false) -> void:
	## Smooth black stone: no mortar, the cel shade, a thin silver lip, and a
	## wet silver drip under one exposed lip in five. B is the same stone with
	## a crack that says "hit me".
	var up := _solid(level, x, y - 1)
	var down := _solid(level, x, y + 1)
	var left := _solid(level, x - 1, y)
	var right := _solid(level, x + 1, y)
	var j := (_hash(x, y) - 0.5) * 0.05
	if up and down and left and right and not cracked:
		ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), col(pal, "buried").lightened(j))
		return
	var stone := col(pal, "brick" if cracked else "stone").lightened(j)
	ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), stone)
	if not down:
		ci.draw_rect(Rect2(p + Vector2(0, TILE - 7), Vector2(TILE, 7)), col(pal, "shade"))
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 5, 0), Vector2(5, TILE)), col(pal, "shade"))
	if not up:
		ci.draw_rect(Rect2(p, Vector2(TILE, 2.5)), col(pal, "lip").lightened(j))
		ci.draw_rect(Rect2(p + Vector2(0, 0.5), Vector2(TILE, 1)), Color(col(pal, "silver"), 0.55))
		if pal.has("trim"):
			ci.draw_rect(Rect2(p + Vector2(0, 2.5), Vector2(TILE, 1)), pal["trim"])
		ci.draw_rect(Rect2(p + Vector2(0, -1), Vector2(TILE, 1.5)), OUTLINE)
		if _hash(x + 3, y + 1) > 0.8:
			# Wet silver running down from the lip.
			var dx := p.x + 5.0 + _hash(x, y + 5) * 20.0
			var len := 4.0 + _hash(x + 7, y) * 8.0
			var dc := col(pal, "drip")
			ci.draw_rect(Rect2(dx - 1.0, p.y + 2.0, 2.0, len), Color(dc, 0.85))
			tb.circle(Vector2(dx, p.y + 2.0 + len), 1.5, Color(dc, 0.85), 6)
	if not down:
		ci.draw_rect(Rect2(p + Vector2(0, TILE - 1.5), Vector2(TILE, 2)), OUTLINE)
	if not left:
		ci.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2, TILE)), OUTLINE)
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 1, 0), Vector2(2, TILE)), OUTLINE)
	if cracked:
		var a := p + Vector2(8 + _hash(x, y) * 8, 5)
		var pts := PackedVector2Array([a, a + Vector2(5, 7), a + Vector2(1, 12), a + Vector2(7, 20), a + Vector2(4, 25)])
		tb.polyline(pts, 2.2, OUTLINE)
		tb.line(a + Vector2(5, 7), a + Vector2(13, 9), 1.5, OUTLINE)
		tb.line(a + Vector2(1.2, 1), a + Vector2(5.8, 7.6), 0.9, Color(col(pal, "silver"), 0.55))


static func _plank(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	## A one-way ledge: old black wood, a silver nail at each end.
	var left: bool = level.tile(x - 1, y) == LevelData.LEDGE
	var right: bool = level.tile(x + 1, y) == LevelData.LEDGE
	ci.draw_rect(Rect2(p + Vector2(-0.5, -1), Vector2(TILE + 1, 11)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(0, 0.5), Vector2(TILE, 8)), col(pal, "wood"))
	ci.draw_rect(Rect2(p + Vector2(0, 0.5), Vector2(TILE, 2)), col(pal, "wood_lip"))
	ci.draw_rect(Rect2(p + Vector2(0, 0.5), Vector2(TILE, 0.8)), Color(col(pal, "silver"), 0.45))
	ci.draw_rect(Rect2(p + Vector2(0, 6.5), Vector2(TILE, 2)), col(pal, "wood_shade"))
	if pal.has("trim"):
		ci.draw_rect(Rect2(p + Vector2(0, 2.5), Vector2(TILE, 1)), pal["trim"])
	# The grain.
	ci.draw_rect(Rect2(p + Vector2(3 + _hash(x, y) * 6, 4.5), Vector2(10, 0.8)), col(pal, "wood_shade"))
	ci.draw_rect(Rect2(p + Vector2(16 + _hash(x, y + 1) * 6, 3.5), Vector2(8, 0.8)), col(pal, "wood_shade"))
	if not left:
		ci.draw_rect(Rect2(p + Vector2(-2, -1), Vector2(3, 11)), OUTLINE)
		tb.circle(p + Vector2(4, 4.5), 1.3, col(pal, "nail"), 6)
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 1, -1), Vector2(3, 11)), OUTLINE)
		tb.circle(p + Vector2(TILE - 4, 4.5), 1.3, col(pal, "nail"), 6)
	if (x + y) % 2 == 0 or not left:
		var bx := p.x + (6.0 if not left else 12.0)
		tb.tri(Vector2(bx, p.y + 8.5), Vector2(bx + 9, p.y + 8.5), Vector2(bx, p.y + 18), OUTLINE)
		tb.tri(Vector2(bx + 1.5, p.y + 9.5), Vector2(bx + 6, p.y + 9.5), Vector2(bx + 1.5, p.y + 14), col(pal, "wood_shade"))


static func _raft(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, q: Vector2, pal: Dictionary) -> void:
	## % : a rotten raft, three short planks lashed together, sagging.
	var sag := 1.5 + _hash(x, y) * 1.5
	ci.draw_rect(Rect2(q + Vector2(0, -1 + sag * 0.3), Vector2(TILE, 12)), OUTLINE)
	for i in 3:
		var px := q.x + 1.0 + i * 10.3
		var dy := sag * (1.0 if i == 1 else 0.3)
		ci.draw_rect(Rect2(px, q.y + 0.5 + dy, 9.3, 9), col(pal, "slab"))
		ci.draw_rect(Rect2(px, q.y + 0.5 + dy, 9.3, 2.5), col(pal, "slab_lip"))
		ci.draw_rect(Rect2(px, q.y + 7.5 + dy, 9.3, 2), col(pal, "shade"))
	# The lashing, frayed.
	tb.line(q + Vector2(2, 5 + sag * 0.3), q + Vector2(TILE - 2, 5 + sag * 0.3), 1.2, Color(col(pal, "silver"), 0.35))
	tb.line(q + Vector2(10.5, 1 + sag), q + Vector2(11.5, 10 + sag), 1.3, OUTLINE)
	tb.line(q + Vector2(20.8, 1 + sag), q + Vector2(21.6, 10 + sag), 1.3, OUTLINE)


static func _thorns(ci: CanvasItem, tb, x: int, p: Vector2, up: bool, pal: Dictionary) -> void:
	## Spikes: black thorns in a black root, each tipped with silver.
	var base_y := p.y + TILE if up else p.y
	var tip_y := p.y + TILE * 0.38 if up else p.y + TILE * 0.62
	var strip := Rect2(p.x, base_y - 5, TILE, 5) if up else Rect2(p.x, base_y, TILE, 5)
	ci.draw_rect(strip.grow(1.0), OUTLINE)
	ci.draw_rect(strip, col(pal, "iron"))
	var s := col(pal, "silver")
	var e := -1.2 if up else 1.2
	for i in 4:
		var x0 := p.x + i * 8.0
		var lean := (_hash(x * 4 + i, 3) - 0.5) * 2.0
		var tip := Vector2(x0 + 4 + lean, tip_y)
		tb.tri(Vector2(x0 - 0.3, base_y), tip + Vector2(0, -1.0 if up else 1.0), Vector2(x0 + 8.3, base_y), OUTLINE)
		tb.tri(Vector2(x0 + 1.4, base_y + e), tip + Vector2(0, 2.5 if up else -2.5), Vector2(x0 + 6.6, base_y + e), col(pal, "iron").lightened(0.1))
		var d := 5.0 if up else -5.0
		tb.tri(tip + Vector2(-1.3, d), tip + Vector2(0, 1.8 if up else -1.8), tip + Vector2(1.3, d), s)


static func _still(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	## Still water: the lake gone to a sheet of silvered glass (a ledge you
	## can stand on), faint reflections in it.
	## Its bright line is its top (y + 0, where he stands: a one-way ledge).
	var s := col(pal, "still")
	var left: bool = level.tile(x - 1, y) == STILL
	var right: bool = level.tile(x + 1, y) == STILL
	ci.draw_rect(Rect2(p + Vector2(0, 2), Vector2(TILE, 8)), Color(s, 0.16))
	ci.draw_rect(Rect2(p, Vector2(TILE, 2)), Color(s, 0.7))
	ci.draw_rect(Rect2(p, Vector2(TILE, 0.8)), Color(1, 1, 1, 0.35))
	if not left:
		ci.draw_rect(Rect2(p, Vector2(2, 10)), Color(s, 0.45))
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 2, 0), Vector2(2, 10)), Color(s, 0.45))
	var k := _hash(x, y)
	tb.line(p + Vector2(4 + k * 10, 7), p + Vector2(12 + k * 10, 5), 1.0, Color(1, 1, 1, 0.22))


static func _reed(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, rotten: bool, pal: Dictionary) -> void:
	## A drowned wick-reed (a vine): a straight stem with a knot each cell, a
	## silver rim on its lit side and a charred wick where the run ends. Its
	## stem is centred on REED_X, where the orchard feature's vein and fraying
	## tell run above the dark (x * 32 + 13..16), so the silver vein lies on it.
	var stem := col(pal, "rot" if rotten else "vine")
	var rim := col(pal, "rot_lit" if rotten else "vine_lit")
	var cx := p.x + REED_X
	# Its free top (a reed grows up out of the lake; one hung from a roof has none).
	var top_of_run: bool = level.tile(x, y - 1) == LevelData.AIR
	ci.draw_rect(Rect2(cx - 3.5, p.y, 7.0, TILE), OUTLINE)
	ci.draw_rect(Rect2(cx - 2.2, p.y, 4.4, TILE), stem)
	ci.draw_rect(Rect2(cx - 2.2, p.y, 1.3, TILE), Color(rim, 0.8))
	# The knot where one wick was bound to the next.
	var ky := p.y + 12.0 + _hash(x, y) * 8.0
	ci.draw_rect(Rect2(cx - 4.0, ky, 8.0, 3.0), OUTLINE)
	ci.draw_rect(Rect2(cx - 3.0, ky + 0.5, 6.0, 2.0), stem.lightened(0.15))
	if rotten:
		# Gaps and a sag: it won't hold long.
		ci.draw_rect(Rect2(cx - 4, p.y + 5, 8, 3), OUTLINE)
		ci.draw_rect(Rect2(cx - 4, p.y + 24, 8, 2.5), OUTLINE)
	if top_of_run:
		# A charred wick-tip, curled.
		tb.polyline(PackedVector2Array([Vector2(cx, p.y + 1), Vector2(cx - 1.5, p.y - 4), Vector2(cx + 1.0, p.y - 8), Vector2(cx + 3.0, p.y - 7)]), 2.6, OUTLINE)
		tb.polyline(PackedVector2Array([Vector2(cx, p.y + 1), Vector2(cx - 1.5, p.y - 4), Vector2(cx + 1.0, p.y - 8), Vector2(cx + 3.0, p.y - 7)]), 1.2, Color("3a3444"))
		tb.circle(Vector2(cx + 3.0, p.y - 7), 1.0, Color(col(pal, "silver"), 0.5), 6)


# ---------------------------------------------------------------- live looks (the deep feature calls these)

static func flat_ring(tb, c: Vector2, rx: float, w: float, col: Color, a0 := 0.0, a1 := TAU, seg := 24, flat := 0.22) -> void:
	## A ripple on the lake: an ellipse band seen nearly edge-on (ry = rx *
	## flat), from angle a0 to a1 (0 = right, PI/2 = toward the viewer).
	var n := maxi(seg, 4)
	var pts := PackedVector2Array()
	var full := is_equal_approx(absf(a1 - a0), TAU)
	for k in (n if full else n + 1):
		var a := a0 + (a1 - a0) * k / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * rx * flat))
	tb.polyline(pts, w, col, full)


static func draw_float(ci: CanvasItem, tb, r: Rect2, water_y: float, t: float, pal := {}) -> void:
	## A wax float: candle stubs melted into a raft. r is the float's rect now
	## (movers.gd: its top 4 px over the lake line at rest, lower as it
	## sinks); water_y the lake line. What is under the line shows through the
	## water, faint; a float gone under is a pale smudge.
	var top := r.position.y
	var body := Rect2(r.position.x + 1.0, top, r.size.x - 2.0, 11.0)
	var above := minf(body.end.y, water_y) - body.position.y
	var ink := Color(0.03, 0.03, 0.06, 1.0)
	if above > 0.0:
		ci.draw_rect(Rect2(body.position + Vector2(-1, -1), Vector2(body.size.x + 2, above + 1)), OUTLINE)
		ci.draw_rect(Rect2(body.position, Vector2(body.size.x, above)), WAX)
		ci.draw_rect(Rect2(body.position, Vector2(body.size.x, minf(3.0, above))), WAX_TOP)
		if above > 7.0:
			ci.draw_rect(Rect2(body.position + Vector2(0, 7), Vector2(body.size.x, above - 7.0)), WAX_SHADE)
	var under := body.end.y - maxf(body.position.y, water_y)
	if under > 0.0:
		# Under the line: a pale smudge through the ink, so you see where it went.
		ci.draw_rect(Rect2(body.position.x, maxf(body.position.y, water_y), body.size.x, under), Color(WAX.lerp(ink, 0.35), 0.30))
	# Candle stubs standing in it (their wicks long out).
	var n := maxi(1, int(r.size.x / 22.0))
	for i in n:
		var sx := body.position.x + (i + 0.5) * body.size.x / n + (fposmod(r.position.x * 0.37 + i * 3.1, 1.0) - 0.5) * 6.0
		var sh := 5.0 + fposmod(r.position.x * 0.13 + i * 1.7, 1.0) * 4.0
		var sy := top - sh
		if top <= water_y:
			ci.draw_rect(Rect2(sx - 3.5, sy - 1, 7, sh + 1.5), OUTLINE)
			ci.draw_rect(Rect2(sx - 2.5, sy, 5, sh + 0.5), WAX_TOP)
			ci.draw_rect(Rect2(sx + 0.5, sy, 2, sh + 0.5), WAX)
			ci.draw_rect(Rect2(sx - 0.4, sy - 2.5, 0.9, 2.5), OUTLINE)
	if above > 3.0:
		tb.circle(Vector2(body.position.x + 3.0, top + minf(above, 9.0)), 1.6, WAX_TOP, 6)


static func draw_float_glow(glow: CanvasItem, tb, r: Rect2, water_y: float, loaded: bool, t: float) -> void:
	## Above the dark: the float's silver top edge and its ends (0.45: the W6
	## phone alpha is 0.30 at least, and the lake's live crest under it is 0.35)
	## and, while it is loaded and sinking, rings at its ends.
	var top := r.position.y
	if top <= water_y:
		# Brighter than the lake's own crest just under it, with its ends
		# marked, so a float reads as a thing apart in the dark.
		var c := Color("d0d0f8", 0.45)
		tb.line(Vector2(r.position.x + 1.0, top + 0.75), Vector2(r.end.x - 1.0, top + 0.75), 2.0, c)
		var down := minf(water_y - top + 2.0, 7.0)
		tb.line(Vector2(r.position.x + 1.5, top), Vector2(r.position.x + 2.0, top + down), 1.5, c)
		tb.line(Vector2(r.end.x - 1.5, top), Vector2(r.end.x - 2.0, top + down), 1.5, c)
	if loaded:
		var k := fposmod(t * 1.6, 1.0)
		var c := Color("e0e0ff", 0.5 * (1.0 - k))
		flat_ring(tb, Vector2(r.position.x, water_y + 1.0), 4.0 + 16.0 * k, 1.4, c, PI * 0.5, PI * 1.5, 12, 0.3)
		flat_ring(tb, Vector2(r.end.x, water_y + 1.0), 4.0 + 16.0 * k, 1.4, c, -PI * 0.5, PI * 0.5, 12, 0.3)


static func draw_still_glow(glow: CanvasItem, tb, x0: float, x1: float, y: float, tell: float, t: float) -> void:
	## Still water's sheen above the dark (it reads as a floor in the dark),
	## and its tell over the last 1.5 s (tell 0..1): cracks spreading from
	## both ends, the sheen shivering, rings starting.
	var s := Color("d8d8ff")
	var shiver := 0.0 if tell <= 0.0 else sin(t * 40.0) * tell
	tb.line(Vector2(x0, y + 1.0), Vector2(x1, y + 1.0), 1.5, Color(s, 0.34 + 0.12 * shiver))
	if tell <= 0.0:
		return
	var span := x1 - x0
	var n := int(3 + tell * 3.0 + span / 48.0)
	var a := 0.45 + 0.5 * tell
	for i in n:
		var f := (float(i) + 0.5) / float(n)
		var cx := x0 + span * f
		var l := 8.0 + 14.0 * tell
		var zig := PackedVector2Array([Vector2(cx - l * 0.5, y + 1.5), Vector2(cx - l * 0.15, y + 4.5), Vector2(cx + l * 0.2, y + 0.8), Vector2(cx + l * 0.5, y + 3.5)])
		tb.polyline(zig, 1.6, Color("e0e0ff", a))
	var k := fposmod(t * 2.2, 1.0)
	flat_ring(tb, Vector2(x0 + span * 0.5, y + 2.0), 4.0 + span * 0.25 * k, 1.2, Color("e0e0ff", 0.4 * tell * (1.0 - k)))


static func draw_grasp_tell(glow: CanvasItem, tb, p: Vector2, k: float, t: float) -> void:
	## A Hushgrasp's tell over k 0..1 (its 0.60 s on Dusk), at p on the lake
	## line: rings of ripples going out, and pale fingertips glinting up
	## through the water as k grows. The silver accent: nothing else uses it.
	var acc := Color("e0e0ff")
	for i in 3:
		var f := fposmod(k * 1.5 + i / 3.0, 1.0)
		flat_ring(tb, p, 6.0 + 28.0 * f, 1.6, Color(acc, 0.75 * (1.0 - f) * minf(k * 3.0, 1.0)), 0.0, TAU, 22, 0.28)
	var tips := [-10.0, -4.0, 2.0, 8.0]
	for i in tips.size():
		var rise := clampf(k * 1.3 - i * 0.08, 0.0, 1.0)
		if rise <= 0.0:
			continue
		var fp := p + Vector2(tips[i], 2.0 - rise * 6.0)
		var tw := 0.6 + 0.4 * sin(t * 18.0 + i * 1.7)
		tb.quad(fp + Vector2(0, -3.4), fp + Vector2(1.0, 0), fp + Vector2(0, 3.4), fp + Vector2(-1.0, 0), Color(acc, 0.95 * rise * tw))
		tb.quad(fp + Vector2(-2.2, 0), fp + Vector2(0, 0.7), fp + Vector2(2.2, 0), fp + Vector2(0, -0.7), Color(acc, 0.8 * rise * tw))
		tb.circle(fp + Vector2(0, 1.4), 1.4, Color(acc, 0.8 * rise), 6)


static func draw_buoy_glow(glow: CanvasItem, tb, p: Vector2, rung := false) -> void:
	## A bell-buoy's silhouette above the dark (spec §11.1: W6 buoys at 0.30
	## at least), so the thing you ring reads outside your light: the float's
	## crest, the cage, the bell and its lantern in silver lines, traced from
	## bell_buoy.svg. p is its water point (points_w6.json "water", on the lake
	## line) with the sprite's bob already in it; rung, brighter, the bell
	## swung and the lantern lit gold.
	var a := 0.55 if rung else 0.32
	var sil := Color("d0d0f4", a)
	var ink := Color(0.02, 0.02, 0.04, 0.5)
	# The float's crest (a flat arc, brighter than the lake's crest under it) and its ends.
	var crest := PackedVector2Array()
	for i in 9:
		var f := i / 8.0
		crest.append(p + Vector2(-10.6 + 21.2 * f, 0.2 - 3.0 * 4.0 * f * (1.0 - f) * 0.9))
	tb.polyline(crest, 1.6, sil)
	tb.line(p + Vector2(-10.6, 0.2), p + Vector2(-11.0, 3.2), 1.3, sil)
	tb.line(p + Vector2(10.6, 0.2), p + Vector2(11.0, 3.2), 1.3, sil)
	# The cage's two bowed bars up to its ring.
	for sd in [-1.0, 1.0]:
		var bar := PackedVector2Array()
		var p0 := Vector2(-8.0 * sd, -2.0)
		var c1 := Vector2(-8.5 * sd, -9.0)
		var c2 := Vector2(-6.0 * sd, -17.0)
		var p3 := Vector2(0.0, -22.0)
		for i in 7:
			var u := i / 6.0
			var v := 1.0 - u
			bar.append(p + p0 * v * v * v + c1 * 3.0 * v * v * u + c2 * 3.0 * v * u * u + p3 * u * u * u)
		tb.polyline(bar, 1.2, sil)
	# The bell, its mouth brightest (swung when rung).
	var bell := [Vector2(-3.0, -16.0), Vector2(3.0, -16.0), Vector2(4.2, -11.0), Vector2(6.0, -7.2), Vector2(5.6, -5.7),
			Vector2(-5.6, -5.7), Vector2(-6.0, -7.2), Vector2(-4.2, -11.0)]
	var rot := -0.28 if rung else 0.0
	var pivot := Vector2(0.0, -17.5)
	var pts := PackedVector2Array()
	for q in bell:
		pts.append(p + pivot + ((q as Vector2) - pivot).rotated(rot))
	tb.polyline(pts, 3.0, ink, true)
	tb.polyline(pts, 1.3, sil, true)
	tb.line(pts[4], pts[5], 1.8, Color("e8e8ff", minf(a + 0.2, 1.0)))
	# The lantern on top: an outline, gold when the toll has lit it.
	var lamp := Color("ffd98a", 0.7) if rung else sil
	tb.polyline(PackedVector2Array([p + Vector2(-3.0, -23.0), p + Vector2(-3.0, -29.0), p + Vector2(3.0, -29.0), p + Vector2(3.0, -23.0)]), 1.2, lamp, true)
	tb.line(p + Vector2(-4.0, -29.4), p + Vector2(0.0, -32.2), 1.1, sil)
	tb.line(p + Vector2(0.0, -32.2), p + Vector2(4.0, -29.4), 1.1, sil)


static func draw_buoy_ring(glow: CanvasItem, tb, p: Vector2, k: float) -> void:
	## A toll going out over the water: a silver ring widening from the buoy
	## to its 6 tiles (192 px) as k goes 0..1, fading.
	if k <= 0.0 or k >= 1.0:
		return
	flat_ring(tb, p, 8.0 + 184.0 * k, 2.0, Color("e0e0ff", 0.45 * (1.0 - k)), 0.0, TAU, 40, 0.14)
	flat_ring(tb, p, 4.0 + 120.0 * k, 1.2, Color("e0e0ff", 0.30 * (1.0 - k)), 0.0, TAU, 32, 0.14)
