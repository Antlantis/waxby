extends RefCounted
## The plain tile painter: the fallback when a theme's painter file is missing,
## the stand-in look for v3's tiles in a v2 theme (tile_view.gd asks it for
## any tile past v2's), and the reference painter for the art streams (A1's
## orchard/frost, A2's glass/hush follow the same shape).
##   static func paint_chunk(ci, tb, level, x0, x1, pal, world, y0, y1)   the painter contract (contract.md §12.4)
##   static func paint_cell(ci, tb, level, x, y, t, pal, world)   one cell
## A chunk is columns [x0, x1) by rows [y0, y1) (y1 -1: to the level's
## bottom); the chunk that reaches the bottom draws the bedrock under it too.
## Rects go straight to ci.draw_rect; every other shape into the TriBatch tb,
## flushed once at the end of the chunk (the caller flushes for paint_cell).
## No draw_circle / draw_colored_polygon / draw_polyline (test_render.gd).
## Greybox, cel-shaded, readable in the dark: an outline, a lit lip on every
## walkable top, a hard shade band. v3's tiles by id (contract.md §2.1):
## VINE 12, ROTTEN_VINE 13, ICE 14, FROST_LEDGE 15, RIME 16, BELT_L 17,
## BELT_R 18, GLASS 19, DAWNGLASS 20, DAWN_ON 21, STILL 22.

const LevelData := preload("res://scripts/level_data.gd")
const TILE := 32
const BEDROCK_ROWS := 5

const VINE := 12
const ROTTEN_VINE := 13
const ICE := 14
const FROST_LEDGE := 15
const RIME := 16
const BELT_L := 17
const BELT_R := 18
const GLASS := 19
const DAWNGLASS := 20
const DAWN_ON := 21
const STILL := 22
const V3_SOLID := [ICE, RIME, BELT_L, BELT_R, GLASS]

const OUTLINE := Color("17121f")
const CRACK := Color("20161e")
const DEFAULTS := {
	"stone": Color("4a3f5e"), "shade": Color("3a3150"), "lip": Color("7a6c96"), "mortar": Color("342b46"),
	"buried": Color("2a2238"), "buried_mortar": Color("231c30"), "brick": Color("62505e"),
	"brick_shade": Color("4a3a48"), "brick_lip": Color("8a7488"), "slab": Color("6a5a78"), "slab_lip": Color("9486a8"),
	"wood": Color("6b4a32"), "wood_lip": Color("9a7250"), "wood_shade": Color("4a3020"), "iron": Color("3a3a48"),
	"steel": Color("c4c8d8"), "steel_shade": Color("7e8296"),
	"vine": Color("6a8a4a"), "vine_lit": Color("a8c878"), "rot": Color("6a5a42"), "rot_lit": Color("9a8a66"),
	"ice": Color("7ea8c0"), "ice_lip": Color("e8fcff"), "ice_shade": Color("5a7e96"), "rime": Color("d8ecf4"),
	"belt": Color("3a3440"), "belt_lip": Color("8a7a5a"), "belt_mark": Color("c8a860"),
	"glass": Color(0.62, 0.72, 0.86, 0.55), "glass_lip": Color("f8f0ff"), "dawn": Color("f2d88a"), "still": Color("c8c8f0"),
}


static func col(pal: Dictionary, key: String) -> Color:
	return pal.get(key, DEFAULTS[key])


static func is_solid_id(t: int) -> bool:
	return LevelData.is_solid(t) or V3_SOLID.has(t)


static func paint_chunk(ci: CanvasItem, tb, level: RefCounted, x0: int, x1: int, pal: Dictionary, world: Node, y0 := 0, y1 := -1) -> void:
	var ye: int = level.height if y1 < 0 else y1
	tb.origin = Vector2(x0 * TILE, y0 * TILE)
	for x in range(x0, x1):
		for y in range(y0, ye):
			var t: int = level.tile(x, y)
			if t != LevelData.AIR:
				paint_cell(ci, tb, level, x, y, t, pal, world)
		if ye >= level.height and is_solid_id(level.tile(x, level.height - 1)):
			for y in range(level.height, level.height + BEDROCK_ROWS):
				ci.draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), col(pal, "buried").darkened(0.15 * (y - level.height + 1)))
	tb.flush(ci)


