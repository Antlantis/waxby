extends RefCounted
## World 4's tile painter, the Frozen Carillon (A1; spec 11.3, p_artaudio 4.2).
## The painter contract (contract.md 12.4): rects with ci.draw_rect, every
## other shape into the TriBatch tb, flushed once at the chunk's end. No
## draw_circle / draw_colored_polygon / draw_polyline.
##   #  stone     frozen slate: fine mortar, a frost lip with a sparkle by hash,
##                icicle teeth under the open bottoms
##   F  false     its stone, with the tell the levels' sign names: "Frost lies
##                thin on hollow stone" (a thin, dull lip, no sparkle, no teeth)
##   I  wax-ice   a glossy pane: pale ice, a 35-degree highlight, a darker
##                foot, trapped bubbles, a thin blue outline (a reflector:
##                the clockwork feature lists its spans)
##   _  frosted   a slab of ice one-way ledge with icicles under it (slick;
##                the brass girder `=` is the ledge that grips)
##   Z  rime      matte white hoarfrost, feathered crystals, soft edges (it
##                melts: the clockwork feature draws its melt over it)
##   < > belts    an iron housing, a brass lip, the dark track the clockwork
##                feature runs the belt_teeth strip along (no arrow here: a
##                boss may reverse a belt), rollers at the run's ends
##   B  brick     an ice block with a gear frozen in it, and the crack
##   =  ledge     a brass girder: a bright lip, rivets, frost at its ends
##   %  crumble   thin ice: translucent, cracking while it shakes, gone while fallen
##   ^ v spikes   icicles: four tapered spikes, pale blue with a white core
##                (tips at edge_lines' tip points)
##   sealed door  the arena's sealed cells: frosted iron plates, a brass band
## Water is level_features.gd's; any other v3 tile is the plain painter's.

const LevelData := preload("res://scripts/level_data.gd")
const Plain := preload("res://scripts/tiles/plain.gd")
const TILE := 32
const BEDROCK_ROWS := 5
const ICE := 14
const FROST_LEDGE := 15
const RIME := 16
const BELT_L := 17
const BELT_R := 18

const OUTLINE := Color("0c1220")
const CRACK := Color("1c3a52")
const DEFAULTS := {
	"stone": Color("4a5a78"), "shade": Color("3a4862"), "lip": Color("a8c8e8"), "mortar": Color("34425c"),
	"buried": Color("222c40"), "buried_mortar": Color("1c2436"), "brick": Color("8ab0cc"), "brick_shade": Color("6a90b0"),
	"brick_lip": Color("d0ecfa"), "slab": Color("bfe4f4"), "slab_lip": Color("d4ecf8"), "drip": Color("c8e2f2"),
	"ice": Color("bfe4f4"), "ice_sh": Color("7ab0d0"), "ice_hi": Color("d4ecf8"), "ice_line": Color("1c3a52"),
	"brass": Color("c8983a"), "brass_sh": Color("8a6424"), "brass_hi": Color("f0d080"), "brass_line": Color("3a2408"),
	"iron": Color("3a3a48"), "frost": Color("e8fcff"), "rime": Color("d4e6f2"), "belt": Color("2e2e3a"),
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
	return level.tile(x, y) == LevelData.STONE and level.has_method("original_tile") \
			and level.original_tile(Vector2i(x, y)) == LevelData.AIR


static func paint_chunk(ci: CanvasItem, tb, level: RefCounted, x0: int, x1: int, pal: Dictionary, world: Node, y0 := 0, y1 := -1) -> void:
	var ye: int = level.height if y1 < 0 else y1
	tb.origin = Vector2(x0 * TILE, y0 * TILE)
	for x in range(x0, x1):
		for y in range(y0, ye):
			var t: int = level.tile(x, y)
			if t != LevelData.AIR:
				paint_cell(ci, tb, level, x, y, t, pal, world)
		if ye >= level.height and _solid(level, x, level.height - 1):
			for y in range(level.height, level.height + BEDROCK_ROWS):
				ci.draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), col(pal, "buried").darkened(0.15 * (y - level.height + 1)))
	tb.flush(ci)


