extends Node2D
## Draws one chunk of the level's tiles (CHUNK columns by CHUNK rows from
## col0, row0; the bottom row of chunks also draws the bedrock under the
## level) in the cel-shaded stone look: exposed faces get a candlelit top lip,
## a dark outline and a hard shade band; buried stone is darker and quieter.
## The drawing is cached by the canvas and redone only when a tile changes,
## and the canvas culls a chunk off screen, so a redraw and the tiles drawn a
## frame scale with the screen, not the level's height (the shapes plan's E4:
## a 15-row level is one row of chunks, drawn exactly as before).
## Reliquaries are sprites (the Block nodes) and lava animates on its own;
## water and false stone's crack are level_features' (false stone itself is
## drawn here exactly like stone, which is the point).
##
## Each theme has a palette. World 1's cathedral stone is the default; the
## World 2 themes get warm tallow rock, drowned teal stone, mossy garden
## stone and the violet Undercandle, with wax dripping over the lips, and
## their crumbling ledges are soft wax instead of cracked slabs.
##
## v3: a theme from scripts/themes/* (themes/loader.gd) names a painter,
## scripts/tiles/<painter>.gd, and the chunk is handed to its
## paint_chunk(ci, tb, level, x0, x1, pal, world, y0, y1) (the plain painter
## when the file is missing; painter "" or "v2" keeps this file's stone with the
## theme's palette). In v2's themes, a v3 tile (vines, ice, glass, ...) is
## drawn by the plain painter's stand-in, batched and flushed once; with none
## (W1-W2) the drawing is exactly v2's.

