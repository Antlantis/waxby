# Draw calls by part, on the Mac (spec §13.2): a level at a place, the whole
# frame, then with each part hidden, then each visible backdrop layer or
# slice and tile chunk on its own, against the budgets (a backdrop slice
# <= 15, a tile chunk <= 40; the frame <= 650 in new content, 900 anywhere).
#   godot --path game --resolution 1266x585 --script res://../tools/perf/probe_dc.gd -- <level> [x] [--seam] [--out file]
# x: a fraction of the level's width (<= 1) or a tile column; default the
# level's last tenth (the boss arena in N-4). --seam uses this copy's v3 light
# seam (tools/perf/world_seam.gd) when the tree has it. Runs from any tree
# (v2's promoted rev/verify_phone/tools/_probe_dc.gd). Prints [dc] lines.
extends SceneTree

var _lines: Array = []


func _log(s: String) -> void:
	print(s)
	_lines.append(s)


func _dc() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


func _measure(label: String) -> int:
	for i in 6:
		await process_frame
	var best := 0
	for i in 4:
		await process_frame
		best = maxi(best, _dc())
	_log("[dc] %-40s %4d" % [label, best])
	return best


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var lvl := "2-4"
	var at := -1.0
	var seam := false
	var out := ""
	var i := 0
	var pos: Array = []
	while i < args.size():
		match args[i]:
			"--seam":
				seam = true
			"--out":
				out = args[i + 1]
				i += 1
			_:
				pos.append(args[i])
		i += 1
	if pos.size() > 0:
		lvl = str(pos[0])
	if pos.size() > 1:
		at = float(pos[1])
	var game = root.get_node_or_null("Game")
	if game != null:
		game.settings_path = "user://probe_dc_settings.json"
		game.save_path = "user://probe_dc_save.json"
		game.reset()
	await process_frame
	var LevelData = load("res://scripts/level_data.gd")
	var lv = LevelData.load_file("res://levels/%s.txt" % lvl)
	if game != null:
		for sid in (lv.story as Dictionary).values():
			if not (game.data["seen"] as Array).has(str(sid)):
				(game.data["seen"] as Array).append(str(sid))
	var ws: Script = load("res://scripts/world.gd")
	var sp := "res://../tools/perf/world_seam.gd"
	var has_seam := false
	for m in ws.get_script_method_list():
		if str(m["name"]) == "lit_at":
			has_seam = true
	if seam and not has_seam and ResourceLoader.exists(sp):
		ws = load(sp)
	var w: Node = ws.new()
	w.setup(lv)
	root.add_child(w)
	await process_frame
	var x := int(lv.width * 0.9) if at < 0.0 else (int(at) if at > 1.0 else int(at * lv.width))
	x = clampi(x, 2, lv.width - 3)
	for y in range(lv.height - 1, 0, -1):
		if lv.tile(x, y) == 0 and (lv.is_solid(lv.tile(x, y + 1)) or lv.is_ledge(lv.tile(x, y + 1))):
			w.player.reset_at(Vector2(x * 32 + 16, (y + 1) * 32))
			break
	w.cam = w._clamp_cam(w.player.position)
	for k in 30:
		await process_frame
	w.paused = true
	_log("[dc] level %s at column %d (%s)" % [lvl, x, "v3 seam" if (seam and (has_seam or ResourceLoader.exists(sp))) else "world.gd"])
	var all := await _measure("everything")
	var parts := {}
	var tiles: Array = w.chunks
	var named := {"backdrop": w.backdrop, "glow": w.glow, "hud": w.get("hud"), "touch": w.get("touch"),
			"under": w.get_node_or_null("Under"), "props": w.get_node_or_null("Props"), "monsters": w.get_node_or_null("Monsters"),
			"ambient": w.get("ambient"), "edge lines": w.get("edges")}
	var dark: Node = null
	var wl = w.get("lights")
	if wl is Object and wl.get("node") != null:
		dark = wl.node
	else:
		dark = w.get("_darkness")
	named["darkness"] = dark
	for k in named:
		var n = named[k]
		if n == null or not (n is Object) or not ("visible" in n):
			continue
		n.visible = false
		var d := await _measure("without %s" % k)
		n.visible = true
		parts[k] = all - d
	for t in tiles:
		t.visible = false
	var no_tiles := await _measure("without tile chunks")
	parts["tiles"] = all - no_tiles
	# Each tile chunk in view, alone.
	var view: Rect2 = w.view_rect().grow(64)
	var worst_chunk := 0
	for t in tiles:
		var c0: int = t.col0
		var r0: int = int(t.get("row0")) if "row0" in t else 0
		# (16 x 16 cells, the bottom row of chunks with the bedrock; before
		# tile_view.gd's row0, 16 columns the level's whole height)
		var r := Rect2(c0 * 32, r0 * 32, 16 * 32, 16 * 32 + 160) if "row0" in t else Rect2(c0 * 32, -200, 16 * 32, 2000)
		if not r.intersects(view):
			continue
		t.visible = true
		var d := await _measure("  tile chunk %d,%d alone (+)" % [c0 / 16, r0 / 16])
		t.visible = false
		worst_chunk = maxi(worst_chunk, d - no_tiles)
	for t in tiles:
		t.visible = true
	# The backdrop's layers, and a v3 style's slices, one at a time.
	var bd = w.backdrop
	var worst_slice := 0
	for li in bd.get_child_count():
		var layer: Node2D = bd.get_child(li)
		layer.visible = false
		var d := await _measure("without backdrop layer %d" % li)
		layer.visible = true
		parts["backdrop layer %d" % li] = all - d
		if layer.get_child_count() > 0:
			for sl in layer.get_children():
				(sl as CanvasItem).visible = false
				var d2 := await _measure("  without layer %d slice at %d" % [li, int(sl.get("x0"))])
				(sl as CanvasItem).visible = true
				worst_slice = maxi(worst_slice, all - d2)
	_log("[dc] ---- by part (the frame's calls that go when it is hidden)")
	for k in parts:
		_log("[dc] %-40s %4d" % [k, parts[k]])
	_log("[dc] ---- budgets")
	_log("[dc] %-40s %4d  %s" % ["the frame (<= 650 new, <= 900 any)", all, "ok" if all <= 650 else ("warn" if all <= 900 else "OVER")])
	_log("[dc] %-40s %4d  %s" % ["worst tile chunk (<= 40)", worst_chunk, "ok" if worst_chunk <= 40 else "OVER (v2's wax drips)"])
	if worst_slice > 0:
		_log("[dc] %-40s %4d  %s" % ["worst backdrop slice (<= 15)", worst_slice, "ok" if worst_slice <= 15 else "OVER"])
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	quit()