static func paint_cell(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, t: int, pal: Dictionary, world: Node) -> void:
	var p := Vector2(x * TILE, y * TILE)
	match t:
		LevelData.STONE, LevelData.FALSE_STONE:
			if t == LevelData.STONE and _sealed(level, x, y):
				_sealed_door(ci, tb, level, x, y, p, pal)
			else:
				_slate(ci, tb, level, x, y, p, pal, t == LevelData.FALSE_STONE)
		ICE:
			_ice(ci, tb, level, x, y, p, pal)
		FROST_LEDGE:
			_frost_ledge(ci, tb, level, x, y, p, pal)
		RIME:
			_rime(ci, tb, level, x, y, p, pal)
		BELT_L, BELT_R:
			_belt(ci, tb, level, x, y, p, pal)
		LevelData.BRICK:
			_ice_block(ci, tb, level, x, y, p, pal)
		LevelData.LEDGE:
			_girder(ci, tb, level, x, y, p, pal)
		LevelData.CRUMBLE:
			if world == null or not world.has_method("ledge_present") or world.ledge_present(x, y):
				var sh: Vector2 = world.ledge_shake(x, y) if world != null and world.has_method("ledge_shake") else Vector2.ZERO
				_thin_ice(ci, tb, level, x, y, p + sh, pal, sh != Vector2.ZERO)
		LevelData.SPIKES_UP, LevelData.SPIKES_DOWN:
			_icicle_spikes(ci, tb, p, t == LevelData.SPIKES_UP, pal)
		LevelData.WATER, LevelData.BLOCK, LevelData.SPENT:
			pass
		_:
			Plain.paint_cell(ci, tb, level, x, y, t, pal, world)


static func _edges(ci, p: Vector2, up: bool, down: bool, left: bool, right: bool, c := OUTLINE) -> void:
	if not up:
		ci.draw_rect(Rect2(p + Vector2(0, -1), Vector2(TILE, 2.5)), c)
	if not down:
		ci.draw_rect(Rect2(p + Vector2(0, TILE - 1.5), Vector2(TILE, 2.5)), c)
	if not left:
		ci.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2.5, TILE)), c)
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 1.5, 0), Vector2(2.5, TILE)), c)


# ---------------------------------------------------------------- frozen slate

static func _slate(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary, hollow: bool) -> void:
	var up := _solid(level, x, y - 1)
	var down := _solid(level, x, y + 1)
	var left := _solid(level, x - 1, y)
	var right := _solid(level, x + 1, y)
	var j := (_h(x, y) - 0.5) * 0.06
	if up and down and left and right:
		ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), col(pal, "buried").lightened(j))
		_mortar(ci, p, col(pal, "buried_mortar"), y)
		return
	ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), col(pal, "stone").lightened(j))
	if not down:
		ci.draw_rect(Rect2(p + Vector2(0, TILE - 7), Vector2(TILE, 7)), col(pal, "shade"))
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 5, 0), Vector2(5, TILE)), col(pal, "shade"))
	_mortar(ci, p, col(pal, "mortar"), y)
	# frost in the slate's grain
	ci.draw_rect(Rect2(p.x + 3 + _h(x, y, 3) * 20, p.y + 7 + _h(x, y, 4) * 16, 5, 1), col(pal, "stone").lightened(0.16))
	if not up:
		if hollow:
			# thin frost on hollow stone: a dull, narrow lip
			ci.draw_rect(Rect2(p, Vector2(TILE, 2.5)), col(pal, "lip").darkened(0.18).lerp(col(pal, "stone"), 0.25))
		else:
			ci.draw_rect(Rect2(p, Vector2(TILE, 4)), col(pal, "lip").lightened(j))
			ci.draw_rect(Rect2(p + Vector2(0, 4), Vector2(TILE, 1)), col(pal, "stone").lightened(0.1))
			# a crust of frost with a sparkle
			var fx := p.x + 2 + _h(x, y, 5) * 20
			ci.draw_rect(Rect2(fx, p.y + 3.4, 7, 2.2), col(pal, "lip"))
			if _h(x, y, 6) > 0.45:
				ci.draw_rect(Rect2(p.x + 4 + _h(x, y, 7) * 22, p.y + 1, 1.2, 1.2), col(pal, "ice_hi"))
	_edges(ci, p, up, down, left, right)
	if not down and not hollow:
		# icicle teeth under the open bottom
		var n := 1 + int(_h(x, y, 8) * 2.99)
		for i in n:
			var ix := p.x + 5 + (i + _h(x + i, y, 9) * 0.7) * 24.0 / n
			var ln := 4.0 + _h(x, y + i, 10) * 6.0
			tb.tri(Vector2(ix - 3, p.y + TILE), Vector2(ix + 3, p.y + TILE), Vector2(ix + 0.4, p.y + TILE + ln + 1.4), OUTLINE)
			tb.tri(Vector2(ix - 2, p.y + TILE - 0.5), Vector2(ix + 2, p.y + TILE - 0.5), Vector2(ix + 0.3, p.y + TILE + ln), col(pal, "drip"))
			tb.line(Vector2(ix - 0.6, p.y + TILE), Vector2(ix, p.y + TILE + ln * 0.6), 0.8, col(pal, "ice_hi"))


