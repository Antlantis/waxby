extends RefCounted
## World 5's tile painter (A2): the Shattered Sanctum. Carved ashlar that
## floats over the void with a gold-leaf lip and quatrefoil carvings; ledges
## and crumbles in marble with a gold edge (never glass: glass is what breaks
## underfoot); spikes as glass teeth; the breaking glass G as jewel panes in
## black lead (a colour per run, by hash, that never means anything);
## dawnglass as a gold ghost at alpha 0.30, lit as bright pale gold.
##   static func paint_chunk(ci, tb, level, x0, x1, pal, world)   the painter contract (contract.md §12.4)
##   static func paint_cell(ci, tb, level, x, y, t, pal, world)   one cell (the rest of v3's tiles: plain.gd)
## Rects go to ci.draw_rect, every other shape into tb, flushed once.
##
## The live looks the glass feature (features/glass.gd, WL5) draws each frame
## over the chunks, kept here so the world's look has one owner:
##   draw_pane_overlay(ci, tb, cell, strain, state, age, pal)  cracks at 0.4 and 0.8 (a white core >= 1.5 px),
##                                                             the 0.35 s flash, the re-forming shimmer
##   draw_dawn_overlay(ci, tb, cell, k, flicker, t, pal)       lit dawnglass fading toward its ghost (its clock)
##   gust_band(level, z, view, hero, feet) -> Rect2            the air a gust zone's wind is drawn in: over
##                                                             the hero's own floor (band_floor)
##   draw_gust_glow(glow, tb, level, z, ph, view, t, pal, hero, feet)  the sanctum's wind, above the dark:
##                                                             soft ribbons, dust and glass glints
##   pennant_anchors(level, z) -> Array                        where a zone's pennants hang (at build)
##   draw_gust_under(ci, tb, z, ph, anchors, t, tex, level)    the pennants (slack, lifting at the tell, full)
##   lean_of(ph) -> float                                      0..1: how far a flame or cape leans (tell 0.5)
## (ph is the feature's gust_phase(z): {state: calm|tell|gust, k}; hero the
## player's rect; feet the camera's ground line, world.feet_line() +
## world.look_up(); tb is appended to and the caller flushes it once.) Never
## drawn over the HUD (the band starts HUD_TOP px under the view's top) or
## below the hero's floor.
## No draw_circle / draw_colored_polygon / draw_polyline (test_render.gd).

const LevelData := preload("res://scripts/level_data.gd")
const Plain := preload("res://scripts/tiles/plain.gd")
const TILE := 32
const BEDROCK_ROWS := 5

const GLASS := 19
const DAWNGLASS := 20
const DAWN_ON := 21

const OUTLINE := Color("17121f")
const CRACK := Color("20161e")
const PANES := [Color("c83a5a"), Color("3a6ac8"), Color("e0a830"), Color("4aa86a")]
const DEFAULTS := {
	"stone": Color("5a5070"), "shade": Color("463e5a"), "lip": Color("9c8ec4"), "mortar": Color("3e3654"),
	"buried": Color("2a2440"), "buried_mortar": Color("241f38"), "brick": Color("5a4a66"), "brick_shade": Color("443852"),
	"brick_lip": Color("8a78a0"), "slab": Color("7a7094"), "slab_lip": Color("b0a6cc"),
	"came": Color("1a1420"), "gold": Color("d8b24a"), "gold_hi": Color("ffe28a"), "accent": Color("f8f0ff"),
	"dawn": Color("f2d88a"), "dawn_hi": Color("fff4c8"), "marble": Color("8c84a4"), "marble_lip": Color("c8c0e0"),
	"marble_shade": Color("5e5876"), "lead": Color("2a2434"), "lead_hi": Color("5a5270"),
}
# The gust look (spec §3.2 Gusts; the owner: the stand-in "looked silly").
const HUD_TOP := 70.0            # px under the view's top the wind never goes above (the HUD's rows)
const FEET_LINE := 211.0         # the camera's ground line when the caller has none (world.feet_line() at buttons x1.0)
const GROUND_UP := 44.0          # band_floor: a top at most this far over the ground line (never one over his head)
const GROUND_DOWN := 64.0        # ... or this far under it (a step down while the camera eases; not a pit's bottom)
const GROUND_SLACK := 8.0        # the band's floor never lower than this under the ground line (the thumbs)
const BAND_ROWS := 6             # the wind blows through this many tiles of air over the floor
const WIND := Color("ece8ff")    # the ribbons: a pale lavender white
const DUST := Color("d8cec4")
const GLINT := Color("f8f0ff")   # W5's tell accent (the gust is a tell)
const PENNANT_EVERY := 5


static func col(pal: Dictionary, key: String) -> Color:
	if pal.has(key):
		return pal[key]
	if DEFAULTS.has(key):
		return DEFAULTS[key]
	return Plain.col(pal, key)


static func panes(pal: Dictionary) -> Array:
	var p = pal.get("panes", PANES)
	return p if p is Array and not p.is_empty() else PANES


static func _hash(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(absi(h) % 1000) / 1000.0


static func is_solid_id(t: int) -> bool:
	return Plain.is_solid_id(t)


static func _solid(level: RefCounted, x: int, y: int) -> bool:
	if y >= level.height:
		return true
	return is_solid_id(level.tile(x, y))


# ---------------------------------------------------------------- the chunk

static func paint_chunk(ci: CanvasItem, tb, level: RefCounted, x0: int, x1: int, pal: Dictionary, world: Node) -> void:
	tb.origin = Vector2(x0 * TILE, 0)
	for x in range(x0, x1):
		for y in level.height:
			var t: int = level.tile(x, y)
			if t != LevelData.AIR:
				paint_cell(ci, tb, level, x, y, t, pal, world)
		if is_solid_id(level.tile(x, level.height - 1)):
			for y in range(level.height, level.height + BEDROCK_ROWS):
				ci.draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), col(pal, "buried").darkened(0.15 * (y - level.height + 1)))
	tb.flush(ci)