static func _solid(level: RefCounted, x: int, y: int) -> bool:
	if y >= level.height:
		return true
	return is_solid_id(level.tile(x, y))


static func _hash(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(absi(h) % 1000) / 1000.0


static func paint_cell(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, t: int, pal: Dictionary, world: Node) -> void:
	var p := Vector2(x * TILE, y * TILE)
	match t:
		LevelData.STONE, LevelData.FALSE_STONE:
			_block(ci, level, x, y, p, col(pal, "stone"), col(pal, "shade"), col(pal, "lip"), col(pal, "buried"))
		LevelData.BRICK:
			_block(ci, level, x, y, p, col(pal, "brick"), col(pal, "brick_shade"), col(pal, "brick_lip"), col(pal, "brick"))
			var a := p + Vector2(8 + _hash(x, y) * 8, 5)
			tb.polyline(PackedVector2Array([a, a + Vector2(5, 7), a + Vector2(1, 12), a + Vector2(7, 20), a + Vector2(4, 25)]), 2.0, CRACK)
		LevelData.LEDGE:
			_plank(ci, tb, level, x, y, p, col(pal, "wood"), col(pal, "wood_lip"), col(pal, "wood_shade"), LevelData.LEDGE)
		LevelData.CRUMBLE:
			if world == null or not world.has_method("ledge_present") or world.ledge_present(x, y):
				var sh: Vector2 = world.ledge_shake(x, y) if world != null and world.has_method("ledge_shake") else Vector2.ZERO
				var q := p + sh
				ci.draw_rect(Rect2(q + Vector2(-0.5, -1), Vector2(TILE + 1, 13)), OUTLINE)
				ci.draw_rect(Rect2(q + Vector2(1, 0.5), Vector2(TILE - 2, 10)), col(pal, "slab"))
				ci.draw_rect(Rect2(q + Vector2(1, 0.5), Vector2(TILE - 2, 3)), col(pal, "slab_lip"))
				var k := _hash(x, y)
				tb.polyline(PackedVector2Array([q + Vector2(6 + k * 10, 1), q + Vector2(10 + k * 10, 6), q + Vector2(8 + k * 10, 10)]), 1.5, CRACK)
		LevelData.SPIKES_UP, LevelData.SPIKES_DOWN:
			_spikes(ci, tb, p, t == LevelData.SPIKES_UP, pal)
		VINE, ROTTEN_VINE:
			if t == ROTTEN_VINE and world != null and world.has_method("vine_present") and not world.vine_present(x, y):
				return
			_vine(tb, level, x, y, p, t == ROTTEN_VINE, pal)
		ICE:
			_block(ci, level, x, y, p, col(pal, "ice"), col(pal, "ice_shade"), col(pal, "ice_lip"), col(pal, "ice").darkened(0.25))
			tb.line(p + Vector2(6, 22), p + Vector2(16, 10), 2.0, Color(col(pal, "ice_lip"), 0.55))
			tb.line(p + Vector2(18, 26), p + Vector2(24, 18), 1.5, Color(col(pal, "ice_lip"), 0.45))
		FROST_LEDGE:
			_plank(ci, tb, level, x, y, p, col(pal, "ice"), col(pal, "ice_lip"), col(pal, "ice_shade"), FROST_LEDGE)
			for i in 3:
				var ix := p.x + 5.0 + i * 10.0 + _hash(x + i, y) * 3.0
				tb.tri(Vector2(ix - 3, p.y + 9), Vector2(ix + 3, p.y + 9), Vector2(ix, p.y + 15 + _hash(x, y + i) * 4.0), col(pal, "ice_lip"))
		RIME:
			ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), OUTLINE)
			ci.draw_rect(Rect2(p + Vector2(1.5, 1.5), Vector2(TILE - 3, TILE - 3)), col(pal, "rime").darkened(0.18))
			for i in 4:
				var c := p + Vector2(6 + (i % 2) * 18 + _hash(x + i, y) * 4, 8 + floorf(i / 2.0) * 15)
				tb.tri(c + Vector2(0, -6), c + Vector2(4, 3), c + Vector2(-4, 3), col(pal, "rime"))
			ci.draw_rect(Rect2(p + Vector2(1.5, 1.5), Vector2(TILE - 3, 3)), col(pal, "ice_lip"))
		BELT_L, BELT_R:
			_block(ci, level, x, y, p, col(pal, "belt"), col(pal, "belt").darkened(0.3), col(pal, "belt_lip"), col(pal, "belt"))
			var d := -1.0 if t == BELT_L else 1.0
			for i in 2:
				var cx := p.x + 9.0 + i * 14.0
				tb.tri(Vector2(cx - 4 * d, p.y + 9), Vector2(cx + 4 * d, p.y + 14), Vector2(cx - 4 * d, p.y + 19), col(pal, "belt_mark"))
		GLASS:
			ci.draw_rect(Rect2(p + Vector2(0, 0), Vector2(TILE, TILE)), Color(OUTLINE, 0.6))
			ci.draw_rect(Rect2(p + Vector2(1.5, 1.5), Vector2(TILE - 3, TILE - 3)), col(pal, "glass"))
			if not _solid(level, x, y - 1):
				ci.draw_rect(Rect2(p + Vector2(0, 0), Vector2(TILE, 3)), col(pal, "glass_lip"))
			tb.line(p + Vector2(7, 24), p + Vector2(20, 8), 2.0, Color(col(pal, "glass_lip"), 0.5))
		DAWNGLASS:
			# Unlit: air to stand on, drawn as a faint promise (alpha 0.30).
			var c2 := Color(col(pal, "dawn"), 0.30)
			ci.draw_rect(Rect2(p + Vector2(1, 0), Vector2(TILE - 2, 2)), c2)
			ci.draw_rect(Rect2(p + Vector2(1, 9), Vector2(TILE - 2, 1.5)), c2)
			ci.draw_rect(Rect2(p + Vector2(1, 0), Vector2(1.5, 10)), c2)
			ci.draw_rect(Rect2(p + Vector2(TILE - 2.5, 0), Vector2(1.5, 10)), c2)
		DAWN_ON:
			ci.draw_rect(Rect2(p + Vector2(-0.5, -1), Vector2(TILE + 1, 12)), OUTLINE)
			ci.draw_rect(Rect2(p + Vector2(0.5, 0), Vector2(TILE - 1, 10)), col(pal, "dawn"))
			ci.draw_rect(Rect2(p + Vector2(0.5, 0), Vector2(TILE - 1, 3)), col(pal, "dawn").lightened(0.4))
		STILL:
			ci.draw_rect(Rect2(p + Vector2(0, 0), Vector2(TILE, 3)), Color(col(pal, "still"), 0.55))
			ci.draw_rect(Rect2(p + Vector2(0, 3), Vector2(TILE, 5)), Color(col(pal, "still"), 0.18))