static func _mortar(ci: CanvasItem, p: Vector2, c: Color, y: int) -> void:
	ci.draw_rect(Rect2(p + Vector2(0, 15.5), Vector2(TILE, 1)), c)
	var off := 0.0 if y % 2 == 0 else 16.0
	ci.draw_rect(Rect2(p + Vector2(off, 0), Vector2(1, 15.5)), c)
	ci.draw_rect(Rect2(p + Vector2(fmod(off + 16.0, 32.0), 16.5), Vector2(1, 15.5)), c)


# ---------------------------------------------------------------- wax-ice

static func _ice(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	var up := _solid(level, x, y - 1)
	var down := _solid(level, x, y + 1)
	var left := _solid(level, x - 1, y)
	var right := _solid(level, x + 1, y)
	var ice := col(pal, "ice")
	var sh := col(pal, "ice_sh")
	var hi := col(pal, "ice_hi")
	var ln := col(pal, "ice_line")
	if up and down and left and right:
		ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), sh.darkened(0.3))
		ci.draw_rect(Rect2(p + Vector2(4 + _h(x, y) * 16, 8 + _h(x, y, 1) * 14), Vector2(3, 3)), sh.lightened(0.1))
		return
	ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), ice.darkened(0.06 + _h(x, y) * 0.04))
	if not down:
		ci.draw_rect(Rect2(p + Vector2(0, TILE - 8), Vector2(TILE, 8)), sh)
	elif not up:
		ci.draw_rect(Rect2(p + Vector2(0, TILE - 10), Vector2(TILE, 10)), ice.darkened(0.16))
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 4, 0), Vector2(4, TILE)), sh.lightened(0.08))
	# trapped bubbles
	ci.draw_rect(Rect2(p.x + 6 + _h(x, y, 2) * 16, p.y + 12 + _h(x, y, 3) * 8, 2.4, 2.4), hi)
	ci.draw_rect(Rect2(p.x + 14 + _h(x, y, 4) * 12, p.y + 17 + _h(x, y, 5) * 6, 1.6, 1.6), hi.darkened(0.08))
	if not up:
		ci.draw_rect(Rect2(p, Vector2(TILE, 3)), hi)
		ci.draw_rect(Rect2(p + Vector2(0, 3), Vector2(TILE, 1.2)), ice.lightened(0.2))
	_edges(ci, p, up, down, left, right, ln)
	# the glossy highlight, a 35-degree quad across the face
	var o := _h(x, y, 6) * 6.0
	var hc := Color(hi, 0.6)
	tb.quad(p + Vector2(4 + o, TILE - 6), p + Vector2(10 + o, TILE - 6), p + Vector2(21 + o, 5), p + Vector2(15 + o, 5), hc)
	tb.quad(p + Vector2(15 + o, TILE - 6), p + Vector2(17.5 + o, TILE - 6), p + Vector2(28.5 + o, 5), p + Vector2(26 + o, 5), Color(hi, 0.35))


