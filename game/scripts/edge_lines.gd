extends Node2D
## Static readability lines above the dark, so the path's shape always shows:
## W3's vine veins, W5's glass tops, W6's every walkable lip, spike tip and
## lake crest (spec §11.2 F6, decisions.md's phone alphas). On the glow layer,
## one child per 16-column chunk (the tiles' chunks), drawn once as one
## TriBatch and redrawn only when a tile there changes. A world with no lines
## (W1, W2) builds no chunks and costs nothing.
##   build(level, world_n, theme := level.theme, world := null)  the theme's EDGES (themes/loader.gd), else the world's defaults
##   redraw_chunk(cx)                             after a tile change in chunk cx (and its neighbours' edges)
##   redraw_cell(x)                               the same, by column
## A style entry: {what, color, alpha, width?}. what: vine (veins down vine
## cells), glass (glass tops), lip (every walkable top: solid or ledge under
## air), ledge (one-way tops only), spike (spike tips), crest (a water
## surface), ice (ice and frosted-ledge tops), dawnglass (its outline).
## A crumble that has fallen (world.ledge_present false) gets no lip or ledge
## line: the World redraws its chunk as it falls and again as it grows back.
## No draw_circle / draw_colored_polygon / draw_polyline (test_render.gd).

const TriBatch := preload("res://scripts/tri_batch.gd")
const Themes := preload("res://scripts/themes/loader.gd")
const LevelData := preload("res://scripts/level_data.gd")
const TILE := 32
const CHUNK := 16

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
const V3_LEDGE := [FROST_LEDGE, DAWN_ON, STILL]

# When a theme has no EDGES of its own (decisions.md: W6 lips 0.30, vine
# veins 0.35; spec §11.2: W5 glass tops at 0.30).
const DEFAULTS := {
	3: [{"what": "vine", "color": Color("9ad07a"), "alpha": 0.35}],
	5: [{"what": "glass", "color": Color("d8e4f4"), "alpha": 0.30}],
	6: [{"what": "lip", "color": Color("b8b8e0"), "alpha": 0.30},
		{"what": "spike", "color": Color("c8c8f0"), "alpha": 0.30},
		{"what": "crest", "color": Color("a0a0d0"), "alpha": 0.30}],
}

var level: RefCounted
var world: Node = null            # asked whether a crumble is there (ledge_present); null: always
var world_n := 0
var styles: Array = []
var chunks: Array = []           # Node2D per chunk (or null where nothing draws)
var _tb := TriBatch.new()


func build(p_level: RefCounted, p_world_n: int, theme := "", p_world: Node = null) -> void:
	level = p_level
	world_n = p_world_n
	world = p_world
	for c in get_children():
		c.queue_free()
	chunks.clear()
	var th := theme if theme != "" else str(level.theme)
	styles = Themes.edges(th)
	if styles.is_empty():
		styles = DEFAULTS.get(world_n, [])
	if styles.is_empty():
		return
	var n := ceili(float(level.width) / CHUNK)
	for i in n:
		var ch := Node2D.new()
		ch.name = "Edges%d" % i
		ch.draw.connect(_draw_chunk.bind(ch, i))
		add_child(ch)
		chunks.append(ch)


func redraw_chunk(cx: int) -> void:
	if cx >= 0 and cx < chunks.size() and chunks[cx] != null:
		chunks[cx].queue_redraw()


func redraw_cell(x: int) -> void:
	var i := x / CHUNK
	redraw_chunk(i)
	if (x + 1) / CHUNK != i:
		redraw_chunk((x + 1) / CHUNK)
	if x > 0 and (x - 1) / CHUNK != i:
		redraw_chunk((x - 1) / CHUNK)


func _solid(t: int) -> bool:
	return LevelData.is_solid(t) or V3_SOLID.has(t)


func _walkable(t: int) -> bool:
	return _solid(t) or LevelData.is_ledge(t) or V3_LEDGE.has(t)


func _fallen(t: int, x: int, y: int) -> bool:
	## A crumble (a bone trellis, thin ice) that has fallen: no floor to line.
	return t == LevelData.CRUMBLE and world != null and world.has_method("ledge_present") and not world.ledge_present(x, y)


func _draw_chunk(ch: Node2D, i: int) -> void:
	var x0 := i * CHUNK
	var x1 := mini(x0 + CHUNK, level.width)
	_tb.origin = Vector2(x0 * TILE, 0)
	for st in styles:
		var what := str(st.get("what", "lip"))
		var c: Color = st.get("color", Color(1, 1, 1))
		c.a = float(st.get("alpha", 0.3))
		var w: float = float(st.get("width", 1.5))
		for x in range(x0, x1):
			for y in level.height:
				_cell(what, x, y, c, w)
	_tb.flush(ch)


func _cell(what: String, x: int, y: int, c: Color, w: float) -> void:
	var t: int = level.tile(x, y)
	var above: int = level.tile(x, y - 1) if y > 0 else LevelData.AIR
	var p := Vector2(x * TILE, y * TILE)
	match what:
		"vine":
			if t == VINE or t == ROTTEN_VINE:
				var pts := PackedVector2Array()
				for k in 5:
					pts.append(Vector2(p.x + TILE * 0.5 + sin((y * 4 + k) * 0.9 + x) * 3.0, p.y + k * TILE / 4.0))
				_tb.polyline(pts, w, c)
		"glass":
			if t == GLASS and not _solid(above):
				_tb.line(p + Vector2(0, 0.5), p + Vector2(TILE, 0.5), w, c)
		"lip":
			if _walkable(t) and not _walkable(above) and above != LevelData.WATER and not _fallen(t, x, y):
				_tb.line(p + Vector2(0, 0.5), p + Vector2(TILE, 0.5), w, c)
		"ledge":
			if (LevelData.is_ledge(t) or V3_LEDGE.has(t)) and not _walkable(above) and not _fallen(t, x, y):
				_tb.line(p + Vector2(0, 0.5), p + Vector2(TILE, 0.5), w, c)
		"ice":
			if (t == ICE or t == FROST_LEDGE) and not _walkable(above):
				_tb.line(p + Vector2(0, 0.5), p + Vector2(TILE, 0.5), w, c)
		"spike":
			if t == LevelData.SPIKES_UP or t == LevelData.SPIKES_DOWN:
				var up := t == LevelData.SPIKES_UP
				var tip_y := p.y + TILE * 0.4 if up else p.y + TILE * 0.6
				for k in 4:
					var tx := p.x + 4.0 + k * 8.0
					_tb.tri(Vector2(tx - 1.6, tip_y + (3.0 if up else -3.0)), Vector2(tx, tip_y), Vector2(tx + 1.6, tip_y + (3.0 if up else -3.0)), c)
		"crest":
			if (t == LevelData.WATER or t == STILL) and above != LevelData.WATER and above != STILL:
				_tb.line(p + Vector2(0, 6), p + Vector2(TILE, 6), w, c)
		"dawnglass":
			if t == DAWNGLASS or t == DAWN_ON:
				_tb.line(p + Vector2(1, 0.5), p + Vector2(TILE - 1, 0.5), w, c)
				_tb.line(p + Vector2(1, 10), p + Vector2(TILE - 1, 10), w, c)