static func paint_cell(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, t: int, pal: Dictionary, world: Node) -> void:
	var p := Vector2(x * TILE, y * TILE)
	match t:
		LevelData.STONE, LevelData.FALSE_STONE:
			_ashlar(ci, tb, level, x, y, p, pal)
		LevelData.BRICK:
			_cracked(ci, tb, level, x, y, p, pal)
		LevelData.LEDGE:
			_marble_ledge(ci, tb, level, x, y, p, pal)
		LevelData.CRUMBLE:
			if world == null or not world.has_method("ledge_present") or world.ledge_present(x, y):
				var sh: Vector2 = world.ledge_shake(x, y) if world != null and world.has_method("ledge_shake") else Vector2.ZERO
				_crumble(ci, tb, level, x, y, p + sh, pal)
		LevelData.SPIKES_UP, LevelData.SPIKES_DOWN:
			_teeth(ci, tb, x, y, p, t == LevelData.SPIKES_UP, pal)
		GLASS:
			_pane(ci, tb, level, x, y, p, pal)
		DAWNGLASS:
			_dawn_ghost(ci, tb, p, pal)
		DAWN_ON:
			_dawn_lit(ci, tb, level, x, y, p, pal)
		_:
			Plain.paint_cell(ci, tb, level, x, y, t, pal, world)


static func _ashlar(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	## Carved sanctum masonry: smooth ashlar, a bevel on each block, the cel
	## shade, a lit lip with gold leaf under it, a quatrefoil on 1 face in 6
	## and broken rubble under an exposed bottom (it floats).
	var up := _solid(level, x, y - 1)
	var down := _solid(level, x, y + 1)
	var left := _solid(level, x - 1, y)
	var right := _solid(level, x + 1, y)
	var j := (_hash(x, y) - 0.5) * 0.05
	var mortar := col(pal, "mortar")
	if up and down and left and right:
		ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), col(pal, "buried").lightened(j))
		ci.draw_rect(Rect2(p + Vector2(0, 15), Vector2(TILE, 2)), col(pal, "buried_mortar"))
		if y % 2 == 0:
			ci.draw_rect(Rect2(p + Vector2(15, 0), Vector2(2, 15)), col(pal, "buried_mortar"))
		return
	var stone := col(pal, "stone").lightened(j)
	ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), stone)
	# Two courses a cell, joints staggered by row: big smooth blocks.
	ci.draw_rect(Rect2(p + Vector2(0, 15), Vector2(TILE, 1.5)), mortar)
	var off := 0.0 if y % 2 == 0 else 16.0
	ci.draw_rect(Rect2(p + Vector2(off, 0), Vector2(1.5, 15)), mortar)
	ci.draw_rect(Rect2(p + Vector2(fmod(off + 16.0, 32.0), 16.5), Vector2(1.5, 15.5)), mortar)
	# Each block's lit bevel along its top.
	ci.draw_rect(Rect2(p + Vector2(0, 16.5), Vector2(TILE, 1)), stone.lightened(0.08))
	if not down:
		ci.draw_rect(Rect2(p + Vector2(0, TILE - 7), Vector2(TILE, 7)), col(pal, "shade"))
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 5, 0), Vector2(5, TILE)), col(pal, "shade"))
	if not up:
		ci.draw_rect(Rect2(p, Vector2(TILE, 4)), col(pal, "lip").lightened(j))
		# Gold leaf under the lip highlight; a gilt theme's trim under that.
		ci.draw_rect(Rect2(p + Vector2(0, 4), Vector2(TILE, 1.5)), col(pal, "gold"))
		if pal.has("trim"):
			ci.draw_rect(Rect2(p + Vector2(0, 5.5), Vector2(TILE, 1)), pal["trim"])
		ci.draw_rect(Rect2(p + Vector2(0, -1), Vector2(TILE, 2.5)), OUTLINE)
		if _hash(x, y + 7) > 0.72:
			# A chip out of the lip, and its gold.
			ci.draw_rect(Rect2(p + Vector2(5 + _hash(x + 3, y) * 18, 0), Vector2(4, 2)), col(pal, "shade"))
	if not down:
		ci.draw_rect(Rect2(p + Vector2(0, TILE - 1.5), Vector2(TILE, 2.5)), OUTLINE)
	if not left:
		ci.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2.5, TILE)), OUTLINE)
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 1.5, 0), Vector2(2.5, TILE)), OUTLINE)
	# A quatrefoil carved in one exposed face in six.
	if (not left or not right or not down) and _hash(x + 11, y + 5) > 0.83:
		var c := p + Vector2(14.0, 23.0 if up else 22.0)
		var deep := col(pal, "shade").darkened(0.18)
		for k in 4:
			var a := k * PI * 0.5
			tb.circle(c + Vector2(cos(a), sin(a)) * 2.6, 2.4, deep, 8)
		tb.circle(c, 1.2, stone.lightened(0.12), 6)
	# Broken rubble hanging under an exposed bottom: blunt chunks, never points.
	if not down and level.tile(x, y + 1) == LevelData.AIR and _hash(x, y + 13) > 0.45:
		var bx := p.x + 4.0 + _hash(x + 5, y) * 14.0
		var w := 7.0 + _hash(x, y + 21) * 6.0
		var hgt := 3.0 + _hash(x + 9, y) * 2.5
		var by := p.y + TILE + 0.5
		tb.quad(Vector2(bx - 1, by - 1), Vector2(bx + w + 1, by - 1), Vector2(bx + w - 1, by + hgt + 1.2), Vector2(bx + 1.5, by + hgt + 1.5), OUTLINE)
		tb.quad(Vector2(bx, by - 1), Vector2(bx + w, by - 1), Vector2(bx + w - 2, by + hgt), Vector2(bx + 2, by + hgt), col(pal, "shade").darkened(0.1))