# ---------------------------------------------------------------- the frosted ledge

static func _frost_ledge(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	var left: bool = level.tile(x - 1, y) == FROST_LEDGE
	var right: bool = level.tile(x + 1, y) == FROST_LEDGE
	var ice := col(pal, "ice")
	var ln := col(pal, "ice_line")
	var l0 := 0.0 if left else 1.5
	var r0 := TILE if right else TILE - 1.5
	ci.draw_rect(Rect2(p.x + l0 - 1, p.y - 1, r0 - l0 + 2, 12), ln)
	ci.draw_rect(Rect2(p.x + l0, p.y + 0.5, r0 - l0, 9), ice.darkened(0.08))
	ci.draw_rect(Rect2(p.x + l0, p.y + 0.5, r0 - l0, 3), col(pal, "ice_hi"))
	ci.draw_rect(Rect2(p.x + l0, p.y + 7, r0 - l0, 2.5), col(pal, "ice_sh"))
	tb.quad(p + Vector2(6, 7), p + Vector2(9, 7), p + Vector2(13, 3.4), p + Vector2(10, 3.4), Color(col(pal, "ice_hi"), 0.7))
	for i in 3:
		var ix := p.x + 5.0 + i * 10.0 + _h(x + i, y) * 3.0
		var l := 4.0 + _h(x, y + i, 2) * 5.0
		tb.tri(Vector2(ix - 2.6, p.y + 9), Vector2(ix + 2.6, p.y + 9), Vector2(ix + 0.3, p.y + 10 + l), ln)
		tb.tri(Vector2(ix - 1.6, p.y + 9), Vector2(ix + 1.6, p.y + 9), Vector2(ix + 0.2, p.y + 9 + l), col(pal, "drip"))


# ---------------------------------------------------------------- rime

static func _rime(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	var rime := col(pal, "rime")
	var up: bool = level.tile(x, y - 1) == RIME
	var down: bool = level.tile(x, y + 1) == RIME
	var left: bool = level.tile(x - 1, y) == RIME
	var right: bool = level.tile(x + 1, y) == RIME
	ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), rime.darkened(0.22))
	ci.draw_rect(Rect2(p + Vector2(2, 2), Vector2(TILE - 4, TILE - 4)), rime.darkened(0.1))
	if not up:
		ci.draw_rect(Rect2(p, Vector2(TILE, 3)), rime)
	# feathered crystals (hoarfrost ferns)
	for i in 3:
		var c := p + Vector2(7 + i * 9 + _h(x + i, y) * 3, 9 + _h(x, y + i, 1) * 14)
		var a := _h(x, y, 2 + i) * 1.4 - 0.7
		var d := Vector2(sin(a), -cos(a)) * 6.0
		tb.line(c - d, c + d, 1.2, rime)
		var n := Vector2(-d.y, d.x) * 0.45
		tb.line(c, c + d * 0.5 + n, 1.0, rime)
		tb.line(c, c + d * 0.5 - n, 1.0, rime)
		tb.line(c - d * 0.5, c + n * 0.8, 0.9, rime)
		tb.line(c - d * 0.5, c - n * 0.8, 0.9, rime)
	# soft, fuzzy edges where the patch ends
	var fz := Color(rime, 0.85)
	if not up:
		for k in 4:
			tb.tri(p + Vector2(2 + k * 8, 0.5), p + Vector2(6 + k * 8, 0.5), p + Vector2(4 + k * 8 + _h(x + k, y) * 2, -3.4), fz)
	if not left:
		ci.draw_rect(Rect2(p + Vector2(-0.5, 0), Vector2(1.6, TILE)), Color(col(pal, "ice_line"), 0.6))
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 1.1, 0), Vector2(1.6, TILE)), Color(col(pal, "ice_line"), 0.6))
	if not down:
		ci.draw_rect(Rect2(p + Vector2(0, TILE - 1.1), Vector2(TILE, 1.6)), Color(col(pal, "ice_line"), 0.6))


