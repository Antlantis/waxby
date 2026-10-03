extends RefCounted
## World 3's tile painter, the Bone Orchard (A1; spec 11.3, p_artaudio 4.1).
## The painter contract (contract.md 12.4): paint_chunk draws one 16-column
## chunk, rects with ci.draw_rect, every other shape into the TriBatch tb,
## flushed once at the end. No draw_circle / draw_colored_polygon /
## draw_polyline (test_render.gd, test_world_art.gd).
##   #  stone     packed loam with bone fragments for mortar and a knuckle, a
##                moss fringe off every lit lip, hair roots under the bottoms;
##                one buried tile in nine holds a skull niche
##   F  false     drawn as its stone, with one tell the levels' signs name: a
##                root curling over its face ("Roots grow round hollow
##                places"), or in the rootvault a plaster skull in a niche on
##                an open face ("Some skulls here are only plaster"); real
##                niches sit only in buried stone
##   B  brick     coffin planks: three boards, two iron straps, the crack
##   =  ledge     a bark branch: rounded, a knot, twig stubs at its ends, a
##                leaf pair on every other cell
##   %  crumble   bone trellis: two bone rails, crossed bones, twine; it
##                rattles (world.ledge_shake) and is gone while fallen
##   ^ v spikes   brambles: four curved thorns a tile with bone-white tips
##                (at edge_lines' tip points, so the glow tips sit on them)
##   {  vine      a root-brown stem (5 px) with leaf pairs, a knot where it
##                hangs from stone, a sprig where it ends in air
##   }  rotten    grey and withered. Not drawn here (DRAW_ROTTEN false): a run
##                snaps and regrows while the chunk is cached, so the orchard
##                feature draws rotten runs each frame with vine_cell()
##   sealed door  a door cell the arena sealed (stone where the level had air):
##                roots grown shut (the root seal)
## In 3-4's arena (level.boss "rootmother") the wall behind Mother Gravebough
## (her `X` + 1 .. + 8, rows 2 .. 12: the quarter her arena reserves) is her
## root mass, and roots creep from it over the floor at her feet.
## Water is level_features.gd's; any other v3 tile is the plain painter's.

const LevelData := preload("res://scripts/level_data.gd")
const Plain := preload("res://scripts/tiles/plain.gd")
const TILE := 32
const BEDROCK_ROWS := 5
const VINE := 12
const ROTTEN_VINE := 13
const DRAW_ROTTEN := false        # the orchard feature draws rotten runs (they snap)
const VINE_X := 15.0              # the stem's centre in its cell (the feature's glow vein runs 13..16)

const OUTLINE := Color("140e0a")
const CRACK := Color("1c120c")
const DOOR_DARK := Color("1a120c")
const IRON := Color("3a3440")
const NICHE := Color("120e0a")
const SKULL_EYE := Color("2a2030")
const DEFAULTS := {
	"stone": Color("5a5242"), "shade": Color("463f32"), "lip": Color("9c9070"), "mortar": Color("3e382c"),
	"buried": Color("2a261c"), "buried_mortar": Color("221f17"), "brick": Color("6a4a36"), "brick_shade": Color("50362a"),
	"brick_lip": Color("8e6a4c"), "slab": Color("d8cca8"), "slab_lip": Color("f0e6c8"), "drip": Color("6e8a44"),
	"bone": Color("e6dcc0"), "bone_sh": Color("b8ab8a"), "root": Color("4a3526"), "root_hi": Color("6e4e36"),
	"leaf": Color("6e8a44"), "leaf_hi": Color("9ab86a"), "vein": Color("9ad07a"), "thorn": Color("5a3a2a"),
	"bark": Color("5e4230"), "bark_lip": Color("9c8058"),
	"rot": Color("8a8478"), "rot_hi": Color("b0aa9c"),
}


static func col(pal: Dictionary, key: String) -> Color:
	var c = pal.get(key, null)
	return c if c is Color else DEFAULTS[key]


static func _h(x: int, y: int, salt := 0) -> float:
	## 0..1 by cell (a mixed integer hash: neighbours don't repeat).
	return float(hash(Vector3i(x, y, salt)) % 1000) / 1000.0


static func _solid(level: RefCounted, x: int, y: int) -> bool:
	if y >= level.height:
		return true
	return Plain.is_solid_id(level.tile(x, y))


static func _sealed(level: RefCounted, x: int, y: int) -> bool:
	## A door cell the arena sealed: stone now where the level drew air.
	return level.tile(x, y) == LevelData.STONE and level.has_method("original_tile") \
			and level.original_tile(Vector2i(x, y)) == LevelData.AIR