const LevelData := preload("res://scripts/level_data.gd")
const Themes := preload("res://scripts/themes/loader.gd")
const Plain := preload("res://scripts/tiles/plain.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const V3_FIRST := 12             # the first tile id past v2's (contract.md §2.1)
# In v2's themes (the feel labs), the v3 tiles are drawn by the feature
# modules' draw_under stand-ins, which carry their state (a rotten vine that
# snaps, glass strain, a belt's direction); this file's cached plain
# stand-ins would keep showing a snapped vine. true draws them here too.
const V2_THEME_STANDINS := false
const TILE := LevelData.TILE
const CHUNK := 16
const BEDROCK_ROWS := 5          # rows of stone under the level: world.gd BELOW (160 px) / TILE

const OUTLINE := Color("17121f")
const CRACK := Color("20161e")
const WOOD := Color("6b4a32")
const WOOD_LIP := Color("9a7250")
const WOOD_SHADE := Color("4a3020")
const IRON := Color("3a3a48")
const STEEL := Color("c4c8d8")
const STEEL_SHADE := Color("7e8296")
const PALETTES := {
	"cathedral": {"stone": Color("4a3f5e"), "shade": Color("3a3150"), "lip": Color("7a6c96"), "mortar": Color("342b46"),
			"buried": Color("2a2238"), "buried_mortar": Color("231c30"), "brick": Color("62505e"),
			"brick_shade": Color("4a3a48"), "brick_lip": Color("8a7488"), "slab": Color("6a5a78"), "slab_lip": Color("9486a8"),
			"drip": Color(0, 0, 0, 0), "wax": false},
	"waxfall": {"stone": Color("5a4636"), "shade": Color("46362a"), "lip": Color("8c7254"), "mortar": Color("3e3024"),
			"buried": Color("2e2319"), "buried_mortar": Color("261d15"), "brick": Color("6a5040"),
			"brick_shade": Color("503a2e"), "brick_lip": Color("977a5c"), "slab": Color("d8c49a"), "slab_lip": Color("f2e4c2"),
			"drip": Color("ecdcb6"), "wax": true},
	"chandlery": {"stone": Color("3c5056"), "shade": Color("2e4046"), "lip": Color("6a8c90"), "mortar": Color("2a3a40"),
			"buried": Color("1d2a2e"), "buried_mortar": Color("172226"), "brick": Color("4e5a5a"),
			"brick_shade": Color("3a4646"), "brick_lip": Color("7a8c88"), "slab": Color("d0c8a8"), "slab_lip": Color("ece6cc"),
			"drip": Color("d8d8c4"), "wax": true},
	"garden": {"stone": Color("3c463c"), "shade": Color("2f382f"), "lip": Color("687a5e"), "mortar": Color("2b3329"),
			"buried": Color("1d241d"), "buried_mortar": Color("181e18"), "brick": Color("4c5646"),
			"brick_shade": Color("3a4236"), "brick_lip": Color("788a6a"), "slab": Color("d8e0c0"), "slab_lip": Color("f0f4dc"),
			"drip": Color("7aa062"), "wax": true},
	"undercandle": {"stone": Color("463a5a"), "shade": Color("372d4a"), "lip": Color("766896"), "mortar": Color("30273f"),
			"buried": Color("221b30"), "buried_mortar": Color("1c1628"), "brick": Color("5a4a62"),
			"brick_shade": Color("44384c"), "brick_lip": Color("86749a"), "slab": Color("e0d4bc"), "slab_lip": Color("f6ecd8"),
			"drip": Color("e8dcc6"), "wax": true},
}

var level: RefCounted
var col0 := 0
var row0 := 0                    # the chunk's first row (world.gd lays chunks out CHUNK rows apart)
var world: Node          # for the crumbling ledges' state (may be null)
var _p: Dictionary = PALETTES["cathedral"]
var _tb = null                   # a TriBatch, made the first time a chunk needs one


func _batch():
	if _tb == null:
		_tb = TriBatch.new()
	return _tb


func _draw() -> void:
	var th := str(level.theme)
	var col1 := mini(col0 + CHUNK, level.width)
	var row1 := mini(row0 + CHUNK, level.height)
	if not PALETTES.has(th) and Themes.has_theme(th):
		var painter: Script = Themes.painter(th)
		var pal: Dictionary = Themes.palette(th)
		if painter != null:
			painter.paint_chunk(self, _batch(), level, col0, col1, pal, world, row0, row1)
			return
		_p = PALETTES["cathedral"].merged(pal, true)
	else:
		_p = PALETTES.get(th, PALETTES["cathedral"])
	for x in range(col0, col1):
		for y in range(row0, row1):
			var t: int = level.tile(x, y)
			match t:
				LevelData.STONE, LevelData.FALSE_STONE:
					_stone(x, y)
				LevelData.BRICK:
					_brick(x, y)
				LevelData.LEDGE:
					_ledge(x, y)
				LevelData.CRUMBLE:
					if world == null or world.ledge_present(x, y):
						if _p["wax"]:
							_soft_wax(x, y)
						else:
							_slab(x, y)
				LevelData.SPIKES_UP:
					_spikes(x, y, true)
				LevelData.SPIKES_DOWN:
					_spikes(x, y, false)
				_:
					if t >= V3_FIRST and V2_THEME_STANDINS:
						Plain.paint_cell(self, _batch(), level, x, y, t, _p, world)
		# The bedrock under the level, where the floor goes down: just for looks
		# (as deep as the camera shows, world.gd BELOW), by the bottom chunks.
		if row1 >= level.height and (LevelData.is_solid(level.tile(x, level.height - 1)) or Plain.V3_SOLID.has(level.tile(x, level.height - 1))):
			for y in range(level.height, level.height + BEDROCK_ROWS):
				draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), (_p["buried"] as Color).darkened(0.15 * (y - level.height + 1)))
	if _tb != null:
		_tb.flush(self)


func _solid(x: int, y: int) -> bool:
	# Past the level's bottom counts as solid for the look (no lip under the floor).
	if y >= level.height:
		return true
	return LevelData.is_solid(level.tile(x, y))


