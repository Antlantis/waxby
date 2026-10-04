# The tile painters' cost by level height, on the Mac (the shapes plan's E3):
# for each level (default 3-1, the orchard, and 5-3, glass: the slowest
# painters) at 15 rows (its file) and stacked to 24 and 36 rows (the tall
# render labs, game/levels/tall/lab-tall-<id>-<rows>.txt), every tile chunk
# painted on its own and timed, its TriBatch vertices counted (contract.md
# 12.3: a static chunk <= 6000), the edge lines' chunks timed too, in both
# chunk layouts, interleaved pass by pass in one process (the Mac is shared,
# so each chunk keeps its fastest of PASSES):
#   column  16 columns the level's whole height (world.gd before E4)
#   cell    16 x 16 cells (tile_view.gd's row0, world.gd since E4)
# then for each:
#   chunk       the ms a chunk's paint takes, mean and worst; its vertices, worst
#   redraw      what one terrain change (a crumble, a glass pane, a brick, a
#               rime block, false stone) costs: the chunks world._redraw_at
#               asks for at that cell, tiles and edge lines, summed; mean and
#               worst over every such cell in the level
#   in view     the vertices of the tile chunks a view (844 x 390) overlaps,
#               the worst over the camera's places down the level
# against the 120 Hz frame (8.33 ms; the phone is slower than the Mac, so a
# redraw wants to stay well under it) and the vertex budget. The painting
# goes through the theme's painter (paint_chunk with y0, y1), so it needs a
# v3 theme and a tree with E4's painters.
#   godot --headless --path game --script res://../tools/perf/paint_probe.gd -- [3-1,5-3] [--out file]
extends SceneTree

const LevelData := preload("res://scripts/level_data.gd")
const Themes := preload("res://scripts/themes/loader.gd")
const EdgeLines := preload("res://scripts/edge_lines.gd")
const PASSES := 7
const C := 16                    # tile_view.gd CHUNK
const FRAME_MS := 1000.0 / 120.0
const BUDGET := 6000
const VIEW := Vector2(844, 390)
const BELOW := 160.0
const CHANGING := [LevelData.CRUMBLE, LevelData.BRICK, LevelData.FALSE_STONE, LevelData.RIME, LevelData.GLASS]


class CountBatch extends "res://scripts/tri_batch.gd":
	## Remembers the vertices it held at its last flush.
	var last := 0

	func flush(ci: CanvasItem) -> void:
		last = vertex_count()
		super.flush(ci)


var _lines: Array = []


func _say(s: String) -> void:
	print(s)
	_lines.append(s)


func _layout(lv: RefCounted, cells: bool) -> Array:
	## [col0, row0, rows] of every chunk, column-major (world.gd's order).
	var out := []
	var m := ceili(float(lv.height) / C) if cells else 1
	for i in ceili(float(lv.width) / C):
		for j in m:
			out.append([i * C, j * C, mini(C, lv.height - j * C)] if cells else [i * C, 0, lv.height])
	return out


func _paint_pass(host: Node2D, lv: RefCounted, chunks: Array, e: Node2D, best: Array, ebest: Array, verts: Array) -> void:
	## One frame: every chunk painted into host and timed (tiles, then its
	## edge lines), each chunk's fastest kept.
	var painter: Script = Themes.painter(str(lv.theme))
	var pal: Dictionary = Themes.palette(str(lv.theme))
	var tb := CountBatch.new()
	var cb := func():
		for k in chunks.size():
			var c: Array = chunks[k]
			var t0 := Time.get_ticks_usec()
			painter.paint_chunk(host, tb, lv, c[0], mini(c[0] + C, lv.width), pal, null, c[1], c[1] + c[2])
			best[k] = minf(best[k], float(Time.get_ticks_usec() - t0) / 1000.0)
			verts[k] = tb.last
			if e != null and not e.chunks.is_empty():
				# the edge lines' chunks in it (a whole column: each of its rows)
				t0 = Time.get_ticks_usec()
				for j in range(c[1] / C, ceili(float(c[1] + c[2]) / C)):
					e._draw_chunk(host, (c[0] / C) * e.rows + j)
				ebest[k] = minf(ebest[k], float(Time.get_ticks_usec() - t0) / 1000.0)
	host.draw.connect(cb)
	host.queue_redraw()
	await process_frame
	await process_frame
	host.draw.disconnect(cb)


func _redraw_set(lv: RefCounted, chunks: Array, cells: bool, x: int, y: int) -> Array:
	## The chunks (indices into chunks) world._redraw_at(x, y) queues.
	var m := ceili(float(lv.height) / C) if cells else 1
	var out := []
	for xx in [x - 1, x, x + 1]:
		if xx < 0 or xx >= lv.width:
			continue
		for yy in ([y - 1, y, y + 1] if cells else [0]):
			if yy < 0 or yy >= lv.height:
				continue
			var k: int = (xx / C) * m + (yy / C if cells else 0)
			if k < chunks.size() and not out.has(k):
				out.append(k)
	return out