# ---------------------------------------------------------------- the chunk

static func paint_chunk(ci: CanvasItem, tb, level: RefCounted, x0: int, x1: int, pal: Dictionary, world: Node) -> void:
	tb.origin = Vector2(x0 * TILE, 0)
	var theme := str(level.theme)
	var wall := root_wall(level)
	for x in range(x0, x1):
		for y in level.height:
			var t: int = level.tile(x, y)
			if t == LevelData.AIR:
				continue
			if wall.has_area() and wall.has_point(Vector2i(x, y)) and _solid(level, x, y):
				_root_mass(ci, tb, level, x, y, pal, wall)
				continue
			paint_cell(ci, tb, level, x, y, t, pal, world, theme)
		if _solid(level, x, level.height - 1):
			for y in range(level.height, level.height + BEDROCK_ROWS):
				ci.draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), col(pal, "buried").darkened(0.15 * (y - level.height + 1)))
	if wall.has_area():
		_root_creep(tb, level, x0, x1, pal, wall)
	tb.flush(ci)


static func paint_cell(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, t: int, pal: Dictionary, world: Node, theme := "") -> void:
	var p := Vector2(x * TILE, y * TILE)
	match t:
		LevelData.STONE, LevelData.FALSE_STONE:
			if t == LevelData.STONE and _sealed(level, x, y):
				_sealed_door(ci, tb, level, x, y, p, pal)
			else:
				_stone(ci, tb, level, x, y, p, pal, t == LevelData.FALSE_STONE, theme)
		LevelData.BRICK:
			_coffin(ci, tb, level, x, y, p, pal)
		LevelData.LEDGE:
			_branch(ci, tb, level, x, y, p, pal)
		LevelData.CRUMBLE:
			if world == null or not world.has_method("ledge_present") or world.ledge_present(x, y):
				var sh: Vector2 = world.ledge_shake(x, y) if world != null and world.has_method("ledge_shake") else Vector2.ZERO
				_trellis(ci, tb, level, x, y, p + sh, pal)
		LevelData.SPIKES_UP, LevelData.SPIKES_DOWN:
			_brambles(ci, tb, p, t == LevelData.SPIKES_UP, pal, x, y)
		VINE:
			vine_cell(tb, level, x, y, false, pal)
		ROTTEN_VINE:
			if DRAW_ROTTEN:
				vine_cell(tb, level, x, y, true, pal)
		LevelData.WATER, LevelData.BLOCK, LevelData.SPENT:
			pass    # level_features draws water; reliquaries are sprites
		_:
			Plain.paint_cell(ci, tb, level, x, y, t, pal, world)


# ---------------------------------------------------------------- stone

static func _stone(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary, hollow: bool, theme: String) -> void:
	var up := _solid(level, x, y - 1)
	var down := _solid(level, x, y + 1)
	var left := _solid(level, x - 1, y)
	var right := _solid(level, x + 1, y)
	var j := (_h(x, y) - 0.5) * 0.06
	if up and down and left and right:
		ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), col(pal, "buried").lightened(j))
		# a faint bone fleck, and one tile in nine a skull niche
		var bf := col(pal, "buried").lightened(0.1)
		ci.draw_rect(Rect2(p + Vector2(4 + _h(x, y, 1) * 18, 6 + _h(x, y, 2) * 18), Vector2(6, 2)), bf)
		if hollow:
			_hollow_curl(tb, p, pal)
		elif _h(x, y, 9) < 0.07:
			_skull_niche(tb, p + Vector2(16, 17), col(pal, "bone").darkened(0.58), false)
		return
	ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), col(pal, "stone").lightened(j))
	if not down:
		ci.draw_rect(Rect2(p + Vector2(0, TILE - 7), Vector2(TILE, 7)), col(pal, "shade"))
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 5, 0), Vector2(5, TILE)), col(pal, "shade"))
	# bone fragments where the mortar would be, and a knuckle
	var bone := col(pal, "bone_sh").darkened(0.38)
	var bone_hi := col(pal, "bone_sh").darkened(0.2)
	var bx := p.x + 3 + _h(x, y, 3) * 14
	var by := p.y + 9 + _h(x, y, 4) * 8
	ci.draw_rect(Rect2(bx, by, 9, 2), bone)
	ci.draw_rect(Rect2(bx - 1, by - 1, 2, 4), bone)
	ci.draw_rect(Rect2(bx + 8, by - 1, 2, 4), bone)
	ci.draw_rect(Rect2(bx, by, 9, 1), bone_hi)
	var kx := p.x + 17 + _h(x, y, 5) * 8
	var ky := p.y + 19 + _h(x, y, 6) * 4
	ci.draw_rect(Rect2(kx, ky, 4, 3), bone)
	ci.draw_rect(Rect2(kx + 3, ky + 1, 3, 3), bone)
	if _h(x, y, 7) > 0.5:
		ci.draw_rect(Rect2(p.x + 6 + _h(x, y, 8) * 6, p.y + 23, 6, 1.6), bone)
	if not up:
		var lip := col(pal, "lip").lightened(j)
		ci.draw_rect(Rect2(p, Vector2(TILE, 4)), lip)
		ci.draw_rect(Rect2(p + Vector2(0, 4), Vector2(TILE, 1)), col(pal, "stone"))
		_moss(ci, x, y, p, pal)
	_edges(ci, p, up, down, left, right)
	if not down and _h(x, y, 10) < 0.6:
		# a hair root hanging off the bottom, a thin S
		var rx := p.x + 5 + _h(x, y, 11) * 22
		var ln := 7.0 + _h(x, y, 12) * 7.0
		var ry := p.y + TILE
		tb.polyline(PackedVector2Array([Vector2(rx, ry - 1), Vector2(rx + 1.6, ry + ln * 0.35), Vector2(rx - 0.8, ry + ln * 0.7),
				Vector2(rx + 0.4, ry + ln)]), 1.1, col(pal, "root_hi").darkened(0.1))
	if hollow:
		if theme == "rootvault" and (not left or not right):
			_skull_niche(tb, p + Vector2(16, 16), col(pal, "bone").darkened(0.3), true)
		else:
			_hollow_curl(tb, p, pal)