# ---------------------------------------------------------------- gear belts

static func _belt(ci, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	var iron := col(pal, "belt")
	var brass := col(pal, "brass")
	var left: bool = LevelData.is_belt(level.tile(x - 1, y))
	var right: bool = LevelData.is_belt(level.tile(x + 1, y))
	ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), iron)
	ci.draw_rect(Rect2(p + Vector2(0, TILE - 7), Vector2(TILE, 7)), iron.darkened(0.3))
	# the track (the belt_teeth strip runs here) and its brass lip
	ci.draw_rect(Rect2(p, Vector2(TILE, 9)), Color("1e1a22"))
	ci.draw_rect(Rect2(p + Vector2(0, 9), Vector2(TILE, 2.4)), brass)
	ci.draw_rect(Rect2(p + Vector2(0, 11.4), Vector2(TILE, 1)), col(pal, "brass_sh"))
	# the housing's rivets and a vent
	ci.draw_rect(Rect2(p + Vector2(5, 17), Vector2(2, 2)), iron.lightened(0.3))
	ci.draw_rect(Rect2(p + Vector2(25, 17), Vector2(2, 2)), iron.lightened(0.3))
	ci.draw_rect(Rect2(p + Vector2(10, 16), Vector2(12, 1.4)), iron.darkened(0.4))
	ci.draw_rect(Rect2(p + Vector2(10, 19), Vector2(12, 1.4)), iron.darkened(0.4))
	_edges(ci, p, _solid(level, x, y - 1), _solid(level, x, y + 1), left or _solid(level, x - 1, y), right or _solid(level, x + 1, y))
	# its walkable top: a lit brass lip under the top line, over the track (so
	# a belt's top reads against the wall before and after the feature draws
	# belt_teeth there; the strip's own top band is brass too)
	if not _solid(level, x, y - 1):
		ci.draw_rect(Rect2(p + Vector2(0, 1.5), Vector2(TILE, 1.8)), col(pal, "brass_hi"))
	# rollers at the run's ends
	if not left:
		_roller(tb, p + Vector2(6, 14), pal)
	if not right:
		_roller(tb, p + Vector2(TILE - 6, 14), pal)


static func _roller(tb, c: Vector2, pal: Dictionary) -> void:
	tb.circle(c, 6.4, OUTLINE, 12)
	tb.circle(c, 5.0, col(pal, "brass_sh"), 12)
	tb.circle(c, 3.6, col(pal, "brass"), 10)
	tb.circle(c, 1.4, OUTLINE, 6)


# ---------------------------------------------------------------- the ice block (brick)