func _hash(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(absi(h) % 1000) / 1000.0


func _stone(x: int, y: int) -> void:
	var p := Vector2(x * TILE, y * TILE)
	var up := _solid(x, y - 1)
	var down := _solid(x, y + 1)
	var left := _solid(x - 1, y)
	var right := _solid(x + 1, y)
	var j := (_hash(x, y) - 0.5) * 0.06
	if up and down and left and right:
		draw_rect(Rect2(p, Vector2(TILE, TILE)), (_p["buried"] as Color).lightened(j))
		_mortar(p, _p["buried_mortar"], y)
		return
	draw_rect(Rect2(p, Vector2(TILE, TILE)), (_p["stone"] as Color).lightened(j))
	# The cel shade: a hard band along the bottom and right of the face.
	if not down:
		draw_rect(Rect2(p + Vector2(0, TILE - 7), Vector2(TILE, 7)), _p["shade"])
	if not right:
		draw_rect(Rect2(p + Vector2(TILE - 5, 0), Vector2(5, TILE)), _p["shade"])
	_mortar(p, _p["mortar"], y)
	if not up:
		draw_rect(Rect2(p, Vector2(TILE, 4)), (_p["lip"] as Color).lightened(j))
		draw_rect(Rect2(p + Vector2(0, 4), Vector2(TILE, 1)), _p["stone"])
		if _p.has("trim"):
			# A gilt secret level's 1 px of gold under the lip (A2: only gilt()'s
			# palettes carry "trim", so W1-W2 draw as before).
			draw_rect(Rect2(p + Vector2(0, 4), Vector2(TILE, 1)), _p["trim"])
		# A chip or two out of the lip.
		if _hash(x, y + 7) > 0.7:
			var cx := p.x + 6 + _hash(x + 3, y) * 18
			draw_rect(Rect2(cx, p.y, 5, 2), _p["shade"])
	_edges(p, up, down, left, right)
	if not up and (_p["drip"] as Color).a > 0.0:
		_lip_drips(x, y, p)
	if not down and _p["wax"] and _hash(x, y + 3) > 0.55:
		# Wax that ran over the edge and hardened hanging under it.
		var dx := p.x + 5.0 + _hash(x + 1, y) * 20.0
		var len := 5.0 + _hash(x, y + 9) * 9.0
		var c: Color = _p["drip"]
		draw_colored_polygon(PackedVector2Array([Vector2(dx - 3, p.y + TILE), Vector2(dx + 3, p.y + TILE), Vector2(dx + 1, p.y + TILE + len - 2), Vector2(dx - 1, p.y + TILE + len - 2)]), OUTLINE)
		draw_rect(Rect2(dx - 2, p.y + TILE, 4, len - 3), c)
		draw_circle(Vector2(dx, p.y + TILE + len - 3), 2.2, c)


func _lip_drips(x: int, y: int, p: Vector2) -> void:
	## Tallow (or moss) over the top lip, running down the face in drips.
	var c: Color = _p["drip"]
	var sh := c.darkened(0.22)
	draw_rect(Rect2(p + Vector2(0, -2), Vector2(TILE, 4)), c)
	draw_rect(Rect2(p + Vector2(0, 1), Vector2(TILE, 1.5)), sh)
	var n := 1 + int(_hash(x, y + 11) * 2.99)
	for i in n:
		var dx := p.x + 3.0 + _hash(x + i * 5, y) * 26.0
		var len := 4.0 + _hash(x + i, y + 5) * (10.0 if _p["wax"] else 5.0)
		draw_rect(Rect2(dx - 2, p.y + 1, 4, len), c)
		draw_circle(Vector2(dx, p.y + 1 + len), 2.2, c)
		draw_rect(Rect2(dx + 0.5, p.y + 2, 1.5, len - 1), sh)
	draw_rect(Rect2(p + Vector2(0, -3), Vector2(TILE, 1.5)), OUTLINE)


func _mortar(p: Vector2, c: Color, y: int) -> void:
	draw_rect(Rect2(p + Vector2(0, 15), Vector2(TILE, 2)), c)
	var off := 0.0 if y % 2 == 0 else 16.0
	draw_rect(Rect2(p + Vector2(off, 0), Vector2(2, 15)), c)
	draw_rect(Rect2(p + Vector2(fmod(off + 16.0, 32.0), 17), Vector2(2, 15)), c)


func _edges(p: Vector2, up: bool, down: bool, left: bool, right: bool) -> void:
	if not up:
		draw_rect(Rect2(p + Vector2(0, -1), Vector2(TILE, 2.5)), OUTLINE)
	if not down:
		draw_rect(Rect2(p + Vector2(0, TILE - 1.5), Vector2(TILE, 2.5)), OUTLINE)
	if not left:
		draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2.5, TILE)), OUTLINE)
	if not right:
		draw_rect(Rect2(p + Vector2(TILE - 1.5, 0), Vector2(2.5, TILE)), OUTLINE)