func _report(id: String, rows: int, lv: RefCounted, cells: bool, chunks: Array, best: Array, ebest: Array, verts: Array) -> void:
	var sum_ms := 0.0
	var worst_ms := 0.0
	var worst_v := 0
	var e_worst := 0.0
	for k in chunks.size():
		sum_ms += float(best[k])
		worst_ms = maxf(worst_ms, float(best[k]))
		worst_v = maxi(worst_v, int(verts[k]))
		e_worst = maxf(e_worst, float(ebest[k]))
	# Per redraw: every changing cell in the level.
	var red := []
	for y in lv.height:
		for x in lv.width:
			if CHANGING.has(lv.tile(x, y)):
				var ms := 0.0
				for k in _redraw_set(lv, chunks, cells, x, y):
					ms += float(best[k]) + float(ebest[k])
				red.append(ms)
	var red_mean := 0.0
	var red_worst := 0.0
	for r in red:
		red_mean += r
		red_worst = maxf(red_worst, r)
	red_mean /= maxf(red.size(), 1.0)
	# In view: the tile chunks a view overlaps, down the level.
	var view_v := 0
	var bottom: float = lv.height * 32.0 + BELOW
	var cy := VIEW.y * 0.5
	while true:
		for cx in range(int(VIEW.x * 0.5), int(lv.width * 32 - VIEW.x * 0.5), 256):
			var r := Rect2(Vector2(cx, cy) - VIEW * 0.5, VIEW)
			var v := 0
			for k in chunks.size():
				var c: Array = chunks[k]
				var tr := Rect2(c[0] * 32, c[1] * 32, C * 32, c[2] * 32 + (BELOW if c[1] + c[2] >= lv.height else 0.0))
				if tr.intersects(r):
					v += int(verts[k])
			view_v = maxi(view_v, v)
		if cy >= bottom - VIEW.y * 0.5:
			break
		cy = minf(cy + 64.0, bottom - VIEW.y * 0.5)
	_say("[paint] %s %2d rows, %-6s %3d chunks | chunk %.2f ms mean, %.2f worst, %4d verts worst%s | edges %.2f ms worst | redraw %.2f ms mean, %.2f worst (%d cells; %.0f%% of a 120 Hz frame) | in view %5d verts"
			% [id, rows, "cell" if cells else "column", chunks.size(), sum_ms / maxf(chunks.size(), 1.0), worst_ms, worst_v,
			"" if worst_v <= BUDGET else " OVER %d" % BUDGET, e_worst, red_mean, red_worst, red.size(), 100.0 * red_worst / FRAME_MS, view_v])


func _probe(id: String, rows: int, host: Node2D) -> void:
	var path := "res://levels/%s.txt" % id if rows == 15 else "res://levels/tall/lab-tall-%s-%d.txt" % [id, rows]
	if not FileAccess.file_exists(path):
		_say("[paint] %s at %d rows: no %s (python3 tools/levels/lab_tall.py)" % [id, rows, path])
		return
	var lv = LevelData.load_file(path)
	if Themes.painter(str(lv.theme)) == null:
		_say("[paint] %s: theme %s has no painter (a v3 theme wanted)" % [id, lv.theme])
		return
	var e: Node2D = EdgeLines.new()
	root.add_child(e)
	e.build(lv, LevelData.world_of(id), str(lv.theme))
	var data := {}
	for cells in [false, true]:
		var chunks := _layout(lv, cells)
		var inf := []
		inf.resize(chunks.size())
		inf.fill(INF)
		var zero := []
		zero.resize(chunks.size())
		zero.fill(0)
		data[cells] = {"chunks": chunks, "best": inf.duplicate(), "ebest": inf.duplicate() if not e.chunks.is_empty() else zero.duplicate(),
				"verts": zero.duplicate()}
	for p in PASSES:
		for cells in [false, true]:
			var d: Dictionary = data[cells]
			await _paint_pass(host, lv, d["chunks"], e, d["best"], d["ebest"], d["verts"])
	for cells in [false, true]:
		var d: Dictionary = data[cells]
		_report(id, rows, lv, cells, d["chunks"], d["best"], d["ebest"], d["verts"])
	e.free()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var ids := ["3-1", "5-3"]
	var out := ""
	var i := 0
	while i < args.size():
		if args[i] == "--out":
			out = args[i + 1]
			i += 1
		else:
			ids = Array(str(args[i]).split(","))
		i += 1
	await process_frame
	var host := Node2D.new()
	root.add_child(host)
	# Warm the painters (the first chunks pay for loading scripts and art).
	await _probe("3-1", 15, host)
	_lines.clear()
	for id in ids:
		for rows in [15, 24, 36]:
			await _probe(id, rows, host)
	host.free()
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	quit()