static func _hollow_curl(tb, p: Vector2, pal: Dictionary) -> void:
	## A hair root curling over a hollow stone's face (the false stone's tell).
	var r := col(pal, "root_hi").lightened(0.08)
	tb.polyline(PackedVector2Array([p + Vector2(3, 8), p + Vector2(10, 12), p + Vector2(15, 9), p + Vector2(20, 15),
			p + Vector2(17, 21), p + Vector2(23, 24), p + Vector2(29, 21)]), 1.8, r)
	tb.polyline(PackedVector2Array([p + Vector2(15, 9), p + Vector2(13, 4), p + Vector2(16, 1)]), 1.2, r)
	tb.tri(p + Vector2(23, 24), p + Vector2(26, 27), p + Vector2(21, 28), col(pal, "leaf"))


static func _moss(ci: CanvasItem, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	## A moss fringe hanging 2-4 px off the lip, with its lit tips.
	var leaf := col(pal, "leaf")
	var hi := col(pal, "leaf_hi")
	var n := 3 + int(_h(x, y, 13) * 2.99)
	for i in n:
		var mx := p.x + 1 + (i + _h(x + i, y, 14) * 0.6) * (TILE - 4) / float(n)
		var mw := 4.0 + _h(x, y + i, 15) * 4.0
		var mh := 2.0 + _h(x + i, y + i, 16) * 2.5
		ci.draw_rect(Rect2(mx, p.y + 3, mw, 2 + mh), leaf)
		ci.draw_rect(Rect2(mx + 1, p.y + 3, mw - 2, 1.2), hi)
	ci.draw_rect(Rect2(p + Vector2(0, -1), Vector2(TILE, 2.5)), OUTLINE)


static func _edges(ci: CanvasItem, p: Vector2, up: bool, down: bool, left: bool, right: bool) -> void:
	if not up:
		ci.draw_rect(Rect2(p + Vector2(0, -1), Vector2(TILE, 2.5)), OUTLINE)
	if not down:
		ci.draw_rect(Rect2(p + Vector2(0, TILE - 1.5), Vector2(TILE, 2.5)), OUTLINE)
	if not left:
		ci.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2.5, TILE)), OUTLINE)
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 1.5, 0), Vector2(2.5, TILE)), OUTLINE)


static func _skull_niche(tb, c: Vector2, bone: Color, plaster: bool) -> void:
	## A dark oval niche with a little skull in it (a plaster one is paler and cracked).
	tb.ellipse(c, 10.0, 11.0, NICHE, 12)
	tb.ellipse(c + Vector2(0, -1), 6.0, 5.4, bone, 10)
	tb.rect(Rect2(c + Vector2(-3.6, 3.4), Vector2(7.2, 3.2)), bone)
	tb.rect(Rect2(c + Vector2(-3.6, -2.2), Vector2(2.6, 2.6)), SKULL_EYE)
	tb.rect(Rect2(c + Vector2(1.0, -2.2), Vector2(2.6, 2.6)), SKULL_EYE)
	tb.rect(Rect2(c + Vector2(-0.6, 1.2), Vector2(1.2, 1.4)), SKULL_EYE)
	if plaster:
		tb.polyline(PackedVector2Array([c + Vector2(2, -6), c + Vector2(0.6, -3.4), c + Vector2(2.4, -1.6)]), 0.9, SKULL_EYE)