func _brick(x: int, y: int) -> void:
	var p := Vector2(x * TILE, y * TILE)
	draw_rect(Rect2(p, Vector2(TILE, TILE)), _p["brick"])
	draw_rect(Rect2(p + Vector2(0, TILE - 7), Vector2(TILE, 7)), _p["brick_shade"])
	draw_rect(Rect2(p + Vector2(TILE - 5, 0), Vector2(5, TILE)), _p["brick_shade"])
	draw_rect(Rect2(p, Vector2(TILE, 4)), _p["brick_lip"])
	# The cracks that say "hit me".
	var k := _hash(x, y)
	var a := p + Vector2(8 + k * 8, 5)
	var pts := PackedVector2Array([a, a + Vector2(5, 7), a + Vector2(1, 12), a + Vector2(7, 20), a + Vector2(4, 25)])
	draw_polyline(pts, CRACK, 2.0)
	draw_line(a + Vector2(5, 7), a + Vector2(13, 9), CRACK, 1.5)
	draw_line(a + Vector2(7, 20), a + Vector2(15, 18), CRACK, 1.5)
	draw_rect(Rect2(p + Vector2(-1, -1), Vector2(TILE + 2, TILE + 2)), OUTLINE, false, 2.5)


func _ledge(x: int, y: int) -> void:
	# A wooden ledge: a plank along the top of the cell with an iron bracket.
	var p := Vector2(x * TILE, y * TILE)
	var left = level.tile(x - 1, y) == LevelData.LEDGE
	var right = level.tile(x + 1, y) == LevelData.LEDGE
	draw_rect(Rect2(p + Vector2(-0.5, -1), Vector2(TILE + 1, 11)), OUTLINE)
	draw_rect(Rect2(p + Vector2(0, 0.5), Vector2(TILE, 8)), WOOD)
	draw_rect(Rect2(p + Vector2(0, 0.5), Vector2(TILE, 2.5)), WOOD_LIP)
	draw_rect(Rect2(p + Vector2(0, 6), Vector2(TILE, 2.5)), WOOD_SHADE)
	draw_line(p + Vector2(TILE * 0.5 + (_hash(x, y) - 0.5) * 8, 1), p + Vector2(TILE * 0.5 + (_hash(x, y) - 0.5) * 8, 8), WOOD_SHADE, 1.5)
	if not left:
		draw_rect(Rect2(p + Vector2(-2, -1), Vector2(3, 11)), OUTLINE)
	if not right:
		draw_rect(Rect2(p + Vector2(TILE - 1, -1), Vector2(3, 11)), OUTLINE)
	if (x + y) % 2 == 0 or not left:
		# A bracket under the plank.
		var bx := p.x + (6.0 if not left else 12.0)
		var tri := PackedVector2Array([Vector2(bx, p.y + 9), Vector2(bx + 9, p.y + 9), Vector2(bx, p.y + 19)])
		draw_colored_polygon(tri, OUTLINE)
		var tri2 := PackedVector2Array([Vector2(bx + 1.5, p.y + 10), Vector2(bx + 6, p.y + 10), Vector2(bx + 1.5, p.y + 15)])
		draw_colored_polygon(tri2, IRON)