static func _cracked(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	## B: masonry that says "hit me": darker blocks and a deep crack.
	ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), col(pal, "brick"))
	ci.draw_rect(Rect2(p + Vector2(0, TILE - 7), Vector2(TILE, 7)), col(pal, "brick_shade"))
	ci.draw_rect(Rect2(p + Vector2(TILE - 5, 0), Vector2(5, TILE)), col(pal, "brick_shade"))
	ci.draw_rect(Rect2(p, Vector2(TILE, 4)), col(pal, "brick_lip"))
	ci.draw_rect(Rect2(p + Vector2(0, 4), Vector2(TILE, 1.5)), col(pal, "gold").darkened(0.35))
	var k := _hash(x, y)
	var a := p + Vector2(8 + k * 8, 5)
	tb.polyline(PackedVector2Array([a, a + Vector2(5, 7), a + Vector2(1, 12), a + Vector2(7, 20), a + Vector2(4, 25)]), 2.2, CRACK)
	tb.line(a + Vector2(5, 7), a + Vector2(13, 9), 1.5, CRACK)
	tb.line(a + Vector2(7, 20), a + Vector2(15, 18), 1.5, CRACK)
	tb.line(a + Vector2(1.2, 1), a + Vector2(5.8, 7.6), 0.9, Color(col(pal, "brick_lip"), 0.8))
	ci.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(TILE + 2, 2.5)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-1, TILE - 1.5), Vector2(TILE + 2, 2.5)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2.5, TILE + 2)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(TILE - 1.5, -1), Vector2(2.5, TILE + 2)), OUTLINE)


static func _marble_ledge(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	## A one-way ledge: a marble slab with a gold edge on a small corbel.
	var left: bool = level.tile(x - 1, y) == LevelData.LEDGE
	var right: bool = level.tile(x + 1, y) == LevelData.LEDGE
	ci.draw_rect(Rect2(p + Vector2(-0.5, -1), Vector2(TILE + 1, 11)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(0, 0.5), Vector2(TILE, 8)), col(pal, "marble"))
	ci.draw_rect(Rect2(p + Vector2(0, 0.5), Vector2(TILE, 2.5)), col(pal, "marble_lip"))
	ci.draw_rect(Rect2(p + Vector2(0, 5), Vector2(TILE, 1)), col(pal, "gold"))
	ci.draw_rect(Rect2(p + Vector2(0, 6.5), Vector2(TILE, 2)), col(pal, "marble_shade"))
	if pal.has("trim"):
		ci.draw_rect(Rect2(p + Vector2(0, 3), Vector2(TILE, 1)), pal["trim"])
	if not left:
		ci.draw_rect(Rect2(p + Vector2(-2, -1), Vector2(3, 11)), OUTLINE)
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 1, -1), Vector2(3, 11)), OUTLINE)
	if (x + y) % 3 == 0 or not left:
		var bx := p.x + (7.0 if not left else 13.0)
		tb.quad(Vector2(bx - 1, p.y + 8.5), Vector2(bx + 9, p.y + 8.5), Vector2(bx + 5, p.y + 16), Vector2(bx + 1, p.y + 16), OUTLINE)
		tb.quad(Vector2(bx + 0.8, p.y + 9), Vector2(bx + 7.4, p.y + 9), Vector2(bx + 4.2, p.y + 14.2), Vector2(bx + 1.8, p.y + 14.2), col(pal, "marble_shade"))
		tb.line(Vector2(bx + 0.8, p.y + 9.6), Vector2(bx + 7.4, p.y + 9.6), 1.0, col(pal, "gold"))


static func _crumble(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, q: Vector2, pal: Dictionary) -> void:
	## % : cracked masonry that gives way (no gold: it has lost its leaf).
	ci.draw_rect(Rect2(q + Vector2(-0.5, -1), Vector2(TILE + 1, 13)), OUTLINE)
	ci.draw_rect(Rect2(q + Vector2(1, 0.5), Vector2(TILE - 2, 10)), col(pal, "slab"))
	ci.draw_rect(Rect2(q + Vector2(1, 0.5), Vector2(TILE - 2, 3)), col(pal, "slab_lip"))
	ci.draw_rect(Rect2(q + Vector2(1, 8), Vector2(TILE - 2, 2.5)), col(pal, "shade"))
	var k := _hash(x, y)
	tb.polyline(PackedVector2Array([q + Vector2(6 + k * 10, 1), q + Vector2(10 + k * 10, 6), q + Vector2(8 + k * 10, 10.5)]), 1.6, CRACK)
	tb.polyline(PackedVector2Array([q + Vector2(22, 1.5), q + Vector2(19, 7), q + Vector2(24, 10.5)]), 1.4, CRACK)
	# Chips already fallen from its lower edge.
	tb.tri(q + Vector2(13, 10.5), q + Vector2(17, 10.5), q + Vector2(15, 13.5), OUTLINE)


static func _teeth(ci: CanvasItem, tb, x: int, y: int, p: Vector2, up: bool, pal: Dictionary) -> void:
	## Spikes: glass teeth set in a lead strip: dark-edged shards of one
	## jewel colour a cell (they read as sharp first), each with a pale core.
	var base_y := p.y + TILE if up else p.y
	var tip_y := p.y + TILE * 0.34 if up else p.y + TILE * 0.66
	var strip := Rect2(p.x, base_y - 5, TILE, 5) if up else Rect2(p.x, base_y, TILE, 5)
	ci.draw_rect(strip.grow(1.0), OUTLINE)
	ci.draw_rect(strip, col(pal, "lead"))
	ci.draw_rect(Rect2(strip.position + Vector2(0, 1 if up else 3), Vector2(TILE, 1)), col(pal, "lead_hi"))
	var ps := panes(pal)
	var c: Color = ps[int(_hash(x, y + 29) * 997.0) % ps.size()]
	var e := -1.2 if up else 1.2
	var dy := 1.0 if up else -1.0
	for i in 4:
		var x0 := p.x + i * 8.0
		var tip := Vector2(x0 + 4.0 + (0.8 if i % 2 == 0 else -0.8), tip_y + (0.0 if i % 2 == 0 else 3.0 * dy))
		tb.tri(Vector2(x0 - 0.6, base_y), tip - Vector2(0, 1.6 * dy), Vector2(x0 + 8.6, base_y), OUTLINE)
		tb.tri(Vector2(x0 + 1.2, base_y + e), tip + Vector2(0, 1.4 * dy), Vector2(x0 + 4.2, base_y + e), c.lightened(0.2))
		tb.tri(Vector2(x0 + 4.2, base_y + e), tip + Vector2(0, 1.4 * dy), Vector2(x0 + 6.8, base_y + e), c.darkened(0.35))
		# The core: the jewel's own pale glint (never the prism-white tell accent).
		tb.line(Vector2(x0 + 4.0, base_y + e * 2.0), tip + Vector2(0, 2.4 * dy), 1.2, Color(c.lightened(0.62), 0.9))


