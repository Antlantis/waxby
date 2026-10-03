extends SceneTree
## A2's world art: Worlds 5 and 6, the secrets' gilt themes and the Proving
## Hall (scripts/themes/w5.gd, w6.gd, modes.gd; tiles/glass.gd, hush.gd;
## backdrops/sanctum.gd, hushdeep.gd, hall.gd; tools/art/props_w5.py,
## props_w6.py, props_modes.py). Checks:
## - every theme is the loader's, with its painter and style (not the plain
##   fallback) and the keys the World reads;
## - the contrast rule (stone/mid >= 1.45, stone/near >= 1.75, lip/mid >= 3.0);
## - one tell language: W5's prism white and W6's silver ripple are never a
##   mote's, a window's or a theme glass's colour (within ACCENT_NEAR in every
##   channel), W6 has no ambient ripples and no decorative lights, no theme
##   draws wind across the whole screen;
## - W6 reads on the phone: every walkable lip and spike tip on the edge lines
##   at >= 0.30, the lake's crest and the reeds' veins drawn live (so neither
##   floats off its line nor outlasts a snapped reed); W5's glass tops at >= 0.30;
## - the painters paint every tile id within a chunk's 6000 vertices and
##   flush once; the styles' slices stay inside 6000 too;
## - the live looks (the gust, the panes, dawnglass, floats, still water,
##   grasps, tolls) keep inside the per-frame budget, the gust never above
##   the HUD's rows or below the floor, and the lean starts at the tell;
## - the gust blows where the hero is: its band holds his chest over a flat
##   floor, under a low roof, under a spur or a floating chunk, on staggered
##   panes, and its ribbons show in the air round him; pennants hang under a
##   roof (never on it) and stand only on stone (never on glass that breaks);
## - the W6 live looks match deep.gd's rects: the Hushgrasp's hands fill its
##   hurt rect, a float's edge its rect, a buoy's silhouette its touch rect;
## - a glass run keeps its colour when a pane in it shatters;
## - the Proving Hall is the brightest level theme;
## - the props exist (spec §11.3), ThorVG-safe, at their frames, with their
##   points files; the swaps keep v2's frames;
## - the gilt rule for all six secrets (and 6-S's dark, 1-S's snow).

const Themes_path := "res://scripts/themes/loader.gd"
const W5 := ["choirglass", "rosewind", "voidnave", "prismheart"]
const W6 := ["stillshore", "drownbell", "hushquiet", "husheye"]
const GILT := ["nave_gilt", "tallow_gilt", "orchard_gilt", "carillon_gilt", "sanctum_gilt", "hushdeep_gilt"]
const MINE := {"w5": "res://scripts/themes/w5.gd", "w6": "res://scripts/themes/w6.gd", "modes": "res://scripts/themes/modes.gd"}
const SCRIPTS := ["res://scripts/themes/w5.gd", "res://scripts/themes/w6.gd", "res://scripts/themes/modes.gd",
		"res://scripts/tiles/glass.gd", "res://scripts/tiles/hush.gd", "res://scripts/backdrops/sanctum.gd",
		"res://scripts/backdrops/hushdeep.gd", "res://scripts/backdrops/hall.gd"]
const NO_IMMEDIATE := ["draw_circle(", "draw_colored_polygon(", "draw_polyline("]
const W5_ACCENT := Color("f8f0ff")
const W6_ACCENT := Color("e0e0ff")
const ACCENT_NEAR := 0.06          # a colour within this of the accent in every channel reads as it
const CHUNK_BUDGET := 6000
const FRAME_BUDGET := 4000
# spec §11.3's lists (+ what A2 adds: the door's glint)
const PROPS_W5 := ["pennant_slack", "pennant_lift", "pennant_full", "glass_crack1", "glass_crack2", "glass_crack3",
		"prism_lamp_lit", "prism_lamp_out", "window_seal_open", "window_seal_closed", "altar_glass", "altar_glass_lit",
		"bell_glass", "bell_glass_beam", "sconce_glass"]
const PROPS_W6 := ["buoy_lantern_lit", "buoy_lantern_out", "bell_buoy", "bell_buoy_rung", "vigil_candle_out", "vigil_candle_lit",
		"grasp_hand", "altar_hush", "altar_hush_lit", "bell_hush", "bell_hush_beam", "sconce_dead", "eye_seal_open", "eye_seal_closed"]
const PROPS_MODES := ["secret_door", "secret_door_glint", "silver_bell", "legend_shrine_out", "legend_shrine_lit", "grave_candle_out",
		"grave_candle_lit", "waxley_cart", "trial_candle_out", "trial_candle_lit"]
# a W5/W6 prop that stands in for a v2 one keeps that one's frame (viewBox)
const SWAPS := {"altar_glass": "altar", "altar_glass_lit": "altar_lit", "bell_glass": "bell", "bell_glass_beam": "bell_beam",
		"prism_lamp_lit": "lantern_post_lit", "prism_lamp_out": "lantern_post_out", "sconce_glass": "sconce",
		"altar_hush": "altar", "altar_hush_lit": "altar_lit", "bell_hush": "bell", "bell_hush_beam": "bell_beam",
		"buoy_lantern_lit": "lantern_post_lit", "buoy_lantern_out": "lantern_post_out", "sconce_dead": "sconce",
		"silver_bell": "bell"}

var _passed := 0
var _failed := 0
var Themes: Script
var TriBatch: Script
var LevelData: Script