static func _ice_block(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), col(pal, "brick"))
	ci.draw_rect(Rect2(p + Vector2(0, TILE - 6), Vector2(TILE, 6)), col(pal, "brick_shade"))
	ci.draw_rect(Rect2(p + Vector2(TILE - 4, 0), Vector2(4, TILE)), col(pal, "brick_shade"))
	ci.draw_rect(Rect2(p, Vector2(TILE, 3)), col(pal, "brick_lip"))
	# the gear frozen inside
	var c := p + Vector2(16, 16)
	var g := Color(col(pal, "brass_sh"), 0.5)
	var rim := PackedVector2Array()
	var n := 10
	var rot := _h(x, y) * 0.6
	for k in n * 2:
		var a := rot + TAU * k / (n * 2.0)
		var r := 10.0 if k % 2 == 0 else 7.6
		rim.append(c + Vector2(cos(a), sin(a)) * r)
	tb.fan(c, rim, g)
	tb.circle(c, 3.2, Color(col(pal, "brick"), 0.8), 8)
	var a2 := p + Vector2(7 + _h(x, y, 2) * 8, 4)
	tb.polyline(PackedVector2Array([a2, a2 + Vector2(4, 6), a2 + Vector2(1, 12), a2 + Vector2(6, 19), a2 + Vector2(3, 25)]), 1.8, CRACK)
	tb.line(a2 + Vector2(4, 6), a2 + Vector2(10, 8), 1.2, CRACK)
	tb.quad(p + Vector2(21, 26), p + Vector2(23.5, 26), p + Vector2(29, 7), p + Vector2(26.5, 7), Color(col(pal, "ice_hi"), 0.45))
	ci.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(TILE + 2, 2.5)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-1, TILE - 1.5), Vector2(TILE + 2, 2.5)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2.5, TILE + 2)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(TILE - 1.5, -1), Vector2(2.5, TILE + 2)), OUTLINE)


# ---------------------------------------------------------------- the brass girder (ledge)