static func run_start(level: RefCounted, x: int, y: int) -> int:
	## The first column of the glass run cell (x, y) belongs to.
	## By the level file's tiles (_orig), so a run keeps its colour for the
	## whole level: a pane shattering in its middle doesn't recolour the rest.
	var sx := x
	while sx > 0 and _orig(level, sx - 1, y) == GLASS:
		sx -= 1
	return sx


static func pane_color(level: RefCounted, x: int, y: int, pal: Dictionary) -> Color:
	## A pane's colour: one per horizontal run, by hash of where it starts.
	var ps := panes(pal)
	var sx := run_start(level, x, y)
	return ps[int(_hash(sx, y) * 997.0) % ps.size()]


static func _pane(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	## G: a jewel pane in black lead: the came round the run and between its
	## panes, the jewel at 0.85, a lighter inner pane, a diagonal gleam and,
	## on one in three, a painted star, leaf or bell.
	var c := pane_color(level, x, y, pal)
	var came := col(pal, "came")
	var left: bool = level.tile(x - 1, y) == GLASS
	var right: bool = level.tile(x + 1, y) == GLASS
	var up := _solid(level, x, y - 1)
	var down: bool = level.tile(x, y + 1) == GLASS
	var l := 1.0 if left else 2.5
	var r := 1.0 if right else 2.5
	var tp := 1.0 if level.tile(x, y - 1) == GLASS else 2.5
	var bt := 1.0 if down else 2.5
	ci.draw_rect(Rect2(p + Vector2(-0.5, -0.5), Vector2(TILE + 1, TILE + 1)), Color(came, 0.95))
	var inner := Rect2(p + Vector2(l, tp), Vector2(TILE - l - r, TILE - tp - bt))
	ci.draw_rect(inner, Color(c, 0.85))
	ci.draw_rect(inner.grow(-4.5), Color(c.lightened(0.35), 0.40))
	if not up:
		# A standing top: a pale bevel on the lead so the edge reads.
		ci.draw_rect(Rect2(p + Vector2(0, 0), Vector2(TILE, 2)), Color(c.lightened(0.55), 0.95))
		if pal.has("trim"):
			ci.draw_rect(Rect2(p + Vector2(0, 2), Vector2(TILE, 1)), pal["trim"])
	# The gleam: a diagonal band.
	var g0 := p + Vector2(l + 3, TILE - bt - 4)
	tb.quad(g0, g0 + Vector2(5, 0), g0 + Vector2(17, -17), g0 + Vector2(12, -17), Color(1, 1, 1, 0.22))
	tb.line(g0 + Vector2(9, -2), g0 + Vector2(19, -12), 1.2, Color(1, 1, 1, 0.3))
	var m := _hash(x + 17, y + 3)
	if m < 0.34:
		var mc := Color(c.lightened(0.6), 0.65)
		var cc := p + Vector2(16, 17)
		if m < 0.12:
			tb.quad(cc + Vector2(0, -5), cc + Vector2(1.4, 0), cc + Vector2(0, 5), cc + Vector2(-1.4, 0), mc)
			tb.quad(cc + Vector2(-5, 0), cc + Vector2(0, 1.4), cc + Vector2(5, 0), cc + Vector2(0, -1.4), mc)
		elif m < 0.23:
			tb.quad(cc + Vector2(-5, 3), cc + Vector2(-1, -2), cc + Vector2(5, -4), cc + Vector2(1, 2), mc)
			tb.line(cc + Vector2(-5, 3), cc + Vector2(5, -4), 0.9, Color(c.darkened(0.2), 0.8))
		else:
			# A little bell.
			tb.convex(PackedVector2Array([cc + Vector2(-1.8, -4), cc + Vector2(1.8, -4), cc + Vector2(3.4, 1.5), cc + Vector2(5, 3.4),
					cc + Vector2(-5, 3.4), cc + Vector2(-3.4, 1.5)]), mc)
			tb.circle(cc + Vector2(0, 4.6), 1.1, mc, 6)


static func _dawn_ghost(ci: CanvasItem, tb, p: Vector2, pal: Dictionary) -> void:
	## Unlit dawnglass: air, drawn as a ghost at alpha 0.30 so you can plan.
	var d := col(pal, "dawn")
	ci.draw_rect(Rect2(p + Vector2(1, 1), Vector2(TILE - 2, 8)), Color(d, 0.07))
	var c2 := Color(d, 0.30)
	ci.draw_rect(Rect2(p + Vector2(1, 0), Vector2(TILE - 2, 1.5)), c2)
	ci.draw_rect(Rect2(p + Vector2(1, 8.5), Vector2(TILE - 2, 1.5)), c2)
	ci.draw_rect(Rect2(p + Vector2(1, 0), Vector2(1.5, 10)), c2)
	ci.draw_rect(Rect2(p + Vector2(TILE - 2.5, 0), Vector2(1.5, 10)), c2)


static func _dawn_lit(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	## Lit dawnglass: a slab of bright pale gold in a thin lead, a sun's rays
	## painted on it. (The feature fades it toward the ghost: its clock.)
	var d := col(pal, "dawn")
	var left: bool = level.tile(x - 1, y) == DAWN_ON
	var right: bool = level.tile(x + 1, y) == DAWN_ON
	ci.draw_rect(Rect2(p + Vector2(-0.5, -1), Vector2(TILE + 1, 12)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(0.5 if left else 1.5, 0), Vector2(TILE - (0.5 if left else 1.5) - (0.5 if right else 1.5), 10)), d)
	ci.draw_rect(Rect2(p + Vector2(0.5, 0), Vector2(TILE - 1, 3)), col(pal, "dawn_hi"))
	ci.draw_rect(Rect2(p + Vector2(0.5, 8), Vector2(TILE - 1, 2)), d.darkened(0.18))
	if pal.has("trim"):
		ci.draw_rect(Rect2(p + Vector2(0.5, 3), Vector2(TILE - 1, 1)), pal["trim"])
	var c := p + Vector2(16, 9)
	for k in 5:
		var a := PI + PI * (k + 0.5) / 5.0
		tb.line(c + Vector2(cos(a), sin(a)) * 2.5, c + Vector2(cos(a), sin(a)) * 7.0, 1.0, Color(1, 1, 1, 0.45))


# ---------------------------------------------------------------- live looks (the glass feature calls these)

static func draw_pane_overlay(ci: CanvasItem, tb, cell: Vector2i, strain: float, state: String, age: float, pal := {}) -> void:
	## Over a pane each frame: its cracks (at strain 0.4, more at 0.8: a white
	## core at least 1.5 px on a dark edge), the 0.35 s flash before it goes
	## (white, blinking every 0.1 s), and the shimmer of it re-forming (0.6 s).
	var p := Vector2(cell.x * TILE, cell.y * TILE)
	match state:
		"whole":
			if strain >= 0.4:
				_cracks(tb, p, cell, 1 if strain < 0.8 else 2, 1.0)
		"flash":
			var on := fmod(age, 0.1) < 0.05
			ci.draw_rect(Rect2(p + Vector2(1, 1), Vector2(TILE - 2, TILE - 2)), Color(1, 1, 1, 0.85 if on else 0.35))
			_cracks(tb, p, cell, 3, 1.0)
		"shimmer":
			var k := clampf(age / 0.6, 0.0, 1.0)
			var c := Color(col(pal, "accent"), 0.15 + 0.35 * k)
			ci.draw_rect(Rect2(p + Vector2(0, 0), Vector2(TILE * k, 2)), c)
			ci.draw_rect(Rect2(p + Vector2(TILE * (1.0 - k), TILE - 2), Vector2(TILE * k, 2)), c)
			ci.draw_rect(Rect2(p + Vector2(2, 2), Vector2(TILE - 4, TILE - 4)), Color(col(pal, "accent"), 0.08 * k))
			var s := p + Vector2(4 + 24 * k, 6 + 20 * (1.0 - k))
			tb.quad(s + Vector2(0, -3), s + Vector2(0.8, 0), s + Vector2(0, 3), s + Vector2(-0.8, 0), Color(1, 1, 1, 0.8))
			tb.quad(s + Vector2(-3, 0), s + Vector2(0, 0.8), s + Vector2(3, 0), s + Vector2(0, -0.8), Color(1, 1, 1, 0.8))


static func _cracks(tb, p: Vector2, cell: Vector2i, stage: int, a: float) -> void:
	## A star of cracks from a point near where he'd stand, growing by stage.
	var o := p + Vector2(10.0 + _hash(cell.x, cell.y) * 12.0, 3.0)
	var arms := [[Vector2(-7, 8), Vector2(-9, 16)], [Vector2(5, 9), Vector2(9, 18)], [Vector2(1, 6), Vector2(-2, 22)]]
	if stage >= 2:
		arms += [[Vector2(-9, 4), Vector2(-12, 7)], [Vector2(8, 3), Vector2(13, 11)], [Vector2(3, 14), Vector2(8, 25)]]
	if stage >= 3:
		arms += [[Vector2(-4, 16), Vector2(-10, 26)], [Vector2(11, 14), Vector2(12, 26)]]
	for arm in arms:
		var pts := PackedVector2Array([o, o + (arm[0] as Vector2), o + (arm[1] as Vector2)])
		tb.polyline(pts, 3.2, Color(0.08, 0.05, 0.12, 0.75 * a))
	for arm in arms:
		var pts := PackedVector2Array([o, o + (arm[0] as Vector2), o + (arm[1] as Vector2)])
		tb.polyline(pts, 1.6, Color(1, 1, 1, 0.95 * a))
	tb.circle(o, 2.0, Color(1, 1, 1, 0.9 * a), 6)


static func draw_dawn_overlay(ci: CanvasItem, tb, cell: Vector2i, k: float, flicker: bool, t: float, pal := {}) -> void:
	## Over lit dawnglass: k 1 is bright, 0 its ghost (the feature passes its
	## lamp's last 5 s as k); flicker is the 0.35 s before it goes (a blink);
	## t the feature clock (world.ftime).
	var p := Vector2(cell.x * TILE, cell.y * TILE)
	var ghost := Color("1a1428")
	var wash := (1.0 - clampf(k, 0.0, 1.0)) * 0.72
	if flicker:
		wash = 0.8 if fmod(t, 0.08) < 0.04 else 0.25
	if wash > 0.01:
		ci.draw_rect(Rect2(p + Vector2(0.5, 0), Vector2(TILE - 1, 10)), Color(ghost, wash))
	# A shimmer sweeping along it while it's bright.
	if k > 0.3 and not flicker:
		var s := fposmod(t * 40.0 + cell.x * 11.0, 64.0) - 16.0
		if s >= 0.0 and s < TILE - 4.0:
			tb.quad(p + Vector2(s, 0), p + Vector2(s + 4, 0), p + Vector2(s + 1, 10), p + Vector2(s - 3, 10), Color(1, 1, 1, 0.35 * k))


# ---------------------------------------------------------------- the wind

static func lean_of(ph: Dictionary) -> float:
	## How far the wind bends a flame or a cape, 0..1 (times the zone's
	## direction): it starts leaning at the tell (up to 0.5: the lean is part
	## of the tell), full in the gust.
	var k := clampf(float(ph.get("k", 0.0)), 0.0, 1.0)
	match str(ph.get("state", "calm")):
		"tell":
			return 0.5 * k * k * (3.0 - 2.0 * k)
		"gust":
			return 0.5 + 0.5 * k
	return 0.0


static func _is_top(level: RefCounted, cx: int, ty: int) -> bool:
	## A walkable top: something to stand on with no solid over it.
	return ty >= 1 and ty < level.height and LevelData.is_floor(level.tile(cx, ty)) and not is_solid_id(level.tile(cx, ty - 1))


static func band_floor(level: RefCounted, z: Dictionary, view: Rect2, hero := Rect2(), feet := FEET_LINE) -> float:
	## The floor a zone's wind blows over (world y): the walkable top in the
	## hero's column (clamped into the zone; the view's middle without a hero)
	## nearest the camera's ground line (view.y + feet, where the camera holds
	## his feet: world.feet_line() + look_up()), within GROUND_UP px over it
	## and GROUND_DOWN under it. So a roof, a spur or a floating chunk over
	## his head is never taken for his floor, a pit's bottom under a gap is
	## ignored, and over the void (or mid-jump over a gap) it is the ground
	## line itself. Never lower than GROUND_SLACK under that line (the thumbs).
	var ground := view.position.y + feet
	var ref_x := hero.get_center().x if hero.size.x > 0.0 else view.get_center().x
	var cx := clampi(floori(ref_x / TILE), int(z["x0"]), int(z["x1"]))
	var best := INF
	for ty in range(maxi(ceili((ground - GROUND_UP) / TILE), 1), mini(floori((ground + GROUND_DOWN) / TILE), level.height - 1) + 1):
		if _is_top(level, cx, ty) and absf(ty * TILE - ground) < absf(best - ground):
			best = float(ty * TILE)
	if best == INF:
		return ground
	return minf(best, ground + GROUND_SLACK)


static func gust_band(level: RefCounted, z: Dictionary, view: Rect2, hero := Rect2(), feet := FEET_LINE) -> Rect2:
	## The air a zone's wind is drawn in: across the zone (inside the view),
	## BAND_ROWS tiles of air over band_floor() (the hero's own floor), never
	## above the HUD's rows. The wind is everywhere in the zone's columns
	## (spec §3.2: top to bottom); this is only where it is drawn: around him.
	## A roof over him doesn't cut it: the ribbons fade inside masonry
	## (draw_gust_glow), so the air under the roof keeps its low lanes.
	var zx0 := float(z["x0"]) * TILE
	var zx1 := (float(z["x1"]) + 1.0) * TILE
	var x0 := maxf(zx0, view.position.x - 40.0)
	var x1 := minf(zx1, view.end.x + 40.0)
	if x1 <= x0:
		return Rect2()
	var floor_y := band_floor(level, z, view, hero, feet)
	var top := maxf(floor_y - BAND_ROWS * TILE, view.position.y + HUD_TOP)
	if floor_y - top < 24.0:
		return Rect2()
	return Rect2(x0, top, x1 - x0, floor_y - top - 4.0)


static func lane_rise(u: float) -> float:
	## How high over the band's floor line (band.end.y) a lane or a speck
	## rides, for u 0..1: denser low down, where he is (the lowest lanes
	## cross his chest, about 22 px over his feet), so a low roof over the
	## path still leaves four lanes under it. Fixed in px, never scaled by the
	## band's height, so nothing jumps when the HUD clips the band's top.
	return (BAND_ROWS * TILE) * (0.07 + 0.78 * pow(clampf(u, 0.0, 1.0), 1.35))


static func _r(i: int, salt: float) -> float:
	return fposmod(sin(i * 12.9898 + salt * 78.233) * 43758.5453, 1.0)


static func _in_air(level: RefCounted, p: Vector2) -> bool:
	var t: int = level.tile(floori(p.x / TILE), floori(p.y / TILE))
	return not is_solid_id(t)


static func draw_gust_glow(glow: CanvasItem, tb, level: RefCounted, z: Dictionary, ph: Dictionary, view: Rect2, t: float, pal := {}, avoid := Rect2(), feet := FEET_LINE) -> void:
	## The sanctum's wind over one zone, above the dark (so it reads in it).
	## Calm: nothing. The tell (1.0 s on Dusk): thin faint streaks begin to run
	## through the zone and a few wisps gather and curl at its upwind edge,
	## specks lift. The gust: long soft ribbons stream through the band, dust
	## and glass glints tumble with them. avoid (the hero's rect) is where the
	## band sits (his column's floor: gust_band) and keeps them faint across
	## his body; feet is the camera's ground line (world.feet_line() +
	## world.look_up(); FEET_LINE when the caller has none).
	var state := str(ph.get("state", "calm"))
	if state == "calm":
		return
	var band := gust_band(level, z, view, avoid, feet)
	if band.size.x <= 0.0:
		return
	var k := clampf(float(ph.get("k", 0.0)), 0.0, 1.0)
	var telling := state == "tell"
	var dir := 1.0 if float(z.get("dir", 1)) >= 0.0 else -1.0
	var zx0 := float(z["x0"]) * TILE
	var zx1 := (float(z["x1"]) + 1.0) * TILE
	var span := zx1 - zx0
	var salt := float(z["x0"]) * 0.37 + float(z["x1"]) * 0.11
	var fl := band.end.y
	# A dark theme's floor for the tell (voidnave's gust_tell_min: the rev5
	# review read 5-3's tell by the flame's lean alone at 30% brightness; the
	# phone's readability floor is 0.30).
	var tmin := float(pal.get("gust_tell_min", 0.0)) if pal.get("gust_tell_min") != null else 0.0
	var lanes := 6
	for i in lanes:
		var r1 := _r(i, salt)
		var r2 := _r(i, salt + 1.7)
		var r3 := _r(i, salt + 3.1)
		var y := fl - lane_rise((i + 0.5) / float(lanes)) + (r3 - 0.5) * 10.0
		var length: float
		var head: float
		var a: float
		var w: float
		var curl := false
		if telling:
			if i < 2:
				# Wisps gathering and curling at the upwind edge.
				length = (26.0 + 22.0 * r1) * (0.4 + 0.6 * k)
				head = fposmod(t * (50.0 + 25.0 * r2) + r2 * 40.0, span * 0.35) + length * 0.3
				a = maxf(0.16 + 0.26 * k, tmin * (0.6 + 0.4 * k))
				w = 1.8 + 0.6 * r3
				curl = true
			else:
				# Thin streaks: the air beginning to move.
				length = 60.0 + 60.0 * r1
				head = fposmod(t * (110.0 + 50.0 * r2) + r2 * span, span + length)
				a = maxf((0.06 + 0.22 * k) * (0.7 + 0.3 * r3), tmin * (0.5 + 0.5 * k))
				w = 0.9 + 0.3 * r3
		else:
			length = 150.0 + 110.0 * r1
			head = fposmod(t * (300.0 + 100.0 * r2) + r2 * span, span + length)
			a = (0.26 + 0.2 * r3) * (0.35 + 0.65 * k)
			w = 1.7 + 1.0 * r3
		var hx := (zx0 + head) if dir > 0.0 else (zx1 - head)
		_ribbon(tb, level, hx, y, dir, length, w, a, t + i * 1.3, curl, band, avoid)
	# Dust and glints carried along.
	var specks := 4 if telling else 12
	for j in specks:
		var q1 := _r(j + 20, salt)
		var q2 := _r(j + 20, salt + 2.3)
		var sp := (35.0 + 30.0 * q2) if telling else (300.0 + 140.0 * q2)
		var room := span * 0.45 if telling else span
		var d := fposmod(t * sp + q1 * span, room)
		var px := (zx0 + d) if dir > 0.0 else (zx1 - d)
		var py := fl - lane_rise(0.05 + 0.9 * _r(j + 40, salt)) + sin(t * 3.1 + j * 1.7) * 6.0 - (d / room) * (10.0 if telling else 4.0)
		var sp_p := Vector2(px, py)
		if not band.grow(8.0).has_point(sp_p) or not _in_air(level, sp_p):
			continue
		var fa := clampf(minf(d, room - d) / 30.0, 0.0, 1.0)
		if j % 3 == 2:
			# A glass glint, tumbling: the prism-white star.
			var s := 1.6 + 1.2 * q2
			var rot := t * (6.0 + 4.0 * q1) + j
			var u := Vector2(cos(rot), sin(rot)) * s * 2.0
			var v := u.orthogonal() * 0.28
			var ga := (0.55 + 0.45 * sin(t * 13.0 + j * 2.0)) * (0.5 + 0.5 * k) * fa
			tb.quad(sp_p - u, sp_p + v, sp_p + u, sp_p - v, Color(GLINT, ga))
			tb.quad(sp_p - u.orthogonal() * 0.7, sp_p + v.orthogonal() * 0.7, sp_p + u.orthogonal() * 0.7, sp_p - v.orthogonal() * 0.7, Color(GLINT, ga * 0.8))
		elif j % 3 == 1 and not telling:
			# A chip of coloured glass.
			var ps := panes(pal)
			var gc: Color = ps[j % ps.size()]
			var rot2 := t * 5.0 + j
			var e := Vector2(cos(rot2), sin(rot2)) * 2.4
			tb.tri(sp_p + e, sp_p + e.rotated(2.3) * 0.8, sp_p + e.rotated(-2.1) * 0.9, Color(gc.lightened(0.3), 0.7 * k * fa))
		else:
			var ds := 1.4 + 1.0 * q2
			tb.quad(sp_p, sp_p + Vector2(ds * 1.6 * dir, -ds * 0.3), sp_p + Vector2(ds * 1.8 * dir, ds * 0.6), sp_p + Vector2(0, ds), Color(DUST, (0.35 + 0.3 * k) * fa))


static func _ribbon(tb, level: RefCounted, hx: float, y: float, dir: float, length: float, w: float, a: float, ph: float, telling: bool, band: Rect2, avoid := Rect2()) -> void:
	## One soft ribbon: a tapered, gently waving strip, brightest along its
	## core and fading to nothing at its edges (so it has no hard outline),
	## thickest behind its head and gone at its tail. The tell's ribbons curl
	## up at the head. A point outside the band or inside a wall fades out.
	## Built as one strip with shared vertices (no seams where segments meet).
	var n := 10
	if tb.vertex_count() + n * 4 > tb.MAX_VERTICES:
		return
	var pts := PackedVector2Array()
	var ws := PackedFloat32Array()
	var al := PackedFloat32Array()
	for s in n:
		var f := float(s) / float(n - 1)       # 0 tail .. 1 head
		var x := hx - dir * length * (1.0 - f)
		var yy := y + sin(x / 52.0 + ph * 2.2) * (2.5 + 2.5 * f)
		if telling and f > 0.55:
			var c := (f - 0.55) / 0.45
			yy -= c * c * 8.0
			x -= dir * c * c * 4.0
		var p := Vector2(x, yy)
		pts.append(p)
		var prof := sin(pow(f, 1.6) * PI)
		ws.append(maxf(w * prof, 0.3))
		var inside := band.grow(6.0).has_point(p) and _in_air(level, p)
		var fade := 0.3 if avoid.size.x > 0.0 and avoid.grow(6.0).has_point(p) else 1.0
		al.append(a * clampf(prof * 1.4, 0.0, 1.0) * (1.0 if inside else 0.0) * fade)
	var i0: int = tb.points.size()
	for s in n:
		var d := (pts[mini(s + 1, n - 1)] - pts[maxi(s - 1, 0)])
		var o := d.normalized().orthogonal() if d.length_squared() > 1e-6 else Vector2(0, 1)
		var core := o * ws[s] * 0.55
		var soft := o * ws[s] * 2.6
		var c := Color(WIND, al[s])
		var e := Color(WIND, 0.0)
		tb.points.append_array(PackedVector2Array([pts[s] + soft, pts[s] + core, pts[s] - core, pts[s] - soft]))
		tb.colors.append_array(PackedColorArray([e, c, c, e]))
	for s in n - 1:
		var q := i0 + s * 4
		var r := q + 4
		for k in 3:
			tb.indices.append_array(PackedInt32Array([q + k, r + k, r + k + 1, q + k, r + k + 1, q + k + 1]))


# ---------------------------------------------------------------- pennants

static func _orig(level: RefCounted, x: int, y: int) -> int:
	## What the level file has at (x, y), whatever broke or melted since.
	return level.original_tile(Vector2i(x, y)) if level.has_method("original_tile") else level.tile(x, y)


static func _steady(level: RefCounted, x: int, y: int) -> bool:
	## Masonry a pennant can hang from or stand on for the whole level: stone
	## or a ledge, never glass, a crumble, cracked B, false stone, rime, ice
	## or a belt (what breaks, melts or moves).
	var t := _orig(level, x, y)
	return t == LevelData.STONE or t == LevelData.LEDGE


static func path_floor(level: RefCounted, cx: int) -> int:
	## The path's floor in column cx at build (no hero yet): the lowest
	## walkable top with two rows of air over it (so a roof or a spur over the
	## path is never taken for it), or -1 over the void.
	for ty in range(level.height - 1, 1, -1):
		if _is_top(level, cx, ty) and not is_solid_id(level.tile(cx, ty - 2)):
			return ty
	return -1


static func pennant_anchors(level: RefCounted, z: Dictionary) -> Array:
	## Where a zone's pennants hang, once at build:
	## [{p: Vector2, pole: bool, foot?: Vector2, cell: Vector2i}] (cell: the
	## masonry it hangs from or stands on). From the upwind edge in: under the
	## roof nearest over the path where one is (hung from its underside, over
	## 2 to 6 rows of air), else on a short pole on the path's floor;
	## every PENNANT_EVERY columns under a roof, every 2 * PENNANT_EVERY on
	## poles. Only on steady masonry (_steady): a column of glass, crumble or
	## rime is passed over for the next one, so nothing is ever left hanging
	## in the air when a pane shatters.
	var out := []
	var c0 := int(z["x0"])
	var c1 := int(z["x1"])
	var dir := 1 if float(z.get("dir", 1)) >= 0.0 else -1
	var cx := c0 + 1 if dir > 0 else c1 - 1
	var guard := 0
	while cx >= c0 and cx <= c1 and guard < 512:
		guard += 1
		var step := 1
		var ft := path_floor(level, cx)
		if ft > 0:
			# The roof nearest over that floor, with at least 2 rows of air under it.
			var roof := -1
			for ty in range(ft - 3, maxi(ft - 8, -1), -1):
				if is_solid_id(level.tile(cx, ty)) or LevelData.is_ledge(level.tile(cx, ty)):
					roof = ty
					break
			if roof >= 0 and _steady(level, cx, roof):
				out.append({"p": Vector2(cx * TILE + 16, (roof + 1) * TILE), "pole": false, "cell": Vector2i(cx, roof)})
				step = PENNANT_EVERY
			elif roof < 0 and _steady(level, cx, ft):
				out.append({"p": Vector2(cx * TILE + 16, ft * TILE - 30), "pole": true, "foot": Vector2(cx * TILE + 16, ft * TILE),
						"cell": Vector2i(cx, ft)})
				step = PENNANT_EVERY * 2
		cx += step * dir
	return out


static func draw_gust_under(ci: CanvasItem, tb, z: Dictionary, ph: Dictionary, anchors: Array, t: float, tex := {}, level: RefCounted = null) -> void:
	## The pennants, under the dark (seen in light): slack at rest with a
	## small sway, lifting as the tell begins, flying full in the gust,
	## mirrored to blow the zone's way. tex: {"slack", "lift", "full"} ->
	## Texture2D (props_w5.py's pennant_*; loaded by the caller at build),
	## else a code-drawn pennant. With the level, one whose masonry is gone
	## now is skipped (pennant_anchors never picks such, but a mover of the
	## feature's own could still take it).
	var state := str(ph.get("state", "calm"))
	var k := clampf(float(ph.get("k", 0.0)), 0.0, 1.0)
	var dir := 1.0 if float(z.get("dir", 1)) >= 0.0 else -1.0
	var frame := "slack"
	if state == "tell":
		frame = "lift"
	elif state == "gust":
		frame = "full" if k > 0.25 else "lift"
	for i in anchors.size():
		var an: Dictionary = anchors[i]
		if level != null and an.get("cell") is Vector2i:
			var cell: Vector2i = an["cell"]
			var there: int = level.tile(cell.x, cell.y)
			if not (is_solid_id(there) or LevelData.is_ledge(there)):
				continue
		var p: Vector2 = an["p"]
		if bool(an.get("pole", false)):
			var foot: Vector2 = an.get("foot", p + Vector2(0, 30))
			ci.draw_rect(Rect2(p.x - 1.5, p.y - 2.0, 3.0, foot.y - p.y + 2.0), OUTLINE)
			ci.draw_rect(Rect2(p.x - 0.75, p.y - 1.0, 1.5, foot.y - p.y), Color("b8963a"))
			ci.draw_rect(Rect2(p.x - 2.5, p.y - 4.0, 5.0, 3.0), Color("d8b24a"))
		var flap := sin(t * (14.0 if frame == "full" else 3.0) + i * 1.9)
		var tx = tex.get(frame, null)
		if tx is Texture2D:
			var sz: Vector2 = (tx as Texture2D).get_size() * 0.25
			var sy := 1.0 + (0.06 * flap if frame == "full" else 0.0)
			# The texture hangs from its pole's top, (8, 2) units = (4, 1) px.
			ci.draw_set_transform(p, (0.03 * flap if frame == "slack" else 0.0) * dir, Vector2(dir, sy))
			ci.draw_texture_rect(tx, Rect2(Vector2(-4.0, -1.0), sz), false)
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		else:
			_pennant_code(tb, p, dir, frame, flap)


static func _pennant_code(tb, p: Vector2, dir: float, frame: String, flap: float) -> void:
	## A swallow-tailed pennant from p, by frame (the stand-in for its SVG).
	var cloth := Color("6a2e5a")
	var hem := Color("d8b24a")
	var ang: float
	match frame:
		"full":
			ang = 0.08 + 0.05 * flap
		"lift":
			ang = 0.75
		_:
			ang = 1.35 + 0.05 * flap
	var along := Vector2(cos(ang) * dir, sin(ang))
	var across := Vector2(-along.y, along.x) * dir
	var root := p + Vector2(0, 2)
	var l := 20.0
	var h := 7.0
	var tip := root + along * l
	var tip2 := tip + across * h
	var notch := tip - along * 5.0 + across * h * 0.5
	var bot := root + across * h
	# Its outline, then the cloth in two convex pieces (a swallow tail).
	tb.convex(PackedVector2Array([root - across * 0.9 - along * 0.9, tip + along * 1.0 - across * 0.9, tip2 + along * 1.0 + across * 0.9, bot + across * 0.9 - along * 0.9]), OUTLINE)
	tb.tri(root, tip, notch, cloth)
	tb.convex(PackedVector2Array([root, notch, tip2, bot]), cloth)
	tb.line(root, tip, 1.2, hem)
	tb.rect(Rect2(p + Vector2(-1.5, -1.0), Vector2(3.0, 4.0)), hem)