# ---------------------------------------------------------------- coffin planks (brick)

static func _coffin(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	var face := col(pal, "brick")
	var sh := col(pal, "brick_shade")
	ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), face)
	for i in 3:
		var bx := p.x + i * 10.6
		ci.draw_rect(Rect2(bx + 1, p.y, 1.4, TILE), face.lightened(0.12))
		if i > 0:
			ci.draw_rect(Rect2(bx - 0.6, p.y, 1.4, TILE), sh.darkened(0.25))
	ci.draw_rect(Rect2(p + Vector2(0, TILE - 6), Vector2(TILE, 6)), sh)
	ci.draw_rect(Rect2(p, Vector2(TILE, 3)), col(pal, "brick_lip"))
	for sy in [7.0, 21.0]:
		ci.draw_rect(Rect2(p.x, p.y + sy, TILE, 3.4), IRON)
		ci.draw_rect(Rect2(p.x, p.y + sy, TILE, 1), IRON.lightened(0.25))
		ci.draw_rect(Rect2(p.x + 4, p.y + sy + 1, 1.6, 1.6), IRON.lightened(0.45))
		ci.draw_rect(Rect2(p.x + 26, p.y + sy + 1, 1.6, 1.6), IRON.lightened(0.45))
	var a := p + Vector2(9 + _h(x, y) * 10, 4)
	tb.polyline(PackedVector2Array([a, a + Vector2(4, 6), a + Vector2(1, 12), a + Vector2(6, 19), a + Vector2(3, 25)]), 2.0, CRACK)
	tb.line(a + Vector2(4, 6), a + Vector2(11, 8), 1.4, CRACK)
	tb.line(a + Vector2(6, 19), a + Vector2(13, 17), 1.4, CRACK)
	ci.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(TILE + 2, 2.5)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-1, TILE - 1.5), Vector2(TILE + 2, 2.5)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2.5, TILE + 2)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(TILE - 1.5, -1), Vector2(2.5, TILE + 2)), OUTLINE)


# ---------------------------------------------------------------- the bark branch (ledge)