static func _block(ci: CanvasItem, level: RefCounted, x: int, y: int, p: Vector2, fill: Color, shade: Color, lip: Color, buried: Color) -> void:
	var up := _solid(level, x, y - 1)
	var down := _solid(level, x, y + 1)
	var left := _solid(level, x - 1, y)
	var right := _solid(level, x + 1, y)
	var j := (_hash(x, y) - 0.5) * 0.06
	if up and down and left and right:
		ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), buried.lightened(j))
		return
	ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), fill.lightened(j))
	if not down:
		ci.draw_rect(Rect2(p + Vector2(0, TILE - 7), Vector2(TILE, 7)), shade)
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 5, 0), Vector2(5, TILE)), shade)
	if not up:
		ci.draw_rect(Rect2(p, Vector2(TILE, 4)), lip.lightened(j))
		ci.draw_rect(Rect2(p + Vector2(0, -1), Vector2(TILE, 2.5)), OUTLINE)
	if not down:
		ci.draw_rect(Rect2(p + Vector2(0, TILE - 1.5), Vector2(TILE, 2.5)), OUTLINE)
	if not left:
		ci.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2.5, TILE)), OUTLINE)
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 1.5, 0), Vector2(2.5, TILE)), OUTLINE)


static func _plank(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, wood: Color, lip: Color, shade: Color, same: int) -> void:
	var left: bool = level.tile(x - 1, y) == same
	var right: bool = level.tile(x + 1, y) == same
	ci.draw_rect(Rect2(p + Vector2(-0.5, -1), Vector2(TILE + 1, 11)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(0, 0.5), Vector2(TILE, 8)), wood)
	ci.draw_rect(Rect2(p + Vector2(0, 0.5), Vector2(TILE, 2.5)), lip)
	ci.draw_rect(Rect2(p + Vector2(0, 6), Vector2(TILE, 2.5)), shade)
	if not left:
		ci.draw_rect(Rect2(p + Vector2(-2, -1), Vector2(3, 11)), OUTLINE)
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 1, -1), Vector2(3, 11)), OUTLINE)
	if same == LevelData.LEDGE and ((x + y) % 2 == 0 or not left):
		var bx := p.x + (6.0 if not left else 12.0)
		tb.tri(Vector2(bx, p.y + 9), Vector2(bx + 9, p.y + 9), Vector2(bx, p.y + 19), OUTLINE)
		tb.tri(Vector2(bx + 1.5, p.y + 10), Vector2(bx + 6, p.y + 10), Vector2(bx + 1.5, p.y + 15), DEFAULTS["iron"])