func _slab(x: int, y: int) -> void:
	# A crumbling ledge: a thin cracked stone slab.
	var p := Vector2(x * TILE, y * TILE)
	var shake: Vector2 = world.ledge_shake(x, y) if world != null else Vector2.ZERO
	p += shake
	draw_rect(Rect2(p + Vector2(-0.5, -1), Vector2(TILE + 1, 13)), OUTLINE)
	draw_rect(Rect2(p + Vector2(1, 0.5), Vector2(TILE - 2, 10)), _p["slab"])
	draw_rect(Rect2(p + Vector2(1, 0.5), Vector2(TILE - 2, 3)), _p["slab_lip"])
	draw_rect(Rect2(p + Vector2(1, 8), Vector2(TILE - 2, 2.5)), _p["shade"])
	var k := _hash(x, y)
	draw_polyline(PackedVector2Array([p + Vector2(6 + k * 10, 1), p + Vector2(10 + k * 10, 6), p + Vector2(8 + k * 10, 10)]), CRACK, 1.5)
	draw_polyline(PackedVector2Array([p + Vector2(22, 2), p + Vector2(19, 7)]), CRACK, 1.5)


func _soft_wax(x: int, y: int) -> void:
	# Soft wax: a pale, sagging shelf of tallow that gives way underfoot.
	var p := Vector2(x * TILE, y * TILE)
	var shake: Vector2 = world.ledge_shake(x, y) if world != null else Vector2.ZERO
	p += shake
	var left: bool = level.tile(x - 1, y) == LevelData.CRUMBLE
	var right: bool = level.tile(x + 1, y) == LevelData.CRUMBLE
	var wax: Color = _p["slab"]
	var lip: Color = _p["slab_lip"]
	var sh := wax.darkened(0.2)
	var sag := 2.0 + _hash(x, y) * 2.0
	var body := PackedVector2Array([p + Vector2(0 if left else 2, 0), p + Vector2(TILE if right else TILE - 2, 0),
			p + Vector2(TILE if right else TILE - 3, 9), p + Vector2(TILE * 0.5, 9 + sag), p + Vector2(0 if left else 3, 9)])
	var ol := PackedVector2Array()
	for q in body:
		ol.append(q + (q - (p + Vector2(16, 5))).normalized() * 1.8)
	draw_colored_polygon(ol, OUTLINE)
	draw_colored_polygon(body, wax)
	draw_rect(Rect2(p + Vector2(0 if left else 2, 0.5), Vector2(TILE - (0 if left else 2) - (0 if right else 2), 3)), lip)
	draw_line(p + Vector2(4, 7), p + Vector2(TILE - 4, 7), sh, 1.5)
	# A drip hanging under it.
	var dx := p.x + 7.0 + _hash(x, y + 1) * 18.0
	draw_rect(Rect2(dx - 1.5, p.y + 9, 3, 4 + sag), wax)
	draw_circle(Vector2(dx, p.y + 13 + sag), 2.0, wax)
	# A thumbprint dent that says "soft".
	draw_circle(p + Vector2(10 + _hash(x + 2, y) * 12, 5), 1.6, sh)


func _spikes(x: int, y: int, up: bool) -> void:
	var p := Vector2(x * TILE, y * TILE)
	var base_y := p.y + TILE if up else p.y
	var tip_y := p.y + TILE * 0.4 if up else p.y + TILE * 0.6
	# An iron strip they stand in.
	var strip := Rect2(p.x, base_y - 5, TILE, 5) if up else Rect2(p.x, base_y, TILE, 5)
	draw_rect(strip.grow(1.0), OUTLINE)
	draw_rect(strip, IRON)
	for i in 4:
		var x0 := p.x + i * 8.0
		var tri := PackedVector2Array([Vector2(x0, base_y), Vector2(x0 + 4, tip_y), Vector2(x0 + 8, base_y)])
		draw_colored_polygon(tri, OUTLINE)
		var inner := PackedVector2Array([Vector2(x0 + 1.4, base_y - (1.2 if up else -1.2)), Vector2(x0 + 4, tip_y + (2.5 if up else -2.5)), Vector2(x0 + 6.6, base_y - (1.2 if up else -1.2))])
		draw_colored_polygon(inner, STEEL)
		var shade := PackedVector2Array([Vector2(x0 + 4, tip_y + (2.5 if up else -2.5)), Vector2(x0 + 6.6, base_y - (1.2 if up else -1.2)), Vector2(x0 + 4.6, base_y - (1.2 if up else -1.2))])
		draw_colored_polygon(shade, STEEL_SHADE)