static func _branch(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	var left: bool = level.tile(x - 1, y) == LevelData.LEDGE
	var right: bool = level.tile(x + 1, y) == LevelData.LEDGE
	var bark := col(pal, "bark")
	var lip := col(pal, "bark_lip")
	var l0 := 0.0 if left else 2.0
	var r0 := TILE if right else TILE - 2.0
	ci.draw_rect(Rect2(p.x + l0 - 1.5, p.y - 1, r0 - l0 + 3, 12), OUTLINE)
	ci.draw_rect(Rect2(p.x + l0, p.y + 0.5, r0 - l0, 9), bark)
	ci.draw_rect(Rect2(p.x + l0, p.y + 0.5, r0 - l0, 2.6), lip)
	ci.draw_rect(Rect2(p.x + l0, p.y + 7, r0 - l0, 2.5), bark.darkened(0.3))
	# bark grain
	ci.draw_rect(Rect2(p.x + 4 + _h(x, y) * 10, p.y + 4.6, 9, 1), bark.darkened(0.22))
	if (x + y) % 3 == 0:
		tb.ellipse(p + Vector2(20, 5.4), 2.6, 1.8, bark.darkened(0.35), 8)
		tb.ellipse(p + Vector2(20, 5.0), 1.2, 0.8, lip, 6)
	# rounded ends with a twig stub
	if not left:
		tb.ellipse(p + Vector2(2.2, 5), 3.4, 5.6, OUTLINE, 10)
		tb.ellipse(p + Vector2(2.4, 5), 2.2, 4.4, bark.lightened(0.05), 10)
		tb.line(p + Vector2(4, 8), p + Vector2(-2, 13), 2.4, OUTLINE)
		tb.line(p + Vector2(4, 8), p + Vector2(-1.5, 12.5), 1.2, bark)
	if not right:
		tb.ellipse(p + Vector2(TILE - 2.2, 5), 3.4, 5.6, OUTLINE, 10)
		tb.ellipse(p + Vector2(TILE - 2.4, 5), 2.2, 4.4, bark.lightened(0.05), 10)
		tb.line(p + Vector2(TILE - 5, 1), p + Vector2(TILE + 2, -4), 2.4, OUTLINE)
		tb.line(p + Vector2(TILE - 5, 1), p + Vector2(TILE + 1.5, -3.5), 1.2, bark)
	if (x + y) % 2 == 0:
		# a leaf pair hanging under it
		var lx := p.x + 10 + _h(x, y, 2) * 10
		_leaf(tb, Vector2(lx, p.y + 9), Vector2(-5, 6), pal)
		_leaf(tb, Vector2(lx + 2, p.y + 9), Vector2(5, 7), pal)


static func _leaf(tb, a: Vector2, d: Vector2, pal: Dictionary) -> void:
	var n := Vector2(-d.y, d.x).normalized() * 2.2
	var m := a + d * 0.5
	tb.quad(a, m + n * 1.2, a + d, m - n * 1.2, OUTLINE)
	tb.quad(a + d * 0.08, m + n * 0.7, a + d * 0.9, m - n * 0.7, col(pal, "leaf"))
	tb.line(a + d * 0.1, a + d * 0.75, 0.8, col(pal, "leaf_hi"))


# ---------------------------------------------------------------- bone trellis (crumble)

static func _trellis(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	var bone := col(pal, "slab")
	var lit := col(pal, "slab_lip")
	var sh := col(pal, "bone_sh")
	var left: bool = level.tile(x - 1, y) == LevelData.CRUMBLE
	var right: bool = level.tile(x + 1, y) == LevelData.CRUMBLE
	# the two rails, the top one lit (you stand on it)
	ci.draw_rect(Rect2(p + Vector2(-0.5, -1), Vector2(TILE + 1, 5.5)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-0.5, 8), Vector2(TILE + 1, 5)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(0, 0.2), Vector2(TILE, 3.4)), bone)
	ci.draw_rect(Rect2(p + Vector2(0, 0.2), Vector2(TILE, 1.4)), lit)
	ci.draw_rect(Rect2(p + Vector2(0, 9.2), Vector2(TILE, 2.8)), sh)
	# crossed bones between, lashed with twine
	tb.line(p + Vector2(3, 3), p + Vector2(15, 10), 3.4, OUTLINE)
	tb.line(p + Vector2(15, 3), p + Vector2(3, 10), 3.4, OUTLINE)
	tb.line(p + Vector2(17, 3), p + Vector2(29, 10), 3.4, OUTLINE)
	tb.line(p + Vector2(29, 3), p + Vector2(17, 10), 3.4, OUTLINE)
	tb.line(p + Vector2(3.6, 3.4), p + Vector2(14.4, 9.6), 1.8, bone.darkened(0.08))
	tb.line(p + Vector2(14.4, 3.4), p + Vector2(3.6, 9.6), 1.8, bone.darkened(0.12))
	tb.line(p + Vector2(17.6, 3.4), p + Vector2(28.4, 9.6), 1.8, bone.darkened(0.08))
	tb.line(p + Vector2(28.4, 3.4), p + Vector2(17.6, 9.6), 1.8, bone.darkened(0.12))
	tb.rect(Rect2(p + Vector2(8, 5.4), Vector2(2.2, 2.2)), col(pal, "root"))
	tb.rect(Rect2(p + Vector2(22, 5.4), Vector2(2.2, 2.2)), col(pal, "root"))
	# knuckle ends where the run stops
	if not left:
		tb.circle(p + Vector2(0.5, 2), 2.8, OUTLINE, 8)
		tb.circle(p + Vector2(0.5, 2), 1.8, lit, 8)
	if not right:
		tb.circle(p + Vector2(TILE - 0.5, 2), 2.8, OUTLINE, 8)
		tb.circle(p + Vector2(TILE - 0.5, 2), 1.8, lit, 8)


# ---------------------------------------------------------------- brambles (spikes)

static func _brambles(ci: CanvasItem, tb, p: Vector2, up: bool, pal: Dictionary, x: int, y: int) -> void:
	## A bramble bed: a dark tangle along the base, four thorns a tile in a
	## lit bark colour, each tipped bone-white (so a thorn bed reads as a hazard
	## in the candle's light, and its tips glow on the edge lines in the dark).
	var base_y := p.y + TILE if up else p.y
	var tip_y := p.y + TILE * 0.4 if up else p.y + TILE * 0.6
	var s := -1.0 if up else 1.0
	var thorn := col(pal, "thorn").lightened(0.32)
	var thorn_hi := col(pal, "thorn").lightened(0.55)
	var tip := col(pal, "bone")
	var strip := Rect2(p.x, base_y - 6, TILE, 6) if up else Rect2(p.x, base_y, TILE, 6)
	ci.draw_rect(strip.grow(1.0), OUTLINE)
	ci.draw_rect(strip, col(pal, "thorn").darkened(0.25))
	# a tangle of stems along the base
	var sy := base_y + s * 3.0
	tb.polyline(PackedVector2Array([Vector2(p.x, sy), Vector2(p.x + 8, sy + s * 2), Vector2(p.x + 16, sy - s * 1),
			Vector2(p.x + 24, sy + s * 2.4), Vector2(p.x + TILE, sy)]), 2.2, col(pal, "thorn").lightened(0.15))
	for k in 4:
		var tx := p.x + 4.0 + k * 8.0
		var lean := (1.6 if (k + x) % 2 == 0 else -1.6)
		var mid := Vector2(tx + lean, (base_y + tip_y) * 0.5)
		var t := Vector2(tx, tip_y)
		# the thorn, outlined: a wide foot, bent at mid, to its point
		tb.quad(Vector2(tx - 4.2, base_y + s * 0.5), Vector2(tx + 4.2, base_y + s * 0.5), mid + Vector2(2.6, 0), mid + Vector2(-2.6, 0), OUTLINE)
		tb.tri(mid + Vector2(-2.6, 0), mid + Vector2(2.6, 0), t + Vector2(0, s * 1.4), OUTLINE)
		tb.quad(Vector2(tx - 3.0, base_y + s * 1.2), Vector2(tx + 3.0, base_y + s * 1.2), mid + Vector2(1.6, 0), mid + Vector2(-1.6, 0), thorn)
		tb.tri(mid + Vector2(-1.6, 0), mid + Vector2(1.6, 0), t + Vector2(0, s * 2.8), thorn)
		tb.line(Vector2(tx - 1.8, base_y + s * 2.0), mid + Vector2(-0.8, 0), 0.9, thorn_hi)
		# the bone-white point
		tb.tri(Vector2(tx - 1.3, tip_y - s * 5.4), Vector2(tx + 1.3, tip_y - s * 5.4), t + Vector2(0, s * 0.3), tip)


# ---------------------------------------------------------------- vines

static func vine_cell(tb, level: RefCounted, x: int, y: int, rotten: bool, pal: Dictionary, sway := 0.0, a := 1.0) -> void:
	## One vine cell (the static stem, or a rotten one the orchard feature draws
	## each frame, swaying by sway px as it frays, faded by a). Rotten vines
	## are grey and withered ("Grey vines snap"). A knot where the run hangs
	## from stone, roots where it grows from the floor, a sprig where it ends
	## in air.
	var p := Vector2(x * TILE, y * TILE)
	var stem := col(pal, "rot" if rotten else "root")
	var rim := col(pal, "rot_hi" if rotten else "root_hi")
	var ol := Color(OUTLINE, a)
	stem.a = a
	rim.a = a
	var cx := p.x + VINE_X + sway
	var wig := 1.2 if not rotten else 1.8
	var pts := PackedVector2Array()
	for k in 5:
		pts.append(Vector2(cx + sin((y * 4 + k) * 0.8 + x * 1.3) * wig * (0.0 if k == 0 or k == 4 else 1.0), p.y + k * TILE / 4.0))
	tb.polyline(pts, 8.8, ol)
	tb.polyline(pts, 6.0, stem)
	var rp := PackedVector2Array()
	for q in pts:
		rp.append(q + Vector2(-1.5, 0))
	tb.polyline(rp, 1.6, rim)
	var above: int = level.tile(x, y - 1) if y > 0 else LevelData.STONE
	var below: int = level.tile(x, y + 1) if y + 1 < level.height else LevelData.STONE
	var is_vine := func(t: int) -> bool: return t == VINE or t == ROTTEN_VINE
	# leaves (withered on a rotten vine)
	var leaf := col(pal, "rot" if rotten else "leaf").darkened(0.15 if rotten else 0.0)
	leaf.a = a
	var lhi := col(pal, "rot_hi" if rotten else "leaf_hi")
	lhi.a = a
	for i in 2:
		var ly := p.y + 8.0 + i * 16.0
		var d := 1.0 if ((y + i + x) % 2) == 0 else -1.0
		var root := Vector2(cx + d * 1.5, ly)
		var tip := root + Vector2(d * (10.5 if not rotten else 7.0), -4.0 if not rotten else 4.5)
		var n := Vector2(0, 3.3)
		tb.quad(root, (root + tip) * 0.5 - n, tip, (root + tip) * 0.5 + n, ol)
		tb.quad(root + Vector2(d * 0.6, 0), (root + tip) * 0.5 - n * 0.55, tip - Vector2(d * 0.8, 0), (root + tip) * 0.5 + n * 0.55, leaf)
		tb.line(root, (root + tip) * 0.5 + Vector2(d * 1.5, 0), 0.8, lhi)
	if rotten:
		# frayed fibres and a dark rot band: it won't hold long
		tb.rect(Rect2(cx - 3.2, p.y + 14, 6.4, 2.6), Color(col(pal, "root").darkened(0.35), a))
		tb.line(Vector2(cx + 2, p.y + 20), Vector2(cx + 6, p.y + 24), 0.9, rim)
		tb.line(Vector2(cx - 2, p.y + 5), Vector2(cx - 6, p.y + 8), 0.9, rim)
	if not is_vine.call(above):
		if Plain.is_solid_id(above):
			# the knot it hangs from, roots splayed on the stone
			tb.ellipse(Vector2(cx, p.y + 3.5), 6.6, 4.4, ol, 10)
			tb.ellipse(Vector2(cx, p.y + 3.3), 5.2, 3.2, stem, 10)
			tb.line(Vector2(cx - 4, p.y + 1), Vector2(cx - 11, p.y - 0.5), 2.2, stem)
			tb.line(Vector2(cx + 4, p.y + 1), Vector2(cx + 10, p.y - 0.5), 2.2, stem)
			tb.line(Vector2(cx - 2.6, p.y + 2.2), Vector2(cx + 1.6, p.y + 1.6), 1.0, rim)
		else:
			# a sprig at its top
			tb.tri(Vector2(cx, p.y + 2), Vector2(cx - 5, p.y - 5), Vector2(cx - 1, p.y - 1), leaf)
			tb.tri(Vector2(cx, p.y + 2), Vector2(cx + 5, p.y - 6), Vector2(cx + 1.5, p.y - 1), leaf)
	if not is_vine.call(below):
		if Plain.is_solid_id(below) or LevelData.is_ledge(below):
			tb.line(Vector2(cx, p.y + TILE - 1), Vector2(cx - 6, p.y + TILE + 2), 2.0, stem)
			tb.line(Vector2(cx, p.y + TILE - 1), Vector2(cx + 5, p.y + TILE + 2.4), 2.0, stem)
		else:
			tb.tri(Vector2(cx - 2.4, p.y + TILE - 2), Vector2(cx + 2.4, p.y + TILE - 2), Vector2(cx + 1, p.y + TILE + 5), stem)


# ---------------------------------------------------------------- the sealed door

static func _sealed_door(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	## Roots grown shut across the door (the root seal).
	var root := col(pal, "root")
	var hi := col(pal, "root_hi")
	ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), DOOR_DARK)
	for k in 3:
		var sx := p.x + 5 + k * 11 + _h(x, y, k) * 3
		var pts := PackedVector2Array([Vector2(sx, p.y), Vector2(sx + 3 * sin(y + k), p.y + 11), Vector2(sx - 2, p.y + 22),
				Vector2(sx + 1, p.y + TILE)])
		tb.polyline(pts, 7.0, OUTLINE)
		tb.polyline(pts, 5.0, root)
		tb.polyline(pts, 1.3, hi)
	tb.polyline(PackedVector2Array([p + Vector2(0, 12 + _h(x, y, 5) * 6), p + Vector2(16, 16), p + Vector2(TILE, 11)]), 4.0, root.darkened(0.1))
	tb.tri(p + Vector2(10, 18), p + Vector2(14, 20), p + Vector2(8, 24), col(pal, "bone"))