static func _near(a: Color, b: Color) -> bool:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b)) < ACCENT_NEAR


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Themes = load(Themes_path)
	TriBatch = load("res://scripts/tri_batch.gd")
	LevelData = load("res://scripts/level_data.gd")
	await process_frame
	_test_grep()
	_test_themes()
	_test_contrast()
	_test_tell_language()
	_test_edges()
	await _test_painters()
	await _test_styles()
	await _test_gusts()
	await _test_live_w5()
	await _test_live_w6()
	_test_props()
	_test_gilt()
	_test_brightest()
	await _test_gust_geometry()
	await _test_w6_geometry()
	print("test_world_art2: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- the files

func _test_grep() -> void:
	for path in SCRIPTS:
		_check(ResourceLoader.exists(path), "%s exists" % path)
		var src := FileAccess.get_file_as_string(path)
		var hits := []
		for line in src.split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			for bad in NO_IMMEDIATE:
				if code.contains(bad):
					hits.append(bad)
			if code.contains("Time.get_ticks") or code.contains("randf(") or code.contains("randi("):
				hits.append("wall time or a random number")
		_check(hits.is_empty(), "%s: rects and a TriBatch only, timed by ftime (%s)" % [path, ", ".join(hits)])


func _test_themes() -> void:
	var need := ["style", "painter", "sky", "far", "mid", "near", "glass", "banner", "dark_color"]
	for id in W5 + W6 + ["trialhall"]:
		_check(Themes.has_theme(id), "%s is a theme" % id)
		var t: Dictionary = Themes.theme(id)
		var missing := need.filter(func(k): return not t.has(k))
		_check(missing.is_empty(), "%s has %s" % [id, ", ".join(missing) if not missing.is_empty() else "every key"])
		_check(t.get("dark") == t.get("dark_color"), "%s: the World's dark is its dark_color" % id)
		var want_p := "glass" if W5.has(id) or id == "trialhall" else "hush"
		var want_s := "sanctum" if W5.has(id) else ("hushdeep" if W6.has(id) else "hall")
		_check(Themes.painter(id) == load("res://scripts/tiles/%s.gd" % want_p), "%s paints with tiles/%s.gd" % [id, want_p])
		_check(Themes.style(id) == load("res://scripts/backdrops/%s.gd" % want_s), "%s draws backdrops/%s.gd" % [id, want_s])
		_check(not Themes.ambient(id).is_empty(), "%s has motes" % id)
	for id in W6:
		var t: Dictionary = Themes.theme(id)
		_check(t.get("water") is Color and t.get("crest") is Color, "%s names its lake's colours (water, crest)" % id)
		_check(t.get("sconce_light") == false, "%s: the `c` sconce gives no light (spec §3.2)" % id)
	for id in W5 + W6:
		var props: Dictionary = Themes.theme(id).get("props", {})
		var missing := []
		for k in props:
			if not ResourceLoader.exists("res://art/props/%s.svg" % props[k]):
				missing.append(props[k])
		_check(not props.is_empty() and missing.is_empty(), "%s's props all exist (%s)" % [id, ", ".join(missing)])
	# dark_color: W6 darker than W5; hushquiet the darkest of all
	var lum := func(c: Color) -> float: return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	var darkest := true
	for id in W5 + W6:
		if id != "hushquiet" and lum.call(Themes.theme(id)["dark"]) <= lum.call(Themes.theme("hushquiet")["dark"]):
			darkest = false
	_check(darkest, "hushquiet is the darkest theme")
	_check(lum.call(Themes.theme("voidnave")["dark"]) < lum.call(Themes.theme("choirglass")["dark"]), "voidnave is darker than choirglass (so its lamps matter)")


# ---------------------------------------------------------------- contrast

static func _rel(c: Color) -> float:
	var ch := [c.r, c.g, c.b]
	for i in 3:
		var v: float = ch[i]
		ch[i] = v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


static func _ratio(a: Color, b: Color) -> float:
	var la := _rel(a)
	var lb := _rel(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _contrast_of(id: String) -> void:
	var t: Dictionary = Themes.theme(id)
	var p: Dictionary = Themes.palette(id)
	if t.is_empty() or not p.has("stone") or not p.has("lip"):
		print("skipped: %s's palette (its parent theme isn't in this build)" % id)
		return
	var sm := _ratio(p["stone"], t["mid"])
	var sn := _ratio(p["stone"], t["near"])
	var lm := _ratio(p["lip"], t["mid"])
	_check(sm >= 1.45 and sn >= 1.75 and lm >= 3.0, "%s passes the contrast rule (stone/mid %.2f, stone/near %.2f, lip/mid %.2f)" % [id, sm, sn, lm])


func _test_contrast() -> void:
	for id in W5 + W6 + ["trialhall", "sanctum_gilt", "hushdeep_gilt", "nave_gilt", "tallow_gilt"]:
		_contrast_of(id)
	for id in ["orchard_gilt", "carillon_gilt"]:
		var base: String = load(MINE["modes"]).base_of(id)
		if Themes.has_theme(base):
			_contrast_of(id)
		else:
			print("skipped: %s (A1's %s not in this build)" % [id, base])


# ---------------------------------------------------------------- one tell language

func _test_tell_language() -> void:
	for id in W5 + W6:
		var acc := W5_ACCENT if W5.has(id) else W6_ACCENT
		var bad := []
		for e in Themes.ambient(id):
			var c: Color = e.get("color", Color.WHITE)
			if _near(c, acc):
				bad.append(str(e.get("kind")))
			if str(e.get("kind")) == "streak":
				bad.append("streak (wind across the whole screen)")
			if W6.has(id) and str(e.get("kind")) == "ripple":
				bad.append("ripple (a grasp's tell)")
			if int(e.get("count", 0)) > 64:
				bad.append("more than 64 motes")
		_check(bad.is_empty(), "%s: no mote uses the tell accent or its shapes (%s)" % [id, ", ".join(bad)])
		var glass_bad := (Themes.theme(id).get("glass", []) as Array).filter(func(g): return _near(g, acc))
		_check(glass_bad.is_empty(), "%s: no theme glass (decorative panes, window lights) is the tell accent (%s)" % [id, str(glass_bad)])
	var Hd = load("res://scripts/backdrops/hushdeep.gd")
	for id in W6:
		var none := true
		for i in 3:
			if not (Hd.windows(i, Themes.theme(id), Vector2(12000, 460)) as Array).is_empty():
				none = false
		_check(none, "%s has no decorative lights (every W6 light means something)" % id)
	var Sa = load("res://scripts/backdrops/sanctum.gd")
	for id in W5:
		var ok := true
		for i in 3:
			for w in Sa.windows(i, Themes.theme(id), Vector2(12000, 460)):
				if w.get("tint") != null and _near(w["tint"], W5_ACCENT):
					ok = false
				for wc in w.get("colors", []):
					if _near(wc, W5_ACCENT):
						ok = false
				if not (w.get("rose", false) and w.has("center") and w.has("radius")) and not (w.get("rect") is Rect2):
					ok = false
		_check(ok, "%s's windows are well formed and never the accent" % id)


# ---------------------------------------------------------------- edges

func _alpha_of(id: String, what: String) -> float:
	var best := -1.0
	for e in Themes.edges(id):
		if str(e.get("what")) == what:
			best = maxf(best, float(e.get("alpha", 0.0)))
	return best


func _test_edges() -> void:
	for id in W6 + ["hushdeep_gilt"]:
		for what in ["lip", "spike"]:
			_check(_alpha_of(id, what) >= 0.30, "%s: every %s on the edge lines at >= 0.30 (the phone at 30%% brightness)" % [id, what])
		# The crest and the reeds are drawn live (level_features' crest at 0.35 on
		# its real line; features/orchard.gd's per-state veins at 0.35), in the
		# theme's silver: never as static lines (a wade's crest sits 7 px lower
		# than edge_lines' +6; a snapped reed's static vein would still show).
		_check(_alpha_of(id, "crest") < 0.0 and _alpha_of(id, "vine") < 0.0, "%s: no static crest or reed vein on the edge lines" % id)
		var t: Dictionary = Themes.theme(id)
		var lit := func(c) -> bool: return c is Color and (c as Color).get_luminance() >= 0.5
		_check(lit.call(t.get("crest")) and lit.call(t.get("vine_vein")) and lit.call(t.get("rot_vein")), "%s names a pale silver crest and reed veins for the live lines" % id)
	for id in W5:
		_check(_alpha_of(id, "glass") >= 0.30, "%s: glass tops on the edge lines at >= 0.30" % id)
		_check(_alpha_of(id, "spike") > 0.0, "%s: the glass teeth's tips glint above the dark" % id)


# ---------------------------------------------------------------- painters

func _stub_level(theme: String):
	var fx: Script = load("res://tests/render/theme_stub.gd")
	if fx == null:
		return null
	var lv = fx.call("stub_level")
	lv.theme = theme
	return lv


func _test_painters() -> void:
	var lv = _stub_level("choirglass")
	if lv == null:
		print("skipped: tests/render/theme_stub.gd missing")
		return
	var seen := {}
	for y in lv.height:
		for x in lv.width:
			seen[lv.tile(x, y)] = true
	var probe := Node2D.new()
	root.add_child(probe)
	var results := {}
	probe.draw.connect(func():
		for id in W5 + W6 + ["trialhall", "sanctum_gilt", "hushdeep_gilt"]:
			var painter: Script = Themes.painter(id)
			var pal: Dictionary = Themes.palette(id)
			var tb = TriBatch.new()
			var worst := 0
			var flushed := true
			for x0 in range(0, lv.width, 16):
				var x1 := mini(x0 + 16, lv.width)
				# The chunk's vertices before its flush: paint cell by cell into a batch.
				var tb2 = TriBatch.new()
				for x in range(x0, x1):
					for y in lv.height:
						var t: int = lv.tile(x, y)
						if t != 0:
							painter.paint_cell(probe, tb2, lv, x, y, t, pal, null)
				worst = maxi(worst, tb2.vertex_count())
				painter.paint_chunk(probe, tb, lv, x0, x1, pal, null)
				if tb.vertex_count() != 0:
					flushed = false
			results[id] = [worst, flushed]
	)
	probe.queue_redraw()
	await process_frame
	await process_frame
	var all_v3 := range(12, 23).all(func(t): return seen.has(t))
	_check(all_v3 and seen.has(LevelData.STONE) and seen.has(LevelData.WATER), "the stub level holds every v3 tile (12..22), stone and water")
	for id in results:
		_check(results[id][0] > 0 and results[id][0] <= CHUNK_BUDGET, "%s: a chunk stays within %d vertices (%d)" % [id, CHUNK_BUDGET, results[id][0]])
		_check(results[id][1], "%s: paint_chunk flushes its batch" % id)
	_check(results.size() == W5.size() + W6.size() + 3, "every theme was painted")
	# Every tile id, alone, through both painters (nothing unhandled).
	var probe2 := Node2D.new()
	root.add_child(probe2)
	var ok := [true]
	probe2.draw.connect(func():
		for painter in [load("res://scripts/tiles/glass.gd"), load("res://scripts/tiles/hush.gd")]:
			for t in range(1, 23):
				var tb = TriBatch.new()
				painter.paint_cell(probe2, tb, lv, 5, 5, t, {}, null)
				if tb.dropped > 0:
					ok[0] = false
				tb.clear()
	)
	probe2.queue_redraw()
	await process_frame
	await process_frame
	_check(ok[0], "both painters draw every tile id 1..22 with an empty palette (their defaults)")
	# The pane colour is one per run and never picks outside the panes.
	var G = load("res://scripts/tiles/glass.gd")
	var lv2 = LevelData.new()
	lv2.parse("title: t\n---\n..........\n.GGGG.GG..\n.P......E.\n##########\n")
	var run_ok: bool = G.pane_color(lv2, 1, 1, {}) == G.pane_color(lv2, 4, 1, {}) and G.run_start(lv2, 4, 1) == 1 and G.run_start(lv2, 7, 1) == 6
	_check(run_ok, "a glass run shares one pane colour (by where it starts)")
	var stable := 0
	var total := 0
	for start in range(2, 30):
		var lv3 = LevelData.new()
		var row := ".".repeat(start) + "GGGGGGGG" + ".".repeat(6)
		lv3.parse("title: t\n---\n%s\n%s\n%s\n" % [".".repeat(row.length()), row, "#".repeat(row.length())])
		var before := []
		for x in range(start, start + 8):
			before.append(G.pane_color(lv3, x, 1, {}))
		lv3.set_tile(Vector2i(start + 3, 1), LevelData.AIR)
		for x in range(start + 4, start + 8):
			total += 1
			if (G.pane_color(lv3, x, 1, {}) as Color).is_equal_approx(before[x - start]):
				stable += 1
	_check(total > 0 and stable == total, "a pane shattering mid-run never recolours the rest of it (%d of %d kept)" % [stable, total])
	probe.queue_free()
	probe2.queue_free()
	await process_frame


# ---------------------------------------------------------------- styles

func _test_styles() -> void:
	var Backdrop = load("res://scripts/backdrop.gd")
	var span_x := 9000.0
	var results := {}
	for id in W5 + W6 + ["trialhall", "nave_gilt", "sanctum_gilt", "hushdeep_gilt"]:
		var bd = Backdrop.new()
		root.add_child(bd)
		bd.build(id, Vector2(span_x, 480), Vector2(844, 390))
		var style: Script = bd.style_script
		var worst := [0]
		var n := [0]
		var probe := Node2D.new()
		root.add_child(probe)
		probe.draw.connect(func():
			for i in 3:
				var sp: Vector2 = bd.span(i)
				var x := -256.0
				while x < sp.x + 200.0:
					var tb = TriBatch.new()
					style.draw(probe, tb, i, bd.colors(), sp, x, x + 1024.0)
					worst[0] = maxi(worst[0], tb.vertex_count())
					n[0] += 1
					tb.clear()
					x += 1024.0
		)
		probe.queue_redraw()
		await process_frame
		await process_frame
		results[id] = [worst[0], n[0], bd.windows.size(), bd.slice_count()]
		bd.queue_free()
		probe.queue_free()
	await process_frame
	for id in results:
		var r: Array = results[id]
		_check(r[1] > 0 and r[0] <= CHUNK_BUDGET, "%s: every backdrop slice within %d vertices (%d, %d slices)" % [id, CHUNK_BUDGET, r[0], r[1]])
		_check(r[3] > 3, "%s: its layers are sliced so Godot can cull them" % id)
	for id in W6:
		_check(results[id][2] == 0, "%s: no backdrop windows" % id)
	for id in ["choirglass", "rosewind", "prismheart", "trialhall", "nave_gilt"]:
		_check(results[id][2] > 0, "%s: its windows are made at build" % id)


# ---------------------------------------------------------------- the gust

func _gust_level():
	var lv = LevelData.new()
	var rows := PackedStringArray()
	for y in 15:
		if y == 12:
			rows.append("....#####.....##.....##....")
		elif y >= 13:
			rows.append("###########################")
		else:
			rows.append("...........................")
	rows[11] = ".P........................E"
	lv.parse("title: g\ntheme: rosewind\ngusts: 2-22:R:A\n---\n" + "\n".join(rows) + "\n")
	return lv


func _test_gusts() -> void:
	var G = load("res://scripts/tiles/glass.gd")
	var lv = _gust_level()
	_check(lv.gusts.size() == 1, "the test level has its gust zone")
	var z: Dictionary = lv.gusts[0]
	# The hero on the floor at row 12's top (y 384), the camera holding his feet on the ground line.
	var hero := Rect2(6 * 32 + 6, 384 - 38, 20, 38)   # column 6: on row 12's stone
	var view := Rect2(0, 384 - G.FEET_LINE, 844, 390)
	var band: Rect2 = G.gust_band(lv, z, view, hero, G.FEET_LINE)
	_check(band.size.x > 0.0 and band.position.y >= view.position.y + G.HUD_TOP - 0.01, "the wind never rises into the HUD's rows")
	_check(band.end.y <= 12 * 32 + 0.01 and band.end.y <= view.position.y + G.FEET_LINE + G.GROUND_SLACK + 0.01, "the wind never goes below the floor (or the thumbs' line)")
	# Over the void (no floor in view): the ground line bounds it.
	var lv2 = LevelData.new()
	lv2.parse("title: v\ngusts: 1-8:L:B\n---\n" + "..........\n".repeat(14) + ".P......E.\n")
	var b2: Rect2 = G.gust_band(lv2, lv2.gusts[0], view, Rect2(), G.FEET_LINE)
	_check(b2.size.y <= 0.0 or b2.end.y <= view.position.y + G.FEET_LINE + 0.01, "over the void the wind stops at the ground line")
	# The lean: nothing in calm, it starts at the tell, full in the gust.
	var calm: float = G.lean_of({"state": "calm", "k": 0.0})
	var t0: float = G.lean_of({"state": "tell", "k": 0.1})
	var t1: float = G.lean_of({"state": "tell", "k": 1.0})
	var g1: float = G.lean_of({"state": "gust", "k": 1.0})
	_check(calm == 0.0 and t0 > 0.0 and t0 < t1 and t1 <= 0.5 and g1 >= 0.99, "the lean: 0 calm, rising through the tell (to 0.5), 1 at full push")
	# Vertices per frame: calm nothing; tell less than gust; both inside the budget.
	var counts := {}
	var probe := Node2D.new()
	root.add_child(probe)
	probe.draw.connect(func():
		for st in [["calm", 0.0], ["tell", 0.7], ["gust", 1.0]]:
			var tb = TriBatch.new()
			for i in 12:
				G.draw_gust_glow(probe, tb, lv, z, {"state": st[0], "k": st[1]}, view, 1.3 + i * 0.37, {}, hero, G.FEET_LINE)
				counts[st[0] + str(i)] = tb.vertex_count()
				tb.clear()
	)
	probe.queue_redraw()
	await process_frame
	await process_frame
	var most_tell := 0
	var most_gust := 0
	var calm_n := 0
	for k in counts:
		if str(k).begins_with("tell"):
			most_tell = maxi(most_tell, counts[k])
		elif str(k).begins_with("gust"):
			most_gust = maxi(most_gust, counts[k])
		else:
			calm_n += int(counts[k])
	_check(calm_n == 0, "calm: the wind draws nothing")
	_check(most_gust > 0 and most_tell > 0 and most_tell < most_gust, "the tell is lighter than the gust (%d < %d vertices)" % [most_tell, most_gust])
	_check(most_gust <= FRAME_BUDGET / 3, "a zone's wind stays inside a third of the per-frame budget (%d)" % most_gust)
	# Pennants: anchors under the roof or on posts, and they draw (code or sprite).
	var anchors: Array = G.pennant_anchors(lv, z)
	_check(not anchors.is_empty() and anchors.all(func(a): return (a["p"] as Vector2).x >= 2 * 32 and (a["p"] as Vector2).x <= 23 * 32), "the zone has pennants inside it (%d)" % anchors.size())
	var tex := {}
	for k in ["slack", "lift", "full"]:
		tex[k] = load("res://art/props/pennant_%s.svg" % k)
	_check(tex.values().all(func(t): return t is Texture2D), "the pennant sprites load")
	var drew := [0]
	var probe2 := Node2D.new()
	root.add_child(probe2)
	probe2.draw.connect(func():
		var tb = TriBatch.new()
		for st in ["calm", "tell", "gust"]:
			G.draw_gust_under(probe2, tb, z, {"state": st, "k": 0.8}, anchors, 2.0, {})
		drew[0] = tb.vertex_count()
		G.draw_gust_under(probe2, tb, z, {"state": "gust", "k": 0.8}, anchors, 2.0, tex)
		tb.flush(probe2)
	)
	probe2.queue_redraw()
	await process_frame
	await process_frame
	_check(drew[0] > 0, "the code-drawn pennants stand in without their sprites")
	probe.queue_free()
	probe2.queue_free()
	await process_frame


# ---------------------------------------------------------------- the live looks

func _test_live_w5() -> void:
	var G = load("res://scripts/tiles/glass.gd")
	var n := {}
	var probe := Node2D.new()
	root.add_child(probe)
	probe.draw.connect(func():
		var tb = TriBatch.new()
		G.draw_pane_overlay(probe, tb, Vector2i(3, 4), 0.2, "whole", 0.0, {})
		n["none"] = tb.vertex_count()
		G.draw_pane_overlay(probe, tb, Vector2i(3, 4), 0.5, "whole", 0.0, {})
		n["crack1"] = tb.vertex_count()
		tb.clear()
		G.draw_pane_overlay(probe, tb, Vector2i(3, 4), 0.9, "whole", 0.0, {})
		n["crack2"] = tb.vertex_count()
		tb.clear()
		G.draw_pane_overlay(probe, tb, Vector2i(3, 4), 1.0, "flash", 0.1, {})
		G.draw_pane_overlay(probe, tb, Vector2i(3, 4), 0.0, "shimmer", 0.3, {})
		G.draw_dawn_overlay(probe, tb, Vector2i(3, 4), 0.4, false, 1.0, {})
		G.draw_dawn_overlay(probe, tb, Vector2i(3, 4), 0.1, true, 1.0, {})
		n["rest"] = tb.vertex_count()
		tb.flush(probe)
	)
	probe.queue_redraw()
	await process_frame
	await process_frame
	_check(n.get("none", -1) == 0, "a pane under 0.4 strain shows no crack")
	_check(n.get("crack1", 0) > 0 and n.get("crack2", 0) > n.get("crack1", 0), "cracks at 0.4, more at 0.8")
	_check(n.get("rest", 0) > 0, "the flash, the shimmer and dawnglass's clock draw")
	probe.queue_free()
	await process_frame


func _test_live_w6() -> void:
	var H = load("res://scripts/tiles/hush.gd")
	var n := {}
	var probe := Node2D.new()
	root.add_child(probe)
	probe.draw.connect(func():
		var tb = TriBatch.new()
		H.draw_float(probe, tb, Rect2(64, 100, 64, 12), 104.0, 1.0, {})
		H.draw_float(probe, tb, Rect2(64, 118, 64, 12), 104.0, 1.0, {})
		H.draw_float_glow(probe, tb, Rect2(64, 100, 64, 12), 104.0, true, 1.0)
		H.draw_still_glow(probe, tb, 0.0, 192.0, 96.0, 0.0, 1.0)
		n["calm"] = tb.vertex_count()
		H.draw_still_glow(probe, tb, 0.0, 192.0, 96.0, 0.8, 1.0)
		n["tell"] = tb.vertex_count() - n["calm"]
		var before: int = tb.vertex_count()
		H.draw_grasp_tell(probe, tb, Vector2(300, 104), 0.5, 1.0)
		n["grasp"] = tb.vertex_count() - before
		before = tb.vertex_count()
		H.draw_buoy_ring(probe, tb, Vector2(400, 104), 0.4)
		H.draw_buoy_ring(probe, tb, Vector2(400, 104), 1.0)
		n["ring"] = tb.vertex_count() - before
		n["all"] = tb.vertex_count()
		tb.flush(probe)
	)
	probe.queue_redraw()
	await process_frame
	await process_frame
	_check(n.get("tell", 0) > 0, "still water's last seconds crack (its tell draws)")
	_check(n.get("grasp", 0) > 0 and n.get("ring", 0) > 0, "a grasp's tell and a toll's ring draw")
	_check(n.get("all", 0) <= FRAME_BUDGET / 2, "W6's live looks stay light (%d vertices)" % n.get("all", 0))
	probe.queue_free()
	await process_frame


# ---------------------------------------------------------------- props

func _svg_box(path: String) -> Array:
	## [width, height, viewBox w, viewBox h] of an SVG file (or []).
	var txt := FileAccess.get_file_as_string(path)
	var re := RegEx.new()
	re.compile("<svg[^>]*width=\"(\\d+)\"[^>]*height=\"(\\d+)\"[^>]*viewBox=\"0 0 ([\\d.]+) ([\\d.]+)\"")
	var m := re.search(txt)
	if m == null:
		return []
	return [int(m.get_string(1)), int(m.get_string(2)), float(m.get_string(3)), float(m.get_string(4))]


func _test_props() -> void:
	for name in PROPS_W5 + PROPS_W6 + PROPS_MODES:
		var path := "res://art/props/%s.svg" % name
		var txt := FileAccess.get_file_as_string(path)
		_check(txt != "", "art/props/%s.svg exists" % name)
		if txt == "":
			continue
		_check(not txt.contains("<text") and not txt.contains("<filter"), "%s is ThorVG-safe (no <text>, no filters)" % name)
		var box := _svg_box(path)
		_check(box.size() == 4 and box[0] == int(box[2] * 2) and box[1] == int(box[3] * 2), "%s: width = 2 x its viewBox" % name)
		if SWAPS.has(name):
			var v2 := _svg_box("res://art/props/%s.svg" % SWAPS[name])
			_check(box.size() == 4 and v2.size() == 4 and box[2] == v2[2] and box[3] == v2[3], "%s keeps %s's frame" % [name, SWAPS[name]])
		_check(ResourceLoader.exists(path), "%s is imported" % name)
	for pf in ["points_w5", "points_w6", "points_modes"]:
		var path := "res://art/props/%s.json" % pf
		var doc = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(doc is Dictionary and doc.has("_doc"), "%s.json parses and says what it holds" % pf)
		if doc is Dictionary:
			var missing := []
			for k in doc:
				if k != "_doc" and not FileAccess.file_exists("res://art/props/%s.svg" % k):
					missing.append(k)
			_check(missing.is_empty(), "%s.json names only props that exist (%s)" % [pf, ", ".join(missing)])
	# The flame points match v2's for the swapped props (so the live flame lands on the wick).
	var p5 = JSON.parse_string(FileAccess.get_file_as_string("res://art/props/points_w5.json"))
	var p6 = JSON.parse_string(FileAccess.get_file_as_string("res://art/props/points_w6.json"))
	var v2 = JSON.parse_string(FileAccess.get_file_as_string("res://art/props/points_world2.json"))
	if p5 is Dictionary and p6 is Dictionary and v2 is Dictionary:
		var lp: Array = v2["lantern_post_lit"]["flame"]
		_check(p5["prism_lamp_lit"]["flame"] == lp and p6["buoy_lantern_lit"]["flame"] == lp, "the W5/W6 lanterns keep the lantern post's flame point")
		_check(p5["altar_glass"]["flame"] == [32.0, 22.0] and p6["altar_hush"]["flame"] == [32.0, 22.0], "the W5/W6 altars keep v2's wick tip (32, 22)")


# ---------------------------------------------------------------- the gilt rule

func _test_gilt() -> void:
	var M = load(MINE["modes"])
	for id in GILT:
		_check(Themes.has_theme(id), "%s is a theme" % id)
		var t: Dictionary = Themes.theme(id)
		var p: Dictionary = Themes.palette(id)
		_check(t.get("gilt") == true and not t.is_empty(), "%s comes from gilt()" % id)
		_check(p.get("trim") is Color and (p["trim"] as Color).is_equal_approx(Color("d8b24a")), "%s: a gold trim under every lip" % id)
		_check(Themes.style(id) != null or ["cathedral", "cavern"].has(str(t.get("style"))), "%s has a backdrop" % id)
		var base: String = M.base_of(id)
		var bt: Dictionary = Themes.theme(base) if Themes.has_theme(base) else {}
		if id == "hushdeep_gilt":
			_check(bt.is_empty() or (t["dark"] as Color).is_equal_approx(bt["dark"]), "6-S keeps its dark (the trim only)")
			_check(not t.has("near_density"), "6-S keeps its near layer")
			continue
		var glass: Array = t.get("glass", [])
		_check(not glass.is_empty() and (glass[0] as Color).is_equal_approx(Color("ffd84a")), "%s: gold glass" % id)
		_check((t.get("banner", Color.BLACK) as Color).is_equal_approx(Color("d8b24a")), "%s: a gold banner" % id)
		_check(float(t.get("near_density", 1.0)) == 0.5, "%s: the near layer at half" % id)
		if not bt.is_empty():
			var d0: Color = bt["dark"]
			var d1: Color = t["dark"]
			_check(d1.get_luminance() > d0.get_luminance() and (d1.r - d1.b) > (d0.r - d0.b), "%s: its dark lighter and warmer than %s's" % [id, base])
	var roof: Dictionary = Themes.theme("nave_gilt")
	_check(str(roof.get("style")) == "hall" and str(roof.get("variant")) == "roof", "1-S is outdoors (the roof)")
	var snow: Array = Themes.ambient("nave_gilt")
	_check(snow.size() == 1 and str(snow[0].get("kind")) == "flake" and int(snow[0].get("count", 99)) <= 40, "1-S: at most 40 flakes of snow")
	_check(not Themes.theme("choirglass_gilt").is_empty() and Themes.theme("choirglass_gilt").get("gilt") == true, "an unlisted *_gilt gilds its own parent")
	_check(Themes.theme("nosuch_gilt").get("gilt") == true and Themes.theme("nosuch_gilt").has("dark"), "a gilt of a missing parent still has a look (the plain one in gold)")


# ---------------------------------------------------------------- the brightest hall

func _test_brightest() -> void:
	## spec §11.4: the Proving Hall is the brightest level theme (its dark the
	## lightest): over every v3 theme, v2's eight and the six secrets'.
	var lum := func(c: Color) -> float: return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	var hall: float = lum.call(Themes.theme("trialhall")["dark"])
	var ids: Array = Themes.ids() + GILT
	var over := []
	for id in ids:
		if id == "trialhall" or not Themes.has_theme(id):
			continue
		var d = Themes.theme(id).get("dark")
		if d is Color and lum.call(d) >= hall:
			over.append(id)
	var v2: Dictionary = load("res://scripts/backdrop.gd").get_script_constant_map().get("THEMES", {})
	for id in v2:
		var d = (v2[id] as Dictionary).get("dark")
		if d is Color and lum.call(d) >= hall:
			over.append(id)
	_check(v2.size() >= 8 and over.is_empty(), "trialhall is the brightest level theme (%.3f; not under: %s)" % [hall, ", ".join(over)])


# ---------------------------------------------------------------- the gust where he is

func _zone_level(rows: Array, gust: String):
	var lv = LevelData.new()
	lv.parse("title: g\ntheme: rosewind\ngusts: %s\n---\n%s\n" % [gust, "\n".join(rows)])
	return lv


func _test_gust_geometry() -> void:
	## p_worlds' gust sections (GG_PHASE's sigil over the seam, RW_TRACERY's
	## lone panes, the floating chapels, a gallery under a roof): with the
	## hero standing in the zone and the camera holding his feet on the
	## ground line, the band holds his chest, and the full push shows
	## ribbons in the air round him (under a low roof too).
	var G = load("res://scripts/tiles/glass.gd")
	var W := 30
	var base := []
	for y in 15:
		base.append(".".repeat(W) if y < 13 else "#".repeat(W))
	var cases := {"flat": base.duplicate()}
	var spur := base.duplicate()
	spur[10] = "..........======.............."
	cases["a spur 3 rows up"] = spur
	var roof := base.duplicate()
	roof[9] = "......##################......"
	cases["a roof 3 rows up"] = roof
	var roof2 := base.duplicate()
	roof2[8] = "......##################......"
	cases["a roof 4 rows up"] = roof2
	var chunk := base.duplicate()
	chunk[10] = "...........####..............."
	cases["a floating chunk"] = chunk
	var stag := base.duplicate()
	stag[12] = ".........GG.GG.GG..G.G.G......"
	stag[13] = "#########....................#"
	stag[14] = "#########....................#"
	cases["staggered panes"] = stag
	var probe := Node2D.new()
	root.add_child(probe)
	var got := {}
	probe.draw.connect(func():
		for name in cases:
			var lv = _zone_level(cases[name], "2-27:R:A")
			var z: Dictionary = lv.gusts[0]
			var rows := []
			for hx in [12, 15, 16]:
				var ft: int = G.path_floor(lv, hx)
				if ft <= 0:
					continue
				var feet := float(ft * 32)
				var hero := Rect2(hx * 32 + 6, feet - 38, 20, 38)
				var view := Rect2(hx * 32 - 422, feet - G.FEET_LINE, 844, 390)
				var band: Rect2 = G.gust_band(lv, z, view, hero, G.FEET_LINE)
				var chest := Vector2(hero.get_center().x, feet - 24)
				# The ribbons at full push, over many moments: the vertices that show
				# (alpha > 0.05) in the air a tile either side of him, from his feet to
				# two tiles over his head.
				var near := Rect2(hero.position.x - 32, feet - 38 - 64, hero.size.x + 64, 38 + 64)
				var shown := 0
				for i in 16:
					var tb = TriBatch.new()
					G.draw_gust_glow(probe, tb, lv, z, {"state": "gust", "k": 1.0}, view, 0.4 + i * 0.29, {}, hero, G.FEET_LINE)
					for v in tb.points.size():
						if tb.colors[v].a > 0.05 and near.has_point(tb.points[v]):
							shown += 1
					tb.clear()
				rows.append([band.has_point(chest), band.end.y <= feet + 0.01, shown])
			got[name] = rows
	)
	probe.queue_redraw()
	await process_frame
	await process_frame
	for name in cases:
		var rows: Array = got.get(name, [])
		var chest := rows.all(func(r): return r[0])
		var floor := rows.all(func(r): return r[1])
		var shown := rows.all(func(r): return r[2] > 40)
		_check(not rows.is_empty() and chest and floor, "%s: the gust's band holds the hero's chest, never below his floor" % name)
		_check(not rows.is_empty() and shown, "%s: the full push shows ribbons in the air round him (%s)" % [name, str(rows.map(func(r): return r[2]))])
	probe.queue_free()
	# Pennants: under a roof they hang from its underside (never stand on its
	# top); on the pole level every one stands on stone, none on the panes.
	var lr = _zone_level(cases["a roof 3 rows up"], "2-27:R:A")
	var hung := (G.pennant_anchors(lr, lr.gusts[0]) as Array).filter(func(a): return not a["pole"])
	_check(not hung.is_empty() and hung.all(func(a): return is_equal_approx((a["p"] as Vector2).y, 10 * 32.0)), "under a roof the pennants hang from its underside (%d)" % hung.size())
	var tops_ok := (G.pennant_anchors(lr, lr.gusts[0]) as Array).all(func(a): return (a["p"] as Vector2).y > 9 * 32.0)
	_check(tops_ok, "no pennant is planted on a roof's top")
	var prow := ".".repeat(40)
	var pole_rows := []
	for y in 13:
		pole_rows.append(prow)
	pole_rows.append("#####GGG#GGG#GGG#GGG#GGG#GGG#GGG#GGG####")
	pole_rows.append("#".repeat(40))
	var lp = _zone_level(pole_rows, "4-35:R:A")
	var poles: Array = G.pennant_anchors(lp, lp.gusts[0])
	var on_stone := poles.all(func(a): return lp.tile((a["cell"] as Vector2i).x, (a["cell"] as Vector2i).y) == LevelData.STONE)
	_check(not poles.is_empty() and on_stone, "pennant poles stand on stone, never on glass that breaks (%d)" % poles.size())
	# And one whose masonry is gone is not drawn.
	var cell: Vector2i = poles[0]["cell"] if not poles.is_empty() else Vector2i(0, 0)
	lp.set_tile(cell, LevelData.AIR)
	var drawn := [0, 0]
	var probe2 := Node2D.new()
	root.add_child(probe2)
	probe2.draw.connect(func():
		var tb = TriBatch.new()
		G.draw_gust_under(probe2, tb, lp.gusts[0], {"state": "gust", "k": 1.0}, poles, 1.0, {})
		drawn[0] = tb.vertex_count()
		tb.clear()
		G.draw_gust_under(probe2, tb, lp.gusts[0], {"state": "gust", "k": 1.0}, poles, 1.0, {}, lp)
		drawn[1] = tb.vertex_count()
		tb.clear()
	)
	probe2.queue_redraw()
	await process_frame
	await process_frame
	_check(drawn[1] < drawn[0], "a pennant whose stone is gone isn't drawn (%d < %d vertices)" % [drawn[1], drawn[0]])
	probe2.queue_free()
	await process_frame


# ---------------------------------------------------------------- W6's looks against deep.gd's rects

func _test_w6_geometry() -> void:
	var H = load("res://scripts/tiles/hush.gd")
	var deep: Dictionary = load("res://scripts/features/deep.gd").get_script_constant_map()
	var gw := float(deep.get("GRASP_W", 28.0))
	var gh := float(deep.get("GRASP_H", 80.0))
	# The Hushgrasp: its sprite (drawn at 0.25) fills the hurt rect it stands for.
	var tex: Texture2D = load("res://art/props/grasp_hand.svg")
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var s := float(img.get_width()) / 32.0          # image px per world px (the frame is 32 x 80 px)
	var widest := 0.0
	var tall := 0
	for yy in range(0, img.get_height(), 4):
		var x0 := -1
		var x1 := -1
		for xx in img.get_width():
			if img.get_pixel(xx, yy).a > 0.5:
				if x0 < 0:
					x0 = xx
				x1 = xx
		if x0 >= 0:
			tall += 4
			if yy < img.get_height() * 0.6:
				widest = maxf(widest, (x1 - x0 + 1) / s)
	_check(widest >= gw * 0.85 and widest <= gw + 4.0, "the Hushgrasp's hands fill its %d px hurt width (%.1f px)" % [int(gw), widest])
	_check(tall / s >= gh * 0.6, "the Hushgrasp stands most of its %d px (%.0f px opaque)" % [int(gh), tall / s])
	var p6 = JSON.parse_string(FileAccess.get_file_as_string("res://art/props/points_w6.json"))
	var hurt: Array = p6["grasp_hand"]["hurt"] if p6 is Dictionary else []
	_check(hurt.size() == 4 and is_equal_approx(float(hurt[2]), gw * 2.0) and is_equal_approx(float(hurt[3]), gh * 2.0)
			and is_equal_approx(float(hurt[0]) + float(hurt[2]) * 0.5, 32.0), "points_w6.json's grasp hurt is deep.gd's rect in frame units (%s)" % str(hurt))
	# A float's edge spans its rect; a buoy's silhouette sits on its touch rect.
	var n := {}
	var probe := Node2D.new()
	root.add_child(probe)
	probe.draw.connect(func():
		var tb = TriBatch.new()
		var r := Rect2(64, 100, 64, 12)
		H.draw_float_glow(probe, tb, r, 104.0, false, 1.0)
		var bb := Rect2(tb.points[0], Vector2.ZERO)
		for v in tb.points:
			bb = bb.expand(v)
		n["float"] = [bb, r]
		tb.clear()
		# deep.gd: a buoy's pos is its cell's centre, its touch rect pos - (16, 24), 32 x 32;
		# the lake line in a deep cell at +8 (the sprite's water point).
		var cell := Vector2i(10, 6)
		var pos := Vector2(cell.x * 32 + 16, cell.y * 32 + 16)
		var water := Vector2(pos.x, cell.y * 32 + 8.0)
		for rung in [false, true]:
			H.draw_buoy_glow(probe, tb, water, rung)
		var bb2 := Rect2(tb.points[0], Vector2.ZERO)
		var bright := 0
		for v in tb.points.size():
			bb2 = bb2.expand(tb.points[v])
			if tb.colors[v].a >= 0.30:
				bright += 1
		n["buoy"] = [bb2, Rect2(pos - Vector2(16, 24), Vector2(32, 32)), bright, tb.vertex_count()]
		tb.clear()
	)
	probe.queue_redraw()
	await process_frame
	await process_frame
	var f: Array = n.get("float", [])
	_check(f.size() == 2 and absf((f[0] as Rect2).position.x - (f[1] as Rect2).position.x) <= 2.0 and absf((f[0] as Rect2).end.x - (f[1] as Rect2).end.x) <= 2.0,
			"a float's silver edge spans its rect, end to end")
	var b: Array = n.get("buoy", [])
	if b.size() == 4:
		var sil: Rect2 = b[0]
		var touch: Rect2 = b[1]
		var inter := sil.intersection(touch)
		_check(inter.size.x >= touch.size.x * 0.6 and inter.size.y >= touch.size.y * 0.5 and sil.size.x <= touch.size.x + 2.0,
				"a buoy's silhouette sits on its touch rect (%s over %s)" % [sil, touch])
		_check(int(b[2]) > 0 and int(b[3]) <= 600, "a buoy's silhouette reads above the dark (>= 0.30) and stays light (%d vertices)" % int(b[3]))
	else:
		_check(false, "the buoy's silhouette draws")
	probe.queue_free()
	await process_frame