static func _girder(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	var left: bool = level.tile(x - 1, y) == LevelData.LEDGE
	var right: bool = level.tile(x + 1, y) == LevelData.LEDGE
	var brass := col(pal, "brass")
	ci.draw_rect(Rect2(p + Vector2(-0.5, -1), Vector2(TILE + 1, 12)), col(pal, "brass_line"))
	ci.draw_rect(Rect2(p + Vector2(0, 0.5), Vector2(TILE, 9)), brass)
	ci.draw_rect(Rect2(p + Vector2(0, 0.5), Vector2(TILE, 2.6)), col(pal, "brass_hi"))
	ci.draw_rect(Rect2(p + Vector2(0, 7), Vector2(TILE, 2.5)), col(pal, "brass_sh"))
	for rx in [6.0, 22.0]:
		ci.draw_rect(Rect2(p.x + rx, p.y + 4.2, 2.2, 2.2), col(pal, "brass_line"))
		ci.draw_rect(Rect2(p.x + rx, p.y + 4.2, 1, 1), col(pal, "brass_hi"))
	if not left:
		ci.draw_rect(Rect2(p + Vector2(-2, -1), Vector2(3, 12)), col(pal, "brass_line"))
		ci.draw_rect(Rect2(p + Vector2(1, 0.5), Vector2(3, 1.6)), col(pal, "ice_hi"))
	if not right:
		ci.draw_rect(Rect2(p + Vector2(TILE - 1, -1), Vector2(3, 12)), col(pal, "brass_line"))
		ci.draw_rect(Rect2(p + Vector2(TILE - 5, 0.5), Vector2(3, 1.6)), col(pal, "ice_hi"))
	# the truss under it
	if (x + y) % 2 == 0 or not left:
		var bx := p.x + (5.0 if not left else 12.0)
		tb.tri(Vector2(bx, p.y + 9.5), Vector2(bx + 9, p.y + 9.5), Vector2(bx, p.y + 18), col(pal, "brass_line"))
		tb.tri(Vector2(bx + 1.5, p.y + 10.5), Vector2(bx + 6, p.y + 10.5), Vector2(bx + 1.5, p.y + 14.5), col(pal, "brass_sh"))


# ---------------------------------------------------------------- thin ice (crumble)

static func _thin_ice(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary, shaking: bool) -> void:
	## Thin ice: a translucent pane (the dark shows through it), always with a
	## hairline crack, three while it shakes. A frosted ledge is a thick slab
	## with icicles under it: the two never look alike.
	var ice := col(pal, "slab")
	var ln := col(pal, "ice_line")
	ci.draw_rect(Rect2(p + Vector2(-0.5, -1), Vector2(TILE + 1, 9)), Color(ln, 0.85))
	ci.draw_rect(Rect2(p + Vector2(0.5, 0.5), Vector2(TILE - 1, 6)), Color(ice, 0.5))
	ci.draw_rect(Rect2(p + Vector2(0.5, 0.5), Vector2(TILE - 1, 2)), col(pal, "slab_lip"))
	ci.draw_rect(Rect2(p + Vector2(0.5, 5.5), Vector2(TILE - 1, 1)), Color(col(pal, "ice_sh"), 0.8))
	var k := _h(x, y)
	var n := 3 if shaking else 1
	var cracks := [
		[Vector2(6 + k * 14, 1), Vector2(9 + k * 14, 4), Vector2(7 + k * 14, 7)],
		[Vector2(22, 1.5), Vector2(19, 4), Vector2(23, 6.5)],
		[Vector2(12, 3), Vector2(15, 5), Vector2(28, 4)],
	]
	for i in n:
		var pts := PackedVector2Array()
		for q in cracks[i]:
			pts.append(p + q)
		tb.polyline(pts, 1.2, ln)


# ---------------------------------------------------------------- icicle spikes

static func _icicle_spikes(ci: CanvasItem, tb, p: Vector2, up: bool, pal: Dictionary) -> void:
	var base_y := p.y + TILE if up else p.y
	var tip_y := p.y + TILE * 0.4 if up else p.y + TILE * 0.6
	var ice := col(pal, "ice")
	var core := col(pal, "ice_hi")
	var ln := col(pal, "ice_line")
	var strip := Rect2(p.x, base_y - 5, TILE, 5) if up else Rect2(p.x, base_y, TILE, 5)
	ci.draw_rect(strip.grow(1.0), OUTLINE)
	ci.draw_rect(strip, col(pal, "ice_sh").darkened(0.2))
	var e := -1.2 if up else 1.2
	var e2 := 2.5 if up else -2.5
	for i in 4:
		var x0 := p.x + i * 8.0
		tb.tri(Vector2(x0, base_y), Vector2(x0 + 4, tip_y), Vector2(x0 + 8, base_y), ln)
		tb.tri(Vector2(x0 + 1.4, base_y + e), Vector2(x0 + 4, tip_y + e2), Vector2(x0 + 6.6, base_y + e), ice)
		tb.tri(Vector2(x0 + 3.2, base_y + e), Vector2(x0 + 4, tip_y + e2 * 1.6), Vector2(x0 + 4.8, base_y + e), core)


# ---------------------------------------------------------------- the sealed door

static func _sealed_door(ci: CanvasItem, tb, level: RefCounted, x: int, y: int, p: Vector2, pal: Dictionary) -> void:
	## The Tinker's door shut: frosted iron plates, rivets, a brass band.
	var iron := col(pal, "iron")
	ci.draw_rect(Rect2(p, Vector2(TILE, TILE)), iron)
	ci.draw_rect(Rect2(p + Vector2(0, TILE - 3), Vector2(TILE, 3)), iron.darkened(0.3))
	ci.draw_rect(Rect2(p + Vector2(0, 0), Vector2(TILE, 1.2)), iron.lightened(0.3))
	ci.draw_rect(Rect2(p + Vector2(3, 3), Vector2(2, 2)), iron.lightened(0.4))
	ci.draw_rect(Rect2(p + Vector2(27, 3), Vector2(2, 2)), iron.lightened(0.4))
	if level.tile(x, y - 1) != LevelData.STONE or not _sealed(level, x, y - 1):
		ci.draw_rect(Rect2(p + Vector2(0, 12), Vector2(TILE, 5)), col(pal, "brass"))
		ci.draw_rect(Rect2(p + Vector2(0, 12), Vector2(TILE, 1.4)), col(pal, "brass_hi"))
	ci.draw_rect(Rect2(p + Vector2(5 + _h(x, y) * 18, 1), Vector2(4, 1.6)), col(pal, "ice_hi"))
	ci.draw_rect(Rect2(p + Vector2(-0.5, 0), Vector2(1.5, TILE)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(TILE - 1, 0), Vector2(1.5, TILE)), OUTLINE)