# ---------------------------------------------------------------- Mother Gravebough's root mass (3-4's arena)

static func root_wall(level: RefCounted) -> Rect2i:
	## The wall behind Mother Gravebough: her placement x + 1 .. + 8, rows
	## 2 .. 12 (Rect2i in cells), or an empty rect when the level has no
	## rootmother (A4's ruling: she reads rooted into the arena's right
	## quarter, cols 28-35 of R_ARENA).
	if str(level.get("boss")) != "rootmother":
		return Rect2i()
	for e in level.entities:
		if str(e.get("kind", "")) == "boss":
			var c: Vector2i = e["cell"]
			return Rect2i(c.x + 1, 2, 8, 11)
	return Rect2i()


static func _root_mass(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, pal: Dictionary, wall: Rect2i) -> void:
	## Her roots, knotted into the wall: a dark mass with thick twisting
	## trunks, knots and a bone caught here and there. No rungs: nothing in it
	## reads as a thing to climb (vines are thin, leafy and green-brown).
	var p := Vector2(x * TILE, y * TILE)
	var root := col(pal, "root")
	var hi := col(pal, "root_hi")
	var dark := root.darkened(0.55)
	ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), dark)
	var lx := x - wall.position.x
	var ph := lx * 2.3 + _h(lx, 0, 3) * 3.0
	# one trunk a column, twisting and swelling as it goes down
	var cx := p.x + 16 + sin(y * 0.7 + ph) * 8.0
	var cx2 := p.x + 16 + sin((y + 1) * 0.7 + ph) * 8.0
	var w0 := 15.0 + 6.0 * sin(y * 0.5 + ph)
	var w1 := 15.0 + 6.0 * sin((y + 1) * 0.5 + ph)
	var body := root.darkened(0.26)
	tb.quad(Vector2(cx - w0 * 0.5 - 1.5, p.y), Vector2(cx + w0 * 0.5 + 1.5, p.y), Vector2(cx2 + w1 * 0.5 + 1.5, p.y + TILE),
			Vector2(cx2 - w1 * 0.5 - 1.5, p.y + TILE), OUTLINE)
	tb.quad(Vector2(cx - w0 * 0.5, p.y), Vector2(cx + w0 * 0.5, p.y), Vector2(cx2 + w1 * 0.5, p.y + TILE), Vector2(cx2 - w1 * 0.5, p.y + TILE), body)
	tb.line(Vector2(cx - w0 * 0.28, p.y), Vector2(cx2 - w1 * 0.28, p.y + TILE), 1.8, hi.darkened(0.3))
	tb.line(Vector2(cx + w0 * 0.18, p.y + 4), Vector2(cx2 + w1 * 0.1, p.y + TILE - 4), 1.0, root.darkened(0.35))
	if _h(x, y, 23) < 0.16:
		# a knot where a root bends
		tb.ellipse(Vector2(cx, p.y + 14), w0 * 0.62, 6.0, OUTLINE, 12)
		tb.ellipse(Vector2(cx, p.y + 14), w0 * 0.5, 4.6, body.lightened(0.05), 12)
		tb.ellipse(Vector2(cx - 2, p.y + 13), 2.4, 1.6, hi.darkened(0.15), 8)
	if _h(x, y, 24) < 0.22:
		# a side root arching into the next trunk, at its own slant
		var a := p + Vector2(18, 4 + _h(x, y, 25) * 14)
		var b := a + Vector2(26, 10 + _h(x, y, 26) * 12)
		tb.polyline(PackedVector2Array([a, (a + b) * 0.5 + Vector2(2, -6), b]), 5.4, OUTLINE)
		tb.polyline(PackedVector2Array([a, (a + b) * 0.5 + Vector2(2, -6), b]), 3.4, body)
	if _h(x, y, 21) < 0.12:
		# a bone caught in the roots
		var bc := p + Vector2(8 + _h(x, y, 22) * 16, 24)
		tb.line(bc + Vector2(-6, -2), bc + Vector2(6, 2), 5.2, OUTLINE)
		tb.line(bc + Vector2(-6, -2), bc + Vector2(6, 2), 3.0, col(pal, "bone_sh").darkened(0.2))
		tb.circle(bc + Vector2(-6, -2), 2.6, col(pal, "bone_sh").darkened(0.2), 8)
		tb.circle(bc + Vector2(6, 2), 2.6, col(pal, "bone_sh").darkened(0.2), 8)
	if y == wall.position.y or not _solid(level, x, y - 1):
		ci.draw_rect(Rect2(p + Vector2(0, -1), Vector2(TILE, 2.5)), OUTLINE)


static func _root_creep(tb, level: RefCounted, x0: int, x1: int, pal: Dictionary, wall: Rect2i) -> void:
	## Roots creeping from her wall over the floor at her feet (3 tiles).
	var fy := wall.end.y   # the floor row under her (row 13)
	var root := col(pal, "root")
	for x in range(maxi(x0, wall.position.x - 4), mini(x1, wall.position.x + 1)):
		if not _solid(level, x, fy) or _solid(level, x, fy - 1):
			continue
		var p := Vector2(x * TILE, fy * TILE)
		var k := float(wall.position.x - x) / 4.0
		var w := 5.0 * (1.0 - k) + 1.5
		var pts := PackedVector2Array([p + Vector2(TILE, 1.5), p + Vector2(18, 0.5 - w * 0.2), p + Vector2(0, 2)])
		tb.polyline(pts, w + 2.0, OUTLINE)
		tb.polyline(pts, w, root)