static func _spikes(ci: CanvasItem, tb, p: Vector2, up: bool, pal: Dictionary) -> void:
	var base_y := p.y + TILE if up else p.y
	var tip_y := p.y + TILE * 0.4 if up else p.y + TILE * 0.6
	var strip := Rect2(p.x, base_y - 5, TILE, 5) if up else Rect2(p.x, base_y, TILE, 5)
	ci.draw_rect(strip.grow(1.0), OUTLINE)
	ci.draw_rect(strip, col(pal, "iron"))
	var e := -1.2 if up else 1.2
	var e2 := 2.5 if up else -2.5
	for i in 4:
		var x0 := p.x + i * 8.0
		tb.tri(Vector2(x0, base_y), Vector2(x0 + 4, tip_y), Vector2(x0 + 8, base_y), OUTLINE)
		tb.tri(Vector2(x0 + 1.4, base_y + e), Vector2(x0 + 4, tip_y + e2), Vector2(x0 + 6.6, base_y + e), col(pal, "steel"))
		tb.tri(Vector2(x0 + 4, tip_y + e2), Vector2(x0 + 6.6, base_y + e), Vector2(x0 + 4.6, base_y + e), col(pal, "steel_shade"))


static func _vine(tb, level: RefCounted, x: int, y: int, p: Vector2, rotten: bool, pal: Dictionary) -> void:
	## A climbable stem down the middle of the cell: an outline, the stem,
	## a lit rim on its left, a leaf or knot every other cell.
	var stem := col(pal, "rot" if rotten else "vine")
	var rim := col(pal, "rot_lit" if rotten else "vine_lit")
	var cx := p.x + TILE * 0.5
	var pts := PackedVector2Array()
	for k in 5:
		var yy := p.y + k * TILE / 4.0
		pts.append(Vector2(cx + sin((y * 4 + k) * 0.9 + x) * 3.0, yy))
	tb.polyline(pts, 7.0, OUTLINE)
	tb.polyline(pts, 4.5, stem)
	var rp := PackedVector2Array()
	for q in pts:
		rp.append(q + Vector2(-1.2, 0))
	tb.polyline(rp, 1.4, Color(rim, 0.8))
	if rotten:
		# Gaps and a sag: it won't hold long.
		tb.rect(Rect2(cx - 4, p.y + 13, 8, 3), OUTLINE)
	elif (x + y) % 2 == 0:
		var l := pts[2]
		var d := 1.0 if (y % 4) < 2 else -1.0
		tb.tri(l, l + Vector2(9 * d, -5), l + Vector2(6 * d, 3), OUTLINE)
		tb.tri(l + Vector2(1 * d, 0), l + Vector2(7.5 * d, -3.5), l + Vector2(5 * d, 1.5), rim)
